-- [ratchet] [strategy 2026-09-16] Soak candidate 'tpstash': a mode guard that
-- is a TAUTOLOGY, on the branch that teleports a bot home to build an item.
--
-- THE DEFECT (shipped default, bots/ability_item_usage_generic.lua, inside
-- X.ConsiderItemDesire["item_tpscroll"], the "Go complete items" branch)
-- ---------------------------------------------------------------------------
--     and (bot:GetActiveMode() ~= BOT_MODE_PUSH_TOWER_TOP
--       or bot:GetActiveMode() ~= BOT_MODE_PUSH_TOWER_MID
--       or bot:GetActiveMode() ~= BOT_MODE_PUSH_TOWER_BOT
--       or bot:GetActiveMode() ~= BOT_MODE_ATTACK)
--
-- GetActiveMode() returns ONE value and the four constants are pairwise
-- distinct, so at most one disjunct can be false and the chain is the literal
-- `true` for EVERY value the engine can return. It is also true for nil. The
-- author wanted `and` -- those four modes are exactly "I am busy hitting
-- something" -- and what shipped filters nothing at all.
--
-- What the branch does once past it: `hEffectTarget = J.GetTeamFountain()`,
-- motive `撤退:1`, return BOT_ACTION_DESIRE_HIGH. So a bot with a full
-- inventory and a recipe in its stash is free to TP to its own fountain WHILE
-- PUSHING A TOWER. In Turbo -- where item timings arrive early enough for
-- inventories to fill during the push, and where grouped pushing is the thing
-- that pays -- that is a push abandoned for a recipe.
--
-- ⛔ WHY NO AUTOMATIC READER HAS EVER SEEN IT. The expression is well-formed
-- Lua with no undefined name, so luacheck (a linter; it executes no expression)
-- is silent by construction, and the file loads, so the smoke loader is silent
-- too. Same blind spot as `wardcomma` and `warddupkey`, a third failure mode:
-- there the operands were wrong, here the OPERATOR is.
--
-- ⛔ WHAT THIS FILE CAN AND CANNOT BUY -- read before quoting any number below
-- ---------------------------------------------------------------------------
-- ⭐ The headline claim is NOT a corpus reading and does not want to be. That
-- the shipped guard is constant is a statement about a finite domain -- the
-- BOT_MODE_* enum -- so §2 EXHAUSTS it instead of sampling it: every mode the
-- engine documents, plus nil, evaluated through both forms, pinned as equality
-- assertions (21/21 shipped-true; armed false on exactly 4). A sampled corpus
-- could never say "for every input"; this can, and a mode added to the engine
-- makes §2 red rather than quietly weakening the claim.
--
-- ⛔ The OTHER two operands are not in the corpus at all, and §3 measures that
-- rather than assuming it:
--   * the stash is slots 9-14 (X.GetNumStashItem / X.IsThereRecipeInStash) and
--     the dumper emits exactly the NINE carried slots 0-8 -- so
--     GetNumStashItem reads 0 on every hero of every fixture, and the branch's
--     second conjunct is UNASKABLE here, not merely rare;
--   * no fixture carries an active mode at all, so the guard's own operand is
--     absent from the corpus.
-- Both are pinned as world assertions (§3 W1/W2) that go RED the day the
-- dumper starts emitting either, which is the day this lever becomes locally
-- testable end to end. `X.IsInvFull` reads slots 0-8 and IS askable, so §3
-- prices that one honestly instead of reporting a zero for the whole branch.
--
-- ⭐ So the zero here is the CONSTRUCTIVE kind on the instrument side and the
-- CORPUS-COVERAGE kind on the game side, and those have different dispositions
-- (charter 0NEXT22/0NEXT23). The branch runs for every drafted hero in every
-- game that lasts long enough to fill an inventory -- nothing about a wave,
-- seed or draft excludes it. It is the DUMP that cannot see the stash. Hence:
-- land gated, with the IOU written as a tripwire rather than as prose.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local SRC = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'
local DOC = 'docs/BOT_API_REFERENCE.md'
local HELPER = 'J.ShouldHoldStashTpWhileBusy'

--- The four modes the author meant to exclude, in source order.
local BUSY = {
    'BOT_MODE_PUSH_TOWER_TOP',
    'BOT_MODE_PUSH_TOWER_MID',
    'BOT_MODE_PUSH_TOWER_BOT',
    'BOT_MODE_ATTACK',
}

