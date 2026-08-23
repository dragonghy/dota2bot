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
        local lineno = 0
        for line in fh:lines() do
            lineno = lineno + 1
            for _, v in ipairs(equality_literals(line)) do
                if v == n then
                    hits[#hits + 1] = path .. ':' .. lineno .. ': ' .. line:gsub('^%s+', '')
                end
            end
        end
        fh:close()
        end
    end
    assert(#hits == 0, string.format(
        '%d assertion(s) compare a literal to the current fixture count (%d). That is the '
        .. 'GH #106 / GH #127 defect: landing the next fixture turns them red without '
        .. 'anything they measure having changed. Use tests/corpus_scale.lua -- ratchet() '
        .. 'for a per-fixture sum, universal() for an "all of them" claim, corpus() for '
        .. 'the size itself.\n  %s', #hits, n, table.concat(hits, '\n  ')))
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

return tests
