#!/usr/bin/env python3
"""Ratchet for [harness] #258 -- one unparseable .dem must cost its own game
and nothing else.

The failure this pins (W17-R, 2026-08-27): `sweep_run.sh` ran `"$BIN" "$demf"`
unguarded under `set -euo pipefail`. The dumper panicked on game 6 of 12
(`unexpected EOF`, stdout 0 bytes, a .dem whose size and `analysis.json` look
completely normal), the script exited on the spot, and `sweep_summary.md` /
`games_manifest.jsonl` / `sweep_complete.json` were never written. Every #102
consumer then correctly refused the whole directory -- so 1 bad file removed
**6 of 25 stamped games (24%)** of that wave's corpus, on a preemption wave
that was already all single-leg orphans.

The #102 sentinel was doing its job. The bug was one level up: the sweep
promoted "this GAME is unparseable" (a property of one file) into "this RUN
never ran" (a property of the sweep). So the fix degrades per game -- and the
two things it must not do while degrading are exactly what this file asserts:

  1. It must not make the bad game DISAPPEAR. `unparseable K` is printed even
     when K == 0, so absence never reads as zero (the #253/#257 family), and
     the names ride along in the sentinel for consumers to judge.
  2. It must not hand out a complete-looking sentinel over an EMPTY corpus.
     If every stamped game is unparseable there is nothing to sweep, and the
     run fails loudly instead of relocating the original bug.

Coverage, stated up front:
  * BEHAVIOURAL. The real `sweep_run.sh` is copied verbatim (byte-identity is
    asserted) into a temp dir and actually run, with its neighbours stubbed:
    a fake `awsx` on PATH serving a fake S3 prefix, a fake `get_dumper.sh`
    handing back a fake dumper that panics on one named .dem, and a fake
    `detect.py`. No AWS call, no network, no billable resource, no real dumper
    build.
  * The load-bearing assertion is NOT "the sweep exited 0" -- the pre-fix
    script also exits 0 when no .dem happens to be bad. It is that the good
    games are in the manifest AND the bad game is named in the summary.
  * The strictest real consumer (`null_leg_occupancy.load_manifest`) is
    imported and pointed at the produced directory, because the summary's
    `games swept: N (` prefix is parsed by hand out there and this change
    edits that very line.

Run:  python3 tests/test_sweep_unparseable_dem.py
      (or via tools/agent/run_py_tests.sh)
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SWEEP_RUN = os.path.join(REPO, "tools/batch_test/behavioral/sweep_run.sh")
BEHAV = os.path.join(REPO, "tools/batch_test/behavioral")

checks = 0
failures = []


def check(cond, label, detail=""):
    global checks
    checks += 1
    if cond:
        print("  ok   %s" % label)
    else:
        print("  FAIL %s%s" % (label, (" -- " + detail) if detail else ""))
        failures.append(label)


# --------------------------------------------------------------- the sandbox

TIMELINE = {
    "game": {"teams": {"npc_dota_hero_axe": 2, "npc_dota_hero_lion": 3}},
    "frames": [],
}

FAKE_AWSX = r"""#!/usr/bin/env bash
# Fake `awsx` standing in for S3. Serves $FAKE_S3 as a flat directory.
# Anything that is not the two calls sweep_run.sh makes is a hard error, so a
# future edit that starts calling AWS for something else cannot pass silently.
set -euo pipefail
if [ "${1:-}" = "s3" ] && [ "${2:-}" = "ls" ]; then
    for f in "$FAKE_S3"/*; do
        [ -e "$f" ] || continue
        echo "2026-08-27 00:00:00 100 $(basename "$f")"
    done
    exit 0
fi
if [ "${1:-}" = "s3" ] && [ "${2:-}" = "cp" ]; then
    src="$3"; dst="$4"
    name="${src##*/}"
    [ -f "$FAKE_S3/$name" ] || exit 1
    cp "$FAKE_S3/$name" "$dst"
    exit 0
fi
echo "fake awsx: unexpected call: $*" >&2
exit 99
"""

FAKE_GET_DUMPER = r"""#!/usr/bin/env bash
set -euo pipefail
echo "[get_dumper] fake" >&2
echo "$FAKE_DUMPER"
"""

# Panics exactly like the real thing did on 20260827_151652_slot11: non-zero
# exit, zero bytes on stdout, and the .dem itself looks perfectly ordinary.
#
# EMPTYGAME is the quieter sibling and the reason the guard checks the FILE and
# not only the exit code: a parser that gives up and returns success with
# nothing on stdout leaves a 0-byte timeline that the next stage reads as "a
# game in which nothing happened" -- a silent zero, not an error.
FAKE_DUMPER = r"""#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    *BADGAME*)
        echo "panic: unexpected EOF" >&2
        exit 2
        ;;
    *EMPTYGAME*)
        exit 0
        ;;
