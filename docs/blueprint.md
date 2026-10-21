# Next Cup — Blueprint

Status: DRAFT for owner approval (Phase 3, 2026-10-21).
Inputs: `replica/recon.md`, `replica/features.csv`, `replica/comparison.md`,
`replica/prompts/`, `PRODUCT.md`, `prd.md`. Replica's architecture pass is in
`replica/architecture.md`; this file is the binding spec for Phase 4.

## 1. Stack decision

| Layer | Choice | Why |
| --- | --- | --- |
| Language / UI | Swift 6.4, SwiftUI, strict concurrency on | Intake chose native SwiftUI; Swift 6 catches data races in the timer and AI queue at compile time |
| Minimum OS | iOS 27.0, iPhone only | Only the iOS 27 simulator runtime is installed, so every supported OS is testable; TestFlight testers in late 2026 are on 27. Gives current SwiftData (`#Index`, history) and Live Activity APIs |
| Persistence | SwiftData, one local store | Intake; first-party, no SDK; schema kept CloudKit-compatible so optional iCloud sync (COULD) is an add-on, not a migration |
| State | `@Observable` models + `@Query` | First-party, no Combine or third-party state library |
| Domain logic | Local Swift package `NextCupKit` (pure Swift, no UI) | Ratio, scaling, timer engine, freshness, taxonomy, recommender, dial-in rules and AI request building test with `swift test` in seconds, no simulator |
| Live Activity | ActivityKit + WidgetKit extension | Timer on Lock Screen and Dynamic Island (prompt 03, X7) |
| Text recognition | Vision `RecognizeTextRequest`, on device | Paper import works without an AI key (prompt 08) |
| Maps | MapKit `MKLocalSearch` + SwiftUI `Map` | Roaster discovery without a backend or API key (prompt 09) |
| Secrets | Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) | Keys never leave the device, never in backups |
| Networking | `URLSession` to OpenAI and Anthropic only | BYO key, direct from device, no backend (intake) |
| Project file | Xcode project with synchronized folder groups | No generator tool needed; folders on disk are the source of truth, so parallel worktrees rarely conflict in `project.pbxproj` |
| Tests | Swift Testing (package + app), XCUITest (flows) | First-party |
| Lint / format | `swift format` (ships with the toolchain) | No extra install |
| Third-party packages | **None** | Safeguard 8: zero SDKs to audit; privacy label "Data Not Collected" is achievable |

Rejected options:

| Option | Why not |
| --- | --- |
| Expo / React Native | Intake chose native; Live Activity, Vision and haptics are first-class in Swift |
| Core Data directly | SwiftData covers the model with less code; Core Data stays reachable underneath if needed |
| SQLite via GRDB | Adds a dependency and loses `@Query` and the CloudKit path |
| Thin proxy backend for AI | Conflicts with no-backend, $0 budget; would make the developer a data processor (ASSUMED Q10 alternative) |
| XcodeGen / Tuist | Not installed; synchronized folders solve the merge problem without a new tool |
| iOS 26 minimum | No iOS 26 runtime installed, so it could not be verified (safeguard rule: untested is not PASS) |

## 2. Data model (SwiftData)

Conventions for every model:

- `id: UUID` (stable across export/import), `createdAt`, `updatedAt` as `Date` (UTC).
- **CloudKit-compatible**: no `@Attribute(.unique)`, every stored property has a
  default or is optional, every relationship is optional with an explicit
  inverse. Uniqueness of `id` is enforced in the data layer (`Store.upsert`).
- Canonical units only: grams, °C, seconds. Conversion happens at display (X8).
- Ratings are `ratingHalfSteps: Int?` 1–10 (0.5–5 stars); `nil` = unrated.
- Photos: `@Attribute(.externalStorage) var photo: Data?`, re-encoded on save
  with **EXIF and GPS metadata stripped**.
