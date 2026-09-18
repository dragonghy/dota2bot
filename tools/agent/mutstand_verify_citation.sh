#!/usr/bin/env bash
# Mutation stand for the citation rule in the condition-(a) counter
# (director 2026-09-18; filed by the replay desk 15:42Z).
#
# WHAT IT IS DEFENDING.  `verify_coverage.py` is the ONLY counter for iron
# law 2's condition (a), and the defect this rule repairs ran in the dangerous
# direction: a report that QUOTED another document's VERIFY line scored it as
# a fresh verdict, so an id could read `verify>0, last_verdict=WORKING` on a
# round that made no judgement at all.  Ten of 191 matches on the live corpus
# were quotations; one of them inverted a verdict and one invented one.
#
# ⚠️ AND THE OBVIOUS FIX IS WORSE THAN THE BUG.  Every tempting widening of
# the rule -- test the paragraph, test the file, let a bare report path widen
# over a blockquote -- drops REAL verdicts, which manufactures condition-(a)
# debt and sends rounds back over finished work.  That is this file's own
# history twice over (the `^VERIFY` anchor, `episodes=(\S+)`).  So the stand
# carries mutants in BOTH directions: M1/M5 stop refusing, M2/M6 refuse too
# much, M3 keeps the arithmetic and hides it.
#
# DISCIPLINE (evidence-discipline rules 1-3):
#   * the pristine copy lives OUTSIDE the temp dir the trap wipes, the trap is
#     armed BEFORE the first mutant, and the run ends on a sha256 manifest;
#   * every mutant is `cmp`-checked, so a no-op edit cannot score as a mutant;
#   * exit codes are read BARE -- no pipe between the runner and `$?`.
#
# Usage: bash tools/agent/mutstand_verify_citation.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/agent/verify_coverage.py
PYTEST=tests/test_verify_coverage.py
# The sibling leg, mutated by M7.  It is in the stand because sharing a regex
# is not sharing a rule: this is where the same quotation, uncaught, stops an
# obligation instead of mis-printing a row.
TOOL2=tools/agent/a_evidence_route.py
PYTEST2=tests/test_a_evidence_route.py

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BAK=$(mktemp -d "${TMPDIR:-/tmp}/mutbak.XXXXXX")     # NOT the dir the trap wipes
cp "$TOOL" "$BAK/tool.orig"
cp "$TOOL2" "$BAK/tool2.orig"
sha256sum "$TOOL" "$TOOL2" > "$BAK/manifest.sha256"

restore() {
    cp "$BAK/tool.orig" "$TOOL"
    cp "$BAK/tool2.orig" "$TOOL2"
    if ! sha256sum -c --quiet "$BAK/manifest.sha256"; then
        printf 'FATAL: restore did not verify -- the tree may hold a mutant\n' >&2
        exit 9
    fi
}
trap 'restore; rm -rf "$WORK"' EXIT
restore                                   # prove the manifest before mutating

caught=0
survived=0

