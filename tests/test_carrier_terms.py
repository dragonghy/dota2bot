#!/usr/bin/env python3
"""Acceptance for tools/batch_test/soak/carrier_terms.py (GH #276).

The gate this feeds was not broken; it was ASKED THE WRONG QUESTION -- its terms
were hand-typed focus-five names, so W20 and W21 both armed `aimguard` over waves
that drafted zero `spirit_breaker` (180 and ~180 stamped games) and both times the
gate returned exit 0.  These checks are written against that failure, not against
the printed output: a derivation that scores 5/6 by reading gate-site filenames
would satisfy every "it prints terms" assertion and still miss the only id that
ever cost anything.

Test 1 is therefore the load-bearing one (`aimguard` resolves ACROSS files, from a
`jmz_func.lua` gate to its sole `hero_spirit_breaker.lua` consumer).  Tests 5-7
pin the failure DIRECTIONS: never invent a carrier from a comment, never call an
unresolved id generic, never flatten a multi-hero id into a conjunction.

Runs against the real tree (no fixtures): the thing under test is a claim about
this repo's call graph, and a synthetic graph would only re-assert my own model.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SOAK = os.path.join(ROOT, "tools", "batch_test", "soak")
sys.path.insert(0, SOAK)

import carrier_terms as ct          # noqa: E402
import seed_draft                   # noqa: E402

CHECKS = []


def check(cond, label):
    CHECKS.append((bool(cond), label))
    return bool(cond)


def main():
    tree = ct.Tree(ROOT)
    pool = seed_draft.load_pool()

    # --- 1. the load-bearing case: the id that actually broke -----------------
    row = ct.derive_id(tree, "aimguard")
    check(row["kind"] == "hero", "aimguard classified hero-scoped")
    check(row["heroes"] == {"spirit_breaker"},
          "aimguard carrier is spirit_breaker (got %s)" % sorted(row["heroes"]))
    check(any("jmz_func" in rel for rel, _ in row["sites"]),
          "aimguard's gate site really is in FunLib/jmz_func.lua, not a hero file")
    # If this ever passes by reading the filename, the line above is a lie.
    check(not any("hero_spirit_breaker" in rel for rel, _ in row["sites"]),
          "aimguard resolved ACROSS files (no gate literal in hero_spirit_breaker.lua)")

    # --- 2. the five that a filename read would also have found ---------------
    for cand, want in [("cmrguard", "crystal_maiden"), ("zusult", "zuus"),
                       ("zusstatic", "zuus"), ("liondrainstop", "lion"),
                       ("odaoe", "obsidian_destroyer")]:
        r = ct.derive_id(tree, cand)
        check(r["kind"] == "hero" and r["heroes"] == {want},
              "%s -> %s" % (cand, want))

    # --- 3. the live arm string derives exactly the six, and nothing else -----
    # Input it cannot read => exit 2 (did not run), never a FAIL: same 0/2/3
    # vocabulary as run_py_tests.sh, GH #243.
    try:
        with open(os.path.join(ROOT, "iterations", "streams", "test_set.md")) as fh:
            arm = fh.read().splitlines()[1]
    except (IOError, OSError, IndexError) as exc:
        print("UNCERTIFIABLE: cannot read the arm string from test_set.md (%s)" % exc)
        sys.exit(2)
    ids = ct.parse_arm(arm)
    check(len(ids) >= 40, "test_set.md line 2 parsed as an arm string (%d ids)" % len(ids))
    terms, rows, summary = ct.derive_terms(ids, ROOT, tree=tree)
    scoped = {r["id"] for r in rows if r["kind"] == "hero"}
    check(scoped == {"aimguard", "cmrguard", "zusult", "zusstatic",
                     "liondrainstop", "odaoe"},
          "hero-scoped set is exactly the six replay-check derived by hand (got %s)"
          % sorted(scoped))
    check("spirit_breaker" in terms, "spirit_breaker IS asked about")
    # The other half of #276: the gate was also asking about heroes no armed id needs.
    check("axe" not in terms and "skeleton_king" not in terms,
          "axe / skeleton_king are NOT asked about (no axe- or SK-scoped armed id)")
    check(summary["unresolved"] == 0,
          "no unresolved id on the live arm string (got %d)" % summary["unresolved"])

    # --- 4. the two waves that paid for this file ----------------------------
    for label, seeds in [("W20", [947, 959, 971, 974]), ("W21", [983, 986, 995, 1138])]:
        import io
        buf = io.StringIO()
        rc = ct.assert_carrier_ids(seeds, rows, pool, out=buf)
        text = buf.getvalue()
        check(rc == 1, "%s: gate REFUSES (exit 1, was exit 0 in the field)" % label)
        check("id=aimguard" in text and "verdict=ABSENT" in text,
              "%s: names aimguard ABSENT" % label)
    # #276's own worked example, digit for digit.
    import io
    buf = io.StringIO()
    ct.assert_carrier_ids([947, 959, 971, 974], rows, pool, out=buf)
    w20 = buf.getvalue()
    check("id=odaoe term=obsidian_destroyer seeds=4 satisfied=2" in w20,
          "W20: odaoe 2/4 (as #276 predicted)")
    check("id=liondrainstop term=lion seeds=4 satisfied=1" in w20,
          "W20: liondrainstop 1/4 (as #276 predicted)")

    # --- 5. failure direction: comments must not manufacture carriers --------
    # hero_spirit_breaker.lua:293 names J.CanBeAttackedPair in prose one line
    # above the real call; a naive scan reads that as a call site.
    check(ct.strip_line_comment("\tif J.Foo(a) then -- J.Bar(b)") == "\tif J.Foo(a) then ",
          "strip_line_comment drops the comment, keeps the code")
    check(ct.strip_line_comment("local s = '-- not a comment'") ==
          "local s = '-- not a comment'",
          "strip_line_comment respects quoted '--'")
    fake = ct.Tree.from_lines({
        "bots/FunLib/jmz_func.lua": ["function J.OnlyProse()", "\tif J.IsSoakCandidate( 'zz' ) then end", "end"],
        "bots/BotLib/hero_lich.lua": ["\t-- J.OnlyProse() is what we would call here"],
        "bots/mode_farm_generic.lua": ["\tJ.OnlyProse()"],
    })
    r = ct.derive_id(fake, "zz")
    check(r["kind"] == "generic",
          "a prose-only mention in a hero file does not make that hero a carrier (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))

    # --- 6. failure direction: unresolved is not generic ---------------------
    fake2 = ct.Tree.from_lines({"bots/FunLib/jmz_func.lua": ["-- nothing gates 'ghost' anywhere"]})
    r = ct.derive_id(fake2, "ghost")
    check(r["kind"] == "unresolved",
          "an id with no findable gate literal is unresolved, not generic")
    # and the CLI turns that into a refusal, not a pass
    rc = subprocess.call([sys.executable, os.path.join(SOAK, "carrier_terms.py"),
                          "--arm", "ghost_id_that_does_not_exist"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    check(rc == 2, "CLI exits 2 on an unresolved id (unchecked != passed)")

    # --- 7. failure direction: multi-hero ids are a disjunction --------------
    fake3 = ct.Tree.from_lines({
        "bots/FunLib/jmz_func.lua": ["function J.ManyHeroes()", "\tif J.IsSoakCandidate( 'many' ) then end", "end"],
        "bots/BotLib/hero_lich.lua": ["\tJ.ManyHeroes()"],
        "bots/BotLib/hero_sven.lua": ["\tJ.ManyHeroes()"],
    })
    r3 = ct.derive_id(fake3, "many")
    check(r3["heroes"] == {"lich", "sven"}, "multi-hero id collects both carriers")
    buf = io.StringIO()
    # sven is in the pool and drafted by seed 986; lich is not drafted there.
    rc = ct.assert_carrier_ids([986], [r3], pool, out=buf)
    check(rc == 0, "ONE carrier present satisfies a multi-hero id (disjunction, not conjunction)")
    check("term=lich|sven" in buf.getvalue(), "multi-hero term prints as a disjunction")

    # --- 8. undraftable carriers are named, not silently ABSENT -------------
    fake4 = ct.Tree.from_lines({
        "bots/FunLib/jmz_func.lua": ["function J.RubickOnly()", "\tif J.IsSoakCandidate( 'rb' ) then end", "end"],
        "bots/FunLib/rubick_hero/axe.lua": ["\tJ.RubickOnly()"],
    })
    r4 = ct.derive_id(fake4, "rb")
    check(r4["heroes"] == {"rubick"},
          "rubick_hero/<x>.lua carries rubick, not <x> (got %s)" % sorted(r4["heroes"]))
    buf = io.StringIO()
    rc = ct.assert_carrier_ids([947], [r4], pool, out=buf)
    check(rc == 1 and "UNDRAFTABLE" in buf.getvalue(),
          "a carrier outside hero_pool.txt reads UNDRAFTABLE, not ABSENT")

    # --- 9. the old gate still behaves byte-for-byte ------------------------
    buf = io.StringIO()
    rc = seed_draft.assert_carrier([947], [("crystal_maiden", None)], pool, out=buf)
    check(rc == 0 and "CARRIER_GATE terms=1 seeds=1 exit=0" in buf.getvalue(),
          "--assert-carrier's own output is unchanged")

    failed = [lbl for ok, lbl in CHECKS if not ok]
    for ok, lbl in CHECKS:
        if not ok:
            print("FAIL %s" % lbl)
    print("carrier_terms: %d checks, %d failed" % (len(CHECKS), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
