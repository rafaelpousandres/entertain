import 'package:supabase_flutter/supabase_flutter.dart';

import '../../photos/data/media.dart';
import 'quota.dart';
import 'stock_photo.dart';

/// Thrown when `save` is blocked because the group's monthly stock-photo quota
/// is exhausted (the Edge Function returns 402). The paywall seam — surfaced to
/// the user as the limit-reached message, no upsell yet.
class QuotaExceededException implements Exception {
  const QuotaExceededException({required this.used, required this.limit});
  final int used;
  final int limit;
}

/// Spec 019 §B — client side of the `stock-photos` Edge Function. The Pexels
/// key lives only in the function; the client never sees it. The quota counter
/// is read directly (RLS allows group members SELECT on `quota_usage` /
/// `quota_entitlements`) but only the function ever writes it.
class StockPhotoRepository {
  StockPhotoRepository(this._client);

  final SupabaseClient _client;

  /// §B.1 — search (no quota). [locale] is `ca-ES` / `es-ES` / `en-US`.
  Future<List<StockPhoto>> search({
    required String query,
    required String locale,
    int page = 1,
  }) async {
    final res = await _client.functions.invoke(
      'stock-photos',
      body: {
        'action': 'search',
        'query': query,
        'locale': locale,
        'page': page,
      },
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final photos = (data['photos'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return photos.map(StockPhoto.fromJson).toList();
  }

  /// §B.2 — copy the chosen photo onto the entity (server downloads, uploads,
  /// inserts the media row with provenance, and atomically charges quota).
  /// Returns the updated usage; throws [QuotaExceededException] on 402.
  Future<QuotaStatus> save({
    required StockPhoto photo,
    required MediaEntityType type,
    required String entityId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'stock-photos',
        body: {
          'action': 'save',
          'photo': photo.toSavePayload(),
          'entity_type': type.wire,
          'entity_id': entityId,
        },
      );
      final data = (res.data as Map).cast<String, dynamic>();
      final usage = (data['usage'] as Map).cast<String, dynamic>();
      return QuotaStatus(
        used: (usage['used'] as num).toInt(),
        limit: (usage['limit'] as num).toInt(),
      );
    } on FunctionException catch (e) {
      if (e.status == 402) {
        final details = e.details;
        final map = details is Map ? details.cast<String, dynamic>() : null;
        throw QuotaExceededException(
          used: (map?['used'] as num?)?.toInt() ?? 0,
          limit: (map?['limit'] as num?)?.toInt() ?? kStockPhotosDefaultLimit,
        );
      }
      rethrow;
    }
  }

  /// Reads the group's usage for the current period + its effective limit
  /// (entitlement row, else the system default). Drives the "N de 10" header.
  Future<QuotaStatus> fetchQuota(String groupId) async {
    final period = currentPeriodUtc();
    final usageRow = await _client
        .from('quota_usage')
        .select('used')
        .eq('group_id', groupId)
        .eq('quota_key', kStockPhotosQuotaKey)
        .eq('period', period)
        .maybeSingle();
    final entRow = await _client
        .from('quota_entitlements')
        .select('monthly_limit')
        .eq('group_id', groupId)
        .eq('quota_key', kStockPhotosQuotaKey)
        .maybeSingle();
    return QuotaStatus(
      used: (usageRow?['used'] as num?)?.toInt() ?? 0,
      limit:
          (entRow?['monthly_limit'] as num?)?.toInt() ??
          kStockPhotosDefaultLimit,
    );
  }
}
