# Next Cup for Android: Play Store listing and data safety

Draft text for the Play Console. Harold submits; nothing here has been entered in the Console.

## Store listing

- **App name:** Next Cup
- **Short description (80 max):** A coffee brew journal with a guided timer and one change to try next cup.
- **Category:** Food & Drink
- **Contact email:** hello@rarecreatures.app
- **Privacy policy URL:** (needs a hosted page; see docs/legal)

**Full description**

Next Cup is a brew journal for people who make coffee at home and want the next cup to be better than the last.

- Guided timer for pour over, immersion, espresso and cold brew, with each step, its water target and a chime when it changes. It keeps running with the screen off and shows in your notifications.
- Log a brew in seconds: dose, water, grind, temperature, time, how it tasted and a rating. Unsaved brews are kept as drafts.
- One change to try next: tell Next Cup a cup was sour, bitter, weak or strong and it suggests a single adjustment for the next brew of those beans.
- Your beans: roast date and freshness, how much is left, the best brew of each bag so far and what to brew it with. Scan the barcode or read the label to fill details.
- Explore roasters from a starter catalog, or find roasters near you.
- Optional AI advice with your own Anthropic or OpenAI key, or on the phone itself where Gemini Nano is available. You see exactly what would be sent before the first request.
- Export everything as JSON or CSV. Imports from Next Cup on iPhone.

No account, no ads, no tracking.

## Data safety form

**Does the app collect or share user data?** No data is collected by the developer. The app has no servers.

Data leaves the phone only when the user acts, directly to a third party the user chose:

| Data | Sent to | When | Purpose | Optional |
| --- | --- | --- | --- | --- |
| A retail barcode number | Open Food Facts | User scans a bag's barcode | Look up the coffee's name and brand | Yes |
| A roaster name, a city, or a coarse location (rounded search box) | OpenStreetMap Nominatim | User searches for roasters | Find roasters | Yes |
| Brew details or a photo (metadata removed), as shown on screen first | Anthropic or OpenAI, with the user's own key | User taps Send after accepting the disclosure | AI brew advice or reading a journal page | Yes |

Answers for the form:
- Data collected: **None** (transfers above are user-initiated, to services the user chose, and the developer receives nothing). If Google's reviewers count the AI or search transfers as "shared", declare: *App activity → Other user-generated content* (brew notes), *Photos*, *Approximate location*; all optional, not used for ads or analytics, processed ephemerally.
- Data encrypted in transit: **Yes** (https only).
- Users can request deletion: **Yes**, in the app (Settings → Delete all data); there is no server copy.
- Ads: **No**. Analytics: **No**.

## Permissions and why

| Permission | Why |
| --- | --- |
| CAMERA | Scan a bag's barcode or photograph its label. Asked when the user opens the scanner. |
| ACCESS_COARSE_LOCATION | "Use my location" in roaster search, one search, never stored. Asked on that tap. |
| POST_NOTIFICATIONS | The running brew timer's notification. Asked when the first brew starts. |
| FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE | Keeps the user-started brew timer and its step cues running with the screen off. |
| INTERNET | The three user-initiated lookups above. |
| VIBRATE | A tap at each brew step. |

**Foreground service declaration (special use):** "Brew timer: a user-started countdown with step cues (sound and vibration at each brewing step) that must keep running while the screen is off. It stops when the brew ends or the user cancels it." A short screen recording of starting a brew, locking the phone and the step change notification should accompany it.

## Content rating

No user-generated content is shared, no violence, no gambling: expected rating Everyone / PEGI 3.

## Release checklist (Harold)

1. Create an upload keystore and add its four `nextcup.*` lines to `android/local.properties`.
2. `./gradlew bundleRelease` → `android/app/build/outputs/bundle/release/app-release.aab`.
3. Host the privacy policy and paste its URL.
4. Upload the AAB to an internal testing track first, then fill the forms above.
