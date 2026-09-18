#!/usr/bin/env bash
# Mutation stand for "the push gate's leg 2 buys its own interpreter"
# (GH #899, director ruling 2026-09-18).  Target: tests/test_rc_wrapper.py's
# `_buy_lua()`.  Pin: tests/test_rc_wrapper_buys_lua.py.  Not part of any
# suite -- run by hand when either file is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * every mutant is `cmp`-checked against the source first, so a no-op edit
#     cannot be mistaken for a surviving mutant;
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, NEVER
#     `git checkout` (which would also revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the command and `$?`.
#
# WHAT THE PAIR OF MUTANTS IS FOR.  The claim has two halves and only the pair
# is the claim: buy the interpreter when it can be bought (M1 kills a revert to
# a bare `which`), and keep GH #384's UNCERTIFIABLE when it cannot (M2 kills the
# "fix" that would be strictly worse than the bug -- green with no interpreter,
# a did-not-run wearing a pass).  A stand with only M1 would wave M2 through.
#
# Usage: bash tools/agent/mutstand_rcwrap_lua.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tests/test_rc_wrapper.py
TEST=tests/test_rc_wrapper_buys_lua.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BACKUP="$WORK/test_rc_wrapper.py.orig"

cp "$SRC" "$BACKUP"
( cd "$WORK" && sha256sum "$(basename "$BACKUP")" > sum.txt )

restore() {
    cp "$BACKUP" "$SRC"
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
        if cmp -s "$BACKUP" "$SRC"; then
            printf '%-10s ABORT: mutator produced a byte-identical file (no-op mutant)\n' "$name"
            return 1
        fi
    fi
    python3 "$TEST" > "$WORK/$name.out" 2>&1
    local rc=$?          # bare, no pipe
    local verdict
    if [ "$rc" -eq 0 ]; then verdict=GREEN; else verdict=RED; fi
    if [ "$verdict" = "$expect" ]; then
        printf '%-10s %-5s (expected %s)  OK\n' "$name" "$verdict" "$expect"
    else
        printf '%-10s %-5s (expected %s)  *** UNEXPECTED ***\n' "$name" "$verdict" "$expect"
        sed 's/^/             /' "$WORK/$name.out"
    fi
    grep -E '  (FAIL|UNCERTIFIABLE)$' "$WORK/$name.out" | sed 's/^/             /'
}

printf '=== mutation stand: leg 2 buys its interpreter (GH #899) ===\n'
printf 'work dir: %s\n\n' "$WORK"

run_case CONTROL GREEN ""

# M1 -- the pre-#899 line, restored verbatim: decide from PATH, never buy.
# This is the state the ruling found, and case (A) is what must object.
run_case M1 RED '
i = s.index("HAS_LUA = _buy_lua()")
s = s[:i] + "HAS_LUA = shutil.which(\x27lua5.1\x27) is not None" + s[i+len("HAS_LUA = _buy_lua()"):]'

# M2 -- the tempting wrong fix: declare the interpreter present without
# acquiring it.  Deliberately NARROW -- the helper reference and the ordering
# survive, so both structural checks stay green and the kill has to come from
# behaviour.  (Read the stand's output rather than this comment: the first
# draft of M2 deleted the whole function, which killed the structural checks
# too and would have let me write "only (B) objects" off a reading that did not
# say that.  Evidence discipline 4.)
run_case M2 RED '
s = s.replace("    if shutil.which(\x27lua5.1\x27) is not None:\n        return True\n",
              "    if True:\n        return True\n", 1)'

# M3 -- buy the WRONG tool.  ensure_lua_tool() maps exactly two names and
# returns 1 on anything else, so the purchase silently no-ops while every line
# of the code still looks like it is buying something.  Structural check 1
# stays green (the helper is still named); (A) is what catches it.
run_case M3 RED '
s = s.replace("[\x27bash\x27, helper, \x27lua5.1\x27]", "[\x27bash\x27, helper, \x27luajit\x27]", 1)'

# M4 -- keep the purchase, drop the re-read: return the pre-purchase answer.
# The interpreter really is installed afterwards, so this mutant is invisible
# to anything that looks at the container instead of at the decision.
run_case M4 RED '
i = s.index("    return shutil.which(\x27lua5.1\x27) is not None\n\n\nHAS_LUA")
s = s[:i] + "    return False\n\n\nHAS_LUA" + s[i+len("    return shutil.which(\x27lua5.1\x27) is not None\n\n\nHAS_LUA"):]'

printf '\n=== stand complete (source restored + verified on exit) ===\n'
