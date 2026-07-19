# Iteration 0004 — Analysis

Owner-driven, same session as 0001–0003. Trigger: the first finished
iter-0002 game (slot4, `iter-0002-dirty`) confirmed the owner's live
suspicion that the iter-0002 closing fixes were **not enough**:

- Duration **53.0 game-min** (wall 1381 s, timescale 2.3×), still
  `slow_close`.
- Radiant building damage 18,811 (~355/min) — no better than the
  pre-fix ~424/min average. Dire 2,863.
- Tower timeline: outer towers DID fall faster than before (Dire's three
  T1s down by 10.3/14.6/15.2 min — pre-fix cohort was 15–25 min), so the
  early-push behavior improved; but 15→38 min (T2/T3/high ground) was
  still molasses: first rax only at **38.4 min**, throne at 53.
- Sniper fix verified: `GetCurrentCharges` warnings **0** (was ~2,378
  per game).

Conclusion: iter-0002 fixed the early game but the mid/late siege phase
needs stronger desire arithmetic — exactly what the owner predicted
("push desire is still not high enough").
