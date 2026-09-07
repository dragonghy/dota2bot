#!/usr/bin/env bash
# Mutation stand for the soak candidate 'ckpush': the seconds-per-minute gate in
# bots/BotLib/hero_chaos_knight.lua (X.GetPushCommitTime + the X.ConsiderR push
# branch that reads it) and the assertions in
# tests/test_ckpush_minute_unit.lua.  Run by hand when any of those is edited.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418: an
#     interrupted stand otherwise leaves the MUTANT in the working tree);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant (0CORP);
#   * mutants that would trip a SOURCE-TEXT assertion also BRIBE that assertion,
#     so "caught" means a behaviour/measurement assertion caught it and not that
#     a string pin noticed a string changing (§DJ / 0EQUIV).
#
# WHAT THIS STAND IS ESPECIALLY FOR.  The lever's whole justification is a
# MEASUREMENT (Phantasm is first learned at t=306.0s, so the shipped 240 never
# binds).  M7-M10 attack the measurement rather than the gate: a corpus census
# that has quietly stopped measuring anything is the failure mode this file
# exists to make impossible, because unlike a wrong constant it stays green.
#
# ⚠ TWO MUTANTS WERE TRIED, SURVIVED, AND WERE REPLACED -- and the reason is
# reusable, so it is written here rather than deleted with them.  The first
# drafts of M9 and M10 WEAKENED the two corpus floors themselves (`>= 5` -> `>= 0`,
# `== 0` -> `<= 99`).  Both survived, and not because an assertion is missing:
# a file cannot catch its own assertion being loosened.  Weakening an assertion
# is invisible to every test that assertion protects, by construction, so
# "SURVIVED" there is a statement about mutation testing, not about this file.
# Per 0EQUIV that is NOT licence to call them equivalent mutants -- they do change
# what the suite can detect.  The disposition is to attack the SAME FACT from the
# DATA side instead (M9 empties the band, M10 widens "has the ultimate" to "is
# alive"): if the floors are load-bearing, those must be caught, and they are.
# The residual gap is honest and named: nothing in this repo notices a future
# edit that merely relaxes these two numbers.
#
# Usage: bash tools/agent/mutstand_ckpush.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    bots/BotLib/hero_chaos_knight.lua
    bots/FunLib/rubick_hero/chaos_knight.lua
    tests/test_ckpush_minute_unit.lua
)
TESTS=(
    test_ckpush_minute_unit
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ck.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null || { echo "RESTORE FAILED"; exit 2; }
}

trap restore EXIT

