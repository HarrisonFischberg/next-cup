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
| Recommendations are explained only from computed facts | T017 tests (explanation built from computed values) | Verified in unit tests |
| Data Not Collected (App Store privacy label) | Privacy manifest declares no collected data and no tracking | NOT CLAIMED anywhere yet; owner decides when filling the store form |

Never claimed: store ratings, user counts, comparisons with other apps, legal compliance.
