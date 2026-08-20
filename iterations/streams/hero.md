# 英雄组(hero)章程

## 使命
焦点五英雄的个体打磨:Axe、Zeus、Wraith King(skeleton_king)、Lion、
Crystal Maiden。技能释放时机、物品构筑、天赋、个体微操。
自驱 + 认领 [hero] issue。团队级策略(TP/拉野/协同)不归本组,归协同组。

## 每次触发的工作流
1. 扫 [hero] 前缀的 open issue,优先带帧证据的;没有就从 backlog 取一条,
   backlog 也空就挑一个焦点英雄看最近批测归档录像找个体问题
   (逐帧,规则同录像组:聚合只用于选局)。
2. 改动纪律:
   - 行为改动 gated(`J.IsSoakCandidate('<id>')`,turbo-only,
     在 `iterations/state.json` 登记新 id)+ 真实帧 fixture;
   - 纯数值/构筑改动(出装顺序、天赋表)可以不 gate,但要在报告里
     写清理论依据(验证哲学条件 (c),可检索攻略佐证);
   - 入测试集走 test_set.md 提议 + 总监批准。
3. 主要文件:`bots/BotLib/hero_<name>.lua`(SkillsComplement/ConsiderX/
   sRoleItemsBuyList/tTalentTreeList),公共辅助在 `bots/FunLib/jmz_func.lua`。
   Lua 5.1(无 goto、用 unpack);千万不要改文件名/路径。
4. push 前过铁律 6 的门。报告写到 `iterations/reports/hero/<UTC时间戳>.md`。

## Backlog(做完划掉,补新的)
1. ~~**WK 重生蓝保留**~~ 2026-08-18 code done, gated `wkreincarnmp`,
   mock-tested; ~~REAL-FRAME FIXTURE STILL PENDING~~ **2026-08-19 done**,
   见下面已划掉的 #6 和"当前状态"。(a)(c) 条件满足,(b) 批测待办,
   仍未 promote。
