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
