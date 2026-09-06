#!/usr/bin/env bash
# Mutation stand for tests/test_towerring_attack_circle.lua (test_set.md §FG).
#
# WHAT IT IS FOR. `towerring` narrows an EXISTING armed lever (`towerfear`) on a
# geometric line: keep the halved early-tower-fear clock in the 700-898 u
# annulus, restore the shipped clock inside the tower's own 700 u attack circle.
# The case rests on four claims, and they forge differently:
#   (a) the BEHAVIOUR -- a driven four-world read (shipped / towerfear /
#       towerring / the pair) on seven real frames that straddle 700;
#   (b) the DOMINATION claim -- armed together with `towerfear`, `towerring`
#       must win, because the pair is the configuration a promote would ship.
#       That is carried by STATEMENT ORDER and by nothing else;
#   (c) the NO-DRIFT claim -- the restore writes back a captured local, not a
#       second copy of `5 * 60`;
#   (d) the SUBSET claim -- released(towerring) is inside released(towerfear).
#
# ⭐ WHAT THIS STAND CANNOT BUY, and says so with a measured mutant rather than
# with prose (M6b). The corpus brackets the 700 literal behaviourally only
# between 649.41 u and 727.46 u. Move the constant INSIDE that interval and the
# frames see nothing; only the source assertion is left. M6 mutates the constant
# and is CAUGHT; M6b mutates the constant AND the source assertion together --
# i.e. it plays the reviewer who retunes a number and updates its test -- and it
# is declared UNMEASURABLE, because that is exactly what the frames cannot see.
# The pair is the honest statement of the price; either mutant alone would
# misrepresent it.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2) -- the restore gate lands negated (so
#     the SHIPPED tree changes and the armed leg is the old shipped read), or the
#     restore clause is deleted and `towerring` becomes a silent alias of
#     `towerfear`: still gated, still turbo-only, still passes its own gate, and
#     narrows nothing;
#   * ⭐ THE ORDERING GOES (M4, M10) -- the restore is moved above the halving, or
#     the shipped clock is captured after it. Both leave every statement present
#     and correct-looking; what they destroy is the domination claim, which is
#     the only reason the PAIR reads as the narrowed lever;
#   * THE NEW ID STOPS HALVING (M3, M5) -- `towerring` is dropped from the
#     halving disjunction, or the disjunction becomes a conjunction. Armed alone
#     it then restores a clock nothing halved: a no-op that a single-arm wave
#     reads as "tested, neutral";
#   * THE CONSTANT MOVES (M6, M6b) -- see above;
#   * THE COMPARISON MOVES (M7) -- strict `<` becomes `<=`. Declared
#     UNMEASURABLE: no frame in the corpus sits at exactly 700.00 u;
#   * THE NIL GUARD GOES (M8) -- `nEnemyTowers[1] ~= nil` is dropped from the
#     restore, so the distance call runs against nil on every frame with no
#     tower in the ring;
#   * THE DUPLICATION RETURNS (M9) -- the restore writes its own `5 * 60`
#     instead of the captured local. Behaviourally identical TODAY; it is the
#     shape that lets the two copies drift the day the shipped clock moves;
#   * THE PULLCAD TRAP (M11) -- the restore gate grows a second soak id, which
#     freezes it FALSE the day that id is promoted and destroys single-arm
#     readability in the meantime;
#   * THE GATE STOPS BEING TURBO-ONLY (M12) -- the `IsModeTurbo()` conjunct
#     leaves the restore, so a candidate ships into normal games;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M13, control) -- the block's
#     comment is rewritten. This lever's rationale names both ids, `700`, `898`
#     and the clock while explaining them, so a suite that parses prose goes
#     green-to-red here and nowhere else.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION (GH #550, GH #555). Every
# anchor below is counted in the file BEFORE its mutant runs; a mismatch is a
# STAND failure, not a mutant result. `perl -0pi -e "s///"` without /g rewrites
# the first match, and a `CAUGHT` printed for a cut somewhere else is
# indistinguishable from a mutant that worked.
#
# Each mutant edits files in place and restores them from copies taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` (evidence-discipline rule 1:
# `git checkout --` would silently discard the uncommitted work under test).
#
#   bash tools/agent/mutstand_towerring.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT, or an anchor did not occur the declared number of
# times. Exit 2 = a restore did not verify (nothing else runs after that).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RETREAT=bots/mode_retreat_generic.lua
TEST_FILE=tests/test_towerring_attack_circle.lua
TEST=towerring

TMP=$(mktemp -d)
nrun=0; ncaught=0; nbad=0; nunmeas=0
INFLIGHT=""

