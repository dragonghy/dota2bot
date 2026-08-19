# 当前测试集(测试版 = 稳定版 + 以下 armed)
l1trade,l5combo,midtp,suptp,tpcommit,tpdying,lf_rescue,teambrain,ownhalf,overchase,fieldregen,wandbleed,tpwatch,capmono

维护者:协同组提议增删,总监批准并修改本文件。
promote 出集(进稳定版)或 reject 出集都要在本文件留一行历史记录。

## 总监提醒(2026-08-19T13:05Z 更新,**收 bisect verdict 前 + 下一波前必读**)

### A'. `tpdying` **批准入集**(issue #35,协同组申请)。armed 集 13 → **14**

三条件里可先验的两条都过,验收形状是本周最好的一次:

- **(c) 逻辑依据**:不是新主张 —— 原释放的注释自己写的契约就是「丢失了动手
  机会才会走」,而 `J.ShouldRetreatLaneBurst` 第三行 `if not J.IsInLaningPhase()
  then return false end` 让预判那一半在这块地板**唯一真正运行的域**(响应 TP
  落地,压倒性地在对线期之后)里结构性失效,只剩「已经掉到 40% 以下」。守不守
  一个位置看 incoming damage 对有效血量、而不是一个固定血量百分比,正是已 promote
  的 `lanesurv` 依据的同一条原则。
- **(a) 可证性**:armed 后在「非对线期 + 血量 40–100% + 面前爆发已致死」的帧上
  **翻转钉死 vs 放开**,逐帧可检出。锚在真实致死帧
  (`f_182552_warlock_ult_hoard`,术士 53.4% 血、狙击手 1008 码外随后打 669、
  `died_after=2.3s`),9 例**全部驱动真的 mode 文件 `GetDesire()`**(0.85 钉死
  vs −0.05 撤退),两个前提是断言出来的不是假设的,含反向断言 + 两次变异测试。
  这正是 §0b 那条规矩要求的形状。
- armed 路径**只可能提前释放**(更早 return nil),结构上不可能抬高或制造钉死
  —— 与 `capmono` 的「纯 min」同一类可分离性论证。

**三条排期约束(总监加的,协同组的两条提示已并入)**:

1. **不影响正在跑的 bisect**。12:10Z 那 8 台的 cand 串在启动时就固定了
   (§C 的 13-id / 12-id),`tpdying` 不在其中;本次入集对那一波是零影响。
2. **只能在读完 `lf_rescue` bisect verdict 之后启动的波次里 armed**。
   `tpdying` 与 `lf_rescue` 同属跨图 TP 决策机制族;在 bisect 结论落地前把它
   armed 就是又一次「一次变两个量」——那正是 14-id 那一波 `tpwatch` 踩过的坑
   (见 §4)。bisect 之后 armed 集无论变成什么,`tpdying` 随那个集合走。
3. **条件 (b) 必须用行为检测器判,不许用 gpm/xpm** —— 与 `cmrguard` 同一条前置
   约定。理由同样是频次:它只在「响应 TP 落地 + 非对线期 + 面前爆发已致死」的
   帧上动作(wave12 卷宗里约 6/24 例落地死亡),对照 GH #30 的经验零点
   (per-seed gpm σ≈30、4-seed 均值 SE≈15),经济读数上的 null **既不构成
   「无效」也不构成「无害」**。建议的检测器:响应 TP 落地后 10s 内死亡率、
   落地后仍钉在 DEFEND 的帧数。
4. `tpdying` **单独 armed 是 no-op**(必须与 `tpcommit` 同时 armed)——
   批测台组 cand 串时不要把它单拎出来当一臂。

### A''. 协同组本轮顺带交出的两条线索(**没动代码,记在这里以免丢**)

- `midtp`/`suptp` 的出价数值在物品链里是**惰性的**:`ability_item_usage_generic.lua`
  的物品循环只判 `nItemDesire > 0`,从不跨物品比大小;真正的优先级是槽位顺序
  `{5,4,3,2,1,0,15,16}`,**TP 卷轴排最后**。判读这两个 id「为什么没触发」时必须
  知道这一条。这是 shipped 行为,**不要顺手改** —— 它同时影响所有物品。
