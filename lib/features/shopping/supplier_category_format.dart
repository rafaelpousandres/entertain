/// Presentation helpers for supplier categories in the shopping surfaces.
///
/// Supplier categories are system content whose display name comes from the
/// `translations` table (resolved by `supplierCategoriesProvider`); this file
/// only adds the icon mapping and the pantry test the panel needs. Icons are
/// Material Symbols outline glyphs, per design system §6.
library;

import 'package:flutter/material.dart';

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

/// Outline icon for a supplier category, keyed by its system code.
IconData supplierCategoryIcon(String code) => switch (code) {
  'fishmonger' => Icons.set_meal_outlined,
  'butcher' => Icons.kebab_dining_outlined,
  'greengrocer' => Icons.eco_outlined,
  'supermarket' => Icons.shopping_cart_outlined,
  'pantry' => Icons.kitchen_outlined,
  _ => Icons.storefront_outlined,
};
