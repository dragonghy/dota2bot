#!/usr/bin/env bash
# Mutation stand for tests/test_mockscalar_return_shape.lua (test_set.md §EI).
#
# WHAT IT IS FOR. This round lands NO behaviour change: the whole product is a
# set of counts plus one ordering constraint ("repair `^Get` before `^Is`").
# A census whose headline is a comparison between two legs of the SAME sweep is
# the easiest kind of green to get for the wrong reason -- if the lifted leg
# quietly stops lifting anything, both legs agree, every assertion about
# "masked" is trivially satisfiable, and the file reads exactly as it does now.
# That is the same defect this file is ABOUT (a default that cancels another
# default), so it is also the way this file itself would fail. Hence a stand
# whose mutants are mostly INSTRUMENT mutants.
#
# The shapes under test:
#   * the blocker is REMOVED (M1, M2, M3) -- the mock stubs one of the three
#     non-scalar getters. That is the day the pricing expires, and the file must
#     go red saying "re-take it" rather than stay quietly green;
#   * the OTHER prefix rule is repaired first (M4) -- the exact move this file
#     exists to argue against. Four carriers must stop answering, and the test
#     must notice that they no longer answer TODAY, not only when lifted;
#   * a shipped consumption site is rewritten (M5, M6, M7) -- then the tree no
#     longer proves the return non-scalar, and the classification this pricing
#     rests on is inherited rather than re-derived;
#   * a carrier leaves the tree (M8) -- J.GetUltLoc's only caller goes away, so
#     "shipped, ungated, never answers" becomes a claim about dead code;
#   * the INSTRUMENT loses its lift (M9, M10) -- the lifted leg stops lifting,
#     or lifts the wrong units. Both make "masked" vacuous while every count
#     stays plausible;
#   * the INSTRUMENT folds three buckets back into two (M11) -- abstentions
#     counted as answers, which is GH #492's own defect re-committed;
#   * the exempt roster stops being parsed out of the mock (M12) -- then the
#     census subtracts a list it invented instead of the mock's real one.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_mockscalar.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (rule 2: suspect the
# assertion before the mutation -- and per its converse, read the diff first: a
# regex that misses prints NO-OP, a regex that hits the wrong place prints
# SURVIVED while the subject is untouched. That converse cost the midsupmirror
# stand two rounds on one `perl s///` without /g).
#
# SLOW ON PURPOSE: every mutant re-runs a 109-fixture, 199k-probe sweep (~35s),
# so the stand takes ~8 minutes. The sweep is the thing under test; running it
# once and reusing the output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
SHR=bots/BotLib/hero_shredder.lua
SWEEP=tests/_mockscalar_sweep.lua
MOCK=tests/mock/replay_fixture.lua
API=tests/mock/bot_api.lua
TEST=test_mockscalar_return_shape

TMP=$(mktemp -d)
nrun=0; ncaught=0
INFLIGHT=""

save() {
    cp "$1" "$TMP/$(basename "$1").orig"
    sha256sum "$1" > "$TMP/$(basename "$1").sha"
    INFLIGHT="$1"
}
restore() {
    cp "$TMP/$(basename "$1").orig" "$1"
    if ! sha256sum -c "$TMP/$(basename "$1").sha" >/dev/null; then
        echo "FATAL: restore of $1 did not verify -- stopping before anything else runs"
        exit 2
    fi
    INFLIGHT=""
}
# GH #418's trap: restore FIRST, delete the copies SECOND. The reverse leaves a
# mutant in the tree and destroys the only original.
on_exit() {
    if [ -n "$INFLIGHT" ]; then
        echo "INTERRUPTED with $INFLIGHT mutated -- restoring before exit"
        restore "$INFLIGHT"
    fi
    rm -rf "$TMP"
}
trap on_exit EXIT

# Rule 3: read the exit code directly, never through a pipe.
run_test() {
    local rc=0
    lua5.1 tests/run_tests.lua "$TEST" > "$TMP/$TEST.log" 2>&1 || rc=$?
    echo "$rc"
}

mutant() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-58s (the edit matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
        echo "            per its converse, first confirm the edit landed where you meant."
    fi
}

# --- M1..M3: the blocker is removed, one name at a time ----------------------
# The day somebody acts on this pricing. Each stub makes one of the three names
# answer from the frame instead of from the catch-all, and every count that
# rests on it has to be retaken. A file that stays green here is a finding that
# outlives its own premise.
m1() { perl -0pi -e 's/\n            GetLocation = loc,/\n            GetLocation = loc,\n            GetExtrapolatedLocation = loc,/' "$MOCK"; }
mutant "M1 mock stubs GetExtrapolatedLocation" "$MOCK" m1

m2() { perl -0pi -e 's/\n            GetLocation = loc,/\n            GetLocation = loc,\n            GetVelocity = loc,/' "$MOCK"; }
mutant "M2 mock stubs GetVelocity" "$MOCK" m2

