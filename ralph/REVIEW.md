# Review of coleam00/ralph-loop-quickstart (2026-10-21)

Cloned shallow into a scratch directory (commit `f6a7781`, 2026-01-20); files
read, nothing executed. Repo has no LICENSE file, so no code was copied;
`ralph/ralph.sh` is an independent implementation of the same idea.

| Finding | Their approach | Ours |
| --- | --- | --- |
| Fresh context per iteration | `claude -p "$(cat PROMPT.md)"` in a loop | Same idea |
| Model | Not pinned | `--model claude-sonnet-5-5`, overridable with `RALPH_MODEL` |
| Cost cap | None | `--max-budget-usd` per iteration (default 5) |
| Iteration cap | Caller's number, unbounded | Capped at 10 |
| Stall handling | None | Stops after two iterations with no new commit and no change to `prd.md` |
| Completion | Marker anywhere in output | Marker must be the last line AND `prd.md` has no open task |
| Errors | `\|\| true` hides failures | Exit code recorded per iteration, full log kept in `ralph/logs/` |
| Branch safety | None | Refuses `main`/`master`; requires a clean tree |
| Permissions | `WebFetch(domain:*)`, `npx`, `pnpm`, `python`, broad installs, sandbox on | Allow only xcodebuild, simctl, swift build/test/format, git add/commit/status/diff/log, token check; deny push, remotes, network tools, WebFetch, WebSearch, rm -rf, sudo |
| Browser verification | `agent-browser` for web UI | Not applicable (native); simulator screenshots instead |
| Tasks file | JSON `passes` flags | Existing `prd.md` status column |

Not adopted: the web-only prompt, `agent-browser` skill, `/create-prd`
command, wildcard WebFetch.

`/goal`: `claude -p "/goal"` answers "No goal set. Usage: `/goal <condition>`",
so the command exists in this Claude Code (2.1.304). Whether it enforces a turn
bound in print mode is not verified; the 5-turn limit is an instruction in
`PROMPT.md` plus the per-iteration budget cap.

## Permission rewriting (found while testing)

The owner's global hook rewrites shell commands to `rtk <cmd>`. A first test run
of `.claude/settings.json` blocked `xcodebuild -version` because only the plain
form was allowed. Every allow and deny rule now exists in both forms
(`Bash(xcodebuild:*)` and `Bash(rtk xcodebuild:*)`), plus a deny on
`rtk proxy` (which runs arbitrary commands). Verified with non-interactive
runs: `xcodebuild -version` runs, `curl` is denied, `xcrun simctl list` runs.
`git push` denial is by rule only; it was not exercised.

## First run (T001, 2026-10-21)

One iteration, one commit (`743edff`). I re-ran the checks myself afterwards:
package tests pass, `xcodebuild test` succeeds (unit and UI), strict format
lint is clean. Two loop findings: the headless session cannot invoke `/goal`
(a slash command, not a tool) so the goal bound is self-imposed; and its
`git add -A` staged SwiftPM `.build/` files (not committed; `.gitignore` fixed).
