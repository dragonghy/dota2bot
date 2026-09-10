-- [tfnull 20260910] What J.GetTeamFightLocation hands its 35 call sites when
-- the ally centroid has no contributor -- pinned on the real frames of the
-- corpus.
--
-- ⭐ PRIOR ART, and it is not this file. The diagnosis below -- empty list ->
-- Vector(0,0) -> handed to consumers that only test `~= nil`, with the
-- 1400/1500 radius mismatch as the in-game route into it -- was already
-- written down in tests/test_activemode_world_assertion.lua ("A SHIPPED
-- READING THAT IS NOT A HARNESS ARTEFACT"), which recorded it as a candidate
-- lever and deliberately did NOT change bots/. This round takes that lever up
-- gated, and adds three things that file does not have: the consequence priced
-- at four named call sites (including one that does NOT fire), a substitute
-- anchor measured against the centroid it stands in for, and a mutation stand.
-- The precondition that file set is still the promote bar -- see section 3.
--
-- THE DEFECT (the shape the charter is scanning for: a set feeds the UPSTREAM
-- gate and then has no vote in the DOWNSTREAM free variable). The branch exists
-- because `J.GetEnemyCount(member, 1400) >= 2` -- there are enemies on this
-- member, so there is a fight. That set decides ONLY whether to answer. WHAT is
-- answered is the centroid of ATTACK-mode ALLIES near the member, and when that
-- list is empty J.GetCenterOfUnits returns Vector(0,0). The helper then hands
-- back the map ORIGIN as a measured location. Every caller checks `~= nil`;
-- none of them can tell the sentinel from a place.
--
-- WHY IT HAS NEVER BEEN SEEN: (0,0) is the middle of the Dota map -- mid lane,
-- the river, a few thousand units off both Roshan pits. It does not look wrong
-- in a replay. Section 1 measures how far it is from the fight it claims to
-- report on each frame: 844 to 8017 units.
--
-- ⛔ WHAT THIS CORPUS CANNOT DO, stated before any number below is read.
-- NO fixture carries active-mode data: `GetActiveMode()` answers the mock's
-- generic getter default, 0, and BOT_MODE_ATTACK is 1003. Section 3 MEASURES
-- that rather than citing it. Consequences, both directions:
--   * every qualifying frame in this corpus takes the empty-list path, so
--     "5 of 5" is a property of the LOADER, not a frequency. This round does
--     NOT buy how often a real game reaches the empty list; that argument is
--     structural (see the header in jmz_func.lua) and stays structural.
--   * the corpus can still price the CONSEQUENCE exactly, because the geometry
--     is real: sections 1-2 read the true distance between the fabricated
--     answer and the fight, on real frames.
-- Section 4 supplies the other half -- modes INJECTED so the list is non-empty
-- -- and that is this change's risk upper bound on real frames: byte-identical.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The five frames of tests/fixtures/ on which some team member satisfies both
-- of J.GetTeamFightLocation's predicates. `moved` is the distance from the
-- qualifying member to the answer the shipped code gives, i.e. exactly how far
-- off the fabricated location is. Every number was reproduced from the frame
-- before it was written down, and is re-derived below rather than trusted.
-- `gap` is section 4's reading: with ATTACK injected on the whole roster (the
-- only way this corpus can show a POPULATED centroid at all), how far the real
-- centroid lands from the member the fix anchors on. Compare it with `moved`.
local FRAMES = {
    { path = 'tests/fixtures/f_071859_oracle_screen.lua',
      member = 'npc_dota_hero_chaos_knight',       moved = 8017, gap = 307 },
    { path = 'tests/fixtures/f_260725_105305_wk_reincarn_gap.lua',
      member = 'npc_dota_hero_earthshaker',        moved = 6007, gap = 259 },
    { path = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua',
      member = 'npc_dota_hero_chaos_knight',       moved =  844, gap = 161 },
    { path = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
      member = 'npc_dota_hero_juggernaut',         moved = 5271, gap = 295 },
    { path = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
      member = 'npc_dota_hero_obsidian_destroyer', moved = 6471, gap =   7 },
}

