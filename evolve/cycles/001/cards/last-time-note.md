# "Last time with this bean" at recipe setup            Flag: exp_last_time_note   Status: PLANNED

**What changes for the user:** On Recipe setup, once a bean is chosen, a small card shows the last brew of that bean: date, rating, taste verdicts, grind, and the first line of its notes (plus the pending dial-in suggestion if there is one). Tapping it opens that brew. So the note you wrote yesterday "pops up" before today's brew.
**Why (evidence):**
- "My only wish is for there to be an option to leave a note for the next brew that pops up" - BenMEight, Beanconqueror, https://apps.apple.com/au/app/beanconqueror/id1445297158?see-all=reviews, 2025-08-20
- "it would be great to see deviations from the recipe" - kbizz12, Coffee Book, https://apps.apple.com/app/id1512681263?see-all=reviews, 2025-07-12
**Where to see it:** Brew tab > a recipe > Recipe setup, with a bean that has at least one brew (demo: `-inMemoryStore -demoBrews`).
**Scope / files:** NextCup/Features/Recipes/RecipeDetailView.swift (insert under beansRow) + a new LastTimeCard view file. Read-only: latest non-draft Brew among bean.brewUses. Prefer a brew on this method when one exists. Do not touch beansRow (exp_bean_picker_detail edits it).
**Design:** KraftNote-style or PaperBox per DESIGN.md; notes in DS.Font.note; verdict chips as existing tags. Hidden when no prior brew. One accent at most.
**Accessibility:** VoiceOver reads it as one button "Last time, 3 days ago, rated 7.8, a bit sour. Note: grind finer". 44 pt target.
**Tests:** unit test the "which brew" selection (same method preferred, drafts skipped, none). Flag off: setup unchanged.
**Risk / what it does not do:** does not change the recipe or grind (grind recall already exists).
**Rollback:** delete branch evolve/001/last-time-note; flag removal is one commit.
