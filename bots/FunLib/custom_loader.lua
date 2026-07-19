local Customize = nil

-- Dev-only soak-farm drafting. Customize/soak_pool.lua exists ONLY on farm
-- instances (gitignored, never shipped): a flat list of internal hero names.
-- Each team scope derives the FULL draft (both teams' picks) from one seed,
-- via a local Park-Miller LCG (double-safe in Lua 5.1):
--   * If the team scopes share a Lua VM, the first scope stashes its seed in
--     _G and the second reuses it — both compute identical partitions and
--     samples, so cross-team duplicate picks are impossible.
--   * If the scopes are isolated VMs, seeds differ and the partitions can
--     disagree — a duplicated pick degrades to OHA's random-available
--     fallback at selection time; occasional, harmless noise.
-- Seeding constraints learned from farm data (iteration 0001): RealTime() is
-- elapsed-since-process-start (NOT wall clock), so any coarse bucket of it is
-- identical every launch; and engine RandomInt() repeats the same sequence at
-- file-load time in the first-loaded scope (radiant drafted the same 5 heroes
-- 18/18 games). The reliable per-launch entropy at load time is the
-- sub-second load-timing jitter in RealTime(), so that drives the seed, with
-- RandomInt mixed in as a secondary source only.
-- Without the pool file this is a silent no-op.
local function ApplySoakDraft( tCustomize )
	local bOk, tPool = pcall( dofile, GetScriptDirectory()..'/Customize/soak_pool' )
	if not bOk or type( tPool ) ~= 'table' or #tPool < 10 then return end

	local tG = type( _G ) == 'table' and _G or nil
	local nSeed = tG and rawget( tG, '__SOAK_DRAFT_SEED' )
	if not nSeed then
		nSeed = ( math.floor( ( RealTime() % 1 ) * 1e6 ) * 31
			+ math.floor( RealTime() ) * 7
			+ RandomInt( 1, 1048576 ) ) % 2147483646 + 1
		if tG then rawset( tG, '__SOAK_DRAFT_SEED', nSeed ) end
	end

	local s = nSeed
	local function NextRand( n )
		s = ( s * 16807 ) % 2147483647
		return ( s % n ) + 1
	end

	-- Split the pool by role so each team gets a position-ordered comp:
	-- slots 1-3 (RoleAssignment pos 1/2/3) = cores, slots 4-5 = supports.
	-- 'either' heroes backfill whichever bucket runs short. Accepts both the
	-- new {name, role} pool format and the legacy flat-string format.
	local tCore, tSupport, tEither = {}, {}, {}
	for i = 1, #tPool do
		local e = tPool[i]
		if type( e ) == 'table' and e.name then
			local r = e.role
			if r == 'core' then tCore[#tCore + 1] = e.name
			elseif r == 'support' then tSupport[#tSupport + 1] = e.name
			else tEither[#tEither + 1] = e.name end
		else
			tEither[#tEither + 1] = e
		end
	end
	local function Shuffle( t )
		for i = #t, 2, -1 do
			local j = NextRand( i )
			t[i], t[j] = t[j], t[i]
		end
	end
	Shuffle( tCore ); Shuffle( tSupport ); Shuffle( tEither )

	-- Deal in a fixed order so both team VMs (shared seed) agree and never
	-- collide: radiant cores, dire cores, radiant sups, dire sups.
	local function Take( t )
		return table.remove( t ) or table.remove( tEither )
	end
	local tRadCore, tDireCore, tRadSup, tDireSup = {}, {}, {}, {}
	for _ = 1, 3 do tRadCore[#tRadCore + 1] = Take( tCore ); tDireCore[#tDireCore + 1] = Take( tCore ) end
	for _ = 1, 2 do tRadSup[#tRadSup + 1] = Take( tSupport ); tDireSup[#tDireSup + 1] = Take( tSupport ) end

	local function Comp( tCores, tSups )
		local tOut = {}
		for i = 1, #tCores do tOut[#tOut + 1] = 'npc_dota_hero_'..tCores[i] end
		for i = 1, #tSups do tOut[#tOut + 1] = 'npc_dota_hero_'..tSups[i] end
		return tOut
	end
	tCustomize.Radiant_Heros = Comp( tRadCore, tRadSup )
	tCustomize.Dire_Heros = Comp( tDireCore, tDireSup )
	print( '[SOAK] role-balanced draft applied (seed='..nSeed..')' )
end

function LoadCustomize()
	if Customize then return Customize end
	local sDir, tSet = "game/Customize/general", nil
	local status, _ = xpcall(function() tSet = require( sDir ) end, function( err ) print( '[WARN] When loading customized file: '..err ) end )
	if status and tSet then
		Customize = tSet
	else
		if GetScriptDirectory() == 'bots' then Customize = require('bots.Customize.general')
		else Customize = require( GetScriptDirectory()..'/Customize/general' ) end
	end
	ApplySoakDraft( Customize )
	return Customize
end
return LoadCustomize()
