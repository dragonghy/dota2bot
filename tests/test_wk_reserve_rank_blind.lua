-- [ratchet] [hero] Wraith King's Reincarnation reserve never asks whether
-- Reincarnation has been LEARNED -- `nLV >= 6` stands in for it, and the two
-- are not the same predicate.  New soak candidate `wkrank0`.
--
-- GH #407, the issue's second open cell.  X.ShouldSaveMana refuses a cast while
--
--     nLV >= 6
--       and nAbility ~= nil and abilityR ~= nil
--       and abilityR:GetCooldownTimeRemaining() <= 3.0
--       and ( GetMana() - nAbility:GetManaCost() < <reserve> )
--
-- Five operands, and NOT ONE of them is R's rank.  An unlearned ability reports
-- a remaining cooldown of 0, so the availability clause waves it through too.
-- The rule therefore holds mana against a death trigger the hero does not own.
--
-- ⭐⭐ WHAT THIS FILE IS FOR, and it is not the gate plumbing.  Section 3 does
-- not ARGUE the blindness, it MEASURES it: on the 7 real frames where the
-- shipped reserve fires, moving Reincarnation's rank from 1 to 0 -- the one
-- operand the rule ought to depend on -- leaves the shipped answer identical on
-- 7 of 7.  A rule whose answer cannot be moved by the fact it is about is blind
-- to it, and that is a reading rather than a sentence.
--
-- ⚠️ SEVEN, where the sibling file tests/test_wk_save_mana_unreachable_cap.lua
-- says SIX about the same shipped predicate.  Both are right and neither is a
-- drift: that file splits `tests/fixtures` only, and the seventh firing frame
-- lives in `tests/frames`.  Section 2.3 carries the finding; it was bought by
-- writing 6 here off the sibling and watching it go red.
--
-- ⭐⭐ AND THE READING THIS DESK WAS TOLD IT HAD TO BUY IS BOUNDED OUT RATHER
-- THAN BOUGHT.  GH #407's archive scan closed by saying the engine's
-- `GetManaCost()` for an UNLEARNED ability "is something a replay cannot
-- answer", and the backlog carried that forward as the blocker.  Section 4
-- drives both answers instead of choosing one:
--   * priced at 0  -> the shipped clause is arithmetically unreachable on these
--                     frames (both call sites put `not IsFullyCastable()` ahead
--                     of X.ShouldSaveMana in an `or` chain, so entering it
--                     entails `GetMana() >= cost`, so `>= 0 < 0` is false) and
--                     this lever is a byte-for-byte no-op;
--   * priced at the rank-1 price -> the rule holds 220 mana for an ability that
--                     cannot be cast, and this lever removes exactly that.
-- Under both, the lever is correct and its direction is unchanged.  The
-- undecided reading moves the lever's DOMAIN SIZE, never its correctness.
--
-- ⚠️ WHAT IS NOT CLAIMED, said before any number below is quoted:
--   * NO DOMAIN IN THIS CORPUS.  Section 2 measures 0: on all 48 priced live
--     Wraith King frames, `nLV >= 6` and "R is trained" AGREE.  The 42 frames
--     where they disagree were measured somewhere else (W34's archive scan, GH
--     #407 comment 3) and are not in here.  A 0 from a corpus assembled for
--     other questions is not a 0 in game -- and it is also not evidence that
--     the lever is live.  Both halves of that are stated because only one of
--     them is comfortable.
--   * NO FREQUENCY.  Nothing here says how often a real Wraith King sits past
--     level 6 with R unlearned; 42 frames is the archive's count, not a rate.
--   * NO CLAIM THAT A RELEASED RESERVE IS A CAST.  Section 5 pins the shipped
--     X.ConsiderQ still answering 0 on the released probe, with the control
--     that separates "the body ran and declined" from "the body never ran".
--   * NOTHING ABOUT THE OTHER TWO RESERVE LEVERS.  `wksavecap` asks how much is
--     reserved and `wksaveidle` asks whether the reserve is idle; section 6
--     drives the three gates' mutual independence rather than asserting it.
--   * NOTHING ABOUT `wkreinctr`.  J.IsWkReincarnationArmed carries the SAME
--     blindness on a different call site (a retreat-mode veto, not a mana
--     reserve) and already has its own conjunct.  The two share a defect shape
--     and neither is evidence for the other; what this file borrows is its
--     accessor convention (section 1.1b).
--
-- ⚠️ PRIOR ART ON THE ZERO, and it is not this file's discovery.
-- tests/test_wk_rank0_absence_join.lua already joined the two readings of
-- "Reincarnation at ability level 0" and ruled that the two hero-level-7
-- "untrained ultimate" frames another file quoted are the ABSENCE rows.  It
-- concluded, on 36 frames, that this tree holds zero recorded frames of the
-- shape.  Section 2 re-derives that independently on 48 (this corpus adds
-- `tests/frames`), and M8 on the stand shows what admitting the absences does.
--
-- SECTIONS
--   1  the gate is wired, turbo-only, and names exactly one id
--   2  the corpus: 48 priced, 32 at level >= 6, 16 at rank 0, intersection 0
--   3  ⭐ the blindness, measured: rank 1 -> 0 moves the shipped answer 0/7
--   4  ⭐ the undecided engine reading, both branches driven
--   5  direction, and a released reserve is not a cast
--   6  inert unarmed / inert outside turbo / independent of both siblings

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_skeleton_king.lua'
local UNIT = 'npc_dota_hero_skeleton_king'
local HELPER = 'IsReincarnationReserveUnlearned'
local CAND = 'wkrank0'
local SIB_CAP = 'wksavecap'
local SIB_IDLE = 'wksaveidle'
local Q = 'skeleton_king_hellfire_blast'
local R = 'skeleton_king_reincarnation'
-- Q's cast range off the KV snapshot.  GetCastRange is on no spec and falls
-- through to the generic `^Get` default of 0 (GH #391), so section 5 feeds it
-- back before reading anything into a silent X.ConsiderQ.
local Q_CAST_RANGE = 525
local DIRS = { 'tests/fixtures', 'tests/frames' }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Comments stripped, so a census counting CODE shapes cannot be satisfied by
--- prose that merely mentions the expression.  The hero file opens with an npc
--- dump inside a block comment whose lines do NOT start with `--`, so the block
--- form goes first (the trap tests/test_wk_fact_anchor.lua documents).
local function strip_comments(s)
    return (s:gsub('%-%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', ''))
end

--- Slice a function by its own terminating column-0 `end` rather than by the
--- next `function X.`, which swallows the NEXT function's header and makes any
--- assertion about something being ABSENT wrong (the trap
--- tests/test_axe_cull_blade_mail.lua section 6 was rebuilt around).
local function fn_code(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend\n')
    assert(to, 'X.' .. name .. ' has no column-0 `end` in ' .. SRC)
    return rest:sub(1, to + 4)
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s, e = hay:find(needle, at, true)
        if not s then return n end
        n, at = n + 1, e + 1
    end
end

local SRC_TEXT = read_file(SRC)
local SRC_CODE = strip_comments(SRC_TEXT)

local function short(path) return (path:gsub('^tests/[a-z]+/', '')) end
local function joined(t) return table.concat(t, ', ') end

local function frame_files()
    local files = {}
    for _, dir in ipairs(DIRS) do
        -- UNRESOLVED_HAND_READ (GH #774 / GH #803, registered in
        -- tests/test_bots_walk_farm_only.py in the SAME work unit that landed
        -- this file): io.popen over a literal directory name held in a local
        -- table above, non-recursive `ls`, no interpolated runtime value.  It
        -- cannot reach bots/Customize/.
        local p = assert(io.popen('ls ' .. dir))
        for line in p:lines() do
            if line:match('%.lua$') then files[#files + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    table.sort(files)
    return files
end

--- The PRICED live Wraith King frames.  A fixture with no abilities list hands
--- back blank handles whose rank 0 / cooldown 0 / cost 0 are an ABSENCE that is
--- the same integer as "unlearned, ready, free" -- and this lever READS rank 0,
--- so including such a row would manufacture its entire domain.  A DEAD row is
--- excluded for the separate GH #794 reason: the shipped file assigns nLV only
--- past X.SkillsComplement's `J.CanNotUseAbility( bot )` return, so a corpse
--- raises rather than answering.  Same split as
--- tests/test_wk_save_mana_lock_census.lua section 1.
local function priced_corpus()
    local priced, absent = {}, {}
    for _, path in ipairs(frame_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == UNIT and u.alive ~= false then
                    if type(u.abilities) == 'table' then
                        priced[#priced + 1] = path
                    else
                        absent[#absent + 1] = short(path)
                    end
                    break
                end
            end
        end
    end
    return priced, absent
end

--- One frame through the real loader with `cand` armed (nil = nothing armed).
--- `tweak` runs on the subject's ability handles BEFORE the hero file is
--- loaded, because the hero binds abilityR at file scope and X.SkillsComplement
--- memoises nLV/nMP on that same load.
local function read_frame(path, cand, tweak, nonturbo)
    local J = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return cand ~= nil and id == cand end
    -- ⚠️ BEFORE load_hero, not after.  J.IsModeTurbo memoises into a module
    -- upvalue on its first call and X.SkillsComplement calls it, so an override
    -- installed afterwards is read by nobody and the section passes vacuously.
    if nonturbo then GetGameMode = function() return 1 end end
    local bot = GetBot()
    local hQ, hR = bot:GetAbilityByName(Q), bot:GetAbilityByName(R)
    if tweak then tweak(hQ, hR, bot) end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)   -- primes the file-level nLV/nMP/nHP
    return {
        X = X, J = J, bot = bot, hQ = hQ, hR = hR,
        level = bot:GetLevel(),
        mana = bot:GetMana(),
        max_mana = bot:GetMaxMana(),
        q_cost = hQ:GetManaCost(),
        q_castable = hQ:IsFullyCastable(),
        r_rank = hR:GetLevel(),
        r_cost = hR:GetManaCost(),
        r_cd = hR:GetCooldownTimeRemaining(),
        reserve = X.GetReincarnationReserve(hQ),
        save = X.ShouldSaveMana(hQ),
    }
end

local function spec_of(h)
    local sp = rawget(h, '__spec')
    assert(type(sp) == 'table', 'the loader stopped exposing __spec; every '
        .. 'probe below is a control and would pass vacuously without it')
    return sp
end

--- Move Reincarnation to rank 0 and NOTHING else.  This is the loader's own
--- reading-B world (mana_ladder clamps a rank below 1 to steps[1], so R still
--- prices at 220) applied to a REAL frame's every other operand.
--- ⚠️ Only GetLevel is moved, deliberately: the loader derives IsTrained from
--- it (`GetLevel() > 0`), so a probe that set both could pass while the shipped
--- helper read a field nothing else agreed with.
local function unlearn_R(_, hR) spec_of(hR).GetLevel = 0 end

-- ===========================================================================
-- 1  THE GATE IS WIRED, TURBO-ONLY, AND NAMES EXACTLY ONE ID
-- ===========================================================================

tests['1.1 the helper is turbo-gated and names only its own id'] = function()
    local body = strip_comments(fn_code(SRC_TEXT, HELPER))
    assert(body:find('J.IsModeTurbo()', 1, true),
        HELPER .. ' lost its turbo guard -- a soak candidate must be turbo-only')
    assert(count(body, "IsSoakCandidate( '") == 1,
        HELPER .. ' must hold exactly ONE IsSoakCandidate call, it holds '
        .. count(body, "IsSoakCandidate( '"))
    -- ⚠️ QUOTED literal, not a bare substring match.  `wkrank0` shares no
    -- prefix with a sibling today, but tests/test_axe_cull_blade_mail.lua found
    -- the bare form self-reporting a conjunction on an UNMUTATED tree because
    -- `axecull` is a substring of `axecullbm`.  The quotes are the convention
    -- that makes the match exact; this asserts them.
    assert(body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        HELPER .. ' no longer names ' .. CAND .. ' as a quoted literal')
    -- The pullcad trap: a gate that ALSO names another id is frozen FALSE the
    -- day that id is promoted, and check_armed_wiring.py still calls it WIRED
    -- (it checks that a call site exists, not that the predicate can be true).
    -- The two siblings live in the same function and guard the same reserve, so
    -- they are what a future round is likeliest to reach for here.
    for id in body:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
        assert(id == CAND, HELPER .. ' names a second id ' .. id
            .. ' -- the pullcad trap.  The three reserve levers must stay '
            .. 'independently armable')
    end
end

tests['1.1b the helper asks ownership the way the rest of the tree asks it'] =
function()
    -- `IsTrained()` and not `GetLevel() < 1`.  The two agree on every engine
    -- answer, but only one of them is the convention a source-level sweep for
    -- "who checks ownership before pricing an ability" can find: the huskar and
    -- `axeblink` blocks in mode_retreat_generic both use it, and so does
    -- J.IsWkReincarnationArmed's own `wkreinctr` conjunct -- which is THIS
    -- DEFECT in a second consumer of the same ultimate.  A convention that only
    -- most of its instances follow is the GH #235 shape.
    local body = strip_comments(fn_code(SRC_TEXT, HELPER))
    assert(body:find('abilityR:IsTrained()', 1, true),
        HELPER .. ' no longer asks abilityR:IsTrained().  If it was changed to '
        .. 'a GetLevel comparison on purpose, say why here -- the accessor is '
        .. 'the part a census can see')
    assert(body:find('abilityR', 1, true) and not body:find('abilityW', 1, true),
        HELPER .. ' reads a handle other than abilityR -- the reserve is FOR '
        .. 'Reincarnation')
end

tests['1.2 the release is its OWN statement, not a disjunct on the sibling'] =
function()
    local body = strip_comments(fn_code(SRC_TEXT, 'ShouldSaveMana'))
    assert(count(body, 'X.' .. HELPER .. '()') == 1,
        'expected exactly one X.' .. HELPER .. ' call site inside '
        .. 'X.ShouldSaveMana, got ' .. count(body, 'X.' .. HELPER .. '()'))
    assert(count(SRC_CODE, 'X.' .. HELPER) == 2,
        'expected exactly two X.' .. HELPER .. ' occurrences in the whole file '
        .. '(the definition and the single call site), got '
        .. count(SRC_CODE, 'X.' .. HELPER))
    -- The sibling's own release line must still read exactly as it did.  Folding
    -- this lever in as `A() or B()` would make arming either id release BOTH
    -- frames sets, which is the GH #798 shape (a bundle reading attributable to
    -- neither member).
    assert(body:find('bShipped and X.IsReincarnationReserveIdle()', 1, true),
        "wksaveidle's release statement was rewritten -- the two levers must "
        .. 'stay separate statements')
    assert(body:find('bShipped and X.' .. HELPER .. '()', 1, true),
        'the ' .. CAND .. ' release is not guarded by the already-bound '
        .. 'bShipped -- without it the lever could move false -> true')
    -- The shipped predicate is bound before either release is consulted.  That
    -- ordering is the whole direction argument in section 5.
    local bound = body:find('local bShipped', 1, true)
    local callsite = body:find('X.' .. HELPER, 1, true)
    assert(bound and callsite and bound < callsite,
        'bShipped is no longer bound before the ' .. CAND .. ' release')
end

-- ===========================================================================
-- 2  THE CORPUS.  The stand-in and the thing it stands in for AGREE here.
-- ===========================================================================

local function census()
    local c = { n = 0, lvl6 = {}, rank0 = {}, both = {}, fires = {}, absent = nil }
    local priced, absent = priced_corpus()
    c.absent = absent
    for _, path in ipairs(priced) do
        local f = read_frame(path, nil)
        local name = short(path)
        c.n = c.n + 1
        if f.level >= 6 then c.lvl6[#c.lvl6 + 1] = name end
        if f.r_rank < 1 then c.rank0[#c.rank0 + 1] = name end
        if f.level >= 6 and f.r_rank < 1 then c.both[#c.both + 1] = name end
        if f.save then c.fires[#c.fires + 1] = name end
    end
    return c
end

local CENSUS = census()

tests['2.1 the corpus is the priced one, and the absences are named'] = function()
    assert(CENSUS.n == 48, 'expected 48 priced live Wraith King frames across '
        .. joined(DIRS) .. ', got ' .. CENSUS.n .. '.  If the corpus grew, '
        .. 'RE-DERIVE every count in this section rather than bumping this one: '
        .. 'a new frame at level >= 6 with R at rank 0 is exactly this lever\'s '
        .. 'first domain member and must not arrive silently')
    assert(#CENSUS.absent == 3, 'expected 3 Wraith King rows with no abilities '
        .. 'list (their rank 0 is an ABSENCE, and this lever READS rank 0), got '
        .. #CENSUS.absent .. ': ' .. joined(CENSUS.absent))
end

tests['2.2 the stand-in and the predicate agree on every priced frame'] =
function()
    assert(#CENSUS.lvl6 == 32, 'expected 32 priced frames at hero level >= 6, '
        .. 'got ' .. #CENSUS.lvl6)
    assert(#CENSUS.rank0 == 16, 'expected 16 priced frames with Reincarnation '
        .. 'at rank 0, got ' .. #CENSUS.rank0)
    -- ⭐ THE DOMAIN, and it is zero.  Both sets are large and their
    -- intersection is empty: every rank-0 frame in this corpus sits at hero
    -- level 1-5, where the shipped rule's FIRST conjunct already refuses.
    assert(#CENSUS.both == 0, 'this corpus now holds a frame at hero level >= 6 '
        .. 'with Reincarnation at rank 0: ' .. joined(CENSUS.both)
        .. '.  That is this lever\'s domain arriving -- pin it as a decision '
        .. 'frame here instead of deleting this assertion')
end

tests['2.3 the zero is a corpus fact, and the complement is NOT empty'] =
function()
    -- Without this the section reads as "nothing to see".  The two sets it
    -- intersects are both large, so the empty intersection is a statement about
    -- THIS corpus's composition rather than about Wraith King -- which is the
    -- distinction the file's ⚠️ block promises and the reason the archive's 42
    -- frames are not contradicted by it.
    assert(#CENSUS.lvl6 > 0 and #CENSUS.rank0 > 0,
        'one of the two sets is empty, so 2.2 is vacuous rather than a reading')
    -- ⚠️ SEVEN, and the sibling file says SIX about the same predicate.  Both
    -- are right: tests/test_wk_save_mana_unreachable_cap.lua section 2 splits
    -- `tests/fixtures` ONLY, and the seventh firing frame --
    -- f_260909_215227_zeus_jump_283 -- lives in `tests/frames`.  This was found
    -- by writing 6 here off that file and watching it go red, which is the
    -- reason the count is asserted rather than carried: a number measured on
    -- one corpus split is not a number about this one, and `tests/frames` is
    -- where this tree's recent frames land.
    assert(#CENSUS.fires == 7, 'expected the shipped reserve to fire on 7 '
        .. 'priced frames across ' .. joined(DIRS) .. ', got ' .. #CENSUS.fires
        .. ': ' .. joined(CENSUS.fires))
end

-- ===========================================================================
-- 3  ⭐ THE BLINDNESS, MEASURED RATHER THAN ARGUED
-- ===========================================================================

tests['3.1 moving R rank 1 -> 0 moves the shipped answer on 0 of 7'] = function()
    local moved, checked = {}, 0
    for _, path in ipairs((priced_corpus())) do
        local base = read_frame(path, nil)
        if base.save then
            local blind = read_frame(path, nil, unlearn_R)
            checked = checked + 1
            assert(blind.r_rank == 0, 'the rank probe did not take on '
                .. short(path) .. ' -- it read rank ' .. tostring(blind.r_rank))
            if blind.save ~= base.save then moved[#moved + 1] = short(path) end
        end
    end
    assert(checked == #CENSUS.fires, 'expected ' .. #CENSUS.fires
        .. ' firing frames to probe, probed ' .. checked)
    -- ⭐ The rule is ABOUT Reincarnation and cannot be moved by Reincarnation's
    -- rank.  That is the defect stated as a measurement.
    assert(#moved == 0, 'the shipped X.ShouldSaveMana now reacts to R\'s rank on '
        .. joined(moved) .. ' -- if the shipped rule grew a rank term this lever '
        .. 'is redundant and should be withdrawn, not re-baselined')
end

tests['3.2 armed, the lever releases every one of those 7'] = function()
    local released, checked = {}, 0
    for _, path in ipairs((priced_corpus())) do
        local base = read_frame(path, nil)
        if base.save then
            checked = checked + 1
            local armed = read_frame(path, CAND, unlearn_R)
            if not armed.save then released[#released + 1] = short(path) end
        end
    end
    assert(checked == #CENSUS.fires, 'expected ' .. #CENSUS.fires
        .. ' firing frames, probed ' .. checked)
    assert(#released == #CENSUS.fires, 'armed on a rank-0 probe the lever '
        .. 'released ' .. #released .. ' of ' .. #CENSUS.fires
        .. ' frames, expected all of them: ' .. joined(released))
end

tests['3.3 ⚠️ the 6 are PROBES, and the lever is inert on the real frames'] =
function()
    -- Said out loud so 3.1/3.2 can never be quoted as a domain.  On the frames
    -- AS THEY WERE RECORDED -- R at rank >= 1 -- arming changes nothing at all.
    local moved = {}
    for _, path in ipairs((priced_corpus())) do
        local base = read_frame(path, nil)
        local armed = read_frame(path, CAND)
        if armed.save ~= base.save then moved[#moved + 1] = short(path) end
        assert(armed.reserve == base.reserve, 'the lever moved the RESERVE on '
            .. short(path) .. ' -- it must not touch X.GetReincarnationReserve')
    end
    assert(#moved == 0, 'armed, the lever changed the answer on real recorded '
        .. 'frames: ' .. joined(moved) .. '.  Section 2.2 says its domain here '
        .. 'is empty; both cannot be true')
end

-- ===========================================================================
-- 4  ⭐ THE UNDECIDED ENGINE READING, BOTH BRANCHES DRIVEN
-- ===========================================================================

tests['4.1 both call sites put IsFullyCastable ahead of X.ShouldSaveMana'] =
function()
    -- The premise of branch A below, taken off the source rather than from
    -- memory.  If a future edit reorders either `or` chain, the entailment
    -- "ShouldSaveMana was entered => mana >= cost" is gone and 4.2 is arguing
    -- about a world that no longer exists.
    for _, fn in ipairs({ 'ConsiderQ', 'ConsiderW' }) do
        local body = strip_comments(fn_code(SRC_TEXT, fn))
        local castable = body:find(':IsFullyCastable()', 1, true)
        local save = body:find('X.ShouldSaveMana(', 1, true)
        assert(castable and save, 'X.' .. fn .. ' no longer holds both an '
            .. 'IsFullyCastable() test and an X.ShouldSaveMana call')
        assert(castable < save, 'X.' .. fn .. ' now calls X.ShouldSaveMana '
            .. 'BEFORE testing IsFullyCastable -- branch A of this lever\'s '
            .. 'correctness argument rests on that ordering')
    end
end

tests['4.2 branch A: priced at 0, the shipped clause cannot fire at all'] =
function()
    -- Driven on real operands, not on a constructed triple.  Two halves:
    -- (a) the entailment holds on every real frame where Q is castable, and
    -- (b) with R priced at 0 the reserve is 0 and the shipped rule is silent.
    local castable, silent = 0, 0
    for _, path in ipairs((priced_corpus())) do
        local zero = read_frame(path, nil, function(_, hR)
            spec_of(hR).GetManaCost = function() return 0 end
        end)
        if zero.q_castable then
            castable = castable + 1
            assert(zero.mana - zero.q_cost >= 0, 'a fully castable Q on '
                .. short(path) .. ' costs more than the hero holds ('
                .. zero.mana .. ' - ' .. zero.q_cost .. ') -- the entailment '
                .. 'branch A rests on is false on a real frame')
            assert(zero.reserve == 0, 'R priced at 0 but the reserve read '
                .. tostring(zero.reserve) .. ' on ' .. short(path))
            assert(zero.save == false, 'the shipped reserve FIRED on '
                .. short(path) .. ' with R priced at 0 -- branch A is wrong and '
                .. 'this lever would not be a no-op under that engine reading')
            silent = silent + 1
        end
    end
    assert(castable > 0, 'no frame in the corpus has a castable Q, so this '
        .. 'section is vacuous rather than a reading')
    assert(silent == castable, 'expected all ' .. castable .. ' castable-Q '
        .. 'frames to be silent under branch A, got ' .. silent)
end

tests['4.3 branch B: priced at the rank-1 price, the reserve is held for a '
    .. 'rank-0 ability'] = function()
    -- This loader IS branch B (mana_ladder clamps a rank below 1 to steps[1]),
    -- so the probe reads the branch directly.  What the assertion is about is
    -- that under it the held amount is R's FULL rank-1 price while R is rank 0.
    local seen = 0
    for _, path in ipairs((priced_corpus())) do
        local base = read_frame(path, nil)
        if base.save then
            local blind = read_frame(path, nil, unlearn_R)
            assert(blind.r_rank == 0, 'the rank probe did not take')
            assert(blind.r_cost > 0, 'under branch B an unlearned R must still '
                .. 'be priced above 0, read ' .. tostring(blind.r_cost))
            assert(blind.reserve == blind.r_cost, 'the reserve held on '
                .. short(path) .. ' is ' .. tostring(blind.reserve)
                .. ', not R\'s price ' .. tostring(blind.r_cost))
            assert(blind.mana - blind.q_cost < blind.reserve, 'the shipped '
                .. 'clause is not the thing refusing on ' .. short(path))
            seen = seen + 1
        end
    end
    assert(seen == #CENSUS.fires, 'expected ' .. #CENSUS.fires
        .. ' branch-B probes, ran ' .. seen)
end

tests['4.4 the two branches are the SAME lever, and it never adds a refusal'] =
function()
    -- The disjunction is only bounded out if the armed answer is acceptable
    -- under BOTH branches.  Under A the lever is a no-op (nothing fired to
    -- release); under B it releases.  Neither ever turns a permitted cast into
    -- a refused one -- which is what makes "we cannot buy the reading" survivable.
    for _, path in ipairs((priced_corpus())) do
        for _, probe in ipairs({
            { tag = 'A', tweak = function(_, hR)
                spec_of(hR).GetLevel = 0
                spec_of(hR).GetManaCost = function() return 0 end
            end },
            { tag = 'B', tweak = unlearn_R },
        }) do
            local base = read_frame(path, nil, probe.tweak)
            local armed = read_frame(path, CAND, probe.tweak)
            assert(not (armed.save and not base.save), 'branch ' .. probe.tag
                .. ': arming ' .. CAND .. ' REFUSED a cast the shipped code '
                .. 'permitted on ' .. short(path) .. ' -- this lever is release-'
                .. 'only by shape and that shape is broken')
        end
    end
end

-- ===========================================================================
-- 5  DIRECTION, AND A RELEASED RESERVE IS NOT A CAST
-- ===========================================================================

tests['5.1 direction holds on every priced frame, armed or not'] = function()
    for _, path in ipairs((priced_corpus())) do
        local base = read_frame(path, nil)
        local armed = read_frame(path, CAND)
        assert(not (armed.save and not base.save),
            'arming ' .. CAND .. ' refused a cast the shipped code permitted on '
            .. short(path))
    end
end

tests['5.2 a released reserve is not a cast -- with the control'] = function()
    -- The headline probe: a real level-7 frame with R moved to rank 0.  Armed,
    -- X.ShouldSaveMana stops refusing -- and X.ConsiderQ STILL answers 0, for
    -- reasons downstream of this lever.  Without the control below, "both legs
    -- answer 0" and "the body never ran" look identical, which is the reading
    -- tests/test_wk_save_mana_lock_census.lua section 3 was built to separate.
    local path = 'tests/fixtures/f_114311_drow_pushguard_silent.lua'
    local reads = 0
    local function probe(hQ, hR)
        spec_of(hR).GetLevel = 0
        spec_of(hQ).GetCastRange = function(self)
            reads = reads + 1
            return Q_CAST_RANGE
        end
    end

    reads = 0
    local base = read_frame(path, nil, probe)
    assert(base.level >= 6, 'the control frame is no longer at hero level >= 6')
    assert(base.save == true, 'the shipped reserve no longer refuses on the '
        .. 'control frame, so 5.2 has nothing to release')
    local shipped_reads = reads
    local shipped_desire = base.X.ConsiderQ()

    reads = 0
    local armed = read_frame(path, CAND, probe)
    assert(armed.save == false, 'armed, the lever did not release the control frame')
    local armed_reads = reads
    local armed_desire = armed.X.ConsiderQ()

    assert(shipped_desire == 0 and armed_desire == 0,
        'X.ConsiderQ answered non-zero (' .. tostring(shipped_desire) .. '/'
        .. tostring(armed_desire) .. ') -- the ⚠️ block above says this lever '
        .. 'releases a PERMISSION and not a cast; update it before this passes')
    -- The control.  The shipped leg short-circuits on line 1 and never reads
    -- Q's cast range; the armed leg gets past it and does.
    assert(shipped_reads == 0, 'the shipped leg read Q\'s cast range '
        .. shipped_reads .. ' times -- it should have short-circuited on '
        .. 'X.ShouldSaveMana before reaching the body')
    assert(armed_reads >= 1, 'the armed leg never read Q\'s cast range, so the '
        .. 'body did not run and both zeros above mean nothing')
end

-- ===========================================================================
-- 6  INERT UNARMED / OUTSIDE TURBO / INDEPENDENT OF BOTH SIBLINGS
-- ===========================================================================

tests['6.1 unarmed and non-turbo are both byte-for-byte shipped'] = function()
    -- ⚠️ THE CONTROL FRAME IS DERIVED, NOT PICKED.  The first draft used
    -- f_114311_drow_pushguard_silent and the section went red on its own last
    -- assertion, because `wksaveidle` already releases that frame -- so "a
    -- sibling released it" would have been true with this lever deleted.  What
    -- the section is about is that arming a sibling does not release THIS
    -- lever's frames, so the frame has to be one no sibling reaches.
    local sole = {}
    for _, path in ipairs((priced_corpus())) do
        local base = read_frame(path, nil, unlearn_R)
        if base.save then
            local idle = read_frame(path, SIB_IDLE, unlearn_R)
            local cap = read_frame(path, SIB_CAP, unlearn_R)
            if idle.save and cap.save then sole[#sole + 1] = path end
        end
    end
    assert(#sole > 0, 'every firing frame in the corpus is released by a '
        .. 'sibling gate, so this section has no control frame and would pass '
        .. 'vacuously')
    for _, path in ipairs(sole) do
        local base = read_frame(path, nil, unlearn_R)
        local armed = read_frame(path, CAND, unlearn_R)
        local nonturbo = read_frame(path, CAND, unlearn_R, true)
        assert(base.save == true, short(path) .. ' no longer fires the shipped '
            .. 'reserve')
        assert(armed.save == false, CAND .. ' did not release ' .. short(path)
            .. ', so the frame is not this lever\'s to begin with')
        assert(nonturbo.save == true, CAND .. ' fired OUTSIDE turbo on '
            .. short(path) .. ' -- every soak candidate in this tree is turbo-only')
    end
end

tests['6.2 the three reserve gates are mutually unmentioned'] = function()
    -- Source-level, over all three helpers: no gate may name another's id, or
    -- promoting that other id freezes this one FALSE forever while
    -- check_armed_wiring.py still calls it WIRED.
    local trio = {
        [HELPER] = CAND,
        GetReincarnationReserve = SIB_CAP,
        IsReincarnationReserveIdle = SIB_IDLE,
    }
    for fn, own in pairs(trio) do
        local body = strip_comments(fn_code(SRC_TEXT, fn))
        for id in body:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
            assert(id == own or fn == 'IsReincarnationReserveIdle',
                'X.' .. fn .. ' names ' .. id .. ' but owns ' .. own)
        end
        assert(body:find("'" .. own .. "'", 1, true),
            'X.' .. fn .. ' no longer names its own id ' .. own)
    end
    -- ⚠️ IsReincarnationReserveIdle is exempted above BY NAME rather than by a
    -- loosened pattern: it legitimately consults `wkidleshare`, which is a pure
    -- NARROWING of its own gate documented in the file.  Assert that the
    -- exemption covers exactly that one id and nothing else.
    local idle = strip_comments(fn_code(SRC_TEXT, 'IsReincarnationReserveIdle'))
    for id in idle:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
        assert(id == SIB_IDLE or id == 'wkidleshare',
            'IsReincarnationReserveIdle now names ' .. id
            .. ', which the documented wkidleshare exemption does not cover')
    end
    assert(not idle:find("'" .. CAND .. "'", 1, true),
        'IsReincarnationReserveIdle now names ' .. CAND)
end

return tests
