# Design system: Steel & Kraft (Phase 3C)

Approved direction: Steel & Kraft (owner, 2026-10-21). Spec: `DESIGN.md`.
Code: `design/DesignSystem/` (`Tokens.swift`, `Components.swift`, `Gallery.swift`).
Tokens: `docs/design/tokens/tokens.light.json`, `tokens.dark.json`.

## Checks (run 2026-10-21)

| Check | Command | Result |
| --- | --- | --- |
| Swift tokens match the JSON | `python3 design/check_tokens.py` | in sync (14 colors, both appearances) |
| Contrast, light | `python3 <replica-design>/contrast.py docs/design/tokens/tokens.light.json` | 14 pairs, 0 failing AA |
| Contrast, dark | same, `tokens.dark.json` | 14 pairs, 0 failing AA |
| Build | `xcodebuild -project design/Concepts.xcodeproj -scheme Concept -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build` | succeeds |
| Gallery screenshots | `design/shoot-gallery.sh <out>` | 9 groups x light/dark x default/largest text; sheets in `docs/design/system/gallery-*.jpg` |
| F01 screens on the system | `design/shoot.sh` | `docs/design/system/flow-*.jpg` |

Lowest ratios: orange on the steel panel 5.2:1 (light) and 4.8:1 (dark); rule
on paper 4.5:1 (dark, UI). Everything else 5:1 or better.

## What changed from the concept

- The concept's private colors, fonts, buttons and tiles were moved into the
  system; `ConceptRoot.swift` now only lays out and wires screens (migration:
  no component is defined twice).
- Dark `rule` raised from `#6A6F74` to `#8A9096` so outlines on paper meet 3:1.
- Grade entry: the eight-tap half-step stepper is replaced by `GradeScale`
  (one tap per whole grade plus a half toggle). Fixes the critique's open item.
- Components now handle accessibility sizes themselves (stack, wrap, never
  break a word): found by the gallery at the largest text size and fixed
  (toast, banner, choice buttons, badges, tile captions).
- Loading is visibly different from disabled (full strength plus spinner vs 40%).
- Reduce Motion: press offset and skeleton pulse are removed when it is on.
- Added states the concept lacked: empty list, loading row, error and offline
  banners, Undo toast as a component.
- A missing journal empty state was added to the Journal screen.

## Component inventory and states

| Component | Default | Pressed | Disabled | Loading | Error | Empty | Selected |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SteelButton (primary, secondary) | yes | yes | yes | yes | n/a | n/a | n/a |
| SpecCell, PaperBox, ColumnHeader | yes | n/a | n/a | n/a | n/a | n/a | n/a |
| OperationRow | upcoming | n/a | n/a | n/a | n/a | n/a | live, done |
| InstrumentPanel, ReadoutBar | yes | n/a | n/a | n/a | n/a | n/a | n/a |
| StepperTile | yes | system | n/a | n/a | n/a | n/a | n/a |
| ReadoutTile | yes | n/a | n/a | n/a | n/a | n/a | n/a |
| ChoiceButton | yes | system | n/a | n/a | n/a | n/a | yes |
| GradeScale, GradeBadge | yes | system | disabled half toggle | n/a | n/a | unrated | yes |
| KraftNote | yes | n/a | n/a | n/a | n/a | n/a | n/a |
| SteelToast | yes | system | n/a | n/a | n/a | n/a | n/a |
| StateBanner | info | n/a | n/a | n/a | error, offline | n/a | n/a |
| EmptyState | n/a | n/a | n/a | n/a | n/a | yes | n/a |
| SkeletonRow | n/a | n/a | n/a | yes | n/a | n/a | n/a |

"system" means the platform's default highlight; "n/a" means the state does
not exist for that component.

## Known gaps (carried to Phase 4)

- VoiceOver and Accessibility Inspector not run on the components (labels,
  traits and adjustable actions are in code only).
- Full Keyboard Access focus ring not designed or tested.
- Journal swipe-delete has no Undo toast yet (task T010 requires it).
- Disabled button state is a 40% fade; its contrast is exempt as an inactive
  control but a text alternative should explain why it is disabled.
- Orange on the steel panel in dark mode is 4.8:1: passes AA, little headroom.
- Brass or other warmth from Late-Night Café was not applied; the owner chose
  "start now" rather than "warm it up first".
- Fonts are Apple-bundled (DIN Condensed, SF Mono, American Typewriter); no
  font files shipped, so no license row beyond `docs/asset-licenses.md`.
