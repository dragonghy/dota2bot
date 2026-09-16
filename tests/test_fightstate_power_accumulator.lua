-- [ratchet] [strategy 2026-09-16] Soak candidate 'fightstate': J.WeAreStronger
-- builds TWO totals for our own side and compares the one that cannot see our
-- cooldowns or our mana.
--
-- THE DEFECT (shipped default, bots/FunLib/jmz_func.lua, J.WeAreStronger)
-- ---------------------------------------------------------------------------
-- The function keeps `ourPower` and `ourPowerRaw` side by side and writes BOTH
-- on every branch it has (real allies, illusions, the glyphed/plain ally-tower
-- term, the teamfight bonus). The two expressions are identical except for one
-- getter:
--
--     ourPower    = ... math.log(1 + unit:GetOffensivePower())    ...
--     ourPowerRaw = ... math.log(1 + unit:GetRawOffensivePower()) ...
--
-- docs/BOT_API_REFERENCE.md:1170-1171 -- GetOffensivePower() "respects
-- cooldowns/mana", GetRawOffensivePower() is "damage output ignoring cooldowns
-- and mana". The enemy total is built from the RAW getter only; there is no
-- state-aware enemy accumulator anywhere in the function.
--
-- And the comparison that shipped is `ourPowerRaw > enemyPower`. So `ourPower`
-- is computed for every ally inside the radius, on every call, and then thrown
-- away -- a dead store, and the only term in the whole function that knows our
-- own side is out of mana or has its ultimates down.
--
-- ⭐ WHY THAT IS A DEFECT AND NOT A STYLE. Raw-vs-raw LOOKS symmetric, but the
-- two sides are not symmetric in what a bot can know: it knows its own
-- cooldowns and mana exactly and cannot see the enemy's. The standard
-- conservative engagement rule is therefore the other pairing -- count yourself
-- at what you can actually do right now, credit the enemy with everything they
-- own -- and that pairing is precisely what a second accumulator is for. The
-- author built it and then compared the other one.
--
-- DIRECTION. GetOffensivePower() <= GetRawOffensivePower() by construction, so
-- arming can only LOWER our side: strictly fewer frames answer "we are
-- stronger", never more. §4 exhausts that over a grid instead of asserting it.
-- Turbo is where it bites -- fights are constant and mana, not damage, is the
-- binding constraint.
--
-- ⛔ WHY NO AUTOMATIC READER SAW IT -- AND THE CORRECTION THAT GOES WITH IT
-- ---------------------------------------------------------------------------
-- luacheck DOES see this one. It is W311, "value assigned to variable
-- 'ourPower' is unused", and it has been there the whole time. What suppresses
-- it is this repo's own .luacheckrc: `only = { "1" }` keeps the 1xx
-- global-access family and drops everything else, so the push gate's static
-- half is CONFIGURED not to look, not blind by construction.
--
-- ⭐ That distinction corrects a sentence this desk shipped last round. The
-- 'tpstash' round wrote "both automatic readers are blind BY CONSTRUCTION",
-- and for tpstash that is true (no luacheck rule evaluates `a or b` for
-- constancy). It is NOT true of the family: 'warddupkey' is W314, which
-- default luacheck reports and which this repo's config drops -- the three
-- W314 hits in bots/FunLib/aba_ward_utility.lua are that exact finding. A
-- configured blind spot and a constructional one have different dispositions,
-- and reading the first as the second is how a fixable gate stays unfixed.
--
-- ⛔ WHAT THIS FILE CAN AND CANNOT BUY -- read before quoting any number below
-- ---------------------------------------------------------------------------
-- ⭐ The headline is not a corpus reading. "Un-armed this is the expression
-- that shipped" and "armed can only withhold, never add" are statements over a
-- domain, so §4 exhausts a grid (including the equal case and the nan case)
-- rather than sampling frames.
--
-- ⛔ Neither getter is in the dump. No fixture carries an offensive-power
-- field of any kind, so the two accumulators cannot be evaluated on a real
-- frame here at all -- the numeric comparison is UNASKABLE on this corpus, not
-- merely rare. That is pinned as world assertion §5 W1, which goes RED the day
-- the dumper emits either getter, and it is reverse-called (a field that IS in
-- every fixture must be found by the same scanner) so a zero means "absent",
-- not "scanner broken". That reverse call is charter 0NEXT27's criterion:
-- a census tool self-certifies on a known answer before it is asked about an
-- unknown one.
--
-- ⭐ What the corpus CAN price is the lever's live domain, because the state
-- the state-aware getter respects -- ability cooldowns, mana -- IS dumped.
-- §5 measures, on real frames, how often an ally of the subject is degraded in
-- exactly that sense. That is the honest half: it bounds how often the two
-- totals could differ, without inventing the engine's number for either.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local JMZ = 'bots/FunLib/jmz_func.lua'
local DOC = 'docs/BOT_API_REFERENCE.md'
local HELPER = 'J.ShouldRateOurFightPowerByState'
local CAND = 'fightstate'

