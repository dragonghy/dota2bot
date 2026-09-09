-- BLIND-A: can condition (a) be BOUGHT for 'roamidle' and 'campsel'?
-- Director ruling 2026-09-09, test_set.md §GE.  Same question as §GC
-- (wandlimbo/tpdead) and §GD (cmrguard), asked of the two remaining
-- `narrat=1` ids in tools/agent/verify_coverage.py.
--
-- (a) is "the fix really executes in a real game, and its decision is right".
-- It is NOT "given this input, is the decision right" -- that is what the two
-- ids' existing GREEN tests answer, and both of those tests write the pivotal
-- input themselves.  This file measures the OTHER half: does the input ever
-- reach the decision from a real frame, on either instrument path (the fixture
-- corpus, and the behavioural dumper)?
--
-- ============================================================================
-- 'roamidle' -- THE ARM IS CONSTRUCTIVELY SHUT, AND IT FAILS CLOSED
-- ============================================================================
-- The gate (bots/mode_team_roam_generic.lua) only fires on `bRelocated`, and
-- jmz_func.lua's J.CheckBotIdleState sets that true inside exactly one
-- disjunction:
--
--     if bot:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE
--     or botMode == BOT_MODE_ITEM
--     or botMode == BOT_MODE_FARM then
--
-- api.install auto-resolves every unknown ALL_CAPS global to a distinct
-- sentinel >= 1001 (IDLE = 1174, ITEM = 1021, FARM = 1017), while an unspecced
-- `^Get` getter defaults to 0.  So on a frame nobody has hand-written, all
-- three comparisons are `0 == <non-zero sentinel>` -- FALSE, every one, on
-- every frame of the corpus.  `bRelocated` is unreachable and armed 'roamidle'
-- is a no-op that no counter would report.
--
-- ⚠️ THE DIRECTION IS THE OPPOSITE OF §GD's.  cmrguard's catch-all zero held a
-- veto ring OPEN (it PASSED the channel that killed the CM).  This one fails
-- CLOSED: the lever simply never fires, so the reading comes back "tested, no
-- effect" with nothing raising a hand.  Both are silent; only one looks like a
-- result.
--
-- ⭐ THIS IS A FIX THAT WAS NEVER GENERALISED -- the second instance, after
-- §GD.5.  tests/mock/replay_fixture.lua:847-863 diagnoses this EXACT mechanism,
-- names it, and repairs it -- for a SIBLING getter:
--
--     "unspecced, `^Get` defaults to 0, so `GetItemSlotType(slot) ==
--      ITEM_SLOT_TYPE_MAIN` was `0 == 1174`, FALSE on every frame of the
--      corpus.  Every branch behind one was constructively unreachable,
--      failing CLOSED and silently"
--
-- Same sentinel number, same comparison shape, same failure direction.
-- `GetItemSlotType` got its getter; `GetCurrentActionType` did not, and an
-- armed id has been sitting on the unfixed one.  In §GD it was AbilityDamage
-- (guarded) beside AbilityCastRange (not); here it is one loader note away
-- from itself.
--
-- ============================================================================
-- 'campsel' -- THE CAMP HALF IS NOT IN EITHER INSTRUMENT
-- ============================================================================
-- The lever is `rec = camp.cattr` feeding IsEnemyCamp (reads `.team`) and
-- IsAncientCamp (reads `.type`).  Its own green test says, in its header, that
-- "The CAMP half is not in the corpus and is not pretended to be" and that its
-- camp tables are "a DECLARED STAND-IN".  That is an honest test; it is simply
-- not (a).  The replay path is worse: the dumper's creepSnap carries exactly
-- {t, team, x, y} -- no name and no type -- so a camp's `.type` ("ancient")
-- cannot be rebuilt from a .dem either.  Same wall as GH #581.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  Neither id is REJECTED here and neither
-- lever is said to be wrong.  Both retain their logical case (c); the finding
-- is about the INSTRUMENT.  Retiring them from the armed set frees two slots
-- against owner P4.2's `armed <= 20` and costs no behaviour: this file pins
-- `bots/` zero-diff in [3c].

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local F_START = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local function read_file(sPath)
    local f = io.open(sPath)
    assert(f, 'missing file: ' .. sPath)
    local s = f:read('*a')
    f:close()
    return s
end

--- Blank whole-line Lua comments while preserving line numbering, so a count
--- means "in code", not "anywhere in the file". (Same reason as the sibling
--- file: the doc comment above each fix quotes the very lines being counted.)
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

--- Build the same real-frame world the shipped roamidle test builds, but with
--- its S-B stub (`spec.GetCurrentActionType = BOT_ACTION_TYPE_IDLE`) OPTIONAL.
--- `opts.supplyActionType` writes the pivot; omitting it is the blind reading.
local function world(opts)
    opts = opts or {}
    local J, bot = rf.load(F_START)
    for k, v in pairs(DESIRE) do _G[k] = v end

    GetLaneFrontLocation = function() -- luacheck: ignore
        return api.Vector(1234, -4321, 0)
    end

    if opts.supplyActionType then
        local spec = rawget(bot, '__spec')
        spec.GetCurrentActionType = BOT_ACTION_TYPE_IDLE
        rawset(bot, 'GetCurrentActionType', nil)
    end

    return J, bot
end

--- Drive the helper to the frame where it would relocate: call once to seed
--- its per-bot sampling anchor, then again with the clock advanced past its
--- own 3s threshold. Returns the helper's two return values.
local function driveIdle(opts)
    local J, bot = world(opts)
    local t0 = DotaTime()
    J.CheckBotIdleState()
    local real = _G.DotaTime
    _G.DotaTime = function() return t0 + 3.5 end
    local idle, relocated = J.CheckBotIdleState()
    _G.DotaTime = real
    return idle, relocated, bot
end

-- ---------------------------------------------------------------------------
-- §1 roamidle: the pivot is absent, and its absence shuts the arm
-- ---------------------------------------------------------------------------

tests['[1a] the three sentinels are non-zero and mutually distinct'] = function()
    world()
    local idle, item, farm = BOT_ACTION_TYPE_IDLE, BOT_MODE_ITEM, BOT_MODE_FARM
    for name, v in pairs({ BOT_ACTION_TYPE_IDLE = idle, BOT_MODE_ITEM = item,
                           BOT_MODE_FARM = farm }) do
        assert(type(v) == 'number', name .. ' is not a number: ' .. tostring(v))
        assert(v ~= 0, name .. ' resolved to 0 -- the whole reading below '
            .. 'inverts if a sentinel is ever pinned to zero')
    end
    -- The catch-all every unspecced `^Get` returns.
    assert(idle ~= 0 and item ~= 0 and farm ~= 0)
end

tests['[1b] BLIND: on the real frame, unstubbed, the arm never relocates'] = function()
    local idle, relocated, bot = driveIdle()
    -- The bot really is idle by every predicate the frame CAN answer...
    assert(idle == true, 'the helper latches idle on this real frame; got '
        .. tostring(idle))
    -- ...and the recovery arm is still unreachable, because the ONE operand
    -- that selects it is not on the frame.
    assert(bot:GetCurrentActionType() == 0,
        'unspecced `^Get` must answer 0; got ' .. tostring(bot:GetCurrentActionType()))
    assert(not relocated,
        'BLIND-A FAILED: the arm fired without the pivot being supplied. If '
        .. 'this ever goes red the instrument gained the reading and roamidle '
        .. 'can be re-admitted -- re-derive §GE before deleting this file.')
end

tests['[1c] SUPPLIED: the same frame relocates -- the lever works, (a) does not'] = function()
    local _, relocated = driveIdle({ supplyActionType = true })
    assert(relocated == true,
        'with the pivot hand-written the arm fires -- so [1b] measures the '
        .. 'INSTRUMENT, not a dead lever')
end

tests['[1d] the pivot appears in 0 fixtures, and exactly one test writes it'] = function()
    local p = io.popen('ls tests/fixtures/*.lua 2>/dev/null | wc -l')
    local nFix = tonumber(p:read('*a')); p:close()
    assert(nFix and nFix >= 100, 'expected a corpus of >=100 fixtures; got '
        .. tostring(nFix))

    for _, key in ipairs({ 'GetCurrentActionType', 'GetActiveMode' }) do
        local q = io.popen('grep -l ' .. key .. ' tests/fixtures/*.lua 2>/dev/null | wc -l')
        local hits = tonumber(q:read('*a')); q:close()
        assert(hits == 0, key .. ' now appears in ' .. tostring(hits)
            .. ' fixture(s) -- the corpus gained the reading; re-derive §GE')
    end

    -- The only writer in the whole suite is the id's own green test.
    --
    -- ⚠️ COUNTED IN CODE, NOT IN PROSE (director 2026-09-09, §GF).  This was a
    -- bare `grep -l`, and it went red the moment the NEXT blind-A ruling
    -- (§GF, pulllane/pullthink) cross-referenced this one by name in a comment.
    -- Nothing had written the pivot; a file had merely talked about it.  The
    -- assertion's own title says "writes it", so the needle was wider than the
    -- thing it pins -- the same shape as §GF's own M8 and §GD/§GE's M5/M6.
    local r = io.popen('ls tests/*.lua 2>/dev/null')
    local files, n = '', 0
    for path in r:lines() do
        if codeOnly(read_file(path)):find('GetCurrentActionType', 1, true) then
            n = n + 1
            files = files .. path .. '\n'
        end
    end
    r:close()
    assert(n == 2, 'expected exactly two test files WRITING the pivot in code '
        .. '(its own green test and this one); got ' .. n .. ':\n' .. files)
    assert(files:find('test_roamidle_recovery_clobber.lua', 1, true),
        'the id\'s own test must be one of them')
end

tests['[1e] that test DECLARES the write -- it is labelled synthetic S-B'] = function()
    local src = read_file('tests/test_roamidle_recovery_clobber.lua')
    -- ⚠️ Pin the label BOUND TO WHAT IT LABELS, not the bare string 'S-B'.
    -- That bare needle occurs FOUR times in that file (the declaration, the
    -- assignment marker, and two lines in the assertion block), so deleting
    -- the load-bearing declaration left it green -- M5 survived exactly once,
    -- for this reason.  Discipline 2: the assertion was wrong, not the mutant.
    -- Same family as the cmrguard stand's M6 (`GetCastRange = 1000` twice).
    assert(src:find('S-B  `bot:GetCurrentActionType()`', 1, true),
        'the S-B declaration entry (label + the operand it declares) is gone '
        .. 'from the LABELLED SYNTHETIC block')
    assert(src:find('the behavioural dump carries no action', 1, true),
        'the test no longer declares the replay-side wall in its header')
    assert(codeOnly(src):find('spec.GetCurrentActionType = BOT_ACTION_TYPE_IDLE', 1, true),
        'the S-B assignment moved; §GE quotes it verbatim')
end

tests['[1f] the replay path carries no action type either'] = function()
    local src = read_file('tools/batch_test/behavioral/dumper/main.go')
    for _, needle in ipairs({ 'action_type', 'ActionType', 'NumQueuedActions' }) do
        assert(not src:find(needle, 1, true),
            'the dumper now emits ' .. needle .. ' -- the replay path gained '
            .. 'the reading; re-derive §GE')
    end
end

-- ---------------------------------------------------------------------------
-- §2 campsel: the camp record is in neither instrument
-- ---------------------------------------------------------------------------

tests['[2a] no fixture carries a camp record'] = function()
    local p = io.popen('grep -l "cattr" tests/fixtures/*.lua 2>/dev/null | wc -l')
    local hits = tonumber(p:read('*a')); p:close()
    assert(hits == 0, 'the corpus gained camp records (' .. tostring(hits)
        .. ' file(s)) -- campsel may be re-admittable; re-derive §GE')
end

tests['[2b] the dumper creep snapshot is exactly {t, team, x, y}'] = function()
    local src = read_file('tools/batch_test/behavioral/dumper/main.go')
    local body = src:match('type creepSnap struct%s*{(.-)}')
    assert(body, 'creepSnap struct not found -- the dumper was restructured')
    local fields = {}
    for tag in body:gmatch('json:"([%w_]+)"') do fields[#fields + 1] = tag end
    table.sort(fields)
    assert(table.concat(fields, ',') == 't,team,x,y',
        'creepSnap now carries {' .. table.concat(fields, ',') .. '} -- if it '
        .. 'gained a name or a type, the camp half may be reconstructible and '
        .. '§GE must be re-derived')
end

tests['[2c] campsel own test declares the camp half a stand-in'] = function()
    local src = read_file('tests/test_campsel_wrapper_fields.lua')
    assert(src:find('not in the corpus and is not pretended to be', 1, true),
        'the declaration §GE quotes is gone from campsel\'s own test')
    assert(src:find('DECLARED STAND-IN', 1, true),
        'the stand-in label is gone')
end

-- ---------------------------------------------------------------------------
-- §3 what the ruling must NOT have touched
-- ---------------------------------------------------------------------------

tests['[3a] the never-generalised fix: the loader repaired the sibling only'] = function()
    local src = read_file('tests/mock/replay_fixture.lua')
    -- The loader diagnoses the mechanism by name, for GetItemSlotType.
    assert(src:find('was `0 == 1174`', 1, true),
        'the loader note §GE.3 cites is gone -- re-derive the witness')
    assert(src:find('failing CLOSED', 1, true),
        'the loader no longer names the failure direction')
    -- And it still does not serve the getter this ruling is about.
    assert(not codeOnly(src):find('GetCurrentActionType', 1, true),
        'the loader now serves GetCurrentActionType -- the gap §GE.3 is about '
        .. 'was closed; roamidle may be re-admittable and §GE must be re-derived')
end

tests['[3b] pullcad trap: no promote atom and no other gate names either id'] = function()
    local atoms = read_file('iterations/promote_atoms.json')
    for _, id in ipairs({ 'roamidle', 'campsel' }) do
        assert(not atoms:find(id, 1, true),
            'promote_atoms.json now names ' .. id .. ' -- retiring it could '
            .. 'freeze another lever (the pullcad trap); resolve before ruling')
    end
end

tests['[3c] REVERSE: gates, helper and call sites are untouched by the ruling'] = function()
    local mode = codeOnly(read_file('bots/mode_team_roam_generic.lua'))
    local jmz  = codeOnly(read_file('bots/FunLib/jmz_func.lua'))
    local farm = codeOnly(read_file('bots/mode_farm_generic.lua'))
    local site = codeOnly(read_file('bots/FunLib/aba_site.lua'))

    -- roamidle: the gate line and the helper's second return value stay.
    assert(mode:find("J.IsSoakCandidate('roamidle')", 1, true),
        'the roamidle gate was removed -- a retirement from the armed set is '
        .. 'NOT a reject, and must leave bots/ byte-identical')
    assert(jmz:find('return true, bRelocated', 1, true),
        'the helper stopped reporting bRelocated')

    -- campsel: the gate, its single wrapper and the two operands stay.
    assert(farm:find("J.IsSoakCandidate('campsel')", 1, true),
        'the campsel gate was removed')
    assert(site:find('bReadCampRecord and camp.cattr ~= nil', 1, true),
        'the campsel lever body changed')

    -- One gate call site each, so neither retirement can silently take a
    -- second lever with it.
    assert(select(2, mode:gsub("IsSoakCandidate%('roamidle'%)", '')) == 1,
        'roamidle gained a second call site; §GE assumed exactly one')
    assert(select(2, farm:gsub("IsSoakCandidate%('campsel'%)", '')) == 1,
        'campsel gained a second call site; §GE assumed exactly one')
end

return tests
