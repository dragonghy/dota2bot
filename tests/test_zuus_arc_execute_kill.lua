-- [hero] soak candidate `zusarcexec` (turbo-only, gated, UNARMED) -- the kill
-- test X.ConsiderQ's EXECUTE branch states in its POSITION and not in its
-- PREDICATE.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_zuus.lua X.ConsiderQ opens with a loop over every enemy hero
-- inside Arc Lightning's cast range and returns BOT_ACTION_DESIRE_HIGH on the
-- FIRST one it finds under 20% health.  That loop is above all six other firing
-- points -- the laning last-hit, the retreat self-defence, the teamfight AoE
-- (>= 2 targets), the push/defend AoE (>= 3), the chosen-target initiation, the
-- farm and the Roshan branches -- and unlike every one of them it is not
-- conditioned on a mode.  Each of the six says what it is buying.  This one
-- buys a FINISH, and the only thing it asks the frame is
--
--     J.GetHP( npcEnemy ) <= 0.2
--
-- A percentage is not a kill test, and what it hides is not a fixed error: the
-- left side scales with max health and Arc Lightning's damage does not.  Two
-- rows, both read off this repo's own Zeus frames, before magic resistance is
-- even applied to the right column:
--
--     frame                                    0.2 * max_hp    arc_damage
--     --------------------------------------   -------------   ----------
--     f_260909_215227_zeus_arc_od_79  (rank 1)  0.20 *  802     105
--     f_260909_215227_zeus_bolt_od_1084 (rk 4)  0.20 * 2762     180
--
-- Six lines below, the LANING branch of the same function tests exactly the
-- thing this branch asserts --
-- `J.WillKillTarget( creep, nDamage, DAMAGE_TYPE_MAGICAL, nCastPoint )` -- on
-- the SAME `nDamage` local this branch computes and never reads.  Armed appends
-- that call, same arguments, same local.  It invents no threshold.
--
-- Same family as `wkqodds` (GH #708) and `cmqpoke` (GH #698): the qualified
-- test is not missing from the file, it is missing from THIS branch.
--
-- ===========================================================================
-- §0.1  THE PIN, AND ITS GROUND TRUTH FROM THE SAME REPLAY
-- ===========================================================================
--
-- tests/frames/f_260909_215227_zeus_exec_wk_615.lua, t=615.5, Zeus the subject:
--
--     Zeus level 10, Arc Lightning rank 4 (KV arc_damage 180), cd 0.
--     Wraith King at 241 / 1317 = 18.3% health, 71.4u away -- the only enemy
--     hero in cast range, and the branch's whole domain on this frame.
--     Lightning Bolt (rank 3) is 0.6s from ready; the ult is 48.1s away.
--
-- The replay this frame was cut from says what the shipped branch bought
-- (tools/batch_test/behavioral, same timeline, combat log):
--
--     613.3  zuus_arc_lightning -> skeleton_king   130 damage (+37 static field)
--     615.2  zuus_arc_lightning -> skeleton_king   130 damage  <- THIS frame
--     617.2  zuus_arc_lightning -> skeleton_king
--     617.9  zuus_lightning_bolt -> skeleton_king
--     619.9  skeleton_king DIES -- credited to npc_dota_hero_pudge
--
-- THREE arcs at a hero the arc cannot finish, and the kill went to somebody
-- else.  Note the measured 130: that is the engine's own post-mitigation number
-- for a rank-4 arc, against 241 points of health.  The gap is not a modelling
-- artefact of this test.
--
-- ===========================================================================
-- §0.2  WHAT THIS TEST DOES NOT CLAIM -- the mock cannot see spell immunity
-- ===========================================================================
--
-- Section 3 records a HARNESS defect found while sizing this lever, and it is
-- registered here because it inflates this very lever's domain by one:
-- tests/mock's unit objects answer `IsMagicImmune()` FALSE on a hero carrying
-- `modifier_black_king_bar_immune`.  J.CanCastOnNonMagicImmune -- a conjunct of
-- the branch under test, and of a great many branches elsewhere -- exists to
-- veto exactly that hero, and on fixtures it never does.
--
-- Consequence, stated before the numbers rather than after: on
-- f_260909_215227_zeus_exec_od_1467.lua the elected target is an Obsidian
-- Destroyer with 0.6s of BKB left.  The mock lets the shipped branch fire there;
-- the engine would not.  So the corpus funnel in section 5 reports FOUR frames
-- reaching the branch and THREE after that instant is removed by hand, and
-- every direction claim in this file is made on the three.
--
-- ===========================================================================
-- §0.3  DIRECTION, at two altitudes, because they are not one claim
-- ===========================================================================
--
--   * at the BRANCH: strictly narrowing by construction.  A conjunct appended
--     to an `if` that returns can delete this branch's fire and can never add
--     one.  Section 4 drives that on the real frames.
--   * at the FUNCTION: a suppressed frame FALLS THROUGH to the six branches
--     below, which may return a cast of the same ability at a DIFFERENT target.
--     So armed re-aims as often as it silences, and section 5 reports the two
--     columns apart rather than summing them.  On today's corpus the fall-
--     through is silent on both frames -- no lower branch bids -- and that is a
--     fact about this corpus, not a property of the lever.
--
-- ZERO effect shipped: the gate is unarmed and turbo-only (section 2).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local T = {}

local ZEUS = 'npc_dota_hero_zuus'
local PART = 'zuus'
local ARC  = 'zuus_arc_lightning'
local SRC  = 'bots/BotLib/hero_zuus.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The pin: the branch fires, and the finish it claims is false.
local PIN      = 'tests/frames/f_260909_215227_zeus_exec_wk_615.lua'
-- The carve-out: the branch fires and the finish it claims is TRUE, so armed
-- keeps the cast.  Without this frame "armed narrows" and "armed is off" are
-- the same reading.
local CARVEOUT = 'tests/frames/f_260909_215227_zeus_bolt_wk_434.lua'
-- The instant the mock manufactures (see §0.2): elected target holds BKB.
local IMMUNE   = 'tests/frames/f_260909_215227_zeus_exec_od_1467.lua'

--- Every corpus file from BOTH directories, never a hardcoded list -- the
--- enumeration idiom of tests/test_cm_ult_reach_meter_domain.lua.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame. '
            .. 'An empty enumerator and an empty corpus are the same integer; '
            .. 'this assertion is what tells them apart.')
    end
    table.sort(out)
    return out
