-- [strategy 20260912 / GH #782 second family] AN OUTPOST IS AN ALLIED BUILDING,
-- AND THAT IS A DIFFERENT DEFECT FROM THE NAME TEST GH #782 WAS FILED ABOUT.
--
-- WHAT THIS FILE PINS
-- -------------------
-- GH #782 is a NAME TEST bug: `string.find( b:GetUnitName(), 'tower' )` also
-- matches `npc_dota_watch_tower`, so a captured outpost reads as a defensible
-- tower. Three sites were counted there and every one of them has a name test
-- to narrow.
--
-- ⭐ THE FINDING THIS FILE ADDS: the family is strictly LARGER than the name
-- test, and its other half is unreachable by a name-test fix. A captured
-- outpost is a MEMBER of `GetUnitList( UNIT_LIST_ALLIED_BUILDINGS )` and it
-- PASSES `J.IsValidBuilding` (= `IsValidUnit and unit:IsBuilding()`), so every
-- reader that uses that list as a PROXIMITY ANCHOR and carries NO name test at
-- all is contaminated too -- and there is nothing there for GH #782's narrowing
-- to attach to. Measured over the whole fixture corpus by
-- tests/_outpost_anchor_sweep.lua:
--
--     wt_fixtures 68   wt_allied 68   wt_valid 68
--
-- i.e. 68 of 111 fixtures carry an allied outpost, all 68 appear in the allied
-- list, and NOT ONE is rejected by the filter every shipped reader trusts.
--
-- The two no-name-test anchor sites in bots/ are
-- J.ShouldRefuseUnsupportedPunish ('ohnum', narrowed here) and
-- J.ShouldPunishOverchase's DEEP building branch ('overchase', left alone this
-- round -- one lever at a time).
--
-- WHY THE ohnum SITE IS THE SHARPER OF THE TWO
-- --------------------------------------------
-- The release being narrowed is justified, in the helper's own prose one screen
-- up, by exactly one sentence: "the tower is the ally the count does not name,
-- so parity there is really parity plus a tower". An outpost HAS NO ATTACK. It
-- supplies none of the support that sentence rests on, so the release can fire
-- on an anchor worth zero fighters and hand back the parity/1v1 punish at 0.98
-- desire that this helper exists to refuse. The defect is CLOSED FORM -- an
-- outpost does not shoot -- and needs no corpus witness; what needed measuring
-- is the MEMBERSHIP, and that is the reading above.
--
-- ⚠️ EFFECT SIZE ON THIS CORPUS IS ZERO, AND THE ZERO IS ATTRIBUTED
-- ----------------------------------------------------------------
-- Over 111 fixtures / 1031 live hero-frames / 804 (subject, visible enemy)
-- pairs: `oa_anchor 53` pairs have an allied building inside the 1200 anchor
-- radius, and `oa_anchor_has_wt 0` -- not one of those anchors is an outpost.
-- Hence `oa_anchor_wt_only 0` and the flip set `oa_wt_only_would_refuse 0`.
--
-- ⭐⭐ THE POSITIVE CONTROL, because a negative reading whose only support is
-- the no-op assertions themselves is free. A dead distance instrument would
-- produce those same zeros and look identical. So the sweep reads the SAME
-- handles through the SAME distance call at two wider radii and reports the
-- closest outpost-to-enemy distance it ever saw:
--
--     oa_wt_within_4800 127        MIN_WT_TO_ENEMY_DIST 2466.3
--
-- Non-zero and finite ⇒ the instrument was alive when it answered zero, and the
-- zero is GEOMETRY: this corpus contains no outpost fight, the nearest approach
-- being more than TWICE the 1200 radius.
--
-- ⛔ WHY IT IS STILL CUT AND NOT MERELY REGISTERED. The previous round's
-- 'table zero' ruling (GH #782's mode_retreat_generic site) refused a cut
-- because the inertness there is CONSTRUCTIVE -- the outpost branch is inert in
-- a real game too, so corpus and game are indistinguishable. That is not the
-- case here: an enemy hero within 1200 of one of our outposts is an ordinary
-- in-game configuration, and the corpus is thin (111 frames), not the game.
-- Domain real, corpus thin ⇒ cut, with the effect size registered as zero-here.
--
-- SCOPE
-- -----
--   * Zero new gate ids. The narrowing inherits 'ohnum', because the host is
--     itself an unpromoted candidate and a nested id would be the conjunction
--     `ohnum AND <new>` -- an isolation wave arming <new> alone would read a
--     structurally impossible zero that check_armed_wiring.py still calls
--     WIRED (the 'pullcad' trap). Asserted below, not asserted by comment.
--   * Shipped play is unchanged: 'ohnum' is unpromoted, so the helper returns
--     false on its second line in every real game.
--   * Zero AWS, no S3 access.
--
-- DECLARED SYNTHETIC (one, and it is one operand)
-- -----------------------------------------------
-- The flip cannot be driven on an unmodified frame -- that is what
-- `oa_anchor_has_wt 0` means. So the [drive] case below swaps the ANCHOR'S
-- IDENTITY and nothing else: the allied-building list is replaced by a single
-- proxy that delegates every method to the fixture's OWN REAL outpost handle
-- (real name, real team, real alive flag, real IsBuilding) except GetLocation,
-- which answers the position of the REAL tower that releases this frame today.
-- Both arms are driven against the identical world; the only difference is the
-- narrowing. The un-narrowed answer is recomputed on the same handles rather
-- than by mutating the tree, so the flip is a difference and not an assertion.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'
local SWEEP = 'tests/_outpost_anchor_sweep.lua'

-- The frame the sibling file already cut around as the case where a live
-- building of ours is right there and the release therefore fires.
local PARITY      = 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua'
local PARITY_HERO = 'npc_dota_hero_axe'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Line comments only -- this tree has no long-bracket comments in jmz_func,
-- and the narrowing being pinned is CODE, so prose must never satisfy it.
local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- Body of a top-level `function <name>(` ... up to the next top-level
--- `function J.`, comments stripped.
local function fn_body(sName)
    local src = strip_comments(read_file(JMZ))
    local i = assert(src:find('function ' .. sName .. '%('),
        'no such top-level function: ' .. sName)
    local j = src:find('\nfunction J%.', i + 10) or #src
    return src:sub(i, j)
end

---------------------------------------------------------------------------
-- [source]
---------------------------------------------------------------------------

tests['[source] J.IsOutpostBuilding exists, is ungated, and names watch_tower'] = function()
    local body = fn_body('J.IsOutpostBuilding')
    assert(body:find('watch_tower', 1, true),
        'J.IsOutpostBuilding no longer names watch_tower. That literal is the '
        .. 'only stable discriminator for an outpost (its TEAM is whoever '
        .. 'holds it, and modifier_watch_tower_capturing only exists '
        .. 'mid-channel), and tests/_outpost_anchor_sweep.lua parses it out of '
        .. 'this function so the census cannot disagree with the narrowing')
    assert(not body:find('IsSoakCandidate', 1, true),
        'J.IsOutpostBuilding has acquired a gate. It is a pure predicate with '
        .. 'several intended callers; a gate here would silently disarm every '
        .. 'one of them and each caller already carries its own')
    assert(body:find('IsNull', 1, true),
        'J.IsOutpostBuilding no longer guards IsNull before GetUnitName; a '
        .. 'stale building handle would raise instead of answering false')
end

tests['[source] the narrowing is in the ohnum release loop, before the distance test'] = function()
    local body = fn_body('J.ShouldRefuseUnsupportedPunish')
    local iNarrow = body:find('not J.IsOutpostBuilding( building )', 1, true)
    assert(iNarrow ~= nil,
        'the outpost narrowing is gone from J.ShouldRefuseUnsupportedPunish. '
        .. 'Without it a captured outpost -- which passes J.IsValidBuilding '
        .. 'and sits in UNIT_LIST_ALLIED_BUILDINGS -- releases a refusal whose '
        .. 'whole stated reason is that the anchor is a fighter the count does '
        .. 'not name')
    local iValid = body:find('J.IsValidBuilding( building )', 1, true)
    local iDist = body:find('GetUnitToUnitDistance( target, building )', 1, true)
    assert(iValid and iDist, 'the release loop no longer has the shape this '
        .. 'file pins (a validity test and a distance test on `building`)')
    assert(iValid < iNarrow and iNarrow < iDist,
        'the narrowing moved out of the position it was cut into '
        .. '(IsValidBuilding < IsOutpostBuilding < distance). The order is not '
        .. 'cosmetic: a name test is cheaper than a distance call, and putting '
        .. 'it after the distance test pays for a measurement that is about to '
        .. 'be discarded')
end

tests['[source] no new soak id: the narrowing inherits ohnum'] = function()
    local body = fn_body('J.ShouldRefuseUnsupportedPunish')
    local n = 0
    for _ in body:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 1, 'J.ShouldRefuseUnsupportedPunish now asks '
        .. tostring(n) .. ' soak candidates. A second id inside a host that is '
        .. 'itself an unpromoted candidate is the conjunction `ohnum AND '
        .. '<new>`: an isolation wave arming <new> alone reads a zero that is '
        .. 'structurally impossible rather than informative, and '
        .. 'check_armed_wiring.py still calls it WIRED (the pullcad trap)')
    assert(body:find("IsSoakCandidate( 'ohnum' )", 1, true),
        'the one gate in this function is no longer ohnum')
