#!/usr/bin/env bash
# Mutation stand for the lost-chain-member census:
# tools/agent/chain_member_census.py and its ratchet
# tests/test_chain_member_census.py.  Run by hand when either is edited, and
# before quoting either in a ruling.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418: an
#     interrupted stand otherwise leaves the MUTANT in the working tree);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS ESPECIALLY FOR.  This round's product is a READING and a
# JUDGEMENT, not a behaviour change: "twelve duplicated operands in bots/, four
# of them dropped members, and all four unbuyable on this corpus."  Three ways
# that fails silently:
#   (1) The SCANNER goes blind -- walks nothing, stops splitting, or stops
#       DESCENDING -- and `FINDINGS 0` (or `FINDINGS 10`) is indistinguishable
#       from a completed sweep.  M4-M8.
#   (2) The JUDGEMENT drifts -- a site quietly gets repaired, or reclassified
#       from dropped-member to idempotent, and the registration it was traded
#       for evaporates.  M1-M3.
#   (3) The DOMAIN reading goes vacuous -- the fixture scan matches nothing and
#       "these heroes are not in the archive" becomes a statement about an
#       empty set.  M9-M12.
#
# ⚠ THE DESCENT IS NOT DECORATION, AND M7 IS WHY.  The first draft of this
# census split only the OUTERMOST and/or chain of a condition.  It reported ten
# duplicates and looked like a finished sweep; two of the four dropped-member
# sites (hoodwink, snapfire) are parenthesised sub-chains and were invisible to
# it.  M7 rots the descent back out.  If M7 ever survives, the sweep is half a
# sweep again and nothing says so.
#
# Usage: bash tools/agent/mutstand_chainmember.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    tools/agent/chain_member_census.py
    tests/test_chain_member_census.py
    bots/BotLib/hero_dark_seer.lua
    bots/BotLib/hero_kunkka.lua
    bots/BotLib/hero_snapfire.lua
    tools/agent/write_only_local_census.py
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cm.XXXXXX")
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
    python3 tests/test_chain_member_census.py > "$WORK/run.log" 2>&1
    return $?
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys
mut = os.environ["MUT"]
TOOL = "tools/agent/chain_member_census.py"
TEST = "tests/test_chain_member_census.py"
DS   = "bots/BotLib/hero_dark_seer.lua"
KK   = "bots/BotLib/hero_kunkka.lua"
SF   = "bots/BotLib/hero_snapfire.lua"
WO   = "tools/agent/write_only_local_census.py"