local function all_fixtures()
    local out = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'),
        'could not list tests/fixtures')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    assert(#out > 100, 'expected the full fixture corpus, got ' .. #out)
    return out
end

--- The member J.GetTeamFightLocation's own loop would stop on, found with the
--- helper's own two predicates and its own order (GetTeamPlayers / GetTeamMember).
local function qualifying_member(J)
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local member = GetTeamMember(i)
        if member ~= nil and member:IsAlive()
            and J.IsInTeamFight(member, 1500)
            and J.GetEnemyCount(member, 1400) >= 2
        then
            return member, i
        end
    end
    return nil, nil
end

local function arm(J, bArmed)
    J.IsSoakCandidate = function(sId)
        return bArmed and sId == 'tfnull'
    end
end

local function is_origin(v)
    return v ~= nil and v.x == 0 and v.y == 0
end

-- ------------------------------------------------------- 1. the defect ------

tests['[tfnull] 1. the shipped answer is the map ORIGIN, not the fight'] = function()
    for _, f in ipairs(FRAMES) do
        local J = rf.load(f.path)
        arm(J, false)
        local member = qualifying_member(J)
        assert(member ~= nil, f.path .. ': no member satisfies the branch any '
            .. 'more -- the frame moved, and every number below is stale')
        assert(member:GetUnitName() == f.member,
            ('%s: the branch stops on %s, expected %s')
                :format(f.path, member:GetUnitName(), f.member))
        -- The cause, read at the same place the helper reads it.
        local allyList = J.GetSpecialModeAllies(member, 1400, BOT_MODE_ATTACK)
        assert(#allyList == 0, f.path .. ': the ally centroid has a contributor '
            .. 'here, so this frame is not on the sentinel path')
        local v = J.GetTeamFightLocation(member)
        assert(is_origin(v), ('%s: shipped answer should be the (0,0) sentinel, '
            .. 'got (%.0f,%.0f)'):format(f.path, v.x, v.y))
        -- ...and this is how far the answer is from the fight it reports on.
        local nOff = GetUnitToLocationDistance(member, v)
        assert(math.abs(nOff - f.moved) <= 1.0,
            ('%s: the fabricated answer sits %.0f from the fight, recorded %d')
                :format(f.path, nOff, f.moved))
    end
end

tests['[tfnull] 1b. the sentinel is indistinguishable from a place'] = function()
    -- The reason this survived: nothing downstream can reject it. The two
    -- properties every caller has to work with -- non-nil, and a distance --
    -- are both satisfied by the origin, and on the widest frame here the
    -- fabricated answer is closer to the map's own middle than the real fight
    -- is to anything.
    local J = rf.load(FRAMES[1].path)
    arm(J, false)
    local v = J.GetTeamFightLocation(GetBot())
    assert(v ~= nil, 'the sentinel passes the only test callers apply')
    assert(type(v.x) == 'number' and type(v.y) == 'number',
        'the sentinel is a well-formed Vector, which is the whole problem')
end

-- --------------------------------------------------------- 2. the fix -------

tests['[tfnull] 2. armed, the answer is the member the fight was found on'] = function()
    for _, f in ipairs(FRAMES) do
        local J = rf.load(f.path)
        arm(J, true)
        local member = qualifying_member(J)
        local v = J.GetTeamFightLocation(member)
        assert(not is_origin(v), f.path .. ': armed still answers the sentinel')
        local vMember = member:GetLocation()
        assert(math.abs(v.x - vMember.x) < 1e-6 and math.abs(v.y - vMember.y) < 1e-6,
            ('%s: armed answered (%.0f,%.0f), member is at (%.0f,%.0f)')
                :format(f.path, v.x, v.y, vMember.x, vMember.y))
        -- The move is the whole defect, restated as the fix's magnitude.
        assert(math.abs(GetUnitToLocationDistance(member, v)) < 1.0,
            f.path .. ': armed must answer the fight itself, distance 0')
    end
end

tests['[tfnull] 2b. the fix does not change WHICH fight is reported'] = function()
    -- The other free variable in this loop -- which member's fight wins when
    -- several qualify -- is decided by roster order and is NOT touched here.
    -- Asserted so a later round cannot slip that lever in under this id.
    for _, f in ipairs(FRAMES) do
        local J = rf.load(f.path)
        arm(J, true)
        local _, iShipped = qualifying_member(J)
        local v = J.GetTeamFightLocation(GetBot())
        local member = GetTeamMember(iShipped)
        assert(math.abs(v.x - member:GetLocation().x) < 1e-6,
            f.path .. ': armed answered about a different member than the '
            .. 'shipped loop order picks')
    end
end

-- ------------------------------------------------- 3. the loader bound ------

tests['[tfnull] 3. MEASURED: no fixture carries active-mode data'] = function()
    -- This is the reason section 1 finds the empty list on 5 of 5 qualifying
    -- frames, and the reason that 5-of-5 is NOT a frequency. If a future
    -- make_fixture.py starts dumping modes, this assertion goes red and the
    -- honest-bounds paragraph at the top of this file has to be rewritten --
    -- which is the point of asserting it instead of writing it in prose.
    local nChecked = 0
    for _, f in ipairs(FRAMES) do
        rf.load(f.path)
        for i = 1, #GetTeamPlayers(GetTeam()) do
            local member = GetTeamMember(i)
            if member ~= nil then
                assert(member:GetActiveMode() ~= BOT_MODE_ATTACK,
                    f.path .. ': a fixture hero now reports a real active mode')
                nChecked = nChecked + 1
            end
        end
    end
    assert(nChecked >= 20, 'expected to have checked the rosters, got ' .. nChecked)
    assert(BOT_MODE_ATTACK ~= 0, 'the default this leans on must differ from '
        .. 'BOT_MODE_ATTACK')
end

-- ------------------------------- 4. risk upper bound on the real frames -----

tests['[tfnull] 4. INJECTED modes: armed is byte-identical to shipped'] = function()
    -- The half the corpus cannot supply, supplied by declaration: give the
    -- roster the ATTACK mode the dump does not carry, so the ally centroid has
    -- contributors on exactly these real frames. Armed must then be a no-op --
    -- this is the change's risk upper bound on every frame that reaches the
    -- branch at all.
    local nFrames, nNonOrigin = 0, 0
    for _, f in ipairs(FRAMES) do
        local Joff, _, heroesOff = rf.load(f.path)
        for _, h in pairs(heroesOff) do
            rawget(h, '__spec').GetActiveMode = function() return BOT_MODE_ATTACK end
        end
        arm(Joff, false)
        local vOff = Joff.GetTeamFightLocation(GetBot())

        local Jon, _, heroesOn = rf.load(f.path)
        for _, h in pairs(heroesOn) do
            rawget(h, '__spec').GetActiveMode = function() return BOT_MODE_ATTACK end
        end
        arm(Jon, true)
        local vOn = Jon.GetTeamFightLocation(GetBot())

        assert(vOff ~= nil and vOn ~= nil, f.path .. ': the branch must still be '
            .. 'reached with modes injected')
        assert(vOff.x == vOn.x and vOff.y == vOn.y,
            ('%s: armed moved a frame whose centroid HAS contributors: '
                .. '(%.1f,%.1f) vs (%.1f,%.1f)')
                :format(f.path, vOff.x, vOff.y, vOn.x, vOn.y))
        nFrames = nFrames + 1
        if not is_origin(vOff) then nNonOrigin = nNonOrigin + 1 end

        -- ...and, on the same frame, how good the substitute anchor is: the
        -- distance between the centroid the branch WOULD have answered with
        -- data and the member the fix answers with instead. Read it against
        -- `moved` -- the sentinel is 844-8017 away from the fight, this is
        -- 7-307. NOT a claim about real games: the modes are injected here.
        local member = qualifying_member(Jon)
        local nGap = GetUnitToLocationDistance(member, vOff)
        assert(math.abs(nGap - f.gap) <= 1.0,
            ('%s: the substitute anchor sits %.0f from the populated centroid, '
                .. 'recorded %d'):format(f.path, nGap, f.gap))
        assert(nGap < f.moved,
            f.path .. ': the fix must be closer to the real centroid than the '
            .. 'sentinel it replaces')
    end
    assert(nFrames == #FRAMES, 'every frame must have been driven')
    -- The injection has to actually leave the sentinel path, or this section
    -- proves nothing but that two sentinels are equal.
    assert(nNonOrigin == #FRAMES, ('the injection must take every frame OFF the '
        .. 'sentinel path; %d of %d left it'):format(nNonOrigin, #FRAMES))
end

-- -------------------------------------------- 5. the forbidden directions ---

tests['[tfnull] 5. never invents an answer where the shipped code had none'] = function()
    -- Across the WHOLE corpus, armed may only rewrite an answer the shipped
    -- code already gave. A nil (no member qualifies) must stay nil: this fix is
    -- not allowed to widen the branch's domain by one frame.
    local nLive, nQual = 0, 0
    for _, path in ipairs(all_fixtures()) do
        local ok, Joff = pcall(rf.load, path)
        if ok and Joff ~= nil then
            nLive = nLive + 1
            arm(Joff, false)
            local vOff = Joff.GetTeamFightLocation(GetBot())
            local ok2, Jon = pcall(rf.load, path)
            assert(ok2, path .. ': second load failed')
            arm(Jon, true)
            local vOn = Jon.GetTeamFightLocation(GetBot())
            if vOff == nil then
                assert(vOn == nil, path .. ': armed invented a fight location '
                    .. 'on a frame where the shipped code had none')
            else
                nQual = nQual + 1
                assert(vOn ~= nil, path .. ': armed deleted an answer')
            end
        end
    end
    assert(nLive > 100, 'expected the whole corpus to load, got ' .. nLive)
    assert(nQual == #FRAMES, ('the branch is reached on %d frames, recorded %d')
        :format(nQual, #FRAMES))
end

tests['[tfnull] 5b. gate off and non-turbo both keep the shipped answer'] = function()
    for _, f in ipairs(FRAMES) do
        -- candidate not armed
        local J1 = rf.load(f.path)
        arm(J1, false)
        assert(is_origin(J1.GetTeamFightLocation(GetBot())),
            f.path .. ': unarmed must keep the shipped sentinel')
        -- armed but not Turbo. Driven through the predicate the call site
        -- reads, because J.IsModeTurbo caches its answer at first call and the
        -- fixture loader has already fixed GetGameMode by then.
        local J2 = rf.load(f.path)
        arm(J2, true)
        J2.IsModeTurbo = function() return false end
        assert(is_origin(J2.GetTeamFightLocation(GetBot())),
            f.path .. ': the fix must be turbo-only')
    end
end

return tests
