-- [ratchet] A column-0 `function Foo()` in this repo is NOT necessarily a
-- global. `game/botsinit.lua:15` calls `setfenv(2, newenv)` on its CALLER's
-- chunk, and that env's `__newindex` is the module table `M` -- so in every
-- file that calls `BotsInit.CreateGeneric()`, a definition written exactly like
-- a global lands in that module's own table and is invisible to `_G`.
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     A NAMESPACE IS A RUNTIME FACT, NOT A SYNTACTIC ONE. `^function Name(`
--     tells you the SHAPE of a definition, never the TABLE it writes to, when
--     any file in the tree can rebind its own environment. Any audit that reads
--     column-0 definitions as writes to one shared namespace is measuring a
--     namespace the program does not have -- and it fails in the CONFIDENT
--     direction: it manufactures collisions between files that can never see
--     each other's names, complete with file:line evidence for both halves.
--
-- Distinguish from the three same-family findings this group filed before it:
--   GH #348 ordering (a nil guard below the index it guards)
--   GH #368 scope    (a `local` shadow whose extent ends above its consumer)
--   GH #370 an unreported side effect a caller cannot sequence
--   GH #373 a latch recording the attempt instead of the postcondition
-- All four are defects in shipped Lua. THIS one is not a defect in the bots at
-- all: it is a defect in how the tree is READ. The shipped code is correct and
-- the audit that indicts it is wrong. That is why it needs a ratchet -- nothing
-- in the tree fails when someone re-derives the false conclusion.
--
-- WHAT IT REFUTED, concretely, this round. A plain grep over `bots/` reports
-- three global function names defined in BOTH
--   bots/mode_laning_generic.lua                        (base)
--   bots/FunLib/override_generic/mode_laning_generic.lua (override)
-- namely GetBestLastHitCreep / GetBestDenyCreep / GetFurthestEnemyAttackRange.
-- The base `dofile`s the override at :30 and then defines its own copies at
-- :251/:265/:287 -- i.e. AFTER. Read as one namespace, that is a textbook
-- clobber: the override's `Think` would call the base's helpers, whose contract
-- differs (2 return values, not 1). Every step of that reasoning is checkable
-- and every step is true except the premise. §2 below executes the real load
-- order and shows the two sets never touch.
--
-- The shipped code says so itself, in the other direction: base :143 reaches
-- the override's member as `local_mode_laning_generic.GetBotTargetLane()` --
-- through the module table, because that is the only place it exists.
--
-- ⚠️ LIMITS, declared:
--   * §4's partition is a static scan of `bots/`. It answers "which files
--     rebind their env", not "which names actually coexist in one VM at
--     runtime" -- the engine's per-script environment is NOT observable from
--     this repo, so this file asserts nothing about whether two mode files
--     share `_G`. Every conclusion here is about the `setfenv` this repo
--     performs itself, in source, and executes below.
--   * §5 measures the fixture corpus, not the game: it establishes that the
--     override file cannot be driven on a real frame TODAY, not that it is
--     rare in play.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local tests = {}

local F = 'tests/fixtures/f_080225_wk_lane.lua'
local OVERRIDE = 'bots/FunLib/override_generic/mode_laning_generic.lua'
local BASE     = 'bots/mode_laning_generic.lua'

