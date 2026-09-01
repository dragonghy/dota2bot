#!/usr/bin/env python3
"""corpus_hero_census.py must be able to say NO, and must say it by exit code.

WHY THIS EXISTS
    The reading this tool carries is asymmetric: `corpus 0` is load-bearing (a
    fixture-level acceptance of iron-rule-2 condition (a) is IMPOSSIBLE for that
    subject), while `corpus > 0` is nearly worthless (presence is necessary, not
    sufficient).  Three consecutive strategy rounds -- GH #385 / #393 / #397 --
    landed a gated fix on a subject with corpus 0, and each learned it only
    after the ruling came back DOMAIN-EMPTY.  #397 measured it once, inline,
    inside one test file's [source S6]; this pins the standing tool.

    Every failure mode of such a tool is SILENT and FLATTERING.  A walk that
    finds no files reports "0 appearances" for everybody, which reads exactly
    like the true answer for a hero who really is absent.  A `--hero` query that
    always exits 0 looks like a working tool to any caller that only checks the
    exit code.  Both are pinned by number below.

HOW IT TESTS
    It drives the REAL script by subprocess on the REAL repo corpus (that is the
    artifact whose readings other rounds will cite), and separately on a
    synthetic corpus injected through a copy of the tool pointed at a temp dir,
    so the "empty corpus" and "hero present" branches are exercised without
    editing tests/fixtures/.

    ANTI-VACUITY: the header lines are parsed first and nothing numeric is
    asserted until `frame files read` has actually been found, because every
    numeric assertion here would pass just as happily against a tool that
    printed nothing at all.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "agent", "corpus_hero_census.py")

failures = []


def check(cond, msg):
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def run(args, cwd=ROOT):
    proc = subprocess.run([sys.executable, SCRIPT] + args,
                          capture_output=True, text=True, cwd=cwd)
    return proc


if not os.path.isfile(SCRIPT):
    print("cannot run: %s is missing" % SCRIPT)
    sys.exit(2)

# ---------------------------------------------------------------------------
# 1. the real corpus -- and the anti-vacuity guard, before anything numeric
# ---------------------------------------------------------------------------
proc = run([])
m = re.search(r"frame files read\s*:\s*(\d+)", proc.stdout)
heroes = re.search(r"distinct heroes\s*:\s*(\d+)", proc.stdout)
parsed = bool(m and heroes)
check(parsed, "case1: the report prints a file count and a hero count at all")

if not parsed:
    print("\n%d checks failed" % len(failures))
    sys.exit(1)

nfiles = int(m.group(1))
nheroes = int(heroes.group(1))
check(proc.returncode == 0, "case1: a plain report exits 0 (got %d)" % proc.returncode)
check(nfiles >= 100,
      "case1: the walk actually reaches the archive -- >= 100 frame files (got %d)" % nfiles)
check(nheroes >= 20,
      "case1: and finds a real spread of heroes, not one (got %d)" % nheroes)

# A frame names ~10 heroes, so the appearance total must be several times the
# file count.  Without this, a walk that reads only the FIRST hero of each
# frame passes everything above: the focus heroes would still be PRESENT and
# the absent five would still be DOMAIN-EMPTY, for the wrong reason.
rows = re.findall(r"^\s*(\d+)\s+(\d+)\s+([a-z_0-9]+)(?:\s+<- WeakHeroes)?\s*$",
                  proc.stdout, re.M)
check(len(rows) == nheroes,
      "case1: the presence table lists every hero the header counted (%d rows vs %d)"
      % (len(rows), nheroes))
total = sum(int(r[0]) for r in rows)
check(total >= 5 * nfiles,
      "case1: appearances (%d) are several times the file count (%d) -- a frame "
      "names a whole lineup, so a walk reading one hero per file is caught here"
      % (total, nfiles))
check(all(int(r[1]) <= int(r[0]) for r in rows),
      "case1: distinct games never exceed files for any hero (the two columns "
      "are not the same number printed twice)")
# Fixtures cluster: several frames often come from one game.  If the two
# columns were ever EQUAL everywhere, the game column would just be the file
# count relabelled -- which is what the tool prints when the `game = '...'`
# read silently falls back to the path.
check(any(int(r[1]) < int(r[0]) for r in rows),
      "case1: and for at least one hero games < files, so the game column is a "
      "real de-duplication and not the file count under another name")

# --top must truncate the table and nothing else.  Without this the flag could
# print any prefix at all, since case1 never passes it.
top = run(["--top", "5"])
trows = re.findall(r"^\s*(\d+)\s+(\d+)\s+([a-z_0-9]+)(?:\s+<- WeakHeroes)?\s*$",
                   top.stdout, re.M)
check(len(trows) == 5, "case1: --top 5 prints exactly 5 rows (got %d)" % len(trows))
check([r[2] for r in trows] == [r[2] for r in rows[:5]],
      "case1: and they are the first 5 of the full ordering, not an arbitrary slice")
# ...but "the first 5 of the full ordering" is self-consistent under ANY
# ordering, including a reversed one, so the ordering itself is claimed
# absolutely: --top is only useful if the prefix is the most-present heroes.
counts_col = [int(r[0]) for r in rows]
check(counts_col == sorted(counts_col, reverse=True),
      "case1: the table is sorted most-present FIRST (head %r)" % counts_col[:5])

# The focus heroes are the sanity anchor: if THEY read 0, the walk is broken,
# not the archive.
for hero in ("crystal_maiden", "zuus", "skeleton_king", "axe", "lion"):
    proc = run(["--hero", hero])
    check(proc.returncode == 0 and "PRESENT" in proc.stdout,
          "case2: focus hero %s reads PRESENT and exits 0" % hero)

# ---------------------------------------------------------------------------
# 3. the load-bearing half: a subject with corpus 0 must be sayable BY EXIT CODE
# ---------------------------------------------------------------------------
# These five are the subjects of GH #393 and GH #397 (+ its 0HPB5 registry).
# If one of them ever becomes PRESENT that is GOOD NEWS and this test is the
# thing that says so out loud, rather than a stale sentence in a report.
absent = ("tiny", "shredder", "kez", "dawnbreaker", "brewmaster")
proc = run([a for h in absent for a in ("--hero", h)])
check(proc.returncode == 3,
      "case3: a query containing a corpus-0 subject exits 3, not 0 (got %d)"
      % proc.returncode)
for hero in absent:
    check(re.search(r"^\s*%s\s+DOMAIN-EMPTY" % hero, proc.stdout, re.M) is not None,
          "case3: %s reads DOMAIN-EMPTY -- if this fails the archive grew, which "
          "is good news and reopens 0HPB5" % hero)

# Mixed query: one present + one absent must still exit 3.  A tool that ORs
# instead of ANDs would exit 0 here and quietly bless the bad half.
proc = run(["--hero", "crystal_maiden", "--hero", "tiny"])
check(proc.returncode == 3,
      "case4: present+absent still exits 3 (a present subject must not mask an "
      "absent one; got %d)" % proc.returncode)

# ---------------------------------------------------------------------------
# 5. --file: the structural escape hatch is the tool's answer, not the reader's
# ---------------------------------------------------------------------------
proc = run(["--file", "bots/mode_retreat_generic.lua",
            "--file", "bots/FunLib/jmz_func.lua"])
check(proc.returncode == 0 and proc.stdout.count("SHARED") >= 2,
      "case5: shared code answers SHARED and pays no domain price (exit %d)"
      % proc.returncode)
proc = run(["--file", "bots/BotLib/hero_tiny.lua"])
check(proc.returncode == 3,
      "case5: a hero file inherits its subject's exit code (got %d)" % proc.returncode)
check("SHARED" not in proc.stdout,
      "case5: and is NOT answered as SHARED -- a hero file pays the domain "
      "price in full, which is the distinction the tool exists to draw")
check(re.search(r"^\s*tiny\s+DOMAIN-EMPTY", proc.stdout, re.M) is not None,
      "case5: it appears as a QUERIED SUBJECT row, not merely as a path echo")

# ---------------------------------------------------------------------------
# 6. the silent-and-flattering failure: an EMPTY corpus must not read as
#    "everybody is absent".  It must refuse with 2 (could-not-run).
# ---------------------------------------------------------------------------
tmp = tempfile.mkdtemp(prefix="corpuscensus_")
try:
    # A whole fake repo: tools/agent/<script copy> + empty tests/fixtures.
    os.makedirs(os.path.join(tmp, "tools", "agent"))
    os.makedirs(os.path.join(tmp, "tests", "fixtures"))
    os.makedirs(os.path.join(tmp, "bots"))
    fake = os.path.join(tmp, "tools", "agent", "corpus_hero_census.py")
    shutil.copyfile(SCRIPT, fake)
    proc = subprocess.run([sys.executable, fake, "--hero", "tiny"],
                          capture_output=True, text=True, cwd=tmp)
    check(proc.returncode == 2,
          "case6: an empty corpus exits 2 = could-not-run, NOT 3 = 'absent' "
          "and NOT 0 (got %d)" % proc.returncode)
    check("UNREADABLE" in (proc.stdout + proc.stderr),
          "case6: and says so in words, not only in the code")

    # Now put one frame in and confirm the same tool flips to PRESENT: without
    # this, case6 could be passing because the tool is broken everywhere.
    with open(os.path.join(tmp, "tests", "fixtures", "f_x.lua"), "w") as fh:
        fh.write("-- game = 'g1'\nunits = { { name = 'npc_dota_hero_tiny' } }\n")
    proc = subprocess.run([sys.executable, fake, "--hero", "tiny"],
                          capture_output=True, text=True, cwd=tmp)
    check(proc.returncode == 0 and "PRESENT" in proc.stdout,
          "case6: FALSIFICATION -- one injected frame flips tiny to PRESENT/0, "
          "so case6's exit 2 was about the empty corpus and not about the tool "
          "(got %d)" % proc.returncode)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

# ---------------------------------------------------------------------------
# 7. the WeakHeroes cross-read is a SEPARATE fact and must be reported as one
# ---------------------------------------------------------------------------
# The header ALWAYS prints a "WeakHeroes list : N" line, so a bare
# `"WeakHeroes" in stdout` is satisfied by a tool that never writes the note at
# all -- a mutant that deleted the note survived exactly that way.  Read the
# QUERIED SUBJECTS section only.
def subjects(out):
    parts = out.split("-- QUERIED SUBJECTS --")
    return parts[-1] if len(parts) > 1 else ""


proc = run(["--hero", "brewmaster"])
brew = subjects(proc.stdout)
check("brewmaster" in brew and "WeakHeroes" in brew,
      "case7: brewmaster's own note names the throttle list (it fights the draw "
      "as well as the archive -- the structural difference GH #397 registered)")
proc = run(["--hero", "tiny"])
check("WeakHeroes" not in subjects(proc.stdout),
      "case7: tiny's note does NOT -- the two facts are not merged")

print("\n%d checks failed" % len(failures))
sys.exit(1 if failures else 0)
