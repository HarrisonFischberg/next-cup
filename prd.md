# next-cup — PRD

Status: DRAFT, not yet approved. Created 2026-10-21.

## Purpose

Native iPhone coffee brew journal with AI dial-in, bean taxonomy, recipe matrix, and paper-journal import. App name: **Next Cup**. Audience: coffee aficionados who brew precisely every day and want to dial in and improve the next cup. Success in 30 days: a portfolio piece, distributed by TestFlight and a public GitHub repo. Free, no ads, no accounts, local-first.

## Decisions from intake

- Platform: iPhone only, native SwiftUI, SwiftData on device. Light and dark, both fully supported.
- AI: bring-your-own OpenAI or Anthropic key held in the Keychain, per-feature model selection, calls direct from the device, no backend (ASSUMED). No AI call until a key is added; disclosure before the first call.
- Offline: logging, notes, photos, recipes, and history work offline. AI requests queue with visible status. Imported recipes are cached.
- Out of scope: accounts, social features, sharing feeds.
- Approval stops: reference comparison, blueprint, design pick, repo creation.
- Design concepts to build in Phase 3B: Charcoal & Crema, Quiet Ceramic, Terracotta Hand-Thrown, Steel & Kraft, Late-Night Café.
- Brand: none yet. Domain rarecreatures.app and a paid Apple developer account exist.

## Product features

(priority is a draft for the blueprint; Opus ranks them in Phase 3)

1. Brew journal: log each brew (method, dose, water, temperature, grind, timing, notes, photos, grade) with a timer-driven brew flow. MUST
2. Taxonomy and shared in-app database: categorize brew method, beans, roaster, origin, process; map to generic buckets (for example Kenyan, light roast, stone fruit). One bundled reference dataset used by every feature. MUST
3. Recipe library: organized and searchable notes, user-written recipes, a grading scale, creator recipes imported as parameters with credit and links. MUST
4. Recommendation matrix: link beans, roasts, methods, and recipes; recommend methods and recipes from similar roasts and bean characteristics, computed on device. MUST
5. AI dial-in: diagnose a brew and suggest changes for the next cup; the user taps to accept. MUST
6. Photo interpretation: AI reads a coffee photo (for example crema, extraction). SHOULD
7. Bag recognition: photograph a bag, identify the roaster and beans, and link them into the recipe. SHOULD
8. Insights: AI reads notes and past brews and offers patterns. SHOULD
9. Paper-journal import: photo or screenshot of handwritten recipes or journal pages becomes a structured recipe, shown on a review screen, then filed automatically. SHOULD
10. Local roaster discovery: search and browse nearby roasters (MapKit), save favorites, link to beans. SHOULD
11. In-app assistant: explains the app and troubleshoots. COULD
12. Bluetooth scale and machine integration: candidate, ranked in the blueprint. COULD
13. Optional iCloud sync (later). COULD

## REA and Replica findings

See `docs/rea-findings.md` and `replica/`.

## Atomic tasks

Filled after the blueprint is approved (Phase 3).

| ID | Task | Depends on | Acceptance criteria | Verification command | Status |
| --- | --- | --- | --- | --- | --- |
| T001 | | | | | pending |

## Safeguard coverage

Every applicable item in `docs/compliance-checklist.md` has a task here or a
recorded reason it does not.

## Human review and launch blockers

See `docs/launch-blockers.md`.
