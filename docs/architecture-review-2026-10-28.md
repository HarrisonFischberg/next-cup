# Architecture review, 2026-10-28

Check-in run with the `improve-architecture` skill (daveebbelaar/bama), adapted
from macOS to this SwiftUI + SwiftData iPhone app. Survey only, except where a
card says it was done. Performance numbers are in `docs/perf/2026-10-28.md`.

Signals found: two files over 600 lines (`BrewFormView.swift` 839,
`RecipeDetailView.swift` 667), `BrewFormView` is the most-changed Swift file in
the last 30 days (21 commits), and no drifted `private struct` copies.

## Store lookups load whole tables  [Worth exploring]

Files: NextCup/Persistence/Store.swift (`find`, `upsert`)
Signal: slow work on the main thread that grows with the data.
Problem: the generic `find` fetches every row of a table and filters in memory.
`upsert(Brew.self, ...)` calls the generic `find` (static dispatch inside a
generic), so saving a brew loads every brew. At 1,000 brews one lookup costs
about 4 ms and an upsert about 12 to 14 ms (release build).
Proposal: give `Identified` a per-model requirement so each model builds its own
concrete predicate:

```swift
protocol Identified: PersistentModel {
  static func withID(_ id: UUID) -> FetchDescriptor<Self>
}
extension Brew {
  static func withID(_ id: UUID) -> FetchDescriptor<Brew> {
    var d = FetchDescriptor<Brew>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1; return d
  }
}
```

Why not done here: a generic `#Predicate<T> { $0.id == id }` compiles and passes
the debug unit tests but traps in a release build ("Couldn't find \BrewBean.<computed>
on BrewBean"). The per-model version touches 12 model types for a cost users
do not feel yet (one save is under 15 ms at 1,000 brews).
Proof of same behavior: PersistenceTests and DataExchangeTests, run in a
**release** build (the debug run missed the trap above).
Plan: one commit adds the requirement and the 12 conformances; one commit
switches `find`.

## Daily backup builds the whole archive on the main actor  [Strong]

Files: NextCup/Features/Settings/DataSettingsView.swift (`BackupStatus.runDaily`),
NextCup/Persistence/DataExchange.swift (`DataExporter.archive`)
Signal: slow work on the main thread.
Problem: once a day, the first launch reads every row (including bean and brew
photos, which live in external storage) on the main actor before the encode
moves to a background task. It runs in `.task`, so after the first frame, but it
still competes with the user's first scroll. Measured at 169 ms for 1,000
brews without photos (145 ms after the sort fix below), well over the skill's
50 ms main-thread budget; photos add their read time on top.
Proposal: a `@ModelActor` exporter that opens its own `ModelContext` on the
container and returns the `DataArchive` (already `Sendable` values).
Benefits: the main actor does nothing for backups.
Proof of same behavior: `DataExchangeTests` round-trip; a backup made before and
after decodes to the same archive.
Plan: one commit for the actor, one to switch `runDaily`.
Done here instead: the archive's sort now reads its keys once per row, not once
per comparison (169 → 145 ms).

## Split BrewFormView  [Speculative]

Files: NextCup/Features/Journal/BrewFormView.swift (839 lines), BrewFormModel.swift (574)
Signal: file over 600 lines, most-changed file.
Problem: the form view holds five `@Query`s and every section; any edit to one
section re-reads the whole file. Not yet at the 1,000-line action threshold, and
the model already holds the logic, so the cost is reading, not bugs.
Proposal: move each section (beans, numbers, taste, photo) into its own view
file in `Features/Journal/BrewForm/`, each taking the model.
Plan: one section per commit, no logic change.

## Considered, not recommended

- **Timer state split by update rate.** `TimerSession.publish` already limits
  view updates to whole seconds and step changes, and `BrewSceneView` runs its
  own `TimelineView`. Nothing to split.
- **Prefetching each brew's bean parts in the Journal and Explore queries.**
  Measured: no gain (Explore 5.51 → 5.65 G instructions), so it was dropped.
- **A NextCupKit-style core for Explore.** `Recommender` already lives in the
  package; `ExploreModel` is the thin adapter it should be.

- **Reading sort keys once in `JournalFilter`.** Measured: the newest-first sort
  got slower (0.56 → 0.69 ms), so it was dropped.

## Top recommendation

Move the daily backup's archive build off the main actor (the one measured
main-thread stall over 50 ms). Then Store lookups, once brews pass a few
thousand. Otherwise the code is in good shape for its size.
