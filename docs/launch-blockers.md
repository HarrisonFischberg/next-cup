# Launch blockers

| # | Blocker | Type (missing fact / failed check / legal review / approval) | Owner | Needed for | Status |
| --- | --- | --- | --- | --- | --- |
| B001 | GitHub org name for the repo | missing fact | Owner | Phase 1 repo creation | RESOLVED for now: private repo created under HarrisonFischberg 2026-10-21; move to an org and flip public (owner's stated plan) only on explicit approval |
| B002 | Ralph quickstart not cloned; `/goal` not yet verified (REA verified 2026-10-21 by real calls, see `docs/rea-findings.md`) | failed check | Builder | Phase 4 (Ralph, `/goal`) | RESOLVED 2026-10-21: quickstart cloned and reviewed, own `ralph/ralph.sh`, `/goal` command exists; turn-bound enforcement unverified (see `ralph/REVIEW.md`) |
| B003 | Authorization to analyze the three reference products: public pages and store listings only, no login or paywall bypass | approval | Owner | Phase 2 | Owner supplied the three URLs 2026-10-21; analysis kept to public pages. Confirm at the comparison stop |
| B004 | Creator recipe import: confirm the source list, store parameters only with credit and links, check each source's terms | legal review | Owner | Feature build | OPEN |
| B005 | Privacy policy and support URL (candidate host: rarecreatures.app) | approval | Owner | TestFlight external testing | OPEN |
| B006 | Draft privacy policy and AI-provider disclosure for qualified review | legal review | Owner | TestFlight external testing | OPEN |
| B007 | Best-of comparison approval before the final spec is written | approval | Owner | Phase 2 final spec, 2B | RESOLVED 2026-10-21: owner approved the comparison as written (Bluetooth scales stay deferred); review findings get folded in as additions |
| B008 | Public review research (`/replica-entrepreneur`) on the three references not yet run | missing fact | Builder | Comparison stop | RESOLVED 2026-10-21: 151 items (50 App Store reviews of one reference, 99 public issues of another, 2 HN comments); no reviews exist for the third (0 ratings); Reddit skipped (official API needs a registered app). Fix plan X1–X8 and angle options in the lab |
| B009 | Does the creator video channel from intake belong in Phase 2 research? | missing fact | Owner | Phase 2 | RESOLVED 2026-10-21: owner chose to study it when creator-recipe import is built (see B004), not in Phase 2 |
| B010 | Reference recon used a Chromium-based app binary with a fresh profile because stock Chrome is not installed; in-app screens of two references not captured | failed check | Builder | Recon completeness | ACCEPTED limitation, noted in `docs/rea-findings.md` |
| B011 | Blueprint and task plan (`docs/blueprint.md`, `prd.md`) need owner approval before Phase 3B | approval | Owner | Phase 3B, 4 | RESOLVED 2026-10-21: owner approved (PR #1) |
| B012 | T026 Live Activity: no Lock Screen or Dynamic Island screenshots, and the tap-to-open-timer and end-with-brew behavior were never exercised on a running activity. The simulator tool here cannot lock the device or tap a Live Activity | failed check | Owner (a manual pass on the simulator or a device) | T026 acceptance, Gate A | RESOLVED 2026-10-24 by a supervised simulator pass (see activity.md); gaps listed there |
| B013 | T030 safeguards and UX baseline pass cannot be verified against the code: `grep`, `git` and compound shell commands are denied approval in the Ralph session | failed check | Owner (permission change) | T030, Gate A | RESOLVED 2026-10-24: T030 done in a supervised session; owner items remain (rows 1, 2, 12, 16, 17 of the checklist) |

## ASSUMED answers (skipped or interpreted at intake)

| Q | Assumed value | Alternatives offered |
| --- | --- | --- |
| 4 | Best-of merge of the three references, refined by public reviews | Source C-style simplicity first; Source B-style depth first; reviews-only research |
| 10+ | AI calls go direct from the device with the user's own key; no backend | Thin proxy backend that holds no keys |
| 12 | "No budget" means $0 for paid services beyond the Apple developer account | Any paid service needs separate approval |
| 16 | "Shared database" means one shared taxonomy and database inside the app, with a curated bundled reference dataset; no user-to-user sharing | A server-backed shared database (conflicts with the no-accounts, no-backend, and social-out-of-scope answers) |
| 16 | "Social component for local roasters" means local roaster discovery (MapKit search, saved favorites); no profiles, feeds, or sharing | Real social features (reverses the out-of-scope answer) |
| 16 | Paper-journal import shows a review screen before saving | Save blind (rejected: handwriting recognition errors) |

## Unknown business and legal inputs

Never infer these from a reference app. Never invent them.

- Legal entity and trading name: UNKNOWN
- Business location: UNKNOWN
- Launch countries/states: UNKNOWN (TestFlight beta; no store launch planned)
- Public business contact: UNKNOWN
- Privacy contact: UNKNOWN
- Minimum user age / children may use: UNKNOWN
- Pricing, billing, trials, renewal: none (free, no ads), per intake
- Refund and cancellation terms: not applicable while free
- Data types and sensitive data: brew logs, tasting notes, photos of coffee, bags and handwritten pages, optional coarse location for roaster search; no health or kids' data expected
- Vendors, SDKs, analytics, AI providers, processors: OpenAI and Anthropic, only when the user adds their own key; Apple MapKit for roaster search; YouTube and creator sites for recipe import (to be confirmed); no analytics or ads SDKs
- Retention or deletion exceptions: UNKNOWN

## Jurisdiction (Phase 2 discovery, 2026-10-21)

Needs authoritative research or qualified review; not treated as universal:

- Apple App Store and TestFlight rules: privacy nutrition label, App Privacy
  Details, account-deletion rule (not triggered: no accounts), external
  beta review for TestFlight. Applies regardless of country.
- Launch countries: UNKNOWN (B005/B006). If TestFlight testers are in the
  EU/UK, GDPR/UK GDPR transparency applies to any processing the developer
  controls; AI calls go from the device to the user's chosen provider with
  the user's own key, and who acts as controller there needs review.
- US state privacy laws (for example California): likely below thresholds
  for a free portfolio app with no collection, but needs confirmation once
  launch countries are known.
- Children: minimum age UNKNOWN; COPPA only if directed at children (not
  expected).
- Health data: only if Apple Health caffeine export is adopted (candidate
  from discovery); would need its own review.
- Creator recipe import: copyright and each platform's terms (B004).

## Owner answers, 2026-10-25

| Item | Answer | Effect |
| --- | --- | --- |
| Legal entity / trading name | Rare Creatures LLC | Used in the policy and the checklist; no other entity details assumed |
| Public contact and privacy contact | hello@rarecreatures.app | Used in the policy |
| Website / support host | rarecreatures.app (existing studio site) | Policy and support page not published; URL not final |
| Business address, state of formation | Not given | Still UNKNOWN; needed if Apple or the EU asks for a trader address |
| Minimum age | "any age" | Not directed at children; no personal data collected, so no age gate. App Store age rating to be set by the owner (expected 4+); no COPPA collection to disclose |
| Privacy policy | Reuse and adapt the owner's existing policies for Next Cup | Written in `docs/legal/PRIVACY.md` in the style of the Keepsake policy; still unreviewed by a lawyer |
| Hands-on VoiceOver, real AI call, real location prompt | "I don't think we need any of this" | Recorded as NOT TESTED, accepted by the owner; not claimed anywhere |
| Photo zoom, shake-to-undo | Not needed; an undo button is enough | Closed as decided (Undo toasts exist) |
| Localization, keyboard shortcuts | Later | Deferred, recorded |
| Bean photo | Must match a real bean company and use that company's information | New task T031 |
