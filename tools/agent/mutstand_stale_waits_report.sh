#!/usr/bin/env bash
# Mutation stand for the REPORT-vs-WAIT discriminator in `stale_waits.py`
# (GH #448).
#
# WHAT IT IS FOR.  `stale_waits.py` finds an expired wait by its text, and the
# text that RECORDS such a finding is shaped like the finding.  On
# 2026-09-03T07:0xZ the tool's only STALE was the director's own sentence
# describing the previous round's finding -- while the three real expired waits
# it had found were already fixed.  The repair is a discriminator; the danger of
# a discriminator is that the cheapest wrong one (always "this is only a
# record") makes the detector deaf and prints exit 0 while doing it -- the same
# clean line a working detector prints.  So the cells that matter are the ones
# where the SUITE must be RED.
#
#   M0  unmutated                         -> exit 0, 47 checks 0 failed
#   M1  discriminator constant TRUE       -> exit 1  (deaf: founding wait lost)
#   M2  discriminator constant FALSE      -> exit 1  (no exemption at all)
#   M3  location half alone (drop verb)   -> exit 1  (real wait citing a line)
#   M4  verb half alone (drop location)   -> exit 1  (real wait using 写着)
#   M5  `or` instead of `and`             -> exit 1  (both halves' fixtures)
#   M6  the PRE-FIX tool, same tests      -> exit 1  (the stand sees the defect)
#
# ⭐ M1 is the load-bearing cell: it is the mutation a hurried repair actually
# writes.  M3/M4 are what make the exemption a CONJUNCTION rather than a hatch --
# each proves one half is insufficient on its own, and a stand without them
# would call a one-half discriminator a pass.  M6 is the stand's self-proof: the
# same fixtures against the tool as it stood before this change must fail.
#
# Restore discipline (evidence-discipline skill): the mutated file is copied
# FIRST, `trap restore EXIT` is installed BEFORE the first apply, and the
# restore is verified with sha256 -- not with `git checkout`, which would also
# quietly revert unrelated work in the tree.
#
# Read-only with respect to git, zero AWS, ~5s.

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 2

TOOL="tools/agent/stale_waits.py"
SUITE="tests/test_stale_waits.py"
WORK="$(mktemp -d /tmp/mutstand_stale_waits_report.XXXXXX)"

cp "$TOOL" "$WORK/tool.py" || exit 2
sha256sum "$TOOL" > "$WORK/before.sha256"

restore() {
    local rc=$?
    cp "$WORK/tool.py" "$TOOL"
    rm -rf "$REPO/tools/agent/__pycache__"
    if sha256sum -c "$WORK/before.sha256" --status; then
        echo "RESTORE   ok ($TOOL byte-identical to the start)"
    else
        echo "RESTORE   *** FAILED *** -- inspect $WORK before doing anything else"
        rc=2
    fi
    exit $rc
}
trap restore EXIT

# The one expression the whole discriminator lives in.  Kept on one line in the
# tool precisely so this stand can rewrite it without touching anything else;
# if it ever stops matching, that is a finding about the tool, not about bash.
ORIG='    return bool(RE_LOCATION.search(scope)) and bool(RE_REPORT_VERB.search(scope))'

mutate() {  # mutate <replacement line>
    cp "$WORK/tool.py" "$TOOL"
    python3 - "$TOOL" "$ORIG" "$1" <<'PY'
import sys
path, orig, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path, encoding="utf-8").read()
if orig not in src:
    sys.stderr.write("MUTSTAND: anchor line not found in %s\n" % path)
    sys.exit(2)
open(path, "w", encoding="utf-8").write(src.replace(orig, new, 1))
PY
}

FAILS=0
cell() {  # cell <name> <want_exit> <must_contain...>
    local name="$1" want="$2"; shift 2
    local out rc
    rm -rf "$REPO/tools/agent/__pycache__"
    # No pipe between the command and `$?` (evidence discipline 3).
    out="$(python3 "$SUITE" 2>&1)"; rc=$?
    local bad=0
    [ "$rc" = "$want" ] || { bad=1; echo "  exit $rc, wanted $want"; }
    for needle in "$@"; do
        grep -qF -- "$needle" <<<"$out" || { bad=1; echo "  missing: $needle"; }
    done
    if [ "$bad" = 0 ]; then
        echo "$name  CAUGHT/OK   exit $rc"
    else
        echo "$name  *** SURVIVED/WRONG ***   exit $rc"
        FAILS=$((FAILS + 1))
        grep -E 'FAIL|checks,' <<<"$out" | sed -n '1,8p' | sed 's/^/      | /'
    fi
    cp "$WORK/tool.py" "$TOOL"
}

echo "=== M0  baseline, nothing mutated ==="
cell "M0 " 0 "checks, 0 failed"

echo "=== M1  discriminator constant TRUE (the cheap wrong repair) ==="
mutate '    return True'
cell "M1 " 1 "swallowed the founding expired admission wait" \
             "the report exemption leaked past its own clause"

echo "=== M2  discriminator constant FALSE (no exemption at all) ==="
mutate '    return False'
cell "M2 " 1 "a report ABOUT an expired wait"

echo "=== M3  location half alone -- the cited line becomes sufficient ==="
mutate '    return bool(RE_LOCATION.search(scope))'
cell "M3 " 1 "went silent because it cited a file and line"

echo "=== M4  verb half alone -- the reporting verb becomes sufficient ==="
mutate '    return bool(RE_REPORT_VERB.search(scope))'
cell "M4 " 1 "went silent because it used a reporting verb"

echo "=== M5  \`or\` instead of \`and\` -- both halves become sufficient ==="
mutate '    return bool(RE_LOCATION.search(scope)) or bool(RE_REPORT_VERB.search(scope))'
cell "M5 " 1 "went silent because it cited a file and line" \
             "went silent because it used a reporting verb"

echo "=== M6  the PRE-FIX tool (HEAD), read by the new fixtures ==="
git show HEAD:"$TOOL" > "$WORK/prefix_tool.py" 2>/dev/null
if [ -s "$WORK/prefix_tool.py" ] && ! grep -q 'def reports_elsewhere' "$WORK/prefix_tool.py"; then
    cp "$WORK/prefix_tool.py" "$TOOL"
    rm -rf "$REPO/tools/agent/__pycache__"
    out="$(python3 "$SUITE" 2>&1)"; rc=$?
    if [ "$rc" = 1 ] && grep -qF 'was read as a wait' <<<"$out"; then
        echo "M6  CAUGHT/OK   exit 1 (the pre-fix tool reads the report as a wait)"
    else
        echo "M6  *** WRONG ***   exit $rc, wanted 1 with 'was read as a wait'"
        FAILS=$((FAILS + 1))
    fi
    cp "$WORK/tool.py" "$TOOL"
else
    echo "M6  SKIPPED (HEAD's $TOOL already carries the discriminator) -- this is"
    echo "    a SKIP, not a pass: once this change lands, HEAD has the fix and the"
    echo "    comparison has to be made against the commit before it."
fi

echo
if [ "$FAILS" = 0 ]; then
    echo "MUTSTAND  all cells behaved as specified"
else
    echo "MUTSTAND  $FAILS cell(s) did NOT -- a surviving mutant means the"
    echo "          assertion, not the mutation, is what to suspect first"
fi
exit $((FAILS == 0 ? 0 : 3))
