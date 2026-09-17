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
git pull --rebase origin main    # FIRST, before either push
git push -u origin <this-session-branch> && git push origin HEAD:main
```

If rejected: `git pull --rebase origin main` then retry. The stop-hook will
nudge unpushed commits. Owner 2026-08-26: this repo does not use PRs —
Cursor integrator sessions use the same `push origin HEAD:main` path.

**⭐ 这个顺序是承重的,不是风格(总监 RULING 69,2026-09-17;GH #865):
「先推分支、再推 main」要保持不变,而 `git push origin HEAD:main` 会把本地的
`origin/main` 挪到 HEAD**,于是**排在它后面的那一次 push 同时被两样东西打掉**,
两样都**只在账单上出现、不在提示符上出现**(两次 push 都成功,第二次只是付钱):

1. `.githooks/pre-push` 的快 Lua 腿 scope = `git diff --name-only origin/main...HEAD`,
   **空表按设计 = 跑全集**(fail-closed,逐字 `skipping needs a positive answer`)⇒
   main 落地后那一次 push 的 diff **恒为空** ⇒ 跑全集。**实测**:总监 09-17T01:00Z
   那轮反着推,main 推读 `lua gate: SKIPPED BY SCOPE`,紧随其后的分支推读
   **`lua 411 ran … 639.7s`**(同一棵树,markdown-only 改动)。
2. `tools/agent/rule6_memo.py` 的键 = `(HEAD^{tree}, origin/main)` ⇒ 同一个 ref 移动
   让孪生 push **恒定 MISS**。⛔ **这是恒等式不是概率**,而 memo 存在的全部理由正是
   把第二推的窗口从 ~7 分钟压到 ~0(它输掉的那些 ref 竞态,正是 `RULE6_BYPASS` 被按下的路)。

**按文档顺序两条都不触发**:分支推**不移动** `origin/main` ⇒ 第二推问的是同一个问题,
memo 免费答掉。⚠️ **反序另有一条立法理由(GH #290:引用先可解析再发表),而它不需要反序** ——
本轮同时满足的做法是:两次 push 都在**发表任何带引用的评论之前**完成,
`claim_precheck.sh` 本来就按 `origin/main` 解析。
⛔ **反序唯一真实的代价(分支 ref 停在 rebase 之前 ⇒ 要 `--force-with-lease`)由上面那条
`pull --rebase` 前置解决**,不需要动顺序;真撞上时,会话分支是本会话独占的,
`--force-with-lease` 是安全的。
⛔ **也不要把顺序当成那条读写竞态(GH #856)的对策** —— #856 (丙) 已禁止这个推广,
管那件事的是读方走 `read_lua()` 判 exit 2,与谁先谁后无关。
📌 钉子:`tests/test_push_order_contract.py`(规则文件 / memo 的引用 / 钩子的 scope 三处必须一致)。

**这条路径上现在有一道门(GH #213):** 开工自检把 `core.hooksPath` 指向
`.githooks`,于是**上面两条 `git push` 各自跑一次铁律 6 的静态门**
(`luacheck_gate.sh`,冷启 18s / 热 13s);红或没跑成都会**拒绝 push**。
容器真跑不动时用 `RULE6_BYPASS=1 git push …`,并把它打出来的
「SKIPPED, not passed」那行**写进报告**。此前这里**中间没有任何东西挡着**,
那正是 #213 的立案句。

## Subagent dispatch

Rare one-offs from a Claude Code interactive session: Agent tool →
`.claude/agents/` (`batch-runner`, `replay-analyst`, `replay-artifact`).
Scheduled streams should not spawn those as a substitute for their charter.

## Session continuity (heartbeat)

Routines are owner-built and fire on their own cron. Steering them is done
by **editing charter files** (`iterations/streams/*.md`), which every fresh
session re-reads. `list_triggers` / `send_later` / `create_trigger` have
historically been blocked on permission approval in the old main session.
**Iron rule 11 (owner 2026-08-26):** a headless Routine has nobody to click
Approve. If a tool returns `requires approval` / `MCP tool call requires
approval`, skip that tool immediately (git via Bash; GitHub comments go in
the report if MCP is blocked). Do not sit waiting — that is how a wave
launches and the whole session evaporates (2026-08-24 W5; GH #180).

- In-memory schedules (CronCreate etc.) **do not survive session suspend**.
- Fallback background `sleep` dies silently on container restart.
- Always leave the tree committed + pushed so any wake resumes from git.

## AWS bootstrap timing

`session_setup.sh` as an environment setup script runs *before* Claude Code
launches, and in that phase `DOTA2BOT_AWS_*` is not injected — it no-ops.
Run it in-session, from a Bash tool call, when you actually need AWS.
Only batch-desk spends money.
