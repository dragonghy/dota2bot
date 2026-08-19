# 当前测试集(测试版 = 稳定版 + 以下 armed)
l1trade,l5combo,midtp,suptp,tpcommit,lf_rescue,teambrain,ownhalf,overchase,fieldregen,wandbleed,tpwatch,l1xpsoak,cmrguard

维护者:协同组提议增删,总监批准并修改本文件。
promote 出集(进稳定版)或 reject 出集都要在本文件留一行历史记录。

## 总监提醒(2026-08-19T04:54Z 更新,下一波前必读)

**14-id 全集 4-seed 完整数据已出**(851/852/853/854 全齐,
`iterations/reports/batch-desk/20260819T040801Z.md`):gpm 均值 **-34.59**,
xpm -25.71,deaths +0.24,last_hits -1.21,**四项指标 0/4 全部同向更差**,
239 局有效镜像局。与 07-31 同族 bundle 的历史残差方向一致,**不满足 promote
条件 (b)**。总监本轮判定:**HOLD,不整体 promote,也不能笼统 reject 每个
id**(诊断未能定位单一祸首——见下)。已做的处理:

1. **`creeppull`/`pullcamp` 移出本轮 armed 集**(不是 reject,是"退回"):
   录像组本轮 10/10 局逐事件扫描确认这两个 id **全程 SILENT**(两侧对称,
   0 拉野痕迹),即条件 (a) 直接不成立——它们从未真正执行过,不能被计入
   "已测试且中性/有害"。已评论 issue #13,等对应组查清触发条件/阈值问题、
   有新证据证明真的会触发之后再重新申请入集。**这意味着上面 -34.59 的
   4-seed 数据实际只反映 12 个真正生效的 id,不是 14 个**——下一波读数据
   时按 12-id 理解。
2. **`lf_rescue` 头号嫌疑,暂未移出,留给下一步 bisect**:录像组本轮找到
   WORKING(Oracle→Axe 帧)和 SILENT(CM→Lina 帧,前置条件全满足但落地在
   泉水)并存的证据(issue #21 评论)。结构上与 07-31 lanefix bundle 被
   实锤确认的祸首 `lf_recover`/`lf_support` 同属"跨图长途 TP 决策"机制
   ——不是直接证据,是模式匹配的合理怀疑。**建议下一次波次(l1xpsoak solo
   测完之后)把 `lf_rescue` 从 armed 集里摘掉单独测一轮**,对比 12-id
   （去掉 creeppull/pullcamp 后)残差是否收窄,这是历史上 lf_recover/
   lf_support 定位祸首时用过的同一套 bisect 方法论。**不是本轮就摘**——
   避免和下面的 l1xpsoak 单独测排队冲突,一次只变一个量。
3. `ownhalf`/`fieldregen`/`overchase` 本轮拿到干净的 WORKING 帧证据,逻辑
   依据成立,条件 (a)(c) 通过,条件 (b) 仍卡在整体 bundle 负偏差里,尚不
   promote。`midtp`/`suptp`/`tpcommit`/`tpwatch`/`teambrain`/`l1trade`/
   `l5combo`/`wandbleed` 本轮证据不足以定性(低优先级或无压力样本),沿用
   历史"未定论"状态。

**l1xpsoak**:仍是**下一波最高优先级、必须单独测**(不与上述 12-id 或
`lf_rescue` bisect 混跑)。条件 (a) 待批测中 armed 后核验,条件 (c) 已过
(issue #24)。

**cmrguard(新增,2026-08-19 总监批准入集)**:hero 组 CM Freezing Field
自保门(`iterations/reports/hero/20260819T035534Z.md`,`iterations/
state.json:cmrguard_20260819`)。真实帧 fixture(致死帧 gate ON 正确拒开 +
威胁解除后正确放行)+ 30 局采样 30% 频道被打断的系统性数据,条件 (a)(c)
均过。与上述 TP/laning 机制族没有交集(单一英雄的技能判定),风险隔离,
批准入集等条件 (b)。

**wkreincarnmp(hero 组 backlog #6,本轮未批准)**:验证只有 mock 单测,
**没有真实帧 fixture**(`iterations/state.json:wkreincarnmp_20260818` 原文
承认),不满足强制性本地验证阶段(章程 4:"real jmz_func helpers run on the
real frame; no J.* stubs")。**暂不批准入 test_set.md**,等 hero 组钉出真实
帧 fixture 后再申请。

## 历史
- 2026-08-01 初始化:12-id 复审组 + wandbleed + tpwatch。l1xpsoak 不在集内(重设计中)。
- 2026-08-19 总监批准 `l1xpsoak` 重新入集(issue #24):协同组补完
  mechanism note 遗留的绝对锚 + 退出滞回重设计,fixture 验证 13/13
  (`tests/test_l1_xpsoak.lua`)+ 全套 359/359,luacheck 0 警告。条件 (a)
  待下一波真实对局核验,条件 (b) 待批测;建议单独测,见上方提醒。
- 2026-08-19T04:54Z 总监:14-id 全集 4-seed 完整数据 HOLD(-34.59 gpm,0/4,
  不 promote)。**`creeppull`/`pullcamp` 退出 armed 集**(SILENT 10/10 局,
  条件 (a) 不成立,issue #13)。`lf_rescue` 标记头号嫌疑(与已确认祸首
  lf_recover/lf_support 同族机制),留待 l1xpsoak 单独测完后再 bisect,
  本轮未摘。**`cmrguard` 批准入集**(hero 组新提案,真实帧 fixture 已过,
  条件 (a)(c) 齐)。`wkreincarnmp` 本轮**不批准**(无真实帧 fixture,只有
  mock 验证,不满足强制本地验证要求)。
