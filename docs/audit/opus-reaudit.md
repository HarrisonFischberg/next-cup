# Next Cup: Opus re-audit of F1 to F16 (after T031 to T034)

Engineering audit, not legal advice. Read-only: no edits, no commits, no xcodebuild, no simulator. `swift test --package-path Packages/NextCupKit` was run: 153 tests passed.

**Which tree I audited.** The assigned worktree (`.claude/worktrees/agent-ae78f651dd3cc5a8e`, branch `worktree-agent-ae78f651dd3cc5a8e` at `fbc9719`) is stale. It has no `docs/audit/`, no `docs/legal/PRIVACY.md` and no T031 to T034 entries in `activity.md`. So I read the main checkout's working tree, `/Users/harrison/projects/next-cup`. Its `.git/HEAD` points at `main` (`06c673d`), while `build/phase-5` is at `ffefd49`. A hook blocked every git command, so I couldn't confirm that this working tree is exactly `build/phase-5` or check for uncommitted changes. Paths below are relative to `/Users/harrison/projects/next-cup`.

## Verdict

Most of the fixes are real and done well.
- The queue now sends only the requests it enqueued itself. Every screen that uses it cancels on leave (all three callers), and stale requests are cancelled at launch.
- Photos and payloads are purged when a request ends, and `Brew.aiRequests` cascades.
- Consent is per provider and checked again inside `AIClient`. The disclosure lists exactly what each feature sends, and a test ties that text to the payload builders.
- Diagnosis and insights are wired up behind a preview.
- Location is reduced-accuracy, and export files are created only on tap.
- The manifest declares Photos or Videos and Other User Content.
- The T031 roaster match runs only from a tap and sends Apple only the roaster name text.

What's left is mostly honesty in the docs, plus one retention gap. `AIRequest.resultJSON` is never purged. For paper import it holds the AI's transcription of the whole handwritten page, notes included. It stays after the user discards the import, isn't exported, and only delete-all removes it. That contradicts `PRIVACY.md:13` and `data-inventory.md:76`.

Delete-all is still tested with a stubbed Keychain wipe, a stand-in external-data folder and a stand-in disclosure key. `claims-evidence.md`, `compliance-checklist.md` and parts of `data-inventory.md` still describe the old code. None of this blocks launch.

## Findings F1 to F16

