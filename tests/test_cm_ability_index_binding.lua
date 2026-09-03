-- [hero] `GRANTSLOT`, the Crystal Maiden half: what index 4 can name, and the
-- one direction in which `IsHidden()` turned out to be readable offline.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- GH #203 settled the Zeus half of this axis: `sAbilityList` is not the slot
-- array, it is what `J.Skill.GetAbilityList` COMPACTS out of slots 0..10, so
-- index N means "the Nth ability the walk accepted".  It left the Crystal
-- Maiden binding open, and tests/test_focus_innate_index_anchor.lua section 4
-- says so in as many words.  This file closes it.
--
-- Crystal Maiden's slot order (datafeed hero_id=5, fetched 2026-08-26; the
-- grant/innate flags are the feed's own `ability_is_granted_by_shard` /
-- `ability_is_innate`).  ⭐ CONFIRMED 2026-08-26 (GH #209) against the game's
-- own npc_heroes.txt, which publishes the ability-index map the datafeed does
-- not: the six rows below match it exactly, and
-- tests/test_hero_slot_order_anchor.lua re-checks them every run -- so this is
-- no longer the assumption the LIMITS section below calls it, and a patch that
-- moves a row turns this candidate red instead of silently pointing it at
-- another ability:
--
--     slot 0  crystal_maiden_crystal_nova
--     slot 1  crystal_maiden_frostbite
--     slot 2  crystal_maiden_brilliance_aura
--     slot 3  crystal_maiden_crystal_clone    granted by shard
--     slot 4  crystal_maiden_glacial_guard    innate
--     slot 5  crystal_maiden_freezing_field   ultimate -> index 6
--
-- `CrystalClone = sAbilityList[4]` therefore means Crystal Clone only if the
-- walk keeps the shard grant.  Section 1 enumerates the drop decision over the
-- two optional abilities -- 2^2 = 4 worlds -- and drives the SHIPPED walk in
-- each.  Measured: index 4 is Crystal Clone in TWO of the four, the INNATE in
-- one, and the empty-slot placeholder `generic_hidden` in one.  It is nil in
-- NONE of them on this VM, which is not what the first cut of this file
-- predicted and is the more interesting answer (see the `#`-border note below).
--
-- ⭐ WHAT IS NEW HERE: THE CORPUS PICKS THE WORLD
-- ----------------------------------------------
-- The Zeus round had to stop at a disjunction because `ability:IsHidden()` was
-- taken to be unreadable outside the game VM.  It is unreadable in one
-- direction only, and this repo has been printing the other direction all
-- along.  The behavioural dumper walks the same `m_vecAbilities` the bot API
-- exposes through GetAbilityInSlot, and its filter
-- (tools/batch_test/behavioral/dumper/main.go, isRealAbility) reads:
--
--     if hidden { return false }
--
-- So a name PRESENT in a fixture frame's ability array had `m_bHidden` false on
-- that frame.  Presence is a read of IsHidden; absence is a disjunction (hidden,
-- OR an unleveled talent row, OR one of the blacklisted generic abilities, OR
-- not in the vector at all) and is never treated as one here.
--
-- That asymmetry is enough, because the two innates the corpus DOES carry are
-- the control: Wraith King's innate is present on 33 of 33 frames and Lion's on
-- 23 of 23, so an innate is exactly the kind of entry this pipeline shows.
-- Crystal Maiden's array is four entries on 53 of 53 frames -- her innate on
-- ZERO and the shard grant on ZERO -- and `zuus_lightning_hands`, a shard
-- grant, appears on one Zeus frame, which is the denominator that makes a
-- grant's zero readable at all.
--
-- ⇒ Both of her optional abilities are hidden on every frame this repo owns,
--   both are dropped by the walk, and index 4 falls to the fourth world -- the
--   `generic_hidden` one.  The shipped `CrystalClone` is a handle to the
--   engine's empty-slot placeholder: `IsTrained()` is false, the branch answers
--   NONE forever, and nothing raises.  Silent, not loud.
--
-- ⭐ AND THE SLOT ORDER IS CONFIRMED, NOT ASSUMED
--   GH #203 had to declare "that GetAbilityInSlot enumerates the datafeed's
--   order is an assumption".  For this hero the corpus settles it.  The walk
--   writes the ultimate to the fixed index 6 only from `slot >= 4`; Crystal
--   Maiden has three always-visible abilities, so if her two optional abilities
--   occupied no slot ahead of the ultimate, the ultimate would sit at slot 3,
--   fall through to `table.insert`, and `sAbilityList[6]` would be nil -- i.e.
--   `abilityR` unusable and Freezing Field never cast.  The corpus refutes that
--   directly: her ultimate is ON COOLDOWN on 10 of 53 frames, and the only cast
--   site for `abilityR` in the whole repo is inside X.SkillsComplement.
--
-- ⚠️ WHY THE NIL GUARD IS INSURANCE AND NOT A REPAIR
--   `#` over a table with a hole is UNSPECIFIED in Lua 5.1, and this hero is
--   where that stops being academic: with three abilities kept in front of the
--   fixed index 6, this VM answers 3 for `#{1,2,3,[6]}` and the placeholder
--   lands on index 4, while a VM answering 6 would append past the hole and
--   leave index 4 nil.  In THAT world the shipped `CrystalClone:IsTrained()`
--   raises inside X.SkillsComplement; the engine error handler is broken
--   (AGENTS.md) so the tick dies silently, and since this branch sits ABOVE
--   ConsiderQ/W/R it would take her entire spell dispatch with it.  The corpus
--   says that is not the world that ships today -- her ultimate is on cooldown
--   on 10 of 53 frames and the only Freezing Field cast site in the repo is
--   below this branch.  So the guard covers a legal-but-unobserved VM answer.
--   Section 4 pins that distinction so nobody upgrades it in a later summary.
--
--   Note also that the Zeus half measured the OPPOSITE border on the same VM
--   ({1,2,3,4,[6]} answers 6).  "This VM answers 6" is not a fact that may be
--   carried from one hero to the next; the WORLD ASSERTION pins both.
--
-- WHAT THE COST IS
--   Crystal Clone is unreachable for the entire game, in every game.
--   `sAbilityList` is computed once at file scope, before any shard exists, so
--   even the Turbo free shard at 15:00 -- which GH #108's cap=25 finally brings
--   inside the scored window -- cannot revive a binding frozen at t=0.  This is
--   index arithmetic, not a decision anybody made.
--
-- THE SHAPE OF THE CHANGE
--   `X.GetBoundAbility( hShipped, sName )`, the same shape GH #203 landed on
--   hero_zuus.lua: gate-off returns the caller's own file-local as the LAST
--   statement, so gate-off equivalence is structural rather than measured.
--   Armed (`cmclone`, turbo-only) it resolves by name and still falls back when
--   the engine answers nil.  Binding by name is this repo's majority pattern:
--   GH #203 counted 40 file-scope sites under bots/BotLib that already fetch a
--   shard or scepter ability by literal name.  That count is CARRIED FORWARD
--   from #203, not re-measured here; what this file re-checked is only the
--   weaker fact that bindings of this shape are common (78 file-scope
--   GetAbilityByName-with-a-string-literal sites across bots/BotLib/hero_*.lua,
--   of which the grant subset is #203's 40).
--
-- ⚠️ LIMITS -- READ BEFORE CITING
--   * "Hidden on 53 of 53 frames" is a read of THIS corpus, curated for other
--     investigations.  It is an existence read, never a density, and it says
--     nothing about a game where somebody buys the shard before minute 10.
--   * `m_bHidden` (dumper) and `ability:IsHidden()` (bot API) being the same bit
--     is an assumption, declared here and nowhere relied on in the other
--     direction.
--   * Nothing here says a reachable Crystal Clone WINS games.  Locally-correct
--     is not emergently-good (AGENTS.md, the lanefix lesson).  That is the
--     gate's job.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local CM      = 'bots/BotLib/hero_crystal_maiden.lua'
local FRAME   = 'tests/fixtures/f_113638_cm_chain_rescue.lua'
local CAND_ID = 'cmclone'

local CLONE = 'crystal_maiden_crystal_clone'
local INNATE = 'crystal_maiden_glacial_guard'
local ULT   = 'crystal_maiden_freezing_field'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE counting anything: the reasoning block in the
--- hero file quotes every name and every id it explains, and a parser that reads
--- prose reports the prose (GH #136's first census).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

local function load_cm(bArmed, bTurbo)
    local J, bot = rf.load(FRAME)

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(sId) return sId == CAND_ID end
        or function() return false end

    return rf.load_hero('crystal_maiden'), J, bot
end

-- ---------------------------------------------------------------------------
-- Crystal Maiden's real slot order, and a synthetic bot that serves it to the
-- shipped walk.  Fabricated handles are declared as such: no .dem carries slot
-- order, and section 5 is where that limit is pinned.

local SLOTS = {
    [0] = { name = 'crystal_maiden_crystal_nova' },
    [1] = { name = 'crystal_maiden_frostbite' },
    [2] = { name = 'crystal_maiden_brilliance_aura' },
    [3] = { name = CLONE,  optional = 'clone' },
    [4] = { name = INNATE, optional = 'innate' },
    [5] = { name = ULT,    ult = true },
}

--- @param tDrop table  which optional abilities the walk drops in this world
local function make_cm(tDrop)
    local nNotLearnable = DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE
    assert(type(nNotLearnable) == 'number' and nNotLearnable > 0,
        'the NOT_LEARNABLE constant must be a real number for this enumeration to mean anything')

    local function ability(sName, bDropped, bUlt)
        return api.MakeUnit{
            GetName     = sName,
            IsUltimate  = bUlt == true,
            IsTalent    = false,
            IsHidden    = bDropped == true,
            GetBehavior = bDropped and nNotLearnable or 0,
        }
    end

    return api.MakeUnit{
        GetUnitName = 'npc_dota_hero_crystal_maiden',
        GetAbilityInSlot = function(_, nSlot)
            local t = SLOTS[nSlot]
            if t ~= nil then
                return ability(t.name, t.optional ~= nil and tDrop[t.optional] == true, t.ult)
            end
            -- Empty engine slots hold generic_hidden and the walk KEEPS those
            -- (slot ~= 0), so leaving them out would make the tail of the list
            -- shorter than the engine's.
            return ability('generic_hidden', false, false)
        end,
    }
end

local WORLDS = {}
for _, bClone in ipairs({ false, true }) do
    for _, bInnate in ipairs({ false, true }) do
        table.insert(WORLDS, { clone = bClone, innate = bInnate })
    end
end

local function world_label(w)
    return 'dropped{clone=' .. tostring(w.clone) .. ',innate=' .. tostring(w.innate) .. '}'
end

-- ---------------------------------------------------------------------------
-- One pass over tests/fixtures/, used by sections 2 and 3.  Every hero entry
-- counts, alive or dead: the dumped ability array is present either way.

local scanned = nil

local function scan()
    if scanned then return scanned end
    local r = {}
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)

    for _, path in ipairs(files) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                local h = tostring(u.name):match('^npc_dota_hero_(.+)$')
                if h then
                    local acc = r[h]
                    if not acc then
                        acc = { frames = 0, with = 0, names = {}, entries = {},
                                ult_on_cd = 0 }
                        r[h] = acc
                    end
                    acc.frames = acc.frames + 1
                    if u.abilities ~= nil then
                        acc.with = acc.with + 1
                        local nReal = 0
                        for _, a in ipairs(u.abilities) do
                            acc.names[a.name] = (acc.names[a.name] or 0) + 1
                            if not tostring(a.name):match('^special_bonus') then
                                nReal = nReal + 1
                            end
                            if a.name == ULT and (a.cd or 0) > 0 then
                                acc.ult_on_cd = acc.ult_on_cd + 1
                            end
                        end
                        acc.entries[nReal] = (acc.entries[nReal] or 0) + 1
                    end
                end
            end
        end
    end
    scanned = r
    return r
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The disjunction, computed by the shipped walk in all four worlds.

tests['[hero] index 4 is Crystal Clone in only two of the four drop-worlds'] = function()
    local J = rf.load(FRAME)
    assert(#WORLDS == 4, 'the enumeration must be complete, got ' .. #WORLDS)

    local tSeen = {}
    for _, w in ipairs(WORLDS) do
        local list = J.Skill.GetAbilityList(make_cm(w))
        local sGot = tostring(list[4])
        tSeen[sGot] = (tSeen[sGot] or 0) + 1
        if w.clone then
            assert(list[4] ~= CLONE,
                'a dropped Crystal Clone cannot be at index 4 in ' .. world_label(w))
        else
            assert(list[4] == CLONE,
                'a kept Crystal Clone must land at index 4 in ' .. world_label(w)
                    .. ', got ' .. tostring(list[4]))
        end
    end

    -- What index 4 DOES carry is recorded here rather than in prose, so the
    -- assertion above cannot pass for a boring reason.  Note the fourth world:
    -- it is NOT nil.  The walk name-checks `generic_hidden` (aba_skill.lua:5 is
    -- a file-local string, so the branch really does fire) BEFORE it applies the
    -- NOT_LEARNABLE/IsHidden drop rule, so an empty engine slot is kept whatever
    -- its flags say -- and with three abilities in front of the fixed index 6,
    -- the `#` border lands the first placeholder squarely on index 4.
    assert(tSeen[CLONE] == 2,
        'expected Crystal Clone at index 4 in the two worlds that keep the shard grant, got '
            .. tostring(tSeen[CLONE]))
    assert(tSeen[INNATE] == 1,
        'expected the INNATE at index 4 in the one world that drops the grant and keeps it, got '
            .. tostring(tSeen[INNATE]))
    assert(tSeen['generic_hidden'] == 1,
        'expected the empty-slot placeholder at index 4 in the one world that drops both, got '
            .. tostring(tSeen['generic_hidden']))
    assert(tSeen['nil'] == nil,
        'index 4 is nil in ' .. tostring(tSeen['nil']) .. ' world(s) on this VM; it was nil in '
            .. 'none. That is a `#`-border change (see the WORLD ASSERTION below) and it '
            .. 'moves the ungated nil guard from insurance to repair -- re-state both.')
end

tests['[hero] the walk keeps the empty-slot placeholder by NAME, before the drop rule'] = function()
    -- The fourth world above is only "generic_hidden" and not "nil" because of
    -- the ordering inside the walk, so the ordering is pinned rather than
    -- inferred from the outcome.
    local src = read_file('bots/FunLib/aba_skill.lua')
    assert(src:find("local generic_hidden = 'generic_hidden'", 1, true),
        'aba_skill.lua no longer defines the generic_hidden file-local. If it became an '
            .. 'undefined global the comparison at the head of the walk is `name == nil`, '
            .. 'never true, and placeholders would fall through to the drop rule instead.')
    local sWalk = src:match('function X%.GetAbilityList%b()(.-)\nend\n')
    local nName = sWalk:find('if name == generic_hidden then', 1, true)
    local nDrop = sWalk:find('DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE', 1, true)
    assert(nName and nDrop and nName < nDrop,
        'the generic_hidden name check must run BEFORE the NOT_LEARNABLE/IsHidden drop '
            .. 'rule -- that ordering is why an empty slot can occupy index 4 at all')
    assert(sWalk:find('if slot ~= 0 then', 1, true),
        'the walk no longer spares slot 0 from the placeholder insert')
end

tests['[hero] the ultimate reaches the fixed index 6 in every world'] = function()
    -- Whatever else moves, index 6 must stay the ultimate: `abilityR` is bound
    -- from it and the only Freezing Field cast site in the repo reads that
    -- handle.  This is also the premise section 3 leans on.
    local J = rf.load(FRAME)
    for _, w in ipairs(WORLDS) do
        local list = J.Skill.GetAbilityList(make_cm(w))
        assert(list[6] == ULT, 'sAbilityList[6] is ' .. tostring(list[6]) .. ' in '
            .. world_label(w) .. ', expected the ultimate')
    end
end

tests['[hero] the walk really is index-shifting, not slot-addressed'] = function()
    -- If the walk kept every ability at its slot index this whole axis would be
    -- empty, so the shifting itself is pinned rather than assumed.
    local J = rf.load(FRAME)
    local kept = J.Skill.GetAbilityList(make_cm({}))
    assert(kept[4] == CLONE, 'with nothing dropped, slot 3 lands at index 4, got '
        .. tostring(kept[4]))
    assert(kept[5] == INNATE, 'and slot 4 lands at index 5, got ' .. tostring(kept[5]))
    assert(kept[6] == ULT, 'the ultimate takes the fixed index 6, got ' .. tostring(kept[6]))

    local both = J.Skill.GetAbilityList(make_cm({ clone = true, innate = true }))
    assert(both[3] == 'crystal_maiden_brilliance_aura',
        'index 3 is the aura whatever happens above it, got ' .. tostring(both[3]))
    assert(both[4] == 'generic_hidden',
        'dropping both optional abilities hands index 4 to the empty-slot placeholder, got '
            .. tostring(both[4]))
    assert(both[6] == ULT, 'and the ultimate still holds the fixed index 6, got '
        .. tostring(both[6]))
end

tests['WORLD ASSERTION: the index arithmetic rests on `#` over a table with a hole'] = function()
    -- GetAbilityList writes the ultimate to the fixed index 6 and keeps
    -- appending with table.insert afterwards, so every later insert asks `#`
    -- about a table with a hole -- UNSPECIFIED in Lua 5.1, and this hero is
    -- where that stops being academic.  On THIS VM `#{1,2,3,[6]}` answers 3, so
    -- the first empty-slot placeholder lands on index 4 -- Crystal Clone's slot.
    -- A VM answering 6 would append past the hole instead and index 4 would be
    -- nil, which is the world the ungated nil guard is written for.  Both
    -- answers are legal, the engine's is not readable from here, and neither is
    -- Crystal Clone: that this file cannot say which failure ships is itself the
    -- argument for not counting indices at all.
    --
    -- ⚠️ Note the contrast with the Zeus half (GH #203): there the table was
    -- {1,2,3,4,[6]} and this VM answered 6.  Same VM, same idiom, opposite
    -- answer, because the border moved with the table -- so "the VM answers 6"
    -- is NOT a fact about the VM that may be carried between heroes.
    local t = { 'a', 'b', 'c' }
    t[6] = 'ult'
    assert(#t == 3, 'this VM used to answer 3 for #{1,2,3,[6]}; it now answers ' .. #t
        .. ' -- re-run the world enumeration before citing any index in this file')
    local t2 = { 'a', 'b', 'c', 'd' }
    t2[6] = 'ult'
    assert(#t2 == 6, 'this VM used to answer 6 for #{1,2,3,4,[6]} (the Zeus case); it now '
        .. 'answers ' .. #t2 .. ' -- GH #203 reasons from that value')

    local src = read_file('bots/FunLib/aba_skill.lua')
    local sWalk = src:match('function X%.GetAbilityList%b()(.-)\nend\n')
    assert(sWalk, 'X.GetAbilityList not found')
    assert(sWalk:find('sAbilityList%[6%] = name'), 'the fixed-index write must still be there')
    assert(sWalk:find('table.insert(sAbilityList, name)', 1, true),
        'and the appends that run after it')
    assert(sWalk:find('ability:IsUltimate() and slot >= 4', 1, true),
        'the ultimate is no longer forced to index 6 by an `IsUltimate() and slot >= 4` '
            .. 'test; section 3 reasons from that exact literal')
end

-- ---------------------------------------------------------------------------
-- 2. The corpus reads IsHidden in ONE direction, and that picks the world.

tests['[corpus] the dumper filters hidden abilities -- presence is a read of IsHidden'] = function()
    -- This is the bridge the whole section rests on, so it is asserted against
    -- the dumper source rather than remembered.
    local src = read_file('tools/batch_test/behavioral/dumper/main.go')
    local a = src:find('func isRealAbility(', 1, true)
    assert(a, 'isRealAbility is gone from the dumper; the bridge below has no source')
    local b = src:find('\nfunc ', a + 1)
    local fn = src:sub(a, (b or #src) - 1)
    assert(fn:find('if hidden {\n\t\treturn false\n\t}', 1, true),
        'the dumper no longer drops hidden abilities. If that filter went away, every '
            .. '"absent from the corpus" reading in this file loses its meaning and the '
            .. 'Crystal Maiden world set widens back to four.')
    assert(src:find('m_bHidden', 1, true),
        'the dumper no longer reads m_bHidden; say what it reads instead')
    assert(src:find('slotPath("m_vecAbilities"', 1, true),
        'the dumper no longer walks m_vecAbilities -- that it walks the SAME vector '
            .. 'GetAbilityInSlot exposes is why its filter says anything about the bot API')
end

tests['[corpus] the pipeline DOES show innates -- WK 33/33 and Lion 23/23'] = function()
    -- The control.  Without it, "Crystal Maiden's innate is absent" and "this
    -- pipeline cannot show an innate" look identical.
    --
    -- Stated over the LIVE denominator since 2026-08-28 (GH #274): the claim is
    -- "on every frame that dumps an array", and as an equality against a
    -- remembered 31 it went red when b50a7727 grew the WK corpus without any of
    -- it becoming false.
    local r = scan()
    cs.universal(r.skeleton_king.names.skeleton_king_innate_vampiric_spirit or 0,
        r.skeleton_king.with, "Wraith King's innate", 33)
    cs.universal(r.lion.names.lion_innate_to_hell_and_back or 0,
        r.lion.with, "Lion's innate", 23)
    -- and a grant, so a grant's zero is readable too.  RE-MEASURED 2026-09-03
    -- (GH #458): 2 frames, raised from 1 on 2026-09-03T13:30Z when
    -- f_260903_101254_cm_farm_stealcamp.lua landed -- the message still said
    -- "recorded 1" after that bump, so it is restated here.  Held as a ratchet
    -- for the same reason as its twin in
    -- tests/test_focus_innate_index_anchor.lua: the readable content is that
    -- the count is NON-ZERO, and `==` additionally pinned the corpus size.
    cs.ratchet(r.zuus.names.zuus_lightning_hands or 0, 2,
        'zuus_lightning_hands frames. These are the only proof this corpus can '
            .. 'show a granted ability at all; without them the Crystal Clone zero '
            .. 'below is UNMEASURABLE rather than zero.')
end

tests['[corpus] Crystal Maiden carries neither optional ability on any frame'] = function()
    local r = scan()
    local cm = r.crystal_maiden
    cs.ratchet(cm.frames, 53, 'Crystal Maiden entries in tests/fixtures/')
    cs.universal(cm.with, cm.frames,
        'Crystal Maiden entries dumping an ability array', 53)
    assert(cm.names[CLONE] == nil,
        CLONE .. ' now appears on ' .. tostring(cm.names[CLONE]) .. ' frames. That is a '
            .. 'frame where the shard grant was NOT hidden -- the world set narrows with '
            .. 'evidence instead of enumeration, so re-derive section 1 before citing it.')
    assert(cm.names[INNATE] == nil,
        INNATE .. ' now appears on ' .. tostring(cm.names[INNATE]) .. ' frames')
    for name in pairs(cm.names) do
        assert(not name:find('_innate_', 1, true),
            'Crystal Maiden grew an _innate_ ability entry (' .. name .. '), the shape '
                .. 'Wraith King and Lion have. Her innate would then be KEPT by the walk '
                .. 'and index 4 becomes it rather than nil.')
    end
    -- exactly four real abilities on every frame that has an array
    cs.universal(cm.entries[4] or 0, cm.with,
        'Crystal Maiden frames dumping exactly four real abilities', 53)
end

-- ---------------------------------------------------------------------------
-- 3. The corpus CONFIRMS the slot order rather than assuming it.

tests['[corpus] her ultimate was cast, so an optional ability really sits ahead of it'] = function()
    local r = scan()
    assert(r.crystal_maiden.ult_on_cd == 10,
        "Crystal Maiden's ultimate is on cooldown on " .. r.crystal_maiden.ult_on_cd
            .. ' frames, recorded 10 of 53. That count is the whole slot-order argument: '
            .. 'if it reaches zero, re-state the order as ASSUMED.')

    -- The argument, made executable rather than left in prose: with only the
    -- three always-visible abilities in front of it, the ultimate would sit at
    -- slot 3, fail `slot >= 4`, and fall through to table.insert -- leaving
    -- index 6 nil and Freezing Field uncastable.
    local J = rf.load(FRAME)
    local tShort = {
        [0] = { name = 'crystal_maiden_crystal_nova' },
        [1] = { name = 'crystal_maiden_frostbite' },
        [2] = { name = 'crystal_maiden_brilliance_aura' },
        [3] = { name = ULT, ult = true },
    }
    local hShort = api.MakeUnit{
        GetUnitName = 'npc_dota_hero_crystal_maiden',
        GetAbilityInSlot = function(_, nSlot)
            local t = tShort[nSlot]
            return api.MakeUnit{
                GetName = t and t.name or 'generic_hidden',
                IsUltimate = t ~= nil and t.ult == true,
                IsTalent = false, IsHidden = false, GetBehavior = 0,
            }
        end,
    }
    local list = J.Skill.GetAbilityList(hShort)
    assert(list[6] ~= ULT,
        'with the ultimate at slot 3 the walk still put it at index 6. The counterfactual '
            .. 'this section refutes is no longer refutable -- re-derive the slot order.')
    assert(list[4] == ULT,
        'with the ultimate at slot 3 it should be APPENDED to index 4, got '
            .. tostring(list[4]))
    -- (index 6 is the placeholder tail here, not nil -- same `#`-border effect
    -- as section 1's fourth world.  What matters is only that it is not the
    -- ultimate, so `abilityR` would be bound to something uncastable.)

    -- and the shipped order does write index 6, in every world
    for _, w in ipairs(WORLDS) do
        assert(J.Skill.GetAbilityList(make_cm(w))[6] == ULT,
            'the datafeed order must write index 6 in ' .. world_label(w))
    end
end

-- ---------------------------------------------------------------------------
-- 4. Source ratchets: where the correction may live, and what the nil check is
--    and is NOT.

tests['[hero] the helper is gated, turbo-only, and ends on the shipped handle'] = function()
    local src = strip_comments(read_file(CM))

    local sHelper = src:match('function X%.GetBoundAbility%b()(.-)\nend')
    assert(sHelper, 'X.GetBoundAbility is gone from hero_crystal_maiden.lua; every call '
        .. 'site would be ungated')
    assert(sHelper:find("IsSoakCandidate( '" .. CAND_ID .. "' )", 1, true),
        'the correction must sit behind IsSoakCandidate(' .. CAND_ID .. ')')
    assert(sHelper:find('IsModeTurbo', 1, true),
        'and behind IsModeTurbo (turbo-only, AGENTS.md)')
    assert(sHelper:find('GetAbilityByName( sName )', 1, true),
        'armed, it must resolve the handle BY NAME')

    local sTail = sHelper:match('(return[^\n]*)%s*$')
    assert(sTail and sTail:find('hShipped', 1, true),
        "the helper must END on the caller's shipped handle -- that is what makes gate-off "
            .. 'equivalence structural; got ' .. tostring(sTail))
    assert(sHelper:find('hNamed ~= nil', 1, true),
        'the armed branch must check the resolved handle before returning it (GH #162: a '
            .. 'silent nil is not a value)')
end

tests['[hero] both consumers of the index-bound handle go through the helper'] = function()
    local src = strip_comments(read_file(CM))

    -- The declaration itself is the only bare use that may remain.  The three
    -- longer names built on the same stem (ConsiderCrystalClone,
    -- CrystalCloneDesire, CrystalCloneLocation) are removed first rather than
    -- excluded by a character class -- a class of "not D, not L" silently counts
    -- `ConsiderCrystalClone(` as a bare use, which is how the first cut of this
    -- assertion read 3 and blamed the routing.
    local sBare = src:gsub('X%.ConsiderCrystalClone', '')
                     :gsub('CrystalCloneDesire', '')
                     :gsub('CrystalCloneLocation', '')
                     :gsub('X%.GetBoundAbility%( CrystalClone', '')
    local nBare = select(2, sBare:gsub('CrystalClone', ''))
    assert(nBare == 1, 'CrystalClone may appear outside the helper exactly once (its own '
        .. 'declaration), got ' .. nBare)

    assert(select(2, src:gsub("X%.GetBoundAbility%( CrystalClone, '" .. CLONE .. "' %)", '')) == 2,
        'both call sites -- the consider and the queued order -- must be routed; routing '
            .. 'only one would let the desire and the order disagree about which ability '
            .. 'they are talking about')
    assert(src:find('local CrystalClone = bot:GetAbilityByName( sAbilityList[4] )', 1, true),
        'the shipped index-4 binding must stay exactly as it was -- it is the gate-off leg')
end

tests['[hero] the nil check is ungated and runs before anything indexes the handle'] = function()
    local src = strip_comments(read_file(CM))
    local sFn = src:match('function X%.ConsiderCrystalClone%(%)(.-)\nend')
    assert(sFn, 'X.ConsiderCrystalClone is gone')

    local nNil = sFn:find('hClone == nil', 1, true)
    assert(nNil, 'X.ConsiderCrystalClone must bail on a nil handle')
    local nTrained = sFn:find('hClone:IsTrained()', 1, true)
    assert(nTrained and nNil < nTrained,
        'the nil check must run BEFORE IsTrained() indexes the handle')
    assert(not sFn:find('IsSoakCandidate', 1, true),
        'the nil check is the UNGATED half (GH #188 / #192 / #203: forced repairs ship, '
            .. 'policy ships gated) -- no gate may appear in this function body')
end

tests['[hero] and it is insurance, not the repair of an observed crash'] = function()
    -- Recorded because it is the easiest thing for a later summary to get wrong.
    -- If the shipped code were dying on a nil handle, Freezing Field would never
    -- be cast: X.ConsiderCrystalClone sits ABOVE ConsiderQ/W/R in the dispatch,
    -- and the only ActionQueue site for abilityR in the repo is below it.
    local src = strip_comments(read_file(CM))
    local nClone = src:find('CrystalCloneDesire, CrystalCloneLocation = X.ConsiderCrystalClone()', 1, true)
    local nR = src:find('bot:ActionQueue_UseAbility( abilityR )', 1, true)
    assert(nClone and nR and nClone < nR,
        'the Crystal Clone branch is no longer above the ultimate dispatch; the '
            .. 'counter-observation in this file assumed it was')
    assert(select(2, src:gsub('abilityR%s*%)', '')) >= 1,
        'abilityR no longer reaches a cast order at all')

    local r = scan()
    assert(r.crystal_maiden.ult_on_cd > 0,
        'the corpus no longer shows Freezing Field on cooldown, so the dispatch is no '
            .. 'longer known to survive this branch. The nil check would then be a repair '
            .. 'rather than insurance -- and that is a stronger claim needing its own frame.')
end

-- ---------------------------------------------------------------------------
-- 5. The helper's behaviour, on both legs.

tests['gate off: the shipped handle comes back untouched'] = function()
    local X = load_cm(false, true)
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, CLONE) == hShipped,
        'gate off must be the shipped handle, by identity')
end

tests['gate off: a nil shipped handle stays nil rather than being papered over'] = function()
    local X = load_cm(false, true)
    assert(X.GetBoundAbility(nil, CLONE) == nil,
        'gate off must not invent a handle -- the nil world is the shipped world and the '
            .. 'consider function is where it is answered')
    assert(X.ConsiderCrystalClone ~= nil)
end

tests['gate on: the handle is resolved by name'] = function()
    local X = load_cm(true, true)
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, CLONE):GetName() == CLONE,
        'armed, the handle must be the one named ' .. CLONE)
    assert(X.GetBoundAbility(nil, CLONE):GetName() == CLONE,
        'armed, a nil shipped handle must still resolve -- that is the whole point')
end

tests['gate on but NOT turbo: unchanged (turbo-only, AGENTS.md)'] = function()
    local X = load_cm(true, false)
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, CLONE) == hShipped,
        'the correction is turbo-only')
    assert(X.GetBoundAbility(nil, CLONE) == nil, 'and that includes the nil leg')
end

tests['gate on, engine cannot resolve the name: falls back, never returns a surprise'] = function()
    local X, _, bot = load_cm(true, true)
    bot.GetAbilityByName = function() return nil end
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, CLONE) == hShipped,
        'an unresolvable name must fall back to the shipped handle')
    assert(X.GetBoundAbility(nil, CLONE) == nil,
        'and when the shipped handle is nil too, the answer is nil -- which the ungated '
            .. 'check in X.ConsiderCrystalClone is there to absorb')
end

tests['the ungated nil check costs the branch, not the tick'] = function()
    for _, bArmed in ipairs({ false, true }) do
        local X, _, bot = load_cm(bArmed, true)
        bot.GetAbilityByName = function() return nil end
        -- rebuild the file-local binding under a nil-answering engine
        local Y = rf.load_hero('crystal_maiden')
        local ok, desire = pcall(Y.ConsiderCrystalClone)
        assert(ok, 'X.ConsiderCrystalClone raised on a nil handle (armed=' .. tostring(bArmed)
            .. '): ' .. tostring(desire) .. '. Inside X.SkillsComplement that is a silent '
            .. 'whole-tick abort and it takes ConsiderQ/W/R with it.')
        assert(desire == BOT_ACTION_DESIRE_NONE,
            'a nil handle must answer NONE, got ' .. tostring(desire))
        assert(X ~= nil)
    end
end

-- ---------------------------------------------------------------------------
-- 6. The limit that bounds every claim above.

tests['LIMIT: the fixture corpus cannot supply slot order'] = function()
    local J, bot, _, fx = rf.load(FRAME)
    local tCM
    for _, u in ipairs(fx.units) do
        if u.name == 'npc_dota_hero_crystal_maiden' then tCM = u.abilities end
    end
    assert(tCM ~= nil and #tCM > 0, 'the frame must carry a Crystal Maiden ability array at all')

    for _, a in ipairs(tCM) do
        assert(a.name ~= CLONE and a.name ~= INNATE,
            'the frame now carries ' .. a.name .. '; section 2 must be re-measured')
    end

    -- And the live consequence, which is why the fixture world cannot decide the
    -- binding on its own: the shipped walk over the REAL frame produces no
    -- Crystal Clone entry anywhere.  (It does produce a talent at index 4 --
    -- the mock's IsTalent() is a constant false, GH #151 section 3 -- which is a
    -- fact about the harness, recorded in test_focus_innate_index_anchor.lua
    -- section 6 and deliberately not leaned on here.)
    local list = J.Skill.GetAbilityList(bot)
    for i = 1, 6 do
        assert(list[i] ~= CLONE, 'no fixture-world index may carry ' .. CLONE)
    end
end

return tests
