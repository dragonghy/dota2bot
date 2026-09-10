-- [hero] queue `hero-54` (priority 1, frame supply) EXECUTED, and the answer it
-- bought in one line:
--
--     The corpus's "four live decisions in 183 alive focus-hero instants" was a
--     fact about WHERE the frames were cut, not about the bots.  Cut twelve
--     frames AT the instants the bots actually pressed a spell, and the same
--     shipped tree (every gate OFF) orders an ability on TEN of thirty-four.
--
-- Corpus:  4 / 183 = 2.2%   (tests/test_focus_decision_reachability.lua section 2)
-- Here:   10 /  34 = 29.4%  (this file, section 2)
--
-- and the row that matters most, because fifteen-odd rounds of this stream ran
-- aground on it: **Wraith King, 0 of 36 in the corpus, is 3 of 6 here.**  He was
-- never silent; nobody had ever cut a frame where he was about to cast.
--
-- HOW THE FRAMES WERE CUT (the recipe hero-54 asked for, and it is cheap --
-- ~4 minutes per game end to end, no EC2, S3 read only):
--   1. bash tools/batch_test/aws/session_setup.sh            (read-only use)
--   2. bash tools/batch_test/behavioral/get_dumper.sh        (S3 cache hit: seconds)
--   3. awsx s3 cp s3://<bucket>/replays/<game>.dem .
--   4. behav-dump -interval 0.5 <game>.dem > tl.json
--   5. the cast instants are combat-log entries, already in that file:
--        [e for e in tl['events'] if e['type']=='ABILITY'
--                                and e['actor']=='npc_dota_hero_<focus hero>']
--   6. make_fixture.py tl.json --t <that t> --hero <focus hero> --roles <analysis.json>
--
-- ⭐ WHY `--t` IS THE CAST INSTANT ITSELF AND NOT A MOMENT BEFORE IT.  Measured
-- on this replay: at the ABILITY entry's own timestamp the caster's cooldown and
-- mana still read PRE-cast (Hellfire Blast cd 0, mp 315 at t=67.1; the very next
-- 0.5s sample reads cd 13.9, mp 220).  The combat-log entry leads the entity
-- snapshot, so `--t <cast t>` freezes the world the bot decided IN.  Half a
-- second earlier is a different question -- at t=66.6 the same target is 838u
-- away and still being walked at.
--
-- ⚠️ THESE FRAMES ARE STAGED, NOT ADMITTED.  They live in `tests/frames/`, which
-- is outside the `tests/fixtures/*.lua` corpus glob, for the reason that
-- directory's README gives.  hero-54's acceptance asked for admission to
-- `tests/fixtures/`; the round that executed it MEASURED that price instead of
-- assuming it, by moving the frames in, running, and moving them back:
--
--     admission price, measured 2026-09-10: 17 of 19 census files go red
--     (16 corpus-glob sweepers + 3 more the selfcheck's Lua leg names), and the
--     six Wraith King frames ALONE turn 17 of those 19 -- i.e. the price is per
--     NEW GAME ADMITTED, not per frame.  Two of the seventeen are not number
--     bumps: `test_salvetarget_axis_undecidable` reports the archive now carries
--     a NON-TIED disagreement between its two axes, and GH #242's published
--     ruling rests on there being none; `test_blind_a_pulllane_pullthink` moves
--     a count that test_set.md section GF quotes as the size of a purchase.
--     Paying that list is its own work unit and it is NOT paid here.
--
--     staging price, measured the same way: ONE file, PAID in this round --
--     `tests/test_cm_ult_reach_meter_domain.lua` (section 1's five counts
--     53->65, section 4's five constants and two new LIVE_BIDS rows, section 5's
--     fire set 2->3).  `tests/test_cm_nova_surplus_poke.lua` stays green.
--
-- ⛔ AND THE FIRST READING OF THAT PRICE WAS "ZERO", WHICH IS THE PART WORTH
-- CARRYING AWAY.  It came from `grep -l 'tests/frames/\*'`, which finds the one
-- test that writes the glob as a literal and CANNOT find the one that builds it:
--     for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
--         io.popen('ls ' .. dir .. ' 2>/dev/null')
-- Same family as this stream's own `_cm_t10_payoff_sweep` lesson (2026-09-10,
-- backlog -139): before you price a directory, ask who reads it through a
-- VARIABLE, not only who spells it out.  A text search over call sites answers
-- a question about text, and the census it missed was the one with teeth.
--
-- ZERO behaviour change: no `bots/` or `game/` edit, no new gate id, no arm.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

