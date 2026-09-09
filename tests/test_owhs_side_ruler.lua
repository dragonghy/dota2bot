-- [l5trees cut 2 / RULER 20260909] J.GetOffWaveHarassSpot picked which way to
-- sidestep by averaging THE HARASS-TARGET LIST -- the enemies within 800 of me
-- -- while the sentence that choice implements says "away from their OTHER
-- laner". The other laner is exactly the hero who is usually NOT inside poke
-- range, so the code could not contain the unit its own comment named: an enemy
-- at 900 had no vote, and the 550u step could be aimed straight at them.
--
-- The fix gives the side choice its own census at 1200 -- a radius this branch
-- had already chosen twice (the helper's own peel scan, and the caller's
-- `J.WeAreStronger(bot, 1200)` on the very `if` that reaches the helper). No
-- new number and no new soak id: the single call site is a pure conjunction
-- with `IsSoakCandidate('l5trees')`, so the change rides that id, and a second
-- id inside an unpromoted gate can never be armed alone (GH #606). Section 3
-- asserts that call-site claim instead of trusting the header -- last round's
-- sister finding was a header making exactly this claim falsely.
--
-- ⛔ WHAT THIS CORPUS CANNOT DO, stated before any number below is read. The
-- helper's third conjunct needs an enemy lane creep within 500 of the bot, and
-- tests/fixtures carries NO CREEPS ON ANY FRAME (section 4 measures that rather
-- than citing it). Every driven row therefore injects ONE creep AT the bot.
-- That injection is bounded by the helper's own precondition instead of
-- invented: any creep list that passes the conjunct lies within 500 of the bot,
-- so its centroid does too, and the bot's own location is the centre of that
-- ball -- the deepnum vLoc convention with a radius bound deepnum did not have.
-- What stays unpriced is a lane axis that disagrees with (bot -> own fountain);
-- that is the open lane-geometry corpus request (GH #648 / #652). Section 9 is
-- the one reading that survives it: it needs no axis at all.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- ------------------------------------------------------------ source reads --

local function read_file(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a'); fh:close()
    return s
end

-- ------------------------------------------------------------- the manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_lanekill_domain_sweep.lua 2>&1'),
        'could not start tests/_lanekill_domain_sweep.lua')
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
            local fx, hero, what = line:match('^F (%S+) (%S+) (%S+)$')
            if fx then table.insert(m.F, { fixture = fx, hero = hero, what = what }) end
        elseif kind == 'DONE' then
            m.done = true
        end
    end
    assert(m.done, 'the corpus sweep did not finish -- run '
        .. '`lua5.1 tests/_lanekill_domain_sweep.lua` by hand to see why:\n'
        .. raw:sub(1, 800))
    manifest_cache = m
    return m
end

local function C(key)
    local n = manifest().C[key]
    assert(n ~= nil, 'the sweep did not report counter ' .. key)
    return n
end

local function G(key)
    local v = manifest().G[key]
    assert(v ~= nil and v ~= 'nil',
        'the sweep could not parse ' .. key .. ' out of the shipped source -- '
        .. 'a census that cannot read the ruler cannot check it')
    return v
end

-- Drive the helper on one real frame under the declared creep injection, and
-- compute the OLD rule's spot on the same frame with the same axis (the sweep's
-- arithmetic, restated here so a witness argument never leans on the sweep's
-- own conclusion).
local function drive(path, hero)
    local J, bot = rf.load(path, hero)
    local armed = {}
    J.IsSoakCandidate = function(id) return armed[id] == true end
    local vMe = bot:GetLocation()
    local nStep = tonumber(G('OW_STEP'))

    local function census(r)
        local t = J.GetNearbyHeroes(bot, r, true, BOT_MODE_NONE) or {}
        local x, y, n = 0, 0, 0
        local named = {}
        for _, e in pairs(t) do
            if J.IsValidHero(e) then
                local v = e:GetLocation()
                x, y, n = x + v.x, y + v.y, n + 1
                named[e:GetUnitName()] = math.floor(GetUnitToUnitDistance(bot, e))
            end
        end
        if n == 0 then return nil, nil, 0, named end
        return x / n - vMe.x, y / n - vMe.y, n, named
    end

    local ax, ay, nNarrow, tNarrow = census(tonumber(G('OW_TGT_R')))
    local bx, by, nWide, tWide = census(tonumber(G('OW_SIDE_R')))

    local vF = J.GetTeamFountain()
    assert(vF ~= nil, 'this frame has no team fountain; pick another witness')
    local dx, dy = vF.x - vMe.x, vF.y - vMe.y
    local mag = math.max(math.sqrt(dx * dx + dy * dy), 1)
    local px, py = -(dy / mag), dx / mag
    local function side_spot(cx, cy)
        local qx, qy = px, py
        if cx ~= nil and (qx * cx + qy * cy) > 0 then qx, qy = -qx, -qy end
        return { x = vMe.x + qx * nStep, y = vMe.y + qy * nStep }
    end

    local fakeCreep = {
        IsNull = function() return false end,
        CanBeSeen = function() return true end,
        IsAlive = function() return true end,
        IsBuilding = function() return false end,
        GetLocation = function() return Vector(vMe.x, vMe.y, 0) end,
    }
    bot.GetNearbyLaneCreeps = function(_, _r, bEnemy)
        if bEnemy then return { fakeCreep } end
        return {}
    end
    local vSpot = J.GetOffWaveHarassSpot(bot)

    local function dist_from(p, name)
        for _, e in pairs(J.GetNearbyHeroes(bot, tonumber(G('OW_SIDE_R')), true, BOT_MODE_NONE) or {}) do
            if J.IsValidHero(e) and e:GetUnitName() == name then
                local v = e:GetLocation()
                return math.floor(math.sqrt((p.x - v.x) ^ 2 + (p.y - v.y) ^ 2))
            end
        end
        return nil
    end

    return {
        spot = vSpot,
        old = side_spot(ax, ay),
        wide = side_spot(bx, by),
        n_narrow = nNarrow, n_wide = nWide,
        d_narrow = tNarrow, d_wide = tWide,
        dist_from = dist_from,
    }
end

-- ==================================== 1. the ruler, asserted as an equality --

tests['[owhs] the side census reads the radius this branch already uses, whatever it is']
= function()
    local nSide = tonumber(G('OW_SIDE_R'))
    local nAlly = tonumber(G('OW_ALLY_R'))
    local nCall = tonumber(G('OW_GATE_WESTRONGER_R'))
    -- The claim is EQUALITY, not "1200". A mutant that moves the side census
    -- back to 800, or overshoots it to 2400, has to be caught by the same line
    -- -- otherwise the census is asserting a number it copied out of the code.
    assert(nSide == nAlly, string.format(
        'the side census (%d) must read the same board as this helper\'s own '
        .. 'peel scan (%d): both ask "who is around me", one about the fight I '
        .. 'must not walk out of, the other about the ground I am walking onto',
        nSide, nAlly))
    assert(nSide == nCall, string.format(
        'the side census (%d) must read the same board as the caller\'s own '
        .. 'gate J.WeAreStronger(bot, %d) on the very `if` that reaches this '
        .. 'helper -- that is what makes 1200 this branch\'s number rather than '
        .. 'a number this round invented', nSide, nCall))
end

tests['[owhs] the TARGET census is still its own, smaller ruler'] = function()
    local nTgt = tonumber(G('OW_TGT_R'))
    local nSide = tonumber(G('OW_SIDE_R'))
    -- The other way to "fix one comparison with two rulers" is to widen the
    -- SHORT one, and here that would be a behaviour change of a completely
    -- different kind: the target list decides WHETHER the helper fires at all.
    -- This round deliberately did not touch it, and this line is what makes
    -- that a checked property instead of a promise in a comment.
    assert(nTgt < nSide, string.format(
        'the poke-range list (%d) must stay strictly inside the side census '
        .. '(%d); merging them would change when the sidestep fires, which is '
        .. 'not what this change measured', nTgt, nSide))
    assert(nTgt == 800, 'the harass-target radius moved (' .. nTgt
        .. '): it was not part of this change, so a move here means someone '
        .. 'retuned the firing condition under cover of the side-choice fix')
end

-- ======================================== 2. no new id, and why that is right --

tests['[owhs] the helper still carries no soak id of its own'] = function()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.GetOffWaveHarassSpot( bot )', 1, true),
        'J.GetOffWaveHarassSpot moved')
    local fin = assert(src:find('\nend\n', at, true), 'helper has no end')
    local body = src:sub(at, fin)
    assert(body:find('IsSoakCandidate', 1, true) == nil,
        'a second id inside a body already gated by the unpromoted \'l5trees\' '
        .. 'can never be armed alone -- the arm would be a conjunction, its '
        .. 'single-arm reading structurally zero, and check_armed_wiring.py '
        .. 'would still answer WIRED (GH #606)')
