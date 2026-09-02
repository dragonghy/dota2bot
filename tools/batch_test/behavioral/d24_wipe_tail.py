#!/usr/bin/env python3
"""Is the "solo" in d24_deep_solo_death a fight the hero arrived at WITH allies?

WHY THIS FILE EXISTS (replay-check 2026-09-02T15:xxZ)
-----------------------------------------------------
`d24_deep_solo_death` (detect.py:987) evaluates its `alone` predicate at the
INSTANT OF DEATH:

    alone = no allied hero with hp > 0 within 2500u, at e["t"]

In a lost teamfight deep in enemy territory the allies who pushed in
alongside are already CORPSES by the time the last hero dies, so `alone` is
true by construction.  The detector then prints

    "<hero> died SOLO at depth +N (no ally within 2500) -- pushguard case"

and the whole-run table counts it beside genuine solo dives.  Frame evidence
that this is not hypothetical (W38 seed 2613, `20260902_123428_slot8`,
`sweep_f65fb4`): four dire heroes stood within ~530u of the death spot at
t=845, and lina (853.5) / sven (853.6) / obsidian_destroyer (857.1) /
skeleton_king (857.6) died in 4.1 seconds inside ~600u.  d24 fires on
skeleton_king alone -- the last man of a FOUR-man push -- and calls it solo.

Note the shape is "one finding per wipe, mis-labelled", not "four findings
per wipe": at each earlier death an ally is still alive nearby, so only the
LAST death passes `alone`.  The count is not inflated four-fold; the
DIAGNOSIS attached to it is wrong, and a fix aimed at "stop diving alone"
cannot address a hero that never dived alone.

WHAT IT MEASURES
----------------
For every finding d24 would emit, whether an ALLY DIED within WINDOW seconds
before it and within NEAR units of the death spot (measured at that ally's
own death, i.e. where the ally actually was).  That is the operational
definition of "this was the tail of a group fight, not a solo dive".

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. WINDOW=15s / NEAR=2500u are THIS TOOL'S operational definitions.  The
   dumper carries no "teamfight" field; nothing here is read off the game.
   NEAR is deliberately d24's own leash so the two predicates are commensurable.
2. A wipe-tail death is not automatically a non-finding.  "Kept pushing after
   two team-mates died" is still a bad decision -- it is a DIFFERENT bad
   decision from "dived alone", needing a different fix.  This tool separates
   the two populations; it does not rule either out.
3. The rate is NOT established as differential between the armed and the
   baseline side.  On W38's four seeds the candidate-minus-baseline
   contamination delta is +5.5pp in the ab leg and -8.0pp in the ba leg --
   opposite signs, so by 铁律 4(i-b) that is noise and must not be concluded
   from.  What is established is the LEVEL (~40% of findings), not a bias.

USAGE
    python3 d24_wipe_tail.py <sweep_dir> [<sweep_dir> ...]
    python3 d24_wipe_tail.py --selfcheck
"""
import sys
import os
import glob
import json
import math
import collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detect  # noqa: E402

WINDOW = 15.0   # seconds before this death an ally may have died
NEAR = 2500.0   # d24's own ally leash, reused on purpose (LIMIT 1)
TOL = 3.0       # d24's own state_at tolerance


def _companions(tl, hero, team, t, s, deaths):
    """Allies that died within WINDOW before t and within NEAR of s."""
    out = []
    for e2 in deaths:
        h2 = e2["target"]
        if h2 == hero or tl.teams.get(h2) != team:
            continue
        dt = t - e2["t"]
        if not (0.0 <= dt <= WINDOW):
            continue
        s2 = tl.state_at(h2, e2["t"], tol=TOL)
        if not s2:
            continue
        d = math.hypot(s2["x"] - s["x"], s2["y"] - s["y"])
        if d < NEAR:
            out.append((h2, round(dt, 1), round(d)))
    return out