- Access rules: single user, single device. No owner column. The store sits in
  the app sandbox with Data Protection `completeUntilFirstUserAuthentication`.
  Nothing is readable by other apps; the Live Activity gets only timer state.

| Model | Fields (type) | Relationships (delete rule) | Indexes |
| --- | --- | --- | --- |
| `Brew` | `date: Date`, `doseG: Double?`, `waterG: Double?`, `yieldG: Double?` (espresso), `grindSetting: String?`, `grindValue: Double?`, `tempC: Double?`, `totalTimeS: Int?`, `tds: Double?`, `ratingHalfSteps: Int?`, `verdict: Verdict?` (sour, bitter, weak, strong, balanced), `notes: String`, `photo: Data?` (external), `targetsJSON: Data?` (recipe targets shown alongside, never locked), `isDraft: Bool` | `method → BrewMethod` (nullify), `recipe → Recipe` (nullify), `grinder → Grinder` (nullify), `beans → [BrewBean]` (cascade), `waterProfile → WaterProfile` (nullify), `suggestionsMade → [Suggestion]` (cascade), `suggestionFollowed → Suggestion` (nullify) | `date`, `isDraft` |
| `BrewBean` | `grams: Double`, `beanNameSnapshot: String` | `brew` (inverse), `bean → Bean` (nullify) | — |
| `Bean` | `name`, `originCountry?`, `region?`, `farm?`, `process?`, `varietal?`, `roastLevel: RoastLevel?` (ultraLight…dark), `roastDate: Date?`, `bagFlavorNotes: [String]`, `bagWeightG: Double?`, `remainingAdjustmentG: Double` (manual correction), `status: BeanStatus` (inUse, buyAgain, wishlist, finished), `isDecaf: Bool`, `frozenOn: Date?`, `thawedOn: Date?`, `ratingHalfSteps: Int?`, `photo: Data?` | `roaster → Roaster` (nullify), `brewUses → [BrewBean]` (inverse) | `status`, `roastDate` |
| `Roaster` | `name`, `city?`, `website: URL?`, `latitude?`, `longitude?`, `savedFromMap: Bool` | `beans → [Bean]` (nullify) | `name` |
| `BrewMethod` | `name`, `style: BrewStyle` (pourOver, immersion, espresso, cold), `symbol: String`, `trackedParameters: [BrewParameter]`, `defaultStepKinds: [StepKind]`, `sortOrder: Int`, `isHidden: Bool`, `builtInKey: String?` | `recipes`, `brews` (nullify; hidden methods keep history) | `sortOrder` |
| `Recipe` | `name`, `credit: String?`, `creditURL: URL?`, `doseG`, `waterG`, `tempC?`, `totalTimeS?`, `tuningNote?`, `includesIce: Bool`, `iceG: Double?`, `builtInKey: String?` | `method → BrewMethod` (nullify), `steps → [RecipeStep]` (cascade), `brews` (nullify) | `name` |
| `RecipeStep` | `order: Int`, `kind: StepKind` (bloom, pour, wait, stir, swirl, invert, press, plug, bypass, openValve, closeValve, drawdown), `startOffsetS: Int`, `targetCumulativeWaterG: Double?`, `instruction: String` | `recipe` (inverse) | — |
| `Grinder` | `name`, `notes?` | `brews` (nullify) | — |
| `Suggestion` | `source: SuggestionSource` (rules, ai), `field: BrewParameter`, `fromValue`, `toValue`, `rationale: String`, `state: SuggestionState` (proposed, accepted, edited, dismissed), `modelID: String?` | `sourceBrew → Brew` (inverse of `suggestionsMade`), `appliedTo → [Brew]` (nullify) | `state` |
| `AIRequest` | `feature: AIFeature`, `provider: AIProvider`, `modelID`, `status` (queued, sending, done, failed, cancelled), `payloadJSON: Data`, `attachment: Data?` (external), `resultJSON: Data?`, `errorMessage: String?`, `attempts: Int` | `brew → Brew` (nullify) | `status` |
| `TaxonomyAlias` | `dimension: TaxonomyDimension` (origin, process, roast, flavor, brewer), `rawValue: String` (normalized), `bucketKey: String` | — | `dimension, rawValue` |
| `WaterProfile` (COULD) | `name`, `ppmHardness?`, `ppmAlkalinity?`, `calcium?`, `magnesium?`, `sodium?` | `brews` (nullify) | — |

