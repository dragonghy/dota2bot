-- [cutoff 20260912] THE 'lvlany' FAMILY SHAPE IN A NEW FUNCTION -- AND THE FIRST
-- SITE OF THE FAMILY WHERE `[1]` IS NOT EVEN THE NEAREST MEMBER.
--
-- THE DEFECT. bots/mode_retreat_generic.lua, X.ShouldRun's invisible-retreat
-- branch:
--     and J.GetDistanceFromAncient(bot, false) < J.GetDistanceFromAncient(nEnemyHeroes[1], false)
--     then return 5
-- `false` is OUR ancient on both sides (J.GetDistanceFromAncient reads
-- GetAncient(GetTeam()) and only swaps when bEnemy is true), so the clause asks
-- "am I ahead of the enemy in the race home" and commits to a retreat desire of
-- 5 on the answer. The question is existential -- ONE chaser standing between
-- the bot and its own ancient is what being CUT OFF means, and running home is
-- then the losing line -- and it is asked of a single list member.
--
-- THE AUTHOR'S OWN EVIDENCE. `#nEnemyHeroes` is spent as a GROUP term eight
-- times in this same file on this same list (:449, :492, :493, :495, :517, :565,
-- :600 and the `> #nAllyHeroes` comparisons among them), and `#nAllyHeroes <= 1`
-- sits in this very conjunction two lines above the race term. A whole term was
-- already being spent asking about the group; the race term beside it asks about
-- one member.
--
-- ⭐⭐ WHY THIS SITE IS WORTH ITS OWN REPORT LINE, and it is structural, not a
-- preference. Every earlier member of this family (lvlany / lvlcarry / lvlgroup
-- / lvltogether / lvlhitcreep) read a list that INHERITS A DISTANCE SORT, so
-- `[1]` at least meant "the nearest" and the defect was "the nearest is not the
-- most dangerous". Here `nEnemyHeroes` is C.enemyHeroes, filled by
-- buildContext() from `GetUnitList(UNIT_LIST_ALL)` -- ONE WORLD LIST, the same
-- object order for every observer -- filtered by team and radius and never
-- sorted anywhere on the path. A list that does not depend on the observer
-- CANNOT be in that observer's distance order except by coincidence, so `[1]` is
-- an ARBITRARY enemy hero within 1600. Section 4a pins "no sort on the path" on
-- the shipped source; section 4b measures the coincidence failing on 162 of 682
-- live rows that carry an enemy at all.
-- ⛔ The 162 is the corpus's INSTANCE of that argument, not its proof: the
-- loader's UNIT_LIST_ALL is roster order (allies then enemies), which is A world
-- order, not necessarily the engine's. The argument that survives either order
-- is the observer-independence above, and that is the one this file rests on.
--
-- ⛔ DIRECTION, measured over all 1306 live rows (section 3c). Armed answers
-- `forall e in list: d(bot) < d(e)`; shipped answers `d(bot) < d(list[1])`. The
-- loop starts at i = 1 and the caller has already established `[1]` is a valid
-- hero, so `[1]` is always evaluated ⇒ armed TRUE implies shipped TRUE. Arming
-- is a pure NARROWING of the permission the clause guards: it can only WITHHOLD
-- a `return 5` that ships today, never issue one baseline withheld. 0 violations,
-- pinned as an equality, plus `shipped_true - armed_true == site_miss` so the
-- bound cannot be satisfied by a helper that answers a constant.
-- ⛔ It is a bound on the DIRECTION, not a fire rate. No fire rate is claimed in
-- this file.
--
-- ⛔ THE BAR THIS LEVER IS TAKEN ON, said before any number is read, because it
-- is the WEAKER of the two in force and lvlhitcreep was taken on the stronger
-- one. The lever's own predicate is driven on 43 real rows (section 3c) -- the
-- largest predicate-layer drive in the family so far. The enclosing function's
-- RETURN moves on ZERO of them, and for a reason this corpus cannot argue away:
-- the branch's outer guard needs `J.IsRealInvisible(bot)` and `J.IsRetreating(bot)`,
-- and section 5 measures BOTH at zero rows. So:
--   * no fire rate is claimed, and
--   * 'cutoff' OWES A FRAME exactly like its four `cat_flip == 0` siblings --
--     registered in state.json:cutoff_20260912 and handed to the replay group,
--     NOT settled by lvlhitcreep's 9 rows (a different predicate entirely).
--
-- ⛔ WHAT THIS CORPUS CAN AND CANNOT BUY.
--   * IT CAN BUY the producer and the geometry: hero team/position and the
--     ancient are dump ground truth, and UNIT_LIST_ALL is restored from the
--     fixture roster rather than modelled. Section 4c asserts the team split and
--     self-exclusion as EQUALITIES on the rows that carry the claim.
--   * IT CANNOT BUY the invalid-member skip in the armed loop: every member of
--     every list on this corpus is a valid hero (section 4d measures that at
--     zero), so the skip is inert here and is pinned on the SOURCE instead --
--     which is weaker, and says so. It cannot change the direction bound either
--     way, because `[1]` is not skippable.
--   * IT CANNOT BUY the outer guard at all (section 5).
--   ⇒ 'cutoff' is FROZEN-HOLD per OWNER_PRIORITIES P4.2: registered in
--     state.json:cutoff_20260912, NOT requested into the armed set. The armed
--     string, queue.json and test_set.md are untouched.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/mode_retreat_generic.lua'
local CAND = 'cutoff'

