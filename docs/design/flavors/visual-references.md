# Visual references for Next Cup: four apps, six flavors

Scope: aesthetic study only (these apps are not competitors). Sources are the URLs listed below. I looked at the screenshots directly in a browser and read the README and store copy. I copied no assets, icons or text. Hex values marked "measured" come from computed CSS. Values marked "~" are estimates taken by eye from screenshots.

## 1. LocalSend (https://localsend.org)

Sources: https://localsend.org (live CSS inspected), https://localsend.org/img/hero-mobile.webp, https://localsend.org/img/hero-desktop.webp

- **Color:** The site's dark ground is a green-tinted near-black, measured `#0E1513` (`rgb(14,21,19)`). The single accent is a soft mint, measured `#82D5C8`. Text on accent buttons reuses the ground color, so the button reads as a lit tile with a dark label. The accent also colors the second line of the headline ("Fast, private, offline."), so one hue does both brand and emphasis. The app screenshot (hero-mobile) uses a neutral charcoal dark mode (~`#1F2023`) with a periwinkle tonal accent (~`#BAC6FF`). That is the Material You "tonal primary" look: a pale accent with no loud saturation.
- **Typography:** The site uses Inter at weight 700 for the 48px H1 (measured), with body text in the same family at regular weight. In the app, the device name ("Fast Papaya"-style) sits in very large light type, about 36sp, centered, with a small dim "#109" under it. Hierarchy comes from size alone. Weight changes are rare.
- **Shape:** All buttons are full pills, measured `border-radius: 50px`. The quick-save control is a three-segment outlined pill whose selected segment is filled with a tonal color. The bottom nav marks the active item with a small pill behind its icon (the Material 3 active indicator). The large central icon is a dashed ring around a solid disc. That shape is the app's signature.
- **Density:** Very airy. The home screen holds one hero object and one control, and roughly 40% of the screen is empty space. Lists in the desktop hero (the file receive window) are compact rows with thin progress bars.
- **Icons:** Outlined, monoline system icons (history, info, wifi, send, gear), about 24dp, in secondary text color.
- **Motion cues:** The dashed ring implies a scanning or rotating state. Nothing else is visible.
- **Theming offered:** The site has a light/dark toggle (sun icon). The app follows the system theme with Material You color. The pages do not advertise any further customization.
- **Signature:** A single friendly object centered on a calm dark ground, with mint/periwinkle tonal accents. The empty space feels like confidence, not like missing content.

## 2. Image Toolbox (https://github.com/T8RIN/ImageToolbox)

Sources: README; screenshots https://github.com/T8RIN/ImageToolbox/raw/master/fastlane/metadata/android/en-US/images/phoneScreenshots/01.png, `04.png`, `06.png` (same folder)

- **Color:** The README promotes dynamic color, generated from the wallpaper or from a chosen image. The screenshots run in a moss-green scheme on a dark charcoal-green ground (~`#1A1C19`), with surface containers one step lighter (~`#232622`). The accent is a light green (~`#A6D99A`), used for the FAB-style "Add filter" button, the active toolbar icon, and the scrollbar. The README also lists an AMOLED true-black mode, a contrast adjustment, inverted colors, and preset palette styles.
- **Typography:** Roboto-style sans. Titles are medium weight, about 16–18sp ("Image Toolbox", "Size 254.9 kB"). Each tool row has a bold title and a small dim one-line description under it. The marketing captions use a heavy rounded display face in the accent color. The README says the app ships ~30 bundled fonts and supports importing OTF/TTF files and setting a font scale.
- **Shape:** The main screen (01.png) is a stack of separate rounded cards, one per tool, each with a leading icon in a tinted rounded square. The cards have small gaps between them, about 4dp, which reads as grouped and segmented. Section containers in 04.png ("Histogram", "Filters") are large-radius cards (~20dp) with nested pill fields inside. The README describes shape options (Rounded, Cut, Squircle, Smooth) with adjustable size, 11 icon-background shapes (squircle, clover, heart, star and others), adjustable border thickness, and per-element shadow toggles.
- **Density:** Regular to compact. The home screen is a long scrolling catalog of tools, so it relies on segmented cards rather than whitespace.
- **Icons:** Rounded Material Symbols, each on a tinted container chip. The README lists an emoji top-bar icon as an option.
- **Motion:** The README mentions confetti styles, haptics controls and switch styles (it names a "Cupertino" and a "Liquid Glass" switch).
- **Theming offered:** The most of the four by far: palette style, accent and scheme from an image, AMOLED, fonts, font scale, corner shape plus size, switch and slider styles, border width, shadows, and main-screen layout.
- **Signature:** "Make it yours". Every visual token is exposed to the user, yet the default still looks coherent because everything derives from one tonal palette.

## 3. Musicolet (https://play.google.com/store/apps/details?id=in.krosbits.musicolet)

