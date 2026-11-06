# Bean menu shows grams left and freshness            Flag: exp_bean_picker_detail   Status: PLANNED

**What changes for the user:** In Recipe setup's Beans menu each bag shows its grams left and freshness ("Hair Bender · Stumptown — 180 g · Peak"), ordered least left first so the bag to finish is on top. Today it is name order with name and roaster only.
**Why (evidence):**
- "the list should be sorted by Amount Left." - adamulacha, Timer.Coffee #79 (bean picker during brew), https://github.com/antonkarliner/timer-coffee/issues/79, 2026-06-12
- "Currently the consumed and remaining amounts only show on beans list view—would be great if this showed (or was an option to show) in detail view" - b-dod, Beanconqueror #1015, https://github.com/graphefruit/Beanconqueror/issues/1015, 2026-01-01
**Where to see it:** Brew tab > a recipe > Recipe setup > Beans row menu (demo: `-demoBeans`).
**Scope / files:** NextCup/Features/Recipes/RecipeDetailView.swift, beansRow and the `beans` ordering only. Reuse BeanText.freshnessLine / stockLine wording. Untracked amounts sort after tracked ones, then by name. Default pick (first bean) must stay the same with flag off.
**Design:** Menu buttons with a subtitle (Button with Text + secondary Text), no new colours.
**Accessibility:** VoiceOver reads name, roaster, grams left, freshness.
**Tests:** unit test the ordering helper. Flag off: same order and labels as today.
**Risk / what it does not do:** does not change which bean is auto-picked on first open when flag is off; with flag on the auto-pick follows the new order (called out in the report).
**Rollback:** delete branch evolve/001/bean-picker-detail; flag removal is one commit.
