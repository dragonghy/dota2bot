-- [ratchet] [bbalone] [strategy 2026-09-19] A TABLE COMPARED WITH A NUMBER IS
-- NOT A COUNT -- AND `==` IS THE ONE OPERATOR THAT NEVER SAYS SO.
--
-- X.ConsiderBuyback in bots/ability_item_usage_generic.lua:
--
--   local nEnemyUnitsAroundAncient = J.GetEnemiesAroundLoc( ancLoc, 1500 ) -- NUMBER
--   local nAllyUnitsAroundAncient  = J.GetAlliesNearLoc(   ancLoc, 1500 ) -- TABLE
--   if nEnemyUnitsAroundAncient > 1 and nAllyUnitsAroundAncient == 0 ...   -- <= THIS
--       bot:ActionImmediate_Buyback()
--
-- Two locals named the same way, read off the same location with the same
-- radius on two adjacent lines, and not the same KIND of thing. The second
-- term is `{} == 0`.
--
-- ⭐ WHY IT SURVIVED. In Lua 5.1 an ORDER comparison across types raises
-- ("attempt to compare number with table"); EQUALITY across types does not --
-- different types are simply unequal, silently, every frame. Measured in this
-- container: `({}) == 0` -> false, `({}) > 1` -> error. The defect sits on the
-- one operator with no runtime opinion about it, in a tree whose engine-side
-- error text is unreadable anyway (AGENTS.md). The sibling term one line up,
-- written with `>`, would have crashed on the first frame.
--
-- ⛔⛔ AND IT DOES NOT ONLY COST ITS OWN BRANCH. The enclosing `if` is
-- J.IsAncientBadlyHurt, which is ITSELF a constant-false shipped expression
-- waiting for validation (soak candidate 'bbancient': absolute hp compared
-- against 0.8). Arming 'bbancient' opens the outer test and lands on THIS
-- term, which is constant-false too -- so a wave arming 'bbancient' alone
-- measures a branch that still cannot fire and reads back "tested, no effect"
-- with nothing raising a hand. ⇒ THE TWO IDS MUST BE ARMED TOGETHER OR
-- NEITHER IS TESTED. §5 pins that requirement is NOT coded as a conjunction of
-- the two ids, which would freeze this gate FALSE the day either is promoted
-- ('pullcad').
--
-- ⛔ WHAT NO ASSERTION BELOW CLAIMS. Nothing here drives X.ConsiderBuyback end
-- to end and on this corpus nothing could: the branch needs the subject DEAD
-- with a buyback and an ancient under 80%, and the sweep measures the corpus
-- holding NEITHER -- 0 frames with enemy weight > 1 within 1500 of our own
-- ancient, and every one of the 69 ancients at hp 1.0. That is a structural
-- absence (our batch games are force-won long before a siege), it is declared,
-- and it is not dressed up as rarity. What IS driven is the TERM, on real
-- frames, with the same getter, location and radius the call site uses.
--
-- ⛔ THE CORPUS WALK IS NOT IN THIS FILE. It is tests/_bbalone_sweep.lua, run
-- by hand. Readings 2026-09-19, 112 fixtures / 1039 live subject frames:
--
--   fixtures carrying an ancient                        69 of 112
--   frames REFUSED (no ancient => bare-mock stand-in    403   <= not read
--     at the map ORIGIN; a 1500 ring there is a
--     different question and is not answered)
--   frames read                                        636
--     shipped term true (`{} == 0`)                      0   <= the defect
--     armed term true  (no living ally within 1500)    528   <= the flip
--     armed term false (someone is home)               108
--   sibling term true (enemy weight > 1 at our base)     0   <= branch wall
--   outer term true, shipped / as 'bbancient' reads it   0 / 0
--
-- ⚠️ ONE MORE THING THE LIVE-FRAME READING AND THE CALL SITE DO NOT SHARE, and
-- §4 is built on it rather than leaving it to be rediscovered:
-- J.GetAlliesNearLoc walks GetTeamMember and filters on `member:IsAlive()`, so
-- on a live frame it can count THE SUBJECT'S OWN BODY. At the call site the
-- caster is dead by construction (`if bot:IsAlive() then return end` above it),
-- so the term there means "some OTHER living teammate is at base". The
-- separating control is therefore chosen so the defender is NOT the subject,
-- and the subject-is-the-defender frame is asserted separately as exactly that.
--
-- ⛔ WHY [ratchet]-TAGGED AND NOT IN tools/agent/lua_gate_manifest.json: same
-- arithmetic as tests/test_smokescan_ally_scan_gate.lua (GH #901). 开工自检's
-- fast Lua leg reads tagged files. ⛔ That is a weaker guarantee and is not
-- dressed up as the same one: the push hook does not run this file unless it
-- has budget left.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_bbalone_ancient_defenders load time')

local tests = {}
local R = 1500   -- the shipped radius at the call site, mirrored exactly

-- THE CLAIM. Lion, dire, t=473.1: not one living dire hero within 1500 of the
-- dire ancient. Shipped, the term answers false (it always does); armed it
-- answers true. One of 528 such frames.
local W_ALONE = { 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
                  'npc_dota_hero_lion', 'dire' }
-- ⭐ THE SEPARATING CONTROL, and the defender is NOT the subject. Crystal
-- Maiden, radiant, t=151.4: one living radiant hero (Chaos Knight, 1063u) is
-- inside 1500 of the radiant ancient while CM herself is 11.8k away. Armed the
-- term must answer FALSE. This is what separates "ask the list its size" from
-- "armed returns true", and it is the only assertion in this file a mutant
-- that hard-codes `true` cannot pass.
local W_DEFENDED = { 'tests/fixtures/f_260819_123546_jakiro_landed_ok.lua',
                     'npc_dota_hero_crystal_maiden', 'radiant' }
-- ⚠️ THE SAME FRAME, READ BY THE BODY THAT IS STANDING THERE. Chaos Knight,
-- radiant, t=151.4: the one ally inside the ring IS him. Armed the term answers
-- false, and the reason is his own body -- a reading the call site can never
-- produce, because the caster is dead there. Asserted as that, not as a domain.
local W_SELF_AT_BASE = { 'tests/fixtures/f_260819_123546_jakiro_landed_ok.lua',
                         'npc_dota_hero_chaos_knight', 'radiant' }

local function turbo()
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ⛔ NOT-TURBO IS A MODE, NOT THE ABSENCE OF A PROBE (0NEXT49): with
--- GAMEMODE_TURBO nil, J.IsModeTurbo falls through to a courier-speed
--- heuristic that can answer either way on a .dem slice.
local function normal_mode()
    GAMEMODE_TURBO = 23                   -- luacheck: ignore
    GetGameMode = function() return 1 end -- luacheck: ignore
end

--- ONE real load. ⛔ Never reuse a load to read the other arming state or the
--- other game mode: J.IsSoakCandidate caches the switch into the module
--- instance on first read, and J.IsModeTurbo memoises on first call.
local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end

--- The call site's own two reads, rebuilt from the same getters so that "the
--- shipped answer" below is produced by the shipped shape, not remembered.
local function site_reads(J, bot)
    local hAnc = GetAncient(bot:GetTeam())
    assert(hAnc ~= nil, 'no ancient for this subject\'s team')
    local vLoc = hAnc:GetLocation()
    return hAnc, J.GetAlliesNearLoc(vLoc, R), J.GetEnemiesAroundLoc(vLoc, R)
end

local function slurp(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

--- Comments stripped: a claim about what the CODE does must not be satisfiable
--- by the prose describing it (both headers quote every one of these tokens).
local function code_of(path)
    return (slurp(path):gsub('%-%-[^\n]*', ''))
end

local function helper_code()
    local s = code_of('bots/FunLib/jmz_func.lua')
    local at = assert(s:find('function J.IsAncientUndefended', 1, true),
        'J.IsAncientUndefended is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

local function buyback_site_code()
    local s = code_of('bots/ability_item_usage_generic.lua')
    local at = assert(s:find('nEnemyUnitsAroundAncient', 1, true),
        'the buyback ancient-defense path is gone from '
        .. 'ability_item_usage_generic.lua')
    local fin = assert(s:find('\n\tend\n', at, true))
    return s:sub(at, fin)
end

-- ============================================== 1. the language fact

tests['[bbalone] `{} == 0` is false and `{} > 1` raises -- the defect sits on '
    .. 'the operator with no opinion'] = function()
    local t = {}
    assert((t == 0) == false,
        'equality across types stopped being false in this VM; the whole '
        .. 'reading of this defect rests on it')
    local ok = pcall(function() return t > 1 end)
    assert(ok == false,
        'an order comparison across types no longer raises -- then the sibling '
        .. 'term would have been silent too and the diagnosis needs redoing')
    -- ⭐ And the shipped term really is that expression, not a count of it.
    local site = buyback_site_code()
    assert(site:find('nAllyUnitsAroundAncient%s*=%s*J%.GetAlliesNearLoc'),
        'the ally local is no longer J.GetAlliesNearLoc -- it may not be a '
        .. 'table any more and this file is measuring the wrong thing')
    assert(site:find('nEnemyUnitsAroundAncient%s*=%s*J%.GetEnemiesAroundLoc'),
        'the enemy local is no longer J.GetEnemiesAroundLoc')
end

-- ============================================== 2. the wiring

tests['[bbalone] the ally term is the helper, handed the call site\'s own '
    .. 'list'] = function()
    local site = buyback_site_code()
    -- ⭐ THE SEMANTIC NAIL FIRST: a mutant that only breaks the wiring must not
    -- be scored by a counting assertion that happens to fire earlier
    -- (0NEXT47/0NEXT48).
    assert(site:find('J%.IsAncientUndefended%s*%(%s*nAllyUnitsAroundAncient%s*%)'),
        'the ally term at the buyback site is no longer '
        .. 'J.IsAncientUndefended reading the site\'s own list')
    assert(not site:find('nAllyUnitsAroundAncient%s*==%s*0'),
        'the shipped `nAllyUnitsAroundAncient == 0` came back at the call site')
    -- ⛔ AN ASSERTION DOMINATED BY AN EARLIER ONE ASSERTS NOTHING. A check that
    -- the site does not hand over `bot` used to stand here; the positive
    -- pattern above already fails for EVERY argument that is not the site's own
    -- list, so its mutant died on the nail and that line could never fire. It
    -- was removed rather than kept as decoration, and the real half of the
    -- claim -- that the helper cannot build a list of its own -- is asserted
    -- where it is not dominated, in §5.
    -- ONE ring, named once for both reads.
    local _, nLit = site:gsub('1500', '')
    assert(nLit == 2, 'expected the 1500 to appear exactly twice (once per '
        .. 'getter at the site); found ' .. nLit)
    -- The sibling term and the respawn threshold are untouched: this is one
    -- lever, and the other two terms of the conjunction stay shipped.
    assert(site:find('nEnemyUnitsAroundAncient%s*>%s*1'),
        'the sibling enemy-weight term changed -- that is a second lever')
    assert(site:find('nRemainingRespawnTime%s*>%s*20'),
        'the respawn threshold changed -- that is a second lever')
end

-- ============================================== 3. the claim

tests['[bbalone] the frame with nobody home: shipped says defended, armed says '
    .. 'undefended'] = function()
    local J, bot = load(W_ALONE)
    local _, tAllies = site_reads(J, bot)
    assert(#tAllies == 0,
        'the claim witness grew a defender (read allies=' .. #tAllies
        .. ') -- it is no longer the frame this lever is claimed on')
    -- ⛔ The shipped answer, produced by the shipped expression.
    assert((tAllies == 0) == false,
        'the shipped expression answered true on a real frame -- then it is '
        .. 'not constant-false and the whole diagnosis is wrong')
    assert(J.IsAncientUndefended(tAllies) == false,
        'the helper answers armed while the gate is OFF')
    unprobe()

    local J2, bot2 = load(W_ALONE)
    ss.with_candidate('bbalone', function()
        local _, t2 = site_reads(J2, bot2)
        assert(#t2 == 0, 'the witness changed under the armed load')
        assert(J2.IsAncientUndefended(t2) == true,
            'armed, the term STILL answers "defended" on a frame with nobody '
            .. 'alive within ' .. R .. ' of our own ancient')
    end, W_ALONE[3])
    unprobe()
end

-- ============================================== 4. the separating control

tests['[control] one living teammate at base, and it is not the subject: armed '
    .. 'must answer defended'] = function()
    local J, bot = load(W_DEFENDED)
    local hAnc, tAllies = site_reads(J, bot)
    assert(#tAllies == 1,
        'the separating control no longer holds exactly one defender (read '
        .. #tAllies .. ') -- it separates nothing')
    assert(tAllies[1] ~= bot,
        'the defender is the subject itself now; this control exists precisely '
        .. 'because the call site\'s caster is dead and cannot be in the list')
    assert(GetUnitToLocationDistance(bot, hAnc:GetLocation()) > R,
        'the subject walked inside the ring -- it can no longer stand for a '
        .. 'caster who is somewhere else entirely')
    unprobe()

    local J2, bot2 = load(W_DEFENDED)
    ss.with_candidate('bbalone', function()
        local _, t2 = site_reads(J2, bot2)
        -- ⭐ THE POINT. Armed, the term reads the list and the list is not
        -- empty. A mutant that returns `true` under the gate passes §3 and
        -- dies right here.
        assert(J2.IsAncientUndefended(t2) == false,
            'armed, the term calls the base undefended while a living '
            .. 'teammate is standing in it -- this lever asks the list its '
            .. 'size, it does not answer for it')
    end, W_DEFENDED[3])
    unprobe()
end

tests['[control] the defender reading its own body: armed answers defended, '
    .. 'and the reason is the subject'] = function()
    local J, bot = load(W_SELF_AT_BASE)
    local _, tAllies = site_reads(J, bot)
    assert(#tAllies == 1 and tAllies[1] == bot,
        'the self-at-base witness is no longer the body in its own list')
    unprobe()

    local J2, bot2 = load(W_SELF_AT_BASE)
    ss.with_candidate('bbalone', function()
        local _, t2 = site_reads(J2, bot2)
        assert(J2.IsAncientUndefended(t2) == false,
            'armed, the term ignores a living teammate standing at the ancient')
        -- ⛔ DECLARED, NOT CLAIMED: at the call site the caster is dead, so
        -- J.GetAlliesNearLoc's `member:IsAlive()` filter drops him and this
        -- exact configuration cannot occur there. The frame is a reading of
        -- the TERM, not of the branch.
        assert(t2[1] == bot2,
            'the reason this frame answers defended is no longer the subject '
            .. 'itself -- the declared limitation above no longer describes it')
    end, W_SELF_AT_BASE[3])
    unprobe()
end

-- ============================================== 5. scope and the gate

tests['[bbalone] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'expression'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'bbalone'%s*%)"),
        "the 'bbalone' gate is gone from J.IsAncientUndefended")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- ⛔ The disarmed leg is the shipped expression, character for character --
    -- table against 0, the defect itself, kept so the shipped default does not
    -- move until this is validated.
    assert(code:find('return%s+tAlliesNearAncient%s*==%s*0'),
        'the disarmed leg no longer carries the shipped expression; the '
        .. 'shipped default has moved and this is no longer a gated fix')
    -- ⛔ NOT A CONJUNCTION OF TWO IDS ('pullcad'): naming 'bbancient' here
    -- would freeze this gate FALSE the day either id is promoted. The
    -- co-arming requirement is registered in prose and in the queue request,
    -- deliberately not in the predicate.
    local _, nIds = code:gsub("IsSoakCandidate%(%s*'[%w_]+'%s*%)", '')
    assert(nIds == 1, 'J.IsAncientUndefended now names ' .. nIds
        .. ' soak ids -- a gate inside a gate is the conjunction of two levers')
    assert(not code:find("'bbancient'", 1, true),
        "J.IsAncientUndefended names 'bbancient' -- that is the pullcad trap")
    -- ⭐ A PURE PREDICATE OVER THE HANDED LIST, and not dominated by anything
    -- at the call site: if the helper fetched the ancient or built its own
    -- ally list, "same list, same location, same ring as the call site" would
    -- stop being true by construction and become a thing to re-check on every
    -- edit -- which is the drift 'roamring'/'tormring' cost.
    for _, sGetter in ipairs({ 'GetAlliesNearLoc', 'GetAncient', 'GetBot',
                               'GetNearbyHeroes', 'GetTeamMember' }) do
        assert(not code:find(sGetter, 1, true),
            'the helper builds its own list: it calls ' .. sGetter
            .. ' instead of reading the list the call site handed it')
    end
    local s = code_of('bots/FunLib/jmz_func.lua')
    local at = assert(s:find('function J.IsAncientBadlyHurt', 1, true))
    local fin = assert(s:find('\nend\n', at, true))
    assert(not s:sub(at, fin):find("'bbalone'", 1, true),
        "J.IsAncientBadlyHurt names 'bbalone' -- same trap, other side")
end

tests['[control] outside turbo the armed id changes nothing'] = function()
    local J, bot = load(W_ALONE)
    local _, tAllies = site_reads(J, bot)
    normal_mode()
    ss.with_candidate('bbalone', function()
        assert(J.IsAncientUndefended(tAllies) == false,
            'armed but NOT in turbo, the helper answered the armed value -- '
            .. 'the turbo scope is not holding')
    end, W_ALONE[3])
    unprobe()
end

tests['[bbalone] nil is not an empty list'] = function()
    local J, bot = load(W_ALONE)
    assert(J.IsAncientUndefended(nil) == false,
        'disarmed, nil no longer answers the shipped false')
    unprobe()
    local J2 = load(W_ALONE)
    ss.with_candidate('bbalone', function()
        assert(J2.IsAncientUndefended(nil) == false,
            'armed, a nil list reads as "nobody is home" -- a getter that came '
            .. 'back nil would then order a buyback')
    end, W_ALONE[3])
    unprobe()
    assert(bot ~= nil)
end

-- ============================================== 6. the direction, as arithmetic

tests['[bbalone] armed can only ADD a buyback, never remove one'] = function()
    -- The branch ends in ActionImmediate_Buyback and nothing else; the term is
    -- one conjunct of its guard; shipped the term is constant-false. So the
    -- armed truth set is a strict SUPERSET of the shipped one (which is empty),
    -- and no frame can lose a buyback it had. Pinned against the source so the
    -- claim cannot outlive the shape it rests on.
    local site = buyback_site_code()
    local _, nBuyback = site:gsub('ActionImmediate_Buyback', '')
    assert(nBuyback == 1, 'the ancient-defense branch no longer ends in '
        .. 'exactly one ActionImmediate_Buyback (found ' .. nBuyback
        .. ') -- the direction proof in the helper header rests on that')
    assert(not site:find('not%s+J%.IsAncientUndefended'),
        'the term is read negated now -- the direction reverses and armed '
        .. 'could REMOVE a buyback')
    -- Exhaustive over the only thing the term can see.
    local J = load(W_ALONE)
    ss.with_candidate('bbalone', function()
        for n = 0, 3 do
            local t = {}
            for i = 1, n do t[i] = true end
            local bShipped = (t == 0)
            local bArmed = J.IsAncientUndefended(t)
            assert(bShipped == false,
                'the shipped expression answered true for a list of ' .. n)
            if bArmed then
                assert(n == 0, 'armed answered undefended with ' .. n
                    .. ' defenders in the list')
            end
        end
    end, W_ALONE[3])
    unprobe()
end

return tests