run_tests() {
    local rc=0
    for t in "${TESTS[@]}"; do
        lua5.1 tests/run_tests.lua "$t" > "$WORK/run.log" 2>&1
        local one=$?
        if [ "$one" -ne 0 ]; then rc=$one; fi
    done
    return $rc
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys

mut = os.environ["MUT"]
HERO = "bots/BotLib/hero_chaos_knight.lua"
TWIN = "bots/FunLib/rubick_hero/chaos_knight.lua"
TEST = "tests/test_ckpush_minute_unit.lua"

BAND_PIN = "    assert(in_band_with_ult >= 5, string.format(\n"
EARLY_PIN = "    assert(early_with_ult == 0, string.format(\n"

MUTANTS = {
    # M1: the revert -- this round's edit undone, byte for byte.  The threshold
    #     goes back to an inline literal and the lever ceases to exist.
    "M1": [(HERO,
            "\t\tand DotaTime() > X.GetPushCommitTime()\n",
            "\t\tand DotaTime() > 8 * 30\n")],
    # M2: [RE-ANCHORED 2026-09-07 BY THE PROMOTE] the repair escapes turbo, so a
    #     normal-mode game gets it too.  Before the promote this mutant
    #     hard-armed the gate; the promote IS that edit, ruled and registered, so
    #     the mutant now attacks the boundary the promote kept -- this repo rules
    #     on turbo only, and the non-turbo leg must stay byte-identical to what
    #     the tree inherited.  BRIBED: the source-parity pattern is loosened in
    #     the same mutant, so a string pin cannot be what catches it.
    "M2": [(HERO,
            "\tif J.IsModeTurbo()\n",
            "\tif true\n"),
           (TEST,
            "    assert(src:find('if J%.IsModeTurbo%(%)%s*\\n%s*then%s*\\n%s*return 8 %* 60'),",
            "    assert(src:find('return 8 %* 60'),")],
    # M3: [RE-ANCHORED 2026-09-07] the turbo selection is INVERTED: turbo reads
    #     the inherited 240 and normal mode reads the repaired 480.  Both
    #     directions of section 2 have to be load-bearing for this to die; a
    #     suite that only asserted the turbo value would let it through.
    #     BRIBED the same way as M2.
    "M3": [(HERO,
            "\tif J.IsModeTurbo()\n",
            "\tif not J.IsModeTurbo()\n"),
           (TEST,
            "    assert(src:find('if J%.IsModeTurbo%(%)%s*\\n%s*then%s*\\n%s*return 8 %* 60'),",
            "    assert(src:find('return 8 %* 60'),")],
    # M4: gate-off stops being the SHIPPED value -- 240 becomes 300.  Truthiness
    #     is unchanged on both CK-subject frames (both sit at t < 240), so only
    #     the value-for-value [gate] assertion can see it.  This is the mutant
    #     that says whether "gate-off is the shipped value" was measured or
    #     merely written in the header.
    "M4": [(HERO, "\treturn 8 * 30\n\n", "\treturn 300\n\n")],
    # M5: armed returns 8 * 45 rather than the idiomatic 8 * 60.  A plausible
    #     "split the difference" edit that quietly changes what is being tested
    #     while every prose claim in the tree still says 480.
    "M5": [(HERO, "\t\treturn 8 * 60\n", "\t\treturn 8 * 45\n")],
    # M6: [RE-ANCHORED 2026-09-07] THE PROMOTE IS SILENTLY UNDONE.  Somebody
    #     re-gates the resolver on the promoted id.  Nothing about the tree looks
    #     wrong -- the comment still says PROMOTED, check_armed_wiring still
    #     passes because it only asks whether a call site exists -- but 'ckpush'
    #     is in no armed string ever again, so the conjunct is frozen FALSE (the
    #     `pullcad` trap, AGENTS.md) and every real turbo game silently returns
    #     to the inherited 8 * 30.  BRIBED on BOTH source-text pins, so the only
    #     thing left that can catch it is the behavioural assertion that turbo
    #     answers 480 with nothing armed.
    "M6": [(HERO,
            "\tif J.IsModeTurbo()\n",
            "\tif J.IsModeTurbo() and J.IsSoakCandidate( 'ckpush' )\n"),
           (TEST,
            "    assert(n == 0, string.format(",
            "    assert(n >= 0, string.format("),
           (TEST,
            "    assert(src:find('if J%.IsModeTurbo%(%)%s*\\n%s*then%s*\\n%s*return 8 %* 60'),",
            "    assert(src:find('return 8 %* 60'),")],
    # M7: THE MEASUREMENT GOES BLIND.  The corpus scan is pointed at a glob that
    #     matches nothing, so "no frame below 240 has Phantasm" and "12 frames in
    #     the band" both become statements about an empty set -- and both would
    #     still be TRUE of an empty set for the first one.  The anti-vacuity
    #     floors are the only thing standing here.
    "M7": [(TEST,
            "io.popen('ls tests/fixtures/*.lua 2>/dev/null')",
            "io.popen('ls tests/fixtures/*.luaX 2>/dev/null')")],
    # M8: the rank read is bribed to answer 1 for every frame, INCLUDING the
    #     ones below 240.  That inverts the ruling ("the shipped 240 never
    #     binds") while leaving every gate assertion green.
    "M8": [(TEST,
            "                rank = tonumber(raw) or 0,",
            "                rank = 1,")],
    # M9: the corpus scan silently drops every frame past the shipped 240, so
    #     the disagreement band becomes empty.  Same FACT as the discarded
    #     assertion-weakening mutant (see the header note), attacked from the
    #     data side -- which is the side on which the band floor is actually
    #     load-bearing.  If this survives, "12 frames separate the two legs" is
    #     not being measured.
    "M9": [(TEST,
            "        if t ~= nil and src:find(\"name = 'npc_dota_hero_chaos_knight'\", 1, true) then",
            "        if t ~= nil and t <= 240 and src:find(\"name = 'npc_dota_hero_chaos_knight'\", 1, true) then")],
    # M10: "has a learned Phantasm" is widened to rank >= 0, i.e. to "is alive".
    #      Every frame below 240 then counts as carrying the ultimate and the
    #      ruling inverts -- the shipped 240 would be binding after all.  This is
    #      the load-bearing direction of the early_with_ult == 0 floor.
    "M10": [(TEST,
             "        if r.rank >= 1 then\n            if earliest == nil or r.t < earliest then earliest = r.t end",
             "        if r.rank >= 0 then\n            if earliest == nil or r.t < earliest then earliest = r.t end")],
    # M11: the census stops seeing the tree.  "exactly 1 inline * 30 site left"
    #      would then be a claim about an empty scan -- and it would read as 0,
    #      so the assertion has to be two-sided to survive this.
    # ⚠ RE-ANCHORED 2026-09-07, AND THE RE-ANCHOR IS THE POINT.  The old target
    #   was the whole `io.popen('find ' .. dir .. ' -name "*.lua" 2>/dev/null')`
    #   line.  That line acquired the shared FARM_ONLY_FIND_CLAUSE (GH #365 §2 /
    #   #438) some time after this stand landed, so the target string went
    #   ABSENT: M11 has been ABORTing -- scoring nothing, and taking the stand's
    #   exit code to 1 -- ever since, while state.json still recorded 12/12
    #   CAUGHT.  Same family as GH #550: a mutant whose anchor no longer matches
    #   changes nothing and the stand still prints a verdict.  The anchor is now
    #   the SHORTEST load-bearing fragment (the glob itself), which is the part
    #   the mutant is actually about.
    "M11": [(TEST,
             "-name \"*.lua\" '",
             "-name \"*.luaX\" '")],
    # M12: the registered-not-fixed TWIN is silently repaired.  One lever per
    #      round is a rule, and rubick is DOMAIN-EMPTY, so this edit ships an
    #      unvalidatable behaviour change with no gate and no ruling.
    "M12": [(TWIN,
             "\t\tand DotaTime() > 8 * 30\n",
             "\t\tand DotaTime() > 8 * 60\n")],
}

edits = MUTANTS[mut]
for path, old, new in edits:
    src = open(path, encoding="utf-8").read()
    if old not in src:
        sys.stderr.write("ABORT: %s target absent in %s\n" % (mut, path))
        sys.exit(3)
for path, old, new in edits:
    src = open(path, encoding="utf-8").read()
    open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

echo "=== baseline (must be GREEN before any mutant is scored) ==="
run_tests
BASE=$?
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- every mutant below would score CAUGHT on this red."
    tail -20 "$WORK/run.log"
    exit 2
fi
echo "baseline GREEN"

CAUGHT=0; SURVIVED=0; ABORTED=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12; do
    restore
    apply_mutant "$m"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ABORT   $m -- target string absent; NOT scored"
        ABORTED=$((ABORTED + 1))
        continue
    fi
    run_tests
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "CAUGHT  $m"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "SURVIVED $m  <-- an assertion is missing"
        SURVIVED=$((SURVIVED + 1))
    fi
done
restore

echo "=== $CAUGHT caught / $SURVIVED survived / $ABORTED aborted (of 12) ==="
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]
