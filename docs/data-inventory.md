# Data inventory

Planned flows, recorded at intake (2026-10-21). Nothing is built yet; each row
is verified against the code in Phase 5.

| Data collected | Purpose | Collection point | Recipient / storage | Retention | Deletion mechanism |
| --- | --- | --- | --- | --- | --- |
| Brew logs, tasting notes, grades, recipes | Journal and dial-in | User entry | On device (SwiftData) | Until user deletes | Delete item; delete all data in Settings |
| Photos of coffee, bags, handwritten pages | AI analysis, bag recognition, paper import | Camera or photo library, only on tap | On device; sent to the user's chosen AI provider only when the user triggers analysis | On device until deleted; provider retention per its own terms | Delete item; remove key to stop all AI calls |
| User's OpenAI or Anthropic API key | Authenticate AI calls | Settings | iOS Keychain, device only | Until removed | Remove key in Settings; never logged or backed up |
| Prompts built from notes, past brews, photos | AI insights and suggestions | User triggers | OpenAI or Anthropic (user's choice) | Provider's retention | Not controllable by the app; disclosed before the first AI call |
| Coarse location (planned) | Local roaster search | Location prompt, while in use, on demand | Apple MapKit local search; not stored | Not stored | Revoke permission in iOS Settings |
| Creator recipe parameters (planned) | Recipe library with credit and links | Import by the user | On device | Until deleted | Delete recipe |
| iCloud sync (optional, later) | Cross-device journal | User opt-in | Apple CloudKit private database | Until deleted | Turn off sync; delete all data |

## Phase 2 discovery: candidate flows (2026-10-21)

The references point to these possible data flows. None is adopted yet. Each
needs a decision in the blueprint and then a row in the table above.

| Candidate | Seen in | Data and recipient if adopted | Note |
| --- | --- | --- | --- |
| Bluetooth scale (live weight, flow, saved curve) | Sources A, B, C | Weight time series, on device only; Bluetooth permission | Open decision in PRODUCT.md |
| Caffeine written to Apple Health | Source B | Caffeine amounts to HealthKit (Apple, on device) | Adds health-category data and a permission; default no |
| CSV / JSON export of every field | Source A | User-chosen destination via share sheet | Recommended: supports data portability (safeguard 20) |
| Import from another journal app's export | Source A | File the user picks, parsed on device | Could |
| Water profiles (mineral content) | Source B | On device | Could |
| Café check-ins with location | Source A | Place and date on device; MapKit search | Narrower than intake's roaster search; decide in blueprint |
| Live Activity / widgets for the brew timer | Source C | Timer state on device | No new recipient |

Discovery inventory for the current repository: no app code exists yet, so
there are no routes, SDKs, cookies, storage, emails, fonts or licenses to
inventory. Rerun this section in Phase 5 against the built code.

## Phase 3 blueprint decisions (2026-10-21)

Pending owner approval of `docs/blueprint.md` §6.

| Candidate | Decision |
| --- | --- |
| Bluetooth scale | Deferred (owner) |
| Caffeine to Apple Health | Not adopted |
| Café check-ins with location | Not adopted; only roasters the user saves |
| CSV / JSON export and merge import | Adopted (T019) |
| Automatic local backup (Application Support, keep 7) | Adopted (T019); included in the user's iCloud device backup per iOS settings; Keychain keys excluded |
| Water profiles | Could (T029), on device |
| Live Activity | Adopted (T026); timer state only |
| Photo metadata | EXIF and GPS stripped before storing or sending (T009) |
| Third-party SDKs | None |
