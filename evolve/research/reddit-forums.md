# Voice of customer: forums, HN and feature-request boards (Next Cup evolve-001)

Collected 2026-11-06. Every quote below is exact text from the linked page. Nothing inside quotation marks is paraphrased; `...` marks a cut. HTML entities in HN comments are decoded (`&#x27;` is shown as `'`).

## Read this first: source coverage

- **Reddit (r/pourover, r/Coffee, r/espresso, r/AeroPress, r/ios, r/iosapps) could not be reached in this session.** reddit.com and old.reddit.com are blocked at the egress proxy. The Redlib mirrors refuse automated fetches (robots or an Anubis bot check), and the Pushshift and Arctic Shift archives returned errors. Thread titles turned up in search, for example r/espresso "What tools do you use to remember different beans?" (2024-12-04) and r/JamesHoffmann "Coffee apps" (2025-03-23), but their comment text could not be retrieved verbatim, so none of it is used here.
- **Home-Barista** (the Beanconqueror thread t68236 and "Feedback for my pourover tracking app" t99334) was blocked too (client_error). The two Barista Hustle Discourse app-feedback threads loaded, but neither has any replies.
- **Sources that did work:** public GitHub issue trackers, which serve as the feature-request boards of three open-source coffee apps:
  - Beanconqueror, the biggest free brew-log app on iOS and Android
  - Timer.Coffee, a guided pour-over timer for iOS, Android and web
  - Cofi, an Android brew timer

  Also used: Hacker News (Show HN threads for coffee-tracking apps) and Product Hunt reviews.
- **What this means:** these quotes come from enthusiasts who take the trouble to file GitHub issues. They lean toward power users, so treat the counts as directional. Feature-request boards are close to "what I wish the app did", which is the evidence this cycle needs.

