---
name: evidence-discipline
description: Four rules for making a reading trustworthy before it becomes a ruling — restore a mutation stand from a file copy, suspect the assertion when a mutant survives, never measure an exit code through a pipe, and never let a matching conclusion stand in for a correct reason. Use when building a mutation stand, reading a tool's exit code, or writing any verdict/promote/reject/verification claim into a report, issue, state.json or test_set.md.
---

# Evidence discipline

Four rules. Each was written after the same mistake had already happened at
least twice in this repo, and each has a **mechanical** remedy — you are meant
to do the thing, not remember the lesson.

## 1. Restore a mutation stand from a file copy, never `git checkout`

Copy the file **outside the tree** first, mutate in place, run, then restore
from the copy and prove the restore:

```bash
cp path/to/target.py /tmp/target.orig            # outside the tree
sha256sum path/to/target.py > /tmp/target.sha
# ... mutate, run, observe red ...
cp /tmp/target.orig path/to/target.py
sha256sum -c /tmp/target.sha                     # must print OK
```

`git checkout -- <file>` restores the **committed** state, so it silently
discards any uncommitted work in that same file — and the loss looks exactly
like "the mutation was reverted." The `sha256sum -c` line is what turns a
belief into a reading; run it after **every** mutant, not once at the end.

Sites: a `queue.json` rollback (2026-08-29) and the round before it.

## 2. A surviving mutant → suspect the assertion first, then the mutation

When a mutant stays green, the tempting read is "my mutation was too weak."
The commoner cause is that the **real corpus happens to agree** with the broken
rule, so the assertion never had to discriminate.

- Add a **synthetic** case that separates the two rules, then re-run the mutant.
- Ask which direction the accidental agreement points. If it points at *this
  leg staying quiet*, that is the dangerous direction and needs the synthetic
  case most.

Site (2026-08-29T21:50Z): the `ORPHAN_PROPOSAL` detector. M3 ("take the first
backtick on the line") matched the correct rule **word for word** on the real
corpus, because in all seven section headings the proposed id already came
first. M4 read `armed_ids` from the *first* member-like line — in the real file
that was the same line as the last one; the file holds 13 bare member strings,
**12 of them historical archive strings**, and reading any of those would judge
every post-08-19 id un-armed, i.e. exactly the direction that silences the leg.
Both went red the moment a synthetic case was added.

## 3. Never measure an exit code through a pipe

**Use the wrapper. It is shorter than the wrong thing, which is the point:**

```bash
bash tools/agent/rc.sh <cmd> [args...]      # short tail AND the true code
bash tools/agent/rc.sh -n 10 lua5.1 tests/run_tests.lua test_foo.lua
```

It runs the command with nothing between it and `$?`, shows you the last N
lines, and prints `RC_EXIT=<code>` as the **last line** — so the code survives
even `rc.sh cmd | tail -5`, at the exact moment `$?` no longer can. It also
exits with that code, so bare use reads correctly. Pinned by
`tests/test_rc_wrapper.py`.

By hand, if you must:

```bash
tool --flag                     # run it bare, read $?
tool --flag > /tmp/out.txt; rc=$?; tail -40 /tmp/out.txt   # or capture, then look
```

`tool | tail -40` returns **`tail`'s** status. A tool that exited 2 or 3 reads
back as 0, and a "could not run" reads exactly like a pass. The same shape
covers wrappers that swallow the code: `timeout 300 tool` killed by SIGTERM
gives **exit 143 with empty output** — that is *did not run*, not *ran clean*
(GH #171), and `argparse` answers a missing required flag with **exit 2**,
which likewise looks like a completed command.

In a test, assert it explicitly: `subprocess.run(...).returncode == 3`.

**A third look-alike, and this one a bare code cannot save you from:** a
`tests/*.lua` detector ends with `return tests` — it is a **module**, so
`lua5.1 tests/test_x.lua` loads it, asserts nothing, and exits **0** honestly.
Run Lua tests through `lua5.1 tests/run_tests.lua <basename>`; `rc.sh` refuses
the module form and names the runner.

Sites: `| tail -8` (08-29), `timeout 300` → 143 (08-29), a missing `--cand` →
argparse 2 (08-30), `| tail -50` on the self-check by the very round that
legislated this rule, `| tail -60` on the round after the skill landed — and
2026-08-31, where the **same command in the same minute** read **exit 0 piped**
and **exit 3 bare** on a round whose trunk really was red. That controlled pair
is what bought `rc.sh`: five rounds of prose lost to one one-liner, because the
wrong form was the shorter one.

## 4. The same conclusion is not the same reason

Two arguments reaching one answer does not make either argument sound, and the
wrong reason is what gets **inherited** by the next reader.

- When a ruling could be reached by more than one route, say **which route you
  took** and what would separate them.
- When you agree with someone's conclusion, verify their *argument* from the
  source before writing "confirmed"; a summary of an argument is not the
  argument.

Sites: a draft ruled "出集 by (乙)" when the correct ground was (甲) — invisible
because the outcome matched (§AR.3(丙), 08-30T01:20Z). And GH #329, where
option (A) gave roughly the right verdict for a reason that would have passed a
hand-pooled economy reading and blocked a swap-averaged detector reading.

## Where these belong in a report

State the reading and how it was obtained, in the same sentence:

- mutation stand: `变异 N/N 红`, plus `还原走文件副本 + sha256sum -c 每次 OK`
- exit codes: the number **and** that it was taken bare (`未经管道`)
- a leg that did not run: `UNCERTIFIABLE` — never folded into a pass count
