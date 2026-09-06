-- A turbo scaling written with the `a and b or c` ternary idiom is a NO-OP
-- whenever `b` is a boolean -- and this repo had five of them (one left).
--
-- THE SHAPE.  Lua has no ternary operator; the idiom is `cond and x or y`, and
-- it is correct only while `x` can never be false or nil.  A turbo constant
-- written as
--
--     J.IsModeTurbo() and DotaTime() < 18 * 60 or DotaTime() < 25 * 60
--
-- puts a BOOLEAN in the `x` position, and `and` binds tighter than `or`, so it
-- parses as
--
--     (J.IsModeTurbo() and DotaTime() < 18 * 60) or (DotaTime() < 25 * 60)
--
-- Because 18*60 < 25*60 the first disjunct IMPLIES the second: when it is true
-- the second is true anyway, and when it is false the second decides alone.
-- The expression is therefore literally `DotaTime() < 25 * 60` in every mode.
-- The turbo constant is unreachable -- not "approximately right", not "rarely
-- reached": it decides nothing, ever, and no counter anywhere reports that.
--
-- This is the disjunctive twin of GH #160 (mode_farm_generic's second "前期谨慎
-- 冲塔" block, dominated by the first) and the same charter rule applies: the
-- conclusion is an ARITHMETIC RELATION between two constants, so it is asserted
-- as arithmetic, not sampled on frames.  A frame cannot show it -- the two
-- branches agree on every frame the corpus holds (see the corpus section at the
-- bottom); it takes the relation `turboBound < normalBound` to see it at all.
--
-- WHAT THIS FILE PINS
--   1. the general dominance, on a dense pure-model grid, in BOTH directions
--      (swap the constants and the equivalence must BREAK -- otherwise the grid
--      would be proving a tautology instead of a relation);
--   2. that mode_farm_generic's `bEarlyGame` no longer carries the shape, that
--      its gate-closed value is the SHIPPED value in both modes, and that the
--      armed value is a strict SUBSET of it (charter: one lever, and it can
--      only fire less);
--   3. a repo-wide RATCHET over bots/: the set of surviving occurrences must be
--      exactly the allowlist below.  A new one turns this file red on the day
--      it is written; a fixed one has to be deleted from the list, so the list
--      can only shrink.
--
-- WHAT IT DOES NOT CLAIM.  It does not say 18*60 is the right turbo bound (that
-- is the clock-constant axis, GH #157, and the reason the fix ships gated).  It
-- does not touch what is left on the allowlist: one orphan with no callers.
-- (Alchemist's four were claimed by the hero desk on 2026-08-24, GH #165, and
-- are asserted in tests/test_alchemist_rage_objective_clock.lua.)  The verdict
-- on the survivor is recorded below as data for whoever claims it.
--
-- LIMITS, stated so nobody over-reads the ratchet.
--   * The scan is LINE-BASED.  An occurrence split across two source lines is
--     invisible to it.  All five known ones are single-line; a future one need
--     not be.
--   * It only recognises the shape when a relational operator sits between
--     `IsModeTurbo()` and the ` or `.  That is exactly the dangerous case (a
--     boolean in the `x` slot); `IsModeTurbo() and 8 * 60 or 10 * 60` is a
--     NUMBER in the `x` slot and is correct, so it is deliberately not flagged.
--   * A second disjunct that re-tests turbo (`... or (not J.IsModeTurbo() and
--     ...)`, mode_farm_generic's horn offset) is the CORRECT hand-written form
--     and is deliberately not flagged either.  Both exclusions are asserted
--     below rather than assumed, so a change to the matcher that starts
--     swallowing them shows up here.

package.path = 'tests/?.lua;' .. package.path

local tests = {}

local FARM = 'bots/mode_farm_generic.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a'); fh:close()
    return s
end

-- ---------------------------------------------------------------------------
-- The matcher.  One place, used by the ratchet AND by the exclusion tests.
-- ---------------------------------------------------------------------------

--- Does this single source line carry the dangerous idiom?
--- Returns nil, or the segment between `IsModeTurbo()` and the ` or `.
local function turbo_ternary_segment(line)
    local at = line:find('IsModeTurbo%(%)')
    if at == nil then return nil end
    local rest = line:sub(at)
    local seg, tail = rest:match('^IsModeTurbo%(%)(.-)%f[%w]or%f[%W](.*)$')
    if seg == nil then return nil end
    -- `x` must be a BOOLEAN, i.e. a comparison, for the idiom to misfire.
    if not seg:find('[<>=~]=?') then return nil end
    if not seg:find('%f[%w]and%f[%W]') then return nil end
    -- A second disjunct that re-tests turbo is the correct hand-written form.
    if tail:find('IsModeTurbo') then return nil end
    return seg
end

local function scan_bots()
    local hits = {}
-- Farm-only files are skipped: `bots/Customize/` holds two gitignored,
-- TRANSIENT switch files that every gate test in this suite creates and
-- deletes, so listing one and then reading it is a race whose red names a
-- file this test has no business reading (GH #365 §2 / #438; hero backlog
-- -79 measured the population at 18 walks in 18 files).  The rule lives in
-- tests/lua_source_scan.lua and is referenced, never copied -- the path
-- literal is load-bearing text and a second copy is the defect.
    for _, path in ipairs(require('lua_source_scan').bots_files()) do
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            -- commented-out code is not shipped behaviour
            local code = line:match('^%s*%-%-') and '' or line
            if turbo_ternary_segment(code) ~= nil then
                hits[#hits + 1] = { file = path, line = n, text = line:match('^%s*(.-)%s*$') }
            end
        end
    end
    return hits
end

-- The ones that survive, each with the pair of constants that makes it
-- dominated.  `turbo` is the bound the author meant; `normal` is the bound the
-- expression actually uses in every mode.
-- ORDER IS LOAD-BEARING: rows are paired to scan hits positionally, and the
-- scan walks `find bots -name "*.lua" | sort`.
--
-- 2026-08-24, hero desk, GH #165: the four Alchemist rows (hero_alchemist.lua
-- 15/30 and 16/32, and their verbatim rubick_hero copies) are GONE -- both
-- files now route those clauses through X.GetRageObjectiveClock, whose armed
-- branch takes a math.min so the narrowing is structural.  The list shrank
-- from five to one, which is the only direction it is allowed to move.
local ALLOWED = {
    { file = 'bots/FunLib/aba_site.lua',                turbo = 8,  normal = 12,
      note = 'ORPHAN: ____exports.IsInLaningPhase has zero callers in bots/ or '
          .. 'typescript/ -- every consumer reaches J.IsInLaningPhase in '
          .. 'jmz_func, which is written with NUMERIC ternaries and is correct. '
          .. 'Generated from typescript/bots/FunLib/aba_site.ts, so a fix has '
          .. 'to move both files; it buys no behaviour either way.' },
}

-- ---------------------------------------------------------------------------
-- 1. The relation, as arithmetic.
-- ---------------------------------------------------------------------------

--- The shipped idiom, evaluated exactly as Lua parses it.
local function idiom(bTurbo, t, nTurboBound, nNormalBound)
    return bTurbo and t < nTurboBound or t < nNormalBound
end

--- A dense grid over the interesting range: every 5s from -120 to 40 minutes,
--- plus both bounds and their immediate neighbours.
local function grid(a, b)
    local ts = {}
    for t = -120, 40 * 60, 5 do ts[#ts + 1] = t end
    for _, edge in ipairs({ a, b }) do
        for _, d in ipairs({ -0.001, 0, 0.001, -1, 1 }) do ts[#ts + 1] = edge + d end
    end
    return ts
end

tests['[arithmetic] with turboBound < normalBound the idiom IS the normal bound'] = function()
    local a, b = 18 * 60, 25 * 60
    for _, t in ipairs(grid(a, b)) do
        for _, bTurbo in ipairs({ true, false }) do
            local got = idiom(bTurbo, t, a, b)
            local want = t < b
            assert(got == want, ('idiom(turbo=%s, t=%.3f, %d, %d) = %s but `t < %d` = %s '
                .. '-- the dominance this whole file rests on has broken')
                :format(tostring(bTurbo), t, a, b, tostring(got), b, tostring(want)))
        end
    end
end

tests['[arithmetic] the turbo and normal columns are identical at every t'] = function()
    local a, b = 18 * 60, 25 * 60
    for _, t in ipairs(grid(a, b)) do
        assert(idiom(true, t, a, b) == idiom(false, t, a, b),
            ('turbo and non-turbo finally disagree at t=%.3f -- if this is real, '
            .. 'the idiom is no longer dominated and the fix below is the wrong shape')
            :format(t))
    end
end

-- The reverse direction. Without this the two tests above would pass on a grid
-- where NOTHING is dominated -- they would be asserting `x == x`.
tests['[reverse] swap the constants and the equivalence must BREAK'] = function()
    local a, b = 25 * 60, 18 * 60   -- turboBound > normalBound: no longer dominated
    local nDiff = 0
    for _, t in ipairs(grid(a, b)) do
        if idiom(true, t, a, b) ~= idiom(false, t, a, b) then nDiff = nDiff + 1 end
    end
    assert(nDiff > 0, 'with turboBound ABOVE normalBound the two modes still agree '
        .. 'everywhere -- the grid is not exercising the relation at all, so the '
        .. 'passing tests above prove nothing')
    -- and it must break exactly on the band between the two bounds
    assert(idiom(true, 20 * 60, a, b) == true and idiom(false, 20 * 60, a, b) == false,
        'the break is not where the arithmetic says it is (t = 20:00, bounds 25/18)')
end

tests['[reverse] a NUMBER in the x slot makes the same idiom correct'] = function()
    -- why `IsModeTurbo() and 8 * 60 or 10 * 60` is fine and not flagged: the x
    -- operand is a number, so it is never false and the `or` is never reached.
    local function numeric(bTurbo) return bTurbo and 8 * 60 or 10 * 60 end
    assert(numeric(true) == 8 * 60, 'the numeric ternary stopped selecting the turbo arm')
    assert(numeric(false) == 10 * 60, 'the numeric ternary stopped selecting the normal arm')
end

-- ---------------------------------------------------------------------------
-- 2. The shipped fix in mode_farm_generic.
-- ---------------------------------------------------------------------------

local WINDOW = (function()
    local src = read_file(FARM)
    local at = assert(src:find('%[tbearly%]'),
        'the [tbearly] anchor is gone from ' .. FARM)
    local w = src:sub(at, at + 2400)
    -- Self-witnessing window (charter 0LN2): fail with the truth, not with
    -- "the clause disappeared" when it is merely past the window.
    assert(w:find('bEarlyGame'), 'the source window from [tbearly] no longer '
        .. 'reaches the bEarlyGame assignment -- widen it; the block may be intact')
    return w
end)()

local SHIPPED_BOUND, ARMED_BOUND = (function()
    local shipped = assert(WINDOW:match('local nEarlyClock%s*=%s*(%d+)%s*%*%s*60'),
        'the gate-closed bound is no longer a literal `local nEarlyClock = N * 60`')
    local armed = assert(WINDOW:match("IsSoakCandidate%('tbearly'%).-nEarlyClock%s*=%s*(%d+)%s*%*%s*60"),
        'the armed bound is no longer a literal `nEarlyClock = N * 60` inside the '
        .. "IsSoakCandidate('tbearly') branch")
    return tonumber(shipped) * 60, tonumber(armed) * 60
end)()

tests['[fix] the dangerous idiom is gone from the bEarlyGame clause'] = function()
    for line in WINDOW:gmatch('[^\n]+') do
        local code = line:match('^%s*%-%-') and '' or line
        assert(turbo_ternary_segment(code) == nil,
            'the [tbearly] block grew the idiom back: ' .. line)
    end
    assert(WINDOW:find('local bEarlyGame%s*=%s*DotaTime%(%)%s*<%s*nEarlyClock'),
        'bEarlyGame no longer reads the single resolved bound -- if it was '
        .. 'rewritten, re-derive the subset claim below before trusting it')
end

tests['[fix] gate closed reproduces the SHIPPED bound, in both modes'] = function()
    -- What shipped, for every t, was `t < 25*60` regardless of mode (test 1).
    -- The gate-closed rewrite must agree with that everywhere.
    local a, b = 18 * 60, 25 * 60
    assert(SHIPPED_BOUND == b, ('the gate-closed bound is now %d, not the %d the '
        .. 'shipped idiom collapsed to -- this is no longer a no-op change')
        :format(SHIPPED_BOUND, b))
    for _, t in ipairs(grid(a, b)) do
        for _, bTurbo in ipairs({ true, false }) do
            assert((t < SHIPPED_BOUND) == idiom(bTurbo, t, a, b),
                ('gate-closed differs from the shipped idiom at t=%.3f turbo=%s')
                :format(t, tostring(bTurbo)))
        end
    end
end

tests['[fix] armed is a strict SUBSET, and exactly one lever moves'] = function()
    assert(ARMED_BOUND < SHIPPED_BOUND, ('armed bound %d is not below the shipped '
        .. '%d -- the fix would let this clause fire MORE, which is a different '
        .. 'lever with a different risk'):format(ARMED_BOUND, SHIPPED_BOUND))
    local nMoved = 0
    for _, t in ipairs(grid(ARMED_BOUND, SHIPPED_BOUND)) do
        local factory, armed = t < SHIPPED_BOUND, t < ARMED_BOUND
        if factory ~= armed then
            nMoved = nMoved + 1
            assert(factory == true and armed == false,
                ('at t=%.3f armed is TRUE where factory is FALSE -- not a subset')
                :format(t))
            assert(t >= ARMED_BOUND and t < SHIPPED_BOUND,
                ('a frame outside [%d, %d) moved: t=%.3f')
                :format(ARMED_BOUND, SHIPPED_BOUND, t))
        end
    end
    assert(nMoved > 0, 'armed and factory agree at every t on the grid -- the '
        .. 'armed bound has no teeth at all and the gate is a no-op')
end

tests['[fix] the gate is turbo-only and rides one soak id'] = function()
    assert(WINDOW:find("J%.IsSoakCandidate%('tbearly'%)%s*and%s*J%.IsModeTurbo%(%)")
        or WINDOW:find("J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%('tbearly'%)"),
        'the [tbearly] gate no longer conjoins IsSoakCandidate with IsModeTurbo '
        .. '-- a clock lever that can fire outside turbo is out of scope by charter')
    local _, n = WINDOW:gsub('IsSoakCandidate%(', '')
    assert(n == 1, ('the [tbearly] window now names %d soak candidates; one '
        .. 'lever per change'):format(n))
end

-- ---------------------------------------------------------------------------
-- 3. The repo-wide ratchet.
-- ---------------------------------------------------------------------------

tests['[ratchet] bots/ carries exactly the allowlisted occurrences'] = function()
    local hits = scan_bots()
    assert(#hits == #ALLOWED, ('bots/ now carries %d turbo-ternary occurrence(s), '
        .. 'the allowlist has %d.\nfound:\n%s\nA NEW one is a turbo scaling that '
        .. 'silently does nothing -- fix it or add it to ALLOWED with its two '
        .. 'constants. A MISSING one means it was fixed: delete its row.')
        :format(#hits, #ALLOWED, (function()
            local t = {}
            for _, h in ipairs(hits) do
                t[#t + 1] = ('  %s:%d  %s'):format(h.file, h.line, h.text)
            end
            return table.concat(t, '\n')
        end)()))
    for i, h in ipairs(hits) do
        assert(h.file == ALLOWED[i].file, ('occurrence %d is in %s:%d, the '
            .. 'allowlist expects %s'):format(i, h.file, h.line, ALLOWED[i].file))
    end
end

tests['[ratchet] every allowlisted occurrence is still DOMINATED'] = function()
    -- The allowlist is not just "these lines exist"; it records WHY each one is
    -- dead. If somebody swaps the constants the site stops being dead and this
    -- file must not keep calling it a known no-op.
    local hits = scan_bots()
    for i, h in ipairs(hits) do
        local want = ALLOWED[i]
        local a = tonumber(h.text:match('IsModeTurbo%(%).-<%s*(%d+)%s*%*%s*60'))
        local b = tonumber(h.text:match('or%s+DotaTime%(%)%s*<%s*(%d+)%s*%*%s*60'))
        assert(a ~= nil and b ~= nil, ('%s:%d no longer reads two literal `N * 60` '
            .. 'bounds; re-derive it by hand: %s'):format(h.file, h.line, h.text))
        assert(a == want.turbo and b == want.normal,
            ('%s:%d now reads turbo=%d normal=%d, the allowlist recorded %d/%d')
            :format(h.file, h.line, a, b, want.turbo, want.normal))
        assert(a < b, ('%s:%d is NO LONGER dominated (turbo %d >= normal %d) -- '
            .. 'it now decides something, so it is a live behaviour question, '
            .. 'not a known no-op'):format(h.file, h.line, a, b))
    end
end

tests['[reverse] the matcher does not swallow the two correct forms'] = function()
    -- the numeric ternary, the shape most turbo constants in this repo use
    assert(turbo_ternary_segment('local n = J.IsModeTurbo() and 8 * 60 or 10 * 60') == nil,
        'the matcher flags the NUMERIC ternary -- it would demand "fixes" to '
        .. 'every correct turbo constant in the repo')
    assert(turbo_ternary_segment('if DotaTime() < (J.IsModeTurbo() and 5 * 60 or 10 * 60) then') == nil,
        'the matcher flags a numeric ternary that merely sits inside a comparison')
    -- the hand-written two-sided form (mode_farm_generic's horn offset)
    assert(turbo_ternary_segment(
        'if ((J.IsModeTurbo() and DotaTime() > -50) or (not J.IsModeTurbo() and DotaTime() > -75))') == nil,
        'the matcher flags the CORRECT two-sided form, where the second disjunct '
        .. 're-tests turbo')
    -- and it does catch the real thing
    assert(turbo_ternary_segment(
        'local b = (J.IsModeTurbo() and DotaTime() < 18 * 60 or DotaTime() < 25 * 60)') ~= nil,
        'the matcher no longer catches the exact line this file was written about')
end

-- ---------------------------------------------------------------------------
-- 4. Why there is no fixture assertion here.
-- ---------------------------------------------------------------------------

tests['[corpus] no real frame in tests/fixtures can tell armed from factory'] = function()
    local n, tMax, sMax = 0, -math.huge, nil
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for path in p:lines() do
        local t = tonumber(read_file(path):match('time%s*=%s*([%-%d%.]+)'))
        assert(t ~= nil, path .. ' has no `time =` field -- the corpus scan is blind to it')
        n = n + 1
        if t > tMax then tMax, sMax = t, path end
    end
    p:close()
    assert(n > 0, 'no fixtures found -- this assertion is vacuous, do not read it as a pass')
    -- The claim: every fixture sits BELOW the armed bound, so `t < armed` and
    -- `t < shipped` agree on all of them. That is why this file argues from
    -- arithmetic and the gated fix carries no frame pin -- and the day a fixture
    -- lands in [18:00, 25:00) this goes red and says so, which is the moment a
    -- real-frame assertion becomes possible.
    -- ⚠️ FIRED 2026-09-06 (hero, GH #566).  tests/fixtures/f_260905_004847_lion_
    -- drain_bkb.lua sits at t=1266.5, inside [ARMED_BOUND, SHIPPED_BOUND) -- the
    -- first fixture that can tell armed from factory.  THE FRAME PIN THIS FILE
    -- ASKED FOR IS NOW POSSIBLE AND HAS NOT BEEN WRITTEN: the round that landed
    -- the frame was withdrawing a Lion lever, not taking up this one.  So the
    -- arithmetic argument below still stands exactly as it did, and it is still
    -- the ONLY thing standing -- handed off in GH #566 rather than absorbed.
    -- The wire is kept live at the new count, naming the frames, so the next one
    -- is visible too.
    local nInBand, sInBand = 0, {}
    local q = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for path in q:lines() do
        local t = tonumber(read_file(path):match('time%s*=%s*([%-%d%.]+)'))
        if t and t >= ARMED_BOUND and t < SHIPPED_BOUND then
            nInBand = nInBand + 1
            sInBand[#sInBand + 1] = string.format('%s (t=%.1f)', path, t)
        end
    end
    q:close()
    assert(nInBand == 1, ('%d fixture(s) now sit in the band [%d, %d) this change '
        .. 'moves, was 1 as of 2026-09-06: %s. Each one is a real-frame pin this '
        .. 'file could carry and does not.')
        :format(nInBand, ARMED_BOUND, SHIPPED_BOUND, table.concat(sInBand, '; ')))
    assert(tMax < SHIPPED_BOUND, ('%s sits at t=%.1f, at or past the SHIPPED bound '
        .. '%d -- past that both sides agree again and the band argument needs a '
        .. 're-read, not just a bigger count.'):format(sMax, tMax, SHIPPED_BOUND))
end

return tests