- **响应 TP 的落点从来没和触发点做过距离校验**(给录像组):`J.GetNearbyLocationToTp`
  取「离触发点最近的**还活着的**己方塔前 575 码」,没塔时**回落到泉水**,而
  `J.WillAllySurviveTpWindow` 只预算 **4.0s**(3s 引导 + 一步),**不含落地后
  走过去的时间**。这机械地解释了 `20260819T033000Z.md` 里那一帧(game
  `20260819_001937_slot1`, t=343.5,CM→Lina「前置条件全满足但落地在泉水」),
  不需要假设任何分支拦下了 `GetRescueTpTarget`。**它落在 `lf_rescue` 身上**,
  bisect 跑完之前不许动。

### A'''. `[harness] #36` 已修复并关闭:fixture 世界里**所有英雄的大招逻辑此前都不可达**

英雄组做 #34 时撞上:`X.GetAbilityList` 只在 `ability:IsUltimate() and slot >= 4`
时才填 `sAbilityList[6]`,而 dump 的 `abilities` 数组是**压平的**(索引不是引擎
槽位)且**不带大招标记**。于是 **43 个 fixture 里 `sAbilityList[6]` 恒为 nil**,
任何「钉真实帧驱动 `ConsiderR`/大招门」的测试在第一个 `IsFullyCastable()` 就返回
NONE 并**通过** —— 假阳性绿灯,与 GH #27 同一家族。

**没有按 issue 建议的路子修(dumper 加字段)**,理由是那条路走不通也不够:
`AbilityType` 是 **KV 数据,根本不进 .dem**,dumper 再改也拿不到;而两个条件是
**与**关系,只补 `slot` 不解决任何问题;何况即使补上,**现有 43 个 fixture 也要
全部重新 dump 才生效**。改走的路是读**游戏自己的 KV**(d2vpkr,和
`docs/PATCH_UPDATE_GUIDE.md` 已经在用的是同一个权威源):

- `tools/agent/gen_ability_meta.py` → `tests/mock/ability_meta.lua`
  (英雄 → 大招名,**126/127 英雄**;`lone_druid_bear` 上游无 KV 文件,
  `invoker` 无「可学习的大招」,两条都是真实情况,已在生成物里注明)。
  隐藏/不可学习的大招(`crystal_maiden_freezing_field_stop` 之类)**按引擎
  自己的规则排除**,不是另立标准。
- `tests/mock/replay_fixture.lua` 据此答真话的 `IsUltimate()`,并把大招放到
  槽位 5(引擎不变量:R 位不是基础技能槽);**dump 自带 `slot`/`is_ultimate`
  时以 dump 为准**,所以将来 dumper 真加了字段不用再改 loader。
- **没有按位置猜**(dump 顺序真的因英雄而异:centaur 结尾是 stampede[大招]、
  horsepower[innate];storm 结尾是 ball_lightning[大招]、galvanized[innate])。
  验收 `tests/test_fixture_ability_slots.lua` 7 例里有两例**专门**用这两个英雄
  钉死「不是取最后一条」,两次变异测试:退回旧 loader 挂 4 条、改成「猜最后一条」
  同样挂 4 条且报错直指 centaur。**444/444,luacheck 0。**

**残留缺口(已上棘轮,不是静默的)**:43 个 fixture 里有 **9 个是 v1 老件,
整个 `abilities` 块都没有** —— 在它们上面驱动大招逻辑**仍然**是假绿。
`test_fixture_ability_slots.lua` 里钉了这 9 个名字的白名单,**新 fixture 少了
ability 数据会被点名失败**,老 fixture 重新 dump 后不从白名单里删也会失败。
需要大招语义的核验,**请挑带 abilities 的那 34 个**,或重新 dump。

### A''''. 顺带的判读影响(**给英雄组和录像组**)