Sources: Play listing text; screenshots https://play-lh.googleusercontent.com/E5P7VIdMKpRAVLWQz8Ybepm3Vnr0ctTvJBG7ITVavnsvg5azUppOyef8Lj1Lx6fCNWlT_eVkKEbFfvVOTIsU, `.../uP_FFWnPgu1CT5Pj3mawgXkxbDMj0JlO0F0oIkETTbqwnZme1Q0fnXTbg33ymqh32cMIBBvdF_O1TjVuwhwYX6Q`, `.../741SMROA8nbWXB9zVyIv17WAfdIv_w3w5jWDNy3oAwM1yUstJU7XKpAqG5_Iqw4CiE9m923SBEZRYx_KCkLYDw`

- **Color:** The UI is near-neutral. Dark mode is a deep grey (~`#212121`) with lighter grey rows, and light mode is white. One mint-green accent (~`#7EE2A0`) carries all the meaning: the checkmark confirm button, the selected "Synced" segment, the active timestamp tile, the seek thumb, and the focused field underline. The store art pairs that mint with black text and flat hard offset shadows in mint (a neo-brutalist sticker look). The listing says "Light and dark themes". The listing copy doesn't confirm an AMOLED option.
- **Typography:** Plain sans throughout. Song title, artist and album are stacked and centered in descending sizes, with the title about 2× the size of the album line. Timestamps (`0:45.00`, `3:28`/`4:36`) use tabular figures and sit in small boxed tiles in the lyrics editor. The store captions use a geometric heavy sans set on mint highlighter bars.
- **Shape:** Compact rectangular rows with small radii (~4–8dp). The lyrics editor uses outlined boxes per line, each with a leading time tile. The segmented toggle ("Simple | Synced") is squared, not a pill. The confirm button is a solid circle. The player sits on a square album-art crop.
- **Density:** High. A one-row tab strip at the bottom holds every library section (the listing says all main sections sit in one row, a single tap away). The player packs about 10 controls into the lower third.
- **Icons:** Small, monoline, utilitarian, about 20dp, arranged in dense toolbars.
- **Theming offered:** Light and dark themes, and notification appearance settings. Customization is functional (queues, EQ presets, widgets) rather than cosmetic.
- **Signature:** A power-user layout: data-dense, square, one hot accent, with monospaced-feeling time tiles. It is the closest of the four to Next Cup's spec-sheet character.

## 4. WikiReader (https://github.com/nsh07/WikiReader)

Sources: README; screenshots https://github.com/nsh07/WikiReader/raw/main/fastlane/metadata/android/en-US/images/phoneScreenshots/1.png, `2.png`, `6.png`

- **Color:** Light mode is a warm lavender-tinted off-white (~`#FBF8FF`). Surfaces are tonal lilac (~`#EDE7F6`), used for the search pill, the collapsed infobox and the floating bottom toolbar. Links and the primary accent are a muted purple (~`#6750A4`-like). Dark mode (6.png) is a near-black purple-grey (~`#141218`) with off-white body text. The README cites Material You dynamic color and a customizable M3 palette. It does not mention AMOLED.
- **Typography:** The signature trait. Article titles ("Lavandula") and section headers ("Etymology", "Cultivation", "Z-transform") are set in a large classical serif, about 28–32sp at regular weight. Body text is a clean sans at about 15sp with generous line height. Italics carry the "Main article" notes, and LaTeX math is rendered inline. The README lists font size as a user setting.
- **Shape:** A pill search field at the top. Images sit in large rounded rectangles (~24dp). The infobox is a full-width rounded tonal card with a chevron in a small circle. The bottom toolbar floats as a rounded-pill FAB group (README: floating buttons for one-handed use). Section headers carry disclosure chevrons and collapse in place.
- **Density:** Airy and reading-first. Wide margins (~20dp), a single column, with no cards around body text.
- **Icons:** Rounded Material Symbols in the floating toolbar, tinted with the accent.
- **Motion:** The README mentions smooth animations and an immersive mode that hides the chrome while scrolling.
- **Theming offered:** Light/dark, dynamic color, an M3 palette choice, font size, and a text-only data saver.
- **Signature:** Serif headlines on soft tonal paper, with chrome that floats away while you read. It feels like a book.

## Synthesis

### (a) Shared traits

