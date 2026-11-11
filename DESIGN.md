---
name: Next Cup
description: A brew journal as a kitchen poster: butter, cream and cobalt in whole fields, heavy rounded type, the brewer's drawing in front, and a timer screen that changes colour when your hands are needed.
colors:
  cream: "#FFFDF3"
  cream-dark: "#0E1230"
  paper: "#FFFFFF"
  paper-dark: "#171D45"
  butter: "#F5E8A4"
  butter-dark: "#14204F"
  cobalt: "#2448C8"
  cobalt-dark: "#FFFDF3"
  on-cobalt: "#FFFFFF"
  on-cobalt-dark: "#0E1230"
  accent: "#2448C8"
  accent-dark: "#FF9F5A"
  field: "#2448C8"
  on-field: "#FFFDF3"
  field-soft: "#F5E8A4"
  ink: "#2B1A12"
  ink-dark: "#FFFDF3"
  ink-muted: "#625046"
  ink-muted-dark: "#C9CCE6"
  line: "#8A7A6E"
  line-dark: "#7B82B8"
  error-red: "#9A1B0A"
  error-red-dark: "#FFA08C"
  ok-green: "#2A6A2A"
  ok-green-dark: "#9FE0A8"
typography:
  page-title:
    fontFamily: "SF Pro Rounded"
    fontSize: "Large Title, scales, capped at accessibility1"
    fontWeight: 800
  headline:
    fontFamily: "SF Pro Rounded"
    fontSize: "Headline, scales"
    fontWeight: 800
  body:
    fontFamily: "SF Pro Rounded"
    fontSize: "Body, scales"
  data:
    fontFamily: "SF Pro Rounded, monospaced digits"
    fontSize: "Callout / Title, bold"
  timer-readout:
    fontFamily: "SF Pro Rounded, monospaced digits"
    fontSize: "84pt, capped at xxxLarge"
    fontWeight: 800
rounded:
  panel: "22px"
  control: "pill"
  poster-corner: "36px"
spacing:
  xs: "5px"
  sm: "10px"
  md: "14px"
  lg: "19px"
  xl: "29px"
  xxl: "38px"
components:
  button-primary:
    backgroundColor: "{colors.cobalt}"
    textColor: "{colors.on-cobalt}"
    rounded: "{rounded.control}"
    height: "60px"
  step-button:
    backgroundColor: "{colors.cobalt}"
    textColor: "{colors.on-cobalt}"
    rounded: "full"
    height: "40px (44px target)"
  tile:
    backgroundColor: "{colors.butter} at 50%"
    textColor: "{colors.ink}"
    rounded: "{rounded.panel}"
  poster:
    backgroundColor: "{colors.butter}"
    textColor: "{colors.ink}"
    rounded: "{rounded.poster-corner}"
  timer-field:
    backgroundColor: "{colors.field}"
    textColor: "{colors.on-field}"
    rounded: "{rounded.poster-corner}"
---

# Design System: Next Cup

The hexes above are Sunday Studio, the look the app ships with ("Fill the Cup",
chosen November 2026). Source of truth: `NextCup/DesignSystem/Tokens.swift` and
`docs/design/tokens/sundayStudio.json`, kept in sync by `design/check_tokens.py` and
checked for contrast by `design/contrast.py`. Settings still offers five other looks
(Brass, Steel Blue, Daily, Café Page, Roaster Poster); each is a palette plus a
`Flavor` (type, corners, density, control and number style) over the same layouts, so
every rule below is written against token roles, not hexes.

## Overview

**Creative North Star: "Fill the Cup"**

Next Cup looks like a poster on the kitchen wall. Colour comes in whole blocks: a
butter poster at the top of a recipe, cream everywhere else, and cobalt for the one
thing to press. The brewer you are using is drawn, not photographed, and sits in front.
During a brew the screen itself is the signal: it turns cobalt while your hands are
needed and goes back to cream when they are not, and a cup fills as the water goes in.

