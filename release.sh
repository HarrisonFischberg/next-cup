#!/bin/bash
# One command for every store Next Cup ships to (iOS, and Android once android/ exists).
# Dry run by default: builds and stops. --live uploads; --track production goes to review.
# Usage: ./release.sh [ios|android|all] [--live] [--track internal|production]
#   ios      internal = TestFlight (lane beta), production = App Store review (lane release)
#   android  internal = Play internal testing, production = Play production
# Env vars and one-time setup: release/README.md
set -euo pipefail
cd "$(dirname "$0")"
usage="usage: ./release.sh [ios|android|all] [--live] [--track internal|production]"
target=all live=false track=internal
while [ $# -gt 0 ]; do
  case "$1" in
    ios|android|all) target=$1 ;;
    chrome|firefox) echo "$1: Next Cup has no browser extension, nothing to release." >&2; exit 2 ;;
    --live) live=true ;;
    --track) track=${2:-}; shift ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
  shift
done
case "$track" in internal|production) ;; *) echo "$usage" >&2; exit 2 ;; esac
command -v fastlane >/dev/null || { echo "fastlane is not installed: brew install fastlane" >&2; exit 1; }

ios() {
  local lane=beta
  [ "$track" = production ] && lane=release
  fastlane ios "$lane" live:"$live"
}
android() {
  if [ ! -d android ]; then
    echo "android/ is not on this branch yet, skipping Android." >&2
    [ "$target" = all ] && return 0 || return 1
  fi
  fastlane android release live:"$live" track:"$track"
}

[ "$live" = true ] || echo "Dry run: building only. Add --live to upload."
case "$target" in
  ios) ios ;;
  android) android ;;
  all) ios; android ;;
esac
