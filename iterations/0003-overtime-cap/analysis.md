# Iteration 0003 — Analysis

Owner-driven, same session as 0001/0002. Two triggers:

1. **Owner observed game processes burning 30+ wall-minutes.** The
   post-draft-fix cohort confirms it: 14 finished `iter-0001-dirty` games
   (run `soak/run_20260719_0630`) ran **46–74.5 game-min (avg ~60)** at
   effective timescale ~2.3× → 25–35 wall-min per game. Fair drafts made
   games LONGER: with neither side stomping, the weak closing logic
   (fixed only in iter-0002, which these games predate) stalls even more.
   The only existing bound was `GAME_CAP_MIN=45` wall-minutes in
   `soak_loop.sh` — a `kill -9` that loses the game's scoreboard. There
   was **no game-time cap at all**.
2. **Version stamps read `iter-0001-dirty`** — the farm checkout had a
   stale `bots/Customize/general.lua` modification left over from the
   removed external `draft.py` flow (hardcoded team lists, dead since
   in-game drafting landed). Restored via `git checkout --` on the farm;
   stamps are clean from iter-0003 on.

Also confirmed from this cohort: **the iter-0001 draft fix works** —
Radiant lineups now vary every game and Dire wins games (4–5 of 14 vs
0/18 before).

## Draft-fix scoring (iter-0001, from 14 fair-draft games)

- Radiant win rate: 100% → **~64–68%** (small sample; keep watching).
- Radiant lineup: 1 frozen 5-set in 18/18 → **all 14 games distinct**.
- `script_version` stamped on every row (was `unknown` on all 26 old rows).
