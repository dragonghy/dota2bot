-- [itemtrip / GH #120] Contest the healthy trip home for stash items.
--
-- BOT_MODE_ITEM is Valve's BUILT-IN mode in this tree: the only item-mode
-- script here is bots/--mode_item_generic.lua, and the `--` prefix means the
-- engine (which loads mode scripts by fixed name) never finds it. So nothing
-- in bots/ has ever had a say in this bid, which is why the replay desk could
-- attribute 643 high-HP home TPs across 283 turbo games to every branch in the
-- tree and still be left with 76 (0.27/game, median round trip 40.1s) that no
-- branch explains. Full write-up and the four-quantity clause budget:
-- J.IsWastefulItemTrip in FunLib/jmz_func.lua; the reachability audit that had
-- to come first: tests/test_itemtrip_supply_gap.lua.
--
-- THE GATE IS LOAD-TIME, ON PURPOSE, AND IT IS THE WHOLE SAFETY ARGUMENT.
-- Unarmed, this file defines no GetDesire at all, so the engine has nothing to
-- call and keeps its built-in bid -- an unarmed game is byte-for-byte the game
-- we ship today. That mechanism needs no documentation contract to be true:
-- bots/mode_attack_generic.lua already installs GetDesire/Think/OnStart/OnEnd
-- only for the nine heroes in Utils.BuggyHeroesDueToValveTooLazy while the
-- other ~118 attack perfectly well, and tests/test_tpwatch_channel_bid.lua
-- asserts on a real frame that at least one mode file leaves the bid to the
-- engine. Deliberately NOT used as the gate: the `GetDesire() returning nil
-- falls through to the built-in` contract in docs/BOT_API_REFERENCE.md:52,
-- which has zero users in this tree. Gating on an undischarged contract fails
-- INVERTED -- if it is wrong, item mode is silently suppressed in every
-- shipped game while wearing a gate's clothes.
--
-- WHAT ARMED MEANS, INCLUDING THE PART THAT IS NOT KNOWN. Armed, this file can
-- only ever LOWER the item-mode bid, never raise it: the wasteful branch
-- returns NONE and the other branch returns nil, and neither is a number the
-- engine can act on positively. So the worst case is "the hero does not fetch
-- its stash", never "the hero goes home more often" -- the failure is bounded
-- on the safe side by construction.
--
-- Within that bound, the nil branch rests on the same undischarged contract as
-- above, and the honest statement is that we do not know which way it goes:
--   * if nil falls through, armed == the built-in bid minus the wasteful
--     frames, which is the lever as designed;
--   * if nil is read as 0, armed == item mode off for the whole game, which is
--     what bots/--mode_item_generic.lua unconditionally did before somebody
--     disabled it by renaming.
-- Both are contained to the armed side of a soak wave, and the (a) verification
-- separates them with no extra instrumentation: if item-mode home trips drop
-- only in #120's wasteful profile the contract holds; if they drop to ~0 the
-- contract is false and we have discharged it for every future author. That
-- prediction is registered BEFORE the wave on purpose.
--
-- Nothing here defines Think. The bid is never raised, so item mode wins only
-- on frames it would have won anyway, and the engine's own arrival behaviour
-- is the right thing to run when it does.

-- The load-time guard reads only things that cannot change during the game.
-- The other mode files also test IsAlive()/IsInvulnerable() here, but this
-- block runs ONCE, at load, so a transient spawn state read at that instant
-- would silently decide the whole game -- and for a gate that must be exactly
-- "armed or not", that is a coin flip we do not need.
local bot = GetBot()

if bot == nil or not bot:IsHero() or bot:IsIllusion() then return end

local botName = bot:GetUnitName()
if botName == nil or not string.find( botName, 'hero' ) then return end

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )

if not J.IsSoakCandidate( 'itemtrip' ) then return end

function GetDesire()
	if J.IsWastefulItemTrip( bot ) then
		return BOT_MODE_DESIRE_NONE
	end

	return nil
end
