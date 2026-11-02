# Next Cup privacy policy

_Last updated: October 2026 · applies to Next Cup 0.1 · published by Rare Creatures LLC_

**Status (2026-10-30): superseded. The published policy is the source of truth: https://rarecreatures.app/apps/next-cup/privacy/ (`apps/next-cup/privacy/index.html` in the studio-site repo). Change that page, not this file. This draft is kept for history; it was never reviewed by a lawyer. Since this draft: with no key, AI uses Apple's on-device model and nothing leaves the iPhone; brew-size tuning with a keyed provider waits for a tap. 2026-11-01: the published page now also covers Improve with AI, Create with AI, Ask AI for Next Cup, the provider-side web search with sources, and QR-code links (studio-site PR, lawyer review still deferred). 2026-11-01, later: Ask AI for Next Cup also sends up to 8 of your other brews with the same method (studio-site PR); the separate brew tip was removed.**

Next Cup is an iPhone coffee brew journal. It keeps everything **on your phone**. It has no server, no account, no analytics and no advertising, and Rare Creatures LLC receives none of your data. This document says exactly what it stores, what it can send and when, and how to erase everything.

## What Next Cup stores (on this device)

| Where | Contents |
| --- | --- |
| Next Cup's database on your phone | Your brews (date, method, recipe, beans, dose, water, grind, temperature, time, optional TDS, grade, taste, notes, optional photo), recipes and steps, brew methods, beans and roasters (name, origin, process, roast level and date, flavor notes, bag weight, remaining amount, freeze and thaw dates, optional photo), water profiles, your own taxonomy aliases, saved suggestions, and AI requests while they are waiting or running (the request text and any photo, removed when the request ends) |
| Drafts | A brew you are typing, saved so a relaunch does not lose it |
| Backups | Up to seven daily copies of your data, photos included, kept on the phone. A brew you delete can still be in a backup for up to seven days |
| Settings | Units, your remembered filters, which AI provider and model you chose for each feature, and that you read the AI notice |
| The iOS Keychain | Your OpenAI or Anthropic key, if you add one. It stays on this device, is not synced, and is not included in exports or backups made by Next Cup |
| The Lock Screen and Dynamic Island | While a timer runs, the recipe name, the step and the time are shown by iOS from this device. Nothing is sent anywhere |

Next Cup does not store your location, contacts, browsing history or any account details. Your phone's own iCloud or computer backup may include Next Cup's files, according to your iOS settings.

## When Next Cup uses the network

Only in these cases:

- **AI features (optional, off until you add a key and accept the notice for that provider).** Each action sends only the data listed here, directly from your phone to the provider you picked, using your own key. You see a preview before a brew diagnosis or insights request is sent.
  - **Brew diagnosis:** the one brew you ask about: date, method, bean origin, process and roast, dose, water, grind, temperature, time, taste, grade and your notes.
  - **Insights:** the same details for up to the 8 most recent brews of one coffee.
  - **Bag recognition and photo interpretation:** one photo, with location and camera data removed, and a fixed instruction.
  - **Recipe tuning and review:** when you tap Tune on Start brew, the recipe name, brewer and that batch's dose, water, temperature and time. When you tap Improve with AI on a recipe, its name, brewer, the name of the grinder you used last, dose, water, temperature, time, every step with its instruction, and the note you typed. When you tap Create with AI, the brewer and grinder you pick and what you type. Suggestions change nothing until you choose to use them, and a new recipe is kept only when you save it. When you tap Ask AI for Next Cup on a past brew, that brew's date, method, recipe name and steps, bean name, roaster, roast, origin, process and bag flavors, dose, water, grinder and grind, temperature, time, taste, rating and your notes, plus up to 8 of your other brews with the same method (same bean or similar dose and water first), each with its date, recipe name, bean name, roaster and roast, dose, water, grinder and grind, temperature, time, taste, rating and notes (a web search first uses only the brewer, grinder, roast and taste); the answer is saved on your phone as your Next Cup recipe, replacing the earlier one for that method. When you save a brew with a taste or rating, and it is your newest with that method, the same is sent without a further tap, with only your rated or tasted brews of that method and a similar dose and water, and the answer replaces your Next Cup recipe for that method. You can turn this off in Settings, AI.
  - **Paper import:** one photo of a handwritten journal page, in full, with location and camera data removed. Everything written on the page is sent.
  Apart from saving a brew as described above, nothing is sent until you tap, and never without a key. The provider handles the request under its own terms, may keep it, and may charge your own account. Rare Creatures LLC never sees these requests. The copy of a photo and the request text held for the request are deleted from your phone when it finishes, fails or is cancelled, and the answer to a photo request is deleted as soon as you have used it. A bag photo you read while adding a bean is kept on that bean, on your phone only, until you remove it in Edit or delete the bean. You can remove the key at any time.
- **Roaster search (optional).** When you search for roasters or match a bag to a roaster, the text you search for goes to Apple Maps (for a roaster match, the roaster's name followed by "coffee roaster"; for the roaster search, the map area or the city you typed). If you tap "Use my location", iOS asks first and Next Cup asks for your approximate location (you can still allow precise); it is used for that search only. Next Cup keeps only roasters you choose to save, with the roaster's details, not your position.

- **Barcode lookup (optional).** When you scan the barcode on a coffee bag, only the barcode number is sent to Open Food Facts (world.openfoodfacts.org), a free public product database, to look up the coffee's name and brand. Nothing else goes with it: no account, no identifier and no location. The answer is filled into the form for you to check, and nothing is saved until you tap Save. The camera view used for scanning stays on your phone and is not recorded.

- **QR codes on bags (optional).** When you scan a QR code on a coffee bag and it holds a web link, Next Cup opens that link once, the way a browser would but without cookies, to read the coffee's details from the page. The website the code points to (usually the roaster's) sees that request, including your IP address, under its own terms; nothing else is sent. A QR code that is not a link is read on your phone only. What the page says is filled into the form for you to check, and nothing is saved until you tap Save.

Any other request is not made by the app. Photos are picked with the system photo picker, so Next Cup cannot see the rest of your library. When you choose Take a photo, iOS asks for camera access first; the camera is used only while it is open.

## What Rare Creatures LLC collects

Nothing: no identifiers, no usage data, no crash reports of its own, no contact details. Apple may share crash data and analytics with developers if you allow it in iOS settings.

## Children

Next Cup is not directed at children and collects no personal information from anyone, so it has no age gate.

## Your controls

- **Export** your journal data (brews, recipes, beans, methods and more) as CSV or JSON; the AI request log and the photos sent to providers are not part of it, **import** with a preview that never overwrites silently, and **restore** a backup.
- **Delete everything** in Settings > Your data (it removes your data, drafts, backups and AI keys, and offers Undo for a short time).
- **Remove your AI key** in Settings > AI to stop every AI request.
- Deny location in iOS Settings; delete the app to remove its data from this phone.

## App Store privacy label (decision recorded 2026-10-25, to confirm in App Store Connect)

Not "Data Not Collected". Because a photo or your notes can go to OpenAI or Anthropic when you tap an AI action, the label declares **Photos or Videos** and **Other User Content**, used for App Functionality, not linked to you and not used for tracking. The app's privacy manifest says the same. Rare Creatures LLC itself receives none of this data; the declaration is deliberately cautious.

## Contact

Rare Creatures LLC · hello@rarecreatures.app · rarecreatures.app

Business address: not provided yet (UNKNOWN).

## Changes

When this policy changes, the date at the top changes. UNKNOWN: how changes will be announced to users; to decide before publishing.
