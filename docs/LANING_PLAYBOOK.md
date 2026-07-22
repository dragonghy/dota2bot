# Laning Playbook — owner's domain spec (2026-07-22)

Canonical translation of the owner's laning rules into implementable, gated
fixes. **This document is the blueprint for all laning-phase work.** Teamfight
rules come later as a separate spec (GH #23). Positions 2/3/4 to be specced by
the owner later; pos-1 and pos-5 below.

Every rule gets an ID (`L1-*` = pos-1, `L5-*` = pos-5), an API mapping, the
status of existing code, and a fixture strategy. Implementation stays inside
the standard loop: narrow gated fix → replay-fixture validation → accumulate →
one batch A/B.

---

## Position 1 (safelane carry)

### L1-SALVE — "补大药" awareness (foundational)
**Rule:** early waves are near our T1; if a trade goes bad, retreat under tower
— the enemy cannot follow. Unless the enemy can 100→0 you within one CC
duration, a bad trade is fine: **walk back, drink a salve, return full.**
**API:** `item_flask` purchase/hold/use; `J.LaneRegenItemToUse` (lf_salve).
**Status:** COVERED (verified 2026-07-22, no new code needed) — three pieces:
lf_salve (gated) covers *using* a carried salve; `ShouldStayAndRegen` (#2,
SHIPPED) stops wasteful TP-home; and re-purchase ALREADY EXISTS shipped in
`item_purchase_generic.lua` ("Init Healing Items in Lane": laning, level<6,
no flask/tango carried, HP<50%, gold allows -> buys a flask). Remaining nice-
to-have: the "trade is acceptable IF salve-recoverable" link into trade logic
(low priority; lanesurv's peel threshold partially encodes it).

### L1-BURST — don't be 100→0'able (the only real danger)
**Rule:** the only lethal lane threat is being bursted inside CC duration.
**Status:** DONE (gated `lanesurv`): `J.ShouldRetreatLaneBurst` — enemy
currently-castable (mana/cd-aware) burst vs my HP, peel-ally aware. Pinned by
3 real death fixtures + Lion cross-hero. Awaiting A/B.

### L1-DRAG — melee vs double-ranged: drag the wave back (勾线)
**Rule:** melee pos-1 being pecked by two ranged with no support help must
drag the lane: **fake an attack order on the enemy hero → enemy creeps aggro
you → walk back** → wave resets toward our tower; CS under tower.
**API:** attack-order on enemy hero within 500 of enemy creeps flips creep
aggro; `Action_AttackUnit` + retreat point.
**Status:** IMPLEMENTED as `creeppull` (#10, gated) — same mechanic. **Gap:**
its trigger doesn't yet include the specific "I'm melee AND enemy lane is
double-ranged AND they harass on cooldown" case; add as an OR-branch
(`IsRangedAttacker` on the two lane enemies + recent harass damage taken).

### L1-TRADE — trade decision WITH support present
**Rule:** when the support is beside me:
  * **counter-trade:** if together we win the trade or they started it — give
    one spell, back off, support keeps attacking; if they chase me they eat
    the support's damage the whole way = we likely convert a kill.
  * **initiate:** if support poke has them low enough that our combined burst
    kills — go first.
**API:** `GetEstimatedDamageToTarget` both directions (us→them vs them→us),
`J.SafeToCommitFight` (lethal-or-numbers), ally mana/spell state.
**Status:** GAP. Closest pieces: `lanesurv` (the defensive half), SafeToCommit
(numbers). The "give one spell then kite back while support fights" behavior
does not exist. **This is the offensive half of the owner's trade-survival
model.**

### L1-SPLIT — support absent / can't win: passive drag & split
**Rule:** can't win the lane → drag the wave (they chase me = they lose CS =
still our win); or split the equilibrium so both sides farm apart in peace.
**Status:** PARTIAL — creeppull covers the drag; "split into two calm
sub-lanes" is emergent, not coded. Treat as creeppull's success metric, not a
separate fix.

### L1-XPSOAK — extreme disadvantage: sit at XP range, do NOT contest
**Rule:** alone vs two, can't drag, any CS attempt = CC'd + killed → **stand
OUTSIDE their stun/slow range, inside XP range (~1500), take XP, do not feed,
wait for the support to come back.** This state is not winnable solo; the
goal is purely "don't die, don't fall a level behind."
**API:** XP radius 1500; stand point = wave position pulled back toward our
tower, ≥ enemy-threat distance from every visible enemy.
**Status:** GAP — and the *corrected* version of `lf_recover` (REJECTED
culprit): lf_recover sent zoned cores to the JUNGLE (CS@8 −48%); the correct
behavior keeps them AT the lane edge soaking XP.
**Danger note:** this is the same family as the c3/corefarm/lf_recover
rejects — must be extremely narrow (exact trigger: ≥2 visible lane enemies,
no ally within ~1400, contest = provably lethal per lanesurv math).

---

## Position 5 (hard support)

### L5-NOLH — never last-hit; deny only
**Rule:** pos-5 NEVER takes a last hit; denies own creeps + harasses.
**Status:** IMPLEMENTED as `suplh` (#14, gated): deny + uncontested-only LH.
**Gap vs spec:** owner says NEVER last-hit (current code still takes
uncontested creeps when no core is near). Tighten under a sub-toggle when
validating suplh.

### L5-TREES — stand OFF the wave (in trees), harass without creep aggro
**Rule:** standing on the wave and attacking draws creep aggro and ruins the
equilibrium. Stand in the treeline BESIDE the lane; harass with attacks/spells
from the side, never pulling creep aggro (creep aggro = attack order on an
enemy hero within ~500 of their creeps).
**Target selection:** vs standard melee-3 + ranged-4: harass the 3 from the
side AWAY from their 4.
**Status:** GAP (and the EXPLANATION of the `bodyblock` −50 gpm reject: I
gave harass duty to pos-1-3 cores standing on the wave — exactly what this
rule forbids. Harass belongs to the pos-5, from off-wave angles.)
**API:** position offset perpendicular to lane direction; harass only when
>500 from enemy creeps or with spells; `IsRangedAttacker` check for the
"long-hands support" precondition.

### L5-COMBO — call the kill on a too-deep enemy 4
**Rule:** enemy pos-4 walks too deep / past our pos-1 → focus it together
with the pos-1; typical 4s are squishy, 2-man focus kills. Inverse risk: *we*
are squishier than our 1 — never jump too deep ourselves; if their 3+4 turn,
we die first.
**Status:** PARTIAL — `J.ShouldPunishOverchase`/dive punish covers *reactive*
collapse; the proactive "their 4 is standing too deep, kill window now" call
does not exist. Reuse `SafeToCommitFight` + lanesurv-style burst math against
US as the self-risk gate.

### L5-PULL — pull camps to reset a bad lane
**Rule:** if we can't win the lane or the wave is too far forward for our 1
to CS safely → pull (:12/:42). Only a pulled-back wave gives the 1 room.
**Status:** IMPLEMENTED as `pullcamp` (#13, gated, econ-neutral in first A/B).
**Note:** if the 5 leaves to pull, the 1 alone on the wave is at risk — the 1
may pull himself when solo (owner). Cross-link to L1-XPSOAK while alone.

### L5-MANA — spell/mana discipline
**Rule:** don't throw spells blindly; spend only when (a) mana is healthy AND
the poke will actually land, or (b) we/I got jumped and must counter. Low
mana = save it for the key moment.
**Status:** IMPLEMENTED as `lf_mana` (`ShouldConserveManaInLane`, gated,
fixture-validated). Matches spec.

### L5-TPDEF — TP to defend sibling lanes
**Rule:** watch the minimap; enemy dives our 3/4's tower → TP in, usually a
free counter-kill.
**Status:** PARTIAL — `midtp` (#15, gated) does this for MID only. Generalize
the same helper to pos-5 (it already checks winnability + TP availability);
new sub-id `suptp`.

---

## Cross-cutting notes
* **Role split is load-bearing:** cores farm, supports harass/pull. The
  bodyblock reject is what happens when this is violated.
* **Aggro mechanics used:** attack-order on enemy hero near their creeps =
  creep aggro on me (L1-DRAG uses it deliberately; L5-TREES avoids it).
* **All fixes ship gated per rule-ID** (`creeppull`, `pullcamp`, `suplh`,
  `lf_mana`, `lanesurv` exist; new: `l1trade`, `l1xpsoak`, `l5trees`,
  `l5combo`, `suptp`).
* Validation: fixtures from real frames per rule; batch A/B only on the
  accumulated laning bundle, mirrored draft, deaths + CS@8 + lane-equilibrium
  as metrics.

## Priority (owner-signaled)
1. **L1-SALVE link + L1-TRADE** (the trade model is the heart of laning).
2. **L1-XPSOAK** (stops the worst feeding; corrected lf_recover).
3. **L5-TREES** (harass moved to the right role, done right).
4. **L5-COMBO / suptp / L1-DRAG trigger widening** — after the above hold.
