# Next Cup: Opus audit of safeguards 1, 2, 6, 7, 8, 20

Engineering audit, not legal advice. Done by reading the code in the worktree; no tests were run and nothing was edited.

## Verdict

The architecture holds up. There are no third-party SDKs, no server and no logging. Only two network paths exist (AI over `URLSession`, Apple `MKLocalSearch`), and both start from a user tap. Keys sit in the Keychain as `WhenUnlockedThisDeviceOnly` and never show up in UserDefaults, exports or backups. Every photo send path strips metadata. The four PASS rows (6, 7, 8, 20) still overstate things, and the privacy draft says things the code contradicts. The disclosure and policy describe AI payloads (brew, notes, history) that production never sends, and leave out what is sent and kept. Every AI photo, including handwritten journal pages and cancelled imports, is kept forever in `AIRequest.attachment`, isn't exported, and only goes away with delete-all. Old queued requests get sent the next time the user taps any AI action. Users accept the disclosure once and it names only the first provider. Location is precise, not "approximate". None of these blocks launch and each is a small fix, but rows 6 and 7 should be FAIL until fixed, and rows 8 and 20 NEEDS REVIEW. Also, `docs/legal/PRIVACY.md` doesn't exist: the policy is `docs/legal/privacy-policy-draft.md`, and that's the file audited here.

## Row status

| Row | Builder | Auditor | Why |
| --- | --- | --- | --- |
| 1 Privacy policy | NEEDS REVIEW | NEEDS REVIEW (evidence overstated) | The status is right, but the claim that the statements were "checked against code" is false: 5 statements are unsupported or contradicted (F1, F4, F8, F10, F11). No hosted URL yet. |
| 2 Terms | NEEDS REVIEW | NEEDS REVIEW | Fine. Apple's standard EULA covers it. The cited tests are about the AI disclosure, not terms, so they're no evidence for this row. |
| 6 Form consents | PASS | FAIL | The disclosure describes data that isn't sent and omits data that is (F1). It's accepted once for every provider (F3). Tests cited in the wrong file (`noDisclosureMeansNoCall` is in `Packages/NextCupKit/Tests/NextCupKitTests/AIClientTests.swift:66`). |
| 7 No unnecessary data | PASS | FAIL | AI photos and payloads are kept forever with no purpose (F2). Precise location is requested where coarse is enough (F4). Daily backups keep 7 full copies of every photo (F9). |
| 8 Third-party SDK audit | PASS | PASS for SDKs; NEEDS REVIEW for manifest | Confirmed: `Package.swift` has no dependencies, the project has one `XCLocalSwiftPackageReference`, and every import is an Apple framework. Leaving `NSPrivacyCollectedDataTypes` empty may be wrong because user content goes to OpenAI/Anthropic (F6). |
| 20 Data deletion | PASS | NEEDS REVIEW | Delete-all covers the store (including `AIRequest`), drafts, backups, all UserDefaults and Keychain items. But the Keychain wipe is stubbed in its test, external-storage blob removal isn't verified, deleting a single item leaves AI copies and backups behind, and the Live Activity and caches remain (F5, F7). |

## Findings (by severity)

### High

**F1. The AI disclosure and policy misstate what is sent.**
- What the docs say: `NextCup/Features/AI/AISettingsView.swift:147` and `docs/legal/privacy-policy-draft.md:23-25` both say the app "sends the brew, notes and a slice of your history".
- What the code does: the only `enqueue` callers are `NextCup/Features/Beans/BeanEditorView.swift:294` (bag label / coffee photo) and `NextCup/Features/Import/PaperImportModel.swift:100` (journal page photo). Each sends a fixed prompt, the JSON schema and one sanitized JPEG (up to 1568 px).
- Dead code: `AISuggestions.payload(diagnosing:)` and `payload(insightsFrom:)` (`NextCup/Features/AI/AISuggestions.swift:29-44`, up to 8 brews with dates, bean origin/process/roast, all brew parameters and free-text notes) have no callers. Settings still lists "Brew diagnosis" and "Insights" as features (`AIConfig.swift:107-110`), but nothing in the UI triggers them.
- What's left out: neither text says that a photo of a handwritten journal page is sent in full, or that a copy of every sent photo is kept on the device (F2).
- Fix: rewrite the disclosure and policy to list exactly what each feature sends. Either remove diagnosis/insights from Settings and `AIFeature`, or wire them up and disclose the 8-brew slice including notes. Bump `AIPreferences.disclosureVersion` when the text changes.

