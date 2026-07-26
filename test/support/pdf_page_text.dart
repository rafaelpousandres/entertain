/// Test-side extraction of the text lines of each page of a generated PDF,
/// with their device-space positions.
///
/// The widowed-heading regression test (Release 1.0.29+43) needs to see the
/// *paginated* result — which text actually landed on which page, and what sits
/// at the bottom — not the widget list handed to `pw.MultiPage`. There is no
/// pure-Dart PDF text extractor to depend on, so this implements the minimal
/// subset the `pdf` package emits: Flate-compressed content streams positioned
/// with `q`/`Q`/`cm` and text drawn as `BT … Td/Tm … Tj/TJ … ET` with literal
/// (latin-1) strings — which is what the builder produces when no custom fonts
/// are loaded, as in tests.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One reconstructed line of text: all show-text ops sharing a baseline on a
/// page, joined left-to-right with single spaces.
class PdfTextLine {
  const PdfTextLine({required this.y, required this.text});

  /// Device-space baseline, PDF origin (0 = bottom of the page).
  final double y;
  final String text;

  @override
  String toString() => '(${y.toStringAsFixed(1)}) $text';
}

/// Returns, per page and sorted top → bottom, the text lines of [bytes].
List<List<PdfTextLine>> extractPdfTextLines(Uint8List bytes) {
  final raw = latin1.decode(bytes);

  // All indirect objects, body split at the `stream` keyword when present.
  final objects = <int, String>{};
  final streams = <int, String>{};
  for (final m in RegExp(r'(\d+) 0 obj(.*?)endobj', dotAll: true)
      .allMatches(raw)) {
    final id = int.parse(m.group(1)!);
    final body = m.group(2)!;
    final streamStart = RegExp(r'stream\r?\n').firstMatch(body);
    if (streamStart == null) {
      objects[id] = body;
    } else {
      objects[id] = body.substring(0, streamStart.start);
      final end = body.lastIndexOf('endstream');
      streams[id] = body.substring(streamStart.end, end);
    }
  }

  // The page tree — the `pdf` package writes a single flat /Pages node.
  final pagesEntry = objects.entries.firstWhere(
    (e) => RegExp(r'/Type\s*/Pages\b').hasMatch(e.value),
    orElse: () => throw StateError('no /Pages object found'),
  );
  final kids = RegExp(r'/Kids\s*\[([^\]]*)\]').firstMatch(pagesEntry.value);
  if (kids == null) throw StateError('no /Kids in the /Pages object');
  final pageIds = [
    for (final m in RegExp(r'(\d+) 0 R').allMatches(kids.group(1)!))
      int.parse(m.group(1)!),
  ];

  final pages = <List<PdfTextLine>>[];
  for (final pageId in pageIds) {
    final contents =
        RegExp(r'/Contents\s*(\d+) 0 R').firstMatch(objects[pageId]!);
    if (contents == null) throw StateError('page $pageId has no /Contents');
    final streamId = int.parse(contents.group(1)!);
    var data = latin1.encode(streams[streamId]!);
    if (objects[streamId]!.contains('/FlateDecode')) {
      data = Uint8List.fromList(ZLibDecoder().convert(data));
    }
    pages.add(_linesOf(_runContentStream(latin1.decode(data))));
  }
  return pages;
}

/// A PDF transformation matrix [a b c d e f] (row-vector convention).
class _Mat {
  const _Mat(this.a, this.b, this.c, this.d, this.e, this.f);
  static const identity = _Mat(1, 0, 0, 1, 0, 0);
  final double a, b, c, d, e, f;

  /// `this × other` in PDF order (this applied first).
  _Mat mul(_Mat o) => _Mat(
        a * o.a + b * o.c,
        a * o.b + b * o.d,
        c * o.a + d * o.c,
        c * o.b + d * o.d,
        e * o.a + f * o.c + o.e,
        e * o.b + f * o.d + o.f,
      );
}

class _TextItem {
  const _TextItem(this.x, this.y, this.text);
  final double x;
  final double y;
  final String text;
}

