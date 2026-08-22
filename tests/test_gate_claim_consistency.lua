-- Gate-claim consistency ratchet: a comment that says "gated" must be talking
-- about a gate that actually exists.
--
-- This project's whole method rests on one sentence in CLAUDE.md: "A gated fix
-- on the branch is NOT live -- don't call it shipped until it's ungated." The
-- comments ARE the register of which side of that line each behavior sits on;
-- nothing else reads at the call site. Both directions of drift cost real work:
--
--   * UNDER-claim (comment says gated/inert, code ships default-on). Found 14
--     times on 2026-08-22, oldest since 2026-07-23: `tpsafe2` and `pushguard`
--     were promoted by owner directive and `nodive` / `punish` / `regroup` /
--     `deathzone` / `vsafe` / `tpsafe` under the Class-B policy, but their
--     CALL-SITE comments still said "inert by default". A reader there
--     concludes shipped behavior is dark, and either re-arms an id that is
--     already live or attributes what it sees to something else.
--   * OVER-claim (comment names an id nothing is wired to). Found once:
--     `jmz_func.lua`'s anti-suicide-chase block said "gated behind the
--     'nochaselow' soak candidate" -- an id that has never existed anywhere in
--     the tree; the real gate is `lanefix` / `lf_chase`. Arming `nochaselow`
--     as instructed arms NOTHING, and the wave reads as "tested, neutral" --
--     the exact failure that made `creeppull` / `pullcamp` read SILENT in
--     10/10 games and cost a batch verdict its meaning.
--
-- SOURCE-LEVEL on purpose, same reasoning as test_retreat_priority_order.lua:
-- a fixture can only prove the one claim it happens to execute, while the
-- invariant has to hold for every claim, including ones written next month.
--
-- The wired set is READ FROM SOURCE, never hand-maintained -- a hand list
-- would itself become the next stale register.

local BOTS_ROOT = 'bots'

local function list_lua_files()
    local files = {}
    local p = assert(io.popen('find ' .. BOTS_ROOT .. ' -name "*.lua" | sort'))
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    return files
end

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local text = fh:read('*a')
    fh:close()
    return text
end

--- Gate ids this source actually wires, by the three forms the tree uses.
-- Returns a set. Exposed (not inlined) so the synthetic controls below run
-- through the SAME extractor the census does -- a control that exercises a
-- different code path proves nothing about the census.
local function wired_ids_in(src, into)
    local set = into or {}
    for id in src:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do set[id] = true end
    for id in src:gmatch('IsSoakCandidate%s*%(%s*"([%w_]+)"') do set[id] = true end
    -- J.IsLaneFixOn(sub) arms the bundle id or the per-fix id 'lf_<sub>'.
    for sub in src:gmatch("IsLaneFixOn%s*%(%s*'([%w_]+)'") do
        set['lf_' .. sub] = true
        set['lanefix'] = true
    end
    -- The reader compares conf.cand to literals directly for the wildcard id.
    for id in src:gmatch("cand%s*==%s*'([%w_]+)'") do set[id] = true end
    return set
end

