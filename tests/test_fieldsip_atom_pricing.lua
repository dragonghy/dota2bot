-- [strategy 2026-09-08, owner priority P2 / P4.4(ii)] THE FOURTH CENSUS, and
-- the one that finishes pricing the registered promote atom
-- 'field_hold_needs_magnitude' (`iterations/promote_atoms.json`:
-- stayfield / stayfield2 / fieldsip).
--
-- The two rounds before this one priced the atom's two HOLD legs by
-- REACHABILITY -- which home-TP branch or which retreat-chain line gets to them
-- first.  'fieldsip' cannot be priced that way and that is the whole point: it
-- is not wired to a branch at all.  It is a conjunct INSIDE
-- J.ShouldRegenNotGoHome, the predicate both other legs wrap.  So its price is
-- what it does to THEIR domains when the atom is armed as ONE wave -- which is
-- the only question a co-promote atom exists to answer, and the one nobody has
-- asked in the eleven days since the atom was registered.
--
-- ⭐ THE HEADLINE.  Measured on the same 1021-live-frame corpus walk
-- (tests/_tpquiet_sweep.lua, extended -- NOT a fifth full-corpus sweep, which
-- the charter forbids):
--
--     srnwh_armed_true_live      19   -- 'stayfield2''s live domain (a DOMAIN,
--                                     -- not a ceiling; see the third census)
--     fs_sf2_live_killed         19   -- ...of which, killed by co-arming 'fieldsip'
--     fs_sf2_live_survives        0
--     fs_sf1_ceil_killed          2   -- 'stayfield''s ceiling, same treatment
--     fs_sf1_ceil_survives        0
--
-- ⇒ THE ATOM ARMED AS ITS STANDING PLAN DESCRIBES PRODUCES A HOLD WITH ZERO
-- LIVE DOMAIN ON THIS CORPUS.  Both hold legs would read back "tested, no
-- effect" -- the 'pullcad' shape (a lever frozen inert by something else in the
-- same string, with `check_armed_wiring.py` still calling it WIRED), except
-- stated BEFORE the wave instead of after it.
--
-- ⭐⭐ AND THE SAME NUMBER IS THE ATOM'S JUSTIFICATION, WHICH IS WHY THIS IS AN
-- ATTRIBUTION FINDING AND NOT A BUG REPORT.  The 22 frames 'fieldsip' takes off
-- the hold side are the SAME 22 it hands to the supply side
-- (`fs_hold_kills == fs_buy_gains`, asserted), and the supply side is where
-- owner P2's actual rule lives ("买大药").  One of the 19 killed frames is
-- `f_260822_063722_lina_tp_home` -- owner P2's OWN pinned evidence frame, and
-- the frame J.IsFieldSipEnough's own comment block cites as the case it exists
-- for.  So the transfer is the CORRECT behaviour; what is defective is the
-- plan to read it and the hold in one wave.
--
-- ⭐⭐⭐ WHAT 'fieldsip' ARMED ACTUALLY IS ON THIS CORPUS, as arithmetic between
-- two parsed constants rather than as a description.  The bar is
-- `FieldRegenSipValue >= MIN_FRACTION * GetMaxHealth()` and every accepted sip
-- is a constant in one parsed table, so the largest NON-flask sip clears the
-- bar only at or under
--     SIP_NONFLASK_MAX_BAR = max(non-flask heals) / MIN_FRACTION = 135 / 0.25 = 540
-- health.  Above that the predicate is not a magnitude test at all -- it is
-- "is one of the accepted sources a salve".
--
-- ⛔ AND THAT READING IS EARNED ON THE KILLED SET, NEVER INHERITED FROM THE
-- CORPUS.  `fs_maxhp_le_nonflask_bar` is 17, NOT zero: seventeen live frames in
-- this corpus really are small enough for a tango to clear the bar, so the
-- salve-only sentence is FALSE corpus-wide.  It is true where the finding needs
-- it -- `fs_sf2_killed_above_nonflask_bar == fs_sf2_live_killed` -- and that is
-- asserted on the killed set specifically.  A file that had argued the closed
-- form instead of measuring it would have published a false sentence.
--
-- ⛔⛔ WHAT THIS FILE DOES NOT CLAIM.  It does not claim 'fieldsip' is wrong,
-- does not rule on any of the three ids, and does not touch the armed string,
-- test_set.md or queue.json.  The recommendation it hands the director is a
-- WAVE-SHAPE one and is stated in the report, not enacted here.

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local function count(s, needle)
    if s == nil then return 0 end
    local n, at = 0, 1
    while true do
        local i = s:find(needle, at, true)
        if i == nil then break end
        n = n + 1
        at = i + 1
    end
    return n
