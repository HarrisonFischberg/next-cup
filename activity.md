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

## T009 — Brew form S02, DraftStore, honest saves, photo sanitizing (Sonnet)

Changed:
- `NextCupKit`: `DraftStore` (file-backed autosave, failed write reported and previous draft kept, corrupt file discarded), `BrewDraft` (`canSave` needs positive dose and water), `PhotoSanitizer` (re-encodes without GPS/EXIF/TIFF metadata, scales down).
- `NextCup/Features/Journal/`: `BrewFormModel` (restore, debounced autosave, flush on background/disappear, save clears the draft only after the store confirms; failure rolls back, shows the error, keeps the draft), `BrewFormView` (method picker, date, dose/water/temperature/time steppers with recipe targets beside them, ratio, grind, verdict, grade, photo, notes; Save in the bottom inset; tap-away and Done dismiss the keyboard), `BrewFormSeed` hand-over from the timer. DEBUG `-failBrewSave` simulates a write failure.
- This session: fixed the "BREWED" label wrapping letter by letter at the largest text size (label now stacks above the date picker); fixed one over-long line in `NextCupUITests.swift`.

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 52 tests passed (incl. DraftStore, PhotoSanitizer GPS/EXIF absence).
- `swift format lint --recursive --strict ...`: clean.
- `xcodebuild ... build`: BUILD SUCCEEDED.
- `xcodebuild ... test` (app + UI, before the label fix): TEST SUCCEEDED, 16 UI tests. After the fix a scoped re-run of the app unit tests plus the three form UI tests was started; see the result line below.

Screenshots (`ralph/screenshots/`): `brewform-prefilled-{light,dark,largest-text}.png`, `brewform-blank-{light,dark,largest-text}.png`, `brewform-lower-light.png` (viewed: prefilled largest text before and after the fix).

Untested / honest gaps:
- VoiceOver not run by hand; labels and identifiers are set, not heard. Real haptics not felt.
- Photo picker was not driven in a UI test (system picker); sanitizing is covered by package tests with a GPS-carrying fixture.
- Journal list that shows the saved brew is T010; the form currently ends on a "Brew saved" state.
- `/impeccable polish` and `audit` not run. `/goal` not invoked as a tool; bound self-enforced.
- Result of the post-fix scoped re-run (app unit tests + 3 form UI tests, `-quiet`): no failures or errors printed; the run went quiet at the end of the test phase without a summary line, so I did not see an explicit TEST SUCCEEDED for it. The full run before the label fix did print TEST SUCCEEDED. Lint re-run clean.

## 2026-10-22 — T010 journal list S01

What changed:
- `JournalListView` (S01): newest-first list, search (notes, method, recipe, grind, verdict, bean names), method / bean / order filters remembered in `@AppStorage`, empty state with "Log a brew", "No matches" state with "Clear filters", swipe-to-delete (full swipe) and context-menu / VoiceOver "Delete" with a 6 s Undo toast. The brew is removed from the store only when the toast times out or the screen is left; a failed delete rolls back and shows an error.
- `JournalFilter` (pure rules, unit tested), `JournalStorage`.
- Edit of a saved brew (needed by the T010 criterion): `BrewFormModel(editing:)`, own per-brew draft file, `brew/<id>` deep link opens the form on the saved values; a missing brew shows "Brew not found".
- `SteelToast` now uses `.contain` so Undo stays its own control for VoiceOver.
- Grade badge shows only for graded brews (found from screenshots).

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 52 passed.
- `swift format lint --recursive --strict ...`: clean.
- `xcodebuild ... test` (full): TEST SUCCEEDED, 72 app tests and 18 UI tests, including `testJournalLogsFindsEditsAndDeletesABrewWithUndo` (log, search hit and miss, edit, delete + Undo, delete and let the toast expire).
- After the badge change: re-ran only the F01 journal UI test and the journal screenshot capture; exit code 0 (I could not read the per-test lines, the output was truncated). The full suite was not re-run after that one-line view change.

Screenshots (`ralph/screenshots/`): `journal-{empty,list,undo}-{light,dark,largest-text}.png`.

Untested / honest gaps:
- Bean filter has no UI test: beans cannot be logged until T014; covered by `JournalFilterTests` only.
- Leading swipe, duplicate, share, move are not built (brew again is T011, export T019).
- No pull-to-refresh or loading skeleton: the list is local and synchronous.
- Undo window ends if the app is killed during it: the brew then stays (safe direction).
- At the largest text size the Undo toast covers the empty state's button until scrolled.
- VoiceOver not run by hand; haptics not felt. `/impeccable polish` and `audit` not run.

## 2026-10-22 — T011 Brew again and edit any saved brew

