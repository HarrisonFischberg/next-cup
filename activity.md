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
