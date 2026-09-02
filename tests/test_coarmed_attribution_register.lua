-- [ratchet] A conjunction is formed at the CALL SITE, not at the gate literal
-- -- so "this id has no conjunct" is certified at an address that does not
-- decide, and the arm string is the other half of the answer.
--
-- WHAT THIS FILE ADDS TO test_gated_helper_nesting_census.lua. That file asks
-- the FREEZE question about bots/ alone: arm only the outer id and the inner is
-- un-armed, so the lever can be a byte-for-byte no-op. This file asks the
-- ATTRIBUTION question, which needs a second input the tree never joined in --
-- `iterations/streams/test_set.md`, the armed set. When the inner id is armed
-- TOO (which is what an all-on wave does), nothing is frozen and everything
-- still moves: the outer id's per-id (a) reading -- the trigger-level frame
-- count the replay desk reports on the armed leg -- is no longer the outer id's.
-- It is `outer AND inner`, and the wave attributes it to whichever id the
-- request line was filed under.
--
-- THIS IS THE CAVEAT THE DIRECTOR HAS BEEN WRITING BY HAND. test_set.md SS BW.3
-- (`campexit`: "(a) must not be read from the armed-baseline differential --
-- campfarm/campvoid are moving the same frames") and SS CG.4 (`fieldsip`: "(a)
-- must not be read from the stayfield/stayfield2 hold-rate differential -- four
-- ids act on those frames") are two hand-discovered instances of exactly this
-- relation, each found by a human reading source at admission time. Nothing
-- computes it, so the third one is found the same way or not at all.
--
-- **THE FINDING.** The certification that is actually performed reads the
-- gate's OWN line and counts `IsSoakCandidate` calls in it:
--
--   * `tpreach`, test_set.md SS BC.3 -- "the gate is its own single line
--     (IsModeTurbo and tpreach) => NO CONJUNCT, no SS BA.2 freeze risk".
--     True of the gate. But `J.CanEnemyInterruptTpChannel` is CALLED from
--     jmz_func.lua:8312, which is inside `J.ShouldTpSupportTowerFight`, past
--     that function's own `midtp`/`suptp` gate at :8288 -- and midtp and suptp
--     are both armed today. Armed `tpreach` widens the interrupt scan 700->1200,
--     so it returns true more often, so ShouldTpSupportTowerFight returns nil
--     more often. `midtp`/`suptp` measure `midtp AND NOT tpreach-veto`.
--   * `pulldrag`, test_set.md line 176 -- "the gate is a standalone line (turbo
--     + pulldrag), NOT conjoined with pullcamp -- avoiding the pullcad trap".
--     Also true of the gate, and the avoidance was deliberate. But the call site
--     (mode_roam_generic.lua:363) sits behind the gated EARLY RETURN at :224:
--     un-armed `pullthink` lets the think-throttle `return` before :363 is ever
--     reached, and armed `pullthink` also takes the :321 `elseif` that skips the
--     :354 branch the call lives in. `pullthink` is armed. It both adds and
--     removes frames from `pulldrag`'s call site, and neither is a nested gate.
--
-- => The trap was avoided at the address that was checked and stepped into at
-- the address that decides. Reusable discriminant, and cheap: for each armed id,
-- do not read its gate -- read who calls its helper.
--
-- **THE DATED CONSEQUENCE.** `fieldsip` was admitted 2026-08-29T18:5xZ (44->45).
-- Its helper is read inside `J.ShouldFieldBuyRegen`, which is `fieldbuy`'s gate
-- (jmz_func.lua: `return not ( J.HasFieldRegenSource( bot ) and
-- J.IsFieldSipEnough( bot ) )`). `fieldbuy` has been armed since before that and
-- its (a) is still pending. So at 18:5xZ, WITHOUT ANY EDIT TO fieldbuy AND
-- WITHOUT ANYTHING SAYING SO, what `fieldbuy`'s armed leg counts changed: it now
-- fires on `not source OR not sip-enough` where it used to fire on `not source`.
-- A `fieldbuy` trigger count from the wave before that admission and one from
-- the wave after are not the same measurement. SS CG.4 warned about fieldsip's
-- own (a) and named stayfield/stayfield2; it did not say that admitting fieldsip
-- re-defined an already-registered reading belonging to a different id.
--
-- **WHY THE PREVIOUS ROUND CONCLUDED "not a live problem" AND WAS RIGHT ABOUT
-- THE WRONG NODE.** Charter `0CONJ` registered `J.IsInLaningPhase` -- read by 13
-- other gated helpers -- and closed it as non-live because its ids `c2`/`c4` are
-- not armed. That is correct and it is still correct below (`c2`/`c4` are the
-- largest fan-out in the tree at 15 call sites each, and are safe precisely
-- because a predicate that central is the one nobody admits). The register was
-- not answered by that, because RANKING BY FAN-OUT RANKS BY POTENTIAL. The live
-- confounds are every one of them at fan-out 1: small, local, unremarkable
-- predicates whose ids are armed exactly because they are small. The question is
-- answered by the JOIN with the arm string, never by the maximum.
--
-- **WHY AN INVARIANT AND NOT A PINNED SNAPSHOT.** The director already ruled
-- this (GH #221/#276, in tests/test_carrier_terms.py): "a test that goes red
-- every time the arm string it reads is edited is re-stating the arm string, not
-- checking the deriver". So the claim below is CONTAINMENT, not equality:
-- live pairs must be a subset of the acknowledged ones. Retiring an id, or
-- admitting one that creates no new pair, stays green. Only an admission that
-- creates a NEW (outer, inner) confound reddens -- which is the one moment the
-- caveat has to be written, and the moment nothing else in the tree raises a
-- hand.
--
-- **WHAT THIS DOES NOT ESTABLISH.** Membership in the register is not a verdict
-- that the confound is large, or that the outer id is wrong. It says the two
-- ids' (a) readings are not independent on the same leg. Over-inclusive on
-- purpose, the same direction as the census: "nested" means the call sits
-- anywhere in the caller's body, so rows through a wide dispatch body
-- (`ItemPurchaseThink`) are counted although the two gates may never meet on a
-- frame. A wider net cannot miss the pair that matters and a false row costs one
-- read; deciding by indentation what the wave decides by arithmetic would not.
-- Each entry below therefore carries the reading that was actually done.

local BOTS_ROOT = 'bots'
local TEST_SET = 'iterations/streams/test_set.md'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local text = fh:read('*a')
    fh:close()
    return text
end

--- Source with every comment removed, as a line array.
--
-- Load-bearing in both directions and this repo has paid for both: a comment
-- that QUOTES a call must not be counted as one (GH #300), and a real call must
-- not be hidden. Long comments first, then `--` to end of line -- a one-line
-- `--[[ ]]` is already killed by the second pass, which is why the control
-- below uses a MULTI-line block (a single-line control left the long-comment
-- gsub unfalsifiable in the sister census's first draft).
local function strip_comments(src)
    src = src:gsub('%-%-%[==%[.-%]==%]', '')
    src = src:gsub('%-%-%[%[.-%]%]', '')
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        local i = line:find('--', 1, true)
        out[#out + 1] = i and line:sub(1, i - 1) or line
    end
    return out
end

--- Every top-level function in one file, with the gate ids its body names.
local function functions_in(lines, path)
    local funcs, i, n = {}, 1, #lines
    while i <= n do
        local name = lines[i]:match('^function%s+([%a_][%w_.:]*)%s*%(')
            or lines[i]:match('^local%s+function%s+([%a_][%w_.:]*)%s*%(')
        if name then
            local j = i + 1
            while j <= n and lines[j]:gsub('%s+$', '') ~= 'end' do j = j + 1 end
            local body = table.concat(lines, '\n', i, math.min(j, n))
            local ids = {}
            for id in body:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do
                ids[id] = true
            end
            funcs[#funcs + 1] = { name = name, file = path, body = body, ids = ids }
            i = j + 1
        else
            i = i + 1
        end
    end
    return funcs
end

local function has_id(f)
    for _ in pairs(f.ids) do return true end
    return false
end

--- Nesting rows: a gated helper called from inside a DIFFERENT id's helper.
--
-- Name resolution is deliberately narrow. `J.*` lives in one global table and is
-- reachable everywhere; anything else must be defined in the SAME file as the
-- caller, or the short name `GetBoundAbility` cross-links two hero files and
-- invents conjunctions no game can execute.
local function nesting_rows(funcs)
    local rows = {}
    for _, caller in ipairs(funcs) do
        if has_id(caller) then
            for _, callee in ipairs(funcs) do
                local reachable = callee.name:sub(1, 2) == 'J.'
                    or callee.file == caller.file
                local disjoint = has_id(callee)
                if disjoint then
                    for id in pairs(caller.ids) do
                        if callee.ids[id] then disjoint = false end
                    end
                end
                if callee ~= caller and reachable and disjoint then
                    local short = callee.name:match('([%w_]+)$')
                    if caller.body:find('[.:]' .. short .. '%s*%(') then
                        rows[#rows + 1] = { caller = caller, callee = callee }
                    end
                end
            end
        end
    end
    return rows
end

--- The join: (outer id, inner id) pairs where BOTH sides are armed.
local function coarmed_pairs(rows, armed)
    local seen, out = {}, {}
    for _, r in ipairs(rows) do
        for outer in pairs(r.caller.ids) do
            if armed[outer] then
                for inner in pairs(r.callee.ids) do
                    if armed[inner] then
                        local key = outer .. ' > ' .. inner
                        if not seen[key] then
                            seen[key] = true
                            out[#out + 1] = key
                        end
                    end
                end
            end
        end
    end
    table.sort(out)
    return out
end

local function funcs_from(sources)
    local funcs = {}
    local paths = {}
    for path in pairs(sources) do paths[#paths + 1] = path end
    table.sort(paths)
    for _, path in ipairs(paths) do
        for _, f in ipairs(functions_in(strip_comments(sources[path]), path)) do
            funcs[#funcs + 1] = f
        end
    end
    return funcs
end

local function tree_funcs()
    local files = {}
    -- The two gitignored, farm-only files under bots/Customize/ are skipped:
    -- `soak_side.lua` is created and deleted by every gate test in this suite,
    -- so listing it and then `read_file`-ing it (which asserts) is a race that
    -- surfaces as `cannot open <that switch>` from THIS file -- a red that
    -- names neither this file's subject nor a real defect. (The literal
    -- path is deliberately NOT spelled out in this comment: prose alone
    -- would enrol this file in test_soakside_shared_switch.lua's census of
    -- files that reach the switch, which is why that census excludes
    -- itself for the same reason.)
    -- a red that names neither this file's subject nor a real defect. Measured
    -- 2026-09-02: 2/6 runs red under a churn loop, 0/6 after this line. It is
    -- not bot logic and it carries no gated helper, so nothing here reads it
    -- on purpose. Same reasoning as tests/lua_source_scan.lua's bots_files().
    local p = assert(io.popen('find ' .. BOTS_ROOT
        .. ' -name "*.lua" ! -path "' .. BOTS_ROOT .. '/Customize/soak_*.lua" | sort'))
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    local funcs = {}
    for _, path in ipairs(files) do
        for _, f in ipairs(functions_in(strip_comments(read_file(path)), path)) do
            funcs[#funcs + 1] = f
        end
    end
    return funcs
end

--- The live arm string, as a set.
--
-- Anchored on DOCUMENT ORDER, not a line number (the 0ADDR lesson: a pin that
-- addresses a coordinate is a pin that a compliant commit can move). test_set.md
-- carries the live members string first and 12 historical ones below it -- 13
-- lines match this shape today -- and the file states that convention itself
-- ("SS SS 44 (history)"). So: the FIRST line that is nothing but comma-separated
-- ids, and it must come after the heading. Returns nil + reason; the caller
-- turns that into a FAILURE, never a quiet pass -- a register that reads an
-- empty arm string reports zero confounds, and "zero" is the answer this file
-- publishes.
local function parse_arm(text)
    local seen_heading = false
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        local t = line:gsub('%s+$', '')
        if t:find('当前测试集', 1, true) then seen_heading = true end
        if seen_heading and t:match('^[%w_]+,[%w_,]+$') then
            local set, n = {}, 0
            for id in t:gmatch('[%w_]+') do
                if not set[id] then n = n + 1 end
                set[id] = true
            end
            return set, n
        end
    end
    return nil, 'no comma-separated id line found after the heading'
end

-- The acknowledged confounds. A pair is here because somebody read the two call
-- sites and wrote down what the outer id's (a) actually counts while the inner
-- is armed on the same leg. CONTAINMENT, not equality: pairs leave this list
-- only when the reading is retired, never to make the file green.
local ACKNOWLEDGED = {
    -- REAL conjunction. jmz_func.lua `J.ShouldFieldBuyRegen`:
    -- `return not ( J.HasFieldRegenSource( bot ) and J.IsFieldSipEnough( bot ) )`.
    -- Un-armed `fieldsip` is the literal `true` on its first line, so the shipped
    -- read is `not source`. Armed it is `not source OR not sip-enough`, strictly
    -- wider => `fieldbuy`'s armed-leg trigger count grew on 2026-08-29T18:5xZ
    -- without fieldbuy being touched. Cross-wave fieldbuy (a) readings straddle
    -- that date and are not comparable.
    ['fieldbuy > fieldsip'] = true,
    -- REAL conjunction, same helper one line up: `J.IsFieldRegenSituation` is
    -- `fieldcreep`'s. It is a hard precondition (`if not ... then return false`),
    -- so `fieldbuy`'s domain is `fieldbuy AND fieldcreep` outright.
    ['fieldbuy > fieldcreep'] = true,
    -- WIDE row (over-inclusion, kept). item_purchase_generic.lua
    -- `ItemPurchaseThink` is a long dispatch body carrying `fieldregen` and
    -- `tpdeathbuy` gates elsewhere in it; the `J.ShouldFieldBuyRegen` call is not
    -- known to sit inside either branch. Counted because the whole
    -- fieldregen/tpdeathbuy/fieldbuy/fieldcreep/fieldsip family buys supplies on
    -- the same frames, which is the confound test_set.md SS CG.4 was reaching for.
    ['fieldregen > fieldbuy'] = true,
    ['tpdeathbuy > fieldbuy'] = true,
    -- REAL conjunction, and it contradicts a standing certification.
    -- jmz_func.lua:8312 calls `J.CanEnemyInterruptTpChannel` (tpreach) past the
    -- `midtp`/`suptp` gate at :8288. Armed tpreach widens the scan 700->1200 =>
    -- vetoes more TPs => midtp/suptp count `midtp AND NOT tpreach-veto`.
    -- SS BC.3 certified tpreach "no conjunct" by reading tpreach's own gate line.
    ['midtp > tpreach'] = true,
    ['suptp > tpreach'] = true,
    -- REAL, by a mechanism that is not a nested gate at all: a gated EARLY
    -- RETURN. mode_roam_generic.lua:224 `if not (bot.roamCampPull ~= nil and
    -- J.IsSoakCandidate('pullthink')) and <throttle> then return end` decides
    -- whether :363 (`J.GetLanePullDragTarget`, pulldrag) is reached this frame,
    -- and the armed :321 `elseif` steals frames from the :354 branch the call
    -- lives in. So pullthink both adds and removes frames from pulldrag's call
    -- site. test_set.md line 176 certified pulldrag's gate "standalone, NOT
    -- conjoined with pullcamp -- avoiding the pullcad trap": true of the gate.
    ['pullthink > pulldrag'] = true,
    -- WIDE row (over-inclusion, kept). Same `Think`, but the `pullcad` gate at
    -- :268 is in the `bot.roamCreepPull` block -- a different branch from the
    -- camp-pull one that reaches :363. Read and judged not to meet on a frame;
    -- listed so the reading is on the record rather than the row being narrowed
    -- away by a rule that decides scope by indentation.
    ['pullcad > pulldrag'] = true,
    -- WIDE row, and the ONLY one here whose vacuity is an implication rather
    -- than a judgement call (GH #349, admitted with 'creepthink' 44->47).
    -- Same `Think`. 'creepthink' occurs exactly once in bots/, as the right
    -- operand of `bot.roamCreepPull ~= nil and ...`, and `and` short-circuits.
    -- Reaching `J.GetLanePullDragTarget` needs `bot.roamCampPull ~= nil`, which
    -- implies `roamCreepPull == nil` TWICE OVER: (1) the `if roamCreepPull ~=
    -- nil then ... return end` block sits above the camp block in Think, and
    -- (2) the two fields are written at three sites in GetDesireHelper, each of
    -- which nils the other. So at pulldrag's call site the id's literal is
    -- unreachable and arming it moves no frame there -- driven on a real frame
    -- in tests/test_creepthink_pulldrag_vacuous.lua, where arming 'pullthink'
    -- on the same frame moves 89->0 and 89->75 (the probe is not dead) and
    -- arming 'creepthink' on a live CREEP-pull plan changes the order log
    -- (the arming is not unplumbed). Not registered to make this green.
    -- !! INVALIDATION CONDITION (director 20260831, the half not in GH #349):
    -- acknowledging a row TURNS ITS LIGHT OFF, so name what would make it false
    -- again. Either ground failing does it: (1) the `if roamCreepPull ~= nil
    -- then ... return end` block ceasing to precede the camp block, or (2) any
    -- new write site for roamCampPull/roamCreepPull that does not nil the other.
    -- Then this becomes a REAL conjunction and nothing here raises its hand.
    -- See test_set.md SS CP (the reading) and SS CQ (the ruling).
    ['creepthink > pulldrag'] = true,
    -- REAL conjunction, by the gated EARLY RETURN mechanism (same shape as
    -- `pullthink > pulldrag`), and it is the FIRST row here whose confound is
    -- SIDE-ASYMMETRIC. mode_outpost_generic.lua `GetDesireHelper`: outlatch's
    -- gate is the `local bRescan = ...` at :79, and :45 -- above it -- is
    -- `if J.IsTeamPushingHighGround(bot) then return BOT_MODE_DESIRE_NONE end`,
    -- which IS slotpush's one gate-resolution wrapper (jmz_func.lua:12263).
    -- Every frame that predicate answers TRUE on is a frame that never reaches
    -- :79 => outlatch's armed-leg trigger count is `outlatch AND NOT
    -- slotpush-veto`, and a pre-admission outlatch (a) is a different quantity.
    -- DIRECTION, and it is not symmetric between the sides: armed slotpush
    -- scans 5 of 5 team slots where shipped scans 4 of 5 (radiant, pids 0..4)
    -- or 1 of 5 (dire, pids 5..9). A wider scan can only make "the team is
    -- pushing" EASIER to answer TRUE => the veto fires more often armed =>
    -- frames are REMOVED from outlatch's call site, ~5x more of them on dire
    -- than on radiant. (Not strictly one-way: utils.lua's own header records
    -- that shipped can answer TRUE off a hero whose liveness was never checked,
    -- which armed refuses.) => outlatch's (a) must be registered per stratum;
    -- a two-stratum sign flip on that count is iron rule 4(i-b) noise, because
    -- the estimator has a side-correlated confound, not merely side-correlated
    -- draw. This is the first row here that needs 4(i-b) to be READ, not cited.
    -- THE OVERLAP IS NOT MARGINAL, which is why this row is not a formality:
    -- :79 is unreachable until `IsEnemyTier2Down` (:63), and slotpush's
    -- predicate is TRUE exactly in the late-game state that FOLLOWS tier-2
    -- falling (a teammate near an enemy second-tier or high-ground tower, or
    -- within 3000 of the enemy ancient). The veto therefore lands preferentially
    -- INSIDE outlatch's own domain, not uniformly across the game.
    -- AND IT IS BEHAVIOURAL, not only a measurement artefact: armed outlatch
    -- re-scans at most once per game second (OUTPOST_RESCAN_INTERVAL = 1.0) and
    -- IsTeamPushingSecondTierOrHighGround is memoised for 1 second -- the same
    -- time scale -- so one veto that lands eats one whole rescan slot. Armed
    -- slotpush makes armed outlatch slower to close its latch, in precisely the
    -- phase outlatch exists for.
    -- WHY §DL.3'S READING DOES NOT ALREADY COVER THIS: the strategy desk read
    -- these same three nestings (c3 / outlatch / roshgate outer, slotpush inner)
    -- for test_gated_helper_nesting_census.lua and classified all three as
    -- (P) parameter gates. That is correct and it answers the FREEZE question --
    -- "arm the OUTER alone and the inner is still the shipped answer, so the
    -- lever is not frozen". This file asks the ATTRIBUTION question, which is
    -- about the all-on wave where BOTH are armed, and (P) says nothing there.
    -- !! INVALIDATION CONDITION: acknowledging a row turns its light off.
    -- (1) the :45 early return ceasing to precede the :79 gate in
    --     GetDesireHelper (either moving);
    -- (2) `c3` or `roshgate` entering the arm string -- the other two outer ids
    --     of the same nesting are ALREADY in the census's (P) list, so those two
    --     pairs go live the day either id is admitted and NOTHING here raises
    --     its hand;
    -- (3) `slotpush` being PROMOTED -- then both legs carry the veto and the
    --     confound leaves the differential, but outlatch (a) readings from
    --     before and after that day stay incomparable. Retire this row then,
    --     do not delete it to make anything green.
    -- See test_set.md SS DN.6 (the reading) and GH #424.
    ['outlatch > slotpush'] = true,
}

local tests = {}

-- The whole point. Not equality -- see the header on GH #221/#276.
tests['every co-armed conjunction has been read and acknowledged'] = function()
    local armed, n = parse_arm(read_file(TEST_SET))
    assert(armed ~= nil, 'could not read the arm string from ' .. TEST_SET
        .. ' (' .. tostring(n) .. '); a register that cannot see the armed set '
        .. 'reports zero confounds, and zero is what this file publishes')
    local live = coarmed_pairs(nesting_rows(tree_funcs()), armed)

    local new = {}
    for _, key in ipairs(live) do
        if not ACKNOWLEDGED[key] then new[#new + 1] = key end
    end
    assert(#new == 0, 'a NEW co-armed conjunction is live:\n      '
        .. table.concat(new, '\n      ')
        .. '\n    An id was admitted whose helper is read inside another ARMED '
        .. "id's gated function (or vice versa). Both ids move on the same leg, "
        .. "so the outer id's per-id (a) -- its armed-leg trigger count -- now "
        .. 'measures `outer AND inner`, and any (a) reading taken before this '
        .. 'admission is a different measurement. Read the two call sites, write '
        .. 'the caveat into the admission section of ' .. TEST_SET .. ' the way '
        .. 'SS BW.3 and SS CG.4 do, then add the pair to ACKNOWLEDGED with what '
        .. 'you read. Do NOT add it to make this green.')
end

-- A register whose extractor breaks reads clean, and clean is the published
-- answer. Floors, not equalities (GH #273): growth must not renumber them.
tests['the extractor still sees the tree it is reading'] = function()
    local funcs = tree_funcs()
    local nGated = 0
    for _, f in ipairs(funcs) do
        if has_id(f) then nGated = nGated + 1 end
    end
    assert(nGated >= 80, 'only ' .. nGated .. ' gated helper(s) in ' .. BOTS_ROOT
        .. '; the tree had 91 on 2026-08-29, so the extractor is what changed')
    assert(#nesting_rows(funcs) >= 40, 'the nesting census collapsed to '
        .. #nesting_rows(funcs) .. ' row(s); it had 45 on 2026-08-29')
end

tests['the arm string parses, and a failure to parse is a failure'] = function()
    local armed, n = parse_arm(read_file(TEST_SET))
    assert(armed ~= nil, 'arm string unreadable: ' .. tostring(n))
    assert(n >= 40, 'parsed only ' .. n .. ' armed id(s) from ' .. TEST_SET
        .. '; the set was 45 on 2026-08-29 and a short read silently shrinks '
        .. 'the join this file exists to compute')
    -- Prose must not be mistaken for the arm string, and the FIRST match must
    -- win -- the file carries 12 historical members strings of the same shape.
    local synthetic = table.concat({
        '# 当前测试集(测试版 = 稳定版 + 以下 armed)',
        'alpha,beta,gamma',
        '**成员串 3**(上一行)。本行的变动:`gamma` 入集。',
        'stale1,stale2',
    }, '\n')
    local set, cnt = parse_arm(synthetic)
    assert(set ~= nil and cnt == 3 and set.alpha and set.gamma, 'the parser did '
        .. 'not take the first id line: ' .. tostring(cnt))
    assert(not set.stale1, 'the parser reached a historical members string')
    -- The heading guard, made falsifiable. Without it the first id-shaped line
    -- ANYWHERE wins, and test_set.md is a file whose top is edited every time an
    -- id is admitted -- a stray front-matter line would silently become "the
    -- armed set" and the register would publish a join against the wrong input.
    local before = table.concat({
        'decoy1,decoy2',
        '# 当前测试集(测试版 = 稳定版 + 以下 armed)',
        'alpha,beta,gamma',
    }, '\n')
    local set2, cnt2 = parse_arm(before)
    assert(set2 ~= nil and cnt2 == 3 and set2.alpha, 'heading guard: got '
        .. tostring(cnt2))
    assert(not set2.decoy1,
        'an id-shaped line ABOVE the heading was read as the arm string')
    assert(parse_arm('no heading, no ids here') == nil,
        'the parser invented an arm string out of prose')
end

-- The registered item from charter 0CONJ, kept as the measured record. Source-
-- anchored, so it is not restating the arm string; a floor, so adding another
-- IsInLaningPhase reader does not redden it.
tests['the largest fan-out node is still the shared laning-phase predicate'] = function()
    local fan = {}
    for _, r in ipairs(nesting_rows(tree_funcs())) do
        for id in pairs(r.callee.ids) do
            fan[id] = fan[id] or {}
            fan[id][r.caller.file .. '::' .. r.caller.name] = true
        end
    end
    local top, best = nil, 0
    for id, sites in pairs(fan) do
        local c = 0
        for _ in pairs(sites) do c = c + 1 end
        if c > best then top, best = id, c end
    end
    assert(top == 'c2' or top == 'c4', 'the biggest fan-out inner id is now '
        .. tostring(top) .. ' (' .. best .. ' call sites), not c2/c4. Whatever '
        .. 'it is, arming it moves that many other levers at once -- so it is '
        .. 'the id whose admission needs the caveat written before the wave, '
        .. 'not after')
    assert(best >= 10, 'c2/c4 fan-out fell to ' .. best
        .. '; it was 15 on 2026-08-29')
end

-- --- controls -------------------------------------------------------------
-- Synthetic sources through the SAME functions, because a control that walks a
-- different code path proves that path, not the branch under test.

local C_OUTER = table.concat({
    'function J.Outer( bot )',
    "\tif not J.IsSoakCandidate( 'outerid' ) then return false end",
    '\treturn J.Inner( bot )',
    'end',
}, '\n')

local C_INNER = table.concat({
    'function J.Inner( bot )',
    "\tif not J.IsSoakCandidate( 'innerid' ) then return false end",
    '\treturn true',
    'end',
}, '\n')

local function pairs_from(sources, armed_list)
    local armed = {}
    for _, id in ipairs(armed_list) do armed[id] = true end
    return coarmed_pairs(nesting_rows(funcs_from(sources)), armed)
end

tests['C1: both ids armed is a co-armed pair'] = function()
    local p = pairs_from({ ['syn.lua'] = C_OUTER .. '\n' .. C_INNER .. '\n' },
        { 'outerid', 'innerid' })
    assert(#p == 1 and p[1] == 'outerid > innerid',
        'the join read ' .. #p .. ' pair(s); if this is 0 the register above is '
        .. 'publishing "clean" from a broken join')
end

-- The join is the half this file adds. If it did nothing, C2 and C3 would pass
-- for free while C1 passed too.
tests['C2: an UN-armed inner under an armed outer is not a confound'] = function()
    local src = { ['syn.lua'] = C_OUTER .. '\n' .. C_INNER .. '\n' }
    assert(#pairs_from(src, { 'outerid' }) == 0,
        'a pair was reported with the inner id not armed -- that is the FREEZE '
        .. 'case (the sister census owns it), not an attribution confound')
    assert(#pairs_from(src, { 'innerid' }) == 0,
        'a pair was reported with the outer id not armed')
end

-- The director's rule (GH #221/#276) made executable: this file must not redden
-- when the arm string shrinks.
tests['C3: retiring an id never reddens the register'] = function()
    local src = { ['syn.lua'] = C_OUTER .. '\n' .. C_INNER .. '\n' }
    local ack = { ['outerid > innerid'] = true }
    local live = pairs_from(src, { 'innerid' })
    local new = {}
    for _, k in ipairs(live) do if not ack[k] then new[#new + 1] = k end end
    assert(#new == 0, 'retiring the outer id produced an unacknowledged pair: '
        .. table.concat(new, ', '))
end

tests['C4: a call that only appears in a COMMENT is not a call'] = function()
    local quoted = table.concat({
        'function J.Outer( bot )',
        "\tif not J.IsSoakCandidate( 'outerid' ) then return false end",
        '\t-- shipped reads J.Inner( bot ) here; armed it does not',
        '\treturn true',
        'end',
    }, '\n')
    assert(#pairs_from({ ['syn.lua'] = quoted .. '\n' .. C_INNER .. '\n' },
        { 'outerid', 'innerid' }) == 0,
        'a commented-out call was counted as a confound')
    -- MULTI-line on purpose: a one-line `--[[ ]]` is already killed by the `--`
    -- strip, so a single-line control leaves the long-comment gsub
    -- unfalsifiable. bots/ carries 202 long-comment blocks, three of which
    -- already contain call-shaped text.
    local long = table.concat({
        'function J.Outer( bot )',
        "\tif not J.IsSoakCandidate( 'outerid' ) then return false end",
        '\t--[[',
        '\tshipped:',
        '\t\treturn J.Inner( bot )',
        '\t]]',
        '\treturn true',
        'end',
    }, '\n')
    assert(#pairs_from({ ['syn.lua'] = long .. '\n' .. C_INNER .. '\n' },
        { 'outerid', 'innerid' }) == 0,
        'a call inside a multi-line long comment was counted')
end

tests['C5: two helpers sharing an id are one lever, not a confound'] = function()
    local same = table.concat({
        'function J.Outer( bot )',
        "\tif not J.IsSoakCandidate( 'innerid' ) then return false end",
        '\treturn J.Inner( bot )',
        'end',
    }, '\n')
    assert(#pairs_from({ ['syn.lua'] = same .. '\n' .. C_INNER .. '\n' },
        { 'innerid' }) == 0,
        'a helper calling another gated on the SAME id was reported as a pair')
end

tests['C6: the same short name in two files is not cross-linked'] = function()
    local a = table.concat({
        'function X.Shared( bot )',
        "\tif not J.IsSoakCandidate( 'aid' ) then return false end",
        '\treturn true',
        'end',
        'function X.CallerA( bot )',
        "\tif not J.IsSoakCandidate( 'callerid' ) then return false end",
        '\treturn X.Shared( bot )',
        'end',
    }, '\n')
    local b = table.concat({
        'function X.Shared( bot )',
        "\tif not J.IsSoakCandidate( 'bid' ) then return false end",
        '\treturn true',
        'end',
    }, '\n')
    local p = pairs_from({ ['a.lua'] = a .. '\n', ['b.lua'] = b .. '\n' },
        { 'aid', 'bid', 'callerid' })
    assert(#p == 1 and p[1] == 'callerid > aid',
        'cross-file short-name resolution invented a confound: '
        .. table.concat(p, ', '))
end

-- Pure drift must not move the register (0ADDR: content, never position).
tests['C7: pure drift above the code changes nothing'] = function()
    local src = C_OUTER .. '\n' .. C_INNER .. '\n'
    local armed = { 'outerid', 'innerid' }
    local a = pairs_from({ ['syn.lua'] = src }, armed)
    local b = pairs_from({ ['syn.lua'] = string.rep('\n', 20) .. src }, armed)
    assert(#a == 1 and #b == 1 and a[1] == b[1],
        'a pure-drift prefix moved the register')
end

return tests
