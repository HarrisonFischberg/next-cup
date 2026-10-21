#!/bin/bash
# Next Cup build loop: one fresh Claude Code session per iteration, one task each.
# Own implementation, informed by coleam00/ralph-loop-quickstart (see ralph/REVIEW.md);
# no code copied (that repo has no license file).
#
# usage: ralph/ralph.sh [iterations]      (default 10, never more than 10)
# Run from the repo root on a build/* branch (never main).
set -u

MAX=${1:-10}
[ "$MAX" -gt 10 ] && MAX=10
MODEL=${RALPH_MODEL:-claude-sonnet-5-5}
BUDGET=${RALPH_BUDGET_USD:-5}
MARK='<promise>COMPLETE</promise>'

for f in PROMPT.md prd.md activity.md .claude/settings.json; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done
branch=$(git rev-parse --abbrev-ref HEAD)
case "$branch" in main|master) echo "refusing to run on $branch; switch to a build/* branch"; exit 1;; esac
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean; commit or stash first"; exit 1; }
mkdir -p ralph/logs ralph/screenshots

stall=0
for ((i = 1; i <= MAX; i++)); do
  before_head=$(git rev-parse HEAD)
  before_prd=$(shasum prd.md | cut -d' ' -f1)
  log="ralph/logs/iter-$(date +%Y%m%d-%H%M%S)-$i.log"
  echo "=== iteration $i of $MAX on $branch (model $MODEL, budget \$$BUDGET) -> $log"

  claude -p "$(cat PROMPT.md)" --model "$MODEL" --max-budget-usd "$BUDGET" \
    --permission-mode acceptEdits --settings .claude/settings.json \
    --output-format text < /dev/null > "$log" 2>&1
  code=$?
  echo "claude exited $code"; tail -n 5 "$log"

  last=$(grep -v '^[[:space:]]*$' "$log" | tail -n 1 | tr -d '[:space:]')
  if [ "$last" = "$MARK" ]; then
    if grep -Eq '\|[[:space:]]*(pending|blocked|in progress)[[:space:]]*\|' prd.md; then
      echo "completion marker emitted but prd.md still has open tasks; not accepting it"
    else
      echo "ALL TASKS COMPLETE after $i iteration(s)"; exit 0
    fi
  fi

  if [ "$(git rev-parse HEAD)" = "$before_head" ] && [ "$(shasum prd.md | cut -d' ' -f1)" = "$before_prd" ]; then
    stall=$((stall + 1)); echo "no progress this iteration ($stall in a row)"
  else
    stall=0
  fi
  if [ "$stall" -ge 2 ]; then
    echo "STOP: two iterations without progress. Escalate to Opus with the last logs in ralph/logs/."
    exit 2
  fi
  sleep 2
done
echo "STOP: reached $MAX iterations. This is not completion; see prd.md and activity.md."
exit 1
