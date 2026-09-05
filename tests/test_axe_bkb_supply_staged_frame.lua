-- [ratchet] [hero] The Black King Bar zero behind `axecull`, re-taken on a frame
-- that finally carries Black King Bars.
--
-- Pays row 3 of GH #357's reopen list -- "the corpus holds ZERO Black King Bars"
-- -> the staged frame holds TWO -- the second of that issue's three real
-- re-decisions to be paid (row 6, Axe t15 in-domain, was paid
-- 2026-08-31T13:59Z in tests/test_axe_t15_in_domain.lua; row 2, the Alchemist
-- objective-clock band, is still open and still owed).
--
-- Sister file: tests/test_axe_cull_immune_veto.lua, which registered `axecull`
-- (Culling Blade is bkbpierce Yes; the shipped branch refuses a spell-immune
-- target) with the verdict SUPPLY-STARVED-IN-CORPUS, and whose section 2 says of
-- its own Black King Bar ratchet:
--
--     "The single most load-bearing supply fact, and the one GH #108
--      (10 -> 25 game-minute cap) is most likely to overturn."
--
--     tests/frames/f_20260831_004433_cm_creepreach.lua
--     69e067 / 20260831_004433_slot1, t = 1190.4 (19:50)
--     npc_dota_hero_axe, team 2, level 21, ALIVE, Culling rank 2, cd 0, 991 mp
--
-- GH #108 did overturn it. This file takes the reading, and the reading says the
-- sentence quoted above was WRONG ABOUT ITS OWN LEVER: the item-slot zero was
-- never load-bearing. It is a PROXY for the zero that is -- the ACTIVE-IMMUNITY
-- zero -- and the two came apart the moment the corpus stopped being empty.
--
-- WHY BY NAME AND NOT THROUGH THE GLOB.  tests/fixtures/ is also the census
-- corpus (tests/frames/README.md, GH #357): admitting this frame turns nine
-- corpus readings red across three levers.  This file loads the frame BY NAME,
-- so it pays exactly one of the three and moves NONE of the nine.  The Black
-- King Bar ratchet in the sister file therefore stays BYTE-IDENTICAL and stays
-- TRUE (tests/fixtures/ still holds zero Black King Bars); only the prose above
-- it is corrected, in the same change that adds this file.
--
-- ===========================================================================
-- THE READING
-- ===========================================================================
--
-- (1) THE ITEM ZERO IS GONE.  2 Black King Bar item-slots on the frame.
--
-- (2) THE IMMUNITY ZERO IS NOT.  ZERO spell-immune hero-instants -- measured
--     with the same eleven modifier names the shipped IsMagicImmune override
--     consults, read out of that file rather than copied.  The (ready Axe) x
--     (spell-immune living enemy) pair count is still 0, and the domain count is
--     still 0.
--
-- (3) WHY (1) CANNOT IMPLY (2), FROM SOURCE, WITHOUT A DATAFEED.  The shipped
--     override at bots/FunLib/aba_global_overrides.lua:237 reads MODIFIERS and
--     nothing else -- eleven HasModifier calls, zero item reads.  An item in a
--     slot cannot make IsMagicImmune() answer true; only the modifier the item
--     grants WHILE ACTIVE can.  So "how many Black King Bars are in the corpus"
--     and "how many instants are spell-immune" are not the same question, and
--     never were.  NOT SUFFICIENT.
--
-- (4) AND NOT NECESSARY EITHER, MEASURED RATHER THAN ARGUED.  The corpus's
--     three spell-immune hero-instants are all modifier_juggernaut_blade_fury,
--     and all three carriers hold ZERO Black King Bars in any slot:
--         npc_dota_hero_juggernaut  tl_20260819_222030_slot1  t=439.5
--         npc_dota_hero_juggernaut  tl_20260819_222030_slot1  t=437.1
--         npc_dota_hero_juggernaut  20260819_222559_slot1     t=661.5
--     So 3 of 3 immune instants in this archive arrived with no Black King Bar
--     on the immune unit.  A Black King Bar census is neither an upper nor a
--     lower bound on the immunity census.  It is a different number that
--     happened to also be zero.
--
-- (5) THE CARRIER SPLIT: EVEN THE COUNT IS THE WRONG COUNT.  Both staged Black
--     King Bars are structurally incapable of entering this domain, for two
--     DIFFERENT reasons, neither of which is about immunity:
--       * slot 4 of npc_dota_hero_axe -- the CASTER's own.  The veto clause
--         reads `npcEnemy:IsMagicImmune()`; the caster's immunity is not in the
--         predicate at all.
--       * slot 5 of npc_dota_hero_lina -- an enemy of Axe, but DEAD on this
--         frame (alive = false, hp = 0).  The funnel requires a living enemy.
--     A count that does not split by (team relative to the carrier) x (alive)
--     over-reports the supply it claims to measure.  Here it over-reports it by
--     2 out of 2.
--
-- (6) A THIRD, INDEPENDENT MISS.  Grant Necrolyte -- Axe's nearest LIVING enemy
--     on this frame -- immunity by fiat and the frame still would not reach the
--     domain: it stands 637.5u away, outside the branch's 375u effective ring,
--     and at 1835 hp, far above the rank-2 execute threshold of 350.  The frame
--     misses on immunity, on carrier, AND on geometry.
--
-- ===========================================================================
-- VERDICT
-- ===========================================================================
--
-- SUPPLY-STARVED-IN-CORPUS: **UNCHANGED**.  Admitting this frame would move the
-- Black King Bar ratchet and would not move the verdict, because the verdict
-- never rested on that ratchet.  `axecull` still cannot be sized locally, and
-- iterations/queue.json: hero-9 (the wave that sizes it) is still the way to
-- size it.  No gate is armed, promoted or written here; bots/ and game/ are
-- untouched by this file's change.
--
-- WHAT ACTUALLY CHANGES: the sister file's supply prose, and the standing
-- instruction for whoever next reads its Black King Bar ratchet going red.
-- Before this round the correct response to that red was "the verdict may now be
-- wrong, go re-read it".  It is now "check the immunity count and the carrier
-- split; the item count alone re-decides nothing".
--
-- ===========================================================================
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ===========================================================================
--   * THE SISTER FILE'S RECORDED SUPPLY NUMBERS ARE A SNAPSHOT, AND TWO OF THE
--     THREE HAVE GROWN AS DESIGNED.  Its header records "104 fixture frames ...
--     THREE spell-immune hero-instants ... 26 frames carry an Axe".  Measured
--     today over the same glob: 107 frames, 28 Axe units, and the immune count
--     UNCHANGED at 3.  Its ratchets are one-sided (`frames < 100`, `axe < 26`,
--     `immune > 3`), which is correct for tripwires on a universal: the corpus
--     is meant to grow.  Section 4 records today's four numbers beside the
--     snapshot so a later reader can tell growth from drift without re-deriving
--     them -- and, since 2026-08-31, checks the first two of them in the same
--     one-sided direction the sentence above calls correct (see section 4).
--   * ONE OF THOSE NUMBERS WAS NEARLY REGISTERED AS A FINDING THAT DOES NOT
--     EXIST.  The scratch census behind the first draft of this file read the
--     immune count as ZERO and the draft header called that a silent downward
--     drift the sister ratchet could not report.  The cause was in the scratch,
--     not the corpus: `src:sub(src:find(pat))` passes BOTH of find's return
--     values, so the "function body" it scanned was the matched signature alone,
--     the eleven HasModifier names came back as an EMPTY set, and every frame
--     then read as not-immune.  A zero produced by an empty predicate is
--     indistinguishable at the number from a zero produced by an empty corpus.
--     Section 1's `n ~= 11` check and section 4's count are what caught it, and
--     they are kept for that reason: any reading here that consults IMMUNE also
--     asserts that IMMUNE is populated.  Same family as the sister file's note
--     that a scan asserting an ABSENCE has no live positive path.
--   * THE EXECUTE THRESHOLD USED HERE IS A LOWER BOUND ON THE REAL ONE.  The
--     dump carries at most one `special_bonus_*` per hero and this Axe carries
--     none (measured 2026-08-31T13:59Z), so the +150 from
--     special_bonus_unique_axe_5 that hero_axe.lua:930 adds when trained cannot
--     be seen from a frame.  A lower threshold admits MORE targets, so every
--     "nothing reaches the domain" statement here errs SAFE.
--   * THE RING IGNORES VISION, which makes it an UPPER bound on reachability --
--     also safe in the same direction.  Inherited verbatim from the sister file.
--   * CAST RANGE 175 IS RECORDED (odota/dotaconstants 10.8.0, 2026-08-23, via
--     the sister file).  This test cannot reach the network.  What it does check
--     against source is the SHAPE the ring and the threshold are built from --
--     `nCastRange + 200` and `150 + 100 * nSkillLV` -- so a change to either in
--     hero_axe.lua turns this file red instead of quietly invalidating it.
--   * COUNTS COME FROM `dofile` ON THE FRAME, never from a regex over the file.
--   * "STRUCTURALLY INCAPABLE" IN (5) IS ABOUT THIS FRAME'S TWO SLOTS, not a
--     claim that a caster-side or dead-carrier Black King Bar is impossible to
--     matter in general.  A dead Lina respawns; the claim is about the instant.

package.path = 'tests/?.lua;' .. package.path

local cs = require('corpus_scale')

local FRAME = 'tests/frames/f_20260831_004433_cm_creepreach.lua'
local OVERRIDES = 'bots/FunLib/aba_global_overrides.lua'
local SRC = 'bots/BotLib/hero_axe.lua'
local SISTER = 'tests/test_axe_cull_immune_veto.lua'
local AXE = 'npc_dota_hero_axe'
local LINA = 'npc_dota_hero_lina'
local NECRO = 'npc_dota_hero_necrolyte'
local CULLING = 'axe_culling_blade'
local BKB = 'black_king_bar'

-- Recorded 2026-08-23 from odota/dotaconstants build/abilities.json (10.8.0),
-- via tests/test_axe_cull_immune_veto.lua.  See HONEST BOUNDS.
local R_MANA = { 100, 125, 150 }
local RING = 175 + 200

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The eleven names the shipped IsMagicImmune override consults, plus the raw
--- body of that override so callers can assert what it does NOT read.
--- Read out of the shipped file rather than copied, so this scan cannot drift
--- away from the reader it is modelling.  Same seam as the sister file's
--- immunity_modifiers().
local function override_body()
    local src = read_file(OVERRIDES)
    local from = src:find('function CDOTA_Bot_Script:IsMagicImmune%(%)')
    assert(from, 'the IsMagicImmune override is gone from ' .. OVERRIDES
        .. '; every immunity number in this file was read through it')
    local rest = src:sub(from)
    return rest:sub(1, rest:find('\nend') or #rest)
end

local function immunity_modifiers()
    local body = override_body()
    local set, n = {}, 0
    for name in body:gmatch("HasModifier%('([%w_]+)'%)") do
        if not set[name] then set[name], n = true, n + 1 end
    end
    return set, n
end

local function frame()
    local fx = dofile(FRAME)
    assert(type(fx) == 'table' and type(fx.units) == 'table',
        FRAME .. ' did not load as a frame table')
    return fx
end

local function unit(fx, name)
    for _, u in ipairs(fx.units) do
        if u.name == name then return u end
    end
    return nil
end

local function ability_of(u, name)
    for _, a in ipairs(u.abilities or {}) do
        if a.name == name then return a end
    end
    return nil
end

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

--- The funnel, over an arbitrary list of frames.  Same shape as the sister
--- file's scan_frames, plus the carrier split (5) shows is missing from a bare
--- item count.  Kept here rather than imported so that moving or renaming the
--- sister file cannot silently take this reading down with it; the two are held
--- together instead by the source-shape ratchets in section 3.
local function scan(frames, IMMUNE)
    local c = {
        frames = 0, bkb_slots = 0, bkb_on_caster_side = 0, bkb_on_dead = 0,
        bkb_live_enemy_of_an_axe = 0, immune_units = 0, axe = 0, ready = 0,
        pairs_ = 0, in_ring = 0, domain = 0,
    }
    local hits = {}
    for _, fx in ipairs(frames) do
        if type(fx) == 'table' and type(fx.units) == 'table' then
            c.frames = c.frames + 1
            local axes, immunes = {}, {}
            for _, u in ipairs(fx.units) do
                if u.name == AXE then axes[#axes + 1] = u end
                for _, m in ipairs(u.modifiers or {}) do
                    if IMMUNE[m.name] then
                        immunes[#immunes + 1] = { u = u, mod = m.name }
                        c.immune_units = c.immune_units + 1
                        break
                    end
                end
            end
            for _, u in ipairs(fx.units) do
                local carries = false
                for _, it in ipairs(u.items or {}) do
                    if it == BKB then carries = true; c.bkb_slots = c.bkb_slots + 1 end
                end
                if carries then
                    -- The carrier split (5).  A slot only ever matters to this
                    -- lever when it sits on a LIVING enemy OF AN AXE.
                    local bLiveEnemy = false
                    for _, me in ipairs(axes) do
                        if u.team ~= me.team and u.alive then bLiveEnemy = true end
                    end
                    if bLiveEnemy then
                        c.bkb_live_enemy_of_an_axe = c.bkb_live_enemy_of_an_axe + 1
                    elseif not u.alive then
                        c.bkb_on_dead = c.bkb_on_dead + 1
                    else
                        c.bkb_on_caster_side = c.bkb_on_caster_side + 1
                    end
                end
            end
            for _, me in ipairs(axes) do
                c.axe = c.axe + 1
                local r = ability_of(me, CULLING)
                local lv = (r and r.level) or 0
                if me.alive and lv >= 1 and (r.cd or 0) <= 0
                    and (me.mp or 0) >= R_MANA[math.min(lv, 3)] then
                    c.ready = c.ready + 1
                    for _, e in ipairs(immunes) do
                        if e.u.team ~= me.team and e.u.alive then
                            c.pairs_ = c.pairs_ + 1
                            local d = dist(e.u, me)
                            if d <= RING then
                                c.in_ring = c.in_ring + 1
                                if e.u.hp < 150 + 100 * lv then
                                    c.domain = c.domain + 1
                                    hits[#hits + 1] = string.format(
                                        '%s t=%s %s on %d hp, %.0fu, %s',
                                        tostring(fx.game), tostring(fx.time),
                                        e.u.name, e.u.hp, d, e.mod)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return c, hits
end

-- NOTE on the idiom: `if not cond then error(...) end`, never
-- `assert(cond, string.format(...))` where the message indexes a row the
-- condition proves absent -- Lua evaluates both arguments of assert.

-- ---------------------------------------------------------------- section 1 --
-- The reading GH #357 row 3 asks for: the item zero moved, the immunity zero
-- did not.

tests['[ratchet] section 1: the staged frame carries 2 Black King Bar slots -- the zero row 3 names is really gone'] = function()
    local IMMUNE = immunity_modifiers()
    local c = scan({ frame() }, IMMUNE)
    assert(c.frames == 1, 'the staged frame did not load')
    assert(c.bkb_slots == 2, string.format(
        'the staged frame carries %d Black King Bar slots, was 2. GH #357 row 3 '
        .. 'is the claim that this number is no longer zero; if it changed again, '
        .. 're-take the reading below rather than editing this number', c.bkb_slots))
end

tests['[ratchet] section 1: and ZERO spell-immune hero-instants -- the zero the verdict actually rests on'] = function()
    local IMMUNE, n = immunity_modifiers()
    if n ~= 11 then
        error(string.format(
            'the shipped override now consults %d modifier names, was 11. Every '
            .. 'immunity count in this file was taken through that list', n))
    end
    local c, hits = scan({ frame() }, IMMUNE)
    if c.immune_units > 0 then
        error(string.format(
            'the staged frame now shows %d spell-immune hero-instants, was 0. That '
            .. 'is the number the SUPPLY-STARVED verdict rests on -- unlike the item '
            .. 'count in the case above -- so go re-read it', c.immune_units))
    end
    if c.pairs_ > 0 or c.domain > 0 then
        error(string.format(
            'DOMAIN REACHED on the staged frame: pairs=%d domain=%d%s -- pin this '
            .. 'instant in place of the counterfactual in ' .. SISTER
            .. ' section 1 and re-read the SUPPLY-STARVED verdict; it is now wrong',
            c.pairs_, c.domain, hits[1] and ('  ' .. hits[1]) or ''))
    end
end

tests['[ratchet] section 1: the Axe on this frame IS a ready carrier -- the zero above is not "no Axe"'] = function()
    -- Without this the two zeros above are true for an uninteresting reason.
    -- This is the first archived instant where a live Axe holds a rank-2 Culling
    -- off cooldown and paid for; the corpus tops out at Axe level 14.
    local fx = frame()
    local axe = unit(fx, AXE)
    assert(axe, 'no Axe on the staged frame')
    assert(axe.alive == true and axe.level == 21, string.format(
        'staged Axe reads alive=%s level=%s, was true/21',
        tostring(axe.alive), tostring(axe.level)))
    local r = ability_of(axe, CULLING)
    assert(r and r.level == 2, 'Culling rank on the staged Axe is not 2')
    assert((r.cd or 0) <= 0, 'Culling is on cooldown here; the frame is not a carrier frame')
    assert(axe.mp >= R_MANA[2], string.format(
        'a rank-2 Culling costs %d; the staged Axe has %s mana', R_MANA[2], tostring(axe.mp)))
    local IMMUNE = immunity_modifiers()
    local c = scan({ fx }, IMMUNE)
    assert(c.axe == 1 and c.ready == 1, string.format(
        'the funnel does not count this Axe as ready: axe=%d ready=%d', c.axe, c.ready))
end

-- ---------------------------------------------------------------- section 2 --
-- Why an item slot was never the load-bearing zero.  Read off the shipped
-- source, so it needs neither the datafeed nor a wave.

tests['[ratchet] section 2: the shipped IsMagicImmune override reads MODIFIERS and no items -- NOT SUFFICIENT'] = function()
    local body = override_body()
    -- Eleven modifier reads ...
    local n = 0
    for _ in body:gmatch("HasModifier%('") do n = n + 1 end
    assert(n == 11, string.format('expected 11 HasModifier reads in the override, found %d', n))
    -- ... and not one item read.  If this ever changes, an item slot could make
    -- IsMagicImmune true and the "not sufficient" half of row 3's answer needs
    -- re-taking.
    for _, probe in ipairs({ 'GetItemInSlot', 'HasItem', 'FindItemSlot',
                             'GetItemSlotType', 'GetItemCount', 'HasScepter' }) do
        if body:find(probe, 1, true) then
            error(string.format(
                'the IsMagicImmune override now reads %s. This file answers GH #357 '
                .. 'row 3 with "an item slot cannot make IsMagicImmune true"; that '
                .. 'answer was read off this function body and is now wrong', probe))
        end
    end
    -- The item NAME may legitimately appear in the body -- but only ever inside
    -- the MODIFIER the item grants.  Probing for the bare name instead is the
    -- first draft's bug: `black_king_bar` is a substring of
    -- `modifier_black_king_bar_immune`, so the probe fired on the very line that
    -- proves the point.  A substring is not a reader.
    for occ in body:gmatch('[%w_]*' .. BKB .. '[%w_]*') do
        assert(occ == 'modifier_black_king_bar_immune', string.format(
            'the override mentions %q, which is not the Black King Bar MODIFIER. '
            .. 'If it now reads the item itself, the "not sufficient" half of row 3 '
            .. 'is wrong', occ))
    end
end

tests['[ratchet] section 2: modifier_black_king_bar_immune is ONE of eleven routes -- NOT NECESSARY'] = function()
    local IMMUNE, n = immunity_modifiers()
    assert(IMMUNE['modifier_black_king_bar_immune'],
        'the Black King Bar modifier is no longer in the immunity list; row 3 is '
        .. 'about that item, so re-read what the list now means')
    assert(n == 11, string.format('the list is %d names, was 11', n))
    assert(IMMUNE['modifier_juggernaut_blade_fury'],
        'modifier_juggernaut_blade_fury has left the list; it is the modifier '
        .. 'behind every immune instant this archive holds, and the '
        .. '"immunity without a Black King Bar" half of row 3 cites it')

    -- And the half that is DATA rather than a name count: every spell-immune
    -- instant this archive actually holds arrived on a unit carrying NO Black
    -- King Bar.  3 of 3.  An item census cannot bound an immunity census in
    -- either direction, and here it does not even correlate.
    local n_immune, n_with_item = 0, 0
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^.+%.lua$') then
            local ok, fx = pcall(dofile, 'tests/fixtures/' .. line)
            if ok and type(fx) == 'table' and type(fx.units) == 'table' then
                for _, u in ipairs(fx.units) do
                    for _, m in ipairs(u.modifiers or {}) do
                        if IMMUNE[m.name] then
                            n_immune = n_immune + 1
                            for _, it in ipairs(u.items or {}) do
                                if it == BKB then n_with_item = n_with_item + 1 end
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    p:close()
    assert(n_immune == 3, string.format(
        'the archive holds %d spell-immune instants, was 3 -- re-take the '
        .. 'co-occurrence below on the new set', n_immune))
    if n_with_item ~= 0 then
        error(string.format(
            '%d of %d spell-immune instants now carry a Black King Bar, was 0 of 3. '
            .. 'The "an item census does not even correlate with the immunity census" '
            .. 'reading in (4) was taken on that zero', n_with_item, n_immune))
    end
end

tests['[ratchet] section 2: the sister file still leans on the item zero in PROSE, and this is where that is corrected'] = function()
    -- The sister file's ratchet is correct and untouched.  What this pins is
    -- that its Black King Bar case is still THERE to be corrected, so a future
    -- reader of a red ratchet finds this file rather than the retired sentence.
    local body = read_file(SISTER)
    assert(body:find('zero Black King Bars anywhere in the corpus', 1, true),
        'the sister file no longer carries the Black King Bar ratchet this file '
        .. 'was written to re-decide. If it was retired, retire this file with it')
    assert(body:find('tests/test_axe_bkb_supply_staged_frame.lua', 1, true),
        'the sister file no longer points at this file. The correction in (3)-(5) '
        .. 'only reaches a reader through that pointer -- restore it')
end

-- ---------------------------------------------------------------- section 3 --
-- The carrier split, the geometry, and the source shapes the numbers rest on.

tests['[ratchet] section 3: both staged Black King Bars are structurally out of this domain, for two different reasons'] = function()
    local fx = frame()
    local axe, lina = unit(fx, AXE), unit(fx, LINA)
    assert(axe and lina, 'the two Black King Bar carriers are not both on the frame')

    local function carries(u)
        for _, it in ipairs(u.items or {}) do if it == BKB then return true end end
        return false
    end
    assert(carries(axe), 'the caster-side Black King Bar is gone from Axe')
    assert(carries(lina), 'the enemy-side Black King Bar is gone from Lina')

    -- Reason one: the caster's own.  The veto clause reads npcEnemy, so Axe's
    -- own immunity is not in the predicate.
    assert(axe.team == 2, 'staged Axe changed team')

    -- Reason two: an enemy, but dead.
    assert(lina.team == 3 and lina.team ~= axe.team, 'Lina is no longer Axe\'s enemy here')
    assert(lina.alive == false and lina.hp == 0, string.format(
        'the enemy Black King Bar carrier now reads alive=%s hp=%s. If she is alive '
        .. 'on this frame the carrier split has a live member and (5) needs re-taking',
        tostring(lina.alive), tostring(lina.hp)))

    local IMMUNE = immunity_modifiers()
    local c = scan({ fx }, IMMUNE)
    assert(c.bkb_on_caster_side == 1 and c.bkb_on_dead == 1
        and c.bkb_live_enemy_of_an_axe == 0, string.format(
        'the carrier split moved: caster-side %d / dead %d / live-enemy %d, was 1/1/0. '
        .. 'A live-enemy Black King Bar is the only one of the three that can ever '
        .. 'enter this domain', c.bkb_on_caster_side, c.bkb_on_dead,
        c.bkb_live_enemy_of_an_axe))
end

tests['[ratchet] section 3: a third independent miss -- the nearest LIVING enemy is outside the ring and far above the threshold'] = function()
    local fx = frame()
    local axe = unit(fx, AXE)
    local nearest, nd = nil, math.huge
    for _, u in ipairs(fx.units) do
        if u.team ~= axe.team and u.alive and u.name ~= axe.name then
            local d = dist(u, axe)
            if d < nd then nearest, nd = u, d end
        end
    end
    assert(nearest and nearest.name == NECRO, string.format(
        'the nearest living enemy is now %s, was necrolyte',
        nearest and nearest.name or 'nobody'))
    assert(nd > 637 and nd < 638, string.format('nearest living enemy at %.1fu, was 637.5', nd))
    assert(nd > RING, string.format(
        'the nearest living enemy is now INSIDE the %du ring (%.1fu). Granting it '
        .. 'immunity would then be one step from the domain -- re-take (6)', RING, nd))
    local r = ability_of(axe, CULLING)
    local threshold = 150 + 100 * r.level
    assert(threshold == 350, 'rank-2 execute threshold moved')
    assert(nearest.hp > threshold, string.format(
        'the nearest living enemy is at %d hp, below the %d threshold', nearest.hp, threshold))
end

tests['[ratchet] section 3: the ring and the threshold still have the SHAPE this file read them from'] = function()
    -- The two numbers above are built from source shapes, not from prose.  175
    -- itself is RECORDED (HONEST BOUNDS); what is checked here is that
    -- hero_axe.lua still builds the ring as cast range + 200 and the kill check
    -- as 150 + 100 * rank, so a change to either turns this file red.
    local src = read_file(SRC)
    local from = src:find('function X%.ConsiderR%s*%(%s*%)')
    assert(from, 'X.ConsiderR not found in ' .. SRC)
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nfunction X%.') or #rest)
    assert(body:find('J%.GetAroundEnemyHeroList%( nCastRange %+ 200 %)'),
        'the branch no longer iterates the cast range + 200 ring; RING = ' .. RING
        .. ' in this file was derived from it')
    -- RE-AIMED 2026-09-05.  `150 + 100 * nSkillLV` left ConsiderR when hero-2 landed
    -- as the gated candidate `cullthresh` (tests/test_axe_cull_threshold_gate.lua):
    -- it is now the GATE-OFF value inside X.CullKillThreshold, which is the shape
    -- every "below the threshold" reading in this file was taken under, since no
    -- reading here arms anything.  Checked where it lives now rather than relaxed --
    -- if the shipped ladder changes, this file's readings are stale either way.
    local cAt = src:find('function X%.CullKillThreshold%s*%(')
    assert(cAt, 'X.CullKillThreshold not found in ' .. SRC
        .. ' -- the shipped execute threshold moved somewhere this ratchet cannot see')
    local cbody = src:sub(cAt)
    cbody = cbody:sub(1, cbody:find('\nfunction X%.') or #cbody)
    assert(cbody:find('local nKillDamage = 150 %+ 100 %* nSkillLV'),
        'the gate-off execute threshold is no longer 150 + 100 * rank; every "below the '
        .. 'threshold" reading in this file used that shape')
    assert(body:find('X%.CullKillThreshold%( nSkillLV %)'),
        'ConsiderR no longer reaches the threshold through the helper, so this file '
        .. 'cannot tell which value its readings were taken under')
end

-- ---------------------------------------------------------------- section 4 --
-- Today's corpus supply numbers, pinned beside the sister header's snapshot so a
-- later reader can tell GROWTH (expected; the ratchets are one-sided because the
-- corpus is meant to grow) from DRIFT (not expected) without re-deriving them --
-- and so that no reading in this file can be produced by an empty predicate.
--
-- CORRECTED 2026-08-31T19:xxZ (director, GH #106 / GH #127 family).  The first
-- draft wrote the first two of these as EQUALITIES -- `c.frames == 107` and
-- `c.axe == 28` -- which is the defect the paragraph directly above says the
-- sister ratchets are one-sided to avoid, written two lines under the sentence
-- saying so.  `c.frames == 107` was RED THE MOMENT IT LANDED: it names the
-- live corpus size, and tests/test_corpus_scale.lua scans for exactly that
-- literal.  Both now go through tests/corpus_scale.lua, whose argument is that
-- both counters are SUMS OVER FIXTURES, so appending a fixture can only raise
-- them: a rise is the corpus growing (not a finding) and a FALL is a deleted
-- fixture or moved behaviour (the only thing these pins were ever written to
-- catch), which cs.corpus and cs.ratchet still report exactly.  The recorded
-- numbers below are unchanged -- what changed is the DIRECTION they are
-- checked in.  The other two cases in this test stay two-sided, each for its
-- own written reason.

tests['[ratchet] section 4: the corpus supply numbers as measured TODAY, against the sister header\'s recorded 104 / 26 / 3'] = function()
    local IMMUNE = immunity_modifiers()
    local frames = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^.+%.lua$') then
            local ok, fx = pcall(dofile, 'tests/fixtures/' .. line)
            if ok then frames[#frames + 1] = fx end
        end
    end
    p:close()
    local c = scan(frames, IMMUNE)
    -- 107 measured by this file (sister header snapshot: 104).  BOTH calls, and
    -- neither is redundant: cs.corpus is the module's idiom for the size itself
    -- and carries the type check plus the repo-wide anti-vacuum FLOOR (100),
    -- which alone would let SEVEN fixtures be deleted without a hand going up;
    -- cs.ratchet keeps TODAY's reading as the fall tripwire, which is the half
    -- of the original equality that was actually load-bearing here.
    cs.corpus(c.frames, 'axe/bkb supply sweep over tests/fixtures')
    cs.ratchet(c.frames, 107, 'corpus fixture frames')
    -- 28 measured by this file (sister header snapshot: 26).  A per-fixture sum,
    -- so a fall is the finding and a rise is the corpus.
    cs.ratchet(c.axe, 28, 'corpus Axe units')
    -- Two-sided ON PURPOSE, unlike the sister ratchet: this is the number every
    -- other reading in this file is taken through, so a FALL to zero here has to
    -- raise a hand rather than read as "no supply".  A zero from an empty
    -- predicate and a zero from an empty corpus are the same integer, and the
    -- first draft of this file was written on the wrong one (see HONEST BOUNDS).
    if c.immune_units ~= 3 then
        error(string.format(
            'the corpus holds %d spell-immune hero-instants; this file and the sister '
            .. 'header both record 3. The sister ratchet only fires ABOVE 3, so a fall '
            .. 'is invisible there -- if this is a real fall, re-read the supply verdict; '
            .. 'if it is zero, suspect the reader before the corpus', c.immune_units))
    end
    assert(c.bkb_slots == 0, string.format(
        'tests/fixtures/ now holds %d Black King Bar slots. The sister file\'s ratchet '
        .. 'is the one that reports that; this case only pins that the GLOB is still '
        .. 'clean, i.e. that the staged frame is still staged', c.bkb_slots))
end

-- ---------------------------------------------------------------- section 5 --
-- Self-tests.  Every reading above asserts an ABSENCE, which on a clean tree is
-- also what a scan that reports nothing at all asserts.  These feed the scanner
-- data it MUST report, and near misses it must NOT.

local SYNTH_IMMUNE = { modifier_black_king_bar_immune = true }

local function synth(enemy, over)
    local axe = { name = AXE, team = 2, x = 0, y = 0, hp = 1000, max_hp = 1000,
                  mp = 500, max_mp = 500, alive = true, items = {},
                  abilities = { { name = CULLING, level = 2, cd = 0 } } }
    for k, v in pairs(over or {}) do axe[k] = v end
    return { game = 'SYNTHETIC', time = 1.0, units = { axe, enemy } }
end

local function synth_enemy(over)
    local e = { name = LINA, team = 3, x = 100, y = 0, hp = 50, max_hp = 900,
                mp = 0, max_mp = 900, alive = true, items = { BKB },
                modifiers = { { name = 'modifier_black_king_bar_immune' } } }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

tests['[ratchet] section 5 self-test: the scanner REPORTS a live immune enemy inside the ring'] = function()
    local c, hits = scan({ synth(synth_enemy()) }, SYNTH_IMMUNE)
    assert(c.domain == 1 and #hits == 1, string.format(
        'the offender was not reported: domain=%d hits=%d', c.domain, #hits))
    assert(hits[1]:find(LINA, 1, true), 'the hit must name the unit: ' .. hits[1])
    assert(c.bkb_live_enemy_of_an_axe == 1 and c.bkb_on_dead == 0
        and c.bkb_on_caster_side == 0, 'the carrier split must put this slot on the live-enemy side')
end

tests['[ratchet] section 5 self-test: the carrier split separates the two staged reasons'] = function()
    -- Dead enemy carrier: counted as a slot, never as live-enemy supply.
    local dead = scan({ synth(synth_enemy({ alive = false, hp = 0 })) }, SYNTH_IMMUNE)
    assert(dead.bkb_slots == 1 and dead.bkb_on_dead == 1
        and dead.bkb_live_enemy_of_an_axe == 0 and dead.domain == 0,
        'a dead enemy carrier must be a slot, on the dead side, and not a hit')
    -- Caster-side carrier: the Axe holds it, the enemy does not.
    local own = scan({ synth(synth_enemy({ items = {}, modifiers = {} }),
                             { items = { BKB } }) }, SYNTH_IMMUNE)
    assert(own.bkb_slots == 1 and own.bkb_on_caster_side == 1
        and own.bkb_live_enemy_of_an_axe == 0 and own.domain == 0,
        'a Black King Bar in the caster\'s own slots must never be enemy supply')
end

tests['[ratchet] section 5 self-test: an item slot alone is not immunity, and immunity alone needs no item'] = function()
    -- This pair IS (3) and (4), driven rather than argued.
    local carried_only = scan({ synth(synth_enemy({ modifiers = {} })) }, SYNTH_IMMUNE)
    assert(carried_only.bkb_slots == 1 and carried_only.immune_units == 0
        and carried_only.domain == 0,
        'an enemy holding a Black King Bar with the buff DOWN must not count as immune')
    local immune_only = scan({ synth(synth_enemy({ items = {},
        modifiers = { { name = 'modifier_juggernaut_blade_fury' } } })) },
        { modifier_juggernaut_blade_fury = true })
    assert(immune_only.bkb_slots == 0 and immune_only.immune_units == 1
        and immune_only.domain == 1,
        'immunity from an ability, with no item anywhere, must still reach the domain')
end

tests['[ratchet] section 5 self-test: the three near misses are still near misses'] = function()
    local far = scan({ synth(synth_enemy({ x = RING + 1 })) }, SYNTH_IMMUNE)
    assert(far.pairs_ == 1 and far.in_ring == 0 and far.domain == 0,
        'an immune enemy just outside the ring is a pair, not a hit')
    local healthy = scan({ synth(synth_enemy({ hp = 400 })) }, SYNTH_IMMUNE)
    assert(healthy.in_ring == 1 and healthy.domain == 0,
        'a rank-2 threshold is 350; a 400 hp target is in-ring but not a hit')
    local cd = scan({ synth(synth_enemy(), { abilities = { { name = CULLING, level = 2, cd = 9 } } }) },
        SYNTH_IMMUNE)
    assert(cd.axe == 1 and cd.ready == 0 and cd.domain == 0,
        'a Culling on cooldown must block the funnel')
end

return tests
