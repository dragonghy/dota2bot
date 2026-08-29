-- GH #91 RULING, MACHINE-ENFORCED: whether somebody pinged for defence in the
-- last five seconds is a WORLD ASSUMPTION, and a test that drives a bid gated
-- on it must state which way it assumed. Not the loader -- the test.
--
-- WHY NOT A LOADER DEFAULT (the repair the issue asks for). The truth value is
-- not recoverable: the dumper captures no pings, so no frame in any fixture
-- knows whether one happened. A loader default would therefore MODEL a number
-- with no ground truth and move readings in every affected test at once,
-- silently -- which is why path 1 of GH #89 was refused two hours earlier, and
-- what the "no fallback value" clause of the #90 ruling forbids: a default
-- turns this whole defect class into something that can never go red again.
--
-- WHY A NAMED HELPER IS NOT ENOUGH EITHER. `rf.declare_defend_ping` (added in
-- the same change) only helps the tests whose author remembers it exists. The
-- half of the defect that has actually been costing us is the SILENT half: a
-- file drives mode_farm_generic, reads the floor, and publishes it as "what
-- this frame bids". A helper cannot see that file. This registry can, and goes
-- red when a new one joins.
--
-- THE AFFECTED SET IS DERIVED FROM SOURCE, NOT COPIED. Per the #90 ruling: a
-- literal that claims to mirror shipped code must be read from it. So this
-- file greps the shipped tree for the guard shape -- a comparison against
-- `defendPings.pingedTime` followed within three lines by a return of a NONE
-- desire -- and resolves which mode files inherit it through their FunLib
-- requires. Nothing below hardcodes "farm, side_shop, three push modes"; that
-- set is a RESULT, asserted for shape only. aba_defend.lua also reads the
-- stamp and is correctly NOT in the set: its guard returns bare, gating only
-- the "everyone come defend" chat ping, not a bid. If someone puts the guard
-- in front of a fourth bid, the census picks it up and this file starts
-- demanding declarations from the tests that drive it.
--
-- THE REGISTRY IS A WORK QUEUE, NOT A PARDON. Every entry carries the status
-- of its re-read. `retnear` is marked reviewed because the strategy stream
-- re-ran its three bid assertions both ways on 2026-08-21T15:46Z and none
-- moved. The rest are 'unreviewed': their published bid claims were read out
-- of the degenerate world and nobody has checked them since. The ratchet is
-- two-way -- an entry that stops driving a guarded mode, or that starts
-- declaring, fails until it is removed -- so the list cannot rot into a
-- permanent exemption list.
--
-- SCOPE CORRECTION vs the report that opened #91. That report named 11 files
-- as making "bid-level assertions" and asked each author to re-read. The
-- operative criterion is narrower: a file is only affected if it DRIVES a
-- guarded mode. Six do (below). defnum / lanehyst / wave13_fixes assert at
-- helper level and never call GetDesire at all, so the guard cannot reach
-- them; capmono_ceiling / roamreach / roamstale drive only unguarded modes.
-- Naming 11 where 6 are affected costs five unnecessary re-reads and, worse,
-- makes the list look like advice; the census makes it exact.

local rf = dofile('tests/mock/replay_fixture.lua')

local FIXTURE = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local FARM = 'bots/mode_farm_generic.lua'

local DESIRE_NONE_RETURN = { 'BOT_MODE_DESIRE_NONE', 'BotModeDesire.None' }
local LOOKAHEAD = 3