-- buildContext's own constant: the radius both hero lists are filled at.
local SITE_RADIUS = 1600

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This lever's own comment block quotes the
--- shipped expression, so an unstripped read would let a COMMENT satisfy the
--- structural assertions in sections 4a, 6 and 7.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        -- Registered in tests/test_bots_walk_farm_only.py:UNRESOLVED_HAND_READ:
        -- a plain non-recursive `ls` over two literal directories, which cannot
        -- reach bots/Customize/.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'),
            'could not list ' .. dir)
        for line in p:lines() do
            if line:sub(-4) == '.lua' then out[#out + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    assert(#out > 100, 'expected the frame corpus, got ' .. #out)
    return out
end

--- The helper's body, lifted verbatim from the shipped file, so sections 3-5
--- drive the REAL shipped bytes and not a re-implementation of them.
local function helper_src()
    local src = stripped(read_file(TRG))
    local s = src:find('function X.AheadOfEveryEnemyToAncient(tHeroes, hBot)', 1, true)
    assert(s ~= nil, 'X.AheadOfEveryEnemyToAncient is gone from ' .. TRG)
    local e = src:find('\nend', s, true)
    assert(e ~= nil, 'unterminated X.AheadOfEveryEnemyToAncient in ' .. TRG)
    return src:sub(s, e + 3)
end

local BODY = helper_src()

local function compile(body, env, name)
    local fn = assert(loadstring(
        'local X = {}\n' .. body .. '\nreturn X.AheadOfEveryEnemyToAncient', name))
    setfenv(fn, env)
    return fn()
end

--- The shipped expression, spelled out here so section 3a compares the helper
--- against the TEXT of what shipped rather than against another call of itself.
local function shipped_answer(J, list, hBot)
    return list[1] ~= nil
        and J.GetDistanceFromAncient(hBot, false)
            < J.GetDistanceFromAncient(list[1], false)
end

--- The armed quantifier, written out once for the drift check in section 3b.
--- The HELPER itself is never re-implemented for sections 3c-5; those drive the
--- real bytes. The invalid-member skip is replicated here so section 3b compares
--- like with like; section 4d measures that the skip is inert on this corpus.
local function armed_answer(J, list, hBot)
    if list[1] == nil then return false end
    local nBotDist = J.GetDistanceFromAncient(hBot, false)
    for i = 1, #list do
        if J.IsValidHero(list[i])
            and nBotDist >= J.GetDistanceFromAncient(list[i], false)
        then
            return false
        end
    end
    return true
end

-- ------------------------------------------------------------- the sweep ---

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local RADII = { 800, 1200, 1600 }

    for _, path in ipairs(corpus_paths()) do
        local ok, J, _, heroes = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames_loaded')

            -- The arm under test, injected once per fixture rather than once per
            -- row: 1306 rows would otherwise mean 1306 compiles of the same
            -- bytes, and the compile is not what is being measured.
            local armed = false
            local realSoak = J.IsSoakCandidate
            J.IsSoakCandidate = function(sId)
                if sId ~= CAND then return realSoak(sId) end
                return armed
            end
            local env = setmetatable({ J = J }, { __index = _G })
            local fn = compile(BODY, env, 'cutoff_body')
            local realGetTeam = GetTeam

            for _, h in pairs(heroes or {}) do
                if h ~= nil and h.IsAlive and h:IsAlive() then
                    bump('live')
                    -- GetTeam() is the SCRIPT's team, i.e. the team of the bot
                    -- whose Think is running. Overriding it per row is what the
                    -- engine already does when each bot's script runs -- without
                    -- it, J.GetDistanceFromAncient would measure every row to the
                    -- loaded subject's ancient and half the census would be about
                    -- the wrong building.
                    GetTeam = function() return h:GetTeam() end

                    -- buildContext's producer, reproduced: UNIT_LIST_ALL, team
                    -- split, 1600. The shipped filters this leaves out (illusion,
                    -- Meepo clone, five modifier exclusions) are SUBTRACTIVE and
                    -- order-preserving, so the ORDER claim in section 4 carries
                    -- exactly and every count here is an upper bound on the
                    -- shipped list's -- which is the safe direction for a
                    -- ratchet and the unsafe one for a ceiling, so no count here
                    -- is used as a ceiling.
                    local site = {}
                    for _, u in pairs(GetUnitList(UNIT_LIST_ALL)) do
                        if J.IsValid(u)
                            and u:GetTeam() ~= TEAM_NEUTRAL
                            and u:GetTeam() ~= TEAM_NONE
                            and J.IsValidHero(u)
                            and GetUnitToUnitDistance(h, u) <= SITE_RADIUS
                            and u:GetTeam() ~= h:GetTeam()
                        then
                            site[#site + 1] = u
                        end
                    end

                    -- 3a-3b: the real bytes, both legs of the gate.
                    armed = true
                    local a_real = fn(site, h)
                    armed = false
                    local s_real = fn(site, h)

                    local s_text = shipped_answer(J, site, h)
                    local a_spec = armed_answer(J, site, h)

                    if s_real ~= s_text then bump('UNARMED_DRIFT') end
                    if a_real ~= a_spec then bump('ARMED_DRIFT') end

                    if s_real then bump('shipped_true') end
                    if a_real then bump('armed_true') end
                    -- 3c. DIRECTION: armed true must imply shipped true.
                    if a_real and not s_real then bump('DIR_VIOLATION') end

                    if s_real and not a_real then
                        bump('site_miss')
                        -- A withdrawal needs a SECOND member: with one member the
                        -- two answers are the same expression. Pinned as an
                        -- equality in section 3c.
                        if #site >= 2 then bump('miss_ge2') end
                        -- 4c. producer sanity, taken ON THE ROWS THAT CARRY THE
                        -- CLAIM rather than corpus-wide.
                        for i = 1, #site do
                            if site[i] == h then bump('SELF_IN_LIST') end
                            if site[i]:GetTeam() == h:GetTeam() then bump('SAME_TEAM') end
                        end
                        -- 4b, restricted to the rows the lever actually moves.
                        local d1 = GetUnitToUnitDistance(h, site[1])
                        for i = 2, #site do
                            if GetUnitToUnitDistance(h, site[i]) < d1 - 0.5 then
                                bump('miss_not_nearest')
                                break
                            end
                        end
                    end

                    if site[1] ~= nil then
                        bump('nonempty')
                        if #site >= 2 then bump('ge2') end
                        -- 4b. `[1]` is NOT the nearest, measured. For the four
                        -- level siblings the equivalent section asserted the
                        -- OPPOSITE (SORT_VIOLATION == 0) because their producer
                        -- inherits a distance sort. This producer does not, and
                        -- that difference is the reason this site was taken.
                        local d1 = GetUnitToUnitDistance(h, site[1])
                        for i = 2, #site do
                            if GetUnitToUnitDistance(h, site[i]) < d1 - 0.5 then
                                bump('not_nearest')
                                break
                            end
                        end
                        -- 4d. can the armed loop's validity skip ever fire here?
                        for i = 1, #site do
                            if not J.IsValidHero(site[i]) then bump('invalid_member') end
                        end
                    end

                    -- 5. the outer guard, measured rather than assumed absent.
                    if J.IsRealInvisible(h) then bump('g_invis') end
                    if J.IsRetreating(h) then bump('g_retreat') end

                    -- 2. the sweep: the site cell is ONE of these, and the
                    -- neighbours are what make it a population rather than a
                    -- coincidence.
                    for _, r in ipairs(RADII) do
                        local L = {}
                        for _, u in pairs(GetUnitList(UNIT_LIST_ALL)) do
                            if J.IsValid(u) and J.IsValidHero(u)
                                and u:GetTeam() ~= TEAM_NEUTRAL
                                and u:GetTeam() ~= TEAM_NONE
                                and GetUnitToUnitDistance(h, u) <= r
                                and u:GetTeam() ~= h:GetTeam()
                            then
                                L[#L + 1] = u
                            end
                        end
                        if shipped_answer(J, L, h) and not armed_answer(J, L, h) then
                            bump('miss_r' .. r)
                        end
                    end

                    GetTeam = realGetTeam
                end
            end
        end
    end
    return c
end)()

-- ============================================================== sections ===

tests['[cutoff] 1. the corpus this file speaks about'] = function()
    assert(SWEEP['load_fail'] == 0,
        SWEEP['load_fail'] .. ' fixture(s) failed to load -- every count below '
        .. 'is taken over a corpus this file cannot describe. Fix the loader '
        .. 'before reading any other section.')
    cs.corpus(SWEEP['frames_loaded'], 'frames loaded')
    cs.ratchet(SWEEP['live'], 1306, 'live hero rows')
    cs.ratchet(SWEEP['nonempty'], 682,
        'live rows with >= 1 enemy hero within ' .. SITE_RADIUS)
    cs.ratchet(SWEEP['ge2'], 349,
        'live rows with >= 2 enemy heroes within ' .. SITE_RADIUS)
end

tests['[cutoff] 2. the sweep: the site cell is one of a population'] = function()
    cs.ratchet(SWEEP['miss_r1600'], 43, 'site cell: r1600 withdrawals')
    cs.ratchet(SWEEP['miss_r1200'], 33, 'r1200 withdrawals')
    cs.ratchet(SWEEP['miss_r800'], 13, 'r800 withdrawals')
    assert(SWEEP['miss_r1600'] == SWEEP['site_miss'],
        'the sweep cell (' .. SWEEP['miss_r1600'] .. ') and the site count ('
        .. SWEEP['site_miss'] .. ') disagree, and they are the same question '
        .. 'asked twice -- one of the two is measuring something else now.')
    -- ⛔ Registered, NOT asserted as a law. Widening the ring adds members, which
    -- can only add ways for the quantifier to fail -- but it also changes WHO
    -- `[1]` is, so monotonicity is not entailed here the way it would be for a
    -- distance-sorted producer. 13 / 33 / 43 is this corpus's curve, recorded in
    -- the report; if a future corpus breaks the ordering that is a finding about
    -- the producer, not a failure of this file.
end

tests['[cutoff] 3a. unarmed, the shipped bytes answer the shipped text'] = function()
    assert(SWEEP['UNARMED_DRIFT'] == 0,
        SWEEP['UNARMED_DRIFT'] .. ' row(s) where the helper UNARMED disagrees '
        .. 'with `d(bot) < d(list[1])`. Unarmed MUST be byte-for-byte the old '
        .. 'behaviour -- this id is gated and unpromoted, so a drift here is a '
        .. 'live change to every shipped game.')
    assert(SWEEP['shipped_true'] > 0,
        'the shipped predicate is true on 0 rows, so section 3c compares two '
        .. 'empty sets and the direction bound is vacuous.')
end

tests['[cutoff] 3b. armed, the shipped bytes answer the quantifier'] = function()
    assert(SWEEP['ARMED_DRIFT'] == 0,
        SWEEP['ARMED_DRIFT'] .. ' row(s) where the helper ARMED disagrees with '
        .. '`forall e: d(bot) < d(e)`. The lever is not the fix it is described '
        .. 'as.')
    assert(SWEEP['armed_true'] > 0,
        'the armed predicate is true on 0 rows -- the lever is inert on this '
        .. 'corpus and nothing below is about anything.')
end

tests['[cutoff] 3c. DIRECTION: arming only ever WITHDRAWS the permission'] = function()
    -- ⛔ This assertion comes FIRST and the counts come after, deliberately: a
    -- violation here means arming GRANTED a `return 5` that baseline withheld,
    -- which is the one outcome this lever must never produce.
    assert(SWEEP['DIR_VIOLATION'] == 0,
        SWEEP['DIR_VIOLATION'] .. ' row(s) where ARMED said "ahead of them all" '
        .. 'and SHIPPED did not. `[1]` is a member of the list and the loop '
        .. 'starts at i = 1, so this is supposed to be impossible: armed must be '
        .. 'a pure NARROWING. A non-zero here is a bug in the helper, not a new '
        .. 'baseline.')
    -- ... and the narrowing must be REAL, not a constant that trivially
    -- satisfies the line above.
    assert(SWEEP['shipped_true'] - SWEEP['armed_true'] == SWEEP['site_miss'],
        'shipped_true - armed_true = '
        .. (SWEEP['shipped_true'] - SWEEP['armed_true']) .. ' but site_miss = '
        .. SWEEP['site_miss'] .. '. These are the same rows counted two ways; '
        .. 'if they disagree the helper is not a pure narrowing of the shipped '
        .. 'answer and the assertion above is measuring the wrong thing.')
    cs.ratchet(SWEEP['site_miss'], 43,
        'rows where arming withdraws the race-home permission')
    -- Every withdrawal needs a SECOND member -- with one member the two answers
    -- are the same expression. An equality, not a floor: a miss without a second
    -- member would mean the helper disagrees with itself on a one-element list.
    assert(SWEEP['miss_ge2'] == SWEEP['site_miss'],
        SWEEP['site_miss'] - SWEEP['miss_ge2'] .. ' withdrawal row(s) carry '
        .. 'fewer than 2 enemies. On a one-element list armed and shipped are '
        .. 'the SAME expression, so such a row cannot exist -- the helper is '
        .. 'not reading the list it is documented to read.')
end

tests['[cutoff] 4a. the producer has no sort anywhere on its path'] = function()
    local src = stripped(read_file(TRG))
    -- The list the site reads is C.enemyHeroes, and buildContext fills it from
    -- the world sweep. Both halves are pinned: if either moves, `[1]` might mean
    -- something else and this whole file is about a different defect.
    assert(src:find('GetUnitList(UNIT_LIST_ALL)', 1, true) ~= nil,
        'buildContext no longer builds its hero lists from '
        .. 'GetUnitList(UNIT_LIST_ALL). The claim this file rests on -- that the '
        .. 'list is a WORLD order and therefore observer-independent -- is about '
        .. 'that producer.')
    assert(src:find('table.insert(C.enemyHeroes, u)', 1, true) ~= nil,
        'C.enemyHeroes is no longer filled by the world sweep.')
    assert(src:find('nEnemyHeroes = C.enemyHeroes', 1, true) ~= nil,
        'nEnemyHeroes is no longer C.enemyHeroes at the read site.')
    -- ⛔ And nothing sorts it. A `table.sort` appearing in this file would not
    -- necessarily be on this path, so this is deliberately the WIDE check: it is
    -- cheap to re-read a new sort and expensive to discover one silently.
    local n = 0
    for _ in src:gmatch('table%.sort') do n = n + 1 end
    assert(n == 0,
        'found ' .. n .. ' table.sort call(s) in ' .. TRG .. '. This file '
        .. 'asserts that nEnemyHeroes carries NO order of its own; go read the '
        .. 'new sort and decide whether `[1]` now means something, do not raise '
        .. 'this number.')
end

tests['[cutoff] 4b. `[1]` is not the nearest -- measured, not assumed'] = function()
    -- The four level siblings assert SORT_VIOLATION == 0 here because their
    -- producer inherits a distance sort. This producer does not, and the
    -- difference is the reason this site was taken.
    cs.ratchet(SWEEP['not_nearest'], 162,
        'live rows where nEnemyHeroes[1] is NOT the nearest enemy')
    cs.ratchet(SWEEP['miss_not_nearest'], 28,
        'withdrawal rows where nEnemyHeroes[1] is NOT the nearest enemy')
    assert(SWEEP['not_nearest'] > 0,
        'nEnemyHeroes[1] was the nearest enemy on every row of this corpus. '
        .. 'That does NOT vindicate the shipped clause -- the argument in this '
        .. 'file\'s header is that an observer-independent list cannot be in any '
        .. 'one observer\'s distance order except by coincidence -- but it does '
        .. 'mean the loader is handing back an order this file has not read. Go '
        .. 'read it before trusting any count above.')
end

tests['[cutoff] 4c. the producer, checked on the rows that carry the claim'] = function()
    assert(SWEEP['SELF_IN_LIST'] == 0,
        SWEEP['SELF_IN_LIST'] .. ' withdrawal row(s) carry the observer in its '
        .. 'own enemy list. Contamination of that kind can only ever SATISFY a '
        .. 'floor, so it is asserted as an equality (the lesson anyhero\'s M7 '
        .. 'paid for).')
    assert(SWEEP['SAME_TEAM'] == 0,
        SWEEP['SAME_TEAM'] .. ' withdrawal row(s) carry an ALLY in the enemy '
        .. 'list. The team split is the one thing the race comparison cannot '
        .. 'survive being wrong about: an ally between the bot and the ancient '
        .. 'is not a cut-off.')
end

tests['[cutoff] 4d. the invalid-member skip is inert here, and says so'] = function()
    -- ⛔ THE ONE GUARD IN THE HELPER THIS CORPUS CANNOT FALSIFY. Every member of
    -- every list on this corpus is a valid hero, so the armed loop's
    -- J.IsValidHero skip never fires and no row can tell a helper with the skip
    -- from one without it. It is pinned on the SOURCE instead, and that is
    -- WEAKER than a behaviour pin -- registered, not glossed over.
    assert(SWEEP['invalid_member'] == 0,
        SWEEP['invalid_member'] .. ' list member(s) are not valid heroes. That '
        .. 'is GOOD NEWS: the skip in the armed loop now has real rows, so '
        .. 'replace this source pin with a behaviour assertion on them.')
    local body = stripped(read_file(TRG))
    local s = body:find('function X.AheadOfEveryEnemyToAncient(tHeroes, hBot)', 1, true)
    local e = body:find('\nend', s, true)
    local fn_src = body:sub(s, e + 3)
    assert(fn_src:find('J.IsValidHero(tHeroes[i])', 1, true) ~= nil,
        'the armed loop no longer skips invalid members. This corpus cannot '
        .. 'tell the difference (see above), which is exactly why the guard is '
        .. 'pinned on the source.')
    -- ⛔ The skip cannot break the direction bound in either direction, and that
    -- is structural rather than measured: `[1]` is established valid by the
    -- caller, so `[1]` is never the member that gets skipped.
    assert(fn_src:find('for i = 1, #tHeroes do', 1, true) ~= nil,
        'the armed loop no longer starts at i = 1. The direction bound in '
        .. 'section 3c is exactly the claim that `[1]` is always evaluated.')
    -- ⭐ THE SECOND GUARD THIS CORPUS CANNOT FALSIFY, and the stand is what
    -- found it (M6). The armed comparison is `>=`, not `>`: a DEAD HEAT -- the
    -- bot and a chaser exactly equidistant from the ancient -- must count as
    -- cut off, because shipped's own comparison is the STRICT `<` and would
    -- answer false for that member. Relax `>=` to `>` and armed can be TRUE
    -- where shipped is FALSE, which is a DIRECTION VIOLATION -- the one thing
    -- section 3c exists to forbid. No row can see it: these are float
    -- distances, so exact equality never occurs on this corpus (and would not
    -- on any), which is why it is pinned on the source and said out loud.
    assert(fn_src:find('and nBotDist >= J.GetDistanceFromAncient(tHeroes[i], false)',
        1, true) ~= nil,
        'the armed loop no longer compares with >= against tHeroes[i]. A dead '
        .. 'heat must count as cut off: shipped answers the strict `<`, so a '
        .. '`>` here lets armed be TRUE where shipped is FALSE and section 3c '
        .. 'would be violated on a row this corpus cannot produce.')
end

tests['[cutoff] 5. the FUNCTION\'s return does not move here, and why'] = function()
    -- ⛔ The honest half of this file. The lever's own predicate moves on 43 real
    -- rows, but X.ShouldRun's `return 5` moves on none of them, because the
    -- branch's outer guard is empty on this corpus. Both conjuncts are MEASURED
    -- rather than asserted from reading the diff.
    assert(SWEEP['g_invis'] == 0,
        SWEEP['g_invis'] .. ' row(s) carry J.IsRealInvisible. That is GOOD NEWS: '
        .. 'the branch is reachable now, so drive X.ShouldRun end to end on '
        .. 'those rows and replace this bound -- do NOT re-baseline it.')
    assert(SWEEP['g_retreat'] == 0,
        SWEEP['g_retreat'] .. ' row(s) carry J.IsRetreating. Same as above: a '
        .. 'non-zero here is a driver, not a failure.')
    -- ⇒ the owed frame, stated where it cannot be mistaken for a fire rate:
    --   one frame with an invisible, retreating, ALONE hero (not riki / bounty
    --   hunter / slark) carrying >= 2 enemy heroes within 1600, of which the
    --   FIRST in world order is farther from our ancient than the bot while
    --   another is closer. state.json:cutoff_20260912 carries the same request.
end

tests['[cutoff] 6. the gate, pinned on the shipped source'] = function()
    local src = stripped(read_file(TRG))
    assert(src:find("J.IsSoakCandidate('" .. CAND .. "')", 1, true) ~= nil,
        'the gate id ' .. CAND .. ' is gone from ' .. TRG)
    assert(src:find("J.IsModeTurbo() and J.IsSoakCandidate('" .. CAND .. "')",
        1, true) ~= nil,
        'the lever is no longer turbo-only. Every id in this family is gated on '
        .. 'BOTH, and the turbo leg is not decoration -- the whole optimisation '
        .. 'target is Turbo.')
    -- The call site reads the helper, so section 3's counts are about an
    -- expression that is actually in the tree.
    local want = 'and X.AheadOfEveryEnemyToAncient(nEnemyHeroes, bot)'
    assert(src:find(want, 1, true) ~= nil,
        'X.ShouldRun no longer reads `' .. want .. '`. This file\'s 43 would '
        .. 'otherwise quietly become a statement about an expression that is no '
        .. 'longer in the tree.')
    local calls = 0
    for _ in src:gmatch('X%.AheadOfEveryEnemyToAncient') do calls = calls + 1 end
    assert(calls == 2,
        'X.AheadOfEveryEnemyToAncient appears ' .. calls .. ' times (1 '
        .. 'definition + 1 call expected). A second call site is a second '
        .. 'behaviour riding one id -- go read it.')
end

tests['[cutoff] 7. census: no un-repaired copy of this shape at this site'] = function()
    local src = stripped(read_file(TRG))
    -- The race-home comparison against a single list member, which is THIS
    -- lever's shape.
    local n = 0
    for _ in src:gmatch('GetDistanceFromAncient%(%s*nEnemyHeroes%[%d+%]') do
        n = n + 1
    end
    assert(n == 0,
        'found ' .. n .. ' un-repaired `J.GetDistanceFromAncient(nEnemyHeroes[k], ...)` '
        .. 'site(s) in ' .. TRG .. '. The one this file took is behind an id '
        .. 'now, so a new one means a NEW site was written in the old shape -- '
        .. 'go read it, do not raise this number.')
    -- ⛔ Zero is ALSO what a DELETED guard looks like, so emptiness is only half
    -- the claim. The other half is section 6's live call, which fails if the
    -- clause left the shape by being removed rather than by getting an id.
end

return tests
