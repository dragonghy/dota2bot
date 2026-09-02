-- What Wraith King's mana reserve rule actually costs, measured over the whole
-- fixture corpus instead of over the one frame that raised it.
--
-- GH #407 (opened by this stream 2026-09-01T23:04Z off section 5e of
-- iterations/reports/hero/20260901T225550Z.md).  That section pinned, on ONE
-- frame, a consequence nobody had priced: X.ShouldSaveMana refuses Q whenever
--
--     nLV >= 6  and  abilityR ~= nil  and  R cooldown <= 3.0
--     and  GetMana() - Q:GetManaCost() < R:GetManaCost()
--
-- and on f_232320_wk_od_burst that threshold is 220 + 95 = 315 while the hero's
-- MAX mana is 272 -- so on that frame Q cannot be cast at any mana at all.  The
-- issue asks for a CORPUS, not a frame: how often does the reserve fire, how
-- often is it the only thing in the way, and how many casts does it cost.
--
-- This file answers the first two and REFUSES the third, which is the part
-- worth reading.  The corpus cannot price the rule in casts, because the
-- shipped X.ConsiderQ returns 0 on 33 of 33 priced frames whether the reserve
-- is on or off -- section 5 measures that instead of assuming it, including the
-- one control that separates "the body ran and still declined" from "the body
-- never ran".  A 0 that has never had the ability to be anything else is not a
-- measurement (the recurring shape in this repo: an unspecced getter answering
-- 0, GH #386 / #391).
--
-- WHAT IS NOT CLAIMED HERE, stated up front:
--   * Nothing about how often the reserve fires in a GAME.  A fixture corpus is
--     a set of instants chosen for other reasons; it is not a sample of play.
--     The in-game half of GH #407 needs frames from the W34 replay batch
--     (GH #388, 103 replays in dem21/, auto-deleted 2026-09-22).
--   * No verdict on whether the rule is right.  Reserving mana so a dead Wraith
--     King can actually reincarnate is a correct rule; this file prices it.
--     bots/ is untouched by this work unit, on purpose.
--
-- SECTIONS
--   1  meter honesty: which frames can be read at all, and why 3 cannot
--   2  the gate census on the 33 readable frames
--   3  the MARGINAL domain -- the reserve fires AND Q was otherwise castable
--   4  the constructive case: max mana below the threshold
--   5  DOMAIN-EMPTY: the cast-count question the corpus cannot answer
--   6  rank blindness: the rule never asks whether R has been learned

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local WK = 'npc_dota_hero_skeleton_king'
-- The ENGINE name.  `skeleton_king_wraithfire_blast` is the display name and
-- the mock answers a blank handle for it -- that mistake cost a whole probe
-- round on 2026-09-01 (report 20260901T225550Z section "wrong name"), and a
-- blank handle reads rank 0 / cost 0, i.e. exactly like a real unlearned Q.
local Q = 'skeleton_king_hellfire_blast'
local R = 'skeleton_king_reincarnation'
-- Q's cast range from the KV snapshot (tests/mock/special_value_shapes.lua,
-- AbilityCastRange = 525).  GetCastRange is on no spec, so it falls through to
-- the generic `^Get` default and answers 0 on every frame (GH #391); section 5
-- feeds this back before concluding anything from a silent ConsiderQ.
local Q_CAST_RANGE = 525

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

--- Every fixture that holds a Wraith King, split by whether the fixture also
--- records that WK's ABILITIES.  The split is the whole point: a v1 fixture
--- without an abilities list gives blank handles, and a blank handle answers
--- rank 0, cooldown 0 and cost 0 -- three readings that are indistinguishable
--- from "unlearned, ready, free".  Counting those frames as data would put an
--- absence into every ratio below.
local function split_corpus()
    local priced, unpriced = {}, {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == WK then
                    local row = { path = path, unit = u }
                    if type(u.abilities) == 'table' then
                        priced[#priced + 1] = row
                    else
                        unpriced[#unpriced + 1] = row
                    end
                    break
                end
            end
        end
    end
    return priced, unpriced
end

local function short(path) return (path:gsub('^tests/fixtures/', '')) end

local function names_of(rows)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = short(r.path) end
    table.sort(out)
    return out
end

local function joined(t) return table.concat(t, ', ') end

--- One frame, read through the real loader.  Returns the operands the reserve
--- rule actually uses plus the two facts section 3 needs.
local function read_frame(path)
    local _, bot = rf.load(path, WK)
    local hQ, hR = bot:GetAbilityByName(Q), bot:GetAbilityByName(R)
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)   -- primes the file-level nLV/nMP/nHP
    return {
        level = bot:GetLevel(),
        mana = bot:GetMana(),
        max_mana = bot:GetMaxMana(),
        q_rank = hQ:GetLevel(),
        q_cost = hQ:GetManaCost(),
        q_castable = hQ:IsFullyCastable(),
        r_rank = hR:GetLevel(),
        r_cost = hR:GetManaCost(),
        r_cd = hR:GetCooldownTimeRemaining(),
        reserve = X.ShouldSaveMana(hQ),
    }
end

-- ---------------------------------------------------------------------------
-- 1. Meter honesty.  Before any ratio: what can actually be read, and is the
--    number being read the FRAME's or the MOCK's default?

tests['[section 1] 36 WK frames, 33 priced and 3 that must be excluded'] =
function()
    local priced, unpriced = split_corpus()
    local n = #priced + #unpriced
    if n ~= 36 then
        error('the corpus holds ' .. n .. ' Wraith King frames, recorded 36.  '
            .. 'Fixtures were added or removed; re-read every count in this '
            .. 'file before quoting one (same rule as '
            .. 'tests/test_wk_bone_guard_talent_bypass.lua section 2)')
    end
    if #priced ~= 33 or #unpriced ~= 3 then
        error(#priced .. ' priced / ' .. #unpriced .. ' unpriced, recorded '
            .. '33 / 3.  The unpriced ones are: ' .. joined(names_of(unpriced)))
    end
    local expect = 'f_073148_zuus_lina.lua, f_080225_wk_lane.lua, '
        .. 'f_080225_wk_revive.lua'
    if joined(names_of(unpriced)) ~= expect then
        error('the frames without an abilities list are now {'
            .. joined(names_of(unpriced)) .. '}, recorded {' .. expect .. '}')
    end
end

tests['[section 1] the excluded 3 read rank 0 / cost 0 -- an ABSENCE, not a 0'] =
function()
    local _, unpriced = split_corpus()
    for _, row in ipairs(unpriced) do
        local f = read_frame(row.path)
        if f.q_cost ~= 0 or f.r_cost ~= 0 or f.r_rank ~= 0 then
            error(short(row.path) .. ' now answers q_cost=' .. f.q_cost
                .. ' r_cost=' .. f.r_cost .. ' r_rank=' .. f.r_rank
                .. '.  It used to answer 0/0/0 because the fixture carries no '
                .. 'abilities list.  If it answers prices now, it belongs in '
                .. 'the priced set and every count in this file moves')
        end
    end
    -- Two of the three are level >= 6, which is what makes them dangerous
    -- rather than merely useless: they sit exactly where the reserve rule
    -- lives, and their 0 prices make it silently FALSE there.
    local at_six = 0
    for _, row in ipairs(unpriced) do
        if read_frame(row.path).level >= 6 then at_six = at_six + 1 end
    end
    if at_six ~= 2 then
        error(at_six .. ' of the 3 unpriced frames are level >= 6, recorded 2.  '
            .. 'That count is the reason they are excluded rather than counted '
            .. 'as "reserve did not fire"')
    end
end

tests['[section 1] every WK frame carries its own max_mp -- the 300 default never stands in'] =
function()
    -- tests/mock/bot_api.lua defaults GetMaxMana to 300 when a unit does not
    -- carry one.  300 < 315 = the threshold section 4 measures, so a corpus
    -- with even one defaulted frame would manufacture "constructively
    -- unreachable" out of a missing field.  This asserts the field is real on
    -- all 36, and pins the default itself so the trap stays visible if the
    -- default ever changes.
    local priced, unpriced = split_corpus()
    local missing = {}
    for _, set in ipairs({ priced, unpriced }) do
        for _, row in ipairs(set) do
            if row.unit.max_mp == nil then missing[#missing + 1] = short(row.path) end
        end
    end
    if #missing ~= 0 then
        error(#missing .. ' WK frame(s) carry no max_mp and would read the '
            .. "mock's default instead of the game's number: " .. joined(missing))
    end
    local ghost = api.MakeHero('npc_dota_hero_dummy_maxmana', {})
    if ghost:GetMaxMana() ~= 300 then
        error("the mock's GetMaxMana default is now " .. tostring(ghost:GetMaxMana())
            .. ', recorded 300.  The note above (300 < 315) is why the '
            .. 'assertion above it exists; re-read it')
    end
end

-- ---------------------------------------------------------------------------
-- 2. The gate census, on the 33 frames that can be read.

local function census()
    local priced = split_corpus()
    local c = { n = #priced, lv6 = 0, gate = 0, reserve = 0, marginal = 0,
                constructive = 0 }
    local named = { reserve = {}, marginal = {}, constructive = {},
                    lock_but_uncastable = {} }
    for _, row in ipairs(priced) do
        local f = read_frame(row.path)
        if f.level >= 6 then c.lv6 = c.lv6 + 1 end
        -- The shipped guard's own two structural operands, read off the frame.
        if f.level >= 6 and f.r_cd <= 3.0 then c.gate = c.gate + 1 end
        if f.reserve then
            c.reserve = c.reserve + 1
            named.reserve[#named.reserve + 1] = short(row.path)
            if f.q_castable then
                c.marginal = c.marginal + 1
                named.marginal[#named.marginal + 1] = short(row.path)
            else
                named.lock_but_uncastable[#named.lock_but_uncastable + 1] =
                    short(row.path)
            end
            if f.max_mana < f.q_cost + f.r_cost then
                c.constructive = c.constructive + 1
                named.constructive[#named.constructive + 1] = short(row.path)
            end
        end
    end
    for _, t in pairs(named) do table.sort(t) end
    return c, named
end

tests['[section 2] 21 frames at level >= 6, 11 inside the gate, 6 reserved'] =
function()
    local c = census()
    if c.n ~= 33 then error('priced corpus is ' .. c.n .. ', recorded 33') end
    if c.lv6 ~= 21 then
        error(c.lv6 .. ' priced frames are level >= 6, recorded 21')
    end
    if c.gate ~= 11 then
        error(c.gate .. ' priced frames satisfy the two structural operands '
            .. '(level >= 6 and R cooldown <= 3.0), recorded 11.  This is the '
            .. 'denominator the 6 below is a fraction OF -- the other 22 frames '
            .. 'never reach the mana arithmetic at all')
    end
    if c.reserve ~= 6 then
        error(c.reserve .. ' priced frames have X.ShouldSaveMana(Q) == true, '
            .. 'recorded 6 (of 11 inside the gate, of 33 priced).  Re-derive '
            .. 'sections 3-5 before quoting any of them')
    end
end

tests['[section 2] the 6 reserved frames, by name'] =
function()
    local _, named = census()
    local expect = 'f_114311_drow_pushguard_silent.lua, '
        .. 'f_225947_wk_trade_kite.lua, f_232320_wk_od_burst.lua, '
        .. 'f_260725_105305_wk_reincarn_gap.lua, f_260820_102645_cm_es_reach.lua, '
        .. 'f_260820_103216_cm_es_aftershock.lua'
    if joined(named.reserve) ~= expect then
        error('the reserved set is now {' .. joined(named.reserve)
            .. '}, recorded {' .. expect .. '}.  A set that moved while the '
            .. 'COUNT held is the change this naming exists to catch')
    end
end

-- ---------------------------------------------------------------------------
-- 3. The marginal domain.  "The reserve fired" is not the same as "the reserve
--    cost something": on a frame where Q is not fully castable anyway, the
--    first disjunct of X.ConsiderQ would have refused with or without it.

tests['[section 3] only 4 of the 6 are marginal; on 2 Q was not castable anyway'] =
function()
    local c, named = census()
    if c.marginal ~= 4 then
        error(c.marginal .. ' of the reserved frames also have Q fully '
            .. 'castable, recorded 4.  Only these can cost anything: on the '
            .. 'others `not abilityQ:IsFullyCastable()` -- the disjunct BEFORE '
            .. 'the reserve -- already refuses')
    end
    local expect_m = 'f_114311_drow_pushguard_silent.lua, '
        .. 'f_232320_wk_od_burst.lua, f_260820_102645_cm_es_reach.lua, '
        .. 'f_260820_103216_cm_es_aftershock.lua'
    if joined(named.marginal) ~= expect_m then
        error('marginal set is now {' .. joined(named.marginal)
            .. '}, recorded {' .. expect_m .. '}')
    end
    local expect_u = 'f_225947_wk_trade_kite.lua, '
        .. 'f_260725_105305_wk_reincarn_gap.lua'
    if joined(named.lock_but_uncastable) ~= expect_u then
        error('the reserved-but-uncastable set is now {'
            .. joined(named.lock_but_uncastable) .. '}, recorded {' .. expect_u
            .. '}.  These two are the difference between "the rule fires on 6" '
            .. 'and "the rule could be costing something on 6"')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The constructive case -- the one GH #407 was opened on.

tests['[section 4] exactly 1 frame is below the threshold at FULL mana'] =
function()
    local c, named = census()
    if c.constructive ~= 1 or named.constructive[1] ~= 'f_232320_wk_od_burst.lua' then
        error('frames whose MAX mana is below Q cost + R cost: ' .. c.constructive
            .. ' {' .. joined(named.constructive) .. '}, recorded 1 '
            .. '{f_232320_wk_od_burst.lua}.  This is the count GH #407 is about: '
            .. 'on such a frame no amount of mana regen can unlock Q')
    end
    local f = read_frame('tests/fixtures/f_232320_wk_od_burst.lua')
    if f.q_cost + f.r_cost ~= 315 or f.max_mana ~= 272 then
        error('operands moved: Q ' .. f.q_cost .. ' + R ' .. f.r_cost .. ' vs '
            .. 'max mana ' .. f.max_mana .. ', recorded 95 + 220 vs 272')
    end
end

tests['[section 4] filling that pool to the brim does not unlock it'] =
function()
    -- The difference between "this hero happened to be low" and "this hero
    -- cannot get there": hand the frame every point of mana it could ever hold
    -- and ask the shipped rule again.
    local _, bot = rf.load('tests/fixtures/f_232320_wk_od_burst.lua', WK)
    local hQ = bot:GetAbilityByName(Q)
    local spec = rawget(bot, '__spec')
    spec.GetMana = function(self) return self:GetMaxMana() end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)
    if X.ShouldSaveMana(hQ) ~= true then
        error('at full mana (272) the reserve rule no longer fires.  Either the '
            .. 'threshold or the pool moved; section 4 above holds the operands')
    end
    -- and the smallest pool that DOES unlock it, read rather than asserted
    spec.GetMana = function() return 315 end
    if X.ShouldSaveMana(hQ) ~= false then
        error('315 mana still reserves; the threshold is not Q cost + R cost '
            .. 'any more and every number in this file needs re-deriving')
    end
    spec.GetMana = function() return 314 end
    if X.ShouldSaveMana(hQ) ~= true then
        error('314 mana does not reserve, so the knife edge is not at 315')
    end
end

-- ---------------------------------------------------------------------------
-- 5. The question this corpus CANNOT answer, measured rather than assumed.

--- Drive the shipped X.ConsiderQ on one frame.  `unlock` replaces the reserve
--- rule with a constant false and changes nothing else; `range` feeds Q's KV
--- cast range back over the unspecced getter's 0 (GH #391).  Also returns how
--- many times the body read the cast range -- the control that separates "ran
--- and declined" from "never ran".
local function consider_q(path, unlock, range)
    local _, bot = rf.load(path, WK)
    local hQ = bot:GetAbilityByName(Q)
    local sp = rawget(hQ, '__spec')
    local reads = 0
    sp.GetCastRange = function()
        reads = reads + 1
        return range and Q_CAST_RANGE or 0
    end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)
    if unlock then X.ShouldSaveMana = function() return false end end
    local ok, d = pcall(function() return X.ConsiderQ() end)
    if not ok then return 'REFUSED', reads end
    return d, reads
end

tests['[section 5] the control: unlocking really does run the body'] =
function()
    -- Without this, the "no decision changed" below is worthless -- it would
    -- read identically if the counterfactual never executed a line.  The cast
    -- range is read on the line AFTER the reserve guard, so the counter is a
    -- direct witness of the short circuit.
    for _, name in ipairs({ 'f_114311_drow_pushguard_silent.lua',
                            'f_232320_wk_od_burst.lua',
                            'f_260820_102645_cm_es_reach.lua',
                            'f_260820_103216_cm_es_aftershock.lua' }) do
        local path = 'tests/fixtures/' .. name
        local _, locked_reads = consider_q(path, false, true)
        local _, open_reads = consider_q(path, true, true)
        if locked_reads ~= 0 then
            error(name .. ': the shipped run read the cast range '
                .. locked_reads .. ' time(s).  It must be 0 -- the reserve '
                .. 'guard is supposed to return before that line')
        end
        if open_reads < 1 then
            error(name .. ': with the reserve forced false the body still '
                .. 'never reached the cast range.  The counterfactual is not '
                .. 'executing anything and section 5 below proves nothing')
        end
    end
end

tests['[section 5] DOMAIN-EMPTY: ConsiderQ is 0 on 33 of 33, locked or not'] =
function()
    local priced = split_corpus()
    local fires0, fires525, changed, refused = 0, 0, 0, 0
    for _, row in ipairs(priced) do
        local shipped_zero = consider_q(row.path, false, false)   -- meter as shipped
        local shipped_fed = consider_q(row.path, false, true)     -- GH #391 fed back
        local unlocked = consider_q(row.path, true, true)
        if shipped_zero == 'REFUSED' or shipped_fed == 'REFUSED'
            or unlocked == 'REFUSED' then refused = refused + 1 end
        if type(shipped_zero) == 'number' and shipped_zero > 0 then
            fires0 = fires0 + 1
        end
        if type(shipped_fed) == 'number' and shipped_fed > 0 then
            fires525 = fires525 + 1
        end
        if tostring(shipped_fed) ~= tostring(unlocked) then changed = changed + 1 end
    end
    if refused ~= 0 then
        error(refused .. ' frame(s) hit a loader refusal, recorded 0')
    end
    if fires0 ~= 0 or fires525 ~= 0 then
        error('shipped X.ConsiderQ fired on ' .. fires0 .. ' frame(s) with the '
            .. 'cast-range meter as shipped and ' .. fires525 .. ' with it fed '
            .. Q_CAST_RANGE .. '; recorded 0 and 0.  A non-zero here is GOOD '
            .. 'news -- it means the corpus finally has a Q decision to price '
            .. 'and the DOMAIN-EMPTY verdict below is stale')
    end
    if changed ~= 0 then
        error('forcing the reserve rule false changed the decision on '
            .. changed .. ' frame(s), recorded 0.  That is the cast-count '
            .. 'reading GH #407 asked for; write it up rather than quoting '
            .. 'this file as "unmeasurable"')
    end
    -- The conclusion, stated as data so it cannot drift from the assertions:
    -- 4 marginal frames, 0 decisions changed, and the body demonstrably ran on
    -- all 4 (control above).  The rule costs this corpus nothing measurable in
    -- casts.  It does not follow that it costs a GAME nothing: this corpus
    -- makes no Q casts at all, while the replay side counted 205 in W34.
end

-- ---------------------------------------------------------------------------
-- 6. Rank blindness: the operand the rule does NOT read.

tests['[section 6] the guard reads hero level and a non-nil handle, never R rank'] =
function()
    local src = read_file(WK_SRC)
    local body = src:match('function X%.ShouldSaveMana%b()(.-)\nend')
    if body == nil then
        error('cannot find X.ShouldSaveMana in ' .. WK_SRC .. '; this section '
            .. 'reads its body, so a rename breaks the reading not just the match')
    end
    local live = {}
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then live[#live + 1] = line end
    end
    local text = table.concat(live, '\n')
    for _, needle in ipairs({ 'nLV >= 6', 'abilityR ~= nil',
                              'GetCooldownTimeRemaining', 'GetManaCost' }) do
        if not text:find(needle, 1, true) then
            error('the reserve rule no longer contains "' .. needle .. '"; its '
                .. 'operands moved and sections 2-4 are readings of a different '
                .. 'function')
        end
    end
    if text:find('abilityR:GetLevel', 1, true) then
        error('the reserve rule now asks R\'s rank.  That is the gap this '
            .. 'section registers -- if it was closed deliberately, delete this '
            .. 'test and say so in the charter')
    end
end

tests['[section 6] the untested shape: level >= 6 with R unlearned'] =
function()
    -- What the corpus can say: zero readable frames put a level->=6 Wraith King
    -- next to an unlearned R, so nothing here has ever exercised the gap.  The
    -- two frames that LOOK like the shape are the excluded ones from section 1,
    -- where rank 0 is an absent field.
    local priced = split_corpus()
    local shape = {}
    for _, row in ipairs(priced) do
        local f = read_frame(row.path)
        if f.level >= 6 and f.r_rank == 0 then shape[#shape + 1] = short(row.path) end
    end
    if #shape ~= 0 then
        error(#shape .. ' priced frame(s) now hold a level >= 6 WK with R at '
            .. 'rank 0: ' .. joined(shape) .. '.  The gap is testable on real '
            .. 'frames now -- measure it instead of leaving it registered')
    end
    -- What the corpus CANNOT say, so it is written as a conditional rather than
    -- a finding: whether the engine prices an UNLEARNED ability at its level-1
    -- cost or at 0.  The mock charges the level-1 rung (that is what the ladder
    -- does with rank 0), and under that reading the rule reserves 220 mana for
    -- an ultimate the hero cannot cast; under a 0 reading, `mana - cost < 0` is
    -- false and it never fires.  Both are consistent with every frame we hold.
    -- GH #366 / #374 make the shape itself real -- bots reaching high level
    -- with ultimate ranks unspent -- which is why it is registered and not
    -- dismissed.
    local _, bot = rf.load('tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua', WK)
    local hR = bot:GetAbilityByName(R)
    local sp = rawget(hR, '__spec')
    sp.GetLevel = function() return 0 end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)
    local hQ = bot:GetAbilityByName(Q)
    local spb = rawget(bot, '__spec')
    spb.GetMana = function() return 300 end
    if X.ShouldSaveMana(hQ) ~= true then
        error('with R demoted to rank 0 and 300 mana against a 220 reserve the '
            .. 'rule declined to fire, so it DOES consult rank somewhere and '
            .. 'the section above is wrong about the source')
    end
end

return tests