end

-- ================= 3. the gate claim in the header, CHECKED not inherited --

tests['[owhs] the one call site really is unreachable without l5trees'] = function()
    assert(tonumber(G('OW_CALLSITES')) == 1, 'the helper grew a second call '
        .. 'site: the "rides l5trees" argument is per-call-site and has to be '
        .. 'redone, not carried over')
    assert(tonumber(G('OW_GATE_HAS_L5')) == 1,
        "the call-site gate no longer names 'l5trees'")
    -- The sister finding of 2026-09-09: a header claiming "armed-only" while
    -- its caller's gate carried a disjunct that needed no id at all. Read the
    -- gate for ` or `, disjunct by disjunct, rather than believing the header.
    assert(tonumber(G('OW_GATE_HAS_OR')) == 0,
        'the call-site gate grew a disjunction: it may now be reachable with '
        .. 'no soak id armed, in which case this helper is LIVE in real games '
        .. 'and the change inside it needs a gate of its own')
end

-- ============================ 4. the instrument, before any driven reading --

tests['[owhs] this corpus carries no lane creeps at all -- measured, not cited']
= function()
    assert(C('ow_creeps_zero') == C('ow_live'), string.format(
        'ow_creeps_zero %d != ow_live %d: the corpus grew creeps, so the '
        .. 'declared one-creep injection is no longer the only way the driven '
        .. 'rows can exist -- re-read them before quoting them',
        C('ow_creeps_zero'), C('ow_live')))
    assert(C('ow_creeps_live') == 0, 'ow_creeps_live went non-zero')
