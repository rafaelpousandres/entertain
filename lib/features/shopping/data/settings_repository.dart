import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_supplier_setting.dart';
import 'message_channel.dart';

/// Data-access wrapper for the Settings screen (Specification 005 §2.5):
/// the group-level signature on `groups`, and the per-category messaging
/// configuration in the `group_supplier_settings` companion table.
class SettingsRepository {
  SettingsRepository(this._client);

  final SupabaseClient _client;

  /// Per-category configuration rows for the group.
  Future<List<GroupSupplierSetting>> listSettings(String groupId) async {
    final rows = await _client
        .from('group_supplier_settings')
        .select(
          'supplier_category_id, channel, phone_address, email_address, '
          'supplier_name',
        )
        .eq('group_id', groupId);
    return [
      for (final r in rows as List)
        GroupSupplierSetting.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// Inserts or updates the configuration for one category. Keyed on the
  /// `(group_id, supplier_category_id)` unique constraint so editing the
  /// same category repeatedly never creates duplicate rows.
  ///
  /// Fixes §2.1: phone and email are stored independently; [channel] only marks
  /// which one is the default for outgoing messages.
  Future<void> upsertSetting({
    required String groupId,
    required String supplierCategoryId,
    required MessageChannel? channel,
    required String? phoneAddress,
    required String? emailAddress,
    required String? supplierName,
  }) async {
    await _client.from('group_supplier_settings').upsert({
      'group_id': groupId,
      'supplier_category_id': supplierCategoryId,
      'channel': channel?.wire,
      'phone_address': phoneAddress,
      'email_address': emailAddress,
      // Spec 008 §2.3: the concrete supplier name, per group.
      'supplier_name': supplierName,
    }, onConflict: 'group_id,supplier_category_id');
  }

  /// The group's stored signature (null when never set).
  Future<String?> fetchSignature(String groupId) async {
    final row = await _client
        .from('groups')
        .select('signature')
        .eq('id', groupId)
        .maybeSingle();
    return row?['signature'] as String?;
  }

  Future<void> updateSignature(String groupId, String? signature) async {
    await _client
        .from('groups')
        .update({'signature': signature})
        .eq('id', groupId);
  }

  /// The group's stored greeting (Fixes round 2 §2.1). Returns the raw column
  /// value so the caller can tell the three states apart: null (never set —
  /// seed the localised default), '' (cleared — no greeting line), or the
  /// user's greeting text.
  Future<String?> fetchGreeting(String groupId) async {
    final row = await _client
        .from('groups')
        .select('greeting')
        .eq('id', groupId)
        .maybeSingle();
    return row?['greeting'] as String?;
  }

  /// Persists the greeting exactly as given, including the empty string. Unlike
  /// the signature, an empty greeting is stored as '' (not null) so that a user
  /// who deliberately clears it keeps it cleared instead of falling back to the
  /// default on the next load.
  Future<void> updateGreeting(String groupId, String greeting) async {
    await _client
        .from('groups')
        .update({'greeting': greeting})
        .eq('id', groupId);
  }

  /// The group's text-message channel (Spec 008 §2.9): which app a "text"
  /// dispatch resolves to. Defaults to WhatsApp for a missing row / column.
  Future<TextMessageChannel> fetchTextMessageChannel(String groupId) async {
    final row = await _client
        .from('groups')
        .select('text_message_channel')
        .eq('id', groupId)
        .maybeSingle();
    return TextMessageChannelWire.parse(
      row?['text_message_channel'] as String?,
    );
  }

  Future<void> updateTextMessageChannel(
    String groupId,
    TextMessageChannel channel,
  ) async {
    await _client
        .from('groups')
        .update({'text_message_channel': channel.wire})
        .eq('id', groupId);
  }

  /// The current user's `profiles.display_name`, used as the default
  /// signature the first time the Settings screen is shown (Spec §2.5).
  Future<String?> fetchProfileDisplayName() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', user.id)
        .maybeSingle();
    return row?['display_name'] as String?;
  }
}
