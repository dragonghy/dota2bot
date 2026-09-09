#!/usr/bin/env bash
# Mutation stand for the condition-(a) route census (director 2026-09-09, §GG).
#
# WHAT IT IS DEFENDING.  This census tells a director whether an unverified
# armed id should be WITHDRAWN (evidence unbuyable) or LEFT IN with a delivery
# debt.  Every way it can be wrong makes it print a cleaner, smaller, more
# confident answer -- more NO-CORPUS, more BUILD, more DELIVER -- and each of
# those reads as a decision the director is entitled to make.  So the mutants
# below are not invented: M1, M3 and M4 are three rules that were actually
# tried while writing it, each of which classified a real id wrongly, and M2 is
# the wave-record reader it was deliberately NOT written with.
#
# DISCIPLINE (evidence-discipline rules 1-3; GH #418 restore family):
#   * the pristine copy lives OUTSIDE the temp dir the trap wipes, the trap is
#     armed BEFORE the first mutant, and the run ends on a sha256 manifest;
#   * every mutant is `cmp`-checked, so a no-op edit cannot score as a mutant;
#   * exit codes are read BARE -- no pipe between the runner and `$?`.
#
# Usage: bash tools/agent/mutstand_a_evidence_route.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/agent/a_evidence_route.py
PYTEST=tests/test_a_evidence_route.py

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

printf '=== mutation stand: condition-(a) route census ===\n'
printf 'work %s   backups %s\n\n' "$WORK" "$BAK"

run_case CONTROL GREEN ""

# M1 -- THE RATCHET REMOVED.  With no wave records the census happily reports
# every armed id as NO-CORPUS, i.e. "no id in the test set has a corpus", which
# is a withdrawal recommendation for the whole set delivered as a clean run.
run_case M1 RED '
a = """            print("AER_COULD_NOT_RUN: no %s under %s -- every id would be "
                  "misclassified, and the misclassification looks like a "
                  "finished census" % (what, where), file=sys.stderr)
            return 2"""
assert a in s, "M1 anchor missing"
s = s.replace(a, "            pass", 1)'

# M2 -- MEMBERSHIP BY SUBSTRING instead of the arm_string field.  Wave records
# name withdrawn ids in prose ("REMOVED: `tpdead`, `wandlimbo`"), so this
# inflates `waves` for exactly the ids a ruling is about, and an id with a
# fabricated corpus can never read NO-CORPUS.
run_case M2 RED '
a = """    s = rec.get("arm_string")
    if not isinstance(s, str):
        return None
    return {x.strip() for x in s.split(",") if x.strip()}"""
assert a in s, "M2 anchor missing"
s = s.replace(a, """    blob = json.dumps(rec)
    return {w for w in re.findall(r"[A-Za-z0-9_]+", blob)}""", 1)'

# M3 -- SUBJECT rule loosened to head-anywhere.  This is the rule the census
# was first written with, and on the real tree it promotes `ownhalf` and
# `overchase` to DELIVER on the strength of `capmono_refusal.py` naming them as
# CONFOUNDERS -- two owed rows pointing at a tool that cannot answer them.
#      (anchored by index arithmetic, not by a literal: the assignment carries
#      regex escapes, and a backslash that has to survive bash -> heredoc ->
#      python is a mutant that silently stops anchoring.  It did, first run.)
run_case M3 RED '
end = s.index("subject_of(head)))") + len("subject_of(head)))")
start = s.rindex("subject = bool(", 0, end)
s = s[:start] + "subject = True" + s[end:]'

# M4 -- the head window opened to the whole file.  Every id that appears in a
# constant table or an argparse choices list downstream counts as an
# instrument, and BUILD becomes unreachable.
run_case M4 RED '
a = "HEAD_CHARS = 4000"
assert a in s, "M4 anchor missing"
s = s.replace(a, "HEAD_CHARS = 10 ** 9", 1)'

# M5 -- class PRECEDENCE inverted: corpus is tested before the verdict, so an
# id that HAS a condition-(a) verdict is reported as owing one.  This is the
# direction that manufactures debt, the same failure `verify_coverage`'s
# anchored regex had (26 of 59 verdicts invisible, one of them a BUGGY).
run_case M5 RED '
a = """        if verify.get(i):
            out[i] = "VERIFIED"
        elif not waves.get(i):"""
assert a in s, "M5 anchor missing"
s = s.replace(a, """        if not waves.get(i):""", 1)'

# M6 -- the partition assertion removed AND a class silently dropped from the
# counter, so the header under-reports while every row still prints.  A header
# that does not add up is the one line most likely to be quoted in a ruling.
run_case M6 RED '
a = """    counts = {k: 0 for k in ("VERIFIED", "NO-CORPUS", "DELIVER", "MENTION", "BUILD")}"""
assert a in s, "M6 anchor missing"
s = s.replace(a, """    counts = {k: 0 for k in ("VERIFIED", "NO-CORPUS", "DELIVER", "MENTION", "BUILD")}
    counts["MENTION"] = 0""", 1)
b = """    for i in ids:
        counts[cls[i]] += 1"""
assert b in s, "M6 second anchor missing"
s = s.replace(b, """    for i in ids:
        if cls[i] != "MENTION":
            counts[cls[i]] += 1""", 1)'

printf '\n%d CAUGHT / %d SURVIVED\n' "$caught" "$survived"
[ "$survived" -eq 0 ] || exit 3
