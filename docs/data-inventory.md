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
