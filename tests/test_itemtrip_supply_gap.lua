-- [itemtrip] GH #120: 643 home TPs made at high HP, of which ~76 (11.8%,
-- 0.27/game) have no branch in bots/ that can explain them -- healthy heroes
-- walking home to combine an item, ~40s round trips in a ~600s Turbo game.
-- The desk's lead: BOT_MODE_ITEM is Valve's built-in implementation ("go fetch
-- your stash"), because the tree's own item-mode file is named
-- `bots/--mode_item_generic.lua` and the engine loads mode scripts by name.
--
-- ⚠️ CITATION CORRECTED IN FLIGHT. This file was drafted against #120's
-- BEARING FRAME (lina `20260822_123136_slot3 t=434.6`, described there as full
-- HP with a permanently empty ninth slot). The replay desk delivered that
-- fixture at 22:50Z (commit 70aefe5) and its own 0.1s replay OVERTURNED it:
-- the courier's claymore lands on t=434.6, pushing tango into slot 9, and the
-- `ITEM item_tpscroll` event is on THAT SAME TICK -- so `X.IsInvFull` is true
-- at the decision instant and the trip is the ordinary `shop` branch after
-- all. The second bearing frame (crystal_maiden `121409_slot8 t=526.2`) is
-- digit-for-digit the same shape. 2 of 2 bearing frames flipped: a 1Hz blind
-- window landing on a BOOLEAN gate does not bias a percentage, it flips a
-- label. Their re-scan of one full run puts the artefact rate in the residual
-- at single-digit percent, so the POPULATION survives while the two exhibits
-- do not.
--
-- Nothing below rests on those two frames. A, B and C are source and corpus
-- facts, and they are why this file is still the right pre-flight for whatever
-- the re-derived population turns out to be. But the head of #120 should be
-- read with the correction attached, and "inventory occupancy" -- one of the
-- four inputs this file rules IN below -- is now known to need a sub-second
-- read to be trusted at the decision instant.
--
-- This file is the reachability audit charter 0RES demands BEFORE an
-- interceptor gets written: grep the tree for the defect's remedy verb, then
-- judge the remedy's REACHABILITY rather than its existence. It ships no
-- bots/ change. What it establishes, in order:
--
--   A. The remedy really is absent -- but not for the reason anyone assumed.
--      Eight sites in bots/ already branch on `BOT_MODE_ITEM`. Five are
--      hero-specific (lone druid bear / arc warden tempest double / meepo
--      clone), three are POST-ARRIVAL cleanup (get out of the fountain again,
--      pick up the dropped item, unstick an idle bot). ZERO contest the
--      decision to make the trip. So #120's defect is un-remedied -- unlike
--      GH #123, where a factory rescuer was running every frame and nobody
--      had looked. The difference is measured below, not assumed.
--
--   B. The gate for a future `itemtrip` must be the LOAD-TIME one, and this
--      matters more than it sounds. docs/BOT_API_REFERENCE.md:52 states that
--      `GetDesire()` returning nil falls through to Valve's built-in desire.
--      If that contract is true, a gated mode file could return nil when
--      unarmed. It has ZERO users in this tree (asserted below: no GetDesire
--      body in bots/ contains a literal `return nil`), so it is an
--      UNDISCHARGED documentation claim, and the cost of it being wrong is
--      not a dead branch but the opposite: item mode silently suppressed in
--      every game, unarmed, ungated -- a shipped behaviour change wearing a
--      gate's clothes. The contract-free gate needs no contract at all: a file
--      that never DEFINES GetDesire leaves the engine nothing to call, so it
--      keeps its built-in -- and that is not an inference. bots/
--      mode_attack_generic.lua installs GetDesire/Think/OnStart/OnEnd only for
--      the nine heroes in Utils.BuggyHeroesDueToValveTooLazy, and the other
--      ~118 heroes attack anyway. A per-hero, load-time conditional override
--      is therefore already running in every game we ship. And that is not
--      only read off source: tests/test_tpwatch_channel_bid.lua loads all 21
--      mode files on a real frame and asserts `#engine_owned >= 1` -- at least
--      one of them installs no script GetDesire, naming mode_attack_generic as
--      the reason. An independent desk measured the mechanism before this file
--      needed it. Both facts are pinned here so the next author picks the safe
--      gate on purpose.
--
--   C. THE EIGHTEENTH WORLD ASSERTION: there is no courier in the fixture
--      world, and the shipped courier code does not merely go blind on it --
--      it CRASHES. `GetCourier()` answers nil for all five ids
--      (tests/mock/bot_api.lua), so `X.GetBotCourier`'s
--      `courier:GetPlayerID()` indexes nil on its first iteration, i.e. all
--      ~140 lines of CourierUsageComplement (every stash fetch, every
--      delivery, the secret-shop trip) are UNRUNNABLE on every frame of the
--      corpus. `GetCourierState` is not even auto-defined -- it is mixed
--      case, so the mock's ALL_CAPS constant metatable skips it and it reads
--      nil, a call-a-nil-value crash. And `bot:GetStashValue()` /
--      `bot:GetCourierValue()` answer the generic `Get* -> 0`, so every
--      stash-valued clause is CONSTANT FALSE on real frames.
--
-- WHAT THAT COSTS #120, stated as a verdict so nobody has to re-derive it:
-- `itemtrip` is writable and gateable, but its decision clause MUST NOT read
-- stash contents, courier state, or `bot:GetActiveMode()` (the thirteenth
-- world assertion: 0 on every hero on every frame). Every one of those is
-- structurally unanswerable here, and a clause built on one runs fast, green,
-- and all-zero -- charter 0p's shape, and the same trap
-- test_fieldbuy_backpack_rescuer.lua exists to keep shut. The inputs that ARE
-- on a real frame -- HP, nearest enemy, distance from fountain, inventory
-- occupancy -- are the whole budget a fixture-validated itemtrip may spend.
--
-- Honest bounds, stated first:
--   * "ZERO sites contest the trip" is a claim about the eight `BOT_MODE_ITEM`
--     comparison sites, classified by tokens in a +-window of source. A remedy
--     that never names the mode (say, a farm-desire bump that happens to
--     outbid item mode) would not be in this census and is not excluded by it.
--   * The census does not claim the three post-arrival sites are useless --
--     `mode_roam_generic:1335`'s own comment says "is stuck in item mode", so
--     the tree already knew item mode drags heroes home. It handles the tail.
--   * Nothing here measures how often the built-in item mode WINS the auction.
--     That number is #120's own 0.27/game, bought off batch replays; it cannot
--     be re-derived from fixtures, because a fixture does not carry a mode.
--   * C is measured over the whole fixture corpus, one loaded frame per fixture
--     (the subject hero). It is a property of the mock rather than of any
--     frame, so one load per fixture is the measurement, not a sample of a
--     larger one. Counts are compared to the corpus size measured in the same
--     run, never to a literal (GH #106); a floor catches shrinkage.
--   * This file drives no mode bid -- it reads mode files as TEXT. The census
--     discovers its own file list by grep for that reason as much as for
--     staleness: a hardcoded list naming a defence-ping-guarded mode makes
--     test_defend_ping_declaration_ratchet.lua read this file as a bid driver
--     (its detector is textual: "mentions GetDesire and names a guarded mode").
--     That ratchet is right to be textual and was not touched; the census was
--     made to discover instead, which is the better shape anyway.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

local function exists(path)
    local fh = io.open(path, 'r')
    if fh then fh:close() return true end
    return false
end

local function lines_of(path)
    local out = {}
    for l in io.lines(path) do out[#out + 1] = l end
    return out
end

local function ls(dir, pattern)
    local p = assert(io.popen('ls "' .. dir .. '"'))
    local out = {}
    for f in p:lines() do
        if f:match(pattern) then out[#out + 1] = f end
    end
    p:close()
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------------------
-- A. The census: who in bots/ already branches on BOT_MODE_ITEM, and what for.
-- ---------------------------------------------------------------------------

-- Every file that compares against the mode, DISCOVERED rather than listed.
-- A hardcoded list would have gone stale the moment somebody added a branch in
-- a file not on it -- which is the one event this census exists to catch -- and
-- it would have been the census reporting "still 8, still none contesting".
-- ts_libs/ is excluded on purpose: its two hits are the TypeScript enum
-- table's own definition (`BotMode.Item = BOT_MODE_ITEM or 21`), not a branch.
local function mode_item_files()
    local p = assert(io.popen('grep -rl BOT_MODE_ITEM bots --include=*.lua'))
    local out = {}
    for f in p:lines() do
        if not f:find('ts_libs', 1, true) then out[#out + 1] = f end
    end
    p:close()
    table.sort(out)
    return out
end

-- Lookback is 14 lines because two of the farm sites sit inside a hero block
-- whose header (`modifier_arc_warden_tempest_double`, `J.IsMeepoClone(bot)`)
-- is 10-11 lines above the comparison. Lookahead is 4 because the roam sites
-- carry their hero list on the line AFTER the comparison.
local LOOKBACK, LOOKAHEAD = 14, 4

local function census()
    local sites = {}
    for _, path in ipairs(mode_item_files()) do
        local lines = lines_of(path)
        for i, line in ipairs(lines) do
            -- Comment lines are skipped, added 2026-08-23 when this census
            -- read its own successor's head comment as three new branch sites.
            -- It is the SAME textual-detector failure this file's §5之二 fixed
            -- in the defend-ping ratchet's favour, arriving from the other
            -- direction: a census of BRANCHES must not count prose that names
            -- the constant. Trailing comments are left alone -- a line with
            -- code on it is a site regardless of what follows the `--`.
            if line:find('BOT_MODE_ITEM', 1, true)
                and not line:match('^%s*%-%-') then
                local w = {}
                for j = math.max(1, i - LOOKBACK), math.min(#lines, i + LOOKAHEAD) do
                    w[#w + 1] = lines[j]
                end
                local win = table.concat(w, '\n')
                local cls
                if win:find('lone_druid') or win:find('tempest_double')
                    or win:find('IsMeepoClone') then
                    cls = 'HERO_SPECIFIC'
                elseif win:find('DistanceFromFountain') or win:find('GetDroppedItemList')
                    or win:find('BOT_ACTION_TYPE_IDLE') then
                    cls = 'POST_ARRIVAL'
                else
                    cls = 'CONTESTS_TRIP'
                end
                sites[#sites + 1] = { where = path .. ':' .. i, cls = cls }
            end
        end
    end
    return sites
end

local function count_cls(sites, cls)
    local n = 0
    for _, s in ipairs(sites) do if s.cls == cls then n = n + 1 end end
    return n
end

tests['[census] all 8 BOT_MODE_ITEM branches, and 0 of them contest the trip'] = function()
    local sites = census()
    assert(#sites == 8, 'BOT_MODE_ITEM branch sites moved from 8 to ' .. #sites)
    assert(count_cls(sites, 'HERO_SPECIFIC') == 5,
        'hero-specific sites moved from 5 to ' .. count_cls(sites, 'HERO_SPECIFIC'))
    assert(count_cls(sites, 'POST_ARRIVAL') == 3,
        'post-arrival sites moved from 3 to ' .. count_cls(sites, 'POST_ARRIVAL'))
    -- THE LOAD-BEARING ROW. This is the whole difference between #120 and
    -- #123: there, a factory remedy was running every frame; here there is
    -- none, and that is measured rather than assumed. If this ever turns red
    -- because someone added a general-hero item-mode branch, the head comment
    -- of this file is out of date and #120's verdict must be re-derived.
    local contest = count_cls(sites, 'CONTESTS_TRIP')
    if contest ~= 0 then
        local names = {}
        for _, s in ipairs(sites) do
            if s.cls == 'CONTESTS_TRIP' then names[#names + 1] = s.where end
        end
        error('a branch now contests the item-mode trip itself: '
            .. table.concat(names, ', ') .. ' -- re-read this file\'s head comment')
    end
    -- ...and the contest that DOES now exist is not in this census, which is a
    -- statement about what the census measures rather than a loophole. It
    -- counts sites that COMPARE against BOT_MODE_ITEM; the interceptor written
    -- on 2026-08-23 is the item mode -- bots/mode_item_generic.lua, whose bid
    -- the engine only asks for while it is already considering that mode -- so
    -- it never needs to name the constant. Asserted here so "0 contest it"
    -- cannot be read as "nothing contests the trip" after this round.
    assert(exists('bots/mode_item_generic.lua'),
        'the itemtrip interceptor is gone, and with it the only thing that '
        .. 'contests this trip; 0 CONTESTS_TRIP now means what it said in #120')
end

tests['[census] the three general-hero branches are all post-arrival'] = function()
    -- Named individually, because "3" alone would survive one of them being
    -- replaced by something that acts BEFORE the trip -- which is exactly the
    -- change that should force a re-read, and which the count cannot see.
    local sites = census()
    local post = {}
    for _, s in ipairs(sites) do
        if s.cls == 'POST_ARRIVAL' then post[s.where:match('^(.*):%d+$')] = true end
    end
    assert(post['bots/mode_roam_generic.lua'],
        'the roam fountain-exit / dropped-item pair is no longer classified post-arrival')
    assert(post['bots/FunLib/jmz_func.lua'],
        'the idle-unstick handler is no longer classified post-arrival')
    -- The tree's own words for what site 1335 is doing. Quoted from source so
    -- that "the tree already knew item mode drags heroes home" stays a fact.
    local src = read_file('bots/mode_roam_generic.lua')
    assert(src:find('is stuck in item mode', 1, true),
        'mode_roam_generic no longer says "is stuck in item mode"')
end

-- ---------------------------------------------------------------------------
-- B. What a future itemtrip may gate on -- and what it must not.
-- ---------------------------------------------------------------------------

tests['[reverse] the loadable item-mode file bids only when armed'] = function()
    -- UPDATED 2026-08-23, by the round this file was written to gate: the
    -- interceptor landed, so bots/mode_item_generic.lua now exists and the
    -- original form of this assertion ("it must not exist") has been retired
    -- deliberately rather than quietly. What it was protecting is NOT retired:
    -- #120's premise is that BOT_MODE_ITEM is Valve's built-in bid, and that
    -- premise still holds in every game where the soak id is not armed --
    -- because the new file installs no GetDesire at all until then. So the
    -- assertion moves from "the file is absent" to "the file cannot bid
    -- unarmed", which is the property #120's premise actually rests on.
    assert(exists('bots/mode_item_generic.lua'),
        'bots/mode_item_generic.lua is gone -- the itemtrip interceptor was '
        .. 'reverted; say so here rather than leaving this test asserting a '
        .. 'file that no longer exists')
    local live = read_file('bots/mode_item_generic.lua')
    local gate_at = live:find("J.IsSoakCandidate( 'itemtrip' )", 1, true)
    local bid_at = live:find('function GetDesire', 1, true)
    assert(gate_at ~= nil, 'the itemtrip load-time gate is gone from the item-mode file')
    assert(bid_at ~= nil, 'the item-mode file no longer defines GetDesire')
    -- The ORDER is the gate. A GetDesire defined above the armed check is
    -- defined in every game, armed or not, and that is a shipped behaviour
    -- change wearing a gate's clothes -- the exact failure this file was
    -- written to keep shut.
    assert(gate_at < bid_at,
        'GetDesire is defined BEFORE the armed check in bots/mode_item_generic.lua '
        .. '-- unarmed games would then get a script bid instead of the engine\'s')
    -- ...and the check has to actually stop the load, not merely be mentioned.
    local head = live:sub(1, bid_at)
    assert(head:find("if not J.IsSoakCandidate( 'itemtrip' ) then return end", 1, true),
        'the armed check no longer returns out of the file scope, so the '
        .. 'unarmed load does not stop before GetDesire is defined')
    assert(exists('bots/--mode_item_generic.lua'),
        'the disabled item-mode file is gone; #120\'s lead was built on it')
    local src = read_file('bots/--mode_item_generic.lua')
    -- Whoever wrote it disabled item mode outright and then disabled the FILE
    -- by renaming it. Un-prefixing it is therefore not a small step: it is an
    -- ungated, team-wide "item mode never bids", for every hero, in every game
    -- mode -- the exact opposite of ships-dark.
    assert(src:find('function GetDesire', 1, true), 'the dead file lost its GetDesire')
    assert(src:find('BOT_MODE_DESIRE_NONE', 1, true),
        'the dead file no longer returns BOT_MODE_DESIRE_NONE, so the reason it '
        .. 'is dangerous to un-prefix has changed')
end

tests['[reverse] nil-fallthrough is documented and has zero users in bots/'] = function()
    local doc = read_file('docs/BOT_API_REFERENCE.md')
    assert(doc:find('Returning nil from `GetDesire()`', 1, true),
        'the nil-fallthrough contract left BOT_API_REFERENCE; if it was deleted '
        .. 'because it is false, say so here')
    -- UPDATED 2026-08-23: the count moved 0 -> 1, and the one user is the
    -- itemtrip file this round landed. That is a change of KIND, so it is
    -- named rather than re-baselined: the contract is still undischarged (no
    -- shipped game exercises it, because the only user is behind a load-time
    -- soak gate), but it is now REACHABLE -- an armed wave will discharge it
    -- one way or the other, and the item-mode file's head comment registers
    -- both outcomes in advance.
    --
    -- Why the contract may never be used as a GATE regardless of how that
    -- turns out: a gate built on it fails OPEN (item mode suppressed in every
    -- shipped game) rather than closed. itemtrip therefore uses it only INSIDE
    -- an already-armed bid, where being wrong costs the armed side of one wave.
    local users = {}
    for _, f in ipairs(ls('bots', '^%-?%-?mode_.*_generic%.lua$')) do
        local body = read_file('bots/' .. f):match('\nfunction GetDesire%(%)(.-)\nend')
        if body and body:find('return%s+nil') then users[#users + 1] = f end
    end
    assert(#users == 1 and users[1] == 'mode_item_generic.lua',
        'the nil-fallthrough contract users moved to {' .. table.concat(users, ', ')
        .. '} -- exactly one user is expected (mode_item_generic.lua, gated on '
        .. 'itemtrip). A second user means somebody spent an undischarged engine '
        .. 'contract somewhere new; read this file\'s head comment first')
end

tests['[reverse] the contract-free gate already ships: mode_attack defines GetDesire conditionally'] = function()
    -- The strongest corroboration in the tree, and it is not an idiom -- it is
    -- a live, per-hero, load-time conditional override running in every game.
    -- bots/mode_attack_generic.lua defines GetDesire/Think/OnStart/OnEnd ONLY
    -- for the nine heroes in Utils.BuggyHeroesDueToValveTooLazy. For every
    -- other hero the file installs no entry points at all -- and those heroes
    -- still attack, so "define nothing => the engine keeps its built-in" is
    -- not a documentation claim here, it is observed behaviour that ships.
    -- That is the gate an itemtrip must use: arm the candidate at file scope,
    -- define GetDesire only when armed, and the unarmed game is byte-for-byte
    -- today's game without the nil-fallthrough contract ever being invoked.
    local src = read_file('bots/mode_attack_generic.lua')
    local guard = src:find('if local_mode_attack_generic ~= nil then', 1, true)
    local def = src:find('function GetDesire%(%)')
    assert(guard and def and guard < def,
        'mode_attack_generic no longer defines GetDesire behind a runtime guard '
        .. '-- the contract-free gate lost its shipped precedent')
    assert(src:find('BuggyHeroesDueToValveTooLazy', 1, true),
        'the per-hero condition on that override is gone')
    -- Corroborated by execution, not just by reading: tpwatch loads every mode
    -- file on a real frame and requires at least one to install no GetDesire.
    local tp = read_file('tests/test_tpwatch_channel_bid.lua')
    assert(tp:find('#engine_owned >= 1', 1, true),
        'test_tpwatch_channel_bid no longer asserts that some mode file installs '
        .. 'no script GetDesire -- that assertion is the executed half of this '
        .. 'file\'s claim, and without it only the source reading is left')
    -- Nine heroes get the override; everyone else runs Valve's built-in attack
    -- desire. If the table ever grew to cover the roster, the corroboration
    -- would weaken to "every hero is overridden anyway" -- so pin the count.
    local utils = read_file('bots/FunLib/utils.lua')
    local body = utils:match('BuggyHeroesDueToValveTooLazy = {(.-)}')
    assert(body, 'the buggy-hero table moved out of utils.lua')
    local n = 0
    for _ in body:gmatch('%[HeroName%.') do n = n + 1 end
    assert(n == 9, 'the buggy-hero table moved from 9 heroes to ' .. n)
end

tests['[census] 11 mode files already return at file scope before defining GetDesire'] = function()
    -- The same mechanism at the file level, counted so the next author can see
    -- it is ordinary rather than clever. mode_attack_generic is excluded from
    -- this count on purpose: it never defines GetDesire, so it has no anchor
    -- and is the subject of the test above instead.
    local n = 0
    for _, f in ipairs(ls('bots', '^mode_.*_generic%.lua$')) do
        local head = read_file('bots/' .. f)
        local before = head:match('^(.-)\nfunction GetDesire%(%)')
        if before and before:find('then return end', 1, true) then n = n + 1 end
    end
    -- A FLOOR, not an equation (GH #127: seven files went red at once the last
    -- time a growable population was pinned as `== N`). 11 when this file was
    -- written, 12 once bots/mode_item_generic.lua landed and used the same
    -- mechanism as its gate. Another mode file adopting the idiom should make
    -- this census stronger, not red.
    assert(n >= 12, 'mode files with a head early-return before GetDesire fell to ' .. n
        .. ' -- the idiom this file calls ordinary is disappearing from the tree')
    local head = read_file('bots/mode_item_generic.lua')
    assert(head:match('^(.-)\nfunction GetDesire%(%)'):find('then return end', 1, true),
        'the itemtrip gate is no longer one of these file-scope early returns')
end

-- ---------------------------------------------------------------------------
-- C. The eighteenth world assertion: no courier exists in the fixture world.
-- ---------------------------------------------------------------------------

local swept
local function sweep()
    if swept then return swept end
    local c = { fixtures = 0, frames = 0, stash_zero = 0, couriervalue_zero = 0,
                activemode_zero = 0, courier_nil = 0, getbotcourier_error = 0 }
    for _, f in ipairs(ls('tests/fixtures', '^f_.*%.lua$')) do
        local path = 'tests/fixtures/' .. f
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            c.fixtures = c.fixtures + 1
            local subject
            for _, u in ipairs(fx.units) do
                if u.alive then subject = u.name break end
            end
            if subject then
                local _, bot = rf.load(path, subject)
                c.frames = c.frames + 1
                if bot:GetStashValue() == 0 then c.stash_zero = c.stash_zero + 1 end
                if bot:GetCourierValue() == 0 then
                    c.couriervalue_zero = c.couriervalue_zero + 1
                end
                if bot:GetActiveMode() == 0 then
                    c.activemode_zero = c.activemode_zero + 1
                end
                local all_nil = true
                for i = 0, 4 do if GetCourier(i) ~= nil then all_nil = false end end
                if all_nil then c.courier_nil = c.courier_nil + 1 end
                -- The shipped loop, verbatim in shape
                -- (ability_item_usage_generic.lua:768-775): it indexes the
                -- handle before testing it.
                local ok = pcall(function()
                    for i = 0, 4 do
                        local courier = GetCourier(i)
                        if courier:GetPlayerID() == bot:GetPlayerID() then return courier end
                    end
                end)
                if not ok then c.getbotcourier_error = c.getbotcourier_error + 1 end
            end
        end
    end
    swept = c
    return c
end

-- Every count below is asserted against the corpus size MEASURED IN THE SAME
-- RUN, never against a literal. GH #106 is the reason: corpus sizes pinned as
-- equations make adding a fixture a destructive change across every consumer,
-- and this file would have been consumer number six. It nearly was -- the first
-- version pinned 100, and a rebase landing a 101st fixture turned it red inside
-- the hour, which is the whole of #106 reproduced in miniature. A floor is kept
-- so that the corpus SHRINKING is still caught; only growth is free.
local FLOOR = 100

tests['[world] the courier is absent on every fixture, and reading it crashes'] = function()
    local c = sweep()
    assert(c.fixtures >= FLOOR, 'the fixture corpus SHRANK below ' .. FLOOR
        .. ' (now ' .. c.fixtures .. ') -- growth is free here, loss is not')
    assert(c.frames == c.fixtures,
        'some fixture no longer yields a loadable live subject: ' .. c.frames
        .. ' of ' .. c.fixtures)
    assert(c.courier_nil == c.frames,
        'GetCourier() now answers a handle on ' .. (c.frames - c.courier_nil)
        .. ' fixture(s) -- the courier layer may have become testable')
    -- Not "blind": UNRUNNABLE. X.GetBotCourier is the first thing
    -- CourierUsageComplement does when bot.theCourier is nil, so all ~140
    -- lines below it -- COURIER_ACTION_TAKE_STASH_ITEMS included, the one
    -- remedy that could drain a stash without walking the hero home -- cannot
    -- be reached by any fixture test written today.
    assert(c.getbotcourier_error == c.frames,
        'the shipped GetBotCourier loop now survives on '
        .. (c.frames - c.getbotcourier_error) .. ' fixture(s)')
end

tests['[world] every stash-valued clause is constant-false on a real frame'] = function()
    local c = sweep()
    assert(c.stash_zero == c.frames, 'bot:GetStashValue() is no longer 0 everywhere: '
        .. c.stash_zero .. ' of ' .. c.frames)
    assert(c.couriervalue_zero == c.frames,
        'bot:GetCourierValue() is no longer 0 everywhere: '
        .. c.couriervalue_zero .. ' of ' .. c.frames)
    -- Cited, not re-derived: the thirteenth world assertion
    -- (tests/test_activemode_world_assertion.lua) owns this one. It is
    -- re-counted here only because an itemtrip author will reach for
    -- GetActiveMode() first, and this file has to be able to say no.
    assert(c.activemode_zero == c.frames, 'bot:GetActiveMode() is no longer 0 everywhere: '
        .. c.activemode_zero .. ' of ' .. c.frames)
end

tests['[world] GetCourierState is not even auto-defined'] = function()
    -- The mock auto-defines unknown ALL_CAPS globals to distinct numbers, which
    -- is what makes `BOT_MODE_ITEM` comparisons merely FALSE rather than fatal.
    -- `GetCourierState` is mixed case, so it misses that net entirely and reads
    -- nil: a clause using it does not answer wrong, it kills the test.
    sweep()
    assert(GetCourierState == nil,
        'GetCourierState now resolves; the courier layer may be testable')
    assert(type(GetCourier) == 'function', 'GetCourier is no longer stubbed at all')
    assert(BOT_MODE_ITEM ~= nil and type(BOT_MODE_ITEM) == 'number',
        'BOT_MODE_ITEM no longer auto-resolves to a constant')
end

tests['[ratchet] the mock still answers 0 for every unknown Get*'] = function()
    -- The mechanism the two assertions above rest on. If this line moves, the
    -- "constant false" reading of every stash clause moves with it, and a
    -- future itemtrip clause could quietly become reachable -- or quietly stop
    -- being. Pinned so the claim cannot rot silently.
    local src = read_file('tests/mock/bot_api.lua')
    assert(src:find("if key:find('^Get') then return 0 end", 1, true),
        'the mock no longer falls back to 0 for unknown Get* -- re-derive C')
    assert(src:find('G.GetCourier = function() return nil end', 1, true),
        'GetCourier is no longer stubbed to nil -- re-derive the crash claim')
end

return tests
