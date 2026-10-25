# Data inventory

Flows recorded at intake (2026-10-21) and verified against the code in Phase 5.
The table directly below is the intake plan; "Current flows" at the end of this
file is the refreshed list that matches the code (T034).

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

Discovery inventory at intake: no app code existed, so there was nothing to
inventory. It was rerun against the built code in Phase 5 (see the verified and
current-flow tables below).

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
| AI keys (T021) | Keychain generic-password items, `WhenUnlockedThisDeviceOnly`, service `app.rarecreatures.nextcup.ai`; cleared by delete all; no network call made yet |
| AI disclosure version and per-feature provider/model IDs (T021) | `UserDefaults` only; contain no secrets |
| Paper import (T025) | Photo of a journal page chosen with `PhotosPicker` (no library permission). Text is read on device by Apple Vision with no network. Only on an explicit tap of "Read with my AI key" is the metadata-stripped photo sent to the user's chosen provider (existing OpenAI/Anthropic rows). The page photo is kept on the saved brew only after the user confirms; nothing is stored before that |

## Verified against the code (T030, 2026-10-24)

Checked by search of `NextCup`, `NextCupLiveActivity` and `Packages/NextCupKit/Sources` on `build/phase-4f`.

| Item | Result |
| --- | --- |
| Third-party SDKs | None. The project references only the local `NextCupKit` package; imports are Apple frameworks |
| Analytics, crash reporting, ads, tracking | None found; `PrivacyInfo.xcprivacy` added: no tracking, no collected data |
| Network endpoints | Only `api.anthropic.com` and `api.openai.com` in `AIClient.swift`, reached through `URLSessionTransport`; MapKit search is Apple's service |
| Required-reason APIs | `UserDefaults` only (reason CA92.1); no file-timestamp, disk-space or uptime APIs found |
| Permissions | Location when in use (string in `Config/NextCup-Info.plist`); photos via `PhotosPicker` (no permission); no camera, contacts, microphone, Bluetooth or notifications |
| Logging | No `print`, `NSLog`, `os_log` or `Logger` in app code |
| Planned flows not built | Bluetooth scales, Apple Health, iCloud sync, creator-recipe import: none present in code |
| Not verified | Runtime network capture; widget extension has no privacy manifest (no required-reason API found); on-device backup contents were not inspected beyond tests |

## Current flows (T034, 2026-10-24)

Refreshed against the code on `build/phase-5`. Replaces the "nothing built yet" wording above.

| Data | Where it lives or goes | Retention | Removed by |
| --- | --- | --- | --- |
| AI request log (`AIRequest`: feature, provider, model ID, status, payload, attached photo, result, error) | On device, SwiftData; the payload and photo go to the user's chosen provider only on a tap | Payload and photo are emptied when a request ends, fails or is cancelled (T032); the result and status stay with the brew | Delete the brew (cascade); delete all data |
| Export files (JSON and CSV, all journal fields, photos in JSON) | `tmp/NextCupExport`, created only when the user taps Export | Removed when the share sheet closes | Closing the sheet; delete all data empties `tmp` |
| Automatic backups | Application Support/Backups, complete file protection, newest 7 | 7 days of files | Delete all data |
| Brew-form drafts | Application Support/Drafts, complete file protection | Until the brew is saved or discarded | Delete all data |
| Timer snapshot (start time, pauses, recipe) | On device so a relaunch restores a running brew | Until the brew ends | Delete all data (preferences domain cleared) |
| Live Activity content (recipe name, method name, current and next step, start and end dates, `nextcup://` link) | Lock Screen and Dynamic Island on this device; no push token, no server | Until the brew ends or the user dismisses it | Delete all data ends a running activity |
| Typed city or map region for roaster search | Sent to Apple MapKit local search as the search text and region; the app keeps no copy | Apple's terms | Not stored by the app |
| Reduced-accuracy location | `NSLocationDefaultAccuracyReduced` asks iOS for approximate location; used once per search, not stored | Not stored | Revoke permission in iOS Settings |
| Saved roaster name, city, website, coordinates | On device (`Roaster`), only for roasters the user chose to save | Until deleted | Delete the roaster; delete all data |
| Photos and AI attachments stored outside the database | SwiftData external-data folder next to the store | While the owning row exists | Delete all data empties the folder |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO`: only Apple's standard HTTPS to the two AI providers | n/a | n/a |

## Corrections after the second Opus pass (2026-10-25)

These supersede older rows above where they disagree:
- No camera is used; photos come from the system photo picker only. Brew photos are never sent to AI; bag, coffee and journal-page photos are, on a tap.
- AI requests: the photo and request text are removed when a request ends; the answer to a bag or journal-page photo is removed once the screen has used it; diagnosis and insights answers become suggestions stored with the brew.
- Drafts use the default file protection (until first unlock) on purpose, so a draft saved as the phone locks is not lost; backups use complete file protection.
- The privacy manifest declares Photos or Videos and Other User Content as collected (App Functionality, not linked), not "no data".
- Roaster match sends Apple the roaster name plus "coffee roaster" and nothing else.
- Network calls exist (AI providers, Apple Maps search); older text saying none were made is out of date.