--- Every comment line that CLAIMS a gate, with the ids it names.
-- Trigger vocabulary is "gated" or "soak candidate"/"soak-candidate". Bare
-- "inert" is deliberately NOT a trigger: it appears on lines describing a
-- non-gate fallthrough (mode_attack_generic's 'flee' case), and widening the
-- trigger to catch those would flag quoted words that were never gate ids.
local function claims_in(src, path)
    local found = {}
    local line_no = 0
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        line_no = line_no + 1
        local st = line:match('^%s*(.-)%s*$')
        if st:sub(1, 2) == '--' then
            local low = st:lower()
            if low:find('gated', 1, true) or low:find('soak[%- ]candidate') then
                -- A line that says PROMOTED is the register saying the gate is
                -- gone on purpose; that is the documented exit, not drift.
                local promoted = st:find('PROMOTED', 1, true) ~= nil
                local function add(id)
                    found[#found + 1] = {
                        path = path, line = line_no, id = id,
                        promoted = promoted, text = st,
                    }
                end
                for id in st:gmatch("'([%l%d_]+)'") do add(id) end
                -- The tree writes gate ids two ways: quoted ('pushguard') and
                -- bracket-tagged ([liondrain]). Both are checked. The bracket
                -- pattern requires the WHOLE bracket to be one lowercase id, so
                -- the other bracket tags in these comments ([GH #4], [LAB C3],
                -- [replay-review 071423], [pushguard freehunt#2]) do not match.
                for id in st:gmatch('%[([%l][%l%d_]+)%]') do add(id) end
            end
        end
    end
    return found
end

local function census()
    local wired, claims = {}, {}
    for _, path in ipairs(list_lua_files()) do
        local src = read_file(path)
        wired_ids_in(src, wired)
        for _, c in ipairs(claims_in(src, path)) do claims[#claims + 1] = c end
    end
    return wired, claims
end

local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

local tests = {}

-- THE invariant.
tests['every gate id named in a "gated" comment is actually wired'] = function()
    local wired, claims = census()
    local bad = {}
    for _, c in ipairs(claims) do
        if not c.promoted and not wired[c.id] then
            bad[#bad + 1] = string.format(
                "%s:%d names gate '%s', which nothing in bots/ wires\n      %s",
                c.path, c.line, c.id, c.text)
        end
    end
    assert(#bad == 0, string.format(
        '%d comment(s) claim a gate that does not exist. Either wire the id, '
        .. 'correct it to the real one, or -- if the behavior was promoted -- '
        .. 'say PROMOTED on that line:\n   %s',
        #bad, table.concat(bad, '\n   ')))
end

-- Guards against the census going quiet. "Zero violations" and "the extractor
-- matched nothing" are indistinguishable in the assertion above, and that is
-- how a ratchet dies without anyone noticing (the M13 / M7 / M9 recurrence).
tests['the wired-id census still finds the tree'] = function()
    local wired = census()
    assert(count(wired) >= 60, 'wired-id census collapsed to ' .. count(wired)
        .. ' ids; the IsSoakCandidate extractor has stopped matching')
    for _, id in ipairs({ 'lanefix', 'lf_chase', 'capmono', 'tpdying', 'all' }) do
        assert(wired[id], "wired-id census lost '" .. id
            .. "', which is wired in bots/ -- extractor regression, not a fix")
    end
end

tests['the claim census still finds the tree'] = function()
    local _, claims = census()
    assert(#claims >= 40, 'claim census collapsed to ' .. #claims
        .. ' claims; the comment extractor has stopped matching')
    local seen = {}
    for _, c in ipairs(claims) do seen[c.id] = true end
    -- Anchors that stay GATED after the 2026-08-22 sweep, so this guard keeps
    -- its meaning: 'liondrain' is bracket-form, the rest quoted.
    for _, id in ipairs({ 'liondrain', 'capmono', 'lanefix', 'midtp' }) do
        assert(seen[id], "claim census lost '" .. id
            .. "' -- extractor regression, not a fix")
    end
end

-- Positive controls: prove the census CAN see a violation, and that the two
-- ways of being clean are both honored. Without these, all three tests above
-- pass just as happily on an extractor that matches nothing.
tests['a bogus gate id in a synthetic source is detected'] = function()
    local wired = wired_ids_in("J.IsSoakCandidate( 'realid' )")
    local claims = claims_in("-- Gated (turbo + 'ghostid'); inert by default.", 'synthetic')
    assert(#claims == 1, 'extractor did not see the synthetic claim')
    assert(not wired[claims[1].id], "synthetic 'ghostid' should be unwired")
    assert(claims[1].id == 'ghostid', 'wrong id extracted: ' .. claims[1].id)
end

tests['a wired gate id in a synthetic source is not flagged'] = function()
    local wired = wired_ids_in("J.IsSoakCandidate( 'realid' )")
    local claims = claims_in("-- Gated turbo + soak-candidate 'realid'; inert.", 'synthetic')
    assert(#claims == 1 and wired[claims[1].id],
        'a genuinely wired id must not be flagged')
end

tests['a PROMOTED line is exempt even with no gate left'] = function()
    local claims = claims_in(
        "-- PROMOTED (was soak-candidate 'goneid'); no gate, turbo default-on.",
        'synthetic')
    assert(#claims == 1 and claims[1].promoted,
        'PROMOTED is the documented exit and must exempt the line')
end

-- The over-claim direction has a second, sharper failure mode than a stale
-- comment: an id nothing wires can still be ARMED by soak_side.lua, and the
-- wave then measures a no-op while reading as a real test. Pin it by name so
-- the reason this file exists survives the next edit.
tests['nochaselow is not resurrected as an unwired id'] = function()
    local wired, claims = census()
    for _, c in ipairs(claims) do
        assert(not (c.id == 'nochaselow' and not wired[c.id]),
            c.path .. ':' .. c.line .. " still names 'nochaselow'; the "
            .. 'anti-suicide-chase guard is gated on lanefix / lf_chase')
    end
end

return tests
