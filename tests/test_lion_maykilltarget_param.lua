-- ===========================================================================
-- GH #785 -- X.MayKillTarget honours its parameter for ALL THREE of its
-- readings, not just the first one.
--
-- This is a RATCHET on a provable-equivalence refactor, not a behavior test.
-- The change it guards had zero behavior delta on the day it landed (both call
-- sites pass `botTarget`, so `nTarget == botTarget` identically), and that is
-- exactly why nothing else in the suite can notice if it regresses.
--
-- WHAT WOULD REGRESS.  Someone re-introduces a file-scope `botTarget` read
-- inside the body -- by reverting, by copy-paste from a sibling function, or by
-- "fixing" a nil warning.  The function would then answer questions about a unit
-- the caller never named, silently: no error, no nil, and no luacheck warning,
-- because `botTarget` is a legal file-scope local.
--
-- ⛔ WHY THE ASSERTION IS "NAMES NO FILE-SCOPE TARGET" AND NOT "READS nTarget
-- THREE TIMES".  The second form is satisfiable by a body that reads `nTarget`
-- three times AND `botTarget` once more; the defect is the presence of the
-- second name, so the presence is what is asserted.
--
--     lua5.1 tests/run_tests.lua
--     lua5.1 -e "for n,f in pairs(dofile('tests/test_lion_maykilltarget_param.lua')) do f() end"
-- ===========================================================================

local SRC   = 'bots/BotLib/hero_lion.lua'
local FN    = 'MayKillTarget'
local PARAM = 'nTarget'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting CODE shapes cannot be satisfied --
--- or broken -- by prose.  The header above this function talks about
--- `botTarget` at length on purpose; that must not count.
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Whole-word count, so `botTarget` is not also matched inside a longer
--- identifier such as `botTargetList`.
local function count_word(hay, word)
    local n = 0
    for _ in hay:gmatch('%f[%w_]' .. word .. '%f[^%w_]') do n = n + 1 end
    return n
end

local SRC_TEXT = strip_comments(read_file(SRC))
local BODY = fn_body(SRC_TEXT, FN)

tests['§1 X.MayKillTarget still takes the parameter GH #785 is about'] = function()
    assert(SRC_TEXT:find('function X%.' .. FN .. '%s*%(%s*' .. PARAM .. '%s*%)'),
        'X.' .. FN .. ' no longer takes a single parameter named ' .. PARAM
        .. '.  GH #785 offered two fixes and this file pins the first (honour the '
        .. 'parameter).  If the second was chosen instead -- drop the parameter and '
        .. 'rename the function -- this file should be deleted, not edited')
end

tests['§2 the body names no file-scope target: every reading goes through the parameter'] = function()
    local nBot = count_word(BODY, 'botTarget')
    assert(nBot == 0, 'X.' .. FN .. ' reads the file-scope `botTarget` ' .. nBot
        .. ' time(s).  That is GH #785 exactly: the signature promises an answer '
        .. 'about the unit the caller named, and a `botTarget` read silently '
        .. 'answers about a different one.  Today both call sites pass botTarget, '
        .. 'so this costs nothing and NOTHING ELSE IN THE SUITE WILL NOTICE -- '
        .. 'which is why it is pinned here')
end

tests['§3 all three readings are present and all three are the parameter'] = function()
    assert(count_word(BODY, PARAM) == 4, 'X.' .. FN .. ' names ' .. PARAM .. ' '
        .. count_word(BODY, PARAM) .. ' time(s), not 4 (the declaration plus its '
        .. 'three readings) -- re-derive this census before trusting §2')
    for _, needle in ipairs({
        PARAM .. ':HasModifier',
        'GetEstimatedDamageToTarget( true, ' .. PARAM,
        'J.CanKillTarget( ' .. PARAM,
    }) do
        assert(BODY:find(needle, 1, true),
            'X.' .. FN .. ' no longer contains `' .. needle .. '`.  One of the '
            .. 'three readings changed shape; §2 counts names, so it can pass '
            .. 'while a reading has quietly gone somewhere else')
    end
end

--- ⛔ The equivalence claim itself, pinned.  §2 says the body is clean; this
--- says the refactor was a NO-OP when it landed, which is the whole reason it
--- shipped ungated.  If a call site ever passes something other than `botTarget`,
--- the change stops being equivalent retroactively -- fine, but then the hero
--- file's header paragraph ("byte-for-byte the same thing today") is stale and
--- has to be re-read before it is repeated.
tests['§4 both call sites still pass botTarget, which is what made the refactor a no-op'] = function()
    local nCalls, nWithBotTarget = 0, 0
    for line in SRC_TEXT:gmatch('[^\n]+') do
        if line:find('X%.' .. FN .. '%s*%(') and not line:find('function X%.' .. FN) then
            nCalls = nCalls + 1
            if line:find('X%.' .. FN .. '%(%s*botTarget%s*%)') then
                nWithBotTarget = nWithBotTarget + 1
            end
        end
    end
    assert(nCalls == 2, 'X.' .. FN .. ' now has ' .. nCalls .. ' call sites, not 2')
    assert(nWithBotTarget == nCalls,
        'only ' .. nWithBotTarget .. ' of ' .. nCalls .. ' call sites pass '
        .. '`botTarget`.  The GH #785 refactor was justified as byte-for-byte '
        .. 'equivalent BECAUSE they all did.  It is still the correct code -- the '
        .. 'parameter is now honoured -- but the equivalence sentence in the hero '
        .. 'file header no longer describes today, and a reader must not repeat it')
end

return tests