ss.assert_clean('file load, tests/test_tpstash_mode_tautology.lua')

local tests = {}

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

--- The "Go complete items" branch condition, comments removed: from its first
--- conjunct down to the `then`.
local function branch_condition()
    local src = strip_comments(read(SRC))
    local body = src:match('(if X%.IsInvFull%(bot%) and '
        .. 'X%.GetNumStashItem%(bot%) >= 1.-)\n%s*then')
    assert(body, 'the "Go complete items" branch condition is gone from '
        .. SRC .. '. If the lever was promoted or removed, this file retires '
        .. 'with it; if the branch was rewritten, re-pin it here.')
    return body
end

--- The helper body, comments removed.
local function helper_body()
    local jmz = strip_comments(read(JMZ))
    local a = jmz:find('function ' .. HELPER:gsub('%.', '%%.'))
    assert(a, HELPER .. ' is gone from ' .. JMZ)
    local b = jmz:find('\nend', a, true)
    return jmz:sub(a, b)
end

-- ==========================================================================
-- §1 THE SITE. Source-level, because it holds for every frame.
-- ==========================================================================

tests['[site] ⭐ the shipped tautology is gone, and nothing else grew one']
= function()
    local src = strip_comments(read(SRC))
    -- The exact disjunctive form that shipped. Its absence is the change.
    assert(not src:find('GetActiveMode%(%) ~= BOT_MODE_PUSH_TOWER_TOP or'),
        'the disjunctive mode guard is back in ' .. SRC .. '. It is the '
        .. 'literal `true` (§2) -- if it returned, the lever is a no-op and '
        .. 'the branch is unguarded again.')
    -- And the whole file carries no OTHER `x ~= A or x ~= B` on this reader.
    local n = 0
    for _ in src:gmatch('GetActiveMode%(%)%s*~=%s*BOT_MODE_%w+%s+or%s+'
        .. '[%w_.:()]*GetActiveMode') do
        n = n + 1
    end
    assert(n == 0, SRC .. ' has ' .. n .. ' tautological GetActiveMode '
        .. 'disjunction(s). Each one is a guard that filters nothing.')
end

tests['[site] the branch still is the fountain TP this lever is about']
= function()
    local src = strip_comments(read(SRC))
    local after = src:match('if X%.IsInvFull%(bot%) and '
        .. 'X%.GetNumStashItem%(bot%) >= 1.-\n%s*then(.-)\n\tend')
    assert(after, 'cannot read the guarded branch body')
    assert(after:find('J%.GetTeamFountain%(%)'),
        'the guarded branch no longer TPs to our own fountain. Every '
        .. 'direction claim in the header rests on that destination.')
    assert(after:find('BOT_ACTION_DESIRE_HIGH'),
        'the guarded branch no longer returns DESIRE_HIGH; "arming can only '
        .. 'WITHHOLD a home TP" rests on the branch being an emitter')
end

tests['[site] the three conjuncts the lever must NOT touch, verbatim']
= function()
    local body = branch_condition()
    -- The wardcomma/M3 lesson: a token no behavioural leg can reach is only
    -- ever caught by a verbatim pin.
    for _, clause in ipairs({
        'X%.IsInvFull%(bot%) and X%.GetNumStashItem%(bot%) >= 1',
        'X%.IsThereRecipeInStash%(bot%) or %(bot:GetStashValue%(%) >= 1000 '
            .. 'and bot:GetGold%(%) > 1100%)',
        'not J%.IsInTeamFight%(bot, 1000%)',
        'nEnemyCount == 0',
    }) do
        assert(body:find(clause), 'a conjunct this lever is not supposed to '
            .. 'touch changed. Missing: ' .. clause)
    end
end

