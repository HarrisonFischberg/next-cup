# Expected Behaviors Baseline

Source list: the owner's global baseline (`~/.claude/CLAUDE.md`, "Expected
Behaviors Baseline"; the skill's `ux-baseline.md` points to the same list).
Filled 2026-10-24 (T030). Evidence is a file, test name or search of the code at
the head of `build/phase-4f`; "not tested" means the code exists but was not
exercised.

| Item | Status | Reason / evidence |
| --- | --- | --- |
| Drag-to-reorder user-ordered lists, handle, haptic, drop target | PRESENT (partial) | Methods reorder by drag with a non-gesture alternative (T012, `testMethodsAddReorderHideAndShapeTheBrewForm`). Drop haptic and a custom drop target not added (system defaults) |
| Long-press / context menu on items | PRESENT (partial) | `contextMenu` in 4 files (journal, recipes, beans); not every item type has one |
| Swipe actions on rows | PRESENT | `swipeActions` in 3 files; journal and bean delete with Undo (`testJournalLogsFindsEditsAndDeletesABrewWithUndo`, `testBeansAddCorrectFilterAndDeleteWithUndo`) |
| Pull-to-refresh on remote-backed lists | NOT APPLICABLE | No list is backed by remote data; roaster search is on demand |
| Pinch / double-tap zoom on images, maps, canvases | MISSING | Maps zoom natively; brew, bean and paper-import photos have no zoom. Add before release |
| Text fields: dismiss keyboard, Return advances, right keyboard and autofill hints | PRESENT | `scrollDismissesKeyboard` (4 files), `submitLabel`/`keyboardType`/`textContentType` (9 files) |
| Undo toast instead of "Are you sure?" | PRESENT | `SteelToast`; `undoAfterDeleteAllRestoresTheData`. Confirm dialogs appear in 3 files, only for the irreversible step |
| Autosave drafts, never lose typed input | PRESENT | `testBrewFormDraftSurvivesRelaunch`, `testFailedSaveShowsTheErrorAndKeepsTheDraftUntilARetrySucceeds` |
| Shake / Cmd-Z undo, Cmd-Shift-Z redo | MISSING | No `UndoManager`; Undo is toast-based only. Decide whether to add |
| Designed loading, empty, error, offline states per screen | PRESENT (partial) | Empty: journal, roasters, beans; error + retry: roasters (`testRoasterSearchShowsEmptyAndErrorStatesWithARetry`); offline: AI queue status; skeletons in 3 files. Not every screen audited |
| Optimistic UI with rollback message | NOT APPLICABLE | All writes are local and immediate; a failed save keeps the draft and shows the error |
| Haptics on meaningful events only | PRESENT | `sensoryFeedback`/feedback generators in 7 files (step change, pause/resume, finish, save) |
| Button pressed, disabled, in-progress; no double submit | PRESENT | `SteelButton` states (gallery screenshots); Save disabled while saving |
| Search on collections over ~15 items, plus remembered sort/filter | PRESENT | `searchable` in 3 files; bean and journal filters kept in `AppStorage` (not re-checked across a relaunch) |
| Back swipe works; deep links; state restores after relaunch | PRESENT | Native navigation kept; `nextcup://` links (`DeepLink.swift`, UI tests); `SceneStorage`/`AppStorage` in 16 files |
| Keyboard shortcuts and menu-bar commands | MISSING | iPhone only; no `keyboardShortcut`. Low value on iPhone; decide |
| Share sheet, copy, export | PRESENT (partial) | Export through a share sheet in `DataSettingsView.swift`; copy not added |
| Dark mode | PRESENT | Both appearances designed and screenshotted |
| Dynamic Type | PRESENT | Screens reflow at the largest accessibility size (screenshots); timer digits capped at xxxLarge by design |
| Reduce Motion | PRESENT (partial) | `accessibilityReduceMotion` in 5 files (design system, timer); not every transition checked |
| High contrast (Increase Contrast) | NOT TESTED | Not exercised |
| VoiceOver labels, 44 pt targets, non-gesture alternatives | PRESENT (partial) | Labels and an adjustable grade control in code; 44 pt targets in the design system; VoiceOver never run |
| Safe areas, landscape / iPad / resizable windows | PRESENT (partial) | Safe-area insets used; iPhone portrait only by decision, so landscape and iPad are NOT APPLICABLE |
| System language, locale, units | PRESENT (partial) | Units setting (g/oz, °C/°F) applies everywhere; no localization (no string catalog), English only. Decide before release |
| Notifications opt-in in context | NOT APPLICABLE | The app sends no notifications |
| Settings: data export, account deletion, privacy controls | PRESENT | Export and delete-all; no accounts so no account deletion; privacy summary in Settings |
| Animations 150 to 300 ms, interruptible, spring for physical moves | NOT TESTED | Durations are 100 to 400 ms in the design system; not measured |
| Onboarding skippable and under 3 screens | NOT APPLICABLE | None built; first run goes straight to the journal. The AI disclosure gates only AI |
| Sensible defaults: remember last-used choices, prefill, never ask twice | PRESENT | Brew again prefill (T011), remembered filters, unit settings |

Missing without a decided reason (these block Gate A until decided or built):
photo zoom, shake/Cmd-Z undo, localization, keyboard shortcuts.
