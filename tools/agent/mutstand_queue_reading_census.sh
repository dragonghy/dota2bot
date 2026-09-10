#!/usr/bin/env bash
# Mutation stand for tools/agent/queue_reading_census.py (hero desk 2026-09-10).
# Not part of any suite -- run by hand when the tool or
# tests/test_queue_reading_census.py is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3), copied from
# mutstand_pending_rulings.sh because each line of it was paid for:
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose target string is absent ABORTS the stand: a no-op edit
#     scored as "caught" is the stand lying about what was on the bench;
#   * __pycache__ is purged between mutants.
#
# WHAT EACH MUTANT IS ANCHORED ON.  Every one of them is a way the tool could
# re-tell the story the tool was written to end -- a spent reading that still
# looks unspent (M1/M2/M10), a schema hole that stops being a finding
# (M3/M4), or "one reading on four rows" reading back as four readings
# (M5/M6).  M7/M8 are the label's honesty; M9 is could-not-run reading as a
# pass, which is GH #171 / #205 in one line.
#
# Usage: bash tools/agent/mutstand_queue_reading_census.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/agent/queue_reading_census.py
TEST=tests/test_queue_reading_census.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_qrc.XXXXXX")

cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }

restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || {
        echo "RESTORE FAILED -- $SRC does not match its pre-mutation checksum"; exit 2; }
}
trap restore EXIT

apply_mutant() {
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # -- a spent row must leave the candidate list ---------------------------
    "M1": ('SPENT_STATUSES = ("done", "delivered-and-consumed", "rejected")',
           'SPENT_STATUSES = ("done",)'),
    "M2": ('        spent = status in SPENT_STATUSES or any(\n'
           '            k.startswith("consumed_by") for k in row)',
           '        spent = status in SPENT_STATUSES'),
    "M10": ("        if text and not spent:", "        if text:"),
    # -- the schema hole must stay a finding ---------------------------------
    "M3": ('        if "status" not in row:', '        if False:'),
    "M4": ("        for f in findings:\n            print(\"  \" + f)\n        sys.exit(3)",
           "        for f in findings:\n            print(\"  \" + f)\n        sys.exit(0)"),
    # -- one reading on N rows must not read back as N readings --------------
    "M5": ("MIN_SHARED_SEGMENT = 120", "MIN_SHARED_SEGMENT = 1"),
    "M6": ('        for seg in re.split(r"\\|\\|", result_text(row)):',
           '        for seg in [result_text(row)]:'),
    # -- the label's honesty -------------------------------------------------
    "M7": ('    if len(ranked) > 1 and len(ranked[0][1]) == len(ranked[1][1]):\n'
           '        return "AMBIGUOUS", hits',
           '    if False:\n        return "AMBIGUOUS", hits'),
    "M8": ('        markers = ", ".join(sorted(\n'
           '            m for fired in evidence.values() for m in fired))[:60]',
           '        markers = ""'),
    # -- could-not-run must not read as a pass -------------------------------
    "M9": ('        print("COULD NOT RUN (exit 2, NOT a pass): %s -- %s"\n'
           '              % (os.path.relpath(QUEUE, ROOT), exc))\n'
           '        sys.exit(2)',
           '        print("COULD NOT RUN (exit 2, NOT a pass): %s -- %s"\n'
           '              % (os.path.relpath(QUEUE, ROOT), exc))\n'
           '        sys.exit(0)'),
}
old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

echo "== mutation stand: $SRC / $TEST"
worst=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10; do
    purge_pyc
    if ! apply_mutant "$m"; then
        echo "$m  APPLY-FAILED -- stand aborted rather than score a no-op as caught"
        restore; exit 2
    fi
    python3 "$TEST" > "$WORK/$m.log" 2>&1
    rc=$?                                  # bare: no pipe between test and $?
    sha=$(sha256sum "$SRC" | cut -c1-12)
    if [ "$rc" -eq 0 ]; then
        echo "$m  SURVIVED (sha=$sha) -- the tests do not pin this behaviour"
        worst=3
    else
        echo "$m  CAUGHT   (sha=$sha, exit $rc)"
    fi
    grep -E "^[0-9]+ checks|^FAIL" "$WORK/$m.log" | head -3 | sed 's/^/       /'
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
rc=$?
echo "baseline after restore: exit $rc :: $(tail -1 "$WORK/baseline.log")"
[ "$rc" -eq 0 ] || { echo "BASELINE RED after restore -- the stand left damage"; exit 2; }
exit $worst
