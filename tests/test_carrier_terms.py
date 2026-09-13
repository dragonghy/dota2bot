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

sys.path.insert(0, os.path.join(ROOT, "tools", "agent"))
import stale_waits                  # noqa: E402

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
    # [director 2026-09-13, test_set.md SS HJ] A PROMOTED id has NO gate literal
    # -- deleting it is what promoting means -- so `derive_id` cannot resolve it
    # and must not be asked to.  `zusult` (SS GW) and `liondrainstop` (stable-v7)
    # were promoted in 2026-09-11 and these two lines have been red ever since,
    # handed between rounds as someone else's, because the red LOOKS like a
    # derivation bug and reads like one in every report.  It is not: the deriver
    # is answering correctly ("no gate literal found in bots/") about a shape the
    # promote removed on purpose.  This is the same family the 2026-09-13T04:3xZ
    # round named for the detectors -- any assertion pinned to
    # `J.IsSoakCandidate('<id>')` asserts a shape that id's OWN promote deletes.
    #
    # Dropping the check would retire the guard with the id, which this file's
    # own doctrine forbids.  So the claim is replaced by the one that still has
    # teeth for a promoted id: the gate literal is GONE (the promote finished)
    # and the `PROMOTED (was soak-candidate ...)` note is THERE (it was recorded).
    # A half-promote -- gate deleted, note never written, or note written while
    # the gate still stands -- fails here, and that is the real hazard.
    promoted = stale_waits.promoted_ids()
    for cand, want in [("cmrguard", "crystal_maiden"), ("zusult", "zuus"),
                       ("zusstatic", "zuus"), ("liondrainstop", "lion"),
                       ("odaoe", "obsidian_destroyer")]:
        r = ct.derive_id(tree, cand)
        if cand in promoted:
            check(r["kind"] == "unresolved" and not r["sites"],
                  "%s is PROMOTED, so it has no gate literal left to derive "
                  "(kind=%s sites=%d)" % (cand, r["kind"], len(r["sites"])))
        else:
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
    # ⚠️ THE FLOOR WAS THE WRONG SHAPE (director 2026-09-09, same defect as
    # `test_coarmed_attribution_register`'s `n >= 40` the round before).  This
    # check wants to catch a SHORT READ -- parse_arm returning three ids off a
    # 37-id line -- and a floor cannot express that: it goes red for the arm
    # string SHRINKING, which is the team doing exactly what owner P4.2 asked
    # (target <= 20).  It went red at 37.
    #
    # Counting the commas independently does express it: a short read moves the
    # two numbers apart, and a legitimate promote/return moves them together.
    want = len([s for s in arm.split(",") if s.strip()])
    check(len(ids) == want and len(ids) > 0,
          "test_set.md line 2 parsed as an arm string (%d ids from %d "
          "comma-separated fields)" % (len(ids), want))
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
    # [director 2026-09-05, test_set.md SS EX] The 08-29 restatement above
    # hardened this loop against GROWTH ("so growth cannot renumber it") but not
    # against REMOVAL, and `scoped` is still derived from the live arm string.
    # Retiring `zusstatic` from the arm string (SS EX.2, a return-to-sender, the
    # gate site in bots/ untouched) therefore reddened this line -- and the red
    # was NOT about the thing this file guards: `derive_id` still resolves
    # zusstatic -> zuus, which section 2 above asserts directly against the tree.
    # That is the SAME defect the comment block describes, one direction over: a
    # test that goes red every time the arm string is edited is re-stating the
    # arm string.  So the membership claim is split by what it can actually mean:
    #   * armed     -> it must still come out hero-scoped THROUGH the live
    #                  derivation (the original teeth, unchanged);
    #   * not armed -> the arm string cannot speak for it, so demand the claim
    #                  from the deriver + tree instead.  Retiring an id must
    #                  never silently retire the assertion that guards it.
    for cand in ("aimguard", "cmrguard", "zusult", "zusstatic",
                 "liondrainstop", "odaoe"):
        if cand in ids:
            check(cand in scoped,
                  "%s is still hero-scoped (the six replay-check derived by hand)"
                  % cand)
        elif cand in promoted:
            # [director 2026-09-13, SS HJ] Third branch: the 2026-09-05 split was
            # armed / not-armed, and "not armed" silently meant "RETURNED, gate
            # still in bots/".  A PROMOTED id is also not armed and its gate is
            # gone by design, so the else-branch below demanded a shape the
            # promote deleted.  Section 2 carries the claim that still has teeth.
            check(cand not in scoped,
                  "%s is PROMOTED, so the live arm string must not scope it"
                  % cand)
        else:
            check(ct.derive_id(tree, cand)["kind"] == "hero",
                  "%s is still hero-scoped off the tree (unarmed, so the arm "
                  "string cannot speak for it)" % cand)
    # [director 2026-09-13, test_set.md SS HJ] THIRD TIME, THIRD DIRECTION.  This
    # line used to read `check("spirit_breaker" in terms, ...)` -- a frozen
    # snapshot of the live arm string, true only while `aimguard` (the sole
    # spirit_breaker-scoped id) was armed.  RULING 33 returned `aimguard` out of
    # the test set (gate site in bots/ untouched), so no armed id is
    # spirit_breaker-scoped any more and the gate must now NOT ask about
    # spirit_breaker -- for exactly the reason it must not ask about axe.  The
    # old line called that correct behaviour a failure.
    #
    # That is the same defect the two comment blocks above describe, and the
    # reason it recurred is that both previous patches fixed an INSTANCE: growth
    # (2026-08-29), then removal in the membership loop (2026-09-05).  This one
    # is removal in the TERM LIST.  So state it as the biconditional it always
    # was -- a hero is asked about IFF some armed id is scoped to it -- which is
    # #276's actual half ("the gate must not ask about a hero NO armed id
    # needs") and which holds in both directions as ids come and go.
    claimed = set()
    for r in rows:
        if r["kind"] == "hero":
            claimed |= set(r["heroes"])
    for hero in ("spirit_breaker", "axe"):
        check((hero in terms) == (hero in claimed),
              "%s is asked about IFF an armed id is scoped to it "
              "(term=%s claimant=%s)"
              % (hero, hero in terms, hero in claimed))
    check(set(terms) <= claimed and claimed <= set(terms),
          "every term has a claimant and every claimant has a term "
          "(terms-without-claimant=%s, claimants-without-term=%s)"
          % (sorted(set(terms) - claimed), sorted(claimed - set(terms))))
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
    check(summary["unresolved"] == 0,
          "no unresolved id on the live arm string (got %d)" % summary["unresolved"])

    # --- 4. the two waves that paid for this file ----------------------------
    # [director 2026-09-13, test_set.md SS HJ] These two replays are statements
    # about W20 and W21 -- two waves that ran in 2026-08, whose arm strings are
    # FROZEN HISTORY.  They were being driven with `rows` derived from TODAY's
    # arm string, so every promote or return silently changed the input to a
    # fixed-answer question: `liondrainstop`'s promote (stable-v7) took the
    # "W20: liondrainstop 1/4" line red and it stayed red for four rounds, and
    # RULING 33's return of `aimguard` would have taken the other three with it.
    # Neither red was about what this section guards -- whether #276's defect
    # would have been CAUGHT -- and the answer to that cannot depend on what is
    # armed today.  So section 4 derives its own rows from the three ids the two
    # waves actually turned on.  ALL THREE ARE DELIBERATELY NAMED: this list is
    # historical input, so it must NOT track the live arm string.
    W20_W21_IDS = ["aimguard", "odaoe", "liondrainstop"]
    _, hist_rows, _ = ct.derive_terms(W20_W21_IDS, ROOT, tree=tree)
    # `liondrainstop` was PROMOTED (stable-v7, 2026-09-11), so its gate literal
    # is gone and the deriver correctly answers "unresolved" for it TODAY.  W20's
    # carrier terms are a fact about 2026-08, when the gate was there, so the row
    # is pinned as frozen history rather than re-derived.  ⛔ This is the ONLY
    # place a row is hand-written, and only for ids the tree can no longer speak
    # about; anything still derivable stays derived, or this section stops
    # testing the deriver and starts re-stating my own model of it.
    FROZEN_HISTORICAL_ROWS = {
        "liondrainstop": {"id": "liondrainstop", "kind": "hero",
                          "heroes": {"lion"}, "sites": [],
                          "why": "frozen: gate literal removed by the stable-v7 "
                                 "promote (2026-09-11); W20 ran with it present"},
    }
    hist_rows = [FROZEN_HISTORICAL_ROWS.get(r["id"], r) for r in hist_rows]
    for _hid in W20_W21_IDS:
        _hr = [r for r in hist_rows if r["id"] == _hid]
        check(len(_hr) == 1 and _hr[0]["kind"] == "hero",
              "W20/W21 historical row for %s is hero-scoped (%s)"
              % (_hid, _hr[0]["kind"] if _hr else "missing"))
    for label, seeds in [("W20", [947, 959, 971, 974]), ("W21", [983, 986, 995, 1138])]:
        import io
        buf = io.StringIO()
        rc = ct.assert_carrier_ids(seeds, hist_rows, pool, out=buf)
        text = buf.getvalue()
        check(rc == 1, "%s: gate REFUSES (exit 1, was exit 0 in the field)" % label)
        check("id=aimguard" in text and "verdict=ABSENT" in text,
              "%s: names aimguard ABSENT" % label)
    # #276's own worked example, digit for digit.
    import io
    buf = io.StringIO()
    ct.assert_carrier_ids([947, 959, 971, 974], hist_rows, pool, out=buf)
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
    # are genuinely generic (any hero can field one, Manta included), so an id
    # gated in illusions.lua stays `generic`.  Calling it `unresolved` would have
    # traded a wrong optimistic answer for a wrong loud one and made a correct id
    # start refusing launches with exit 2.
    # [director 2026-09-06] `illumove` was PROMOTED (stable-v4), so its gate
    # literal is gone from the tree and the deriver can no longer be asked about
    # it -- a promoted id is not a candidate.  The claim this loop makes is about
    # the illusions.lua PATH, which `illureal` still gates, so the assertion
    # keeps its teeth on a live id instead of being deleted with the promote.
    for cand in ("illureal",):
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

    # --- 10. the OVER-BROAD gate (GH #402 (b)) ------------------------------
    # `UNDRAFTABLE` refuses a term no draft can carry.  Its mirror -- a term no
    # draft can MISS -- was passing silently, and that is the direction that
    # cost a wave: `immguard`'s 128-hero disjunction read `satisfied=4/4`.  Test
    # 5 above pins the one id; these pin the SHAPE, because the next id with it
    # will not be immguard.  Synthetic rows, on the real pool: the live tree
    # offers no over-broad id (check L below is exactly that), so a test that
    # only ran against the tree would be green whether or not the gate exists.
    def gate(cand_id, heroes, seeds=(2745, 2838, 2850, 2922), the_pool=None):
        row = {"id": cand_id, "kind": "hero", "heroes": set(heroes),
               "sites": [], "why": "synthetic"}
        b = io.StringIO()
        rc = ct.assert_carrier_ids(list(seeds), [row],
                                   pool if the_pool is None else the_pool, out=b)
        return rc, b.getvalue()

    pool_by_pos = {p: [n for n, ps in pool if p in ps] for p in range(1, 6)}
    every_hero = sorted({h for rel in ct.lua_files(ROOT) if (h := tree.hero_of(rel))})

    # A. the whole pool: the degenerate case a `len(heroes) > N` threshold does
    #    catch, kept so the cheap half of the gate is pinned too.
    rc, text = gate("synth_wholepool", [n for n, _ in pool])
    check(rc == 2 and "verdict=OVER-BROAD" in text and "verdict=FULL" not in text,
          "a term covering the whole pool reads OVER-BROAD, exit 2 (got %d)" % rc)

    # B. the W36 line itself, reconstructed: the 128-hero disjunction that read
    #    `verdict=FULL satisfied=4/4` on the seeds that actually flew.
    check(len(every_hero) > 100,
          "the hero table really is ~128 wide (got %d)" % len(every_hero))
    rc, text = gate("synth_immguard_1", every_hero)
    check(rc == 2 and "verdict=OVER-BROAD" in text and "satisfied=4" not in text,
          "the 128-hero shape reads OVER-BROAD, not FULL satisfied=4/4 (got %d)" % rc)

    # C. THE case a width threshold cannot see, and the reason this gate asks
    #    Hall's question instead of counting: every hero eligible for mid is a
    #    carrier, so both mid slots are carriers in every draft.  Twelve heroes
    #    -- narrower than the `abilanc`-shaped terms the docstring promises to
    #    keep passing -- and still frozen TRUE.
    mids = pool_by_pos[2]
    check(len(mids) < 20,
          "the position-2 set is narrow enough to slip a width threshold (%d)" % len(mids))
    rc, text = gate("synth_allmid", mids)
    check(rc == 2 and "verdict=OVER-BROAD" in text,
          "covering one whole position reads OVER-BROAD at %d heroes (got %d)"
          % (len(mids), rc))

    # D. one hero short of that: the draft still cannot miss it, because each
    #    position is filled TWICE (radiant and dire) and only one free mid
    #    exists.  This is what pins PER_POSITION=2 -- a per-position demand of 1
    #    calls this missable and the gate goes quiet on it.
    rc, text = gate("synth_allmid_but_one", mids[1:])
    check(rc == 2 and "verdict=OVER-BROAD" in text,
          "one free mid is not enough for two mid slots (got %d)" % rc)

    # E. ...and two free mids IS enough, so the gate is not simply saying yes to
    #    anything position-shaped.
    check(ct.draft_can_miss(set(mids[2:]), pool) is True,
          "two free mids make the term missable again")

    # F. grounded in the drafter, not in my model of it: the real `draft()` over
    #    a seed scan must never produce a carrier-free roster for C or D, and
    #    must sometimes produce one for a single-hero term.
    scan = [seed_draft.heroes_of(s, pool) for s in range(1, 401)]
    for label, carriers in [("all mids", set(mids)), ("all mids but one", set(mids[1:]))]:
        missed = [i for i, hs in enumerate(scan) if not (hs & carriers)]
        check(not missed,
              "400 real drafts, %s: none is carrier-free (%d were)" % (label, len(missed)))
    cm_missed = [i for i, hs in enumerate(scan) if "crystal_maiden" not in hs]
    check(cm_missed,
          "control: a single-hero term IS missable in the real drafter")

    # G. a narrow real term must be unaffected -- the gate buys loudness only
    #    where loudness is also true.
    rc, text = gate("synth_cm", ["crystal_maiden"], seeds=(2838,))
    check(rc == 0 and "OVER-BROAD" not in text and "verdict=FULL" in text,
          "a one-hero term still reads FULL, exit 0 (got %d)" % rc)

    # H. positions missing => `UNCHECKED`, exit 2.  Not `OVER-BROAD` (that would
    #    name a defect this run cannot see) and not silence.
    rc, text = gate("synth_nopos", ["crystal_maiden"],
                    the_pool=[n for n, _ in pool])
    check(rc == 2 and "verdict=UNCHECKED" in text,
          "a pool with no positions reads UNCHECKED, exit 2 (got %d)" % rc)

    # I. the LIMIT is enforced, not assumed: thin a position below the draft's
    #    slot count and the model stops answering instead of guessing.
    thin = [(n, ps) for n, ps in pool if 2 not in ps] + [(n, ps) for n, ps in pool
                                                         if 2 in ps][:4]
    check(ct.draft_can_miss({"crystal_maiden"}, thin) is None,
          "a position thinner than the draft makes draft_can_miss say None")

    # L. and the live arm string must NOT trip any of this.  A gate that starts
    #    refusing today's waves would be the "always says no" failure the
    #    docstring warns about, paid for in hand-written overrides every wave.
    buf = io.StringIO()
    rc = ct.assert_carrier_ids([2745, 2838, 2850, 2922], rows, pool, out=buf)
    check("OVER-BROAD" not in buf.getvalue() and "UNCHECKED" not in buf.getvalue(),
          "no id on the live arm string is over-broad (gate is prospective)")

    failed = [lbl for ok, lbl in CHECKS if not ok]
    for ok, lbl in CHECKS:
        if not ok:
            print("FAIL %s" % lbl)
    print("carrier_terms: %d checks, %d failed" % (len(CHECKS), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