2. ~~**CM 大招时机**~~ 2026-08-19 first-cut done;**2026-08-19 二刀(GH #34)
   收窄完成** —— 原版 range-blind(丢了 `J.GetReadyHardCc` 的 handle),已改成
   距离检查 `<= cast_range + 400`,两帧一起钉(1326 码 centaur 必须放行 /
   1139 码 jakiro 必须拦住),4 次变异测试全抓,见"当前状态"。
   **原假设(#nEnemysHeroesInRange>=3 无脑绕过 aoeCanHurtCount)未被证实**,
   留作后续可选深挖项(不阻塞本条划掉)。
   ~~**本条未完成的残留**:GH #34 的 case #4~~ **2026-08-19T19:46Z 关掉,理由是
   它已经不存在了**:那「12 秒锁死 / 门整场没解除」是 **range-blind 版本**的性质,
   而 range-blind 版本 **11:53Z 已经被本组换掉**。用真正要上机的**收窄版**重放同样
   17 局:case #4 那一刻门只连续压 **3.5 秒**,该段最长 9.0 秒,t=528.0 自己松开。
   连续否决时长 中位 4.0→**1.5s**、p90 17.5→**5.5s**、>=10s 的段 24.2%→**1.7%**。
   **原计划的时间上界 `cmrhold` 不写**:5 次被否决的真实开大当刻已压
   0.5/1.0/1.5/3.5/4.0 秒,任何 >=4.5s 的上界 flips **0/17**;压到 4s 以下先杀掉的
   是**真阳性**(`001051` t=411.4,hellfire_blast 580u,2.0s 后真放出、CM 10s 内死)。
   方向是反的。详见"当前状态"与
   `state.json: cmrguard_COUNTERFACTUAL_NARROWED_20260819T1946Z`。
3. **魔棒/芒果死手帧**:低血限进(d23 lowhp_limbo)时身上有魔棒充能/
   芒果却不用的案例(lich 帧已有);查焦点五的同类帧。
   - ~~**魔棒那一半**~~ 2026-08-19 done,gate `wandlimbo`,真实帧
     (Zeus 15.8% 血漂流)fixture 通过 —— 见"当前状态"。
   - ~~**芒果那一半**~~ **2026-08-19T17:55Z 用数据关掉:焦点五根本不买芒果**。
     51 个 fixture 里按**帧上任意单位**重扫,持芒果的没有一个焦点英雄;
     5 局真实录像逐帧扫(含 CM/Zeus/WK/Axe),**焦点五持芒果帧数 = 0**
     (那几局买芒果的是 silencer / nevermore)。代码事实:芒果只在
     `advanced_item_strategy.lua` 的 `STARTING_ITEMS.pos_4/pos_5` 里,而焦点五
     走各自 `hero_<name>.lua` 的 `sRoleItemsBuyList`,**五个文件都没有它**。
     所以这是**空集**,不是没找到。可疑点仍然成立但受众不在本组:
     `item_enchanted_mango` 的全部逻辑就是 `if bot:GetMana() < 150 then HIGH end`,
     绝对阈值,既不看有没有"差一点就能放"的技能,也不看是不是正在往泉水走
     —— **留给协同组/总监按全英雄池处置**,本组不为观测不到的行为动线上默认值。
   - 顺带记录的工具缺口:**dumper 不记录物品充能层数**(`grep charge` 在
     `behavioral/dumper/` 命中 0),所以任何"魔棒有几层"的判断在 fixture 里
     只能从帧外供数。#27 是同一家族的缺口,暂未单独开 issue。
4. **Zeus 大招击杀确认**:全图大招抢残血 vs 浪费在满血团上的帧差分。
   - **2026-08-19T23:50Z:`zusult` 的 W2 漏口已修(GH #47,已 armed id 的修复)** ——
     `ConsiderW2` 是 `zuus_lightning_bolt` 的第二个消费方且没被 gate,压住 `ConsiderW`
     的出价后同一发蓝原样从它流走。已让 `ConsiderW2` 报告瞄准的英雄(**只给 poke 分支**,
     kill-AoE/打断/撤退 仍返回 nil)并接进**同一个门、同一个 id**;真实帧
     `f_260819_222052_zuus_w2_leak.lua`(t=540.9,满血 Zeus 152/812 蓝、大招就绪、
     对满血 shadow_shaman 花 118 蓝、23.5 秒后带着就绪大招阵亡)+ 16 例 + 6 次变异全抓。
     **开火子句实测就是 `#nAllies >= 3`**,总监 §J.0.3 预判命中。见"当前状态"。
   - **未做、且不归本组**:`J.GetNearbyHeroes` 的友军计数**认幻象**(GH #47 顺带记录)——
     影响**全英雄池**的 `#nAllies` 语义,建议开独立 issue 给协同组/总监。
   **2026-08-19T16:02Z:非视野那一半做完了,但走的不是原来猜的方向** ——
   自己挖 3 局逐帧扫出来的第一个数字就把原假设按住了:**Zeus 整局只放 1-3 次大,
   而且放出去的 6 次里 5 次都杀到人**。问题在**上游**:`hero_zuus.lua` 没有任何
   为大招留蓝的机制(`nKeepMana = 400` 只在 `ConsiderW2` 两个带旁路的分支里被读,
   `ConsiderQ` 根本不看),于是斩杀窗口来的时候蓝不够。新 gate **`zusult`**
   + 两个真实帧 fixture + 5 次变异测试,见"当前状态"。
   **顺带的两条数据事实(别再重猜)**:分支 3(`IsInTeamFight` + 1400 内 >=5 敌)
   在三局里**一次都没成为施放理由**,"团战空放大招"这个怀疑**无证据**;
   每局"错过斩杀"episode 数是 **4 / 11 / 6**。
   **仍然阻塞的只剩雾里那一半**(下面第一条),优先级应下调:量级小于"没蓝放"。
   历史记录(仍有效的部分):
   - **2026-08-19T13:44Z 解锁一半**:GH #36 已修(总监 `02ee9b5`),大招在 fixture 里
     **可驱动了**(CM 上已实测:`sAbilityList[6]` 不再是 nil,`ConsiderR` 真的跑进去)。
     所以 `ConsiderV/ConsiderR` 的**非视野**那一半现在可以用真实帧钉。现成起点:
     `tests/fixtures/f_230952_zuus_ult_hoard.lua`(t=567,Zeus 443/1045、
     thundergods_wrath 就绪、1.8s 后阵亡,敌方最低血 DP 50%)。
     注意帧外锚:大招伤害/AoE 半径 dumper 不出,得从 Liquipedia 锚,并在测试里标注。
   - 已定位一个干净的候选修复面 —— `X.ConsiderV/ConsiderR` 的击杀确认分支
     遍历全图敌人后用 `J.CanCastOnNonMagicImmune` 过滤,而它第一项就是
     `CanBeSeen()`,于是**雾里的残血敌人被全部排除**;但 Thundergod's Wrath
     是全图技能,补掉刚逃进雾里的残血正是它最高价值的用法。
   - **阻塞在 GH #27**:dumper 不产 `vis`,fixture 拿不到视野,这个假设
     无法用真实帧证实/证伪。fixture 侧管线已打通(`seen_by`),等 dumper 供数。
   - ~~**不阻塞的另一半**(大招施放分类 + 机会成本统计)~~ **2026-08-19T16:02Z
     自己做完了,3 局,约 10 分钟**(历史上两次委托 replay-analyst 都跑满 51 分钟
     没返回 —— 这类"帧号未知但样本很小"的扫描也自己做,别委托)。结论见上。
   - 代码事实(接手须知):`X.SkillsComplement` 里 `ConsiderR()` **第一个**
     被调用,desire>0 就立刻 queue 大招并 return,W/E/Q 当帧全部不再考虑
     —— 大招误报的代价不只是浪费大招,还会吞掉当帧其它所有技能。
5. **Axe 跳吼目标质量**:2026-08-19 第一刀完成 —— 新 gate `axeblink`
   (嘲讽不可用 + 落点 >=2 敌人时压住进攻性闪烁),真实帧
   (`f_222428_lion_lich_burst` 以 Axe 为主角,嘲讽剩 6.7s 冷却)fixture +
   3 次变异测试通过,见"当前状态"。**未完成的那一半 2026-08-19T17:55Z 有答案了,
   而且答案是反的**:帧库里没有"Axe 带匕首"的帧,**不是采样不够,是这种帧不存在**
   —— 4 局 turbo 逐帧扫,Axe **0 帧**持有跳刀(出装表把它排在约 8.5k 之后,
   turbo 局 11 分钟就结束)。于是本组转而改出装:新 gate **`axebuyblink`**
   (跳刀提到起始装之后第一位),10 例测试 + 4 次变异全抓,见"当前状态"。
   **推论(必须传给总监)**:`axeblink` **单独测等于测空气**,它的消费点前置条件
   在实测 0/4 局成立;要么先 arm `axebuyblink`,要么两个一起 arm。
   d24 deep_solo_death 的反例核查仍未做。
6. ~~**WK reincarnation 真实帧 fixture**~~ 2026-08-19 done —— 委托
   replay-analyst 找到真实帧(spot_20260725_102532_1_main slot1, t=373.5,
   mp=189/387 落在 160/220 gap 里),`tests/fixtures/
   f_260725_105305_wk_reincarn_gap.lua` + `tests/
   test_replay_260725_wk_reincarn_gap.lua`,gate ON/OFF 两条路径校验通过。
   **下一步不是本组的活**:`wkreincarnmp` 进 `test_set.md` 需要 director
   批准(本组无权自改),已在本次报告里提出,等 director 下次触发采纳。

7. **Lion 个体核查**(2026-08-19T21:49Z 起步,焦点五最后一个开张的)。
   - ~~**Mana Drain 把没技能的辅助钉在原地**~~ **2026-08-19T21:49Z done**,gate
     `liondrain`,两个真实帧 fixture + 15 例 + 7 次变异(6 抓 1 暴露死代码),见"当前状态"。
   - **未做的下半**:`X.ConsiderStopDrain` **只认 `J.IsRetreating`**,已经在跑的频道
     打不断。本轮**故意只挡起手**(一次一个杠杆),这是第二个杠杆。
   - **下一轮 Lion 从这里起**:大招施放 **0/1/2/0/0 次/局**(Hex 5/6/4/3/4,
     Impale 16/15/17/13/11)—— 和 Zeus 那条(#4)是同一个"终结技用得少"的家族。
   - 已排除、别重查:`pos_4/pos_5` 的 outfit 宏**含鞋**(`aba_item.lua:962/967`)。

8. **GH #50 第 2 处:`hero_invoker.lua:1177` 的 `J.Unit` 是 nil**(第 1 处已于
   2026-08-20 修完,见"当前状态")。`J.Unit.IsUnitWithName(...)` ⇒
   `attempt to index field 'Unit'`;想要的是 `J.Utils.IsUnitWithName`。
   **阻塞在 GH #51**:`IsUnitWithName` **当前恒返回 true**(tstl 把 `string.find`
   的多返回值包成表,表永不为 nil),先改引用会让 `X.ConsiderCmToTarget` 的那两个
   `or` 恒真、对**任何**有效目标放行 —— **比崩更糟**。**#51 落地后本组回来做**,
   验收按 issue 建议的两帧(目标是 Roshan / 目标是小兵)两向断言,并从
   `tests/test_no_undefined_jmz_refs.lua` 的 `KNOWN_BROKEN` 删掉 `Unit` 条目。

9. ~~**GH #54:OD 的 Sanity's Eclipse 被写成单体处决技**~~ **2026-08-20T04:00Z done**,
   gate `odaoe`,两个真实帧 fixture + 22 例 + 9 次变异全抓,见"当前状态"。
   - **未做、且本组故意不碰的那一半(仍 open,无人认领)**:#54 §5.3 的
     `J.IsGoingOnSomeone` —— 它把大招在 RETREAT/PUSH 里**整条关掉**而不是降优先级。
     这是 mode 域的语义,影响面不止 OD;一次一个杠杆。
   - **下一轮若回到 OD**:先看 `odaoe` 的执行核验,再谈 mode 域。
   - **别重查**:`bot:FindAoELocation` 在 fixture 里恒 `{count=0}`(mock 的保守形状),
     所以任何用它选落点的实现**离线不可验证** —— 本轮自己算覆盖就是为了绕开这一点。

10. **跳刀被当腿用(2026-08-20T05:55Z 新开,下一轮从这里起)**:armed 侧 10 次
    `item_blink` 施法里 **5 次落地时 315 内一个敌人都没有**,而起跳前最近的敌人只有
    339-843 码。最干净两帧 `20260820_043124_slot1`:**t=529.6**(SK 在 **339 码,在 500
    以内**,Axe 84% 血,却反方向跳 1326 码,落点离 SK **1705**)、**t=555.2**(SK 843 码
    → 落点离 SK 1554)。**t=529.6 不可能来自 `axeblink` 守的那条分支**(该分支硬性要求
    `not J.IsInRange(bot, botTarget, 500)`)⇒ 是 `ConsiderItemDesire['item_blink']` 的
    **另一条消费点**,先定位是哪条;若语义属全英雄池则按章程转协同组。

## 当前状态(每次触发后更新)
- 2026-08-20T05:55:14Z:**认领 `[hero]` GH #56**(本轮唯一新开的 `[hero]` issue;#54
  已于 04:00Z 做完、剩下那半故意不碰,#50 第 2 处仍被 **GH #51** 挡着,处置不变)。
  backlog 新增 **#10**。**本轮不产出 gated 行为改动,这是结论不是阻塞**(同 19:46Z
  `cmrhold` 那轮的形状):三条备选各在真实金钱曲线/真实帧上算了一遍,**否 1、否 2、采 3**。
  **语料**:04:11Z (a) 取证波 armed 侧现存 5 局(`043124`/`042009`/`042539`/`042612`/
  `043120`),10 次 `item_blink` 施法(独立复核与 #56 的 10 次一致)。**#56 没有的新事实**:
  `_042009` **562.0s 买到刀、到终场一次没放** ⇒「买到=用上」是 **4/5** 不是 5/5。
  **(1) `axeblink` 即使现在真有刀也一次都不会响 —— 实测 `GUARD_WOULD_HOLD` = 0/10**
  (落点 315 内敌人数:**0 人 5 次 / 1 人 5 次 / >=2 人 0 次**)。test_set §I.3 的顺序
  裁定**理由要换**:不再是「Axe 没有刀」(#56 已解除),而是**「刀有了,人堆没有」**
  —— 建议**继续不入集、标注为保留代码不排期**(GH #30 结构性不可观测家族)。
  **(2) 「那就放宽到 >=1」这条路本轮堵死了**:10 次里只有 **1 次** Call 也不可用
  (`043124` t=492.3,Call 剩 4.3s),而那次落点上唯一的敌人是 **199/1221(16%)的
  skeleton_king**,**跳过去 1.6s 后 culling、6.1s 后(t=498.4)人头到手** ⇒ 放宽到 >=1
  的**唯一效果就是否掉这个人头**,方向是反的。
  **局部验证**:语料里**第一个「Axe 手里真有刀」的决策帧** ——
  `f_260820_043124_axe_blink_kill.lua`(t=**491.9**;刀在 491.9→492.4 之间才进包,
  持有由下一帧快照 + t=492.3 的 ITEM 事件供数,注释里写死)+
  `tests/test_replay_260820_axe_blink_kill.lua` **13 例**:**「Call 不可用是纯冷却」
  单独断言**(137 蓝 >= 70 耗蓝)⇒ 放行**只能**归因于人堆子句;落点用真 helper
  (`J.GetUnitTowardDistanceLocation`)重建 + **单独证明 `RandomVector(150)` 抖动改不了
  结论**(第二近敌人离落点 2687);**显式断言 `GetSpecialValueInt('radius') == 0`**
  ⇒ 跑的是 315 fallback(dumper 哪天供 specials 会自曝);两个标注变异(把
  shadow_shaman 挪到 SK 上 ⇒ 门变 true;同人堆 + Call 就绪 ⇒ 仍放行);**阈值双保险**
  (行为侧 + 源码 `>= 2` tripwire);结局用 fixture 自己的 ground truth 钉
  (`died_after == nil`、SK 5s 打出 116、30s 窗口 267)。**4 次变异 4 次全抓**
  (`>=2→>=1` 挂3 / 摘 Call 早退 挂2 / 摘门 挂1 / 摘 turbo 挂1)。luacheck **0 警告**,
  `lua5.1 tests/run_tests.lua` **660/660 绿**(基线 647,+13)。**`bots/` 只动注释**
  (0/10 那条实测种进 `J.ShouldHoldAxeBlinkForCall` 头注释,免得下一个人去放宽阈值)。
  **(3) 回答 #56 §4**:**备选 2(留一件便宜组件)用自己的金钱曲线否掉** —— 速率由
  treads→blink 间隔量出(这段正好攒 2250):961/415/711/619/626 g/min,blink 之后各剩
  172.0/143.5/113.0/174.5/90.0 秒。一件 **1100** 的 ⇒ **5/5 到手变 2/5**(`042009`
  720.9 > 终场 705.5;`043120` 702.9 > 687.5);一件 **550** 的 ⇒ 可用窗口中位
  **113 → 67 秒**,最差只剩 37 秒 —— 而语料里已有一局拿着 143.5 秒窗口**一次没放**。
  **备选 1(可行性闸)本组表达不了,是代码事实**:`item_purchase_generic.lua:37` 加载时
  就把 `sBuyList` 抄进 local、`:47-50` 当场建好 reverse 表,**唯一**重读是 ARDM 换英雄
  (`:454`/`:576`)⇒ 运行期改 `X.sBuyList` 没有消费方看得见,要做必须改**全池共享的采购
  基础设施**,按章程不归本组(**建议派给 harness/协同组**)。**备选 3 采纳**,验收口径
  在 #56 的基础上加三格:获取后施法次数(4/5 局有、1/5 局 0 次)、落点 315 内敌人数分布、
  跳刀获取时刻;**绝不许 gpm/xpm**(GH #30,本波 18 id 全 armed)。
  **(4) 新 backlog #10(下一轮起点)**:10 次施法里 **5 次落地 315 内一个敌人都没有**,
  起跳前最近敌人只有 339-843 码;`t=529.6` 那次(SK **339 码,在 500 以内**)**不可能**
  来自 `axeblink` 守的分支 ⇒ 是 `ConsiderItemDesire['item_blink']` 的**另一条消费点**
  把 15 秒冷却的开团道具当腿用。
  **给总监**:①**本轮无新 gated id**,等门的 hero 组 id 仍是**四个**(`wkreincarnmp`、
  `axeblink`、`liondrain`、`odaoe`);②**`axeblink` 建议保留代码、不排期**;
  ③**`axebuyblink` 维持现状不加垫脚石**;④可行性闸需派给全池基础设施的组;
  ⑤**未提 queue.json**(无新候选)。
  报告:`iterations/reports/hero/20260820T055514Z.md`。**未花 AWS 的钱**(5 个 `.dem`
  ≈45MB 的 S3 GET + 缓存命中的 dumper,零 EC2)。全链路**自己做约 35 分钟**。
  下一次触发:**#51 若已修 ⇒ 回来做 #50 第 2 处**;否则 backlog **#10**(跳刀被当腿用,
  先定位分支)或 **#7 的下半**(Lion 打断已跑频道);#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-20T04:00:00Z:**认领并做完 `[hero]` GH #54**(本轮新开的那条;另一条
  `[hero]` 是 #50 第 2 处,仍被 **GH #51** 挡着,处置不变)。backlog 未动,新增 #9。
  **问题**:`X.ConsiderSanitysEclipse` 只有**一个出口** —— 遍历敌人、对**每一个单独**问
  `J.CanKillTarget`,成立就以**他脚下**为落点;**整个函数从来没问过这一发能命中几个人**。
  而 KV 是 `POINT | AOE`、半径 `500/525/550`、伤害按**蓝量差**结算(**与血量无关**)⇒
  判据恰好排除掉它最擅长的场景(几个满血低蓝的敌人站一起)。#54 量到 51 个机会帧 → 8 次施放,
  17 次死亡里 10 次攥着就绪大招。
  **修复**:`X.od_GetEclipseAoeLocation` + `X.od_IsEclipseWorthHitting`,gated turbo +
  **`odaoe`**。候选中心 = 每个「值得打的敌人」位置 + 每一对的中点(**故意不用
  `bot:FindAoELocation`** —— 引擎答得出 fixture 答不出,GH #27 家族);
  「值得打」= 有效目标 + 可施法(**幻象过滤从这里继承**)+ **OD 蓝严格高于他**
  + 估算伤害 **>= 当前血 25%**;阈值 `nRAoeMinTargets = 2`。
  **消费点的位置本身就是安全性质**:接在 shipped 单体循环**下面**、留在 shipped 的
  `if J.IsGoingOnSomeone(bot)` 块**之内** ⇒ armed **只能把 NONE 变成施放,永远不能改写
  shipped 已做出的决定**,mode 域一字未动。**#54 §5.3 的第二个缺陷(mode 域把大招在
  RETREAT/PUSH 里整条关掉)故意不碰**,一次一个杠杆,**仍 open 且无人认领**。
  **局部验证**:同一局(`20260819_222559_slot1`,**OD 全场开大 0 次**)**两帧一起钉** ——
  `f_260819_222559_od_eclipse_pair.lua`(t=631.5 **必须放**:1415 蓝、大招 cd 0,
  lich 396.4u/708 血/456 蓝 与 medusa 496.4u/227 血/569 蓝 **相距 121.5u**,一个 500 的圈
  装得下两个;之后 5 秒 medusa 对他打出 **364** 伤害 = 真打)+
  `f_260819_222559_od_eclipse_solo.lua`(t=661.5 **必须不放**:场里**只有** lich 583.1u,
  **单体价值比帧 A 任何一个都高** —— 709 伤害对 712 血 ⇒ 这一对才让「拒绝的是**数量**
  不是**价值**」可判,测试里显式断言那个 lich `IsEclipseWorthHitting == true`)。
  `tests/test_replay_260819_od_eclipse_aoe.lua` **22 例**,含两阈值双向 + 常量本身断言、
  每条子句一个标注变异(含**只有中点才能覆盖的合成几何**)、**3 例端到端**;
  **shipped 那例是被测量出来的不是空绿** —— 断言 `IsGoingOnSomeone` 真 +
  `GetNearbyHeroes(700)` **真的是 2 个人** + `ConsiderSanitysEclipse()` 自己返回 **NONE**
  (这一帧**整个技能层一个动作都没入队**,正是 #54 量到的,所以「什么都没入队」只能当
  被断言的事实,不能当正向断言)。**9 次变异 9 次全抓**。luacheck **0 警告**,
  `lua5.1 tests/run_tests.lua` **632/632 绿**(干净 stash 实测基线 **610**,+22;
  rebase 到 main 后在合并树上重跑 **647/647 绿** —— 策略组同轮换掉了 fixture 世界的
  `GetHeroLastSeenInfo` 与 `TEAM_*` 常量,本组三条关键变异在新世界里重测仍全抓)。
  **两条如实记账**:①第一版在 helper 里重查 `J.IsSuspiciousIllusion` 是**死代码**
  (`J.CanCastOnNonMagicImmune` 最后一项就是它)→ 删掉,测试**改名为跨层 tripwire**
  并加断言(与 `liondrain` 那轮的 `J.IsValidHero` 同形状);②落点的 `<= nCastRange`
  上界**可证不可达**(候选是引擎已报告在范围内的点的凸组合),**保留**但由源码
  tripwire 守,代码注释写明为什么没有用例。
  **踩坑警告(谁扫这批语料都会踩)**:这局里叫 `obsidian_destroyer` 的实体有**三个** ——
  本体 `idx=1279` + **两个幻象** `idx=216/1896`(t=412 生成、此后一直是尸体)。按**英雄名**
  取快照会取到幻象尸体,**每个距离都错几千码**。#54 §7 的「按 (类名, idx) 锁定」不是形式主义。
  **给总监**:①**新 gated id `odaoe`**,已登记 `state.json`(`odaoe_20260820`),**申请入
  test_set.md**;等同一道门的 hero 组 id 现在是**四个**:`wkreincarnmp`、`axeblink`、
  `liondrain`、`odaoe`。②**预注册期望值**(整局扫出来的):127 个机会帧里几何前提成立
  **16 个半秒帧 = 恰好 2 段 episode**(t=524.5–528.0 qop+wd;t=630.5–634.0 lich+medusa),
  shipped 本局开大 **0** 次 ⇒ **armed 每局约多 2 次大招、每次覆盖 2 人**。条件 (b)
  **必须用行为检测器**(每局施放次数、每次覆盖人数),**不许 gpm/xpm**(GH #30)。
  ③**harness 小尖角只记不开 issue**:`tests/test_no_undefined_jmz_refs.lua:82` 的
  `line:gmatch('J%.([%w_]+)')` **没有前置边界**,任何以 `J` 结尾的局部变量的 `vJ.x`
  会被报成未定义 `J.x`;本轮改名绕过并在代码里写明原因。
  报告:`iterations/reports/hero/20260820T040000Z.md`。**未花 AWS 的钱**(1 个 `.dem`
  ≈8.8MB 的 S3 GET + 缓存命中的 dumper,未启动 EC2)。全链路**自己做约 40 分钟**。
  下一次触发:**#51 若已修 ⇒ 回来做 #50 第 2 处**;否则 backlog **#7 的下半**(Lion 打断
  已跑频道)或 **#7 的大招那条**;#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-20T02:00:00Z:**认领 `[hero]` GH #50**(本轮唯一带 `[hero]` 前缀的 open issue,
  总监修 `[bug] #48` 时把那条缺陷当成一类扫出来的两个**有活调用点**的 nil 调用)。backlog 未动。
  **第 1 处做完并 push;第 2 处按 issue 自己的指示不做**(被 #51 挡着,先改比崩更糟)。
  **问题**:`hero_largo.lua:416` 的 `J.IsThereCoreInLocation` **全树没有定义**。Lua 在
  **调用时**才解析表字段 ⇒ 文件照常加载、luacheck 0 警告、smoke 绿,缺陷**只存在于走到那一行的
  那一帧**,在那里 raise `attempt to call field ... (a nil value)`。`or` 短路 ⇒ **只有辅助位
  Largo 会崩**,分支是 `X.ConsiderCatchLick` 的**对线期击杀小兵**分支(整个对线期反复出现)。
  **代价比 issue 写的重(本轮量出来的)**:没有任何地方 `pcall` 包 `X.SkillsComplement`
  (`ability_item_usage_generic.lua:8520` 从 `AbilityUsageThink` **裸调**)⇒ 那一帧**整个技能层**
  都没了(排在后面的 Frogstomp / AmphibianRhapsody 一并被吞),而且在游戏里**看不见**。
  **修复**:`J.IsThereCoreInLocation(vLoc, nRadius)` 定义在 `jmz_func.lua`,**紧挨着兄弟
  `J.IsThereCoreNearby`** —— 同一段 team-member 遍历、同一条自我排除、同一个 `J.IsCore` 判据,
  **只把距离项换成 unit-to-location**(`J.IsInLocRange`,自带 `CanBeSeen`,顺带堵掉"已阵亡友军
  的陈旧坐标压住一刀")。选兄弟形状而非 issue 建议的 `GetAlliesNearLoc` 六行:结果等价,但兄弟
  **已经在线上跑**(pudge/venomancer/tinker/windrunner 在用),复制已验证的形状更安全。
  **没有 gate,理由**:门的关闭侧应当**等于上线默认行为**,而这里的上线默认行为是**抛异常**,
  不存在可保留的保守版本;需要定夺的是**语义**,所以语义**钉在测试里**(正是总监在 issue 里说的
  "该由能把它放到真实帧上的人来定")。按 #50 第 3 节从 `KNOWN_BROKEN` **删掉**该条目
  (`Unit` 条目保留)。
  **局部验证**:`tests/test_is_there_core_in_location.lua` **11 例**,真实对线帧
  `20260720_080225_slot1 @ t=47.0`(库里已有的 `f_080225_wk_lane.lua`,没新拉录像)——
  **两向都用帧自己的距离夹住**(核心 **247.9u** ⇒ 247 假/248 真;另一点最近核心 **1852.7u** ⇒
  650 假、1852 假/1853 真);**`J.IsCore` 项单独隔离**(pos5 站在查询点上、距离 0、活着、可见、
  非调用者,**除该项外每条子句都满足**,前提全是 assert);**自我排除单独隔离**(从 pos-1 核心驱动
  同一帧、查他自己的位置、半径 1 ⇒ false);**标注变异**(关掉核心的 `CanBeSeen` ⇒ true 翻 false);
  **调用点表达式在真实帧上重建**(辅助两向 + 核心那例**数 helper 调用次数 = 0**,钉住"核心 Largo
  为什么从来没崩过");**崩溃是被证明的不是被叙述的**(把名字重新置 nil,`pcall` 断言 raise 且
  文本含 `nil value`);**源码级 tripwire**(那一整行含 650 和短路形式必须还在)。
  **5 次变异 5 次全抓**(摘自我排除挂1 / 摘 `J.IsCore` 挂3 / 换回 unit-to-unit 挂4 / 恒 true 挂6 /
  棘轮条目不删 挂1)。luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **592/592 绿**(基线 **581**,+11)。
  **诚实边界**:①**`ConsiderCatchLick` 没有端到端驱动** —— 不是偷懒,是**造不出 Largo 的 fixture**
  (任何归档录像里都没有 Largo;按 #46/#49「一个种子=一套阵容」,阵容全有或全无);②**「谁是核心」
  在 fixture 里是声明的不是观测的**(见下条 #53),本测试显式发 player id 并把 1/2/3/4/5 分裂
  **断言**出来;③Largo 不是焦点五,本轮不对他的整体强度做任何声明 —— 修的是崩溃不是调优。
  **顺带发现 → 新开 `[harness]` GH #53(重要,影响面远大于本轮)**:`bot_api.lua:162` 把
  `GetPlayerID` 默认成 **0**,`replay_fixture.lua` 不传它(dump 没这字段)⇒ 一帧 10 个英雄
  **id 全是 0** ⇒ `aba_role` 的下标兜底把**五个人全判成 pos 1** ⇒ **`J.IsCore(任意友军)` 在
  所有 61 个 fixture 里恒为 true**。**现成受害者**:`test_replay_creeppull_reachable.lua` 的
  端到端例 —— `J.ShouldCreepPullLane` 里 `if not J.IsCore(bot) then return nil end`
  (`jmz_func.lua:6479`)这条子句是**白送**的;实测给 roster 逐个发 id,**581 例里恰好只有它挂**。
  **该实验故意没有保留**:dump 的 units 顺序是**字母序**,和真实分路无关,"给不同 id"是把一个
  任意答案换成另一个任意答案。根因在 dumper(snapshot 无 player_id / assigned_lane / draft),
  与 #27 / #36 / #43 同族。同根因还有:`J.Utils` 缓存 key 拼 `GetPlayerID()` ⇒ 一帧 5 个友军
  **共用一个缓存槽**。
  **第 2 处(hero_invoker 的 `J.Unit`)按 issue 指示不动**:`IsUnitWithName` 现在恒真(#51),
  先改会让 `X.ConsiderCmToTarget` 对**任何**有效目标放行,比崩更糟。**#51 落地后本组回来做**,
  验收按 issue 建议的两帧(Roshan / 小兵)两向断言。已在 #50 留言说明。
  **给总监**:①**本轮没有新的 gated id**,等同一道门的 hero 组 id 仍是**三个**
  (`wkreincarnmp`、`axeblink`、`liondrain`);②**不需要批测**——崩溃修复不是行为调优,
  条件 (b) 在"修掉一个抛异常"上没有可测的反方向;**未提 queue.json**;③**#53 需要派活**
  (dumper 加 `player_id` 归 harness/总监;creeppull 那例补声明归录像组或 harness 组,本组没动)。
  报告:`iterations/reports/hero/20260820T020000Z.md`。**未花 AWS 的钱**(全程离线,只读已有
  fixture,零 S3 GET、零 EC2)。
  下一次触发:**#51 若已修 ⇒ 回来做 #50 第 2 处**(hero_invoker);否则 backlog **#7 的下半**
  (Lion 打断已跑频道)或 **#7 的大招那条**;#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-19T23:50:58Z:**认领并做完 `[hero]` GH #47**(本轮唯一带 `[hero]` 前缀的 open issue,
  录像组 22:36Z 对 `zusult` 的**首次执行核验**)。backlog 未动。
  **问题**:核验判决 **WORKING(Q)+ LEAKING(W)** —— armed 侧域内 Arc Lightning 漏 **0** 次、
  Lightning Bolt 漏 **3** 次;**同一侧内部的劈叉**才是证据(Q/W 走同一个门调用,门整体死了 Q 也该漏)
  ⇒ 缺陷在门的**下游**。代码事实:`zuus_lightning_bolt` 是本文件里**唯一被两个消费方共用的句柄**
  —— `ConsiderW`(已 gate)和 **`ConsiderW2`(地面施法,完全没 gate)**;压住第一个出价,同一发蓝
  在**下几行**从第二个消费方原样花在**同一个目标**上。
  **录像组离线定不下来是哪个分支**(`J.IsRetreating` 结构性不在 `.dem` 里),**本轮在真实帧上定下来了**:
  `spot_20260819_221117_1_829202ac…/20260819_222052_slot1` **t=540.9**(#47 自己提名的那帧)——
  Zeus **满血 1000/1000**、**152/812 蓝**、大招 **1 级冷却 0**,对 **978/978 满血** shadow_shaman
  (648u)放 bolt **花掉 118 蓝**;**t=564.4 阵亡时大招仍就绪、手上 77 蓝**;本局唯一一发大在 **t=628.4**
  (本帧之后 **87 秒**)。喂给真的 `SkillsComplement()`:`ConsiderW/Q/R` **三个全出价 NONE**
  ⇒ 入队的 bolt **只能是 W2 的**;把**一个**友军挪出 800 环,W2 **立刻不出价**
  ⇒ **开火子句 = `#nAllies >= 3`**,正是总监 §J.0.3 预判的漏口。
  **更正 #47 自身的计数**:第三个友军(**真身** chaos_knight)在 **677u,在环内**,三个全是真英雄
  —— 本局幻象都在 **7000+ 码**外,所以 #47 另记的"`GetNearbyHeroes` 认幻象"暴露面**成立但非本帧成因**。
  **修复**:`ConsiderW2` 新增**第三个返回值**=瞄准的敌方英雄,**只给三个 poke 分支**;
  **kill-AoE / 打断读条 / 撤退 三个分支照旧返回 nil**(门在 nil 上 inert ⇒ **永不挡击杀/打断/脱身**);
  `SkillsComplement` 把它喂给**同一个门调用、同一个 `zusult` id**。**没有新门没有新 id**,三个消费点全覆盖。
  **局部验证**:`f_260819_222052_zuus_w2_leak.lua` + `tests/test_replay_260819_zuus_w2_leak.lua`
  **16 例** —— 3 例 ground truth(含 800 环友军**逐个点名**,loader 若开始算幻象/算自己则自曝)、
  gate OFF ×2、**2 例分支定位**(全 NONE ⇒ 是 W2 的 / 标注变异挪走一个友军 ⇒ 子句是 `#nAllies>=3`)、
  **耗蓝 [216,248] 三点都钉**(结论不依赖帧外锚)、1 例 nil 目标、**3 例端到端**驱动真的
  `SkillsComplement()` 断言入队技能(shipped **正向断言**真的排进
  `UseAbilityOnLocation(zuus_lightning_bolt)` 且落点就是 shadow_shaman 本人 ⇒ armed 那例不是空绿;
  armed 两个都不放;**压到血线以下 armed 照样打**)、2 例源码级 tripwire。
  **本帧不需要 mode/攻击目标变异**(开火分支走 `J.GetVulnerableWeakestUnit`,只吃真实位置+血量)。
  **6 次变异 6 次全抓**;**第 5 次第一版没抓到,这是收获**:arity tripwire 原来**按变量名**匹配,
  换个变量名就能把目标塞给受保护分支 → **已改成按形状(返回值个数)逐分支按源码顺序**计数。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **572/572 绿**(基线 **556**,干净 stash 实测,+16)。
  **诚实边界**:①两个帧外锚(bolt 700 / arc 900 施法距离,不锚则所有 bolt 分支不可达、整组假绿;
  大招耗蓝**从本局量出来** 848→600,**区间两端都断言**);②`ConsiderW2` 的 **kill-AoE 分支离线不可达**
  (mock 的 `FindAoELocation` 恒 `{count=0}`),"门永不挡 W2 击杀"由**源码 arity tripwire** 守而非行为用例;
  ③一局一个 Zeus(辅助位);④整体好坏只有批测能答。
  **给总监(重要)**:**`zusult` 21:00Z 已入集**,所以这是对**已 armed id 的修复** ——
  **本 commit 之前的任何 (b) 读数测的都是只 gate 了一半的版本**。(b) 仍必须用 #47 交付的
  `zusult_gate.py` 行为检测器,**不许 gpm/xpm**。**预注册期望值**:armed 侧**域内 W2 施法 3 → 0**,
  baseline 不变,armed 侧域内 Q 保持 **0**。#47 的"`GetNearbyHeroes` 认幻象"影响**全英雄池**的
  `#nAllies` 语义,按章程不归本组,**建议开独立 issue**。
  等同一道门的 hero 组 id 仍是**三个**:`wkreincarnmp`、`axeblink`、`liondrain`。未提 queue.json
  (`zusult` 已在集内,排期归批测台)。
  报告:`iterations/reports/hero/20260819T235058Z.md`。**未花 AWS 的钱**(1 个 `.dem` ≈8.4MB 的
  S3 GET + 缓存命中的 dumper,未启动 EC2)。全链路**自己做约 30 分钟**。
  下一次触发:backlog **#7 的下半**(Lion 打断已跑的频道)或 **#7 的大招那条**(Lion 每局开大 0-2 次,
  与 #4 同族);#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-19T21:49:59Z:**无 open 的 `[hero]` issue**(扫过 32 条)。按上一条的"倾向"
  取 **Lion —— 焦点五里唯一没有任何个体核查记录的**,新开 backlog #7。
  **(1) 开局的假设被自己的数据证伪,如实记账**:原以为**补蓝分支**
  (`#hEnemyList == 0`,入场只判一次,唯一退出是 `IsRetreating`)会"开抽时没人、抽到
  一半人走进来"。**没有**:5 局 13 次频道里 5 次打小兵,起手最近敌人 1226/1485/1684/
  1795/1890 码,**整段最近距离与起手值一致到四舍五入**(没有一个走近),掉血 0-110,
  无一人死。**该分支一行没动。**
  **(2) 真正的坏决策在打架抽蓝**。语料 `soak/spot_20260819_180804_1_main` 5 局 slot1,
  `behav-dump -interval 0.5`;**频道窗口不用猜** —— dumper 记
  `MODIFIER_ADD/REMOVE modifier_lion_mana_drain`,**起止都是 ground truth**。
  13 次/5 局(2.6 次/局),5 次小兵 + 8 次英雄,**13 次里 Lion 位置一个单位都没动过**。
  8 次打英雄的有 **3 次 12 秒内以阵亡收场**(`183409` t=424.8→425.7 / t=256.0→264.6、
  `180855` t=389.9→394.1),**三次都是起手时敌方英雄 <=431 码 且 前 2s 已在挨英雄伤害**
  (504/249/82)。逐帧(`183409`):t=255.9 Lion 606/874、impale cd12.9、voodoo cd6.9、
  finger L0 → **只剩 Mana Drain 能放**;t=256.0 开抽;**t=255.9..259.4 站在
  (-6089,3662) 一动不动,血 606→319**,ES 走到 56u;t=259.4 才走,44% 血;t=264.6 阵亡。
  **根因**:两个战斗分支排在 `IsOtherAbilityFullyCastable` 早退**之下**,即**只在
  Q/W/R 全不可用时才开火** —— 恰恰是贴脸辅助该走人的状态;而频道一开
  `J.CanNotUseAbility` 为真,`SkillsComplement` **第二行就 return**,
  `ConsiderStopDrain` **只认 `IsRetreating`**。**与 `cmrguard` 同族**(CM 自缚频道当初
  也没有"我会不会被打死"这一项)。
  **修复**:`X.lion_IsDrainSafeToStart(hBot)`,gated turbo + **`liondrain`**,消费点在
  `ConsiderE` 里紧跟那条早退 —— **只挡两个战斗分支**,补蓝/清幻像在调用点**上方**字节不变。
  拒绝需**同时**:`WasRecentlyDamagedByAnyHero(2.0)` **且** 500 内有敌方英雄。
  **为什么必须是 AND**:只看距离**会连对照帧一起拒**(`182323` t=278.0,ES **416u,在
  500 内**,但那次 Lion 活下来了)。两个钉帧**几何几乎相同**(261u vs 416u,0.5s 后 264u)、
  **英雄伤害状态相反**、**结局相反** —— 这一对才是判据来源。半径被 census 夹在
  **[484, 781)**,**区间本身写成断言**。
  **局部验证**:`f_260819_183409_lion_drain_focused.lua`(t=255.9,必须拒,ground truth
  `died_after=8.7s`)+ `f_260819_182323_lion_drain_calm.lua`(t=278.0,必须放,12.5s);
  `tests/test_replay_260819_lion_drain.lua` **15 例**,含**两个子句各自双向的标注变异**、
  半径区间断言、**3 例端到端**(驱动真的 `SkillsComplement()` 断言入队技能;**shipped 那例
  是正向断言** —— 未 arm 真的会把 `lion_mana_drain` 排进队列,所以 armed 那例不是空绿)、
  1 例源码级顺序 tripwire。**7 次变异 6 次被抓**;**没抓到的第 7 次是收获**:在 helper 里
  重查 `J.IsValidHero` 是**不可达死代码**(`J.GetNearbyHeroes` 自己就过了一遍,
  `jmz_func.lua:2532`)→ **死代码删掉**,对应测试**改名标注为跨层 tripwire**,不再声称
  它测的是 helper 自己的分支。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **544/544 绿**(基线 **529**,干净
  stash 上实测,+15)。
  **诚实边界**:①5 局 1 归档 1 个 Lion(pos_5),pos_1/2/3 未观测;
  ②`WasRecentlyDamagedByAnyHero` **不在快照里**,每帧取值从**同一局 DAMAGE 事件流**导出并
  在测试里**显式传入**(不躺在 mock 的 `Was*` 默认 false 上);③帧外锚**只有两个**
  (施法距离 600 —— 不锚则 shipped 分支不可达、整组假绿,但两帧 261u/416u 无论取哪个值都
  在里面,**结论不依赖它**;耗蓝留默认 0,真实持蓝 268/205 高于任何 2 级耗蓝,
  **不可能在要紧方向翻转** `IsFullyCastable`),`GetActiveMode`/`GetAttackTarget` 逐条标注为变异;
  ④**整体是否更好只有批测能答**(lanefix 教训全适用);⑤**只挡起手**,打断已跑频道是
  第二个杠杆,故意留着。
  **给总监**:`liondrain` **申请入 test_set.md**。**预注册期望值**:拒 **4/13 次
  (≈0.8 次/局)**,**5 次小兵频道和另 4 次英雄频道一次不碰**,**3/3 次频道后阵亡全覆盖**。
  条件 (b) **必须用行为检测器**(按目标类型分的每局频道数、"起手 500 内有敌且正在挨英雄
  伤害"的频道数、频道后 12s 内阵亡数),**不许用 gpm/xpm**(<1 次/局按 GH #30 结构性
  不可观测)。等同一道门的 hero 组 id 现在是**三个**:`wkreincarnmp`、`axeblink`、
  `liondrain`(`zusult`/`wandlimbo` 21:00Z 已入集)。未提 queue.json(未入集提了无处可跑)。
  报告:`iterations/reports/hero/20260819T214959Z.md`。**未花 AWS 的钱**(只有 S3 GET,
  5 个 `.dem` ≈46MB + 缓存命中的 dumper,未启动 EC2)。全链路**自己做约 35 分钟**。
  下一次触发:backlog **#7 的下半**(打断已跑的频道)或 **#7 的大招那条**(Lion 每局开大
  0-2 次,与 #4 同族);#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-19T19:46:35Z:**无 open 的 `[hero]` issue**(扫过 28 条)。按上一条的指引
  取 backlog **#2 的残留(GH #34 case #4)**,打算给 `cmrguard` 的否决加**时间上界**。
  **写代码之前的第一步——把门在真实帧上重放一遍——就把立案前提证伪了,于是本轮
  不产出 gated 行为改动,而且这是结论不是阻塞。**
  **(1) 那 12 秒锁死是 range-blind 版本的性质,11:53Z 的收窄已经顺带修掉了**。
  同一份 **17 局**(三个 run 全部含 CM 的对局:`001007`×9 + `060928`×4 + `060935`×4;
  GH #34 用的是其中 14 局),同一个工具,只切 `--range-blind`:
  真实开大被否决 8/17(47%)→ **5/17(29%,0.29 次/局)**;连续否决时长
  中位 4.0→**1.5s**、p90 17.5→**5.5s**、最长 49.5→**15.0s**、
  **>=10s(整个频道时长)的连续段 68/281(24.2%)→ 4/241(1.7%)**。
  case #4 那一局(`061821`)收窄版逐帧:t=522.0 真实开大帧**只压了 3.5 秒**,
  该段最长 9.0 秒,**t=528.0 门自己松开**并给出 3.5 秒完全放行窗口,CM t=534 阵亡。
  **(2) 时间上界 `cmrhold` 决定不写**:5 次被否决的真实开大,当刻已压时长
  `0.5/1.0/1.5/3.5/4.0` 秒 → 任何 >=4.5s 的上界 **flips 0/17**(按 GH #30 噪声零点
  结构性不可观测,白占一个 test_set 名额);压到 4s 以下**先杀掉的是真阳性**
  (`001051` t=411.4,hellfire_blast 580u,**2.0s 后真的放出、CM 10s 内阵亡**)。
  收窄版 >=10s 的 4 段(`001051` 13.5 / `002451` 15.0、11.0 / `005355` 11.0)
  **与任何一次真实开大都不重合**。
  **(3) 顺带交付 `cmrguard` 上机前的收窄版反事实核验**(替换 GH #34 那份 range-blind
  的过期数字,直接答总监 readmission 里写死的「被否决的帧是不是真威胁帧」):
  **3/5 是无歧义真阳性** —— 否决者的硬控在频道窗口内真的用掉了(2.0s / 2.0s / 0.5s),
  且 CM **10 秒内都死了**(`001051` t=411.4 sk/hellfire_blast 580u;`001051` t=598.9
  ck/chaos_bolt 53u;`003005` t=373.5 jakiro/ice_path 849u)。`002451` t=394.5
  (ck/chaos_bolt 453u)是**代价为零的假阳性**(只压 0.5s,CM 10s 后满血);
  `061821`(case #4)CM 1.00→阵亡但只压 3.5s 随即放行,两边都判不出。
  **给批测台的预注册期望值**:被否决 **≈0.29 次/局**,「被否决帧威胁真兑现」基线 **3/5**;
  条件 (b) 仍**必须**用行为检测器,gpm/xpm 结构性看不见。
  **收窄的代价如实记**:range-blind 会否决、收窄放行的 3 次里,两次 shadow_shaman
  shackles(779u / 1057u)那个 shackles **确实 2 秒内用掉了**;但冷却跳变检测**认不出
  施法目标**且 Shackles 施法距离 200 码,最可能打在别人身上 —— **不声称丢了真阳性,
  也不声称没丢**。
  **交付物**:`tools/batch_test/behavioral/cmrguard_counterfactual.py`(dev-only)——
  把一次性脚本固化,armed 后的执行核验变成一条命令;curated 表从 Lua 正则抽取、
  buffer 从 `X.nRGuardCloseBuffer` 读出(两边改动跟随/自曝),`--range-blind` 做对照、
  `--buffer` 做敏感性、`--json` 供下游,实体按 dumper `idx` 锁定。
  **诚实边界(docstring 里逐条写死)**:①施法距离是**帧外锚**(behav-dump 不带
  cast range,同 GH #36 家族),自身半径类故意记 0;②**没有视野**(GH #27),
  假设敌人全可见 → 否决率是**上界**;③**不查蓝**,同向偏高;④施法按冷却跳变检测,
  **认不出目标**。其余(位置/血/等级/冷却/生死)全真。
  **`bots/` 与 `game/` 一行未动**。luacheck 0 警告,`lua5.1 tests/run_tests.lua`
  **502/502 绿**(与本轮开始的基线一致)。**没有新 gated id**;等同一道门的 hero 组 id
  仍是五个:`wkreincarnmp`、`wandlimbo`、`axeblink`、`zusult`、`axebuyblink`。
  未提 queue.json(本轮输出是给已排期的 `cmrguard` 那一波用的预注册期望值)。
  报告:`iterations/reports/hero/20260819T194635Z.md`。未花 AWS 的钱(只有 S3 GET,
  17 个 `.dem` ≈155MB + 缓存命中的 dumper,未启动 EC2)。
  **方法学**:全链路(AWS 自举 → 拉 17 个 `.dem` → 缓存 dumper → 逐帧重放门)
  **自己做约 25 分钟**。
  下一次触发:backlog **#4 的雾里那一半**(仍卡 GH #27,低优),或对 **Lion**
  (焦点五里**唯一还没有任何个体核查记录**的)起一轮逐帧 —— **倾向后者**。
- 2026-08-19T17:55:18Z:**无 open 的 `[hero]` issue**(扫过 28 条)。取 backlog
  **#3 芒果那一半 → 数据关掉**,转 **#5 未完成的那一半 → 发现问题在上游,改出装**。
  **(1) 芒果:空集**。焦点五**根本不买芒果**(51 个 fixture 按帧上任意单位重扫 +
  5 局录像逐帧,焦点五持芒果帧数 **0**;芒果只在 `advanced_item_strategy.lua` 的
  pos_4/pos_5 起始装里,而焦点五走各自 hero 文件的 `sRoleItemsBuyList`,五个都没有)。
  backlog #3 划掉,绝对阈值那条留给全英雄池的组处理。
  **(2) Axe 带匕首的帧不存在,因为他买不到**:4 局 turbo(`spot_20260819_121044_1_main`,
  `20260819_121916/_122445/_123032/_123546` slot1)逐帧扫,Axe **0 帧持有跳刀**;
  终局身价 7834/8586/5556/4228,靴子(tank_outfit 最后一件)在 272/291/292/432 秒
  完成、那时身价 2696/2672/2834/2650,局长 658/723/660/658 秒。
  **代码事实**:pos_3 是 `tank_outfit → crimson_guard → blade_mail → blink`,
  跳刀的 2250 要到约 **8.5k** 才开始买;pos_1 也把 Blade Mail 排在前面 ——
  **普通模式的顺序跑在 11 分钟结束的模式里**。
  **修复**:`BlinkFirstBuild(tList)` **从 shipped 表派生**(不是复制)一份把
  `item_blink` 挪到 index 2 的表,只在 `J.IsModeTurbo() and
  J.IsSoakCandidate('axebuyblink')` 时替换 pos_1/pos_3(别名赋值在 gate 之后,
  pos_2/4/5 跟随);gate 关闭 shipped 表一字节未动。
  **理论依据**:跳刀是 Berserker's Call 的投送工具,主流出装一律第一大件;
  Vanguard/Crimson 买生存不买开团。**可达性是量出来的**:按他自己的金钱曲线,
  靴子后直接买跳刀会在 **558.5/479.4/584.5/永不** 落地 → **3/4 局**拿到,
  还剩 100-240 秒,对比现在 **0/4**。
  **局部验证**:`tests/test_axe_blink_build.lua` **10 例** —— gate OFF 逐字对照
  shipped 表、armed+普通模式不变、armed 别的 id 不变、armed+turbo 下 blink 在
  index 2 且**多重集相等 + 非 blink 子序列顺序不变**、别名位 pos_2/4/5 两侧都钉、
  **可达性算术跑在被测表上**(先断言"blink 前只有起始装",谁插东西谁自曝)、
  shipped 下标 tripwire。**4 次变异全抓**(摘 gate 挂6 / 去 turbo 检查挂1 /
  blink 落第3位挂4 / 只删不挪挂4)。luacheck 0 警告,`lua5.1 tests/run_tests.lua`
  **499/499 绿**(基线 489 + 10)。
  **诚实边界**:①唯一帧外锚是跳刀 2250 金(商店价);②身价≠当刻可花的钱,
  落地帧是近似;③4 局、1 个归档、Axe 全是 pos_3,**pos_1 未观测**(对称推广);
  ④"跳过防装的跳刀 Axe 活不活得到用出跳刀"只有批测能答(lanefix 教训)。
  **给总监(重要)**:① **`axeblink` 单独测等于测空气** —— 前置条件实测 **0/4** 局
  成立;先 arm `axebuyblink`,或两个一起 arm 并承认测的是这一对。② `axebuyblink`
  的条件 (b) 请用**行为检测器**(跳刀获取率/获取时刻、每局跳刀施放次数、每次 Call
  拉住的人数),gpm/xpm 只当"没变更差"的兜底 —— 这个改动**换的是身价构成不是身价**。
  **顺带记下不开 issue**:这 5 局里**任何一方任何英雄都没买到过跳刀**;Axe 的靴子
  272-432 秒才完成(turbo!)—— 都归 issue #16 那个经济/节奏家族,不是本组杠杆。
  **仍未 promote、未提 queue.json**。等同一道门的 hero 组 id 现在是**五个**:
  `wkreincarnmp`、`wandlimbo`、`axeblink`、`zusult`、`axebuyblink`(`cmrguard` 已入集)。
  报告:`iterations/reports/hero/20260819T175518Z.md`。未花 AWS 的钱(只有 S3 GET)。
  下一次触发:获批则跟进批测请求;否则做 backlog **#2 的残留**(GH #34 case #4,
  要"同一威胁两帧"的输入才能设计时间上界)或 **#4 的雾里那一半**(仍卡 GH #27,低优)。
  **方法学再确认**:全链路(AWS 自举 → 拉 5 个 `.dem` → 缓存 dumper → python 扫帧)
  **自己做约 12 分钟**,包括"帧号未知的小样本扫描"。
- 2026-08-19T16:02:33Z:做 backlog **#4 的非视野那一半**(GH #36 修好后解锁的那半)。
  **无 open 的 `[hero]` issue**(#34 已关闭)。上一轮留的"跟进 `cmrguard` 批测请求"
  **主动放弃**:总监 `4409ce5` 批准它入集时**已经把排期和四条约束自己写死在
  `test_set.md` §E**(随 bisect verdict 之后第一波、与 `tpdying` 同批、必须用行为
  检测器、必须回答"被拦的帧是不是真威胁帧"),再提 `queue.json` 只会打架。
  **原假设被数据推翻(如实记录)**:自己拉 3 局 Zeus 录像(`20260819_121901` /
  `_122930` / `_142047` slot1)跑 `behav-dump -interval 0.5` 逐帧扫,**Zeus 整局只放
  1-3 次大,6 次施放里 5 次在 1.5s 内产出 `zuus->X` 击杀** —— "击杀确认分支在浪费
  大招"没有数据支持;分支 3(团战代理判据)三局里**一次都没成为施放理由**。
  **真正的坏决策在上游**,一条完整因果链(`20260819_142047_slot1`):t=213.5 升 6 级
  拿到大招(冷却 0),身上 **55 蓝 vs 246 耗蓝**;t=225.5 花 **94** 蓝 Arc Lightning
  打一个 **971/1072 血(90.6%)**的 dragon_knight,t=241.5 再花 **49** 蓝 Heavenly
  Jump,而 DK 到 t=251 **已经回满**;t=278.5 敌方 lich 掉到 **149→11 血、7678 码**
  (除全图大招外**无一件够得着**),大招**仍冷却 0**,Zeus **190 蓝,差 56**,
  `IsFullyCastable()` 为假 → `ConsiderR` **第一行**就 return;t=283.0 lich 被别人收掉;
  t=296.2 才放出本局第一发大,**靠回蓝爬了 83 秒**。两发 chip = 143 蓝,缺口 56。
  **代码事实**:`nKeepMana = 400` 只在 `ConsiderW2` 两个**带旁路**的分支里被读,
  `ConsiderQ`(三局各 21-26 次施放,最大蓝口)**从不看它**。
  **修复**:`X.zuus_ShouldSaveManaForUlt(hBot, hTarget)`,gated turbo + **`zusult`**,
  消费点在 `SkillsComplement` 里 `castQDesire`/`castWDesire` 变成**最终出价**那一行。
  全满足才压:大招**已学 + 冷却 0 + 蓝不够**(**够蓝就当帧无效** —— 门在绝大多数帧上
  结构性沉默)、**不在撤退**、目标是**敌方英雄**(小兵不碰,farm 不动)、目标血量
  **>= 0.6**(只挡 chip 不挡斩杀)。gate 关闭第一行 return false,线上字节级不变。
  **Heavenly Jump 有意不 gate**(双用途:小晕+脱身,风险画像不同;一次一个杠杆)。
  **局部验证**:**两帧一起钉**(本轮自己挖)——
  `f_260819_142047_zuus_ult_manalock.lua`(t=225.5,必须压)+
  `f_260819_142047_zuus_ult_denied.lua`(t=278.5,必须放,lich 21% 血在血线下);
  `tests/test_replay_260819_zuus_ult_manalock.lua` **17 例**,含 **3 例端到端**驱动真的
  `X.SkillsComplement()` 并断言**入队技能**(shipped 放 `zuus_lightning_bolt`;armed
  两个都不放;frame B 逐项相同),血线 0.6 **两侧都钉且常量本身写成断言**,
  `J.IsRetreating` 是**断言**不是假设。**5 次变异全抓**:摘 W 接线(挂2,含1条端到端)/
  删"已够蓝"早退(挂1)/ 血线→0.0(挂3)/ 摘 gate(挂3)/ **撤回 loader 的耗蓝项**(挂2)。
  luacheck 0 警告,`lua5.1 tests/run_tests.lua` **472/472 绿**(基线 455 + 17)。
  **顺带补的共享管线(dev-only,总监 §F 那一类"验收世界本身退化")**:
  `replay_fixture.lua` 的 `IsTrained`/`IsCooldownReady`/`IsFullyCastable` 之前是**加载时
  冻结的布尔**且 `IsFullyCastable` **完全不看蓝** —— 246 耗蓝的大招在 190 蓝的手里
  读作"完全可施放",**而这正是线上 ConsiderR 掉头就走的唯一原因**;改成对活 spec
  求值的函数(mock 里 `GetManaCost` 默认 0,**46 个既有 fixture 行为不变**)。
  另 `bot:FindAoELocation` 返回通用 `Get*` 默认值 0,调用方索引 `.count` 直接崩 →
  给**保守形状** `{count=0, targetloc=自己位置}`(宁可少报不凭空造)。
  **第 1 条不修的话本轮全部端到端断言都是假绿。**
  **诚实边界**:①门自己的输入只有**一个**帧外锚(大招 1 级耗蓝 246),而且它是
  **从录像量出来的**不是抄 wiki(本局 253→7;姊妹局 257→15 / 824→579 / 848→601);
  ②3 例端到端带**标注的变异**(`GetActiveMode`/攻击目标 dumper 都不记,不置于
  `BOT_MODE_ATTACK` 则每个技能都出价 NONE、门不可观测;另锚定 Arc 900 / Bolt 700),
  **门读的每一个量仍是真实帧数据**;③整体是否更好只有批测能答。
  **仍未 promote、未提 queue.json**。等同一道门的 hero 组 id 现在是**四个**:
  `wkreincarnmp`、`wandlimbo`、`axeblink`、`zusult`(`cmrguard` 已入集且已排期)。
  **给总监**:`zusult` 的条件 (b) 必须用**行为检测器**(每局开大次数、"大招就绪→
  第一次施放"的秒数、每局错过斩杀 episode 数),**不许用 gpm/xpm**;三局基线读数是
  **1-3 次/局**、**4/11/6 个 episode/局**。
  报告:`iterations/reports/hero/20260819T160233Z.md`。未花 AWS 的钱(只有 S3 GET)。
  下一次触发:做 backlog **#5 未完成的一半**(Axe 带匕首的起跳帧)或 **#3 的芒果那一半**
  —— 两者都自己挖帧(全链路约 6 分钟,方法见 11:53Z 那条;**这一轮又验证了一次:
  连"帧号未知的小样本扫描"也自己做更快**)。#4 只剩雾里那一半,仍卡 GH #27,
  **优先级已下调**(量级小于"没蓝放")。
- 2026-08-19T13:44:02Z:**`bots/`/`game/` 一行未动**,本轮补的是验收的最后一块。
  唯一 open 的 `[hero]` issue 仍是 **#34**(11:53Z 已收窄 + 已留言申请重新入集,
  **等总监裁定**),所以不重复做它,而是补上一轮报告自己记下的"诚实边界 ③"。
  **能做的原因**:本组 11:53Z 开的 **GH #36** 被总监 13:08Z(`02ee9b5`)修好了 ——
  他没按 issue 提的"dumper 吐 slot/is_ultimate"(`AbilityType` 是 KV,进不了 `.dem`),
  而是从游戏 KV 生成 `tests/mock/ability_meta.lua`,loader 据此回答 `IsUltimate()`
  并把大招放 slot 5。**本轮第一件事是验证它对 CM 真生效**:`sAbilityList[6]` 从恒 nil
  变成 `crystal_maiden_freezing_field`,`abilityR:IsFullyCastable()` 真、
  `DistanceFromFountain()` 9481(loader 按地图常量泉水算的真值)—— `ConsiderR`
  **第一次真的跑到守卫那一行**。这三条在测试里是**断言**的,#36 若退化本组自曝。
  **新增 5 例端到端**(同样那两个真实帧,驱动真的 `X.ConsiderR()`,断言**最终出价**,
  即总监 §0b 的要求):FAR(centaur 1326u)armed **0.75 HIGH** 且**等于 shipped**
  (误报在决策层消失)/ 给同一 centaur 1000 射程则 **0 NONE**(守卫真在决策路径上)/
  CLOSE(jakiro 1139u)armed **0 NONE** 而 shipped **0.75 HIGH**(拦住它的就是这道门)。
  E1 里**否决者一根手指没动**(断言 centaur 仍在真实 1326u、仍持就绪 hoof_stomp)。
  **端到端的诚实边界**:`ConsiderR` 开局分支要 **场里 >=3 敌**,而两个真实帧都只有
  **1 个**敌人站那么近 → 线上在这两帧本来就出价 NONE,门的影响在未改动的帧上
  **不可观测**;故各例把该帧上**真实存活的两个敌人走进 500u** 作**明确标注的变异**,
  且**把"他们不持就绪硬控"写成断言**(`J.GetReadyHardCc(mover) == nil`)而非声明
  ——FAR 用 lich/luna(lina 该帧已死),CLOSE 用 chaos_knight/pudge(持就绪
  hellfire_blast 的 skeleton_king 故意留在 8554u,连 1600 扫描都进不来)。
  另一帧外锚:Freezing Field **835 AoE 半径**(Liquipedia)。
  **四条变异全部重跑**:还原布尔包装(挂 5,**含 2 条端到端**)/ 摘掉守卫接线
  (挂 3,**含 2 条端到端**)/ buffer 1100(挂 2)/ buffer 100(挂 7,跨两个文件)。
  **关键变化:前两条以前只有源码级 wiring 抓得到,现在端到端抓得到**;两条源码级断言
  **保留**当廉价 tripwire。luacheck 0 警告,`lua5.1 tests/run_tests.lua`
  **449/449 绿**(基线 444 + 5;rebase 到 main 后在合并树上重跑 **455/455 绿**)。`state.json` 的 `cmrguard_20260819.validation`
  已补记端到端与上述变异边界(**上次正是这个字段陈旧害 `wkreincarnmp` 被驳回**)。
  **顺带的代码事实(给总监/录像组)**:这两帧上**线上 `ConsiderR` 自己出价 NONE**,
  而现实里 CM 两帧**都真开了大** → 她的大招走的是**次要分支**
  (`IsGoingOnSomeone`/目标制导),而 `GetActiveMode()`/攻击目标**不在 dump 里**,
  离线复现不了。与 #34 第 4 节"CM 大招全由次要分支驱动"互相印证;判读 `cmrguard`
  的执行核验数据时必须知道(不另开 issue,#27 已覆盖这一类)。
  **仍未 promote、未提 queue.json**(没重新入集,提了无处可跑)。等同一道门的 hero 组
  id 仍是**四个**:`cmrguard`、`wkreincarnmp`、`wandlimbo`、`axeblink`。
  报告:`iterations/reports/hero/20260819T134402Z.md`。
  下一次触发:若 `cmrguard` 获批入集则跟进批测请求(**提醒必须用行为检测器,不许用
  gpm/xpm**);否则做 backlog #5 未完成的一半(Axe 带匕首的起跳帧)或 #3 的芒果那一半
  —— **两者都自己挖帧,不要委托**(全链路约 6 分钟,方法见 11:53Z 那条)。
  **#4(Zeus 大招)的一半刚被解锁**:#36 修好后大招 fixture 可驱动了,`ConsiderV/
  ConsiderR` 的击杀确认分支现在能用真实帧跑;**只有"雾里残血"那一半仍卡在 GH #27**。
  库里现成的 `f_230952_zuus_ult_hoard.lua`(t=567,Zeus 443/1045、R 就绪、1.8s 后阵亡)
  是现成起点。
- 2026-08-19T11:53:45Z:认领并做完 **`[hero]` GH #34**(本轮唯一带 `[hero]`
  前缀的 open issue;总监 11:10Z 把 `cmrguard` 在**第一次 armed 之前**退回本组,
  并写死了重新入集路径)。backlog 未动。
  **问题**:`X.cm_IsRSafeToOpen` 调布尔包装 `J.HasReadyHardCc`,丢掉
  `J.GetReadyHardCc` 特意返回的 handle → **没有距离检查**,1600 内任何人"会"
  硬控就否决大招。同一缺陷 `ccburst` 2026-07-23 的 bisect 已经付费修过一次。
  **修复**:取 handle + `GetUnitToUnitDistance(hBot,e) <= (hCc:GetCastRange()
  or 0) + X.nRGuardCloseBuffer`,形式照 `ccburst` 已验证的写法(自身半径类技能
  cast range 报 0 → 必须贴脸,正好正确处理 `hoof_stomp`)。gate 关闭时第一行
  仍 return true,线上字节级不变。
  **阈值定 400,不是 ccburst 的 250**(issue 把这个数留给本组):**消费点不同**
  —— 250 是给 3 秒对线换血窗口定的,这里守的是 **10 秒自缚频道**,威胁只要在
  这 10 秒里够到一次就够;400 码 ≈ 300 移速下 1.3 秒位移,比频道时长小一个
  量级。两帧把它夹在 **[139, 1001)**,**区间本身写成了断言**(以后谁调这个数
  测试会自曝)。
  **新真实帧(本轮自己挖的)**:`tests/fixtures/f_260819_004858_cm_centaur_far
  .lua` = `20260819_004858_slot1` t=423.4(7:03)。CM 427/890;唯一持就绪
  curated 硬控的近敌是 **31% 血 centaur 1326 码**,`hoof_stomp` 自身为心 325
  半径、无施法距离,之后 10 秒单调走远(1326→3077)且从未施放;更近的 ogre
  (346 码)fireblast **还有 4 秒冷却**,所以 centaur 确是唯一否决者。
  **Ground truth:CM 真的开了大,之后活了 44.1 秒** —— 误报,不是侥幸。
  **局部验证**:`tests/test_replay_260819_cm_r_range.lua`(10 例)+
  `..._cm_r_selfpreserve.lua`(5 例,更新)。**两帧一起钉**(lanefix 教训);
  含 gate OFF 字节不变、**hoof_stomp cast range 取 0 或 325 放行结论都成立**、
  两条标注变异(走到 350 码重新否决 / 同一位置改成 1000 射程则否决 → 证明
  放行是**投送距离**造成的)、原 jakiro 1139 码帧仍拦、buffer 区间断言、
  两条 wiring 断言。**4 次变异测试全部被抓**(还原布尔包装 / buffer 1100 /
  buffer 100 / 摘掉接线)。luacheck 0 警告,`lua5.1 tests/run_tests.lua`
  **428/428 绿**(基线 418 + 10);rebase 到 main 后重跑 **437/437 绿**。
  **诚实边界**:①GH #34 的 **case #4 没修好**(见 backlog #2 残留);②技能
  施法距离是**帧外锚定**(ice_path 按 1000 测,是故意低估;谓词对 cast range
  单调,拦得住 1000 就拦得住真值),位置/血蓝/等级/冷却/背包/生死全真;
  ③端到端只做到源码级 wiring —— 原因是下面这个新缺口。
  **顺带发现的系统性缺口 → 新开 GH #36(`[harness]`)**:`aba_skill.lua:82`
  只在 `IsUltimate() and slot>=4` 时把名字放进 `sAbilityList[6]`,而 **dumper
  压平了技能槽位且不记 `IsUltimate`** → **每个 fixture 里 `sAbilityList[6]`
  恒为 nil**,`ConsiderR`/大招路径在碰到被测逻辑前就短路成 `DESIRE_NONE`。
  **影响全体英雄的大招 fixture 测试(会绿但什么都没跑到)**,与 #27 同一个
  假阳性家族。**没有**在加载器里硬猜兜底(会让 fixture 世界再偏离引擎一次)。
  **仍未 promote**:已在 GH #34 留言申请重新入 test_set(本组无权自改)。
  重新入集后条件 (b) **必须用行为检测器判**(开大次数、开大后 10s 内死亡率),
  **不许用 gpm/xpm**。未提 queue.json 申请(排队跟在批准之后)。
  等同一道门的 hero 组 id 现在有**四个**:`cmrguard`(收窄后重申)、
  `wkreincarnmp`、`wandlimbo`、`axeblink`。
  **经验(重要)**:**单局、已知帧号的取帧自己做,不要委托** —— 全链路
  (AWS 自举 → `awsx s3 cp` 一个 `.dem` → `get_dumper.sh` 命中 S3 缓存 →
  `behav-dump -interval 0.5 X.dem > out.json`(位置参数 + stdout,不是
  `-in/-out`) → `make_fixture.py`)**约 6 分钟**;历史上两次委托
  replay-analyst 分别跑满 51 分钟没返回。委托的价值在**帧号未知时扫全库**。
  报告:`iterations/reports/hero/20260819T115345Z.md`。
  下一次触发:若 `cmrguard` 获批入集则跟进批测请求(并提醒用行为检测器);
  否则做 backlog #5 未完成的一半(Axe 带匕首的起跳帧)或 #3 的芒果那一半 ——
  **两者都可以自己挖帧了**(方法见上),不必再委托。#4(Zeus 大招)仍部分
  阻塞在 GH #27。
- 2026-08-19T09:45:13Z:完成 backlog #5(Axe 跳吼目标质量)第一刀。无 open 的
  `[hero]` issue(扫过 22 条)。
  **问题(代码事实)**:`ability_item_usage_generic.lua` 的
  `X.ConsiderItemDesire["item_blink"]` 里 `J.IsGoingOnSomeone` 那条进攻性闪烁
  分支**从不看嘲讽**:目标在 500..施法距离之间、人头数不吃亏就闪过去。而且
  没人替 Axe 兜底 —— 同函数上方的 `bot.shouldBlink` 保留名单(batrider/
  beastmaster/dark_seer/earthshaker/magnataur/rubick/tiny/treant)**没有 Axe**,
  `hero_axe.lua` 也从不给 `shouldBlink` 赋值。于是嘲讽在冷却/蓝不够时 Axe 照样
  往人堆里跳:落地是一具没有控制没有脱身手段的近战身体(Counter Helix 的触发
  本来就靠嘲讽制造的"被攻击",Culling Blade 的重置假设目标走不掉)。
  **修复**:新增 `J.ShouldHoldAxeBlinkForCall(bot, vLandLoc)`,gated turbo +
  **`axeblink`**;同时满足才压住闪烁:是 Axe、嘲讽**已学**、嘲讽**当帧不可用**
  (冷却或蓝 < 耗蓝)、落点嘲讽半径内**可见敌方英雄 >= 2**(人堆)。
  **单人跳刻意不动**(嘲讽没好但对面只剩一个残血,跳过去收掉是正当用法),
  所以判据是"人堆 + 没吼"而非"没吼"。gate 关闭时函数第一行返回 false,线上
  行为字节级不变。理论依据:匕首是嘲讽的投送工具(blink→call 一气呵成),
  等待的代价只有剩余冷却,不等的代价是匕首 CD + 一条命。
  **局部验证**:真实帧 `20260721_222428_slot1` t=314.0(5:14)——Axe 7 级、
  629/1719 血、151/459 蓝、嘲讽 1 级**剩 6.7s 冷却**、敌方 Lion(354/823)在
  **741 码**(正落在该分支自己的 500..1200 窗口里)、Lion 身边**没有第二个敌人**。
  `tests/test_replay_222428_axe_blink_call.lua` 10 例(无 J.* 桩):ground
  truth、gate OFF ×2、**未经改动的真实帧不压**(单人)、人堆+嘲讽冷却压住、
  人堆但嘲讽就绪不压、人堆+出CD但蓝不够压住、人堆但嘲讽没点不压、非 Axe 主角
  不压、**源码级 wiring 断言**(对应总监 #0b:必须断言最终决策不只是 helper)。
  **3 次变异测试全部被抓**(阈值 2→1 / 删嘲讽可用性检查 / 摘掉消费点接线)。
  luacheck 0 警告,`lua5.1 tests/run_tests.lua` **418/418 绿**(基线 408 + 10)。
  **顺带的共享管线改动(非行为改动)**:`tests/mock/replay_fixture.lua` 的
  `M.load(path)` 新增可选 `sSubject` —— **用帧上任意英雄当主角**驱动同一帧
  (帧里每个单位的位置/血蓝/等级/物品/技能冷却本来就都是真的),把 43 个既有
  fixture 的可用面放大一圈;覆盖主角时把 `GetEstimatedDamageToTarget` 归零
  (`observed` 是关于原主角的 ground truth,不能转移)。默认路径不变。
  **caveat**:①这帧上 **Axe 没带匕首**,帧钉的是守卫的输入(嘲讽等级/冷却/蓝、
  决定单人还是人堆的位置),不是"持有匕首"这个消费点前置条件;②人堆那几例是
  对真实帧的**变异**(把同帧另一个真实敌人挪到目标身边),测试里逐条标注;
  ③嘲讽 1 级耗蓝 70 帧外锚定(Liquipedia,同 `wkreincarnmp` 的 `GetManaCost`);
  ④消费点未端到端驱动(`botTarget` 是文件局部、只在未导出的
  `ItemUsageComplement` 里赋值),用源码级 wiring 断言代替。
  **仍未 promote、未提批测请求**:`axeblink` 要总监批准进 `test_set.md`。现在
  等同一道门的 hero 组 id 有**三个**:`wkreincarnmp`、`wandlimbo`、`axeblink`
  (`cmrguard` 已获批入集)。
  报告:`iterations/reports/hero/20260819T094513Z.md`。
  下一次触发:若三个 id 有获批的则跟进批测请求;否则委托 replay-analyst
  **小样本 1-2 局**同时扫两件事(都要 12 分钟后的片段)——"Axe + 背包有
  item_blink"的起跳帧(#5 未完成的一半)和"焦点五 + 低蓝 + 背包有
  enchanted_mango"的死手帧(#3 芒果那一半);注意历史教训:AWS 自举 + S3 +
  dumper 跑多局会超出单次触发的时间预算,样本量务必压到 1-2 局。
  #4(Zeus 大招)仍部分阻塞在 GH #27。
- 2026-08-19T07:44:04Z:完成 backlog #3 的**魔棒那一半**(芒果那一半没有可用
  真实帧,如实留在 backlog)。无 open 的 `[hero]` issue(扫过 20 条)。
  **问题(代码事实)**:`ability_item_usage_generic.lua` 的魔棒 consider
  (`item_magic_stick`/`item_holy_locket` 也委托进来)4 条规则**每一条都要求
  1000 内有敌方英雄**,唯一例外 `wandbleed` 要求
  `WasRecentlyDamagedByAnyHero(2.0)` —— 于是处在 d23 `lowhp_limbo` 状态
  (<40% 血、离家 >2500、45s+、不回血不 TP 不刷钱、**周围没人**)的 bot
  满足不了任何一条,攥着瞬发治疗在 15% 血上晃到死。
  **真实帧(归档里已有,没花 dumper)**:`f_181441_zuus_lowhp_limbo.lua`
  = `20260722_181441_slot1` t=660.0(11:00),Zeus 214/1354(15.8%),最近敌人
  ~2017 码(1000 内和 1600 内都是 0 人),离己方泉水 ~4599,之后 5 秒**无人
  对他造成伤害**且没死,背包 slot5 魔棒、slot4 是**空瓶**。
  **修复**:新增 `J.ShouldDrinkWandInLimbo(bot, hItem)`,gated turbo +
  **`wandlimbo`**;条件:>=6 层、HP<=25%(比用途1 的 40% 更深)、
  缺血 >= 15*层数(不溢出)、**1600 内无敌方英雄**(有敌人就是用途1 的活,
  结构上不重叠)、离己方泉水 >2500(对齐 d23)。gate 关闭时函数第二行返回
  false,线上行为字节级不变。
  **局部验证**:`tests/test_replay_181441_wand_limbo.lua` 9 例跑在真实帧上
  (无 J.* 桩):ground truth、gate OFF ×2、gate ON 在真实帧出手、3 层不出手、
  **把敌人挪到 900 码就不出手**(证明认的是"安静漂流"不是"血低就喝")、
  血抬到 36.9% 不出手、挪到泉水上不出手、不溢出不变量(这一条是合成的,
  已在测试里注明)。luacheck 0 警告,`lua5.1 tests/run_tests.lua`
  **390/390 绿**(基线 381 + 9)。
  **caveat**:**dumper 不记录物品充能层数**,充能是这组测试里唯一来自帧外的
  数字(同 `wkreincarnmp` 的 `GetManaCost`);位置/血量/阵容/生死/背包内容
  全真。
  **仍未 promote、未提批测请求**:`wandlimbo` 要总监批准进 `test_set.md`,
  和 `cmrguard`、`wkreincarnmp` 卡在同一步 —— 现在是**三个**通过局部验证、
  等同一道门的 gated id;三个都没进 test_set,提 queue 也无处可跑。
  报告:`iterations/reports/hero/20260819T074404Z.md`。
  下一次触发:若 test_set 三个 id 已获批则跟进批测请求;否则做 backlog #3 的
  芒果那一半(委托 replay-analyst **小样本 1-2 局**扫芒果死手帧)或 #5
  (Axe 跳吼目标质量)。#4(Zeus 大招)仍部分阻塞在 GH #27。
- 2026-08-19T05:45:28Z:**本次没有产出新的 gated 英雄行为改动**,`bots/` 与
  `game/` 一行未动 —— 是一个诚实的阻塞,记录在案免得下一个人重走。
  **(1) 订正了卡住 `wkreincarnmp` 的记录错误**:总监 04:54Z 驳回它入
  test_set 的唯一理由是"只有 mock 单测、没有真实帧 fixture(state.json 原文
  承认)",但真实帧 fixture 早在 01:51Z 就已落地并 push
  (`tests/fixtures/f_260725_105305_wk_reincarn_gap.lua` +
  `tests/test_replay_260725_wk_reincarn_gap.lua`),**是 state.json 的
  `validation` 字段没跟着更新**,总监读的是陈旧文字。已重写该字段(两层
  验证、文件路径、真实帧数值、并显式标注它此前是陈旧的且正是它导致了驳回),
  **重新申请入 test_set,需总监批准**。必须一并交代的 caveat:
  `make_fixture.py` 不挖技能 spec,测试里显式把 `GetManaCost` 设成 220
  (Liquipedia + 同局录像实测 ~219 耗蓝双重印证),即位置/血蓝/等级/冷却全
  来自真实帧,**唯独耗蓝这一个数是外部锚定的**。
  **(2) 打通了 fixture 的视野管线,但它现在还空转**:接 backlog #4 读
  `hero_zuus.lua` 时发现击杀确认分支被 `CanBeSeen()` 挡住(见 backlog #4
  条目),要做真实帧验证时撞墙 —— `replay_fixture.lua` 把每个单位硬编码成
  `CanBeSeen = true`,`make_fixture.py` 不输出视野,再往上游 **dumper
  (`behavioral/dumper/main.go`)从不写 `vis`**。影响面**远不止 Zeus**:
  `J.CanCastOnNonMagicImmune`(:988)和 `J.IsValid`(:2984)都硬依赖
  `CanBeSeen()`,**所有 fixture 都在"敌人全亮"的世界里判绿**,这是跨全组的
  系统性假阳性来源(与 `creeppull`/`pullcamp` 批测全程 SILENT 同一成因家族)。
  已做掉 fixture 侧一半:`make_fixture.py` 输出 `seen_by`(v1 dump 无该键时
  **整个字段省略**,不是空表);`replay_fixture.lua` 按 `seen_by` 设
  `CanBeSeen()` 且 `GetNearbyHeroes` 视野受限,`GetUnitList` 保持全图
  (与 `docs/BOT_API_REFERENCE.md:624` 一致);老 fixture 一律全可见、
  行为不变。契约由 `tests/test_replay_fixture_vision.lua`(9 例)钉住。
  **dumper 侧已开 GH #27(`[harness]`,带复现步骤 + 三条验收标准)**。
  luacheck 0 警告,`lua5.1 tests/run_tests.lua` **386/386 绿**(基线 377 +
  新增 9,无既有 fixture 测试位移)。本次未提 `iterations/queue.json` 批测
  请求(没有新 gated 改动需要批测)。
  报告:`iterations/reports/hero/20260819T054528Z.md`。
  **(3) 委托 replay-analyst 扫 Zeus 大招施放的任务没能在本次会话内返回**
  (51 分钟仍 running),`zeus_ult_scan_*.md` **不存在**。教训记录:
  AWS 自举 + S3 拉取 + dumper 跑多局的组合**超出单次触发的时间预算**,
  下次委托时把样本量先压到 1-2 局。
  下一次触发:重新发起 Zeus 大招扫描(小样本起步)接 backlog #4 的非视野
  那一半;#27 若已解则补上雾里击杀确认的真实帧 fixture;否则认领 #3/#5。
- 2026-08-19T03:55:34Z:完成 backlog #2(CM 大招时机,第一刀)。委托
  `replay-analyst` 在 soak S3 归档扫了 186 局含 CM 的对局、抽样 30 次 R
  (Freezing Field) 施放,系统性发现:30 次里 9 次(30%)频道被打断到
  <2秒(满时长10秒),多次紧接着 CM 阵亡。最干净的真实帧:
  `spot_20260819_001007_1_main/20260819_003005_slot1` t=373.4(6:13)——CM
  开大时 Jakiro(ice_path 未在冷却,`J.tHardCcAbilities` 收录的硬控技能)
  正逼近至约1139码、无友军控制掩护;0.6秒后被冰封禁锢打断频道,5.9秒后
  阵亡。**根因**:`hero_crystal_maiden.lua` 的 `X.ConsiderR` 完全没有"我
  自己是否安全"的判断,只算敌人数量/逃逸,不管自己是否即将被控链锁死。
  **修复**:新增 `X.cm_IsRSafeToOpen(hBot)`,复用既有 `J.HasReadyHardCc`/
  `J.GetReadyHardCc`(`jmz_func.lua` 已有的硬控技能表,未新增表),1600码内
  任一敌方英雄有就绪硬控则拒开大;gated turbo + `cmrguard`,gate 关闭时
  行为与线上字节级不变。附带修了 `tests/mock/replay_fixture.lua` 的一个
  通用缺口(之前只接了 `GetAbilityByName`,没接 `GetAbilityInSlot`——
  `J.GetReadyHardCc` 按槽位扫描,这是引擎管线补丁不是 gated 行为改动)。
  真实帧 fixture:`tests/fixtures/f_260819_003005_cm_selfpreserve.lua`
  (AWS 自举 + behav-dump 在真实 .dem 上跑出 timeline + make_fixture.py 钉
  t=373.4)+ `tests/test_replay_260819_cm_r_selfpreserve.lua`(5 例:
  ground truth、gate OFF ×2 字节不变、gate ON 在真实帧正确拒开、gate ON
  但把 Jakiro 硬控置于冷却后正确放行——证明 gate 认的是真实威胁不是敌人
  存在性)。luacheck 0 警告,`lua5.1 tests/run_tests.lua` **371/371 绿**。
  **验证哲学三条件**:(a) 真实帧确认逻辑正确 ✅;(c) 逻辑依据 ✅(频道
  被硬控打断导致价值流失,直接对应观测到的系统性 30% 打断率);(b) 批测
  无负面 —— **待办**,`cmrguard` 尚未入 test_set.md,本组无权自改,需
  director 批准纳入(与 backlog #6 的 `wkreincarnmp` 一样卡在同一步)。
  **原始假设未证实**:backlog #2 原文猜测"`#nEnemysHeroesInRange>=3` 无脑
  绕过 `aoeCanHurtCount` 逃逸检查导致空放"——30 次采样没找到这个模式的
  干净实例,发现的是更高信号、更可复现的"自保缺失"问题,已在报告里说明
  是替代而非偷懒漏查;原假设的分支本身未动,留作可选后续项。
  **仍未 promote**,等 director 批准 test_set 后再排批测。
  报告:`iterations/reports/hero/20260819T035534Z.md`。
  下一次触发:director 批准 `cmrguard`/`wkreincarnmp` 入 test_set 后跟进
  批测请求;否则认领 backlog #3-5(魔棒/芒果死手帧、Zeus 大招击杀确认、
  Axe 跳吼目标质量)之一。
- 2026-08-19T01:51Z:完成 backlog #6(接 #1 的真实帧 fixture 缺口)。
  本组无本地录像归档/AWS 访问,委托 `replay-analyst` 子代理在既有批测
  归档里挖帧,拿到 `spot_20260725_102532_1_main/20260725_105305_slot1`
  t=373.5(6:13)的真实 WK 帧:等级6、Reincarnation 1级、冷却0、
  mp=189/387——正落在旧阈值160与真实1级耗蓝220(Liquipedia 2026-08)的
  gap 里(该局死亡帧前后的实测耗蓝~219,印证了220这个数字)。新增
  `tests/fixtures/f_260725_105305_wk_reincarn_gap.lua` +
  `tests/test_replay_260725_wk_reincarn_gap.lua`(真实帧、无 J.* 桩,
  `mock/replay_fixture.lua` 加载后跑真实 `J.IsWkReincarnationArmed`):
  gate OFF 读 ARMED(与线上字节级不变,即使数值上是误判)、gate ON 正确读
  NOT armed。luacheck 0 警告(容器新装 luacheck/lua5.1/luarocks),
  `lua5.1 tests/run_tests.lua` **363/363 绿**。
  **验证哲学三条件**:(a) 真实帧确认逻辑正确 ✅ 本轮首次达成;
  (c) 逻辑依据 ✅(Liquipedia + 帧内实测耗蓝双重印证);
  (b) 批测无负面 —— **待办**,`wkreincarnmp` 目前不在 test_set.md
  14-id 现行集里也不在本轮已启动的批测波次里,需 director 批准纳入
  test_set 提议(本组无权自改 test_set.md)。**仍未 promote。**
  报告:`iterations/reports/hero/20260819T015121Z.md`。
  下一次触发:认领 backlog #2-5(Zeus/CM/Axe/魔棒芒果死手帧核查)之一,
  焦点五目前只有 WK 有系统性个体核查记录,其余四个仍待起步。
- 2026-08-18:完成 backlog #1(WK 重生蓝保留)代码修复 —
  `mode_retreat_generic.lua` 的团战免撤逻辑此前用硬编码 `mana >= 160`
  判断"大招重生已备好",但 Reincarnation 实际触发耗蓝随技能等级递减
  (约 220/110/0,Liquipedia 2026-08 查证),6 级刚学时(WK 大部分中期)
  真实耗蓝是 220,160 会被误判为"已备好",WK 因此不撤、真死不重生。
  新增 `J.IsWkReincarnationArmed(bot)`(`bots/FunLib/jmz_func.lua`),
  gated turbo + `wkreincarnmp`,默认路径(未 arm)与线上行为字节级不变;
  `mode_retreat_generic.lua` 内联判断改为调用该 helper。
  验证:本会话无本地录像归档/未跑 AWS bootstrap,无法用
  make_fixture.py 钉真实帧,改用 6 条 mock 单测
  (`tests/test_wk_reincarnation_mana_gate.lua`)锁定 gate OFF 字节不变 +
  gate ON 修正后的判定;luacheck 0 警告,`lua5.1 tests/run_tests.lua`
  355/355 绿。**未 promote、未排批测** —— 真实帧 fixture 是 backlog #6,
  下一次触发或 replay-analyst 优先做。
  测试集里与本组相关的 id:wandbleed(魔棒放血规则)、
  fieldregen(野区补给回购)。焦点五各英雄尚无系统性个体核查记录
  (Zeus/Lion/CM/Axe backlog #2-5 仍待认领)。
