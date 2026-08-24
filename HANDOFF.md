# 主会话交接文档(HANDOFF)

写于 2026-08-24,交接人:上一任主会话(integrator)。接手前**按顺序**读:
`CLAUDE.md` → `iterations/streams/README.md`(铁律)→
`iterations/OWNER_PRIORITIES.md` → `iterations/streams/test_set.md` 最新 § 节 →
`iterations/DECISIONS_NEEDED.md` → 五份章程(`iterations/streams/*.md`)→
各组最新 2-3 份报告(`iterations/reports/<组>/`)。

## 1. 你的角色:整合者,不是执行者

owner(中文交流)只跟你聊。五个专业 agent 以 **Routine**(每 2h,fresh-session)
自治运行:批测台 batch-desk / 录像检查组 replay-check / 协同组 strategy /
英雄组 hero / 总监 director。**他们的活你不要抢**(分工在各自章程里);你做:

- 汇总现状回答 owner(数据从 reports/、test_set.md、issue 拉,别凭记忆);
- 把 owner 的意图变成机制:改章程文件、维护 `OWNER_PRIORITIES.md`(只有主会话
  可改)、开带 [前缀] 的 GitHub issue、往 `iterations/queue.json` 提批测请求;
- owner 的直接请求(如"给我做个回放页")用本地子代理:`replay-artifact`
  (ReplayScope 页 + Artifact)、`replay-analyst`(逐帧诊断)、`batch-runner`;
- 盯接力棒:凡 owner 决定/优先项,进 OWNER_PRIORITIES + issue 点名,
  不许沉入普通队列(这是 owner 两次失望的根源,铁律 9 有全文)。

## 2. 当前状态快照(2026-08-24T02:00Z)

- **稳定版**:`stable-v1`(2026-08-19,首个 promote = `roamstale`)。
  测试集 armed ~24 id,权威串在 test_set.md **最新 § 节的 §x.0**(别读旧节)。
- **P1 拉野**(owner 多次点名):creeppull 三条件已买齐((a) 二分装置 WORKING、
  (b) W3 过、(c) 节奏核过)——**等总监 promote 判定**;campgrade 在 W4 仍
  SILENT 迭代中;pullcamp 修复后回集。入口 issue #109。
- **P2 低血不回家**:决策侧 gated id `stayfield` 已落地;铁证帧已换
  (原 Slardar 帧作废,#111 检测器缺落点谓词;新帧 = lina t=349.1)。issue #110。
- **P3 cap 10→25**(owner 2026-08-22 拍板,#108):被晾两天后 08-24 刚升级
  点名总监——**验收三条落地并关 issue 才算完,要盯**。
- **坏消息在查**:25-id 全集波 gpm −93 / 胜率 0.243(0/4),与前一波只差
  `itemtrip` 一个 id ⇒ 头号嫌疑,总监在排查。
- **成本**:MTD ~$23.6,围栏 $45 / 刹车 $90 / 批准线 $100。批测默认
  **全集 armed**(owner 指示),单 id 隔离波是例外。
- **待确认**:W34 周日(08-23)的 owner 决定邮件是否已发(DECISIONS_NEEDED
  有 8 条,多数"不需决定,周报要报")——接手后第一件事核对。

## 3. Owner 的原则集(违反过的都付过学费)

1. **Turbo 优先**,与普通模式冲突时 Turbo 赢;t15+ 天赋/高等级门是死数据(#84)。
2. **少 TP 回家**:低血无危险 → 用/买补给、野区回复;回家 TP 是病例(P2)。
3. **拉野是肯定要做的**;数据不对 = 设计或实现错,不是方向错。
4. **验证三条件**(取代显著性检验):(a) 录像核验真的执行 (b) 胜负无明显负面
   (c) 逻辑/理论依据。小改动不做单独统计测量。
5. **批测/录像默认看测试版**(= 稳定版 + 全部最近改动 armed)。
6. **每周 ≤1 封需要 owner 决定的邮件**(dragonghy@gmail.com),问题攒进
   DECISIONS_NEEDED.md;花钱例外:每 $50 档要 owner 批(已批到 $100)。
7. owner 失望的两次都是**停滞/掉棒**,不是做错方向。宁可保守推进,不可沉默等待。

## 4. 环境与工具的坑(真实踩过)

- **claude-code-remote MCP 工具(list_triggers/send_later/create_trigger 等)
  在主会话一直被权限审批挡住**——Routine 是 owner 手动建的,你大概率也调不了;
  调整各组行为的正确姿势是**改章程文件**(每轮 fresh session 都会重读),
  参数底稿在 `iterations/streams/routine_prompts.md`。
- 自我唤醒用**后台 `sleep`**(Bash run_in_background);容器重启会悄悄杀掉它,
  醒来先 re-arm。不要依赖 CronCreate(会话挂起即失)。
- push 纪律:`git push -u origin <本会话分支> && git push origin HEAD:main`;
  被拒 `git pull --rebase origin main` 后重推。stop-hook 会催未推提交。
- GitHub 一律走 `mcp__github__*` 工具(无 gh CLI)。commit/PR/代码里**禁止模型名**。
- AWS:每个新会话先 `bash tools/batch_test/aws/session_setup.sh`,之后只用
  `awsx`。主会话一般只做只读(S3 ls/cp);花钱是批测台的独占权。
- 验证:`luacheck bots game` 0 警告 + `lua5.1 tests/run_tests.lua` 全绿
  (fresh 容器要先 apt 装 lua5.1/luacheck);只改 markdown 可免。
- token 统计:`python3 tools/agent/token_usage.py`(已修 message.id 去重)。
- 回放页:子代理用 `tools/batch_test/replayscope/`;dumper 用
  `tools/batch_test/behavioral/get_dumper.sh`(S3 缓存,秒级),宽扫用
  `sweep_run.sh`。dumper 事件流英雄名无下划线,统计过滤暂停段。
- 各组报告/`test_set.md` 是最可靠的事实源;test_set.md 很长,**只读最新 § 节
  和文件头的 ⚠️ 行**;`iterations/state.json` 是历史判决档案(JSON 改后必须
  `python3 -c "import json; json.load(open(...))"` 验证)。

## 5. 未收口的线程(按紧急度)

1. **P3/#108**:盯总监认领与三条验收(换 cap 后第一波要报自然结束占比/均局长/
   每波成本;录像组确认高地/买活场景首现)。
2. **creeppull promote 判定**(P1 最后一棒,总监)。
3. **itemtrip 排查**(25-id 波 −93 gpm 的头号嫌疑)。
4. **周日 owner 邮件**是否已发(见 §2 末条)。
5. campgrade SILENT 迭代(#117);stayfield 取证波(P2 完成定义 2-3 条)。
6. 帧语料检索工具(效率台账把它提为总监下一个自由工作单元——(a) 取证的
   规模化,四天 1 个 promote 的瓶颈解药)。

## 6. 一句话心法

这套机器不缺产能(五组 12 轮/天零漏拍),缺的是**方向压强**:owner 的每个
决定要立刻变成 OWNER_PRIORITIES 里带完成定义和责任链的条目并在 issue 上
点名,然后**盯到关闭**。你的价值 = owner 意图的保真传导 + 掉棒的及时发现。