end

tests['[source] the precondition still holds: J.IsValidBuilding admits outposts'] = function()
    local body = fn_body('J.IsValidBuilding')
    assert(not body:find('watch_tower', 1, true)
        and not body:find('IsOutpostBuilding', 1, true),
        'J.IsValidBuilding now excludes outposts by itself. That is a LARGER '
        .. 'and possibly better fix than the per-site narrowing this file '
        .. 'pins, and it makes this narrowing redundant rather than wrong -- '
        .. 'but it also moves every one of the ~120 J.IsValidBuilding call '
        .. 'sites at once, so it must be read as a deliberate decision and '
        .. 'this file re-baselined, not as a regression')
end

tests['[source] the census file declares its positive control'] = function()
    local src = read_file(SWEEP)
    for _, k in ipairs({ 'oa_anchor_has_wt', 'oa_wt_within_4800',
        'MIN_WT_TO_ENEMY_DIST' }) do
        assert(src:find(k, 1, true),
            'the census no longer reports `' .. k .. '`. The zero this file '
            .. 'registers (oa_anchor_wt_only 0) is only readable next to a '
            .. 'reading that MUST come out non-zero; without the control it is '
            .. 'indistinguishable from a dead distance instrument')
    end
end

---------------------------------------------------------------------------
-- [frame] / [drive]
---------------------------------------------------------------------------

