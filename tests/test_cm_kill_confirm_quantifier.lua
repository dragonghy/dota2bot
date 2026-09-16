-- [ratchet] [hero] The 击杀敌人 firing point of Crystal Maiden's X.ConsiderW, and
-- the hero desk's DO-NOT-ARM ruling on the candidate iterations/streams/hero.md
-- backlog `-190` handed forward as its "下一轮主体候选·第 1 条".
--
-- ===========================================================================
-- §0  WHAT THE CANDIDATE SAID, AND WHAT MEASURING IT FOUND
-- ===========================================================================
--
-- The backlog entry reads, verbatim: "CM `击杀敌人` 首个出货点只问了一个候选:
-- 它取环内绝对血量最低的那个,该目标过不了 J.CanCastOnTargetAdvanced 就整条
-- 击杀确认放弃,哪怕环内另有可杀的(存在量词塌缩成单候选)".  It also says, in
-- the same breath, that this is a CANDIDATE and not a finding, and that whoever
-- claims it measures its domain first.  This file is that measurement.
--
-- ⭐⭐ THE HEADLINE IS THAT THE OBVIOUS FIX IS A DEAD CONJUNCT, AND THE PROOF IS
-- IN THE SELECTOR, NOT IN THE CORPUS.  The first thing this desk wrote was the
-- magic-immunity guard the branch appears to be missing: X.ConsiderW names
-- J.CanCastOnNonMagicImmune at four inline sites (打断TP, 团战最强敌人, 进攻,
-- 撤退) and reaches it at a fifth through X.cm_FindSelfDefenseTarget (保护自己),
-- while the kill confirm carries neither it nor any immunity term -- so adding
-- it looks like a one-conjunct repair with five sibling precedents.  It is a
-- guaranteed no-op.  X.cm_GetWeakestUnit -- the selector that PRODUCES
-- `nWeakestEnemyHeroInRange` -- filters its own loop on exactly
-- `J.CanCastOnNonMagicImmune( unit )`.  The subject expression can therefore
-- never be magic-immune, invulnerable, a suspicious illusion, or carry a
-- forbidden modifier, and a conjunct re-testing that predicate on the same
-- handle, with nothing in between that could change it, is the `#nTowers == 0`
-- shape backlog `-190` refused one round earlier.  Section 2 DRIVES this
-- (injecting immunity makes the shipped branch refuse ALREADY, and refuse for
-- the selector's reason) rather than arguing it.
--
-- ⭐⭐ AND THE FILE ITSELF ALREADY ANSWERS THE QUESTION, WHICH IS BETTER
-- EVIDENCE THAN EITHER.  The 对线期消耗 block has four sub-branches.  The three
-- that bid on a target produced by X.cm_GetWeakestUnit carry NO immunity term.
-- The one that bids on `nEnemysHeroesInView[1]` -- a raw J.GetNearbyHeroes
-- element that never passed the selector -- is the one that writes
-- `not ...:IsMagicImmune()` out longhand.  ⇒ In this file the immunity test
-- appears exactly where the target did NOT come through the selector.  The
-- shipped author's own answer to "must a selector-derived target be re-tested"
-- is NO, and the kill confirm's target is selector-derived.  Section 1 asserts
-- that split off the source.
--
-- ⭐ WHAT SURVIVES THE MEASUREMENT IS THE CANDIDATE'S ACTUAL SHAPE, SHARPER
-- THAN IT WAS FILED.  There are two castability FAMILIES in this repo and the
-- two sit in different helpers:
--
--     J.CanCastOnNonMagicImmune   immunity family: IsMagicImmune,
--                                 IsInvulnerable, suspicious illusion,
--                                 forbidden modifier   (+ CanBeSeen)
--     J.CanCastOnTargetAdvanced   spell-BLOCK family: Linken's sphere, AM
--                                 spell shield, brewmaster earth, lotus orb,
--                                 aeon disk, roshan block, shallow grave
--
-- The selector filters on the FIRST family.  The branch then tests the SECOND
-- family on the single survivor the selector handed it, and abandons the whole
-- kill confirm when it fails.  ⇒ A Linken's-carrying lowest-health enemy does
-- not merely go unpicked, it deletes the kill confirm for every other enemy in
-- the ring -- including ones the selector's own loop had already accepted.
-- That is the existential collapse, and it is REAL: section 3 drives it.
--
-- ⛔⛔ AND IT IS STILL DO-NOT-ARM TODAY, for the reason backlog `-190` refused
-- `not J.IsDisabled` (0 of 19) rather than for a new one.  Section 4's table:
-- over all 70 live-CM instants in tests/fixtures/ + tests/frames/, 19 carry a
-- weakest enemy inside Frostbite's ring and J.CanCastOnTargetAdvanced answers
-- TRUE on all 19 -- because the corpus contains ZERO instances of any
-- spell-block modifier, on any unit, on any frame.  Arming a lever whose
-- trigger the archive cannot exhibit once is arming something neither leg can
-- see.  The frame request is iterations/queue.json hero-98.
--
-- ⚠️⚠️ AND TWO OF THE THREE ZEROES IN THAT TABLE ARE UNASKABLE, NOT MEASURED --
-- WHICH IS A DIFFERENT SENTENCE AND SECTION 5 PINS IT.  `IsMagicImmune()` and
-- `IsInvulnerable()` are not derived by the fixture loader at all: they fall to
-- tests/mock/bot_api.lua's blanket `^Is -> false` and answer false for EVERY
-- unit on EVERY frame -- including the 9 archived instants whose recorded
-- modifier list literally carries modifier_black_king_bar_immune or
-- modifier_juggernaut_blade_fury, and the 3 carrying
-- modifier_obsidian_destroyer_astral_imprisonment_prison.  The state occurs in
-- the corpus; the instrument cannot see it.  Same family as the loader's own
-- documented HasModifier / WasRecentlyDamagedBy / GetTower gaps.  ⛔ Nobody may
-- read section 4's immunity rows as "it never happens".
--
-- ⛔ bots/ CARRIES NO BEHAVIOR CHANGE FROM THIS WORK UNIT, ON PURPOSE.  The
-- answer to "add the immunity conjunct" is NO (dead), and the answer to "fix
-- the collapse now" is NOT YET (no frame).  Same disposition, and for the same
-- stated reason, as tests/test_wk_dead_row_precondition.lua's ruling on GH #794.
--
-- SECTIONS
--   1  the source: five firing points, two families, and the selector's filter
--   2  DRIVEN: the immunity conjunct is a no-op, and the refusal is the selector's
--   3  DRIVEN: the collapse that does survive, on a real frame
--   4  DOMAIN: the table, with its liveness checks
--   5  the loader gap that makes two of those rows UNASKABLE

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC  = 'bots/BotLib/hero_crystal_maiden.lua'
local UNIT = 'npc_dota_hero_crystal_maiden'
local FB   = 'crystal_maiden_frostbite'

-- The one frame section 2 and section 3 drive.  Spirit Breaker at 172/1755
-- inside Frostbite's ring, Frostbite trained at rank 4 (300 magic damage), CM
-- at 447 mana.  It is the ONLY live-CM instant in the whole archive on which
-- J.WillMagicKillTarget answers true, which is what makes it the frame on
-- which the kill confirm actually fires.
local FRAME = 'tests/frames/f_260909_215040_wk_blast_sb_661.lua'
local SB    = 'npc_dota_hero_spirit_breaker'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The two modifier vocabularies section 5 counts.  Written out rather than
-- read from J.Buff so that a future edit to that table cannot silently empty
-- the enumerator this file's zeroes are measured against.
local IMMUNE_MODS = {
    'modifier_black_king_bar_immune',
    'modifier_juggernaut_blade_fury',
    'modifier_life_stealer_rage',
    'modifier_omniknight_repel',
}
local INVULN_MODS = {
    'modifier_obsidian_destroyer_astral_imprisonment_prison',
    'modifier_eul_cyclone',
}
-- J.CanCastOnTargetAdvanced's own list, byte for byte off jmz_func.lua.
local BLOCK_MODS = {
    'modifier_item_sphere_target',
    'modifier_antimage_spell_shield',
    'modifier_brewmaster_earth_spell_immunity',
    'modifier_item_lotus_orb_active',
    'modifier_item_aeon_disk_buff',
    'modifier_roshan_spell_block',
    'modifier_dazzle_shallow_grave',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The same file with LINE COMMENTS removed.  This file's own header quotes the
--- shipped conjuncts it is about, and so do the headers of the five gated
--- helpers already living in that file, so a census over the raw text would
--- count documentation as call sites.  ⚠️ LIMIT: line comments only; a
--- `--[[ ]]` block would still be counted (bots/ has none today).
local function read_code(path)
    local out = {}
    for line in (read_file(path) .. '\n'):gmatch('(.-)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer and only the assert
--- tells them apart.
--- ⚠️ io.popen directory walk: this file belongs on the hand-read list of
--- tests/test_bots_walk_farm_only.py (GH #774).
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method.
--- ⚠️ THE SECOND LINE IS DEFENSIVE HERE, NOT LOAD-BEARING, and this comment
--- says so because the first version of it claimed the opposite.  The reasoning
--- for the claim was sound -- section 2 injects onto a handle obtained from an
--- EARLIER J.GetNearbyHeroes call, so the method could already have been
--- materialised -- and it is still wrong: the stand's M12 deleted the line and
--- the suite stayed GREEN, because nothing in these paths calls the injected
--- method before the injection.  The line stays because that ordering is an
--- accident of how each section is written today.  M12 now deletes the line
--- that IS load-bearing, the spec write.  (Same finding, and the same
--- correction, as tests/test_cm_lane_fallback_wallet.lua's M12.)
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- The cast ring X.ConsiderW itself builds, rebuilt out of the real helpers
--- rather than frozen at one of today's values.
local function w_cast_range(J, bot)
    local hW = bot:GetAbilityByName(FB)
    local nAether = 0
    local hLens = J.IsItemAvailable('item_aether_lens')
    if hLens ~= nil then nAether = J.GetAetherLensRangeBonus(hLens, 250) end
    local nCastRange = (hW and hW:GetCastRange() or 0) + 30 + nAether
    local view = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
    if #view <= 1 and nCastRange < bot:GetAttackRange() then
        nCastRange = bot:GetAttackRange() + 60
    end
    return nCastRange
end

--- Drive the REAL X.SkillsComplement dispatch on FRAME, then ask X.ConsiderW
--- for its bid.  `fPrep` receives (J, bot, hW) and is where each section
--- declares its own injections -- there are no hidden ones.
--- ⚠️ THE DISPATCH IS NOT LOAD-BEARING FOR THE BRANCH THIS FILE IS ABOUT, and
--- saying so is better than implying otherwise: the stand's first M11 removed
--- the X.SkillsComplement() call and the suite stayed GREEN.  The kill confirm
--- reads none of the per-frame file-scope locals the dispatch assigns
--- (nMP/nHP/nLV/nKeepMana) -- those belong to the 对线期消耗 block, which is why
--- tests/test_cm_lane_fallback_wallet.lua's own driver genuinely needs it.  The
--- call stays because it is the real entry point the engine uses, and any later
--- section here that drives a lane branch would need it; it is not evidence.
local function drive(fPrep)
    local J, bot = rf.load(FRAME, UNIT)
    -- Every gate DOWN, so what is driven is the SHIPPED tree.
    -- ⚠️ On today's tree this stub is inert for the kill confirm and the stand
    -- measures that (its first M13 flipped it to `return true` and the suite
    -- stayed green): no CM soak candidate reaches this branch.  It stays
    -- because that is a property of today's gate set, not of the branch -- and
    -- the section-1 assertion below turns it into a ratchet, so the day someone
    -- lands a gate inside the kill confirm this file stops being silent.
    J.IsSoakCandidate = function() return false end
    J.IsModeTurbo = function() return true end
    local X = rf.load_hero('crystal_maiden')
    local hW = bot:GetAbilityByName(FB)
    if fPrep then fPrep(J, bot, hW) end
    X.SkillsComplement()
    local nDesire, hTarget = X.ConsiderW()
    local sTarget = nil
    if type(hTarget) == 'table' and hTarget.GetUnitName then
        sTarget = hTarget:GetUnitName()
    end
    return nDesire, sTarget, J, bot, hW
end

--- Frostbite off cooldown.  DECLARED, and it is the ONE injection section 2's
--- and section 3's baselines carry: the recording has 3.2s of cooldown left,
--- and with it on cooldown X.ConsiderW's first statement returns NONE before
--- any of the code this file is about is reached.
--- ⚠️ ONE injection, not two, and that is measured rather than tidied: the
--- loader DERIVES IsFullyCastable from the recorded cooldown (3.2 -> false;
--- inject 0 -> true), so a second `inject(hW, 'IsFullyCastable', true)` changed
--- nothing.  The stand's first M10 deleted that second line and every test
--- stayed green, which is how a redundant injection announces itself.  Fewer
--- declared injections is the point: each one is a world fact this file asserts
--- into existence, and one of the two was not doing anything.
local function ready(hW)
    inject(hW, 'GetCooldownTimeRemaining', 0)
end

--- The Spirit Breaker handle, off the loader's own ring.
local function sb_handle(J, bot)
    for _, h in ipairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)) do
        if h:GetUnitName() == SB then return h end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The source.  Five firing points, two castability families, one selector.

tests['[section 1] the immunity term appears exactly where the target does NOT come from the selector'] =
function()
    local sCode = read_code(SRC)
    local sW = sCode:match('function X%.ConsiderW%(%)(.-)\nend\n')
    assert(sW ~= nil and #sW > 2000, 'X.ConsiderW did not slice out of the '
        .. 'source; every census below reads this slice')

    -- The four firing points that DO guard the immunity family.  Three name the
    -- helper; the third lane sub-branch writes the predicate out longhand.
    local nHelper = 0
    for _ in sW:gmatch('J%.CanCastOnNonMagicImmune%(') do nHelper = nHelper + 1 end
    assert(nHelper == 4, 'X.ConsiderW names J.CanCastOnNonMagicImmune at ' .. nHelper
        .. ' site(s) inline; 4 were recorded. The 保护自己 branch reaches it through '
        .. 'X.cm_FindSelfDefenseTarget in addition, so the function guards the '
        .. 'immunity family in at least five places -- and the kill confirm, '
        .. 'asserted below, is not one of them.')
    -- ⭐⭐ THE STRONGEST SINGLE PIECE OF EVIDENCE FOR THE RULING, and it is the
    -- file's own design rather than this desk's reading.  The 对线期消耗 block
    -- has four sub-branches.  Three of them bid on nWeakestEnemyHeroInRange or
    -- nWeakestEnemyHeroInBonus -- both produced by X.cm_GetWeakestUnit -- and
    -- NONE of those three carries an immunity term.  The fourth bids on
    -- nEnemysHeroesInView[1], which is a raw J.GetNearbyHeroes element that
    -- never passed the selector, and it is the ONE that writes the immunity test
    -- out longhand.  ⇒ In this file, the immunity term appears exactly where the
    -- target did NOT come through the selector.  That is the shipped author's
    -- own answer to "does a selector-derived target need re-testing", and it is
    -- NO.
    assert(sW:find('not nEnemysHeroesInView%[1%]:IsMagicImmune%(%)') ~= nil,
        'the 对线期消耗 sub-branch that bids on the raw view list no longer writes '
        .. 'its own IsMagicImmune term. That term is the in-file evidence that '
        .. 'the immunity test belongs to NON-selector targets; without it the '
        .. 'ruling in this file rests on section 2 alone.')
    local sLane = sW:match('\n\tif bot:GetActiveMode%(%) == BOT_MODE_LANING(.-)\n\tend\n')
    assert(sLane ~= nil, 'the 对线期消耗 block did not slice out')
    assert(sLane:find('CanCastOnNonMagicImmune') == nil,
        'a 对线期消耗 sub-branch now calls J.CanCastOnNonMagicImmune; the '
        .. '"selector-derived targets are not re-tested" reading depends on none '
        .. 'of them doing so')
    local nView = 0
    for _ in sLane:gmatch('IsMagicImmune') do nView = nView + 1 end
    assert(nView == 1, 'the 对线期消耗 block names IsMagicImmune ' .. nView
        .. ' time(s); exactly one was recorded, on the one sub-branch whose '
        .. 'target does not come from X.cm_GetWeakestUnit')

    -- ⭐ AND THE KILL CONFIRM HAS NEITHER.  Its guard is exactly two predicates.
    local sKill = sW:match('(\n\tif J%.IsValid%( nWeakestEnemyHeroInRange %).-\n\tend\n)')
    assert(sKill ~= nil, 'the 击杀敌人 firing point did not slice out; it is the '
        .. 'first `if J.IsValid( nWeakestEnemyHeroInRange )` in X.ConsiderW')
    assert(sKill:find('J%.CanCastOnTargetAdvanced%(') ~= nil,
        'the kill confirm no longer calls J.CanCastOnTargetAdvanced')
    assert(sKill:find('CanCastOnNonMagicImmune') == nil
        and sKill:find('IsMagicImmune') == nil
        and sKill:find('IsInvulnerable') == nil,
        'the kill confirm now carries an immunity term of its own -- this whole '
        .. 'file is about the fact that it does not, and about why adding one '
        .. 'would be a no-op. Re-read section 2 before deleting anything here.')

    -- ⭐ AND THE BRANCH IS UNGATED, which is what makes the driver's gates-down
    -- stub honest rather than decorative.  Every leg below drives with
    -- J.IsSoakCandidate answering false; if a soak candidate ever lands inside
    -- this branch, "shipped" and "what this file drives" stop being the same
    -- thing and every reading here silently becomes a reading of one arm.
    assert(sKill:find('IsSoakCandidate') == nil and sKill:find('X%.cm_Is') == nil,
        'the 击杀敌人 firing point now routes through a gate or a gated helper. '
        .. 'The driver in this file pins every gate DOWN, so its readings would '
        .. 'be of the unarmed leg only -- give the new lever its own end-to-end '
        .. 'legs rather than letting these stand for both.')
end

tests['[section 1] the SELECTOR already filters the immunity family -- the proposed conjunct is dead'] =
function()
    local sCode = read_code(SRC)
    local sSel = sCode:match('function X%.cm_GetWeakestUnit%( nEnemyUnits %)(.-)\nend\n')
    assert(sSel ~= nil, 'X.cm_GetWeakestUnit did not slice out of the source')

    -- ⭐⭐ THE RULING, read off the producer of the subject expression.
    assert(sSel:find('J%.CanCastOnNonMagicImmune%( unit %)') ~= nil,
        'X.cm_GetWeakestUnit no longer filters on J.CanCastOnNonMagicImmune. '
        .. 'THAT FILTER IS WHY the immunity conjunct this desk first wrote for '
        .. 'the kill confirm is a dead conjunct. If it is really gone, the '
        .. 'DO-NOT-ARM ruling in this file header no longer holds and the lever '
        .. 'becomes live -- re-measure before assuming either way.')
    -- And it does NOT filter the other family, which is the whole of section 3.
    assert(sSel:find('CanCastOnTargetAdvanced') == nil,
        'X.cm_GetWeakestUnit now also filters the spell-block family; if so the '
        .. 'existential collapse section 3 drives is repaired at the selector '
        .. 'and iterations/queue.json hero-98 should be withdrawn')

    -- The subject expression is produced by that selector and never reassigned
    -- between there and the kill confirm -- the "nothing in between could change
    -- it" half of the dead-conjunct argument, which is the half a reader would
    -- otherwise have to take on trust.
    -- ⚠️ COUNTED LINE BY LINE, not over the slice: in a Lua pattern `[^=]`
    -- matches a newline, so a slice-wide `nWeakestEnemyHeroInRange[^=]*=` runs
    -- past the end of its own statement and into the next `=` several branches
    -- below.  The first version of this assertion did exactly that and reported
    -- 2 where the file has 1.
    local sW = sCode:match('function X%.ConsiderW%(%)(.-)\nend\n')
    local nAssign = 0
    for sLine in (sW .. '\n'):gmatch('(.-)\n') do
        if sLine:find('nWeakestEnemyHeroInRange%f[%A]') and sLine:find('=')
            and not sLine:find('==') then
            nAssign = nAssign + 1
        end
    end
    assert(nAssign == 1, 'nWeakestEnemyHeroInRange is assigned ' .. nAssign
        .. ' time(s) inside X.ConsiderW; exactly one (the X.cm_GetWeakestUnit '
        .. 'call) was recorded, and the dead-conjunct reading depends on it')
end

tests['[section 1] the three considers that consume the selector, so the ruling is not local to W'] =
function()
    local sCode = read_code(SRC)
    -- ⚠️ The definition line matches the call pattern too, so it is excluded by
    -- name rather than by subtracting one -- a subtraction would keep answering
    -- the recorded number if the definition were ever renamed away.
    local nCalls, nDef = 0, 0
    for sLine in (sCode .. '\n'):gmatch('(.-)\n') do
        if sLine:find('X%.cm_GetWeakestUnit%(') then
            if sLine:find('function%s+X%.cm_GetWeakestUnit') then
                nDef = nDef + 1
            else
                nCalls = nCalls + 1
            end
        end
    end
    assert(nDef == 1, 'X.cm_GetWeakestUnit is defined ' .. nDef .. ' time(s); 1 '
        .. 'was recorded')
    assert(nCalls == 7, 'X.cm_GetWeakestUnit is called at ' .. nCalls .. ' site(s); '
        .. '7 were recorded (ConsiderQImpl: 2 hero rings + 2 lane-creep rings, '
        .. 'ConsiderW: 2 hero rings, ConsiderR: 1). Any new consumer inherits '
        .. 'BOTH properties: an immunity filter it need not repeat, and a '
        .. 'spell-block blindness it must handle itself.')

    -- ⭐ AND FOUR OF THE SEVEN PASS CREEPS, not heroes -- which is worth writing
    -- down next to the ruling: J.CanCastOnNonMagicImmune is a unit predicate, so
    -- the selector's filter applies there too, and a magic-immune creep is a
    -- state this repo's own creep branches would otherwise have to re-test.
    local nCreepArg = 0
    for _ in sCode:gmatch('X%.cm_GetWeakestUnit%(%s*nEnemysLaneCreeps') do
        nCreepArg = nCreepArg + 1
    end
    assert(nCreepArg == 2, 'the lane-creep call sites moved (' .. nCreepArg .. ')')
end

-- ---------------------------------------------------------------- section 2 --
-- DRIVEN: the immunity conjunct is a no-op, and the refusal is the selector's.

tests['[section 2] with Frostbite ready the shipped kill confirm fires on the real frame'] =
function()
    local nDesire, sTarget = drive(function(J, bot, hW) ready(hW) end)
    assert(nDesire == BOT_ACTION_DESIRE_HIGH, 'the shipped kill confirm no longer '
        .. 'bids on ' .. FRAME .. '; got ' .. tostring(nDesire) .. '. Sections 2 '
        .. 'and 3 are both differences FROM this bid, so a vacuous baseline would '
        .. 'make both of them pass while measuring nothing.')
    assert(sTarget == SB, 'the bid targets ' .. tostring(sTarget) .. ', not the '
        .. 'Spirit Breaker the kill confirm is about')
end

tests['[section 2] injecting magic immunity ALREADY refuses, with every gate down'] =
function()
    -- ⭐⭐ THE DEAD-CONJUNCT PROOF, driven.  Two injections, both declared:
    -- Frostbite off cooldown (as in the baseline above) and IsMagicImmune on the
    -- one enemy in the ring.  If the shipped branch needed an immunity guard,
    -- this leg would still bid HIGH -- that is exactly what the candidate
    -- predicted and exactly what does not happen.
    local nDesire, sTarget = drive(function(J, bot, hW)
        ready(hW)
        local hSB = sb_handle(J, bot)
        assert(hSB ~= nil, 'the Spirit Breaker is not in the loader ring; the '
            .. 'injection below would land on nothing')
        inject(hSB, 'IsMagicImmune', true)
    end)
    assert(nDesire == BOT_ACTION_DESIRE_NONE, 'the SHIPPED X.ConsiderW still bids '
        .. tostring(nDesire) .. ' on a magic-immune target. That would make the '
        .. 'immunity conjunct a real repair rather than a dead one and this '
        .. 'file\'s DO-NOT-ARM ruling wrong -- re-open it, do not relax this.')
    assert(sTarget == nil, 'and it hands back no target; got ' .. tostring(sTarget))
end

tests['[section 2] and the refusal comes from the SELECTOR, not from the branch'] =
function()
    -- The negative control that separates "the branch guarded it" from "the
    -- subject expression was never produced".  Only the second is true: with
    -- immunity injected, X.cm_GetWeakestUnit returns nil over the same ring, so
    -- the branch's `J.IsValid( nWeakestEnemyHeroInRange )` sees nil and the
    -- CanCastOnTargetAdvanced call is never reached.
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function() return false end
    J.IsModeTurbo = function() return true end
    local X = rf.load_hero('crystal_maiden')
    local hSB = sb_handle(J, bot)
    assert(hSB ~= nil, 'no Spirit Breaker handle')

    local tRing = J.GetNearbyHeroes(bot, w_cast_range(J, bot), true, BOT_MODE_NONE)
    assert(#tRing == 1 and tRing[1]:GetUnitName() == SB,
        'the ring on this frame is no longer exactly the Spirit Breaker (' .. #tRing
        .. ' member(s)); the two readings below are of THAT ring')

    local hBefore = X.cm_GetWeakestUnit(tRing)
    assert(hBefore ~= nil, 'the selector already refuses this ring before any '
        .. 'injection -- the reading below would then be vacuous')

    inject(hSB, 'IsMagicImmune', true)
    local hAfter = X.cm_GetWeakestUnit(tRing)
    assert(hAfter == nil, 'the selector still returns a unit for a magic-immune '
        .. 'ring; the dead-conjunct ruling rests on it returning nil')

    -- ⭐ AND THE UNIT IS STILL IN THE RING -- it is the selector that dropped it,
    -- not the engine's search.  Without this, "the ring went empty" would be an
    -- equally good explanation and it would point at a different repair.
    local tRingAfter = J.GetNearbyHeroes(bot, w_cast_range(J, bot), true, BOT_MODE_NONE)
    assert(#tRingAfter == 1 and tRingAfter[1]:GetUnitName() == SB,
        'the magic-immune hero left J.GetNearbyHeroes too (' .. #tRingAfter
        .. ' member(s)); then the refusal is the search\'s and not the selector\'s')
end

-- ---------------------------------------------------------------- section 3 --
-- DRIVEN: the collapse that does survive the measurement.

tests['[section 3] a spell-BLOCK modifier on the weakest kills the kill confirm outright'] =
function()
    -- The other family.  The selector accepts a Linken's-carrying enemy (it
    -- filters immunity, not spell block), hands it over as the single candidate,
    -- and the branch then refuses it -- and with it, the whole kill confirm.
    local nDesire, sTarget = drive(function(J, bot, hW)
        ready(hW)
        local hSB = sb_handle(J, bot)
        assert(hSB ~= nil, 'no Spirit Breaker handle')
        inject(hSB, 'HasModifier', function(_, sName)
            return sName == 'modifier_item_sphere_target'
        end)
    end)
    assert(nDesire == BOT_ACTION_DESIRE_NONE, 'the kill confirm now survives a '
        .. 'spell-blocked weakest (bid ' .. tostring(nDesire) .. '); if the branch '
        .. 'was repaired, iterations/queue.json hero-98 should be withdrawn')
    assert(sTarget == nil, 'got target ' .. tostring(sTarget))
end

tests['[section 3] and the selector ACCEPTS that same hero -- which is what makes it a collapse'] =
function()
    -- ⭐ THE ASYMMETRY, stated as two readings of the same handle: the selector
    -- says yes, the branch says no.  On a one-enemy ring the consequence is only
    -- a lost cast; on a ring with a second, legal, killable enemy it is a lost
    -- KILL -- the branch never looks at the second one, because there is no loop.
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function() return false end
    J.IsModeTurbo = function() return true end
    local X = rf.load_hero('crystal_maiden')
    local hSB = sb_handle(J, bot)
    inject(hSB, 'HasModifier', function(_, sName)
        return sName == 'modifier_item_sphere_target'
    end)

    local tRing = J.GetNearbyHeroes(bot, w_cast_range(J, bot), true, BOT_MODE_NONE)
    assert(X.cm_GetWeakestUnit(tRing) == hSB, 'the selector no longer accepts a '
        .. 'spell-blocked hero; then the two families are no longer split across '
        .. 'selector and branch and section 3 has nothing to say')
    assert(J.CanCastOnNonMagicImmune(hSB) == true,
        'the immunity family must still pass -- otherwise this leg is measuring '
        .. 'section 2 over again')
    assert(J.CanCastOnTargetAdvanced(hSB) == false,
        'the spell-block family must fail; got true, so the injection did not land')
end

tests['[section 3] the branch has no loop -- the quantifier is the defect, read off the source'] =
function()
    -- ⚠️ HONEST BOUND: this is a SOURCE reading, not a frame.  No archived
    -- instant carries a ring with two enemies AND a blocked weakest AND a
    -- killable second (section 4 says why: zero spell-block modifiers in the
    -- corpus), so the "lost kill" half of section 3's claim is a construction.
    -- What is not a construction is that the branch cannot look past its one
    -- candidate, and that is what this reads.
    local sCode = read_code(SRC)
    local sW = sCode:match('function X%.ConsiderW%(%)(.-)\nend\n')
    local sKill = sW:match('(\n\tif J%.IsValid%( nWeakestEnemyHeroInRange %).-\n\tend\n)')
    assert(sKill ~= nil, 'the 击杀敌人 firing point did not slice out')
    assert(sKill:find('for ') == nil, 'the kill confirm now contains a loop; if it '
        .. 'scans the ring, the collapse is repaired and this file needs re-reading')

    -- The sibling that shows a loop is this function's own idiom rather than
    -- something this desk would be inventing: 团战最强敌人 scans the SAME ring
    -- with both families and keeps a running best.
    assert(sW:find('for _, npcEnemy in pairs%( tableNearbyEnemyHeroes %)') ~= nil,
        'the teamfight firing point no longer scans; it is the in-file precedent '
        .. 'for what a repaired kill confirm would look like')
end

-- ---------------------------------------------------------------- section 4 --
-- DOMAIN.  The table, and the liveness checks that make its zeroes sayable.

--- One pass over the archive: every live-CM instant, with the loader's real
--- answers for the things this file counts.
local tRows = nil
local function rows()
    if tRows ~= nil then return tRows end
    tRows = {}
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                local J, bot = rf.load(path, UNIT)
                local hW = bot:GetAbilityByName(FB)
                local tRing = J.GetNearbyHeroes(bot, w_cast_range(J, bot), true, BOT_MODE_NONE)
                -- X.cm_GetWeakestUnit picks by ABSOLUTE health.  Rebuilt here
                -- WITHOUT the selector's immunity filter on purpose: this table
                -- is about what the branch would receive, and the filter is the
                -- thing section 2 already measured.
                local hWeakest, nLow = nil, nil
                for _, h in ipairs(tRing) do
                    if J.IsValid(h) and (nLow == nil or h:GetHealth() < nLow) then
                        hWeakest, nLow = h, h:GetHealth()
                    end
                end
                tRows[#tRows + 1] = {
                    path    = path,
                    ready   = (hW ~= nil and hW:IsFullyCastable()) and true or false,
                    ring    = #tRing,
                    weakest = hWeakest ~= nil,
                    adv     = hWeakest ~= nil
                        and (J.CanCastOnTargetAdvanced(hWeakest) and true or false),
                    nonimm  = hWeakest ~= nil
                        and (J.CanCastOnNonMagicImmune(hWeakest) and true or false),
                }
            end
        end
    end
    assert(#tRows > 0, 'no live-CM instant in the archive: this file would then be '
        .. 'counting an empty set and calling every claim true')
    return tRows
end

tests['[section 4] the population, and the two factors that must be non-empty first'] =
function()
    local t = rows()
    assert(#t == 70, 'the archive carried 70 live Crystal Maiden instants when '
        .. 'this was measured, now ' .. #t .. '. Every count below is of THAT '
        .. 'population -- re-read them rather than adjusting one.')

    local nReady, nRing, nWeak, nRing2 = 0, 0, 0, 0
    for _, r in ipairs(t) do
        if r.ready then nReady = nReady + 1 end
        if r.ring >= 1 then nRing = nRing + 1 end
        if r.ring >= 2 then nRing2 = nRing2 + 1 end
        if r.weakest then nWeak = nWeak + 1 end
    end
    -- ⭐ LIVENESS FIRST.  The zeroes in the next test are only sayable if the
    -- enumerator they are measured over is non-empty; otherwise "measured zero"
    -- and "measured nothing" are the same integer.
    assert(nReady == 44, 'Frostbite was fully castable on 44 instants; got ' .. nReady)
    assert(nRing == 19, 'a ring enemy was present on 19 instants; got ' .. nRing)
    assert(nWeak == 19, 'a weakest-in-ring existed on 19 instants; got ' .. nWeak)
    assert(nRing2 == 7, 'the ring held TWO OR MORE enemies on 7 instants; got '
        .. nRing2 .. '. This is the factor the collapse needs and it is NOT '
        .. 'empty -- what is missing is a blocked weakest, not a second enemy.')
end

tests['[section 4] the spell-block zero is the CORPUS s, and it is askable'] =
function()
    local t = rows()
    local nAdv, nAdvFalse = 0, 0
    for _, r in ipairs(t) do
        if r.weakest then
            if r.adv then nAdv = nAdv + 1 else nAdvFalse = nAdvFalse + 1 end
        end
    end
    assert(nAdv == 19 and nAdvFalse == 0, 'J.CanCastOnTargetAdvanced answered '
        .. 'false on ' .. nAdvFalse .. ' weakest-in-ring instant(s); it answered '
        .. 'false on NONE when this was measured. A non-zero here is the frame '
        .. 'iterations/queue.json hero-98 asks for -- the lever becomes armable '
        .. 'and this file\'s DO-NOT-ARM ruling expires.')

    -- ⭐ AND THIS ZERO IS ASKABLE, unlike section 5's.  J.CanCastOnTargetAdvanced
    -- reads HasModifier, which the loader DOES wire from the recorded modifier
    -- lists -- so the reading above is a measurement of the corpus and not of
    -- the instrument.  What the corpus does not contain is any instance of the
    -- modifiers themselves, counted straight off the fixture data:
    -- ⚠️ LIVENESS ON THE ENUMERATOR FIRST, because `nBlock == 0` is exactly as
    -- true over an EMPTY modifier list as over a corpus that carries none, and
    -- the two are the same integer.  Each name is required to appear in the
    -- shipped helper this file claims to be enumerating, so the list cannot
    -- drift into a set of strings nothing tests.
    local sJmz = read_file('bots/FunLib/jmz_func.lua')
    local sAdv = sJmz:match('function J%.CanCastOnTargetAdvanced%( npcTarget %)(.-)\nend\n')
    assert(sAdv ~= nil, 'J.CanCastOnTargetAdvanced did not slice out of jmz_func')
    assert(#BLOCK_MODS == 7, 'BLOCK_MODS holds ' .. #BLOCK_MODS .. ' names; 7 were '
        .. 'recorded, and the census below reads zero over whatever this list holds')
    for _, sMod in ipairs(BLOCK_MODS) do
        assert(sAdv:find(sMod, 1, true) ~= nil, 'BLOCK_MODS carries "' .. sMod
            .. '", which J.CanCastOnTargetAdvanced no longer names -- the census '
            .. 'below would then be counting a modifier the predicate ignores')
    end

    local nBlock = 0
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            for _, u in ipairs(chunk.units or {}) do
                for _, m in ipairs(u.modifiers or {}) do
                    for _, sBlock in ipairs(BLOCK_MODS) do
                        if m.name == sBlock then nBlock = nBlock + 1 end
                    end
                end
            end
        end
    end
    assert(nBlock == 0, 'the corpus now carries ' .. nBlock .. ' spell-block '
        .. 'modifier instance(s). The trigger this lever needs has appeared: '
        .. 're-measure the weakest-in-ring rows above and reconsider arming.')
end

-- ---------------------------------------------------------------- section 5 --
-- The loader gap: why two rows of that table are UNASKABLE and not zero.

tests['[section 5] the corpus DOES carry magic immunity and invulnerability'] =
function()
    local nImm, nInv, nUnits = 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            for _, u in ipairs(chunk.units or {}) do
                nUnits = nUnits + 1
                for _, m in ipairs(u.modifiers or {}) do
                    for _, s in ipairs(IMMUNE_MODS) do
                        if m.name == s then nImm = nImm + 1 end
                    end
                    for _, s in ipairs(INVULN_MODS) do
                        if m.name == s then nInv = nInv + 1 end
                    end
                end
            end
        end
    end
    assert(nUnits == 1420, 'the archive carried 1420 unit rows when this was '
        .. 'measured, now ' .. nUnits .. '; the two counts below are of THAT '
        .. 'population')
    assert(nImm == 9, 'the archive carried 9 magic-immunity modifier instances; '
        .. 'got ' .. nImm)
    assert(nInv == 3, 'the archive carried 3 invulnerability modifier instances; '
        .. 'got ' .. nInv)
end

tests['[section 5] and the loader answers false on every one of them'] =
function()
    -- ⭐⭐ THE GAP, driven on a real row rather than asserted about the mock.
    -- IsMagicImmune() is not derived from the modifier list: it falls to
    -- tests/mock/bot_api.lua's blanket `^Is -> false`.  So every
    -- `not IsMagicImmune()` and `not IsInvulnerable()` guard under bots/ is
    -- structurally satisfied on every fixture frame, and no census over this
    -- archive -- including section 4's -- may be read as evidence about them.
    local FRAME_BKB = 'tests/frames/f_260905_004847_lion_drain_bkb.lua'
    local BB = 'npc_dota_hero_bristleback'

    local chunk = dofile(FRAME_BKB)
    local bRecorded = false
    for _, u in ipairs(chunk.units or {}) do
        if u.name == BB then
            for _, m in ipairs(u.modifiers or {}) do
                if m.name == 'modifier_black_king_bar_immune' then bRecorded = true end
            end
        end
    end
    assert(bRecorded, FRAME_BKB .. ' no longer records a BKB on the Bristleback; '
        .. 'pick another of the 9 instants section 5 counts')

    local J, bot = rf.load(FRAME_BKB, 'npc_dota_hero_lion')
    local hBB = nil
    for _, h in ipairs(J.GetNearbyHeroes(bot, 3000, true, BOT_MODE_NONE)) do
        if h:GetUnitName() == BB then hBB = h end
    end
    assert(hBB ~= nil, 'the Bristleback is not reachable from the Lion subject on '
        .. 'this frame; the reading below needs a handle')

    -- The modifier IS visible to the loader...
    assert(hBB:HasModifier('modifier_black_king_bar_immune') == true,
        'the loader no longer answers HasModifier from the recorded list; then '
        .. 'section 4\'s spell-block reading is UNASKABLE too and this file\'s '
        .. 'domain table must be re-read from scratch')
    -- ...and the derived predicate is NOT.
    assert(hBB:IsMagicImmune() == false, 'the loader now derives IsMagicImmune. '
        .. 'THE GAP IS CLOSED: section 4\'s immunity rows stop being UNASKABLE, '
        .. 'every immunity guard under bots/ becomes measurable on this corpus, '
        .. 'and the [harness] issue this file cites can be closed.')
    assert(J.CanCastOnNonMagicImmune(hBB) == true, 'and the helper built on it '
        .. 'therefore passes a BKB-ed hero -- which is the sentence nobody may '
        .. 'read as "no archived hero was ever immune"')
end

return tests
