# next-cup — PRD

Status: APPROVED by the owner with `docs/blueprint.md` (Phase 3,
2026-10-21). Created 2026-10-21.

## Purpose

Native iPhone coffee brew journal with AI dial-in, bean taxonomy, recipe matrix, and paper-journal import. App name: **Next Cup**. Audience: coffee aficionados who brew precisely every day and want to dial in and improve the next cup. Success in 30 days: a portfolio piece, distributed by TestFlight and a public GitHub repo. Free, no ads, no accounts, local-first.

Positioning (default angle A, confirm at the brand phase): for home brewers
who log carefully but still guess at the next cup, Next Cup turns past brews
into the next recipe.

## Decisions from intake

- Platform: iPhone only, native SwiftUI, SwiftData on device, iOS 27 minimum (blueprint §1). Light and dark, both fully supported.
- AI: bring-your-own OpenAI or Anthropic key held in the Keychain, per-feature model selection, calls direct from the device, no backend (ASSUMED). No AI call until a key is added; disclosure before the first call.
- Offline: logging, notes, photos, recipes, and history work offline. AI requests queue with visible status. Imported recipes are cached.
- Approval stops: reference comparison (done), blueprint (this), design pick, repo creation (done).
- Design concepts to build in Phase 3B: Charcoal & Crema, Quiet Ceramic, Terracotta Hand-Thrown, Steel & Kraft, Late-Night Café.
- Brand: none yet. Domain rarecreatures.app and a paid Apple developer account exist.

## Product features (ranked)

| # | Feature | Priority | Spec |
| --- | --- | --- | --- |
| 1 | Brew journal with actual values, brew again, honest saves, one units setting | MUST | prompt 01, X2 X5 X8 |
| 2 | Recipes with step kinds beyond pour/wait, scale to dose, own recipes | MUST | prompt 02, X1 |
| 3 | Guided brew timer with haptics, one-handed controls | MUST | prompt 03, X7 |
| 4 | Brew methods: built-ins, custom methods, tracked parameters per method | MUST | prompt 04, X1 |
| 5 | Bean library and roasters, remaining stock, freshness | MUST | prompt 05 |
| 6 | Taxonomy (shared buckets) and recommendation matrix, on device | MUST | prompt 06 |
| 7 | Rule-based dial-in with suggestions saved and shown on the next brew | MUST | prompt 07, X4 |
| 8 | Export (CSV, JSON), merge import, automatic local backup, delete all | MUST | prompt 10, X5, safeguard 20 |
| 9 | AI features: brew diagnosis, photo interpretation, bag recognition, insights | SHOULD | prompt 07 |
| 10 | Paper-journal import with review screen (Vision without a key) | SHOULD | prompt 08 |
| 11 | Live Activity for the timer | SHOULD | prompt 03, X7 |
| 12 | Bean best-so-far card; freeze/thaw, decaf, blends | SHOULD | X3, X6 |
| 13 | Local roaster discovery (MapKit) | SHOULD | prompt 09 |
| 14 | Flavor explorer (taxonomy browser) | SHOULD | features.csv |
| 15 | TDS and extraction yield | COULD | features.csv |
| 16 | Water profiles | COULD | features.csv |
| 17 | App Intents (Log a brew, Brew again, Start recipe) | COULD | features.csv |
| 18 | In-app assistant | COULD | intake; after AI features |
| 19 | Optional iCloud sync | COULD | schema ready (blueprint §2) |
| 20 | Creator recipe import with credit | COULD | blocked on B004 |

## Non-goals

Accounts, social features, feeds and sharing to others, café check-ins,
paywall or paid tier, ads, analytics, Bluetooth scales and pressure devices
(deferred by owner), Apple Health, home roasting, AR gear previews, editorial
content, iPad, Android, web, a backend of any kind.

## REA and Replica findings

See `docs/rea-findings.md`, `replica/recon.md`, `replica/comparison.md`,
`replica/architecture.md`, and the intentional differences in
`replica/README.md`.

## Design directions (Phase 3B scope)

All five concepts cover the same **core screen and flow: F01, guided brew and
log** — recipe detail (S07) → guided timer (S05) → prefilled log form (S02) →
journal list (S01). Each concept shows S05 and S02 in light and dark, empty
and filled states, at default and the largest accessibility text size.

## Verification commands