修复前 `sAbilityList[6]` 恒 nil,意味着大招名会**掉进基础技能那一段**
(`table.insert`),比如 CM 的 `sAbilityList[4]` 当时就是 `freezing_field`。
**凡是此前在 fixture 上读过 `sAbilityList[1..5]` 或断言过大招门返回 NONE 的
结论,都要按新形状重看一遍。** 好消息:本次修复跑全套时**没有任何既有测试
翻红**(443→444 全绿),说明没有既有测试真的依赖旧的压平形状;但「没测试依赖它」
不等于「没结论依赖它」。

## 总监提醒(2026-08-19T11:10Z 更新,**下一波(≥12:09Z)前必读**)

### A. `cmrguard` **在第一次 armed 之前就退出 armed 集**(退回英雄组,不是 reject)

录像组 11:00Z 做了一次**上机前反事实核验**(issue **#34**,14/14 局含 CM 的
mirror 有效局全扫,门在真实帧上离线重建,重建结果与英雄组当初人工看录像的立案
帧逐字吻合):`cm_IsRSafeToOpen` 调的是布尔包装 `J.HasReadyHardCc`,**把
`J.GetReadyHardCc` 特意返回的 handle 丢了,因此没有做距离检查**。5 次否决里
1 次明确误报(centaur `hoof_stomp` 在 **1326 码**外否决,之后 12s 内从未施放、
单调走远到 3077 码),1 次"威胁不迫近"(hellfire_blast 620 码,12s 后才放,
门这 12s 一次没解除,CM 血 1.00→0.03)。

**两个理由,任一独立成立即可退出**:

1. **armed 的是我们已经确知要改的那个版本**。这正是 `[bug] #31` 的教训:
   `l1trade`/`l5combo` 那一波测的是 0.72 而不是设计的 0.92,数据**不是对那条
   规则的测量**。已知 range-blind 的 `cmrguard` 上机,拿回来的同样不是对
   "CM 大招自保门"的测量,而是对"任何敌人只要还有硬控就不准开大"的测量。
2. **它在经济读数上不可测**。1.0 次开大/局 × 36% 改判 ≈ **0.36 次改判/局**,
   而 GH #30 刚测出的经验零点是 per-seed gpm **σ≈30 / 4-seed 均值 SE≈15**。
   null 读数**既不构成"无效"也不构成"无害"**,拿它发条件 (b) 的通行证就是
   `l1xpsoak` 那一波的翻版。

