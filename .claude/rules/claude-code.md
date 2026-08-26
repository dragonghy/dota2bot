# Claude Code runtime (this file is not loaded by Cursor)

Shared project rules live in `AGENTS.md`. This file is only the Claude Code
session runtime.

## Seat (2026-08-24)

You are almost certainly one of the **five Routines** (batch-desk /
replay-check / strategy / hero / director). Owner-facing integration moved
to **Cursor**. Do not wait for a Claude Code main session. Do not invent an
integrator loop here. Cross-group work stays on GitHub issues, `queue.json`,
and charter files — Cursor reads your reports.

Automation hosting stays on Claude Code Cloud Routines until the owner
migrates it. Do not change the cron host.

If you somehow are a Claude Code interactive session talking to the owner,
still follow `HANDOFF.md`, but prefer routing owner chat to Cursor.

## Named streams

Read `iterations/streams/README.md` then your charter. One work unit, then
commit+push and end. Prompt templates: `iterations/streams/routine_prompts.md`.

## GitHub

Use the GitHub MCP tools (`mcp__github__*`). This environment historically
has no `gh` CLI in Claude Code sessions.

## Push path (Routines and Claude Code sessions)

```bash
git push -u origin <this-session-branch> && git push origin HEAD:main
```

If rejected: `git pull --rebase origin main` then retry. The stop-hook will
nudge unpushed commits. Owner 2026-08-26: this repo does not use PRs —
Cursor integrator sessions use the same `push origin HEAD:main` path.

## Subagent dispatch

Rare one-offs from a Claude Code interactive session: Agent tool →
`.claude/agents/` (`batch-runner`, `replay-analyst`, `replay-artifact`).
Scheduled streams should not spawn those as a substitute for their charter.

## Session continuity (heartbeat)

Routines are owner-built and fire on their own cron. Steering them is done
by **editing charter files** (`iterations/streams/*.md`), which every fresh
session re-reads. `list_triggers` / `send_later` / `create_trigger` have
historically been blocked on permission approval in the old main session.

- In-memory schedules (CronCreate etc.) **do not survive session suspend**.
- Fallback background `sleep` dies silently on container restart.
- Always leave the tree committed + pushed so any wake resumes from git.

## AWS bootstrap timing

`session_setup.sh` as an environment setup script runs *before* Claude Code
launches, and in that phase `DOTA2BOT_AWS_*` is not injected — it no-ops.
Run it in-session, from a Bash tool call, when you actually need AWS.
Only batch-desk spends money.
