-- [ratchet] A gate inside a gate is a CONJUNCTION of two ids, and nothing in
-- the tree counts them.
--
-- The finding this file pins (strategy 2026-08-29, discharging the discriminant
-- registered by charter `0DODGE` / GH #304 and never run):
--
--   A helper that carries its own `J.IsSoakCandidate` is not a predicate, it is
--   a conjunct. Call it from inside ANOTHER gated helper and the new lever is
--   `outer_id AND inner_id`. Arm only the outer id -- which is exactly what an
--   isolation wave does -- and the lever can be a byte-for-byte no-op, while
--   `tools/batch_test/check_armed_wiring.py` still reports it WIRED, because
--   WIRED means "a call site exists on this tree" and says so in its own LIMITS
--   block. The verdict then comes back "tested, no effect" with nothing raising
--   a hand. That is the `pullcad` shape (AGENTS.md: "Promoting an id silently
--   kills any gate that names it"), except the loss no longer waits for a
--   promote -- it is there on the day the call lands.
--
-- THE ANSWER ON THIS TREE IS: no live violation. Every one of the pinned pairs
-- below is safe, and safe for one of exactly three reasons, none of which was
-- written down anywhere before this file:
--
--   (P) PARAMETER gate. Un-armed the inner helper returns the SHIPPED value,
--       not a constant that kills the caller's branch (`J.IsInLaningPhase`
--       shifts a minute threshold under 'c2'/'c4'; `J.SafeToCommitFight` takes
--       a deeper margin under 'depthnum'). Nothing freezes.
--   (A) ADDITIVE-only. Armed, the inner can only ADD a true / raise a value
--       (`J.HasFieldRegenSource` under 'bagsalve' only ever admits one more
--       backpack slot), so un-armed is the shipped answer.
--   (I) IDENTITY element. Un-armed the inner is the literal `true` on its first
--       line, which is the unit of the `and` it sits in -- `J.IsFieldSipEnough`
--       under 'fieldsip' is the one helper in the tree written this way on
--       purpose, and it is the general form of the fix (charter §CE.6): EITHER
--       co-arm the inner id on the same leg, OR make its un-armed value the
--       identity element of the conjunction it joins.
--
-- WHY A CENSUS AND NOT A VERDICT. Deciding (P)/(A)/(I) automatically means
-- deciding what an arbitrary Lua function returns un-armed; a checker that
-- guessed would be a `量具` that manufactures its own findings, which is the
-- more expensive of the two self-injuries this group has logged (0ADDR: a `-P 8`
-- run invented nine red tests that were indistinguishable from real ones). So
-- this file pins the SET of conjunctions instead. A new pair turns it red, and
-- the reader answers the one question by hand: is the inner helper's UN-ARMED
-- value the identity element of the conjunction it just joined?
--
-- OVER-INCLUSIVE BY CONSTRUCTION, on purpose. "Nested" here means the call sits
-- anywhere in the caller's body, not that it sits inside the outer gate's own
-- branch. `Think` in mode_roam_generic.lua is 400 lines with several unrelated
-- gates in it, so some pinned rows are not conjunctions at all. That is the
-- SAFE direction for a ratchet: a wider net cannot miss the pair that matters,
-- and a false row costs one read. A narrower rule (walk the block structure and
-- take only calls lexically inside the gated branch) would decide by
-- indentation what the wave decides by arithmetic.
--
-- ANCHORED BY CONTENT, NOT POSITION -- the 0ADDR lesson. No row carries a line
-- number: `87c69bdc` deleted 22 of them out of test_level_gate_census.lua and
-- left a sister file permanently red for 9.4 hours because its pin addressed a
-- coordinate that file had just declared non-load-bearing. Rows here are
-- (outer ids, caller, callee, inner ids, caller file); a pure-drift control
-- proves position does not enter.

local BOTS_ROOT = 'bots'

local function list_lua_files()
    local files = {}
    -- Skip the two gitignored, farm-only files under bots/Customize/. The gate
    -- switch `soak_side.lua` is created and deleted by every gate test in this
    -- suite, so listing it and then `read_file`-ing it (which asserts) is a
    -- race whose red -- `cannot open <that switch>` -- names
    -- neither this file's subject nor a real defect. THIS FILE IS ONE OF THE
    -- THREE CARRIERS GH #365 §2 PUBLISHED (`:72`), seen again here on
    -- 2026-09-02 in 开工自检's Lua-detector leg. #365 read those reds as GH
    -- #229's contention and routed the fix into #229's scope (a per-process
    -- switch path, still blocked) -- but this file is not a gate test and
    -- never writes the switch: it only walks over it, and the walk is its own
    -- to fix. Neither farm-only file is bot logic or nests a gated helper.
    local p = assert(io.popen('find ' .. BOTS_ROOT
        .. ' -name "*.lua" ! -path "' .. BOTS_ROOT .. '/Customize/soak_*.lua" | sort'))
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    return files
end

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local text = fh:read('*a')
    fh:close()
    return text
end