ss.assert_clean('file load, tests/test_fightstate_power_accumulator.lua')

local tests = {}

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

local _jmz
local function jmz_src()
    if not _jmz then _jmz = strip_comments(read(JMZ)) end
    return _jmz
end

--- The body of J.WeAreStronger, comments removed.
local function weaker_body()
    local src = jmz_src()
    local a = src:find('function J%.WeAreStronger%(')
    assert(a, 'J.WeAreStronger is gone from ' .. JMZ .. '. If it was renamed '
        .. 'or deleted, this lever went with it and so does this file.')
    local b = src:find('\nend', a, true)
    return src:sub(a, b)
end

--- The helper body, comments removed.
local function helper_body()
    local src = jmz_src()
    local a = src:find('function ' .. HELPER:gsub('%.', '%%.'))
    assert(a, HELPER .. ' is gone from ' .. JMZ)
    local b = src:find('\nend', a, true)
    return src:sub(a, b)
end

-- ==========================================================================
-- §1 THE SITE. Source-level, because it holds on every frame, not some.
-- ==========================================================================

tests['[site] ⭐ the comparison no longer reads ourPowerRaw directly']
= function()
    local body = weaker_body()
    assert(not body:find('local res = ourPowerRaw > enemyPower', 1, true),
        'J.WeAreStronger compares ourPowerRaw again. That is the shipped '
        .. 'defect: ourPower becomes a dead store and the gate has nothing '
        .. 'left to switch.')
    assert(body:find('local res = nOurPower > enemyPower', 1, true),
        'the comparison is no longer `nOurPower > enemyPower`. Every claim in '
        .. 'this file is about which total that name holds.')
end

tests['[site] ⭐ nOurPower DEFAULTS to ourPowerRaw -- un-armed inertness']
= function()
    local body = weaker_body()
    assert(body:find('local nOurPower = ourPowerRaw', 1, true),
        'nOurPower no longer defaults to ourPowerRaw. The default IS the '
        .. 'un-armed behaviour; if it changes, the lever stops being inert in '
        .. 'shipped games and becomes a live edit.')
    -- The armed assignment, and it must sit behind the helper.
    local armed = body:match('if ' .. HELPER:gsub('%.', '%%.')
        .. '%(%)%s*then%s*(.-)%s*end')
    assert(armed, 'the armed assignment is no longer guarded by '
        .. HELPER .. '(). Un-armed inertness rests on that guard.')
    assert(armed == 'nOurPower = ourPower', 'the guarded body is `' .. armed
        .. '`, not `nOurPower = ourPower`. The gate is supposed to switch '
        .. 'which of the two existing totals is read and nothing else.')
end

tests['[site] ⭐ ourPower is no longer a dead store']
= function()
    local body = weaker_body()
    -- Every occurrence of the bare name, minus the ones that are writes.
    local nAll = select(2, body:gsub('ourPower[^R%w]', ''))
    local nWrite = select(2, body:gsub('ourPower = ourPower', ''))
        + select(2, body:gsub('local ourPower = 0', ''))
    assert(nAll > nWrite, 'ourPower is written ' .. nWrite .. ' time(s) and '
        .. 'read nowhere -- it is a dead store again, which is the defect '
        .. 'this lever exists to end.')