end

-- ==========================================================================
-- 1. The structure, derived HERE and independently of the sweep
-- ==========================================================================

local facts_cache = nil
local function facts()
    if facts_cache ~= nil then return facts_cache end
    local jmz = read_file(JMZ)
    local bare = strip_comments(jmz)
    local o = {}
    o.min_fraction = tonumber(jmz:match('J%.FIELD_SIP_MIN_FRACTION = ([%d%.]+)'))
    local heal = jmz:match('J%.FIELD_SIP_HEAL = {.-}') or ''
    o.heals = {}
    o.flask, o.max_nonflask, o.n_heals = -1, -1, 0
    for sName, sVal in heal:gmatch('(item_[%w_]+)%s*=%s*(%d+)') do
        local n = tonumber(sVal)
        o.heals[sName] = n
        o.n_heals = o.n_heals + 1
        if sName == 'item_flask' then o.flask = n
        elseif n > o.max_nonflask then o.max_nonflask = n end
    end
    o.sipfn = strip_comments(jmz:match('function J%.IsFieldSipEnough.-\nend')) or ''
    o.srngh = strip_comments(jmz:match('function J%.ShouldRegenNotGoHome.-\nend')) or ''
    -- The definition is not a call site.
    o.callsites = count(bare, 'J.IsFieldSipEnough(')
        - count(bare, 'function J.IsFieldSipEnough(')
    o.hold_calls = count(o.srngh, 'J.IsFieldSipEnough(')
    o.buy_fns = { 'ShouldFieldBuyRegen', 'ShouldFieldBuyRegenHurt',
        'ShouldFieldBuyRegenTower', 'ShouldFieldBuyRegenRing',
        'ShouldFieldBuyRegenDeep' }
    o.buy_with_sip, o.buy_selfgated = 0, 0
    for _, sFn in ipairs(o.buy_fns) do
        local body = strip_comments(jmz:match('function J%.' .. sFn .. '.-\nend')) or ''
        local at_sip = body:find('J.IsFieldSipEnough(', 1, true)
        local at_gate = body:find('if not J.IsSoakCandidate(', 1, true)
        if at_sip then o.buy_with_sip = o.buy_with_sip + 1 end
        if at_gate and at_sip and at_gate < at_sip then
            o.buy_selfgated = o.buy_selfgated + 1
        end
    end
    facts_cache = o
    return o
end

tests['[structure] the sip table and its bar are five constants, all parsed'] = function()
    local o = facts()
    assert(o.min_fraction ~= nil and o.min_fraction > 0,
        'J.FIELD_SIP_MIN_FRACTION no longer parses off ' .. JMZ .. '; every '
        .. 'number this file publishes is a quotient with it in the denominator')
    assert(o.n_heals == 5,
        'J.FIELD_SIP_HEAL now has ' .. o.n_heals .. ' entries, not 5. A new '
        .. 'accepted sip changes max(non-flask) and therefore the bar this '
        .. 'whole census is read against')
    assert(o.flask == 400 and o.max_nonflask == 135,
        'the flask / largest-non-flask heals moved to ' .. o.flask .. ' / '
        .. o.max_nonflask .. '; the "salve-only above the bar" reading is '
        .. 'arithmetic on exactly these two numbers')
    assert(o.heals.item_tango == 115 and o.heals.item_faerie_fire == 85
        and o.heals.item_bottle == 135,
        'a non-flask heal moved; the bar below is derived from their maximum')
