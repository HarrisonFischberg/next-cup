# Coffee on hand across open bags            Flag: exp_beans_on_hand   Status: PLANNED

**What changes for the user:** The top of the Beans tab shows one line: total coffee left across bags In use (and roughly how many brews that is at the user's usual dose), e.g. "420 g on hand · 3 bags · about 26 cups". Decaf share shown when any decaf is open.
**Why (evidence):**
- "Sometimes I have a few opened packs of coffee and would like to know how much I have in total (to know when to order a new coffee)." - adamulacha, Timer.Coffee #78, https://github.com/antonkarliner/timer-coffee/issues/78, 2026-06-08
- "It whould be great to have seperate information on the dashboard how much coffee is left and how much of that is decaf" - alclonky, Beanconqueror #1032, https://github.com/graphefruit/Beanconqueror/issues/1032, 2026-01-23
- Competitor: Coffee Book lets Siri answer "how much is left?", https://apps.apple.com/app/id1512681263
**Where to see it:** Beans tab, under the page header, above the list.
**Scope / files:** NextCup/Features/Beans/BeanLibraryView.swift (new small summary view; can live in its own file). Read-only: sums Bean.remainingG for status .inUse where tracked; "about N cups" uses the median doseG of the last 10 brews (hide if fewer than 3 brews). Bags with untracked amounts are counted as "1 bag not tracked".
**Design:** one PaperBox/ReadoutTile row from DESIGN.md, monospaced digits, accent for the number only. Hidden when no bag is in use.
**Accessibility:** single combined VoiceOver element; reflows at accessibility sizes.
**Tests:** unit test the summary math (0 bags, untracked bag, decaf, oz units, fewer than 3 brews).
**Risk / what it does not do:** no reminders or notifications (that would be a new notification type).
**Rollback:** delete branch evolve/001/beans-on-hand; flag removal is one commit.
