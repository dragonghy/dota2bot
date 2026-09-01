-- [ratchet] [tormself] hero_ringmaster.lua:915 opens a two-way disjunction --
-- "am I doing Roshan, or am I doing Tormentor?" -- and then discriminates the
-- two ways on the wrong object for one of them. The Roshan arm asks
-- `J.IsRoshan(botTarget)`. The Tormentor arm asks `J.IsTormentor(bot)`.
--
-- J.IsTormentor (jmz_func.lua:10638) is a pure unit-IDENTITY predicate:
-- `string.find(nTarget:GetUnitName(), 'miniboss') ~= nil`. Our own hero is
-- npc_dota_hero_ringmaster. So that arm is not rarely true, it is FALSE BY
-- CONSTRUCTION, and the whole Tormentor half of the outer disjunction cannot
-- reach the body: while the bot is in BOT_MODE_SIDE_SHOP hitting the Tormentor,
-- `J.IsRoshan(botTarget)` is false too (the target is a miniboss, not Roshan).
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     A predicate whose domain is ANOTHER unit, fed `self`, is a type error
--     that the language cannot catch and the runtime will not report -- because
--     `bot` and `botTarget` are the same duck type (a unit handle) and the
--     predicate is TOTAL: on self it does not raise, it just answers false,
--     forever. The failure direction is OFF, and it is silent in the strongest
--     sense available: there is no frame, no game and no replay on which the
--     wrong answer differs from a correct `false`, because the correct answer
--     for `self` IS false. Only the CALL SITE knows the question was meant for
--     somebody else.
--     The tell is countable and needs no frame: take an identity predicate,
--     enumerate its call sites, and look at what each one is FED. Measured
--     code-only over bots/, excluding the dead file: 249 live J.IsTormentor call
--     sites, 227 of them (90.8%) fed `botTarget`, the rest fed some other unit
--     handle, and EXACTLY ONE fed `bot`. That one is not a variant, it is the
--     bug -- and the deviating file gets it right four other times in itself
--     (lines 436, 622, 846, 965).
--     Sharper still, an identity predicate splits its own call sites into two
--     populations by ARITY OF INTENT, and only the target population can ever
--     be true; `IsMeepoClone(bot)` is the legitimate self-fed case (a Meepo bot
--     really can be a clone) and that is exactly why "self-fed" alone is not
--     the rule. The rule is: self-fed AND unsatisfiable-by-self.
--
--     Distinguish from the same-family findings before it. GH #348 is a
--     MISSPELLING (`.cout`) -- an identifier that does not exist. GH #368 is
--     LEXICAL SCOPE -- the right name bound to the wrong variable. GH #370 is
--     an UNREPORTED SIDE EFFECT. GH #373 is a latch recording the ATTEMPT
--     instead of the POSTCONDITION. GH #378 is a throttle whose SCOPE exceeds
--     what it throttles. GH #381 is a hand-maintained FIELD duplicating an
--     engine fact. Here every identifier exists, is spelled correctly, is in
--     scope, holds no state and is never stale. The function called is the
--     right function. The defect is entirely in WHICH OBJECT it is asked about.
--
-- ⭐⭐ WHY THIS IS A DEFECT AND NOT A DESIGN CHOICE, from the same line. The
-- outer gate is a 2-way disjunction over `bot`'s mode; the inner condition is
-- the discriminator over the target for those same 2 ways. Read the inner arm
-- as written and it is a mode test spelled as an identity test -- but
-- `J.IsDoingTormentor(bot)` (the mode test that WOULD be meaningful on `bot`)
-- is already the outer gate's second arm, so on that reading the inner arm is
-- a tautology and the author wrote a redundant re-check next to a real one.
-- Either reading makes it wrong; only the target reading makes it useful, and
-- the target reading is what the other 227 `botTarget` call sites do.
--
-- ⭐⭐⭐ WHY NOBODY NOTICED. There are two more copies of this exact expression
-- in the tree -- aba_hero_sub_units.lua:370 and the commented-out block at
-- minion_lib/familiars.lua:358 -- so it is a copy-paste lineage, not a
-- one-off slip. But `aba_hero_sub_units.lua` is required by NOTHING (pinned by
-- [source S4] below): it is the legacy file that minion_lib/ replaced. So the
-- lineage is two-thirds dead code, and a reader who greps the phrase finds it
-- mostly in files that cannot run -- which makes the one live copy look like
-- more of the same dead thing.
--
-- REAL FRAME: tests/fixtures/f_20260828_004757_venomancer_785.lua -- subject
-- alive at 1219/1219, t=785.4 (13:05), a full 10-hero roster with real names.
--
-- ⚠️ LIMITS, declared:
--   * NO FIXTURE IN THE CORPUS CONTAINS A RINGMASTER, and none contains a
--     miniboss -- the dumper emits heroes and buildings only. So [frame F2]'s
--     Tormentor handle is an INJECTION, byte-identical across both arms, and
--     the claim under test ("which object does the guard ask about") is a
--     property of the file, not of the frame. Same UNMEASURABLE-is-not-EMPTY
--     distinction as GH #368/#373/#378/#381.
--   * THE SUBJECT IS A VENOMANCER, NOT A RINGMASTER, and that is deliberate,
--     not a compromise: the shipped arm is false for EVERY hero name, which is
--     the whole finding, and [frame F0] measures exactly that over the entire
--     corpus rather than asserting it for one hero.
--   * FREQUENCY IS UNKNOWN AND IS THE CEILING ON THIS FIX'S VALUE. Ringmaster
--     is not a focus hero, and the branch additionally needs
--     BOT_MODE_SIDE_SHOP + Funhouse Mirror off cooldown + the Tormentor inside
--     900u + the bot mid-attack. Nothing here prices that; 录像组 does.
--   * WHAT THIS FIX DOES NOT CLAIM: that using Funhouse Mirror on a Tormentor
--     is worth points. It makes an already-shipped, already-written arm
--     reachable for the situation it was written for. Conditions (b)/(c) are
--     not this file's business.
--
-- DECLARED WORLD SLOTS (identical in both arms):
--   S-A  bot:GetActiveMode() = BOT_MODE_SIDE_SHOP -- what J.IsDoingTormentor
--        reads. Not in the dump.
--   S-B  bot:GetAnimActivity() = ACTIVITY_ATTACK, plus GetAttackPoint() >
--        GetAnimCycle()*0.99 -- BOTH halves of what J.IsAttacking reads
--        (jmz_func.lua:3305-3320). The mock defaults the second pair to 0/0,
--        which makes `0 > 0` false, so declaring only the activity would have
--        left J.IsAttacking false and F1 would have "passed" for the wrong
--        reason -- the guard shut on the last conjunct instead of on the arm
--        under test. Not in the dump.
--   S-C  the Tormentor handle and bot:GetTarget() returning it (see LIMITS).
--        Placed 300u from the subject's REAL frame location, so the 900u range
--        term is computed against real coordinates.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_20260828_004757_venomancer_785.lua'
local TARGET  = 'bots/BotLib/hero_ringmaster.lua'
local DEAD    = 'bots/FunLib/aba_hero_sub_units.lua'

