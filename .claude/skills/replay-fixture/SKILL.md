---
name: replay-fixture
description: Freeze one Dota replay instant into tests/fixtures and assert a bot decision on the real frame (make_fixture.py + replay_fixture.lua). Use when validating a gated fix, reproducing a timestamp, or the user asks for a fixture.
---

# Replay fixture

This is the cheap, mandatory local validator. It answers "did the fix fire on
the frame that motivated it?" The simulator does not belong here.

## Build a fixture

Need a behav-dump timeline JSON (from `behav-dump` / `get_dumper.sh` on a
`.dem`):

```bash
python3 tools/batch_test/replayscope/make_fixture.py <timeline> --t <sec> --hero <name> -o tests/fixtures/f_<stamp>_<hero>_<sec>.lua
```

Load it in a lua5.1 test via `tests/mock/replay_fixture.lua`. Real `jmz_func`
helpers run on that frame. **Do not stub `J.*`.**

## What a fixture actually contains

Heroes' pos / HP / mana / level / team / items / TP CD / abilities, plus
ground truth such as damage dealt to the subject in the next 5s and
`died_after`. It does **not** carry everything the live VM has.

Known world facts (do not treat a green test as a live-game green):

- `GetNearbyLaneCreeps` is empty on hero-only dumps — lane-creep predicates
  need a **declared** synthesized wave.
- `GetNeutralSpawners()` is `{}` — camp tables are stand-ins.
- `GetAttackRange` often reads the mock default 150 (ranged heroes look melee).
- `GetActiveMode` is bot-VM state, absent from `.dem` files.
- `GetActualIncomingDamage` / `GetMagicResist` often answer the Get* default 0.

If a clause you need is structurally unreadable offline, pin that as a world
assertion in the test and say which half is declared vs real. Do not pretend
end-to-end.

## Assert both arms

- **Gate off** (no `soak_side`): byte-identical to today's shipped decision
  on the untouched frame.
- **Gate on**: the new decision on that same frame (or a labeled
  counterfactual that flips one field and says so).

Drive the shipped function when you can; do not only grep the source.

## Naming

`tests/fixtures/f_<matchstamp>_<hero>_<sec>.lua` and a test file that names
the match, t=, hero, and what the bot could see. Substitute frames are allowed
when the motivating `.dem` is not in this checkout — write the substitution
in the test header (backlog 0FIX).
