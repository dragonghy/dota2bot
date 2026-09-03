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
    -- Skip the two gitignored, farm-only files under bots/Customize/. The gate
    -- switch `soak_side.lua` is created and deleted by every gate test in this
    -- suite, so listing it and then `read_file`-ing it (which asserts) is a
    -- race whose red -- `cannot open <that switch>` -- names
    -- neither this file's subject nor a real defect. THIS FILE IS ONE OF THE
    -- THREE CARRIERS GH #365 §2 PUBLISHED (`:42`), seen again here on
    -- 2026-09-02 in 开工自检's Lua-detector leg. #365 read those reds as GH
    -- #229's contention and routed the fix into #229's scope (a per-process
    -- switch path, still blocked) -- but this file is not a gate test and
    -- never writes the switch: it only walks over it, and the walk is its own
    -- to fix. Neither farm-only file is bot logic or carries a gate claim.
    local p = assert(io.popen('find ' .. BOTS_ROOT
        .. ' -name "*.lua" ! -path "' .. BOTS_ROOT .. '/Customize/soak_*.lua" | sort'))
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

--- Blank every COMMENT byte in a Lua source, keeping offsets and newlines.
--
-- WHY THIS EXISTS (2026-09-03). `wired_ids_in` used to run its patterns over
-- the raw file, so an id that appears in `IsSoakCandidate('id')` form ONLY
-- INSIDE A COMMENT was collected as wired -- and this file's whole verdict is
-- `not claim.promoted and not wired[claim.id]`. The register and the thing
-- being registered were the same text: an over-claim is masked by any comment
-- that quotes the id in call form, which is precisely what a comment ABOUT a
-- gate does.
--
-- It is not hypothetical, and the two live carriers are self-referential:
--
--   * 'pullbeat' -- PROMOTED 2026-08-23, wired by nothing. It sat in the wired
--     set because THREE comment blocks in mode_roam_generic.lua (:253, :331,
--     :416) teach the `pullcad` trap by quoting the conjunction that would
--     freeze FALSE. The prose explaining "a promoted id is in no armed string"
--     was what put that promoted id back into the armed-string census.
--   * 'X' -- jmz_func.lua:1909, the METAVARIABLE in `IsSoakCandidate('X') and
--     IsSoakCandidate('abilanc')`. A placeholder was minted into a gate id.
--
-- So a comment reading `-- Gated (turbo + 'pullbeat')` -- the likeliest
-- over-claim on this tree, because the name is still all over the roam
-- comments a month after promotion -- passed the census clean. Arming
-- 'pullbeat' arms nothing; the wave reads "tested, neutral". That is verbatim
-- the `nochaselow` failure in the header, reached by a different door.
--
-- Strings are KEPT, deliberately: `IsSoakCandidate('pullcad')` IS a string
-- literal. This only has to know where a string ENDS so that a `--` inside one
-- is not read as a comment. Long forms (`--[[`, `--[=[`, `[[`, `[=[`) are
-- handled because bots/ has 80 of the first and 204 of the second.
--
-- Comment bytes become spaces and newlines survive. Of those two, only the
-- NEWLINES have a reader: `SoakStrArms%b()(.-)\nend` below is anchored on one.
-- Byte offsets are preserved as well, but every extractor here is a
-- position-independent `gmatch`, so that half is a defensive property and not a
-- tested claim -- two mutants had to survive before that distinction was drawn
-- (tools/agent/mutstand_gatecomment.sh, header).
local function strip_lua_comments(src)
    local out, i, n = {}, 1, #src
    local NONE = n + 1
    local cs, qs, bs, beq
    while i <= n do
        if cs == nil or cs < i then cs = src:find('--', i, true) or NONE end
        if qs == nil or qs < i then qs = src:find("['\"]", i) or NONE end
        if bs == nil or bs < i then
            local s, _, eq = src:find('%[(=*)%[', i)
            bs, beq = s or NONE, eq
        end
        local first = math.min(cs, qs, bs)
        if first == NONE then
            out[#out + 1] = src:sub(i)
            break
        end
        out[#out + 1] = src:sub(i, first - 1)
        if first == cs then
            -- A comment: long-bracket form, else to end of line.
            local _, le, leq = src:find('^%-%-%[(=*)%[', first)
            local stop
            if le then
                local close = ']' .. leq .. ']'
                local j = src:find(close, le + 1, true)
                stop = j and (j + #close - 1) or n
            else
                local j = src:find('\n', first, true)
                stop = j and (j - 1) or n
            end
            out[#out + 1] = (src:sub(first, stop):gsub('[^\n]', ' '))
            i = stop + 1
        elseif first == qs then
            -- A short string: copied through verbatim, only skipped over.
            local q = src:sub(first, first)
            local j, stop = first + 1, nil
            while j <= n do
                local c = src:sub(j, j)
                if c == '\\' then
                    j = j + 2
                elseif c == q or c == '\n' then
                    stop = j
                    break
                else
                    j = j + 1
                end
            end
            stop = stop or n
            out[#out + 1] = src:sub(first, stop)
            i = stop + 1
        else
            -- A long string: also copied through verbatim.
            local close = ']' .. beq .. ']'
            local j = src:find(close, first + #beq + 2, true)
            local stop = j and (j + #close - 1) or n
            out[#out + 1] = src:sub(first, stop)
            i = stop + 1
        end
    end
    return table.concat(out)
end

--- Gate ids this source actually wires, by the three forms the tree uses.
-- Returns a set. Exposed (not inlined) so the synthetic controls below run
-- through the SAME extractor the census does -- a control that exercises a
-- different code path proves nothing about the census.
--
-- Comments are stripped FIRST (see strip_lua_comments): what a comment says
-- about a gate is the claim under audit, never evidence for it.
--
-- SPLIT IN TWO on purpose. `wired_ids_in_text` holds every pattern and is the
-- ONLY place they live; `wired_ids_in` is that same extractor with the
-- comment strip in front. The domain-price ratchet below reads the tree BOTH
-- ways, and it may only do so through one code path -- a "before" figure
-- produced by a second copy of the patterns would agree with any drift in
-- either copy, which is the shape GH #67 names.
local function wired_ids_in_text(src, into)
    local set = into or {}
    for id in src:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do set[id] = true end
    for id in src:gmatch('IsSoakCandidate%s*%(%s*"([%w_]+)"') do set[id] = true end
    -- J.IsLaneFixOn(sub) arms the bundle id or the per-fix id 'lf_<sub>'.
    for sub in src:gmatch("IsLaneFixOn%s*%(%s*'([%w_]+)'") do
        set['lf_' .. sub] = true
        set['lanefix'] = true
    end
    -- The wildcard id 'all' is never CALLED, only COMPARED: the soak reader
    -- decides it by a literal comparison against the armed string, so the two
    -- call-form rules above cannot see it.
    --   pre-GH #141: J.IsSoakCandidate compared `conf.cand` inline;
    --   post-#141:   both legs share one matcher, SoakStrArms.
    -- The second rule is scoped to that function's OWN BODY rather than
    -- matching every `== 'literal'` in the file -- a rule wide enough to see
    -- the wildcard everywhere would also mint gate ids out of unrelated string
    -- comparisons, and a census that over-collects stops flagging over-claims.
    for id in src:gmatch("cand%s*==%s*'([%w_]+)'") do set[id] = true end
    local sMatcher = src:match('local function SoakStrArms%b()(.-)\nend')
    if sMatcher then
        for id in sMatcher:gmatch("==%s*'([%w_]+)'") do set[id] = true end
    end
    return set
end

local function wired_ids_in(src, into)
    return wired_ids_in_text(strip_lua_comments(src), into)
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

--- The verdict itself, factored out of the invariant below so that it has
--- somewhere to be tested. The extractors already had synthetic controls; this
--- half did not, and it is the half that decides what counts as drift. The tree
--- has been clean since the 2026-08-22 sweep, so the census never walks the
--- violating branch on real data -- widen this boundary (exempt one more shape,
--- treat every claim as promoted) and every assertion in this file still
--- passes. Backlog 24, same shape as test_dup_component_buylist_census.lua's
--- is_partial / offences_in pair.
local function is_violation(claim, wired)
    return not claim.promoted and not wired[claim.id]
end

--- Render the claims that violate the invariant, as readable strings.
--- Extracted for the same reason is_violation is: on a clean tree the reporting
--- branch is unreachable from real data, so a mutation that stopped reporting
--- would be invisible without a synthetic caller. (Still invisible, honestly: a
--- mutation at the call site that drops the result on the floor -- nothing an
--- extraction can falsify from a world with nothing to report.)
local function offences_in(claims, wired)
    local bad = {}
    for _, c in ipairs(claims) do
        if is_violation(c, wired) then
            bad[#bad + 1] = string.format(
                "%s:%d names gate '%s', which nothing in bots/ wires\n      %s",
                c.path, c.line, c.id, c.text)
        end
    end
    return bad
end

--- One walk of bots/, memoised: the wired set, the claims, and -- third return
--- value, added 2026-09-03 -- what the SAME extractor collects from the RAW
--- text, which is what this file collected before the comment strip existed.
--
-- MEMOISED because five tests below want it and the strip is the expensive part:
-- unmemoised, adding the raw side took this file from 2.4s to 4.6s, and the fast
-- Lua detector leg it runs inside is already hitting a 120s budget in Routine
-- containers. One walk, one strip per file: 1.1s, faster than before the strip
-- existed. Safe because the tree does not change inside a process -- the
-- mutation stand mutates BETWEEN processes.
local cached_census
local function census()
    if cached_census then
        return cached_census[1], cached_census[2], cached_census[3]
    end
    local wired, claims, raw = {}, {}, {}
    for _, path in ipairs(list_lua_files()) do
        local src = read_file(path)
        wired_ids_in(src, wired)      -- comments stripped (today)
        wired_ids_in_text(src, raw)   -- comments included (before the fix)
        for _, c in ipairs(claims_in(src, path)) do claims[#claims + 1] = c end
    end
    cached_census = { wired, claims, raw }
    return wired, claims, raw
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
    local bad = offences_in(claims, wired)
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

-- The wildcard rule is the one that reads a FUNCTION BODY rather than a call
-- site, so it has a failure mode the other rules do not: scoped too tight it
-- silently loses 'all' (the census anchor above catches that), scoped too wide
-- it mints gate ids out of every string comparison in the file -- and THAT is
-- invisible, because an over-collecting census simply stops flagging
-- over-claims. Both directions are pinned here, on synthetic source.
tests['the wildcard rule reads the shared matcher, and only the shared matcher'] = function()
    local src = [[
local function SoakStrArms( sStr, sId )
	if sStr == sId or sStr == 'all' then return true end
	return false
end
function J.SomethingElse( s )
	return s == 'notagateid'
end
]]
    local wired = wired_ids_in(src)
    assert(wired['all'], "the wildcard id 'all' must be collected from the matcher body")
    assert(not wired['notagateid'],
        "a comparison OUTSIDE the matcher must not become a gate id -- an "
        .. 'over-collecting census stops flagging over-claims, silently')
end

tests['a PROMOTED line is exempt even with no gate left'] = function()
    local claims = claims_in(
        "-- PROMOTED (was soak-candidate 'goneid'); no gate, turbo default-on.",
        'synthetic')
    assert(#claims == 1 and claims[1].promoted,
        'PROMOTED is the documented exit and must exempt the line')
end

-- The three controls above prove the EXTRACTORS see what they should. These
-- two prove the VERDICT and the REPORT do -- the half that has had nothing real
-- to chew on since the tree went clean, and the half a widening edit lives in.
tests['a claim naming an unwired id is a violation; the two clean shapes are not'] = function()
    local wired = { realid = true }
    assert(is_violation({ id = 'ghostid', promoted = false }, wired),
        'a comment naming an id nothing wires is exactly the over-claim this '
        .. "file exists for -- arming it arms nothing and the wave reads as "
        .. '"tested, neutral"')
    assert(not is_violation({ id = 'realid', promoted = false }, wired),
        'a genuinely wired id is not drift')
    assert(not is_violation({ id = 'goneid', promoted = true }, wired),
        'PROMOTED is the documented exit from the gated state; a line that says '
        .. 'so is the register working, not drifting')
    -- The near miss that a loosened boundary would swallow: PROMOTED is a
    -- property of the LINE, not of the id, so an unwired id on a line that does
    -- not say it must still be caught.
    assert(is_violation({ id = 'ghostid', promoted = false }, { goneid = true }),
        'exemption is leaking from one claim to another')
end

tests['the report names the offender, and stays silent on the clean ones'] = function()
    local wired = { realid = true }
    local tClaims = {
        { path = 'synthetic.lua', line = 7,  id = 'ghostid', promoted = false,
          text = "-- Gated (turbo + 'ghostid'); inert by default." },
        { path = 'synthetic.lua', line = 11, id = 'realid',  promoted = false,
          text = "-- Gated turbo + soak-candidate 'realid'; inert." },
        { path = 'synthetic.lua', line = 19, id = 'goneid',  promoted = true,
          text = "-- PROMOTED (was soak-candidate 'goneid'); turbo default-on." },
    }
    local bad = offences_in(tClaims, wired)
    assert(#bad == 1, 'the report produced ' .. #bad .. ' line(s) for one '
        .. 'over-claim among two clean claims; it must produce exactly one, or '
        .. 'its silence on the real tree says nothing about the real tree')
    assert(bad[1]:find('ghostid', 1, true) and bad[1]:find('synthetic.lua:7', 1, true),
        'the report does not point at the offending line: ' .. bad[1])
    assert(not bad[1]:find('realid', 1, true), 'the report names a wired id too')
    assert(#offences_in({}, wired) == 0, 'an empty claim set reports something')
end

-- === The comment strip (2026-09-03) ====================================
--
-- Five synthetic controls for the mechanism, then one reading of the real tree.
-- The mechanism controls are what survive a reworded comment; the tree reading
-- is what proves the strip is not a no-op HERE, which no synthetic can say.
tests['a call form that exists only inside a comment is not wired'] = function()
    local wired = wired_ids_in("-- see J.IsSoakCandidate('ghostid') for why\n")
    assert(not wired['ghostid'],
        "a comment that QUOTES a call minted a gate id -- this is the defect: "
        .. 'the register and the thing being registered were the same text')
    local claims = claims_in("-- Gated (turbo + 'ghostid'); inert by default.",
        'synthetic')
    assert(is_violation(claims[1], wired),
        'and with the id no longer falsely wired, the over-claim it was '
        .. 'masking must now be a violation')
end

tests['a real call next to a comment about a different id is still wired'] = function()
    local wired = wired_ids_in(
        "-- the 'pullcad' trap: IsSoakCandidate('ghostid') would freeze FALSE\n"
        .. "if J.IsSoakCandidate('realid') then return true end\n")
    assert(wired['realid'], 'the strip ate a real call site')
    assert(not wired['ghostid'], 'the strip left the commented call site behind')
end

tests['a -- inside a string literal does not blank the rest of the line'] = function()
    local wired = wired_ids_in(
        "local s = '-- not a comment' ; J.IsSoakCandidate('realid')\n")
    assert(wired['realid'],
        "a `--` inside a STRING was read as a comment start, so everything "
        .. 'after it on that line stopped being code -- strings are why this '
        .. 'cannot be a `gsub` on `--.-\\n`')
end

-- The long comment here spans LINES on purpose. A strip that has lost its
-- long-comment branch degrades to the line-comment branch, which blanks a
-- one-line `--[==[ ... ]==]` correctly and hides the regression completely --
-- and bots/ has 80 long comments, most of them multi-line.
tests['long comments are stripped and long strings are kept'] = function()
    local wired = wired_ids_in(
        "--[==[ a long comment\n"
        .. "   J.IsSoakCandidate('ghostid')\n"
        .. "]==]\n"
        .. "local s = [[ J.IsSoakCandidate('stringid') ]]\n"
        .. "J.IsSoakCandidate('realid')\n")
    assert(not wired['ghostid'], 'a multi-line --[==[ ]==] comment was not stripped')
    assert(wired['stringid'],
        'a long STRING was stripped; strings are code and hold the ids')
    assert(wired['realid'], 'the strip lost the call after a long bracket')
end

-- What the wildcard rule downstream actually depends on is that stripping a
-- comment does not change the LINE STRUCTURE around it: its pattern is anchored
-- on `\nend`. So the comment below sits between the matcher body and its `end`,
-- which is where a strip that swallows one newline too many shows up.
--
-- (Byte offsets are preserved as well, but nothing in this file reads one, so
-- that half is a property rather than a tested claim -- see the note in
-- tools/agent/mutstand_gatecomment.sh about the mutant that was dropped for it.)
tests['stripping a comment does not disturb the lines around it'] = function()
    local src = [[
-- a comment ahead of the matcher
local function SoakStrArms( sStr, sId )
	if sStr == sId or sStr == 'all' then return true end
	-- a comment between the body and its end
end
]]
    assert(wired_ids_in(src)['all'],
        "the wildcard id 'all' was lost -- the strip changed the newline "
        .. 'structure, and `SoakStrArms%b()(.-)\\nend` no longer matches')
end

-- The domain price, read on the real tree through the one extractor, both ways.
-- Double-sided on purpose (0CKTWIN's rule): MORE means somebody wrote a new
-- comment that quotes a call form -- fine to do, but the census must know;
-- FEWER means the two demonstrations below were reworded away, and this file
-- then rests on synthetic evidence alone. Either way it is a deliberate edit
-- to this list, never drift.
--
-- Anchored by ID, not by line number: 0B3FRAME's rule after one commit moved
-- two separate censuses' line anchors in the same afternoon.
tests['the comment strip removes exactly the two known comment-only ids'] = function()
    local code, _, raw = census()
    local only, n = {}, 0
    for id in pairs(raw) do
        if not code[id] then only[#only + 1] = id; n = n + 1 end
    end
    table.sort(only)
    local got = table.concat(only, ',')
    assert(got == 'X,pullbeat', string.format(
        "comment-only wired ids are now {%s}; expected {X,pullbeat}.\n"
        .. "  'pullbeat' was PROMOTED 2026-08-23 and is wired by nothing -- it "
        .. 'sat in the wired set because mode_roam_generic.lua teaches the '
        .. "`pullcad` trap by quoting the frozen conjunction.\n"
        .. "  'X' is the METAVARIABLE in jmz_func.lua's statement of that same "
        .. 'trap.\n'
        .. '  Both are the register being built out of the text it audits. If '
        .. 'you meant to change this, change this list too.', got))
    assert(n == 2, 'count and set disagree: ' .. n)
    -- And the half that matters: without the strip, a claim on either of these
    -- is invisible. With it, it is a violation.
    assert(not code['pullbeat'] and raw['pullbeat'],
        "'pullbeat' must be raw-wired and code-unwired, or this file's reason "
        .. 'for the strip no longer holds on this tree')
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
