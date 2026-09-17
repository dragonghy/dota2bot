-- [strategy 2026-09-16] The '撤退:3' funnel, per conjunct, and the sign of it.
--
-- ⭐ WHAT THIS ADDS TO tests/test_stayfield_tpleg_live_domain.lua, which already
-- pins the HEADLINE of the same reading (trigger 76 -> branch_open 4,
-- margin_live 0).  That file answers "is the domain empty".  This one answers
-- the question the ARCHIVE answered wrongly-by-omission: **which conjunct
-- empties it, and which way does that conjunct point.**
--
-- `state.json:stayfield_RETURNED_20260914` records the disposition as
-- CALLSITE-EMPTY with the sentence "⇒ 解开它**什么都不用买**" -- unlocking it
-- costs nothing.  That is true about COST and it has no lever behind it, and the
-- difference is the whole content of this file:
--
--   * 59 of the 76 trigger frames (78%) are closed by ONE conjunct,
--     `bot:GetLevel() >= 9`;
--   * every conjunct in the funnel is ANDed into a branch head whose BODY is
--     the home trip (`tpLoc = J.GetTeamFountain()`), so a conjunct reading
--     FALSE *prevents* a trip;
--   ⇒ loosening the conjunct that eats the most would CREATE the pathology
--     owner priority P2 forbids, not prevent it.  There is nothing to unlock.
--
-- That sign claim is not a taste and not a count -- it is the shape of a
-- conjunction, so it is asserted STRUCTURALLY off the shipped tree (test C)
-- rather than inferred from the fact that the numbers came out small.
--
-- ⭐⭐ AND THE FOUR SURVIVORS ARE CLOSED ONE BY ONE, which is the anti-vacuum
-- half.  A funnel that ends in 4 can be reported as "empty, near enough" by
-- anyone who does not look at the 4.  Driven on the real frames (test D), they
-- are closed for FOUR DIFFERENT reasons and only ONE of them is an instrument
-- gap:
--   zuus  0.158 lvl12  nothing to drink (an `item_empty_bottle` is worth 0)
--                      AND below the family's own 0.18 floor        -- 2 reasons
--   lina  0.257 lvl14  an enemy tower inside 1200 (danger is real here)
--                      AND its `item_faerie_fire` is in the BACKPACK -- 2 reasons
--   cent  0.096 lvl11  nothing to drink AND below the 0.10 arithmetic bottom
--   lina  0.318 lvl9   P2's own 铁证帧: solo_S TRUE, live_S FALSE, closed by
--                      `fieldsip`'s magnitude clause at SipValue 85 -- and slot
--                      1 is an `item_magic_wand`, whose charges are not in the
--                      dump, so 85 is a LOWER BOUND and this frame is
--                      UNCERTIFIABLE (RULING 37,
--                      owed_executions.json:wandlimbo_charge_instrument).
--
-- ⚠️ The backpacked faerie fire on the lina tower frame is attributed to an
-- UNARMED id, never to an absent one: `bagtango`'s rescuer
-- (TrySwapInvItemForFieldRegen, GH #734) is shipped and gated, so "unreachable"
-- here means "its id is not in the member string", which is a different
-- sentence from "nobody wrote it" and only the first one is true (test E).
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  It does not re-derive the census; the
-- counts below are a RECORDING of tests/_stayfield_tpleg_sweep.lua run on
-- 2026-09-16 over the live 25-id member string, and the sweep is the instrument.
-- What is re-derived here every run is (a) the arithmetic those counts must
-- satisfy, (b) the sign, off the source, and (c) the four frames, driven.  A
-- recorded count that only ever grows under corpus append is a FLOOR; the ones
-- whose entire content is a zero stay EQUALITIES.
--
-- ⚠️ ONE MUTATION IS KNOWN TO SURVIVE THIS FILE, declared rather than left to be
-- discovered: widening `J.FieldRegenSipValue`'s OWN backpack leg past item_flask
-- (the sibling of the leg test D pins on J.HasFieldRegenSource) is not caught
-- here, because no frame below asserts a sip VALUE under 'bagsalve'.  The
-- "these two helpers must agree about which items count" claim belongs to the
-- census test the helpers' own comment names, not to this file; this file's
-- subject is the funnel and its sign.
--
-- Mutation stand 2026-09-16: 9 mutants, 8 CAUGHT, 1 (the one above) out of
-- scope.  The 8 include dropping the level gate from the head, retargeting the
-- body off the fountain, counting an `item_empty_bottle` as a sip, widening the
-- backpack leg to a faerie fire, un-gating the bagtango rescuer, and moving the
-- faerie fire's 85.
--
-- [detector][ratchet]

package.path = 'tests/?.lua;' .. package.path

local tests = {}

local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'
local ROAM = 'bots/mode_team_roam_generic.lua'
local rf = require('mock.replay_fixture')

-- Recorded 2026-09-16, tests/_stayfield_tpleg_sweep.lua, 1039 live hero frames,
-- live 25-id member string (stayfield itself RETURNED, so the wrapper is off).
-- Buckets absent from the sweep's output are zero and are written out here on
-- purpose: the identity below has to sum over the WHOLE row grammar, and a
-- bucket that is silently missing from the sum is how an identity passes
-- vacuously.
local FUNNEL = {
    lvl        = 59,  -- FLOOR, and the headline: 78% of the funnel
    ring       = 7,   -- FLOOR
    attackally = 4,   -- FLOOR
    allies     = 1,   -- FLOOR
    modifier   = 1,   -- FLOOR
    flask      = 0,   -- EQUALITY on this corpus
    name       = 0,   -- EQUALITY on this corpus
    target     = 0,   -- EQUALITY on this corpus
    open       = 4,   -- FLOOR, and it must equal branch_open
}
local TRIGGER     = 76
local BRANCH_OPEN = 4

-- The live armed string, read through the SAME parser 开工自检 uses rather than
-- retyped: a test carrying its own copy of the arm string can agree with itself
-- while disagreeing with the waves.
local armed_cache
local function armed()
    if armed_cache then return armed_cache end
    local cmd = "python3 -c \"import sys; sys.path.insert(0,'tools/agent'); "
        .. "from stale_waits import armed_ids; print(','.join(sorted(armed_ids())))\" 2>/dev/null"
    local p = assert(io.popen(cmd))
    local out = p:read('*a')
    p:close()
    out = (out or ''):gsub('%s+$', '')
    assert(out ~= '', 'could not read the armed member string from test_set.md')
    armed_cache = out
    return out
end

local function read(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- Strip comments so a source ratchet cannot be satisfied by prose describing
--- the code it is meant to be reading. Every file touched here carries long
--- comments naming the very conjuncts and helpers asserted below -- including
--- this one's own header, which quotes several of them verbatim.
local function mask_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- The '撤退:3' branch, split at its `then` into HEAD (the conjunction) and BODY
--- (what firing does). Anchored on the cast-motive STRING, which is code.
local function branch3()
    local src = mask_comments(read(AIUG))
    local a = src:find('if ( botHP < 0.34 or botHP + botMP < 0.43 )', 1, true)
    assert(a, "the '撤退:3' branch head is gone from " .. AIUG
        .. ' -- this reading is about a branch that no longer exists')
    local b = src:find("sCastMotive = '撤退:3'", a, true)
    assert(b, "the '撤退:3' cast motive is gone from " .. AIUG)
    local whole = src:sub(a, b)
    local t = whole:find('\n%s*then%s*\n')
    assert(t, "the '撤退:3' branch head has no `then` on its own line; the "
        .. 'head/body split this file argues the SIGN from cannot be made')
    return whole:sub(1, t), whole:sub(t)
end

--- Load one frame in the honest turbo world (GH #93: the fixture world is Turbo
--- by name and not by the literal 23, and every predicate here opens with
--- IsModeTurbo).
local function world(path, subject)
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load(path, subject)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    return J, bot
end

--- Re-point the gate closure. Every predicate reads J.IsSoakCandidate at CALL
--- time, so this gives a second world without a second load.
local function arm(J, csv)
    local set = {}
    for a in csv:gmatch('[^,]+') do set[a] = true end
    J.IsSoakCandidate = function(id) return set[id] == true end
end

local function slot_names(bot)
    local t = {}
    for i = 0, 8 do
        local it = bot:GetItemInSlot(i)
        t[i] = it and it:GetName() or nil
    end
    return t
end

-- ---------------------------------------------------------------------------
-- A + B. The arithmetic the recorded funnel must satisfy.
-- ---------------------------------------------------------------------------

tests['[ratchet][arith] the funnel sums to the trigger set -- every trigger frame got a row'] = function()
    local sum = 0
    for _, n in pairs(FUNNEL) do sum = sum + n end
    assert(sum == TRIGGER, string.format(
        'the per-conjunct funnel sums to %d but the trigger set is %d. The '
        .. "sweep's own contract is that EVERY trigger frame emits an R row "
        .. 'with the first conjunct that closed it (the anti-vacuum column), '
        .. 'so these two must be equal by construction. A gap means either a '
        .. 'bucket was dropped from this table or the row grammar grew a '
        .. 'category -- re-run tests/_stayfield_tpleg_sweep.lua and re-read, '
        .. 'do not adjust a number to close the gap', sum, TRIGGER))
end

tests['[ratchet][arith] the open bucket IS branch_open, and it is the only survivor count'] = function()
    assert(FUNNEL.open == BRANCH_OPEN, string.format(
        'stop_open %d ~= branch_open %d -- the funnel and the headline count '
        .. 'disagree about how many frames survive every readable conjunct, '
        .. 'and this file drives exactly branch_open of them below',
        FUNNEL.open, BRANCH_OPEN))
end

tests['[ratchet][arith] one conjunct owns the funnel, and it is the level gate'] = function()
    -- The finding, as an inequality rather than as a percentage: the level gate
    -- closes more than every other conjunct put together. If that ever stops
    -- being true the attribution in this file's header is stale and the
    -- "nothing to unlock" conclusion has to be re-argued, not inherited.
    local others = 0
    for k, n in pairs(FUNNEL) do
        if k ~= 'lvl' and k ~= 'open' then others = others + n end
    end
    assert(FUNNEL.lvl > others, string.format(
        'the level gate closes %d frames and all other conjuncts together '
        .. 'close %d; the header attributes the empty domain to the level gate '
        .. 'and that attribution no longer holds', FUNNEL.lvl, others))
end

-- ---------------------------------------------------------------------------
-- C. The SIGN, off the source. This is the claim the archive was missing.
-- ---------------------------------------------------------------------------

tests['[ratchet][source] every funnel conjunct is ANDed into the head, and the body is the trip'] = function()
    local head, body = branch3()

    -- The body is the home trip. If it were not, "a false conjunct prevents a
    -- trip" would be a claim about the wrong branch.
    assert(body:find('tpLoc = J.GetTeamFountain()', 1, true),
        "the '撤退:3' body no longer sets tpLoc to the team fountain, so this "
        .. 'branch is not the home trip this reading is about')

    -- Each conjunct the sweep names as a funnel bucket, in the HEAD, preceded by
    -- `and`. A conjunct of a conjunction whose body is the trip can only ever
    -- PREVENT the trip by being false -- that is the sign, and it is structural.
    local CONJ = {
        lvl        = 'bot:GetLevel() >= 9',
        ring       = 'nEnemyCount <= 1',
        allies     = 'nAllyCount <= 2',
        attackally = '#nAttackAllyList == 0',
        flask      = 'itemFlask == nil',
        target     = 'bot:GetAttackTarget() == nil',
        modifier   = 'modifier_tango_heal',
        name       = 'npc_dota_hero_huskar',
    }
    for bucket, text in pairs(CONJ) do
        assert(FUNNEL[bucket] ~= nil,
            'funnel bucket ' .. bucket .. ' is not in the recorded table')
        local i = head:find(text, 1, true)
        assert(i, string.format(
            "the '%s' conjunct (%s) is no longer in the 撤退:3 head. The sweep "
            .. 'still buckets frames under it, so either the branch was '
            .. 'rewritten or the bucket now means something else -- the SIGN '
            .. 'argument does not survive either way', bucket, text))
        -- `and`-joined, not the trigger disjunction itself: the first line of
        -- the head is the `or` trigger and is deliberately NOT a funnel bucket.
        assert(head:sub(1, i):find('\n%s*and%s'), string.format(
            "the '%s' conjunct is in the head but not reached through an `and`; "
            .. 'if it moved into a disjunction, a FALSE reading no longer '
            .. 'prevents the trip and the sign flips', bucket))
    end
end

tests['[ratchet][source] the gated wrapper is still the only lever wired into this head'] = function()
    local head = branch3()
    assert(head:find('not J.ShouldRegenNotTpHome( bot )', 1, true),
        "the 'stayfield' wrapper left the 撤退:3 head. It is RETURNED out of "
        .. 'the member string, NOT rejected, and RULING 37 kept it verbatim; a '
        .. 'call site that lost it cannot be re-admitted by arming an id')
    local src = mask_comments(read(JMZ))
    assert(src:find("IsSoakCandidate%(%s*'stayfield'%s*%)"),
        'J.ShouldRegenNotTpHome is no longer gated on stayfield')
end

-- ---------------------------------------------------------------------------
-- D. The four survivors, driven. One test each, so a failure names its frame.
-- ---------------------------------------------------------------------------

tests['[frame] zuus 0.158: an empty bottle is worth nothing, and the floor closes it too'] = function()
    local J, bot = world('tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
        'npc_dota_hero_zuus')
    arm(J, armed())
    local s = slot_names(bot)
    assert(s[4] == 'item_empty_bottle', 'slot 4 is no longer the empty bottle '
        .. 'this frame is pinned for; it read ' .. tostring(s[4]))
    assert(J.HasFieldRegenSource(bot) == false,
        'the zuus frame grew a field regen source. Its only consumable-shaped '
        .. 'item is an item_empty_bottle, which the helper excludes BY NAME '
        .. '(CDOTA_Item_EmptyBottle is a different entity) -- if this is now '
        .. 'TRUE the exclusion broke and every P2 domain count is inflated')
    assert(J.FieldRegenSipValue(bot) == 0,
        'FieldRegenSipValue is nonzero on a frame whose only candidate item is '
        .. 'an empty bottle')
    assert(J.GetHP(bot) < 0.18,
        "this frame is also below the family's own 0.18 floor; the second, "
        .. 'independent closure is part of the finding')
end

tests['[frame] lina 0.257: a real tower, and a faerie fire it cannot reach'] = function()
    local J, bot = world('tests/fixtures/f_260820_103630_lina_tower_ring.lua',
        'npc_dota_hero_lina')
    arm(J, armed())
    local s = slot_names(bot)
    -- ⭐ The reachability half: the supply EXISTS and is in the backpack.
    assert(s[6] == 'item_faerie_fire', 'slot 6 is no longer the backpacked '
        .. 'faerie fire this frame is pinned for; it read ' .. tostring(s[6]))
    local main = false
    for i = 0, 5 do
        if s[i] == 'item_faerie_fire' or s[i] == 'item_tango'
            or s[i] == 'item_tango_single' or s[i] == 'item_flask' then main = true end
    end
    assert(main == false,
        'a main-slot heal appeared on this frame, so "the supply is stuck in '
        .. 'the backpack" is no longer what closes it')
    assert(J.HasFieldRegenSource(bot) == false,
        'HasFieldRegenSource is TRUE here. Its backpack widening is flask-only '
        .. "('bagsalve'), and a backpacked faerie fire has no shipped swapper "
        .. "except the gated 'bagtango' rescuer -- if this is TRUE, either the "
        .. 'widening grew past the flask or an unarmed id is being counted')

    -- ⭐ AND AGAIN WITH 'bagsalve' ARMED, which is the assertion that actually
    -- carries the claim. A MUTATION FOUND THIS: widening the backpack leg from
    -- item_flask to item_faerie_fire SURVIVED the line above, because on the
    -- live string 'bagsalve' is unarmed and the backpack loop is never entered
    -- -- so that line was attributing "unreachable" to the ARM STRING while its
    -- own failure message blamed the widening. The source comment's claim is
    -- specifically that the widening "must leave every one of them FALSE" (55
    -- live frames carry a backpacked tango/tango_single/faerie_fire with no
    -- main-slot heal), and that is a claim about the WIDENING, so it has to be
    -- driven in the world where the widening runs.
    arm(J, armed() .. ',bagsalve')
    assert(J.HasFieldRegenSource(bot) == false,
        "with 'bagsalve' ARMED this frame answers TRUE, so the backpack "
        .. 'widening now admits something other than item_flask. That is the '
        .. 'one thing it may never do: there is no shipped swapper for tango / '
        .. 'tango_single / faerie_fire / bottle, so counting one of them here '
        .. 'holds a bot in the field with something it cannot drink. The honest '
        .. "way to widen the SET is to ship the swapper ('bagtango', GH #734), "
        .. 'never to widen this predicate')
    assert(#bot:GetNearbyTowers(1200, true) == 1,
        'the enemy tower inside 1200 is gone from this frame. Danger is the '
        .. 'SECOND closure here and it is the one that makes this frame not a '
        .. 'P2 pathology at all -- P2 exempts genuine retreats')
    assert(J.IsFieldRegenSituation(bot) == false,
        'IsFieldRegenSituation is TRUE next to an enemy tower inside its own '
        .. 'veto radius')
end

tests['[frame] centaur 0.096: nothing to drink, and below the arithmetic bottom'] = function()
    local J, bot = world('tests/fixtures/f_631400_dragon_knight_snowballtarget.lua',
        'npc_dota_hero_centaur')
    arm(J, armed())
    assert(J.HasFieldRegenSource(bot) == false,
        'the centaur frame grew a field regen source')
    assert(J.GetHP(bot) < 0.10, string.format(
        'this frame read %.3f HP. It is pinned as the one BELOW the 0.10 '
        .. "bottom, where one sip provably cannot lift a bot back to the "
        .. "family's 0.18 floor; above 0.10 it would be a different frame with "
        .. 'a different closure', J.GetHP(bot)))
end

tests['[frame] lina 0.318: P2 own 铁证帧 -- solo TRUE, live FALSE, and the wand makes 85 a bound'] = function()
    local J, bot = world('tests/fixtures/f_260822_063722_lina_tp_home.lua',
        'npc_dota_hero_lina')

    -- Solo world: only the RETURNED id armed. This is the ONE frame in the
    -- whole corpus where the TP leg's predicate answers TRUE.
    arm(J, 'stayfield')
    assert(J.ShouldRegenNotGoHome(bot) == true,
        'S is no longer TRUE on the solo string for P2 own 铁证帧; margin_solo '
        .. 'was 1 and this is that 1')
    assert(J.HasFieldRegenSource(bot) == true,
        'the main-slot faerie fire is gone from P2 own pinned frame')
    assert(J.FieldRegenSipValue(bot) == 85,
        'the sip value on the 铁证帧 moved off 85 (the faerie fire); the '
        .. '85-vs-272 arithmetic RULING 37 turns on is stale')

    -- Live world: the magnitude clause closes it, and that is the ONLY closure.
    arm(J, armed())
    assert(J.ShouldRegenNotGoHome(bot) == false,
        'S became TRUE on the live string. margin_live was 0 and it is the '
        .. 'finding of tests/test_stayfield_tpleg_live_domain.lua; a TRUE here '
        .. 'means the TP leg grew a domain and that file must be re-read')
    assert(J.GetHP(bot) >= 0.18 and J.IsFieldRegenSituation(bot) == true,
        'this frame is pinned as the one closed ONLY by the magnitude clause: '
        .. 'it is above the floor and the situation predicate accepts it, so '
        .. 'no danger or floor reason may be borrowed to explain it away')

    -- ⚠️ The instrument gap, named on the frame rather than in prose: slot 1 is
    -- a magic wand, whose charges are not in the dump, so 85 is a LOWER BOUND.
    local s = slot_names(bot)
    assert(s[1] == 'item_magic_wand',
        'slot 1 is no longer the magic wand. That wand is the whole reason '
        .. 'RULING 37 calls this frame UNCERTIFIABLE rather than not-a-case: '
        .. 'FIELD_SIP_HEAL has no wand row and its charge count is not in the '
        .. 'dump, so 85 is a bound and not a measurement. If the wand is gone, '
        .. 'owed_executions.json:wandlimbo_charge_instrument no longer blocks '
        .. 'this frame and the verdict can be RETAKEN')
end

-- ---------------------------------------------------------------------------
-- E. "Unreachable" is attributed to an UNARMED id, never to an absent one.
-- ---------------------------------------------------------------------------

tests['[ratchet][source] the backpack rescuer for tango/faerie fire is SHIPPED and gated'] = function()
    local src = mask_comments(read(ROAM))
    assert(src:find('TrySwapInvItemForFieldRegen', 1, true),
        "the 'bagtango' rescuer (GH #734) is gone from " .. ROAM .. '. This '
        .. "file's lina-tower frame says a backpacked faerie fire is "
        .. 'unreachable BECAUSE its id is unarmed; with the rescuer deleted '
        .. 'that sentence changes meaning to "nobody wrote it"')
    assert(src:find("IsSoakCandidate%(%s*'bagtango'%s*%)"),
        "the 'bagtango' rescuer lost its gate -- it would now run in shipped "
        .. 'games, and the unreachability this file drives would be false')
    local a = src:find('TrySwapInvItemForFlask()', 1, true)
    local b = src:find('TrySwapInvItemForFieldRegen()', 1, true)
    assert(a and b and b > a,
        'the bagtango rescuer is no longer called AFTER the shipped flask '
        .. 'rescuer. Appended-never-inserted is what makes the un-armed tree '
        .. 'byte-identical, and the call order is the whole of that claim')
end

tests['[ratchet][arm] neither P2 decision-side id nor the rescuer is armed today'] = function()
    -- The conclusion this round hands to the director: every id P2 完成定义 1
    -- asks for is WRITTEN, and none of them is in the member string. That is a
    -- statement about the arm string, so it is read off the arm string.
    --
    -- ⭐ 2026-09-17 (director, RULING 73 / test_set.md §HN): `stayfield2` MOVED
    -- from the armed list below to the unarmed list here, because this round
    -- retired it (25 -> 24, disposition `SIBLING-ABSORBED`).  The move is NOT a
    -- bookkeeping edit -- this assertion's own instruction is "re-drive them
    -- before quoting any of this", and that was done:  on the new 24-id string
    -- this file runs `11 tests, 1 failures`, the ONE failure being this
    -- assertion itself.  Test D (the four survivor frames, driven on the live
    -- string) and every other closure here passed UNCHANGED.
    --
    -- ⛔ That is a measurement, not a guess, and the mechanism says why: this
    -- file drives the TP leg (`撤退:3`, J.ShouldRegenNotTpHome, gated
    -- `stayfield` -- already unarmed), while `stayfield2` gates the WALK leg
    -- wrapper J.ShouldRegenNotWalkHome (jmz_func.lua:6416).  The four survivors'
    -- closures never passed through it.  `fieldsip` stays below, because the
    -- 铁证帧 closure IS attributed to its magnitude clause at SipValue 85.
    local csv = ',' .. armed() .. ','
    for _, id in ipairs({ 'stayfield', 'stayfield2', 'tprecov', 'tpdeep',
                          'bagtango', 'bagsalve' }) do
        assert(csv:find(',' .. id .. ',', 1, true) == nil, string.format(
            "'%s' is now ARMED. This file's frames are driven on the live "
            .. 'string and their closures are attributed to it being absent; '
            .. 're-drive them before quoting any of this', id))
    end
    -- ... and the one that IS armed, because the lina-tower and 铁证帧
    -- closures are attributed to it being present.
    for _, id in ipairs({ 'fieldsip' }) do
        assert(csv:find(',' .. id .. ',', 1, true) ~= nil, string.format(
            "'%s' left the member string. The live-world closures above are "
            .. 'attributed to it being armed', id))
    end
end

return tests
