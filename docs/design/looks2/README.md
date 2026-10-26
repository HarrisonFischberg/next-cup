# Ten looks, round 2 (2026-10-26)

Round 1 (`docs/design/glass/`) was one layout in ten palettes; Harold wanted dramatically different
directions. Each look here has its own layout, type, timer and value entry. Built in the concept app
(`design/Concept/LookNN*.swift`, run with `-look N`); same data, timer and validation for all (`design/Shared/`).

Shared rules from the three skills: Liquid Glass on controls (tinted primary, `.interactive()`,
grouped in `GlassEffectContainer`), solid fill under Reduce Transparency (`LookGlass`), 44 pt targets,
one adjustable rating element for VoiceOver, light and dark.

| # | Look | ui-ux-pro-max style | Where the glass is |
|---|------|------|------|
| 1 | Glass Lab | Liquid Glass / Aurora mesh | Everything floats; the timer face is a glass disc, controls morph |
| 2 | Receipt | Brutalism | One clear square bar on a thermal ticket |
| 3 | Bauhaus | Bauhaus | Square tinted glass with hard offset shadows |
| 4 | Neon Bar | Retro-futurism | Magenta glass that glows in dark |
| 5 | Field Notes | Anti-polish / hand-drawn | Clear glass like a loupe on the page |
| 6 | Brew Lab Dashboard | Bento grid + data viz | System glass buttons and toolbar |
| 7 | Ma | Exaggerated minimalism | One clear glass disc |
| 8 | Clay | Claymorphism | Pastel sugar-glass buttons on clay |
| 9 | Departures | Split-flap signage | Glass push panels |
| 10 | Hardware | Skeuomorphic device | Glass keys |

Sheets: `look-01..10.png`, `looks-sheet-1/2.png` (journal, timer, log in light, then dark).
