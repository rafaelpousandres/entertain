// Guard: the client never reads `translations` without restricting the read
// to an explicit set of entity ids.
//
// Origin (November 2026): the catalog asked for "every name translation of a
// type and locale". The API cuts a response at 1000 rows without any error, so
// once enough accounts existed the recent ones no longer received their own
// rows and showed untranslated names.
import 'dart:io';

import 'package:entertain/data/translations_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reader = 'lib/data/translations_query.dart';
  final tableRead = RegExp(r'''\.from\(\s*['"]translations['"]\s*\)''');

  test('translations is read only through the filtered reader', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.path.replaceAll(r'\', '/') != reader)
        .where((f) => tableRead.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'read translations through fetchTranslationTexts ($reader), '
          'never with a direct query',
    );
  });

  test('every translations query in the reader filters by entity_id', () {
    final source = File(reader).readAsStringSync();
    final reads = tableRead.allMatches(source).toList();
    expect(reads, isNotEmpty);
    for (final read in reads) {
      // The query is the fluent chain that follows, up to its closing comma
      // or semicolon at statement level.
      final rest = source.substring(read.end);
      final chain = rest.substring(0, rest.indexOf(RegExp(r'\)\s*[,;]\n')) + 1);
      expect(
        chain,
        contains(".inFilter('entity_id',"),
        reason: 'an unfiltered translations read is cut at 1000 rows',
      );
    }
  });

  test('ids are de-duplicated and split into blocks below the row cap', () {
    final ids = [for (var i = 0; i < 250; i++) 'id-$i', 'id-0', 'id-1'];
    final blocks = translationIdBlocks(ids);
    expect(blocks.map((b) => b.length), [100, 100, 50]);
    expect(blocks.expand((b) => b).toSet().length, 250);
    expect(translationIdBlocks(const []), isEmpty);
    // Two locales per request: a block can never reach the 1000-row cap.
    expect(translationIdBlockSize * 2, lessThan(1000));
  });
}
