-- [owner priority P2 / GH #340] The HP band of J.IsFieldRegenSituation has two
-- edges, and the two `stayfield` call sites do not see the same number of them.
--
-- WHAT THIS ANSWERS
-- -----------------
-- The replay desk's 2026-08-30T18:57Z decomposition of 201 home TPs (GH #340
-- §2) reports the FIRST FAILING CLAUSE of J.IsFieldRegenSituation, and its
-- second-largest bucket is `hp>0.55` -- 30.6% of the armed leg, 21.4% of the
-- baseline leg. Read as "the hold's HP window is too narrow", that bucket is
-- the largest addressable population in the table after the (correct) danger
-- veto. This file shows it cannot be read that way on the TP leg, because on
-- the TP leg the clause that produced it CANNOT BIND AT ALL.
--
-- THE ARITHMETIC (closed form, no corpus, no sampling)
-- ---------------------------------------------------
-- J.IsFieldRegenSituation vetoes on `nHP < 0.18 or nHP > 0.55`, with
-- nHP = J.GetHP( bot ).
--
-- `stayfield`'s ONLY call site is the '撤退:3' branch of
-- ability_item_usage_generic, and that branch is entered only under
--
--     botHP < 0.34  or  botHP + botMP < 0.43
--
-- where -- and this is the load-bearing part, asserted below rather than
-- assumed -- `botHP` at that call site is `J.GetHP( bot )`, the SAME function
-- the situation predicate reads. The two bands are therefore commensurable
-- with no unit conversion between them: they are two constraints on one
-- quantity.
--
-- botMP = J.GetMP( bot ) is a ratio of non-negative engine quantities, so
-- botMP >= 0, so the second disjunct implies botHP < 0.43. Hence
--
--     sup( botHP | the branch is entered ) = max( 0.34, 0.43 ) = 0.43
--
-- and 0.43 < 0.55. ⇒ **The ceiling clause of J.IsFieldRegenSituation is
-- unsatisfiable at `stayfield`'s only call site.** The floor is not: 0.18 lies
-- strictly inside [0, 0.43), so `hp<0.18` is the ONLY one of the two edges that
-- can decide anything on the TP leg.
--
-- Direction: this is conservative in the same sense the neighbouring files use.
-- Every non-HP conjunct of the branch (twelve of them) is granted as satisfied;
-- the reduction still holds.
--
-- ⭐ WHAT IT BUYS, AND IT IS NOT ANOTHER EMPTINESS PROOF
-- ----------------------------------------------------
-- 1. It reclassifies GH #340's second bucket. `hp>0.55` means `botHP > 0.55 >
--    0.43`, which fails the branch's own entry condition, so **those 30 + 22
--    home TPs were pressed somewhere OTHER than '撤退:3'**. That is an
--    independent, instrument-free derivation of #340 §4.2's own "reach = 0" --
--    and a sharper one, because it names WHICH rows and WHY, without the
--    detector. Widening the hold's HP window could never have caught them.
-- 2. It says where the bucket IS meaningful. On the WALK leg
--    (mode_retreat_generic, `stayfield2`) there is no HP conjunct at all
--    between the mode entry and the call -- the one `botHP` comparison in that
--    prefix is inside `DotaTime() < 0` AND `not enemy:IsBot()`, i.e. pre-horn
--    with a HUMAN opponent, which an all-bot batch game never takes (asserted
--    below). So on that leg both edges are live, and `hp>0.55` becomes a real
--    bucket rather than an artefact of asking the TP question. This is a
--    SECOND, independent reason for the handoff GH #338 already made on
--    different grounds ("this family's (a) can only be read off the walk leg").
--    Two unrelated derivations, one instruction.
-- 3. The residue is bounded. Of #340's table, the buckets that lie inside the
--    TP leg's reachable HP domain are `hp<0.18` (25.5% / 24.3%, excluded BY
--    DESIGN -- owner's principle is that a danger retreat is legitimate) plus
--    the tail (`no heal in bag` 2.0/6.8, `attributed damage` 2.0/1.0,
--    `fieldcreep` 2.0/-, `enemy tower` 1.0/0.0). So the TP leg's addressable
--    population on that corpus is at most ~7-8% of 201 BEFORE the branch's
--    twelve remaining conjuncts are applied -- and GH #338 showed that what
--    those conjuncts leave, on the W27/W28 string, is nothing. Two independent
--    routes to the same zero, by different clauses.
--
-- ⭐⭐ THE REUSABLE CRITERION
-- -------------------------
-- **A clause's measured hit rate is a property of the POPULATION it was
-- evaluated over, not of the guard it lives in.** A first-failing-clause
-- decomposition run over "every home TP" attributes to a shared predicate the
-- rows of call sites that predicate is not wired into; the resulting histogram
-- is arithmetically correct and still mis-ranks the levers, because the biggest
-- bucket can belong to a clause that is dead where the id under test sits. The
-- fix is not a better detector -- it is to intersect the population with the
-- call site's own entry condition BEFORE ranking, which for this family is four
-- constants and no data at all. Same family as GH #319 ("the conjunction holds
-- at the CALL SITE, not at the gate"), one step further: there it was the
-- guard's domain that shrank, here it is the MEASUREMENT's denominator.
--
-- Note the number was already on the table and nobody joined it: the 13:27Z
-- round (charter `0MODE`, GH #333) computed this very 0.43 as the per-press cap
-- of '撤退:3' -- but used it only inside a max() for the retreat BLOCK's
-- supremum (0.87), where it is invisible. Nothing compared it to 0.55.
--
-- WHAT THIS FILE DOES NOT CLAIM
-- -----------------------------
--   * It does not rule on `stayfield` / `stayfield2` membership, and does not
--     re-open, confirm or contradict GH #340's INDETERMINATE verdict. #340
--     measured the TP leg and #340 is right that the TP leg's domain is zero;
--     this file only re-attributes one of its buckets and says which leg the
--     next read belongs on.
--   * It does not say the 0.55 ceiling is wrong or should move. Dead at one
--     call site is not wrong; it is live at the other.
--   * Zero behaviour change, zero new gate ids, zero AWS: every assertion reads
--     the shipped tree or drives a real frame.
--   * The corpus percentages quoted above are GH #340's, reproduced as prose.
--     Nothing here asserts them -- this file cannot see that corpus, and a
--     ratchet that pretends to would be a ratchet on someone else's instrument.
--   * `botMP >= 0` is an EXTERNAL operand (the engine's mana range), not a
--     fact in this tree. It is declared as a [limit] below, with the shape of
--     the source that would have to change for it to stop holding.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ    = 'bots/FunLib/jmz_func.lua'
local ITEMS  = 'bots/ability_item_usage_generic.lua'
local RETMOD = 'bots/mode_retreat_generic.lua'

-- Owner priority P2's own pinned frame: Lina, level 9, 31.8% HP, nearest enemy
-- 6,596 units away. The same subject the rest of this family drives, so a
-- reader can put the two files side by side without re-deriving the frame.
local LINA      = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local LINA_HERO = 'npc_dota_hero_lina'

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Line comments only -- same restriction and same reason as the sibling files
--- in this family: this tree has no long-bracket comments.
local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- Like strip_comments, but BLANKS each comment instead of deleting it, so
--- byte offsets stay identical to the raw file. Needed because the '撤退:3'
--- anchor is itself a comment: the anchor has to be found in the raw text
--- while every clause taken from that offset must be read out of code only.
--- Deleting instead of blanking is how the first draft of this file managed to
--- fail all ten arithmetic cases at once on a perfectly healthy tree.
local function mask_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        local a = line:find('%-%-')
        if a == nil then
            out[#out + 1] = line
        else
            out[#out + 1] = line:sub(1, a - 1) .. string.rep(' ', #line - a + 1)
        end
    end
    return table.concat(out, '\n')
end

local function count(src, needle)
    local n, i = 0, 1
    while true do
        local a = src:find(needle, i, true)
        if a == nil then return n end
        n, i = n + 1, a + 1
    end
end

local function fn_body(src, sName)
    local i = assert(src:find('function ' .. sName .. '%('),
        'no such function in the source: ' .. sName)
    local j = assert(src:find('\nend\n', i, true),
        'unterminated function body: ' .. sName)
    return src:sub(i, j + 4)
end

--- Byte offset of the '撤退:3' branch marker, asserted UNIQUE first. An anchor
--- that matches twice silently widens every span taken from it -- that is the
--- self-inflicted red the 13:27Z round had to fix mid-unit, and the lesson
--- there was to assert the uniqueness rather than remember a grep.
--- Takes the RAW file text (the anchor is a comment) and returns the offset.
local function tp3_at(raw)
    assert(count(raw, '第三种情况') == 1,
        "the '撤退:3' marker comment is no longer unique in " .. ITEMS
        .. ' -- re-anchor this file before trusting any span below')
    return (raw:find('第三种情况', 1, true))
end

--- The CODE of the '撤退:3' branch condition: from the (comment) marker to the
--- fountain assignment that terminates it, comments blanked.
local function tp3_condition(raw)
    local i = tp3_at(raw)
    local code = mask_comments(raw)
    local j = assert(code:find('tpLoc = J.GetTeamFountain()', i, true),
        'the branch no longer ends in a fountain TP')
    return code:sub(i, j)
end

--- The last `local <name> = ...` line at or before `pos`, as text. Used to
--- prove WHICH quantity the branch's botHP/botMP actually are, rather than
--- trusting that a name spelled the same means the same thing.
local function binding_before(src, sName, pos)
    local needle, last = 'local ' .. sName .. ' =', nil
    local i = 1
    while true do
        local a = src:find(needle, i, true)
        if a == nil or a > pos then break end
        last, i = a, a + 1
    end
    assert(last ~= nil, 'no binding of ' .. sName .. ' before the branch')
    local eol = src:find('\n', last, true) or (#src + 1)
    return (src:sub(last, eol - 1):gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Load a frame with turbo forced on and an explicit armed SET, so every
--- reading names the string it was taken on instead of inheriting one.
local function world(fix, hero, armed)
    local J, bot = rf.load(fix, hero)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return (armed or {})[id] == true end
    return J, bot
end

--============================================================================
-- [source] The four constants and the two bindings the arithmetic stands on.
-- Every number below is PARSED, never typed: change one in the tree and the
-- derivation re-runs against the new value instead of silently disagreeing.
--============================================================================

--- { floor, ceiling } of J.IsFieldRegenSituation's HP band.
local function situation_band()
    local body = fn_body(strip_comments(read(JMZ)), 'J.IsFieldRegenSituation')
    local lo, hi = body:match('nHP < ([%d%.]+) or nHP > ([%d%.]+)')
    assert(lo ~= nil, 'the HP band of J.IsFieldRegenSituation no longer parses '
        .. '-- it is the whole subject of this file, re-read it before editing')
    return tonumber(lo), tonumber(hi)
end

--- { hp cap, hp+mp cap } of the '撤退:3' entry condition.
local function tp3_caps()
    local cond = tp3_condition(read(ITEMS))
    local hp, sum = cond:match('botHP < ([%d%.]+) or botHP %+ botMP < ([%d%.]+)')
    assert(hp ~= nil, "the '撤退:3' entry condition no longer parses -- this "
        .. 'file derives the TP leg\'s reachable HP from it')
    return tonumber(hp), tonumber(sum)
end

tests['[ratchet][source] the situation band is a floor and a ceiling on J.GetHP'] = function()
    local lo, hi = situation_band()
    assert(lo > 0 and hi > lo and hi < 1,
        'the band stopped being a proper sub-interval of [0,1]: '
        .. lo .. '..' .. hi)
    local body = fn_body(strip_comments(read(JMZ)), 'J.IsFieldRegenSituation')
    assert(body:find('local nHP = J.GetHP( bot )', 1, true) ~= nil,
        'J.IsFieldRegenSituation stopped reading J.GetHP -- the two bands in '
        .. 'this file are only commensurable because both sides call it')
end

tests['[ratchet][source] the TP call site reads the SAME function for its cap'] = function()
    local raw = read(ITEMS)
    local at  = tp3_at(raw)
    local src = mask_comments(raw)
    assert(binding_before(src, 'botHP', at) == 'local botHP = J.GetHP( bot )',
        "the '撤退:3' branch's botHP is no longer J.GetHP( bot ) -- with a "
        .. 'different reader the two HP bands stop being constraints on one '
        .. 'quantity and every derivation in this file lapses')
    assert(binding_before(src, 'botMP', at) == 'local botMP = J.GetMP( bot )',
        "the '撤退:3' branch's botMP is no longer J.GetMP( bot )")
end

tests['[ratchet][source] botMP is a ratio of engine quantities, hence >= 0'] = function()
    local body = fn_body(strip_comments(read(JMZ)), 'J.GetMP')
    assert(body:find('bot:GetMana() / bot:GetMaxMana()', 1, true) ~= nil,
        'J.GetMP no longer returns a mana ratio -- the step "botMP >= 0, so '
        .. 'botHP + botMP < c implies botHP < c" needs re-deriving')
    assert(body:find('-', 1, true) == nil,
        'J.GetMP grew a subtraction; re-check that it cannot go negative')
end

tests['[ratchet][source] the TP call site is unique, so "the TP leg" is well defined'] = function()
    assert(count(strip_comments(read(ITEMS)), 'J.ShouldRegenNotTpHome(') == 1,
        'a second call site of J.ShouldRegenNotTpHome appeared -- "the TP '
        .. "leg's reachable HP\" is now the union of two branches and the "
        .. 'supremum below is no longer the whole story')
    assert(count(strip_comments(read(RETMOD)), 'J.ShouldRegenNotWalkHome(') == 1,
        'a second call site of J.ShouldRegenNotWalkHome appeared')
end

tests['[ratchet][source] the WALK call site has no HP conjunct above it'] = function()
    local src = strip_comments(read(RETMOD))
    local a = assert(src:find('function GetDesireHelper()', 1, true))
    local b = assert(src:find('J.ShouldRegenNotWalkHome(bot)', a, true))
    local prefix = src:sub(a, b)
    -- One comparison of botHP is expected in this prefix and only one; it is
    -- the pre-horn ladder, which is gated on a HUMAN opponent and so cannot be
    -- taken in an all-bot game. Any OTHER botHP comparison would be a real cap
    -- and would put a ceiling on the walk leg too.
    local seen = {}
    for cmp in prefix:gmatch('botHP%s*[<>][=]?%s*[%d%.]+') do
        seen[#seen + 1] = cmp
    end
    assert(#seen == 1, 'the walk leg grew ' .. #seen .. ' HP comparison(s) '
        .. 'before the call; this file claims both band edges are LIVE there, '
        .. 'which stops being true the moment one of them caps HP')
    assert(prefix:find('if DotaTime() < 0 and ' .. seen[1] .. ' then', 1, true) ~= nil,
        'the one HP comparison on the walk leg moved out of the pre-horn '
        .. 'block: ' .. seen[1])
    local i = assert(prefix:find('if DotaTime() < 0 and ', 1, true))
    local j = assert(prefix:find('end', i, true))
    assert(prefix:sub(i, j):find('not enemy:IsBot()', 1, true) ~= nil,
        'the pre-horn ladder stopped requiring a human opponent -- it can now '
        .. 'fire in a batch game and the walk leg has an HP cap after all')
end

--============================================================================
-- [arith] The derivation itself, recomputed from the parsed constants.
--============================================================================

--- Supremum of botHP over the frames where the '撤退:3' branch is entered,
--- given botMP >= 0. Not attained (both caps are strict), which is why every
--- comparison below is against the open bound.
local function tp_leg_sup()
    local hp, sum = tp3_caps()
    return math.max(hp, sum)
end

tests['[ratchet][arith] the ceiling cannot bind on the TP leg'] = function()
    local _, ceil = situation_band()
    local sup = tp_leg_sup()
    assert(sup < ceil, string.format(
        'the TP leg can now reach botHP up to %.4f, which is NOT below the '
        .. 'situation ceiling %.4f -- the central claim of this file (the '
        .. 'ceiling clause is dead at stayfield\'s only call site) has lapsed, '
        .. 'and GH #340\'s hp>0.55 bucket may now contain 撤退:3 rows',
        sup, ceil))
end

tests['[ratchet][arith] the floor CAN bind on the TP leg'] = function()
    local floor = situation_band()
    local sup = tp_leg_sup()
    assert(floor < sup, string.format(
        'the situation floor %.4f is no longer inside the TP leg\'s reachable '
        .. 'HP [0, %.4f) -- with both edges dead the TP leg stops being an HP '
        .. 'question at all, which is a different finding from this one',
        floor, sup))
    assert(floor > 0, 'a floor of 0 is not a constraint')
end

tests['[ratchet][arith] the sup comes from the mana disjunct, not the HP one'] = function()
    -- Recorded because it is the half a reader is likeliest to get wrong: the
    -- branch's own HP cap is 0.34, comfortably below the floor's neighbourhood,
    -- and it is the SUM disjunct -- an HP cap in disguise, since botMP >= 0 --
    -- that lifts the reachable band to 0.43. Delete the sum disjunct and the
    -- conclusion gets STRONGER, not weaker.
    local hp, sum = tp3_caps()
    assert(sum > hp, string.format(
        'the sum disjunct (%.4f) no longer dominates the HP disjunct (%.4f); '
        .. 'the supremum is now set by a different clause than this file '
        .. 'explains', sum, hp))
end

--============================================================================
-- [drive] The same two edges on a REAL frame. Only J.GetHP is modelled -- one
-- operand, declared -- and every other clause runs on the fixture as recorded.
--============================================================================

--- The '撤退:3' entry condition as a function of (hp, mp), built from the
--- constants parsed out of the tree.
local function tp3_entered(hp, mp)
    local hpcap, sumcap = tp3_caps()
    return hp < hpcap or (hp + mp) < sumcap
end

tests['[ratchet][drive] the real pinned frame sits under the TP leg\'s cap'] = function()
    local J, bot = world(LINA, LINA_HERO, {})
    local hp = J.GetHP(bot)
    assert(hp > 0.30 and hp < 0.33, 'the pinned frame\'s HP moved: ' .. hp)
    assert(tp3_entered(hp, 0), 'owner P2\'s own frame stopped satisfying the '
        .. "'撤退:3' entry condition it was pinned for")
    assert(J.IsFieldRegenSituation(bot),
        'the situation predicate stopped holding on the pinned frame -- the '
        .. 'sibling file test_stayfield_callsite_domain drives the same frame '
        .. 'and expects the same answer')
end

tests['[ratchet][drive] both edges are live on the frame, only one is reachable'] = function()
    local J, bot = world(LINA, LINA_HERO, {})
    local floor, ceil = situation_band()
    local real = J.GetHP

    local function at(hp)
        J.GetHP = function(u) if u == bot then return hp end return real(u) end
        local ok = J.IsFieldRegenSituation(bot)
        J.GetHP = real
        return ok
    end

    -- Both edges genuinely decide this frame: it is not that the ceiling is a
    -- no-op predicate, it is that the TP leg never presents it a frame.
    assert(at(ceil + 0.01) == false, 'above the ceiling the situation still holds')
    assert(at(ceil - 0.01) == true,  'just below the ceiling the situation fails')
    assert(at(floor - 0.01) == false, 'below the floor the situation still holds')
    assert(at(floor + 0.01) == true,  'just above the floor the situation fails')

    -- ...and the frames on which the ceiling did the deciding are exactly the
    -- ones the TP call site cannot reach, for ANY mana value in [0,1].
    for _, mp in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
        assert(tp3_entered(ceil + 0.01, mp) == false,
            'a frame above the situation ceiling now enters the TP branch at '
            .. 'mp=' .. mp)
        assert(tp3_entered(ceil - 0.01, mp) == false,
            'a frame just below the situation ceiling now enters the TP branch '
            .. 'at mp=' .. mp)
    end
    -- Whereas the floor's neighbourhood IS reachable there.
    assert(tp3_entered(floor + 0.01, 1) == true,
        'just above the floor is no longer reachable on the TP leg; the floor '
        .. 'would then be dead too and this file describes the wrong tree')
end

--============================================================================
-- [control] The knife edges, so a model that answered "yes" or "no" flat could
-- not pass the [arith] block by accident.
--============================================================================

tests['[ratchet][control] the entry model has both answers around its own cap'] = function()
    local hp, sum = tp3_caps()
    assert(tp3_entered(hp - 0.01, 1) == true,  'below the HP cap is unreachable')
    assert(tp3_entered(hp + 0.01, 0) == true,  'the sum disjunct stopped admitting')
    assert(tp3_entered(sum + 0.01, 0) == false, 'above the sum cap is reachable')
    assert(tp3_entered(sum - 0.01, 0.5) == false,
        'the sum disjunct stopped counting mana')
    -- The exact caps are strict comparisons, so neither is attained -- but the
    -- HP cap can only be probed with the SUM disjunct switched off, i.e. at
    -- high mana. Probing it at mp=0 (the first draft of this case) reads the
    -- sum disjunct's `0.34 + 0 < 0.43` as the HP cap admitting its own bound,
    -- and reports a non-strict comparison that is not there. Recorded because
    -- it is exactly the confusion the [arith] block exists to prevent: the two
    -- disjuncts constrain the same quantity and neither can be read alone.
    assert(tp3_entered(hp, 1) == false and tp3_entered(sum, 0) == false,
        'a cap became non-strict; the supremum is now a maximum and the '
        .. 'derivation needs a <= where it has a <')
end

tests['[ratchet][control] the two legs disagree, which is the whole point'] = function()
    -- Same predicate, same frame, same HP: reachable on the walk leg, not on
    -- the TP leg. Stated as an assertion so a future edit that gives the walk
    -- leg an HP cap cannot leave this file quietly describing one leg twice.
    local _, ceil = situation_band()
    local probe = ceil + 0.01
    assert(tp3_entered(probe, 0) == false, 'the TP leg reached above the ceiling')
    local src = strip_comments(read(RETMOD))
    local a = assert(src:find('function GetDesireHelper()', 1, true))
    local b = assert(src:find('J.ShouldRegenNotWalkHome(bot)', a, true))
    assert(src:sub(a, b):find('DotaTime() < 0', 1, true) ~= nil,
        'the walk leg prefix changed shape; re-derive its reachable HP before '
        .. 'trusting the asymmetry this file reports')
end

--============================================================================
-- [limit] What is outside the tree, and what this file must not be quoted for.
--============================================================================

tests['[limit] botMP >= 0 is an external operand'] = function()
    -- The step "botHP + botMP < 0.43 implies botHP < 0.43" needs botMP >= 0,
    -- and that is the engine's mana range, not a fact in this repository. The
    -- source shape that carries it is asserted in [source] above; this case
    -- records that it is an ASSUMPTION and names the one hero where J.GetMP
    -- returns something other than mana.
    local body = fn_body(strip_comments(read(JMZ)), 'J.GetMP')
    assert(body:find('npc_dota_hero_huskar', 1, true) ~= nil,
        'J.GetMP lost its huskar special case; re-read it -- this file relies '
        .. 'on knowing every branch of it')
    -- For huskar J.GetMP returns an HP fraction, which is also >= 0, so the
    -- step survives; and the branch excludes huskar by name anyway.
    local cond = tp3_condition(read(ITEMS))
    assert(cond:find("botName ~= 'npc_dota_hero_huskar'", 1, true) ~= nil,
        "the '撤退:3' branch stopped excluding huskar; the one hero where "
        .. 'botMP is not mana is now inside the domain (still >= 0, so the '
        .. 'derivation holds -- but the note above is no longer accurate)')
end

tests['[limit] this file asserts nothing about the GH #340 corpus'] = function()
    -- The percentages this file interprets belong to the replay desk's
    -- instrument on a corpus this process cannot see. Re-attributing a bucket
    -- is an arithmetic claim about the TREE; it is not a re-measurement, and a
    -- later reader must not be able to cite this file as one.
    local body = strip_comments(read('tests/test_stayfield_hp_window_reach.lua'))
    local BOOKKEEPING = 'iter' .. 'ations/'
    assert(body:find(BOOKKEEPING, 1, true) == nil,
        'this file started reading the lab bookkeeping -- it is an arithmetic '
        .. 'ratchet, not a ruling')
    for _, path in ipairs({ JMZ, ITEMS, RETMOD, LINA }) do
        assert(body:find(path, 1, true) ~= nil,
            'a subject path left this file: ' .. path)
    end
end

tests['[limit] this file rules on nobody'] = function()
    -- Neither `stayfield` nor `stayfield2` is admitted, returned, promoted or
    -- rejected here, and GH #340's verdict is not re-opened. Asserted the same
    -- way the sibling file asserts it, for the same reason: an emptiness or
    -- reachability proof is not a verdict, and the distinction is only durable
    -- if something fails when it is blurred.
    -- Each needle is split so the list itself is not a match. A self-scanning
    -- assertion that fires on its own literal reads as a finding and is not
    -- one -- the same guard, and the same reason, as the sibling file's.
    local body = strip_comments(read('tests/test_stayfield_hp_window_reach.lua'))
    for _, halves in ipairs({ { 'prom', 'ote' }, { 'INDETER', 'MINATE' },
                              { 'WOR', 'KING' }, { 'SIL', 'ENT' } }) do
        local word = halves[1] .. halves[2]
        assert(body:find(word, 1, true) == nil,
            'a verdict vocabulary word entered the executable part of this '
            .. 'file: ' .. word)
    end
end

return tests
