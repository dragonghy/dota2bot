-- [ratchet] [fieldcreep / GH #323 / owner priority P2's family] The narrowing
-- GH #323 asks for is not a re-tuning. It needs a SENSOR THE BOT VM DOES NOT
-- HAVE, and the one knob it does have is falsified by a tie in this corpus.
--
-- GH #323 (replay desk, W25, 121 games) measured that `fieldcreep`'s veto is
-- reversed on 72.5% (ab) / 72.4% (ba) of the pure-lane frames where the bot is
-- carrying a heal: the chip damage is smaller than what the bag delivers over
-- the same three seconds, so the veto hands a frame back to the go-home logic
-- that owner priority P2 exists to suppress. Its §4 acceptance asks for a
-- narrowing that reads MAGNITUDE: release the light frames, keep vetoing the
-- three heavy ones (109 / 129 / 132 damage in 3s).
--
-- Three things this file pins, in the order they bind:
--
--   (A) THE OPERAND DOES NOT EXIST IN THE ENGINE. `bots/` reads creep damage
--       through exactly one call, `bot:WasRecentlyDamagedByCreep(fInterval)`,
--       and the whole Damage History family is boolean except for one
--       hero-only float (`TimeSinceDamagedByAnyHero`) with no creep sibling.
--       A boolean with a lookback cannot report 36-vs-132; the corpus can,
--       because a fixture row carries `value`, but the bot cannot ask for it.
--       `InstallDamageCallback` -- the one engine entry point that could build
--       a magnitude ledger -- is called nowhere under `bots/`.
--
--   (B) THE ONLY KNOB IS FALSIFIED, over its WHOLE range, not at one setting.
--       A boolean reader's entire information content on a frame is the
--       smallest `dt` at which it still answers true, so sweeping the interval
--       recovers min-dt and nothing else. In this corpus a HEAVY frame
--       (viper_ring_alone, 129 in 3s) and a LIGHT one (wd_defend_token, 22)
--       share min-dt to the fixture's own resolution. A tie cannot be split by
--       a threshold, so NO interval separates the two populations -- the grid
--       drive below asserts that over the full range rather than at 1.0.
--
--   (C) THIS CORPUS CANNOT HOST §4's ACCEPTANCE TEST. The cell §4 wants
--       released -- light damage AND a heal in the bag -- is EMPTY here: the
--       five vetoed frames are 2 heavy+heal, 1 heavy+dry, 2 light+dry. The two
--       light frames carry nothing to drink, so releasing them moves the SUPPLY
--       half (`fieldbuy`) and cannot move the hold half at all. A local
--       narrowing would therefore be validated on frames where it provably
--       changes no hold decision.
--       And the units are not free either: read per-single-use instead of
--       per-3s, BOTH heal-carrying frames flip to "reversed" (109 taken against
--       a 115-health tango; 132 against a 400-health salve) -- and §4 requires
--       both to KEEP vetoing, so §4's own acceptance forces the per-3s reading.
--       The tango frame decides it by 6 health.
--
-- => Ruling handed back on #323: agreed on the direction and on the reading,
--    but the lever cannot be landed or validated today. It needs a sensor
--    (harness) and the W25 OD frame dumped into tests/fixtures (replay desk).
--    Until then `fieldcreep` stays as it is -- gated, unpromoted.
--
-- Honest bounds, stated first rather than buried:
--   * ZERO behaviour change this round. `bots/` and `game/` are byte-identical;
--     no new gate id exists, so nothing here buys condition (a) on any frame.
--   * the corpus numbers are a fact about tests/fixtures/, not about Dota. The
--     empty cell is asserted as an EQUALITY ZERO on purpose (corpus_scale's own
--     doctrine): the day the replay desk lands the OD frame, this file goes red
--     and the finding gets re-read instead of quietly surviving.
--   * `value` sums are read straight off the fixture rows, the same rows the
--     loader answers the boolean from. They are the replay dumper's numbers;
--     this file does not re-derive them from the .dem.
--   * whether `WasRecentlyDamagedByCreep` counts neutrals is STILL unresolved
--     (state.json:fieldcreep_engine_semantics_20260822T2300Z, GH #324 §4).
--     Nothing here depends on it: both worlds agree these five rows are creep
--     damage, and (A) is about the reader's return type, not its domain.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local JMZ = 'bots/FunLib/jmz_func.lua'
local API_DOC = 'docs/BOT_API_REFERENCE.md'

-- The lookback the shipped clause uses. Read from source, never restated
-- (backlog 0SRC / M13: a census that copies the constant it measures reports
-- the old world unmoved after the constant moves).
local LOOKBACK

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

-- Source assertions run on CODE, never on the file text. GH #300 paid for this
-- once and the `campvoid` round paid for it again inside a file that was about
-- `campvoid`: `jmz_func.lua` quotes its own call sites in prose, so a bare
-- `src:find` matches the comment and a mutation of the real branch survives.
-- Blocks first, then line comments (which would otherwise eat a block's `--`).
-- Limit: a `--` inside a string literal is stripped too; no assertion below
-- reads one.
local function code_only(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    src = src:gsub('%-%-[^\n]*', '')
    return src
end

local JMZ_SRC = read_file(JMZ)
local JMZ_CODE = code_only(JMZ_SRC)

LOOKBACK = (function()
    local n = JMZ_CODE:match('bot:WasRecentlyDamagedByCreep%(%s*([%d%.]+)%s*%)')
    assert(n, 'the fieldcreep clause is no longer a literal WasRecentlyDamagedByCreep')
    return tonumber(n)
end)()

-- Per-single-use heal, read off the SHIPPED table so this file cannot drift
-- from it, and the seconds that use takes to deliver. The durations are the
-- item facts (salve 400 over ~13s, tango 115 over ~16s, faerie fire 85 at
-- once, bottle 135 over ~3s) and they are what turns a per-use number into the
-- per-3s rate GH #323 compares against. Stated here rather than in `bots/`
-- because nothing in `bots/` reads a rate yet -- that is the whole finding.
local SIP_SECONDS = {
    item_flask        = 13.0,
    item_tango        = 16.0,
    item_tango_single = 16.0,
    item_faerie_fire  =  3.0,
    item_bottle       =  3.0,
}

-- A frame is HEAVY when it carries a creep hit in the 25+ tail. That is not a
-- new split: it is the one the shipped comment already argues from ("per-hit
-- creep damage in this corpus tops out at 45, with the mass at or below 24"),
-- and it is what tracks camp contact versus a lane creep or two.
local TAIL = 25

local function creep_rows(u, window)
    local rows = {}
    for _, d in ipairs(u.recent_damage or {}) do
        if d.kind == 'creep' and d.dt <= window then
            rows[#rows + 1] = { dt = d.dt, value = tonumber(d.value) or 0 }
        end
    end
    return rows
end

-- The per-3s rate of the best single sip in the bag, in health. This is the
-- quantity GH #323 §2 compares trauma against; J.FieldRegenSipValue answers the
-- per-USE number, and the two differ by up to 5.3x (a salve: 400 in the bag,
-- ~92 inside the window the clause reads). Deliberately built from the SHIPPED
-- table plus the delivery times above, so it cannot drift from what the tree
-- believes an item is worth -- only from what it believes about time, which is
-- the thing this round says is not modelled anywhere yet.
local function sip_rate_3s(J, bot)
    local best = 0
    for i = 0, 5 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil then
            local name = hItem:GetName()
            local heal = J.FIELD_SIP_HEAL[name]
            local secs = SIP_SECONDS[name]
            if heal ~= nil and secs ~= nil then
                if name == 'item_bottle'
                    and (tonumber(hItem:GetCurrentCharges()) or 0) <= 0 then
                    heal = nil
                end
                if heal ~= nil then
                    local rate = heal * math.min(1.0, 3.0 / secs)
                    if rate > best then best = rate end
                end
            end
        end
    end
    return best
end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

-- The drive. Only frames that carry a creep row inside the lookback can be
-- vetoed by the clause -- the loader answers the boolean from those same rows
-- -- so the sweep loads `bots/` for those frames only (~4s instead of the
-- ~45s a whole-corpus drive costs). `[control] prefilter` below is what makes
-- that shortcut a fact rather than an assumption.
local function sweep()
    local rows, seen, agree, disagree = {}, 0, 0, 0
    for _, path in ipairs(fixture_files()) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units and fx.time then
            seen = seen + 1
            for _, u in ipairs(fx.units) do
                if u.alive and u.recent_damage ~= nil then
                    local cr = creep_rows(u, LOOKBACK)
                    local J, bot = rf.load(path, u.name)
                    J.IsSoakCandidate = function() return false end
                    -- control data: the raw-row scan and the loader's reader
                    -- must answer the same question on every askable frame.
                    if (#cr > 0) == bot:WasRecentlyDamagedByCreep(LOOKBACK) then
                        agree = agree + 1
                    else
                        disagree = disagree + 1
                    end
                    if #cr > 0 and J.IsFieldRegenSituation(bot) then
                        local tot, mindt, maxhit = 0, math.huge, 0
                        for _, d in ipairs(cr) do
                            tot = tot + d.value
                            if d.dt < mindt then mindt = d.dt end
                            if d.value > maxhit then maxhit = d.value end
                        end
                        rows[#rows + 1] = {
                            fixture = path, hero = u.name,
                            hp = u.hp / u.max_hp,
                            total = tot, mindt = mindt, maxhit = maxhit,
                            hits = #cr,
                            sip = J.FieldRegenSipValue(bot),
                            rate3s = sip_rate_3s(J, bot),
                            heal = J.HasFieldRegenSource(bot),
                            J = J, bot = bot,
                        }
                    end
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.fixture < b.fixture end)
    return rows, seen, agree, disagree
end

local ROWS, FIXTURES, AGREE, DISAGREE = sweep()

local function heavy(r) return r.maxhit >= TAIL end

-- How many settings of the ONLY knob (the lookback) would veto every heavy
-- frame and no light one. Shared by the axis assertion and by the control that
-- proves the scan can answer anything other than zero.
local function count_separators(H, L)
    local n = 0
    for step = 1, 60 do
        local T = step * 0.05
        local heavy_all, light_none = true, true
        for _, r in ipairs(H) do
            if not r.bot:WasRecentlyDamagedByCreep(T) then heavy_all = false end
        end
        for _, r in ipairs(L) do
            if r.bot:WasRecentlyDamagedByCreep(T) then light_none = false end
        end
        if heavy_all and light_none then n = n + 1 end
    end
    return n
end

local tests = {}

tests['[source] the engine gives a boolean with a lookback, and nothing else'] = function()
    -- One call site, one literal interval: the clause's only tunable.
    local n = 0
    for _ in JMZ_CODE:gmatch('WasRecentlyDamagedByCreep') do n = n + 1 end
    assert(n == 1, 'jmz_func now has ' .. n .. ' creep-damage reads; the operand '
        .. 'argument below was taken over exactly one')
    assert(LOOKBACK == 3.0, 'the lookback moved to ' .. tostring(LOOKBACK)
        .. ' -- the census populations were taken at 3.0, re-read them')

    -- The engine's Damage History family, read off the API reference rather
    -- than remembered. Every creep/tower row returns bool; the single float is
    -- hero-only and has no creep sibling. A new row here is exactly the event
    -- that would make GH #323's lever buildable, so this failing is the signal
    -- to re-derive the finding, not to relax the assertion.
    local doc = read_file(API_DOC)
    local section = doc:match('### Damage History(.-)```')
    assert(section, 'the Damage History section of ' .. API_DOC .. ' moved')
    local bools, floats = 0, 0
    for fn, ret in section:gmatch('|%s*`([%w_]+)%b()`%s*|%s*`(%w+)`') do
        if ret == 'bool' then
            bools = bools + 1
        else
            floats = floats + 1
            assert(fn == 'TimeSinceDamagedByAnyHero',
                'a non-boolean damage-history reader appeared: ' .. fn
                .. ' -- GH #323 may now be buildable')
        end
    end
    assert(bools == 4 and floats == 1,
        'the Damage History table changed shape (' .. bools .. ' bool / '
        .. floats .. ' non-bool) -- re-read (A)')

    -- The one entry point that could build a magnitude ledger is unused, so
    -- the sensor genuinely does not exist -- it is not merely unread.
    local shipped = read_file('bots/FunLib/jmz_func.lua')
        .. read_file('bots/item_purchase_generic.lua')
        .. read_file('bots/mode_retreat_generic.lua')
    assert(not code_only(shipped):find('InstallDamageCallback', 1, true),
        'InstallDamageCallback is now called -- a damage ledger may exist; '
        .. 'the "no operand" half of this finding must be re-taken')
end

tests['[census] the five vetoed frames, split by magnitude and by bag'] = function()
    cs.corpus(FIXTURES, 'fieldcreep magnitude corpus')
    cs.ratchet(#ROWS, 5, 'situation frames the clause bites on')

    local hh, hd, lh, ld = 0, 0, 0, 0
    for _, r in ipairs(ROWS) do
        if heavy(r) then
            if r.heal then hh = hh + 1 else hd = hd + 1 end
        else
            if r.heal then lh = lh + 1 else ld = ld + 1 end
        end
    end
    assert(hh + hd + lh + ld == #ROWS, 'the 2x2 must partition the vetoed set')
    cs.ratchet(hh, 2, 'heavy frames carrying a heal')
    cs.ratchet(hd, 1, 'heavy frames with a dry bag')
    cs.ratchet(ld, 2, 'light frames with a dry bag')

    -- (C). The cell GH #323 §4 wants released. An equality zero, deliberately:
    -- the day a light+heal frame lands (the W25 OD frame is exactly one) this
    -- goes red, which is when the ruling below stops being true.
    assert(lh == 0, 'a light+heal frame appeared (' .. lh .. ') -- GH #323 §4 '
        .. 'can now be hosted locally; re-read this file and land the lever')

    -- ... and why an empty cell is not a technicality: on a dry bag the HOLD
    -- half cannot move whatever the clause decides, because
    -- J.ShouldRegenNotGoHome asks for a source too. Driven with the gate BOTH
    -- ways on the two light frames: releasing them changes the supply half
    -- (`fieldbuy`) and provably nothing else.
    local dry_checked = 0
    for _, r in ipairs(ROWS) do
        if not r.heal then
            for _, armed in ipairs({ false, true }) do
                r.J.IsSoakCandidate = function(id) return armed and id == 'fieldcreep' end
                assert(not r.J.ShouldRegenNotGoHome(r.bot),
                    'a dry-bag frame holds the bot anyway (armed=' .. tostring(armed)
                    .. ') -- the supply/hold split moved')
            end
            r.J.IsSoakCandidate = function() return false end
            dry_checked = dry_checked + 1
        end
    end
    cs.ratchet(dry_checked, 3, 'dry-bag vetoed frames driven both ways')
end

tests['[axis] no interval separates heavy from light -- the knob is falsified'] = function()
    local H, L = {}, {}
    for _, r in ipairs(ROWS) do
        if heavy(r) then H[#H + 1] = r else L[#L + 1] = r end
    end
    assert(#H >= 3 and #L >= 2, 'the two populations must both be non-empty')

    -- The tie that does it. min-dt is the whole information content of a
    -- boolean-with-lookback, and a heavy frame and a light frame share it.
    local hmax, lmin = 0, math.huge
    for _, r in ipairs(H) do if r.mindt > hmax then hmax = r.mindt end end
    for _, r in ipairs(L) do if r.mindt < lmin then lmin = r.mindt end end
    assert(hmax >= lmin, 'the populations are now separable on min-dt ('
        .. 'heaviest-latest ' .. hmax .. ' < lightest-earliest ' .. lmin
        .. ') -- a shortened lookback would work; re-read (B)')

    -- Asserted over the whole knob range, not at the tie: for every interval
    -- on a 0.05 grid out to the shipped lookback, the clause either lets a
    -- heavy frame through or keeps vetoing a light one.
    local separators = count_separators(H, L)
    assert(separators == 0, separators .. ' interval(s) now separate the two '
        .. 'populations -- GH #323 is buildable on the shipped reader; re-read (B)')
end

tests['[units] §4 acceptance forces the per-3s reading, by 6 health'] = function()
    -- Read per USE, the tango frame flips: 115 health in the bag against 109
    -- taken. §4 requires that frame to keep vetoing, so the generous reading
    -- contradicts §4 itself and the per-3s reading is the one it means.
    local flips, carriers, thinnest = 0, 0, math.huge
    for _, r in ipairs(ROWS) do
        if r.heal then
            carriers = carriers + 1
            if r.sip > r.total then
                flips = flips + 1
                assert(heavy(r), 'a light frame flipped under the per-use reading -- '
                    .. 'that is cell (C) and it should have been caught above')
                if r.sip - r.total < thinnest then thinnest = r.sip - r.total end
            end
        end
    end
    -- Not one frame: BOTH of them. Every frame §4 requires to keep vetoing is
    -- released by the generous reading, so the contradiction is total, not a
    -- boundary case.
    cs.universal(flips, carriers, 'heal-carrying frames flipped by the per-use reading', 2)
    -- ... and the tango frame decides it by 6 health, which is the whole
    -- margin the units argument stands on.
    cs.ceiling(thinnest, 6, 'thinnest per-use flip margin')

    -- Under the per-3s rate -- what GH #323 §2 actually compares -- no vetoed
    -- frame in this corpus is a reversal. Same equality-zero doctrine as (C).
    local reversed, rated = 0, 0
    for _, r in ipairs(ROWS) do
        if r.heal then
            rated = rated + 1
            assert(r.rate3s > 0, 'a frame with a heal has no per-3s rate -- '
                .. 'SIP_SECONDS and the shipped table disagree about which items count')
            assert(r.rate3s <= r.sip, 'the rate exceeds the per-use value')
            if r.rate3s > r.total then reversed = reversed + 1 end
        end
    end
    cs.ratchet(rated, 2, 'vetoed frames carrying a heal')
    assert(reversed == 0, reversed .. ' vetoed frame(s) are reversals under the '
        .. 'per-3s reading -- GH #323 §2 now has a local instance; re-read (C)')
end

tests['[control] the classifier can emit the empty cell, and the prefilter is sound'] = function()
    -- Anti-vacuum for (C): the cell is empty because the corpus has no such
    -- frame, NOT because the classifier cannot produce that label. Fed GH #323's
    -- own OD numbers (36 taken in 3s, a faerie fire at 85), it says light+heal.
    local od = { maxhit = 14, total = 36, heal = true, sip = 85 }
    assert(not heavy(od) and od.heal,
        'the classifier cannot label the very frame GH #323 asks about -- the '
        .. 'empty cell above would be an artefact of this file, not a reading')

    -- Anti-vacuum for (B): `count_separators` is not a function that returns
    -- zero. Fed a corpus where the populations ARE separable -- a heavy frame
    -- still being hit at 0.2s, a light one whose last hit was 1.5s ago -- it
    -- finds the intervals. Without this, (B) would also be green on a scan
    -- that never looked.
    local function stub(mindt)
        return { bot = { WasRecentlyDamagedByCreep = function(_, f) return f >= mindt end } }
    end
    assert(count_separators({ stub(0.2) }, { stub(1.5) }) > 0,
        'the separator scan cannot report a separation even when one exists -- '
        .. 'the axis assertion above is vacuous')

    -- Anti-vacuum for the shortcut the sweep takes: on every askable frame the
    -- raw-row scan and the loader's boolean agree, so restricting the drive to
    -- frames carrying a creep row loses no vetoed frame.
    assert(DISAGREE == 0, DISAGREE .. ' frame(s) where the raw rows and the '
        .. 'loader disagree -- the sweep prefilter is unsound')
    cs.ratchet(AGREE, 16, 'askable frames where the two agree')
end

tests['[control] the comment stripper works, and today it is not load-bearing'] = function()
    -- The campvoid round (GH #318) lost a mutation to exactly this: jmz_func
    -- quotes its own call sites in prose, a bare `src:find` matched the
    -- comment, and a patched branch stayed green. So every source assertion
    -- here runs on `code_only`. But a guard nobody can falsify is a claim, not
    -- a guard -- so it is proven on synthetic text rather than assumed:
    -- The block-comment control MUST be multi-line (0CONJ's self-injury 乙):
    -- on a single-line block the line-comment pass strips the same text, so a
    -- broken block pass stays green. What only the block pass can remove is
    -- the SECOND line of the block -- so that is what is asserted.
    local blk = code_only('a --[[ b\nc ]] d')
    assert(blk:find('a') and blk:find('d') and not blk:find('c'),
        'code_only no longer strips a multi-line block comment')
    assert(not code_only('x = 1 -- WasRecentlyDamagedByCreep( 9.9 )\ny = 2')
        :find('WasRecentlyDamagedByCreep', 1, true),
        'code_only no longer strips a line comment')

    -- ... and the honest half, registered rather than papered over: on TODAY's
    -- jmz_func the stripper changes nothing for the count above, because the
    -- prose around the clause describes the read in words ("a creep damaged me
    -- in the last 3 seconds") instead of quoting the call. A mutation that
    -- swaps JMZ_CODE for JMZ_SRC therefore SURVIVES, and that is recorded, not
    -- hidden. The day a comment starts quoting the call, this equality breaks
    -- and says the guard has become load-bearing.
    local raw, code = 0, 0
    for _ in JMZ_SRC:gmatch('WasRecentlyDamagedByCreep') do raw = raw + 1 end
    for _ in JMZ_CODE:gmatch('WasRecentlyDamagedByCreep') do code = code + 1 end
    assert(raw == code, 'the prose now quotes the creep read (' .. raw
        .. ' raw vs ' .. code .. ' in code) -- code_only just became load-bearing '
        .. 'for the [source] count, and the registered self-injury is closed')
end

tests['[limit] what this file does not buy'] = function()
    -- (1) No behaviour. There is no gate id in this round at all: the finding
    -- is that the lever cannot be built yet, and a placeholder gate would be a
    -- claim that it can.
    assert(not JMZ_CODE:find('fieldmag', 1, true),
        'a magnitude gate id landed -- this file argued none could be validated; '
        .. 'either the sensor arrived or the argument was wrong')

    -- (2) The W25 reading itself. GH #323's 72.5%/72.4% is over 121 games of
    -- batch corpus this repository does not carry; nothing here re-derives it,
    -- and nothing here contradicts it. The two speak about different corpora,
    -- which is precisely why the acceptance frame has to be dumped.
    assert(#ROWS < 100, 'this corpus grew a batch-scale damage census -- the '
        .. 'limitation above is stale')
end

return tests