end

-- ===================================== 5. the domain, funnel by funnel --

tests['[owhs] the corpus reaches every conjunct the loader can answer'] = function()
    assert(C('ow_live') > 900, 'the corpus shrank below the 1021 frames this '
        .. 'round priced; the counts below are not comparable')
    assert(C('ow_target') > 0 and C('ow_reach') > 0, string.format(
        'the domain went empty (target %d, reach %d) -- a zero here is a '
        .. 'finding about the corpus, not a licence to skip the rest',
        C('ow_target'), C('ow_reach')))
    -- Every frame where the wider board holds MORE heroes is a frame where a
    -- hero in the band got a vote. Two counters, one population: they are equal
    -- by construction, and a split means one of them stopped counting.
    assert(C('ow_band') == C('ow_side_pop_differs'), string.format(
        'ow_band %d != ow_side_pop_differs %d', C('ow_band'), C('ow_side_pop_differs')))
end

-- ===================== 6. two independent routes to one number (the M5 lesson) --

tests['[owhs] the driven spot equals the wide-census spot on every frame'] = function()
    assert(C('ow_drive_raised') == 0, 'the helper raised on a real frame')
    assert(C('ow_drive_matches_wide') == C('ow_drive_nonnil'), string.format(
        'ow_drive_matches_wide %d != ow_drive_nonnil %d: the shipped helper '
        .. 'stopped keying on its own side census, and only running both routes '
        .. 'can see that', C('ow_drive_matches_wide'), C('ow_drive_nonnil')))
    assert(C('ow_drive_matches_narrow') == C('ow_drive_nonnil') - C('ow_side_flips'),
        string.format('ow_drive_matches_narrow %d != nonnil %d - flips %d',
            C('ow_drive_matches_narrow'), C('ow_drive_nonnil'), C('ow_side_flips')))
