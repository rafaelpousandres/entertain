import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the iOS project wiring that cannot be compiled locally (no macOS).
///
/// Origin: the first Codemagic build produced an IPA with an empty
/// CFBundleVersion because `ios/Flutter/Release.xcconfig` had lost its
/// `#include "Generated.xcconfig"` line — the only path through which
/// FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER reach the Info.plist.
void main() {
  for (final mode in ['Debug', 'Release']) {
    test('ios/Flutter/$mode.xcconfig includes Generated.xcconfig', () {
      final lines = File('ios/Flutter/$mode.xcconfig').readAsLinesSync();
      expect(lines, contains('#include "Generated.xcconfig"'));
    });
  }

  test('Info.plist takes its version from the Flutter build settings', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    String valueOf(String key) {
      final match = RegExp(
        '<key>$key</key>\\s*<string>([^<]*)</string>',
      ).firstMatch(plist);
      expect(match, isNotNull, reason: '$key is missing from Info.plist');
      return match!.group(1)!;
    }

    expect(valueOf('CFBundleVersion'), r'$(FLUTTER_BUILD_NUMBER)');
    expect(valueOf('CFBundleShortVersionString'), r'$(FLUTTER_BUILD_NAME)');
  });
}