Tags: **complaint** (something hurts today), **missing** (asks for a feature that doesn't exist), **delight** (praise for something that works).

---

## Timer UX

1. **complaint**: "When I'm brewing coffee but I want to switch a song or reply to a message I leave the timer.coffee app. The timer does not keep up for more than 2-4 seconds."
   jakubbenko, Timer.Coffee #46, 2025-08-22. https://github.com/antonkarliner/timer-coffee/issues/46
2. **complaint**: "Timer should continue running in the background even when switching to a different app."
   rsuplido, Timer.Coffee #45, 2025-06-07. https://github.com/antonkarliner/timer-coffee/issues/45
3. **complaint**: "I sometimes find myself accidentally closing the app while waiting for my coffee to brew. When I reopen the app my coffee timer is completely reset and even though I can skip steps I cannot fast forward the timers in any way so it's difficult to pick up where I left off."
   deltainium, Cofi #147, 2023-01-18. https://github.com/rozPierog/Cofi/issues/147
4. **complaint**: "Anyway I love the app, I'd love it more if it beeped."
   rodmitch, Timer.Coffee #84 ("Notifications do not make sound"), 2026-09-11. https://github.com/antonkarliner/timer-coffee/issues/84
5. **complaint**: "Beep/Ding sound stopped working in v3.4.5 (iOS)."
   rsuplido, Timer.Coffee #58, 2025-11-03. https://github.com/antonkarliner/timer-coffee/issues/58
6. **missing**: "Sometimes I'm not looking at my phone and I need to either go back a step or advance manually in case I lost track or if I'm intentionally trying to move quicker than the recipe asks."
   samtsai, Timer.Coffee #69, 2026-02-02. https://github.com/antonkarliner/timer-coffee/issues/69
7. **missing**: "During brewing process, would be nice to see what is the next step. As to stir or pour is quite different thing, and one requires kettle, another one spoon (or somethign else)."
   szymonk92, Timer.Coffee #40 ("Grayed out instruction what would be next"), 2024-11-17. https://github.com/antonkarliner/timer-coffee/issues/40
8. **missing**: "Showing the *total* time left instead of just the current step would be useful too"
   notDavid, Timer.Coffee #27, 2024-02-11. https://github.com/antonkarliner/timer-coffee/issues/27
9. **missing**: "Add a button to finish/stop the recipe early, and return Home (somewhere at the bottom left, like the Pause button)"
   notDavid, Timer.Coffee #27, 2024-02-11. https://github.com/antonkarliner/timer-coffee/issues/27
10. **missing**: "Having a button to signal end of brew, that might be before or after the recipe time. This would be useful if the grind was changed or different beans to see where it lands."
    ueen, Timer.Coffee #77, 2026-05-31. https://github.com/antonkarliner/timer-coffee/issues/77
11. **complaint**: "I would like an optional setting that when enabled will auto pause the timer after each step. Global or recipe specific setting. I always feel rushed as I may not keep up with the timer"
    krohrsb, Cofi #227, 2023-10-02. https://github.com/rozPierog/Cofi/issues/227
12. **complaint**: "A couple of times I accidentally tapped on one of the upcoming steps and didn't even noticed that the timer has changed until it was obvious that my brew has been completely ruined."
    ar-lex, Cofi #174, 2023-04-26. https://github.com/rozPierog/Cofi/issues/174
13. **complaint**: "Please have Cofi either count DOWN the timer or make it an option. A count up timer is unintuitive."
    gordol1, Cofi #188, 2023-07-04. https://github.com/rozPierog/Cofi/issues/188
14. **missing**: "I would like audio feedback for various events. These events could be: first drops, intervals at 5 or 10 seconds, weight within a certain range of a target weight, weight at target."
    joelponder, Beanconqueror #1144, 2026-07-05. https://github.com/graphefruit/Beanconqueror/issues/1144
15. **complaint**: "However, I always have to manually reset the brew timer. If I forget to do that, the current brew is appended to the existing time..."
    reox, Beanconqueror #509, 2023-03-21. https://github.com/graphefruit/Beanconqueror/issues/509

## Widgets / Live Activity

16. **missing**: "The beep should still work and maybe a notification should have popped up for the next step"
    rsuplido, Timer.Coffee #45, 2025-06-07. https://github.com/antonkarliner/timer-coffee/issues/45

## Apple Watch / wearables

17. **complaint**: "When using my OnePlus Watch 2, the recipe timers do not continue to run when the watch's screen turns off after the screen timeout."
    hundertzwoelf, Cofi #255, 2024-09-25. https://github.com/rozPierog/Cofi/issues/255

## Logging friction

18. **complaint**: "every day i have to type in the same amount of water. It keeps resetting back to the default value (250 ml) every time you re-open the app (regardless whether you set it as favorite or not);"
    notDavid, Timer.Coffee #25 ("Remember last entered water amount"), 2024-01-31. https://github.com/antonkarliner/timer-coffee/issues/25
19. **missing**: "there could also be an option to quickly increment the existing value for scenarios where you're doing a repeat brew and you're dialing something in."
    mi01101011e, Beanconqueror #1026, 2026-01-14. https://github.com/graphefruit/Beanconqueror/issues/1026
20. **missing**: "For example you switch the dose to 15g and just hit an up or down arrow instead of bringing up the full keyboard."
    mi01101011e, Beanconqueror #1026, 2026-01-14. https://github.com/graphefruit/Beanconqueror/issues/1026
21. **complaint**: "I just lost my carefully created bean entry for a new bean."
    dannybloe, Beanconqueror #1001 ("Confirm on cancel"), 2025-12-19. https://github.com/graphefruit/Beanconqueror/issues/1001
22. **complaint**: "When filling out the optional general/variety info, the terms you would type in the name field are typically just a tedious repeat of that info."
    keldian, Beanconqueror #1199, 2026-10-27. https://github.com/graphefruit/Beanconqueror/issues/1199
23. **complaint**: "Date and time of records in the Brew Diary cannot be edited."
    lbtbs, Timer.Coffee #83, 2026-08-23. https://github.com/antonkarliner/timer-coffee/issues/83
24. **complaint**: "I do remember the ratios and date, but now I can't add them to their respective dates."
    simplysaru, Beanconqueror #302, 2022-01-19. https://github.com/graphefruit/Beanconqueror/issues/302
25. **missing**: "I don't launch the app while I make my coffee. Instead I just read and remember the relevant parameters to enter them later"
    benedetto, Beanconqueror #199, 2021-04-02. https://github.com/graphefruit/Beanconqueror/issues/199
26. **complaint**: "I just dislike clicking through form field entries to add new local recipes."
    780Farva, Timer.Coffee #72, 2026-04-06. https://github.com/antonkarliner/timer-coffee/issues/72
27. **missing**: "For people using different brew methods (e.g. filter and espresso) it would be nice to be able to repeat a past brew."
    stefanheyder, Beanconqueror #26, 2019-06-09. https://github.com/graphefruit/Beanconqueror/issues/26
28. **complaint**: "I usually have multiple bags of espresso beans open at the same time. Thus, I use the "repeat brew" feature quite often, as I would like to "copy over" the grind and machine settings."
    reox, Beanconqueror #509, 2023-03-21. https://github.com/graphefruit/Beanconqueror/issues/509

## Grind settings

29. **missing**: "Normally I don't change "Grind Setting" and "Brew Temperature", so a predefined value would help."
    LagaV, Beanconqueror #496, 2023-02-22. https://github.com/graphefruit/Beanconqueror/issues/496
30. **missing**: "A new entry **"Show grind settings"** in the actions menu of a bean opens an overview of the grind settings used with that bean, taken from the existing brews"
    tim-g-02, Beanconqueror #1196, 2026-10-18. https://github.com/graphefruit/Beanconqueror/issues/1196
31. **complaint**: "Currently its easy to forget about changing the RPM when switching grinders, even though you will more often than not keep the same RPM for a grinder when using the same brew method."
    HoustonPutman, Beanconqueror #1123, 2026-04-22. https://github.com/graphefruit/Beanconqueror/issues/1123
32. **missing**: "would it be feasible to auto populate BQ field when/after creating a new brew, based off of the information selected for the "Preparation Method" and "Grinder" Selections?"
    Silvermane06, Beanconqueror #1172, 2026-09-06. https://github.com/graphefruit/Beanconqueror/issues/1172
33. **missing**: "One thing that would be cool to see is the ability to list the gear you have and get custom suggestions. For instance, instead of "medium-coarse", the app could know which grinder I have and recommend a specific setting."
    tiltowait, HN "Show HN: We're two coffee nerds who built an AI app to track beans and recipes", 2025-07-01. https://news.ycombinator.com/item?id=44430901
34. **missing**: "The name grinder and the settings of the grinder"
    Ardakilic, Timer.Coffee #63 ("Extend Recipes with brewer and Grinder details"), 2025-11-23. https://github.com/antonkarliner/timer-coffee/issues/63

## Ratios / scaling

35. **missing**: "I'd like to just decouple and change the grams, would that make sense or is there another way to easily modify ratio from existing recipes?"
    ueen, Timer.Coffee #75, 2026-05-30. https://github.com/antonkarliner/timer-coffee/issues/75
36. **complaint**: "This is correct for ingredient weights and volumes, but it also incorrectly scales values that should remain constant (e.g., brewing temperature, pressure values or repetitions)."
    sbezavvs, Timer.Coffee #52, 2025-09-24. https://github.com/antonkarliner/timer-coffee/issues/52
37. **complaint**: "Instead or along side of "Weight multiplier" have it so, you can type in the specific amount of coffee grams you want to brew with (currently "Weight multiplier" skips some grams sometimes, because the adjustment isn't fine enough)"
    witherik, Cofi #150, 2023-01-30. https://github.com/rozPierog/Cofi/issues/150
38. **missing**: "I think I go with James Hoffmann, that for filter the 1:x brew ratios are a bit "ugly" to use. I would prefer to see this as g/l instead of the 1:x ratios."
    reox, Beanconqueror #244, 2021-08-03. https://github.com/graphefruit/Beanconqueror/issues/244
39. **complaint**: "In moka pots, a lot of water always remains in the bottom part and dos not affect the brew at all. Therefore it only makes sense to use _beverage quantity_ for calculation the _brew ratio_."
    jon-jm, Beanconqueror #464, 2023-01-08. https://github.com/graphefruit/Beanconqueror/issues/464
40. **complaint**: "Observe that it will use 300 ml water instead - the default value"
    notDavid, Timer.Coffee #24 (4:6 method ignores entered amount), 2024-01-20. https://github.com/antonkarliner/timer-coffee/issues/24

## Design / clutter

41. **complaint**: "the home screen looks a but cluttered and the removable collection screams feature creep."
    ueen, Timer.Coffee #76 ("home redesign"), 2026-05-30. https://github.com/antonkarliner/timer-coffee/issues/76
42. **missing**: "display the top 5 most used favourite recipes on top (sometimes I brew one cup, sometimes half a liter and if it gets hot an iced v60 so it's nice too have a few favourites/most brewed directly on home)."
    ueen, Timer.Coffee #76, 2026-05-30. https://github.com/antonkarliner/timer-coffee/issues/76
43. **complaint**: "I think it's essential to not fall for feature creep and only keep essential info and data in the app and not cater to every users whim"
    ueen, Timer.Coffee #77, 2026-05-31. https://github.com/antonkarliner/timer-coffee/issues/77
44. **complaint**: "Once you add upwards of 5-6 recipes in the app, the recipe list starts appearing cluttered and it's a little difficult finding the recipe you need."
    AmaryllisVFX, Cofi #202, 2023-07-28. https://github.com/rozPierog/Cofi/issues/202
45. **missing**: "My primary actions are: Adjusting the weight and starting the recipe. These two actions could live in a bottom bar for easier reach."
    JuliusLoewe, Cofi #145, 2023-01-07. https://github.com/rozPierog/Cofi/issues/145
46. **complaint**: "The flat design looks very outdated and boring"
    sinfulz, Beanconqueror #1170 (asks for iOS 26 Liquid Glass tab bar), 2026-08-31. https://github.com/graphefruit/Beanconqueror/issues/1170
47. **complaint**: "This is quite misleading to me, because it now looks like my lightly roasted beans have a very bad rating."
    m42cel, Beanconqueror #973 (roast level drawn with stars), 2025-10-20. https://github.com/graphefruit/Beanconqueror/issues/973
48. **missing**: "Personally I'd like to be able to customize what parameters I can see in the Brews overview without needing to show the Details."
    silasg, Beanconqueror #101, 2020-09-20. https://github.com/graphefruit/Beanconqueror/issues/101
49. **missing**: "I'd like to optionally (new setting) display them as only one field "In/Out (BR)" with a value like "18g/36g (1:2)". This would save a lot of space"
    silasg, Beanconqueror #99, 2020-09-20. https://github.com/graphefruit/Beanconqueror/issues/99
50. **complaint**: "when I saw this for the first time I was under the impression that I had already archived the bean."
    mihirgarikiparithi, Beanconqueror #339 (menu label "archived" vs "archive"), 2022-03-15. https://github.com/graphefruit/Beanconqueror/issues/339
51. **complaint**: "Labels cut off (Screenshot 1) if larger system font size is used (Screenshot 2)."
    kasamdor, Cofi #250, 2024-05-12. https://github.com/rozPierog/Cofi/issues/250

## Onboarding

52. **complaint**: "Why only accept Google/Apple accounts? Why even require an account? :("
    whoamii, HN "Show HN: We're two coffee nerds who built an AI app...", 2025-06-30. https://news.ycombinator.com/item?id=44429001
53. **complaint**: "the text in each screen of the onboarding flow is cut off on my iPhone 14"
    wjgilmore, same HN thread, 2025-06-30. https://news.ycombinator.com/item?id=44429010
54. **missing**: "I have to admit that I'm just going to start using the app. So far I have entered all the available coffee beans and searching now for an option to adjust the remaining (or already consumed) beans from an open bag."
    Ragos81, Beanconqueror #968, 2025-10-12. https://github.com/graphefruit/Beanconqueror/issues/968

## Bean freshness / inventory

55. **missing**: "Sometimes I have a few opened packs of coffee and would like to know how much I have in total (to know when to order a new coffee)."
    adamulacha, Timer.Coffee #78 ("My Beans amount left summary"), 2026-06-08. https://github.com/antonkarliner/timer-coffee/issues/78
56. **missing**: "the list should be sorted by Amount Left."
    adamulacha, Timer.Coffee #79 (bean picker during brew), 2026-06-12. https://github.com/antonkarliner/timer-coffee/issues/79
57. **missing**: "best before/opened on + possible notification of opened too long/use it soon"
    vgorova, Timer.Coffee #48, 2025-09-06. https://github.com/antonkarliner/timer-coffee/issues/48
58. **missing**: "adding eg 200 g and count down based on usage in the app? I am currently having a separate list"
    vgorova, Timer.Coffee #48, 2025-09-06. https://github.com/antonkarliner/timer-coffee/issues/48
59. **missing**: "it'd be great that if we could add a new optional field called URL, to store where we bought the beans from."
    Ardakilic, Timer.Coffee #62, 2025-11-23. https://github.com/antonkarliner/timer-coffee/issues/62
60. **missing**: "Best flavor and viewing period of coffee beans"
    xxy9468615, Timer.Coffee #71, 2026-03-25. https://github.com/antonkarliner/timer-coffee/issues/71
61. **missing**: "Currently we're displaying the roast time/date, but instead (optional) or in addition we could have a relative time such as "2 days ago"."
    DeastinY, Beanconqueror #22, 2019-04-24. https://github.com/graphefruit/Beanconqueror/issues/22
62. **complaint**: "When adding a brew and selecting beans, I usually see an empty page, as I have no un-frozen beans in the database."
    reox, Beanconqueror #860, 2024-12-25. https://github.com/graphefruit/Beanconqueror/issues/860
63. **complaint**: "If I freeze some portions of a bag of beans, these currently become new individual "beans", which is confusing in many aspects."
    katexochen, Beanconqueror #986, 2025-11-20. https://github.com/graphefruit/Beanconqueror/issues/986
64. **missing**: "Currently the consumed and remaining amounts only show on beans list view—would be great if this showed (or was an option to show) in detail view"
    b-dod, Beanconqueror #1015, 2026-01-01. https://github.com/graphefruit/Beanconqueror/issues/1015
65. **missing**: "It whould be great to have seperate information on the dashboard how much coffee is left and how much of that is decaf"
    alclonky, Beanconqueror #1032, 2026-01-23. https://github.com/graphefruit/Beanconqueror/issues/1032
66. **missing**: "Imagine taking pic of coffee bag and the fields such as roaster, bean type, process, etc are filled in automatically"
    tokenstar, Beanconqueror #192, 2021-03-27. https://github.com/graphefruit/Beanconqueror/issues/192 (Next Cup's photo scan already covers this.)
67. **missing**: "I find the webpage for a particular bag has a bunch more info not usually found on the bag"
    cgturner1, Beanconqueror #1152, 2026-07-17. https://github.com/graphefruit/Beanconqueror/issues/1152

## Stats / insights (incl. rating)

68. **missing**: "Distribution of brew scores for every time a bean was brewed (mean as well as distribution because consistency is important)"
    tokenstar, Beanconqueror #187, 2021-03-27. https://github.com/graphefruit/Beanconqueror/issues/187
69. **missing**: "I like to see my best brews and the relation to the parameters like grind settings, temperature, pressure in combination with the roast of the beans - to find out best settings."
    sebastian-tischer, Beanconqueror #156, 2021-01-11. https://github.com/graphefruit/Beanconqueror/issues/156
70. **complaint**: "The only thing I am missing - which currently leads to double usage of excel + app - is to have custom charts/statistics in the app."
    sebastian-tischer, Beanconqueror #156, 2021-01-11. https://github.com/graphefruit/Beanconqueror/issues/156
71. **missing**: "it would be even better if there could be a settings option to automatically calculate bean rating based on the average of all the brews associated with that bean."
    danielzsandberg, Beanconqueror #915, 2025-03-23. https://github.com/graphefruit/Beanconqueror/issues/915
72. **missing**: "This way, users can quickly reference their best espresso and best pour-over recipe for the same coffee, without mixing up the results."
    LawrenceLiu023, Beanconqueror #1022 ("Track best brew by individual brew method"), 2026-01-07. https://github.com/graphefruit/Beanconqueror/issues/1022
73. **complaint**: "Statistics page lacks information about beans."
    nxblnd, Beanconqueror #939, 2025-05-22. https://github.com/graphefruit/Beanconqueror/issues/939
74. **missing**: "It would be nice to have another chart that includes them or a toggle that switches the rating source from brews to beans."
    kimoofey, Beanconqueror #978, 2025-11-08. https://github.com/graphefruit/Beanconqueror/issues/978
75. **complaint**: "5 stars is restrictive. When trying different brew params with the same bean they might all be 3 out of 5 stars overall, but I still want to differentiate a bit."
    tokenstar, Beanconqueror #188, 2021-03-27. https://github.com/graphefruit/Beanconqueror/issues/188
76. **missing**: "It would be nice if one could create their own tasting templates, to mirror for example [Hoffmann tasting sheet]"
    BbqGamer, Beanconqueror #1110, 2026-04-03. https://github.com/graphefruit/Beanconqueror/issues/1110
77. **missing**: "An optional, opt-in espresso dial-in assistant that turns Beanconqueror's existing brew data into actionable next-shot suggestions, using a 2D taste compass."
    RichardAtCT, Beanconqueror #1125, 2026-05-03. https://github.com/graphefruit/Beanconqueror/issues/1125 (This is Next Cup's core loop. It is evidence that the "suggest one change" feature is wanted.)
78. **missing**: "The user taps where the shot landed. The assistant suggests deltas for the next shot — grind, dose, and/or yield — with a one-line rationale"
    RichardAtCT, Beanconqueror #1125, 2026-05-03. https://github.com/graphefruit/Beanconqueror/issues/1125
79. **complaint**: "For coffee beans particularly I don't think finding the mean of people's ratings would be useful."
    mousetree, HN "Show HN: A Minimalist Coffee Bean Rating System", 2025-02-06. https://news.ycombinator.com/item?id=42965536

## Sync / export

80. **missing**: "Maybe a switch/feature which will write all the data to iCloud by default instead of writing them in My Device?"
    dkbhadeshiya, Beanconqueror #974 ("Automatic iCloud Backup"), 2025-10-24. https://github.com/graphefruit/Beanconqueror/issues/974
81. **missing**: "It would be great to have the option to sync via WebDAV. This would allow to use the app across multiple devices."
    gidhap, Beanconqueror #25, 2019-04-24. https://github.com/graphefruit/Beanconqueror/issues/25
82. **complaint**: "The data for my beans does apper to be syncing but recipes that I create are not syncing."
    mmoore99, Timer.Coffee #42, 2025-05-18. https://github.com/antonkarliner/timer-coffee/issues/42
83. **missing**: "it's a lot easer to upload a single file than a whole directory from a phone."
    m42cel, Beanconqueror #984 ("Full export to zip"), 2025-11-19. https://github.com/graphefruit/Beanconqueror/issues/984
84. **complaint**: "I checked the data export, but everything since 02.04.2024 is missing."
    abaebae, Beanconqueror #694 ("Database rollback / Data are missing"), 2024-04-13. https://github.com/graphefruit/Beanconqueror/issues/694
85. **missing**: "No new features, just a QoL improvement to make the app available in "Share" and "Open In" menus across iOS."
    hlibkoval, Beanconqueror #1066, 2026-02-21. https://github.com/graphefruit/Beanconqueror/issues/1066

## Recipe sharing

86. **complaint**: "When I attempt to share a recipe that I have created I get the following message: "Recipe not found in the cloud or is not public." How can I share my custom recipes?"
    mmoore99, Timer.Coffee #43, 2025-05-18. https://github.com/antonkarliner/timer-coffee/issues/43
87. **missing**: "Or even a way to make our recipes."
    lolzorzbbq, Timer.Coffee #29, 2024-03-06. https://github.com/antonkarliner/timer-coffee/issues/29
88. **missing**: "It would be great if there was a way to see other peoples brew notes"
    jeemusu, HN "Show HN: We're two coffee nerds...", 2025-06-30. https://news.ycombinator.com/item?id=44428158

## Water / temp

89. **missing**: "It would be great if water composition could be shown the list view the way grind setting and profile is. It could be shortened to just GH/KH for example."
    nhadler, Beanconqueror #288, 2022-01-05. https://github.com/graphefruit/Beanconqueror/issues/288
90. **missing**: "As an enhancement, it would be really nice when there will be a timer for temperature surfing."
    wulfithewulf, Beanconqueror #8, 2018-10-03. https://github.com/graphefruit/Beanconqueror/issues/8

## Shortcuts / deep links

91. **complaint**: "When scanning an NFC tag written with Beanconqueror, the app opens but does not navigate to the intended bean or trigger the expected action (e.g. START_BREW)."
    TickleThePanda, Beanconqueror #1051, 2026-02-13. https://github.com/graphefruit/Beanconqueror/issues/1051
92. **missing**: "It'd nice to have some kind of import API to create a new brew with prefilled values."
    mike1808, Beanconqueror #280, 2021-12-24. https://github.com/graphefruit/Beanconqueror/issues/280

## Delight (what people praise)

93. **delight** (logging friction): "love that Beanconqueror actually tracks grind size and recipes for each method!"
    Cruise Chen, Product Hunt Beanconqueror page, about 2025 (shown as "1yr ago"). https://www.producthunt.com/products/beanconqueror
94. **delight** (logging friction): "seriously the most comprehensive coffee app I've ever used."
    Juan Secchi, Product Hunt Beanconqueror page, about 2025 (shown as "1yr ago"). https://www.producthunt.com/products/beanconqueror
95. **delight** (timer UX): "Genius concept. Simple, clean and perfect timing. Love the name too!"
    Cem Yıldız, Product Hunt Brewcat reviews, about 2025 (shown as "1yr ago"). https://www.producthunt.com/products/brewcat/reviews
96. **delight** (stats/insights): "I love how I can track the details of each brew and iIt has a unique ranking interface for each."
    Ekin İçbudak, Product Hunt Brewcat reviews, about 2025 (shown as "1yr ago"). https://www.producthunt.com/products/brewcat/reviews
97. **delight** (stats/insights): "I always wanted this, especially after one of my wine loving friends showed me the Vivino app."
    mastazi, HN "Show HN: We're two coffee nerds...", 2025-07-01. https://news.ycombinator.com/item?id=44429592
98. **delight** (timer UX): "Love the app been using it daily!"
    lolzorzbbq, Timer.Coffee #29, 2024-03-06. https://github.com/antonkarliner/timer-coffee/issues/29
99. **delight** (stats/insights): "at first huge thanks for this amazing app - I love to use it daily"
    sebastian-tischer, Beanconqueror #156, 2021-01-11. https://github.com/graphefruit/Beanconqueror/issues/156

---

## Theme count

Each quote is counted once, under its primary theme. The delight quotes are counted under the theme shown in brackets.

| Theme | complaint | missing | delight | Total |
|---|---:|---:|---:|---:|
| Timer UX | 9 | 6 | 2 | **17** |
| Stats / insights (incl. rating) | 4 | 8 | 3 | **15** |
| Bean freshness / inventory | 2 | 11 | 0 | **13** |
| Logging friction | 7 | 4 | 2 | **13** |
| Design / clutter | 7 | 4 | 0 | **11** |
| Grind settings | 1 | 5 | 0 | **6** |
| Ratios / scaling | 4 | 2 | 0 | **6** |
| Sync / export | 2 | 4 | 0 | **6** |
| Onboarding | 2 | 1 | 0 | **3** |
| Recipe sharing | 1 | 2 | 0 | **3** |
| Water / temp | 0 | 2 | 0 | **2** |
| Shortcuts / deep links | 1 | 1 | 0 | **2** |
| Widgets / Live Activity | 0 | 1 | 0 | **1** |
| Apple Watch | 1 | 0 | 0 | **1** |
| **Total** | **41** | **51** | **7** | **99** |

How to read the thin rows: few people asked for widgets, Live Activities or the Watch directly. Most of the timer complaints, though, come down to the timer stopping or going silent when the app is in the background or the screen is off (quotes 1-5, 16, 17). On iOS, the usual fix for that is a Live Activity with notification chimes for each step.
