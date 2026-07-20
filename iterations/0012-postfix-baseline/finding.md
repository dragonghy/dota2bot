# Iteration 0012 — Post-fix behavioral baseline + the sharpening tension

**8 fresh games, all 6 shipped fixes live** (detect.py over batch_postfix):

| detector | post-fix /game | pre-fix /game (rollup) | change |
|---|---|---|---|
| idle_while_ally_dies | 3.1 | ~7 | **−55%** (#5 working) |
| sandwiched_walk | 10.9 | ~11 | **~0** (#4 sharpened too far) |
| overextend_alone | 7.9 | — | high |
| unpunished_tower_dive | 5.6 | — | high |
| tp_home_wasteful | 4.6 | — | (#2 targets this; still present) |
| tp_under_threat | 3.6 | — | (#3 rarely fires by design) |
| skywrath_solo_silence | 0.4 | ~0.4 | flat |

## The strategic tension (important)
Under the OLD econ-A/B regime I **sharpened #4** (anti-dive) until it was a clean
multi-seed win — but that narrowed it to "near-certain feed only", so it now
**barely reduces sandwiched_walk (10.9 ≈ 11 unchanged)**. #5 (idle), shipped
under the new Class-B policy without econ-sharpening, cut its target behavior 55%.

**Lesson:** optimizing a locally-correct micro-behavior fix for econ-A/B-cleanliness
can gut its behavioral value. Under Class-B (runbook §1) the yardstick is the
detector drop, not econ neutrality. #4 should be RE-BROADENED and re-measured by
sandwiched_walk reduction + kill-participation (does broadening make bots flee
winnable fights?), NOT by econ. Filed as follow-up.

## Still-rich problem space (all remain high with fixes live)
sandwiched_walk 10.9, overextend_alone 7.9, unpunished_tower_dive 5.6,
tp_home_wasteful 4.6 — plenty of real behavior to fix. Next waves target these.
