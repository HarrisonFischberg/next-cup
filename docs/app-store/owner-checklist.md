# Owner checklist: Next Cup 1.0 on the App Store

Steps only the owner can do (Apple account, legal sign-off, the submit
button). Copy for every field is in `listing.md`. Nothing here has been
submitted; Claude has no Apple login.

## Before App Store Connect

1. **Merge the release PRs.** The Next Cup PR (amount-wheel tap, privacy
   screen with policy link, consent text, version 1.0, this pack) and the
   studio-site PR (policy and support page updates). The studio-site merge
   goes live on rarecreatures.app straight away.
2. **Check the two URLs open in a browser:**
   https://rarecreatures.app/apps/next-cup/privacy/ and
   https://rarecreatures.app/apps/next-cup/support/.
3. **Legal sign-off.** The 2026-10-25 decision was a lawyer read before the
   App Store. Either get that read of the privacy page, or decide to ship
   without it and note that in `docs/launch-blockers.md` (B006).
4. **Check support@rarecreatures.app receives mail.** The support page and
   App Review both point there.

## In App Store Connect (appstoreconnect.apple.com)

The app record for `app.rarecreatures.nextcup` already exists from TestFlight.

5. **Agreements, Tax and Banking.** A free app needs only the Free Apps
   agreement, which is active if TestFlight works. No banking or tax forms.
6. **EU trader status (Digital Services Act).** Look under Business in App Store
   Connect for the Digital Services Act trader status question. Rare Creatures LLC is a business, so the usual answer is
   "trader", which shows a business address, phone and email on the EU
   product page. The address is not recorded anywhere in the project yet.
   If you do not want that public, leave the EU out of availability (step 8)
   for now; you can add it later.
7. **App Information:** subtitle, categories (Food & Drink, Lifestyle),
   content rights (Yes, third-party content with rights), age rating
   questionnaire (all No, expect 4+), privacy policy URL.
8. **Pricing and Availability:** Free. Territories: all, or all except the
   EU per step 6.
9. **App Privacy:** start the questionnaire, choose "Yes, we collect data",
   tick Photos or Videos and Other User Content, each App Functionality,
   not linked, no tracking. Publish the answers.

## The build

10. **Archive and upload a 1.0 build** on the Mac:
    `scripts/archive-testflight.sh` from the repo root on `main`. It
    uploads to App Store Connect; wait for it to finish processing (the
    email from Apple). Export compliance is answered by the Info.plist key.
11. **Optional but wise:** install that build from TestFlight and do one
    full brew on a real iPhone.

## Version 1.0 page

12. **Screenshots:** the 6.9-inch set (1320 × 2868), 1 to 10 shots. Claude
    can capture them on the Mac's simulator; see `listing.md` for the list.
13. **Text:** promotional text, description, keywords, support URL,
    marketing URL, copyright, from `listing.md`.
14. **Build:** pick the 1.0 build from step 10.
15. **App Review Information:** no sign-in needed; your name, phone and
    email; paste the review notes from `listing.md`.
16. **Version release:** "Manually release this version" is recommended,
    so you choose the moment it goes live after approval.

## Submit

17. **Add for Review, then Submit to App Review.** Review usually takes a
    day or two. If Apple replies with a question or rejection, paste it into
    the project thread and Claude will draft the fix and the reply.
18. **After approval:** press Release. Then ask Claude to change the support
    page's "Can I download it?" answer to the App Store link.
