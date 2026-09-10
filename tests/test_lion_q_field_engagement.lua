-- [hero] `lionqfight` -- the engagement test Lion's catch-all Earth Spike branch
-- was written WITH and can never use.
--
-- THE DEFECT, in the first line of X.ConsiderQ's `--常规` branch:
--
--     if ( #hEnemyList > 0 or bot:WasRecentlyDamagedByAnyHero( 3.0 ) )
--         and ( ... ~= BOT_MODE_RETREAT or #hAllyList >= 2 )
--         and #nInRangeEnemyList >= 1
--         and nLV >= 15
--
-- The right half of that first parenthesis is an ENGAGEMENT test (somebody hit
-- Lion inside three seconds).  The left half is a bare PROXIMITY count -- and it
-- is IMPLIED BY THE SAME `if`'s third conjunct.  `hEnemyList` is
-- `J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)`; `nInRangeEnemyList` is the
-- same helper with the same filters at radius `nCastRange`.  So
-- `#nInRangeEnemyList >= 1` forces `#hEnemyList > 0` whenever nCastRange <= 1600,
-- `or` short-circuits on its left, and the engagement test is never evaluated for
-- ANY input.  What fires the branch is proximity alone.
--
-- ⭐ §1 CHECKS THE SUBSUMPTION AS ARITHMETIC rather than asserting it in prose,
-- because the margin is smaller than it looks: lion_impale's AbilityCastRange is
-- 650 with a +600 `special_bonus_unique_lion_2`, and X.SkillsComplement hands
-- J.GetAetherLensRangeBonus a 250 (25 more than the item KV's 225), so the
-- worst case over the whole ladder is 650 + 600 + 250 + 20 = 1520 -- inside the
-- 1600 by EIGHTY units.  Under the shipped talent build it is not close at all
-- (t25 is `{0, 10}`, which takes +250 AoE Hex and never the cast range), and §1
-- pins both numbers so a patch that moves either one goes red here.
--
-- ⛔ §3 ASSERTS A NO-OP, AND THAT IS THE HONEST READING.  Driven over both corpus
-- directories this branch has an EMPTY domain: 38 live-Lion instants -> 4 at hero
-- level >= 15 -> 0 with Impale fully castable AND >= 1 enemy inside the ring.
-- `nLV >= 15` is the binding clause.  So this lever is NOT locally validated in
-- the sense AGENTS.md means; §4 is gate plumbing and says so.  The next step is to
-- cut Lion frames AT the branch's own predicate -- the reverse-lookup recipe of
-- tests/frames/f_260909_215227_zeus_exec_*.lua -- not to hope a corpus cut for
-- other questions contains one.  Precedent for landing the term anyway:
-- tests/test_lion_q_kill_reach.lua drives the same no-op claim for `lionqkill`.
--
-- ⚠️ NOT claimed here: a frequency.  38 live-Lion instants are a DOMAIN.  Nothing
-- in this file says how often a level-15 Lion stands inside his own cast range in
-- a real Turbo game; sizing that needs a wave.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local SRC   = 'bots/BotLib/hero_lion.lua'
local CAND  = 'lionqfight'
local UNIT  = 'npc_dota_hero_lion'
local IMPALE = 'lion_impale'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The radius X.SkillsComplement builds hEnemyList at.  Read off the source in
-- §1 rather than trusted here.
local WIDE_RADIUS = 1600

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list, so a frame
--- added by another round is seen here without an edit.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local p = io.popen('ls ' .. dir .. '/*.lua 2>/dev/null')
        if p ~= nil then
            for line in p:lines() do out[#out + 1] = line end
            p:close()
        end
    end
    return out
end

local function has_live_lion(path)
    local chunk = loadfile(path)
    if chunk == nil then return false end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then return false end
    for _, u in ipairs(data.units or {}) do
        if u.name == UNIT and u.alive ~= false then return true end
    end
    return false
end

--- Load a frame with Lion as the subject, arming exactly the ids in `tOn`.
local function frame(path, tOn)
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return tOn[id] == true end
    J.IsModeTurbo = function() return true end
    local X = rf.load_hero('lion')
    return J, bot, X
end

--- Drive the REAL X.SkillsComplement dispatch and return the ability names it
--- ordered, in order.  No injection anywhere in this file.
local function drive(path, tOn)
    local _, bot, X = frame(path, tOn)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local out = {}
    for _, a in ipairs(log) do
        local h = a.args and a.args[1]
        if h ~= nil and type(h) == 'table' and h.GetName ~= nil then
            out[#out + 1] = a.fn .. ':' .. tostring(h:GetName())
        end
    end
    return table.concat(out, '|')
end

-- ---------------------------------------------------------------- section 1 --
-- The subsumption, as arithmetic over the ability's own KV ladder.  This is the
-- load-bearing claim of the whole file: if it stops holding, the engagement test
-- can bind and there is no defect to gate.

tests['§1.1 hEnemyList really is the 1600u list, read off the source'] = function()
    local body = read_file(SRC)
    assert(body:find('hEnemyList = J.GetNearbyHeroes%(bot, ' .. WIDE_RADIUS .. ', true, BOT_MODE_NONE %)'),
        'X.SkillsComplement no longer builds hEnemyList with J.GetNearbyHeroes at '
        .. WIDE_RADIUS .. '. The subsumption argument in the header is about THAT '
        .. 'call; re-derive it before editing this number.')
end

tests['§1.2 nInRangeEnemyList is the same helper with the same filters'] = function()
    local body = read_file(SRC)
    local head = body:match('function X%.ConsiderQ%(%)(.-)\n\t%-%-击杀')
    assert(head ~= nil, 'X.ConsiderQ no longer opens with the kill loop; re-read the branch.')
    assert(head:find('nInRangeEnemyList = J%.GetNearbyHeroes%(bot, nCastRange, true, BOT_MODE_NONE %)'),
        'nInRangeEnemyList is no longer J.GetNearbyHeroes(bot, nCastRange, ...). Both '
        .. 'lists must come from the same helper for the subset argument to hold: '
        .. 'that helper is what applies IsValidHero / IsMeepoClone / tempest_double.')
    assert(head:find('local nCastRange = abilityQ:GetCastRange%(%) %+ aetherRange %+ 20'),
        'X.ConsiderQ no longer computes nCastRange as GetCastRange() + aetherRange + 20; '
        .. 'the ceiling in §1.3 is built out of exactly those three terms.')
end

tests['§1.3 the worst-case nCastRange stays inside 1600, and the slack is 80'] = function()
    local kv = shapes.SHAPES['lion'][IMPALE]['AbilityCastRange']
    assert(kv ~= nil, IMPALE .. ' no longer declares AbilityCastRange in the KV snapshot.')

    local nBase = 0
    for tok in tostring(kv.base):gmatch('%S+') do
        local v = tonumber(tok)
        if v ~= nil and v > nBase then nBase = v end
    end
    assert(nBase == 650, ('lion_impale AbilityCastRange base moved to %d (was 650). '
        .. 'Re-take the ceiling below rather than editing this number.'):format(nBase))

    local nTalent = 0
    for sName, sVal in pairs(kv.bonus or {}) do
        local v = tonumber(tostring(sVal):match('%-?%d+') or '')
        if v ~= nil and v > nTalent then
            nTalent = v
            assert(sName == 'special_bonus_unique_lion_2',
                'a NEW cast-range bonus appeared on lion_impale (' .. sName .. '). '
                .. 'The 80-unit margin below was computed against the +600 talent alone.')
        end
    end
    assert(nTalent == 600, ('the lion_impale cast-range talent moved to +%d (was +600).'):format(nTalent))

    -- The aether term, read off THIS file rather than off the item's KV: the
    -- shipped call hands the helper 250, which is 25 more than item_aether_lens
    -- grants (cast_range_bonus 225), and it is the shipped number that decides
    -- the margin.
    local body = read_file(SRC)
    local nAether = tonumber(body:match('aetherRange = J%.GetAetherLensRangeBonus%( aether, (%d+) %)'))
    assert(nAether == 250, 'X.SkillsComplement no longer hands J.GetAetherLensRangeBonus a 250.')

    local nSlack = 20   -- X.ConsiderQ's own `+ 20`, pinned in §1.2
    local nCeiling = nBase + nTalent + nAether + nSlack
    assert(nCeiling == 1520, ('worst-case nCastRange is now %d, not 1520.'):format(nCeiling))
    assert(nCeiling < WIDE_RADIUS,
        ('worst-case nCastRange %d has reached the %d that builds hEnemyList. The left '
         .. 'disjunct of the 常规 branch is no longer implied by `#nInRangeEnemyList >= 1`, '
         .. 'so the engagement test CAN bind and `lionqfight` is no longer a repair of '
         .. 'dead code. Re-read the branch before touching this assert.')
            :format(nCeiling, WIDE_RADIUS))
    assert(WIDE_RADIUS - nCeiling == 80,
        ('the margin moved to %d units (was 80). The header quotes 80; fix the prose '
         .. 'in the same edit.'):format(WIDE_RADIUS - nCeiling))
end

tests['§1.4 the shipped talent build never takes the +600, so the real ceiling is 920'] = function()
    local body = read_file(SRC)
    local t25 = body:match("%['t25'%] = %{(.-)%}")
    assert(t25 ~= nil, 'tTalentTreeList no longer carries a t25 row.')
    assert(t25:gsub('%s', '') == '0,10',
        ('t25 is now {%s}. `{0, 10}` takes the ODD tier entry (+250 AoE Hex); the EVEN '
         .. 'one is +600 Earth Spike cast range. If this build starts taking the even '
         .. 'entry the real ceiling becomes 1520 and the margin is 80, not 680.'):format(t25))
    local nRealCeiling = 650 + 250 + 20
    assert(WIDE_RADIUS - nRealCeiling == 680,
        'the shipped-build slack is no longer 680; the header quotes it.')
end

-- ---------------------------------------------------------------- section 2 --
-- Gate-off equivalence and gate hygiene.  A soak candidate that is not byte-for-
-- byte the shipped behaviour with its gate off is not a soak candidate.

tests['§2.1 the helper is turbo-gated on exactly this id and names no other'] = function()
    local body = read_file(SRC)
    local fn = body:match('function X%.lion_IsFieldImpaleEngagementOk%(%)(.-)\nend')
    assert(fn ~= nil, 'X.lion_IsFieldImpaleEngagementOk is gone.')
    assert(fn:find("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%( '" .. CAND .. "' %)"),
        'the helper is no longer gated on IsModeTurbo() and IsSoakCandidate(' .. CAND .. ').')
    local nIds = 0
    for _ in fn:gmatch('IsSoakCandidate%(') do nIds = nIds + 1 end
    assert(nIds == 1,
        'the helper names ' .. nIds .. ' soak ids. A gate that conjoins a second id '
        .. 'freezes FALSE the day that id is promoted (the pullcad trap, AGENTS.md).')
    assert(fn:find('\n\treturn true\n'),
        'the helper no longer falls through to a literal `true`; gate-off equivalence '
        .. 'is supposed to be structural here, not argued.')
end

tests['§2.2 the call site adds exactly one conjunct and edits no shipped term'] = function()
    local body = read_file(SRC)
    local blk = body:match('\t%-%-常规\n(.-)\n\tthen')
    assert(blk ~= nil, 'the 常规 branch no longer opens the way this file parses it.')
    assert(blk:find('#hEnemyList > 0 or bot:WasRecentlyDamagedByAnyHero%( 3%.0 %)'),
        'the shipped first line changed. This lever deliberately leaves it byte for '
        .. 'byte: the defect is that it can never be false, and DELETING it would be a '
        .. 'different change with a different reader set.')
    assert(blk:find('and X%.lion_IsFieldImpaleEngagementOk%(%)'),
        'the call site no longer calls the helper.')
    assert(blk:find('and #nInRangeEnemyList >= 1') and blk:find('and nLV >= 15'),
        'the two conjuncts §1 and §3 reason about are gone from the branch.')
end

tests['§2.3 gate off, the helper answers true on every live-Lion frame'] = function()
    local n = 0
    for _, path in ipairs(corpus_paths()) do
        if has_live_lion(path) then
            local _, _, X = frame(path, {})
            assert(X.lion_IsFieldImpaleEngagementOk() == true,
                'gate off, the helper answered false on ' .. path)
            n = n + 1
        end
    end
    assert(n >= 30, ('only %d live-Lion frames were reached; the corpus enumerator is '
        .. 'probably broken (an empty enumerator and an empty corpus are the same '
        .. 'integer).'):format(n))
end

-- ---------------------------------------------------------------- section 3 --
-- The domain, driven.  This is the section that says the lever is inert on this
-- corpus -- and says WHICH clause makes it inert, so the next round knows what
-- to cut a frame at.

tests['§3.1 the funnel: 38 live Lions, 4 at level >= 15, 0 in the branch'] = function()
    local nLion, nLv15, nDomain = 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        if has_live_lion(path) then
            nLion = nLion + 1
            local J, bot = frame(path, {})
            local bLv = bot:GetLevel() >= 15
            if bLv then nLv15 = nLv15 + 1 end
            local hQ = bot:GetAbilityByName(IMPALE)
            local bCastable = hQ ~= nil and hQ:GetLevel() > 0 and hQ:IsFullyCastable()
            local nRing = (hQ ~= nil) and (hQ:GetCastRange() + 20) or 0
            local tRing = J.GetNearbyHeroes(bot, nRing, true, BOT_MODE_NONE) or {}
            if bLv and bCastable and #tRing >= 1 then nDomain = nDomain + 1 end
        end
    end
    assert(nLion == 38, ('live-Lion instants moved %d -> %d. That is a corpus change, '
        .. 'not a bug: re-take the funnel below and the header, in this round.')
            :format(38, nLion))
    assert(nLv15 == 4, ('live-Lion instants at hero level >= 15 moved 4 -> %d.'):format(nLv15))
    assert(nDomain == 0,
        ('the 常规 branch now has %d frame(s) in domain. THIS IS GOOD NEWS and it '
         .. 'retires §3.2: stop asserting a no-op, pin the frame, and report what the '
         .. 'armed leg does with it.'):format(nDomain))
end

tests['§3.2 armed changes nothing this corpus can see'] = function()
    local n = 0
    for _, path in ipairs(corpus_paths()) do
        if has_live_lion(path) then
            local sShipped = drive(path, {})
            local sArmed   = drive(path, { [CAND] = true })
            assert(sShipped == sArmed,
                ('%s: armed changed the dispatch (%s -> %s). The domain census in §3.1 '
                 .. 'says that is impossible, so one of the two is wrong -- read the '
                 .. 'frame before editing either.'):format(path, sShipped, sArmed))
            n = n + 1
        end
    end
    assert(n == 38, ('drove %d frames, expected 38.'):format(n))
end

tests['§3.3 the binding clause is nLV >= 15, not the other two'] = function()
    -- Which clause is the marginal veto?  Count the instants each clause alone
    -- rejects.  This is what tells the next round where to cut.
    local nOnlyLevel, nOnlyCastable, nOnlyRing = 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        if has_live_lion(path) then
            local J, bot = frame(path, {})
            local hQ = bot:GetAbilityByName(IMPALE)
            local bLv = bot:GetLevel() >= 15
            local bCastable = hQ ~= nil and hQ:GetLevel() > 0 and hQ:IsFullyCastable()
            local nRing = (hQ ~= nil) and (hQ:GetCastRange() + 20) or 0
            local bRing = #(J.GetNearbyHeroes(bot, nRing, true, BOT_MODE_NONE) or {}) >= 1
            if not bLv and bCastable and bRing then nOnlyLevel = nOnlyLevel + 1 end
            if bLv and not bCastable and bRing then nOnlyCastable = nOnlyCastable + 1 end
            if bLv and bCastable and not bRing then nOnlyRing = nOnlyRing + 1 end
        end
    end
    assert(nOnlyLevel > 0,
        'no instant is rejected by the level clause ALONE any more. The claim "nLV >= 15 '
        .. 'is what keeps this branch out of the corpus" was measured, not assumed; '
        .. 're-measure it.')
    assert(nOnlyLevel >= nOnlyCastable and nOnlyLevel >= nOnlyRing,
        ('the marginal veto moved: level %d, castable %d, ring %d. The header and the '
         .. 'reverse-lookup instruction both name the level clause.')
            :format(nOnlyLevel, nOnlyCastable, nOnlyRing))
end

-- ---------------------------------------------------------------- section 4 --
-- GATE PLUMBING, and this file calls it that.  It shows the armed predicate
-- reads the window it claims to read, on two REAL frames that differ in the
-- answer.  It is NOT local validation: neither frame reaches the branch (§3.1),
-- so nothing here says the lever changes a decision.

tests['§4 the armed predicate tracks the 3.0s damage window on real frames'] = function()
    local HIT  = 'tests/frames/f_260905_004847_lion_drain_bkb.lua'
    local CALM = 'tests/fixtures/f_260819_182323_lion_drain_calm.lua'

    local _, botHit, XHit = frame(HIT, { [CAND] = true })
    assert(botHit:WasRecentlyDamagedByAnyHero(3.0) == true,
        HIT .. ' no longer carries damage inside 3.0s; §4 needs a frame that does.')
    assert(XHit.lion_IsFieldImpaleEngagementOk() == true,
        'armed, the helper refused a frame where Lion WAS hit inside the window.')

    local _, botCalm, XCalm = frame(CALM, { [CAND] = true })
    assert(botCalm:WasRecentlyDamagedByAnyHero(3.0) == false,
        CALM .. ' now carries damage inside 3.0s; §4 needs a frame that does not.')
    assert(XCalm.lion_IsFieldImpaleEngagementOk() == false,
        'armed, the helper accepted a frame where Lion was NOT hit inside the window -- '
        .. 'the whole lever is that conjunct.')

    -- The window is the branch's own 3.0, not a number this lever invented.
    local body = read_file(SRC)
    assert(body:find('X%.nQFieldDamageWindow = 3%.0'),
        'X.nQFieldDamageWindow is no longer 3.0.')
    assert(body:find('bot:WasRecentlyDamagedByAnyHero%( 3%.0 %)'),
        'the shipped 3.0 the armed window is copied FROM is gone from the branch; if the '
        .. 'branch stops carrying it, this id stops being "the term already written here".')
end

return tests
