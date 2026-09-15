#!/usr/bin/env bash
# Mutation stand for tests/test_waitclar_callsite_empty.lua (strategy charter
# 0NEXT22; the dead host of soak candidate 'waitclar').
#
# WHY THIS STAND IS NOT OPTIONAL HERE.  Every assertion in the test under it is
# a statement about SOURCE TEXT, and a source-text assertion is the easiest kind
# to write so that it can never go red -- a needle with a typo, or a stripper
# that eats the code it was meant to search, both read as "zero call sites" and
# both look exactly like the finding.  The finding is that a counter reads zero;
# the stand is what separates that from a counter that cannot read.
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1).  Each leg first proves the edit LANDED with
# grep -c, then runs the test; an edit that did not land is reported NO-OP -- a
# failure of the stand, not a pass of the code.
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.
#
# ⚠ MUTANTS ARE ANCHORED ON LEADING WHITESPACE, not on a line tail (0NEXT22 酉).
# The header of the test under this stand QUOTES the commented call site
# verbatim, so a pattern matching only `-- if ConsiderWaitInBaseToHeal()` is
# ambiguous between the code file and nothing else -- but the same class of
# accident is one edit away, and every leg below also checks WHICH case caught
# it (`check`'s 6th argument) rather than only red/green.
#
# Usage: bash tools/agent/mutstand_waitclar_callsite.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

ROAM=bots/mode_roam_generic.lua
BAK=$(mktemp)
OUT=$(mktemp)
cp "$ROAM" "$BAK"
SUM=$(sha256sum "$ROAM")

restore() {
    cp "$BAK" "$ROAM"
    if [ "$(sha256sum "$ROAM")" != "$SUM" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

# $1 name  $2 needle  $3 wanted grep -c  $4 CAUGHT|SURVIVED
# $5 (optional) substring the failure output MUST contain -- i.e. WHICH case
#    caught it.  Without it a mutant can be "caught" by an unrelated assertion
#    and the leg still reads green.
check() {
    local name="$1" needle="$2" want="$3" expect="$4" by="${5:-}"
    local got
    got=$(grep -c -- "$needle" "$ROAM")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua waitclar_callsite_empty >"$OUT" 2>&1; then
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: SURVIVED -- the suite is green on a mutant"
            fails=$((fails + 1))
        else
            echo "  $name: SURVIVED (as intended -- control)"
        fi
    else
        if [ "$expect" != "CAUGHT" ]; then
            echo "  $name: RED -- the control mutant went red, so at least one"
            echo "        assertion is keyed to something it should not be"
            fails=$((fails + 1))
        elif [ -n "$by" ] && ! grep -qF -- "$by" "$OUT"; then
            echo "  $name: CAUGHT BY THE WRONG CASE -- expected a failure"
            echo "        naming '$by'; got:"
            grep -m3 -- '^FAIL' "$OUT" | sed 's/^/          /'
            fails=$((fails + 1))
        else
            echo "  $name: CAUGHT"
        fi
    fi
    restore
}

echo "== mutation stand: waitclar call-site emptiness =="

# M1  THE FINDING, INVERTED: the call site is put back into code.  This is the
#     one mutant that matters most, because it is not a defect -- it is the
#     future in which 'waitclar' becomes readable.  If the test cannot see it,
#     the test cannot tell "nothing calls this" from "I cannot count calls",
#     and the tripwire half of the file is decoration.
sed -i 's|^\t-- if ConsiderWaitInBaseToHeal()|\tif ConsiderWaitInBaseToHeal() then end -- MUT1|' "$ROAM"
check "M1 the call site is re-enabled" "MUT1" 1 CAUGHT \
      "expected exactly 1 live mention of ConsiderWaitInBaseToHeal"

# M2  The commented call site is DELETED outright.  The function is then dead
#     with no trace of ever having been called, which is a different finding
#     with a different disposition (delete the function and the lever, rather
#     than wait for the call to come back), so the file must not keep reporting
#     the old one.
sed -i 's|^\t-- if ConsiderWaitInBaseToHeal()|\t-- MUT2 deleted|' "$ROAM"
check "M2 the commented call site is deleted" "MUT2" 1 CAUGHT \
      "the commented call site is gone"

# M3  A SECOND live 'waitclar' gate appears.  That is the 'pullcad' shape -- two
#     gate points for one id -- and it also means §4's "the gate is inside the
#     dead function" no longer describes the whole lever.
sed -i "12a local _mutGate = J.IsSoakCandidate('waitclar') -- MUT3" "$ROAM"
check "M3 a second gate point for the same id" "MUT3" 1 CAUGHT \
      "expected exactly one live 'waitclar' gate"

# M4  The gate is MOVED OUT of the dead function: the one inside is neutered and
#     a live one appears at file scope.  The count stays at one, so only the
#     POSITION assertion can see this -- and position is the entire finding,
#     because a gate outside the dead host is a gate that can fire.
sed -i "s|^\t\t\tand not (J.IsSoakCandidate('waitclar')|\t\t\tand not (false -- MUT4A|" "$ROAM"
sed -i "12a local _mutGate = J.IsSoakCandidate('waitclar') -- MUT4B" "$ROAM"
check "M4 the gate is moved outside the dead function" "MUT4B" 1 CAUGHT \
      "outside"

# M5  The flag gains a SECOND writer.  `ShouldWaitInBaseToHeal = true` from live
#     code would make the "Heal in Base" consumer branch reachable again while
#     the call site stayed commented -- i.e. §1 would still be green and §3 is
#     the only thing standing between that and a stale claim.
sed -i "12a ShouldWaitInBaseToHeal = true -- MUT5" "$ROAM"
check "M5 the flag gains a live writer" "MUT5" 1 CAUGHT \
      "expected exactly one \`ShouldWaitInBaseToHeal = true\`"

# M6  A long-bracket comment appears in the file.  strip_comments() handles line
#     comments only, so from this point every count in the test is unsound --
#     and unsound in the silent direction, since an unstripped block reads as
#     code.  §0 exists so that this is a red rather than a wrong number.
sed -i "12a --[[ MUT6 ]]" "$ROAM"
check "M6 a long-bracket comment defeats the stripper" "MUT6" 1 CAUGHT \
      "long-bracket comment"

# M7  The stripper's own CONTROL is removed: the live Tinker call at ~126 is
#     commented out.  Nothing about 'waitclar' changed, but the test's only
#     evidence that strip_comments() does not eat code has gone -- so the leg
#     that proves the counter is not blind must be the one that fires.
sed -i 's|^\tTinkerShouldWaitInBaseToHeal = TinkerWaitInBaseAndHeal()|\t-- MUT7 TinkerShouldWaitInBaseToHeal = TinkerWaitInBaseAndHeal()|' "$ROAM"
check "M7 the stripper's live control is commented out" "MUT7" 1 CAUGHT \
      "strip_comments() is eating code"

# M8  CONTROL.  A comment-only edit inside the 2026-09-06 block, on a line no
#     needle in the test names.  It must SURVIVE: a red here means an assertion
#     is keyed to prose rather than to code or to a measurement.
sed -i 's|^\t\t\t-- \[waitclar / owner priority P2, 2026-09-06\] The leg above this one|\t\t\t-- [waitclar / owner priority P2, 2026-09-06] (control edit) The leg above|' "$ROAM"
check "M8 CONTROL comment-only edit" "control edit" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "== all mutants CAUGHT, control SURVIVED =="
    exit 0
fi
echo "== $fails leg(s) failed =="
exit 1
