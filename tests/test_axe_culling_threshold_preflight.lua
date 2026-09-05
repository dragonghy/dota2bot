-- [hero] Pre-flight for the registered Axe lever at hero_axe.lua X.ConsiderR
-- (GH #115 section 5; handed to this round by the 2026-08-22T15:47Z wkqaim report).
--
-- WHAT IS PROPOSED
-- ----------------
-- X.ConsiderR estimates its own finisher with a hardcoded constant:
--
--     local nKillDamage = 150 + 100 * nSkillLV        -- 250 / 350 / 450
--
-- and casts Culling Blade when a target's effective health falls BELOW it.  Culling
-- Blade's damage on the live datafeed (hero_id 2, read 2026-08-22) is 275/375/475.
-- The constant is therefore 25 pure damage LOW at every level, and the bot declines
-- a Culling that would in fact kill whenever the target sits in the 25-point band
-- [150 + 100*lv, damage[lv]).  The honest fix is to stop hardcoding it:
-- abilityR:GetSpecialValueInt('damage') -- an API this very function already uses
-- one line below, on talent8.
--
-- VERDICT THIS ROUND: NOT WRITTEN -- AND THE REASON IS NEW
-- -------------------------------------------------------
-- The five pre-flights before this one (wkreincarnmp, axeblink, cmrself, zusultx,
-- esaftershock, liondrain, wkqaim) all died because their domain was EMPTY or
-- vanishing, and in every case the emptiness had a STRUCTURAL cause that a desk
-- check could name.  None of those causes applies here, and section 3 pins that:
--
--   * No upstream sibling.  X.ConsiderR has exactly ONE firing branch in the whole
--     function.  There is nothing above it that would already have taken these
--     frames (the wkqaim / liondrain shape), and nothing that routes the action
--     around the change (the zusultx shape).
--   * No stronger guard already doing the job (the wkreincarnmp shape): the change
--     WIDENS the only test there is.
--   * Carrier is available: Axe is a focus hero and is in the soak pool (the
--     CARRIER-UNAVAILABLE shape that killed the Tiny lever).
--
-- What stops it instead is MEASUREMENT POWER, which is a different thing and must
-- not be recorded as an empty domain:
--
--     The band is 25 points wide.  Measured over this repo's fixture library: 26
--     frames carry an Axe, all 26 alive, 20 have Culling ready (blocked: 4 unlearned,
--     1 cooldown, 1 mana), and on 3 of those 20 an enemy hero is inside the effective
--     375u ring.  The band is occupied in the ring ZERO times.
--
--     That zero decides nothing.  Three in-ring enemy-frames against a 25-point
--     window on a health pool of order 1000 gives an expected count near 0.08 even if
--     the defect is completely real -- you would need roughly 40 in-ring frames to
--     expect a single hit, and several hundred for an estimate worth quoting.  The
--     fixture library is about two orders of magnitude too small to answer this
--     question, and no amount of care in reading it changes that.
--
-- So this file records UNDERPOWERED, not EMPTY.  Proposed disposition name:
-- NARROW-BAND-UNMEASURABLE.  The reusable form, for the stream's Y.2 list:
--
--     A lever whose domain is a narrow BAND on a continuous quantity (health, mana,
--     distance) cannot be sized from a frame corpus at all -- frame counts estimate
--     how often a continuous variable lands in a small interval, which needs orders
--     more samples than an existence question does.  Size it on the EVENT side
--     (casts that did/didn't happen), or not at all.
--
-- >>> HALF OF THAT RULE WAS RETRACTED ON 2026-08-30 -- READ BEFORE QUOTING IT.
-- tests/test_axe_culling_band_power.lua (hero stream; state.json
-- hero2_BANDPOWER_20260830) reproduces the "roughly 40 frames" figure from this
-- repo's own corpus (median in-ring pool 1131 -> 45.2 frames, so the arithmetic
-- above is right) and then shows it prices the wrong population.  band /
-- health_pool is the POOL model: it asks how often a UNIFORMLY DRAWN frame lands
-- in the window.  An enemy never occupies the band uniformly -- it ENTERS from
-- above on the way down, so a crossing is caught with p = min(1, band/(v*dt)),
-- which contains no health pool term.  Priced off `observed.burst` (real damage
-- dealt, 58 fixtures, median 58.3 HP/s): 2.3 crossings per hit at the median and
-- 14.4 at the fastest burst the corpus has recorded -- 19.4x and 3.1x better than
-- the random-frame population.  So a narrow band CAN be sized from 1 Hz timelines
-- by counting CROSSINGS; what cannot size it is a FIXTURE LIBRARY, which holds
-- isolated instants and by construction contains no crossings at all.  This file's
-- own verdict (UNDERPOWERED, lever not written) is unaffected -- the corpus scan
-- below still comes back zero -- but the Y.2 rule as phrased above is too strong.
--
-- THE ARGUMENT THAT DOES NOT DEPEND ON THE DOMAIN
-- -----------------------------------------------
-- Worth recording because it is the strongest (c)-condition case here and it
-- survives whatever the corpus scan comes back with: the staleness is BIDIRECTIONAL.
-- Today 150 + 100*lv sits 25 BELOW the real damage, and the cost is a declined kill.
-- The constant matched Culling's damage when it was written; the next rebalance that
-- moves damage the other way makes it sit ABOVE, and then the bot spends an 80-second
-- ultimate on a target it does NOT kill -- strictly worse than today's failure, and
-- silent.  Reading the value off the ability removes both directions permanently.
-- That is a correctness argument about the SOURCE, not a behaviour claim about a
-- band, which is why it is recorded here rather than shipped as a gate this round.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * The fixture library is a CURATED set cut for other investigations, not a
--     random sample of turbo play.  26 of its 100 frames carry an Axe, and several
--     are near-duplicate instants from the same game (three from 043124, three from
--     183613), so the effective independent sample is smaller still.  Nothing here is
--     a density estimate.  This is the stream's Y.2 limit in local form -- a desk or
--     fixture read can show EMPTY, never RARE -- with the extra twist that for a
--     narrow band it cannot honestly show EMPTY either.
--   * All 20 ready frames are at Culling rank 1, so only the [250,275) band is
--     exercised.  The library is skewed early-game; ranks 2 and 3 are untested here.
--   * The first pass at this scan was a Python regex reader and it under-counted the
--     Axe frames 10 to 26, which would have turned a reachable ring into an empty
--     one and produced exactly the confident wrong answer this stream keeps warning
--     about.  The numbers above come from `dofile` on each fixture -- the same loader
--     the tests use.  Do not re-derive corpus counts by pattern-matching the files.
--   * The rings below ignore vision.  The engine's list is vision-limited; counting
--     every living enemy makes each ring an UPPER bound, so "no frame reaches the
--     branch" is measured against a ring at least as large as the bot's.  The
--     approximation runs in the safe direction.
--   * Health regen is not in the fixtures.  The shipped test is
--     hp + regen*0.8 < nKillDamage, so the true effective health is slightly HIGHER
--     than the hp used here -- which can only move a target further above the
--     threshold, again the safe direction for a "nothing reaches it" claim.
--   * Damage/mana/cast-range anchors (275/375/475; 100/125/150; 175) are RECORDED
--     from https://www.dota2.com/datafeed/herodata?language=english&hero_id=2, read
--     2026-08-22.  This test cannot reach the network.
--
-- WHAT THIS FILE IS FOR, GOING FORWARD
-- ------------------------------------
-- Sections 1 and 3 are RATCHETS on the source: the day the constant is fixed, or a
-- second firing branch is added to ConsiderR, they go red and say so in as many
-- words, so nobody "repairs the regression" without reading this. Section 2 is a
-- TRIPWIRE, not a census equality (GH #106 filed corpus-size-as-equation as its own
-- hazard): it asserts a universal, so adding fixtures can only strengthen it, and
-- the day a fixture does reach the band it turns red and NAMES the frame -- which is
-- exactly the real frame this lever would need in order to be written.

package.path = 'tests/?.lua;' .. package.path

local T = {}

local SRC = 'bots/BotLib/hero_axe.lua'
local AXE = 'npc_dota_hero_axe'
local CULLING = 'axe_culling_blade'

-- Recorded 2026-08-22 from the live datafeed (hero_id 2).  See HONEST BOUNDS.
local R_DAMAGE = { 275, 375, 475 }
local R_MANA = { 100, 125, 150 }
local R_CAST_RANGE = 175
-- The branch actually iterates J.GetAroundEnemyHeroList( nCastRange + 200 ).
-- NOTE the bare nCastRange list is computed on the line above and then never read;
-- section 3 pins that, because it means the EFFECTIVE ring is 375, not 175, and the
-- lever's pre-registered domain text ("target is inside 175") understates it.
local RING = R_CAST_RANGE + 200

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^.+%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function ability(unit, name)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == name then return a end
    end
    return nil
end

-- The body of X.ConsiderR, so the source ratchets below cannot be fooled by a
-- matching string somewhere else in the file.
local function consider_r_body(src)
    local from = src:find('function X%.ConsiderR%s*%(%s*%)')
    assert(from, 'X.ConsiderR not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

-- One row per (fixture, living Axe) where Culling Blade is genuinely castable:
-- learned, off cooldown, and affordable.  That reproduces the guard ConsiderR runs
-- before anything else (abilityR:IsFullyCastable()).
local function scan()
    local rows, axe_frames, alive_frames = {}, 0, 0
    local blocked = { unlearned = 0, cooldown = 0, mana = 0 }
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, me in ipairs(fx.units) do
                if me.name == AXE then
                    axe_frames = axe_frames + 1
                    if me.alive then
                        alive_frames = alive_frames + 1
                        local r = ability(me, CULLING)
                        local lv = (r and r.level) or 0
                        if lv < 1 then
                            blocked.unlearned = blocked.unlearned + 1
                        elseif (r.cd or 0) > 0 then
                            blocked.cooldown = blocked.cooldown + 1
                        elseif (me.mp or 0) < R_MANA[math.min(lv, 3)] then
                            blocked.mana = blocked.mana + 1
                        else
                            local stale = 150 + 100 * lv
                            local live = R_DAMAGE[math.min(lv, 3)]
                            local ring, band_in_ring, band_anywhere, nearest = {}, {}, {}, nil
                            for _, u in ipairs(fx.units) do
                                if u.name:match('^npc_dota_hero_') and u.team ~= me.team and u.alive then
                                    local d = dist(u, me)
                                    if nearest == nil or d < nearest then nearest = d end
                                    if u.hp >= stale and u.hp < live then
                                        band_anywhere[#band_anywhere + 1] = { unit = u, d = d }
                                    end
                                    if d <= RING then
                                        ring[#ring + 1] = { unit = u, d = d }
                                        if u.hp >= stale and u.hp < live then
                                            band_in_ring[#band_in_ring + 1] = { unit = u, d = d }
                                        end
                                    end
                                end
                            end
                            rows[#rows + 1] = {
                                path = path, t = fx.time, lv = lv, stale = stale, live = live,
                                ring = ring, band_in_ring = band_in_ring,
                                band_anywhere = band_anywhere, nearest = nearest,
                            }
                        end
                    end
                end
            end
        end
    end
    return rows, axe_frames, alive_frames, blocked
end

-- ---------------------------------------------------------------- section 1 --
-- The arithmetic.  A ratchet on the source: it states what the shipped constant is
-- and what it is worth, so a fix cannot land silently.

-- ============================================================================
-- THE RATCHET FIRED, 2026-09-05.  hero-2 LANDED -- gated, as `cullthresh`.
-- ============================================================================
-- This section used to assert that `local nKillDamage = 150 + 100 * nSkillLV` was
-- still standing in X.ConsiderR, and its failure text told whoever tripped it to
-- "delete sections 1 and 2 of this file ... and note that the domain was never
-- sized ... this change ships on the source-correctness argument in the header,
-- not on a measured frame."
--
-- HALF of that instruction is taken and half is DELIBERATELY NOT, and the
-- difference is the one thing the instruction could not have known: the fix landed
-- BEHIND A GATE (bots/BotLib/hero_axe.lua X.CullKillThreshold /
-- J.IsSoakCandidate('cullthresh'), turbo-only, unarmed), not ungated on the
-- source-correctness argument.
--
--   * Section 1 is RE-AIMED, not deleted.  The invariant it protected -- "a fix
--     cannot land silently" -- is still wanted, because the gate-off path must keep
--     reproducing the stale constant byte for byte or "inert when unarmed" stops
--     being checkable by reading.  Deleting it would retire the guard on the
--     shipped half at the exact moment there are two halves to tell apart.
--   * Section 2 is KEPT VERBATIM.  Its tripwire names the frame the day the band is
--     occupied, and a gated lever still needs that frame -- more than an ungated one
--     would, because the gate exists precisely because the domain is unsized.
--   * The header's UNDERPOWERED verdict STANDS for a fixture library.  What expired
--     is the OTHER half, and it expired on a supply fact rather than on an argument:
--     tests/test_axe_culling_band_power.lua (2026-08-30) showed 1 Hz timelines size
--     this by counting CROSSINGS, and the reason nobody could count them -- Axe in
--     0 of 306 archived games, batch desk 2026-08-23 -- is falsified by
--     tests/fixtures/tl_260905_010226_axe_outchan.json (seed 4763, an archived
--     timeline whose subject is an Axe).
--
-- Landing record: iterations/reports/hero/ 2026-09-05, and the new file
-- tests/test_axe_cull_threshold_gate.lua, which owns the behaviour of the armed
-- path.  This file keeps owning the DOMAIN question.
T['section 1: the gate-off path still reproduces the stale hardcode'] = function()
    local src = read_file(SRC)
    local at = src:find('function X%.CullKillThreshold%s*%(')
    assert(at, [[
X.CullKillThreshold is gone from bots/BotLib/hero_axe.lua.

That helper is where hero-2 put the threshold: the ability read behind the
`cullthresh` gate, and the stale `150 + 100 * nSkillLV` as the gate-off value.  If
it has been removed, find out which of the two survived before touching this file --
a tree where the armed value became unconditional is a PROMOTE and must be recorded
as one, and a tree where the constant came back inline is a revert.]])
    local body = src:sub(at)
    body = body:sub(1, body:find('\nfunction X%.') or #body)
    assert(body:find('local nKillDamage = 150 %+ 100 %* nSkillLV'), [[
The gate-off path no longer computes nKillDamage as `150 + 100 * nSkillLV`.

While `cullthresh` is unarmed the shipped tree must behave exactly as it did before
hero-2 landed.  If the constant is gone, the change is no longer inert in real games
and is no longer a soak candidate -- promote it deliberately and record it, do not
let it happen by edit.]])

    local rbody = consider_r_body(src)
    assert(rbody:find('X%.CullKillThreshold%( nSkillLV %)'), [[
X.ConsiderR no longer routes its threshold through X.CullKillThreshold, so the gate
is bypassed.  Section 2's domain reading below is taken against the gate-off value;
if ConsiderR reads something else, this whole file is measuring a band nothing acts on.]])
end

T['section 1: the constant under-states Culling Blade by exactly 25 at every level'] = function()
    for lv = 1, 3 do
        local stale = 150 + 100 * lv
        assert(R_DAMAGE[lv] - stale == 25, string.format(
            'rank %d: recorded damage %d vs constant %d is a gap of %d, not the 25 this '
            .. 'pre-flight measured.  The datafeed anchor changed -- re-read it and re-size '
            .. 'the band, because the band width IS the lever',
            lv, R_DAMAGE[lv], stale, R_DAMAGE[lv] - stale))
    end
end

-- RE-AIMED with the case above.  This used to check that GetSpecialValueInt was
-- already in use inside X.ConsiderR -- the evidence that the recommended fix was
-- de-risked.  The fix is now WRITTEN, so the claim it supported is spent; what is
-- worth keeping is the assertion that the recommended read is the one that landed,
-- on the ability handle and on the `damage` key, rather than a re-hardcode of
-- today's numbers under a gate.
T['section 1: the fix that landed is the READ this pre-flight recommended'] = function()
    local src = read_file(SRC)
    local at = assert(src:find('function X%.CullKillThreshold%s*%('),
        'X.CullKillThreshold not found -- see the case above')
    local body = src:sub(at)
    body = body:sub(1, body:find('\nfunction X%.') or #body)
    assert(body:find("abilityR:GetSpecialValueInt%( 'damage' %)"), [[
The armed path no longer reads abilityR:GetSpecialValueInt('damage').

That read IS the fix: it is what makes the threshold survive a patch that moves the
ladder, and it is what folds the +150 talent the shipped arithmetic can never see.
A gate that instead hardcodes 275/375/475 buys the 25 points once and re-acquires
the staleness the moment Valve edits the KV -- which is the defect, not the fix.]])
    assert(not body:find('275') and not body:find('475'), [[
The armed path names today's KV numbers literally.  Read them off the ability; a
constant behind a gate is still a constant.]])
end

-- ---------------------------------------------------------------- section 2 --
-- The domain, on real frames.  A TRIPWIRE asserting a universal, so more fixtures
-- can only strengthen it.  Read the header's UNDERPOWERED note before quoting this:
-- a zero on a 25-point band is not evidence the band is empty.

-- NOTE on the idiom below: these use `if not cond then error(...) end`, never
-- `assert(cond, string.format(...))`.  Lua evaluates BOTH arguments of assert before
-- calling it, so a message that indexes the very row the condition proves absent
-- blows up on the PASSING path.  The first draft of this file did exactly that and
-- reported three failures that were all message-construction errors.
T['section 2: the 25-point band is never occupied inside the ring -- THIS is the domain'] = function()
    local rows = scan()
    for _, r in ipairs(rows) do
        if #r.band_in_ring > 0 then
            local h = r.band_in_ring[1]
            error(string.format(
                'DOMAIN REACHED: %s t=%.1f -- %s at %.0f hp, %.0fu away, sits in the band [%d, %d) '
                .. 'with Culling rank %d ready.  The pre-flight recorded ZERO such frames across 20 '
                .. 'ready frames.  This is the frame the lever needs: cut it with make_fixture.py, '
                .. 'and the change can finally be written against a real decision instant instead '
                .. 'of an unmeasurable band',
                r.path, r.t or -1, h.unit.name, h.unit.hp, h.d, r.stale, r.live, r.lv))
        end
    end
end

T['section 2: the tripwire above is NOT vacuous -- the ring is genuinely reached'] = function()
    -- The failure mode that would quietly make this whole pre-flight worthless: a
    -- universal over an empty set is true for the wrong reason.  The ring IS reached
    -- on 3 of 20 ready frames, so "the band is never occupied in the ring" is a claim
    -- about health, not a claim about Axe never standing near anyone.
    local rows, axe_frames, alive_frames, blocked = scan()
    local ring_frames = 0
    for _, r in ipairs(rows) do
        if #r.ring > 0 then ring_frames = ring_frames + 1 end
    end
    if axe_frames < 26 then
        error(string.format(
            'only %d fixture frames carry an Axe; the pre-flight scanned 26.  Fixtures were '
            .. 'removed, or the loader changed', axe_frames))
    end
    if #rows < 20 then
        error(string.format(
            'only %d Culling-ready frames (pre-flight found 20, from %d living Axe frames; blocked: '
            .. '%d unlearned / %d cooldown / %d mana)', #rows, alive_frames,
            blocked.unlearned, blocked.cooldown, blocked.mana))
    end
    if ring_frames < 3 then
        error(string.format(
            'only %d ready frames have an enemy inside %du (pre-flight found 3).  Below this the '
            .. 'band tripwire is near-vacuous -- it would pass because Axe is never near anyone, '
            .. 'not because the band is empty.  Do not quote it', ring_frames, RING))
    end
end

T['section 2: the firing branch is demonstrably LIVE in this corpus'] = function()
    -- The single most important difference from the wkqaim pre-flight, which died
    -- because its branch was never reached at all.  Here at least one ready frame has
    -- an enemy inside the ring whose health is BELOW even the stale threshold -- i.e.
    -- the shipped code casts on it.  The execute branch works; what is unmeasurable is
    -- only the 25-point strip above the threshold that the stale constant gives away.
    local rows = scan()
    local firing = nil
    for _, r in ipairs(rows) do
        for _, e in ipairs(r.ring) do
            if e.unit.hp < r.stale then firing = { r = r, e = e } end
        end
    end
    if firing == nil then
        error('no ready frame in the library has an in-ring enemy below the stale kill threshold. '
            .. 'The pre-flight found one (f_260820_043637_axe_ring_close.lua t=393.4, skywrath_mage '
            .. 'at 221 hp / 188u against a 250 threshold) and leaned on it to argue the branch is '
            .. 'live rather than dead.  Without it this pre-flight is the wkqaim shape after all, '
            .. 'and the reasoning must be redone')
    end
end

-- ---------------------------------------------------------------- section 3 --
-- The structural pins: why the five earlier collapse modes do NOT apply, and why the
-- effective ring is 375 rather than the pre-registered 175.  These are ratchets --
-- if the shape of ConsiderR changes, the pre-flight's reasoning must be re-read.

T['section 3: X.ConsiderR has exactly ONE firing branch'] = function()
    -- Counted, never compared by position.  The wkqaim round learned this the hard
    -- way: "the cast sits after the guard" is satisfied by ANY branch appended
    -- below it, which is precisely the change such an assertion exists to catch.
    local body = consider_r_body(read_file(SRC))
    local n = 0
    for _ in body:gmatch('return BOT_ACTION_DESIRE_HIGH') do n = n + 1 end
    assert(n == 1, string.format(
        'X.ConsiderR now has %d firing branches, not 1.  The pre-flight ruled out the '
        .. 'UPSTREAM-SIBLING collapse (wkqaim/liondrain) and the CONSUMER-SIDE-UNREACHABLE '
        .. 'collapse (zusultx) on the grounds that there is nothing else in this function '
        .. 'that could take the frames or route around the change.  With a second branch '
        .. 'that reasoning has to be redone', n))
end

T['section 3: the firing branch iterates the +200 list, so the effective ring is 375'] = function()
    local body = consider_r_body(read_file(SRC))
    assert(body:find('nInBonusEnemyList = J%.GetAroundEnemyHeroList%( nCastRange %+ 200 %)'),
        'the bonus list is no longer nCastRange + 200; RING above is wrong')
    assert(body:find('for _, npcEnemy in pairs%( nInBonusEnemyList %)'),
        'the firing loop no longer iterates nInBonusEnemyList; re-check the effective ring')
    -- The bare cast-range list is computed and never read.  That is what makes the
    -- effective ring 375 and not 175, and it means the branch returns DESIRE_HIGH on
    -- targets up to 200u out of cast range -- registered here, not fixed: it is a
    -- separate lever with its own domain and its own cost side.
    local reads = 0
    for _ in body:gmatch('nInRangeEnemyList') do reads = reads + 1 end
    assert(reads == 1, string.format(
        'nInRangeEnemyList now appears %d times in X.ConsiderR (was 1: the assignment, never '
        .. 'read).  If it is now used, the effective ring changed and section 2 must be re-run',
        reads))
end

return T
