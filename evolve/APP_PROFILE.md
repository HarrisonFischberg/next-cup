# Next Cup app profile (main 81b34cc, version 1.1, 2026-11-06)

Native SwiftUI iPhone app with SwiftData on the device. There is no backend and no account. AI runs
on Apple's on-device model, or on the user's own Anthropic or OpenAI key (kept in the Keychain).
Sources: the code under `NextCup/`, plus a run on an iPhone 18 Pro simulator (iOS 27) with demo data
(shots in `evolve/cycles/001/shots/`).

## Fixture / demo data mode

There is one. It is **DEBUG builds only** and works **only together with `-inMemoryStore`**
(`AppBootstrap.start`, `DemoBrews`):

| Launch argument | Effect |
|---|---|
| `-inMemoryStore` | Fresh throwaway store; real data is never touched; onboarding skipped, audio silent, taste reminders off |
| `-demoBrews` | 5 brews (Geometry, Kenya Rukira, Monarch, Geometry, Southern Weather; 0–4 days ago, ratings 6.8–8.8, verdicts) on the first method, plus a dark "Southern Weather" bag in use |
| `-demoBeans` | 4 bags with roasters, origins, roast dates, weights and ratings (Counter Culture 46, Hair Bender, Kenya Rukira, Monarch) |
| `-fakeNextCupAI` (with `-demoBrews`) | Adds a Baratza Encore grinder at setting 18 to every demo brew, and fakes the Next Cup AI answer |
| `-demoOnlyMethod <key>` | Hides every method except one |
| `-perfBrews N` | N brews over 30 beans (performance runs) |
| `-showOnboarding` | Forces the first-run flow |
| `-resetNavigationState`, `-resetDraft` | Start from a known tab and no draft |
| `-appStyle <case>`, `-appearanceMode light\|dark`, `-selectedTab recipes\|journal\|beans\|explore` | Pin the look, appearance and tab (UserDefaults argument domain) |
| `-deepLink nextcup://…` | Opens a link at launch (DEBUG). `nextcup://settings` didn't open Settings this way in my run; tapping the gear did |
| `-timerSpeed`, `-brewMusic`, `-tasteReminders`, `-roasterStub`, `-locationStub`, `-failBrewSave`, `-brewingPreview`, `-locked` | Test hooks for the timer, audio, notifications, MapKit, failure paths |
| `-evolve_all YES` | New: turns every Experiments flag on (Debug/TestFlight only) |

The baseline shots used `-inMemoryStore -demoBrews -demoBeans -resetNavigationState -resetDraft
-selectedTab <tab> -appearanceMode <mode>`. UI tests run through `scripts/run-ui-tests.sh` (batches,
`-appStyle steelKraft`).

## Shell and navigation

- There are 4 tabs (`AppTab`, persisted in `selectedTab`): **Brew** (raw value `recipes`),
  **Journal** (default), **Beans**, **Explore**. Each has its own NavigationStack (`AppRouter`).
- Settings is pushed from a gear on every tab (`SettingsGear`), or opened with `nextcup://settings`.
- Deep links (`nextcup://`): `brew/new`, `brew/<id>`, `brew-again/<id>`, `recipe/<id>`,
  `method/<id>`, `bean/<id>`, `timer?…`, `settings`, `taste/<id>`, `unsaved/<…>`.
- App Shortcuts / Siri: Log a brew, Brew again, Start recipe.
- Live Activity and Dynamic Island for a running brew timer (`NextCupLiveActivity`).
- A startup failure screen ("Can't open your journal", with Try again) appears if the store
  can't open.

## Onboarding (first run only; `onboarding.done`)

`OnboardingView` replaces the tabs on a fresh install with no brews. It has 4 steps, each skippable,
with Back on steps 2–4:
1. "What do you brew with?": pick methods, plus a grinder (named list or Other…).
2. "Your units": prefilled from the region.
3. Apple Intelligence: the "Bean me up, Scotty" switch (`BeanDetailsAI.enabledKey`).
4. Beans: scan or photo a bag first, then a list of popular coffees (more than 100: retail
   flagships plus the bundled catalog, Starbucks last), plus a Your Style card.