Derived, never stored: `ratio` (water ÷ dose, or yield ÷ dose for espresso),
`extractionYield` (TDS × beverage weight ÷ dose), `remainingG` (bag weight −
Σ grams in `BrewBean` + adjustment), `freshness` (resting / peak / past peak /
frozen, from roast date with frozen days excluded), `buckets` (from the
taxonomy service).

Bundled, read-only data (versioned JSON in the app bundle, original content
written for Next Cup, no third-party text):

- `taxonomy.json` — `version`, buckets per dimension, raw-value → bucket map,
  flavor families, roast bands.
- `methods.json` — built-in methods, including a switchable immersion dripper
  and an inverted press (X1).
- `recipes.json` — a small set of generic starter recipes.

Built-ins are seeded once by `builtInKey`; a newer bundle version adds new
keys and never overwrites user edits.

Schema versioning: `VersionedSchema` + `SchemaMigrationPlan` from v1, so
later changes are lightweight migrations.

## 3. API spec

There is no server. The "API" is the app's internal service layer (in
`NextCupKit` unless noted), its outbound calls, and its system entry points.

### 3a. Internal services

| Service / call | Does | Input → output | Errors |
| --- | --- | --- | --- |
| `Store.save(_:)` (app) | Saves a model context | context → `Result<Void, StoreError>` | Write failure surfaces a banner and keeps the draft (X5) |
| `DraftStore.save/load/clear` | Autosaves the open brew form outside SwiftData | `BrewDraft` (Codable) → file in Application Support | Corrupt draft is discarded with a notice, never crashes |
| `BrewMath.ratio / extractionYield` | Derivations | doses, TDS → `Double?` | Missing inputs → `nil`, never 0 |
| `RecipeScaler.scale(_:toDose:)` | Scales every step target | recipe, new dose → scaled recipe + rounding notes | Dose ≤ 0 rejected; ice counts toward water |
| `TimerEngine` | Runs steps against an injectable clock | steps, `Clock` → state stream (current, next, elapsed, paused) | Survives termination: persists start date and pauses |
| `Freshness.state(for:)` | Bean freshness | roast date, frozen spans, today → state | No roast date → `.unknown` |
| `BrewPrefill.again(bean:method:)` | Brew again (X2) | last brew of same bean + method → draft with timing reset | None found → blank draft for that method |
| `Taxonomy.buckets(for:)` | Raw values → buckets | bean/method fields + user aliases → bucket set | Unknown raw value → "Unmapped", offered for mapping |
| `Recommender.recommend(for:)` | Matrix recommendation | bean buckets + history → ranked method/recipe/start params + explanation facts | < 3 similar rated brews → bundled default by roast band, labelled as a default |
| `DialInRules.suggest(for:)` | Rule-based next change | verdict + parameters → one `SuggestionDraft` | `balanced` → "keep it", no change |
| `AIClient.send(_:)` | One AI call via a `Transport` protocol | `AIRequestPayload` → `AIResult` (JSON-schema validated) | No key → refused before any I/O; 401 → "key rejected"; 429/5xx → retry with backoff, max 3; invalid JSON → failed with message |
| `AIQueue` (app) | Sends queued `AIRequest`s | path monitor + queue → status updates | Offline → stays queued, visible, cancellable |
| `PaperImport.extract(image:)` | Image → draft recipe/brew | image → fields with per-field confidence | Low confidence highlighted; nothing saved until confirmed |
| `Exporter.export(format:)` | Full export | store → CSV bundle or JSON file | Write failure reported |
| `Importer.preview/apply` | Merge import (X5) | file → diff (new / changed / conflicts) → apply | Never overwrites silently; conflicts need a choice |
| `Backup.run/restore` | Automatic local backup | daily JSON in Application Support/Backups, keep 7 | Restore previews like an import |
| `KeychainStore` | AI keys | provider → key | Missing / access errors surfaced in Settings |

