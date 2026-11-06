# App Store voice of customer: iOS coffee brew apps

Collected 2026-11-06 for Next Cup evolve-001.

## Method and caveats

- The iTunes RSS reviews feed (`itunes.apple.com/.../customerreviews/...json`) was blocked: the sandbox egress proxy refused itunes.apple.com, apps.apple.com and amp-api.apps.apple.com with 403 for curl, and WebFetch reported itunes.apple.com as robots-disallowed.
- Quotes came from public apps.apple.com product pages and `?see-all=reviews` pages (US, GB, CA, AU storefronts) through WebFetch, which turns a page into text and extracts excerpts from it. Excerpts were requested character-for-character and kept under about 120 characters, so most are fragments of longer reviews. No quote is paraphrased here. Because a model did the extraction, spot-check any quote at its URL before you cite it externally.
- These pages do not show per-review star ratings, so the star column is "n/s" (not shown). Review titles hint at sentiment. Dates use the storefront format, normalized to ISO where the year is shown.
- Apps checked that showed no individual reviews: Drippe (id1528844321), Barista – Coffee Timer (id1286975088, 4.7/198, $2.99), Easy Coffee Timer (id6451002421, 4.0/4), Brewly (id6738063344, 5.0/1), Coffee 101 (id1466306762, praise only). Search did not turn up "Kaffeine" or "Brewer's Handbook" listings, and "Brew Guide" matched only a new app with no reviews.
- Tags: **complaint** = something broken or annoying; **missing** = a feature request; **delight** = praise for a specific thing.

## Apps

| App | App Store URL | Rating (count) | Price / IAP |
|---|---|---|---|
| Beanconqueror | https://apps.apple.com/us/app/beanconqueror/id1445297158 | US 4.9 (139 ratings); GB 4.8 (39); AU 4.8 (21) | Free; no IAP listed (a reviewer says nothing is behind a paywall and there are no ads) |
| Filtru – Brew the Best Coffee | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 | US 4.8 (3.8K ratings); GB 4.8 (541); CA 4.7 (366) | Free + IAP: Pro Monthly $3.49, Pro Annual $32.99, Pro Brew Guides $4.99, Pro Lifetime $79.99 |
| Timer.Coffee (Coffee Recipes & Bean Tracker) | https://apps.apple.com/us/app/timer-coffee/id6449322787 | US 5.0 (136 ratings); GB 4.8 (39) | Free; tip-jar IAP only ($1.99 / $4.99 / $9.99) |
| Coffee Book: Brew Journal | https://apps.apple.com/app/id1512681263 | 4.7 (83 ratings) | Free + IAP: Plus annual $4.99–$25.99, Plus $1.99, Plus Lifetime $14.99, Coffee Book $29.99, tips $0.99–$9.99 |
| Single Origin – Coffee Timer | https://apps.apple.com/app/id1480168613 | 4.5 (99 ratings) | $0.99 paid; "Single Origin +" one-time upgrade (price not shown) |
| Pour-Over Coffee Recipes Timer | https://apps.apple.com/us/app/id1615750286 | 4.7 (54 ratings) | Free + IAP: $1.99/month, $12.99/year |
| Brew Timer – Coffee Recipes | https://apps.apple.com/app/id1082171596 | 4.7 (55 ratings) | $2.99 paid; no IAP listed |

## Theme table

114 quotes in total: 35 complaint, 34 missing, 45 delight.

| Theme | Total | Complaint | Missing | Delight |
|---|---|---|---|---|
| logging friction | 11 | 3 | 3 | 5 |
| recipes | 11 | 3 | 4 | 4 |
| timer UX | 11 | 6 | 3 | 2 |
| design/clutter | 9 | 0 | 1 | 8 |
| ratios/scaling | 8 | 1 | 1 | 6 |
| bean inventory | 7 | 0 | 5 | 2 |
| pricing/paywall | 7 | 5 | 0 | 2 |
| stats | 7 | 1 | 3 | 3 |
| grind settings | 6 | 2 | 3 | 1 |
| onboarding/discoverability | 5 | 3 | 0 | 2 |
| bugs/stability | 4 | 4 | 0 | 0 |
| customization | 4 | 2 | 0 | 2 |
| next-brew guidance | 4 | 0 | 3 | 1 |
| sync/export | 4 | 0 | 3 | 1 |
| tasting notes | 3 | 2 | 1 | 0 |
| brew methods | 2 | 1 | 1 | 0 |
| photos | 2 | 0 | 0 | 2 |
| recipe sharing | 2 | 0 | 1 | 1 |
| scale/bluetooth | 2 | 1 | 0 | 1 |
| water/temp | 2 | 1 | 1 | 0 |
| consistency | 1 | 0 | 0 | 1 |
| privacy | 1 | 0 | 0 | 1 |
| widgets/watch | 1 | 0 | 1 | 0 |

