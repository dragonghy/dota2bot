-- [GH: ownhalf margin] Two sibling helpers ask the SAME question about the SAME
-- quantity and answered it with two different numbers.
--
-- THE DEFECT. "Is this enemy far enough onto OUR ground to be treated as an
-- invader" is computed in this tree as one quantity: the difference between the
-- enemy's distance to its own ancient and its distance to ours. Three places
-- read it, all three hand the answer to the same commit test
-- (J.SafeToCommitFight), and the margin they require was:
--
--   J.SafeToCommitFight, 'depthnum' branch     1600  (with its reason written)
--   J.ShouldPunishOverchase, midline branch    1600  (corrected 2026-09-07)
--   J.ShouldPunishDive, 'ownhalf' branch        800  <-- this one
--
-- The reason the other two carry 1600 is the failure this whole family exists
-- to avoid, and it is written out at the depthnum branch: the commit test reads
-- VISIBLE bodies only, so within about a screen of the midline the other side's
-- reinforcements are in fog and instantaneous parity systematically
-- overestimates safety. That is AGENTS.md's 2v2-becomes-2v4, and it cost a
-- batch run. 800u past the midline is the river bank, not the "CLEARLY on our
-- half" that the branch's own comment claimed -- the constant contradicted the
-- sentence justifying it.
--
-- WHY THIS IS A FIX AND NOT A NEW POLICY. No number is invented here. 1600 is
-- the tree's own ancient-distance convention, already shipped twice, and the
-- depthnum comment names J.ShouldRegroupNotSolo as its source. This branch was
-- written first and was simply never revisited when the sibling was corrected.
-- Section 1 therefore asserts the three margins are EQUAL rather than that this
-- one is 1600: symmetry is the property, 1600 is only today's value.
--
-- ⭐ THE NUMBERS (tests/_posture_domain_sweep.lua, 110 fixtures / 1021 live
-- hero-frames; two independent roads to the same fact):
--   * POPULATION ARITHMETIC, from positions and ancients only -- no getter this
--     corpus stubs. Of the 741 (bot, enemy) pairs with no allied building
--     within 1200 of the target, 97 cleared the shallow margin and 54 clear the
--     sibling's, so `pd_oh_band` 43 pairs on `pd_oh_band_frames` 37 distinct
--     frames entered the domain ONLY because the margin was the shallow one.
--   * THE DRIVEN HELPER, armed on 'ownhalf': `pd_fires_ownhalf` 79 -> 56 and
--     `pd_ownhalf_only` 51 -> 28. Twenty-three frames stop punishing.
--   The two roads do not have to agree on a number and they do not: 37 is the
--   arithmetic UPPER BOUND (a frame in the band can still be in domain via a
--   second enemy past 1600, or be refused downstream by SafeToCommitFight /
--   J.ShouldRefuseUnsupportedPunish anyway) and 23 is what the function
--   actually did. Section 4 asserts the bound, not an equality -- claiming
--   equality here would be a coincidence dressed as a check.
--
-- ⭐⭐ THE FORBIDDEN DIRECTION IS MEASURED, NOT ARGUED. The domain at a larger
-- margin is a subset of the domain at a smaller one, so armed this can only
-- DELETE a punish. `pd_fires_shipped` is 28 before and 28 after, digit for
-- digit: the building branch -- the whole shipped path -- is untouched, which
-- is what section 3 pins as an identity rather than as a literal.
--
-- ⭐⭐⭐ NEGATIVE CONTROL, BECAUSE "NARROWED" AND "SWITCHED OFF" PASS THE SAME
-- POSITIVE TEST. That is the lanefix lesson in one line, and the overchase
-- round's own near-miss (its M2 mutant over-tightened into a disable and the
-- positive control still passed). Section 6 holds a frame that must STILL fire
-- armed. Without it, deleting the branch outright would go green here.
--
-- ⭐⭐⭐⭐ NO NEW SOAK ID, ON PURPOSE -- the rule the 0OVERCHASE round wrote
-- down. This branch already hangs on the unpromoted 'ownhalf' candidate, so a
-- nested J.IsSoakCandidate('<new>') would be the conjunction `ownhalf AND
-- <new>`; a wave arming <new> alone would read a zero that is STRUCTURALLY
-- impossible rather than informative, and check_armed_wiring.py would still
-- call it WIRED (GH #606, the #576/#600/#607 family). So the narrowing edits
-- the host's own body and inherits the host's id, and section 2 pins that no
-- new gate appeared inside the branch.
--
-- ⛔ REGISTERED CONSEQUENCE, SAID BEFORE ANY WAVE (GH #622). 'ownhalf' is the
-- SOLE ENABLER of 'ohnum''s effective domain (state.json:ownhalf_KEPT_20260908:
-- on the shipped path J.ShouldPunishDive reaches J.ShouldRefuseUnsupportedPunish
-- only when the target has NO allied building within 1200, which is exactly the
-- complement of the building branch). So this narrowing shrinks 'ohnum''s
-- reachable frames by the same band. Neither id is armed in W60 or W61, so no
-- flying wave is disturbed -- but a future 'ohnum' reading is a reading of the
-- narrowed domain, and that must not be discovered afterwards.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Every witness below is a line the sweep printed about itself; none was gone
-- looking for. CLOSED and SURVIVES come off the `F ... pd_ownhalf` set before
-- and after the change, SHIPPED off `F ... pd_shipped`.
local CLOSED      = 'tests/fixtures/f_260820_042607_zuus_reserve_cross.lua'
local CLOSED_HERO = 'npc_dota_hero_zuus'
local SURVIVES      = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua'
local SURVIVES_HERO = 'npc_dota_hero_bristleback'
local SHIPPED      = 'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua'
local SHIPPED_HERO = 'npc_dota_hero_lion'

-- ------------------------------------------------------------ source reads --

local function jmz_source()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

local function block(header)
    local src = jmz_source()
    local at = assert(src:find(header, 1, true), header .. ' moved')
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

-- Comments are stripped before every structural read: this file's own header
-- quotes both margins and both id names in prose, and so does the note in the
-- helper, so an unstripped search would anchor on the explanation instead of
-- the code.
local function stripped(s)
    local out = {}
    for line in (s .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

-- ------------------------------------------------------------- the manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_posture_domain_sweep.lua 2>&1'),
        'could not start tests/_posture_domain_sweep.lua')
    local raw = p:read('*a')
    p:close()
    local m = { C = {}, G = {}, F = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local kind = line:match('^(%S+)')
        if kind == 'C' then
            local k, n = line:match('^C (%S+) (%-?%d+)$')
            if k then m.C[k] = tonumber(n) end
        elseif kind == 'G' then
            local k, v = line:match('^G (%S+) (%S+)$')
            if k then m.G[k] = v end
        elseif kind == 'F' then
            local fx, hero, what = line:match('^F (%S+) (%S+) (%S+)')
            if fx then table.insert(m.F, { fixture = fx, hero = hero, what = what }) end
        elseif kind == 'DONE' then
            m.done = true
        end
    end
    assert(m.done, 'the corpus sweep did not finish -- run '
        .. '`lua5.1 tests/_posture_domain_sweep.lua` by hand to see why:\n'
        .. raw:sub(1, 800))
    manifest_cache = m
    return m
end

local function C(key)
    local n = manifest().C[key]
    assert(n ~= nil, 'the sweep did not report counter ' .. key)
    return n
end

local function drive(path, hero, armed_ids)
    local J, bot = rf.load(path, hero)
    J.IsSoakCandidate = function(id) return armed_ids[id] == true end
    return J.ShouldPunishDive(bot)
end

-- ==================== 1. one quantity, one margin, asserted as an identity --

tests['[ownhalf] the three ancient-distance margins are the same number']
= function()
    local dive = tonumber(block('function J.ShouldPunishDive( bot )')
        :match('nInvadeDepth >= (%d+)'))
    local chase = tonumber(block('function J.ShouldPunishOverchase( bot )')
        :match('GetLocation%(%) %) %- (%d+)'))
    local commit = tonumber(block('function J.SafeToCommitFight( bot, target )')
        :match('GetLocation%(%) %) %- (%d+)'))
    assert(dive ~= nil,
        "the ownhalf branch no longer states its margin as `nInvadeDepth >= " ..
        "<number>` -- either the branch moved or the number is behind a " ..
        'variable now, and a pin that cannot read the ruler cannot check it')
    assert(chase ~= nil, 'could not read the overchase midline margin')
    assert(commit ~= nil, "could not read J.SafeToCommitFight's depthnum margin")
    -- The property is SYMMETRY. Asserting equality means the day someone
    -- re-tunes the convention, a site that kept the old value goes red here
    -- instead of quietly becoming a different lever -- and a rollback of THIS
    -- change (dive back to 800) is caught by the same line.
    assert(dive == chase,
        'J.ShouldPunishDive treats an enemy as an invader at ' .. dive ..
        'u past the midline while J.ShouldPunishOverchase requires ' .. chase ..
        'u -- same quantity, same team\'s ground, same downstream commit ' ..
        'test, two numbers. That disagreement IS the defect this file pins.')
    assert(dive == commit,
        'the ownhalf margin (' .. dive .. ') has drifted from the depthnum ' ..
        'convention it borrows (' .. commit .. '); the tree is supposed to ' ..
        'have ONE ancient-distance margin, not one per helper')
end

-- ================================= 2. the repair inherits the host's gate --

tests['[ownhalf] the narrowing sits inside the ownhalf branch and adds no gate']
= function()
    local body = stripped(block('function J.ShouldPunishDive( bot )'))
    local atGate = body:find("bOwnHalf = J.IsSoakCandidate%(%s*'ownhalf'%s*%)")
    local atBranch = body:find('if not bInDomain and bOwnHalf', 1, true)
    local atMargin = body:find('nInvadeDepth >= ', 1, true)
    assert(atGate ~= nil, "J.ShouldPunishDive no longer reads the 'ownhalf' id")
    -- Split from the pin below so the two failures do not share a message: the
    -- branch existing WITHOUT its gate conjunct is an accidental promote, and a
    -- reader told only "re-anchor this pin" would not know that.
    if atBranch == nil then
        local atBare = body:find('if not bInDomain', 1, true)
        assert(atBare == nil,
            'the invade-depth branch no longer asks whether anything armed ' ..
            "'ownhalf' -- the wider punish domain would then run in every " ..
            'turbo game, which is an unpromoted behaviour change live in ' ..
            'real games')
    end
    assert(atBranch ~= nil, 'the ownhalf branch moved; re-anchor this pin')
    assert(atMargin ~= nil, 'the invade-depth margin moved; re-anchor this pin')
    assert(atGate < atBranch and atBranch < atMargin,
        'the gate, the branch and the margin are no longer in that order -- ' ..
        'a margin that can be reached without the gate is an unpromoted ' ..
        'behaviour change live in real games')
    -- The 0OVERCHASE rule, as an assertion rather than as a comment: exactly
    -- one soak id may be named in this helper's ownhalf path. A second one
    -- here is the conjunction `ownhalf AND <new>`, whose single-arm zero is
    -- structurally impossible and which check_armed_wiring.py calls WIRED.
    local tail = body:sub(atBranch)
    assert(tail:find("IsSoakCandidate") == nil,
        'a soak gate appeared inside or below the ownhalf branch -- if that ' ..
        'is a deliberate new candidate, read the note in this file first: ' ..
        'nested inside an unpromoted host it can never produce a readable ' ..
        'single-arm reading (GH #606 / #576 / #600 / #607)')
end

-- ============================ 3. the shipped path is untouched, as a bound --

tests['[ownhalf] the building branch is a strict subset of the armed domain']
= function()
    local shipped, armed, only = C('pd_fires_shipped'), C('pd_fires_ownhalf'),
        C('pd_ownhalf_only')
    assert(shipped > 0,
        'the corpus no longer witnesses the SHIPPED dive domain at all (' ..
        shipped .. ') -- every claim below about "the shipped path is ' ..
        'unchanged" would be vacuous')
    assert(armed >= shipped,
        'the armed drive fires on FEWER frames (' .. armed .. ') than the ' ..
        'shipped one (' .. shipped .. '); the ownhalf branch only ever ADDS ' ..
        'to the domain, so this is impossible unless it now removes frames')
    assert(only == armed - shipped,
        'ownhalf-only is ' .. only .. ' but armed-minus-shipped is ' ..
        (armed - shipped) .. '; the two disagree, so one of the drives is no ' ..
        'longer measuring what its name says')
end

-- ================== 4. the band is closed, and closed in the one direction --

tests['[ownhalf] no pair enters the domain on the shallow margin any more']
= function()
    assert(C('pd_oh_band') == 0,
        C('pd_oh_band') .. ' (bot, enemy) pairs still enter the ownhalf ' ..
        'domain under this helper\'s margin but not under the sibling\'s -- ' ..
        'the band is exactly what this change closes, so a non-zero here ' ..
        'means the margins drifted apart again')
    assert(C('pd_oh_margins_differ') == 0 and C('pd_oh_margins_equal') == C('live'),
        'the sweep reports the two margins unequal on ' ..
        C('pd_oh_margins_differ') .. ' of ' .. C('live') .. ' frames')
    assert(C('pd_oh_ge_dive') == C('pd_oh_ge_chase'),
        'the two margins admit different populations (' .. C('pd_oh_ge_dive') ..
        ' vs ' .. C('pd_oh_ge_chase') .. ') while claiming to be equal -- ' ..
        'that combination means the sweep is parsing one of them wrong')
    -- The driven closure must not exceed its arithmetic bound. It is a BOUND
    -- and not an equality on purpose: a banded frame can survive via a second
    -- enemy past the margin, or die downstream for reasons this branch does
    -- not own. See the header.
    assert(C('pd_oh_nobuilding') > 0,
        'no pair in the corpus reaches the ownhalf branch at all (' ..
        C('pd_oh_nobuilding') .. ') -- this whole file would be vacuous')
    -- pd_pairs was declared by the round that created the sweep and never
    -- bumped: a column that could only ever print 0, standing beside real
    -- ones. Pinned so the repair cannot silently regress.
    assert(C('pd_pairs') > 0,
        'pd_pairs is back to 0 -- it is the sweep\'s own funnel count and a ' ..
        'permanently-zero column next to real ones is how a domain gets read ' ..
        'as empty when it is only unmeasured (the GH #171 shape)')
end

-- ================================= 5. the positive control, on a real frame --

tests['[ownhalf] the river-bank punish is refused on the frame it was found on']
= function()
    assert(drive(CLOSED, CLOSED_HERO, { ownhalf = true }) == nil,
        'armed, J.ShouldPunishDive still commits on ' .. CLOSED_HERO ..
        '\'s frame in ' .. CLOSED .. ' -- the frame the sibling helper ' ..
        'already refuses at the same depth, and the one this change exists for')
    assert(drive(CLOSED, CLOSED_HERO, {}) == nil,
        'the SHIPPED path fires on that frame, so the refusal above is not ' ..
        'this branch\'s doing and the witness proves nothing')
end

-- ==================== 6. the negative control: narrowed, not switched off --

tests['[ownhalf] a genuinely deep invader is still punished'] = function()
    local target = drive(SURVIVES, SURVIVES_HERO, { ownhalf = true })
    assert(target ~= nil,
        'armed, nothing is punished on ' .. SURVIVES_HERO .. '\'s frame in ' ..
        SURVIVES .. ' either -- deleting the ownhalf branch outright passes ' ..
        'every other assertion in this file, and only this one can tell ' ..
        '"narrowed" from "switched off" (the lanefix lesson)')
    assert(drive(SURVIVES, SURVIVES_HERO, {}) == nil,
        'the shipped path punishes there too, so this frame no longer ' ..
        'witnesses the ownhalf branch and the control is not a control')
end

-- ================ 7. the shipped answer is byte-for-byte what it always was --

tests['[ownhalf] arming the id changes nothing where a building is in range']
= function()
    local unarmed = drive(SHIPPED, SHIPPED_HERO, {})
    local armed = drive(SHIPPED, SHIPPED_HERO, { ownhalf = true })
    assert(unarmed ~= nil,
        SHIPPED_HERO .. ' no longer reaches the shipped dive domain in ' ..
        SHIPPED .. '; pick another `F ... pd_shipped` witness')
    assert(armed ~= nil and armed:GetUnitName() == unarmed:GetUnitName(),
        'the armed drive answers ' ..
        (armed and armed:GetUnitName() or 'nil') .. ' where the shipped one ' ..
        'answers ' .. unarmed:GetUnitName() .. ' -- this change is not ' ..
        'allowed to touch a frame the building branch already owns')
end

return tests
