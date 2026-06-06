/// Read model for a `group_supplier_settings` row — the per-group, per-
/// category messaging configuration (Specification 005 §2.2 / §2.5,
/// Specification 007 Fixes §2.1).
library;

import 'message_channel.dart';

class GroupSupplierSetting {
  const GroupSupplierSetting({
    required this.supplierCategoryId,
    this.channel,
    this.phoneAddress,
    this.emailAddress,
  });

  final String supplierCategoryId;

  /// Default outgoing channel for this category, or null for "none" (send via
  /// the share sheet). The composer picks the address matching this channel.
  final MessageChannel? channel;

  /// Phone number with international prefix (used by the WhatsApp channel).
  /// Fixes §2.1: stored independently from [emailAddress] so both can coexist.
  final String? phoneAddress;

  /// Email address (used by the Email channel). Fixes §2.1.
  final String? emailAddress;

  /// The stored address for a given channel, or null when that channel has no
  /// address (Compartir / "Cap", which use the share sheet, never carry one).
  String? addressForChannel(MessageChannel? channel) => switch (channel) {
    MessageChannel.whatsapp => phoneAddress,
    MessageChannel.email => emailAddress,
    MessageChannel.share => null,
    null => null,
  };

  /// The address matching the default [channel] — what the composer sends to
  /// unless the user overrides the channel for a single send.
  String? get defaultAddress => addressForChannel(channel);

  factory GroupSupplierSetting.fromRow(Map<String, dynamic> row) {
    return GroupSupplierSetting(
      supplierCategoryId: row['supplier_category_id'] as String,
      channel: MessageChannelWire.parse(row['channel'] as String?),
      phoneAddress: row['phone_address'] as String?,
      emailAddress: row['email_address'] as String?,
    );
  }
}
