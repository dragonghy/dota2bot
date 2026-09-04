-- [hero] Crystal Maiden's t10 pair, examined and DELIBERATELY NOT FLIPPED.
--
-- The focus-five talent ladder re-anchor (tests/test_focus_talent_anchor.lua,
-- GH #104/#115/#122) has now flipped three pairs -- Axe t10, Zeus t15, Lion t10
-- -- each on PAYOFF REACHABILITY: the rejected side could only be collected
-- through a conjunction of conditions this codebase rarely satisfies, while the
-- taken side had no predicate at all.  CM's t10 is the pair where that ruler
-- returns NO FLIP, and this file exists so the decision is not re-litigated on
-- taste, and so the evidence that WOULD reopen it is written down as assertions
-- rather than prose.
--
--   [1] special_bonus_hp_200      +200 health        <- SHIPPED, unchanged
--   [2] special_bonus_intelligence_12   +12 Intelligence
--
-- WHY NOT, IN ORDER OF WEIGHT
--
-- 1. The mana side's payoff IS measurable and it is real: on the 12 corpus
--    frames where CM is at or above level 10 (below that NEITHER talent
--    exists), 11 of 26 ready ability slots -- trained, off cooldown -- cannot
--    pay their own mana cost, and 9 of those 11 sit inside the +144 mana that
--    +12 INT buys (7 at +120, 11 at +168, so the reading does not hang off the
--    12-mana-per-INT constant).  That is a wide, non-narrow-band domain.
-- 2. The health side's payoff is NOT measurable here, which is NOT the same as
--    absent.  Its collection point is surviving damage, and the corpus has ZERO
--    CM-subject frames at level >= 10 -- observed.burst/died_after exist only
--    for a fixture's subject -- so the channel that would price it has no
--    samples at all.  Per GH #115's standing rule a zero from an underpowered
--    channel is UNDERPOWERED, not EMPTY, and may not be spent as evidence.
-- 3. Condition (c) of the validation philosophy points the other way.  Standard
--    play prefers +200 Health on CM precisely because she is the squishiest
--    hero on the map and her mana can be bought with items, while her
--    durability mostly cannot (dota2.fandom.com/wiki/Crystal_Maiden/Talents and
--    the guide corpus around it, read 2026-08-23).  A flip here would ship
--    against BOTH the default and the searchable consensus, on the strength of
--    a channel that is half blind (see 4).
-- 4. The instrument's own blindness, measured rather than assumed.  Driving the
--    real X.SkillsComplement() in all three worlds queues NOTHING on any of the
--    12 in-domain frames, so the decision channel -- the strongest one -- is
--    silent for BOTH sides.  Part of that is the corpus (7 of 12 frames have no
--    enemy hero within 1600), and part of it is structural: in the fixture
--    world GetActiveMode() answers 0 while every BOT_MODE_* constant is a
--    distinct auto-sentinel >= 1001, so `== BOT_MODE_LANING` is FALSE on every
--    frame and `~= BOT_MODE_RETREAT` is TRUE on every frame.  hero_crystal_
--    maiden.lua puts four of its eight mana thresholds inside mode-EQUALITY
--    blocks (the two laning ones at :746, the two Roshan ones at :567/:887), so
--    exactly the branches where the mana talent would pay cannot fire offline.
--    That blindness is NOT new: it is the repo's THIRTEENTH world assertion,
--    already carried by tests/test_activemode_world_assertion.lua (which also
--    measures the loader half this file does not: GetNearbyHeroes' replacement
--    ignores its mode argument, so mode-FILTERED calls are over-permissive).
--    Re-pinned below only at CM's own site, because it is what makes this
--    pair's decision-channel zero unreadable rather than informative.
--
-- WHAT WOULD REOPEN IT (each is an assertion in this file, not a promise):
--   * the +200 HP world crossing ANY of the file's own nHP thresholds on a real
--     frame -- today it crosses zero, while the +12 INT world crosses five;
--   * CM-subject frames at level >= 10 appearing in the corpus, i.e. the death
--     channel gaining samples;
--   * the shipped mana reserve (nKeepMana) or the pos_5 build changing, since
--     both decide how much of the pool is spendable.
--
-- HONEST BOUNDS
--   * The fixture library is curated for other investigations: existence, not
--     density.  12 in-domain frames is a floor on nothing.
--   * The counterfactual is STATIC: it adds 144 mana to a frame whose history
--     would itself have differed had CM owned the talent all game.  It is an
--     upper bound on the flip rate, not a rate.
--   * Mana regen per INT (+0.05/point, possibly 0.04) and +12 attack damage
--     (INT is CM's primary attribute) are not modelled.  Both omissions
--     UNDERSTATE the side this file declines to take, and it declines anyway.
--   * Mana costs are external anchors (datafeed hero_id=5, 2026-08-23); the
--     dump carries no ability specs.  Section "anchors" pins that they are
--     actually in force, because with the mock's default 0 the whole mana
--     channel would read "everything affordable" and quietly agree with itself.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local BOTLIB = 'bots/BotLib/'
local HERO   = BOTLIB .. 'hero_crystal_maiden.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a'); fh:close()
    return s
end

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_cm_t10_payoff_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line)')
    local c, rows, delta, thresh = {}, {}, {}, { mana = {}, hp = {} }
    local xmana, xhp, deaths, slots, worlds = {}, {}, {}, {}, {}
    for line in text:gmatch('[^\n]+') do
        local k, v = line:match('^C ([%w_]+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        local dk, dv = line:match('^DELTA (%d+) (%d+)$')
        if dk then delta[tonumber(dk)] = tonumber(dv) end
        local tk, tv = line:match('^THRESH (%w+) (%S+)$')
        if tk then thresh[tk][#thresh[tk] + 1] = tv end
        local f, lv, hp, maxhp, mp, maxmp, d0, dH, dI =
            line:match('^ROW (%S+) (%d+) (%d+) (%d+) (%d+) (%d+) (%S+) (%S+) (%S+)$')
        if f then
            rows[#rows + 1] = { fix = f, lv = tonumber(lv), hp = tonumber(hp),
                maxhp = tonumber(maxhp), mp = tonumber(mp), maxmp = tonumber(maxmp),
                d0 = d0, dH = dH, dI = dI }
        end
        local mf, mt = line:match('^XMANA (%S+) (%S+)$')
        if mf then xmana[#xmana + 1] = { fix = mf, gate = mt } end
        local hf, ht = line:match('^XHP (%S+) (%S+)$')
        if hf then xhp[#xhp + 1] = { fix = hf, gate = ht } end
        local df, dhp, burst, died, saved =
            line:match('^DEATH (%S+) (%d+) (%d+) ([%d%.]+) (%d)$')
        if df then
            deaths[#deaths + 1] = { fix = df, hp = tonumber(dhp), burst = tonumber(burst),
                died = tonumber(died), saved = saved == '1' }
        end
        local wf, wk, whp, wmaxhp, wmp, wmaxmp =
            line:match('^WORLD (%S+) (%S+) (%d+) (%d+) (%d+) (%d+)$')
        if wf then
            worlds[wf] = worlds[wf] or {}
            worlds[wf][wk] = { hp = tonumber(whp), maxhp = tonumber(wmaxhp),
                mp = tonumber(wmp), maxmp = tonumber(wmaxmp) }
        end
        local sf, sa, sr, sc, smp, sb, sfl =
            line:match('^SLOT (%S+) (%S+) (%d+) (%d+) (%d+) (%d) (%d)$')
        if sf then
            slots[#slots + 1] = { fix = sf, ability = sa, rank = tonumber(sr),
                cost = tonumber(sc), mp = tonumber(smp), blocked = sb == '1',
                flip = sfl == '1' }
        end
    end
    return c, rows, delta, thresh, xmana, xhp, deaths, slots, worlds
end

local C, ROWS, DELTA, THRESH, XMANA, XHP, DEATHS, SLOTS, WORLDS = sweep()

local tests = {}

-- ---------------------------------------------------------------------------
-- 0. The corpus the numbers are quoted from, and the domain inside it.

tests['[hero] census: CM frames, and how few of them are in the talent domain'] = function()
    assert(C.cm_frames >= 42,
        'the corpus lost CM frames (' .. tostring(C.cm_frames) .. ' < 42); every '
        .. 'number in this file was read off a corpus that had at least that many')
    assert(C.cm_below_t10 + C.cm_at_or_above_t10 == C.cm_frames,
        'the level split must partition the CM frames')
    assert(C.cm_at_or_above_t10 >= 12,
        'in-domain CM frames: ' .. tostring(C.cm_at_or_above_t10) .. ' (was 12)')
    -- The bound that matters more than any count here: most CM frames in this
    -- corpus are BELOW the level where either talent exists.
    assert(C.cm_below_t10 > C.cm_at_or_above_t10,
        'the corpus is no longer dominated by sub-level-10 CM frames ('
        .. tostring(C.cm_below_t10) .. ' below vs ' .. tostring(C.cm_at_or_above_t10)
        .. ' at/above). The "domain is thin" caveat this decision leans on has '
        .. 'moved -- re-read it before quoting it.')
    assert(#ROWS == C.cm_at_or_above_t10, 'one ROW per in-domain frame')
end

-- ---------------------------------------------------------------------------
-- 1. The anchors, asserted rather than trusted.
--
-- With the mock's default answer of 0 for un-stubbed Get* (world assertion #13)
-- every ability costs nothing, IsFullyCastable() is mana-blind, and the entire
-- mana channel reads "nothing was ever blocked" -- a green, fast, all-zero
-- agreement with itself. This section is what stands between that and a claim.

--- RECONCILED 2026-09-01 (hero).  This case used to assert the loader answers
--- ZERO here, because when it was written the sweep's datafeed table was the
--- only source of a mana cost in the tree and the assertion's job was to stop a
--- second, silent one appearing underneath it.  The tripwire fired as designed
--- the day tests/mock/replay_fixture.lua started charging the KV price
--- (mana_ladder, GH-less hero change of the same date), and its failure text
--- asked for exactly this: reconcile the two before trusting either.
---
--- They reconcile CLEANLY, and that is worth more than the silence it replaces.
--- The datafeed (hero_id=5, read 2026-08-23) and the game's own KV snapshot
--- (tests/mock/special_value_shapes.lua) are independent reads taken nine days
--- apart, and they agree digit for digit on all three of CM's costed abilities:
---     Crystal Nova   115/135/155/175
---     Frostbite      125/135/145/155
---     Freezing Field 200/400/600
--- So this section now asserts AGREEMENT rather than absence.  That is strictly
--- stronger: the old form could only notice a second source arriving, this one
--- notices it arriving and DISAGREEING -- which is the case that would actually
--- corrupt the sweep, since the sweep prices its own slots while the loader
--- prices IsFullyCastable.  A drift between them would put the CASTABLE channel
--- and the DECISION channel on different worlds without either going quiet.
tests['[hero] the mana-cost anchors are in force, and both sources agree'] = function()
    local FIX = 'tests/fixtures/f_260820_103644_necro_pinned_dying.lua'
    local _, bot = rf.load(FIX, 'npc_dota_hero_crystal_maiden')
    local nova = bot:GetAbilityByName('crystal_maiden_crystal_nova')
    assert(nova ~= nil, 'the frame must carry Crystal Nova')

    -- The loader must be charging SOMETHING: a silent 0 here is the world this
    -- whole section exists to keep out, and it is now reachable from the other
    -- direction (a mana_ladder that stops resolving).
    local nLoader = nova:GetManaCost() or 0
    assert(nLoader > 0,
        'the loader answers 0 for Crystal Nova, so IsFullyCastable() is mana-blind '
        .. 'again and the CASTABLE channel silently agrees with itself -- check '
        .. 'mana_ladder() in tests/mock/replay_fixture.lua')

    -- ... and it must charge the SAME thing this sweep does.
    local rank = nova:GetLevel()
    local anchored = ({ 115, 135, 155, 175 })[rank]
    assert(anchored ~= nil, 'Crystal Nova at an unanchored rank ' .. tostring(rank))
    assert(nLoader == anchored,
        'the loader prices Crystal Nova rank ' .. rank .. ' at ' .. nLoader
        .. ' while this sweep anchors it at ' .. anchored .. ' (datafeed hero_id=5, '
        .. '2026-08-23). The two cost sources have drifted -- the CASTABLE channel '
        .. 'below is priced by the sweep and the DECISION channel by the loader, so '
        .. 'a drift puts them on different worlds. Reconcile before trusting either.')

    assert(#SLOTS > 0, 'the sweep reported no ready ability slots at all')
    local nCosted = 0
    for _, s in ipairs(SLOTS) do if s.cost > 0 then nCosted = nCosted + 1 end end
    assert(nCosted == #SLOTS,
        'the sweep priced ' .. tostring(#SLOTS - nCosted) .. ' ready slots at 0 mana; '
        .. 'the datafeed anchor is not reaching them')
end

tests['[hero] world assertion: GetActiveMode is blind in every fixture world'] = function()
    local FIX = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
    local _, bot = rf.load(FIX, 'npc_dota_hero_crystal_maiden')
    assert(bot:GetActiveMode() == 0,
        'GetActiveMode now answers ' .. tostring(bot:GetActiveMode())
        .. ' instead of the mock default 0')
    assert(BOT_MODE_LANING ~= 0 and BOT_MODE_ROSHAN ~= 0 and BOT_MODE_NONE ~= 0,
        'BOT_MODE_* are no longer auto-sentinels; the blindness below may be fixed')
    -- The consequence, stated as the two halves it actually has.
    assert(not (bot:GetActiveMode() == BOT_MODE_LANING),
        'mode EQUALITY can now be true offline -- the laning branches of every '
        .. 'hero file just became reachable in fixtures. Re-read every '
        .. 'fixture-based domain reading that reported a zero.')
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT,
        'mode INEQUALITY can now be false offline -- branches that were always '
        .. 'open in fixtures are not any more.')
end

-- ---------------------------------------------------------------------------
-- 2. The mana side: what +12 INT actually buys, on real frames.

tests['[hero] +12 INT unblocks ready-but-unaffordable ability slots'] = function()
    assert(C.ready_slots >= 26, 'ready slots: ' .. tostring(C.ready_slots))
    assert(C.unaffordable_slots >= 1 and C.unaffordable_slots < C.ready_slots,
        'unaffordable ready slots: ' .. tostring(C.unaffordable_slots)
        .. ' of ' .. tostring(C.ready_slots))
    assert(C.castable_flips >= 1,
        'the +144 mana world unblocked nothing. Either the corpus moved or the '
        .. 'cost anchor stopped reaching the sweep -- check the anchors section '
        .. 'before reading this as "the talent buys nothing".')
    assert(C.castable_flips <= C.unaffordable_slots, 'a flip must be a blocked slot')
    -- All three spells, not one pathological row: the reading is about the pool,
    -- not about Freezing Field's 600.
    assert((C.flip_crystal_maiden_crystal_nova or 0) >= 1
        and (C.flip_crystal_maiden_frostbite or 0) >= 1,
        'the flips collapsed onto the ultimate; the "mana binds across her whole '
        .. 'kit" reading rests on Nova AND Frostbite also being blocked')
end

tests['[hero] the castability reading does not hang off the 12-mana-per-INT constant'] = function()
    assert(DELTA[120] and DELTA[144] and DELTA[168], 'all three sensitivity rows must be reported')
    assert(DELTA[120] <= DELTA[144] and DELTA[144] <= DELTA[168],
        'flips must be monotone in the mana delta (' .. tostring(DELTA[120]) .. '/'
        .. tostring(DELTA[144]) .. '/' .. tostring(DELTA[168])
        .. '); a non-monotone reading means the sweep is not measuring what it says')
    assert(DELTA[120] >= 1,
        'even the pessimistic +120 reading must keep the finding alive, or the '
        .. 'conclusion depends on an externally anchored constant')
end

-- ---------------------------------------------------------------------------
-- 3. The two sides through the SAME procedure -- the hero file's own gates.

tests['[hero] the file has thresholds on both resources, read out of the source'] = function()
    assert(#THRESH.mana >= 8, 'mana thresholds parsed: ' .. tostring(#THRESH.mana))
    assert(#THRESH.hp >= 4, 'hp thresholds parsed: ' .. tostring(#THRESH.hp))
    local src = read_file(HERO)
    assert(src:find('nKeepMana%s*=%s*220'),
        'the shipped mana reserve moved off 220. It is an ABSOLUTE floor, so how '
        .. 'much of a bigger pool is spendable moves with it -- re-run this sweep.')
    local bAbs, bFrac = false, false
    for _, t in ipairs(THRESH.mana) do
        if t:find('GetMana', 1, true) then bAbs = true end
        if t:find('nMP', 1, true) then bFrac = true end
    end
    assert(bAbs and bFrac,
        'the mana gates are no longer a mix of absolute and fraction tests; the '
        .. 'sweep models both on purpose')
end

tests['[hero] the asymmetry: +12 INT crosses shipped gates, +200 HP crosses none'] = function()
    assert((C.managate_crossings or 0) >= 1,
        'the +144 mana world crosses none of the file own gates any more ('
        .. tostring(C.managate_crossings) .. ')')
    assert((C.managate_frames or 0) >= 1 and C.managate_frames <= #ROWS,
        'frames with at least one mana crossing: ' .. tostring(C.managate_frames))
    -- THE RATCHET THIS FILE EXISTS FOR. Not a veto: a report.
    assert((C.hpgate_crossings or 0) == 0,
        'the +200 HP world now crosses ' .. tostring(C.hpgate_crossings)
        .. ' of hero_crystal_maiden.lua own nHP thresholds on a real frame. When '
        .. 'this decision was taken it crossed ZERO while the mana world crossed '
        .. 'five, and that asymmetry is the only measured thing on the health '
        .. 'side. REOPEN the t10 pair -- do not just relax this assertion.')
end

-- ---------------------------------------------------------------------------
-- 4. The channels that came back empty, and WHY -- so nobody spends the zeros.

tests['[hero] the decision channel is silent for BOTH worlds, and says so'] = function()
    assert((C.baseline_acted or 0) == 0,
        'the shipped file now queues an ability on some in-domain frame ('
        .. tostring(C.baseline_acted) .. '). The decision channel just came alive '
        .. '-- re-run both worlds against it, it outranks every other channel here.')
    assert((C.hp_world_changed or 0) == 0 and (C.int_world_changed or 0) == 0,
        'a talent world changed the queued decision; that is exactly the evidence '
        .. 'this decision lacked')
    assert((C.errors or 0) == 0,
        tostring(C.errors) .. ' world(s) raised instead of deciding; a silent '
        .. 'channel that is silent because it crashed proves nothing')
    -- Why it is silent, measured: this is what makes the zero UNDERPOWERED.
    assert((C.channel_no_enemy_1600 or 0) >= 1,
        'no in-domain frame is enemy-free any more; the "the corpus is mostly '
        .. 'quiet frames" half of the explanation no longer holds')
    for _, r in ipairs(ROWS) do
        assert(r.d0 == r.dH and r.d0 == r.dI,
            'per-frame: ' .. r.fix .. ' now decides differently across worlds ('
            .. r.d0 .. ' / ' .. r.dH .. ' / ' .. r.dI .. ')')
    end
end

tests['[hero] the three worlds the silent channel was asked in are really different'] = function()
    -- Mutation M4 escaped the first version of this file: with the decision
    -- channel silent on every frame, a sweep that stopped applying the talent
    -- shift at all read EXACTLY like one that applied it. A silence is only
    -- evidence if the thing being silent about was actually present.
    local nChecked = 0
    for _, r in ipairs(ROWS) do
        local w = WORLDS[r.fix]
        assert(w and w['0'] and w['H'] and w['I'],
            'no WORLD record for ' .. r.fix .. ' -- the sweep stopped reporting '
            .. 'what the hero file saw, and every zero below becomes unreadable')
        assert(w['H'].hp == w['0'].hp + 200 and w['H'].maxhp == w['0'].maxhp + 200,
            'world H is not +200 hp on ' .. r.fix .. ' (' .. w['0'].hp .. ' -> ' .. w['H'].hp .. ')')
        assert(w['I'].mp == w['0'].mp + 144 and w['I'].maxmp == w['0'].maxmp + 144,
            'world I is not +144 mana on ' .. r.fix .. ' (' .. w['0'].mp .. ' -> ' .. w['I'].mp .. ')')
        assert(w['H'].mp == w['0'].mp and w['I'].hp == w['0'].hp,
            'the worlds are not single-resource on ' .. r.fix .. '; each talent '
            .. 'must move exactly one pool or the comparison is not a comparison')
        nChecked = nChecked + 1
    end
    assert(nChecked >= 12, 'only ' .. nChecked .. ' frames carried world records')
end

tests['[hero] the death channel has no in-domain samples, so it prices nothing'] = function()
    -- 2026-09-03 (strategy, GH #455 work unit): the corpus gained its first
    -- CM-SUBJECT frame at level >= 10 --
    -- f_260903_101254_cm_farm_stealcamp.lua, cut to pin a camp-arbitration
    -- decision, not a fight. READ AND RE-DECIDED, per this assertion's own
    -- instruction, and the decision below is UNCHANGED. Why the frame prices
    -- nothing:
    --
    --   CM level 15, hp 1684/1684 (FULL), observed.burst = {} (nothing dealt
    --   her any damage in the 5s window), observed.died_after = 94.0s -- i.e.
    --   18.8 windows later, an unrelated event.
    --
    -- The sweep's own verdict on such a row is `bSaved = (nBurst < hp +
    -- HP_BONUS)` = `0 < 1884`, which is TRUE for every conceivable talent and
    -- therefore says nothing about this one. That is exactly the shape §2 of
    -- this file's header refuses to spend: a zero out of an underpowered
    -- channel is UNDERPOWERED, not EMPTY.
    --
    -- So the guard is TIGHTENED rather than merely re-pinned: what should
    -- reopen the +200 HP decision is a frame that can actually price it --
    -- one where CM took NONZERO burst -- not any CM-subject frame at all.
    -- A frame with burst > 0 still fails this assertion and still demands a
    -- re-read. Raising the count without this refinement would have been a
    -- pure loosening, which is what the header forbids.
    local nInformative = 0
    for _, d in ipairs(DEATHS) do
        if (d.burst or 0) > 0 then nInformative = nInformative + 1 end
    end
    assert(nInformative == 0,
        'the corpus now has ' .. nInformative .. ' CM-SUBJECT frame(s) at '
        .. 'level >= 10 carrying NONZERO observed.burst -- the channel that '
        .. 'can actually price +200 HP, and it was empty when this decision '
        .. 'was taken. Read it and re-decide.')
    -- The vacuous rows are still counted, so the denominator cannot go quiet.
    assert((C.cm_subject_frames or 0) == 1 and #DEATHS == 1,
        'CM-subject frames at level >= 10 moved to '
        .. tostring(C.cm_subject_frames) .. ' (' .. #DEATHS .. ' with a '
        .. 'died_after). Recorded 1 / 1 on 2026-09-03, both vacuous (zero '
        .. 'burst). If this grew, check whether the new rows are informative '
        .. 'via the assertion above before touching this number.')
end

-- ---------------------------------------------------------------------------
-- 5. The decision itself, in the source.

tests['[hero] CM t10 still takes +200 health, and the pair is unchanged'] = function()
    local src = read_file(HERO)
    local body = src:match('local tTalentTreeList = {(.-)\n}')
    assert(body, 'hero_crystal_maiden.lua has no tTalentTreeList literal')
    local a, b = body:match("%['t10'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}")
    assert(a and b, 'the t10 row is no longer a two-number literal')
    assert(tonumber(a) == 0 and tonumber(b) == 10,
        'CM t10 is now {' .. a .. ',' .. b .. '}, i.e. it takes sTalentList[2] '
        .. '(+12 Intelligence). That is the side this desk examined on '
        .. '2026-08-23 and DECLINED: the mana payoff is real (9 of 26 ready '
        .. 'slots unblocked) but the health payoff is UNMEASURED, not absent, '
        .. 'and standard play prefers +200 health on the squishiest hero on the '
        .. 'map. Flipping is allowed -- but bring the death channel, or say in '
        .. 'hero_crystal_maiden.lua why it is not needed.')
end

return tests
