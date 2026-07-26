import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The versionCode convention (adopted after versionCode 43 was burned on an
/// AAB that never shipped): the code is DERIVED from the version name,
///
///     versionCode = major * 10000 + minor * 100 + patch
///
/// so 1.0.29 → 10029, 1.1.0 → 10100, 2.0.0 → 20000. Codes always grow with the
/// name, never collide with the old hand-counted series (≤ 43), and there is
/// exactly one right answer per release — no Play Console archaeology.
///
/// This guard fails the suite whenever `pubspec.yaml` carries a build number
/// that the formula does not derive from its own version name. Android takes
/// both values from pubspec (`flutter.versionCode` / `flutter.versionName` in
/// android/app/build.gradle), so pubspec is the single source of truth.
void main() {
  test('pubspec versionCode is derived from the version name', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(
      r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(m, isNotNull,
        reason: 'pubspec.yaml must declare version: <major>.<minor>.<patch>+<code>');

    final major = int.parse(m!.group(1)!);
    final minor = int.parse(m.group(2)!);
    final patch = int.parse(m.group(3)!);
    final code = int.parse(m.group(4)!);

    expect(minor, lessThan(100),
        reason: 'the formula reserves two digits for minor');
    expect(patch, lessThan(100),
        reason: 'the formula reserves two digits for patch');
    expect(
      code,
      major * 10000 + minor * 100 + patch,
      reason: 'versionCode must be major*10000 + minor*100 + patch of the '
          'version name (e.g. 1.0.29 → 10029). Fix pubspec.yaml, do not '
          'hand-pick codes.',
    );
  });
}
