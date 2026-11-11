# Asset and code licenses

| Asset / package | Type | Source | License | Permitted uses | Attribution required | Where used |
| --- | --- | --- | --- | --- | --- | --- |

"Publicly downloadable" is not a license.

## Phase 3C design system (2026-10-21)

| Asset | Source | License | Notes |
| --- | --- | --- | --- |
| DIN Condensed Bold, American Typewriter, SF Mono / SF Pro | Bundled with iOS | Apple system fonts, used by name through system APIs | No font files are copied into the repo or the app |
| SF Symbols | Apple | Apple SF Symbols license | Used by name only |
| Colors, shapes, components | Written for Next Cup | Original | No reference-app assets |

## T003 bundled data (2026-10-21)

| Asset | Source | License | Notes |
| --- | --- | --- | --- |
| `NextCup/Resources/methods.json`, `recipes.json`, `taxonomy.json` | Written for Next Cup | Original | Generic method and recipe text; no creator or reference-app recipes. SF Symbol names used by name only |

## App icon (2026-10-28)

`NextCup/Assets.xcassets/AppIcon.appiconset/AppIcon-Light-1024.png` and `AppIcon-Dark-1024.png` (same image for both appearances): "Brew Ring", option 4 of the 2026-10-28 icon round, picked by the owner. Drawn for Next Cup as vector art (source `design/app-icon/brew-ring.svg`) and rendered to a 1024×1024 opaque PNG. Original work; no third-party assets. Replaces the earlier yellow/blue icon cropped from the owner's `AppIcon-options-yellow-blue.png`.

## Handoff redesign hero photographs (2026-10-27)

