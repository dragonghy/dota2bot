# 多 Agent 工作流(2026-08-01 owner 定稿)

五个 Routine agent(每 2 小时各自触发一次全新会话)+ 主会话整合者。
每次触发:读本 README(铁律)→ 读自己的章程 → 做一个工作单元 →
写报告到 iterations/reports/<agent>/ → 更新章程"当前状态"节 → commit+push。

## 铁律(所有 agent 共守)
1. **只有批测台可以花 AWS 的钱**(MTD 刹车线 $90,owner 批准线 $100)。
   其他 agent 要批测:往 iterations/queue.json 提交申请。
2. **验证哲学(owner 2026-08-01 新规,取代旧的 4-seed 显著性检验)**:
   小改动不做数据显著性检验。一个改动从测试版进入稳定版的条件:
   (a) 录像组确认改动在实际对局中**真的执行且行为正确**(触发/生效/无副作用);
   (b) 批测显示对**胜负没有明显负面影响**(粗粒度,非显著性);
   (c) 改动的价值有**逻辑/理论依据**(标准策略可上网检索佐证)。
3. **版本模型**:稳定版 = main 上所有 gate 关闭的默认行为(锚点即当前 main,
   以后每次 promote 打 stable-vN tag);测试版 = 稳定版 + armed 的测试集
   (iterations/streams/test_set.md 维护当前测试集)。
   另有 upstream 基线 = 仓库初始 OHA 快照(commit 74727e4a66ab38d16fdb09800a19ab6c0c82c6b9),
   用于衡量累计总进步。
4. **可重复性纪律**:行为改动必须带真实帧 fixture(make_fixture.py);
   先逐帧后聚合;英雄名 canon 化;窗口统计加暂停过滤。
5. **协作总线 = GitHub issue**(repo dragonghy/dota2bot),标题前缀分派:
   [strategy] 协同组 | [hero] 英雄组 | [bug]/[harness] 总监 | [batch] 批测台。
   开 issue 必须带:帧证据(局/时刻/英雄)或复现步骤 + 建议的验收方式。
6. push 前:luacheck bots game --formatter plain 0 警告 + lua5.1
   tests/run_tests.lua 全绿。push 当前分支并同步 origin main;被拒先
   git pull --rebase 重试;仍失败只提交自己的报告/章程文件并在报告中记录。
7. 提交信息不含模型名。工作单元要小,干完就结束会话,不空转等待。
8. **报告末尾必须带本次会话的 token 用量**(owner 2026-08-19 要求):
   收尾时跑 `python3 tools/agent/token_usage.py`,把最后那行
   `TOKENS total_in=... out=... turns=...` 原样贴进报告最后一节。
   注意:这是"到统计时刻为止"的数字,统计后的收尾回合不计入,当量级
   参考足够。总监按周汇总各组用量,异常高的组要查原因(空转/重复劳动)。
9. **Owner 优先项凌驾于 issue 流**(2026-08-22):每轮触发先读
   `iterations/OWNER_PRIORITIES.md`;有属于本组的未完成项就优先做它。
   连带规则:"修好"不等于"做完"——被退回 id 的修复落地时,**同一工作
   单元内**必须把下一棒(重新入集申请 / 波次请求 / 核验请求)以 issue
   或 queue 请求的形式显式交出去,否则接力棒会掉(教训:拉野死分支
   2026-08-19 早晨修复后,因 issue #13 关闭而从所有队列消失 37 轮)。
   总监健康巡检核对优先项推进:12 轮零推进→报告红色升级并指名下一步;
   24 轮零推进→写进 DECISIONS_NEEDED 说明原因。
10. **开工第一件事跑自检**(总监 2026-08-22T13:00Z 立,GH #113):
    `bash tools/agent/routine_selfcheck.sh`(约 20s,零成本、只读)。
    它把「推了没落地」(`unlanded_commits.py`)和「报告节奏有洞 / 已发表的
    引用解析不了」(`citation_audit.py`)一次跑完。**立这条的原因不是缺工具,
    是工具没人跑**:08-22 hero 08:00Z 的整棵树一直在
    `origin/claude/vibrant-heisenberg-3os6d0`(`eda1257`)上,03:00Z 就已经
    建好的检测器**点名点得到它**,没人跑 ⇒ 10:00Z 花整整一轮从零重做了同样
    的 8 个文件,12:00Z 又花一轮才落地。**报出来的是问题不是判决**(见两个
    工具的 LIMITS:OFF-TRUNK 可能是已改头换面落地的同一份工作,cadence 的洞
    可能是那一轮本来就没东西可交)——但**要看一眼**。
