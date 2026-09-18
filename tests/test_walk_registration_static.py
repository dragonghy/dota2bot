"""The half of the io.popen walk census that fits in the push gate.

WHY THIS FILE EXISTS
--------------------
`tests/test_bots_walk_farm_only.py` is the ONLY reader that notices a newly
landed `tests/*.lua` walk whose `io.popen` command cannot be resolved
statically and was never hand-read.  It has reddened trunk at least eight
times since 2026-09-12, and every single time the same way: an author lands
the walk, that author's push is NOT refused, and the red is bought hours later
by whichever desk opens next -- twice in one day on 2026-09-18.

The mechanical reason is a price, not a habit.  Measured on a Routine
container, 2026-09-18:

    read + statically resolve every tests/ io.popen   1.679s
    execute the 89 distinct read-only walks           2.556s
                                                      -----
    tools/agent/py_gate_manifest.json                 5.527s  vs 3.0s cap
                                                      => in_gate: false

Only the second half can answer "does a walk reach bots/Customize/".  The
registration question -- the one that keeps going red -- is answered by the
first half alone, and the first half fits in the cap with room to spare.  So
the census grew a `--static-only` mode and THIS file is what the push gate
runs.  `owed_executions.json:walk_census_out_of_push_gate_so_rule803_cannot_bind`
option (甲).

⛔ IT DOES NOT RE-IMPLEMENT THE CENSUS.  It runs it.  The extractor has a
retry that drops a trailing top-level `, <message>` argument, and that retry
moves 20 of 98 statically-unresolved sites into the resolved column: a second
spelling that forgot it would report 20 fabricated findings on its first run.
One implementation, two entry points -- this repo's most-recorded defect is
"a baseline written by one regex and read by another".

⛔ IT REFUSES TO LET `--static-only` GROW.  The mode names the checks it did
not run, and check 2 below asserts that naming is still there.  A did-not-run
wearing a pass is GH #171 / #198 / #200 / #384's shape.

Run: python3 tests/test_walk_registration_static.py
"""

import ast
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CENSUS = os.path.join(HERE, "test_bots_walk_farm_only.py")

checks = 0
failures = []


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        failures.append(msg)


# --- 1. the subset runs, and its exit code is the census's own ---------------
proc = subprocess.run([sys.executable, CENSUS, "--static-only"], cwd=REPO,
                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                      timeout=120)
out = proc.stdout.decode("utf-8", "replace")

check(proc.returncode == 0,
      "the static half of the walk census is RED -- read its own FAIL line, do "
      "not silence it here:\n%s" % out.strip())

# --- 2. the mode still says what it did NOT do ------------------------------
# Skipped is not passed.  If someone deletes the banner, or widens the mode
# until nothing is skipped, this goes red rather than the mode quietly
# becoming "the whole census" in the reader's head.
not_run = [ln for ln in out.splitlines() if ln.startswith("NOT RUN (--static-only")]
check(len(not_run) >= 2,
      "--static-only no longer names the checks it skipped (%d NOT RUN lines) "
      "-- either the banner was deleted, in which case a reader cannot tell "
      "this apart from the full census, or the mode grew and this file's "
      "measured cost is stale: re-measure before trusting it. Output:\n%s"
      % (len(not_run), out.strip()))
check("this is not a pass" in out,
      "the NOT RUN banner no longer says it is not a pass")
# Belt and braces: the exit code is one channel and the FAIL lines are another.
# A census that swallowed its own `sys.exit` would still print what it found,
# and a guard that reads only the code would report green on a red tree.
fails_printed = [ln for ln in out.splitlines() if ln.startswith("FAIL:")]
check(not fails_printed,
      "the static half printed findings while exiting %d -- believe the "
      "findings: %s" % (proc.returncode, fails_printed))
check(out.startswith("STATIC-ONLY: "),
      "the summary line no longer announces the mode, so a pasted reading "
      "cannot be told apart from the full census's: %r" % out.splitlines()[:1])

# --- 3. anti-vacuity: the population the check consumes is still there ------
# A census pointed at nothing reports zero findings and exits clean (GH #345).
m = re.search(r"\[(\d+) call sites resolved, (\d+) unresolved\]", out)
check(m is not None,
      "cannot read the counts off the static run's summary line: %r"
      % out.splitlines()[:1])
if m:
    resolved, unresolved = int(m.group(1)), int(m.group(2))
    check(resolved >= 100,
          "only %d call sites resolved -- the extractor stopped matching, so "
          "'no findings' here would mean 'nothing scanned'" % resolved)
    check(unresolved > 0,
          "zero unresolved sites -- the hand-read list has %d rows, so an empty "
          "unresolved population means the parameter-built walks stopped being "
          "seen, not that they went away" % unresolved)

# --- 4. the hand-read list, read off the SOURCE ------------------------------
# Duplicate keys: by the time the dict object exists the evidence is gone --
# a dict literal keeps the LAST value silently.  Four keys were duplicated on
# 2026-09-18 (cm_lane_fallback_wallet, cm_kill_confirm_quantifier,
# wk_q_teamfight_reach_pricing, lion_hex_panic_level), each one discarding a
# hand read that a desk had actually done, and the census had no check for it
# although its own comment at the axe_hunger_camp_reach gap names the hazard.
census_src = open(CENSUS, encoding="utf-8").read()
tree = ast.parse(census_src)
tables = {}
for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
        for t in node.targets:
            name = getattr(t, "id", None)
            if name in ("UNRESOLVED_HAND_READ", "READ_SIDE_FILTERED"):
                tables[name] = node.value

check(set(tables) == {"UNRESOLVED_HAND_READ", "READ_SIDE_FILTERED"},
      "cannot find both tables in the census source (found %s) -- this file "
      "reads them by name, so a rename must be seen, not silently skipped"
      % sorted(tables))

for name, node in sorted(tables.items()):
    keys = [k.value for k in node.keys]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    check(not dupes,
          "%s has the same key twice; a dict literal keeps only the LAST value, "
          "so the other hand read is discarded silently -- merge them, do not "
          "delete one: %s" % (name, dupes))

# The list has to be somewhere near the size of the unresolved population, or
# the two have drifted apart and the stale check is carrying the difference.
if m and "UNRESOLVED_HAND_READ" in tables:
    n_keys = len(tables["UNRESOLVED_HAND_READ"].keys)
    check(n_keys > 0 and unresolved >= n_keys,
          "%d hand-read rows against %d unresolved sites -- the census's own "
          "stale check should have caught this first; read it before touching "
          "this one" % (n_keys, unresolved))

# --- 5. no second spelling of the flag --------------------------------------
check(census_src.count('"--static-only" in sys.argv') == 1,
      "the --static-only flag is read in more than one place in the census; "
      "one spelling or the modes drift apart")

print("%d checks, %d failed  [%s]"
      % (checks, len(failures), out.splitlines()[0] if out else "no output"))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
