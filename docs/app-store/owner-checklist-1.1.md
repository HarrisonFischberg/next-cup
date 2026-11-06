# Next Cup 1.1: what Harold does

Everything up to the upload is ready. The build is **1.1 (20261106.1509)**, archived from
main 9e43d15 with the version bump (PR #81). It shows in Xcode Organizer as
"NextCup 2026-11-06 08.09.54". Ignore the 08.08.51 archive, which is from a failed first try.

## 1. Upload the build (pick one)

**Xcode:** Window > Organizer > Archives > the 1.1 (20261106.1509) archive >
Distribute App > App Store Connect > Upload. If it says "App Store Connect access for
KTV2G3Z883 is required", sign in again under Xcode > Settings > Accounts.

**Terminal**, with your App Store Connect key (no Xcode sign-in needed):

```bash
cd ~/projects/next-cup/worktrees/release-1.1 && xcodebuild -exportArchive -archivePath "$HOME/Library/Developer/Xcode/Archives/2026-11-06/NextCup 2026-11-06 08.09.54.xcarchive" -exportOptionsPlist scripts/ExportOptions-testflight.plist -exportPath /tmp/nextcup-1.1 -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

Wait for Apple's "has completed processing" email. The build also lands on TestFlight.

## 2. Make the 1.1 version page (appstoreconnect.apple.com > Next Cup)

1. Click **+** next to "iOS App" in the sidebar and type `1.1`.
2. **What's New in This Version:** paste `store/ios/metadata/en-US/release_notes.txt`.
3. **Description:** paste `store/ios/metadata/en-US/description.txt`. Promotional text,
   keywords and URLs stay the same.
4. **Screenshots:** under 6.9" Display, delete the old ones and drag in the 8 files from
   `~/projects/next-cup/screenshots/next-cup-appstore-screenshots/marketing-1.1/6.9/`.
   If the 6.5" Display slot has its own set, replace it with the files from `.../6.5/`.
5. **Build:** click "Add Build" and pick 20261106.1509.
6. **App Review Information:** the notes stay the same (they already cover QR codes and
   AI web search).
7. **Version Release:** keep "Manually release this version".

## 3. Privacy: no changes needed

App Privacy stays the same: Photos or Videos and Other User Content, App
Functionality, not linked to you, no tracking. The published policy (updated 2 November) already
covers QR links, Create with AI, Ask AI for Next Cup and Next Cup on save.

## 4. Submit, when you're ready

Click **Add for Review**, then **Submit to App Review**. After Apple approves it, press
**Release**. Claude does not do this step.