end

local function zeus_record(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return nil end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == ZEUS and u.alive == true then return u, chunk end
    end
    return nil
end

--- Re-walk the branch's OWN conjunction on a real frame, with the real helpers
--- and the real handles, in the order the source reads them.  Returns nil when
--- the frame never reaches the loop.
--- @param opts table {armed=bool, turbo=bool}
local function branch(path, opts)
    opts = opts or {}
    local res
    local ok, err = pcall(function()
        local J, bot = rf.load(path, ZEUS)
        J.IsSoakCandidate = function(id) return opts.armed == true and id == 'zusarcexec' end
        J.IsModeTurbo     = function() return opts.turbo ~= false end
        local X = rf.load_hero(PART)
        pcall(X.SkillsComplement)  -- binds the file's upvalues (abilityASBonus &c.)

        local q = bot:GetAbilityByName(ARC)
        if not (q and q:IsFullyCastable()) then return end
        if J.ShouldConserveManaInLane(bot) then return end

        local nCastRange = q:GetCastRange()
        local nCastPoint = q:GetCastPoint()
        local nDamage    = q:GetSpecialValueInt('arc_damage')

        for _, e in pairs(J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE)) do
            if J.IsValidHero(e)
                and J.CanCastOnNonMagicImmune(e)
                and J.CanCastOnTargetAdvanced(e)
                and J.GetHP(e) <= 0.2
            then
                if res == nil then
                    res = {
                        target  = e:GetUnitName(),
                        hp      = e:GetHealth(),
                        frac    = J.GetHP(e),
                        dmg     = nDamage,
                        kills   = J.WillKillTarget(e, nDamage, DAMAGE_TYPE_MAGICAL, nCastPoint),
                        fires   = X.zuus_ArcExecuteFinishes(e, nDamage, nCastPoint),
                        bkb     = e:HasModifier('modifier_black_king_bar_immune'),
                    }
                end
            end
        end
    end)
    assert(ok, 'walking the branch on ' .. path .. ' raised: ' .. tostring(err))
    return res
