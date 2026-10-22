# Activity log

## 2026-10-21 — scaffold

- Created project skeleton under the `new-app` skill.
- Next: Phase 0 intake and tool-environment verification.

## 2026-10-21 — Phase 2 discovery

- Verified REA with real calls (see `docs/tool-environment.md`).
- Owner supplied the three reference URLs. REA passive page inspection ran on
  all three first, then Replica recon from the same public pages.
- Wrote sanitized `docs/rea-findings.md`; added discovery candidates to
  `docs/data-inventory.md`; added blockers B007–B010 and a jurisdiction
  section to `docs/launch-blockers.md`.
- Draft recon, feature matrix and best-of comparison are in the lab folder
  (not in the repo) pending owner approval (B007) and review research (B008).
- Review research (`/replica-entrepreneur`): 151 items via official feeds and
  APIs only, every quote verified verbatim against its link. Fix plan X1–X8
  and three positioning angles written in the lab (`fixes.md`), 9 rows added
  to the lab feature matrix. Owner decisions recorded: comparison approved
  as written, creator channel deferred to the import build.
- Final spec merged (approved comparison + fixes X1–X8 + positioning
  default A) with 10 per-feature build prompts. Phase 2B: copied only the
  neutral spec files into `replica/` (recon, features, comparison, prompts),
  filled `replica/README.md` intentional differences, sweep clean, then
  deleted the lab folder with the owner's yes (2026-10-21). From here on,
  work only from `replica/`.

## 2026-10-21 — Phase 3 blueprint (Opus)

- Ran `replica-architect` against `replica/` (adapted to SwiftData; no SQL
  or server routes). Wrote `replica/architecture.md`.
- Wrote `docs/blueprint.md`: stack (SwiftUI, Swift 6.4, iOS 27, SwiftData
  CloudKit-compatible, zero third-party packages), 12 models, internal
  services, outbound calls, folders, state, vendors, parts that bite, and the
  permission changes Phase 4 would need.
- Rewrote `prd.md`: ranked features, non-goals, Phase 3B core flow (F01),
  verification commands, 30 atomic tasks with dependencies, safeguard map.
- Checked host: xcodegen, tuist, swiftlint absent; `swift format` present;
  only the iOS 27 simulator runtime installed (drove the iOS 27 minimum).
- Waiting on owner approval (B011). Nothing deployed or changed externally
  beyond the PR.

## 2026-10-21 — Phase 3B design directions (Sonnet)

