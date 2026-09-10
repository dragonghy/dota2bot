-- [hero] The ring a census recomputes is the BRANCH's ring, term for term.
--
-- WHY THIS FILE EXISTS, AND WHY IT IS NOT ANOTHER CENSUS.  A test that wants to
-- ask "which enemies could this branch reach on this frame" has to recompute
-- the branch's cast ring, because the branch keeps it in a file-local.  Twice
-- running, that recomputation was found to have dropped a term -- always the
-- same term, always found by walking into it one file at a time:
--
--   2026-09-10 (GH #725)  hero_lion.lua X.ConsiderQ's ring is
--                         `abilityQ:GetCastRange() + aetherRange + 20` = 920.
--                         Two Lion censuses spelled it `GetCastRange() + 20`
--                         = 670.  9 of 42 live Lions in this corpus carry the
--                         lens, so it was not theoretical: one census read a
--                         legal 861.99u cast as "outside 670", in a file whose
--                         own comment said it was mirroring "X.ConsiderQ's own
--                         arithmetic".
--   this round            six more sites in four files, found by sweeping
--                         instead of waiting: two Crystal Maiden (X.ConsiderQ
--                         `+ aetherRange + 32`, X.ConsiderW `+ 30 +
--                         aetherRange`) and four Axe (X.ConsiderW
--                         `+ aetherRange`).  All six read 0 on every frame the
--                         corpus holds today -- 0 of 70 live CM and 0 of 40
--                         live Axe carry the item -- so this round moved no
--                         reading.  Both heroes BUY the lens in both of their
--                         buy lists, which is the whole point: the Lion pair
--                         was equally quiet until a late-game frame landed.
--
-- Two instances is a coincidence; eight is a discipline nobody wrote down.  So
-- it is written here as a property that runs, rather than as prose in a charter
-- the next author will not be reading when they type the line.
--
-- ⛔ WHAT THIS FILE DELIBERATELY DOES NOT DO: assert that the set of
-- recomputation sites equals a set someone already read.  That is the shape
-- GH #624 named -- a census whose red is tripped by ANY group adding a call
-- site or a frame, found hours later by whoever opens the repo next, author
-- long gone.  Three of the fifteen files on the gate's known-red list are red
-- for exactly that reason right now, and two of the three are this group's.
-- Every assertion here is either a property of each site it finds, or a
-- direction-safe bound (>=, never ==), so that a correctly-written new mirror
-- and a newly-added frame are both green on the round they land, while a
-- dropped term is red in its own author's push, naming their file and the term.
--
-- ⚠️ WHAT IT CANNOT SEE, stated so a green cannot be read as more than it is:
--   * It is a TEXT check over tests/*.lua.  It knows an expression recomputes a
--     ring and whether an aether term is spelled in it; it cannot tell a real
--     `+ aether_bonus(J)` from a `+ 0` typed in that spot.  The arithmetic
--     itself is proved per-site, in the file doing the mirroring.
--   * It only judges a site whose ABILITY it can resolve (section 2 explains
--     the three shapes it resolves).  Unresolved sites are skipped, not
--     accused -- the alternative is a false accusation on rings like
--     axe_culling_blade's, which genuinely carries no aether term.  Section 2
--     asserts that resolution keeps reaching a useful number of sites, because
--     a resolver that silently stopped resolving would be green and worthless.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local LENS = 'item_aether_lens'

--- Sites that recompute a ring WITHOUT an aether term on purpose.  A reason is
--- required; the reason is checked by a human, not by this file.  The table
--- exists so "deliberate" and "forgotten" stop looking identical.
local EXEMPT = {
    ['tests/test_lion_q_field_engagement.lua'] = {
        pattern = 'nNarrowRing',
        reason = 'the narrow ring is the SUBJECT of that assertion, not a mirror '
              .. 'of the branch: it pins that the 670 census ring and the 920 '
              .. 'branch ring answer the same thing on the four 15-level Lion '
              .. 'frames, which is why GH #725 did not move those readings.',
    },
}

--- Heroes whose corpus frames give a slot -> ability-name map.  Only these can
--- be judged; see the header's second limit.
local SUBJECTS = {
    crystal_maiden = 'npc_dota_hero_crystal_maiden',
    axe            = 'npc_dota_hero_axe',
    lion           = 'npc_dota_hero_lion',
}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Split into lines.  `gmatch('[^\n]*')` yields an EMPTY match between every
--- pair of lines in Lua 5.1, which doubles every line number it reports -- the
--- first draft of this file reported :557 for a line that lives at :286.
local function lines_of(body)
    local t = {}
    for line in (body .. '\n'):gmatch('(.-)\n') do t[#t + 1] = line end
    return t
end

local function ls(glob)
    local t = {}
    local p = assert(io.popen('ls ' .. glob .. ' 2>/dev/null'))
    for l in p:lines() do t[#t + 1] = l end
    p:close()
    table.sort(t)
    return t
end

local function frame_paths()
    local t = {}
    for _, d in ipairs({ 'tests/fixtures/*.lua', 'tests/frames/*.lua' }) do
        for _, p in ipairs(ls(d)) do t[#t + 1] = p end
    end
    return t
end

--- slot -> ability KV name, read off a real frame rather than off a table
--- written here: J.Skill.GetAbilityList is the same reader the hero file uses
--- to bind abilityQ/W/E/R, so this cannot disagree with the source it judges.
local function slot_names(unit)
    local got
    for _, path in ipairs(frame_paths()) do
        if got ~= nil then break end
        pcall(function()
            local J, bot = rf.load(path, unit)
            if bot == nil or not bot:IsAlive() then return end
            local l = J.Skill.GetAbilityList(bot)
            if type(l) == 'table' and l[1] ~= nil then got = l end
        end)
    end
    return got
end

--- For one hero file: which of its abilities have a SHIPPED (ungated) aether
--- term in their cast ring, and which demonstrably do not.
--- @return withTerm (set of ability names), without (set of ability names)
local function hero_ring_terms(hero, names)
    local body = read_file('bots/BotLib/hero_' .. hero .. '.lua')
    local var2slot = {}
    for var, n in body:gmatch('local%s+(ability%w+)%s*=%s*bot:GetAbilityByName%(%s*sAbilityList%[(%d+)%]%s*%)') do
        var2slot[var] = tonumber(n)
    end
    local withTerm, without = {}, {}
    for _, line in ipairs(lines_of(body)) do
        if not line:match('^%s*%-%-') then
            local var = line:match('(ability%w+):GetCastRange%(%s*%)')
            local slot = var and var2slot[var]
            local nm = slot and names[slot]
            if nm ~= nil then
                if line:find('aetherRange') then withTerm[nm] = true else without[nm] = true end
            end
        end
    end
    -- An ability spelled both ways in its own file is ambiguous; judging a
    -- mirror against it would be judging it against a coin flip.
    for nm in pairs(withTerm) do
        if without[nm] then withTerm[nm], without[nm] = nil, true end
    end
    return withTerm, without
end

--- Ring sites in a test file: a GetCastRange() read BOUND TO A LOCAL, i.e. a
--- reach the file computes once and then measures distances against.  String
--- literals are blanked first -- an assert MESSAGE quoting `GetCastRange() +
--- aetherRange + 20` is prose about a ring, not a ring.
---
--- ⭐ WHY THE TEST IS "IS IT BOUND", NOT "DOES IT ADD SOMETHING".  The first
--- draft asked for a `+` after the call, and the mutation stand killed it: drop
--- the aether term from an Axe mirror and the expression becomes a BARE
--- `w:GetCastRange()` with no addition left, so the detector stopped seeing the
--- site at the exact moment it became defective.  That is not a corner case --
--- four of this round's six sites were bare reads, because Axe's branch ring is
--- `GetCastRange() + aetherRange` with no pad to leave behind.  A detector that
--- can only see the defect while it is absent is worse than none: it is green.
---
--- The binding test also draws the line this file needs on the other side.  A
--- raw KV assertion (`assert(abilityW:GetCastRange() == 600, ...)`) is not a
--- ring and must not be made to carry the term; it binds nothing.
--- @return array of { line = n, text = <expression, up to 2 lines joined> }
local function ring_sites(body)
    local raw = lines_of(body)
    local out = {}
    for i, line in ipairs(raw) do
        local code = line:gsub('%b""', '""'):gsub("'[^']*'", "''")
        if not code:match('^%s*%-%-') and code:find('GetCastRange%(%s*%)')
            and code:match('local%s+[%w_]+%s*=') then
            -- The window runs to the end of the enclosing block, capped, because
            -- a ring is often built in two steps: bind the base, then add the
            -- item bonus under an `if`.  tests/test_lion_q_kill_reach.lua's
            -- frame_ring() does exactly that and a two-line window accused it
            -- wrongly.  Widening trades sensitivity for false positives on
            -- purpose: this file is a tripwire, and a tripwire that cries wolf
            -- gets edited away, which costs more than the sensitivity does.
            local parts = { code }
            for k = i + 1, math.min(i + 10, #raw) do
                local nxt = raw[k]:gsub('%b""', '""'):gsub("'[^']*'", "''")
                if nxt:match('^end') or nxt:match('^%s%s?%s?%s?end%s*$') then break end
                parts[#parts + 1] = nxt
            end
            out[#out + 1] = { line = i, text = table.concat(parts, ' ') }
        end
    end
    return out
end

--- The ability a ring site is about, resolved through the three shapes the
--- corpus of tests actually uses:
---   (a) `bot:GetAbilityByName('literal'):GetCastRange()`, inline;
---   (b) `h:GetCastRange()` where `local h = bot:GetAbilityByName(X)` and X is
---       a literal or a file-level constant bound to one;
---   (c) X spelled `sAbilityList[n]`, resolved through the hero the file names
---       in its own SRC constant.
--- @return ability name, or nil when the site cannot be attributed
local function resolve_ability(body, text, names_by_hero, src_hero)
    local consts = {}
    for name, val in body:gmatch("local%s+([%w_]+)%s*=%s*'([%w_]+)'") do consts[name] = val end

    local function from_arg(arg)
        if arg == nil then return nil end
        arg = arg:gsub('^%s*(.-)%s*$', '%1')
        local lit = arg:match("^'([%w_]+)'$") or arg:match('^"([%w_]+)"$')
        if lit ~= nil then return lit end
        if consts[arg] ~= nil then return consts[arg] end
        local slot = arg:match('^sAbilityList%[(%d+)%]$')
        if slot ~= nil and src_hero ~= nil and names_by_hero[src_hero] ~= nil then
            return names_by_hero[src_hero][tonumber(slot)]
        end
        return nil
    end

    local inline = text:match('GetAbilityByName%(([^)]*)%)%s*:GetCastRange')
    if inline ~= nil then return from_arg(inline) end

    local var = text:match('([%w_]+):GetCastRange%(%s*%)')
    if var == nil then return nil end
    local arg = body:match('local%s+' .. var .. '%s*=%s*[%w_]*:?GetAbilityByName%(([^)]*)%)')
    return from_arg(arg)
end

local tests = {}

-- ---------------------------------------------------------------- section 1
tests['[1] source-side ground truth: which abilities ship an aether ring term'] = function()
    local names_by_hero = {}
    for hero, unit in pairs(SUBJECTS) do
        local names = slot_names(unit)
        assert(names ~= nil, string.format(
            'no live %s frame in the corpus answers J.Skill.GetAbilityList, so this '
            .. 'file cannot attribute any %s ring site and section 2 goes quietly '
            .. 'blind on that hero.', unit, hero))
        names_by_hero[hero] = names
    end

    -- Anchors, not an inventory: exactly the abilities whose mirrors GH #725
    -- and this round repaired.  Membership, so a newly-wired hero cannot redden
    -- this file in someone else's push.
    local expect = {
        crystal_maiden = { 'crystal_maiden_crystal_nova', 'crystal_maiden_frostbite' },
        axe            = { 'axe_battle_hunger' },
        lion           = { 'lion_impale' },
    }
    for hero, want in pairs(expect) do
        local withTerm = hero_ring_terms(hero, names_by_hero[hero])
        for _, ab in ipairs(want) do
            assert(withTerm[ab] == true, string.format(
                "hero_%s.lua no longer builds %s's cast ring with an ungated "
                .. 'aetherRange term.  If that is deliberate, the mirrors in tests/ '
                .. 'must lose the term in the same change; if it is not, the ring '
                .. 'just got 225-250 units narrower than the item pays for.',
                hero, ab))
        end
    end

    -- The negative half, and the reason section 2 must resolve per ABILITY
    -- rather than per file: one Axe ring carries the term and one does not.
    local _, without = hero_ring_terms('axe', names_by_hero['axe'])
    assert(without['axe_culling_blade'] == true,
        'X.ConsiderR used to build axe_culling_blade\'s ring as a bare '
        .. 'GetCastRange().  If it now carries the aether term, the culling-blade '
        .. 'mirrors in tests/ are under-stating their ring and section 2 should be '
        .. 'accusing them -- check that it does before editing this line away.')
end

-- ---------------------------------------------------------------- section 2
tests['[2] every resolvable mirror of an aether ring spells the aether term'] = function()
    local names_by_hero = {}
    local withTerm = {}
    for hero, unit in pairs(SUBJECTS) do
        local names = slot_names(unit)
        if names ~= nil then
            names_by_hero[hero] = names
            local w = hero_ring_terms(hero, names)
            for ab in pairs(w) do withTerm[ab] = hero end
        end
    end

    local nSites, nResolved, nJudged, tBad = 0, 0, 0, {}
    for _, path in ipairs(ls('tests/test_*.lua')) do
        if path ~= 'tests/test_cast_ring_mirror_discipline.lua' then
            local body = read_file(path)
            local src_hero = body:match("SRC%s*=?%s*'?bots/BotLib/hero_([%w_]+)%.lua")
                          or body:match('bots/BotLib/hero_([%w_]+)%.lua')
            local ex = EXEMPT[path]
            for _, s in ipairs(ring_sites(body)) do
                nSites = nSites + 1
                local ab = resolve_ability(body, s.text, names_by_hero, src_hero)
                if ab ~= nil then
                    nResolved = nResolved + 1
                    if withTerm[ab] ~= nil then
                        nJudged = nJudged + 1
                        local bOk = s.text:lower():find('aether') ~= nil
                        if not bOk and ex ~= nil and s.text:find(ex.pattern, 1, true) then
                            bOk = true          -- exempt, and the reason is on record
                        end
                        if not bOk then
                            tBad[#tBad + 1] = string.format('%s:%d  (%s)  %s',
                                path, s.line, ab,
                                (s.text:gsub('^%s+', ''):gsub('%s+', ' ')):sub(1, 80))
                        end
                    end
                end
            end
        end
    end

    -- Non-vacuity.  A property test that reaches nothing is green for the wrong
    -- reason, and this one's domain is "whatever the resolver could attribute".
    assert(nJudged >= 6, string.format(
        'this check judged only %d ring site(s) (of %d found, %d resolved) -- there '
        .. 'were 8 when it was written.  Either the mirrors moved to a shape '
        .. 'ring_sites() cannot see or resolve_ability() cannot attribute, in which '
        .. 'case a green here means nothing.', nJudged, nSites, nResolved))

    assert(#tBad == 0, string.format(
        '%d census site(s) recompute a cast ring for an ability whose SHIPPED '
        .. 'branch adds an aether-lens term, without that term:\n    %s\n'
        .. 'The branch ring is `abilityX:GetCastRange() + aetherRange + <pad>`; a '
        .. 'mirror that drops the term under-states its own ring by 225-250 units '
        .. 'and reads legal casts as out of range (GH #725 read an 861.99u cast as '
        .. '"outside 670").  Read the term off the FRAME -- J.IsItemAvailable(\'%s\') '
        .. '-- rather than assuming it is 0, or add the site to EXEMPT with a '
        .. 'reason.', #tBad, table.concat(tBad, '\n    '), LENS))
end

-- ---------------------------------------------------------------- section 3
tests['[3] the corpus half: the term is real, and it is 0 unless the item is held'] = function()
    local nLens, nLive = 0, 0
    for _, path in ipairs(frame_paths()) do
        for _, unit in pairs(SUBJECTS) do
            pcall(function()
                local J, bot = rf.load(path, unit)
                if bot == nil or not bot:IsAlive() then return end
                nLive = nLive + 1
                local item = J.IsItemAvailable(LENS)
                -- The two readers must agree.  J.IsItemAvailable only looks at
                -- slots 0-5; a lens in the BACKPACK grants no cast range and must
                -- not be counted -- and the branch's own producer calls this same
                -- helper, so a mirror that scanned 0-8 instead would over-state
                -- the ring on exactly the frames where it matters.
                local bSlot = false
                for i = 0, 5 do
                    local it = bot:GetItemInSlot(i)
                    if it ~= nil and it:GetName() == LENS then bSlot = true end
                end
                assert(bSlot == (item ~= nil), string.format(
                    '%s / %s: the slot scan and J.IsItemAvailable disagree about the '
                    .. 'lens, so the term a mirror computes would depend on which '
                    .. 'reader it happened to use.', path, unit))
                if item ~= nil then nLens = nLens + 1 end
            end)
        end
    end

    -- Direction-safe on purpose: >=, never ==.  Adding frames is the routine act
    -- that reddens the census files this file refuses to imitate, and a
    -- lens-carrying frame added tomorrow is handled correctly by every mirror
    -- this round fixed -- so its arrival must not be a failure.
    assert(nLive >= 100, 'the corpus lost live focus-hero frames, saw ' .. nLive)
    assert(nLens >= 9, string.format(
        'only %d live focus-hero frame(s) carry an aether lens; there were 9 (all '
        .. 'Lion, of 42 live Lions; 0 of 70 CM and 0 of 40 Axe) when this was '
        .. 'written.  If they went away, section 2 still holds as arithmetic but '
        .. 'nothing in the corpus exercises the non-zero branch of any mirror any '
        .. 'more -- say so in the round report rather than deleting this line.',
        nLens))
end

return tests