### 3b. Outbound network (the only ones)

| Call | When | Auth | Request | Response | Errors |
| --- | --- | --- | --- | --- | --- |
| `POST https://api.anthropic.com/v1/messages` | User taps an AI action with an Anthropic key | `x-api-key`, `anthropic-version` | system prompt, user text, optional image (JPEG, ≤1568 px, metadata stripped), JSON schema via tool definition | tool-use JSON | 401, 429, 529/5xx, timeout 60 s |
| `POST https://api.openai.com/v1/responses` | Same, with an OpenAI key | `Authorization: Bearer` | same content, `text.format` JSON schema | JSON output | 401, 429, 5xx, timeout 60 s |
| `GET /v1/models` (either provider) | User opens model picker | same key | — | model list for per-feature choice | Falls back to last cached list |
| `MKLocalSearch` (Apple) | User searches roasters | none | query "coffee roaster" + visible map region or typed city | map items | Denied location → typed city path |

No analytics, crash reporting, ads, fonts or remote config calls. The model
list is never hardcoded to a guess; the defaults are whatever the user picks.

### 3c. System entry points

| Entry | Target |
| --- | --- |
| `nextcup://brew/new`, `nextcup://brew/<id>`, `nextcup://recipe/<id>`, `nextcup://bean/<id>` | Deep links (Live Activity tap opens the running timer) |
| App Intents (SHOULD): "Log a brew", "Brew again", "Start recipe" | Shortcuts and Siri |
| Live Activity | Current step, next step, elapsed time via `Text(timerInterval:)`; ends with the brew |

## 4. Folder structure

```
next-cup/
├── NextCup.xcodeproj
├── NextCup/                      # app target (synchronized folder)
│   ├── App/                      # NextCupApp, RootTabView, deep links, model container
│   ├── Features/
│   │   ├── Journal/              # S01 list, S02 form, brew detail
│   │   ├── Recipes/              # S06 library, S07 detail, S08 editor
│   │   ├── Timer/                # S05 guided timer
│   │   ├── Beans/                # S03 library, S04 detail, best-so-far card
│   │   ├── Methods/              # S09 method setup
│   │   ├── Explore/              # recommendations, flavor explorer, insights
│   │   ├── DialIn/               # suggestion cards, AI disclosure
│   │   ├── Import/               # paper import review
│   │   ├── Discovery/            # S10 roaster map
│   │   └── Settings/             # units, AI keys + models, data, privacy, about
│   ├── Persistence/              # @Model types, schema versions, Store, seeding
│   ├── DesignSystem/             # tokens + components (Phase 3C fills this)
│   └── Resources/                # taxonomy.json, methods.json, recipes.json, Assets, Localizable.xcstrings
├── NextCupLiveActivity/          # widget extension
├── Packages/NextCupKit/
│   ├── Sources/NextCupKit/       # Domain/, Taxonomy/, Recommender/, DialIn/, AI/, ImportExport/
│   └── Tests/NextCupKitTests/
├── NextCupUITests/
├── design/concepts/              # Phase 3B concept previews
├── replica/  docs/  ralph/
└── prd.md  PROMPT.md  activity.md  CLAUDE.md  PRODUCT.md
```

`NextCupKit` imports only Foundation (plus CoreGraphics/ImageIO for image
prep). SwiftData models live in the app target; the package works on plain
value types so it stays testable without a store.

## 5. State management

