# Round 5: clean and simple, from Filtru and Beanconqueror (2026-10-26)

Harold asked for a much cleaner, simpler, more elegant app, using Filtru (App Store) and
Beanconqueror as inspiration. Studied from their public App Store screenshots:

- Filtru: dark, quiet; brew methods as thin line icons in circles; the brew screen is one big
  scale gauge (weight in the middle, target and flow rate under a hairline) and one sentence.
- Beanconqueror: warm grey with white cards; four stat tiles; each brew card has a date, the
  bean, a thin rule and a two-column label/value grid; Latest/Archive tabs.

| # | Look | Idea |
|---|------|------|
| 41 | Guide | Filtru-led: method circles on home, gauge timer with a three-button bar |
| 42 | Logbook | Beanconqueror-led: stat tiles, date-block cards, plain light timer with step list |
| 43 | Together | Both: light method row and label/value cards, dark Filtru gauge for brewing |

Code `design/Concept/R5*.swift` (`-look 41...43`); shared gauge and pour model in `R5Kit.swift`.

## 44 Daily loop (functionality)

Harold's brief: a simple journal (grams of beans and water, recipes, methods) built around one
daily loop. Look 43's style, five screens:

1. **Today's brew**: opens as yesterday's brew with the tip applied. Bean by "Scan the bag" (on-device
   Apple Intelligence, or the user's own AI key) or typed roaster, coffee, roast; method circles; grams.
2. **Brew**: the gauge timer.
3. **Done, enjoy**: schedules a local notification 20 minutes later ("How's your Kenya?").
   Permission is asked here, in context, not at first launch.
4. **How does it taste?**: five plain choices with descriptions, stars, optional note.
5. **Your next cup**: one change (e.g. grind 22 → 21) with the reason, plus what to keep.

What the real app already has: brew drafts (`isDraft`), bag text/barcode scanning (DataScannerViewController),
rule-based dial-in suggestions (`SuggestionService`/`DialInRules`) and bring-your-own-key AI.
Missing: the taste reminder notification, on-device Foundation Models for reading the bag photo,
and "Today's brew" opening prefilled with the accepted tip.
