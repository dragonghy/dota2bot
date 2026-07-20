# Behavioral replay analysis — giving the bots "eyes"

Dev-only tooling (never shipped to the Workshop). It turns a farm game's `.dem`
replay into a per-hero behavioral timeline and automatically flags the concrete
logic bugs the owner spots by hand — TP-under-threat, wasteful TP-home, solo
silence, walking into a flank, idling while an ally dies. This is the automated
substitute for watching replays, complementing the economy-only signal in
`soak/analyze_log.py` (which can measure GPM/XPM but cannot see a discrete
decision).

The bug classes come from `iterations/0009-laning-bugs/bug_queue.md`.

## Why the .dem replay (not console logs)

Two data sources were investigated on the actual farm instance:

- **Verbose console log via cvars** — rejected. Bot-script `print()` never
  reaches the dedicated-server console in this `-dedicated -nogc` environment
  (already confirmed by the soak work; it's why `referee.py` reconstructs the
  clock from `Building: ... destroyed` lines). The console stream carries a
  scoreboard and building/death lines but **no per-tick positions, HP, or
  order/target stream** — it cannot see the decisions we care about.

- **Parse the Source 2 `.dem` replay** — works, and is what this pipeline uses.
  The replay is the ground-truth entity + combat-log stream the game recorded:
  per-tick hero positions, HP/mana, levels, every ability cast, item use, death,
  damage instance, and modifier (buff/debuff) add/remove — all with exact game
  timestamps. A 10 MB / ~12-min replay parses in **~0.4 s**.

Parser choice: **Go + [dotabuff/manta](https://github.com/dotabuff/manta)**
(v1.5.0). Chosen over Java "clarity" only because a single static Go binary is
trivial to build and run on the Ubuntu farm box with no JVM. Clarity would work
equally well as the underlying parser.

### The one manta patch (important)

Dedicated-server replays report a **bare game directory** (`.../game/dota`) in
`CSVCMsg_ServerInfo`, with no `/dota_vNNNN/` build tag. Stock manta treats that
as fatal (`unable to determine game build`). Worse, if you naively default the
build to `0`, manta's legacy field patches (`field_patch.go`, ranges `<=990`
and `<=954`) **wrongly apply** and corrupt position/mana decoding.

`setup_instance.sh` vendors manta and changes exactly one thing: when the build
tag is absent, default `GameBuild = 9999` — above every legacy patch's upper
bound, so a modern replay decodes correctly. That is the only modification.

## Pipeline

```
 .dem  ──(Go: dumper/main.go, "behav-dump")──▶  timeline.json
                                                    │
                                                    ▼
 timeline.json ──(Python: detect.py)──▶  findings.json  +  human-readable print
```

**`timeline.json`** (one object):

- `game.start_time` — server time of the horn; every `t` below is game-clock
  seconds (0 = horn), matching the clock the owner reads off the replay.
- `game.teams` — `{ npc_name: 2|3 }` (2 = Radiant, 3 = Dire).
- `snapshots[]` — sampled every 1.0 game-second (tunable `-interval`):
  `{t, hero, team, x, y, hp, hp_pct, mp_pct, level}`.
- `events[]` — every combat-log entry touching a hero:
  `{t, type, actor, target, inflictor, value, actor_hero, target_hero}`
  (types: ABILITY, ITEM, DAMAGE, HEAL, DEATH, MODIFIER_ADD/REMOVE, GOLD, XP,
  PURCHASE, …). TP channels appear as `MODIFIER_ADD`/`REMOVE` of
  `modifier_teleporting` — matching an ADD to its REMOVE gives the channel
  duration, so an interrupted (wasted) TP is directly observable.

Hero identity: derived from the entity class name (`CDOTA_Unit_Hero_Skywrath_Mage`
→ `npc_dota_hero_skywrath_mage`) via camelCase/underscore → snake_case, which
matches the names the combat log uses, so snapshots and events cross-reference.

## Detectors (`detect.py`)

Each is a pure function over the timeline; `[X]` is the `bug_queue.md` class.

| id | bug | fires when |
|----|-----|-----------|
| `tp_under_threat`      | A | a hero starts a TP channel with an enemy hero within 700u (reports channel duration; `interrupted` = channel < 2.9s = TP wasted/killed) |
| `tp_home_wasteful`     | A | a **living**, low-HP (<55%) hero TPs with no enemy within 1400u — should regen in lane, not TP home |
| `skywrath_solo_silence`| G | Ancient Seal cast with no Arcane Bolt / Concussive / Mystic Flare and no damage to the target within 4s |
| `idle_while_ally_dies` | F | an ally within 1500u of a dying hero cast/attacked nothing in the fight window (no teamfight participation) |
| `sandwiched_walk`      | F | a hero took damage from ≥2 distinct enemy heroes within 4s while flanked (enemies on opposite sides within 750u) |

Thresholds are constants at the top of `detect.py`. Detectors deliberately run
generous and report exact distances/HP/timestamps so a human can confirm; tune
radii to trade recall for precision.

## Visual "eyes": storyboards + report cards

Two additional tools consume the same `timeline.json` and give a
non-video-capable analysis agent a visual + quantitative read on a game
(the agent can view PNGs, not `.dem` replays):

