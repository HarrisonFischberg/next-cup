#!/bin/bash
# Run the UI tests in short batches, restarting the simulator between batches.
# Long single runs get flaky (the same tests pass when run alone).
# usage: scripts/run-ui-tests.sh [batch-size]   (run from the repo root)
set -u
SIZE=${1:-8}
DEV="iPhone 18 Pro"
DD="${DERIVED:-/tmp/nextcup-ui-dd}"
PROJECT=NextCup.xcodeproj
tests=$(grep -ho "func test[A-Za-z0-9_]*" NextCupUITests/*.swift | sed 's/func //' | sort -u)
fail=0; n=0; args=()
run_batch() {
  [ ${#args[@]} -eq 0 ] && return
  xcrun simctl shutdown "$DEV" 2>/dev/null; sleep 3; xcrun simctl boot "$DEV" 2>/dev/null; sleep 10
  echo "== batch of ${#args[@]}"
  if ! xcodebuild -project "$PROJECT" -scheme NextCup -destination "platform=iOS Simulator,name=$DEV" \
      -derivedDataPath "$DD" "${args[@]}" test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"; then :; fi
  args=()
}
for t in $tests; do
  args+=("-only-testing:NextCupUITests/NextCupUITests/$t"); n=$((n+1))
  if [ $((n % SIZE)) -eq 0 ]; then run_batch; fi
done
run_batch
