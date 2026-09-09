-- [GH: deepnum] The deep-front hold test decides "do we have the numbers here"
-- by comparing two populations measured with two different rulers.
--
-- THE DEFECT. J.IsLaneFrontTooDeepToHold has two tiers. The shallow one asks
-- "am I alone?" and counts allies within 1000 of me, which is what its comment
-- says. The deep one asks a different question -- "do we out-number them at
-- this spot?" -- and answers it with `(1 + nAllies) <= nEnemies`, where
-- nAllies is the SHALLOW TIER'S 1000u count and nEnemies is read on 1600. So
-- an ally at 1300 is off the board while an enemy at the SAME 1300 is a
-- besieger. The short ruler sits on the "pull back" side, so the branch
-- enforces a rule stricter than the one its own comment states, and says
-- nothing about doing so.
--
-- THE FRAME THAT MAKES IT UNARGUABLE. f_260822_063559_slardar_tp_forward,
-- subject necrolyte: enemy luna is counted at 1328u; ally slardar, 3 units
-- further out at 1331u, is not on the field at all. One comparison, two rulers,
-- two heroes three units apart on opposite sides of it.
--
-- WHY THIS IS A FIX AND NOT A NEW POLICY. No number is invented here. 1600 is
-- the disc this branch already chose for itself, and every other numbers test
-- in this tree reads both sides on ONE disc: SafeToCommitFight 1200/1200,
-- ShouldRegroupNotSolo 1500/1500, ShouldRefuseUnsupportedPunish 1200/1200,
-- ShouldNotChaseWhenLow 1200/1200, ShouldAbortRoshanAttempt 900/900. Section 1
-- asserts the two radii are EQUAL rather than that the new one is 1600:
-- symmetry is the property, 1600 is today's value.
--
-- ⚠️ THIS HELPER IS NOT ARMED-ONLY, and its header said it was until this
-- change. The Think that calls it is guarded by `bCustomLastHit or bSupLastHit
-- or bLaneFixSupport or bLaneFixCoreLH or bBodyBlock`, and bCustomLastHit is
-- not a soak gate: it is true for any hero with an override laning module and
-- for a pos-1 paired with a human pos-5. That is why this repair carries its
-- own id instead of inheriting the caller's (the 0OVERCHASE rule applies to a
-- host that really is gate-locked; this one is not). Section 6 pins the gate.
--
-- ⭐ THE NUMBERS (115 fixtures, 1021 live frames,
-- tests/_lanekill_domain_sweep.lua -- the same walk that priced hrreach and
-- hrparity, extended rather than duplicated):
--   * 871 frames sit under the 400 floor, 66 in the shallow tier, `dn_tier2`
--     84 in the deep tier -- that is this lever's whole domain, and 52 of the
--     84 have at least one visible enemy within 1600 of the spot.
--   * `dn_disc_differs` 13 -- frames where the 1600 disc really holds more
--     allies than the 1000 disc. That is the ARITHMETIC UPPER BOUND on where
--     this lever could possibly bite.
--   * `dn_closes` 2, `dn_opens` 0 -- armed, exactly 2 frames stop abandoning
--     the front and none starts. shipped 71 true -> armed 69 true.
--   * 13 and 2 are SUPPOSED to differ: a wider ally disc only changes the
--     verdict when it carries the count across `<= nEnemies`. 13 is a bound,
--     2 is what the function does, and section 3 asserts the bound as a bound.
--
-- ⭐⭐ THE 2 IS CROSS-CHECKED, NOT RESTATED. `dn_pred_flips` is arithmetic on
-- the raw populations (count both discs, redo the comparison by hand);
-- `dn_closes` is what the shipped function actually did when driven with the id
-- armed. Different code paths, same 2, and section 4 asserts they are equal --
-- the check that can tell "keys on the parity test" from "keys on nothing".
--
-- ⭐⭐⭐ THE DOMAIN IS NOT A STUB, and that is asserted rather than assumed.
-- Every row here is hero POSITIONS and ancient positions, which every fixture
-- carries for real; nothing on this path calls a getter the loader answers with
-- a silent constant (the GH #656 shape). `dn_disc_differs` 13 is the proof that
-- the loader is answering the radius question rather than shrugging.
--
-- ⛔ SAID BEFORE ANY WAVE, NOT AFTER (GH #622). WHAT THIS GUARD DOES NOT FIX:
-- the two discs now share a RADIUS but not a CENTRE -- allies are counted
-- around the bot, enemies around vLoc. That half cannot be priced on this
-- corpus at all: the loader REFUSES GetLaneFrontLocation (GH #61) and lane
-- geometry is an open corpus request (GH #648/#652), so the real vLoc of a live
-- frame is unknown and any vLoc invented here would measure the invention. The
-- whole census is therefore taken at vLoc = bot:GetLocation() -- the one spot a
-- frame witnesses a hero standing on, and the vLoc
-- tests/test_replay_megabundle_laning.lua already drives -- where the centres
-- coincide and only the radius half is in play. Registered, not shipped, not
-- silently folded into this reading.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Both flip witnesses come off the sweep's own `F ... dn_pred_flips` lines, so
-- the corpus picked them; they are not frames anyone went looking for.
local W1 = 'tests/fixtures/f_260819_223607_sniper_rooted.lua'
local W1_HERO = 'npc_dota_hero_sniper'
local W2 = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua'
local W2_HERO = 'npc_dota_hero_juggernaut'
-- Negative controls: the discs differ here too, and the armed verdict is still
-- "too deep". They are what separates "narrowed" from "switched off".
local N1 = 'tests/fixtures/f_260820_042612_axe_blink_init_573.lua'
local N1_HERO = 'npc_dota_hero_juggernaut'
local N2 = 'tests/fixtures/f_260822_063559_slardar_tp_forward.lua'
local N2_HERO = 'npc_dota_hero_necrolyte'

-- ------------------------------------------------------------ source reads --

local function jmz_source()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

local function helper_body()
    local src = jmz_source()
    local at = assert(src:find('function J.IsLaneFrontTooDeepToHold( bot, vLoc )', 1, true),
        'J.IsLaneFrontTooDeepToHold moved')
    local fin = assert(src:find('\nend\n', at, true), 'helper has no end')
    return src:sub(at, fin)
end

-- Comments are stripped before every structural read: this helper's header
-- quotes both radii, the id name and five sibling helpers in prose, so an
-- unstripped search would anchor on the explanation instead of the code.
local function stripped_body()
    local out = {}
    for line in (helper_body() .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

-- ------------------------------------------------------------- the manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_lanekill_domain_sweep.lua 2>&1'),
        'could not start tests/_lanekill_domain_sweep.lua')
    local raw = p:read('*a')
    p:close()
    local m = { C = {}, G = {}, F = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local kind = line:match('^(%S+)')
        if kind == 'C' then
            local k, n = line:match('^C (%S+) (%-?%d+)$')
            if k then m.C[k] = tonumber(n) end
        elseif kind == 'G' then
            local k, v = line:match('^G (%S+) (%S+)$')
            if k then m.G[k] = v end
        elseif kind == 'F' then
            local fx, hero, what = line:match('^F (%S+) (%S+) (%S+)$')
            if fx then table.insert(m.F, { fixture = fx, hero = hero, what = what }) end
        elseif kind == 'DONE' then
            m.done = true
        end
    end
    assert(m.done, 'the corpus sweep did not finish -- run '
        .. '`lua5.1 tests/_lanekill_domain_sweep.lua` by hand to see why:\n'
        .. raw:sub(1, 800))
    manifest_cache = m
    return m
end

local function C(key)
    local n = manifest().C[key]
    assert(n ~= nil, 'the sweep did not report counter ' .. key)
    return n
end

-- Drive the helper on one real frame, unarmed and then with only 'deepnum'
-- armed, at vLoc = the subject's own location (the pricing convention above).
local function drive(path, hero)
    local J, bot = rf.load(path, hero)
    local armed = {}
    J.IsSoakCandidate = function(id) return armed[id] == true end
    local vHere = bot:GetLocation()
    local shipped = J.IsLaneFrontTooDeepToHold(bot, vHere)
    armed = { deepnum = true }
    local guarded = J.IsLaneFrontTooDeepToHold(bot, vHere)
    armed = {}
    local function count_allies(r)
        local n = 0
        for _, a in pairs(J.GetNearbyHeroes(bot, r, false, BOT_MODE_NONE) or {}) do
            if J.IsValidHero(a) then n = n + 1 end
        end
        return n
    end
    local hOwn, hEny = GetAncient(GetTeam()), GetAncient(GetOpposingTeam())
    return {
        shipped = shipped,
        guarded = guarded,
        near = count_allies(1000),
        wide = count_allies(1600),
        enemies = #J.GetEnemiesNearLoc(vHere, 1600),
        depth = J.GetLocationToLocationDistance(vHere, hOwn:GetLocation())
            - J.GetLocationToLocationDistance(vHere, hEny:GetLocation()),
    }
end

-- ================================ 1. the guard symmetrises, asserted as such --

tests['[deepnum] the armed ally radius equals the enemy radius, whatever it is']
= function()
    local g = manifest().G
    local nE = tonumber(g.DN_ENEMY_R)
    local nA = tonumber(g.DN_ARMED_R)
    assert(nE ~= nil, 'the sweep could not parse the deep tier enemy radius')
    assert(nA ~= nil,
        "the sweep could not parse an ally radius inside the 'deepnum' block " ..
        '(got ' .. tostring(g.DN_ARMED_R) .. ') -- either the guard stopped ' ..
        'reading a second ally set or it now hides the number behind a ' ..
        'variable, and a census that cannot read the ruler cannot check it')
    -- The property is SYMMETRY, not the literal 1600. Asserting equality means
    -- the day someone re-tunes the deep tier's enemy disc, a guard that kept
    -- 1600 goes red here instead of quietly becoming a different lever.
    assert(nA == nE,
        'the guard counts allies to ' .. nA .. ' but enemies to ' .. nE ..
        ' -- it exists to put both sides of the numbers test on ONE ruler, ' ..
        'and two unequal rulers is the defect it was written to remove')
    -- And the SHIPPED default must still carry the asymmetry: this id is an
    -- unpromoted soak candidate, so an ungated repair means it shipped by
    -- accident -- and this helper is NOT armed-only (see the header), so an
    -- accident here is live in real games for override-module heroes.
    assert(tonumber(g.DN_ALLY_R) ~= nil and tonumber(g.DN_ALLY_R) ~= nE,
        'the shipped ally radius now equals the enemy radius (' ..
        tostring(g.DN_ALLY_R) .. ') -- the repair has left its gate. If that ' ..
        'was a promote, remove this assertion in the same change and say so; ' ..
        'if it was not, an unpromoted behaviour change is live in real games.')
end

tests['[deepnum] the shallow tier is untouched and still reads the 1000 count']
= function()
    -- The gated recount must not leak upward. The shallow tier answers a
    -- DIFFERENT question ("am I alone here?"), its comment names 1000 as the
    -- ruler for that question, and nothing in this round argued about it.
    local body = stripped_body()
    local atShallow = body:find('return nAllies == 0', 1, true)
    local atGate = body:find("IsSoakCandidate%(%s*'deepnum'%s*%)")
    assert(atShallow ~= nil, 'the shallow tier moved; re-anchor this pin')
    assert(atGate ~= nil, "the shipped helper no longer names 'deepnum'")
    assert(atShallow < atGate,
        'the deepnum recount now sits ABOVE the shallow tier, so it can ' ..
        'change an answer it was never priced against')
end

tests['[deepnum] the id appears exactly once in the shipped helper'] = function()
    local body = stripped_body()
    local n = 0
    for _ in body:gmatch("IsSoakCandidate%(%s*'deepnum'%s*%)") do n = n + 1 end
    assert(n == 1, "the helper names 'deepnum' " .. n ..
        ' times in code; it is one lever with one call site')
end

-- ======================= 2. the deep tier's own population, before any gate --

tests['[deepnum] the corpus reaches the deep tier at all'] = function()
    assert(C('dn_live') > 0, 'no live frame reached the census')
    assert(C('dn_noancient') == 0,
        C('dn_noancient') .. ' frames could not read both ancients -- the ' ..
        'depth convention this whole helper rests on is unavailable there')
    assert(C('dn_underfloor') + C('dn_tier1') + C('dn_tier2') == C('dn_live'),
        'the three depth tiers do not close over the live population')
    assert(C('dn_tier2') > 0,
        'the deep tier has no frames in this corpus, so nothing below this ' ..
        'line is a measurement of the lever')
end

-- ================================== 3. the arithmetic bound, kept as a bound --

tests['[deepnum] the discs really do differ on this corpus'] = function()
    -- Not assumed: if the loader answered the radius question with a shrug,
    -- the two ally discs would return identical sets on every frame and every
    -- reading below would be about tests/mock/, not about Dota (GH #656).
    assert(C('dn_disc_differs') > 0,
        'the 1000 and 1600 ally discs never differ on any deep-tier frame -- ' ..
        'this census is measuring the loader, not the tree')
    -- A BOUND, asserted as one. Writing this as equality would be a
    -- coincidence dressed as a cross-check: a wider ally disc only moves the
    -- verdict on the frames where the extra body crosses `<= nEnemies`.
    assert(C('dn_closes') <= C('dn_disc_differs'),
        'more frames flipped (' .. C('dn_closes') .. ') than have differing ' ..
        'ally discs (' .. C('dn_disc_differs') .. ') -- impossible, so the ' ..
        'guard is keying on something other than the ally count')
end

-- ======================= 4. two independent routes to the same number, equal --

tests['[deepnum] the arithmetic flip count equals the driven flip count']
= function()
    assert(C('dn_raised') == 0,
        'the helper raised on ' .. C('dn_raised') .. ' frames')
    assert(C('dn_pred_flips') == C('dn_closes'),
        'arithmetic on the raw populations says ' .. C('dn_pred_flips') ..
        ' frames flip, the armed drive says ' .. C('dn_closes') ..
        ' -- the guard is not keying on the parity test it claims to repair')
    assert(C('dn_closes') > 0,
        'the guard changes nothing on this corpus, so nothing here witnesses it')
end

tests['[deepnum] the forbidden direction is empty'] = function()
    -- By construction the armed ally set is a SUPERSET of the shipped one, so
    -- `1 + nAllies` can only grow and the verdict can only go true -> false.
    -- Armed may KEEP a deep front; it must never abandon one the shipped code
    -- held. A single dn_opens frame means the guard is not the superset it
    -- claims to be.
    assert(C('dn_opens') == 0,
        C('dn_opens') .. ' frames went false -> true under the guard; the ' ..
        'armed ally count is a superset, so that direction is unreachable ' ..
        'unless the guard also changed the enemy side')
    assert(C('dn_armed_true') == C('dn_shipped_true') - C('dn_closes'),
        'shipped ' .. C('dn_shipped_true') .. ' true, armed ' ..
        C('dn_armed_true') .. ' true, ' .. C('dn_closes') .. ' closes -- ' ..
        'those three do not reconcile, so some frame moved unaccounted for')
end

-- ==================================== 5. the witnesses, named and re-derived --

tests['[deepnum] witness 1: an ally at 1244 was off a board an enemy at 622 was on']
= function()
    local r = drive(W1, W1_HERO)
    assert(r.depth > 1600, 'witness 1 is no longer in the deep tier (depth ' ..
        math.floor(r.depth) .. ')')
    assert(r.near == 0 and r.wide == 1,
        'witness 1 ally counts moved: 1000-disc ' .. r.near ..
        ', 1600-disc ' .. r.wide .. ' (was 0 and 1)')
    assert(r.enemies == 1,
        'witness 1 enemy count moved to ' .. r.enemies .. ' (was 1)')
    assert(r.shipped == true,
        'shipped no longer abandons this front, so this frame no longer ' ..
        'witnesses the defect')
    assert(r.guarded == false,
        'the guard no longer holds this front: 1 + ' .. r.wide .. ' <= ' ..
        r.enemies .. ' should be false')
end

tests['[deepnum] witness 2: same shape on a different game and a different hero']
= function()
    local r = drive(W2, W2_HERO)
    assert(r.depth > 1600, 'witness 2 is no longer in the deep tier')
    assert(r.near == 0 and r.wide == 1,
        'witness 2 ally counts moved: ' .. r.near .. ' / ' .. r.wide)
    assert(r.enemies == 1, 'witness 2 enemy count moved to ' .. r.enemies)
    assert(r.shipped == true and r.guarded == false,
        'witness 2 no longer flips (shipped ' .. tostring(r.shipped) ..
        ', guarded ' .. tostring(r.guarded) .. ')')
end

tests['[deepnum] negative control: the extra ally is counted and the answer stays true']
= function()
    -- N1 juggernaut: ally silencer at 1152u is invisible to the shipped ruler
    -- too, so the guard DOES count it -- 1 + 1 <= 2 -- and still says the
    -- front cannot be held. This is the frame that separates "narrowed" from
    -- "switched off": a mutant that simply disabled the deep tier would go red
    -- here and green on both witnesses.
    local r = drive(N1, N1_HERO)
    assert(r.depth > 1600, 'N1 left the deep tier')
    assert(r.wide > r.near,
        'N1 no longer has an ally in the 1000-1600 band, so it no longer ' ..
        'controls for anything')
    assert(r.shipped == true and r.guarded == true,
        'N1 flipped (shipped ' .. tostring(r.shipped) .. ', guarded ' ..
        tostring(r.guarded) .. ') -- the guard is not narrowing, it is ' ..
        'disabling the deep tier')
end

tests['[deepnum] negative control 2: outnumbered 4-to-2 is still outnumbered']
= function()
    -- N2 necrolyte is the frame quoted at the top of this header: enemy luna
    -- counted at 1328u, ally slardar not counted at 1331u. Four enemies, so
    -- even with slardar on the board the numbers test still refuses the hold.
    local r = drive(N2, N2_HERO)
    assert(r.depth > 1600, 'N2 left the deep tier')
    assert(r.enemies >= 4,
        'N2 now sees only ' .. r.enemies .. ' enemies; it was chosen because ' ..
        'the count is far past the tipping point')
    assert(r.wide == r.near + 1,
        'N2 band ally count moved (' .. r.near .. ' / ' .. r.wide .. ')')
    assert(r.shipped == true and r.guarded == true,
        'N2 flipped, which would mean the guard stopped comparing counts')
end

-- ============================================ 6. the gate itself, not the id --

tests['[deepnum] the guard is turbo-gated and carries its own id'] = function()
    -- This helper is NOT armed-only (bCustomLastHit in mode_laning_generic.lua
    -- is not a soak gate), so an inherited gate would have left the repair live
    -- in shipped games for override-module heroes. Both conjuncts, in code.
    local body = stripped_body()
    assert(body:find('J.IsModeTurbo%(%)%s*and%s*J.IsSoakCandidate%(%s*\'deepnum\'%s*%)'),
        'the deepnum branch is no longer `IsModeTurbo() and ' ..
        "IsSoakCandidate('deepnum')` -- either the turbo conjunct went away " ..
        '(this lab tunes turbo only) or the gate was restructured')
end

tests['[deepnum] the host Think is still reachable without any soak id']
= function()
    -- The premise of section 6, pinned where it can rot: if bCustomLastHit
    -- ever becomes a soak gate, the reason this repair carries its own id
    -- disappears and the 0OVERCHASE rule starts applying instead.
    local fh = assert(io.open('bots/mode_laning_generic.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    local at = assert(s:find('local bCustomLastHit', 1, true),
        'bCustomLastHit is gone; re-derive why deepnum has its own id')
    local decl = s:sub(at, (s:find('\n\n', at, true) or #s))
    assert(not decl:find('IsSoakCandidate%(%s*\'lf', 1),
        'bCustomLastHit now looks gated; re-read the 0OVERCHASE rule')
    assert(decl:find('local_mode_laning_generic', 1, true),
        'bCustomLastHit no longer keys on the override module, which was the ' ..
        'ungated disjunct that makes this helper live in shipped games')
end

return tests