save() {
    for f in $1; do
        cp "$f" "$TMP/$(basename "$f").orig"
        sha256sum "$f" > "$TMP/$(basename "$f").sha"
    done
    INFLIGHT="$1"
}
restore() {
    for f in $1; do
        cp "$TMP/$(basename "$f").orig" "$f"
        if ! sha256sum -c "$TMP/$(basename "$f").sha" >/dev/null; then
            echo "FATAL: restore of $f did not verify -- stopping before anything else runs"
            exit 2
        fi
    done
    INFLIGHT=""
}
# GH #418's trap: restore FIRST, delete the copies SECOND.
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

# ⛔ Literal substring count over the WHOLE file. Not `grep -F -c`: that counts
# LINES and treats a multi-line needle as a LIST of alternative patterns, which
# is how the first version of this check reported 13133 occurrences of a
# two-line anchor that occurs once (GH #555).
anchor() {
    local want=$1 file=$2 needle=$3
    local n
    n=$(NEEDLE="$needle" python3 -c 'import os,sys; sys.stdout.write(str(open(sys.argv[1]).read().count(os.environ["NEEDLE"])))' "$file" 2>/dev/null || true)
    [ -z "$n" ] && n=0
    if [ "$n" -ne "$want" ]; then
        printf 'ANCHOR    %-58s occurs %s time(s) in %s, expected %s\n' \
            "${needle:0:58}" "$n" "$file" "$want"
        nbad=$((nbad + 1))
        return 1
    fi
    return 0
}

