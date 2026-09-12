-- Two armed soak candidates whose condition (a) -- "the replay desk confirms
-- the change actually fires and behaves correctly" -- cannot be bought from any
-- instrument this lab owns.  Both retired from the armed set 2026-09-08
-- (director, test_set.md §GC; state.json:wandlimbo_RETURNED_20260908 and
-- tpdead_RETURNED_20260908).
--
-- ⛔ RETIRED FROM THE ARMED SET IS NOT REJECTED.  Both gates and both helper
-- bodies stay byte-for-byte; that ruling had zero `bots/` diff.  What this file
-- pins is the BLINDNESS -- the reason no wave can answer (a) -- so that a future
-- round proposing re-admission has to go through the instrument rather than
-- around it.  Each half names the purchase that would lift it.
--
-- ⭐⭐⭐ THE SHAPE BOTH HALVES SHARE, AND IT IS THE FINDING WORTH CARRYING OUT
-- OF THIS FILE: EACH ID ALREADY HAS A GREEN FIXTURE TEST ON A REAL FRAME, AND IN
-- BOTH THE ONE INPUT THE LEVER TURNS ON IS WRITTEN BY THE TEST, NOT READ FROM
-- THE FRAME.
--
--   * tests/test_replay_181441_wand_limbo.lua loads the real 20260722_181441
--     frame, asserts the real HP, the real 2017u enemy distance, the real
--     fountain distance -- and then does
--     `rawget(wand, '__spec').GetCurrentCharges = n`, choosing 12 for the case
--     that must fire and 3 for the case that must not.  Charges are the ONLY
--     clause `wandlimbo` adds over the shipped rules, and they are the author's
--     number.
--   * tests/test_tpdead_release.lua builds its landing frames and then assigns
--     `bot.tpRespondLoc`, `bot.tpRespondUntil` and `bot.tpRespondAlly` by hand.
--     That commitment state is what makes J.GetTpCommitDefendDesire reachable at
--     all, and this sweep measures it as absent on all 1021 corpus frames.
--
-- Neither test is wrong -- both are good CLAUSE tests and both say what they do
-- in their own prose.  What is wrong is reading them as condition (a).  A test
-- like this asserts "given this input, the decision is correct"; condition (a)
-- asks "does this input ever occur, and did the bot then decide correctly".  On
-- a real frame with every OTHER clause genuinely read from the dump, the two are
-- very hard to tell apart, and nothing in the tree tells them apart today.
-- That is why both ids sat at verify=0 for 20 days while looking validated, and
-- it is why the retirement is about the INSTRUMENT rather than about the levers.
--
-- ⭐⭐ AND UNDERNEATH IT: IN EACH CASE THE WALL WAS ALREADY WRITTEN DOWN IN THE
-- TREE BEFORE THE ID WAS ARMED, in prose, by the house's own convention of
-- declaring limits -- and the id was armed anyway.  A wall that is documented but
-- not instrumented stops nobody.  Both declarations are parsed below, not quoted,
-- so rewriting a note takes this file red instead of orphaning the citation.
--
-- CORPUS READINGS are pinned as literals from tests/_blind_a_sweep.lua
-- (110 fixtures / 1021 live turbo hero frames), the same way
-- tests/test_fieldregen_family_overlap.lua and tests/test_ohnum_refusal.lua
-- carry theirs: the sweep is a 30s subprocess and does not belong in the fast
-- leg (the Lua detector leg is already at its 120s budget, GH #358).  Re-take
-- them with:  lua5.1 tests/_blind_a_sweep.lua
--
--   G DUMPER_CHARGE_MENTIONS 0     G FIXLOADER_SERVES_CHARGES 0
--   C has_wand 953                 C charges_read 953    C charges_nonzero 0
--   C wl_full 0                    C wl_nocharge 17
--   C td_state_present 0           C tc_alone_nonnil 0   C td_armed_alone_nonnil 0
--
-- ------------------------------------------------------------------------
-- HALF 1 -- `wandlimbo`: the instrument answers 0, and 0 reads as "never fires"
-- ------------------------------------------------------------------------
--
-- J.ShouldDrinkWandInLimbo's first conjunct after the two gates is
-- `hItem:GetCurrentCharges() < 6`.  Item charges are per-frame runtime state and
-- they are missing from BOTH ends of this lab's evidence chain:
--
--   * the fixture path -- tests/mock/replay_fixture.lua builds inventory handles
--     with api.MakeAbility(name, { IsFullyCastable = true }) and serves no
--     charge getter, so the call falls through bot_api.lua's `^Get -> 0`
--     catch-all.  Measured: all 953 wand/stick handles in the corpus read 0.
--   * the replay path -- tools/batch_test/behavioral/dumper/main.go emits
--     `Items []string`, item NAMES only.  The substring "charge" does not occur
--     in that file at all, so a behavioural detector on the .dem cannot
--     reconstruct the clause either.
--
-- ⭐ SO THE MEASURED DOMAIN IS ZERO FOR THE INSTRUMENT'S REASON, NOT THE
-- WORLD'S, AND ZERO IS THE ANSWER THAT RETIRES THE ID.  `wl_full` is 0 on all
-- 1021 frames; `wl_nocharge` -- the same predicate with the charge conjunct
-- removed -- is 17.  Neither number says anything alone.  Together they are the
-- §GB.2 shape the charter stated three weeks after this id was armed: a wall
-- hands back not a blank but an ordinary-looking number pointing at one verdict.
--
-- ⭐⭐ AND THE FRAME THE ID WAS WRITTEN FOR IS IN THE HIDDEN SEVENTEEN.
-- tests/fixtures/f_181441_zuus_lowhp_limbo.lua is the frame quoted in the
-- helper's own comment (20260722_181441 t=660.0, zuus 214/1354 HP, ~4600 from
-- its own fountain, "a charged wand sitting idle in slot 5").  The sweep reads
-- it at hp 0.1581 / fountain 4598.5 in `wl_nocharge`, and `wl_full` false on it.
-- The pinned frame its author froze to prove the case is a frame the instrument
-- cannot reproduce.  Section 1c drives exactly that fixture.
--
-- ⭐⭐⭐ THE DECLARATION ALREADY EXISTED, ~5,800 LINES ABOVE THE HELPER, IN THE
-- SAME FILE.  J.HasFieldRegenSource's `stayfield` note says both halves in its
-- own prose -- "a fixture can never answer TRUE through the bottle leg -- the
-- mock's GetCurrentCharges default is 0. Declared, not hidden." and, about the
-- wand specifically, "its charge count -- the thing that decides whether it
-- heals at all -- is not in the dump."  That note then declines to count the
-- wand FOR THAT REASON.  `wandlimbo` was armed on 2026-08-19 with a charge count
-- as its first conjunct, and rode seven waves' member strings (W39/W40/W41/
-- W52/W53/W54/W55, never single-armed) before anyone read the two together.
--
-- THE PURCHASE THAT LIFTS THIS: the dumper emits per-item charges, and the
-- fixture loader serves them (owed row `wandlimbo_charge_instrument`, GH #642).
-- Section 1d goes red the day either end is served, which is the day this id
-- may be re-proposed.
--
-- ------------------------------------------------------------------------
-- HALF 2 -- `tpdead`: unreachable from both paths, for two different reasons
-- ------------------------------------------------------------------------
--
-- The `tpdead` clause is an inline `if` in the body of
-- J.GetTpCommitDefendDesire, whose second line is
-- `if not J.IsSoakCandidate( 'tpcommit' ) then return nil end`.  Its only writer
-- (bot.tpRespondAlly, ability_item_usage_generic.lua) runs ungated in every game
-- but is inert, and that file says so: "only J.GetTpCommitDefendDesire reads it,
-- and only with the 'tpdead' candidate armed."  So:
--
--   * armed ALONE -- which is what an isolation wave does -- `tpdead` is a
--     byte-for-byte no-op, because the gate above it has already returned;
--   * armed WITH `tpcommit`, the reading is a net of pin creation (`tpcommit`)
--     and release (`tpdead`), which §GA.1 established cannot be decomposed even
--     in sign, over 4,527 response-TP landings on 70 game-legs (W49).
--
-- This is the identical structure §GA.1 measured for `tpdying` -- the clause 20
-- lines ABOVE this one, in the same function, retired from the armed set on
-- 2026-09-08 for exactly this reason.  `tpdead` is named verbatim in that ruling
-- ("两个释放(`tpdying`/`tpdead`)") and stayed armed for another day, which is
-- the carry-across this file closes.
--
-- ⭐ AND THE CORPUS PATH IS SHUT TOO, WHICH THE SWEEP FOUND BY FAILING ITS OWN
-- CONTROL.  _blind_a_sweep.lua arms `tpdead` alone and counts non-nil returns
-- (0), then arms `tpcommit` alone as the control -- which must be > 0 or the
-- first zero means nothing (the GH #171 shape).  It is 0 too.  The cause is
-- measured: `td_state_present` is 0 on all 1021 frames, because the function's
-- fifth line requires `bot.tpRespondUntil`, state written only by a live game's
-- response-TP branch.  A fixture-loaded bot has never taken a TP.
--
-- ⛔ SO NEITHER ZERO IN HALF 2 IS EVIDENCE ABOUT `tpdead`, AND THIS FILE USES
-- NEITHER AS ANY.  They establish a third blindness instead: the corpus cannot
-- reach this function at all.  Half 2's assertions below are SOURCE readings and
-- are labelled as such -- line order and the writer's declared inertness -- plus
-- the already-measured W49 reading in §GA.1.  The one thing the sweep's zeros
-- are used for is section 2d, which pins the unreachability itself.
--
-- THE PURCHASE THAT LIFTS THIS: an isolation leg -- same seeds, `tpcommit` armed
-- with NEITHER release -- against the existing W49 readings (owed row
-- `tpdying_isolation_leg`, amended 2026-09-08 to name `tpdead`).  It costs a
-- wave, so it is batch-desk's to schedule, not replay-check's to take.

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'
local ITEMUSE = 'bots/ability_item_usage_generic.lua'
local DUMPER = 'tools/batch_test/behavioral/dumper/main.go'
local FIXLOADER = 'tests/mock/replay_fixture.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(s) return (s:gsub('%-%-[^\n]*', '')) end

local function line_of(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return -1 end
    local _, n = src:sub(1, at):gsub('\n', '')
    return n + 1
end

-- The helper body with its prose removed, so the long comment above it cannot
-- satisfy a single assertion here (the §EN mistake this house paid for once).
local function wl_block()
    local src = read_file(JMZ)
    local at = src:find('function J.ShouldDrinkWandInLimbo( bot, hItem )', 1, true)
    assert(at, 'J.ShouldDrinkWandInLimbo is gone -- this whole file is about it')
    local stop = src:find('\nend', at, true) or #src
    return strip_comments(src:sub(at, stop))
end

-- ============================================================== half 1

tests['[1a] wandlimbo gates on a charge count, and it short-circuits everything'] = function()
    local b = wl_block()
    assert(not b:find('--', 1, true), 'wl_block still carries comments')
    assert(b:match('nCharges < 6'),
        'the charge floor moved off 6 -- re-take the corpus readings in this header')
    -- Position is load-bearing.  The instrument's 0 is only fatal to the whole
    -- predicate because the charge read comes FIRST; a reordering that put it
    -- last would change what `wl_full 0` means and this file would be measuring
    -- a different claim.
    local src = read_file(JMZ)
    local nCharge = line_of(src, 'local nCharges = hItem:GetCurrentCharges()')
    local nHp = line_of(src,
        'if bot:GetHealth() > bot:GetMaxHealth() * 0.25 then return false end')
    assert(nCharge > 0 and nHp > 0, 'the wandlimbo clauses no longer parse')
    assert(nCharge < nHp,
        'the charge read is no longer the first conjunct -- `wl_full 0` no longer '
        .. 'means "the instrument short-circuited it" and must be re-taken')
end

tests['[1b] neither end of the evidence chain carries item charges'] = function()
    -- The replay path.  Parsed, not asserted: this is the claim that a
    -- behavioural detector cannot be built either, and it is the reason the
    -- ruling says "no instrument" rather than "not from fixtures".
    local dsrc = read_file(DUMPER)
    local n = 0
    for _ in dsrc:lower():gmatch('charge') do n = n + 1 end
    assert(n == 0,
        'the dumper now mentions charges (' .. n .. ' times) -- the replay half of '
        .. "`wandlimbo`'s blindness may be lifted; re-read before trusting this file")
    assert(dsrc:find('Items     []string', 1, true),
        'the dumper no longer emits Items as names-only -- re-take half 1')

    -- The fixture path.
    local fsrc = read_file(FIXLOADER)
    assert(fsrc:find('STILL REFUSED, deliberately: ChannelTime, Duration, Charges.',
        1, true), "the fixture loader's refusal of Charges is no longer declared "
        .. 'where this file reads it')
    assert(not fsrc:find('GetCurrentCharges =', 1, true),
        'the fixture loader now serves GetCurrentCharges -- half 1 of this file is '
        .. 'stale and `wandlimbo` may be re-proposable; re-take the sweep')
end

tests['[1c] the frame the id was written for is one the instrument cannot answer'] = function()
    -- Driven, on the one fixture the helper's own comment names.  This is the
    -- whole argument in a single frame: the author froze the case, and the
    -- predicate reads false on it for a reason that has nothing to do with the
    -- case being wrong.
    package.path = 'tests/?.lua;' .. package.path
    local rf = require('mock.replay_fixture')
    local FX = 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua'
    local J, bot = rf.load(FX, 'npc_dota_hero_zuus')
    J.IsSoakCandidate = function(sId) return sId == 'wandlimbo' end
    assert(J.IsModeTurbo(), 'the fixture world stopped being turbo')

    local slot = bot:FindItemSlot('item_magic_wand')
    assert(slot ~= nil and slot >= 0,
        'the zuus limbo fixture no longer carries a magic wand -- the helper cannot '
        .. 'even be called on it and this section is measuring nothing')
    local hWand = bot:GetItemInSlot(slot)

    assert((tonumber(hWand:GetCurrentCharges()) or -1) == 0,
        'the fixture world now answers a non-zero charge count -- that is the '
        .. 'purchase this ruling asked for; re-read the ruling')
    assert(J.ShouldDrinkWandInLimbo(bot, hWand) == false,
        'the helper now fires on its own motivating frame -- the blindness this '
        .. 'file records is lifted and `wandlimbo` should be re-proposed')

    -- ...and it is NOT because the frame is out of domain.  Every other conjunct
    -- holds.  Without this half the section above would be satisfied by a
    -- fixture that simply does not match, which is the same right-answer-wrong-
    -- reason failure the evidence-discipline skill's fourth rule names.
    assert(bot:GetHealth() <= bot:GetMaxHealth() * 0.25, 'HP clause no longer holds')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'the 1600 ring clause no longer holds on this frame')
    assert(J.GetDistanceFromAllyFountain(bot) > 2500, 'fountain clause no longer holds')
    assert((bot:GetMaxHealth() - bot:GetHealth()) >= 6 * 15, 'overheal clause no longer holds')
end

tests['[1d] the wall was declared in the tree before the id was armed'] = function()
    -- Both sentences of the `stayfield` note, parsed rather than quoted.  They
    -- are the reason this round's finding is "documented but not instrumented"
    -- rather than "nobody knew".
    local src = read_file(JMZ)
    assert(src:find('GetCurrentCharges default is 0. Declared, not hidden.', 1, true),
        "the `stayfield` note's mock declaration is gone -- this file's central "
        .. 'claim (the wall was already written down) no longer has its citation')
    assert(src:find('decides whether it heals at all -- is not in the dump.', 1, true),
        "the `stayfield` note's dump declaration is gone -- same problem, and this "
        .. 'one is the sentence that names the WAND specifically')
end

tests['[1e] the green fixture test supplies the charge count it tests on'] = function()
    -- ⭐ The section that keeps this whole file honest.  Without it, a reader who
    -- knows tests/test_replay_181441_wand_limbo.lua is green and pinned on the
    -- real frame would take it as the condition-(a) reading this ruling says
    -- does not exist.  Pinned as the ASSIGNMENT, so the day that test starts
    -- reading charges from the fixture instead, this section goes red and the
    -- ruling is due for re-reading.
    local t = read_file('tests/test_replay_181441_wand_limbo.lua')
    assert(t:find("rawget(wand, '__spec').GetCurrentCharges = n", 1, true),
        'tests/test_replay_181441_wand_limbo.lua no longer injects the charge '
        .. 'count -- if it now reads charges from the frame, the instrument was '
        .. 'bought and `wandlimbo` is re-proposable; re-read the ruling')
    -- The rest of that file really is real-frame -- which is exactly what makes
    -- the one stubbed input hard to see, and is why this section names it rather
    -- than dismissing the test.
    assert(t:find('bot:GetHealth() == 214 and bot:GetMaxHealth() == 1354', 1, true),
        'the real-HP assertion is gone from the wandlimbo fixture test -- this '
        .. "section's claim (every OTHER clause is genuinely read) no longer holds")
end

-- ============================================================== half 2

-- REWRITTEN 2026-09-12. tpcommit was PROMOTED (director RULING 20, anchor
-- stable-v8), so the id's gate line is gone from J.GetTpCommitDefendDesire and
-- the old assertion cannot hold. Its own failure text named the outcome
-- exactly -- "`tpdead` may now be reachable alone, which is the purchase this
-- ruling asked for" -- so this case now asserts the purchase instead of the
-- gate: the clause still lives inside that function, and the function's only
-- remaining entry condition is turbo. The half that still constrains anything
-- is the ORDER (the turbo guard precedes the clause), and that is kept.
tests['[2a] the tpdead clause lives inside a turbo-default floor'] = function()
    local src = read_file(JMZ)
    local at = src:find('function J.GetTpCommitDefendDesire( bot, nLane )', 1, true)
    assert(at, 'J.GetTpCommitDefendDesire is gone')
    -- Searched from the function head, not from the file head: the id is named
    -- in several unrelated comments elsewhere.
    assert(not src:find("if not J.IsSoakCandidate( 'tpcommit' ) then return nil end",
        at, true),
        'a tpcommit gate is back inside J.GetTpCommitDefendDesire -- the id was '
        .. 'promoted on 2026-09-12 and re-gating it would silently un-ship a '
        .. 'turbo default and make tpdead unreachable alone again')
    local turbo = src:find('if not J.IsModeTurbo() then return nil end', at, true)
    assert(turbo, 'the turbo guard left J.GetTpCommitDefendDesire')
    local clause = src:find("if J.IsSoakCandidate( 'tpdead' )", at, true)
    assert(clause, 'the tpdead clause left J.GetTpCommitDefendDesire')
    assert(turbo < clause,
        'the turbo guard no longer precedes the tpdead clause -- the clause would '
        .. 'be reachable outside turbo, which no wave has ever measured')
end

tests['[2b] the clause is INLINE, which is why the nesting census cannot see it'] = function()
    -- ⭐ The GH #622 reading.  tests/test_gated_helper_nesting_census.lua
    -- censuses helper-in-helper conjunctions -- "a helper that carries its own
    -- J.IsSoakCandidate is not a predicate, it is a conjunct".  `tpdead` is the
    -- same conjunction with NO helper: an inline `if` in the caller's body.  The
    -- census's row for this very function carries `tpcommit,tpdead,tpdying` in
    -- its OUTER-id column -- it names all three -- while the question it asks is
    -- about the callee (J.ShouldRetreatLaneBurst).  The conjunction that made
    -- `tpdying`'s (a) unbuyable is sitting in that row's own first column with no
    -- verdict slot for it.
    local src = read_file(JMZ)
    assert(src:find("if J.IsSoakCandidate( 'tpdead' )\n\tand bot.tpRespondAlly ~= nil",
        1, true), 'the tpdead clause is no longer the inline form this file reasons '
        .. 'about -- if it became a gated helper, the nesting census now covers it '
        .. 'and section 2b should be retired rather than repaired')

    -- The row lost `tpcommit` from its outer-id column when that id was
    -- promoted on 2026-09-12 (RULING 20). The GH #622 reading is unaffected:
    -- it is about `tpdead` sitting in an OUTER-id column with no verdict slot,
    -- and `tpdead` is still there. Cite what exists now, not what existed then.
    local census = read_file('tests/test_gated_helper_nesting_census.lua')
    assert(census:find('tpdead,tpdying | J.GetTpCommitDefendDesire', 1, true),
        'the census row that names tpdead in its outer-id column is gone -- the '
        .. 'GH #622 reading in this header cited it as the live example and now '
        .. 'cites nothing')
end

tests['[2c] the writer is ungated but declared inert, and has no other reader'] = function()
    -- The other half of "armed alone is a no-op": if some ungated consumer read
    -- the stamp, arming `tpdead` alone could still change behaviour.
    local usesrc = read_file(ITEMUSE)
    assert(usesrc:find('bot.tpRespondAlly = hRescueAlly', 1, true),
        'the tpRespondAlly writer is gone')
    assert(usesrc:find('only J.GetTpCommitDefendDesire reads it, and only with', 1, true),
        "the writer's own declaration of inertness is gone -- re-derive it before "
        .. 'trusting the no-op claim')
    -- Driven against the tree rather than taken from that comment: every read of
    -- the stamp must be inside the one gated function.
    local jmz = read_file(JMZ)
    local fn = jmz:find('function J.GetTpCommitDefendDesire( bot, nLane )', 1, true)
    local fnEnd = jmz:find('\nfunction J.', fn + 10, true) or #jmz
    local outside = 0
    local pos = 1
    while true do
        local a = jmz:find('bot.tpRespondAlly', pos, true)
        if a == nil then break end
        if a < fn or a > fnEnd then outside = outside + 1 end
        pos = a + 1
    end
    assert(outside == 0,
        'bot.tpRespondAlly is now read outside J.GetTpCommitDefendDesire (' .. outside
        .. ' site(s)) -- arming `tpdead` alone may no longer be a no-op')
end

tests['[2d] the corpus cannot reach this function, so its zeros are not readings'] = function()
    -- Pins the state gate the sweep's failed control landed on.  This is the
    -- section that keeps `td_armed_alone_nonnil 0` from ever being quoted as
    -- evidence that the release behaves correctly: nothing in the corpus gets
    -- past line five.
    local src = read_file(JMZ)
    local at = src:find('function J.GetTpCommitDefendDesire( bot, nLane )', 1, true)
    local body = strip_comments(src:sub(at, (src:find('\nfunction J.', at + 10, true) or #src)))
    assert(body:find('bot.tpRespondLoc == nil or bot.tpRespondUntil == nil', 1, true),
        'the response-TP state gate is gone -- the corpus may now reach this '
        .. 'function, and _blind_a_sweep.lua\'s control should be re-run before '
        .. 'anyone repeats "unreachable from the corpus"')

    -- And the state has no producer outside a live game's TP branch: if a
    -- fixture ever carried it, the sweep's control could pass and half 2 would
    -- have a real corpus reading rather than a blindness.
    local loader = read_file(FIXLOADER)
    assert(not loader:find('tpRespondUntil', 1, true),
        'the fixture loader now sets tpRespondUntil -- re-run tests/_blind_a_sweep.lua; '
        .. 'its control may now pass and half 2 can be upgraded from source to driven')
end

tests['[2e] the green release test writes the commitment state it tests on'] = function()
    -- The half-2 twin of section 1e, and the reason `td_state_present 0` is a
    -- finding rather than a broken drive: the state the corpus never carries is
    -- state this test assigns in three lines.
    -- ⚠ THE NEEDLES ARE WHOLE ASSIGNMENT STATEMENTS, NOT `bot.tpRespondUntil =`.
    -- The first version of this section used the bare `field =` form and its
    -- mutant SURVIVED: `bot.tpRespondUntil =` is a PREFIX of
    -- `bot.tpRespondUntil ==`, and this same file asserts
    -- `bot.tpRespondUntil == nil` twice, so deleting every assignment left the
    -- section green.  An assertion that a comparison can satisfy is not an
    -- assertion about assignment (evidence discipline 2 -- suspect the assertion
    -- when a mutant survives; here the mutant was right and the assertion was
    -- wrong).
    local t = read_file('tests/test_tpdead_release.lua')
    for _, stmt in ipairs({
        'bot.tpRespondLoc = ally:GetLocation()',
        'bot.tpRespondUntil = f.cast + COMMIT',
        'bot.tpRespondAlly = ally',
    }) do
        assert(t:find(stmt, 1, true),
            'tests/test_tpdead_release.lua no longer contains `' .. stmt
            .. '` -- if it now obtains the commitment from a driven TP, the corpus '
            .. 'path may be open and half 2 must be re-taken')
    end
end

tests['[2f] the promote atom that names both releases stays, and is not this ruling'] = function()
    -- ⛔ Retiring an id from the armed set is not promoting it, so
    -- `tp_response_releases_need_commit` is untouched by this ruling and must NOT
    -- be retired alongside it: it constrains promote day, and a future
    -- re-admission would still need it.  Pinned because deleting it would be the
    -- easy tidy-up, and it would silently re-open the configuration it exists to
    -- refuse.
    -- ⭐ It is also the third independent witness to half 2's structure, and it
    -- was written on 2026-09-05 -- three days before §GA.1 read the same nesting
    -- as a condition-(a) problem for `tpdying`, and never carried it to `tpdead`.
    local atoms = read_file('iterations/promote_atoms.json')
    assert(atoms:find('"tp_response_releases_need_commit"', 1, true),
        'the promote atom constraining the two TP releases is gone -- retiring '
        .. 'them from the armed set must not have retired it')
    assert(atoms:find('"tpdead"', 1, true) and atoms:find('"tpcommit"', 1, true),
        'the atom no longer names tpdead / tpcommit')
end

return tests
