# Frame-by-frame observation — focus-hero deaths (2026-07-22)

Watched ~19 Wraith King deaths + Zeus deaths across 5 Turbo games
(run spot_20260721_225025, current code) **tick by tick** — not aggregate
detectors. Method: `scratchpad/watch.py` traces every focus-hero death with
per-second HP + position (distance-to-own-vs-enemy-ancient) + all
allies/enemies within 1700u.

## Methodology honesty note
My first trace tool had a **sign bug** (labelled a dire hero's own half as
"enemy half"), which nearly produced the exact wrong conclusion ("WK
overextends deep") — twice. Caught by cross-checking against the ancient
coordinates and a hand trace. Corrected tool uses `dist(own_ancient) −
dist(enemy_ancient)`. All findings below are post-fix and consistent with the
hand trace.

## What actually kills WK (verified)
Killers across the deaths: **Lich ×7, Sniper ×6, Obsidian Destroyer ×3,
Sven ×2** — every one a ranged nuker / DPS or a blink-stun burst.

Death classification tags (from the traces):
- **`own-half` dominates (~15/19).** WK does NOT overextend into enemy
  territory — it dies on its OWN side, getting picked/whittled/bursted at home.
- **`BURST` dominates (~10/19): 100%→55%, 95%→43%, 99%→49%, 67%→0%, 56%→0%,
  51%→0%, 47%→0%, 65%→0%.** WK goes from FULL/healthy to dead in **2–3
  seconds**. It is deleted before any HP-threshold retreat can fire.
- **`ALLY-LEFT` recurs (~5): ogre ×2, skywrath, jakiro, witch_doctor** — the
  support is present when the fight starts, then drifts away as WK is dying,
  turning a 2v2 into a 1v2.

## The one core mechanism (smoking gun: 232320 6:25 and 230545 5:15)
- **230545 5:15:** WK at **100% HP** walks toward a Sven+Lich pair (Ogre with
  it). Sven blink-stun + God's Strength + Lich nuke → 100%→55% in 1s → dead in
  4s. A "2v2" that WK never got to fight — it was focused and deleted first.
- **232320 6:25:** WK stands at **87% HP with OD 54u away for 4 straight
  seconds**, doesn't disengage, then OD orbs/ults → 88%→36%→dead.

**Diagnosis:** the bots commit to numerically-fair fights
(`SafeToCommitFight`: parity → go), but in a fair fight the **squishiest /
lowest-farm hero (WK) is the focus target and gets BURST down first**, turning
2v2 → 1v2 the instant WK dies. The commit/retreat logic models neither
(a) **incoming burst lethality against *itself*** (85% next to an OD is
already dead) nor (b) **"I will be focused."** Danger is judged by *current
HP*, which is far too slow against burst.

## WK is in a death spiral
Weakest hero → focused every fight → dies (5×/game) → falls further behind →
weaker → dies more. The aggregate symptoms (15 CS, 0.6 kills, 661 GPM) are
CONSEQUENCES of dying constantly, not the disease (cf. #16: low CS is a
symptom).

## Honest correction to my own recent work
**My #17 fix (an earlier-2nd-stun skill build for "kill participation") targets
the WRONG problem.** WK's problem is not kill participation — it is that it
**dies 5×/game to burst**. The skill build does nothing for survivability,
burst-anticipation, or support follow-through. Kill participation is downstream
of not being dead.

## Fix directions (HYPOTHESES — to be watched/validated, not shipped on faith)
1. **Defensive burst-anticipation (highest value, general):** a hero should
   flee / not-commit when *visible adjacent enemies can burst it below a lethal
   threshold in the next ~3s* (`GetEstimatedDamageToTarget` from enemies → self),
   even at high current HP. This is the inverse of SafeToCommitFight's lethal
   check. Would prevent the 100%→dead and 87%-next-to-OD deaths.
2. **Don't let the focus-target commit to a "fair" fight:** the lowest-net-worth
   ally on a team should require a bigger margin than parity to commit (it will
   be focused). A per-hero discount in the commit gate.
3. **WK survivability itemization** vs a nuker-heavy enemy (magic resist / BKB
   timing) — but this is downstream and slow; #1/#2 are the leverage.
4. **Support follow-through** (the ALLY-LEFT pattern) — supports disengaging
   mid-trade. (Note: lf_support "glue to carry" already A/B-REJECTED; the fix is
   about not BAILING once committed, not proximity.)

## Caveat
~19 deaths in 5 games is a strong signal but one hero pool / matchup. Watch more
games (other focus heroes, other enemy drafts) before committing a fix. #1
(burst-anticipation) is the most general and most testable locally (fixture).
