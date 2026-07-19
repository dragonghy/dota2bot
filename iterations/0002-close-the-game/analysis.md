# Iteration 0002 — Analysis (deep log forensics)

Same-day follow-up to iter-0001, driven by the owner's direction: read the
actual console logs from both teams and find out (a) why turbo games run
38–67 minutes and (b) why Dire never wins beyond the rigged draft. 8 more
pre-fix games ingested (26 total in the ledger; the post-iter-0001 cohort in
`soak/run_20260719_0630` had not finished games yet during this session).

## Building-damage forensics (26 games, all pre-draft-fix)

From the `Match signout` scoreboards + `Building:` destruction timelines:

| Metric | Value |
|---|---|
| Avg duration | 51 min (turbo; expect ~20–25) |
| First enemy rax falls | 35–40 min typical |
| Rax → throne gap | median ~10 min, max 27.6 min |
| Radiant hero building dmg | ~424/min (~20k/game — anemic) |
| **Dire hero building dmg** | **~16/min; several games 0–33 TOTAL** |

Conclusion: **heroes barely attack buildings at all** — towers die to creep
waves. The winning team wins by attrition, not by pushing; the losing team
literally never touches a structure. The 67.5-min game (slot5) even shows
Dire cracking Radiant's mid T3 (via creeps) at 53 min while Radiant needed
~12 more minutes to finish — a pure seesaw of unattended creep waves.

## Why: push desire arithmetic (bots/FunLib/aba_push.lua)

- Push desire is hard-capped at **0.82** while farm desire routinely returns
  **0.9** (`BOT_MODE_DESIRE_VERYHIGH`) for healthy cores → a fat core
  *always* farms instead of closing.
- Lane front near enemy fountain (<5000 — i.e. any high-ground siege) capped
  desire to **0.08** unless 3 allies stood within 1600 of the bot — bots
  straggle, so sieges effectively never happened.
- Any enemy within 900 while we have parity/numbers capped desire to 0.3 —
  the siege stopped the moment a defender showed up.
- One enemy hero near our ancient dropped the whole team's push desire to
  ExtraLow — a single rat pinned 5 heroes, even 30k gold ahead.
- Any teammate below level 6 zeroed team push desire (harmless mid-game,
  a landmine if a bot ever stays low level).

## Secondary findings

- **`IsModeTurbo()` guessed the mode from courier speed == 1100.** If a patch
  shifts courier speed, every turbo adaptation (8/18-min phase boundaries
  etc.) silently turns off. `GetGameMode()`/`GAMEMODE_TURBO` is authoritative
  and documented — now used. (Owner's hypothesis: code assuming normal-mode
  pacing. The phase functions themselves do adapt to turbo, but only if this
  detection works.)
- **Sniper's Shrapnel farm branch never fired**: `GetCurrentCharges()` is
  item-only; the engine rejected it with ~2,378 console warnings per game.
- `PushThink` has a tower-aggro yo-yo: with a creep wave present, one tower
  hit within 2 s triggers a retreat step-back, then re-approach — likely a
  large chunk of the missing hero building DPS. **Not changed yet** (micro
  change, wants in-game observation first) — backlog `push_think:tower_yoyo`.
- "Script Runtime Error: error in error handling" counts vary (11–20/game),
  no consistent preceding line; bot-VM `print()` never reaches the dedicated
  server console, so in-game markers are invisible — unmasking needs an
  error-channel emit or on-instance probe. Backlog `vscript_errors:masked`.
- ~74 engine rejections/game of orders on dead units ("invalid order (19/20)")
  — sloppy target validation, low priority.
- Dire-vs-Radiant: no dire-specific hardcode found in the push/mode layer;
  the 0-building-damage asymmetry is expected to be the rigged draft
  (perpetually-losing teams sit in defend). Post-draft-fix cohort will
  discriminate: if the loser still does ~0 building damage, there's a
  deeper defend-lock to find.
