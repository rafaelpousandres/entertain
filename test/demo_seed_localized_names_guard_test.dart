// Guard: the demo clone must write the event-line name copies in the account's
// language.
//
// Each demo event line stores a COPY of its dish / ingredient / drink name.
// The first seed_demo copied them verbatim from the English template, so
// Catalan and Spanish accounts saw their demo events in English (November
// 2026). The definition of `_seed_demo_into` in force — the last one across
// the migrations — must route the three copies through `_demo_line_name`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed_demo writes event-line name copies through _demo_line_name', () {
    final files =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final definition = RegExp(
      r'create or replace function public\._seed_demo_into[\s\S]*?\n\$\$;',
      caseSensitive: false,
    );
    String? inForce;
    for (final file in files) {
      final matches = definition.allMatches(file.readAsStringSync());
      if (matches.isNotEmpty) inForce = matches.last.group(0);
    }

    expect(inForce, isNotNull, reason: '_seed_demo_into is never defined');
    for (final call in const [
      "_demo_line_name('dish', ed.source_dish_id, v_locale, ed.dish_name)",
      "_demo_line_name('ingredient', edi.ingredient_id, v_locale, edi.ingredient_name)",
      "_demo_line_name('drink', edk.source_drink_id, v_locale, edk.drink_name)",
    ]) {
      expect(
        inForce,
        contains(call),
        reason: 'the demo clone copies a line name untranslated: $call',
      );
    }
  });
}
