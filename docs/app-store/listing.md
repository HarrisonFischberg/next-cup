# App Store submission pack: Next Cup 1.0 (iOS)

Everything to paste into App Store Connect for the first release. Written
2026-10-30 from the code at this branch. Each claim below is something the
app does today; nothing here compares Next Cup to another app.

The owner does every App Store Connect step himself; see
`owner-checklist.md` for the order.

## App information

| Field | Value |
| --- | --- |
| Name (30) | Next Cup |
| Subtitle (30) | Brew journal & coffee timer |
| Bundle ID | `app.rarecreatures.nextcup` |
| SKU | `nextcup-ios` (any unique text; never shown) |
| Primary language | English (U.S.) |
| Primary category | Food & Drink |
| Secondary category | Lifestyle |
| Version | 1.0 (`MARKETING_VERSION`), build number from `scripts/archive-testflight.sh` |
| Price | Free, no in-app purchases |
| Copyright | 2026 Rare Creatures LLC |
| Privacy policy URL | https://rarecreatures.app/apps/next-cup/privacy/ |
| Support URL | https://rarecreatures.app/apps/next-cup/support/ |
| Marketing URL (optional) | https://rarecreatures.app/apps/next-cup/ |
| Devices | iPhone only, iOS 27 or later |

If "Next Cup" is already taken as an App Store name, App Store Connect says so
when the app record is created. Fallback: "Next Cup: Brew Journal".

## Promotional text (170, can change without review)

Log a brew in seconds, taste it, and get a clear suggestion for tomorrow's cup. Your journal stays on your iPhone.

## Description (4000)

Next Cup is a coffee brew journal for people who brew with a scale and a kettle and want tomorrow's cup to be better than today's.

BREW WITH A TIMER THAT KNOWS THE RECIPE
Pick a brewer and a style, set how much coffee you want with simple − / + steppers (hold one for a dial), and the dose and water follow the recipe's ratio. The timer walks you through each pour and wait, with chimes, an optional soundtrack that keeps playing when you leave the app, and the current step on your Lock Screen and in the Dynamic Island.

THIRTEEN WAYS TO BREW
Cone and flat-bed drippers, switchable immersion, press pot and inverted press, espresso, iced pour over, cold brew, moka pot, AeroPress, Chemex, drip machine and Nespresso, each with its own styles and starting recipes.

A JOURNAL THAT LEARNS YOUR TASTE
Save each brew with its dose, water, grind, temperature, time, taste and a photo. Tell Next Cup how the cup tasted, and it suggests one change for next time, built from the recipe and your recent brews of the same coffee. A suggestion only changes your recipe when you tap to use it. Ask AI for Next Cup turns a past brew and your similar brews into an improved recipe, pinned at the top of the Brew tab.

YOUR BEANS, ORGANIZED
Keep each bag with its roaster, origin, process, roast date and flavor notes. Scan the bag's barcode or QR code, or take a photo, to fill in the details, see how much is left, and find coffee roasters near you on the map.

RECIPES YOU CAN CHANGE
Change a recipe's steps before you brew, delete the ones you no longer use, or describe a cup and let Create with AI write the recipe, with a grind to start from on your grinder.

AI THAT STAYS OPTIONAL
With no key, AI features use Apple's on-device model where it is available, and nothing leaves your iPhone. You can add your own OpenAI or Anthropic key instead; Next Cup shows what each action sends before the first request and sends nothing until you tap, or until you save a brew you tasted or rated, which writes your Next Cup recipe (you can turn that off in Settings).

PRIVATE BY DESIGN
No account, no ads, no analytics and no server of ours. Your journal stays on your iPhone, with daily backups on the phone, export to CSV or JSON, and one place to delete everything.

Make it yours with several looks, light and dark.

## Keywords (100, comma separated, no spaces after commas)

```
pour over,brew,timer,grind,beans,roaster,recipe,dial in,log,barista,espresso,cold brew,ratio,tasting
```

Exactly 100 characters. Words already in the name and subtitle (next, cup,
coffee, journal) are left out because Apple indexes those anyway. No brand
or competitor names, to stay clear of guideline 2.3.7.

## What's New (version 1.1)

Same text as `store/ios/metadata/en-US/release_notes.txt`:

- Ask AI for Next Cup: turn a past brew into an improved recipe, pinned at the top of the Brew tab. It reads your similar brews, and can write your Next Cup each time you save a tasted brew (turn that off in Settings > AI).
- Create with AI: describe the cup you want and get a full recipe, with a suggested grind for your grinder. Improve with AI rewrites a recipe's steps for your note.
- Change steps on Start brew, and delete your own recipes from the Brew tab.
- − / + steppers for grind, amount and dose. Hold one for a fine dial.
- Scan the QR code on a coffee bag to fill in the bean.
- Brew music keeps playing when you leave the app, at a gentler volume.
- Every look is now in Settings > Appearance.

## Age rating

Answer **None / No** to every content question (violence, sexual content,
profanity, horror, gambling, alcohol/tobacco/drugs, medical, contests). For
the capability questions: no unrestricted web access, no user-generated
content shared with others, no messaging or chat between users, no
advertising. Expected result: **4+**. Coffee is not an age-restricted
substance under Apple's questionnaire. If the form asks about AI-generated
content, answer that the app makes brewing suggestions from the user's own
data and does not generate open-ended chat.

## App Privacy (the "nutrition label")

