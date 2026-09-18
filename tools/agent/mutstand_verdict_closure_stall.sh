#!/usr/bin/env bash
# Mutation stand for tools/agent/verdict_closure_stall.py (RULING 73 ⑧(b)).
#
# WHAT IT IS FOR.  The subject's healthy answer is `STALL 1 -- OK`, exit 0 --
# visually identical to a subject that cannot see anything.  This lab has paid
# for that three times (GH #171 SKIP-is-not-pass, GH #200 zero test bodies,
# RULING 72's 0.006s false green), so the cells that matter here are the ones
# where the SUITE must be RED.
#
#   M0  unmutated                          -> exit 0, 25 checks 0 failures
#   M1  anchor taken from REPORT NAMES     -> exit 1  (THE founding defect:
#                                                      23 rounds green)
#   M2  `判定完结 >= 1` requirement dropped -> exit 1  (an 入集 resets the stall)
#   M3  empty corpus answers 0 not exit 2  -> exit 1  (silence read as health)
#   M4  fuzzy stamp resolved LATEST        -> exit 1  (quiet side: under-counts)
#   M5  12-round threshold deafened        -> exit 1  (iron rule 9 never fires)
#
# ⭐ M1 is the load-bearing cell.  It is not a straw man: it is the reading the
# whole lab actually used for 23 rounds, and it is what a hurried author writes
# because report names are the easy corpus.  M2 is the one a CAREFUL author
# writes -- "the member string moved" sounds like the right anchor until you
# notice `test_set.md:142`, an admission that moved the string and closed no
# verdict.  M4 is the direction test: both resolutions are defensible in
# isolation, and only one of them can never hide a stall.
#
# Restore discipline (evidence-discipline skill): the subject is NEVER written.
# Each mutant is a COPY in a temp dir and the suite is pointed at it through
# VERDICT_CLOSURE_SUBJECT; the repo file's sha256 is compared before and after
# anyway, because "we never wrote it" is a claim and sha256 is a measurement.
#
# Read-only with respect to git, zero AWS, ~2s.

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 2

TOOL="tools/agent/verdict_closure_stall.py"
SUITE="tests/test_verdict_closure_stall.py"
WORK="$(mktemp -d /tmp/mutstand_verdict_closure.XXXXXX)"
sha256sum "$TOOL" > "$WORK/before.sha256"

cleanup() {
    local rc=$?
    rm -rf "$REPO/tools/agent/__pycache__"
    if sha256sum -c "$WORK/before.sha256" --status; then
        echo "RESTORE   ok ($TOOL byte-identical to the start; it was never written)"
    else
        echo "RESTORE   *** FAILED *** -- $TOOL CHANGED; inspect $WORK first"
        rc=2
    fi
    rm -rf "$WORK"
    exit $rc
}
trap cleanup EXIT

fail=0

cell() {   # cell <label> <expected-rc> <mutant-path>
    local label="$1" want="$2" subj="$3" rc
    VERDICT_CLOSURE_SUBJECT="$subj" python3 "$SUITE" > "$WORK/out.txt" 2>&1
    rc=$?
    if [ "$rc" -eq "$want" ]; then
        printf '%-42s exit %d  (want %d)  CAUGHT\n' "$label" "$rc" "$want"
    else
        printf '%-42s exit %d  (want %d)  *** SURVIVED ***\n' "$label" "$rc" "$want"
        sed -n '/checks,/,$p' "$WORK/out.txt" | head -6 | sed 's/^/    | /'
        fail=1
    fi
}

mutate() {  # mutate <name> <python-replacement-script>
    local name="$1" script="$2"
    cp "$TOOL" "$WORK/$name.py" || exit 2
    MUT="$WORK/$name.py" python3 -c "$script" || exit 2
    printf '%s' "$WORK/$name.py"
}

echo "=== mutation stand: verdict_closure_stall.py ==="
cell "M0  unmutated" 0 "$REPO/$TOOL"

# M1 -- the founding defect: anchor the stall on the newest REPORT NAME.
m1=$(mutate m1 '
import os
p=os.environ["MUT"]; s=open(p).read()
s=s.replace("    since = [n for t, n in stamps if t > inst]",
            "    inst = stamps[-1][0]\n    since = [n for t, n in stamps if t > inst]")
open(p,"w").write(s)')
cell "M1  anchor = newest report name" 1 "$m1"

# M2 -- drop the 判定完结 requirement: any member-string move counts.
m2=$(mutate m2 '
import os
p=os.environ["MUT"]; s=open(p).read()
s=s.replace("        if not c or int(c.group(1)) < 1:\n            continue",
            "        if False:\n            continue")
s=s.replace("        cand = (inst, int(c.group(1)), raw, n, fuzzy)",
            "        cand = (inst, int(c.group(1)) if c else 0, raw, n, fuzzy)")
open(p,"w").write(s)')
cell "M2  判定完结 requirement dropped" 1 "$m2"

# M3 -- an empty corpus answers 0 instead of refusing.
m3=$(mutate m3 '
import os
p=os.environ["MUT"]; s=open(p).read()
s=s.replace("    if not stamps:\n        return None, (", "    if False:\n        return None, (")
open(p,"w").write(s)')
cell "M3  empty corpus -> 0 stall" 1 "$m3"

# M4 -- resolve masked digits to the LATEST instant (the quiet side).
m4=$(mutate m4 '
import os
p=os.environ["MUT"]; s=open(p).read()
s=s.replace("        digits = \"\".join(c if c.isdigit() else \"0\" for c in raw)",
            "        digits = \"\".join(c if c.isdigit() else \"9\" for c in raw)")
open(p,"w").write(s)')
cell "M4  fuzzy stamp -> LATEST instant" 1 "$m4"

# M5 -- deafen iron rule 9's threshold.
m5=$(mutate m5 '
import os
p=os.environ["MUT"]; s=open(p).read()
s=s.replace("NAME_NOTICE = 12", "NAME_NOTICE = 999")
open(p,"w").write(s)')
cell "M5  12-round threshold deafened" 1 "$m5"

echo
if [ "$fail" -eq 0 ]; then
    echo "ALL MUTANTS CAUGHT (5/5) -- the suite is not vacuous."
else
    echo "*** A MUTANT SURVIVED *** -- suspect the assertion, not the mutant."
fi
exit "$fail"