m3() { perl -0pi -e 's/\n            GetLocation = loc,/\n            GetLocation = loc,\n            GetCurrentActiveAbility = false,/' "$MOCK"; }
mutant "M3 mock stubs GetCurrentActiveAbility" "$MOCK" m3

# --- M4: the OTHER prefix rule is repaired FIRST -----------------------------
# THE mutant. This is precisely the move the file argues is out of order: repair
# `^Is -> false` before `^Get -> 0`. Four carriers that answer on every frame
# they can reach today stop answering entirely, and per GH #492 a two-bucket
# census downstream would score that as "measured no" and delete the frames.
# The test must notice the change TODAY, not only in its lifted leg.
m4() { perl -0pi -e "s/    if key:find\('\\^Is'\) or key:find\('\\^Has'\)/    if key == 'IsCastingAbility' then return true end\n    if key:find('\\^Is') or key:find('\\^Has')/" "$API"; }
mutant "M4 mock repairs the ^Is default first (out of order)" "$API" m4

# --- M5..M7: a shipped consumption site is rewritten -------------------------
# The classification "this return is not a scalar" is taken from the tree, never
# from the API doc (GH #241's banner). Rewrite the consumption and the tree
# stops proving it; the pricing would then be inherited prose.
m5() { perl -0pi -e 's/\tlocal a = v\.x \* v\.x \+ v\.y \* v\.y - s \* s/\tlocal a = 0 - s * s/' "$JMZ"; }
mutant "M5 GetUltLoc stops indexing the velocity .x/.y" "$JMZ" m5

m6() { perl -0pi -e 's/local nAbility = npcEnemy:GetCurrentActiveAbility\(\)/local nAbility = npcEnemy:GetCurrentActiveAbilityX()/g' "$JMZ"; }
mutant "M6 the GetCurrentActiveAbility sites are renamed away" "$JMZ" m6

m7() { perl -0pi -e 's/hEnemy:GetExtrapolatedLocation\( 0\.5 \)/hEnemy:GetLocation()/g' "$JMZ"; }
mutant "M7 the extrapolation sites collapse to GetLocation" "$JMZ" m7

# --- M8: the never-answering carrier becomes dead code -----------------------
# "Shipped, ungated, and has never answered" is three claims. Delete the only
# caller and the first one is gone, which changes what 503/503 means.
m8() { perl -0pi -e 's/\t\t\tlocal loc = J\.GetUltLoc\(bot, botTarget, nManaCost, nCastRange, nSpeed\)/\t\t\tlocal loc = bot:GetLocation()/' "$SHR"; }
mutant "M8 J.GetUltLoc loses its only shipped caller" "$SHR" m8

# --- M9, M10: the instrument stops lifting -----------------------------------
# The masking claim is a comparison between two legs. If the lifted leg lifts
# nothing, both legs agree and "masked" is satisfiable by any corpus at all --
# the census would be measuring only itself. M10 is the subtler one: it lifts
# the right names on the WRONG units, which still runs, still produces two legs,
# and still looks like a comparison.
m9() { perl -0pi -e 's/                                        rawset\(h, g, function\(\) return true end\)/                                        local _ = g/' "$SWEEP"; }
mutant "M9 the lifted leg stops overriding anything" "$SWEEP" m9

m10() { perl -0pi -e "s/                            if k\.lift == 'enemies' then\n                                targets = near\(J, bot, 1600\)\n                            end/                            local _ = k.lift/" "$SWEEP"; }
mutant "M10 the lift is applied to the wrong units" "$SWEEP" m10

# --- M11: three buckets fold back into two -----------------------------------
# GH #492's own defect, re-committed inside the instrument that reports it: an
# out-of-domain early return scored as a measured answer. Every "never answers"
# row would then read as a row with hundreds of answers.
m11() { perl -0pi -e 's/                        if not okd or not ind then r\.out_s = r\.out_s \+ 1\n                        elseif pcall\(k\.call, J, bot\) then r\.ans_s = r\.ans_s \+ 1/                        if false then r.out_s = r.out_s + 1\n                        elseif pcall(k.call, J, bot) then r.ans_s = r.ans_s + 1/' "$SWEEP"; }
mutant "M11 abstentions are scored as answers (the #492 defect)" "$SWEEP" m11

# --- M12: the exempt roster stops being parsed -------------------------------
# The census subtracts the names the mock already steers away from the
# catch-all. Parsed, that list tracks the mock; hardcoded, it tracks nothing,
# and the first person to stub a getter gets a green census that is wrong.
m12() { perl -0pi -e "s/    for name in src:gmatch\(\"key%s\*==%s\*'\(Get\[A-Za-z0-9_\]\*\)'\"\) do ex\[name\] = true end/    local _ = src/" "$SWEEP"; }
mutant "M12 the exempt roster stops tracking the mock" "$SWEEP" m12

echo
echo "$ncaught/$nrun mutants CAUGHT"
[ "$ncaught" -eq "$nrun" ] || exit 1
