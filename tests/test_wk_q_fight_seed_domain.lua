-- [hero] The Wraith King copy of the `nMostDangerousDamage = 0` argmax seed
-- (GH #870 §5.2's suggested starting point for the floor/max-search polarity):
-- X.ConsiderQ's 团战 branch spells its "no candidate yet" sentinel as a DAMAGE
-- VALUE sitting ON the floor of that quantity's own range, so an all-zero
-- candidate set vetoes the branch -- exactly the shape `lionwseed` was landed
-- for in hero_lion.lua.
--
-- ===========================================================================
-- §0  THE VERDICT THIS FILE CARRIES:  DO NOT LAND THE WK COPY (yet)
-- ===========================================================================
--
-- The WK copy has a BRANCH domain of one frame and a DECISION domain of ZERO,
-- and the second number is the one that decides whether an id is worth landing.
-- Measured 2026-09-18 on the whole corpus (both directories, 51 live-WK
-- frames), driving the real X.SkillsComplement + X.ConsiderQ:
--
--     live-WK frames .................................. 51
--     J.IsInTeamFight( bot, 1200 ) true ...............  2
--     ... and every legal candidate projecting 0 ......  2   <- the seed bites
--     ... and arming the seed moves the DECISION ......  0   <- the domain
--
-- ⭐⭐ THE HEADLINE IS THE THIRD RUNG, AND IT IS NEW.  The charter's `-201`
-- bought "a branch-internal all-zero SET is not a domain" (it does not ask
-- whether the leg is reached).  This round buys the rung above it: ⛔ EVEN A
-- FRAME WHERE THE BRANCH DEMONSTRABLY FIRES CAN HAVE AN EMPTY DOMAIN.  On
-- tests/frames/f_260909_215040_wk_blast_sb_661.lua the seed is the ONLY thing
-- between the 团战 branch and a cast -- a mutation stand that marks each firing
-- point's return proves it, seed 0 -> the marker never prints, seed -1 -> the
-- marker prints on exactly that frame (tools/agent/mutstand_wkqfightseed.sh,
-- control C1/C2) -- and the end-to-end decision is STILL byte-identical,
-- because firing point 10 answers with THE SAME TARGET.
--
-- ⭐ AND THAT IS THIS FILE'S OWN THIRD CONJUNCT, BOUGHT.  hero_skeleton_king.lua
-- already carries it, written for `wkqdmg` and labelled "closed form, not a
-- corpus reading":
--
--     AND no downstream firing point returns the same target on that frame
--
-- ⇒ it now has a measured instance, with the masking point NAMED (point 10, the
-- universal catch-all -- the same one the charter's `-203` studied for
-- `wkqaim`).  ⛔ The closed-form argument is not weakened by this; what changed
-- is that the conjunct stopped being something a round could forget to apply.
--
-- ===========================================================================
-- §0.1  WHY ZERO IS THE ORDINARY READING, NOT AN EXOTIC ONE
-- ===========================================================================
--
-- GetEstimatedDamageToTarget is RETROSPECTIVE: it answers for damage the enemy
-- actually dealt to THIS bot inside the window (GH #873 corrected the "always
-- 0 on fixtures" prose; the accurate statement has been at
-- tests/test_chasering_target_in_ring.lua:48 all along).  An enemy who has not
-- connected on this bot reads 0 -- in a teamfight, the ordinary state of every
-- enemy currently hitting somebody else.  ⇒ the all-zero set is common, which
-- is why the seed is worth measuring at all, and why "the domain is empty" is
-- a statement about the DOWNSTREAM POINTS rather than about the meter.
--
-- ===========================================================================
-- §0.2  ⛔ THREE LIMITS -- QUOTING THIS FILE MEANS QUOTING THEM
-- ===========================================================================
--
-- 1. ⛔ EMPTY ON THIS CORPUS IS NOT EMPTY IN PLAY.  144 frames, 51 with a live
--    WK, TWO of them in a teamfight.  That is a sample, and a small one on the
--    axis that matters.  ⛔ Never write "the WK seed can never matter"; write
--    "no frame in the repo separates the two seeds end to end."  The baton for
--    the frame that would is iterations/queue.json:hero-104.
-- 2. ⛔ THE TWO TEAMFIGHT FRAMES ARE BLOCKED FOR TWO INDEPENDENT REASONS, so
--    this is not one mechanism measured twice: sb_661 is masked DOWNSTREAM
--    (point 10 answers with the same target), zeus_ult_1008 is refused UPSTREAM
--    (Q carries 2.4s of cooldown, so X.ConsiderQ returns at its first line and
--    the branch is never reached).  A repair to either does not touch the other.
-- 3. ⚠️ SECTIONS 2 AND 5 TRANSCRIBE THE LOOP'S LEGALITY CHAIN.  The end-to-end
--    readings (§3, §4) drive the shipped function and transcribe nothing; the
--    census and the tripwire have to re-type the conjunction to know which
--    candidates the loop would consider.  If the shipped chain changes, §6.2
--    goes red -- that guard is why the transcription is allowed to exist here.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local WK      = 'npc_dota_hero_skeleton_king'
local SRC     = 'bots/BotLib/hero_skeleton_king.lua'
local Q       = 'skeleton_king_hellfire_blast'
local RING    = 43     -- X.ConsiderQ's own search ring: nCastRange + 43
local FIGHT_R = 1200   -- the branch's J.IsInTeamFight radius

-- ⭐ BOTH directories.  tests/frames/README.md: "Any scan that claims to read
-- 'the tree' rather than 'the corpus' has to enumerate tests/frames/ too."  This
-- file claims the tree in §0 and §5, so it enumerates both from its first round
-- -- the charter's `-203` paid for that lesson on a sibling file that adopted
-- the scope without adopting the enumeration.
local CORPUS_DIRS = { 'tests/fixtures', 'tests/frames' }

-- ⭐⭐ THE COVERAGE CHECK POINTS AT THIS LIST, NOT AT THE ONE ABOVE, AND THAT IS
-- THE WHOLE LESSON.  A guard written against CORPUS_DIRS asks "did each
-- directory I read yield frames" -- a question a narrowed walk answers YES to,
-- because the directory it dropped is no longer in the list it iterates.  The
-- omission is invisible to a check that ranges over what is present, which is
-- the same shape as tests/frames/README.md's own `rg -l 'tests/frames' tests/`
-- (charter `-203`).  REQUIRED_DIRS is the claim; CORPUS_DIRS is the
-- implementation; §1.1 compares them.
local REQUIRED_DIRS = { 'tests/fixtures', 'tests/frames' }

-- The two frames the census lands on today.  Named, never assumed: §2.2 asserts
-- the teamfight set is exactly these, so a corpus that grows a third one turns
-- this file red rather than letting it publish a stale universal.
local PIN_MASKED  = 'tests/frames/f_260909_215040_wk_blast_sb_661.lua'
local PIN_REFUSED = 'tests/frames/f_260909_215227_zeus_ult_1008.lua'

-- Floors, not equalities: the corpus only grows, and a file that goes red on
-- size alone is the `-145`/`-149` family.
local LIVE_WK_FLOOR = 51
local FIRING_POINTS = 10

local T = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Every frame chunk in the corpus, deduplicated BY BASENAME (a frame staged in
--- one directory and landed in the other must be read once, or the floors below
--- inflate).
local function fixture_files()
    local files, seen, per_dir = {}, {}, {}
    for _, dir in ipairs(CORPUS_DIRS) do
        per_dir[dir] = 0
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit in
        -- tests/test_bots_walk_farm_only.py in this same work unit (GH #803).
        local p = io.popen('ls ' .. dir .. ' 2>/dev/null')
        if p then
            for line in p:lines() do
                if line:match('^f_.+%.lua$') and not seen[line] then
                    seen[line] = true
                    files[#files + 1] = dir .. '/' .. line
                    per_dir[dir] = per_dir[dir] + 1
                end
            end
            p:close()
        end
    end
    table.sort(files)
    return files, per_dir
end

--- Is `unit` alive on this frame?  Read off the chunk, without paying for
--- rf.load -- loading is the expensive part of the census below.
local mALIVE = {}
local function alive(path, unit)
    local set = mALIVE[path]
    if set == nil then
        set = {}
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            for _, u in ipairs(chunk.units or {}) do
                if u.alive == true then set[u.name] = true end
            end
        end
        mALIVE[path] = set
    end
    return set[unit] == true
end

--- ⚠️ TRANSCRIBED (limit 3): the 团战 loop's legality chain, byte for byte off
--- hero_skeleton_king.lua.  §6.2 asserts the shipped chain still reads this way.
local function is_legal_candidate(J, e)
    return J.IsValid(e)
        and J.CanCastOnNonMagicImmune(e)
        and J.CanCastOnTargetAdvanced(e)
        and not J.IsDisabled(e)
        and not e:IsDisarmed()
end

--- One frame, driven end to end: the shipped dispatch, then the shipped
--- X.ConsiderQ, then the branch's own reads.  ⛔ Nothing is injected -- no
--- cooldown lifted, no spec patched, gates all off.
local mDRIVE = {}
local function drive(path)
    local row = mDRIVE[path]
    if row ~= nil then return row end
    row = {}
    local ok, err = pcall(function()
        local J, bot = rf.load(path, WK)
        J.IsModeTurbo = function() return true end
        J.IsSoakCandidate = function() return false end
        local hQ = bot:GetAbilityByName(Q)
        row.level     = hQ and hQ:GetLevel() or -1
        row.cooldown  = hQ and hQ:GetCooldownTimeRemaining() or -1
        row.castable  = (hQ ~= nil) and hQ:IsFullyCastable() or false
        row.teamfight = J.IsInTeamFight(bot, FIGHT_R) and true or false

        local cr = (hQ and hQ:GetCastRange() or 0)
        row.cast_range = cr
        row.legal, row.zeros, row.first_legal = 0, 0, nil
        for _, e in pairs(J.GetNearbyHeroes(bot, cr + RING, true, BOT_MODE_NONE)) do
            if is_legal_candidate(J, e) then
                row.legal = row.legal + 1
                if row.first_legal == nil then row.first_legal = e:GetUnitName() end
                if e:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL) == 0 then
                    row.zeros = row.zeros + 1
                end
            end
        end
        row.all_zero = (row.legal > 0 and row.zeros == row.legal)

        local X = rf.load_hero('skeleton_king')
        X.SkillsComplement()
        local d, t = X.ConsiderQ()
        row.desire = d
        row.target = (type(t) == 'table' and t.GetUnitName and t:GetUnitName()) or nil
    end)
    row.err = (not ok) and tostring(err) or nil
    mDRIVE[path] = row
    return row
end

--- Every live-WK frame, driven once.
local mCENSUS = nil
local function census()
    if mCENSUS ~= nil then return mCENSUS end
    local rows = {}
    for _, path in ipairs((fixture_files())) do
        if alive(path, WK) then
            local row = drive(path)
            row.path = path
            rows[#rows + 1] = row
        end
    end
    mCENSUS = rows
    return rows
end

--- The body of X.ConsiderQ, cut on the function rather than on a prose needle.
local function consider_q_body()
    local src = read_file(SRC)
    local i = assert(src:find('\nfunction%s+X%.ConsiderQ%s*%('), 'X.ConsiderQ not found in ' .. SRC)
    local rest = src:sub(i + 1)
    return rest:sub(1, assert(rest:find('\nend\n'), 'no terminating end for X.ConsiderQ'))
end

--- Source with `--` comments stripped, so a source census counts CODE.  This
--- file's own header quotes its literals constantly and so does the shipped one.
local function code_only(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

-- ------------------------------------------------------------- section 1 --
-- COVERAGE.  The check pointed the other way: not "which scans enumerate
-- tests/frames" (a grep finds only the ones that already do) but "does THIS
-- file's enumeration cover the directories its universals range over".

T['§1.1 the corpus walk enumerates BOTH frame directories, and neither is empty'] = function()
    local files, per_dir = fixture_files()
    for _, dir in ipairs(REQUIRED_DIRS) do
        assert((per_dir[dir] or 0) > 0, 'REQUIRED corpus directory ' .. dir .. ' contributed no '
            .. 'f_*.lua frame to this file\'s walk.  Every universal here ranges over BOTH '
            .. 'directories; one that is dropped from CORPUS_DIRS -- or that silently lists '
            .. 'nothing -- turns the verdict in §0 into a statement about the other half, and '
            .. 'says so nowhere.  ⛔ Do NOT repair this by narrowing REQUIRED_DIRS.')
    end
    assert(#files >= 140, 'the corpus walk sees only ' .. #files .. ' frames, floor 140 -- '
        .. 'frames do not leave the tree, so this is an enumeration fault, not a shrinking corpus')
end

-- ------------------------------------------------------------- section 2 --
-- THE CENSUS.  Which frames can even ask the question.

T['§2.1 the live-WK population is at or above its measured floor'] = function()
    local rows = census()
    local errs = {}
    for _, r in ipairs(rows) do
        if r.err then errs[#errs + 1] = r.path .. ': ' .. r.err end
    end
    assert(#errs == 0, 'the census could not drive ' .. #errs .. ' frame(s); a frame that '
        .. 'errors is NOT a frame that declines:\n  ' .. table.concat(errs, '\n  '))
    assert(#rows >= LIVE_WK_FLOOR, 'only ' .. #rows .. ' live-WK frames, floor '
        .. LIVE_WK_FLOOR .. ' (measured 2026-09-18).  A corpus that grew is fine; one that '
        .. 'shrank means the walk lost a directory and every number in §0 is understated.')
end

T['§2.2 ⭐ exactly two frames reach the branch\'s entry predicate -- and both are all-zero'] = function()
    local fight, allzero = {}, {}
    for _, r in ipairs(census()) do
        if r.teamfight then
            fight[#fight + 1] = r.path
            if r.all_zero then allzero[#allzero + 1] = r.path end
        end
    end
    table.sort(fight)
    assert(#fight == 2, 'the teamfight set is now ' .. #fight .. ' frame(s), was 2:\n  '
        .. table.concat(fight, '\n  ') .. '\n⭐ A THIRD ONE IS NEWS, not noise: §0\'s verdict '
        .. 'is "no frame separates the two seeds end to end", and a new teamfight frame is the '
        .. 'only kind of frame that can falsify it.  Drive it through §3\'s two questions '
        .. '(is it masked downstream / is it refused upstream) before re-quoting §0.')
    assert(fight[1] == PIN_MASKED or fight[2] == PIN_MASKED, PIN_MASKED
        .. ' is no longer in the teamfight set; §3 measures nothing')
    assert(fight[1] == PIN_REFUSED or fight[2] == PIN_REFUSED, PIN_REFUSED
        .. ' is no longer in the teamfight set; §4 measures nothing')
    assert(#allzero == 2, 'only ' .. #allzero .. ' of the 2 teamfight frames carry an all-zero '
        .. 'candidate set, was 2 -- if a candidate started projecting a positive number the seed '
        .. 'cannot bite there and that frame stops being evidence either way')
end

-- ------------------------------------------------------------- section 3 --
-- ⭐⭐ THE MASKED WITNESS, DRIVEN, NOTHING INJECTED.  This is the frame where
-- the seed genuinely gates the branch (the stand's C1/C2 controls prove it) and
-- the decision still does not move.

T['§3.1 ⛔ NOTHING is injected on the masked pin -- pin the reads that make that true'] = function()
    local r = drive(PIN_MASKED)
    assert(r.err == nil, 'the masked pin failed to drive: ' .. tostring(r.err))
    assert(r.level >= 1, 'Blast is unlearned on the masked pin (' .. r.level
        .. '); X.ConsiderQ returns at its first line and §3 is measuring nothing')
    assert(r.cooldown == 0, 'Blast now carries ' .. r.cooldown .. 's of cooldown on the masked '
        .. 'pin.  The whole point of §3 is that it pays NO counterfactual -- if that stopped '
        .. 'being true, say so, do not start injecting.')
    assert(r.castable, 'Blast is not fully castable on the masked pin as recorded')
    assert(r.teamfight, 'the masked pin no longer clears J.IsInTeamFight')
    assert(r.legal == 1, 'the masked pin carries ' .. r.legal .. ' legal candidates, was 1')
    assert(r.all_zero, 'the sole candidate no longer projects 0, so the shipped seed does not '
        .. 'bite here and this frame stops demonstrating the veto')
end

T['§3.2 ⭐⭐ the branch is vetoed AND the decision is unchanged -- point 10 answers first'] = function()
    local r = drive(PIN_MASKED)
    -- The shipped answer exists and names a target.  It cannot have come from
    -- the 团战 branch: that branch's argmax is all-zero (§3.1), so its winner is
    -- nil under a seed of 0.  The stand names the point that did answer (10).
    assert(r.desire == BOT_ACTION_DESIRE_HIGH, 'shipped X.ConsiderQ bids ' .. tostring(r.desire)
        .. ' on the masked pin, was BOT_ACTION_DESIRE_HIGH.  If NOBODY answers here any more, '
        .. 'the decision domain just became NON-EMPTY and `wkwseed` is worth landing -- '
        .. 're-read §0 and §5.1 before quoting either.')
    assert(r.target == 'npc_dota_hero_spirit_breaker', 'shipped X.ConsiderQ targets '
        .. tostring(r.target) .. ' on the masked pin, was npc_dota_hero_spirit_breaker')
    -- ⭐ THE CONJUNCT, AS AN ASSERTION: the downstream point answers with the
    -- SAME unit the armed argmax would pick, so the two legs are
    -- indistinguishable by anything X.ConsiderQ returns.
    assert(r.first_legal == r.target, 'the masked pin\'s armed-argmax pick ('
        .. tostring(r.first_legal) .. ') and the shipped answer (' .. tostring(r.target)
        .. ') are no longer the same unit.  THE MASKING IS WHAT MAKES THE DOMAIN EMPTY: two '
        .. 'different targets means arming the seed changes the decision, which is exactly the '
        .. 'evidence §0 says the repo does not have.')
end

T['§3.3 ⭐ all ten firing points return the SAME desire constant -- target identity is the only observable'] = function()
    local body = code_only(consider_q_body())
    local n = 0
    for _ in body:gmatch('return%s+BOT_ACTION_DESIRE_HIGH') do n = n + 1 end
    assert(n == FIRING_POINTS, 'X.ConsiderQ now has ' .. n .. ' firing points returning '
        .. 'BOT_ACTION_DESIRE_HIGH, was ' .. FIRING_POINTS .. '.  This count is load-bearing for '
        .. '§3.2: the file\'s own third conjunct ("no downstream firing point returns the same '
        .. 'target on that frame") is only decidable because every point returns the same '
        .. 'constant and differs ONLY in the target.')
    -- And the branch under study is one of them, spelled the shipped way.
    assert(body:find('return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy', 1, true) ~= nil,
        'the 团战 branch no longer returns npcMostDangerousEnemy -- §3 is about a branch that '
        .. 'no longer exists in that shape')
end

-- ------------------------------------------------------------- section 4 --
-- THE SECOND TEAMFIGHT FRAME, REFUSED UPSTREAM.  A different mechanism, stated
-- rather than folded into §3 (limit 2).

T['§4.1 the other teamfight frame is refused at X.ConsiderQ\'s FIRST line, not by the seed'] = function()
    local r = drive(PIN_REFUSED)
    assert(r.err == nil, 'the refused pin failed to drive: ' .. tostring(r.err))
    assert(r.teamfight, 'the refused pin no longer clears J.IsInTeamFight')
    assert(r.all_zero, 'the refused pin no longer carries an all-zero candidate set')
    assert(r.cooldown > 0, 'Blast now reads ' .. r.cooldown .. 's of cooldown on the refused '
        .. 'pin, was 2.4.  If it went castable this frame moved from the UPSTREAM blocker to '
        .. 'the downstream question and has to be re-driven through §3, not quoted through §4.')
    assert(not r.castable, 'Blast is fully castable on the refused pin now')
    assert(r.desire == 0, 'shipped X.ConsiderQ bids ' .. tostring(r.desire) .. ' on the refused '
        .. 'pin, was 0 -- a not-fully-castable ability returns BOT_ACTION_DESIRE_NONE at the '
        .. 'first line, and every branch below it, seeded either way, is unreachable')
end

-- ------------------------------------------------------------- section 5 --
-- THE TRIPWIRE.  ⭐ The one assertion that hands the next round the work: it
-- goes red the day the corpus holds a frame where arming the seed WOULD move a
-- decision.  Both halves of "would move" are asked, because they fail
-- differently: nobody answers at all, or somebody answers with a DIFFERENT unit.

T['§5.1 ⭐ TRIPWIRE -- no frame where the seed\'s veto costs a cast outright'] = function()
    local hits = {}
    for _, r in ipairs(census()) do
        if r.teamfight and r.all_zero and r.castable and r.desire == 0 then
            hits[#hits + 1] = r.path
        end
    end
    assert(#hits == 0, 'THE DECISION DOMAIN IS NO LONGER EMPTY -- on ' .. #hits
        .. ' frame(s) the 团战 branch holds a legal candidate, every downstream point declines, '
        .. 'and shipped X.ConsiderQ bids nothing:\n  ' .. table.concat(hits, '\n  ')
        .. '\n⇒ this is the frame iterations/queue.json:hero-104 asked for.  LAND `wkwseed` '
        .. '(gated, turbo-only, seed -> -1, the hero_lion.lua X.lion_FightArgmaxSeed shape) and '
        .. 'pin it -- and update §0, which says the repo holds no such frame.')
end

T['§5.2 ⭐ TRIPWIRE -- no frame where the masking point answers with a DIFFERENT unit'] = function()
    local hits = {}
    for _, r in ipairs(census()) do
        if r.teamfight and r.all_zero and r.castable and r.desire ~= 0
            and r.first_legal ~= nil and r.target ~= nil and r.first_legal ~= r.target then
            hits[#hits + 1] = r.path .. ' (armed would pick ' .. r.first_legal
                .. ', shipped answers ' .. r.target .. ')'
        end
    end
    assert(#hits == 0, 'THE DECISION DOMAIN IS NO LONGER EMPTY, by the OTHER half -- on '
        .. #hits .. ' frame(s) a downstream point answers, but with a different unit than the '
        .. 'armed argmax would choose:\n  ' .. table.concat(hits, '\n  ')
        .. '\n⇒ same baton as §5.1, and note this half is the one the closed-form conjunct in '
        .. 'hero_skeleton_king.lua predicts is POSSIBLE: all ten points return the same desire, '
        .. 'so target identity is where a difference can hide.  ⚠️ The armed pick is read '
        .. 'through this file\'s TRANSCRIBED legality chain (limit 3) -- re-drive before '
        .. 'quoting the number.')
end

-- ------------------------------------------------------------- section 6 --
-- RETIREMENT AND TRANSCRIPTION GUARDS.  A verdict file is quoted by later
-- rounds as the reason NOT to do something; a reading it can no longer make is
-- worse than a missing file.

T['§6.1 the shipped seed is still the literal 0 -- if it moved, this verdict is spent'] = function()
    local body = code_only(consider_q_body())
    assert(body:find('local nMostDangerousDamage = 0', 1, true) ~= nil,
        'X.ConsiderQ no longer seeds its 团战 argmax with the literal 0.  If a later round '
        .. 'landed the gated seed (`wkwseed` or any name), THIS FILE IS RETIRED: it exists to '
        .. 'explain why nobody landed it, and it must not go on saying so while one is on the '
        .. 'tree.  Fold §0\'s readings into the new id\'s own file and delete this one.')
    assert(body:find('wkwseed', 1, true) == nil,
        'a `wkwseed` gate now exists in ' .. SRC .. ' -- see the message above; this file is '
        .. 'retired the moment it does')
end

T['§6.2 the transcribed legality chain still matches the shipped loop'] = function()
    local body = consider_q_body()
    -- The 团战 loop, from its seed to its comparison.  ⚠️ Anchored on the seed
    -- line so the sibling loops in this same function cannot satisfy it.
    local i = assert(body:find('local nMostDangerousDamage = 0', 1, true),
        'seed line not found -- §6.1 has already said what that means')
    local seg = code_only(body:sub(i, i + 1200))
    for _, needle in ipairs({
        'J.IsValid( npcEnemy )',
        'J.CanCastOnNonMagicImmune( npcEnemy )',
        'J.CanCastOnTargetAdvanced( npcEnemy )',
        'not J.IsDisabled( npcEnemy )',
        'not npcEnemy:IsDisarmed()',
        'npcEnemyDamage > nMostDangerousDamage',
    }) do
        assert(seg:find(needle, 1, true) ~= nil, 'the shipped 团战 loop no longer contains "'
            .. needle .. '".  §2 and §5 TRANSCRIBE this chain (limit 3) to know which candidates '
            .. 'the loop would consider; a chain that moved makes every count in those sections '
            .. 'a count of a different set.  Re-read is_legal_candidate before touching the '
            .. 'numbers.')
    end
    -- The ring, too: the census builds nCastRange + 43 off the same literal.
    assert(seg:find('nEnemysHerosInRange', 1, true) ~= nil,
        'the 团战 loop no longer iterates nEnemysHerosInRange (the nCastRange + 43 ring); the '
        .. 'census in §2 is counting a different ring than the branch reads')
end

return T
