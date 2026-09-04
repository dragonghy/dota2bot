-- [hero] GH #175 -- `ability:GetAbilityDamage()` is structurally 0 for almost
-- every ability this repo reads it on, and in Zeus's X.ConsiderW2 that zero is
-- not a small number, it is a DIFFERENT PREDICATE.  Behaviour change, so it
-- ships GATED ('zusboltcap', turbo-only).  Axis `0DMG`.
--
-- WHAT WAS FOUND
--
-- docs/BOT_API_REFERENCE.md:1526 documents GetAbilityDamage() as "base damage of
-- the ability at current level".  It reads the ability's TOP-LEVEL `AbilityDamage`
-- KV field and nothing else.  Modern Dota moved per-level damage into
-- `AbilityValues` years ago, so an ability that does not declare `AbilityDamage`
-- answers 0 -- silently, with no error, and invisibly from inside a game
-- (`print()` never reaches the server console, AGENTS.md).
--
-- `zuus_lightning_bolt` in this patch's KV (d2vpkr mirror, the same source
-- tools/agent/gen_ability_meta.py already reads; fetched 2026-08-25) declares
-- none -- its "// Damage." section is literally empty:
--
--     "zuus_lightning_bolt"
--     {
--         "AbilityCastRange"  "700 750 800 850"
--         // Damage.
--         //-------------------------------------------------------------------
--         "AbilityCooldown"   "6.0 6.0 6.0 6.0"
--         "AbilityManaCost"   "120 125 130 135"
--         "AbilityValues" { "damage" { "value" "140 220 300 380" }
--                           "spread_aoe" { "value" "325" } ... }
--     }
--
-- WHY THE DIRECTION IS THE INTERESTING PART
--
-- hero_zuus.lua's X.ConsiderW2 spent that zero here:
--
--     local nDamage = abilityW:GetAbilityDamage()                      -- 0
--     local nCanKillHeroLocationAoE =
--         bot:FindAoELocation( true, true, ..., nRadius, 0.3, nDamage )
--     if nCanKillHeroLocationAoE.count >= 1 then ... DESIRE_HIGH ...
--
-- FindAoELocation's last argument is `nMaxHealth`, and the engine's rule is
-- recorded at docs/BOT_API_REFERENCE.md § `FindAoELocation` (:1400 today, :1288 when first cited -- find it by heading, the line number drifts): "Only target units below this HP.
-- Pass 0 for no HP filter (target any HP)."  So the branch whose own local is
-- named `nCanKillHeroLocationAoE` -- written to ask "is there a spot where one
-- bolt FINISHES somebody" -- has, since the upstream snapshot, been asking "is
-- there an enemy hero anywhere in cast range", and answering yes at
-- BOT_ACTION_DESIRE_HIGH and 120-135 mana a cast.
--
-- That is a WIDENING.  The very same zero, over in X.ConsiderW, KILLS that
-- branch instead.  One silent zero, two opposite directions, one file:
-- **which way a silent zero cuts has to be read per call site**, which is the
-- half GH #162's key census could not supply.  The other direction is filed,
-- not fixed here -- un-deadening a kill branch is a widening and needs its own
-- evidence and its own id (the lesson from GH #166: never put the two
-- directions inside one predicate).
--
-- CORRECTED 2026-08-30 (hero, backlog -50's unmeasured second consumer, priced
-- in tests/test_zuus_static_field_second_consumer.lua).  The paragraph above
-- used to read "The very same zero, over in X.ConsiderW, is fed to
-- J.WillMagicKillTarget, where it KILLS the branch instead (a 0-damage nuke
-- finishes nobody)".  The verdict survived; the shape did not:
--   * J.WillMagicKillTarget has ONE call site in hero_zuus.lua and it is
--     X.ConsiderR's (:1100), not X.ConsiderW's.  X.ConsiderW's kill test is the
--     inline GetActualIncomingDamage comparison at :795, and the two sites take
--     their flat damage from different calls -- GetSpecialValueInt('damage') in
--     ConsiderR (nonzero) versus GetAbilityDamage() here (zero).
--   * The estimate at :795 is not a 0-damage nuke: it still carries
--     `GetHealth() * abilityASBonus`.  The zero removes the SCALE, leaving
--     `h < m*b*h`, i.e. `1 < m*b` -- health-free.  So the branch is dead for
--     every creep at every health at every rank, and no percentage `zusstatic`
--     can carry revives it (break-even b >= 1/m >= 1.0; shipped 0.09 is 11.1x
--     short).  Total and percentage-proof, not marginal.
-- Consequence for a SIBLING id, which is why it is recorded here too: with that
-- consumer's domain empty, `zusstatic`'s ConsiderR-only (a) reading is the whole
-- id -- but only while this zero holds.  Fixing the direction this file filed
-- and did not fix re-opens it.
--
-- HOW BIG THE AXIS IS (tools/agent/ability_damage_census.py, new this trigger)
--
-- Over all 128 shipped heroes' KV: 30 abilities declare `AbilityDamage` at all,
-- and only 16 declare a nonzero one.  Against the 58 GetAbilityDamage() reads in
-- bots/: 46 are PROVEN ZERO, 10 UNRESOLVED, 2 UNRESOLVED-GLOBAL.
--
-- The proof needs no handle resolution, which is what makes it stronger than
-- #162's: a read inside hero_<h>.lua can only be taken on one of <h>'s own
-- abilities, so if <h> declares no nonzero `AbilityDamage` at all, that read is
-- 0 whichever handle it was on.  ONE-DIRECTIONAL as always: a hero that HAS one
-- proves nothing about any particular site.
--
-- Focus five: zuus (2 sites) and lion (3) are both proven-zero; axe,
-- skeleton_king and crystal_maiden never call it.
--
-- THE SHAPE OF THE CHANGE (why gate-off equivalence is structural)
--
-- X.GetBoltKillHealthCap keeps `hAbility:GetAbilityDamage()` as the function's
-- LAST statement and the armed branch is the only detour.  Armed, a KV key that
-- answers <= 0 falls through to that same last statement rather than inventing a
-- default (the house rule from GH #162), so the armed leg can never be WIDER
-- than shipped.  §1/§2 make both claims falsifiable.
--
-- WARNING -- LIMIT, MEASURED IN §4, NOT ASSERTED
--
--   * tests/mock/bot_api.lua answers 0 for every `Get*` it does not know, so
--     offline BOTH legs read 0: GetAbilityDamage() because the mock has no such
--     field, GetSpecialValueInt('damage') because the mock has no KV at all.
--     Same class as GH #162/#133/#145/#154.  The armed leg is therefore driven
--     here on FABRICATED handles, declared as such.
--   * FindAoELocation is not in the mock either, so "does the branch fire on
--     this frame" is not a question a fixture can settle -- there is no
--     firing-side fixture and its absence is measured, not assumed.
--   * Condition (a) has to be bought from the corpus: queue hero-16.
--
-- WHAT THIS FILE DOES NOT CLAIM
--
--   * That 140/220/300/380 is what the engine hands back at a given level --
--     how facets and talents fold into GetSpecialValueInt is the engine's
--     business.  §2 proves the tightening for ANY positive reading.
--   * That tightening this branch WINS games.  Locally-correct is not
--     emergently-good (AGENTS.md, the lanefix lesson).  That is what the gate is
--     for.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local ZUUS     = 'bots/BotLib/hero_zuus.lua'
local LION     = 'bots/BotLib/hero_lion.lua'
local SNAPSHOT = 'tests/mock/ability_damage.lua'
local FRAME    = 'tests/fixtures/f_230952_zuus_ult_hoard.lua'

local CAND_ID = 'zusboltcap'
local KEY     = 'damage'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE anything is counted.  The reasoning block
--- above quotes the call name and the key while explaining them, and a parser
--- that reads prose reports the prose (GH #136's first census).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- An ability handle that answers like a Lightning Bolt whose engine-side
--- AbilityDamage is `nShipped` and whose KV `damage` is `nKv`.  A declared
--- fabrication, not a frame reading (§4 measures why no frame can supply one).
local function make_bolt(nShipped, nKv)
    return api.MakeUnit{
        GetUnitName = 'zuus_lightning_bolt',
        GetAbilityDamage = function() return nShipped end,
        GetSpecialValueInt = function(_, sKey)
            if sKey == KEY then return nKv end
            return 0
        end,
    }
end

--- Load Zeus on the real frame, set the mode and the gate, return (X, J, bot).
--- GetGameMode is set BEFORE the hero file loads because J.IsModeTurbo memoises
--- its answer on the first call.
local function load_zuus(bArmed, bTurbo)
    local J, bot = rf.load(FRAME)

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(sId) return sId == CAND_ID end
        or function() return false end

    return rf.load_hero('zuus'), J, bot
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The source shape: a ratchet on where the shipped expression may live.

tests['[hero] ConsiderW2 takes its HP filter from the helper and nowhere else'] = function()
    local src = strip_comments(read_file(ZUUS))

    local sBody = src:match('function X%.ConsiderW2%(%)(.-)\nend\n')
    assert(sBody, 'X.ConsiderW2 not found')
    assert(sBody:find('X.GetBoltKillHealthCap( abilityW )', 1, true),
        'the one assignment must go through the helper, with the file-local handle')
    assert(not sBody:find('GetAbilityDamage', 1, true),
        'and the raw call must not survive inside ConsiderW2 -- that would be an ungated site')

    -- nDamage has exactly TWO consumers in this function, and both are named
    -- here, because a third would be a leg nothing is watching.
    --   (1) FindAoELocation's nMaxHealth -- the filter itself;
    --   (2) X.BoltAoEKillTarget -- GH #477, which asks whether that filter is a
    --       filter at all before the branch may claim GH #47's kill exemption.
    -- (2) is deliberately a READ of the same local rather than a second call to
    -- the helper: two calls could drift apart mid-frame if the cap ever stops
    -- being pure, and then the branch would exempt itself on one value while
    -- searching on another.
    local nReads = select(2, sBody:gsub('nDamage', ''))
    assert(nReads == 3, 'expected the assignment plus exactly two reads of nDamage in '
        .. 'ConsiderW2, got ' .. nReads)
    assert(sBody:find('0.3, nDamage )', 1, true),
        'the first read must be FindAoELocation\'s last argument (nMaxHealth)')
    assert(sBody:find('X.BoltAoEKillTarget( nDamage,', 1, true),
        'the second must be the GH #477 exemption test, on the same local')
end

tests['[hero] the helper is gated, turbo-only, and ends on the shipped expression'] = function()
    local src = strip_comments(read_file(ZUUS))

    local sHelper = src:match('function X%.GetBoltKillHealthCap%b()(.-)\nend')
    assert(sHelper, 'X.GetBoltKillHealthCap is gone; the call site would be ungated')
    assert(sHelper:find("IsSoakCandidate( '" .. CAND_ID .. "' )", 1, true),
        'the correction must sit behind IsSoakCandidate(' .. CAND_ID .. ')')
    assert(sHelper:find('IsModeTurbo', 1, true), 'and behind IsModeTurbo (turbo-only, AGENTS.md)')
    assert(sHelper:find("GetSpecialValueInt( '" .. KEY .. "' )", 1, true),
        'and it must read the KV key ' .. KEY)

    -- The shipped expression is the LAST statement: gate-off is the shipped
    -- path by construction, not by measurement.
    local sTail = sHelper:match('(return[^\n]*)%s*$')
    assert(sTail and sTail:find('GetAbilityDamage()', 1, true),
        'the helper must END on hAbility:GetAbilityDamage(), got ' .. tostring(sTail))

    -- Exactly one raw GetAbilityDamage() survives in the whole Zeus file per
    -- census site minus the one this change routed through the helper: the
    -- helper's own fallback, and X.ConsiderW's (filed, not fixed -- see header).
    local n = select(2, src:gsub('GetAbilityDamage%(%)', ''))
    assert(n == 2, 'expected exactly 2 GetAbilityDamage() calls left in ' .. ZUUS
        .. ' (the helper fallback + the un-fixed X.ConsiderW site), got ' .. n)
end

-- ---------------------------------------------------------------------------
-- 2. The helper's own behaviour, on fabricated handles.

tests['gate off: the answer is the shipped GetAbilityDamage(), whatever the KV says'] = function()
    local X = load_zuus(false, true)
    assert(X.GetBoltKillHealthCap(make_bolt(0, 300)) == 0,
        'gate off must be byte-for-byte the shipped expression')
    assert(X.GetBoltKillHealthCap(make_bolt(77, 300)) == 77,
        'and it must not consult the KV key at all off-gate')
end

tests['gate on: the answer is the KV damage'] = function()
    local X = load_zuus(true, true)
    assert(X.GetBoltKillHealthCap(make_bolt(0, 140)) == 140, 'level 1 bolt')
    assert(X.GetBoltKillHealthCap(make_bolt(0, 380)) == 380, 'level 4 bolt')
end

tests['gate on: a dead KV key falls through to shipped, it never invents a default'] = function()
    local X = load_zuus(true, true)
    assert(X.GetBoltKillHealthCap(make_bolt(0, 0)) == 0,
        'a key answering 0 (renamed, or a facet that does not carry it) must fall '
        .. 'through -- the GH #162 house rule')
    assert(X.GetBoltKillHealthCap(make_bolt(0, -5)) == 0, 'and so must a negative reading')

    -- The `> 0` in the guard has to be a STRICT `>`.  With `>= 0` a dead key
    -- would stop falling through and start OVERWRITING the shipped answer with
    -- a zero -- which is invisible on a shipped-0 handle and is exactly why this
    -- case fabricates a nonzero one.
    assert(X.GetBoltKillHealthCap(make_bolt(77, 0)) == 77,
        'a dead key must lose to the shipped expression, not replace it')
end

tests['gate on is a TIGHTENING for every positive reading, never a widening'] = function()
    local X = load_zuus(true, true)
    -- The whole point: shipped 0 means "no HP filter" (BOT_API_REFERENCE:1288),
    -- so any positive answer admits a strict subset of what shipped admits.
    for _, nKv in ipairs({ 1, 140, 220, 300, 380, 9999 }) do
        local nOff = 0
        local nOn = X.GetBoltKillHealthCap(make_bolt(nOff, nKv))
        assert(nOn > nOff, 'armed must be a finite cap where shipped was the unfiltered 0')
    end
end

tests['turbo-only: armed outside turbo is the shipped expression'] = function()
    local X = load_zuus(true, false)
    assert(X.GetBoltKillHealthCap(make_bolt(0, 380)) == 0,
        'AGENTS.md: a soak candidate is inert outside turbo')
end

-- ---------------------------------------------------------------------------
-- 3. The census the reading rests on -- so a patch breaks this file loudly.

tests['[hero] zuus and lion declare no nonzero AbilityDamage in the KV snapshot'] = function()
    api.install({})
    local tNonzero = assert(dofile(SNAPSHOT).NONZERO, 'no AbilityDamage snapshot')

    assert(tNonzero['zuus'] == nil, 'zuus must declare no nonzero AbilityDamage -- if a '
        .. 'patch gives one to a Zeus ability, X.ConsiderW2\'s shipped leg stops being '
        .. 'the unfiltered 0 and this whole reading needs redoing')
    assert(tNonzero['lion'] == nil, 'same for lion (3 proven-zero reads; the ConsiderQ one '
        .. 'was picked up 2026-08-30 as gated `lionqdmg`, W/E are still filed not fixed)')
    assert(tNonzero['axe'] == nil and tNonzero['skeleton_king'] == nil
        and tNonzero['crystal_maiden'] == nil, 'and the other three focus heroes')

    -- Corroboration inside the same snapshot, so the absences above are not a
    -- fetch that half-succeeded and wrote an empty table.
    assert(tNonzero['tidehunter'], 'expected tidehunter in the snapshot')
    assert(tNonzero['tidehunter']['tidehunter_ravage'] == '275 375 475',
        'and Ravage is the ability that carries it')
    local nHeroes = 0
    for _ in pairs(tNonzero) do nHeroes = nHeroes + 1 end
    assert(nHeroes == 16, 'expected 16 heroes with a nonzero AbilityDamage, got ' .. nHeroes)
end

tests['[hero] the other proven-zero focus-five reads are still where the census left them'] = function()
    -- Filed here, deliberately NOT fixed here (they are widenings; see the
    -- header).  This is a ratchet, not an endorsement: if somebody routes one of
    -- them through a helper, they must come back and re-read the header.
    --
    -- UPDATED 2026-08-30 (hero, backlog -43a's Lion direction).  The ratchet
    -- fired as designed and was answered rather than edited away: X.ConsiderQ's
    -- kill branch -- the "live one" this case used to name -- now takes its
    -- damage from X.GetImpaleKillDamage, gated `lionqdmg` (turbo-only, unarmed,
    -- unpromoted).  The COUNT is unchanged at 3 because that helper keeps
    -- GetAbilityDamage() as its shipped fallthrough, which is exactly the shape
    -- X.GetBoltKillHealthCap uses here; so the count alone can no longer tell
    -- the two states apart, and the site check below is what now carries it.
    -- The Lion domain, the driven ceiling and the corpus limit live in
    -- tests/test_lion_q_kill_damage.lua.
    local sLion = strip_comments(read_file(LION))
    local nLion = select(2, sLion:gsub('GetAbilityDamage%(%)', ''))
    assert(nLion == 3, 'expected 3 GetAbilityDamage() reads in ' .. LION .. ', got ' .. nLion
        .. ' (one is now the gated helper\'s fallthrough; W and E assign a local nobody reads)')
    assert(sLion:match('function X%.GetImpaleKillDamage%(.-%)(.-)\nend\n'),
        'the ConsiderQ read must stay behind its helper -- if it goes back inline, that is an '
        .. 'ungated site and this file\'s "filed not fixed" reading is stale again')
end

-- ---------------------------------------------------------------------------
-- 4. LIMITS -- measured on the real frame, not asserted.

-- RE-ANCHORED 2026-09-04 (hero, `kvgetters`).  Same repair, same shape, as
-- tests/test_lion_q_kill_damage.lua's section 6: this LIMIT is HALF gone.
--
-- ARCHIVED READING (until 2026-09-03): both legs read 0 offline, and the mock
-- could not tell a real key from a fabricated one, so no fixture could separate
-- them.  tests/mock/replay_fixture.lua now serves GetSpecialValue* from the KV
-- snapshot (tests/test_fixture_kv_getters.lua), so the armed leg reads the real
-- zuus_lightning_bolt ladder.  GetAbilityDamage was NOT served -- a different
-- unspecced getter, deliberately left for the next batch -- so the shipped leg
-- still reads 0, and the two legs are now DIFFERENT offline.
--
-- ⛔ The sections above are NOT rebaselined here.  Their numbers were taken in
-- the archived world with the armed leg driven on declared fabrications;
-- re-driving them through the getter is this lever's own work unit (charter
-- backlog -88).  What survives of the limit is pinned below: a key nobody ever
-- wrote still reads 0, so ABSENCE and ZERO stay indistinguishable -- GH #162 is
-- not repaired by this.
tests['LIMIT: the armed leg is readable offline now; the shipped leg is not, and absence still reads 0'] = function()
    local _, _, bot = load_zuus(true, true)
    local h = bot:GetAbilityByName('zuus_lightning_bolt')
    assert(h:GetAbilityDamage() == 0,
        'the mock has no AbilityDamage field, so the shipped leg reads 0 offline for a '
        .. 'reason unrelated to the KV -- the agreement with the real engine here is a '
        .. 'coincidence and must not be cited as confirmation')

    local shapes = require('mock.special_value_shapes')
    local blk = shapes.SHAPES['zuus'] and shapes.SHAPES['zuus']['zuus_lightning_bolt']
    local entry = blk and blk[KEY]
    assert(entry ~= nil and entry.base ~= nil,
        'the KV snapshot no longer carries zuus_lightning_bolt/' .. KEY
        .. '; without it this case is back in the archived world and cannot say so')
    local steps = {}
    for tok in entry.base:gmatch('%S+') do steps[#steps + 1] = tonumber(tok) end
    local rank = h:GetLevel()
    local want = steps[math.min(math.max(rank, 1), #steps)]
    local got = h:GetSpecialValueInt(KEY)
    assert(got == want, KEY .. ' reads ' .. tostring(got) .. ' at rank ' .. rank
        .. ', KV ladder says ' .. tostring(want) .. '. A 0 means the loader stopped '
        .. 'serving GetSpecialValue* and the sections above are back in the world '
        .. 'their numbers were taken in.')
    assert(got ~= h:GetAbilityDamage(),
        'the two legs read the same number offline again, so the separation this '
        .. 'case records has been lost')

    assert(h:GetSpecialValueInt('a_key_nobody_ever_wrote') == 0,
        'a key that never existed still reads 0 -- the loader must not invent a '
        .. 'value for one, which would be worse than the zero it replaced')
end

tests['LIMIT: FindAoELocation is not in the mock, so the branch cannot be fired'] = function()
    local _, _, bot = load_zuus(true, true)
    assert(rawget(bot, 'FindAoELocation') == nil or type(bot.FindAoELocation) ~= 'function'
        or (function()
                local ok, res = pcall(function()
                    return bot:FindAoELocation(true, true, bot:GetLocation(), 800, 325, 0.3, 0)
                end)
                -- Either it is absent, or the mock's catch-all answers something
                -- with no `count` -- both mean the branch cannot be driven.
                return not ok or type(res) ~= 'table' or res.count == nil
            end)(),
        'if FindAoELocation ever answers a real {count=...} under the mock, a firing-side '
        .. 'fixture becomes possible and this file should grow one')
end

return tests
