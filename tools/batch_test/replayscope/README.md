# ReplayScope

A vision-aware replay review tool. Turn any dumped Dota bot replay into a
**self-contained web page**: a square minimap with hero portraits, a scrubbable
timeline, a global / radiant / dire **vision toggle** (so you see what a bot
actually saw), and a per-tick state table — plus a one-click **Lua test-fixture
export** that captures the world at the current instant for unit tests.

It is a *reusable template*, not a hand-made page per replay. One template
(`template.html`) + one transform (`build.py`). Point it at a replay's timeline
and it emits a page; a different replay in gives a different page out.

## Pipeline

```
replay.dem  --(behav-dump, Go/manta)-->  timeline.json  --(build.py)-->  page.html
```

1. **Dump** the replay to a timeline JSON (the eyes toolchain's `dumper`):

   ```
   dumper -in replay.dem -out game.timeline.json
   ```

   For ReplayScope, dump creeps every second so the map updates smoothly:

   ```
   dumper -creep-interval 1.0 -in replay.dem -out game.timeline.json
   ```

2. **Build** the page (data + hero/item icons inlined; the page needs no network):

   ```
   python3 tools/batch_test/replayscope/build.py game.timeline.json -o game.html
   ```

   Open `game.html` in any browser, or publish it as an artifact for review.

## What the page shows

- **Map (kept square)** — river midline, ancients, towers (greyed when dead),
  creeps as small team-colored dots, and each hero as its **minimap portrait**
  ringed in team color. Dead heroes are dimmed with an ✕. No HP is drawn on the
  map (it's in the table). Under a team perspective, enemies you can't see are
  hidden or shown as a faded "last-seen @ m:ss" ghost.
- **Vision toggle** — `global` (omniscient ground truth), `radiant`, `dire`.
  This is the point of the tool: the bot decides on its own team's vision, so to
  judge a decision you view the world from that team's fog.
- **State table** — hero (portrait + name), level, **HP/MP as `cur/max`**,
  **TP** status, **items** (9 slots: 6 inventory | 3 backpack, split by a
  divider), and **status** (crowd-control). No coordinates (they're on the map),
  no raw visibility column (the map toggle shows it). Fogged enemies are dimmed
  and read from their last-seen snapshot.
- **Crowd-control** — stun/slow/root/silence/hex/etc. are reconstructed from
  modifier events with a live countdown (e.g. `Stun 1.2s`), shown in the table
  and as a colored ring on the map.
- **TP cooldown, perspective-aware** — each hero's Town Portal cooldown, shown
  on the map (green = ready, amber + seconds = on cooldown, grey `?` = unknown)
  and in the table. Under a team perspective you only KNOW an enemy's TP is down
  if you witnessed the cast (they were in your vision when it fired) — exactly
  the bot's information model. Own team is always known.
- **Pre-game** — the timeline starts at ~-90s. The replay doesn't record hero
  movement before the horn (bots stand idle at their staging spots), so pre-0 is
  static by nature and labeled `PRE-GAME`; the informative review starts at 0:00.
- **Lua fixture export** — pick a hero, hit export: emits a `return { time=,
  perspective_team=, self=, units={...} }` table describing exactly the units
  that hero could see at this tick. Feed it to `tests/mock` to reproduce a real
  game state as a unit test.

## Data it uses (and what "lights up" with a richer dump)

`build.py` reads the behav-dump timeline schema. A **position-only** dump (v1)
renders fully — movement, HP/MP/level, deaths (a dead hero reports `hp_pct==0`).
These fields are optional and turn on more of the UI when an **extended** dump
provides them, with no template change:

| field (per snapshot / stream) | lights up |
|---|---|
| `items` | item chips under each hero on the map |
| `vis` (teams that see the unit) | real fog instead of the 1600-radius approximation |
| `buildings` stream | towers with real death times |
| `creeps` stream | creep dots / lane pressure |

Until an extended dump provides `vis`, vision is **approximated** (an enemy is
"seen" if within 1600 of any live ally) and the header says so. Manta does not
network a per-team visibility bitmask, so exact fog must be reconstructed from
vision sources — see `docs/ANALYSIS_PANEL.md`.

## Frame-corpus retrieval (`corpus_query.py`)

`make_fixture.py` freezes ONE instant a human picked out of ONE replay. That
answers "is this decision correct here". It cannot answer the question a
promotion turns on — **on how many of the frames where this rule applies does
it fire?** — because that needs a population, and a population needs a
denominator somebody computed.

`corpus_query.py` sweeps a corpus of timelines, evaluates a declarative
predicate on every (hero, snapshot) frame, reports matched-over-examined with
every excluded frame accounted for by name, and then feeds the survivors to
`make_fixture.py` in bulk.

```bash
# how often is a support low, alone, and past the midline with an enemy on it?
python3 corpus_query.py .sweep_out/<run>/timelines/*.json \
    --name lowhp_deep --dedup 15 \
    --query '{"all":[{"term":"hp_pct","lt":0.35},
                     {"term":"depth","gt":0},
                     {"term":"enemies_within","args":[1200],"ge":1},
                     {"term":"allies_within","args":[1500],"eq":0}]}' \
    --jsonl hits.jsonl \
    --fixtures ../../../tests/fixtures --tag lowdeep \
    --analysis-dir .sweep_out/<run>/analysis
python3 corpus_query.py --list-terms   # the vocabulary
```

Reading the output:

- `CORPUS … frames_total=N postgame=… out_of_window=… paused=… dead=… examined=…`
  — these balance exactly (`frames_total` is the corpus files' own snapshot
  count) and the tool **aborts** if they don't. `postgame` is the GH #43 frozen
  tail that `detect.Timeline` drops upstream; it is counted here rather than
  left silent because a denominator that starts a third below the file's row
  count is the same defect as an unnamed cap.
- `CLAUSE true=k/r reached …` — per-leaf, against the frames that clause was
  actually **offered** (`all` short-circuits), never against the global
  `examined`. `VACUOUS` means the clause selects nothing (typo'd item, an
  ability the corpus never leveled, a threshold on the wrong side); `INERT`
  means it narrows nothing. Both are invisible in a plain hit count.
- `POPULATION matched=… deduped=…` — `matched` is raw frames, `deduped` is
  hits after collapsing each hero's 1Hz run to one per `--dedup` seconds.
  Quote `deduped` as the population; a 20-second condition is one situation,
  not twenty independent frames.

It selects by **world state only** and has no opinion about what the bot did
there. "The rule applies here" is this tool's output; "the rule fired here" is
the fixture test's. Keeping those on opposite sides of the fixture boundary is
the point — a selector that already knew the answer would be measuring itself.

Malformed predicates (unknown term or operator, wrong arity, stray keys) and a
missing corpus file are hard errors, never a quiet zero. Tests:
`tests/test_corpus_query.py`.

## Files

- `corpus_query.py` — frame-corpus retrieval + batch fixture front-end (above).
- `make_fixture.py` — one timeline instant → a real-frame Lua fixture.
- `template.html` — the renderer. Reads `window.__REPLAY__` + `window.__ICONS__`
  (injected at the `/*__REPLAYSCOPE_INJECT__*/` marker). Renders standalone with
  a tiny synthetic sample if opened directly.
- `build.py` — timeline.json → standalone page. Inlines hero minimap icons
  (cached in `icons/`, fetched + cached on a miss).
- `icons/` — committed hero minimap icons (data source for the inlined portraits).
