#!/bin/bash
# Capture journal, timer and log for each -look N in light and dark, then join them per look.
# usage: design/shoot-looks.sh <out-dir> <look...>   (run from the repo root)
set -euo pipefail
OUT=$1; shift; mkdir -p "$OUT/raw"
DEV="iPhone 18 Pro"; BUNDLE="com.nextcup.concept.r4"
DD="${DERIVED:-$TMPDIR/dd-r4}"
xcodebuild -project design/Concepts.xcodeproj -scheme Concept -destination "platform=iOS Simulator,name=$DEV" \
  -derivedDataPath "$DD" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" -quiet build 2>&1 | grep -E "error" || true
xcrun simctl install "$DEV" "$DD/Build/Products/Debug-iphonesimulator/Concept.app"
xcrun simctl status_bar "$DEV" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
xcrun simctl ui "$DEV" content_size large
xcrun simctl launch "$DEV" "$BUNDLE" >/dev/null; sleep 4  # first launch after install is slow
for mode in light dark; do
  xcrun simctl ui "$DEV" appearance $mode
  for n in "$@"; do
    for stage in ${STAGES:-journal timer log}; do
      xcrun simctl terminate "$DEV" "$BUNDLE" >/dev/null 2>&1 || true
      EXTRA=(); [ "$stage" = timer ] && EXTRA=(-elapsed 78); [ "$stage" = next ] && EXTRA=(-next)
      xcrun simctl launch "$DEV" "$BUNDLE" -look "$n" -stage ${stage/next/log} ${EXTRA[@]+"${EXTRA[@]}"} >/dev/null
      sleep 2.8
      xcrun simctl io "$DEV" screenshot --type=png "$OUT/raw/$n-$stage-$mode.png" >/dev/null 2>&1
    done
  done
done
xcrun simctl ui "$DEV" appearance light
echo "captured -> $OUT/raw"