def audit_timeline(tl, game=""):
    """Re-derive d24's findings and tag each with its wipe companions."""
    deaths = [e for e in tl.events
              if e["type"] == "DEATH" and e.get("target_hero")]
    out = []
    for e in deaths:
        hero = e["target"]
        team = tl.teams.get(hero)
        if team is None:
            continue
        s = tl.state_at(hero, e["t"], tol=TOL)
        if not s:
            continue
        if detect._depth_anc(team, s["x"], s["y"]) <= 3500:
            continue
        near_live = False
        for h2, t2 in tl.teams.items():
            if h2 == hero or t2 != team:
                continue
            s2 = tl.state_at(h2, e["t"], tol=TOL)
            if s2 and s2["hp"] > 0 \
                    and math.hypot(s2["x"] - s["x"], s2["y"] - s["y"]) < NEAR:
                near_live = True
                break
        if near_live:
            continue    # d24 does not fire here
        out.append({
            "game": game, "hero": hero, "team": team, "t": round(e["t"], 1),
            "depth": round(detect._depth_anc(team, s["x"], s["y"])),
            "companions": _companions(tl, hero, team, e["t"], s, deaths),
        })
    return out


def load_manifest(sweep_dir):
    man = {}
    p = os.path.join(sweep_dir, "games_manifest.jsonl")
    if not os.path.exists(p):
        return man
    for line in open(p):
        g = json.loads(line)
        man[g["game"]] = (g.get("seed"), g.get("side"))
    return man


TEAM_OF_SIDE = {"radiant": 2, "dire": 3}


def report(sweep_dirs):
    rows = []
    man = {}
    for d in sweep_dirs:
        man.update(load_manifest(d))
        for f in sorted(glob.glob(os.path.join(d, "timelines", "*.json"))):
            game = os.path.basename(f).replace(".timeline.json", "")
            tl = detect.Timeline(json.load(open(f)))
            rows.extend(audit_timeline(tl, game))
    n = len(rows)
    if not n:
        print("no deep_solo_death findings in %d sweep dir(s)" % len(sweep_dirs))
        return rows
    withc = [r for r in rows if r["companions"]]
    print("deep_solo_death findings: %d" % n)
    print("  an ALLY DIED within %.0fs and %.0fu before the death (wipe tail):"
          " %d (%.1f%%)" % (WINDOW, NEAR, len(withc), 100.0 * len(withc) / n))
    c = collections.Counter(len(r["companions"]) for r in rows)
    for k in sorted(c):
        print("    companions=%d : %4d (%.1f%%)" % (k, c[k], 100.0 * c[k] / n))

    # 铁律 4(i-a): both strata's READINGS, unconditionally.
    tab = collections.defaultdict(lambda: [0, 0])
    unmapped = 0
    for r in rows:
        if r["game"] not in man:
            unmapped += 1
            continue
        _seed, armed = man[r["game"]]
        leg = "ab" if armed == "radiant" else "ba"
        on_cand = (r["team"] == TEAM_OF_SIDE.get(armed))
        e = tab[(leg, on_cand)]
        e[1] += 1
        if r["companions"]:
            e[0] += 1
    if unmapped:
        print("  (%d finding(s) had no manifest row and are excluded from the "
              "strata table)" % unmapped)
    print()
    for leg in ("ab", "ba"):
        for oc in (True, False):
            w, t = tab[(leg, oc)]
            if t:
                print("  leg=%s %-9s : %3d/%3d = %.1f%%"
                      % (leg, "CANDIDATE" if oc else "baseline", w, t,
                         100.0 * w / t))
    for leg in ("ab", "ba"):
        wc, tc = tab[(leg, True)]
        wb, tb = tab[(leg, False)]
        if tc and tb:
            print("  leg=%s contamination delta (cand-base) = %+.1f pp"
                  % (leg, 100.0 * wc / tc - 100.0 * wb / tb))
    print("  4(i-b): if those two deltas disagree in sign that is NOISE -- "
          "register it, do not conclude from it (LIMIT 3).")
    return rows


# ------------------------------------------------------------------ selfcheck
class _FakeTL:
    """Minimal Timeline stand-in: exact snapshots, no interpolation."""

    def __init__(self, teams, events, snaps):
        self.teams = teams
        self.events = sorted(events, key=lambda e: e["t"])
        self.snaps = snaps

    def state_at(self, hero, t, tol=3.0):
        best = None
        for s in self.snaps.get(hero, []):
            if abs(s["t"] - t) <= tol and (best is None
                                           or abs(s["t"] - t) < abs(best["t"] - t)):
                best = s
        return best


