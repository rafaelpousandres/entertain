import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import 'group_supplier_setting.dart';
import 'settings_repository.dart';
import 'shopping_models.dart';
import 'shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(Supabase.instance.client);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(Supabase.instance.client);
});

/// The full shopping picture for an event — every line and every order —
/// loaded once and shared by the panel and the message composer. Invalidated
/// after a send so the panel reflects the new order immediately (Spec §2.6).
final eventShoppingProvider = FutureProvider.family<EventShopping, String>((
  ref,
  eventId,
) async {
  final repo = ref.watch(shoppingRepositoryProvider);
  final lines = await repo.listEventLines(eventId);
  final orders = await repo.listEventOrders(eventId);
  return EventShopping(lines: lines, orders: orders);
});

/// Per-category messaging configuration for the current group, keyed by
/// `supplierCategoryId`. Invalidated after any Settings edit.
final groupSupplierSettingsProvider =
    FutureProvider<Map<String, GroupSupplierSetting>>((ref) async {
      final groupId = await ref.watch(currentGroupIdProvider.future);
      final settings = await ref
          .watch(settingsRepositoryProvider)
          .listSettings(groupId);
      return {for (final s in settings) s.supplierCategoryId: s};
    });

/// The group's outgoing-message signature, defaulting to the owner's
/// `profiles.display_name` the first time it is shown (Spec §2.5). Invalidated
/// after a Settings edit.
final groupSignatureProvider = FutureProvider<String>((ref) async {
  final groupId = await ref.watch(currentGroupIdProvider.future);
  final repo = ref.watch(settingsRepositoryProvider);
  final stored = await repo.fetchSignature(groupId);
  if (stored != null) return stored;
  final displayName = await repo.fetchProfileDisplayName();
  return displayName ?? '';
});