```bash
# fight storyboards: auto-detects team-fight windows (>=3 hero-vs-hero DAMAGE
# events clustered within 15s / 2500u) and renders each as 4-8 top-down map
# frames (positions, HP%, movement trails, deaths as X, river + ancients)
python3 storyboard.py timeline.json --out-dir sb/
#   -> sb/fight_<N>_frame_<K>.png + sb/fights.json (participants, deaths,
#      damage per side)

# per-hero report card: fight participation %, "spectator" fights (present but
# zero damage events), death contexts (solo_overextend / outnumbered_fight /
# even_fight / unknown), positioning (distance to team centroid, % time in
# enemy half), activity (damage events/min, longest idle-in-fight gap)
python3 report_card.py timeline.json --out-dir rc/
#   -> rc/report_<hero>.md + rc/report_all.json + rc/SUMMARY.md
#      (heroes ranked by concern = spectator fights + solo-overextend deaths)
```

`storyboard.py` needs matplotlib; `report_card.py` is stdlib-only (it imports
fight detection from `storyboard.py`, which loads matplotlib lazily). Smoke
test: `python3 tests/test_storyboard_smoke.py` (runs both end-to-end on
`tests/fixtures/timeline_synthetic.json`).

## Results on the reference game (`auto-20260719-1418`)

This is the exact replay the owner reviewed by hand for `bug_queue.md`
(Radiant viper/skywrath/centaur/sniper/warlock vs Dire axe/jakiro/necrolyte/
witch_doctor/zuus). The detectors independently reproduce his findings:

- **`npc_dota_hero_axe` channeled TP at t=220s (3:39) with skywrath 502u away,
  hp=29% → TP-under-threat** — the owner's "原地 TP bug: Axe (3:42) channeled TP
  in-place with enemies on their face".
- **`npc_dota_hero_witch_doctor` caught between centaur + skywrath at t=100s
  (1:40)** — the owner's "迷之走位: Witch Doctor at 1:39 walked between two
  enemies and took free harass".
- **`npc_dota_hero_skywrath_mage` TP'd at 5:39, hp=26%, no enemy near → wasteful
  TP-home** — the owner's "Skywrath (5:40) TP'd home to refill while NOT being
  chased".
- **Skywrath cast Ancient Seal at 7:33 and 10:35 with no follow-up burst** —
  the owner's bug G "Skywrath: cast Silence alone then nothing".
- **`npc_dota_hero_axe` TP at 10:29 INTERRUPTED after 2.8s with centaur 93u away**
  — a wasted TP caught red-handed.

21 findings total on this one game; a `rollup.json` aggregates by detector and
by (detector, hero) — e.g. `tp_under_threat|npc_dota_hero_axe: 3`.

## How to run

Everything runs on the soak instance (`i-08b59ef7130025860`) over SSM; nothing
new is launched (parsing is compute-cheap and shares the running box).

```bash
# 0. AWS creds in this session
bash tools/batch_test/aws/bootstrap_creds.sh

# 1. one-time: install Go + build behav-dump on the instance (idempotent)
awsx ssm send-command --instance-ids i-08b59ef7130025860 \
  --document-name AWS-RunShellScript \
  --parameters commands='bash /opt/dota2bot/tools/batch_test/behavioral/setup_instance.sh'

# 2a. analyze one replay (local path or s3://...)
#   -> writes <out>/<name>.timeline.json + .findings.json and prints findings
bash /opt/dota2bot/tools/batch_test/behavioral/run_replay.sh \
  s3://dota2bot-batch-results-4924/replays/auto-20260719-1418-dota-Dota_2.dem

# 2b. analyze EVERY replay under an S3 prefix; upload per-game findings + rollup
bash /opt/dota2bot/tools/batch_test/behavioral/batch_s3.sh
#   src default: s3://dota2bot-batch-results-4924/replays/
#   dst default: s3://dota2bot-batch-results-4924/behavioral/
```

Locally you can run just the detector against a downloaded timeline:
`python3 detect.py timeline.json --json findings.json`.

## Running it across ALL farm games (integration TODO)

The pipeline is proven end-to-end on a real game. The one missing piece is that
**the soak farm does not currently record replays** — the reference `.dem` was
recorded manually by the owner; soak slots launch without replay recording and
the `replays/` dir is otherwise empty. To make this automatic:

1. **Record replays per slot.** Add GOTV/replay recording to the soak launch in
   `soak/soak_loop.sh` (e.g. `+tv_enable 1 +tv_autorecord 1`); each game then
   drops an `auto-*.dem` in `game/dota/replays/`. (Recording adds negligible CPU
   and ~10 MB/game disk.)
2. **Process on game end.** In `soak_loop.sh`, after `analyze_log.py`, call
   `run_replay.sh` on the freshly written `.dem` and upload the
   `*.findings.json` next to the existing `*.analysis.json` (same S3 prefix),
   then delete the local `.dem` to bound disk. Parsing (~0.4 s) is dwarfed by a
   game, so it adds no meaningful wall time.
3. **Fleet roll-up.** `batch_s3.sh` already produces `rollup.json`
   (counts by detector and by hero); point a periodic job at the results prefix
   to track which bug classes fire most for which focus heroes, and to A/B the
   *behavioral* bug rate before/after a hero-logic change — the discrete-bug
   analogue of the economy A/B in `report.py`.

No expensive infrastructure is required: it all runs on the existing soak
instance.
