-- [tpclaim] The team's single-responder claim for the stock defend TP was
-- burned by ASKING, not by GOING.
--
-- TeamBrain phase 1 put one arbitrator in front of the stock defend TP
-- (J.ShouldAllowDefendTp) and gave it a per-spot claim: one event = one
-- answer, 12s / 1600u.  The stamp lived at the bottom of the query, so every
-- bot whose query returned TRUE took the claim.  But its single caller --
-- ability_item_usage_generic, the 守塔 branch -- asks and can still refuse on
-- the very next line, and the two lines read DIFFERENT quantities:
--
--     tpLoc is assigned when   botAmount.distance > nMinTPDistance      (how
--                              far the bot is OFF that lane)
--                       or     botAmount.amount  < laneFront / 5        (how
--                              far BEHIND the lane front it is)
--     the TP is refused when   GetUnitToLocationDistance( bot, tpLoc )
--                                <= nMinTPDistance - 500                (the
--                              straight-line distance to the destination)
--
-- Off-lane distance and behind-the-front position are not straight-line
-- distance to the tower.  A bot standing in its own base while mid is under
-- siege, or one standing in another lane, clears the assignment and fails the
-- straight-line test: it never TPs -- and the claim it just took refuses the
-- four teammates who could have answered, for 12 seconds.  The arbitration
-- inverts: the single answer is handed to the one bot that will not go.
--
-- THE FIX (one variable): the query stops stamping when 'tpclaim' is armed,
-- and the caller stamps at the line that is already on its way to
-- BOT_ACTION_DESIRE_ABSOLUTE (J.NoteDefendTpClaim).  Asking is not answering.
--
-- WHAT THIS FILE CAN AND CANNOT ASSERT (charter backlog item 8 -- the
-- 'final-bid reachability' audit of `teambrain`, recorded here because this
-- round is where it was actually run):
--   * CAN: the arbitration itself, on real frames, through the real helper --
--     that is the whole of the behavior change, and both directions of the
--     gate are pinned below.
--   * CANNOT: the FINAL item desire.  The only caller sits behind
--     J.IsDefending -> bot:GetActiveMode(), the THIRTEENTH world assertion
--     (tests/test_activemode_world_assertion.lua): constant 0 on every hero on
--     every frame, so the 守塔 branch is structurally unreachable in the
--     corpus, and so is its destination (X.GetDefendTPLocation is
--     GetLaneFrontLocation, GH #61-refused).  Faking either would be writing
--     the harness's answer, not the game's.  The call-site half is therefore
--     asserted STRUCTURALLY below -- on the stripped source, never on comment
--     text (the lesson this stream has now collected three times: a text
--     judge that reads comments reads its own header back as code).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- `armed` is the set of soak ids that answer true for this world.
local function loaded(fixture, armed)
    local J, bot, heroes, fx = rf.load(fixture)
    local set = {}
    for _, id in ipairs(armed or {}) do set[id] = true end
    J.IsSoakCandidate = function(id) return set[id] == true end
    return J, bot, heroes, fx
end

-- Two REAL heroes off the fixture, on the same team, with the real player ids
-- the .dem carried (the claim is per-player, so distinct ids are load-bearing).
-- MEASURED, and the reason the fixture below is the one it is: only 41 of the
-- 101 fixtures carry real player ids at all -- on the other 60 every hero
-- reads the mock's default 0 (tests/mock/bot_api.lua), which would make a
-- per-player claim test silently vacuous. The setup assert is what caught it.
local function two_mates(bot, heroes)
    local names = {}
    for name in pairs(heroes) do names[#names + 1] = name end
    table.sort(names) -- deterministic pick; pairs() order is not stable
    local a, b
    for _, name in ipairs(names) do
        local h = heroes[name]
        if h:GetTeam() == bot:GetTeam() and h:IsAlive() then
            if a == nil then a = h elseif b == nil and h ~= a then b = h end
        end
    end
    assert(a ~= nil and b ~= nil, 'setup: need two living allies on the frame')
    assert(a:GetPlayerID() ~= b:GetPlayerID(),
        'setup: the fixture must carry distinct player ids -- ' ..
        'a shared id would make every assertion below vacuous')
    return a, b
end

-- A spot with nobody near it, so the headcount / defeat-memory legs cannot be
-- the thing doing the refusing in the claim tests.
local QUIET = { x = -900, y = -900, z = 0 }

tests['[the defect, pinned] teambrain alone: asking burns the claim'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
        { 'teambrain' })
    local a, b = two_mates(bot, heroes)
    DotaTime = function() return fx.time end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(a, QUIET) == true, 'first ask is allowed')
    DotaTime = function() return fx.time + 1 end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(b, QUIET) == false,
        'THIS is the defect: the first bot only ASKED -- it may well have ' ..
        'failed the straight-line test on the next line and never TPd -- ' ..
        'yet the event is now closed to its teammate for 12s')
end

