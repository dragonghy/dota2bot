# Iteration 0005 — Analysis

Owner-driven (live session). Full iter-0004 cohort landed: 11 games,
`soak/run_20260719_0716`.

## iter-0004 scoring vs owner acceptance criteria

| Criterion | Result |
|---|---|
| First T1 at 10–20 min | ✓ all games (10.7–22.6, mostly in range) |
| T2s ~30 min | ✓ (first T2s 24–34 min) |
| All towers down < 40 min | ✗ — organic sieges reached rax by ~34–39 in the
best games, but even games stalled until the 40-min forfeit, and the
post-forfeit base-race takes 5–15 min to physically finish → durations
**44.2–56.0 min (avg ~49)** |
| Winner balance | **5 radiant / 6 dire — ~50/50**, draft fix fully validated |

## Root cause of the residual stall (the key finding)

Push desire is computed as `nPushDesire × HP` remapped onto `[0, cap]` —
**multiplicative**. With base `nPushDesire = 0.5–0.65`, an even-game core
peaked at ~0.6 — below farm's 0.9 — no matter how high the cap went.
Raising caps (iter-0002/0004) only helped teams that were already ahead
(advantage bonuses push the product over 1.0). Even games therefore
farmed until the forfeit fired. The owner's read ("push desire is still
not high enough; farming must not outcompete pushing") was exactly right.