# want=caught (a real mutant), want=survive (a control), want=unmeasurable (a
# real mutant this corpus provably cannot witness, reason at the call site).
# UNMEASURABLE is not a pass; it is a declared hole with a named cause.
mutant() {
    local want=$1 label=$2 targets=$3; shift 3
    nrun=$((nrun + 1))
    save "$targets"
    "$@"
    local changed=0
    for f in $targets; do
        cmp -s "$f" "$TMP/$(basename "$f").orig" || changed=1
    done
    if [ "$changed" -eq 0 ]; then
        restore "$targets"
        printf 'NO-OP     %-58s (the edit matched nothing -- the mutant never existed)\n' "$label"
        nbad=$((nbad + 1))
        return
    fi
    local rc; rc=$(run_test)
    restore "$targets"
    if [ "$want" = caught ]; then
        if [ "$rc" -ne 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
            echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
            echo "            per its converse, first confirm the edit landed where you meant."
        fi
    elif [ "$want" = unmeasurable ]; then
        if [ "$rc" -eq 0 ]; then
            nunmeas=$((nunmeas + 1))
            printf 'UNMEASURABLE %-55s exit=%s  (declared; NOT a pass)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** re-classify as `caught` **\n' "$label" "$rc"
            echo "          ^ the suite can now witness this branch; the"
            echo "            UNMEASURABLE note at the call site is out of date."
        fi
    else
        if [ "$rc" -eq 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'SURVIVED  %-58s exit=%s  (control, as declared)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** CONTROL WENT RED **\n' "$label" "$rc"
            echo "          ^ a comment edit turned this suite red: something in it"
            echo "            is being satisfied by prose rather than by code."
        fi
    fi
}

HALVE=$'        if (J.IsSoakCandidate(\'towerfear\') or J.IsSoakCandidate(\'towerring\'))\n            and J.IsModeTurbo()\n        then\n            nFearClock = nFearClock / 2\n        end\n'
RESTORE=$'        if J.IsSoakCandidate(\'towerring\') and J.IsModeTurbo()\n            and nEnemyTowers[1] ~= nil\n            and GetUnitToUnitDistance(bot, nEnemyTowers[1]) < 700\n        then\n            nFearClock = nFearClockShipped\n        end\n'
CAPTURE=$'        local nFearClock = 5 * 60\n        local nFearClockShipped = nFearClock\n'

anchor 1 "$RETREAT" "$HALVE"   || true
anchor 1 "$RETREAT" "$RESTORE" || true
anchor 1 "$RETREAT" "$CAPTURE" || true

# --- M1, M2: the lever leaves, or lands inverted -----------------------------
m1() { perl -0pi -e "s/if J\.IsSoakCandidate\('towerring'\) and J\.IsModeTurbo\(\)\n            and nEnemyTowers/if not J.IsSoakCandidate('towerring') and J.IsModeTurbo()\n            and nEnemyTowers/" "$RETREAT"; }
mutant caught "M1 the restore gate lands negated (shipped tree changes)" "$RETREAT" m1

m2() { perl -0pi -e "s/        if J\.IsSoakCandidate\('towerring'\) and J\.IsModeTurbo\(\)\n            and nEnemyTowers\[1\] ~= nil\n            and GetUnitToUnitDistance\(bot, nEnemyTowers\[1\]\) < 700\n        then\n            nFearClock = nFearClockShipped\n        end\n//" "$RETREAT"; }
mutant caught "M2 the restore clause is deleted (towerring aliases towerfear)" "$RETREAT" m2

# --- M3, M5: the new id stops halving ----------------------------------------
# Armed alone it then restores a clock nothing halved -- a no-op that reads as
# "tested, neutral" in a single-arm wave and as WIRED in check_armed_wiring.py.
m3() { perl -0pi -e "s/if \(J\.IsSoakCandidate\('towerfear'\) or J\.IsSoakCandidate\('towerring'\)\)/if (J.IsSoakCandidate('towerfear'))/" "$RETREAT"; }
mutant caught "M3 towerring is dropped from the halving disjunction" "$RETREAT" m3

m5() { perl -0pi -e "s/if \(J\.IsSoakCandidate\('towerfear'\) or J\.IsSoakCandidate\('towerring'\)\)/if (J.IsSoakCandidate('towerfear') and J.IsSoakCandidate('towerring'))/" "$RETREAT"; }
mutant caught "M5 the halving disjunction becomes a conjunction" "$RETREAT" m5

# --- M4, M10: ⭐ the ordering goes ---------------------------------------------
# Every statement is still present and individually correct. What dies is the
# claim that the PAIR reads as the narrowed lever -- i.e. what a promote ships.
# Swapped as literal blocks in python: a perl one-liner carrying two multi-line
# needles through bash quoting is how M4 spent its first run reporting `ENV:
# unbound variable` instead of a mutant result.
m4() {
    A="$HALVE" B="$RESTORE" python3 - "$RETREAT" <<'PY'
import os, sys
p = sys.argv[1]
a, b = os.environ['A'], os.environ['B']
s = open(p).read()
assert s.count(a + b) == 1, 'the halve/restore pair is not adjacent exactly once'
open(p, 'w').write(s.replace(a + b, b + a, 1))
PY
}
mutant caught "M4 the restore is moved ABOVE the halving (domination dies)" "$RETREAT" m4

m10() { perl -0pi -e "s/        local nFearClock = 5 \* 60\n        local nFearClockShipped = nFearClock\n/        local nFearClock = 5 * 60\n/; s/            nFearClock = nFearClock \/ 2\n        end\n/            nFearClock = nFearClock \/ 2\n        end\n        local nFearClockShipped = nFearClock\n/" "$RETREAT"; }
mutant caught "M10 the shipped clock is captured AFTER the halving" "$RETREAT" m10

# --- M6, M6b: ⭐ the constant moves, and what the frames cannot see ------------
# 900 is outside the behavioural bracket (649.41, 727.46): the annulus frames at
# 727/787/845 flip to held and the frames catch it on their own.
m6() { perl -0pi -e "s/nEnemyTowers\[1\]\) < 700/nEnemyTowers[1]) < 900/" "$RETREAT"; }
mutant caught "M6 the attack circle is retuned 700 -> 900 (outside the bracket)" "$RETREAT" m6

# 680 is INSIDE the bracket, and the source assertion is updated with it -- the
# reviewer who retunes a number and fixes up its test. Nothing behavioural is
# left to catch it, and that is the whole point of running this mutant.
m6b() {
    perl -0pi -e "s/nEnemyTowers\[1\]\) < 700/nEnemyTowers[1]) < 680/" "$RETREAT"
    perl -0pi -e "s/assert\(tonumber\(range\) == 700,/assert(tonumber(range) == 680,/" "$TEST_FILE"
    perl -0pi -e "s/BLOCK:find\('nEnemyTowers%\[1%\]%s\*%\)%s\*<%s\*700'\)/BLOCK:find('nEnemyTowers%[1%]%s*%)%s*<%s*680')/" "$TEST_FILE"
    perl -0pi -e "s/assert\(tonumber\(ring\) > 700,/assert(tonumber(ring) > 680,/" "$TEST_FILE"
    perl -0pi -e "s/assert\(d < 700, hero/assert(d < 680, hero/" "$TEST_FILE"
    perl -0pi -e "s/assert\(d > 700, hero/assert(d > 680, hero/" "$TEST_FILE"
    perl -0pi -e "s/assert\(d_in < 700 and d_out > 700,/assert(d_in < 680 and d_out > 680,/" "$TEST_FILE"
}
mutant unmeasurable "M6b 700 -> 680 WITH the source assertion updated" "$RETREAT $TEST_FILE" m6b

# --- M7, M7b: the comparison moves -------------------------------------------
# ⚠️ M7 was DECLARED unmeasurable on this stand's first run and came back CAUGHT.
# The declaration was wrong and the stand said so in one line: the textual
# assertion `<%s*700` does not match `<= 700`, so the source half sees it even
# though no frame in the corpus sits at exactly 700.00 u. Reclassified, and the
# behavioural hole it was really claiming is measured by M7b below instead --
# the same M6/M6b split. Recorded rather than quietly relabelled, because "I
# expected UNMEASURABLE and got CAUGHT" is the direction that flatters the
# suite, and it is exactly the direction that goes unexamined.
m7() { perl -0pi -e "s/nEnemyTowers\[1\]\) < 700/nEnemyTowers[1]) <= 700/" "$RETREAT"; }
mutant caught "M7 the strict < becomes <= (caught by the source half)" "$RETREAT" m7

# The same edit with its source assertion updated: nothing textual is left, and
# the frames cannot separate `<` from `<=` because none sits at 700.00 u.
#
# ⚠️ M7b's own first version was a NO-OP on the test file and therefore just a
# second copy of M7: its perl needles spelled the Lua patterns with `)` where
# the file has `%)`, so nothing matched and the stand reported CAUGHT for an
# edit that had not landed. Same family as GH #550 -- the wrong colour comes
# from the wrong program, not from the wrong prediction. Done as a counted
# literal replacement now; note the fourth `%s*<%s*` in the file belongs to the
# clock leg (`DotaTime() < nFearClock`) and must NOT move.
m7b() {
    perl -0pi -e "s/nEnemyTowers\[1\]\) < 700/nEnemyTowers[1]) <= 700/" "$RETREAT"
    python3 - "$TEST_FILE" <<'PY'
import sys
p = sys.argv[1]
old = 'nEnemyTowers%[1%]%s*%)%s*<%s*'
new = 'nEnemyTowers%[1%]%s*%)%s*<=%s*'
s = open(p).read()
assert s.count(old) == 3, 'expected 3 distance patterns, found %d' % s.count(old)
open(p, 'w').write(s.replace(old, new))
PY
}
mutant unmeasurable "M7b < -> <= WITH the source assertion updated" "$RETREAT $TEST_FILE" m7b

# --- M8: the nil guard goes --------------------------------------------------
m8() { perl -0pi -e "s/        if J\.IsSoakCandidate\('towerring'\) and J\.IsModeTurbo\(\)\n            and nEnemyTowers\[1\] ~= nil\n/        if J.IsSoakCandidate('towerring') and J.IsModeTurbo()\n/" "$RETREAT"; }
mutant caught "M8 the nEnemyTowers[1] ~= nil guard leaves the restore" "$RETREAT" m8

# --- M9: the duplication returns ---------------------------------------------
# Behaviourally identical TODAY. It is caught by the no-drift assertion, and
# that assertion exists because the shipped clock is a number someone will move.
m9() { perl -0pi -e "s/            nFearClock = nFearClockShipped\n/            nFearClock = 5 * 60\n/" "$RETREAT"; }
mutant caught "M9 the restore writes its own 5 * 60 instead of the captured local" "$RETREAT" m9

# --- M11: the pullcad trap ---------------------------------------------------
m11() { perl -0pi -e "s/if J\.IsSoakCandidate\('towerring'\) and J\.IsModeTurbo\(\)\n            and nEnemyTowers/if J.IsSoakCandidate('towerring') and J.IsSoakCandidate('towerfear') and J.IsModeTurbo()\n            and nEnemyTowers/" "$RETREAT"; }
mutant caught "M11 the restore gate grows a second soak id (pullcad trap)" "$RETREAT" m11

# --- M12: the gate stops being turbo-only ------------------------------------
m12() { perl -0pi -e "s/if J\.IsSoakCandidate\('towerring'\) and J\.IsModeTurbo\(\)\n            and nEnemyTowers/if J.IsSoakCandidate('towerring')\n            and nEnemyTowers/" "$RETREAT"; }
mutant caught "M12 IsModeTurbo() leaves the restore gate" "$RETREAT" m12

# --- M13: control -- prose only ----------------------------------------------
m13() { perl -0pi -e "s/        -- 700 is the tower's attack range, the same constant the paragraph\n        -- above reasons from; it is not a number invented here\./        -- The radius below is the tower attack range./" "$RETREAT"; }
mutant survive "M13 the rationale comment is rewritten (control)" "$RETREAT" m13

echo
printf 'STAND %s: %d mutant(s), %d as declared, %d UNMEASURABLE, %d unexpected\n' \
    "$([ "$nbad" -eq 0 ] && echo GREEN || echo RED)" "$nrun" "$ncaught" "$nunmeas" "$nbad"
[ "$nbad" -eq 0 ] || exit 1
exit 0
