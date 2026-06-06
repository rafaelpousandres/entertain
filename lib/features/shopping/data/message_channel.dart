/// Outgoing message channel — mirrors the Postgres `message_channel` enum
/// (Specification 005 migration). `none` is the UI-only "send via the system
/// share sheet" option; it has no wire value (the column is simply null).
library;

enum MessageChannel { whatsapp, email }

extension MessageChannelWire on MessageChannel {
  String get wire => switch (this) {
    MessageChannel.whatsapp => 'whatsapp',
    MessageChannel.email => 'email',
  };

  /// Parses the nullable wire value; null (no configured channel) maps to
  /// null, meaning "use the share sheet".
  static MessageChannel? parse(String? value) => switch (value) {
    'whatsapp' => MessageChannel.whatsapp,
    'email' => MessageChannel.email,
    _ => null,
  };
}
