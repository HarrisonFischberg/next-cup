# REA findings

Sanitized for the app directory: sources are labelled A, B, C and never
named. The source key, raw REA evidence and screenshots stay in the
temporary lab folder until Phase 2B erases it.

Authorized target: three public reference pages named by the owner on
2026-10-21 — Source A (a brew-data website for an iOS journal app: home page,
recipe index, one recipe page), Source B (an App Store listing for an
open-source coffee tracker), Source C (an App Store listing for a guided
brew-timer app with a paid tier).
Authorization and restrictions: public pages only (blocker B003). No login,
no paywall, no app binaries, no script bundles, no private APIs, no cookie
consent given.
Methods used (least intrusive first): REA passive page inspection over a
loopback DevTools connection to an isolated browser with a fresh empty
profile (`list_browser_targets`, `inspect_web_page` with accessibility text,
scoped to each page's own origin, script sources off), and one REA viewport
screenshot. No JavaScript was evaluated and nothing was clicked.

## REA verification

The REA MCP server answered real calls on 2026-10-21. The first two returned
structured errors (`inspect_plist`: no artifact open; `inspect_adb_client`: no
adb binary). `list_browser_targets` then succeeded, followed by five
`inspect_web_page` captures and one `capture_web_screenshot`, all with
confidence "observed".

| # | Observation | Evidence | Verified or inferred | Limitation | Informs |
| --- | --- | --- | --- | --- | --- |
| 1 | Source A is a no-account, local-first journal with optional iCloud sync and full CSV/JSON export | A home page text | Verified (page claims) | Marketing claims, app not run | Data model, export (safeguard 20), positioning |
| 2 | Source A's app uses a four-tab layout: brews, check-ins, coffees, more | A screenshot | Verified (screenshot) | One screen only | Navigation in blueprint |
| 3 | Source A's bean library filters by all / buy again / wishlist and shows each bean's roaster, rating (half steps) and roast-level tag | A screenshot | Verified | — | Bean list screen |
| 4 | Source A's recipes are grouped by style (pour over, immersion, espresso) and each card shows brewer, ratio, dose and water, temperature, total time | A recipe index | Verified | — | Recipe library screen |
| 5 | Source A's recipe pages model a recipe as ordered steps (pour / wait / drawdown), each with a time offset and a cumulative water target, plus a scale-to-dose control and a tuning note | A recipe page | Verified | Web page; app timer not seen | Recipe and step data model, guided timer |
| 6 | Source A's guided timer gives haptic cues and logs the result at the end | A text | Inferred (claim only) | Not observed running | Brew flow F01 |
| 7 | Source A computes extraction yield from a refractometer reading against a standard target window | A text | Inferred (claim) | — | Optional brew-science feature |
| 8 | Source A links tasting notes to origins and processes (a flavor-wheel explorer on the web) | A tool list | Inferred (link text only) | Tool page not opened | Closest prior art to Next Cup's taxonomy |
| 9 | Source A's web analytics load only after consent; the banner offers equal-weight accept and decline | A banner and screenshot | Verified | Consent not given, so loading was not observed | Not applicable to the native app; good pattern if a website is built |
| 10 | Source B lets users customize which parameters each brew method tracks | B description | Inferred (claim) | App not run | Method setup, faster logging |
| 11 | Source B tracks remaining bean stock and can import roaster data by scanning | B description | Inferred | — | Bean stock; bag recognition |
| 12 | Source B has water profiles (mineral content) and home-roast tracking | B description | Inferred | — | Water: could. Roasting: skip |
| 13 | Source B supports Bluetooth scales and pressure devices with live graphs, and writes caffeine to Apple Health | B description | Inferred | — | Device decision (open); HealthKit would add a data flow |
| 14 | Source B's privacy label lists location, usage and diagnostics as not linked to the user; it declares no accessibility features | B listing | Verified | Label is self-reported by the developer | Target privacy label; declare accessibility |
| 15 | Source C gates coffee logs, espresso dial-in, extraction calculator, widgets and Live Activities behind a paid tier | C listing | Verified (listing) | — | Next Cup keeps these free; no paywall |
| 16 | Source C suggests which variable to change from the user's taste rating | C description | Inferred | Rule-based or not is unknown | Dial-in: AI proposals the user accepts |
| 17 | A visible review of Source C says the espresso flow fixes the target output before the shot and cannot record the actual result | C listing, review text | Verified (one review) | One user's view | Always record actual values |
| 18 | Source C declares VoiceOver, larger text, dark interface, sufficient contrast and reduced motion | C listing | Verified (self-declared) | Not tested | Next Cup declares and verifies all five |
| 19 | Source C's privacy label includes data linked to the user (categories shown include contact info, identifiers, user content and financial info) | C listing | Verified that linked data is declared | Text order does not show which categories are linked and which are not | Next Cup aims for "Data Not Collected" |
| 20 | None of the three shows generic buckets (region, roast band, flavor family) driving method or recipe recommendations, AI diagnosis, or paper-journal import | All three pages | Inferred from absence on public pages | Absence on marketing pages is not proof of absence in the apps | Positioning: the taxonomy and matrix are Next Cup's own |

## Limitations of this analysis

- The B and C apps were not run, and their in-app screens were not captured
  (the store screenshot carousels were not read as text). Screen recon for
  B and C is inferred from listing text.
- Feature claims are the developers' own marketing text.
- Store ratings and the two visible reviews are not a sample of users.
  Review research (`/replica-entrepreneur`) has not run yet.
- The browser was a Chromium-based app's binary with a fresh profile, not
  stock Chrome (none is installed). The app opened its own vendor tabs,
  which were outside the inspection scope.

## Blockers / unauthorized paths not taken

- No logged-in or paid states, no app binaries, no script sources or source
  maps, no network endpoint capture.
- Whether the creator video channel from intake belongs in Phase 2 is still
  open with the owner.
