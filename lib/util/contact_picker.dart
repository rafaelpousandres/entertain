/// Contact picker for supplier categories (Spec 009 §2.3).
///
/// Wraps the `READ_CONTACTS` permission flow and the native contact picker
/// behind one call so the screen stays declarative. The permission is only
/// ever requested here — when the user explicitly taps "Pick from contacts" —
/// never at app launch (§2.3).
///
/// The same flow runs on Android and iOS (Spec 035); iOS additionally needs
/// the `NSContactsUsageDescription` string in Info.plist.
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

  // The native picker returns the chosen contact already populated with the
  // requested properties (flutter_contacts 2.x), so no refetch is needed. On
  // Android, asking for properties requires READ_CONTACTS — granted above.
  final picked = await FlutterContacts.native.showPicker(
    properties: const {ContactProperty.phone, ContactProperty.email},
  );
  if (picked == null) {
    return const ContactPickResult(ContactPickStatus.cancelled);
  }

  final name = (picked.displayName ?? '').trim();
  return ContactPickResult(
    ContactPickStatus.picked,
    PickedContact(
      name: name.isEmpty ? null : name,
      phones: _dedup(picked.phones.map((p) => p.number)),
      emails: _dedup(picked.emails.map((e) => e.address)),
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
