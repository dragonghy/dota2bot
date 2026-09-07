#!/usr/bin/env python3
"""Acceptance for the hero-name-guard narrowing in carrier_terms.py (GH #473 甲).

WHAT WAS WRONG.  `carrier_terms.py` derives an id's domain by walking consumers
and reading the FILE each one lives in: `bots/BotLib/hero_x.lua` => hero x,
anything else => generic.  That reading is blind to a second shape -- a gate
written in a generic file whose domain is nonetheless ONE hero, because a
hero-name literal in an enclosing `if` decides whether the line runs:

    bots/mode_roam_generic.lua:1038   if botName == 'npc_dota_hero_pudge' then
    bots/mode_roam_generic.lua:1039       ... J.IsSoakCandidate('rotscope')

`generic` is the one class the carrier gate EXEMPTS, so the gate built to
refuse a wave whose draft cannot carry an armed id had nothing to say about
`rotscope`.  W44 is the measured instance: 7 terms derived, `pudge` absent, and
the wave carried Pudge (96/207 games) only because the seeds happened to.  Such
an id can read zero wave after wave with nothing raising a hand.

WHAT THESE CHECKS ARE WRITTEN AGAINST.  Not "it prints pudge" -- an
implementation that simply grepped `npc_dota_hero_` anywhere in the enclosing
function would also print pudge, and would additionally invent carriers out of
`botName ~= 'npc_dota_hero_huskar'` and out of lines sitting AFTER the guard's
`end`.  So the load-bearing checks are the ones that separate a real lexical
scope from a proximity match (LAYER 2 D4/D5/D8), and the ones that pin the
failure DIRECTIONS: an unmappable unit name and an unfollowable block both
resolve `unresolved` (loud), never `generic` (silent) and never a fabricated
term (confident and wrong).

LAYER 1 runs against the real tree, because the claim "rotscope is Pudge-only"
is a claim about THIS repo.  LAYER 2 drives synthetic trees, because the shapes
that must NOT narrow (`~=`, `else`, after-`end`) are shapes this tree happens
not to hold next to a gate literal today -- and "today" is not an acceptance.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SOAK = os.path.join(ROOT, "tools", "batch_test", "soak")
sys.path.insert(0, SOAK)

import carrier_terms as ct          # noqa: E402

CHECKS = []
GEN = "bots/mode_synth_generic.lua"


def check(cond, label):
    CHECKS.append((bool(cond), label))
    return bool(cond)


def synth(body):
    """Tree over one generic file plus the two hero files used as carriers.

    The hero files exist so `has_hero_file` can answer; they are never walked,
    because a positive guard short-circuits before the caller walk begins.
    """
    lines = {
        GEN: body.splitlines(),
        "bots/BotLib/hero_pudge.lua": ["-- carrier file, not walked"],
        "bots/BotLib/hero_zuus.lua": ["-- carrier file, not walked"],
        # huskar is here ON PURPOSE, for D2b.  Without it, a `~=` clause that
        # wrongly narrowed would land on `unmapped` (no carrier file in this
        # synthetic tree) and D2b would fail for the RIGHT reason by accident --
        # the mutation stand's first run showed exactly that signature.  With
        # the file present, the wrong answer is the dangerous one -- the term
        # `huskar`, naming the single hero the line excludes -- so the check
        # dies of what it is named after.
        "bots/BotLib/hero_huskar.lua": ["-- carrier file, not walked"],
    }
    return ct.Tree.from_lines(lines, ROOT)


def main():
    tree = ct.Tree(ROOT)

    # ================= LAYER 1: the real tree =============================
    # 1. the id that paid for this file
    row = ct.derive_id(tree, "rotscope")
    check(row["kind"] == "hero", "rotscope classified hero-scoped (got %s)" % row["kind"])
    check(row["heroes"] == {"pudge"},
          "rotscope carrier is pudge (got %s)" % sorted(row["heroes"]))
    # If it ever passes by reading a filename, this line is a lie.
    check(row["sites"] and all("BotLib/hero_" not in rel for rel, _ in row["sites"]),
          "rotscope's only gate literal is in a GENERIC file (%s)"
          % [rel for rel, _ in row["sites"]])
    check(any("mode_roam_generic" in rel for rel, _ in row["sites"]),
          "rotscope's gate site is mode_roam_generic.lua")

    # 2. NO OVER-REACH: three ids whose gate literals sit in the SAME FILE as
    #    rotscope's, outside any hero guard, must stay generic.  A narrowing
    #    that keyed on the file, or on "a hero name appears somewhere above",
    #    would drag these in and start demanding pudge for all of them.
    for cand in ("pullcad", "pullthink", "creepthink"):
        r = ct.derive_id(tree, cand)
        check(r["kind"] == "generic",
              "%s stays generic -- same file as rotscope, no guard (got %s %s)"
              % (cand, r["kind"], sorted(r["heroes"])))

    # 3. the live arm string gains a term and loses nothing.  `unresolved == 0`
    #    is the load-bearing half: this change can only be shipped if it does
    #    not turn today's waves loud, and a bare "pudge in terms" would not say
    #    that.
    #
    #    STATED AS THE DIFFERENTIAL IT IS, and the reason is a red this file
    #    served on 2026-09-07.  "Loses nothing" was first written as a
    #    hardcoded roster of the seven terms the live string happened to derive
    #    the day GH #473 landed -- and a roster is a claim about WHICH IDS ARE
    #    ARMED, not about this change.  Promoting `ckpush` (stable-v5) retired
    #    the last id carrying `chaos_knight`, the roster's term vanished for
    #    exactly the right reason, and the assertion went red pointing at a file
    #    the promote never touched.  Every future promote could do it again.
    #    `pullcad` and GH #579 are the same family: gate, data and both sides
    #    each correct, with the convention between them never written down.
    #
    #    So take the baseline instead of freezing it.  `hero_guard_scope` IS the
    #    whole of GH #473 甲 -- a tree that declines to narrow falls through
    #    `_resolve_site` to the pre-existing file-path reading -- so deriving
    #    the SAME live ids both ways measures the change and nothing else.  What
    #    survives a promote is the shape of the delta, not its contents.
    with open(os.path.join(ROOT, "iterations/streams/test_set.md"), encoding="utf-8") as fh:
        arm = fh.read().splitlines()[1]
    ids = ct.parse_arm(arm)
    terms, rows, summary = ct.derive_terms(ids, ROOT, tree=tree)

    pre = ct.Tree(ROOT)
    pre.hero_guard_scope = lambda rel, lineno: (frozenset(), "ok")
    base_terms, _base_rows, base_summary = ct.derive_terms(ids, ROOT, tree=pre)

    check(summary["unresolved"] == 0,
          "live arm string derives 0 unresolved (got %d)" % summary["unresolved"])
    # If the BASELINE is loud, the delta below is not a reading of this change.
    check(base_summary["unresolved"] == 0,
          "the pre-change reading is quiet too, so the delta is attributable "
          "(got %d unresolved)" % base_summary["unresolved"])

    lost = sorted(set(base_terms) - set(terms))
    gained = sorted(set(terms) - set(base_terms))
    # Not true by construction: narrowing short-circuits the caller walk, so a
    # site that resolves `unmapped`/`unbalanced` drops an id to `unresolved` and
    # takes its file-path terms with it.
    #
    # ⚠️ BOUNDARY, measured 2026-09-07 and not inferred: on TODAY's tree this
    # check cannot fail, so it buys nothing today.  Exactly one live id changes
    # reading under narrowing (`rotscope`: generic/[] -> hero/[pudge]), and a
    # baseline of `generic` carries no terms, so there is nothing available to
    # lose.  Two mutation stands agree -- breaking the scanner (-> unbalanced)
    # and forcing a wrong-but-mapped hero were both caught, by OTHER checks,
    # with `lost` silent in both.  It is a ratchet for the tree where a second
    # id narrows, and it should be read as one until this note is re-measured.
    check(not lost,
          "the narrowing loses no term the file-path reading already had "
          "(lost %s)" % lost)

    if "rotscope" in ids:
        check(gained == ["pudge"],
              "the narrowing gains exactly pudge on the live arm string "
              "(gained %s)" % gained)
    else:
        # The measured instance left the live string (promoted or retired), so
        # the arm string can no longer buy this claim.  Say so out loud and put
        # the weight back on the real-tree claim in LAYER 1.1, which never
        # depended on what is armed.
        print("NOTE rotscope is no longer armed; the gain is claimed on the "
              "real tree instead (gained on the live string: %s)" % gained)
        check(ct.derive_id(tree, "rotscope")["heroes"] == {"pudge"},
              "rotscope still narrows to pudge on the real tree, which is where "
              "the gain is claimed once it leaves the arm string")

    # 4. the multi-line condition that is NOT a failure.  `creepthink`'s gate
    #    literal sits INSIDE a three-line `if` condition, so at the gate line
    #    the scanner is mid-condition.  That condition guards the lines below
    #    it, not itself; reading it as unbalanced would have made a correct,
    #    common shape go loud.  (The prototype of this rule did exactly that.)
    guard, status = tree.hero_guard_scope("bots/mode_roam_generic.lua", 265)
    check(status == "ok" and not guard,
          "a gate inside a multi-line `if` condition reads ok/no-guard (got %s %s)"
          % (status, sorted(guard)))

    # 5. the bear block, and the LIMIT it measures.  This check was WRITTEN
    #    expecting `unmapped` -- and the tree said otherwise:
    #    `bots/BotLib/hero_lone_druid_bear.lua` exists, so the unit really does
    #    have a carrier file and the guard narrows to `lone_druid_bear`.  That
    #    term is not in hero_pool.txt, so a gate there would read UNDRAFTABLE
    #    for a line the bear can run whenever lone_druid is drafted.  Pinned as
    #    it IS, not as it was assumed: `hero_of()` already answers
    #    `lone_druid_bear` for gates inside that file, so this rule inherits the
    #    file-path convention instead of inventing a second one, and the day
    #    that convention is revisited this check is where it comes due.
    guard, status = tree.hero_guard_scope("bots/mode_roam_generic.lua", 971)
    check(status == "ok" and guard == {"lone_druid_bear"},
          "the bear guard narrows to lone_druid_bear, matching hero_of on that "
          "unit's own file (got %s %s)" % (status, sorted(guard)))
    check(os.path.exists(os.path.join(ROOT, "bots/BotLib/hero_lone_druid_bear.lua")),
          "and it reads ok only BECAUSE that carrier file exists")

    # ================= LAYER 2: shapes the tree does not hold today ========
    # D1 drive: the positive guard narrows, end to end through derive_id.
    t = synth("""
