import 'package:supabase_flutter/supabase_flutter.dart';

import '../../stock_photos/data/quota.dart' show QuotaStatus, currentPeriodUtc;
import 'dish_assistant.dart';
import 'dish_card.dart';

/// Thrown when `generate` is blocked because the group's monthly dish-assistant
/// quota is exhausted (the Edge Function returns 402). The paywall seam —
/// surfaced as the limit-reached message, no upsell yet (Spec 020 §5).
class QuotaExceededException implements Exception {
  const QuotaExceededException({required this.used, required this.limit});
  final int used;
  final int limit;
}

/// Spec 020 §5 (v4) — client side of the generate→review→save `dish-assistant`
/// Edge Function. The Anthropic + Pexels keys live only in the function. The
/// quota counter is read directly (RLS allows group members SELECT on the
/// Spec 019 quota tables) but only the function ever writes it.
class DishAssistantRepository {
  DishAssistantRepository(this._client);

  final SupabaseClient _client;

  /// §5 generate — CHARGES QUOTA. Free text (name or description) + locale ->
  /// Claude produces a dish card (with an illustrative photo already resolved).
  /// Returns the card for review + updated usage; throws [QuotaExceededException]
  /// on 402. The dish is NOT persisted yet — see [save] / discard.
  Future<({DishCard card, QuotaStatus usage})> generate({
    required String text,
    required String locale,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'dish-assistant',
        body: {'action': 'generate', 'text': text, 'locale': locale},
      );
      final data = (res.data as Map).cast<String, dynamic>();
      final usage = (data['usage'] as Map).cast<String, dynamic>();
      return (
        card: DishCard.fromJson(
          (data['card'] as Map).cast<String, dynamic>(),
          locale: locale,
        ),
        usage: QuotaStatus(
          used: (usage['used'] as num).toInt(),
          limit: (usage['limit'] as num).toInt(),
        ),
      );
    } on FunctionException catch (e) {
      if (e.status == 402) {
        final details = e.details;
        final map = details is Map ? details.cast<String, dynamic>() : null;
        throw QuotaExceededException(
          used: (map?['used'] as num?)?.toInt() ?? 0,
          limit:
              (map?['limit'] as num?)?.toInt() ?? kDishAssistantDefaultLimit,
        );
      }
      rethrow;
    }
  }

  /// §5 save — NO quota (already charged at generate). Persists the reviewed
  /// card (creates new ingredients with i18n, the dish with preparation +
  /// multilingual name, the lines, and the already-chosen photo). Returns the
  /// new dish id. Discard simply never calls this.
  Future<String> save({required DishCard card}) async {
    final res = await _client.functions.invoke(
      'dish-assistant',
      body: {'action': 'save', 'card': card.toSavePayload()},
    );
    final data = (res.data as Map).cast<String, dynamic>();
    return data['dish_id'] as String;
  }

  /// Reads the group's usage for the current period + its effective limit
  /// (entitlement row, else the system default). Drives the "N de 3" header.
  Future<QuotaStatus> fetchQuota(String groupId) async {
    final period = currentPeriodUtc();
    final usageRow = await _client
        .from('quota_usage')
        .select('used')
        .eq('group_id', groupId)
        .eq('quota_key', kDishAssistantQuotaKey)
        .eq('period', period)
        .maybeSingle();
    final entRow = await _client
        .from('quota_entitlements')
        .select('monthly_limit')
        .eq('group_id', groupId)
        .eq('quota_key', kDishAssistantQuotaKey)
        .maybeSingle();
    return QuotaStatus(
      used: (usageRow?['used'] as num?)?.toInt() ?? 0,
      limit:
          (entRow?['monthly_limit'] as num?)?.toInt() ??
          kDishAssistantDefaultLimit,
    );
  }
}
