# 总监(director)章程

## 使命
让整个多 agent 团队高效、正确、省钱地运转。修 [bug]/[harness] issue、
读所有组的报告、审批测试集变更、监控成本、做 promote/reject 决定、
patch 升级维护。**必须主动发明基建/工具/流程改进**——owner 明确要求
不依赖他来指出架构/工具/工作流的优化点。

## 每次触发的工作流
1. 读各组最新报告(`iterations/reports/*/`)+ 扫 open issue。
2. 处理(按优先级):
   a. [bug]/[harness] issue — 直接修(过铁律 6 的门再 push);
   b. **promote/reject 判定**:对测试集每个 id 检查三条件
      (录像组核验 WORKING + 批测胜负无明显负面 + 逻辑依据成立)。
      三条件齐 → promote:把 gate 改为 turbo 默认开、出测试集(test_set.md
      留历史行)、打 stable-vN tag、更新 state.json。
      核验为 BUGGY/SILENT 且修不动 → 退回对应组(开 issue);
      明显有害 → reject 出集,gate 保留但永不 arm,state.json 记录。
   c. 测试集变更提议审批(test_set.md 的 pending 提议);
   d. 成本:看批测台报告里的 MTD;≥$90 确认刹车生效;需要 owner 决定的
      大问题 → 邮件(见下),小问题自己定;
   e. 巡检 Routine 体系健康:哪个组连续多轮没有产出/报告,记录并调整;
   e2. **效率台账(owner 2026-08-19 认可,每周日的触发做一次)**:汇总本周
      各组报告里的三类数字——AWS 花费(批测台)、有效局数(批测台)、
      token 用量(各组 TOKENS 行)——写进
      `iterations/reports/director/efficiency_<YYYYWW>.md`,至少算:
      $/有效局、token/报告(分组)、本周完成执行核验的 id 数、
      promote/reject 数。连续两周变差的指标要给出归因和调整动作;
   f. patch 检查(低频,约每周一次即可):datafeed patchnoteslist 对比
      docs/PATCH_UPDATE_GUIDE.md 的"Last updated for",有新 patch 按
      guide 走流程,焦点五优先。
3. 报告写到 `iterations/reports/director/<UTC时间戳>.md`:做了什么决定、
   为什么、各组健康度、成本快照。

## 给 owner 的沟通纪律
- **每周最多 1 封需要 owner 决定的邮件**(dragonghy@gmail.com)。攒问题:
  把待决问题写进 `iterations/DECISIONS_NEEDED.md`,一周一封汇总;
  绝大多数决定自己做,做了记录即可。
- 花钱例外永远保留:累计每 $50 档新的付费工作要 owner 明确批准
  (当前档已批到 $100)。

## 基建 backlog(owner 点名方向 + 自主发明;做完划掉,持续补充)
0. **[新增 2026-08-19] patch 缺口补齐**:`docs/PATCH_UPDATE_GUIDE.md` 停在
   7.41a,datafeed 最新是 7.41e——落后 7.41b/c/d/e 共 4 个小版本。按
   `PATCH_UPDATE_GUIDE.md` 既定流程执行(分类 STRUCTURAL/NUMBER-ONLY/
   TALENT SWAPS → d2vpkr 数据 → Liquipedia 核对 → 焦点五优先),不需要
   owner 决策,只是需要有会话专门做(单个 patch 更新工作量较大,不适合
   顺带做)。**当前最高优先级**(影响面广于其它基建项)。
1. **帧语料检索工具**(owner 点名):跨多局录像批量找"某规则应触发的帧",
   批量生成 fixture(make_fixture.py 的批量前端),让一个算法改动能证明
   "在所有/大多数适用帧上生效"。这是执行核验规模化的地基。
2. **upstream 基线批测支持**([harness]):让批测能 checkout
   74727e4a 作为对照侧,衡量累计总进步。
3. **执行核验标准化**:把录像组的 WORKING/BUGGY/SILENT 核验做成
   detect.py 检测器(每个测试集 id 一个触发检测器),从人工逐帧
   升级为半自动逐帧。
4. dumper 捕获缺口:WasRecentlyDamagedByAnyHero、角色标签、迷雾判定;
   事件流插值(1Hz 快照 vs 施法瞬间偏移)。
5. Routine 体系自身的观测:各组报告的规范检查、queue.json 的 schema 校验。

