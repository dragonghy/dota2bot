-- [GH #29] Retreat guard chain: source order IS priority order.
--
-- GetDesireHelper() returns on the FIRST guard that fires, so a guard placed
-- above a stronger one silently downgrades it. Observed defect: `tpwatch`
-- (VERYHIGH -- a TP channel being eaten alive must outbid everything) and
-- `pushguard` (0.92, a value picked specifically to outbid an active
-- kill-chase) both sat BELOW several HIGH (0.75) guards, so on any frame
-- where a HIGH guard also fired they could never win. It also made the
-- soak candidates non-independent: arming two ids changed each other's
-- effective behavior.
--
-- This is a SOURCE-LEVEL test on purpose. The alternative -- driving
-- GetDesireHelper() through a fixture -- can only prove the ordering for the
-- one pair of guards the fixture happens to trigger; the invariant we need
-- holds for every pair, including guards added next month. So we assert the
-- structure directly, between the explicit BEGIN/END markers in the file.
--
-- Vetoes (NONE) are exempt: they are not desire floors, they are hard
-- suppressions whose placement expresses "this bot must not retreat at all",
-- which is orthogonal to the descending-desire ordering.

local BEGIN_MARK = '=== RETREAT GUARD CHAIN: BEGIN'
local END_MARK   = '=== RETREAT GUARD CHAIN: END'

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local SOURCE = 'bots/mode_retreat_generic.lua'

-- Collect the guard returns between the markers, in source order.
-- Each entry: { line = <1-based line no>, value = <numeric desire>, text = <raw> }
local function collect_guard_returns()
    local fh = assert(io.open(SOURCE, 'r'), 'cannot open ' .. SOURCE)
    local inside, seen_begin, seen_end = false, false, false
    local out, lineno = {}, 0

    for line in fh:lines() do
        lineno = lineno + 1
        if line:find(BEGIN_MARK, 1, true) then
            inside, seen_begin = true, true
        elseif line:find(END_MARK, 1, true) then
            inside, seen_end = false, true
        elseif inside then
            -- ignore comment lines; only real `return <desire>` statements count
            local code = line:match('^%s*(.-)%s*$')
            if not code:match('^%-%-') then
                local sym = code:match('^return%s+(BOT_MODE_DESIRE_%u+)%s*$')
                local num = code:match('^return%s+([%d%.]+)%s*$')
                if sym then
                    out[#out + 1] = { line = lineno, value = DESIRE[sym], text = sym }
                elseif num then
                    out[#out + 1] = { line = lineno, value = tonumber(num), text = num }
                end
            end
        end
    end
    fh:close()

    assert(seen_begin, SOURCE .. ': missing "' .. BEGIN_MARK .. '" marker')
    assert(seen_end, SOURCE .. ': missing "' .. END_MARK .. '" marker')
    return out
end

local tests = {}

tests['guard chain is parseable and non-trivial'] = function()
    local guards = collect_guard_returns()
    assert(#guards >= 8, ('expected >= 8 guard returns in the chain, found %d ' ..
        '(markers moved, or the chain was gutted?)'):format(#guards))
    for _, g in ipairs(guards) do
        assert(type(g.value) == 'number',
            ('%s:%d: unrecognized desire "%s"'):format(SOURCE, g.line, tostring(g.text)))
    end
end

tests['guard desires are non-increasing in source order (GH #29)'] = function()
    local guards = collect_guard_returns()
    local prev = nil
    for _, g in ipairs(guards) do
        if g.value > 0 then -- NONE vetoes are exempt, see header
            if prev and g.value > prev.value then
                error(('%s:%d returns %s (%.2f) but is placed BELOW %s:%d which ' ..
                    'returns %s (%.2f). The chain returns on first match, so the ' ..
                    'stronger guard can never win a frame where the weaker one also ' ..
                    'fires. Move it above, per the INVARIANT comment in %s.'):format(
                    SOURCE, g.line, g.text, g.value,
                    SOURCE, prev.line, prev.text, prev.value, SOURCE))
            end
            prev = g
        end
    end
end

tests['the two guards GH #29 was filed for outrank every HIGH guard'] = function()
    -- Regression pin for the specific defect, independent of the generic
    -- ordering rule above: whatever else moves, these two must stay on top.
    local fh = assert(io.open(SOURCE, 'r'))
    local src = fh:read('*a')
    fh:close()

    local chain = src:match(BEGIN_MARK .. '(.-)' .. END_MARK)
    assert(chain, 'guard chain markers not found in ' .. SOURCE)

    local tpwatch = chain:find('J.ShouldAbandonTpChannel', 1, true)
    local pushguard = chain:find('J.ShouldAbortDeepSoloPush', 1, true)
    assert(tpwatch, 'tpwatch guard (J.ShouldAbandonTpChannel) left the guard chain')
    assert(pushguard, 'pushguard guard (J.ShouldAbortDeepSoloPush) left the guard chain')

    -- every HIGH-returning guard must come after both of them
    local pos = 1
    while true do
        local s, e = chain:find('return%s+BOT_MODE_DESIRE_HIGH', pos)
        if not s then break end
        assert(s > tpwatch, 'a HIGH guard is placed above tpwatch (VERYHIGH) -- GH #29 regression')
        assert(s > pushguard, 'a HIGH guard is placed above pushguard (0.92) -- GH #29 regression')
        pos = e + 1
    end
end

return tests