end

--- What X.SkillsComplement actually ORDERS on a frame -- the function-altitude
--- reading, which is not the branch-altitude one (§0.3).
local function ordered(path, opts)
    opts = opts or {}
    local ability, target = '', ''
    local ok, err = pcall(function()
        local J, bot = rf.load(path, ZEUS)
        J.IsSoakCandidate = function(id) return opts.armed == true and id == 'zusarcexec' end
        J.IsModeTurbo     = function() return opts.turbo ~= false end
        local X = rf.load_hero(PART)
        local log = rf.record_actions(bot)
        pcall(X.SkillsComplement)
        for _, a in ipairs(log) do
            if a.fn:find('UseAbility') then
                local ab = a.args[1]
                ability = (type(ab) == 'table' and ab.GetName and ab:GetName() or '?')
                local t = a.args[2]
                if type(t) == 'table' and t.GetUnitName then target = t:GetUnitName() end
                break
            end
        end
    end)
    assert(ok, 'driving ' .. path .. ' raised: ' .. tostring(err))
    return ability, target
end

-- ---------------------------------------------------------------- section 1 --
-- The pin frame, and that every fact the lever turns on is REAL.

T['1.1 the pin carries a living level-10 Zeus with a rank-4 arc off cooldown'] = function()
    local rec = zeus_record(PIN)
    assert(rec, PIN .. ' does not carry a living Zeus')
    assert(rec.level == 10, 'pin Zeus is level ' .. tostring(rec.level) .. ', expected 10')
    local arc
    for _, a in ipairs(rec.abilities or {}) do if a.name == ARC then arc = a end end
    assert(arc, 'pin frame carries no ' .. ARC)
    assert(arc.level == 4, 'pin arc reads rank ' .. arc.level .. ', expected 4')
    assert(arc.cd == 0, 'pin arc reads cd ' .. arc.cd .. ', expected 0')
end

T['1.2 the pin is the execute the branch fires on, and the finish is false'] = function()
    local r = branch(PIN, { armed = false })
    assert(r, 'the shipped branch does not reach its body on ' .. PIN
        .. ' -- then this file is measuring something else')
    assert(r.target == 'npc_dota_hero_skeleton_king',
        'pin elects ' .. r.target .. ', expected the Wraith King')
    assert(r.hp == 241, 'pin target health is ' .. r.hp .. ', expected 241')
    assert(r.frac <= 0.2, 'pin target reads ' .. string.format('%.3f', r.frac)
        .. ' of max health; the shipped branch needs <= 0.2')
    assert(r.dmg == 180, 'arc_damage reads ' .. tostring(r.dmg) .. ' at rank 4, expected 180')
    assert(r.kills == false, 'J.WillKillTarget says the arc FINISHES the pin target. '
        .. 'Then the pin is no longer the frame this lever is about -- re-cut it, '
        .. 'do not relax this assertion.')
    assert(r.bkb == false, 'the pin target holds BKB; §0.2 says that instant is not usable')
end

T['1.3 the pin target is NOT spell-immune, unlike the instant §0.2 sets aside'] = function()
    local pin = branch(PIN, { armed = false })
    local imm = branch(IMMUNE, { armed = false })
    assert(pin and pin.bkb == false, 'the pin has become spell-immune')
    assert(imm, 'the shipped branch no longer reaches its body on ' .. IMMUNE)
    assert(imm.bkb == true, IMMUNE .. ' no longer carries the BKB instant §0.2 is about. '
        .. 'If the mock has learnt IsMagicImmune this frame should stop reaching the '
        .. 'branch at all -- re-read section 3 before touching this line.')
end

-- ---------------------------------------------------------------- section 2 --
-- Gate off and non-turbo are the shipped path, byte for byte.

