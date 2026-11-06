# Backlog, cycle 001 (scored 2026-11-06)
Scores: evidence (0-3), impact (0-3), effort fit ~40 min (0-3), identity fit (0-3).

## Picked
| # | Idea | Flag | Ev | Imp | Fit | Id | Total | Why |
|---|---|---|---|---|---|---|---|---|
| 1 | Timer shows this pour's amount | exp_pour_amount | 2 | 3 | 3 | 3 | 11 | top timer complaint; StepCue already has `added` |
| 2 | Last time with this bean at setup | exp_last_time_note | 2 | 3 | 3 | 3 | 11 | feeds the core "next cup" loop |
| 3 | Coffee on hand across open bags | exp_beans_on_hand | 3 | 2 | 3 | 2 | 10 | two direct asks; pure read |
| 4 | Bean menu with grams left + freshness | exp_bean_picker_detail | 2 | 2 | 3 | 2 | 9 | polish |
| 5 | Rating trend per bean (Swift Charts) | exp_bean_trend | 3 | 2 | 2 | 3 | 10 | the one bigger swing |
Mix: 2 polish (3, 4), top complaint (1), one bigger swing (5). Files: 1 Timer/StepCue; 3 Beans/BeanLibraryView; 5 Beans/BeanDetailView; 2 and 4 both RecipeDetailView but different regions (2 inserts below beansRow, 4 edits beansRow); build 2 before 4.

## Next up (6-10)
6. Back one step in the timer (Skip exists; no Back). Ev: samtsai, Timer.Coffee #69, https://github.com/antonkarliner/timer-coffee/issues/69. Touches the timer engine and Live Activity; ~60 min.
7. Confirm an unclear roast date after a bag scan (Timer.Coffee pattern).
8. Freshness / running-low reminder notification (new notification type: decide first).
9. Monthly review card in Journal (Timer.Coffee, Hanko palate graph).
10. Story share card for a brew (Hanko, Drippe 9:16).

## Already in the app (verified in code, not candidates)
Brew again (journal swipe/context menu/Siri), editable brew date (BrewFormView DatePicker), freshness + roast age + grams left on bean rows and detail, undo toasts, chime + haptic 5 s before a step, keep-awake timer, Live Activity, skip step, steppers, journal filter/sort incl. highest rating, taste reminder notification, Best-so-far card.

## Needs Harold's decision (touch a contract or a new target)
- Home/Lock Screen widget or Control Center "start my usual brew" (new widget target).
- Apple Watch companion (new target; 3 Filtru reviewers ask).
- Recipe sharing by link/QR (deep link + import contract).
- iCloud sync (persisted data contract).
- App Store listing: subtitle/keywords lack "pour over", "V60", "AeroPress", "recipes"; listing seller shows "Harrison Fischberg", not Rare Creatures LLC (listing work, not app code).

## UX baseline audit
Against new-app ux-baseline.md: present for swipe actions, context menus, undo toasts, autosave drafts, search/sort/filter remembered, empty/error states, dark mode, Dynamic Type, Reduce Motion, notifications asked in context, export/delete data, skippable onboarding. No new table-stakes gaps found worth a slot this cycle.