It is used one-handed at the brew station, often with wet hands, so type is large,
targets are large, and the state can be read from across the counter.

**Key characteristics**
- Three colours do the work: cream ground, butter second colour, cobalt for action.
- Heavy rounded type, sentence case; numbers in the same face with fixed-width digits.
- The method's drawing (`BrewGlyph`) is the hero wherever a recipe or method is shown.
- Values you set sit on butter tiles; records and messages sit on white cards.
- One primary button per screen, a full-width pill.

## Colors

Roles, with the token that carries each (`DS.` in code):

- **Ground** (`bg`): cream; navy in dark.
- **Card** (`paper`): white; indigo in dark. Records (journal rows, bean cards), banners,
  menus and the music bar.
- **Second colour** (`kraft`): butter. The Start brew poster, recipe-card heads, step
  chips, the "Explore by method" block. Text on it is `onKraft`.
- **Tile** (`tile`): the second colour at half strength over the ground. Holds a value
  you set: dose, grind, amount, the pickers on the brew form.
- **Action** (`signal`, text `onSignal`): cobalt; cream in dark. The primary button and
  the − and + of every stepper.
- **Accent** (`accent`): labels, icons, links and progress; cobalt in light, orange in
  dark.
- **Field** (`field`, text `onField`, quieter text `fieldSoft`): the brew timer while
  your hands are needed; cobalt with cream and butter text in both appearances. These
  are the `steel`, `onSteel` and `signalOnSteel` tokens, which every look already
  defines as a checked pair; toasts use the same three.
- **Ink** (`ink`, `ink2`): text; `ink2` is for labels and captions only and becomes
  `ink` under Increase Contrast.
- **Line** (`line`): outlines and dividers, 3:1 against what they border.
- **Error** and **OK**: messages only, always with an icon or words.

### Rules
- **One thing is cobalt.** A screen has one filled cobalt button. The stepper buttons
  are small and belong to their tile; nothing else is filled with the action colour.
- **State is never colour alone.** The timer's field always comes with the chip
  ("Pour now", "Hands off", "Get ready") and the instruction in words.
- **Measure before adding.** A new pair goes into `tokens.light.json`'s `pairs` and
  through `design/contrast.py` before it ships.

## Typography

System fonts only. Sunday Studio sets everything in SF Pro Rounded (`bodyDesign` and
`displayDesign` `.rounded`), display weight heavy.

- **Page title** (`DS.Font.pageTitle`): tab titles, the recipe name on the poster, the
  timer's instruction. Large Title, capped at `accessibility1`, up to three lines.
- **Headline** (`DS.Font.headline`): row names, chip names, the next step.
- **Tile title**: Subheadline, bold. Names the value a tile holds.
- **Body, footnote, caption**: system text styles; captions in `ink2`.
- **Data** (`DS.Font.data`, `dataLarge`): measured values, with monospaced digits so
  they do not jump.
- **Timer readout** (`DS.flavor.timerReadout`): the countdown, capped at `xxxLarge`.

Every size is a text style or scales from one. Large display text is capped so one
element never fills the screen; layouts stack instead (the poster drops its drawing,
the cup moves above the countdown, the next-step strip stacks).

## Layout

One column, `DS.Space.lg` side margins, the 4-pt scale times the look's density
(Sunday Studio is airy, 1.2). Gaps grow with grouping: inside a tile `md`, between
tiles `md`, between sections `lg`.

- **Start brew:** the poster (method, name, the numbers that follow from the dose,
  the drawing) runs edge to edge and up under the navigation bar, with 36 pt bottom
  corners. Then beans, dose, grind and amount, each a tile with the same stepper row
  so the − and + line up. Steps are a strip of numbered chips; "Show instructions"
  swaps the strip for a timeline with the full text. Start brew is pinned at the bottom.