--- part -> unit name, for the five focus heroes.  Same five, same order, as
--- tests/test_focus_decision_reachability.lua.
local FOCUS = {
    { 'axe',            'npc_dota_hero_axe' },
    { 'zuus',           'npc_dota_hero_zuus' },
    { 'skeleton_king',  'npc_dota_hero_skeleton_king' },
    { 'lion',           'npc_dota_hero_lion' },
    { 'crystal_maiden', 'npc_dota_hero_crystal_maiden' },
}

--- The twelve frames this round cut, with the cast that motivated each one.
--- `t` is the combat-log timestamp of that cast, i.e. the fixture's own `time`.
local FRAMES = {
    -- game 20260909_215040_slot1 (spot ..._5313f5): skeleton_king, crystal_maiden,
    -- lion, death_prophet, dragon_knight, lich, obsidian_destroyer, slardar,
    -- spirit_breaker, vengefulspirit.  46 Wraith King casts in the replay.
    { 'f_260909_215040_wk_blast_lane_67.lua',   67.1,   'skeleton_king_hellfire_blast' },
    { 'f_260909_215040_wk_blast_lane_121.lua',  121.5,  'skeleton_king_hellfire_blast' },
    { 'f_260909_215040_wk_blast_mid_269.lua',   269.1,  'skeleton_king_hellfire_blast' },
    { 'f_260909_215040_wk_blast_lion_480.lua',  480.6,  'skeleton_king_hellfire_blast' },
    { 'f_260909_215040_wk_blast_sb_661.lua',    661.3,  'skeleton_king_hellfire_blast' },
    { 'f_260909_215040_wk_blast_sb_1052.lua',   1052.0, 'skeleton_king_hellfire_blast' },
    -- game 20260909_215412_slot1 (spot ..._7eb1ba): axe, crystal_maiden, lion,
    -- drow_ranger, lina, luna, obsidian_destroyer, pudge, silencer, viper.
    -- 74 Axe casts in the replay.
    { 'f_260909_215412_axe_call_init_224.lua',  224.3,  'axe_berserkers_call' },
    { 'f_260909_215412_axe_cull_viper_348.lua', 348.0,  'axe_culling_blade' },
    { 'f_260909_215412_axe_cull_cm_415.lua',    415.1,  'axe_culling_blade' },
    { 'f_260909_215412_axe_cull_pudge_470.lua', 470.9,  'axe_culling_blade' },
    { 'f_260909_215412_axe_cull_drow_475.lua',  475.8,  'axe_culling_blade' },
    { 'f_260909_215412_axe_cull_cm_838.lua',    838.9,  'axe_culling_blade' },
}

--- Alive-subject instants per focus hero over the twelve frames, 2026-09-10.
--- zuus is 0 because neither drafted roster carries him -- that is the standing
--- gap this file hands to the next round, not a defect of the method.
local ALIVE = {
    axe = 6, zuus = 0, skeleton_king = 6, lion = 10, crystal_maiden = 12,
}

--- Every instant on which the SHIPPED dispatch (all gates off) orders an
--- ability, `part .. ' ' .. frame basename` -> ability name.  2026-09-10.
local LIVE = {
    ['skeleton_king f_260909_215040_wk_blast_sb_661.lua']    = 'skeleton_king_hellfire_blast',
    ['skeleton_king f_260909_215040_wk_blast_lion_480.lua']  = 'skeleton_king_hellfire_blast',
    ['skeleton_king f_260909_215040_wk_blast_sb_1052.lua']   = 'skeleton_king_hellfire_blast',
    ['axe f_260909_215412_axe_cull_viper_348.lua']           = 'axe_culling_blade',
    ['axe f_260909_215412_axe_cull_cm_415.lua']              = 'axe_culling_blade',
    ['axe f_260909_215412_axe_cull_pudge_470.lua']           = 'axe_culling_blade',
    ['axe f_260909_215412_axe_cull_cm_838.lua']              = 'axe_culling_blade',
    ['crystal_maiden f_260909_215412_axe_cull_pudge_470.lua'] = 'crystal_maiden_crystal_nova',
    ['crystal_maiden f_260909_215412_axe_cull_cm_838.lua']    = 'crystal_maiden_crystal_nova',
    ['lion f_260909_215412_axe_cull_cm_838.lua']              = 'lion_mana_drain',
}

