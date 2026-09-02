-- [GH #262 / GH #263] The guard and the unit it licenses must be the same
-- unit -- and the gate and the defect it targets must be on the same axis.
--
-- THE SITE. hero_spirit_breaker.lua's farm branch (X.ConsiderChargeOfDarkness)
-- reaches its neutral-camp case through two disjuncts, both of which already
-- require `#nNeutralCreeps >= 2`. It then asks
-- `J.CanBeAttacked(nNeutralCreeps[1])` and returns `nNeutralCreeps[2]` as the
-- charge target. Index [2] -- the unit actually charged -- is never asked
-- anything at all. [site] below reads both facts back out of the shipped file
-- rather than restating them here, so the day someone changes which index is
-- returned this file goes red instead of quietly testing a premise that moved.
--
-- WHY THIS LEVER CARRIES NO LEVEL CLAUSE, though the site is the third member
-- of the `[1]` family that 'abilanc' (GH #196) and 'abil1st' (GH #259) sit in.
-- GH #263 measured that band on the W18 two-legged corpus -- 68 games, 143
-- ancient-camp episodes:
--
--     band                        episodes   abandoned   rate
--     < 12  (the two ids' domain)        5           1   20.0%
--     >= 12 (provably out of reach)    138          41   29.7%
--
-- The rate is nearly the same on both sides of the threshold; the edge is in
-- the NUMERATOR, not in the ratio. Low-level heroes are not likelier to poke
-- and leave -- they just rarely go, because Turbo levels fast. A level gate
-- therefore selects almost none of the defect it was written for. Worse, the
-- same corpus carries a clean, profitable, BELOW-tier ancient kill (zuus L11,
-- `843688/20260827_185943_slot12` t=708.0: two Arc Lightnings, kill at 709.9,
-- gold and XP booked, cost ~17% mana and ~1.4% health already regenerated) --
-- an in-domain frame the armed level gate would have SUPPRESSED. That is the
-- reversal this file's sibling ruling records: 'abil1st' should not be armed
-- on the level axis.
--
-- ⭐ THE REUSABLE CRITERION, at the two scales this pair of issues shows it:
--     A predicate must be about the same object as the action it licenses,
--     and a gate must be measured on the same axis as the defect it claims to
--     control. Otherwise its narrowness is not safety -- it is irrelevance.
-- The failure direction is a FALSE SENSE OF NARROWNESS: a tiny domain reads
-- as "low risk" in review precisely when it is aimed away from the defect,
-- and nothing turns red to say so.
--
-- THE FIX. `J.CanBeAttackedPair(hGuard, hTarget)` (jmz_func.lua), soak
-- candidate 'aimguard', turbo-only, a single conjunct, NOT conjoined with
-- 'abilanc' or 'abil1st' (the `pullcad` trap in AGENTS.md). Unarmed it is
-- literally `J.CanBeAttacked(hGuard)`; armed it also requires the target.
--
-- WHAT IS REAL HERE AND WHAT IS DECLARED -- read before trusting a number.
--   * REAL: the subject (spirit_breaker) and its LEVEL, on two frames of the
--     same match, and the shipped source of both the call site and the helper.
--   * DECLARED: the camp. World fact [W1] asserts the dumper carries no
--     creeps at all, so every unit below is a stand-in with exactly the
--     fields `J.CanBeAttacked` reads.
--   * [instrument]: turbo is forced by the fixture LOADER, not read off this
--     frame -- pinned as an assertion below rather than left in prose.
--   * NOT CLAIMED: that the branch is reachable end-to-end under the mock.
--     [limit reach] asserts WHY (the same shape as 'abil1st''s centaur leg):
--     it sits behind `J.IsAttacking`, and this frame's mana is below the
--     branch's own 0.25 precondition. A second layer of declaration on top of
--     a declared camp would be a claim with no frame under it.

package.path = 'tests/?.lua;' .. package.path
local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')
local ss  = require('mock.soak_side')              -- owns bots/Customize/soak_side.lua

local FIX_A = 'tests/fixtures/f_260822_182012_sb_backpack_rescue_372.lua'
local FIX_B = 'tests/fixtures/f_260822_182012_sb_fieldbuy_gate_307.lua'
local JMZ   = 'bots/FunLib/jmz_func.lua'
local SB    = 'bots/BotLib/hero_spirit_breaker.lua'
local CAND  = 'aimguard'

-- Subjects as the dumps gave them: name, level.
local S_SB_A = { 'npc_dota_hero_spirit_breaker', 7 }
local S_SB_B = { 'npc_dota_hero_spirit_breaker', 6 }

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Write the (gitignored) soak_side file the farm writes per wave. The gate is
--- read through its SHIPPED body -- no J.* function is stubbed in this file.
--- GetSoakSideConf caches on first read, so the file must exist BEFORE the
--- frame is loaded, not merely before the call -- which is why this file arms
--- by hand around a fixture load instead of wrapping a closure.
---
--- [GH #365 §3 / GH #229, hero backlog `-78`] The three lines this used to
--- inline are now in tests/mock/soak_side.lua, the switch's one owner: the
--- write is read back (a short write, a full disk or a read-only tree used to
--- present as "the gate did not fire", which is what the unarmed half of the
--- grid below EXPECTS), arming refuses to clobber a switch this process did
--- not write, and `disarm` removes only bytes this process wrote and still owns.
local function arm(sCand)
    ss.arm(sCand)
end

local function disarm()
    ss.disarm()
end

--- Load a frame with the gate already in whatever state the caller wants.
--- `sCand == nil` is the unarmed leg, and it now ASSERTS the switch is absent:
--- "the shipped answer" and "the gate is off" are the same observation only
--- while no soak_side file exists, and that path is one global inode shared
--- with every concurrent lua5.1 process.
local function subject(fix, spec, sCand)
    if sCand then arm(sCand) else ss.assert_clean('unarmed leg') end
    local ok, J, bot = pcall(rf.load, fix, spec[1])
    if not ok then disarm(); error(J, 0) end
    if not (bot ~= nil) then disarm(); error('fixture no longer carries ' .. spec[1], 0) end
    if bot:GetLevel() ~= spec[2] then
        disarm()
        error(string.format('the frame moved: %s used to be level %d here, now %d',
            spec[1], spec[2], bot:GetLevel()), 0)
    end
    return J, bot
end

-- ...and once HERE, at file-load time, the only moment that sees the state this
-- process STARTED in: every armed span ends by removing the switch, and the
-- armed cases can sort before the unarmed ones, so an INHERITED leftover is
-- deleted by a sibling case before any per-case guard looks at it (GH #417:
-- such a leftover survived a per-case guard 19/19 green).
ss.assert_clean('test_aimguard_target_axis')

--- Close a span `subject` opened. On the armed leg the switch cause OUTRANKS
--- the value the body produced (a switch removed mid-span yields the UNARMED
--- value, which #365 §3 spent a round arguing about as an expectation bug); on
--- the unarmed leg the switch must still be absent afterwards.
local function close_span(sCand, ok, err)
    if sCand ~= nil then return ss.finish(ok, err) end
    if ok then ss.assert_clean('unarmed leg, after the case body') end
    if not ok then error(err, 0) end
end

-- The camp as a declared stand-in -- see [W1]. Only the fields
-- `J.CanBeAttacked` reads are supplied. `bOk == false` is spelled as "dead",
-- the single most common real reason index [2] is not a legal charge target on
-- a frame where index [1] still is: the bash that motivated the branch has
-- already killed it.
local function neutral(sName, bOk)
    return api.MakeUnit({
        GetUnitName     = sName,
        IsAncientCreep  = false,
        IsNull          = false,
        IsAlive         = bOk,
        CanBeSeen       = true,
        IsAttackImmune  = false,
        IsInvulnerable  = false,
        GetTeam         = 4,
        GetHealth       = 900,
        GetMaxHealth    = 900,
    })
end

--- The other way index [2] goes illegal, so the lever is not pinned to a
--- single field of the mock: alive and visible, but attack-immune.
local function immune_neutral(sName)
    local u = neutral(sName, true)
    u.__spec.IsAttackImmune = true
    return u
end

--- Call the shipped helper on a real frame, with the gate in a given state.
local function pair_ok(fix, spec, sCand, hGuard, hTarget)
    local J = subject(fix, spec, sCand)
    local ok, answer = pcall(J.CanBeAttackedPair, hGuard, hTarget)
    close_span(sCand, ok, answer)
    return answer
end

--- The same four inputs everywhere, so armed and unarmed are compared on an
--- identical grid rather than on cases chosen per leg.
local function grid()
    return {
        { name = 'guard ok, target ok',     g = neutral('npc_dota_neutral_prowler_acolyte', true),
                                            t = neutral('npc_dota_neutral_prowler_shaman',  true) },
        { name = 'guard ok, target DEAD',   g = neutral('npc_dota_neutral_prowler_acolyte', true),
                                            t = neutral('npc_dota_neutral_prowler_shaman',  false) },
        { name = 'guard ok, target IMMUNE', g = neutral('npc_dota_neutral_prowler_acolyte', true),
                                            t = immune_neutral('npc_dota_neutral_prowler_shaman') },
        { name = 'guard DEAD, target ok',   g = neutral('npc_dota_neutral_prowler_acolyte', false),
                                            t = neutral('npc_dota_neutral_prowler_shaman',  true) },
        { name = 'guard DEAD, target DEAD', g = neutral('npc_dota_neutral_prowler_acolyte', false),
                                            t = neutral('npc_dota_neutral_prowler_shaman',  false) },
    }
end

----------------------------------------------------------------------
-- [W1] world fact: the corpus carries no creeps, stated before it is relied on
----------------------------------------------------------------------

tests['[W1] neither frame carries a creep, so every camp above is declared'] = function()
    for _, pair in ipairs({ { FIX_A, S_SB_A }, { FIX_B, S_SB_B } }) do
        local _, bot = subject(pair[1], pair[2])
        local tNeutrals = bot:GetNearbyNeutralCreeps(1600)
        assert(type(tNeutrals) == 'table' and #tNeutrals == 0,
            'GetNearbyNeutralCreeps answers {} on every fixture (GH #100 section 3); got '
            .. tostring(#tNeutrals))
    end
end

----------------------------------------------------------------------
-- [site] the shipped call site really has the shape this file is about
----------------------------------------------------------------------

tests['[ratchet][site] the branch guards one index and returns the other'] = function()
    local src = read_file(SB)
    -- The premise, read out of the file: the returned charge target is [2].
    assert(src:find('return BOT_ACTION_DESIRE_HIGH, nNeutralCreeps%[2%]', 1, false),
        'the site still returns nNeutralCreeps[2] as the charge target; if that '
        .. 'moved, this whole file is testing a premise that no longer holds')
    -- And the guard is now the pair form, naming BOTH indices.
    assert(src:find('J.CanBeAttackedPair(nNeutralCreeps[1], nNeutralCreeps[2])', 1, true),
        'the guard names the unit it licenses')
    -- Entry already guarantees index [2] exists, so the fix never introduces a
    -- nil read that the shipped code did not already have.
    assert(src:find('#nNeutralCreeps >= 2', 1, true),
        'both disjuncts require at least two units, so [2] is not a new nil risk')
    -- The one-line-for-one-line claim: the bare single-argument guard on this
    -- site is gone, so there is no second copy of the old shape left behind.
    -- Comment lines are stripped first -- the note above the fix quotes the old
    -- shape on purpose, and a census that counted it would be reading prose.
    local code = src:gsub('%-%-[^\n]*', '')
    local _, nBare = code:gsub('J%.CanBeAttacked%(nNeutralCreeps%[1%]%)', '')
    assert(nBare == 0, 'no bare CanBeAttacked(nNeutralCreeps[1]) guard remains in CODE; got ' .. nBare)
end

tests['[ratchet][site] the lever carries no level clause, and is nobody else\'s conjunct'] = function()
    local src = read_file(JMZ)
    local body = src:match('function J%.CanBeAttackedPair%b()(.-)\nend')
    assert(body ~= nil, 'J.CanBeAttackedPair is in jmz_func.lua')
    -- GH #263: the defect is not distributed on the level axis, so the helper
    -- must not read a level. This is the ruling made executable.
    assert(not body:find('GetLevel', 1, true),
        'no level clause in the armed path -- GH #263 measured 5 in-gate episodes '
        .. 'against 138 out-of-gate ones on the same corpus')
    assert(not body:find('ANCIENT_MIN_LEVEL', 1, true), 'and no threshold borrowed from that axis')
    -- The `pullcad` trap: an id written into another gate's conjunction freezes
    -- to FALSE the day that other id is promoted.
    assert(not body:find('abilanc', 1, true) and not body:find('abil1st', 1, true),
        'not conjoined with the other two ids of the [1] family')
    assert(select(2, body:gsub('IsSoakCandidate', '')) == 1,
        'exactly one soak-candidate call -- a single conjunct')
end

----------------------------------------------------------------------
-- [frame] the subjects really are what this file claims
----------------------------------------------------------------------

tests['[frame] both subjects are real spirit_breakers, and turbo is the instrument'] = function()
    local J, bot = subject(FIX_A, S_SB_A)
    assert(bot:GetUnitName() == 'npc_dota_hero_spirit_breaker')
    -- [instrument] turbo is forced by the loader, NOT read off this frame.
    -- Pinned rather than assumed: the gate is turbo-only, so if the loader
    -- ever stops forcing it every [lever] case below silently becomes unarmed.
    assert(J.IsModeTurbo() == true,
        '[instrument] the fixture loader forces GAMEMODE_TURBO; the run behind '
        .. 'these frames was turbo, but this assertion is about the loader')
    local _, botB = subject(FIX_B, S_SB_B)
    assert(botB:GetUnitName() == 'npc_dota_hero_spirit_breaker')
    -- Two frames of the same match at different levels. They are here to show
    -- the lever does NOT move with level -- not to walk a threshold.
    assert(bot:GetLevel() ~= botB:GetLevel(), 'the two frames differ in level')
end

tests['[limit reach] the branch is not reachable end-to-end here, and this says why'] = function()
    -- The same shape as 'abil1st''s centaur leg: rather than leaving "we did
    -- not do end-to-end" in prose, the reason is an assertion that will go red
    -- if it stops being true.
    local src = read_file(SB)
    assert(src:find('J.IsAttacking(bot)', 1, true),
        'the branch sits behind J.IsAttacking, which reads animation state no dump carries')
    assert(src:find('J.GetMP(bot) > 0.25', 1, true), 'and behind a mana precondition of its own')
    local _, bot = subject(FIX_A, S_SB_A)
    local nMp = bot:GetMana() / bot:GetMaxMana()
    assert(nMp < 0.25, string.format(
        'and this frame is below that precondition (%.3f) -- so an end-to-end '
        .. 'claim here would be a declaration stacked on a declared camp; got %.3f', nMp, nMp))
end

----------------------------------------------------------------------
-- [lever] the behaviour change, through the shipped helper on real frames
----------------------------------------------------------------------

tests['[lever] unarmed it IS CanBeAttacked(guard) -- the target is not consulted'] = function()
    for _, c in ipairs(grid()) do
        local got = pair_ok(FIX_A, S_SB_A, nil, c.g, c.t)
        local want = pair_ok(FIX_A, S_SB_A, nil, c.g, c.g)  -- same guard, target ignored
        assert(got == want, 'unarmed, the target cannot change the answer: ' .. c.name)
    end
    -- And the answer it does give is the guard's own attackability.
    assert(pair_ok(FIX_A, S_SB_A, nil, neutral('a', true), neutral('b', false)) == true,
        'unarmed: a live guard passes even with a dead target -- this is shipped behaviour')
    assert(pair_ok(FIX_A, S_SB_A, nil, neutral('a', false), neutral('b', true)) == false,
        'unarmed: a dead guard fails')
end

tests['[lever] armed, the DISCRIMINATING input: guard ok but target not'] = function()
    -- This is the only input on which "guard [1]" and "guard [2]" disagree.
    -- Without it the file would be testing whether the branch fires, not which
    -- unit was guarded -- the failure this stream recorded on 'abil1st' M9,
    -- where a mutation that swapped the selection rule stayed green because
    -- every input made both rules agree.
    assert(pair_ok(FIX_A, S_SB_A, CAND, neutral('a', true), neutral('b', false)) == false,
        'armed: the unit actually charged is dead, so the charge is withheld')
    assert(pair_ok(FIX_A, S_SB_A, CAND, neutral('a', true), immune_neutral('b')) == false,
        'armed: and likewise when it is attack-immune rather than dead')
    -- The mirror image, which is what tells a CONJUNCTION from a SWAP: if the
    -- fix had replaced [1] with [2] instead of conjoining them, this would be
    -- true and the guard the site already shipped would have been thrown away.
    assert(pair_ok(FIX_A, S_SB_A, CAND, neutral('a', false), neutral('b', true)) == false,
        'armed: a dead guard still fails -- the shipped conjunct was kept, not swapped')
    -- Control: armed does not withhold the case the site exists to serve.
    assert(pair_ok(FIX_A, S_SB_A, CAND, neutral('a', true), neutral('b', true)) == true,
        'armed: both legal, so the charge is unchanged')
end

tests['[lever] armed is UNIDIRECTIONAL on the whole grid: it can only withhold'] = function()
    -- The property the comment in jmz_func.lua claims, asserted rather than
    -- argued: on every input, armed implies unarmed. A lever with this shape
    -- cannot invent a firing that does not ship today, so the worst case of
    -- arming it in a wave is a charge that does not happen.
    local nWithheld = 0
    for _, c in ipairs(grid()) do
        local bBase  = pair_ok(FIX_A, S_SB_A, nil,  c.g, c.t)
        local bArmed = pair_ok(FIX_A, S_SB_A, CAND, c.g, c.t)
        assert(not (bArmed and not bBase),
            'armed must never fire where baseline does not: ' .. c.name)
        if bBase and not bArmed then nWithheld = nWithheld + 1 end
    end
    -- ... and the grid actually exercises the difference, so "unidirectional"
    -- is not being satisfied by a lever that does nothing at all.
    assert(nWithheld == 2, 'the grid separates the two legs on exactly the two '
        .. 'illegal-target rows; got ' .. nWithheld)
end

tests['[lever] turbo-only, and only under its own id'] = function()
    -- A different candidate armed must leave the site at shipped behaviour --
    -- the property `pullcad` destroys when an id is written into another
    -- gate's conjunction.
    assert(pair_ok(FIX_A, S_SB_A, 'abil1st', neutral('a', true), neutral('b', false)) == true,
        'another id armed leaves this site alone')
    assert(pair_ok(FIX_A, S_SB_A, 'abilanc', neutral('a', true), neutral('b', false)) == true,
        'including the two ids of the same family')
    -- Turbo-only. GetGameMode is replaced AFTER the frame is loaded and before
    -- the first IsModeTurbo call, so the helper's own cache is still cold.
    arm(CAND)
    local J = select(1, rf.load(FIX_A, S_SB_A[1]))
    GetGameMode = function() return 1 end  -- luacheck: ignore
    local ok, answer = pcall(J.CanBeAttackedPair, neutral('a', true), neutral('b', false))
    GetGameMode = function() return GAMEMODE_TURBO end  -- luacheck: ignore
    close_span(CAND, ok, answer)
    assert(ok, answer)
    assert(answer == true, 'outside turbo the gate is off even when armed')
end

tests['[lever] nil handling adds no new outcome class'] = function()
    assert(pair_ok(FIX_A, S_SB_A, nil,  nil, neutral('b', true)) == false, 'nil guard: false, unarmed')
    assert(pair_ok(FIX_A, S_SB_A, CAND, nil, neutral('b', true)) == false, 'nil guard: false, armed')
    assert(pair_ok(FIX_A, S_SB_A, nil,  neutral('a', true), nil) == true,
        'unarmed, a nil target is not consulted -- shipped behaviour')
    assert(pair_ok(FIX_A, S_SB_A, CAND, neutral('a', true), nil) == false,
        'armed, a nil target is withheld like any other illegal one')
end

tests['[lever] the second frame answers identically -- the lever reads no bot state'] = function()
    -- Level 6 against level 7: if a level clause ever leaked into this helper,
    -- these two frames would stop agreeing. This is the GH #263 ruling as a
    -- standing regression, not as a comment.
    for _, c in ipairs(grid()) do
        local a = pair_ok(FIX_A, S_SB_A, CAND, c.g, c.t)
        local b = pair_ok(FIX_B, S_SB_B, CAND, c.g, c.t)
        assert(a == b, 'the two levels answer the same on: ' .. c.name)
    end
end

return tests