Decision of 2026-10-25, kept. The app's `PrivacyInfo.xcprivacy` says the same.

- Tracking: **No**.
- Data collected: **Yes**, two types:
  - **Photos or Videos**: purpose App Functionality; not linked to the user; not used for tracking.
  - **Other User Content** (brew notes and journal entries, recipes and their steps, bean details and text typed for Create with AI, sent for an AI answer): purpose App Functionality; not linked; not used for tracking.
- Everything else: not collected.

Why not "Data Not Collected": a photo or brew notes leave the phone to OpenAI
or Anthropic when the user adds their own key and taps an AI action.
Over-declaring is the safer error. Roaster search goes to Apple Maps (Apple's
own service) and a barcode lookup sends only the barcode number to Open Food
Facts; neither is personal data.

Rechecked 2026-11-01 against Improve with AI, Create with AI, Ask AI for Next
Cup (PR #76) and QR-code links: **no change to the answers**. The new AI
features send recipe, bean and brew text, which is Other User Content, still
only to the user's own provider on a tap. The provider's web search runs on
the provider's side with the brewer, grinder, roast, taste or typed text, so
the developer collects nothing new. A QR link is opened from the phone like a
browser would; the site sees the request, the developer collects nothing.
Nothing to change in App Store Connect.

Rechecked 2026-11-08 for 1.2 against Brew advice for a bean (PR #83): the bean's
details, the typed taste goal and the brewer names are Other User Content sent
only to the user's own provider on a tap; Apple's model keeps it on the phone.
**No change to the answers.** The published policy has the matching bullet
(studio-site PR #42).

Rechecked 2026-11-08 for 1.3 against Send Debug Logs (PR #86): the app only
opens a draft in the user's own email app, which they read and send
themselves; the app sends nothing. **No change to the answers.** The published
policy already covers it ("If you email us, we receive what you choose to send").

Rechecked 2026-11-09 for 1.4 against the bean AI flow (PR #88: front and back of
the bag as one image), brewer size in recipe requests (PR #90) and the journal
recipe line (PR #91, on device only): photos and recipe text still go only to the
user's own provider on a tap. **No change to the answers.** The published policy
gained the two matching lines (studio-site PR #45).

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is already in `Config/NextCup-Info.plist`,
so App Store Connect should not ask. If it does: the app uses only HTTPS through
Apple's URLSession and the iOS Keychain, which is exempt. Answer **No**
non-exempt encryption; no export documentation needed. No French encryption
declaration needed.

## Content rights

The app contains third-party content: Unsplash photos (Unsplash License) and
public-domain or CC0 music, listed in `docs/asset-licenses.md`. Answer **Yes,
it contains third-party content, and I have the rights to use it**.

## App Review information

- Sign-in required: **No** (there are no accounts).
- Contact: the owner's name, phone and email (owner fills in; not stored here).
- Notes (paste as is):

```
Next Cup is a coffee brew journal. There is no account or sign-in; everything is stored on the device.

To try the main flow: tap Brew, choose a brewer (for example Cone dripper), pick a style, then Start brew. The timer runs through the steps. Finish, rate the taste, and the Journal shows the brew with a suggestion for the next one.

AI features: with no key, Next Cup uses Apple's on-device Foundation Models where Apple Intelligence is available, and nothing leaves the device. Users can optionally add their own OpenAI or Anthropic API key in Settings > AI. Before the first request to a provider, the app shows a notice listing exactly what each action sends, and nothing is sent until the user accepts it and taps an action. We do not provide a demo key; the on-device path covers the same screens.

Permissions: camera only when the user taps Take a photo or scans a bag's barcode or QR code; location only when the user taps Use my location in roaster search (a typed city works without it); notifications only for an optional reminder to taste a saved brew.

Network use: Apple Maps for roaster search, Open Food Facts for barcode lookups (barcode number only), the link on a bag's QR code when the user scans one (opened once, like a browser, to read the coffee's page), and the user's own AI provider if they add a key (for Create with AI and Ask AI for Next Cup the provider may also run up to three web searches on its own side). No analytics, ads or tracking.

Privacy policy in the app: Settings > Privacy > Read the full privacy policy.
```

## Screenshots

Upload one set for the **6.9-inch iPhone display**; App Store Connect scales it
down for the smaller iPhones. Size **1320 × 2868** portrait (1290 × 2796 is
also accepted). PNG or JPEG, no transparency, 1 to 10 shots. No iPad set: the
app is iPhone only.

Capture on the largest-screen iPhone simulator in Xcode (the Pro Max model)
in the Sunday Studio look, mixing light and dark, with sample data only:

| # | Screen | Caption idea |
| --- | --- | --- |
| 1 | Brew tab, brewer picker | Thirteen ways to brew |
| 2 | Start brew with "How much coffee?" set | Set the amount, the recipe follows |
| 3 | Timer mid-pour | A timer that knows every pour |
| 4 | Taste and rating after a brew | Tell it how it tasted |
| 5 | Journal with a suggestion card | One clear change for tomorrow |
| 6 | Beans list or a bean with its roaster | Your beans and roasters, organized |
| 7 | Live Activity on the Lock Screen (if it can be captured) | The step on your Lock Screen |
| 8 | Settings > Privacy | No account, no ads, no server |

Captions are optional; plain screenshots are fine for 1.0. App previews
(video) are optional and skipped.
