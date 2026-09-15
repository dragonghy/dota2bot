#!/usr/bin/env bash
# Mutation stand for tests/test_siegecap_ancient_roster.lua (strategy charter
# 0NEXT21; soak candidate 'siegecap').
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP -- a failure of the
# stand, not a pass of the code.
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.  sha256sum rather than `git diff --quiet`: this stand runs mid-work,
# and a git comparison reports DIRTY for every uncommitted line under test.
#
# ⚠ Run it SERIALLY with anything else that touches bots/Customize/soak_side.lua
# (开工自检's Lua leg, another mutation stand).  That path is one global inode;
# concurrent use presents as "the gate did not fire" (GH #229, GH #365 §3).
#
# ⚠ M7 is the leg that matters most here and it is checked by WHICH assertion
# fires, not only by red/green: this lever's answer cannot move on today's
# corpus (nothing stands inside the alarm's 3000u ring), so a stand that only
# read the exit code would be satisfied by the source pins alone and would never
# notice that the behavioural half had stopped observing anything.
#
# Usage: bash tools/agent/mutstand_siegecap.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

FARM=bots/mode_farm_generic.lua
RUNE=bots/mode_rune_generic.lua
BAKF=$(mktemp)
BAKR=$(mktemp)
OUT=$(mktemp)
cp "$FARM" "$BAKF"
cp "$RUNE" "$BAKR"
SUMS=$(sha256sum "$FARM" "$RUNE")