local DIR = 'tests/frames/'

local function base(path) return (path:gsub('.*/', '')) end

--- Drive one focus hero as SUBJECT on one staged frame with every gate OFF.
--- Byte-identical in behaviour to tests/test_focus_decision_reachability.lua's
--- `drive`, deliberately: the 10/34 here and the 4/183 there have to be the
--- same measurement taken over two different frame sets, or the comparison in
--- this file's header is not a comparison.
--- @return nil when the hero is absent or dead on that frame, else the ability
---         name X.SkillsComplement ordered ('' when it ordered nothing).
local function drive(path, part, uname, fx)
    local present = false
    for _, u in ipairs(fx.units or {}) do
        if u.name == uname and u.alive == true then present = true end
    end
    if not present then return nil end
    local ordered = ''
    pcall(function()
        local J, bot = rf.load(path, uname)
        J.IsSoakCandidate = function() return false end
        local X = rf.load_hero(part)
        local log = rf.record_actions(bot)
        pcall(X.SkillsComplement)
        for _, a in ipairs(log) do
            if a.fn:find('UseAbility') then
                local ab = a.args[1]
                if type(ab) == 'table' and ab.GetName then ordered = ab:GetName() end
                break
            end
        end
    end)
    return ordered
end

local sweep_cache = nil
local function sweep()
    if sweep_cache ~= nil then return sweep_cache end
    local alive, live = {}, {}
    for _, row in ipairs(FRAMES) do
        local path = DIR .. row[1]
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, h in ipairs(FOCUS) do
                local ordered = drive(path, h[1], h[2], fx)
                if ordered ~= nil then
                    alive[h[1]] = (alive[h[1]] or 0) + 1
                    if ordered ~= '' then live[h[1] .. ' ' .. base(path)] = ordered end
                end
            end
        end
    end
    sweep_cache = { alive = alive, live = live }
    return sweep_cache
end

--- --------------------------------------------------------------- section 1 --
--- The frames are here, and each one really sits on the cast it claims.

tests['1.1: all twelve staged frames load, at the cast instant they name'] = function()
    for _, row in ipairs(FRAMES) do
        local path = DIR .. row[1]
        local ok, fx = pcall(dofile, path)
        assert(ok and type(fx) == 'table', 'staged frame will not load: ' .. path)
        assert(math.abs((fx.time or -1) - row[2]) < 0.001,
            ('%s carries time %s, the table says the cast was at %s')
            :format(row[1], tostring(fx.time), tostring(row[2])))
        assert(type(fx.units) == 'table' and #fx.units == 10,
            row[1] .. ' does not carry ten heroes')
    end
end

tests['1.2: the caster is alive on his own frame, with that spell OFF cooldown'] = function()
    -- The claim the header makes about `--t`: at the combat-log timestamp the
    -- entity snapshot still reads PRE-cast.  If this ever goes red the dumper's
    -- event/snapshot ordering changed and the recipe above needs re-taking.
    for _, row in ipairs(FRAMES) do
        local path, spell = DIR .. row[1], row[3]
        local fx = dofile(path)
        local caster = nil
        for _, u in ipairs(fx.units) do
            if u.name == fx.self then caster = u end
        end
        assert(caster ~= nil and caster.alive == true,
            row[1] .. ': the subject is not alive on his own cast frame')
        local found = nil
        for _, a in ipairs(caster.abilities or {}) do
            if a.name == spell then found = a end
        end
        assert(found ~= nil, row[1] .. ': the cast spell ' .. spell .. ' is not on the caster')
        assert((found.cd or 0) == 0,
            ('%s: %s reads cd %s at the cast instant. The combat-log entry no '
             .. 'longer leads the entity snapshot -- re-take the recipe in this '
             .. 'file\'s header before cutting more frames.')
            :format(row[1], spell, tostring(found.cd)))
    end
