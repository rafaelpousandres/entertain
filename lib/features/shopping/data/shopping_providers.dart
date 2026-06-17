import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import 'group_supplier_setting.dart';
import 'message_channel.dart';
import 'settings_repository.dart';
import 'shopping_models.dart';
import 'shopping_repository.dart';
import 'supplier_resolution.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(Supabase.instance.client);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(Supabase.instance.client);
});

/// The full shopping picture for an event — every line and every order —
/// shared by the panel and the message composer.
///
/// `autoDispose` (Fixes §2.1): the original provider cached its value for the
/// whole session and was invalidated only after a send, so menu edits left the
/// shopping panel showing stale data until a cold restart. Auto-disposing
/// means the data is re-read from the source of truth every time the panel is
/// shown anew, and the menu-mutation sites (add/remove dish, edit a line) also
/// invalidate it explicitly so a panel kept mounted underneath a pushed route
/// refreshes the moment the user returns.
final eventShoppingProvider =
    FutureProvider.autoDispose.family<EventShopping, String>((
  ref,
  eventId,
) async {
  final repo = ref.watch(shoppingRepositoryProvider);
  final lines = await repo.listEventLines(eventId);
  final orders = await repo.listEventOrders(eventId);
  return EventShopping(lines: lines, orders: orders);
});

/// Suppliers for the current group grouped by `supplierCategoryId` (Spec 013:
/// a category may have several). Each list is resolution-ordered (default
/// first, then by name). Invalidated after any Settings edit.
final groupSuppliersByCategoryProvider =
    FutureProvider<Map<String, List<GroupSupplierSetting>>>((ref) async {
      final groupId = await ref.watch(currentGroupIdProvider.future);
      final settings = await ref
          .watch(settingsRepositoryProvider)
          .listSettings(groupId);
      final byCategory = <String, List<GroupSupplierSetting>>{};
      for (final s in settings) {
        byCategory.putIfAbsent(s.supplierCategoryId, () => []).add(s);
      }
      // Order each category's suppliers consistently with the resolver.
      for (final entry in byCategory.entries) {
        byCategory[entry.key] =
            resolveSuppliersForCategory(entry.value, entry.key).suppliers;
      }
      return byCategory;
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

/// The group's text-message channel (Spec 008 §2.9): SMS or WhatsApp. Resolves
/// what the per-supplier "text" channel dispatches to. Invalidated after a
/// Settings edit.
final groupTextMessageChannelProvider = FutureProvider<TextMessageChannel>((
  ref,
) async {
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return ref.watch(settingsRepositoryProvider).fetchTextMessageChannel(groupId);
});

/// The group's outgoing-message greeting (Fixes round 2 §2.1), returned raw:
/// null when never set (the consumer seeds the localised default), '' when the
/// user cleared it (no greeting line), or the user's greeting text. The default
/// is resolved at the consumer because it is locale-dependent and this provider
/// has no BuildContext. Invalidated after a Settings edit.
final groupGreetingProvider = FutureProvider<String?>((ref) async {
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return ref.watch(settingsRepositoryProvider).fetchGreeting(groupId);
});
