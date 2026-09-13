#!/usr/bin/env bash
# Mutation stand for the rule 6 push-gate memo (director 2026-09-13).
#
# WHAT IT IS DEFENDING.  The memo lets the SECOND push of an identical tree
# skip the three legs.  Every way it can be wrong points the same direction:
# it answers "green" for a tree nobody measured, and it does so QUIETLY, in a
# banner whose whole job is to look reassuring.  That is RULE6_BYPASS without
# the typing and without the line you are supposed to quote -- strictly worse
# than the escape hatch it exists to keep people out of.
#
# A guard whose failure mode is a clean pass must be SHOWN to redden.
#
# The mutants are not invented.  M1-M3 are the three fail-closed rules
# rule6_memo.py is written around, each removed (dirty tree ignored; the base
# dropped from the key; a found record trusted instead of re-checked).  M4 is
# the pipe hazard this repo has misread 33 times, now live in this hook because
# `tee` was added to capture the readings.  M5 is the escape hatch going dead.
#
# DISCIPLINE (evidence-discipline rules 1-3; GH #418 restore family):
#   * pristine copies live OUTSIDE the temp dir the trap wipes; the trap is
#     armed BEFORE the first mutant; the run ends on a sha256 manifest;
#   * every mutant is `cmp`-checked, so a no-op edit cannot score as a mutant;
#   * exit codes are read BARE -- no pipe between the runner and `$?`.
#
# Usage: bash tools/agent/mutstand_rule6_memo.sh
set -u
cd "$(dirname "$0")/../.."

MEMO=tools/agent/rule6_memo.py
HOOK=.githooks/pre-push
PYTEST=tests/test_rule6_memo.py

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BAK=$(mktemp -d "${TMPDIR:-/tmp}/mutbak.XXXXXX")     # NOT the dir the trap wipes
cp "$MEMO" "$BAK/memo.orig"
cp "$HOOK" "$BAK/hook.orig"
START_MEMO=$(sha256sum "$MEMO" | cut -d' ' -f1)
START_HOOK=$(sha256sum "$HOOK" | cut -d' ' -f1)
sha256sum "$MEMO" "$HOOK" > "$BAK/manifest.sha256"

restore() {
    cp "$BAK/memo.orig" "$MEMO"
    cp "$BAK/hook.orig" "$HOOK"
    chmod +x "$HOOK"
    if ! sha256sum -c --quiet "$BAK/manifest.sha256"; then
        printf 'FATAL: restore did not verify -- the tree may hold a mutant\n' >&2
        exit 9
    fi
}
trap 'restore; rm -rf "$WORK"' EXIT
restore                                   # prove the manifest before mutating

caught=0
survived=0

# run_case <name> <expect RED|GREEN> <target file> <python-mutator on $TARGET>
run_case() {
    local name="$1" expect="$2" target="${3:-}" mut="${4:-}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$target" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
$mut
open(p, 'w', encoding='utf-8').write(s)
PY
        local orig="$BAK/memo.orig"
        [ "$target" = "$HOOK" ] && orig="$BAK/hook.orig"
        if cmp -s "$orig" "$target"; then
            printf '%-8s ABORT: byte-identical file -- the anchor is gone, not the mutant\n' "$name"
            return 1
        fi
        chmod +x "$HOOK"
    fi
    python3 "$PYTEST" > "$WORK/$name.out" 2>&1
    local rc=$?                            # bare, no pipe
    local verdict=GREEN
    [ "$rc" -ne 0 ] && verdict=RED
    if [ "$verdict" = "$expect" ]; then
        if [ "$name" = CONTROL ]; then
            printf '%-8s %-5s (expected %-5s) control_ok   %s\n' "$name" "$verdict" \
                "$expect" "$(tail -3 "$WORK/$name.out" | head -1)"
        else
            caught=$((caught + 1))
            printf '%-8s %-5s (expected %-5s) CAUGHT       %s\n' "$name" "$verdict" \
                "$expect" "$(grep -m1 'FAIL' "$WORK/$name.out")"
        fi
    else
        [ "$name" = CONTROL ] || survived=$((survived + 1))
        printf '%-8s %-5s (expected %-5s) *** SURVIVED ***\n' "$name" "$verdict" "$expect"
        sed 's/^/           /' "$WORK/$name.out"
    fi
}

printf '=== mutation stand: rule 6 push-gate memo ===\n'
printf 'work %s   backups %s\n\n' "$WORK" "$BAK"

run_case CONTROL GREEN "" ""

# M1 -- THE DIRTY-TREE REFUSAL REMOVED.  The legs lint and run what is on
# DISK; the tree sha names what is in the COMMIT.  Drop this and a memo taken
# on a clean tree answers for an edited one -- the fail-open with the widest
# everyday reach, since a mid-round edit between the two pushes is ordinary.
run_case M1 RED "$MEMO" '
a = """    if dirty.strip():"""
assert a in s, "M1 anchor missing"
s = s.replace(a, """    if False:""", 1)'

