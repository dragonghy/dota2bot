# `tpreach` — condition (a) evidence (owed_executions row `a_evidence_tpreach`, GH #159)

**Executor**: replay-check(录像组) · **Produced**: 2026-09-06T04:04Z
**Ruling this discharges**: 总监 2026-09-05T22:xxZ, `iterations/streams/test_set.md` §FB.2 下半行 / §FB.5 第 2 条.
**§BC.3 self-restraint honoured**: this reading was taken by the replay desk, not by the director.

`VERIFY id=tpreach verdict=WORKING episodes=59`

(59 = ADDED-domain presses under the calibrated p50 reach table, 21 armed + 38
baseline, over 70 game-legs. See **Verdict** for the one restriction the
director may want to apply, which would move this to INDETERMINATE.)

---

## 1. Wave, corpus, coverage

| | |
|---|---|
| Wave | **W49**, launched 2026-09-05T21:19:57Z, `--ref` pinned to `066219d61009c35357de49cfe3e8521940b09109` |
| Seeds | 5404, 5502, 5574, 5705 (4 seeds × 12 games × 2 legs) |
| Games | **72/72 scored games swept**, 24 warm-up skipped, **unparseable 0** |
| Sweeps | `sweep_run.sh` ×4 machines, `SWEEP_EXIT=0` ×4 |
| Game-legs in the census | 70 (42 radiant-armed + 30 dire-armed; two games carry no press row) |
| TP presses examined | **7,630** |
| AWS | S3 **read-only**. Zero EC2, zero new wave, zero Cost Explorer. |

**Reachability**: `tpreach` is armed in the tested tree. Verified against the
pinned tree itself, not against prose — `git show 066219d6:iterations/streams/test_set.md`
line 2, position 28 of 61 ids. Its arm string md5 matches `W49_wave.json.arm_md5`
(`824ec2842e234693cb3c4094f73d6a14`).

## 2. What was measured, and why this is the right quantity

`tpreach` widens `J.CanEnemyInterruptTpChannel`'s scan from 700 u to 1200 u and
holds the enemies the widening ADDS to the STRIKE clause only
(`bots/FunLib/jmz_func.lua:6731-6752`). It is a **pure one-sided veto**: armed,
the predicate refuses a strict superset of the frames it refuses unarmed. So
its (a) signature is *fewer presses inside its own added domain, and nothing
else* — a direction, fixed in advance by the source, not a hypothesis fitted
after the fact.

The domain is `tpreach`'s own:

```
ADDED = { press : no enemy fires the old predicate inside 700,
                  and some enemy sits at 700 < d <= reach(enemy) }
```

Tool: `tools/batch_test/behavioral/tpreach_domain.py` (already on trunk; not
written this round). Its `--selfcheck` was run first: **42 PASS / 0 FAIL,
exit 0**, including three source pins that fail the day the lever moves.

`GetAttackRange()` is not in the behavioural dump, so `reach` is estimated from
the distance at which each hero's auto-attacks land. **All three reach tables
the tool offers were run**, because a conclusion that survives only one table
is a conclusion about the table.

## 3. Iron rule 4(i-a): both strata, always

