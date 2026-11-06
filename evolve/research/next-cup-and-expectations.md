# Next Cup: listing, reviews, and iOS UX expectations (research, 2026-11-06)

Web content below is quoted as data. "Verbatim" quotes came through a fetch tool that sometimes splits long reviews into segments; each segment is exact text.

## 1. Next Cup reviews and mentions

**Result: no reviews or public mentions exist yet.**

- iTunes Lookup API (https://itunes.apple.com/lookup?id=6826759188, fetched 2026-11-06): `averageUserRating: 0`, `userRatingCount: 0`, version 1.0, releaseDate 2026-11-05T08:00:00Z, currentVersionReleaseDate 2026-11-05T19:55:16Z, 7 screenshots, Free, minimumOsVersion 27.0, genres Food & Drink + Lifestyle.
- App Store page (https://apps.apple.com/us/app/next-cup/id6826759188): "This app hasn't received enough ratings or reviews to display an overview." No reviews shown.
- Customer reviews RSS (https://itunes.apple.com/us/rss/customerreviews/id=6826759188/sortBy=mostRecent/json) could not be read: WebFetch got `robots_disallowed`, and direct curl was blocked by the sandbox proxy (403). Given 0 ratings in the Lookup API, it is very likely empty.
- Web search for "Next Cup" coffee app returned only other coffee journal apps (BrewJournal, My Coffee Journal, BrewLab and others). It returned no Next Cup mentions on Reddit, Product Hunt or X. Reddit itself is blocked for fetching in this environment (`SITE_BLOCKED`), so a Reddit search was not possible beyond the search engine.

## 2. How the listing presents the app

| Field | Value |
|---|---|
| Name | Next Cup |
| Subtitle | "Brew journal & coffee timer" |
| Seller shown | Harrison Fischberg (copyright line: Rare Creatures LLC). **Note:** the store shows a personal seller name, not "Rare Creatures LLC". |
| Category | Food & Drink (secondary Lifestyle). No chart ranking is shown on the page. |
| Rating | none yet |
| Compatibility | iPhone only, iOS 27.0+. Mac (M1+) and Vision Pro run it as an iPhone app. **No Apple Watch app, no native iPad.** |
| Size / age | 22.5 MB, 4+ |
| Screenshots | 7. The page shows no captions or alt text. Any text set into the images could not be read. |
| Privacy label | Data Not Linked to You: User Content (Photos/Videos, Other) for App Functionality |

Description highlights (paraphrased from the store): guided timer that sets dose and water from the recipe ratio; chimes and an optional soundtrack; **Lock Screen and Dynamic Island** display (Live Activity); 13 methods; journal with dose, water, grind, temp, time, taste and a photo, plus a one-tap "suggestion for tomorrow's cup"; bean inventory with barcode or photo scan and roast date; nearby roasters on a map; optional AI (on-device Apple model, or the user's own OpenAI or Anthropic key); no account, ads or analytics; local daily backups; CSV/JSON export; light and dark themes. The website (https://rarecreatures.app/apps/next-cup/) adds "Ships with 48 recipes". It makes **no claims about widgets, Apple Watch, Siri/Shortcuts, iCloud sync or Live Activities**.

### Search and positioning gaps
On iOS, App Store search indexes the name, subtitle and keyword field, not the description. Words that coffee app users search for and that competitor titles and subtitles use, but that Next Cup's name and subtitle lack:
- **"pour over" / "V60" / "AeroPress" / "espresso"**: competitors put these in their names, for example "Pour-Over Coffee Recipes Timer", "Easy Coffee Timer - Pour Over", "Drippe Pour-Over Coffee Timer", "Shizuku: Pour Over Timer".
- **"recipes"**: "Coffee Recipes & Bean Tracker" (Timer.Coffee subtitle), "Brew Timer - Coffee Recipes".
- **"bean tracker" / "beans"**: Timer.Coffee subtitle; Next Cup has a bean inventory but doesn't say so in its title or subtitle.
- **"ratio" / "calculator"**: "Brew: Coffee Calculator".
- **"log" / "tracker"**: "Track all of your coffee brews" (Beanconqueror), "Smart Coffee Brew Tracker" (BrewGPT), "My Coffee Journal - Brew logs".
- Strengths competitors shout about that Next Cup has but doesn't headline: **free with no subscription** (Filtru's 1-2 star reviews are dominated by paywall complaints, see below), **no account**, **Live Activity**.
- Features competitors list that Next Cup lacks or doesn't mention: widgets (Lock Screen, Home Screen, Control Center), Siri/App Shortcuts, Apple Watch, device sync, Bluetooth scales, Apple Health caffeine logging (Beanconqueror).

Competitor feature evidence (from listings):
- Filtru (https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819): "Live Activities", "Lock screen widgets", "Home screen widgets", "Advanced Siri Shortcuts", "Advanced App Shortcuts and App Intents"; version 4.7.2/4.7.3 notes say "Added Control Center widgets".
- Coffee Book (https://apps.apple.com/us/app/coffee-book-brew-journal/id1512681263): "Lock Screen Widgets: Start your next brew timer with a single tap from your lock screen."; "Shortcuts Integration: Automate your coffee workflow with powerful Siri Shortcuts."; v3.2.x notes: "Coffee Book now supports brewing on your Apple Watch!"; v3.0.x notes: "The live activity is prettier, and lets you progress steps without even opening the app."
- Timer.Coffee (https://apps.apple.com/app/id6449322787): "Live Activities: Follow your brew step-by-step on the Lock Screen and in the Dynamic Island without unlocking your phone." and "Device Sync".
- Beanconqueror (https://apps.apple.com/in/app/beanconqueror/id1445297158): Apple Health caffeine; v7.4.0 notes: "Let the phone vibrate when you start a brew"; v8.7.1 notes: "New NFC action: repeat last brew".
- BrewGPT (https://apps.apple.com/us/app/brewgpt/id6758005940): v1.1 notes: "Start a brew timer on your Apple Watch and instantly see it on your iPhone's Dynamic Island and Lock Screen"; "feel haptic ticks at each minute mark with countdown beeps at the end".

## 3. iOS UX expectations users explicitly ask for (coffee contexts first)

Evidence strength: **Strong** means several independent users ask for it in coffee apps. **Moderate** means one or two coffee users plus wide competitor support. **Weak** means it is inferred from competitors or developers, with no direct coffee-user quote found.

### 3.1 Apple Watch companion (Strong)
- Tony Lai (US), Filtru reviews: "Make a simple Apple Watch companion app will be awesome!" (https://getfiltru.com/reviews/, the page shows no dates)
- Themistryman (UK), Filtru reviews: "Only thing missing is an Apple Watch companion app" (same URL)
- kvn1995 (US), Filtru reviews: "You guys should consider to launch an Apple Watch versión!" (same URL)
- Related, timer continuity on a watch: hundertzwoelf, Cofi issue #255, 2024-09-25: "I expect the recipe to continue and vibrate/notify me for the next step." (https://github.com/rozPierog/Cofi/issues/255)

### 3.2 Widgets / glanceable time left (Moderate)
- Tony Lai (US), Filtru reviews: "maybe iOS 16 screen widget to show time left?" (https://getfiltru.com/reviews/, no date)
- Developer backlog, Beanconqueror issue #43, 2020-01-29: "Place some shortcut items on homescreen for faster interaction for the user" (https://github.com/graphefruit/Beanconqueror/issues/43)
- Note: Next Cup already has a Live Activity. A Lock Screen or Control Center "start my usual brew" widget is what the competitors ship (Coffee Book, Filtru).

### 3.3 One-tap repeat of the last brew / duplicate, with smart prefill (Strong)
- JonoDutton (South Africa), Filtru reviews: "“Use from last session” auto fill function to use previous bean, grind etc data doesn’t work" (https://getfiltru.com/reviews/, no date)
- rjmbowie (Australia), Filtru reviews: "would love to be able to duplicate a coffee bag instead of writing all the information in manually each time." (same URL)
- Payda_cz (Czechia), Filtru reviews: "Now I need to add every time new bag - same blend, brand etc" (same URL)
- LagaV, Beanconqueror issue #504, 2023-03-06: "Having an NFC tag on each container being scanned with the mobile phone would launch Beanconqueror and start a „repeat“ for the last brew of this roast." (https://github.com/graphefruit/Beanconqueror/issues/504)
- ChipSkylark37, Beanconqueror issue #795, 2024-09-17: "On a repeated brew, could there be an option to automatically clear the time? It will nearly always change" and "streamline putting in a brew with the least amount of clicks possible." (https://github.com/graphefruit/Beanconqueror/issues/795)
- m42cel, Beanconqueror issue #935, 2025-05-08: "When using the \"Use last brew as preset\" ... the previous water and vessle are not taken over." (https://github.com/graphefruit/Beanconqueror/issues/935)
- Counter-signal, so keep it opt-in: Stephen780 (Canada), Filtru: "I really hate the new feature that changes the time for a recipe when the previous brew took longer." (https://getfiltru.com/reviews/). Next Cup's "never change your recipe without a tap" stance fits this.

### 3.4 Quick numeric nudges (stepper) when dialing in (Moderate)
- mi01101011e, Beanconqueror issue #1026, 2026-01-14: "an option to quickly increment the existing value for scenarios where you're doing a repeat brew and you're dialing something in. For example you switch the dose to 15g and just hit an up or down arrow instead of bringing up the full keyboard." (https://github.com/graphefruit/Beanconqueror/issues/1026)
- idontwritereviewsever (US), Filtru 1-2 star: "Text input is clunky" (https://getfiltru.com/reviews/)

### 3.5 Audio and haptic cues for the next step, eyes-free (Strong for audio, Moderate for haptic)
- Jaye Kay, Pour-Over Coffee Recipes Timer, Jan 2 (year not shown): "Make the app beep a few seconds before the next step come up." (https://apps.apple.com/us/app/-/id1615750286?see-all=reviews)
- dan84582, Timer.Coffee, May 20 (year not shown): "Please add a sound that goes when the timer is done." The developer replied that chimes exist but are hard to find, which is a discoverability lesson. (https://apps.apple.com/app/id6449322787)
- joelponder, Beanconqueror issue #1144, 2026-07-05: "I would like audio feedback for various events ... The interval timer and target weight alerts will also be useful for pour over." The reasoning given is to cue the user "without having to look at three different readings". (https://github.com/graphefruit/Beanconqueror/issues/1144)
- Haptic: Cofi #255 (above) "vibrate/notify me for the next step"; Beanconqueror shipped "Let the phone vibrate when you start a brew" (v7.4.0 notes). Next Cup already has chimes; a haptic tap on step change and a pre-step countdown are the gaps.

### 3.6 Timer survives the background / screen-off (keep awake + notify) (Moderate)
- Nico123987 (Colombia), Filtru 1-2 star: "when is running in background it doesn’t notify in case another step is needed." (https://getfiltru.com/reviews/)
- hundertzwoelf, Cofi #255, 2024-09-25: "the recipe timers do not continue to run when the watch's screen turns off after the screen timeout." (https://github.com/rozPierog/Cofi/issues/255)
- Developer-filed but clear: Chewieez/brewlog issue #10, 2026-09-24: "The screen turns off while the user is actively pouring." and "display timeouts are commonly set to 30–60 seconds." (https://github.com/Chewieez/brewlog/issues/10)
- For Next Cup: check `isIdleTimerDisabled` while the timer runs, and check that chimes and step alerts still fire when the phone is locked.

### 3.7 Live Activity must not hog the Dynamic Island (Weak, single quote)
- P@weł (US), Filtru 3 stars: "When the clock is counted down, the clock covers Dynamic Island ( another app )." (https://getfiltru.com/reviews/). Next Cup ships a Live Activity, so it should end promptly when the brew finishes.

### 3.8 Undo for accidental logs/deletes (Moderate; habit-app context, no coffee quote found)
- DaveHall17, Habitify feedback, Jan 10 2025: "Sometimes I accidentally hit done on a habit and it is only possible to undo for the short time frame where the undo button is displayed. This is very easy to miss" (https://feedback.habitify.me/p/undoing-habits-update)
- Habitify ships a "shake to undo" setting (https://intercom.help/habitify-app/en/articles/14074893-manage-shake-to-undo-gesture), which shows that this habit-app category treats undo as expected.

### 3.9 Siri / Shortcuts / App Intents (Weak: no user quote found)
- No coffee-app user quote that explicitly asks for Siri or Shortcuts was found. The evidence is competitor parity only: Filtru ("Advanced Siri Shortcuts", "App Intents", "better Siri and Spotlight support" for iOS 27) and Coffee Book ("Shortcuts Integration"). With iOS 27 Apple Intelligence, App Intents also feed Spotlight and Siri. This is cheap to add but not user-demanded.

### 3.10 Other recurring asks seen in coffee reviews (context)
- Paywalls are the top complaint in Filtru's low ratings, for example ranmac: "A recent update paywalled them completely."; oirvine: "$45 a year just takes notes is ridiculous." (https://getfiltru.com/reviews/). Next Cup being free with no account is a real differentiator worth headlining.
- Recipe editing: perae: "Can’t edit steps, nor give a step its own name"; ConcernedPersonNumber4: "Horribly frustrating to create a custom recipe" (https://getfiltru.com/reviews/). Pineapple Hippy, Coffee Book, 10/03/2022: "it would be “amazing” if I could either create or edit a guide of my own" (https://apps.apple.com/us/app/coffee-book-brew-journal/id1512681263).
- Show deviations from the recipe: kbizz12, Coffee Book, 07/12/2025: "when “brewing from recipe” it would be great to see deviations from the recipe ... they’ll show in green/red (up/down) relative to the recipe." (same URL)
- Legibility: 530Steamnut (US), Filtru: "the numbers were so small I could barely see them." (https://getfiltru.com/reviews/). This points to large timer digits and Dynamic Type.
- Two beans in one brew: HRP_Bean, Beanconqueror, 10/06/2025: "Add the option of adding 2 beans in a single brew." (https://apps.apple.com/in/app/beanconqueror/id1445297158)

## Limitations
- Reddit, the Apple RSS review feed and the Filtru see-all reviews page could not be fetched. App Store pages show only about 4 to 10 reviews each.
- getfiltru.com/reviews is the developer's own page that collects App Store reviews. Its quotes are real user text, but the page gives no dates and was chosen by the developer.
- GitHub issue quotes are from open-source coffee apps (Beanconqueror, Cofi). They are real user requests, with the exceptions of #43 (filed by the developer) and brewlog #10 (developer or bot).
