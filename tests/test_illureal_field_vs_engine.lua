-- [ratchet] [illureal] minion_lib/illusions.lua asks "is this an illusion?"
-- twice, on the same handle, in one file -- once with a hand-maintained field
-- and once with the engine method. The field is written by 2 of the 127 hero
-- files, so the branch it guards has been unreachable for every illusion in the
-- game except Naga Siren's and Phantom Lancer's.
--
-- Family: the minion drivers, the population backlog `0d` never named because
-- it is not reached through mode bidding (see tests/test_illumove_shared_
-- throttle.lua, GH #378). That round fixed the MOVE branch of X.Think. This one
-- is the branch four lines above it.
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     When a predicate about the WORLD is stored as a hand-maintained field,
--     its truth is no longer a fact about the world -- it is a fact about
--     whether every writer remembered. The predicate is then only as reachable
--     as its least diligent caller, and it fails in the OFF direction and in
--     SILENCE: an unset field is indistinguishable from an honest `false`, so
--     the guarded branch simply never happens, nothing errors, no counter
--     moves, and no test can tell "this unit is not an illusion" apart from
--     "nobody set the flag on this illusion".
--     The tell is countable and needs no frame: one predicate with TWO
--     spellings live in the same file -- a field and the engine call that
--     answers the same question -- with different branches reading different
--     ones. Where that happens, count the WRITERS of the field against the
--     CALLERS of the branch. Here it is 2 against 127.
--     Distinguish from the five same-family findings before it. GH #348 is
--     ORDER (a nil guard below the index it guards). GH #368 is LEXICAL scope
--     (a `local` shadowing a file-level name). GH #370 is an UNREPORTED SIDE
--     EFFECT. GH #373 is a latch recording the ATTEMPT instead of the
--     POSTCONDITION. GH #378 is a throttle whose SCOPE is wider than what it
--     throttles. All five are defects in how one piece of state is read or
--     written. This one is different: every read and every write of
--     `isIllusion` is correct, and the field is never stale. The defect is that
--     the field is a DUPLICATE of something the engine already knows, and the
--     duplicate has two writers where the original has 127 readers.
--
-- ⭐⭐ WHY THIS IS A DEFECT AND NOT A DESIGN CHOICE, on the evidence of the same
-- file. Sixty lines below the guard, X.ConsiderRetreat asks
-- `hMinionUnit:IsIllusion()` -- the engine method, on the same handle, reached
-- through the same X.Think call, one line later in the same function. So the
-- method is available on these handles in shipped code (this is not a "the
-- engine might not answer" question), and the file itself does not consistently
-- prefer the field. Pinned by [source S2].
--
-- ⭐⭐⭐ WHY NOBODY NOTICED, and it is not "nobody thought about illusions".
-- Twelve hero files gate their own X.MinionThink on `hMinionUnit:IsIllusion()`
-- before routing -- twelve authors who explicitly had illusions in mind. TWO of
-- those twelve also set the field, and they are Naga Siren and Phantom Lancer:
-- the two dedicated illusion heroes, i.e. exactly the two you would open the
-- game to test an illusion feature with. The feature demos correctly and is
-- dead everywhere else. Terrorblade is in the other ten -- while this very file
-- carries a Terrorblade-specific lane-farm branch in X.ConsiderMove, so the
-- module is written for a population its own guard cannot admit. Pinned by
-- [source S4].
--
-- REAL FRAME: tests/fixtures/f_231411_ck_zoned.lua -- game 20260721_231411,
-- subject chaos_knight, t=192.0 (3:12), hp 126/1068 = 0.118. Chosen because CK
-- is both an illusion-ultimate hero (Phantasm) and one of the 19 hero files
-- whose buy list contains item_manta, and because hero_chaos_knight.lua:124-131
-- routes minions to Minion.IllusionThink unconditionally without ever setting
-- the field. On this frame the branch's two WORLD conditions are true for real,
-- read off the dump and not asserted by this test: J.GetHP(bot) = 0.118 < 0.4,
-- and J.WeAreStronger(bot, 1200) = false with two live enemies inside 1200.
--
-- ⚠️ LIMITS, declared:
--   * THE ILLUSION HANDLE IS AN INJECTION. No fixture in the corpus carries an
--     illusion or a summon (established in GH #378); the dumper does not emit
--     them. So the frame supplies the OWNER's world -- the hp, the enemies, the
--     strength comparison, the fountain distance -- and the illusion itself is
--     built. Both arms receive the byte-identical injection, and the claim under
--     test ("which spelling of `is this an illusion` does the guard read") is a
--     property of the module, not of the frame. Same UNMEASURABLE-is-not-EMPTY
--     distinction as GH #171/#205, #368, #373, #378.
--   * ON THIS FRAME CK IS LEVEL 4, so it has neither Phantasm (level 6) nor a
--     Manta yet. The frame is not evidence that this CK had illusions at t=192;
--     it is evidence of the low-hp-under-pressure world the branch exists to
--     act in. The "CK can have illusions" half is bought from the shipped
--     ability and buy lists instead, and pinned as source, not as frame.
--   * bot:GetActiveMode() IS NOT IN THE DUMP (world slot S-A below).
--     J.IsRetreating needs it and it is declared, identical in both arms.
--   * bot:GetFacing() IS NOT IN THE DUMP (world slot S-C). It only steers WHERE
--     the decoy runs; every assertion here is about WHETHER an order is issued.
--   * WHAT THIS FIX DOES NOT CLAIM: that the decoy play is worth points. It
--     makes an already-shipped, already-written branch reachable for the
--     population it was written for. Whether it earns anything in Turbo is
--     condition (b)/(c) work, not this file's.
--
-- DECLARED WORLD SLOTS:
--   S-A  bot:GetActiveMode()/GetActiveModeDesire() = RETREAT above MODERATE.
--        J.IsRetreating's first disjunct; its third argument
--        (DistanceFromFountain > 0) IS read from the frame for real.
--   S-B  the illusion handle (see LIMITS). Built once, used by both arms.
--   S-C  bot:GetFacing() = 0.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_231411_ck_zoned.lua'
local TARGET  = 'bots/FunLib/minion_lib/illusions.lua'
local DRIVER  = 'bots/FunLib/aba_minion.lua'
local HERODIR = 'bots/BotLib/'

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_MODERATE = 0.4,
    BOT_ACTION_DESIRE_NONE   = 0.0,
    BOT_ACTION_DESIRE_HIGH   = 0.75,
    BOT_MODE_RETREAT         = 12,
}

--- Blank whole-line comments while PRESERVING line numbers, so every count
--- below means "in code". This file's own fix comment names `isIllusion` six
--- times and `IsIllusion` twice; without this the scanners would be counting
--- their own explanation. GH #370 hit exactly that; its fix is copied here
--- rather than re-derived.
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local function read(path)
    local fh = assert(io.open(path), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function count(src, needle)
    return select(2, src:gsub(needle:gsub('%W', '%%%0'), ''))
end

--- Slice a function body by its two NEIGHBOURS instead of by `.-\nend`, which
--- stops at the first NESTED end and silently returns a truncated body -- the
--- method self-harm recorded in GH #373.
local function slice(src, from, to)
    local a = src:find(from, 1, true)
    local b = src:find(to, 1, true)
    assert(a and b and a < b, ('%q must sit above %q'):format(from, to))
    return src:sub(a, b - 1)
end

local CODE  = codeOnly(read(TARGET))
local DRIVE = codeOnly(read(DRIVER))

--- Every hero file, read once. Enumerated off the DIRECTORY, the same way
--- tests/test_smoke_load.lua does it, rather than off any in-tree registry
--- list: the population this test is counting is "hero files that ship", and a
--- registry that had drifted from the directory would quietly shrink the
--- denominator toward the answer the test wants.
local HEROES = (function()
    local out = {}
    local p = assert(io.popen('ls ' .. HERODIR), 'cannot list ' .. HERODIR)
    for line in p:lines() do
        local part = line:match('^hero_(.*)%.lua$')
        -- hero_lone_druid_bear.lua is the druid's BEAR unit, not a hero.
        if part and part ~= 'lone_druid_bear' then
            out[#out + 1] = {
                name = 'npc_dota_hero_' .. part,
                path = HERODIR .. line,
                src  = codeOnly(read(HERODIR .. line)),
            }
        end
    end
    p:close()
    table.sort(out, function(a, b) return a.path < b.path end)
    return out
end)()

-- ---------------------------------------------------------------------------
-- [source] -- the shape, read off the shipped tree
-- ---------------------------------------------------------------------------

tests['[source S1] the guard goes through the accessor, and the accessor is the only reader of the field'] = function()
    -- The field survives (gate shut must be the shipped answer), but X.Think
    -- must not read it directly any more.
    local think = slice(CODE, 'function X.Think(', 'function X.ConfuseEnemyWithIllusions(')
    assert(count(think, 'hMinionUnit.isIllusion') == 0,
        'X.Think must not read the raw field; it has to go through IsIllusionUnit')
    assert(count(think, 'IsIllusionUnit(hMinionUnit)') == 1,
        'X.Think must consult IsIllusionUnit exactly once')

    -- Exactly two mentions of the field in code: the two inside the accessor.
    local mentions = count(CODE, 'isIllusion')
    assert(mentions == 2, 'expected exactly 2 mentions of the field IN CODE (both inside '
        .. 'IsIllusionUnit: the shipped return and the armed disjunct); got ' .. mentions)

    local acc = slice(CODE, 'local function IsIllusionUnit(', 'function X.Think(')
    assert(count(acc, 'isIllusion') == 2, 'both mentions must live in IsIllusionUnit')
    assert(acc:find('hMinionUnit:IsIllusion()', 1, true) ~= nil,
        'the armed arm must ask the engine method')
end

tests['[source S2] the same file already asks the engine the same question on the same handle'] = function()
    -- This is the whole reason the fix is a fix and not a preference: the
    -- method is demonstrably usable on these handles in code that ships today.
    local retreat = slice(CODE, 'function X.ConsiderRetreat(', 'function X.IsTargetInShouldAimToAttackRange(')
    assert(count(retreat, 'hMinionUnit:IsIllusion()') == 1,
        'ConsiderRetreat must ask the engine method -- the shipped precedent')

    -- ... and it is reached from the same X.Think, one line below the guard.
    local think = slice(CODE, 'function X.Think(', 'function X.ConfuseEnemyWithIllusions(')
    assert(think:find('X.ConsiderRetreat(hMinionUnit', 1, true) ~= nil,
        'X.Think must call ConsiderRetreat, so both spellings run on the same handle '
        .. 'in the same call')
end

tests['[source S3] gate shut is the shipped predicate, proved by evaluation not by reading'] = function()
    local function pred(armed, unit)
        if armed then return unit.isIllusion == true or unit:IsIllusion() end
        return unit.isIllusion
    end

    local realIllusion   = { isIllusion = nil,  IsIllusion = function() return true  end }
    local flaggedIllusion= { isIllusion = true, IsIllusion = function() return true  end }
    local plainMinion    = { isIllusion = nil,  IsIllusion = function() return false end }

    -- Shipped: the flag and nothing else. A real illusion nobody flagged reads
    -- exactly like a creep.
    assert(pred(false, realIllusion) == nil, 'gate shut must answer the raw field')
    assert(pred(false, flaggedIllusion) == true, 'gate shut must admit a flagged illusion')
    assert(pred(false, plainMinion) == nil, 'gate shut must reject a non-illusion')
    assert(pred(false, realIllusion) == pred(false, plainMinion),
        'THE DEFECT: shipped, an unflagged illusion is indistinguishable from a creep')

    -- Armed: a superset. Everything the shipped arm admitted is still admitted
    -- (so arming cannot silence a Naga or PL illusion that moves today), plus
    -- the ones the engine calls illusions.
    assert(pred(true, flaggedIllusion) == true, 'arming must not drop the flagged case')
    assert(pred(true, realIllusion) == true, 'arming must admit an unflagged real illusion')
    assert(pred(true, plainMinion) == false,
        'arming must NOT widen to non-illusions -- skill-less minions route here too')

    -- And the gate itself is the standard conjunction.
    assert(CODE:find("J.IsModeTurbo() and J.IsSoakCandidate('illureal')", 1, true) ~= nil,
        'the gate must be turbo-only and named illureal')
    assert(count(CODE, "IsSoakCandidate('illureal')") == 1,
        'exactly one illureal gate expression in this file')
end

tests['[source S4] 2 writers against 127 routers, and the 2 are the demo heroes'] = function()
    assert(#HEROES >= 120, 'expected the full shipped hero registry; got ' .. #HEROES)

    local writers, routers, considered = {}, 0, {}
    for _, h in ipairs(HEROES) do
        if h.src:find('isIllusion%s*=%s*true') then writers[#writers + 1] = h.name end
        -- Every hero file hands its minions to the shared driver. Keyed on the
        -- CALL, not on the module local's name: hero_wisp.lua is transpiled out
        -- of typescript/ and spells it `minion.IllusionThink` in lower case, so
        -- a scanner keyed on `Minion.` walks straight past a file that does
        -- route. (Caught by this assertion at 126/127. Same self-harm as the
        -- GH #377 M8 probe that keyed on a variable name -- a census must match
        -- what the code DOES, not how one author spelled it.)
        if h.src:find('%.IllusionThink%s*%(') or h.src:find('%.MinionThink%s*%(') then
            routers = routers + 1
        end
        -- ... and these ones did so with illusions explicitly in mind.
        local mt = h.src:match('function X%.MinionThink.-\nend')
        if mt and mt:find('IsIllusion', 1, true) then
            considered[#considered + 1] = h.name
        end
    end
    table.sort(writers)

    assert(routers == #HEROES, ('every hero file must route minions into the shared '
        .. 'driver; %d of %d do'):format(routers, #HEROES))
    assert(#writers == 2, 'expected exactly 2 hero files to write the field; got '
        .. #writers .. ' (' .. table.concat(writers, ', ') .. ')')
    assert(writers[1] == 'npc_dota_hero_naga_siren'
        and writers[2] == 'npc_dota_hero_phantom_lancer',
        'the two writers must be the two dedicated illusion heroes -- that is why the '
        .. 'branch demos correctly and is dead everywhere else; got '
        .. table.concat(writers, ', '))

    -- The sharp count: authors who explicitly routed illusions here, minus the
    -- ones who also set the flag.
    assert(#considered >= 10, 'expected at least 10 hero files gating MinionThink on '
        .. 'IsIllusion(); got ' .. #considered)
    local blind = 0
    for _, n in ipairs(considered) do
        if n ~= 'npc_dota_hero_naga_siren' and n ~= 'npc_dota_hero_phantom_lancer' then
            blind = blind + 1
        end
    end
    assert(blind == #considered - 2, 'both writers must be inside the considered set')
    assert(blind >= 8, 'the point of the count: hero files that deliberately send illusions '
        .. 'into this module and still cannot reach the branch; got ' .. blind)
end

tests['[source S5] the module is written for a population its shipped guard cannot admit'] = function()
    -- Terrorblade has a dedicated branch in this very file...
    local move = slice(CODE, 'function X.ConsiderMove(', 'function X.IsTargetUnderEnemyTower(')
    assert(move:find('terrorblade', 1, true) ~= nil,
        'ConsiderMove must carry its Terrorblade illusion lane-farm branch')
    -- ... and never sets the flag.
    local tb = read(HERODIR .. 'hero_terrorblade.lua')
    assert(codeOnly(tb):find('isIllusion%s*=%s*true') == nil,
        'hero_terrorblade.lua must NOT set the field -- that is the contradiction')

    -- Chaos Knight, the subject below, is in the same position and additionally
    -- buys a Manta.
    local ck = codeOnly(read(HERODIR .. 'hero_chaos_knight.lua'))
    assert(ck:find('Minion.IllusionThink', 1, true) ~= nil,
        'hero_chaos_knight.lua must route minions into the shared driver')
    assert(ck:find('isIllusion%s*=%s*true') == nil,
        'hero_chaos_knight.lua must NOT set the field')
    assert(ck:find('item_manta', 1, true) ~= nil,
        "CK's shipped buy list must contain a Manta -- the second illusion source")

    -- And the driver really does hand every hero illusion to this module.
    assert(count(DRIVE, 'Illusion.Think(bot, hMinionUnit)') == 1,
        'exactly one call expression into Illusion.Think')
    assert(DRIVE:find('hMinionUnit:IsIllusion()', 1, true) ~= nil,
        'the driver routes on the ENGINE method -- so an illusion always arrives here, '
        .. 'flagged or not; only the branch inside cannot see it')
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------

local function world(armed)
    local J, bot = rf.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end

    J.IsSoakCandidate = function(id) return armed and id == 'illureal' end
    J.IsModeTurbo     = function() return true end

    -- S-A / S-C: not in the dump. Identical in both arms.
    local spec = rawget(bot, '__spec')
    spec.GetActiveMode       = function() return BOT_MODE_RETREAT end
    spec.GetActiveModeDesire = function() return 0.9 end
    spec.GetFacing           = function() return 0 end

    local Illusion = dofile(TARGET)
    local here = bot:GetLocation()

    -- S-B: the illusion handle. `flagged` reproduces what Naga/PL do.
    local function illusion(flagged, bReallyIllusion)
        local log = {}
        local u = api.MakeUnit({
            GetUnitName             = 'npc_dota_hero_chaos_knight',
            GetTeam                 = bot:GetTeam(),
            GetPlayerID             = -1,
            IsAlive                 = true,
            IsNull                  = false,
            CanBeSeen               = true,
            IsIllusion              = bReallyIllusion ~= false,
            GetCurrentMovementSpeed = 300,
            GetAttackDamage         = 50,
            GetHealth               = 600,
            GetMaxHealth            = 600,
            -- J.GetHP reads the OriginalGet* pair for own-team units
            -- (jmz_func.lua:4006-4009).
            OriginalGetHealth       = 600,
            OriginalGetMaxHealth    = 600,
            GetAttackRange          = 150,
            GetLocation             = api.Vector(here.x + 150, here.y + 150, here.z),
            Action_MoveToLocation   = function() log[#log + 1] = 'move' end,
            Action_AttackMove       = function() log[#log + 1] = 'attackmove' end,
            Action_AttackUnit       = function() log[#log + 1] = 'attack' end,
        })
        if flagged then u.isIllusion = true end
        return u, log
    end

    return { J = J, bot = bot, Illusion = Illusion, illusion = illusion }
end

--- Did the CONFUSE branch fire? It is the only path that issues an order and
--- returns before ConsiderAttack runs, so it is identified by X.Think returning
--- after exactly one MoveToLocation with the attack fields never written.
local function confused(w, u, log)
    w.Illusion.Think(w.bot, u)
    return #log == 1 and log[1] == 'move' and u.attack_desire == nil
end

-- ---------------------------------------------------------------------------
-- [frame] -- the real frame
-- ---------------------------------------------------------------------------

tests['[frame F0] the branch world conditions are TRUE on this frame, read not asserted'] = function()
    local w = world(false)
    assert(w.bot:GetUnitName() == 'npc_dota_hero_chaos_knight',
        'subject must be CK; got ' .. tostring(w.bot:GetUnitName()))

    local hp = w.J.GetHP(w.bot)
    assert(hp < 0.4, 'the frame must supply the low-hp half for real; got ' .. tostring(hp))
    assert(hp > 0.10 and hp < 0.13, 'sanity: CK is at 126/1068 on this frame; got ' .. tostring(hp))

    assert(w.J.WeAreStronger(w.bot, 1200) == false,
        'the frame must supply the "not stronger" half for real')
    assert(#w.J.GetEnemiesNearLoc(w.bot:GetLocation(), 1200) == 2,
        'and it must be false because enemies are genuinely close, not because the '
        .. 'list is empty')

    -- The declared half, checked as declared rather than assumed.
    assert(w.J.IsRetreating(w.bot) == true,
        'world slot S-A must make IsRetreating true, or F1/F2 prove nothing')
    assert(w.bot:DistanceFromFountain() > 0,
        'IsRetreating third conjunct -- this one IS read from the frame')
end

tests['[frame F1] SHIPPED: a real CK illusion on this frame is given no decoy order'] = function()
    local w = world(false)
    local u, log = w.illusion(false, true)
    assert(u:IsIllusion() == true, 'the engine calls this unit an illusion')
    assert(u.isIllusion == nil, 'and no hero file flagged it -- CK never does')
    assert(not confused(w, u, log),
        'THE DEFECT: with every world condition satisfied, the shipped guard reads the '
        .. 'unset field and the decoy branch never runs')
end

tests['[frame F2] ARMED: the same illusion on the same frame is given the decoy order'] = function()
    local w = world(true)
    local u, log = w.illusion(false, true)
    assert(confused(w, u, log),
        'armed, the guard asks the engine and the shipped branch finally runs on the '
        .. 'population it was written for')
end

tests['[frame F3] a Naga/PL-style flagged illusion behaves identically in both arms'] = function()
    local a = world(false)
    local ua, la = a.illusion(true, true)
    local shipped = confused(a, ua, la)

    local b = world(true)
    local ub, lb = b.illusion(true, true)
    local armed = confused(b, ub, lb)

    assert(shipped == true, 'the flagged case is the one that works today')
    assert(shipped == armed, 'arming must not change the two heroes that already set the '
        .. 'field; shipped ' .. tostring(shipped) .. ' vs armed ' .. tostring(armed))
end

tests['[frame F4] ARMED: arming does NOT widen the branch to skill-less minions'] = function()
    -- aba_minion routes U.IsMinionWithNoSkill units down the same call. They
    -- must stay out: the engine says they are not illusions, and a WK skeleton
    -- running 800u the wrong way is not the play.
    local w = world(true)
    local u, log = w.illusion(false, false)
    assert(u:IsIllusion() == false, 'a summon is not an illusion')
    assert(not confused(w, u, log),
        'the armed predicate must be a superset of illusions only, not of everything '
        .. 'that reaches X.Think')
end

tests['[frame F5] ARMED: the branch still needs its world -- a healthy owner does not decoy'] = function()
    local w = world(true)
    -- Same frame, same armed gate; only the owner's hp is lifted above the
    -- branch's own threshold. If this still fired, the fix would have removed a
    -- guard rather than repaired a predicate.
    --
    -- 0.8, NOT full health. At exactly 1.0 this case cannot tell `< 0.4` from
    -- `< 1.0`, because `1.0 < 1.0` is false too -- so a mutant that raises the
    -- threshold to admit every hero in the game survives while the case still
    -- reads green. Measured: it did survive, and the defect was in this
    -- assertion's chosen point, not in the mutant. Any healthy-but-not-maximal
    -- value separates them.
    local spec = rawget(w.bot, '__spec')
    local maxhp = spec.OriginalGetMaxHealth or spec.GetMaxHealth
    spec.OriginalGetHealth = maxhp * 0.8
    spec.GetHealth         = (spec.GetMaxHealth or maxhp) * 0.8
    local hp = w.J.GetHP(w.bot)
    assert(hp > 0.4 and hp < 1.0,
        'this case must sit strictly BETWEEN the threshold and full health; got ' .. tostring(hp))

    local u, log = w.illusion(false, true)
    assert(not confused(w, u, log),
        'arming must change WHICH UNITS the guard admits, not WHEN the play happens')
end

tests['[frame F6] ARMED: an owner who is not retreating does not decoy either'] = function()
    -- The other half of F5, and it moves the DECLARED slot rather than the
    -- frame: with S-A set to anything but a committed retreat, J.IsRetreating
    -- goes false and the branch must stay shut. Without this case a mutant that
    -- deletes `J.IsRetreating(bot)` from the branch condition survives, because
    -- on this frame the hero really is retreating.
    local w = world(true)
    local spec = rawget(w.bot, '__spec')
    spec.GetActiveMode       = function() return 3 end -- farm, not retreat
    spec.GetActiveModeDesire = function() return 0.2 end
    assert(w.J.IsRetreating(w.bot) == false, 'precondition of this case')

    local u, log = w.illusion(false, true)
    assert(not confused(w, u, log),
        'the decoy is a retreat play; arming the predicate must not make it fire while '
        .. 'the owner is standing its ground')
end

-- NOT PINNED -- three surviving mutants, declared with their reasons. All three
-- are in ConfuseEnemyWithIllusions' own body, which this change does not touch;
-- the cases above pin the PREDICATE that decides who reaches it.
--   * `not J.WeAreStronger(bot, 1200)` deleted. Reads false on this frame for
--     real (F0), so the mutant is EQUIVALENT here. Catching it needs a frame
--     where a low-hp retreating hero is nonetheless the stronger side, or a J.*
--     stub -- and stubbing the helper would be measuring the stub. Declared
--     before the stand was run, and the run confirmed it.
--   * `J.GetHP(bot) < 0.4` widened to `< 0.5`. F0/F1/F2 sit at 0.118 and F5 at
--     0.8, so nothing separates 0.4 from 0.5. Pinning the constant exactly
--     would assert a shipped tuning value this change has no opinion about, and
--     would then have to be edited by whoever legitimately tunes it. `< 1.0`
--     IS caught (see F5) -- i.e. the threshold is pinned as "still a real
--     threshold", not as "exactly 0.4".
--   * `confuseDistance = 800` set to 0. Every assertion here is about WHETHER an
--     order is issued, not where it points; see LIMITS.

return tests