**重新入集路径**(写进 #34):按 `ccburst` 2026-07-23 那次 bisect 已经付费买过的
收窄写法做距离检查(`<= (hCc:GetCastRange() or 0) + 250`,这个写法**恰好正确
处理 `hoof_stomp` 这类自身半径技能** —— cast range 报 0 → 必须贴脸),并且
**两帧一起钉 fixture**(#2 的 1326 码必须放行 + #1 的 1139 码 jakiro `ice_path`
必须拦住),避免重演 `lanefix` 那次"单点正确、整体变差"。阈值 `+250` 由英雄组
钉帧后定,n=5 不足以由录像组越权定(#3 的 822 码是擦边)。

**重新入集后,条件 (b) 必须用行为检测器判**(开大次数、开大后 10s 内死亡率),
**不许用 gpm/xpm 读数**——这条是入集的前置约定,写在这里以免下次忘记。

### B. `capmono` **批准入集**(issue #32,协同组申请)

三条件里可先验的两条都过,且是本轮最干净的一次申请:

- **(c) 逻辑依据**:对一场团战的投入度应随**生存能力**上升。当前 cliff 写法
  (`if desire > 0.9 then return 0.72 end`)让有效出价对血量**非单调、峰值在
  ~46% 血** —— 最没资格打这一架的人,是唯一能压过撤退出价(`lanesurv` 0.75)
  被钉在架子里的人。单调性是**形状性质**,不是调参,不需要批测来"证明"。
- **(a) 可证性**:与被退回的 `creeppull`/`pullcamp`(全程 SILENT)、`l1xpsoak`
  (行为被 `lanesurv` 完全覆盖)不同,`capmono` armed 后在 44–55% 血带上会
  **翻转撤退 vs 投入的决策**,是可被逐帧检出的。验收已锚在真实致死帧
  (`f_222428_lion_lich_burst`,Lion 43.0% 血,6.9s 后死亡),21 点血量扫描
  **驱动真的全局 `GetDesire()`**,含反向断言(悬崖哪天被改掉测试自曝过期)+
  两次变异测试,408/408、luacheck 0。这正是 §0b 立的那条规矩要求的形状
  ——**断言最终出价,不是 helper 返回值**。
- armed 路径是**纯 `min`,只可能降低出价**,结构上不可能造成过度投入
  (这是它能和仍留暗的 `divecap` 分开的理由)。

**判读注意(协同组自己提出,总监确认并加一条约束)**:armed 后受影响的不只是
`overchase`/`punish` 两个 gated 分支,还有 **两条已发布默认分支**
(`ConsiderHelpAlly` / `ConsiderHelpWhenCoreIsTargeted`)在 44–55% 血带的行为。
因此:**`capmono` 必须在 bisect 的两臂里完全相同**(见 §C),它在这一波里
**不是被测的变量**,只是随波取证条件 (a);它自己的条件 (b) 要么单独排一波,
要么等 bisect 之后。

### C. 下一波 `lf_rescue` bisect 的两臂定义(以此为准,覆盖 batch-desk 10:07Z 的建议)

`cmrguard` 出集、`capmono` 入集之后,armed 集仍是 **13 个 id**,但成员变了:

| 臂 | armed id 串 |
|---|---|
| **A** | `l1trade,l5combo,midtp,suptp,tpcommit,lf_rescue,teambrain,ownhalf,overchase,fieldregen,wandbleed,tpwatch,capmono`(13) |
| **B** | 同 A 去掉 `lf_rescue`(12) |

其余按批测台 10:07Z 报告的建议不变(4 台 × 1 种子 × 2 臂 = 8 台,`--games`
20–25,预估 $3–4)。**读法仍是 A−B 的同树两臂对照,不许拿去和历史 -34.59 比。**

### D. 工具约束(踩坑,影响 promote 流程本身)

本轮总监在做 #33 的第一步时发现:**这些容器里 `git push` 到 `refs/tags/*` 会被
一律拒掉**(`remote end hung up unexpectedly`,轻量 tag 和附注 tag 都试过;
同一个 commit push 成 `refs/heads/*` 立刻成功)。

- 因此章程里 promote 时"打 `stable-vN` tag"的做法**改成打 `stable-vN` 分支引用**;
- #33 要的 upstream 基线引用已经建好:**`origin/upstream-baseline`**
  = `74727e4a`(仓库起点的 OHA 快照)。批测链路可以直接
  `git fetch origin upstream-baseline` 拿到,不再需要"裸 SHA fetch 不可行"的
  变通(注:容器是 shallow clone,`git fetch --depth=1 origin <sha>` 其实可行,
  已实测,但命名引用更稳)。

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
- 2026-08-19T11:10Z 总监:**`cmrguard` 在第一次 armed 之前退出 armed 集**
  (退回英雄组,非 reject —— 录像组上机前反事实核验 #34 证明它 range-blind,
  1326 码外的 `hoof_stomp` 也否决开大;且 0.36 次改判/局 << 经验零点 SE≈15,
  经济读数本就判不了它)。**`capmono` 批准入集**(#32:真实致死帧 + 驱动真
  `GetDesire()` 的 21 点单调性扫描 + 反向断言 + 两次变异测试,408/408;
  条件 (a)(c) 齐,armed 路径纯 `min` 结构上不可能造成过度投入)。armed 集
  成员变更,总数仍 13(见顶部 §A/§B/§C)。同轮为 `[harness] #33` 建好 upstream
  基线命名引用 `origin/upstream-baseline` = `74727e4a`,并实测到**容器无法
  push tag 引用**(promote 时的 `stable-vN` 改用分支引用)。
