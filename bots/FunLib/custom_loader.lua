local Customize = nil

-- Dev-only soak-farm drafting. Customize/soak_pool.lua exists ONLY on farm
-- instances (gitignored, never shipped): a flat list of internal hero names.
-- The two team VMs cannot communicate, so to partition the pool between the
-- teams without cross-team duplicate picks, both VMs derive the SAME
-- partition from a shared input: a coarse wall-clock bucket (5 min) seeding a
-- deterministic shuffle. Radiant takes the first half, Dire the second; each
-- team then truly-randomly samples its 5 from its own half. Pairings rotate
-- every bucket. (~1-2% of games straddle a bucket edge -> teams disagree ->
-- a duplicate pick may fall back to engine-random; harmless noise.)
-- Without the file this is a silent no-op.
local function ApplySoakDraft( tCustomize )
	local bOk, tPool = pcall( dofile, GetScriptDirectory()..'/Customize/soak_pool' )
	if not bOk or type( tPool ) ~= 'table' or #tPool < 10 then return end

	-- deterministic LCG seeded by the shared clock bucket
	local nSeed = math.floor( RealTime() / 300 )
	local s = nSeed
	local function NextRand( n )
		s = ( s * 1103515245 + 12345 ) % 2147483648
		return ( s % n ) + 1
	end
	local tShuffled = {}
	for i = 1, #tPool do tShuffled[i] = tPool[i] end
	for i = #tShuffled, 2, -1 do
		local j = NextRand( i )
		tShuffled[i], tShuffled[j] = tShuffled[j], tShuffled[i]
	end

	local nHalf = math.floor( #tShuffled / 2 )
	local function SampleRange( nFrom, nTo, nCount )
		local tIdx, tOut = {}, {}
		for i = nFrom, nTo do tIdx[#tIdx + 1] = i end
		for _ = 1, nCount do
			local j = RandomInt( 1, #tIdx )
			tOut[#tOut + 1] = 'npc_dota_hero_'..tShuffled[tIdx[j]]
			table.remove( tIdx, j )
		end
		return tOut
	end
	tCustomize.Radiant_Heros = SampleRange( 1, nHalf, 5 )
	tCustomize.Dire_Heros = SampleRange( nHalf + 1, #tShuffled, 5 )
	print( '[SOAK] draft applied (pool='..#tShuffled..', bucket='..nSeed..')' )
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
