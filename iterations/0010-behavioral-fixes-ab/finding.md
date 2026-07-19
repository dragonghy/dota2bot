# Iteration 0010 — Behavioral fixes #3/#4/#5: A/B is noise-limited

**Date:** 2026-07-19
**Branch:** claude/affectionate-dirac-qumja6 → main
**Status:** fixes implemented + gated on main (INERT); NOT promoted. Issues #3/#4/#5 stay OPEN.

## What was done

Three sub-agents (worktree-isolated) implemented gated fixes for the owner's
top replay-observed bugs, each `IsModeTurbo() + IsSoakCandidate('<id>')` gated
(inert until an A/B wave activates it, so shipped code is unchanged):

- **#3 `tpsafe`** (`J.ShouldWalkNotTp`) — enemy on face + can walk + survivable → step to safety before channeling retreat TP. Detector: `tp_under_threat`.
- **#4 `nodive`** (`J.ShouldSuppressDive` / `J.SafeToCommitFight`) — about to walk/charge into 2+ enemies with no kill & no numbers → raise retreat desire. Wired into `mode_retreat_generic`, spirit_breaker charge, PA blink. Detector: `sandwiched_walk`.
- **#5 `fight`** (`J.EvalTeamfightIdle` / `J.ResolveTeamfightIdle`) — idle near a focused/dying ally → 'help' (suppress retreat, engage) or 'flee' (raise retreat). Detector: `idle_while_ally_dies`.

All three cherry-picked onto main, gated, verified (0 luacheck, 20 unit + smoke pass).
Added an `'all'` candidate id to `J.IsSoakCandidate` to activate every gated
experiment at once, so one wave+swap validates the whole bundle.

## A/B result (bundle, cand='all')

Golden farm, run_20260719_1601, 12-game waves, paired radiant/dire swap.

| metric | radiant wave (cand=R) | dire wave (cand=D) | paired (bias-corr) |
|---|---|---|---|
| XPM diff (cand−base) | −15 | −72 | **−43** |
| GPM diff | −14 | −66 | **−40** |
| deaths diff | −0.05 | +0.80 | **+0.38** |

Behavioral (slot-1 replays, bundle-side vs baseline-side heroes):
- `idle_while_ally_dies`: **11 → 1** (strong reduction — #5 clearly changes the behavior)
- `sandwiched_walk`: **8 → 6** (modest — #4)
- `tp_under_threat`: **2 → 2** (no effect — #3; rare event, tiny sample)

## The real finding: the econ/deaths A/B is noise-limited

Per-game candidate−baseline **team-GPM-sum** diffs ranged **−1380 … +973**;
team-deaths diffs **−8 … +11**. The soak draft assigns *different random
heroes to each side every game*, so a radiant-vs-dire comparison is confounded
by draft, and the swap only cancels the ~+1.5k **side** bias, not draft
variance. Per-game SD ≈ 600 GPM → SE over 12 games ≈ 170 GPM. A ~40 GPM effect
is **deep in the noise**; the +0.38 deaths likewise not significant. The two
waves even disagree on direction. **Conclusion: this harness cannot resolve a
behavior-fix-sized effect at 12 games/wave.**

## Decision

- **Do NOT promote.** No evidence of econ/death improvement; directionally
  slightly negative (bots more passive: #4 retreat-desire costs farm, #5 'help'
  branch joins losing fights → deaths). Keep #3/#4/#5 gated on main (inert).
- Issues #3/#4/#5 remain OPEN.
- Farm rolled back to clean baseline (soak_side `{false,false}`, HEAD 3da956a).

## Next (recommendations for the next agent)

1. **Mirrored-draft A/B** — same 10 heroes both sides, swap which side carries
   the fix. Removes the ±600 GPM/game draft noise; only then can econ resolve
   small effects. This is the #1 unblock.
2. **Use the behavioral detectors as the primary metric** for behavior fixes —
   they are dense (25 findings/replay) and directly measure the target bug,
   unlike noisy end-of-game econ.
3. **Refine the fixes** rather than ship as-is:
   - #5: for non-buggy heroes make it **flee-only** (the safe half); the 'help'
     branch (stay & fight) is the likely death-adder.
   - #4: soften — `BOT_MODE_DESIRE_HIGH` retreat on any 2-enemy pocket is too
     blunt; scope to genuine no-escape / already-committed cases.
   - #3: rarely fires; fold into #4's positioning logic or drop.