end

tests['[structure] the two bars are a quotient, not a number typed in here'] = function()
    local o = facts()
    local nonflask_bar = math.floor(o.max_nonflask / o.min_fraction)
    local flask_bar = math.floor(o.flask / o.min_fraction)
    assert(nonflask_bar == 540,
        'the non-flask bar moved to ' .. nonflask_bar .. ' health. Above it the '
        .. 'armed predicate is a salve-only presence test; the corpus columns '
        .. 'below are read against this exact number')
    assert(flask_bar == 1600,
        'the flask bar moved to ' .. flask_bar .. ' health. ABOVE this bar even '
        .. 'a salve fails the test, i.e. the armed predicate is unsatisfiable '
        .. 'no matter what the bot carries -- a second reading this census '
        .. 'reports rather than assumes')
    assert(nonflask_bar < flask_bar,
        'the two bars crossed; the "salve and only a salve" band between them '
        .. 'is empty and the killed-set reading below has no meaning')
end

tests['[structure] the gate fails OPEN, which is the promote trap on this id'] = function()
    local o = facts()
    assert(count(o.sipfn, "if not J.IsSoakCandidate( 'fieldsip' ) then return true end") == 1,
        'J.IsFieldSipEnough no longer opens with a fail-OPEN gate. Two things '
        .. 'rest on that exact line: unarmed every consumer is byte-for-byte '
        .. 'its pre-fieldsip expression (so the census below compares real '
        .. 'shipped answers), and PROMOTING this id means deleting the LINE, '
        .. 'not just the id -- a promoted id appears in no armed string, so '
        .. 'deleting only the id would freeze the helper at `true` forever and '
        .. 'silently un-narrow the family on the day it is promoted. That is '
        .. 'the \'wandbleed2\' trap already recorded against this very helper '
        .. 'in state.json, and it is pinned here rather than described')
end

tests['[structure] six call sites, split one hold / five buy, all five self-gated'] = function()
    local o = facts()
    assert(o.callsites == 6,
        'J.IsFieldSipEnough now has ' .. o.callsites .. ' call sites, not 6. '
        .. 'The hold/buy split below has to add up to this number')
    assert(o.hold_calls == 1,
        'the HOLD side now calls the sip test ' .. o.hold_calls .. ' times. '
        .. 'Exactly one call, inside J.ShouldRegenNotGoHome, is what makes this '
        .. 'id a conjunct of the predicate BOTH other atom legs wrap')
    assert(o.buy_with_sip == 5,
        'the BUY side now has ' .. o.buy_with_sip .. ' consumers, not 5')
    assert(o.hold_calls + o.buy_with_sip == o.callsites,
        'the hold/buy split (' .. o.hold_calls .. ' + ' .. o.buy_with_sip
        .. ') no longer accounts for all ' .. o.callsites .. ' call sites -- '
        .. 'there is a seventh consumer somewhere this census does not model')
    -- ⭐ The structural reason arming 'fieldsip' ALONE cannot move the buy side:
    -- every buy consumer's OWN gate stands upstream of the sip call and returns
    -- before reaching it.  Asserted here and confirmed on the drive below
    -- (`fs_sip_alone_moves_buy == 0`) -- source order and the running code, not
    -- one standing in for the other.
    assert(o.buy_selfgated == 5,
        'only ' .. o.buy_selfgated .. ' of the 5 buy consumers still put their '
        .. 'own IsSoakCandidate gate UPSTREAM of the sip call. That ordering is '
        .. 'the reason arming this id alone is a hold-side-only change')
end

