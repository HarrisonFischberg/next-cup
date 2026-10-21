# Architecture: Next Cup (a rebuild of the reference set's core brew-journal features)

Full spec: `docs/blueprint.md`. This file is the Replica architect summary.

## Stack

| layer | choice | why |
| --- | --- | --- |
| app | SwiftUI, Swift 6.4, iOS 27, iPhone only | Intake; testable on the installed runtime |
| database | SwiftData on device, CloudKit-compatible schema | Local-first, no accounts; iCloud sync later without migration |
| auth | none | No accounts by intake |
| payments | none | Free; paywall S18 not built |
| email | none | No accounts, no marketing |
| jobs | `AIQueue` (on reconnect), daily local backup on launch | No server |
| hosting | none; TestFlight distribution | Portfolio app |

## Schema

Models: 12 (`Brew`, `BrewBean`, `Bean`, `Roaster`, `BrewMethod`, `Recipe`,
`RecipeStep`, `Grinder`, `Suggestion`, `AIRequest`, `TaxonomyAlias`,
`WaterProfile`). Access rules: single-user sandbox, data-layer uniqueness by
`id`. Definitions in `docs/blueprint.md` §2 (SwiftData, not SQL).

## API

No server routes. Internal services by flow:

| flow | services |
| --- | --- |
| F01 guided brew + log | `RecipeScaler`, `TimerEngine`, `DraftStore`, `Store.save` |
| F02 quick log | `BrewPrefill`, `DraftStore`, `Store.save` |
| F03 add bean | `Taxonomy.buckets`, `AIClient` (bag recognition, optional) |
| F04 dial in from history | `Recommender`, `DialInRules`, `AIClient` |
| F05 espresso dial-in | `DialInRules` (actual yield and time always recorded) |
| F06 scale + customize | `RecipeScaler` |
| F07 find a roaster | `MKLocalSearch` (no check-ins) |
| F08 export | `Exporter`, `Importer`, `Backup` |

Webhooks in/out: none. Outbound: Anthropic Messages, OpenAI Responses, model
lists, MapKit search, all user-initiated.

## The parts that bite

- time zones: UTC storage, device-zone display, freshness in calendar days
- idempotency: single in-flight save; import merges by `id`
- races: timer state from persisted timestamps; AI queue serialized on an actor
- offline: everything but AI and map search works; AI queues visibly
- deletion: delete-all covers store, drafts, backups, Keychain

## Build order

1. Vertical slice: S06 → S07 → S05 → S02 → S01 with `BrewMethod`, `Recipe`,
   `RecipeStep`, `Brew` and built-in seed data.
2. Must-haves: full journal (X2, X5, X8), beans (S03, S04), methods (S09, X1),
   taxonomy + matrix, rule-based dial-in (X4), export/import/backup.
3. Should-haves: AI features (diagnosis, photo, bag, insights), paper import,
   roaster discovery, Live Activity, best-so-far card (X3), freeze/decaf/blends (X6).
4. Could-haves: water profiles, TDS chart, App Intents, iCloud sync.
