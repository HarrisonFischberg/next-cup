# Interaction matrix

November 2026, branch `interaction/polish` on top of `design/fill-the-cup`. Shared pieces live
in `NextCup/DesignSystem/Interaction.swift`: `DS.Motion` (durations, press scale, enter and
exit), `Feedback` (the semantic haptics), `PressableStyle` (card press) and
`Announcement.urgent` (VoiceOver, spoken now). Look-level character stays in `Flavor.motion`.

Status: **done** (this pass), **there** (already in the app, checked), **n/a** (with the
reason), **device** (built, but the feel can only be judged on a phone).

P1 = a fundamental, P2 = polish.

## Brew timer

| Journey | Trigger and intent | Visual | Gesture + alternative | Haptic and sound | States, Reduce Motion | P | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Step change | The schedule reaches the next shown step | New command rises 28 pt into place as the old one lifts away (250 ms ease-out); chip, field colour, progress segment and "Step n of m" change with it | None needed; Skip step does the same by hand | Two heavy beats 140 ms apart plus the chime | Reduce Motion: 200 ms cross-fade, no travel. VoiceOver: "Step 2 of 4. Pour to 250 g. Add 205 g." at high priority | P1 | done, device for the beat |
| Short steps joined on screen | A step under 15 s shares a screen with the next | Nothing moves inside a joined step | n/a | One cue when the screen changes; none when the joined step's own second passes (it used to chime and thump with nothing to see) | Same | P1 | done |
| Five seconds before a step | Heads-up | Next-step strip turns butter with a large count; field turns cobalt; chip "Get ready" | n/a | Warning haptic plus chime | VoiceOver "Get ready: …", now high priority | P1 | there |
| Start, Pause, Resume, Finish | Big button | Presses to 0.97 and darkens, 120 ms | Tap | Light tap; success on finish | A second tap within half a second is ignored, so a double tap cannot start-then-pause or skip the finished screen. Reduce Motion: darkens only | P1 | done |
| Skip step, End brew | Text buttons | System press | Tap; End asks first because a running brew cannot be resumed | Step-change cue on skip, success on end | Confirmation kept: undo is impossible | P1 | there |
| Hands-on / hands-off field | State change | 250 ms cross-fade of the whole field | n/a | none (the step cue covers it) | Reduce Motion: at once. Always with the chip and words | P1 | there |
| Cup, steam, progress, countdown | Each second | Linear level, numeric text transition, steam on its own clock | n/a | none | Reduce Motion: no moving level, still steam | P2 | there |
| Music bar | Previous, play or pause, next | System press | Tap; targets now 44 × 44 (were 38 wide) | Selection tick when the song changes | Equalizer rests when paused or Reduce Motion | P1 | done |
| Back in the foreground | Returning mid-brew | Catches up to the right step | n/a | Missed cues are not replayed | — | P1 | there |
| Finished | Brew ends | Banner fades and grows from 0.94 | Tap one of two buttons | Success | Reduce Motion: fade only | P2 | there |

## Brew tab, recipes, Start brew

| Journey | Trigger and intent | Visual | Gesture + alternative | Haptic | States, Reduce Motion | P | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Recipe, method and style cards | Tap to open | Card shrinks to 0.97 and dims under the finger, 120 ms; cancels when a scroll takes over | Tap | none (navigation) | Reduce Motion: dims only | P1 | done |
| Recipe card menu | Long press: favorite, edit, duplicate, delete | System context menu | Long press; VoiceOver action for favorite; Edit and Duplicate are also on the recipe page | Light tap on favorite | — | P1 | there |
| Delete a recipe | Menu → Delete | Card leaves (200 ms), "Recipe deleted · Undo" toast for 6 s | Undo button; toast announced to VoiceOver | Medium on delete, light on undo, error if the write fails | Was an "are you sure" sheet. A failed write puts the card back with a banner | P1 | done |
| Favorite star | Toggle | Star scales in, short spring | Menu or VoiceOver action | Light tap | Reduce Motion: no spring | P2 | there |
| Steppers (dose, grind, amount) | − / +, or hold the value for a dial | Numeric text | Tap, hold-to-repeat, dial; VoiceOver adjustable | Selection per notch | 44 pt targets | P1 | there |
| Start brew | Pinned primary button | Glass press | Tap | Light tap as the timer starts | — | P1 | there |
| Recipe editor: steps | Reorder, remove | Row menu | Move up / Move down / Remove in the row's menu | none | Remove has Undo (6 s). Drag to reorder is **n/a**: steps run in time order, so position follows the time field | P1 | there |
| Recipe editor: leave with changes | Swipe the sheet down | Sheet stays | Cancel asks; Save | — | Swipe-dismiss is off while there are changes | P1 | there |
| Create with AI | Send | Brewing cup while it works | Cancel | Success or error when the answer is known | Sheet cannot be swiped away mid-request; Reduce Motion: still cup | P1 | there |

