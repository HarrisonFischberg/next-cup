#!/bin/bash
# Archive the Release build and upload it to App Store Connect for TestFlight.
# Same approach as the studio's other apps (sunglasses-at-night). Run on the
# owner's Mac with Xcode signed in to the team's Apple ID (Xcode > Settings >
# Accounts) and the App Store Connect app record for app.rarecreatures.nextcup
# already created. Uploads go to Apple: owner's approval only.
# Usage: scripts/archive-testflight.sh [--no-upload]
# Build number: NC_BUILD_NUMBER, default a UTC timestamp so every upload is
# higher. Version: MARKETING_VERSION in the project. Team: NC_TEAM.
set -euo pipefail
cd "$(dirname "$0")/.."
TEAM="${NC_TEAM:-KTV2G3Z883}"
BUILD="${NC_BUILD_NUMBER:-$(date -u +%Y%m%d.%H%M)}"
UPLOAD=1; [ "${1:-}" = "--no-upload" ] && UPLOAD=0
tmp="$(mktemp -d -t nc-archive)"
trap 'rm -rf "$tmp"' EXIT
archive="build/archives/NextCup-$BUILD.xcarchive"
echo "archiving build $BUILD"
xcodebuild -project NextCup.xcodeproj -scheme NextCup -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD" \
  archive > "$tmp/archive.log" 2>&1 || {
  grep -E ' error:' "$tmp/archive.log" >&2 || tail -n 30 "$tmp/archive.log" >&2
  echo "archive failed" >&2; exit 1
}
echo "archived: $archive"
[ "$UPLOAD" = 1 ] || { echo "not uploaded (--no-upload)"; exit 0; }
echo "uploading build $BUILD"
xcodebuild -exportArchive -archivePath "$archive" -exportPath "build/archives/export-$BUILD" \
  -exportOptionsPlist scripts/ExportOptions-testflight.plist -allowProvisioningUpdates \
  > "$tmp/export.log" 2>&1 || {
  grep -E ' error:|Error' "$tmp/export.log" >&2 || tail -n 30 "$tmp/export.log" >&2
  echo "upload failed" >&2; exit 1
}
echo "Done: build $BUILD uploaded. App Store Connect > TestFlight shows it after Apple's processing (usually 5 to 30 minutes)."
