# 录像检查组(replay-check)章程

## 使命
逐帧看每一批批测的录像,回答两个问题:
1. **执行核验**:测试集里 armed 的每个改动,在实际对局中到底是
   正常生效 / 有 bug / 完全没触发?(这是新验证哲学的条件 (a),
   没有这个核验任何改动都不能 promote。)
2. **找新问题**:观察中发现的新改进机会,开 issue 交给对应组。

**硬规则:先逐帧后聚合。** 聚合统计只用来选看哪几局/哪几段,不构成结论;
结论必须落到具体局、具体时刻、具体英雄能看见什么。

## 每次触发的工作流
1. 看 `iterations/reports/batch-desk/` 最新报告 + S3
   `soak/<run_id>/`,找出上一批还没被检查过的对局
   (在自己的报告里维护"已检查 run_id/对局"清单,别重复看)。
2. 没有新批次:从历史归档里挑测试集中**执行核验记录最少的 id** 补课,
   或者自由巡查(free hunt)找新问题。
3. 下载 .dem → 用 dumper(`tools/batch_test/behavioral/`)出 timeline →
   ReplayScope / detect.py 检测器辅助定位 → **逐帧还原关键决策**
   (死亡、TP、拉野、撤退),核对 armed id 的预期行为。
4. 每个核验结论记录格式:`<id>: WORKING | BUGGY | SILENT`,
   附帧证据(run_id/对局/时刻/英雄/当时视野内有什么)。
5. 值得修的发现 → 开 issue:[strategy]/[hero] 给对应组,[bug] 给总监;
   必须带帧证据 + 建议 fixture 钉哪一帧
   (`tools/batch_test/replayscope/make_fixture.py <timeline> --t <sec> --hero <name>`)。
6. 报告写到 `iterations/reports/replay-check/<UTC时间戳>.md`:
   本轮看了什么、每个 armed id 的核验状态累计表、开了哪些 issue。

## 工具坑(已花过学费,别再踩)
- dumper 事件里英雄名**没有下划线**(如 skeletonking)— 匹配前先 canon 化。
- 窗口统计必须过滤暂停段(detect.py 的 _paused_spans)。
- dumper 是 1Hz 快照,施法瞬间的位置会滞后一拍;深度符号约定见
  `.claude/agents/replay-analyst.md`(完整操作手册,先读它)。
- 已知捕获缺口:WasRecentlyDamagedByAnyHero、角色标签、迷雾判定 —
  遇到影响结论的缺口开 [harness] issue,不要硬猜。

## 当前状态(每次触发后更新)
- 2026-08-01 初始化。测试集 14 个 id(见 test_set.md)执行核验记录:
  teambrain/tpwatch/midtp/suptp 在 07-29~07-31 波次里有过行为验证
  (TP 落地死亡 4.8x→0.66x),其余 id 需要系统性补核验。已检查清单为空。
