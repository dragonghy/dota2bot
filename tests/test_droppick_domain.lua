-- [ratchet] [droppick 2026-09-04, 协同组] The domain pricing for the dropped-item
-- give-up mechanism in bots/mode_team_roam_generic.lua -- the one item GH #452
-- routed to this group and left unclaimed ("下一轮或谁先拿到").
--
-- ⭐ THE FINDING (reusable, larger than this subject).
-- WHEN A DEFECT HAS TWO HALVES AND ONLY ONE OF THEM IS VISIBLE, THE VISIBLE
-- HALF IS NOT THE CHEAPER HALF -- IT IS THE DECOY. Repairing it alone produces
-- a diff that reads like a fix, passes review, changes the source, and moves
-- NOTHING: measured here at 0 of 5932, which is the shipped number to the digit.
--
-- The mechanism. `ItemOpsThink` keeps `ignorePickupList` so an item the bot has
-- failed to reach three times is abandoned. Four lines run it:
--
--   :1771  if not J.Utils.SetContains(itemName) and ...             -- read
--   :1819  if tryPickCount >= 3 and not Utils.SetContains(itemName) -- read
--   :1821      Utils.AddToSet(ignorePickupList, PickedItem.item)    -- write
--   :1823  if not Utils.SetContains(itemName) and ...               -- read
--
-- against `function ____exports.SetContains(set, key)` (utils.lua:1260). Two
-- INDEPENDENT defects sit on those four lines:
--
--   (1) ARITY -- the visible half. All three reads pass one argument, so `set`
--       binds to the item NAME and `key` binds to nil. `("item_aegis")[nil]` is
--       a legal read through the string metatable and answers nil, so the gate
--       is constantly false. It does not raise, which is why nothing has ever
--       pointed at it: measured `shipped_raise` = 0 over 5932 real handles.
--   (2) TWO INDEX SPACES -- the invisible half. The write stores
--       `PickedItem.item`, a HANDLE, as the key; every read asks by NAME. So
--       the set is written in one index space and read in another, and adding
--       the missing first argument -- which is exactly what defect (1) looks
--       like it is asking for -- still never hits. (Third appearance of this
--       family after `0SLOT` and `slotarb`.)
--
-- ⭐⭐ THE THREE COLUMNS, driven through the REAL shipped AddToSet/SetContains
-- on all 5932 real item handles in the corpus (117 distinct names):
--
--   shipped   `SetContains(name)`                                 0 / 5932
--   argfix    `AddToSet(ig, handle)` then `SetContains(ig, name)` 0 / 5932
--   bothfix   `AddToSet(ig, name)`   then `SetContains(ig, name)` 5932 / 5932
--
-- `bothfix` is also this file's anti-vacuum control: the instrument is the same
-- shipped pair of functions in all three columns, and it demonstrably CAN say
-- "ignored" -- on every handle. So the two zeros are readings, not a stuck
-- probe. ⇒ THE REPAIR IS TWO-PART OR IT IS NOTHING, and a review that sees only
-- the arity half will sign off on a no-op.
--
-- ⭐⭐⭐ AND THE VALUE THE RETRY LOOP COMPUTES REACHES NOBODY (new here; #452
-- did not have this). `ItemOpsDesire` ends its dropped-item loop with
--   `if PickedItem ~= nil and GetItemCost(itemName) > minPickItemCost then
--        return RemapValClamped(...) end`
-- and its ONLY caller, GetDesireHelper:271, calls it as a bare statement and
-- throws the value away. So in the shipped tree that `return` is not a desire
-- at all -- it is purely a SKIP, and what it skips is the eight housekeeping
-- calls below it (TrySellOrDropItem, SwapSmokeSupport, and the six
-- TrySwapInvItemFor* routines) plus the `ConsiderDroppedTime = DotaTime()` that
-- re-arms the function's own 2-second throttle. Because `PickedItem` is
-- module-level and cleared only in OnEnd, and because the give-up set above is
-- inert, the condition that triggers that skip is sticky. Both facts are pinned
-- as source assertions below so a rewrite re-derives them instead of inheriting
-- this paragraph.
--
-- ⇒ NOTHING IS REPAIRED HERE and no id is opened -- for a reason that is
-- structural, not timid. Charter rule 2 requires a real-frame fixture for any
-- behaviour change, and the decision this code makes cannot be witnessed by
-- this corpus at any price: `GetDroppedItemList()` is `{}` in the mock and the
-- dumper writes no dropped-item record, measured 0 of 1012 live frames. What
-- the corpus DOES carry is every other precondition -- ItemOpsThink's own
-- inventory-room guard is satisfied on 983 of those 1012 frames -- so the
-- pricing names exactly one missing ingredient rather than a vague gap. That is
-- the deliverable: the shape of the repair (two-part), the size of the decoy
-- (0 of 5932), and the single dumper field that would unlock validation.
--
-- Same family as GH #492/#495: the honest answer to "which of these do we fix
-- next" can be "none of them yet, and here is the price of finding out".

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_droppick_sweep.lua'
local MODE = 'bots/mode_team_roam_generic.lua'
local UTILS = 'bots/FunLib/utils.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Every call to `name` in `src`, returned as a list of its top-level argument
-- lists. Balanced-paren scan rather than a pattern, because a pattern cannot
-- tell `SetContains(f(a, b))` (one argument) from `SetContains(a, b)` (two) and
-- the whole arity finding turns on that distinction.
local function calls_of(src, name)
    local found, at = {}, 1
    while true do
        local s, e = src:find(name .. '%s*%(', at)
        if s == nil then break end
        local depth, i, args, cur = 1, e + 1, {}, ''
        while i <= #src and depth > 0 do
            local ch = src:sub(i, i)
            if ch == '(' then depth = depth + 1; cur = cur .. ch
            elseif ch == ')' then
                depth = depth - 1
                if depth > 0 then cur = cur .. ch end
            elseif ch == ',' and depth == 1 then
                args[#args + 1] = cur:match('^%s*(.-)%s*$'); cur = ''
            else cur = cur .. ch end
            i = i + 1
        end
        cur = cur:match('^%s*(.-)%s*$')
        if cur ~= '' or #args > 0 then args[#args + 1] = cur end
        found[#found + 1] = { args = args, at = s }
        at = i
    end
    return found
end

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { c = {}, n = {}, done = false, names = 0 }
    for line in raw:gmatch('[^\n]+') do
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local nn, a, b, d, e = line:match('^N (%S+) (%d+) (%d+) (%d+) (%d+)$')
        if nn ~= nil then
            m.n[nn] = { n = tonumber(a), shipped = tonumber(b),
                        argfix = tonumber(d), bothfix = tonumber(e) }
            m.names = m.names + 1
        end
        if line == 'DONE' then m.done = true end
    end
    return m
end)()

local function C(key)
    local n = M.c[key]
    assert(n ~= nil, 'the sweep did not emit counter ' .. key
        .. ' -- an absent counter is not a zero')
    return n
end

tests['[sweep] the subprocess ran to completion'] = function()
    assert(M.done, 'tests/_droppick_sweep.lua did not print DONE -- every count '
        .. 'below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    cs.ratchet(C('handles'), 5932, 'real item handles driven through the set')
    cs.ratchet(C('names'), 117, 'distinct item names in the corpus')
    assert(M.names == C('names'), 'the sweep emitted ' .. M.names
        .. ' N-rows for a names counter of ' .. C('names')
        .. ' -- the per-name breakdown and its own total disagree')
end

-- ------------------------------------------------ the decoy, in numbers ----

tests['[pricing] the one-line arity repair is a measured no-op'] = function()
    -- The whole finding. `argfix` is line 1821 verbatim plus line 1823 with its
    -- missing first argument supplied -- the diff a reviewer would call the fix
    -- -- and it reports "ignored" exactly as often as the unrepaired tree does.
    assert(C('shipped_ignored') == 0, 'the shipped one-argument gate now reports '
        .. C('shipped_ignored') .. ' items as ignored (was 0 of '
        .. C('handles') .. ') -- defect (1) moved; re-read the pricing')
    assert(C('argfix_ignored') == 0, 'supplying the missing first argument now '
        .. 'hits on ' .. C('argfix_ignored') .. ' handles -- the two index '
        .. 'spaces claim is no longer true and the "two-part repair" verdict '
        .. 'must be re-read, not re-baselined')
    assert(C('names_argfix_ever_ignored') == 0,
        C('names_argfix_ever_ignored') .. ' item name(s) are now reachable via '
        .. 'the handle-keyed set -- same re-read')
    -- Neither zero is a raise being scored as a no (GH #492, three-valued).
    assert(C('shipped_raise') == 0 and C('argfix_raise') == 0,
        'the set probes started raising (' .. C('shipped_raise') .. '/'
        .. C('argfix_raise') .. ') -- a raise is not a measured no, and these '
        .. 'columns would be silently losing handles from their denominator')
end

tests['[control] the instrument can say "ignored" -- on every handle'] = function()
    -- Anti-vacuum for the two zeros above, and the positive half of the finding:
    -- key the set by what the readers ask for and it works everywhere. Same
    -- shipped AddToSet/SetContains, same handles, one changed index space.
    cs.universal(C('bothfix_ignored'), C('handles'),
        'handles the name-keyed set recognises', 5932)
    assert(C('bothfix_raise') == 0, 'the control column raised on '
        .. C('bothfix_raise') .. ' handles -- it is no longer a control')
    cs.ratchet(C('names_bothfix_always_ignored'), 117,
        'item names the name-keyed set recognises on every handle')
end

-- --------------------------------------- what the corpus cannot witness ----

tests['[domain] the decision is unbuyable here; everything around it is not'] = function()
    -- The ceiling on the whole ItemOps family: without a drop, `PickedItem` is
    -- never set, so neither ItemOpsDesire's early return nor ItemOpsThink's
    -- body is reachable on any frame this repository holds.
    -- ...and the instrument asked the engine getter the shipped tree reads,
    -- rather than a stand-in that would answer 0 without ever asking. A zero
    -- whose provenance is "nobody looked" is the one reading this whole file
    -- would be worthless without.
    local shipped_reads = read_file(MODE):find('GetDroppedItemList()', 1, true)
    assert(shipped_reads ~= nil, MODE .. ' no longer reads GetDroppedItemList '
        .. '-- the domain this file prices is not the one bots/ decides on')
    assert(read_file('tests/_droppick_sweep.lua'):find('pcall(GetDroppedItemList)',
        1, true) ~= nil, 'the sweep no longer probes GetDroppedItemList itself '
        .. '-- drop_frames would be 0 because nothing asked, which is not a '
        .. 'measurement')
    cs.ceiling(C('drop_frames'), 0, 'live frames carrying a dropped item')
    assert(C('drop_raise') == 0, 'GetDroppedItemList raised on '
        .. C('drop_raise') .. ' frames -- the 0 above would be a broken probe '
        .. 'rather than an empty world')
    -- ...and the contrast that makes the 0 actionable rather than vague: every
    -- OTHER precondition ItemOpsThink needs is carried by the corpus already.
    cs.ratchet(C('invroom_frames'), 983, 'live frames with inventory room')
    cs.share(C('invroom_frames'), C('live'), 0.90, 1.00,
        'share of live frames satisfying ItemOpsThink inventory guard', 1012)
end

-- ------------------------------------------------- the source it rests on --

tests['[source] three one-argument reads against a two-parameter set API'] = function()
    local utils = read_file(UTILS)
    local decl = utils:match('function%s+____exports%.SetContains%s*%(([^)]*)%)')
    assert(decl ~= nil, UTILS .. ' no longer declares SetContains -- the arity '
        .. 'finding has no subject')
    assert(decl:match('^%s*set%s*,%s*key%s*$') ~= nil,
        'SetContains is now declared (' .. decl .. ') -- this file prices a '
        .. '(set, key) API; re-derive the arity finding')

    local mode = read_file(MODE)
    local reads = calls_of(mode, 'SetContains')
    assert(#reads == 3, MODE .. ' now has ' .. #reads .. ' SetContains call '
        .. 'sites (was 3) -- the pricing counted three and must be re-run')
    for _, call in ipairs(reads) do
        assert(#call.args == 1, 'a SetContains call site now passes '
            .. #call.args .. ' arguments -- defect (1) is being repaired, and '
            .. 'per this file that alone changes nothing; land the index-space '
            .. 'half in the same change or re-read the pricing')
    end
end

tests['[source] the set is written by handle and never read by that key'] = function()
    local mode = read_file(MODE)
    local writes = calls_of(mode, 'AddToSet')
    assert(#writes == 1, MODE .. ' now has ' .. #writes .. ' AddToSet call '
        .. 'sites (was 1) -- re-derive which index space the set is keyed in')
    assert(writes[1].args[1] == 'ignorePickupList' and #writes[1].args == 2,
        'the AddToSet write no longer targets ignorePickupList with two '
        .. 'arguments -- re-read')
    assert(writes[1].args[2]:find('%.item$') ~= nil,
        'the ignore set is no longer keyed by an item HANDLE (key is now "'
        .. writes[1].args[2] .. '") -- defect (2) moved')
    -- The set is write-only: it appears at its declaration and at that one
    -- write, and at no read. That is the whole give-up mechanism, inert.
    local n = 0
    for _ in mode:gmatch('ignorePickupList') do n = n + 1 end
    assert(n == 2, 'ignorePickupList now appears ' .. n .. ' times (was 2: one '
        .. 'declaration, one write, zero reads) -- if it gained a reader the '
        .. '"write-only set" half of this finding is stale')
end

tests['[source] the retry loop returns a desire its only caller discards'] = function()
    local mode = read_file(MODE)
    -- Exactly one call site, and it is a bare statement: no assignment, no
    -- `return`, no enclosing expression. So the RemapValClamped value computed
    -- inside the dropped-item loop reaches nobody and that `return` is only a
    -- skip of the eight housekeeping calls below it.
    local sites = {}
    for line in mode:gmatch('[^\n]+') do
        if line:find('ItemOpsDesire%s*%(') and line:find('^%s*function') == nil then
            sites[#sites + 1] = line:match('^%s*(.-)%s*$')
        end
    end
    assert(#sites == 1, 'ItemOpsDesire now has ' .. #sites .. ' call sites '
        .. '(was 1) -- re-derive whether its return value reaches anyone')
    assert(sites[1] == 'ItemOpsDesire()', 'the ItemOpsDesire call site is now "'
        .. sites[1] .. '" -- it used to be a bare statement that discards the '
        .. 'desire; if it now consumes the value, the "the return is only a '
        .. 'skip" half of this finding is stale')
    -- And the thing that skip costs: the housekeeping tail of the same
    -- function, which the early `return` jumps over.
    for _, fn in ipairs({ 'TrySellOrDropItem', 'SwapSmokeSupport',
        'TrySwapInvItemForCheese', 'TrySwapInvItemForRefresherShard',
        'TrySwapInvItemForClarity', 'TrySwapInvItemForFlask',
        'TrySwapInvItemForSmoke', 'TrySwapInvItemForMoonshard' }) do
        assert(mode:find('\n    ' .. fn .. '()', 1, true) ~= nil,
            fn .. ' is no longer a tail call of ItemOpsDesire -- the list of '
            .. 'what the early return starves is out of date')
    end
end

return tests