--- Every shipped file whose source contains a defendPings-age comparison that
--- gates a NONE desire. Returns { [path] = line }.
local function guard_sites()
    local out = {}
    local p = io.popen('ls bots/mode_*.lua bots/FunLib/*.lua 2>/dev/null')
    for path in p:lines() do
        local lines = {}
        for line in io.lines(path) do lines[#lines + 1] = line end
        for i, line in ipairs(lines) do
            if line:find('defendPings', 1, true)
                and line:find('pingedTime', 1, true)
                and line:find('<=', 1, true) then
                for j = i, math.min(i + LOOKAHEAD, #lines) do
                    for _, tok in ipairs(DESIRE_NONE_RETURN) do
                        if lines[j]:find('return', 1, true)
                            and lines[j]:find(tok, 1, true) then
                            out[path] = i
                        end
                    end
                end
            end
        end
    end
    p:close()
    return out
end

--- FunLib modules a mode file pulls in (one level, which is all the shipped
--- mode files use).
local function funlib_requires(path)
    local deps = {}
    for line in io.lines(path) do
        local name = line:match("/FunLib/([%w_]+)")
        if name then deps['bots/FunLib/' .. name .. '.lua'] = true end
    end
    return deps
end

--- Mode files whose bid is gated by the stamp, directly or through a require.
local function guarded_modes()
    local sites = guard_sites()
    local out = {}
    local p = io.popen('ls bots/mode_*.lua')
    for path in p:lines() do
        if sites[path] then
            out[path] = 'direct'
        else
            for dep in pairs(funlib_requires(path)) do
                if sites[dep] then out[path] = dep end
            end
        end
    end
    p:close()
    return out
end

local function read(path)
    local fh = io.open(path)
    local src = fh:read('*a')
    fh:close()
    return src
end

local function test_files()
    local out = {}
    local p = io.popen('ls tests')
    for line in p:lines() do
        if line:match('^test_.*%.lua$') then out[#out + 1] = 'tests/' .. line end
    end
    p:close()
    table.sort(out)
    return out
end

--- A test that loads no code cannot drive a bid.
---
--- The `GetDesire` + mode-basename match is a TOKEN match, deliberately wide
--- (see the header: the silent half of the defect is a file nobody remembers).
--- Wide enough that a SOURCE-LEVEL census -- a test that opens bots/*.lua and
--- reads it as text -- trips it on its own data: strategy's gated-helper
--- nesting census carries `GetDesire` and `bots/mode_farm_generic.lua` as
--- CENSUS ROWS and executes nothing at all. Its rows are the anchor, so they
--- cannot be renamed away, and neither escape hatch fits honestly: the LEGACY
--- registry means "drove a bid before this ruling", and `declares()` would be
--- satisfied by writing the token `defendPings` into a comment -- a comment
--- impersonating a call site, which is the exact failure GH #300 paid for.
---
--- So the narrowing is by MECHANISM, not by pattern: a file that never
--- `require`s, `dofile`s, `loadfile`s or `loadstring`s cannot reach a mode's
--- GetDesire, whatever tokens its text contains. MEASURED before landing, on
--- 2026-08-29, because the obvious narrowing is a trap: requiring `GetDesire(`
--- in CALL FORM instead would have dropped 4 of the 6 LEGACY entries, i.e.
--- loosened the ratchet while looking like a tightening. This one spares
--- exactly the census-shaped files and NONE of the registry -- asserted below
--- rather than left as prose.
local LOADERS = { 'require%s*[%(\'"]', 'dofile%s*%(', 'loadfile%s*%(',
                  'loadstring%s*%(' }
local function loads_code(src)
    for _, p in ipairs(LOADERS) do
        if src:find(p) then return true end
    end
    return false
end

--- A test drives a guarded mode if it loads code at all, calls GetDesire, and
--- either names one of the guarded mode files or enumerates the whole mode set
--- with a glob.
local function drives_guarded_mode(src, modes)
    if not loads_code(src) then return false end
    if not src:find('GetDesire', 1, true) then return false end
    if src:find('ls bots/mode_%*') then return true end
    for path in pairs(modes) do
        local base = path:match('([^/]+)%.lua$')
        if src:find(base, 1, true) then return true end
    end
    return false
end

--- A test has declared the assumption if it says so in its own source --
--- either through the loader helper or by writing the stamp itself. Both are
--- visible at the call site, which is the whole point; the helper is merely
--- the tidier of the two.
local function declares(src)
    return src:find('declare_defend_ping', 1, true) ~= nil
        or src:find('defendPings', 1, true) ~= nil
end

-- Files that drove a guarded mode before this ruling existed. `reviewed` means
-- somebody has since re-run its bid assertions with the assumption declared
-- both ways and confirmed the published numbers. Anything else is a claim read
-- out of the degenerate world, still standing only because nobody has checked.
local LEGACY = {
    ['tests/test_retnear_radius_parity.lua'] =
        'reviewed 2026-08-21T15:46Z: all three bid assertions unchanged both ways',
    ['tests/test_defclose_defender_arbitration.lua'] = 'unreviewed',
    ['tests/test_defstale_defend_bail.lua'] = 'unreviewed',
    ['tests/test_towerreach_out_of_range_veto.lua'] = 'unreviewed',
    ['tests/test_tpwatch_channel_bid.lua'] = 'unreviewed',
    ['tests/test_replay_260820_181711_wk_l1trade.lua'] = 'unreviewed',
}

return {

    ['[census] the guard sits in front of a bid in exactly the shipped shape'] = function()
        local sites = guard_sites()
        local n = 0
        for _ in pairs(sites) do n = n + 1 end
        assert(n >= 3, 'expected at least three bid-gating defendPings sites; found ' .. n)
        -- Shape, not identity: these three are the ones the #91 measurement was
        -- taken on, so if any of them stops gating a bid the measured numbers
        -- (94/94 farm floor, 32 suppressed push bids) no longer describe the tree.
        for _, expect in ipairs({
            'bots/mode_farm_generic.lua',
            'bots/mode_side_shop_generic.lua',
            'bots/FunLib/aba_push.lua',
        }) do
            assert(sites[expect], expect .. ' no longer gates a NONE desire on the '
                .. 'defendPings stamp -- the #91 measurements were taken with it there')
        end
    end,

    ['[census] aba_defend reads the same stamp but gates no bid'] = function()
        local sites = guard_sites()
        assert(sites['bots/FunLib/aba_defend.lua'] == nil,
            'aba_defend now gates a desire on the stamp; it used to gate only the '
            .. '"come defend" chat ping. Every defend-mode bid reading in the tree '
            .. 'was taken before that and has to be re-read.')
        assert(read('bots/FunLib/aba_defend.lua'):find('defendPings', 1, true),
            'aba_defend no longer touches defendPings at all -- it is the WRITER '
            .. 'of the shared stamp, so this census lost its only writer')
    end,

    ['[census] the push modes inherit the guard through aba_push'] = function()
        local modes = guarded_modes()
        for _, lane in ipairs({ 'top', 'mid', 'bot' }) do
            local path = 'bots/mode_push_tower_' .. lane .. '_generic.lua'
            assert(modes[path] == 'bots/FunLib/aba_push.lua',
                path .. ' no longer inherits the stamp guard from aba_push; got '
                .. tostring(modes[path]))
        end
        assert(modes['bots/mode_farm_generic.lua'] == 'direct',
            'mode_farm_generic should carry the guard in its own source')
    end,

    ['[ratchet] the loads-no-code narrowing pardons nobody in the registry'] = function()
        -- The narrowing above is the only way a file leaves this ratchet
        -- without declaring, so it is the only place it can rot into a pardon.
        -- Every registry entry must still be seen as driving; a registry entry
        -- that goes quiet because someone widened LOADERS would take its
        -- unreviewed bid claims with it, silently.
        for path in pairs(LEGACY) do
            local src = read(path)
            assert(loads_code(src), path .. ' is in the registry but now reads '
                .. 'as loading no code, so the narrowing has swallowed it; the '
                .. 'registry is a work queue, not a pardon')
        end
        -- and the narrowing must still bite something, or it is not a narrowing
        assert(not loads_code('local x = 1\nreturn x\n'), 'loads_code says a '
            .. 'file with no loader call loads code; the exemption is dead')
        assert(loads_code("local api = require('mock.bot_api')"), 'loads_code '
            .. 'no longer recognises require; every test would be exempt')
    end,

    ['[ratchet] every test driving a guarded mode declares the assumption'] = function()
        local modes = guarded_modes()
        local offenders = {}
        for _, path in ipairs(test_files()) do
            local src = read(path)
            if drives_guarded_mode(src, modes) and not declares(src) and not LEGACY[path] then
                offenders[#offenders + 1] = path
            end
        end
        assert(#offenders == 0,
            'these tests drive a bid gated on the defence-ping stamp without saying '
            .. 'which way they assumed it (GH #91). Add one visible line -- '
            .. "rf.declare_defend_ping(J, 'stale') for the ordinary case -- or, if the "
            .. 'reading really is meant to come out of a just-pinged world, declare '
            .. "'fresh' and say why: " .. table.concat(offenders, ', '))
    end,

    ['[ratchet] the legacy list cannot rot into a permanent exemption'] = function()
        local modes = guarded_modes()
        for path, status in pairs(LEGACY) do
            local fh = io.open(path)
            assert(fh, 'LEGACY names ' .. path .. ', which no longer exists -- drop the entry')
            fh:close()
            local src = read(path)
            assert(drives_guarded_mode(src, modes),
                path .. ' no longer drives a guarded mode; remove it from LEGACY '
                .. 'instead of carrying a dead exemption')
            assert(not declares(src),
                path .. ' now declares the assumption -- delete its LEGACY entry so '
                .. 'the list keeps meaning "not yet re-read"')
            assert(status == 'unreviewed' or status:find('^reviewed '),
                path .. ": LEGACY status must be 'unreviewed' or start with "
                .. "'reviewed <when>: <what was re-run>'; got " .. tostring(status))
        end
    end,

    ["[helper] 'stale' clears the widest window shipped, read from source"] = function()
        -- The window is NOT copied here. Every shipped comparison against the
        -- stamp is scraped and the widest one taken, so a patch that widens a
        -- guard to 30s makes this fail instead of leaving the helper quietly
        -- declaring a world that is still inside somebody's window.
        local widest = 0
        local p = io.popen('ls bots/mode_*.lua bots/FunLib/*.lua 2>/dev/null')
        for path in p:lines() do
            for line in io.lines(path) do
                if line:find('defendPings', 1, true) and line:find('pingedTime', 1, true)
                    and line:find('<=', 1, true) then
                    -- Grab the whole token and insist it parses. A digits-only
                    -- pattern reads `<= 2e6` as 2 and silently under-reports the
                    -- window -- caught by mutation M8, which stayed green until
                    -- an unparseable literal became an error instead of a skip.
                    local tok = line:match('<=%s*([^%s]+)')
                    local n = tok and tonumber(tok)
                    assert(n, path .. ': cannot read the defence-ping window from '
                        .. tostring(tok) .. ' -- widen the scrape rather than '
                        .. 'letting an unreadable guard drop out of the maximum')
                    if n > widest then widest = n end
                end
            end
        end
        p:close()
        assert(widest > 0, 'no shipped defendPings window found to compare against')
        local J = rf.load(FIXTURE)
        local stamped = rf.declare_defend_ping(J, 'stale')
        assert(GameTime() - stamped > widest,
            "declare_defend_ping('stale') left the stamp inside a shipped window of "
            .. widest .. 's')
        assert(J.Utils['GameStates']['defendPings'].pingedTime == stamped,
            'the helper returned a value it did not write')
    end,

    ["[helper] 'fresh' puts the frame inside every window, and a typo raises"] = function()
        local J = rf.load(FIXTURE)
        assert(GameTime() - rf.declare_defend_ping(J, 'fresh') == 0,
            "declare_defend_ping('fresh') must place the ping on this very frame")
        -- No default: the whole point of the ruling is that an undeclared world
        -- cannot be reached by accident, least of all through a fallback value.
        for _, bad in ipairs({ 'STALE', 'true', '' }) do
            assert(not pcall(rf.declare_defend_ping, J, bad),
                'declare_defend_ping accepted ' .. string.format('%q', bad)
                .. ' instead of raising')
        end
        assert(not pcall(rf.declare_defend_ping, J),
            'declare_defend_ping accepted a missing state -- it must have no default')
    end,

    ['[queue] the re-read backlog is stated, not implied'] = function()
        local pending = {}
        for path, status in pairs(LEGACY) do
            if status == 'unreviewed' then pending[#pending + 1] = path end
        end
        table.sort(pending)
        -- Five files still publish bid numbers read out of the degenerate world.
        -- This asserts the count so that clearing one is a deliberate edit here,
        -- and so the backlog cannot quietly grow.
        assert(#pending == 5,
            'the defence-ping re-read backlog changed size (' .. #pending .. '): '
            .. table.concat(pending, ', ')
            .. ' -- update the count when you clear or add one')
    end,
}
