# Iteration 0011 — "Eyes" pipeline first run (2026-07-20)

**Context.** Owner's strategy reset: econ A/B only for macro changes (Class A);
micro-behavior fixes ship on behavioral evidence (Class B, runbook §1). Owner's
challenge: "you watch a replay but can't reach human-like conclusions about who
played well — how will you gain that ability?" Answer built this session:

- `tools/batch_test/behavioral/storyboard.py` — renders each detected team
  fight as a sequence of 2D minimap PNG frames (positions, HP%, trails, deaths).
  The agent CAN read images → this is literal vision over replays.
- `tools/batch_test/behavioral/report_card.py` — per-hero judgment metrics:
  fight participation, spectator fights, death contexts (solo/outnumbered/even),
  distance to team centroid, damage activity.
- `tools/batch_test/scenario/` — scenario-assertion harness (v1: every organic
  in-game incident of a class, e.g. "ally attacked nearby", is scored against a
  reaction assertion; no cheats needed. See docs/SCENARIO_TESTING.md).

## First run on a fresh all-fixes-live replay (20260720_044026_slot1)

Detector counts (1 game, all 4 promoted behaviors active):
idle_while_ally_dies **2** (pre-fix baseline ~7/game), sandwiched_walk 8
(baseline ~11), tp_under_threat 6, tp_home_wasteful 5, overextend_alone 7,
unpunished_tower_dive 3.

**Reading the storyboards found a structural miss (filed as #18):**
fight 24, 6:45–7:41 — WK(74%)+Shaman dive the dire safe-lane corner into a
visible 2v2 ("parity" → SafeToCommitFight allows). Ember+Axe arrive from fog →
2v4; WK dies 6:59, Shaman dies 7:01 (to creeps). Meanwhile Sniper idles mid,
Lich/Slardar top — nobody rotates. WK respawns and **walks back to the same
corner** → dies again 7:27.

Why the shipped guards missed it:
1. `ShouldRegroupNotSolo` defines alone as "no ally within 1500" — a 2-man
   overextension doesn't trigger; 2vN still feeds.
2. `SafeToCommitFight`'s numbers check is instantaneous + visible-only —
   "parity at engage" deep in enemy territory systematically overestimates
   safety (fog reinforcements). Fix direction (Class A, #18): depth-discounted
   numbers — deeper past the enemy midline requires advantage, not parity;
   or count alive-but-unseen enemies as nearby.

Also concrete: WK's "respawn → walk straight back to the death spot" loop is
its own bad behavior (tracked in #17).

**The capability loop works**: storyboard frames were sufficient to reach the
same kind of conclusions the owner reaches watching the replay (who fed, who
watched, why the guard logic missed). Each such conclusion → detector/issue →
fix → scenario/behavioral verification.
