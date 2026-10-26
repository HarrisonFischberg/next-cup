# Ten Liquid Glass looks (2026-10-25)

Sources merged: Dimillian `swiftui-liquid-glass`, AvdLee `swiftui-expert-skill`, `ui-ux-pro-max`.
Rules all ten share (where the three agree):
- Glass only on controls (buttons, tab bar); journal, tables and forms stay on solid paper.
- Native `glassEffect`, tinted with the accent for the primary, `.interactive()` only on tappables,
  timer buttons grouped in one `GlassEffectContainer`.
- Reduce Transparency falls back to the solid buttons. Every palette passes WCAG AA (`design/contrast.py`, `StyleTests`).
- Primary buttons always use regular glass: clear glass over-saturates a tint and broke contrast in dark mode.

| # | Look | ui-ux-pro-max style | Idea |
|---|------|------|------|
| 1 | Crema Glass | Soft UI Evolution | Bloom's cream and rings with a caramel glass button. Safest step up. |
| 2 | Pour Over | Exaggerated Minimalism | White and black, light big numerals, clear glass secondaries, one copper accent. |
| 3 | Matcha Glass | Organic Biophilic | Sage and cream, rounded type, green glass. Calm. |
| 4 | Midnight Roast | OLED dark / Spatial UI | True black at night, amber glass glows on the timer. |
| 5 | Nordic Morning | Swiss Modernism 2.0 | Cool grid, steel panels, mono numbers, blue glass. Most "instrument". |
| 6 | Clay Glass | Nature Distilled | Terracotta with Cochin headings, clay glass. Warmest. |
| 7 | Aurora Roast | Aurora UI (muted) | Plum by day, peach by night, serif. Most distinctive. |
| 8 | Bento Bar | Bento Box Grid | Heavy rounded type, compact, mustard glass. Loudest. |
| 9 | Cold Brew | Glassmorphism | Ice blue, mono numbers, steel panels, clear glass secondaries. |
| 10 | Editorial Café | Editorial Grid / Magazine | Didot, red accent, sharp corners, clear glass. |

Sheets: `glass-01..10-*.png`, all in `glass-sheet-1.png` / `-2.png`. Each shows journal, timer and
brew form in light, then journal and timer in dark. Captured by `FlavorCaptureUITests` (testGlass*).
