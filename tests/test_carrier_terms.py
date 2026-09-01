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
    # [director 2026-08-29, GH #221/#276] These two checks used to be FROZEN
    # SNAPSHOTS of the live arm string -- "exactly these six" and "skeleton_king
    # is not asked about".  Admitting `odbuild`+`wkqdmg` (test_set.md SS CE)
    # reddened both, and NEITHER red was about the thing this file guards: the
    # derivation did its job, resolving odbuild -> obsidian_destroyer and wkqdmg
    # -> skeleton_king with unresolved == 0.  A test that goes red every time the
    # arm string it reads is edited is re-stating the arm string, not checking
    # the deriver -- the same defect corpus_scale.lua was written for, one domain
    # over.  So the claims are restated as INVARIANTS over whatever is armed:
    #   * the six replay-check derived by hand must never silently stop being
    #     hero-scoped (membership, so growth cannot renumber it);
    #   * #276's actual half -- the gate must not ask about a hero NO armed id
    #     needs -- becomes "every term has a claimant", which is what that
    #     sentence meant and which keeps holding as ids come and go.
    for cand in ("aimguard", "cmrguard", "zusult", "zusstatic",
                 "liondrainstop", "odaoe"):
        check(cand in scoped,
              "%s is still hero-scoped (the six replay-check derived by hand)" % cand)
    check("spirit_breaker" in terms, "spirit_breaker IS asked about")
    # ⚠️ NOT written as `set(terms) == {h for r in rows ...}`.  That was the first
    # draft and it is a TAUTOLOGY: derive_terms builds `terms` by exactly that
    # comprehension (carrier_terms.py:293), so the check could not fail and would
    # have replaced a real assertion with a green light.  #276's claim -- the term
    # list is DERIVED from what is armed, not hand-maintained -- only has content
    # against an arm string that differs from the live one, so it is tested that
    # way: drive the deriver with synthetic sets and demand the terms track them.
    for probe, want in [(["cmrguard"], {"crystal_maiden"}),
                        (["wkqdmg"], {"skeleton_king"}),
                        (["cmrguard", "zusult", "zusstatic"],
                         {"crystal_maiden", "zuus"}),
                        (["teambrain"], set())]:
        t2, _, _ = ct.derive_terms(probe, ROOT, tree=tree)
        check(set(t2) == want,
              "terms track the armed set, not a hand list: %s -> %s (want %s)"
              % (probe, sorted(t2), sorted(want)))
    # The founding instance, kept as an instance: no armed id is axe-scoped, so
    # the gate must not ask about axe.  (skeleton_king WAS in this line until
    # `wkqdmg` was admitted -- it is asked about now, correctly, which is exactly
    # why the frozen pair had to go.)
    check("axe" not in terms, "axe is NOT asked about (no axe-scoped armed id)")
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

    # --- 10. minion_lib carriers (GH #402) ----------------------------------
    # `immguard`'s gate lives in bots/FunLib/minion_lib/primal_split.lua, which
    # every hero reaches through the generic dispatcher aba_minion.lua.  The
    # reachability walk therefore answered "all 128 heroes", seed_draft.py
    # evaluated that as ONE disjunction, and the gate read
    # `verdict=FULL satisfied=4/4` on a wave that drafted no brewmaster -- and
    # cannot, since brewmaster is not in hero_pool.txt.  Frozen TRUE, failing
    # toward optimism, on precisely the check GH #276 built to stop this.
    r_imm = ct.derive_id(tree, "immguard")
    check(r_imm["kind"] == "hero" and r_imm["heroes"] == {"brewmaster"},
          "immguard carries brewmaster alone (got %s %s)"
          % (r_imm["kind"], sorted(r_imm["heroes"])))
    buf = io.StringIO()
    rc = ct.assert_carrier_ids([2745, 2838, 2850, 2922], [r_imm], pool, out=buf)
    check(rc == 1 and "UNDRAFTABLE" in buf.getvalue() and "FULL" not in buf.getvalue(),
          "immguard reads UNDRAFTABLE, verbatim as its sibling tormself did")
    # The general statement, not just this instance: no hero-scoped id may claim
    # a carrier set so wide that a ten-hero draft cannot miss it.  A term wider
    # than the draft is not a carrier term, it is `generic` wearing one.
    widest = max(((r["id"], len(r["heroes"])) for r in rows if r["kind"] == "hero"),
                 key=lambda kv: kv[1], default=("none", 0))
    check(widest[1] <= 10,
          "a hero-scoped id claims %d carriers (%s) -- wider than a draft, so its "
          "gate cannot fail" % (widest[1], widest[0]))
    # ...and the fix must not have bought loudness with correctness.  Illusions
    # are genuinely generic (any hero can field one, Manta included), so the two
    # ids gated in illusions.lua stay `generic`.  Calling them `unresolved`
    # would have traded a wrong optimistic answer for a wrong loud one and made
    # two correct ids start refusing launches with exit 2.
    for cand in ("illumove", "illureal"):
        check(ct.derive_id(tree, cand)["kind"] == "generic",
              "%s is generic by construction, not unresolved" % cand)
    # An UNMAPPED summon file resolves loud, never optimistic: walking on from
    # there reaches aba_minion.lua and re-answers "every hero".
    kind, heroes, _trail = ct._resolve_site(
        tree, "bots/FunLib/minion_lib/jugg.lua", 7, 0, frozenset(), [])
    check(kind == "unresolved" and not heroes,
          "an unmapped minion file resolves unresolved (got %s %s)"
          % (kind, sorted(heroes)))
    # Every MINION_OWNER entry must be EARNED BY THE FILE -- the owner's units
    # or ability named in its text.  This is what stops the table being
    # "finished" from memory: `jugg.lua` is obviously Juggernaut's Healing Ward
    # to a Dota player and names neither, which is the exact reading the
    # rubick_hero case exists to warn against.
    for fname, owner in ct.MINION_OWNER.items():
        path = os.path.join(ROOT, "bots", "FunLib", "minion_lib", fname)
        check(os.path.isfile(path), "MINION_OWNER names a missing file: %s" % fname)
        with open(path, encoding="utf-8", errors="replace") as fh:
            body = fh.read()
        check(owner in body,
              "MINION_OWNER[%s]=%s is not evidenced by the file itself" % (fname, owner))

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
