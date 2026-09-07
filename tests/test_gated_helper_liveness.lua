-- [ratchet] A GATED HELPER WITH NO CALL SITE IS A DEAD ID, AND ON 2026-09-07 A
-- LIVE ARMED ONE BECAME ONE IN A ONE-LINE DIFF THAT NOTHING COUNTED.
--
-- WHAT HAPPENED (GH #600; the first two of GH #601's four trunk reds).
-- `8b25217e` landed the 'pgchannel' veto into mode_retreat_generic's
-- GetDesireHelper by REPLACING the condition of the veto that was already
-- standing there:
--
--     -    if J.ShouldRegenNotWalkHome(bot) then
--     +    if J.ShouldLetTpChannelFinish(bot) then
--              return BOT_MODE_DESIRE_NONE
--          end
--
-- The two vetoes have the SAME BODY, so that diff adds a veto and deletes a
-- veto in the same token, and the ten-line comment block naming 'stayfield2'
-- stayed above it describing a line that was no longer there. 'stayfield2' is
-- IN the live 51-id armed string: for the whole window every wave that armed it
-- measured a no-op, and `tools/batch_test/check_armed_wiring.py` reported it
-- WIRED throughout -- correctly by its own LIMITS block, because WIRED means
-- "the gate exists in bots/" and the gate lives INSIDE J.ShouldRegenNotWalkHome,
-- which nobody touched. A verdict from such a wave reads "tested, no effect".
--
-- WHAT SAW IT was tests/test_stayfield_callsite_domain.lua, which asserts that
-- one call is inside that one function -- a file that exists only because
-- 'stayfield2' happened to get a dedicated call-site test. No other id has one.
-- THIS FILE IS THE GENERAL FORM: every J.* helper that carries its own
-- J.IsSoakCandidate gate must be called from somewhere in bots/, and the set of
-- exceptions is pinned rather than tolerated.
--
-- WHY THE PREDICATE IS "ZERO CALL SITES" AND NOT SOMETHING SHARPER -- measured,
-- not chosen. On this tree there are 66 gated J.* helpers and exactly TWO have
-- no call site, both explainable (see EXEMPT below), so the rule costs two
-- pinned rows today. A sharper rule (say, "reachable on some armed leg") would
-- have to decide what an arbitrary Lua function returns un-armed, which is the
-- 量具-that-manufactures-findings failure tests/test_gated_helper_nesting_census
-- refuses for the same reason.
--
-- SCOPE, stated because it reads wider than it is: every J.* helper carrying a
-- soak gate in this tree is defined in bots/FunLib/jmz_func.lua -- measured at
-- 0 defined anywhere else -- so "the library" and "the class" coincide today.
-- Gated blocks written inline at a call site (mode files, hero files) are NOT
-- this file's subject: they cannot lose a call site, they are one.
--
-- HONEST LIMIT: a call site existing is not a call site being REACHED. This
-- file answers "did the lever's only consumer get deleted", nothing else -- the
-- reachability question is the nesting census's (gate-inside-a-gate) and the
-- single-arm sweeps'. Its value is that its answer changes in the same commit
-- as the defect, which is the property the wiring checker does not have.

package.path = 'tests/?.lua;' .. package.path

local LIB = 'bots/FunLib/jmz_func.lua'

-- The two gated J.* helpers that legitimately have no call site on this tree.
-- Each is a READING, not a tolerance: a third entry has to be explained here
-- before it is added, exactly as the nesting census requires of a new row.
local EXEMPT = {
    -- Infrastructure, not a lever: it is how J.IsSoakCandidate itself reads the
    -- farm's side/candidate file. It carries no id of its own (its body names
    -- no literal candidate), so there is no wave that could measure it.
    ['J.IsSoakCandidateSide'] = true,
    -- The 'lanefix' BUNDLE wrapper. The bundle was REJECTED twice by the final
    -- gate (gpm -74.5, then -88.7, 0/4 comps -- AGENTS.md's crux lesson), and
    -- its members were re-narrowed to their own lf_* ids afterwards, which is
    -- what took this wrapper's last call site away. Dead on purpose, and the
    -- entry is here so that "dead" stays a decision on the record rather than a
    -- thing nobody has looked at since July.
    ['J.IsLaneFixActive'] = true,
}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local text = fh:read('*a')
    fh:close()
    return text
end

--- Source with every comment removed. Load-bearing in both directions, and this
--- repo has paid for both: a comment that QUOTES a call must not count as a
--- call, and a real call must not be hidden. Same stripper as the nesting
--- census, for the same reasons.
local function strip_comments(src)
    src = src:gsub('%-%-%[==%[.-%]==%]', '')
    src = src:gsub('%-%-%[%[.-%]%]', '')
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        local i = line:find('--', 1, true)
        out[#out + 1] = i and line:sub(1, i - 1) or line
    end
    return table.concat(out, '\n')
end

local function bot_files()
    -- Skip the two gitignored, farm-only files under bots/Customize/: the gate
    -- switch is created and deleted by every gate test in this suite, so
    -- opening it here is a race whose red names neither this file's subject nor
    -- a real defect.
    local files = {}
    local p = assert(io.popen(
        'find bots -name "*.lua" ! -path "bots/Customize/soak_*.lua" | sort'))
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    return files
end

--- Every top-level `function J.x(` in `code` whose body names IsSoakCandidate.
--- A body runs to the next line that is exactly `end` at column 0 -- the whole
--- file layout convention in bots/, where an indented `end` closes an inner
--- block and never a top-level function.
local function gated_helpers(code)
    local lines = {}
    for line in (code .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = line end
    local names, order = {}, {}
    local i = 1
    while i <= #lines do
        local name = lines[i]:match('^function (J%.%w+)%s*%(')
        if name then
            local j = i + 1
            while j <= #lines and lines[j]:gsub('%s+$', '') ~= 'end' do j = j + 1 end
            local body = table.concat(lines, '\n', i, math.min(j, #lines))
            if body:find('IsSoakCandidate', 1, true) then
                if not names[name] then order[#order + 1] = name end
                names[name] = true
            end
            i = j
        end
        i = i + 1
    end
    return order
end

--- Call sites of `J.<short>(` across the corpus, NOT counting the definition
--- itself. `%s*%(` after the name is what keeps a short name from matching a
--- longer one that starts with it.
local function call_sites(tCorpus, sName)
    local short = sName:match('^J%.(%w+)$')
    local n = 0
    for _, code in pairs(tCorpus) do
        n = n + select(2, code:gsub('J%.' .. short .. '%s*%(', ''))
             - select(2, code:gsub('function%s+J%.' .. short .. '%s*%(', ''))
    end
    return n
end

local function corpus()
    local t = {}
    for _, f in ipairs(bot_files()) do t[f] = strip_comments(read_file(f)) end
    return t
end

--- The finding: gated helpers nothing calls.
local function dead(tCorpus)
    local out = {}
    for _, name in ipairs(gated_helpers(tCorpus[LIB])) do
        if call_sites(tCorpus, name) == 0 then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

local tests = {}

tests['[ratchet] every gated J.* helper still has a call site'] = function()
    local tCorpus = corpus()
    local unexplained = {}
    for _, name in ipairs(dead(tCorpus)) do
        if not EXEMPT[name] then unexplained[#unexplained + 1] = name end
    end
    assert(#unexplained == 0,
        'a gated helper lost its last call site -- its id is now a DEAD GATE, '
        .. 'and check_armed_wiring.py will still call it WIRED:\n      '
        .. table.concat(unexplained, '\n      ')
        .. '\n    If the id is in the armed string, every wave arming it is '
        .. 'measuring a no-op. Restore the call, or retire the id AND add it to '
        .. 'EXEMPT above with the reading that made it dead.')
end

tests['[ratchet] the pinned exemptions are still exactly the dead set'] = function()
    -- The other direction, and the reason EXEMPT is a set and not a skip-list:
    -- an exemption that has quietly come back to life is a stale claim about
    -- this tree, and the next reader of that list would inherit it.
    local seen = {}
    for _, name in ipairs(dead(corpus())) do seen[name] = true end
    local revived = {}
    for name in pairs(EXEMPT) do
        if not seen[name] then revived[#revived + 1] = name end
    end
    table.sort(revived)
    assert(#revived == 0,
        'an EXEMPT helper has a call site again -- drop its row and its '
        .. 'paragraph rather than leaving a dead-on-purpose claim standing:\n      '
        .. table.concat(revived, '\n      '))
end

tests['[floor] the extractor still sees the class it is scanning'] = function()
    -- A census whose extractor breaks reads CLEAN, and clean is the answer this
    -- file publishes. The floor is deliberately far below today's 66 so that
    -- ordinary promotes (which delete gates) never touch it, while an extractor
    -- that has stopped parsing bots/ cannot pass.
    local tCorpus = corpus()
    local n = #gated_helpers(tCorpus[LIB])
    assert(n >= 40,
        'only ' .. n .. ' gated J.* helpers found in ' .. LIB .. ' -- the '
        .. 'extractor stopped seeing them; a zero here would read exactly like '
        .. 'a clean tree')

    -- Every gated J.* helper in this tree is defined in the library, which is
    -- what makes LIB the whole class rather than a sample of it. Measured at 0
    -- elsewhere on 2026-09-07; if that changes, this file's scope has to widen
    -- with it instead of silently narrowing.
    for path, code in pairs(tCorpus) do
        if path ~= LIB then
            assert(#gated_helpers(code) == 0,
                'a gated J.* helper is now defined outside ' .. LIB .. ' ('
                .. path .. ') -- widen this file to scan it, or its id can go '
                .. 'dead unseen')
        end
    end
end

tests['[positive control] the detector names the call this file was born for'] = function()
    -- END TO END, not a parser unit test: take the real corpus and delete the
    -- exact line `8b25217e` deleted, then assert the detector names
    -- J.ShouldRegenNotWalkHome. Without this leg every assertion above passes
    -- on a detector that finds nothing at all.
    local tCorpus = corpus()
    local before = tCorpus['bots/mode_retreat_generic.lua']
    local after, n = before:gsub('if J%.ShouldRegenNotWalkHome%(bot%) then', 'if false then', 1)
    assert(n == 1,
        'the restored stayfield2 call is not where this file expects it in '
        .. 'GetDesireHelper -- the control below would prove nothing')
    tCorpus['bots/mode_retreat_generic.lua'] = after

    local seen = {}
    for _, name in ipairs(dead(tCorpus)) do seen[name] = true end
    assert(seen['J.ShouldRegenNotWalkHome'],
        'with the only stayfield2 call site removed, the detector still reports '
        .. 'no dead gate -- it cannot see the defect it exists for')
    assert(not EXEMPT['J.ShouldRegenNotWalkHome'],
        'stayfield2 got itself onto the exemption list, which would mute this '
        .. 'control permanently')

    -- And the negative half of the same control: on the UNMODIFIED corpus that
    -- name is absent, i.e. the restore is what makes the tree clean, not a
    -- detector that always answers "clean".
    local seen2 = {}
    for _, name in ipairs(dead(corpus())) do seen2[name] = true end
    assert(not seen2['J.ShouldRegenNotWalkHome'],
        'the stayfield2 call site is missing from the real tree -- GH #600 has '
        .. 'regressed')
end

tests['[source] the restored veto sits in GetDesireHelper, beside pgchannel'] = function()
    -- The shape of the accident, pinned where it happened: two vetoes with the
    -- SAME body, so a swap of one predicate for the other is invisible to
    -- anything that counts ids, gates or call sites. Both calls must be inside
    -- GetDesireHelper and both must be present.
    local ret = strip_comments(read_file('bots/mode_retreat_generic.lua'))
    local i = assert(ret:find('function GetDesireHelper()', 1, true),
        'GetDesireHelper was renamed -- re-read this file')
    local a = assert(ret:find('J.ShouldRegenNotWalkHome(bot)', i, true),
        'the stayfield2 veto left GetDesireHelper again (GH #600)')
    local b = assert(ret:find('J.ShouldLetTpChannelFinish(bot)', i, true),
        'the pgchannel veto left GetDesireHelper')
    assert(a < b,
        'the two vetoes swapped order. Behaviourally free (both answer NONE, '
        .. 'neither helper has a side effect the other loses) -- but this file '
        .. 'pins the order the restore chose, so a REPLACEMENT can never again '
        .. 'read as a reordering')
end

return tests