# M2 -- `origin/main` DROPPED FROM THE KEY *AND* FROM THE RECORD CHECK.  The
# Lua leg scopes itself with `git diff origin/main...HEAD`, so a moved base is
# a larger changed-set: a different question.
#
# ⚠️ WHY BOTH HALVES.  The first cut of this mutant removed the base from the
# KEY only, and it SURVIVED -- correctly: the record check reads the base back
# off the stored entry and misses anyway, so dropping it from the key costs a
# cache slot and nothing else.  Two independent layers is the design; a mutant
# that removes one of them is an EQUIVALENT mutant, not an escaped defect, and
# scoring it as caught would have credited the test for work the other layer
# was doing.  The real fail-open needs both gone, and that is this mutant.
run_case M2 RED "$MEMO" '
a = """    raw = "rule6-memo-v1\\ntree=%s\\nbase=%s\\n" % (inputs["tree"], inputs["base"])"""
assert a in s, "M2 anchor missing (key half)"
s = s.replace(a, """    raw = "rule6-memo-v1\\ntree=%s\\n" % (inputs["tree"],)""", 1)
b = """    if rec.get("tree") != inputs["tree"] or rec.get("base") != inputs["base"]:"""
assert b in s, "M2 anchor missing (record half)"
s = s.replace(b, """    if rec.get("tree") != inputs["tree"]:""", 1)'

# M3 -- A FOUND RECORD TRUSTED INSTEAD OF RE-CHECKED.  The key is a hash, so
# "the file is here" is not "the file is about this tree" -- a truncated key, a
# hand-copied memo dir or a hash collision all land here.  Re-reading the two
# fields off the record costs nothing and is the difference between finding and
# verifying.
run_case M3 RED "$MEMO" '
a = """    if rec.get("tree") != inputs["tree"] or rec.get("base") != inputs["base"]:
        return 1"""
assert a in s, "M3 anchor missing"
s = s.replace(a, """    if False:
        return 1""", 1)'

# M4 / M6 -- THE PIPE HAZARD, LIVE, ON THE TWO LEGS THAT HAVE NO SECOND
# OPINION.  `tee` was added to this hook to capture the readings, which puts a
# pipe on the path for the first time; `tee` succeeds essentially always, so a
# leg read with `$?` reads GREEN off a RED gate and pushes it.  Iron rule 3's
# 34th shape, and the only defect here that the memo INTRODUCES rather than
# fails to prevent.
#
# ⚠️ NOT MUTATED: leg 1's `rc=${PIPESTATUS[0]}`.  It is an EQUIVALENT mutant --
# luacheck_gate.sh prints its own exit code as `GATE_EXIT=`, the hook compares
# the two and refuses on a disagreement, so `$?` there still refuses a red
# push. Leg 1 was the first cut of this mutant and it survived for exactly that
# reason. Legs 2 and 3 print no exit code and have nothing to cross-check,
# which is why the failure that matters lives here and why tests/ now reddens
# each leg separately.
run_case M4 RED "$HOOK" '
a = """    lrc=${PIPESTATUS[0]}   # NOT $? -- see the note on leg 1"""
assert a in s, "M4 anchor missing"
s = s.replace(a, """    lrc=$?""", 1)'

run_case M6 RED "$HOOK" '
a = """    prc=${PIPESTATUS[0]}   # NOT $? -- see the note on leg 1"""
assert a in s, "M6 anchor missing"
s = s.replace(a, """    prc=$?""", 1)'

# M5 -- THE ESCAPE HATCH GOES DEAD.  RULE6_NO_MEMO=1 is how anyone buys a
# second INDEPENDENT reading of the same tree; if it silently no-ops, the memo
# becomes unfalsifiable from the outside, which is the state a caching layer
# must never be allowed to reach.
run_case M5 RED "$HOOK" '
a = """if [ "${RULE6_NO_MEMO:-}" != "1" ]; then"""
assert a in s, "M5 anchor missing"
s = s.replace(a, """if true; then""", 1)'

restore
END_MEMO=$(sha256sum "$MEMO" | cut -d' ' -f1)
END_HOOK=$(sha256sum "$HOOK" | cut -d' ' -f1)
restored=1
[ "$START_MEMO" = "$END_MEMO" ] || restored=0
[ "$START_HOOK" = "$END_HOOK" ] || restored=0

printf '\n%d CAUGHT / %d SURVIVED / control_ok=1 / restored=%d\n' \
    "$caught" "$survived" "$restored"
[ "$survived" -eq 0 ] && [ "$restored" -eq 1 ] && exit 0
exit 1
