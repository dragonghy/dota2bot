#!/usr/bin/env bash
# Mutation stand for the pipe refusal in tools/agent/routine_selfcheck.sh
# (charter backlog 22).  Not part of any suite -- run by hand when the guard or
# tests/test_selfcheck_pipe_guard.py is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * every mutant is `cmp`-checked against the source first, so a no-op edit
#     cannot be mistaken for a surviving mutant;
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, NEVER
#     `git checkout` (which would also revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe stands between the command and `$?`,
#     which is the very defect the guard under test exists to prevent.
#
# Usage: bash tools/agent/mutstand_pipe_guard.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/agent/routine_selfcheck.sh
TEST=tests/test_selfcheck_pipe_guard.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BACKUP="$WORK/routine_selfcheck.sh.orig"

cp "$SRC" "$BACKUP"
( cd "$(dirname "$BACKUP")" && sha256sum "$(basename "$BACKUP")" > sum.txt )

restore() {
    cp "$BACKUP" "$SRC"
    # Prove the restore, rather than assuming it.
    local want got
    want=$(awk '{print $1}' "$WORK/sum.txt")
    got=$(sha256sum "$SRC" | awk '{print $1}')
    if [ "$want" != "$got" ]; then
        printf 'FATAL: restore of %s did not verify (%s != %s)\n' "$SRC" "$want" "$got" >&2
        exit 9
    fi
}
trap 'restore' EXIT

# run_case <name> <expect: RED|GREEN> <python-mutator or "">
run_case() {
    local name="$1" expect="$2" mut="${3:-}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$SRC" <<PY
import sys
p = sys.argv[1]
s = open(p).read()
$mut
open(p, 'w').write(s)
PY
        # Rule 1: a mutant that did not change the file is not a mutant.
        if cmp -s "$BACKUP" "$SRC"; then
            printf '%-10s ABORT: mutator produced a byte-identical file (no-op mutant)\n' "$name"
            return 1
        fi
    fi
    PG_TIMEOUT=45 python3 "$TEST" > "$WORK/$name.out" 2>&1
    local rc=$?          # bare, no pipe
    local verdict
    if [ "$rc" -eq 0 ]; then verdict=GREEN; else verdict=RED; fi
    if [ "$verdict" = "$expect" ]; then
        printf '%-10s %-5s (expected %s)  OK   %s\n' "$name" "$verdict" "$expect" \
            "$(head -1 "$WORK/$name.out")"
    else
        printf '%-10s %-5s (expected %s)  *** UNEXPECTED ***\n' "$name" "$verdict" "$expect"
        sed 's/^/             /' "$WORK/$name.out"
    fi
    grep '  FAIL' "$WORK/$name.out" | sed 's/^/             /'
}

printf '=== mutation stand: pipe guard (backlog 22) ===\n'
printf 'work dir: %s\n\n' "$WORK"

run_case CONTROL GREEN ""

# M1 -- the tty test instead of the FIFO test.  This is the wrong discriminant
# the charter warned about; under a pipe `[ -t 1 ]` is false, so the guard never
# fires.  Kills 1a and 5b.
run_case M1 RED 's = s.replace("[ -p /dev/stdout ]", "[ -t 1 ]", 1)'

# M2 -- guard disabled outright.
run_case M2 RED 's = s.replace("if [ -z \"${SELFCHECK_PIPE_OK:-}\" ] && [ -p /dev/stdout ]; then", "if false; then", 1)'

# M3 -- stderr aside moved back AFTER the verdict, so `2>&1 | tail -1` shows the
# aside instead of the verdict.  This is the bug the first draft actually had;
# it is here so it cannot come back silently.  Kills 3a and 5c.
run_case M3 RED '
aside = "    printf '"'"'REFUSED: routine_selfcheck.sh stdout is a pipe; exit 2, nothing checked.\\n'"'"' >&2\n"
verdict = "    printf '"'"'SELFCHECK_EXIT=2  REFUSED (nothing was checked; this is NOT a pass)\\n'"'"'\n"
assert aside in s and verdict in s, "M3 anchors not found"
s = s.replace(aside, "", 1).replace(verdict, verdict + aside, 1)'

# M4 -- the text still says 2, the process exits 0.  Every check that reads the
# MESSAGE stays green; only 1f, which reads the real code, goes red.  That is
# the point of 1f: a did-not-run wearing a pass.
run_case M4 RED '
i = s.index("SELFCHECK_EXIT=2  REFUSED")
j = s.index("    exit 2", i)
s = s[:j] + "    exit 0" + s[j+len("    exit 2"):]'

# M5 -- escape hatch removed; the documented opt-out for callers that really do
# read the exit code (subprocess capture) stops working.  Kills 4a/4b.
run_case M5 RED 's = s.replace("[ -z \"${SELFCHECK_PIPE_OK:-}\" ] && ", "", 1)'

printf '\n=== stand complete (source restored + verified on exit) ===\n'