## Quotes by app

### Beanconqueror

| # | Tag | Theme | Quote (verbatim) | Author | Date | Stars | Source |
|---|---|---|---|---|---|---|---|
| 1 | missing | timer UX | "What it doesn’t do is give the ability to record weight and start/finish time of each pour for a given brew." | theCoffeeScientist | 2021-06-14 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 2 | complaint | timer UX | "I find the built in timer to be too small and a lot of the icons are not dark enough" | theCoffeeScientist | 2021-06-14 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 3 | complaint | scale/bluetooth | "The scale will disconnect and connect automatically" | Dsvist12 | 2024-02-17 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 4 | delight | logging friction | "The app as a journal is pretty good though" | Dsvist12 | 2024-02-17 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 5 | missing | logging friction | "Changing the date/time of a brew would be great." | dylanriverlopez | 2021-07-08 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 6 | missing | bean inventory | "An option to indicate storage of your beans." | dylanriverlopez | 2021-07-08 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 7 | missing | recipes | "a recipes tab where you can log custom recipes" | Ben Figuly | 2022-12-28 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 8 | complaint | timer UX | "I just don’t think the current system of bloom time and total brew time are specific enough." | Ben Figuly | 2022-12-28 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 9 | delight | customization | "nothing comes close to the breadth of customization and integration that this app offers." | Uselessknowledge | 2024-09-12 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 10 | missing | sync/export | "A few things I would love to see one day would be a user account with cloud syncing, dark mode" | austinburcham | 2022-11-12 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 11 | delight | design/clutter | "It manages to strike a great balance between minimal simplicity and detailed complexity" | austinburcham | 2022-11-12 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 12 | delight | pricing/paywall | "This app is awesome! It is the only app I could find that’s completely free." | Ccrowr14 | 2024-10-11 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 13 | delight | photos | "I enjoy the ability to add pictures of what I’m using." | Ccrowr14 | 2024-10-11 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 14 | delight | stats | "I’m still logging and comparing notes daily" | StewD65 | 2023-04-24 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 15 | missing | logging friction | "it would be nice to be able to log the pressure reached during each brew" | Preston84 | 2022-12-11 | n/s | https://apps.apple.com/us/app/beanconqueror/id1445297158?see-all=reviews |
| 16 | missing | sync/export | "The one major missing feature is cloud sync." | BenBtg | 2025-08-14 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 17 | missing | sync/export | "need to be able to sync data between my iPhone and iPad" | BenBtg | 2025-08-14 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 18 | delight | sync/export | "Photo upload feature is great and even can export stats to excel." | Disappointed EL | 2021-11-29 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 19 | delight | ratios/scaling | "input how much beans and select some common ratio 1:2, 1:3, 1:16 etc or can customise ratio." | Disappointed EL | 2021-11-29 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 20 | delight | customization | "Easy to personalise to the variables you want to track" | Snudg3r | 2025-12-16 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 21 | delight | stats | "a nice summary list of all your brews" | Snudg3r | 2025-12-16 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 22 | delight | logging friction | "Repeating previous brews at the touch of a button?" | Skywalker_Dark79 | 2023-05-23 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 23 | delight | design/clutter | "super intuitive to use and well explained." | Mateusz.Polanski | 2024-04-26 | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 24 | complaint | bugs/stability | "Constantly complaining about some kind of backup issue" | DJ84584 | (Sept, year not shown) | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 25 | complaint | onboarding/discoverability | "The plus (which is presumably to add a brew??) does nothing" | DJ84584 | (Sept, year not shown) | n/s | https://apps.apple.com/gb/app/beanconqueror/id1445297158?see-all=reviews |
| 26 | missing | next-brew guidance | "My only wish is for there to be an option to leave a note for the next brew that pops up" | BenMEight | 2025-08-20 | n/s | https://apps.apple.com/au/app/beanconqueror/id1445297158?see-all=reviews |
| 27 | delight | logging friction | "Lots of control to set it up to suit me, easy to record my daily brew without too much faff." | neponn | 2023-03-24 | n/s | https://apps.apple.com/au/app/beanconqueror/id1445297158?see-all=reviews |
| 28 | missing | recipes | "I would love to see some way to define a recipe for a certain bean type" | neponn | 2023-03-24 | n/s | https://apps.apple.com/au/app/beanconqueror/id1445297158?see-all=reviews |
| 29 | missing | bean inventory | "how about a field in the Beans records to add the processing method Washed, Natural, Honey, etc ?" | Mal_53 | 2023-11-24 | n/s | https://apps.apple.com/au/app/beanconqueror/id1445297158?see-all=reviews |
| 30 | delight | onboarding/discoverability | "This app has such an intuitive interface that it takes only a few goes to work it all out." | Mal_53 | 2023-11-24 | n/s | https://apps.apple.com/au/app/beanconqueror/id1445297158?see-all=reviews |
| 31 | missing | recipes | "Although a more detailed recipe section could be added, currently just using methods" | Loldfhfbj | 2025-07-18 | n/s | https://apps.apple.com/au/app/beanconqueror/id1445297158?see-all=reviews |