| # | Status | Evidence | What remains |
| --- | --- | --- | --- |
| F1 Disclosure misstated payload | FIXED | `AIConfig.swift:112-125` `sends` per feature; `AIDisclosureView.swift:26-35` lists them; diagnosis/insights wired (`BrewFormView.swift:195-199`, `ExploreView.swift:100-105`); `describe` fields (`AISuggestions.swift:46-65`) match the text; `PRIVACY.md:26-31` matches; version bumped to 2 (`AIConfig.swift:65`); test `AIConfigTests.swift:61-88` | Test checks key words only, not every field |
| F2 AI photos/payloads kept forever | PARTLY FIXED | `purge` on done/failed/cancelled (`AIQueue.swift:154-177`); cascade (`Models.swift:42`); tests `AIQueueTests.swift:124-148,192-219` | `resultJSON` is never purged (`AIQueue.swift:156`). For paper import it is the page's transcribed content incl. notes (`PaperImport.swift:219-222`), kept on a row with no brew after the user abandons review. Bag-scan results likewise. Also: SwiftData freeing the external blob when `attachment = nil` was not verified |
| F3 One acceptance for all providers | FIXED | `AIConfig.swift:67-79` per-provider key; `AIQueue.swift:45-48` checks the called provider; gates at `BeanEditorView.swift:333`, `PaperImportView.swift:137-143`, `AIAskModel.swift:59`; tests `AIClientTests.swift:77`, `AIConfigTests.swift:49-59` | None |
| F4 Precise location / Apple not named | FIXED | `Config/NextCup-Info.plist` `NSLocationDefaultAccuracyReduced = true`; asserted by `DataExchangeTests.swift:328-332`; `PRIVACY.md:32` names Apple Maps; `data-inventory.md:82-83` | The user can still grant precise in the iOS prompt (disclosed) |
| F5 Old queued requests sent by a later tap | FIXED | `owned` set (`AIQueue.swift:30,81,89`); `cancelAll` on leave: `BeanEditorView.swift:135`, `PaperImportView.swift:74`, `AIAskView.swift:54`; `expireStale` at launch (`NextCupApp.swift:28`); tests `AIQueueTests.swift:150-190` | A request already `.sending` when the screen closes may have left the device (expected) |
| F6 Manifest under-declares | FIXED | `PrivacyInfo.xcprivacy:9-35` PhotosorVideos + OtherUserContent, not linked, no tracking, App Functionality; `PRIVACY.md:51-53` records the decision | App Store Connect must be filled the same way (owner) |
| F7 Delete-all under-tested, leaves things | PARTLY FIXED | `DataExchange.swift:417-454` now deletes `AIRequest`, ends the Live Activity, empties Caches, tmp and `_EXTERNAL_DATA`; test `DataExchangeTests.swift:284-326` | Keychain wipe still stubbed (`keys: { keysCleared = true }`, line 305). External folder is a stand-in temp dir: the real path from `externalDataDirectory(of:)` (`DataExchange.swift:404-409`) is an unverified guess. Disclosure key is a stand-in (`ai.disclosure.accepted.anthropic` ≠ real `ai.disclosure.anthropic.version`). Activity end is an injected closure. No SQLite vacuum/WAL checkpoint, so purged bytes may linger in free pages |
| F8 Export isn't everything | FIXED (by disclosure) | `PRIVACY.md:46` says the AI log and sent photos aren't exported; `DataExchange.swift:18-37` unchanged | See F2: the unexported log still holds paper-import results |
| F9 Backups / drafts protection, 7-day retention | FIXED | Backups `.completeFileProtection` (`DataExchange.swift:353`); retention disclosed (`PRIVACY.md:15`); drafts deliberately left at until-first-auth (see below) | `data-inventory.md:79` wrongly says drafts use complete protection |
| F10 Export temp file written on appear | FIXED | Written on tap (`DataSettingsView.swift:192-200`), removed on dismiss (`:69,202-205`), and delete-all empties tmp | No explicit file protection on export files (`DataExchange.swift:53-57`); they survive if the app is killed with the share sheet open |
| F11 "No crash reports" | FIXED | `PRIVACY.md:38` | None |
| F12 Key field AutoFill | FIXED | `.textContentType(nil)` (`AISettingsView.swift:62`) | Not checked on device |
| F13 Stale data inventory | PARTLY FIXED | New "Current flows" table (`data-inventory.md:70-86`) | Still stale or wrong: intake rows `:10` (Camera, "AI analysis" of photos), `:51` "no network call made yet", `:53` "nothing is stored before that", `:62` manifest "no collected data", `:79` drafts protection, `:76` "result stays with the brew" (bean/paper results have no brew). No row for the T031 roaster-name query to Apple (CLAUDE.md requires every flow) |
| F14 Can't re-accept after a version bump | FIXED | Disclosure is shown from each AI action (`BeanEditorView.swift:123-133`, `PaperImportView.swift:65-73`, `AIAskView.swift:45-53,116-117`) | None |
| F15 App Store items | PARTLY FIXED | `ITSAppUsesNonExemptEncryption = false` in the Info.plist plus test | Privacy policy URL and in-app link still missing (B005/B006/B013, owner). Widget has no manifest (acceptable) |
| F16 Provider default never written | FIXED | `AISettingsView.swift:137-138` writes the default on appear | Only written once Settings → AI is opened, but a key can only be saved there anyway |

**Drafts protection is on purpose.** `DraftStore.swift:53-55` uses `.completeFileProtectionUntilFirstUserAuthentication` and has a code comment saying so. The reason is in `activity.md:641`: a draft saved as the phone locks must not be lost. The flush happens on `scenePhase != .active` (`BrewFormView.swift:93`). The choice is defensible. Note the draft can hold the brew photo and notes. `data-inventory.md:79` should say "default protection (until first unlock)".

**T031 (roaster match).** It runs only from a tap: `matchShown = true` is set only by the button at `BeanEditorView.swift:209-216`, which shows only when a roaster name is typed. The sheet's `.task` then searches once (`RoasterMatchView.swift:83`), and Retry is a tap. It sends Apple the string `"<name> coffee roaster"` with no region, no coordinates and no location request (`MapKitRoasterSearch.swift:20-21`, `RoasterDiscoveryModel.swift:130-133`). Nothing is stored until the bean is saved, and then only the picked name, city and website. It does not send more than the roaster name. In fact it sends less than `PRIVACY.md:32` says: no "map area or city" goes with a match.

