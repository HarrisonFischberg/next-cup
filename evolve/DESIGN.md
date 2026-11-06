# Next Cup design system, as shipped (main 81b34cc, 2026-11-06)

Read from the code: `NextCup/DesignSystem/Tokens.swift`, `Components.swift`, `Edition.swift`,
`Progress.swift`, `BrewGlyph.swift`, `Bloom.swift`, and the running app (shots in
`evolve/cycles/001/shots/baseline-*.png`). The root `DESIGN.md` describes the Oct 2026 "Steel & Kraft
bench instrument" system. It is stale. Use this file.

Every new screen is built from the `DS` tokens and the shared components. Never hard-code a hex,
radius or font. A look ("flavor") changes palette, type, corners, density, control shape and motion,
so a screen built from tokens follows all six looks for free.

## Harold's colour rules (hard constraints)

- No brown, no terracotta, no muddy or olive darks.
- No off-yellow or butter buttons.
- He likes white buttons with orange accents on navy (Sunday Studio dark).
- Restraint over novelty: clean, simple, elegant, native iOS. A "different" design means different
  layout, type and controls, not a palette swap.
- Glass goes on controls only. The primary button is always regular glass, because clear glass
  over-saturates the tint and fails contrast.

Watch out: Sunday Studio **light** uses butter `#F5E8A4` as its `kraft` colour block (the "Explore by
method" panel on Brew). That is a surface, not a button. Never put butter on a button, and do not
spread it to new surfaces without asking.

## Looks (AppStyle)

`AppStyle.current` is read live from `UserDefaults["appStyle"]`; the default is **Sunday Studio**
(`adoptSundayStudioOnce`). Settings offers six looks (`AppStyle.offered`), in this order:

| Look (case) | Mood | Display type | Radius | Density | Controls | Numbers | Motion |
|---|---|---|---|---|---|---|---|
| **Sunday Studio** (`sundayStudio`) default | cobalt on cream / white and orange on navy | SF Rounded heavy, body rounded | 22 | airy ×1.2 | pill | rounded, monospaced digits | playful; timer digits in accent |
| Brass (`morningEdition`) | ink and brass, editorial | New York serif, medium | 8 | airy | pill | serif | quiet |
| Steel Blue (`steelBlue`) | ink and steel blue, editorial | New York serif, medium | 8 | airy | pill | serif | quiet |
| Daily (`daily`) | warm white, white cards, amber | serif regular | 24 | airy | pill | serif | quiet |
| Café Page (`cafePage`) | paper, plum signal | serif semibold | 18 | airy | square | monospaced | quiet |
| Roaster Poster (`roasterPoster`) | white, green, hard offset "sticker" shadow | rounded heavy | 12 | regular | sticker | DIN Condensed | quiet |

Still in code but not offered (UI tests pin `-appStyle steelKraft`): bloom, steelKraft,
charcoalCrema, quietCeramic, nightMint, espressoBlack, precisionAtelier. Don't design for them.
Note that Daily's amber `#93591A` reads brown-ish.

Appearance: System / Light / Dark (`AppearanceMode`, key `appearanceMode`). Both appearances are
first class.

## Colour roles (`DS.*`, light / dark hex pairs)

Roles, not colours. Sunday Studio values first, since it is the default:

| Role | Use | Sunday Studio light | Sunday Studio dark |
|---|---|---|---|
| `bg` | screen | `#FFFDF3` cream | `#0E1230` navy |
| `paper` | cards, list rows, tiles | `#FFFFFF` | `#171D45` |
| `steel` | instrument panels, table headers | `#1B2F7A` | `#2448C8` |
| `onSteel` | text on steel | `#FFFDF3` | `#FFFDF3` |
| `ink` | primary text | `#2B1A12` | `#FFFDF3` |
| `ink2` | secondary text (becomes `ink` under Increase Contrast) | `#625046` | `#C9CCE6` |
| `line` | rules, outlines (3:1) | `#8A7A6E` | `#7B82B8` |
| `signal` | **buttons** and selection | `#2448C8` cobalt | `#FFFDF3` white |
| `onSignal` | text on buttons | `#FFFFFF` | `#0E1230` |
| `accent` | labels, kickers, icons, digits, progress, switches | `#2448C8` | `#FF9F5A` orange |
| `signalOnSteel` | accent on steel | `#F5E8A4` | `#F5E8A4` |
| `kraft` | the look's second colour block (`colorBlock()`) | `#F5E8A4` butter | `#14204F` indigo |
| `onKraft` | text on kraft | `#2B1A12` | `#FFFDF3` |
| `error` | messages only | `#9A1B0A` | `#FFA08C` |
| `ok` | messages only | `#2A6A2A` | `#9FE0A8` |

Brass and Steel Blue share an ink palette (light `#F7F7F4` bg / `#1A2129` ink buttons; dark `#10151B`
bg / ivory `#F2F0EA` buttons). Only the accent differs: brass `#7A5C14`/`#D9B36A`, steel blue
`#2F5E9E`/`#8FB3E8`. Use `palette.accent ?? palette.signal` (that is `DS.accent`).

Rules:
- `DS.signal` is for buttons. `DS.accent` is for everything else that needs colour: kickers, icons,
  digits, progress, switch tint (`SwitchToggleStyle(tint: DS.accent)` is set at the root).
- One accent block per screen region.
- The tab bar tint is `DS.ink`.
- Tokens are mirrored in `docs/design/tokens/<look>.json`. After any colour change, run
  `python3 design/check_tokens.py` and `contrast.py`.

## Type

- Display text comes from `Flavor.display` (Sunday Studio: `.system(style, design: .rounded,
  weight: .heavy)`). `caps` is false for every offered look, so titles stay as written.
- `DS.Font.pageTitle`: tab-root title, 44 pt on largeTitle (56 pt DIN in caps looks).
- `DS.Font.display`: 34 pt on title. Recipe name, empty-state titles.
- `DS.Font.headline`: 21 pt on headline. Row names, section rules.
- `DS.Font.label`: caption semibold, uppercase, tracked 1.2 in a `Kicker`. Kickers ("NEXT CUP"),
  tile labels.
- `DS.Font.instruction`: 34 pt. The current brew step.
- `DS.Font.data` (callout bold) and `dataLarge` (title bold) for measured values. Numbers always
  use monospaced digits.
- `DS.Font.readout`: 104 pt (rounded bold). `Flavor.timerReadout` is 84 pt rounded heavy for the
  timer.
- `DS.Font.note`: American Typewriter 15 pt, for notes.
- Body text uses system text styles with the look's `bodyDesign` (rounded in Sunday Studio), set at
  the root with `.fontDesign`.
- Everything is relative to a text style. Display text is capped at `DS.displayCap` (.accessibility1)
  and the readout at `.xxxLarge`. Layouts stack at accessibility sizes instead of shrinking.

## Spacing and sizes

- `DS.Space`: xs 4, sm 8, md 12, lg 16, xl 24, xxl 32, multiplied by density (airy ×1.2, so
  5/10/14/19/29/38 in Sunday Studio).
- Margins are 16 pt (×density). One column, iPhone portrait.
- `DS.Size`: minTap 44, control 48, primary button 60, timer control 64.
- Rules: `DS.rule` 1.5, `DS.hairline` 1.

## Shape

- `DS.radius` = the look's radius (Sunday Studio 22) for cards, panels, tiles and colour blocks.
  Always use `RoundedRectangle(cornerRadius:style: .continuous)`.
- `DS.controlRadius` is 999 (a capsule) for pill looks. Use it **only for buttons**. A card with
  controlRadius turns into a giant oval (this happened before on GettingStartedCard).
- `ColumnHeader` caps its radius at 12.

## Surfaces and depth

- `.panel(fill)` (Components.swift) is the one card surface: Liquid Glass `.regular.tint(fill.opacity(0.6))`
  clipped to the radius, with a 1 pt `line` border at 35%. Under Reduce Transparency, and in sticker
  looks, it becomes a solid fill with a full `DS.rule` border (stickers add a 3 pt accent offset shadow).
- `PaperBox`, `InstrumentPanel` (steel) and `ReadoutTile` (dashed) all build on `.panel`.
- `.colorBlock()` puts the look's `kraft` colour behind a hero or a group of rows. In Sunday Studio
  that is butter in light and indigo in dark.
- Journal rows are white or `paper` rounded cards. There are no drop shadows apart from the glass
  and the sticker offset.

## Buttons

- `SteelButton(title:kind:isLoading:action:)` with `SteelButtonStyle`.
  - Primary: Liquid Glass `.regular.tint(DS.signal).interactive()`, `onSignal` text, 60 pt tall,
    full width, display font 26 pt. Sunday Studio gives a cobalt pill in light and a **white pill
    with navy text** in dark.
  - Secondary: clear regular glass, `ink` text, 64 pt.
  - Disabled is 40% opacity. Loading shows a spinner and keeps the label for VoiceOver, with
    taps blocked.
  - The solid fallback (Reduce Transparency or sticker looks) moves 2 pt down on press; under
    Reduce Motion it dims instead.
- Round icon buttons (Brew page +, `SettingsGear(large:)`): a 52 pt circle. The + is filled
  `signal`. The gear sits on `paper` with a `line` stroke at 50%.
- Toolbar items (Journal gear and +) use the system glass toolbar group.
- `ChoiceButton`: exclusive choices (verdicts). The selected one is filled with signal and gets
  the selected trait.
- Links and text actions ("All methods ›") use `DS.accent`.

## Page furniture (Edition.swift)

- `PageHeader(title:kicker:trailing:)`: an accent Kicker "NEXT CUP" over a big pageTitle, with one
  trailing action. Every tab root starts with it.
- `SettingsGear(id:large:)`: Settings sits on every tab, left of the + button.
- `Kicker`, `SectionRule(title:trailing:)` (hairline at 60%, then a headline and an optional
  action), `LabeledRow(symbol:label:…)`, `Figure`, `BrewHero` / `HeroBanner` (Unsplash method
  photos `method.<key>`, credited in `docs/asset-licenses.md`).
- Progress.swift: `StepProgress` (onboarding "Step N of M"), `StagedProgress`, `SuccessView`.
- DailyLoop: a loop strip (Brew · Rest · Taste · Next) on a hairline. Done stations are filled and
  the current one is ringed in the accent.

## Other components (Components.swift)

`Hairline`, `SpecCell`, `ColumnHeader` + `OperationRow` (the live row fills with signal),
`ReadoutBar`, `StepperTile` (value, unit, TARGET, −/+ halves 48 pt, optional typed field),
`ReadoutTile`, `GradeScale` (rating 0–10 in tenths: a slider plus −/+ in the accent, 0 = unrated),
`GradeBadge`, `KraftNote` (dashed, typewriter), `SteelToast` (bottom bar with one Undo, used instead
of confirm dialogs), `StateBanner` (error / offline / info, always names a way out), `EmptyState`
(title, sentence, one action), `SkeletonRow` (0.9 s pulse, static under Reduce Motion),
`.hiddenWhileTyping` for pinned bottom bars. Recipes: `DialStepper` and `GrindWheel` (−/+ with
hold-for-dial so a scroll can't change them).

## Iconography and illustration

- SF Symbols for UI. Tabs: `cup.and.saucer` Brew, `book.closed` Journal, `leaf` Beans,
  `safari` Explore. Gear `gearshape`, add `plus`.
- Brewer drawings: `BrewGlyph` / `BrewArt` line drawings per method (13 methods plus the
  Nespresso joke cup), drawn in `ink` with an accent rim and left empty (`GlyphInk.still`). Only the
  timer scene (`BrewSceneView`) fills with coffee in the accent and animates: the kettle tips, the
  press plunges.
- Photos are used only as method heroes. Nothing decorative beyond that.

## Motion

- `Flavor.motion`: `.playful` (Sunday Studio) = spring(response 0.35, damping 0.72) for state
  changes, easeOut 0.25 for text. `.quiet` = easeInOut 0.3. `.crisp` = easeOut 0.18.
- Text and instructions never bounce. Button press is 0.1 s easeOut.
- Reduce Motion removes offsets, pulses and the timer scene's movement.
- Haptics only on start, step change, pause/resume, end, toggle and drop.

## Accessibility baseline

44 pt minimum targets. Every component carries labels, values and traits. Increase Contrast swaps
`ink2` for `ink`. Reduce Transparency replaces glass with solid fills. Dynamic Type is capped and
reflows. Every gesture has a visible alternative (the hidden Experiments long press is Debug and
TestFlight only, and also has a VoiceOver action).