### Filtru – Brew the Best Coffee

| # | Tag | Theme | Quote (verbatim) | Author | Date | Stars | Source |
|---|---|---|---|---|---|---|---|
| 32 | delight | ratios/scaling | "I love the customization of the app e.g. water to grounds to cup ratio as well as the coffe/brewing notes." | I.M. Fit | 2025-09-21 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 33 | delight | stats | "I can always look back on my brew notes to help me decide to buy again or to change my brewing ratio." | I.M. Fit | 2025-09-21 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 34 | complaint | logging friction | "you have to specify your output volume or weight ahead of time, and after you pull a shot you cannot tweak it" | Plastikos | 2023-03-16 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 35 | complaint | logging friction | "it does not let you actually record what happened with each shot in a stepwise fashion" | Plastikos | 2023-03-16 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 36 | complaint | recipes | "Also the brew guides are very rudimentary" | Plastikos | 2023-03-16 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 37 | missing | grind settings | "I wish there was a better way to record grind size and roast level (Dark/Light)." | NativeIndie | 2023-06-28 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 38 | missing | logging friction | "I’d like a way to record my TDS measurements from using a refractometer." | NativeIndie | 2023-06-28 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 39 | delight | scale/bluetooth | "This app works wonderfully with a Bluetooth, smart scale and my iPhone." | NativeIndie | 2023-06-28 | n/s | https://apps.apple.com/us/app/filtru-brew-the-best-coffee/id1150921819 |
| 40 | complaint | timer UX | "Why does the total time counter not continue when you pause the flow?" | vamkiwavkw | 2022-11-07 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 41 | missing | timer UX | "You need to add a real, immutable total time elapsed timer." | vamkiwavkw | 2022-11-07 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 42 | missing | recipes | "I would love to see the possibility to add a field for extra information to each recipe/or each step." | Kama4o | 2017-11-25 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 43 | missing | widgets/watch | "Only thing missing is an Apple Watch companion app" | Themistryman | 2022-02-19 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 44 | delight | timer UX | "I particularly like the audio cues when to move on to the next step." | Fender Jim | 2021-12-29 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 45 | delight | consistency | "This app has drastically improved the consistency in brewing my coffee" | Fender Jim | 2021-12-29 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 46 | delight | design/clutter | "Love the look and feel of this app, clearly a lot of work has gone into it." | Aapptastic | 2022-08-19 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 47 | complaint | bugs/stability | "particularly in the guide creating functionality and saving brew details" | Alex Canning | 2020-05-18 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 48 | complaint | bugs/stability | "There are quite a few bugs of the irritating and frustrating kind." | Alalsacienne | 2022-08-17 | n/s | https://apps.apple.com/gb/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 49 | complaint | ratios/scaling | "When using chemex, the timer does not update based on grams of coffee or amount of water selected" | Zoblart | (Jul 25, year not shown) | n/s | https://apps.apple.com/ca/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 50 | complaint | timer UX | "I really hate the new feature that changes the time for a recipe when the previous brew took longer." | Stephen780 | (May 21, year not shown) | n/s | https://apps.apple.com/ca/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 51 | complaint | pricing/paywall | "Free version lets you make a brew but you need a pro version to even look at your previous pours." | Helohoss | (Mar 21, year not shown) | n/s | https://apps.apple.com/ca/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 52 | complaint | pricing/paywall | "What a joke. Another predatory subscription app to use basic features" | Joe Beveridge | 2025-11-15 | n/s | https://apps.apple.com/ca/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 53 | complaint | pricing/paywall | "$45 a year just takes notes is ridiculous." | oirvine | 2024-05-02 | n/s | https://apps.apple.com/ca/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 54 | complaint | pricing/paywall | "such as the clever dripper and espresso, now require the PRO version." | notaprof | 2024-04-29 | n/s | https://apps.apple.com/ca/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |
| 55 | delight | recipes | "The variety of brew methods takes a lot of the thinking out and helps visualize output." | Kucci1 | 2024-11-23 | n/s | https://apps.apple.com/ca/app/filtru-brew-the-best-coffee/id1150921819?see-all=reviews |

