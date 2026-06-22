import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import 'quota.dart';
import 'stock_photo_repository.dart';

/// Spec 019 — the stock-photo proxy repository (Pexels via the Edge Function).
final stockPhotoRepositoryProvider = Provider<StockPhotoRepository>((ref) {
  return StockPhotoRepository(Supabase.instance.client);
});

/// The current group's stock-photo usage for this month. Invalidated after a
/// successful save so the "N de 10" header updates live.
final stockPhotoQuotaProvider = FutureProvider<QuotaStatus>((ref) async {
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return ref.watch(stockPhotoRepositoryProvider).fetchQuota(groupId);
});
