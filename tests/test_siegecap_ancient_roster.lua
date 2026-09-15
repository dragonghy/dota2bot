-- [ratchet] [strategy 2026-09-15] Soak candidate 'siegecap': a question about
-- the enemy TEAM, answered from the first THREE roster slots.
--
-- THE DEFECT (shipped default, bots/mode_farm_generic.lua X.IsUnitAroundLocation)
-- ---------------------------------------------------------------------------
--     for i, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
--         if IsHeroAlive(id) and i <= 3 then
--
-- Its one caller is the base-siege farm veto at the top of GetDesireHelper:
--
--     if X.IsUnitAroundLocation(GetAncient(GetTeam()):GetLocation(), 3000)
--     then return BOT_MODE_DESIRE_NONE; end
--
-- "Is any enemy at our ancient" is existential over five players; `i <= 3`
-- asks three of them. Slots 4 and 5 may stand on the ancient at any distance,
-- at any freshness, and the alarm is FALSE -- not rarely, BY CONSTRUCTION.
--
-- THE ANSWER IS ALREADY SHIPPED, in this same repo, under this same name:
-- bots/mode_rune_generic.lua:676 is the same function with the same body and NO
-- cap. jmz_func.lua:9292 names the asymmetry in prose and has done nothing else
-- about it. Armed, the farm copy IS the rune copy, term for term -- so this
-- lever invents no policy and no constant.
--
-- ⛔ WHAT THIS FILE CAN AND CANNOT BUY -- read before quoting any number below
-- ---------------------------------------------------------------------------
-- THE CALLER'S OWN INSTANT IS NOT IN THE CORPUS, and that is measured here
-- rather than assumed: over the 636 live subject frames that carry an ancient,
-- the closest any enemy ever comes to its opponents' ancient is 4440u against
-- this call's 3000u ring -- ZERO frames in the domain. So no fixture in this
-- repo can show the alarm FLIP, and this file does not pretend one does. What
-- it pins instead, all of it on real frames and real geometry:
--
--   * §3 ⭐ the lever IS wired and IS live at the shipped call site, observed on
--     three real frames through the real GetDesire(): the shipped walk asks the
--     engine about 3 enemy ids, the armed walk about 5. The alarm's ANSWER
--     cannot move here, but the QUESTION can, and the question is the thing the
--     cap truncates. The same section also shows the lever is INERT -- no farm
--     bid moves on any frame this repo owns;
--   * §4 the blindness itself, priced on real positions: the enemy nearest our
--     own ancient sits in roster slot 4 or 5 on 207/636 frames (32.5%), and at
--     a 6000u ring 15 of the 39 frames with an enemy inside are invisible to
--     the capped form;
--   * §5 a TRIPWIRE that goes red the day a frame lands inside 3000u -- the day
--     the flip can and must be pinned properly (GH #837, queue strategy-47).
--
-- ⛔ AND THE ZERO IS THE OTHER KIND. GH #831's zero was CONSTRUCTIVE: heroes
-- that the soak drafter can never pick, so the domain is empty in every wave
-- that will ever run. This zero is CORPUS COVERAGE: the corpus spans t in
-- [35, 850]s and nobody sieges a base at 14 minutes. The branch is reachable by
-- every drafted hero in every game that lasts, so "domain zero, do not land" is
-- NOT the disposition here.
--
-- ⚠️ ROSTER ORDER IS THE HARNESS'S, NOT THE ENGINE'S. replay_fixture answers
-- GetTeamPlayers(enemy) with ALIVE enemies in fixture order (pid-sorted only
-- where the fixture carries player_id). In game the list is all five ids in
-- player-slot order, dead included -- which makes the cap STRICTLY worse than
-- anything measured here, because dead slots 1-3 consume the whole quota. Every
-- §4 number is therefore a LOWER bound on the blindness, and §4 sorts by
-- player_id wherever the fixture carries it so the ordering is the real one on
-- the frames that can supply it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local SRC     = 'bots/mode_farm_generic.lua'
local SIBLING = 'bots/mode_rune_generic.lua'
local RING    = 3000                          -- the caller's own ring

ss.assert_clean('file load, tests/test_siegecap_ancient_roster.lua')

local tests = {}

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

local function fn_body(path, name)
    local src = strip_comments(read(path))
    local body = src:match('function ' .. name .. '%b()(.-)\nend')
    assert(body, name .. ' is gone from ' .. path)
    return body
end

-- ==========================================================================
-- §1 THE SITE. The defect, the single call site, and the sibling that already
-- ships the armed form. Source-level, because they hold for every frame.
-- ==========================================================================

tests['[site] the shipped cap is still spelled the way this file describes it']
= function()
    local body = fn_body(SRC, 'X%.IsUnitAroundLocation')
    assert(body:find('i <= 3'), 'the `i <= 3` cap is gone from '
        .. 'X.IsUnitAroundLocation. If it was removed outright the lever is '
        .. 'moot and this file retires; if it was renamed, re-pin it here.')
    assert(body:find('for i, id in pairs%(GetTeamPlayers%(GetOpposingTeam%(%)%)%)'),
        'the loop no longer walks the enemy roster by index; the whole reading '
        .. 'below rests on `i` being a ROSTER SLOT')
    -- The three clauses the lever does NOT touch, verbatim. A future edit that
    -- "helps" siegecap by loosening one of these stops this file describing
    -- what shipped -- the M3/M6 lesson of the runecamp round: a token that no
    -- behavioural leg can see is only ever caught by a verbatim pin.
    for _, clause in ipairs({
        'IsHeroAlive%(id%)',
        'J%.GetDistance%(vLoc, dInfo%.location%) <= nRadius',
        'dInfo%.time_since_seen < 1%.0',
    }) do
        assert(body:find(clause), 'a clause the lever is not supposed to touch '
            .. 'changed. Missing: ' .. clause)
    end
end

tests['[site] ⭐ exactly one caller, and it is the ancient alarm at 3000u']
= function()
    local src = strip_comments(read(SRC))
    local n = 0
    for _ in src:gmatch('X%.IsUnitAroundLocation%s*%(') do n = n + 1 end
    assert(n == 2, 'X.IsUnitAroundLocation appears ' .. n .. ' times in ' .. SRC
        .. ' (definition + callers), not 2. A second caller means this lever '
        .. 'moves a decision this file has never read.')
    assert(src:find('X%.IsUnitAroundLocation%(GetAncient%(GetTeam%(%)%)'
        .. ':GetLocation%(%), 3000%)'),
        'the one call site is no longer `GetAncient(GetTeam()):GetLocation(), '
        .. '3000` -- every domain number in §4 is priced against that ring')
    assert(src:find('return BOT_MODE_DESIRE_NONE'),
        'the alarm no longer returns BOT_MODE_DESIRE_NONE; the direction claim '
        .. '("arming can only ADD farm refusals") rests on that')
end

tests['[site] ⭐⭐ the armed form is the sibling that already ships uncapped']
= function()
    local sib = fn_body(SIBLING, 'X%.IsUnitAroundLocation')
    assert(not sib:find('i <= 3'), SIBLING .. ' grew an `i <= 3` cap too. The '
        .. 'whole "no policy is invented, the tree already answers this" claim '
        .. 'in the header of ' .. SRC .. ' rests on that copy being uncapped.')
    assert(sib:find('for _, id in pairs%(GetTeamPlayers%(GetOpposingTeam%(%)%)%)'),
        SIBLING .. ' no longer walks the whole enemy roster')
    -- And the prose that has been carrying this finding instead of code.
    assert(read('bots/FunLib/jmz_func.lua')
        :find("mode_farm_generic's own X.IsUnitAroundLocation", 1, true),
        'jmz_func.lua no longer names this asymmetry. It was the only place it '
        .. 'was written down before this lever existed; if it moved, follow it.')
end

-- ==========================================================================
-- §2 THE GATE. Shape, not behaviour.
-- ==========================================================================

tests['[gate] the lever is turbo-only'] = function()
    assert(fn_body(SRC, 'X%.IsUnitAroundLocation')
        :find('J%.IsModeTurbo%s*%(%s*%)'),
        'the siegecap gate lost its J.IsModeTurbo() conjunct')
end

tests['[gate] the gate names exactly one soak id -- its own (pullcad trap)']
= function()
    local body = fn_body(SRC, 'X%.IsUnitAroundLocation')
    local ids = {}
    for id in body:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1, 'the siegecap gate names ' .. #ids .. ' soak ids ('
        .. table.concat(ids, ' ') .. '). A gate conditioned on a SECOND id is '
        .. 'frozen FALSE the day that id is promoted -- a promoted id appears '
        .. 'in no armed string -- and check_armed_wiring.py still calls it '
        .. 'WIRED.')
    assert(ids[1] == 'siegecap', 'the gate names ' .. ids[1])