The finish screen says "You're set". "Start brewing" opens the Brew tab, or the method's styles
when only one method was picked. After onboarding, the Journal shows a **Getting started** card
("2 of 4 set up": Brew methods ready, Units set, Add your first bag, Log your first brew; Log a brew,
Import a journal page; can be dismissed).

## Screens and features

**Brew tab (S06, `RecipeLibraryView`)**
- PageHeader with the gear and a round + (new recipe, or Create with AI) and Search recipes.
- "Explore by method": brewer drawings with a style count each on the colour block, plus All
  methods and More methods (the ones hidden in onboarding).
- "Your recipes" as photo-hero cards, grouped by style (Pour over…).
- Method → `MethodStylesView`: numbered style cards (`style.N`). The Nespresso joke method opens
  `NespressoJokeView` instead.
- Recipe setup (S07, `RecipeDetailView`): a brewer hero, bean picker, grinder and grind
  (`GrindWheel`, grind recalled per bean, `GrinderGuide` with 21 grinders), editable dose,
  "How much coffee?" yield wheels (`BrewYield`) with BrewSizeAI tuning, the numbers calculated
  from them, a step preview, and Start brew.
- Recipe editor (`RecipeEditorView`): edit your own recipes and versions, delete your own.
  "Improve with AI" (`RecipeReviewAI`, review sheet) and "Create with AI"
  (`RecipeCreateAIView`: brewer + grinder + a prompt → a whole recipe; a cup fills while it works).
- Active brew timer (S05, `TimerView`, full screen):
  - Music bar, step segments, a `StepRing` counting down to the next step, a plain-command
    `StepCue` per method ("Close the valve, then pour to 270 g", a Valve open/closed badge,
    hands-on seconds).
  - An animated brewer scene, Pause, a next card pinned above it, and a chime and haptic 5 s before
    each step.
  - The timer runs past the target (overtime). Finish brew → "Taste and log".
  - Audio (`BrewAudio`): tick-tock, chime, 5 public-domain tracks at 34% volume.

**Journal tab (S01, `JournalListView`)**
- Gear and + in the toolbar, Search brews, and Filter · order (method, bean, newest first;
  remembered).
- A Today card / daily loop strip (Brew · Rest · Taste · Next), then "Past Brews" cards: bean,
  date · method, rating /10, dose : water, ratio, time, verdict chips.
- Swipe to delete with an Undo toast. Long press → "Ask AI for Next Cup" (`NextCupAIView`).
- Brew form (S02, `BrewFormView`): blank or prefilled from the timer. Dose, water, yield, grind,
  temperature, time, a 0–10 rating in tenths, multi-taste verdicts (sour, bitter, weak, strong,
  balanced…), notes, photo, a dial-in suggestion card (Accept / Edit / Dismiss), and "New bean…".
  The draft autosaves. Saving returns to the Journal.
- Taste reminder: a local notification 20 min after an untasted save. Permission is asked then.
  `nextcup://taste/<id>` opens `TasteView`.
- Next Cup auto (`NextCupAuto`): after a tasted or rated save, the AI writes tomorrow's recipe to
  the method's Next Cup.
- Paper journal import (`PaperImportView`): photo of a page → Vision OCR on the device (or the AI
  key) → check every field → save.

**Beans tab (S03, `BeanLibraryView`)**
- Search, status filter (All, In use, Buy again, Wishlist, Finished) and sort (remembered).
- Bean detail: remaining grams, freezer dates, a Best-so-far card, every brew that used it, and
  Brew this bean.
- Bean editor: name, roaster, origin, region, farm, process, varietal, roast level and date, bag
  flavour notes, weight, decaf, frozen/thawed, rating, photo.
- Capture: camera, photo, barcode (Open Food Facts), QR link read, bag photo AI
  (`BagRecognition`), then a roaster match on MapKit (`RoasterMatchView`). `BeanDetailsAI` fills
  blank origin, process, roast and notes on the device.

**Explore tab (`ExploreView`)**
- "For your Next Cup": for each bean in use, ranked method and recipe suggestions with dose,
  water, temperature and time, plus why ("DEFAULT · 0 of 3 rated similar brews"). Tapping one opens
  Start brew.
