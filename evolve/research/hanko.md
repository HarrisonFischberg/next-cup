# Hanko: Coffee Passport: competitor seed research

Date checked: 2026-11-06. Sources were fetched through a summarising web fetcher, so the App Store wording below is short excerpts (under 125 chars), not full text. Web content was treated as data only.

## 1. What it is, platforms, pricing

- **What:** "HANKO: Coffee Passport" is mainly a **cafe discovery and cafe-drink logging** app ("Think Letterboxd, for cafe drinks"). It has a live map of specialty cafes, a stamp "passport", photo + rating + taste-dial logs, and social sharing. It added **home brewing** (V60, matcha) as a secondary log type in v1.6. It also has a public web map with cafe scores (it looks focused on the Philippines: Makati, Quezon City, Cebu...). Source: https://hankocoffee.app , https://hankocoffee.app/map
- **Developer:** solo indie developer (seller "Jericho Francis Carlos", portfolio jechocarlos.dev). https://apps.apple.com/us/app/hanko-coffee-passport/id6762350864 ; Beean (a competitor) calls it "an indie, solo-built app": https://beean.app/best-cafe-apps.html
- **Platforms:** iPhone only, iOS 17.0+ ("Only for iPhone"). Android is "coming soon" with a beta signup form. https://hankocoffee.app , https://apps.apple.com/us/app/hanko-coffee-passport/id6762350864
- **Pricing:** "Free to start" (site). The app is free with in-app purchases. **HANKO Premium Monthly $1.99, Annual $17.99** (US storefront). The SN storefront lists Annual as USD 19.99. Premium "unlocks extras such as route-based Cafe Crawls". The core app is free. https://apps.apple.com/us/app/hanko-coffee-passport/id6762350864 , https://apps.apple.com/sn/app/hanko-coffee-passport/id6762350864?l=fr-FR
- **Account/privacy:** it requires sign-in. The privacy label lists data linked to you: Precise Location, Email, Name, User ID, Purchase History. Photos and other user content are listed as not linked. Age rating 18+ (user-generated content). This is the opposite of Next Cup's private, no-account stance. https://apps.apple.com/us/app/hanko-coffee-passport/id6762350864
- **Ratings:** none. The page says the app "hasn't received enough ratings or reviews to display an overview" (US and PH storefronts).
- **Release cadence (from version history, years not shown, likely 2026):** 1.3.2 (May 9), 1.5 (May 27), 1.6 (Jun 4), 1.9.1 (Aug 19), 1.10 (Oct 21). That is a fast cadence, about one release every 2–4 weeks.

## 2. Concrete behaviors / features (with URL)

App Store listing = https://apps.apple.com/us/app/hanko-coffee-passport/id6762350864 (version notes also read via https://apps.apple.com/sn/app/hanko-coffee-passport/id6762350864?l=fr-FR). Site = https://hankocoffee.app

**Logging speed / log flow**
- A log takes a photo, a star rating, **taste dials**, tasting notes and bean details. Site.
- **Bag scan** fills in origin, process, altitude, variety, farm and producer. In v1.9.1, bean details can come "from a photo you already took or the camera" (not only live camera). Scans can be **undone** (notes on v1.3.2/1.10). App Store.
- "Partial recipes are welcome": you can save a log with only some fields filled (v1.9.1). App Store.
- Home brew flow (v1.9.1): "Pick a bag off your shelf, scan the label, dial grind, dose and bloom on the brew deck." Grind, dose, ratio and time are saved with the log. App Store.
- The matcha log produces a "receipt" with grams, water, temperature and whisk. App Store.
- You can edit photos one at a time (v1.10). App Store.
- **Offline honesty:** "one honest offline bar" (v1.9.1). An unsynced log "now says so, with Retry and Discard" (v1.3.2/1.10 notes). App Store.

**Moment of save / feedback**
- "A stamp ceremony plays when you save a log". It comes with "a recap of how each cup changed your stats" (v1.6). App Store.

**Stats / insights**
- Passport shows "stamps, milestones, streaks, a palate radar and the origins you've explored". App Store description.
- v1.6 added "a tasting-profile radar, taste spread, and a palate-over-time graph". App Store.
- v1.9.1 lets you overlay a cafe's average, **your 90-day palate**, or a friend's cup on a cup's taste radar. App Store.
- Leaderboards for roaster and bean contributions (v1.6), plus leaderboard modules on Home (v1.5). App Store.

