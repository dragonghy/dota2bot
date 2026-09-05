-- [census + register] `local nManaCost = ability:GetManaCost()` inside a
-- shipped Consider function that nothing in that function ever reads.
--
-- WHY THIS EXISTS (hero stream, 2026-09-05, backlog -75).
-- -------------------------------------------------------
-- backlog -75 registered nine of these across the focus five and asked one
-- question before any of them is touched: "what did this line originally want
-- to read -- how do the SIBLING branches in the same function use it?"  This
-- file is that question answered, frozen so the answer cannot quietly rot.
--
-- THE ANSWER IS NOT ONE ANSWER.  It is five, and they do not generalise to each
-- other.  That is the same shape backlog -93 named on the KV keys ("the
-- remainder is not a queue") and -85 on the unread numeric locals, and it is
-- the reason this file registers rather than enforces a zero: seven of the nine
-- are DISPOSITIONS, not work.
--
-- FIRST, THE FACT THAT COLLAPSES THE OBVIOUS READING.  All nine sit under an
-- `IsFullyCastable()` early return in their own function.  IsFullyCastable is
-- already "off cooldown AND levelled AND mana >= cost", so by the time the
-- binding is taken, AFFORDABILITY IS ANSWERED UPSTREAM.  The binding was never
-- the "can I pay for this" read that its name suggests.
--
-- What the two LIVE idioms in this tree ask is a different question -- a
-- RESERVE question, about what is left after paying:
--
--     J.GetManaAfter( cost ) > 0.3            -- (mana - cost)/maxmana
--     J.IsAllowedToSpam( bot, cost )          -- same ratio vs fKeepManaPercent
--
-- So "wire the dead binding to the live idiom" is not a repair of a dropped
-- read.  It is a proposal to add a per-cast mana RESERVE to a decision that
-- does not have one.  Whether that is right depends entirely on the site, and
-- the five classes below are exactly that dependency, each discriminated by
-- something measurable in the source rather than by taste:
--
--   甲 A COMPETING RESERVE IS ALREADY THERE (CM ConsiderQImpl, CM ConsiderW,
--      Zeus ConsiderW2).  Each gates on `bot:GetMana() > nKeepMana` -- an
--      absolute, hero-level floor that does not consult the cost.  Wiring
--      GetManaAfter here does not fill a gap; it stacks a second, cost-aware
--      reserve on top of an existing one.  Two reserves is a design question
--      with a measurable cost, not a cleanup.
--
--   乙 THE RESERVE IS THERE AND FROZEN OFF (Zeus ConsiderW).  Its only reserve
--      is `J.ShouldConserveManaInLane`, whose first line is
--      `if not J.IsLaneFixOn('mana') then return false end` -- so on shipped
--      trunk, where no candidate is armed, this function has NO reserve at all.
--      And the domain is precisely `lanefix`, the bundle the final gate
--      REJECTED TWICE (AGENTS.md).  This site looks like class 戊 in a game and
--      like class 甲 in the source; it is neither, and the difference is only
--      visible if you follow the helper into jmz_func.
--
--   丙 IT IS AN ULTIMATE (Zeus ConsiderR, Axe ConsiderR).  Withholding an ult
--      to keep mana for a lesser spell is the reserve pointing backwards.  Zeus
--      already carries the lever that points the RIGHT way here --
--      `X.zuus_ShouldSaveManaForUlt`, which reserves mana FOR the ult and is
--      one of the few LIVE GetManaCost bindings in the focus five.
--
--   丁 THE ABILITY RESTORES MANA (Lion ConsiderE).  Mana Drain: the function
--      reads `mana_per_second` and does its own mana arithmetic.
--      `GetManaAfter( cost ) > 0.3` would decline to drain exactly when mana is
--      low -- the sign is inverted.  This is the same shape backlog -89 named
--      on Zeus ("every kill predicate deserves the question 'where does its
--      ceiling come from'"): an idiom copied across a sign change.
--
--   戊 NOTHING (Lion ConsiderW / Hex, Zeus ConsiderE / Heavenly Jump).  No
--      reserve predicate of any kind, not an ult, does not restore mana.  These
--      TWO -- of nine -- are the only sites where the dead binding names a gap
--      that the live idiom would fill in the same direction.
--
-- SO THE DELIVERABLE OF backlog -75 IS A NARROWING: nine sites, at most two
-- levers, and the two are a gated turbo candidate + a real frame away, which is
-- a different work unit (behaviour change; -75's own discipline).  Wiring the
-- other seven would be seven individually-arguable edits landing together --
-- the `lanefix` shape, and that bundle was rejected twice.
--
-- HOW IT MEASURES.  Over comment-stripped source, for every column-0
-- `function ... end` span: a line matching `local <ident> = <obj>:GetManaCost()`
-- is DEAD iff `<ident>` appears on no other line of the span.  Every ambiguity
-- resolves toward LIVE (a use in a nested closure counts, a mention inside a
-- string counts, `nManaCostX` does not count as a use of `nManaCost`).  The
-- reading therefore UNDERSTATES the class: a site named here is dead; a site
-- not named is not thereby proven live.
--
-- LIMITS.  (1) Only column-0 `function ... end` pairs are spans; a nested
-- function is scanned as part of its parent, which merges scopes and can only
-- move a site from dead to live.  (2) Only the `local X = <obj>:GetManaCost()`
-- shape -- a cost passed straight into a call, or stored on a table field, is
-- out of the domain by construction.  (3) The class discriminators are
-- SOURCE-SHAPE facts (does the span mention `nKeepMana`, is the receiver named
-- `abilityR`, ...), not semantics; they are pinned so that a site changing
-- class has to say so, not so that they prove the classification.  (4) Inherited
-- from lua_source_scan.strip_line_comment: long comments are not tracked.
--
-- WHY THE FOCUS FIVE ARE A REGISTER AND THE TREE IS ONLY RATCHETED.  Removing
-- an unread local is a provable no-op, and -85 did exactly that for unread
-- NUMBER literals -- because those were false premises (a 1600-unit Zeus ult
-- "cast range" that never existed).  These are not false premises: each holds a
-- true cost that nothing consumes.  Deleting them would erase the only marker
-- of where a reserve policy is absent, so they stay and are registered instead.
-- The tree-wide ceiling is `<=` and MONOTONE -- down is the point, up names the
-- new site.  It is deliberately not `==`; that is the shape GH #457 repaired.

package.path = 'tests/?.lua;' .. package.path

local scan = require('lua_source_scan')

local FOCUS = {
    'bots/BotLib/hero_axe.lua',
    'bots/BotLib/hero_zuus.lua',
    'bots/BotLib/hero_skeleton_king.lua',
    'bots/BotLib/hero_lion.lua',
    'bots/BotLib/hero_crystal_maiden.lua',
}

-- Measured 2026-09-05 on the tree that added this file: 275 files, 2593 column-0
-- spans, 189 GetManaCost bindings, of which 82 dead / 107 live.  RATCHET.
local TREE_CEILING = 82

-- Supply floors.  A ceiling assertion alone cannot tell "nothing is broken"
-- from "the scanner matched nothing" -- the aetherlens lesson (hero
-- 2026-09-03), whose first parser read ZERO tree-wide while its `<=` passed in
-- silence.  Floors sit well below the measured values so ordinary churn does
-- not trip them and a parser that stops matching does.
local MIN_SPANS      = 2000
local MIN_LIVE       = 80
local MIN_FOCUS_LIVE = 4

-- The nine, with the discriminator that puts each in its class.  `tags` are
-- substrings that MUST appear somewhere in the enclosing span; `absent` must
-- appear nowhere in it.
local RESERVE_IDIOMS = {
    'nKeepMana', 'GetManaAfter', 'IsAllowedToSpam', 'ShouldConserveManaInLane',
}

local REGISTER = {
    { path = 'bots/BotLib/hero_crystal_maiden.lua', fn = 'X.ConsiderQImpl', recv = 'abilityQ',
      class = '甲', tags = { 'nKeepMana' } },
    { path = 'bots/BotLib/hero_crystal_maiden.lua', fn = 'X.ConsiderW', recv = 'abilityW',
      class = '甲', tags = { 'nKeepMana' } },
    { path = 'bots/BotLib/hero_zuus.lua', fn = 'X.ConsiderW2', recv = 'abilityW',
      class = '甲', tags = { 'nKeepMana' } },
    { path = 'bots/BotLib/hero_zuus.lua', fn = 'X.ConsiderW', recv = 'abilityW',
      class = '乙', tags = { 'ShouldConserveManaInLane' } },
    { path = 'bots/BotLib/hero_zuus.lua', fn = 'X.ConsiderR', recv = 'abilityR',
      class = '丙', absent = RESERVE_IDIOMS },
    { path = 'bots/BotLib/hero_axe.lua', fn = 'X.ConsiderR', recv = 'abilityR',
      class = '丙', absent = RESERVE_IDIOMS },
    { path = 'bots/BotLib/hero_lion.lua', fn = 'X.ConsiderE', recv = 'abilityE',
      class = '丁', tags = { 'mana_per_second' }, absent = RESERVE_IDIOMS },
    { path = 'bots/BotLib/hero_lion.lua', fn = 'X.ConsiderW', recv = 'abilityW',
      class = '戊', absent = RESERVE_IDIOMS },
    { path = 'bots/BotLib/hero_zuus.lua', fn = 'X.ConsiderE', recv = 'abilityE',
      class = '戊', absent = RESERVE_IDIOMS },
}

--- Every `local <ident> = <recv>:GetManaCost()` site in `path`, tagged dead or
--- live, each carrying the text of its enclosing column-0 function span.
local function sites(path)
    local lines = scan.stripped_lines(path)
    local out, spans = {}, 0
    local i = 1
    while i <= #lines do
        local fname = lines[i]:match('^function%s+([%a_][%w_%.:]*)%s*%(')
        if fname ~= nil then
            spans = spans + 1
            local j = i + 1
            while j <= #lines and not lines[j]:match('^end%f[%W]') do j = j + 1 end
            local last = math.min(j, #lines)
            for k = i, last do
                local ident, recv = lines[k]:match(
                    '^%s*local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*:%s*GetManaCost%s*%(%s*%)%s*$')
                if ident ~= nil then
                    local used = false
                    for m = i, last do
                        if m ~= k and lines[m]:find('%f[%w_]' .. ident .. '%f[^%w_]') then
                            used = true
                            break
                        end
                    end
                    local body = {}
                    for m = i, last do body[#body + 1] = lines[m] end
                    out[#out + 1] = {
                        path = path, line = k, ident = ident, recv = recv, fn = fname,
                        dead = not used, body = table.concat(body, '\n'),
                    }
                end
            end
            i = j
        end
        i = i + 1
    end
    return out, spans
end

local function sweep(paths)
    local dead, live, spans = {}, 0, 0
    for _, p in ipairs(paths) do
        local found, n = sites(p)
        spans = spans + n
        for _, s in ipairs(found) do
            if s.dead then dead[#dead + 1] = s else live = live + 1 end
        end
    end
    return dead, live, spans
end

local function key(path, fn)
    return path .. '::' .. fn
end

local function render(dead)
    local parts = {}
    for _, s in ipairs(dead) do
        parts[#parts + 1] = string.format('%s:%d %s (%s = %s:GetManaCost())',
            s.path, s.line, s.fn, s.ident, s.recv)
    end
    return table.concat(parts, '\n  ')
end

local tests = {}

tests['[register] the focus-five dead set is exactly the nine registered sites'] = function()
    local dead, live, spans = sweep(FOCUS)
    assert(spans >= 45,
        'supply: only ' .. spans .. ' function spans across the focus five -- the '
        .. 'scanner stopped matching, nothing below is a clean reading')
    assert(live >= MIN_FOCUS_LIVE,
        'supply: only ' .. live .. ' LIVE GetManaCost bindings across the focus five, '
        .. 'floor ' .. MIN_FOCUS_LIVE .. ' -- use-detection has broken open, and a '
        .. 'set that matched the register by accident would still pass')

    local want, got = {}, {}
    for _, r in ipairs(REGISTER) do want[key(r.path, r.fn)] = r end
    for _, s in ipairs(dead) do got[key(s.path, s.fn)] = s end

    local missing, extra = {}, {}
    for k in pairs(want) do if got[k] == nil then missing[#missing + 1] = k end end
    for k in pairs(got) do if want[k] == nil then extra[#extra + 1] = k end end
    table.sort(missing)
    table.sort(extra)

    assert(#extra == 0,
        'a focus-five function grew a NEW unread GetManaCost binding:\n  '
        .. table.concat(extra, '\n  ')
        .. '\nClassify it (see this file\'s header) before wiring it -- the nine '
        .. 'registered sites fall into FIVE classes and only two of them are levers.')
    assert(#missing == 0,
        'a registered site is gone from the dead set:\n  ' .. table.concat(missing, '\n  ')
        .. '\nIf it was WIRED, that is a behaviour change and it needs a gated turbo '
        .. 'candidate + a real frame (backlog -75); update this register in the same '
        .. 'change and say which class it left.  If it was DELETED, say why the marker '
        .. 'was worth less than the absence it recorded.')
end

tests['[structure] every registered site sits under an IsFullyCastable early return'] = function()
    -- This is the load-bearing fact of the whole file: affordability is already
    -- answered upstream, so none of the nine was ever the "can I pay" read its
    -- name suggests.  If this ever goes red, the reserve-vs-affordability
    -- framing above stops holding for that site and the class must be re-derived.
    local dead = sweep(FOCUS)
    for _, s in ipairs(dead) do
        assert(s.body:find('IsFullyCastable', 1, true) ~= nil,
            s.path .. ':' .. s.line .. ' (' .. s.fn .. ') no longer gates on '
            .. 'IsFullyCastable.  Affordability is no longer answered upstream here, '
            .. 'so this site may genuinely be a dropped AFFORDABILITY read rather than '
            .. 'a missing reserve -- re-derive its class instead of updating the tags.')
    end
end

tests['[class] each registered site still carries the discriminator of its class'] = function()
    local dead = sweep(FOCUS)
    local got = {}
    for _, s in ipairs(dead) do got[key(s.path, s.fn)] = s end

    for _, r in ipairs(REGISTER) do
        local s = got[key(r.path, r.fn)]
        assert(s ~= nil, 'register/dead-set mismatch for ' .. key(r.path, r.fn)
            .. ' -- the section above should have caught this first')
        for _, t in ipairs(r.tags or {}) do
            assert(s.body:find(t, 1, true) ~= nil, string.format(
                '%s:%d (%s) is registered class %s on the strength of `%s`, which is no '
                .. 'longer in the function.  Its class changed; re-derive it.',
                s.path, s.line, s.fn, r.class, t))
        end
        for _, t in ipairs(r.absent or {}) do
            assert(s.body:find(t, 1, true) == nil, string.format(
                '%s:%d (%s) is registered class %s -- "no reserve predicate in this '
                .. 'function" -- but `%s` now appears in it.\n'
                .. 'THIS RED IS THE POINT, not an obstacle: for the two class-戊 sites '
                .. '(lion ConsiderW, zuus ConsiderE) it means someone wired the reserve '
                .. 'this backlog item was about.  Move the site out of class 戊 here and '
                .. 'record the gated candidate id that carries it.  Do NOT delete the '
                .. 'assertion to get green.',
                s.path, s.line, s.fn, r.class, t))
        end
    end
end

tests['[class 乙] Zeus ConsiderW\'s only reserve is frozen off on shipped trunk'] = function()
    -- The site that looks like class 戊 in a game and class 甲 in the source.
    -- The difference is only visible by following the helper into jmz_func:
    -- ShouldConserveManaInLane's first statement is an IsLaneFixOn('mana')
    -- gate, and no candidate is armed on shipped trunk -- so the reserve this
    -- function appears to carry is constant false in every shipped game, and
    -- its armed domain is `lanefix`, rejected twice at the final gate.
    local body = nil
    for _, s in ipairs(sweep(FOCUS)) do
        if s.path == 'bots/BotLib/hero_zuus.lua' and s.fn == 'X.ConsiderW' then body = s.body end
    end
    assert(body ~= nil, 'hero_zuus.lua X.ConsiderW left the dead set; the section above '
        .. 'should have caught this first')
    assert(body:find('ShouldConserveManaInLane', 1, true) ~= nil,
        'hero_zuus.lua X.ConsiderW no longer calls J.ShouldConserveManaInLane -- it has '
        .. 'left class 乙; re-derive its class')

    local helper = table.concat(scan.stripped_lines('bots/FunLib/jmz_func.lua'), '\n')
    local decl = helper:find('function J.ShouldConserveManaInLane', 1, true)
    assert(decl ~= nil, 'J.ShouldConserveManaInLane is gone from jmz_func.lua; if the '
        .. 'reserve became unconditional, hero_zuus.lua X.ConsiderW moved from class 乙 '
        .. 'to class 甲 and this file must say so')
    local head = helper:sub(decl, decl + 400)
    assert(head:find('IsLaneFixOn', 1, true) ~= nil, string.format(
        'J.ShouldConserveManaInLane no longer opens with an IsLaneFixOn gate.  If that '
        .. 'gate was PROMOTED away the reserve is now live in every Turbo game and Zeus '
        .. 'ConsiderW is class 甲, not 乙 -- update the register and the header rather '
        .. 'than this assertion.  Head read:\n%s', head:sub(1, 200)))
end

tests['[ratchet] the tree-wide dead count does not grow'] = function()
    local dead, live, spans = sweep(scan.bots_files())
    assert(spans >= MIN_SPANS,
        'supply: ' .. spans .. ' function spans tree-wide, floor ' .. MIN_SPANS
        .. ' -- the scanner is not reaching the tree; the ceiling below proves nothing')
    assert(live >= MIN_LIVE,
        'supply: ' .. live .. ' LIVE GetManaCost bindings tree-wide, floor ' .. MIN_LIVE
        .. ' -- same failure, and a shrunken dead set would read as an improvement')
    assert(#dead <= TREE_CEILING,
        'unread GetManaCost bindings tree-wide: ' .. #dead .. ' > ceiling ' .. TREE_CEILING
        .. '.  Someone copied the template again.  The list:\n  ' .. render(dead)
        .. '\nLower the ceiling when you remove some; never raise it, and never make it '
        .. '`==` (GH #457).')
end

tests['[negative control] a binding the code really reads is called live'] = function()
    -- hero_axe.lua X.ConsiderQ takes the same binding and feeds it to
    -- J.IsAllowedToSpam and two J.GetManaAfter comparisons.  If the scanner
    -- ever calls THIS dead, use-detection has broken open and every reading in
    -- this file is worthless -- including the nine.
    local found = sites('bots/BotLib/hero_axe.lua')
    local seen = false
    for _, s in ipairs(found) do
        if s.fn == 'X.ConsiderQ' then
            seen = true
            assert(not s.dead, 'hero_axe.lua:' .. s.line .. ' read as DEAD, but '
                .. 'X.ConsiderQ consumes it three times -- use-detection is broken')
        end
    end
    assert(seen, 'the control site (hero_axe.lua X.ConsiderQ) is gone; re-anchor this '
        .. 'control on another live binding rather than deleting it')
end

tests['[negative control] the dead branch of the classifier still fires'] = function()
    -- Each per-class assertion above is satisfied by a scanner that finds
    -- nothing at all.  The 82 registered tree-wide sites are the standing proof
    -- that the dead branch fires; if this ever legitimately reaches zero,
    -- replace it with a synthetic fixture rather than deleting it.
    local dead = sweep(scan.bots_files())
    assert(#dead > 0,
        'the tree-wide sweep found ZERO dead sites.  Either 82 sites were fixed in one '
        .. 'round (then lower TREE_CEILING and re-anchor this control) or the dead '
        .. 'branch no longer fires -- and in that case every reading above is vacuous.')
end

tests['[shape] a prefix is not a use, and the receiver is captured'] = function()
    local lines = {
        'function X.A()',
        '\tlocal nManaCost = abilityR:GetManaCost()',
        '\tlocal nManaCostX = 1',
        '\treturn nManaCostX',
        'end',
        'function X.B()',
        '\tlocal nCost = abilityQ:GetManaCost()',
        '\treturn nCost',
        'end',
    }
    local tmp = os.tmpname()
    local fh = assert(io.open(tmp, 'w'))
    fh:write(table.concat(lines, '\n') .. '\n')
    fh:close()
    local found = sites(tmp)
    os.remove(tmp)
    local by = {}
    for _, s in ipairs(found) do by[s.fn] = s end
    assert(by['X.A'] ~= nil and by['X.A'].dead,
        'nManaCost must be DEAD: only nManaCostX is read')
    assert(by['X.A'].recv == 'abilityR',
        'the receiver must be captured (class 丙 is discriminated on it); got '
        .. tostring(by['X.A'].recv))
    assert(by['X.B'] ~= nil and not by['X.B'].dead,
        'nCost must be LIVE: the return reads it')
end

return tests