- AI insights (`AIAskView` shows exactly what would be sent before anything goes).
- Flavor explorer (taxonomy buckets → words → beans).
- Roaster catalog (bundled `catalog.json`: roasters → coffees → starting recipes).
- Find roasters near me (S10, MapKit search by city or location; only the ones you save are kept).

**Settings (`SettingsRootView`)**
- Appearance: System/Light/Dark and look tiles (`FlavorPicker`, 6 looks).
- Units: g/oz and °C/°F.
- Brewing: Brew methods (S09: add, rename, reorder, hide, fields per method), Brew sounds,
  Ticking timer, Music while brewing.
- AI: a card per provider (Apple on-device, Anthropic, OpenAI). The key is checked by listing
  models, then a model picker and a disclosure before the first call.
- Your data: export, import, daily backups, delete all.
- Privacy summary with links to the policy and support. About shows the version.
- **Experiments** (new, hidden): long-press the Version row (Debug and TestFlight only) → one
  switch per flag, Turn all on, Reset.

## Data model (SwiftData, `NextCup/Persistence/Models.swift`)

- **Brew**: date, doseG, waterG, yieldG, grindSetting/Value, tempC, totalTimeS, tds, ratingTenths
  (0–100), verdict and alsoTasted, notes, photo, targetsJSON, isDraft. Links to method, recipe,
  grinder, waterProfile, beans (BrewBean), suggestionFollowed.
- **BrewBean**: grams plus a bean name snapshot, linking a Brew to a Bean (blends).
- **Bean**: name, origin, region, farm, process, varietal, roastLevel, roastDate, bagFlavorNotes,
  bag weight and remaining adjustment, status, decaf, frozenOn/thawedOn, ratingTenths, photo,
  aiSuggestion, roaster.
- **Roaster**: name, city, website, lat/long, savedFromMap.
- **BrewMethod**: name, style, symbol, trackedParameters, defaultStepKinds, sortOrder, isHidden,
  builtInKey. 13 built in: cone, flat-bed, switchable, press, inverted press, espresso, iced pour
  over, cold brew, moka pot, AeroPress, Chemex, drip machine, nespresso (joke).
- **Recipe**: name, credit and URL, dose, water, temp, time, tuning note, ice, grind and grinder
  name, method, steps. 48 built in.
- **RecipeStep**: order, kind (pour, bloom, swirl, heat, …), start offset, target cumulative
  water, instruction.
- **Grinder**, **Suggestion** (dial-in proposal: field from→to, rationale, state, source rules or
  AI), **AIRequest** (offline queue: feature, provider, model, status, payload, attachment,
  result), **TaxonomyAlias** (raw value → bucket per dimension), **WaterProfile** (hardness,
  alkalinity, minerals).
- `NextCupKit` package: taxonomy, recommender, dial-in rules, rating text, GrinderGuide.

## AI features

All of them are proposals that need a tap. Apple's on-device model is used when no key is set; a
key sends straight to the provider after its disclosure.

- Bag photo → bean fields (BagRecognition).
- On-device bean details (BeanDetailsAI).
- Ask AI for Next Cup (overview plus an improved recipe), and Next Cup auto after saving.
- Improve with AI / Create with AI for recipes.
- How much coffee? tuning (BrewSizeAI).
- Explore insights (AIAskModel).
- AI dial-in suggestions merged into rule cards (AISuggestions).
- Paper-page reading with a key.
- An offline queue that expires stale requests (AIQueue).

## What I could not exercise in this run

- AI with a real key (no key used). Apple Intelligence on the simulator (availability unknown).
- Camera, barcode and QR capture (the simulator has no camera).
- MapKit roaster search and location.
- The Live Activity, Siri/Shortcuts and taste-reminder notifications. A notification permission
  prompt did show once on a later launch; I dismissed it with Don't Allow.
- Music playback (silent under `-inMemoryStore`), and export/import files.
- Onboarding was not stepped through, and no brew was logged or timed. Their descriptions come from
  the code.
- I only captured the five main screens in Sunday Studio light and dark, plus the Experiments
  screen. I captured no other looks.