### Timer.Coffee (Coffee Recipes & Bean Tracker)

| # | Tag | Theme | Quote (verbatim) | Author | Date | Stars | Source |
|---|---|---|---|---|---|---|---|
| 56 | missing | timer UX | "Please add a sound that goes when the timer is done." | dan84582 | (May 20, year not shown) | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 57 | complaint | onboarding/discoverability | "I am not seeing the feature anywhere." | dan84582 | (May 20, year not shown) | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 58 | delight | logging friction | "Love all the recipe options and ability to add notes and beans with each brew." | JarHeadButter | 2025-06-16 | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 59 | delight | recipes | "I love being able to have many different recipes and step by step directions all in one app!" | 021Y | (Jun 12, year not shown) | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 60 | delight | pricing/paywall | "Only one without annoying ads" | VybzKartel13 | (Jul 20, year not shown) | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 61 | delight | ratios/scaling | "it reduced the stress of figuring out the ratios and time to pour" | Jeremy Gerritsen | 2025-02-17 | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 62 | delight | design/clutter | "Love the simplicity of this app." | Jeremy Gerritsen | 2025-02-17 | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 63 | delight | onboarding/discoverability | "it also links directly to helpful how-to videos." | Andy Spyros | (Jul 4, year not shown) | n/s | https://apps.apple.com/us/app/timer-coffee/id6449322787?see-all=reviews |
| 64 | delight | design/clutter | "It makes my coffee routine a no-brainer." | ACLAXNG | 2024-10-05 | n/s | https://apps.apple.com/gb/app/timer-coffee/id6449322787?see-all=reviews |

### Coffee Book: Brew Journal

| # | Tag | Theme | Quote (verbatim) | Author | Date | Stars | Source |
|---|---|---|---|---|---|---|---|
| 65 | missing | grind settings | "I only wish there was a category to input grinder rpm settings" | Gotfart? | 2022-02-09 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 66 | missing | stats | "Perhaps being able to graph flow control profiles would be a nice add on in the future as well." | Gotfart? | 2022-02-09 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 67 | delight | photos | "Allows for excellent data input to dial in each roast along with being able to add specific notes and photos." | Gotfart? | 2022-02-09 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 68 | delight | design/clutter | "the app just feels GOOD to use" | Y2Kbotz | 2024-06-29 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 69 | delight | next-brew guidance | "great tools for identifying how to improve your coffee making" | Y2Kbotz | 2024-06-29 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 70 | complaint | customization | "it lacks customizability, and the abilty to create your own" | Pineapple Hippy | 2022-10-03 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 71 | missing | grind settings | "the ability to turn off details, like RPM, my grinder is very basic" | Pineapple Hippy | 2022-10-03 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 72 | delight | recipes | "I really like the guide feature" | Pineapple Hippy | 2022-10-03 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 73 | delight | privacy | "Doesn’t harvest data, and it’s a reasonable one-time purchase." | kbizz12 | 2025-07-12 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 74 | missing | bean inventory | "the shots pulled in the dialing-in phase should be calculated in the total usage of a bag" | kbizz12 | 2025-07-12 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 75 | missing | next-brew guidance | "it would be great to see deviations from the recipe" | kbizz12 | 2025-07-12 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 76 | missing | stats | "I would add some graphs or charts they compare the same brewers" | B Interface | 2021-03-30 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 77 | complaint | tasting notes | "Tasting notes are extremely limited." | RoxyPhillips | (Jan 26, year not shown) | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 78 | missing | tasting notes | "please add custom varieties and custom tasting notes" | RoxyPhillips | (Jan 26, year not shown) | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 79 | missing | bean inventory | "I hope you add the ability to manually add varietals." | parappapraggy | 2025-02-10 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 80 | delight | bean inventory | "Been using it to record all the beans I bought." | parappapraggy | 2025-02-10 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 81 | complaint | water/temp | "When creating a recipe it displays the field in F but does a conversion from C to F" | Gtduser13 | 2025-03-13 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 82 | complaint | recipes | "however the AP seems to be an after thought." | Gtduser13 | 2025-03-13 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |
| 83 | missing | brew methods | "My only suggestion is to add the Kalita Wave" | Drew DeCuir | 2021-05-02 | n/s | https://apps.apple.com/app/id1512681263?see-all=reviews |