| Check | Command |
| --- | --- |
| package tests | `swift test --package-path Packages/NextCupKit` |
| build | `xcodebuild -project NextCup.xcodeproj -scheme NextCup -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build` |
| app + UI tests | `xcodebuild -project NextCup.xcodeproj -scheme NextCup -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test` |
| lint | `swift format lint --recursive --strict NextCup NextCupTests NextCupUITests Packages/NextCupKit/Sources Packages/NextCupKit/Tests` |

Types are checked by the build (Swift 6 strict concurrency, warnings as
errors in `NextCupKit`).

## Atomic tasks

Order is dependency order. "UI" tasks also need `/impeccable polish` and
`/impeccable audit` on simulator screenshots, VoiceOver and largest Dynamic
Type checks, per the platform profile.

| ID | Task | Depends on | Acceptance criteria | Verification | Status |
| --- | --- | --- | --- | --- | --- |
| T001 | Create Xcode project (synchronized folders), `NextCupKit` package, UI test target, swift-format config | — | Empty app launches on iPhone 18 Pro sim; `swift test` and `xcodebuild test` run green with one placeholder test each | build, package tests, app tests | done |
| T002 | SwiftData schema v1 (all models in blueprint §2), `Store` with upsert by `id`, migration plan | T001 | Models match blueprint; CloudKit-compatibility test (no unique attributes, all defaults/optional) passes; in-memory CRUD tests | app tests | pending |
| T003 | Bundled `methods.json`, `recipes.json`, `taxonomy.json` (original content) and idempotent seeding by `builtInKey` | T002 | Seeding twice creates no duplicates; a newer bundle adds keys without overwriting edits | app tests | pending |
| T004 | `BrewMath`, `RecipeScaler`, `Freshness`, units conversion in `NextCupKit` | T001 | Unit tests: ratio, espresso ratio, extraction yield, scaling incl. ice, rounding notes, freshness incl. frozen spans, °C/°F and g/oz round trips | package tests | pending |
| T005 | `TimerEngine` with injectable clock, persisted start and pauses | T001 | Fake-clock tests: step changes, pause/resume, skip, end early, restore after simulated termination | package tests | pending |
| T006 | App shell: tab bar (Journal, Recipes, Beans, Explore, Settings), deep links, scene restoration, design-system token stubs from Phase 3C | T002, Phase 3C | Each `nextcup://` link opens the right screen (UI test); tab restores after relaunch | app tests | pending |
| T007 | Recipe library S06, detail S07 with step timeline, scale-to-dose | T003, T004, T006 | Grouped by style, searchable; scaling updates every target; VoiceOver reads each step as "kind, time, target" | app + UI tests | pending |
| T008 | Guided timer S05 (haptics, one-handed bottom controls, Reduce Motion) | T005, T007 | Runs a recipe end to end; background/foreground UI test passes; opens S02 prefilled at the end | app + UI tests | pending |
| T009 | Brew form S02 with `DraftStore`, honest saves, actual values, photo with metadata stripped | T004, T006 | Autosave restores after relaunch; simulated write failure shows error and keeps draft; keyboard never covers Save at largest text size; EXIF/GPS absent in stored photo | app + UI tests | pending |
| T010 | Journal list S01: search, filter by method and bean, empty / no-results states, swipe delete with Undo | T009 | **Vertical slice complete:** UI test logs, edits, and finds a brew via F01 | UI tests | pending |
| T011 | Brew again (X2) and edit any saved brew | T010 | Prefill tests (same bean + method, timing reset); UI test repeats a brew | package + UI tests | pending |
| T012 | Methods S09: add, rename, reorder (drag + non-gesture alternative), hide, tracked parameters | T009 | Brew form shows exactly enabled parameters; hidden method keeps history | app + UI tests | pending |
| T013 | Recipe editor S08 with all step kinds (X1); save customized copy | T007 | Editor round-trip tests; built-in switchable dripper and inverted press present | app tests | pending |
| T014 | Bean library S03 and detail S04, roasters, remaining stock, freshness, status filters | T003, T004, T009 | Remaining math with manual edits; filter and sort remembered | app + UI tests | pending |
| T015 | Blends, decaf, freeze/thaw (X6) and best-so-far card (X3) | T014 | Blend brew deducts from each bean; best-so-far shows rating spread, best settings, grind history by grinder and dose | app tests | pending |
| T016 | `Taxonomy` service + user aliases + "Unmapped" flow | T003 | Deterministic mapping tests; user alias overrides bundle | package tests | pending |
| T017 | `Recommender` + Explore tab recommendations with explanation | T016, T014 | Synthetic-history ranking tests; explanation built only from computed facts; cold start labelled as default | package + app tests | pending |
| T018 | Rule-based dial-in + `Suggestion` cards (accept / edit / dismiss), shown on next brew and in history (X4) | T011 | Rules tests per verdict; persistence tests; suggestion visible on the next brew of that bean | package + UI tests | pending |
| T019 | Export CSV/JSON, merge import with preview, daily backup keep 7, restore, delete all with Undo where possible | T010, T014 | Export → wipe → import round trip lossless; conflicts never overwrite silently; delete all clears store, drafts, backups, keys | app tests | pending |
| T020 | Settings: units everywhere (X8), privacy summary, about, data controls | T019 | Changing units updates journal, recipes, timer, form (UI test) | UI tests | pending |
| T021 | `KeychainStore`, AI disclosure, per-feature model picker | T020 | Disclosure shown once before the first call; key not in UserDefaults, logs, or backups | app tests | pending |
| T022 | `AIClient` (Anthropic, OpenAI) over a `Transport` protocol, schema-validated output; `AIQueue` with offline status and cancel | T021 | Stub transport proves no call without key + tap; retry max 3; invalid JSON never becomes a suggestion | package + app tests | pending |
| T023 | AI brew diagnosis and insights as `Suggestion`s | T018, T022 | Same card flow as rules; stored with source brew and model ID | app tests | pending |
| T024 | Photo interpretation and bag recognition → bean draft | T022, T014 | Bag result fills a bean draft for review, never saves blind | app tests | pending |
| T025 | Paper import S-import: Vision OCR without a key, AI with a key, review screen, auto-filing | T013, T016, T022 | Save blocked until confirmed; field-mapping tests with synthetic images; low-confidence fields highlighted | app + UI tests | pending |
| T026 | Live Activity (widget extension) mirrored from `TimerEngine` | T008 | Snapshot of Lock Screen and Dynamic Island; tap deep-links to timer; ends with the brew | app tests + sim screenshot | pending |
| T027 | Roaster discovery S10 (MapKit, location in context, typed-city fallback) | T014 | Denied-location path works; only saved roasters persist | UI tests | pending |
| T028 | Flavor explorer (taxonomy browser linking flavors, origins, processes) | T016 | Every bucket reachable; VoiceOver navigable | UI tests | pending |
| T029 | COULD set: TDS/extraction UI, water profiles, App Intents | T019 | Each behind its own acceptance test; may be dropped without blocking Gate A if the owner agrees | app tests | pending |
| T030 | Safeguards and UX baseline pass (Phases 5, 5B): privacy policy draft, data inventory verified against code, asset licenses, accessibility evidence, `docs/ux-baseline.md` | T001–T028 | All 20 rows in `docs/compliance-checklist.md` have status and evidence; no unexplained UX baseline gaps | per row | pending |

