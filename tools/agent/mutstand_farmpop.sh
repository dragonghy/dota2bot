#!/usr/bin/env bash
# Mutation stand for tests/test_farm_population_reachability.lua
# (strategy charter 0NEXT19).
#
# WHAT THIS STAND HAS TO PROVE, and why it is not optional here.  That test
# file's entire content is TWO ZEROS (no override hero in the drafter's pool, no
# frame of one in the corpus).  A zero is the one reading that a broken walk
# produces for free: a census that loads nothing, a name map that resolves
# nothing, a canonicaliser that matches nothing all answer "0" in the same
# voice as the truth does.  So every leg below makes the domain NON-empty in one
# specific way and requires the file to go red -- the direction a broken walk
# cannot fake.
#
# Mutants are applied to the SHIPPED artefacts (the pool file, the launcher, the
# mode script, a real fixture), never to copies (evidence-discipline rule 1).
# Each leg first proves the edit LANDED with `grep -c` against an expected
# COUNT, not merely a hit (0NEXT18 卯): "did an edit land" and "did THIS edit
# land" are different questions and only a count answers both.
#
# Restore is from byte copies taken before the first mutation and verified with
# sha256sum, so a stand that dies mid-run cannot leave a mutant in the tree.
#
# Usage: bash tools/agent/mutstand_farmpop.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

POOL=tools/batch_test/soak/hero_pool.txt
LOOP=tools/batch_test/soak/soak_loop.sh
LAN=bots/mode_laning_generic.lua
UTILS=bots/FunLib/utils.lua
FIX=tests/fixtures/f_011405_jak_rescue_axe.lua
FILES=("$POOL" "$LOOP" "$LAN" "$UTILS" "$FIX")

BAK=()
for f in "${FILES[@]}"; do
    b=$(mktemp); cp "$f" "$b"; BAK+=("$b")
done
SUMS=$(sha256sum "${FILES[@]}")

restore() {
    for i in "${!FILES[@]}"; do cp "${BAK[$i]}" "${FILES[$i]}"; done
    if [ "$(sha256sum "${FILES[@]}")" != "$SUMS" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

# check <name> <file> <landed-grep> <expect-count> <CAUGHT|SURVIVE>
check() {
    local name="$1" file="$2" needle="$3" want="$4" expect="$5"
    local got
    got=$(grep -c -- "$needle" "$file")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua test_farm_population_reachability >/dev/null 2>&1; then
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: SURVIVED -- the file is green on a mutant"
            fails=$((fails + 1))
        else
            echo "  $name: SURVIVED (as intended -- control)"
        fi
    else
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: CAUGHT"
        else
            echo "  $name: RED -- the control went red, so an assertion is keyed"
            echo "        to something it should not be"
            fails=$((fails + 1))
        fi
    fi
    restore
}

echo "== mutation stand: farm population reachability =="

# M1  THE HEADLINE MUTANT.  An override hero enters the drafter's pool, which is
#     precisely the day the ungated doorway stops being empty and the
#     BUNDLE-ONLY constraint on 'denyreach' / 'deepnum' may be lifted.  If this
#     survives, the file's central zero is decorative.
printf 'hoodwink,4/5,filler\n' >> "$POOL"
check "M1 override hero joins the soak pool" "$POOL" "^hoodwink," 1 CAUGHT

# M2  The same event seen from the other measurement: a corpus frame of an
#     override hero.  This is the leg that proves the corpus counter can SEE a
#     buggy hero at all -- without it, "0 frames" is indistinguishable from "the
#     name never had a bucket".
sed -i "s/name = 'npc_dota_hero_pudge'/name = 'npc_dota_hero_muerta'/" "$FIX"
check "M2 an override hero appears in the corpus" "$FIX" "npc_dota_hero_muerta" 1 CAUGHT

# M3  The human half.  Drop `-fill_with_bots` from the soak launcher and a human
#     slot becomes possible again, reopening J.IsPosxHuman(5) -- the second
#     ungated disjunct.  Nothing in the pool or the corpus changes, so ONLY the
#     launch leg can see it.
sed -i "s/-fill_with_bots/-fill_with_humans_please/" "$LOOP"
check "M3 launcher stops filling with bots" "$LOOP" "fill_with_humans_please" 1 CAUGHT

# M4  A FOURTH DISJUNCT on bCustomLastHit -- a new population, ungated, that
#     this file has not priced.  The pool and corpus zeros stay true and stay
#     irrelevant, which is exactly why the structural leg counts disjuncts
#     instead of trusting the two it knows about.
python3 - "$LAN" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index('local bCustomLastHit = ')
j = s.index('\n\n', i)
s = s[:j] + "\n\tor J.GetPosition(bot) == 4 -- MUT4" + s[j:]
open(p, 'w', encoding='utf-8').write(s)
PY
check "M4 bCustomLastHit grows an ungated disjunct" "$LAN" "MUT4" 1 CAUGHT

# M5  One of the four gated flags quietly loses its gate.  Same shape as M4 at a
#     different door: the Think becomes reachable without arming anything, and
#     no count of heroes or frames can see it.
sed -i "s/local bBodyBlock = J.IsModeTurbo() and J.IsSoakCandidate('bodyblock')/local bBodyBlock = J.IsModeTurbo() -- MUT5/" "$LAN"
check "M5 a gated flag loses its gate" "$LAN" "MUT5" 1 CAUGHT

# M6  The name map goes short: HeroName.Muerta stops resolving, so one of the
#     nine drops silently out of every count.  This is the GH #171 failure --
#     a missing key reading as a satisfied assertion -- and the reason the file
#     asserts the map's SIZE and resolves every name through it rather than
#     typing nine strings.
sed -i "s/\[HeroName.Muerta\] = true,/[HeroName.MuertaTypo] = true,/" "$UTILS"
check "M6 an override name stops resolving" "$UTILS" "HeroName.MuertaTypo" 1 CAUGHT

# M7  The pool shrinks by one hero.  Both the pool-size ratchet and the
#     corpus-IS-the-pool leg must see it: the corpus would then carry a hero the
#     drafter cannot draft, which is the drift that would quietly decouple the
#     two measurements from each other.
sed -i "/^sniper,/d" "$POOL"
check "M7 a hero leaves the drafter pool" "$POOL" "^sniper," 0 CAUGHT

# CONTROL  A comment line in the pool file.  Nothing about the population
#     changes, so a red here means an assertion is keyed to file bytes rather
#     than to the census it claims to take.
printf '# control: a comment, not a hero\n' >> "$POOL"
check "C  a comment line in the pool file" "$POOL" "^# control:" 1 SURVIVE

echo
if [ "$fails" -eq 0 ]; then
    echo "stand: OK (7 caught, control survived)"
    exit 0
fi
echo "stand: $fails leg(s) failed"
exit 1