local CONST = {
    BOT_ACTION_DESIRE_NONE = 0.0,
    BOT_ACTION_DESIRE_HIGH = 0.75,
    BOT_MODE_SIDE_SHOP     = 21,
    BOT_MODE_ROSHAN        = 20,
    ACTIVITY_ATTACK        = 1500,
}

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Blank whole-line comments while PRESERVING line numbers, so every count
--- below means "in code". This file's fix comment in hero_ringmaster.lua names
--- `J.IsTormentor(bot)` and `IsTormentorSubject` several times; without this the
--- census would be counting its own explanation. GH #370 hit exactly that.
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local function count(hay, needle)
    local n, i = 0, 1
    while true do
        local s, e = hay:find(needle, i, true)
        if not s then return n end
        n, i = n + 1, e + 1
    end
end

local function lineOf(src, needle)
    local n = 1
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        if line:find(needle, 1, true) then return n end
        n = n + 1
    end
    return nil
end

local function luaFiles(dir)
    local files = {}
    local p = assert(io.popen("find " .. dir .. " -name '*.lua' | sort"))
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    return files
end

-- ---------------------------------------------------------------------------
-- [source] -- the shipped tree
-- ---------------------------------------------------------------------------

tests['[source S1] the gate is a single expression and it lives in the accessor'] = function()
    local src = codeOnly(read(TARGET))
    assert(count(src, "IsSoakCandidate('tormself')") == 1,
        "exactly one 'tormself' gate expression in this file -- a second one would "
        .. 'be a way to reach the fix without the accessor')

    local body = src:match('local function IsTormentorSubject%(%)(.-)\nend')
    assert(body ~= nil, 'IsTormentorSubject must exist as a file-local function')
    assert(body:find("IsSoakCandidate('tormself')", 1, true) ~= nil,
        'the one gate expression must sit INSIDE IsTormentorSubject')
    assert(body:find('J.IsModeTurbo()', 1, true) ~= nil,
        'turbo-only, per the stream charter')
    assert(body:find('J.IsTormentor(botTarget)', 1, true) ~= nil,
        'the armed arm must ask about the TARGET')
    assert(body:find('J.IsTormentor(bot)', 1, true) ~= nil,
        'the shut arm must reproduce the shipped expression VERBATIM, or this is '
        .. 'not a no-op default')
