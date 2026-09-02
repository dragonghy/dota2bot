#!/usr/bin/env bash
# Mutation stand for the third summary bucket of 开工自检 -- `NOT RUN (inside a
# leg)` (GH #420).  Not part of any suite; run by hand when
# tools/agent/selfcheck_tally.sh, the python leg of
# tools/agent/routine_selfcheck.sh, or section 9 of
# tests/test_selfcheck_exit_attribution.py is edited.
#
# WHAT THIS IS GRADING.  #420's defect was not "a missing line".  It was that
# the two existing buckets are keyed on a LEG'S NOTE LEVEL, and a leg has
# exactly one -- so a python leg that is BOTH red and partly un-run reports
# whole into FINDINGS and its un-run files land nowhere, under a line that says
# `UNCERTIFIABLE (exit 2): none`.  A mutant that merely deletes the new line is
# therefore the EASY one (M1).  The ones worth having are M3 (read the runner's
# machine-readable roll-up, which is absent exactly on the red tree) and M2
# (call the extractor inside a branch, which is how the leg body first acquired
# this same bug) -- both are plausible refactors that a decorative test suite
# would wave through.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * every mutant is `cmp`-checked against its source, so a no-op edit cannot
#     be mistaken for a surviving mutant;
#   * restore is an out-of-tree `cp` verified with `sha256sum`, NEVER
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the command and `$?`.
#
# Usage: bash tools/agent/mutstand_unrun_bucket.sh
set -u
cd "$(dirname "$0")/../.."

TALLY=tools/agent/selfcheck_tally.sh
WRAPPER=tools/agent/routine_selfcheck.sh
TEST=tests/test_selfcheck_exit_attribution.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_unrun.XXXXXX")

cp "$TALLY"   "$WORK/tally.orig"
cp "$WRAPPER" "$WORK/wrapper.orig"
TALLY_SUM=$(sha256sum "$WORK/tally.orig"   | awk '{print $1}')
WRAP_SUM=$(sha256sum  "$WORK/wrapper.orig" | awk '{print $1}')

restore() {
    cp "$WORK/tally.orig"   "$TALLY"
    cp "$WORK/wrapper.orig" "$WRAPPER"
    local a b
    a=$(sha256sum "$TALLY"   | awk '{print $1}')
    b=$(sha256sum "$WRAPPER" | awk '{print $1}')
    if [ "$a" != "$TALLY_SUM" ] || [ "$b" != "$WRAP_SUM" ]; then
        printf 'FATAL: restore did not verify -- do NOT commit this tree.\n' >&2
        exit 9
    fi
}
trap 'restore' EXIT

# run_case <name> <expect: RED|GREEN> <file> <python-mutator or "">
run_case() {
    local name="$1" expect="$2" target="${3:-}" mut="${4:-}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$target" <<PY
import sys
p = sys.argv[1]
s = open(p).read()
$mut
open(p, 'w').write(s)
PY
        if cmp -s "$WORK/$(basename "$target" .sh).orig" "$target" 2>/dev/null \
           || { [ "$target" = "$TALLY" ] && cmp -s "$WORK/tally.orig" "$target"; } \
           || { [ "$target" = "$WRAPPER" ] && cmp -s "$WORK/wrapper.orig" "$target"; }; then
            printf '%-9s ABORT: mutator produced a byte-identical file (no-op mutant)\n' "$name"
            return 1
        fi
    fi
    python3 "$TEST" > "$WORK/$name.out" 2>&1
    local rc=$?          # bare, no pipe
    local verdict
    if [ "$rc" -eq 0 ]; then verdict=GREEN; else verdict=RED; fi
    if [ "$verdict" = "$expect" ]; then
        printf '%-9s %-5s (expected %s)  CAUGHT/OK  %s\n' "$name" "$verdict" "$expect" \
            "$(head -1 "$WORK/$name.out")"
    else
        printf '%-9s %-5s (expected %s)  *** UNEXPECTED ***\n' "$name" "$verdict" "$expect"
        sed 's/^/            /' "$WORK/$name.out"
    fi
    grep '^      ' "$WORK/$name.out" | head -4 | sed 's/^/            /'
}

