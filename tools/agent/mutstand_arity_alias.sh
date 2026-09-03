#!/usr/bin/env bash
# Mutation stand for the cross-module half of the call-arity census:
# tools/agent/call_arity_census.py and tests/test_call_arity_census.py.
# Run by hand when either is edited, and before quoting either in a ruling.
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
# WHAT THIS STAND IS ESPECIALLY FOR.  The product of 2026-09-03 is a RESOLVER,
# and a resolver fails in the one direction that stays green: it stops
# resolving, the findings it used to reach vanish, and every count downstream
# reads as a cleaner tree.  That is not a hypothetical here -- it is the
# measured history of this exact file.  Before this round the tool keyed
# declarations on the name as written (`____exports.Foo`) while every importer
# writes `Alias.Foo`, so 665 cross-module call sites fell out of an UNCOUNTED
# `continue`; the tool printed `OVER (0)`, the ratchet asserted "the OVER half
# is still empty", and both were true of the resolver rather than of the tree.
# The tree's only OVER member had been sitting at hero_selection:1040 the whole
# time.
#
# So the mutants are weighted accordingly: M1-M6 blind the resolver in six
# different places, and each one must be caught by a DENOMINATOR rather than by
# a finding, because a finding that has disappeared cannot raise its own hand.
# M7-M9 attack the false-positive direction (resolving a name that was never
# imported is how a correct call gets "fixed" and takes behaviour with it).
# M10-M13 pin the judgements this round wrote down, including the two words --
# ALLOWLIST (benign) and ROUTED (broken, owned elsewhere) -- whose separation is
# the only thing keeping a real defect from being filed as fine.
#
# Usage: bash tools/agent/mutstand_arity_alias.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    tools/agent/call_arity_census.py
    tests/test_call_arity_census.py
    bots/hero_selection.lua
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_aa.XXXXXX")
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
    python3 tests/test_call_arity_census.py > "$WORK/run.log" 2>&1
    return $?
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys
mut = os.environ["MUT"]
TOOL = "tools/agent/call_arity_census.py"
TEST = "tests/test_call_arity_census.py"

