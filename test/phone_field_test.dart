import 'package:entertain/features/shopping/widgets/phone_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 009 §3.2 — the supplier phone prefix moved from a hand-curated short
/// list to the `intl_phone_field` worldwide country data. These lock the
/// E.164 split / compose / validate helpers that the supplier screen relies on
/// against that data, so the stored `+NN…` round-trips stay intact.
void main() {
  group('splitStoredPhone', () {
    test('splits a stored E.164 number into dial code + local part', () {
      final split = splitStoredPhone('+34600123456');
      expect(split.dialCode, '+34');
      expect(split.local, '600123456');
    });

    test('matches the longest dial code (+351 over +3…)', () {
      final split = splitStoredPhone('+351912345678');
      expect(split.dialCode, '+351');
      expect(split.local, '912345678');
    });

    test('empty value falls back to the default dial code, no local part', () {
      final split = splitStoredPhone(null);
      expect(split.dialCode.startsWith('+'), isTrue);
      expect(split.local, '');
    });

    test('a value with no recognised prefix keeps the whole string as local', () {
      final split = splitStoredPhone('600123456');
      expect(split.local, '600123456');
    });
  });

  group('composeStoredPhone', () {
    test('recombines prefix + local digits into E.164', () {
      expect(composeStoredPhone('+34', '600 123 456'), '+34600123456');
    });

    test('blank local part yields an empty string (stored as null upstream)', () {
      expect(composeStoredPhone('+34', '  '), '');
    });

    test('round-trips a split number unchanged', () {
      const stored = '+33612345678';
      final split = splitStoredPhone(stored);
      expect(composeStoredPhone(split.dialCode, split.local), stored);
    });
  });

  group('isValidLocalPhone', () {
    test('accepts 6–15 digits, ignoring separators', () {
      expect(isValidLocalPhone('600 12 34'), isTrue);
      expect(isValidLocalPhone('600123456'), isTrue);
    });

    test('rejects too-short and too-long numbers', () {
      expect(isValidLocalPhone('123'), isFalse);
      expect(isValidLocalPhone('1234567890123456'), isFalse);
    });
  });

  group('isoForDialCode', () {
    test('resolves a unique dial code to its country', () {
      expect(isoForDialCode('+34'), 'ES');
      expect(isoForDialCode('+351'), 'PT');
    });

    test('default dial code is a valid +NN string', () {
      expect(defaultPhoneDialCode().startsWith('+'), isTrue);
    });
  });
}
