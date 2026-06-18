/// Presentation helpers for supplier categories in the shopping surfaces.
///
/// Supplier categories are system content whose display name comes from the
/// `translations` table (resolved by `supplierCategoriesProvider`); this file
/// only adds the icon mapping and the pantry test the panel needs. Icons are
/// Material Symbols outline glyphs, per design system §6.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../catalog/data/reference_data.dart';
import 'data/group_supplier_setting.dart';
import 'data/message_channel.dart';

/// Outline icon for a preferent message channel (Fixes round 3 §2.2): icons
/// replace the text labels in the channel selector so the four options read at a
/// glance and never truncate. Native Material glyphs only, per design system §6
/// (no external icon package). [channel] is nullable — null is "Cap" (no
/// channel). WhatsApp uses a chat-bubble glyph rather than the brand logo to
/// stay within the Material outline set.
IconData channelIcon(MessageChannel? channel) => switch (channel) {
  MessageChannel.whatsapp => Icons.chat_bubble_outline,
  MessageChannel.email => Icons.email_outlined,
  MessageChannel.share => Icons.share_outlined,
  null => Icons.do_not_disturb_alt_outlined,
};

/// System code of the pantry category seeded in
/// `20260529000000_pantry_supplier_category.sql`. The pantry section is
/// consultive only — no send action (Spec §2.3).
const String pantryCategoryCode = 'pantry';

bool isPantryCategory(String code) => code == pantryCategoryCode;

/// System codes of the two categories seeded for Spec 014 — sensible (editable)
/// defaults for bought dishes and drinks (Spec 016 §2.2 / §3.2).
const String preparedDishesCategoryCode = 'prepared';
const String beveragesCategoryCode = 'beverages';

/// Group key for catalog/shopping items with no supplier category.
const String uncategorisedGroupKey = '__uncategorised__';

/// Orders supplier-group keys for a catalog accordion (Spec 016 §4b): dispatch
/// suppliers first (alphabetical by name), then the pantry/Rebost, then the
/// uncategorised "Sense categoria" bucket — never interleaved. [categoryIds]
/// are the per-item supplier category ids (null → uncategorised); only groups
/// actually present are returned. Shared by the Ingredients and Begudes
/// catalogs so the three catalogs stay consistent.
List<String> orderedSupplierGroupKeys(
  Iterable<String?> categoryIds,
  Map<String, SupplierCategory> categoriesById,
) {
  final keys = <String>{
    for (final id in categoryIds) id ?? uncategorisedGroupKey,
  };
  return keys.toList()
    ..sort((a, b) {
      if (a == uncategorisedGroupKey) return 1;
      if (b == uncategorisedGroupKey) return -1;
      final ca = categoriesById[a];
      final cb = categoriesById[b];
      final aPantry = ca != null && isPantryCategory(ca.code);
      final bPantry = cb != null && isPantryCategory(cb.code);
      if (aPantry != bPantry) return aPantry ? 1 : -1;
      final na = ca?.name ?? '';
      final nb = cb?.name ?? '';
      return na.toLowerCase().compareTo(nb.toLowerCase());
    });
}

/// Outline icon for a supplier category, keyed by its system code.
IconData supplierCategoryIcon(String code) => switch (code) {
  'fishmonger' => Icons.set_meal_outlined,
  'butcher' => Icons.kebab_dining_outlined,
  'greengrocer' => Icons.eco_outlined,
  'supermarket' => Icons.shopping_cart_outlined,
  'pantry' => Icons.kitchen_outlined,
  _ => Icons.storefront_outlined,
};

/// Display label for a concrete supplier (Spec 013): its name when set, else
/// its default contact address, else a localised "unnamed" placeholder — so a
/// supplier configured with only a phone still reads as something in lists and
/// the order-time selector.
String supplierDisplayLabel(AppLocalizations l10n, GroupSupplierSetting s) {
  final name = s.supplierName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final address = s.defaultAddress?.trim();
  if (address != null && address.isNotEmpty) return address;
  return l10n.supplierUnnamed;
}

/// Channel + address one-liner for a supplier (list subtitles). Null when no
/// channel is configured; the share channel has no address, so just its label.
String? supplierChannelSummary(AppLocalizations l10n, GroupSupplierSetting s) {
  final channel = s.channel;
  if (channel == null) return null;
  final label = switch (channel) {
    MessageChannel.whatsapp => l10n.channelWhatsApp,
    MessageChannel.email => l10n.channelEmail,
    MessageChannel.share => l10n.channelShare,
  };
  if (channel == MessageChannel.share) return label;
  final address = s.defaultAddress?.trim() ?? '';
  return address.isEmpty ? label : '$label${l10n.metadataSeparator}$address';
}
