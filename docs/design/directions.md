# Design directions (Phase 3B)

Status: built, critiqued, fixed, screenshotted 2026-10-21. Waiting for the
owner's pick. Nothing here is `DESIGN.md`; that is written only after a
direction is approved.

## Brief (Impeccable `shape`, native iOS, Operate mode)

Run in this session with `impeccable context` loaded (PRODUCT.md, iOS
reference). The owner had already named the five worlds and the flow, so no
discovery round was held; assumptions are stated here instead.

- **Job and audience:** a precise home brewer at the brew station, often early,
  one hand wet, a scale and kettle in the other. The flow must beat paper.
- **Core flow (all five cover the same one):** F01 guided brew and log.
  Recipe detail (S07) -> guided timer (S05) -> prefilled log form (S02) ->
  journal (S01). Same data, same validation, same timer in every concept
  (`design/Shared/`); only presentation differs.
- **Hard rules in every concept:** actual values are what get saved and the
  recipe's targets sit beside them, never locked; Undo toast after saving, no
  confirm dialog; every control 44 pt or larger; Dynamic Type through the
  largest accessibility size; light and dark both first-class; haptic on each
  step change and on save; system tab bar, navigation stack, sheet and cover
  (HIG), brand lives in color, type, shape and the interaction inside the
  screens.
- **Out of scope here:** the other screens (bean library, methods, AI, import),
  real icons or brand marks, custom licensed fonts. Fonts used are Apple-bundled
  (Didot, Hiragino Mincho, Cochin, DIN Condensed, American Typewriter, Menlo,
  Bodoni 72, Gill Sans, SF); no font files are shipped, so no license rows yet.

## The five worlds

| # | World | Personality | Structural thesis | Timer | Value entry | Fonts |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Charcoal & Crema | Moody, sophisticated, ledger-like | One crema accent on charcoal (or crema paper in light); hairline rules | Giant Didot numerals, one segmented strip across all steps | Round -/+ steppers beside a large value | Didot, SF |
| 2 | Quiet Ceramic | Calm, spare, Japanese-minimal | Ivory/walnut, one celadon glaze, wide margins, one round disc button per screen | Light Mincho numerals plus a vertical water gauge showing where the scale should read | Typed entry with a decimal pad; targets in grey | Hiragino Mincho, SF Light |
| 3 | Terracotta, Hand-Thrown | Warm, tactile, friendly | Uneven clay shapes, chunky chips, big thumb targets | Pottery-wheel dial with a marker per step | Sliders and chips, tap-a-mug grading | Cochin, SF Rounded |
| 4 | Steel & Kraft | Utilitarian, exact, instrument-like | Spec-sheet tables, hard corners, kraft label for notes, one signal orange | Instrument panel: readout on top, every step listed, the live one lit | Tile grid with -/+ under each value | DIN Condensed, Menlo, American Typewriter |
| 5 | Late-Night Café | Intimate, amber-lit, menu-card | Brass double rules, dotted leaders, centered composition | Spotlight on the current step, others fade away; lamp glow in dark | Native wheel pickers that open in place | Bodoni 72, Gill Sans |

Each world differs in layout, typography, color, and how you enter a value;
none is a reskin. Source for each lives on its local branch `ui-1` to `ui-5`
(`design/Concept/ConceptRoot.swift`); never pushed.

## Evidence

Screenshots: iPhone 18 Pro simulator (iOS 27.0), light and dark, default text
and the largest accessibility size (`accessibility-extra-extra-extra-large`),
via `xcrun simctl io screenshot`. Side-by-side sheets are in
`docs/design/screenshots/compare/`; per-concept before/after in
`docs/design/screenshots/<n>-<name>/`. Screens are launched at fixed states
(`-stage`, `-elapsed` arguments) so every concept is shot at the same moment
(timer at 1:18, step 4 of 6). Not captured: landscape, iPad (out of scope),
real hardware.