local function slurp(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Blank every whole-line Lua comment while PRESERVING line numbering, so a
--- count or a line lookup means "in code", not "anywhere in the file". The
--- header above quotes the very lines this file pins; without this, the scan
--- counts its own explanation (the GH #341/#345/#370 blind spot).
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

--- Does this chunk rebind its own environment?
---
--- Keyed on the CALL, never on the receiver's name. A first draft matched the
--- literal string `BotsInit.CreateGeneric`, and mutant M8 -- a file that
--- rebinds through a differently-named local -- walked straight past it and was
--- filed as "plain". A detector for a namespace mistake that itself keys on a
--- naming convention reproduces the mistake it is warning about.
local function rebindsEnv(code)
    return code:find('[%w_]+%s*%.%s*CreateGeneric%s*%(') ~= nil
        or code:find('[%w_]+%s*%.%s*CreateTeam%s*%(') ~= nil
        or code:find('setfenv%s*%(') ~= nil
end

local function lineOf(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return nil end
    local _, n = src:sub(1, at):gsub('\n', '')
    return n + 1
end

--- Column-0 `function Name(` definitions, by name -> list of line numbers.
local function colZeroDefs(code)
    local out, n = {}, 0
    for line in (code .. '\n'):gmatch('([^\n]*)\n') do
        n = n + 1
        local name = line:match('^function ([A-Za-z_][A-Za-z0-9_]*)%s*%(')
        if name then
            out[name] = out[name] or {}
            out[name][#out[name] + 1] = n
        end
    end
    return out
end

--- Widest `return` in one column-0 function body, counted in VALUES.
---
--- The body is sliced from its own `function` line to the NEXT column-0
--- `function` (or EOF), never with a non-greedy `.-\nend`: that pattern stops
--- at the first NESTED `end` and hands back a truncated body that still
--- matches a plausible expectation (the self-inflicted wound of GH #373).
local function maxReturnArity(code, name)
    local lines = {}
    for line in (code .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = line end
    local from
    for i, line in ipairs(lines) do
        if line:match('^function ' .. name .. '%s*%(') then from = i break end
    end
    if from == nil then return nil end
    local to = #lines
    for i = from + 1, #lines do
        if lines[i]:match('^function ') then to = i - 1 break end
    end
    local best = 0
    for i = from, to do
        local expr = lines[i]:match('^%s*return%s+(.*)$')
        if expr then
            expr = expr:gsub('%b()', ''):gsub('%b{}', '')      -- ignore inner commas
            local n = 1
            for _ in expr:gmatch(',') do n = n + 1 end
            if n > best then best = n end
        end
    end
    return best
end

local CODE_BASE     = codeOnly(slurp(BASE))
local CODE_OVERRIDE = codeOnly(slurp(OVERRIDE))
local CODE_BOTSINIT = codeOnly(slurp('game/botsinit.lua'))

local THREE = { 'GetBestLastHitCreep', 'GetBestDenyCreep', 'GetFurthestEnemyAttackRange' }

-- ---------------------------------------------------------------------------
-- §1  The mechanism, in the real source of game/botsinit.lua.
-- ---------------------------------------------------------------------------

function tests.botsinit_rebinds_the_callers_environment()
    assert(CODE_BOTSINIT:find('setfenv(2, newenv)', 1, true),
        'botsinit no longer rebinds its caller env -- this whole file is about that line')
    assert(CODE_BOTSINIT:find('__newindex = M', 1, true),
        'botsinit no longer routes writes into the module table')
    -- The read side falls back to _G, which is why these files can still call
    -- engine globals. Both halves matter: writes are captured, reads are not.
    assert(CODE_BOTSINIT:find('return globaltbl[k]', 1, true),
        'botsinit no longer falls back to _G on reads')
end

--- Executable demo of the semantics the rest of this file leans on, so the
--- claim is never carried by prose alone.
function tests.setfenv_capture_is_demonstrated_not_asserted()
    local BotsInit = dofile('game/botsinit.lua')
    local sentinel = '__botsinit_env_probe__'
    _G[sentinel] = nil
    local chunk = loadstring or load
    local f = assert(chunk(
        'local BotsInit = ...\n' ..
        'local M = BotsInit.CreateGeneric()\n' ..
        'function ' .. sentinel .. '() return 1 end\n' ..
        'return M\n'))
    local M = f(BotsInit)
    assert(type(M[sentinel]) == 'function',
        'a column-0 definition did NOT land in the module table')
    assert(rawget(_G, sentinel) == nil,
        'a column-0 definition leaked into _G despite CreateGeneric')
end

-- ---------------------------------------------------------------------------
-- §2  The real shipped load order, executed. This is the refutation.
-- ---------------------------------------------------------------------------

--- Load the override, then the base, exactly as `bots/mode_laning_generic.lua`
--- does (dofile at :30, own definitions afterwards), on a real frame.
local function loadRealOrder()
    for _, name in ipairs(THREE) do rawset(_G, name, nil) end
    local J, bot = rf.load(F)
    local X = dofile(OVERRIDE)
    local afterOverride = {}
    for _, name in ipairs(THREE) do afterOverride[name] = rawget(_G, name) end
    dofile(BASE)
    local afterBase = {}
    for _, name in ipairs(THREE) do afterBase[name] = rawget(_G, name) end
    return X, afterOverride, afterBase, J, bot
end

function tests.the_grep_premise_is_real_both_files_define_all_three()
    local dBase, dOver = colZeroDefs(CODE_BASE), colZeroDefs(CODE_OVERRIDE)
    for _, name in ipairs(THREE) do
        assert(dBase[name], BASE .. ' no longer defines ' .. name .. ' at column 0')
        assert(dOver[name], OVERRIDE .. ' no longer defines ' .. name .. ' at column 0')
    end
    -- ...and the base's copies really do come AFTER the dofile, which is the
    -- half that makes the false conclusion look airtight.
    local dofileLine = lineOf(CODE_BASE, 'override_generic/mode_laning_generic')
    assert(dofileLine, BASE .. ' no longer dofiles the override')
    for _, name in ipairs(THREE) do
        assert(dBase[name][1] > dofileLine,
            name .. ' is now defined ABOVE the dofile; the premise of this ratchet changed')
    end
end

function tests.override_definitions_never_reach_G()
    local _, afterOverride = loadRealOrder()
    for _, name in ipairs(THREE) do
        assert(afterOverride[name] == nil,
            name .. ' leaked into _G from the override -- CreateGeneric no longer protects it')
    end
end

function tests.base_and_override_helpers_are_distinct_objects()
    local X, _, afterBase = loadRealOrder()
    for _, name in ipairs(THREE) do
        assert(type(X[name]) == 'function', OVERRIDE .. ' lost its own ' .. name)
        assert(type(afterBase[name]) == 'function', BASE .. ' lost its ' .. name)
        assert(X[name] ~= afterBase[name],
            name .. ': the two files now share ONE function object -- the clobber this ' ..
            'file refutes would be real again')
    end
end

--- The contract difference the false conclusion predicted would leak across:
--- the base returns (creep, bApproachOnly); the override returns one value.
--- Both survive, each in its own namespace, so nothing leaks.
function tests.the_two_contracts_coexist_untouched()
    local X, _, afterBase = loadRealOrder()

    -- Read the contract off the BODIES, not off one call. An earlier draft
    -- asserted `select('#', helper({}))` and mutant M9 -- the override adopting
    -- the base's two-value return -- SURVIVED it: an empty list reaches only
    -- the shared `return nil` fall-through, so both arms answer 1 whatever the
    -- creep-found branch returns. The assertion agreed for a reason unrelated
    -- to the claim.
    local maxOver = maxReturnArity(CODE_OVERRIDE, 'GetBestLastHitCreep')
    local maxBase = maxReturnArity(CODE_BASE, 'GetBestLastHitCreep')
    assert(maxOver == 1,
        'override GetBestLastHitCreep now returns up to ' .. tostring(maxOver) ..
        ' values; its call site at :109 reads one')
    assert(maxBase == 2,
        'base GetBestLastHitCreep now returns up to ' .. tostring(maxBase) ..
        ' values; both its call sites (:227, :477) read two')

    -- ...and the base's own call sites really do read the second value. Mutant
    -- M12 (dropping it at :477) SURVIVED the first draft, because "both its
    -- call sites read two" lived only in the sentence above's error string. A
    -- claim that appears only in a failure message is not asserted by anything.
    local sites = 0
    for line in (CODE_BASE .. '\n'):gmatch('([^\n]*)\n') do
        local lhs = line:match('^%s*local%s+(.-)%s*=%s*GetBestLastHitCreep%s*%(')
        if lhs then
            sites = sites + 1
            assert(lhs:find(',', 1, true),
                'a base call site now drops the second return value: ' .. line)
        end
    end
    assert(sites == 2, 'expected 2 base call sites of GetBestLastHitCreep, found ' .. sites)

    -- The fall-through path agrees for both, which is exactly why it could not
    -- carry the claim above. Kept, labelled as the weaker reading it is.
    assert(select('#', X.GetBestLastHitCreep({})) == 1)
    assert(select('#', afterBase.GetBestLastHitCreep({})) == 1)
    -- The override's Think reaches its OWN helper, via the env's __index (M
    -- first, _G only as fallback). Proven by substitution: swap the module's
    -- member and the module's own code must follow it, while _G's copy does not.
    local marker = {}
    local saved = X.GetBestLastHitCreep
    X.GetBestLastHitCreep = function() return marker end
    assert(X.GetBestLastHitCreep() == marker, 'module member is not writable')
    assert(rawget(_G, 'GetBestLastHitCreep') ~= X.GetBestLastHitCreep,
        'writing the module member also wrote _G -- the namespaces are not separate')
    X.GetBestLastHitCreep = saved
end

--- The shipped tree states the same fact in the opposite direction: the base
--- reaches an override member through the module table, never by bare name.
function tests.base_reaches_override_members_through_the_module_table()
    assert(CODE_BASE:find('local_mode_laning_generic.GetBotTargetLane()', 1, true),
        'base no longer reaches the override member through its module table')
    -- and it never calls it bare, which would be the _G read that does not exist
    local bare = 0
    for line in (CODE_BASE .. '\n'):gmatch('([^\n]*)\n') do
        if line:find('GetBotTargetLane', 1, true)
            and not line:find('local_mode_laning_generic.', 1, true) then
            bare = bare + 1
        end
    end
    assert(bare == 0, 'base now calls GetBotTargetLane by bare name ' .. bare .. ' time(s)')
end

-- ---------------------------------------------------------------------------
-- §4  How wide the mislabelling is: the static partition of `bots/`.
-- ---------------------------------------------------------------------------

local function listLua(dir, acc)
    acc = acc or {}
    local pipe = io.popen('find ' .. dir .. " -name '*.lua' -type f 2>/dev/null")
    for line in pipe:lines() do acc[#acc + 1] = line end
    pipe:close()
    return acc
end

--- The blast radius, measured rather than assumed. Only TWO files under `bots/`
--- rebind their environment at all, and both are the `override_generic` pair --
--- i.e. the entire population where a column-0 definition is not a global is
--- exactly the population a naive audit pairs against a same-named base file.
--- That concentration is the reason this ratchet exists: the mislabelling is
--- narrow, and it is aimed straight at the one pair that produces a plausible
--- false collision.
function tests.exactly_two_files_in_bots_rebind_their_env()
    local protected, plain = {}, 0
    for _, path in ipairs(listLua('bots')) do
        local code = codeOnly(slurp(path))
        if next(colZeroDefs(code)) ~= nil then
            if rebindsEnv(code) then
                protected[#protected + 1] = path
            else
                plain = plain + 1
            end
        end
    end
    table.sort(protected)
    -- Both sides must be non-empty or the criterion is vacuous: if nothing were
    -- protected there would be no mislabelling to warn about, and if nothing
    -- were plain the naive audit would be right by accident.
    assert(#protected > 0, 'no file in bots/ rebinds its env any more; criterion is vacuous')
    assert(plain > 0, 'every file in bots/ rebinds its env; criterion is vacuous')
    -- Measured 2026-09-01: 2 protected, 59 plain. Pinned by NAME, not by count,
    -- so a new env-rebinding file fails here loudly instead of drifting a number.
    assert(#protected == 2,
        'the env-rebinding set is now ' .. #protected .. ' file(s): ' ..
        table.concat(protected, ', ') .. ' -- re-derive the blast radius')
    assert(protected[1] == 'bots/FunLib/override_generic/mode_attack_generic.lua'
        and protected[2] == OVERRIDE,
        'the env-rebinding set changed membership: ' .. table.concat(protected, ', '))
end

--- The sibling override pair cannot even produce the false conclusion: its one
--- column-0 name is defined nowhere else. Pinning this says the laning pair is
--- the ONLY site where the mislabelling has a plausible-looking target, which
--- is what makes a single ratchet enough coverage.
function tests.the_attack_override_pair_has_no_name_overlap()
    local over = colZeroDefs(codeOnly(slurp('bots/FunLib/override_generic/mode_attack_generic.lua')))
    local base = colZeroDefs(codeOnly(slurp('bots/mode_attack_generic.lua')))
    assert(next(over) ~= nil, 'the attack override lost its column-0 definitions')
    for name in pairs(over) do
        assert(base[name] == nil,
            'mode_attack_generic now shares the column-0 name ' .. name ..
            ' with its override -- a second site for this false conclusion')
    end
end

-- ---------------------------------------------------------------------------
-- §5  Corpus boundary: this override file is not locally validatable today.
-- ---------------------------------------------------------------------------

--- The override laning file loads only for Utils.BuggyHeroesDueToValveTooLazy.
--- Not one of those heroes appears anywhere in the fixture corpus, so no real
--- frame in this repo can drive a single line of it. This assertion is written
--- to FAIL the day such a fixture lands -- that failure is the signal to come
--- back and validate the file for real.
function tests.no_fixture_can_drive_the_override_laning_file()
    local UTILS = codeOnly(slurp('bots/FunLib/utils.lua'))
    local at = UTILS:find('BuggyHeroesDueToValveTooLazy = {', 1, true)
    assert(at, 'the buggy-hero table moved; re-derive this boundary before quoting it')
    local block = UTILS:sub(at, (UTILS:find('}', at, true) or at))
    local heroes = {}
    for name in block:gmatch('HeroName%.([A-Za-z]+)') do
        heroes[#heroes + 1] = name:lower()
    end
    assert(#heroes >= 5, 'buggy-hero list collapsed to ' .. #heroes .. ' entries')

    -- Name forms differ between HeroName.* and npc_dota_hero_*; compare on the
    -- letters only, so IO/wisp-style renames cannot silently pass as absent.
    local corpus = {}
    for _, path in ipairs(listLua('tests/fixtures')) do
        for n in slurp(path):gmatch('npc_dota_hero_([a-z_]+)') do
            corpus[(n:gsub('_', ''))] = true
        end
    end
    assert(next(corpus) ~= nil, 'the fixture corpus scan found no heroes at all')

    local found = {}
    for _, h in ipairs(heroes) do
        if corpus[h] then found[#found + 1] = h end
    end
    assert(#found == 0,
        'a buggy hero is now in the corpus (' .. table.concat(found, ',') ..
        ') -- ' .. OVERRIDE .. ' can finally be driven on a real frame; go do it')
end

-- ---------------------------------------------------------------------------
-- REVERSE assertions: fail loudly if the subject of this file stops existing,
-- so a green run can never mean "the thing was not there to check".
-- ---------------------------------------------------------------------------

tests['REVERSE: the override laning file is still reachable from the base'] = function()
    assert(CODE_BASE:find('Utils.BuggyHeroesDueToValveTooLazy[botName]', 1, true),
        'the base no longer gates the override on the buggy-hero table')
    assert(lineOf(CODE_BASE, 'override_generic/mode_laning_generic'),
        'the base no longer loads the override at all -- this file is moot')
end

tests['REVERSE: botsinit is still the only env-rebinding mechanism here'] = function()
    local mechanisms = 0
    for _, path in ipairs(listLua('bots')) do
        if rebindsEnv(codeOnly(slurp(path))) then mechanisms = mechanisms + 1 end
    end
    assert(mechanisms == 2,
        'the env-rebinding population is now ' .. mechanisms ..
        ' file(s); the blast radius pinned in this file must be re-derived')
end

return tests