function X.Think()
	if botName == 'npc_dota_hero_pudge' then
		if J.IsSoakCandidate('synthpos') then return end
	end
end
""")
    r = ct.derive_id(t, "synthpos")
    check(r["kind"] == "hero" and r["heroes"] == {"pudge"},
          "D1 positive guard narrows (got %s %s)" % (r["kind"], sorted(r["heroes"])))

    # D2 drive: `~=` is not a domain.  `botName ~= 'npc_dota_hero_huskar'`
    # appears all over this codebase and means "everyone but huskar" -- a
    # narrowing read of it would name the ONE hero that cannot run the line.
    t = synth("""
function X.Think()
	if botName ~= 'npc_dota_hero_huskar' then
		if J.IsSoakCandidate('synthneg') then return end
	end
end
""")
    r = ct.derive_id(t, "synthneg")
    check(r["kind"] == "generic" and not r["heroes"],
          "D2 `~=` guard does not narrow (got %s %s)" % (r["kind"], sorted(r["heroes"])))

    # D2b drive: THE ONE THAT ACTUALLY PAYS FOR THE `~=` CLAUSE.  D2 above is
    # satisfied by the base rule alone ("no `==` in the condition, so no
    # narrowing") -- the first mutation stand proved it, by deleting the `~=`
    # clause and watching D2 pass anyway.  The clause earns its place only on a
    # MIXED condition, which is the shape this tree actually holds
    # (mode_roam_generic.lua:1587-1589 excludes three heroes inside a larger
    # test): an `==` elsewhere makes the condition eligible, and the hero
    # literal sitting behind `~=` is then the one hero that CANNOT run the line.
    t = synth("""
