-- A field read off a `FindAoELocation` result must be one of the two keys the
-- API returns.  GH #348 (this stream, 2026-08-30), taken 2026-08-31.
--
-- THE SHAPE
-- ---------
--     local X = bot:FindAoELocation( true, true, loc, nCastRange, nRadius, 0.8, 0 )
--     if  #nEnemysHeroesInSkillRange >= 2
--         and ( X.cout ~= nil and X.cout >= 2 )     -- <== `cout`, not `count`
--         ...
--     then
--         return BOT_ACTION_DESIRE_HIGH, X.targetloc
--     end
--
-- `X.cout` is a key the table does not have, so it is nil, so `X.cout ~= nil`
-- is FALSE, so the conjunction is false on every frame at every level with
-- every item against every target.  The branch has never fired and cannot.
--
-- WHY IT IS INVISIBLE.  Lua does not error on a missing table key; it answers
-- nil.  And a bot cannot see that from inside a game: `print()` never reaches
-- the server console and the engine's error handler is broken -- `error in
-- error handling` masks every Lua error text (AGENTS.md).  So this defect has
-- no in-game symptom other than a decision that is never taken, which is
-- exactly what nobody notices.  Same family as GH #162 (`splash_radius_scepter`
-- reads 0 because the key was renamed) and the `GetAbilityDamage()` zeros in
-- hero_lion.lua / hero_zuus.lua: a silent zero/nil that kills a branch.
--
-- WHAT THIS FILE DOES AND DOES NOT DO
-- -----------------------------------
-- It does NOT fix the two sites.  Fixing them REVIVES a branch that has never
-- run in this repo's history -- an action-ADDING change, which ships gated with
-- a sized domain, and neither Sniper nor Muerta is one of the five focus heroes
-- (AGENTS.md).  What it does instead is make the class impossible to grow: the
-- allowlist below is a ratchet with exactly two entries, and both directions
-- are pinned -- a NEW misspelling anywhere under `bots/` goes red, and a
-- REPAIRED site also goes red so that the prose here is rewritten with it.
--
-- ⚠️ THE SECOND SITE WAS NOT IN THE ISSUE.  GH #348 names hero_sniper.lua only.
-- hero_muerta.lua:360 carries the same defect in a byte-identical copy of the
-- same block (`#nEnemysHeroesInSkillRange >= 2` ... `X.cout ~= nil and X.cout
-- >= 2` ... `bot:GetActiveMode() ~= BOT_MODE_LANING`), i.e. it is one upstream
-- copy-paste, not two independent typos.  Found by this census; #348 is
-- updated to say so.
--
-- ⚠️ IT IS ALSO NOT A CLEAN BILL FOR THE FOCUS FIVE'S AoE CODE.  What is
-- established here is narrow and counted: of this repo's 353 `FindAoELocation`
-- call sites, 332 are `local X = ...` declarations this scan can follow, 14 of
-- them in the five focus hero files, and none of those 14 reads a key outside
-- the API's two.  It says nothing about whether the RADIUS handed to the search
-- is right (that is `cmqreach`), whether the result is tested for nil (it is
-- not, at 350 of 353 sites -- tests/test_nil_guard_then_body.lua), or whether
-- the branch guarded by `.count` is the right branch.

package.path = 'tests/?.lua;' .. package.path

local scan = require('lua_source_scan')

-- The focus five (AGENTS.md).  Named here so the standing claim below is about
-- the files this stream owns and cannot be widened by accident.
local FOCUS_FIVE = {
    'bots/BotLib/hero_axe.lua',
    'bots/BotLib/hero_zuus.lua',
    'bots/BotLib/hero_skeleton_king.lua',
    'bots/BotLib/hero_lion.lua',
    'bots/BotLib/hero_crystal_maiden.lua',
}

local function census()
    local rows, sites = {}, 0
    for _, path in ipairs(scan.bots_files()) do
        local r, n = scan.aoe_result_fields(path)
        sites = sites + n
        for _, x in ipairs(r) do rows[#rows + 1] = x end
    end
    return rows, sites
end

local function render(rows)
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = r[1] .. ':' .. r[2] .. ' (' .. r[3] .. '.' .. r[4] .. ')'
    end
    table.sort(out)
    return table.concat(out, '\n            ')
end

local tests = {}

tests['[ratchet] the scanner itself: canonical keys pass, a typo does not'] = function()
    -- WHY THIS NODE EXISTS.  The two census nodes below hold their verdicts for
    -- a scanner that finds nothing at all (both would read "no new hits") and
    -- for one that follows a local past its own reassignment.  Neither failure
    -- is visible from the tree census, so the scanner is pinned here, on
    -- synthetic input with known line numbers.
    local path = os.tmpname()
    local f = assert(io.open(path, 'w'))
    f:write([[
local a = bot:FindAoELocation( true, true, loc, 900, 300, 0, 0 )
if a.count >= 2 then use( a.targetloc ) end
local b = bot:FindAoELocation( true, false, loc, 900, 300, 0, 0 )
if b.cout ~= nil and b.cout >= 2 then use( b.targetloc ) end
local c = bot:FindAoELocation( true, true, loc, 900, 300, 0, 0 )
c = somethingElse()
if c.wibble then use( c ) end
local n = bot:FindAoELocation( true, true, loc, 900, 300, 0, 0 )
if fn.wibble >= 1 then use( n.count ) end
function Other( b )
    if b.wibble then use( b ) end
end
]])
    f:close()
    local rows, sites = scan.aoe_result_fields(path)
    os.remove(path)

    -- `a`: both canonical keys -- must not be reported.
    -- `b`: the defect, read twice on one line -- reported ONCE, on line 4.
    -- `c`: reassigned on line 6, so line 7 is no longer an AoE result and the
    --      scan must have stopped; flagging `c.wibble` would be a false hit.
    -- `n`: `fn.wibble` must not match -- `n` occurs inside `fn` and IS followed
    --      immediately by a dot, so only the leading word boundary stops it.
    --      ⚠️ THE FIRST VERSION OF THIS CASE DID NOT CATCH IT: it used
    --      `counted` / `countedThings.nope`, where the dot does not follow the
    --      matched prefix, so the boundary-removal mutant SURVIVED and this
    --      node passed.  The tree census cannot catch that mutant either (it
    --      was green too), so this line is the only thing holding the boundary.
    -- `Other( b )`: a LATER function whose parameter shadows `b`.  Nothing
    --      assigns to it, so only the function-boundary break stops the scan
    --      for the `b` declared on line 3 from reaching `b.wibble` here.  That
    --      mutant was also green on the tree census.
    assert(sites == 4, 'expected 4 tracked declarations, got ' .. sites)
    assert(#rows == 1,
        'expected exactly 1 hit (`b.cout`), got ' .. #rows .. ':\n            ' ..
        render(rows) .. '\n        2+ means the scan followed `c` past its own ' ..
        'reassignment, matched `n` inside `fn`, or ran on into `Other`')
    assert(rows[1][3] == 'b' and rows[1][4] == 'cout',
        'expected the hit on `b.cout`, got ' .. rows[1][3] .. '.' .. rows[1][4])
    assert(rows[1][2] == 4,
        'expected the `b` hit on line 4, got line ' .. rows[1][2] ..
        ' -- and exactly one hit, not two, for the two reads on that line')
end

tests['[ratchet] no FindAoELocation result is read under a name the API does not return'] = function()
    local rows, sites = census()

    -- The scan must have looked at something.  Without this, a scanner that
    -- silently stopped resolving declarations would report zero findings and
    -- pass -- the "0 games + exit 0" shape GH #345 caught in another census.
    assert(sites >= 300,
        'the census tracked only ' .. sites .. ' FindAoELocation declarations ' ..
        '(332 when this was written) -- a collapse means the scanner stopped ' ..
        'resolving them, and its silence proves nothing')

    -- The TWO registered sites, registered as defects and not as acceptable.
    -- They stay because repairing them REVIVES a branch (see the header) and
    -- neither hero is a focus hero.  Whoever takes GH #348 deletes both from
    -- this list in the same change; do not add a third.
    local expected = {
        'bots/BotLib/hero_muerta.lua:360',
        'bots/BotLib/hero_sniper.lua:282',
    }

    local got = {}
    for _, r in ipairs(rows) do got[#got + 1] = r[1] .. ':' .. r[2] end
    table.sort(got)

    assert(#got == #expected,
        'the set of non-API field reads on a FindAoELocation result moved ' ..
        '(expected ' .. #expected .. ', got ' .. #got .. '):\n            ' ..
        render(rows) ..
        '\n        A NEW one means a misspelled key just froze a branch false.' ..
        '\n        A MISSING one means GH #348 was fixed -- delete it here and ' ..
        'rewrite this file\'s header.')
    for n = 1, #expected do
        assert(got[n] == expected[n],
            'expected ' .. expected[n] .. ', found ' .. got[n])
    end
end

tests['[ratchet] both registered sites are the SAME block, and it is dead both times'] = function()
    -- Pin what makes these two one finding rather than two: the same conjunct,
    -- in the same shipped block, in both files.  If a future round repairs one
    -- and not the other, this goes red on the survivor and says why.
    for _, path in ipairs({ 'bots/BotLib/hero_muerta.lua', 'bots/BotLib/hero_sniper.lua' }) do
        local src = assert(io.open(path)):read('*a')
        assert(src:match('#nEnemysHeroesInSkillRange%s*>=%s*2'),
            path .. ': the shipped multi-hero block changed shape')
        assert(src:match('nCanHurtHeroLocationAoE%s*%.%s*cout%s*~=%s*nil'),
            path .. ': the `.cout` conjunct is gone -- if it was repaired, ' ..
            'remove this file\'s registration for ' .. path)
        -- The dead conjunct guards a `.targetloc` return, which is what makes
        -- this a never-taken decision rather than a harmless nil read.
        assert(src:match('return BOT_ACTION_DESIRE_HIGH,%s*nCanHurtHeroLocationAoE%s*%.%s*targetloc'),
            path .. ': the branch the dead conjunct guards no longer returns ' ..
            'a cast location -- the cost side of GH #348 changed')
    end
end

tests['[ratchet] the focus five read no key the API does not return'] = function()
    -- The standing claim this stream signs, and it is a counted one: 14 tracked
    -- declarations across the five files, zero offending reads.  A count of
    -- zero declarations would make the claim vacuous, so it is asserted too.
    local sites = 0
    for _, path in ipairs(FOCUS_FIVE) do
        local rows, n = scan.aoe_result_fields(path)
        sites = sites + n
        assert(#rows == 0,
            path .. ' reads a FindAoELocation result under a key the API does ' ..
            'not return:\n            ' .. render(rows))
    end
    assert(sites == 14,
        'the focus five tracked 14 FindAoELocation declarations when this was ' ..
        'written, now ' .. sites .. ' -- not a defect, but the claim above is ' ..
        'about that many sites and the number must move with them')
end

return tests