printf '=== mutation stand: NOT RUN bucket (GH #420) ===\n'
printf 'work dir: %s\n\n' "$WORK"

run_case CONTROL GREEN "" ""

# M1 -- the line is gone.  The pre-#420 output, byte for byte: two buckets, and
# a run that is red-and-un-run says `UNCERTIFIABLE (exit 2): none`.
run_case M1 RED "$TALLY" '
s = s.replace("""    printf '"'"'NOT RUN (inside a leg): %s\\n'"'"' "${_sc_unrun:-none}"\n""", "", 1)'

# M2 -- the extractor call moves INSIDE the exit-2 branch.  This is the exact
# shape of the original bug one level down (the leg body named the un-run file
# only on the exit-2 branch, so the strictly worse tree said less), and it is a
# tempting "only run it when it can matter" refactor.  9.8 is the check.
run_case M2 RED "$WRAPPER" '
call = "    sc_unrun_from_py_output \"$suite\"\n"
assert call in s, "M2 anchor not found"
s = s.replace(call, "", 1)
anchor = "        note 2\n"
assert anchor in s, "M2 branch anchor not found"
s = s.replace(anchor, call + anchor, 1)'

# M3 -- ⭐ read the runner s machine-readable roll-up instead of its per-file
# lines.  Looks strictly cleaner (one parse instead of a scan) and is green on
# any tree where nothing FAILED -- but run_py_tests.sh exits 1 on the `failed:`
# line before ever printing `uncertifiable:`, so on the #420 tree the roll-up
# does not exist and the bucket is silently empty again.  9.1 is the check.
run_case M3 RED "$TALLY" '
old = """    _names=$(printf '"'"'%s\\n'"'"' "$1" | awk '"'"'$1 == "UNCERTIFIABLE" && $2 ~ /^tests\\// { print $2 }'"'"')"""
assert old in s, "M3 anchor not found"
new = """    _names=$(printf '"'"'%s\\n'"'"' "$1" | sed -n '"'"'s/^uncertifiable://p'"'"')"""
s = s.replace(old, new, 1)'

# M4 -- the new bucket starts moving the exit code (`sc_unrun` folds into
# `worst`).  #420 asks for visibility and says the exit semantics move by zero
# words; a bucket that re-adjudicates would make every stream s reading of the
# integer change silently.  9.2 is the check.
run_case M4 RED "$TALLY" '
old = """    for _u in $1; do\n        _sc_unrun=$(_sc_add "$_sc_unrun" "$_u")\n    done\n    return 0"""
assert old in s, "M4 anchor not found"
s = s.replace(old, old.replace("    return 0", "    [ -n \"$1\" ] && _sc_worst=2\n    return 0"), 1)'

# M5 -- the drift banner is removed.  The extractor then prints a confident
# short list whenever the runner s format moves under it -- which is this
# file s header rule ("must not be able to lie quietly") turned off.  9.6.
run_case M5 RED "$TALLY" '
i = s.index("    if [ \"$_sc_unrun_seen\" -ne \"$_sc_unrun_declared\" ]; then")
j = s.index("    fi\n", s.index("Fix the extractor", i))
s = s[:i] + s[j+len("    fi\n"):]'

# M6 -- the extractor prints the wrong awk field, so the literal word
# UNCERTIFIABLE enters the bucket instead of the file name.  A count-only check
# would survive this (two in, two out); 9.1/9.3 read the NAMES.
run_case M6 RED "$TALLY" '
s = s.replace("{ print $2 }", "{ print $1 }", 1)'

printf '\n=== stand complete (both sources restored + verified on exit) ===\n'