/// Interprets the subset of content-stream operators that affect where text is
/// shown, returning every show-text op with its device position.
List<_TextItem> _runContentStream(String content) {
  final items = <_TextItem>[];
  final ctmStack = <_Mat>[];
  var ctm = _Mat.identity;
  var tlm = _Mat.identity;
  final operands = <Object>[];

  void show(String text) {
    if (text.isEmpty) return;
    final m = tlm.mul(ctm);
    items.add(_TextItem(m.e, m.f, text));
  }

  double num_(Object o) => (o as num).toDouble();

  var i = 0;
  while (i < content.length) {
    final ch = content[i];
    if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
      i++;
    } else if (ch == '(') {
      final (s, next) = _parseLiteralString(content, i);
      operands.add(s);
      i = next;
    } else if (ch == '<' && i + 1 < content.length && content[i + 1] != '<') {
      final end = content.indexOf('>', i);
      final hex = content.substring(i + 1, end).replaceAll(RegExp(r'\s'), '');
      final chars = <int>[
        for (var j = 0; j + 1 < hex.length; j += 2)
          int.parse(hex.substring(j, j + 2), radix: 16),
      ];
      operands.add(latin1.decode(chars));
      i = end + 1;
    } else if (ch == '[') {
      operands.add('[');
      i++;
    } else if (ch == ']') {
      // Collapse the array into the concatenation of its string elements
      // (the kerning numbers of a TJ array are irrelevant here).
      final start = operands.lastIndexOf('[');
      final parts = operands.sublist(start + 1).whereType<String>();
      final joined = parts.join();
      operands.removeRange(start, operands.length);
      operands.add(joined);
      i++;
    } else if (ch == '/') {
      final m = RegExp(r'/[^\s()<>\[\]/]*').matchAsPrefix(content, i)!;
      operands.add(m.group(0)!);
      i = m.end;
    } else if (RegExp(r'[-+.0-9]').hasMatch(ch)) {
      final m = RegExp(r'[-+]?[0-9]*\.?[0-9]+').matchAsPrefix(content, i)!;
      operands.add(double.parse(m.group(0)!));
      i = m.end;
    } else {
      final m = RegExp(r"[A-Za-z'\x22*]+").matchAsPrefix(content, i);
      if (m == null) {
        i++; // unknown byte (e.g. << >> dict delimiters) — skip
        continue;
      }
      final op = m.group(0)!;
      i = m.end;
      switch (op) {
        case 'q':
          ctmStack.add(ctm);
        case 'Q':
          if (ctmStack.isNotEmpty) ctm = ctmStack.removeLast();
        case 'cm':
          final n = operands.length;
          ctm = _Mat(
            num_(operands[n - 6]),
            num_(operands[n - 5]),
            num_(operands[n - 4]),
            num_(operands[n - 3]),
            num_(operands[n - 2]),
            num_(operands[n - 1]),
          ).mul(ctm);
        case 'BT':
          tlm = _Mat.identity;
        case 'Tm':
          final n = operands.length;
          tlm = _Mat(
            num_(operands[n - 6]),
            num_(operands[n - 5]),
            num_(operands[n - 4]),
            num_(operands[n - 3]),
            num_(operands[n - 2]),
            num_(operands[n - 1]),
          );
        case 'Td' || 'TD':
          final n = operands.length;
          tlm = _Mat(1, 0, 0, 1, num_(operands[n - 2]), num_(operands[n - 1]))
              .mul(tlm);
        case 'Tj' || "'":
          show(operands.last as String);
        case 'TJ':
          show(operands.last as String);
        default:
          break; // painting/state op with no effect on text position
      }
      operands.clear();
    }
  }
  return items;
}

/// Parses a `(…)` literal string starting at [start]; returns the decoded text
/// and the index just past the closing paren. Handles nesting and `\` escapes.
(String, int) _parseLiteralString(String content, int start) {
  final buf = StringBuffer();
  var depth = 0;
  var i = start;
  while (i < content.length) {
    final ch = content[i];
    if (ch == r'\') {
      final next = content[i + 1];
      if (RegExp(r'[0-7]').hasMatch(next)) {
        final m = RegExp(r'[0-7]{1,3}').matchAsPrefix(content, i + 1)!;
        buf.writeCharCode(int.parse(m.group(0)!, radix: 8));
        i = m.end;
      } else {
        buf.write(switch (next) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          _ => next, // \( \) \\ and friends
        });
        i += 2;
      }
    } else if (ch == '(') {
      depth++;
      if (depth > 1) buf.write(ch);
      i++;
    } else if (ch == ')') {
      depth--;
      if (depth == 0) return (buf.toString(), i + 1);
      buf.write(ch);
      i++;
    } else {
      buf.write(ch);
      i++;
    }
  }
  throw StateError('unterminated string literal');
}

/// Groups the raw show-text items of one page into visual lines (shared
/// baseline within half a point), left → right, and sorts them top → bottom.
List<PdfTextLine> _linesOf(List<_TextItem> items) {
  final sorted = [...items]..sort((p, q) => q.y.compareTo(p.y));
  final lines = <PdfTextLine>[];
  var start = 0;
  for (var i = 1; i <= sorted.length; i++) {
    if (i == sorted.length || (sorted[start].y - sorted[i].y).abs() > 0.5) {
      final line = sorted.sublist(start, i)
        ..sort((p, q) => p.x.compareTo(q.x));
      lines.add(PdfTextLine(
        y: sorted[start].y,
        text: line.map((t) => t.text).join(' '),
      ));
      start = i;
    }
  }
  return lines;
}