| State | Owner | Lives in |
| --- | --- | --- |
| Brews, beans, roasters, methods, recipes, suggestions, AI queue, aliases | Device (no server exists) | SwiftData store |
| Open brew form | Client, autosaved | `DraftStore` JSON file; restored on relaunch |
| Running timer | Client | `TimerEngine` (@Observable), persisted start/pauses in `UserDefaults`; mirrored to the Live Activity |
| Units, appearance, last-used method/grinder, list sort and filter choices, AI disclosure version accepted, per-feature model IDs | Client preferences | `@AppStorage` |
| AI keys | Client secret | Keychain, this device only |
| Taxonomy, built-in methods and recipes | Bundle (read-only) | JSON in app bundle; user aliases in SwiftData |
| Navigation and selected tab | Client | `@SceneStorage` (restores after relaunch) |
| Model list cache | Client | `UserDefaults` |

No state is server-owned. The AI providers hold whatever their own terms say
about requests the user sends; that is disclosed, not controlled.

## 6. Vendors and data flows

| Vendor / framework | Purpose | Data it receives | When | Recorded in |
| --- | --- | --- | --- | --- |
| Apple SwiftData, Vision, ImageIO, ActivityKit | Storage, OCR, image prep, Live Activity | Everything stays on device | Always | `docs/data-inventory.md` |
| Apple MapKit | Roaster search | Search text and map region or typed city (Apple's terms) | Only on a search tap | data inventory |
| Anthropic | AI features | Prompt text built from the chosen brew, notes and history slice, optional photo (metadata stripped) | Only with the user's key, after disclosure, on a tap | data inventory |
| OpenAI | AI features | Same as above | Same | data inventory |
| Apple iCloud device backup | System backup of the app container | SwiftData store and local backups (not Keychain keys) | Per user's iOS settings | data inventory |

Decisions on Phase 2 candidate flows: Bluetooth scales **deferred** (owner);
Apple Health caffeine **not adopted**; café check-ins **not adopted** (only
saved roasters); CSV/JSON export and merge import **adopted**; water profiles
**COULD**; Live Activity **adopted**; import from another journal app's
export **COULD** (generic CSV mapping covers the common case).

Permissions requested, each in context, never at launch: camera (bag photo,
brew photo, paper import), location when in use (roaster search). Photo
picking uses `PhotosPicker`, which needs no library permission. No
notifications in v1.

## 7. The parts that bite

- **Time zones**: brew `date` stored in UTC, shown in the device's zone;
  freshness counts calendar days in the device zone.
- **Timer in background**: haptics stop when backgrounded; the Live Activity
  carries the step change. State survives termination via persisted start
  date and pause spans, never a ticking counter.
- **Idempotent saves**: Save is disabled while saving; the draft is cleared
  only after a confirmed write.
- **Import merges**: match by `id`; same `id` with different content is a
  conflict the user resolves; built-ins match by `builtInKey`.
- **CloudKit later**: the constraints in §2 are mandatory now, or sync becomes
  a migration.
- **AI**: structured output is validated before display; a failed or odd
  response never becomes a suggestion. Rate limits get backoff, max 3 tries.
- **Photo privacy**: strip location and EXIF before storing or sending.
- **Search**: `#Predicate` with `localizedStandardContains` over notes, bean,
  roaster and method; fine at journal scale (thousands of rows).
- **Deletion**: delete-all wipes the store, drafts, backups, aliases, cached
  model list and Keychain keys, then reseeds built-ins.

## 8. Permission changes for the build loop (Phase 4)

Not applied yet. On approval of Phase 4, `.claude/settings.local.json` in this
repo would allow: `xcodebuild`, `xcrun simctl`, `swift test`, `swift build`,
`swift format`, `git add/commit/switch/worktree` in this repo. Not allowed:
`git push`, `gh pr merge`, network installs, anything outside the repo.
Ralph's fresh-context runner is still to be cloned and reviewed (B002).