esac
cat "$FAKE_TIMELINE"
"""

FAKE_DETECT = r"""#!/usr/bin/env python3
import json, sys
out = sys.argv[sys.argv.index("--json") + 1]
json.dump([], open(out, "w"))
"""


def build_sandbox(tmp, games):
    """games: list of (basename, stamped?) -- basename containing BADGAME panics."""
    s3 = os.path.join(tmp, "s3")
    bindir = os.path.join(tmp, "bin")
    scriptdir = os.path.join(tmp, "behavioral")
    for d in (s3, bindir, scriptdir):
        os.makedirs(d, exist_ok=True)

    for name, stamped in games:
        with open(os.path.join(s3, name + ".dem"), "w") as fh:
            fh.write("x" * 64)          # normal-looking, like the real bad one
        sv = "mirror:cand:s851:radiant" if stamped else "warmup"
        json.dump({"script_version": sv, "natural_end": True},
                  open(os.path.join(s3, name + ".analysis.json"), "w"))

    tlpath = os.path.join(tmp, "timeline.json")
    json.dump(TIMELINE, open(tlpath, "w"))

    def write(path, body, mode=0o755):
        with open(path, "w") as fh:
            fh.write(body)
        os.chmod(path, mode)

    write(os.path.join(bindir, "awsx"), FAKE_AWSX)
    write(os.path.join(bindir, "behav-dump-fake"), FAKE_DUMPER)
    write(os.path.join(scriptdir, "get_dumper.sh"), FAKE_GET_DUMPER)
    write(os.path.join(scriptdir, "detect.py"), FAKE_DETECT)

    # The script under test, copied verbatim. sweep_run.sh resolves its
    # neighbours from its own location, so copying it (and nothing else) is
    # what puts the stubs in front of it.
    sut = os.path.join(scriptdir, "sweep_run.sh")
    shutil.copyfile(SWEEP_RUN, sut)
    check(open(sut, "rb").read() == open(SWEEP_RUN, "rb").read(),
          "the script under test is byte-identical to the shipped sweep_run.sh")

    env = dict(os.environ)
    env["PATH"] = bindir + os.pathsep + env["PATH"]
    env["FAKE_S3"] = s3
    env["FAKE_DUMPER"] = os.path.join(bindir, "behav-dump-fake")
    env["FAKE_TIMELINE"] = tlpath
    return sut, env


def run_sweep(tmp, games):
    sut, env = build_sandbox(tmp, games)
    out = os.path.join(tmp, "out")
    proc = subprocess.run(["bash", sut, "s3://fake/soak/run_test/", out],
                          env=env, capture_output=True, text=True, timeout=300)
    return proc, out


def read_summary(out):
    p = os.path.join(out, "sweep_summary.md")
    return open(p).read() if os.path.exists(p) else None


def read_manifest(out):
    """Missing manifest -> [], never a traceback.

    A regression here means the sweep died, and a died-sweep must surface as
    the named check that failed, not as a stack trace three lines earlier that
    hides which invariant broke.
    """
    p = os.path.join(out, "games_manifest.jsonl")
    if not os.path.exists(p):
        return []
    return [json.loads(l) for l in open(p) if l.strip()]


# ------------------------------------------- 1. one bad .dem costs one game

print("\n[1] a mid-run unparseable .dem does not take the run with it")
with tempfile.TemporaryDirectory() as tmp:
    games = [("g1", True), ("g2", True), ("BADGAME_slot11", True),
             ("g4", True), ("warm5", False)]
    proc, out = run_sweep(tmp, games)

    check(proc.returncode == 0, "sweep exits 0 despite the panic",
          "rc=%d stderr tail=%s" % (proc.returncode, proc.stderr[-400:]))

    summary = read_summary(out)
    check(summary is not None,
          "sweep_summary.md exists (pre-fix: never written, whole dir refused)")
    sentinel = os.path.join(out, "sweep_complete.json")
    check(os.path.exists(sentinel), "sweep_complete.json exists")

    manifest = read_manifest(out)
    names = sorted(g["game"] for g in manifest)
    # THE load-bearing pair: the three good stamped games survive the bad one,
    # and the bad one is not quietly among them.
    check(names == ["g1", "g2", "g4"],
          "the 3 good stamped games are in the manifest, the bad one is not",
          "got %s" % names)

    check(summary and "unparseable 1" in summary,
          "summary counts the unparseable game", summary)
    check(summary and "BADGAME_slot11" in summary,
          "summary NAMES the unparseable game (counted, not vanished)")
    check(summary and summary.startswith("# Sweep summary")
          and "games swept: 3 (" in summary,
          "`games swept: N (` shape kept -- N still means manifest lines")

    sent = json.load(open(sentinel)) if os.path.exists(sentinel) else {}
    check(sent.get("unparseable") == 1, "sentinel carries unparseable=1")
    check(sent.get("unparseable_games") == ["BADGAME_slot11"],
          "sentinel names the unparseable game so consumers can judge",
          str(sent.get("unparseable_games")))
    check(sent.get("swept") == 3 and sent.get("skipped") == 1,
          "sentinel swept/skipped unchanged in meaning",
          json.dumps(sent))

    # A 0-byte timeline left on disk is a landmine: it is a file the next tool
    # will happily open and read as "a game with no frames".
    tl = os.path.join(out, "timelines", "BADGAME_slot11.timeline.json")
    check(not os.path.exists(tl),
          "the 0-byte timeline of the bad game is deleted, not left behind")
    errf = os.path.join(out, "unparseable", "BADGAME_slot11.dumper.err")
    check(os.path.exists(errf), "the dumper's stderr is kept for diagnosis")
    check(os.path.exists(errf) and "panic: unexpected EOF" in open(errf).read(),
          "and it holds the actual panic text")

    # The strictest shipped consumer must accept the directory this produced.
    sys.path.insert(0, BEHAV)
    import null_leg_occupancy as nlo
    try:
        rows = nlo.load_manifest(out)
        check(len(rows) == 3,
              "null_leg_occupancy.load_manifest accepts the dir and reads 3 games",
              "got %d" % len(rows))
    except BaseException as e:
        # Includes a plain crash: this consumer parses the `games swept:` line
        # by hand, so a reshaped summary line fails here as loudly as a refusal.
        check(False, "null_leg_occupancy.load_manifest accepts the dir",
              "refused/crashed: %r" % (e,))


# ----------------------- 1b. success + empty stdout counts as unparseable too

print("\n[1b] a dumper that 'succeeds' with 0 bytes is unparseable, not empty")
with tempfile.TemporaryDirectory() as tmp:
    proc, out = run_sweep(tmp, [("g1", True), ("EMPTYGAME_s7", True)])
    summary = read_summary(out)
    manifest = read_manifest(out)
    check(proc.returncode == 0, "sweep exits 0")
    check([g["game"] for g in manifest] == ["g1"],
          "the 0-byte game does NOT enter the manifest as a frameless game",
          str([g["game"] for g in manifest]))
    check(summary and "unparseable 1" in summary and "EMPTYGAME_s7" in summary,
          "it is counted and named as unparseable", summary)
    check(not os.path.exists(os.path.join(out, "timelines",
                                          "EMPTYGAME_s7.timeline.json")),
          "and its 0-byte timeline is not left on disk")


# ------------------------------------- 2. K is printed even when it is zero

print("\n[2] a clean sweep still says `unparseable 0` (absence != zero)")
with tempfile.TemporaryDirectory() as tmp:
    proc, out = run_sweep(tmp, [("g1", True), ("g2", True)])
    summary = read_summary(out)
    check(proc.returncode == 0, "clean sweep exits 0")
    check(summary and "unparseable 0" in summary,
          "`unparseable 0` printed on a clean run -- so a summary WITHOUT the "
          "word means 'swept by a version that did not count', not 'none'",
          summary)
    sp = os.path.join(out, "sweep_complete.json")
    sent = json.load(open(sp)) if os.path.exists(sp) else {}
    check(sent.get("unparseable") == 0 and sent.get("unparseable_games") == [],
          "sentinel says zero explicitly too")


# --------------------------------- 3. all-unparseable must NOT look complete

print("\n[3] every game unparseable => loud failure, no complete-looking dir")
with tempfile.TemporaryDirectory() as tmp:
    proc, out = run_sweep(tmp, [("BADGAME_a", True), ("BADGAME_b", True)])
    check(proc.returncode != 0,
          "sweep fails when there is nothing left to sweep",
          "rc=%d" % proc.returncode)
    check(not os.path.exists(os.path.join(out, "sweep_complete.json")),
          "NO sentinel is written over an empty corpus (else the fix would "
          "just relocate #258 into a silent zero)")
    check(read_summary(out) is None, "and no summary either")
    check("FATAL" in proc.stderr and "empty corpus" in proc.stderr,
          "the reason is stated on stderr", proc.stderr[-300:])


# ------------------------------------------------- 4. no accidental spending

print("\n[4] the degrade path stays off the network")
with tempfile.TemporaryDirectory() as tmp:
    games = [("g1", True), ("BADGAME_x", True)]
    sut, env = build_sandbox(tmp, games)
    # Any AWS call other than the two the fake serves exits 99; assert the run
    # never hit that, i.e. the retry-free degrade did not start re-fetching.
    out = os.path.join(tmp, "out")
    proc = subprocess.run(["bash", sut, "s3://fake/soak/run_test/", out],
                          env=env, capture_output=True, text=True, timeout=300)
    check(proc.returncode == 0 and "unexpected call" not in proc.stderr,
          "no unexpected awsx call on the unparseable path",
          proc.stderr[-300:])
    check(not os.path.exists(os.path.join(out, "dem", "BADGAME_x.dem")),
          "the bad .dem is removed too -- degrading must not leak disk")


print("\n%d checks, %d failures" % (checks, len(failures)))
if failures:
    for f in failures:
        print("  FAILED: %s" % f)
    sys.exit(1)
print("OK")
