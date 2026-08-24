---
name: owner-briefing
description: Summarize current bot-lab status for the owner, or turn an owner decision into OWNER_PRIORITIES / issues / queue.json. Use when the owner asks what is going on, what to do next, whether a priority moved, or wants a schedule/digest. Cursor integrator skill; do not use this to run a Routine work unit.
---

# Owner briefing and scheduling

You are the integrator talking to the owner (简体中文; paths and ids stay
English). Data from disk and GitHub, never from memory.

## Read order (every briefing)

1. `HANDOFF.md` — role and open threads (the snapshot dates; verify)
2. `iterations/OWNER_PRIORITIES.md` — standing P1/P2/P3
3. `iterations/streams/test_set.md` — **latest § only** plus the header ⚠️
4. `iterations/DECISIONS_NEEDED.md` — what is waiting on the owner
5. Newest 1–2 reports per stream under `iterations/reports/<stream>/`
6. Open GitHub issues (title prefixes assign the stream)

`iterations/state.json` is the verdict archive, not the live board. Do not
quote an old pending_validations list as current.

## Briefing shape

Lead with what is true now: priorities, what each stream last did, what is
blocked on the owner, cost (MTD vs $45 / $90 / $100) if a batch-desk report
has it. Then open threads. Do not recap the whole project.

Flag dropped batons: a named owner decision with no work unit in ~12 stream
cycles (~1 day) is red; ~24 cycles goes into `DECISIONS_NEEDED.md`.

## Scheduling (turning talk into mechanism)

When the owner decides something:

1. Write or update `OWNER_PRIORITIES.md` (integrator-only file) with a
   completion definition and a named next stream.
2. Open or comment on a `[prefix]` GitHub issue so the next Routine cannot
   miss it. "Fixed" ≠ done — the next baton (readmit / wave / verify) must
   be an explicit issue or `queue.json` request in the same turn.
3. Do **not** start the five Claude Code Routines or rewrite their cron.
   Change behavior by editing `iterations/streams/*.md` (they re-read every
   fire). Prompt templates stay in `routine_prompts.md`.
4. Batch launches go on `iterations/queue.json` for batch-desk. You do not
   spend AWS.

## Cadence

If the owner wants recurring Cursor summaries, subscribe a timer in this
conversation (briefing prompt only). That is not a replacement for the
Claude Code Routines. Do not set a cadence unless they asked.

## Later migration

Cursor Automations may host the five streams later. Until then the host is
Claude Code. Do not create parallel Cursor automations that duplicate
batch-desk / replay-check / strategy / hero / director.