--- Every live allied building on the loaded frame, split by outpost-ness.
local function allied_buildings(J)
    local tOut, tReal = {}, {}
    for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
        if J.IsValidBuilding(b) then
            if J.IsOutpostBuilding(b) then tOut[#tOut + 1] = b
            else tReal[#tReal + 1] = b end
        end
    end
    return tOut, tReal
end

tests['[frame] an allied outpost is in the list and passes the filter every reader trusts'] = function()
    local J = rf.load(PARITY, PARITY_HERO)
    local tOut, tReal = allied_buildings(J)
    assert(#tOut >= 1, 'this frame no longer carries an allied outpost that '
        .. 'clears J.IsValidBuilding; the membership fact this whole file '
        .. 'rests on cannot be witnessed here any more')
    assert(#tReal >= 1, 'this frame carries no ordinary allied building, so '
        .. 'the control case below (a real tower still releases) has no subject')
    -- The finding, stated as the two predicates disagreeing on one handle.
    local b = tOut[1]
    assert(J.IsValidBuilding(b) and J.IsOutpostBuilding(b),
        'the outpost handle no longer satisfies both predicates at once, which '
        .. 'is the entire defect: the readers filter on the first and mean the '
        .. 'negation of the second')
end

--- Drive the real helper with the allied-building list replaced by `tList`.
--- Nothing else is touched; the previous list function is restored after.
local function drive_with_buildings(J, bot, target, tList, armed)
    local prev = GetUnitList
    GetUnitList = function(kind)
        if kind == UNIT_LIST_ALLIED_BUILDINGS then return tList end
        return prev(kind)
    end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    local ok, res = pcall(J.ShouldRefuseUnsupportedPunish, bot, target)
    GetUnitList = prev
    assert(ok, 'J.ShouldRefuseUnsupportedPunish raised: ' .. tostring(res))
    return res
end

--- The un-narrowed release, recomputed on the SAME handles: true = "the old
--- loop would have released here". Not a mutation of the tree -- a difference.
local function unnarrowed_releases(J, target, tList)
    for _, b in pairs(tList) do
        if J.IsValidBuilding(b)
            and GetUnitToUnitDistance(target, b) <= 1200 then
            return true
        end
    end
    return false
end

--- A proxy that IS the real outpost handle except for where it stands.
local function outpost_at(hOutpost, vLoc)
    return setmetatable({ GetLocation = function() return vLoc end },
        { __index = hOutpost })
end

--- The enemy hero this frame's punish trigger actually selects.
local function punish_target(J, bot)
    local armed = { ownhalf = true, ohnum = true }
    J.IsSoakCandidate = function(id) return armed[id] == true end
    local t = J.ShouldPunishDive(bot)
    if t ~= nil then return t end
    -- Fall back to any visible enemy hero: this file's claim is about the
    -- ANCHOR loop, which runs before anything target-specific.
    for _, e in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(e) then return e end
    end
    return nil
end

tests['[control] a real tower still releases the refusal -- the narrowing is not a blanket'] = function()
    local J, bot = rf.load(PARITY, PARITY_HERO)
    local target = punish_target(J, bot)
    assert(target ~= nil, 'no visible enemy hero on the parity frame; this '
        .. 'case has no subject')
    local _, tReal = allied_buildings(J)
    -- Put the real tower where it releases, so this case tests the narrowing
    -- and not the frame's geometry.
    local hAnchor = { outpost_at(tReal[1], target:GetLocation()) }
    assert(unnarrowed_releases(J, target, hAnchor),
        'the un-narrowed loop does not release on a real tower placed at the '
        .. 'target; the control is mis-set-up')
    assert(drive_with_buildings(J, bot, target, hAnchor, { ohnum = true }) == false,
        'the narrowed helper now REFUSES with an ordinary allied tower on the '
        .. 'target. The narrowing was supposed to remove outposts only; a '
        .. 'blanket refusal changes the shipped domain this helper promises '
        .. 'not to touch')
end

tests['[drive] swap the anchor for the frame\'s own outpost and the refusal FLIPS'] = function()
    local J, bot = rf.load(PARITY, PARITY_HERO)
    local target = punish_target(J, bot)
    assert(target ~= nil, 'no visible enemy hero on the parity frame')
    local tOut, tReal = allied_buildings(J)
    -- DECLARED SYNTHETIC, one operand: the frame's OWN outpost handle (real
    -- name, team, alive flag, IsBuilding) standing where the REAL tower that
    -- releases this frame stands.
    local vWhereTheTowerReleases = target:GetLocation()
    local hAnchor = { outpost_at(tOut[1], vWhereTheTowerReleases) }
    assert(J.IsOutpostBuilding(hAnchor[1]) and J.IsValidBuilding(hAnchor[1]),
        'the proxy lost one of the two predicates it must carry; it has to be '
        .. 'a valid building AND an outpost or it is not the case under test')

    -- The old behaviour, on these very handles.
    assert(unnarrowed_releases(J, target, hAnchor) == true,
        'the un-narrowed release does NOT fire on an outpost at the target. '
        .. 'That is the claim this whole file rests on (an outpost passes '
        .. 'J.IsValidBuilding and is in the allied list); if it is false the '
        .. 'narrowing has no defect to repair')

    -- ...and the narrowed behaviour on the same handles.
    local bRefused = drive_with_buildings(J, bot, target, hAnchor, { ohnum = true })
    assert(bRefused == true,
        'the narrowed helper still RELEASES with the only anchor an outpost. '
        .. 'The outpost conjunct is either gone or placed where the loop never '
        .. 'reaches it, and the release is being handed a parity punish on an '
        .. 'anchor worth zero fighters')
    -- Both sides of the flip are now stated as readings, not as one assertion.
    assert(unnarrowed_releases(J, target, hAnchor) ~= (not bRefused),
        'the two arms agree on this frame, so it witnesses nothing')
end

tests['[control] gate off and non-turbo both answer false regardless of the anchor'] = function()
    local J, bot = rf.load(PARITY, PARITY_HERO)
    local target = punish_target(J, bot)
    assert(target ~= nil, 'no visible enemy hero on the parity frame')
    local tOut = (allied_buildings(J))
    local hAnchor = { outpost_at(tOut[1], target:GetLocation()) }
    assert(drive_with_buildings(J, bot, target, hAnchor, {}) == false,
        'J.ShouldRefuseUnsupportedPunish answers true with ohnum UNARMED. '
        .. 'This helper must be inert in every shipped game; the narrowing '
        .. 'rides its host gate and must never reach a real match')
    local prev = J.IsModeTurbo
    J.IsModeTurbo = function() return false end
    local bNonTurbo = drive_with_buildings(J, bot, target, hAnchor, { ohnum = true })
    J.IsModeTurbo = prev
    assert(bNonTurbo == false,
        'the helper answers true outside turbo. Every lever in this lab is '
        .. 'turbo-only and this one reads a turbo-specific trade')
end

---------------------------------------------------------------------------
-- ⛔ NO PRIVATE HARNESS. `tests/run_tests.lua` is the only supported entry
-- point (GH #200/#387): a file that runs and exits itself passes standalone and
-- takes the runner down mid-suite the first time one of its cases goes red --
-- which is what tests/test_run_tests_guard.py's "no test file exits the process
-- itself" check exists to refuse. Run this file with
--   lua5.1 tests/run_tests.lua ohnum_outpost_anchor

return tests
