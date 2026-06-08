/// Outgoing message channel — mirrors the Postgres `message_channel` enum
/// (Specification 005 migration, extended with `share` in Fixes round 2 §2.3).
///
/// The preferred channel for a supplier category is now one of four choices:
///   * [whatsapp] / [email] — a direct channel to the stored address.
///   * [share] ("Compartir") — explicitly dispatch through the OS share sheet,
///     no stored address required; the user picks the destination at send time.
///   * null ("Cap") — no preferred channel configured.
///
/// Both [share] and null fall back to the share sheet at dispatch time (only
/// WhatsApp/Email are special-cased), but they are distinct *preferences*:
/// `share` is a deliberate choice, null is "not set yet".
library;

enum MessageChannel { whatsapp, email, share }

/// Group-level text-message channel (Specification 008 §2.9) — which app a
/// "text" dispatch resolves to. Mirrors the `groups.text_message_channel`
/// column (CHECK-constrained to these two values). The per-supplier
/// [MessageChannel.whatsapp] preference now means "use the group's configured
/// text channel"; this enum says which one that is.
enum TextMessageChannel { sms, whatsapp }

extension TextMessageChannelWire on TextMessageChannel {
  String get wire => switch (this) {
    TextMessageChannel.sms => 'sms',
    TextMessageChannel.whatsapp => 'whatsapp',
  };

  /// Parses the stored value, defaulting to [TextMessageChannel.whatsapp]
  /// (the column default and the historical behaviour) for null / unknown.
  static TextMessageChannel parse(String? value) =>
      value == 'sms' ? TextMessageChannel.sms : TextMessageChannel.whatsapp;
}

extension MessageChannelWire on MessageChannel {
  String get wire => switch (this) {
    MessageChannel.whatsapp => 'whatsapp',
    MessageChannel.email => 'email',
    MessageChannel.share => 'share',
  };

  /// Parses the nullable wire value; null (no configured channel) maps to
  /// null, meaning "Cap" — which, like `share`, uses the share sheet.
  static MessageChannel? parse(String? value) => switch (value) {
    'whatsapp' => MessageChannel.whatsapp,
    'email' => MessageChannel.email,
    'share' => MessageChannel.share,
    _ => null,
  };
}
