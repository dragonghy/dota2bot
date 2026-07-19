# Iteration 0004 — Decision

## Change (commit `9260ccf`, aba_push.lua + TS in sync)

1. Significant-advantage threshold: networth 15k → **10k** (turbo
   reaches 10k advantage by ~15-20 min when a side is actually ahead).
2. Push-desire caps: base 0.82 → **0.85**; with advantage 0.92 →
   **0.95** (decisively above farm's 0.9, so fat cores close).
3. **Closing urgency (new)**: past the time a game of this mode should
   be over — turbo **25 min**, normal 40 — the cap floors at 0.92 and
   base desire gets +0.25, applied BEFORE the safety min-gates
   (retreat/outnumbered protections still bite).

## Deploy

Farm restarted from scratch on `iter-0004` (owner's instruction):
new run prefix **`soak/run_20260719_0716`**, 16 slots, clean version
stamps. In-flight iter-0002/0003 games were sacrificed. The 35-min wall
backstop from iter-0003 is now active too (loops restarted), plus the
40-game-min overtime forfeit.

## Expected metric movement (score from run_20260719_0716)

- First rax: 38 min → **< ~28 min**; most games end 25–35 min.
- No game exceeds ~42 game-min (overtime forfeit) or 35 wall-min (kill
  backstop — should never fire now).
- Radiant winrate stays ~50–65% (draft fix holding); watch feeder
  anomalies on cores while ahead (dive risk from higher aggression).
