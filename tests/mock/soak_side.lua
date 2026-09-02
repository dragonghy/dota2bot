--- The one owner of `bots/Customize/soak_side.lua` inside the test suite.
--
-- WHAT THIS IS FOR.  Twenty-two test files arm gates by writing that one path
-- and then `os.remove`ing it, each with its own copy-pasted three lines and no
-- owner (hero backlog `-77`).  The copies share three defects, and all three
-- fail in the SAME direction -- "the gate did not fire":
--
--   1. `f:write` / `f:close` return values dropped, the bytes never read back.
--      A short write, a full disk, a read-only tree, or another test file
--      already holding the path all present as an unarmed reading.
--   2. `os.remove` with no ownership.  A file this process did not create gets
--      deleted anyway, which is how an INHERITED leftover disappears before any
--      guard can name it (GH #417: a planted leftover survived a per-case guard
--      19/19 green, because the armed cases sort first and delete it).
--   3. Nothing re-reads the switch at the moment the assertion is taken.  The
--      path is ONE global inode shared by every concurrent `lua5.1` process, so
--      an unarmed leg in another process removes it mid-case -- this is the
--      measured cause of the three "true reds" of GH #365 §3, reproduced byte
--      for byte under a concurrent `rm` loop and recorded in
--      tests/test_soakside_shared_switch.lua.
--
-- "The gate did not fire" is what MOST cases in a gated test file expect, so a
-- harness fault reads as a pass in most places and as one mystery assertion
-- mismatch somewhere else.  That is the wrong direction for a gate harness to
-- fail in, and it is why these three get one checked implementation instead of
-- twenty-two unchecked ones.
--
-- OWNERSHIP, stated once so the copies stop having to decide it each:
--
--   * `arm` REFUSES to overwrite a switch this module did not write.  A file
--     that is already there belongs to someone else (another case that died
--     between its write and its remove, another process, the farm) and is
--     reported, never clobbered.
--   * `disarm` removes ONLY bytes this module wrote AND that are still ours.
--     If the content changed under us we drop ownership and leave the file --
--     deleting a stranger's switch is what makes the next process's failure
--     unattributable.
--   * `assert_still_armed` is taken AFTER the case body and BEFORE any
--     assertion error is re-raised, so "the switch was removed under us" is
--     reported INSTEAD of the value mismatch it caused.  Without it, GH #365
--     §3 spent a round arguing about three expected values that were never in
--     doubt.
--
-- SCOPE.  This does NOT fix the contention itself; the path is still one global
-- literal and two concurrent processes still race for it.  Serialising or
-- uniquifying the switch is GH #229 and needs a change on the reader side
-- (`jmz_func.lua` reads `GetScriptDirectory()..'/Customize/soak_side'`, and
-- GetScriptDirectory also loads every module, so it cannot simply be repointed
-- at a per-process directory).  What this buys is that the race stops
-- presenting as an unarmed reading and starts presenting as a named failure.

local M = {}

--- The switch, gitignored, farm-only.  One literal, on purpose: it is the same
--- inode the game reads, and a test that armed some other path would be
--- measuring nothing.
local PATH = 'bots/Customize/soak_side.lua'
M.PATH = PATH

--- The exact bytes this module last wrote, or nil when it owns nothing.
--- Module-level: `api.reset_modules()` only clears `bots/` modules, so this
--- survives the reloads a gate test does between cases.
local sOwned = nil

local function slurp()
    local fh = io.open(PATH, 'r')
    if fh == nil then return nil end
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Current bytes of the switch, or nil when it does not exist.
M.read = slurp

--- The line the farm writes.  `sSide` defaults to radiant because most fixture
--- subjects are radiant; the salve/tp files pass 'dire' explicitly.
function M.body(sCand, sSide)
    return "return { side = '" .. (sSide or 'radiant') .. "', cand = '"
        .. sCand .. "' }\n"
end

--- Nothing may be armed here.  Call this at FILE LOAD time (the only moment
--- that sees the state the process started in) and from the unarmed cases.
function M.assert_clean(sWhere)
    local s = slurp()
    if s == nil then return end
    error(PATH .. ' already exists' .. (sWhere and (' (' .. sWhere .. ')') or '')
        .. ', so "gate off" is NOT what this measures. Some other case -- here, '
        .. 'in one of the other test files that write this path, or in a '
        .. 'concurrent lua5.1 process -- armed a candidate and did not remove '
        .. 'it. Contents: ' .. tostring(s), 0)
end