MUTANTS = {
    # ---- the judgement drifts -------------------------------------------
    # M1: dark_seer is silently REPAIRED -- an ungated behaviour change on a
    #     lever this round deliberately registered instead of fixing.  Exactly
    #     the drift the registration exists to make impossible.
    "M1": [(DS,
            "        and nEnemyTowers ~= nil and #nInRangeEnemy == 0",
            "        and nEnemyTowers ~= nil and #nEnemyTowers == 0")],
    # M2: kunkka is "repaired" by DELETING the third operand rather than
    #     restoring the lost member.  The census reads clean and the tier the
    #     author intended is gone with no ruling anywhere.
    "M2": [(KK,
            "\t\tor Combo2Time ~= 0\n\t\tor Combo2Time ~= 0\n",
            "\t\tor Combo2Time ~= 0\n")],
    # M3: the snapfire WITNESS is removed -- the tautology's `or x == 0` arm
    #     goes away, so the duplicate stops being self-evidently a lost member
    #     while the duplicate itself stays.  The finding survives; the ARGUMENT
    #     for calling it dropped-member does not.
    "M3": [(SF,
            "                    or #nTargetInRangeAlly == 0\n",
            "                    or #nInRangeAlly == 0\n")],
    # ---- the scanner goes blind (the green-failure family) --------------
    # M4: the corpus walk is pointed at nothing.  FINDINGS 0 on an empty scan;
    #     only the DENOMINATORS can tell that apart from a clean tree.
    "M4": [(TOOL,
            "    for path in lua_corpus.bots_lua_files(root):",
            "    for path in lua_corpus.bots_lua_files(root)[:0]:")],
    # M5: conditions stop being JOINED across lines (max 30 -> 0), so every
    #     multi-line chain is truncated at its first line.  The scanner still
    #     walks all 275 files; the dark_seer and kunkka chains simply stop
    #     existing.  This is the mutant M4's denominator cannot catch.
    "M5": [(TOOL, "MAX_JOIN_LINES = 30", "MAX_JOIN_LINES = 0")],
    # M6: the depth-0 splitter loses its depth, so bracketed sub-expressions
    #     are cut mid-way and operands stop matching.  Over-splitting is the
    #     under-report direction and it is silent.
    "M6": [(TOOL,
            "        if c in \"([{\":\n            depth += 1\n        elif c in \")]}\":\n            depth -= 1\n        if depth == 0:",
            "        if c in \"([{\":\n            depth += 1\n        elif c in \")]}\":\n            depth -= 1\n        if True:")],
    # M7: THE DESCENT IS ROTTED BACK OUT -- chain_scopes returns only the
    #     outermost chain, exactly the first draft of this round.  Ten
    #     duplicates, a printed denominator, and half the dropped-member class
    #     gone.  See the header.
    "M7": [(TOOL,
            "                    queue.append(cur[start:i])",
            "                    pass")],
    # M8: the guard pattern stops being ANCHORED, so `#nA ~= nil` and other
    #     non-bare comparisons count as guards.  The false-positive direction:
    #     this is how a correct existence test gets "repaired" into a defect.
    "M8": [(TOOL,
            "    m = re.match(r\"^([A-Za-z_]\\w*)\\s*[~=]=\\s*nil$\", operand)",
            "    m = re.match(r\"([A-Za-z_]\\w*)\\s*[~=]=\\s*nil\", operand)")],
    # ---- the domain reading goes vacuous --------------------------------
    # M9: the fixture glob matches nothing.  "These heroes are not in the
    #     archive" becomes true of the empty set and the whole justification
    #     for registering-instead-of-fixing evaporates, silently.
    "M9": [(TEST,
            "fixtures = sorted(glob.glob(os.path.join(REPO, \"tests\", \"fixtures\", \"*.lua\")))",
            "fixtures = sorted(glob.glob(os.path.join(REPO, \"tests\", \"fixtures\", \"*.luaX\")))")],
    # ⚠ M10-M12 MUTATE THE READER, NOT THE ASSERTION.  The first draft of this
    #   stand mutated section 3's assertions themselves (weakening `== 53` to
    #   `>= 0`, deleting the second spelling, `or True`-ing the blind-spot
    #   claim) and all three SURVIVED -- necessarily, because the oracle this
    #   stand scores against IS that test file: an assertion cannot catch its
    #   own weakening.  That is a property of the stand, not a missing
    #   assertion, and the repair is to break what the assertion is ABOUT.
    #
    # M10: the corpus reader answers 0 for everything.  Every "this hero is not
    #      in the archive" line goes on passing; only the NON-EMPTY control can
    #      tell a real absence from a broken reader.
    "M10": [(TEST,
             "    return sum(1 for b in blobs if token in b)",
             "    return sum(0 for b in blobs if token in b)")],
    # M11: the reader stops distinguishing spellings -- every token is looked
    #      up under the canonical prefix.  This is the GH #431 near-miss made
    #      mechanical, and it is caught only because one hero in this corpus
    #      really is present under two spellings with different counts.
    "M11": [(TEST,
             "    return sum(1 for b in blobs if token in b)",
             "    return sum(1 for b in blobs\n"
             "               if token.replace(\"vengefulspirit\", \"vengeful_spirit\") in b)")],
    # ---- the walk goes HALF blind (GH #457) -----------------------------
    # M13: the walk drops ONE file -- the last one in corpus order.  This is
    #      the mutant the denominators were never able to catch and the reason
    #      turning them into floors costs nothing: an exact `== 10946` and a
    #      floor of 7000 are equally blind to it (10945 fails both the pin and
    #      nothing else), and the findings ratchet only sees it on the days the
    #      dropped file happens to hold one of the twelve.  Only the coverage
    #      relation -- `visited == bots_lua_relpaths()` -- says so every time.
    #      If M13 ever survives, the sweep can quietly stop covering shipped
    #      code one file at a time, which is the failure `lua_corpus.py`'s own
    #      header warns an easy exclusion mechanism would buy.
    "M13": [(TOOL,
             "    for path in lua_corpus.bots_lua_files(root):",
             "    for path in lua_corpus.bots_lua_files(root)[:-1]:")],
    # M12: THE HOLE IS CLOSED -- write_only_local_census stops counting a self
    #      nil-guard as a read, so it reports nEnemyTowers too and section 4's
    #      claim becomes false.  If this survives, section 4 is not actually
    #      reading that tool's output and the round's headline reusable finding
    #      is unpinned.
    "M12": [(WO,
             "                if ln in writes[name] and _is_write_occurrence(line, m.start(), name):\n"
             "                    continue\n"
             "                reads += 1",
             "                if ln in writes[name] and _is_write_occurrence(line, m.start(), name):\n"
             "                    continue\n"
             "                if re.match(r\"\\s*[~=]=\\s*nil\\b\", line[m.end():]):\n"
             "                    continue\n"
             "                reads += 1")],
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
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13; do
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

echo "=== $CAUGHT caught / $SURVIVED survived / $ABORTED aborted (of 13) ==="
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]
