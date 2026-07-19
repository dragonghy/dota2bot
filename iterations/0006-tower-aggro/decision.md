# Iteration 0006 — Decision (owner-specified tower-aggro fix)

## Context

iter-0005 (push-first doctrine) live data: T1s 11-16 min, T2s 25-31,
first rax still ~36.5 min — desire is maxed, EXECUTION is the
bottleneck. Prime suspect (open issue push_think:tower_yoyo): the
PushThink retreat rule stepped back on every tower hit whenever >2
allied creeps were near — exactly when tanking is safest — so bots
yo-yoed and building DPS cratered.

## Change (commit 928f2c1, aba_push.lua + TS; deployed with 4c723d1's
5-min early game as farm tag iter-0006)

Owner specified the human mechanic to copy:
- Real danger (5s incoming > 20% HP) or no creeps to soak -> step out of
  tower range (unchanged).
- Wave present + affordable damage -> HOLD the siege; if the tower locks
  onto the bot, attack-command a deniable allied creep (<50% HP — deny
  orders are always legal, unlike attacking healthy allies which the
  engine may reject) to transfer tower aggro, then resume hitting.

## Expected metric movement (iter-0006 cohort)

- Hero building damage/min up substantially (was ~355-424 radiant).
- T1->rax gap compresses; first rax toward <30 min; more organic
  (pre-forfeit) finishes.
- Watch: deny-order rejections in logs (would show as invalid-order
  spam), tower-dive deaths.
