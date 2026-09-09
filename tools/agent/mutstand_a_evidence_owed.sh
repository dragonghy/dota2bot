#!/usr/bin/env bash
# Mutation stand for the condition-(a) obligation leg (director 2026-09-09,
# GH #540's general half).
#
# WHAT IT IS DEFENDING.  This leg is the thing that raises a hand when NOTHING
# is asking for an armed id's condition-(a) evidence.  Every way it can be
# wrong makes it print a cleaner, quieter answer -- fewer UNOWED rows, exit 0
# -- and exit 0 here is the exact sentence 40 armed ids hid behind for 13 days
# (GH #540's measurement).  A leg whose failure mode is silence must be shown
# to redden, not asserted to.
#
# The mutants are not invented.  M1 and M2 are the two simplifications this
# tool was deliberately NOT written with (count `retired` as coverage; treat an
# unreadable registry as empty), M3 is the ordering slip that would report a
# verified id as owing evidence, M4 is dropping the second coverage form, and
# M5 is the one that matters most: findings that print but do not reach the
# exit code, which is how a selfcheck leg becomes decoration.
#
# DISCIPLINE (evidence-discipline rules 1-3; GH #418 restore family):
#   * the pristine copy lives OUTSIDE the temp dir the trap wipes, the trap is
#     armed BEFORE the first mutant, and the run ends on a sha256 manifest;
#   * every mutant is `cmp`-checked, so a no-op edit cannot score as a mutant;
#   * exit codes are read BARE -- no pipe between the runner and `$?`.
#
# Usage: bash tools/agent/mutstand_a_evidence_owed.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/agent/a_evidence_owed.py
PYTEST=tests/test_a_evidence_owed.py

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BAK=$(mktemp -d "${TMPDIR:-/tmp}/mutbak.XXXXXX")     # NOT the dir the trap wipes
cp "$TOOL" "$BAK/tool.orig"
sha256sum "$TOOL" > "$BAK/manifest.sha256"

restore() {
    cp "$BAK/tool.orig" "$TOOL"
    if ! sha256sum -c --quiet "$BAK/manifest.sha256"; then
        printf 'FATAL: restore did not verify -- the tree may hold a mutant\n' >&2
        exit 9
    fi
}
trap 'restore; rm -rf "$WORK"' EXIT
restore                                   # prove the manifest before mutating

caught=0
survived=0

# run_case <name> <expect RED|GREEN> <python-mutator on $TOOL>
run_case() {
    local name="$1" expect="$2" mut="${3:-}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$TOOL" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
$mut
open(p, 'w', encoding='utf-8').write(s)
PY
        if cmp -s "$BAK/tool.orig" "$TOOL"; then
            printf '%-8s ABORT: byte-identical file -- the anchor is gone, not the mutant\n' "$name"
            return 1
        fi
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

printf '=== mutation stand: condition-(a) obligation leg ===\n'
printf 'work %s   backups %s\n\n' "$WORK" "$BAK"

run_case CONTROL GREEN ""

# M1 -- RETIRED COUNTED AS COVERAGE.  The tempting simplification, and the one
# that lets the registry close its own case: `done_when: path_exists` judges
# that an artefact exists, not that a verdict appeared (pending_rulings
# LIMIT 11), so "retired and still no VERIFY line" is precisely the state this
# leg exists to shout about.
run_case M1 RED '
a = """    for row in registry.get("owed", []):"""
assert a in s, "M1 anchor missing"
s = s.replace(a, """    for row in (list(registry.get("owed", []))
                + list(registry.get("retired", []))):""", 1)'

# M2 -- AN UNREADABLE REGISTRY READ AS EMPTY.  This is the failure direction
# the whole file is about, one level up: a registry that cannot be parsed makes
# every armed id UNOWED, which at least is loud -- but the tempting `except:
# registry = {}` makes the leg answer a question it could not read.  Here the
# mutant is the quiet half: could-not-run becomes a clean run with no rows.
run_case M2 RED '
a = """    except Exception as exc:                                   # noqa: BLE001
        print("AEO_COULD_NOT_RUN: registry %s: %s" % (a.registry, exc),
              file=sys.stderr)
        return 2"""
assert a in s, "M2 anchor missing"
s = s.replace(a, """    except Exception:                                          # noqa: BLE001
        registry = {"owed": []}""", 1)'

# M3 -- PRECEDENCE INVERTED: coverage tested before the verdict.  An id that
# HAS its (a) verdict but also still carries an open row reads OWED, so the
# state "verdict bought, row not yet retired" is reported as debt.  Same
# direction as `verify_coverage`'s anchored-regex defect: the instrument
# manufactures the debt it then reports.
run_case M3 RED '
a = """        if r.get("verify"):
            state, why = "VERDICT", "%d VERIFY line(s)" % r["verify"]
        elif i in covered:"""
assert a in s, "M3 anchor missing"
s = s.replace(a, """        if i in covered:""", 1)'

# M4 -- THE SECOND COVERAGE FORM DROPPED.  `covers_ids` is how ONE row
# discharges several ids (a detector run answers every id in its own subject
# line).  Without it every such row is invisible and the leg demands one row
# per id -- which is the 40-hand-written-rows design GH #540 rejected.
run_case M4 RED '
a = """        explicit = row.get("covers_ids")"""
assert a in s, "M4 anchor missing"
s = s.replace(a, """        explicit = None""", 1)'

# M5 -- FINDINGS PRINT BUT DO NOT REACH THE EXIT CODE.  The leg still prints
# every UNOWED row; only `note $?` in routine_selfcheck.sh reads 0.  This is
# how a leg becomes decoration -- and it is invisible to anyone reading the
# output rather than the code, which is everyone.
run_case M5 RED '
a = """    if unowed:
        print("\\nFINDING: %d armed id(s) with neither a verdict nor an owed "
              "row." % len(unowed))
        return 3"""
assert a in s, "M5 anchor missing"
s = s.replace(a, """    if unowed:
        print("\\nFINDING: %d armed id(s) with neither a verdict nor an owed "
              "row." % len(unowed))
        return 0""", 1)'

printf '\n%d CAUGHT / %d SURVIVED\n' "$caught" "$survived"
[ "$survived" -eq 0 ] || exit 3