1. **One accent, tonal everything else.** Each app sets one hue against neutral or tinted neutrals: mint (LocalSend, Musicolet), green (Image Toolbox), lilac (WikiReader). Surfaces differ from the background by a small lightness step, not by borders.
2. **Tinted dark grounds.** The dark grounds are rarely pure grey. LocalSend's is green-black `#0E1513`, Image Toolbox's is moss-charcoal, and WikiReader's is purple-black. True black appears as an opt-in (Image Toolbox lists AMOLED).
3. **Pills for actions, rounded containers for groups.** Full-radius buttons, search fields and active indicators sit inside 16–24pt grouped containers. Musicolet is the exception: square and dense.
4. **Strong size-driven hierarchy.** Each has one oversized element (the device name, the article title, the song title) and calm, small secondary text.
5. **Icons in tinted chips.** Image Toolbox puts icons in rounded tinted squares, and LocalSend uses a pill nav indicator. Both make the icons read as objects.
6. **Users own the look.** Every app offers at least light/dark and dynamic color. Image Toolbox goes all the way: fonts, shapes, radius and AMOLED.

### (b) Traits that translate to native iOS (without looking like an Android port)

- **Keep:** a single accent via `.tint()`; tonal grouped surfaces (`.insetGrouped` lists with custom `listRowBackground`, card stacks with `RoundedRectangle(cornerRadius:, style: .continuous)`); a large-title hierarchy using Dynamic Type styles (`.largeTitle` for the hero, `.footnote` for metadata); serif headers via `.fontDesign(.serif)` (New York scales with Dynamic Type for free); SF Symbols in tinted rounded-square chips, the same pattern as Settings.app icons; true black as an opt-in under Settings; an accent picker and a corner-radius choice (`@AppStorage`); tabular numbers via `.monospacedDigit()`.
- **Translate, don't copy:** Material's pill active indicator becomes the native `TabView` (on iOS 26 the system draws its own selection). A FAB becomes a toolbar `Button` or a `.bottomBar` toolbar item, and on iOS 26 that bar gets the system glass material for free. Segmented pills become `Picker(.segmented)`. Wallpaper-based dynamic color isn't available on iOS, so derive the palette from the user's chosen accent, or from the bean or bag photo with `UIImage` average color, as a "make it yours" option.
- **Avoid:** Roboto-like type, Material ripples, FAB circles floating over content, hamburger drawers, underline-only text fields, 4dp elevation shadows, and custom back buttons. Keep `NavigationStack`, swipe-back, sheets with detents, and system context menus.

### (c) Six flavors for Next Cup

All palettes were checked with a WCAG contrast script. Text/bg ≥ 14:1, secondary text ≥ 5.4:1 on both bg and surface, accent/bg ≥ 4.5:1, on-accent/accent ≥ 5:1 (all AA for normal text). Every flavor uses Dynamic Type text styles. Fonts change only the design or family, never fixed sizes.

| # | Flavor | Mode | bg | surface | text | text-2 | accent | on-accent |
|---|---|---|---|---|---|---|---|---|
| 1 | Steel & Kraft | L | `#EDEBE6` | `#FFFFFF` | `#1C1E21` | `#5A5F66` | `#AE3A0A` | `#FFFFFF` |
| | | D | `#141619` | `#1E2125` | `#ECEAE4` | `#A3A8AF` | `#FF7A33` | `#141619` |
| 2 | Night Mint | L | `#F4F8F7` | `#FFFFFF` | `#13201D` | `#4F615C` | `#0F766E` | `#FFFFFF` |
| | | D | `#0E1513` | `#18211F` | `#E3EEEB` | `#9FB3AE` | `#82D5C8` | `#0E1513` |
| 3 | Espresso Black (AMOLED) | L | `#F2F2F7` | `#FFFFFF` | `#000000` | `#5C5C63` | `#2F6B3F` | `#FFFFFF` |
| | | D | `#000000` | `#0D0D0D` | `#FFFFFF` | `#9A9AA1` | `#7EE2A0` | `#000000` |
| 4 | Café Page | L | `#FBF8F3` | `#F3EEE6` | `#22201C` | `#625C52` | `#7A4A8C` | `#FFFFFF` |
| | | D | `#1A1816` | `#24211E` | `#EDE7DD` | `#ABA396` | `#D6B3E3` | `#1A1816` |
| 5 | Roaster Poster | L | `#FFFFFF` | `#F1F7F2` | `#0B0B0B` | `#4A4F4B` | `#1E7A3E` | `#FFFFFF` |
| | | D | `#121413` | `#1C201D` | `#F2F5F2` | `#A7AFA9` | `#8FF0A4` | `#0B0B0B` |
| 6 | Make It Yours | L | `#F7F6F4` | `#FFFFFF` | `#1A1A1A` | `#5E5E5E` | user (default `#B4531F`) | `#FFFFFF` |
| | | D | `#111111` | `#1C1C1E` | `#F2F2F2` | `#A0A0A5` | user (default `#F0915A`) | `#111111` |

