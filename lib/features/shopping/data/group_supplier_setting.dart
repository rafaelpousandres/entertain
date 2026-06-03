/// Read model for a `group_supplier_settings` row — the per-group, per-
/// category messaging configuration (Specification 005 §2.2 / §2.5).
library;

import 'message_channel.dart';

class GroupSupplierSetting {
  const GroupSupplierSetting({
    required this.supplierCategoryId,
    this.channel,
    this.channelAddress,
  });

  final String supplierCategoryId;

  /// Configured channel, or null for "none" (send via the share sheet).
  final MessageChannel? channel;

  /// Phone number with international prefix (WhatsApp) or email address.
  final String? channelAddress;

  factory GroupSupplierSetting.fromRow(Map<String, dynamic> row) {
    return GroupSupplierSetting(
      supplierCategoryId: row['supplier_category_id'] as String,
      channel: MessageChannelWire.parse(row['channel'] as String?),
      channelAddress: row['channel_address'] as String?,
    );
  }
}
