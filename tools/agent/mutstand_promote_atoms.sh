#!/usr/bin/env bash
# Mutation stand for tools/agent/promote_atoms.py (director 2026-09-04, §EI).
# Not part of any suite -- run by hand when the tool or
# tests/test_promote_atoms.py is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- the test writes to a log file and `$?` is
#     read with no pipe between it and the command;
#   * a mutant whose target string is absent ABORTS: a no-op edit scored as
#     "caught" is the stand lying about what was on the bench;
#   * __pycache__ is purged between mutants (the test runs the tool as a
#     SUBPROCESS, not an import, so a stale .pyc is not the hazard it was for
#     mutstand_pending_rulings.sh -- purged anyway, at zero cost, because the
#     day someone switches to an import is not the day to remember this).
#
# ⭐ TWO MUTANTS MUST SURVIVE, and they are the point of reading this file.
#   M9 changes only a message string.  M10 widens the scan to `game/` as well
#   as `bots/` -- on this tree that is a no-op (no soak gates live under
#   game/), so it is a RANGE control: writing a check that kills it would pin
#   an implementation detail as behaviour.  A stand where everything dies is
#   a stand that has stopped distinguishing.
#
# Usage: bash tools/agent/mutstand_promote_atoms.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/agent/promote_atoms.py
TEST=tests/test_promote_atoms.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_pa.XXXXXX")

cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }

restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || {
        echo "RESTORE FAILED -- $SRC does not match its pre-mutation checksum"; exit 2; }
}

# A stand interrupted between apply and restore leaves the MUTANT in the tree,
# where the next `git add -A` commits it (GH #418 -- that is not hypothetical).
trap restore EXIT

apply_mutant() {
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # -- comment stripping: the decoy defence (cases 3 / 4) ------------------
    # M1 is the whole reason this tool strips comments: without it, the tool
    # is RED on trunk from birth on five cautionary comments.
    "M1": ("        stripped = strip_lua_comments(raw)",
           "        stripped = raw"),
    "M2": ("        idx = line.find('--')",
           "        idx = -1"),
    "M3": ("    text = BLOCK_COMMENT_RE.sub(lambda m: '\\n' * m.group(0).count('\\n'), text)",
           "    text = text"),
    # -- the frozen-FALSE leg (shape A, the pullcad trap) --------------------
    "M4": ("    frozen = sorted(i for i in promoted if live.get(i))",
           "    frozen = []"),
    # -- the atom leg (shape B, test_set.md §ED.5) ---------------------------
    "M5": ("            if states.get(subj) == 'PROMOTED' and still_gated:",
           "            if False:"),
    "M6": ("        still_gated = [p for p in prereqs if states.get(p) == 'GATED']",
           "        still_gated = [p for p in prereqs if states.get(p) == 'PROMOTED']"),
    # -- the vacuity guard: a typo'd id must be LOUD -------------------------
    "M7": ("        unknown = sorted(i for i, s in states.items() if s == 'UNKNOWN')",
           "        unknown = []"),
    # -- could-not-run is not a pass (repo convention 0/2/3) -----------------
    "M8": ("        return 2 if not findings else 3, lines",
           "        return 0 if not findings else 3, lines"),
    # -- RANGE CONTROLS: these MUST survive ---------------------------------
    "M9": ("        lines.append('FROZEN    none (no live gate names a promoted id)')",
           "        lines.append('FROZEN    none (nothing frozen)')"),
    "M10": ("SCAN_DIRS = ('bots', 'game')",
            "SCAN_DIRS = ('bots',)"),
    # -- an unknown rule kind must not read as satisfied ---------------------
    "M11": ('''        if rule != 'no_promote_without':
            findings += 1''',
            '''        if rule != 'no_promote_without':
            findings += 0'''),
}
old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

# M9 and M10 are range controls: SURVIVED is the correct outcome for them.
EXPECT_SURVIVE=" M9 M10 "

echo "== mutation stand: $SRC / $TEST"
worst=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11; do
    purge_pyc
    if ! apply_mutant "$m"; then
        echo "$m  APPLY-FAILED -- stand aborted rather than score a no-op as caught"
        restore; exit 2
    fi
    python3 "$TEST" > "$WORK/$m.log" 2>&1
    rc=$?                                  # bare: no pipe between test and $?
    sha=$(sha256sum "$SRC" | cut -c1-12)
    case "$EXPECT_SURVIVE" in
        *" $m "*) want_survive=1 ;;
        *)        want_survive=0 ;;
    esac
    if [ "$rc" -eq 0 ]; then
        if [ "$want_survive" -eq 1 ]; then
            echo "$m  SURVIVED (sha=$sha) -- CORRECT, range control"
        else
            echo "$m  SURVIVED (sha=$sha) -- the tests do not pin this behaviour"
            worst=3
        fi
    else
        if [ "$want_survive" -eq 1 ]; then
            echo "$m  CAUGHT   (sha=$sha, exit $rc) -- WRONG: a range control died,"
            echo "        which means a check is pinning an implementation detail"
            worst=3
        else
            echo "$m  CAUGHT   (sha=$sha, exit $rc)"
        fi
    fi
    grep -E "^[0-9]+ check|^FAIL" "$WORK/$m.log" | sed 's/^/       /'
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
rc=$?
echo "baseline after restore: exit $rc :: $(tail -2 "$WORK/baseline.log" | head -1)"
[ "$rc" -eq 0 ] || { echo "BASELINE RED after restore -- the stand left damage"; exit 2; }
exit $worst
