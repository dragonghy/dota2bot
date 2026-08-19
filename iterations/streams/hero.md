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
   **本条未完成的残留(不阻塞划掉,但别丢)**:GH #34 的 case #4
   (skeleton_king hellfire_blast 620 码否决、威胁 12 秒后才兑现、门整场没
   解除、CM 被磨到 0.03)**没修**。单帧快照没有"是否在逼近"的信号;真修法要么
   给否决加**时间上界**,要么需要接近速度输入。要帧证据才能设计。
3. **魔棒/芒果死手帧**:低血限进(d23 lowhp_limbo)时身上有魔棒充能/
   芒果却不用的案例(lich 帧已有);查焦点五的同类帧。
   - ~~**魔棒那一半**~~ 2026-08-19 done,gate `wandlimbo`,真实帧
     (Zeus 15.8% 血漂流)fixture 通过 —— 见"当前状态"。
   - **芒果那一半仍待做**,卡在没有真实帧:本地 43 个 fixture 里只有 1 个
     持芒果的主角(viper,非焦点英雄且蓝量高)。下次委托 replay-analyst
     **小样本(1-2 局)**扫"焦点五 + 低蓝 + 背包有 enchanted_mango"的帧。
     可疑点(未证实,不作改动依据):`item_enchanted_mango` 的全部逻辑就是
     `if bot:GetMana() < 150 then HIGH end`,绝对阈值,既不看有没有一个
     "差一点就能放"的技能,也不看是不是正在往泉水走(走到泉水前吃掉=浪费)。
   - 顺带记录的工具缺口:**dumper 不记录物品充能层数**(`grep charge` 在
     `behavioral/dumper/` 命中 0),所以任何"魔棒有几层"的判断在 fixture 里
     只能从帧外供数。#27 是同一家族的缺口,暂未单独开 issue。
4. **Zeus 大招击杀确认**:全图大招抢残血 vs 浪费在满血团上的帧差分。
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
   3 次变异测试通过,见"当前状态"。**未完成的一半**:帧库里没有一个
   "Axe 身上带匕首"的帧,所以"起跳"这个消费点前置条件仍未被真实帧覆盖;
   下次委托 replay-analyst **小样本(1-2 局,取 12 分钟后的片段)** 扫
   "Axe + 背包有 item_blink + IsGoingOnSomeone" 的帧。d24 deep_solo_death
   的反例核查也仍未做。
6. ~~**WK reincarnation 真实帧 fixture**~~ 2026-08-19 done —— 委托
   replay-analyst 找到真实帧(spot_20260725_102532_1_main slot1, t=373.5,
   mp=189/387 落在 160/220 gap 里),`tests/fixtures/
   f_260725_105305_wk_reincarn_gap.lua` + `tests/
   test_replay_260725_wk_reincarn_gap.lua`,gate ON/OFF 两条路径校验通过。
   **下一步不是本组的活**:`wkreincarnmp` 进 `test_set.md` 需要 director
   批准(本组无权自改),已在本次报告里提出,等 director 下次触发采纳。

## 当前状态(每次触发后更新)
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
