#!/usr/bin/env python3
"""corpus_query.py must report a denominator that balances, and fail loud otherwise.

WHY THIS EXISTS
    The tool's whole value is the denominator.  A frame-selector that reports
    "matched 14" is worth nothing; one that reports "matched 14 of 302
    examined, with 180 post-game rows, 21 paused rows and 2 dead rows each
    named" is a population claim somebody can promote a fix on.  Every failure
    mode of such a tool is SILENT and FLATTERING -- rows dropped upstream
    shrink the denominator, a typo'd clause selects nothing, a short-circuited
    clause gets scored against a denominator it was never offered.  None of
    those show up as a crash.  So each is pinned here by number.

HOW IT TESTS
    It drives the REAL script (subprocess, real stdout) on REAL corpora it
    writes to a temp dir, and for the fixture case it lets the script invoke
    the REAL make_fixture.py.  It does not import the predicate compiler and
    unit-test it in isolation: this repo has a named failure class for tools
    validated only through a reimplementation nobody ships (GH #67).

    check_parsed() is the anti-vacuity guard and is written BEFORE the
    assertions it protects: every numeric assertion below could pass on a
    corpus the script silently skipped, so nothing is asserted until the
    CORPUS/POPULATION lines have actually been found and parsed.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "batch_test", "replayscope", "corpus_query.py")

failures = []


def check(cond, msg):
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


# --------------------------------------------------------------------------
# corpus construction
# --------------------------------------------------------------------------

def snap(t, hero, team, x, y, hp=1000, hp_pct=1.0, level=6, **kw):
    s = {"t": float(t), "hero": hero, "team": team, "x": float(x), "y": float(y),
         "hp": hp, "hp_pct": hp_pct, "mp": 300, "mp_pct": 0.5, "level": level,
         "net_worth": 2000, "tp_cd": 0.0, "items": [], "abilities": []}
    s.update(kw)
    return s


def ev(t, actor="npc_dota_hero_axe", target="npc_dota_hero_lion", typ="DAMAGE", value=50):
    return {"t": float(t), "type": typ, "actor": actor, "target": target,
            "inflictor": "", "value": value, "actor_hero": True, "target_hero": True}


AXE, LION = "npc_dota_hero_axe", "npc_dota_hero_lion"


def build_corpus():
    """One game with every exclusion bucket populated by construction.

    Layout (both heroes sampled at 1Hz, t = 0..45):
      events at t = 1, 10, 30, 40  ->  t_end = 40, so t = 41..45 is POST-GAME
      t in [10, 30]  positions frozen with a >=3s event gap  ->  PAUSED
      axe hp = 0 at t = 5, 6                                  ->  DEAD
      the 1->10 gap is 9s but both heroes MOVE through it, so it must NOT be
      read as a pause -- that is the discriminating case for the pause rule.
    """
    snaps, evs = [], [ev(1), ev(10), ev(30), ev(40)]
    for t in range(0, 46):
        if 10 < t < 30:
            ax, ay, lx, ly = 100.0, 100.0, 900.0, 900.0        # frozen span
        else:
            ax, ay = 100.0 + t, 100.0 + t
            lx, ly = 900.0 + t, 900.0 + t
        axe_hp, axe_pct = (0, 0.0) if t in (5, 6) else (1000, 1.0)
        snaps.append(snap(t, AXE, 2, ax, ay, hp=axe_hp, hp_pct=axe_pct))
        snaps.append(snap(t, LION, 3, lx, ly, hp=800, hp_pct=0.4))
    return {"game": {"start_time": 0.0, "teams": {AXE: 2, LION: 3}},
            "snapshots": snaps, "events": evs}


def write_corpus(dirpath, name, doc):
    p = os.path.join(dirpath, name)
    with open(p, "w") as fh:
        json.dump(doc, fh)
    return p


def run(paths, query, extra=(), expect_ok=True):
    cmd = [sys.executable, SCRIPT] + list(paths) + ["--query", json.dumps(query)] + list(extra)
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if expect_ok and proc.returncode != 0:
        print("FAIL script exited %d\n%s" % (proc.returncode, proc.stderr))
        failures.append("script crashed: %s" % (proc.stderr.strip().splitlines()[-1:] or [""]))
        return proc, {}
    return proc, parse(proc.stdout)


def parse(out):
    d = {"clauses": [], "heroes": {}, "raw": out}
    for line in out.splitlines():
        if line.startswith(("CORPUS ", "POPULATION ", "FIXTURES ")):
            for k, v in re.findall(r"(\w+)=([^\s]+)", line):
                d[k] = v
        elif line.startswith("CLAUSE "):
            m = re.match(r"CLAUSE true=(\d+)/(\d+) reached  (.*)$", line)
            if m:
                d["clauses"].append((int(m.group(1)), int(m.group(2)), m.group(3)))
        elif line.startswith("HERO "):
            _, hero, n = line.split()
            d["heroes"][hero] = int(n)
        elif line.startswith("CAP "):
            d["cap_line"] = line
    return d


def check_parsed(d, label):
    """Anti-vacuity guard -- run before any numeric assertion on `d`.

    Everything below asserts on numbers pulled out of stdout.  If the script
    printed nothing parseable (crash, changed line format, a corpus it skipped
    whole), every `d.get(...)` would be None and a comparison against it would
    quietly not fire.  This makes that case a named failure instead.
    """
    ok = all(k in d for k in ("frames_total", "examined", "matched", "deduped"))
    check(ok, "%s: CORPUS+POPULATION lines present and parseable" % label)
    if ok:
        check(int(d["frames_total"]) > 0, "%s: frames_total is non-zero" % label)
    return ok


ALIVE = {"term": "hp", "gt": 0}
TMP = tempfile.mkdtemp(prefix="corpusq_")
try:
    doc = build_corpus()
    C = write_corpus(TMP, "20260823_120000_slot1.timeline.json", doc)

    # ---- 1. the accounting equation, bucket by bucket ---------------------
    proc, d = run([C], ALIVE)
    if check_parsed(d, "case1"):
        total = int(d["frames_total"])
        buckets = [int(d[k]) for k in ("postgame", "out_of_window", "paused", "dead", "examined")]
        check(total == len(doc["snapshots"]),
              "case1: frames_total (%d) equals the corpus's own snapshot count (%d)"
              % (total, len(doc["snapshots"])))
        check(sum(buckets) == total,
              "case1: postgame+out_of_window+paused+dead+examined == frames_total (%d == %d)"
              % (sum(buckets), total))
        # 5 post-game rows (t=41..45) x 2 heroes: the GH #43 frozen tail, which
        # detect.Timeline drops before corpus_query sees it.
        check(int(d["postgame"]) == 10,
              "case1: postgame == 10 (t=41..45 for both heroes), got %s" % d["postgame"])
        # t in [10,30] inclusive = 21 rows x 2 heroes.  The 9s event gap at
        # t=1..10 must NOT be counted: the heroes moved through it.
        check(int(d["paused"]) == 42,
              "case1: paused == 42 (t=10..30 both heroes), got %s" % d["paused"])
        check(int(d["dead"]) == 2, "case1: dead == 2 (axe at t=5,6), got %s" % d["dead"])
        # 46 rows per hero, minus 5 post-game, minus 21 paused = 20 each;
        # axe loses its 2 dead rows on top.
        check(int(d["examined"]) == 20 + (20 - 2),
              "case1: examined == 38, got %s" % d["examined"])

    # ---- 2. short-circuit denominators are per-leaf, not global -----------
    # Clause 2 may only be scored against the frames clause 1 let through.
    # Scoring it against `examined` would understate every later clause --
    # invisible in a hit count, and the exact shape this tool exists to stop.
    proc, d = run([C], {"all": [{"term": "team", "eq": 3}, {"term": "hp_pct", "lt": 0.5}]})
    if check_parsed(d, "case2"):
        check(len(d["clauses"]) == 2, "case2: two clause lines")
        if len(d["clauses"]) == 2:
            (t1, r1, _), (t2, r2, _) = d["clauses"]
            check(r1 == int(d["examined"]),
                  "case2: first clause reached == examined (%d)" % r1)
            check(r2 == t1,
                  "case2: second clause's denominator is the first's true-count "
                  "(%d), not examined (%s)" % (t1, d["examined"]))
            check(t2 == r2 and t2 > 0,
                  "case2: lion is under 50%% HP on all %d frames that reached clause 2" % r2)

    # ---- 3. the two vacuous shapes are named, not just counted -----------
    proc, d = run([C], {"all": [ALIVE, {"term": "has_item", "args": ["item_no_such_item"]}]})
    if check_parsed(d, "case3"):
        check("VACUOUS(selects nothing)" in d["raw"],
              "case3: a clause true on 0 frames is labelled VACUOUS")
        check(int(d["matched"]) == 0, "case3: and the population is empty")
        check("INERT(narrows nothing)" in d["raw"],
              "case3: the alive clause, true on every examined frame, is labelled INERT")

    # ---- 4. dedup collapses the 1Hz run, and says by how much ------------
    proc, d = run([C], {"term": "team", "eq": 3}, extra=["--dedup", "0"])
    raw_hits = int(d.get("matched", -1))
    check_parsed(d, "case4a")
    proc, d = run([C], {"term": "team", "eq": 3}, extra=["--dedup", "1000"])
    if check_parsed(d, "case4b"):
        check(raw_hits > 10, "case4: undeduped run is a long 1Hz stretch (%d frames)" % raw_hits)
        check(int(d["matched"]) == raw_hits,
              "case4: dedup does not change `matched` -- it is reported separately")
        check(int(d["deduped"]) == 1,
              "case4: one hero, one huge window -> exactly 1 kept hit, got %s" % d["deduped"])

    # ---- 5. subject filters ---------------------------------------------
    proc, d = run([C], ALIVE, extra=["--hero", "lion"])
    if check_parsed(d, "case5"):
        check(set(d["heroes"]) == {"lion"}, "case5: --hero restricts the subject set")
        check(int(d["examined"]) == 20, "case5: and the denominator shrinks with it (20)")
    proc, d = run([C], ALIVE, extra=["--team", "2"])
    if check_parsed(d, "case5b"):
        check(set(d["heroes"]) == {"axe"}, "case5b: --team restricts the subject set")

    # ---- 6. fail loud: every malformed predicate is an error, never a 0 ---
    bad = [
        ({"term": "no_such_term", "gt": 1}, "unknown term"),
        ({"term": "hp_pct", "wat": 1}, "unknown operator"),
        ({"term": "enemies_within", "ge": 1}, "wrong arity (missing args)"),
        ({"term": "hp_pct", "args": [1], "gt": 1}, "wrong arity (extra args)"),
        ({"all": []}, "empty all"),
        ({"all": [ALIVE], "any": [ALIVE]}, "combinator with a stray sibling key"),
        ({"nope": 1}, "leaf with no term"),
    ]
    for spec, why in bad:
        proc, _ = run([C], spec, expect_ok=False)
        check(proc.returncode != 0 and "query error" in (proc.stderr + proc.stdout),
              "case6: %s exits non-zero with a query error" % why)

    # A corpus that is not all there must not yield a population at all: a
    # missing game silently shrinks the denominator every reader will quote.
    proc, _ = run([C, os.path.join(TMP, "absent.json")], ALIVE, expect_ok=False)
    check(proc.returncode != 0 and "missing timeline" in (proc.stderr + proc.stdout),
          "case6: a missing timeline file refuses to report, rather than reporting a short denominator")

    # ---- 7. multi-game corpus: population spans games ---------------------
    C2 = write_corpus(TMP, "20260823_130000_slot2.timeline.json", build_corpus())
    proc, d = run([C, C2], ALIVE, extra=["--dedup", "1000"])
    if check_parsed(d, "case7"):
        check(int(d["frames_total"]) == 2 * len(doc["snapshots"]),
              "case7: two games -> the denominator is the sum of both")
        check(d.get("games_with_hits") == "2/2", "case7: both games contribute hits")
        check(int(d["deduped"]) == 4,
              "case7: 2 heroes x 2 games under one huge dedup window, got %s" % d["deduped"])

    # ---- 8. batch fixtures: real make_fixture.py, and a cap that speaks ---
    fx = os.path.join(TMP, "fx")
    proc, d = run([C], ALIVE, extra=["--dedup", "1000", "--fixtures", fx, "--tag", "probe"])
    if check_parsed(d, "case8"):
        made = sorted(os.listdir(fx)) if os.path.isdir(fx) else []
        check(int(d.get("made", -1)) == 2 and len(made) == 2,
              "case8: one fixture per kept hit, generated by the real make_fixture.py (got %r)" % made)
        check(int(d.get("failed", -1)) == 0, "case8: none failed")
        if made:
            body = open(os.path.join(fx, made[0])).read()
            check("GENERATED by tools/batch_test/replayscope/make_fixture.py" in body,
                  "case8: the file is a real fixture, not a stub written by this tool")
            check("units = {" in body and "npc_dota_hero_" in body,
                  "case8: and it carries the frozen world")
        check("NONE(draft-slot fallback, GH #57)" in d["raw"],
              "case8: a fixture built without --analysis-dir says so (roles fallback is 47.3%% accurate)")

    fx2 = os.path.join(TMP, "fx2")
    proc, d = run([C], ALIVE,
                  extra=["--dedup", "1000", "--fixtures", fx2, "--tag", "probe", "--max-fixtures", "1"])
    if check_parsed(d, "case9"):
        check("cap_line" in d and "dropped=1" in d.get("cap_line", ""),
              "case9: --max-fixtures prints what it dropped (no silent caps)")
        check(int(d.get("made", -1)) == 1, "case9: and generated exactly the cap")

    # ---- 10. --list-terms is the documented vocabulary --------------------
    proc = subprocess.run([sys.executable, SCRIPT, "--list-terms"], capture_output=True, text=True)
    check(proc.returncode == 0 and "enemies_within" in proc.stdout and "depth" in proc.stdout,
          "case10: --list-terms prints the vocabulary and exits clean")
finally:
    shutil.rmtree(TMP, ignore_errors=True)

print("\n%d checks failed" % len(failures))
sys.exit(1 if failures else 0)
