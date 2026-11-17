// Guard: no table may be left readable by every signed-in user by accident.
//
// Replays the Supabase migrations in order and looks at the row-level-security
// policies that are in force at the end. A policy whose condition is the bare
// `using (true)` exposes every row of its table to every authenticated user;
// that is only acceptable for tables holding nothing but shared system content.
//
// Origin (November 2026): `translations` started as system content with an open
// policy, later also received each group's own ingredient/dish/drink names, and
// the policy was never revisited — a cross-account leak, and (through the API's
// 1000-row cap on the unfiltered read) untranslated catalogs on recent accounts.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tables that hold ONLY shared, non-personal system content. Adding a table
/// here is a deliberate statement that none of its rows belongs to a group.
const _openByDesign = {'units', 'hints', 'quota_defaults', 'demo_event_i18n'};

class _Policy {
  _Policy(this.table, this.name, this.body, this.file);
  final String table;
  final String name;
  final String body;
  final String file;

  bool get isSelectable =>
      RegExp(r'\bfor\s+(select|all)\b', caseSensitive: false).hasMatch(body) ||
      !RegExp(r'\bfor\s+\w+', caseSensitive: false).hasMatch(body);

  bool get isOpen =>
      RegExp(r'\busing\s*\(\s*true\s*\)', caseSensitive: false).hasMatch(body);
}

/// The policies in force after applying every migration in filename order.
Map<String, _Policy> _finalPolicies() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  expect(files, isNotEmpty, reason: 'run the test from the repository root');

  final statement = RegExp(
    r'(create|drop|alter)\s+policy\s+(?:if\s+exists\s+)?"?(\w+)"?\s+on\s+(?:public\.)?"?(\w+)"?([^;]*);',
    caseSensitive: false,
  );
  final policies = <String, _Policy>{};
  for (final file in files) {
    // Drop `--` comments so prose mentioning a policy is not parsed as SQL.
    final sql = file
        .readAsLinesSync()
        .map((l) => l.replaceFirst(RegExp(r'--.*$'), ''))
        .join('\n');
    for (final m in statement.allMatches(sql)) {
      final verb = m.group(1)!.toLowerCase();
      final key = '${m.group(3)!.toLowerCase()}.${m.group(2)!.toLowerCase()}';
      if (verb == 'drop') {
        policies.remove(key);
      } else {
        policies[key] = _Policy(
          m.group(3)!.toLowerCase(),
          m.group(2)!.toLowerCase(),
          m.group(4)!,
          file.uri.pathSegments.last,
        );
      }
    }
  }
  return policies;
}

void main() {
  test('translations is not readable by every authenticated user', () {
    final selects = _finalPolicies().values
        .where((p) => p.table == 'translations' && p.isSelectable)
        .toList();
    expect(
      selects,
      isNotEmpty,
      reason: 'translations must keep a SELECT policy (clients read it)',
    );
    for (final p in selects) {
      expect(
        p.isOpen,
        isFalse,
        reason:
            '${p.name} (${p.file}) is `using (true)`: translations holds '
            "every group's own catalog names and must be scoped",
      );
    }
  });

  test('only system-content tables have an open (using true) policy', () {
    final offenders = _finalPolicies().values
        .where((p) => p.isOpen && !_openByDesign.contains(p.table))
        .map((p) => '${p.table}.${p.name} (${p.file})')
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'these policies expose every row to every signed-in user; scope '
          'them, or add the table to _openByDesign if it truly holds only '
          'shared system content',
    );
  });
}
