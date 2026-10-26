# Round 3: ten native looks (2026-10-26)

Harold rejected round 1 (palette swaps) and round 2 (themed gimmicks). Round 3 applies
heyimjames/ios-design-skills (the-final-5-percent), iAmVishal16/swiftui-microinteractions,
rshankras/claude-code-apple-skills (design, ui-prototyping) and rshzrh/ui-design-skills (ui-ios):

- Divergence by organizing metaphor, not paint (ui-prototyping): each look is a different idea of what the app *is*.
- Native first: semantic system colors, Dynamic Type styles, SF Pro, one tinted primary per screen.
- Liquid Glass only on the floating control layer; primary tinted, secondary clear.
- Craft: press-down scale + haptic (`PressScale`), staggered entrance (`assemble`), `.numericText` timers,
  symbol replace on play/pause, selection haptics. These are felt in motion, not visible in stills.

| # | Look | Reference | Idea |
|---|------|------|------|
| 1 | Today | Fitness / Health | Single "Today" summary, workout-style timer |
| 2 | Checklist | Things 3 | Quiet text list, open inline; recipe as a checklist |
| 3 | Now Playing | Apple Music | Beans as album covers, brew as a track |
| 4 | Journal | Day One / Bear | Writing first, serif pages, calendar strip |
| 5 | Pro Tool | Halide | Instrument: tracked caps, mono readouts, scale ruler |
| 6 | Board | Linear | Brews as issues: "needs a fix" vs "dialed in" |
| 7 | Step Cards | Mela | One step per card, readable from the counter |
| 8 | Run Summary | Slopes / Strava | Brew as a recorded session, live pour curve |
| 9 | Glance | Live Activities / Granola | One big Brew button; timer is the Live Activity |
| 10 | Coach | Messages | Brewing as a chat with a barista |

Code: `design/Concept/R3Look11..20*.swift`, run with `-look 11...20`.