What changed:
- Housekeeping: T010 was finished and logged by the previous session but never committed; committed it separately first (`feat(T010)`), so this commit holds T011 only.
- Edit of any saved brew already shipped with T010 (`BrewFormModel(editing:)`); T011 adds a test that editing leaves a brew's beans alone.
- Brew again: `BrewDraft.repeating` (NextCupKit) keeps method, recipe, beans, dose, water, temperature, grind and recipe targets; resets time, date, verdict, grade, notes, photo and ended-early. `BrewDraft.beans` is optional, so old draft files still load and an edit never touches beans. `DraftStore.repeating(id)` gives a repeat its own draft file, so it never overwrites a half-typed new brew.
- App: `nextcup://brew-again/<id>` (`DeepLink.brewAgain`), `BrewFormModel(repeating:)` copies beans into new `BrewBean` rows scaled to the dose (a deleted bean keeps its name), form shows "BREW AGAIN" and "Same beans: ...". Journal: leading full-swipe, context menu and VoiceOver action "Brew again".

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 57 passed (5 new).
- `xcodebuild ... test -only-testing:NextCupTests`: 76 passed, TEST SUCCEEDED (4 new brew-again/edit model tests).
- `xcodebuild ... test -only-testing:NextCupUITests`: TEST SUCCEEDED, 19 run, 4 skipped (screenshot captures), 0 failures, incl. `testBrewAgainRepeatsASavedBrew`.
- `swift format lint --recursive --strict ...`: clean.

Screenshots (`ralph/screenshots/`): `brewform-again-{light,dark,largest-text}.png`, `journal-brew-again-swipe-{light,dark,largest-text}.png` (viewed: brewform-again largest text; reflows, Save stays visible).

Untested / honest gaps:
- UI test brews have no bean (beans UI is T014), so beans carry-over is covered by model tests only; the "Same beans" line was not seen on screen.
- Time reset in the UI test checks an empty time on a brew that never had one; a measured time being cleared is covered by package and model tests.
- VoiceOver not run by hand; haptics not felt. `/impeccable polish` and `audit` not run. `/goal` not invoked as a tool.
- The full suite was run as two scoped runs (unit, then UI), not one `test` invocation.

## 2026-10-22 — T012 Methods S09

What changed:
- `NextCup/Features/Methods/`: `MethodsView` (S09 list: tap to edit, drag in Edit mode, trailing full-swipe Hide/Show, context menu and VoiceOver actions for Hide, Move up, Move down; "Hidden" tag; empty state; error banner), `MethodEditorView` (sheet: name, style on add, one switch per optional field, visible Move up / Move down with "Position n of m"), `MethodsService` (add, rename/update, hide, move, step; trimmed non-empty case-insensitive unique names; renumbers `sortOrder` without gaps; failed save is rolled back and reported), `MethodParameters` (which fields a method shows).
- Methods are never deleted; hiding keeps every brew and the method's place. The brew form still offers a hidden method on a brew that already uses it.
- `SettingsRootView` is now the Settings tab root with a "Brew methods" row (units, data, privacy arrive with T020).
- `BrewFormView`: temperature, time, grind setting, grade, photo and notes show only if the chosen method tracks them. Dose, water, ratio and taste verdict always show.

Decisions to confirm:
- Dose and water are always on (a brew cannot be saved without them), so the editor shows them locked. Yield and TDS stay on a method untouched but are not offered: the form has no field for them yet (TDS UI is T029). Espresso keeps using the Water field for output weight, as before.
- Verdict ("how it tasted") is not a `BrewParameter`, so it is always shown.
- Style is chosen when adding a method and not changed afterwards.

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 57 passed.
- `xcodebuild ... test` (full, app + UI): TEST SUCCEEDED; UI 22 run, 6 skipped (screenshot captures), 0 failures, incl. `testMethodsAddReorderHideAndShapeTheBrewForm`. Unit tests 85 passed (9 new in `MethodsServiceTests`). The wrapper reported the background task as killed at its time limit after the run had printed TEST SUCCEEDED (simulator diagnostics collection hangs ~10 min after a run).
- `swift format lint --recursive --strict ...`: clean.
- First UI attempts failed for test-side reasons (editor "Move up" below the fold; a switch tap that missed the thumb); the app code was not changed for either.

Screenshots (`ralph/screenshots/`): `settings-{light,dark,largest-text}.png`, `methods-list-{light,dark,largest-text}.png`, `methods-editor-{light,dark}.png` (viewed: list light and largest text, editor dark). `methods-editor-largest-text.png` was not produced in the final capture run; the editor at the largest text size was not looked at. Fixed from screenshots: off-theme white footer band, icon overlapping text at the largest size.

Untested / honest gaps:
- VoiceOver not run by hand; the row label, actions and switch values are set, not heard. Real drag-to-reorder was not driven in a UI test (Move up/down is). No haptics on reorder.
- Hide has no Undo toast: it is non-destructive and reversible from the same row.
- Restoring the brew form after a method is hidden mid-draft is untested. A brew saved with a field its method no longer tracks keeps the value, but the field is not shown.
- `/impeccable polish` and `audit` not run. `/goal` not invoked as a tool; bound self-enforced.