## Journal

| Journey | Trigger and intent | Visual | Gesture + alternative | Haptic | States, Reduce Motion | P | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Brew row | Open | System row highlight | Tap | none | — | P1 | there |
| Delete a brew | Trailing swipe (full swipe commits), menu, VoiceOver action | Row leaves, "Brew deleted · Undo" 6 s | Swipe, long-press menu, VoiceOver "Delete" | Medium, light on undo | Toast now announced to VoiceOver. Write failure restores the row | P1 | there + done |
| Brew again | Leading swipe, menu | Opens Start brew | Swipe, menu, VoiceOver action | none | — | P1 | there |
| Unsaved brew row, last-cup card | Open, discard | Pressable card | Tap; swipe or menu to discard | none | — | P2 | done |
| Search and filters | Type, pick | System search; "No matches" with Clear filters | — | none | Choice remembered | P1 | there |
| Save a brew | Save brew | Button shows a spinner and blocks taps | Tap | Success, or error with the form kept | No double save | P1 | there |
| Saved brew | Read-only until Edit | No steppers or chevrons | Edit button | — | — | P1 | there |
| Rating | Slider plus − / + | Numeric text | Drag tracks the finger; − / + repeat; VoiceOver adjustable | Selection per whole point | — | P1 | there |
| Pull to refresh | — | — | — | — | **n/a**: the journal is local data | — | n/a |

## Beans, Explore, Settings

| Journey | Trigger and intent | Visual | Gesture + alternative | Haptic | States, Reduce Motion | P | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bean row | Swipe to finish or delete, long-press menu | Row leaves, Undo toast | Swipe, menu, VoiceOver actions (Edit, Mark finished, Delete) | Medium on delete, light on status and undo | Toast now announced | P1 | there + done |
| Bean editor | Fields, scan | Keyboard Next walks the fields | Scroll dismisses the keyboard | Success when a scan fills fields | Sheet locked while there are changes | P1 | there |
| Explore cards, roaster rows, flavour chips | Open or toggle | Pressable card | Tap | Selection on a chip toggle | Reduce Motion: dims only | P2 | done |
| Roaster search | Search by city | Skeleton rows, then results or an error with retry | Return key searches | Light tap when saved | Pull to refresh is **n/a**: a search runs only when asked | P1 | there |
| Methods list | Reorder, hide | System drag in the list | Drag; VoiceOver "Move up" / "Move down"; swipe to hide | none | Order saved; a failed save reports | P1 | there |
| Erase all data | Settings → Data | Undo toast | Undo | Success, light on undo | Toast announced | P1 | there + done |
| Remove an AI key | Settings → AI | Confirmation | Buttons | none | Kept as a dialog: the key cannot be brought back | P1 | there |
| Look picker | Tap a look | Pressable card, selection ring | Tap | none | — | P2 | done |
| Onboarding | Chips, Next | Page cross-fade 250 ms | Tap; skippable | Selection on chips, success at the end | Reduce Motion: no fade | P2 | there |

## Across the app

| Item | Status |
| --- | --- |
| One place for haptics (`Feedback`): selection, tap, lift, step change, success, error. No haptic on plain taps, scrolling or navigation | done |
| Motion tokens (`DS.Motion`): 120 ms press, 200 ms exit, 250 ms enter, 0.97 press scale; exits shorter than entrances | done |
| Toasts tell VoiceOver they are there ("Brew deleted. Undo available.") | done |
| Dynamic Type through accessibility sizes, dark mode, Increase Contrast, Reduce Transparency | there |
| Back swipe, sheets with detents, keyboard dismissal on scroll | there |
| Staggered list reveals, arcs, masks, shared-element moves, stretching knobs, custom rubber-banding | n/a: lists are short and already on screen at launch, steppers and sliders are system-shaped, scrolling is the system's. Adding these would be effect for its own sake |
| Pinch or double-tap zoom | n/a: no zoomable content |
| Sound | Only the timer's existing tick, chime and music; nothing added |

## Needs a phone

- How the two-beat step cue feels next to the five-second warning and the finish.
- Haptics in general (the simulator plays none), and the cue with the phone face down or in a pocket.
- Swipe thresholds, the methods drag, and press feel on cards while scrolling.
- VoiceOver speech order during a live brew.
