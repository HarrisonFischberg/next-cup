# Data inventory

Flows recorded at intake (2026-10-21) and verified against the code in Phase 5.
The table directly below is the intake plan; "Current flows" at the end of this
file is the refreshed list that matches the code (T034).

| Data collected | Purpose | Collection point | Recipient / storage | Retention | Deletion mechanism |
| --- | --- | --- | --- | --- | --- |
| Brew logs, tasting notes, grades, recipes | Journal and dial-in | User entry | On device (SwiftData) | Until user deletes | Delete item; delete all data in Settings |
| Taste reminder (bean name, brew id in a `nextcup://taste/<id>` link) | Remind the user to taste a brew 20 minutes after saving it untasted | Brew form save | Local notification scheduled on device (`UNUserNotificationCenter`); nothing leaves the iPhone | Until it fires or the brew is tasted | Tasting cancels it; notifications can be turned off in iOS Settings |
| Photos of coffee, bags, handwritten pages | AI analysis, bag recognition, paper import | Camera or photo library, only on tap | On device; sent to the user's chosen AI provider only when the user triggers analysis | On device until deleted (a bag photo read while adding a bean stays on that bean, never re-sent); provider retention per its own terms | Delete item, or Remove photo in the bean editor; remove key to stop all AI calls |
| User's OpenAI or Anthropic API key | Authenticate AI calls | Settings | iOS Keychain, device only | Until removed | Remove key in Settings; never logged or backed up |
| Send Debug Logs (2026-11-08): the note typed under "What went wrong?", app version and build, iPhone model, iOS version, language, and the error and fault lines the system logged for this launch (Apple frameworks included; private values stay redacted as `<private>`) | Let the user report a problem to support | Settings > "Send Debug Logs to support@rarecreatures.app" | A draft in the user's own email app, addressed to support@rarecreatures.app, which the user can read and edit and which is sent only if they tap Send there (copied to the clipboard instead if no email app opens). The app itself sends nothing. While typed, the note is kept in UserDefaults (`supportDraft`) | Note: until the draft opens. Email: in the owner's mailbox until deleted | Clear the field; ask support to delete the email |
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
| Brew size tuning | Setting an amount in "How much coffee?" on Start brew, then tapping "Tune time, temperature and grind with <provider>", sends the recipe name, brewer, recipe and new dose, water, temperature and time (numbers only, no notes or photos) to the provider chosen in Settings → AI, only after its disclosure (version 3, which lists this) was accepted. With no key Apple's on-device model answers as the wheel settles, with no tap, because nothing leaves the iPhone; with neither nothing is sent. Changed 2026-10-30: before, a keyed provider was asked as soon as the wheel settled, with no tap. The answer (temperature, time, grind, a note) is kept in memory for that page only |
| Recipe review ("Improve with AI") | In the recipe editor (also opened by "Change steps" on Start brew), tapping "Improve with AI" sends the recipe name, brewer, the name of the grinder used last (with the bundled guide's range for it, when known), dose, water, ice, temperature, total time, every step (kind, start time, running water, instruction) and the optional note typed above the button to the provider chosen in Settings → AI, only after its disclosure (version 6, which lists this) was accepted; when the disclosure is not yet accepted, the tap shows it first instead of falling back. With no key Apple's on-device model answers on the iPhone, also only on the tap; with neither the button is off and nothing is sent. No beans, brews or photos. The answer (summary, changes, steps, temperature, time, a grind to start at) is held in memory and changes nothing until "Use these steps", which also writes the grind into the tuning note; the recipe is stored only when the user taps Save. Added 2026-10-30 |
| Recipe creation ("Create with AI") | From the + on the Brew tab, tapping "Create recipe" sends the brewer picked (name and style), the grinder picked or typed (with the guide's range for it, when known) and the text typed to the same provider, under the same disclosure (version 7) and the same Apple fallback. With a keyed provider, a first request sends the same brewer, grinder name and text with the provider's web search tool (Anthropic `web_search`, OpenAI `web_search`, at most 3 searches, billed to the user's key); the provider runs the searches and the sites see the provider, not the phone. Its summary goes into the recipe request and the pages it cites (from the provider's citations only) are written into the tuning note as sources. Apple's model cannot search, so it skips this step. No beans, brews, photos or other recipes. The answer, with the grind in its tuning note, opens in the recipe editor and is stored only when the user taps Save. Added 2026-10-30; grinder added 2026-10-31; web research added 2026-10-31 |
| Next Cup ("Ask AI for Next Cup") | On a past brew, the long-press item or the saved-brew button sends that brew and the user's similar past brews to the provider chosen in Settings → AI, only after its disclosure (version 10, which lists this) was accepted; with no key Apple's on-device model answers on the iPhone. Sent: date, method, recipe name and every step, bean name, roaster, roast, origin, process and bag flavors, dose, water, ice, grinder (with the guide's range) and grind, temperature, time, taste, rating and the user's notes, plus up to 8 of the user's other brews with the same method (same bean first, then dose and water within 20%, then the rest; newest first in each; 4 with notes cut to 120 characters on Apple's model, notes cut to 240 otherwise), each with its date, recipe name, bean name, roaster and roast, dose, water, ratio, grinder and grind, temperature, time, taste, rating and notes. No photos. With a keyed provider a first request runs its web search with the brewer, grinder, roast and taste only (never the bean's name or the notes), at most 3 searches billed to the user's key. The checked answer is saved on device as the recipe "Next Cup" (one per method, replaced on the next ask), with the changes and any cited pages in its tuning note. Added 2026-11-01; similar brews added and the separate "Get one AI tip" sheet on a saved brew removed the same day |
| Next Cup on save (automatic) | Saving a brew with a taste or rating (brew form, or the taste reminder screen), when it is the newest brew of its method and its taste, rating or notes changed, runs the same request as "Ask AI for Next Cup" with no further tap and writes the answer straight to the method's "Next Cup" recipe on the Brew tab. Same fields and provider as the row above, and the same web search; the other brews are narrowed to already rated or tasted brews with the same method and dose and water within 20% (up to 8, or 4 on Apple's model). Runs only with a key whose disclosure (version 10, which lists this) was accepted, or Apple's on-device model; with a key and the notice not accepted nothing is sent and the Brew tab offers the notice. Off with Settings → AI → "Write my Next Cup when I save a brew" (`ai.nextCup.auto`, on by default). Each save may cost the user's key one request plus up to 3 searches. The waiting brew's id is kept in `UserDefaults` (`ai.nextCup.pendingBrew`) until answered, and is cleared on erase. Added 2026-11-02 |
| Brew advice for a bean | After a bag photo, barcode or QR scan fills a new bean and it is saved from the Beans tab, and from "Brew advice" on any bean's page: the user picks or types how they want it to taste (or taps "Just recommend 3"), and one request goes to the provider chosen in Settings → AI, only after its disclosure (version 11, which lists this) was accepted; with no key Apple's on-device model answers on the iPhone. Sent: the bean's name, roaster, roast, origin, process and bag flavors, the taste goal text (up to 300 characters), the names and styles of the user's shown brewers, and the last-used grinder's name and settings range. No photos, brews or notes, and no web search. The answer (3 ranked recipes) is held in memory; only the one the user taps Start brew on is saved on device as a recipe credited "AI, for your taste" (starting the same pick again replaces it). Added 2026-11-06 |
| Brewer size in recipe requests | The size of the brewer picked for each built-in method (asked the first time an AI recipe is made for it, editable in Settings → Brewer sizes; the most common size when skipped or never asked) and how much water it holds are added to Improve with AI, Create with AI, Ask AI for Next Cup, the automatic Next Cup and brew advice requests, so recipes never overfill it. Sent to the same provider as the rest of the request, only after its disclosure (version 12, which lists this) was accepted; with no key Apple's on-device model answers on the iPhone. The choice itself is stored in `UserDefaults` (`brewer.size.<method>`). Added 2026-11-09 |

## Verified against the code (T030, 2026-10-24)

Checked by search of `NextCup`, `NextCupLiveActivity` and `Packages/NextCupKit/Sources` on `build/phase-4f`.

| Item | Result |
| --- | --- |
| Third-party SDKs | None. The project references only the local `NextCupKit` package; imports are Apple frameworks |
| Analytics, crash reporting, ads, tracking | None found; `PrivacyInfo.xcprivacy` added: no tracking, no collected data |
| Network endpoints | Only `api.anthropic.com` and `api.openai.com` in `AIClient.swift`, reached through `URLSessionTransport`; MapKit search is Apple's service |
| Required-reason APIs | `UserDefaults` only (reason CA92.1); no file-timestamp, disk-space or uptime APIs found |
| Permissions | Location when in use (string in `Config/NextCup-Info.plist`); photos via `PhotosPicker` (no permission); local notifications for the taste reminder, asked the first time a brew is saved untasted (never at launch); no contacts, microphone or Bluetooth |
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

## Camera and barcode (T037, 2026-10-25)

New vendor: **Open Food Facts** (Open Food Facts association, open database, no key, no account).

| Data | Where it lives or goes | Retention | Removed by |
| --- | --- | --- | --- |
| Scanned barcode number (8 to 14 digits, validated) | Sent once, after a scan, to `world.openfoodfacts.org/api/v2/product/<code>.json?fields=product_name,brands` with the user agent `NextCup/1.0 (iOS; hello@rarecreatures.app)`; no other data, no identifier, no location | Not stored by the app; Open Food Facts server logs per its terms | Not stored by the app |
| Product name and first brand from Open Food Facts | Filled into the bean form for review; saved only when the user taps Save | As the bean | Delete the bean; delete all data |
| Camera photos (brew, bag) | Taken only on a tap through the system camera; treated exactly like library photos (metadata stripped; brew photos stay on device, bag photos go to the AI provider only on a tap) | As before | As before |
| Live barcode video | Processed on device by VisionKit; not recorded or sent | Not stored | n/a |

Supersedes "No camera is used" above. Network endpoints are now the two AI providers, Apple Maps search and Open Food Facts.

## QR codes on bags (2026-10-30)

No new vendor of ours. The roaster's own site (whatever host the bag's QR code names) receives one request, the same as opening the link in a browser.

| Data | Where it lives or goes | Retention | Removed by |
| --- | --- | --- | --- |
| Scanned QR text | Read on device by VisionKit. A web link (https, or http upgraded to https; named public host only, no IP address, local name or user name) is fetched once with `GET`, the user agent `NextCup/1.0 (iOS; hello@rarecreatures.app)` and an ephemeral session (no cookies, no cache); nothing else is sent. Text that is not a link is read on device and never sent | Not stored; the link is shown in the open editor only | Closing the editor |
| Page facts (name, roaster, origin, region, farm, process, varietal, roast level, roast date, notes, weight) | Read on device from the page (`QRBeanLink`, first 2 MB, page text treated as data); filled into blank fields for review; saved only when the user taps Save | As the bean | Delete the bean; delete all data |
| The page's site (`https://host/`) | Saved as the roaster's website on Save, only if that roaster has none | As the roaster | Edit or delete the roaster; delete all data |
| The roaster's server logs | The roaster's site sees the iPhone's IP address and the user agent, as for any web visit | Per that site's terms | n/a |

Network endpoints are now the two AI providers, Apple Maps search, Open Food Facts and the link on a scanned QR code. App Privacy label: unchanged (Rare Creatures LLC still collects nothing new; the request goes from the phone to the site the user scanned, as when following a link).

## Apple on-device AI and model lists (2026-10-26)

| Data | Flow | Retention | Control |
| --- | --- | --- | --- |
| AI prompts and photos with no key set | Apple's on-device model (FoundationModels). Photos are first read to text with Apple Vision. Nothing leaves the iPhone, so no disclosure is shown | Same as the AI request log | Pick another provider in Settings → AI |
| API key when it is saved | Sent once to `api.anthropic.com/v1/models` or `api.openai.com/v1/models` to check it and list its models; no user data is sent | Not stored by the app beyond the Keychain item | Remove key |
| Effort choice | `UserDefaults` (`ai.effort`), no secrets; sent with each cloud request | Until changed | Settings → AI |
