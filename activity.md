# Activity log

## 2026-10-21 — scaffold

- Created project skeleton under the `new-app` skill.
- Next: Phase 0 intake and tool-environment verification.

## 2026-10-21 — Phase 2 discovery

- Verified REA with real calls (see `docs/tool-environment.md`).
- Owner supplied the three reference URLs. REA passive page inspection ran on
  all three first, then Replica recon from the same public pages.
- Wrote sanitized `docs/rea-findings.md`; added discovery candidates to
  `docs/data-inventory.md`; added blockers B007–B010 and a jurisdiction
  section to `docs/launch-blockers.md`.
- Draft recon, feature matrix and best-of comparison are in the lab folder
  (not in the repo) pending owner approval (B007) and review research (B008).
- Review research (`/replica-entrepreneur`): 151 items via official feeds and
  APIs only, every quote verified verbatim against its link. Fix plan X1–X8
  and three positioning angles written in the lab (`fixes.md`), 9 rows added
  to the lab feature matrix. Owner decisions recorded: comparison approved
  as written, creator channel deferred to the import build.
- Final spec merged (approved comparison + fixes X1–X8 + positioning
  default A) with 10 per-feature build prompts. Phase 2B: copied only the
  neutral spec files into `replica/` (recon, features, comparison, prompts),
  filled `replica/README.md` intentional differences, sweep clean, then
  deleted the lab folder with the owner's yes (2026-10-21). From here on,
  work only from `replica/`.

## 2026-10-21 — Phase 3 blueprint (Opus)

- Ran `replica-architect` against `replica/` (adapted to SwiftData; no SQL
  or server routes). Wrote `replica/architecture.md`.
- Wrote `docs/blueprint.md`: stack (SwiftUI, Swift 6.4, iOS 27, SwiftData
  CloudKit-compatible, zero third-party packages), 12 models, internal
  services, outbound calls, folders, state, vendors, parts that bite, and the
  permission changes Phase 4 would need.
- Rewrote `prd.md`: ranked features, non-goals, Phase 3B core flow (F01),
  verification commands, 30 atomic tasks with dependencies, safeguard map.
- Checked host: xcodegen, tuist, swiftlint absent; `swift format` present;
  only the iOS 27 simulator runtime installed (drove the iOS 27 minimum).
- Waiting on owner approval (B011). Nothing deployed or changed externally
  beyond the PR.

## 2026-10-21 — Phase 3B design directions (Sonnet)

- Phase 3 blueprint approved and merged (PR #1).
- Built `design/Shared` (one flow model, sample data, timer, validation, shell)
  and five concept presentations, one git worktree and local branch each
  (`ui-1`..`ui-5`, never pushed). Base branch `design-base`.
- Screenshots (light/dark x default/largest text), critique, one fix batch per
  concept, re-capture. Contrast computed; three failures found and fixed.
- One live walkthrough (concept 4) found a safe-area bleed bug and a missing
  verdict in the journal; both fixed.
- Not done: VoiceOver, Reduce Motion, landscape, performance. Owner picked Steel & Kraft; other four archived as text, worktrees and
  `ui-*` branches removed. Next: Phase 3C design system.
