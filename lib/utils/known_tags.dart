import '../repository/grow_repository.dart';

/// Q7 — Distinct sorted tag pool across every plant + note.
///
/// Used by the `TagEditor` suggestion strip on the Add Note and Edit
/// Plant sheets so growers can re-pick from their existing taxonomy
/// instead of typing fresh labels every time.
///
/// Lives in `lib/utils/` (not on `GrowRepository`) because it's a pure
/// derivation — cheap enough to recompute on each dialog open, and
/// belonging on the repo would add another caller-facing method for
/// a one-off UI concern.
List<String> allKnownTags(GrowRepository repo) {
  final set = <String>{};
  for (final n in repo.notes) {
    set.addAll(n.tags);
  }
  for (final pl in repo.plants) {
    set.addAll(pl.tags);
  }
  final list = set.toList()..sort();
  return list;
}
