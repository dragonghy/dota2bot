#!/usr/bin/env bash
# Mutation stand for the gated-getter stub census (director 2026-09-09).
#
# Covers BOTH halves, because the census's whole point is that they are
# different questions and the gap between them is the defect class:
#
#   tests/test_gated_getter_stub_census.py   -- what the census SAYS (static)
#   tests/test_gated_getter_stub_control.lua -- what the loader DOES (a reading)
#
# M1 and M2 are not invented mutants: they are the two defects this census
# actually had while it was being written, both of which produced a SMALLER and
# CLEANER answer rather than an error.  If either survives, the reach counters
# are decoration and the purchase list is unfalsifiable.
#
# DISCIPLINE (evidence-discipline rules 1-3; GH #418 restore family):
#   * pristine copies live OUTSIDE the temp dir the trap wipes, `trap restore
#     EXIT` is armed BEFORE the first mutant, and the run ends by proving
#     byte-identity with sha256sum;
#   * every mutant is `cmp`-checked, so an edit that changed nothing cannot be
#     scored as a surviving mutant;
#   * exit codes are read BARE -- no pipe between the runner and `$?`.
#
# ⚠️ DO NOT RUN CONCURRENTLY WITH THE FULL SUITE OR 开工自检: M7 rewrites
# tests/mock/bot_api.lua in place, which every Lua test in the tree reads.
#
# Usage: bash tools/agent/mutstand_gated_getter_stub.sh
set -u
cd "$(dirname "$0")/../.."

CEN=tools/agent/gated_getter_stub_census.py
MOCK=tests/mock/bot_api.lua
PYTEST=tests/test_gated_getter_stub_census.py
LUATEST=test_gated_getter_stub_control.lua

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BAK=$(mktemp -d "${TMPDIR:-/tmp}/mutbak.XXXXXX")     # NOT the dir the trap wipes
cp "$CEN" "$BAK/census.orig"
cp "$MOCK" "$BAK/bot_api.orig"
sha256sum "$CEN" "$MOCK" > "$BAK/manifest.sha256"

restore() {
    cp "$BAK/census.orig" "$CEN"
    cp "$BAK/bot_api.orig" "$MOCK"
    if ! sha256sum -c --quiet "$BAK/manifest.sha256"; then
        printf 'FATAL: restore did not verify -- the tree may hold a mutant\n' >&2
        exit 9
    fi
}
trap 'restore; rm -rf "$WORK"' EXIT
restore                                   # prove the manifest before mutating

caught=0
survived=0

# run_case <name> <file> <expect RED|GREEN> <runner: py|lua> <python-mutator>
run_case() {
    local name="$1" file="$2" expect="$3" runner="$4" mut="${5:-}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$file" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
$mut
open(p, 'w', encoding='utf-8').write(s)
PY
        local orig
        case "$file" in
            "$CEN")  orig="$BAK/census.orig" ;;
            "$MOCK") orig="$BAK/bot_api.orig" ;;
        esac
        if cmp -s "$orig" "$file"; then
            printf '%-8s ABORT: byte-identical file -- the anchor is gone, not the mutant\n' "$name"
            return 1
        fi
    fi
    if [ "$runner" = py ]; then
        python3 "$PYTEST" > "$WORK/$name.out" 2>&1
    else
        lua5.1 tests/run_tests.lua "$LUATEST" > "$WORK/$name.out" 2>&1
    fi
    local rc=$?                            # bare, no pipe
    local verdict=GREEN
    [ "$rc" -ne 0 ] && verdict=RED
    if [ "$verdict" = "$expect" ]; then
        case "$name" in CONTROL|CTRLLUA) : ;; *) caught=$((caught + 1)) ;; esac
        printf '%-8s %-5s (expected %-5s) %s   %s\n' "$name" "$verdict" "$expect" \
            "$(case "$name" in CONTROL|CTRLLUA) echo 'control_ok' ;; *) echo 'CAUGHT   ' ;; esac)" \
            "$(head -2 "$WORK/$name.out" | tail -1)"
    else
        case "$name" in CONTROL|CTRLLUA) : ;; *) survived=$((survived + 1)) ;; esac
        printf '%-8s %-5s (expected %-5s) *** SURVIVED ***\n' "$name" "$verdict" "$expect"
        sed 's/^/           /' "$WORK/$name.out"
    fi
}

