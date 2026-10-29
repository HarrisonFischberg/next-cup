#!/bin/bash
# Runs the bean-capture fixtures through the app's real pipeline on a simulator.
# usage (repo root):  qa/run-eval.sh [apple|anthropic|apple,anthropic]
# Limits and model come from the environment (defaults in brackets):
#   QA_MODEL [claude-opus-5-5]  QA_MAX_REQUESTS [40]  QA_MAX_USD [3]  QA_REPEAT [1]
#   QA_SPLIT [all; dev|heldout]  QA_IDS [all; S01,S05]  QA_PRICE_IN/OUT [4/20 $ per MTok]
#   QA_SIM [NextCup QA]
# The key is never read by this script: only the path of the git-ignored file is passed.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MAIN=$(cd "$(git -C "$ROOT" rev-parse --git-common-dir)/.." && pwd)
PROVIDERS=${1:-apple}
ENV_FILE=${QA_ENV_FILE:-}
for f in "$ROOT/.env.qa.local" "$MAIN/.env.qa.local"; do
  [ -z "$ENV_FILE" ] && [ -f "$f" ] && ENV_FILE=$f
done
if [[ $PROVIDERS == *anthropic* ]]; then
  [ -n "$ENV_FILE" ] || { echo "blocked: no .env.qa.local (see .env.qa.example)"; exit 2; }
  [ "$(stat -f %Lp "$ENV_FILE")" = 600 ] || { echo "blocked: $ENV_FILE must be chmod 600"; exit 2; }
  git -C "$(dirname "$ENV_FILE")" check-ignore -q "$ENV_FILE" || { echo "blocked: $ENV_FILE is not git-ignored"; exit 2; }
  ! git -C "$(dirname "$ENV_FILE")" ls-files --error-unmatch "$ENV_FILE" >/dev/null 2>&1 || { echo "blocked: $ENV_FILE is tracked"; exit 2; }
  grep -q '^ANTHROPIC_API_KEY=..' "$ENV_FILE" || { echo "blocked: ANTHROPIC_API_KEY is empty"; exit 2; }
  echo "credentials: configured ($ENV_FILE)"
fi
mkdir -p "$ROOT/qa/results"
export TEST_RUNNER_QA_ROOT="$ROOT/qa" TEST_RUNNER_QA_PROVIDERS="$PROVIDERS" TEST_RUNNER_QA_ENV_FILE="$ENV_FILE"
for v in QA_MODEL QA_MAX_REQUESTS QA_MAX_USD QA_REPEAT QA_SPLIT QA_IDS QA_PRICE_IN QA_PRICE_OUT; do
  [ -n "${!v:-}" ] && export "TEST_RUNNER_$v=${!v}"
done
xcodebuild -project "$ROOT/NextCup.xcodeproj" -scheme NextCup \
  -destination "platform=iOS Simulator,name=${QA_SIM:-NextCup QA}" \
  -derivedDataPath "${DERIVED:-/tmp/nextcup-qa-dd}" \
  -only-testing:NextCupTests/BeanCaptureEvalTests test > "$ROOT/qa/results/xcodebuild.log" 2>&1 || true
grep -E "✘|^[^ ]+:[0-9]+:[0-9]+: error:|Test run with|TEST (SUCCEEDED|FAILED)" "$ROOT/qa/results/xcodebuild.log" | tail -15
python3 "$ROOT/qa/tools/score.py"