MUTANTS = {
    # ---- the resolver goes blind (the green-failure family) --------------
    # M1: the exact pre-2026-09-03 state, restored in one line -- the alias
    #     branch is never taken, so the tool is back to keying on the name as
    #     written.  Every finding this round added disappears at once.  If this
    #     survives, the blind spot can return and nothing says so.
    "M1": [(TOOL,
            "                entry = resolve_alias(name, aliases)",
            "                entry = None")],
    # M2: subtler than M1 -- resolution still happens, but the module export
    #     table is empty, so only the import side works.  The denominator
    #     `exports` is the one that has to catch this.
    "M2": [(TOOL,
            "        if \"____exports\" not in src:\n            continue",
            "        if \"____exports\" in src:\n            continue")],
    # M3: the `require` binding stops being read, so no file has any alias and
    #     `alias_calls` collapses to zero while every other denominator (files,
    #     declarations, dotted_calls) stays exactly as healthy as before.  This
    #     is precisely the shape that made the old blind spot invisible.
    "M3": [(TOOL,
            "    return {m.group(1): m.group(2).strip(\"/\")\n"
            "            for m in LOCAL_ALIAS_RE.finditer(src)}",
            "    return {}")],
    # M4: only the TWO-segment path breaks (`J.Utils.Foo`), so single-segment
    #     aliases still resolve and the totals barely move.  Three of this
    #     round's four routed rows live behind this branch.
    "M4": [(TOOL,
            "            mod = fields.get((mod, head[1]))",
            "            mod = None")],
    # M5: alias resolution succeeds but is never counted, so the denominator
    #     that this round added goes to zero while the findings stay.  The
    #     assertion must be about the COUNT, not merely about the findings --
    #     otherwise the next blind spot is once again unreportable.
    "M5": [(TOOL,
            "                stats[\"alias_calls\"] += 1",
            "                stats[\"alias_calls\"] += 0")],
    # M6: the module key stops matching what require() names (a leading-path
    #     drift), so every lookup misses.  Same end state as M1, reached
    #     through the path arithmetic instead of the branch.
    "M6": [(TOOL,
            "    return rel[:-4].replace(os.sep, \"/\") if rel.endswith(\".lua\") else rel",
            "    return rel.replace(os.sep, \"/\")")],
    # ---- the false-positive direction ------------------------------------
    # M7: any dotted name resolves against any module, whether it was imported
    #     or not.  This is the dangerous direction for this tool: a confident
    #     mismatch on a call that was always correct, "fixed" by the next
    #     reader, taking behaviour with it.
    "M7": [(TOOL,
            "        mod = aliases.get(head[0])\n        if mod is None:\n            return None",
            "        mod = aliases.get(head[0]) or (list(mods)[0] if mods else None)\n"
            "        if mod is None:\n            return None")],
    # M8: the export name stops having to be the LAST segment, so `U.x.f(` --
    #     a field of a module, not an export of it -- starts resolving.
    "M8": [(TOOL,
            "        if len(segs) < 2 or len(segs) > 3:\n            return None",
            "        if len(segs) < 2:\n            return None")],
    # M9: a module declaring one export at two arities stops being ambiguous,
    #     so the tool picks one at random and reports against it.
    "M9": [(TOOL,
            "            if name in table and table[name][0] != len(params):\n"
            "                table[name] = (table[name][0], table[name][1], True)\n"
            "                continue",
            "            if False:\n                continue")],
    # ---- the judgements, pinned -----------------------------------------
    # M10: ROUTED is folded back into ALLOWLIST.  The ratchet still passes
    #      trivially -- every finding is still "judged" -- but four real
    #      defects are now filed as benign, which is the whole distinction
    #      this round introduced.  Caught by the no-TEETH-in-ALLOWLIST rule.
    "M10": [(TOOL, "\nROUTED = {", "\nALLOWLIST.update({"),
            (TOOL,
             "    (\"bots/mode_team_roam_generic.lua\", \"J.Utils.SetContains\", \"UNDER\", 1, 2):\n"
             "        (1, \"TEETH: constant-false guard, strategy -- GH #452\"),\n}",
             "    (\"bots/mode_team_roam_generic.lua\", \"J.Utils.SetContains\", \"UNDER\", 1, 2):\n"
             "        (1, \"TEETH: constant-false guard, strategy -- GH #452\"),\n})\nROUTED = {}")],
    # M11: a routed row loses its issue reference.  "Routed" then means
    #      "noticed and left alone", which is how a baton gets dropped (iron
    #      rule 9's 37-round lesson).
    "M11": [(TOOL,
             "        (8, \"TEETH: runtime error, hero group -- GH #451\"),",
             "        (8, \"TEETH: runtime error, hero group\"),")],
    # M12: the COSMETIC verdict on the one OVER row is upgraded to TEETH.  An
    #      OVER argument is dropped by Lua and cannot bear behaviour; if the
    #      row ever looks behaviour-bearing the DECLARATION changed, and the
    #      answer is to re-judge it, not to relabel it.
    "M12": [(TOOL,
             "        (1, \"COSMETIC: `userSwitchedRole` is dropped by Lua; the flag has no \"",
             "        (1, \"TEETH: `userSwitchedRole` is dropped by Lua; the flag has no \"")],
    # M13: the write-only flag gains a reader in the source -- i.e. someone
    #      implemented the feature -- while the COSMETIC row stays.  The row's
    #      justification is gone and the test has to say so.
    #      ⚠ The first draft of this mutant ALSO relaxed the test's own
    #      assertion (`== 3` -> `>= 3`) and survived, which proved nothing
    #      about the tree: a file cannot catch its own oracle being weakened
    #      (charter 0EQUIV).  A well-posed mutant edits the SUBJECT only.
    "M13": [("bots/hero_selection.lua",
             "local userSwitchedRole = false",
             "local userSwitchedRole = false\nlocal _reader = userSwitchedRole")],
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
