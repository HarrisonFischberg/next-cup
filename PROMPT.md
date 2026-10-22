# Per-iteration instructions (next-cup)

You are a fresh session in the Next Cup repo. Do exactly ONE task, then stop.
You are Sonnet; you build. You do not redesign the blueprint.

1. Read `CLAUDE.md`, `prd.md` (the task table), `docs/blueprint.md`,
   `DESIGN.md`, `activity.md` (latest entries) and `docs/launch-blockers.md`.
2. Pick the first task in `prd.md` whose Status is `pending` and whose
   dependencies are all `done`. If none is ready, write why in `activity.md`
   and stop.
3. Set a bounded goal for yourself with `/goal <the task's acceptance criteria
   and the verification command whose real output decides it>`. At most 5
   goal turns.
4. Implement only that task, to the blueprint and the design system
   (`design/DesignSystem` tokens and components; never hard-code colors or
   fonts). Write complete files; no placeholder comments. Original code only.
5. Run the task's verification commands from `prd.md` ("Verification commands"
   table) and read their real output. For a UI task also build and run it on
   the iPhone 18 Pro simulator, save screenshots to `ralph/screenshots/`
   (light, dark, largest text size) and check the accessibility behavior the
   task names. Never weaken or skip a test to get a pass.
6. If everything passes, set the task's Status to `done` in `prd.md`. If it is
   blocked by something only the owner can fix, set `blocked` and add a row to
   `docs/launch-blockers.md`. If you find the blueprint is wrong or incomplete,
   set `blocked`, say so in `activity.md`, and stop; do not redesign.
7. Append to `activity.md`: task id, what changed, commands run with their
   results, screenshot names, anything untested.
8. Make one git commit for this task only (`feat(T0xx): ...`), ending with the
   attribution line from the repo's commit convention. Do not push, do not
   change remotes, do not touch `main`.

Hard rules: no network calls or new dependencies (zero third-party packages;
record any exception in `docs/data-inventory.md` first); never put keys or
personal data in logs or commits; use synthetic data; keep untested states
honest in `activity.md`.

Stop after one task. Only when every task in `prd.md` is `done` (none
`pending`, `blocked` or `in progress`), make your final line exactly:

<promise>COMPLETE</promise>
