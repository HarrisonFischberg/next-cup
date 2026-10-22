#!/bin/bash
# Build one concept worktree and capture F01 screens on the simulator.
# usage: design/shoot.sh <concept-id> <worktree-path> <out-dir> [stage...]
# Writes <out>/<id>-<stage>-<light|dark>-<default|ax>.png
set -euo pipefail
ID=$1; WT=$2; OUT=$3; shift 3
STAGES=("$@"); [ ${#STAGES[@]} -eq 0 ] && STAGES=(recipe timer log journal)
DEV="iPhone 18 Pro"
DD="${DERIVED:-/private/tmp/claude-501/-Users-harrison-projects/960feba3-3f52-4abd-9abe-2728b7a2060e/scratchpad/dd-$ID}"
BUNDLE="com.nextcup.concept.$ID"
mkdir -p "$OUT"
xcodebuild -project "$WT/design/Concepts.xcodeproj" -scheme Concept -destination "platform=iOS Simulator,name=$DEV" \
  -derivedDataPath "$DD" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" -quiet build 2>&1 | grep -E "error|warning: .*Swift|BUILD" || true
APP="$DD/Build/Products/Debug-iphonesimulator/Concept.app"
xcrun simctl install booted "$APP"
xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
for mode in light dark; do
  xcrun simctl ui booted appearance $mode
  for size in default ax; do
    [ $size = ax ] && CS=accessibility-extra-extra-extra-large || CS=large
    xcrun simctl ui booted content_size $CS
    for stage in "${STAGES[@]}"; do
      xcrun simctl terminate booted "$BUNDLE" >/dev/null 2>&1 || true
      EXTRA=(); [ "$stage" = timer ] && EXTRA=(-elapsed 78)
      xcrun simctl launch booted "$BUNDLE" -stage $stage ${EXTRA[@]+"${EXTRA[@]}"} >/dev/null
      sleep 2.6
      xcrun simctl io booted screenshot --type=png "$OUT/$ID-$stage-$mode-$size.png" >/dev/null 2>&1
    done
  done
done
xcrun simctl ui booted content_size large
xcrun simctl ui booted appearance light
echo "captured -> $OUT"