tests['[the fix] tpclaim armed: asking leaves the event answerable'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
        { 'teambrain', 'tpclaim' })
    local a, b = two_mates(bot, heroes)
    DotaTime = function() return fx.time end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(a, QUIET) == true, 'first ask is allowed')
    DotaTime = function() return fx.time + 1 end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(b, QUIET) == true,
        'nobody committed, so nobody answered -- the second bot must still ' ..
        'be allowed to be the single responder')
end

tests['[the guard survives] a COMMITTED answer still refuses the second TP'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
        { 'teambrain', 'tpclaim' })
    local a, b = two_mates(bot, heroes)
    DotaTime = function() return fx.time end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(a, QUIET) == true)
    -- What the caller does on the path to BOT_ACTION_DESIRE_ABSOLUTE:
    J.NoteDefendTpClaim(a, QUIET)
    assert(J.ShouldAllowDefendTp(b, QUIET) == false,
        'the 343.2s dossier case -- THREE same-frame TPs for one diving Axe ' ..
        '-- is exactly what the claim exists to stop, and the fix must not ' ..
        'weaken it: same frame, answer already in the air, refuse')
end

tests['[window unchanged] the committed claim expires at 12s, not sooner'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
        { 'teambrain', 'tpclaim' })
    local a, b = two_mates(bot, heroes)
    DotaTime = function() return fx.time end -- luacheck: ignore
    J.NoteDefendTpClaim(a, QUIET)
    DotaTime = function() return fx.time + 11.9 end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(b, QUIET) == false, 'inside the 12s window')
    DotaTime = function() return fx.time + 12.1 end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(b, QUIET) == true, 'the window is 12s and the fix does not move it')
end

tests['[radius unchanged] the committed claim is 1600u wide, not global'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
        { 'teambrain', 'tpclaim' })
    local a, b = two_mates(bot, heroes)
    DotaTime = function() return fx.time end -- luacheck: ignore
    J.NoteDefendTpClaim(a, QUIET)
    local near = { x = QUIET.x + 1500, y = QUIET.y, z = 0 }
    local far  = { x = QUIET.x + 1700, y = QUIET.y, z = 0 }
    assert(J.ShouldAllowDefendTp(b, near) == false, 'same event (1500 < 1600)')
    assert(J.ShouldAllowDefendTp(b, far) == true, 'a different event 1700u away is not claimed')
end

tests['[off-candidate equivalence] the caller-side stamp is a no-op when tpclaim is off'] = function()
    -- The call site calls J.NoteDefendTpClaim unconditionally. Off the
    -- candidate the query already stamped, in the same frame, for the same
    -- bot and spot -- so the extra call must leave the world byte-identical.
    local function verdict(with_caller_stamp)
        local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
            { 'teambrain' })
        local a, b = two_mates(bot, heroes)
        DotaTime = function() return fx.time end -- luacheck: ignore
        local first = J.ShouldAllowDefendTp(a, QUIET)
        if with_caller_stamp then J.NoteDefendTpClaim(a, QUIET) end
        DotaTime = function() return fx.time + 1 end -- luacheck: ignore
        return first, J.ShouldAllowDefendTp(b, QUIET)
    end
    local f1, s1 = verdict(false)
    local f2, s2 = verdict(true)
    assert(f1 == f2 and s1 == s2,
        'off the candidate the new call site must not change any verdict')
end

tests['[transparency] teambrain off -> the arbitrator is permissive either way'] = function()
    for _, armed in ipairs({ {}, { 'tpclaim' } }) do
        local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua', armed)
        local a, b = two_mates(bot, heroes)
        DotaTime = function() return fx.time end -- luacheck: ignore
        assert(J.ShouldAllowDefendTp(a, QUIET) == true)
        J.NoteDefendTpClaim(a, QUIET)
        assert(J.ShouldAllowDefendTp(b, QUIET) == true,
            'with teambrain off the whole arbitrator is a no-op -- arming ' ..
            'tpclaim alone must not switch any of it on')
    end
end

tests['[non-turbo] the claim is turbo-only, in both directions'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
        { 'teambrain', 'tpclaim' })
    local a, b = two_mates(bot, heroes)
    J.IsModeTurbo = function() return false end
    DotaTime = function() return fx.time end -- luacheck: ignore
    J.NoteDefendTpClaim(a, QUIET)
    assert(J.ShouldAllowDefendTp(b, QUIET) == true,
        'outside turbo the arbitrator returns before reading the claim at all')
end