- **Brew timer:** music bar and step progress at the top; the chip, the instruction
  and its detail; the cup beside the countdown, centred in the room that is left; the
  next step and the controls pinned at the bottom. The field begins under the
  navigation bar with 36 pt top corners, so the system status bar keeps its colours.
- **Lists** (Journal, Beans, Explore): white cards on cream.

Navigation is the system tab bar, navigation stacks and sheets. iPhone portrait only.

## Shapes and depth

- Cards and tiles: the look's radius (22 pt). Buttons: pills. Poster and field: 36 pt
  on the edge that meets the page.
- Tiles, posters, chips and the timer field are flat fills with no border and no
  shadow. Cards (`panel`) keep the system glass with a hairline; with Reduce
  Transparency they become solid with a full border.
- Icons are SF Symbols. Tile titles carry no icon.

## Illustration

`BrewGlyph` holds one line drawing per brew method, drawn in code so it follows every
look and stays sharp. `BrewHero` puts it on a disc of the ground colour, to sit on the
second colour. `PourCup` is the timer's cup: outline in the text colour, and a liquid
that is always the plain contrasting colour: `liquid` (cobalt in light, off-white in
dark) off the field and `onField` (off-white) on it, standing a little off the wall so
the cup reads when both match. Nothing drawn as a liquid, drip, stream or pool may use
butter, the orange accent, or any yellow, brown, green or purple. All of it is decorative and hidden
from VoiceOver; the name beside it carries the meaning. Photographs are not used.

## Components

`NextCup/DesignSystem/Components.swift` unless noted.

- **SteelButton:** the primary (cobalt pill, 60 pt) and secondary (clear glass) button.
  Pressed, disabled (40%) and loading states; loading keeps the label.
- **FieldButtonStyle:** the timer's primary button, flat, in colours the screen passes:
  cobalt on cream, cream on the field. Presses to 0.97.
- **DialStepper** (`Features/Recipes`): caption, −, value, +. Hold the value for a dial.
  The − and + are `StepGlyph`: solid 40 pt discs inside a 44 pt target, 40% when at
  the end of the range.
- **StepperTile:** a value over its − and + on a tile (the brew form).
- **`.tile()` and `.panel(_:)`:** the two surfaces. Tile for a value you set, panel
  for a record or a message.
- **BrewHero, PourCup:** see Illustration.
- **StateBanner, SteelToast, EmptyState, SkeletonRow:** messages and states. Toasts
  carry Undo instead of a confirm dialog.
- **TimelineRow** (`Features/Recipes`): a step with its time, for the instructions view.

## Motion

- Press: 0.97 scale over 120 ms on the timer button; system press on glass buttons.
- The timer's field cross-fades over 250 ms when the state changes; the cup level and
  the progress move linearly each second; numbers use the numeric text transition.
- Look-level feel comes from `Flavor.motion` (Sunday Studio: a short spring on
  secondary feedback, never on the timer digits or the instruction).
- Reduce Motion: no scale, no spring, no moving level between seconds; the field
  changes at once.
- Haptics: start, step change, pause and resume, finish, and a warning five seconds
  before a step. One per event.

## Accessibility

- 44 pt targets everywhere; primary buttons 60 pt.
- Dynamic Type through the accessibility sizes: display text is capped and layouts
  stack.
- VoiceOver: each step is one element; the countdown reads as chip, caption and value;
  step changes are announced.
- Increase Contrast swaps `ink2` for `ink`. Reduce Transparency makes cards solid.

## Do and don't

**Do**
- Put the drawing of the brewer wherever a recipe or method is introduced.
- Put a value the user sets on a tile, with the shared stepper row.
- Keep the timer's state in words as well as colour.
- Run `python3 design/check_tokens.py` and `python3 design/contrast.py` after any
  colour change.

**Don't**
- Don't add a second filled cobalt button to a screen.
- Don't add photographs, gradients, glows or decorative icons on headings.
- Don't shrink text to fit; cap it and stack.
- Don't use `ink2` for anything the user must read to act.
