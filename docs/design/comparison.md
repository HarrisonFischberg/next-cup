# Direction comparison and recommendation

Draft by the builder (Sonnet) for the owner's decision; under
`~/.claude/skills/new-app` the recommendation is Opus's to confirm, so it can
be re-checked in the next phase. The owner chooses.

Side-by-side screenshots: `docs/design/screenshots/compare/` (`recipe`,
`timer`, `log`, `journal`, each in `-default` and `-ax`; top row light, bottom
row dark; left to right concepts 1 to 5).

| | 1 Charcoal & Crema | 2 Quiet Ceramic | 3 Terracotta | 4 Steel & Kraft | 5 Late-Night Café |
| --- | --- | --- | --- | --- | --- |
| Feels like | A good bar | A tea room | A pottery studio | A lab bench | A café after dark |
| Best moment | Timer numerals | Water gauge | Dial timer | Whole recipe lit up while timing | Spotlight timer |
| Logging speed | Steppers: even, slow for big jumps | Typed: fastest for exact numbers | Sliders: fast, coarse | Tiles with -/+: steady | Wheels: slowest, most pleasant |
| Wet hands | Good | Good (large disc) | Best (huge targets) | Good | Fair |
| Dense data (journal, stats later) | Good | Sparse, wastes space | Cards waste space | Best | Fair |
| Warmth for a coffee app | High in dark | High | Highest | Lowest | High |
| Risk | Close to a generic premium look | Very quiet; "as awesome as possible" may want more | Playful may read casual to aficionados | Cold; all-caps heavy | Looks best in dark; light mode is a menu card |
| Heuristic score | 29 | 28 | 30 | 31 | 28 |

## Recommendation: Steel & Kraft (4), runner-up Late-Night Café (5)

The audience brews precisely every day and logs numbers. Concept 4 shows the
whole recipe while the timer runs, keeps every target beside the value being
entered, and scales best to the later screens that are mostly data (bean
library, best-so-far card, taxonomy matrix). It was the one concept walked
through end to end on the simulator and held up. Its weakness is coldness, and
the fix is cheap: keep its structure and borrow warmth from concept 5 (brass
for the orange, a softer display face for titles) during the design-system
step.

Concept 5 is the one to pick if atmosphere matters more than speed: its dark
mode is the most striking and a good fit for early-morning brewing. Concept 3
is the safest choice for friendliness and large targets. Concept 1 is the
most refined but the least distinct. Concept 2 is the calmest and has the best
number entry, at the cost of density.

## Decision needed

One pick (or a named hybrid such as "4's structure with 5's palette"). On your
pick: merge that branch into main, remove the other worktrees and `ui-*`
branches, then Phase 3C writes `DESIGN.md`, tokens and component states.
Branches: `ui-1` Charcoal & Crema, `ui-2` Quiet Ceramic, `ui-3` Terracotta,
`ui-4` Steel & Kraft, `ui-5` Late-Night Café (local only, never pushed).
