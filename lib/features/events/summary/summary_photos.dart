/// Spec 034 §C3 — the photos beyond the cover that go into the event summary
/// PDF.
///
/// The summary keeps each entity's first photo as its cover exactly as before
/// and adds **all** the remaining ones as small thumbnails (no cap, no "+N").
/// More photos must not bloat the file or the build time, so the more extras
/// an entity has, the smaller they print and the smaller they are embedded.
library;

/// Every photo after the cover, in carousel order.
List<String> secondaryPhotoPaths(List<String>? allPaths) {
  if (allPaths == null || allPaths.length < 2) return const <String>[];
  return allPaths.sublist(1);
}

/// Printed size (pt) of the event's secondary thumbnails for [count] of them:
/// clearly visible, clearly subordinate to the 150 pt cover, shrinking as the
/// strip grows so many photos take few rows.
double summaryEventThumbSize(int count) {
  if (count <= 8) return 56;
  if (count <= 20) return 44;
  return 36;
}

/// Printed size (pt) of a dish's secondary thumbnails for [count] of them,
/// subordinate to the 70 pt dish photo.
double summaryDishThumbSize(int count) {
  if (count <= 4) return 34;
  if (count <= 12) return 28;
  return 24;
}

/// Longest edge, in px, at which a secondary thumbnail is embedded when its
/// entity has [count] of them. They print at under 60 pt, so even the smaller
/// edge is ample at print DPI and a fraction of the cover's 1000 px.
int summaryThumbMaxEdge(int count) => count <= 8 ? 300 : 200;
