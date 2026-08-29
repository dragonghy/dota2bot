# 多 Agent 工作流(2026-08-01 owner 定稿)

五个 Routine agent(每 2 小时各自触发一次全新会话)+ 主会话整合者。
每次触发:读本 README(铁律)→ 读自己的章程 → 做一个工作单元 →
写报告到 iterations/reports/<agent>/ → 更新章程"当前状态"节 → commit+push。

**座位(2026-08-24):** 这五个 Routine **仍在 Claude Code Cloud 上跑**(本文件的
读者就是它们)。Owner 只跟 **Cursor 主会话**聊(调度、总结、优先项)。不要等
一个 Claude Code 主会话来整合——那个座位已经挪走。跨组协作照旧走 GitHub
issue / `iterations/queue.json` / 章程文件;Cursor 读你们的报告,不替代你们的
工作单元。以后可能把 Routine 迁到 Cursor automation;**未迁之前不要改 cron 宿主**。

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
   **计量三条(总监 2026-08-23T21:xxZ 立,GH #148,全文档案 test_set.md §AZ)**:
   (i) **任何 armed/baseline 对比必须同时给 ab / ba 两个分层的读数**;两层反号 =
   噪声,不写进结论。这是「Radiant 侧偏 +1.5k gold,永远 swap-and-average」的
   行为检测器版,而且**更隐蔽**(检测器读数看起来不像经济读数那样"侧别相关")。
   (ii) **整数取值 + 小值域的计数类量不报中位数**,报均值 + 分布或某阈值的占比;
   要报中位数就必须同时给占比,**让刀口暴露出来**。
   (iii) **登记过的效应量,连"用哪种切法得到的"一起登记**。
   **立法依据是算术不是偏好**:同一份 212 局语料上 `med n_rc` 池化读作
   armed 1.0 vs baseline 2.0(**看着像 2 倍**),而均值是 **2.01 vs 2.02 逐位相同**——
   那个"2 倍"**全部**来自 `n_rc==1` 的占比 51.4% 与 47.9% **骑在 50% 刀口两侧**;
   同时中位数**跟着物理侧走不跟着 armed 腿走**(radiant 2.0 / dire 1.0,在 ab 与 ba
   两层里各自复现),侧别效应 6.1pp **大于**腿效应 3.5pp。
5. **协作总线 = GitHub issue**(repo dragonghy/dota2bot),标题前缀分派:
   [strategy] 协同组 | [hero] 英雄组 | [bug]/[harness] 总监 | [batch] 批测台。
   开 issue 必须带:帧证据(局/时刻/英雄)或复现步骤 + 建议的验收方式。
6. push 前:luacheck bots game --formatter plain 0 警告 + lua5.1
   tests/run_tests.lua 全绿。push 当前分支并同步 origin main;被拒先
   git pull --rebase 重试;仍失败只提交自己的报告/章程文件并在报告中记录。
   **⭐ 2026-08-26 再补(GH #213):静态那半现在自己跑** —— `.githooks/pre-push`
   调同一个 gate,**红(exit 3)与没跑成(exit 2)都拒绝 push**;开工自检
   (铁律 10)每个容器给它上膛(`tools/agent/arm_push_gate.sh` 写
   `core.hooksPath`,本地配置不随 clone 走)。真跑不动的容器用
   `RULE6_BYPASS=1 git push …`,它会打一行**「这是跳过不是通过」**,
   **那一行要抄进你的报告**。动态那半(~100min,GH #124)**不在钩子里也不被它声称**。
   **2026-08-26 补(GH #205):静态那半跑 `bash tools/agent/luacheck_gate.sh`** ——
   它先**自己把 luacheck 装上**再跑(冷启实测 **18s** = 装 5.5s + 跑 13s,trunk 0 警告),
   退出码 **0 干净 / 2 没跑成 / 3 有警告**。**「容器里没有 luacheck」从来不是跳过的理由**:
   apt 包名是 **`lua-check`** 不是 `luacheck`,后者 `Unable to locate package`,
   于是三轮独立地把它记成「不在 apt 里」,而**铁律 6 的第一条门在容器里一次都没开过**
   (与 GH #171 的 `lua5.1` 同族,但那次丢的是读数,这次丢的是门)。
   **⭐ 2026-08-29 再补(GH #290,总监立):`git push` 排在**关闭 issue、写下档案引用、
   让下游依赖它们**这三件事之前** —— 顺序,不是速度。08-28T22:03Z 那轮把 #286 关了并
   发表五处引用,而那五件产物还只在容器里(四小时后才 push);中间这段时间 **#287 拿
   一个不存在的测试限定了英雄组的作用域**,**W23 在未修的树上发波,OD 9/12 局停摆**。
   ⇒ 发表任何带引用的评论/裁定前,把草稿存成文件跑一次
   **`bash tools/agent/claim_precheck.sh <草稿文件>`**(冷启 <2s,只读):它按
   **`origin/main`**(读者看到的那棵树,不是你的工作树)解析草稿里的
   `tests/…` / `bots/…` 路径、`state.json:<key>`、`<章程>.md §XX` 和被 git 词锚定的
   commit,并打印**「本地领先 origin/main 几个 commit」**这一行。**0 = 可以发;
   3 = 先 push 再发;2 = 没跑成,不是通过。** 事后审计仍走
   `citation_audit.py --comments <评论 JSON>`(同一个解析器,新增 `AMBIGUOUS`:
   两节抢同一个 `§XX` 标题;08-29 当天就抓到一例)。
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
    `bash tools/agent/routine_selfcheck.sh`(约 20s,零 AWS 成本;**对仓库只读**)。
    **2026-08-26 更正两处措辞(GH #171)**:(i) 它**不再**是对容器只读 —— 缺
    `lua5.1` 时它会自己 `apt-get install`(实测 **4s**,失败就退回原行为),
    因为「缺解释器」被当成不可改变的环境事实,正是那条腿**从落地起在 Routine
    容器里一次都没跑过**的原因;它**仍然不碰工作树**(自检若死在 stash 与 pop
    之间会扣住未提交的工作)。(ii) **`SKIP`/`UNCERTIFIABLE` 不是通过** ——
    没跑成的腿现在打 `UNCERTIFIABLE` 横幅并把退出码抬到 **2**
    (0 干净 / 2 未核验 / 3 有发现);读到 2 的那一轮,**trunk 的那一侧这轮没人看过**。
    它把「推了没落地」(`unlanded_commits.py`)和「报告节奏有洞 / 已发表的
    引用解析不了」(`citation_audit.py`)一次跑完。**立这条的原因不是缺工具,
    是工具没人跑**:08-22 hero 08:00Z 的整棵树一直在
    `origin/claude/vibrant-heisenberg-3os6d0`(`eda1257`)上,03:00Z 就已经
    建好的检测器**点名点得到它**,没人跑 ⇒ 10:00Z 花整整一轮从零重做了同样
    的 8 个文件,12:00Z 又花一轮才落地。**报出来的是问题不是判决**(见两个
    工具的 LIMITS:OFF-TRUNK 可能是已改头换面落地的同一份工作,cadence 的洞
    可能是那一轮本来就没东西可交)——但**要看一眼**。
11. **不要在权限提示上坐等**(owner 2026-08-26 点名;铁律级)。
    无头 Routine **没有人点 Approve**。工具返回 `requires approval` /
    弹出权限对话框 / MCP 报 `MCP tool call requires approval` →
    **立刻放弃该工具**,改走还能用的路:git 用 Bash;`mcp__github__*`
    失败就把该写的评论写进报告(下轮补 issue)。**不许空转等待。**
    坐等的实测形状:08-24 W5 发了波、花了 ~$1.4、整轮蒸发无报告;
    同一座位并发会话(GH #180;总监 08-24 三个会话抢同一份活)。
    归因是「触发照常,产出落不了地」,不是 cron 停了。
