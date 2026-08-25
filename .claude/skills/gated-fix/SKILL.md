---
name: gated-fix
description: Land a new Dota 2 bot behavior change as a turbo-only soak-candidate (gated, fixture-validated, inert until promoted). Use when writing or narrowing a J.IsSoakCandidate fix, a new cand id, or any hero/strategy logic that must not ship live yet.
---

# Gated fix

New behavior lands **dark**. It is a no-op unless the game is Turbo **and** its
soak-candidate id is armed. Do not call a gated fix "shipped."

## Before writing code

1. Pin **one** concrete bad decision: match, timestamp, hero, what the bot
   could see (its team vision, not global).
2. Name a **new** id unless you are narrowing an existing one. Do not bundle
   unrelated levers (lanefix lesson).
3. State the local test: a replay fixture on that frame, not a simulator run.

## Implementation

- Gate with `J.IsModeTurbo() and J.IsSoakCandidate('<id>')` at the **single
  call site** that changes behavior. Off-candidate must stay byte-identical
  to the shipped path (keep the old code; do not "simplify it away").
- Prefer a helper that returns the old answer when the gate is off, then
  widens/narrows only when armed.
- Do not edit `bots/Customize/soak_side.lua` in git (it is gitignored; the
  farm writes `{side, cand, seed}`).
- If the file has a TypeScript source under `typescript/`, keep it in lockstep
  (ARCHITECTURE.md §13).

## Local validation (mandatory)

Follow the `replay-fixture` skill: freeze the motivating frame, load real
`jmz_func` (no `J.*` stubs), assert gate-off ≡ shipped and gate-on fires the
new decision. Gate-plumbing tests are not enough.

## After the code

- `luacheck bots game --formatter plain` → 0 warnings.
- Targeted lua tests for the new file plus anything that pins line numbers
  in the files you touched.
- **`bash tests/run_py_tests.sh` — yes, for a Lua change.** Gating a shipped
  constant is not only a Lua edit: a family of python detectors reads Lua
  thresholds *as source* (`tools/batch_test/behavioral/source_constants.py`),
  and the moment a gate turns a literal into an expression
  (`700` → `bWide and 1200 or 700`) every one of them goes red **for a reason
  that has nothing to do with the behavior you changed**. Seconds to run.
  When it does fire, the fix is `call_arg(..., arm='shipped')` (or `'armed'`)
  at the assertion — pin **both** legs, never delete the assertion. Caught on
  `tpreach` 2026-08-25 after the change had already ridden a branch and a
  `luacheck` + targeted-lua pass clean.
- File or update a GitHub issue with frame evidence and the proposed
  acceptance. Admission to `iterations/streams/test_set.md` is the
  **director** stream's job; a batch wave is the **batch-desk** job via
  `iterations/queue.json`. Do not launch AWS yourself from a hero/strategy
  session.
- Do not promote (remove the gate) without the three conditions in
  `iterations/streams/README.md`: (a) replay confirms it actually ran,
  (b) no obvious win/loss harm, (c) a retrievable strategy justification.
