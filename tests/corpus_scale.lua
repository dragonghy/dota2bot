-- Corpus-scale assertions: the ONE place that knows how a census is allowed to
-- depend on the size of tests/fixtures/.
--
-- WHY THIS FILE EXISTS (GH #106, then GH #127 as the recurrence). Every census
-- in this suite used to pin the corpus size, and every count taken over it, as
-- an EQUALITY -- `== 100`, `74 of 100`, `334/911`, `22 wet / 28 dry`. Landing a
-- single fixture on 2026-08-22 turned **18 assertions across 7 files** red at
-- once, and none of the 18 was about the thing its test is about; they were all
-- re-statements of the corpus size. #106 counted 5 files, #127 counted 7 -- the
-- coupling face was GROWING, and the only thing holding it together was every
-- future fixture author remembering to re-baseline seven files they have never
-- read. GH #106 §4 proposed exactly the change this module makes, and
-- test_level_gate_census.lua wrote it down and then performed the ritual twice
-- more in one day instead.
--
-- THE ARGUMENT THAT MAKES THE REPLACEMENT SAFE -- it is not "assert less".
-- Every counter in these censuses is a SUM OVER FIXTURES: the sweep visits each
-- fixture once and adds what it finds. Appending a fixture therefore adds a
-- non-negative amount to every such counter and removes nothing. So:
--
--   * a count going DOWN is impossible under append. It means a fixture was
--     deleted, or a frame stopped satisfying the predicate -- i.e. BEHAVIOUR
--     MOVED, which is the only failure these pins were ever written to catch.
--     `ratchet` still catches it, exactly.
--   * a count going UP is the corpus growing, which the equality mis-reported
--     as a regression. `ratchet` stops charging for it.
--
-- And for the "all N of N" claims the replacement is STRICTLY STRONGER, not
-- weaker: `hits == total` keeps holding over the fixtures nobody has written
-- yet, where `hits == 100` only ever spoke about the hundred we had.
--
-- WHAT IS DELIBERATELY NOT SOFTENED. A claim whose whole content is a zero
-- (`ge20 == 0`, `camp_up == 0`, `mode_nonzero == 0`) stays an equality: it is
-- already growth-immune, and it is the assertion that several INERT/SILENT
-- verdicts elsewhere are argued from. Those must go red the moment the corpus
-- grows a counter-example -- that is the point of them.
--
-- HOW TO RE-BASELINE HONESTLY. When a census is genuinely re-taken (not merely
-- outgrown), raise the `recorded` argument at the call site and say in the
-- comment what was re-measured. Never lower FLOOR.

local M = {}

-- The registered size of tests/fixtures/ at the time the censuses in this suite
-- were taken. It is an anti-vacuum floor, not a target: the corpus may grow
-- freely, but a census that suddenly runs over 3 fixtures is measuring nothing
-- and must not be allowed to pass quietly.
M.FLOOR = 100

local function fail(msg)
    -- level 3: report at the caller's call site, not inside this module.
    error(msg, 3)
end

--- The corpus may grow; it must never silently shrink.
function M.corpus(n, label)
    if type(n) ~= 'number' then
        fail((label or 'corpus') .. ': size is not a number (' .. tostring(n) .. ')')
    end
    if n < M.FLOOR then
        fail(string.format(
            '%s: corpus SHRANK to %d fixtures (floor %d) -- fixtures are append-only, '
            .. 'so this is a deleted fixture or a broken sweep, not growth',
            label or 'corpus', n, M.FLOOR))
    end
    return n
end

--- A count that is a sum over fixtures: it may rise with the corpus, never fall.
function M.ratchet(actual, recorded, label)
    if type(actual) ~= 'number' then
        fail((label or 'count') .. ': not a number (' .. tostring(actual) .. ')')
    end
    if actual < recorded then
        fail(string.format(
            '%s FELL to %d (registered %d). Appending fixtures cannot lower a '
            .. 'per-fixture count, so this is a behaviour change or a lost fixture -- '
            .. 're-read the finding, do not re-baseline',
            label or 'count', actual, recorded))
    end
    return actual
end

--- The mirror of ratchet, for quantities whose claim is an upper bound (a
--- rarity claim: "this shape occurs on at most N frames").
function M.ceiling(actual, limit, label)
    if actual > limit then
        fail(string.format(
            '%s ROSE to %d (ceiling %d) -- the rarity this verdict rests on no longer '
            .. 'holds; re-read it', label or 'count', actual, limit))
    end
    return actual
end

--- Anti-vacuum guard for a denominator. `min_total` is the caller's, because a
--- denominator is not always the fixture corpus: it can be hero-frames, or a
--- sub-domain of a few dozen frames, and applying FLOOR to those would be a
--- category error (it was, once -- the fieldcreep situation domain is 50).
--- Pass cs.FLOOR explicitly when the denominator IS the fixture corpus.
local function denominator(total, min_total, label)
    if type(total) ~= 'number' or total <= 0 then
        fail((label or 'denominator') .. ': nothing was measured (' .. tostring(total) .. ')')
    end
    if min_total and total < min_total then
        fail(string.format('%s: only %d, below the registered minimum %d -- this reads '
            .. 'as a broken sweep rather than a measurement', label or 'denominator',
            total, min_total))
    end
    return total
end

--- "All of them", stated over the live corpus instead of over a remembered
--- hundred. Carries an anti-vacuum check so it cannot pass on an empty sweep.
function M.universal(hits, total, label, min_total)
    denominator(total, min_total, (label or 'universal') .. ' denominator')
    if hits ~= total then
        fail(string.format('%s: %d of %d -- no longer universal', label or 'universal',
            hits, total))
    end
    return hits
end

--- For figures whose interest is the proportion rather than the count. `lo`/`hi`
--- are inclusive shares in [0,1].
function M.share(count, total, lo, hi, label, min_total)
    denominator(total, min_total, (label or 'share') .. ' denominator')
    local s = count / total
    if s < lo or s > hi then
        fail(string.format('%s: %d/%d = %.3f, outside the registered band %.3f..%.3f',
            label or 'share', count, total, s, lo, hi))
    end
    return s
end

return M
