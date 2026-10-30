# Releasing Next Cup

One command, from the repo root on the Mac:

```bash
./release.sh ios                          # dry run: archive only, nothing uploaded
./release.sh ios --live                   # archive + upload to TestFlight        (fastlane ios beta)
./release.sh ios --live --track production    # archive + upload + listing + screenshots + submit for review (fastlane ios release)
./release.sh android --live               # signed AAB to Play internal testing   (fastlane android release)
./release.sh android --live --track production # signed AAB + listing to Play production
./release.sh all --live                   # both
```

Without `--live` nothing leaves the Mac. Android is skipped until the `android/` folder is on the branch.
Next Cup has no browser extension, so there is no `chrome` or `firefox` target.

The iOS submit leaves the version on **Manually release**: after Apple approves, press Release in App Store Connect.

## Where things live

| Path | What |
| --- | --- |
| `release.sh` | The one command |
| `fastlane/Appfile`, `fastlane/Fastfile` | Bundle ID, team KTV2G3Z883, lanes |
| `store/ios/metadata/` | Name, subtitle, description, keywords, URLs, categories, copyright, App Review contact and notes |
| `store/ios/age_rating.json` | Age rating answers (all None/No, expect 4+) |
| `store/ios/screenshots/en-US/` | `*-6.9.png` (1320 × 2868) and `*-6.3.png` (1206 × 2622) |
| `store/android/metadata/en-US/` | Play title, short and full description, `changelogs/default.txt`, `images/phoneScreenshots/` |

For each iOS version after 1.0, add `store/ios/metadata/en-US/release_notes.txt` (Apple refuses release notes on a first version) and bump `MARKETING_VERSION` in Xcode. For Android, bump `versionCode` in `android/` and update `changelogs/default.txt`.

## Env vars (never commit the files they point to)

| Var | For |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | Issuer ID, shown above the keys list |
| `ASC_KEY_PATH` | Path to `AuthKey_XXXX.p8`, e.g. `~/.appstoreconnect/AuthKey_XXXX.p8` |
| `PLAY_JSON_KEY_PATH` | Path to the Play service-account JSON |
| `ANDROID_KEYSTORE_PATH` | Path to the upload keystore (`.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | Key password |

Put them in `~/.zshrc` (or a password manager's shell plugin). `.gitignore` blocks `*.p8`, `*.jks`, `*.keystore` and `play-*.json` as a backstop.

## One-time setup

1. `brew install fastlane`
2. **App Store Connect key:** App Store Connect > Users and Access > Integrations > Team Keys > "+", access **App Manager**. Download the `.p8` (Apple lets you download it once), move it to `~/.appstoreconnect/`, set the three `ASC_*` vars.
3. **Xcode signing:** Xcode > Settings > Accounts signed in to team KTV2G3Z883 (the archive uses automatic signing, same as `scripts/archive-testflight.sh`).
4. **Play service account:** Google Cloud console > create a service account with a JSON key; Play Console > Users and permissions > invite its email with Release permissions for Next Cup. Set `PLAY_JSON_KEY_PATH`.
5. **Upload keystore:** `keytool -genkeypair -v -keystore ~/.android/nextcup-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`, set the four `ANDROID_*` vars, and enroll in Play App Signing when creating the app. Back the keystore up; losing it means asking Google for an upload-key reset.
6. Run each target once **without** `--live` to check the build works.

## Steps that can't be automated

Apple and Google offer no API for these; do them once in the web consoles.

**Both stores**
- Developer accounts: Apple Developer Program (US$99/year, already active) and Google Play Console (US$25 once).
- First listing creation: the App Store Connect app record (exists from TestFlight) and the Play Console app (Create app). Play's API also can't upload the very first AAB of a new app: upload it by hand in Play Console once, then `release.sh` works.
- EU Digital Services Act trader status: App Store Connect > Business, and Play Console > Account details. As a trader, Rare Creatures LLC's address, phone and email show publicly in the EU.
- Agreements: App Store Connect > Agreements, Tax and Banking (Free Apps agreement), and the Play Developer Distribution Agreement when the account is made.

**iOS**
- App Privacy answers: Yes, we collect data; Photos or Videos and Other User Content; each App Functionality, not linked, no tracking. Same as `NextCup/PrivacyInfo.xcprivacy`.
- Content rights: Yes, third-party content with rights (Unsplash photos, CC0 music; `docs/asset-licenses.md`).
- App Review phone number: App Store Connect > the version > App Review Information (kept out of git).
- Pricing and availability: Free; territories.

**Android**
- Data safety form, content rating (IARC) questionnaire, target audience, ads declaration, and app access (no login) in Play Console > App content.
- New personal developer accounts must run a closed test with 12+ testers for 14 days before production; organization accounts skip it.
- While the app has never been published, Play only accepts draft releases: if an upload fails with "Only releases with status draft may be created on draft app", finish the first release in Play Console.

## Already handled in code

- `ITSAppUsesNonExemptEncryption = false` in `Config/NextCup-Info.plist` (HTTPS and Keychain only), so App Store Connect doesn't ask about export compliance.
- `NextCup/PrivacyInfo.xcprivacy` declares the required-reason APIs the app uses: UserDefaults (`CA92.1`) and file timestamps (`C617.1`, the drafts folder reads its own files' modification dates). No tracking, no tracking domains.
