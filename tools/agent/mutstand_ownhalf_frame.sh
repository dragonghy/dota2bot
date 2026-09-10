#!/usr/bin/env bash
# Mutation stand for tests/test_replay_212625_lion_ownhalf_punish.lua -- the
# (a)-evidence frame for the 'ownhalf' soak candidate.
#
# A green fixture test proves nothing until something that SHOULD break it
# does. This stand mutates the real gate in bots/FunLib/jmz_func.lua, re-runs
# the frame test, and restores from a FILE COPY taken before the first mutation
# (evidence-discipline rule 1: never restore with a re-edit).
#
# Expected, as recorded in the test's header on 2026-09-10:
#   M1 depth margin unreachable        -> KILLED (1 fail)
#   M2 SafeToCommitFight conjunct gone -> KILLED (2 fails)
#   M3 margin reverted to old 800      -> SURVIVES, on purpose and declared:
#      both invaders on this frame are past 800 AND past 1600, so the frame
#      cannot separate the margins. tests/test_ownhalf_margin.lua owns that.
#
# Read-only on AWS; touches nothing but jmz_func.lua, which it puts back.
# Exit 0 = the stand reproduced the recorded outcome; 1 = it did not.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
SRC=bots/FunLib/jmz_func.lua
TEST=tests/test_replay_212625_lion_ownhalf_punish.lua
WORK=$(mktemp -d)
ORIG="$WORK/jmz_func.lua.orig"
RUNNER="$WORK/runone.lua"

# The copy-back is the only thing between this stand and a committed mutant, so
# it is a function reached by an EXIT trap armed BEFORE the first mutation --
# a timeout, a ^C or a reclaimed container must not leave the defect behind
# (GH #418). The temp dir is removed only AFTER the restore, so an interrupt can
# never delete the sole pristine copy.
unmutate() { [ -f "$ORIG" ] && cp "$ORIG" "$SRC"; }
restore() {
    unmutate
    rm -rf "$WORK"
}
trap restore EXIT

command -v lua5.1 >/dev/null 2>&1 || bash tools/agent/ensure_lua_toolchain.sh >/dev/null 2>&1
command -v lua5.1 >/dev/null 2>&1 || { echo "UNCERTIFIABLE: no lua5.1; this is NOT a pass"; exit 2; }

cp "$SRC" "$ORIG"

cat > "$RUNNER" <<EOF
package.path = 'tests/?.lua;' .. package.path
local tests = dofile('$TEST')
local pass, fail = 0, 0
local names = {}
for k in pairs(tests) do names[#names+1] = k end
table.sort(names)
for _, name in ipairs(names) do
    local ok, err = pcall(tests[name])
    if ok then pass = pass + 1
    else fail = fail + 1; io.stderr:write('  FAIL ' .. name .. '\n') end
end
io.stderr:write(string.format('%d passed, %d failed\n', pass, fail))
os.exit(fail == 0 and 0 or 1)
EOF

run() { lua5.1 "$RUNNER" >/dev/null 2>"$WORK/out"; echo $?; }
report() { sed 's/^/      /' "$WORK/out"; }

rc=0
check() { # name expected_kill
    local label="$1" want="$2" got
    got=$(run)
    local verdict
    if [ "$want" = kill ]; then
        [ "$got" -ne 0 ] && verdict=KILLED || { verdict="SURVIVED (UNEXPECTED)"; rc=1; }
    else
        [ "$got" -eq 0 ] && verdict="SURVIVED (expected)" || { verdict="KILLED (UNEXPECTED)"; rc=1; }
    fi
    echo "  $label -> $verdict (exit $got)"
    report
}

echo "[baseline] unmutated tree"
got=$(run); echo "  baseline exit $got"; report
[ "$got" -eq 0 ] || { echo "BASELINE RED -- stand is meaningless until it is green"; exit 1; }

echo "[M1] depth margin -> unreachable"
sed -i 's/if nInvadeDepth >= 1600 then bInDomain = true end/if nInvadeDepth >= 100000 then bInDomain = true end/' "$SRC"
check M1 kill
unmutate

echo "[M2] delete the SafeToCommitFight conjunct"
python3 - "$SRC" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = ("\t\t\tif bInDomain\n"
       "\t\t\tand J.SafeToCommitFight( bot, enemy )\n"
       "\t\t\tand not J.ShouldRefuseUnsupportedPunish( bot, enemy )\n"
       "\t\t\tthen")
new = ("\t\t\tif bInDomain\n"
       "\t\t\tand not J.ShouldRefuseUnsupportedPunish( bot, enemy )\n"
       "\t\t\tthen")
assert s.count(old) == 1, f"expected exactly 1 site, found {s.count(old)}"
open(p, 'w').write(s.replace(old, new))
PY
check M2 kill
unmutate

echo "[M3] margin reverted to the old 800 (expected to survive)"
sed -i 's/if nInvadeDepth >= 1600 then bInDomain = true end/if nInvadeDepth >= 800 then bInDomain = true end/' "$SRC"
check M3 survive
unmutate

echo "[restore] verifying the tree is back"
if git diff --quiet -- "$SRC"; then echo "  RESTORED clean"; else echo "  RESTORE FAILED"; rc=1; fi
got=$(run); echo "  post-restore exit $got"; report
[ "$got" -eq 0 ] || rc=1

echo "STAND EXIT $rc"
exit $rc