- Phase 3 blueprint approved and merged (PR #1).
- Built `design/Shared` (one flow model, sample data, timer, validation, shell)
  and five concept presentations, one git worktree and local branch each
  (`ui-1`..`ui-5`, never pushed). Base branch `design-base`.
- Screenshots (light/dark x default/largest text), critique, one fix batch per
  concept, re-capture. Contrast computed; three failures found and fixed.
- One live walkthrough (concept 4) found a safe-area bleed bug and a missing
  verdict in the journal; both fixed.
- Not done: VoiceOver, Reduce Motion, landscape, performance. Owner picked Steel & Kraft; other four archived as text, worktrees and
  `ui-*` branches removed. Next: Phase 3C design system.

## 2026-10-21 — Phase 3C design system (Sonnet)

- Owner picked Steel & Kraft; PR #2 (direction and evidence) open.
- Wrote `DESIGN.md`, token JSON (light, dark), `design/DesignSystem/` (tokens,
  15 components, gallery), moved the concept screens onto it, `design/check_tokens.py`.
- Contrast: 0 failing AA in either appearance. Gallery shot in light/dark at
  default and largest text; it exposed component reflow bugs, fixed and re-shot.
- Not done: VoiceOver, focus ring, journal Undo. `/impeccable extract` and
  `polish` were applied by hand to this scope (no browser tooling for native).

## 2026-10-21 — Phase 4 setup (Sonnet)

- Cloned and reviewed the Ralph quickstart (no license, nothing copied). Wrote
  `ralph/ralph.sh`, `ralph/REVIEW.md`, iOS `PROMPT.md`, `.claude/settings.json`
  (narrow permissions, both plain and `rtk` command forms).
- Verified by real non-interactive runs: `/goal` is recognized; `xcodebuild`
  runs; `curl` is denied. First test failed because the rtk hook rewrote
  commands; rules fixed.
- Branch `build/phase-4` for the loop. Next: run the loop for T001.

## 2026-10-21 — T001 Xcode project and package (Sonnet)

- Added `NextCup.xcodeproj` (hand-written pbxproj, synchronized folders, shared
  `NextCup` scheme with both test targets), `NextCup/App/NextCupApp.swift`
  (placeholder `LaunchView`), `NextCupTests` (Swift Testing), `NextCupUITests`
  (XCUITest launch check), local package `Packages/NextCupKit` (warnings as
  errors, one test), `.swift-format`. Strict concurrency complete, iOS 27.
- Commands: `swift test --package-path Packages/NextCupKit` passed (1 test);
  `xcodebuild ... test` TEST SUCCEEDED (unit 1, UI 1); `xcodebuild ... build`
  BUILD SUCCEEDED; `swift format lint --recursive --strict` clean.
- Fixes along the way: added `ENABLE_TESTABILITY` for `@testable import`;
  UI test queries any element type for the combined accessibility element.
- Screenshots: `ralph/screenshots/T001-light.png`, `T001-dark.png`,
  `T001-largest-text.png` (I viewed the largest-text shot only; it fits).
- Untested: VoiceOver (placeholder screen only); `/goal` was not invoked as a
  tool in this session, so the goal bound was self-enforced; `NextCupLiveActivity`
  does not exist yet (T026); lint target list in CLAUDE.md omits `NextCupTests`,
  which I linted too. `/impeccable` polish/audit not run: placeholder screen.

## 2026-10-21 — T002 SwiftData schema v1 and Store (Sonnet)

- Added `NextCup/Persistence/`: `Enums.swift`, `Models.swift` (12 models from
  blueprint §2), `Schema.swift` (`NextCupSchemaV1`, `NextCupMigrationPlan`,
  `NextCupContainer.make(inMemory:)`), `Store.swift` (`find`, `upsert` by `id`,
  `save() -> Result`). Tests in `NextCupTests/PersistenceTests.swift` (17).
- Blueprint deviation (needed for its own CloudKit rule): added
  `Brew.aiRequests` as the inverse of `AIRequest.brew`; §2 listed no inverse.
- SwiftData rejects an inverse declared on both sides (circular macro error),
  so each pair is declared from one end. The CloudKit test checks that every
  relationship is either that end or its target.
- `Schema.Attribute.defaultValue` hung the test host, so the "defaults" rule is
  checked behaviorally (`everyModelSavesFromDefaultsAlone`) instead of by
  introspection. Uniqueness, optional relationships and pairing are introspected.
- `Store.find` filters in memory (generic `#Predicate` is unsupported); fine at
  journal scale, revisit if brews reach many thousands.
- Commands: `xcodebuild ... test` TEST SUCCEEDED (18 unit, 1 UI); `xcodebuild
  ... build` BUILD SUCCEEDED; `swift test --package-path Packages/NextCupKit`
  passed (1); `swift format lint --recursive --strict` clean.
- Debugging notes: tests that dropped their `ModelContainer` (`let (store, _)`)
  crashed the host; `timeout` does not exist on this Mac.
- Untested: on-disk container and migration between versions (only v1 exists);
  `/goal` not invoked as a tool, bound self-enforced. No UI, so no screenshots.

## 2026-10-21 — T003 Bundled data and idempotent seeding (Sonnet)

- Added `NextCup/Resources/` `methods.json` (8 methods, one per style incl.
  switchable immersion dripper and inverted press), `recipes.json` (8 generic
  recipes, original text), `taxonomy.json` (5 dimensions, versioned). Added
  `Persistence/BuiltInContent.swift` (decoder) and `BuiltInSeeder.swift`.
- Seeding keys on `builtInKey` and a ledger of offered keys in `UserDefaults`
  (saved only after a confirmed write). Seeding twice adds nothing; a newer
  bundle adds only new keys and never touches edited rows; a built-in the user
  deleted stays deleted until `forgetOfferedKeys()` (for delete-all, T019).
- For T004 to confirm: on an iced recipe `waterG` is the hot water and `iceG` is
  separate, so ratio and scaling must add them (`includesIce`). Espresso
  recipes store the target yield in `waterG`.
- Tests: `NextCupTests/BuiltInSeederTests.swift` (9: references resolve,
  required presets, every style covered, taxonomy buckets valid and every
  `RoastLevel`/`BrewStyle` mapped, seeding, idempotence, newer bundle, deleted
  built-in).
- Commands: `xcodebuild ... test` TEST SUCCEEDED (26 unit incl. 9 new, 1 UI);
  `xcodebuild ... build` BUILD SUCCEEDED; `swift test --package-path
  Packages/NextCupKit` passed (1); `swift format lint --recursive --strict`
  clean (two long lines fixed first).
- Untested: the seeder is not called at app launch yet (T006 wires it); no
  taxonomy consumer yet (T016); bundle loaded only via `Bundle.main` in the
  hosted test. No UI, so no screenshots. `/goal` not invoked as a tool; bound
  self-enforced.

## 2026-10-21 — T004 BrewMath, RecipeScaler, Freshness, units (Sonnet)

- Added `Packages/NextCupKit/Sources/NextCupKit/Domain/`: `BrewMath` (ratio incl.
  ice, espresso ratio, extraction yield, `1:x.x` label; missing or non-positive
  inputs give `nil`), `RecipeScaler` (scales dose, water, ice and step targets;
  water to whole grams, dose to 0.1 g; rounding notes; dose <= 0 throws),
  `Freshness` (age in calendar days with frozen spans excluded, state
  unknown/resting/peak/pastPeak/frozen), `UnitPreferences` (g/oz, °C/°F).
- Value types only (`ScalableRecipe`, `FrozenSpan`); the app maps SwiftData
  models onto them. Confirmed the T003 note: on an iced recipe `totalWaterG`
  adds `iceG` to `waterG`; the ratio and scaling both include ice.
- Freshness windows are my default (resting < 5 days, peak through day 30),
  adjustable via `FreshnessWindows`; the blueprint gave no numbers.
- Tests: `DomainTests.swift` (22 total in package incl. the version test).
- Commands: `swift test --package-path Packages/NextCupKit` passed (22 tests);
  `swift format lint --recursive --strict` clean (after `format --in-place`);
  `xcodebuild ... build` BUILD SUCCEEDED. App tests not re-run (no app code
  changed).
- Untested: nothing consumes these yet (T007+); freshness in non-Gregorian
  calendars or DST-boundary zones is not covered beyond the UTC test calendar.
  No UI, so no screenshots. `/goal` not invoked as a tool; bound self-enforced.

## T005 — TimerEngine with injectable clock (done)

- Added `Packages/NextCupKit/Sources/NextCupKit/Domain/TimerEngine.swift`: `TimerClock`, `TimerPlan`/`TimerStep`, `TimerSnapshot` (start date, pause spans, skip offset, end), `TimerStateStore` with `UserDefaultsTimerStateStore` (corrupt data discarded), and a value-type `TimerEngine` (start, pause, resume, skip, end early, discard, restore). State is derived from persisted dates, never a ticking counter.
- Added `Tests/NextCupKitTests/TimerEngineTests.swift`: fake-clock tests for step changes, pause/resume, multiple pauses, skip (incl. while paused and on the last step), end early, restore after simulated termination (open pause, skips, early end), backwards clock, plan validation, UserDefaults round trip.
- Commands: `swift test --package-path Packages/NextCupKit` → 41 tests in 8 suites passed (one first-run failure was a wrong expected value in my own test, fixed; engine unchanged). `swift format lint --recursive --strict ...` → no output (clean).
- Not run: app build / `xcodebuild test` (package-only task, no app files touched). No screenshots (not a UI task).
- Untested: Live Activity mirroring and the `@Observable` wrapper with a real ticking UI belong to T008/T026.

## 2026-10-21 — T006 App shell (Sonnet)

- Added `NextCup/App/`: `AppTab`, `DeepLink` (parse/serialize `nextcup://brew/new`, `brew|recipe|bean/<uuid>`; malformed links are ignored), `AppRouter` (per-tab paths, replaces instead of stacking), `RootTabView` (5 tabs, placeholder screens built from `EmptyState`), `AppBootstrap` (opens the store and seeds built-ins at launch, closing the T003 gap; failure shows a retry screen). `NextCupApp` now uses them; `LaunchView` is gone.
- Added `NextCup/DesignSystem/` (`Tokens.swift`, `Components.swift`) copied from `design/DesignSystem` and reformatted to the 2-space style. `design/check_tokens.py` now checks the app copy; the concept copy in `design/DesignSystem` is no longer checked and may drift.
- URL scheme registered via `Config/NextCup-Info.plist` (`INFOPLIST_FILE` merged with the generated plist).
- Blueprint deviation: the selected tab is stored with `@AppStorage`, not `@SceneStorage` (§5). A UI test showed `@SceneStorage` did not survive terminate and relaunch, and iOS discards it on force-quit, so it would miss "tab restores after relaunch".
- Replaced the T001 `launchViewBuilds` placeholder test with `shellBuilds` and a bootstrap-seeds-store test; no test was weakened.
- Tests: `DeepLinkTests` (unit, 7 incl. parameterized malformed links), `NextCupUITests` (launch to Journal, each of 4 links opens its screen and tab, malformed link ignored, tab restores after relaunch).
- Commands: `xcodebuild ... test` TEST SUCCEEDED; `swift test --package-path Packages/NextCupKit` 41 passed; `xcodebuild ... build` BUILD SUCCEEDED; `swift format lint --recursive --strict` clean; `python3 design/check_tokens.py` tokens in sync.
- Screenshots: `ralph/screenshots/T006-light.png`, `T006-dark.png`, `T006-largest-text.png` (viewed: recipe deep link, dark, accessibility XXXL; reflows), `T006-deeplink-recipe.png`.
- Untested / caveats: UI tests deliver links through a DEBUG-only `-deepLink` launch argument that calls the same `handle` as `onOpenURL`; the real `simctl openurl` path was only seen to reach the system "Open in Next Cup?" prompt (scheme is registered), I could not tap Open. VoiceOver and Full Keyboard Access not run; tab bar is the system one. `contrast.py` not rerun (no colour change). `/impeccable` polish and audit not run (placeholder screens). `/goal` not invoked as a tool; bound self-enforced. The simulator was rebooted to clear a stuck system dialog.

## T007 — Recipe library S06, detail S07, scale-to-dose

Changed:
- `NextCup/Features/Recipes/`: `RecipeLibraryView` (grouped by brew style, searchable by name, method, credit; empty and no-results states), `RecipeDetailView` (spec tiles, tuning note on kraft, step timeline, dose stepper that rescales water, ice and every step target via `RecipeScaler`, reset, rounding notes, credit link, not-found state), `RecipeFormat` (clock, spoken time, units-aware weight and temperature, step titles, VoiceOver "kind, at time, target" label).
- `RootTabView`: Recipes tab shows the library; `nextcup://recipe/<id>` opens the detail.
- `AppBootstrap`: an in-memory store now gets a throwaway defaults suite for the seeding ledger. Before, a second UI-test launch found the ledger full and seeded no recipes (found by the new UI test).
- Tests: `RecipeFormatTests` (6), UI `testRecipeLibraryGroupsSearchesAndScales`, and `testCaptureRecipeScreenshots` (runs only while `ralph/screenshots/.capture` exists).

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 41 tests passed.
- `swift format lint --recursive --strict ...`: clean.
- `xcodebuild ... test` (iPhone 18 Pro): 40 app tests passed, 5 UI tests passed, TEST SUCCEEDED.

Screenshots (`ralph/screenshots/`): `recipes-library-{light,dark,largest-text}.png`, `recipe-detail-{light,dark,largest-text}.png`, `recipe-detail-steps-light.png`.

Untested / honest gaps:
- VoiceOver was not run on a device or simulator by hand; the per-step label is unit-tested and set as the accessibility label, not heard.
- The unit setting UI is T020; until then units read `units.weight` / `units.temperature` from UserDefaults (default g, °C). The ounce path is covered by format tests only, not by a UI test.
- `/impeccable polish` and `/impeccable audit` were not run (not available in this session); screenshots were checked by eye only.
- No Start button on the detail yet; the guided timer is T008.

## T008 — Guided timer S05 (Sonnet)

Changed:
- `NextCup/Features/Timer/`: `TimerSetup` + `TimerPlanBuilder` (recipe at the chosen dose to a `TimerPlan`; total = recipe time, or last step + 30 s), `TimerSession` (@Observable wrapper over `TimerEngine`; haptics only on start, step change, pause/resume, finish; adopts a saved timer only if its plan matches; forgets the saved timer at the end), `TimerView` (readout on steel, live step row, bottom thumb-zone controls Start/Pause/Resume, Skip step, End early; keeps the screen awake; VoiceOver announces step changes; no animation under Reduce Motion; tab bar hidden).
- `RecipeDetailView`: "Start brew" button at the bottom, starts at the scaled dose.
- `Features/Journal/BrewFormSeed.swift`: `BrewFormSeed` and `BrewFormPlaceholder`, a stand-in for S02 that shows what the timer hands over (dose, water, temperature, time reached). T009 replaces the placeholder with the real form.
- DEBUG-only `-timerSpeed <n>` launch argument speeds the timer clock so UI tests finish in seconds.

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 41 passed.
- `swift format lint --recursive --strict ...`: clean.
- `xcodebuild ... test` (iPhone 18 Pro, app unit tests + UI tests): TEST SUCCEEDED. New: `TimerSessionTests` (plan, end to end, pause, skip, end early, background catch-up, haptic count, restore, foreign plan) and 3 UI tests (end-to-end run to prefilled form, background/foreground, end early). The first UI run failed because identifiers on `SteelButton` were not found; tests now find buttons by label.

Screenshots (`ralph/screenshots/`): `timer-ready-{light,dark,largest-text}.png`, `timer-running-{light,dark,largest-text}.png` (viewed: running light, ready dark, running largest text).

Untested / honest gaps:
- VoiceOver was not run by hand; labels, the step announcement and `updatesFrequently` are set but not heard. Real haptics not felt (simulator).
- At the largest text size the readout scrolls out of view as the live step is centered; elapsed time is not pinned. Candidate fix for a later polish pass.
- Relaunch mid-brew: the engine restores (T005 tests) and a same-plan session adopts it, but nothing reopens the timer screen on its own after a relaunch; the user must reopen the recipe and tap Start brew.
- Pause/resume haptics and the Live Activity (T026) are not exercised in UI tests. `/impeccable polish` and `audit` not run. `/goal` not invoked as a tool; bound self-enforced.
- The first full test run hit a 600 s simulator-diagnostics timeout; later runs were scoped to the app test targets.