Photographs in `NextCup/Assets.xcassets/Handoff/hero.<look>.<slot>.imageset`, one card and one setup hero per look plus one per built-in brew method (`method.<key>`), downloaded through the Unsplash API (downloads recorded). All are under the
[Unsplash License](https://unsplash.com/license): free for commercial use, no permission needed,
attribution appreciated but not required; may not be sold unaltered or used to build a competing service.

| Asset | Photographer | Photo |
| --- | --- | --- |
| `hero.sundayStudio.setup` | Moon Moons | https://unsplash.com/photos/mil1ye4BTmY |
| `hero.morningEdition.setup` | Emma Smith | https://unsplash.com/photos/8iEPHGbsp70 |
| `hero.precisionAtelier.card` | Ryan ODee | https://unsplash.com/photos/yWPs9knfK9o |
| `hero.precisionAtelier.setup` | Ashkan Forouzani | https://unsplash.com/photos/1SATo8GQBYg |

| `method.cone-dripper` | Szymon Satora | https://unsplash.com/photos/c-wdaPOmtLQ |
| `method.flat-dripper` | Jamie Long | https://unsplash.com/photos/t2cId7djc0k |
| `method.switchable-dripper` | Di Bella Coffee | https://unsplash.com/photos/Ko7PFAommGE |
| `method.press` | Clay Banks | https://unsplash.com/photos/Sv_3PDNZyQ0 |
| `method.inverted-press` | Elin Melaas | https://unsplash.com/photos/d7-QG58ONm0 |
| `method.espresso` | Kevin Butz | https://unsplash.com/photos/BBFRIGifYQ8 |
| `method.iced-pour-over` | Nguyen Tong Hai Van | https://unsplash.com/photos/Q1ImlWMxOIM |
| `method.cold-brew` | Blake Wisz | https://unsplash.com/photos/X6aY_j6JD_Y |
| `hero.sundayStudio.card` (replaced) | Szymon Satora | https://unsplash.com/photos/c-wdaPOmtLQ |
| `hero.morningEdition.card` (replaced) | Jamie Long | https://unsplash.com/photos/sK-pgy8W_Yc |
| `method.moka-pot` | Thanos Amoutzias | https://unsplash.com/photos/Kc_OvVVpnUo |
| `method.aeropress` | Monaz Nazary | https://unsplash.com/photos/tYtkd20J3iA |
| `method.chemex` | Jamie Long | https://unsplash.com/photos/sK-pgy8W_Yc |
| `method.drip-machine` | earlybird coffee | https://unsplash.com/photos/JE-MOId38SU |

The brewer drawings on the active brew screen and the method tiles remain original Canvas line art.

## Brew music

Tracks in `NextCup/Resources/Music/`, played at 34% volume during a brew (Settings > Brewing >
Music while brewing). Downloaded 2026-10-27 from Wikimedia Commons as its MP3 transcodes and
re-encoded to 64 kbps AAC. Only public domain or CC0 recordings are bundled; nothing needs credit,
but each is listed here.

| File | Recording | License | Source |
| --- | --- | --- | --- |
| `brew-music-jazz-at-the-park.m4a` | "Jazz at the park", flute and tenor sax duo, by Commons user Manwithmetalpig (own work) | CC0 | https://commons.wikimedia.org/wiki/File:Jazz_at_the_park.ogg |
| `brew-music-army-blues-kellis-number.m4a` | "Kelli's Number", U.S. Army Blues jazz ensemble | CC0 (U.S. government work) | https://commons.wikimedia.org/wiki/File:US_Army_Blues_-_08_-_Kellis_Number.ogg |
| `brew-music-army-blues-not-on-the-bus.m4a` | "Not On The Bus", U.S. Army Blues jazz ensemble | CC0 (U.S. government work) | https://commons.wikimedia.org/wiki/File:US_Army_Blues_-_04_-_Not_On_The_Bus.ogg |
| `brew-music-satie-gymnopedie-1.m4a` | Satie, Gymnopédie No. 1, Robin Alciatore for Musopen | Public domain | https://commons.wikimedia.org/wiki/File:Erik_Satie_-_gymnopedies_-_la_1_ere._lent_et_douloureux.ogg |
| `brew-music-chopin-nocturne-op55-1.m4a` | Chopin, Nocturne Op. 55 No. 1 | CC0 | https://commons.wikimedia.org/wiki/File:Chopin_-_Nocturne-op-55-no-1.ogg |
| `brew-music-dixie-panama.m4a` | "Panama" (William H. Tyers, 1911), Dixie Players of the U.S. Air Force Heritage of America Band, 2002 | Public domain (U.S. Air Force work) | https://commons.wikimedia.org/wiki/File:Panama_-_Dixie_Players_-_United_States_Air_Force_Heritage_of_America_Band.mp3 |
| `brew-music-dixie-clarinet-marmalade.m4a` | "Clarinet Marmalade" (Larry Shields and Henry Ragas, 1918), Dixie Players of the U.S. Air Force Heritage of America Band, 2002 | Public domain (U.S. Air Force work) | https://commons.wikimedia.org/wiki/File:Clarinet_Marmalade_-_Dixie_Players_-_United_States_Air_Force_Heritage_of_America_Band.mp3 |
| `brew-music-dixie-da-da-strain.m4a` | "That Da-Da Strain" (J. Edgar Dowell, 1922), Dixie Players of the U.S. Air Force Heritage of America Band, 2002 | Public domain (U.S. Air Force work) | https://commons.wikimedia.org/wiki/File:That_Da-Da_Strain_-_Dixie_Players_-_United_States_Air_Force_Heritage_of_America_Band.mp3 |
| `brew-music-dixie-tiger-rag.m4a` | "Tiger Rag" (Nick LaRocca, 1917), Dixie Players of the U.S. Air Force Heritage of America Band, 2002 | Public domain (U.S. Air Force work) | https://commons.wikimedia.org/wiki/File:Tiger_Rag_-_Dixie_Players_-_United_States_Air_Force_Heritage_of_America_Band.mp3 |
| `brew-music-joplin-sunflower-slow-drag.m4a` | "Sunflower Slow Drag" (Scott Joplin and Scott Hayden, 1901), U.S. Marine Band, arranged by Col. John R. Bourgeois, 1994 | Public domain (U.S. Marine Corps work) | https://commons.wikimedia.org/wiki/File:%22Sunflower_Slow_Drag%22_performed_by_the_United_States_Marine_Band_in_May_1994.mp3 |
| `brew-music-bach-goldberg-aria.m4a` | Bach, Goldberg Variations, Aria, Kimiko Ishizaka (Open Goldberg Variations), 2012 | CC0 | https://commons.wikimedia.org/wiki/File:Goldberg_Variations_01_Aria.ogg |
| `brew-music-bach-prelude-c.m4a` | Bach, Well-Tempered Clavier Book 1, Prelude No. 1 in C, BWV 846, Kimiko Ishizaka, 2015 | CC0 | https://commons.wikimedia.org/wiki/File:Kimiko_Ishizaka_-_Bach_-_Well-Tempered_Clavier,_Book_1_-_01_Prelude_No._1_in_C_major,_BWV_846.ogg |
| `brew-music-bach-air.m4a` | Bach, Air from Orchestral Suite No. 3 ("Air on the G String"), Air Force Strings of the U.S. Air Force Band, 2000 | Public domain (U.S. Air Force work) | https://commons.wikimedia.org/wiki/File:Air_-_Air_Force_Strings_-_United_States_Air_Force_Band.mp3 |
| `brew-music-chopin-nocturne-op9-2.m4a` | Chopin, Nocturne Op. 9 No. 2, Peter Johnston for Musopen | CC0 | https://commons.wikimedia.org/wiki/File:Chopin_Nocturne_No._2_in_E_Flat_Major,_Op._9.ogg |
| `brew-music-schumann-traumerei.m4a` | Schumann, Kinderszenen Op. 15 No. 7 "Träumerei", Musopen recording | Public domain (Musopen, Commons permission ticket 2008012110017088) | https://commons.wikimedia.org/wiki/File:Robert_Schumann_-_scenes_from_childhood,_op._15_-_vii._dreaming.ogg |
| `brew-music-beethoven-moonlight.m4a` | Beethoven, Sonata No. 14 "Moonlight", first movement, Paul Pitman for Musopen | Public domain (Musopen, Commons permission ticket 2008012110017088) | https://commons.wikimedia.org/wiki/File:Ludwig_van_Beethoven_-_sonata_no._14_in_c_sharp_minor_%27moonlight%27,_op._27_no._2_-_i._adagio_sostenuto.ogg |
| `brew-music-grieg-holberg-sarabande.m4a` | Grieg, Holberg Suite Op. 40, Sarabande, Marine Chamber Orchestra of the U.S. Marine Band, 2013 | Public domain (U.S. Marine Corps work) | https://commons.wikimedia.org/wiki/File:Grieg%27s_Suite_for_Strings,_Op._40,_%22From_Holberg%E2%80%99s_Time%22_-_II._Sarabande_-_Chamber_Orchestra_-_United_States_Marine_Band.mp3 |
| `brew-music-debussy-danse-sacree.m4a` | Debussy, Danse sacrée (1904), Marine Chamber Orchestra of the U.S. Marine Band, Karen Grimsey, harp, 2010 | Public domain (U.S. Marine Corps work) | https://commons.wikimedia.org/wiki/File:Danse_Sacr%C3%A9e.ogg |

The thirteen tracks from `brew-music-dixie-panama.m4a` down were downloaded 2026-11-11 from
Wikimedia Commons as its original files and re-encoded the same way. Each recording's own licence
was read from the Commons file page, not only the summary field, which for some files describes
the composition alone. The compositions are public domain in the US because all were published
before 1931: the four Dixieland tunes in 1911 to 1922, "Sunflower Slow Drag" in 1901, and the classical pieces
are by composers who died between 1750 (Bach) and 1918 (Debussy). The Air Force files are hosted
on its own "Public Domain Music" page; the arrangers of the Dixieland tunes are given only by
surname there. A fourteenth track, the Airmen of Note's "Sakura", was left out because the album
credits a vocalist. The louder band recordings play about 8 dB quieter (`BrewAudio.loud`).

The two Army Blues pieces were picked over the band's standards ("Main Stem", "Stardust") because
those compositions are still under copyright even though the recordings are not. Commons does not
name their composers; they are taken to be the band's own pieces, written as government work.

The timer's tick and chime are generated in code (`BrewAudio.tone`), so there is no sound file.
