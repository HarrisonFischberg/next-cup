# Rating trend for a bean            Flag: exp_bean_trend   Status: PLANNED (bigger swing)

**What changes for the user:** Bean detail gets a small Swift Charts line of the ratings of that bean's brews over time (one dot per rated brew, best brew marked), with the average and spread in one line ("avg 7.6 · range 6.8-8.8 · 7 brews"). Shows dialing in converging.
**Why (evidence):**
- "Distribution of brew scores for every time a bean was brewed (mean as well as distribution because consistency is important)" - tokenstar, Beanconqueror #187, https://github.com/graphefruit/Beanconqueror/issues/187, 2021-03-27
- "The only thing I am missing - which currently leads to double usage of excel + app - is to have custom charts/statistics in the app." - sebastian-tischer, Beanconqueror #156, https://github.com/graphefruit/Beanconqueror/issues/156, 2021-01-11
- "I would add some graphs or charts they compare the same brewers" - B Interface, Coffee Book, https://apps.apple.com/app/id1512681263?see-all=reviews, 2021-03-30
- Competitor: Dialed In trend charts, https://apps.apple.com/app/id6759168523
**Where to see it:** Beans tab > a bean with 2+ rated brews (demo: `-demoBrews`) > under Best so far.
**Scope / files:** NextCup/Features/Beans/BeanDetailView.swift (one insertion) + new BeanTrendChart.swift. Swift Charts is a system framework (no new dependency). Read-only.
**Design:** accent line, ink2 axis, no gridline clutter, look radius. Hidden with fewer than 2 rated brews.
**Accessibility:** .accessibilityChartDescriptor (audio graph) plus a text summary; Reduce Motion: no draw-in animation.
**Tests:** unit test the summary stats (0/1/2/n rated brews, unrated ignored).
**Risk / what it does not do:** no cross-bean or grind-vs-rating chart this cycle.
**Rollback:** delete branch evolve/001/bean-trend; flag removal is one commit.
