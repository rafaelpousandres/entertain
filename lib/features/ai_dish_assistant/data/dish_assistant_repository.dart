import 'package:supabase_flutter/supabase_flutter.dart';

import '../../stock_photos/data/quota.dart' show QuotaStatus, currentPeriodUtc;
import 'dish_assistant.dart';
import 'dish_suggestion.dart';

/// Thrown when `process` is blocked because the group's monthly dish-assistant
/// quota is exhausted (the Edge Function returns 402). The paywall seam —
/// surfaced as the limit-reached message, no upsell yet (Spec 020 §6).
class QuotaExceededException implements Exception {
  const QuotaExceededException({required this.used, required this.limit});
  final int used;
  final int limit;
}

/// Spec 020 §6 (v3) — client side of the two-phase `dish-assistant` Edge
/// Function. The Anthropic key lives only in the function. The quota counter is
/// read directly (RLS allows group members SELECT on the Spec 019 quota tables)
/// but only the function ever writes it.
class DishAssistantRepository {
  DishAssistantRepository(this._client);

  final SupabaseClient _client;

  /// §1 Path A, Phase 1 — suggest (no quota). [locale] is `ca` / `es` / `en`.
  /// Returns up to 3 {title, url} recipe suggestions; fewer is fine.
  Future<List<DishSuggestion>> suggest({
    required String name,
    required String locale,
  }) async {
    final res = await _client.functions.invoke(
      'dish-assistant',
      body: {'action': 'suggest', 'name': name, 'locale': locale},
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final list = (data['suggestions'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return list
        .map(DishSuggestion.fromJson)
        .where((s) => s.hasUrl)
        .toList();
  }

  /// §1 Process (charges quota) — both input paths converge here. Path A passes
  /// the picked suggestion's [url]; Path B passes the user-pasted [url]. The
  /// server fetches & adapts that one recipe, creates the dish (with i18n
  /// ingredients, multilingual name, preparation = recipe, hybrid photo), and
  /// atomically charges quota. Returns the new dish id + updated usage; throws
  /// [QuotaExceededException] on 402.
  Future<({String dishId, QuotaStatus usage})> process({
    required String url,
    String? name,
    required String locale,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'dish-assistant',
        body: {
          'action': 'process',
          'url': url,
          if (name != null && name.isNotEmpty) 'name': name,
          'locale': locale,
        },
      );
      final data = (res.data as Map).cast<String, dynamic>();
      final usage = (data['usage'] as Map).cast<String, dynamic>();
      return (
        dishId: data['dish_id'] as String,
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