### Single Origin – Coffee Timer

| # | Tag | Theme | Quote (verbatim) | Author | Date | Stars | Source |
|---|---|---|---|---|---|---|---|
| 84 | complaint | stats | "there is no way to filter through your notes" | E Dyer | 2020-10-29 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 85 | missing | stats | "would also be nice to be able to select / move / order notes" | E Dyer | 2020-10-29 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 86 | delight | bean inventory | "love this app, helps me keep track of the beans i use and how well each brew turns out." | E Dyer | 2020-10-29 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 87 | complaint | tasting notes | "the tasting notes field hasn’t worked for me" | rdevitt | 2025-08-10 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 88 | complaint | bugs/stability | "Trying to edit it freezes the interface and I have to force close the application." | rdevitt | 2025-08-10 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 89 | missing | ratios/scaling | "it’d be great if the recipes would explain the logic of their internal equations a little better" | rdevitt | 2025-08-10 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 90 | delight | ratios/scaling | "I love that it allows you to adjust the recipe and ratio too." | Nannabree | 2021-12-22 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 91 | missing | next-brew guidance | "add a setting to choose how dark you want to make the brew." | M_Raffle | 2020-04-14 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 92 | delight | grind settings | "has settings for my new grinder which is helpful!" | M_Raffle | 2020-04-14 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 93 | complaint | onboarding/discoverability | "It appears as if they removed the cold brew pour over from the list which is a bit annoying." | Ocoee Boater | 2019-10-11 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 94 | delight | design/clutter | "Beautiful, intuitive, and thoughtful." | CaptainCobbler | 2024-10-19 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 95 | delight | ratios/scaling | "Like the timing functionality and a water the grounds ratio that I can adjust to 1 or 2 cups" | Stvo92 | 2025-12-10 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 96 | complaint | grind settings | "The limited list of grinders (6 total, and one is a $3000 commercial unit) is not even shown prior to purchase" | tennr | 2020-02-17 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |
| 97 | complaint | brew methods | "Be sure your brew method is listed." | tennr | 2020-02-17 | n/s | https://apps.apple.com/app/id1480168613?see-all=reviews |

### Pour-Over Coffee Recipes Timer

| # | Tag | Theme | Quote (verbatim) | Author | Date | Stars | Source |
|---|---|---|---|---|---|---|---|
| 98 | complaint | recipes | "I have saved two new recipes using the 'custom' tab, but it is tedious." | gikeith1 | 2025-10-02 | n/s | https://apps.apple.com/us/app/id1615750286?see-all=reviews |
| 99 | delight | ratios/scaling | "Good inventory of big name recipes and does all the math for you." | DanGreenfield90 | 2023-05-01 | n/s | https://apps.apple.com/us/app/id1615750286?see-all=reviews |
| 100 | complaint | timer UX | "Because the app wont display the exact weight, the the timing function for the app is useless." | Jaye Kay | (Jan 2, year not shown) | n/s | https://apps.apple.com/us/app/id1615750286?see-all=reviews |
| 101 | complaint | timer UX | "the pour has already drained by the time the timer has even reached the halfway mark" | Jaye Kay | (Jan 2, year not shown) | n/s | https://apps.apple.com/us/app/id1615750286?see-all=reviews |
| 102 | missing | recipe sharing | "Biggest issue: Let us copy and paste recipes!" | Jaye Kay | (Jan 2, year not shown) | n/s | https://apps.apple.com/us/app/id1615750286?see-all=reviews |
| 103 | complaint | customization | "Simple app that doesn’t give the user much flexibility in customization." | Jaye Kay | (Jan 2, year not shown) | n/s | https://apps.apple.com/us/app/id1615750286?see-all=reviews |
| 104 | complaint | pricing/paywall | "when I try to select, restore purchases it freezes." | JamesM4life | 2025-03-12 | n/s | https://apps.apple.com/us/app/id1615750286?see-all=reviews |

