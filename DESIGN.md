---
name: Next Cup
description: A brew journal built like a bench instrument: spec-sheet tables, one signal orange, kraft paper for notes.
colors:
  kraft-board: "#D9C4A0"
  gunmetal: "#1B1D1F"
  sheet-paper: "#EFE6D3"
  gunmetal-paper: "#26292C"
  panel-steel: "#2B2F33"
  panel-steel-dark: "#30353A"
  steel-text: "#E8EAEC"
  ink: "#1E1E1C"
  ink-dark: "#ECEAE4"
  ink-muted: "#4A463E"
  ink-muted-dark: "#B4B1A8"
  rule: "#1E1E1C"
  rule-dark: "#8A9096"
  signal-orange: "#C2410C"
  signal-orange-dark: "#FF7A3D"
  signal-on-steel: "#FF7A3D"
  on-signal: "#FFFFFF"
  on-signal-dark: "#1B1D1F"
  label-kraft: "#C9AE82"
  error-red: "#9A1B0A"
  error-red-dark: "#FF9C85"
  ok-green: "#2A6A2A"
  ok-green-dark: "#7FD18A"
typography:
  display:
    fontFamily: "DIN Condensed Bold"
    fontSize: "34pt (Title, scales)"
    fontWeight: 700
    lineHeight: 1.05
  headline:
    fontFamily: "DIN Condensed Bold"
    fontSize: "21pt (Headline, scales)"
  label:
    fontFamily: "DIN Condensed Bold"
    fontSize: "16pt (Footnote, scales)"
    letterSpacing: "0.5pt"
  data:
    fontFamily: "SF Mono"
    fontSize: "Callout, bold"
  data-large:
    fontFamily: "SF Mono"
    fontSize: "Title, bold"
  readout:
    fontFamily: "SF Mono"
    fontSize: "104pt, capped at xxxLarge"
    fontWeight: 700
  note:
    fontFamily: "American Typewriter"
    fontSize: "15pt (Body, scales)"
rounded:
  control: "3px"
  panel: "0px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.signal-orange}"
    textColor: "{colors.on-signal}"
    rounded: "{rounded.control}"
    height: "60px"
  button-secondary:
    backgroundColor: "{colors.panel-steel}"
    textColor: "{colors.steel-text}"
    rounded: "{rounded.control}"
    height: "64px"
  stepper-tile:
    backgroundColor: "{colors.sheet-paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.panel}"
    padding: "12px"
  operation-row-live:
    backgroundColor: "{colors.signal-orange}"
    textColor: "{colors.on-signal}"
    rounded: "{rounded.panel}"
    padding: "12px"
  kraft-note:
    backgroundColor: "{colors.label-kraft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.panel}"
    padding: "12px"
---

# Design System: Next Cup

Light-mode hexes are the defaults above; the `-dark` entries are the gunmetal
appearance. Source of truth: `docs/design/tokens/*.json` and
`NextCup/DesignSystem/Tokens.swift` (kept in sync by `design/check_tokens.py`).
Values the format cannot hold (focus, motion, depth) are in the sections below.

## Overview

**Creative North Star: "The Bench Instrument"**

Next Cup looks like the tool on the bench next to the scale: a spec sheet with
a readout. Information sits in ruled tables and square tiles, measured values
are monospaced, names are set in condensed capitals, and one signal orange
marks the thing that is happening now or the thing to press. Notes live on a
piece of kraft stock, because a journal is paper at heart. Light mode is kraft
board and cream sheets; dark mode is gunmetal. Both are first-class.

It rejects the soft wellness-app look: no rounded cards, gradients, glass or
mascots. It is dense but never cramped, because it is used one-handed at the
brew station.

**Key Characteristics:**
- Ruled tables and square tiles; 1.5 pt rules; no shadows.
- Monospaced numbers so values line up and do not jump while the timer runs.
- One accent, orange, used for the primary action and the live step only.
- Large hit areas: every control is at least 44 pt; primary buttons are 60 pt.
- Everything reflows at the largest accessibility text size.

## Colors

A kraft-and-steel palette with a single hot accent.

### Primary
- **Signal Orange** (`#C2410C` light, `#FF7A3D` dark): the primary button, the live step, selected choices, grade blocks. White text on it in light (5.2:1), gunmetal text in dark (6.5:1). On steel panels use **Signal on Steel** (`#FF7A3D`, 5.2:1 light, 4.8:1 dark).

### Neutral
- **Kraft Board** (`#D9C4A0`) / **Gunmetal** (`#1B1D1F`): the screen.
- **Sheet Paper** (`#EFE6D3`) / **Gunmetal Paper** (`#26292C`): tables, tiles, list rows.
- **Panel Steel** (`#2B2F33` / `#30353A`): the timer readout, table headers, secondary buttons.
- **Ink** (`#1E1E1C` / `#ECEAE4`) and **Ink Muted** (`#4A463E` / `#B4B1A8`): text; muted is for labels and captions only.
- **Rule** (`#1E1E1C` / `#8A9096`): every outline and divider; 3:1 or better against the surfaces it borders.
- **Label Kraft** (`#C9AE82`): the note stock, same in both appearances, with `#1E1E1C` text (7.8:1).
- **Error Red** (`#9A1B0A` / `#FF9C85`) and **OK Green** (`#2A6A2A` / `#7FD18A`): messages only, never decoration.

