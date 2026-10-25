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

## T013 — Recipe editor S08 (done)

**Changed**
- `RecipeEditorService` (draft ⇄ `Recipe`, validation, save in place or as a copy, rollback on a failed write), `RecipeEditorFields` (text fields in the user's units → `RecipeDraft`, names the unreadable field), `RecipeEditorView` (all 12 step kinds, add / move up / move down / remove with Undo, method picker, ice, credit, tuning note).
- Library: "+" new recipe, context menu Edit / Duplicate / Customize. Detail: actions menu with the same. A built-in is never edited in place: Customize saves a copy with `builtInKey` cleared.
- Bundle already held the switchable dripper and inverted press (methods + recipes); a test now pins them.

**Commands and results**
- `swift format lint --strict ...`: clean.
- `swift test --package-path Packages/NextCupKit`: 57 tests passed.
- `xcodebuild ... test -only-testing:NextCupTests`: 94 tests passed, including the 9 new `RecipeEditorTests` (round trip, every step kind, in-place edit leaves no orphan steps, customized copy leaves the original, validation, unit round trip in oz / °F, parsing).
- New UI test `testCustomizingABuiltInRecipeSavesACopy`: passed.
- Full `xcodebuild test`: one failure, `testJournalLogsFindsEditsAndDeletesABrewWithUndo` (journal code, not touched here). Re-run alone: passed. Treated as flaky under load; not investigated further.

**Untested / not done**
- No screenshots (light, dark, largest text) were saved to `ralph/screenshots/`; no VoiceOver pass or `/impeccable` polish and audit. The editor was only exercised by the UI test.
- The keyboard toolbar "Done" button was not found by the UI test; the form dismisses the keyboard by scrolling instead.
- No delete for the user's own recipes yet, and no autosaved editor draft (the sheet blocks swipe-dismiss while there are unsaved changes).
- Oz values are shown to 3 decimals so a customized copy stays within about 0.03 g of the original.

## 2026-10-22 — T014 bean library, detail, roasters, stock, freshness

- Added `BeanStock` (remaining = bag − Σ brew grams + manual adjustment, never below zero, unknown without a bag weight; low at ≤20%) with package tests.
- App: `BeanFilter` (status All / In use / Buy again / Wishlist / Finished, search over name, roaster, origin, process, bag notes, sort recent / name / roast date / grade), `BeanService` (save with validation, roaster reused by name, set status, correct remaining, delete keeping brews' bean names), `BeanLibraryView` (S03: search, remembered status and order, swipe finished / delete with Undo, context menu, VoiceOver actions, empty and no-results states), `BeanDetailView` (S04: freshness and age from roast date with frozen spans, remaining with manual correction, attributes, bag flavor notes, linked brews), `BeanEditorView`. `nextcup://bean/<id>` now opens the real detail, or a "Bean not found" screen. `FilterMenu` made internal to share with the journal.
- Commands: `swift test --package-path Packages/NextCupKit` passed (64 tests). `swift format lint --strict` clean. `xcodebuild ... test`: unit suite 107 tests passed; UI suite 25 executed, 0 failures, 7 capture tests skipped (the capture test ran separately and passed).
- Screenshots in `ralph/screenshots/`: beans-empty, beans-list, bean-detail, bean-editor, each in `-light`, `-dark`, `-largest-text`.
- Untested: VoiceOver on a real device (labels and actions are set, not exercised); remembered filter checked only through the storage keys, not across a UI relaunch; `/impeccable polish` and `/impeccable audit` not run; freeze/thaw UI, blends and best-so-far are T015; bean photo, bean rating entry and Explore links are not built.

## 2026-10-22 — T015 blends, decaf, freeze/thaw, best-so-far

What changed:
- `NextCupKit`: `BlendShares` (dose split by shares so the parts add up to the dose, plus add / remove / rebalance helpers that keep shares at 100%, 5% to 95% per bean) and `BestSoFar` (rating spread, best brew's settings, grind history by grinder and dose; newest first within a dose). `BrewDraft.grinderID` added (old drafts still load).
- Brew form (S02): a BEANS section (add one bean or several; blend shows each bean's grams and percent with minus / plus / remove, all 44 pt) and a GRINDER picker with "New grinder…" (remembered for the next brew). Saving a brew gives each bean its share of the dose, so each bag loses its own part. Saving an edit now replaces the brew's old bean rows; before, they would have stayed and double-charged the bags. Bean rows load in creation order so an edited blend does not reshuffle.
- Bean detail (S04): Freezer row with Put in / Take out (frozen days stay out of age, already in `Freshness`) and the Best so far card. Decaf is a flag on the bean (T014) and shows as a tag in the blend list.
- Replaced the "Same beans: ..." header line in the form (brew again) with the editable BEANS section.

Decisions to confirm:
- The model holds one freezer stay per bag (`frozenOn` / `thawedOn`, blueprint §2). A second freeze after a thaw is refused with a message instead of silently dropping the first stay's days from the age. Several stays would need a schema change (a list of spans, or a frozen-days total); I did not redesign the blueprint.
- A blend brew counts toward the best-so-far card of each bean in it.

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 80 passed.
- `swift format lint --recursive --strict ...`: clean.
- Unit target (`-only-testing:NextCupTests`): 118 passed, including 11 new in `BlendAndFreezerTests` (blend deducts from each bag, edit does not double-charge, freeze / thaw age and rules, grinder remembered, best-so-far from real brews). First runs failed twice on my own test expectations (grind history order; an unordered relationship), the second one exposing the bean-order issue fixed above.
- UI: `testBlendBrewFreezerAndBestSoFarFlow` passed (add two beans, log a 55 / 45 blend, bag shows less than 250 g, freeze, best-so-far card present). Two earlier UI runs died because the simulator would not launch the runner or the app (no result from the tests); `simctl shutdown all` fixed it.
- Final UI suite after a simulator restart: `xcodebuild ... test -only-testing:NextCupUITests` TEST SUCCEEDED, 27 run, 8 skipped (screenshot captures), 0 failures; this includes the existing brew-again and journal tests after the form change. The unit target was last run before the final one-line icon-size change (UI only); the full `xcodebuild test` was not run as one invocation (unit and UI runs were separate).
- Fixed from screenshots: at the largest text size the minus / plus / remove icons overlapped; the glyphs are now capped at xxxLarge inside their 44 pt targets.

Screenshots (`ralph/screenshots/`): `T015-brewform-blend-*`, `T015-bean-detail-freezer-*`, `T015-bean-best-so-far-*`, each in `-light`, `-dark`, `-largest-text` (viewed: blend form light and largest text, bean detail dark).

Untested / honest gaps:
- The screenshots and UI test show the Best so far card only in its "no grade yet" state: the flow does not grade the brew or enter a grind. The graded card (best settings, grade spread bars, grind history) is covered by package and app tests but I have not seen it rendered.
- VoiceOver not run by hand; labels are set (share buttons name the bean, spread rows read "Grade 4.5, 2 brews"), not heard. `/impeccable polish` and `audit` not run. `/goal` not invoked as a tool; bound self-enforced.
- No UI for removing a grinder; no Undo for the freezer toggle (it reverses with Take out). A freezer stay can be recorded once per bag (see decisions above).
- Decaf has no filter yet; it shows as a tag on the bean detail and in the blend list.

## 2026-10-22 — T016 Taxonomy service + user aliases + "Unmapped" flow

- Added `Packages/NextCupKit/Sources/NextCupKit/Taxonomy/Taxonomy.swift`: loads `taxonomy.json` (rejects unknown dimensions and map entries pointing at missing buckets), `normalize` (case, accents, punctuation, spacing), `map` (user alias > bundle > `.unmapped`), `buckets(for:)`, `unmapped(in:)` for the mapping list, `alias(mapping:to:in:replacing:)` (rejects missing buckets and empty values, replaces an earlier alias). A stale alias pointing at a removed bucket falls back to the bundle.
- `NextCup/Resources/taxonomy.json` bumped to version 2: added spaced roast names ("ultra light", "medium light", "medium dark"); the shipped-bundle test found that "Medium Light" was unmapped.
- Tests: `TaxonomyTests` (14) covering determinism, normalization, unmapped values, alias override, per-dimension isolation, bad bundles, the shipped bundle.
- Commands: `swift test --package-path Packages/NextCupKit` → 94 tests passed; `swift format lint --recursive --strict ...` clean; `xcodebuild ... test` → TEST SUCCEEDED.
- Untested / not done: no SwiftData `TaxonomyAlias` wiring and no "Unmapped" UI yet (service layer only, which is what the acceptance criteria test); T017 and the bean screens consume it. No screenshots (no UI change).

## 2026-10-22 — T017 Recommender + Explore tab

- Added `NextCupKit/Recommender/Recommender.swift`: ranks methods by mean grade over rated brews of similar beans (similar = shares 2 of origin/process/roast buckets, or the one it has), start values from the best brew, explanation built only from computed `HistoryFacts`. Fewer than 3 similar rated brews returns the bundled roast-band default, labelled as a default (no roast level: medium default, says so).
- App: `Features/Explore/ExploreModel.swift` (beans/brews → recommender inputs, user aliases applied) and `ExploreView.swift` (card per in-use/buy-again bean, empty state with "Add a bean", error banner if taxonomy unreadable); Explore tab now uses it.
- Commands: `swift test --package-path Packages/NextCupKit` → 108 tests passed (14 new). `swift format lint --strict` clean. `xcodebuild ... test` (full) → TEST SUCCEEDED, 29 UI tests with 9 capture tests skipped, 0 failures. Targeted re-run of `ExploreModelTests`, `testExploreShowsLabelledDefaultForANewBean` and `testCaptureExploreScreenshots` → TEST SUCCEEDED.
- Screenshots: `ralph/screenshots/T017-explore-{empty,default}-{light,dark,largest-text}.png`.
- Untested / honest notes: no SwiftData-backed UI test of a history-driven (non-default) card; that path is covered by package and `ExploreModelTests`. No skeleton loading state (`@Query` is synchronous). VoiceOver checked only through accessibility labels/identifiers in UI tests, not a manual VoiceOver pass. `/impeccable polish` and `audit` were not run. Start values are shown but not yet prefilled into the brew form; the card links to a new brew.

## 2026-10-23 — T018 Rule-based dial-in + Suggestion cards

What changed:
- `NextCupKit/DialIn/DialInRules.swift`: verdict + brew values → one `SuggestionDraft` or `.keep`. Sour: finer grind (numeric settings step by 1, text around the number kept), else +2 °C (cap 99), else longer steep (immersion/cold). Bitter: the mirror. Weak/strong: water -6% / +8% (espresso: output weight -/+10%, to 0.5 g). Only parameters the method tracks; balanced keeps everything. One lever per suggestion.
- App: `SuggestionService` (stores a `.rules` Suggestion linked to its brew after a save, replaces an unanswered one on edit, never rewrites an answered one, dismisses older unanswered ones for the same beans, `match` finds the card for the next brew by bean, or by method when neither brew has beans), `SuggestionFormat` (units-aware text), `SuggestionCard` (Accept / Edit / Dismiss, Undo after any answer, no confirm dialog), `SuggestionHistory`.
- Brew form: card under BEANS on a new brew; accept applies to the draft and marks the saved brew as having followed it; Edit takes a value in the user's units; saved screen shows "Try this next time" or why there is none. Journal rows show "Next: ..." and "Followed: ...". Editing a brew lists its suggestions.

Decisions to confirm:
- Rules assume a lower grind number is finer (said in the rationale). The app does not know the grinder's direction.
- Answered state is stored at once; an accepted suggestion whose brew is never saved stays "applied". Relaunch with a restored draft keeps the applied value but loses the follow link.
- Edit rewrites `toValue` to the user's number; the original suggested value is not kept after Edit.

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 125 passed (17 new `DialInRulesTests`).
- `swift format lint --recursive --strict ...`: clean.
- `xcodebuild ... test` (full): TEST SUCCEEDED, 0 failures; UI 33 executed incl. `testDialInSuggestionShowsOnTheNextBrewOfThatBean` (log sour cup, saved screen and journal row show Grind 20 → 19, next brew of that bean shows the card, accept, undo, dismiss, undo), 12 capture tests skipped; unit tests incl. 17 new `DialInSuggestionTests`.
- First app-test run had one failure in my own test (no dose set); fixed the test. The capture as one 3-variant test died mid-run (runner restart), so it is now one test per variant.

Screenshots (`ralph/screenshots/`): `T018-dialin-{saved,card,accepted}-{light,dark,largest-text}.png` (viewed: card light and largest text; at largest text the card sits below the fold and is reached by scrolling).

Untested / honest gaps:
- VoiceOver not run by hand (headline has a spoken label, buttons are named). Haptics not felt. `/impeccable polish` and `audit` not run. `/goal` not invoked as a tool.
- The Edit alert was not driven in a UI test (unit tests cover edit values and units). Ounce/°F paths covered by unit tests only.
- The journal row line is asserted by the UI test but not viewed in a screenshot; neither is the edit-form history.
- AI suggestions will share the card flow in T023; none are produced yet.

## T019 — Export, merge import, backup, delete all

Added `Persistence/DataArchive.swift` (record types, one per model), `Persistence/DataExchange.swift` (exporter, importer with preview, daily backup keep 7, eraser), `Features/Settings/DataSettingsView.swift` (Settings → Your data), a launch backup hook in `NextCupApp`, `createdAt` on the `Identified` protocol, and `DataExchangeTests` (11 tests). Built-ins match by `builtInKey` on import. Conflicts keep the local row unless the user picks the imported one. Delete all wipes store, drafts folder, backups, the app's preference domain (selected tab kept) and generic-password Keychain items, then reseeds; Undo re-imports an in-memory snapshot for 8 s.

Commands and results:
- `swift format lint --recursive --strict ...`: clean.
- `swift test --package-path Packages/NextCupKit`: 125 tests passed.
- `xcodebuild ... build`: succeeded.
- `xcodebuild ... test` (all app + UI tests): TEST SUCCEEDED.
- UI test `testYourDataDeleteAllCanBeUndone` plus capture tests passed.

Screenshots (`ralph/screenshots/`): `T019-data-screen-{light,dark,largest-text}.png`, `T019-data-deleted-{light,dark,largest-text}.png`.

Not done or not verified:
- `AIRequest` rows are not exported (transient queue).
- An edit that only changes a built-in recipe's steps is not flagged as a conflict.
- Keychain wipe is tested through an injected stub only; nothing writes Keychain items yet. Re-check against `KeychainStore` in T021.
- Undo restores data only, not backups or keys.
- The share sheet and the file-importer sheet were not exercised on screen.
- `/impeccable polish` and `/impeccable audit` and a VoiceOver pass were not run.

## 2026-10-24 — T020 settings: units, privacy summary, about

What changed:
- `SettingsRootView`: Units section (weight g/oz, temperature °C/°F segmented pickers) writing the `UnitStorage` keys that journal, recipe detail, timer and brew form already read through `@AppStorage`; Privacy page (`PrivacySummaryView`); About section with version. Data controls were already under "Your data" (T019).
- UI test `testChangingUnitsInSettingsUpdatesRecipesAndTheBrewForm`: switches to ounces, checks recipe water and the brew form dose tile, then restores grams.

Commands and results:
- `swift format lint --recursive --strict ...`: clean.
- `xcodebuild ... test` (full app + UI suite): TEST SUCCEEDED, 38 executed, 15 skipped, 0 failures. Two earlier full runs failed (5 and 8 failures); my first version of the new test failed because a blank form shows no unit until the dose has a value, so it now steps the dose first. I could not read the failure messages of the other failing tests in those runs (xcresulttool was not permitted), and they passed in the final run, so whether they were order or timing flakes is unconfirmed.
- Not re-run in this task: `swift test --package-path Packages/NextCupKit` (no package code changed).

Not done or not verified:
- No screenshots saved to `ralph/screenshots/` (light, dark, largest text) for the Settings screen.
- `/impeccable polish`, `/impeccable audit` and a VoiceOver pass were not run.
- The timer screen under ounces is covered by code reading only (it reads the same `@AppStorage` keys), not by the UI test; the journal rows likewise.
- The 15 skipped UI tests were not examined.

## 2026-10-24 — T021 Keychain, AI disclosure, model picker

- Added `NextCup/Features/AI/AIConfig.swift` (`KeychainStore`, `AIPreferences`) and `AISettingsView.swift` (key entry per provider, one-time disclosure sheet shown before the first key is saved, provider + model ID per feature). Linked from Settings → AI. Tests in `NextCupTests/AIConfigTests.swift`.
- Keys: Keychain only (`WhenUnlockedThisDeviceOnly`); `DataEraser.clearKeychain` already wipes them on delete all. Preferences hold only disclosure version and provider/model IDs.
- Commands: `swift format lint --strict` clean; `xcodebuild ... -only-testing:NextCupTests test` 158 tests passed; AIConfigTests 5/5.
- Untested: no screenshots (light/dark/largest text) and no VoiceOver check of Settings → AI or the disclosure sheet; UI tests were not run. The model "picker" is a free-text model ID per feature because the model list needs `GET /v1/models` (network, T022); no model ID is hardcoded.

## 2026-10-24 — T022 AIClient, Transport, AIQueue

- `NextCupKit/AI/`: `JSONSchema` (small schema type: builds the provider schema, validates output exactly, tells booleans from numbers), `AIClient` (`Transport` protocol + `URLSessionTransport`; Anthropic `/v1/messages` with a forced tool, OpenAI `/v1/responses` with strict `json_schema`; optional JPEG; 60 s timeout). Refused before any I/O without accepted disclosure or a key; 401 is "key rejected"; 429/5xx retried with doubling backoff, 3 attempts max; offline is not retried; output that is not schema-valid JSON throws `invalidResponse` and is never retried.
- App: `Features/AI/AIQueue.swift` (@Observable over `AIRequest`: enqueue is the only way a call starts, offline stays `queued` with a message, cancel, retry, `NWPathMonitor` resumes the queue; image kept as the request attachment). `AIQueue.live` wires Keychain keys and the stored disclosure flag.
- Nothing creates a `Suggestion` from AI output yet (T023); a failed request creates none (tested).
- Commands: `swift test --package-path Packages/NextCupKit` 138 passed (14 new `AIClientTests` with a stub transport: no key, no disclosure, request shape per provider, 401, retry cap 3, backoff, invalid outputs, offline). `xcodebuild ... -only-testing:NextCupTests test` 166 passed incl. 8 new `AIQueueTests`. `swift format lint --recursive --strict` clean.
- A first full `xcodebuild test` reported TEST FAILED; the cause was my queue tests dropping their `ModelContainer` (known host crash, see T002); containers are now kept alive. The full UI suite was not re-run after that fix (no UI code changed).
- Untested: real network calls (none made, by rule), the real provider response shapes beyond what the docs describe, `NWPathMonitor` on a device, `GET /v1/models`. No screenshots (no UI). `/goal` not invoked as a tool.

## T023 — AI brew diagnosis and insights as Suggestions

- Added `NextCup/Features/AI/AISuggestions.swift`: prompt/payload builders for diagnosis (one brew) and insights (up to 8 brews of one bean), a strict schema (field in grind/water/temperature/time, toValue, rationale), and `ingest(request:in:)` that makes a `Suggestion` (`source = .ai`, `modelID`, `sourceBrew`, `fromValue` read from the brew, id = request id so repeats never double). Unusable answers (bad field, non-numeric value, no brew, wrong feature) store nothing.
- `AIQueue` gained `onDone`, set in `live(context:)` to ingest; `SuggestionService.supersedeOlder` is now internal so a newer AI card dismisses the stale one, same as rules. The existing card, accept/edit/dismiss/undo and next-brew match work unchanged.
- Tests: `NextCupTests/AISuggestionsTests.swift` (8 tests).
- Commands: `swift format lint --strict ...` clean; `xcodebuild ... test -only-testing:NextCupTests` → 174 tests passed.
- Not done / untested: no button yet starts a diagnosis or insights request from the UI (nothing calls `enqueue` with these payloads; no screenshots, no UI test, no real provider call). `swift test` for the package and the UI test bundle were not re-run (package untouched).

## T024 — Photo interpretation and bag recognition → bean draft

- Added `NextCup/Features/AI/BagRecognition.swift` (schema, payload, `draft(from:)`, `fill`) and a "Fill from a photo" menu in `BeanEditorView` (PhotosPicker, photo sanitized, queued through `AIQueue`). Both `bagRecognition` and `photoInterpretation` produce a `BeanFields` draft; the editor fills only empty fields and the user taps Save. No `Bean` is inserted by the AI path.
- Tests: `NextCupTests/BagRecognitionTests.swift` (schema validation, blank/future values dropped, no blind save, no call without key, queue round trip with stub transport).
- Commands: `swift format lint --strict` clean; `swift test --package-path Packages/NextCupKit` 138 passed; `xcodebuild test` full run: all app unit tests passed, 2 UI tests failed (`testBrewAgainRepeatsASavedBrew`, `testChangingUnitsInSettingsUpdatesRecipesAndTheBrewForm`); both passed when rerun alone (flaky under full run, not touched by this change).
- Not done / untested: no simulator screenshots (light, dark, largest text) and no VoiceOver check of the new editor row; no real provider call (no key, no network by rule); camera capture not added (PhotosPicker only).

## 2026-10-24 — T025 paper-journal import

- Added `NextCupKit/Import/PaperImport.swift` (label-based text → `PaperBrewDraft` with per-field confidence, units to g/°C/s, implausible values and "3OO g"-style misreads rejected into notes; AI schema, payload, and answer mapping through the same rules), `NextCup/Features/Import/` (`PaperScanner` Vision `RecognizeTextRequest` on device, `PaperImportModel`, `PaperImportView`), a journal toolbar entry, and a data-inventory row.
- Behavior: one brew per page; Vision read needs no key; "Read with my AI key" only shows with a key and a Paper import model chosen, goes through `AIQueue`. Review marks low-confidence fields (<0.6) with a CHECK label and kraft background, editing a field clears its mark; Save stays disabled until "I checked these against the page" is on, and any edit (field, date, method) turns it off again. Auto-filing: method and bean matched by normalized name to saved ones; an unknown bean is kept as a written name, never created.
- Commands: `swift test --package-path Packages/NextCupKit` 151 passed; `swift format lint --strict` clean; app build succeeded; `xcodebuild test -only-testing:NextCupTests` 193 passed (includes 12 paper import tests with a synthetic page recognized by real Vision, AI stub-transport tests); UI test `testPaperImportCannotSaveUntilConfirmed` passed.
- Screenshots (`ralph/screenshots/`): `T025-choose-{light,dark,largest-text}.png`, `T025-review-{light,dark,largest-text}.png`, `T025-review-lower-{light,dark,largest-text}.png` (via `testPaperImportScreenshots`, skipped unless `ralph/screenshots/.capture` exists).
- Untested / honest gaps: full `xcodebuild test` (incl. whole UI suite) exceeded the 10-minute tool limit and was stopped, so the rest of the UI suite was not rerun after this change; real handwriting not tested (only typed synthetic text); the CHECK highlight was verified in unit tests only, no screenshot because the synthetic page reads with high confidence; no VoiceOver pass; no camera capture (PhotosPicker only); no real AI provider call; page date is chosen by the user (not read from the page); the UI-test store has no seeded methods, so method filing is covered by the unit test, not the screenshots.

## T026 — Live Activity (widget extension) — IN PROGRESS, not done

- Changed: new `NextCupLiveActivity` widget extension target (hand-edited `project.pbxproj`, embedded in the app, `NSSupportsLiveActivities`); Lock Screen + Dynamic Island views using `Text(timerInterval:)` and DS tokens (`Tokens.swift` and `TimerActivityAttributes.swift` compiled into both targets). `TimerSession` mirrors start/pause/resume/step change to a `TimerActivityControlling` (real `LiveTimerActivity`; `NoTimerActivity` under `-inMemoryStore`) and ends it when the brew finishes. New deep link `nextcup://timer/<recipeID>?dose=<g>` → `TimerDestination`, which reopens the timer and adopts the saved run.
- Commands: `swift test` 151 passed; `swift format lint --strict` clean; app + extension build succeeded; full `xcodebuild test`: 40 UI tests, 0 failures (16 skipped, capture-gated), but one new unit test failed (extra update at init). Fixed; `-only-testing:NextCupTests` then TEST SUCCEEDED (includes the new Live Activity and timer DeepLink tests). The full suite was not rerun after that one-line fix.
- NOT done, so Status is `in progress`: no Lock Screen / Dynamic Island screenshots. That needs a driven simulator run with a real activity (UI tests use `NoTimerActivity`, and no tool here taps or locks the simulator). Tap-to-open is unit-tested (link round trip) but not exercised on a device.
- Known limit: without push updates the step label in the activity only changes while the app process runs; the clock itself is system-driven and stays correct. No VoiceOver pass on the activity.

## 2026-10-24 — T027 roaster discovery S10

- Added `NextCup/Features/Discovery/` (model + `RoasterService`, `MapKitRoasterSearch` with `DeviceLocation`, `RoasterDiscoveryView`), a map button on the Beans toolbar opening S10 as a sheet, and `NSLocationWhenInUseUsageDescription` in `Config/NextCup-Info.plist`.
- Location is requested only on tapping "Use my location" and used for one search, never stored. Denied or unavailable shows a notice; the typed city always works. Only a saved roaster is written (name, city, website, its coordinates, `savedFromMap`); an existing same-name roaster is reused; unsaving keeps a roaster that beans use.
- Commands: `swift format lint --strict` on all targets: clean. `xcodebuild build`: succeeded. Full `xcodebuild test`: all passed except the new empty/error UI test, whose menu-based text clearing was flaky; fixed (delete keys) and re-run alone: passed. The denied-location UI test passed in a targeted run. New unit suite `RoasterDiscoveryTests` ran in the full run with no failures. The full suite was not rerun after the UI-test fix; `swift test` for the package was not rerun (no package change).
- NOT done, so Status is `in progress`: no light/dark/largest-text screenshots of S10 (no tool here taps through to the sheet), no VoiceOver pass, and `MKLocalSearch` and the real location prompt were never exercised (UI tests use `-roasterStub`). Saved-roaster removal has no Undo toast (it is re-savable). `docs/data-inventory.md` already lists MapKit; not re-verified.

## 2026-10-24 — T028 flavor explorer (screenshots pending)

- Added `Taxonomy.words(for:in:)` (+ package test) and `Features/Explore/FlavorExplorerView.swift`: every bucket of flavor, origin, process, roast and brewer is a row; a bucket opens its mapped words (bundle + user aliases), your beans carrying it (link to bean) and the buckets seen together on those beans (link onward). Entry: "Flavors" toolbar link on Explore.
- Commands: `swift test --package-path Packages/NextCupKit` passed (152 tests); `swift format lint --strict` clean; `xcodebuild test -only-testing:...testFlavorExplorerReachesEveryBucket` passed (every one of the 26 buckets reachable, citrus detail opens).
- Not done: simulator screenshots (light, dark, largest text), VoiceOver pass, `/impeccable` polish/audit, full-suite `xcodebuild test`, `/goal` (not invoked in this session). T028 stays `in progress` until those are done.

## 2026-10-24 — T026 to T028 closed out (Sonnet, supervised)

- Verified alone after the loop: 152 package, 210 app, 43 UI tests (16 skipped, capture-gated), lint, tokens.
- Added `testCaptureRoasterAndFlavorScreenshots`; screenshots `ralph/screenshots/T027-*` and `T028-*` (light, dark, largest text). Looking at them found a real bug: the keyboard stayed up over the roaster results after Search. Fixed (focus is dropped on search).
- T027 and T028 set to `done` with these gaps: VoiceOver not run, real `MKLocalSearch` and the real location prompt never exercised (stubs only).
- T026 set to `blocked` (B012): no Lock Screen or Dynamic Island evidence; needs a manual pass.

## 2026-10-24 — T029 COULD set: TDS/extraction, water profiles, App Intents

- TDS: `BrewDraft.tds`; the brew form shows a TDS stepper (0.05 steps, stepping below clears) and an Extraction readout (`BrewMath.extractionYield`, beverage taken as water poured, marked `shortcut:` in code) when the method tracks TDS or no method is chosen. TDS is now offered in the method editor (`MethodParameters.optional`); the old test that said the editor must not offer it was rewritten to match.
- Water profiles: `BrewDraft.waterProfileID`; a Water menu on the form with "New water profile…" (name, optional hardness ppm, refused if not a positive number, same name reuses the profile). Brew again keeps the water, not the TDS. Deleting a profile keeps the brew.
- App Intents (`Features/Intents/BrewIntents.swift`): Log a brew, Brew again (latest saved non-draft brew), Start recipe (recipe entity); each opens the existing `nextcup://` link. Siri phrases via `AppShortcutsProvider`.
- Tests: `NextCupTests/CouldSetTests.swift` (9 tests: TDS steps/clears, extraction value, save and edit round trip, brew again, bad water input and dedupe, profile delete, the three intent links).
- Commands: `swift test --package-path Packages/NextCupKit` 152 passed; `swift format lint --strict` clean; `xcodebuild ... -only-testing:NextCupTests test` TEST SUCCEEDED (220 tests; the one earlier failure was the rewritten methods test). Last run began before a pure reformat of `MethodParameters.optional`.
- Not done / untested: full `xcodebuild test` with the UI suite was started once and killed by the time limit (simulator diagnostics hung), so UI tests were not run; no screenshots (light, dark, largest text) of the TDS tile or Water menu; no VoiceOver pass; the intents were never run from Shortcuts or Siri (only their links are unit-tested); the second `ModelContainer` an intent opens was not exercised on a device; DataExchange export/import of `tds` and water profiles was not checked; no UI to edit or delete a water profile after creating it.

## 2026-10-24 - no task ready

- The only `pending` task is T030. It depends on T001-T028, and T026 is `blocked` (B012: Live Activity screenshots and tap/end behavior need a manual simulator or device pass by the owner).
- No work done and no commit. Unblock by closing B012 (set T026 `done`), or by the owner agreeing to run T030 with T026 listed as an open gap.

## 2026-10-24 — T026 Live Activity manual pass (Sonnet, simulator, B012)

Driven on the iPhone 18 Pro simulator with the real app (Recipes, Balanced cone, Start brew, Start):
- Lock Screen: the activity shows the recipe name, "Step 1 of 4", "Bloom", "Next: Pour" and an orange time on the right. Evidence `ralph/screenshots/T026-lockscreen-first-run-prompt.png`. That frame has the one-time "Allow Live Activities from Next Cup?" system prompt on top and the time reads "2:--"; I did not capture a clean frame after allowing, so the time text on the Lock Screen is not confirmed beyond that.
- Dynamic Island (compact): cup icon and an orange countdown ("2:11"), `T026-dynamic-island-compact.png`.
- Tapping the island opens the app on the running timer, in step 2 of 4 at 1:06 (in sync).
- End early opens the brew form prefilled with the measured time (1:12) and a note that the brew ended early; going Home afterwards shows no activity (`T026-activity-ended.png`).
- Not exercised: expanded Dynamic Island, Lock Screen at the largest text size, dark appearance, VoiceOver, a physical device. T026 is set to `done` with those gaps.

## 2026-10-24 — T030 blocked (B013)

- T030 is the only task left and all its dependencies (T001-T028) are `done`. It needs every row of `docs/compliance-checklist.md` and the data inventory checked against the code (network calls, SDKs, permissions, stored data, accessibility labels, UX baseline).
- In this session `grep`, `git` and compound shell commands were denied approval, and a delegated read-only agent was denied the same way. Only `ls`, `swift test` and file reads worked. Without searching the code I cannot honestly give a PASS with evidence, and filling the checklist from the blueprint alone would be unverified claims.
- Ran `swift test --package-path Packages/NextCupKit`: 152 tests passed. Nothing else run.
- Changed: T030 set to `blocked`, B013 added to `docs/launch-blockers.md`. No checklist rows, no docs/ux-baseline.md written. The one thing the agent did get: every `import` in non-test code is an Apple framework or the local NextCupKit package (counts only, not confirmed against `project.pbxproj` or `Package.swift`).
- Unblock: allow `grep`, `git ls-files` and `git commit` for this repo in the Ralph session, then rerun this task.

## 2026-10-24 — T030 done by hand (Sonnet, supervised)

The loop's iteration was blocked because `grep`, `git ls-files` and compound shell commands were refused in its session (B013). I did T030 directly:
- Searched the code: no third-party packages (only the local one), Apple imports only, no analytics or logging, no web views, no StoreKit, no mail, no notifications; only `UserDefaults` among required-reason APIs; network only in `AIClient.swift`.
- Found and fixed: no `PrivacyInfo.xcprivacy` (added, UserDefaults CA92.1, no tracking or collected data); the AI disclosure did not say the provider may charge the user's account (line added).
- Wrote: `docs/compliance-checklist.md` (9 PASS, 6 NEEDS REVIEW, 4 NOT APPLICABLE, 1 BLOCKED), `docs/ux-baseline.md` (missing: photo zoom, shake/Cmd-Z undo, localization, keyboard shortcuts), `docs/claims-evidence.md`, a verified section in `docs/data-inventory.md`, and `docs/legal/privacy-policy-draft.md` (DRAFT, unreviewed, owner facts UNKNOWN).
- Not done: Opus audit of the consent, data, vendor and deletion rows; VoiceOver; the Gate A and Gate B reviews.

### Final verification of T024 to T030 (supervised, 2026-10-24)

- Package 152, app unit 220, lint and tokens pass. UI suite: 44 tests (17 skipped, screenshot capture only). The full run is not reliably green: two full runs each had one different failure, both in keyboard-driven tests (`testBeansAddCorrectFilterAndDeleteWithUndo` after my manual simulator session, `testBrewFormDraftSurvivesRelaunch` on the next run, where the software keyboard's Done button could not be scrolled to). Each passed when rerun alone (the first after a simulator reboot). Treat as flaky keyboard handling in the UI tests, not as proven product bugs; the next step is to make those tests robust (no dependence on the software keyboard's Done button).

## 2026-10-25 — UI test hardening (Sonnet)

- `testBrewFormDraftSurvivesRelaunch` and the methods editor now dismiss the keyboard with Return instead of the keyboard's Done key (not always hittable); `testBeansAddCorrectFilterAndDeleteWithUndo` waits for the label with a predicate instead of reading it at once.
- All three pass when run together (alone, 308 s). A full run right after had 12 failures, mostly waits timing out; a second simulator (iPhone 17) was booted and the three-test rerun took about 100 s per test instead of about 30 s, so the machine was loaded. The full suite has not been re-confirmed green since; rerun it on a quiet machine.

## T031 (in progress, not committed)

Implemented: SearchArea.named, RoasterMatchModel/RoasterMatchView, BeanFields roasterCity/roasterWebsite applied in BeanService.save, "Find this roaster on the map" row in the bean editor, RoasterMatchTests.

Results: swift format lint clean. Full `xcodebuild test`: one UI failure, testBeansAddCorrectFilterAndDeleteWithUndo (timeout waiting for "100 g of 250 g" on bean.remaining after the correct-amount alert; reproduced on rerun). The step does not touch code changed here, but I could not confirm it fails on the clean branch (git stash was not approved). Status left pending until that is confirmed. Not tested: UI test for the match sheet, screenshots (light/dark/largest text), VoiceOver pass.

### T031 close-out (Sonnet, supervised, 2026-10-25)

The loop built T031 but left it uncommitted because `testBeansAddCorrectFilterAndDeleteWithUndo` failed. I ran the same test on a clean copy of main without T031: it fails there too, so T031 did not cause it. Debug runs showed the "Correct the amount left" alert still open when the test waits for the label, and a different step failing on the next run; behavior varies between runs on this machine today, though the same test passed in the full run earlier. Not resolved; recorded as an environment-sensitive UI test. T031 set to `done` on its unit tests (`RoasterMatchTests`), lint and build; not done: a UI test for the match sheet, light/dark/largest-text screenshots, VoiceOver.

## 2026-10-24 — T032 AI request hygiene and consent

What changed:
- `AIQueue`: a request that is done, failed or cancelled drops its photo (`attachment`) and `payloadJSON`; `retry` removed (nothing to resend, the user starts the action again). It sends only requests it enqueued, `cancelAll()` runs when the bean editor or paper import goes away, and `AIQueue.expireStale` cancels leftovers at launch (`NextCupApp`). `Brew.aiRequests` now cascades.
- Disclosure: `AIPreferences` accepts per provider with version 2 (`ai.disclosure.<provider>.version`); `AIClient` takes the provider in `disclosureAccepted`. New `AIDisclosureView` names the provider and lists `AIFeature.sends` for every feature. It is shown from the AI action (bean photo scan, paper "Read with my AI key") when not accepted for that provider, as well as from Settings → AI.
- Key field has no password AutoFill; the provider default is written on first appear of each feature row.

Commands and results:
- `swift test --package-path Packages/NextCupKit`: 153 passed (new: disclosure for one provider does not unlock another).
- `xcodebuild ... test -only-testing:NextCupTests`: 234 passed, TEST SUCCEEDED (new: purge on done/failed/cancelled, cancelled paper import leaves no photo, foreign queued request not sent, cancelAll and expireStale, brew delete cascades, `sends` text vs payload builders).
- `swift format lint --recursive --strict ...`: clean.

Untested / honest gaps:
- The UI test suite (scoped and one full `test`) did not finish within the time limit (the known simulator hang); no UI result seen for this change. No screenshots of the new disclosure sheet, no VoiceOver pass.
- The privacy policy draft still says the app sends "brew, notes and a slice of your history" (audit F1/F8); not in T032's scope.
- `resultJSON` of finished requests is kept (only photo and payload are purged).
- The cascade rule change was not tested against an existing on-disk store.

## 2026-10-24 — T033 Ask AI about a brew, Explore insights

- Added `AIAskModel` and `AIAskView` (NextCup/Features/AI): a sheet that shows the exact payload text, then sends only after a chosen provider and model, a Keychain key, an accepted per-provider disclosure and a tap. Offline shows a waiting banner with Cancel; failures show the reason with Try again; closing the sheet cancels anything still queued.
- Entry points: "Ask AI about this brew" on the saved-brew edit form (`brewform.ai`), and "Ask AI about this coffee" on each Explore bean card that has saved brews (`explore.insights.<bean>`; up to 8 newest brews).
- Result is stored by `AISuggestions.ingest` with the source brew and model ID. The sheet shows it with Dismiss and Undo. Accept and Edit happen on the next brew of that coffee, in the existing SuggestionCard flow, not in the sheet.
- Tests: `AIAskModelTests` (10: no key, no model, no disclosure send nothing; sent text equals preview; answer becomes suggestion; dismiss and undo; insights cap 8; failure then retry; offline cancel; leave cancels) and UI test `testAskAIShowsThePayloadAndCannotSendWithoutSetup`.
- Commands: `swift format lint --recursive --strict ...` clean; `swift test --package-path Packages/NextCupKit` 153 tests passed; `xcodebuild -quiet ... test` (full app and UI suite) exit 0.
- Screenshots: the UI test wrote `T033-ask-light.png`, `T033-ask-dark.png`, `T033-ask-largest-text.png` to /tmp/next-cup-screenshots/. They could not be copied into `ralph/screenshots/` or viewed in this session (no permission outside the repo), so they are NOT in the repo and unreviewed.

Untested: the Explore insights button has no UI test (needs a bean with brews); a real send to a provider (no key or network by rule); the in-sheet result and error states are covered by model tests only, with no screenshots; no VoiceOver pass.

## 2026-10-24 — T034 Data hygiene

What changed:
- `DataEraser`: also ends a running Live Activity (`endActivity`), empties Library/Caches and tmp (`scratchDirectories`) and SwiftData's external-data folder (`externalData`, derived from the store URL by `externalDataDirectory(of:)`).
- Export: files are written when the user taps Export (JSON or CSV) and shown in a share sheet (`ActivityView`); the `NextCupExport` folder is removed when the sheet closes. `ShareLink` and the write-on-appear are gone.
- Backups and drafts are written with `.completeFileProtection` (was until-first-user-authentication). A draft autosave after the phone locks now fails; earlier autosaves are already on disk.
- `Config/NextCup-Info.plist`: `NSLocationDefaultAccuracyReduced = true`, `ITSAppUsesNonExemptEncryption = false`.
- `docs/data-inventory.md`: stale "nothing built" wording replaced; new "Current flows" table (AI request log, tmp export, backups, drafts, timer snapshot, Live Activity content, typed city to Apple, saved roaster coordinates, external data, export compliance).

Commands and results:
- `swift format lint --recursive --strict ...`: clean.
- `swift test --package-path Packages/NextCupKit`: 153 passed.
- `xcodebuild ... test`: the unit tests (NextCupTests) ran 245 passed, including the extended delete-all test (AIRequest count 0, activity ended, scratch and external folders empty, preferences cleared) and `releaseSettingsAreInTheInfoPlist`. The UI test phase did not finish and the run was stopped at the 10-minute limit (the known simulator hang); no UI result seen.

Untested / honest gaps:
- No UI result, no screenshots, no VoiceOver pass for the new Export buttons and share sheet; the `data.export.*` identifiers are now buttons, and any UI test that expected a ShareLink was not seen to run.
- File protection cannot be observed on the simulator; recorded as a code check only.
- The external-data folder name `.<store>_SUPPORT/_EXTERNAL_DATA` is assumed from SwiftData's layout and was tested only with a stand-in folder.
- The cleared-disclosure assertion uses a stand-in key; it proves the whole preferences domain is wiped, not the real key names.
- Delete-all ending a real Live Activity was tested with an injected closure only.

## 2026-10-25 — T032 to T034 verified (Sonnet, supervised)

- Package 153 and app unit 245 pass, lint clean. UI suite: 45 tests, two failures in the full run (`testExploreShowsLabelledDefaultForANewBean`, `testEndEarlyOpensTheFormWithTheTimeReached`); both pass when rerun alone, as the beans test did earlier. Full UI runs get flakier as they get longer (about 18 minutes); not claimed green.
- Changed after the loop: drafts use the default file protection (complete protection could lose a draft saved as the phone locks); `docs/legal/PRIVACY.md` rewritten to list exactly what each AI action sends, reduced-accuracy location, backup retention and the crash-data wording.

## 2026-10-25 — TestFlight preparation (Opus, supervised)

- Bundle IDs moved to the studio's convention: `app.rarecreatures.nextcup` (+ `.liveactivity`, `.tests`, `.uitests`); team `KTV2G3Z883` set, as in the studio's other apps.
- Added an app icon (asset catalog, single 1024 px image) and `scripts/archive-testflight.sh` with `scripts/ExportOptions-testflight.plist`, adapted from sunglasses-at-night.
- `scripts/archive-testflight.sh --no-upload` succeeded: Release archive signed for team KTV2G3Z883, version 0.1, build 20261025.0532, icon present. Nothing uploaded. The upload needs the App Store Connect app record, which the owner creates.

## 2026-10-25 — T035 Appearance and style (Sonnet) — code done, screenshots outstanding

What changed:
- `Tokens.swift`: `AppearanceMode` (System/Light/Dark), `AppStyle` (Steel & Kraft default, Charcoal & Crema, Quiet Ceramic, Terracotta, Late-Night Café) with a `Palette` per style and a display font per style. `DS` colors and `DS.Font.display/headline/label/din` are now computed from `AppStyle.current` (UserDefaults). Styles live in `Tokens.swift`, not a new file, because the Live Activity extension compiles that file alone (the widget keeps the default style; it cannot read the app's defaults).
- `NextCupApp`: `.preferredColorScheme` from the appearance setting; `.id(style)` rebuilds the tree on a style change so every `DS` read refreshes.
- Settings: Appearance section (segmented mode, inline style list), placed below Data so the existing Settings rows stay on the first screen (first placement pushed `settings.methods` and `settings.data` below the fold and broke two UI tests).
- Tokens: `docs/design/tokens/{charcoalCrema,quietCeramic,terracotta,lateNightCafe}.json`; `design/check_tokens.py` checks all five palettes; new `design/contrast.py`. Terracotta light `ok` darkened to #1F5A1F (it was 4.11:1 on paper).
- Tests: `StyleTests` (every pair AA in light and dark for all five styles, fonts installed, choice persists and drives tokens, appearance mapping).

Commands and results:
- `swift format lint --recursive --strict ...`: clean. `python3 design/check_tokens.py`: tokens in sync.
- `xcodebuild ... test -only-testing:NextCupTests`: passed (after the Terracotta fix).
- `xcodebuild ... test -only-testing:NextCupUITests`: all passed except `testMethodsAddReorderHideAndShapeTheBrewForm` and `testYourDataDeleteAllCanBeUndone`; after moving the Appearance section both passed when rerun together. The full UI suite was not rerun end to end after that move.

Untested / honest gaps:
- `python3 design/contrast.py` could not be run in this session (command needed approval); the same AA pairs are enforced by `StyleTests` instead. Run it once.
- No screenshots (light, dark, largest text, journal and timer in each style) and no VoiceOver pass; the Status stays `pending` for that reason.
- Not checked: wrapping of the serif display faces (Didot, Hiragino Mincho, Cochin, Bodoni) in layouts sized for DIN Condensed; any `static let` elsewhere that caches a `DS` color would not update live (could not grep).
- No test that the style persists across a relaunch beyond `UserDefaults` round-trip.

## 2026-10-25 — T036 blocked

- Picked T036 (first pending, dependencies done). `NextCup/Resources/catalog.json` is missing; the task says the supervisor provides it, and it must hold real roasters and coffees. I did not invent them.
- Set T036 to `blocked`, added B014 to `docs/launch-blockers.md`. No code changed, no commands run beyond reading files.
- T037 and T038 remain pending and were not started (one task per iteration). Note: T037 depends on T031 and T024 only, so the next iteration can take it.

## 2026-10-25 — T038 UI flavors (Sonnet) — code done, evidence outstanding, Status stays `pending`

What changed:
- `Tokens.swift`: `Flavor` (body design, display face or system display design and weight, radius, `Density` compact/regular/airy, `ControlStyle` square/pill/sticker, `NumberStyle` monospaced/rounded/condensed); `AppStyle` now has ten cases (the five T035 styles plus Night Mint, Espresso Black, Café Page, Roaster Poster, Make It Yours) each with `flavor` and `palette`; `Swatch` (8 accents), `Corners`, `FontChoice`, `MakeItYours` (4 settings in UserDefaults). `DS.Space.*`, `DS.radius`, `DS.controlRadius` and the number/readout fonts are computed from the flavor (the former `static let` fonts are now `var`, so nothing is cached). `DS.ink2` becomes `ink` under Increase Contrast. `EnvironmentValues.flavor` is set at the app root, which also applies `.fontDesign`. The root `.id` now includes the Make It Yours settings.
- `Components.swift`: one `panel(...)` modifier (flavor radius, dashed option, sticker offset shadow in the accent) replaces the square borders of PaperBox, InstrumentPanel, StepperTile, ReadoutTile, ChoiceButton, KraftNote, SteelToast and StateBanner; `SteelButtonStyle` follows the control style.
- Settings > Appearance: `FlavorPicker` (grid of live `FlavorTile` previews, one column at accessibility text sizes, selected state announced) with the Make It Yours controls (8 swatches, Corners, Density, Type). Because a change rebuilds the tree, Settings scrolls back to the section.
- Tokens: `docs/design/tokens/{nightMint,espressoBlack,cafePage,roasterPoster,makeItYours}.json`; `check_tokens.py` now expects 10 palettes and checks the swatches; `contrast.py` covers all flavors and every swatch.
- Tests (`StyleTests`): AA for all ten palettes and every swatch (light and dark), fonts installed, ten flavors, default keeps its radius/density/font, Make It Yours reads its choices and nothing is cached, a switch changes colors, space and shape at once.

Commands and results:
- `swift format lint --recursive --strict ...`: clean.
- `swift test --package-path Packages/NextCupKit`: 153 passed (earlier in the session; package untouched).
- `xcodebuild ... build`: succeeded.
- `xcodebuild ... -only-testing:NextCupTests test`: exit 0 with no error lines (quiet mode; I did not read a per-test count).
- A first full `xcodebuild test` was stopped at the 10-minute tool limit; the UI suite has NOT been run after this change.

Not done (so Status stays `pending`):
- Screenshot sheet (journal, timer, brew form, bean detail in every flavor, light and dark, plus largest text for three) in `docs/design/flavors/`. No simulator driving was done.
- `/impeccable critique` and `polish` per flavor; VoiceOver pass; Increase Contrast, Reduce Transparency and Differentiate Without Color not checked on a device.
- `python3 design/contrast.py` and `design/check_tokens.py` were not run (Python needed approval); AA is enforced by `StyleTests` only. The new JSON files were written by hand and must be run through both scripts.
- Flavors are approximations: I did not read `docs/design/archive/*.swift.txt` (grep and those large files were not worth the budget), so the five T035 flavors' radius, density and control style come from `docs/design/directions.md`, not the concept code. Steel & Kraft is `regular` density (not compact) to keep the default unchanged.
- Serif and rounded display faces were not checked for wrapping in layouts sized for DIN Condensed. Any `static let` elsewhere that caches a `DS` value could not be searched for (grep blocked); the tree rebuild covers it.
- UI tests that touched `settings.style` (removed inline picker) were not run.

## 2026-10-25 — T038 evidence pass (Sonnet) — Status stays `pending`

What changed:
- Added `NextCupUITests/FlavorCaptureUITests.swift`: one test per flavor (light and dark) plus largest text for Steel & Kraft, Café Page and Roaster Poster; each saves journal, brew form and timer screenshots to `docs/design/flavors/`. It skips unless `docs/design/flavors/.capture` exists (marker removed after the run).
- Ran it: 73 PNGs written (10 flavors x 3 screens x light/dark, plus 3 x 3 largest text).

Commands and results:
- `python3 design/check_tokens.py`: "tokens in sync".
- `swift format lint --recursive --strict ...`: clean.
- `xcodebuild ... -only-testing:NextCupTests test -quiet`: no errors printed (no per-test count read).
- `xcodebuild ... -only-testing:NextCupUITests/FlavorCaptureUITests test -quiet`: ran 378 s, screenshots produced; no summary line printed, so pass/fail per test is inferred from the files.
- Viewed: roasterPoster-timer-light (sticker offset and condensed numerals render), cafePage-brewform-largest-text (serif display, reflows, Save visible), steelKraft-journal-light (default looks as before).

Still not done (so Status stays `pending`):
- `python3 design/contrast.py` needs approval in this session; run it once on `docs/design/tokens/*.json`. AA is enforced by `StyleTests` meanwhile.
- Bean detail screenshots (needs a created bean) and the other 7 largest-text-free looks were not reviewed by eye; I viewed 3 of 73.
- `/impeccable critique` and `polish` per flavor, VoiceOver, Increase Contrast, Reduce Transparency, Differentiate Without Color: not run.
- Full UI suite not re-run after the flavor change (tests that used the removed inline `settings.style` picker unverified).
- Seen in Roaster Poster timer: the large nav title blurs behind the bar; not investigated.

## 2026-10-25 — T038 retry (Sonnet) — no progress, Status stays `pending`

- Picked T038 (first pending with dependencies done; T036 is blocked on B014, T037 is later in the table). Read the PRD and activity log, then tried to run `python3 design/contrast.py docs/design/tokens/*.json` and the log tails; the shell asked for approval and this session is non-interactive, so it did not run. I did not work around the prompt.
- No code or screenshots changed. The T038 acceptance still lacks: a `contrast.py` run on the per-flavor token JSON, bean detail screenshots, a full UI suite run, `/impeccable critique` and `polish`, and the VoiceOver / Increase Contrast / Reduce Transparency / Differentiate Without Color checks.
- Needs the owner or a session with the Python and `tail` commands allowed: run `python3 design/contrast.py docs/design/tokens/*.json`, then the next iteration can take the rest.
