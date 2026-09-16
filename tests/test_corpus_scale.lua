-- The ratchet on the ratchet: tests/corpus_scale.lua itself, plus a detector
-- that goes red when a census re-pins the corpus size the old way.
--
-- WHY BOTH HALVES. GH #106 diagnosed the defect (a fixture landing is a
-- breaking change across N files, because censuses pin the corpus size as an
-- equality) and proposed the repair; GH #127 is the SAME defect happening
-- again five weeks later, with N grown from 5 to 7 and 18 assertions red at
-- once. A helper module alone does not fix that -- it only helps the author who
-- remembers it exists, which is precisely the contract that already failed
-- twice. So section 2 below does not check that anybody used the helper; it
-- checks the thing itself, on every test file in the tree, whether or not its
-- author had heard of any of this.
--
-- THE DETECTOR, AND WHY IT IS NARROW ON PURPOSE. It flags an INTEGER literal,
-- in a non-comment line, compared with `==`, whose value is exactly the number
-- of fixtures in tests/fixtures/ right now. That is deliberately not "any
-- suspicious-looking number": the director's own backlog note (§7, the inline
-- HP literal census) records that a broad regex over these files is more than
-- half prose, and a detector that cries wolf gets whitelisted into silence.
-- Measured on the tree at the time of writing, the wide form (+/- 3 of the
-- corpus size) produced 5 hits of which 3 were false -- a hero's mana of 99 and
-- two float timestamps 101.9 / 103.5. The exact form produces the two real ones
-- and nothing else.
--
-- WHAT IT THEREFORE DOES NOT CATCH, said plainly rather than left to be
-- discovered: a pin that is already stale (its literal no longer equals the
-- corpus) is invisible to it -- but a stale pin is a RED test, which is the
-- state this detector exists to prevent reaching in the first place. And a
-- derived count that happens to coincide with the corpus size is a false
-- positive; if one ever appears, the fix is to make the assertion say what it
-- means (`== c.fixtures`), which is the same repair the detector is asking for.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local tests = {}

local function caught(fn)
    local ok, err = pcall(fn)
    return (not ok), tostring(err)
end

-- ---------------------------------------------------------------------------
-- 1. The module.  Each assertion is paired with the mutation it must reject --
--    a guard nobody has watched fail is a guard nobody knows is wired up.
-- ---------------------------------------------------------------------------

tests['corpus: growth passes, a shrink below the floor is caught'] = function()
    assert(cs.corpus(cs.FLOOR, 'x') == cs.FLOOR, 'the floor itself must pass')
    assert(cs.corpus(cs.FLOOR + 500, 'x') == cs.FLOOR + 500, 'growth must pass')
    local hit, err = caught(function() return cs.corpus(cs.FLOOR - 1, 'demo') end)
    assert(hit, 'a corpus one below the floor was accepted')
    assert(err:find('SHRANK', 1, true), 'the message must name the direction: ' .. err)
    assert(caught(function() return cs.corpus(nil, 'demo') end),
        'a nil corpus size was accepted')
end

tests['ratchet: a rise passes, a fall is caught'] = function()
    assert(cs.ratchet(74, 74, 'x') == 74, 'the registered value must pass')
    assert(cs.ratchet(75, 74, 'x') == 75, 'a rise must pass -- that is corpus growth')
    local hit, err = caught(function() return cs.ratchet(73, 74, 'push bids') end)
    assert(hit, 'a count one BELOW the registered value was accepted')
    assert(err:find('FELL', 1, true) and err:find('push bids', 1, true),
        'the message must name the counter and the direction: ' .. err)
    -- The point of the whole exercise: what a ratchet must NOT do is congratulate
    -- itself for accepting anything at all.
    assert(caught(function() return cs.ratchet('74', 74, 'x') end),
        'a non-number was accepted')
end

tests['ceiling: the mirror, for a rarity claim'] = function()
    assert(cs.ceiling(4, 4, 'x') == 4, 'the ceiling itself must pass')
    assert(cs.ceiling(3, 4, 'x') == 3, 'below the ceiling must pass')
    local hit, err = caught(function() return cs.ceiling(5, 4, 'rare shape') end)
    assert(hit, 'a count above the ceiling was accepted')
    assert(err:find('ROSE', 1, true), 'the message must name the direction: ' .. err)
