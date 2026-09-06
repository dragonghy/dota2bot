-- [strategy 20260904, GH #464 §5 / test_set.md §DU.8]
--
-- WHAT THIS GUARDS, and why it is a text test rather than a census.
--
-- The wandbleed2 harvest condition (`iterations/streams/test_set.md` §DU.5) is
-- the ruler W43 gets read against: item 2 is the load-bearing negative face
-- ("of the frames the narrowing KEEPS, how many still have a live enemy inside
-- the ring") and item 3 is the DOMAIN-NOT-REACHED clause ("how often does the
-- last conjunct fire at all"). Both are RATIOS OVER THE FIXTURE CORPUS, and
-- both were written as prose.
--
-- The corpus side already has a ratchet: test_replay_437_wandbleed_source.lua
-- pins `#c.fresh_frames` and `#blocked`, so growing the corpus turns that file
-- red. The ARCHIVE side had nothing -- and it drifted exactly once already:
-- one fixture (f_260902_154755_cm_wandbleed_residue.lua) landed, the census
-- moved 80 -> 81 frames and 2 -> 3 blocked, the test file was re-nailed the
-- same day, and §DU.5 went on saying `78/80` and `2/101` for a day with
-- nothing red anywhere. GH #464 caught the first of those two by hand.
--
-- So this file does NOT recompute the corpus. Recomputing it would be a THIRD
-- copy of the same fact (the defect §DU.8.2 and GH #458 are both about), and
-- a third copy can drift from the other two on its own. It reads the numbers
-- back out of the ratchets in the census test -- the one registered place --
-- derives the two ratios the archive is supposed to quote, and asserts the
-- archive quotes exactly those. The chain is:
--
--     corpus  ->  ratchets in test_replay_437_wandbleed_source.lua  (already)
--             ->  the prose in test_set.md §DU.5                    (here)
--
-- One hammer, two nails. When the corpus next grows, the census test goes red
-- first (it owns the measurement); once someone re-nails it, THIS file goes
-- red until §DU.5 is re-nailed too, and its failure text says what to write.
--
-- WHAT IT DOES NOT GUARD (registered, not fixed here):
--   * `iterations/queue.json:1501` -- the strategy-39 verdict note carries both
--     stale numbers verbatim. That is the DIRECTOR's own ruling text; this
--     stream does not edit another seat's verdict, and does not assert on it.
--     A harvester who reads the queue note instead of §DU.5 still gets `78/80`
--     and `2/101`. Handed off in §DU.8.3.
--   * §DS / §DU.2's "blocks 0/101 pairs" -- history lines, left verbatim per
--     the charter; the current reading (0/102, still zero) is in §DU.8.1.

package.path = 'tests/?.lua;' .. package.path

local CENSUS_TEST = 'tests/test_replay_437_wandbleed_source.lua'
-- Owner P4.3 (2026-09-06): the two carriers this file checks now live in
-- DIFFERENT files.  The harvest banner stayed in the live `test_set.md` (it is
-- what a harvester meets first, which is the whole reason it is a second
-- carrier); §DU.5 itself moved to the ruling archive.  So the corpus here is
-- the union, in the same order a reader meets it -- and the `assert(at, ...)`
-- in `section` below is why this was not a silent pass: the split ran the
-- suite red on this file until the constant was re-pointed, exactly as it is
-- supposed to.  ⚠️ `lua5.1 tests/test_du5_archive_census.lua` executes NOTHING
-- (this file `return`s a table); it must be run through `tests/run_tests.lua`.
local LIVE = 'iterations/streams/test_set.md'
local ARCHIVE_FILE = 'iterations/archive/test_set_archive.md'
local ARCHIVE = LIVE .. ' + ' .. ARCHIVE_FILE

-- A superseded number may stay in the archive, but only in demoted position:
-- right after this marker, so a reader meets the correction before the number.
local DEMOTED = '原写作'
local DEMOTED_WINDOW = 24 -- bytes; the marker plus at most a little markup

-- Ratios that are legitimately in §DU.5 and are NOT one of the two the archive
-- must quote. Each needs a reason here, so adding one is a deliberate act
-- rather than a way to quiet this file.
local OTHER_POPULATION = {
    -- §DU.8.2's contrast reading: victim/attacker PAIRS whose attacker is
    -- dead. A different population from the frame ratios above -- it is
    -- printed precisely to show the two cuts have diverged.
    ['2/102'] = 'pairs whose attacker is dead (the diverged cut, §DU.8.2)',
}

local tests = {}

local function slurp(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

-- The live file and the ruling archive, joined by a newline so a heading on
-- the archive's first line cannot be swallowed by the live file's last.
local function corpus()
    return slurp(LIVE) .. '\n' .. slurp(ARCHIVE_FILE)
end

-- The two numbers the census test registers. Read from the ratchet CALLS, not
-- from a comment: a comment can be updated without the assertion moving, and
-- the assertion is the thing that actually goes red.
local function registered()
    local src = slurp(CENSUS_TEST)
    local fresh = src:match('cs%.ratchet%(#c%.fresh_frames,%s*(%d+),')
    local blocked = src:match('cs%.ratchet%(#blocked,%s*(%d+),')
    assert(fresh, 'the fresh-frame ratchet moved in ' .. CENSUS_TEST
        .. ' -- this file reads it by shape, re-point it')
    assert(blocked, 'the blocked-frame ratchet moved in ' .. CENSUS_TEST
        .. ' -- this file reads it by shape, re-point it')
    return tonumber(fresh), tonumber(blocked)
end

-- §DU.5 runs from its own heading to the next `### §DU.` heading.
local function section(src, heading)
    local at = src:find('\n' .. heading, 1, true)
    assert(at, heading .. ' is gone from ' .. ARCHIVE)
    local stop = src:find('\n### §DU%.', at + 1)
    assert(stop, 'no following §DU heading -- the section boundary moved')
    return src:sub(at, stop)
end

-- The top-of-file harvest banner. It is a SECOND carrier of item 3's ratio,
-- and it is the one a harvester meets first.
local function banner(src)
    for line in src:gmatch('[^\n]+') do
        if line:find('收割前必读(§DU.5)', 1, true) then return line end
    end
    error('the §DU.5 harvest banner is gone from the top of ' .. ARCHIVE)
end

-- Every `<int>/<int>` in the text, with the byte offset it starts at.
local function ratios(text)
    local out = {}
    local pos = 1
    while true do
        local s, e, r = text:find('(%d+/%d+)', pos)
        if not s then break end
        out[#out + 1] = { ratio = r, at = s }
        pos = e + 1
    end
    return out
end

local function is_demoted(text, at)
    local from = math.max(1, at - DEMOTED_WINDOW)
    return text:sub(from, at - 1):find(DEMOTED, 1, true) ~= nil
end

tests['the census test still registers both numbers this file reads'] = function()
    local fresh, blocked = registered()
    assert(fresh > blocked, string.format(
        'blocked (%d) must be a strict subset of fresh-damage frames (%d)',
        blocked, fresh))
    -- Not a re-measurement: just the arithmetic that makes "kept" meaningful.
    -- If this ever fails the two ratchets have gone out of step with each
    -- other and neither ratio below means anything.
    assert(fresh - blocked > 0, 'kept frames must be positive')
end

tests['§DU.5 quotes the kept-frames ratio the census test registers'] = function()
    local fresh, blocked = registered()
    local want = string.format('%d/%d', fresh - blocked, fresh)
    local sec = section(corpus(), '### §DU.5')
    assert(sec:find(want, 1, true), string.format(
        '§DU.5 item 2 must quote the kept-frames ratio %s (kept = fresh %d - '
        .. 'blocked %d, both read off the ratchets in %s). Re-nail the prose, '
        .. 'and demote the old value with the marker "%s".',
        want, fresh, blocked, CENSUS_TEST, DEMOTED))
end

tests['§DU.5 and the harvest banner quote the last-conjunct rate, in FRAMES'] = function()
    local fresh, blocked = registered()
    -- The correction §DU.8.2 exists to make permanent: this rate is
    -- frames-over-frames. It was written 2/101 -- a frame numerator over a
    -- victim/attacker-pair denominator -- and nobody had to say which cut it
    -- was, because on the old corpus both cuts happened to read 2.
    local want = string.format('%d/%d', blocked, fresh)
    local src = corpus()
    local sec = section(src, '### §DU.5')
    assert(sec:find(want, 1, true), string.format(
        '§DU.5 item 3 (the DOMAIN-NOT-REACHED clause) must quote %s -- blocked '
        .. 'frames over fresh-damage frames, both from %s. A pair denominator '
        .. 'here reads the domain SMALLER than it is.', want, CENSUS_TEST))
    assert(banner(src):find(want, 1, true), string.format(
        'the top-of-file harvest banner still quotes a stale last-conjunct '
        .. 'rate -- it must say %s too; it is the copy a harvester meets first',
        want))
end

tests['no superseded ratio stands undemoted in §DU.5 or the banner'] = function()
    local fresh, blocked = registered()
    local live = {
        [string.format('%d/%d', fresh - blocked, fresh)] = true,
        [string.format('%d/%d', blocked, fresh)] = true,
    }
    local src = corpus()
    for label, text in pairs({ ['§DU.5'] = section(src, '### §DU.5'),
                               ['the harvest banner'] = banner(src) }) do
        for _, hit in ipairs(ratios(text)) do
            if not live[hit.ratio] and not OTHER_POPULATION[hit.ratio] then
                assert(is_demoted(text, hit.at), string.format(
                    '%s carries the ratio %s with no "%s" marker before it. A '
                    .. 'number that is no longer the reading must be demoted '
                    .. 'in place, not left standing next to the live one -- '
                    .. 'that is how 78/80 and 2/101 survived a re-baseline. '
                    .. '(Live: %s and %s.)',
                    label, hit.ratio, DEMOTED,
                    string.format('%d/%d', fresh - blocked, fresh),
                    string.format('%d/%d', blocked, fresh)))
            end
        end
    end
end

return tests