**1. Steel & Kraft (current, kept).** *Mood:* lab bench and spec sheet, precise and slightly industrial. *Type:* SF Pro for UI, SF Mono (`.monospaced()`) for every number (grams, ratios, °C, seconds), and American Typewriter at `.callout` for kraft-paper tasting notes. *Radius:* 0/2/4pt, near square. *Density:* compact. *Controls:* square-cornered bordered buttons, spec tables as hairline-divided rows (no cards), and a kraft note card (`#E4D3B4` light / `#3A3023` dark, both with text ≥ 7:1) as the one textured element. *Inspired by:* Musicolet (one hot accent, boxed numeric tiles, density). I nudged the light accent darker, from `#C2410C` to `#AE3A0A`, because the original measured 4.3:1 on the ground.

**2. Night Mint.** *Mood:* calm, private, after-hours brew bar. *Type:* SF Pro Rounded (`.fontDesign(.rounded)`). The hero (today's cup or the last brew) is set at `.largeTitle` regular, with small `.footnote` secondary text. *Radius:* 12/20/28pt continuous, with pill buttons (`Capsule`). *Density:* airy, with one hero object per screen and lots of negative space. *Controls:* pill primary button filled with the accent, `.segmented` pickers, and `.insetGrouped` lists whose rows tint to the surface color. *Inspired by:* LocalSend (green-black ground, mint lit-tile buttons, one centered signature object; for Next Cup, a cup ring that fills as the brew timer runs).

**3. Espresso Black (AMOLED).** *Mood:* night shift, maximum contrast, battery-friendly. *Type:* SF Pro with heavier weights (`.semibold` titles) so text holds up on pure black, and SF Mono digits. *Radius:* 10/16/22pt. *Density:* regular. *Controls:* no shadows. Surfaces are `#0D0D0D` cards separated by a 0.5pt `#2A2A2A` hairline, because a lightness step alone vanishes on OLED. Buttons are pills with black text on mint. *Inspired by:* Image Toolbox's AMOLED option and Musicolet's mint-on-dark. Offer it as a "True black" toggle that applies only in Dark Mode, so it never forces dark.

**4. Café Page.** *Mood:* reading a roaster's journal, slow and literary. *Type:* New York (`.fontDesign(.serif)`) for bean names, origins and section headers, SF Pro for body and controls, and SF Mono for brew data. Optional Cochin for the bag's "story" quote. *Radius:* 14/20/24pt, with large rounded photo frames for bag and cup photos. *Density:* airy, with a single reading column and ~20pt margins. *Controls:* disclosure sections (`DisclosureGroup`) such as "Origin", "Process" and "Tasting", a tonal lilac infobox card for specs, and a bottom `.toolbar` that hides on scroll (`.toolbarVisibility` by scroll phase). *Inspired by:* WikiReader (serif titles on tonal paper, collapsible sections, chrome that steps aside).

**5. Roaster Poster.** *Mood:* loud, playful, sticker-on-a-bag. *Type:* SF Pro Rounded `.heavy` (or Avenir Next Heavy) for headings, SF Pro body, and DIN Condensed Bold for big stat numbers. *Radius:* 8/12/16pt. *Density:* regular. *Controls:* cards with a flat 2pt black border and a hard 3pt offset "shadow" in the accent color (no blur). Key words in titles sit on a highlighter bar in the accent. Primary buttons are rounded rectangles, not pills. *Inspired by:* Musicolet's store art (neo-brutalist mint highlight bars, offset sticker cards) and Image Toolbox's chunky display captions. Keep this styling to cards and headings, and leave navigation fully native.

**6. Make It Yours.** *Mood:* the user's own bar. *Type:* the user picks a design (Default, Rounded, Serif or Mono) applied via `.fontDesign`, so it stays Dynamic Type-safe. *Radius:* a 3-stop "Corners" control (Square 2pt, Soft 12pt, Round 24pt) that feeds one `@Environment` value read by every card, button and image frame. *Density:* a Compact/Regular toggle that changes row insets and `.environment(\.defaultMinListRowHeight)`. *Controls:* follow the corner choice (Round gives `Capsule` buttons, Square gives squared ones). *Accent:* a row of 8 curated swatches (bean-inspired: cherry, honey, roast, sage, slate, blueberry, crema, matcha), each pre-checked for AA in both modes, plus "Match bag photo", which averages the photo's colors and then clamps lightness to pass 4.5:1. Add the True black toggle from flavor 3. Show a live preview card at the top of Appearance settings. Defaults are the values in the table. *Inspired by:* Image Toolbox (the full token exposure, shapes plus size, AMOLED, fonts, image-based scheme), scaled down to 4 controls so it never becomes a settings maze.

### Implementation note (shared)
Define one `Theme` struct (colors, radius scale, font design, density) and inject it via `@Environment`. The six flavors are then six values, not six code paths. Store the selection in `@AppStorage`. Respect `colorScheme`, `accessibilityReduceTransparency` and `accessibilityDifferentiateWithoutColor` (in Roaster Poster, the borders already carry state). With Increase Contrast on, every flavor's text-2 should switch to text.