end

tests['universal: stated over the live total, and it can still fail'] = function()
    assert(cs.universal(101, 101, 'x') == 101, 'all of them must pass')
    local hit, err = caught(function() return cs.universal(100, 101, 'the split') end)
    assert(hit, '100 of 101 was accepted as universal')
    assert(err:find('no longer universal', 1, true), 'wrong message: ' .. err)
    -- Anti-vacuum: a universal over nothing is true and worthless.
    assert(caught(function() return cs.universal(0, 0, 'x') end),
        'a universal over an empty sweep was accepted')
end

tests['universal: min_total is the caller\'s, because a denominator is not always the corpus'] = function()
    -- The category error this argument exists to prevent, kept as a test
    -- because it was a real bug in the first draft: applying the fixture-corpus
    -- FLOOR to a 50-frame sub-domain rejected a perfectly good measurement.
    assert(cs.share(34, 50, 0.5, 0.85, 'sub-domain') > 0.67,
        'a 50-frame sub-domain must be a legal denominator')
    local hit = caught(function() return cs.share(34, 50, 0.5, 0.85, 'x', cs.FLOOR) end)
    assert(hit, 'an explicit min_total must still be enforced')
    assert(cs.universal(101, 101, 'x', cs.FLOOR) == 101,
        'the corpus itself must pass its own floor')
end

tests['share: outside the band either way is caught'] = function()
    assert(cs.share(74, 101, 0.60, 0.85, 'x') > 0.73, 'inside the band must pass')
    local lo_hit, lo_err = caught(function() return cs.share(50, 101, 0.60, 0.85, 'floor share') end)
    assert(lo_hit, 'a share below the band was accepted')
    assert(lo_err:find('outside the registered band', 1, true), 'wrong message: ' .. lo_err)
    assert(caught(function() return cs.share(95, 101, 0.60, 0.85, 'x') end),
        'a share above the band was accepted')
end

-- ---------------------------------------------------------------------------
-- 2. The detector: no test file may pin the live corpus size as an equality.
-- ---------------------------------------------------------------------------

local function fixture_count()
    local p = assert(io.popen('ls tests/fixtures'))
    local n = 0
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then n = n + 1 end
    end
    p:close()
    return n
end