Per-physical-side readings, reach-mode **p50** (the tool's calibrated default):

| stratum | leg | games | presses | ADDED | ADDED:field | ADDED:home |
|---|---|---|---|---|---|---|
| radiant | armed | 42 | 2146 | 8 | 1 | 4 |
| radiant | baseline | 42 | 2377 | 27 | 9 | 9 |
| dire | armed | 30 | 1588 | 13 | 2 | 7 |
| dire | baseline | 30 | 1519 | 11 | 4 | 4 |

⚠️ **On this per-side table the two strata disagree in sign** on ADDED/game
(radiant −0.452, dire +0.067). Registered here as 4(i-a) requires.

**It is not read as noise, and the reason is 4(i-c), not preference.** The
per-side count is the side-bias-uncontaminated estimator only if you stop
there. Each seed carries both an ab and a ba game set, so
`arm = (ab + ba)/2` is a 50/50 swap-average and the side bias is gone from it;
`ab·ba < 0` is then the identity `|side| > |arm|`, a statement about this
draw's side bias and not about how well `arm` is measured. What measures `arm`
is its dispersion **across seeds**:

## 4. Per-seed swap-average (4(i-c)), all three reach tables

Arithmetic mean across seeds — **never weighted by games or presses** (4(i-d)).

| reach table | ADDED/game mean arm | seeds down | n armed / baseline |
|---|---|---|---|
| **p50** (calibrated default) | **−0.2135** | **4/4** | 21 / 38 |
| p90 (known to overshoot +198..+376 u) | −0.2375 | 4/4 | 108 / 122 |
| source (base ranges named in the source comment) | −0.1167 | 4/4 | 19 / 24 |

**4/4 seeds down under every reach table.** The direction is the one the source
fixes in advance.

### 4.1 Volume control — the reading is not a by-product of pressing fewer TPs

The armed leg is a 61-id bundle, and its total TP volume moves on its own
(swap-averaged, ≈ −1.6 presses/game against ~52/game, ≈ 3%). If ADDED simply
tracked volume, the whole reading would be an artifact. It does not: ADDED as a
**share of all presses** is down too.

| reach table | ADDED share of presses, mean arm | seeds down | armed share | baseline share |
|---|---|---|---|---|
| p50 | −0.00387 | 4/4 | **0.5624 %** | **0.9754 %** |
| p90 | −0.00457 | 3/4 | 2.8923 % | 3.1314 % |
| source | −0.00238 | 4/4 | 0.5088 % | 0.6160 % |

A ~3 % drop in TP volume against a ~42 % drop in the ADDED share (p50): the
suppression is specific to the band, not general.

## 5. §BC.4's own cell: the non-retreat read, and its limit

§BC.4 asks specifically for the **non-retreat** cell — the armed leg should not
press, the baseline leg should — because `tpsafe2`, the wrapper that consults
this predicate, is scoped to `nMode ~= BOT_MODE_RETREAT` and never runs on a
retreat TP. §BC.1 further forbids putting a threshold on the retreat cell at
all (a retreat TP is the deliberate last-resort escape GH #3 paid −15 GPM to
learn not to suppress). The dump has no mode field; `dest` (landed at own
fountain vs out in the field) is the proxy.

**The mechanistic signature is there, and it is exactly the right shape** —
under p50, the suppression is concentrated in the cell where the guard actually
runs, and the retreat cell is nearly untouched:

| stratum | leg | ADDED:field | ADDED:home | field share |
|---|---|---|---|---|
| radiant | armed | 1 | 4 | **20 %** |
| radiant | baseline | 9 | 9 | **50 %** |
| dire | armed | 2 | 7 | **22 %** |
| dire | baseline | 4 | 4 | **50 %** |

Both strata: baseline splits exactly 50/50, armed collapses to ~20 %. The
widening bites where `tpsafe2` runs and not where it cannot. This is a
within-leg composition ratio, so it is far less side-exposed than a raw count,
and **it reproduces in both strata independently**.

⛔ **Two limits, stated rather than smoothed over:**

1. **n is small.** ADDED:field is 3 armed vs 13 baseline across 70 game-legs.
   Swap-averaged per seed it is −0.1312 with only **2/4 seeds** down — one seed
   (5404) contributes literally zero ADDED:field events on all four legs.
2. **The composition signature is p50-only.** Under p90 it vanishes
   (armed 37 % vs baseline 38 %) and under `source` it inverts on a handful of
   events (n=1 in one cell). p50 is the tool's *calibrated* table — measured
   error −3..+85 u against the four source-cited ground-truth heroes, against
   p90's +198..+376 u — so p90's dilution is the expected behaviour of an
   inflated band rather than a contradiction. But the letter of "survives every
   table" is met by §4 (the ADDED aggregate) and **not** by this cell.

## 6. Attribution (charter 4a) — what this reading can and cannot be charged to

The armed leg carries **61 ids**, not one. Other armed ids touch TP presses
(`tpgap`, `tpcommit`, `tpdead`, `teambrain`, `midtp`, `lf_rescue`,
`tpdeathbuy`), so the raw press population is a bundle differential and charter
4a forbids booking a bundle differential to a single id.

What makes this reading nonetheless chargeable to `tpreach`, and the argument
stated so it can be attacked:

* **ADDED is `tpreach`'s own domain**, computed from its own source clause
  (`700 < d <= reach(enemy)`, strike-clause only). No other armed id has that
  band as its domain.
* **The volume control (§4.1) separates it from any general press suppression**:
  the bundle moves total presses ~3 %, the ADDED share ~42 %.
* **The composition split (§5) is mechanism-specific**: the suppression lands in
  the non-retreat cell where `tpsafe2` runs and not in the retreat cell where it
  structurally cannot. A general "press less" id could not produce that split.

The one overlap that is *not* excluded: **`tpgap`** also acts on presses with a
nearby enemy, on the retreat branch. It could in principle move the retreat
cell. It cannot produce the field-cell collapse, which is where the reading
lives.

## 7. Verdict

`VERIFY id=tpreach verdict=WORKING episodes=59`

**WORKING**: the candidate suppresses presses inside its own added band, 4/4
seeds, under all three reach tables, after volume control, with the suppression
concentrated in the non-retreat cell where its caller actually runs. No
BUGGY-shaped evidence appeared: nothing indicates it refuses presses outside
ADDED, and the retreat cell — the one §BC.1 protects — is essentially unmoved
(13 → 11).

**The one restriction that would change this to INDETERMINATE**: if §BC.4 is
read to the letter — the acceptance must be carried by the *non-retreat cell
alone* — then n = 3 vs 13 at 2/4 seeds is under-powered, and the honest answer
is INDETERMINATE pending more seeds. The distinction is the director's to make,
which is why both readings are given above rather than one merged number.

**This is condition (a) only.** (b) and (c) are not addressed here, and
`tpreach` is currently **out of the set** (退集 2026-09-05, 60 → 59). Per §FB
the retraction was not a reject and did not destroy the ability to buy (a);
this file is that purchase. Re-admission remains the director's call.

## 8. Reproduction

```bash
bash tools/batch_test/aws/session_setup.sh                     # S3 read-only
for R in <the four W49 run_ids from iterations/reports/batch-desk/waves/W49_wave.json>; do
  bash tools/batch_test/behavioral/sweep_run.sh \
    s3://dota2bot-batch-results-4924/soak/$R/ <out>/$R
done
python3 tools/batch_test/behavioral/tpreach_domain.py --selfcheck        # 42 PASS / 0 FAIL
python3 tools/batch_test/behavioral/tpreach_domain.py --reach-mode p50 \
        --out rows.jsonl <out>/*/
python3 tools/batch_test/behavioral/tpreach_domain.py --reach-mode p90 <out>/*/
python3 tools/batch_test/behavioral/tpreach_domain.py --reach-mode source <out>/*/
```

⚠️ The per-seed swap-average of §4 and §4.1 was computed from `rows.jsonl` in
this round, **not printed by the tool**. That is the shape 4(i-d) warns about
(six rounds satisfied the disclosure rule with the wrong hand-computed
quantity). Registered as a debt: `tpreach_domain.py` should print its own
per-seed swap-average table, the way `tpdying_release.py --by-seed` now does.
