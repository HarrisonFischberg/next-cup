# Best-of comparison

Status: APPROVED by the owner as written, 2026-10-21 (Bluetooth scales deferred).

Per capability: how each source handles it (from public pages only), the
strongest approach for Next Cup, and why. A = brew-data website + journal app,
B = open-source tracker, C = guided timer with paid tier.

| Capability | A | B | C | Strongest for Next Cup | Why |
| --- | --- | --- | --- | --- | --- |
| Brew logging | Precise fields, dated, searchable, drawdown diagnosis | Per-method custom parameters | Paid; reviewer says the target output is locked before a shot | B's per-method parameters + A's search, always recording actual results | Fast entry for the methods a user owns; fixes C's complaint |
| Recipes | Timed pour schedules, cumulative targets, scale-to-dose, tuning note | Methods preconfigured | Large method list, community + pro guides, flow-speed illustration | A's step model (kind, offset, cumulative target) + own recipe editor | Clearest structure; maps straight to a timer and to logging |
| Guided timer | Haptic cues, logs result | Live graphs with scales | Timer with flow illustration, Live Activities | A's timer with haptics + a Live Activity + one-handed controls | Wet hands at the brew station (intake) |
| Beans | Library by roaster, rating, roast chip, rest/peak, buy again/wishlist | Scan/import roaster data, remaining stock | Partner roaster products | A's library + B's remaining stock + AI bag recognition | Covers freshness and running low without accounts |
| Taxonomy / matrix | Tasting-notes explorer links notes to origins/processes | — | — | Next Cup's own bucket taxonomy driving recommendations | Unclaimed by all three; this is the positioning |
| Dial-in | Extraction yield vs target window | Graphs to repeat a brew | Taste rating → which variable to change (rule-based) | C's taste-first guidance + AI proposals the user taps to accept | Matches "AI proposes, user decides" |
| Devices | Two scale brands | Many scales + pressure devices | ~16 scale brands | Defer; open decision | Hardware cost and protocol work; not core |
| Data ownership | CSV/JSON export, import from B, no account, iCloud optional | Open source, free | Paid tier, linked-data privacy label | A's model | Matches intake (free, local-first, no accounts) |
| Privacy label | (web: analytics only on consent) | Not linked: location, usage, diagnostics | Includes linked categories | Aim for "Data Not Collected" | No analytics or SDKs by intake |
| Accessibility | Not visible on web | Declares none | Declares VoiceOver, larger text, dark, contrast, reduced motion | Declare all five, verified | Intake requirement |
| Engagement | Streaks, badges, stats | — | Curated feed | Stats yes; streaks only if they never pressure | No dark patterns (safeguard 9) |

## Follow-ups (done)

- Public review research ran on 2026-10-21; its fixes (X1–X8) are in `recon.md` and `features.csv`.
- In-app screens of B and C were not captured; their recon is inferred from listing text.
- The creator video channel is deferred to the creator-recipe import build.
