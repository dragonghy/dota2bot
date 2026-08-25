#!/usr/bin/env python3
"""[GH #108] The cap 10 -> 25 change, pinned where it can silently rot.

WHY THIS EXISTS

    The owner's decision is one literal (`SOAK_CAP_MIN`).  The issue's own
    warning is that changing only the literal is the failure: three other
    constants were calibrated on an ~11-minute game and each of them fails
    QUIETLY at 25 -- not with an error, with a plausible-looking number.

      1. soak_loop.sh's wall-clock backstop (was a pinned 15).  A 25-game-minute
         game needs ~14 wall-minutes at the farm's measured timescale, so the
         old literal killed every game roughly 10 game-minutes early and the
         analysis would have reported "no winner", i.e. a harness fault dressed
         up as a bot fault.
      2. validate_onspot.sh's stall budget (was a pinned 35 minutes).  Too small
         and every healthy wave "stalls"; the caller runs it with `|| true` and
         scores whatever arrived, so the wave under-produces in silence.
      3. analyze_log.py's forcewin-recovery heuristic.  It rewrites a sub-cap
         engine winner to the economic winner, on the reasoning that at cap=10 a
         sub-cap engine ending could only be the referee's premature-forcewin
         artifact.  That reasoning was sound while no turbo game could lose its
         ancient in 10 minutes.  At 25 most games are expected to end naturally,
         and a REAL win by the economic loser -- a comeback, a throw -- has the
         same signature as the artifact.  Un-repaired, the harness would have
         quietly deleted exactly the real wins the cap change was bought to
         produce.

    So the three derived values are asserted to FOLLOW the cap rather than to
    equal today's numbers: each one is recomputed at the old cap as well, and
    required to reproduce the hand-picked literal it replaced.  That agreement
    at 10 is the only evidence the formulas are calibrated rather than invented.

HOW IT TESTS

    By running the real scripts.  The two bash values are read by sourcing the
    real files under a stubbed environment, not by re-implementing their
    arithmetic; analyze_log.py is imported and run on synthetic console logs in
    the engine's real line format.  Nothing here copies a formula and then
    checks its own copy (the shape GH #67 names).
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOAK = os.path.join(ROOT, "tools", "batch_test", "soak")
AWS = os.path.join(ROOT, "tools", "batch_test", "aws")

sys.path.insert(0, SOAK)
import analyze_log  # noqa: E402

FAIL = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        print("  FAIL %s" % msg)
        FAIL.append(msg)


def sh_value(path, var, cap_override=None):
    """Evaluate one variable out of a real script without running the script.

    The prologue of both files is straight-line assignment, so everything up to
    the first line that needs the farm is sourced verbatim.  A re-implementation
    of the arithmetic here would pass while the file said something else.
    """
    with open(path) as fh:
        src = fh.read()
    # stop before anything that touches the machine
    for marker in ("mkdir -p", "sync_s3()", "while true"):
        i = src.find(marker)
        if i > 0:
            src = src[:i]
            break
    env = dict(os.environ)
    env.pop("SOAK_CAP_MIN", None)
    env.pop("GAME_CAP_MIN", None)
    env.pop("STALL_MIN", None)
    if cap_override is not None:
        env["SOAK_CAP_MIN"] = str(cap_override)
    script = "set +u\n" + src + '\necho "VALUE=${%s}"\n' % var
    out = subprocess.run(["bash", "-c", script, "_", "1", "s3://x/y"],
                         cwd=os.path.dirname(path),
                         env=env, capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith("VALUE="):
            return line[6:].strip()
    raise AssertionError("could not read %s out of %s\n%s\n%s"
                         % (var, path, out.stdout[-800:], out.stderr[-800:]))


def game_log(duration_s, winning_team, fort=None, gpm=(500, 500)):
    """A console log with just the lines parse_log.py reads."""
    lines = ["07/19 04:22:27 [Server] entering state 'DOTA_GAMERULES_STATE_GAME_IN_PROGRESS'"]
    if fort:
        lines.append("07/19 04:30:00 [Server] Building: npc_dota_%s_fort destroyed at %.6f."
                     % (fort, duration_s))
    lines.append("07/19 04:31:00 [Server] Match signout:  duration = %d (%d.5) Winning team = %d"
                 % (duration_s, duration_s, winning_team))
    for team in (0, 1):
        for slot in range(5):
            lines.append("07/19 04:31:00 [Server] Team %d Player %d m_unAccountID = 0" % (team, slot))
            lines.append("07/19 04:31:00 [Server] Level: 12 Gold: 500  KDA: 5 / 5 / 5")
            lines.append("07/19 04:31:00 [Server] LastHit = 40  Deny = 0")
            lines.append("07/19 04:31:00 [Server] XP per min: 500  Gold per min: %d" % gpm[team])
    fh = tempfile.NamedTemporaryFile("w", suffix=".log", delete=False)
    fh.write("\n".join(lines) + "\n")
    fh.close()
    return fh.name


def run_analyze(path, cap):
    os.environ["SOAK_CAP_MIN"] = str(cap)
    try:
        return analyze_log.analyze(path)
    finally:
        os.environ.pop("SOAK_CAP_MIN", None)


print("1. the cap itself is the owner's value, and is the single source of truth")
loop = os.path.join(SOAK, "soak_loop.sh")
cap = sh_value(loop, "SOAK_CAP_MIN")
check(cap == "25", "soak_loop.sh caps games at 25 game-minutes (owner decision, GH #108), got %r" % cap)
check(sh_value(loop, "SOAK_CAP_MIN", cap_override=10) == "10",
      "the environment still overrides the cap (a single loop can be driven by hand)")

print("2. the wall-clock backstop follows the cap and outlasts a full-length game")
# measured farm timescale, control slots, batch-desk 2026-08-22/23 fits
TIMESCALE_SLOWEST = 1.79
for c in (10, 25):
    backstop = int(sh_value(loop, "GAME_CAP_MIN", cap_override=c))
    need = c / TIMESCALE_SLOWEST
    # 1.5x, not "greater than": the backstop also has to cover map load, the
    # per-slot launch desync and a slot running slower than the fitted trend.
    # A backstop that merely beats the mean game is a coin flip on the tail,
    # and the tail is where a killed game costs a wave its evidence.
    check(backstop >= need * 1.5,
          "at cap=%d the backstop (%d min) clears one full game (~%.1f min) with load slack"
          % (c, backstop, need))
check(int(sh_value(loop, "GAME_CAP_MIN", cap_override=10)) in (15, 16),
      "at the OLD cap the formula reproduces the hand-picked 15 it replaced "
      "(this agreement is the calibration evidence, not the 25-minute value)")
check(sh_value(loop, "GAME_CAP_MIN", cap_override=25) != "15",
      "the backstop is no longer the literal that would have killed every game early")

print("3. the stall budget follows the cap too")
val = os.path.join(SOAK, "validate_onspot.sh")


def stall_at(c):
    with open(val) as fh:
        src = fh.read()
    src = src[:src.find("sync_s3()")]
    env = dict(os.environ)
    env.pop("STALL_MIN", None)
    if c is None:
        env.pop("SOAK_CAP_MIN", None)
    else:
        env["SOAK_CAP_MIN"] = str(c)
    script = "set +u\n" + src + '\necho "VALUE=${STALL_MIN}:${CAP_MIN}"\n'
    out = subprocess.run(["bash", "-c", script, "_", "cand", "851", "12", "bkt", "run"],
                         cwd=SOAK, env=env, capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith("VALUE="):
            return [int(x) for x in line[6:].strip().split(":")]
    raise AssertionError("no STALL_MIN out of validate_onspot.sh\n%s\n%s"
                         % (out.stdout[-800:], out.stderr[-800:]))


stall10, cap10 = stall_at(10)
stall25, cap25 = stall_at(25)
stall_default, cap_default = stall_at(None)
check(stall10 == 35, "at the OLD cap the budget reproduces the hand-picked 35 min, got %d" % stall10)
# A half-wave costs the drain of the game each slot is already in, plus
# ceil(TARGET/slots) fresh ones -- two games at the standing 12-games/14-slots
# topology -- plus the S3 sync lag. Three games' wall time is the floor, and it
# is the RATIO the old 35 encoded (3.5 games at cap=10) that has to survive the
# cap change, not the literal: a budget that merely beats the mean half-wave
# turns every slow wave into a silent under-produce.
for c, s in ((10, stall10), (25, stall25)):
    check(s >= 3 * (c / TIMESCALE_SLOWEST),
          "at cap=%d the stall budget (%d min) covers a drain plus a full round with margin"
          % (c, s))
check(cap_default == 25 and stall_default == stall25,
      "with no environment at all it reads the cap out of soak_loop.sh (no second copy of 25), "
      "got cap=%d stall=%d" % (cap_default, stall_default))

print("4. an ancient that fell is a scoreboard: no economic reasoning may overwrite it")
# radiant far ahead on gold, but DIRE took the fort at 12 minutes -- a real
# comeback win, and bit for bit the shape of the referee artifact.
log = game_log(720, winning_team=1, fort="goodguys", gpm=(900, 300))
a = run_analyze(log, 25)
check(a["winner"] == "dire", "the engine winner survives, got %r" % a["winner"])
check(a["winner_by"] == "engine_natural", "and is labelled engine_natural, got %r" % a["winner_by"])
check(a["natural_end"] is True, "natural_end is reported as a field (GH #108 acceptance 1)")
check(a["econ_winner"] == "radiant", "while econ_winner still records the gold leader")
os.unlink(log)

print("5. the sub-cap artifact with NO ancient down is still repaired")
log = game_log(720, winning_team=1, fort=None, gpm=(900, 300))
a = run_analyze(log, 25)
check(a["winner"] == "radiant", "the economic winner replaces the artifact, got %r" % a["winner"])
check(a["winner_by"] == "economy_forcewin_recovery", "labelled as the repair, got %r" % a["winner_by"])
check(a["natural_end"] is False, "and natural_end says why the repair was allowed")
os.unlink(log)

print("6. a game that reaches the cap is still decided by economy")
log = game_log(1500, winning_team=1, fort=None, gpm=(900, 300))
a = run_analyze(log, 25)
check(a["winner_by"] == "economy_25min_cap", "labelled with the live cap, got %r" % a["winner_by"])
check(a["cap_min"] == 25.0, "the cap the game was scored under is archived with it")
os.unlink(log)

print("7. the duration anomalies mean the same thing at the new cap")
log = game_log(540, winning_team=1, fort="goodguys", gpm=(500, 500))
kinds = [x["type"] for x in run_analyze(log, 25)["anomalies"]]
check("insta_end" not in kinds, "a 9-minute win WITH an ancient down is not an anomaly, got %r" % kinds)
os.unlink(log)
log = game_log(540, winning_team=1, fort=None, gpm=(500, 500))
kinds = [x["type"] for x in run_analyze(log, 25)["anomalies"]]
check("insta_end" in kinds, "a 9-minute ending with NO ancient down still is, got %r" % kinds)
os.unlink(log)
log = game_log(2500, winning_team=1, fort=None, gpm=(500, 500))
kinds = [x["type"] for x in run_analyze(log, 25)["anomalies"]]
check("slow_close" in kinds, "past cap+15 the referee is dead and it is flagged, got %r" % kinds)
os.unlink(log)
log = game_log(2200, winning_team=1, fort=None, gpm=(500, 500))
kinds = [x["type"] for x in run_analyze(log, 25)["anomalies"]]
check("slow_close" not in kinds,
      "36 min at cap=25 is inside the referee's slack and is NOT flagged, got %r" % kinds)
os.unlink(log)

print("8. a wave that cannot fit its watchdog is refused before any money is spent")
spot = os.path.join(AWS, "spot_run.sh")


def launch(args):
    return subprocess.run(["bash", spot] + args, cwd=AWS, capture_output=True, text=True)


four_seeds = "--validate"
r = launch([four_seeds, "pulllane 851 852 853 854 --games 12", "--hours", "3", "--dry-run"])
check(r.returncode != 0, "4 seeds on the default 3h watchdog is refused (the 852 accident)")
check("--hours" in r.stderr, "and the refusal names the --hours it needs:\n      %s"
      % r.stderr.strip().replace("\n", "\n      "))
r2 = launch([four_seeds, "pulllane 851 852 853 854 --games 12", "--hours", "3",
             "--allow-short-watchdog", "--dry-run"])
check(r2.returncode == 0, "and a human can still overrule it with --allow-short-watchdog")
r3 = launch([four_seeds, "pulllane 851 --games 12", "--hours", "2", "--dry-run"])
check(r3.returncode == 0, "one seed in 2h still fits at the new cap and launches")

print()
if FAIL:
    print("%d FAILED" % len(FAIL))
    sys.exit(1)
print("all checks passed")
