#!/usr/bin/env bash
# Mutation stand for the hero-name-guard narrowing in
# tools/batch_test/soak/carrier_terms.py (director 2026-09-04, GH #473 甲).
# Not part of any suite -- run by hand when the narrowing or
# tests/test_carrier_hero_guard.py is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- the test writes to a log file and `$?` is
#     read with no pipe between it and the command;
#   * a mutant whose target string is absent ABORTS, because a no-op edit
#     scored as "caught" is the stand lying about what was on the bench;
#   * __pycache__ is purged between mutants: the test imports `carrier_terms`
#     as a module, and a stale .pyc means the mutant on the bench is not the
#     mutant in the interpreter (that is how mutstand_pending_rulings.sh once
#     scored M8 by M7's failure signature).
#
# ⭐ AND THE ONE THIS STAND IS WRITTEN AROUND (test_set.md §EE.5): "the stand
# reported 7 of 7 CAUGHT" is a claim about the SET, not about any single check.
# A mutant can be caught by a neighbouring assertion while the check advertised
# as pinning that behaviour passes right through it.  So this stand prints the
# FAIL lines of every mutant, and the reader is expected to check that the
# check which DIED is the one the mutant was aimed at.  M12 is the range
# control: it must SURVIVE, or the stand is measuring "any edit reddens".
#
# Usage: bash tools/agent/mutstand_carrier_hero_guard.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/batch_test/soak/carrier_terms.py
TEST=tests/test_carrier_hero_guard.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_chg.XXXXXX")

cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }

restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || {
        echo "RESTORE FAILED -- $SRC does not match its pre-mutation checksum"; exit 2; }
}

# An interrupted stand otherwise leaves the MUTANT in the working tree, where
# the next `git add -A` commits it (GH #418 is that exact accident).
trap restore EXIT

