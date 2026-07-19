# Iteration 0002 — Decision

## Hypothesis

Turbo games average 51 min because the push-desire arithmetic makes closing
impossible: farm (0.9) outranks the push cap (0.82) for healthy cores, and
three separate gates collapse push desire exactly during sieges. If pushing
outranks farming when clearly ahead and sieges survive contact with
defenders, games should end shortly after the first rax instead of 10–27
minutes later, pulling average duration into the low 30s.

## Changes shipped (each its own commit)

1. `bots/BotLib/hero_sniper.lua` — Shrapnel charge check: probe the
   ability-charge API, else use "no recharge ticking" as charges-to-spare.
   Expect: Sniper farm speed up slightly, ~2.4k console warnings/game gone.
2. `bots/FunLib/jmz_func.lua` — `IsModeTurbo()` via `GetGameMode()` with
   courier fallback, cached per match. Locked by `tests/test_mode_detect.lua`.
   Expect: turbo phase boundaries guaranteed active on the farm.
3. `bots/FunLib/aba_push.lua` + `typescript/bots/FunLib/aba_push.ts` (kept in
   sync) — five gate changes, see analysis.md. Expect: **avg duration
   51 min → low 30s; rax→end gap toward ~5 min; hero building damage up
   severalfold.**

## Metrics for iteration 0003 to score (post-iter-0002 cohort)

- Avg game duration and the rax→throne gap (from `Building:` timelines).
- Hero building damage per minute per team (from signout scoreboards).
- Radiant win rate ~50% (scores iter-0001's draft fix).
- Loser-side building damage: if still ~0 with fair drafts, hunt a
  defend-lock next.
- Sniper GPM (charge fix) and absence of the GetCurrentCharges warning line.

## Risks

- Raising the winning team's aggression could increase throw rate
  (high-ground dives while ahead). Watch win-rate stability of the
  advantaged team and `feeder` anomalies on cores while ahead.
- Push cap 0.92 with-advantage now beats defend caps in some spots; the
  ancient gate still hard-blocks at 2+ intruders, which bounds the risk.
