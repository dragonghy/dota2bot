#!/usr/bin/env python3
"""Smoke test for the behavioral "eyes" tooling (plain python, no pytest).

Runs tools/batch_test/behavioral/storyboard.py and report_card.py end-to-end
on tests/fixtures/timeline_synthetic.json (4 heroes, one fight, one death)
and asserts the PNG frames, fights.json, and the markdown/JSON reports get
produced with the expected content.

If matplotlib is not installed, PNG rendering is skipped (the storyboard runs
on the analysis machine which has it) but fight detection and the full report
card are still verified.

Usage:  python3 tests/test_storyboard_smoke.py
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEHAV = os.path.join(ROOT, "tools", "batch_test", "behavioral")
FIXTURE = os.path.join(ROOT, "tests", "fixtures", "timeline_synthetic.json")

CM = "npc_dota_hero_crystal_maiden"
AXE = "npc_dota_hero_axe"

failures = []


def check(cond, msg):
    tag = "ok" if cond else "FAIL"
    print("  [%s] %s" % (tag, msg))
    if not cond:
        failures.append(msg)


def run(cmd):
    print("+ " + " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr, file=sys.stderr)
        raise SystemExit("command failed: %s" % " ".join(cmd))
    return r.stdout


def check_fight(fight):
    check(70.0 <= fight["t_start"] <= 71.0 and 74.0 <= fight["t_end"] <= 76.0,
          "fight window ~70-75s (got %s-%s)" % (fight["t_start"], fight["t_end"]))
    check(sorted(fight["participants"]) ==
          sorted([CM, "npc_dota_hero_zuus", "npc_dota_hero_lion"]),
          "participants are CM + Zeus + Lion (Axe absent)")
    check(len(fight["deaths"]) == 1 and fight["deaths"][0]["hero"] == CM,
          "one death: crystal_maiden")
    check(fight["damage"]["dire"] == 690 and fight["damage"]["radiant"] == 90,
          "damage per side 690 dire / 90 radiant (got %s)" % fight["damage"])


def test_storyboard(out):
    try:
        import matplotlib  # noqa: F401
        have_mpl = True
    except ImportError:
        have_mpl = False

    if have_mpl:
        run([sys.executable, os.path.join(BEHAV, "storyboard.py"), FIXTURE,
             "--out-dir", out])
        idx = os.path.join(out, "fights.json")
        check(os.path.isfile(idx), "fights.json written")
        fights = json.load(open(idx))
        check(len(fights) == 1, "exactly one fight detected (got %d)" % len(fights))
        check_fight(fights[0])
        pngs = sorted(glob.glob(os.path.join(out, "fight_1_frame_*.png")))
        check(4 <= len(pngs) <= 8, "4-8 frames rendered (got %d)" % len(pngs))
        check(all(os.path.getsize(p) > 5000 for p in pngs),
              "every frame PNG is non-trivial (>5KB)")
    else:
        print("  [skip] matplotlib not installed -> skipping PNG render, "
              "verifying fight detection only")
        sys.path.insert(0, BEHAV)
        import detect
        import storyboard
        tl = detect.Timeline(json.load(open(FIXTURE)))
        fights = storyboard.detect_fights(tl)
        check(len(fights) == 1, "exactly one fight detected (got %d)" % len(fights))
        check_fight(fights[0])


def test_report_card(out):
    run([sys.executable, os.path.join(BEHAV, "report_card.py"), FIXTURE,
         "--out-dir", out])
    for fn in ("report_all.json", "SUMMARY.md", "report_axe.md",
               "report_crystal_maiden.md", "report_zuus.md", "report_lion.md"):
        check(os.path.isfile(os.path.join(out, fn)), fn + " written")
    allj = json.load(open(os.path.join(out, "report_all.json")))
    check(len(allj["fights"]) == 1, "report_all.json carries the fight index")
    cm = allj["heroes"][CM]
    axe = allj["heroes"][AXE]
    check(len(cm["deaths"]) == 1 and cm["deaths"][0]["class"] == "solo_overextend",
          "CM's death classified solo_overextend (got %s)" %
          [d["class"] for d in cm["deaths"]])
    check(cm["deaths"][0]["alone"] and cm["deaths"][0]["in_enemy_half"],
          "CM died alone in the enemy half")
    check(cm["fights_present"] == 1 and cm["spectator_fights"] == [],
          "CM present in the fight and not a spectator (she dealt damage)")
    check(axe["fights_present"] == 0 and len(axe["deaths"]) == 0,
          "Axe present in 0 fights with 0 deaths")
    check(cm["positioning"]["pct_time_enemy_half"] > 0.2,
          "CM spent measurable time in the enemy half")
    check(cm["concern_score"] >= 1 and axe["concern_score"] == 0,
          "concern: CM >= 1, Axe == 0")
    summary = open(os.path.join(out, "SUMMARY.md")).read()
    check("CM" in summary and "Axe" in summary, "SUMMARY.md mentions the heroes")
    # CM must rank above Axe (higher concern)
    check(summary.find("| CM |") < summary.find("| Axe |"),
          "CM ranked more concerning than Axe in SUMMARY.md")


def main():
    tmp = tempfile.mkdtemp(prefix="behav_smoke_")
    try:
        print("== storyboard.py ==")
        test_storyboard(os.path.join(tmp, "sb"))
        print("== report_card.py ==")
        test_report_card(os.path.join(tmp, "rc"))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if failures:
        print("\n%d FAILURE(S):" % len(failures))
        for f in failures:
            print("  - " + f)
        raise SystemExit(1)
    print("\nall behavioral tooling smoke checks passed")


if __name__ == "__main__":
    main()