## Proposed safeguard rows

| Row | Proposed | Reason |
| --- | --- | --- |
| 1 Privacy policy | NEEDS REVIEW | The text is now close to the code, but `PRIVACY.md:13` contradicts AI-result retention (F2). It also isn't published, has no in-app link and has no legal review. |
| 6 Form consents | NEEDS REVIEW (code would pass) | Per-provider, versioned, shown before the first send and accurate. But no screenshot or UI-test result of the sheet exists, and the checklist cites a test that doesn't exist (`disclosureIsOnceAndVersioned`; the real one is `disclosureIsPerProviderAndVersioned`). |
| 7 No unnecessary data | NEEDS REVIEW | Photos and payloads are purged and location is reduced, but paper-import transcriptions and bag results in `resultJSON` are kept indefinitely with no purpose once used. |
| 8 Third-party SDK audit | PASS | No dependencies; Apple imports only; manifest declares the cautious answer. The checklist text still says "no collected data" and needs editing. |
| 20 Data deletion | NEEDS REVIEW | Coverage is much better, but the Keychain wipe, the real external-data path and the real disclosure keys are never exercised, and the store isn't vacuumed. Needs one on-device or simulator check. |

## New findings

**Medium**
- **N1. AI results kept with no purpose.** `AIQueue.purge` (`AIQueue.swift:174-177`) leaves `resultJSON`. Fix: clear `resultJSON` for `.bagRecognition`, `.photoInterpretation` and `.paperImport` once the screen has read it, or delete those rows. Keep it for diagnosis/insights, since the `Suggestion` copies what it needs. Then make `PRIVACY.md:13` and `AIDisclosureView.swift:21` exact.

**Low**
- **N2. Stale `claims-evidence.md`.** Last updated at T030. Line 14 says the manifest "declares no collected data", which contradicts `PrivacyInfo.xcprivacy`. There are no entries for the new claims: purge on end, per-provider consent, reduced accuracy, preview equals what's sent.
- **N3. Stale `compliance-checklist.md` rows.** Row 6 cites a renamed test and `AISettingsView` as the disclosure (it's now `AIDisclosureView`). Row 7 says the Info.plist has "location string only". Row 8 says the manifest has "no collected data".
- **N4. `PRIVACY.md:32` over-describes the match search.** It sends name text only. Also unverified: whether MapKit adds an implicit location bias to a region-less `MKLocalSearch` when the app has location permission.
- **N5. Export files have no explicit protection.** `DataExchange.swift:53-57` uses default protection, and a crash while the share sheet is open leaves them in tmp. Use `.completeFileProtection`, since export runs in the foreground.
- **N6. `NWPathMonitor` is never cancelled.** Every `AIQueue.live` starts one and none is ever cancelled (`AIQueue.swift:54-60`). It holds `self` weakly, so nothing is sent; it's a resource leak only.
- **N7. A weak test.** `AIAskModelTests.swift:103-114`, "theTapSendsExactlyThePreviewedText", compares the stored payload with the preview, not the request bytes the transport got: the stub doesn't capture the `URLRequest`. Request bodies are covered separately in `AIClientTests.swift:86-113`.
- **N8. No UI evidence for T032 to T034.** The UI runs timed out or were flaky (`activity.md:601,629,640`). There are no screenshots of the disclosure sheet, the Ask sheet or the Export buttons in the repo, and no VoiceOver pass.

## Could not verify

- Whether the audited working tree equals `build/phase-5`: git was blocked, and the assigned worktree is an older commit without these changes.
- App unit tests and UI tests (no xcodebuild allowed). I relied on `activity.md` for the 245 unit passes.
- Whether setting `attachment = nil` or deleting rows removes SwiftData's external blob files, and whether the guessed `_EXTERNAL_DATA` path is right.
- Real Keychain wipe, a real Live Activity ending, and file-protection classes: these need a device.
- Real MapKit/URLSession traffic (no proxy capture), including any implicit location bias on the region-less name search.
- Whether the cascade rule change migrates cleanly on an existing on-disk store (`activity.md:604`).
- Apple's view of the BYO-key privacy label and of 5.1.2(i). Those are owner/legal calls.