### Brew Timer – Coffee Recipes

| # | Tag | Theme | Quote (verbatim) | Author | Date | Stars | Source |
|---|---|---|---|---|---|---|---|
| 105 | missing | water/temp | "I’d love to see water temperature as a first class parameter that could also be adjusted from the journal." | Kevin Condon | (Apr 7, year not shown) | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 106 | delight | logging friction | "The journal is the feature I didn’t know I needed." | Kevin Condon | (Apr 7, year not shown) | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 107 | delight | recipes | "I love that the pro experts recipes are there and that you can adjust them as needed and save." | Scott77889 | 2021-07-16 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 108 | complaint | grind settings | "It also doesn’t seem to remember the grinder I use, even though I have tried updating it a couple times." | yonkdaddy | 2023-04-03 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 109 | missing | bean inventory | "Would love to see future updates that include the ability to snap pictures of coffee bags/containers" | Uly.K.M | 2020-04-12 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 110 | delight | recipe sharing | "Makes sharing recipes with other coffee enthusiasts extremely easy." | Uly.K.M | 2020-04-12 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 111 | missing | design/clutter | "make font auto size when recipe title is long, so entire title can fit in the frame" | kevvermeister | 2020-12-21 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 112 | complaint | logging friction | "Specifically the “stepped” sliders are very finicky and don’t let you easily pick amounts." | johnjacobjake | 2018-03-05 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 113 | delight | timer UX | "it gives me all the freedom to setup a timer the way I want." | FullProof45 | 2019-11-14 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |
| 114 | delight | design/clutter | "it’s one of the most important apps on my phone." | joel.ml | 2025-04-30 | n/s | https://apps.apple.com/app/id1082171596?see-all=reviews |

## Implications for small Next Cup changes (about 40 minutes each)

- **Timer UX** (11 quotes, 6 complaints): a timer that is too small, no chime at the end (or one users cannot find), a total elapsed time that stops on pause, and per-pour steps that ignore actual weights. Small wins: a large always-on total-elapsed clock, a visible end-of-brew chime toggle on the timer screen, and a current/next pour target in grams shown at large size.
- **Logging friction** (11): users want to edit the date/time of a brew, record what actually happened rather than only the plan, and repeat a previous brew in one tap. Small wins: an editable timestamp, "Brew again" from history, and a quick edit of the result after the timer ends.
- **Recipes** (11) and **recipe sharing** (2): custom recipes are "tedious" to make, and users ask for copy/paste of recipes and a recipe tied to a specific bean. Small wins: duplicate a recipe, share or paste it as text, and pin a default recipe to a bean.
- **Next-brew guidance** (4 missing): "leave a note for the next brew that pops up" and "see deviations from the recipe" back Next Cup's one-change suggestion. Small win: show last time's suggestion or note as a banner when the next brew of that bean starts.
- **Bean inventory** (5 missing): processing method, varietals, storage, bean usage that counts dial-in shots, and photos of bags. Small wins: a processing-method picker, and counting every brew against the bag weight.
- **Pricing/paywall** (5 complaints, all Filtru): history locked behind Pro, and methods moved to Pro. Free, private and no-account is a real differentiator to state on screen.
- **Stats** (7): filter/sort notes, and charts that compare brews. Small win: filter history by bean or method.
- **Tasting notes** (3): the presets are too limited. Allow custom tasting-note chips.
- **Water/temp** (2): temperature as a first-class field, and a unit-conversion bug. Check that the °C/°F display and the stored value agree.
- **Sync/export** (4) and **widgets/watch** (1): cloud sync between iPhone and iPad, CSV/Excel export, and an Apple Watch app. These are mostly too large for 40 minutes, except a CSV export.