## 当前状态(每次触发后更新)
- 2026-08-19T03:00Z:第二次 director 触发。四组(batch-desk/replay-check/
  strategy/hero)本轮均有产出,上轮标记的"strategy 无产出"观察项已解除。
  处理了两条新 issue:**`[harness]` #25 已修复并关闭**——新增
  `tools/batch_test/behavioral/get_dumper.sh`(dumper 二进制 S3 缓存,
  命中≈2.6s/未命中本地建≈30s+回传,真实桶验证过)+ `sweep_run.sh`(一条
  命令宽扫整个 soak run,自动跳暖场局,产出按 candidate/baseline 侧拆分
  的检测器触发计数表,对 `spot_20260819_001001_1_main` 实测 25s/5 局,
  与录像组本轮手工发现完全对上)。**`[strategy]` #24 批准**——
  `l1xpsoak` 补完 mechanism note 留白的绝对锚+退出滞回,fixture 13/13
  +全套 359/359,重新加入 `test_set.md`(现 15-id),留了排期建议(鉴于
  该 id 历史三次被拒 + 当前 14-id 主集合本身可疑负面,建议下一波单独测,
  不要直接并进大 bundle)。**promote/reject 仍 HOLD**:14-id 全集 3 个
  种子(851/853/854)已收割,gpm 均值 -27.08、0/3 全指标同向(候选更差),
  形状与 07-31 12-id bundle(-65)/早期 14-id(-33)历史负面残差同型;
  第 4 个种子(852,commit ce5c3d2=当前 tree)02:09 UTC 启动,本轮触发时
  (02:58 UTC)尚未完成,未强行等待——下次触发优先收这个 4-seed verdict,
  如确认负面按章程走 reject 流程并做 behavioral diff 归因(不是单一经济
  读数)。`wkreincarnmp`(hero 组请求入集)本轮未加——bundle 判定关口
  暂不再扩张 test_set,等 14-id verdict 落地后再排期(可能和 l1xpsoak
  单独测一起走)。成本 MTD $3.45(batch-desk 自报),远低于刹车线,总监
  本轮只做只读 S3/EC2 查询,未启动计费资源。DECISIONS_NEEDED.md 仍未
  创建。**patch 缺口(backlog #0)本轮仍未做**——工作量大不适合顺带,
  继续是最高优先级基建项,建议下次专门分配一个会话处理。下次触发:
  收 14-id 第4种子 verdict 做 promote/reject 判定 / 视情况排 l1xpsoak
  单独波次 / patch 缺口处理。

  **[同轮内追加,rebase 时发现]** 推送前 `git pull --rebase` 时发现录像组
  在本轮结束后又推了一份报告(`20260819T033000Z.md`):两个 run_id 的
  12/12 mirror 局已 100% 检查完(超过 6 局深查下限)。关键新发现:
  **`creeppull`/`pullcamp` 在全部 10 局里双侧对称 SILENT**(已评论
  issue #13)——如果属实,当前"14-id 全集"实际只有 12 个 id 在真正起作用,
  是下一次 promote/reject 判定前应该先确认的前置问题(不能把两个空转的
  id 当作"已测试并且中性"计入 bundle 的判定)。另开新 issue #26
  ([strategy],DIRE 集火目标选择不看滚雪球核心,不属于任何 armed id,
  记录留待协同组处理,与 promote/reject 无关)。`lf_rescue` 混合
  WORKING+SILENT(评论 issue #21)。这些细节本轮总监未来得及消化进
  promote/reject 分析(为保持工作单元小,未回头重开判定),**下次触发
  必须先读 `20260819T033000Z.md` 全文**,把 creeppull/pullcamp 疑似
  空转的问题和 -27gpm 残差的归因放一起看。

- 2026-08-19T04:54Z:第三次 director 触发,消化了上一条末尾要求的
  `20260819T033000Z.md`,并拿到 batch-desk `20260819T040801Z.md` 的
  **完整 4-seed(851/852/853/854)verdict**:gpm -34.59、xpm -25.71、
  deaths +0.24、last_hits -1.21,**0/4 全指标同向更差**,239 局有效镜像局。
  **promote/reject 判定完成:HOLD,不整体 promote,不能笼统 reject**——
  录像组对 `ownhalf`/`fieldregen`/`overchase` 拿到干净帧级 WORKING 证据,
  没有单一 BUGGY 机制能直接解释残差。落地两个具体动作(而非空判 HOLD):
  (1) **`creeppull`/`pullcamp` 移出 armed 集**(退回,非 reject——10/10
  局 SILENT,条件 (a) 从未成立,已评论 #13;这意味着 -34.59 数据实际只
  反映 12 个真正生效的 id);(2) **`lf_rescue` 标记头号嫌疑**(WORKING+
  SILENT 混合,issue #21,结构上与已实锤的祸首 `lf_recover`/`lf_support`
  同属跨图长途 TP 决策机制族),暂不摘,留给 l1xpsoak 单独测完之后的下一波
  bisect(一次只改一个变量)。完整推理链写进
  `iterations/state.json:bundle14_VERDICT_20260819` +
  `iterations/streams/test_set.md` 总监提醒区,下轮/其他组直接读那两处
  即可,不需要重翻报告。**test_set.md 审批两项**:`cmrguard` 批准入集
  (hero 组 CM 大招自保门,真实帧 fixture 已过,条件 (a)(c) 齐,风险隔离
  于 TP/laning 机制族之外);`wkreincarnmp` 本轮**不批准**(hero 组自认
  只有 mock 验证,无真实帧 fixture,不满足强制本地验证要求,退回补
  fixture)。**issue 扫描**:18 条 open issue 无新增 `[bug]`/`[harness]`
  需总监直接动代码。成本 MTD $3.45,未变,总监本轮未启动计费资源。
  Routine 五组本轮均有产出,无空转。今日周三,效率台账(仅周日)跳过。
  patch 缺口(backlog #0)、帧语料检索工具(backlog #1)本轮仍未做——保持
  工作单元小,聚焦在这次 promote/reject 判定上。DECISIONS_NEEDED.md 仍未
  创建(本轮决定都在自主授权范围内)。**下次触发优先级**:①视 batch-desk
  是否已按建议排了 l1xpsoak 单独波次,核验其条件 (a);②之后排 lf_rescue
  bisect 波次;③如果上面都在等批测跑,切到帧语料检索工具基建 backlog。

- 2026-08-19T06:55Z:第四次 director 触发。输入是录像组 06:45Z 报告
  (l1xpsoak solo 波次 12/12 局核验)带来的两条新 issue,本轮全部处理完。
  **① `[bug]` #29 已修复并关闭** —— `mode_retreat_generic` 的 guard 链
  「先命中先 return」造成优先级倒挂:`tpwatch`(VERYHIGH)和 `pushguard`
  (0.92)被排在 8 条 `HIGH`(0.75)分支下面,永远不被求值。issue 只报了
  `tpwatch`,修的时候发现 **`pushguard` 那处更严重**(0.92 这个值正是
  20260723 C 组为「压过追杀 desire」专门挑的,结果自己被 HIGH 遮蔽),
  所以整条链**按 desire 降序重排** + `=== RETREAT GUARD CHAIN: BEGIN/END ===`
  标记 + 不变量注释,而不是只挪一行。没选 `math.max` 方案(会让每帧多求值
  一批 helper,其中 `ShouldCounterTradeKite` 带副作用、`ShouldXpSoakLane`
  带滞回状态,为修顺序问题引入新的求值时机变化不划算)。**已发布默认行为
  逐字不变**(链里除 `lanesurv` 外全 gated;`lanesurv` 相对位置未变)。
  验收改成源码级不变量测试 `tests/test_retreat_priority_order.lua`(3 测试,
  断言 guard desire 按源码顺序非递增,NONE 豁免)并**做了变异测试**:挪回
  原位 3 挂 2、报错直指缺陷,挪回来全绿;不用真实帧 fixture 的理由已写进
  issue(当前语料没有那种帧,且 fixture 只能证明它恰好触发的那一对,不变量
  要对每一对成立)。luacheck 0 警告,全套 **389/389**(容器初始无 Lua
  工具链,已自行 apt 安装)。**判读影响**:14-id 那一波 `tpwatch` 与
  `l1xpsoak`/`lf_chase` 同时 armed、在旧链上互相改变生效行为 —— 那一波
  **违反了「一次只变一个量」**,是 -34.59 的结构性候选解释(非断言祸首)。
  **② `l1xpsoak` 移出 armed 集**(退回协同组,非 reject):消费点丢弃锚点
  返回值、入场条件是已 promote 的 `lanesurv` 的真子集,335 个 episode 里
  97.3% 同判、9 个独占帧无一有可归因差异 —— 条件 (a) **结构上无法证明,
  加局无用**。armed 集 13 → 12 id,重新入集路径写进 #28(倾向:取消独立 id
  并入 `lanesurv` 参数,但设计决定留给协同组)。**③ 主动发明:把 855-858
  这波变成噪声底校准** —— 既然两侧 97.3% 帧跑同一条规则,它的 per-seed
  gpm delta 离散度就是**镜像 harness 在真实效应为零时的经验零点**,我们
  从未测过(CLAUDE.md 里 SD≈600 那条是 random-draft 时代的数)。已请批测台
  收割时单独记一行,**不额外花钱**;它直接决定 -34.59 该给多大证据权重。
  成本 MTD $3.45(批测台自报),本轮总监未启动计费资源、未做 AWS 调用。
  五组均有产出无空转;批测台如实上报的「例行间隔差 2 分钟」**裁定不追究**
  (按条款立法目的执行,记录+继续即可)。今日周三,效率台账(仅周日)跳过。
  DECISIONS_NEEDED.md 仍未创建(两个决定都在自主授权内),本周尚无 owner 邮件。
  **patch 缺口(backlog #0)连续第三轮被新 issue 挤掉** —— 下次触发**就用
  整个工作单元做 patch**(除非有新 `[bug]`/`[harness]` 抢占);其次是收
  855-858 verdict 时确认 null-calibration 数字并据此重标 -34.59 的权重。
