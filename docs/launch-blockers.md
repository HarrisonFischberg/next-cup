# Launch blockers

| # | Blocker | Type (missing fact / failed check / legal review / approval) | Owner | Needed for | Status |
| --- | --- | --- | --- | --- | --- |
| B001 | GitHub org name for the repo | missing fact | Owner | Phase 1 repo creation | RESOLVED for now: private repo created under HarrisonFischberg 2026-10-21; move to an org and flip public (owner's stated plan) only on explicit approval |
| B002 | Ralph quickstart not cloned; `/goal` and REA calls not yet verified | failed check | Builder | Phase 2 (REA) and Phase 4 (Ralph, `/goal`) | OPEN |
| B003 | Authorization to analyze the three reference products: public pages and store listings only, no login or paywall bypass | approval | Owner | Phase 2 | ASSUMED from intake, confirm at the comparison stop |
| B004 | Creator recipe import: confirm the source list, store parameters only with credit and links, check each source's terms | legal review | Owner | Feature build | OPEN |
| B005 | Privacy policy and support URL (candidate host: rarecreatures.app) | approval | Owner | TestFlight external testing | OPEN |
| B006 | Draft privacy policy and AI-provider disclosure for qualified review | legal review | Owner | TestFlight external testing | OPEN |

## ASSUMED answers (skipped or interpreted at intake)

| Q | Assumed value | Alternatives offered |
| --- | --- | --- |
| 4 | Best-of merge of the three references, refined by public reviews | Filtru-style simplicity first; Beanconqueror-style depth first; reviews-only research |
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