# Deep inside team 3's enemy half: _depth_anc(3, x, y) must exceed 3500.
DEEP = (-6057.0, 1445.0)
HOME = (6800.0, 6200.0)


def selfcheck():
    """Mutation stand: every case is built so a specific WRONG
    implementation gives a different answer than the right one."""
    ok, fail = 0, 0

    def chk(name, got, want):
        nonlocal ok, fail
        if got == want:
            ok += 1
        else:
            fail += 1
            print("FAIL %s: got %r want %r" % (name, got, want))

    teams = {"A": 3, "B": 3, "E": 2}

    def snap(h, t, xy, hp):
        return {"hero": h, "t": t, "x": xy[0], "y": xy[1], "hp": hp}

    def death(h, t):
        return {"type": "DEATH", "t": t, "target": h, "target_hero": True,
                "actor": "E", "actor_hero": True}

    # M1 -- the frame case: ally B dies 0.5s earlier 638u away, then A dies.
    # A right implementation reports 1 companion; one that reads `alone` and
    # stops (i.e. d24 itself) reports the finding with NO companion.
    B_XY = (DEEP[0] + 638.0, DEEP[1])
    tl = _FakeTL(teams,
                 [death("B", 100.0), death("A", 100.5)],
                 {"A": [snap("A", 100.0, DEEP, 500), snap("A", 100.5, DEEP, 0)],
                  "B": [snap("B", 100.0, B_XY, 0), snap("B", 100.5, B_XY, 0)],
                  "E": [snap("E", 100.5, DEEP, 900)]})
    rows = audit_timeline(tl, "m1")
    chk("M1 one finding (A, the last man)", [r["hero"] for r in rows], ["A"])
    chk("M1 the wipe companion is found", len(rows[0]["companions"]), 1)

    # M2 -- an ally alive within 2500 means d24 does NOT fire at all.  A
    # mutant that dropped the near_live guard would emit a finding here.
    tl = _FakeTL(teams, [death("A", 100.5)],
                 {"A": [snap("A", 100.5, DEEP, 0)],
                  "B": [snap("B", 100.5, (DEEP[0] + 1000.0, DEEP[1]), 700)]})
    chk("M2 living ally within leash suppresses the finding",
        audit_timeline(tl, "m2"), [])

    # M3 -- a genuine solo death (ally died far away) must report ZERO
    # companions, so the contamination rate cannot be 100% by construction.
    FAR = (DEEP[0] + 9000.0, DEEP[1])
    tl = _FakeTL(teams, [death("B", 100.0), death("A", 100.5)],
                 {"A": [snap("A", 100.5, DEEP, 0)],
                  "B": [snap("B", 100.0, FAR, 0)]})
    rows = audit_timeline(tl, "m3")
    chk("M3 far ally death is not a companion", rows[0]["companions"], [])

    # M4 -- the window is one-sided: an ally dying AFTER does not count
    # (a mutant using abs(dt) would call this a wipe tail).
    tl = _FakeTL(teams, [death("A", 100.0), death("B", 100.5)],
                 {"A": [snap("A", 100.0, DEEP, 0)],
                  "B": [snap("B", 100.5, B_XY, 0)]})
    rows = audit_timeline(tl, "m4")
    chk("M4 a LATER ally death is not a companion", rows[0]["companions"], [])

    # M5 -- an enemy dying next door is not a companion (team filter).
    tl = _FakeTL(teams, [death("E", 100.0), death("A", 100.5)],
                 {"A": [snap("A", 100.5, DEEP, 0)],
                  "E": [snap("E", 100.0, B_XY, 0)]})
    rows = audit_timeline(tl, "m5")
    chk("M5 enemy death is not a companion", rows[0]["companions"], [])

    # M6 -- shallow deaths are out of d24's domain entirely.
    tl = _FakeTL(teams, [death("A", 100.5)],
                 {"A": [snap("A", 100.5, HOME, 0)]})
    chk("M6 own-half death is not a d24 finding", audit_timeline(tl, "m6"), [])

    print("SELFCHECK %d PASS / %d FAIL" % (ok, fail))
    return 0 if fail == 0 else 3


def main():
    args = [a for a in sys.argv[1:]]
    if "--selfcheck" in args:
        return selfcheck()
    if not args:
        print(__doc__)
        return 2
    report(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