local function test_files()
    local p = assert(io.popen('ls tests'))
    local out = {}
    for f in p:lines() do
        if f:match('^test_.*%.lua$') then out[#out + 1] = 'tests/' .. f end
    end
    p:close()
    table.sort(out)
    return out
end

--- Every `== <integer>` in `line` that is not inside a comment, as a list of
--- numbers. A trailing '.' rules the literal out: `died_after == 101.9` is a
--- timestamp, not a count.
local function equality_literals(line)
    if line:match('^%s*%-%-') then return {} end
    local code = line:match('^(.-)%-%-') or line
    local out = {}
    -- The trailing `(%.?)` is the float guard: it consumes a decimal point if
    -- one follows the digits, so `died_after == 101.9` is rejected while
    -- `fixtures == 101,` is kept. Written as a capture rather than as a
    -- substring lookahead because the first draft's lookahead was wrong and
    -- the negative control below is what said so.
    for digits, dot in code:gmatch('==%s*(%d+)(%.?)') do
        if dot ~= '.' then out[#out + 1] = tonumber(digits) end
    end
    return out
end

--- ⭐ THE INDIRECTION HOLE (2026-09-07, strategy). `local NAME = <integer>` on a
--- non-comment line, returned as (name, value).
---
--- WHY THIS EXISTS, measured rather than imagined. The three trunk reds this
--- detector was supposed to prevent, and did not, on 2026-09-07:
---
---   tests/test_propertarget_corpus_domain.lua   `r.frames == 1012`
---   tests/test_salveyield_arbitration.lua       `#corpus().pairs == 73`
---   tests/test_stayfield2_marginal_domain.lua   `tonumber(sub) == SIGN_SUBSAMPLE`
---                                               with `local SIGN_SUBSAMPLE = 109`
---
--- The first two evade it the way the previous round already named: the literal
--- is a DIFFERENT denominator (live hero frames, holder/ally pairs), so it is
--- never equal to the fixture count and never compared. The third is a NEW
--- evasion and the reason for this function: 109 WAS the fixture count on the
--- day that line landed, and the detector still could not see it, because the
--- right-hand side of the `==` is an IDENTIFIER. Hoisting a literal into a named
--- constant -- the tidier way to write it, and the way this suite recommends
--- everywhere else -- silently exempted it.
---
--- ⛔ WHY THE PREDICATE IS "declared here AND equality-compared here", not "any
--- assignment". The detector's subject is EQUALITY PINS; following a name is
--- meant to reach the same pins through one more hop, not to widen the subject
--- to every integer constant in the suite. Measured on today's tree at N=110:
---   * 594 assignment-form integer constants exist in tests/;
---   * exactly 1 of them equals 110 (`local Q_MANA_R3 = 110`, Axe's Q mana at
---     rank 3, tests/test_axe_call_staged_frames.lua:84);
---   * it is compared only with `>=`, never `==`, so the equality requirement
---     rejects it and this extension costs ZERO new exemptions today.
--- The plain form ("any assignment equal to N") would have cost one exemption
--- immediately and roughly DOUBLED the per-fixture collision rate the
--- NOT_A_CORPUS_PIN note above is already paying. That is the trade this
--- narrower predicate declines, and it declines it on a measurement.
local function assignment_literal(line)
    if line:match('^%s*%-%-') then return nil end
    local code = line:match('^(.-)%-%-') or line
    local name, digits, dot = code:match('^%s*local%s+([%a_][%w_]*)%s*=%s*(%d+)(%.?)%s*$')
    if name == nil or dot == '.' then return nil end
    return name, tonumber(digits)
end

--- Names this file compares with `==` (either side), as a set.
local function equality_compared_names(lines)
    local names = {}
    for _, line in ipairs(lines) do
        if not line:match('^%s*%-%-') then
            local code = line:match('^(.-)%-%-') or line
            for n in code:gmatch('==%s*([%a_][%w_]*)') do names[n] = true end
            for n in code:gmatch('([%a_][%w_]*)%s*==') do names[n] = true end
        end
    end
    return names
end

-- Literals this detector may NOT read as a corpus pin, each with the reason it
-- is something else. Keyed by the trimmed CODE of the line, not by a line
-- number: a line that moves keeps its exemption, and a line whose code CHANGES
-- loses it and comes back as a finding.
--
-- ⭐ WHY THIS LIST EXISTS AT ALL (2026-09-03, replay-check). The detector's rule
-- is "a literal equal to TODAY'S fixture count", so its precision is a function
-- of the corpus size: every fixture landing re-aims it at whatever unrelated
-- `== N` the new count happens to hit. Landing the 109th fixture (GH #437's
-- frame) aimed it at a DAMAGE TOTAL -- three creep hits summing to 109 HP --
-- and reported it in the same words it reports a real corpus pin. That is a
-- false positive by construction, not a mistake in the entry below, and the
-- next fixture will produce a different one. The exemption is deliberately
-- narrow and fails CLOSED so nobody can widen it by accident.
--
-- ⭐ THE NEXT COLLISION IS ALREADY MEASURED (2026-09-05, replay-check). Landing
-- the 110th fixture aims this detector at `tests/test_cm_q_creep_aoe_reach.lua`
-- line 548 -- `assert(h:GetSpecialValueInt('nova_damage') == 110, ...)`, a
-- Crystal Maiden ability VALUE out of the KV snapshot. Observed for real: a
-- fixture checked in mid-round took the corpus to 110, this test went red
-- naming that line, and removing the fixture cleared it. Whoever lands #110 --
-- add the entry, do not loosen the detector, and do not spend the round
-- wondering what nova_damage has to do with the corpus (it has nothing to do
-- with it; that is the whole point of this comment).
--
-- ⭐ #110 LANDED 2026-09-07 (replay-check) and it was the predicted collision,
-- to the line. The 110th fixture is the `zusultstrand` creation frame
-- (tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua, pinned by
-- tests/test_replay_260827_zuus_ultstrand_creation.lua); the detector went red
-- naming exactly the line the note above names, and holding the fixture out
-- cleared it. Entry added as instructed -- the detector was NOT loosened, and
-- the round was NOT spent wondering what nova_damage has to do with the corpus.
-- It has nothing to do with it: 110 is Crystal Nova's KV damage value.
local NOT_A_CORPUS_PIN = {
    ['assert(hits == 3 and total == 109,'] =
        'tests/test_fieldcreep_veto.lua: `total` is summed DAMAGE from three '
        .. 'creep hits (109 HP), not a fixture count -- the next line asserts '
        .. 'the biggest of them is >= 25',
    ["assert(h:GetSpecialValueInt('nova_damage') == 110, 'nova_damage: pinned 110, fixture KV '"] =
        'tests/test_cm_q_creep_aoe_reach.lua: 110 is crystal_maiden_crystal_nova\'s '
        .. 'KV `nova_damage` at the pinned rank, read off the fixture loader\'s KV '
        .. 'snapshot -- an ABILITY VALUE, not a fixture count. Predicted by the '
        .. 'note above on 2026-09-05 and confirmed on the day #110 landed',
}

tests['[detector] no test pins the live corpus size with an equality'] = function()
    local n = fixture_count()
    cs.corpus(n, 'live fixture corpus')
    local hits = {}
    for _, path in ipairs(test_files()) do
        -- This file is excluded from its own scan, and that is a hole, so it is
        -- named rather than hidden: the literals above are the detector's test
        -- DATA (a real pin, a float, a comment) and would otherwise be reported
        -- as findings. The hole is bounded -- this file contains no census, so
        -- there is nothing here for a corpus pin to be about.
        if path ~= 'tests/test_corpus_scale.lua' then
        local fh = assert(io.open(path, 'r'))
        local lines = {}
        for line in fh:lines() do lines[#lines + 1] = line end
        fh:close()
        -- Second pass over the same file, so a constant declared below its use
        -- is still followed. Cheap: these files are a few hundred lines.
        local compared = equality_compared_names(lines)
        for lineno, line in ipairs(lines) do
            local flagged = false
            for _, v in ipairs(equality_literals(line)) do
                if v == n then flagged = true end
            end
            -- The indirection hop: `local NAME = <fixture count>` counts only
            -- when NAME is equality-compared in this same file. See
            -- assignment_literal's note for why the second clause is required.
            local name, val = assignment_literal(line)
            if name ~= nil and val == n and compared[name] then flagged = true end
            if flagged and NOT_A_CORPUS_PIN[line:gsub('^%s+', '')] == nil then
                hits[#hits + 1] = path .. ':' .. lineno .. ': ' .. line:gsub('^%s+', '')
            end
        end
        end
    end
    assert(#hits == 0, string.format(
        '%d assertion(s) compare a literal to the current fixture count (%d). That is the '
        .. 'GH #106 / GH #127 defect: landing the next fixture turns them red without '
        .. 'anything they measure having changed. MATCHING FACE, so a green line here is '
        .. 'not mistaken for a broader claim than it makes (GH #240 option 3): this leg '
        .. 'sees ONLY literals equal to the live fixture count, which is one quantity and '
        .. 'not every pin that a new fixture turns red -- the leg below covers corpus-'
        .. 'derived SUMS. Use tests/corpus_scale.lua -- ratchet() '
        .. 'for a per-fixture sum, universal() for an "all of them" claim, corpus() for '
        .. 'the size itself.\n  %s', #hits, n, table.concat(hits, '\n  ')))
end

tests['[detector] the indirection hop is wired, and it is narrow'] = function()
    -- A guard nobody has watched fail is a guard nobody knows is wired up --
    -- section 1's rule, applied to the extension. Every clause of the predicate
    -- gets the mutation it must reject, because the whole cost argument for this
    -- extension rests on the SECOND clause being real.
    local name, val = assignment_literal('local SIGN_SUBSAMPLE  = 109   -- declared slice')
    assert(name == 'SIGN_SUBSAMPLE' and val == 109,
        'the real evading line is not parsed: ' .. tostring(name) .. '/' .. tostring(val))

    assert(assignment_literal('-- local SIGN_SUBSAMPLE = 109') == nil,
        'a commented-out declaration must not be followed (GH #267 discipline)')
    assert(assignment_literal('local T = 101.9') == nil,
        'a float is a timestamp, not a count -- same guard as equality_literals')
    assert(assignment_literal('local T = n + 1') == nil,
        'only a bare integer literal is a pin; an expression is a derivation')
    assert(assignment_literal('local T = 109 + OFFSET') == nil,
        'a literal that is only part of an expression must not be read as the value')

    -- Clause two, in both directions, on the two real lines that motivated it.
    local compared = equality_compared_names({
        'local SIGN_SUBSAMPLE  = 109',
        'assert(tonumber(sub) == SIGN_SUBSAMPLE, ...)',
        'local Q_MANA_R3 = 110',
        'assert(bot:GetMana() >= Q_MANA_R3, ...)',
    })
    assert(compared['SIGN_SUBSAMPLE'],
        'the name whose equality made it a pin was not collected')
    assert(not compared['Q_MANA_R3'],
        'a name used only under >= was collected -- the extension just widened '
        .. 'to every integer constant in the suite, which is exactly what its '
        .. 'cost argument says it does not do')

    -- And the left-hand form, which a one-sided pattern would miss.
    local lhs = equality_compared_names({ 'assert(LIVE_FRAMES == n)' })
    assert(lhs['LIVE_FRAMES'], 'a name on the LEFT of == was not collected')
end

tests['[detector] every declared exemption still names a live line'] = function()
    -- An exemption that stops matching anything is not harmless: it is a
    -- standing licence nobody can see the target of, and the next reader has to
    -- take it on faith that it was ever justified. So a dead entry goes red and
    -- gets deleted rather than accumulating.
    for code in pairs(NOT_A_CORPUS_PIN) do
        local found = false
        for _, path in ipairs(test_files()) do
            local fh = assert(io.open(path, 'r'))
            for line in fh:lines() do
                if line:gsub('^%s+', '') == code then found = true break end
            end
            fh:close()
            if found then break end
        end
        assert(found, 'a declared exemption matches no line in tests/ any more -- '
            .. 'delete it instead of leaving a licence with no target: ' .. code)
    end
end

tests['[detector] the detector reads code and not prose'] = function()
    -- Its own negative controls, because a scanner that matches nothing passes
    -- section 2 for free. Each of these is a shape that really occurs in the
    -- tree (a commented number, a float timestamp, a mana value).
    local function only(line) return #equality_literals(line) end
    assert(only('-- assert(c.fixtures == 101, ...)') == 0, 'a comment line was scanned')
    assert(only('    local x = 1 -- pinned at == 101 in the prose') == 0,
        'a trailing comment was scanned')
    assert(only('assert(fx.observed.died_after == 101.9, ...)') == 0,
        'a float timestamp was read as an integer count')
    assert(only('assert(c.fixtures == 101, ...)') == 1,
        'a real pin was missed')
    assert(equality_literals('assert(a == 101 and b == 940, ...)')[2] == 940,
        'a second equality on the same line was missed')
end

-- ===========================================================================
-- GH #240 / GH #466 -- the second matching face (director RULING 65, 2026-09-16)
-- ===========================================================================
--
-- The detector above asks "is this literal equal to TODAY'S fixture count".
-- That predicate is neither NECESSARY nor SUFFICIENT for the proposition it is
-- said to guard ("appending a fixture turns this assertion red"), and both
-- failures are measured, not argued:
--
--   * NOT SUFFICIENT -> false positives, at a rate that is a FUNCTION OF THE
--     CORPUS SIZE. Every landing re-aims it at whatever unrelated `== N` the
--     new count happens to hit. Its two lifetime fires were a summed DAMAGE
--     total (109) and a Crystal Nova KV VALUE (110) -- measured precision
--     0/2, and the two NOT_A_CORPUS_PIN entries above are the receipts.
--   * NOT NECESSARY -> systematic misses. `assert(CORPUS.axe_frames == 29)`
--     is a raw equality on a per-fixture sum: it goes red the day an Axe
--     fixture lands, with nothing it measures having changed. That is the
--     GH #106 / GH #127 defect exactly, and the face above cannot see it,
--     because 29 is not 112.
--
-- ⛔ WHY THE FILE-LEVEL CONTEXT PROPOSAL WAS REJECTED (GH #466 (a) / GH #240
-- option 1, "only judge inside census-type context"). Measured on today's tree
-- before ruling: the context face `grep -ln "tests/fixtures\|scan_corpus\|
-- corpus_scale" tests/test_*.lua` selects 400 of 488 test files (82%), and it
-- CONTAINS BOTH MEASURED FALSE POSITIVES -- test_fieldcreep_veto.lua and
-- test_cm_q_creep_aoe_reach.lua are both in it. So at file granularity the
-- proposal removes NEITHER false positive while widening the finding set to
-- every `assert(<expr> == <int>)` in 82% of the suite. The context is the
-- FILE; the defect is the LINE. Nearly every test here loads a fixture, so
-- file-level context carries almost no information.
--
-- ⇒ WHAT IS ADOPTED: the same idea at LINE granularity, which is what GH #466
-- actually proposed ("同一行/邻近行出现 fixtures、corpus、#files 之类的记号").
-- The predicate is "the LEFT-HAND SIDE of the equality reads the corpus", and
-- it drops the dependence on N entirely. Consequences, all of them the point:
--   * the false-positive rate STOPS being a function of the corpus size --
--     landing a fixture cannot re-aim a predicate that never reads the count;
--   * both NOT_A_CORPUS_PIN entries are rejected BY CONSTRUCTION (neither
--     `total` nor `h:GetSpecialValueInt('nova_damage')` reads the corpus), so
--     the exemption table stops accreting one entry per fixture;
--   * the 11 live misses become visible. Two were verified at the source
--     before this landed: test_axe_t15_payoff.lua's `scan()` and
--     test_wk_bone_guard_stock_gate.lua's `wk_corpus()` both `ls
--     tests/fixtures` and accumulate, so those equalities really are pinned
--     to the corpus.
--
-- `== 0` is exempt and that is deliberate: `assert(X == 0)` claims the set is
-- EMPTY, and a new fixture turning it red is a MEANINGFUL red (something
-- entered the domain), not a spurious one. 8 of the 20 raw matches are `== 0`.
--
-- ⚠️ THE 11 KNOWN LINES ARE A DECLARED BASELINE, NOT AN AMNESTY. Making them
-- red today would turn trunk red for all five streams at once and be found by
-- whichever desk starts work next -- the GH #624 failure mode this repo has
-- already paid for four times. So the door CLOSES today (a new raw corpus pin
-- is red immediately) and the 11 are enumerated as migration debt under
-- GH #240. Migrating one is `cs.ratchet()` -- see the helpers in
-- tests/corpus_scale.lua.

--- True when an equality's left-hand side reads the fixture corpus. This is
--- the whole matching face, and it is deliberately textual: the alternative
--- (real data-flow) buys precision this detector does not need, because the
--- baseline below bounds the over-approximation to a set that is checked.
local function reads_corpus(lhs)
    local low = lhs:lower()
    return low:find('corpus', 1, true) ~= nil
        or low:find('fixture', 1, true) ~= nil
        or low:find('archive', 1, true) ~= nil
end

--- Every `<expr> == <integer literal>` on the line whose left-hand side reads
--- the corpus, as a list of { value = , lhs = }. Comments and floats are
--- rejected for the same reasons equality_literals rejects them: a commented
--- number is prose, and a float is a timestamp rather than a count.
local function corpus_sum_equalities(line)
    if line:match('^%s*%-%-') then return {} end
    local code = line:match('^(.-)%-%-') or line
    local out = {}
    local pos = 1
    while true do
        local s, e, digits = code:find('==%s*(%d+)', pos)
        if s == nil then break end
        if code:sub(e + 1, e + 1) ~= '.' then
            local v = tonumber(digits)
            local lhs = code:sub(1, s - 1)
            if v ~= 0 and reads_corpus(lhs) then
                out[#out + 1] = { value = v, lhs = lhs }
            end
        end
        pos = e + 1
    end
    return out
end

-- The migration debt GH #240 names, enumerated on 2026-09-16 at N=112. Keyed
-- by the trimmed CODE of the line, exactly like NOT_A_CORPUS_PIN above: a line
-- that MOVES keeps its entry, a line whose code CHANGES loses it and comes
-- back as a finding. Each entry says what the pinned quantity is summed over,
-- because that is the fact a migrator needs and the fact that makes the entry
-- auditable.
local KNOWN_RAW_CORPUS_PIN = {
    ['assert(CORPUS.axe_frames == 29,'] =
        'tests/test_axe_t15_payoff.lua: scan() lists tests/fixtures and counts '
        .. 'Axe hero-slots -- red the day an Axe fixture lands',
    ['assert(CORPUS.axe_frames_with_modifiers == 19,'] =
        'tests/test_axe_t15_payoff.lua: same scan(), Axe frames carrying '
        .. 'modifier data',
    ['assert(CORPUS.hunger_live == 5,'] =
        'tests/test_axe_t15_payoff.lua: same scan(), frames with battle_hunger live',
    ['assert(CORPUS.call_live == 1,'] =
        'tests/test_axe_t15_payoff.lua: same scan(), frames with berserkers_call live',
    ['assert(CORPUS.max_level == 14,'] =
        'tests/test_axe_t15_payoff.lua: same scan(), the highest Axe level in the corpus',
    ["assert(corpus.max_shown == 1, 'the corpus alone now shows '"] =
        'tests/test_cm_cmqreach_transit_frame.lua: a per-fixture maximum',
    ['assert(corpus.complete == 0 and corpus.worst_deficit == 2,'] =
        'tests/test_cm_cmqreach_transit_frame.lua: worst_deficit is a per-fixture '
        .. 'extremum (the == 0 conjunct is exempt on its own; this entry is for the 2)',
    ["assert(#corpus == 3, 'the identity was checked on fewer heroes than claimed')"] =
        'tests/test_pullchew_camp_commit.lua: the count of heroes the sweep found',
    ['assert(corpus().heal_units == 9,'] =
        'tests/test_salveyield_arbitration.lua: a sum over tests/fixtures -- the '
        .. 'sibling lines in this same file already migrated to cs.ratchet(), '
        .. 'which is what makes this one the clearest instance of GH #240',
    ["assert(#corpus == 33, 'the corpus holds ' .. #corpus .. ' live Wraith King '"] =
        'tests/test_wk_bone_guard_stock_gate.lua: wk_corpus() lists tests/fixtures '
        .. '-- red the day a Wraith King fixture lands',
    ["assert(#corpus == 33, 'the priced corpus holds ' .. #corpus .. ' Wraith King '"] =
        'tests/test_wk_reserve_idle_release.lua: the same wk_corpus() sweep',
}

tests['[detector] no test pins a corpus-derived sum with a raw equality'] = function()
    local hits = {}
    for _, path in ipairs(test_files()) do
        -- Excluded from its own scan for the same reason the detector above is:
        -- the baseline table right here is this detector's test DATA and would
        -- otherwise report itself. The hole is bounded the same way -- this file
        -- holds no census, so there is nothing here for a corpus pin to be about.
        if path ~= 'tests/test_corpus_scale.lua' then
            local fh = assert(io.open(path, 'r'))
            local lineno = 0
            for line in fh:lines() do
                lineno = lineno + 1
                local code = line:gsub('^%s+', '')
                if #corpus_sum_equalities(line) > 0
                    and KNOWN_RAW_CORPUS_PIN[code] == nil then
                    hits[#hits + 1] = path .. ':' .. lineno .. ': ' .. code
                end
            end
            fh:close()
        end
    end
    assert(#hits == 0, string.format(
        '%d assertion(s) pin a CORPUS-DERIVED SUM with a raw equality. Landing the '
        .. 'next fixture turns them red without anything they measure having changed '
        .. '(GH #106 / GH #127, reached through GH #240). MATCHING FACE, so you can '
        .. 'tell a real hit from a coincidence: `<expr> == <non-zero integer>` where '
        .. 'the LEFT-HAND SIDE mentions corpus/fixture/archive. It does NOT read the '
        .. 'fixture count, so it does not drift when the corpus grows. Fix with '
        .. 'tests/corpus_scale.lua -- ratchet() for a per-fixture sum, universal() '
        .. 'for an "all of them" claim, corpus() for the size itself.\n  %s',
        #hits, table.concat(hits, '\n  ')))
end

tests['[detector] every declared corpus-pin baseline entry still names a live line'] = function()
    -- Same rule as the exemption guard above, for the same reason: a baseline
    -- entry that stops matching anything is a standing licence with no visible
    -- target. It goes red so it gets deleted -- which is also how GH #240's
    -- migration debt is counted DOWN rather than quietly kept at 11 forever.
    for code in pairs(KNOWN_RAW_CORPUS_PIN) do
        local found = false
        for _, path in ipairs(test_files()) do
            local fh = assert(io.open(path, 'r'))
            for line in fh:lines() do
                if line:gsub('^%s+', '') == code then found = true break end
            end
            fh:close()
            if found then break end
        end
        assert(found, 'a declared corpus-pin baseline entry matches no line in '
            .. 'tests/ any more -- it was migrated or moved, so delete the entry '
            .. 'instead of leaving a licence with no target: ' .. code)
    end
end

tests['[detector] the second face reads code, not prose, and not the corpus size'] = function()
    -- Negative controls, because a scanner that matches nothing passes for free.
    local function n(line) return #corpus_sum_equalities(line) end

    assert(n('-- assert(CORPUS.axe_frames == 29, ...)') == 0, 'a comment line was scanned')
    assert(n('    local x = 1 -- corpus pinned at == 29 in the prose') == 0,
        'a trailing comment was scanned')
    assert(n('assert(corpus.died_after == 101.9, ...)') == 0,
        'a float timestamp was read as an integer count')
    assert(n('assert(CORPUS.in_domain == 0, ...)') == 0,
        'an == 0 emptiness claim was reported -- a new fixture breaking THAT is '
        .. 'a meaningful red, and exempting it is why this face is usable')

    -- The two shapes the OLD face got wrong, in both directions. These are the
    -- whole cost argument for this detector, so they are asserted, not asserted
    -- about in a comment.
    assert(n('assert(hits == 3 and total == 109,') == 0,
        'the summed-DAMAGE false positive came back -- its LHS does not read the corpus')
    assert(n("assert(h:GetSpecialValueInt('nova_damage') == 110, 'nova_damage: pinned 110'") == 0,
        'the ability-VALUE false positive came back')
    assert(n('assert(CORPUS.axe_frames == 29,') == 1,
        'the systematic MISS that motivated GH #240 is still invisible')
    assert(n("assert(#corpus == 33, 'the corpus holds ')") == 1,
        'a length-of-corpus pin was missed')

    -- Two equalities on one line are two hits, and the conjunct that is `== 0`
    -- is not one of them.
    assert(n('assert(corpus.complete == 0 and corpus.worst_deficit == 2,') == 1,
        'the == 0 conjunct and the == 2 conjunct were not told apart')

    -- And the face really is independent of the corpus size: a literal equal to
    -- the live fixture count is NOT a hit unless its LHS reads the corpus. This
    -- is the identity that ends the "precision is a function of corpus size"
    -- defect, so it is pinned.
    assert(n('assert(mana_cost == ' .. fixture_count() .. ', ...)') == 0,
        'a non-corpus literal that happens to equal the fixture count was reported '
        .. '-- that is the GH #466 defect, reintroduced')
end

return tests
