-- [hero] GH #570 -- the False Promise veto proposed for X.HasSpecialModifier.
-- PREMISE-FALSIFIED 2026-09-06, and NOTHING WAS ADDED TO bots/.  This file is
-- the pin that keeps the falsified premise from being re-derived, and the
-- record of what the shipped branch really does on the one frame in the tree
-- where the proposed veto could have fired.
--
-- WHAT WAS CLAIMED
-- ----------------
-- bots/BotLib/hero_axe.lua X.HasSpecialModifier is the "do not cull this
-- target" list on the execute branch of X.ConsiderR.  It names seven modifiers
-- and NOT Oracle's False Promise, during which the target cannot die.  The
-- request read that as a wasted ultimate on a 80/75/70s cooldown, and offered
-- as evidence: over 449 `axe_culling_blade` casts in the replay-check corpus,
-- 2 landed INSIDE a False Promise window on the target, criterion = the
-- target's own [MODIFIER_ADD, MODIFIER_REMOVE] interval contains the cast.
--
-- WHAT KILLED IT
-- --------------
-- BOTH of those 2 casts are KILLS, and both live in ONE game, which is the
-- whole of the positive evidence -- so re-deriving them from that game's own
-- .dem settles the corpus reading, not a sample of it.  Re-derived for this
-- round rather than quoted (section 0 has the recipe):
--
--   * Every one of the 5 `axe_culling_blade` casts in that game is followed at
--     the same 0.1s tick by `DEATH <target> inflictor=axe_culling_blade`, with
--     the kill gold and XP credited to Axe.  There is no wasted cull in the
--     game the request drew its evidence from -- section 5.
--   * Under HALF-OPEN containment (`add <= t < remove`, which is what
--     make_fixture.py's own reconstruction uses) the count is ZERO, not 2.
--     Both "hits" sit exactly ON the right endpoint, where the MODIFIER_REMOVE
--     is the cull's own kill removing the buff -- section 6.
--   * The give-away is in the durations.  The four windows no cull touched run
--     7.0 / 8.5 / 8.5 / 8.5s; the two "hits" run 4.9s and 0.2s.  The two hits
--     are exactly the two windows that were cut short, and what cut them short
--     is the event being counted -- section 6.
--
-- So the criterion cannot tell "cast inside a live window" from "cast that
-- ENDED the window", and those two have OPPOSITE sign.  On this corpus every
-- hit is of the second kind.
--
-- AND THE VETO WOULD HAVE COST A KILL.  Section 4 installs the proposed veto
-- as a labelled injection on the real frame frozen below -- t=1452.8, the
-- decision instant 0.1s before the cast -- and the shipped HIGH desire on
-- oracle becomes NONE.  The combat log says that suppressed cast killed oracle
-- (223 damage, +650 and +170 gold to Axe, Culling's own kill-reset).  Deleting
-- legal, effective casts is the one direction a NARROWING lever's negative
-- reading can mean, and it is the direction this one points.
--
-- WHAT SURVIVES, AND IT IS NOT NOTHING
-- ------------------------------------
-- The OMISSION is real and section 2 asserts it: the shipped list names seven
-- modifiers, none of them Oracle's, while 228 call sites elsewhere under bots/
-- do veto on `modifier_oracle_false_promise_timer`.  What the corpus does not
-- support is that the omission has ever COST anything.  Supply for the claim
-- is now 0/449, and the theory case (c) alone does not ship a behavior change
-- in this repo.  A future round that wants this lever needs a frame where a
-- cull lands strictly INSIDE a window and the target survives; section 6's
-- half-open counter is written so it goes RED and names that frame the day one
-- exists.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ---------------------------------------------------------
--   * ONE GAME.  Every reading here is off
--     20260828_124358_slot1__spot_20260828_121642_..._11c470, which is the game
--     the request named for both of its hits.  It settles THOSE two.  It does
--     not re-scan the other 68 games, and this file must not be cited as if it
--     had.  The 449/69 figures are the request's, quoted as its own.
--   * WHY THE PROMISE ENDED IS NOT SETTLED HERE.  Whether the engine let
--     Culling Blade kill through False Promise, or the buff came off for some
--     other reason in the same 0.1s bucket, is an engine question this bench
--     cannot settle offline (same shape as GH #564's "读法无关" argument).  It
--     does not need settling: under BOTH readings the target ended up dead with
--     the cull named as the inflictor, and under both the veto would have
--     suppressed that cast.  The conclusion is invariant to the mechanic.
--   * SECTION 5's ROWS ARE A READING FROZEN AS DATA, NOT AN ASSERTION ABOUT A
--     LIVE FILE.  They are combat-log rows from a .dem this repo does not
--     carry, transcribed with the recipe that regenerates them.  Only the
--     FRAME is asserted against a loaded world.
--   * THE FRAME IS STAGED, NOT ADMITTED.  It lives in tests/frames/ and is read
--     BY NAME.  It is the tree's first frame from t>1400 (levels to 30, against
--     a corpus topping out near t=790 / level 19), so admitting it would move
--     census readings belonging to other levers.  That price is NOT measured
--     this round and is not claimed -- see tests/frames/README.md, which is
--     explicit that paying an admission list is its own work unit.
--   * SUPPLY IS TWO SENTENCES, NOT ONE.  Section 8 keeps "the corpus offers
--     zero units carrying this modifier" and "the tree offers exactly one, and
--     it is staged" apart, per that README's own closing finding.
--
-- Round: GH #570, owner priority P4.4 (ii) -- the last piece of evidence a
-- judgement needs.  Verdict label proposed: PREMISE-FALSIFIED; the director
-- rules.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_axe.lua'
local FRAME = 'tests/frames/f_260828_124358_axe_cull_promise.lua'
local SCANNER = 'tools/batch_test/behavioral/cullthresh_domain.py'
local GENERATOR = 'tools/batch_test/replayscope/make_fixture.py'
local AXE = 'npc_dota_hero_axe'
local ORACLE = 'npc_dota_hero_oracle'
local CULLING = 'axe_culling_blade'
local FP = 'modifier_oracle_false_promise_timer'

-- ---------------------------------------------------------------- section 0 --
-- Provenance of the frozen frame and of section 5's rows.
--
--   bash tools/batch_test/aws/session_setup.sh
--   BIN=$(bash tools/batch_test/behavioral/get_dumper.sh)
--   awsx s3 cp s3://dota2bot-batch-results-4924/replays/\
-- 20260828_124358_slot1__spot_20260828_121642_1_\
-- 4b2ee33416df1f41617387c93838052296c2aab7_11c470.dem g.dem
--   "$BIN" -interval 0.1 g.dem > timeline.json
--   python3 tools/batch_test/replayscope/make_fixture.py timeline.json \
--       --t 1452.8 --hero axe \
--       -o tests/frames/f_260828_124358_axe_cull_promise.lua
--
-- Section 5's rows are the `ABILITY`/`DEATH` events whose inflictor is
-- axe_culling_blade, and the MODIFIER_ADD/REMOVE pairs whose inflictor is
-- modifier_oracle_false_promise_timer, read out of that same timeline.json.

-- The 5 Culling Blade casts in that game and the DEATH row that follows each,
-- transcribed verbatim.  `dmg` is the DEATH row's value.
local CASTS = {
    { t =  958.7, target = 'npc_dota_hero_sniper',           death_t =  958.7, dmg =  65 },
    { t =  963.9, target = 'npc_dota_hero_oracle',           death_t =  963.9, dmg = 447 },
    { t = 1043.9, target = 'npc_dota_hero_bristleback',      death_t = 1043.9, dmg = 221 },
    { t = 1203.9, target = 'npc_dota_hero_phantom_assassin', death_t = 1203.9, dmg =  16 },
    { t = 1452.9, target = 'npc_dota_hero_oracle',           death_t = 1452.9, dmg = 223 },
}

-- Every modifier_oracle_false_promise_timer window in that game.
local WINDOWS = {
    { target = 'npc_dota_hero_bristleback', add =  374.4, remove =  381.4 },
    { target = 'npc_dota_hero_oracle',      add =  605.2, remove =  613.7 },
    { target = 'npc_dota_hero_oracle',      add =  799.5, remove =  808.0 },
    { target = 'npc_dota_hero_sniper',      add =  953.8, remove =  958.7 },
    { target = 'npc_dota_hero_ember_spirit',add = 1174.8, remove = 1183.3 },
    { target = 'npc_dota_hero_oracle',      add = 1452.7, remove = 1452.9 },
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The body of one X.<name> function, so a source ratchet cannot be satisfied
--- by a matching string elsewhere in the file.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load the staged frame with every gate OFF, so no armed farm string can leak
--- into a reading here.  Returns the pieces every section below needs.
local function load_frame()
    local J, bot, heroes, fx = rf.load(FRAME)
    J.IsSoakCandidate = function() return false end
    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[6] == CULLING,
        'the ultimate must be reachable in the frame world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    local X = rf.load_hero('axe')
    return X, J, bot, heroes, abilityR, fx
end

local function dist(a, b)
    local dx, dy = a:GetLocation().x - b:GetLocation().x,
                   a:GetLocation().y - b:GetLocation().y
    return math.sqrt(dx * dx + dy * dy)
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth: the frame really is the execute branch's own situation, on the
-- replay's numbers, 0.1s before the cast the request counted.

tests['ground truth: 24:12, Axe one tick from the cull, oracle under False Promise'] = function()
    local _, _, bot, heroes, abilityR, fx = load_frame()
    assert(fx.self == AXE and fx.time == 1452.8, string.format(
        'the decision instant, got %s @ %s', tostring(fx.self), tostring(fx.time)))
    assert(bot:GetLevel() == 30 and bot:GetHealth() == 3633, string.format(
        'real Axe state, got lvl %s hp %s', tostring(bot:GetLevel()), tostring(bot:GetHealth())))
    assert(abilityR:GetLevel() == 3 and abilityR:IsFullyCastable(),
        'Culling at rank 3 and off cooldown -- X.ConsiderR early-returns otherwise')
    assert(abilityR:GetCastRange() == 175, string.format(
        'AbilityCastRange is 175 in KV; the loader answered %s',
        tostring(abilityR:GetCastRange())))

    local oracle = heroes[ORACLE]
    assert(oracle ~= nil, 'oracle is not in the frame')
    assert(oracle:IsAlive() and oracle:CanBeSeen(),
        'the branch needs a visible living enemy; the frame carries one')
    assert(oracle:GetHealth() == 437, string.format(
        "oracle's real HP at the instant, got %s", tostring(oracle:GetHealth())))
    local d = dist(bot, oracle)
    assert(d > 153 and d < 154, string.format(
        'oracle sits 153.7u away, inside the 175 cast range; got %.1f', d))
    assert(oracle:HasModifier(FP) == true,
        'the whole point of this frame: the promise is LIVE at the decision instant')
end

-- ---------------------------------------------------------------- section 2 --
-- The half of GH #570 that is TRUE, asserted so a future round does not have to
-- re-find it: the shipped veto list really does not name Oracle's buff.

tests['the omission is real: seven names in the shipped list, none of them Oracle'] = function()
    local X, _, _, heroes = load_frame()
    assert(X.HasSpecialModifier(heroes[ORACLE]) == false,
        'on the real frame the shipped veto list does NOT veto a False-Promised target. '
        .. 'It now does -- if a later round ADDED the veto, this file is the record of '
        .. 'why it was withdrawn (it deletes the cast that killed oracle here): '
        .. 're-open GH #570 rather than editing this assertion')

    local body = fn_body(read_file(SRC), 'HasSpecialModifier')
    local names, n = {}, 0
    for name in body:gmatch("HasModifier%(%s*'([%w_]+)'%s*%)") do
        if not names[name] then names[name], n = true, n + 1 end
    end
    -- The name check runs BEFORE the count check on purpose: adding the veto
    -- moves BOTH, and the reader needs the actionable message, not the tally.
    for name in pairs(names) do
        assert(not name:find('false_promise'), string.format(
            'the list now names %s.  If a later round ADDED the veto, this file is the '
            .. 'record of why it was withdrawn -- re-open GH #570 rather than editing '
            .. 'this assertion', name))
    end
    assert(n == 7, string.format(
        'the shipped list named 7 modifiers when GH #570 was judged; it now names %d '
        .. '-- re-read it before quoting this file', n))
end

-- ---------------------------------------------------------------- section 3 --
-- What the SHIPPED branch decides here, with every gate off.

tests['shipped decision: HIGH desire, target oracle, on the real frame'] = function()
    local X, _, _, heroes = load_frame()
    local desire, target, motive = X.ConsiderR()
    assert(desire == BOT_ACTION_DESIRE_HIGH, string.format(
        'the execute branch fires here; got desire %s', tostring(desire)))
    assert(target == heroes[ORACLE], string.format(
        'it picks oracle; got %s',
        type(target) == 'table' and target:GetUnitName() or tostring(target)))
    assert(type(motive) == 'string' and motive:find('R%-'),
        'the branch reports its own kill motive')
end

-- ---------------------------------------------------------------- section 4 --
-- The proposed veto, as a LABELLED injection: nothing under bots/ implements
-- it, so it is built here, on the real frame, and the injection is asserted to
-- have changed something before anything is concluded from it.

tests['the proposed veto WOULD fire here -- and it deletes the cast that killed oracle'] = function()
    local X, _, _, heroes = load_frame()
    local before = X.ConsiderR()
    assert(before == BOT_ACTION_DESIRE_HIGH,
        'baseline must be the firing branch, else the injection proves nothing')

    -- The exact shape GH #570 asked for: one more name in the veto list.
    local shipped = X.HasSpecialModifier
    local fired = 0
    X.HasSpecialModifier = function(npcEnemy)
        if npcEnemy:HasModifier(FP) then fired = fired + 1 return true end
        return shipped(npcEnemy)
    end
    local after = X.ConsiderR()
    X.HasSpecialModifier = shipped

    assert(fired >= 1,
        'the injected veto never even read the frame -- it proves nothing about it')
    assert(after == BOT_ACTION_DESIRE_NONE, string.format(
        'the veto suppresses the branch; got %s', tostring(after)))

    -- ...and the combat log says that suppressed cast was a kill.
    local killed = false
    for _, c in ipairs(CASTS) do
        if c.t == 1452.9 and c.target == ORACLE and c.death_t == c.t then killed = true end
    end
    assert(killed, 'section 5 rows no longer carry the 1452.9 kill this section leans on')
end

-- ---------------------------------------------------------------- section 5 --
-- The frozen combat-log reading: no wasted cull exists in the game the request
-- drew both of its hits from.

tests['every cull in that game is a kill -- 5 casts, 5 deaths naming the blade'] = function()
    assert(#CASTS == 5, 'the game holds 5 Culling Blade casts')
    for _, c in ipairs(CASTS) do
        assert(c.death_t == c.t, string.format(
            'cast at t=%.1f on %s has no DEATH row at the same tick -- a wasted cull '
            .. 'would be exactly this, and it is what GH #570 needed and did not have',
            c.t, c.target))
        assert(c.dmg > 0, 'a kill row carries the damage that closed it')
    end
end

-- ---------------------------------------------------------------- section 6 --
-- The boundary arithmetic that turns 2 into 0, and the tripwire for the frame
-- that would revive the lever.

local function count_containment(closed)
    local n, hits = 0, {}
    for _, w in ipairs(WINDOWS) do
        for _, c in ipairs(CASTS) do
            if c.target == w.target then
                local inside = closed and (w.add <= c.t and c.t <= w.remove)
                                       or  (w.add <= c.t and c.t <  w.remove)
                if inside then
                    n = n + 1
                    hits[#hits + 1] = string.format('%s @ %.1f in [%.1f, %.1f]',
                        c.target, c.t, w.add, w.remove)
                end
            end
        end
    end
    return n, hits
end

tests['closed containment counts 2, half-open counts 0 -- the whole disagreement'] = function()
    local nClosed = count_containment(true)
    local nOpen, openHits = count_containment(false)
    assert(nClosed == 2, string.format(
        "the request's own criterion reproduces its own count; got %d", nClosed))
    assert(nOpen == 0, string.format(
        'HALF-OPEN containment finds no cull strictly inside a live window.  It now '
        .. 'finds %d (%s) -- that is the frame GH #570 always needed, and this lever '
        .. 'can be re-opened on it', nOpen, table.concat(openHits, '; ')))
end

tests['the two hits are exactly the two windows the culls cut short'] = function()
    local cut, uncut = {}, {}
    for _, w in ipairs(WINDOWS) do
        local touched = false
        for _, c in ipairs(CASTS) do
            if c.target == w.target and w.add <= c.t and c.t <= w.remove then touched = true end
        end
        local dur = w.remove - w.add
        if touched then cut[#cut + 1] = dur else uncut[#uncut + 1] = dur end
    end
    assert(#cut == 2 and #uncut == 4, string.format(
        '2 windows touched, 4 not; got %d and %d', #cut, #uncut))
    local maxCut, minUncut = 0, math.huge
    for _, d in ipairs(cut) do if d > maxCut then maxCut = d end end
    for _, d in ipairs(uncut) do if d < minUncut then minUncut = d end end
    assert(maxCut < minUncut, string.format(
        'the longest touched window (%.1fs) must be shorter than the shortest untouched '
        .. 'one (%.1fs): the "hits" are the windows the counted event itself ended',
        maxCut, minUncut))
    -- rounded to the dumper's own 0.1s resolution: these are differences of
    -- decimal timestamps, so a raw compare rides on float error (6.999... and
    -- 4.900...1 both showed up as "7.0" and "4.9" while failing the test).
    local function tick(x) return math.floor(x * 10 + 0.5) / 10 end
    minUncut, maxCut = tick(minUncut), tick(maxCut)
    assert(minUncut >= 7.0 and maxCut <= 4.9, string.format(
        'the numbers this reading was written on: untouched >= 7.0s (got %.1f), '
        .. 'touched <= 4.9s (got %.1f)', minUncut, maxCut))
end

-- ---------------------------------------------------------------- section 7 --
-- Where the miscount lives, read out of the two instruments rather than
-- retyped, so a fix or a drift in either turns this red instead of stale.

tests['the two instruments disagree at the boundary, and the closed one produced the count'] = function()
    local scanner = read_file(SCANNER)
    local from = scanner:find('def active_modifiers%(')
    assert(from, 'active_modifiers is gone from ' .. SCANNER)
    local body = scanner:sub(from, from + 800)
    assert(body:find('a <= t <= b', 1, true), string.format(
        '%s no longer uses CLOSED containment.  If it was fixed, say so in GH #570 '
        .. 'and re-take the 449-cast reading -- the fix changes the count that '
        .. 'opened it', SCANNER))

    local gen = read_file(GENERATOR)
    local gfrom = gen:find('def active_modifiers%(')
    assert(gfrom, 'active_modifiers is gone from ' .. GENERATOR)
    local gbody = gen:sub(gfrom, gfrom + 3000)
    assert(gbody:find('s <= t < e', 1, true),
        GENERATOR .. ' no longer uses HALF-OPEN containment; the frame under '
        .. 'tests/frames/ was generated by the half-open reconstruction')
end

-- ---------------------------------------------------------------- section 8 --
-- Supply, kept as two sentences.

tests['supply: the corpus carries zero units under this modifier; the tree carries one'] = function()
    local pipe = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    local nFiles, nCarrying = 0, 0
    for path in pipe:lines() do
        nFiles = nFiles + 1
        local fx = dofile(path)
        for _, u in ipairs((fx or {}).units or {}) do
            for _, m in ipairs(u.modifiers or {}) do
                if m.name == FP then nCarrying = nCarrying + 1 end
            end
        end
    end
    pipe:close()
    assert(nFiles >= 100, string.format(
        'the corpus should hold 100+ frames; found %d -- did the glob break?', nFiles))
    assert(nCarrying == 0, string.format(
        'the CORPUS carried zero units under %s when GH #570 was judged; it now carries '
        .. '%d.  That is new supply: re-take the reading rather than trusting this file',
        FP, nCarrying))

    -- ...and separately, by name, the one staged frame that does carry it.
    local staged = dofile(FRAME)
    local seen = 0
    for _, u in ipairs(staged.units or {}) do
        for _, m in ipairs(u.modifiers or {}) do
            if m.name == FP then seen = seen + 1 end
        end
    end
    assert(seen == 1, string.format(
        'the staged frame carries exactly one unit under %s; got %d', FP, seen))
end

-- The `remaining` this frame carries for that modifier is 0.1s, and it is NOT a
-- reading of how much promise was left: it is the distance to a MODIFIER_REMOVE
-- that the cull's own kill produced.  Asserted so nobody mines it as a duration.
tests['the frames `remaining` for the promise is a boundary artifact, not a duration'] = function()
    local staged = dofile(FRAME)
    for _, u in ipairs(staged.units or {}) do
        for _, m in ipairs(u.modifiers or {}) do
            if m.name == FP then
                assert(m.remaining == 0.1, string.format(
                    'the generator measured 0.1s to the REMOVE; got %s', tostring(m.remaining)))
                assert(m.elapsed == 0.1, string.format(
                    'the promise was 0.1s old at the instant; got %s', tostring(m.elapsed)))
            end
        end
    end
end

return tests