tests['[site] ⭐ the call site hands over nMode and names no candidate id']
= function()
    local body = branch_condition()
    assert(body:find('not ' .. HELPER:gsub('%.', '%%.') .. '%( nMode %)'),
        'the call site no longer reads `not ' .. HELPER .. '( nMode )`. The '
        .. '`not` is load-bearing: un-armed the helper returns false, so the '
        .. 'conjunct is the literal `true` that §2 proves the shipped '
        .. 'expression always was.')
    assert(not body:find('GetActiveMode'), 'the call site calls '
        .. 'GetActiveMode() again. `nMode` is that same call, read once at the '
        .. 'top of this invocation; a second read is the same tick\'s answer '
        .. 'and only obscures that.')
    -- ⛔ The rule test_tpstale_recover_leak.lua enforces for 'tpstale' and
    -- test_tprecov_recover_trip.lua for 'tprecov'/'tpdeep': an id named in
    -- this branch's condition makes this branch's levers jointly armable
    -- instead of separately. This lever's first draft named it inline and
    -- that ratchet turned red the same round -- pinned here so the next
    -- draft of THIS lever is caught by its own file too.
    assert(not body:find('IsSoakCandidate', 1, true),
        'a candidate id is named in the tpscroll branch body; the gate '
        .. 'belongs in the helper so each lever here stays separately armable')
end

tests['[helper] ⭐ gate-first, turbo-second, exactly one id, no unit read']
= function()
    local body = helper_body()
    local n = select(2, body:gsub('IsSoakCandidate', ''))
    assert(n == 1, 'the helper names ' .. n .. ' candidate ids; a second one '
        .. 'freezes the gate FALSE the day the other is promoted (the pullcad '
        .. 'trap)')
    assert(body:find("IsSoakCandidate%( 'tpstash' %)"),
        "the helper's id is no longer 'tpstash'")
    local nGate = body:find("IsSoakCandidate( 'tpstash' )", 1, true)
    local nTurbo = body:find('IsModeTurbo', 1, true)
    assert(nGate and nTurbo and nGate < nTurbo,
        'the helper is no longer gate-first-then-turbo; un-armed it must '
        .. 'reach no engine call at all')
    -- A pure predicate over its argument: it must not grow an opinion of its
    -- own about the unit, or the call site stops being able to reason about
    -- what it asked.
    assert(not body:find('bot', 1, true),
        'the helper now reads the bot; it is meant to answer only "is this '
        .. 'mode one of the four busy ones"')
    for _, m in ipairs(BUSY) do
        assert(body:find('nActiveMode == ' .. m), 'the helper no longer names '
            .. m .. '. §2 prices exactly these four.')
    end
end

-- ==========================================================================
-- §2 ⭐⭐ THE PROOF, EXHAUSTIVE over the mode domain -- not a sample.
-- ==========================================================================

--- Every BOT_MODE_* the engine documents. Read from the API reference rather
--- than hardcoded, so "the whole domain" stays the engine's list and not this
--- file's memory of it.
local function mode_domain()
    local seen, out = {}, {}
    for name in read(DOC):gmatch('BOT_MODE_[A-Z0-9_]+') do
        -- BOT_MODE_DESIRE_* is a desire scale, not a mode.
        if not name:find('^BOT_MODE_DESIRE') and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

--- What shipped: m ~= A or m ~= B or m ~= C or m ~= D.
local function shipped_guard(m)
    return m ~= _G[BUSY[1]] or m ~= _G[BUSY[2]]
        or m ~= _G[BUSY[3]] or m ~= _G[BUSY[4]]
end

--- What is meant, and what the armed leg evaluates.
local function armed_guard(m)
    return m ~= _G[BUSY[1]] and m ~= _G[BUSY[2]]
        and m ~= _G[BUSY[3]] and m ~= _G[BUSY[4]]
end

tests['[proof] the four constants are pairwise distinct -- the whole premise']
= function()
    rf.load('tests/fixtures/' .. 'f_260819_222559_od_eclipse_solo.lua',
        'npc_dota_hero_obsidian_destroyer')
    local seen = {}
    for _, name in ipairs(BUSY) do
        local v = _G[name]
        assert(v ~= nil, name .. ' resolves to nil')
        assert(seen[v] == nil, name .. ' and ' .. tostring(seen[v])
            .. ' are the SAME value. The tautology argument rests entirely on '
            .. 'these four being distinct -- if the engine ever collapsed two '
            .. 'of them the shipped guard would stop being constant.')
        seen[v] = name
    end
end