### Named Rules
**The One Voice Rule.** Orange appears on at most one block per screen region: the action to take or the step in progress. If two things are orange, one is wrong.
**The Measured Contrast Rule.** Every text and control pair is checked with `contrast.py` against both token files. A new color is not added until its pairs pass AA.

## Typography

**Display Font:** DIN Condensed Bold (bundled with iOS, set uppercase)
**Data Font:** SF Mono (system monospaced)
**Note Font:** American Typewriter (bundled with iOS)
**Body:** SF Pro via system text styles

**Character:** a stencil-and-ledger pairing: condensed capitals name things, monospaced figures measure them, typewriter text is the human note.

### Hierarchy
- **Display** (DIN Bold, 34 pt, Title style): the recipe name, empty-state titles.
- **Headline** (DIN Bold, 21 pt): row and bean names.
- **Label** (DIN Bold, 16 pt, uppercase): column headers and tile labels.
- **Data** (SF Mono bold, Callout / Title): every measured value.
- **Readout** (SF Mono bold, 104 pt, capped at xxxLarge): the timer.
- **Note** (American Typewriter, 15 pt): tuning notes and the tasting note.
- **Body** (system, Body): instructions and sentences, 65 characters or fewer per line on a phone.

### Named Rules
**The Dynamic Type Rule.** Every size is relative to a text style. Large display text is capped (`accessibility1`, timer `xxxLarge`) so one control never exceeds the screen; layouts stack instead of shrinking.
**The Numbers Are Monospaced Rule.** Measured values are never set in a proportional face.

## Layout

One column, 16 pt side margins, 4-pt spacing scale (4, 8, 12, 16, 24, 32). Tables run edge to edge inside the margin; tiles sit in a two-column grid that becomes one column at accessibility sizes. Primary actions are pinned to the bottom third inside a safe-area inset so a thumb reaches them and the keyboard never covers Save. Navigation is the system tab bar (Journal, Recipes), navigation stack, sheet (log form) and full-screen cover (timer). iPhone portrait only.

## Elevation & Depth

Flat. Depth is conveyed by rules, contrasting surfaces (paper on board, steel on paper) and the 2 pt press offset on buttons. There are no shadows, blur or gradients. System surfaces (tab bar, sheet) keep their native materials.

**The Flat-By-Default Rule.** No shadow is added to any component; hierarchy comes from rule weight and surface color.

## Shapes

Square. Panels, tables, tiles and chips have 0 radius; buttons have a 3 pt radius so they read as pressable. Outlines are 1.5 pt (1 pt for inner dividers). Kraft notes have a dashed outline like a cut label. Icons are SF Symbols only, used sparingly.

## Components

All components live in `NextCup/DesignSystem/Components.swift`.

### Buttons
- **Primary** (`SteelButton`): signal orange, uppercase DIN, 60 pt tall, full width. Pressed: down 2 pt (brightness dip under Reduce Motion). Disabled: 40% opacity. Loading: spinner beside the label, taps blocked, label kept for VoiceOver.
- **Secondary:** panel steel, 64 pt on the timer row, same states.

### Spec cell, table, operation row
- **SpecCell / PaperBox:** label over a monospaced value in a ruled grid.
- **ColumnHeader + OperationRow:** steel header, paper rows; the live row turns orange and shows its instruction; finished rows turn muted.

### Instrument panel
- **InstrumentPanel + ReadoutBar:** steel panel, the elapsed time and a thin orange bar (decorative; the value is the label).

### Value entry
- **StepperTile:** value, unit, recipe target beneath, and minus/plus halves 48 pt tall. The saved value is whatever is shown; the target is never locked.
- **ReadoutTile:** derived values (ratio) in a dashed outline, no input.
- **ChoiceButton:** one of several exclusive words; selected is orange with the selected trait.
- **GradeScale:** five square cells 1 to 5, one tap per whole grade, a half-step toggle, adjustable for VoiceOver.
- **GradeBadge:** orange block with the grade in lists.

### Notes
- **KraftNote:** kraft stock with a dashed outline, typewriter text.

### Feedback and state
- **SteelToast:** steel bar with one Undo action; used instead of confirm dialogs for reversible actions.
- **StateBanner:** error, offline and info; names the problem and offers a way out.
- **EmptyState:** title, one sentence, one action.
- **SkeletonRow:** paper block with grey bars; pulses unless Reduce Motion is on.

### Focus and motion
- Focus (Full Keyboard Access): not yet designed or tested. Open item for Phase 4: verify the system focus ring is visible on every custom control and add an ink outline where it is not.
- Motion: 100 ms ease-out for press; skeleton pulse 0.9 s. Reduce Motion removes the press offset and the pulse.

## Do's and Don'ts

### Do:
- **Do** show the recipe target beside every value the user can change.
- **Do** keep every control 44 pt or larger and stack rows at accessibility sizes.
- **Do** set measured numbers in SF Mono and names in DIN capitals.
- **Do** use Undo toasts for reversible actions and keep the draft on any failure.
- **Do** run `python3 design/check_tokens.py` and `contrast.py` after any color change.

### Don't:
- **Don't** add rounded cards, shadows, gradients, blur or decorative illustrations.
- **Don't** put orange on more than one block in a region.
- **Don't** use muted ink for anything the user must read to act.
- **Don't** shrink text to fit; cap it and reflow.
- **Don't** lock or hide a user's value behind a recipe target.
