# Tool environment

Verified: 2026-10-21 (Phase 0, Sonnet 5.5)

## Platform profile

iPhone only (native SwiftUI). Runtime evidence: iOS Simulator screenshots and
input, XCTest/XCUITest, Accessibility Inspector, VoiceOver and Dynamic Type
checks; `ios-accessibility`, `swiftui-performance-audit`. Browser tests: no.
Safeguards 13-15 use native evidence; `web-quality-audit`, Lighthouse, `seo`,
and Core Web Vitals are NOT APPLICABLE (no web surface).

## Host

| Item | Value | How verified |
| --- | --- | --- |
| Xcode | 27.1 (build 27A9275) | `xcodebuild -version` |
| iOS Simulator | iPhone 18 Pro (booted), others available | `xcrun simctl list devices available` |
| Node | v24.22.0 | `node -v` |
| Python | 3.9.6 | `python3 --version` |
| GitHub CLI | logged in as HarrisonFischberg (scopes: gist, read:org, repo) | `gh auth status` |

## Mandatory tools

| Tool | Available | Version | How verified |
| --- | --- | --- | --- |
| Replica | YES | replica-skill 1.0.0 (user scope) | `~/.claude/plugins/installed_plugins.json`; `replica-skill:replica-*` skills listed in session |
| REA (MCP tools answer, not just skill installed) | YES | `rea` MCP server (CDP browser provider v2) | 2026-10-21 Phase 2: `inspect_plist` and `inspect_adb_client` returned structured errors (no artifact open, no adb), then `list_browser_targets`, `inspect_web_page` x5 and `capture_web_screenshot` succeeded against an isolated browser on 127.0.0.1:9333. Stock Chrome is not installed; a Chromium-based app binary (Comet 155) with a fresh profile served as the CDP browser |
| Claude Code `/goal` | PENDING | | Not yet exercised. Verify before the first Phase 4 task; if unavailable, propose a documented alternative |
| Ralph fresh-context shell loop | BLOCKED (not yet cloned) | only `ralph-loop` 1.0.0 plugin present | The plugin is a same-context loop and is not a substitute. Clone `coleam00/ralph-loop-quickstart` and review its scripts and permissions before Phase 4; difference recorded in `activity.md` |
| Impeccable | YES | skill listed in session; installed at `~/projects/.claude` (engine 0.1.15; npm 4.6.0 checked 2026-10-17) | `/impeccable` appears in the session skill list, so no install was run in `next-cup` |

Impeccable hooks (`SessionStart`, `PostToolUse` on `Edit|Write`, `Stop`) live in
`~/projects/.claude/settings.local.json` and are kept. They run only if
`${CLAUDE_PROJECT_DIR}/.claude/skills/impeccable/scripts/impeccable` exists, so
from `next-cup` they are no-ops unless the project is opened with that path.
Browser-preview Impeccable commands are NOT APPLICABLE (native app); critique
and audit use simulator screenshots. Never claim a browser preview.

## Section F — design, accessibility, quality layer

| Skill | Available | Version / source | How verified |
| --- | --- | --- | --- |
| ui-ux-pro-max (design decisions) | YES | `~/.claude/skills/ui-ux-pro-max` | Listed in session; directory present |
| fixing-accessibility (edit-time a11y) | YES, web-oriented | `~/.claude/skills/fixing-accessibility` | Listed in session; for native code use `ios-accessibility` alongside it |
| web-quality-audit + siblings (evidence) | YES, NOT APPLICABLE | `~/.claude/skills/web-quality-audit` | No web surface |

Missing tool or credential = BLOCKED, never PASS.

## Phase 3B run (2026-10-21)

| Item | Result |
| --- | --- |
| `impeccable context` | Ran once; loaded PRODUCT.md and the iOS reference. No DESIGN.md yet (by design) |
| `/impeccable shape` | Brief written inline from the owner's directions; no interview round (owner had named the worlds and flow). Recorded in `docs/design/directions.md` |
| `/impeccable critique` | Native: Assessment A only, inline, no detector (not applicable). `docs/design/critique.md` |
| `/impeccable audit` | Native, from source and screenshots. VoiceOver and Accessibility Inspector not run: BLOCKED |
| `/impeccable craft`, `live` | Not used (craft is a deprecated alias; live is browser-only) |
| Browser preview | NOT APPLICABLE (native app) |
| iOS Simulator | iPhone 18 Pro, iOS 27.0; screenshots by `xcrun simctl io`; one live tap-through on concept 4 |
| Xcode project | Hand-written `design/Concepts.xcodeproj` (synchronized folders); builds with `xcodebuild` |

## Phase 3C run (2026-10-21)

| Item | Result |
| --- | --- |
| `replica-skill:replica-design` | Skill loaded; its contrast tool ran on both token files. Its web outputs (tokens.css, Tailwind) are NOT APPLICABLE; tokens are Swift plus JSON |
| `/impeccable document` | DESIGN.md written in scan mode from the built concept. North Star and voice chosen as defaults rather than asked (owner prefers few questions); owner can rename |
| `/impeccable extract` | Done by hand: concept-private styles and controls moved to `design/DesignSystem`, concept screens migrated |
| `/impeccable polish` | Not run as a command. Equivalent bounded pass done: gallery shot at the largest text size, defects fixed, one re-shoot |
| `.impeccable/design.json` | Minimal sidecar written (motion, breakpoints, narrative); no component HTML (native) |