tests['[proof] ⭐⭐ the shipped guard is TRUE on every mode in the domain']
= function()
    rf.load('tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
        'npc_dota_hero_obsidian_destroyer')
    local domain = mode_domain()
    assert(#domain == 21, 'the documented BOT_MODE_* domain is ' .. #domain
        .. ' names, not 21. This is an EQUALITY on purpose: a mode added to '
        .. 'or removed from the engine must make someone re-read this proof '
        .. 'rather than let it pass on a domain that changed underneath it. '
        .. 'Re-read, then re-baseline -- in that order.')
    local nTrue = 0
    for _, name in ipairs(domain) do
        if shipped_guard(_G[name]) then nTrue = nTrue + 1 end
    end
    assert(nTrue == #domain, 'the shipped guard was FALSE on '
        .. (#domain - nTrue) .. ' of ' .. #domain .. ' documented modes. It '
        .. 'is supposed to be constant-true on all of them.')
    -- nil is in the domain too: an unset mode reads nil and `nil ~= k` is true.
    assert(shipped_guard(nil) == true,
        'the shipped guard is not true for a nil mode')
end

tests['[proof] ⭐ the armed guard is FALSE on exactly the four busy modes']
= function()
    rf.load('tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
        'npc_dota_hero_obsidian_destroyer')
    local domain = mode_domain()
    local blocked = {}
    for _, name in ipairs(domain) do
        if not armed_guard(_G[name]) then blocked[#blocked + 1] = name end
    end
    table.sort(blocked)
    local want = { BUSY[4], BUSY[3], BUSY[2], BUSY[1] }   -- ATTACK sorts first
    table.sort(want)
    assert(#blocked == 4, 'the armed guard blocks ' .. #blocked
        .. ' modes (' .. table.concat(blocked, ' ') .. '), not 4')
    for i = 1, 4 do
        assert(blocked[i] == want[i], 'the armed guard blocks '
            .. table.concat(blocked, ' ') .. ', not ' .. table.concat(want, ' '))
    end
    assert(armed_guard(nil) == true, 'the armed guard blocks a nil mode. It '
        .. 'must not: an unset mode is not one of the four busy ones, and '
        .. 'blocking it would make the lever WIDEN rather than narrow.')
end

tests['[proof] ⭐ armed TRUE set is a strict subset of shipped -- direction']
= function()
    rf.load('tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
        'npc_dota_hero_obsidian_destroyer')
    local domain = mode_domain()
    local nOnlyArmed = 0
    for _, name in ipairs(domain) do
        local m = _G[name]
        -- Armed true while shipped false would be a home TP the shipped code
        -- withheld -- the one thing this lever must never do.
        if armed_guard(m) and not shipped_guard(m) then
            nOnlyArmed = nOnlyArmed + 1
        end
    end
    assert(nOnlyArmed == 0, 'on ' .. nOnlyArmed .. ' mode(s) the armed guard '
        .. 'passes where the shipped one blocks. The lever would EMIT a home '
        .. 'TP the shipped tree held back.')
end

-- ==========================================================================
-- §2b ⭐⭐ THE SAME SWEEP, THROUGH THE REAL SHIPPED HELPER, ON A REAL FRAME.
-- §2 evaluates a MIRROR of the two expressions -- it has to, because the
-- shipped disjunction no longer exists in the tree and this file is the only
-- remaining record of what it evaluated to. §2b evaluates the thing that
-- actually ships: J.ShouldHoldStashTpWhileBusy itself, loaded from a real
-- fixture (so J.IsModeTurbo() is the loader's real Turbo answer and the gate
-- is the real gitignored switch), crossed with the whole mode domain. A
-- disagreement between §2 and §2b means the mirror has drifted from the code.
-- ==========================================================================

local SWEEP_FRAME = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local SWEEP_SUBJ  = 'npc_dota_hero_obsidian_destroyer'

--- Run the real helper over every documented mode, plus nil.
local function sweep_helper(J)
    local blocked, nAsked = {}, 0
    for _, name in ipairs(mode_domain()) do
        nAsked = nAsked + 1
        if J.ShouldHoldStashTpWhileBusy(_G[name]) then
            blocked[#blocked + 1] = name
        end
    end
    nAsked = nAsked + 1
    local bNil = J.ShouldHoldStashTpWhileBusy(nil)
    table.sort(blocked)
    return blocked, bNil, nAsked
end

tests['[driven] ⭐ un-armed the real helper holds NOTHING, across the domain']
= function()
    local J = rf.load(SWEEP_FRAME, SWEEP_SUBJ)
    local blocked, bNil, nAsked = sweep_helper(J)
    assert(nAsked == 22, 'the sweep asked ' .. nAsked .. ' modes, not 22 '
        .. '(21 documented + nil)')
    assert(#blocked == 0, 'un-armed the helper held the TP on '
        .. table.concat(blocked, ' ') .. '. Un-armed it must be false '
        .. 'everywhere -- that is the whole inertness claim.')
    assert(bNil == false, 'un-armed the helper held the TP on a nil mode')
end

tests['[driven] ⭐⭐ armed, the real helper holds on exactly the four busy modes']
= function()
    ss.with_candidate('tpstash', function()
        local J = rf.load(SWEEP_FRAME, SWEEP_SUBJ)
        assert(J.IsSoakCandidate('tpstash') == true,
            'the gate did not open, so this leg measured the unarmed tree')
        local blocked, bNil, nAsked = sweep_helper(J)
        assert(nAsked == 22, 'the sweep asked ' .. nAsked .. ' modes, not 22')
        local want = {}
        for _, m in ipairs(BUSY) do want[#want + 1] = m end
        table.sort(want)
        assert(#blocked == #want, 'armed, the helper holds on ' .. #blocked
            .. ' mode(s) (' .. table.concat(blocked, ' ') .. '), not '
            .. #want .. ' (' .. table.concat(want, ' ') .. ')')
        for i = 1, #want do
            assert(blocked[i] == want[i], 'armed, the helper holds on '
                .. table.concat(blocked, ' ') .. ', not '
                .. table.concat(want, ' '))
        end
        assert(bNil == false, 'armed, the helper holds a nil mode. It must '
            .. 'not: an unset mode is not one of the four busy ones, and '
            .. 'holding it would make the lever WIDEN rather than narrow.')
    end, (function()
        local _, bot = rf.load(SWEEP_FRAME, SWEEP_SUBJ)
        return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
    end)())
end

tests['[driven] the mirror in §2 has not drifted from the shipped helper']
= function()
    ss.with_candidate('tpstash', function()
        local J = rf.load(SWEEP_FRAME, SWEEP_SUBJ)
        for _, name in ipairs(mode_domain()) do
            local m = _G[name]
            -- armed_guard is "the branch may proceed"; the helper is "hold it".
            assert(armed_guard(m) == (not J.ShouldHoldStashTpWhileBusy(m)),
                'on ' .. name .. ' the §2 mirror and the shipped helper '
                .. 'disagree. One of them is wrong and every number in §2 is '
                .. 'suspect until it is worked out which.')
        end
    end, (function()
        local _, bot = rf.load(SWEEP_FRAME, SWEEP_SUBJ)
        return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
    end)())
end

-- ==========================================================================
-- §3 REAL FRAMES. What the corpus can and cannot answer, measured.
-- ==========================================================================

--- Every fixture, recursively -- tests/fixtures has subdirectories, and the
--- top-level-only enumeration is what made a previous round believe this repo
--- has no frame past 850s (it has frames to 1514.1s).
local _frames
local function all_frames()
    if _frames then return _frames end
    local p = assert(io.popen('find tests/fixtures -name "f_*.lua" | sort'))
    local out = {}
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units and fx.self then
            out[#out + 1] = { path = path, fx = fx }
        end
    end
    p:close()
    _frames = out
    return out
end

--- ONE rf.load per fixture for BOTH corpus readings below (the stash census and
--- the inventory census). Cached: loading the corpus three times cost 7.6s and
--- put this file over the push gate's 3.0s per-test cap, i.e. outside the only
--- reader that can refuse a push (GH #843, GH #624).
local _sweep
local function corpus_sweep()
    if _sweep then return _sweep end
    local s = { nSubjects = 0, nStashSlots = 0, nInvFull = 0 }
    for _, f in ipairs(all_frames()) do
        local _, bot = rf.load(f.path, f.fx.self)
        for slot = 9, 14 do
            if bot:GetItemInSlot(slot) ~= nil then
                s.nStashSlots = s.nStashSlots + 1
            end
        end
        local full = true
        for slot = 0, 8 do
            if bot:GetItemInSlot(slot) == nil then full = false; break end
        end
        if full then s.nInvFull = s.nInvFull + 1 end
        s.nSubjects = s.nSubjects + 1
    end
    _sweep = s
    return s
end

tests['[world W1] ⛔ the stash is not in the dump -- 0 stash items, every hero']
= function()
    assert(#all_frames() >= 120, 'only ' .. #all_frames() .. ' fixtures '
        .. 'enumerated; the recursive corpus is ~125. A top-level-only walk '
        .. 'reads 112.')
    local s = corpus_sweep()
    assert(s.nSubjects >= 120, 'only ' .. s.nSubjects .. ' subjects loaded')
    assert(s.nStashSlots == 0, s.nStashSlots .. ' stash slot(s) now carry an item. '
        .. '⭐ THAT IS THE GOOD NEWS, NOT A BUG: the dumper has started '
        .. 'emitting slots 9-14, so X.GetNumStashItem and '
        .. 'X.IsThereRecipeInStash are askable on real frames for the first '
        .. 'time and this lever can finally be pinned END TO END -- make a '
        .. 'fixture on a frame where a pushing bot holds a stash recipe and '
        .. 'assert the armed leg withholds the `撤退:1` TP. Then delete this '
        .. 'assertion. (GH #837 / queue strategy-47 is the same instrument '
        .. 'wall from the other side.)')
end

tests['[world W2] ⛔ no fixture carries an active mode -- the guard operand']
= function()
    local frames = all_frames()
    local nWithMode = 0
    for _, f in ipairs(frames) do
        for _, u in ipairs(f.fx.units) do
            if u.active_mode ~= nil or u.mode ~= nil then
                nWithMode = nWithMode + 1
            end
        end
    end
    assert(nWithMode == 0, nWithMode .. ' unit row(s) now carry an active '
        .. 'mode. The guard\'s OWN operand has arrived in the corpus: §2 can '
        .. 'stop being the only reading, and a real frame in '
        .. 'BOT_MODE_PUSH_TOWER_* can be pinned directly. Delete this '
        .. 'assertion and write that fixture test.')
end

tests['[domain] ⭐ a full inventory IS askable, and priced here']
= function()
    -- IsInvFull reads slots 0-8, which the dump DOES carry. Reporting "the
    -- branch has zero support" for the whole conjunction would hide that one
    -- of its three operands is measurable and sometimes true.
    local s = corpus_sweep()
    local nSubjects, nFull = s.nSubjects, s.nInvFull
    assert(nSubjects >= 120, 'only ' .. nSubjects .. ' subjects')
    -- Not an equality: this one moves whenever a fixture is added, and it is
    -- a reading rather than a claim. It must stay non-vacuous in both
    -- directions -- a corpus where every subject is full, or none is, would
    -- make the conjunct's first term uninformative.
    assert(nFull > 0, 'not one subject in the corpus has all nine carried '
        .. 'slots occupied, so X.IsInvFull is false everywhere and the '
        .. 'branch\'s first conjunct is a second unaskable operand. Say so in '
        .. 'the report rather than quoting §2 alone.')
    assert(nFull < nSubjects, 'every subject has a full inventory, which '
        .. 'means IsInvFull is constant here and prices nothing')
end

-- ==========================================================================
-- §4 THE GATE. Shape and controls.
-- ==========================================================================

local FRAME = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local SUBJ  = 'npc_dota_hero_obsidian_destroyer'

local function side_of()
    local _, bot = rf.load(FRAME, SUBJ)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

tests['[control] un-armed the gate is shut'] = function()
    local J = rf.load(FRAME, SUBJ)
    assert(J.IsSoakCandidate('tpstash') == false,
        'the gate is open with nothing armed')
end

tests['[control] armed on the other side the gate stays shut'] = function()
    local sOther = side_of() == 'radiant' and 'dire' or 'radiant'
    ss.with_candidate('tpstash', function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate('tpstash') == false,
            'the gate fired for a bot on the other side')
    end, sOther)
end

tests['[control] armed under another id the gate stays shut'] = function()
    ss.with_candidate('siegecap', function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate('tpstash') == false,
            'the gate fired under a different candidate id')
    end, side_of())
end

tests['[control] and armed under its own id on its own side, it opens']
= function()
    ss.with_candidate('tpstash', function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate('tpstash') == true,
            'the gate did NOT open under its own id on its own side, so every '
            .. 'armed leg above measured the unarmed tree')
    end, side_of())
end

return tests
