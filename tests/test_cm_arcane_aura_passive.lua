-- [hero] GH #177 -- Crystal Maiden's dispatch chain opens by ordering a cast on
-- an ability the game declares PASSIVE.  Behaviour change, so it ships GATED
-- ('cmaurapassive', turbo-only).  Axis `CASTSHAPE`.
--
-- WHAT THE AXIS ASKS
--
-- The last five triggers all asked what a NUMBER was worth: a constant against
-- the KV (`zusstatic`), a key Valve renamed (#162), a slot index pointing at the
-- other half of a talent row (#166), a table with no role dimension (#170), an
-- API call reading a field nobody declares any more (#175).  This one asks a
-- different question about the same files:
--
--     the file decided to cast.  Can the engine accept the ORDER it wrote?
--
-- `bot:Action*_UseAbility( h )`, `...OnEntity( h, u )` and `...OnLocation( h, v )`
-- are three different orders.  Which of them an ability accepts is fixed by its
-- `AbilityBehavior` flags, and `DOTA_ABILITY_BEHAVIOR_PASSIVE` accepts none of
-- them, ever.  A wrong-shaped order does not raise: bot-side there is no way to
-- see it at all (AGENTS.md -- `print()` never reaches the server console and the
-- engine error handler is broken).  It simply does not happen.
--
-- WHAT WAS FOUND
--
-- hero_crystal_maiden.lua binds `ArcaneAura` to the string literal
-- 'crystal_maiden_brilliance_aura' and X.SkillsComplement's FIRST branch is
--
--     ArcaneAuraDesire = X.ConsiderArcaneAura()
--     if ( ArcaneAuraDesire > 0 ) then ... bot:ActionQueue_UseAbility( ArcaneAura ); return end
--
-- while that ability's KV block is, in full, one flag:
--
--     "crystal_maiden_brilliance_aura" { "AbilityBehavior" "DOTA_ABILITY_BEHAVIOR_PASSIVE" ... }
--
-- HOW BIG THE AXIS IS (tools/agent/cast_shape_census.py, new this trigger)
--
-- 755 cast orders in bots/BotLib/hero_*.lua, 493 of them resolvable to a literal
-- ability name.  11 of those name a PASSIVE ability, spread over 10 files -- and
-- exactly ONE is in the focus five: this site.  (22 more are SHAPE-MISMATCH, a
-- deliberately weaker class -- ALT_CASTABLE/AUTOCAST/facet overrides make flags
-- alone a list of questions there, not a list of defects.  Filed in GH #177 §2,
-- not touched here.)
--
-- ONE-DIRECTIONAL, same as #162's key census and for the same reason: a handle
-- bound through sAbilityList[N] or a talent list is UNRESOLVED and proves
-- nothing.  262 of the 755 are exactly that -- including twelve of the focus
-- five's fifteen cast orders, so the "exactly one" above is a floor, not a
-- clean bill of health.  Only skeleton_king and crystal_maiden bind by literal
-- at all; axe, zuus and lion are invisible to this census by construction.
--
-- WHAT IT COSTS TODAY IS ZERO, AND THAT IS THE WHOLE POINT
--
-- The branch is dead UPSTREAM of the order: `J.CanCastAbility` rejects on
-- `ability:IsPassive()` before it ever gets there.  So the reading rests on ONE
-- engine predicate that cannot be read from here -- and §4 MEASURES that it
-- cannot: on a real CM frame the mock answers `IsPassive() == false` and
-- `GetBehavior() == 0`, so offline the shipped predicate does NOT reject and the
-- branch is not dead in the fixture world at all.
--
-- The cost of that predicate being false in the engine is not one wasted cast.
-- This branch runs FIRST and `return`s, so a nonzero desire eats Crystal Nova,
-- Frostbite, Crystal Clone AND Freezing Field for that tick -- every tick CM is
-- going on someone within 500 units.  A silent dependency with that blast radius
-- is worth converting into a fact.
--
-- THE SHAPE OF THE CHANGE (why gate-off equivalence is structural)
--
-- X.IsArcaneAuraCastable runs the shipped predicate FIRST and returns false on
-- it; `return false` is the only thing the armed path can add.  Gate-off is
-- therefore the shipped expression by construction, not by measurement -- the
-- same shape as `lionhexaoe` (GH #166) and the dual of GH #154's widening.
-- Direction is single: armed can only ever REFUSE a cast shipped allowed.
--
-- A behavior mask of 0, or a VM without the constant, means "could not read it"
-- -> answer false, let shipped stand.  Inventing a default there is the mistake
-- GH #162 wrote down: a silent zero is not a value.
--
-- WHAT THIS FILE DOES NOT CLAIM
--
--   * That the engine's `IsPassive()` really is true here.  It is not readable
--     offline (§4) and that is precisely why the gate exists.
--   * That arming this WINS games.  Locally-correct is not emergently-good
--     (AGENTS.md, the lanefix lesson).  Condition (a) is queue hero-17.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local CM       = 'bots/BotLib/hero_crystal_maiden.lua'
local WK       = 'bots/BotLib/hero_skeleton_king.lua'
local SNAPSHOT = 'tests/mock/ability_behavior.lua'
local FRAME    = 'tests/fixtures/f_260820_102645_cm_laning_release.lua'

local CAND_ID = 'cmaurapassive'
local AURA    = 'crystal_maiden_brilliance_aura'

local FOCUS = { 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua comments BEFORE anything is counted.  The block above quotes the
--- call names and the candidate id while explaining them, and a parser that
--- reads prose reports the prose (GH #136).  Long-bracket blocks go first and
--- whole: dropping only the `--[[` opener leaves the BODY looking like code.
local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', '')
    return (src:gsub('%-%-[^\n]*', ''))
end

--- An ability handle whose behavior mask is `nBehavior` and whose IsPassive()
--- answers `bPassive`.  Two knobs because the point of this change is that the
--- two can disagree -- the engine has both, the fixture world has neither.
local function make_aura(nBehavior, bPassive)
    return api.MakeUnit{
        GetName = AURA,
        GetBehavior = nBehavior,
        IsPassive = bPassive and true or false,
        IsNull = false, IsHidden = false, IsTrained = true,
        IsFullyCastable = true, IsActivated = true,
    }
end

--- Load CM on the real frame, set the mode and the gate, return (X, J, bot).
--- GetGameMode is set BEFORE the hero file loads because J.IsModeTurbo memoises
--- its answer on the first call.
local function load_cm(bArmed, bTurbo)
    local J, bot = rf.load(FRAME)

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(sId) return sId == CAND_ID end
        or function() return false end

    return rf.load_hero('crystal_maiden'), J, bot
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The source shape: a ratchet on where the shipped predicate may live.

tests['[hero] ConsiderArcaneAura asks the helper and nothing else'] = function()
    local src = strip_comments(read_file(CM))

    local sBody = src:match('function X%.ConsiderArcaneAura%(%)(.-)\nend\n')
    assert(sBody, 'X.ConsiderArcaneAura not found')
    assert(sBody:find('X.IsArcaneAuraCastable()', 1, true),
        'the castability question must go through the helper')
    assert(not sBody:find('J.CanCastAbility', 1, true),
        'and the raw predicate must not survive inside it -- that would be an ungated site')
end

tests['[hero] the helper is gated, turbo-only, and OPENS on the shipped predicate'] = function()
    local src = strip_comments(read_file(CM))

    local sHelper = src:match('function X%.IsArcaneAuraCastable%b()(.-)\nend')
    assert(sHelper, 'X.IsArcaneAuraCastable is gone; the call site would be ungated')
    assert(sHelper:find("IsSoakCandidate( '" .. CAND_ID .. "' )", 1, true),
        'the refusal must sit behind IsSoakCandidate(' .. CAND_ID .. ')')
    assert(sHelper:find('IsModeTurbo', 1, true),
        'and behind IsModeTurbo (turbo-only, AGENTS.md)')

    -- Structural gate-off: the shipped predicate is the FIRST statement and it
    -- returns false on its own.  Everything after it can only ever subtract.
    local sFirst = sHelper:match('^%s*(.-)\n')
    assert(sFirst and sFirst:find('if not J.CanCastAbility( ArcaneAura ) then return false end', 1, true),
        'the helper must OPEN on the shipped predicate, got ' .. tostring(sFirst))

    -- Direction is single: the armed leg has exactly one outcome, `false`.
    local nTrue = select(2, sHelper:gsub('return true', ''))
    assert(nTrue == 1, 'exactly one `return true` (the tail) -- an armed-only true '
        .. 'would make this a widening riding a tightening\'s gate (GH #166), got ' .. nTrue)
end

tests['[hero] the behavior read never invents a default'] = function()
    local src = strip_comments(read_file(CM))
    local sHelper = src:match('function X%.HasPassiveBehavior%b()(.-)\nend')
    assert(sHelper, 'X.HasPassiveBehavior is gone')
    -- Two fall-backs, one for the constant and one for the mask.  Counted, not
    -- named: pinning the LOCAL's spelling would make a pure rename fail a test
    -- about behaviour, which is a ratchet that costs a later reader a false
    -- alarm (it caught the control mutation of this file's own scan).
    local nGuards = select(2, sHelper:gsub('<= 0 then return false end', ''))
    assert(nGuards == 2,
        'an unreadable constant AND an unreadable mask must both fall back to shipped '
        .. '(the GH #162 house rule), not to a hardcoded flag value; got ' .. nGuards)
end

-- ---------------------------------------------------------------------------
-- 2. The helper's behaviour, on fabricated handles.
--    Fabricated by necessity: §4 measures that no frame carries a behavior mask.

--- Load CM on the real frame and hand its file-local ArcaneAura handle the two
--- readings the engine has and the frame does not (§4 measures both absences):
---   * IsActivated, a mock default that otherwise rejects before passivity is
---     ever consulted -- lifting it is what puts the shipped predicate in the
---     state this fix is about;
---   * the behavior mask, which the dumper does not network at all.
--- `__spec` is the fixture's own mutation idiom (replay_fixture.lua:261), and
--- the handle is memoised per name, so this reaches the file-local binding.
local function load_cm_masked(bArmed, bTurbo, nMask)
    local X, J, bot = load_cm(bArmed, bTurbo)
    local h = assert(bot:GetAbilityByName(AURA), 'the frame must carry the aura')
    local sp = rawget(h, '__spec')
    sp.IsActivated = true
    sp.GetBehavior = nMask
    return X, J, bot, h
end

tests['gate off: the answer is the shipped predicate, whatever the mask says'] = function()
    local X = load_cm_masked(false, true, DOTA_ABILITY_BEHAVIOR_PASSIVE)
    assert(X.IsArcaneAuraCastable ~= nil, 'helper not exported')
    assert(X.IsArcaneAuraCastable() == true,
        'gate off must be byte-for-byte the shipped predicate -- which, with the mock '
        .. 'default lifted, says CASTABLE even on a mask that carries PASSIVE')
end

tests['gate on: the same frame, the same mask, and now it is refused'] = function()
    local X = load_cm_masked(true, true, DOTA_ABILITY_BEHAVIOR_PASSIVE)
    assert(X.IsArcaneAuraCastable() == false,
        'armed, a PASSIVE mask must refuse the cast the shipped predicate allowed')
end

tests['gate on: a mask WITHOUT the passive bit is not refused'] = function()
    -- ⚠ The mask has to be built by CLEARING the passive bits, not by naming
    -- another flag.  Measured the hard way: tests/mock/bot_api.lua hands every
    -- unknown ALL_CAPS global a sequential integer (1001, 1002, ...), so the
    -- mock's DOTA_ABILITY_BEHAVIOR_* are NOT disjoint powers of two the way the
    -- engine's are -- `band(NO_TARGET, PASSIVE) == PASSIVE` came out TRUE, and
    -- the test failed while the code under test was correct.  Same family as
    -- the world assertions (#133/#145): a mock default that quietly states a
    -- fact about the world nobody declared.
    local nActive = bit.band(0xFFFFFFFF, bit.bnot(DOTA_ABILITY_BEHAVIOR_PASSIVE))
    local X = load_cm_masked(true, true, nActive)
    assert(X.IsArcaneAuraCastable() == true,
        'the narrowing must key on the PASSIVE bit and nothing else -- an active '
        .. 'ability (a future patch, a facet override) must pass straight through')
end

tests['gate on: an unreadable mask falls back to shipped, it never invents a default'] = function()
    local X = load_cm_masked(true, true, 0)
    assert(X.IsArcaneAuraCastable() == true,
        'a 0 mask is "could not read", not "passive" -- acting on a silent zero is the '
        .. 'mistake GH #162 wrote down')
end

tests['turbo-only: armed outside turbo is the shipped predicate'] = function()
    local X = load_cm_masked(true, false, DOTA_ABILITY_BEHAVIOR_PASSIVE)
    assert(X.IsArcaneAuraCastable() == true,
        'AGENTS.md: a soak candidate is inert outside turbo')
end

tests['the mask reader: PASSIVE bit set vs clear vs unreadable'] = function()
    local X = load_cm(true, true)
    assert(X.HasPassiveBehavior(make_aura(DOTA_ABILITY_BEHAVIOR_PASSIVE, false)) == true,
        'PASSIVE set -> true')
    assert(X.HasPassiveBehavior(make_aura(0, true)) == false,
        'a 0 mask is "could not read", not "not passive" and not "passive" -- it must '
        .. 'fall back to shipped rather than act on a silent zero')
    assert(X.HasPassiveBehavior(make_aura(-1, false)) == false, 'and so must a negative mask')
    assert(X.HasPassiveBehavior(nil) == false, 'and a nil handle')
end

tests['the gate reads turbo AND the candidate on one branch, in that order'] = function()
    local src = strip_comments(read_file(CM))
    local sHelper = src:match('function X%.IsArcaneAuraCastable%b()(.-)\nend')
    assert(sHelper:find('J.IsModeTurbo() and J.IsSoakCandidate', 1, true),
        'turbo and the candidate must guard the SAME branch, in that order')

    -- The mask reader itself is mode-blind and gate-blind on purpose: it is a
    -- fact about an ability, and only the helper decides what to do with it.
    local X = load_cm(true, false)
    assert(X.HasPassiveBehavior(make_aura(DOTA_ABILITY_BEHAVIOR_PASSIVE, false)) == true)
end

-- ---------------------------------------------------------------------------
-- 3. The census the reading rests on -- so a patch breaks this file loudly.

tests['[hero] Brilliance Aura is PASSIVE in the frozen KV snapshot'] = function()
    api.install({})
    local tBehavior = assert(dofile(SNAPSHOT).BEHAVIOR, 'no AbilityBehavior snapshot')

    local tCM = assert(tBehavior['crystal_maiden'], 'crystal_maiden absent from the snapshot')
    assert(tCM[AURA] == 'DOTA_ABILITY_BEHAVIOR_PASSIVE',
        'Brilliance Aura must be declared PASSIVE and nothing else -- if a patch gives it '
        .. 'an active behavior, this whole reading needs redoing, got ' .. tostring(tCM[AURA]))

    -- Corroboration inside the same snapshot, so the assertion above is not a
    -- fetch that half-succeeded and wrote a table with one lucky row.
    local tWK = assert(tBehavior['skeleton_king'], 'expected skeleton_king in the snapshot')
    assert(tWK['skeleton_king_hellfire_blast'] == 'DOTA_ABILITY_BEHAVIOR_UNIT_TARGET',
        'and Wraithfire Blast is the unit-target one')
end

tests['[hero] exactly one PASSIVE dispatch in the focus five, and it is this one'] = function()
    api.install({})
    local tBehavior = assert(dofile(SNAPSHOT).BEHAVIOR)

    local tPassive = {}
    for _, sHero in ipairs(FOCUS) do
        for sName, sBeh in pairs(tBehavior[sHero] or {}) do
            if sBeh:find('DOTA_ABILITY_BEHAVIOR_PASSIVE', 1, true) then
                table.insert(tPassive, sHero .. '/' .. sName)
            end
        end
    end
    assert(#tPassive == 1 and tPassive[1] == 'crystal_maiden/' .. AURA,
        'expected exactly one PASSIVE-dispatched ability across the focus five, got '
        .. table.concat(tPassive, ', '))

    -- And the honest floor: three of the focus five bind every cast handle
    -- through sAbilityList[N], so this census cannot see them AT ALL.  If one of
    -- them ever grows a literal binding, that is new ground and this count moves.
    for _, sHero in ipairs({ 'axe', 'zuus', 'lion' }) do
        assert(tBehavior[sHero] == nil,
            sHero .. ' now has a literal-bound cast handle; the "exactly one" above is a '
            .. 'floor over literal bindings only and must be re-derived')
    end
end

tests['[hero] the whole snapshot still holds 11 PASSIVE-dispatched abilities'] = function()
    api.install({})
    local tBehavior = assert(dofile(SNAPSHOT).BEHAVIOR)

    local nPassive, nTotal = 0, 0
    for _, tHero in pairs(tBehavior) do
        for _, sBeh in pairs(tHero) do
            nTotal = nTotal + 1
            if sBeh:find('DOTA_ABILITY_BEHAVIOR_PASSIVE', 1, true) then
                nPassive = nPassive + 1
            end
        end
    end
    assert(nTotal == 403, 'expected 403 literal-bound cast targets, got ' .. nTotal)
    assert(nPassive == 11, 'expected 11 PASSIVE ones (GH #177 §1), got ' .. nPassive)
end

tests['[hero] the other ten PASSIVE sites are filed, not fixed'] = function()
    -- A ratchet, not an endorsement.  They are nine other heroes' files and none
    -- is in the focus pool; whoever picks one up owns its own id and its own
    -- evidence.  What must not happen is one of them being routed through THIS
    -- helper, which is CM's and reads CM's file-local handle.
    local nCM = select(2, strip_comments(read_file(CM)):gsub('IsArcaneAuraCastable', ''))
    assert(nCM == 2, 'expected the definition plus exactly one call of '
        .. 'X.IsArcaneAuraCastable in ' .. CM .. ', got ' .. nCM)

    -- WK is the only other focus hero with a literal-bound cast, and both of its
    -- orders are shape-legal.  Pinned so a rename over there is not silent.
    local sWK = strip_comments(read_file(WK))
    assert(sWK:find("bot:GetAbilityByName('skeleton_king_bone_guard')", 1, true),
        'WK still binds Bone Guard by literal (the census depends on it)')
end

-- ---------------------------------------------------------------------------
-- 4. LIMITS -- measured on the real frame, not asserted.

tests['LIMIT: a real frame carries no behavior mask, so the shipped predicate does NOT reject'] = function()
    local _, J, bot = load_cm(false, true)
    local h = bot:GetAbilityByName(AURA)
    assert(h ~= nil, 'the frame must carry a Brilliance Aura handle')

    -- This is the measurement that justifies the gate.  The dumper does not
    -- network AbilityBehavior (same class as GH #36's "is this the ultimate"
    -- and GH #151's innate naming), so:
    assert(h:GetBehavior() == 0,
        'the mask reads 0 offline -- so the ARMED leg cannot fire on a frame either, '
        .. 'by its own do-not-invent-a-default rule')
    assert(h:IsPassive() == false,
        'and IsPassive() -- the ONE predicate the whole "this branch is already dead" '
        .. 'reading rests on -- reads FALSE on a real frame.  Whether it is true in the '
        .. 'engine is exactly the thing no local test can settle')

    -- The shipped predicate DOES reject offline, and this is the part worth
    -- writing down: it rejects for a reason that has nothing to do with
    -- passivity.  IsActivated() is a mock default (GH #133/#145 family), so the
    -- offline "dead" and the claimed engine-side "dead" agree by COINCIDENCE.
    -- That agreement must never be cited as confirmation -- the same warning
    -- GH #175 attached to its own two legs.
    assert(J.CanCastAbility(h) == false, 'castable reads false offline')
    assert(h:IsActivated() == false,
        'and IsActivated() is what makes it false -- not IsPassive()')

    local bWasActivated = false
    h.IsActivated = function() return true end
    bWasActivated = J.CanCastAbility(h)
    assert(bWasActivated == true,
        'with the mock-default clause lifted the shipped predicate says CASTABLE: '
        .. 'passivity is not what stops it here.  So the firing side of this fix '
        .. 'cannot be settled offline and has to be bought from the corpus, queue hero-17')
end

tests['LIMIT: injecting the KV mask is what makes the armed leg decidable at all'] = function()
    local X, _, bot = load_cm(true, true)
    local h = bot:GetAbilityByName(AURA)

    assert(X.HasPassiveBehavior(h) == false, 'unaugmented frame: unreadable mask -> false')

    -- Supply the pair the engine has: the frame's handle plus the KV's mask.
    -- Doing this inside replay_fixture.lua (so every fixture carries behavior,
    -- the way tests/mock/ability_meta.lua carries the ultimate flag) is the
    -- next step and is filed in GH #177, not done here.
    api.install({})
    local tBehavior = assert(dofile(SNAPSHOT).BEHAVIOR)
    assert(tBehavior['crystal_maiden'][AURA]:find('PASSIVE', 1, true))
    h.GetBehavior = function() return DOTA_ABILITY_BEHAVIOR_PASSIVE end
    assert(X.HasPassiveBehavior(h) == true,
        'with the KV mask in place the armed leg decides -- and it decides REFUSE')
end

return tests
