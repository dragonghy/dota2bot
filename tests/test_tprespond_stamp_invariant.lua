-- [director, GH #37 admission review] Every TP-response commitment must also
-- write the `tpRespondAlly` stamp, in the same block.
--
-- `tpdead` releases a landing commitment when the ally it answered for is
-- dead. It tells "rescue" apart from "answer a place" by the stamp alone:
-- the rescue branch sets bot.tpRespondAlly, and the two place-answering
-- response TPs clear it. If a commitment site ever sets tpRespondUntil
-- WITHOUT touching the stamp, a corpse left over from an earlier rescue
-- releases a commitment that has nothing to do with it -- the tower-defend
-- responder walks away from a fight that is still happening, and (per the
-- house rule: no bot-side debugging) it does so silently.
--
-- That is the `hTargetCreep` defect shape from GH #39 exactly: cross-frame
-- state with an incomplete reset. The code is correct as written today --
-- all three writers do pair the two -- but the pairing was UNASSERTED:
-- deleting BOTH stamp-clearing lines failed zero tests. This test closes
-- that hole.
--
-- SOURCE-LEVEL on purpose, same reasoning as GH #29's chain-order test: a
-- behavioural fixture can only prove the pairing for the sites it happens
-- to drive, while the invariant has to hold for the fourth commitment site
-- somebody adds next month -- which is precisely the one no fixture exists
-- for yet.

local SOURCE = 'bots/ability_item_usage_generic.lua'
local READER = 'bots/FunLib/jmz_func.lua'

-- How far from the `tpRespondUntil` assignment the paired stamp write may
-- sit. The three shipped sites all keep them within 6 lines; the window is
-- deliberately tight so "somewhere else in the function" does not count.
local WINDOW = 10

local function read_lines(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local out = {}
    for line in fh:lines() do out[#out + 1] = line end
    fh:close()
    return out
end

local function is_code(line)
    local code = line:match('^%s*(.-)%s*$')
    return code ~= '' and not code:match('^%-%-')
end

-- Commitment sites: `bot.tpRespondUntil = <something other than nil>`.
-- The nil-clears inside the release paths are not commitments.
local function commitment_sites(lines)
    local out = {}
    for i, line in ipairs(lines) do
        if is_code(line) then
            local rhs = line:match('bot%.tpRespondUntil%s*=%s*(.+)$')
            if rhs and not rhs:match('^nil%s*$') then
                out[#out + 1] = { line = i, text = line:match('^%s*(.-)%s*$') }
            end
        end
    end
    return out
end

local function stamp_written_near(lines, at)
    for i = math.max(1, at - WINDOW), math.min(#lines, at + WINDOW) do
        if is_code(lines[i]) and lines[i]:match('bot%.tpRespondAlly%s*=') then
            return i
        end
    end
    return nil
end

local tests = {}

tests['the commitment sites are findable and non-trivial'] = function()
    local sites = commitment_sites(read_lines(SOURCE))
    assert(#sites >= 3, ('expected >= 3 TP-response commitment sites in %s, found %d ' ..
        '(pattern changed, or the commitments were gutted -- this test must not ' ..
        'pass vacuously)'):format(SOURCE, #sites))
end

tests['every TP-response commitment also writes the tpRespondAlly stamp'] = function()
    local lines = read_lines(SOURCE)
    for _, site in ipairs(commitment_sites(lines)) do
        local at = stamp_written_near(lines, site.line)
        assert(at, ('%s:%d sets a TP-response commitment (%s) without writing ' ..
            'bot.tpRespondAlly within %d lines. Set it to the rescued ally, or ' ..
            'clear it to nil if this commitment answers a PLACE rather than a ' ..
            'named ally. Leaving it alone lets a corpse from an earlier rescue ' ..
            'release this commitment (tpdead, GH #37).'):format(
            SOURCE, site.line, site.text, WINDOW))
    end
end

tests['the stamp still has a reader, so the invariant still matters'] = function()
    -- If tpdead is ever promoted or dropped this assertion is the thing that
    -- forces someone to re-read the invariant above rather than leave a rule
    -- guarding nothing.
    local fh = assert(io.open(READER, 'r'), 'cannot open ' .. READER)
    local src = fh:read('*a')
    fh:close()
    assert(src:find('bot%.tpRespondAlly'), (
        '%s no longer reads bot.tpRespondAlly. If the stamp lost its consumer, ' ..
        'delete the stamp and this test together; if it moved, point READER at ' ..
        'the new home.'):format(READER))
end

return tests