T['2.1 gate off, the helper is the constant true'] = function()
    for _, path in ipairs({ PIN, CARVEOUT, IMMUNE }) do
        local r = branch(path, { armed = false })
        assert(r, 'shipped branch does not reach its body on ' .. path)
        assert(r.fires == true, 'gate off, X.zuus_ArcExecuteFinishes answered '
            .. tostring(r.fires) .. ' on ' .. path .. ' -- it must be the constant true')
    end
end

T['2.2 armed but NOT turbo is also the shipped path'] = function()
    local r = branch(PIN, { armed = true, turbo = false })
    assert(r and r.fires == true,
        'the id is armed outside turbo and the branch changed answer; the gate is turbo-only')
end

T['2.3 the id appears in the source exactly where the header says'] = function()
    local f = assert(io.open(SRC, 'r'))
    local src = f:read('*a')
    f:close()
    local n = 0
    for _ in src:gmatch("IsSoakCandidate%( 'zusarcexec' %)") do n = n + 1 end
    assert(n == 1, 'zusarcexec is gated at ' .. n .. ' call sites in ' .. SRC .. ', expected 1')
    assert(src:find('X%.zuus_ArcExecuteFinishes%( npcEnemy, nDamage, nCastPoint %)'),
        'the execute branch no longer calls the helper with the branch\'s own locals')
    -- The idiom armed borrows, six lines below, on the same local.
    assert(src:find('J%.WillKillTarget%( creep, nDamage, DAMAGE_TYPE_MAGICAL, nCastPoint %)'),
        'the laning branch no longer carries the call this lever copies. The header\'s '
        .. '"invents nothing" argument rests on that call existing in this file.')
end

-- ---------------------------------------------------------------- section 3 --
-- The harness defect found while sizing this lever (§0.2).  Recorded here, as a
-- ratchet, because it inflates this lever's domain and a great many others'.

T['3.1 the mock answers IsMagicImmune false on a hero holding BKB'] = function()
    local J, bot = rf.load(IMMUNE, ZEUS)
    local od
    for _, e in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == 'npc_dota_hero_obsidian_destroyer' then od = e end
    end
    assert(od, IMMUNE .. ' no longer puts an Obsidian Destroyer in Zeus\'s view')
    assert(od:HasModifier('modifier_black_king_bar_immune'),
        'the BKB modifier is gone from ' .. IMMUNE)
    -- The finding.  When this flips, the mock has been taught spell immunity:
    -- delete this section and re-take section 5's funnel, which will lose a row.
    assert(od:IsMagicImmune() == false, 'the mock now models spell immunity. '
        .. 'Good -- but section 5 quotes a funnel that counted this instant, and '
        .. '§0.2 of this file promises it was counted. Re-take both.')
    assert(J.CanCastOnNonMagicImmune(od) == true,
        'J.CanCastOnNonMagicImmune now vetoes the BKB hero on a fixture; same instruction')
end

-- ---------------------------------------------------------------- section 4 --
-- Direction at the BRANCH: armed is a subset of shipped, on the real frames.

T['4.1 armed silences the pin -- the cast whose finish is false'] = function()
    local shipped = branch(PIN, { armed = false })
    local arm     = branch(PIN, { armed = true })
    assert(shipped.fires == true, 'the shipped branch no longer fires on the pin')
    assert(arm.fires == false, 'armed still fires on the pin; the lever is a no-op there')
end

T['4.2 armed KEEPS the carve-out -- the cast whose finish is true'] = function()
    local rec = zeus_record(CARVEOUT)
    assert(rec, CARVEOUT .. ' does not carry a living Zeus')
    local r = branch(CARVEOUT, { armed = true })
    assert(r, 'the branch does not reach its body on ' .. CARVEOUT)
    assert(r.target == 'npc_dota_hero_skeleton_king',
        CARVEOUT .. ' elects ' .. r.target .. ', expected the Wraith King')
    assert(r.hp == 4, 'carve-out target health is ' .. r.hp .. ', expected 4')
    assert(r.kills == true, 'the arc no longer finishes a hero at four hit points')
    assert(r.fires == true, 'armed SILENCED the four-hit-point execute. '
        .. 'Then the lever is not a kill test, it is an off switch.')
