-- [ratchet] Strategy desk 2026-08-30 -- GH #333, the discriminator the
-- `tpreach` (a) verdict was declared INDETERMINATE for want of.
--
-- WHAT #333 ASKED
-- ---------------
-- The replay desk measured `tpreach` condition (a) on W28 and returned
-- INDETERMINATE (domain 6/1010, the 4 armed-leg rows all from ONE game, the two
-- physical-side strata opposite-signed). It then published one frame as material
-- and declined to rule it BUGGY, with a reason it stated plainly:
--
--   * lion, `990f5c/20260830_063340_slot1`, armed leg (s1850, radiant=armed),
--     t=657.0, hp=0.90, death_prophet at d=705, DP attack range 600 => reach
--     750, so `705 <= 750` sits squarely in the band `tpreach` widens for;
--   * BUT the dump has no bot-mode column, so "the RETREAT branch never asks
--     this predicate" (expected residue) and "the predicate should have fired
--     and did not" (BUGGY) are, in its words, indistinguishable in the data.
--
-- #333 §3 therefore proposed two routes: (1) swap to the fixture route and pin
-- that frame; (2) if staying on batch, get a mode field from harness -- "that is
-- another line".
--
-- ⭐ THE RULING THIS FILE PINS: THE MODE OPERAND IS NOT NEEDED.
-- ------------------------------------------------------------
-- The retreat branch cannot press a TP at hp = 0.90 -- not for this frame's
-- other operands, but for ANY assignment of them. It holds exactly three TP
-- presses, and all three are HP-capped:
--
--     retreat:1   botHP < 0.19
--     retreat:2   botHP < 0.15 + 0.24 * nEnemyCount,
--                 AND nEnemyCount <= (botHP < 0.4 and 2 or 3)
--     retreat:3   botHP < 0.34  OR  botHP + botMP < 0.43
--
-- retreat:2 is the only one that scales, and it scales with the very quantity
-- its own second conjunct caps. At botHP >= 0.4 that cap is 3, so its bar can
-- never exceed 0.15 + 0.24*3 = **0.87**. retreat:3's disjunct is closed by the
-- range of the operand itself: botMP >= 0 makes `botHP + botMP < 0.43` strictly
-- weaker than `botHP < 0.43`. So the supremum over the whole family is
--
--     sup = max(0.19, 0.87, 0.43) = 0.87
--
-- => **hp >= 0.87 closes every retreat TP press in the tree.** #333's frame
-- reads hp = 0.90. The retreat-residue world is shut by arithmetic, so the
-- press came from a path that DOES consult `J.CanEnemyInterruptTpChannel`, and
-- on the armed leg at d=705 that predicate answers TRUE ([drive D1]) --
-- i.e. it should have vetoed and did not.
--
-- The bound is conservative in the right direction: [arith A1] grants EVERY
-- non-HP conjunct (damage recency, juke, flask, modifiers, fountain distance,
-- hero name) as satisfied. Closing the branch even with all of those given is
-- strictly stronger than closing it on this frame's actual values.
--
-- ⚠️ THE ONE LIMIT, AND IT IS THE NEXT ROUND'S WHOLE JOB.
-- The 0.90 is a 1 Hz sample. #333's own table puts the press at t=657.0
-- between a 656.5 row (hp 0.90) and a 657.5 row (hp 0.69, after DP's Carrion
-- Swarm at 656.3). **0.69 < 0.87** -- so if the true press-instant HP was the
-- later sample, retreat:2 reopens (it needs nEnemyCount = 3). The ruling is
-- therefore conditional on ONE already-dumped column read at the press instant,
-- against the constant this file pins. That is a strictly smaller ask than
-- #333 §3.2's harness field: **hp and nEnemyCount are columns the dump already
-- has; mode is not.** [control C1] makes the knife edge explicit so nobody
-- reads A1 as "retreat can never TP".
--
-- ⭐⭐ AND WHY #333 §3.1'S FIXTURE ROUTE DOES NOT BUY THIS.
-- A fixture pinned on that frame would drive `J.CanEnemyInterruptTpChannel` and
-- get TRUE armed -- in BOTH worlds, because the predicate's answer does not
-- depend on whether its caller asks it. It would report green while carrying no
-- information about the ambiguity it was built to settle: the same
-- reports-green-because-it-is-not-load-bearing family as charter 0FOG (甲),
-- 0GEOM M5 and 0SENSE M12. Discriminating needs the CALL SITE driven with a
-- real mode, and [corpus C3] measures that the corpus cannot do that today:
-- `GetActiveMode` is called 360x in bots/, defined nowhere in tests/mock/, and
-- carried by 0 of 107 fixtures. **The fixture route does not dodge the missing
-- operand; it inherits it.** The arithmetic above is what dodges it.
--
-- WHAT THIS FILE DOES NOT CLAIM
-- -----------------------------
-- * It does not re-derive or dispute #333's 6/1010, its strata, or its
--   INDETERMINATE verdict -- those are readings, and rule 4(i) already refuses
--   the opposite-signed strata as an effect size. This file only reopens the
--   ONE frame #333 published as material.
-- * It does not claim `tpreach` should be promoted or dropped. (b)/(c) are not
--   the strategy desk's to buy, and one frame is not condition (a).
-- * It does not model the OTHER two consulting call sites' own gates
--   (`GetRescueTpTarget` needs lf_rescue, the mid/sup response TP needs
--   midtp/suptp). It does not need to: both `return nil` when their gate is
--   off, so an unarmed one cannot have produced a press at all. Either the
--   press came from the ungated non-retreat gate at :5239, or from a gated
--   path that was armed -- and all three consult the predicate.
-- * hp = 0.90 and d = 705 are #333's published numbers, cited not re-derived.
--
-- MUTATION RECORD (run 2026-08-30; 11 patches, 11 CAUGHT, 0 SURVIVED)
-- --------------------------------------------------------------------
-- Patches on THIS FILE's model (what [arith A1] / [control C1] guard):
--   M1  model retreat:2 bar 0.24 -> 0.30     => A1 + C1 red                  CAUGHT
--   M2  model retreat:2 enemy cap 3 -> 4     => A1 red (sup -> 1.11)         CAUGHT
--   M3  model retreat:1 bar 0.19 -> 0.95     => A1 + C1 red                  CAUGHT
--   M4  model retreat:3 bar 0.34 -> 0.90     => A1 + C1 red                  CAUGHT
--   M5  model always-false (`return false`)  => C1 red, **A1 GREEN**         CAUGHT
-- Patches on the TREE (what the [source]/[drive] assertions guard):
--   M6  scan 1200 -> 700 (jmz_func)          => D1 red (armed stops firing)  CAUGHT
--   M7  reach `+150` -> `+0` (jmz_func)      => D1 red (705 > 600)           CAUGHT
--   M8  drop `nMode ~= BOT_MODE_RETREAT`     => S3 red                       CAUGHT
--   M9  add a CanEnemyInterruptTpChannel
--       call inside the retreat block        => S1 red                       CAUGHT
--   M10 TREE retreat:2 bar 0.24 -> 0.30,
--       model left alone                     => S2 red, A1 GREEN             CAUGHT
--   M11 add a second tpsafe2 call site       => S1 + S2 + S3 red             CAUGHT
--
-- ⚠️ M5 is the one that matters, and its result is the reason [control C1]
-- exists: a model answering "no" to everything leaves **[arith A1] fully
-- green**. The arithmetic half of this file is load-bearing only because C1
-- makes it prove a press IS reachable just below the bound.
-- ⚠️ M10 is the division of labour, stated as a measurement: A1 runs on the
-- model in this file, NOT on the tree, so a tree-side bar change is caught by
-- [source S2] alone. If S2 is ever deleted, A1 keeps passing while describing
-- a tree that no longer exists.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SRC = 'bots/ability_item_usage_generic.lua'
local ss = require('mock.soak_side')
local SIDE_PATH = ss.PATH                          -- gitignored, farm-only

