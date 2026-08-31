-- Corpus half of the `towerCreepMode` reading. The closed form -- that the flag
-- is `roamstale`'s unreset sibling and that its consumer SHADOWS the branch
-- which won the auction -- is pinned by tests/test_towercreep_stale_source.lua.
-- This file measures what the corpus can and cannot say about it.
--
-- THE HEADLINE, and it is a negative one: the SETTER is unreachable on all 993
-- live-hero frames of the 109-fixture corpus, and NOT for a game reason. Three
-- independent engine values that the behavioural dump does not carry read as
-- their mock defaults, and each one shuts a different door:
--
--   GetActiveMode()        = 0 on every frame (BOT_MODE_* are mock sentinels in
--                            the 1000s), so GetDesireHelper's mode gate returns
--                            NONE on 925/925 zero-bid frames and the ENTIRE
--                            `elseif` half -- CarryFindTarget, SupportFindTarget
--                            AND the tower-creep block -- is never reached;
--   GetAnimActivity()      = 0 on 993/993, and X.ShouldAttackTowerCreep's first
--                            three returns sit behind `== 1502`;
--   Tower:GetAttackTarget() = nil on all 264 frames that DO have a friendly
--                            tower within 1600, which is the gate on the fourth
--                            and last return.
--
-- So the honest verdict on the setter is UNMEASURABLE, not EMPTY -- the GH #171
-- / GH #205 distinction: a door that has never been opened is not a door that
-- leads nowhere. This is why no `towerstale` candidate ships with this reading:
-- it could not be driven on a real frame, and gate-plumbing is not local
-- validation (charter step 4).
--
-- WHAT THE CORPUS *CAN* SAY, and it is the half that matters for pricing: the
-- EXPOSURE is not hypothetical. 58 of 993 frames (5.8%), spread over 29
-- distinct fixtures, deliver through exactly the two Think sites a stale flag
-- shadows. Every one of those is a frame where the mode won the auction on a
-- collapse/help branch and the shadow would replace the collapse with a
-- continuous attack on last frame's tower creep.
--
-- NOT IN THE FAST LEG ON PURPOSE. The sweep costs ~51s. GH #358 has the
-- selfcheck's Lua leg at 133.3s with 78.4s already concentrated in two files;
-- adding 38% to every stream's every trigger to re-derive a reading that does
-- not change between waves is the cost that issue is about. The cheap source
-- half IS tagged. If the director wants this one covered continuously, that is
-- a budget decision, not an oversight.

package.path = 'tests/?.lua;' .. package.path

local tests = {}
local cache

local function sweep()
    if cache then return cache end
    local p = assert(io.popen('lua5.1 tests/_towerstale_sweep.lua 2>/dev/null'))
    local out = p:read('*a')
    p:close()
    assert(out and out ~= '', 'the sweep produced nothing')
    cache = out
    return out
end

local function count(out)
    local frames, bidpos, f587, f612, f621 = out:match(
        'COUNT frames=(%d+) bidpos=(%d+) fire587=(%d+) fire612=(%d+) fire621or628=(%d+)')
    assert(frames, 'the sweep did not report a COUNT line:\n' .. out)
    return tonumber(frames), tonumber(bidpos), tonumber(f587), tonumber(f612), tonumber(f621)
end

tests['[control] the sweep drove the whole corpus with no errored frame'] = function()
    local out = sweep()
    local frames = count(out)
    assert(frames == 993,
        'expected the 993-frame live-hero slice the sibling sweeps use, got ' .. frames)
    assert(not out:find('\nERR ', 1, true) and not out:find('\nERRLOAD ', 1, true),
        'the sweep reported at least one errored frame -- the counts below are not a census')
    local rows = 0
    for _ in out:gmatch('\nFRAME ') do rows = rows + 1 end
    assert(rows == frames, 'FRAME rows (' .. rows .. ') do not match the COUNT (' .. frames .. ')')
end

tests['[control] the site classifier reproduces the published roamreach bid'] = function()
    -- If the classifier were vacuous every frame would read site=0. It does not:
    -- on the frame tests/test_roamreach_bounded_chase.lua is built on, this
    -- sweep independently reads 0.72 -- that file's `CEIL` -- and classifies the
    -- delivery as one of the two shadowed sites.
    local out = sweep()
    local bid, site = out:match(
        'FRAME f_260819_181742_ss_chase_start%.lua npc_dota_hero_shadow_shaman bid=([%d%.]+) site=(%d+)')
    assert(bid, 'the roamreach start frame is no longer in the corpus')
    assert(math.abs(tonumber(bid) - 0.72) < 1e-9,
        'expected the lane-capped 0.72 that roamreach publishes, got ' .. bid)
    assert(tonumber(site) == 621, 'expected delivery through a shadowed site, got ' .. site)
end

tests['[recorded] the exposure is 58 of 993 frames over 29 fixtures'] = function()
    local out = sweep()
    local frames, bidpos, f587, f612, f621 = count(out)
    assert(bidpos == 68, 'expected 68 frames with a positive team_roam bid, got ' .. bidpos)
    assert(f621 == 58, 'expected 58 frames delivering through a shadowed site, got ' .. f621)
    assert(f612 == 0, 'expected the tower-creep consumer to fire on no frame, got ' .. f612)
    assert(f587 == 0, 'expected the hTargetCreep consumer to fire on no frame, got ' .. f587)
    assert(frames == 993)

    local seen, n = {}, 0
    for fx, site in out:gmatch('\nFRAME (%S+) %S+ bid=[%d%.]+ site=(%d+)') do
        if site == '621' and not seen[fx] then seen[fx] = true; n = n + 1 end
    end
    assert(n == 29, 'expected the exposure spread over 29 distinct fixtures, got ' .. n)
