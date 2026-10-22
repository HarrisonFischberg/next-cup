# Critique and audit (Phase 3B)

Method: design review only (detector not applicable, native platform).
Impeccable `critique` ran as Assessment A alone, inline, per its native rule;
`audit` ran from source per `audit.native.md`. Both are judgments by one
reviewer from the screenshots, the source and one live walkthrough, not
measurements, except the contrast table, which is computed.

What was and was not exercised:

| Check | Result |
| --- | --- |
| Screenshots, 5 concepts x 4 screens x light/dark x default/AX | Done, before and after the fix batch |
| Live F01 walkthrough on the simulator (tap Recipes, start, end and log, set verdict and grade, save, see journal row and Undo toast) | Done on concept 4 only. It found two real bugs (below). Concepts 1, 2, 3, 5 were checked from stage-launched screenshots and a clean build, not by tapping through |
| Contrast ratios for every text/background pair | Computed (table below) |
| VoiceOver, Accessibility Inspector | **Not run** (BLOCKED: no screen-reader driver in this setup). Labels and traits reviewed in code only |
| Reduce Motion, increased contrast, landscape | Not tested |
| Performance (Instruments) | Not measured |
| `/impeccable craft`, `/impeccable live` | Not used. The concepts were written directly; `craft` is a deprecated alias of new-work and `live` is browser-only |

## Findings and fixes (one batch each, then one confirming capture)

### 1 Charcoal & Crema
- Kicker above the headline ("CONE DRIPPER") and small-caps labels over every
  group. Fixed: removed the kicker, groups use plain headings.
- Hero-metric template (huge "1:16" plus label plus stats). Fixed: the recipe
  name leads; ratio moved into the spec row.
- Grade needs eight taps to reach 4.0 (half-step stepper). Kept; flagged for
  Phase 4 (direct tap targets).
- At the largest text size the log rows overflowed sideways. Fixed: rows stack,
  stars fixed-size.
- Verdict was saved but never shown in the journal. Fixed (all concepts).

### 2 Quiet Ceramic
- Disc button floated over content and the tab bar. Fixed: pinned as a bottom
  inset.
- Taste words looked like plain text. Fixed: hairline under each choice,
  glaze underline when selected.
- Timer close button clipped at the trailing edge at large text; controls and
  gauge overflowed. Fixed: padding, gauge becomes a horizontal bar, controls
  stack.

### 3 Terracotta, Hand-Thrown
- **Contrast failure, measured:** terracotta text was 4.3:1 on the sand
  background and 3.3:1 on clay. Fixed: light terracotta darkened to `#962F14`
  (6.2:1 on sand, 4.8:1 on clay).
- "Flame" symbol on a timer button implied fire. Changed to a timer glyph.
- Method name repeated the recipe name in the header. Removed.
- Dial center "of 3:00" truncated at large text. Fixed.

### 4 Steel & Kraft
- **Bug found live:** the close button's paper background bled up through the
  status bar (`background(Color)` ignores safe areas). Fixed for every panel.
- **Contrast failure, measured:** orange on the steel panel was 2.6:1 in light
  mode. Fixed with a lighter orange for text and the progress bar on steel (5.2:1 light, 4.8:1 dark).
- Step times wrapped vertically at large text. Fixed with a fixed-size time
  column and stacked rows.
- Method cell repeated the title; replaced with a step count.
- Same eight-tap grade issue as concept 1; flagged.

### 5 Late-Night Café
- Dotted-leader rows broke words ("Coff/ee") at the largest size. Fixed: the
  leader collapses to stacked name and value.
- Recipe summary line wrapped awkwardly. Now two lines.
- Wheel pickers hide the value until tapped, so changing five values costs
  five opens. Kept as the concept's cost; flagged.

### Shared (all concepts)
- Undo toast used the system blue instead of the concept tint. Fixed in the
  shared shell.
- Screenshots show a "Next Cup Concept" back-link in the status bar on some
  first-launch captures; it is the simulator's return-to-app chip, not UI.

## Design health (Nielsen, 10 heuristics, /40; judgment, after fixes)

| # | Concept | Score | Strongest | Weakest |
| --- | --- | --- | --- | --- |
| 1 | Charcoal & Crema | 29 | Timer legibility, quiet confidence | Stepper-only entry, slow grading |
| 2 | Quiet Ceramic | 28 | Typed entry is fastest for exact numbers | Low affordance on plain-text choices, one-disc-button hides secondary actions |
| 3 | Terracotta | 30 | Big targets, friendly, clear states | Sliders are imprecise for 0.5 g steps |
| 4 | Steel & Kraft | 31 | Whole recipe visible while timing; data density | Cold, all-caps heavy, grade stepper |
| 5 | Late-Night Café | 28 | Most atmospheric, spotlight timer | Wheels hide values, slower logging |

## Native audit (/16: performance not measured, so left out)

| Dimension | 1 | 2 | 3 | 4 | 5 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Accessibility | 3 | 3 | 3 | 3 | 3 | Labels and adjustable grade actions in code; 44 pt targets; AX-size layouts reflow in screenshots. Not VoiceOver-tested; no Reduce Motion handling yet (P2 for Phase 4) |
| Appearance and theming | 3 | 3 | 3 | 3 | 3 | Light and dark both designed; colors are dynamic UIColors, not an asset catalog (moves to tokens in 3C) |
| Platform conformance | 4 | 4 | 3 | 3 | 3 | System tab bar, stack, sheet, cover, swipe actions. 3/4/5 use hand-drawn buttons and tables inside the screens; none replaces navigation |
| Adaptivity | 2 | 2 | 2 | 2 | 2 | iPhone portrait only; keyboard inset checked only on the system sheet; landscape untested |
| **Total** | **12** | **12** | **11** | **11** | **11** | out of 16 |

P2 items for Phase 4 regardless of pick: Reduce Motion fallbacks, direct-tap
grading, VoiceOver pass, keyboard-covers-Save check with a real keyboard,
timer digit cap (`xxxLarge`) reviewed against the X7 large-digits requirement.

## Contrast (computed, WCAG 2.x relative luminance)

All text and control pairs measured pass 4.5:1 after the fixes except where
noted as large text. Before the fixes three pairs failed: terracotta on sand
4.3:1, terracotta on clay 3.3:1, orange on steel (light) 2.6:1.

| Concept | Lowest passing pair | Ratio |
| --- | --- | --- |
| 1 | crema on bg (light) | 5.0 |
| 2 | glaze on bg (light) | 5.5 |
| 3 | terracotta on clay (light, after fix) | 4.8 |
| 4 | orange on steel panel (after fix, dark panel is the lowest) | 4.8 |
| 5 | brass on bg (light) | 5.4 |

The full pair list is reproducible from the palette constants at the top of
each `ConceptRoot.swift`.