end

--- --------------------------------------------------------------- section 2 --
--- The headline.  hero-54's premise, confirmed and quantified.

tests['2.1: 34 alive focus-hero instants over the twelve frames, by hero'] = function()
    local s = sweep()
    local total = 0
    for _, h in ipairs(FOCUS) do
        local got = s.alive[h[1]] or 0
        assert(got == ALIVE[h[1]],
            ('%s: %d alive-subject instants, expected %d -- re-pin, and re-pin '
             .. 'the 10/34 in the header with it')
            :format(h[1], got, ALIVE[h[1]]))
        total = total + got
    end
    assert(total == 34, 'total alive-subject instants ' .. total .. ', expected 34')
end

tests['2.2: exactly the ten live decisions, and no others'] = function()
    local s = sweep()
    for k, v in pairs(s.live) do
        assert(LIVE[k] ~= nil,
            ('NEW LIVE DECISION on a staged frame: %s orders %s. Add it to LIVE '
             .. 'and re-read the header ratio.'):format(k, v))
        assert(LIVE[k] == v, ('%s now orders %s, was %s'):format(k, v, LIVE[k]))
    end
    for k, v in pairs(LIVE) do
        assert(s.live[k] == v,
            ('%s no longer orders %s (got %s) -- a live decision was LOST; these '
             .. 'ten are the reason this frame set exists, so find out what took it.')
            :format(k, v, tostring(s.live[k])))
    end
end

tests['2.3: Wraith King -- 0 of 36 in the corpus, 3 of 6 here'] = function()
    local s = sweep()
    local n = 0
    for k in pairs(s.live) do
        if k:find('^skeleton_king ') then n = n + 1 end
    end
    assert(s.alive.skeleton_king == 6, 'WK alive instants ' .. s.alive.skeleton_king)
    assert(n == 3,
        ('Wraith King live decisions on the staged frames: %d, expected 3. This '
         .. 'is the single number hero-54 was filed to move (the corpus reading '
         .. 'is 0 of 36, tests/test_focus_decision_reachability.lua section 2.2) '
         .. '-- do not re-pin it without saying which way it moved and why.')
        :format(n))
end

tests['2.4: the yield is an order of magnitude denser than the corpus'] = function()
    -- Guard on the COMPARISON rather than on either number alone: the point of
    -- the round is the ratio, and a re-pin of one side that quietly kills the
    -- ratio is exactly the shape this stream keeps filing issues about.
    local s = sweep()
    local live_n = 0
    for _ in pairs(s.live) do live_n = live_n + 1 end
    local alive_n = 0
    for _, h in ipairs(FOCUS) do alive_n = alive_n + (s.alive[h[1]] or 0) end
    local here = live_n / alive_n
    local corpus = 4 / 183  -- pinned in tests/test_focus_decision_reachability.lua
    assert(here > 8 * corpus,
        ('cast-instant frames yield %.1f%% live decisions, corpus frames %.1f%% '
         .. '-- the factor dropped below 8. Either the corpus caught up (good, '
         .. 'say so) or these frames stopped being cut on cast instants (bad).')
        :format(here * 100, corpus * 100))
end

--- --------------------------------------------------------------- section 3 --
--- The gap this round did NOT close, stated so the next round does not have to
--- rediscover it.

tests['3.1: Zeus has no frame here, and the reason is the draft not the method'] = function()
    local s = sweep()
    assert((s.alive.zuus or 0) == 0,
        'Zeus gained staged frames -- delete this case and re-pin ALIVE.zuus; '
        .. 'the standing gap it records is closed.')
    for _, row in ipairs(FRAMES) do
        local fx = dofile(DIR .. row[1])
        for _, u in ipairs(fx.units) do
            assert(u.name ~= 'npc_dota_hero_zuus',
                row[1] .. ' carries a Zeus, so the reason for the zero above is '
                .. 'no longer "he was not drafted in either game"')
        end
    end
end

return tests