--- Source with every comment removed, as a line array.
--
-- Comment stripping is load-bearing in BOTH directions and this repo has paid
-- for both: a comment that QUOTES a call must not be counted as a call (the
-- 'fieldsip' round put one pure-comment line in jmz_func.lua and a sister
-- census counted it as a third call site), and a real call must not be hidden.
-- Long comments are stripped first, then `--` to end of line.
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

local function sorted_ids(set)
    local t = {}
    for id in pairs(set) do t[#t + 1] = id end
    table.sort(t)
    return table.concat(t, ',')
end

--- Every top-level function in one file, with the gate ids its body names.
--
-- Both definition forms the tree uses at column 0 (`function X.y(` and
-- `local function y(`); a body runs to the next line that is exactly `end` at
-- column 0. That is the whole file layout convention in bots/ -- an indented
-- `end` closes an inner block, never a top-level function.
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
            funcs[#funcs + 1] = {
                name = name, file = path, body = body,
                ids = ids, id_str = sorted_ids(ids),
            }
            i = j + 1
        else
            i = i + 1
        end
    end
    return funcs
end

--- The conjunctions: gated helper called from inside a DIFFERENT id's helper.
--
-- Name resolution is deliberately narrow. `J.*` lives in one global table and
-- is reachable from every file, so those match tree-wide; anything else must be
-- defined in the SAME file as the caller. Without that rule the short name
-- `GetBoundAbility` cross-links hero_zuus to hero_crystal_maiden and invents
-- two conjunctions that no game can execute -- the first draft of this census
-- reported exactly those, and a control below keeps them out.
local function conjunctions_in(funcs)
    local rows = {}
    for _, caller in ipairs(funcs) do
        if caller.id_str ~= '' then
            for _, callee in ipairs(funcs) do
                local reachable = callee.name:sub(1, 2) == 'J.'
                    or callee.file == caller.file
                local disjoint = callee.id_str ~= ''
                if disjoint then
                    for id in pairs(caller.ids) do
                        if callee.ids[id] then disjoint = false end
                    end
                end
                if callee ~= caller and reachable and disjoint then
                    local short = callee.name:match('([%w_]+)$')
                    if caller.body:find('[.:]' .. short .. '%s*%(') then
                        -- The caller's FILE is part of the key, not decoration.
                        -- `X._nopush_ShouldSuppressWaveShove` is defined twice
                        -- -- once in hero_crystal_maiden.lua, once in
                        -- hero_jakiro.lua -- with the same ids on both sides, so
                        -- a name-only key pools two independent call sites into
                        -- one row and deleting either leaves this file GREEN.
                        -- Caught by counting the keyed and unkeyed sets against
                        -- each other (45 vs 44) before pinning anything; paths
                        -- under bots/ are frozen by the never-rename rule, so
                        -- the coupling costs nothing.
                        rows[#rows + 1] = table.concat({
                            caller.id_str, caller.name,
                            callee.name, callee.id_str, caller.file,
                        }, ' | ')
                    end
                end
            end
        end
    end
    table.sort(rows)
    return rows
end

