#!/usr/bin/env python3
"""[slotdust] The reachability fit: a model the corpus can refute (GH #441).

WHAT THIS FILE IS FOR.  `slotdust_arbitration.py` counts dust casts that no
shipped configuration could have produced, and the whole design rests on
`reachable_unarmed` -- a HYPOTHESIS about which team slots the unarmed scan of
`J.IsClosestToDustLocation` can return.  Replay-check ran it over 64 W40 games
and got `EXCLUSIVE-DOMAIN DUST CASTS armed 14 baseline 9`, and by that script's
own LIMIT 6 a non-zero baseline falsifies the branch partition or the slot
mapping.  Nine dire casts (pids 6/7/8) survived B2/B3/B4 on a leg that cannot
produce them.

THE STRUCTURAL REASON NO RERUN OF THAT SCRIPT COULD HAVE SETTLED IT.  The
exclusive column is DEFINED by the hypothesis: a cast from a slot the hypothesis
calls reachable took `continue` before B2/B3/B4 were consulted, so the one
number that discriminates the competing models -- "how many casts from a
REACHABLE slot survive all three exclusions" -- was never computed by any run,
on any corpus.  It is not a number that came out small or noisy.  It does not
exist.  A model can only be corrected by a reading it does not itself define.

THE FIT.  Run the three ungated exclusions for EVERY cast and tabulate
survivors by team slot.  Then one line does the work: on the BASELINE leg a slot
with a surviving cast MUST be reachable, so {slots with baseline survivors} is a
subset of any surviving hypothesis.  Three are on the table, and they differ
only in what the module-level `AllyPIDs` cache (jmz_func.lua:11541) holds:

    H0-shipped              radiant {1,2,3,4}   dire {5}
    H1-leak-radiant-cached  radiant {1,2,3,4}   dire {1,2,3,4}
    H2-leak-dire-cached     radiant {5}         dire {5}

The observed shape (dire baseline survivors on slots 2/3/4) refutes H0 and H2
and leaves H1 -- and H1's own falsifier is a cell no run has ever printed: dire
baseline slot 5.  The ARMED leg reads the loop INDEX, not the pid values, so it
is immune under all three; only the baseline rows carry information.  That is
also why this defect can only break the CONTROL, never the fix.

WHAT THIS FILE ASSERTS, AND THE ONE IT WOULD BE EASIEST TO FAKE.  Section 0 is
the load-bearing one: the claim in the patch is that every pre-existing column
keeps its exact value, and prose saying so is worth nothing.  So the reference
cascade is TRANSCRIBED INDEPENDENTLY here and the two are compared over a
battery of synthetic games -- the same discipline the script's own [source-
parity] uses, and with the same caveat it learned the hard way (LIMIT 9/10): a
comparison run over inputs that cannot separate two bodies is not evidence they
are the same body, so the battery walks every slot, every leg and every one of
the three exclusions.
"""
import collections
import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "batch_test", "behavioral",
                    "slotdust_arbitration.py")
sys.path.insert(0, os.path.dirname(TOOL))
import slotdust_arbitration as sd  # noqa: E402

PASS, FAIL = [0], [0]


def check(name, cond, detail=""):
    if cond:
        PASS[0] += 1
        print("  ok   %s" % name)
    else:
        FAIL[0] += 1
        print("  FAIL %s%s" % (name, ("  -- " + detail) if detail else ""))


# ---------------------------------------------------------------- fixtures
RAD, DIRE = sd.RADIANT, sd.DIRE
DUST = sd.DUST


def snap(hero, idx, team, pid, t, x=0.0, items=None):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "player_id": pid,
            "x": x, "y": 0.0, "hp": 500, "hp_pct": 0.5,
            "items": items if items is not None else [""] * 9}


def game(caster_team, caster_pid, sandking_pid=None, radiance_team=None,
         damage_at=None, t_cast=10.0):
    """Ten pre-horn bodies, one dust cast, and the three exclusions dialled."""
    snaps = []
    for pid in range(10):
        team = RAD if pid < 5 else DIRE
        name = (sd.SANDKING if pid == sandking_pid
                else "npc_dota_hero_h%d" % pid)
        items = ([sd.RADIANCE] + [""] * 8) if team == radiance_team else None
        is_caster = (team == caster_team and pid == caster_pid)
        for t in (-30.0, t_cast - 1.0, t_cast + 1.0):
            snaps.append(snap(name, 100 + pid, team, pid, t,
                              x=0.0 if is_caster else 9000.0, items=items))
    caster = "npc_dota_hero_h%d" % caster_pid
    events = []
    if damage_at is not None:
        events.append({"t": damage_at, "type": "DAMAGE",
                       "actor": "npc_dota_hero_h0", "target": caster,
                       "inflictor": "", "value": 100,
                       "actor_hero": True, "target_hero": True})
    events.append({"t": t_cast, "type": "ITEM", "actor": caster,
                   "target": caster, "inflictor": DUST, "value": 0,
                   "actor_hero": True, "target_hero": True})
    return {"snapshots": snaps, "events": events}