# run_case <name> <RED|GREEN> <mutator> [target file] [test to run]
run_case() {
    local name="$1" expect="$2" mut="${3:-}"
    local target="${4:-$TOOL}" pytest="${5:-$PYTEST}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$target" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
$mut
open(p, 'w', encoding='utf-8').write(s)
PY
        if cmp -s "$BAK/$(basename "$target")" "$target" 2>/dev/null \
           || { [ "$target" = "$TOOL" ] && cmp -s "$BAK/tool.orig" "$TOOL"; } \
           || { [ "$target" = "$TOOL2" ] && cmp -s "$BAK/tool2.orig" "$TOOL2"; }; then
            printf '%-8s ABORT: byte-identical file -- the anchor is gone, not the mutant\n' "$name"
            return 1
        fi
    fi
    python3 "$pytest" > "$WORK/$name.out" 2>&1
    local rc=$?                            # bare, no pipe
    local verdict=GREEN
    [ "$rc" -ne 0 ] && verdict=RED
    if [ "$verdict" = "$expect" ]; then
        if [ "$name" = CONTROL ]; then
            printf '%-8s %-5s (expected %-5s) control_ok   %s\n' "$name" "$verdict" \
                "$expect" "$(tail -1 "$WORK/$name.out")"
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

printf '=== mutation stand: citations are not verdicts ===\n'
printf 'work %s   backups %s\n\n' "$WORK" "$BAK"

run_case CONTROL GREEN ""

# M1 -- THE RULE REMOVED.  The pre-fix tool exactly: every quoted VERIFY string
# counts, and the quoting round owns it.  This is the state that read `ownhalf
# verify=7 last_verdict=WORKING` off a round whose own text says it judged
# nothing.
run_case M1 RED '
a = "            if CITED_RE.search(line) or in_owed_quote(lines, idx):"
assert a in s, "M1 anchor missing"
s = s.replace(a, "            if False:", 1)'

# M2 -- THE WIDENING LET OFF ITS LEASH.  The tidy simplification: one regex for
# both tests, so a bare report path widens over a whole blockquote.  This
# desk's summary head IS a blockquote and routinely names other reports, so
# every verdict stated in a summary head silently stops counting -- the
# under-count direction, wearing a bugfix.
run_case M2 RED '
a = "    return bool(OWED_QUOTE_RE.search"
assert a in s, "M2 anchor missing"
s = s.replace(a, "    return bool(CITED_RE.search", 1)'

# M3 -- THE ARITHMETIC KEPT, THE DISCLOSURE DROPPED.  Refusals still happen and
# nothing says so.  A count nobody can see is a count nobody can dispute, and
# this tool has already been wrong three times in ways only a visible number
# would have caught.
run_case M3 RED '
a = """    print("not counted: %d citation(s), %d off-vocabulary token(s)"
          % (len(cited), len(offvocab)))"""
assert a in s, "M3 anchor missing"
s = s.replace(a, "", 1)'

# M4 -- THE HYPHEN BACK OUT OF THE VERDICT TOKEN.  `NOT-ARMED` truncates to
# `NOT`, a token in no charter vocabulary, and files it as a verdict.  Live
# corpus: 12 lines, all on ids outside the armed string -- invisible until the
# day one of them is armed.
run_case M4 RED '
a = "verdict=([A-Z]+(?:-[A-Z]+)*)"
assert a in s, "M4 anchor missing"
s = s.replace(a, "verdict=([A-Z]+)", 1)'

# M5 -- OFF-VOCABULARY TOKENS COUNTED ANYWAY.  The parse is fixed but the
# classification is not, so `NOT-ARMED` becomes a verdict with a full row.  M4
# and M5 are separate failures of the same line and neither implies the other.
run_case M5 RED '
a = "            if verdict not in VERDICT_VOCAB:"
assert a in s, "M5 anchor missing"
s = s.replace(a, "            if False:", 1)'

# M6 -- FILE SCOPE INSTEAD OF ROW SCOPE.  The other over-broad reading, and the
# one measured before adoption: block scope flagged 27 of 191 matches on the
# live corpus and 17 of those were real verdicts whose paragraph merely named a
# corpus path.  File scope is strictly worse.
run_case M6 RED '
a = "            if CITED_RE.search(line) or in_owed_quote(lines, idx):"
assert a in s, "M6 anchor missing"
s = s.replace(a, "            if CITED_RE.search(text) or in_owed_quote(lines, idx):", 1)'

# M7 -- THE RULE NOT REACHING THE SIBLING LEG.  `a_evidence_route.py` reverts
# to the bare regex: the census prints the refusal and the obligation leg,
# reading the same corpus one import away, still counts the quotation and lets
# the demand for the evidence retire.  This is the mutant that says whether the
# fix is a rule or just a loop in one file.
run_case M7 RED '
a = "        for _lineno, wid, verdict, _eps in VC.scan_report(text)[0]:"
assert a in s, "M7 anchor missing"
s = s.replace(a, """        _seen = set()
        for m in VC.VERIFY_RE.finditer(text):
            wid, verdict = m.group(1), m.group(2)
            if (wid, verdict, m.group(3)) in _seen:
                continue
            _seen.add((wid, verdict, m.group(3)))""", 1)' "$TOOL2" "$PYTEST2"

printf '\n%d CAUGHT / %d SURVIVED\n' "$caught" "$survived"
[ "$survived" -eq 0 ] || exit 3