local function census()
    local funcs = {}
    for _, path in ipairs(list_lua_files()) do
        local lines = strip_comments(read_file(path))
        for _, f in ipairs(functions_in(lines, path)) do funcs[#funcs + 1] = f end
    end
    return funcs, conjunctions_in(funcs)
end

-- The pinned set. Each row is `outer ids | caller | callee | inner ids`, and
-- each was read by hand and classified (P)/(A)/(I) per the header. Update this
-- list ONLY together with that reading -- the list is the record that somebody
-- answered the question, and a row added to make the test green without the
-- reading turns this file into the stale register it exists to prevent.
local PINNED = {
    "bodyblock | J.ShouldBodyBlockHarass | J.IsInLaningPhase | c2,c4 | bots/FunLib/jmz_func.lua",                                        -- P
    "bodyblock | J.ShouldBodyBlockHarass | J.SafeToCommitFight | depthnum | bots/FunLib/jmz_func.lua",                                    -- P
    "c1,c10r | GetDesire | J.ShouldCoreKeepFarming | corefarm | bots/mode_farm_generic.lua",                                              -- W
    "c1,c10r | GetDesire | J.ShouldGroupWithAegis | aegisgroup | bots/mode_farm_generic.lua",                                             -- W
    -- [roshdist 20260902] Read by hand before pinning, and it is (W): the three
    -- outer ids are SIBLING statements inside the same 500-line GetDesireHelper
    -- (c12 at :396/:397, retnear at :528, towerreach at :634), not a block that
    -- encloses the BOT_MODE_ROSHAN paragraph at :424 -- that paragraph runs on
    -- every frame regardless of any of them, so arming 'roshdist' alone is not
    -- arming a no-op. This is the census's wide net doing what its header says.
    -- Un-armed the inner helper is the identity element anyway: J.IsAtRoshanPit
    -- hands back the DISTANCE, the same value the call site used to compute
    -- inline, so with roshdist off the conjunction is byte-for-byte what
    -- shipped.
    "c12,retnear,towerreach | GetDesireHelper | J.IsAtRoshanPit | roshdist | bots/mode_retreat_generic.lua",                              -- W
    "c12,retnear,towerreach | GetDesireHelper | J.IsInLaningPhase | c2,c4 | bots/mode_retreat_generic.lua",                               -- W
    "c12,retnear,towerreach | GetDesireHelper | J.IsWkReincarnationArmed | wkreincarnmp | bots/mode_retreat_generic.lua",                 -- W
    "c12,retnear,towerreach | GetDesireHelper | J.ShouldAbandonTpChannel | tpwatch | bots/mode_retreat_generic.lua",                      -- W
    "c12,retnear,towerreach | GetDesireHelper | J.ShouldCounterTradeKite | l1kite | bots/mode_retreat_generic.lua",                       -- W
    "c12,retnear,towerreach | GetDesireHelper | J.ShouldRegenNotWalkHome | stayfield2 | bots/mode_retreat_generic.lua",                   -- W
    "c12,retnear,towerreach | GetDesireHelper | J.ShouldRetreatLaneBurst | ccburst,lanehyst | bots/mode_retreat_generic.lua",             -- W
    "c12,retnear,towerreach | GetDesireHelper | J.ShouldRetreatPastMidline | midguard | bots/mode_retreat_generic.lua",                   -- W
    -- [stayattr 20260905] 'stayattr' joined this row when it narrowed the chase
    -- read inside J.ShouldStayAndRegen.  Read by hand before pinning, and it is
    -- (P): the new clause is `WasRecentlyDamagedByAnyHero(3.0) and ( not
    -- IsSoakCandidate('stayattr') or HasNearbyHeroDamager(...) )`, so un-armed
    -- the second operand short-circuits on its FIRST disjunct and the veto
    -- condition is the shipped expression, evaluated in the shipped order.
    -- Arming any outer id ALONE therefore measures exactly what it measured
    -- before this clause landed.
    -- The direction is additive on its own arm too, and by construction rather
    -- than by inspection: an added disjunct can only make the veto HARDER to
    -- satisfy, so armed 'stayattr' can only turn this helper's FALSE into TRUE,
    -- never the reverse.  Measured, not asserted: tests/_stayattr_sweep.lua
    -- drives both legs over 1012 live frames and `flip_true_to_false` is 0.
    -- Note the sibling row two lines up ('stayfield2', J.ShouldRegenNotWalkHome)
    -- is the GATED family aimed at the same trip home; this one is the PROMOTED
    -- guard next to it.  They are separate rows because they are separate
    -- decisions, and neither reads the other.
    -- [staysrc 20260905] 'staysrc' joined the SAME row a few hours later, on a
    -- different clause of the same function (the supply read).  Also (P), and by
    -- the same short-circuit argument: `not bHasRegen and IsSoakCandidate(
    -- 'staysrc' )` leaves `bHasRegen` at its shipped value un-armed, and the
    -- veto below it is then the shipped expression.  Direction is additive by
    -- construction (widening `bHasRegen` can only remove vetoes);
    -- tests/_staysrc_sweep.lua drives both legs over the same 1012 live frames
    -- and `flip_true_to_false` is 0.
    -- ⭐ WHAT THIS ROW NOW RECORDS THAT NO OTHER ROW DOES: two ids on one
    -- helper, NOT conjoined -- each guards its own clause, and each clause is
    -- INDEPENDENTLY SUFFICIENT to veto.  That is the opposite of the pullcad
    -- trap and it costs the opposite mistake: arming one measures a correct
    -- ZERO on any frame the other one also vetoes.  Measured: over 1012 live
    -- frames exactly one frame flips only when BOTH are armed, and it is the
    -- frame owner priority P2 is named after (f_260822_063722_lina_tp_home,
    -- lina, 31.8% HP).  A wave that arms these one at a time cannot see it.
    -- [staybottle 20260905] The THIRD id joined this row the same day, on the
    -- same supply clause as 'staysrc' but reading a different fact (the bottle's
    -- in-flight modifier, which no item-slot read can see while the sip is
    -- running).  Also (P), by the same short-circuit argument: `not bHasRegen
    -- and IsSoakCandidate( 'staybottle' )` leaves `bHasRegen` at its shipped
    -- value un-armed, and it is APPENDED after the 'staysrc' block, so the
    -- sibling's un-armed evaluation is byte-identical.  Direction additive by
    -- construction; tests/_staybottle_sweep.lua drives both legs over the same
    -- 1012 live frames and `flip_true_to_false` is 0.
    -- ⭐ AND IT ANSWERS THE QUESTION THE ROW ABOVE RAISED.  The pair problem
    -- recorded here (arming one of two individually sufficient vetoes measures a
    -- correct ZERO) is NOT a property of this function -- it is a property of
    -- those two clauses.  Measured for the new pair rather than inherited:
    -- 'staysrc' alone flips 44 frames, 'staybottle' alone flips 1, and the
    -- overlap is 0, so a single-arm wave CAN see this one.
    -- [staybag 20260905] The FOURTH id joined this row the same day, on the same
    -- supply clause again, and it is the one that answers this row's own
    -- question in the OTHER direction.  Also (P), by the same short-circuit
    -- argument: `not bHasRegen and IsSoakCandidate( 'staybag' )` leaves
    -- `bHasRegen` at its shipped value un-armed, and it is APPENDED after the
    -- 'staybottle' block, so both siblings' un-armed evaluation is
    -- byte-identical.  Direction additive by construction;
    -- tests/_staybag_sweep.lua drives both legs over the same 1012 live frames
    -- and `flip_true_to_false` is 0.
    -- ⭐ WHY IT EXISTS AT ALL, and it is this file's own thesis with the gates
    -- one call apart.  A backpacked salve was ALREADY reachable from this
    -- function -- through the row below (J.HasFieldRegenSource under 'bagsalve')
    -- -- but only with 'staysrc' AND 'bagsalve' armed TOGETHER: 'staysrc' to get
    -- the callee called, 'bagsalve' to make its backpack block run.  Each SITE
    -- names one id, so no grep for "two ids in one condition" sees it.  Measured
    -- rather than argued: 'staysrc' alone flips 44 frames, 'bagsalve' alone
    -- flips 0 (its own gate is never reached), the PAIR flips 46 -- and the 2
    -- frames the pair adds are exactly the 2 this standalone lever buys with one
    -- arm (`pair_gain` == `flips`, `pair_gain_not_flips` == 0).  That is the
    -- (A)-row's safety argument holding and the WAVE still being unable to see
    -- the behaviour: additive-and-safe is not the same as single-arm-visible.
    -- [buyband 20260906] Two rows, and they are the 'fieldbuy' rows one function
    -- over: this lever is the OTHER arm of the same purchase site, covering the
    -- HP band between J.ShouldStayAndRegen's 0.75 and J.IsFieldRegenSituation's
    -- 0.55. Both classified by the same arguments as their 'fieldbuy' twins:
    --   (A) J.HasFieldRegenSource under 'bagsalve' -- un-armed the callee returns
    --       its byte-for-byte SHIPPED main-slot answer, not a frozen constant, so
    --       arming 'buyband' alone measures 'buyband'. Arming 'bagsalve' can only
    --       make the callee MORE true, i.e. can only REMOVE buys -- additive in
    --       the safe direction, and tests/_buyband_sweep.lua drives both legs over
    --       the same 1012 live frames with `flip_true_to_false` 0.
    --   (I) J.IsFieldSipEnough under 'fieldsip' -- un-armed it is the literal
    --       `true`, the identity element of the `and` it joined.
    -- ⭐ THE ROW THAT IS ABSENT IS THE INFORMATIVE ONE. 'fieldbuy' also carries a
    -- (P) row for J.IsFieldRegenSituation under 'fieldcreep'; this lever has no
    -- such row because it does not CALL that predicate -- it repeats three of its
    -- clauses inline. That is not tidiness lost: giving the shared predicate an
    -- optional ceiling argument was written and reverted the same day (its
    -- signature and band are parsed as literal text by several detector files),
    -- and copying the sibling's gated creep veto would have named another
    -- candidate's id in this body, freezing that clause FALSE the day it is
    -- promoted -- the pullcad trap. The cost is a duplication that can drift, and
    -- it is paid where it can be seen: every constant in both copies is parsed and
    -- compared in tests/test_buyband_hp_band.lua.
    "buyband | J.ShouldFieldBuyRegenHurt | J.HasFieldRegenSource | bagsalve | bots/FunLib/jmz_func.lua",                                  -- A
    "buyband | J.ShouldFieldBuyRegenHurt | J.IsFieldSipEnough | fieldsip | bots/FunLib/jmz_func.lua",                                     -- I
    "c12,retnear,towerreach | GetDesireHelper | J.ShouldStayAndRegen | stayattr,staybag,staybottle,staysrc | bots/mode_retreat_generic.lua", -- P
    "c12,retnear,towerreach | GetDesireHelper | J.ShouldSuppressDive | nodive2 | bots/mode_retreat_generic.lua",                          -- W
    "c12,retnear,towerreach | GetDesireHelper | X.ShouldRun | towerfear | bots/mode_retreat_generic.lua",                                 -- W
    "c14,c15 | ____exports.WhichLaneToPush | J.IsInLaningPhase | c2,c4 | bots/FunLib/aba_push.lua",                                       -- P
    "c3 | GetDesire | J.IsInLaningPhase | c2,c4 | bots/mode_laning_generic.lua",                                                          -- P
    "c3 | GetDesire | J.ShouldBodyBlockHarass | bodyblock | bots/mode_laning_generic.lua",                                                -- W
    -- [GH #415 20260902] The three rows 'slotpush' arrived in. Read by hand and
    -- they are (P): J.IsTeamPushingHighGround is a one-line wrapper whose only
    -- job is to resolve the id, and un-armed it hands the utils predicate
    -- `false`, i.e. the byte-for-byte shipped answer -- not a constant that
    -- freezes the caller's branch. Arming the outer id alone therefore measures
    -- the outer id, exactly as an isolation wave intends. Only three of the
    -- seven call sites appear because the other four modes have no gate of
    -- their own in the same function; that asymmetry is the census's wide net,
    -- not a property of this lever.
    "c3 | GetDesire | J.IsTeamPushingHighGround | slotpush | bots/mode_laning_generic.lua",                                               -- P
    -- [GH #455/#456 20260903] 'arbheart' joined this row when it added a second
    -- gate to the same Think.  Read by hand before re-pinning, and it stays
    -- (W): the callee `J.IsCampSwitchSafe` is reached ONLY from the shipped
    -- switch-to-nearer block, which is the `if old then` arm of the heartbeat.
    -- Arming 'arbheart' is what sets `old = nil`, so on any tick where arbheart
    -- actually fires that block is SKIPPED -- the two are mutually exclusive by
    -- construction, and arming 'arbheart' alone measures 'arbheart', not
    -- `arbheart AND campdanger`.  Not a conjunction: this is the census's wide
    -- net doing what the header says.
    -- ⭐ The real interaction runs the OTHER way, and its direction is the safe
    -- one, so it is registered rather than fixed: un-armed 'campdanger' freezes
    -- `J.IsCampSwitchSafe` to false for every camp
    -- (tests/test_arbheart_repick_relatch.lua §5), which means the shipped
    -- switch-to-nearer branch can never fire and arbheart's release is the ONLY
    -- thing in the heartbeat that can move `preferedCamp`.  Un-armed
    -- 'campdanger' makes arbheart MORE visible, not less.  The day 'campdanger'
    -- is armed or promoted, the two heartbeat arms both become live and this
    -- row must be re-read.
    "arbheart,campexit | Think | J.IsCampSwitchSafe | campdanger | bots/mode_farm_generic.lua",                                           -- W
    "campgrade,tbearly | GetDesireHelper | J.IsInLaningPhase | c2,c4 | bots/mode_farm_generic.lua",                                       -- P
    "capmono,divecap | _divecap_CapForLanePush | J.IsInLaningPhase | c2,c4 | bots/mode_team_roam_generic.lua",                            -- P
    "ccburst,lanehyst | J.ShouldRetreatLaneBurst | J.GetReadyHardCc | esaftershock | bots/FunLib/jmz_func.lua",                           -- P
    "ccburst,lanehyst | J.ShouldRetreatLaneBurst | J.IsInLaningPhase | c2,c4 | bots/FunLib/jmz_func.lua",                                 -- P
    "cmrcap,cmrguard,cmrself | X.cm_IsRSafeToOpen | J.GetReadyHardCc | esaftershock | bots/BotLib/hero_crystal_maiden.lua",               -- P
    "fieldbuy | J.ShouldFieldBuyRegen | J.HasFieldRegenSource | bagsalve | bots/FunLib/jmz_func.lua",                                     -- A
    "fieldbuy | J.ShouldFieldBuyRegen | J.IsFieldRegenSituation | fieldcreep | bots/FunLib/jmz_func.lua",                                 -- P
    "fieldbuy | J.ShouldFieldBuyRegen | J.IsFieldSipEnough | fieldsip | bots/FunLib/jmz_func.lua",                                        -- I
    "fieldregen,tpdeathbuy | ItemPurchaseThink | J.IsInLaningPhase | c2,c4 | bots/item_purchase_generic.lua",                             -- W
    "fieldregen,tpdeathbuy | ItemPurchaseThink | J.ShouldFieldBuyRegen | fieldbuy | bots/item_purchase_generic.lua",                      -- W
    -- [buyband 20260906] The third row, and it is the (W) twin of the one above:
    -- the census's wide net, since 'fieldregen'/'tpdeathbuy' guard OTHER blocks of
    -- the same Think and this predicate is a new OR arm on the 'fieldbuy' block.
    -- Un-armed J.ShouldFieldBuyRegenHurt returns false on its first line -- the
    -- identity element of the `or` it joined -- so the shipped purchase order is
    -- byte-identical and arming either outer id alone still measures that id.
    "fieldregen,tpdeathbuy | ItemPurchaseThink | J.ShouldFieldBuyRegenHurt | buyband | bots/item_purchase_generic.lua",                   -- W
    "fieldsip | J.IsFieldSipEnough | J.FieldRegenSipValue | bagsalve | bots/FunLib/jmz_func.lua",                                         -- A
    "l1kite | J.ShouldCounterTradeKite | J.IsInLaningPhase | c2,c4 | bots/FunLib/jmz_func.lua",                                           -- P
    "l1trade | J.ShouldInitiateLaneKill | J.IsInLaningPhase | c2,c4 | bots/FunLib/jmz_func.lua",                                          -- P
    "l5combo | J.ShouldSupportComboKill | J.IsInLaningPhase | c2,c4 | bots/FunLib/jmz_func.lua",                                          -- P
    "l5trees | DoSupportLaningThink | J.IsLaneFixOn | lanefix,lf_ | bots/mode_laning_generic.lua",                                        -- W
    "midguard | J.ShouldRetreatPastMidline | J.IsInLaningPhase | c2,c4 | bots/FunLib/jmz_func.lua",                                       -- P
    "midsupyield,midtp,suptp,tparrive | J.ShouldTpSupportTowerFight | J.CanEnemyInterruptTpChannel | tpreach | bots/FunLib/jmz_func.lua",  -- P
    "midsupyield,midtp,suptp,tparrive | J.ShouldTpSupportTowerFight | J.SafeToCommitFight | depthnum | bots/FunLib/jmz_func.lua",          -- P
    "midsupyield,midtp,suptp,tparrive | J.ShouldTpSupportTowerFight | J.SafeToCommitFightOnArrival | depthnum | bots/FunLib/jmz_func.lua", -- P
    "nodive2 | J.ShouldSuppressDive | J.SafeToCommitFight | depthnum | bots/FunLib/jmz_func.lua",                                          -- P
    "nopush | X._nopush_ShouldSuppressWaveShove | J.IsInLaningPhase | c2,c4 | bots/BotLib/hero_crystal_maiden.lua",                        -- P
    "nopush | X._nopush_ShouldSuppressWaveShove | J.IsInLaningPhase | c2,c4 | bots/BotLib/hero_jakiro.lua",                                -- P
    -- [outcommit 20260905] 'outcommit' joined the row 'outlatch' already held,
    -- and the answer is unchanged (P) for a reason worth writing down rather
    -- than inheriting: `J.IsTeamPushingHighGround` is not conjoined with either
    -- id. It is an EARLY RETURN five clauses above both of them, and its
    -- 'slotpush' gate is a PARAMETER (`J.IsModeTurbo() and
    -- J.IsSoakCandidate('slotpush')` threaded into
    -- J.Utils.IsTeamPushingSecondTierOrHighGround), so un-armed it evaluates to
    -- false and the helper returns the shipped value of the expression it
    -- replaced. Arming 'outcommit' ALONE therefore measures what the shipped
    -- tree measures, not `outcommit AND slotpush`. This census's wide net is
    -- doing what its header says it does: it keys on the id SET of the enclosing
    -- function, so landing a second gate anywhere in GetDesireHelper rewrites
    -- this row even when nothing about the nesting changed.
    "outcommit,outlatch | GetDesireHelper | J.IsTeamPushingHighGround | slotpush | bots/mode_outpost_generic.lua",                          -- P
    "overchase | J.ShouldPunishOverchase | J.SafeToCommitFight | depthnum | bots/FunLib/jmz_func.lua",                                     -- P
    "ownhalf | J.ShouldPunishDive | J.SafeToCommitFight | depthnum | bots/FunLib/jmz_func.lua",                                            -- P
    "roshgate | GetDesireHelper | J.IsTeamPushingHighGround | slotpush | bots/mode_roshan_generic.lua",                                     -- P
    -- [GH #326 20260830] 'creepthink' joined this row when it added a second
    -- throttle-bypass clause to the same 400-line Think.  Read by hand before
    -- re-pinning, and it stays (W): the callee `J.GetLanePullDragTarget` is
    -- called ONLY from the camp-pull branch (`bot.roamCampPull ~= nil`), while
    -- the new id's clause is guarded on `bot.roamCreepPull ~= nil` -- and
    -- GetDesire nils each plan when it sets the other, so no frame can be in
    -- both.  Not a conjunction at all: it is this census's wide net doing what
    -- the header says it does.  'creepthink' is additive on its own arm anyway
    -- (armed it can only SKIP a `return`, never add one).
    "creepthink,pullcad,pullthink | Think | J.GetLanePullDragTarget | pulldrag | bots/mode_roam_generic.lua",                              -- W
    -- [campbind 20260904] 'campbind' joined the same 400-line Think when it
    -- bound the camp-pull poke to the PLANNED camp.  Read by hand before
    -- pinning, and it is (P): un-armed -- and in any game that is not Turbo --
    -- `J.GetCampPullPokeTarget` returns `tNeut[1]` under the same `J.IsValid`
    -- test the call site's own `bCampHere` just applied, i.e. the SHIPPED value
    -- of the expression it replaced, not a constant that kills the branch.
    -- Arming any outer id ALONE therefore measures exactly what it measured
    -- before this call landed.
    -- The one genuine interaction is with 'pullthink' and it runs the ADDITIVE
    -- way: armed 'pullthink' un-eats the ACTIVITY_ATTACK frames the throttle
    -- was swallowing, which can only make MORE poke frames reach this line.  It
    -- cannot make fewer, so 'campbind' armed alone is not `campbind AND
    -- pullthink`.
    "creepthink,pullcad,pullthink | Think | J.GetCampPullPokeTarget | campbind | bots/mode_roam_generic.lua",                             -- P
    "towerfear | X.ShouldRun | J.IsBasePresenceAdverse | basesiege | bots/mode_retreat_generic.lua",                                       -- W
    "tpcommit,tpdead,tpdying | J.GetTpCommitDefendDesire | J.ShouldRetreatLaneBurst | ccburst,lanehyst | bots/FunLib/jmz_func.lua",        -- P
    -- [staysrc 20260905] The inner helper here is the (A) exemplar this file's
    -- own header already names: armed 'bagsalve', J.HasFieldRegenSource only
    -- ever admits ONE MORE backpack slot, so un-armed it returns the shipped
    -- answer and 'staysrc' armed alone is not `staysrc AND bagsalve`.  Stronger
    -- than (A) on this particular call, and driven rather than argued: un-armed
    -- 'staysrc' the `and` short-circuits before the callee is reached at all --
    -- tests/_staysrc_sweep.lua's `arm_leak` counter drives 'bagsalve' through
    -- the stub on all 1012 live frames and reads 0.
    -- [staybag 20260905] The outer-id column grew a fourth id (the new lever
    -- reads the backpack DIRECTLY and never calls this callee), and the pair it
    -- documents is now measured rather than only argued safe: 'staysrc' alone
    -- flips 44 frames, 'bagsalve' alone 0, the pair 46.  (A) still holds -- the
    -- callee is additive-only -- and that is exactly the point worth carrying
    -- out of this row: (A) says arming the OUTER id alone still measures the
    -- outer id; it does NOT say the inner id's own behaviour is reachable by any
    -- single-arm wave.  Here it was not, for the whole time this row read safe.
    "stayattr,staybag,staybottle,staysrc | J.ShouldStayAndRegen | J.HasFieldRegenSource | bagsalve | bots/FunLib/jmz_func.lua",             -- A
    "wlok | X.ConsiderE | J.IsInLaningPhase | c2,c4 | bots/BotLib/hero_warlock.lua",                                                       -- P
}

local tests = {}

tests['the conjunction census is exactly the set that has been read'] = function()
    local _, rows = census()
    local pinned, seen = {}, {}
    for _, r in ipairs(PINNED) do pinned[r] = true end
    for _, r in ipairs(rows) do seen[r] = true end

    local added = {}
    for _, r in ipairs(rows) do
        if not pinned[r] then added[#added + 1] = r end
    end
    assert(#added == 0, 'a NEW gate-inside-a-gate appeared:\n      '
        .. table.concat(added, '\n      ')
        .. '\n    Answer one question before pinning it: un-armed, is the inner '
        .. 'helper the IDENTITY element of the conjunction it just joined '
        .. '(literal true for an `and`, the shipped value for a parameter, '
        .. 'additive-only)? If not, arming the outer id ALONE measures a no-op '
        .. 'and check_armed_wiring.py will still call it WIRED.')

    local gone = {}
    for _, r in ipairs(PINNED) do
        if not seen[r] then gone[#gone + 1] = r end
    end
    assert(#gone == 0, 'a pinned conjunction is no longer found:\n      '
        .. table.concat(gone, '\n      ')
        .. '\n    Either the code changed (drop the row) or the extractor '
        .. 'stopped seeing it (fix the extractor -- a census that silently '
        .. 'reads zero is the failure this file is built to survive).')
end

-- A census whose extractor breaks reads clean, and "clean" is the answer this
-- file publishes. Pin a floor so an empty read can never be mistaken for a tree
-- with nothing on it. A FLOOR, not an equality: GH #273.
tests['the extractor still finds gated helpers at all'] = function()
    local funcs = census()
    local nGated = 0
    for _, f in ipairs(funcs) do
        if f.id_str ~= '' then nGated = nGated + 1 end
    end
    assert(nGated >= 80, 'only ' .. nGated .. ' gated helper(s) found in '
        .. BOTS_ROOT .. '; the tree had 91 on 2026-08-29, so the extractor is '
        .. 'the thing that changed')
    assert(#PINNED >= 40, 'the pinned set collapsed to ' .. #PINNED .. ' rows')
end

-- --- controls -------------------------------------------------------------
-- Synthetic sources through the SAME extractor, because a control that walks a
-- different code path proves nothing about the census.

local function rows_from(sources)
    local funcs = {}
    for path, src in pairs(sources) do
        for _, f in ipairs(functions_in(strip_comments(src), path)) do
            funcs[#funcs + 1] = f
        end
    end
    return conjunctions_in(funcs)
end

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

tests['C1: a gated helper called from a different gated helper is caught'] = function()
    local rows = rows_from({ ['syn.lua'] = C_OUTER .. '\n' .. C_INNER .. '\n' })
    assert(#rows == 1, 'the census read ' .. #rows .. ' row(s) for one nested '
        .. 'gate; if this is 0 the real census above is meaningless')
    assert(rows[1] == 'outerid | J.Outer | J.Inner | innerid | syn.lua', rows[1])
end

tests['C2: a call that only appears in a COMMENT is not a call'] = function()
    local quoted = table.concat({
        'function J.Outer( bot )',
        "\tif not J.IsSoakCandidate( 'outerid' ) then return false end",
        '\t-- shipped reads J.Inner( bot ) here; armed it does not',
        '\treturn true',
        'end',
    }, '\n')
    local rows = rows_from({ ['syn.lua'] = quoted .. '\n' .. C_INNER .. '\n' })
    assert(#rows == 0, 'a commented-out call was counted as a conjunction: '
        .. (rows[1] or ''))
    -- MULTI-LINE on purpose. A one-line `--[[ ... ]]` is already killed by the
    -- `--` strip, so a single-line control leaves the long-comment gsub
    -- unfalsifiable: deleting that gsub was a mutation that SURVIVED the first
    -- battery, and a line-based stripper leaves the middle of a real block
    -- comment intact. bots/ carries 202 long-comment blocks, three of which
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
    assert(#rows_from({ ['syn.lua'] = long .. '\n' .. C_INNER .. '\n' }) == 0,
        'a call inside a multi-line long comment was counted as a call')
end

tests['C3: two helpers sharing an id are one lever, not a conjunction'] = function()
    local same = table.concat({
        'function J.Outer( bot )',
        "\tif not J.IsSoakCandidate( 'innerid' ) then return false end",
        '\treturn J.Inner( bot )',
        'end',
    }, '\n')
    assert(#rows_from({ ['syn.lua'] = same .. '\n' .. C_INNER .. '\n' }) == 0,
        'a helper calling another helper gated on the SAME id was reported')
end

tests['C4: a helper that calls itself is not nested inside itself'] = function()
    local rec = table.concat({
        'function J.Inner( bot )',
        "\tif not J.IsSoakCandidate( 'innerid' ) then return false end",
        '\treturn J.Inner( bot )',
        'end',
    }, '\n')
    assert(#rows_from({ ['syn.lua'] = rec .. '\n' }) == 0, 'self-recursion read '
        .. 'as a conjunction')
end

tests['C5: the same short name in two files is not cross-linked'] = function()
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
    local rows = rows_from({ ['a.lua'] = a .. '\n', ['b.lua'] = b .. '\n' })
    assert(#rows == 1, 'expected exactly the same-file pair, got ' .. #rows
        .. ': ' .. table.concat(rows, ' / '))
    assert(rows[1] == 'callerid | X.CallerA | X.Shared | aid | a.lua', rows[1])
end

-- The point of anchoring by content instead of position (0ADDR). Prepending
-- pure drift must not move a single row.
tests['C6: pure drift above the code changes nothing'] = function()
    local src = C_OUTER .. '\n' .. C_INNER .. '\n'
    local drift = string.rep('\n', 20) .. src
    local a = rows_from({ ['syn.lua'] = src })
    local b = rows_from({ ['syn.lua'] = drift })
    assert(#a == 1 and #b == 1 and a[1] == b[1],
        'a pure-drift prefix moved the census: ' .. (a[1] or 'nil') .. ' vs '
        .. (b[1] or 'nil'))
end

-- The defect this file shipped with for one draft. Two files define
-- `X._nopush_ShouldSuppressWaveShove` with the same ids on both sides; keyed by
-- name alone they pool into ONE row, and deleting either call site leaves the
-- census green while a real conjunction disappears. Same shape as the pooling
-- lesson in 铁律 4(ii): the reading that hides the difference is the one that
-- looks fine.
tests['C7: two files with the same caller and callee are two rows'] = function()
    local body = table.concat({
        'function X.Dup( bot )',
        "\tif not J.IsSoakCandidate( 'dupid' ) then return false end",
        '\treturn J.Inner( bot )',
        'end',
    }, '\n')
    local rows = rows_from({
        ['one.lua'] = body .. '\n' .. C_INNER .. '\n',
        ['two.lua'] = body .. '\n',
    })
    assert(#rows == 2, 'the census pooled two files into ' .. #rows
        .. ' row(s); a name-only key lets one of two identical call sites be '
        .. 'deleted without turning this file red')
    table.sort(rows)
    assert(rows[1]:find('one.lua', 1, true) and rows[2]:find('two.lua', 1, true),
        table.concat(rows, ' / '))
end

-- The named case this file exists for. `pullcad` is the id AGENTS.md records as
-- the near-miss: it was written as `IsSoakCandidate('pullcad') and
-- IsSoakCandidate('pullbeat')`, and promoting 'pullbeat' would have frozen that
-- conjunction FALSE in every wave. The conjunct was dropped -- so no gate
-- anywhere may name a promoted id again.
tests['no gate names a promoted id (the pullcad freeze)'] = function()
    local PROMOTED = {
        'lanesurv', 'tphome', 'tpsafe', 'tpsafe2', 'pushguard', 'nodive',
        'punish', 'regroup', 'deathzone', 'vsafe', 'skyburst', 'fight',
        'roamstale', 'creeppull', 'pullbeat',
    }
    local funcs = census()
    for _, f in ipairs(funcs) do
        for _, id in ipairs(PROMOTED) do
            assert(not f.ids[id], f.file .. ' ' .. f.name .. " gates on '" .. id
                .. "', which is PROMOTED and therefore in no armed string; that "
                .. 'gate is frozen FALSE and every id conjoined with it is a '
                .. 'no-op that still reads WIRED')
        end
    end
end

return tests
