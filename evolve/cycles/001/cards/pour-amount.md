# Timer shows this pour's amount            Flag: exp_pour_amount   Status: PLANNED

**What changes for the user:** On a pour step the timer cue leads with how much to pour now ("Pour 60 g") and keeps the running total second ("to 270 g on the scale"). Today it only says "pour to 270 g", so the user does the subtraction mid-pour.
**Why (evidence):**
- "Because the app wont display the exact weight, the the timing function for the app is useless." - Jaye Kay, Pour-Over Coffee Recipes Timer review, https://apps.apple.com/us/app/id1615750286?see-all=reviews, (Jan 2, year not shown). The same review says the pour animation shows the total weight instead of this pour's amount (research/competitors.md).
- Competitor behavior: Drippe's pour timer gives target water amounts per pour, https://apps.apple.com/app/id1528844321
**Where to see it:** Brew tab > any pour-over recipe > Start brew > a pour step (bloom, pour). Flag on via Settings > long-press Version > Experiments, or `-evolve_all YES`.
**Scope / files:** NextCup/Features/Timer/StepCue.swift (phrase for .bloom and default .pour; `added` is already computed there). Keep moka/drip/cold-brew/bypass phrases as they are (they already say the amount). VoiceOver announcement in TimerView.announce(stepAt:) should say the same thing when on. Live Activity text unchanged this cycle.
**Design:** amount is the primary number in the existing StepCue type; the cumulative target is secondary (ink2). Use RecipeFormat.weight for units (g/oz). No new colours.
**Accessibility:** VoiceOver reads "Pour 60 grams, to 270 grams total". Dynamic Type at accessibility sizes must not truncate.
**Tests:** StepCue unit tests: flag off returns today's exact strings; flag on for bloom, a middle pour, oz units, and a pour with added == 0 (falls back to old phrase).
**Risk / what it does not do:** No timer engine change. Does not track real scale weight.
**Rollback:** delete branch evolve/001/pour-amount; flag removal is one commit.
