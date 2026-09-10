-- [hero] `lionqfight` -- the engagement test Lion's catch-all Earth Spike branch
-- was written WITH and can never use.
--
-- THE DEFECT, in the first line of X.ConsiderQ's `--常规` branch:
--
--     if ( #hEnemyList > 0 or bot:WasRecentlyDamagedByAnyHero( 3.0 ) )
--         and ( ... ~= BOT_MODE_RETREAT or #hAllyList >= 2 )
--         and #nInRangeEnemyList >= 1
--         and nLV >= 15
--
-- The right half of that first parenthesis is an ENGAGEMENT test (somebody hit
-- Lion inside three seconds).  The left half is a bare PROXIMITY count -- and it
-- is IMPLIED BY THE SAME `if`'s third conjunct.  `hEnemyList` is
-- `J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)`; `nInRangeEnemyList` is the
-- same helper with the same filters at radius `nCastRange`.  So
-- `#nInRangeEnemyList >= 1` forces `#hEnemyList > 0` whenever nCastRange <= 1600,
-- `or` short-circuits on its left, and the engagement test is never evaluated for
-- ANY input.  What fires the branch is proximity alone.
--
-- ⭐ §1 CHECKS THE SUBSUMPTION AS ARITHMETIC rather than asserting it in prose,
-- because the margin is smaller than it looks: lion_impale's AbilityCastRange is
-- 650 with a +600 `special_bonus_unique_lion_2`, and X.SkillsComplement hands
-- J.GetAetherLensRangeBonus a 250 (25 more than the item KV's 225), so the
-- worst case over the whole ladder is 650 + 600 + 250 + 20 = 1520 -- inside the
-- 1600 by EIGHTY units.  Under the shipped talent build it is not close at all
-- (t25 is `{0, 10}`, which takes +250 AoE Hex and never the cast range), and §1
-- pins both numbers so a patch that moves either one goes red here.
--
-- ⭐ §3 IS NOW LOCAL VALIDATION, not a no-op claim.  The previous round could only
-- assert that the branch was unreachable (38 live Lions -> 4 at level >= 15 -> 0
-- in the ring) and handed the next round the branch's own conjunction to cut
-- frames AT.  Four such frames now exist -- tests/frames/f_260910_124853_lion_
-- spike_*.lua, from soak game 20260910_124853_slot1, each one an instant at which
-- the real bot really did press Earth Spike -- and armed WITHHOLDS three of them
-- (§3.2) while leaving untouched the fourth, where a branch that says what it is
-- for (a 19%-HP Finger of Death) fires first.
--
-- ⭐ THE FRAMES' FIRST PURCHASE WAS A DEFECT IN THE METER THAT WAS HUNTING THEM.
-- §3.1's ring was `hQ:GetCastRange() + 20`; X.ConsiderQ's is
-- `abilityQ:GetCastRange() + aetherRange + 20`, and aetherRange is 250 for any
-- Lion carrying an item_aether_lens -- which is every Lion in this corpus.  The
-- census was reading a 670-unit ring for a branch that fires on 920, and THREE OF
-- THE FOUR new frames sit in that annulus.  §3.1 pins both counts.  What this
-- does not do is retract the old zero: on the four level-15 instants that predate
-- this round the two rings agree (§3.1 asserts it), so that reading was correct
-- for its corpus, for the reason it named.
--
-- ⚠️ NOT claimed here: a frequency.  42 live-Lion instants are a DOMAIN, and four
-- of them come from ONE game deliberately chosen for having a level-24 Lion.
-- Nothing in this file says how often a level-15 Lion stands inside his own cast
-- range unhit in a real Turbo game; sizing that needs a wave.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local SRC   = 'bots/BotLib/hero_lion.lua'
local CAND  = 'lionqfight'
local UNIT  = 'npc_dota_hero_lion'
local IMPALE = 'lion_impale'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The radius X.SkillsComplement builds hEnemyList at.  Read off the source in
-- §1 rather than trusted here.
local WIDE_RADIUS = 1600

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list, so a frame
--- added by another round is seen here without an edit.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local p = io.popen('ls ' .. dir .. '/*.lua 2>/dev/null')
        if p ~= nil then
            for line in p:lines() do out[#out + 1] = line end
            p:close()
        end
    end
    return out
end

--- The cast-range term X.SkillsComplement adds and §3.1's ring used to drop:
--- `aetherRange = J.GetAetherLensRangeBonus( aether, 250 )` when Lion holds an
--- item_aether_lens, 0 otherwise.  Read off THIS file's own 250 in §1.3; hard-
--- coded here only because the census has to answer it per frame.
local AETHER_BONUS = 250

local function lens_bonus(bot)
    if bot.FindItemSlot == nil then return 0 end
    local nSlot = bot:FindItemSlot('item_aether_lens')
    if nSlot ~= nil and nSlot >= 0 then return AETHER_BONUS end
    return 0
end

local function has_live_lion(path)
    local chunk = loadfile(path)
    if chunk == nil then return false end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then return false end
    for _, u in ipairs(data.units or {}) do
        if u.name == UNIT and u.alive ~= false then return true end
    end
    return false
end

--- Load a frame with Lion as the subject, arming exactly the ids in `tOn`.
local function frame(path, tOn)
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return tOn[id] == true end
    J.IsModeTurbo = function() return true end
    local X = rf.load_hero('lion')
    return J, bot, X
end

--- Drive the REAL X.SkillsComplement dispatch and return the ability names it
--- ordered, in order.  No injection anywhere in this file.
local function drive(path, tOn)
    local _, bot, X = frame(path, tOn)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local out = {}
    for _, a in ipairs(log) do
        local h = a.args and a.args[1]
        if h ~= nil and type(h) == 'table' and h.GetName ~= nil then
            out[#out + 1] = a.fn .. ':' .. tostring(h:GetName())
        end
    end
    return table.concat(out, '|')
end

-- ---------------------------------------------------------------- section 1 --
-- The subsumption, as arithmetic over the ability's own KV ladder.  This is the
-- load-bearing claim of the whole file: if it stops holding, the engagement test
-- can bind and there is no defect to gate.

tests['§1.1 hEnemyList really is the 1600u list, read off the source'] = function()
    local body = read_file(SRC)
    assert(body:find('hEnemyList = J.GetNearbyHeroes%(bot, ' .. WIDE_RADIUS .. ', true, BOT_MODE_NONE %)'),
        'X.SkillsComplement no longer builds hEnemyList with J.GetNearbyHeroes at '
        .. WIDE_RADIUS .. '. The subsumption argument in the header is about THAT '
        .. 'call; re-derive it before editing this number.')
end

tests['§1.2 nInRangeEnemyList is the same helper with the same filters'] = function()
    local body = read_file(SRC)
    local head = body:match('function X%.ConsiderQ%(%)(.-)\n\t%-%-击杀')
    assert(head ~= nil, 'X.ConsiderQ no longer opens with the kill loop; re-read the branch.')
    assert(head:find('nInRangeEnemyList = J%.GetNearbyHeroes%(bot, nCastRange, true, BOT_MODE_NONE %)'),
        'nInRangeEnemyList is no longer J.GetNearbyHeroes(bot, nCastRange, ...). Both '
        .. 'lists must come from the same helper for the subset argument to hold: '
        .. 'that helper is what applies IsValidHero / IsMeepoClone / tempest_double.')
    assert(head:find('local nCastRange = abilityQ:GetCastRange%(%) %+ aetherRange %+ 20'),
        'X.ConsiderQ no longer computes nCastRange as GetCastRange() + aetherRange + 20; '
        .. 'the ceiling in §1.3 is built out of exactly those three terms.')
end

tests['§1.3 the worst-case nCastRange stays inside 1600, and the slack is 80'] = function()
    local kv = shapes.SHAPES['lion'][IMPALE]['AbilityCastRange']
    assert(kv ~= nil, IMPALE .. ' no longer declares AbilityCastRange in the KV snapshot.')

    local nBase = 0
    for tok in tostring(kv.base):gmatch('%S+') do
        local v = tonumber(tok)
        if v ~= nil and v > nBase then nBase = v end
    end
    assert(nBase == 650, ('lion_impale AbilityCastRange base moved to %d (was 650). '
        .. 'Re-take the ceiling below rather than editing this number.'):format(nBase))

    local nTalent = 0
    for sName, sVal in pairs(kv.bonus or {}) do
        local v = tonumber(tostring(sVal):match('%-?%d+') or '')
        if v ~= nil and v > nTalent then
            nTalent = v
            assert(sName == 'special_bonus_unique_lion_2',
                'a NEW cast-range bonus appeared on lion_impale (' .. sName .. '). '
                .. 'The 80-unit margin below was computed against the +600 talent alone.')
        end
    end
    assert(nTalent == 600, ('the lion_impale cast-range talent moved to +%d (was +600).'):format(nTalent))

    -- The aether term, read off THIS file rather than off the item's KV: the
    -- shipped call hands the helper 250, which is 25 more than item_aether_lens
    -- grants (cast_range_bonus 225), and it is the shipped number that decides
    -- the margin.
    local body = read_file(SRC)
    local nAether = tonumber(body:match('aetherRange = J%.GetAetherLensRangeBonus%( aether, (%d+) %)'))
    assert(nAether == 250, 'X.SkillsComplement no longer hands J.GetAetherLensRangeBonus a 250.')

    local nSlack = 20   -- X.ConsiderQ's own `+ 20`, pinned in §1.2
    local nCeiling = nBase + nTalent + nAether + nSlack
    assert(nCeiling == 1520, ('worst-case nCastRange is now %d, not 1520.'):format(nCeiling))
    assert(nCeiling < WIDE_RADIUS,
        ('worst-case nCastRange %d has reached the %d that builds hEnemyList. The left '
         .. 'disjunct of the 常规 branch is no longer implied by `#nInRangeEnemyList >= 1`, '
         .. 'so the engagement test CAN bind and `lionqfight` is no longer a repair of '
         .. 'dead code. Re-read the branch before touching this assert.')
            :format(nCeiling, WIDE_RADIUS))
    assert(WIDE_RADIUS - nCeiling == 80,
        ('the margin moved to %d units (was 80). The header quotes 80; fix the prose '
         .. 'in the same edit.'):format(WIDE_RADIUS - nCeiling))
end

tests['§1.4 the shipped talent build never takes the +600, so the real ceiling is 920'] = function()
    local body = read_file(SRC)
    local t25 = body:match("%['t25'%] = %{(.-)%}")
    assert(t25 ~= nil, 'tTalentTreeList no longer carries a t25 row.')
    assert(t25:gsub('%s', '') == '0,10',
        ('t25 is now {%s}. `{0, 10}` takes the ODD tier entry (+250 AoE Hex); the EVEN '
         .. 'one is +600 Earth Spike cast range. If this build starts taking the even '
         .. 'entry the real ceiling becomes 1520 and the margin is 80, not 680.'):format(t25))
    local nRealCeiling = 650 + 250 + 20
    assert(WIDE_RADIUS - nRealCeiling == 680,
        'the shipped-build slack is no longer 680; the header quotes it.')
end

-- ---------------------------------------------------------------- section 2 --
-- Gate-off equivalence and gate hygiene.  A soak candidate that is not byte-for-
-- byte the shipped behaviour with its gate off is not a soak candidate.

tests['§2.1 the helper is turbo-gated on exactly this id and names no other'] = function()
    local body = read_file(SRC)
    local fn = body:match('function X%.lion_IsFieldImpaleEngagementOk%(%)(.-)\nend')
    assert(fn ~= nil, 'X.lion_IsFieldImpaleEngagementOk is gone.')
    assert(fn:find("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%( '" .. CAND .. "' %)"),
        'the helper is no longer gated on IsModeTurbo() and IsSoakCandidate(' .. CAND .. ').')
    local nIds = 0
    for _ in fn:gmatch('IsSoakCandidate%(') do nIds = nIds + 1 end
    assert(nIds == 1,
        'the helper names ' .. nIds .. ' soak ids. A gate that conjoins a second id '
        .. 'freezes FALSE the day that id is promoted (the pullcad trap, AGENTS.md).')
    assert(fn:find('\n\treturn true\n'),
        'the helper no longer falls through to a literal `true`; gate-off equivalence '
        .. 'is supposed to be structural here, not argued.')
end

tests['§2.2 the call site adds exactly one conjunct and edits no shipped term'] = function()
    local body = read_file(SRC)
    local blk = body:match('\t%-%-常规\n(.-)\n\tthen')
    assert(blk ~= nil, 'the 常规 branch no longer opens the way this file parses it.')
    assert(blk:find('#hEnemyList > 0 or bot:WasRecentlyDamagedByAnyHero%( 3%.0 %)'),
        'the shipped first line changed. This lever deliberately leaves it byte for '
        .. 'byte: the defect is that it can never be false, and DELETING it would be a '
        .. 'different change with a different reader set.')
    assert(blk:find('and X%.lion_IsFieldImpaleEngagementOk%(%)'),
        'the call site no longer calls the helper.')
    assert(blk:find('and #nInRangeEnemyList >= 1') and blk:find('and nLV >= 15'),
        'the two conjuncts §1 and §3 reason about are gone from the branch.')
end

tests['§2.3 gate off, the helper answers true on every live-Lion frame'] = function()
    local n = 0
    for _, path in ipairs(corpus_paths()) do
        if has_live_lion(path) then
            local _, _, X = frame(path, {})
            assert(X.lion_IsFieldImpaleEngagementOk() == true,
                'gate off, the helper answered false on ' .. path)
            n = n + 1
        end
    end
    assert(n >= 30, ('only %d live-Lion frames were reached; the corpus enumerator is '
        .. 'probably broken (an empty enumerator and an empty corpus are the same '
        .. 'integer).'):format(n))
end

-- ---------------------------------------------------------------- section 3 --
-- The domain, DRIVEN -- and no longer empty.  The previous round could only
-- assert a no-op here (38 live Lions, 4 at level >= 15, 0 inside the ring) and
-- handed the next round a predicate to cut frames AT.  This round cut them:
-- tests/frames/f_260910_124853_lion_spike_*.lua are four instants from soak game
-- 20260910_124853_slot1 at which the real bot really did press Earth Spike, each
-- reverse-looked-up from the branch's own conjunction rather than from a cast
-- stamp chosen for some other question.
--
-- ⭐ AND THE FIRST THING THEY BOUGHT WAS A DEFECT IN THE METER THAT WAS LOOKING
-- FOR THEM.  §3.1's own ring was `hQ:GetCastRange() + 20`.  X.ConsiderQ's is
-- `abilityQ:GetCastRange() + aetherRange + 20`, and X.SkillsComplement sets
-- aetherRange to 250 for any Lion holding an item_aether_lens -- which is EVERY
-- Lion in this corpus (all 8 level-15 instants carry one).  So the census was
-- measuring a 670-unit ring while the branch it censused fires on a 920-unit
-- one, and three of these four frames sit in the 250-unit annulus between them:
-- invisible to the meter, live to the branch.  §3.1 now pins BOTH readings so
-- the gap cannot close silently again.
--
-- ⚠️ WHAT THAT DOES **NOT** RETRACT, and the distinction is the honest half:
-- the annulus did not manufacture last round's zero.  On the four level-15
-- instants that predate this round the two rings return the SAME count (§3.1
-- asserts that too), so "domain empty, `nLV >= 15` binding" was a correct
-- reading of that corpus for the reason it gave.  A broken meter that happened
-- to agree is still a broken meter; it is not a wrong conclusion.

tests['§3.1 the funnel: 42 live Lions, 8 at level >= 15, 4 in the branch'] = function()
    local nLion, nLv15, nNarrow, nWide, nOldLv15Gap = 0, 0, 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        if has_live_lion(path) then
            nLion = nLion + 1
            local J, bot = frame(path, {})
            local bLv = bot:GetLevel() >= 15
            if bLv then nLv15 = nLv15 + 1 end
            local hQ = bot:GetAbilityByName(IMPALE)
            local bCastable = hQ ~= nil and hQ:GetLevel() > 0 and hQ:IsFullyCastable()
            local nNarrowRing = (hQ ~= nil) and (hQ:GetCastRange() + 20) or 0
            local nWideRing = nNarrowRing + (lens_bonus(bot))
            local nN = #(J.GetNearbyHeroes(bot, nNarrowRing, true, BOT_MODE_NONE) or {})
            local nW = #(J.GetNearbyHeroes(bot, nWideRing, true, BOT_MODE_NONE) or {})
            if bLv and bCastable and nN >= 1 then nNarrow = nNarrow + 1 end
            if bLv and bCastable and nW >= 1 then nWide = nWide + 1 end
            -- The frames that predate this round: did the annulus ever change
            -- their answer?  This is the claim the header refuses to retract.
            if bLv and not path:find('124853') and nN ~= nW then
                nOldLv15Gap = nOldLv15Gap + 1
            end
        end
    end
    assert(nLion == 42, ('live-Lion instants moved %d -> %d. That is a corpus change, '
        .. 'not a bug: re-take the whole funnel below and the header, in this round.')
            :format(42, nLion))
    assert(nLv15 == 8, ('live-Lion instants at hero level >= 15 moved 8 -> %d.'):format(nLv15))
    assert(nWide == 4,
        ('the branch\'s own ring now admits %d frame(s), not 4. §3.2 drives exactly '
         .. 'those, so re-take it in the same edit.'):format(nWide))
    assert(nNarrow == 1,
        ('the 670-unit ring (the one this census used BEFORE the aether term was '
         .. 'restored) now admits %d, not 1. That number exists to keep the meter '
         .. 'defect visible; if it has moved, say which frame moved it.'):format(nNarrow))
    assert(nWide - nNarrow == 3,
        ('the annulus between the censused ring and the branch\'s ring holds %d '
         .. 'frame(s), not 3.'):format(nWide - nNarrow))
    assert(nOldLv15Gap == 0,
        ('%d level-15 frame(s) from BEFORE this round answer differently under the two '
         .. 'rings. The header states that none do, and uses it to refuse to retract '
         .. 'the previous round\'s "domain empty" reading. Fix the prose in this edit.')
            :format(nOldLv15Gap))
end

--- The four frames of §3.1's domain, and what the armed leg does with each.
--- Ground truth beside each one is read off the SAME replay (soak game
--- 20260910_124853_slot1), not inferred from the frame.
local DOMAIN_FRAMES = {
    -- path suffix,           armed withholds?, what the shipped tree orders
    { 'slardar_1129', true,  'ActionQueue_UseAbilityOnLocation:lion_impale' },
    { 'sb_1344',      true,  'ActionQueue_UseAbilityOnLocation:lion_impale' },
    { 'slardar_1416', true,  'ActionQueue_UseAbilityOnLocation:lion_impale' },
    -- The exemption.  Here a branch that SAYS WHAT IT IS FOR wins first: Spirit
    -- Breaker is at 19% and Finger of Death is the order, so the catch-all never
    -- runs and this lever cannot touch it.  Without this row "armed narrows" and
    -- "armed is an off switch" would be the same reading.
    { 'sb_1357',      false, 'ActionQueue_UseAbilityOnEntity:lion_finger_of_death' },
}

tests['§3.2 armed withholds three catch-all Earth Spikes and leaves the qualified cast alone'] = function()
    local nSeen, nMoved = 0, 0
    for _, row in ipairs(DOMAIN_FRAMES) do
        local sSuffix, bWithheld, sShippedWant = row[1], row[2], row[3]
        local path = 'tests/frames/f_260910_124853_lion_spike_' .. sSuffix .. '.lua'
        local sShipped = drive(path, {})
        local sArmed   = drive(path, { [CAND] = true })
        nSeen = nSeen + 1

        assert(sShipped:find(sShippedWant, 1, true) ~= nil,
            ('%s: the SHIPPED tree no longer orders %s (it ordered "%s"). This row is a '
             .. 'statement about the tree, not about the lever.')
                :format(path, sShippedWant, sShipped))

        if bWithheld then
            nMoved = nMoved + 1
            assert(sArmed == '',
                ('%s: armed, the dispatch is "%s". It was expected to fall SILENT -- the '
                 .. 'catch-all is the last Earth Spike branch and nothing below it picks '
                 .. 'the cast up. A non-empty answer here is a different (and more '
                 .. 'interesting) fact than the one this row asserts.')
                    :format(path, sArmed))
        else
            assert(sArmed == sShipped,
                ('%s: armed changed a dispatch this lever must not reach (%s -> %s). The '
                 .. 'catch-all is not the branch that fires here.')
                    :format(path, sShipped, sArmed))
        end
    end
    assert(nSeen == 4, ('drove %d domain frames, expected 4.'):format(nSeen))
    assert(nMoved == 3, ('armed moved %d of them, expected 3.'):format(nMoved))
end

tests['§3.3 on every withheld frame the engagement test is genuinely false'] = function()
    -- The lever is one conjunct.  If any of the three withheld frames HAD been
    -- hit inside 3.0s, the withholding would be a bug in the reader, not the
    -- lever doing its job.  Ground truth: the replay's DAMAGE events show zero
    -- hero damage to Lion in the 3.0s before each of these four casts.
    for _, row in ipairs(DOMAIN_FRAMES) do
        local path = 'tests/frames/f_260910_124853_lion_spike_' .. row[1] .. '.lua'
        local _, bot, X = frame(path, { [CAND] = true })
        assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
            ('%s now reports hero damage inside 3.0s. Every frame in this set was cut at '
             .. 'an instant where the replay records none; re-read the frame.'):format(path))
        assert(X.lion_IsFieldImpaleEngagementOk() == false,
            ('%s: armed, the helper accepted a frame with no incoming hero damage.'):format(path))
    end
end

tests['§3.4 direction by construction: armed never ADDS an action, on any live-Lion frame'] = function()
    -- The armed predicate is a pure extra conjunct, so the armed release set is a
    -- strict subset of the shipped one for every input.  Driven rather than
    -- argued: a negative wave read on this id is attributable to withheld stuns
    -- and never to a cast this lever invented.
    local nDrove, nDiff = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if has_live_lion(path) then
            local sShipped = drive(path, {})
            local sArmed   = drive(path, { [CAND] = true })
            nDrove = nDrove + 1
            if sShipped ~= sArmed then
                nDiff = nDiff + 1
                assert(sArmed == '',
                    ('%s: armed produced "%s" where shipped produced "%s". This lever can '
                     .. 'only WITHHOLD; anything else means the conjunct is not where the '
                     .. 'header says it is.'):format(path, sArmed, sShipped))
            end
        end
    end
    assert(nDrove == 42, ('drove %d frames, expected 42.'):format(nDrove))
    assert(nDiff == 3, ('armed moved %d frames over the whole corpus, expected 3 (all of '
        .. 'them in §3.2).'):format(nDiff))
end

-- ---------------------------------------------------------------- section 4 --
-- GATE PLUMBING, and this file still calls it that.  It shows the armed predicate
-- reads the window it claims to read, on two REAL frames that differ in the
-- answer.  Neither frame reaches the branch, so nothing HERE says the lever
-- changes a decision -- that claim now lives in §3.2, where it is driven.

tests['§4 the armed predicate tracks the 3.0s damage window on real frames'] = function()
    local HIT  = 'tests/frames/f_260905_004847_lion_drain_bkb.lua'
    local CALM = 'tests/fixtures/f_260819_182323_lion_drain_calm.lua'

    local _, botHit, XHit = frame(HIT, { [CAND] = true })
    assert(botHit:WasRecentlyDamagedByAnyHero(3.0) == true,
        HIT .. ' no longer carries damage inside 3.0s; §4 needs a frame that does.')
    assert(XHit.lion_IsFieldImpaleEngagementOk() == true,
        'armed, the helper refused a frame where Lion WAS hit inside the window.')

    local _, botCalm, XCalm = frame(CALM, { [CAND] = true })
    assert(botCalm:WasRecentlyDamagedByAnyHero(3.0) == false,
        CALM .. ' now carries damage inside 3.0s; §4 needs a frame that does not.')
    assert(XCalm.lion_IsFieldImpaleEngagementOk() == false,
        'armed, the helper accepted a frame where Lion was NOT hit inside the window -- '
        .. 'the whole lever is that conjunct.')

    -- The window is the branch's own 3.0, not a number this lever invented.
    local body = read_file(SRC)
    assert(body:find('X%.nQFieldDamageWindow = 3%.0'),
        'X.nQFieldDamageWindow is no longer 3.0.')
    assert(body:find('bot:WasRecentlyDamagedByAnyHero%( 3%.0 %)'),
        'the shipped 3.0 the armed window is copied FROM is gone from the branch; if the '
        .. 'branch stops carrying it, this id stops being "the term already written here".')
end

return tests