end

T['4.3 armed never fires where shipped does not -- over the whole corpus'] = function()
    local added = {}
    for _, path in ipairs(corpus_paths()) do
        if zeus_record(path) then
            local s = branch(path, { armed = false })
            local a = branch(path, { armed = true })
            if a ~= nil and (s == nil or s.fires ~= true) then
                added[#added + 1] = path
            end
        end
    end
    assert(#added == 0, 'armed reaches the branch body on ' .. #added
        .. ' frame(s) where shipped does not: ' .. table.concat(added, ', ')
        .. '. A conjunct cannot do that; the shape has changed.')
end

-- ---------------------------------------------------------------- section 5 --
-- The funnel, and the two altitudes reported apart.
--
-- DELIBERATELY NOT A TOTAL-CORPUS RATCHET.  The counts below are asserted as
-- PROPERTIES (non-vacuity, subset, the two named frames), not as "the corpus
-- holds N files".  GH #705 / GH #709 are what that costs: three of this repo's
-- corpus-size ratchets went red across streams the day a stream added frames,
-- and the red said nothing about the lever it was guarding.  The exact funnel
-- as measured on 2026-09-10 is recorded here in prose, where growing the corpus
-- cannot redden it:
--
--     137 corpus files -> 57 with a living Zeus -> 42 with the arc castable
--     -> 4 reach the execute branch -> 3 once §0.2's BKB instant is removed
--     -> armed keeps 1 (the carve-out), cuts 2 (the pin, and the PA at 209hp
--        on f_260909_215227_zeus_ult_1008.lua where ConsiderR outbids it anyway)
--     function altitude: 2 frames change what Zeus orders, both SILENCED,
--        0 re-aimed.

T['5.1 the branch domain is non-vacuous on both sides'] = function()
    local fire, cut, keep = 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        if zeus_record(path) then
            local s = branch(path, { armed = false })
            if s and s.fires then
                fire = fire + 1
                local a = branch(path, { armed = true })
                if a and a.fires then keep = keep + 1 else cut = cut + 1 end
            end
        end
    end
    assert(fire >= 2, 'the shipped execute branch fires on ' .. fire
        .. ' corpus frame(s); with fewer than 2 this file cannot separate '
        .. '"armed narrows" from "armed is off"')
    assert(cut >= 1, 'armed cuts nothing on the corpus -- the lever has no domain')
    assert(keep >= 1, 'armed keeps nothing on the corpus -- it is an off switch, '
        .. 'not a kill test')
end

T['5.2 every frame armed cuts is one where the arc genuinely cannot finish'] = function()
    for _, path in ipairs(corpus_paths()) do
        if zeus_record(path) then
            local s = branch(path, { armed = false })
            local a = branch(path, { armed = true })
            if s and s.fires and a and a.fires ~= true then
                assert(s.kills == false, path .. ': armed cut a cast that J.WillKillTarget '
                    .. 'says DOES finish. The helper and the branch disagree.')
            end
        end
    end
end

T['5.3 at the function altitude the pin is silenced, not re-aimed'] = function()
    local sa, st = ordered(PIN, { armed = false })
    local aa, at = ordered(PIN, { armed = true })
    assert(sa == ARC and st == 'npc_dota_hero_skeleton_king',
        'shipped no longer orders the arc at the Wraith King on the pin (got '
        .. sa .. '/' .. st .. ')')
    assert(aa == '', 'armed orders ' .. aa .. ' on the pin. That is a RE-AIM, not a '
        .. 'silence -- §0.3 says to report the two apart, so update the header\'s '
        .. 'funnel rather than this assertion.')
end

T['5.4 the carve-out is untouched at the function altitude too'] = function()
    local sa, st = ordered(CARVEOUT, { armed = false })
    local aa, at = ordered(CARVEOUT, { armed = true })
    assert(sa == aa and st == at, 'armed changed what Zeus orders on the carve-out: '
        .. sa .. '/' .. st .. ' -> ' .. aa .. '/' .. at)
    assert(sa == ARC, 'shipped no longer orders the arc on the carve-out')
end

return T
