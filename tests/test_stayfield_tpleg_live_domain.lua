-- [owner priority P2 / charter 0NEXT12] What is left of `stayfield`'s domain --
-- the TP leg of the field-regen family -- ON THE STRING THE WAVES ACTUALLY FLY.
--
-- ⭐ THE READING (2026-09-14, tests/_stayfield_tpleg_sweep.lua over 1039 live
-- hero frames on the 26-id member string):
--
--     solo_S 24   live_S 2    trigger('撤退:3') 76   branch_open 4
--     margin_solo 1           margin_live 0
--
-- ⚖️ DISPOSITION MADE, 2026-09-14T16:xxZ (director, RULING 37; full text
-- test_set.md §HK). This file's closing sentence -- "that is a disposition
-- question and it belongs to the director" -- was answered ON this reading:
-- `stayfield` is RETURNED out of the member string (armed 26 → 25, disposition
-- CALLSITE-EMPTY). ⛔ NOT a reject: gate, predicate, both wrappers and this
-- file are kept verbatim, bots/ zero diff. The census above therefore describes
-- the string as it stood WHEN THE RULING WAS MADE -- it is the evidence that
-- got acted on, not a stale number. Two guards below carry the consequence.
--
-- ⭐ AND THE HALF OF THE RULING THAT CAME OUT OF THIS FILE'S OWN FRAME: the
-- proposal handed up with it asked the director to write "P2 has no case on the
-- TP leg" into OWNER_PRIORITIES.md. That was REFUSED. `FieldRegenSipValue = 85`
-- is a FLOOR, not a measurement -- J.FIELD_SIP_HEAL has no magic_wand row (the
-- declaration at jmz_func.lua:5692-5696 says why: "its charge count ... is not
-- in the dump"), and slot 1 of this very fixture is a magic wand. The rescue
-- band is computable and narrow: 15 HP/charge, best SINGLE sip ⇒ the wand alone
-- clears 272 only at ≥19 charges. Narrow is not empty, and the difference is
-- precisely the number nobody can read ⇒ the frame's status is UNCERTIFIABLE,
-- blocked on owed_executions.json:wandlimbo_charge_instrument.
--
-- ⛔ AND THE HEADLINE IS *NOT* THE ZERO -- it is the ONE.
--
-- tests/test_stayfield2_live_domain.lua measured the WALK leg on the same day
-- and the same corpus: 19 marginal frames in a world where only `stayfield2` was
-- armed, 0 on the live string, all 19 taken by `fieldsip`'s magnitude clause.
-- The obvious inference is that the TP leg is the same story. It is not, and the
-- difference is the whole content of this file:
--
--     the walk leg HAD a domain and `fieldsip` took it;
--     the TP leg NEVER HAD ONE -- its call site had already taken 23 of the 24,
--     and `fieldsip` took the single frame that was left.
--
-- ⭐⭐ AND THAT SINGLE FRAME IS THIS LEVER'S OWN PINNED FRAME, i.e. owner
-- priority P2's 铁证帧: f_260822_063722_lina_tp_home, the seed-888 dire Lina the
-- jmz_func comment above J.ShouldRegenNotTpHome describes ("31.8% HP, nearest
-- enemy 6,596 units away, faerie_fire in slot 0 -- TPs home, lands 33 units from
-- the fountain and is out of the game for 20.3 seconds"). On the live member
-- string that frame is vetoed, and the veto is arithmetic, not a judgement call:
--
--     FieldRegenSipValue = 85  (item_faerie_fire)
--     0.25 * GetMaxHealth = 0.25 * 1088 = 272
--     85 >= 272  ->  false  ->  J.IsFieldSipEnough false -> S false
--
-- ⇒ ON TODAY'S MEMBER STRING, `fieldsip` VETOES THE ONE FRAME owner priority P2
-- WAS FILED ON. Neither id is wrong on its own reading: `fieldsip` is saying a
-- faerie fire cannot rescue a 31.8% Lina, which is true. What has never been
-- said is that the two cannot both be in the string and still leave P2 anything
-- to buy on this leg. That is a disposition question and it belongs to the
-- director; this file only makes it unavoidable.
--
--     ⇒ REUSABLE CRITERION (the sibling's, one layer down). "How much domain did
--       the live string leave this id" is not one question per FAMILY, it is one
--       per CALL SITE. Two wrappers over the SAME predicate, armed in the SAME
--       string, on the SAME corpus, lost their domains to DIFFERENT things --
--       and the reading taken on either one does not transfer to the other. The
--       walk leg's absorber was a sibling helper; this leg's absorber is 20-odd
--       conjuncts of the branch it was dropped into.
--
-- ⚠️ WHAT IS EXPENSIVE HERE AND WHERE IT LIVES (charter 亥). The census above is
-- a 1039-frame corpus walk: ~32s, because tests/mock/replay_fixture.lua's load is
-- ~30ms and there is one per hero-frame. It therefore CANNOT live in this file:
-- the push hook's per-test cap is 5.5s (tools/agent/lua_gate_measure.py) and
-- 开工自检's Lua leg budget is 120s FOR THE WHOLE LEG, of which the walk-leg
-- sibling already spends 45s. A second 1039-frame census in that leg is not a
-- slow test, it is a leg that stops certifying anything.
-- So the split is deliberate and it is stated rather than hidden:
--   * the CENSUS is tests/_stayfield_tpleg_sweep.lua, run by hand and quoted in
--     iterations/reports/strategy/20260914T12xxxxZ.md with its exact command;
--   * THIS file drives the census's three DECISIVE frames on the real mock world
--     (~0.3s) and ratchets the mechanism off the shipped source, so that if the
--     behaviour moves the reading is red here and not only in a report;
--   * cs.corpus() guards the population: a grown corpus does not invalidate a
--     frame drive, but it does mean the CENSUS is stale, and the failure message
--     says to re-run the sweep rather than to edit a number.
--
-- ⚠️ UPPER BOUND, stated because it is a real limit. `X` in
-- ability_item_usage_generic is a FILE-LOCAL table, so `X.CanJuke()` and
-- `X.GetNumHeroWithinRange(1600)` cannot be driven; the sweep reads the enemy
-- ring with the same readable proxy tests/_tprecov_sweep.lua uses and does not
-- model CanJuke. `branch_open` is therefore an upper bound on reachability. An
-- upper bound is the RIGHT side of the inequality for the zero (margin_live <=
-- 0 + undriven conjuncts can only close the branch further) and the WRONG side
-- for the one -- so margin_solo = 1 is not left resting on it: that frame is a
-- REPLAY-OBSERVED firing of this very branch (the bot did TP home in the .dem
-- the fixture was cut from), so the undriven conjuncts held on the real frame.
--
-- Usage: lua5.1 tests/run_tests.lua stayfield_tpleg_live_domain
-- ⚠️ NOT `lua5.1 tests/test_stayfield_tpleg_live_domain.lua` -- run directly, a
-- test file returns its table without calling anything and exits 0 having
-- executed zero bodies (run_tests.lua header, GH #200; charter 戌 was filed the
-- day four files were called green that way). The runner is the only entry point
-- that can tell a pass from a no-op. Its filter is a FILENAME SUBSTRING, not a
-- path.
-- [detector][ratchet]

package.path = 'tests/?.lua;' .. package.path

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'
local cs = require('corpus_scale')
local rf = require('mock.replay_fixture')

-- The census, as recorded by tests/_stayfield_tpleg_sweep.lua on 2026-09-14 over
-- the 26-id member string. Counts are SUMS OVER FIXTURES, so the corpus-scale
-- doctrine applies: what can only grow under append is a FLOOR, and the claims
-- whose entire content is a ZERO stay equalities -- those are the ones this
-- file's conclusion is argued from and they must go red the moment the corpus
-- grows a counter-example.
local CENSUS = {
    frames      = 1039,  -- FLOOR
    solo_S      = 24,    -- FLOOR
    live_S      = 2,     -- FLOOR
    trigger     = 76,    -- FLOOR: frames inside the '撤退:3' HP/sum trigger
    branch_open = 4,     -- FLOOR: ... and open on every readable conjunct
    margin_solo = 1,     -- the ONE, and it is P2's own 铁证帧
    margin_live = 0,     -- ⭐ EQUALITY, and it is the finding
}

-- The three frames the census singles out. Each is driven below.
local PINNED = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local PINNED_HERO = 'npc_dota_hero_lina'
local LIVE_S_FRAMES = {
    { 'tests/fixtures/f_071859_qop_salve.lua', 'npc_dota_hero_queen_of_pain' },
    { 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua', 'npc_dota_hero_juggernaut' },
}

local function read(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- Strip comments so a source ratchet cannot be satisfied by prose that merely
--- describes the code it is supposed to be reading. Both files carry long
--- comments naming every helper and modifier asserted here.
local function mask_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

local function fn_body(src, name)
    -- `name` is given PLAIN; the escaping happens here, once. A pre-escaped name
    -- double-escapes the dot and the find silently matches nothing -- a ratchet
    -- that cannot locate its subject must fail loudly, not vacuously.
    local pat = 'function%s+' .. name:gsub('%.', '%%.') .. '%s*%b()'
    local i = src:find(pat)
    assert(i, 'function ' .. name .. ' not found in ' .. JMZ)
    local j = src:find('\nend', i, true)
    assert(j, 'function ' .. name .. ' has no terminating end')
    return src:sub(i, j)
end

--- The '撤退:3' branch text, anchored on its cast motive STRING (code, never a
--- comment) so no comment can open or close the block.
local function branch3()
    local src = read(AIUG)
    local a = src:find('if ( botHP < 0.34 or botHP + botMP < 0.43 )', 1, true)
    assert(a, "the '撤退:3' branch head is gone from " .. AIUG
        .. ' -- this reading is about a branch that no longer exists')
    local b = src:find("sCastMotive = '撤退:3'", a, true)
    assert(b, "the '撤退:3' cast motive is gone from " .. AIUG)
    return (src:sub(a, b):gsub('%-%-[^\n]*', ''))
end

-- ---------------------------------------------------------------------------
-- The live member string, read through the SAME parser 开工自检 uses
-- (tools/agent/stale_waits.py: armed_ids) and never retyped here: a test that
-- carries its own copy of the arm string can agree with itself while disagreeing
-- with the waves.
-- ---------------------------------------------------------------------------
local armed_cache
local function armed()
    if armed_cache then return armed_cache end
    local cmd = "python3 -c \"import sys; sys.path.insert(0,'tools/agent'); "
        .. "from stale_waits import armed_ids; print(','.join(sorted(armed_ids())))\" 2>/dev/null"
    local p = assert(io.popen(cmd))
    local out = p:read('*a')
    p:close()
    out = (out or ''):gsub('%s+$', '')
    assert(out ~= '', 'could not read the armed member string from test_set.md')
    armed_cache = out
    return out
end

local function armed_list()
    local t = {}
    for a in armed():gmatch('[^,]+') do t[#t + 1] = a end
    return t
end

local function armed_has(id)
    for a in armed():gmatch('[^,]+') do
        if a == id then return true end
    end
    return false
end

--- Load one fixture frame in the HONEST turbo world (GH #93: by name the fixture
--- world is Turbo, by the literal 23 it is not, and every predicate here opens
--- with IsModeTurbo).
local function world(path, subject)
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load(path, subject)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    return J, bot
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- Re-point the gate closure. Every predicate reads J.IsSoakCandidate at CALL
--- time, so this gives a second world without a second load. The assumption --
--- that nothing between load and call MEMOISES a gate answer -- is the same one
--- tests/_stayfield2_livedomain_sweep.lua states, and it is what the two
--- opposite answers below would break if it ever stopped holding.
local function arm(J, list)
    local set = {}
    for _, a in ipairs(list) do set[a] = true end
    J.IsSoakCandidate = function(id) return set[id] == true end
end

local function corpus_size()
    local p = assert(io.popen('ls tests/fixtures'))
    local n = 0
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then n = n + 1 end
    end
    p:close()
    return n
end

-- ---------------------------------------------------------------------------
-- Source ratchets: the MECHANISM the reading is attributed to, parsed off the
-- shipped tree rather than written down here.
-- ---------------------------------------------------------------------------

tests['[ratchet][source] the TP wrapper is gated on stayfield and delegates to S'] = function()
    local src = mask_comments(read(JMZ))
    local body = fn_body(src, 'J.ShouldRegenNotTpHome')
    assert(body:find("IsSoakCandidate%(%s*'stayfield'%s*%)"),
        'J.ShouldRegenNotTpHome is no longer gated on stayfield')
    assert(body:find('J.ShouldRegenNotGoHome', 1, true),
        'J.ShouldRegenNotTpHome no longer delegates to J.ShouldRegenNotGoHome, '
        .. 'so S is not its predicate and this reading is about the wrong thing')
end

tests['[ratchet][source] `fieldsip` is the magnitude clause inside S'] = function()
    local src = mask_comments(read(JMZ))
    local body = fn_body(src, 'J.ShouldRegenNotGoHome')
    assert(body:find('J.IsFieldSipEnough', 1, true),
        'J.ShouldRegenNotGoHome no longer calls J.IsFieldSipEnough -- the '
        .. 'mechanism this file attributes the live veto to is gone, and the '
        .. 'reading has to be re-taken, not re-based')
    local sip = fn_body(src, 'J.IsFieldSipEnough')
    assert(sip:find("IsSoakCandidate%(%s*'fieldsip'%s*%)%s*then%s*return%s+true"),
        "J.IsFieldSipEnough stopped being a `return true` early-out on the "
        .. "'fieldsip' gate; unarmed S is no longer the predicate the solo "
        .. 'reading assumes and both worlds below change meaning')
end

tests['[ratchet][source] the arithmetic that vetoes the pinned frame is 0.25 x maxHP of a single sip'] = function()
    local src = mask_comments(read(JMZ))
    assert(src:find('J.FIELD_SIP_MIN_FRACTION%s*=%s*0%.25'),
        'FIELD_SIP_MIN_FRACTION moved off 0.25 -- the 85-vs-272 arithmetic in '
        .. 'this file is stale; re-run tests/_stayfield_tpleg_sweep.lua')
    assert(src:find('item_faerie_fire%s*=%s*85'),
        'the faerie fire heal value moved off 85 -- same consequence')
    local sip = fn_body(src, 'J.IsFieldSipEnough')
    assert(sip:find('J.FieldRegenSipValue', 1, true)
        and sip:find('J.FIELD_SIP_MIN_FRACTION', 1, true),
        'J.IsFieldSipEnough no longer compares a single sip against the '
        .. 'fraction of max health')
end

tests['[ratchet][source] one lever, one call site, and it is the 撤退:3 branch'] = function()
    local src = mask_comments(read(AIUG))
    local n, at = 0, 1
    while true do
        local i = src:find('J.ShouldRegenNotTpHome', at, true)
        if i == nil then break end
        n = n + 1
        at = i + 1
    end
    assert(n == 1, 'J.ShouldRegenNotTpHome has ' .. n .. ' call sites in ' .. AIUG
        .. ', not 1 -- this file measures ONE call site\'s domain and the '
        .. 'reading no longer covers the lever')
    local b3 = branch3()
    assert(b3:find('J.ShouldRegenNotTpHome', 1, true),
        "the '撤退:3' branch no longer carries the wrapper")
end

tests['[ratchet][source] the branch already negates the flask, by name'] = function()
    -- This is the conjunct that blocks BOTH live-S frames, and the whole
    -- closed-form half of the zero rests on it being in the branch rather than
    -- in a comment about the branch.
    local b3 = branch3()
    assert(b3:find('itemFlask == nil', 1, true),
        "the '撤退:3' branch no longer requires `itemFlask == nil`; the two "
        .. 'live-S frames are no longer blocked for the reason this file gives')
    for _, m in ipairs({ 'modifier_tango_heal', 'modifier_flask_healing' }) do
        assert(b3:find(m, 1, true),
            "the '撤退:3' branch no longer vetoes " .. m)
    end
end

-- ---------------------------------------------------------------------------
-- Preconditions: this reading is a statement about ONE member string.
-- ---------------------------------------------------------------------------

tests['[ratchet][precondition] both ids are armed TODAY, or the census is about a dead world'] = function()
    -- If either id leaves the string the reading is not wrong -- it is about a
    -- world that no longer exists, and the honest response is to re-run the
    -- sweep, not to edit a number. Going red here is that instruction.
    --
    -- ⭐ 2026-09-14T16:xxZ, DIRECTOR. `stayfield` left the string, and this
    -- guard fired exactly as designed -- on the pusher's own hook, in the same
    -- work unit that removed it (GH #624's whole point). It is NOT deleted and
    -- NOT weakened to `true`: what changes is that ONE named exit is now
    -- allowed, and it has to be PROVED from the archive rather than assumed.
    --
    -- Why an exit exists at all: this file's own header ends "that is a
    -- disposition question and it belongs to the director; this file only makes
    -- it unavoidable." The disposition was made -- RULING 37, 退集 (armed
    -- 26 → 25), disposition CALLSITE-EMPTY, full text test_set.md §HK -- and it
    -- was made ON this reading. So the census is not stale here; it is the
    -- evidence that got acted on. Re-running the sweep on the 25-string would
    -- measure live_S = 0 BY CONSTRUCTION (the gate is simply off), which is a
    -- vacuous number wearing the old number's name -- the exact "green for the
    -- wrong reason" shape this lab keeps paying for.
    --
    -- ⛔ WHAT STILL GOES RED: a SILENT removal. The exit demands the ruling's
    -- own tokens be present in the archive, so dropping `stayfield` out of the
    -- string without ruling it still fails here.
    if not armed_has('stayfield') then
        local f = assert(io.open('iterations/streams/test_set.md', 'r'),
            'stayfield left the member string and test_set.md cannot be read '
            .. 'to check whether that was a ruling or an accident')
        local doc = f:read('*a')
        f:close()
        assert(doc:find('stayfield_tp_disposition', 1, true),
            'stayfield left the member string with NO disposition on record '
            .. '(test_set.md carries no `stayfield_tp_disposition`) -- either '
            .. 'rule it and archive the ruling, or put it back')
        assert(doc:find('RULING 37', 1, true),
            'stayfield left the member string but test_set.md carries no '
            .. 'RULING 37 -- the retirement is not archived; re-run '
            .. 'tests/_stayfield_tpleg_sweep.lua or restore the id')
    end
    -- `fieldsip` has NO exit. It is the absorber this file attributes the last
    -- frame to, and the P2 correction in OWNER_PRIORITIES.md rests on that
    -- attribution -- if it leaves the string, the attribution must be re-taken.
    assert(armed_has('fieldsip'),
        'fieldsip left the member string; the live veto this file attributes '
        .. 'margin_live = 0 to is gone -- re-run tests/_stayfield_tpleg_sweep.lua')
end

tests['[ratchet][precondition] the census population has not shrunk'] = function()
    local n = corpus_size()
    cs.corpus(n, 'tests/fixtures')
    -- The census is a sum over fixtures. Growth does not falsify a frame drive,
    -- but it does make the COUNTS stale, and a zero that was true over 112
    -- fixtures is exactly the claim a 113th can break.
    cs.ratchet(n, 112, 'fixture count at the time of the 0NEXT12 census')
end

-- ---------------------------------------------------------------------------
-- The frame drives. Three loads, the three frames the census singles out.
-- ---------------------------------------------------------------------------

tests['[detector] the pinned P2 frame IS in the solo margin -- the lever is not structurally dead'] = function()
    -- ANTI-VACUUM. `margin_live = 0` would be worthless if this lever could
    -- never speak anywhere: the finding is that it CAN, on exactly the frame it
    -- was written for, and that today's string is what silences it.
    local J, bot = world(PINNED, PINNED_HERO)
    assert(bot ~= nil and bot:IsAlive(), PINNED .. ' no longer carries a live ' .. PINNED_HERO)
    arm(J, { 'stayfield' })
    assert(J.ShouldRegenNotTpHome(bot) == true,
        'the TP wrapper is FALSE on its own pinned frame even with stayfield '
        .. 'alone armed -- margin_solo = 1 no longer holds and the census is stale')
    -- ... and the branch it guards is open on this frame by every conjunct a
    -- fixture can answer, so the wrapper's TRUE actually cancels a home TP.
    assert(bot:GetLevel() >= 9, 'the pinned frame fell below the branch level gate')
    assert(J.IsItemAvailable('item_flask') == nil,
        'the pinned frame grew a main-slot flask; the branch vetoes it and the '
        .. 'frame is no longer in this call site\'s domain')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) <= 1,
        'the pinned frame grew a second enemy inside 1600')
    assert(bot:DistanceFromFountain() > 5500 - 600,
        'the pinned frame is no longer far enough from the fountain for the branch')
    unprobe()
end

tests['[detector] ... and the live member string takes that one frame, by arithmetic'] = function()
    local J, bot = world(PINNED, PINNED_HERO)
    -- ⭐ 2026-09-14T16:xxZ, DIRECTOR -- the driven set is the CENSUSED string,
    -- not `armed_list()` alone, and the difference is the point.
    --
    -- RULING 37 took `stayfield` out of the member string. Driving bare
    -- `armed_list()` after that still makes the assertion below PASS -- the
    -- wrapper answers false at its own `IsSoakCandidate('stayfield')` line,
    -- before any arithmetic runs. That is a pass FOR THE WRONG REASON: the
    -- claim this test exists to hold is that the MAGNITUDE CLAUSE takes the
    -- frame, and a gate that is simply off proves nothing about the clause.
    -- (Same shape as the director's own 09-14 mutation stand, where a command
    -- that "looked like it tested X" tested something else and read green.)
    --
    -- So the frame is driven in the world the census actually measured: the
    -- live string PLUS `stayfield`. Every assertion below then still has teeth,
    -- and `fieldsip` is still read off the live string rather than hardcoded.
    local driven = armed_list()
    driven[#driven + 1] = 'stayfield'
    arm(J, driven)
    -- ⛔ AND PIN THE DRIVEN WORLD, because the repair above is otherwise
    -- INVISIBLE TO THIS TEST: reverting to bare `armed_list()` changes only the
    -- REASON the next assertion passes, never the result, so without this line
    -- a mutation that re-vacuums the test survives green. Measured, not
    -- assumed -- the director ran exactly that mutation (M2) when landing the
    -- repair, and it SURVIVED until this assertion existed.
    assert(J.IsSoakCandidate('stayfield') == true,
        'the driven world does not have `stayfield` armed, so the assertions '
        .. 'below are answered by the wrapper\'s own gate and prove nothing '
        .. "about `fieldsip`'s magnitude clause -- this test is vacuous")
    assert(J.IsSoakCandidate('fieldsip') == true,
        '`fieldsip` is not in the driven world (it is read off the live member '
        .. 'string) -- the attribution below has no absorber to attribute to')
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'the TP wrapper is TRUE on the pinned frame under the live member '
        .. 'string -- margin_live is no longer 0 and `stayfield` has a live '
        .. 'domain again; re-run tests/_stayfield_tpleg_sweep.lua before acting')
    -- WHICH clause did it, driven rather than asserted: the situation half
    -- carries no gate of its own, so situation-true + sip-false is `fieldsip`
    -- and nothing else.
    assert(J.IsFieldRegenSituation(bot) == true,
        'the pinned frame left the field-regen situation entirely; the veto is '
        .. 'no longer attributable to fieldsip')
    assert(J.HasFieldRegenSource(bot) == true,
        'the pinned frame no longer carries a drinkable at all')
    assert(J.IsFieldSipEnough(bot) == false,
        'the magnitude clause no longer rejects the pinned frame -- this file\'s '
        .. 'whole attribution is stale')
    -- The numbers, so the failure message is a diagnosis and not a boolean.
    local nSip = J.FieldRegenSipValue(bot)
    local nNeed = J.FIELD_SIP_MIN_FRACTION * bot:GetMaxHealth()
    assert(nSip == 85, 'the pinned frame\'s best sip is ' .. tostring(nSip)
        .. ', not the faerie fire\'s 85')
    assert(math.abs(nNeed - 272) < 0.5, 'the pinned frame\'s threshold is '
        .. tostring(nNeed) .. ', not 0.25 * 1088 = 272')
    assert(nSip < nNeed, 'the sip now clears the threshold; re-take the census')
    unprobe()
end

tests['[detector] both live-S frames are blocked by a conjunct the branch already carries'] = function()
    -- The closed-form half of the zero: S survives the live string on exactly
    -- two frames, and on both of them the '撤退:3' branch is already shut by its
    -- own `itemFlask == nil`. So they were never this leg's to take, with or
    -- without `fieldsip`. Counted rather than argued, one frame at a time.
    local nBlocked = 0
    for _, spec in ipairs(LIVE_S_FRAMES) do
        local J, bot = world(spec[1], spec[2])
        assert(bot ~= nil and bot:IsAlive(), spec[1] .. ' no longer carries a live ' .. spec[2])
        arm(J, armed_list())
        assert(J.ShouldRegenNotGoHome(bot) == true,
            spec[1] .. ' / ' .. spec[2] .. ': S is no longer TRUE on the live '
            .. 'member string -- live_S = 2 is stale, re-run the sweep')
        assert(J.IsItemAvailable('item_flask') ~= nil,
            spec[1] .. ' / ' .. spec[2] .. ': the main-slot flask is gone, so '
            .. "the branch's own `itemFlask == nil` no longer blocks this frame "
            .. 'and it may have entered the TP leg\'s domain')
        nBlocked = nBlocked + 1
        unprobe()
    end
    assert(nBlocked == CENSUS.live_S, 'drove ' .. nBlocked .. ' live-S frames, '
        .. 'census recorded ' .. CENSUS.live_S)
end

tests['[ratchet] the recorded census is internally consistent and says the TP leg was never full'] = function()
    -- Not a re-measurement -- an arithmetic guard on the numbers this file
    -- carries, so a careless re-baseline cannot produce a census that says
    -- nothing. The inequality is the finding: the call site absorbed 23 of the
    -- 24 solo frames BEFORE `fieldsip` was ever armed.
    assert(CENSUS.margin_live == 0, 'margin_live is recorded non-zero')
    assert(CENSUS.margin_solo == 1, 'margin_solo is recorded as ' .. CENSUS.margin_solo)
    assert(CENSUS.margin_solo <= CENSUS.branch_open,
        'the solo margin exceeds the branch-open upper bound')
    assert(CENSUS.margin_live <= CENSUS.margin_solo,
        'the live margin exceeds the solo margin; arming more ids can only '
        .. 'narrow S, so this census is impossible')
    assert(CENSUS.live_S <= CENSUS.solo_S, 'live_S exceeds solo_S')
    assert(CENSUS.solo_S - CENSUS.margin_solo == 23,
        'the call site no longer absorbs 23 of the 24 solo-S frames -- that '
        .. 'number IS the finding (the TP leg never had a domain to lose) and '
        .. 'it has to be re-measured, not re-typed')
    assert(CENSUS.branch_open <= CENSUS.trigger and CENSUS.trigger <= CENSUS.frames,
        'the census funnel is not monotone')
end

return tests
