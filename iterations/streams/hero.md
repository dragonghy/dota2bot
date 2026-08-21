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
   见下面已划掉的 #6 和"当前状态"。~~(a)(c) 条件满足,(b) 批测待办,仍未 promote。~~
   **2026-08-21T00:45Z 语料核验后撤回排队(GH #76):域 = 1 帧 / 2119,而那 1 帧是
   1 血、大招仍在 0.4s 冷却的将死之人 ⇒ axeblink 陷阱,永不 arm。** 成因在代码里:
   `hero_skeleton_king.lua:490` 的 `X.ShouldSaveMana` **已经用了正确的 `GetManaCost()`**
   且看住了 WK 全部两个花蓝技能(:225 / :442),所以 WK 结构上花不进 [160,220) 带
   (就绪帧 mana min 187 / p1 234 / 中位 363,对 cost 220)。gate 代码保留(它是对的)。
   **复活条件**:`X.ShouldSaveMana` 被改/删或其 `<= 3.0` 窗口收窄,或对手池稳定出现掉蓝
   —— 届时必须重量,不得引用 1/2119。**可复用先验**:一个门若只改「读」的那一侧,
   先去看「写/花」的那一侧有没有已经写对的同款守卫;有的话域基本就是空的。
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
   ~~**推论(必须传给总监)**:`axeblink` **单独测等于测空气**,它的消费点前置条件
   在实测 0/4 局成立;要么先 arm `axebuyblink`,要么两个一起 arm。~~
   **2026-08-21T02:10Z 语料核验后撤回排队(GH #79):域是空的,而且比 `wkreincarnmp`
   那次更硬 —— 配对排期的裁定同时作废。** 选的是**唯一一波 `axebuyblink` armed** 的语料
   (`replays/20260820_04*`,18 局 turbo,**8 局 Axe 持刀**、11 次真实施放),刻意先把
   「没刀」这个供给问题排除掉 ⇒ **载体有了,域照样空**。A 段精确域 **0/11**(承重的是门自己的
   最后一行:落点 315 内敌人数 `{0 人: 5 次, 1 人: 6 次}`,一次没到 2);B 段松上界漏斗
   `223 → 72 → 21 → 0`,**最后那一步是发现:那 21 帧上目标 1200 内的友军(含 Axe 本人)
   = 1,21 帧全是 1**,只有他自己。**成因在代码里**:分支自己的
   `#nInRangeAlly >= nNearbyEnemyHeroCount`(`ability_item_usage_generic.lua:1610`)
   **严格更弱** —— 落点在 cast range 内就等于目标位置,所以「落点 315 内 >= 2 敌」蕴含
   「目标 1200 内 >= 2 敌」⇒ 门想否决的每一帧,分支都已经否决过。gate 代码保留(它是对的)。
   **复活条件**:那条人数闸被削弱/删除或 1200 环被改,或落地一个编组改动使 Axe 跳的目标
   1200 内稳定有第二个队友(今天实测 1,21/21)。
   **可复用先验(本轮最该被别的组拿走的东西)**:**上机一个「新增否决」的门之前,先看它所在的
   那条分支是不是已经用一个更弱的条件否决了 —— 是的话,新门的域就是一个已有否决的子集,
   必然是空的。** 与 `wkreincarnmp` 那条同族、低一层,两条都是**不用拉语料的桌面检查**。
   **顺带一条量测事实**:跳刀位移出现在 ITEM 事件后的第一**或**第二个 0.5s 采样,不固定 ——
   按「事件后下一帧」取落点会把 `043124` t=529.6 读成 77 码走路(真值 1309 码 cos +0.999),
   **分支归属会错**;改成「`[t-0.5, t+2.0]` 窗口内相邻快照最大位移」后与 GH #71 的独立读数
   完全对上。
   **⚠️ 2026-08-21T03:00Z 总监驳回上面这段的强度,03:48Z 本组自己又更正了两个数 —— 上面 02:10Z
   那一版的措辞不要再引用,以「当前状态」最新一条为准。**三处:
   ① **不是「结构性为空」**:代入后得到的是**耦合**不是子集,「目标 1200 内还有 >= 1 个队友」的帧上
   分支**通过**,armed ≠ shipped ⇒ 归类是 **DOMAIN-NOT-REACHED**,且复活条件多一条
   「**任何 grouping 类 id 被 armed**」。上面那条「可复用先验」的**措辞已被总监否掉**(它在产生它的
   那个 case 上就不成立),正确写法见 test_set.md §Y.2 / state.json
   `general_prior_20260821_corrected`:**桌面能证 EMPTY,不能证 RARE**。
   ② **漏斗分母错了**:223 里混着 **132 个尸体帧**(GH #78 家族),正确是 **167 → 63 → 21 → 0**。
   ③ **「21 帧全是 1」不是上界的性质**:整个上界上 **36.5% 的帧 / 48.0% 的 episode** Axe 身边有队友;
   而且那 21 帧只是 **3 个 episode**(一个独供 17 帧)⇒ **「0/21」实为「0/3」**,p=0.24,
   正确上界 **63.2%**(不是 13.3%),施放侧 **0/6 ⇒ 39.3%**(不是 0/11 ⇒ 23.8%)。
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
   - ~~**`X.ConsiderStopDrain` 只认 `J.IsRetreating`**~~ **2026-08-20T18:12Z done**,
     新 gate **`liondrainstop`**,与 `liondrain` 共用 `X.nEDrainDangerRadius` 常量
     (retune 双向自报);两个真实帧 fixture(**同一局 182855 的两个不同 channel**:
     mid-channel 297.2 viper focused 必压 / mid-channel 244.3 troll jungle 必放)
     + 19 例 + 8 次变异全抓,见"当前状态"。
   - **下一轮 Lion 从这里起**:大招施放 **0/1/2/0/0 次/局**(Hex 5/6/4/3/4,
     Impale 16/15/17/13/11)—— 和 Zeus 那条(#4)是同一个"终结技用得少"的家族。
     - **2026-08-20T20:08Z 走查落地(GH #73)**:代码走查两条结构缺口:①`nKeepMana=400`
       在 `hero_lion.lua` 是**纯死代码**(全仓 0 处读,和 Zeus `zusult` 那家同型 —— Lion
       完全没有为 Finger 留蓝);②`X.ConsiderR` 的**击杀**与**团战最弱**分支跑
       `nInBonusEnemyList = GetNearbyHeroes( bot, nCastRange+400, ...)`(1300/1550u)
       但**没有 range 断言**(只过 CanCastOnTargetAdvanced + CanCastOnNonMagicImmune,
       两者都不看距离),而同函数的 aghs-AoE(+150)与 IsGoingOnSomeone(+200)分支自己
       IsInRange。**本轮只清了死代码 + 加了 17 行注释**(非行为等价,857/857 绿,luacheck 0),
       两个 lever 都**没上机 gate** —— 六个 Lion fixture **零一** 满足 gate 正样本条件
       (finger cd=0 且 mp ∈ [cost, cost+spend) 与 Impale 竞争),armed 与 shipped 端到端
       会相同(axeblink 陷阱)。**GH #73** 已把两个 lever 形状 / 与 zusult 同型证据 /
       六帧不满足条件的表 / (b) 检测器建议全部写死。
     - ~~**下一轮选一个 lever 做**~~ **2026-08-20T21:51Z 上机前语料核验:两个 lever 都不做**
       (新工具 `tools/batch_test/behavioral/lion_finger_domain.py`,3 局有 Lion 的 turbo 语料)。
       **lever(a) `lionult` 域 = 空集**:1216 个「大招已学+就绪+付得起」帧里 below-cost **0**、
       post-spend 带 `[200,350)` **0**,大招就绪时最低蓝 **337/397/381** 对 cost **200**
       —— 结构性的(零蓝 Mana Drain 把蓝池顶在 380 以上,单个 Impale/Hex 跨不过线),
       armed 与 shipped 端到端逐帧相同 ⇒ **axeblink 陷阱**,建议在 #73 里关掉。
       **lever(b) 域 = 6 帧 / 1 episode / 3 局**且反事实不干净(那 2 秒 Lion 确实在走近、
       1343→968,窗口最终是被 CM **脱战回血**关上的,不是被距离)⇒ **park**。
       **真正的成因是窗口供给**:5 个射程内击杀窗口帧 vs **4 次实际施法**(第 5 个 0.1 秒后被
       队友 OD 大招抢掉),即 Lion 能打的基本都打了;窗口少是因为 ① Finger 整局停在 **level 1**
       (hero level 上限 9/11/11,第二点要 12,turbo 够不到)⇒ 恒 600 raw ≈ **450 有效**、cd 恒 **110s**,
       ② `X.ConsiderR` 每条开火分支都要 `J.WillMagicKillTarget`(不能一发打死就不放)。
       **下一轮若回到 Lion 大招:唯一有量的杠杆是改策略本身**(level 1 时把 Finger 当团战爆发起手
       而不是处决技),大改动,单独 id、单独一条臂,先想清代价侧。
       **顺带算清、别再捡回去**:`ultcash`(owner 已判「没啥道理…never arm」)在 turbo level 1 上
       净亏 ≈95 秒终结技可用时间(110s cd vs 13-16s turbo 复活),而击杀窗口约每 2 分钟才来一个;
       C 域那 2/9 次「攥着大招死」的射程内目标**都是满血**(1135/1.00、1429/1.00)。
   - 已排除、别重查:`pos_4/pos_5` 的 outfit 宏**含鞋**(`aba_item.lua:962/967`)。

8. ~~**GH #50 第 2 处:`hero_invoker.lua` 的 `J.Unit` 是 nil**~~ **2026-08-20T10:30Z done**
   (#51 09:08Z 由总监修完解锁)。已改成 `J.Utils.IsUnitWithName`,`KNOWN_BROKEN` **归空**,
   11 例 + 6 次变异全抓,见"当前状态"。
   - **更正 #50 的记录**:这一处**从来没崩过** —— `J.IsValidTarget` 与 `J.IsValidHero` 是
     **同一个 delegate**,闸门 `A or (A and X)` ≡ `A`,右支**结构性不可达**。改的是**引信**
     (jmz_func.lua:2992 的 NOTE 一行就能点燃它),不是崩溃。
   - **故意没做**:「陨石也能砸肉山/百解」这个**意图从来没实现过**,补它缺的是**一个调用点**
     不是一次重命名 ⇒ 非焦点英雄上的行为改动,要 gated + 真实帧,而它的 (a) 取证卡在
     dumper 只 dump 英雄(#27/#43/#53)。
   - **顺带开了 GH #64(全池,不归本组)**:`J.IsValidTarget` ≡ `J.IsValidHero`,377 个调用点
     里 287 个传 `botTarget` ⇒ 所有"为非英雄目标写的分支"恰好在自己适用的场景下被挡掉。
     已确认受害者:`hero_snapfire.lua:763`(`GobbleUp == 'creep'` 却要求目标是英雄,语义完全反了)、
     `mode_roam_generic.lua:1565`(tombstone 分支的可达域是意图的补集,这是 #51 之外的第二重死因)。

9. ~~**GH #54:OD 的 Sanity's Eclipse 被写成单体处决技**~~ **2026-08-20T04:00Z done**,
   gate `odaoe`,两个真实帧 fixture + 22 例 + 9 次变异全抓,见"当前状态"。
   - **2026-08-21T05:52Z 上机前语料核验 PASS**(三轮里第一个);**07:0xZ 总监暂缓**(承重子句跑在
     被 #78 判死的存活代理上);**08:15Z 两列审计交付、两列都通过** ⇒ 头条改为
     **30 帧 / 10 EPISODE / 7 局**,长度 >= 2 的 **8/10**,代理只值 1 帧 0 episode。
     **等总监批准入集**;获批后本组下一件事是它的 **(a) 执行核验**(预注册域 = 那 30 帧 / 10 episode)。
   - **未做、且本组故意不碰的那一半(仍 open,无人认领)**:#54 §5.3 的
     `J.IsGoingOnSomeone` —— 它把大招在 RETREAT/PUSH 里**整条关掉**而不是降优先级。
     这是 mode 域的语义,影响面不止 OD;一次一个杠杆。
   - **下一轮若回到 OD**:先看 `odaoe` 的执行核验,再谈 mode 域。
   - **别重查**:`bot:FindAoELocation` 在 fixture 里恒 `{count=0}`(mock 的保守形状),
     所以任何用它选落点的实现**离线不可验证** —— 本轮自己算覆盖就是为了绕开这一点。

10. ~~**跳刀被当腿用**~~ **2026-08-20T15:20Z 定位完成、按章程转协同组(GH #71)**:
    重跑 `20260820_043124_slot1` dumper 得到 5 次 `item_blink` 施放的几何指纹
    (cos = 位移向量与「Axe → Dire ancient」单位向量的点积;+1 = 完全朝家门,-1 = 完全朝
    敌方)。**t=529.6 cos=+0.997 跳 1326**、**t=555.2 cos=+0.998 跳 1162** ⇒ 两次都落
    在 `bots/ability_item_usage_generic.lua:1503-1518` 的 **retreat 分支**(把
    `nCastRange=1200` 交给 `J.GetLocationTowardDistanceLocation(bot, GetAncient(GetTeam()),
    nCastRange)`)。**排除 `IsProjectileIncoming` 分支**(t=529.6 前 7s 没有可躲避的非
    攻击弹道在飞;t=555.2 前 5s 里敌方零施法)。分支语义是**全英雄池**(mode 域 +
    `ability_item_usage_generic.lua` 都不归英雄组),GH #71 已开给协同组,附完整帧读数
    与两条建议(HP 地板 / 敌方威胁地板)+ 几何检测器验收口径(cos>0.9 且距离在
    [1100,1400])。**本条到「定位」为止即完成,英雄组不再持有。**

11. **Zeus 有两套互不知情的「留蓝」机制(2026-08-20T07:55Z 新开)**:`zusult`/`zusultx` 这一套
    问的是「花完还付不付得起大招」;而 `nKeepMana = 400` 这个常量只在 `ConsiderW2` 的两个带旁路
    的分支里被读(`bot:GetMana() > nKeepMana * 2` / `* 2.3`),**`ConsiderQ` 根本不看它**。
    两套阈值并存、口径不同、互不知情。**等 `zusultx` 落地(有 (b) 读数)之后再动**,不要同时
    动两个杠杆。

14. ~~**`esaftershock`(GH #66 的召回补丁)等入集**~~ **2026-08-21T12:15Z 上机前语料核验后撤回:
    DO NOT ARM,`DOMAIN-REACHED-BUT-VANISHING`,域 = 1 EPISODE / 17 局里的 1 局、
    17 次真实施放里的 1 次。** 与 `cmrself` 同处置但**成因是第二种:供给饥饿,不是反相关**
    (载体 1/4 种子 × 几何「totem-armed 的 ES 只有 5.5% 的时间在 400 码环内」;那 65 个在环帧里
    Fissure 冷却中的有 **64** ⇒ 门拿到机会时几乎每次都真的加上了 handle,它只是拿不到机会;
    开火子句反而配合,`aoeCanHurtCount >= 2` 中 **4/15 = 27%**,对比 `cmrself` 的 3%)。
    **要引用的是施放侧的 1/17,不是状态扫描的 4 帧** —— 后者全靠 `aoeCanHurtCount`,
    环含**不在 `.dem` 里的敌方移速**,ms>=330 时为 0;施放侧跑在三条分支之上,**ms 全程恒 1**。
    **复活条件**:种子池变得稳定抽到 ES / `X.nRGuardCloseBuffer` 被放宽(实测 800 ⇒ 1→3,
    但多的两发里有一个**干净的假阳性**:满血读满 10 秒还活着)/ 候选表长出第二条且载体常见。
    **门代码保留(它是对的)。** 工具 `tools/batch_test/behavioral/es_aftershock_domain.py`;
    GH **#85**;详见"当前状态"。
    - **本条掉出来的两条跨组事实(不归本组,但本组已在工具侧落地修法)**:
      **(甲) 采样间隔**:dumper `-interval` 默认 1.0s、`run_replay.sh` 不传 flag,而本目录 docstring
      写 0.5s ⇒ **历来所有「N 帧」头条跨轮不可比**(同 17 局两种间隔:帧数 ×2,**episode 不变**)。
      **(乙) `CAST_RANGE` 锚 23 条错 16 条**(cask **900→600**、shackles **200→450**,
      两条其实是逐级值)⇒ **GH #63 的 86%/78% 必须用新表重跑**。

12. ~~**`[hero]` GH #63 未认领(下一轮第一候选)**~~ **2026-08-20T12:08Z 改判:本组不认领,
    等 `esaftershock` 的读数**。**2026-08-21T12:15Z 更新:等的东西变了 —— `esaftershock`
    不上机了(见 #14),所以不再等它的行为读数;改等**用重锚后的 `CAST_RANGE` 重跑
    `cmrguard_precision.py`** 的精确率/封锁时长。而且 #63 的**头条数字本身已被重锚推翻**
    (cask 真值 600 ⇒ 环 1000u,不是 1300u),shackles 又是反方向(200→450)⇒
    「统一封顶到 200-300u」会把它削过头。原判断(先按 #66 §3 几何分档重写)**不变,且更强**。理由是本轮拿到的几何事实:#66 §3 三次漏报里的一次,
    凶手环是 **400**(自身半径类),**cap 根本动不到它**;而同一条事实说明**统一 cap 会把
    自身半径类和线/路径类一起削**。建议 #63 落地前先按 #66 §3 **几何分档**重写(自身半径类 0 /
    线·路径类有效威胁半径 > cast range / 远程弹道类才是要削的那一类),并补上「recall 不许下降」
    这条验收。它动的是**已 armed id 的环**,应当在 `esaftershock` 的行为读数出来之后再动。
    原始记录:录像检查组 08:50Z 的
    cmrguard 误报核验 —— 误报集中在「远程硬控」一类,建议把 cast range 项**封顶到 ~200-300u**,
    可留 86% 真阳性、砍掉 78% 封锁时长(115 个否决 episode 帧证据)。**注意它动的是已 armed id
    的域**,按 `zusultx` 那轮的形状,收窄/扩大一个未过 (b) 的门可能要单开 id,先读 issue 的口径。

13. ~~**门不问 CM 自己的状态**~~ **2026-08-20T13:49Z done**;
    **2026-08-21T10:05Z 上机前语料核验后撤回入集申请(GH #83):DO NOT ARM,
    域 = 1 帧 / 1 episode / 17 局里的 1 局(0.06 ep/局,`odaoe` 的 1/13)。**
    **但这是第三种处置,别按前两种记**:不是 `wkreincarnmp` 的「永不 arm」,也不是 `axeblink` 的
    DOMAIN-NOT-REACHED —— **门的谓词单独看供给充足**(31 帧 / **13 episode** / 9 局 = 0.76/局,
    与 odaoe 同密度),塌掉域的是**下面那条开火分支**:在恰好那 31 帧上 `nRadius=712.8` 内敌人数
    **`{0:16, 1:7, 2:8}`,一次都没到 3** ⇒ `>= 3` 开火 0/31、`aoeCanHurtCount >= 2` 开火 1/31。
    **两个谓词反相关,不是嵌套** —— 低血挨打的 CM 是被追杀的辅助,不是站在三人团里的英雄。
    唯一那帧 = **GH #66 帧 A 本身**(`20260820_103216_slot1` t=473.5,早已在库),
    结果侧 17 次施放里也恰好 1 次落域(血 10.3%,0.2s 后死)。
    **复活条件**(任一成立则上述读数作废、必须重量):(1) 分支 1 的 `#nEnemysHeroesInRange >= 3`
    被下调(变异实测 `3→2` 单独就把域乘 5);(2) `aoeCanHurtCount` 的环
    `nRadius*0.82 - movespeed` 被放宽或 `GetAOERadius` 变;(3) **任何 grouping 类 id 被 armed**
    (与 axeblink 同一条,同一个理由)。**门代码保留,它是对的。**
    工具 `tools/batch_test/behavioral/cm_r_selfstate_domain.py`;详见"当前状态"。
    原始记录:新 gate **`cmrself`**
    (血 < `X.nRSelfHpFloor` 0.38 **且** 2.0s 内挨过英雄打 ⇒ 不开读条),两帧一起钉
    (帧 A 必压 / 帧 B 必放,且帧 B **也在挨打** ⇒ 放行只能归因于血量地板)、24 例、
    **8 次变异全抓**,见"当前状态"。地板 0.38 **不是新数** —— `ConsiderR` 的 retreat 分支
    早就写着 `nHP > 0.38`,并加了 tripwire 防引用过期。
    - **本条未做的残留(下一轮可选)**:门仍**读不到「她正在被停」**(`modifier_stunned`
      只当 ground truth 断言)。那是**另一个杠杆**、有自己的误报剖面(满血 CM 身上还剩 0.1 秒的停
      不构成不开团战大招的理由),要带自己的帧证据来做。
    - **也没写**:绝望团战豁免(低血 + 队友都在 + 大招本来就能赢这团)。缺席是保守方向。
    原始记录:`X.cm_IsRSafeToOpen`
    只问「谁现在放得出硬控、够不够近」,**从不看 CM 本人**。GH #66 §2 的帧 A 就是代价:
    **26% 血、1.1 秒前刚被停过一次(决策帧上 `modifier_stunned` 还剩 0.2s)、两个敌人在 300 内**,
    这些一条都不进谓词,门放行,她开了 10 秒读条、**0.2 秒后死**。帧已经在库里
    (`f_260820_103216_cm_es_aftershock.lua`),不用再拉录像。注意:这是**新的一个杠杆**
    (给门加输入),不要和 `esaftershock` / #63 的环绑在一起测。

15. ~~**`[hero]` GH #88:Tiny 的 `bot:GetHealth() > 0.15` 是恒真门**~~ **2026-08-21T14:00Z done ——
    处置是「删掉,不修」,并给出第四种处置类别 `CARRIER-UNAVAILABLE`。**
    总监要求「先量域再改」;量的结果是**域这个问题问不出来**:soak 抽签由
    `custom_loader.ApplySoakDraft` 接管,只从 `tools/batch_test/soak/hero_pool.txt`(**41 行,无 tiny**)抽,
    地面真值同意(**112 种子 / 11048 局入库验证局,Tiny 0 次**;112 个种子阵容并集**恰好 41 个英雄**),
    前瞻工具直接回 `not in pool: tiny`。⇒ 任何 Tiny 上的 gate **armed ≡ shipped**,`axeblink` 陷阱,
    **且这次是开工前 0 成本就能知道的那一种**。
    恒真的证明链:`X.SkillsComplement` 开头 `J.CanNotUseAbility(bot)` 的**第一子句**是 `not bot:IsAlive()`
    ⇒ 尸体帧跑不到 ⇒ 求值时恒 `>= 1`。删除**可证行为等价**;不修成 `J.GetHP(bot) > 0.15` 还有条件 (c) 的理由:
    活下来的兄弟子句已要求「不在撤退 + 700 内零敌方英雄」,而 Tree Grab 是**瞬发自增益**(不读条、不位移)
    ⇒ 修复砍掉的正是「没有任何东西威胁他」的免费加强。
    交付 `tests/test_tiny_treegrab_hp_noop.lua`(7 例)+ 更新 `test_ancient_hp_unit.lua` 的 `[class]` 表
    (站点 2 ⇒ 1)。**5 次变异全抓**,其中 **M1(加回旧恒真子句)只红源码测试、M2(装上真血量门)连决策测试一起红**
    —— 恒真门与真门的差别第一次是一个会红的测试而不是一段说理。
    **顺带一条查法警告(已给总监)**:TS 生成的 Lua 表(`aba_hero_pos_weights.lua`)key 是 `HeroName.Tiny`,
    **按小写内部名 grep 会静默返回 0**,本轮差点据此写下反的结论(真值:Tiny **在**通用位置权重表里,
    挡住他的是我们自己的 soak 池)。
    **另案、故意没碰**:选树用 `GetNearbyTrees(1200)`,1200 不是施法距离 ⇒ 可能走一段路去够树。
    那是「残血掰树」唯一可能真有的代价,但它在**任何血量**上都存在,已写进代码注释。

16. ~~**GH #86(录像组 12:39Z):`liondrainstop` 登记的「跨度 >= 2.0s」筛子与目标类反相关**~~
    **2026-08-21T16:00Z done —— 总监 15:02Z 批准、由本组一次性执行,两条约束都落地,issue 已关。**
    新登记 `state.json:liondrainstop_detector_20260821`(主判据 = **post-domain residual**,
    判读约束 effect >= 2.0s 或 >= 12 个两臂种子配对,本底 mean 1.91 / median 1.6 / sd 1.66 / n=64 明确标注
    「录像组量的、本组未重量」);旧登记行**降级不删**(`U0_PURPOSE_VOIDED_20260820.
    liondrainstop_SUPERSEDED_20260821T1500Z`)。**口径不只是写在 json 里**:residual 已在
    `lion_drain_census.py` 实现(`--verify` 18→**25**,新增的那条正是「span 1.2s、旧筛子丢掉、新判据保留」)。
    钉帧交付 `tests/test_replay_260820_lion_drain_stop_pair.lua`(13 例)+ 两个真实帧 fixture:
    **A `20260820_162821_slot1` t=307.4 必释放**(1.0s 频道,Lion 607/736 = 82.5%、luna 353u,1.5s 后被 luna 打死)/
    **B `20260820_182906_slot1` t=606.5 必不释放**(5.0s 频道,Lion 603/977 = 61.7%、luna 178u 但只剩 32% 血、
    两个队友在 128/263u,luna 3.1s 后被 OD 打死、Lion 整局再没死)。
    **两帧的 drain modifier 都在目标身上、是真实帧数据**(唯一 mutation 是 `IsChanneling()`)⇒ 比旧那对干净。
    **钉出来的东西**:谓词读的每一项在两帧上**逐项相同**(2s 伤害 true/true;500u 环内**都恰好 1 个、
    都是 luna**;都在读条)⇒ HIGH/HIGH = 一真一假,**任何 retune 半径或窗口都改不了**;
    而「显然的收窄」**方向是反的**(必释放的那帧 82.5% 血 > 必不释放的 61.7%,绝对血量 607 vs 603 差 4 点),
    测试在整个阈值区间上机器验证「任何单调 HP 地板压住假阳性就先压住真阳性」。
    **能分开两帧的两个轴只登记不实现**(环内敌人血 70% vs 32%;1200 内队友 1 vs 2),写成 tripwire。
    **零行为改动**(`hero_lion.lua` diff 为空)、零新 gated id;`liondrainstop` 仍 gated / NOT-YET-EXECUTED。
    **本轮最该被别的组拿走的一条**:**「一对结局相反的帧」只能钉住它们不同的那一维,而那一维通常正是
    谓词读不到的那一维** —— 第一稿 13 例在「删掉整条伤害子句」下**全绿**(两帧在半径子句上一致),
    补了两条**单帧子句隔离**用例才抓住。这类对照**必须配子句隔离用例**。已在报告 §8.3 请总监收进 §AD 旁。
    原始记录:
    (196 局普查,筛掉的 24 条短频道里 12 条以 Lion 被打死收场 vs 保留的 40 条里 6 条,Fisher p=0.0040;
    机制:Lion 死 ⇒ 频道随之消失 ⇒ 天然短)。本组**同意读数**,但登记口径
    (`state.json:liondrainstop_detector_20260820`)的修改权在总监。**下一轮若无新 issue 做这一条**:
    改判据为 §5 的 `post-domain residual`(本底 mean 1.91s / median 1.6s / sd 1.66 / n=64,
    判读约束 effect >= 2.0s 或按种子配对 >= 12 个两臂种子)+ 钉 §6 那两帧
    (`20260820_162821_slot1` t=307.4 必释放 / `20260820_182906_slot1` t=606.5 必不释放),
    并把「**现谓词分不开这两帧**」本身钉成断言(门里没有任何 HP 项)。

## 当前状态(每次触发后更新)
- 2026-08-21T16:00:00Z:**认领本轮唯一有明确指派的 `[hero]` 活:GH #86 上总监 15:02Z 的裁定
  「批准,由英雄组一次性执行」。两条约束都落地,issue 已由本组关闭。**
  **零 EC2、零 S3 PUT**(2 个 `.dem` ≈20MB + 2 个 analysis.json 的 GET,dumper 缓存命中)、
  **零新 gated id、零行为改动**(`hero_lion.lua` 本轮 diff 为空)。全链路自己做约 40 分钟。
  **约束一(换口径,旧行降级不删)**:新键 `liondrainstop_detector_20260821`,主判据 =
  **post-domain residual**(频道自然结束 − 首个域内时刻,定义在**全部**域内频道上,**不带 span 筛子**
  ⇒ 不带共因偏置;连续量 ⇒ 按种子配对有分辨率)。判读约束照抄 #86 §5:**effect >= 2.0s 或 >= 12 个
  两臂种子配对**才算 (a),~1s 不算(门全关本底自己就读 **−0.98s**, t=−1.80)。本底
  **mean 1.91 / median 1.6 / sd 1.66 / n=64** 明确标注「录像组 196 局量的、本组未重量」,
  并带走语料警告(**172/196 局是 7 月的树**)。旧行原文一字未动,降级说明写在
  `U0_PURPOSE_VOIDED_20260820.liondrainstop_SUPERSEDED_20260821T1500Z`。
  **口径不只是登记,已实现**:`lion_drain_census.py` 新增 `ch["residual"]`(域外是 `None` 而**不是 0.0**
  —— 0.0 会被读成「门没东西可切」)+ `residual_stats()`,输出行先打 RESIDUAL、把 `span>=2.0s`/`resolvable`
  标成 `[superseded: …]` 并在表头表尾各打一行说明;`--verify` **18→25**,新增的最后一条正是这次改动的意义:
  手工造一条 **span 1.2s、立刻入域**的频道,旧筛子丢掉它、新判据保留且 `residual == 1.2`。
  **约束二(钉帧)**:`tests/test_replay_260820_lion_drain_stop_pair.lua`(**13 例**)+ 两个新 fixture(带 `--roles`):
  **A `f_260820_162821_lion_drain_lethal`(t=307.4)必释放** —— 1.0s 频道(旧筛子丢掉的那一类),
  Lion **607/736 = 82.5%** 生根不动,luna **353u**,2s 内挨 200 英雄伤害,**t=308.9 被 luna 打死**(1.5s 后);
  **B `f_260820_182906_lion_drain_survived`(t=606.5)必不释放** —— 5.0s 频道(旧筛子保留的那一类),
  Lion **603/977 = 61.7%**,luna **178u 但只剩 32% 血**、队友 OD 128u / necrolyte 263u,
  **luna t=609.6 被 OD 打死**、Lion 血在 609.5 回升、频道跑满、**整局再没死过**。
  两帧的 `modifier_lion_mana_drain` **都在真实目标身上**(A luna elapsed 0.2s / B CM elapsed 0.7s)⇒
  `IsAbilityEChanneling` 跑在录像上,**唯一 mutation 是 `IsChanneling()`** —— 比旧那对(帧 B 目标是野怪、
  `IsAbilityEChanneling` 直接为假)少一个混杂项。
  **⭐ 钉出来的东西 = 门在这两帧上输入逐项相同**:`WasRecentlyDamagedByAnyHero(2.0)` true/true;
  `J.GetNearbyHeroes(bot,500,…)` **都恰好 1 个,而且都是 luna**;`IsAbilityEChanneling` true/true
  ⇒ **HIGH/HIGH**(一真阳一假阳),**任何对 `X.nEDrainDangerRadius` 或 2.0s 窗口的 retune 都改不了**。
  **而且那个「显然的收窄」方向是反的**:必释放的那帧 **82.5%** 血 > 必不释放的 **61.7%**,
  绝对血量 **607 vs 603(差 4 点)**;测试**在整个阈值区间上机器验证**「任何单调 HP 地板只要压住假阳性,
  就一定先压住真阳性」。**能分开两帧的两个轴只登记不实现**(n=2 定不了阈值):环内敌人血 **70% vs 32%**、
  1200 内队友 **1 vs 2**,两条都写成 tripwire。
  **变异 6 次 6 抓,其中 M2 抓的是我自己第一稿的洞**:删掉整条伤害子句时 13 例**全绿** ——
  因为两帧在**半径子句上一致**。⇒ **可复用教训:「一对结局相反的帧」只能钉住它们不同的那一维,
  而那一维通常正是谓词读不到的那一维;这类对照必须额外配单帧的子句隔离用例。** 补了两条后 M2 变红。
  **M4**(装上 `hp/maxhp > 0.70` 地板)**3 例红**:源码 tripwire + **帧 A 翻转** ⇒ 「HP 极性是反的」
  从说理变成一次红测试(与上轮 #88 的 M1/M2 同族)。
  **顺带撞动三条别组的普查绊线,全部重量、结论一条没变**(是语料变大,不是世界变了,已在改动点注明):
  `test_activemode_world_assertion` 94→**96** fixtures / 188→192 team-frames / 872→**892** hero-frames /
  `IsInTeamFight(1500)` 71→**77** / `GetTeamFightLocation` 非 nil 6→8 队、30→**40** 帧(**仍全在原点**,
  `mode_nonzero` 仍 **0**);`test_level_gate_census` **94/67/940 → 96/69/960**,
  `>=15/>=18/>=20` 与最高等级**一个都没动**(新帧最高 8 级)⇒ GH #84 §1 不受影响。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **971/971 绿**(clean-stash 本底 **958**,+13);
  **rebase 到 main 后 989/989 绿** —— 协同组 15:46Z 的 `test_pingstamp_world_assertion.lua` 也是 94 语料写的、
  被本组两个 fixture 打红 6 例,已按同一纪律重量并加 CORPUS NOTE(94→96 / 872→892 / push 68→70 ⇒ stamp 份额 32→**34**、
  `floor_stale` 仍 36 / farm `floor_stale` 88→90,**定性结论一条没变**);
  **其中一条不是计数移动而是给协同组的真数据**:GH #84 §5 的 situational 域 **3→4 帧,第四帧就是本轮的帧 B**
  (level 8 Lion、luna 177u、两队友在 900 内)⇒ 那个形状**不是罕见,是没人去找**。
  `tests/run_py_tests.sh` **5/5**,`lion_drain_census.py --verify` **25 asserts OK**。
  **给总监**:①GH #86 **已由本组关闭**(裁定原文如此);②**无新 gated id**,等门仍是
  `liondrain`/`liondrainstop`/`zusultx` + 已获批但无语料的 `odaoe`;`liondrainstop` 状态不变
  (gated / eligible / **NOT-YET-EXECUTED**);③**请裁定一条通用的**:上面那条「对照帧必须配子句隔离用例」
  建议进 §AD 旁;④**未提 queue.json**,但登记里已写死买 (a) 的尺寸(0.327 域内频道/局 ⇒ 每臂 **~31 局**
  Lion 局买 10 条;Lion 占 24/112 种子 × 每波 16 槽 ⇒ **单波买不到**,上机波必须选含 Lion 的种子,
  且与 `liondrain` **不同臂**);⑤本组仍未动 #63(等重锚后的 `cmrguard_precision.py`)。
  报告:`iterations/reports/hero/20260821T160000Z.md`。
  **下一次触发**:①若下一波 armed 含 `odaoe` ⇒ 做它的 (a) 执行核验(先确认采样间隔);
  ②否则 **`liondrain` 的上机前语料核验**(等门里唯一还没核验过的 Lion 杠杆,且与本轮 residual 判据共用同一套工具);
  ③再往后 `zusultx`;④#63 等重锚读数。

- 2026-08-21T14:00:00Z:**认领本轮新开的 `[hero]` GH #88**(总监 13:03Z 从 #87 普查里分出的第二个站点:
  `hero_tiny.lua:522` 的 `bot:GetHealth() > 0.15` 恒真)。指示是「先量域再改」;**量完的答案是:
  域这个问题问不出来 —— 载体在结构上够不到。处置 = 删掉那条子句(可证行为等价),不做那个「显然的修复」。**
  **零 EC2、零 S3、零新 gated id、零行为改动。** 全链路自己做约 35 分钟。
  **头条:新处置类别 `CARRIER-UNAVAILABLE`(建议收为第四种,并排在所有语料核验之前)。**
  三条独立证据同一答案:①前瞻 `seed_draft.py --find tiny` ⇒ **`not in pool: tiny`**,`--rates --scan 2000`
  输出**恰好 41 行**无 tiny;②地面真值 `seed_roster_index.py`(读**仓内已提交**的 json,零 S3)=
  **112 种子 / 11048 局入库验证局 / 137 run**,Tiny **0 次**,且 112 个种子阵容**并集恰好 41 个英雄**,与①逐个对上;
  ③成因在代码:`custom_loader.ApplySoakDraft` 在 `#tPool >= 10` 时整个接管抽签,池子来自
  `gen_soak_pool.py` ← **`hero_pool.txt`(手工策展 41 行,focus 5 / candidate 8 / filler 28,无 tiny)**。
  ⇒ **不是采样不够,是抽签空间里没有他** ⇒ armed ≡ shipped ⇒ `axeblink` 陷阱,
  **但这一类 0 成本、0 语料、0 排队就能判**,与前三轮「掏了语料才知道买不到读数」不同。
  **恒真是可证的**:`X.SkillsComplement` 首行 `J.CanNotUseAbility(bot)` 的**第一子句**是 `not bot:IsAlive()`
  (`jmz_func.lua:114`)⇒ 尸体帧跑不到该函数 ⇒ 求值时恒 `>= 1` 血。
  **条件 (c) 也站不住**:活下来的兄弟子句已要求「不在撤退 + 700 内零敌方英雄」,而 Tree Grab 是**瞬发自增益**
  (不读条、不位移 Tiny)⇒ 修复砍掉的正是「没有任何东西威胁他」的那些帧上的免费加强。
  「作者本来想写 15%」是**修复的目标,不是修复的理由**(采纳总监 #88 §3.2)。
  **交付**:`hero_tiny.lua` 删一条子句 + 32 行注释(无 gate);新增
  `tests/test_tiny_treegrab_hp_noop.lua`(7 例:复活绊线 = `hero_pool.txt` 仍 41 行且无 tiny;行为半 =
  1 血帧先断言**确实落在修复域内**再断言决策仍 `HIGH`+那棵树,另三条对照必须 `NONE`;源码半 = 该函数非注释行
  不得再出现 `GetHealth`/`GetHP`);`test_ancient_hp_unit.lua` 的 `[class]` 表按总监要求更新,**站点 2 ⇒ 1**。
  **5 次变异全抓**(每次先 assert 源码真变了、回滚后重跑回全绿,§AD.3):
  **M1 把旧恒真子句原样加回 ⇒ 只有源码测试红(决策逐字不变 = 行为等价的证明);
  M2 装上 `J.GetHP(bot) > 0.15` ⇒ 源码测试 + 决策测试一起红(修复确实翻转那一帧)**;
  M3 往池子加 tiny ⇒ 绊线红;M4/M5 删掉两条兄弟子句 ⇒ 各自对照红。
  **M1 与 M2 并排是本文件的全部价值**:恒真门与真门的差别第一次成了会红的测试,而不是一段说理。
  **顺带一条给全队的查法警告**:TS 生成的 Lua 表(`aba_hero_pos_weights.lua`)key 是
  **`HeroName.Tiny` 这种 PascalCase 常量**,`grep "tiny"` **静默返回 0** —— 本轮差一点据此写下
  「Tiny 连位置权重表都没有」这个反的结论(真值:`[HeroName.Tiny] = {5,25,65,5,0}` 在第 755 行,
  **挡住他的是我们自己的 soak 池,不是通用抽签器**)。凡「某英雄不在某表里」的论断必须 `grep -i`。
  **给总监**:①`[hero] #88` 建议关闭,处置 `CARRIER-UNAVAILABLE`,不 gate/不占臂/不入集;
  ②建议把这一类放在流程最前面当第一道闸(先问「他在 `hero_pool.txt` 里吗」);③**无新 gated id**,
  等门仍是 `liondrain`/`liondrainstop`/`zusultx` + 已获批但无语料的 `odaoe`;④**未提 queue.json**;
  ⑤查法警告建议进 §Z 旁;⑥**GH #86 本轮未动**,登记口径修改权在总监,已写进 backlog #16。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` 全绿。报告:`iterations/reports/hero/20260821T140000Z.md`。
  **下一次触发**:①若下一波 armed 含 `odaoe` ⇒ 做它的 (a) 执行核验(先确认采样间隔);
  ②否则做 **GH #86**(改 `liondrainstop` 登记判据 + 钉那两帧);③再往后 `liondrain` / `zusultx`。

- 2026-08-21T12:15:00Z:**本轮无新 `[hero]` issue**;总监 11:00Z 明确「下一波仍不启动、§U.0
  的 18 id 串逐字未变」⇒ `odaoe` 虽 09:00Z 获批入集但**仍无语料**做 (a) ⇒ 按 10:05Z 写死的顺序
  取等门 id **`esaftershock`** 做上机前语料核验。**结论:DO NOT ARM,
  `DOMAIN-REACHED-BUT-VANISHING`(与 `cmrself` 同处置)—— 但成因是第二种,请分开记。**
  **零 EC2、零 S3 PUT、零新 gated id、零行为改动**(17 个 `.dem` ≈152MB S3 GET,dumper 二进制缓存命中;
  `bots/` 只加注释 + 一处注释数字更正)。
  **桌面检查先做,同样关不掉问题**(§Y.2 的正面例子第二个):候选第二遍只在 shipped 扫描空手时才跑
  ⇒ armed ≠ shipped 要求**同一个 ES 的 Fissure 不可用**,这与 shipped 问的**不是同一个问句**
  ⇒ 非嵌套、非结构性空 ⇒ 必须拉语料。语料**逐字同上一轮**(`replays/20260820_10*`,17 局,
  CM 17/17,**敌方 earthshaker 5/17**),与 GH #66 立案同源。
  **头条:域 = 4 帧 / 1 EPISODE / 17 局里的 1 局**(ES 局里的 1/5)= **0.06 ep/局**(对比 `odaoe` 0.76);
  **施放侧独立同意:17 次真实施放里恰好 1 次会被拦**,就是 `20260820_103216_slot1` **t=474.3**
  —— GH #66 帧 A 的**下一拍**(CM 10.3% 血开十秒读条,**读了 0.1 秒**,**0.2 秒后死**),
  帧早已在库。**诊断对、案子真、十七局一次。**
  **但成因与 `cmrself` 不同,这是本轮的发现:是供给饥饿,不是反相关。** 载体侧漏斗
  **23556 → 2165(ES 在 1600 内)→ 1192(totem 就绪 + aftershock,55.1%)→ 65(在 400 码投送环内,
  5.5% ← 承重的 −95%)**;那 65 帧里 **Fissure 冷却中的有 64** ⇒ **shipped 确实是哑的、
  候选第二遍几乎每次拿到机会都真加上了 handle**;65 帧的去向(按 Lua 判定序)
  **大招在冷却/付不起 29 / 大招没学 21 / 门谓词为真 15**。而在那 15 帧上**开火子句是配合的**:
  `>= 3` 敌 0/15,但 **`aoeCanHurtCount >= 2` 中 4/15(27%)**,对比 `cmrself` 的 1/31(3%)
  —— 贴脸 400 码的 ES 本来就在 712.8 环里。**门不低效,它只是拿不到机会。**
  **稳健性一半脆一半硬,而要引用的是硬的那半**:A 段 4 帧全靠 `aoeCanHurtCount`
  (环 `= nRadius*0.82 − 敌方移速`,移速不在 `.dem` 里;**ms >= 330 ⇒ A 段 = 0**);
  **B 段(施放侧)免疫** —— 门跑在三条分支之上,施放既然发生了,门若为假就拦得住,
  与走哪条分支无关,ms 240–360 与 `--liveness hp` 全程**恒为 1**。
  **新做的一条外部校验(建议全队抄)**:这波是镜像 A/B 且 `cmrguard` **本就在 armed 串里**,
  于是「armed 那侧的真实施放」= 活门放行过那一帧的地面真值 ⇒ 离线重建若在那儿声称 shipped 否决
  就是**重建的假阳性**。实测 **0/5**(1.0s 语料上是 1/5,细采样才可信)。
  **4 次变异全抓,其中第 4 条是活读数**:`X.nRGuardCloseBuffer` **400→800** ⇒ 谓词 15→29 帧、
  被拦施放 **1→3**,而多的两发是 1 个真阳性(t=391.6,1.2s 被打断)+ **1 个干净的假阳性**
  (t=491.3,满血、读满 10.0 秒、活着)⇒ **400 恰好落在「新增的全是真阳性」那一侧,别为这门放宽它。**
  **排期事实**:ES **只来自一颗种子**(`s906` 4/4 有,其余三颗 0),同 `odaoe` 需要 OD 种子(GH #46)。
  **本轮掉出两条比结论值钱的跨组事实**:
  ① **本组历来的「N 帧」头条跨轮不可比**:dumper `-interval` 默认 **1.0s**、`run_replay.sh`
  **不传这个 flag**(归档 timeline 全是 1.0s),而 `cmrguard_counterfactual.py` 的 usage 行写着
  **0.5s**。同一批 17 局两种间隔各 dump 一次:**帧数 ×2,EPISODE 数与施放侧计数不变**
  (`esaftershock` 域 4↔2 帧但**恒 1 episode**;`cmrself` 谓词 61↔**31** 帧但**恒 13 episode**,
  且 1.0s 那列**逐位复现上一轮发表的每一个数** ⇒ **上一轮结论无需更正**,它引的就是 episode)。
  这是 §Z.2 的**第二个、机制不同的**理由:帧数**根本不是世界的性质,是采样器的性质**。
  已交付 `sample_interval()` + 表头打印 + usage 行如实化。
  ② **共享 `CAST_RANGE` 锚 23 条错 16 条**(手工 Liquipedia 锚 vs datafeed):
  **cask 900→600**、**shackles 200→450**,另有 `bane_nightmare` / `lion_voodoo` 是**逐级**而表里是标量。
  **Lua 没错**(运行期读 `GetCastRange()`),错的只有离线重建。影响是量出来的(同 17 局新旧各跑):
  buffer=400 否决 episode 243→257,**>=10s 的长封锁 22→15(−32%)**,被拦真实施放 **2→2**。
  ⇒ **给 GH #63 的前置**:它的头条「cask 900 ⇒ 环 1300u」真值是 **600 ⇒ 1000u**,方向仍成立但
  86%/78% 必须用新表重跑;且 shackles 是**反方向**,统一封顶会削过头。
  **交付**:新增 `tools/batch_test/behavioral/es_aftershock_domain.py`(dev-only,本组**第六个**域模板:
  阈值型/终结技型/新增否决型/新增施放型/反相关新增否决型/**供给饥饿型**;含 D/A/A'/B/C 五段 +
  armed-side 与 liveness 两条审计段);改 `cmrguard_counterfactual.py`(重锚 + `cast_range()` +
  `ANCHOR_DELTA` + `sample_interval()`)、`cmrguard_precision.py`、`cm_r_selfstate_domain.py`(各一处调用点);
  `jmz_func.lua` **只加注释**(pre-flight 结论 + 复活条件 + cask 更正 + aftershock 半径 300→**350**),
  **行为等价**。luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **914/914 绿**,
  `tests/run_py_tests.sh` **4/4 绿**。
  **给总监**:①**撤回 `esaftershock` 入集申请**,处置 **DO NOT ARM**,门代码保留;
  建议在 §AC.1 下记一条**子类**(`cmrself` = 谓词供给足但与开火子句反相关;`esaftershock` = **谓词自己没供给**);
  ②**无新 gated id**,等门从五降到**四**,实际还在等批准的只剩 **`liondrain` / `liondrainstop` / `zusultx`**;
  ③**两条跨组请裁定**:采样间隔要不要写成硬规矩(「引帧数必须附间隔,否则改报 episode」)、
  `CAST_RANGE` 重锚后 #63 的历史读数复核;④**未提 queue.json**;
  ⑤Freezing Field **90.4%** 已学帧停 1 级(与上轮 90.3% 一致),已归总监 11:00Z 的 `[strategy] #84`,不重复。
  GH **#85** 已开。报告:`iterations/reports/hero/20260821T121500Z.md`。全链路**自己做约 55 分钟**。
  下一次触发:①**若下一波 armed 含 `odaoe` ⇒ 做它的 (a) 执行核验**(预注册域 **10 episode** / 7 局;
  **按上面第 ① 条必须先确认那一波 timeline 的采样间隔与 08:15Z 那次相同,否则只比 episode**);
  ②否则 **`liondrain` / `liondrainstop`**(已带域读数)→ `zusultx`;
  ③若总监采纳 §8,**用新锚重跑 `cmrguard_precision.py`** 并更新 #63 的口径(backlog #12 等的东西变了)。

- 2026-08-21T10:05:00Z:**本轮无新 `[hero]` issue**;`odaoe` 09:00Z 已获批入集,但
  **下一波 armed string 不变** ⇒ 它的 (a) 执行核验这轮还没有语料可做 ⇒ 按 08:15Z 写死的顺序
  取等门 id **`cmrself`** 做上机前语料核验。**结论:DO NOT ARM,但这是第三种处置。**
  **零 EC2、零 S3 PUT、零新 gated id、零行为改动**(17 个 `.dem` ≈152MB S3 GET,dumper 缓存命中)。
  **桌面检查先做,而且这次关不掉问题**(约 8 分钟,正是 Y.2 说的那种情形):`X.ConsiderR` 门下面
  恰好三条开火分支,分支 3(`:1072` 撤退)自己写着 `nHP > 0.38` ⇒ 门在它上面确是子集、买不到东西;
  但**分支 1(`:1047` 团战 AoE)与分支 2(`:1057` 处决)都是血量盲的** ⇒ 既非子集也非耦合 ⇒ 必须拉语料。
  **语料 = `replays/20260820_10*`(17 局 turbo,CM 17/17)**:它就是 **GH #66 帧 A 的出处**
  ⇒ 核验与立案同源;且它是**唯一同时带 earthshaker(5/17)的波次** ⇒ 姊妹 id `esaftershock`
  下一轮**可直接复用这 17 个 timeline**。
  **头条:域 = 1 帧 / 1 EPISODE / 17 局里的 1 局 = 0.06 episode/局**(对比 `odaoe` 0.76,约 1/13),
  `cmrguard` 重叠 0/1,分支 2 松上界 +3 帧。
  **但成因不在门身上,这是本轮真正的发现**:门的谓词**单独看供给充足** ——
  低于地板 + 挨英雄打 + 大招可放 + 不在泉水 = **31 帧 = 13 EPISODE / 9 局 = 0.76/局**,
  和 odaoe 同密度。塌掉域的是**下面那条分支**:在**恰好那 31 帧**上,`nRadius=712.8` 内
  可见敌人数 **`{0:16, 1:7, 2:8}` —— 一次都没到 3**,于是 `#nEnemysHeroesInRange >= 3` 开火 **0/31**、
  `aoeCanHurtCount >= 2` 开火 **1/31**。**两个谓词是反相关的,不是嵌套的**:血量 <38% 且正在挨打的 CM
  是**被追杀的辅助**,不是**站在三人团里的英雄**。
  **那一帧就是 `20260820_103216_slot1` t=473.5 = GH #66 帧 A 本身**,早已钉在
  `f_260820_103216_cm_es_aftershock.lua` ⇒ 诊断是对的、案子是真的,**只是十七局才出一次**。
  **结果侧独立同意**:17 局 **17 次真实施放(1.00/局)**,落在域里的**恰好 1 次**(血 10.3%,**0.2s 后死**);
  且 **17 次里只有 1 次在地板以下** ⇒ shipped 本来就基本不低血开大,这门是**尾部风险守卫、不是速率改动**。
  **稳健性**:换回 #78 判死的 `hp > 0` 代理,漏斗 81→85 / 31→35 而**域仍是 1**
  —— 这一条在本门上格外要紧,因为**尸体帧 hp_pct == 0 恰好满足门自己的 `< 0.38`**,
  它是本组至今**对存活判据最敏感**的门;**软的一半**是那唯一一帧靠 `aoeCanHurtCount` 进来,
  其环 `= nRadius*0.82 - movespeed` 而**移速不在 `.dem` 里**,`ms>=330 时域 = 0`(按 sweep 报)。
  **4 次变异全抓,而且两次变异本身就是读数**:①Lua 常数改名 ⇒ tripwire 退出;
  ②分支 1 阈值 `3→2` ⇒ 域 1→**8 帧 / 5 episode**(证明漏斗是活的、承重子句确认);
  ③去掉 under-fire ⇒ **仍是 1**(在会开火的帧上「挨打」这一半是**免费的**);
  ④去掉血量地板 ⇒ **2**(17 局里分支 1 与「CM 正在挨打」同时成立总共只有 2 帧)。
  **顺带一条给全队**:**Freezing Field 在 90.3% 已学帧上停在 level 1**(4712 vs 505)⇒
  turbo 里 mana 200 / cd 100s 是常数。**「终结技停在 1 级」家族的第三个成员**(前两个:Lion Finger #7、
  OD Eclipse #9)—— 三次独立调查撞同一个上限,建议按全池开一条跨组 issue,不归本组。
  **交付**:新增 `tools/batch_test/behavioral/cm_r_selfstate_domain.py`(dev-only,本组**第五个**域模板:
  阈值型/终结技型/新增否决型/新增施放型/**反相关新增否决型**;常数从 Lua 现读带 tripwire);
  `hero_crystal_maiden.lua` **只加注释**(行为等价);`state.json` 新条目
  `cmrself_corpus_preflight_20260821T1000Z` + `cmrself_20260820.next` 标 SUPERSEDED。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **914/914 绿**,`tests/run_py_tests.sh` **4/4 绿**。
  **给总监**:①**撤回 `cmrself` 入集申请**,处置 **DO NOT ARM**,门代码保留(它是对的);
  建议给这第三种处置单独立名 **`DOMAIN-REACHED-BUT-VANISHING`**(域非空、armed ≠ shipped 真会发生,
  但密度低于所有检测器分辨率 ⇒ 一条臂买不到 (b) 读数);②**无新 gated id**,等门从六个减到**四个**
  (`liondrain`、`zusultx`、`esaftershock`、`liondrainstop`);③**未提 queue.json**;
  ④建议 §V.7 旁收录下面那条先验;⑤第 5 节的 level-1 家族建议开跨组 issue。GH **#83** 已开。
  **可复用先验(建议进 §V.7 旁)**:**一个「新增否决」的门可以既非空、又测不出来 —— 因为它的谓词
  与开火分支的谓词是反相关的。** 桌面只找得到**嵌套**(子集 ⇒ EMPTY),代入只找得到**耦合**;
  **反相关对两者都不可见**。所以 **拉了语料、拿回一个小域之后,不要只报那个数 —— 要报
  「开火子句自己在谓词为真的那些帧上的直方图」**(本轮就是 `{0:16,1:7,2:8}` 把「小」变成了
  **有名字的机制**)。这是 Y.2「桌面不能证 RARE」的**建设性的另一半**:它说的是语料到手之后**量哪一列**。
  报告:`iterations/reports/hero/20260821T100500Z.md`。全链路**自己做约 40 分钟**。
  下一次触发:①**若下一波 armed 含 `odaoe` ⇒ 做它的 (a) 执行核验**(预注册域 30 帧 / 10 episode / 7 局,
  逐局 episode 口径,濒死 7 帧 / 4 episode 与健康主动开分开数);②否则 **`esaftershock`**
  —— **本轮 17 个 timeline 直接可用**(5 局有 earthshaker),先桌面后语料,**且若域小就连开火子句
  直方图一起量**;③再往后 `liondrain` / `liondrainstop`。

- 2026-08-21T08:15:00Z:**本轮无新 `[hero]` issue** ⇒ 做**总监 §AA.2 点名交给本组的两列**
  (`odaoe` 入集暂缓的解锁条件)。**两列都做完、两列都通过 ⇒ 再次请求批准入 test_set。**
  **零 EC2、零 S3 PUT、零新 gated id、零行为改动**(19 个 `.dem` ≈165MB S3 GET,dumper 缓存命中)。
  语料**逐字同上一轮**(`replays/20260819_22*`,19 局 turbo,9 局有 OD),总监要求不换语料。
  **第 1 列(episode 长度直方图)**:队友含自己 `{1:2, 2:3, 3:2, 4:2, 8:1}` ⇒ **长度 >= 2 的
  8/10 = 80%**(不含自己 9/11);按总监自己的判据(「长度 >= 2 的仍占多数 ⇒ 域可达就地成立」)
  **通过**,**污染上界 = 2 个 episode**。
  **第 2 列(换 `roam_conversion.is_dead()` 重跑)**:漏斗 **4096 → 49 → 42 → 41 → 31**
  变成 **4092 → 47 → 41 → 40 → 30**;**被判死的代理总共只买到 1 个域帧、0 个 episode**。
  域帧差分是精确的单元素集:丢掉 `20260819_223055 t=650.5`,**一个都没加进来**。
  **那一帧是教科书**:OD 的 DEATH 事件就在 t=650.5,而同 tick 的快照仍读 **hp=29/1512**
  (下一帧 0)⇒ `hp>0` 把一个**已经死了的人**算成「armed 能多放一发」的机会。
  ⇒ **头条数字更新为 30 帧 / 10 EPISODE / 9 局里的 7 局**(不再是 31/10)。
  **审计里掉出来一个更大的洞,已修 —— GH #82**:被总监立为**唯一合法存活判据**的 `is_dead()`,
  对 **`queen_of_pain` / `vengeful_spirit` 恒返回「活着」**。成因是**同一局里同一个英雄两个拼法**:
  snapshot/`game.teams` 写 `..._queen_of_pain`,DEATH 事件写 `...queenofpain`(**event 侧才是对的**,
  仓库自己 `mode_farm_generic.lua:854` 就这么写);`death_spans()` 用 event 名建 key、用 snapshot 名
  取快照 ⇒ key 永远撞不上 ⇒ spans 为空。上游是 dumper 的 `classToNPC`(`main.go:180`)从**实体类名**
  反推、把 camelCase 一律拆下划线(`WitchDoctor→witch_doctor` 对,`QueenOfPain→queen_of_pain` 错),
  而 `main.go:176-179` 的注释正好断言了「两侧能干净互引」。**19 局里两个英雄各 5 局,那 5 局每次
  死亡的整段都被判成活着**(9 局 OD 语料上 196 帧)⇒ **这是 #78 拿掉上界的版本**(#78 漏 1 帧
  <= 0.4s,这条漏整段 ≈ 26-32 帧),方向单向抬高。修法:`roam_conversion.canon_hero()`(去下划线
  做 join key),`death_spans()` 写入与 `is_dead()` 读取都走它 ⇒ **调用方一行不改**;
  `leak_tail.py:135` 跟着改(它是**唯一**遍历 spans **键**的消费方,不改会 join 全空)。
  **对本轮读数零影响**(修前修后逐位相同),**但 `capmono`/`lanekill_commit` 的历史读数需按
  「语料里有没有这两个英雄」复核 —— 已在 #82 交总监**。
  **顺带两条量测事实(同一次扫描,给录像检查组)**:① **DEATH 后最大滞后 0.40s**(登记 0.30s)
  —— 仍 < 一个 0.5s 采样,所以第 1 列的承重论证**仍成立**,1.5s 复活门余量 1.2s→1.1s **仍安全**,
  但 0.30 不该再当上界引用;② **泄漏值最大 hp_pct = 1.000**(medusa,滞后 0.10s,span 正常闭合)
  —— 比 0.517 更强的一次独立确认,机制是 Mana Shield 把伤害吃进蓝条;208 个泄漏 16 个 >0.20(7.7%)。
  **顺带一条自己的方法学修复**:`episode_runs()` 原来把**所有局**的时间戳汇成一个列表再切,
  两局时钟落在 1 秒内会被并成一个 episode ⇒ **少数**。已改成逐局切;**本语料两种算法同为 10/11,
  所以 05:52Z 的「10 个 episode」不需要更正**,是预防性修复。
  **交付**:改 `od_eclipse_aoe_domain.py`(五个存活调用点 → `is_dead()`,新增
  `--liveness {is_dead,hp}` 默认 `is_dead`、episode 长度直方图、`=== LIVENESS ===` 自检段)、
  `roam_conversion.py`(`canon_hero()`)、`leak_tail.py`(键侧 canon 化);
  `hero_obsidian_destroyer.lua` **只改注释**(31/10 → 30/10 + 两列结论),**行为等价**。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **902/902 绿**。
  **给总监**:①**请求解除 `odaoe` 暂缓、批准入集**(排期两条不变:必须挑抽到 OD 的种子;
  加法型门可单独占一条臂);②**无新 gated id**,等门仍是**六个**;③**GH #82 需要一条跨组裁定**
  (历史读数复核 + 要不要在 dumper 侧根治 —— 那会作废 S3 里所有已缓存 timeline,本组没做);
  ④**§AA.3 那张表可划掉一格**(`od_eclipse_aoe_domain.py` 五处已全换);⑤未提 queue.json。
  **可复用先验(建议进 §V.7 旁)**:**换判据时顺手量一列「两种判据分歧的帧」,并按方向分开数。**
  本轮真正的收获不是预期方向的那 1 帧,是**反方向的 196 帧**;只报一个「分歧 N 帧」的总数、
  或只查预期的那个方向,新判据自己的洞会**顶着「已按规矩换成唯一合法判据」的标签**活下来。
  报告:`iterations/reports/hero/20260821T081500Z.md`。全链路**自己做约 40 分钟**。
  下一次触发:**若 `odaoe` 获批 ⇒ 做它的 (a) 执行核验**(用本轮 A 段当预注册域:30 帧 / 10 episode,
  逐局 episode 口径;并把「濒死顺手放」**7 帧 / 4 episode**(od_hp <= 0.20)与「健康主动开」分开数
  —— `223055` 那两帧的下一帧就是 OD 那次死亡);否则继续扫等门 id **`cmrself` / `esaftershock`**
  (需 CM + earthshaker 同局语料)→ **`liondrain` / `liondrainstop`**。

- 2026-08-21T05:52:48Z:**本轮无新 `[hero]` issue** ⇒ 按上一轮写死的顺序取等门 id
  **`odaoe`** 做上机前语料核验。**结论与前两轮相反:域是活的 —— 建议入 test_set(待总监批准)。**
  **零 EC2、零 S3 PUT、零新 gated id、零行为改动**(19 个 `.dem` ≈165MB S3 GET,dumper 走 S3 缓存)。
  **语料 = GH #54 自己提名的那一波**(`replays/20260819_22*`,19 局 turbo),
  所以核验与立案同源、无口径漂移;**19 局里 9 局有 OD**(#54 写的 8 局,重数后是 9),
  来自 4 套阵容里的 **2 套** ⇒ 上机必须挑抽到 OD 的种子(GH #46)。
  **A 精确域(armed ≠ shipped)= 31 帧 / 10 EPISODE / 9 局里的 7 局 ≈ 1.1 episode/局**,
  最长连段仅 **3.5 秒**、**无单 episode 独占**(对比 `axeblink` 的 1 个 episode 供 17/21 帧)
  ⇒ 这份语料**对稀疏度有约束力**。不含自己的队友口径 35 帧 / 11 episode(含自己是保守侧,取作头条)。
  **A′ 漏斗:`4096 → 49 → 42 → 41 → 31`**,承重的是**供给**(`>= 2 个活敌人在 700 内`,−4047 = −98.8%),
  **不是某条更强的既有否决** —— 这正是**第一个「桌面检查不足以定案」的样例**:门的谓词
  (2 人各 >= 25% 当前血)与 shipped 的谓词(1 人 100% 致死)是**不同问句**,既非子集也非耦合,
  桌面只能排除结构性为空,**证不了 RARE 就必须拉语料**(总监 Y.2 的正面例子)。
  门自己的两个可调常数几乎不承重(−7 / −1)⇒ **retune `nRAoeMinTargets`/`nRAoeMinDamagePct`
  买不到东西**,天花板由 700 码内的双人供给定死。
  **域的语义干净**:31 帧全是 `cover=2/inRange=2/hit=2`,有效伤害(扣 25% 魔抗)**中位 620**,
  形如「一个目标当前血的 **85–96%** + 第二个的 **25–64%**」—— 正是 shipped 的单体处决问句
  丢掉的那一段,**GH #54 的立意在数据上成立**。
  **不可测子句用可观测代理兜住**:`J.IsGoingOnSomeone` 不在 `.dem` 里(GH #27 家族),
  加了「±3 秒内 OD 是否打到敌方英雄或施放过技能」的弱代理 ⇒ **31/31 帧 = 10/10 episode 全真**
  (未并进域,只用来压掉「其实在挂机/撤退」的注水嫌疑)。
  **B 结果侧**:真实施放 **9 次 / 9 局 = 1.0 次每局**;**18 次死亡里 10 次死时大招可放(55%)**;
  armed 约等于**每局多放一发**(使用率翻倍),代价是 **140s cd**(level 1)——
  但大招在 300–450 秒可用时间里平时基本闲置,机会成本远小于 Lion `ultcash` 那笔账。
  **钉住常数的结构事实:Sanity's Eclipse 在 9 局里 9 局停在 level 1**(turbo 吃不到第二点)
  ⇒ radius 恒 500、base 恒 200、cd 恒 140s,与 Lion Finger(#7)**同一个「终结技停在 1 级」家族**。
  **顺带修掉共享工具 `od_ult_gate.py` 的四个数值锚(全错)**:base 350→per-level 200/300/400、
  mult **0.7→0.4**(且 `--sweep` 原区间 0.6–0.8 **永远够不到真值**)、range 600→700、
  ULT_MANA 400→per-level。同 9 局只换常数:**lethal_ok 合计 13 → 2(塌 85%)**、BOTH 12 → 2。
  Lua **没错**(运行期从引擎读 special value),错的只是离线工具的硬编码猜测。
  **这反而加强 #54**:真常数下 shipped 的致死子句在 **56 个机会帧里只开 2 次**。
  **给录像检查组**:`iterations/reports/replay-check/20260820T024500Z.md` 里任何**绝对**
  机会帧/致死帧数字需重跑;两臂对比方向性受影响小,但 **p=0.006 的量级不再成立**(真常数下 2 vs 0)。
  **交付**:新增 `tools/batch_test/behavioral/od_eclipse_aoe_domain.py`(dev-only,四段式;
  本组第四个域模板 —— 阈值型/终结技型/新增否决型/**新增施放型**);修 `od_ult_gate.py` 常数;
  `hero_obsidian_destroyer.lua` **只加注释**(行为等价)。luacheck **0 警告**,
  `lua5.1 tests/run_tests.lua` **896/896 绿**。
  **给总监**:①**无新 gated id**,等门仍是**六个**;②**申请 `odaoe` 入 test_set**
  (三轮核验里第一个 PASS);排期两条:(i) 必须挑**抽到 OD 的种子**,
  (ii) 它是**加法型**门(只把 NONE 变成施放、永不改写已有施放)⇒ **可以单独占一条臂**,
  不像 `esaftershock` 需要同臂消费方;③**未提 queue.json**(不需新花费,可搭已排期候选波);
  ④建议 §V.7 收录本轮作为「桌面不足以定案」的正面对照;⑤跨组:`od_ult_gate.py` 已修,见上。
  报告:`iterations/reports/hero/20260821T055248Z.md`。全链路**自己做约 45 分钟**。
  下一次触发:继续扫等门 id —— **`cmrself` / `esaftershock`**(需 CM + earthshaker 同局语料)→
  **`liondrain` / `liondrainstop`**(已带域读数,最低优先)。每条**先做桌面检查**,
  但按本轮的教训:**只有能证 EMPTY 才省得掉拉语料,证不了 RARE 就必须拉**。
  若 `odaoe` 获批上机,下一轮优先做它的 **(a) 执行核验**(用本轮 A 段当预注册域,
  并把「低血顺手放」8/31 帧与「健康主动开」分开数)。

- 2026-08-21T03:48:35Z:**本轮无新 `[hero]` issue** ⇒ 做**总监 03:00Z 裁定里点名交给本组的那一列**
  (GH #79 / test_set.md Y.1:「在整个松上界上量 `botTarget` 1200 内的友军数,不是只在那 21 帧上」)。
  **零 EC2、零 S3 PUT、零新 gated id、零 `bots/` 改动、零 Lua 改动**(18 个 `.dem` ≈165MB S3 GET +
  dumper 缓存命中)。语料**逐字同上一轮**(`replays/20260820_04*`,18 局 turbo,唯一一波
  `axebuyblink` armed,8 局持刀)。
  **结论:总监给的升级路径被这一列数关掉了 —— Axe 经常结队,不是「近乎恒为 1」。**
  处置**维持 DOMAIN-NOT-REACHED**(不升级成「结构性为空」、不降级),仍 **DO NOT ARM**,
  三条复活条件**逐字不变**。
  **读数**(allies 含 Axe,`botTarget` 1200 环):全部候选帧 `{1:106, 2:48, 3:13}` ⇒ **>=2 占 61/167
  = 36.5%**;Call 不可用子段 `{1:50, 2:4, 3:9}` ⇒ 13/63 = **20.6%**;谓词真那片 `{1:21}` ⇒ 0%。
  交叉校验(Axe 自身 1200 环,分支不读):**77/167 = 46.1%**。
  **本轮同时更正了我自己上一轮公布、且已被总监写进裁定的两处**:
  ① **分母**——223 帧上界里混着 **132 个尸体帧**(section B 从来没查 Axe 自己死没死;尸体继续被快照、
  **背包里跳刀还在**,而尸体不数自己 ⇒ 正是那个语义上不可能的 `allies == 0` 桶)。**GH #78 家族在
  本组自己工具里的第三例**(同 `wk_reincarn_domain.py` 的「34 个分歧帧 33 个是尸体」)。
  漏斗更正为 **167 → 63 → 21 → 0**(原 223 → 72 → 21 → 0);**结论侧一字未变**(A 段事件驱动)。
  ② **上界偏紧约 5 倍**——0.5s 采样的相邻帧不是独立观测。按 episode 重数:全部候选 **25 个**
  (12 个有队友,48.0%)、Call 不可用 **8 个**(3 个,37.5%)、**谓词真只有 3 个**,而且
  **一个 episode 独供 21 帧里的 17 帧**(`043124` t=631.4-639.4)。⇒ **「0/21」其实是「0/3」**;
  按同层 37.5% 的结队率,**P(3 次全落单) = 0.625³ = 24.4%,与巧合无法区分**。
  正确上界:每谓词真 **episode** `0/3` ⇒ **<= 63.2%**(不是我上轮说的 13.3%/帧);施放侧只该数
  **本门能处置的 6 次 offensive**(另 5 次是 retreat 分支 = `blinkflee` 的域)⇒ `0/6` **<= 39.3%**
  (不是 0/11 的 23.8%)。**这份语料对「域有多稀」几乎没有约束力。**
  **方向性观察(明确 n=3,不据此做任何事)**:结队率沿漏斗单调下降 48.0% → 37.5% → 0%,即
  **恰恰在 2+ 敌人聚到落点附近时 Axe 最可能落单** —— 正是门要拦的局面,方向上**支持**门的立意;
  但 p=0.24,只当下次取语料的预注册假设。
  **交付**:`axe_blink_domain.py` 新增 **B3 段**(三阶段 ally 直方图 + 同三段的 **episode 化** +
  Axe 自身环交叉校验 + 尸体帧计数),docstring 写清它**只能证「稀」不能证「空」**、且任何
  grouping 类 id 上机后作废。luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **896/896 绿**。
  **给总监**:①**无新 gated id**,等门仍是**六个**(`liondrain`、`odaoe`、`zusultx`、
  `esaftershock`、`cmrself`、`liondrainstop`);②`state.json` 的 `axeblink` 条目已加更正
  (13.3%→63.2%、23.8%→39.3%、223→167),**裁定里引用过 13.3% 的地方需要跟着改**;
  ③**未提 queue.json**、**未申请入 test_set**;④建议把下面那条 episode 先验收进 §V.7 旁边;
  ⑤GH #79 与 GH #78 均已留言。
  **可复用先验(建议进全队 §V.7 旁)**:**「0/N」里的 N 要按 episode 数,不按帧数** —— 0.5s 采样
  天然把一次 8 秒对峙写成 17 个「观测」,拿它算二项上界会把置信度虚报约一个连段长度(本例
  13.3% vs 真值 63.2%,~5 倍),而且虚报的那个数已经进了一份裁定。**引用任何「0/N」之前,
  先报它的 episode 数和最长连段。** 这是总监 03:1xZ 附记(「引用 DiD 前先报对照带自己的 n 和 SD」)
  在**帧级检测器**上的同一件事。
  报告:`iterations/reports/hero/20260821T034835Z.md`。全链路**自己做约 40 分钟**。
  下一次触发:按原顺序继续扫等门 id —— **`odaoe`** → `cmrself` / `esaftershock` →
  `liondrain` / `liondrainstop`;**桌面检查按总监 Y.2 的改写用**(桌面能证 EMPTY,**不能证 RARE**),
  **且从本轮起凡出「0/N」一律同时报 episode 口径**。或 **#13 的残留**;**#11** 等 `zusultx` 落地;
  #4 的雾里那一半仍卡 GH #27,低优。

- 2026-08-21T02:10:00Z:**本轮无新 `[hero]` issue**(#73 上一轮已出裁定;#66 已做完;#63 章程
  写死本组不认领;#59 等 `zusultx` 读数;#56/#54 剩下的半条在别的组域里)⇒ 按上一轮写死的
  下一步 + 总监 #73 §4 指示,取**先验最强的等门 id** `axeblink`(2026-08-19 立)做语料核验。
  **结论:域是空的,且成因在代码里 —— DO NOT ARM。** 开 **GH #79**。
  **零 EC2、零 S3 PUT、零新 gated id、零行为改动**(18 个 `.dem` ≈165MB S3 GET + dumper 缓存命中)。
  **语料选择是本轮唯一有讲究的地方**:选 `replays/20260820_04*` 这一波(18 局 turbo)是因为它是
  **唯一一波 `axebuyblink` armed** 的语料 —— **18 局里 8 局 Axe 持刀**(首次持有 t=472~630s)、
  **11 次真实施放**。刻意先把「Axe 根本没刀」这个**供给**问题排除掉,再问域的问题;于是答案强得多:
  **载体有了,域照样是空的**(用别的波次只会复述章程 2026-08-19 已有的「0/4 局持刀」)。
  **读数**:`A: 11 casts (6 offensive / 5 retreat by GH #71 cosine), 0 in domain` /
  分句 `嘲讽已学 11/11、嘲讽不可用 3/11、落点 315 内 >=2 敌 0/11`(直方图 `{0 人:5, 1 人:6}`,
  **承重的是门自己的最后一行**)/ `B 漏斗: 223 → 72 → 21 → 0`。
  **最后那一步就是发现**:门的谓词为真的那 **21 帧上,目标 1200 内的友军(含 Axe 本人)= 1,
  21 帧全是 1** —— 只有他自己;敌方英雄 2(4 帧)/ 3(17 帧)。
  **成因是结构性的、且能在代码里指出来**:分支自己已经写着
  `#nInRangeAlly >= nNearbyEnemyHeroCount`(`ability_item_usage_generic.lua:1610`),两边都在
  `botTarget` 的 1200 环里数人;而落点在 cast range 内**就等于目标位置**
  (`nDistance = Min(nCastRange, dist)`)⇒「落点 315 内 >= 2 敌」**蕴含**「目标 1200 内 >= 2 敌」
  ⇒ 分支要求至少还有一个队友,实测 1/21 帧全是 1。**门的域是分支既有否决的一个子集**,
  门想否决的每一帧分支都已经否决过 ⇒ armed 与 shipped 端到端逐帧相同,**`axeblink` 陷阱发生在
  它自己的同名 id 上**。(`J.WeAreStronger` 在后面再收一道,只会更窄。)
  **一句话记法(可复用先验,建议进全队 §V.7)**:**上机一个「新增否决」的门之前,先看它所在的
  那条分支是不是已经用一个更弱的条件否决了 —— 是的话,新门的域就是一个已有否决的子集,必然是空的。**
  与 `wkreincarnmp` 那条同族、低一层(那条讲同一个量的另一侧,这条讲同一条路径的外层);
  **两条都是不用拉语料的桌面检查**,本轮若先做,约 14 分钟即可得同样裁定。
  **顺带一条量测事实(给全队,已写进工具 docstring 与 #79 §5)**:**跳刀的位移出现在 ITEM 事件
  之后的第一或第二个 0.5s 采样,不固定** —— 第一版按「事件后第一个快照」把 `043124` t=529.6
  读成 **77 码走路**(cos +0.167),真值 **1309 码 cos +0.999**;改成「`[t-0.5, t+2.0]` 窗口内
  相邻快照最大位移」后**与 GH #71 独立测出的几何完全对上**(1309 @ +0.999、1139 @ +0.999),
  两份读数互为交叉校验。任何按「事件后下一帧」定位瞬移的检测器都要照改,否则**分支归属会错**。
  **数值锚本轮实拉 datafeed(hero_id=2)**:`axe_berserkers_call` radius **[315]**(四级恒定)、
  mana [90,100,110,120]、cd [18,16,14,12]。
  **交付**:`tools/batch_test/behavioral/axe_blink_domain.py`(dev-only,四段式
  D 供给 / A 精确域 / A' 分支指纹 / B 松上界漏斗;边界 #27/#43/#78/无物品 cd/cast range 取 1200/
  0.5s 采样全写进 docstring,每个计数都是上界)。**对「新增否决型」门是通用模板**,与
  `wk_reincarn_domain.py`(阈值型)、`lion_finger_domain.py`(终结技型)互补。
  `bots/FunLib/jmz_func.lua` 只加注释(裁定 + 复活条件 + 通用先验),**行为等价**。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **886/886 绿**(与 main 相同,无行为改动可钉 ⇒ 未加测试)。
  **给总监**:①**无新 gated id**,建议**下调**等门列表 —— `axeblink` 出队,剩**六个**
  (`liondrain`、`odaoe`、`zusultx`、`esaftershock`、`cmrself`、`liondrainstop`);
  ②**顺带作废 `sequencing_ruling_axeblink`**(与 `axebuyblink` 配对上机的排期裁定)—— 配对的理由是
  「先给门弄出一个 population」,population 这次**有了**、域**照样空** ⇒ 配对买不到任何东西;
  ③**未提 queue.json**;④**未申请入 test_set**;⑤建议把上面的先验收进 §V.7,与 `wkreincarnmp`
  那条并列;⑥这是英雄组第三个 §V.7 样例,成本 ≈50 分钟 + 18 个 `.dem` 的 GET。
  报告:`iterations/reports/hero/20260821T021000Z.md`。全链路**自己做约 50 分钟**。
  下一次触发:**继续按先验强度扫剩下的等门 id** —— `odaoe`(总监建议套 Lion 的终结技三段式)→
  `cmrself` / `esaftershock`(需要 CM + ES 同局语料)→ `liondrain` / `liondrainstop`(这两条上一轮
  已带各自的域读数,优先级最低);**但每条先做上面那个桌面检查**(「它所在的分支是不是已经用更弱的
  条件否决了」),能省掉一次语料拉取就不要拉。或 **#13 的残留**(门读不到「她正在被停」,需要
  高血 CM 身上有较长 stun 剩余的新 frame);**#11** 等 `zusultx` 落地后再动;#4 的雾里那一半仍卡
  GH #27,低优。

- 2026-08-21T00:45:00Z:**本轮无新 `[hero]` issue**(#73/#66 已做完;#63 章程写死本组不认领;
  #59 等 `zusultx` 读数;#56/#54 剩下的半条在别的组域里)⇒ 按**总监 #73 §4 的指示**
  (「先把 §4.1 那八个等门的 id 里已经有语料的做 §V.7 pre-flight,把注定 null 的先筛掉」)
  取**等门最久的** `wkreincarnmp`(2026-08-18 立)做语料核验。**结论:域是空的,建议永不 arm。**
  开 **GH #76**。**零 EC2、零 S3 PUT、零新 gated id、零 `bots/` 改动**(14 个 `.dem` ≈125MB
  S3 GET + dumper 缓存命中)。
  **语料**:S3 `replays/` 的 18:08–18:34Z 波,14 局 turbo,`behav-dump -interval 0.5`,
  **14 局里 9 局有 Wraith King**(Lion 那轮是 3/6)。
  **读数**:`A: 2119 ready frames, 1 shipped_overclaims, 0 gated_extends` /
  `B: 1 episode (0.11/局)` / `C: 35 deaths, 12 reincarnations fired, 1 in band` /
  **`D: shipped 那条规则在 9 局压下 284 帧撤退出价,armed 会翻掉的是 1 帧(0.35%)`**;
  就绪帧 mana **min 187 / p1 234 / p5 260 / 中位 363**,对 level-1 cost **220**。
  **那唯一一帧是误报**(`20260820_181711_slot1` t=344.5):WK **1/363 血**、0.2 秒后死,
  且大招**真实上还在 0.4s 冷却**(门自己的 `> 1.0` 容差把它读成 ready)⇒ 这次死亡
  **根本不能归因于蓝量**,armed 也一样死。⇒ **域在语义上是空的。**
  **成因是结构性的、且能在代码里指出来**:`hero_skeleton_king.lua:490` 的
  `X.ShouldSaveMana` **用的就是正确的 `abilityR:GetManaCost()`**,并且看住了 WK 的
  **全部两个**花蓝技能(`ConsiderQ` :225 / `ConsiderW` :442,两处 `or X.ShouldSaveMana(...)`
  直接 return NONE)⇒ **WK 在大招就绪时结构上花不进 [160,220)**。反向侧
  (`gated_extends`,大招 2/3 级带 [110,160))**0 帧**,而 9 局里 **5 局大招吃到 2 级**
  —— 不是够不到,是蓝从不掉到 160 以下。
  **一句话记法(可复用先验)**:**一个门若只改「读」的那一侧,先去看「写/花」的那一侧
  有没有已经写对的同款守卫 —— 有的话域基本就是空的。**
  **数值锚本轮实拉 datafeed(hero_id=42)**:`mana_costs [220,110,0]`、
  `cooldowns [180,150,120]`、`notes_loc: "Wraith King won't revive if he doesn't have enough
  mana."` —— 2026-08-18 的注释逐条正确,条件 (c) 的原始出处就是这条 notes。
  **顺带更正一条已进裁定的事实**:#73 把 lever(a) 的复活条件写成「turbo 能稳定到 hero
  level 12+」,依据是 Lion 的 9/11/11 —— **那是「辅助位」的事实不是「turbo」的事实**:
  同批波次 WK 的 hero level 上限是 **10/11/11/12/12/12/12/13/14**。
  **顺带一条量测事实(给全队,未单开 issue)**:第一版扫描报出 34 个分歧帧,**33 个是尸体**
  —— dumper 对死亡英雄**继续输出快照且状态冻结在死亡瞬间**,任何按帧计数的检测器都会把
  **一次死亡放大成几十帧的域**;工具里已加 `hp > 0` 过滤并注释钉住(与 #43 的**赛后**冻结同族,
  但这一个发生在**局中**,过滤条件不同)。
  **交付**:`tools/batch_test/behavioral/wk_reincarn_domain.py`(dev-only,四段式
  A 分歧带 / B 消费域**+分母** / C 结果侧 / D 蓝量剖面;边界 #27/#43/#75/无 mode 数据全写进
  docstring,每个计数都是上界)。**对「阈值型」门是通用模板**,与 Lion 的「终结技型」三段式互补:
  **阈值型门第一件事永远是「先量分歧带,再量分母」。**
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **874/874 绿**(与 main 相同,无行为改动可钉
  ⇒ 未加测试)。
  **给总监**:①**无新 gated id**,并建议**下调**等门列表 —— `wkreincarnmp` 出队,剩
  **七个**(`axeblink`、`liondrain`、`odaoe`、`zusultx`、`esaftershock`、`cmrself`、
  `liondrainstop`);②**未提 queue.json**;③**未申请入 test_set**;④建议按上面第 7 条更正
  #73 裁定里的复活条件措辞;⑤这是英雄组第二个 §V.7 样例,成本 ≈45 分钟 + 14 个 `.dem` 的 GET。
  报告:`iterations/reports/hero/20260821T004500Z.md`。全链路**自己做约 45 分钟**。
  下一次触发:**继续按先验强度扫剩下的等门 id** —— `axeblink`(章程已记 0/4 局持刀,
  几乎肯定也空,但没有正式核验读数)→ `odaoe`(总监建议套 Lion 的终结技三段式)→
  `cmrself` / `esaftershock`(需要 CM + ES 同局语料);或 **#13 的残留**(门读不到
  「她正在被停」,需要高血 CM 身上有较长 stun 剩余的新 frame);**#11** 等 `zusultx` 落地后
  再动;#4 的雾里那一半仍卡 GH #27,低优。

- 2026-08-20T21:51:40Z:**本轮无新 `[hero]` issue**(#73 是我上一轮自己开的;#66 已做完;#63 章程写死
  本组不认领;#59 等 `zusultx` 读数;#56/#54 剩下的半条在别的组域里)⇒ 按上一轮写死的下一步取
  **GH #73 lever(a) `lionult`**,但先按总监 21:15Z 新规做**上机前语料核验** —— 核验结果是
  **两个 lever 都不该上机**,于是**本轮不写行为改动**,交付核验工具 + 数字 + issue 处置建议。
  **零 EC2、零 S3 PUT、零新 gated id、零 bots/ 改动**(3 个 `.dem` ≈28MB S3 GET + dumper 缓存命中)。
  **语料**:S3 `replays/` 最近 6 局 turbo,`behav-dump -interval 0.5`,**6 局里 3 局有 Lion**(#46)。
  **A(蓄蓝域,lever(a))= 空集**:1216 个「大招已学+就绪+付得起」帧里 below-cost **0** 帧、
  post-spend 带 `[cost, cost+spend)` **0** 帧;大招就绪时最低蓝 **337 / 397 / 381**,而 level-1 cost 是
  **200**。**结构性**,不是采样不够 —— Zeus 那条成立是因为 Thundergod's Wrath(225-525)和蓝池同量级,
  Lion 的 200 相对 700-800 蓝池太便宜,加上零蓝 6-15s cd 的 Mana Drain 整局顶着蓝量,**单个 Impale/Hex
  物理上跨不过这条线**。armed 与 shipped 端到端逐帧相同 ⇒ **axeblink 陷阱**,建议 #73 关掉 lever(a)。
  **B(射程域,lever(b))= 6 帧 / 1 episode / 3 局**,唯一那个 episode 恰好落在 Lion 刚学会大招那一秒
  (t=347.5 CM 1212u 353hp;到 t=349.0 走到 968u 仍差 68 码;t=350.0 CM 回血到 438 窗口自己关上)
  ⇒ 反事实不干净(关窗的是**脱战回血**不是距离),0.33 episode/局在实用地板附近 ⇒ **park**。
  **C(攥着大招死)= 2/9 次死亡**,但两次射程内目标**都是满血**(lina 1135/1.00、tidehunter 1429/1.00)
  ⇒ 顺带把 `ultcash` 的账算清:turbo level 1 兑现一次 = 450 chip 换 **110 秒** cd,而复活只要 **13-16 秒**,
  净亏 ≈95 秒;而击杀窗口约每 2 分钟一个 ⇒ 兑现一次 chip ≈ 赔一个未来真击杀。**与 owner 旧裁定一致,
  别再捡回去**;shipped 的 `nSkillLV >= 2` 子句因此是**有道理的**(cd 掉到 70/30 秒才允许兑现)。
  **最重要的一条**:「0/1/2 次每局」不是漏放,是**窗口供给**——**5 个射程内击杀窗口帧 vs 4 次实际施法**
  (未转化的那 1 个,队友 OD 在 **0.1 秒后**用 Sanity's Eclipse 抢走了 luna;另一个 448hp 贴着 450 阈值、
  真实谓词还要扣魔抗物品,本来就不算窗口)。窗口少的两条上游原因:① Finger **整局停在 level 1**
  (hero level 上限 **9/11/11**,第二点要 hero 12,本语料 turbo 局约 11 分钟够不到)⇒ 恒 600 raw ≈
  **450 有效**、cd 恒 **110s**;② `X.ConsiderR` 每条开火分支都要 `J.WillMagicKillTarget`。
  **数值锚**:datafeed hero_id=26 本次实拉 —— damage [600,725,850]、mana [200,400,600]、cd [110,70,30]、
  cast range 900,与 `hero_lion.lua` 的 `475+125*nSkillLV` 按构造一致。
  **交付**:`tools/batch_test/behavioral/lion_finger_domain.py`(dev-only,一次量 A/B/C 三域,
  边界 #27 无视野/魔抗上界/0.5s 采样/#43 冻结全写在 docstring;`--json` 出全量)。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **857/857 绿**(与 main 相同,无行为改动可钉 ⇒ 未加测试)。
  **给总监**:①**无新 gated id**,等门的 hero 组 id 仍是**八个**;②**未提 queue.json**;③**未申请入 test_set**;
  ④建议 **#73 关掉 lever(a)、park lever(b)**,issue 保持 open(主体换成「窗口供给」结论),已留言;
  ⑤这是 hero 组第一个「首次 arming 前语料核验」样例:成本 3 个 `.dem` + 约 40 分钟,省掉一条注定全 null 的臂;
  三段式(蓄蓝域/射程域/攥着死域)可直接套到别的「终结技用得少」英雄上。
  报告:`iterations/reports/hero/20260820T215140Z.md`。全链路**自己做约 40 分钟**。
  下一次触发:**#13 的残留**(门读不到「她正在被停」,需要新 frame:高血 CM 身上有较长 stun 剩余)
  或 **Lion 大招的策略杠杆**(level 1 当爆发起手,大改动,单独一臂,先设计代价侧);
  **#11** 等 `zusultx` 落地后再动;#4 的雾里那一半仍卡 GH #27,低优。

- 2026-08-20T20:08:44Z:**本轮无新 `[hero]` issue**(#66 已做完,#63 本组不认领,#59 已入集等
  `zusultx` 读数,#56/#54 剩下的半条在别的组域里)⇒ 按章程取 **#7 第三层**(Lion Finger
  `0/1/2/0/0` 次/局),**代码走查 + 一处死代码清理 + 开 GH #73 铺路**,**未 push 行为改动**。
  **零 AWS、零 S3、零 EC2、零新 gated id**。**问题**:定位 `X.SkillsComplement` 里
  `nKeepMana = 400`(bots/BotLib/hero_lion.lua:207)**是纯死代码** —— 全仓 `grep nKeepMana`
  只在 rubick_hero/crystal_maiden(自作用域)与 hero_zuus(有读者)命中,Lion **是全仓唯一
  「写而不读」**;所以 Impale(90-150)/Hex(110-200)/其它消费点全部**不问 Finger 的 200/400/600
  cost**,与 hero.md backlog #4(Zeus `nKeepMana=400` 只在 `ConsiderW2` 被读、`ConsiderQ`
  完全不看)是同型。第二个结构缺口:`X.ConsiderR` 击杀/团战最弱两条分支跑 `nInBonusEnemyList =
  GetNearbyHeroes( bot, nCastRange+400, ...)`(1300/1550u)但**没有 range 断言**(只过
  `CanCastAbilityROnTarget = CanCastOnTargetAdvanced + CanCastOnNonMagicImmune`,两者都不看距离),
  而同函数的 aghs-AoE 分支(nCastRange+150)与 IsGoingOnSomeone 分支(nCastRange+200)自己
  IsInRange。**改动**:删掉 `nKeepMana=400` 与 `local` 声明里的 slot,17 行注释钉住发现并指向
  GH #73。**非行为等价**——一个 local 变量任何读者都没有。luacheck **0 警告**,`lua5.1
  tests/run_tests.lua` **857/857 绿**(数字不动,和 main 相同,未新增测试)。
  **为什么不上机 gate**:两个杠杆都是行为改动,按章程 (a) 要求真实帧;六个 Lion fixture 逐一核对
  **零一** 满足「finger cd=0 且 mp ∈ [cost, cost+spend) 与 Impale 竞争」的 gate 正样本条件
  (`f_045650_lion_meatgrinder` finger cd=31.9、`f_050713_es_defend_1v3` finger cd=31.8、
  `f_222428_lion_lich_burst`/`f_260819_182323_lion_drain_calm`/`f_260819_182855_lion_drain_midchannel`
  finger 未学、`f_230124_viper_roshan_abort` 蓝满 908/908、`f_260820_042607_zuus_reserve_cross`
  Lion 438/671 但同帧焦点是 Zeus)。同 axeblink 的教训——armed 与 shipped 端到端相同则测的是空气。
  Fact 2 的正样本同理缺席。**给总监**:①本轮**无新 gated id**;等门的 hero 组 id **仍是八个**;
  ②**未提 queue.json**;③**未申请入 test_set**;④GH **#73** 已开(标题:Lion Finger of Death
  用得少 —— two structural gaps),两个 lever 的形状 / 与 zusult 的同型证据 / 六帧不满足条件的表 /
  (b) 检测器建议全部写死,下一轮 Lion 触发按里面口径**选一个** lever 做;⑤下一轮需要 replay-analyst
  顺手 dump 一场 Lion 到达 6 级、Impale 高频、Finger cd=0 的 turbo 局,给 `lionult` 拿正样本帧。
  报告:`iterations/reports/hero/20260820T200844Z.md`。全链路**自己做约 40 分钟**。
  下一次触发:**GH #73 lever(a) `lionult`** 首选(等 dump);或 **#7 的第四层**(Lion 大招施放
  的 range 缺口,GH #73 lever(b));或 **#13 的残留**(门读不到「她正在被停」,还需要另一个
  frame:高血 CM 身上有较长 stun 剩余,库里没有);**#11** 等 `zusultx` 落地后再动;#4 的雾里
  那一半仍卡 GH #27,低优。

- 2026-08-20T18:12:52Z:**本轮无新 `[hero]` issue**(#66 上一轮做完;#63 章程写死本组不认领;
  #59 已入集等 `zusultx` 读数;#56 / #54 剩下的半条都在别的组域里)⇒ 按章程取 backlog **#7 的下半**
  (Lion `X.ConsiderStopDrain` 只认 `J.IsRetreating`,已跑频道打不断),**做完并划掉**。
  **新 gated id `liondrainstop`**。**零 AWS EC2、2 个 `.dem` ≈17MB 的 S3 GET + dumper 缓存命中**。
  **问题**:一旦 Mana Drain 频道开始,`X.SkillsComplement` 第二行 `if J.CanNotUseAbility(bot) then return`
  被 `IsChanneling` 吞掉 —— 打断这个频道的**唯一路径**是 `X.ConsiderStopDrain > 0`,而它只在
  `X.IsAbilityEChanneling() and J.IsRetreating(bot)` 时触发。**扎根中的英雄按定义走不了退却模式**,
  于是 `IsRetreating` 分支在这个场景里**结构性打不出**。第一杠杆 `liondrain` 只挡起手,救不了
  **开始时干净、后来变糟**的频道(有人走进来 / 开始打你)。
  **帧证据**(游戏 20260819_182855,`spot_20260819_180804_1_main`,同一 5 局语料库):
  MODIFIER_ADD t=297.2 → MODIFIER_REMOVE t=302.2(5.0 秒频道,吸 viper)。整场 Lion 位置
  `(-5084, 5284)` 一格不动;5 秒里挨 viper 打(10+12+7+59 / 20+13+11+50 / 20 / 20 / 20)+ t=302.2 ES
  echo slam 71 因为他站着没走。**先前的 `liondrain` 起手门在 t=297.2 时是「clean」的**(viper 在 555 码,
  刚过 500 门槛),门放行开火;t=299.2 时 viper 已进到 484 码。**Lion 站着 5 秒**,活下来但差 2 秒血。
  **修法**:新 helper `X.lion_ShouldStopDrain(hBot)`,gated turbo + `liondrainstop`;谓词**与
  `lion_IsDrainSafeToStart` 完全对称**(极性反转)—— 同一 `WasRecentlyDamagedByAnyHero(2.0)` + 同一
  `X.nEDrainDangerRadius = 500` 内 `J.GetNearbyHeroes` 非空。**复用同一常量**是刻意的:
  retune 一边另一边**自报**(测试里的 `[484, 781)` 区间断言两个 test 文件都在读)。
  消费点在 `X.ConsiderStopDrain` 里,排在 shipped `IsRetreating` 分支**之后**,且**内嵌在自己的
  `IsAbilityEChanneling()` 前提里**(无频道无释放,单独 arm 不影响 shipped 退却路径)。
  **两帧一起钉**:`f_260819_182855_lion_drain_midchannel.lua`(t=299.2 focused 必压:mid-channel
  第 2.0 秒、viper 484u、hero pressure)+ `f_260819_182855_lion_drain_jungle.lua`(t=247.0 jungle
  必放:mid-channel 第 2.7 秒吸黑山贼、最近活着的敌方英雄 necrolyte 5995u、只挨野怪)。**同一局
  两个不同的频道** ⇒ 任何 harness 缺口对两帧对称,不给对偶 lever 留掩护。
  **局部验证** `tests/test_replay_260819_lion_drain_stop.lua` **19 例**:
  2 ground-truth(A 必压 / B 必放,附 died_after 15.9 vs 68.1);2 gate-OFF(未 arm / 非 turbo);
  5 armed 组(focused 释放 / jungle 保持 / 摘伤害子句 / jungle 加伤害仍不释放 / jungle 挪敌人+加伤害
  必释放 / focused 把 viper 推出圈必不释放);**1 外前提测试**(IsChanneling=false ⇒ ConsiderStopDrain
  仍 NONE,同时断言 helper 内部谓词**独立**成立 —— 证明 `IsAbilityEChanneling` 外闸不是冗余);
  **1 双计防护**(强制 retreat 模式,shipped 分支单独还 HIGH,新 gate 关掉也还 HIGH,不双计);
  **1 跨层 tripwire**(死尸不锁住释放,`J.GetNearbyHeroes` 上游过滤);**1 半径区间断言**
  (`[484, 781)`,与起手 lever 共享);**4 例端到端**驱动真正的 `X.SkillsComplement()`,断言
  `Action_ClearActions` 是否入队(shipped 必**不**入队 = 缺陷复现;armed 必入队;jungle 不入队;
  只摘伤害子句翻掉 ClearActions ⇒ 端到端归因);**1 源码 wiring tripwire**(`liondrainstop` 恰好一次、
  两句 AND、新分支在 shipped `IsRetreating` 之后、外嵌 `IsAbilityEChanneling`)。
  **8 次变异 8 次全抓**(改 gate id 挂5 / 摘 turbo 挂1 / 反转伤害子句挂6 / 摘外前提挂2 /
  HIGH→NONE 挂3 / 半径→1 挂12 / 半径→900 挂5 / 硬编码 100 替常量挂8)。**另有 1 例故意不算(记账)**:
  `== nil or #list == 0` → `~= nil and #list == 0` 在 `GetNearbyHeroes` 总返回列表(从不 nil)的世界里
  **可证行为等价**,是防御式 belt-and-suspenders,不是承载分支。luacheck **0 警告**,
  `lua5.1 tests/run_tests.lua` **857/857 绿**(干净 stash 基线 **838**,+19)。
  **给总监**:①**新 gated id `liondrainstop`** 已登记 `state.json`(`liondrainstop_20260820`),
  **申请入 test_set.md**;等门的 hero 组 id 现在是**八个**(`wkreincarnmp`、`axeblink`、
  `liondrain`、`odaoe`、`zusultx`、`esaftershock`、`cmrself`、`liondrainstop`)。
  ②**排期约束**:**绝不许**与 `liondrain` 绑一个臂 —— 两 lever 共用 `X.nEDrainDangerRadius`
  常量与 2 秒伤害窗口,同臂丢失归因(哪个 lever 抓了哪个频道);两 lever 触及**不相交的调用点**
  (`ConsiderE` vs `ConsiderStopDrain`),单独 arm **各自都有行为**,不存在 axeblink 陷阱。
  ③**(b) 用行为检测器**:域内频道释放次数(shipped 只在 IsRetreating 时释放,armed 加一类)、
  频道内 Lion HP 曲线、每局 Mana Drain 频道数按目标类型拆(hero / creep)。**不许 gpm/xpm**
  (GH #30 噪声底 30 gpm,<1 事件/局结构性看不见)。④**未提 queue.json**(不需新花费,
  搭已排期 candidate wave)。⑤**预注册期望值**:第一杠杆 `liondrain` 已挡 4/13 频道;`liondrainstop`
  的域是**另一类** —— 起手时安全、mid-channel 变糟的。语料实例:182855 t=297.2 起手时 viper 在 555 码
  (>500),开火放行;t=299.2 viper 484 码 + 挨打 ⇒ armed 释放一次。
  报告:`iterations/reports/hero/20260820T181252Z.md`。**未花 AWS 的钱**(2 个 `.dem` ≈17MB S3 GET + 
  dumper 缓存命中,零 EC2)。全链路**自己做约 45 分钟**。
  下一次触发:**#7 的第三层**(`liondrain` 起手门 + `liondrainstop` 释放门都到位后,回头看大招
  0/1/2/0/0 次/局那条,Lion 的 Finger 用得少 —— 和 Zeus #4、Lion #7 是"终结技用得少"的家族)
  或 **#13 的残留**(门读不到「她正在被停」);**#11** 等 `zusultx` 落地后再动;#4 的雾里那一半
  仍卡 GH #27,低优。

- 2026-08-20T15:20:00Z:**本轮无新 `[hero]` issue** —— open 里 `[hero]` 前缀的
  #66(上一轮自己做完的 esaftershock)、#63(本组不认领,等 `esaftershock` 读数)、
  #59(zusult 已入集,等 `zusultx` 读数)、#56 / #54(剩下的半条都在别的组域里)都无新可
  推进的动作 ⇒ 按章程取 backlog **#10**(跳刀被当腿用),**做完并划掉,转协同组开 GH #71**。
  **本轮无新 gated id、无 bots/ 代码改动、无入集申请**;测试计数不动(830/830 绿,同 main)。
  **拉了 1 个 `.dem`(~8.5MB S3 GET)+ 缓存命中的 dumper,零 EC2**。
  **问题**:backlog #10 的两帧证据(t=529.6 / t=555.2)在 `axeblink` 守的**进攻分支**外
  ——前者硬门 `not J.IsInRange(bot, botTarget, 500)` 挡掉(SK 在 339),后者进攻分支
  的其他子句挡掉。定位「另一条消费点是哪一条」是英雄组的义务,但**修哪一条门不归本组**。
  **做法**:独立复跑 `20260820_043124_slot1` 的 dumper(`-interval 0.5`),对全部 5 次
  `item_blink` 施放算几何指纹:cos(位移向量, 单位向量-到-Dire-ancient(5528,5000))与跳跃
  距离。5 次结果排开:492.3(cos -0.411, 841u, 进攻/axeblink 域)、**529.6(cos +0.997,
  1326u,retreat)**、**555.2(cos +0.998, 1162u,retreat)**、574.9(cos -0.996, 642u, 进攻)、
  613.2(cos -0.183, 1174u,其它)。retreat 分支 `nCastRange=1200`,cos ≈ +1 与距离
  ≈ 1200 的组合是它的唯一指纹(进攻分支反方向,`IsStuck` 要求 EAd/TAd > 2200 且卡位 >5s,
  farm-creep-AoE 分支要求敌方零人在 1600 而 SK 在 339 / 843,tormentor 方向不对上 ancient)。
  **排除 `IsProjectileIncoming`(第 3 候选)**:t=529.6 前 7s 唯一相关是 SK 的 hellfire_blast
  @523.3(526.4 落地);t=555.2 前 5s 内**零敌方施法**。
  **T=529.6 完整读数**:pos=(4684,-6154) hp% **0.84** mp=349/519 lvl=10,items
  `blink_dagger, quelling_blade, magic_wand, bracer, power_treads`(无 aether/monocle/
  keen_eyed/mystical/boundless ⇒ nCastRange 确认 1200),1200 内敌人 = SK@339 hp% 0.63,
  800 内队友 = Earthshaker@173 hp% 0.97,5s 前挨的伤害 = SK 的 hellfire_blast 15+15 + Radiant
  一塔 52。上下文:ES 前 2.7s 已 Echo Slam 打 SK 220+,Axe 正 battle_hunger 追击 —— 门
  把这场胜利态硬拉回家。**T=555.2 更干净**:pos=(4671,-6156) hp% **0.81** mp=383/543,
  1200 内敌人 = SK@843 hp% **0.41**,800 内队友 **零**,5s 内挨伤合计 4(近战小兵一下)。
  **给协同组的建议(不写死数字,GH #71 §建议)**:①retreat 分支加对自己 HP 的下限断言,
  按 `cmrself`(hero 组 2026-08-20T13:49Z)的合取形状:低血 **且** 挨过打;②敌方威胁地板
  ——不仅"1200 内有敌人"就够,要看能不能真打到我;③验收 (a) 用几何检测器
  (cos>0.9 且距离在 [1100,1400] 上归为 retreat 分支),(b) 不用 gpm/xpm(GH #30),
  (c) 攻略口径一致(blink 是"进攻先手 / 保命有指向性威胁",不是 15s cd 的腿)。
  **给总监**:①**本轮无新 gated id**;等门的 hero 组 id 仍是**七个**
  (`wkreincarnmp`、`axeblink`、`liondrain`、`odaoe`、`zusultx`、`esaftershock`、`cmrself`)。
  ②**未提 queue.json**(不需要新花费,协同组落地后可搭已排期 candidate wave)。
  ③**GH #71 已开**,body 里带 `20260820_043124_slot1` 的完整 5 帧几何 + 两帧 (529.6/555.2)
  完整读数 + 分支源码 + 检测器建议。④#63/#54/#56 剩下的半条本组仍不认领,理由前几轮已写。
  报告:`iterations/reports/hero/20260820T152000Z.md`。全链路**自己做约 20 分钟**。
  下一次触发:**#7 的下半**(Lion 打断已跑频道:`X.ConsiderStopDrain` 只认 `J.IsRetreating`,
  已跑频道打不断)或 **#13 的残留**(门读不到「她正在被停」);**#11** 等 `zusultx` 落地后
  再动;#4 的雾里那一半仍卡 GH #27,低优。

- 2026-08-20T13:49:58Z:**本轮无新 `[hero]` issue**(#66 是我上一轮自己做的、#63 章程写死**本组不认领**、
  #54 剩下那半仍无人认领、#59 13:00Z 总监裁定要的是**检测器**不是本组的活)⇒ 按章程取 backlog
  **#13**,**做完并划掉**。**新 gated id `cmrself`**。**零 AWS、零 S3、零 dumper —— 帧上一轮就在库里。**
  **问题**:`X.cm_IsRSafeToOpen` 从 GH #34 到 #66,**每一个输入都是关于敌人的**,
  **从没读过 CM 自己的任何字段**。GH #66 §2 帧 A 的账单:**292/1110(26.3%)**、身上 `modifier_stunned`
  还剩 **0.2s**(1.1s 前挨的)、前 6 秒挨了 **919** 点英雄伤害、**2 个敌人在 300 内**、
  最近队友 **1543 码** —— 一条都不进谓词,门放行,10 秒自定身读条,**474.5 死**(`died_after = 1.0`)。
  **修法**:gated turbo + `cmrself`,`J.GetHP < X.nRSelfHpFloor (0.38)` **且**
  `WasRecentlyDamagedByAnyHero(X.nRSelfFireWindow (2.0))`。**故意是合取**:低血单独看是辅助常态
  (会把大招静音大半局),挨打单独看就是团战的定义(而团战正是该开的时候);**是这一对**才说明
  「读条活不到收钱」(伤害按脉冲摊在 10 秒里,第一秒死 ≈ 一次脉冲)。**地板 0.38 不是新数** ——
  `ConsiderR` 的 retreat 分支早写着 `nHP > 0.38`,复用是对齐口径,并加 tripwire 防引用过期。
  **结构上刻意分家(避开 `axeblink` 陷阱)**:`cmrguard` 环扫描与本子句现在是**共享一个 turbo 早退
  下的两个各自 gated 的块** ⇒ 单 arm 任一 id 都自己有行为,`cmrguard` 单独 arm **逐字节不变**,
  且这一条是**行为式证明**的(单 arm `cmrguard` 时把她砸到 1 血,答案不动)。
  **局部验证** `tests/test_replay_260820_cm_r_selfstate.lua` **24 例**:**两帧一起钉**——
  `f_260820_103216_cm_es_aftershock.lua`(t=473.5 **必压**,两个半边都真)+
  `f_260820_102645_cm_es_reach.lua`(t=391.5 **必放**,51.5% **但也在挨打** ⇒ **放行只能归因于
  血量地板**,同时证明挨打那半边单独扛不动判决;`died_after=106.9`);**盲点写成正向断言**
  (单 arm `cmrguard` 在帧 A 仍放行,并断言原因是**扫描找不到就绪 curated 硬控**,不是环里没人);
  **两个 id 互不代打**(一个被标注的世界:血抬到 60% + ES fissure 还成 cd=0 在真实 195.9 码 ⇒
  `cmrself` 放行 / `cmrguard` 否决);**地板全带扫**(0.265/0.30/0.38/0.45/0.514 两帧判决不动)
  + **带外两向翻**(0.26 放掉死了的那帧 / 0.52 否决活下来的那帧)+ **一点血双向钉死**(421 压 / 422 放);
  **窗口在真实的 0.2 秒那一下两侧钉死**(0.1 放 / 0.2 压);**5 例端到端**(帧 A **无需任何 mutation**
  就出价 HIGH ⇒ 不是空绿、armed 变 NONE、**只动血量**放回 HIGH = 归因、非 turbo 不变、
  帧 B 两侧 NONE **且把真实理由断言出来**:两敌在 734.8 圈内但都在 302.5 之外 ⇒ `aoeCanHurtCount` 恒 0);
  **3 处源码 tripwire**。**8 次变异 8 次全抓**(裸跑子句挂 6+**esaftershock 文件 7**(跨层)/
  `<`→`>` 挂12 / 摘挨打项挂2 / 摘血量项挂8 / 地板→0.26 挂6 / **折回 cmrguard 块(重建 axeblink 陷阱)挂7** /
  摘 turbo 挂3 / 窗口→0.05 挂9)。luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **811/811 绿**
  (main 基线 **787**,+24)。
  **给总监**:①新 id `cmrself` 已登记 `state.json`,**申请入 test_set.md**;等门的 hero 组 id 现在是
  **七个**(+ `cmrself`)。②**排期约束与 `esaftershock` 相反**:`cmrself` **自足**,单 arm 就有行为 ⇒
  **绝不许**与 `cmrguard`/`esaftershock` 绑成一个臂(三者都是同一个函数的返回值,绑了不可归因),
  也不许与动 `X.nRGuardCloseBuffer`/#63 cap 的改动同臂。③**(b) 按您 13:00Z 在 #59 立的 §R.3 通例**
  (抑制型规则只能用对照臂反推):域内施法率(armed vs base,配对+归一化)、被扣下的读条值多少
  (base 臂域内开大的 3s 打断率/3s 死亡率)、代价侧(每局 Freezing Field 总次数不许塌);**不许 gpm/xpm**。
  ④**未提 queue.json**(不需要新花费)。⑤已在 **GH #66** 留言。
  报告:`iterations/reports/hero/20260820T134958Z.md`。全链路**自己做约 35 分钟**。
  下一次触发:**#10**(跳刀被当腿用,先定位 `ConsiderItemDesire['item_blink']` 的另一条消费点)
  或 **#7 的下半**(Lion 打断已跑频道)或 **#13 的残留**(门读不到「她正在被停」);
  **#11** 等 `zusultx` 落地后再动;#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-20T12:08:07Z:**认领并做完 `[hero]` GH #66**(录像检查组 10:48Z 新开,本轮唯一新出现的
  `[hero]`;#63 仍 open **本组不认领**,理由见下 ⑤;#54 剩下那半仍 open 无人认领)。
  backlog **新增 #13**(门不看 CM 自己的状态),**#12 改判**(#63 不是下一轮第一候选)。
  **新 gated id `esaftershock`**。**结论先说:表里少的那个人补上了,但它只补得上 GH #66 的一半,
  而另一半本轮被证明「不是表的事」。**
  **问题**:`J.tHardCcAbilities` 给 Earthshaker 只收了 `earthshaker_fissure`。但**点了 aftershock 的 ES,
  每放一个技能都在自身 300 半径炸一次硬控** ⇒ fissure 进冷却之后他手里的 `enchant_totem` 仍是硬控,
  而表把他读成无害。#66 量到:12 局 11 次开大,4 次读条 3 秒内被打断,门只拦住 **1** 次。
  **修法**:新表 `J.tHardCcAbilitiesCandidate = { earthshaker_enchant_totem = 'earthshaker_aftershock' }`
  —— **值是「必需的被动」不是 `true`**(没点 aftershock 的 ES 定不住人;被动过不了 `IsFullyCastable`
  所以只能当前置条件);`J.GetReadyHardCc` 里跑成**排在 shipped 扫描之后**的第二遍,
  只在 turbo + `esaftershock` 下。**不往共享表里加行**:那张表两个消费者(`cmrguard` / `ccburst`),
  加行等于同时挪两个域(`lanefix` 形状)。**各消费者仍各守各的门** ⇒ 只 arm `esaftershock` 而不 arm
  `cmrguard`,游戏里**什么都不会变**(写成了测试)。
  **两帧一起钉**:`f_260820_103216_cm_es_aftershock.lua`(t=473.5,**baseline** 侧,**必须拦**:
  CM **292/1110(26%)**、身上 `modifier_stunned` 还剩 0.2s、ES **195.9 码** fissure **cd=14.7**、
  `enchant_totem` cd=0、`aftershock` **lvl4**、Zeus 268 码但无策展技能 ⇒ 否决只可能归 ES;
  ground truth **`died_after = 1.0`**)+ `f_260820_102645_cm_es_reach.lua`(t=391.5,**armed** 侧,
  **必须仍放行**;`died_after = 106.9`,这次漏报**赔的是大招不是命**)。
  **更正 #66 §2 的算术**:它把两次漏报记成「同一个根因」,**按真实几何只有一个是** ——
  `enchant_totem` 无目标 ⇒ `GetCastRange() = 0` ⇒ 否决环 `0 + X.nRGuardCloseBuffer` = **400**,
  而帧 B 的 ES 在 **536.1 码**,加表项**动不到它**。那一半属于**环的形状**(#63 的域),不属于表。
  **取证陷阱(谁扫这批语料都会踩)**:帧 A 上 **jakiro 持就绪 `ice_path`但在 ~9200 码外** ⇒
  「除 ES 外无人持就绪硬控」**必须在 1600 扫描环上说**,不能在阵容上说;第一版测试就这么写错、
  被自己的断言当场抓住,已改成环上普查 + 把 jakiro 那条事实显式断言出来。
  **局部验证** `tests/test_replay_260820_cm_es_aftershock.lua` **24 例**:**缺陷写成正向断言**
  (只 arm `cmrguard` ⇒ `GetReadyHardCc == nil` 且门放行 = #66 那次漏报的复现)、修复、
  只 arm `esaftershock` 决策不变、非 turbo 不变、每条子句一个标注变异(aftershock 未点 / totem 冷却 /
  totem 蓝不够:耗蓝锚 600 对真实 534)、**shipped 优先级**(还给 fissure 冷却 ⇒ 句柄变回 fissure)、
  **帧 B 的环 400/401 两向钉死**(放行归因于**距离**不是「表项没生效」)、**锚点敏感性显式化**
  (cast range 若报 300 则帧 B 翻;另一例断言两局 ES **都没神杖**)、**4 例端到端**驱动真的
  `X.ConsiderR`(**帧 A 不需要任何 mutation** —— 真实帧上 ES 195.9 + Zeus 268 就在圈里,
  shipped 真的出价 **HIGH**;armed 变 NONE;非 turbo 维持 HIGH;帧 B 两侧逐技能相同**且把
  「为什么都是 NONE」的真实理由断言出来**,不留空绿)、**3 处源码 tripwire**(表项不许进 shipped 表 /
  候选表仍是「技能→被动」一条对 / `'esaftershock'` 恰好一次 / **`ccburst` 消费点仍在 `bCcAware` 门内**)。
  **8 次变异 7 抓**;**唯一没抓到的如实记账**:删掉候选分支的 `GetLevel() >= 1` ——
  `IsFullyCastable` 本就蕴含已学习,**可证冗余**,保留是为与上面一行 shipped 扫描对称,
  并新加**跨层 tripwire** 断言让它冗余的那个性质。luacheck **0 警告**,
  `lua5.1 tests/run_tests.lua` **769/769 绿**(干净 stash 实测基线 **745**,+24)。
  **给总监**:①新 id `esaftershock` 已登记 `state.json`,**申请入 test_set.md**;等门的 hero 组 id
  现在是**六个**(`wkreincarnmp`、`axeblink`、`liondrain`、`odaoe`、`zusultx`、`esaftershock`)。
  ②**排期约束两条**:**必须与 `cmrguard` 同臂**(单独 arm 结构上测不到东西,`axeblink` 同款陷阱);
  **绝不许**与任何动 `X.nRGuardCloseBuffer` / #63 cap 的改动绑成一个臂(同一道门的环,绑了不可归因)。
  ③(b) 只用行为检测器(#66 §1 的读条时长/打断者/**施法前帧**距离 + #63 的
  `cmrguard_precision.py --mana-floor`),**不许 gpm/xpm**(GH #30)。④**转出去一条**:#66 §2 的第二个
  盲点(门从不问 CM 自己的状态),本轮故意没碰,进本组 backlog #13。⑤**#63 的处置建议**:本轮把
  #66 §3 的一次漏报量成了几何事实(凶手环 = 400,cap 动不到),同一条事实也说明**统一 cap 会把
  自身半径类和线/路径类一起削** ⇒ 建议 #63 落地前按 #66 §3 **几何分档**重写、并补上「recall 不许下降」
  这条验收;**本组不认领 #63**,它动的是已 armed id 的环,应等 `esaftershock` 的读数出来之后再动。
  ⑥**未提 queue.json**(不需要新花费,搭已排期的 candidate wave)。
  报告:`iterations/reports/hero/20260820T120807Z.md`。**未花 AWS 的钱**(2 个 `.dem` ≈18MB 的 S3 GET +
  dumper 缓存命中,零 EC2)。全链路**自己做约 45 分钟**。
  下一次触发:**backlog #13**(门不看 CM 自己的状态,#66 §2 已有两帧证据)或 **#10**(跳刀被当腿用,
  先定位 `ConsiderItemDesire['item_blink']` 的另一条消费点)或 **#7 的下半**(Lion 打断已跑频道);
  **#11** 等 `zusultx` 落地后再动;#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-20T10:30:00Z:**认领并做完 `[hero]` GH #50 第 2 处**(**#51 于 09:08Z 由总监修完并关闭**,
  正是上一轮写死的解锁条件)。本轮 open 的 `[hero]` 还有 **#63**(录像检查组 08:50Z 新开,cmrguard 收窄
  —— 留给下一轮,它动的是已 armed id 的域)和 **#54 剩下那半**(mode 域,仍无人认领)。
  backlog **#8 划掉**,新增 **#12**。**GH #50 已关闭**(两处都修完,棘轮归空)。
  **结论先说:#50 §2 把这一处记成了「有活调用点的 nil 崩溃」—— 它不是,而且从来不是。**
  `J.IsValidTarget` 与 `J.IsValidHero` 是**同一个 delegate**(都 `return J.Utils.IsValidHero(nTarget)`,
  jmz_func.lua:2992/2997)⇒ 闸门 `A or (A and X)` **就是 `A`**:Lua 只在 A 假时求值 `or` 右边,
  而那时 `and` 又在**同一个假 A** 上短路 ⇒ **`J.Unit` 永远不被索引**。英雄走左支,非英雄两个合取项全假,
  **没有第三类目标**。独立成立的**第二个理由**:两个调用点都只可能递英雄(`:1246` 遍历
  `UNIT_LIST_ENEMY_HEROES`,`:1259` 用 `J.IsValidTarget(botTarget)` 把门)。
  **测量**(真实帧 `20260720_080225_slot1 @ t=47.0`,**库里已有的** `f_080225_wk_lane`,**没拉新录像**):
  驱动**真的** `X.ConsiderCmToTarget` 过 10 个真实英雄 + 合成肉山/百解/小兵,
  `Utils.IsUnitWithName` **调用 0 次**、无一 raise。**这个 0 不是空绿** —— 同一次驱动里
  pudge 与 shadow_shaman 拿到真的 `BOT_ACTION_DESIRE_HIGH`,juggernaut 是 NONE。
  **那还改它干什么**:`jmz_func.lua:2992` **自己的 NOTE**(「ideally it should be `IsValidUnit`」)
  是**一行就能点燃这条分支的引信**,点燃那天它以**抛异常**的形式活过来,吞掉 Invoker 当帧**整个技能层**
  且在游戏里看不见(没有任何地方 `pcall` 包 `SkillsComplement`)。所以改的是**引信不是崩溃**,
  并把整套推理写进消费点头注释 —— 免得下一个人靠**放宽闸门**来「修」它(那才是真会出事的改法)。
  **局部验证**:`tests/test_invoker_cm_target_guard.lua` **11 例** —— 谓词同一性(用真实单位断言,不从源码读)、
  **源码 tripwire 的失败信息直接告诉下一个人「这条红了 = invoker 那条分支刚刚活了」**、行为式不可达性(计数器==0)、
  非空绿的 HIGH 出价、意图未实现(合成肉山 ⇒ NONE)、**旧写法在真实帧上重建后从不 raise**、
  **正向对照(关键)**:把 `J.IsValidTarget` 人为改成恒真(**正是那条 NOTE 造成的世界**)⇒
  **旧写法当场 raise `attempt to index field 'Unit'`、新写法不 raise 且答 true**(没有这一条,
  「它从来没崩过」也可能只是复现写错了)、**`#51` 跨层 tripwire**(名字判定不许恒真:小兵两例会翻)、
  闸门形状 + 两个调用点 + `ConsiderCmToTarget(` **全文恰好 3 次**的 tripwire。
  **6 次变异 6 次全抓**(回退修复挂2 / `IsValidTarget`→`IsValidUnit` 挂**7** / #51 回归挂5 /
  放宽左析取项挂2 / 修好却不删棘轮条目挂1 / 新增第三个调用点挂2)。
  `tests/test_no_undefined_jmz_refs.lua` 的 **`KNOWN_BROKEN` 归空**,并写明这道扫描的**盲区**:
  只答「名字有没有定义」,不答「调用点可不可达」(本轮的故事),也不答「函数返回得对不对」(#51 的故事)。
  luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **725/725 绿**(基线 **714**,+11)。
  **诚实边界**:①**非英雄单位是 mock 的,必须是** —— behav-dump **只 dump 英雄**,
  **#50 建议的验收口径(Roshan / 小兵 两帧)今天造不出来**(同 #27/#43/#53);不可达性是
  **在 10 个真实英雄上证明**的,mock 只延伸到 dumper 供不出来的那一类,且只带 `IsValidHero` 真读的四个字段;
  ②一帧(判据是短路语义,不是场景依赖的阈值);③**不对 Invoker 的整体强度做任何声明**,改的是引信不是调优。
  **给总监**:①**本轮无新 gated id**,等同一道门的 hero 组 id 仍是**五个**(`wkreincarnmp`、`axeblink`、
  `liondrain`、`odaoe`、`zusultx`);②**不需要批测**(可证不可达 ⇒ (b) 上没有可测的反方向),**未提 queue.json**;
  ③**需要排期的是 GH #64**(全池 `IsValidTarget` 语义,377 调用点 / 287 个 `botTarget`,已按 `[bug]` 交总监;
  **明确写了不许一把梭改 helper 定义** —— 那 287 个点里相当一部分本来就只想要英雄,一次放宽等于同时改掉
  几百条已发布行为,`lanefix` 的形状;而且改定义会**当场点燃** invoker 那条分支);④#63 留下一轮,
  #54 剩下那半仍 open 无人认领。
  报告:`iterations/reports/hero/20260820T103000Z.md`。**未花 AWS 的钱**(全程离线,只读已有 fixture,
  零 S3 GET、零 EC2)。全链路**自己做约 30 分钟**。
  下一次触发:**backlog #12 / GH #63**(cmrguard 收窄,带 115 个 episode 帧证据)优先;
  否则 **#10**(跳刀被当腿用,先定位 `ConsiderItemDesire['item_blink']` 的另一条消费点)
  或 **#7 的下半**(Lion 打断已跑频道);**#11** 等 `zusultx` 落地后再动;#4 的雾里那一半仍卡 GH #27,低优。
- 2026-08-20T07:55:00Z:**认领并做完 `[hero]` GH #59**(本轮唯一新开的 `[hero]` issue,
  录像检查组 06:44Z 对 `zusult` 的**第二次执行核验**;#56 已被总监 07:00Z 处置并退回本组、
  但其成因 GH #60 属全池采购基础设施,本轮不动;#54 剩下那半仍 open 无人认领;#50 第 2 处
  仍被 **GH #51** 挡着,处置不变)。backlog 新增 **#11**。
  **问题**:`X.zuus_ShouldSaveManaForUlt` 的子句 7 `if hBot:GetMana() >= nCost then return
  false end` 读的是**花之前**的蓝量,于是门的**有效域恰好是「储备已经没了」** —— 蓝 >= nCost
  (唯一还有东西可保的时刻)一律放行,蓝 < nCost(储备已丢)才开始压。**它守的不是大招,
  是丢掉大招之后的那段回蓝**;把蓝量从线上打到线下的那一发,门结构性看不见。
  **不依赖 `J.IsRetreating`**(子句 7 排在子句 8 前面),所以 GH #47 的那个盲点在这里不存在。
  **帧证据**(`20260820_042607_slot1`,seed 872 radiant,本组独立复跑 dumper 逐帧确认):
  t=462.3 秘法鞋 +175 把蓝从 104 抬到 **256**;**t=462.5 决策帧** —— lion **499.7 码 1.00 血**,
  大招 lvl1 cd=0 且 **`IsFullyCastable()` 为 TRUE**(**比 #59 多出来的那一格:门把「储备完好
  且当刻可放」读成了「没有东西被否决」,方向是反的**);t=462.9 W2 地面 bolt 打**满血** lion,
  储备**撑了 0.4 秒**;463.5–491.5 门**尽职地压住 57 个连续帧**的 chip,守着一份已经不存在的储备;
  **t=492.2 Zeus 阵亡,手上 116 蓝,大招仍 lvl1 仍 cd=0** —— 就绪且买不起;t=521.0 才放出第二发,
  隔着一次死亡一次复活。
  **修复**:门收**第三个参数 = 出价方自己的技能句柄**,子句 7 改成
  `hBot:GetMana() - nSpend >= nCost`;三个消费点(W/W2/Q)各传各的句柄。
  **单开 id `zusultx`**(#59 §2.2 的建议):post-spend 严格蕴含 pre-spend ⇒ 这是**扩大**一个
  **尚未过 (b)** 的门的域,`lanefix` 高风险面。只 arm `zusult` ⇒ `nSpend` 恒 0、与上线**逐字节
  等价**;arm `zusultx` ⇒ 跑扩大域;**不存在「arm 了什么都不发生」的组合**(写成了测试,防
  `axeblink` 那种陷阱)。**扩大幅度有界**:两者只在蓝落在 `[nCost, nCost+spend)` 时不同,
  对一发 Bolt 是 ~130 宽的一条带。
  **局部验证**:**两帧一起钉** —— `f_260820_042607_zuus_reserve_cross.lua`(t=462.5 **必须压**)
  + `f_260820_042607_zuus_reserve_safe.lua`(t=330.5 **必须放**;**放行的正确性由这一帧自己的
  未来证明,不需要任何帧外锚** —— t=330.7 bolt `380→251`(129),**t=331.2 大招就从 251 放出去了**)。
  `tests/test_replay_260820_zuus_reserve_cross.lua` **24 例**:**缺陷本身写成正向断言**
  (`zusult` 单独 arm ⇒ 门返回 false)、无惰性组合、nil 句柄退化显式记账、**两个帧外锚各自全带扫**
  (大招 `[216,248]`、bolt `[129,133]`,判决在带上不动)、**阈值双向钉死相差 1 点蓝**(31 放 / 32 压)、
  **6 例端到端**(shipped **正向断言**真的入队 ⇒ 后面不是空绿;**`zusult` 单独 arm 照样入队 =
  缺陷的端到端复现**;`zusultx` 压住;**只改蓝量到 400 就翻回去 = 归因**;击杀窗口照放;非 turbo 不变)、
  控制帧两向、**2 例源码 tripwire**(**按形状**逐消费点数参数、按源码顺序 —— GH #47 那个**按变量名**
  的被一次改名溜过去过)。
  **端到端 mutation 如实记账**:挪两个友军进 800 环(真实阵型 800 内**只有 1 个**友军,而 W2 poke
  分支开火子句是 `#nAllies >= 3`,不挪门在 fixture 里不可达);**门读的每个输入全是真实帧数据**,
  且第 4 例**在 mutation 不变下只动蓝量就翻回结论**,证明 mutation 没有替结论干活。
  **7 次变异 7 次全抓**(pre-spend 回退挂8 / 两 id 塌成一个挂4 / W2 丢句柄挂3 / 摘击杀窗口挂5 /
  摘 turbo 挂4 / `zusultx` 变惰性挂7 / `>=`→`>` 挂4);**其中 4 次还挂掉了 `zusult` 那两个既有测试
  文件里的用例**,跨层保护是双向的。luacheck **0 警告**,`lua5.1 tests/run_tests.lua` **695/695 绿**
  (干净 stash 实测基线 **671**,+24;**rebase 到 main 后在合并树上重跑 706/706 绿**,
  策略组同轮 GH #62 带进 11 例)。**顺带改了两个既有 tripwire 的字面量**(多了第三个参数),
  **它们钉的语义一字未改**,并新加「`'zusultx'` 恰好出现一次」。
  **诚实边界**:①三个帧外锚(大招耗蓝 —— 本局实测 t=331.2 `251→3` 与 t=521.0 `848→652`;
  bolt 耗蓝 —— **故意避开 t=462.9**,同帧有魔棒回蓝把差值搅浑,改用 t=440.6 `515→382`=133(L4)
  与 t=330.7 `380→251`=129(L3);bolt 700 / arc 900 施法距离,不锚则端到端整组假绿。**前两个
  全带扫过**);②一局一个 Zeus(辅助位),只逐帧看了 #59 点名的那一局;③**控制帧只做到 helper 级**
  —— `J.GetCastLocation` 在 993.6 码返回 nil(drow 超出 700),那一帧**真的没有出价方**,是真实
  几何不是 fixture 缺陷;④整体好坏只有批测能答,这正是它单开 id 的原因。
  **给总监**:①**新 gated id `zusultx`**,已登记 `state.json`(`zusultx_20260820`),**申请入
  test_set.md**;等同一道门的 hero 组 id 现在是**五个**:`wkreincarnmp`、`axeblink`、`liondrain`、
  `odaoe`、`zusultx`。②**排期约束**:`zusultx` 与 `zusult` **必须分开读**,`zusult` 已入集,
  最省的读法是 `zusultx` 单独占一臂、增量 = 两臂相减;**绝不许绑成一个臂**。
  ③**预注册期望值**(采用 #59 的口径):armed 侧 4 局 5 次跨线花费,**健康英雄 1 次 / 击杀窗口
  4 次**;arm 后期望**健康英雄跨线 1 → 0、击杀窗口维持 4 不动**,`zusult` 域内读数不变。
  **(b) 必须用 `zusult_reserve_cross.py`,不许 gpm/xpm**(~0.5 次/局,GH #30 结构性不可观测)。
  ④**检测器采样间隔敏感性(本轮实测,交给量具 owner,本组不动别人的量具)**:同一局
  `-interval 1.0` ⇒ `crossings 2 / onto_healthy 1`(**头条帧 t=462.9 在里面**),`-interval 0.5`
  ⇒ **0 / 0**(蓝量扣除在 0.5s 网格上**晚一格**落:462.5=256 → **463.0=258** → 463.5=158,
  于是 `post['mp'] < cost` 不成立)。另一侧偏差:1.0s 口径把 **t=330.7** 也算跨线(`380→3`),
  但 0.5s 显示那发 bolt 只走 `380→251`(**仍在线上**),真正跨线的是 **t=331.2 的大招本身**
  —— 该花的那一笔。**建议两行修法**:`post` 取「第一个蓝量真的低于 `pre` 的快照」+ 排除窗口内
  含 R 施法的样本;**在此之前 (b) 的读数请固定在 1 Hz**。⑤**未提 queue.json**(`zusultx` 走
  test_set 入集流程,不需要新的 AWS 花费,搭下一波已排期的 candidate wave 即可)。
  ⑥**本轮故意不碰**:击杀窗口豁免与 RETREAT 豁免(#59 量到都是对的);**#56 也没碰**
  —— 其成因 GH #60 属全池采购基础设施,按章程不归本组。
  报告:`iterations/reports/hero/20260820T075500Z.md`。**未花 AWS 的钱**(1 个 `.dem` ≈8.5MB
  的 S3 GET + 缓存命中的 dumper,零 EC2)。全链路**自己做约 40 分钟**。
  下一次触发:**#51 若已修 ⇒ 回来做 #50 第 2 处**;否则 backlog **#10**(跳刀被当腿用,先定位
  `ConsiderItemDesire['item_blink']` 的另一条消费点)或 **#7 的下半**(Lion 打断已跑频道);
  **#11**(`nKeepMana` 与 `zusult` 两套留蓝机制并存)等 `zusultx` 落地后再动;#4 的雾里那一半
  仍卡 GH #27,低优。
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