tests['[structure] the sip guard is APPENDED to the hold predicate, never inserted'] = function()
    local o = facts()
    assert(o.srngh ~= '', 'J.ShouldRegenNotGoHome no longer parses')
    assert(count(o.srngh, 'if not J.') == 3,
        'J.ShouldRegenNotGoHome now has ' .. count(o.srngh, 'if not J.')
        .. ' guards, not 3 (situation / source / sip)')
    -- Locate the LAST guard, THEN ask which one it is.  Counting what follows
    -- the sip CALL is off by one in a direction that reads as a clean zero: a
    -- slice starting at the call has already cut off that call's own `if not`.
    -- Measured while building this cell, and it is the third census's M4 lesson
    -- (find the statement, then ask what it is) in a second shape.
    local at_last, at = nil, 1
    while true do
        local i = o.srngh:find('if not J.', at, true)
        if i == nil then break end
        at_last, at = i, i + 1
    end
    local SIP_GUARD = 'if not J.IsFieldSipEnough('
    assert(at_last ~= nil
        and o.srngh:sub(at_last, at_last + #SIP_GUARD - 1) == SIP_GUARD,
        'the sip guard is no longer the LAST guard in J.ShouldRegenNotGoHome. '
        .. 'Appended-never-inserted is what keeps the shipped clause order and '
        .. 'the shipped answer reachable by the shipped route, which is what '
        .. 'the unarmed leg of every column below depends on')
end

-- ==========================================================================
-- 2. The corpus census (subprocess sweep, memoised)
-- ==========================================================================

local sweep_cache = nil
local function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_tpquiet_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_tpquiet_sweep.lua did not reach its DONE line -- the subprocess '
        .. 'failed, and a truncated manifest must never be read as a small '
        .. 'measurement')
    local G, C, D = {}, {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        local df, dh, dhp, dl, dm = line:match('^D (%S+) (%S+) (%S+) (%S+) (%S+)$')
        if df then
            D[#D + 1] = { fixture = df, hero = dh, hp = tonumber(dhp),
                level = tonumber(dl), maxhp = tonumber(dm) }
        end
    end
    sweep_cache = { G, C, D }
    return G, C, D
end

--- Keeps a MISSING counter from reading as a satisfied assertion (GH #171): the
--- sweep zero-initialises every bucket, so `nil` means the KEY is gone.
local function must(v, sKey)
    assert(v ~= nil, 'the counter `' .. sKey .. '` is missing from the manifest '
        .. 'entirely -- the sweep no longer measures it, and a nil must never '
        .. 'compare equal to a number')
    return v
end

tests['[corpus] the manifest agrees with the structure derived above'] = function()
    local G = sweep()
    local o = facts()
    assert(G.SIP_FN == 1 and G.SIPVAL_FN == 1 and G.SRNGH_FN == 1,
        'the sweep can no longer parse one of the three functions this census '
        .. 'is about; a manifest built on a failed parse reads as all-zeros')
    local function agree(sKey, vHere)
        assert(G[sKey] == vHere,
            'the sweep manifest says ' .. sKey .. ' = ' .. tostring(G[sKey])
            .. ' while this file derives ' .. tostring(vHere) .. ' from the '
            .. 'same source; a divergence means the two read different trees')
    end
    agree('SIP_MIN_FRACTION', o.min_fraction)
    agree('SIP_HEAL_FLASK', o.flask)
    agree('SIP_HEAL_MAX_NONFLASK', o.max_nonflask)
    agree('SIP_HEAL_ENTRIES', o.n_heals)
    agree('SIP_CALLSITES_FILE', o.callsites)
    agree('SRNGH_SIP_CALLS', o.hold_calls)
    agree('SIP_BUY_CONSUMERS', o.buy_with_sip)
    agree('SIP_BUY_SELFGATED', o.buy_selfgated)
    agree('SIP_NONFLASK_MAX_BAR', math.floor(o.max_nonflask / o.min_fraction))
    agree('SIP_FLASK_MAX_BAR', math.floor(o.flask / o.min_fraction))
    assert(G.SIP_GATE_FAILS_OPEN == 1 and G.SRNGH_SIP_IS_LAST_GUARD == 1
        and G.SRNGH_GUARDS == 3,
        'the sweep no longer sees the fail-open gate or the appended guard')
    -- The two hold legs are the SAME predicate at two addresses; the headline
    -- compares them, so the identity has to still hold.
    assert(G.WRAPPERS_IDENTICAL_MOD_ID == 1,
        'the two hold wrappers are no longer byte-identical modulo the id '
        .. 'string, so "one opinion at two addresses" -- which is what lets '
        .. 'this file read both legs off one predicate -- has stopped being true')
end

-- ⭐⭐⭐ THE MISSING-BUMP GUARD, AND WHY `must()` IS NOT IT HERE.  The sweep
-- ZERO-INITIALISES every bucket precisely so that "never reached" and "measured
-- zero" are different things to the parser (GH #171).  But that same
-- zero-initialisation means a bucket's KEY can never disappear from the
-- manifest -- so on a column whose clean-tree value IS zero, renaming its
-- `bump()` call leaves the key present, reading 0, and `must()` sees nothing
-- wrong.  Measured, not reasoned: mutstand_fieldsip.sh's M8 renamed the
-- `fs_sf2_live_survives` bump and SURVIVED the first battery, with `must()`
-- sitting directly on that counter.
--
-- ⇒ THE GUARD A ZERO-VALUED COLUMN NEEDS IS A CLOSURE CHECK ON THE KEY SET,
-- not a nil check on one key: a renamed bump does not remove a key, it ADDS
-- one.  So every `fs_` key in the manifest must be declared here, and every key
-- declared here must be in the manifest.
local FS_COLUMNS = {
    'fs_hold_bare_true', 'fs_hold_sip_true',
    'fs_hold_kills', 'fs_hold_gains', 'fs_hold_kills_swapped', 'fs_hold_gains_swapped',
    'fs_buy_solo_true', 'fs_buy_pair_true',
    'fs_buy_gains', 'fs_buy_losses', 'fs_buy_gains_swapped', 'fs_buy_losses_swapped',
    'fs_sip_alone_moves_buy', 'fs_situation', 'fs_situation_src',
    'fs_partition_both', 'fs_partition_neither',
    'fs_maxhp_le_nonflask_bar', 'fs_maxhp_le_flask_bar',
    'fs_sf2_live_survives', 'fs_sf2_live_killed',
    'fs_sf2_killed_above_nonflask_bar', 'fs_sf2_killed_le_flask_bar',
    'fs_sf1_ceil_survives', 'fs_sf1_ceil_killed',
}

tests['[corpus] the manifest carries EXACTLY this census\'s columns, no more'] = function()
    local _, C = sweep()
    local declared = {}
    for _, k in ipairs(FS_COLUMNS) do
        declared[k] = true
        assert(C[k] ~= nil,
            'the declared column `' .. k .. '` is absent from the manifest')
    end
    for k in pairs(C) do
        if k:sub(1, 3) == 'fs_' then
            assert(declared[k],
                'the manifest carries an UNDECLARED fourth-census column `' .. k
                .. '`. A renamed bump does not remove a key -- the sweep '
                .. 'zero-initialises them all -- it ADDS one, and on a column '
                .. 'whose clean value is zero that is the ONLY visible trace. '
                .. 'Either this file has gone stale against the sweep, or a '
                .. 'bump was renamed and some column above is now reading a '
                .. 'zero that nothing writes to')
        end
    end
end

tests['[corpus] the walk is the same 1021-frame walk, and it did not raise'] = function()
    local _, C = sweep()
    assert(must(C.live, 'live') == 1021,
        'the corpus walk now covers ' .. C.live .. ' live hero frames, not '
        .. '1021. Every number in this file and in the three censuses before it '
        .. 'is stated against that walk; re-baseline them together or not at all')
    assert(must(C.raises, 'raises') == 0,
        C.raises .. ' frame(s) raised inside a census read. A frame that raised '
        .. 'is counted in `live` but in none of the columns, so every column '
        .. 'below silently becomes a lower bound')
    assert(must(C.fs_situation, 'fs_situation') == 57,
        'the field-regen situation now holds on ' .. C.fs_situation .. ' frames, '
        .. 'not 57')
    assert(must(C.fs_situation_src, 'fs_situation_src') == 24,
        C.fs_situation_src .. ' situation frames carry an accepted source, not 24')
    assert(C.fs_situation_src == C.fs_hold_bare_true,
        'the shipped hold predicate (' .. C.fs_hold_bare_true .. ') no longer '
        .. 'equals situation-and-source (' .. C.fs_situation_src .. '), so it '
        .. 'has grown a clause this census does not model')
end

tests['[corpus] armed ALONE, this id cannot move the supply side'] = function()
    local _, C = sweep()
    -- The anti-vacuum for the source-order reading asserted in the structure
    -- block: with only 'fieldsip' armed, all five buy consumers stop at their
    -- own gate.  This is the one column that could turn "armed alone it is
    -- hold-side-only" from a fact into a guess.
    assert(must(C.fs_sip_alone_moves_buy, 'fs_sip_alone_moves_buy') == 0,
        C.fs_sip_alone_moves_buy .. ' buy-consumer answer(s) went TRUE with only '
        .. '\'fieldsip\' armed. Source order says that is impossible (every buy '
        .. 'gate stands upstream of the sip call), so either the order changed '
        .. 'or a sixth consumer exists -- and the hold/buy attribution this '
        .. 'whole census rests on is wrong either way')
end

tests['[corpus] direction, through a counter proved to count'] = function()
    local _, C = sweep()
    -- A counter whose content is all zeros cannot tell "the direction holds"
    -- from "the tally never ran", so both directions go through ONE `tally`
    -- called a second time with the legs SWAPPED: the column that must read 0
    -- on the real call is the column that must report the WHOLE domain on the
    -- swapped call.
    assert(must(C.fs_hold_gains, 'fs_hold_gains') == 0,
        'arming \'fieldsip\' turned the hold TRUE on ' .. C.fs_hold_gains
        .. ' frame(s). It is a pure narrowing -- an appended `if not ... then '
        .. 'return false end` -- and cannot widen anything')
    assert(must(C.fs_hold_kills, 'fs_hold_kills') > 0
        and C.fs_hold_gains_swapped == C.fs_hold_kills,
        'the swapped tally reports ' .. tostring(C.fs_hold_gains_swapped)
        .. ' against a kill count of ' .. tostring(C.fs_hold_kills) .. '. The '
        .. 'zero above is only evidence if this call proves the same tally can '
        .. 'produce a non-zero on the same frames')
    assert(must(C.fs_buy_losses, 'fs_buy_losses') == 0,
        'arming \'fieldsip\' alongside \'fieldbuy\' turned the buy FALSE on '
        .. C.fs_buy_losses .. ' frame(s). The two consumers read one '
        .. 'conjunction with opposite polarity, so it can only widen the buy')
    assert(must(C.fs_buy_gains, 'fs_buy_gains') > 0
        and C.fs_buy_losses_swapped == C.fs_buy_gains,
        'the swapped buy tally reports ' .. tostring(C.fs_buy_losses_swapped)
        .. ' against a gain count of ' .. tostring(C.fs_buy_gains))
end

tests['[corpus] the partition survives arming, in both impossible directions'] = function()
    local _, C = sweep()
    -- 'campvoid' (GH #265) is the shape where a narrowing leaves frames owned
    -- by nobody.  Both impossible states are zero-initialised in the sweep.
    assert(must(C.fs_partition_both, 'fs_partition_both') == 0,
        C.fs_partition_both .. ' armed frame(s) have the hold AND the buy both '
        .. 'TRUE. The two sides read one conjunction with opposite polarity, so '
        .. 'inside the situation exactly one of them must fire')
    assert(must(C.fs_partition_neither, 'fs_partition_neither') == 0,
        C.fs_partition_neither .. ' armed situation frame(s) are owned by '
        .. 'NEITHER side -- the \'campvoid\' shape, and the exact failure the '
        .. 'fieldsip block claims cannot happen')
end

tests['[corpus] the transfer is exact: what the hold loses, the buy gains'] = function()
    local _, C = sweep()
    assert(must(C.fs_hold_kills, 'fs_hold_kills') == 22,
        'the transfer moved to ' .. C.fs_hold_kills .. ' frames, not 22')
    assert(C.fs_hold_bare_true - C.fs_hold_sip_true == C.fs_hold_kills,
        'the hold column (' .. C.fs_hold_bare_true .. ' -> ' .. C.fs_hold_sip_true
        .. ') and the kill count (' .. C.fs_hold_kills .. ') disagree; one of '
        .. 'the two is measuring something else')
    assert(C.fs_buy_pair_true - C.fs_buy_solo_true == C.fs_buy_gains,
        'the buy column (' .. C.fs_buy_solo_true .. ' -> ' .. C.fs_buy_pair_true
        .. ') and the gain count (' .. C.fs_buy_gains .. ') disagree')
    -- ⭐⭐ The sentence the atom's justification rests on, as an equality
    -- between two independently-driven columns rather than as prose: this id
    -- does not DELETE the hold's frames, it MOVES them to the side owner P2's
    -- rule actually names.
    assert(C.fs_hold_kills == C.fs_buy_gains,
        'the hold loses ' .. C.fs_hold_kills .. ' frames while the buy gains '
        .. C.fs_buy_gains .. '. The two sides read ONE conjunction with '
        .. 'opposite polarity, so every frame the magnitude test takes off the '
        .. 'hold must arrive on the buy -- an inequality here means the two '
        .. 'consumers have drifted apart and the "transfer, not deletion" '
        .. 'reading this census hands the director is no longer true')
end

tests['[corpus] ⭐ THE HEADLINE: the atom armed as one wave holds nothing'] = function()
    local _, C = sweep()
    assert(must(C.srnwh_armed_true_live, 'srnwh_armed_true_live') == 19,
        '\'stayfield2\'\'s live domain moved to ' .. C.srnwh_armed_true_live
        .. '; the third census published 19 and this cell is read against it')
    assert(must(C.fs_sf2_live_killed, 'fs_sf2_live_killed') == C.srnwh_armed_true_live,
        'co-arming \'fieldsip\' kills ' .. C.fs_sf2_live_killed .. ' of '
        .. C.srnwh_armed_true_live .. ' live \'stayfield2\' frames. The finding '
        .. 'handed to the director is that it kills ALL of them; a survivor '
        .. 'means the joint wave has something to read after all and the '
        .. 'recommendation has to be re-derived')
    assert(must(C.fs_sf2_live_survives, 'fs_sf2_live_survives') == 0,
        C.fs_sf2_live_survives .. ' live frame(s) survive the joint arming')
    -- ⛔ AND THE HONEST LIMIT ON THAT ZERO.  `fs_sf2_live_survives` is zero
    -- because its branch NEVER EXECUTES on this corpus -- not because a live
    -- tally ran and came back empty.  No key-based guard can see a change to a
    -- branch that never runs (mutstand_fieldsip.sh's first M8 renamed that very
    -- bump and was an EQUIVALENT MUTANT: the key it would have created was
    -- never created, so the manifest came back byte-identical). What CAN be
    -- checked is that the two branches are exhaustive over the live set, which
    -- is what makes the zero a partition of 19 rather than an unread counter --
    -- and the stand's M8 now flips the branch's POLARITY, which this catches.
    assert(C.fs_sf2_live_survives + C.fs_sf2_live_killed == C.srnwh_armed_true_live,
        'the survivor/killed split (' .. C.fs_sf2_live_survives .. ' + '
        .. C.fs_sf2_live_killed .. ') no longer covers the live domain ('
        .. C.srnwh_armed_true_live .. '). The two branches are the only two '
        .. 'outcomes of the joint arming, so a frame counted in neither means '
        .. 'the cell stopped being read on some live frame')
    -- The other hold leg, whose cell is a CEILING (the '撤退:3' trigger is an
    -- upper bound -- `X` is file-local), so this is "at most 2, and none of
    -- them survive" rather than a domain.
    assert(must(C.stayfield_true_in_t3, 'stayfield_true_in_t3') == 2
        and must(C.fs_sf1_ceil_killed, 'fs_sf1_ceil_killed') == 2
        and must(C.fs_sf1_ceil_survives, 'fs_sf1_ceil_survives') == 0,
        '\'stayfield\'\'s branch ceiling is ' .. tostring(C.stayfield_true_in_t3)
        .. ' with ' .. tostring(C.fs_sf1_ceil_survives) .. ' surviving the joint '
        .. 'arming. Both hold legs reading zero is the whole finding')
end

tests['[corpus] the salve-only reading is earned on the killed set, not inherited'] = function()
    local _, C = sweep()
    -- ⛔ The corpus-wide claim is FALSE and is asserted to be false, because a
    -- file that argued the closed form instead of measuring it would have
    -- published a false sentence.  Seventeen live frames really are small
    -- enough for a tango to clear the bar.
    assert(must(C.fs_maxhp_le_nonflask_bar, 'fs_maxhp_le_nonflask_bar') == 17,
        C.fs_maxhp_le_nonflask_bar .. ' live frames sit at or under the '
        .. 'non-flask bar, not 17. This number is deliberately NOT zero and is '
        .. 'not allowed to be assumed away: it is why the salve-only reading is '
        .. 'asserted on the killed set below instead of corpus-wide')
    assert(C.fs_sf2_killed_above_nonflask_bar == C.fs_sf2_live_killed,
        'only ' .. tostring(C.fs_sf2_killed_above_nonflask_bar) .. ' of '
        .. tostring(C.fs_sf2_live_killed) .. ' killed frames sit ABOVE the '
        .. 'non-flask bar. Where that fails, the frame was killed by a genuine '
        .. 'magnitude judgement and not by "you are not carrying a salve", and '
        .. 'the report\'s characterisation of this id stops holding')
    assert(C.fs_sf2_killed_le_flask_bar == C.fs_sf2_live_killed,
        'only ' .. tostring(C.fs_sf2_killed_le_flask_bar) .. ' of '
        .. tostring(C.fs_sf2_live_killed) .. ' killed frames are at or under the '
        .. 'flask bar. Above THAT bar even a salve fails, so such a frame would '
        .. 'have been killed no matter what the bot carried -- a different '
        .. 'finding wearing the same number')
    -- ...and the second reading the two bars produce, reported rather than
    -- assumed: frames where the armed predicate is unsatisfiable outright.
    assert(must(C.fs_maxhp_le_flask_bar, 'fs_maxhp_le_flask_bar') == 944,
        C.fs_maxhp_le_flask_bar .. ' live frames are at or under the flask bar, '
        .. 'not 944. The complement (1021 - this) is the set of frames where '
        .. 'NOTHING in the sip table can pass the test')
end

tests['[rows] owner P2\'s own pinned frame is in the killed set'] = function()
    local _, C, D = sweep()
    assert(#D == C.fs_sf2_live_killed,
        'the manifest printed ' .. #D .. ' killed-frame rows against a count of '
        .. C.fs_sf2_live_killed .. '. A count without its rows cannot be '
        .. 're-checked, which is the whole reason these rows are printed')
    local bPinned = false
    for _, r in ipairs(D) do
        if r.fixture == 'f_260822_063722_lina_tp_home' and r.hero == 'lina' then
            bPinned = true
            assert(r.maxhp > 540 and r.maxhp <= 1600,
                'the pinned frame\'s max health (' .. r.maxhp .. ') left the '
                .. 'salve-only band, so it is no longer an illustration of it')
        end
    end
    -- ⭐⭐ This is why the finding is an ATTRIBUTION problem and not a bug
    -- report: the frame the atom's own comment block cites as the case
    -- 'fieldsip' exists for is one of the frames co-arming it takes away from
    -- the hold.  The transfer is CORRECT; reading it and the hold in one wave
    -- is what does not work.
    assert(bPinned,
        'owner P2\'s pinned evidence frame (f_260822_063722_lina_tp_home, lina) '
        .. 'is no longer in the killed set. That frame is what makes this a '
        .. 'wave-shape finding rather than a defect report -- the id does the '
        .. 'right thing on the owner\'s own病例 while erasing the hold\'s '
        .. 'reading in the same wave')
end

return tests