function X.Think()
	if bot:GetLevel() == 6 and botName ~= 'npc_dota_hero_huskar' then
		if J.IsSoakCandidate('synthmixed') then return end
	end
end
""")
    r = ct.derive_id(t, "synthmixed")
    check(r["kind"] == "generic" and not r["heroes"],
          "D2b a mixed `==` / `~=` condition names no carrier -- least of all "
          "the excluded hero (got %s %s)" % (r["kind"], sorted(r["heroes"])))

    # D2c drive: same argument for `not (...)`, which inverts an `==` without
    # ever writing `~=`.
    t = synth("""
function X.Think()
	if not (botName == 'npc_dota_hero_pudge') then
		if J.IsSoakCandidate('synthnot') then return end
	end
end
""")
    r = ct.derive_id(t, "synthnot")
    check(r["kind"] == "generic" and not r["heroes"],
          "D2c `not (botName == ...)` does not narrow (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))

    # D3 drive: the `else` branch is the negation, so it narrows to nothing.
    t = synth("""
function X.Think()
	if botName == 'npc_dota_hero_pudge' then
		return
	else
		if J.IsSoakCandidate('syntheise') then return end
	end
end
""")
    r = ct.derive_id(t, "syntheise")
    check(r["kind"] == "generic" and not r["heroes"],
          "D3 else-branch does not inherit the if's hero (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))

    # D4 drive: `elseif` narrows to ITS OWN hero, not the one above it.  A
    # scanner that only remembered the first condition would answer pudge here.
    t = synth("""
function X.Think()
	if botName == 'npc_dota_hero_pudge' then
		return
	elseif botName == 'npc_dota_hero_zuus' then
		if J.IsSoakCandidate('syntheif') then return end
	end