# ------------------------------------------------- 0. column parity
print("=== 0. column parity: the pre-existing columns are untouched ===")


def reference(tl, armed_side):
    """The cascade AS IT WAS before the fit, transcribed independently.

    Deliberately NOT a call into the module: the claim under test is that the
    refactor left these nine columns alone, and an oracle that shares the code
    it is judging cannot say so.
    """
    snaps, events = tl["snapshots"], tl["events"]
    bodies, born = set(), {}
    for s in snaps:
        k = (s["hero"], s["idx"])
        born[k] = min(born.get(k, s["t"]), s["t"])
    bodies = {k for k, t0 in born.items() if t0 < 0.0}
    first = {}
    for s in snaps:
        k = (s["hero"], s["idx"])
        if k in bodies and (k not in first or s["t"] < first[k]["t"]):
            first[k] = s
    key_of = {k[0]: (k, first[k]["team"], first[k]["player_id"]) for k in first}
    armed_team = RAD if armed_side == "radiant" else DIRE
    sandking = any(k[0] == sd.SANDKING for k in bodies)
    radiance_teams = {s["team"] for s in snaps
                      if sd.RADIANCE in (s.get("items") or ())}
    dmg = collections.defaultdict(list)
    for e in events:
        if e.get("type") == "DAMAGE" and e.get("target_hero"):
            dmg[e["target"]].append(e["t"])

    out = {leg: collections.Counter() for leg in ("armed", "baseline")}
    for e in events:
        if e.get("type") != "ITEM" or e.get("inflictor") not in (DUST,
                                                                 sd.GUNGIR):
            continue
        k, team, pid = key_of[e["actor"]]
        leg = "armed" if team == armed_team else "baseline"
        if e["inflictor"] == sd.GUNGIR:
            out[leg]["gungir_casts"] += 1
            continue
        out[leg]["dust_casts"] += 1
        slot = pid + 1 if team == RAD else pid - 4
        enemy_team = DIRE if team == RAD else RAD
        reach = slot in ((1, 2, 3, 4) if team == RAD else (5,))
        if reach:
            out[leg]["reachable_slot"] += 1
            continue
        out[leg]["unreachable_slot"] += 1
        if sandking:
            out[leg]["blocked_b2_sandking"] += 1
            continue
        if enemy_team in radiance_teams:
            out[leg]["blocked_b3_radiance"] += 1
            continue
        if [t for t in dmg.get(e["actor"], ())
                if e["t"] - sd.B4_DAMAGE_WINDOW <= t < e["t"]]:
            out[leg]["blocked_b4_recent_damage"] += 1
            continue
        out[leg]["exclusive"] += 1
    return out


BATTERY = []
for team, pids in ((RAD, range(5)), (DIRE, range(5, 10))):
    for pid in pids:
        for armed in ("radiant", "dire"):
            BATTERY.append(("plain", team, pid, armed, {}))
            BATTERY.append(("b2", team, pid, armed,
                            {"sandking_pid": 9 if team == RAD else 0}))
            BATTERY.append(("b3", team, pid, armed,
                            {"radiance_team": DIRE if team == RAD else RAD}))
            BATTERY.append(("b4", team, pid, armed, {"damage_at": 9.6}))
            BATTERY.append(("stale-dmg", team, pid, armed, {"damage_at": 8.9}))

mismatch = []
for tag, team, pid, armed, kw in BATTERY:
    got = sd.scan_game(game(team, pid, **kw), armed)
    if got is None:
        mismatch.append((tag, team, pid, armed, "REFUSED"))
        continue
    ref = reference(game(team, pid, **kw), armed)
    for leg in ("armed", "baseline"):
        for col in sd.KEYS:
            if col == "ring_nonempty":
                continue          # geometry, not part of the cascade
            if got[0][leg][col] != ref[leg][col]:
                mismatch.append((tag, team, pid, armed, leg, col,
                                 got[0][leg][col], ref[leg][col]))
check("the battery really exercised every slot, leg and exclusion",
      len(BATTERY) == 100, "%d cases" % len(BATTERY))
check("every pre-existing column matches an independently written cascade",
      not mismatch, str(mismatch[:3]))