**F2. Every AI photo and payload is kept forever, including cancelled ones.**
- The code: `AIQueue.enqueue` (`NextCup/Features/AI/AIQueue.swift:70-74`) saves the payload and the photo (`@Attribute(.externalStorage) attachment`, `NextCup/Persistence/Models.swift:241`) to SwiftData. No code ever prunes them. Cancelling only sets `status = .cancelled` (`AIQueue.swift:87-94`).
- Not deleted with the item: `Brew.aiRequests` uses `.nullify` (`Models.swift:42`), so deleting a brew leaves its requests behind.
- Not exported: `DataExporter.archive` leaves `AIRequest` out (`NextCup/Persistence/DataExchange.swift:18-37`), so "export everything" isn't true either. Only delete-all removes them.
- What the docs say: `docs/data-inventory.md:52` says for paper import "nothing is stored before that [confirmation]", but the page photo is stored the moment the user taps "Read with my AI key", whether or not they confirm.
- Fix: once a request is done, cancelled or failed, set `attachment = nil` and `payloadJSON = Data()`, or delete the row after ingest. Make `Brew.aiRequests` cascade. Add a test that a cancelled paper import leaves no attachment.

### Medium

**F3. One disclosure acceptance covers every provider.**
- The code: `AISettingsView.swift:77-79` shows the sheet only if `hasAcceptedDisclosure` is false, and that flag is global (`AIConfig.swift:70-74`). The sheet text names a single provider (`AISettingsView.swift:147,151`).
- The effect: after accepting for Anthropic, saving an OpenAI key shows no disclosure naming OpenAI. App Review guideline 5.1.2(i) asks apps to disclose and get permission before sharing personal data with third-party AI.
- Fix: store the acceptance per provider (e.g. `ai.disclosure.<provider>.version`) and check it in `AIClient`'s `disclosureAccepted` for the provider being called. Add a test.