-- #333's published frame, cited verbatim. Named so a reader can see which
-- numbers are the issue's and which are the tree's.
local FRAME_HP      = 0.90    -- lion, t=657.0, armed leg
local FRAME_DIST    = 705     -- d(death_prophet)
local DP_ATK_RANGE  = 600     -- death prophet, => reach 750
local SHIPPED_SCAN  = 700     -- the unarmed scan radius

local tests = {}

-- ---------------------------------------------------------------------------
-- the shipped retreat arithmetic, restated once
-- ---------------------------------------------------------------------------
-- Every NON-HP conjunct is granted (see header). These are exactly the three
-- HP-bearing conditions at bots/ability_item_usage_generic.lua:5553 / :5588 /
-- :5627, and [source S2] pins their constants against the tree so this model
-- cannot drift away from what ships.
local function retreat1(hp)          return hp < 0.19 end
local function retreat2(hp, nEnemy)
    return nEnemy <= (hp < 0.4 and 2 or 3) and hp < (0.15 + 0.24 * nEnemy)
end
local function retreat3(hp, mp)      return hp < 0.34 or (hp + mp) < 0.43 end

local function any_retreat_tp(hp, nEnemy, mp)
    return retreat1(hp) or retreat2(hp, nEnemy) or retreat3(hp, mp)
