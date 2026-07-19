# Laning / Early-Game Behavior Bugs — from owner's replay review (2026-07-19)

Source: replay `auto-20260719-1418` (Radiant: viper/skywrath/centaur/sniper/
warlock; a NORMAL-mode game — confirmed by levels ~6 @11min and ~30 gold/creep,
matching owner's live observation). Priority = owner's emphasis × tractability.
Most are mode-independent AI fixes; a few are turbo-specific pacing.

## A. TP-home logic overhaul (owner's #1 emphasis, turbo-critical)
- **"No mana/low HP → TP home" must be heavily suppressed.** Observed: Warlock,
  Witch Doctor (5:40), Skywrath (5:40), Axe (3:42) all TP'd home to refill
  state while NOT being chased. In turbo the courier round-trips fast; lane
  XP/gold is precious → almost never TP home just to heal.
- Correct behavior when low state but not in danger: buy salve/regen +
  courier it out, hang back in fog near the wave, soak XP, ranged last-hit if
  possible; pull a small/large camp while regenerating.
- **原地 TP bug**: Zeus (after Jakiro died) and Axe (3:42) channeled TP
  in-place with enemies on their face instead of walking to safety first.
  Two sub-bugs: (a) TP when simply walking away would escape; (b) TP without
  first retreating to a safe spot. Channeling TP under threat = wasted/death.

## B. Kill-if-lethal in lane (owner: "if your damage calc can kill, go")
- If summed ally ability damage in range can kill the enemy laner, commit.
  Example: Zeus+Jakiro trivially kill Sniper. (Bots partly do this already —
  tighten the lethality calc so it triggers reliably.)

## C. Tower-dive punish + rotations (turbo: cheap TP → rotate more)
- **Punish enemy tower-dives when an ally has TP.** 6:13: enemy Axe dove
  Centaur under our tower; Centaur stun + Viper TP (3s) = free kill, didn't
  happen. When an ally core with TP up + a lockdown ally is near a diving/
  overextended enemy, trigger a coordinated collapse.
- **Punish enemies loitering at our T1** (Axe+WD parked at dire T1 for 6+ min):
  Skywrath slow + Centaur stun + Viper TP should catch at least one.
- **Mid should rotate** to a fight at our own tower — mid stood idle while a
  fight happened at our tower.

## D. Lane equilibrium / creep control (mode-independent skill)
- **Creep-aggro pull (勾线)** for the LOSING laner: issue an attack order on the
  enemy hero near enemy creeps (don't need to land it) → enemy creeps aggro →
  step back → drags the wave back so the loser can CS instead of being zoned
  off entirely.
- **Zoning when winning**: step PAST the wave to body-block/harass; orb-walkers
  (viper) free-harass over creeps; win→step up, lose→step back.
- **Don't unintentionally push**: avoid hitting creeps with damage spells
  unless intentionally pushing (CM nova, Warlock bonds, etc.).
- **Pull to reset a shoved lane**: small camp ~:47, big camp ~:55 (own),
  enemy big camp ~:47 on the losing lane; skip pulling if already shoved to
  our tower.

## E. Support/carry CS division (mode-independent)
- Supports: deny + harass ONLY; never contest the carry's last hits (exception:
  carry physically can't reach → support may take it).
- Carry: focus CS (last-hit + deny).

## F. Positioning / pathing bugs
- **迷之走位**: Witch Doctor at 1:39 walked between two enemies (not attacking)
  and took free harass. Some target/position check misfires.
- **Teamfight participation**: Skywrath stood watching while Centaur dove and
  got focused — must either help (even auto-attack for chip) or retreat, not
  idle (he dies next anyway).

## G. Per-hero skill-build / cast logic
- **Skywrath**: cast Silence alone (no damage) then nothing. Silence should
  lock enemy casts OR be immediately followed by Arcane Bolt/Concussive for
  burst; solo silence is pointless.
- **Warlock**: lane build maxes the two push spells + channels Upheaval under
  creep fire (no hero hit, self to low HP). Should take Shadow Word for lane
  sustain/harass; don't channel into creeps.

## H. Draft/position (FIXED this session — role-balanced draft, commit 822b669)
- Was: random hero→slot→position, giving 5-support-vs-5-carry comps and
  supports in carry lanes. Now cores→pos1-3 slots, supports→pos4-5 slots.

---
### Meta blocker: TURBO MODE NOT ACTIVE
The farm runs NORMAL mode (levels ~6@11min, team GPM sums ~normal, courier
speed normal) despite `+dota_force_gamemode 23`. Tried force_gamemode 23,
practice_gamemode 23, reordered launch, addon reset — all still normal on
this `-dedicated -nogc` server. Turbo has never actually run on this farm.
Turbo-specific tuning (A's aggressiveness, C's rotation frequency) needs this
resolved; the mode-independent fixes (B/D/E/F/G) can proceed now.