**F4. Location is precise, but the policy says "approximate", and Apple isn't named as a recipient.**
- The code: `NextCup/Features/Discovery/MapKitRoasterSearch.swift:40-51` uses `CLServiceSession(authorization: .whenInUse)` and `CLLocationUpdate.liveUpdates()` with full accuracy, and there's no `NSLocationDefaultAccuracyReduced` in `Config/NextCup-Info.plist`.
- What the docs say: `privacy-policy-draft.md:32` says "approximate location" and `data-inventory.md:12` says "Coarse". Neither says that the coordinates or the typed city go to Apple (MKLocalSearch).
- Fix: add `NSLocationDefaultAccuracyReduced = YES` (a 25 km search doesn't need precise location), or reword the docs. Name Apple Maps as the recipient of the search point or city.

**F5. Queued requests from earlier sessions are sent by a later, unrelated tap.**
- The code: `processQueued()` (`AIQueue.swift:79-85`) fetches every `.queued` `AIRequest` in the store, not only the ones this screen enqueued. A paper import left "Waiting for a connection" by navigating away (there's no `onDisappear` cancel in `PaperImportView.swift` or `BeanEditorView.swift`) stays queued. It then goes out days later when the user taps any AI action, or when the network comes back while any `AIQueue` is alive.
- The effect: it's still under a key and an earlier tap, but the user no longer expects it to be sent. This weakens "Nothing is sent until you tap".
- Fix: cancel in-flight or queued requests in `onDisappear`, and have `processQueued` send only the IDs this instance enqueued. Or, on launch, expire queued requests older than the session.

**F6. The privacy manifest and App Store label may under-declare.**
- The file: `NextCup/PrivacyInfo.xcprivacy:9-10` declares no collected data types.
- Why it may be wrong: photos and user content are transmitted to OpenAI/Anthropic, which keep API data under their own terms. Whether bring-your-own-key traffic counts as "collected" for Apple's label needs a decision, not an assumption. The row 8 PASS hides that decision.
- Fix: move it to an owner/legal decision. If the answer is "collected", declare Photos or Videos and Other User Content (App Functionality, not linked, no tracking) and use the same answer in App Store Connect. The `UserDefaults` CA92.1 entry is accurate; I found no other required-reason APIs.

**F7. Delete-all is under-tested and leaves a few things behind.**
- The test: it stubs the Keychain wipe (`NextCupTests/DataExchangeTests.swift:293-306`) and never checks that `AIRequest` rows are gone, that the disclosure flag is cleared, or that the external-storage blob files are deleted.
- Left behind: delete-all (`DataExchange.swift:393-421`) doesn't end the running Live Activity (recipe name and steps on the Lock Screen, `TimerActivityController.swift:71`), doesn't clear `Library/Caches` (URLSession/MapKit), and doesn't vacuum the SQLite file.
- Not leaked: there are no cached model lists (model IDs are typed) and no App Group or widget storage.
- Fix: add assertions for `AIRequest` count 0, `ai.disclosure.version` cleared, and an empty `.default_SUPPORT/_EXTERNAL_DATA` folder. Call `LiveTimerActivity().end()` and empty the caches directory. Run one real-Keychain test on the simulator.

**F8. "Export everything" isn't everything.**
- What the docs say: `privacy-policy-draft.md:18`.
- What the code does: AI request history and the photos sent to providers are excluded (F2). Fixing F2 makes this moot. Otherwise, reword the policy.

### Low

- **F9. Backups.** The `Application Support/Backups` files (`DataExchange.swift:353-354`) and drafts (`DraftStore.swift:53-54`) use `.completeFileProtectionUntilFirstUserAuthentication`, which is just the default class. Backups and exports run in the foreground, so `.completeFileProtection` costs nothing. The backups embed every photo as base64 and keep 7 days of them, so a deleted brew survives up to 7 days in the backups. Say so in the policy, or prune the backups when an item is deleted.
- **F10. Export temp file.** `DataSettingsView.swift:68,187-190` writes a full plaintext export to `tmp/NextCupExport` every time "Your data" opens, before the user asks to export, with no explicit file protection. Generate it on tap, and delete it after the share sheet closes.
- **F11. "No crash reports."** (`privacy-policy-draft.md:43`) Apple sends the developer crash logs and App Analytics from users who opt in. Reword to "the app sends nothing to the developer; Apple may share crash data if you allow it in iOS settings".
- **F12. Key field.** The API key `SecureField` uses `.textContentType(.password)` (`AISettingsView.swift:62`), which invites password AutoFill and suggestions. Use `.textContentType(nil)` with no autofill hints.
- **F13. Stale data inventory.** `docs/data-inventory.md:3-4` still says "Nothing is built yet". Line 9 lists "Camera" (there's no camera code; it's `PhotosPicker` only) and "AI analysis" of brew photos (brew photos are never sent). Line 11 lists prompts built from notes and past brews (not wired up). Line 50 says "no network call made yet". It has no rows for the `AIRequest` log, the tmp export, the timer snapshot in UserDefaults, the Live Activity content, the typed city sent to Apple, or saved roaster coordinates.
- **F14. Disclosure version bump.** After a bump, users with a saved key can't re-accept: the sheet only appears from "Save key", so every call fails with `disclosureNotAccepted` (`AISettingsView.swift:51-56,77-79`). Show the sheet from the AI action, or offer "Review disclosure" when a key is saved.
- **F15. App Store items.**
  - Present and fine: `NSLocationWhenInUseUsageDescription` is accurate, `NSSupportsLiveActivities = YES` (pbxproj line 384), and no photo or camera usage strings are needed with `PhotosPicker`.
  - Add `ITSAppUsesNonExemptEncryption = NO` (HTTPS only).
  - The widget extension has no privacy manifest. That's acceptable because it uses no required-reason APIs (only `ActivityKit`, `SwiftUI` and `WidgetKit` imports); add an empty one only if review asks.
  - A privacy policy URL is required in App Store Connect (blocker B005/B013).
- **F16. Provider picker bug.** The segmented control shows Anthropic, but its default is never written (`AISettingsView.swift:113-115`), so `provider(for:)` returns nil and the user gets "Choose a provider" until they toggle it. It's a usability bug, not a leak; write the default on first appear.

## Confirmed as true

- **Network paths.**
  - `URLSessionTransport` (`Packages/NextCupKit/Sources/NextCupKit/AI/AIClient.swift:77`) reaches only `api.anthropic.com` and `api.openai.com`, and the key and disclosure are checked before any I/O (lines 110-111).
  - `MKLocalSearch` (`MapKitRoasterSearch.swift:22`) runs only from the "Use my location" and city-search buttons, and Retry.
  - `Link` to a recipe credit URL opens only on a tap (`RecipeDetailView.swift:215`). There's no Map view.
  - There are no AI calls from launch hooks (`NextCupApp.swift:27` only writes the backup), App Intents (`BrewIntents.swift`, which open URLs only), deep links, or background tasks.
  - `NWPathMonitor` sends nothing by itself. Retries are limited to 3 per send (`AIClient.swift:85,114`).
- **Photos.** All three photo paths sanitize before storing or sending (`BrewFormModel.swift:309`, `BeanEditorView.swift:282`, `PaperImportModel.swift:54`). The sanitizer writes a fresh `CGImage` with no properties (`PhotoSanitizer.swift:24-35`). Brew photos are never sent.
- **Keychain.**
  - Items are `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and not synchronizable (`AIConfig.swift:44`).
  - Keys aren't in UserDefaults (test at `AIConfigTests.swift:40-46`), logs (none exist), exports, backups, or `AIRequest.payloadJSON` (the key goes only into the request header).
  - Delete-all calls `SecItemDelete` on every generic-password item (`DataExchange.swift:389-391`).

## Could not verify

- Whether SwiftData `context.delete(model:)` deletes `.externalStorage` blob files (needs a simulator check of the container).
- Real network traffic (no proxy capture). Whether the real `CLLocationUpdate` prompt and its accuracy match the reading above. The real-Keychain wipe on device.
- Whether URLSession or MapKit leave cached responses in `Library/Caches` after delete-all.
- How Apple will classify bring-your-own-key AI traffic for the privacy label (F6), and whether the disclosure meets 5.1.2(i). Both are owner/legal calls.
- I didn't run `swift test` or `xcodebuild`, so whether the cited tests pass is unconfirmed.
