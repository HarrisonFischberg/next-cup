# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Native SwiftUI, SwiftData on device. No backend: AI calls go direct from the device using the user's own OpenAI or Anthropic key held in the Keychain. Chosen by the owner at intake (2026-10-21). iPhone only; iPad, Android, and web are out of scope.

## Users

Coffee aficionados who brew precisely every day and keep a journal. They are at the brew station with a scale, a kettle, and wet hands, logging dose, water, temperature, grind, timing, and a taste verdict, then trying to dial in the next cup. Some also keep recipes and journals on paper.

## Product Purpose

Next Cup is a daily brew journal that helps a person dial in coffee and make tomorrow's cup better. It logs each brew with notes, grades, and photos; sorts beans, roasters, origins, processes, and brew methods into generic buckets (for example Kenyan, light roast, stone fruit); ties those into a recipe matrix that recommends methods and recipes for similar beans; and uses AI for photo interpretation, bag recognition, brew diagnosis, and next-day suggestions. Success in 30 days is a polished portfolio piece distributed by TestFlight and a GitHub repo, not a business with paying users.

## Positioning

A journal that turns past brews into the next recipe. Its mechanism is the shared taxonomy and recipe matrix: the same bean and roast buckets drive logging, search, recommendations, and AI context, and it ingests paper recipes through photo import. The owner stated this mechanism. No comparative claim against other apps has been verified.

## Operating Context

- Used one-handed or with wet hands at the brew station, daily, often early in the morning; logging has to be fast.
- Works offline for logging, notes, photos, recipes, and history. AI features need a connection and queue requests with visible status when offline.
- Photos are of coffee, bags, and handwritten recipe pages. Paper import shows a review screen before saving.
- AI runs only after the user adds a key, with a plain disclosure before the first call and per-feature model selection.
- Creator recipes (for example from popular coffee YouTubers) are imported as parameters, restated in original wording, with credit and a link back.
- Local roaster discovery uses Apple MapKit search, on demand and while the app is in use.

## Capabilities and Constraints

- Free, no ads, no accounts, no analytics or ad SDKs, no social features, sharing feeds, or user-to-user sharing.
- Local-first storage; optional iCloud sync is a later add-on.
- AI suggestions are proposals the user accepts with a tap; the app never acts on its own.
- "Shared database" means one shared in-app taxonomy and a curated bundled reference dataset, not a server shared between users (assumption, recorded in `docs/launch-blockers.md`).
- Open decisions: Bluetooth scale and machine integration, the in-app assistant scope, creator source list, brand name treatment beyond "Next Cup".

## Brand Commitments

Name: Next Cup. Domain owned: rarecreatures.app. No logo, brand colors, or fonts exist yet.

The owner supplied five style prompts to be explored as separate concepts in the design phase; they are a menu of directions to build, not a decision: charcoal and crema; quiet Japanese minimalism with walnut, ceramic, and warm ivory; terracotta and handmade pottery; industrial steel and kraft; late-night café with amber and brass. Light and dark appearance are both required. Their ambition: "as awesome as possible".

## Evidence on Hand

None: no testimonials, user research, benchmarks, or analytics. Three reference products were named (a coffee-logging app, a brew-timer app, and a brew-data website); they have not yet been analyzed. Do not fabricate evidence about them or about users.

## Product Principles

1. Logging at the brew station must be faster than writing on paper.
2. The taxonomy is the spine: every feature reads from and writes to the same buckets.
3. AI proposes, the user decides, and nothing is sent anywhere without the user's key and tap.
4. Local and private by default; the app works fully without a connection or account.
5. Credit creators and sources; never copy their wording.

## Accessibility & Inclusion

Dynamic Type, VoiceOver labels, 44 pt targets, Reduce Motion, and increased contrast respected; Dark Mode first-class. Every gesture has a visible non-gesture alternative.