end

tests['[site] ⭐ the two totals still differ in exactly one getter']
= function()
    local body = weaker_body()
    local ours, raw = {}, {}
    for line in body:gmatch('[^\n]+') do
        if line:find('ourPower = ourPower +', 1, true)
            or line:find('ourPower = ourPower *', 1, true) then
            ours[#ours + 1] = line
        elseif line:find('ourPowerRaw = ourPowerRaw', 1, true) then
            raw[#raw + 1] = line
        end
    end
    assert(#ours == #raw and #ours >= 4, 'the two accumulators are written '
        .. #ours .. ' and ' .. #raw .. ' times. They are supposed to move in '
        .. 'lockstep on every branch -- if one grew a term the other lacks, '
        .. '"they differ in one getter" stops being true and the whole '
        .. 'direction argument goes with it.')
    for _, line in ipairs(ours) do
        assert(not line:find('GetRawOffensivePower', 1, true),
            'an ourPower line reads the RAW getter: ' .. line)
    end
    for _, line in ipairs(raw) do
        assert(not line:find('GetOffensivePower()', 1, true),
            'an ourPowerRaw line reads the state-aware getter: ' .. line)
    end
    -- The one place the getter appears at all on our side.
    assert(select(2, body:gsub('unit:GetOffensivePower%(%)', '')) == 2,
        'the state-aware getter no longer appears exactly twice on our side '
        .. '(hero term + illusion term)')
end

tests['[site] ⭐ every sqrt on our side is Max(0,...)-guarded']
= function()
    local body = weaker_body()
    for line in body:gmatch('[^\n]+') do
        if line:find('math%.sqrt') then
            assert(line:find('Max(0,', 1, true),
                'an unguarded math.sqrt is back in J.WeAreStronger: ' .. line
                .. ' -- a negative product yields nan, and nan > x is false, '
                .. 'so the armed leg would answer "we are NOT stronger" for a '
                .. 'reason that has nothing to do with this lever. §4 prices '
                .. 'that case; this pin is why it cannot arrive by accident.')
        end
    end
end

tests['[site] the enemy total is still RAW-only -- the asymmetry premise']
= function()
    local body = weaker_body()
    local n = 0
    for line in body:gmatch('[^\n]+') do
        if line:find('enemyPower = enemyPower', 1, true) then
            n = n + 1
            assert(not line:find('GetOffensivePower()', 1, true),
                'the enemy total now reads the state-aware getter: ' .. line
                .. ' -- the argument for this lever is that the bot can see '
                .. 'its OWN cooldowns and not the enemy\'s. If the enemy side '
                .. 'became state-aware too, re-derive the direction before '
                .. 'quoting anything here.')
        end
    end
    assert(n >= 2, 'the enemy accumulator is written ' .. n .. ' times, not '
        .. 'the expected hero+illusion pair')
end

-- ==========================================================================
-- §2 THE PREMISE IS THE ENGINE'S, NOT THIS FILE'S.
-- ==========================================================================

tests['[doc] ⭐ the two getters mean what the direction claim needs']
= function()
    local doc = read(DOC)
    local raw = doc:match('`GetRawOffensivePower%(%)`[^\n]*')
    local eff = doc:match('`GetOffensivePower%(%)`[^\n]*')
    assert(raw and eff, 'the two offensive-power rows are gone from ' .. DOC)
    assert(eff:lower():find('cooldown') and eff:lower():find('mana'),
        'GetOffensivePower() no longer documents itself as respecting '
        .. 'cooldowns and mana: ' .. eff)
    assert(raw:lower():find('ignor'),
        'GetRawOffensivePower() no longer documents itself as ignoring them: '
        .. raw .. ' -- `ourPower <= ourPowerRaw`, and therefore the whole '
        .. '"arming can only withhold" direction, rests on this row.')
end

-- ==========================================================================
-- §3 THE HELPER. Gate-first, turbo-second, one id, no opinions of its own.
-- ==========================================================================

tests['[helper] ⭐ gate-first, turbo-second, exactly one id, reads no unit']
= function()
    local body = helper_body()
    local n = select(2, body:gsub('IsSoakCandidate', ''))
    assert(n == 1, 'the helper names ' .. n .. ' candidate ids; a second one '
        .. 'freezes the gate FALSE the day the other is promoted (the pullcad '
        .. 'trap -- a promoted id is in no armed string).')
    assert(body:find("IsSoakCandidate%( '" .. CAND .. "' %)"),
        "the helper's id is no longer '" .. CAND .. "'")
    local nGate = body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true)
    local nTurbo = body:find('IsModeTurbo', 1, true)
    assert(nGate and nTurbo and nGate < nTurbo,
        'the helper is no longer gate-first-then-turbo; un-armed it must '
        .. 'reach no engine call at all')
    assert(not body:find('bot', 1, true),
        'the helper now reads the bot. It answers one question -- "is this '
        .. 'lever live" -- and the call site owns everything else.')
end

tests['[helper] un-armed it is false, and that is not a corpus fact']
= function()
    local J = rf.load('tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
        'npc_dota_hero_obsidian_destroyer')
    assert(J.ShouldRateOurFightPowerByState() == false,
        'the helper answers true with nothing armed. Every shipped game would '
        .. 'take the armed branch.')
end

-- ==========================================================================
-- §4 ⭐⭐ THE PROOF. Exhaustive over a grid, not sampled over frames.
--
-- The shipped selection, mirrored. The mirror is checked against the real
-- helper in §4's last case, so it cannot drift into proving something the
-- tree does not do.
-- ==========================================================================

local function selection(nRaw, nState, nEnemy, bArmed)
    local nOurPower = nRaw
    if bArmed then nOurPower = nState end
    return nOurPower > nEnemy
end

--- Every ordering that matters, including the two that bite.
local NAN = 0 / 0
local GRID = {
    -- { raw, state, enemy, label }
    { 100, 100, 50,  'state == raw, we lead' },
    { 100, 100, 150, 'state == raw, we trail' },
    { 100, 100, 100, 'state == raw, dead even -- `>` is strict' },
    { 100, 40,  50,  '⭐ the lever\'s whole domain: raw says yes, state says no' },
    { 100, 40,  30,  'both say yes' },
    { 100, 40,  150, 'both say no' },
    { 100, 40,  40,  'enemy exactly equals our state total' },
    { 100, 40,  100, 'enemy exactly equals our raw total' },
    { 0,   0,   0,   'nobody in radius' },
    { 100, NAN, 50,  '⛔ nan state total (unguarded sqrt) -- always false' },
}

tests['[proof] ⭐⭐ un-armed, the selection IS `ourPowerRaw > enemyPower`']
= function()
    for _, c in ipairs(GRID) do
        local got = selection(c[1], c[2], c[3], false)
        local want = c[1] > c[3]
        assert(got == want, 'un-armed disagreed with the shipped expression '
            .. 'on case "' .. c[4] .. '": got ' .. tostring(got) .. ', the '
            .. 'shipped `ourPowerRaw > enemyPower` gives ' .. tostring(want)
            .. '. Un-armed inertness is the promise this lever ships on.')
    end
end

tests['[proof] ⭐⭐ armed can only WITHHOLD "we are stronger", never add it']
= function()
    local nMoved = 0
    for _, c in ipairs(GRID) do
        local nRaw, nState = c[1], c[2]
        if nState == nState and nState <= nRaw then   -- nan-safe
            local bUn = selection(nRaw, nState, c[3], false)
            local bArm = selection(nRaw, nState, c[3], true)
            assert(not (bArm and not bUn), 'on case "' .. c[4] .. '" arming '
                .. 'turned a NO into a YES. GetOffensivePower() <= '
                .. 'GetRawOffensivePower() by construction (§2), so the armed '
                .. 'leg is a subset of the un-armed one -- if that ever fails '
                .. 'the direction claim in the header is wrong, not the test.')
            if bUn ~= bArm then nMoved = nMoved + 1 end
        end
    end
    assert(nMoved > 0, 'no grid case moved at all, so this proof is vacuous. '
        .. 'The grid must keep at least one raw-yes/state-no cell.')
end

tests['[proof] ⛔ a nan state total is false, not an error']
= function()
    assert(selection(100, NAN, 50, true) == false,
        'nan > x stopped being false. The Max(0,...) pin in §1 is the reason '
        .. 'this case cannot arrive in the tree; this case is why that pin '
        .. 'exists.')
end

tests['[proof] ⭐ the mirror agrees with the shipped helper, both ways']
= function()
    local FRAME = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
    local SUBJ = 'npc_dota_hero_obsidian_destroyer'
    local J = rf.load(FRAME, SUBJ)
    assert(selection(100, 40, 50, J.ShouldRateOurFightPowerByState())
        == (100 > 50), 'un-armed, the mirror and the tree disagree')
    local _, bot = rf.load(FRAME, SUBJ)
    local sSide = bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
    ss.with_candidate(CAND, function()
        local J2 = rf.load(FRAME, SUBJ)
        assert(J2.ShouldRateOurFightPowerByState() == true,
            'the gate did NOT open under its own id on its own side, so every '
            .. 'armed reading here measured the un-armed tree')
        assert(selection(100, 40, 50, J2.ShouldRateOurFightPowerByState())
            == (40 > 50), 'armed, the mirror and the tree disagree')
    end, sSide)
end

-- ==========================================================================
-- §5 REAL FRAMES. What the corpus can and cannot answer, measured.
-- ==========================================================================

--- Every fixture, recursively -- tests/fixtures has subdirectories.
local _frames
local function all_frames()
    if _frames then return _frames end
    local p = assert(io.popen('find tests/fixtures -name "f_*.lua" | sort'))
    local out = {}
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units and fx.self then
            out[#out + 1] = { path = path, fx = fx }
        end
    end
    p:close()
    _frames = out
    return out
end

--- ONE walk of the raw fixture tables for every reading below. Reading the
--- tables directly (not through rf.load) is deliberate: the question here is
--- what the DUMPER emitted, and a mock that synthesises a default would answer
--- a different question.
local _sweep
local function corpus_sweep()
    if _sweep then return _sweep end
    local s = {
        nFrames = 0, nHeroes = 0,
        nPowerFields = 0,          -- offensive power, any spelling: expected 0
        nManaFields = 0,           -- reverse call: a field that IS there
        nDegraded = 0,             -- heroes with a leveled ability on cd, or low mp
        nFramesWithDegradedAlly = 0,
        nFramesAllFresh = 0,
    }
    for _, f in ipairs(all_frames()) do
        s.nFrames = s.nFrames + 1
        local bAny = false
        for _, u in ipairs(f.fx.units) do
            if type(u) == 'table' and u.name then
                s.nHeroes = s.nHeroes + 1
                for k in pairs(u) do
                    local sk = tostring(k):lower()
                    if sk:find('offensive') or sk:find('power') then
                        s.nPowerFields = s.nPowerFields + 1
                    end
                    if sk == 'max_mp' then
                        s.nManaFields = s.nManaFields + 1
                    end
                end
                local bDegraded = false
                if u.max_mp and u.max_mp > 0 and u.mp
                    and (u.mp / u.max_mp) < 0.25 then
                    bDegraded = true
                end
                for _, a in ipairs(u.abilities or {}) do
                    if type(a) == 'table' and (a.level or 0) > 0
                        and (a.cd or 0) > 0 then
                        bDegraded = true
                    end
                end
                if bDegraded then
                    s.nDegraded = s.nDegraded + 1
                    bAny = true
                end
            end
        end
        if bAny then
            s.nFramesWithDegradedAlly = s.nFramesWithDegradedAlly + 1
        else
            s.nFramesAllFresh = s.nFramesAllFresh + 1
        end
    end
    _sweep = s
    return s
end

tests['[world W1] ⛔ neither getter is in the dump -- and the zero is reverse-called']
= function()
    assert(#all_frames() >= 110, 'only ' .. #all_frames() .. ' fixtures '
        .. 'enumerated; the recursive corpus is ~118. A top-level-only walk '
        .. 'reads fewer, and that undercount is what makes a zero look like a '
        .. 'fact.')
    local s = corpus_sweep()
    -- ⭐ 0NEXT27: the scanner proves itself on a field that MUST be there
    -- before its zero on the field in question means anything.
    assert(s.nManaFields == s.nHeroes and s.nHeroes > 500,
        'the reverse call failed: the same scanner found max_mp on '
        .. s.nManaFields .. ' of ' .. s.nHeroes .. ' dumped heroes. Until it '
        .. 'finds a field that is certainly present, its zero below is a '
        .. 'statement about the scanner, not about the corpus.')
    assert(s.nPowerFields == 0, s.nPowerFields .. ' offensive-power field(s) '
        .. 'now appear in the corpus. ⭐ THAT IS THE GOOD NEWS: the dumper has '
        .. 'started emitting them, so ourPower and ourPowerRaw are computable '
        .. 'on a real frame for the first time and this lever can be pinned '
        .. 'END TO END -- make a fixture on a frame where the two totals '
        .. 'straddle enemyPower and assert the armed leg answers false where '
        .. 'the shipped one answers true. Then delete this assertion. '
        .. '(queue.json:strategy-52 is the request that buys it.)')
end

tests['[world W2] ⭐ the lever\'s live domain, priced on real frames']
= function()
    local s = corpus_sweep()
    assert(s.nHeroes > 500, 'only ' .. s.nHeroes .. ' dumped heroes')
    -- The state-aware getter respects cooldowns and mana (§2), and BOTH are
    -- dumped. So this is not the engine's number, but it does bound how often
    -- the two totals could possibly differ.
    assert(s.nDegraded > 0, 'not one dumped hero in the whole corpus has a '
        .. 'leveled ability on cooldown or is under 25% mana. If that is '
        .. 'really true, GetOffensivePower() and GetRawOffensivePower() would '
        .. 'agree everywhere here and this lever would be a CONSTRUCTIVE zero '
        .. '-- say so in the report instead of quoting §4.')
    assert(s.nFramesWithDegradedAlly > 0 , 'no frame has a degraded hero')
    assert(s.nFramesAllFresh > 0, 'EVERY frame has a degraded hero, which '
        .. 'makes this reading uninformative in the other direction -- it '
        .. 'stops distinguishing anything. Re-price before quoting it.')
end

-- ==========================================================================
-- §6 THE GATE. Controls.
-- ==========================================================================

local FRAME = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local SUBJ  = 'npc_dota_hero_obsidian_destroyer'

local function side_of()
    local _, bot = rf.load(FRAME, SUBJ)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

tests['[control] un-armed the gate is shut'] = function()
    local J = rf.load(FRAME, SUBJ)
    assert(J.IsSoakCandidate(CAND) == false,
        'the gate is open with nothing armed')
end

tests['[control] armed on the other side the gate stays shut'] = function()
    local sOther = side_of() == 'radiant' and 'dire' or 'radiant'
    ss.with_candidate(CAND, function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate(CAND) == false,
            'the gate fired for a bot on the other side')
        assert(J.ShouldRateOurFightPowerByState() == false,
            'the helper fired for a bot on the other side')
    end, sOther)
end

tests['[control] armed under another id the gate stays shut'] = function()
    ss.with_candidate('siegecap', function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate(CAND) == false,
            'the gate fired under a different candidate id')
        assert(J.ShouldRateOurFightPowerByState() == false,
            'the helper fired under a different candidate id')
    end, side_of())
end

return tests