end

-- ============================================ 7. the forbidden direction --

tests['[owhs] widening the vote never changes WHETHER the sidestep fires']
= function()
    assert(C('ow_drive_nil_on_reach') == 0, string.format(
        'ow_drive_nil_on_reach %d: a frame passed every conjunct this corpus '
        .. 'can answer and the helper still returned nil, which means the side '
        .. 'census leaked into the firing condition -- the one direction this '
        .. 'change is not allowed to move', C('ow_drive_nil_on_reach')))
    assert(C('ow_step_u') <= tonumber(G('OW_STEP')), 'the step grew past '
        .. G('OW_STEP') .. 'u: the sidestep is bounded by construction, so a '
        .. 'longer one means the perpendicular stopped being a unit vector')
end

-- ====================== 8. a BOUND, not an equality (the deepnum discipline) --

tests['[owhs] the band population bounds the flips and is not equal to them']
= function()
    assert(C('ow_side_flips') > 0, 'no frame in this corpus flips: the change '
        .. 'is unpriced here and must not be quoted as measured')
    assert(C('ow_band') > C('ow_side_flips'), string.format(
        'ow_band %d must strictly exceed ow_side_flips %d -- a band enemy only '
        .. 'moves the answer when it drags the centroid across the lane axis, '
        .. 'so equality would mean the flip test stopped testing anything',
        C('ow_band'), C('ow_side_flips')))
end

