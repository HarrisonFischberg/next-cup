#!/bin/bash
# Retakes the App Store screenshots from the current code: runs AppStoreCaptureUITests on an
# iPhone Pro Max simulator, then frames them into store/ios/screenshots (6.9 + 6.5 inch).
set -euo pipefail
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
udid=$(xcrun simctl list devices available | grep -m1 "Pro Max" | grep -oE '[0-9A-F-]{36}')
[ -n "$udid" ] || { echo "No iPhone Pro Max simulator found." >&2; exit 1; }
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3
mkdir -p docs/app-store/raw
touch docs/app-store/raw/.capture
trap 'rm -f docs/app-store/raw/.capture' EXIT
xcodebuild -project NextCup.xcodeproj -scheme NextCup -destination "id=$udid" \
  -only-testing:NextCupUITests/AppStoreCaptureUITests \
  -resultBundlePath "build/store-screenshots-$(date +%s).xcresult" test -quiet
python3 design/frame_store_shots.py
echo "Screenshots written to store/ios/screenshots/en-US."
