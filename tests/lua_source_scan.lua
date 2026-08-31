-- Shared source-scanning primitives for source-shape tests over `bots/`.
--
-- WHY THIS FILE EXISTS (GH #346, hero 2026-08-30).
-- ------------------------------------------------
-- `strip_line_comment` was a file-local of tests/test_activemode_call_site_census.lua,
-- whose header records, in its own words, why it must not be duplicated:
--
--     "THE SCANNER MOVED, IT WAS NOT COPIED. [...] A second copy would be this
--      repo's most expensive recorded trap ('a test that mirrors the thing it
--      checks is checking the mirror', tests/test_selfcheck_lua_leg.py 2a2)."
--
-- A second source-shape test (tests/test_nil_guard_then_body.lua) needs the same
-- cut.  So the function MOVED again, by the same rule that put it there: it lives
-- HERE now and nowhere else, and both callers require it.  The census file keeps
-- its own direct unit checks on the cut -- they now exercise this copy, which is
-- the only one, so the checks got stronger by moving rather than weaker.
--
-- LIMIT (inherited, unchanged): long comments (`--[[ ... ]]`) are not tracked
-- across lines.  A caller that needs that must say so in its own header.

local M = {}

--- Cut a line at its first `--` that is NOT inside a quoted string.
--
-- Deliberately conservative: `--` inside a string literal does NOT start a
-- comment, so a real call sitting after such a string is still counted.  The
-- naive `line:find('--')` would have dropped it -- an over-wide cut is the same
-- class of defect as the over-wide pattern GH #267 fixed.
function M.strip_line_comment(line)
    local quote = nil
    local i = 1
    while i <= #line do
        local c = line:sub(i, i)
        if quote then
            if c == '\\' then
                i = i + 1
            elseif c == quote then
                quote = nil
            end
        elseif c == '"' or c == "'" then
            quote = c
        elseif c == '-' and line:sub(i + 1, i + 1) == '-' then
            return line:sub(1, i - 1)
        end
        i = i + 1
    end
    return line
end

--- Every shipped Lua file under `bots/`, sorted, as a list of paths.
function M.bots_files()
    local out = {}
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for file in p:lines() do
        out[#out + 1] = file
    end
    p:close()
    return out
end

--- A file as a list of comment-stripped lines (1-indexed, line N == lines[N]).
function M.stripped_lines(path)
    local out = {}
    for raw in io.lines(path) do
        out[#out + 1] = M.strip_line_comment(raw)
    end
    return out
end

--- Does `line` ASSIGN identifier `var` (`var = ...`, but not `var == ...`)?
--
-- Load-bearing for the nil-guard scan: the correct, common idiom
--
--     if X == nil then
--         X = {}          -- <== from here on X is not nil
--         X.field = 1     -- ...so this is not a defect
--     end
--
-- is indistinguishable from the defect unless the scan STOPS at the assignment.
-- Without this, the whole-tree census reported 4 hits of which 3 were this
-- idiom (FretBots/HeroLoneDruid.lua, FunLib/aba_role.lua x2), all hand-read.
function M.assigns_var(line, var)
    local padded = ' ' .. line .. ' '
    return padded:match('[^%w_]' .. var .. '%s*=[^=]') ~= nil
end

--- Does `line` index identifier `var` (i.e. `var.field` or `var[expr]`)?
--
-- Word-boundary padded so that `nFoo` does not match inside `nFooBar`, and
-- requires a `.` or `[` to FOLLOW the identifier -- so a plain assignment
-- (`var = { count = 0 }`) is not an index, which is exactly the distinction the
-- nil-guard test is built on.
function M.indexes_var(line, var)
    local padded = ' ' .. line .. ' '
    return padded:match('[^%w_]' .. var .. '%s*[%.%[]') ~= nil
end

--- Block-depth delta for one line: `then` / `do` / `function` / `repeat` open,
-- `end` / `until` close.  Crude but sufficient, and it only ever OVER-counts
-- depth, which makes the body scan stop early -- a false negative, never a
-- false positive.
local function depth_delta(line)
    local padded = ' ' .. line .. ' '
    local d = 0
    for _, open in ipairs({ 'then', 'do', 'function', 'repeat' }) do
        for _ in padded:gmatch('[^%w_]' .. open .. '[^%w_]') do d = d + 1 end
    end
    for _, close in ipairs({ 'end', 'until' }) do
        for _ in padded:gmatch('[^%w_]' .. close .. '[^%w_]') do d = d - 1 end
    end
    return d
end

--- Find both defective nil-guard shapes in one file.
--
-- Returns two lists of `{path, line, var}`:
--   self_indexing -- the guard's own then-body indexes the value it found nil
--   pre_indexed   -- the value was ALREADY indexed, unguarded, between its
--                    `local` declaration and the guard, so the guard cannot
--                    protect anything: the crash happens above it
--
-- Deliberately conservative in four ways, each of which can only make the
-- census SMALLER (a false negative), never larger:
--   * only conditions that are a pure disjunction are considered.  One `and`
--     anywhere and the site is skipped, because `X == nil and ...` does not
--     necessarily route a nil into the body.
--   * `elseif` never opens a guard (only a line starting `if`).
--   * the body scan stops at the first depth-0 `end` / `else` / `elseif`, and
--     `depth_delta` over-counts depth, so it can only stop EARLY.
--   * (b) requires a `local X = <call>(...)` declaration in the same function.
function M.nil_guard_shapes(path)
    local lines = M.stripped_lines(path)
    local self_indexing, pre_indexed = {}, {}

    for i = 1, #lines do
        if lines[i]:match('^%s*if%s') then
            -- Glue the header together until the line carrying `then`.
            --
            -- ⚠️ THE PADDING IS LOAD-BEARING and its absence was this scanner's
            -- first bug: `[^%w_]then[^%w_]` needs a character after `then`, so a
            -- header ending exactly in `then` did not match, the glue ran on one
            -- line too far, and every body was read one line late.  That single
            -- off-by-one is what produced the 53-hit first census.
            local header, j = ' ' .. lines[i] .. ' ', i
            while j < #lines and not header:match('[^%w_]then[^%w_]') do
                j = j + 1
                header = header .. lines[j] .. ' '
            end

            local cond, rest = header:match('^%s*if%s+(.-)[^%w_]then[^%w_](.*)$')
            if cond and not (' ' .. cond .. ' '):match('[^%w_]and[^%w_]') then
                for var in cond:gmatch('([%w_]+)%s*==%s*nil') do
                    -- (a) does the then-body index the value?  The body may be
                    -- inline (`if X == nil then return end`) -- the second bug
                    -- the first census had, which made a one-line guard read the
                    -- code AFTER its own `end` as its body.
                    local hit = nil
                    local depth = 0
                    local rest_t = (rest or ''):match('^%s*(.-)%s*$')
                    if rest_t ~= '' then
                        if not rest_t:match('^end[^%w_]?')
                            and not M.assigns_var(rest, var)
                            and M.indexes_var(rest, var) then
                            hit = i
                        end
                        depth = depth + depth_delta(rest)
                    end
                    if not hit and depth >= 0 then
                        for k = j + 1, #lines do
                            local t = lines[k]:match('^%s*(.-)%s*$')
                            if depth == 0 and (t == 'end' or t == 'else'
                                or t == 'elseif' or t:match('^end[^%w_]')
                                or t:match('^elseif[^%w_]')) then
                                break
                            end
                            if M.assigns_var(lines[k], var) then
                                break
                            end
                            if M.indexes_var(lines[k], var) then
                                hit = k
                                break
                            end
                            depth = depth + depth_delta(lines[k])
                            if depth < 0 then break end
                        end
                    end
                    if hit then
                        self_indexing[#self_indexing + 1] = { path, hit, var }
                    end

                    -- (b) was it already indexed before the guard could fire?
                    -- Scoped to a `local X = <call>(...)` declaration, so that a
                    -- long-lived local indexed in unrelated branches far above
                    -- is not swept in -- the other half of the 53.
                    local decl
                    for k = i - 1, 1, -1 do
                        if (' ' .. lines[k]):match('[^%w_]local%s+' .. var .. '%s*=.*%(') then
                            decl = k
                            break
                        end
                        if lines[k]:match('^%s*function%s') then break end
                    end
                    if decl then
                        for k = decl + 1, i - 1 do
                            if M.indexes_var(lines[k], var) then
                                pre_indexed[#pre_indexed + 1] = { path, k, var }
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    return self_indexing, pre_indexed
end


--- The complete key set of a `FindAoELocation` result table.
--
-- docs/BOT_API_REFERENCE.md:1377 -- "Returns: A table with: `count` (int) ...
-- `targetloc` (vector)".  Two keys, and the doc's own worked example reads
-- exactly those two.  A read of any OTHER name answers nil, silently: Lua does
-- not error on a missing table key, `print()` never reaches the server console
-- and the engine's error handler is broken (AGENTS.md), so a misspelling here
-- is invisible from inside a game and shows up only as a branch that never
-- fires.
M.AOE_RESULT_KEYS = { count = true, targetloc = true }


--- Every field read off a `FindAoELocation` result whose name is not one of the
-- two the API returns.
--
-- Returns `(rows, sites)`:
--   rows  -- `{path, line, var, field}` per offending read, deduplicated per
--            (line, field) so that `X.cout ~= nil and X.cout >= 2` counts once
--   sites -- how many `local <var> = ...FindAoELocation(...)` declarations were
--            tracked in this file.  Returned so a CALLER can assert the scan
--            actually looked at something: a scanner pointed at nothing reports
--            zero findings and exits clean, which is the shape GH #345 caught
--            in arm_string_census.py ("0 games + exit 0").
--
-- Conservative in three ways, each of which can only make the census SMALLER:
--   * only `local X = ...FindAoELocation(...)` declarations are tracked, never
--     a result passed straight into a call or stored on a table field;
--   * tracking stops at the next `function` line, so a same-named local in a
--     later function is not attributed here;
--   * tracking stops as soon as `var` is assigned again, because from there on
--     the value need not be an AoE result at all.
function M.aoe_result_fields(path)
    local lines = M.stripped_lines(path)
    local rows, sites = {}, 0

    for i = 1, #lines do
        local var = lines[i]:match('local%s+([%w_]+)%s*=[^=]*FindAoELocation%s*%(')
        if var then
            sites = sites + 1
            local seen = {}
            for k = i + 1, #lines do
                if lines[k]:match('^%s*function%s') or lines[k]:match('^%s*local%s+function%s') then
                    break
                end
                if M.assigns_var(lines[k], var) then break end
                for f in (' ' .. lines[k]):gmatch('[^%w_]' .. var .. '%s*%.%s*([%w_]+)') do
                    if not M.AOE_RESULT_KEYS[f] and not seen[k .. ':' .. f] then
                        seen[k .. ':' .. f] = true
                        rows[#rows + 1] = { path, k, var, f }
                    end
                end
            end
        end
    end

    return rows, sites
end


return M