# and the battery is not vacuous: it has to contain all four outcomes
seen = collections.Counter()
for tag, team, pid, armed, kw in BATTERY:
    res = sd.scan_game(game(team, pid, **kw), armed)[0]
    for leg in ("armed", "baseline"):
        for col in ("exclusive", "blocked_b2_sandking", "blocked_b3_radiance",
                    "blocked_b4_recent_damage", "reachable_slot"):
            seen[col] += res[leg][col]
check("...over a battery that actually reaches all five outcomes",
      all(seen[c] > 0 for c in ("exclusive", "blocked_b2_sandking",
                                "blocked_b3_radiance",
                                "blocked_b4_recent_damage",
                                "reachable_slot")), str(dict(seen)))


# ------------------------------------------------- 1. the new number
print("=== 1. the fit computes what the exclusive column cannot ===")

res = sd.scan_game(game(DIRE, 9), "dire")[0]          # dire slot 5, reachable
check("a REACHABLE-slot cast is never exclusive (that is the old behaviour)",
      res["armed"]["exclusive"] == 0 and res["armed"]["reachable_slot"] == 1)
check("...yet the fit records it as a cast AND as a B2/B3/B4 survivor",
      res["armed"]["fit_casts_s5"] == 1 and res["armed"]["fit_survive_s5"] == 1)

for kw, why in (({"sandking_pid": 0}, "b2"), ({"radiance_team": RAD}, "b3"),
                ({"damage_at": 9.6}, "b4")):
    res = sd.scan_game(game(DIRE, 9, **kw), "dire")[0]
    check("a reachable-slot cast blocked by %s is a cast, not a survivor" % why,
          res["armed"]["fit_casts_s5"] == 1
          and res["armed"]["fit_survive_s5"] == 0)

res = sd.scan_game(game(DIRE, 5), "dire")[0]          # dire slot 1, unreachable
check("the unreachable slot lands in BOTH the old and the new columns",
      res["armed"]["exclusive"] == 1 and res["armed"]["fit_survive_s1"] == 1)

res = sd.scan_game(game(DIRE, 9), "radiant")[0]       # same cast, baseline leg
check("the fit is booked against the leg the caster is on",
      res["baseline"]["fit_survive_s5"] == 1
      and res["armed"]["fit_casts_s5"] == 0)

tot = sum(sd.scan_game(game(DIRE, pid), "dire")[0]["armed"]["fit_casts_s%d"
          % (pid - 4)] for pid in range(5, 10))
check("every dire slot 1..5 is representable in the fit table", tot == 5)


# ------------------------------------------------- 2. the refutation rule
print("=== 2. subset rule: it refutes, and only refutes ===")

check("H0 is not a copy of the model -- it IS the model",
      all(tuple(s for s in sd.SLOTS if sd.reachable_unarmed(t, s))
          == tuple(sd.HYPOTHESES["H0-shipped"][t]) for t in (RAD, DIRE)),
      str(sd.HYPOTHESES["H0-shipped"]))
check("the armed leg cannot discriminate: the union of all three is all slots",
      set().union(*[set(h[DIRE]) | set(h[RAD])
                    for h in sd.HYPOTHESES.values()]) == set(sd.SLOTS))

OBSERVED = {DIRE: {1: 0, 2: 5, 3: 2, 4: 9, 5: 0},
            RAD: {s: 0 for s in sd.SLOTS}}
check("GH #441's nine survivors refute the shipped model",
      [(t, s) for t, s, _ in
       sd.refutations(OBSERVED, sd.HYPOTHESES["H0-shipped"])]
      == [(DIRE, 2), (DIRE, 3), (DIRE, 4)])
check("...and refute H2 (a dire bot cached first) identically",
      len(sd.refutations(OBSERVED, sd.HYPOTHESES["H2-leak-dire-cached"])) == 3)
check("...and leave H1 (a radiant bot cached first) standing",
      sd.refutations(OBSERVED, sd.HYPOTHESES["H1-leak-radiant-cached"]) == [])

DECISIVE = {DIRE: dict(OBSERVED[DIRE]), RAD: dict(OBSERVED[RAD])}
DECISIVE[DIRE][5] = 1
check("ONE dire slot-5 baseline survivor would refute H1 too",
      sd.refutations(DECISIVE, sd.HYPOTHESES["H1-leak-radiant-cached"])
      == [(DIRE, 5, 1)])
check("...which is exactly the cell no run has ever printed",
      "fit_survive_s5" in sd.FIT_KEYS and "fit_casts_s5" in sd.FIT_KEYS)