end
""")
    r = ct.derive_id(t, "syntheif")
    check(r["kind"] == "hero" and r["heroes"] == {"zuus"},
          "D4 elseif narrows to its own hero (got %s %s)" % (r["kind"], sorted(r["heroes"])))

    # D5 drive: SCOPE REALLY CLOSES.  The gate here sits after the guard's
    # `end`, in the same function, a few lines below a hero literal.  This is
    # the check that separates a lexical scope from proximity, and it is the
    # one a net-delta block counter (depth right, frame identity wrong) fails.
    t = synth("""
function X.Think()
	if botName == 'npc_dota_hero_pudge' then
		bot:Action_AttackUnit(t, false)
	end
	if J.IsSoakCandidate('synthafter') then return end
end
""")
    r = ct.derive_id(t, "synthafter")
    check(r["kind"] == "generic" and not r["heroes"],
          "D5 a gate AFTER the guard's `end` is not narrowed (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))

    # D6 drive: FAILURE DIRECTION -- an unmappable unit name resolves loud, and
    # specifically NOT generic (silent) and NOT a term (confident and wrong).
    # The name is real: `bots/FunLib/aba_matchups.lua:66` holds
    # `npc_dota_hero_outworld_destroyer`, while the pool and BotLib both call
    # that hero `obsidian_destroyer`.  A term built by pattern would look right.
    t = synth("""
function X.Think()
	if botName == 'npc_dota_hero_outworld_destroyer' then
		if J.IsSoakCandidate('synthood') then return end
	end
end
""")
    r = ct.derive_id(t, "synthood")
    check(r["kind"] == "unresolved" and not r["heroes"],
          "D6 unmappable unit name resolves unresolved (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))
    # ...and the reason travels: `derive_id` keeps only kind per site, so the
    # sentence naming the missing carrier is read where it is produced.
    kind, heroes, trail = ct._resolve_site(t, GEN, 4, 0, frozenset(), [])
    check(kind == "unresolved" and not heroes
          and any("no bots/BotLib/hero_*.lua carrier" in step for step in trail),
          "D6 the trail says WHY it could not resolve (got %s)" % trail)

    # D7 drive: FAILURE DIRECTION -- block structure the scanner cannot follow
    # is `unresolved`, not `generic`.  An unchecked guard is not an absent one.
    # Two stray `end`s, because one is closed by the `function` itself -- a
    # detail the first draft of this check got wrong, and the check caught.
    t = synth("""
function X.Think()
	end
	end
	if J.IsSoakCandidate('synthunbal') then return end
end
""")
    r = ct.derive_id(t, "synthunbal")
    check(r["kind"] == "unresolved",
          "D7 unfollowable block structure resolves unresolved (got %s)" % r["kind"])

    # D8 drive: a string literal holding a block keyword must not move the
    # stack.  `'defend'` contains no word-boundary `end`, but `'... end ...'`
    # in a chat line does, and it would close the guard one block early --
    # silently handing the gate below it back to `generic`.
    t = synth("""
function X.Think()
	if botName == 'npc_dota_hero_pudge' then
		bot:ActionImmediate_Chat('push and end it', true)
		if J.IsSoakCandidate('synthstr') then return end
	end
end
""")
    r = ct.derive_id(t, "synthstr")
    check(r["kind"] == "hero" and r["heroes"] == {"pudge"},
          "D8 `end` inside a string does not close the guard (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))

    # D9 drive: an inner `for ... do ... end` inside the guard leaves the guard
    # standing.  `for` and its `do` are ONE block, not two.
    t = synth("""
function X.Think()
	if botName == 'npc_dota_hero_pudge' then
		for _, u in pairs(units) do
			bot:Action_AttackUnit(u, false)
		end
		if J.IsSoakCandidate('synthfor') then return end
	end
end
""")
    r = ct.derive_id(t, "synthfor")
    check(r["kind"] == "hero" and r["heroes"] == {"pudge"},
          "D9 an inner for/do/end leaves the guard standing (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))

    # D10 drive: a guard in a CALLER narrows too.  This is the shape `aimguard`
    # made load-bearing for the file-path reading (gate in jmz_func, consumer
    # in a hero file) -- here the consumer is a generic file's guarded branch,
    # so the same walk has to carry the same answer.
    t = synth("""
function X.Helper()
	if J.IsSoakCandidate('synthcall') then return true end
	return false
end

function X.Think()
	if botName == 'npc_dota_hero_zuus' then
		if X.Helper() then return end
	end
end
""")
    r = ct.derive_id(t, "synthcall")
    check(r["kind"] == "hero" and r["heroes"] == {"zuus"},
          "D10 a hero guard at the CALLER narrows the gate (got %s %s)"
          % (r["kind"], sorted(r["heroes"])))

    failed = [lbl for ok, lbl in CHECKS if not ok]
    for ok, lbl in CHECKS:
        if not ok:
            print("FAIL %s" % lbl)
    print("carrier_hero_guard: %d checks, %d failed" % (len(CHECKS), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