end

tests['[recorded] the setter is UNMEASURABLE: three unwired values, one per door'] = function()
    local out = sweep()

    -- Door 1: the mode gate. Not one zero-bid frame falls through it, so the
    -- whole `elseif` half of GetDesireHelper is unreached -- CarryFindTarget and
    -- SupportFindTarget included, which is a wider consequence than this file's
    -- own subject (see the [limit] below).
    local zero, gate, cnt, alive, far = out:match(
        'REACH zerobid=(%d+) gate=(%d+) count=(%d+) alive=(%d+) far=(%d+)')
    assert(zero, 'the sweep did not report a REACH line')
    assert(tonumber(zero) == 925, 'expected 925 zero-bid frames, got ' .. zero)
    assert(tonumber(gate) == 0,
        'the mode gate opened on ' .. gate .. ' frame(s) -- the tower block is REACHABLE now,'
        .. ' so the setter can finally be measured; re-read this whole file')
    -- The other three clauses of the same reach predicate are NOT the blocker,
    -- and recording that is what makes `gate=0` an attribution instead of a bare
    -- zero: they pass on the large majority of the same frames.
    assert(tonumber(alive) == 925, 'expected every zero-bid frame alive, got ' .. alive)
    assert(tonumber(cnt) == 847, 'expected 847 frames with a non-adverse count, got ' .. cnt)
    assert(tonumber(far) == 845, 'expected 845 frames beyond 4600u, got ' .. far)

    -- Door 2: the 1502 anim clause, ahead of ShouldAttackTowerCreep's first
    -- three returns. Five of the six head clauses pass on most frames; the anim
    -- one passes on none, and the histogram says why -- one value, everywhere.
    local lvl, anim, notgt, noatk, hp38, nodmg, all6 = out:match(
        'CLAUSE lvl=(%d+) anim=(%d+) notgt=(%d+) noatk=(%d+) hp38=(%d+) nodmg=(%d+) all6=(%d+)')
    assert(lvl, 'the sweep did not report a CLAUSE line')
    assert(tonumber(anim) == 0, 'GetAnimActivity answered 1502 on ' .. anim .. ' frame(s)')
    assert(tonumber(all6) == 0, 'the head guard passed on ' .. all6 .. ' frame(s)')
    assert(tonumber(lvl) == 921 and tonumber(notgt) == 993 and tonumber(noatk) == 993
        and tonumber(hp38) == 898 and tonumber(nodmg) == 913,
        'the other five head clauses moved; the "one clause does all the killing"'
        .. ' attribution has to be re-derived')
    local hist = out:match('\nANIM ([^\n]+)')
    assert(hist == '0=993',
        'GetAnimActivity is no longer a single unwired default across the corpus: ' ..
        tostring(hist))

    -- Door 3: the fourth and last return, which is NOT behind the anim clause.
    -- Its own gate is shut by a different unwired value: friendly towers ARE
    -- wired (264 frames carry one), their attack target is not.
    local reach, tow, towtgt, lvl12 = out:match(
        'FOURTH reach=(%d+) tow1600=(%d+) towtgt=(%d+) lvl12=(%d+)')
    assert(reach, 'the sweep did not report a FOURTH line')
    assert(tonumber(tow) == 264, 'expected 264 frames with a friendly tower in 1600, got ' .. tow)
    assert(tonumber(towtgt) == 0,
        'a tower reported an attack target on ' .. towtgt .. ' frame(s) -- the fourth return'
        .. ' is measurable now')
    assert(tonumber(lvl12) == 947, 'expected 947 frames at level <= 12, got ' .. lvl12)
    assert(tonumber(reach) == 0, 'expected the tower block reached on no frame, got ' .. reach)
end

tests['[limit] what these numbers do NOT establish'] = function()
    -- Written as a test so it cannot rot into a paragraph nobody re-reads. Each
    -- line is a claim this file is NOT making.
    local out = sweep()
    assert(count(out) == 993)

    -- L1. `1502` is a raw engine literal in the shipped source. The mock's
    --     ACTIVITY_ATTACK is a sentinel in the 1100s, so even a wired anim
    --     activity would have to carry the REAL constant, not the mock's.
    assert(ACTIVITY_ATTACK == nil or ACTIVITY_ATTACK ~= 1502,
        'if the mock ever answers 1502 for ACTIVITY_ATTACK, this limit is void')

    -- L2. X.IsMostAttackDamage is a file local and is NOT evaluated by the
    --     sweep, so `towtgt = 0` is sufficient for the fourth return to be shut
    --     but the attribution is not exclusive: that clause is unread.

    -- L3. `fire587 = 0` is CONSISTENT with the promoted `roamstale` reset doing
    --     its job, but does not attribute to it -- X.GetLastHitCreep may simply
    --     have returned nil on every frame, and this sweep cannot tell those
    --     apart. Do not quote this as a roamstale confirmation.

    -- L4. 5.8% is the exposure of the SHADOWED SITES, not of the defect. The
    --     defect additionally needs the flag to be stale-true on entry, and the
    --     corpus cannot produce that state at all (the setter is unreachable
    --     here), so this file measures an upper bound on frequency and says
    --     nothing about the joint.

    -- L5. The corpus is fixture-selected -- frames were saved because something
    --     interesting happened -- so every percentage here is a shape and a
    --     bound, not a rate in play.

    -- L6. `gate=0` voids more than this subject: any past conclusion of the form
    --     "team_roam does / does not do X" that ran through CarryFindTarget or
    --     SupportFindTarget was taken on frames where neither function was ever
    --     called. This file records that; it does not go audit it.
end

return tests
