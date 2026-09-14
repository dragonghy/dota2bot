-- [hero] [ratchet] [wkbonespawn] The residual that was registered-but-unsettled
-- for 18 days gets a LEVER, and the point of the lever is that it does not need
-- the reading the note asked for.
--
-- ⚠️ THE [ratchet] TAG IS LOAD-BEARING -- do not drop it to tidy the header.
-- 开工自检's Lua leg discovers by TAG (`[detector]`/`[ratchet]` plus four named
-- files) while the push gate discovers by lua_gate_manifest.json row, and a file
-- that falls through BOTH is reported NEW UNCOVERED: nothing automatic runs it,
-- and its red is found by whichever desk starts work next (GH #806, and this
-- desk's own debt one round ago in tests/test_talent_uptake_visibility.lua).
-- This file has no manifest row because adding one means running
-- lua_gate_measure.py, which CLEARS the known_red amnesty list (GH #783) -- i.e.
-- registering this test would hand the next person nine pre-existing reds at
-- their push.  Measured for the record rather than guessed: 2.41s / 2.37s on
-- this container, under the 5.5s per-test cap, so a future round that has a
-- reason to re-measure the manifest can take it in without a cap argument.
--
-- WHAT THE NOTE SAID (verbatim, two places on the tree since 2026-08-27 --
-- bots/BotLib/hero_skeleton_king.lua's talent6 comment and section 5 of
-- tests/test_wk_bone_guard_talent_bypass.lua): "if the engine applies
-- modifier_skeleton_king_bone_guard only while charges are >= 1, then the guard
-- at the top of X.ConsiderW re-imposes exactly the ammunition requirement the
-- t20 bypass exists to lift, and the '+5 from an empty bank' case can never
-- happen no matter how the disjuncts read."  Both places then send the reader to
-- an IN-GAME reading, because HasModifier is engine state and no fixture can
-- answer it.  Nothing was wrong with that note; what nobody did was ask whether
-- the answer CHANGES THE DECISION.
--
-- ⭐⭐ IT DOES NOT.  The residual is a two-world question and the same lever is
-- right in both worlds:
--   * WORLD A (modifier carried at 0 charges): the shipped disjunct is already
--     true, Lua's `or` short-circuits, and the helper is never called.  The
--     armed file is byte-for-byte the shipped one -- a NO-OP.
--   * WORLD B (modifier only at charges >= 1): the shipped guard returns 0 on
--     every empty-bank frame, so both t20 bypasses below it are unreachable
--     exactly when they are worth the most, and the whole of what this hero's
--     t20 row buys (min_skeleton_spawn 0 -> 5) is refused.  The lever restores
--     it.
-- Section 5 DRIVES that dichotomy rather than asserting it: one tally, called
-- twice with the modifier injected and not injected, on the same real frame.
--
-- WHY THE TALENT IS A CONJUNCT AND NOT A COURTESY.  On an empty bank with the
-- t20 row untrained a release fields ZERO skeletons and burns the flat 42s
-- cooldown -- strictly worse than not casting.  So the helper answers true only
-- when the row is trained.  `IsTrained()` is an ENGINE read, not a soak id, so
-- this gate cannot be frozen false by a sibling's promote (the `pullcad` trap);
-- section 1 asserts the helper body names no second candidate.
--
-- ⛔ DIRECTION IS SINGLE BY CONSTRUCTION.  The helper is consulted only after the
-- shipped disjunct has already failed, and its only possible contribution is
-- false -> true on one disjunct of a refusal chain.  Arming can only ADD Bone
-- Guard releases; a negative wave read is attributable to "the extra empty-bank
-- releases were bad" and NEVER to a release this lever took away.
--
-- ⚠️ WHAT IS AND IS NOT FIXTURE-DRIVEN, said before anyone quotes this file as
-- validation.
--   * DRIVEN ON REAL FRAMES: the reachability half.  33 live Wraith King frames
--     carry Bone Guard at rank >= 1; 19 of them carry a modifier list at all
--     (sibling control: 19/19 carry the innate
--     modifier_skeleton_king_vampiric_spirit_aura, so the absence is not "this
--     corpus has no WK modifiers"); and 0 of those 19 carry the charge
--     modifier.  The shipped disjunct therefore refuses on 19/19 informative
--     frames and this helper is the only thing that can open them.
--   * NOT DRIVEN, AND THAT IS A MECHANISM RATHER THAN AN OMISSION: `IsTrained()`.
--     The dumper drops every hero-unique talent before it is written (settled
--     H1; the WK t20 row is one of the three unique rows the 2026-09-14 hero
--     round priced), so a corpus read answers false whether or not the row is
--     trained.  The talent half is therefore supplied as an ARGUMENT, labelled
--     everywhere it is used, and never smuggled in as a frame reading.
--   * NOT MEASURED AT ALL: frequency.  "0 of 19" is a statement about a corpus
--     of instants cut for other investigations, not about a game.  Sizing needs
--     a wave: iterations/queue.json hero-83.
--   * The 14 WK frames with NO modifier list are SILENT, not negative.  They are
--     excluded from the 19 for the same reason test_wk_bone_guard_talent_bypass
--     excludes them: an absent list cannot distinguish "does not carry it" from
--     "the pipeline did not record it".
--
-- ⚠️ ONE FILTER IN SECTION 3 IS DEFENSIVE, NOT LOAD-BEARING, and it is said here
-- rather than left for the next reader to discover.  `wlvl >= 1` (Bone Guard
-- actually learned) excludes NOTHING on today's corpus: all 33 live Wraith King
-- rows that carry an abilities table carry Bone Guard at rank >= 1, so the count
-- is 33 with the filter and 33 without it.  Measured, not assumed --
-- tools/agent/mutstand_wkbonespawn.sh records it as a mutant that SURVIVES and
-- explains why it is kept anyway (the population this file talks about is "Bone
-- Guard is learned", and a corpus that later holds a rank-0 WK must not quietly
-- join it).  Same shape as the liveness predicate GH #794 found non-load-bearing
-- in tests/test_wk_reserve_idle_release.lua while it was load-bearing in three
-- sibling files.
--
-- ⚠️ AND THE READING THAT SOUNDS LIKE A DISAPPOINTMENT BUT IS NOT.  Section 7
-- drives the whole of X.ConsiderW on all 19 informative frames and finds armed
-- and unarmed BYTE-IDENTICAL (0 on 19/19, both legs).  That is not the lever
-- being inert in game: it is the talent blindness above arriving at the call
-- site, because the helper's own conjunct reads the t20 row off a handle the
-- dumper never wrote.  The lever's effect is representable at the HELPER (section
-- 4, with the talent state supplied) and not at the FUNCTION, and conflating
-- those two is how a "no effect" verdict would get written about a lever nobody
-- had armed in a world where it can act.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local WK = 'npc_dota_hero_skeleton_king'
local W = 'skeleton_king_bone_guard'
local BONE_MOD = 'modifier_skeleton_king_bone_guard'
local SIBLING_MOD = 'modifier_skeleton_king_vampiric_spirit_aura'
local CAND = 'wkbonespawn'

-- The frame section 5 drives.  Named rather than globbed: it is the one the
-- census below reports with Bone Guard at rank 4, off cooldown, and enough mana
-- to make IsFullyCastable a real clause instead of a free pass -- and section 5
-- re-asserts all three rather than trusting this comment.
local DRIVE = 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- A talent handle that is NOT a frame reading.  Every call site below says out
--- loud that the boolean came from here; see the coverage note in the header.
local function talent_row(vTrained)
    return { IsTrained = function() return vTrained end }
end

--- Every fixture holding a LIVE Wraith King with an abilities list AND Bone
--- Guard at rank >= 1.  The liveness conjunct is the GH #794 ruling's (a dead
--- row has no per-frame state and driving one raises on `nLV >= 6`); the
--- abilities conjunct is the older one (a blank handle answers rank 0 / cd 0 /
--- cost 0, three readings indistinguishable from "unlearned, ready, free").
local function wk_corpus()
    local out = {}
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for line in p:lines() do
        if line:match('%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == WK then
                    if type(u.abilities) == 'table' and u.alive ~= false then
                        local wlvl
                        for _, a in ipairs(u.abilities) do
                            if a.name == W then wlvl = a.level end
                        end
                        if wlvl ~= nil and wlvl >= 1 then
                            local mods = {}
                            local hasList = type(u.modifiers) == 'table'
                            if hasList then
                                for _, m in ipairs(u.modifiers) do
                                    local nm = (type(m) == 'table' and (m.name or m[1])) or m
                                    if type(nm) == 'string' then mods[nm] = true end
                                end
                            end
                            out[#out + 1] = {
                                path = path, wlvl = wlvl, hasList = hasList, mods = mods,
                            }
                        end
                    end
                    break
                end
            end
        end
    end
    return out
end

--- Load one real frame, optionally arm the candidate, optionally leave turbo.
local function frame(path, opt)
    opt = opt or {}
    local J, bot = rf.load(path, WK)
    -- `== true` and `id == CAND`: an absent id must read false, and a typo in the
    -- id must arm nothing rather than everything.
    J.IsSoakCandidate = function(id) return (opt.arm == true and id == CAND) end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)   -- primes the file-level nLV
    return X, bot, J
end

-- ---------------------------------------------------------------------------
-- 1. The SHAPE the whole file rests on, read off the source.  Every claim in the
--    header is a claim about this shape, so a future edit that moves it must
--    make this section red rather than leave the reasoning silently obsolete.

tests['[section 1] the helper is the RIGHT operand of an or whose left is the shipped read'] =
function()
    local src = read_file(WK_SRC)

    local body = src:match('function X%.wk_IsBoneGuardEmptyBankOpen%b()(.-)\nend')
    assert(body ~= nil, 'X.wk_IsBoneGuardEmptyBankOpen is gone from ' .. WK_SRC
        .. '; every reading below drives it by name')

    -- The gate must be the FIRST live statement.  This is not style: the talent
    -- handle is dereferenced below it, and gate-off equivalence has to include
    -- ERROR behaviour (a nil handle must raise no earlier than it does today).
    local live = {}
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') and line:match('%S') then live[#live + 1] = line end
    end
    assert(live[1] ~= nil and live[1]:find('J.IsModeTurbo()', 1, true)
        and live[1]:find("J.IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'the first live statement of the helper is "' .. tostring(live[1])
        .. '"; it must be the turbo+candidate gate, because everything after it '
        .. 'touches a handle the shipped chain never touches')

    -- pullcad check: exactly one candidate id, and it is this one.  A gate whose
    -- condition names a SECOND id is frozen false the day that id is promoted.
    local ids = {}
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do ids[#ids + 1] = id end
    assert(#ids == 1 and ids[1] == CAND,
        'the helper names ' .. #ids .. ' candidate id(s) ' .. table.concat(ids, ',')
        .. '; a conjunction with a sibling id is the pullcad trap')

    -- The file-scope fallback read must carry its nil guard ON THE SAME LINE.
    -- Not style: tests/test_focus_talent_reach_wall.lua section 3 requires every
    -- t15+ handle in the focus five to be read on a line that also tests
    -- IsTrained(), and it CAUGHT the first draft of this helper (a two-line
    -- `local hRow = hTalent or talent6` -- nil-safe, and still wrong by that
    -- rule).  Asserted here too so this file defends its own shape rather than
    -- relying on a detector in another file noticing next round.
    assert(body:find('talent6 ~= nil and talent6:IsTrained() == true', 1, true),
        'the fallback read of the t20 handle is no longer '
        .. '`talent6 ~= nil and talent6:IsTrained() == true`.  Either the nil '
        .. 'guard went (GH #366 leaves that handle untrainable, and an unguarded '
        .. 'read is the shape zusboltcap shipped) or the read left the line its '
        .. 'IsTrained() test is on')

    -- The call site.  The shipped HasModifier read must still be the LEFT operand
    -- so that Lua short-circuits past the helper in world A.
    local guard = src:match('function X%.ConsiderW%b()%s*(.-)then return 0 end')
    assert(guard ~= nil, 'X.ConsiderW no longer opens with a refusal chain ending '
        .. 'in `then return 0 end`; section 5 drives that chain')
    local lhs, rhs = guard:match('not%s*%(%s*bot:HasModifier%(%s*"([%w_]+)"%s*%)%s*'
        .. '\r?\n?%s*or%s*X%.(wk_IsBoneGuardEmptyBankOpen)%(%s*%)%s*%)')
    assert(lhs == BONE_MOD and rhs == 'wk_IsBoneGuardEmptyBankOpen',
        'the second disjunct of X.ConsiderW is not `not ( bot:HasModifier("'
        .. BONE_MOD .. '") or X.wk_IsBoneGuardEmptyBankOpen() )`.  If the helper '
        .. 'moved to the LEFT of the or, or the arguments became eager, the '
        .. 'world-A no-op in the header is no longer true')

    -- And the three disjuncts the lever must NOT have touched.
    for _, needle in ipairs({ 'abilityW:IsFullyCastable()', 'X.ShouldSaveMana( abilityW )',
                              'abilityW:GetName() ~= "skeleton_king_bone_guard"' }) do
        assert(guard:find(needle, 1, true),
            'the refusal chain lost "' .. needle .. '"; this lever was supposed to '
            .. 'widen exactly one disjunct')
    end
end

-- ---------------------------------------------------------------------------
-- 2. The helper's whole ladder, pure.  The talent boolean is an ARGUMENT here
--    (header coverage note), never a frame reading.

tests['[section 2] gate off, non-turbo, untrained and non-boolean all refuse'] =
function()
    local X, _, J = frame(DRIVE)   -- not armed

    assert(X.wk_IsBoneGuardEmptyBankOpen(talent_row(true)) == false,
        'gate OFF with a TRAINED row must still refuse: unarmed is every shipped '
        .. 'game, and this lever must be inert there')

    J.IsSoakCandidate = function(id) return id == CAND end
    assert(X.wk_IsBoneGuardEmptyBankOpen(talent_row(true)) == true,
        'armed + trained must open; if this is false the lever is wired to nothing '
        .. 'and check_armed_wiring.py would still call it WIRED')
    assert(X.wk_IsBoneGuardEmptyBankOpen(talent_row(false)) == false,
        'armed + UNTRAINED must refuse: on an empty bank an untrained row fields '
        .. 'zero skeletons and burns the flat 42s cooldown')

    -- `IsTrained() == true` and not a bare truth test.  An engine read that
    -- answers 1, or a mock default that answers a table, must not open a cast.
    assert(X.wk_IsBoneGuardEmptyBankOpen(talent_row(1)) == false,
        'a non-boolean truthy answer opened the gate; the helper must compare '
        .. 'against true so an unimplemented reader cannot arm it')
    assert(X.wk_IsBoneGuardEmptyBankOpen(talent_row(nil)) == false,
        'a nil answer opened the gate')

    -- Turbo is the other half of the gate, and it is checked on a real load
    -- rather than by reading the source twice.
    local X2, _, J2 = frame(DRIVE, { arm = true, nonTurbo = true })
    assert(J2.IsModeTurbo() == false, 'the non-turbo injection did not take, so the '
        .. 'next assertion would pass for the wrong reason')
    assert(X2.wk_IsBoneGuardEmptyBankOpen(talent_row(true)) == false,
        'armed but NOT turbo must refuse')
end

tests['[section 2b] with no argument the helper falls back to the file-scope t20 handle'] =
function()
    local X, bot = frame(DRIVE, { arm = true })
    -- The fallback exists so the call site stays a bare call (eager arguments
    -- would break the world-A short circuit).  On a fixture it answers FALSE,
    -- and the reason is the dumper's talent blindness, not a bug here.
    assert(X.wk_IsBoneGuardEmptyBankOpen() == false,
        'the file-scope t20 handle answered TRAINED on a fixture frame.  Talents '
        .. 'are dropped by the dumper before they are written (settled H1), so a '
        .. 'true here means the loader started inventing talent state and every '
        .. '"not driven" note in this file would need re-reading')
    -- Corroborate the mechanism at the source rather than inferring it: the
    -- frame's own ability list carries no special_bonus_* row at all.
    local fx = dofile(DRIVE)
    for _, u in ipairs(fx.units) do
        if u.name == WK then
            for _, a in ipairs(u.abilities or {}) do
                assert(not tostring(a.name):find('special_bonus', 1, true),
                    'this frame DOES carry a talent row (' .. tostring(a.name)
                    .. '); the blindness premise is corpus-specific and must be '
                    .. 're-read')
            end
            break
        end
    end
    assert(bot ~= nil)
end

-- ---------------------------------------------------------------------------
-- 3. The reachability census, on real frames.  These are the numbers the header
--    quotes; re-read the whole section before quoting any one of them.

tests['[section 3] 33 WK frames with Bone Guard learned, 19 informative, 0 carry the charge modifier'] =
function()
    local corpus = wk_corpus()
    assert(#corpus == 33, 'the corpus holds ' .. #corpus .. ' live Wraith King '
        .. 'frames with Bone Guard at rank >= 1, recorded 33.  Fixtures were '
        .. 'added or removed; RE-READ every count in this file before quoting one')

    local nList, nCharge, nSibling = 0, 0, 0
    for _, row in ipairs(corpus) do
        if row.hasList then
            nList = nList + 1
            if row.mods[BONE_MOD] then nCharge = nCharge + 1 end
            if row.mods[SIBLING_MOD] then nSibling = nSibling + 1 end
        end
    end

    assert(nList == 19, 'informative frames (a modifier list at all) read ' .. nList
        .. ', recorded 19')
    assert(nCharge == 0, nCharge .. ' of the ' .. nList .. ' informative frames now '
        .. 'carry ' .. BONE_MOD .. '.  The corpus has become able to answer the '
        .. 'residual for those frames -- that is GOOD NEWS and a re-read, not a '
        .. 'bar to lower: price the lever again on the frames that carry it')
    -- The control, without which "0" is indistinguishable from "this pipeline
    -- records no WK modifiers at all".
    assert(nSibling == nList, 'the sibling control reads ' .. nSibling .. '/' .. nList
        .. '; it must be all of them, or the zero above is a statement about the '
        .. 'dumper and not about the charge modifier')
end

-- ---------------------------------------------------------------------------
-- 4. Direction over the corpus, through ONE tally called twice with its legs
--    swapped -- so the 0 that must hold in one direction is produced by a counter
--    proved able to count (the M14 lesson: an all-zero tally cannot tell "the
--    direction holds" from "the tally never ran").

tests['[section 4] the lever opens 19/19 armed+trained and 0/19 unarmed -- same tally'] =
function()
    local corpus = wk_corpus()

    local function tally(bArm, bTrained)
        local nOpen, nSeen = 0, 0
        for _, row in ipairs(corpus) do
            if row.hasList then
                nSeen = nSeen + 1
                local X = frame(row.path, { arm = bArm })
                if X.wk_IsBoneGuardEmptyBankOpen(talent_row(bTrained)) == true then
                    nOpen = nOpen + 1
                end
            end
        end
        return nOpen, nSeen
    end

    local nArmed, nSeenA = tally(true, true)
    local nBase, nSeenB = tally(false, true)

    assert(nSeenA == 19 and nSeenB == 19,
        'the tally walked ' .. nSeenA .. '/' .. nSeenB .. ' informative frames, '
        .. 'expected 19 in both legs')
    assert(nArmed == 19, 'armed+trained opened ' .. nArmed .. ' of ' .. nSeenA
        .. '; the shipped disjunct refuses on all of them (section 3), so this '
        .. 'must be all 19 or the lever is not reaching the frames it was built for')
    assert(nBase == 0, 'the UNARMED leg opened ' .. nBase .. ' frames.  Unarmed is '
        .. 'every shipped game; a non-zero here is a behaviour change shipping '
        .. 'ungated')
    -- The counter is proved able to count by the armed leg above: nArmed > 0 and
    -- nBase == 0 come out of the same function, so the zero is a refusal and not
    -- a tally that never ran.
    assert(nArmed > nBase, 'the two legs are indistinguishable; the direction claim '
        .. 'in the header rests on this inequality')
end

-- ---------------------------------------------------------------------------
-- 5. The two worlds, DRIVEN.  One frame, one counter, the modifier injected and
--    not injected.  This is the assertion the header's world-A no-op rests on.

tests['[section 5] world A never calls the helper; world B calls it exactly once'] =
function()
    local function probe(bInject)
        local X, bot = frame(DRIVE, { arm = true })

        -- The chain's FIRST disjunct must be a real pass, or the counter below
        -- would read 0 for the wrong reason (it would never reach disjunct two).
        local hW = bot:GetAbilityByName(W)
        assert(hW:GetLevel() >= 1, 'Bone Guard is unlearned on ' .. DRIVE)
        assert(hW:GetCooldownTimeRemaining() <= 0, 'Bone Guard is on cooldown on '
            .. DRIVE)
        assert(bot:GetMana() >= hW:GetManaCost(), 'the hero cannot pay for Bone '
            .. 'Guard on ' .. DRIVE .. ' (' .. bot:GetMana() .. ' < '
            .. hW:GetManaCost() .. '), so IsFullyCastable is false and this probe '
            .. 'cannot reach the disjunct under test')
        assert(hW:IsFullyCastable() == true, 'IsFullyCastable is false despite rank, '
            .. 'cooldown and mana all passing; the loader changed shape')

        local spec = rawget(bot, '__spec')
        local prior = spec.HasModifier
        spec.HasModifier = function(self, sName)
            if sName == BONE_MOD then return bInject end
            return prior(self, sName)
        end
        assert(bot:HasModifier(BONE_MOD) == bInject, 'the injection did not take')

        local nCalls = 0
        local real = X.wk_IsBoneGuardEmptyBankOpen
        X.wk_IsBoneGuardEmptyBankOpen = function(...)
            nCalls = nCalls + 1
            return real(...)
        end

        X.ConsiderW()
        return nCalls
    end

    -- WORLD B: the modifier is absent (the corpus's real state).  The shipped
    -- disjunct fails, so the helper is the only thing that can open the chain --
    -- it must be consulted.
    local nB = probe(false)
    assert(nB == 1, 'with the charge modifier ABSENT the helper was called ' .. nB
        .. ' times, expected exactly 1.  If 0, the chain refuses before reaching '
        .. 'it and this lever can never fire')

    -- WORLD A: the modifier is present.  Lua's `or` short-circuits and the helper
    -- must never run -- that is the whole of the "armed is byte-for-byte shipped"
    -- claim, and the counter above is proved able to count by the line before.
    local nA = probe(true)
    assert(nA == 0, 'with the charge modifier PRESENT the helper was still called '
        .. nA .. ' times.  World A is then no longer a no-op and the lever would '
        .. 'change behaviour in games where the engine carries the modifier at 0 '
        .. 'charges -- exactly the case the header says it leaves alone')
end

-- ---------------------------------------------------------------------------
-- 6. Registered non-claims, asserted so they cannot rot into claims.

tests['[section 6] branch 2 keeps its exact equality and the bank ids keep their own gates'] =
function()
    local src = read_file(WK_SRC)
    local body = src:match('function X%.ConsiderW%b()(.-)\nend')
    assert(body ~= nil, 'X.ConsiderW is gone')

    -- The lever did NOT touch the ammunition tests themselves; they belong to
    -- wkbonebank / wkbonefight and a bundle read must not be attributed here.
    assert(body:find('nStack == maxStack', 1, true),
        'branch 2 no longer reads `nStack == maxStack`.  That exact equality (and '
        .. 'its maxStack-reads-0 corner) predates this lever and was declared '
        .. 'UNTOUCHED by it; if it moved, that declaration is now false')
    assert(body:find('X.wk_IsBoneGuardBankCommittable( nStack, maxStack )', 1, true),
        'branch 1 no longer prices the bank through X.wk_IsBoneGuardBankCommittable')
    assert(body:find('talent6:IsTrained()', 1, true),
        'the t20 bypasses inside the branches are gone; this lever exists to make '
        .. 'them REACHABLE, so with them gone it has nothing to reach')

    -- This helper must not have grown a second reader: the whole direction
    -- argument is "consulted only after the shipped disjunct failed".
    local n = 0
    for _ in src:gmatch('X%.wk_IsBoneGuardEmptyBankOpen%(') do n = n + 1 end
    assert(n == 2, 'X.wk_IsBoneGuardEmptyBankOpen appears at ' .. n
        .. ' sites (definition + calls), expected 2 = the definition and the one '
        .. 'call in X.ConsiderW.  A second call site is a second direction '
        .. 'argument and needs its own one')
end

-- ---------------------------------------------------------------------------
-- 7. The corpus-level equivalence, driven on the whole function -- and the
--    reason it is NOT the lever's domain reading.  See the header's last note.

tests['[section 7] X.ConsiderW answers 0 on 19/19 informative frames, armed and not'] =
function()
    local corpus = wk_corpus()

    local function tally(bArm)
        local nZero, nSeen, nOther = 0, 0, 0
        for _, row in ipairs(corpus) do
            if row.hasList then
                nSeen = nSeen + 1
                local X = frame(row.path, { arm = bArm })
                local ok, desire = pcall(function() return X.ConsiderW() end)
                if not ok then
                    error('X.ConsiderW raised on ' .. row.path .. ': ' .. tostring(desire))
                end
                if desire == 0 then nZero = nZero + 1 else nOther = nOther + 1 end
            end
        end
        return nZero, nSeen, nOther
    end

    local zA, nA, oA = tally(true)
    local zB, nB, oB = tally(false)

    assert(nA == 19 and nB == 19, 'the tally walked ' .. nA .. '/' .. nB
        .. ' informative frames, expected 19 in both legs')
    assert(zB == 19 and oB == 0, 'the UNARMED leg answered non-zero on ' .. oB
        .. ' frames.  Shipped X.ConsiderW is recorded as 0 on every real frame '
        .. '(the charge-modifier guard); if that changed, every domain reading '
        .. 'about this function needs re-reading')
    assert(zA == 19 and oA == 0, 'the ARMED leg answered non-zero on ' .. oA
        .. ' frames.  It must not: the helper needs the t20 row TRAINED, and the '
        .. 'dumper writes no talent rows, so a cast appearing here would mean the '
        .. 'loader started inventing talent state -- not that the lever works')
    -- Proved able to count in the direction that matters: the counter that must
    -- read 0 for "no cast" is the same one that reads 19 for "a zero desire".
    assert(zA + oA == nA and zB + oB == nB,
        'the two counters do not add up to the frames walked, so neither zero '
        .. 'above is evidence of anything')
end

return tests
