-- THE TWENTIETH WORLD ASSERTION: this corpus cannot tell whether a bot is
-- FIGHTING BACK -- and the three ways of asking do not fail the same way. Two
-- of them are silently FALSE on every frame, and the third is silently TRUE on
-- every frame. The third is the dangerous one, because a lever built on it
-- reports a clean, large, correctly-signed effect while measuring nothing.
--
-- WHY ANYONE WOULD ASK. GH #119 landed the gated `fieldcreep` clause (a creep
-- or neutral hit me in the last 3s => this is not a "hurt bot with nobody
-- anywhere near it", so do not stay in the field and regen). The replay desk
-- then bought its condition (a) twice -- 2026-08-23T02:36Z and 06:55Z -- and
-- came back with the same recommendation both times, in these words:
--
--   "判据要读方向,不要读量级 ... `GetAttackTarget() ~= nil`(或「同窗口内
--    自己打出过伤害」)一句就能把这一族排除干净"
--
-- The measurement behind it is real: on the armed leg, 41 of 90 neutral-damage
-- episodes DEALT more than they took, and the pinned frame
-- (f_260823_002103_wk_ancient_camp_634) is a level-11 skeleton_king who dealt
-- 2261 and took 2110 over 28 seconds and killed two golems. He is not being
-- chewed; he is jungling, and a veto pointed at him is pointed the wrong way.
--
-- So the lever is well-founded. What this file establishes is that it cannot
-- be WRITTEN yet -- not because the idea is wrong, but because every reader the
-- engine offers for it answers a mock default on 100% of this corpus, and one
-- of those defaults lies in the flattering direction.
--
-- THE THREE READERS, MEASURED OVER 966 LIVE HERO FRAMES / 104 FIXTURES:
--
--   bot:GetAttackTarget()            nil on 966/966   (handle getter, never
--                                                      installed by the loader)
--   J.IsAttacking(bot)             false on 966/966   (reads GetAnimActivity(),
--                                                      0 on every frame, while
--                                                      ACTIVITY_ATTACK is the
--                                                      auto-sentinel 1158)
--   GameTime() - bot:GetLastAttackTime() <= 3.0
--                                   TRUE on 966/966   <-- the trap
--
-- The third one is 0 - 0. GetLastAttackTime() is an uninstalled Get* (0), and
-- the mock's GameTime() is a constant 0 while the loader answers DotaTime()
-- with the real frame time -- the FOURTEENTH world assertion's cause (1),
-- tests/test_pingstamp_world_assertion.lua:55. This file does not re-discover
-- that clock; it records what that clock does at a NEW consumer, with the
-- opposite sign and a worse consequence.
--
-- THE CONSEQUENCE, MEASURED RATHER THAN ARGUED. `fieldcreep` turns the
-- situation off on 5 frames of this corpus (54 -> 49). Applying each candidate
-- as an exclusion -- "do not veto when I am fighting back" -- hands back:
--
--   GetAttackTarget() ~= nil         0 of 5   the lever is a no-op
--   J.IsAttacking(bot)               0 of 5   the lever is a no-op
--   GameTime() - GetLastAttackTime() 5 of 5   the veto is GONE, entirely
--
-- Read the third row the way its author would have: the census prints
-- "vetoed 5 -> 0", the jungling frames stop being vetoed, every fixture is
-- green, and the write-up says the direction fix works perfectly. It removed
-- the whole clause on every frame, including the two lane-creep frames it was
-- supposed to keep. That is a false green pointing the way the author hoped.
--
-- AND REPAIRING THE CLOCK DOES NOT FIX IT -- it only flips which way it lies.
-- Teaching the loader to answer GameTime() with the frame time (the repair
-- anyone reaches for first) makes the same clause FALSE on 966/966, and it
-- then hands back 0 of 5: a no-op instead of a wipe. Both readings are
-- structural. Neither is a measurement of the frame. That is asserted below as
-- a probe, not argued -- same method as the fourteenth assertion's own probe.
--
-- THE PINNED FRAME CANNOT EXERCISE THE CLAUSE EITHER, AND FOR A THIRD REASON.
-- f_260823_002103_wk_ancient_camp_634 is at 817/1307 = 62.5% HP, and
-- J.IsFieldRegenSituation's own band is `nHP < 0.18 or nHP > 0.55 => false`.
-- The frame leaves the function four clauses ABOVE `fieldcreep`. It is a real
-- frame and it is the right frame for what it was also filed under (GH #137's
-- level ladder, landed as `campgrade`), but it is not a frame this family can
-- be pinned on. The ceiling is read out of the shipped source below, not
-- restated here.
--
-- WHAT THIS FILE DOES NOT CLAIM.
--   * NOT that the replay desk's 45.6% is wrong. It is measured on .dem combat
--     logs, which carry outgoing damage; the fixture format does not. The two
--     do not disagree -- only one of them can see the quantity.
--   * NOT that a direction clause would be a bad fix. It says only that this
--     corpus cannot grade one, and names the cheapest unblock: make_fixture.py
--     already reads the combat log rows the replay desk quoted
--     ("DAMAGE skeleton_king -> rock_golem 228"), so an outgoing-damage list
--     beside the existing `recent_damage` would make all three readings honest.
--   * NOT a new finding about GetNearbyCreeps. The loader declares the empty
--     creep world itself (tests/mock/replay_fixture.lua:456-474); it is
--     re-measured here only because a "read the camp instead" rewrite is the
--     obvious second attempt and lands in the same hole.
--
-- VERDICT: DO NOT WRITE the direction clause on this corpus. The ratchet at the
-- bottom fails the moment somebody adds one of these three readers to
-- J.IsFieldRegenSituation, and points them here.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local JMZ = 'bots/FunLib/jmz_func.lua'
local WK_FIX = 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua'
local WK_HERO = 'npc_dota_hero_skeleton_king'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- ------------------------------------------------------------- the census --

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_fightback_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line)')
    local c, rows = {}, {}
    for line in text:gmatch('[^\n]+') do
        local k, v = line:match('^C ([%w_]+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        local f, h, at, idle, atk, idlefix =
            line:match('^VROW (%S+) (%S+) (%d) (%d) (%d) (%d)$')
        if f then
            rows[#rows + 1] = { fix = f, hero = h, at = at == '1', idle = idle == '1',
                atk = atk == '1', idlefix = idlefix == '1' }
        end
    end
    return c, rows
end

local C, VROWS = sweep()

tests['census: the corpus these numbers are quoted from'] = function()
    cs.corpus(C.fixtures, 'fightback corpus')
    cs.ratchet(C.live, 966, 'live hero frames')
    -- The lookback is read out of bots/ by the sweep, so it is a fact about the
    -- shipped clause and stays an equality.
    assert(C.lookback_x10 == 30,
        'the sweep read a lookback other than 3.0 out of the source; got '
        .. tostring(C.lookback_x10))
end

-- ------------------------------- the two readers that are FALSE everywhere --

tests['GetAttackTarget() is nil on every live hero frame'] = function()
    cs.universal(C.at_nil, C.live, 'GetAttackTarget() == nil', cs.FLOOR)
    assert(C.at_REAL == 0, string.format(
        '%d frames now answer GetAttackTarget() -- the loader gained a reader, '
        .. 're-read this file: the direction lever may have become writable', C.at_REAL))
end

tests['J.IsAttacking is false on every live hero frame, and why'] = function()
    cs.universal(C.atk_false, C.live, 'J.IsAttacking(bot) == false', cs.FLOOR)
    -- The mechanism, so the zero is not mistaken for "nobody was attacking".
    cs.universal(C.anim_zero, C.live, 'GetAnimActivity() == 0', cs.FLOOR)
    local _, bot = rf.load(WK_FIX, WK_HERO)
    assert(bot:GetAnimActivity() == 0, 'GetAnimActivity is no longer the Get* default')
    assert(ACTIVITY_ATTACK ~= 0,
        'ACTIVITY_ATTACK collapsed onto the Get* default -- J.IsAttacking would '
        .. 'now read TRUE on every frame instead of false')
    -- The shipped helper this file speaks about must still be the one measured.
    local src = read_file(JMZ)
    assert(src:find('nAnimActivity ~= ACTIVITY_ATTACK', 1, true),
        'J.IsAttacking no longer reads GetAnimActivity against ACTIVITY_ATTACK')
end

-- -------------------------------- the reader that is TRUE everywhere -------

tests['the "did I attack recently" spelling is TRUE on every live hero frame'] = function()
    cs.universal(C.idle_TRUE, C.live,
        'GameTime() - GetLastAttackTime() <= 3.0', cs.FLOOR)
    assert(C.idle_false == 0, string.format(
        'the trap reading is no longer universal (%d frames read false) -- re-read this file',
        C.idle_false))
    -- 0 - 0. Both halves pinned, because either one alone would be survivable.
    cs.universal(C.lat_zero, C.live, 'GetLastAttackTime() == 0', cs.FLOOR)
    local _, bot = rf.load(WK_FIX, WK_HERO)
    assert(GameTime() == 0,
        'the loader now answers GameTime(); got ' .. tostring(GameTime()))
    assert(math.abs(DotaTime() - GameTime()) > 600,
        'the two clocks no longer disagree by the whole game -- the fourteenth '
        .. 'world assertion moved, and this file quotes it')
    assert(bot:GetLastAttackTime() == 0, 'GetLastAttackTime is no longer the Get* default')
    -- The shape is not hypothetical: bots/ already ships it.
    local src = read_file(JMZ)
    assert(src:find('GameTime() - bot:GetLastAttackTime()', 1, true),
        'the shipped GameTime()-GetLastAttackTime() shape this file quotes is gone')
end

-- --------------------------------- what each candidate DOES to the domain --

tests['the fieldcreep domain the exclusions would be applied to'] = function()
    cs.ratchet(C.situation, 54, 'situation frames')
    cs.ratchet(C.situation_armed, 49, 'armed situation frames')
    cs.ratchet(C.vetoed, 5, 'frames fieldcreep vetoes')
    assert(C.situation - C.vetoed == C.situation_armed,
        'the armed domain must be the unarmed one minus exactly the vetoes')
    assert(C.IMPOSSIBLE_widened == 0,
        'the appended clause turned a frame ON -- it can only return false')
    assert(#VROWS == C.vetoed, 'every vetoed frame must have emitted a row')
end

tests['two of the three exclusions are no-ops: 0 of the vetoed frames'] = function()
    assert(C.vetoed_excl_at == 0,
        'GetAttackTarget() exclusion now fires on ' .. tostring(C.vetoed_excl_at)
        .. ' vetoed frames -- it used to be structurally 0')
    assert(C.vetoed_excl_atk == 0,
        'J.IsAttacking exclusion now fires on ' .. tostring(C.vetoed_excl_atk)
        .. ' vetoed frames -- it used to be structurally 0')
    for _, r in ipairs(VROWS) do
        assert(not r.at, r.fix .. ' / ' .. r.hero .. ': GetAttackTarget() answered')
        assert(not r.atk, r.fix .. ' / ' .. r.hero .. ': J.IsAttacking answered')
    end
end

tests['the third exclusion wipes the clause: all of the vetoed frames'] = function()
    -- THE FINDING. Not "it does nothing" -- it does everything, on every frame,
    -- for no reason connected to the frame.
    cs.universal(C.vetoed_excl_idle, C.vetoed,
        'the idle-time exclusion hands back the vetoed frames', 1)
    for _, r in ipairs(VROWS) do
        assert(r.idle, r.fix .. ' / ' .. r.hero .. ': the idle exclusion did NOT fire')
    end
    -- Stated as the number the census would have printed, because that is the
    -- number a reader would have believed: 5 vetoes -> 0.
    assert(C.vetoed - C.vetoed_excl_idle == 0,
        'the wipe is no longer total; the false green this file names has changed shape')
end

tests['repairing the clock flips the lie instead of removing it'] = function()
    -- GameTime() := DotaTime() -- the obvious repair. Same clause, same frames.
    cs.universal(C.idlefix_false, C.live,
        'with an honest clock the idle spelling is FALSE everywhere', cs.FLOOR)
    assert(C.vetoed_excl_idlefix == 0,
        'the repaired clock now hands back ' .. tostring(C.vetoed_excl_idlefix)
        .. ' frames -- if the loader also learned GetLastAttackTime, this lever '
        .. 'became writable and this file must be re-read')
    for _, r in ipairs(VROWS) do
        assert(not r.idlefix, r.fix .. ' / ' .. r.hero .. ': repaired clock answered TRUE')
    end
end

-- ------------------------------------------- the second attempt, pre-empted --

tests['the creep world is empty, so "read the camp instead" lands in the same hole'] = function()
    -- Not a new finding: tests/mock/replay_fixture.lua declares it. Measured
    -- here because it is the obvious rewrite once the three readers above fail.
    -- Zero UNITS summed over 966 frames, not "the counter was never touched":
    -- the sweep adds a list length on every frame, so the key exists and is 0.
    assert(C.neutralcreeps == 0, 'GetNearbyNeutralCreeps now returns units: '
        .. tostring(C.neutralcreeps))
    assert(C.enemycreeps == 0, 'GetNearbyCreeps(_, true) now returns units: '
        .. tostring(C.enemycreeps))
    assert(C.allycreeps == 0, 'GetNearbyCreeps(_, false) now returns units: '
        .. tostring(C.allycreeps))
    local loader = read_file('tests/mock/replay_fixture.lua')
    assert(loader:find('no creeps or summons', 1, true)
        or loader:find('NO UNITS AT ALL', 1, true),
        'the loader no longer declares its empty creep world -- re-read this claim')
end

-- ------------------------------------------------ the pinned frame's own bar --

tests['the pinned WK frame is above the situation band, so it cannot pin this'] = function()
    local J, bot = rf.load(WK_FIX, WK_HERO)
    J.IsSoakCandidate = function() return false end

    -- The ceiling comes out of the shipped source, not out of this file -- and
    -- it is read out of THIS FUNCTION'S BODY, not out of the file. jmz_func
    -- carries TWO `if nHP < a or nHP > b then return false end` lines
    -- (J.ShouldFieldBuyRegen's sibling at 0.18/0.75 comes first), so an
    -- unscoped source read silently grades this frame against the wrong band.
    -- That is not hypothetical: the first draft of this assertion did exactly
    -- that and reported a ceiling of 0.75, which would have made the whole
    -- verdict below read the other way.
    local src = read_file(JMZ)
    local body = src:match('function J%.IsFieldRegenSituation%( bot %)(.-)\nend\n')
    assert(body, 'J.IsFieldRegenSituation is no longer a plain named function')
    local lo, hi = body:match('if nHP < ([%d%.]+) or nHP > ([%d%.]+) then return false end')
    assert(lo and hi, 'the field-regen HP band is no longer a literal pair')
    lo, hi = tonumber(lo), tonumber(hi)

    local hp = J.GetHP(bot)
    assert(math.abs(hp - 817 / 1307) < 1e-6,
        'the pinned frame is no longer 817/1307; got ' .. tostring(hp))
    assert(hp > hi, string.format(
        'the WK frame (%.4f) is inside the band (%.2f..%.2f) now -- it became '
        .. 'usable for this family and this verdict must be re-read', hp, lo, hi))

    -- It leaves the function four clauses ABOVE fieldcreep, so arming the gate
    -- changes nothing here. Both readings asserted: the exclusion is not what
    -- makes it false.
    assert(J.IsFieldRegenSituation(bot) == false, 'unarmed: expected false (HP ceiling)')
    J.IsSoakCandidate = function(id) return id == 'fieldcreep' end
    assert(J.IsFieldRegenSituation(bot) == false, 'armed: expected false (same ceiling)')
    J.IsSoakCandidate = function() return false end

    -- And the creep clause itself WOULD have fired, which is why the frame
    -- reads like a fieldcreep case at a glance. Granite/rock golem rows, real.
    assert(bot:WasRecentlyDamagedByCreep(3.0),
        'the pinned frame lost its neutral damage history')
    assert(J.IsModeTurbo(), 'the pinned frame is not Turbo; the whole family is turbo-only')
end

-- --------------------------------------------------------------- the ratchet --

tests['ratchet: no direction reader has been added to the situation predicate'] = function()
    -- The verdict above is DO NOT WRITE. This turns red the moment somebody
    -- writes one anyway, and the message is the pointer back here. It is NOT a
    -- veto: if the loader learns to answer these, land the clause and delete
    -- this test in the same commit, saying which reader became honest.
    local src = read_file(JMZ)
    local body = src:match('function J%.IsFieldRegenSituation%( bot %)(.-)\nend\n')
    assert(body, 'J.IsFieldRegenSituation is no longer a plain named function')
    for _, reader in ipairs({ 'GetAttackTarget', 'GetLastAttackTime',
                              'IsAttacking', 'GetNearbyNeutralCreeps', 'GetNearbyCreeps' }) do
        assert(not body:find(reader, 1, true), string.format(
            'J.IsFieldRegenSituation now reads %s -- on this corpus that reader is '
            .. 'a mock default on 966/966 frames (see tests/test_fightback_world_'
            .. 'assertion.lua). Either the loader learned to answer it, in which '
            .. 'case delete this assertion and say so, or the clause is untestable.',
            reader))
    end
end

return tests