end

local function read_source()
    local f = assert(io.open(SRC, 'r'), 'cannot read ' .. SRC)
    local s = f:read('*a')
    f:close()
    return s
end

-- Long-bracket blocks first: a single-line `--[[ ... ]]` is already destroyed by
-- per-line `--` stripping. Order matters (charter 0CONJ self-harm B).
local function code_only(src)
    local s = src:gsub('%-%-%[%[.-%]%]', '')
    local out = {}
    for line in (s .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s, e = hay:find(needle, at, true)
        if s == nil then return n end
        n, at = n + 1, e + 1
    end
end

-- ⚠️ ANCHOR CHOICE, AND THE FIRST DRAFT'S SELF-HARM.
-- The obvious anchor for "the non-retreat gate" is `nMode ~= BOT_MODE_RETREAT`.
-- It is NOT unique in this file -- there is a second one at the mode-desire
-- helper (~:4029), and it comes FIRST. Anchoring on it made [source S1] span
-- from :4284 to :5668, swallowing the real gate at :5239, so the retreat block
-- "called the tpsafe2 wrapper" and S1/S3 both went red on a healthy tree.
-- The unique anchor is the wrapper CALL, and TPSAFE2_ONCE pins that uniqueness
-- so the next person to add a second call site is told, rather than silently
-- re-widening the span.
local TPSAFE2 = 'J.ShouldNotStartInterruptibleTp( bot )'

local function tpsafe2_gate_at(src)
    assert(count(src, TPSAFE2) == 1,
        SRC .. ' no longer has EXACTLY ONE ' .. TPSAFE2 .. ' call -- every ' ..
        'source assertion in this file anchors on its uniqueness')
    return (src:find(TPSAFE2, 1, true))
end

-- The retreat block of the TP think: it opens at the first
-- `nMode == BOT_MODE_RETREAT` AFTER the (unique) tpsafe2 gate and closes at the
-- unique `nMode == BOT_MODE_FARM`.
local function retreat_block(src)
    local i = tpsafe2_gate_at(src)
    local j = src:find('nMode == BOT_MODE_FARM', i, true)
    assert(j ~= nil, SRC .. ' no longer has the FARM branch after the retreat block')
    local k = src:find('nMode == BOT_MODE_RETREAT', i, true)
    assert(k ~= nil and k < j, 'the retreat block moved out from between the two anchors')
    return src:sub(k, j)
end

-- ---------------------------------------------------------------------------
-- [arith A1] the supremum: hp >= 0.87 closes every retreat TP press
-- ---------------------------------------------------------------------------
tests['[arith A1] no retreat TP press is reachable at hp >= 0.87, for ANY operands'] = function()
    local violations = {}
    -- 0.87 .. 1.00 in 0.01 steps, every legal enemy count, mp across its range.
    for hpi = 87, 100 do
        local hp = hpi / 100
        for nEnemy = 0, 5 do
            for mpi = 0, 100, 5 do
                if any_retreat_tp(hp, nEnemy, mpi / 100) then
                    violations[#violations + 1] =
                        ('hp=%.2f n=%d mp=%.2f'):format(hp, nEnemy, mpi / 100)
                end
            end
        end
    end
    assert(#violations == 0,
        'a retreat TP press is reachable at hp >= 0.87: ' ..
        table.concat(violations, ', ', 1, math.min(#violations, 5)))

    -- and the frame #333 published is inside that closed region
    assert(FRAME_HP >= 0.87,
        'the cited frame hp must be inside the closed region for the ruling to apply')
    for nEnemy = 0, 5 do
        for mpi = 0, 100, 5 do
            assert(not any_retreat_tp(FRAME_HP, nEnemy, mpi / 100),
                ('#333 frame hp=%.2f still admits a retreat TP at n=%d'):format(FRAME_HP, nEnemy))
        end
    end
end

-- ---------------------------------------------------------------------------
-- [control C1] the bound is a knife edge, not a vacuous model
-- ---------------------------------------------------------------------------
-- Without this, M5 (a model that answers false to everything) makes A1 green.
-- It also states, as an assertion, the limit the header spends a paragraph on:
-- the 657.5 sample DOES reopen retreat:2.
tests['[control C1] just below the bound a retreat TP IS reachable (0.87 is tight)'] = function()
    assert(retreat2(0.86, 3),
        'hp=0.86 with 3 enemies must satisfy retreat:2 -- otherwise A1 is vacuous')
    assert(any_retreat_tp(0.86, 3, 1.00),
        'the family must admit at least one press just below the bound')

    -- the honest limit, pinned: #333's NEXT 1 Hz sample is not excluded.
    assert(not any_retreat_tp(0.90, 3, 1.00),
        'the 656.5 sample (hp 0.90) is excluded')
    assert(any_retreat_tp(0.69, 3, 1.00),
        'the 657.5 sample (hp 0.69) is NOT excluded -- the ruling needs the ' ..
        'press-instant hp, and this is exactly why')

    -- ... and it is nEnemyCount that carries it, so that column is owed too.
    assert(not any_retreat_tp(0.69, 2, 1.00),
        'at hp 0.69 the reopening needs n=3; n=2 stays closed, so the next ' ..
        'round owes BOTH columns, not just hp')
end

-- ---------------------------------------------------------------------------
-- [source S1] the retreat block never consults the tpreach predicate
-- ---------------------------------------------------------------------------
tests['[source S1] retreat block: 3 TP presses, all to fountain, 0 interrupt tests'] = function()
    local blk = code_only(retreat_block(code_only(read_source())))

    assert(count(blk, 'CanEnemyInterruptTpChannel') == 0,
        'the retreat block now calls the tpreach predicate -- the whole ' ..
        '"expected residue" world in GH #333 changes shape; re-read this file')
    assert(count(blk, 'ShouldNotStartInterruptibleTp') == 0,
        'the retreat block now calls the tpsafe2 wrapper -- same')

    -- exactly three presses, and every one of them goes to the fountain. The
    -- destination half independently corroborates #333's own "落点不回家"
    -- observation on the cited frame.
    assert(count(blk, 'BOT_ACTION_DESIRE_HIGH') == 3,
        'the retreat block no longer holds exactly 3 TP presses -- the ' ..
        'supremum in [arith A1] is enumerated over those three and must be redone')
    assert(count(blk, 'J.GetTeamFountain()') == 3,
        'a retreat TP press no longer targets the fountain -- the destination ' ..
        'corroboration in GH #333 no longer follows')
end

-- ---------------------------------------------------------------------------
-- [source S2] the model's constants are the tree's constants
-- ---------------------------------------------------------------------------
tests['[source S2] the three HP bars in the tree match the model in this file'] = function()
    local blk = code_only(retreat_block(code_only(read_source())))

    assert(blk:find('botHP < 0.19', 1, true), 'retreat:1 bar moved off 0.19')
    assert(blk:find('botHP < ( 0.15 + 0.24 * nEnemyCount )', 1, true),
        'retreat:2 bar moved off `0.15 + 0.24 * nEnemyCount`')
    assert(blk:find('nEnemyCount <= ( botHP < 0.4 and 2 or 3 )', 1, true),
        'retreat:2 enemy cap moved -- it is what bounds the bar at 0.87')
    assert(blk:find('( botHP < 0.34 or botHP + botMP < 0.43 )', 1, true),
        'retreat:3 bar moved off 0.34 / 0.43')

    -- nEnemyCount really is a count of ENEMY heroes, so capping it at 3 caps the
    -- bar at 0.87. If it ever became an ally or total count the arithmetic in
    -- A1 would still run and would still be green, for the wrong reason.
    local whole = code_only(read_source())
    assert(whole:find('local nEnemyCount = X.GetNumHeroWithinRange( 1600 )', 1, true),
        'nEnemyCount is no longer X.GetNumHeroWithinRange(1600)')
    local i = whole:find('function X.GetNumHeroWithinRange', 1, true)
    assert(i ~= nil, 'X.GetNumHeroWithinRange is gone')
    assert(whole:find('GetTeamPlayers( GetOpposingTeam() )', i, true),
        'X.GetNumHeroWithinRange no longer counts the OPPOSING team')
end

-- ---------------------------------------------------------------------------
-- [source S3] the non-retreat gate -- the path that DOES consult tpreach
-- ---------------------------------------------------------------------------
tests['[source S3] the tpsafe2 gate is scoped to non-retreat and is ungated'] = function()
    local whole = code_only(read_source())
    local i = tpsafe2_gate_at(whole)
    -- the scoping sits immediately ABOVE the call; look back, not forward.
    local seg = whole:sub(math.max(1, i - 120), i + #TPSAFE2)
    assert(seg:find('nMode ~= BOT_MODE_RETREAT', 1, true),
        'the tpsafe2 call is no longer scoped to non-retreat modes -- if it now ' ..
        'runs on the retreat branch too, the two worlds in GH #333 collapse and ' ..
        'the [arith A1] ruling is unnecessary rather than wrong')
    assert(not seg:find('IsSoakCandidate', 1, true),
        'this call site is PROMOTED (tpsafe2) and must stay ungated -- if it ' ..
        'grew a gate, "the press must have consulted the predicate" no longer holds')
end

-- ---------------------------------------------------------------------------
-- [drive D1] the cited frame's operands through the REAL predicate
-- ---------------------------------------------------------------------------
-- The mock honours the requested radius literally: an enemy is returned only
-- when the scan actually covers where it stands. A mock that ignored `r` would
-- make both halves below pass for the wrong reason.
local function fresh_jmz(enemyDist, atkRange)
    api.reset_modules()
    local enemy = api.MakeHero('npc_dota_hero_death_prophet', {
        GetTeam = 3,
        GetLocation = api.Vector(enemyDist, 0, 0),
        GetExtrapolatedLocation = api.Vector(enemyDist, 0, 0),  -- standing still
        GetAttackRange = atkRange,
        GetHealth = 600,
        CanBeSeen = true,
    })
    local bot = api.MakeHero('npc_dota_hero_lion', {
        GetNearbyHeroes = function(_, r, bEnemy)
            if bEnemy and r >= enemyDist then return { enemy } end
            return {}
        end,
    })
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    return J, bot
end

-- [GH #365 §3 / GH #229] tests/mock/soak_side.lua owns the switch: it reads
-- the write back, refuses to clobber a file it did not create, and re-reads
-- the switch after the case body -- so a concurrent `rm` is reported as itself
-- instead of as the unarmed `CanEnemyInterruptTpChannel == false` this file
-- asserts three lines above the published failure.
local function with_candidate(fn)
    ss.with_candidate('tpreach', fn)
end

tests['[drive D1] GH #333 frame: blind unarmed, FIRES armed -- so it should have vetoed'] = function()
    -- the band membership, as arithmetic, before driving anything
    assert(FRAME_DIST > SHIPPED_SCAN,
        'the cited frame must be OUTSIDE the shipped 700 scan or there is no band')
    assert(FRAME_DIST <= DP_ATK_RANGE + 150,
        'the cited frame must be INSIDE the enemy reach or tpreach would not fire either')

    local J, bot = fresh_jmz(FRAME_DIST, DP_ATK_RANGE)
    assert(J.CanEnemyInterruptTpChannel(bot) == false,
        'unarmed, d=705 is in the structural blind band -- this is the defect')

    with_candidate(function()
        local J2, bot2 = fresh_jmz(FRAME_DIST, DP_ATK_RANGE)
        assert(J2.CanEnemyInterruptTpChannel(bot2) == true,
            'ARMED, d=705 <= reach 750 must veto the TP. Combined with [arith A1] ' ..
            'closing the retreat world at hp 0.90, the armed-leg press GH #333 ' ..
            'published is a genuine miss, not expected residue')
    end)
end

-- ---------------------------------------------------------------------------
-- [control C2] the comment stripper is what separates comment from code
-- ---------------------------------------------------------------------------
-- jmz_func's header for this predicate quotes the strike clause verbatim, and
-- this file's own header quotes all three retreat bars. A raw `find` would match
-- those. (GH #300 / charter 0GEOM M5 paid for this once already.)
tests['[control C2] source assertions run on code, not on prose'] = function()
    local raw = read_source()
    assert(raw:find('--撤退', 1, true), 'the retreat prose marker is gone from the raw file')
    assert(not code_only(raw):find('--撤退', 1, true),
        'code_only failed to strip a line comment -- every source assertion above ' ..
        'is unfalsifiable until this is fixed')
    assert(code_only('--[[ botHP < 0.19 ]]'):find('botHP', 1, true) == nil,
        'code_only failed to strip a single-line long-bracket comment')
end

-- ---------------------------------------------------------------------------
-- [corpus C3] the fixture route cannot supply the mode operand today
-- ---------------------------------------------------------------------------
-- This is the measurement behind "#333 §3.1 inherits the blocker rather than
-- dodging it". It is deliberately stated as EXISTENCE, not as a headcount, so
-- adding fixtures does not turn it red -- only actually plumbing the operand
-- does, and that is the day the fixture route becomes available.
tests['[corpus C3] GetActiveMode: called in bots/, defined in no mock, carried by no fixture'] = function()
    local function slurp(path)
        local f = io.open(path, 'r')
        if f == nil then return nil end
        local s = f:read('*a')
        f:close()
        return s
    end

    -- it is load-bearing in the tree ...
    local gen = assert(slurp(SRC))
    assert(gen:find('bot:GetActiveMode()', 1, true),
        'the TP think no longer reads GetActiveMode -- the premise of this case is gone')

    -- ... and absent from the mock layer, so a fixture cannot drive a call site
    -- whose scoping depends on it.
    for _, m in ipairs({ 'tests/mock/bot_api.lua', 'tests/mock/replay_fixture.lua' }) do
        local s = assert(slurp(m), 'cannot read ' .. m)
        assert(not s:find('GetActiveMode', 1, true),
            m .. ' now defines GetActiveMode -- the fixture route may have become ' ..
            'available for GH #333; re-read the ruling in this file before ' ..
            'assuming the arithmetic path is still the only one')
    end
end

return tests
