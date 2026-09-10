-- [hero] `cmqpoke` -- the release test Crystal Maiden's catch-all Crystal Nova
-- path never had, and the FIRST Crystal Maiden lever in this repo whose armed
-- leg moves a decision the fixture corpus actually reaches.
--
-- THE DEFECT, in two neighbouring branches of X.ConsiderQImpl's `--非撤退的逻辑`
-- block.  Both ask for the same cast, on the same subject
-- (`nWeakestEnemyHeroInBonus`), through the same J.GetCastLocation.  They differ
-- in exactly one term:
--
--     upper   nMP > 0.8 or bot:GetMana() > nKeepMana * 2    <- what she HAS
--     lower   weakest-in-bonus health ratio < 0.4           <- what it BUYS
--
-- The upper one is the lower one with its quality test swapped for a wallet
-- test, and because it sits six lines ABOVE it, it always wins.  The enclosing
-- block's only mode term is a NEGATED one (`~= BOT_MODE_RETREAT`), so this is
-- the path that fires whenever the specific paths above it do not.
--
-- Same family as `cmrcrowd` (GH #649) one function down -- the one release path
-- in the file that never asks what the cast is for -- but not the same shape:
-- there the unqualified disjunct short-circuits the qualified one inside a
-- single `if`; here it is a separate, earlier branch, so there is nothing to
-- short-circuit and nothing that could ever reach the qualified one first.
--
-- ⭐ THE PIN (section 4).  tests/fixtures/f_260820_182906_lion_drain_survived.lua
-- is the single Crystal Maiden decision GH #658 found in the whole corpus, and
-- it is this branch: CM level 11, 543/831 mana, one ally inside 1200, three
-- enemies at 625.2u / 749.5u / 885.1u holding 0.62 / 0.94 / 0.97 health, no kill
-- on the table.  65% mana is NOT above the 0.8 ratio, so the disjunct that fires
-- is the flat 440.  Shipped orders crystal_maiden_crystal_nova at the Lion;
-- armed the branch declines, the branches below it decline too, and
-- X.SkillsComplement orders nothing.
--
-- ⚠️ WHAT THIS FILE DOES NOT CLAIM, and the limit is a harness one.  The two
-- multi-hit branches directly above the pinned one read
-- `nCanHurtHeroLocationAoE`, and tests/mock/replay_fixture.lua REFUSES hero AoE
-- searches by construction (they answer `{count = 0}` for every caller, see its
-- aoe_search header).  So this corpus cannot say how often those branches would
-- have taken the frame first in a real game; the funnel in section 5 is
-- therefore an UPPER bound on how often the wallet branch is the reason a Nova
-- goes out, never a rate.  `bot:GetActiveMode()` answers 0 offline, which is
-- what makes the negated mode term true here and most other CM branches dark.
--
-- ⛔ NOT a claim that CM should never poke.  Crystal Nova's cooldown is
-- 11/10/9/8s and in Turbo a declined one comes back fast; the argument for
-- declining is that it is her only AoE slow and her mana is the binding
-- constraint on the Frostbite follow-up.  Whether that trade is worth it in
-- aggregate is a wave's question, which is why this ships gated.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC  = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND = 'cmqpoke'
local PIN  = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua'

--- The shipped constants this lever reasons about, read here so a change to
--- either goes red beside the prose that prices it.
local KEEP_MANA   = 220
local RATIO_TERM  = 0.8
local QUALITY_BAR = 0.4

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely mentions the expression.
local function code_only(path)
    local out = {}
    for line in read_file(path):gmatch('[^\n]*') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

--- The aether-lens term of this hero's cast rings, computed the way
--- X.SkillsComplement computes it (hero_crystal_maiden.lua :327) rather than
--- assumed: `J.IsItemAvailable` then `J.GetAetherLensRangeBonus(item, 250)`.
--- With only this file's own candidate armed the bonus helper is ungated and
--- answers the shipped 250, which is exactly what the branch sees.
--- Must be called with the J of an already-loaded frame -- J.IsItemAvailable
--- reads GetBot(), so it is a fact about the SUBJECT, not about the file.
local function aether_bonus(J)
    local aether = J.IsItemAvailable('item_aether_lens')
    if aether == nil then return 0 end
    return J.GetAetherLensRangeBonus(aether, 250)
end

local function count(hay, needle)
    local n, i = 0, 1
    while true do
        local s = hay:find(needle, i, true)
        if s == nil then return n end
        n, i = n + 1, s + 1
    end
end

--- Every frame file that can carry a Crystal Maiden, both directories.  Globbed
--- on purpose: tests/frames/ sits OUTSIDE tests/fixtures/ and a census that
--- reads only the latter is out of domain for anything staged (GH #236 / #281).
local function frame_paths()
    local t = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua tests/frames/*.lua 2>/dev/null'))
    for l in p:lines() do t[#t + 1] = l end
    p:close()
    table.sort(t)
    return t
end

--- Drive Crystal Maiden as SUBJECT on one frame and report what X.ConsiderQImpl
--- answers, with `cmqpoke` armed or not.  Turbo is forced because the gate is
--- turbo-only and J.IsModeTurbo is not readable from a .dem.
--- @return desire (number), or nil when CM is absent/dead/unloadable there.
local function drive(path, bArmed)
    local desire
    pcall(function()
        local J, bot = rf.load(path, 'npc_dota_hero_crystal_maiden')
        if bot == nil or not bot:IsAlive() then return end
        J.IsModeTurbo = function() return true end
        J.IsSoakCandidate = function(id) return bArmed and id == CAND end
        local X = rf.load_hero('crystal_maiden')
        pcall(X.SkillsComplement)
        local ok, d = pcall(X.ConsiderQImpl)
        desire = ok and d or -1
    end)
    return desire
end


-- ---------------------------------------------------------------- section 1
tests['[1] the wallet test is behind the helper, and the helper names one id'] = function()
    local code = code_only(SRC)

    assert(code:find('function X.cm_ShouldSpendSurplusNova(', 1, true) ~= nil,
        'X.cm_ShouldSpendSurplusNova is gone; the lever lost its seam.')

    assert(count(code, "IsSoakCandidate( '" .. CAND .. "' )") == 1, string.format(
        "the code (comments stripped) must name '%s' exactly ONCE -- a second "
        .. 'call site is a second lever wearing this one\'s id.', CAND))

    -- The pullcad trap: a gate naming a sibling freezes FALSE the day the
    -- sibling is promoted, and check_armed_wiring.py still calls it WIRED.
    local helper = code:match('function X%.cm_ShouldSpendSurplusNova%(.-\nend')
    assert(helper ~= nil, 'cannot isolate the helper body')

    -- TURBO-ONLY.  Added because the mutation stand caught its absence: the
    -- mutant that drops J.IsModeTurbo() while keeping the candidate check
    -- SURVIVED the first run of tools/agent/mutstand_cmqpoke.sh (M2).  Nothing
    -- else in this file looks at it -- the corpus forces turbo on to drive the
    -- armed leg at all, so a lever that had quietly stopped being turbo-only
    -- would read back green everywhere.
    assert(helper:find('J.IsModeTurbo()', 1, true) ~= nil,
        'X.cm_ShouldSpendSurplusNova is no longer turbo-only.  Every behaviour '
        .. 'change in this stream ships turbo-only until promoted; a gate that '
        .. 'lost that conjunct is live in normal mode too.')
    for _, sibling in ipairs({ 'cmqreach', 'cmrcrowd', 'cmwface' }) do
        assert(helper:find(sibling, 1, true) == nil, string.format(
            "X.cm_ShouldSpendSurplusNova names the sibling id '%s'.  A gate "
            .. 'conjoined with another id is frozen FALSE the day that id is '
            .. 'promoted.  Keep this helper to exactly one id.', sibling))
    end

    -- The call site took the expression's place; the raw expression must not
    -- also survive somewhere as a second, ungated copy.
    assert(code:find('X.cm_ShouldSpendSurplusNova( nWeakestEnemyHeroInBonus,', 1, true) ~= nil,
        'the catch-all branch no longer calls the helper with the branch\'s own '
        .. 'subject; re-anchor this test on the new call.')
    -- The shipped disjunction is DELIBERATELY still spelled at the call site --
    -- tests/_cm_t10_payoff_sweep.lua reads this file's mana gates out of the
    -- source text, so hiding it behind renamed parameters silently deletes a
    -- gate from that sweep's model.  Exactly one `nMP > 0.8` is expected, and it
    -- must be the argument to this helper.
    assert(count(code, 'nMP > ' .. RATIO_TERM) == 1, string.format(
        '%s holds %d `nMP > %s` sites; exactly 1 is expected, as the shipped '
        .. 'argument to X.cm_ShouldSpendSurplusNova.  Zero means the expression '
        .. 'moved behind the helper and tests/_cm_t10_payoff_sweep.lua just lost '
        .. 'a gate it still models; two means this branch grew back un-gated.',
        SRC, count(code, 'nMP > ' .. RATIO_TERM), RATIO_TERM))

    -- The 进攻 branch upstream keeps its OWN wallet test (`nMP > 0.75 or
    -- bot:GetMana() > nKeepMana * 2`) and is deliberately NOT in this id: it is
    -- behind J.IsGoingOnSomeone, i.e. she is already committing to a target, so
    -- "what it buys" is answered by the mode rather than by the target's health.
    assert(count(code, 'nKeepMana * 2') == 2, string.format(
        '%s holds %d `nKeepMana * 2` sites; exactly 2 are expected (the 进攻 '
        .. 'branch, out of scope for this id, and this lever\'s own argument).',
        SRC, count(code, 'nKeepMana * 2')))
end


-- ---------------------------------------------------------------- section 2
tests['[2] the shipped constants this lever prices are still the shipped ones'] = function()
    local code = code_only(SRC)
    assert(code:find('nKeepMana = ' .. KEEP_MANA, 1, true) ~= nil, string.format(
        'nKeepMana is no longer %d.  Every number in this file\'s header (the '
        .. '440 disjunct, the 550 crossover, the 40%%/20%% reserves) is derived '
        .. 'from it -- re-derive them, do not just re-pin this line.', KEEP_MANA))
    assert(code:find('GetMaxHealth() < ' .. QUALITY_BAR, 1, true) ~= nil
        or code:find('/ nMaxHealth < ' .. QUALITY_BAR, 1, true) ~= nil, string.format(
        'the %s quality bar the armed leg borrows from the sibling branch is '
        .. 'gone.  The armed test is meant to be the sibling\'s own threshold, '
        .. 'not a new one.', QUALITY_BAR))
end


-- ---------------------------------------------------------------- section 3
tests['[3] direction: armed can only ever DELETE a Nova, never add one'] = function()
    local moved_on, moved_off = {}, {}
    for _, path in ipairs(frame_paths()) do
        local off = drive(path, false)
        local on  = drive(path, true)
        if off ~= nil and on ~= nil then
            local bOff = type(off) == 'number' and off > 0
            local bOn  = type(on)  == 'number' and on  > 0
            if bOn and not bOff then moved_on[#moved_on + 1] = path end
            if bOff and not bOn then moved_off[#moved_off + 1] = path end
        end
    end
    assert(#moved_on == 0, string.format(
        'armed ADDED a Crystal Nova on %d frame(s), e.g. %s.  This lever\'s '
        .. 'whole safety argument is that the shipped disjunction is evaluated '
        .. 'first and a false answer returns unchanged; an added cast means '
        .. 'that ordering was broken.', #moved_on, tostring(moved_on[1])))
    assert(#moved_off >= 1, string.format(
        'armed deleted NOTHING on the whole corpus (%d frames scanned).  A '
        .. 'lever with no reachable domain is inventory, not progress '
        .. '(hero.md -131); if the corpus really lost the pin frame, say so '
        .. 'here rather than deleting this assertion.', #frame_paths()))
end


-- ---------------------------------------------------------------- section 4
tests['[4] the pin frame: shipped pokes a 0.62-health Lion, armed declines'] = function()
    local J, bot = rf.load(PIN, 'npc_dota_hero_crystal_maiden')
    assert(bot ~= nil and bot:IsAlive(), 'the pin frame no longer carries a live CM')

    -- The frame's own numbers, so the header's prose cannot drift off them.
    local nMana, nMax = bot:GetMana(), bot:GetMaxMana()
    assert(math.abs(nMana - 543) < 1.5 and math.abs(nMax - 831) < 1.5, string.format(
        'the pin frame reads %.0f/%.0f mana; the header says 543/831.', nMana, nMax))
    assert(nMana / nMax <= RATIO_TERM, string.format(
        'the pin frame is at %.2f mana, which is ABOVE the %s ratio term -- the '
        .. 'header\'s claim that the flat 440 is the disjunct doing the work no '
        .. 'longer holds on this frame.', nMana / nMax, RATIO_TERM))
    assert(nMana > KEEP_MANA * 2, 'the pin frame no longer satisfies the 440 disjunct')

    local ab = bot:GetAbilityByName('crystal_maiden_crystal_nova')
    assert(ab ~= nil and ab:IsFullyCastable(), 'Crystal Nova is not castable on the pin frame')

    -- The subject the branch aims at, and the fact that it is NOT a kill.
    -- The ring is the BRANCH's ring, term for term (hero_crystal_maiden.lua
    -- X.ConsiderQ: `abilityQ:GetCastRange() + aetherRange + 32`).  The aether
    -- term is read per-frame rather than assumed away: it is 0 on every one of
    -- the 70 live-CM frames this corpus holds today (none carries the item),
    -- but BOTH of this hero's buy lists buy item_aether_lens, so a census that
    -- spells the ring `GetCastRange() + 32` is a reading that silently
    -- under-states itself the day a late-game CM frame lands.  That is not
    -- hypothetical: the same drop on hero_lion.lua read a legal 861.99u cast as
    -- "outside 670" (GH #725), because 9 of 42 live Lions DO carry one.
    local nCastRange = ab:GetCastRange() + aether_bonus(J) + 32
    local nRadius = ab:GetSpecialValueInt('radius')
    local bonus = J.GetNearbyHeroes(bot, nCastRange + nRadius + 150, true, BOT_MODE_NONE)
    assert(#bonus == 3, string.format('the pin frame should hold 3 enemies in the bonus ring, holds %d', #bonus))
    local nearest = bonus[1]
    assert(nearest:GetUnitName() == 'npc_dota_hero_lion', string.format(
        'the pin frame\'s nearest bonus-ring enemy is %s, not lion', nearest:GetUnitName()))
    local ratio = nearest:GetHealth() / nearest:GetMaxHealth()
    assert(ratio > QUALITY_BAR, string.format(
        'the pinned target now sits at %.2f health, at or under the %s bar -- '
        .. 'armed would ALLOW this cast and the pin no longer demonstrates the '
        .. 'lever.', ratio, QUALITY_BAR))

    assert(drive(PIN, false) > 0, 'shipped no longer orders a Nova on the pin frame')
    assert(drive(PIN, true) == 0, 'armed still orders a Nova on the pin frame')
end


-- ---------------------------------------------------------------- section 5
tests['[5] the funnel, and which disjunct actually decides it'] = function()
    local alive, castable, surplus, ratio_only, abs_only = 0, 0, 0, 0, 0
    for _, path in ipairs(frame_paths()) do
        pcall(function()
            local J, bot = rf.load(path, 'npc_dota_hero_crystal_maiden')
            if bot == nil or not bot:IsAlive() then return end
            alive = alive + 1
            local ab = bot:GetAbilityByName('crystal_maiden_crystal_nova')
            if ab == nil or not ab:IsFullyCastable() then return end
            castable = castable + 1
            local bRatio = bot:GetMana() / bot:GetMaxMana() > RATIO_TERM
            local bAbs   = bot:GetMana() > KEEP_MANA * 2
            if bRatio or bAbs then surplus = surplus + 1 end
            if bRatio and not bAbs then ratio_only = ratio_only + 1 end
            if bAbs and not bRatio then abs_only = abs_only + 1 end
        end)
    end

    -- Floors, not equalities: adding frames must not silently retire this
    -- reading, but a parser that stops matching must go red.
    assert(alive >= 53, string.format('CM-alive instants fell to %d (was 53)', alive))
    assert(castable >= 28, string.format('Nova-castable instants fell to %d (was 28)', castable))
    assert(surplus >= 18, string.format('wallet-true instants fell to %d (was 18)', surplus))

    -- ⭐ The reading the header rides.  The ratio term deciding ALONE is the
    -- thing measured to be absent; if it ever appears, the header's "the rule
    -- that actually runs is mana > 440" is no longer true and must be rewritten
    -- rather than re-pinned.
    assert(ratio_only == 0, string.format(
        'the `nMP > %s` term now decides %d instant(s) BY ITSELF.  The helper\'s '
        .. 'header says it decides none, i.e. that the flat %d is the rule that '
        .. 'actually runs.  Rewrite that paragraph with the new reading.',
        RATIO_TERM, ratio_only, KEEP_MANA * 2))
    assert(abs_only >= 6, string.format(
        'instants carried by the absolute term ALONE fell to %d (was 6)', abs_only))
end

-- ---------------------------------------------------------------- section 6
-- The degenerate read, asserted directly on the helper because the corpus
-- CANNOT drive it: every frame's target answers a real GetMaxHealth, so the
-- fallback branch is unreachable from a fixture.  It survived the first run of
-- tools/agent/mutstand_cmqpoke.sh (M8) for exactly that reason.
--
-- WHY THE FALLBACK POINTS THE WAY IT DOES.  A getter that silently answers 0 is
-- how `zusboltcap` (GH #175) turned a health filter into "is anyone there".
-- Here a degenerate read that DECLINED would stop Crystal Nova on this path
-- entirely -- a silent regression in the OPPOSITE direction to the one this
-- lever is about, which no in-domain counter would ever report.  So an
-- unreadable capacity defers to the shipped answer.
tests['[6] an unreadable capacity DEFERS to the shipped answer, never declines'] = function()
    local J = rf.load(PIN, 'npc_dota_hero_crystal_maiden')
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('crystal_maiden')

    local realIsValid = J.IsValid
    local stub = {}
    J.IsValid = function(u, ...) if u == stub then return true end return realIsValid(u, ...) end

    local function health(now, max)
        stub.GetHealth = function() return now end
        stub.GetMaxHealth = function() return max end
    end

    -- shipped false is returned unchanged, whatever the target says.
    health(1, 1000)
    assert(X.cm_ShouldSpendSurplusNova(stub, false) == false,
        'a shipped FALSE came back TRUE -- the armed leg can now ADD a cast')

    for _, bad in ipairs({ 0, -1, 'x' }) do
        health(0, bad)
        assert(X.cm_ShouldSpendSurplusNova(stub, true) == true, string.format(
            'with GetMaxHealth answering %s the armed leg must DEFER to the '
            .. 'shipped answer.  Declining there would mute Crystal Nova on '
            .. 'this path for a reason no counter reports (GH #175 family).',
            tostring(bad)))
    end
    health(0, nil)
    assert(X.cm_ShouldSpendSurplusNova(stub, true) == true,
        'with GetMaxHealth answering nil the armed leg must DEFER to the '
        .. 'shipped answer')

    -- A readable capacity is answered on its merits, both ways.
    health(900, 1000)
    assert(X.cm_ShouldSpendSurplusNova(stub, true) == false,
        'a 0.90-health target is still admitted by the armed leg')
    health(100, 1000)
    assert(X.cm_ShouldSpendSurplusNova(stub, true) == true,
        'a 0.10-health target is refused by the armed leg')

    J.IsValid = realIsValid
end


return tests