end

tests['[source S2] the accessor is defined BELOW `local botTarget` (GH #368)'] = function()
    local src = codeOnly(read(TARGET))
    local decl     = lineOf(src, 'local botTarget')
    local writer   = lineOf(src, 'botTarget = J.GetProperTarget(bot)')
    local accessor = lineOf(src, 'local function IsTormentorSubject()')
    assert(decl and writer and accessor, 'all three landmarks must exist')

    -- The reader half.
    assert(accessor > decl,
        'an accessor defined above the declaration would close over a DIFFERENT, '
        .. 'forever-nil upvalue and read false forever -- the armed arm would then '
        .. 'be just as dead as the shut one. Declared at ' .. tostring(decl)
        .. ', accessor at ' .. tostring(accessor))

    -- The WRITER half, and it is not decoration. A mutation that moved the
    -- declaration down to just above the accessor kept `accessor > decl` true
    -- and still broke the fix: X.SkillsComplement then assigns a GLOBAL
    -- botTarget while the accessor reads the file-local, which is nil forever.
    -- The reader-side check alone did not catch it (the frame tests did). Both
    -- the writer and the reader have to sit below the one declaration.
    assert(writer > decl,
        'X.SkillsComplement must assign the SAME local the accessor reads; with the '
        .. 'declaration below it (' .. tostring(decl) .. ' vs writer ' .. tostring(writer)
        .. ') the assignment silently creates a global and the accessor reads nil')
end

tests['[source S3] the call site reads the accessor, not the self-fed predicate'] = function()
    local src = codeOnly(read(TARGET))
    assert(src:find('J.IsRoshan(botTarget) or IsTormentorSubject()', 1, true) ~= nil,
        'the guard must now discriminate both ways through the accessor')
    assert(src:find('J.IsRoshan(botTarget) or J.IsTormentor(bot)', 1, true) == nil,
        'and the self-fed spelling must be gone from the call site')
    assert(count(src, 'IsTormentorSubject()') == 2,
        'exactly two mentions: the definition and the one call site')
end

