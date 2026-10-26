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
