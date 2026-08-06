import 'package:supabase_flutter/supabase_flutter.dart';

import '../../stock_photos/data/quota.dart' show QuotaStatus, fetchQuotaStatus;
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
          // Malformed 402 body only; the function always sends used/limit.
          limit: (map?['limit'] as num?)?.toInt() ?? 0,
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

  /// The group's usage + effective limit, resolved server-side. Drives the
  /// "N de M" header.
  Future<QuotaStatus> fetchQuota(String groupId) => fetchQuotaStatus(
    _client,
    groupId: groupId,
    quotaKey: kDishAssistantQuotaKey,
  );
}
