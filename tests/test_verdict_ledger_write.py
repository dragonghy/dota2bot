#!/usr/bin/env python3
"""The harvest must WRITE the cross-wave game ledger, not leave it to be
re-assembled by hand out of the wave verdicts.
[owed `games_ledger_cross_wave_accounting`, director 2026-09-13T09:xxZ,
 `iterations/reports/director/efficiency_202637.md` §2 / §5 丙]

WHY THIS EXISTS
    `iterations/games_ledger.jsonl` sat at 391 rows / `run_20260719_1353` for
    three consecutive weeks while eight waves (W62-W69) produced ~1300 scored
    games.  The cross-wave, machine-readable game account had never existed.

    The failure shape is the interesting half.  It is silent, and it is more
    hidden than an ordinary silence: the efficiency ledgers got written anyway,
    because whoever wrote one assembled the game count on the spot out of the
    eight `W6*_verdict.json` files.  Nobody was ever blocked.  What it cost is
    that the DENOMINATOR was chosen fresh each week by the person assembling it
    (one week they all happened to share a `scored_games` key -- luck, not a
    guarantee), so `$/effective game` was not comparable across the three weeks
    that reported it.

    It also could not be caught by any wave-local harvest checklist: the
    obligation belongs to no wave and no candidate id, so there is no line for
    it to be missing FROM.  A desk can audit its own checklist item by item,
    score full marks, and still never write the ledger.  That is why the fix is
    a carrier change (the harvest step that already parses every per-game file
    now appends the rows) and why it is pinned here rather than restated in a
    charter: the obligation had been carried in prose for three weeks and was
    reported as a dropped baton twice before this.

HOW IT TESTS
    On the REAL script, driven over real corpora in temp dirs -- no second copy
    of the row schema (a test that owns its own copy passes when both copies
    are wrong the same way).

    Case 3 is the load-bearing one.  Per-game files are named
    `<YYYYmmdd_HHMMSS>_slot<N>.analysis.json` with no run token, the 4x1 waves
    launch in the same second, and their slot cadence matches, so the same
    basename naming two DIFFERENT games across two runs is the NORM (GH #225
    measured it at the filesystem layer: 208 files became 188).  A ledger keyed
    on `game_id` alone would reinstate that loss inside the ledger, silently,
    because the ledger carries no expected count to miss it against.

    M1 mutation: drop the ledger write entirely            -> case 1 red.
    M2 mutation: de-duplicate on `game_id` alone           -> case 3 red.
    M3 mutation: `finished` from `econ_winner` (never null) -> case 4 red.
    M4 mutation: write the ledger before the #225 refusals -> case 5 red.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "batch_test", "soak", "recover_verdict.py")
CAND = "ledgercand"

failures = []
checks = 0


def check(cond, msg):
    global checks
    checks += 1
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def game(stamp, winner):
    return {
        "script_version": stamp, "winner": winner,
        "winner_by": "engine_natural", "econ_winner": "radiant",
        "mode": "turbo", "duration_s": 1200, "duration_min": 20.0,
        "players": ([{"team": "radiant", "hero": "npc_dota_hero_axe", "gpm": 520,
                      "xpm": 500, "kills": 3, "deaths": 5, "assists": 4,
                      "level": 20, "last_hits": 100} for _ in range(5)] +
                    [{"team": "dire", "hero": "npc_dota_hero_lion", "gpm": 500,
                      "xpm": 500, "kills": 3, "deaths": 5, "assists": 4,
                      "level": 20, "last_hits": 100} for _ in range(5)]),
    }


def write_run(d, seed, n_ab, n_ba, unfinished=0, first_slot=0):
    """One run directory = one seed, two waves, raw tag basenames."""
    os.makedirs(d, exist_ok=True)
    slot = first_slot
    left = unfinished
    for side, n in (("radiant", n_ab), ("dire", n_ba)):
        for _ in range(n):
            winner = None if left > 0 else "radiant"
            if left > 0:
                left -= 1
            g = game("mirror:%s:s%s:%s" % (CAND, seed, side), winner)
            name = "20260915_%06d_slot%d.analysis.json" % (slot, slot % 16)
            json.dump(g, open(os.path.join(d, name), "w"))
            slot += 1
    return slot


def run(pool, ledger, wave="W99", extra=()):
    argv = [sys.executable, SCRIPT, pool, CAND]
    if ledger:
        argv += ["--ledger", ledger, "--ledger-wave", wave]
    argv += list(extra)
    p = subprocess.run(argv, capture_output=True, text=True)
    return p


def rows_of(ledger):
    if not os.path.exists(ledger):
        return []
    return [json.loads(ln) for ln in open(ledger) if ln.strip()]


# --------------------------------------------------------------------------
# 1. The harvest writes a row per loaded game, carrying the fields that let a
#    later reader recompute any denominator it needs.
# --------------------------------------------------------------------------
POOL1 = tempfile.mkdtemp(prefix="ledger_w_")
write_run(os.path.join(POOL1, "runA"), "901", 10, 10)
write_run(os.path.join(POOL1, "runB"), "902", 10, 10, first_slot=100)
LEDGER1 = os.path.join(tempfile.mkdtemp(prefix="ledger_f_"), "games_ledger.jsonl")

P1 = run(POOL1, LEDGER1)
check(P1.returncode == 0, "guard: the tool scored the corpus (exit 0)")
V1 = json.loads(P1.stdout) if P1.returncode == 0 else {}
R1 = rows_of(LEDGER1)

check(len(R1) == 40,
      "40 games in, 40 ledger rows out (got %d) -- the harvest wrote the account"
      % len(R1))
check(V1.get("input", {}).get("games_loaded") == len(R1),
      "the ledger row count equals the verdict's own games_loaded "
      "(%s vs %d) -- one account, not two"
      % (V1.get("input", {}).get("games_loaded"), len(R1)))
check(all(r.get("wave") == "W99" for r in R1),
      "every row carries the wave label, so the account is CROSS-wave")
check(sorted(set(r.get("seed") for r in R1)) == ["901", "902"] and
      sorted(set(r.get("arm_side") for r in R1)) == ["dire", "radiant"],
      "rows carry seed and arm_side, so a reader can rebuild the "
      "per-seed/per-leg denominators the verdict applied")
check(all(r.get("run_prefix") in ("runA", "runB") for r in R1),
      "rows carry the run they came from")
check(V1.get("ledger", {}).get("appended") == 40 and
      V1["ledger"].get("finished") == 40,
      "the verdict self-reports what it wrote (appended/finished), so the "
      "write is auditable without re-reading the ledger")

# --------------------------------------------------------------------------
# 2. Re-harvesting the same corpus does not duplicate it.
# --------------------------------------------------------------------------
P2 = run(POOL1, LEDGER1)
check(P2.returncode == 0, "guard: second harvest also exited 0")
R2 = rows_of(LEDGER1)
check(len(R2) == 40,
      "a re-run appends nothing (still %d rows) -- re-harvesting is safe"
      % len(R2))

# --------------------------------------------------------------------------
# 3. LOAD-BEARING: the same basename from two different runs is two games.
#    De-duplicating on game_id alone would silently drop the second.
# --------------------------------------------------------------------------
POOL3 = tempfile.mkdtemp(prefix="ledger_w_")
write_run(os.path.join(POOL3, "run1"), "903", 10, 10)
write_run(os.path.join(POOL3, "run2"), "904", 10, 10)   # SAME slot numbering
LEDGER3 = os.path.join(tempfile.mkdtemp(prefix="ledger_f_"), "games_ledger.jsonl")
P3 = run(POOL3, LEDGER3)
check(P3.returncode == 0, "guard: colliding-basename pool scored (exit 0)")
R3 = rows_of(LEDGER3)

basenames = set(r["game_id"] for r in R3)
check(len(basenames) < len(R3),
      "guard: the corpus really does collide on game_id (%d tags for %d games) "
      "-- without this the case below is vacuous" % (len(basenames), len(R3)))
check(len(R3) == 40,
      "all 40 games land despite the collision (got %d): the ledger keys on "
      "(run_prefix, game_id), so W14's 208->188 loss is not reinstated here"
      % len(R3))
check(len(set((r["run_prefix"], r["game_id"]) for r in R3)) == 40,
      "and the 40 rows are 40 distinct keys, not 40 rows with 20 identities")

# --------------------------------------------------------------------------
# 4. `finished` is the winner-bearing predicate, not the economy fallback.
# --------------------------------------------------------------------------
POOL4 = tempfile.mkdtemp(prefix="ledger_w_")
write_run(os.path.join(POOL4, "runA"), "905", 10, 10, unfinished=6)
LEDGER4 = os.path.join(tempfile.mkdtemp(prefix="ledger_f_"), "games_ledger.jsonl")
P4 = run(POOL4, LEDGER4)
check(P4.returncode == 0, "guard: corpus with unfinished games scored (exit 0)")
R4 = rows_of(LEDGER4)
V4 = json.loads(P4.stdout) if P4.returncode == 0 else {}
fin = sum(1 for r in R4 if r.get("finished"))
check(len(R4) == 20 and fin == 14,
      "20 rows, 14 of them finished (got %d/%d): an unfinished game is IN the "
      "ledger and OUT of the effective count -- both facts survive, and "
      "`econ_winner` (never null) does not stand in for `winner`" % (fin, len(R4)))
check(V4.get("ledger", {}).get("finished") == fin,
      "the verdict's self-report agrees with the rows on disk")

# --------------------------------------------------------------------------
# 5. A corpus the tool REFUSES writes no ledger.  A ledger that admits games
#    the verdict rejected is worse than no ledger: it is a second account,
#    disagreeing with the first, with nothing marking which one is trusted.
# --------------------------------------------------------------------------
POOL5 = tempfile.mkdtemp(prefix="ledger_w_")
write_run(os.path.join(POOL5, "runA"), "906", 10, 10)
open(os.path.join(POOL5, "runA", "broken.analysis.json"), "w").write("{not json")
LEDGER5 = os.path.join(tempfile.mkdtemp(prefix="ledger_f_"), "games_ledger.jsonl")
P5 = run(POOL5, LEDGER5)
check(P5.returncode == 2,
      "guard: the unparseable file was refused (exit %d, want 2)" % P5.returncode)
check(not os.path.exists(LEDGER5),
      "a refused harvest wrote no ledger rows at all")

# --------------------------------------------------------------------------
# 6. No --ledger, no writes: wiring the ledger did not make the tool start
#    touching files the caller did not name.
# --------------------------------------------------------------------------
LEDGER6 = os.path.join(tempfile.mkdtemp(prefix="ledger_f_"), "games_ledger.jsonl")
P6 = run(POOL1, None)
check(P6.returncode == 0 and not os.path.exists(LEDGER6),
      "without --ledger the tool writes no ledger and still scores")
check("ledger" not in json.loads(P6.stdout),
      "and the verdict carries no ledger stanza it did not earn")

print("\n%d checks, %d failed" % (checks, len(failures)))
sys.exit(1 if failures else 0)