## Safeguard coverage

| Safeguards | Covered by |
| --- | --- |
| 1 privacy policy, 16 business details | T030 + B005, B006 (owner facts) |
| 2 terms, 3 refund, 10 hidden fees | Free, no purchases: likely NOT APPLICABLE with reason; terms draft only if TestFlight review needs it (T030) |
| 4 cookie policy, 5 consent banner | No web surface, no tracking: NOT APPLICABLE with reason (T030) |
| 6 form consents | AI disclosure (T021); no marketing forms |
| 7 no unnecessary data | Blueprint §6 permissions, EXIF stripping (T009), location not stored (T027) |
| 8 SDK audit | Zero third-party packages (blueprint §1), verified at T030 |
| 9 dark patterns | No paywall, no streak pressure, Undo over confirm (T010, T019) |
| 11 fake reviews, 12 claims | No testimonials; claims in `docs/claims-evidence.md` (T030) |
| 13 alt text, 14 contrast, 15 keyboard/assistive | Every UI task's VoiceOver and Dynamic Type check; contrast in Phase 3C tokens |
| 17 children | Minimum age decision (owner, T030) |
| 18 email unsubscribe | No email: NOT APPLICABLE with reason |
| 19 licenses | Original bundled data and art; `docs/asset-licenses.md` (T003, T030) |
| 20 data deletion | Delete all + export (T019) |

## Human review and launch blockers

See `docs/launch-blockers.md`. Open before TestFlight external testing: B004
(creator import), B005 (privacy policy URL), B006 (policy and AI disclosure
review). Open before Phase 4: B002 (Ralph runner, `/goal`).