apply_mutant() {   # $1 = mutant id; writes the mutated source or exits non-zero
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # M1: delete the hook -- the pre-fix behaviour, verbatim.  Aimed at check 1
    #     (rotscope) and at "pudge in terms".
    "M1": ('''    if guard:
        return "hero", set(guard), trail + [
            "%s:%d(hero-name guard: %s)" % (rel, lineno, ",".join(sorted(guard)))]''',
           "    if False:\n        pass"),
    # M2a: read `~=` as a domain.  Aimed at D2b.
    # ⭐ THE FIRST VERSION OF THIS MUTANT SURVIVED, and that survival is the
    # most useful thing this stand has produced: D2 (`if botName ~= 'huskar'`,
    # no `==` anywhere) is satisfied by the base rule alone, so deleting the
    # `~=` clause changed nothing there.  The clause only bites on a MIXED
    # condition -- which is the shape the tree holds -- so D2b was written and
    # the mutant re-aimed.  A check that passes under the mutant is not pinning
    # the behaviour it is named after.
    "M2a": ('    if "~=" in cond or re.search(r"\\bnot\\b", cond) or "==" not in cond:',
            '    if re.search(r"\\bnot\\b", cond) or "==" not in cond:'),
    # M2b: the same for `not (...)`, which inverts an `==` without writing `~=`.
    #      Aimed at D2c.
    "M2b": ('    if "~=" in cond or re.search(r"\\bnot\\b", cond) or "==" not in cond:',
            '    if "~=" in cond or "==" not in cond:'),
    # M3: let the else-branch inherit the if's hero.  Aimed at D3.
    "M3": ('''                elif tok == "else":
                    if not stack:
                        return frozenset(), "unbalanced"
                    stack[-1] = frozenset()''',
           '''                elif tok == "else":
                    if not stack:
                        return frozenset(), "unbalanced"'''),
    # M4: `elseif` opens a new frame instead of replacing the top one.  The
    #     conjunction then intersects pudge with zuus.  Aimed at D4.
    "M4": ('''                    if kind == "elseif":
                        if not stack:
                            return frozenset(), "unbalanced"
                        stack[-1] = heroes
                    else:
                        stack.append(heroes)''',
           "                    stack.append(heroes)"),
    # M5: blocks never close.  Depth stays right-ish, scope does not.  Aimed at
    #     D5 (a gate after the guard's `end`).
    "M5": ('''                elif tok in ("end", "until"):
                    if not stack:
                        return frozenset(), "unbalanced"
                    stack.pop()''',
           '''                elif tok in ("end", "until"):
                    pass'''),
    # M6: an unmappable unit name goes quiet instead of loud.  Aimed at D6.
    "M6": ('''        if unmapped:
            return frozenset(unmapped), "unmapped"''',
           "        if False:\n            pass"),
    # M7: unfollowable structure goes quiet instead of loud.  Aimed at D7.
    "M7": ('''    if gstatus == "unbalanced":
        return "unresolved", set(), trail + [
            "%s:%d(block structure not followable; guard unchecked)" % (rel, lineno)]''',
           "    if False:\n        pass"),
    # M8: count block keywords inside string literals.  Aimed at D8.
    "M8": ("            scan = blank_strings(raw)", "            scan = raw"),
    # M9: `for ... do` counted as one block instead of the `do` opening it, so
    #     the loop's `end` closes the guard.  Aimed at D9.
    "M9": ('''                elif tok == "do":
                    stack.append(frozenset())
                    expect_do = max(0, expect_do - 1)''',
           '''                elif tok == "do":
                    expect_do = max(0, expect_do - 1)'''),
    # M10: SECOND RANGE CONTROL -- it must SURVIVE, and the reason is a
    #      property of Lua, not an omission in the tests.  Starting the scan at
    #      the top of the FILE instead of at the enclosing definition can only
    #      differ if some earlier top-level chunk fails to balance, and a Lua
    #      file whose top-level blocks do not balance does not load at all.  So
    #      the start line is a WORK BOUND, not a semantic choice.  Measured, not
    #      argued: with this mutant applied out of tree, the full derivation
    #      over the live 62-id arm string is BYTE-IDENTICAL to the baseline
    #      (`diff` exit 0, 2026-09-04).  Writing a check that killed it would be
    #      pinning an implementation detail as if it were behaviour.
    "M10": ("        for idx in range((def_line or 1) - 1, lineno - 1):",
            "        for idx in range(0, lineno - 1):"),
    # M11: ask the guard AFTER the generic exits, i.e. too late to matter for
    #      any gate at file scope or in a dispatch entry.  Aimed at check 1 by
    #      way of ordering rather than content.
    "M11": ('''    guard, gstatus = tree.hero_guard_scope(rel, lineno)''',
            '''    guard, gstatus = frozenset(), "ok"'''),
    # M12: RANGE CONTROL.  Wording only -- it must SURVIVE.  If it is caught,
    #      some check is asserting on prose and the stand is measuring noise.
    "M12": ('"%s:%d(hero-name guard: %s)"', '"%s:%d(hero guard, narrowed: %s)"'),
}
old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

echo "== mutation stand: $SRC / $TEST"
worst=0
for m in M1 M2a M2b M3 M4 M5 M6 M7 M8 M9 M10 M11 M12; do
    purge_pyc
    if ! apply_mutant "$m"; then
        echo "$m  APPLY-FAILED -- stand aborted rather than score a no-op as caught"
        restore; exit 2
    fi
    python3 "$TEST" > "$WORK/$m.log" 2>&1
    rc=$?                                  # bare: no pipe between test and $?
    sha=$(sha256sum "$SRC" | cut -c1-12)
    if [ "$m" = "M12" ] || [ "$m" = "M10" ]; then
        if [ "$rc" -eq 0 ]; then
            echo "$m  SURVIVED (sha=$sha) -- CORRECT: range control (see its note)"
        else
            echo "$m  CAUGHT   (sha=$sha, exit $rc) -- WRONG: a range control died"
            worst=3
        fi
    elif [ "$rc" -eq 0 ]; then
        echo "$m  SURVIVED (sha=$sha) -- the tests do not pin this behaviour"
        worst=3
    else
        echo "$m  CAUGHT   (sha=$sha, exit $rc)"
    fi
    grep -E "^[a-z_]+: [0-9]+ checks|^FAIL" "$WORK/$m.log" | sed 's/^/       /'
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
rc=$?
echo "baseline after restore: exit $rc :: $(head -1 "$WORK/baseline.log")"
[ "$rc" -eq 0 ] || { echo "BASELINE RED after restore -- the stand left damage"; exit 2; }
exit $worst