restore() {
    cp "$BAKF" "$FARM"
    cp "$BAKR" "$RUNE"
    if [ "$(sha256sum "$FARM" "$RUNE")" != "$SUMS" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

# $1 name  $2 file  $3 needle  $4 wanted grep -c  $5 CAUGHT|SURVIVED
# $6 (optional) substring the failure output MUST contain -- i.e. WHICH case
#    caught it.  Without this a mutant can be "caught" by an unrelated
#    assertion and the leg still reads green.
check() {
    local name="$1" file="$2" needle="$3" want="$4" expect="$5" by="${6:-}"
    local got
    got=$(grep -c -- "$needle" "$file")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua siegecap_ancient_roster >"$OUT" 2>&1; then
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
            grep -m3 '^FAIL' "$OUT" | sed 's/^/          /'
            fails=$((fails + 1))
        else
            echo "  $name: CAUGHT"
        fi
    fi
    restore
}

echo "== mutation stand: siegecap =="

# M1  The lever is deleted: the roster quota is unconditional again.  The gate,
#     the id and the hoisted local all still read right to a wiring census; only
#     the behaviour is gone.  Behaviour-side this must be caught by the 3-vs-5
#     walk, because nothing else about the tree moved.
sed -i 's/if IsHeroAlive(id) and (bWholeRoster or i <= 3) then/if IsHeroAlive(id) and i <= 3 then -- MUT1/' "$FARM"
check "M1 lever deleted, quota unconditional" "$FARM" "MUT1" 1 CAUGHT \
      "the ARMED walk asked"

# M2  The gate is open for everybody: turbo conjunct AND soak id dropped.  The
#     widening still happens, so the 3-vs-5 walk stays green in its ARMED leg --
#     only the UNARMED leg and the [gate] source pins can see this.
sed -i "s/local bWholeRoster = J.IsModeTurbo() and J.IsSoakCandidate('siegecap')/local bWholeRoster = true -- MUT2/" "$FARM"
check "M2 gate always open" "$FARM" "MUT2" 1 CAUGHT

# M3  The turbo conjunct alone is dropped.  IsModeTurbo() is true on this
#     corpus, so NO behavioural leg can see it -- it is the [gate] source
#     assertion or nothing.  (That is the whole reason that assertion is not
#     prose; it is the M3 of the runecamp round, same shape.)
sed -i "s/local bWholeRoster = J.IsModeTurbo() and J.IsSoakCandidate('siegecap')/local bWholeRoster = J.IsSoakCandidate('siegecap') -- MUT3/" "$FARM"
check "M3 turbo conjunct dropped" "$FARM" "MUT3" 1 CAUGHT "turbo-only"

# M4  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'siegecap' alone the lever no-ops, and the day that second id is
#     promoted the conjunct is frozen false forever while a wiring census still
#     answers WIRED.
sed -i "s/local bWholeRoster = J.IsModeTurbo() and J.IsSoakCandidate('siegecap')/local bWholeRoster = J.IsModeTurbo() and J.IsSoakCandidate('siegecap') and J.IsSoakCandidate('campfarm') -- MUT4/" "$FARM"
check "M4 gate conditioned on a second id" "$FARM" "MUT4" 1 CAUGHT \
      "exactly one soak id"

# M5  The cap is removed OUTRIGHT -- the fix shipped ungated.  This is the
#     mutant that turns a dark lever into a live behaviour change in every
#     normal-mode game, and no behavioural leg can see it (armed and unarmed
#     both widen), so it is the [site] verbatim pin or nothing.
sed -i 's/if IsHeroAlive(id) and (bWholeRoster or i <= 3) then/if IsHeroAlive(id) then -- MUT5/' "$FARM"
check "M5 cap removed outright (ungated ship)" "$FARM" "MUT5" 1 CAUGHT \
      "the \`i <= 3\` cap is gone"

# M6  A clause the lever is NOT supposed to touch is loosened: the freshness
#     window goes 1.0s -> 5.0s.  On this corpus every sighting is current
#     (time_since_seen = 0), so no behavioural leg can see it either.
sed -i 's/and dInfo.time_since_seen < 1.0 then/and dInfo.time_since_seen < 5.0 then -- MUT6/' "$FARM"
check "M6 a clause the lever must not touch is loosened" "$FARM" "MUT6" 1 CAUGHT \
      "a clause the lever is not supposed to touch"

# M7  The call site "helps" the lever by widening the RING instead of the
#     roster: 3000 -> 6000.  It is the one edit that would make §5's tripwire
#     reading ("no corpus frame reaches 3000u") false while every other number
#     in the file still looked right.
#
#     ⚠ ANCHORED ON THE LEADING TAB, and that is not decoration.  The first
#     version of this leg matched on `3000)$` and landed in the HEADER COMMENT
#     (which quotes the call site, and unlike the code line does not end in a
#     space), so grep -c said the edit landed, nothing behavioural changed, and
#     the leg read SURVIVED.  0NEXT19 巳′, third sighting: a mutation located by
#     pattern is only unique in the tree it was written against, and the header
#     this very round added is what made that pattern ambiguous.
sed -i 's/^\tif X.IsUnitAroundLocation(GetAncient(GetTeam()):GetLocation(), 3000)/\tif X.IsUnitAroundLocation(GetAncient(GetTeam()):GetLocation(), 6000) -- MUT7/' "$FARM"
check "M7 the call-site ring is widened instead" "$FARM" "MUT7" 1 CAUGHT \
      "the one call site is no longer"

# M8  The SIBLING grows a cap of its own.  The header's whole "no policy is
#     invented, the tree already answers this" claim rests on
#     mode_rune_generic's copy being uncapped; if it stops being so, the
#     argument for this lever changes and the file must say so.
sed -i 's/^\tfor _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do$/\tfor i, id in pairs(GetTeamPlayers(GetOpposingTeam())) do if i <= 3 then -- MUT8/' "$RUNE"
check "M8 the uncapped sibling grows a cap" "$RUNE" "MUT8" 1 CAUGHT \
      "grew an \`i <= 3\` cap too"

# M9  CONTROL.  A comment-only edit inside the new header.  It must SURVIVE: if
#     the suite goes red here, some assertion is keyed to comment text rather
#     than to code, to a decision or to a measurement.
sed -i 's/^-- THE SITE\. This function has exactly ONE caller/-- THE SITE (control edit). This function has exactly ONE caller/' "$FARM"
check "M9 CONTROL comment-only edit" "$FARM" "control edit" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "== all mutants CAUGHT, control SURVIVED =="
    exit 0
fi
echo "== $fails leg(s) failed =="
exit 1