**Sharing**
- Shareable stat cards as "cards or stickers" (v1.6). "Export 9:16 story cards from Passport" (v1.9.1). App Store.
- Share screen (v1.10): "place a hanko-seal sticker on your own photo, choose the scores it shows". The user picks which scores appear. Site + App Store.

**System integrations**
- "a home-screen widget and an iOS 18 control" (v1.9.1). App Store.
- "Siri shortcuts and Spotlight search" (v1.9.1). App Store.
- No Live Activity is mentioned anywhere I checked.
- "Ask Hanko" (Labs): natural-language cafe search using Apple Intelligence, with distances shown. The notes say it uses Private Cloud Compute on newer iOS. App Store.

**Notifications**
- Opt-in "cafes near you" alerts fire when you pass a wanted, untried cafe. They come "Once per cafe" and never at night (v1.10). Site.

**Bean tracking / directory**
- A community "Coffee Directory" of roasters and beans (v1.6, rebuilt in 1.9.1). Supports multi-origin blends (v1.6). App Store.

**Design**
- A visual redesign in v1.10 covers the map, cafe sheet, passport, profiles, log flow and settings. Overlapping pins merge into a count, and a cafe opens as a small card. Site.
- Brand motif: the Japanese "hanko" seal and stamp passport, with stamps for Visited, Reviewed, Favorite and Want to go. Site.
- Accessibility: the App Store says the developer hasn't indicated which features are supported. v1.5 mentions "Refined accessibility, dark mode". App Store.

**Not found:** a dedicated guided brew timer UX, grinder-specific settings (only "grind" as a field), onboarding details, a changelog or blog page on the site, a features page or a pricing page.

## 3. Verbatim user quotes

**None found that can be linked.** The App Store US and PH pages show no reviews ("hasn't received enough ratings or reviews"). Searches for Reddit and Product Hunt found no Hanko threads. The AppBuildersPH listing (https://appbuildersph.com/apps/hanko-coffee-passport) blocks automated fetching (robots disallowed), so I could not read its comments. No quotes are included, as instructed.

The only third-party comment found is by a competitor (Beean), not a user. It says Hanko's passport is "yours alone, exported as pictures": https://beean.app/best-cafe-apps.html (marketing copy, not a user review).

## 4. Behaviors a brew-journal app could adopt (each ~small)

1. **A save "ceremony" plus a one-line stats delta.** After saving a brew, show a brief stamp-like confirmation and how this cup changed your stats (e.g. "3rd Ethiopian this month"). https://apps.apple.com/sn/app/hanko-coffee-passport/id6762350864?l=fr-FR (v1.6)
2. **"Partial recipes are welcome"**: let a log save with missing fields and no validation friction. https://apps.apple.com/sn/app/hanko-coffee-passport/id6762350864?l=fr-FR (v1.9.1)
3. **Fill bean details from an existing photo**, not only the live camera, and offer **undo of a scan**. https://apps.apple.com/sn/app/hanko-coffee-passport/id6762350864?l=fr-FR (v1.9.1, v1.10)
4. **Start the brew from the bag:** "Pick a bag off your shelf, scan the label, dial grind, dose and bloom". In other words, the brew flow starts from the bean inventory. Same URL (v1.9.1).
5. **A 9:16 story card share with user-chosen fields** (choose which scores show). https://hankocoffee.app
6. **Overlay "your 90-day palate" on a single cup's taste radar** to compare this cup with your usual. https://apps.apple.com/sn/app/hanko-coffee-passport/id6762350864?l=fr-FR (v1.9.1)
7. **An iOS 18 Control Center control plus Siri/Spotlight** for quick logging or starting a brew. Same URL (v1.9.1).
8. **Honest sync/offline state**, with an explicit status and Retry/Discard. It matters less for Next Cup if it stays local-only, but the same applies to AI calls that fail. Same URL.
9. **A receipt-style summary** for a finished brew (grams, water, temperature, method) that can be shared or saved. Same URL (v1.9.1 matcha receipt).