printf '=== mutation stand: gated-getter stub census ===\n'
printf 'work %s   backups %s\n\n' "$WORK" "$BAK"

run_case CONTROL "$CEN" GREEN py ""
run_case CTRLLUA "$CEN" GREEN lua ""

# M1 -- THE DEFECT ITSELF, replayed.  strip_comments blanks string literals as
# well, so `IsSoakCandidate('pulllane')` stops containing its own id and the
# census prints `gate-sites 0 ... ids-with-STUB0 0` for every armed id.  If this
# survives, an empty answer from this tool means nothing.
run_case M1 "$CEN" RED py '
a = "        out.append(line if cut == -1 else line[:cut] + \x27 \x27 * (len(line) - cut))"
assert a in s, "M1 anchor missing"
s = s.replace(a, "        line = STR_RE.sub(\"\x27\x27\", line)\n" + a, 1)'

# M2 -- THE SECOND DEFECT, replayed: truncate instead of pad, so every offset
# after a comment shifts and gate sites fall outside their own function spans.
# The census then blames the corpus (`18 outside any top-level fn`).
run_case M2 "$CEN" RED py '
a = "line[:cut] + \x27 \x27 * (len(line) - cut)"
assert a in s, "M2 anchor missing"
s = s.replace(a, "line[:cut]", 1)'

# M3 -- the call-form split removed: every `J.GetManaCost` / `X.GetOne` is
# priced as an engine getter again (30+ rows of confident nonsense).
run_case M3 "$CEN" RED py '
a = "    if prev == \x27:\x27:\n        return \x27METHOD\x27"
assert a in s, "M3 anchor missing"
s = s.replace(a, "    if True:\n        return \x27METHOD\x27", 1)'

# M4 -- the dotted spec shape dropped from loader_map, so `sp.GetCastRange =
# function` is unseen and GetCastRange reads STUB0.  That is a FALSE finding on
# the very getter §GD spent a round on, in the direction that invents debt.
run_case M4 "$CEN" RED py '
a = "    for m in re.finditer(r\"\\b\\w+(?:\\[[^\\]]*\\])?\\s*\\.\\s*(Get[A-Za-z0-9_]+)\\s*=\", body):\n        served.add(m.group(1))\n"
assert a in s, "M4 anchor missing"
s = s.replace(a, "", 1)'

# M5 -- handle_getters dropped: GetAttackTarget reads STUB0 although the mock
# answers nil.  A control asserting `== 0` on it would then fail for the wrong
# reason, which is exactly why the census reads that table instead of guessing.
run_case M5 "$CEN" RED py '
a = "    hg = re.search(r\"local\\s+handle_getters\\s*=\\s*\\{(.*?)\\}\", api, re.S)"
assert a in s, "M5 anchor missing"
s = s.replace(a, "    hg = None", 1)'

# M6 -- NILGLOB collapsed into SERVED: an engine global the mock never installs
# (it is nil, and calling it RAISES) is reported as answered.
run_case M6 "$CEN" RED py '
a = "        return \x27SERVED\x27 if name in mock_globals else \x27NILGLOB\x27"
assert a in s, "M6 anchor missing"
s = s.replace(a, "        return \x27SERVED\x27", 1)'

# M7 -- THE LOAD-BEARING ONE FOR THE CONTROL.  Move the catch-all off 0.  If the
# Lua control stays green here it is not reading the loader at all, and the
# census would be resting on a grep -- the exact substitution §GD..§GF cost four
# rounds.
run_case M7 "$MOCK" RED lua '
a = "    if key:find(\x27^Get\x27) then return 0 end"
assert a in s, "M7 anchor missing"
s = s.replace(a, "    if key:find(\x27^Get\x27) then return 7 end", 1)'

printf '\n%d CAUGHT / %d SURVIVED   (source restored + verified on exit)\n' \
    "$caught" "$survived"
[ "$survived" -eq 0 ] || exit 3
