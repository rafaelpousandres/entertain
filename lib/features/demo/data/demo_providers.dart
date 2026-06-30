import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart';
import 'demo_repository.dart';

final _demoClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final demoRepositoryProvider = Provider<DemoRepository>(
  (ref) => DemoRepository(ref.watch(_demoClientProvider)),
);

/// True while the current group still holds demo data. The "start from
/// scratch" banner watches this and hides itself once the example is gone.
final hasDemoDataProvider = FutureProvider<bool>((ref) async {
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return ref.watch(demoRepositoryProvider).hasDemoData(groupId);
});