tests['[source S4] aba_hero_sub_units.lua is required by NOTHING'] = function()
    -- The claim the ⭐⭐⭐ paragraph rests on. If a future round wires this file
    -- back in, its copy of the bug (line 370) becomes live and this test is the
    -- thing that says so.
    local refs = 0
    for _, path in ipairs(luaFiles('bots')) do
        if path ~= DEAD then
            local src = codeOnly(read(path))
            if src:find('aba_hero_sub_units', 1, true) then refs = refs + 1 end
        end
    end
    assert(refs == 0,
        'aba_hero_sub_units.lua must stay unreferenced for the "two-thirds of the '
        .. 'lineage is dead code" reading to hold; found ' .. refs .. ' referrer(s)')
    assert(codeOnly(read(DEAD)):find('J.IsRoshan(bot)', 1, true) ~= nil,
        'and it must still carry its own copy of the same shape, so this test keeps '
        .. 'pointing at the lineage rather than at a file that changed underneath it')
end

tests['[source S5] CLASS RATCHET: no live identity predicate is fed `bot`'] = function()
    -- J.IsRoshan and J.IsTormentor are the two J.* predicates whose ENTIRE
    -- return value is a unit-name identity test for a name no hero can have.
    -- (J.IsMeepoClone is the third identity predicate and is deliberately NOT
    -- in this list: a Meepo bot really can be a clone, so self-fed is correct
    -- there. The rule is self-fed AND unsatisfiable-by-self.)
    local offenders = {}
    for _, path in ipairs(luaFiles('bots')) do
        if path ~= DEAD then                       -- unreferenced, see S4
            local n = 0
            for line in (codeOnly(read(path)) .. '\n'):gmatch('([^\n]*)\n') do
                n = n + 1
                for _, pat in ipairs({ 'J%.IsRoshan%(%s*bot%s*[,)]',
                                       'J%.IsTormentor%(%s*bot%s*[,)]' }) do
                    if line:find(pat) then
                        -- The shut arm of our own accessor is the one legitimate
                        -- self-fed site in the tree: it exists precisely to keep
                        -- the shipped default byte-identical.
                        if not (path == TARGET and line:find('return J.IsTormentor(bot)', 1, true)) then
                            offenders[#offenders + 1] = path .. ':' .. n .. '  ' .. line:gsub('^%s+', '')
                        end
                    end
                end
            end
        end
    end
    assert(#offenders == 0,
        'an identity predicate that no hero can satisfy is being asked about `bot`, '
        .. 'which makes its branch false by construction:\n  '
        .. table.concat(offenders, '\n  '))
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------

local function world(armed)
    local J, bot = rf.load(FIXTURE)
    for k, v in pairs(CONST) do _G[k] = v end

    J.IsSoakCandidate = function(id) return armed and id == 'tormself' end
    J.IsModeTurbo     = function() return true end

    local spec = rawget(bot, '__spec')
    spec.GetActiveMode       = function() return BOT_MODE_SIDE_SHOP end   -- S-A
    spec.GetActiveModeDesire = function() return 0.9 end
    spec.GetAnimActivity     = function() return ACTIVITY_ATTACK end      -- S-B
    spec.GetAttackPoint      = function() return 0.3 end                  -- S-B
    spec.GetAnimCycle        = function() return 0.1 end                  -- S-B

    -- S-D: the Souvenir itself. The subject is a venomancer, so the fixture
    -- carries no ringmaster_funhouse_mirror and the mock hands back an
    -- UNTRAINED stub -- which makes J.CanCastAbility false and bails
    -- X.ConsiderFunhouseMirror on its first line. Without this slot the shipped
    -- arm would read NONE for a reason that has nothing to do with the finding,
    -- and [frame F1] would pass while proving nothing. That is what [frame FC]
    -- below exists to keep honest.
    local base = spec.GetAbilityByName
    spec.GetAbilityByName = function(self, name)
        local h = base(self, name)
        if name == 'ringmaster_funhouse_mirror' and h then
            local hs = rawget(h, '__spec')
            hs.IsTrained        = function() return true end
            hs.IsFullyCastable  = function() return true end
            hs.IsActivated      = function() return true end
            hs.IsPassive        = function() return false end
            hs.IsHidden         = function() return false end
            hs.IsNull           = function() return false end
            hs.GetLevel         = function() return 1 end
        end
        return h
    end

    return J, bot, spec
end

--- S-C: the Tormentor. 300u from the subject's REAL location, so the 900u term
--- in the guard is computed against frame coordinates rather than a constant.
local function tormentor(bot)
    local here = bot:GetLocation()
    return api.MakeUnit({
        GetUnitName    = 'npc_dota_miniboss',
        GetTeam        = bot:GetTeam() == 2 and 3 or 2,
        GetPlayerID    = -1,
        IsAlive        = true,
        IsNull         = false,
        IsHero         = false,
        IsBuilding     = false,
        IsIllusion     = false,
        CanBeSeen      = true,
        IsInvulnerable = false,
        IsMagicImmune  = false,
        GetHealth      = 3000,
        GetMaxHealth   = 4000,
        GetAttackRange = 200,
        GetLocation    = api.Vector(here.x + 300, here.y, here.z),
    })
end

--- The Roshan handle: the SIBLING arm of the very same `if`, and this file's
--- positive control. It is built exactly like the Tormentor except for the one
--- byte that matters -- the unit name the identity predicate reads.
local function roshan(bot)
    local here = bot:GetLocation()
    return api.MakeUnit({
        GetUnitName    = 'npc_dota_roshan',
        GetTeam        = 4,
        GetPlayerID    = -1,
        IsAlive        = true,
        IsNull         = false,
        IsHero         = false,
        IsBuilding     = false,
        IsIllusion     = false,
        CanBeSeen      = true,
        IsInvulnerable = false,
        IsMagicImmune  = false,
        GetHealth      = 3000,
        GetMaxHealth   = 4000,
        GetAttackRange = 200,
        GetLocation    = api.Vector(here.x + 300, here.y, here.z),
    })
end

--- Load the shipped hero file against this world and run the real guard.
--- X.SkillsComplement is what populates the file-local `botTarget` (line 161);
--- it may return early after any ability fires, but the assignment happens
--- before the first Consider* call, so botTarget is set either way.
local function funhouseDesire(armed, mkTarget, mode)
    local J, bot, spec = world(armed)
    if mode then spec.GetActiveMode = function() return mode end end
    local target = (mkTarget or tormentor)(bot)
    spec.GetTarget       = function() return target end
    spec.GetAttackTarget = function() return target end

    local X = dofile(TARGET)
    pcall(X.SkillsComplement)
    local ok, desire = pcall(X.ConsiderFunhouseMirror)
    return ok, desire, J, bot, target
end

-- ---------------------------------------------------------------------------
-- [frame] -- the real frames
-- ---------------------------------------------------------------------------

tests['[frame F0] the shipped arm is false on EVERY real hero handle in the corpus'] = function()
    -- The domain-emptiness of `J.IsTormentor(bot)`, measured rather than argued.
    -- Every fixture, every unit it carries, evaluated by the REAL helper.
    local frames, units, trues = 0, 0, 0
    local names = {}
    for _, path in ipairs(luaFiles('tests/fixtures')) do
        local ok, J = pcall(rf.load, path)
        if ok and J then
            frames = frames + 1
            for _, u in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
                units = units + 1
                names[u:GetUnitName()] = true
                if J.IsTormentor(u) then trues = trues + 1 end
            end
            for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
                units = units + 1
                names[u:GetUnitName()] = true
                if J.IsTormentor(u) then trues = trues + 1 end
            end
        end
    end

    local distinct = 0
    for _ in pairs(names) do distinct = distinct + 1 end

    -- Measured 2026-09-01: 107 frames, 993 handles, 41 distinct hero names, 0
    -- true. The floors sit just under those so a NEW fixture never reddens this,
    -- but a census that quietly stopped reaching the corpus does.
    assert(frames >= 105, 'the census must actually cover the corpus; loaded ' .. frames)
    assert(units >= 950, 'and actually reach the handles; read ' .. units)
    assert(distinct >= 40,
        'over a wide hero population, not one draft repeated; ' .. distinct .. ' distinct names')
    assert(trues == 0,
        'THE DEFECT, at corpus scale: the shipped Tormentor arm returned true on '
        .. tostring(trues) .. ' of ' .. units .. ' real hero handles across ' .. frames
        .. ' real frames. It is not a rare condition, it is an empty one.')
end

tests['[frame FC] POSITIVE CONTROL: the SIBLING arm fires on this frame, unarmed'] = function()
    -- The whole finding is "one of two arms in one `if` asks about the wrong
    -- object". The other arm is the control, and it needs no gate: with the bot
    -- doing Roshan and Roshan in front of it, the SHIPPED guard reaches its body
    -- and returns HIGH.
    --
    -- This test is the reason F1 is worth anything. Before it existed, F1 read
    -- NONE and "passed" -- while the real cause was an untrained ability handle
    -- bailing the function on line 1, four conditions upstream of the arm under
    -- test. A shut guard proves nothing until something proves the guard opens.
    local ok, desire, J, bot, rosh = funhouseDesire(false, roshan, BOT_MODE_ROSHAN)
    assert(ok, 'the control must run: ' .. tostring(desire))
    assert(J.IsRoshan(rosh), 'the control target really is Roshan by the real helper')
    assert(J.IsDoingRoshan(bot), 'and the bot really is in Roshan mode')
    assert(desire == BOT_ACTION_DESIRE_HIGH,
        'the sibling arm -- same `if`, same frame, same world slots, correctly fed '
        .. 'botTarget -- must reach the body, or every other frame test here is '
        .. 'measuring some unrelated bail. Got ' .. tostring(desire))
end

tests['[frame F1] SHIPPED: the guard stays shut with the Tormentor 300u away'] = function()
    local ok, desire, J, bot, torm = funhouseDesire(false, tormentor)
    assert(ok, 'the shipped guard must run: ' .. tostring(desire))

    -- The world conditions the branch exists for are all true, checked here so
    -- that F1 failing "for the right reason" is not taken on trust.
    assert(J.IsDoingTormentor(bot), 'S-A must make the outer gate open')
    assert(J.IsAttacking(bot), 'S-B must make the last conjunct true')
    assert(J.IsInRange(bot, torm, 900), 'S-C must sit inside the 900u term')
    assert(J.IsTormentor(torm), 'and the target really is a miniboss by the real helper')
    assert(J.IsTormentor(bot) == false,
        'while the object the shipped arm asks about is not, and cannot be')

    assert(desire == BOT_ACTION_DESIRE_NONE,
        'THE DEFECT on a real frame: every condition the branch was written for holds '
        .. 'and it still does not fire, because the arm was asked about the wrong unit. '
        .. 'Got ' .. tostring(desire))
end

tests['[frame F2] ARMED: the same frame, the same Tormentor, the guard opens'] = function()
    local ok, desire = funhouseDesire(true, tormentor)
    assert(ok, 'the armed guard must run: ' .. tostring(desire))
    assert(desire == BOT_ACTION_DESIRE_HIGH,
        'armed, the arm asks about the target and the branch reaches its body. Got '
        .. tostring(desire))
end

tests['[frame F3] ARMED is a STRICT SUPERSET: no Tormentor, no change'] = function()
    -- The shut arm is identically false, so arming can only ADD firings. The
    -- honest way to say that is to show the armed guard still shut when the
    -- target is an ordinary hero -- i.e. arming did not simply force the branch.
    local J, bot, spec = world(true)
    local enemy
    for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if u:IsAlive() then enemy = u break end
    end
    assert(enemy, 'the frame must supply a live enemy hero')
    spec.GetTarget       = function() return enemy end
    spec.GetAttackTarget = function() return enemy end

    local X = dofile(TARGET)
    pcall(X.SkillsComplement)
    local ok, desire = pcall(X.ConsiderFunhouseMirror)
    assert(ok, 'must run: ' .. tostring(desire))
    assert(J.IsTormentor(enemy) == false, 'a real hero is not a miniboss')
    assert(desire == BOT_ACTION_DESIRE_NONE,
        'armed with a non-miniboss target the guard must stay shut, or the fix is a '
        .. 'blanket open rather than a corrected question. Got ' .. tostring(desire))
end

return tests