tests['[untouched legs] the 1v3 destination is still refused with tpclaim armed'] = function()
    -- The real-frame regression guard for the fix: moving the stamp must not
    -- disturb the three refusals that sit ABOVE it. This is the ES frame from
    -- the wave12 dossier (cast into 1 ally vs 3 enemies, landed, dead in 5.8s).
    local J, bot, heroes = loaded('tests/fixtures/f_050713_es_defend_1v3.lua',
        { 'teambrain', 'tpclaim' })
    local dp = heroes['npc_dota_hero_death_prophet']
    local v = dp:GetLocation()
    local atk = { npc_dota_hero_obsidian_destroyer = 1096,
                  npc_dota_hero_lina = 1116, npc_dota_hero_lion = 1272 }
    for name, d in pairs(atk) do
        local sp = rawget(heroes[name], '__spec')
        sp.GetLocation = { x = v.x + d, y = v.y, z = 0 }
        rawset(heroes[name], 'GetLocation', nil)
    end
    assert(J.ShouldAllowDefendTp(bot, v) == false,
        'headcount still bites -- and a refused ask never reaches the stamp')
end

-- ---------------------------------------------------------------------------
-- The call-site half, asserted on STRIPPED source (comments removed first --
-- this file`s own prose quotes every identifier it looks for, and so does the
-- fix`s header comment; a naive text judge would read them back as code).
-- ---------------------------------------------------------------------------

local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

local function read(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

local function lua_files_under(dir)
    local p = assert(io.popen('find ' .. dir .. ' -name "*.lua" | sort'))
    local files = {}
    for f in p:lines() do files[#files + 1] = f end
    p:close()
    assert(#files > 0, 'setup: found no lua files under ' .. dir)
    return files
end

tests['[no leak] J.NoteDefendTpClaim has exactly the two call sites the fix needs'] = function()
    -- One inside jmz_func (the OFF-candidate legacy stamp, still at the bottom
    -- of the query) and one at the caller (the ON-candidate stamp). A third
    -- would publish the claim outside the gated defend TP.
    local sites = {}
    for _, f in ipairs(lua_files_under('bots')) do
        local code = strip_comments(read(f))
        local n = 0
        for _ in code:gmatch('J%.NoteDefendTpClaim%s*%(') do n = n + 1 end
        for _ in code:gmatch('function%s+J%.NoteDefendTpClaim%s*%(') do n = n - 1 end
        if n > 0 then sites[f] = n end
    end
    local seen = 0
    for f, n in pairs(sites) do
        seen = seen + n
        assert(f:match('jmz_func%.lua$') or f:match('ability_item_usage_generic%.lua$'),
            'unexpected claim site in ' .. f)
    end
    assert(sites['bots/FunLib/jmz_func.lua'] == 1,
        'the off-candidate stamp inside the query is the shipped path -- ' ..
        'removing it would publish the fix ungated')
    assert(sites['bots/ability_item_usage_generic.lua'] == 1,
        'the caller-side stamp is the fix')
    assert(seen == 2, 'exactly two call sites, got ' .. seen)
end

tests['[call-site order] the stamp is past the refusal and before the ABSOLUTE'] = function()
    local code = strip_comments(read('bots/ability_item_usage_generic.lua'))
    -- The 守塔 block: from its ShouldAllowDefendTp ask to the next branch.
    local ask = code:find('J%.ShouldAllowDefendTp%s*%(', 1)
    assert(ask, 'the defend-TP arbitration ask is gone from the caller')
    local stop = code:find('J%.IsPushing%s*%(', ask) or #code
    local block = code:sub(ask, stop)

    local refuse = block:find('GetUnitToLocationDistance%s*%(%s*bot%s*,%s*tpLoc%s*%)')
    local stamp = block:find('J%.NoteDefendTpClaim%s*%(')
    local absolute = block:find('return%s+BOT_ACTION_DESIRE_ABSOLUTE')
    assert(refuse, 'the straight-line refusal that motivates tpclaim is gone')
    assert(stamp, 'the defend TP no longer takes the claim at all')
    assert(absolute, 'the 守塔 branch no longer returns ABSOLUTE')
    assert(refuse < stamp,
        'the claim must be taken AFTER the straight-line test -- taking it ' ..
        'before is the whole defect')
    assert(stamp < absolute, 'and before the action is returned')
end

tests['[the premise] the ask and the refusal read different quantities'] = function()
    -- Why an allowed ask can still end in no TP. If these two ever become the
    -- same measurement the defect dissolves and this candidate should be
    -- dropped rather than promoted.
    local code = strip_comments(read('bots/ability_item_usage_generic.lua'))
    local ask = assert(code:find('J%.ShouldAllowDefendTp%s*%('))
    local head = code:sub(1, ask)
    local assign = head:match('.*()tpLoc%s*=%s*X%.GetDefendTPLocation')
    assert(assign, 'the defend TP destination is no longer assigned from X.GetDefendTPLocation')
    local cond = head:sub(assign - 400, assign)
    assert(cond:find('botAmount%.distance'), 'assignment leg 1 (off-lane distance) is gone')
    assert(cond:find('botAmount%.amount'), 'assignment leg 2 (behind the lane front) is gone')
    assert(not cond:find('GetUnitToLocationDistance'),
        'if the assignment started measuring straight-line distance too, the ' ..
        'ask and the refusal would agree and tpclaim would be pointless')
end

return tests
