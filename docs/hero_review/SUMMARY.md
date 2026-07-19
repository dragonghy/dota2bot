# Focus Hero Review — Cross-Hero Summary & Execution Plan

Five parallel deep reviews of the first-batch focus heroes (2026-07-19).
Per-hero backlogs: [axe.md](axe.md) · [zeus.md](zeus.md) · [wraith_king.md](wraith_king.md) · [lion.md](lion.md) · [crystal_maiden.md](crystal_maiden.md)

## Headline P0s (clear bugs / biggest win-rate levers)

| Hero | Finding | Effect in game |
|---|---|---|
| Axe | `ConsiderR` reads the **wrong talent index** for the Culling Blade threshold (`sTalentList[5]` = untrained t20 HP-regen instead of the t25 execute-threshold talent) | Lvl-25 Axe under-estimates execute range; holds ult on killable targets |
| Crystal Maiden | **Freezing Field has no safety gate** — channels on enemy count alone, no ally/BKB/Glimmer/won-fight check | Fragile pos-5 channels solo into burst and dies for free |
| Wraith King | **Reincarnation-aware aggression is half-built** — only a teamfight retreat-suppression exists; no extra caution when R is down, no boldness when R is up | Misses the hero's core decision loop entirely |
| Lion | **Finger of Death targets the first killable enemy in list order**, not the highest-value one | Signature ult wasted on low-value targets |
| Lion | **Aether Lens is never bought** although `SkillsComplement` consumes its +250 range | Entire cast-range code path is dead; Lion casts at min range |

## Recurring cross-hero patterns

1. ~~Buy-list / sell-list conflicts~~ **CORRECTED — false positive.** `sSellList` uses PAIRED semantics (`SetPairedItems`, item_purchase_generic.lua:1264): entries are `{newItem, oldItem}` pairs meaning "once you own newItem, sell oldItem". Zeus/WK's `{BKB, quelling_blade}` sells the quelling blade, not the BKB. No fix needed (though WK never buying BKB made its pair dead — fixed by adding BKB to WK's builds).
2. **Aether Lens dead code**: Lion and Zeus both implement Aether cast-range handling but never buy the item.
3. **Missing BKB**: Axe pos-3 (primary role) and WK pos-1/pos-3 builds ship no BKB at all.
4. **Value-blind target selection**: Lion Hex ranks threats by *physical* damage only (fed magic nukers never hexed); Zeus Lightning Bolt has no kill-secure branch; Lion Finger takes list order. Same fix shape: rank candidates by value/lethality.
5. **Talent tables need re-verification** against current patch data (several positional index mismatches suspected — Axe's is a confirmed bug).
6. **Ult damage models drift from reality**: Zeus credits Static Field damage to global targets it can't reach; Axe hardcodes the Culling threshold instead of reading ability special values.

## Execution plan (each wave: luacheck + tests → batch A/B → merge)

**Wave 1 — mechanical bug fixes (high confidence, start immediately):**
- Axe Culling talent index fix
- BKB buy/sell conflicts (Zeus, WK)
- Add Aether Lens to Lion pos-4/5 and Zeus builds
- Add BKB to Axe pos-3, WK pos-1/pos-3

**Wave 2 — signature-decision logic (the real win-rate levers):**
- CM: Freezing Field safety gate (+ Blink/BKB setup)
- WK: Reincarnation-aware aggression/caution switch
- Lion: Finger value-ranked targeting; Hex threat model incl. magic damage
- Zeus: ult lethality model (Static Field range) + teamfight-finisher branch; Bolt kill-secure

**Wave 3 — talent verification & remaining P1/P2** (needs Liquipedia/patch-data pass).

Validation: every wave goes through the same-match A/B harness (`tools/batch_test/make_ab_build.py`) once the AWS account is unblocked; per-hero metrics listed in each backlog file.
