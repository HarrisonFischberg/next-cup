# Claims and evidence

Every material claim the app or its drafts make, with what supports it. Updated 2026-10-24 (T030).

| Claim (where) | Support | Status |
| --- | --- | --- |
| "Nothing is sent until you tap, and never without a key" (AI disclosure) | Unit test `noDisclosureMeansNoCall`; the only network code is `URLSessionTransport` in `NextCupKit/AI/AIClient.swift`, used by `AIQueue` | Verified in tests with a stub transport; no real call made |
| "Next Cup has no server and sees none of it" (AI disclosure, privacy draft) | No server code, no non-Apple network endpoints other than the two provider URLs in `AIClient.swift` | Verified by code search |
| "A photo is sent without location or camera metadata" | `sanitizedPhotoHasNoGPSExifOrTIFFMetadata` | Verified for the sanitizer; the send path uses it per code review, not a network capture |
| Keys are kept only on this device | Keychain `WhenUnlockedThisDeviceOnly`; `keychainRoundTrip`; no key in `UserDefaults` (T021 test) | Verified |
| "Location is not stored" (privacy draft) | Only saved roasters persist (`testDeniedLocationFallsBack...`); roaster rows hold the roaster's coordinates, not the user's | Verified for the stub path; real `MKLocalSearch` and the real prompt not exercised |
| "Delete everything" removes store, drafts, backups, keys | `deleteAllClearsStoreDraftsBackupsKeysAndReseeds` | Verified |
| AI photos and request text are deleted when a request ends | `AIQueueTests` (purge on done, failed, cancelled; cancelled paper import leaves no photo); `discardingTheResultLeavesNoAnswerOnTheRow` for answers | Verified in unit tests |
| The AI notice is accepted per provider and lists exactly what each action sends | `AIConfigTests`, `AIClientTests` (per provider and versioned); the notice text is generated from `AIFeature.sends`, which a test compares with the payload builders | Verified in unit tests; no screenshot of the sheet |
| The AI preview is the payload that is sent | `AIAskModelTests` compares the stored payload with the preview; request bodies are covered in `AIClientTests` | Partly verified: the stub does not capture the final request bytes |
| Location is requested at reduced accuracy | `NSLocationDefaultAccuracyReduced` in `Config/NextCup-Info.plist`, asserted in `DataExchangeTests` | Verified by test; the user can still allow precise in the iOS prompt |
| Recommendations are explained only from computed facts | T017 tests (explanation built from computed values) | Verified in unit tests |
| App Store privacy label | Privacy manifest declares Photos or Videos and Other User Content (App Functionality, not linked, no tracking) because data can go to an AI provider on the user's tap | Decision recorded 2026-10-25; "Data Not Collected" is NOT claimed; the store form must say the same |

Never claimed: store ratings, user counts, comparisons with other apps, legal compliance.
