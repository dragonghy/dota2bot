-- [hero] backlog -114: does the mana-refill drain branch's widening have a
-- DOMAIN?  The answer this round records is NOT TAKEN, and this file is the
-- reason, pinned.
--
-- WHAT WAS ASKED
-- --------------
-- bots/BotLib/hero_lion.lua X.ConsiderE picks a Mana Drain target at three
-- places.  Round -109 (`liondrainmi`, GH #587) widened ONE of them -- the
-- 打架抽蓝 branch, whose target is an enemy hero -- and left the third site,
-- the mana-refill loop, explicitly untouched because its target is a CREEP out
-- of `bot:GetNearbyCreeps( 1600, true )`: another domain, another base rate,
-- and GH #566's three legs never measured it.  -114 asked for the second half
-- and said, in the same breath, to answer "has it got a domain" BEFORE writing
-- any code, and not to write a lever for symmetry.
--
-- THE ANSWER: NOT TAKEN.  Two readings, both taken here rather than argued.
--
--   (1) THE BRANCH'S OWN GUARD CERTIFIES THE CIRCLE HERO-FREE, AND IT IS THE
--       SAME CIRCLE THE CREEPS COME OUT OF.  The refill branch's first conjunct
--       is `#hEnemyList == 0`, and `hEnemyList` is assigned once per tick in
--       X.SkillsComplement as `J.GetNearbyHeroes(bot, 1600, true, ...)`.  The
--       creep scan two lines later is `bot:GetNearbyCreeps( 1600, true )`.
--       Section 1 parses BOTH radii out of the source and asserts they are the
--       same number -- it does not retype 1600, so a drift in either one turns
--       this file red instead of stale.
--
--   (2) NINE OF THE ELEVEN IMMUNITY NAMES THE SHIPPED READER CONSULTS CARRY A
--       HERO'S OWN INTERNAL NAME, AND EXACTLY ONE OF THOSE NINE IS `lion`.
--       Section 2 resolves every name in `CDOTA_Bot_Script:IsMagicImmune`
--       against this repo's own hero registry (the `bots/BotLib/hero_*.lua`
--       filenames -- a mechanical join, not a claim about Dota semantics).
--       Nine resolve.  The two that do not are the generic `modifier_magic_immune`
--       and `modifier_black_king_bar_immune`, and BKB is an item this repo's own
--       hero builds buy (asserted, out of Lion's build).  So inside a circle
--       reading (1) has certified hero-free, the supply of spell immunity on a
--       creep is down to: a buff that outlives its applier's departure, an
--       enemy the bot cannot see, the two unprefixed channels -- and
--       `modifier_lion_mana_drain_immunity`, the ONE name in the list whose
--       prefix is the bot itself, i.e. the one name reading (1) does not touch.
--
--   That last one is why this is NOT TAKEN rather than "domain unknown, ask for
--   a scan".  The surviving supply inside this branch's own guard is dominated
--   by a modifier that carries this very ability's name.  Widening the target
--   test here buys, first and foremost, permission to point Mana Drain back at
--   a unit Mana Drain has already flagged.  This file does not claim to know
--   that modifier's exact in-game semantics -- it asserts only what the repo
--   says: the name is in the shipped immunity reader's list (section 2), and a
--   unit carrying it is refused by the shipped predicate and accepted by the
--   widened one (section 3).  Both readings point the same way, so no third
--   reading would change the decision.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANYTHING FROM HERE
-- -------------------------------------------------------
--   * THIS IS NOT A MEASURED DOMAIN.  Nothing here counts instants.  It is a
--     SUPPLY argument taken off the source plus one predicate reading, and it
--     answers "is there a supply of spell-immune creeps inside this branch's
--     own guard" -- not "how often".  The one channel it cannot resolve is
--     INTRINSIC immunity (the engine's own IsMagicImmune, or the unprefixed
--     `modifier_magic_immune`) on a jungle creep or a summon, both of which
--     `GetNearbyCreeps` returns per docs/BOT_API_REFERENCE.md.  That residual
--     is one added column on queue.json hero-40, per -114's own instruction not
--     to open a second request for it.
--   * THE CORPUS CANNOT ANSWER IT EITHER, and section 4 MEASURES that over
--     every frame this file drives rather than quoting the one-frame reading
--     tests/test_lion_drain_combat_widen.lua section 3 already took.  CORRECTED
--     2026-09-07 (backlog -116; the verdict below does NOT move, only the cause
--     does): the reason is the LOADER'S and not the corpus's --
--     tests/mock/replay_fixture.lua wires GetNearbyHeroes, GetNearbyTowers and
--     GetNearbyBarracks to the real frame and never wires GetNearbyCreeps, so
--     that call falls through to the wildcard in tests/mock/bot_api.lua:175
--     (`if key:find('^GetNearby') then return {} end`) and answers an empty
--     table on every frame for either team.  This bullet used to say the DUMPER
--     SCHEMA has no creep channel.  Both sentences produce the same 0, but they
--     have opposite revival conditions, and that is why the wrong one is worth
--     correcting: under the old wording, whoever adds a creep channel to the
--     dumper would expect these zeros to move -- THEY WOULD NOT, because the
--     answer never reaches the dumper.  Only wiring the loader moves them.  The
--     corpus is demonstrably not the blocker: fixture files in this same tree
--     carry npc_dota_creep_* unit names in their text, which is the reading
--     tests/test_cm_frostbite_creep_cap.lua and
--     tests/test_cm_ranged_creep_health.lua already took from the other side.
--     A red in section 4 is still good news, and still for the same reason.
--   * NOTHING HERE TOUCHES bots/.  Section 5 asserts the absence: the refill
--     loop's target test is still literally `J.CanCastOnNonMagicImmune( nCreep )`,
--     no soak id names it, and `liondrainmi` still lives at exactly one call
--     site.  "Not taken" must not decay into "taken quietly" -- the same
--     discipline the sibling file applies from the other direction.
--
-- Round: hero desk 2026-09-07, backlog -114, owner priority P4.4(ii).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_lion.lua'
local OVERRIDES = 'bots/FunLib/aba_global_overrides.lua'
local HEROLIB = 'bots/BotLib'
local DRAIN_IMMUNE_MOD = 'modifier_lion_mana_drain_immunity'
local CAND = 'liondrainmi'

-- Listed, not globbed, for the same reason the sibling file lists them: rf.load
-- is not free, and a new entry should be a deliberate edit whose effect on
-- section 4's count is visible in the diff.  Same thirteen.
local DRIVEN_FRAMES = {
    'tests/fixtures/f_045650_lion_meatgrinder.lua',
    'tests/fixtures/f_222428_lion_lich_burst.lua',
    'tests/fixtures/f_260819_182323_lion_drain_calm.lua',
    'tests/fixtures/f_260819_182855_lion_drain_jungle.lua',
    'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua',
    'tests/fixtures/f_260819_183409_lion_drain_focused.lua',
    'tests/fixtures/f_260820_162821_lion_drain_lethal.lua',
    'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
    'tests/frames/f_20260831_004433_cm_creepreach.lua',
    'tests/frames/f_260828_002127_axe_call_bkb_ring.lua',
    'tests/frames/f_260828_124358_axe_cull_promise.lua',
    'tests/frames/f_260831_061811_axe_call_tp_channel.lua',
    'tests/frames/f_260905_004847_lion_drain_bkb.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function consider_e_body(src)
    local from = src:find('function X%.ConsiderE%s*%(%s*%)')
    assert(from, 'X.ConsiderE not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- The refill loop only: from the `#hEnemyList == 0` guard down to the end of
--- the `for` that scans the creeps.  Read out of ConsiderE so section 1 and
--- section 5 are looking at the same block the game runs.
local function refill_block(src)
    local body = consider_e_body(src)
    local from = body:find('if%s+#hEnemyList%s*==%s*0%s+and%s+#nEnemyTowers%s*==%s*0')
    assert(from, 'the mana-refill branch no longer opens with '
        .. '`if #hEnemyList == 0 and #nEnemyTowers == 0` -- reading (1) of this '
        .. 'whole file is that guard; re-read the branch, do not re-anchor this')
    local rest = body:sub(from)
    local to = rest:find('\n\t%-%-秒杀幻像')
    assert(to, 'the block after the refill loop is no longer the illusion branch; '
        .. 'the extraction below would run past the loop')
    return rest:sub(1, to)
end

--- The modifier names the SHIPPED IsMagicImmune override consults, read out of
--- that file rather than retyped, so this test cannot drift away from the
--- reader whose answer it is standing in for.  Returns an ordered list (the
--- ordering matters to nothing, but a list keeps the count honest).
local function immunity_modifiers()
    local src = read_file(OVERRIDES)
    local from = src:find('function CDOTA_Bot_Script:IsMagicImmune%(%)')
    assert(from, 'the IsMagicImmune override is gone from ' .. OVERRIDES
        .. '; this file was reading its modifier list out of it')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nend') or #rest)
    local seen, list = {}, {}
    for name in body:gmatch("HasModifier%('([%w_]+)'%)") do
        if not seen[name] then
            seen[name] = true
            list[#list + 1] = name
        end
    end
    assert(body:find('originalIsMagicImmune%(self%)'),
        'the override no longer falls through to the engine reader.  The residual '
        .. 'channel this file declares unresolvable (intrinsic immunity) just '
        .. 'changed shape; re-read the HONEST BOUNDS before quoting them.')
    return list, seen
end

--- Every hero internal name this repo carries a BotLib file for.  A mechanical
--- join target: no claim about what any modifier DOES, only about whose name it
--- is spelled with.
local function hero_internal_names()
    local names = {}
    local p = assert(io.popen('ls ' .. HEROLIB .. ' 2>/dev/null'))
    for line in p:lines() do
        local h = line:match('^hero_([%w_]+)%.lua$')
        if h then names[#names + 1] = h end
    end
    p:close()
    assert(#names > 100, 'only ' .. #names .. ' hero files found under ' .. HEROLIB
        .. '; the join in section 2 would under-resolve and read as "unprefixed"')
    return names
end

--- Longest hero prefix that `sModifier` is spelled with, or nil.  Longest, not
--- first: `life_stealer` and `lich` both exist, and a shortest-match join would
--- be a different (weaker) reading than the one this file reports.
local function hero_prefix_of(sModifier, tHeroes)
    local best = nil
    for _, h in ipairs(tHeroes) do
        if sModifier:sub(1, #('modifier_' .. h .. '_')) == 'modifier_' .. h .. '_' then
            if best == nil or #h > #best then best = h end
        end
    end
    return best
end

-- ---------------------------------------------------------------- section 1 --
-- READING (1): the guard and the creep scan are the same circle.  Both radii
-- are parsed; neither is retyped.

tests['guard: the refill branch fires only with ZERO visible enemy heroes near'] = function()
    local block = refill_block(read_file(SRC))
    assert(block:find('#hEnemyList%s*==%s*0'),
        'the hero-free conjunct is gone from the refill branch; reading (1) is void')
    assert(block:find('bot:GetNearbyCreeps%('),
        'the refill loop no longer scans GetNearbyCreeps; this file is about that scan')
    assert(block:find('J%.CanCastOnNonMagicImmune%(%s*nCreep%s*%)'),
        'the refill loop\'s target test is no longer J.CanCastOnNonMagicImmune( nCreep ) '
        .. '-- that predicate IS the thing -114 asked whether to widen')
end

tests['guard: hEnemyList and the creep scan share ONE radius, parsed not retyped'] = function()
    local src = read_file(SRC)
    local sHeroRadius = src:match('hEnemyList%s*=%s*J%.GetNearbyHeroes%(%s*bot%s*,%s*(%d+)%s*,%s*true')
    assert(sHeroRadius, 'hEnemyList is no longer assigned from J.GetNearbyHeroes(bot, <n>, true, ...) '
        .. 'in ' .. SRC .. '; the guard\'s radius cannot be read')
    local sCreepRadius = refill_block(src):match('bot:GetNearbyCreeps%(%s*(%d+)%s*,%s*true%s*%)')
    assert(sCreepRadius, 'the refill loop\'s GetNearbyCreeps radius cannot be read')
    assert(sHeroRadius == sCreepRadius,
        'the guard certifies a ' .. sHeroRadius .. 'u circle hero-free while the loop '
        .. 'takes candidates out of a ' .. sCreepRadius .. 'u one.  Reading (1) of this '
        .. 'file rests on those being the SAME circle -- if they have diverged, the '
        .. 'annulus between them is new supply and -114 has to be re-answered, not '
        .. 're-baselined.')
    -- Exact, once, so the pair moving TOGETHER is still visible in a diff.
    assert(sHeroRadius == '1600', 'the shared radius is now ' .. sHeroRadius
        .. 'u, was 1600u as of 2026-09-07')
end

tests['guard: hEnemyList is assigned once per tick, upstream of ConsiderE'] = function()
    -- Without this the guard could be reading a value computed under different
    -- conditions than the scan, and "same circle" would be an accident.
    local src = read_file(SRC)
    local iAssign = src:find('hEnemyList%s*=%s*J%.GetNearbyHeroes%(')
    local iConsiderE = src:find('function X%.ConsiderE%s*%(%s*%)')
    assert(iAssign and iConsiderE and iAssign < iConsiderE,
        'hEnemyList is no longer assigned above X.ConsiderE in ' .. SRC)
    local n = 0
    for _ in src:gmatch('hEnemyList%s*=%s*J%.GetNearbyHeroes%(') do n = n + 1 end
    assert(n == 1, 'hEnemyList is assigned from GetNearbyHeroes at ' .. n
        .. ' places, was 1 -- the guard and the scan may no longer share a tick')
end

-- ---------------------------------------------------------------- section 2 --
-- READING (2): whose names the immunity list is spelled with.  A mechanical
-- join against this repo's own hero registry -- no Dota semantics asserted.

tests['supply: the shipped immunity list is 11 names plus the engine reader'] = function()
    local list = immunity_modifiers()
    assert(#list == 11, 'the shipped IsMagicImmune override now consults ' .. #list
        .. ' modifier names, was 11 as of 2026-09-07.  Section 2\'s split is a '
        .. 'partition of exactly that list; re-take it, do not re-baseline it.')
end

tests['supply: 9 of 11 carry a hero internal name this repo has a file for'] = function()
    local list = immunity_modifiers()
    local heroes = hero_internal_names()
    local tPrefixed, tUnprefixed = {}, {}
    for _, m in ipairs(list) do
        local h = hero_prefix_of(m, heroes)
        if h then tPrefixed[m] = h else tUnprefixed[#tUnprefixed + 1] = m end
    end
    local nPrefixed = 0
    for _ in pairs(tPrefixed) do nPrefixed = nPrefixed + 1 end
    assert(nPrefixed == 9, nPrefixed .. ' of the 11 immunity names resolve to a hero '
        .. 'internal name, was 9 as of 2026-09-07')
    table.sort(tUnprefixed)
    assert(#tUnprefixed == 2
            and tUnprefixed[1] == 'modifier_black_king_bar_immune'
            and tUnprefixed[2] == 'modifier_magic_immune',
        'the two unprefixed names are now {' .. table.concat(tUnprefixed, ', ')
        .. '}, were {modifier_black_king_bar_immune, modifier_magic_immune}.  '
        .. 'Those two ARE the residual channel this file declares unresolvable; '
        .. 'a change here changes the HONEST BOUNDS.')
end

tests['supply: the one unprefixed non-generic name is a hero ITEM in this repo'] = function()
    -- So the second unprefixed name is not a third channel: its carrier class is
    -- "a hero who buys items", which reading (1) excludes exactly as it excludes
    -- the nine prefixed ones.  Asserted off Lion's own build list, in this file,
    -- rather than off general knowledge about who can carry a BKB.
    local src = read_file(SRC)
    assert(src:find('"item_black_king_bar"'),
        'item_black_king_bar is no longer in ' .. SRC .. '\'s own build list; the '
        .. 'claim that modifier_black_king_bar_immune rides a hero item is then '
        .. 'unsupported HERE and has to be re-sourced')
end

tests['supply: EXACTLY ONE immunity name is spelled with this bot\'s own name'] = function()
    -- This is the decisive reading.  Every other prefixed name needs some OTHER
    -- hero inside the circle reading (1) certifies empty; this one needs Lion,
    -- who is by construction at its centre.
    local list = immunity_modifiers()
    local heroes = hero_internal_names()
    local tLion = {}
    for _, m in ipairs(list) do
        if hero_prefix_of(m, heroes) == 'lion' then tLion[#tLion + 1] = m end
    end
    assert(#tLion == 1 and tLion[1] == DRAIN_IMMUNE_MOD,
        'the immunity names prefixed `lion` are now {' .. table.concat(tLion, ', ')
        .. '}, were exactly {' .. DRAIN_IMMUNE_MOD .. '}.  That singleton is why '
        .. '-114 is answered NOT TAKEN rather than referred out.')
    assert(DRAIN_IMMUNE_MOD:find('mana_drain'),
        'the name no longer carries this ability\'s own name, which is the whole '
        .. 'weight of the decision')
end

-- ---------------------------------------------------------------- section 3 --
-- THE DECISION THE WIDENING WOULD FLIP, driven on a real frame's real unit.
-- One labelled injection, vacuity asserted first -- the same discipline as
-- tests/test_lion_drain_combat_widen.lua section 2.

tests['decision: a unit carrying the drain immunity is refused by shipped, accepted by widened'] = function()
    local J, bot, heroes = rf.load('tests/frames/f_260905_004847_lion_drain_bkb.lua')
    local target = nil
    for _, h in pairs(heroes) do
        if h ~= bot and h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then target = h break end
    end
    assert(target, 'no live enemy unit on the frame to stand in for the creep')

    -- VACUITY, asserted before it is leaned on.  The mock installs neither the
    -- shipped IsMagicImmune override nor this modifier, so without the two
    -- injections below the comparison proves nothing.
    assert(target:HasModifier(DRAIN_IMMUNE_MOD) == false,
        'HARNESS GAP, NOT A CORPUS FACT: a unit in the corpus now carries '
        .. DRAIN_IMMUNE_MOD .. ' -- good news, the supply is measurable; re-read '
        .. 'this case rather than editing it green')
    assert(J.CanCastOnMagicImmune(target) == J.CanCastOnNonMagicImmune(target),
        'without the injection the two predicates cannot be told apart here')

    -- INJECTION, labelled: the modifier, and the reader's answer for it.  The
    -- MAPPING between the two is not invented here -- section 2 asserts the name
    -- is in the shipped reader's own list.
    local spec = rawget(target, '__spec')
    local prior = spec.HasModifier
    spec.HasModifier = function(self, sName)
        if sName == DRAIN_IMMUNE_MOD then return true end
        return prior(self, sName)
    end
    spec.IsMagicImmune = true
    assert(target:HasModifier(DRAIN_IMMUNE_MOD) == true and target:IsMagicImmune() == true,
        'the injections took')

    assert(J.CanCastOnNonMagicImmune(target) == false,
        'the SHIPPED refill-loop predicate must refuse a unit the ability itself '
        .. 'has flagged -- that refusal is the behaviour -114 asked whether to remove')
    assert(J.CanCastOnMagicImmune(target) == true,
        'and the WIDENED predicate would accept it.  This is the flip the not-taken '
        .. 'lever would have bought, measured rather than described.')
end

-- ---------------------------------------------------------------- section 4 --
-- Why no amount of fixture work could have answered this: measured, over every
-- frame this file drives, not quoted from the sibling's single frame.

tests['unmeasurable: not one creep exists in this generator\'s entire output'] = function()
    local nFrames, nCreeps = 0, 0
    for _, path in ipairs(DRIVEN_FRAMES) do
        local _, bot = rf.load(path)
        nCreeps = nCreeps + #bot:GetNearbyCreeps(1600, true)
        nFrames = nFrames + 1
    end
    assert(nFrames == #DRIVEN_FRAMES and nFrames == 13,
        nFrames .. ' frames driven, was 13 -- DRIVEN_FRAMES changed')
    assert(nCreeps == 0,
        nCreeps .. ' enemy creeps appeared across the driven frames.  '
        .. 'tests/mock/replay_fixture.lua now WIRES bot:GetNearbyCreeps to the '
        .. 'frame (corrected 2026-09-07, backlog -116 -- it is the loader that '
        .. 'holds this zero, not the dumper schema): the refill loop\'s domain '
        .. 'became MEASURABLE and -114 can be re-answered with a count instead '
        .. 'of a supply argument.  This is good news -- re-take the reading.')
end

tests['the zero above is the LOADER\'s, and this asserts the mechanism'] = function()
    -- Backlog -116.  Without this, the previous test is a bare 0 whose cause
    -- lives only in a comment, and a comment is exactly what was wrong here for
    -- a round.  Two halves, asserted separately so a future fix to either one
    -- reports itself:
    --   (a) the loader wires three GetNearby* families and not this one;
    --   (b) the corpus is not the blocker -- fixtures do carry creep names.
    local loader = read_file('tests/mock/replay_fixture.lua')
    for _, wired in ipairs({ 'GetNearbyHeroes', 'GetNearbyTowers', 'GetNearbyBarracks' }) do
        assert(loader:find("%.spec%.?" .. wired) or loader:find(wired, 1, true),
            'the loader no longer mentions ' .. wired .. '; the contrast this '
            .. 'assertion draws is with the families it DOES wire')
    end
    assert(not loader:find('GetNearbyCreeps', 1, true),
        'GOOD NEWS -- tests/mock/replay_fixture.lua now names GetNearbyCreeps. '
        .. 'If it wires it to the frame, the zero above is no longer structural '
        .. 'and every "unmeasurable" claim in this file must be re-taken.')
    local api = read_file('tests/mock/bot_api.lua')
    assert(api:find("if key:find('^GetNearby') then return {} end", 1, true),
        'the wildcard that actually answers bot:GetNearbyCreeps moved out of '
        .. 'tests/mock/bot_api.lua; re-read where the zero comes from before '
        .. 'quoting this file')
    -- (b): the dump is not missing creeps.  Read off a fixture's own text, the
    -- same reading tests/test_cm_frostbite_creep_cap.lua takes from its side.
    local seen = false
    for _, path in ipairs(DRIVEN_FRAMES) do
        if read_file(path):find('npc_dota_creep_', 1, true) then seen = true end
    end
    assert(seen, 'not one driven fixture names npc_dota_creep_* in its text.  '
        .. 'That would make the dumper a co-cause after all and this file\'s '
        .. 'HONEST BOUNDS would need re-reading -- which is precisely the '
        .. 'attribution -116 came to fix, so do not just delete this line')
end

-- ---------------------------------------------------------------- section 5 --
-- NOT TAKEN, recorded as an absence so it cannot decay into "taken quietly".

tests['absence: the refill loop is byte-for-byte the shipped one'] = function()
    local block = refill_block(read_file(SRC))
    assert(block:find('J%.CanCastOnNonMagicImmune%(%s*nCreep%s*%)'),
        'the refill loop\'s target test moved.  -114 was answered NOT TAKEN; if a '
        .. 'later round took it, this file is that round\'s starting point, not '
        .. 'its obstacle.')
    assert(block:find('IsSoakCandidate') == nil,
        'a soak gate appeared inside the mana-refill branch.  This round decided '
        .. 'not to put one there; a gate here needs its own id, its own domain '
        .. 'reading and its own entry, not this file going green around it.')
    assert(block:find('J%.CanCastOnMagicImmune') == nil,
        'the refill loop now calls the permissive predicate directly -- that is the '
        .. 'widening, ungated')
end

tests['absence: liondrainmi still rides exactly one call site, and not this one'] = function()
    local body = consider_e_body(read_file(SRC))
    local n = 0
    for _ in body:gmatch('X%.lion_IsDrainCombatTargetCastable%(') do n = n + 1 end
    assert(n == 1, 'X.lion_IsDrainCombatTargetCastable is called at ' .. n
        .. ' places inside ConsiderE, was 1 (the 打架抽蓝 branch).  A second call '
        .. 'site -- in the refill loop above all -- would silently give ' .. CAND
        .. ' a second, unmeasured domain riding one id.')
    assert(refill_block(read_file(SRC)):find('lion_IsDrainCombatTargetCastable') == nil,
        'the refill loop now calls ' .. CAND .. '\'s helper.  Two domains on one id '
        .. 'is exactly what -109 split apart and -114 was asked not to re-merge.')
end

tests['absence: the 团战吸蓝 branch is still untouched too'] = function()
    -- The third site.  GH #566 ruled it correct as shipped; neither -109 nor
    -- this round was allowed to move it, and "untouched" is cheap to assert.
    local body = consider_e_body(read_file(SRC))
    assert(body:find('and%s+J%.CanCastOnMagicImmune%(%s*npcEnemy%s*%)'),
        'the 团战吸蓝 branch stopped calling J.CanCastOnMagicImmune( npcEnemy ) directly')
end

return tests
