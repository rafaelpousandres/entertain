import 'hint.dart';

/// Spec 026 A.2 — pure hint-selection helpers (no I/O, unit-tested).
///
/// [randomIndex] returns an int in `[0, n)`; production passes
/// `Random().nextInt`, tests pass a deterministic stub.
typedef RandomIndex = int Function(int n);

/// The hint to show on this open: the **welcome** hint the first ever time
/// (when [welcomeSeen] is false and a welcome exists), otherwise a **random
/// tip**. Returns null only when there is nothing to show.
Hint? entryHint(
  List<Hint> hints, {
  required bool welcomeSeen,
  required RandomIndex randomIndex,
}) {
  if (!welcomeSeen) {
    for (final h in hints) {
      if (h.kind == HintKind.welcome) return h;
    }
  }
  return randomTip(hints, randomIndex: randomIndex);
}

/// Spec 026 A.4 — a hint's display text: the app-locale translation, falling
/// back to Catalan, then empty (an empty result means the hint has no usable
/// translation and is dropped).
String mergeHintText(
  Map<String, String> local,
  Map<String, String> ca,
  String id,
) => (local[id] ?? ca[id] ?? '').trim();

/// A random `tip` hint, avoiding [excludeKey] when another tip is available (so
/// "Més…" advances rather than repeating). Returns null when there are no tips.
Hint? randomTip(
  List<Hint> hints, {
  required RandomIndex randomIndex,
  String? excludeKey,
}) {
  final tips = [for (final h in hints) if (h.kind == HintKind.tip) h];
  if (tips.isEmpty) return null;
  final pool = excludeKey == null
      ? tips
      : [for (final h in tips) if (h.key != excludeKey) h];
  final from = pool.isEmpty ? tips : pool;
  return from[randomIndex(from.length)];
}
