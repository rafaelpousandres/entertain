import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'message_channel.dart';

/// What was actually used to dispatch the message — persisted on the order
/// (Spec §2.4). When the share sheet handled it, both are null.
class DispatchOutcome {
  const DispatchOutcome({this.channel, this.address});

  final MessageChannel? channel;
  final String? address;
}

/// Dispatches a composed supplier message (Spec §2.4):
///
///   * WhatsApp with a configured number → `https://wa.me/<digits>?text=…`.
///   * Email with a configured address → the default mail client via
///     `mailto:` with subject and body pre-filled.
///   * Otherwise (no channel, no address, or the launch failed) → the system
///     share sheet, letting the user pick a destination at that moment.
///
/// Returns the channel / address effectively used so the caller can persist
/// it on the order.
Future<DispatchOutcome> dispatchMessage({
  required MessageChannel? channel,
  required String? address,
  required String subject,
  required String body,
}) async {
  final trimmedAddress = address?.trim() ?? '';

  if (channel == MessageChannel.whatsapp && trimmedAddress.isNotEmpty) {
    final digits = trimmedAddress.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(body)}',
    );
    if (await _tryLaunch(uri)) {
      return DispatchOutcome(channel: channel, address: trimmedAddress);
    }
  } else if (channel == MessageChannel.email && trimmedAddress.isNotEmpty) {
    final uri = Uri.parse(
      'mailto:$trimmedAddress'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
    if (await _tryLaunch(uri)) {
      return DispatchOutcome(channel: channel, address: trimmedAddress);
    }
  }

  // No configured channel, or the launch failed: fall back to the share
  // sheet. The destination is then whatever the user picks, unknown to us.
  await SharePlus.instance.share(ShareParams(text: body, subject: subject));
  return const DispatchOutcome();
}

Future<bool> _tryLaunch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