--- The whole write, once: refuse a stranger's switch, write, PROVE the bytes
--- landed, take ownership.  `sWhat` names the subject in the failure text.
--- Both public entry points go through here, so a second entry point cannot
--- quietly become a fourth unchecked copy of the three lines.
local function arm_bytes(sWant, sWhat)
    local sPrior = slurp()
    if sPrior ~= nil and sPrior ~= sOwned then
        error(PATH .. ' is already there and this process did not write it, so '
            .. 'arming would clobber someone else\'s switch (and deleting it '
            .. 'afterwards would make THEIR failure unattributable). '
            .. 'Contents: ' .. tostring(sPrior), 0)
    end

    local f, eOpen = io.open(PATH, 'w')
    if f == nil then
        error('cannot open ' .. PATH .. ' for writing, so the gate cannot be '
            .. 'armed at all: ' .. tostring(eOpen), 0)
    end
    local okw, errw = f:write(sWant)
    local okc, errc = f:close()
    if not okw then
        error('writing ' .. PATH .. ' failed: ' .. tostring(errw), 0)
    end
    if not okc then
        error('closing ' .. PATH .. ' failed: ' .. tostring(errc), 0)
    end
    local sGot = slurp()
    if sGot ~= sWant then
        error(PATH .. ' does not hold what we just wrote, so ' .. sWhat
            .. ' is NOT armed and anything measured under it is measuring the '
            .. 'unarmed tree. Wanted ' .. string.format('%q', sWant)
            .. ', read back ' .. string.format('%q', tostring(sGot)) .. '.', 0)
    end
    sOwned = sWant
    return sWant
end

--- Write the switch and PROVE the bytes landed.  Returns the bytes written.
function M.arm(sCand, sSide)
    assert(type(sCand) == 'string' and sCand ~= '',
        'arm() needs a candidate id; pass nil to with_candidate for the '
        .. 'unarmed leg instead of arming an empty string')
    return arm_bytes(M.body(sCand, sSide), '`' .. sCand .. '`')
end

--- Arm EXACT bytes, for the one file whose subject is the gate resolver itself
--- (tests/test_soak_cand_ref_gate.lua).  It must write shapes `M.body` cannot
--- express -- a closed gate (`side = false, cand = false`) and the two-leg
--- `cand_ref` of GH #141 -- and it is the file that would suffer most from
--- reading an unarmed tree, since "the gate is shut" is what four of its cases
--- assert.  Everything else should use `arm`/`with_candidate`.
function M.arm_body(sBody)
    assert(type(sBody) == 'string' and sBody ~= '',
        'arm_body() needs the exact bytes of a gate file')
    if sBody:sub(-1) ~= '\n' then sBody = sBody .. '\n' end
    return arm_bytes(sBody, 'that gate file')
end

--- Still ours, byte for byte?  Raise the switch cause rather than let the
--- unarmed reading it produced be argued about as an expected-value bug.
function M.assert_still_armed()
    if sOwned == nil then return end
    local sGot = slurp()
    if sGot == sOwned then return end
    error(PATH .. ' was ' .. (sGot == nil and 'REMOVED' or 'CHANGED')
        .. ' under this case, so the armed leg read no switch and any value it '
        .. 'produced is the UNARMED value -- do not "fix" the expectation. One '
        .. 'global path is shared by every gate test and by every concurrent '
        .. 'lua5.1 process, and each of them deletes it (GH #365 §3, GH #229). '
        .. 'Wanted ' .. string.format('%q', sOwned) .. ', found '
        .. (sGot == nil and 'no file' or string.format('%q', sGot)) .. '.', 0)
end

--- Remove only what we wrote and still own, and prove it went.
function M.disarm()
    if sOwned == nil then return end
    if slurp() ~= sOwned then
        -- Someone else's bytes are sitting there now. Not ours to delete.
        sOwned = nil
        return
    end
    sOwned = nil
    os.remove(PATH)
    local sLeft = slurp()
    if sLeft ~= nil then
        error(PATH .. ' survived os.remove, so every case after this one would '
            .. 'silently run ARMED while claiming to be unarmed. Contents: '
            .. tostring(sLeft), 0)
    end
end

--- Close a span that was armed by hand (the files that must load a fixture
--- BETWEEN the write and the case body cannot use `with_candidate`).  `ok,
--- err` are the pcall results of the body.  The one place the ordering lives.
function M.finish(ok, err)
    local okSwitch, errSwitch = pcall(M.assert_still_armed)
    M.disarm()
    if not okSwitch then error(errSwitch, 0) end
    if not ok then error(err, 0) end
end

--- Arm `sCand` for the duration of `fn`, or run `fn` on a provably clean
--- switch when `sCand` is nil (the unarmed leg -- which in the copies was
--- itself an unconditional `os.remove`, i.e. a deleter of other processes'
--- switches).
function M.with_candidate(sCand, fn, sSide)
    if sCand == nil then
        M.assert_clean('unarmed leg')
        local ok, err = pcall(fn)
        if ok then M.assert_clean('unarmed leg, after the case body') end
        if not ok then error(err, 0) end
        return
    end

    M.arm(sCand, sSide)
    local ok, err = pcall(fn)
    -- Order matters: the switch cause OUTRANKS the assertion it caused.
    M.finish(ok, err)
end

--- `with_candidate` for exact bytes (see `arm_body`).  Same ordering.
function M.with_body(sBody, fn)
    M.arm_body(sBody)
    local ok, err = pcall(fn)
    M.finish(ok, err)
end

return M