-- ==================================== 9. the axis-free reading (survives GH #648) --

tests['[owhs] the vote direction moves, measured without any lane axis'] = function()
    -- A flip happens iff the lane perpendicular separates the two centroid
    -- directions, so an angle >= 90 degrees means MORE THAN HALF of all
    -- conceivable lane axes flip the side on that frame. This is the only row
    -- here that does not depend on the (bot -> fountain) axis convention.
    assert(C('ow_vote_deg_max') >= 90, 'the widest vote swing in the corpus is '
        .. C('ow_vote_deg_max') .. ' degrees; below 90 no axis-free claim '
        .. 'survives and the witnesses become axis-dependent only')
    assert(C('ow_vote_ge90') >= 1, 'no frame swings the vote past 90 degrees')
end

-- ============================================= 10. the named witnesses --

tests['[owhs] witness 1: an enemy at 1163 had no vote on where to walk']
= function()
    -- f_231411_ck_zoned, tidehunter. Poke target chaos_knight at 361; Skywrath
    -- Mage stands at 1163 -- outside the 800 list, so under the old ruler it
    -- did not exist for the side choice, and the old side lands 715 from it.
    local r = drive('tests/fixtures/f_231411_ck_zoned.lua', 'npc_dota_hero_tidehunter')
    assert(r.spot ~= nil, 'the witness frame stopped producing a spot')
    assert(r.d_narrow['npc_dota_hero_skywrath_mage'] == nil,
        'skywrath moved inside the poke list; the witness no longer shows a '
        .. 'hero with no vote')
    assert(r.d_wide['npc_dota_hero_skywrath_mage'] ~= nil,
        'skywrath left the side census; pick another witness')
    local dOld = r.dist_from(r.old, 'npc_dota_hero_skywrath_mage')
    local dNew = r.dist_from(r.spot, 'npc_dota_hero_skywrath_mage')
    assert(dOld < 800 and dNew > 1500, string.format(
        'old side lands %d from the voteless hero, new side %d -- the witness '
        .. 'is that the step was aimed at somebody the vote could not see',
        dOld, dNew))
end

tests['[owhs] witness 2: the same shape on the game that produced this helper']
= function()
    -- f_175703_sven_tp47, shadow_shaman. Game 175703 is the batch game whose
    -- 2:44 sidestep produced this helper's fight-awareness guard; the same game
    -- carries the ruler defect. Witch Doctor at 953 has no vote; the poke
    -- target Sven ends up at essentially the same distance either way (701 vs
    -- 681), so this frame is the trade-free one.
    local r = drive('tests/fixtures/f_175703_sven_tp47.lua', 'npc_dota_hero_shadow_shaman')
    assert(r.spot ~= nil, 'the witness frame stopped producing a spot')
    assert(r.d_narrow['npc_dota_hero_witch_doctor'] == nil
        and r.d_wide['npc_dota_hero_witch_doctor'] ~= nil,
        'witch doctor is no longer the band hero on this frame')
    local dOld = r.dist_from(r.old, 'npc_dota_hero_witch_doctor')
    local dNew = r.dist_from(r.spot, 'npc_dota_hero_witch_doctor')
    assert(dNew > dOld + 300, string.format(
        'the wider vote must clear the voteless hero by a visible margin here '
        .. '(old %d, new %d)', dOld, dNew))
    local sOld = r.dist_from(r.old, 'npc_dota_hero_sven')
    local sNew = r.dist_from(r.spot, 'npc_dota_hero_sven')
    assert(math.abs(sOld - sNew) < 100, string.format(
        'and it must do so without moving the bot relative to the hero it is '
        .. 'poking on THIS frame (old %d, new %d) -- that is what makes this '
        .. 'witness the one with no trade in it', sOld, sNew))
end

tests['[owhs] negative control: a band hero that does NOT move the answer']
= function()
    -- Same fixture, different subject (viper): Witch Doctor is in the band at
    -- 1007 and gets a vote, and the side comes out bit-identical. Without this
    -- frame a reader cannot tell "the wider census refines the answer" from
    -- "the wider census replaces it".
    local r = drive('tests/fixtures/f_175703_sven_tp47.lua', 'npc_dota_hero_viper')
    assert(r.spot ~= nil, 'the control frame stopped producing a spot')
    assert(r.n_wide > r.n_narrow, string.format(
        'the control needs the board to actually change (narrow %d, wide %d)',
        r.n_narrow, r.n_wide))
    assert(math.abs(r.spot.x - r.old.x) < 1 and math.abs(r.spot.y - r.old.y) < 1,
        'the extra voter is counted here and the side still does not move')
end

-- ================================ 11. the cost, registered rather than argued --

tests['[owhs] the wider vote can step nearer the hero being poked -- measured']
= function()
    -- ⚠️ On all 4 flip frames the new spot is nearer to SOMEBODY than the old
    -- one, and on 2 of them it lands inside 400 of an enemy where the old rule
    -- landed inside 400 of none. That is not a bug being hidden: with exactly
    -- one hero in poke range the old ruler reduces to "step away from the hero
    -- I am about to attack", which walks the support OUT of harass range (the
    -- witnesses land 863-922 from their own target) and defeats the branch's
    -- stated purpose -- the NEXT think is supposed to harass from there. The
    -- open question this does NOT answer is whether the chosen side puts the
    -- bot inside the target's attack range; the helper has never asked that,
    -- this round did not add it, and it is the registered next lever.
    assert(C('ow_flip_nearer_someone') == C('ow_side_flips'), string.format(
        'ow_flip_nearer_someone %d vs ow_side_flips %d -- if this stops being '
        .. 'every flip frame, the trade described above changed shape and the '
        .. 'prose above is stale', C('ow_flip_nearer_someone'), C('ow_side_flips')))
    assert(C('ow_flip_close400_wide') >= C('ow_flip_close400_narrow'),
        string.format('close400 wide %d / narrow %d', C('ow_flip_close400_wide'),
            C('ow_flip_close400_narrow')))
end

return tests
