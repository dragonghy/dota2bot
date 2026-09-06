-- [hero] `liondrainbkb` -- WITHDRAWN 2026-09-06, PREMISE-FALSIFIED.  This file
-- was the lever's validation; it is now the PIN that keeps the falsified
-- premise from being re-derived, and the guard on the shipped predicate the
-- lever tried to narrow.
--
-- WHAT WAS CLAIMED, AND WHAT KILLED IT
-- ------------------------------------
-- bots/BotLib/hero_lion.lua X.ConsiderE picks a Mana Drain target at THREE
-- places and they do not agree about spell immunity:
--
--   mana-refill loop   `J.CanCastOnNonMagicImmune( nCreep )`     <- stricter
--   团战吸蓝 branch     `J.CanCastOnMagicImmune( npcEnemy )`      <- permissive
--   打架抽蓝 branch     `J.CanCastOnNonMagicImmune( botTarget )`  <- stricter
--
-- The two helpers differ by exactly one term, `not npcTarget:IsMagicImmune()`
-- (bots/FunLib/jmz_func.lua :961 vs :988).  The withdrawn lever read that
-- disagreement one way -- the permissive branch is the wrong one, because
-- `lion_mana_drain` carries `SpellImmunityType SPELL_IMMUNITY_ENEMIES_NO` and
-- so "a spell-immune enemy is not a target the engine will accept at all" --
-- and added a turbo-gated veto (`X.lion_IsDrainTargetCastable`) at that one
-- call site.
--
-- THAT SENTENCE WAS THE WHOLE FOUNDATION AND NOTHING IN TREE COULD CHECK IT.
-- It came from an external KV mirror; no KV snapshot in this repo carries a
-- `SpellImmunityType` field at all.  The archived corpus contradicts it on
-- three independent legs, each re-derived from the .dem for this round rather
-- than quoted from the replay-check delivery (iterations/reports/replay-check/
-- domain_hero_34_liondrainbkb.md, which found it first over 75 Lion games):
--
--   (1) ORDER ACCEPTED WHILE IMMUNE -- the leg that falsifies the sentence as
--       written.  1db27d__20260903_093254_slot1: the engine writes
--       `ABILITY lion_mana_drain -> npc_dota_hero_skeleton_king` at t=1526.0
--       with the target's `modifier_black_king_bar_immune` up since t=1518.6.
--       Cast point is 0.3s, so the ORDER was issued ~7.1s INTO the immunity.
--       A refused order writes no `DOTA_COMBATLOG_ABILITY` row at all, which is
--       exactly why the defect could never have been counted on the cast side.
--   (2) THE CHANNEL RUNS INSIDE THE IMMUNITY -- b34547__20260905_004847_slot1,
--       the frame frozen below: `modifier_lion_mana_drain` on bristleback for
--       the full 5.1s [1266.4, 1271.5], nested in BKB [1266.1, 1274.1].
--   (3) MANA ACTUALLY MOVES -- d21f34__20260904_123205_slot1, drain
--       [956.6, 959.9] inside BKB [956.5, 965.5]: Lion 641 -> 798 across the
--       opening second (+157 against a +8/s baseline the two preceding seconds
--       measure), target 455 -> 368 (-87) against a rising trend.  Leg (2)
--       alone would leave "the debuff lands but does nothing"; this closes it.
--
-- So arming the lever would have deleted legal, effective casts -- the one
-- direction a NARROWING lever's negative reading can mean.  The request's
-- finding that the three target tests disagree was REAL; the correction was
-- pointed the wrong way.  Verdict label proposed by replay-check and left to
-- the director: PREMISE-FALSIFIED, not DOMAIN-NOT-REACHED (the domain is not
-- too small -- 16 hero landings on genuinely immune targets in 75 games).
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ---------------------------------------------------------
--   * LEGS (1) AND (3) ARE READINGS, NOT ASSERTIONS.  They live off-corpus in
--     .dem files this repo does not carry, and they are recorded here with the
--     commands that reproduce them (section 0's comment).  Only leg (2) is
--     frozen into a fixture and therefore asserted.  Do not cite (1) or (3) as
--     "tested".
--   * THE MOCK DOES NOT INSTALL THE SHIPPED IsMagicImmune OVERRIDE.  On the
--     loaded frame `bristleback:IsMagicImmune()` answers FALSE even though the
--     frame's own modifier list carries `modifier_black_king_bar_immune`.
--     Section 1 asserts that gap rather than hiding it; section 3 restores the
--     shipped reader's answer with ONE labelled injection, and asserts the
--     injection changed something before leaning on it.  The mapping from the
--     modifier to the answer is read OUT OF bots/FunLib/aba_global_overrides.lua
--     (the same method tests/test_axe_cull_immune_veto.lua uses), never retyped,
--     so a drift in the shipped reader turns this file red instead of stale.
--   * THE SUPPLY TRIPWIRE THIS FILE USED TO CARRY HAS FIRED.  Its previous
--     version asserted 0 spell-immune enemy instants across 8 Lion-subject
--     frames and said, in as many words, that the day one arrived it went RED
--     and named it.  Section 5 is that tripwire after the event: 9 frames, 45
--     enemy instants, exactly 1 immune, named.  That one is the frame that
--     falsified the lever it was built to serve.
--   * WHAT IS NOT SETTLED.  Whether the OTHER two branches' stricter
--     `J.CanCastOnNonMagicImmune` is the side that is wrong is a separate and
--     opposite (WIDENING) lever.  It needs its own id, its own domain and its
--     own evidence; nothing here has measured it, and this file must not be
--     cited for it.
--   * Corpus counts come from `dofile` via the loader, never from a regex over
--     the fixture files.
--
-- Round: GH #566 (backlog item -108), owner priority P4.4.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_lion.lua'
local OVERRIDES = 'bots/FunLib/aba_global_overrides.lua'
local FIXTURE = 'tests/fixtures/f_260905_004847_lion_drain_bkb.lua'
local LION = 'npc_dota_hero_lion'
local BB = 'npc_dota_hero_bristleback'
local DRAIN = 'lion_mana_drain'
local BKB_MOD = 'modifier_black_king_bar_immune'
local DRAIN_MOD = 'modifier_lion_mana_drain'
local CAND = 'liondrainbkb'

-- section 0 -- provenance of the frozen frame, and of the two off-corpus legs.
--
--   bash tools/batch_test/aws/session_setup.sh
--   BIN=$(bash tools/batch_test/behavioral/get_dumper.sh)
--   awsx s3 cp s3://dota2bot-batch-results-4924/dem21/\
-- spot_20260905_003246_1_15b0d9fd25a85805546ccb2d82a66942d5244c94_b34547/\
-- 20260905_004847_slot1.dem g.dem
--   "$BIN" g.dem > timeline.json
--   python3 tools/batch_test/replayscope/make_fixture.py timeline.json \
--       --t 1266.5 --hero lion -o tests/fixtures/f_260905_004847_lion_drain_bkb.lua
--
-- Leg (1) is the same recipe on .../1db27d/20260903_093254_slot1.dem, reading
-- the ABILITY and MODIFIER_ADD/REMOVE events between t=1510 and t=1535.
-- Leg (3) is the same on .../d21f34/20260904_123205_slot1.dem, t=950..970 plus
-- the 1.0s hero snapshots for lion and dragon_knight over t=954..962.

-- Every Lion-SUBJECT fixture, listed rather than globbed so a new one is a
-- deliberate edit and section 5's counts move with a named cause.
local LION_FRAMES = {
    'tests/fixtures/f_045650_lion_meatgrinder.lua',
    'tests/fixtures/f_222428_lion_lich_burst.lua',
    'tests/fixtures/f_260819_182323_lion_drain_calm.lua',
    'tests/fixtures/f_260819_182855_lion_drain_jungle.lua',
    'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua',
    'tests/fixtures/f_260819_183409_lion_drain_focused.lua',
    'tests/fixtures/f_260820_162821_lion_drain_lethal.lua',
    'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
    FIXTURE,
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Load the frozen frame with every gate off (there is no gate left to arm on
--- this path; `IsSoakCandidate` is stubbed false so an armed farm string can
--- never leak into a reading here).
local function load_frame()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    return J, bot, heroes, fx
end

--- The modifier names the shipped IsMagicImmune override consults, read out of
--- that file so this test cannot drift away from the shipped reader.
local function immunity_modifiers()
    local src = read_file(OVERRIDES)
    local from = src:find('function CDOTA_Bot_Script:IsMagicImmune%(%)')
    assert(from, 'the IsMagicImmune override is gone from ' .. OVERRIDES
        .. '; this file was reading its modifier list out of it')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nend') or #rest)
    local set, n = {}, 0
    for name in body:gmatch("HasModifier%('([%w_]+)'%)") do
        if not set[name] then set[name], n = true, n + 1 end
    end
    assert(n >= 11, 'the shipped override now consults ' .. n
        .. ' modifier names, was 11 -- re-read it before quoting any supply number here')
    return set, n
end

local function consider_e_body(src)
    local from = src:find('function X%.ConsiderE%s*%(%s*%)')
    assert(from, 'X.ConsiderE not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth: this really is the branch's own situation, on the replay's
-- numbers, and the harness gap is stated rather than assumed away.

tests['ground truth: 21:06, Lion in a teamfight with only Mana Drain to spend'] = function()
    local J, bot, _, fx = load_frame()
    assert(fx.self == LION and fx.time == 1266.5,
        'the decision instant, got ' .. tostring(fx.self) .. ' @ ' .. tostring(fx.time))
    assert(bot:GetLevel() == 24 and bot:GetHealth() == 1639 and bot:GetMana() == 684,
        'real Lion state, got lvl ' .. bot:GetLevel() .. ' hp ' .. bot:GetHealth()
        .. ' mp ' .. bot:GetMana())
    local X = rf.load_hero('lion')
    assert(J.IsInTeamFight(bot, 1000) == true,
        'the branch premise is the replay\'s, not a stub')
    assert(X.IsOtherAbilityFullyCastable() == false,
        'Impale, Hex and Finger are all uncastable -- the shipped guard above the '
        .. 'branch lets this frame through, which is what makes the branch reachable here')
    local e = bot:GetAbilityByName(DRAIN)
    assert(e:GetLevel() == 4, 'drain is rank 4 -- past the nSkillLV <= 1 early-out')
    assert(e:GetCooldownTimeRemaining() == 0, 'and it is off cooldown on this frame')
end

tests['ground truth: bristleback is a live enemy that clears every other clause'] = function()
    local J, bot, heroes = load_frame()
    local bb = assert(heroes[BB], BB .. ' is not on this frame; the fixture is stale')
    assert(bb:GetTeam() ~= bot:GetTeam(), 'bristleback must be the enemy here')
    assert(bb:IsAlive(), 'and alive')
    assert(GetUnitToUnitDistance(bot, bb) < 850,
        'inside the base 850u cast range, got ' .. math.floor(GetUnitToUnitDistance(bot, bb)))
    assert(bb:GetMana() == 1246, 'clears the >200 mana clause, got ' .. bb:GetMana())
    assert(bb:HasModifier('modifier_lion_finger_of_death') == false, 'not fingered')
    assert(J.IsDisabled(bb) == false, 'not disabled')
    assert(J.CanCastOnTargetAdvanced(bb) == true, 'passes the advanced check')
end

tests['ground truth: the mock does NOT install the shipped IsMagicImmune reader'] = function()
    -- Stated, not hidden.  Section 3's injection exists because of this line,
    -- and if the loader ever grows the override this assertion goes red and
    -- says so -- at which point section 3's injection becomes redundant rather
    -- than wrong.
    local _, _, heroes = load_frame()
    local bb = heroes[BB]
    assert(bb:HasModifier(BKB_MOD) == true, 'the frame really carries the BKB modifier')
    assert(bb:IsMagicImmune() == false,
        'HARNESS GAP, NOT A CORPUS FACT: the mock answers IsMagicImmune from its own '
        .. 'spec, not from bots/FunLib/aba_global_overrides.lua, so it says false on a '
        .. 'frame whose modifier list says otherwise.  If this went red the loader now '
        .. 'installs the shipped reader -- good news; drop section 3\'s injection.')
end

-- ---------------------------------------------------------------- section 2 --
-- THE FALSIFIER.  Both facts are the replay's own; nothing is injected here.

tests['falsifier: the engine ran a Mana Drain ON a spell-immune enemy'] = function()
    local _, _, heroes = load_frame()
    local bb = heroes[BB]
    local set = immunity_modifiers()
    assert(set[BKB_MOD], BKB_MOD .. ' is no longer one of the names the shipped '
        .. 'IsMagicImmune reader consults -- this whole section rests on that mapping')
    assert(bb:HasModifier(BKB_MOD) == true,
        'the target is spell-immune by the shipped reader\'s own criterion')
    assert(bb:HasModifier(DRAIN_MOD) == true,
        'AND Lion\'s drain debuff is on that same target at that same instant.  This '
        .. 'co-occurrence is the falsifier: "a spell-immune enemy is not a target the '
        .. 'engine will accept at all" cannot survive a frame in which the engine has '
        .. 'accepted one and is draining it.')
end

tests['falsifier: it is the immunity that is running late, not the drain'] = function()
    -- The one reading that stops "the BKB went up mid-cast" from explaining the
    -- frame away: at this instant the immunity has 7.6s left and the drain 5.0,
    -- so the channel ENDS inside the immunity window -- it is nested, not
    -- overlapping.  (Cast point is 0.3s, so a start-of-cast alibi would need
    -- the BKB to have appeared within 0.3s of the order; leg (1) in the header
    -- removes that alibi outright, with 7.1s of lead.)
    local _, _, _, fx = load_frame()
    local unit
    for _, u in ipairs(fx.units) do if u.name == BB then unit = u end end
    assert(unit, BB .. ' is not in the fixture\'s unit table')
    local function remaining(name)
        for _, m in ipairs(unit.modifiers or {}) do
            if m.name == name then return m.remaining, m.elapsed end
        end
        return nil
    end
    local immRem, immEl = remaining(BKB_MOD)
    local drRem, drEl = remaining(DRAIN_MOD)
    assert(immRem and drRem, 'both modifiers must carry timings on this frame')
    assert(drRem <= immRem, 'the drain must end no later than the immunity, got drain '
        .. drRem .. 's left vs immunity ' .. immRem .. 's left')
    assert(drEl <= immEl, 'and it must have started no earlier, got drain elapsed '
        .. drEl .. ' vs immunity elapsed ' .. immEl)
end

-- ---------------------------------------------------------------- section 3 --
-- What the withdrawn direction would have done to this frame.  ONE labelled
-- injection: it restores the answer the SHIPPED override would give in game
-- from this frame's own real modifier (section 1 pins why it is needed).

tests['counterfactual: the stricter helper refuses the cast the engine allowed'] = function()
    local J, _, heroes = load_frame()
    local bb = heroes[BB]

    -- before: the harness gap makes the two helpers indistinguishable here, so
    -- an un-injected comparison would prove nothing at all.
    assert(J.CanCastOnMagicImmune(bb) == J.CanCastOnNonMagicImmune(bb),
        'without the injection the two helpers cannot be told apart on this frame; '
        .. 'a comparison taken here would be vacuous')

    rawget(bb, '__spec').IsMagicImmune = true  -- INJECTION, see HONEST BOUNDS

    assert(bb:IsMagicImmune() == true, 'the injection took')
    assert(J.CanCastOnMagicImmune(bb) == true,
        'the SHIPPED predicate at the 团战吸蓝 call site still accepts bristleback -- '
        .. 'and the replay says the engine did too')
    assert(J.CanCastOnNonMagicImmune(bb) == false,
        'while the stricter helper -- the direction the withdrawn lever pushed -- '
        .. 'refuses exactly this target.  On this frame that refusal would have '
        .. 'deleted a drain that really ran for 5.1s.')
end

-- ---------------------------------------------------------------- section 4 --
-- The withdrawal, pinned on the source.  These are what stop the lever from
-- coming back without an answer to section 2.

tests['withdrawal: no liondrainbkb gate survives anywhere in bots/'] = function()
    local hero = read_file(SRC)
    local fun = read_file('bots/FunLib/jmz_func.lua')
    local ov = read_file(OVERRIDES)
    for _, pair in ipairs({ { SRC, hero }, { 'bots/FunLib/jmz_func.lua', fun },
                            { OVERRIDES, ov } }) do
        local path, body = pair[1], pair[2]
        assert(body:find("IsSoakCandidate%s*%(%s*'" .. CAND .. "'") == nil,
            path .. ' still gates on ' .. CAND .. '; the lever was withdrawn, so a live '
            .. 'gate here means it came back without answering section 2')
    end
    -- Definition and call form, not the bare name: the PREMISE-FALSIFIED note
    -- above has to be free to say what it retired, and a note that cannot name
    -- the thing is a note nobody can act on.
    assert(hero:find('function%s+X%.lion_IsDrainTargetCastable') == nil,
        SRC .. ' still DEFINES X.lion_IsDrainTargetCastable')
    assert(hero:find('X%.lion_IsDrainTargetCastable%s*%(') == nil,
        SRC .. ' still CALLS X.lion_IsDrainTargetCastable')
end

tests['withdrawal: the 团战吸蓝 branch reads the permissive helper again'] = function()
    local body = consider_e_body(read_file(SRC))
    assert(body:find('and J%.CanCastOnMagicImmune%(%s*npcEnemy%s*%)'),
        'the 团战吸蓝 branch no longer calls J.CanCastOnMagicImmune( npcEnemy ) -- if this '
        .. 'is a deliberate re-narrowing, section 2\'s frame is the thing to explain first')
    -- The other two branches are untouched by this round, and saying so here
    -- keeps the WIDENING question visibly open instead of silently answered.
    local src = read_file(SRC)
    assert(src:find('J%.CanCastOnNonMagicImmune'),
        'the stricter helper is gone from ' .. SRC .. '; that would be the widening '
        .. 'lever this round explicitly did NOT take -- it needs its own id and evidence')
end

tests['withdrawal: the falsified premise is recorded next to the code'] = function()
    local src = read_file(SRC)
    assert(src:find('PREMISE%-FALSIFIED'),
        SRC .. ' no longer carries the PREMISE-FALSIFIED note.  The note is the only '
        .. 'thing standing between the next reader and re-deriving the same veto from '
        .. 'the same external KV sentence.')
    assert(src:find('1db27d') and src:find('b34547') and src:find('d21f34'),
        'the note must keep naming all three replays; a premise retired without its '
        .. 'evidence is just an opinion')
end

-- ---------------------------------------------------------------- section 5 --
-- The supply, measured -- the old tripwire after it fired.

tests['supply: exactly one spell-immune enemy instant across the Lion frames'] = function()
    local set = immunity_modifiers()
    local nFrames, nEnemies, nImmune, sWhere = 0, 0, 0, {}
    for _, path in ipairs(LION_FRAMES) do
        local J, bot, heroes, fx = rf.load(path)
        J.IsSoakCandidate = function() return false end
        assert(fx.self == LION, path .. ' is not a Lion-subject frame; LION_FRAMES is stale')
        nFrames = nFrames + 1
        for name, h in pairs(heroes) do
            if h:GetTeam() ~= bot:GetTeam() then
                nEnemies = nEnemies + 1
                for m in pairs(set) do
                    if h:HasModifier(m) then
                        nImmune = nImmune + 1
                        sWhere[#sWhere + 1] = path .. ' / ' .. name .. ' / ' .. m
                        break
                    end
                end
            end
        end
    end
    assert(nFrames == 9, 'LION_FRAMES moved to ' .. nFrames
        .. '; re-read the counts here before trusting them')
    assert(nEnemies == 45, 'enemy hero-instants moved from the measured 45 to ' .. nEnemies)
    assert(nImmune == 1, 'spell-immune enemy instants moved from 1 to ' .. nImmune
        .. ' (' .. table.concat(sWhere, '; ') .. ').  More is not a regression -- it is '
        .. 'more supply for the WIDENING question section 4 leaves open.')
    assert(sWhere[1] == FIXTURE .. ' / ' .. BB .. ' / ' .. BKB_MOD,
        'the one immune instant is no longer the frame this round froze, got '
        .. tostring(sWhere[1]))
end

return tests
