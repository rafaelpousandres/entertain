/// Spec 034 §C3 — which photos beyond the cover go into the event summary PDF.
///
/// The summary keeps each entity's first photo as its cover exactly as before
/// and adds the remaining ones as small thumbnails. More photos must not bloat
/// the file or the build time, so the extras are capped per entity and embedded
/// at a much smaller edge than the cover; anything past the cap is reported as
/// an overflow count the PDF shows as "+N".
library;

/// Extra (non-cover) event photos shown under the cover.
const int kSummaryEventExtraPhotos = 8;

/// Extra (non-cover) photos shown under each dish.
const int kSummaryDishExtraPhotos = 4;

/// Longest edge, in px, of an embedded secondary thumbnail. They print at well
/// under 60 pt, so this is ample at print DPI and a fraction of the cover's
/// 1000 px.
const int kSummaryThumbMaxEdge = 300;

/// Splits an entity's photo paths (carousel order, cover first) into the
/// secondary ones to embed — everything after the cover, at most [max] — and
/// the count left out.
({List<String> paths, int overflow}) secondaryPhotoPaths(
  List<String>? allPaths, {
  required int max,
}) {
  if (allPaths == null || allPaths.length < 2) {
    return (paths: const <String>[], overflow: 0);
  }
  final rest = allPaths.sublist(1);
  if (rest.length <= max) return (paths: rest, overflow: 0);
  return (paths: rest.sublist(0, max), overflow: rest.length - max);
}
