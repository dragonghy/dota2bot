-- [hero] soak candidate `wkqodds` (turbo-only, gated, UNARMED) -- the local-parity
-- term X.ConsiderQ's CATCH-ALL branch does not have.
--
-- THE BRANCH.  "通用消耗敌人或受到伤害时保护自己" is the TENTH and last firing
-- point in X.ConsiderQ.  The nine above it each state a reason to spend a
-- 14-second single-target disable (interrupt a channel, confirm a kill, hit the
-- biggest threat in a teamfight, trade in lane behind one's own creeps, initiate
-- a fight already chosen, defend oneself while retreating, clear a camp, hit
-- Roshan, answer damage just taken).  The catch-all states none: an enemy is
-- visible within 1600, one of them is inside 568u, the hero is level 7, cast on
-- the nearest.
--
-- THE DEFECT.  The branch is not crowd-blind by design -- it OWNS a crowd term,
-- `#allyList >= 2`.  That term sits on the right of an `or` whose left side is
-- `bot:GetActiveMode() ~= BOT_MODE_RETREAT`, and every mode except retreat
-- satisfies the left side.  So the number of heroes on each side is consulted
-- ONLY while retreating, and in every other mode the branch never looks at it.
-- Section 4 pins that shape off the source text rather than off prose.
--
-- Same family as `cmqpoke` (GH #698) and not the same shape: there the qualified
-- test existed as a SIBLING BRANCH that a wallet test upstream always beat to the
-- frame; here the qualified test is inside this very branch and is structurally
-- unreachable outside one mode.  In both, the armed leg invents no threshold --
-- it re-uses the number the shipped branch already wrote down.
--
-- WHAT THE ARMED LEG DOES NOT TOUCH.  The branch is two releases wearing one
-- `if`: a poke (`#nEnemysHerosInView > 0`) and a self-defence
-- (`bot:WasRecentlyDamagedByAnyHero( 3.0 )`).  Answering damage already taken is
-- not a judgement about odds, so the recently-damaged case returns true
-- unconditionally and the narrowing applies to the poke half only.  Section 2.3
-- is that carve-out on a real frame: a Wraith King at FIVE hit points with two
-- enemies inside 224u keeps his cast under the armed leg.
--
-- DIRECTION is a property of the shape, not of today's arithmetic: a conjunct
-- added to an `if` that returns BOT_ACTION_DESIRE_HIGH, on the LAST firing point
-- of the function, can only ever delete a cast.  Section 5.3 measures that over
-- the whole corpus rather than asserting it from the shape alone.
--
-- ZERO effect shipped: the gate is unarmed and turbo-only (section 3).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local T = {}

local WK   = 'npc_dota_hero_skeleton_king'
local PART = 'skeleton_king'
local BLAST = 'skeleton_king_hellfire_blast'
local SRC  = 'bots/BotLib/hero_skeleton_king.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The pin frame: queue `hero-54`'s Wraith King half, cut AT a Wraithfire Blast
-- combat-log entry (see tests/frames/README.md).
local PIN      = 'tests/frames/f_260909_215040_wk_blast_lion_480.lua'
-- The self-defence carve-out frame, from the same replay and the same cut recipe.
local CARVEOUT = 'tests/frames/f_260909_215040_wk_blast_sb_1052.lua'
-- The teamfight frame: an upstream branch takes it, so the armed leg is silent.
local UPSTREAM = 'tests/frames/f_260909_215040_wk_blast_sb_661.lua'

--- Every corpus file from BOTH directories, never a hardcoded list -- the
--- enumeration idiom of tests/test_cm_ult_reach_meter_domain.lua, and for the
--- same reason: a third directory must cost an edit here rather than a silent
--- undercount.
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

--- Is Wraith King alive on this frame?  Returns his raw dump record.
local function wk_record(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return nil end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == WK and u.alive == true then return u, chunk end
    end
    return nil
end

--- Drive Wraith King as SUBJECT on one frame and report what X.SkillsComplement
--- ordered ('' for nothing).
--- @param opts table {armed=bool, turbo=bool}
local function drive(path, opts)
    opts = opts or {}
    local ordered, probe = '', nil
    local ok, err = pcall(function()
        local J, bot = rf.load(path, WK)
        J.IsSoakCandidate = function(id) return opts.armed == true and id == 'wkqodds' end
        J.IsModeTurbo = function() return opts.turbo ~= false end
        local X = rf.load_hero(PART)
        local log = rf.record_actions(bot)
        pcall(X.SkillsComplement)
        for _, a in ipairs(log) do
            if a.fn:find('UseAbility') then
                local ab = a.args[1]
                ordered = (type(ab) == 'table' and ab.GetName and ab:GetName() or '?')
                break
            end
        end
        local q = bot:GetAbilityByName(BLAST)
        probe = {
            level    = bot:GetLevel(),
            hp       = bot:GetHealth(),
            max_hp   = bot:GetMaxHealth(),
            mp       = bot:GetMana(),
            max_mp   = bot:GetMaxMana(),
            q_level  = q and q:GetLevel() or 0,
            q_cd     = q and q:GetCooldownTimeRemaining() or -1,
            castable = q and q:IsFullyCastable() or false,
            saving   = q and X.ShouldSaveMana(q) or false,
            allies   = #J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE),
            in_range = #J.GetNearbyHeroes(bot, 568, true, BOT_MODE_NONE),
            in_view  = #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE),
            hurt     = bot:WasRecentlyDamagedByAnyHero(3.0),
            fight    = J.IsInTeamFight(bot, 1200),
            goingon  = J.IsGoingOnSomeone(bot),
            retreat  = J.IsRetreating(bot),
            farming  = J.IsFarming(bot),
        }
    end)
    assert(ok, 'driving ' .. path .. ' raised: ' .. tostring(err))
    return ordered, probe
end

-- ---------------------------------------------------------------- section 1 --
-- The pin frame, and that every fact the lever turns on is REAL.

T['1.1: the pin frame carries a living level-9 Wraith King with the blast ready'] = function()
    local rec = wk_record(PIN)
    assert(rec, PIN .. ' does not carry a living Wraith King')
    assert(rec.level == 9, 'pin frame Wraith King is level ' .. tostring(rec.level) .. ', expected 9')
    local _, probe = drive(PIN, { armed = false })
    assert(probe.q_level == 1, 'Wraithfire Blast reads rank ' .. probe.q_level .. ', expected 1')
    assert(probe.q_cd == 0, 'Wraithfire Blast reads cd ' .. probe.q_cd .. ', expected 0')
    assert(probe.castable, 'Wraithfire Blast is not fully castable on the pin frame')
    assert(not probe.saving, 'X.ShouldSaveMana holds the blast on the pin frame; '
        .. 'the lever would then be measuring the reincarnation reserve, not the catch-all')
end

T['1.2: the pin frame is the OUTNUMBERED POKE the lever is about, with no other branch bidding'] = function()
    local _, p = drive(PIN, { armed = false })
    -- One ally in 1200 (Crystal Maiden at 667u) against three visible enemies.
    assert(p.allies == 1, 'pin frame ally count is ' .. p.allies .. ', expected 1')
    assert(p.in_view == 3, 'pin frame visible-enemy count is ' .. p.in_view .. ', expected 3')
    assert(p.in_range == 1, 'pin frame in-ring enemy count is ' .. p.in_range .. ', expected 1')
    -- and none of the nine reasons above the catch-all is present.
    assert(not p.hurt,    'pin frame Wraith King WAS recently damaged -- then the branch is running '
        .. 'as self-defence and the armed leg is carved out of it by construction')
    assert(not p.fight,   'pin frame reads as a teamfight; the teamfight branch would take it upstream')
    assert(not p.goingon, 'pin frame reads as going on someone; the initiation branch is upstream')
    assert(not p.retreat, 'pin frame reads as retreating')
    assert(not p.farming, 'pin frame reads as farming')
end

T['1.3: the target the shipped tree picks is at FULL health'] = function()
    local ok, chunk = pcall(dofile, PIN)
    assert(ok and type(chunk) == 'table', PIN .. ' will not load')
    local lion
    for _, u in ipairs(chunk.units or {}) do
        if u.name == 'npc_dota_hero_lion' then lion = u end
    end
    assert(lion, 'the pin frame no longer carries lion; section 2.1 names him as the target')
    assert(lion.hp == lion.max_hp, string.format(
        'the pin frame lion reads %d/%d health; the condition-(c) argument in '
        .. 'X.wk_IsCatchAllOddsOk is about spending a disable on a FULL-health hero',
        lion.hp, lion.max_hp))
end

-- ---------------------------------------------------------------- section 2 --
-- The decision moves on the pin frame, and only there.

T['2.1: SHIPPED orders Wraithfire Blast on the pin frame'] = function()
    local ordered = drive(PIN, { armed = false })
    assert(ordered == BLAST, 'shipped tree ordered "' .. ordered .. '" on the pin frame, expected '
        .. BLAST .. ' -- if this moved, the lever no longer has a frame')
end

T['2.2: ARMED refuses, and nothing downstream picks the frame up'] = function()
    local ordered = drive(PIN, { armed = true, turbo = true })
    assert(ordered == '', 'armed leg ordered "' .. ordered .. '" on the pin frame, expected nothing. '
        .. 'X.ConsiderW taking the frame instead would make this lever a Bone Guard change '
        .. 'wearing a Wraithfire Blast name.')
end

T['2.3 CARVE-OUT: a Wraith King at five hit points keeps his cast under the armed leg'] = function()
    local rec = wk_record(CARVEOUT)
    assert(rec, CARVEOUT .. ' does not carry a living Wraith King')
    assert(rec.hp == 5, 'the carve-out frame Wraith King reads ' .. tostring(rec.hp)
        .. ' health, expected 5 -- this section is about the self-defence half of the branch')
    local _, p = drive(CARVEOUT, { armed = false })
    assert(p.hurt, 'the carve-out frame no longer reads recently-damaged; without that the '
        .. 'carve-out is not being exercised')
    assert(p.allies == 0, 'the carve-out frame ally count is ' .. p.allies .. ', expected 0 -- '
        .. 'i.e. the crowd term would refuse here if the carve-out were not in front of it')
    assert(p.in_view >= 2, 'the carve-out frame visible-enemy count is ' .. p.in_view)
    assert(drive(CARVEOUT, { armed = false }) == BLAST, 'shipped tree no longer casts on the carve-out frame')
    assert(drive(CARVEOUT, { armed = true })  == BLAST,
        'the armed leg deleted the cast of a Wraith King at five hit points who is being hit. '
        .. 'That is the self-defence half of the branch and X.wk_IsCatchAllOddsOk returns true on it.')
end

T['2.4: a frame an UPSTREAM branch takes is untouched by the armed leg'] = function()
    local _, p = drive(UPSTREAM, { armed = false })
    assert(p.fight, 'the upstream frame no longer reads as a teamfight')
    assert(drive(UPSTREAM, { armed = false }) == BLAST, 'shipped tree no longer casts on the upstream frame')
    assert(drive(UPSTREAM, { armed = true })  == BLAST,
        'the armed leg moved a frame the TEAMFIGHT branch decides. X.wk_IsCatchAllOddsOk is a '
        .. 'conjunct of the tenth firing point only; reaching any other one is a wiring error.')
end

-- ---------------------------------------------------------------- section 3 --
-- Gate discipline: unarmed and non-turbo are both byte-for-byte shipped.

T['3.1: unarmed is identical to shipped on every corpus frame'] = function()
    for _, path in ipairs(corpus_paths()) do
        if wk_record(path) then
            local a = drive(path, { armed = false, turbo = true })
            local b = drive(path, { armed = false, turbo = false })
            assert(a == b, 'unarmed answers differ by turbo on ' .. path)
        end
    end
end

T['3.2: armed but NOT turbo is identical to shipped -- the candidate is turbo-only'] = function()
    for _, path in ipairs(corpus_paths()) do
        if wk_record(path) then
            local shipped = drive(path, { armed = false, turbo = true })
            local armed_nonturbo = drive(path, { armed = true, turbo = false })
            assert(shipped == armed_nonturbo, string.format(
                'armed-but-not-turbo diverges from shipped on %s (%s vs %s). '
                .. 'J.IsModeTurbo is the first conjunct of the gate for exactly this reason.',
                path, shipped, armed_nonturbo))
        end
    end
end

T['3.3: the candidate id appears in the source exactly once, and it is the gate'] = function()
    local f = assert(io.open(SRC, 'r'))
    local src = f:read('*a')
    f:close()
    local n = 0
    for _ in src:gmatch("IsSoakCandidate%( 'wkqodds' %)") do n = n + 1 end
    assert(n == 1, 'expected exactly one wkqodds gate in ' .. SRC .. ', found ' .. n)
    assert(src:find("J.IsModeTurbo%(%) and J.IsSoakCandidate%( 'wkqodds' %)"),
        'the wkqodds gate is not conjoined with J.IsModeTurbo -- a non-turbo game would run it')
end

-- ---------------------------------------------------------------- section 4 --
-- THE DEFECT, pinned off the source text and not off prose: the crowd term the
-- branch already owns is only reachable while retreating.

T['4.1: the shipped catch-all still carries its crowd term behind the retreat disjunct'] = function()
    local f = assert(io.open(SRC, 'r'))
    local src = f:read('*a')
    f:close()
    local line = 'and ( bot:GetActiveMode() ~= BOT_MODE_RETREAT or #allyList >= 2 )'
    local n = 0
    for _ in src:gmatch(line:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')) do n = n + 1 end
    assert(n >= 1, 'the shipped disjunct this lever is about is gone from ' .. SRC
        .. '. If it was repaired in place, retire the candidate rather than re-aiming it.')
end

T['4.2: that crowd term is DEAD outside retreat -- on every corpus frame'] = function()
    -- The claim is closed-form (`A ~= x or B` never consults B while A holds), so
    -- this section checks the premise the closed form needs: that no corpus frame
    -- reads BOT_MODE_RETREAT.  GetActiveMode is bot-VM state and is in no .dem
    -- (the 13th world assertion), so it answers 0 = BOT_MODE_NONE offline -- which
    -- is why the left side is true on every archived frame and the crowd term is
    -- consulted on none of them.
    local seen = 0
    for _, path in ipairs(corpus_paths()) do
        if wk_record(path) then
            local mode
            pcall(function()
                local _, bot = rf.load(path, WK)
                mode = bot:GetActiveMode()
            end)
            if mode == BOT_MODE_RETREAT then seen = seen + 1 end
            assert(mode == 0 or mode == nil, string.format(
                '%s answers GetActiveMode = %s. The archive used to answer 0 on every frame; '
                .. 'if a mode channel landed, section 4 has to be re-derived rather than re-run.',
                path, tostring(mode)))
        end
    end
    assert(seen == 0, 'a corpus frame now reads BOT_MODE_RETREAT (' .. seen .. ')')
end

-- ---------------------------------------------------------------- section 5 --
-- The domain, measured over the whole corpus (tests/fixtures/ + tests/frames/).

local sweep_cache = nil
local function sweep()
    if sweep_cache then return sweep_cache end
    local r = { files = 0, alive = 0, body = 0, outer = 0,
                shipped_cast = 0, armed_cast = 0, moved = {}, added = {} }
    for _, path in ipairs(corpus_paths()) do
        r.files = r.files + 1
        if wk_record(path) then
            r.alive = r.alive + 1
            local shipped, p = drive(path, { armed = false })
            local armed = drive(path, { armed = true, turbo = true })
            if p.castable and not p.saving then
                r.body = r.body + 1
                if p.level >= 7 and p.in_range >= 1 and (p.in_view > 0 or p.hurt) then
                    r.outer = r.outer + 1
                end
            end
            if shipped ~= '' then r.shipped_cast = r.shipped_cast + 1 end
            if armed ~= '' then r.armed_cast = r.armed_cast + 1 end
            if shipped ~= '' and armed == '' then r.moved[#r.moved + 1] = path end
            if shipped == '' and armed ~= '' then r.added[#r.added + 1] = path end
        end
    end
    sweep_cache = r
    return r
end

T['5.1: the funnel, and it is not vacuous'] = function()
    local r = sweep()
    -- Floors, never equalities: the corpus grows, and GH #106 filed
    -- corpus-size-as-equation as a hazard of its own.
    assert(r.files >= 129, 'corpus shrank to ' .. r.files .. ' frames')
    assert(r.alive >= 44, 'living-Wraith-King instants dropped to ' .. r.alive
        .. '; below the reading this section was taken on')
    assert(r.body >= 25, 'frames reaching the X.ConsiderQ body dropped to ' .. r.body)
    -- 2026-09-10 reading: 129 files -> 44 living-WK instants -> 25 reach the
    -- body (the rest refused by IsFullyCastable or X.ShouldSaveMana) -> 3 satisfy
    -- the catch-all's outer conjuncts -> the shipped tree orders the blast on 3
    -- (one of them from the teamfight branch, not the catch-all) -> the armed leg
    -- orders it on 2.
    assert(r.outer >= 1, 'no corpus frame satisfies the catch-all outer conjuncts any more; '
        .. 'the lever domain would then be empty and this test proves nothing')
end

T['5.2: exactly one frame moves, and it is the pin frame'] = function()
    local r = sweep()
    assert(#r.moved == 1, string.format(
        'the armed leg moves %d frame(s), expected 1:\n  %s\n'
        .. 'A NEW mover is not automatically a regression -- read it, then re-pin. '
        .. 'A LOST mover means the lever no longer has a real frame.',
        #r.moved, table.concat(r.moved, '\n  ')))
    assert(r.moved[1] == PIN, 'the mover is ' .. r.moved[1] .. ', expected ' .. PIN)
end

T['5.3 DIRECTION: the armed leg adds no cast anywhere in the corpus'] = function()
    local r = sweep()
    assert(#r.added == 0, string.format(
        'the armed leg ADDED a cast on %d frame(s):\n  %s\n'
        .. 'X.wk_IsCatchAllOddsOk is a conjunct of an `if` that returns '
        .. 'BOT_ACTION_DESIRE_HIGH on the LAST firing point of X.ConsiderQ, so this is '
        .. 'impossible by construction. A red here is a wiring defect, not a tuning question.',
        #r.added, table.concat(r.added, '\n  ')))
    assert(r.armed_cast <= r.shipped_cast, string.format(
        'armed casts on %d frames, shipped on %d', r.armed_cast, r.shipped_cast))
end

-- ---------------------------------------------------------------- section 6 --
-- A reading this round bought for a DIFFERENT candidate, recorded where the next
-- reader of it will be.

T['6.1: the `wkqaim` supply zero is FALSE off-corpus -- two staged frames reach the ring'] = function()
    -- tests/test_wk_q_aim_preflight.lua section 1 asserts a universal over
    -- `tests/fixtures/` alone: "every frame with a living Wraith King and two or
    -- more living enemies inside 568u has Wraithfire Blast unlearned or on
    -- cooldown -- the branch is never reached".  That tripwire cannot see
    -- `tests/frames/`, and the frames staged there on 2026-09-10 break it.
    local hits = {}
    for _, path in ipairs(corpus_paths()) do
        if wk_record(path) then
            local _, p = drive(path, { armed = false })
            if p.castable and p.in_range >= 2 then hits[#hits + 1] = path end
        end
    end
    assert(#hits >= 2, string.format(
        'expected at least 2 frames with a living Wraith King, Wraithfire Blast castable and '
        .. '>=2 living enemies inside 568u; found %d. This is the configuration '
        .. 'tests/test_wk_q_aim_preflight.lua calls empty, so a drop here would put the two '
        .. 'files back into agreement and this section should then be retired, not repaired.',
        #hits))
    local staged = 0
    for _, h in ipairs(hits) do
        if h:find('^' .. STAGED_DIR) then staged = staged + 1 end
    end
    assert(staged == #hits, 'a `tests/fixtures/` frame now reaches the ring too, which means '
        .. 'test_wk_q_aim_preflight.lua section 1 is red on its own terms. Read that file first.')
end

T['6.2: reachability is not discrimination -- `wkqaim` would still change no target here'] = function()
    -- The distinction the wkqdmg note in bots/ draws between an ARITHMETIC domain
    -- and a DECISION domain, taken on the frames section 6.1 just found: the
    -- proposal was "aim at the lowest-health enemy in the ring instead of the
    -- nearest". On the one frame that also clears the branch's level gate, the
    -- nearest enemy IS the lowest-health one, by fraction and by absolute health.
    local ok, chunk = pcall(dofile, CARVEOUT)
    assert(ok and type(chunk) == 'table', CARVEOUT .. ' will not load')
    local ring = {}
    local me
    for _, u in ipairs(chunk.units or {}) do
        if u.name == WK then me = u end
    end
    assert(me, 'no Wraith King on ' .. CARVEOUT)
    for _, u in ipairs(chunk.units or {}) do
        if u.team ~= me.team and u.alive == true then
            local d = math.sqrt((u.x - me.x) ^ 2 + (u.y - me.y) ^ 2)
            if d <= 568 then ring[#ring + 1] = { u = u, d = d } end
        end
    end
    assert(#ring >= 2, 'the carve-out frame ring holds ' .. #ring .. ' enemies, expected >= 2')
    table.sort(ring, function(a, b) return a.d < b.d end)
    local nearest = ring[1].u
    local weakest_abs, weakest_frac = ring[1].u, ring[1].u
    for _, e in ipairs(ring) do
        if e.u.hp < weakest_abs.hp then weakest_abs = e.u end
        if (e.u.hp / e.u.max_hp) < (weakest_frac.hp / weakest_frac.max_hp) then weakest_frac = e.u end
    end
    assert(nearest.name == weakest_abs.name and nearest.name == weakest_frac.name, string.format(
        'the ring on %s now discriminates: nearest=%s, lowest absolute health=%s, lowest '
        .. 'fraction=%s. That is the frame queue hero-1 asked for and `wkqaim` can be written '
        .. 'on it -- update tests/test_wk_q_aim_preflight.lua rather than this assertion.',
        CARVEOUT, nearest.name, weakest_abs.name, weakest_frac.name))
end

return T