end

tests['[gate] ⭐ unarmed the conjunct is the shipped one, not a rewrite']
= function()
    local body = fn_body(SRC, 'X%.IsUnitAroundLocation')
    assert(body:find('if IsHeroAlive%(id%) and %(bWholeRoster or i <= 3%) then'),
        'the armed form is no longer `bWholeRoster or i <= 3`. Any other shape '
        .. 'has to be re-argued: this one is `false or i <= 3` when the gate is '
        .. 'shut, i.e. the shipped conjunct itself, and a strict SUPERSET when '
        .. 'it is open because slots 1-3 are still evaluated first.')
    assert(body:find('local bWholeRoster = J%.IsModeTurbo%(%) and '
        .. 'J%.IsSoakCandidate%('),
        'the gate moved out of a single hoisted local; a per-iteration read '
        .. 'would ask the switch once per roster slot')
end

-- ==========================================================================
-- §3 DRIVEN, on real frames: the lever is INERT everywhere this corpus reaches.
-- This is the honest real-frame reading available today -- see the header.
-- ==========================================================================

--- Every fixture that carries an ancient, with one real subject each.
local function bearing_frames(nMax)
    local p = assert(io.popen('ls tests/fixtures'))
    local out = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then
            local path = 'tests/fixtures/' .. f
            local ok, fx = pcall(dofile, path)
            if ok and type(fx) == 'table' and fx.units and fx.self then
                local hasAncient = false
                for _, b in ipairs(fx.buildings or {}) do
                    if b.name == 'ancient' and b.alive then hasAncient = true end
                end
                if hasAncient then
                    out[#out + 1] = { path = path, subj = fx.self }
                end
            end
        end
        if nMax and #out >= nMax then break end
    end
    p:close()
    table.sort(out, function(a, b) return a.path < b.path end)
    return out
end

local function side_of(path, subj)
    local _, bot = rf.load(path, subj)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

--- Drive the REAL GetDesire() of the real mode script on a real frame and count
--- how many DISTINCT enemy ids the roster walk asked the engine about.
---
--- ⭐ This is the probe that makes the lever observable at all. The alarm's own
--- ANSWER cannot move on this corpus (§5: nothing is inside 3000u), but the
--- QUESTION it asks can, and it is the question the cap truncates: shipped code
--- asks GetHeroLastSeenInfo for at most three roster slots, armed code asks for
--- every one. Nothing is stubbed -- GetHeroLastSeenInfo is the loader's own fog
--- model, wrapped only to record the ids it was handed.
---
--- `ping` is passed through to rf.declare_defend_ping and is LOAD-BEARING: see
--- the case below that leaves it 'fresh'.
local function roster_asks(path, subj, ping)
    local J = rf.load(path, subj)
    rf.declare_defend_ping(J, ping or 'stale')
    local raw = GetHeroLastSeenInfo
    local seen, n = {}, 0
    _G.GetHeroLastSeenInfo = function(id)                    -- luacheck: ignore
        if not seen[id] then seen[id] = true; n = n + 1 end
        return raw(id)
    end
    dofile(SRC)
    local ok, d = pcall(GetDesire)
    _G.GetHeroLastSeenInfo = raw                             -- luacheck: ignore
    return n, (ok and d or nil)
end

--- The three real frames on which the shipped walk stops at three and the armed
--- walk does not. (On the other reaching frames some earlier uncapped reader has
--- already asked every id, so the two legs agree -- §3's census counts them.)
local BEARING = {
    { path = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
      subj = 'npc_dota_hero_obsidian_destroyer' },
    { path = 'tests/fixtures/f_260820_163429_es_blink_init_621.lua',
      subj = 'npc_dota_hero_earthshaker' },
    { path = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
      subj = 'npc_dota_hero_lion' },
}

tests['[driven] ⭐⭐ on a real frame the shipped walk stops at three, armed asks five']
= function()
    for _, fr in ipairs(BEARING) do
        local nU = roster_asks(fr.path, fr.subj)
        assert(nU == 3, fr.path .. ': the shipped walk asked ' .. nU
            .. ' enemy ids, not 3. If it asked more, some other reader now runs '
            .. 'before the alarm and this frame no longer isolates the cap.')
        local nA
        ss.with_candidate('siegecap', function()
            nA = roster_asks(fr.path, fr.subj)
        end, side_of(fr.path, fr.subj))
        assert(nA == 5, fr.path .. ': the ARMED walk asked ' .. tostring(nA)
            .. ' enemy ids, not 5 -- the lever is not reaching the shipped call '
            .. 'site, whatever check_armed_wiring.py says about it')
    end
end

tests['[driven] ⭐ and the probe is not measuring itself: fresh ping, no walk']
= function()
    -- GH #91: GetDesireHelper's first statement lazily initialises
    -- J.Utils.GameStates.defendPings FROM the clock it then compares against,
    -- so in a one-call VM `GameTime() - pingedTime` is 0 and the function
    -- returns NONE before anything else runs. Every case above declares the
    -- ping 'stale' for exactly that reason; leave it 'fresh' and the walk that
    -- reports 3 and 5 reports 0 instead.
    for _, fr in ipairs(BEARING) do
        local n, d = roster_asks(fr.path, fr.subj, 'fresh')
        assert(n == 0, fr.path .. ': with a FRESH defend ping the walk still '
            .. 'asked ' .. n .. ' ids, so the 3-vs-5 reading above is not '
            .. 'coming from the path this file thinks it is')
        assert(d == BOT_MODE_DESIRE_NONE, fr.path .. ': a fresh ping no longer '
            .. 'short-circuits GetDesireHelper (' .. tostring(d) .. ')')
    end
end

tests['[driven] ⭐ the census: how many corpus frames the cap actually truncates']
= function()
    local frames = bearing_frames()
    assert(#frames >= 60, 'only ' .. #frames .. ' fixtures carry a live '
        .. 'ancient; a short walk makes the census cheap')
    local nWalked, nTrunc, nMovedDesire = 0, 0, 0
    for _, fr in ipairs(frames) do
        local okU, nU, dU = pcall(roster_asks, fr.path, fr.subj)
        if okU then
            nWalked = nWalked + 1
            local nA, dA
            ss.with_candidate('siegecap', function()
                local ok2, a, b = pcall(roster_asks, fr.path, fr.subj)
                if ok2 then nA, dA = a, b end
            end, side_of(fr.path, fr.subj))
            if nA ~= nil and nA ~= nU then nTrunc = nTrunc + 1 end
            if dA ~= dU then nMovedDesire = nMovedDesire + 1 end
        end
    end
    assert(nWalked >= 60, 'only ' .. nWalked .. ' frames drove GetDesire() '
        .. 'without raising')
    assert(nTrunc == 3, 'the armed walk asks more ids than the shipped one on '
        .. nTrunc .. ' corpus frames, not 3 -- re-price the report')
    -- ⛔ The decision itself does NOT move, and that is the honest half: §5
    -- shows nothing in this corpus stands inside the alarm's 3000u ring, so a
    -- wider roster finds nobody either. The lever is INERT on every frame this
    -- repo owns.
    assert(nMovedDesire == 0, 'siegecap moved a farm bid on ' .. nMovedDesire
        .. ' corpus frames. THAT IS NOT A FAILURE -- it is the frame this file '
        .. 'says the corpus does not have. Pin it and delete the §5 tripwire.')
end

-- ==========================================================================
-- §4 THE DOMAIN. What the cap is worth, on real positions.
--
-- ⭐ Every counter below is called a SECOND time with its leg swapped, because
-- a walk that loaded nothing, a roster that admitted nobody and a ring that let
-- no one in all report the same number -- and this section is built on those
-- numbers (0NEXT20 criterion 未).
-- ==========================================================================

local memo = {}

--- One walk, all of it real: for every live subject that has a live ancient,
--- the sorted enemy roster and each enemy's distance to THAT subject's ancient.
local function corpus()
    if memo.done then return memo end
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    memo.fixtures, memo.frames, memo.pidFrames = 0, {}, 0
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            memo.fixtures = memo.fixtures + 1
            local anc = {}
            for _, b in ipairs(fx.buildings or {}) do
                if b.name == 'ancient' and b.alive then
                    anc[b.team] = { x = b.x, y = b.y }
                end
            end
            local live = {}
            for _, u in ipairs(fx.units) do
                if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                    live[#live + 1] = u
                end
            end
            for _, subj in ipairs(live) do
                local a = anc[subj.team]
                if a ~= nil then
                    local roster, allPid = {}, true
                    for _, u in ipairs(live) do
                        if u.team ~= subj.team then
                            roster[#roster + 1] = u
                            if u.player_id == nil then allPid = false end
                        end
                    end
                    if allPid then
                        memo.pidFrames = memo.pidFrames + 1
                        table.sort(roster, function(x, y)
                            return x.player_id < y.player_id
                        end)
                    end
                    local ds = {}
                    for i, e in ipairs(roster) do
                        ds[i] = math.sqrt((e.x - a.x) ^ 2 + (e.y - a.y) ^ 2)
                    end
                    memo.frames[#memo.frames + 1] = ds
                end
            end
        end
    end
    memo.done = true
    return memo
end

--- ONE counter, both legs. `nRing` is the alarm's radius and `nCap` the roster
--- quota (math.huge = the armed form). Returns: frames with an enemy inside the
--- ring at all, frames the quota cannot see any of them from, and the nearest
--- enemy's slot histogram.
local function alarm(nRing, nCap)
    local C = corpus()
    local nIn, nBlind, hist = 0, 0, {}
    local dMin = math.huge
    for _, ds in ipairs(C.frames) do
        local anyIn, capIn = false, false
        local best, bestI = math.huge, nil
        for i, d in ipairs(ds) do
            if d < best then best, bestI = d, i end
            if d <= nRing then
                anyIn = true
                if i <= nCap then capIn = true end
            end
        end
        if bestI then hist[bestI] = (hist[bestI] or 0) + 1 end
        if best < dMin then dMin = best end
        if anyIn then nIn = nIn + 1 end
        if anyIn and not capIn then nBlind = nBlind + 1 end
    end
    return nIn, nBlind, hist, dMin
end

tests['[domain] the walk covered the corpus it thinks it did'] = function()
    local C = corpus()
    assert(C.fixtures >= 100, 'the fixture walk loaded only ' .. C.fixtures
        .. ' files -- a short walk makes every number below cheap')
    assert(#C.frames >= 600, 'the walk found only ' .. #C.frames
        .. ' live subject frames carrying an ancient')
    assert(C.pidFrames >= 400, 'only ' .. C.pidFrames .. ' of those frames '
        .. 'carry player_id for every enemy, so only they are ordered the way '
        .. 'the engine orders them')
end

tests['[domain] ⭐⭐ a third of frames have their nearest besieger out of quota']
= function()
    local _, _, hist = alarm(RING, 3)
    local nAll, nOut = 0, 0
    for i, n in pairs(hist) do
        nAll = nAll + n
        if i >= 4 then nOut = nOut + n end
    end
    local pct = 100 * nOut / nAll
    assert(math.abs(pct - 32.5) < 3.0, string.format(
        'the enemy nearest our own ancient sits in roster slot 4 or 5 on '
        .. '%.1f%% (%d/%d) of frames, not ~32.5%% -- re-price the header of %s',
        pct, nOut, nAll, SRC))
end

tests['[domain] ⭐ and at a ring the corpus DOES reach, the cap misses 15 of 39']
= function()
    local nIn, nBlind = alarm(6000, 3)
    assert(nIn == 39, 'frames with an enemy inside 6000u of our ancient is now '
        .. nIn .. ', not 39')
    assert(nBlind == 15, 'of those, the `i <= 3` cap sees none on ' .. nBlind
        .. ' frames, not 15')
    local nIn8, nBlind8 = alarm(8000, 3)
    assert(nIn8 == 255 and nBlind8 == 54, 'the 8000u reading moved: '
        .. nIn8 .. '/' .. nBlind8 .. ', was 255/54')
end

tests['[domain] ⭐ the same counter, quota lifted, reports zero blind'] = function()
    local nIn, nBlind = alarm(6000, math.huge)
    assert(nIn == 39, 'the ring changed under the swapped leg: ' .. nIn)
    assert(nBlind == 0, 'with no quota at all the counter still reports '
        .. nBlind .. ' blind frames -- it is not measuring the quota')
    local nIn2, nBlind2 = alarm(8000, math.huge)
    assert(nIn2 == 255 and nBlind2 == 0, 'the 8000u swapped leg reports '
        .. nIn2 .. '/' .. nBlind2)
end

tests['[domain] ⭐ and with the quota shut, every occupied frame is blind']
= function()
    local nIn, nBlind = alarm(6000, 0)
    assert(nIn == 39, 'the ring changed under the shut leg: ' .. nIn)
    assert(nBlind == nIn, 'quota 0 still lets ' .. (nIn - nBlind)
        .. ' frames through; the quota is not the thing being varied')
    local nInAll, nBlindAll = alarm(math.huge, 0)
    assert(nInAll == #corpus().frames and nBlindAll == nInAll,
        'with no ring and no quota the counter reports ' .. nInAll .. '/'
        .. nBlindAll .. ', not ' .. #corpus().frames .. ' of itself')
end

-- ==========================================================================
-- §5 THE TRIPWIRE. The one thing that would let the next round pin the flip.
-- ==========================================================================

tests['[limit] ⭐⭐ no corpus frame reaches the caller\'s own 3000u ring']
= function()
    local nIn, _, _, dMin = alarm(RING, 3)
    assert(math.abs(dMin - 4440) < 5, string.format(
        'the closest any enemy comes to its opponents ancient is now %.0fu, '
        .. 'was 4440u', dMin))
    assert(nIn == 0, nIn .. ' corpus frames now carry an enemy inside ' .. RING
        .. 'u of its foes ancient. THAT IS GOOD NEWS, not a regression: the '
        .. 'flip this lever exists for became pinnable today. Build a bearing '
        .. 'fixture on one of them, assert unarmed BOT_MODE_DESIRE_NONE is '
        .. 'withheld and armed it is returned, and delete this case. See GH '
        .. '#837 / queue strategy-47.')
end

tests['[limit] the corpus clock is why, and it is asserted not assumed']
= function()
    local p = assert(io.popen('ls tests/fixtures'))
    local tMax = -math.huge
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then
            local ok, fx = pcall(dofile, 'tests/fixtures/' .. f)
            if ok and type(fx) == 'table' and type(fx.time) == 'number' then
                tMax = math.max(tMax, fx.time)
            end
        end
    end
    p:close()
    assert(tMax < 20 * 60, string.format(
        'the corpus now reaches t = %.1fs. A base siege is a late-game event; '
        .. 'past 20 minutes the "no frame reaches 3000u" reading above should '
        .. 'be re-taken rather than inherited.', tMax))
    assert(tMax > 600, 'the corpus tops out at ' .. tostring(tMax)
        .. 's -- the walk is not reading fx.time')
end

-- ==========================================================================
-- §6 CONTROLS. The two ways to get an unarmed reading by accident, and the
-- one way to get an armed reading that belongs to someone else.
-- ==========================================================================

tests['[control] with no switch on disk the gate is shut'] = function()
    ss.assert_clean('[control] no switch on disk')
    local frames = bearing_frames(3)
    local J = rf.load(frames[1].path, frames[1].subj)
    assert(J.IsSoakCandidate('siegecap') == false,
        'no switch on disk and J.IsSoakCandidate still answers true')
end

tests['[control] armed on the OTHER side the gate stays shut'] = function()
    local frames = bearing_frames(3)
    local sOther = side_of(frames[1].path, frames[1].subj) == 'radiant'
        and 'dire' or 'radiant'
    ss.with_candidate('siegecap', function()
        local J = rf.load(frames[1].path, frames[1].subj)
        assert(J.IsSoakCandidate('siegecap') == false,
            'the gate fired for a bot on the other side')
    end, sOther)
end

tests['[control] armed under another id the gate stays shut'] = function()
    local frames = bearing_frames(3)
    ss.with_candidate('campfarm', function()
        local J = rf.load(frames[1].path, frames[1].subj)
        assert(J.IsSoakCandidate('siegecap') == false,
            'the gate fired under a different candidate id')
    end, side_of(frames[1].path, frames[1].subj))
end

tests['[control] and armed under its own id on its own side, it opens']
= function()
    local frames = bearing_frames(3)
    ss.with_candidate('siegecap', function()
        local J = rf.load(frames[1].path, frames[1].subj)
        assert(J.IsSoakCandidate('siegecap') == true,
            'the gate did NOT open under its own id on its own side, so every '
            .. 'armed leg above measured the unarmed tree')
    end, side_of(frames[1].path, frames[1].subj))
end

return tests
