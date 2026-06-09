/// Contact picker for supplier categories (Spec 009 §2.3).
///
/// Wraps the `READ_CONTACTS` permission flow and the native contact picker
/// behind one call so the screen stays declarative. The permission is only
/// ever requested here — when the user explicitly taps "Pick from contacts" —
/// never at app launch (§2.3).
///
/// iOS is out of scope this round (§2.3); the flow is Android-shaped but the
/// packages are cross-platform, so an iOS pass later only needs the Info.plist
/// usage string.
library;

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// How a [pickContact] attempt ended.
enum ContactPickStatus {
  /// A contact was picked; [ContactPickResult.contact] is populated.
  picked,

  /// The user dismissed the native picker without choosing.
  cancelled,

  /// Permission was denied this time (the user can try again).
  denied,

  /// Permission was denied permanently ("don't ask again"); the only way back
  /// is the system settings page.
  permanentlyDenied,
}

/// The fields extracted from a picked contact. Phones and emails are
/// de-duplicated, order-preserving; the screen decides what to do when either
/// list has more than one entry (§2.3 selection dialog).
class PickedContact {
  const PickedContact({
    required this.name,
    required this.phones,
    required this.emails,
  });

  final String? name;
  final List<String> phones;
  final List<String> emails;
}

class ContactPickResult {
  const ContactPickResult(this.status, [this.contact]);

  final ContactPickStatus status;
  final PickedContact? contact;
}

/// Requests contacts permission (if not already granted) and opens the device
/// contact picker. Returns the picked contact's name, phones and emails, or a
/// status explaining why nothing was picked.
Future<ContactPickResult> pickContact() async {
  final status = await Permission.contacts.request();
  if (status.isPermanentlyDenied || status.isRestricted) {
    return const ContactPickResult(ContactPickStatus.permanentlyDenied);
  }
  if (!status.isGranted) {
    return const ContactPickResult(ContactPickStatus.denied);
  }

  // ACTION_PICK returns the chosen contact; refetch with properties so phones
  // and emails are fully populated regardless of what the picker inlined.
  final picked = await FlutterContacts.openExternalPick();
  if (picked == null) {
    return const ContactPickResult(ContactPickStatus.cancelled);
  }
  final full =
      await FlutterContacts.getContact(picked.id, withProperties: true) ??
      picked;

  final name = full.displayName.trim();
  return ContactPickResult(
    ContactPickStatus.picked,
    PickedContact(
      name: name.isEmpty ? null : name,
      phones: _dedup(full.phones.map((p) => p.number)),
      emails: _dedup(full.emails.map((e) => e.address)),
    ),
  );
}

/// Trims, drops blanks, and removes duplicates while preserving first-seen
/// order — contacts often carry the same number twice (mobile + WhatsApp).
List<String> _dedup(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in values) {
    final value = raw.trim();
    if (value.isEmpty || !seen.add(value)) continue;
    result.add(value);
  }
  return result;
}
