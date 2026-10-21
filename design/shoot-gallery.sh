#!/bin/bash
# Capture the design-system gallery in light/dark at default and largest text.
# usage: design/shoot-gallery.sh <out-dir>   (run from the repo root)
set -euo pipefail
OUT=$1; mkdir -p "$OUT"
DEV="iPhone 18 Pro"; BUNDLE="com.nextcup.concept"
DD="${DERIVED:-/private/tmp/claude-501/-Users-harrison-projects/960feba3-3f52-4abd-9abe-2728b7a2060e/scratchpad/dd-gallery}"
xcodebuild -project design/Concepts.xcodeproj -scheme Concept -destination "platform=iOS Simulator,name=$DEV" \
  -derivedDataPath "$DD" -quiet build 2>&1 | grep -E "error" || true
xcrun simctl install booted "$DD/Build/Products/Debug-iphonesimulator/Concept.app"
for mode in light dark; do
  xcrun simctl ui booted appearance $mode
  for size in default ax; do
    [ $size = ax ] && CS=accessibility-extra-extra-extra-large || CS=large
    xcrun simctl ui booted content_size $CS
    n=0
    for group in "Buttons" "Spec grid" "Operation table" "Instrument panel" "Value entry" "Choices" "Notes and grades" "Feedback" "Empty and loading"; do
      n=$((n+1))
      xcrun simctl terminate booted "$BUNDLE" >/dev/null 2>&1 || true
      xcrun simctl launch booted "$BUNDLE" -gallery -galleryGroup "$group" >/dev/null
      sleep 2
      xcrun simctl io booted screenshot --type=png "$OUT/gallery-$n-${group// /-}-$mode-$size.png" >/dev/null 2>&1
    done
  done
done
xcrun simctl ui booted content_size large; xcrun simctl ui booted appearance light
echo "captured -> $OUT"