EMPTY = {t: {s: 0 for s in sd.SLOTS} for t in (RAD, DIRE)}
check("a corpus with no survivors refutes nothing (LIMIT 12)",
      all(sd.refutations(EMPTY, h) == [] for h in sd.HYPOTHESES.values()))
check("a hypothesis that reaches everything is unrefutable here (LIMIT 12)",
      sd.refutations(DECISIVE, {RAD: sd.SLOTS, DIRE: sd.SLOTS}) == [])
check("the count never decides -- one survivor refutes as hard as nine",
      [t for t, _, _ in sd.refutations({DIRE: {2: 1, 1: 0, 3: 0, 4: 0, 5: 0},
                                        RAD: EMPTY[RAD]},
                                       sd.HYPOTHESES["H0-shipped"])] == [DIRE])


# ------------------------------------------------- 3. end to end
print("=== 3. end to end: the report prints the table and the verdict ===")

with tempfile.TemporaryDirectory() as tmp:
    manifest = os.path.join(tmp, "m.jsonl")
    rows, paths = [], []
    # ab layer (radiant armed) -> the DIRE leg is baseline; put the GH #441
    # shape there: survivors on dire slots 2/3/4, none on slot 5.
    for i, pid in enumerate((6, 7, 8)):
        p = os.path.join(tmp, "g%d.timeline.json" % i)
        with open(p, "w") as fh:
            json.dump(game(DIRE, pid), fh)
        rows.append({"game": "g%d" % i, "cand": "slotdust", "seed": 1,
                     "side": "radiant"})
        paths.append(p)
    # a dire slot-5 cast on the ARMED leg: present in the table, and by design
    # unable to refute anything.
    p = os.path.join(tmp, "g9.timeline.json")
    with open(p, "w") as fh:
        json.dump(game(DIRE, 9), fh)
    rows.append({"game": "g9", "cand": "slotdust", "seed": 1, "side": "dire"})
    paths.append(p)
    with open(manifest, "w") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")
    run = subprocess.run([sys.executable, TOOL] + paths
                         + ["--manifest", manifest],
                         capture_output=True, text=True)
    out = run.stdout

check("the run exits 0 and reads all four games", run.returncode == 0
      and "games read: 4" in out, run.stderr[-300:])
check("the fit table is printed", "REACHABILITY FIT" in out)
check("the shipped model is reported REFUTED on this corpus",
      "H0-shipped" in out and "REFUTED" in out
      and "dire slot2" in out and "dire slot3" in out and "dire slot4" in out,
      [ln for ln in out.splitlines() if "H0" in ln])
check("H1 is reported not-refuted, and NOT as confirmed",
      any("H1-leak-radiant-cached" in ln and "not refuted" in ln
          and "not confirmed" in ln for ln in out.splitlines()))
check("the armed dire slot-5 cast is in the table but refutes nothing",
      "H1-leak-radiant-cached" in out
      and not any("H1-leak-radiant-cached" in ln and "REFUTED" in ln
                  for ln in out.splitlines()))
check("both layers are registered (铁律 4(i-a))",
      out.count("REACHABILITY FIT") == 1
      and len([ln for ln in out.splitlines()
               if ln.startswith("    ab ") or ln.startswith("    ba ")]) >= 4)
check("the exclusive column and its LIMIT 6 line are still printed",
      "EXCLUSIVE-DOMAIN DUST CASTS" in out and "LIMIT 6" in out)


# ------------------------------------------------- 4. the ratchet
print("=== 4. ratchet: the limit is written down where it is read ===")

src = open(TOOL).read()
check("LIMIT 12 is in the module docstring, not only in this test",
      "12." in src and "CANNOT CORRECT THE MODEL IT IS DEFINED BY" in src)
check("the docstring says the test only refutes",
      "REFUTES ONLY" in src or "It REFUTES ONLY." in src)
check("the every-slot-survives escape hatch is written down",
      "not about reachability" in src)
check("exactly three hypotheses are on the table",
      sorted(sd.HYPOTHESES) == ["H0-shipped", "H1-leak-radiant-cached",
                                "H2-leak-dire-cached"])
check("the cache this is about is still a module-level local",
      "local AllyPIDs = nil" in
      open(os.path.join(REPO, "bots", "FunLib", "jmz_func.lua")).read())
check("...and the armed leg still reads the loop INDEX, not the pid value",
      "if bSlotDust then nSlot = i end" in
      open(os.path.join(REPO, "bots", "FunLib", "jmz_func.lua")).read())

print()
print("%d passed, %d failed" % (PASS[0], FAIL[0]))
sys.exit(1 if FAIL[0] else 0)
