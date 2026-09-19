#!/usr/bin/env bash
# Mutation stand for tests/test_blind_a_anim_activity_declare.lua and the
# switch it guards, tests/mock/replay_fixture.lua's M.declare_anim_activity
# (GH #908, director RULING 83 options 2+3).
#
# The stand exists because the test went green on its FIRST run, and a guard
# that has never been red is a guard nobody has measured (evidence-discipline
# rule 2).  Two of its claims are the kind that pass for free if the code does
# nothing at all -- "an undeclared unit refuses" and "a plain load() installs
# nothing" -- so both are mutated directly.
#
# Restore is by FILE COPY + `sha256sum -c`, never by re-applying an inverse
# edit (rule 1), and every exit code is read BARE (rule 3).
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 2

LOADER=tests/mock/replay_fixture.lua
BAK="$(mktemp -d)"
cp "$LOADER" "$BAK/loader.lua" || exit 2
( cd "$BAK" && sha256sum loader.lua > sums.txt ) || exit 2

caught=0
survived=0
aborted=0

restore() {
    cp "$BAK/loader.lua" "$LOADER" || exit 2
    ( cd "$BAK" && sha256sum -c --status sums.txt ) || {
        echo "ABORT: restore did not reproduce the original bytes"
        exit 2
    }
}

# GH #418: the copy-back is the only thing between this stand and a committed
# mutant, so it must survive ^C, a timeout, an OOM or a reclaimed container.
trap restore EXIT

run_subset() {
    lua5.1 tests/run_tests.lua blind_a_anim_activity_declare \
        > "$BAK/out.txt" 2>&1
    echo $?
}

mutate() {  # mutate <label> <python snippet editing `s`>
    local label="$1" code="$2"
    python3 - "$LOADER" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
orig = s
$code
if s == orig:
    sys.exit(7)
open(p, "w", encoding="utf-8").write(s)
PY
    local rc=$?
    if [ "$rc" -eq 7 ]; then
        echo "ABORT $label: byte-identical file -- the anchor is gone, not the mutant"
        aborted=$((aborted + 1))
        return 1
    fi
    if [ "$rc" -ne 0 ]; then
        echo "ABORT $label: mutator failed with $rc"
        aborted=$((aborted + 1))
        return 1
    fi
    return 0
}

verdict() {  # verdict <label> <exit code>
    local label="$1" rc="$2"
    if [ "$rc" -ne 0 ]; then
        echo "CAUGHT   $label (subset exit $rc)"
        caught=$((caught + 1))
    else
        echo "SURVIVED $label (subset exit 0) -- suspect the ASSERTION, not the mutant"
        survived=$((survived + 1))
    fi
}

# --- CONTROL -----------------------------------------------------------------
rc=$(run_subset)
if [ "$rc" -ne 0 ]; then
    echo "ABORT: CONTROL is red (exit $rc); nothing below would mean anything"
    cat "$BAK/out.txt"
    restore
    exit 2
fi
echo "CONTROL  green (exit 0)"

# --- M1: opt-in degenerates into "and otherwise fall back to 0" --------------
# The whole ruling turns on the undeclared side REFUSING rather than answering
# the fabricated 0.  This mutant is the pre-#908 world wearing the new API.
if mutate M1 '
i = s.index("            spec.GetAnimActivity = function()\n                error(\x27LOADER REFUSES")
j = s.index("            nRefused = nRefused + 1", i)
s = s[:i] + "            spec.GetAnimActivity = function() return 0 end\n" + s[j:]
'; then
    verdict "M1 an undeclared unit answers 0 instead of refusing" "$(run_subset)"
fi
restore

# --- M2: the switch stops being opt-in ---------------------------------------
# The priced-and-rejected form: the loader states the activity for everybody,
# which is what reddened 18 files / 70 cases.  [5] is the only thing standing
# between that reading and main.
if mutate M2 '
anchor = "    return J, bot, heroes, fx\nend"
assert s.count(anchor) == 1, s.count(anchor)
s = s.replace(anchor, """    for _, h in pairs(heroes) do
        rawget(h, \x27__spec\x27).GetAnimActivity = function() return 0 end
    end
""" + anchor, 1)
'; then
    verdict "M2 load() installs the getter on every handle by itself" "$(run_subset)"
fi
restore

# --- M3: `idle` quietly becomes the fabricated 0 again -----------------------
if mutate M3 '
s = s.replace("    idle    = \x27ACTIVITY_IDLE\x27,", "    idle    = \x27NOT_AN_ACTIVITY_ZERO\x27,", 1)
s = s.replace("            spec.GetAnimActivity = function() return _G[sConst] end",
              "            spec.GetAnimActivity = function()\n"
              "                if sConst == \x27NOT_AN_ACTIVITY_ZERO\x27 then return 0 end\n"
              "                return _G[sConst]\n            end", 1)
'; then
    verdict "M3 declaring idle hands back the pre-#908 fabricated 0" "$(run_subset)"
fi
restore

# --- M4: a typo'd activity word no-ops instead of raising --------------------
if mutate M4 '
i = s.index("        if ANIM_ACTIVITY_WORDS[sWord] == nil then")
j = s.index("        end\n    end\n    local nDeclared", i)
s = s[:i] + s[j + len("        end\n"):]
'; then
    verdict "M4 an unknown activity word is accepted silently" "$(run_subset)"
fi
restore

# --- M5: a typo'd UNIT NAME no-ops instead of raising ------------------------
# Distinct from M4 and worth its own mutant: a misspelt hero declares nothing,
# so the unit the test meant to declare lands in the refusing branch and the
# test reads a refusal it believes it asked for.
if mutate M5 '
i = s.index("        if heroes[sName] == nil then")
j = s.index("        if ANIM_ACTIVITY_WORDS[sWord] == nil then", i)
s = s[:i] + s[j:]
'; then
    verdict "M5 an unknown unit name is accepted silently" "$(run_subset)"
fi
restore

# --- M6: the declaration reports success and installs nothing ----------------
# The "matching conclusion, wrong reason" shape (rule 4): counts still add up.
if mutate M6 '
s = s.replace("            spec.GetAnimActivity = function() return _G[sConst] end",
              "            local _ = sConst", 1)
'; then
    verdict "M6 declare counts the unit but writes no getter" "$(run_subset)"
fi
restore

# --- M7: the refusal loses the name a reader greps for -----------------------
# A refusal nobody can identify sends the next round back to bisection, which
# is the cost GH #61 paid to avoid.
if mutate M7 '
s = s.replace("                error(\x27LOADER REFUSES: GetAnimActivity is unresolved (GH #908)\x27",
              "                error(\x27unresolved\x27", 1)
'; then
    verdict "M7 the refusal drops its LOADER REFUSES / GH #908 name" "$(run_subset)"
fi
restore

echo
echo "CONTROL green | $caught CAUGHT / $survived SURVIVED / $aborted ABORTED"
restore
trap - EXIT          # the pristine copy is about to go; disarm first
rm -rf "$BAK"
[ "$survived" -eq 0 ] && [ "$aborted" -eq 0 ] && exit 0
exit 3
