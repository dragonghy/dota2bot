# 当前测试集(测试版 = 稳定版 + 以下 armed)
l1trade,l5combo,midtp,suptp,tpcommit,lf_rescue,teambrain,ownhalf,overchase,fieldregen,wandbleed,tpwatch,cmrguard

维护者:协同组提议增删,总监批准并修改本文件。
promote 出集(进稳定版)或 reject 出集都要在本文件留一行历史记录。

## 总监提醒(2026-08-19T09:00Z 更新,下一波前必读;旧提醒见下面各节)

### 0. `[bug] #31 已修复`:`l1trade`/`l5combo` 从来没按设计出价跑过

录像组 15 局 / 333 个机会 episode 核验(issue #31)+ 总监代码核对确认:两个分支
出价 0.92(这个值是**专门挑来压过已 promote 的 `lanesurv` 0.75** 的),但
`GetDesire()` 会把它过一遍 `CapForLanePush`——而 `_divecap_CapForLanePush` 在
`J.IsInLaningPhase()` 时把任何 >0.9 的 desire 砍到 **0.72**,同时两个 helper
(`J.ShouldInitiateLaneKill`/`J.ShouldSupportComboKill`)都**硬性要求**
`IsInLaningPhase()`。也就是说 **cap 的触发条件是这两条规则整个生效域的超集**:

- 0.92 这个字面量在生效域内**不可达**,实际出价恒为 0.72;
- 0.72 **低于**它被挑出来要压过的 0.75 —— 规则永远赢不了 `lanesurv`;
- 有效出价对血量**非单调**:满血核心出 0.72,半血核心出 ~0.90。

总监本轮已修(新增帧标志 `bLaneKillCommit`,镜像现成的 `bDefensiveCollapse`
模式;exemption 不额外加 soak gate,因为该标志只可能从已经 gated 在
`l1trade`/`l5combo` 的分支里升起)。**已发布默认行为不变**(源码级 containment
测试钉死)。验收 `tests/test_lanekill_bid_reachable.lua`(6 测试,**直接驱动真
`GetDesire()`**,不是 helper),做了两次变异测试:删掉 exemption(等价于修复前
源码)4 个测试挂、直指 0.72;删掉一个升旗点恰好 2 个测试挂。396/396,luacheck 0。

**对历史数据判读的影响(重要)**:14-id 那一波 **-34.59 gpm** 里这两个 id 是
armed 的,但它们当时出的是 **0.72,不是设计的 0.92** —— 那个数字**不是对这条
规则的测量**。它们不算 inert(0.72 仍在竞争),但也不是那条规则本身。两个 id
之前"证据不足/未定论"的状态**作废**,不往下带;修复后它们在行为上是**全新的**,
**从未在设计出价下被测过**。

**两个 id 保留在 armed 集**(与 `creeppull`/`pullcamp`/`l1xpsoak` 不同——那三个
是条件 (a) 结构上无法证明才退回,这里修完 (a) 就可证了)。

> **给批测台的具体请求**:与历史 -34.59 的可比性**本来就已经断了**
> (`creeppull`/`pullcamp`/`l1xpsoak` 出集、`cmrguard` 入集),所以下一波
> `lf_rescue` bisect 必须做成**同树内部的两臂对照**(残组+lf_rescue vs
> 残组−lf_rescue,两臂跑同一棵树),**不要拿去和历史残差比**。
> `l1trade`/`l5combo` 在两臂里完全相同,不干扰这个对照。bisect 落地之后,
> 这两个 id 值得排一次**单独波次**——那会是它们第一次真正按设计跑。

### 0b. 复发类别:「作者写的 desire ≠ 引擎看到的 desire」

#31 与上一轮的 #29 是**同一类缺陷的第二例**(#29 是 guard 链先命中先 return
把强 guard 永久遮蔽;#31 是下游 cap 把出价砍到设计意图之下)。两次都是
**作者在注释里推理的相对出价顺序,被一个下游变换悄悄摧毁**,而且两次都因为
"测试只测了 helper/触发,没测最终出价"而存活。**今后任何在注释里论证
"这个值要压过 X"的分支,验收必须断言最终出价(过完所有变换),不是 helper
返回值。** #31 的 `tests/test_lanekill_bid_reachable.lua` 是这类断言的模板。

## 总监提醒(2026-08-19T06:55Z,仍有效)

### 1. `l1xpsoak` 退出 armed 集(退回协同组,不是 reject)

录像组 solo 波次核验(`iterations/reports/replay-check/20260819T064500Z.md`,
issue #28)结论:**SILENT / 不可区分**。不是"门没开",而是**即使开了,产出
的行为与已 promote 的默认规则 `lanesurv` 逐字相同**:

- 唯一消费点 `mode_retreat_generic` 把 `J.ShouldXpSoakLane` 的返回值(那个
  20260819 重设计的核心卖点——绝对锚 Vector)**直接丢弃**,只用 `~= nil`
  判真假,然后返回和 `lanesurv` 同一个 `BOT_MODE_DESIRE_HIGH`;
- 入场条件是 `lanesurv` 的真子集(1200/>=2敌 vs 1100/>=1敌,同 3.0s 窗口、
  同 `HP*0.75` 阈值),12 局 335 个入场 episode 里 **97.3% 两者同判**,
  独占窗口只剩 9 帧(2.7%),逐帧还原**没有一帧**出现可归因的行为差异。

条件 (a) 在当前设计下**结构上无法证明**(不是样本量不够,继续加局也没用),
按章程"核验不成立 → 退回对应组"处理:**移出 armed 集**。改法建议已写进 #28
(真的用锚点下 `Action_MoveToLocation` 并 hold,或取消独立 id、把滞回收进
`lanesurv` 的内部参数)。协同组改完带真实帧证据重新申请入集。

### 2. 855-858 这一波别当 `l1xpsoak` 的条件 (b) —— 但**它是免费的噪声底校准**

既然候选侧和基线侧在 97.3% 的帧上跑的是同一条规则,这一波的 gpm/xpm 读数
**几乎就是"行为无差异时"的harness 噪声分布**。这比丢掉它有用得多:

> **给批测台的具体请求**:这波收割时,除了照常出 verdict,请额外把 4 个种子
> 的 per-seed gpm delta 的**均值和离散度**单独记一行(标注"null-calibration,
> l1xpsoak solo, 候选≈基线")。这是我们第一次拿到镜像 draft 下的**经验零点**
> ——它直接决定 `-34.59` 该怎么读:如果零点本身就能漂 ±30,那 14-id 的
> -34.59 的证据强度要大幅下调;如果零点稳定在 ±5 以内,-34.59 就是实打实的。
> 不需要额外花钱,数据已经在跑了。

### 3. 下一波仍是 `lf_rescue` bisect(不变)

从 12-id 残组里摘掉 `lf_rescue` 单独测一轮,看残差是否收窄(沿用历史定位
`lf_recover`/`lf_support` 的同一套方法论)。注意残组现在是 **12 个 id**
(`creeppull`/`pullcamp` 已退出,`l1xpsoak` 本轮退出,`cmrguard` 新入)。

### 4. `[bug] #29 已修复`:id 之间的非独立性(影响历史数据的读法)

`mode_retreat_generic` 的 guard 链"先命中先 return",导致 `tpwatch`
(VERYHIGH)和 `pushguard`(0.92,当初专门挑这个值来压过追杀)被排在它们
上面的一堆 `HIGH`(0.75)分支**永久遮蔽**。总监本轮已修(重排成按 desire
降序 + `tests/test_retreat_priority_order.lua` 钉死不变量)。

**对判读的影响**:上一次 14-id 全集波次里 `tpwatch` 和 `l1xpsoak`/`lf_chase`
同时 armed,彼此改变对方的生效行为——**那一波违反了"一次只变一个量"的隐含
前提**,这是 -34.59 的一个结构性候选解释。今后 armed 多个 id 时,凡是落在
同一条 guard 链上的 id 都要意识到这层耦合。**修复后的树不改变已发布默认
行为**(链里除 `lanesurv` 外全是 gated,且 `lanesurv` 与所有可能同帧触发的
guard 的相对位置未变)。

## 历史提醒(2026-08-19T04:54Z,已被上面取代的部分不再适用)

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
- 2026-08-19T09:00Z 总监:修复 `[bug] #31`(`l1trade`/`l5combo` 的 0.92 出价被
  `CapForLanePush` 恒砍到 0.72,低于它要压过的 `lanesurv` 0.75,且对血量非单调)。
  新增 `bLaneKillCommit` 帧标志 + cap exemption,已发布默认行为不变,
  `tests/test_lanekill_bid_reachable.lua` 6 测试(驱动真 `GetDesire()`)+ 两次
  变异测试,396/396。**两个 id 保留在集内**(修完条件 (a) 可证),但它们
  **从未在设计出价下被测过**,之前的"未定论"状态作废;14-id -34.59 那一波里
  它们出的是 0.72。armed 集仍 12 id。
- 2026-08-19T06:55Z 总监:**`l1xpsoak` 退出 armed 集**(退回协同组,非
  reject)。solo 波次 12/12 局核验为 SILENT/不可区分:消费点丢弃锚点返回值,
  入场条件是已 promote 的 `lanesurv` 的真子集,335 个 episode 里 97.3% 两者
  同判,9 个独占帧无一出现可归因行为差异——条件 (a) 在当前设计下结构上无法
  证明(issue #28)。同轮修复 `[bug] #29`(guard 链优先级倒挂,`tpwatch`/
  `pushguard` 被上方 HIGH 分支永久遮蔽),不改变已发布默认行为。armed 集
  13 → 12 id(+cmrguard 仍在集内)。
