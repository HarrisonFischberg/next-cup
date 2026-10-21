# Recon map: Next Cup reference set (iOS)

Scope: the daily brew-journal loop — log a brew, follow or adapt a recipe,
track beans, review what worked — plus the supporting tools around it.
For: Next Cup, a free portfolio iPhone app (owner's own project).
Date: 2026-10-21
Status: FINAL spec (2026-10-21). The owner approved the best-of comparison
as written (Bluetooth scales deferred). Review research is folded in below
as fixes X1–X8. Positioning default: angle A (below).

Sources are labelled A, B, C. The key to the real sources was kept only in the temporary lab folder and is erased with it.

## Sources

| # | source | kind | notes |
| --- | --- | --- | --- |
| 1 | Source A marketing home | marketing site + app screenshots | Feature list, one phone screenshot (coffee library), tab bar visible |
| 2 | Source A recipe index | public recipe pages | 24 recipes grouped Pour over / Immersion / Espresso; each card: brewer, ratio, dose · water, temp, total time |
| 3 | Source A recipe detail | public recipe page | Step timeline (pour / wait), cumulative water targets, scale control, tuning note |
| 4 | Source B store listing | App Store | Long feature description, privacy label, version, iOS minimum, rating |
| 5 | Source C store listing | App Store | Feature and paid-tier lists, supported scales, privacy label, declared accessibility features, two visible reviews, release notes |

Not available without going further: in-app screens of B and C (store
screenshot carousel not captured as text), any help-center docs, and any
logged-in state. Gap noted for the comparison stop.

## Core loop

Brew a cup against a recipe (timer guides the pours), log what actually
happened with a taste verdict, and use the history to change one variable
next time.

## Screens (inferred; IDs are stable)

| ID | screen | how to reach | purpose | key components | states seen / to design |
| --- | --- | --- | --- | --- | --- |
| S01 | Brew log list | Tab 1 | Dated, searchable history of brews | Row: method, ratio, grind, time, rating; search; add button | filled (A screenshot alt text); empty, search-no-results not seen |
| S02 | New / edit brew | + on S01, or end of S05 | Record dose, water, grind, temp, time, notes, rating, photo | Number steppers, grind field, star/score control, notes, photo | filled; validation and draft not seen |
| S03 | Coffee (bean) library | Tab "Coffees" | Beans by roaster with rating and roast level | Segmented filter (All / Buy again / Wishlist), row with roaster, rating, roast chip, + | filled (A screenshot) |
| S04 | Bean detail | Row on S03 | Origin, process, varietal, roast date, remaining amount, rest/peak status, linked brews | Attribute list, freshness indicator, stock remaining | inferred from A and B text |
| S05 | Guided brew timer | Recipe → "Brew this" | Step-by-step pours with haptic cues; logs result at the end | Big timer, current step, target weight, step timeline, live scale weight if paired | inferred (A, C) |
| S06 | Recipe library | Tab / More | Recipes grouped by brew style | Recipe card: brewer, ratio, dose·water, temp, time; section headers | filled (A recipe index) |
| S07 | Recipe detail | Card on S06 | Steps with times and cumulative targets, scale-to-dose | Timeline bar, step list (pour / wait / drawdown), scale control, start button | filled (A recipe detail) |
| S08 | Recipe editor | + on S06 | Write or customize a recipe; choose which parameters a method tracks | Step editor, parameter toggles | inferred (B "customize methods", C "share your recipe") |
| S09 | Brew-method setup | Settings / More | Enable methods and pick tracked parameters per method | Method list, parameter checklist | inferred (B) |
| S10 | Check-in / roaster map | Tab "Check-ins" | Map of café visits and nearby roasters | Map, pins, check-in list | inferred (A alt text) |
| S11 | Stats | More / Check-ins | Streak, badges, averages, top spots | Stat tiles, badge grid | inferred (A alt text) |
| S12 | Extraction calculator | Brew detail / tools | TDS reading → extraction yield vs a target window, scatter of best cups | Input, result vs band, chart | inferred (A, C paid) |
| S13 | Tools: ratio scaler, freshness, process guide, tasting-notes explorer | More / web | Utility calculators and reference | Inputs, results, flavor wheel | seen as web tools (A) |
| S14 | Water profiles | More | Saved water recipes (hardness, minerals) used in brews | Mineral fields list | inferred (B) |
| S15 | Green beans and roast batches | More | Home-roast tracking feeding the bean library | Batch list, roast variables | inferred (B) |
| S16 | Scale pairing | Settings | Pair a Bluetooth scale; live weight and flow | Device list, connection state | inferred (A, B, C) |
| S17 | Export / import | Settings | CSV/JSON export with curves; import from another app | Format picker, share sheet | inferred (A) |
| S18 | Paywall | Locked feature | Upgrade to paid tier | Feature list, purchase buttons | inferred (C) — not to be built (Next Cup is free) |
| S19 | Espresso dial-in | Espresso recipe | Pull a shot, taste-rate, get which variable to change | Taste rating, suggestion card | inferred (C); review says output must be set up front |

## Flows

```
F01 Brew with a guided recipe and log it
    S06 -> S07 -> S05 (timer) -> S02 (prefilled result) -> S01
    happy path clicks (estimated): 5 (pick, start, finish, rate, save)
    edge: pause/abandon mid-brew, app backgrounded during timer, scale disconnects,
          actual weight differs from target, user wants to edit after saving

F02 Quick log without a recipe
    S01 -> S02 -> save
    happy path clicks (estimated): 3 + fields
    edge: unknown bean (add inline), missing grind setting, wet-hands one-handed entry

F03 Add a new bag of beans
    S03 -> + -> enter or scan bag -> S04
    edge: roaster not in list, duplicate bag, no roast date, bag runs out (stock reaches 0)

F04 Dial in from history
    S04 (bean) -> linked brews -> compare ratings -> S02 with one variable changed
    edge: too few brews to compare, mixed methods

F05 Espresso dial-in
    S19 -> pull shot -> record actual yield/time -> taste rate -> suggestion
    edge: reviewer complaint — target yield fixed before the shot, cannot record what happened

F06 Scale and customize a recipe
    S07 -> scale to dose -> S08 save as own
    edge: rounding of pour targets, iced recipes (ice counts as water)

F07 Find a roaster nearby / log a café visit
    S10 -> search or check in
    edge: location denied, offline

F08 Export data
    S17 -> choose CSV/JSON -> share sheet
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Tab bar | 4 tabs (log, map/check-ins, beans, more) | selected, badge | all |
| Segmented filter | 2–3 segments | selected | S03 |
| Recipe card | compact, featured | default, pressed | S06, home |
| Parameter readout | ratio, dose·water, temp, time | — | S01, S06, S07 |
| Step timeline | pour, wait, drawdown, bloom | upcoming, active, done | S05, S07 |
| Big timer | running, paused, done | — | S05 |
| Rating control | stars (half steps seen: 4.5) | empty, set | S01–S04 |
| Roast-level chip | light, medium, dark | — | S03, S04 |
| Freshness indicator | resting, peak, past peak | — | S04 |
| Live weight / flow graph | live, saved curve | connected, disconnected | S05, S16 |
| Stat tile, badge | — | locked, earned | S11 |
| Map pin + list | café, roaster | — | S10 |
| Number stepper / field | grams, °C, seconds | focus, invalid | S02, S08 |

## Inferred data model

```
Brew        id, date, method_id, recipe_id?, bean_id?, dose_g, water_g (or yield_g for espresso),
            ratio (derived), grind_setting, water_temp_c, total_time_s, tds?, extraction_yield? (derived),
            rating, tasting_notes, photo?, weight_curve? (time series), water_profile_id?
            evidence: A feature list + recipe cards, B description, C paid features
            confidence: high

Bean        id, name, roaster_id, origin_country, region?, farm/station?, process, varietal?,
            roast_level, roast_date, tasting_notes_on_bag, rating, bag_weight_g, remaining_g,
            status (all | buy again | wishlist), freshness_state (derived from roast_date)
            evidence: A screenshot + "coffee of the week" fields; B "running total of beans"
            confidence: high (remaining_g: B only; status: A only)

Roaster     id, name, location?, website?
            evidence: A library rows, A check-in map; confidence: medium

Method      id, name (V60, Chemex, AeroPress, espresso, French press, cold brew, ...), style
            (pour over | immersion | espresso | cold), tracked_parameters[]
            evidence: A recipe grouping; B customizable parameters; C method list
            confidence: high

Recipe      id, name, author/credit, method_id, dose_g, water_g, ratio, temp_c, total_time,
            steps[], tuning_note?, source_link?
            evidence: A recipe index + detail; confidence: high
RecipeStep  order, kind (bloom | pour | wait | drawdown | stir), start_offset_s,
            target_cumulative_water_g, instruction
            evidence: A recipe detail timeline; confidence: high

WaterProfile id, name, hardness, sodium, calcium, magnesium, ...   evidence: B; confidence: medium
GreenBean / RoastBatch                                            evidence: B; confidence: medium (skip candidate)
CheckIn     id, place, date, rating                               evidence: A; confidence: medium
Device      scale pairing info                                    evidence: A, B, C; confidence: medium
```

Relationships: Roaster 1-n Bean; Bean 1-n Brew; Method 1-n Recipe; Recipe 1-n
RecipeStep; Recipe 0-n Brew; WaterProfile 0-n Brew.

Gaps every source shares (Next Cup's own spine from intake): no source shows
generic buckets (origin region, roast band, flavor family) used to recommend a
method or recipe for a new bean. Source A's tasting-notes explorer links
notes to origins and processes, which is the closest thing.

## Review-driven fixes (from public user feedback, restated neutrally)

- X1 Steps beyond pour and wait: bloom, stir, swirl, invert, press, plug,
  bypass, open/close valve. Built-in presets for a switchable immersion
  dripper and an inverted press. Users can add their own methods.
- X2 Brew again: prefill from the last brew of the same bean and method,
  reset timer values, and allow editing actual results at any time.
- X3 A bean's page shows its best brew so far: rating spread, the best
  brew's settings, and grind history per grinder and dose.
- X4 Every suggestion is stored with the brew it came from and shown again
  on the next brew and in history.
- X5 Honest saves: a failed save is reported and the draft is kept. Import
  merges and never overwrites. Automatic on-device backup plus export.
- X6 Beans: freeze and thaw dates, a decaf flag (no caffeine counted), and
  blends as a brew that uses several beans.
- X7 Layout: Dynamic Type everywhere, large timer digits, the keyboard never
  covers Save, and the Live Activity stays out of other apps' space.
- X8 One units setting (°C/°F, g/oz) applied everywhere, recipes included.
- Commitment: nothing the user built is ever locked or moved behind a
  paywall (Next Cup is free).

Users also ask most for scale integrations (deferred by the owner), per-bean
statistics (X3), and gear and cost tracking (could).

## Positioning angle (default A, confirm at brand phase)

For home brewers who log carefully but still guess at the next cup, Next
Cup turns past brews into the next recipe: it remembers what worked for each
bean and proposes one change at a time. Supporting points: free, nothing is
locked or lost, and every brewer and step can be your own.

## Feature matrix

See `features.csv`. Counts are in that file's header note.

## Out of scope (cannot or should not be cloned)

- The sources' curated content: their recipe write-ups, articles, "coffee of
  the week" picks, community recipes, partner roaster products. Next Cup
  writes its own reference dataset; creator recipes only as credited
  parameters if B004 is approved.
- Social and community features (feeds, sharing recipes to others): out of
  scope by intake.
- Paid tier and paywall: Next Cup is free.
- AR gear previews: no value for the core loop and heavy to build.
- Home roasting (green beans, roast batches): outside the audience; skip.
- Vendor-specific Bluetooth scale protocols: hardware-dependent; open decision.

## Size

Screens ~15 for Next Cup's slice (S18 dropped, S15 skipped), flows 8,
entities ~9. Hard parts: the guided timer with background and haptics, the
taxonomy + recommendation matrix (not present in any source), on-device AI
flows with offline queueing, Bluetooth scales if chosen. Size: L for full
parity plus Next Cup's own features; M for the core loop.
