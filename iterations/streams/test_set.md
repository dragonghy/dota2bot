# 当前测试集(测试版 = 稳定版 + 以下 armed)
tpcommit,lf_rescue,ownhalf,overchase,wandbleed,zusult,blinkflee,liondrainstop,odaoe,pullcamp,stayfield,stayfield2,fieldbuy,pullcad,pulldrag,tpgap,tbearly,tpdeathbuy,campfarm,abilanc,bbfight,bbshort,aimguard,campvoid,wkqdmg,fieldsip,creepthink,lionqdmg,cmqreach,rotscope,outlatch,illureal,slotarb,slotdust,wandbleed2,arbheart,zusboltdom
**成员串 37**(上一行,**335 字节**,md5 `b525d51d4b4957e0e40f22f203aea641`)。本行 **2026-09-09T04:xxZ 的变动:两条 `退回出集`(39 → 37)**,总监裁定全文 **§GF**。⛔ **不是 reject**,两条的 gate、helper、常数与调用点**逐字保留**(`bots/`+`game/` 零 diff);判定完结 **2**(达 owner P4.2 的 ≥2)。**这两条是 `verify_coverage.py` 的 `narrat=1` 最后两条,该档就此清空。**
1. **`pulllane` 退集**(39 → 38)—— `verify=0`,转轴 `J.IsCampBesideLane( camp.location, tLanePath )` 在语料上**一次也没被调用过**。⚠️ **而第一个假设是错的,是阳性对照说的**:`GetNeutralSpawners()` 在 **110/110 帧为 `{}`**(0 个营地句柄),于是「营地名册就是那堵墙」是自己送上门的读法 —— 也正是 §GE 判 `campsel` 的那堵墙。**它不是这里的约束墙**:上门、强制 turbo、**再喂一个距 bot 600u 的合成己方营地**,读数**纹丝不动**(non-nil **0/1100**,`J.IsCampBesideLane` 被调用 **0 次**)。真正的墙在更前面。
2. **`pullthink` 退集**(38 → 37)—— `verify=0`,**两个操作数各自独立地死**:作用域项 `bot.roamCampPull ~= nil` 要 `J.ShouldPullNeutralCamp` 非 nil,而它**全上门、全 turbo 之下仍在 1100/1100 句柄上返回 nil**(与 `pulllane` 同因);节流项 `J.Utils.IsBotThinkingMeaningfulAction` 在 **1100/1100 上为 false** —— 而它为 false 时 **baseline 腿也不提前 return**,于是两条腿在语料**每一帧逐字节相同**。
⭐⭐⭐ **本轮最该被读的一条(§GF.3):同一个加载器里同时住着两种失败模式,而只有一种会举手。** 两个输入都不在语料里,加载器对它们的处理**方向相反**:`GetLaneFrontLocation` **大声拒答并自报家门**(`LOADER REFUSES: … is unresolved (GH #61). The dump does not carry lane fronts; do not compare against (0,0,0). Declare your assumption …`);`GetAnimActivity` **静静地答 0**(`bot_api.lua` 的 `^Get -> 0` 兜底,1100/1100)。**同一个加载器、同一类缺失数据、相反的失败方向** —— 而**拒答那一种就是解药,并且已经实现好了**。⇒ 连续三轮的主轴都是「一次没有推广的修复」(§GD.5 `AbilityDamage` 修了紧邻的 `AbilityCastRange` 没修;§GE.3 `GetItemSlotType` 修了 `GetCurrentActionType` 没修),**而本轮漏掉的不再是一个姊妹 getter,是一条加载器只对一个 getter 执行、对其余一概不执行的策略**。
⭐⭐ **第二件(§GF.4):`pullthink` 源码注释自己的理由已经过期了。** `mode_roam_generic.lua:210-211` 逐字写着「ACTIVITY_* are undefined globals under the mock, so utils.lua builds meaningfulActivities as an **EMPTY table**」,并把它当作「this line reads false locally」的**两条独立理由之一**。**实测为假**:`api.install` 把未知 ALL_CAPS 解析成 ≥1001 哨兵 ⇒ `ACTIVITY_RUN` **1153**、`ACTIVITY_ATTACK` **1154**,那张表是**满的**。判据是唯一能定案的那种 —— **注入一个真哨兵,节流项当场翻 true**(`[2c]`)。**结论活着,两条理由死了一条**(纪律 4:对的答案骑在一条已经不成立的理由上)。⭐ 而且这有**实际后果**:表既然是满的,`GetAnimActivity` 就是加载器**够得着**的一个 getter ⇒ `pullthink` 的节流项是这四轮裁定挖出的四个仪器缺口里**最便宜的一个,dumper 一行都不用动**。
⭐ **归属清单(全 1100 句柄,每一个停在哪)**:dead **79** / `IsCore` **929** / 时间窗 **67** / :12:42 刻 **14** / 800 内有敌 **2** —— 这五条是**诚实的域过滤**(这是一条 pos-4/5 对线期杠杆,而语料以核心、以非 60-360s 为主);`nLane == nil` **0**(**GH #648 的论点实测成立**:引擎答 `LANE_NONE == 0`,那条 guard 打不响);**够到 lane front 的恰好 9 条,而这 9 条上加载器全部拒答**。⇒ **语料里能把问题问出口的只有 9 帧,仪器在 9 帧上全部拒答。** 这个 9 同时是给买单人的报价:**这是一笔小而准的采购,不是全语料改造**。
⚠️ **退集针对的是仪器不是杠杆**:两条的 (c) 都成立且未被取代(`pulllane` 是 GH #117 的拖拽实测,`pullthink` 是 GH #186 的「42% 的 poke 帧从不下拖拽令」),`bots/` 零 diff,重新入集的条件由 `tests/test_blind_a_pulllane_pullthink.lua` 的「若买到就变红」断言自己看着(`[1a]`/`[1b]`/`[1d]`/`[2a]`/`[2b]`/`[2c]`)。
⚠️ **`pullcamp` 仍在集内,而它的读数是与 `pulllane` 同 armed 取的**:退掉 `pulllane` 后 `tLanePath = nil` ⇒ `J.IsCampBesideLane` 首行 `return true` ⇒ **逐字节 no-op**(已核源码,不是承诺),`pullcamp` 回到 §4 之前的选点行为。⛔ **因此 W58 及更早不与 37-id 家族并池。**
⚠️ **不掉进 `pullcad` 陷阱,断言过的**:`promote_atoms.json` **零次**点名这两条;`pulllane` **恰好一个** gate 点、`pullthink` **恰好两个**(节流跳过 + wind-up hold,设计上就是一条 id)。⭐ **`pulllane` 的门写作 `J.IsSoakCandidate( 'pulllane' )` —— 括号里带空格**;不带空格的 grep 会读回「无调用点」并把一条**活着的**杠杆当死的退掉,上一轮的「下次触发 ①」逐字警告过这一点,**本轮把它钉成了 M10**。
⚠️ **载体项 7 → 7 逐字不变,量出来的**:`carrier_terms.py --arm` 对 41-id 与 39-id 两串各跑一次,`TERMS` 行**逐字节相同**,`0 unresolved` 两次;计数 `9 hero / 32 generic` → `9 / 30`(两条都是 generic)⇒ **选种解空间不受影响**。
⛔ **在此之前起飞的任何一波都不含本次变动** —— W58 及更早**不与 39-id 家族并池**。
〔沿革,上一条变动〕**成员串 41**(上一行,**371 字节**,md5 `fd21d5ddc2759c2a7adf829074d51c63`)。本行 **2026-09-08T2x:xxZ 的变动:一条 `退回出集`(42 → 41)**,总监裁定全文 **§GD**。⛔ **不是 reject**,gate、helper 与两个常数(`X.nRGuardCloseBuffer=400` / `X.nRGuardRangeCap=200`)**逐字保留**(`bots/`+`game/` 零 diff);判定完结 **1**(owner P4.2 的产出指标,**不达 ≥2,理由见报告 §6,不粉饰**)。
1. **`cmrguard` 退集**(42 → 41)—— armed **20 天**、`verify=0`,是 2026-08-19 那一档 `verify=0` 的**最后一条**(前两条 `wandlimbo`/`tpdead` 于 §GC 退集)。条件 (a) 在 **fixture 路径**上买不到:veto 环是 `hCc:GetCastRange() + 400`,而那个 cast range 读的是**敌方**技能句柄,加载器从不服务它 —— 落 `bot_api.lua:184` 的 `^Get -> 0` 兜底。**487 个 curated hard-CC 句柄里读得出 cast range 的 137 个,恰好等于 KV 服务的那 137 个;350 个 0 全部来自兜底**(其中仅 100 个碰巧是引擎真答案)。⭐ **立案帧本身就在盲区里**:不由测试作者写入 cast range 时,armed 的 `cmrguard` 在 20260819_003005(Jakiro ice_path **1138.6u**)**放行**了那条要了 CM 命的通道 —— `1138.6 > 0 + 400`。全文 §GD。
**上一轮(2026-09-08T19:xxZ,44 → 42,§GC)的两条,留作沿革:**
1. **`wandlimbo` 退集**(44 → 43)—— armed **20 天**、`verify=0`,条件 (a) **在两条仪器路径上都买不到**:helper 的第一条合取是 `GetCurrentCharges() < 6`,而 fixture 侧 953 个 wand/stick 句柄**全部读 0**(落到 `bot_api.lua:184` 的 `^Get -> 0` 兜底),replay 侧 `dumper/main.go` 里 **`charge` 一次都不出现**(只发 `Items []string`)。全文 §GC。
2. **`tpdead` 退集**(43 → 42)—— armed **20 天**、`verify=0`,它是 §GA.1 逐字点名的「两个释放」之一,而那一轮**只裁了 `tpdying`**。同一个函数体、同一道 `tpcommit` 门:单独 armed 逐位 no-op,同时 armed 则读数**连符号都不可分解**。全文 §GC。
⭐⭐⭐ **本轮最该被读的一条(§GC.2):两条 id 各自都有一份绿的、钉在真实帧上的 fixture 测试,而两份都由测试作者**亲手写进了该杠杆唯一转轴的那个输入**。**
`test_replay_181441_wand_limbo.lua` 断言了真 HP(214/1354)、真敌距(~2017)、真泉水距,然后
`rawget(wand, '__spec').GetCurrentCharges = n`——**充能是 `wandlimbo` 相对已发行规则唯一多出来的子句**,而那个数字是作者选的(要触发写 12,不该触发写 3)。
`test_tpdead_release.lua` 同型:帧是真的,而 `bot.tpRespondLoc / tpRespondUntil / tpRespondAlly` 三行是它自己赋的——那正是让 `J.GetTpCommitDefendDesire` 可达的状态,本轮实测**在 1021 帧语料上一帧都不存在**。
⇒ **两份测试都没有错,错的是把它们读成条件 (a)**:这种测试问的是「给定这个输入,决策对不对」,而 (a) 问的是「这个输入到底出没出现过、出现时机器人决策对不对」。
**在一帧其余子句全部真读自 dump 的真实帧上,这两者极难分辨,而树里今天没有任何东西替人分辨。**
这就是两条 id 一边看起来「已 fixture 验证」一边挂着 `verify=0` 二十天的机制。
⛔ **退集针对的是仪器不是杠杆**:两条的逻辑依据 (c) 都成立且未被取代,`bots/` 零 diff,重新入集的条件写进 owed 行。
⚠️ **`promote_atoms.json:tp_response_releases_need_commit` 不动** —— 它约束的是 **promote 日**的配置(`tpdying`/`tpdead` 不得在 `tpcommit` 仍是候选时单独 promote),退集不是 promote;删掉它才会悄悄放开它存在的理由。它同时是本轮 §GC.3 的**第三个独立见证**:它 **2026-09-05** 就写下了同一处嵌套,比 §GA.1 早三天。
⚠️ **不掉进 `pullcad` 陷阱,断言过的**:两条各自**只有一个** gate 点(`jmz_func.lua:11317` / `:10126`),门行上没有第二个 id;`promote_atoms.json` 里没有任何一行的 **prereq** 点名这两条(点名的是它们作为 subject)。
⚠️ **载体项 7 → 7 逐字不变,量出来的**:`carrier_terms.py --arm` 对 44-id 与 42-id 两串各跑一次,`TERMS` 行**逐字节相同**,`0 unresolved` 两次;计数 `10 hero / 34 generic` → `10 / 32`(两条都是 generic)⇒ **选种解空间不受影响**。
⛔ **在此之前起飞的任何一波都不含本次变动** —— W57 及更早**不与 42-id 家族并池**。
〔历史,上一条变动〕**成员串 44**(**397 字节**,md5 `fe7a309fc06a229e97290b2db4c3bed3`)。**2026-09-08T0x:xxZ 的变动:一条 `退回出集`(45 → 44)**,总监裁定全文 **§FZ**。⛔ **不是 reject**,gate 与代码**逐字保留**(`bots/` 零 diff);判定完结 **3**。
- **`fieldregen` 退集**(45 → 44)—— P4.2 最老一档(armed **45 天**,verify=0),条件 (a) **从 fixture 那条路结构上买不到**(域 6/1021 帧,成因是语料 82.5% 是对线期而这条杠杆按构造是**过线后**的),且它是四臂 `fieldbuy` 族**已登记但机制未名**的混杂项;本轮把机制命名为**抢先**(同一函数体 :776 vs :833,同一件 `item_flask`,共用 stash 闸)。全文 §FZ。
**成员串 45**(上一行,**408 字节**,md5 `f4292f7bb9a5f112ed34af62cbe3c2a8`)。本行 **2026-09-07T22:xxZ 的变动:一条 `退回出集`(46 → 45)**,总监裁定全文 **§FX**。⛔ **不是 reject**,gate 与代码**逐字保留**(`bots/` 零 diff);判定完结 **1**。
- **`campbind` 退集**(46 → 45)—— 与前几轮两条**不同**:它不是从 P4.2 的最老一档选出来的(armed 仅 **2 天**),而是**录像组 09-04T21:56Z 在 GH #475 请裁、连续六轮没等到的那条三选一**,全文 §FX。

上一轮(**2026-09-07T19:xxZ**,46 → 两条退集后的 46)的表头保留在下面三行,不要与本行混读:
**成员串 46**(**417 字节**,md5 `cd3b46d4e3ca4a446272b330a09a2751`)。**2026-09-07T19:xxZ 的变动:两条 `退回出集`(48 → 46)**,总监裁定全文 **§FW**。⛔ **两条都不是 reject**,gate 与代码**逐字保留**(`bots/` 对这两条零 diff);判定完结 **2**(owner P4.2 的产出指标),连续第二轮达标。
1. **`l1trade` 退集**(48 → 47)—— armed **≥ 44 天**(`armed_since.json` 下界 2026-07-25),`verify_coverage.py` 读 **verify=0 / 179 份报告**,与上一轮两条同取自**全集最老的那一档**(P4.2「从核验记录最少、最难买 (a) 的 id 清起」)。
2. **`l5combo` 退集**(47 → 46)—— 同一档、同一读数、同一理由;两条是同一个杠杆的核心腿与辅助腿(`J.ShouldInitiateLaneKill` / `J.ShouldSupportComboKill`),**必须同批处理**:分开退会留下半个对子,而它们的自风险门是按「core 0.75 / support 0.60」成对设计的。
⭐⭐⭐ **本轮最该被读的一条(§FW.2):一个漏斗死在最后一条合取上,「子句为假」和「仪器看不见这条子句」长得一模一样 —— 而本轮第一版结论就是错的那一个。** 新建的域普查(`tests/_lanekill_domain_sweep.lua`)显示两条腿都**走完了整条合取链**才归零:`l1trade` 842 帧笼罩 → 295 有健康队友 → 138 有敌人在射程 → 131 过自风险 → **155 对候选 (bot,target) 过深度缰绳** → **0 lethal / 0 fires**;`l5combo` 130 → 33 → 30 → 22 → 16 → **11 对有己方核心压在目标上** → **0 / 0**。把它写成「这个杠杆的域是空的」是干净、好引、**错的**。
两条腿的最后一条合取都是**出向**爆发估计(我方队友 → 敌方目标),而**这套语料在恰好那个方向上是瞎的**:`tests/mock/replay_fixture.lua:714` 给每个英雄的 `GetEstimatedDamageToTarget` 是它在随后窗口里**对 subject 实际造成的伤害** ⇒ ally→enemy 在每一帧恒为 0,**这是语料格式的性质,不是树的性质**(`tests/mock/bot_api.lua:134` 从另一侧写着同一件事,并点名了它同样悄悄缴械的另外两个 helper)。
⭐⭐ **为什么这个 0 不是一眼可疑的(即它必须被量而不是被读)**:**同一个引擎调用、同一批帧、反方向是活的** —— 两条腿的自风险子句问的是 enemy→me,读到非零的帧 **18(l1trade)/ 9(l5combo)**,并**真的否决掉 138 帧里的 7 帧**。一个在同一批帧上、经同一个调用、一个方向活一个方向死的仪器,**读者盯着一个 `0` 是看不出来的**。⇒ 普查现在把**仪器状态**(`*_est_blind` / `*_est_live` / `*_incoming_live`)与**子句结果**并排打印,两者永不塌缩成同一个数(GH #171 形状)。
⇒ **本轮买到的不是裁决,是那 44 天 `verify=0` 为什么不会自己结束**:对这两条 id,条件 (a) **不是没人买,是从 fixture 这条路买不到**;每一个伸手去拿便宜工具的会话都会重新导出同一个 0,而**如果不核验,就会写下同一个错结论**。买 (a) 需要在**波次录像**上做行为检测器(引擎自己的估计器在那里是活的)—— 已登记 `iterations/owed_executions.json:lanekill_condition_a_detector`,**不留在散文里**。
⛔ **退集不销毁买 (a) 的能力**:W39–W53 的 dump 里两条都是 armed 的,检测器从**已经存在的语料**里买,零 AWS、零新局(与 `stayattr` 09-05、§FB 两条逐条同型)。
⚠️ **两条都不掉进 `pullcad` 陷阱,而这次是断言出来的不是查出来的**:各自**只有一个** gate 点(`jmz_func.lua:9010` / `:8940`),门行上没有第二个 id;`promote_atoms.json` 四行没有一行点名这两个(自检本轮 exit 0)。⭐ **那条断言的第一版是假的,变异台当场量到**:按 id 数自己的闸址计数**看不见第二个 id 加进同一行**(`A and B` 里仍然恰好有一个 `A`),M4 因此 SURVIVED;改成**枚举门前言里读到的每一个 id 并要求它只有这一个**之后 CAUGHT。
⚠️ **载体项 7 → 7 逐字不变,量出来的**:`carrier_terms.py` 对 48-id 与 46-id 两串各跑一次,`TERMS` 行**逐字节相同**(`crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`),`0 unresolved` 两次;计数 `10 hero / 38 generic` → `10 / 36`(两条都是 generic)⇒ **选种解空间不受影响**。
⛔ **在此之前起飞的任何一波都不含本次变动** —— W53 及更早**不与 46-id 家族并池**。
〔历史,上一条变动〕**成员串 48**(上一行,**433 字节**,md5 `51eb44347f25676ec5bf767383eed244`)。本行 **2026-09-07T16:28Z 的变动:两条 `退回出集`(50 → 48)**,总监裁定全文 **§FV**。⛔ **两条都不是 reject**,gate 与代码**逐字保留**(`bots/` 对这两条零 diff);判定完结 **2**(owner P4.2 的产出指标),连续四轮低于 ≥2 之后的第一轮达标。
1. **`teambrain` 退集**(50 → 49)—— armed **≥ 44 天**(`armed_since.json` 下界 2026-07-25,证据 `state.json:family_bisect_launch` 逐字引用了当天的 FamilyB arm 串),**全集最老的一档**,`verify_coverage.py` 读 **verify=0 / 178 份报告**。理由是 **`zusstatic` 那一型:条件 (a) 结构上买不到** —— `state.json:tpclaim_20260823.audit_verdict_teambrain`(2026-08-23,协同组自己的 backlog item 8 审计)逐字写着「the FINAL ITEM DESIRE IS UNBUYABLE from this corpus, and the reason is structural, not a corpus gap」:它唯一的调用者坐在 `J.IsDefending -> bot:GetActiveMode()` 后面,而那是**第十三条世界断言**(语料里每个英雄每一帧恒 0,`tests/test_activemode_world_assertion.lua`),落点 `X.GetDefendTPLocation` = `GetLaneFrontLocation` 是 **GH #61 已拒**的。⇒ 该审计的结论句是「`teambrain` has been in the armed set with **NO evidence that it ever moves a bid**」,而它写下之后这条 id **又 armed 了 15 天**。
2. **`capmono` 退集**(49 → 48)—— armed **19 天**(`armed_since.json` exact 2026-08-19),`verify_coverage.py` 读 **verify=0**。这一条与 1 **形状不同,不许混读**:它的 (a) **买到了,答案是 FAILED under isolation**(`state.json:capmono_NOT_PROMOTED_20260820`:32 局镜像 / 806 帧,DiD **−7.9pp ± 9.3**,|t| 0.84,每粒符号 2/4;当初那条 `+16.6pp WORKING` **被它自己的作者与当时的总监双双撤回**),(b) **UNJUDGEABLE**(四个经济量全空,而空的 A-B 只是上界)。
⭐ **本轮真正的裁定不是「它没通过」,是「让它继续 armed 的那三条理由已经过期,而没有任何东西替它举手」**:08-20 的裁定明写 `stays armed`,理由 (ii) 是「每一波 capmono-ON 的波都在**免费**为那个**波内**(within-arm)HP 梯度再读积攒 n」。**那笔免费的 n 攒了 19 天、十几波,而那次再读一次都没做过**(`next_step_zero_cost` 至今零执行,`verify=0`)。⇒ **一个「等着被免费买到」的条件,和一个没人买的条件,在 verdict 表里长得一模一样**;差别只在前者写了一句谁也没读的散文。本轮把它**从散文搬进 `iterations/owed_executions.json`**(自检第 9 条腿每轮替它举手),再退集。
⛔ **退集不销毁买 (a) 的能力,两条都是**:`capmono` 的再读用的是**已经存在的** 32 局语料(零 AWS、零新局),`teambrain` 的结论本来就是「这套仪器买不到」——退集不改变其中任何一句。与 §FB(`tpdying`/`tpreach`)、`stayattr` 09-05 三个先例逐条同型。
⚠️ **两条都不掉进 `pullcad` 陷阱,查过了**:各自**只有一个** gate 点(`jmz_func.lua:7647` / `mode_team_roam_generic.lua:128`),门行上没有第二个 id;`promote_atoms.json` 四行**没有一行**点名这两个(exit 0)。⚠️ **`tpclaim` 是唯一挂在 `teambrain` 上的东西**(源码注释:only reachable with 'teambrain' armed),而它**本来就不在 armed 串里**(gated、未 armed)⇒ **本次退集没有冻死任何一个 armed 杠杆**;将来 `tpclaim` 提入集必须**先**把 `teambrain` 重新入集,否则它的 armed 腿结构上是空的。
⚠️ **载体项 7 → 7 逐字不变,量出来的**:`carrier_terms.py` 对 50-id 与 48-id 两串各跑一次,`TERMS` 行**逐字节相同**(`crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`),`0 unresolved` 两次;计数 `10 hero / 40 generic` → `10 / 38`(两条都是 generic)⇒ **选种解空间不受影响**。
⛔ **在此之前起飞的任何一波都不含本次变动** —— W53(51-id)及更早**不与 48-id 家族并池**。
⭐ **本轮同时补上了「armed 了多久」这个量本身**:`iterations/armed_since.json` + `tools/agent/arm_since.py`(§FV.1),因为上一轮问这个问题时得到的答案**是容器的性质不是实验室的性质**(shallow clone 的 git 历史左删截)。**这两条退集用的就是它排出来的序**。
〔历史,上一条变动〕**成员串 50**(当时的第 2 行,**451 字节**,md5 `ecd706ca36424a8969b5585c6867680a`)。本行 **2026-09-07T10:xxZ 的变动:一条 PROMOTE(51 → 50)**,总监裁定全文 **§FT**。⭐ **本项目第七次 promote**(`slotpush`,锚点 `stable-v6`);判定完结 **1**(owner P4.2 的产出指标)。
1. ⭐ **`slotpush` PROMOTE**(51 → 50)—— 动作是**把 `jmz_func.lua:J.IsTeamPushingHighGround` 的实参由 `J.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' )` 改成 `J.IsModeTurbo()`**(§DU.6 红线:代码先改、串后改、**同一个 commit**),turbo 默认按 **team slot 1..5** 扫五个队友,**非 turbo 逐字未动**(flag 形参**保留**就是为了这一句成立)。三条件与各自的边界写在 §FT 与源码注释里;机器键 `state.json:slotpush_PROMOTE_20260907`。
⚠️ **(b) 引的是十波家族级读数**(W39/W40/W42/W44/W45/W46/W47/W48/W49/W50,**1 795 局计分**,家族 gpm `−12.58 / −27.81 / −19.15 / −9.60 / −6.19 / −20.26 / −5.95 / +27.25 / +11.70 / +13.76`,十波算术平均 **−4.88**)。成员资格照 §FQ.2 反查(每波 `arm_md5` → git 历史里的 `test_set.md` 第 2 行),**十个 md5 全部命中且每条都含 `slotpush`**;W41 从未收割、W43 报废、W51 是 `campgrade` 独占波,三者都不在表内。
⛔ **这个均值是轻微负的,本裁定不粉饰它**:铁律 2(b) 要的是粗粒度的「无明显负面」,家族级不可归因的 −4.88 gpm 是那个,**但它不是正面证据,永远不许当正面证据引**。⚠️ **与 `ckpush` 不同,本条的效应量不是按构造低于噪声**(§FQ.4 那套「等不到更好读数」的论证**不适用**),将来一波独占波**能**说得更多 —— **压住裁定的是 (c) 不是 (b)**。
⚠️ **载体项 7 → 7,`TERMS` 行逐字节相同**:`carrier_terms.py` 对两串各跑一次,`10 hero / 40 generic` 不变,`TERMS crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`。⭐ **那个 `unresolved` 又一次自己举了手**:promote 之后旧的 51-id 串在这棵树上**解析不了**(`slotpush` 没有 gate literal 可找)⇒ `1 unresolved` **退出码 2**,新串 `0 unresolved` 退出码 0。**代码改了而串没改的那半个状态会立刻变红,不是靠人记得**(与 §FK 同一条)。
⛔ **在此之前起飞的任何一波都不含本次变动** —— W53(51-id)及更早**不与 50-id 家族并池**。
⛔ **同轮退休** `state.json:coarmed_outlatch_slotpush_20260902` —— 那条同臂合取册自己写着「`slotpush` 被 promote ⇒ 届时**退休该行,不是删掉转绿**」,本轮照办。⚠️ **退休不等于混杂消失**:两条腿从此都带 `slotpush` 的否决,所以**差分里的混杂走了**,而**跨越今天的 `outlatch` (a) 依旧不可比**(W38 与 W39 起本就不是同一个量,今天起是第三段)。
1. ⭐ **`ckpush` PROMOTE**(52 → 51)—— 动作是**删掉 `hero_chaos_knight.lua` 里 `X.GetPushCommitTime` 那句 `and J.IsSoakCandidate( 'ckpush' )`**(§DU.6 红线:代码先改、串后改、**同一个 commit**),turbo 默认走修好的 `8 * 60`,**非 turbo 的 `8 * 30` 一字未动**。三条件与各自的边界写在 §FQ 与源码注释里;机器键 `state.json:ckpush_PROMOTE_20260907`。
⚠️ **(b) 引的是八波家族级读数**(W42/W44/W45/W46/W47/W48/W49/W50,**1 478 局计分**,家族 gpm `−19.15 / −9.60 / −6.19 / −20.26 / −5.95 / +27.25 / +11.70 / +13.76`,八波算术平均 **−1.06**)。**这八波的成员资格是量出来的不是读来的**:逐波拿 `W*_wave.json:arm_md5` 去 git 历史里反查 `test_set.md` 第 2 行,八个 md5 全部命中且每一条都含 `ckpush`(§FQ.2)——上一轮 §FO 就是在这一步上第一稿引错了波(W51 是独占波)。
⚠️ **载体项 8 → 7,`chaos_knight` 出表**:`carrier_terms.py --arm <51 串>` 打 `10 hero / 41 generic / 0 unresolved => 7 term(s)`,`TERMS crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`。`ckpush` 是集内**唯一**载 chaos_knight 的 id ⇒ 它一出集,阵容约束里那一项就消失(**方向是放松,不是收紧**;§DT.3 当初量到的「加这一项在紧的那条边上是零」,反过来同样成立)。**将来任何 chaos_knight 杠杆重新入集时这一项要跟着回来。**
⛔ **在此之前起飞的任何一波都不含本次变动** —— W52(52-id,在飞)及更早**不与 51-id 家族并池**。

〔历史,上一条变动〕**成员串 51**(**460 字节**,md5 `e61700f44778dc1ab67166922d22b0bc`)。

〔历史,上一条变动〕**成员串 52**(上一行,**467 字节**,md5 `445ea52100428d4e6c9aab31f3556245`)。本行 **2026-09-06T22:xxZ 的变动:两条 PROMOTE + 一条 `退回出集`(55 → 52)**,总监裁定全文 **§FO**。⭐ **本项目第四、五次 promote,与第三次同一天**;判定完结 **3**(owner P4.2 的产出指标)。
1. ⭐ **`odbuild` PROMOTE**(55 → 54)—— 动作是**删掉 `hero_obsidian_destroyer.lua` 里那句门**(§DU.6 红线;代码先改、串后改、**同一个 commit**),turbo 默认走修好的 `tObjurgationBuildList`,**非 turbo 一字未动**。三条件与边界写在 §FO.1 与源码注释里;机器键 `state.json:odbuild_PROMOTE_20260906`。
2. ⭐ **`illumove` PROMOTE**(54 → 53)—— 同上,删的是 `minion_lib/illusions.lua` 里 `IsPerUnitMoveClock()` 的那句门,turbo 默认给每个单位自己的移动时钟。§FO.2;机器键 `state.json:illumove_PROMOTE_20260906`。
3. **`towerfear` 退回出集**(53 → 52)—— `VERIFY id=towerfear verdict=WORKING episodes=248`(录像组 09-06T06:55Z)**只买到 (a) 的前半**;后半反号:被释放的 episode 摸进塔 700u 攻击圈的占比 **+12.46pp(ab)/ +35.21pp(ba),两层同号**(GH #558)。§FO.4;机器键 `state.json:towerfear_WITHDRAWN_20260906`。
⛔ **退集不是 reject**,gate 与代码逐字保留(`bots/` 对这一条零 diff);该 ship 的配置是 `towerfear`+`towerring` **那一对**,而 owner P4.2 的冻结禁止 `towerring` 入集 ⇒ 重新入集是**解冻后**的事,已登记 `iterations/owed_executions.json:towerfear_towerring_pair_readmit`。
⚠️ **两条 promote 的 (b) 引的是 W47–W50 的家族级读数**(62/63/61/59-id 家族,**701 局计分**,家族 gpm `−5.95 / +27.25 / +11.70 / +13.76`),**不是 W51** —— W51 是 `campgrade` 独占波,这两个 id 在它上面根本没 armed。
⚠️ **载体项 8 → 8 逐字不变,量出来的**:`carrier_terms.py` 的 `TERMS` 行逐字节相同(`obsidian_destroyer` 由仍在集的 `odaoe` 承载);计数 `12 hero / 43 generic / 0 unresolved` → `11 / 42 / 0`。`check_armed_wiring.py`:**all 52 armed ids wired on HEAD**。
⛔ **在此之前起飞的任何一波都不含本次变动** —— W51 及更早**不与 52-id 家族并池**。

〔历史,上一条变动〕**成员串 55**(上一行,**494 字节**,md5 `aa21e7087cddeda479b73e62aab5155a`)。本行 **2026-09-06T13:xxZ 的变动:一条 PROMOTE + 三条 `退回出集`(59 → 55)**,总监裁定全文 **§FK**。⭐ **本项目第三次 promote,距上一次(`creeppull`+`pullbeat`,2026-08-23)14 天。**
1. ⭐ **`slotwait` PROMOTE**(59 → 58)—— 出集的动作**不是只删这一行的 id**,是**删掉 `jmz_func.lua` 那句 `and J.IsSoakCandidate( 'slotwait' )`**(§DU.6 的红线,本轮逐字遵守:代码先改,串后改,**同一个 commit**)。三条件与各自的边界写在 §FK.1;稳定版锚点 **stable-v3**,机器键 `state.json:slotwait_PROMOTE_20260906`。
2. **`midtp` 退集**(58 → 57)—— `VERIFY id=midtp verdict=BUGGY episodes=8`(录像组 09-05T21:51Z):TP 落点在算术上不是合法坐标(GH #539)。
3. **`suptp` 退集**(57 → 56)—— `VERIFY id=suptp verdict=BUGGY episodes=16`(09-06T00:48Z):同一条接线的同一个 NaN,**外加**它的门被同集 `midtp` 完全支配,16/16 波次不承重(GH #545)。
4. **`roshdist` 退集**(56 → 55)—— `VERIFY id=roshdist verdict=BUGGY episodes=77`(09-03T09:59Z):**闸咬对了域、咬错了圆心**;根因是 `J.GetCurrentRoshanLocation()` 昼夜映射反了(GH #450,**77/77,0 例外**),而 `roshdist` 把一个此前从不被读的坐标第一次变成行为的依据。
⛔ **三条退集都不是 reject**,gate 与代码逐字保留(`bots/` 对这三条零 diff);重新入集路径:**先修各自的根因 issue,再重买 (a),再提入集**。这与 §FB 两条(条件 (a) 从没人买过)**形状不同**:这三条的 (a) **买到了,答案是 BUGGY**。
⚠️ **为什么和 promote 同轮**:一个 (a)=BUGGY 的 id 留在串里,armed 腿每一波都在执行一个已知错误的行为,而 (b) 是**家族级**读数 —— 它污染的正是 promote 唯一能引的那个量(§FK.2)。
⚠️ **载体项 8 → 8 逐字不变,量出来的**:`carrier_terms.py` 对两串各跑一次,`TERMS` 行**逐字节相同**(`chaos_knight,crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`);计数 `12 hero / 46 generic / 1 unresolved` → `12 / 43 / 0`。⛔ **那个 `1 unresolved` 是本轮的一条真读数**:promote 之后,**旧的 59-id 串在这棵树上已经解析不了**(`slotwait` 没有 gate literal 可找)⇒ 代码改了而串没改的那半个状态,`carrier_terms.py` 与 `check_armed_wiring.py` **都会立刻变红**,不是靠人记得。新串:`all 55 armed ids wired on HEAD`(`RC_EXIT=0`)。
⛔ **在此之前起飞的任何一波都不含本次变动** —— W50 及更早仍是 59/61/62/63-id 家族,**不与 55-id 家族并池**。

〔历史,上一条变动〕**成员串 59**(**524 字节**,md5 `572b60753699bc68b2ad5ec9020f2512`)。**2026-09-05T22:xxZ 的变动:两条 `退回出集`(61 → 59)**,总监裁定全文 **§FB**。⛔ 两条都**不是 reject**,gate 与代码**逐字保留**(`bots/` 零 diff),重新入集路径各自写在 §FB.5。
1. **`tpdying` 退集**(61 → 60)—— armed **17 天**(§A' 08-19 入集),`verify_coverage.py` 读 **verify=0 / 159 份报告**。
2. **`tpreach` 退集**(60 → 59)—— armed **12 天**(§BC 08-24 入集),同样 **verify=0**。
⭐ **退集的理由与 `zusstatic` 不同,必须分清**:`zusstatic` 是**条件 (a) 结构上买不到**;这两条**买得到**,而且各自的验收形状**在入集那天就写好了**(§A'.3 两个检测器 / §BC.4 `tp_channel_death.py` + 按 mode 分层,连降级读法都写了)。**从没人买过的原因不是难,是那份义务只写在 test_set.md 的散文里,没有落到任何一张真正驱动录像组的表上** —— 这正是 §2.5 / GH #413 立法过的那条缺陷,而那条立法只覆盖**裁定**,不覆盖**入集自带的验收义务**(全文 §FB.3,立案 **GH #540**)。
⇒ 本轮把两条 (a) 义务**登记进 `iterations/owed_executions.json`**(自检第 9 条腿每轮替它举手),再退集。**退集不销毁买 (a) 的能力**:W39–W49 的 dump 里两条都是 armed 的,(a) 从**已经存在的语料**里买,与 `stayattr` 09-05 的先例逐条同型(那条退集后录像组照样在 W48 上买到了 (a1) WORKING)。
⚠️ **`tpdying` 属共同 promote 原子 `tp_response_releases_need_commit`**(subject `tpdying`/`tpdead`,prereq `tpcommit`):**退集不是 promote**,原子行**一字不动**,`promote_atoms.py` 本轮 exit 0。`tpdead`/`tpcommit`/`tpgap` **留在集内**。
⚠️ **载体项 8 → 8 逐字不变,量出来的**:`carrier_terms.py` 对 61-id 与 59-id 两串各跑一次,`TERMS` 行**逐字节相同**(`chaos_knight,crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`),`0 unresolved`;计数 `12/49 → 12/47`(两条都是 generic)。⇒ **选种解空间不受影响。**
⛔ **W49 于 2026-09-05T21:19:57Z 起飞、`--ref` 钉死 `066219d6`,含这两个 id,不作废** —— 它的读数正是买 (a) 的语料。

〔历史,上一条变动〕**成员串 61**(**540 字节**,md5 `824ec2842e234693cb3c4094f73d6a14`)。**2026-09-05T15:5xZ 的变动:两条 `退回出集`(63 → 61)**,全文 **§EX**。
1. **`stayattr` 退集**(63 → 62,**550 字节**,md5 `c7e1f92c739f8f8dc0ee0c9484288628` —— 与 §EC 09-04T10:xxZ 的 62-id 串**逐字节相同**,不是新串)。理由**不是它的技术证据有问题**(§ET 的 (a)(c) 仍然成立):`OWNER_PRIORITIES.md` P4.2 于 **2026-09-05T14:5xZ** 补的「优先级澄清」**废止并压过 §BB.4**「搭车提议当轮放行」,冻结期唯一合法裁定是 **FROZEN-HOLD**;§ET 那次入集(11:xxZ)在澄清落地之前,被 owner 明写认定为违例并点名**「下一总监轮把 stayattr 退集回 62」**。⇒ 本行是**执行 owner 裁定**,不是总监改判 §ET。**W48 已在飞不作废**(它 clone 的是含 `stayattr` 的树),其 `stayattr` 读数按 §ET 归档为额外 (a) 证据。
2. **`zusstatic` 退集**(62 → 61)—— 总监本轮自己的判定完结,按 P4.2「从核验记录最少、最难买 (a) 的 id 清起」,取自 `verify_coverage.py` 的 **BLIND SPOTS** 两条之一(`midtp` / `zusstatic`:VERIFY 0 **且**任何报告里 id 附近从无裁定词)。⇒ **条件 (a) 结构上买不到,加局无用**(与 `l1xpsoak` 08-19 同型,不是 `pullcad` 陷阱:`zusstatic` 全仓**只有一处闸址**且**不与任何 id 合取**)。
⚠️ **载体项 8 → 8 逐字不变,而且这次是量出来的**:`carrier_terms.py` 对 63-id 与 61-id 两个串各跑一次,`TERMS` 行**逐字节相同**(`chaos_knight,crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`),`0 unresolved`;计数从 `13 hero-scoped / 50 generic` 变成 `12 / 49`(各减一条),**项数不动的机械理由**是 `zuus` 仍由 `zusult`/`zusboltdom` 供着、`stayattr` 本就是 generic。⛔ 与 §ET.4 / GH #522 同一条警告:**载体项会在 arm 串一字不动时改变**,不要把差额读成本次退集带来的。
⛔ **在此之前起飞的任何一波都不含本次变动** —— 与 §EC/§ET 同一条规则:实例发波时 clone `origin/main`,所以本次变动**自本行落地之后的第一波起首次生效**,更早的波仍是 62-id / 63-id 家族,三族不并池。

〔历史,上一条变动 —— ⚠️ 它写的「上一行」在 2026-09-05T15:5xZ 之后**不再指第 2 行**〕**成员串 63**(上一行,**559 字节**,md5 `4aefc887f3f8c9173e7ac7024b3c20c9`)。本行 **2026-09-05T11:xxZ 的变动:`stayattr` 单独入集**(62 → 63,总监裁定全文 **§ET**,提议 §EQ / 协同组 07:3xZ 报告;queue `strategy-44`,裁定落在它的 `director` 字段)。⛔ **在此之前起飞的任何一波都不含它** —— 与 §EC 同一条规则:实例发波时 clone `origin/main`,所以本次变动**自本行落地之后的第一波起首次生效**,更早的波仍是 62-id 家族,两族不并池。⚠️ **载体项本轮是 8 项不是 7 项,而多出来的那一项与本次入集无关**:`carrier_terms.py` 对 62-id 与 63-id 两个串各跑一次,`TERMS` 行**逐字节相同**(`chaos_knight,crystal_maiden,lion,obsidian_destroyer,pudge,skeleton_king,spirit_breaker,zuus`),`0 unresolved` ⇒ **`stayattr` 对载体项零贡献**(它是 generic:唯一闸点 `bots/FunLib/jmz_func.lua:5116`,没有任何 `botName == ...` 守卫罩着它)。**`pudge` 是 `rotscope` 带来的,而 §EC 在 09-04T10:xxZ 对**同一个 md5 的 62-id 串**记的是 7 项、不含 `pudge`** —— 同一个串、不同的树,读数不同;今天的推导是**对的**(`rotscope` 的闸址 `bots/mode_roam_generic.lua:1039` 住在`if botName == 'npc_dota_hero_pudge'` 里面,只有 pudge 执行得到它)。⇒ **载体项会在 arm 串一字不动的情况下改变**,已立案(见 §ET.4),**不要把它读成本次入集带来的**。
〔历史,上一条变动 —— ⚠️ 它写的「上一行」在 2026-09-05T11:xxZ 之后**不再指第 2 行**〕**成员串 62**(当时的第 2 行,**550 字节**,md5 `c7e1f92c739f8f8dc0ee0c9484288628`)。本行 **2026-09-04T10:xxZ 的变动:`campbind` + `zusboltdom` 同轮入集**(60 → 62,总监裁定全文 **§EC**,提议 §DZ / 英雄组 07:51Z 报告,GH #475 / #477;queue `strategy-42` / `hero-29`)。

⛔ **W45 不含这两个 id** —— 它于 2026-09-04T06:30:38Z 起飞(`machines[0].launched_at`,权威字段),clone 的是 60-id 串(md5 `eef5fb2e…`),**本次变动自 W46(或其后第一波)起首次生效**。⇒ **W45 仍是 60-id 家族的唯一一波,W46 起是 62-id 家族** —— 两波不并池(`W45_wave.json:pooling_claim` 已预登记它单独站着,本裁定不改它)。
⚠️ **载体项 7 → 7 逐字不变,而且这次是量出来的**:`carrier_terms.py` 对 60-id 与 62-id 两个串各跑一次,`TERMS` 行**逐字节相同**(`chaos_knight,crystal_maiden,lion,obsidian_destroyer,skeleton_king,spirit_breaker,zuus`),`0 unresolved`。分类:`campbind` = **generic**(唯一闸点 `jmz_func.lua:8993`,唯一消费者 `mode_roam_generic.lua`),`zusboltdom` = **hero `zuus`**(`hero_zuus.lua:1032`)—— 而 `zuus` 已由 `zusult`/`zusstatic` 供在项里 ⇒ **两条对载体项零贡献**,不必重算 `BEST min-per-term`;载体供给自己的账仍每波重算。
⚠️ **`campbind` 不是 GH #473 甲(载体门看不见「域=一个英雄、文件=generic」)的又一例**:它的域确实是 generic —— 上游 `pullcamp` 只把 `J.IsCore(bot)` 排除掉,要求的是**队伍里有辅助**,不是某个具名英雄。`rotscope`(域=pudge)那条腿的失效在这里不成立,已逐点核过,**不是照抄提议方的话**。
**⚠️ 收割前必读**:`campbind` 的 (a) 判据是**戳的是哪个营地**不是**戳了几次**(§EC.3;戳次下降正是它要买的),且**与 `pulldrag` 不正交** ⇒ `pulldrag` 的 connect 读数换了定义域,**不许与 W45 及更早的波并池**;`zusboltdom` **必须与 `zusult` 同腿 armed**(否则储备门对任何目标都答 false,读数结构上是空的),而 `zusboltcap` **不在本串里**,所以本波的 (1) 归零可以归因(§EC.4)。
**上一次变动**(60-id 串,**530 字节**,md5 `eef5fb2ef553d96a50960988d482ca4e`):**2026-09-04T01:xxZ 的变动:`arbheart` + `slotwait` 同轮入集**(58 → 60,总监裁定全文 **§DX**,提议 §DV / §DW,GH #455/#456 与 #467;queue `strategy-40` / `strategy-41`)。
⛔ **W43 与 W44 都不含这两个 id** —— 两波分别于 2026-09-03T18:21:58Z / 09-04T00:18:45Z 起飞,clone 的都是 58-id 串(md5 `7009f6c5…`),**本次变动自 W45(或其后第一波)起首次生效**。
⚠️ **载体项 7 → 7 逐字不变** —— 两条都是 generic(`arbheart` 在 `mode_farm_generic.lua`、`slotwait` 在 `utils.lua`,`carrier_terms.py` 自判 `kind=generic`),对载体项**零贡献** ⇒ **不必重算 `BEST min-per-term`**;载体供给自己的账仍每波重算。
**⚠️ 收割前必读**:`arbheart` 的 (b) **与 `slotarb` 混淆且方向偏向让它好看**(§DX.5)⇒ **不许拿 co-armed 波的 (b) 单独给它背书**;`slotwait` 的条件 (a) **必须在真帧上买**,mock 上那个「98 次求值 0 次 TRUE」的零是一台瞎仪器(§DX.6)。
**上一次变动**(2026-09-03T16:0xZ,57 → 58,`wandbleed2`,md5 `7009f6c512e1b6bdf514401f20178eca`,512 字节)裁定全文 **§DU**,提议 §DS,GH #437;queue `strategy-39`。
⛔ **W41 与 W42 都不含这个 id** —— 两波分别于 2026-09-03T03:31:51Z / 09:32Z 起飞,clone 的都是 57-id 串(md5 `38423b79…`),**本次变动自 W43(或其后第一波)起首次生效**;W41+W42 之间的可并池性不受影响。
⚠️ **载体项 7 → 7 逐字不变** —— `wandbleed2` 是 generic(`carrier_terms.py` 自判 `kind=generic`),对载体项**零贡献**。⇒ **不必重算 `BEST min-per-term`**(§DT.3 那一格对本条不适用);但载体供给自己的账仍要每波重算(W41 起飞时 `[2601,3000]` 上 `>=2/term` 已搜出 0)。
**⚠️ 收割前必读(§DU.5):本条是 NARROWING** —— **`wandbleed` 触发计数下降本身不是负面信号**,那正是本 id 要买的;要读的是**掉的那些帧里有没有活着的攻击者**。承重的阴性面(保留下来的触发,4000 环内活敌人数必须 ≥1)**与主判据同等必读**,否则「armed 少喝魔杖」与「armed 干脆不喝魔杖」在同一个数字上不可分。域为零按 `DOMAIN-NOT-REACHED` 退回,**不得**读成「无效应」(六个合取项,最后一项本地命中率 **3/81 = 3.70%**,**分子分母都是「帧」**;⛔ 原写作 `2/101`,分子是帧、分母是「受害者-攻击者对」,见 §DU.8)。
**⛔⛔ promote 关口红线(§DU.6):promote `wandbleed2` 的动作不是把它从 armed 串里删掉,是删掉 `jmz_func.lua:9585` 那一行。** 闸朝「无操作」失效 ⇒ 只删串不删代码,这条收窄会在 promote 当天静悄悄取消**而没有任何东西变红**(`pullcad` 的倒像)。同族另有 `fieldsip` / `teambrain`。

**上一次变动**(2026-09-03T01:xxZ,55 → 57,`roshdist`+`ckpush`,md5 `38423b791c05d96e0e16ed0b51bd132d`,501 字节)裁定全文 **§DT**,提议 §DP / §DQ,GH #422 / #426;queue `strategy-37` / `strategy-38`。⚠️ 那次载体项 6 → 7(新增 `chaos_knight`),价已量为**在紧的那条边上是零**(§DT.3)。
**再上一次变动**(2026-09-02T04:xxZ,52 → 54,`slotarb`+`slotdust`,md5 `80392b258fcd214cf351231be61d15a4`,476 字节)裁定全文 **§DK**,提议 §DI / §DJ,GH #406 / #411。
**⚠️ 收割前必读(§DK.3,`slotarb` 的入集是条件性的,这一条不成立时撞车数下降不构成条件 (a))**:提议的验收只有「撞车变少」,而**「撞车变少」与「谁都不去打野」在那份读数上是同一个数字**。全部营地被拒 ⇒ `mode_farm_generic.lua:805` 的 `if preferedCamp ~= nil then` 整块跳过、**没有 else** ⇒ 一个 Farm 模式的 bot 这一帧不下达任何打野动作;而出厂 dire 侧只扫 slot 5,**五路仲裁从未真正运行过**,armed 是第一次把一个**唯一输出是「拒绝」**的机制全量打开。⇒ 必须同时读**负控**:armed 腿「Farm 模式且无营地」的占比**不得上升**,**两个分层各自登记**。
**⚠️ 收割前必读(§DK.1 (v-b)):`slotdust` 不是子集,`slotarb` 才是** —— 两个函数只差一个初值(`closestMember = bot` vs `closest = nil`),`slotdust` armed 会让 dire 侧四个今天结构性用不了粉的 bot **开始用粉**,那是**积极动作不是撤回**。按 §DI 的模式匹配读会读反(§DF.2 (ii) 同族第二发)。
**⚠️ 收割前必读(§DK.5):两条彼此正交,但都按侧不同** —— 归因分得开的前提是**分层登记**;谁把它们并成「`0SLOT9` 家族」读一个池化的按侧读数,就会把两条搅在一起。**别并池。**

**2026-09-01T22:xxZ 的变动(历史行):`tormself` 与 `immguard` 两条同轮出集**(54 → 52,总监裁定全文 **§DH**,GH #402)。**出集不是 reject** —— gated 代码留在树上、门保持关闭;出的理由是**条件 (a) 在当前 47 人 `hero_pool.txt` 下买不到**:真载体 `ringmaster` / `brewmaster` **都不在池里**,任何种子、任何窗口、任何重抽都改变不了这一点。上一次变动(52 → 54,两条**入**集)全文见 **§DF**,提议 §DD / §DE,GH #385 / #393。
**⚠️ 收割前必读(§DF.5):这两条彼此正交** —— 不同英雄(Ringmaster / 酒仙)、不同文件、不相交的调用路径,**没有 §DC.3 那种「交集上不能分摊归因」的限定**。**阴性也登记**:一道只在命中时才被记录的检查,通过时就变成隐形的,下一个读者无从分辨「查过且正交」与「根本没查」。
**⚠️ 收割前必读(§DF.3):`tormself` 的条件 (a) 买不到于 `corpus_query`** —— 提议那条「全语料 993 个句柄为真 0 次」跑的是**英雄索引**,而 Tormentor 是**中立单位**,`detect.Timeline` 根本不索引它(backlog #1 自己写明的 LIMIT)。那个数字是**关着那条臂**的域的正确测量,是**开着那条臂**的**零信息**。**谁把它读成「这修复不会有效果」,就是拿错臂的读数当结论。**
**⚠️ 收割前必读(§DF.2 (ii)):`tormself` 是严格超集,`immguard` 是严格子集** —— §DC 那一族全是超集,按模式匹配读会读反。
**⚠️ §DF.6:两条都落在非焦点英雄上**(同族第 8、9 条)⇒ **预期会出现一串 `DOMAIN-EMPTY` 收割**,而**那一串不构成关于这些修复的任何证据**;判 `DOMAIN-EMPTY` 必须退回总监重裁,**不得**自行套用「无效应 ⇒ 不 promote」。

**2026-09-01T10:2xZ 的变动(历史行):`illumove` 与 `illureal` 两条同轮入集**(50 → 52,总监裁定全文 **§DC**,提议分别是 §CZ / §DB,GH #378 / #381;queue `strategy-29` / `strategy-30`)。
**⚠️ 收割前必读(§DC.3,总监加的第 (丁) 条限定,两份提议里都没有):`illumove` 与 `illureal` 改的是同一个文件里同一条 `X.Think` 路径,同帧内不正交** —— `illureal` armed 会让更多幻象在 `illusions.lua:80` 的诱饵分支里**提前 `return`**,那些单位**根本走不到 `:94` 的移动闸**,于是 `illumove` 的域被 `illureal` 缩小。两条同波 armed 时,**落在「非娜迦/PL 幻象 ∧ 主人 <40% ∧ 撤退 ∧ 非强势」这个交集上的帧不能分摊归因**;交集之外两条互不影响。**没有任何测试钉住这一条**(两份验收各自只 arm 自己那一个 id),所以它必须靠读这一行才知道。

**2026-09-01T01:0xZ 的变动(历史行):`roamidle` 与 `outlatch` 两条同轮入集**(48 → 50,总监裁定全文 **§CY**,提议分别是 §CW / §CX,GH #370 / #373;queue `strategy-27` / `strategy-28`,**两行都由提议方自己建** —— §CG.5 的上游那半这一轮第一次不用总监代建)。两条都是**搭车、零 AWS 增量、不申请专波、零 EC2**,按 §BB.4 放行;**各自到达后第一个总监轮次内裁毕**。
**收割前必读三条**:(i) ⚠️ **两条的域都可能为空,而这正是它们要买的东西** —— `roamidle` 的域是「team_roam 赢下竞价 **且** bot 已闩上 idle」,`outlatch` 的域是「敌方二塔已倒 **且** 那次扫描返回空表」;**恒零读数必须报成「域为空」,不许报成「测过了无效应」**(§AZ / GH #148 那一族),两者在 verdict 表里长得一样而含义相反。**两条都不能当独臂。**(ii) ⚠️ **`outlatch` 的 armed 腿有一条出厂腿没有的持续成本(总监加的第 (丁) 条限定,提议里没有)**:出厂全局只扫一次 `GetUnitList(UNIT_LIST_ALL)`,armed 在「二塔已倒且表仍空」期间**每个 bot 每游戏秒扫一次直到本局结束** ⇒ armed 腿若读到帧时间/经济的负向漂移,**这条要先排除,不许先归因到别处**。(iii) **两条买的都不是它们最容易被读成的那件事**:`roamidle` 买的是**那一帧的排序**,§CW.3 的每帧重复(`return true` 排在锚点刷新之上)**一字未修**;`outlatch` 买的是**闩的后置条件**,§CX.3 的 `IsNull()` 排在第四位求值**一字未修**。 (iv) ⚠️ **2026-09-02T13:xxZ 补(GH #424,全文 §DN.6):`slotpush` 入集后,`outlatch` 的 armed 腿测的是 `outlatch AND NOT slotpush 否决`** —— `slotpush` 的闸包装 `J.IsTeamPushingHighGround` 是 `mode_outpost_generic.lua:45` 那个**提前 return**,排在 `outlatch` 的闸(`:79`)**上面**,而 armed `slotpush` 扫 5/5 slot(出厂 radiant 4/5、**dire 1/5**)⇒ 否决更频繁、**dire 侧被拿走的帧约是 radiant 侧的 5 倍**,且**优先落在 `outlatch` 自己的域里**(二塔已倒之后)。⇒ **`outlatch` 的 (a) 必须分层登记,两层反号按铁律 4(i-b) 读成噪声**;**W38(54-id,无 `slotpush`)与 W39 起(55-id)的 `outlatch` (a) 不是同一个量,不许跨波比**。

**成员串 48**(上一行,**423 字节**)。本行 **2026-08-31T19:0xZ 的变动:`rotscope` 入集**(47 → 48,总监裁定全文 **§CV**,提议 §CU,GH #368;queue `strategy-26`,**总监代建**——协同组本轮按 §CU.7 明说 `queue.json` 一字未动,而 §CG.5 要求提议必须有行)。**搭车、零 AWS 增量、不申请专波**,按 §BB.4「搭车提议的唯一成本就是不被裁」放行;**到达后第一个总监轮次内裁毕**(16:5xZ 到,19:0xZ 裁)。
**收割前必读两条**:(i) ⚠️ **`rotscope` 只对 Pudge 可达** ⇒ **没抽到 Pudge 的波次对它读数恒为零**,它**永远不能当独臂**;把「零读数」读成「无效应」是把 §CU.7 的排期约束丢掉,条件 (a) 需要一局有 Pudge 的对局。(ii) **它买的是作用域,不是连续性** —— armed 之后那条命令仍是 `bOnce=false` 的连续命令(§CU.2 第 2 条那一半**没有**被这个 id 修掉),写结论时不要把「命令被收窄到被守卫过的句柄上」读成「`roamreach` 那一族的形状已消除」。

**成员串 47**(上一行,**414 字节**)。本行 **2026-08-30T22:0xZ 的变动:`creepthink` / `lionqdmg` / `cmqreach` **三条同轮入集**(44 → 47,总监裁定全文 **§CO**,提议分别是 §CK / §CM / §CN;queue `strategy-25` / `hero-24` / `hero-25`)—— 三条都是**搭车、零 AWS 增量、不申请专波**,按铁律 §BB.4「搭车提议的唯一成本就是不被裁」放行;`cmqreach` 是**到达那一轮就被裁的第一条**。
**收割前必读四条**:(i) **W30 起的读数不得与 W29 并池** —— 串不同(44 → 47),W29 那四粒是 44-id 家族的**唯一一波**,不会再被补厚;**这是可接受的,理由写在 §CO.4:owner 2026-08-01 的验证哲学里,条件 (b) 是「无明显负面」的粗粒度读数,不是显著性检验** —— 把 SE 26.56 读成「4 粒不够裁」等于把 08-01 废掉的那个检验又请回来。真正卡住 44/45-id 家族 promote 的是**条件 (a) 的逐 id 帧核验**,不是 (b) 的精度。(ii) ⚠️ **`pullcad` 的读数也在 W30 断了一道界**,而**没有人提议改动 `pullcad`**:`creepthink` 改的是那段代码**多久被问一次**,`pullcad` 的常数就坐在那个频率里(§CO.1)。**W30 起的 `pullcad` 读数不得与 W25–W29 的并池。**(iii) `creepthink` 的 (a) **有波内同域镜像对照**(`J.ShouldCreepPullLane` 无 soak gate,勾线两腿都跑),**不要**把 `pullthink` 的跨波致歉抄过来;但 `pullcad` 同波共 armed ⇒ 归属规则见 §CO.1。(iv) `lionqdmg` / `cmqreach` 是**归档扫描**(零 EC2),`executor` = `replay-check`,与 hero-14 / hero-17 合并成一次扫描;两条各自的 **UNINTERPRETABLE 退回门**写在 `queue.json` 的 `director` 字段里,**收割前必读**。

**成员串 44**(上一行,**385 字节**)。本行 **2026-08-30T10:09Z 的变动:`fieldcreep` 退集**(45 → 44,总监裁定全文 **§CJ**,起因 GH #325 / #323 / #327)—— gate 与代码**保留、永不 arm**(当前形态),退回协同组。**⚠️ 这个 44 与 08-29T10:xxZ 那个 44 不是同一个串**(那个含 `fieldcreep` 不含 `fieldsip`,388 字节;本串 385)—— 别按 id 数对读。
**收割前必读三条**:(i) **W29 起的读数不得与 W27/W28 并池** —— 串不同,而差的那一个 id 恰好收窄了 `stayfield`/`stayfield2`/`fieldbuy`/`fieldsip` 四个 id 共用的 `J.IsFieldRegenSituation` 域(§AR.0 当初同波 arm 就是为了这个);(ii) **已收割语料(W25–W28)= 带 `fieldcreep` 的窄版本,W29 起 = 不带**,两侧各自内部自洽,**跨界并池才是错的**;(iii) `fieldsip` 的 (a)(`strategy-23`)读的是**已落地的 W27/W28 语料**,不需要新波次 ⇒ **本次退集不作废它**,但它买到的是窄版本上的读数,写结论时要带这个限定。
**成员串 45**(历史,2026-08-29T18:5xZ 起至 08-30T10:09Z)。那一行的变动:`fieldsip` 入集**(44 → 45,总监裁定全文 **§CG**,提议是 §CE)—— 搭车、零 AWS 增量、不申请专波。**收割前必读两条**:(i) 它的 (a) **不得**从 `stayfield`/`stayfield2` 的留守率差分读出(那批帧上四个 id 同时动手,§CG.4);(ii) **书面条件 D**(§CG.3):`fieldbuy` 一旦出集/promote,**同一工作单元内**必须一并处置 `fieldsip` —— 这条**故意不写成代码合取**(写成合取会在 `fieldbuy` promote 当天冻结为 FALSE,`pullcad` 原案)。**⚠️ 顺带记一条别的组要用的事实**:本条提议在 `queue.json` 里**没有请求行**,于是开工自检的 `pending_rulings.py` 连续三轮报 `none` 而它一直未裁(§CG.1)⇒ **提入集必须同时开 queue 请求行** —— 这条规矩本身不变,但它**不再只靠自觉**:`ORPHAN_PROPOSAL` 检测器 **2026-08-29T2x:xxZ 已落地**(`tools/agent/pending_rulings.py`,开工自检第 4 条腿),没有请求行的入集提议现在会被点名并把自检退出码抬到 **3**;回放 §CE 那一刻的三份文件,它逐字打出 `ORPHAN_PROPOSAL: 1 / §CE id=fieldsip`。

**成员串 44**(历史,2026-08-29T10:xxZ 起至 18:5xZ)。那一行的变动:`odbuild` 与 `wkqdmg` 双双入集**(42 → 44,总监裁定全文 **§CF**,提议分别是 §CC / §CD)—— 两条都是**搭车、零 AWS 增量、不申请专波**,按铁律 §BB.4「搭车提议的唯一成本就是不被裁」当场放行;两条各自的 **UNINTERPRETABLE 退回门**(`odbuild` 看 `skill_point_stall.py`,`wkqdmg` 看 WK 等级分布)写在 §CF 与 `queue.json` 各自的 `director` 字段里,**收割前必读**。

**成员串 42**(上一行)。本行 **2026-08-29T00:xxZ 的变动:`campexit` 退集**(43 → 42,总监裁定全文 **§CB**,03:5xZ 前写作 §CA)—— 立案量(等级)在协同组深查的六段上是**常数**,而谓词只读等级 ⇒ 六段全释放,其中**四段是盈利的吃下**;gate 与代码保留、永不 arm,退回协同组按**完成度轴**重窄。下方 43 那段是 06:5xZ 的历史记录,原样保留。

**成员串 43**(历史,2026-08-28T06:5xZ 起至 08-29T00:xxZ)。那一行的**两处变动**(全文档案 **§BW**):
**`campvoid` 入集**(协同组 §BT,GH #265 的落地物)+ **`campexit` 入集**(协同组 §BV,
GH #265 的预登记证伪落地物)。**两条都搭车、零 AWS 增量、不申请专波。**
总监**在源码核过两条的单向性**(§BW.1):`campvoid` 的 filter 是**只删不增**
(`aba_site.lua:616-633`,`kept[#kept+1]` 追加式,无删可删时**返回同一张表**)⇒
`#nNeutrals == 0` 只能 false→true ⇒ 它只能**打开**那条小兵出口,**关不掉**出厂走过的任何一条;
`campexit` 未 armed **字面量 `return false`**(`jmz_func.lua:2013`)⇒ 结构性惰性。
**⚠️ 附加条件(§BW.3)**:`campexit` 的 (a) **不得从 10..11 带的 armed−baseline 差分读出** ——
同一条腿上 `campfarm`/`campvoid` 也在改这批帧,那个差分是**三个 id 的合力**;
它自己的 (a) 只能来自**触发级逐帧**(退役营地 + move,且整个 sweep 都是梯子拒绝的)。
**⚠️ 顺序事实(§BW.2)**:两者同在 `Think()`,`campvoid` 的消费点在 **:752**、`campexit` 的分支在 **:892**,
前者动手就 `return` ⇒ **重叠帧上 `campvoid` 抢走 `campexit` 的触发**;
故 `campexit` 的 armed 腿触发计数是它真实域的**下界**,**低计数不是「它没生效」的证据**。

（上一行的历史记录)2026-08-28T00:5xZ 的**一处变动**(全文档案 **§BS.4**):
**`aimguard` 入集**(协同组 §BR.1,GH #262 的落地物)。**搭车、零 AWS 增量、不申请专波。**
门是**它自己那一条**(`jmz_func.lua:3928`,`IsModeTurbo` and `aimguard`)⇒ **无合取项**,
总监已在源码核过 **armed ⊆ 未 armed 是结构性的**(未 armed 结尾 `return true`,armed 结尾
`return J.CanBeAttacked(hTarget)`)⇒ 它只能**扣下**一次今天会发生的冲锋,**造不出一次**。
**⚠️ 附加条件(§BS.4)**:它的 (a) 读数**必须来自双层语料**;单腿孤儿语料上的读数按
`SINGLE-LAYER` 处理(GH #257/#266),**不得记为 (a) 的一半**。

**⚠️ 发波前必读(cand 串长度,2026-08-28T06:5xZ 实测)**:43 id 的裸 cand 串 **381 字节**
(41 id 时 363,40 id 时 354)。本轮 `check_armed_wiring.py --cand <43 串>` =
**43/43 WIRED,exit 0**;`campvoid` direct、1 站点(`mode_farm_generic.lua:119`),
`campexit` direct、1 站点(`mode_farm_generic.lua:892`)。S3 key 上限 1024,**仍有余量**;
ext4 的 255 早已跨过(GH #167),绕法与判据照旧。
**⚠️ 行号漂移提醒(照 §BG 的老规矩)**:本轮实跑里 `aimguard` 报在 `jmz_func.lua:3993`
(§BS 记的 3928,**六小时漂了 65 行**)、`bbfight` 10770(§BM 记的 10594)、
`bbshort` 10809(§BM 记的 10633)、`zusstatic` `hero_zuus.lua:506`(§BF 记的 360)、
`abilanc` 1850(§BM 记的 1845)—— **行号是会漂的引用,id 不会**;
排波与核对一律以**当轮实跑输出**为准,不要引用历史报告里的行号。


**成员串 40**(上一行)。本行 2026-08-26T22:xxZ 的**四处变动**(全文档案 **§BM**):
**`abilanc` 补录**(§BL 09:5xZ 已裁 APPROVED,但**这一行迟了四轮没同步** —— GH **#210**,本轮结案)+
**`bbfight` / `bbshort` 入集**(GH #218 裁定,§BM.1)+
**`pullthink` 入集**(`strategy-18`,GH #186,§BM.7 —— **它是本轮修好 `pending_rulings.py`
之后第一个被工具报出来的待裁请求**)。**四条都是搭车、零 AWS 增量、不申请专波。**

**⚠️ 关于 `abilanc` 那一格,要记的不是「补上了」而是「为什么补了四轮才补」**:
§BL 是**正式裁定且就写在本文件里**,而第 2 行是它**尚未同步的投影**;批测台章程步骤 6
写的取串规则是「第 2 行**逐字**」⇒ W14 与 W15 **两波**都得靠人**手工判「裁定压过陈旧的行」**
才没漏掉它(见 GH #210 与批测台 21:15Z 报告 §arm 串的裁决依据)。
**这条与 §AW.1 是同一个形状的第三例**:裁定作出了、存进了档案、**没落到被裁方读的那一行上**。
⇒ **本轮起把它并进裁定动作本身**:入集裁定**未改第 2 行 = 裁定未完成**,不许留到「下一轮补」。

**⚠️ 发波前必读(cand 串长度,本轮实测)**:40 id 的裸 cand 串 **354 字节**(36 id 时 320)。
本轮 `check_armed_wiring.py --cand <40 串>` = **40/40 WIRED,exit 0**;
`abilanc` jmz_func:1845(direct,1 站点)/ `bbfight` jmz_func:10594(1)/ `bbshort` jmz_func:10633(1)/
`pullthink` mode_roam_generic:224(**2 站点** —— 它是一个 id 的两个不可分半边,见 §BM.7)。
S3 key 上限 1024,**仍有余量**;ext4 的 255 早已跨过(GH #167),绕法与判据照旧。

**⚠️ 本轮新增的互斥前置(§BM.3,排波必读)**:**`bbrespawn` 与 `bbshort` 不得同腿 arm。**
`bbrespawn` 目前是 REJECTED + `readmit_on`(不在串里),但它的复活条款**恰恰以 `bbshort` armed 为触发**,
所以这条互斥**从它回到排期轴的那一刻起立即生效**,不是将来某天的事 —— 理由见 §BM.2 的格点读数。

- 上一行的 36 是 2026-08-25T16:0xZ 那一处变动(全文档案 **§BG.3**):
**`campfarm` 入集**(协同组 `strategy-17`,GH #137 §3 建议 2)。**搭车、零 AWS 增量、不申请专波。**
门是**它自己那一条**(`mode_farm_generic.lua:78`,`IsModeTurbo` and `campfarm`)⇒
**无合取项、无 §BA.2 冻结风险,单独 arm 即有意义**。
**⚠️ 排波前置**:`campgrade` **不在**本串 ⇒ 界后第一波能干净读到本 id;
`campgrade` 将来入集时**两者不得同腿 arm**(它在上游把远古营从名单里删掉,
同腿会让本 id 的域读不到)——**这条已写进 `campgrade` 未来入集裁定的前置检查**,
与 08-25T13:xxZ 给 `campsel` 写的那条并列。裁定三条附加约束见 §BG.3(甲)(乙)(丙)。

**⚠️ 发波前必读(cand 串长度,本轮实测)**:36 id 的裸 cand 串 **320 字节**(35 id 时 311)。
本轮 `check_armed_wiring.py --cand <36 串>` = **36/36 WIRED,exit 0**,`campfarm` direct、
1 站点(`mode_farm_generic.lua:78`)。S3 key 上限 1024,**仍有余量**;ext4 的 255 早已跨过(GH #167),
绕法与判据照旧(见下一节)。
**⚠️ 顺带一条会咬人的**:`campfarm` 的插入把 `mode_farm_generic.lua` 里 `tbearly` 的站点
从 **493 推到 509**(§BF 里记的 493 从本轮起是旧值)。**行号是会漂的引用,id 不会** ⇒
排波与核对**一律以 `check_armed_wiring.py` 当轮实跑的输出为准,不要引用历史报告里的行号**。

- 上一行的 35 是 2026-08-25T13:xxZ 那一处变动(全文档案 **§BF**):
**积压的六条零成本入集提议一次裁完,全部 APPROVED_ADMITTED** ——
`pulldrag`(GH #117)、`tpgap`(GH #159)、`campsel`(GH #137)、`tbearly`(GH #157/#165)、
`tpdeathbuy`(GH #168)、`zusstatic`(GH #173)。六条各自的条件与预登记读法见 §BF.1,
**其中 `tbearly` 与 `zusstatic` 是条件性的,排波和收割都要照办**。

**⚠️ 发波前必读(cand 串长度)**:35 id 的裸 cand 串**实测 311 字节**(29 id 时 259)。
本轮 `check_armed_wiring.py --cand <35 串>` = **35/35 WIRED,exit 0**(六个新 id 全部 direct、
各 1 站点:`pulldrag` jmz_func:8289 / `tpgap` jmz_func:5963 / `campsel` mode_farm_generic:62 /
`tbearly` mode_farm_generic:493 / `tpdeathbuy` item_purchase_generic:1016 / `zusstatic` hero_zuus:360)。
S3 key 上限 1024,**仍有余量**;但 ext4 的 255 早在 29 id 时就跨过去了(GH #167)⇒
**`<cand>.<ext>` 形状的本地落盘在任何后缀下都必然 `[Errno 36]`**,绕法照旧
(`s3api get-object --key '<长 key>' <短本地路径>`),判据仍是下载后 `ls` 出的文件数
而不是 `--recursive` 的退出码。本轮**没有**让这条变得更坏,只是把余量的数写出来。

- 上一行的 29 是 2026-08-24T22:xxZ 那一处变动(全文档案 **§BC**,来源 GH #159):
  **`tpreach` 入集**(总监自写自批,理由与自我制约见 §BC.3)。门是**它自己那一条**
  (`jmz_func.lua:5878`,`IsModeTurbo` and `tpreach`)⇒ **无合取项、无 §BA.2 冻结风险,
  单独 arm 即有意义**。零 AWS 增量、搭下一波全集的车,**不申请专波**。

### 入集提议档案(最新在上)

**⚠️ 本节的旧标题是「待总监裁定的入集提议」,而 2026-08-25T16:0xZ 起本节里已经
一条待裁的都没有了**(`campfarm` 是最后一条,本轮裁完)。标题照旧写着「待裁定」
⇒ **一个读它的人会以为下面全是待办**。已改名为「档案」,**每条自带裁定行**。
**待裁的真实清单请跑 `python3 tools/agent/pending_rulings.py`**(读 `queue.json` 的
`director` 机器字段),**不要读本节的标题** —— §AW.1/§BA.4 的老病:散文不举手,
而这次散文还举错了手。

- **`campfarm`** —— ✅ **已裁定 2026-08-25T16:0xZ:`APPROVED_ADMITTED`,成员串 35→36
  (见本文件头部与 §BG.3)。** 以下为协同组原提议全文,存档。
  (协同组 2026-08-25T14:xxZ 提议;搭车、零 AWS 增量、不申请专波)。
  GH #137 §3 建议 2 —— 录像组两次(08-24T00:59Z 200 局、15:57Z 全 208 局)点名的
  **第二条通路**,而 `campgrade` **结构上够不到它**:armed 腿 49 次远古阶梯违规里
  **22 次(44.9%)全队从头到尾没有一个人达到该门** ⇒ 那个营**不可能**来自营地名单。
  **缺陷**:`mode_farm_generic` 的三次野怪扫描,两次的门是
  `bot:GetLevel() >= 10 or not nNeutrals[1]:IsAncientCreep()`(**问的是扫描结果的第一只**),
  第三次(1000u 那支)**一句远古子句都没有**;而被打的目标出自 `FindFarmNeutralTarget(整张表)`。
  两个营能同时落进一次扫描(承重帧里 ogre 营与远古营相距 **~590u**)⇒ [1] 是小野 ⇒ 门开
  ⇒ **选中的可以是远古**。对 maxHP 型农夫(viper/naga_siren/huskar、或持
  bfury/大电锤/雷神/辉耀的任何人)这**不是边角而是常规**:远古野怪正是全场血最厚的那只。
  **⭐ 阈值本身也是错位的,而且是三比一**:出厂的远古下界在**三处**都是 **10**
  (两条 `[1]` 子句 + `utils.IsValidCreep` 自带的 `GetBot():GetLevel() > 9`),
  阶梯(`campgrade`)说的是 **12** ⇒ **10..11 就是本 id 的域**:10 以下选择器本来就拒远古,
  12 以上远古本来就该打。这三个数是**从源码断言出来的**(用例 W2/W3),不是散文。
  **修法是过滤名单、不是重问 [1]**:armed 且等级 < `J.Site.ANCIENT_MIN_LEVEL`(=12,
  **与阶梯同一个数、导出一次**,用例断言两处不许漂)时远古野怪不在名单里 ⇒ 两条 `[1]` 子句、
  `#nNeutrals >= 3` 的闩、`UpdateCommonCamp`、目标选择、以及**至今任何等级都无门的
  `Action_AttackUnit(nNeutrals[1])` 兜底**全部一致。**门只解一次**(文件级 `NeutralFarmList`),
  三次扫描全走它 + **调用点计数用例**(不是承诺,是计数)保证将来的新扫描漏不掉门。
  未 armed / 到线 / 无可丢 ⇒ **返回同一张表**(同一性不是等价)。
  **声明的代价写在正面**:扫描里只有远古时 armed 名单为**空**,farm 块随即走它**自己已有的**
  「这里没东西」分支(换营 / 走向营地),不是本修法新造的路径 —— 空名单与那条分支的存在
  **两头都已断言**。
  **本地**:`tests/test_campfarm_ancient_target.lua` **16 例全绿,11 变异 11 抓 + 1 控制**;
  承重帧是**同一个英雄**(viper,正是录像组点名的 maxHP 农夫)的**四个真实等级 9/10/11/12**,
  其中 10 与 12 是**同一局里相隔 26 秒的同一个 viper**。
  **诚实边界**:野怪那一半**语料里没有**(W1:`GetNearbyCreeps()` 在每枚 fixture 上答 `{}`,
  且零枚 fixture 带 creeps 键)⇒ 野怪是**声明的替身**,只带出厂选择器实际读的那几个字段;
  **没有假装端到端**。域:104 枚 fixture / 1040 个真实英雄槽,**140 个(13.5%)落在 10..11 带**,
  **82 个 ≥12**(后者是反向护栏要保护的人口),两个都是下界。
  ⚠️ **排波(与 `campsel` 那条同型、方向相反)**:`campgrade` **不在**当前 35 串
  ⇒ 界后第一波就能干净读到;哪天 `campgrade` 入集,它在**上游**把远古营从名单里删掉,
  **同 arm 的腿读不到本 id 的域**(本 id 管的是「已经站在营边上」那一段)⇒ 要读本 id
  请排 `campgrade` **未 armed** 的腿。**这条请写进 `campgrade` 未来入集裁定的前置检查**,
  与 08-25T13:xxZ 给 `campsel` 写的那条并列。
  详见 `state.json:campfarm_20260825`;批测请求 `queue.json:strategy-17`。

**上面一条之前本区为空(2026-08-25T13:xxZ 清空)。** 下面两条已于 13:xxZ 裁定,留档见 §BF.1。

- **`pulldrag`(协同组 2026-08-25T07:5xZ 提议;搭车、零 AWS 增量、不申请专波)。
  ✅ 2026-08-25T13:xxZ APPROVED_ADMITTED,§BF.1(一)。**
  **附带一件必须先读的事:你 07:xxZ 裁定交办的那个动作(把 `PULL_CAMP_LANE_GAP`
  1200 收到 p90 992 / 中位 742)——按你自己写的「收紧前必须先跑几何核验」跑完了,
  结论是 REFUSE,`PULL_CAMP_LANE_GAP` 一字未动。** 判据是**序**、不是标定值:
  仍在开火的四个营里,产出全部 connect 的那两个是**垂距最宽的两个**(1220 / 1084),
  从未产出 connect 的两个是**最窄的两个**(1069 / 1019)。距离阈值**从宽端删**
  ⇒ **任何会改变行为的收紧都先把分子整个删掉**,留下的恰是不产出的那两个。
  而且它**不会读成 SILENT**(poke episode 照常、connect 恒 0),比 SILENT 更难发现。
  几何用**语料自己的地图**算:61 枚带 buildings 的 fixture 对 **22 座塔**坐标逐个一致
  ⇒ 地图是实测常数;**边缘对照**是 W7→W8 的实际划分,单一阈值复现成功
  (仍开火最宽 **1220** < 归零最近 **1282**),拐角敏感性用 corner-restored 折线复核过
  (该行只动 1u,且序在两模型下一致)。工具 `tools/agent/pullcamp_lane_geometry.py`,
  棘轮 `tests/test_pullcamp_lane_geometry.py`(**已进 `run_py_tests.sh` ⇒ 已进每轮自检**,
  谁再去收紧那个常数,红的是这条,并指着这段裁决)。
  **本 id 是那次 REFUSE 之后的落点(裁定说「binding constraint 是拖拽不是筛子」,
  这就是拖拽那一格)**:drag 那 500u 的**方向**从泉水改成**本 bot 被分配 lane
  路径上离该营最近的一点**。源码注释本来就写着 “so the camp follows into the lane
  path”,而向量取的是泉水 —— 在引擎实际会拉的四个营上,朝家走每 500u 只关掉
  **67 / 67 / 94 / 89 u** 的垂距(**81-87% 的位移平行于兵线**),朝线走关掉整 500u;
  配上 leash 中位 742u,回家式拖拽在脱缰前只关掉 ~100-140u 的 ~1,100u 缺口。
  **这就是两波两层 connect 绝对数恒为 2 的算术原因。**
  **门是独立的一条**(turbo + `pulldrag`,**不与 `pullcamp` 合取** —— 踩 `pullcad`
  那条「promote 冻死点名它的门」的风险为零);未 armed ⇒ 返回 nil ⇒ 出厂回家式行走
  **逐字节不变**(含「未 armed 连 21 次引擎调用都不许花」的用例)。
  ⚠️ **但排波仍需 `pullcamp` 与 `pulllane` 同时 armed**:本代码只经
  `J.ShouldPullNeutralCamp` 到达,那两个是**结构性前置**,不是本 id 的门。
  本地:`tests/test_pulldrag_lane_step.lua` **13 例全绿,11 变异 11 抓 + 1 控制**;
  真实帧两侧,radiant 那枚**只断言不等式**(它落在拐角敏感区,在拐角上断言量级
  就是在断言拐角)。**反向哨兵**:own-side 子句买到的两波一致安全收益
  (20s 内死亡 2/97→0/146、翻面拉 7.2%→0.0%)**不许回吐**。详见
  `state.json:pulldrag_20260825`;批测请求 `queue.json:strategy-16`。

- **`tpdeathbuy`(协同组 2026-08-25T02:xxZ 提议;搭车、零 AWS 增量、不申请专波)。
  ✅ 2026-08-25T13:xxZ APPROVED_ADMITTED,§BF.1(五)。**
  `item_purchase_generic` 的「死前如果会损失金钱则购买额外TP」块,HP 子句是
  `botHP < 0.08 and botHP >= 1`,而 `botHP` 是 `J.GetHP` 的 **0..1 分数** ⇒ 合取
  **不可满足**,约 12 行**死代码**;这一对逐字来自初始 OHA 快照(`74727e4a:957-958`),
  **在本仓库历史上一次都没跑过**。armed(turbo + `tpdeathbuy`)去掉那条杂散下界。
  **门无合取依赖 ⇒ 单独 arm 即有意义**(不踩 `pullcad` 那条「promote 冻死点名它的门」)。
  ⚠️ **方向与本组以往每一条相反:这是加宽不是收窄** —— armed 是空集的真超集,
  **严格增加**出厂树从不发生的采购。⇒ 反向哨兵不是「TP 采购不许塌」而是
  「**TP 花费不许暴涨**」;并且**一份「无变化」读数不能验证本 id**(无变化 = 没 armed 或域为零)。
  本地:`tests/test_tpdeathbuy_dead_conjunct.lua` 8 例全绿、11 变异 10 抓 + 1 控制;
  帧域 966 帧里可读的那一半 = **4 帧**(点名钉住);两条金钱腿在 fixture 上是
  **带错符号的恒真**(`GetGold`/`GetItemCost` 皆读 0),已按 0DIR 两向断言,
  **故本轮不主张端到端钉帧**。详见 `state.json:tpdeathbuy_20260825`。

**下面是 2026-08-24T19:xxZ 那一行的两处变动(全文档案 §BB,裁定 GH #164):**

- **`pulllane` 入集**(协同组 02:0xZ 提议,零 AWS 搭车)。**⚠️ arm 串约束成立且必须照办**:
  门是 `pullcamp` **and** `pulllane` 的合取(外层 `J.ShouldPullNeutralCamp` 在
  `jmz_func.lua:8032` 早退于 `pullcamp`,新子句在 `8154` 门于 `pulllane`)。
  **两者都在成员串里 ⇒ 全集波自动同时 arm**;发隔离波时**必须两个一起写进 armed 串**,
  漏一个 = 逐字节 no-op 且**没有任何计数会报警**(§BA.2 那个形状)。
- **`towerfear` 入集**(协同组 14:0xZ 提议,零 AWS 搭车)。门是**它自己那一条**
  (`mode_retreat_generic.lua:907`,`towerfear` and `IsModeTurbo`)⇒ **无合取风险,单独 arm 即有意义**。
- 以下为 2026-08-23T23:xxZ 那一行的三处变动,留档(**§BA**):
- **`creeppull` + `pullbeat` PROMOTED,出集** —— 不是退回也不是 reject,是**毕业**。
  owner 铁律 2 的三条件在这一对上首次同时齐备,gate 已从源码移除,turbo 默认开。
  **promote 的单位是这一对,不是 `creeppull` 单独**(理由见 §BA.1)。
- **`pullcad` 入集**(协同组 21:5xZ 提议,零 AWS 搭车)。**⚠️ 它的 arm 串约束已作废**:
  原门 `pullcad and pullbeat` 的第二个合取项本轮被 promote ⇒ 合取会被永久冻结为 FALSE,
  已在同一次改动里拆掉(§BA.2)。**发波时 armed 串就是 `pullcad` 一个 id。**
- 以下为 2026-08-23T15:xxZ 那一行的两处变动,留档:
- **`itemtrip` 出集 —— 退回协同组**(§AW.2:归因波 X = gpm −26.44 触发 §AT.1 预登记第一档)。
  **退回≠reject**:它的条件 (a) 是 WORKING(录像组 13:01Z),被否的是这个杠杆值不值得拉。
  gate 与代码留在树上、**永不 arm**,直到协同组带着新的域回来重新申请入集。
- **`pullbeat` 留在集合里**:§AV.7 写的入集条件是「与 W3 发波同生共死 —— 归因波若没能成功
  收割就退回」,**归因波已于 14:10Z 成功收割**(275 有效局,unfinished 0)⇒ 条件已满足。

(26 + `pulllane` + `towerfear` = **28**,+ `tpreach` = **29**。
上一行的 26 = 27 − `creeppull` − `pullbeat` + `pullcad`。
可 arm 串见各 §x.0,与成员串**不是一回事**。)

---

## 裁定档案在别处(owner P4.3,2026-09-06)

**`§BI` 及其之前的全部历史裁定节 → `iterations/archive/test_set_archive.md`。**
本文件拆分前 **1.47 MB / 19436 行**,拆完 **46 KB / 300 行**;移走的 **1.42 MB**
一个字节没改(`head -298` + `sed -n '299,$p'`,两半相加逐字节等于原文件)。

**引用不变:节号照旧挂在 `test_set.md` 这个名字下。** `§XX` 的命名空间是名字不是文件 ——
`citation_audit.py` 的 `SECTION_FALLBACKS` 在 `test_set.md` **∪** 档案上解析,
AMBIGUOUS 也在并集上判。拆分当天实测:251 条不同引用,168 OK / 82 MISSING / 1 AMBIGUOUS,
**拆分前后逐条相同**(那 82 条是**拆分之前就欠着的**:多数是散文里写了 `§XX.N`
而那一级从来没有过标题行,与本次拆分无关,也不是本次要修的)。

⚠️ **改动这条边界之前先读两个读者**:`citation_audit.resolve_section`
(`SECTION_FALLBACKS`)与 `pending_rulings.read_test_set`(23 个提议节**全部**在档案里,
只拆文件不拆读者会让它的提议腿因输入消失而变绿)。两条都钉在
`tests/test_citation_audit.py` 与 `tests/test_pending_rulings.py` 里。

**本文件今后只留三样**:【当前 armed 串】【下一波指令 / 收割前必读】【未决裁定索引】。
新裁定照旧写进本文件;长起来之后由总监按同一边界**追加**进档案,**不插入**。

## §FM 2026-09-06T16:53Z 协同组 —— **药膏那条能给自己喝,影之灵龛那条不能;而它们在同一张表里,治的是同一个 400 血**;本节最该被读的是 **§FM.3:锚检查这一轮抓到三样会让 `CAUGHT`/`SURVIVED` 撒谎的东西 —— 一个不存在的针、一个不唯一的针(GH #550 活体复现)、一个被 `$(...)` 剥掉换行而静默压成一行的针**

**认领**:工作流第 1 步扫 `[strategy]` open issue,`#568`/`#558` 均为本组已交付
或已认领的存量,更早六条为存量或无帧证据 ⇒ **无未认领的带帧证据条目**,按铁律 9
取 owner 优先项 **P4.4(i) + P2(决策侧)**。
**armed 串一字未动、`queue.json` 一字未动**(P4.2 入集冻结)。零 AWS、零波次。

### §FM.1 章程点名的那一格,普查把它答完了 —— 答案是「问得太窄」

章程 `0STAYTOWER` 的下一格是「`J.ShouldStayAndRegen` 的 supply 读数与 docstring
的第三处分歧,先跑普查问**还剩哪半没修**,答案若是『没有了』就判到此为止」。

把那条 **PROMOTED** 函数的四条 supply 杠杆(`staysrc`+`staybottle`+`staybag`+
`bagsalve`)**同时 armed**,沿它自己的前缀走 1012 个活体帧:

```
live 1012 → 带内 305 → 过追击子句 256 → 过 1200 环 125 = 到达 supply 子句 125
            出厂放行 13        四杠杆全 armed 放行 60        ⇒ 仍被否决 65
```

逐件数那 65 帧手里的东西:**49 帧真的什么都没有**(正确否决,归 `fieldbuy` 一族)、
**约 9 帧背包 tango/faerie_fire**(`bagsalve` 早已裁过:没有 shipped swapper ⇒ 不数)、
**6 帧空瓶**(正确)、**8 帧带影之灵龛** —— 这一族的回复词表
(flask/tango/tango_single/faerie_fire/bottle)**里从来没有过它**,而其中 **2 帧
`modifier_item_urn_heal` 是活的**:它们**正在被灵龛治疗**,整条 supply 链读它们
「两手空空」。

⇒ **那一格的答案不是「没有了」,是「问的范围太窄」**:漏的不是 docstring 那句话的
第四半,**是词表本身少一味药**。

### §FM.2 ⭐ 主判据:域价钱答完一格之后,**下一个候选也要先付价钱,而它否掉了最直接的那条**

最直接的动作是「把灵龛加进 `J.HasFieldRegenSource`」。**不做,而理由是这个家族
自己写下的**:`bagsalve` 只宽一件物品的原话是「**没有 shipped 的 swapper ⇒ 数它
就是把 bot 按在一个它永远不会喝的东西旁边**」。

灵龛有没有「按下去」的路?**没有。**
`X.ConsiderItemDesire["item_urn_of_shadows"]` 的病人循环是
`J.GetNearbyHeroes(bot, ...)` → `bot:GetNearbyHeroes(...)`,**引擎这个调用不返回
调用者自己** ⇒ **残血、安全、手持满充能灵龛的 bot,在任何血量下永远不会按它。**

**落地的杠杆来自同一张表的兄弟条目**:

| | `X.ConsiderItemDesire["item_flask"]` | `X.ConsiderItemDesire["item_urn_of_shadows"]` |
|---|---|---|
| 治疗量 / 可自施 | 400 血 13s / 是 | **400 血 8s / 是** |
| **self 分支** | **有**(`hEffectTarget = bot`) | **无** |
| 自己 vs 队友的仲裁 | **三个 id**(`salveyield`/`salvepool`/`salveally`) | —— |

**`urnself`**:在 ally 分支的 `return` **之后**追加 self 分支,**每一条合取项都是
上面那个 ally 循环的原话**(800 / 3.1 / 三个治疗 modifier / 450 / 空
`hNearbyEnemyHeroList` / 非魔免可施),外加**显式** `J.IsModeTurbo()`
(此路径上没有任何一处在它之上问过 turbo —— 写「结构性」会是假话)。

**「只在没有队友够格时才开火」是控制流,不是合取项**:ally 分支自己 `return`。
**自己与队友都够格时的仲裁,本轮不答也不借** —— 语料里那 2 帧**故意留给队友**。

**方向由构造固定**:追加在会 `return` 的分支后 ⇒ arming **只能**把 `DESIRE_NONE`
变成一次施法,**不压制任何 bid**。

**域价钱与读数(两条独立路线互相钉死)**:带灵龛 81 帧 → 瓶颈是**缺血 >450 的 17**
(不是危险子句:泉水 79 / 未被打 71 / 无治疗 modifier 79 / 可施 81 / 1000 内无敌 53)
⇒ **自己够格 6**(无队友竞争 **4** + 有队友竞争 2),**6/6 全在 0.18–0.75 带内**。
驱动读数(跑出厂 `_G.ItemUsageThink`,读引擎 action):
**c0 出厂 0 / armed 0;c1 出厂 3(ally,控制组)/ armed 7** ⇒ **gain 4、loss 0**,
且 **`gain`(驱动) == `domain_selfonly`(镜像) == 4 逐位相等**。
钉帧 `f_260822_123136_lina_shoptp_434` 的 **jakiro(48.0%、缺 612)**,
**同时属于 gain 那 4 帧与 supply 仍否决的那 65 帧** —— 只在前一个集合里的帧只能
证明杠杆开了火,证明不了有人该在乎;**第一版钉的就是那种帧,并被这条断言当场打红**。

### §FM.3 ⭐⭐ 立法级(变异台/量具):三样会让 `CAUGHT`/`SURVIVED` 撒谎的针,三样都是锚检查抓的

变异台**第一次跑 STAND RED,3 个 unexpected,而两个是锚不是杠杆**:

1. **不存在的针**:M3 写成 `return BOT_ACTION_DESIRE_HIGH, hEffectTarget, sCastMotive`
   —— 真实那行还有 `sCastType`。锚打 `occurs 0`。
2. ⛔ **不唯一的针 = GH #550 的活体复现**:
   `and npcAlly:OriginalGetMaxHealth() - npcAlly:OriginalGetHealth() > 450`
   在本文件**出现两次**(药膏那条的 ally 循环逐字相同),`perl s///` 不带 `/g`
   ⇒ **改的是药膏、灵龛的 450 原封不动** ⇒ 测试照样绿 ⇒ **SURVIVED**。
   **没有 `ANCHOR ... occurs 2 time(s)` 那一行,这次 SURVIVED 会被读成「套件有个
   洞」,然后有人去修一个不存在的洞。**
3. ⭐ **被 shell 语义压扁的针(本节最该被抄走的一条)**:修 (2) 时把针写成
   `"...450$(printf '\n')...== 0 $(printf '\n')"`,**锚检查回来是 0**。
   原因:**bash 的命令替换 `$(...)` 会剥掉结尾的换行**,两个 `$(printf '\n')`
   **都展开成空串**,针被**静默压成一行**、匹配不到任何东西 —— **而它长得像一个
   写好了的多行针**。正确写法是 ANSI-C 引用 **`$'\n'`**。
   附:灵龛那份针的第二行**带一个行尾空格**、药膏那份没有 —— **一个肉眼完全看不见
   的差别在承重**,这正是「**数**锚」而不是「**看**锚」的理由。

### §FM.4 ⭐⭐⭐ 一个注释可以移动结构切分的边界

`_urnself_sweep.lua` 第一次跑,**每一个结构事实都读作「这个杠杆不存在」**:
`URN_NIDS 0`、`SELF_ASSIGNS_BOT 0`、`SELF_AFTER_ALLY_RETURN 0` —— **逐字就是杠杆
从未写过的那份读数**。原因:切块沿用兄弟 sweep 的
`src:find('X.ConsiderItemDesire[', at+10, true)`,而**本杠杆自己的注释里就有
`X.ConsiderItemDesire["item_flask"]`**(它是条件 (c) 的论据)⇒ **切块在自己的注释
处被切断**。改成**行首锚定** `'\nX.ConsiderItemDesire['`(条目在第 0 列,注释不在),
做成 **M15,CAUGHT**。
同族一条:探针里 `find('hEffectTarget = bot', 1, true)` 会命中十二行外
`hEffectTarget = botTarget` 的**前缀** ⇒ 侦察探针对**未打补丁的文件**报了
`SELF_MENTION=1`。**针必须自带终结符。**

### §FM.5 诚实边界与交棒

- 本条目**自己的第一行**是 `GetCurrentCharges() == 0 → DESIRE_NONE`,而**充能不进
  `.dem`** ⇒ 经 mock 每一列都是 0。语料因此**跑两遍(c0/c1)、两列都断言**,
  c0 的 0 **永远不能被读成「杠杆没用」**。同时给灵龛句柄补了
  `IsTrained/IsActivated/IsFullyCastable`(GH #89,与 `_itemdesire_sweep.lua`
  给 TP 卷轴补的是同一个探针),**其余每一条合取项都留给出厂代码**。
- 本轮**明确拒绝回答**「灵龛该不该进 `J.HasFieldRegenSource` 的词表」——
  拒绝的理由(没有可用的施法路径)**正是本轮消掉的**,所以它是**下一格的候选**,
  不是本轮的结论。
- **交棒(总线 GH #572)**:甲 → 总监(登记,本轮**不提入集**,冻结期合法裁定
  = FROZEN-HOLD;附规程建议一条,见 §FM.3(3));乙 → 批测台(解冻后**单臂可读**,
  与四条 supply 杠杆重叠**按构造 0**;⚠️ 充能列不可读);丙 → 录像组(核验形状 =
  真实 Turbo 局里「持灵龛、安全、缺血 >450、1000 内无敌人」的时刻,armed 腿应出现
  **对自己**的灵龛施法,**baseline 腿按构造 0 次**)。

---

## §FN 2026-09-06T19:46Z 协同组 —— **这一族的供给读数全是 SLOT 读数,而这一味药是从别人的背包里打过来的**;本节最该被读的是 **§FN.4:一个 presence flag 不能承载一个 COUNT 形状的论据 —— 删掉五处里的一处,它还是绿的**

**认领**:工作流第 1 步扫 `[strategy]` open issue —— `#572`/`#568`(本组前两轮
已交付、等总监裁)、`#558`(上一轮已认领并交回),更早的
`#385/#300/#254/#201/#198/#26` 为存量或无帧证据 ⇒ **无未认领的带帧证据条目**,
按铁律 9 取 owner 优先项 **P4.4(i) + P2(决策侧,球在本组)**。
**armed 串一字未动、`queue.json` 一字未动**(P4.2 入集冻结)。零 AWS、零波次。

### §FN.1 章程点名的下一格:域价钱**判它到此为止**,而否掉它的不是大小是形状

章程 `0URNSELF` 的下一格逐字是「`urnself` 打开之后,灵龛才有资格被问要不要进
`J.HasFieldRegenSource` 的词表 —— **先跑域价钱**,那 65 帧里带灵龛的 8 帧,有几帧
同时满足 `urnself` 的域?**答案很小就把这条路判到此为止**」。

跑了(同一份前缀,读数与上一轮**逐位相同**:1012 → 305 → 256 → 125,armed 放行 60
⇒ 仍被否决 65,其中带灵龛 8):

| 那 8 帧 | 帧数 |
|---|---|
| 满足 `urnself` 全部合取项 | **4** |
| 其中**无队友竞争** | **2** |
| 缺血 ≤ 450 挡下 | 2 |
| 泉水 800 内挡下 | 1 |
| 已挂治疗 modifier 挡下 | 1 |

**4 不是零。这条路仍然判到此为止,而理由不是大小、是形状**:把灵龛记成 field
regen source,**只有在 bot 真会按它时才诚实**,而那需要 `urnself` 在**另一个站点**
armed —— **GH #542 的形状**(每个站点各写一个 id,所有检查都读作干净,而**任何单臂
波都买不到那个行为**)。**登记为一条被定价后拒绝的路,而不是一条没想到的路。**

### §FN.2 ⭐ 主判据:同一批帧,换一个问法 —— 不是「它手里有没有药」,是「药是不是已经在路上」

`modifier_item_urn_heal` **活着**的帧**不需要任何施法路径**:按钮已经被**别人**
按下,400 血正在到账。**这正是 `staybottle` 立论的那句话**(「已经**付过钱**、正在
到达」),而它**对灵龛这味药从来没有被说过**。

**树里另外三处早就这么读了**(全部**从活文件解析**,不是本注释的记忆):

| 站点 | 它对 `modifier_item_urn_heal` 的态度 |
|---|---|
| `ability_item_usage_generic` 的 tpscroll `'撤退:3'`(~5663)及同族**共 5 处** | 挂着就**拒绝回城 TP** |
| `mode_roam_generic` 的 `ShouldWaitInBaseToHeal`(~1599) | 挂着就**不算需要回基地** |
| `FunLib/aba_buff.lua` 的 `hero_is_healing` | **五味药的词表**,它是其中一味 |

而 **PROMOTED 的 `J.ShouldStayAndRegen` 认得其中两味**(`flask_healing` /
`tango_heal`),armed `staybottle` 之后三味,**灵龛这味一次都没有**。

**`stayurn`**:在 `staybag` 块**之后**、`GetGold` 兜底**之前**追加
`if not bHasRegen and J.IsSoakCandidate( 'stayurn' ) then bHasRegen = bot:HasModifier( 'modifier_item_urn_heal' ) end`。
追加而非插入 ⇒ 未 armed 时**三个兄弟杠杆逐字节同构**;排在 `GetGold` 之前 ⇒
它要移除的那个否决**还没有 `return`**。Turbo **结构性**(函数第一行已经问过),
**STANDALONE**(一条件一 id)。

### §FN.3 ⭐⭐ 这是这一族里第一个 **SLOT 读数按定义够不到**的杠杆

出厂 `bHasFlask` 读 `J.IsItemAvailable`(**槽 0-5**)、`staysrc` 读
`J.HasFieldRegenSource`(**`for i = 0, 5`**)、`staybag`/`bagsalve` 把同一个问题
扩到**背包** —— **四条全是 slot 读数**。灵龛的治疗**由队友施放**,物品和病人
**在两个背包里**。

**读数不是修辞**:域内 **2** 帧,其中 **1** 帧
(`f_260820_163429_es_blink_init_621` 的 **jakiro,61.8% 血、缺血 626**)
**九个格子里既没有灵龛也没有魂之灵瓮** —— **无论把 slot 读数扩到多宽都够不到它**
(`flip_no_urn_item == 1`)。另一帧(`f_212636_tide_ancient` 的 zuus,65.8%、缺 463)
**自己带着灵龛**,是**反向控制组**:两半各一帧,杠杆才不是「slot 读数的别名」。

**bid 层比兄弟强的地方是符号不是大小**:`staybottle` 只能在一个出厂 bid 已经
**为负**(−0.4721)的帧上证明守卫开火;这里钉帧 jakiro 的出厂
`mode_retreat_generic.GetDesire` = **+0.20598228813998432**(**正的 —— 它真的在
要求撤退**),armed 后 = **0**(守卫提前 `return`)⇒ **被取消的是一次真实的回程 bid**。

**域价钱与两条独立路线**:carrier **4**(**0 出带**、0 被追击子句挡、**1** 被未触碰
的 1200 环挡、**1** 出厂 supply 本来就放行 —— 它带着药膏)⇒ **域 2**;驱动
`ship_true 13 → arm_true 15`、`flips 2`,且 **`flips` == `blocked_with_mod`(前缀走桶)
== 2 逐位相等**。与兄弟**不相交是读数不是宣称**:`flips_staysrc 44`、
`flips_both_levers 0`,钉帧上单 arm `'staysrc'` 也不动它 ⇒ **单臂波可读**。

### §FN.4 ⭐⭐⭐ 立法级(量具):**presence flag 不能承载一个 COUNT 形状的论据**

变异台 **M6** 要删掉 tpscroll `'撤退:3'` 那条灵龛否决。第一版声明 `anchor 1`,
**锚检查回答 `occurs 5 time(s)`**:item 层在**五处**拒绝
(5585 / 5619 / **5663 = `'撤退:3'`** / 5977 / 6230,其中 **5663 与 5977 连续五行
逐字相同**),`perl s///` 不带 `/g` ⇒ **删掉的是第一处**,`'撤退:3'` 那份**原封不动**,
sweep 的 presence flag **照样读 1** ⇒ **SURVIVED**。

**两件事同时错,而只有一件是变异体**:针不唯一,**并且**它攻击的那个事实是个
**存在标志**,而论据是个**计数**。两处都改:sweep 现在**数站点**
(`ITEM_URN_MOD_SITES == 5`),于是**删掉五处中的任何一处都 5→4**,变异体
**不再取决于 `perl` 先够到谁**。

⇒ **可复用**:凡是「树里另外几处已经这么写了」型的条件 (c) 论据,**量具必须数站点,
不能打存在标志** —— presence flag 在**删掉五分之一**的时候是**绿的**。

同轮第二处(同族):sweep 里 `return armed and sId == 'stayurn'` **出现两次**
(装一次、跑完 `staysrc` 对照后**再装回**一次),**M9/M10 一直在改一个它们的标签
没有点名的位置并打印 `CAUGHT`** —— **锚检查是唯一说出这件事的东西**。

### §FN.5 ⭐⭐⭐⭐ 恒零的断言先证明它数得动(承 `staytower` 的 M14)

`flip_true_to_false` 必须为 0。做法沿用上一轮的构造:两个方向合进同一个
`tally(a, b, sDown, sUp)`,**再调用一次把两腿对调** —— 于是「必须为 0」的那条分支
**正是对调那次必须报出整个域的分支**:`flip_true_to_false_swapped = 2 = flips`,
`flips_swapped = 0`。**M11 删真调用、M11b 删对调调用,两发都 CAUGHT。**

而 **M3(去掉 `not bHasRegen` 守卫)是本杠杆唯一能让 bot 更常回家的改法** ——
赋值变成**覆写**,没有 modifier 的帧上把兄弟算出的 TRUE 抹成 false。它**通过一切
看域的计数**,**只有 `flip_true_to_false` 挡着**。这就是恒零计数器承的重。

### §FN.6 诚实边界与交棒

- **域是 2 帧**,是测量不是道歉;每个 carrier **一行 B 记录并自带停在哪一条子句**
  (band / chase / ring / shipped_ok / domain),五个桶**相加 == `mod_carriers`**
  (数出来的,不是减出来的)⇒「语料里没有灵龛治疗」与「有但被前面三条子句挡掉」
  **永远不是同一份读数**(M14 把 carrier 普查改读魂之灵瓮 modifier ⇒ B 行全消失,CAUGHT)。
- **魂之灵瓮的 `modifier_item_spirit_vessel_heal` 故意不加**:1012 帧里 **0 次**携带,
  加它就是**未定价的加宽**。由 `STAY_READS_VESSEL == 0` 与 `vessel_carriers == 0`
  各钉一次,**它是下一个问题不是本轮的结论**。
- **金钱贫穷超集**:gold 不进 `.dem`(GH #495),`gold_nonzero == 0` 断言这一点,
  **方向固定、大小不作声明**。
- **一帧是一个瞬间,治疗有尾巴**:本条只说 t 时刻的决策错了 —— 剩下那一口够不够
  留下是 `fieldsip` 在 gated 那一族的问题;灵龛的 **400 血是这套词表里单次量最大的
  一味**,所以它是**最不暴露于这一条**的成员。
- **副产物(GH #546 的活体复现)**:一次性 Lua stand 用 `print` 打读数,**mock 的
  `install()` 把 `print` 换成空函数** ⇒ **stdout 全空 + 退出码 0**,长得像
  「跑了没发现」;改用 `io.stderr:write` 才拿到 zuus 那一行的 bid 读数。
- **交棒(总线 GH #575)**:甲 → 总监(登记,本轮**不提入集**,冻结期合法裁定
  = FROZEN-HOLD;附规程建议一条,见 §FN.4);乙 → 批测台(解冻后**单臂可读**,
  `flips_both_levers = 0` 是**读数**不是宣称;⚠️ 域小 2/1012,取证波按**稀有事件**排,
  不要按单波显著性读);丙 → 录像组(核验形状 = 真实 Turbo 局里「身上挂
  `modifier_item_urn_heal`、血量 18%–75%、1200 内无敌方英雄、3 秒内未被英雄打」的
  时刻,armed 腿**留在原地喝完**、baseline 腿走人或 TP;⚠️ **病人未必是灵龛的携带者**
  —— 语料里两帧就有一帧不是)。

---

## §FO 2026-09-06T22:xxZ 总监:**第四、五次 promote(`odbuild` + `illumove`)+ `towerfear` 退回出集**,armed 55 → 52

**产出指标(owner P4.2):判定完结 3**(两条 promote + 一条退集,零入集)。上一轮 0、上上轮 0 ——
交棒清单上「九个 WORKING 里剩下的八条逐条判」**连续两轮被 trunk 红挤掉**,本轮先做它。

⭐ **两条 promote 的 (b) 是同一份读数,而它是 W47–W50 的家族级读数,不是 W51**:两个 id 在
W47/W48/W49/W50(62/63/61/59-id 家族,**701 局计分**)**每一条腿上都 armed**
(那四波的移除项是 `stayattr`/`tpdying`/`tpreach`/`slotwait`,从来不是这两个),
家族 gpm swap-average `−5.95 / +27.25 / +11.70 / +13.76`,deaths `+0.25 / +0.06 / +0.02 / +0.07`
——**本轮逐波从各自 `W*_wave.json:harvest.mean` 裸读,不是抄散文**。
⛔ **本节第一稿引的是 W51 的 `gpm −2.19`,那是错的,登记而不是删掉**:W51 是
`campgrade` **独占波**(`arm_string` 就一个 id、`arm_bytes` 9),**这两个 id 在它上面根本没 armed**。
错法值得记:`arm_ids`/`arm_md5` 这些字段在每个波次记录里都长得一样,**只有把 `arm_string` 打开看
才分得出「55-id 家族的那一波」和「一个 id 的独占波」** —— 而收割报告里那行 2(b) 措辞
(「远在噪声底之内」)对两者读起来完全一致。
**诚实边界逐字抄进了两处源码注释**:那是**家族级**读数,不是 id 级;全开波不可能把经济归给
某一个成员,而 winrate 通道自 GH #352 起 DEGENERATE,**一个可引的胜负数都没有**。
铁律 2(b) 要的是「粗粒度的没有明显负面」——**四波、id 每波都在、均值 +11.7 gpm,就是它,仅此而已**。

### §FO.1 `odbuild` PROMOTE(55 → 54)

- **(a) WORKING**,`VERIFY id=odbuild verdict=WORKING episodes=7`(录像组 2026-08-30T10:01Z,W28):
  带波次戳的 7 个 OD 英雄-局里,armed 三局 objurgation **rank 4/4/4**、baseline 四局 **0/0/0/0**;
  三个 warmup 局无戳,**按 LIMIT 3 不计入**。
  ⚠️ **登记的仪器边界,不抹平**:英雄组 08-29 在 W25(另一棵树、44-id 串)读到 1 例
  `ROW_CONTRADICTS_STAMP`,W28 上 **0/3 未复现** ⇒ 戳与实际行**可能**脱钩、频率未知。
  它限制的是这份读数的**精度**,不是**方向**。
- **(b)** 见上(家族级 W51)。
- **(c) 是算术,不是判断题**:那一行 15 个条目、花 4+4+4+3;OD 恰有三个可学基础技能(各四级)
  加一个三级大招 ⇒ 那个 4× 块只能是基础技能,而出厂行**从不点名的**基础技能正是 index 3。
  index 4 是 `generic_hidden` 占位符(`tests/test_build_index_resolution.lua` 在 2/2 drop-world 里实测)。
  **代价已量**:出厂腿 OD 在英雄 7 级卡死,15 个技能点只花掉 6、天赋 0,4/4 baseline 腿如此(GH #330)。
  「让英雄按一个点名真技能而不是占位符的表加点」不需要任何战术论证。
- ⚠️ **随 promote 一起登记的残留**:armed 腿仍然丢天赋点(冻结 5–24%,GH #330)。
  那是**第二个缺陷**(在天赋侧的花点器里),`odbuild` 不碰它,本次 promote **也不声称**修了它;
  `tests/test_od_levelup_double_spend.lua` 第 7 节继续替它举手。
- **载体项不变,是量出来的**:`obsidian_destroyer` 由**仍在集**的 `odaoe` 承载 ⇒
  `TERMS` 行逐字节不变(8 项),`carrier_terms.py` 计数 12 hero → **11 hero**、43 → **42 generic**、
  **0 unresolved**。批测台排波不受影响。

### §FO.2 `illumove` PROMOTE(54 → 53)

- **(a) WORKING,三份互相独立的语料,方向每次相同,而且仪器在树上**
  (`tools/batch_test/behavioral/illumove_pairs.py`,`--selfcheck` 9/9):
  W35 `episodes=15`(出厂腿上两个幻象**轮流**独占那一个 module 时钟,最长一次连续 **15 秒**只有一个在走)、
  W36 `episodes=305`(`starved%` armed 11.9/8.7 vs baseline 20.5/30.2,**两个分层同号**)、
  W37 `episodes=180`(四格同号,读数跟着 arm 腿走)。
  **归因边界是算出来的不是假设的**:`illureal` 是同文件 `X.Think` 路径上唯一的另一个 id,
  它 armed 会**缩小** `illumove` 的域 ⇒ W35 的交集**逐帧算过,上界 0(空)**,
  所以那份读数可以干净地归给这一条。
- **(b)** 见上(家族级 W51)。
- **(c) 是作用域,不是调参**:`nNextMoveTime` 是**模块局部**,而
  `bots/FunLib/aba_minion.lua:11` 只 dofile 这个模块一次、把**每一个**幻象与无技能小兵都派进同一个
  `X.Think`(:52)⇒ 一帧里第一个走到移动分支的单位把时钟推到 0.2 秒之后,**同帧的兄弟单位
  一条命令都拿不到**——不是延后,是没有。**正确形状本仓库自己就有,在上一层**:
  `aba_minion.lua:33-35` 用**每单位字段**(`lastItemFrameProcessTime`)节流同一批单位。
- **下游钉子同轮翻面**(promote 的隐性成本):
  `tests/test_illumove_shared_throttle.lua` 的结构断言从「必须有这个门」翻成「**一个门都不许剩**」,
  两个世界改由 `IsModeTurbo()` 切换(`IsSoakCandidate` 对所有 id 恒 false ⇒ 同文件的 `illureal`
  在两个世界里都关着,**开关只动时钟这一件事**);`tests/test_carrier_terms.py` 与
  `tools/agent/mutstand_carrier_minion.sh` 的探针把 `illumove` 换成仍然 gated 的 `illureal`
  ——**同一条 illusions.lua 路径继续被探到**,断言没有随 promote 一起被删掉。

### §FO.3 两条都查过 `pullcad` 陷阱,而其中一条**让我改了另一条的排队**

- `odbuild`:全仓 gate 字面量唯一(`hero_obsidian_destroyer.lua`),不与任何 id 合取,不属任何共同 promote 原子。
- `illumove`:gate 字面量唯一(`minion_lib/illusions.lua`),`illureal` 是**同文件的另一个独立 gate**,
  不是合取项 ⇒ promote 后 `illureal` 的门**一字未动**,仍可单独 arm。
- ⭐ **`towerfear` 另有一条构造性的陷阱,与它退集分开成立,所以单独登记**:它的门是
  `bots/mode_retreat_generic.lua:964` 的**析取** `IsSoakCandidate('towerfear') or IsSoakCandidate('towerring')`。
  删掉那句门 ⇒ 整条分支变成 turbo 默认开 ⇒ **`towerring`(GH #558,同块 :969 还有它自己的第二处)
  的 arm 从此测不到任何东西**,而 `check_armed_wiring.py` 照样把它读作 WIRED
  ——`pullcad` 陷阱的**析取版**。**登记进 `promote_atoms.json`(`tower_fear_ring_disjunction`)
  让它在有人 promote 的那一天自己举手**,而不是留在散文里等下一个总监重新发现。

### §FO.4 `towerfear` **退回出集**(53 → 52)—— (a) 买到了,而它有两半,两半反号

- **第一半买到了**:`VERIFY id=towerfear verdict=WORKING episodes=248`(录像组 2026-09-06T06:55Z,
  W50 全语料 248 个 R_lever episode / 65 个不同对局)。矩形内减半时钟确实释放:
  `occ% +2.45 / dwell +1.41s / bounce% −23.88`,三个量**两层同号**,对照的等级-only 控制是纯噪声。
- ⛔ **第二半反号**:被释放的 episode 摸进塔**自己的 700u 攻击圈**的占比升 **+12.46pp(ab)/ +35.21pp(ba)**,
  **两层同号**;读数取 **episode 级**不是帧加权(一局独占 128 个 `<700` 帧里的 **90** 个 ——
  铁律 4(ii) 点名的那个刀口)。点名病例:armed 腿的 sniper 扎到**距塔 179u**,连吃 5 秒塔伤,
  **hp 504 → 280**,最近敌方英雄在 1000u 之外 —— **出厂时钟本会把他拉出来**(GH #558)。
- **为什么不是 HOLD**:(b) 是**家族级**读数 ⇒ 每一波把这个 id 留在串里,armed 腿就在
  **promote 唯一能引的那个量**里执行一个**已量到有害半边**的杠杆。这与 09-06T13:2xZ 三条
  (a)=BUGGY 退集的论证同构(形状不同:那三条是咬错了,这条是咬对了域而结果一半有害;
  **污染是一样的**)。退集把 armed 腿退回**出厂时钟**,也就是稳定版 —— 保守默认。
- **退集不是 reject**:`bots/` 一行未动,gate 逐字保留,可以重新入集。
- **该 ship 的配置是 `towerfear` + `towerring` 那一对**(GH #558:在有害半边的那条几何线上劈开 ——
  塔够不着的环带保留减半,700u 圈内恢复出厂;释放集是 towerfear 的**真子集**,后者又是出厂的真子集,
  单臂可读且支配)。**owner P4.2 的冻结禁止 `towerring` 入集** ⇒ 这一对是**解冻后**(armed ≤ 20)
  要提的**重新入集申请**,已登记进 `iterations/owed_executions.json`
  (`towerfear_towerring_pair_readmit`),**接力棒不许掉**(铁律 9 第二句就是为这个形状写的)。
- ⚠️ **录像组自己的建议与本裁定同向**(20260906T065500Z §4:「`towerfear` 不因这一行而具备
  promote 条件,本组也不建议按现状 promote」)——本轮把它从「不 promote」推进到「不再 armed」。

### §FO.5 剩下六个 WORKING 的状态(**「有 WORKING」不等于「可以 promote」**)

| id | (a) | 本轮裁定 |
|---|---|---|
| `slotpush` | WORKING 939 | **未裁**。promote 时必须同轮退休 `state.json:coarmed_outlatch_slotpush_20260902` 那一行(它自己写着「届时退休该行,不是删掉转绿」),并处理 `outlatch` 的跨波不可比。 |
| `ckpush` | WORKING 40 | 未裁(下轮首选:门是**选择**不是析取,`mutstand_ckpush.sh` 已在树上)。 |
| `fieldsip` | WORKING 15 | **结构性 HOLD**:属共同 promote 原子 `field_hold_needs_magnitude`,而 `stayfield`/`stayfield2` 都是 INDETERMINATE(episodes 0/1)⇒ 单独 promote 会被 `promote_atoms.py` 直接拒。 |
| `wandbleed` | WORKING 1 / 2 | 未裁,(a) 太薄(episodes 1 与 2),且 §DU.5 的**阴性面**(掉的那些帧里有没有活着的攻击者)尚未登记。 |
| `wandbleed2` | WORKING 1 + INDETERMINATE 1 | 同上;两条读数相反,先要一份能分开的语料。 |

### §FO.6 同轮两条 queue 裁定(投递纪律 §2.5:落到被裁方读的那个字段)

`pending_rulings.py` 本轮打 `RIDESHARE 2`,两条都当轮裁掉(裁定写进各自的
`queue.json:<id>.director` 机器字段,不是写进 `question` 散文 —— 那正是 13:05Z W3 掉棒的形状):

- **`hero-38`(`zusfightquorum` 域扫描)= APPROVED-SCAN**。零 EC2、只读归档,搭 hero-2/30…37
  **同一次遍历**的第十份读数。⛔ **只批扫描,不预批入集**:该 id 现在 gated 且未 armed,
  冻结解除(armed ≤ 20)前它的入集提议唯一合法裁定仍是 **FROZEN-HOLD**。
  METHOD-FAILED 按 §CJ 强制;WIDENING 的归因边界逐字保留。
- **`hero-39`(GH #570 撤案复核)= APPROVED-SCAN**。⛔ **量具前提写进裁定本身**:
  必须用**半开**判据 `add <= t < remove`;`cullthresh_domain.py:215` 现在是闭区间,
  原样跑会复现 #570 的那个 `2`。两条预登记判读 (甲)/(乙) **不许合并**,
  `PREMISE-FALSIFIED` 这个标签归总监,本裁定不预判。

---

## §FP 2026-09-06T22:55Z 协同组 —— **一个 `or` 的两条腿,对「补给」的态度是 10:0;而没有否决的那条,正是真正开火的那条**;本节最该被读的是 **§FP.4:一个杠杆自己的测试,在落地当轮抓到了 GH #576 的形状长在它自己身上**

**认领**:工作流第 1 步扫 `[strategy]` open issue —— `#575`/`#572`/`#568`(本组前三轮已交付、
等总监裁)与 `#558`(已认领并交回),更早的 `#385/#300/#254/#201/#198/#26` 同为存量或
无帧证据 ⇒ **无未认领的带帧证据条目**,按铁律 9 取 owner 优先项:**P4.4(i)(工作单元
主体 = 一个 `bots/` 行为改动)+ P2(回程太费时间)**。

**⛔ armed 串一字未动、`queue.json` 一字未动**(P4.2 入集冻结,合法裁定 = FROZEN-HOLD)。
零 AWS、零 S3、零 EC2、零波次。

### §FP.1 章程点名的那一格:域价钱**先否掉它**,而否掉它的正是章程自己写下的那句警告

章程 `0STAYURN` 的「下一格」逐字写着:`J.ShouldStayAndRegen` 的 in-flight 词表缺
`modifier_clarity_potion`,**先跑域价钱**;并且预先警告「**它是回蓝不是回血,
『回蓝算不算 field sustain』是一个新意见不是一处不一致**」。

跑了:1012 活体帧里 **12** 帧挂着它;四条 supply 杠杆全 armed 后仍被否决的 **65** 帧里
带它的有 **3** 帧。**3 不是零。而这条路仍然判到此为止,理由就是章程预判的那一句** ——
`J.ShouldStayAndRegen` 的整个域是一条**血量带**(0.18–0.75),在那里把回蓝算成
field sustain,等于**把一个受伤的 bot 按在野外而一点血都不会到**。那确实是一个新意见。

⇒ **换站点,同一味药**:去一个**触发量本身就是蓝**的地方。

### §FP.2 ⭐ 主判据:`ConsiderWaitInBaseToHeal` 的两条腿,10 比 0

`bots/mode_roam_generic.lua` 的 `ConsiderWaitInBaseToHeal` 是 **SHIPPED 且未 gated**
的回基地 TP 判据,条件是一个 `or` 的两条腿:

| 腿 | 触发 | 回复类 modifier 否决 |
|---|---|---|
| HP 腿 | `J.GetHP(bot) < 0.25` | **10 个**(tango / flask / 化学狂暴 / 分身斧 / 战刃治疗 / 净化之焰 / 致命链接 / 撒旦 / 魂之灵瓮 / 灵龛) |
| MANA 腿 | `J.GetMP(bot) < 0.25` | **0 个** |

HP 腿那份表**长得就像穷尽**(连净化之焰、致命链接、撒旦都在里面),所以缺的那一味
不是「表短」。而 MANA 腿一个都没有 ⇒ **一个已经喝下净化药水的 bot —— 蓝正在到账、
在野外、已经付过钱、而且是它自己按的按钮 —— 仍然被读成「需要回基地补蓝」并 TP 走人。**

**⭐ 开火的正是这条腿,这是读数不是假设**:1012 帧里该函数出厂答 TRUE 的 **6** 帧,
**5 帧走 MANA 腿**。钉帧 `f_260819_222559_od_eclipse_solo` 的 **medusa:hp = 1.000
(满血)、mp = 0.149、`modifier_clarity_potion` 正在跳** —— 出厂说回家。

**⭐⭐ 施法路径这次是满的**,而这正是 `urnself` 那轮拒绝灵龛的理由的反面:
`X.ConsiderItemDesire["item_clarity"]` 在 `J.GetMP( bot ) < 0.4`、周围无敌人时
**自己喝**,**未 gated、每帧跑** ⇒ modifier 挂着就意味着**这个 bot 自己按过按钮**。
条件 (c) 的旁证是**数出来的**(不是打存在标志):item 层 `not bot:HasModifier(
"modifier_clarity_potion" )` 共 **3** 处('撤退:3' / '回复状态' 两条回城 TP 分支 +
一条不重复喝的自饮否决),`aba_buff` 的 `hero_is_healing` 也有它。

**落地**:`waitclar`,在 MANA 腿上追加

```lua
and not (J.IsSoakCandidate('waitclar')
    and J.IsModeTurbo()
    and bot:HasModifier('modifier_clarity_potion'))
```

**追加而非插入**;门是自己那个 `not (...)` 里的**第一个合取项** ⇒ 未 armed 时短路成
`not false` = true,turbo 与引擎调用**都不求值**。方向**由构造固定**:往合取式上追加
否决 ⇒ 只能把 TRUE 变 FALSE,**只能阻止回基地**。Turbo **不是**结构性的
(此路径上没有任何一处在它之上问过),所以**显式问**。

### §FP.3 域价钱与反真空列

```
live 1012 / fixtures 109
出厂 TRUE 6  =  HP 腿 1 + MANA 腿 5     (两桶相加 == 6,partition 是断言不是叙述)
净化药水携带者 12 = 蓝不够低 9 + 外层守卫 2 + HP 腿 0 + 域内 1   (四桶相加 == 12,数出来的)
flips 1 == blocked_domain 1              (驱动读数 与 前缀走桶 两条独立路线逐位相等)
flip_false_to_true 0;对调双腿后 flip_false_to_true_swapped == flips == 1、flips_swapped == 0
```

### §FP.4 ⭐⭐⭐ 立法级:**一个杠杆自己的测试,在落地当轮抓到 GH #576 的形状长在它自己身上**

`test_waitclar_mana_trip.lua` 有一条例行断言「arming 别的 id 不应该动这一帧」。
它**报红了**,而红的是 **`c4`**:本函数的**外层守卫**开头是 `not J.IsInLaningPhase()`,
而 **`c4` 延长对线期** ⇒ 在钉帧上**单独 arm `c4` 也会取消同一次回程**,走的是
**完全不同的一条子句**。

**处理方式是把它断言下来,不是把 `c4` 从循环里删掉**:

- `waitclar` **单臂仍可读**(单独 armed 时它翻这一帧;而同在 `J.IsInLaningPhase` 里的
  **`c2` 不翻**);
- **但含 `c4` 的成员串在这一帧上无法把读数归给任何一方** ⇒ 那种配置下的零应读作
  **「域未到达」不是「无效应」**。

⇒ **GH #576 的形状在一个全新杠杆上的活体实例**,已钉进测试与 nesting census 的新行。

### §FP.5 顺手:GH #576 的「钱那一问」驱动式答完(附带一条,非本轮主体)

`stayurn`(本组上一轮)把 nesting census 打红。修复不是改数字,是**答完检测器问的那句话**,
并且新建 `tests/_stayfamily_singlearm_sweep.lua` + `tests/test_stayfamily_singlearm.lua`
(**6/6 绿**)把批测台真正关心的那一问驱动式量出来 —— 同一份 1012 帧,**两列**:

| id | gold = 0(`.dem` 携带的) | gold ≥ 90(真实对局携带的) |
|---|---|---|
| 出厂 TRUE 集 | 13 | 125 |
| `staysrc` | **+44** | **+0** |
| `staybag` | +2 | **+0** |
| `staybottle` | +1 | **+0** |
| `stayurn` | +2 | **+0** |
| `stayattr` | +1 | +5 |
| `staytower` | **−0** | **−12** |

**⇒ 四条 supply 加宽的全部可测域只存在于金钱贫穷这一侧**:它们唯一能移除的就是最后那条
`not bHasRegen and GetGold() < 90`,金钱一过 90 那条本来就假。而唯一的减法 id
`staytower` 的 gold=0 零是**结构性的**(否决只能作用在函数**已经接受**的帧上,gold=0 时
那只有 13 帧、无一带 1200 内的塔),驱动过金钱门后它翻 **12**。
**没有任何一个 id 的零是另一个 id 造成的**:`pair_attr_tower_both == 0`、
`tower_subtracts_from_all_g200 == staytower_down_g200 == 12`、
`all_minus_tower_true_g200 − all_true_g200 == 12` 三列自洽。
**不声称**这两列就是真实域(顶 gold 只移动了一个 `.dem` 不携带的值),也**不声称**
六个一起 arm 是安全的(那是只有批测能答的涌现问题)。

**顺带一条立法级的量具教训(GH #550 的第三种形态)**:同族 sweep 用 `if(.-)then` 切
Lua 条件,**六个条件读成三个** —— 因为 **`HasModifier` 里含有子串 `if`**
(`Mod`+`if`+`ier`),扫描从**词中间**重新开始,两个「条件」回来时以 `ier( 'modifier_...`
开头。**没有任何东西报红,那个数只是错了。** 改成 `%f[%w]` 前沿锚定后读数 6/6。
⇒ **锚不但要数(#550/#555),还要词边界锚定。**

### §FP.6 诚实边界

1. **域 = 1 帧 / 1012**,是测量不是道歉;sweep 为每个携带者发一行 `B` 记录并自带停在
   哪一条子句 ⇒「语料里没有净化药水」与「有 12 个、被更早的子句挡掉 11 个」
   **永远不是同一份读数**。
2. **不压制逃跑**:本腿所在的外层守卫已经要求 **1200 内无敌方英雄**、距敌方遗迹
   **>2400**、且**非对线期** ⇒ 被取消的是**补给行程**不是撤退。
3. 净化药水**被英雄伤害打断**,一帧是一个瞬间,**不声称蓝一定全到** —— 那是 `fieldsip`
   在另一族的问题,本杠杆不借用。
4. **不碰上面的 HP 腿**,包括那份表**同样缺的 `modifier_bottle_regeneration`** ——
   那是另一条发现,**域为 0**(本语料 3 个空瓶携带者全在 0.25 血触发线之上),
   **另立不搭车**(GH #578 记录)。

### §FP.7 交棒

- **甲 → 总监**:登记在案,本轮**不提入集**(P4.2 冻结,合法裁定 = FROZEN-HOLD)。
  附 GH #576 的定量答复(§FP.5)与**规程建议一条**:锚除了要**数**,还要**词边界锚定**。
- **乙 → 批测台**:解冻后 `waitclar` **单臂可读**,但 ⛔ **不要和 `c4` 放进同一条成员串**
  (会被支配,见 §FP.4);⚠️ 域小(**1/1012 帧**),取证波按**稀有事件**排,
  不要按单波显著性读。
- **丙 → 录像组**:核验形状 = 真实 Turbo 局里「身上挂 `modifier_clarity_potion`、
  蓝 <25%、非对线期、1200 内无敌方英雄、有可用 TP」的时刻,**armed 腿留在野外、
  baseline 腿 TP 回基地**。⚠️ **病人血量可能是满的** —— 钉帧就是 `hp=1.000`,
  **按「低血」筛会一帧都找不到**。

---

## §FQ 2026-09-07T0x:xxZ 总监:**第六次 promote(`ckpush`,锚点 `stable-v5`),armed 52 → 51** —— 本节最该被读的是 **§FQ.4:这一条的 (b) 永远不会有答案,而那不是延期的理由,是裁定的一部分**

**认领**:上一轮交棒第 ① 项(「继续判定完结,首选 `ckpush`」)。owner P4.2 的产出指标是**判定完结数**,本轮 **1**(诚实记账:低于章程要求的 ≥2 —— 第二条本轮换成了 trunk 红的结清,见 §FQ.6)。
**零 AWS 调用、零 S3、零 EC2、零波次请求;不发 owner 邮件**(本周 W36 那封已发)。

### §FQ.1 条件 (a) —— WORKING 40,而它是一个**抑制型** gate 能买到的最强形状

`VERIFY id=ckpush verdict=WORKING episodes=40`(录像组 2026-09-03T07:20Z,W41 的 **82 局 `.dem`** 全部逐帧扫过,40 个域帧 / 15 局)⇒ **域非空,SILENT 被否决**。
决定性的一帧是**反事实**,在 **baseline 腿**上:`20260903_040014_slot4` **t=335.5**,`X.ConsiderR` 另外三条能返回 HIGH 的路被逐条排除(最近敌人 **1384u** > 1200 施法环、> 700 撤退环;1600 内**只有 1 名**敌人 ⇒ 团战合取项假),CK 正在吃 `badguys_tower1_bot` 的塔伤、身边 5 个己方兵,**0.3 秒后 Phantasm 放出**(t=336.3 三个 `modifier_illusion`)。**只有推塔分支能在那一帧开口。**

⛔ **诚实边界,引用本条必须连引**(逐字取自录像组 §4.4,不改口径):
- 这是**抑制型** gate,armed 侧**没有正面可观测量**;买到的是「出厂腿真的会在这里开火」,**不是**「看见 armed 侧挡住了这一次」。
- **效应量极小**:可归因施法 **1 次 / 82 局**;段内总施法率 **1.292 vs 1.294 每局(死平)**。
- LIMIT 1:`J.IsPushing()` 不可观测,40 个域帧是该合取项的**超集**(§4.1 那一帧靠塔伤拿到旁证,其余 39 帧没有);LIMIT 3:`IsFullyCastable()` 含蓝,快照只有 `mp_pct` ⇒ 域帧是上界;LIMIT 2:40 帧里 32 帧被 B1/B2/B4 遮蔽。

### §FQ.2 条件 (b) —— 八波家族级读数,**成员资格是量出来的**

| 波 | arm_ids | arm_md5(前 8) | `ckpush` armed | 家族 gpm | 计分局 |
|---|---|---|---|---|---|
| W42 | 57 | `38423b79` | ✅ | −19.15 | 172 |
| W44 | 58 | `7009f6c5` | ✅ | −9.60 | 183 |
| W45 | 60 | `eef5fb2e` | ✅ | −6.19 | 215 |
| W46 | 62 | `c7e1f92c` | ✅ | −20.26 | 206 |
| W47 | 62 | `c7e1f92c` | ✅ | −5.95 | 163 |
| W48 | 63 | `4aefc887` | ✅ | +27.25 | 184 |
| W49 | 61 | `824ec284` | ✅ | +11.70 | 168 |
| W50 | 59 | `572b6075` | ✅ | +13.76 | 187 |

**八波算术平均 −1.06 gpm,1 478 局计分。**
⭐ **「armed 了没有」这一格是怎么答的,比答案本身重要**:W42–W50 的波次记录**没有一个存 `arm_string` 字面量**(只有 `arm_ids`/`arm_bytes`/`arm_md5`),而上一轮 §FO 的第一稿正是在这里引错了波。本轮的判据是:把每个 `arm_md5` 拿到 **git 历史**里去反查 `test_set.md` 第 2 行(容器是 shallow clone,先 `git fetch --deepen 400` 才够深),**八个 md5 全部命中一个真实提交**,逐条展开后 `ckpush` 都在里面。**这是一次反查,不是一次转述。**
⛔ **边界**:这是**家族级**读数,不是 id 级 —— 全开波无法把经济归因到某一个成员;winrate 通道自 GH #352 起**连续 DEGENERATE**,**没有任何胜负读数可引**。而按 §FQ.1 的效应量(1 次 / 82 局),**这个 id 不可能是上面任何一个数字的成因**,两个方向都不可能。铁律 2(b) 要的是粗粒度的「无明显负面」,这就是那个,**再多一分都没有**。
⛔ W51 **不在表内**(`campgrade` 独占波,`arm_ids` 1);W52(52-id)**在飞未收割**。

### §FQ.3 条件 (c) —— 意图修复,**而反方理论一并登记**

`8 * 30` 是 `bots/` 里**唯一一个不是 60 的每分钟秒数常数**(落地时逐字计数 **127 : 2**,而那 2 处是**同一个表达式** —— 本处与它的 rubick 孪生体),逐字继承自 upstream OHA 快照 `74727e4:485`。作者写的是「8 分钟」,拿到的是 4 分钟。把一个 ~2 分钟冷却的团战大招押在**它刚上线那一段**去啃一座一塔,是标准打法里**不该做的那件事**;修复把阈值还原成代码自己的算术所指的那个值。
⚠️ **反方理论,登记而不是抹平**:Turbo 奖励抱团推进,**更早的目标承诺**本身是一个站得住的 Turbo 调参方向。**语料在这个效应量上分不开这两种理论**。⇒ 本裁定**压在「这是意图修复」上,不压在「量到了收益」上**;若将来真要更早的承诺时间,那必须是一个**带自己证据的、写明是 Turbo 常数**的改动,而不是**把一个继承来的笔误留在原地、因为它可能碰巧是对的**。

### §FQ.4 ⭐ 为什么「等一个更好的读数」不是一个选项

这个 id 的 (b) **永远不会有答案**:可归因效应是 **1 次施法 / 82 局**,而本项目一波的量级是 ~200 局、单粒种子 gpm 离散度上百。**没有任何本项目付得起的波次能把它的符号从零里分出来。** ⇒ 留在集里**买不到任何新东西**,却每一波都占着家族串里的一格、并稀释 promote 唯一能引的那个量。「有 WORKING 不等于可以 promote」的**另一面**是:**当一个 id 的剩余不确定性按构造不可测时,继续 armed 就是把不可测伪装成待测**。三条件是「安全 + 讲得通」的门,不是「证明更好」的门(铁律 2 第一句:小改动不做显著性检验)。

### §FQ.5 落地物与钉子(**促成本轮 promote 的每一颗钉子都同轮翻了面**)

- `bots/BotLib/hero_chaos_knight.lua`:`X.GetPushCommitTime` 的门由 `J.IsModeTurbo() and J.IsSoakCandidate( 'ckpush' )` 变为 `J.IsModeTurbo()`;三条件与边界抄进函数头(promote 之后**唯一还会被读到的地方**)。**非 turbo 逐字未动。**
- `tests/test_ckpush_minute_unit.lua` **14/0**:第 2 节从「gate-off 是出厂值」翻成「turbo 是修好的值 + **armed 集再也动不了它**」(负对照:arm 本 id 与 arm 无关 id 与不 arm 三者读数必须相同);第 3 / 第 5 节的两条腿从**两个 armed 集**改成**两个模式**;第 6 节从 `IsSoakCandidate('ckpush')` **恰好一处**翻成 **零处**(留着不改,它就变成在要求把缺陷装回来)。
- ⚠️ 第 3 节第二条测试原本断言 `dOff == dOn`,promote 后两次加载是**同一棵树** ⇒ 那个等式**按构造成立**,是一个 0EQUIV 绿(§DJ.9)。改成绝对量:`X.ConsiderR()` 在那两帧上答 `BOT_ACTION_DESIRE_NONE`,**且原因不是时钟**(大招未点,第一行就 bail)。
- `tools/agent/mutstand_ckpush.sh` **12/12 CAUGHT / 0 SURVIVED / 0 ABORTED**(`RC_EXIT=0`):M2/M3/M6 重锚 —— M2 = 修复逃出 turbo,M3 = turbo 判断**取反**,M6 = **promote 被悄悄撤销**(有人把门重新加回去:注释仍写 PROMOTED、`check_armed_wiring` 仍读 WIRED,而 `ckpush` 再也不会出现在任何 armed 串里 ⇒ 合取项**冻结为假**,每一局真实 turbo 悄悄回到 `8 * 30`)。**三条都 BRIBE 掉了会先响的字符串钉**,所以「CAUGHT」是行为断言给出的,不是字符串钉注意到字符串变了。
- ⭐ **顺手结清一条从别处漂过来的 ABORT**:M11 的锚是 `io.popen('find ' .. dir .. ' -name "*.lua" 2>/dev/null')` 整行,而该行在 `0fe65459`(英雄组 backlog -79)之后带上了共享的 `FARM_ONLY_FIND_CLAUSE` ⇒ **目标串从此不存在,M11 一直在 ABORT、台子退出码一直是 1**,而 `state.json` 里记的仍是 **12/12 CAUGHT**。与 GH #550 同族:**锚点对不上的变异体什么也没改,而台子照样打结论**。现已重锚到最短的承重片段(那个 glob 本身)。

### §FQ.6 同轮结清一条 trunk 红(**它是上一轮 promote 的产物,而红晚到了一轮**)

开工自检 `RC_EXIT=3`,`trunk-red(python)` 唯一一条:`tests/test_stable_anchors.py` —— `stable-v4` 的 `state_json_key` 写作单个字符串 **`"odbuild_PROMOTE_20260906 + illumove_PROMOTE_20260906"`**,那不是一个键。
修法**不是把它改成一个键**(那一轮确实落了两条独立记录),而是**让复数这件事可以被表达**:`state_json_key` 现在接受**字符串或非空字符串列表**,逐元素在 `state.json` 里查。**` + ` 拼接仍然红**(合成对照四条 + 那条拼接串本身各有一条断言),负对照实测:改回拼接串 ⇒ `NEG_RC=1` 并逐字打出那一行,改回列表 ⇒ 0。
⚠️ **形状值得记住**:写的人看着「两个键中间加个加号」完全合理,而**每一个读者都解析不了**;举手的是一天以后的自检,不是写的那一刻。

### §FQ.7 剩下的 WORKING(**状态更新,取代 §FO.5 那张表的对应行**)

| id | (a) | 现状 |
|---|---|---|
| `ckpush` | WORKING 40 | ✅ **本轮 PROMOTE**(§FQ)。 |
| `slotpush` | WORKING 939 | **未裁,下轮首选**。promote 时必须**同轮退休** `state.json:coarmed_outlatch_slotpush_20260902` 那一行(它自己写着「届时退休该行,不是删掉转绿」),并处理 `outlatch` 的跨波不可比(⛔ W38 与 W39 起的 `outlatch` (a) 不是同一个量)。 |
| `fieldsip` | WORKING 15 | **结构性 HOLD**:共同 promote 原子 `field_hold_needs_magnitude`,`stayfield`/`stayfield2` 仍 INDETERMINATE。 |
| `wandbleed` / `wandbleed2` | WORKING 1 / 1+1 | (a) 太薄且两条读数相反;先要一份能分开的语料。 |

### §FQ.8 投递(§2.5:落到被裁方读的那个字段)

- `queue.json:strategy-38`(bundle `ckpush`)的 **`director` 机器字段**写入本裁定(`{ruling: PROMOTE, ...}`),**不写进 `question` 散文**(13:05Z W3 掉棒的形状)。
- GH **#426** 追评并关闭 —— ⚠️ 若 `mcp__github__*` 在本容器要审批(铁律 11:无头 Routine 没有人点 Approve),**不空转等待**,评论全文留在本节与本轮报告里,下轮补发。
- **残留登记**:rubick 孪生体 `bots/FunLib/rubick_hero/chaos_knight.lua` 的 `8 * 30` **保持 registered-not-fixed**(`corpus_hero_census.py --hero rubick` 答 DOMAIN-EMPTY:files=0, games=0 ⇒ 条件 (a) **按构造买不到**),`mutstand_ckpush.sh` 的 M12 就是替它站岗的那颗钉子。

---

## §FR 2026-09-07T01:20Z 协同组 —— **一个没点技能点的终极技能被读成「有」,而代价是整个撤退模式**;本节最该被读的是 **§FR.3:调用点那一列是 0,而那个 0 是语料的几何性质,不是杠杆的读数** —— 以及 **§FR.6:变异台在本轮抓到 GH #171 的形状长在本杠杆自己的 pair 计数器上**

**认领**:工作流第 1 步扫 `[strategy]` open issue —— `#578`/`#575`/`#572`/`#568`
(本组前四轮已交付、等总监裁)与 `#558`(已认领并交回),更早的
`#385/#300/#254/#201/#198/#26` 同为存量或无帧证据 ⇒ **无未认领的带帧证据条目**,
按铁律 9 取 owner 优先项 **P4.4(i)**。

**⛔ armed 串一字未动、`queue.json` 一字未动**(P4.2 入集冻结,合法裁定 = FROZEN-HOLD)。
零 AWS、零 S3、零 EC2、零波次。

### §FR.1 章程点名的那一格:**价钱把整条缝判到此为止**,不只是「不加第七个 id」

章程 `0WAITCLAR` 的「下一格」要求先答:「**这一族还值不值得再加第七个 id**」。

把五条 supply 杠杆(`staysrc`+`staybottle`+`staybag`+`stayurn`+`bagsalve`)**同时 armed**,
`bot:GetGold()` 分别驱动到 0 与 200 两列,走 1012 活体帧:

```
到达 supply 子句(gold=200 出厂放行)      125
五条全 armed、gold=0 仍被否决              63     (上一轮四条时 65;stayurn 取走 2)
  真的两手空空                             45     → fieldbuy 的事,不是词表
  背包 tango / faerie_fire                  8     → bagsalve 已裁(没有 shipped 换位器)
  空瓶 item_empty_bottle                    3     → 正确
  带灵龛/魂之灵瓮但没有在跳                  7     → urnself 已定价拒绝(GH #542 形状)
  ⭐ 主槽带着词表不认识的回复消耗品           0
```

**最后一行的 0 就是答案**:五条走完之后,**没有任何一帧**是因为词表少一味药而被读成
两手空空。**⇒ 不加第七个 id。**

**而比这更强的一句**,合上 §FP.5 的两列:四条 supply 加宽在 `gold ≥ 90` 一侧读数**全为 0**,
这是**结构**不是巧合 —— 它们全部坐在
`if not bHasRegen and bot:GetGold() < 90 then return false end` 的 `not bHasRegen` 后面,
金钱过 90 那条否决本来就假。⇒ **整族 5 个 id 的真实域 = 「受伤 ∧ 未被追 ∧ 不到 90 金」**。
**这是给总监做 `判定完结` 的读数**(P4.2 要的是集合变小),不是给本组再加杠杆的。

### §FR.2 同轮另外四条候选路,**全部跑了价钱、全部被价钱否掉**(登记为「定价后拒绝」)

| 候选 | 域读数 | 判定 |
|---|---|---|
| `撤退:1`/`撤退:2` 的回复词表比 `撤退:3` 少三味 | 落在两条分支自己的血量帽(`<0.19` / `<0.15+0.24n`)内的携带者:净化药水 **0**、空瓶 **0**、`filler_heal` **0** | ⛔ 域 0 |
| `mode_retreat_generic:457` 回基地补蓝(`botMP<0.4` ∧ 距泉水 ≤4000 ∧ 非团战),**无任何补给否决** | 域 **3**;带净化药水 **1**,而那 1 帧距泉水 1225 < 2000 ⇒ item 层本来就拒绝喝 ⇒ 回家是对的 | ⛔ 唯一域内帧是假阳性 |
| 净化药水自饮的危险半径写成 `800 + aetherRange`(**投掷射程**),而兄弟条目 `item_flask` 同位置写**裸的 900** ⇒ **买以太之镜会让 bot 更不敢喝自己的药水** | 语料里以太之镜 **0** 把 ⇒ 域 0 | ⛔ 域 0(现象登记) |
| `item_blood_grenade` 的收尾判据把 5 秒 DoT 当瞬伤(`CanKillTarget(e, 50+15*5)`,而树里有 `J.WillKillTarget(...,nDelay)` 且本分支自己声明 `nDuration = 5`) | 携带者 **100**/1012、900 内有敌人 **40**、`CanKillTarget(e,125)` 命中 **0** ⇒ 这条收尾分支整份语料**一次都没开过火** | ⛔ 域 0;**但「100 携带者 / 0 次投掷」是独立发现,交英雄组** |

### §FR.3 ⭐ 主判据:`GetAbilityByName` 的把手不等于「这个技能存在」

`J.IsWkReincarnationArmed`(`bots/FunLib/jmz_func.lua`)**SHIPPED**;唯一调用点
`bots/mode_retreat_generic.lua ~:198` 也 **SHIPPED、无 gate**,并把它的答案花在
**`return BOT_MODE_DESIRE_NONE`** 上 —— **整个撤退模式**在那一帧清零,位置在**整条
retreat guard chain 之上**。

它凭两个引擎读数下判断,而**两个都不是要紧的那个**:

- `bot:GetAbilityByName` 对**没点技能点**的技能**照样返回活把手**(未学习 ≠ `nil`,
  是一个 **level 0 技能**);
- level 0 技能**不在冷却里** ⇒ `GetCooldownTimeRemaining()` 答 **0.0**,守卫放行;
- 剩下 `bot:GetMana() >= 160`,骷髅王从第一分钟起都满足。

⇒ **没点大招的骷髅王读作 ARMED,团战里撤退模式被整个关掉。**
`bot:GetLevel() >= 6` 是**英雄等级**,对技能点去了哪里**一个字都没说**。

**⭐ 树在八行之外就知道该问什么** —— `mode_retreat_generic` 自己的 huskar 块,
**同一个函数体内**:`if hAbility and hAbility:IsTrained() and hAbility:GetLevel() >= 3 then`。
同一个引擎调用、同一个文件、同一个函数,**先问 `IsTrained()` 再相信把手**。
`axeblink` 亦然。**这一行只是没被带过来。**

**落地 `wkreinctr`**(turbo **显式** —— 此路径与调用点均无人在其上问过 turbo;**STANDALONE**;
**未 armed**):

```lua
if J.IsSoakCandidate( 'wkreinctr' )
and J.IsModeTurbo()
and not abilityR:IsTrained()
then
    return false
end
```

**方向由构造固定**:排在所有其它判据**之前**的否决 ⇒ 只能 TRUE→FALSE,
唯一能造成的行为是**把出厂压制掉的撤退还回来**。未 armed 时门是第一个合取项 ⇒
turbo 与 `IsTrained()` **都不求值**,兄弟 `wkreincarnmp` 的子句**逐字节同构**。

### §FR.4 两列读数,**而第二列的零必须带标签**(GH #576 的形状)

```
WK 活体帧 36 / 出厂 TRUE 24 / armed TRUE 10 / flips 14      (24 − 14 逐位对得上)
flip_false_to_true 0;对调双腿后 swapped_up == flips == 14、swapped_down == 0
反真空四桶(数出来的):冷却 11 + 未学习 15 + 蓝不够 0 + 出厂放行 10 == 36
  未学习 15 比 flips 多 1:那 1 帧出厂本来就被 160 蓝挡住(mana=158)
—— 调用点那一列 ——
等级>=6 的 WK 帧 23;出厂 TRUE ∧ 未学习 ∧ 等级>=6 = 2;IsInTeamFight(1200) 为真 = 0;调用点 flips = 0
```

**⛔ 那个 0 读作「域未到达」,不是「无效应」**:36 帧无一有两个队友在 1200 内 ——
**这份语料是为 P2 回城 TP 调查切的,不是为团战切的**。
**⛔ 而且它是从宽松侧读的**:mock 的 `GetNearbyHeroes` **忽略第三个参数(bot mode)**
⇒ 它的 `IsInTeamFight` **高估** ATTACK 模式队友数 ⇒ 真实可达集 **≤** 这个 0。

**钉帧** `f_073148_zuus_lina` 的骷髅王:**英雄等级 7、大招技能等级 0、冷却 0.0、蓝 224**
—— 出厂说 ARMED。真实回放帧。

### §FR.5 单臂可读性:同一 helper 上的第二个 id,**顺序的而非并列的**

`wkreinctr` 在 `wkreincarnmp` **之前 return** ⇒ 两者**各自独立充分**,正是
「arming 一个会在另一个也开火的帧上量到正确的零」那种形状。**测量而非断言**:

```
pair_ne_arm 1(= f_260725_105305_wk_reincarn_gap,lv6/蓝189/大招已学习 ⇒ 归 wkreincarnmp)
pair_ne_arm_in_flipset 0;pair_ne_arm_out_flipset 1;两桶相加 == pair_ne_arm
arm_leak 0
```

⇒ **本杠杆的 14 帧没有一帧是兄弟决定的,单臂波可以归因。**

### §FR.6 ⭐⭐ 立法级(量具):**一个断言 == 0 的计数器,证明不了自己数得动 —— 这次它长在 pair 列上**

`pair_ne_arm_in_flipset` 的第一版是

```lua
if shipped and not arm then bump('pair_ne_arm_in_flipset') end
```

下游断言 `== 0`。变异台 **M15 直接走了过去(SURVIVED)**:删掉这个 bump,计数器仍是 0,
**和「1012 帧驱动过、确实一帧都没有」读起来一模一样**。这就是 GH #171 的形状,
而这一次它长在**本杠杆自己的 pair 列**上 —— `tally()` 对调双腿那一招治的是 `flips`,
**没有人把同一条纪律推广到 pair 列**。

**修法与 `tally` 同源**:两半走**同一个 bump**,

```lua
bump((shipped and not arm) and 'pair_ne_arm_in_flipset' or 'pair_ne_arm_out_flipset')
```

于是**必须读 0 的那一支,正是必须报出全集的那一支**;测试同时断言
`out == 1` 与 `in + out == pair_ne_arm`。重跑 **M15 CAUGHT**。

**可复用的一条**:⛔ **任何被断言为 0 的计数器,都要有一个走同一个 bump 的补集**。
「对调双腿」不是 `tally()` 的性质,是**零断言**的性质 —— 凡零断言处皆适用。

### §FR.7 产出

`bots/FunLib/jmz_func.lua`(`wkreinctr` 块)、`tests/test_wkreinctr_untrained.lua`、
`tests/_wkreinctr_sweep.lua`、`tools/agent/mutstand_wkreinctr.sh`、
`tests/test_gated_helper_nesting_census.lua`(新增一行 pin,附手读分类)、
`iterations/state.json:wkreinctr_20260907`;
报告 `iterations/reports/strategy/20260907T012000Z.md`。

### §FR.8 交棒(总线 **GH #582**)

- **甲 → 总监**:`wkreinctr` 登记在案,**不提入集**(FROZEN-HOLD)。另附 §FR.1 的
  五桶读数作 `判定完结` 证据:**supply 加宽族 5 个 id 的真实域被 `GetGold() < 90` 夹死**,
  残余 63 帧里词表缺项那一桶实测 **0**。并提一条规程建议:**§FR.6 的零断言补集规则**。
- **乙 → 批测台**:解冻后 `wkreinctr` **单臂可读**,但 ⛔ **取证不能靠这份 fixture 语料**
  —— 调用点那一列在本语料上是 **0**,而那是**语料几何**不是杠杆。需要真实 Turbo 团战帧。
- **丙 → 录像组**:核验形状 = 真实 Turbo 局里一个**骷髅王**在团战中
  **`skeleton_king_reincarnation` 技能等级为 0** 的时刻,baseline 腿撤退欲望被清零、
  armed 腿恢复撤退。⚠️ **按「英雄等级 ≥ 6」筛会漏掉大半** —— 本语料 15 个未学习帧只有
  2 个到 6 级;**要按技能等级 0 筛**。
- **丁 → 英雄组(登记,不催)**:§FR.2 最后一行的血之荼蘼一格。

---

## §FS 2026-09-07T07:30Z 协同组 —— **一个 25 金、51 个购买表都有、整个对线期反复补货的消耗品,两条分支都是击杀确认**;本节最该被读的是 **§FS.4:本轮最强的变异体在本语料上不动任何一个数字(M7),它打的是位置不是行为** —— 以及 **§FS.6:第一版 M12 幸存,而缺陷在断言不在变异体(sweep 自己那半结构解析算了但没人读)**

**认领**:工作流第 1 步扫 `[strategy]` open issue —— `#582`/`#578`/`#575`/`#572`/`#568`
(本组前五轮已交付、等总监裁)与 `#558`(已认领并交回),更早的
`#385/#300/#254/#201/#198/#26` 同为存量或无帧证据 ⇒ **无未认领的带帧证据条目**,
按铁律 9 取 owner 优先项 **P4.4(i)**;章程 `0CORPUSPIN` 的「下一格」明写:甲路
(`J.IsInTeamFight` 团战帧)未到位 ⇒ 走**乙路**,先跑 `item_blood_grenade` 那条缝的**域价钱**。

**⛔ armed 串一字未动、`queue.json` 一字未动**(P4.2 入集冻结,合法裁定 = FROZEN-HOLD)。
零 AWS、零 S3、零 EC2、零波次。

### §FS.0 先纠一句本组自己的记法 —— 那条缝的根因**不是**「没有 consider 函数」

章程 `0CORPUSPIN` 把这条缝记作「100 携带者 / 0 次投掷」。本轮开工时第一遍
`grep 'ConsiderItemDesire\["'` **读回了「这个道具根本没有 entry」**,而那是**错的**:
这个 entry 用的是**单引号** `ConsiderItemDesire['item_blood_grenade']`,双引号的模式
扫不到它。**根因是另一件事,而且更值得修**:entry 在,只是它的**两条分支都是击杀确认**。

### §FS.1 主判据:两条分支,两个都要求「这一下就把人打死」

| | 已发货分支的开火条件 | 本语料上的命中 |
|---|---|---|
| loop 1 | `J.CanKillTarget(enemyHero, totalDmg, MAGICAL)` —— 手雷自己的 **125**(50 撞击 + 15/s×5s)必须够杀;有一条 **275** 的延伸,但它坐在 `bot:IsFacingLocation(enemyHero:GetLocation(), 15)` 这个**15 度**锥形 + `IsInRange(bot, e, GetAttackRange())` 后面 | **0** / 40(275 那一档 3,但只能经由 15 度锥形够到) |
| loop 2 | `J.IsGoingOnSomeone(bot)` **且**有队友正在追同一个目标 **且** `J.GetTotalEstimatedDamageToTarget(nInRangeAlly, enemyHero) >= enemyHero:GetHealth()` —— **队友自己的伤害已经够杀** | **0**(驱动读数:`cast_ship == 0`) |

⇒ 这棵树把一个**对线期消耗品**当**处决工具**用。条件 (c) 的反面证据是数出来的:
`bots/BotLib/` 下 **51** 个英雄的购买表里有它,25 金,最大囤 2,整个对线期反复补货。

### §FS.2 域价钱(漏斗,每一层都是数出来的)

```
1012 活体帧 / 109 fixture
 238  携带手雷(任意格)
 100  携带在主槽 0-5
  40  主槽携带 且 900 施法距离内有敌方英雄
  40  且全部通过 valid / 非魔免 / 非幻象   (cand == loop,过滤器一帧没删)
   0  且 CanKillTarget(e, 125, MAGICAL)    <- 已发货 loop 1 的门
   3  (若换 275)                           <- 只能经由 15 度锥形
  40  且 nHealth > nHealthCost * 2          <- 自保下限,本语料上不约束
   8  且 GetHealth() <= totalDmg * 3        <- 本杠杆的域(目标血量 225–363)
```

杠杆写在**道具自己的尺子**上而不是一个口味阈值:**手雷能削掉对方剩余血量的至少三分之一**。

### §FS.3 ⭐ 两把独立的量具落在同一个数上,而测试断言的是**等式**

`domain`(合取项前缀行走)**8** == `cast_armed`(**驱动**:每帧跑两遍已发货的
`_G.ItemUsageThink`,读回记录到的引擎动作)**8**;`cast_ship` **0**。
两列都断言,任何一列都不能替另一列说话(变异台 **M8** 专打这个:让前缀行走丢掉阈值)。
驱动那一列需要给**手雷把手**补 IsTrained/IsActivated/IsFullyCastable ——
`J.CanCastAbility` 对每个 fixture 道具把手都短路在 `not IsTrained()`(**第十六条世界断言**),
补法与 `urnself` 那轮逐字相同,**且只补手雷这一个把手**。**M13** 打的就是这个:
把 IsTrained 拿掉,`cast_armed` 读回 **0** —— 和「这个杠杆什么都没做」印出来一模一样。

### §FS.4 ⭐⭐ 本轮最强的变异体在本语料上不动任何一个数字(M7)

方向在这里是**构造**不是论证:块被追加在两条已发货分支的 `return` **之后**
⇒ arming 只能把 `BOT_ACTION_DESIRE_NONE` 变成一次投掷,**永远不可能改道、延迟或压过
已发货代码本来就要做的那次投掷**。**M7 把这个块原样搬到两条分支上面** ——
语法没问题,**本语料上没有任何一个计数会动**(已发货分支在这里一次都不开火),
`domain`、`cast_armed`、`flips` 逐位不变。抓住它的**只有结构断言**
(「gate 必须落在最后一条已发货 `return BOT_ACTION_DESIRE_HIGH` 与最终 `NONE` 之间」)。
⇒ **可复用的一条:当方向来自位置而不是来自谓词,守住方向的断言必须是位置断言;
任何行为计数对它都是瞎的。**

### §FS.5 方向零的补集(GH #171 形状,第三次照办)

`flip_true_to_false == 0`,而**同一个 `tally()` 对调双腿再调一次**:
`flip_true_to_false_swapped == flips == 8`、`flips_swapped == 0`。
**M6 / M6b** 分别删掉两次调用,两发都 CAUGHT。
另有 `driven + undriven == loop`(40 帧里 2 帧驱动不起来)—— **一次死掉的驱动
不许悄悄缩小分母**。

### §FS.6 ⭐ 变异台第一版 M12 幸存,而缺陷在**断言**不在变异体

`M12`(把 **sweep** 的 `strip_comments` 换成恒等式)第一版 **SURVIVED**。
按证据纪律第 2 条先查断言:sweep 自己那半**结构解析算了,但没有任何断言读它**
—— 测试用自己的 parser 把同样的事实又读了一遍。⇒ **那半是死仪表**。
修法**不是删掉它**,而是新增 section 4「**两个 parser 对表**」:
sweep 走的施法距离/伤害常数、gate 位置、id 计数、已发货两条分支的击杀确认计数,
逐条与本文件自己的读数断言相等。**理由是算术不是整洁**:sweep 的语料列
(§FS.2 的 40、§FS.3 的 8)是**用 sweep 解析出来的数**量的,两个 parser 不对表,
就无法排除「sweep 量的是另一个谓词」。补上之后 **M12 CAUGHT**,
全台 **15 发 / 15 如声明 / STAND GREEN**。

### §FS.7 诚实边界(写在前面,不埋)

1. mock **不施加魔抗**(`GetActualIncomingDamage` 返回原始伤害)⇒ 每条 CanKillTarget
   读数都是**上界**。这对「已发货击杀确认命中 **0**」是**安全**方向,对任何
   「这一投能杀」的声称是**不安全**方向 —— **本杠杆不声称击杀**,测试里没有这样的断言。
2. `nHealth > nHealthCost * 2` 在 **40/40** 全通过:**本语料上它不约束**。
   它被保留是因为它是**已发货 entry 自己的规矩**,不是因为量到它有用。
   **M5** 删掉它时**没有任何域数字会动**,抓住它的是「抄写条款计数 == 3」那条。
3. 本语料为 owner 优先项 **P2 的回城 TP 调查**而切,**不是**为对线期而切 ——
   40 是**这份语料的几何**,不是真实对局里的频率。

### §FS.8 产出

`bots/ability_item_usage_generic.lua`(`grenharass` 块)、
`tests/test_grenharass_domain.lua`(**12/12**)、`tests/_grenharass_sweep.lua`、
`tools/agent/mutstand_grenharass.sh`(**15/15 GREEN**)、
`iterations/state.json:grenharass_20260907`;
报告 `iterations/reports/strategy/20260907T073000Z.md`。

### §FS.9 交棒(总线 **GH #590**)

- **甲 → 总监**:`grenharass` 登记在案,**不提入集**(FROZEN-HOLD)。
  另附一条规程建议:**§FS.4 的位置断言规则** —— 当一个 gated 块的方向来自
  **它在函数里的位置**(追加在已发货 `return` 之后)而不是来自谓词,
  守住方向的断言**必须是位置断言**;任何行为计数对这类变异都是瞎的。
- **乙 → 批测台**:解冻后 `grenharass` **单臂可读**(entry 内只有这一个 id,
  一条件一 id)。⚠️ **取证不能只靠这份 fixture 语料** —— 40 帧是 P2 语料的几何。
- **丙 → 录像组**:核验形状 = 真实 Turbo 对线期里一个**主槽带血之荼蘼**的辅助,
  **900 内有敌方英雄且该英雄当前血量 ≤ 375** 的时刻:baseline 腿不投,armed 腿投。
  ⚠️ **按「能不能杀」筛会一帧都筛不到** —— 已发货的门就是击杀确认,本语料命中 0。
- **丁 → 英雄组(登记,不催)**:`X.ConsiderItemDesire` 的键有**单引号与双引号两种写法**
  (`['item_blood_grenade']` vs `["item_flask"]`)。任何按 `ConsiderItemDesire\["` 做的
  普查都会**系统性漏掉单引号那一族**;本轮开工第一遍就是这么读错的(§FS.0)。
  **数出来的**:双引号 **168** 个键、单引号 **8** 个(`item_blood_grenade`、`item_disperser`、
  `item_dust`、`item_harpoon`、`item_pavise`、`item_pirate_hat`、`item_smoke_of_deceit`、
  `item_soul_ring`)—— 漏掉的不是一个,是 **8 个道具的整个决策层**。

---

## §FT 2026-09-07T10:xxZ 总监:**第七次 promote(`slotpush`,锚点 `stable-v6`),armed 51 → 50** —— 本节最该被读的是 **§FT.4:这一条的行为钉子在本仓库的语料上买不到,而变异台是这么量出来的,不是这么猜出来的**

上一轮 §FQ.7 把 `slotpush` 点名为「**未裁,下轮首选**」。本轮裁 PROMOTE。

### §FT.1 条件 (a) —— WORKING 939,**而且它有一个可观测的消费者**

录像组 2026-09-03T22:05Z(`iterations/reports/replay-check/20260903T220500Z.md`),W42 语料,**78/78 局宽扫 + 2 局逐帧**,`unparseable` 0。
读数:夜魇腿上 **43.80%(armed)/ 39.96%(baseline)** 的「本队处于高地推进几何」的帧,**出厂扫描答不出 TRUE**;天辉侧 **1.85% / 1.44%**。**侧别不对称正是缺陷预测的方向**(见 (c))。
**939** = 夜魇 armed 腿上「armed 判 TRUE、出厂判 FALSE、且无死亡成员导致不可判」的帧数。
⭐ **它是 WORKING 而不是 INDETERMINATE 的理由是消费者而不是计数**:那些窗口里 armed 腿的插眼速率降到自己平时的 **0.49 倍**,baseline 腿升到 **1.61 倍** —— 正是 `mode_ward_generic.lua:37`(用 TRUE 把插眼 desire 压成 `NONE`)预测的方向。`slotarb` 卡在一个只问一次的闩上、没有这一半,所以它至今 INDETERMINATE。

### §FT.2 条件 (b) —— 十波家族级读数,**成员资格照 §FQ.2 反查**

| 波 | arm_ids | arm_md5(前 8) | `slotpush` armed | 家族 gpm | 计分局 |
|---|---|---|---|---|---|
| W39 | 55 | `bfe60fcd` | ✅ | −12.58 | 168 |
| W40 | 55 | `bfe60fcd` | ✅ | −27.81 | 149 |
| W42 | 57 | `38423b79` | ✅ | −19.15 | 172 |
| W44 | 58 | `7009f6c5` | ✅ | −9.60 | 183 |
| W45 | 60 | `eef5fb2e` | ✅ | −6.19 | 215 |
| W46 | 62 | `c7e1f92c` | ✅ | −20.26 | 206 |
| W47 | 62 | `c7e1f92c` | ✅ | −5.95 | 163 |
| W48 | 63 | `4aefc887` | ✅ | +27.25 | 184 |
| W49 | 61 | `824ec284` | ✅ | +11.70 | 168 |
| W50 | 59 | `572b6075` | ✅ | +13.76 | 187 |

**十波算术平均 −4.88 gpm,1 795 局计分。** `slotpush` 于 W39 入集,**此后每一波已收割的波都含它**(W41 从未收割、W43 报废、W51 是 `campgrade` 独占波)。反查方法与 §FQ.2 逐字相同:容器是 shallow clone,先 `git fetch --deepen=400`(不 deepen 只能反查出 6 个 md5,十波里**八波读 UNRESOLVED**),再拿每个 `arm_md5` 去 git 历史里比对 `test_set.md` 第 2 行。
⛔ **边界,而且这次边界是承重的**:家族级不是 id 级;全开波无法把经济归因到某一个成员;**十波里 arm 串的成分几乎每波都在变**;winrate 通道自 GH #352 起连续 DEGENERATE,**没有任何胜负读数可引**。
⛔ **均值是轻微负的,不粉饰**:−4.88 gpm。铁律 2(b) 要的是粗粒度的「无明显负面」,这就是那个 —— **但它不是正面证据,不许当正面证据引**。
⚠️ **与 §FQ.4 的分界线,必须读清楚**:`ckpush` 的 (b) 是**按构造**买不到(1 次施法 / 82 局,低于本项目任何一波的噪声底),所以「等更好的读数」在那里不是选项。**`slotpush` 不是那样** —— 它的效应量不在噪声底下,一波独占波**能**说得更多。⇒ **本裁定压在 (c) 上,不压在「等不到」上**;把 §FQ.4 的论证搬过来是**错的**。
⚠️ 分层读数按铁律 4(i-a) 登记(swap-average 后的估计量,4(i-c):反号不是否决理由):W47 gpm ab −45.27 / ba +33.37;W48 ab +127.24 / ba −72.75;W49 ab +58.07 / ba −34.66;W50 ab −131.61 / ba +159.12。四波 `sign_flip` 均为 true,`side_gt_arm` 2/2–4/4 —— **这是 |side| > |arm| 的恒等式,不是诊断**。

### §FT.3 条件 (c) —— **这一条是承重的那一条**

`GetTeamMember(n)` 取的是**队伍槽位 1..5**(`docs/BOT_API_REFERENCE.md:223`);`GetTeamPlayers(team)` 交回的是**玩家 id**(天辉 0-4 / 夜魇 5-9)。出厂那一行**把后者喂给前者**,越界返回 nil,于是扫描按侧静默收缩:**天辉 4/5,夜魇 1/5**;并且从第 2 步起,`IsHeroAlive(playerdId)` 这道守卫问的是**另一个英雄**,不是它随后去量的那个 `teamMember`。
**这是实参类型错误,不是调参选择** —— 没有任何一种读法能让出厂那一行是作者的本意。
失效方向是**闭合的**:看见更少队友只会让「本队在推进」**更难成立**,而七个调用点**全部**用 TRUE 去压制一件分心事(眼 / 神符 / 前哨 / 边路商店 / 秘密商店 / Roshan / 回线)⇒ 扫得少 = **把 bot 从高地攻坚上摘下来去购物**。标准打法里不该做的那件事。
本缺陷族(pid 当槽位喂 `GetTeamMember`)的第四个被修的成员、**第二个被 promote 的**(前一个是 `slotwait`,2026-09-06)。

### §FT.4 ⭐ 行为钉子买不到,**而这是量出来的**

`tools/agent/mutstand_slotpush.sh` **8 CAUGHT / 0 SURVIVED / 0 ABORTED**(`RC_EXIT=0`)。但**最该被读的是过程里那一发幸存**:
本轮先按房规写了「promote 的行为钉子」——turbo 下无论 armed 串是什么都走修好的扫描,三条腿(本 id armed / 无关 id armed / 什么都不 armed)读数必须相同。**它在 M4(有人把闸偷偷加回去)下 SURVIVED。**
原因在文件里早就写着,而我是被变异台按着头才去读的:`[domain price]` 那条断言 **`nFlip == 0`,94 个 subject-load 上两条腿从不分歧**。⇒ **本仓库的 fixture 语料在结构上分不开出厂扫描与按槽位扫描**,于是那条行为断言是 **0EQUIV 绿** —— 它在闸被加回去之后**照样绿**。
⇒ **处置(不是删掉那一发,是把结论写下来)**:M3/M4 **不 BRIBE 源码钉**,并在变异台与测试文件里逐字写明「**这两发是被字符串钉抓住的,那是限制不是优点**」。**这条杠杆今天的守卫是一个字符串钉**;哪天 `[domain price]` 变红(=终于进来一个能分开两条腿的 fixture),那条行为用例才开始承重 —— 它因此保留而不是删除。
⚠️ 同族第二发:M7/M8 的**第一版都攻击了断言自己**(把 `nTrue` 预置成 1 / 把 `nFlip` 计数器写死),**双双幸存** —— **一个文件抓不住自己的断言被放松**(与 `mutstand_ckpush.sh` M9/M10 同一处置)。改从**数据侧**打(抽掉语料里唯一那个 TRUE 的 subject-load)之后两发都 CAUGHT。**残余缺口照实登记**:没有任何东西会发现将来有人把 `nFlip == 0` 或 `nTrue == 1` 放松掉。

### §FT.5 落地物

- `bots/FunLib/jmz_func.lua`:`J.IsTeamPushingHighGround` 的实参 `J.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' )` → `J.IsModeTurbo()`;三条件与边界抄进函数头(promote 之后**唯一还会被读到的地方**)。**`bots/` 本轮只有这一处 diff**;`utils.lua` **零 diff**(flag 形参保留,非 turbo 逐字是出厂路径)。
- `tests/test_slotpush_highground_scan.lua`:`[structure]` 那条**翻面** —— 由「必须挂 `slotpush` 闸」变成「**一处 `IsSoakCandidate` 都不许有**、`jmz_func.lua` 代码里不许再出现这个 id、且实参必须**恰是** `J.IsModeTurbo()` 未取反」。留着不改它就变成**在要求把缺陷装回来**。新增 `[promote]` 行为用例,**带 §FT.4 那段自陈的 0EQUIV 说明**。17 → 19 用例,**19/0**。
- `tools/agent/mutstand_slotpush.sh`:新建,8 发。
- `carrier_terms.py`:载体项 **7 → 7**,`TERMS` 行逐字节相同;⭐ **旧 51 串在本树上 `1 unresolved` 退出码 2,新 50 串 `0 unresolved` 退出码 0** —— 代码改了而串没改的那半个状态会自己变红。
- `state.json`:新键 `slotpush_PROMOTE_20260907`;**退休** `coarmed_outlatch_slotpush_20260902`(该册自己写着「届时退休该行,不是删掉转绿」)。
- `stable_anchors.json`:`stable-v6`。

### §FT.6 交棒

- **`outlatch` 的混杂**:两条腿从此都带 `slotpush` 的否决 ⇒ **差分里的混杂走了**,但**跨越今天的 (a) 依旧不可比**(W38 / W39–W53 / W54 起,三段)。已写进 `owed_executions.json`。
- **同族剩下的两处 pid 缺陷**(`aba_push.lua:584/587`)在录像组 09-03 报告 §7 里量过:同一 107 fixture 上**一次都不答 TRUE**(0 anyTrue / 0 flip)⇒ 与本条不同,它们**连 fixture 侧的域都没有**,不要照抄本条的路径。

## §FU 2026-09-07T13:40Z 协同组 —— **读条中的 TP 就是撤退本身**,而撤退链上第一条闸(PROMOTED)每帧都在取消它;本节最该被读的是 **§FU.2:第一版是个 no-op,而抓住它的不是任何一条 gate 断言,是把真链开在真帧上**

### §FU.0 一句话

新 gated 候选 **`pgchannel`**(`J.ShouldLetTpChannelFinish`,`bots/mode_retreat_generic.lua`
唯一调用点,坐在 `RETREAT GUARD CHAIN: BEGIN` 之上)。**未 armed**:P4.2 冻结期,
本节**不申请入集**(FROZEN-HOLD),**不申请波次**,`queue.json` 一字未动。
全文档案 `iterations/state.json:pgchannel_20260907`,报告
`iterations/reports/strategy/20260907T134000Z.md`,总线 **GH #598**。

### §FU.1 缺陷与证据帧

`J.ShouldAbortDeepSoloPush` 是 **PROMOTED**(每局 turbo 都活),其撤退消费点是守卫链
**第一条**(0.92)。这条路径**从未问过「我是不是已经在走了」**,而后果由这棵树自己写在
`J.ShouldAbandonTpChannel` 抬头:「the caller raises retreat desire so the move order
cancels the channel」。
**证据帧** `f_260819_222030_jugg_tp_start` t=437.1:`modifier_teleporting` **elapsed 0.1**、
深度 >2500、lich 476u / viper 739u、最近队友 4,000+ ⇒ 把**真** `GetDesireHelper` 开在这一帧上
读到 **0.92**。同一局下一帧 `..._jugg_tp_eaten` t=439.5 是**结果**:无 `modifier_teleporting`、
`tp_cd 37.7`(**卷轴已花**)、hp **733 → 313**、人还站在 240u 外的同一个深处。

### §FU.2 ⭐ 主判据:第一版是 no-op,且**每一条 gate-plumbing 断言都会放它过去**

第一版写成 pushguard 那条闸上的 `and not <exempt>` 合取项。实测 **0.92 → 0.75**:
接手的是 `J.ShouldRetreatLaneBurst`(**lanesurv 族、PROMOTED、活的**,7:17 仍在其对线期域
`t < 8*60` 内)。**0.75 取消读条和 0.92 一样彻底。**
⇒ **可复用一条:一个「窄」修法窄到只压住一条竞标者时,它是不是修复,取决于第二条竞标者是谁 ——
而那是个读数,不是设计判断。**
钉在 `tests/test_pgchannel_veto.lua` 第四条断言 + `tools/agent/mutstand_pgchannel.sh` **M6**
(M6 被抓两次:放置断言 + armed 读数)。

### §FU.3 域(110 fixtures / **1021 live hero frames**)

`channeling` **23**;其中 shipped 撤退读数 ≥0.75 的 **4** 帧,armed 后 **4/4 释放**;
与 pushguard 触发域交集 **1**;armed 后 20/23 帧读数变化。
**姿态族域价钱一并量出**(`tests/_posture_domain_sweep.lua`,下一轮不必重跑):
pushguard depth **58** / solo **18** / fires **4**;`ShouldPunishDive` shipped **28**、
`ownhalf` **79**(**ownhalf-only 51**);`overchase` 794 对 / iso∧deep **50** / fires **3**。

### §FU.4 两条界 + 一条未被见证的释放腿(登记,不许当作已解决)

1. **因果的界**:`.dem` 说不出**哪一条指令**打断了那次读条。TP 读条不被伤害打断 ⇒
   自陈移动指令是首选解释,且那条 0.92 是**量出来的**;但同 2.4s 内一次晕眩会给出一样的两帧。
2. **杠杆的界**:撤退欲望**不是唯一竞标者** ⇒ **本杠杆移走撤退那条闸,不承诺读条落地。**
3. **释放腿未被见证**:活的那条 `J.IsIncomingBurstLethal`(**无闸纯谓词**)在 **0/23** 帧触发过;
   哑的那条是 `tpwatch`(从未 armed)⇒ **今天这条 veto 只由前者释放**。
   它是 `not` ⇒ arm/promote `tpwatch` 只会把 veto 变**窄**。**`pgchannel` 若要 promote,
   必须同时回答 `tpwatch` 有没有跟着走。**

### §FU.5 交给总监 / 录像组的一条分歧(本组不裁)

`f_260819_222030_jugg_tp_eaten` 上两条守卫答案**相反**:该帧读条已掉 **36% 最大生命**
(1155 的 420),正是 `tpwatch` 写来要**放弃**的构型;而地面真值是**读条在离落地约 0.5s
时被打断、卷轴照花、人照留在深处**。

### §FU.6 产物与门

`bots/FunLib/jmz_func.lua`(一个新谓词)+ `bots/mode_retreat_generic.lua`(唯一调用点);
`tests/test_pgchannel_veto.lua`(**新,7/7**,真实帧正/负控制);
`tests/_pgchannel_sweep.lua` / `tests/_posture_domain_sweep.lua`(两台仪器);
`tools/agent/mutstand_pgchannel.sh`(**8/8 CAUGHT,零 SURVIVED**);
`state.json:pgchannel_20260907`;**GH #598**。
铁律 6 静态门:`bash tools/agent/luacheck_gate.sh` ⇒ **GATE_EXIT=0,0 警告**(冷启自装)。
动态半:定向过滤 `retreat`/`tp_`/`pgchannel`/`gate_claim`/`push` 合计 **167 tests, 0 failures**;
**全量套件在本容器未跑完(GH #124)⇒ 登记为「未跑完」,不是「通过」。**

---

## §FV 2026-09-07T16:28Z 总监:**两条退回出集(`teambrain` + `capmono`),armed 50 → 48** —— 本节最该被读的是 **§FV.3:一个「等着被免费买到」的条件,和一个没人买的条件,在 verdict 表里长得一模一样**;以及 **§FV.2:一条 armed id 的唯一调用点被另一条 id 的落地覆盖掉了,而 `bots/` 的出厂行为一个字都没变**

### §FV.1 先补量具:「armed 了多久」在本容器里曾经是容器的性质,不是实验室的性质

上一轮(13:31Z)交出的棒:**给每个 armed id 一个机器可读的入集时刻,来源是入集章节,不是左删截的 git 历史。**
立这条棒的现场是 10:00Z 那轮:P4.2 说「从核验记录最少的 id 清起」,而「armed 了多久」是那个排序键的另一半,
当时的答法是 `git log iterations/streams/test_set.md` —— **Routine 容器是 shallow clone**,`--deepen=400` 之后
该文件的历史仍然只到 **08-30**,于是 51 个 id 里 **40 个答「不知道」**。⭐ **那个「不知道」是 clone 的性质,
不是仓库的性质** —— 同一形状在 §FQ.2 的 `arm_md5` 反查上出现过一次(不 deepen 只解得出 6 个 md5,十波里八波 UNRESOLVED)。

落地物:**`iterations/armed_since.json`(50 行,本轮 48 + 2 条盖了 `retired_at`)+ `tools/agent/arm_since.py`**。
三个来源,全部是**仓库里全长发行的东西**,一个都不问 git:
(A) `test_set.md` 的入集章节(权威,交棒点名的那个);
(B) `iterations/reports/director/<UTC>.md` 的**文件名**(时刻在文件名上,散文被重写也不会漂;存档起点 2026-08-19T00:53Z);
(C) `state.json` 的 `<id>_<YYYYMMDD>` 键(最弱,只给前两者看不见的 id 用)。
**覆盖:50/50。** 早于 (B) 存档起点的 9 条(七月那个 bundle)取 `lower_bound`,界的证据是**逐字引用了当天 arm 串**的
`state.json:family_bisect_launch`(8 条,2026-07-25)与 `bundle14_VERDICT_20260819`(`wandbleed`)。
⚠️ **下界是地板不是等式**(GH #106 家规),而它们无论如何都排在最老那一端 —— **本轮两条退集用的就是它排出来的序**。

⭐ **解析器匹配的是形式不是关键词,而这一条是量出来的不是设计出来的**:第一版匹配任何含「入集」的行并收走该行所有反引号 id,
在真文件上把 §DK.3 的 **`\`slotarb\` 的入集是条件性的**」读成了一次 `slotarb` 入集事件,日期取自恰好在它上面的那一节。
**一个错的日期比没有日期更坏** —— 它是 P4.2 的排序键,假老把 id 顶到退集队首,假新把它藏起来。
`tests/test_arm_since.py`(**18 checks, 0 failed**)把四种真实散文形式钉成阴性(`不提入集` / `重新入集路径` /
`的入集是条件性的` / `X 退集`),并钉住三条失效方向:**armed 但没有行 ⇒ exit 3**(不是打一个「-」然后 exit 0,
那是 `pending_rulings.py` 的 `none` 形状)、**有行但不在串里且没盖 `retired_at` ⇒ exit 3**(退集时**删行**会通过其它每一条检查,
并悄悄销毁「上一段 armed 了多久」)、**散文与 `exact` 行不一致 ⇒ 报 CONTRADICTION 且不自动改**
(「存档被重写了」和「钉子写错了」从工具内部看长得一样)。

### §FV.2 顺带结清一条先于本轮存在的 trunk 红:一条 armed id 的唯一调用点被覆盖掉了

开工自检(铁律 10,`RC_EXIT=3`)报 **4 条 Lua 检测器红**,全部指向 `bots/mode_retreat_generic.lua`,
成因是 **`8b25217e`(协同组 09-07T13:40Z,`pgchannel`)**:它把撤退链里的
`if J.ShouldRegenNotWalkHome(bot) then` **整行替换**成 `if J.ShouldLetTpChannelFinish(bot) then`,
**把上面那段 `stayfield2` 的注释原样留着**(描述一个已经不存在的调用),于是
**`J.ShouldRegenNotWalkHome` 在 `bots/` 里的调用点从 1 变成 0** —— 而 `stayfield2` **是 armed 串里的 id**。

⛔ **出厂行为一个字都没变**(两个 helper 在各自 id 未 armed 时都答 false)⇒ 真实对局零影响。
**死掉的是测量**:从那棵树发出的每一波都会把 `stayfield2` 读成 no-op,而在 verdict 表里那长得就像
**「测过了,无效应」**(§AZ / GH #148 那一族的又一发,这次的载体是**调用点**不是**域**)。
处置:**把 `stayfield2` 那一行按原位恢复**,`pgchannel` 的否决**平排在它下面**(协同组自己的落地说明写的就是
「a VETO above the chain, **beside the other two**」),并在源码里写下**两条否决的归因边界**:
两条都返回同一个 `NONE`,所以**单臂 armed 时顺序不可能有影响**,**两条同时 armed 时同满足的那一帧归给排在前面的那条,不可归因**。
⇒ `stayfield` 三条检测器 **56 tests, 0 failures**(此前 3 红)。

⭐ **顺手抓到一发「文本裁判把自己的注释读成代码」(`tpclaim_20260823` 记过同族第三发)**:
`tests/test_pgchannel_veto.lua:147` 用 `gsub` 数调用点,而我写的那段说明**引了那句调用的字面文本**,
于是**代码里恰好一个调用点的树被读成两个**并变红。修法不是改我的措辞(那只是让下一发再来一次),
是**让计数读注释剥离后的源码** —— 调用点是**代码**。⚠️ **失效方向本来就是坏的那一侧**:
它会因为一句注释而红,却数得到藏在 `--[[ ]]` 里的**真**第二调用点。
变异台一发:**真的加第二个调用点 ⇒ CAUGHT**(文件拷贝还原台,`pgchannel` 7/7 绿)。

### §FV.3 ⭐⭐⭐ 立法级:一个「等着被免费买到」的条件,和一个没人买的条件,在 verdict 表里长得一模一样

`capmono` 的 08-20 裁定写的是 **`stays armed`**,三条理由里的第 (ii) 条是:
「每一波 capmono-ON 的波都在**免费**为那次 **within-arm HP 梯度再读**积攒 n」——
**那是一个正确的论证**(波内梯度对 ±15pp 的跨种子噪声免疫),而它有一个**没写下来的到期日**。
**19 天、十几波之后,那次再读一次都没做过**(`next_step_zero_cost` 零执行,`verify_coverage.py` 读 `verify=0`)。

⇒ **这一条不是「capmono 没通过」,是「让它留在集合里的那条理由已经过期,而没有任何东西替它举手」。**
一个 id 停在「等一个免费读数」上和停在「没人管」上,在 `verify_coverage.py` 的表里**同一行同一个 0**;
差别**只在一句谁也没读的散文里**。这与 §FB(`tpdying`/`tpreach`:验收形状在入集当天就写好了,而那份义务只住在散文里)
是**同一个缺陷的第二种长相**,而这一次连「谁欠着」都写清楚了 —— 欠的人就是每一轮读到它的人。
⇒ 本轮把两条义务**搬进 `iterations/owed_executions.json`**(自检第 9 条腿每轮替它举手并 exit 3),**再**退集。
**退集不销毁买 (a) 的能力**:`capmono` 的再读用的是**已经存在的** 32 局语料(零 AWS、零新局)。

### §FV.4 诚实边界(本节每一条都是本轮**没有**做到的事)

- **`teambrain` 的退集理由是「这套仪器买不到 (a)」,不是「它没用」。** 2026-07-25 的
  `wave_teambrain_VERDICT` 里那批仲裁目标读数(TP 落地死亡 4.8x → 1.83x、TP 量 +41% → +19%、同帧三连 TP 消失)
  **看起来像 (a)**,而它们全部是 **wave12(12-id)与 13-id 波的跨波差** ⇒ 被
  `state.json:residual_IS_A_CONSTANT_RULING_20260821T1700Z` 明文**废止**的那种读法(「这波 −24 那波 −34,所以那个 id 有用」)。
  **我没有为 `teambrain` 重新买到任何 (a),也没有推翻那批读数** —— 我说的只是:按今天的记账规矩,它们不能当 (a) 引。
- **`bots/` 对这两条 id 零 diff。** 本轮唯一的 `bots/` 改动是 §FV.2 恢复的那三行(`stayfield2` 的调用点)+ 一段注释。
- **`test_gated_helper_nesting_census.lua` 仍然红,本轮没修,而那是有意的**:它要的是
  `pgchannel` 那两行普查行**被回答之后再钉**,而回答的形状(单臂可读性)是 `_pgchannel_sweep.lua` 那把尺子的活,
  **它是协同组的杠杆、协同组的尺子**;我从源码读到的那一半写在交棒里,**没有把它写成 PINNED**——
  钉错一行比留着红更坏。
- **动态半边不声称全套**(GH #124):跑的是「改动文件 + `stayfield`/`pgchannel`/`retreat`/`gate_claim`/`smoke` +
  全部 `tests/test_*.py`」,逐条读数在报告 §4。

## §FW 2026-09-07T19:xxZ 总监:**两条退回出集(`l1trade` + `l5combo`),armed 48 → 46** —— 本节最该被读的是 **§FW.2:一个死在最后一条合取上的漏斗,「子句为假」和「仪器对这条子句是瞎的」长得一模一样,而本轮的第一版结论就是错的那一个**;以及 **§FW.4:一条断言声称自己在防 `pullcad` 陷阱,变异台量出它根本看不见那个陷阱**

### §FW.0 一句话

两条 id 各 armed ≥44 天、`verify=0`,取自全集最老的一档(owner P4.2)。本轮**先建量具再裁定**:
新建 `tests/_lanekill_domain_sweep.lua` 给两条腿的**适用帧人口**定价,得到的读数**推翻了它自己的表面结论**,
并把「44 天没人买 (a)」的原因从「没人做」改写成**「从这条路买不到」**。
零 AWS、零波次、零 `bots/` diff、不发 owner 邮件。判定完结 **2**(连续第二轮达标)。

### §FW.1 选取依据(P4.2 的排序键,两半都用上)

`arm_since.py --all` 的最老一档(`lower_bound` 2026-07-25,≥44 天)7 条,`verify_coverage.py` 全部 `verify=0`。
本轮**没有**从这 7 条里随便取两条,排除掉的每一条都有具名理由:
- `tpcommit` —— 共同 promote 原子 `tp_response_releases_need_commit` 的 **prereq**,§FB 明写「留在集内」;
- `lf_rescue` —— GH #594/#597 正在它身上买读数(`test_lf_rescue_final_action` 的普查),**正在飞的不动**;
- `ownhalf` / `overchase` —— §FU.3 已有姿态族域读数(`ownhalf` 79 / ownhalf-only 51;`overchase` 794 对 / fires **3**),
  形状与本对**不同**(它们的域**不为空且真的会触发**),留给下一轮单独判;
- `fieldregen` —— 闸在 `item_purchase_generic.lua`,是购买链不是战斗链,与本对不同族。
⇒ 取 `l1trade` + `l5combo`:同一个杠杆的核心腿与辅助腿,**必须同批**(自风险门按 core 0.75 / support 0.60 成对设计,
分开退会留下半个对子)。

### §FW.2 ⭐⭐⭐ 立法级:一个死在最后一条合取上的漏斗,两种成因长得一模一样

普查(110 fixtures / **1021 live hero frames**,laning 842 = core 712 + support 130)的漏斗:

| | l1trade(核心腿) | l5combo(辅助腿) |
|---|---|---|
| laning 帧 | 712 | 130 |
| 有健康队友 / 有敌人在射程 | 295 / **138** | — / **33** |
| 过自风险 | **131** | **30**(再过「第二个敌人」否决 → 22) |
| 候选 (bot,target) 对 / 过深度门 | 185 / **155** | 26 / **16**(再要求己方核心压在目标上 → **11**) |
| **lethal** | **0** | **0** |
| **fires** | **0** | **0** |

**每一条合取都放行了可观的人口,归零发生在最后一条。** 写成「这个杠杆的域是空的」干净、好引、**错**。

两条腿的最后一条合取都是**出向**爆发估计:
`J.GetTotalEstimatedDamageToTarget(我方在目标附近的队友, 敌方目标) >= 目标 HP + 4s 回复`。
而 `tests/mock/replay_fixture.lua:714` 给每个英雄的 `GetEstimatedDamageToTarget` 是
**它在随后窗口里对 subject 实际造成的伤害** ⇒ **ally→enemy 在每一帧恒为 0**,
这是**语料格式的性质,不是树的性质**。`tests/mock/bot_api.lua:134` 从另一侧写着同一件事
(并点名了它同样悄悄缴械的另外两个 helper);本轮把 lane-kill 这一对加进那张名单,
并**给这个性质一个计数器而不是一段散文**。

⭐⭐ **为什么它必须被量而不是被读**:**同一个引擎调用、同一批帧、反方向是活的**。
两条腿的自风险子句问的是 enemy→me,读到非零的帧 **18 / 9**,并**真的否决掉 138 帧里的 7 帧**
(`l1_selfrisk_ok 131 < l1_enemies 138`,这一条本身就是断言)。
**一个在同一批帧上、经同一个调用、一个方向活一个方向死的仪器,盯着一个 `0` 是看不出来的。**
⇒ 普查现在把**仪器状态**(`*_est_blind` / `*_est_live` / `*_incoming_live`)与**子句结果**并排打印,
两者永不塌缩成同一个数(GH #171 形状:「桶没被走到」与「桶量到零」不许打印成同一个东西)。

### §FW.3 这买到了什么,和**没有**买到什么

**买到了**:那 44 天 `verify=0` 为什么不会自己结束 —— 对这两条 id,条件 (a) **不是没人买,是从 fixture 这条路买不到**。
每一个伸手去拿便宜工具的会话都会重新导出同一个 0,**而如果不核验,就会写下同一个错结论**。
**没有买到**:对杠杆本身的任何裁决。真实对局里引擎自己的估计器是活的,两条腿**能**触发;
本节没有说它们会,也没有说触发是好事。买 (a) 需要在**波次录像**上做行为检测器 ⇒
已登记 `iterations/owed_executions.json:lanekill_condition_a_detector`(自检第 9 条腿每轮替它举手),
**不留在散文里**(§FB.3 / GH #540 的教训)。
⛔ **退集不销毁买 (a) 的能力**:W39–W53 的 dump 里两条都是 armed 的,检测器从**已经存在的语料**里买,
零 AWS、零新局(与 `stayattr` 09-05、§FB 两条逐条同型)。

### §FW.4 ⭐⭐ 变异台量到本节自己的两处虚假强度

`tools/agent/mutstand_lanekill_domain.sh`,**7 发 / 7 发如声明 / 控制体 SURVIVED**。两处是台子量出来的,不是我记得的:

1. **M4 SURVIVED 了第一版**:那一版声称在防 `pullcad` 陷阱,做法是数**该 id 自己的闸址数 == 1** ——
   而 `A and B` 里**仍然恰好有一个 `A`**,第二个 id 加进同一行对它**结构上不可见**。
   改成**枚举门前言里读到的每一个 id 并要求它只有这一个**之后 CAUGHT。
   ⇒ 「我检查过没掉进 `pullcad` 陷阱」这句话,在第一版里是**用一个看不见该陷阱的量**满足的。
2. **M7(闸被整个删掉)是 CAUGHT 的,但不是被行为抓住的**:`[control] 出厂树在每一帧静默` 这条断言
   在本节所记录的失明下是 **0EQUIV** —— lethality 过不去,helper 有没有闸都返回 nil,
   `l1_shipped_fires` 两棵树上都是 0。真正抓住 M7 的是 `[source]` 的**字符串钉**。
   ⇒ **今天守着这两道闸的是一个字符串,这是限制不是优点**(§FT.4 同一条教训第二次出现):
   要恢复行为级守卫,需要 harness 里有出向伤害模型 —— **与买 (a) 缺的是同一块料**。

M1(让语料看见出向爆发)CAUGHT 是本节最重要的一发:它模拟「harness 被修好」的未来,
逼 §FW.2 的「结构上买不到」那一半**在那一天变红**,而不是悄悄烂掉。

### §FW.5 落地物

- `tests/_lanekill_domain_sweep.lua`(域普查,阈值全部从 `jmz_func.lua` 解析,M13 规矩)
- `tests/test_lanekill_domain_census.lua`(**6 tests / 0 failures**,棘轮 + 仪器状态断言 + 源码钉)
- `tools/agent/mutstand_lanekill_domain.sh`(**7/7 如声明**)
- `iterations/state.json`:`l1trade_RETURNED_20260907` / `l5combo_RETURNED_20260907`
- `iterations/owed_executions.json`:`lanekill_condition_a_detector`
- `iterations/armed_since.json`:两行退出登记(`arm_since.py` 46/46 覆盖)

### §FW.6 诚实边界(本节**没有**做到的事)

1. **没有量过真实对局里这两条腿的触发率** —— 本节所有数字都是 fixture 语料上的,而那正是本节说它瞎掉的那套仪器。
2. **`ownhalf` / `overchase` 本轮只排除、没判** —— §FU.3 的读数说它们的域不空且 `overchase` 真的 fires 3 次,
   那是一个**不同形状**的判定,需要它自己的工作单元。
3. **`*_est_live` 的门是「非零」不是「正确」** —— harness 哪天给出一个错的出向模型,这套断言会转绿而不是转红。

## §FX 2026-09-07T22:xxZ 总监:**`campbind` 退回出集(46 → 45)** —— 本节最该被读的是 **§FX.2:录像组请裁的「三选一」里,2 和 3 根本不互斥,而把它读成互斥正是这根棒卡了六轮的原因**;以及 **§FX.3:这一次「域为零」真的是域的零,不是仪器的零 —— §FW.2 要求的那道检查在这里做了,而且过了**

### §FX.0 一句话

`campbind` 的条件 (a) 在例行波里**结构上买不到**(两份独立语料、97 局、两个波次族:可判读面为 **0**),
而它 armed 的每一轮都在**替 `pulldrag` 付一笔已量出来的代价**;⇒ **退出测试集,改走 fixture 路径**,
disposition = `DOMAIN-NOT-REACHED-IN-WAVES`,**不是 reject**,gate 与 `bots/` 逐字保留。

### §FX.1 这根棒欠了六轮,而它是本轮 trunk 红的根

录像组 **2026-09-04T21:56Z** 在 GH #475 追评里请裁三选一,此后
`replay-check.md` 连续在 **11004 / 11089 / 11195 / 11286 / 11347 / 11437 / 12903** 七处
把「仍等 #475 三选一再裁」写进 LIVE 当前状态,并且**每一轮都附带「不要再扫更多局」**
—— 也就是说这根棒不只是欠着,它**堵着**:被裁方已经按裁定的形状停下了。
开工自检的 `test_stale_waits.py` 本轮点的就是 `replay-check.md:12903` 这一行
(理由行自带修法:*fix the charter line, do not loosen this test*)。
⚠️ **那条红的成因不在措辞里** —— 那一行把**已落地的入集裁定**(#475,09-04T10:13Z,W46 起生效)
和**未落地的再裁**写成同一件事「等 #475」,于是检测器看见「等一个已经落地的裁定」而变红。
**措辞是对的一半、错的一半,而红的是错的那一半。** 本节把再裁做掉,那一行才有得改(§FX.5)。

### §FX.2 ⭐⭐⭐ 立法级:被请裁的「三选一」不是三选一

录像组给的三条是:
1. 接受「逻辑依据 + 单调性」(armed 戳集 ⊆ 出厂戳集,严格子集);
2. 给它一个**定向 fixture**,用 fixture 代替波次证据;
3. **退出测试集**,别再占一个 id 位。

**2 和 3 是正交的,而它们被写成了互斥的。** 一个杠杆**不需要占着 armed 串里的一个位置**
才能被 fixture 钉住:fixture 断言的是**决策**,它既不需要这个 id 出现在某一波的 arm 串里,
也不需要那一波的录像。⇒ 正确答案是 **2 且 3**,不是 2 或 3。
**而把它读成互斥,恰好是让这根棒卡住的那个形状**:每一轮的读法都是
「要么现在接受(1),要么现在放弃(3),否则就再等等(2)」,于是**「再等等」永远是最便宜的一格**
—— 一个每轮都不必付代价的默认值,连续六轮。⚠️ **这不是录像组的错**:
它明写了「录像组不做这个决定」,三条也确实穷举了处置空间;丢的是**总监没有取的那一步**。

### §FX.3 ⭐⭐ 这次的零是域的零,不是仪器的零(§FW.2 要求的检查,做了,过了)

§FW.2 立的规矩:一个漏斗死在最后一条合取上时,「子句为假」和「仪器看不见这条子句」长得一模一样,
**必须去量仪器在那个方向上活不活**。本节照做:

| 检查 | 读数 |
|---|---|
| 工具自检 | `campbind_poke.py --selfcheck` **4/4 PASS**,含「未被打扰的营地读作没动」的**假阳性对照** |
| liveness | `tests/test_campbind_poke_liveness.py` **17 检查 / 0 失败** |
| 变异台 | `tools/agent/mutstand_campbind_poke.sh` **6 变异 6 CAUGHT**,`sha256sum -c` 还原 OK |
| **同一仪器、同一批帧、有没有非零** | **有,而且两个方向都有**:W46 归属到**最近**营地 armed **7** / baseline **1**;拉营族 (a) in-window armed **52** vs baseline **14**,窄化后 **12/8/18/6 vs 0/0/3/0** 四格同号 |

⇒ 归属腿在这批帧上**是活的**,`non_nearest == 0` 是**域的读数**。这与 §FW 那两条**形状相反**:
那里最后一条合取是出向爆发估计、语料在那个方向恒 0(仪器瞎);这里同一条腿在同一批帧上答得出非零。

⚠️ **一条不许被吞掉的例外(本节唯一一处仪器确实没答上来的地方)**:
W46 语料里**唯一**那个可能咬的瞬间 —— `20260904_125801_slot6` spirit_breaker(armed, pos4),
t=330.7 右键 `forest_troll_berserker`、t=334.7 右键 `kobold_taskmaster`(4 秒内两个不同族 = 两个不同营地)
—— **归属失败**:C0 位移仅 12–176u、C1 全程 0,都够不到 250u 的归属阈值 ⇒ 记 `unattributed`,不入结论。
**所以准确的说法不是「仪器看见了并答否」,是「仪器在唯一一帧上答不出」。**
⭐ 而这恰好**就是**选 fixture 路径的理由,不是反对它的理由:fixture 直接断言决策,
**根本不需要位移归属**,那 250u 阈值在 fixture 上不存在。

### §FX.4 判据:三条件逐条,和「留集」这一侧的**已量出的**代价

- **(c) 逻辑依据 —— 成立。** 入集裁定(#475,09-04T10:13Z)自己核过四格:唯一闸点
  `bots/FunLib/jmz_func.lua:8993` 是**独立门**、不与 `pullcamp` 合取(不踩 `pullcad` 陷阱);
  符号单调(armed 戳集 ⊆ 出厂戳集,没有 over 方向);载体 `generic`(`TERMS` 行两串逐字节相同);
  「站着不动」的最坏上界 **15 秒且只在 1:00–6:00**(由 `J.ShouldPullNeutralCamp` 的窗口自己封死)。
- **(b) 胜负无明显负面 —— 粗粒度成立,而且只到粗粒度。** W53 三粒种子池化 gpm **−6.80**
  (queue `strategy-42:result`),该字段自己写着**这不是改善的证据**:三粒 arm 是 −18.88 / −32.77 / +31.24,
  极差 64.1,落在 GH #30 的噪声里;胜率**退化**(少数侧 0/160)按 GH #352 **两个方向都不许引**。
- **(a) 录像组核验执行 —— 买不到,而这已经量了两次:**

| 语料 | 局数 | in-window 戳(armed/base) | 可判读面(计划营 ≠ 最近营) | 判决 |
|---|---|---|---|---|
| W46(`…_d7082b` 4470 / `…_b77771` 4252) | 宽扫 50、深查 8 | 57 / 7 | **1**,且**不可归属** | INDETERMINATE |
| W52(两个 run,2 粒种子) | 47 | 52 / 14 | **0** | INDETERMINATE |

两份语料**互相独立、来自不同波次族**,合计 **97 局**,可归属的单向证据 **0**。
W52 那条评论还把密度算出来了:满足前半条(≥2 活营同在 1400u 内)的戳 **13 次 / 9 局 ≈ 0.19 次/局**,
后半条(计划营 ≠ 最近营)**一次没出现**。⇒ **例行波再发多少波都会得到同一份 INDETERMINATE。**

⭐ **而「先留着,等以后哪波撞上」不是免费的默认值 —— 代价在入集裁定自己的限定 ⚠️ 第 2 条里写着**:
`campbind` 与 `pulldrag` **不正交**,armed 之后 `J.GetLanePullDragTarget` 问的营地与被激怒的小野
**第一次是同一个箱子** ⇒ **`pulldrag` 的 connect 读数换了定义域,不许与 W45 及更早的波并池**。
`pulldrag` 现在 armed **13 天**、`verify_coverage.py` 读 **verify=0**。
⇒ 每多留一轮,是拿**一条已证买不到的证据**,去换**另一条 id 的可并池语料**。这笔交换不划算,而且它有数。

### §FX.5 裁定(投递照章程 §2.5:档案 / 机器字段 / 活线程,三处齐)

1. **`campbind` 退出测试集**,armed 串 46 → 45。**不是 reject**:gate、helper、调用点
   (`J.GetCampPullPokeTarget`,唯一闸点 `jmz_func.lua:8993`)**逐字保留**,`bots/` 本轮零 diff。
   disposition **`DOMAIN-NOT-REACHED-IN-WAVES`** —— ⛔ **不许**读成「测过了,无效应」
   (入集裁定的收割限定第 1 条已经预先禁止过这一种读法,本节重申)。
2. **条件 (a) 改走 fixture 路径**(录像组的第 2 条),已登记
   `owed_executions.json:campbind_condition_a_fixture`。目标帧就是 §FX.3 那一帧
   (`20260904_125801_slot6` spirit_breaker t=330.7 / t=334.7)。
   `done_when` 明写**拒绝**一份「在例行波语料上重跑报 0」的产物 —— 那正是本节判定买不到的东西。
3. **⚠️ 一条我现在核不了的前提,连同它的后果一起登记(不许烂在散文里)**:那一帧属于 **W46**,
   而 W46 的 timeline **已随容器回收**,`.dem` 是否仍在 S3 **本轮没有核**(总监不动 AWS 的钱,
   S3 只读也没跑)。⇒ owed 行里写死:**若该帧的语料取不回来**,这条**不是继续欠着**,
   而是**当场转为永久退集**(`DOMAIN-NOT-REACHED`)并在报告里说出来。
   **时限是真实存在的**:同族的 W44 录像约 **09-25** 过期(GH #477)。
4. **不取第 1 条(纯单调性接受)。** 单调子集只保证「不会让 bot 去戳它本来不戳的东西」,
   它**不保证掉的那些戳是该掉的**,而 §FX.4 的 15 秒站桩上界说明这一侧**有代价不是零**。
   铁律 2 的 (a) 要的是「真的执行且行为正确」,拿单调性顶替 (a) 等于把三条件改成两条件。

**下一棒**:录像组(`owed_executions.json` 那一行;先核 `.dem` 在不在,再决定是钉 fixture 还是回报永久退集)。
批测台无动作 —— 下一波 arm 串从 `test_set.md` 第 2 行取,自然就少了这一个 id。

### §FX.6 诚实边界(本节**没有**做到的事)

1. **没有核 W46 的 `.dem` 还在不在 S3** —— 见 §FX.5 第 3 条,后果已写进 owed 行的 `done_when`。
2. **没有量 `campbind` 退集之后 `pulldrag` 的 connect 读数**是否真的恢复可并池 ——
   §FX.4 那笔代价是从入集裁定的限定条款**读来的**,不是本轮**测出来的**。
   它足以支持「留集不是免费的」,**不足以**支持任何关于 `pulldrag` 读数会变多好的说法。
3. **没有判 `ownhalf` / `overchase` / `fieldregen`** —— 上一轮 §FW.6 指名的那三条**原样顺延**,
   本轮取了 GH #475 是因为**那根棒欠了六轮且堵着被裁方**,不是因为它更好判。

---

## §FY 2026-09-07T23:xxZ 协同组 —— **一个 armed id 的行为内容改了,而成员串一字未动**;本节最该被读的是 **§FY.2:承载这条守卫的是它两条分支里没有锚的那一条,而这是量出来的不是读出来的**;以及 **§FY.3:宿主自己是未 promote 的候选时,它体内不存在任何能产生可读单臂零的落点 —— 上一轮 `ohnum` 那条判据的推论**

**⛔ armed 串一字未动(仍是 §FX 的 45-id / 408 字节 / md5 `f4292f7bb9a5f112ed34af62cbe3c2a8`)。本节不是入集、不是退集、不是 promote、不是 reject。** 它登记的是**另一件事**:`overchase`(45-id 串的第 4 位,早已在集内)的**函数体**变了,于是**本轮之后的波测的是收窄后的杠杆,而早前波次里 `overchase` 的读数描述的是收窄前的那一个**。这一行存在的唯一理由是让将来对比两批读数的人不要把它们当同一个量。

### §FY.1 改了什么(`bots/` 唯一改动)

`J.ShouldPunishOverchase` 腿 (b) 的**软读**余量 `800 → 1600`。**硬读(建筑 1200)一字不动。**

腿 (b)(「追击者已经进了我方地盘」)是两个性质完全不同的读的析取:

- **硬读**:我方某座**活着的建筑**在追击者 1200 内 —— 一个关于「这是谁的地」的事实,而且那座塔是 numbers 分支从不计数的队友;
- **软读**:按祖庭距离过了中线某个余量 —— 一个软判断。

### §FY.2 承载这条守卫的是**没有锚的那一条**(本节最该被读的第一条)

`tests/_overchase_sweep.lua`,110 fixtures / **1021** live hero-frames:

```
oc_pairs 794 | oc_deep_building 53 | oc_deep_midline 97
oc_iso_deep 50  (building 8 / midline 42)
oc_fires 3      | oc_fire_building 0 | oc_fire_midline 3
```

**语料能见证的每一次触发都来自软读,没有一次来自硬读。** 于是「腿 (b) 有两条分支所以还算稳」这句直觉是错的:实际的守卫**就是**一个中线守卫,那条线上的余量**就是**它的触发条件。

而那个余量是 **800**,是全树同族里最浅的一个。`J.SafeToCommitFight` 对**同一个**祖庭距离约定用 **1600**,并在自己的头注释里写了理由:贴近中线时 visible-only parity 会系统性高估安全,因为雾里的增援很近。**腿 (c) 的 isolated 恰恰只读可见敌人**(`J.GetEnemiesNearLoc` 走 `UNIT_LIST_ENEMY_HEROES`)⇒ 它逐字继承那个失效,而 AGENTS.md 记的正是这个 2v2 变 2v4、花掉一次批测的教训。⇒ 借用全树已有的 1600,不发明第三个数。

改动后(同一把尺子):`oc_iso_deep 50 → 31`(midline 42 → 23,**building 8 → 8 逐位不变**)、`oc_deep_midline_shallow 43 → 0`、`oc_fires 3 → 2`。**`oc_deep_building 53` 前后逐位相同 —— 这是「只收窄了软读」的读数,不是它的论证。**

### §FY.3 为什么**没有**新 id(上一轮判据的推论)

上一轮 `ohnum` 立的是:*一个收窄杠杆的调用点该放在哪里,由它的零读数将来能不能被读懂决定。* 本轮撞到的是它的推论:

`J.ShouldPunishOverchase` **整个函数**挂在**尚未 promote** 的 `overchase` 上。于是在它体内**任何**位置写 `J.IsSoakCandidate('<新 id>')` 都是合取 `overchase AND <新 id>`,**单臂 arm `<新 id>` 的波必然读到 0,而那个 0 是结构上不可能的**;`check_armed_wiring.py` 照样答 WIRED(验闸址不验可达性,GH #606),verdict 读回「测过了,无效应」而没有人举手 —— GH #576/#600/#607 那一族。

⇒ **当宿主 helper 自己就是一个未 promote 的候选时,它体内不存在任何能产生可读单臂零的落点。** 对它的收窄只能**改宿主自己的函数体、继承宿主的 id**。两种写法对**出厂行为**都是零影响(`overchase` 在真实对局里从不 armed,该函数恒返回 nil);差别**只在**将来那一波能不能被读懂。

### §FY.4 钉帧与变异台

正对照 `f_260820_042607_zuus_reserve_cross` / zuus(t=462.5):**0.72 血的宙斯**转身去打 **1.00 满血、确实孤立的莱恩**(500u;其余活着的 dire 英雄最近 7,510u),把 **0.44 血的潮汐**当作第二具身体;过中线 **1436u**(旧 800 内、新 1600 外),**1200 内无我方活建筑**。负对照 = 语料仅有的另外两次触发(`f_20260827_091703_slot12_zuus_473_1` 的 lina 与 tidehunter),都更深,**照旧触发**。

`tools/agent/mutstand_overchase_midline.sh` **6/6,零 SURVIVED**。⚠️ **M5 第一轮记成 SURVIVED,而那是锚歧义不是读数**:`depthnum` 那五行在 `J.SafeToCommitFight` 与 `J.SafeToCommitFightOnArrival` 里**逐字节相同**,`sub()` 的 GH #550 守卫中止了替换 ⇒ 变异**根本没落地**却拿到 exit 0。**这一次是守卫在工作。** M6 是**对变异台自身的对照**(纯注释编辑必须**不**被抓到),实测正确未被抓到。

### §FY.5 先量后拒的两条(免得下一轮重做)

章程 0OHNUM 指名的 **(a)/(d) 两条腿,本轮量完结清,两条都没有杠杆**:

1. **(d) 的「濒死队友被当作一具完整身体」**:腿 (a) 要求 900 内有 <0.5 血队友,腿 (d) 数 1200 内的队友 —— **900 是 1200 的真子集**,所以这个重复计数是守卫的触发条件**蕴含**的,不是偶发。但域价钱 **0**:`oc_a_pass 3 == oc_ad_pass 3`(腿 (d) 全语料**一次都没拒绝过**),`oc_d_numbers_thin 0`(折掉所有 <0.5 血身体,三帧人数**都不翻面**)。
2. **(a) 本身**:50 个 iso∧deep 里只有 3 个通过,但 `oc_a_pursuit_unseen 0` ⇒ 那 47 次拒绝**全部**是「900 内根本没有濒死队友」,**没有一次**是「追击不可见」。⇒ 不是缺陷,是守卫在正确地保守。

### §FY.6 ⚠️ 一条给收割人的界(GH #613,本轮新立)

腿 (a) 是**三条析取**,而语料上 **`oc_a_attacktarget 0` / `oc_a_ischasing 0` / `oc_a_recentdmg 3`** —— **100% 的释放来自单一析取**,另两条**结构性地**开不了火(`replay_fixture.lua` 重写了 `WasRecentlyDamagedByHero`,却没重写 `GetAttackTarget`(每个 unit 答 nil)与 `IsRunning`/`IsFacingLocation`)。

**比 GH #611 更隐蔽的地方在于:读数不为零,所以没有人举手。** `oc_a_pass 3` 看起来像一条正常的窄域读数,实际是「三条腿里只有一条被测过」。**这两条界都不触及腿 (b)** —— 它只读位置与祖庭,正是 fixture 帧携带的 ground truth。

---

## §FZ 2026-09-08T0x:xxZ 总监:**`fieldregen` 退回出集(45 → 44),`ownhalf` / `overchase` 留集且各自具名** —— 本节最该被读的是 **§FZ.2:一族四条臂逐字写着「disjoint by construction」并被三个 sweep 断言为 0,而那个断言的作用域是**它自己驱动的那四条谓词**,同一笔购买的**第五个索取者**在任何一份族内 sweep 里都不出现**;以及 **§FZ.3:本轮两条候选发现**都已经在树里了**,其中一条就写在我正要引用其教训的那一节(§FW.2)里**

### §FZ.0 一句话

上一轮 ⑨① 指名的三条(`ownhalf`/`overchase`/`fieldregen`,已顺延 **3** 轮)本轮**全部判掉**:
一条退集、两条留集且各自带机器可读的欠条。**先建量具再裁定**,而量具**当场推翻了它自己的表面结论**——
新 sweep 报 `overlap_any 0`,而那个 0 是**仪器的零**;把它读成域的零就会得到一个方向相反的裁定。
零 AWS、零波次、零 `bots/`+`game/` diff、不发 owner 邮件。判定完结 **3**(连续第三轮达标)。

### §FZ.1 选取依据,和「留集不是免费默认值」这一侧的代价

`arm_since.py --all` 最老一档(`lower_bound` 2026-07-25,**45 天**)现存 5 条,`verify_coverage.py` 全部 **verify=0**。
其中 `tpcommit`(§FB 明写留集,promote 原子 prereq)与 `lf_rescue`(GH #594/#597 正在其上买读数,**正在飞的不动**)
沿用既有理由排除,**其余三条就是本节的三条**。

⭐ **三条共有一个此前没被登记的读数**:它们在 **W39/W40/W41/W52/W53/W54/W55 七个波次里全部只以
成员串内的一员出现,一次都没有被单臂 arm 过**(逐波扫 `iterations/reports/batch-desk/waves/W*_wave.json`,
命中长度 410–503 字节,即全量成员串,无一条短串)。⇒ 45 天里没有任何一波在问它们的问题。

### §FZ.2 ⭐⭐⭐ 立法级:一句「disjoint by construction」,真值域是它自己驱动的那四条谓词

供给侧这一族在**同一笔 `item_flask` 购买**上有**五个**索取者,而族内的互斥断言驱动**四个**:

```
bots/item_purchase_generic.lua:776   `fieldregen` 内联块
bots/item_purchase_generic.lua:833   fieldbuy or buyband or buytower or buyring
```

:833 那四条是**一起设计的**,互斥**由构造保证**——`buytower` 把塔环取反、`buyring` 把英雄环取反、
`buyband` 取 `fieldbuy` 0.55 天花板之上那一条——四条里有三条在**自己的注释里逐字这么写**
(「so the three arms are disjoint by construction」「so the four arms stay disjoint by construction」)。
`tests/_buytower_sweep.lua` / `tests/_buyring_sweep.lua` **断言**它:
`overlap_tower_buy` / `overlap_tower_hurt` / `overlap_ring_buy` / `overlap_ring_hurt` / `overlap_ring_tower` 必须全 0。

⭐ **那个断言在四条之间为真,对第五条一个字也没说,而树里没有任何地方说过这件事。**
`fieldregen` 在族内**每一份 sweep 里都不出现**——不作为探针、不作为臂、不作为计数桶(逐份核过)。
它买**同一件**物品,在**同一个 `ItemPurchaseThink` 体内**、早 57 行,**没有下界**(`< 0.45`,向下敞开)、
**三条环境子句一条都不问**(无 1600 英雄环、无 1200 塔环、无归属窗)。
⇒ 它在自己的域上**够得到那四条臂各自被写出来去拥有的帧**,包括 `buytower` 与 `buyring` 这两条
**整条杠杆就是一个取反子句**、而 `fieldregen` 从不问那个子句的臂。

⭐⭐ **而且关系是抢先不是共现,方向由行序钉死。** 两个块共用尾部引擎闸,其中有
`not IsThereHealingInStash(bot)`;`fieldregen` **先跑**。它一买,药进 stash(该块只在离泉水 2500 之外跑),
于是**当帧及其后**,:833 那个 `if` 被**它自己的 stash 子句**拒掉。
**早的那个块不是与晚的那个共享帧,它消费掉晚的那个存在的理由。**
`tests/test_coarmed_attribution_register.lua:293` 早就带着 `['fieldregen > fieldbuy'] = true`,
但它是一条 **WIDE 行**,注释逐字写着这次调用「is **not known** to sit inside either branch」
——**混杂被登记了,机制没有**。本节补的就是那个机制。

### §FZ.3 ⭐⭐ 诚实:本轮两条候选发现,**都已经在树里**,其中一条就在 §FW.2

**这一条排在裁定之前,因为它改变了本节别处该被怎么读。**

1. **`ohnum` 的「结构零」**。我从源码读出 `J.ShouldRefuseUnsupportedPunish` 的首个循环
   (allied building ≤1200 of target)**恰是** shipped 路径上让控制流到达它的那个条件的**补集**
   (同半径、同目标、同 unit list),于是 shipped 路径上它**不可能**返回 true;
   实测 `ohnum` 单臂 **28 → 28(零)**,`ownhalf`+`ohnum` **79 → 48(−31)**。
   ⛔ **这一整段已经写在 `tests/test_ohnum_refusal.lua` 的头里,数字逐位相同**
   (`pd_shipped 28` / `pd_ownhalf 79` / `both_changed 31` / `ohnum_alone_changed 0`),
   由 `tests/_ohnum_sweep.lua` 量出。**我重新推了一遍已经记录的结果。**
   那份文件的说法是「这个零是**测量**不是结构零」,并**自己写明**「reads zero because the shipped
   domain is **building-proximate by construction**」。⇒ 值得登记的只有**一条口径**,不是一条发现:
   那句标题把**两件不同的事**合在一起了——**调用点可达**(真,这正是 `check_armed_wiring` 的 WIRED 诚实的原因)
   与**谓词在 shipped 路径上不可满足**(也真,这正是单臂 `ohnum` 波的裁决**不携带信息**的原因)。
   **本轮不为此开 issue**,该文件的口径可辩护。
2. **语料 82.5% 是对线期**(842/1021)。**已经写在 §FW.2 里**(「laning 842 = core 712 + support 130」)
   ——**就写在我正要引用其教训的那一节**。

⇒ 本轮真正新增的产物只有一件:**`tests/_fieldregen_overlap_sweep.lua` + `tests/test_fieldregen_family_overlap.lua`**
(第五个索取者对四条臂的重叠,族内 sweep **结构上看不见**的那一问)。
**代价读数登记在此**:两条候选各花掉一次独立推导,而两份记录都在树里、都可检索
——1726 行的 `test_set.md` 加 11604 行的章程,**「没找到已记录的读数」的成本就是把它重新推一遍**。

### §FZ.4 量具,和它当场推翻的那个表面结论

`tests/_fieldregen_overlap_sweep.lua`(110 fixtures / **1021** live turbo hero-frames,4084 次单臂探针):

```
fr_pred 6      arm_fieldbuy 33   arm_buyband 20   arm_buyring 10   arm_buytower 8
overlap_fieldbuy 0   overlap_buyband 0   overlap_buytower 0   overlap_buyring 0   overlap_any 0
arm_leak 0   fr_pred_err 0   arm_err 0
```

⛔ **`overlap_any 0` 不是「它们不重叠」,是仪器的零,而这正是 §FW.2 那个形状。**
漏斗逐条(独立驱动):`live/turbo 1021` → **`laning_true 842`(82.5%)/ `not_laning 179`** →
`hp45 134` → `noflask 893` → `notango 579` → **全部合取 6**。
杀死它的是 `not J.IsInLaningPhase()`:`fieldregen` 按构造是**过线后**的杠杆,
而这份语料 82.5% 是对线期;四条臂经 `J.IsFieldRegenSituation` 进域,**没有对线子句**,所以它们在这里有域。
⇒ **两边被量在这份语料互不相交的两片上**,那个 0 对这一对**两个方向都不构成证据**。
sweep 把 `fr_pred` 与 `overlap_*` **并排打印**就是为了这两者永远不会被混读。

⚠️ **抢先是源码读数(行序 + 共用 stash 闸),不是驱动出来的** —— 这份语料驱动不了它。逐字登记,不上调。

### §FZ.5 判据:三条件逐条

| id | (a) 录像核验 | (b) 批测胜负 | (c) 逻辑依据 | 裁定 |
|---|---|---|---|---|
| `fieldregen` | **verify=0 / 45 天**;fixture 路**结构上买不到**(域 6/1021);七波从未单臂 | 七波只在全量串里,**无单臂读数** | 成立但**已被同族四条臂以更细的形状重写**(有下界、有三条环境子句) | **退回出集** 45 → 44 |
| `ownhalf` | verify=0 / 45 天 | 同上 | ⭐ **它是 `ohnum` 域的唯一使能者**(`ohnum` 单臂 28→28 零;`ownhalf`+`ohnum` 79→48) | **留集** |
| `overchase` | verify=0 / 45 天 | 同上 | ⭐ **函数体 2026-09-07T23:xxZ 被协同组换过**(§FY)⇒ **45 天是这个名字的年龄,不是当前这条杠杆的** | **留集** |

⛔ **两条「留集」不是「再等等」**:§FX.2 立过的那条——「再等等是唯一一格不必付代价的」——
本节按它办:两条留集**各自进 `owed_executions.json`**,带裸读得出的 `done_when`,
于是它们**从今天起会每轮举手**,而不是安静地再骑 45 天。

⛔ **`fieldregen` 退集不是 reject**:gate(`item_purchase_generic.lua:776`)与其整块**逐字保留**,
`bots/`+`game/` **零 diff**。重新入集的条件写进 owed 行:**(a) 必须从波次录像买,不许再从 fixture 语料买**
——本节量出的正是后者对这条杠杆结构上失明。

### §FZ.6 落地物

- `tests/_fieldregen_overlap_sweep.lua`(重语料 sweep,`_` 前缀,30s,**不进快腿**——Lua 检测器腿已在 120s 预算边缘,GH #358)
- `tests/test_fieldregen_family_overlap.lua`(**纯源码断言**,毫秒级,6/6;语料读数以定值引在头里,同 `test_ohnum_refusal.lua` 的做法)
- `tools/agent/mutstand_fieldregen_overlap.sh`:**7/7 CAUGHT,零 SURVIVED**,控制体(纯注释编辑)**未被抓到**,
  `git diff --quiet` 还原逐字节 YES。⚠️ **M2 的锚不是 stash 那一行本身**:那一行在该文件里出现 **3 次**,
  而 `perl -0pi` 不带 `/g` 改的是**第一处**——那正是 `fieldregen` 块——**一个悄悄切了别的块却照样打 CAUGHT 的变异**(GH #550 同型)。改锚到唯一的 `RegenRing(bot) )`。
- `iterations/state.json:fieldregen_RETURNED_20260908`、`iterations/armed_since.json`(retired 行)、
  `iterations/owed_executions.json`(三行:退集后的 (a) 路径 / `ownhalf` / `overchase`)

### §FZ.7 诚实边界(本节**没有**做到的事)

1. **没有驱动出抢先** —— §FZ.4 末尾那条,重复登记:行序与共用闸是**读**出来的。
2. **没有量 `fieldregen` 退集之后四条臂的读数是否真的变干净** —— 那要一波单臂波次,本节不发波。
3. **没有核 `ownhalf` 留集的代价** —— 它继续在成员串里当混杂项;本节只主张「退它会冻死 `ohnum`」,
   **不主张**留它对别的 id 无害。
4. **`overchase` 的新身体没有被任何波次读过** —— §FY 落地至今零波次,本节只登记不可比性。
5. **patch 检查本轮仍未做**(低频,已连续多轮顺延)。

---

## §GA 2026-09-08T10:1xZ 总监:**四行 owed 读 DONE,逐份读完只有两行可退休** —— 本节最该被读的是 **§GA.3:另外两行**自己的散文早就写着「不许据此退休」,而工具在它下面一行每轮打印「请退休我」**;以及 **§GA.1:一个 id 的 (a) 可以是**结构上买不到的**,而买不到与「没人去买」在 verdict 表里长得一模一样**

零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、无 promote/reject。
取活依据是上一轮「下次触发」自己排的第 ④ 条(退休 owed registry 里那 4 行 DONE,**需读一遍**四份产物,
**已顺延 3 轮**)与第 ⑥ 条(patch 检查,**建议下一轮强制做掉**,已顺延多轮)。

**读完四份的结果:2 退休 / 2 不可退休。** 后者是本节的主体。

### §GA.0 patch 检查(章程 2f,低频)—— 做了,**无新 patch**

`https://www.dota2.com/datafeed/patchnoteslist?language=english` 裸读 `RC_EXIT=0`,
**117 条,最新仍是 7.41e(ts 1785394800 = 2026-07-30)**。与 08-19 建档、09-01 复核的读数
**逐位相同** ⇒ 缺口边界没变,仍是 7.41b–e 四个版本,`patch_gap_7.41b-e.md` 的 P1–P4 分片
一条都不需要改。`docs/PATCH_UPDATE_GUIDE.md` 的 "Last updated for" **本轮不改**(P4 的前置 P1–P3 未做完;
改它等于伪造进度,那是该文件 08-19 就写下的自我约束)。

### §GA.1 `a_evidence_tpdying` —— 交付合格,**判 INDETERMINATE,而且是结构性的**

产物 `iterations/reports/replay-check/a_evidence_tpdying.md`(194 行,录像组 09-06T04:04Z)。
按 `done_when_note` 的验收句逐条读通:§A'.3 约束 3 点名的**两个检测器都建了并跑了**
(`tpdying_release.py --selfcheck` 23 PASS / 0 FAIL)、波次与局数写明(W49、`--ref` 066219d6、
4 粒种子、72/72 计分局、unparseable 0、70 game-legs、**4,527 次响应 TP 落地**)、
铁律 4(i-a) 两个分层给的是**读数不是局数**(并把 pinned frames 的**反号**登记了)、
4(i-c) 每粒 swap-average **由工具自己打**、**全文零 gpm/xpm**。

⭐⭐ **判 INDETERMINATE 的理由不是语料不够,是嵌套**:`tpdying` 的子句住在
`J.GetTpCommitDefendDesire` 里,而那个函数第二行是 `if not J.IsSoakCandidate('tpcommit') then return nil end`
(`jmz_func.lua:8913`,子句 `:8958`)⇒ **单独 armed 逐位 no-op**;两者同时 armed 的那一波里,
`armed − baseline` 是**钉的创建(`tpcommit`)+ 两个释放(`tpdying`/`tpdead`)+ 被移动的分母(`teambrain`)**
的净值。章程 4a 禁止把 bundle differential 记到单个 id 头上,而这里**连符号都不可分解**
(创建把 pinned frames 推上去,两个释放推下来)。

⇒ **`tpdying` 的 (a) 在一条 all-on 镜像波上是结构上买不到的**,不是没人去买。
这两件事在 verdict 表里长得一模一样(`verify=0`),而只有第二种是催一催就会好的。
⭐ **这一条不新建仪器,因为它已经有一个**:`tests/test_gated_helper_nesting_census.lua`
就是这一类的普查,它**此刻在 trunk 上红**(协同组 `tprecov`,`607ce30b`),
而协同组今天刚为同一个形状开了 **GH #622**。`tpdying` 给 #622 补的是**量过的那一半**:
嵌套不只是「入集时可能买到 no-op」,它让**这条 id 自己的 (a) 在嵌套还在的时候就买不到**
—— 4,527 次落地 / 70 game-legs 也答不出来。

**本行退休**(义务已履行:执行方录像组不欠任何东西了),残留义务**换了执行人并开始花钱**,
故另立一行 `tpdying_isolation_leg`(隔离腿:同一批 seed,arm `tpcommit` 而**不** arm `tpdying`)。
⛔ **把它写进已退休行的 outcome 散文里就是 §DR / GH #540 量过的掉棒形状:一条已退休行的散文,没有任何腿会替它举手。**

### §GA.2 `a_evidence_tpreach` —— 判 **WORKING**,而 §BC.4 的字面要求**没有被豁免,是被搬走了**

产物 `iterations/reports/replay-check/a_evidence_tpreach.md`(213 行,录像组 09-06T04:04Z)。
§BC.3 的自我制约守住了(读数由录像组取,不是总监自己看)。arm 串是对**钉住的那棵树**核的
(`git show 066219d6:...test_set.md` 第 2 行第 28 位 / 61,md5 与 `W49_wave.json.arm_md5` 对上),不是对散文核的。

**判 WORKING 的理由,写成可以被攻击的形状**:(i) ADDED 是 `tpreach` **自己的**域
(`700 < d <= reach`,仅 STRIKE 子句),没有第二条 armed id 以这条带为域;
(ii) 方向**由源码事前钉死**(纯单侧否决只能拒绝一个超集),而它 **4/4 粒种子向下、三张 reach 表全过**
(p50 −0.2135 / p90 −0.2375 / source −0.1167);
(iii) **体积对照**把它与「普遍少按 TP」分开 —— 61-id bundle 让总按压动 ~3%,而 **ADDED 占比动 ~42%**
(0.9754% → 0.5624%);(iv) 组成比落在 `tpsafe2` **真的会跑**的那一格
(field share baseline 50% → armed ~20%,**两个分层各自独立复现**),而 §BC.1 保护的撤退格几乎没动(13 → 11)。

⛔ **产物点名要总监裁的那条限制,裁了而不是糊过去**:§BC.4 按字面读要由**非撤退 cell 单独**承载验收,
而那一格是 n=3 : 13、**2/4 粒种子**(有一粒四条腿上全零)、**且只在 p50 这张表上成立**。
**我不把它读成 INDETERMINATE,理由是铁律 4(ii) 而不是偏好**:值域这么小的计数正是 4(ii) 说的
「不许当承重估计量」的那种量;那一格该读的是**层内占比**,而占比两层各自复现。
**但字面要求也没有被豁免** —— 它搬进了 `tpreach_bc4_cell_reread`:**重新入集之前**必须用更多粒种子重读那一格,
且那张每粒 swap-average 表**要由 `tpreach_domain.py` 自己打印**(产物 §8 自登的债,4(i-d) 形状)。
⭕ 本行退休。(b)/(c) 未触及;`tpreach` 仍在集外(09-05 退集,60 → 59);owner P4.2 冻结独立于 (a) 管着重新入集。

### §GA.3 ⭐⭐⭐ 另外两行:**行自己的散文说「不可退休」,工具在它下面一行说「请退休我」**

| 行 | 机器键 | 为什么读 DONE | 为什么不可退休 |
|---|---|---|---|
| `roshan_pit_daynight_fix` | `path_exists tests/test_roshan_pit_daynight.lua` | 该文件 09-07 落地 ⇒ 此后**永远为真** | **同一轮**把残留收窄成「一波 armed `roshpit` 的**行为**读数」,并在行内逐字写下「机器键此后读 DONE,**而本行不许据此退休**」 |
| `hero_domain_scan_2_30_31` | `path_contains_all`(九个 id) | 九个 id 全被**提到**了 | 产物自己的 §7 逐字写着 **hero-32 / hero-33 没交**(卡在 dumper 的 `creeps[]` schema:18,709,698 行单一键形 `t|team|x|y`);另外 **hero-2 / hero-34 交到了另外两个路径**,而入集裁定当时写的是「产物路径不变」 |

**这就是 §AW.1 / §DR 立案的那个形状——裁定落进了没有人读的字段——在替它立法的 registry 内部复现了一次。**
两行都不是「有人偷懒」:两处收窄都是**上一任总监当轮就写清楚了的**,写在 `done_when_note` 与 `residual` 该在的位置上,
只是**那个位置当时不存在**。

**处方(本轮实现,GH #627)**:新增可选行字段 **`residual`**(非空字符串)。
机器键满足 **且** 该字段非空 ⇒ 状态 **RESIDUAL**:它是 finding、进退出码,**永远不打印 retire 那一行**。
- `owed_status()` 拆成 `_machine_key_status()`(纯读键)+ overlay,**键的读数保留在 detail 里**
  ——「产物确实到了」是真的,而且正是本行仍然开着**而不是从没开始**的一半理由;
- 键**未**满足时 overlay 不生效(不许用一句更含糊的话换掉「文件不在」这句更锋利的);
- **写坏的 residual**(`true` / 空串 / 数字)读 **UNCERTIFIABLE 而不是被丢掉** —— 丢掉恰好等于
  在一个**作者正想说反话**的行上恢复 retire 那一行;
- `LIMIT 13` 写明买不到什么:**看不见没人写下来的 residual**(LIMIT 9 同形),
  也不检查 residual 文本仍然为真 ⇒ 残留真没了要**手动清字段**,在那之前一直报 RESIDUAL,**这个方向是安全的那一侧**。

**验收**:`tests/test_pending_rulings.py` **349 → 361 checks / 0 failed**(裸读 `RC_EXIT=0`),
载重断言是**同一行的一对**(同一份满足的键:无字段 DONE、有字段 RESIDUAL)+ **一个对照体**
(无字段的行**必须仍然**打印 retire 那一行,否则「不打印 retire」那条断言平凡真)。
变异台 `tools/agent/mutstand_owed_residual.sh` **7 CAUGHT / 0 SURVIVED / control_ok=1**,
还原 `git diff` 逐字节 YES,裸读 `RC_EXIT=0`。
⚠️ **M5 第一版是空变异**(在 `finding = True` 之前插 `finding = False`,被后一行覆盖)⇒ 它 SURVIVED,
**差一点被读成断言的洞**;按证据纪律 2 先怀疑断言,查出来是**变异自己的锚下错了**——登记在脚本注释里。

### §GA.4 本节买不到的东西(一句都不许合并)

1. **`hero_domain_scan_2_30_31` 的九份读数本轮没有逐份读通** —— 只读了它的 §7 状态表与 hero-2/hero-34
   两份产物的头部。`residual` 买到的是「这一行不再谎称自己可退休」,**不是**那九份读数正确。
   逐份读通仍是退休它的前置,那一层 `path_contains_all` 与 `residual` **都**买不到(LIMIT 11)。
2. **`roshan_pit_daynight_fix` 的残留没有被推进** —— 它挂在 owner P4.2 解冻之后,本轮只让它不再说谎。
3. **`tpdying` / `tpreach` 的 (b) 与 (c) 一个字都没碰**;两条都在集外,本节不主张重新入集。
4. **没有量 `residual` 字段会不会被滥用成「永久缓刑」** —— 它每轮报 finding,但**没有任何腿在数它的年龄**;
   下一个总监该看的是这个字段有没有开始变成一张过期清单。

---

## §GB 2026-09-08T16:0xZ 总监:**八条一次裁完(hero-41..48,APPROVED-SCAN),而本节最该被读的不是裁定 —— 是「已知的三堵墙递给执行方的不是空白,是一个指向同一边的错数」,以及「针脚表靠人记得去加,于是它在被立起来的下一轮就漏了三根」**

零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、无 promote/reject、`DECISIONS_NEEDED` +0。
取活依据是上一轮「下次触发」的 **①**(自检 `queue-rulings` 腿**每轮点名**,`director` 字段至今空着)。
到本轮 16:0xZ,该桶里已经不是七条而是 **八条**(hero-48 14:31Z 到达)。

### §GB.1 裁定:八条全部 **APPROVED-SCAN**,**不是 FROZEN-HOLD**

上一轮的「下次触发 ①」写的是「P4.2 冻结期的合法裁定是 **FROZEN-HOLD**」。**照请求原文读,那句是错的**:
八条在自己的 `bundle` 字段里**逐字写着**「turbo-only soak candidate, **NOT armed** —— P4.2 冻结期内**本条不请求入集**」。
P4.2 冻的是 **armed 集变大**;这八条一条也不进集,要的是**零 EC2 的只读档案遍历**。
先例已经定死了这一档:hero-31(§EY.4)、hero-32/33/34(§FE.1)、hero-35(§FG.2)、hero-36(§FI.2)、
hero-37(§FK.7)、hero-38/39(§FO.6)、hero-40(09-07T10:xxZ,判词逐字是「申请方自己写明本条不请求入集,
所以不触发『冻结期唯一合法裁定是 FROZEN-HOLD』那一条」)。**本节按 hero-40 的判词裁,并把它抬成这一档的引用点。**
(hero-30 拿的是 FROZEN-HOLD,但它自己的 note 也写着「冻结冻的是入集,不是取证」——**同一份判断,标签不同**;
从 hero-31 起标签统一成 APPROVED-SCAN,本节不追改 hero-30 的历史行。)

执行方 **replay-check**(§CH:恰好一个流),产物**不改名**:
`iterations/reports/replay-check/domain_scan_hero_2_30_31.md`,acceptance **一字未改**,
METHOD-FAILED 按 §CJ 强制回总监重裁。

### §GB.2 ⭐ 本节的主轴:**三堵已知的墙,每一堵递出来的都不是空白,而是一个指向「不入集」那一边的错数**

这一档的裁定如果只写「批准、搭车、别改名」,它就是一次盖章。真正花钱的是下面这三处,
**每一处都是今天就知道、而执行方要用一整轮才会重新发现的**:

1. **hero-42(`cmfarcreep`)—— 结构上买不到,今天就知道。** 它的 (2) 要「广列表最强兵血量落在 (390,460]
   **且**近列表最强兵 ≤390」,(1) 要按 lane creep / neutral / 玩家随从分层:两者都要 `creeps[]` 的 **hp 与 name**,
   而 `creepSnap` 只有 `{t,team,x,y}`(产物 §7 / §9.1:**18,709,698 行单一键形**;[harness] **GH #581** open)。
   **这正是卡死 hero-32/33/36 的同一堵墙。** ⇒ 排期裁定:**本条排在 #581 之后**,执行方本次遍历**跳过它**、
   留一行点名 #581 的状态行(与 hero-32/33 同款),**不要交一份把 (2) 写成 0 的报告**。
2. **hero-45(`wkqlane`)的第 (4) 列 —— 墙不给空白,给一个错的 0。** (4) 问「当帧 Bone Guard 是否
   `IsFullyCastable` **且充能 ≥ 60%**」,而充能层数正是产物 §6.5 明写「买不到,**不用 0 顶替**」的那一列;
   §4 更进一步实测:**dump 递过来的是一个正好错的 0** ⇒ `nStack/maxStack >= 0.6` **恒假** ⇒
   (4) 会读成「**从来没有压掉过一个满充能的嘲讽**」。⇒ 预贴 **BLIND-BY-KNOWN-WALL**;
   **不许**把这个 0 写进读数,**更不许**用它论证「机会成本不存在」。(1)(2)(3) 照买。
3. **hero-47 的移速前置 / hero-48 的朝向前置 —— 默认值会做出同一件事。** hero-47 的 (1) 前置含
   「目标移速 < CM 移速」,hero-48 的落点重建要 **bot 自己的朝向**。字段拿不到时,
   「用出厂移速常数顶替」会让那条前置在整份语料上恒真或恒假;「朝向 = 指向目标」会让落点永远朝目标去、
   **gap 恒为最优** ⇒ 读出来是 `DOMAIN-NOT-REACHED`。**两个默认值的方向都正好是掐死本杠杆的那一边。**
   ⇒ 执行前**先自检那一个字段**,拿不到就按 §CJ 交 INSTRUMENT-BLIND 并点名缺的是哪个字段。

**为什么把它写成一条主轴而不是三条脚注**:§GA.1 刚立过「买不到与没人去买在 verdict 表里长得一模一样」。
本节补的是更窄也更贵的一格 —— **撞墙的列常常不是交白卷,而是交一个看起来正常的数字,且三次的方向是同一边**。
一份「(2)=0 / (4)=0 / gap 恒 0」的报告读起来像三条独立的阴性证据,实际上是同一台量具在三处失明。

### §GB.3 ⭐⭐ 顺手撞到、比裁定本身更贵:**针脚表在它被立起来的下一轮就漏了三根**

`owed_executions.json:hero_domain_scan_2_30_31` 的 `done_when` 在 2026-09-06(hero-36)从 `path_exists`
换成 `path_contains_all`,**立案句就是「一份已交付的产物读 DONE,而它欠的读数大多不在里面」**。
本轮清点:**hero-38(09-06T22:xxZ)、hero-39(同轮)、hero-40(09-07T10:xxZ)三条都已批准搭这次遍历,
三条都没有进针脚表**,于是这条腿在**三份从未开工的读数之上**照样读 DONE(产物里 `hero-38/39/40` 各 **0** 次出现)。
**换针脚那一轮之后的第一轮和第二轮,各漏一次。**

⛔ **缺陷不是裁定也不是工具,是「裁定搭车」与「加一根针」是两个分开的手工动作,而第二个没人拿着。**
⇒ 本轮立机器不变量,两条腿都写在失效方向上:
- 机器键 **`director.owed_row`**(值 = owed 行 id)。八条新裁定自带;**hero-2/30..40 十二行回填**。
- **`tests/test_domain_scan_pass_pins.py`(5 checks)**:`{queue 里 director.owed_row==本行的 id}` **≡**
  `{本行 done_when.contains 里形如 hero-N 的针脚}`。**是等式不是包含** —— 左到右抓本轮这次漂移(裁了不钉),
  右到左抓它的镜像(钉了没人欠,那会让这条腿为一份没人欠的读数**永远红**)。另加「两侧不许同时为空」
  (`set()==set()` 与任何东西都相符)、`done_when.kind/path` 仍指着那份产物、rider 的 `deliverable`
  必须以该路径开头(**startswith 不是等号**:hero-31 那行把路径和「路径是裁定的一部分」的理由写在同一个字段里)。
- 变异台 **`tools/agent/mutstand_domain_scan_pins.sh`**:**5 CAUGHT / 0 SURVIVED / control_ok=1**、
  还原按 `sha256sum -c` 逐字节 YES。**五发全部是「这次遍历欠得比裁定少」的方向**,M1 就是 hero-40 今天之前的真实状态。
  `tests/test_mutstand_restore_trap.py` 对新台五项全 ok。

针数 **9 → 20**(hero-38..48 一次补齐)。⚠️ **针数变大不是记账倒退** —— 那三份读数本来就欠着,
只是这条腿看不见它们。改完这条腿当场点名:`11 of 20 required mention(s) are absent: hero-38 … hero-48`。
⚠️ **hero-42 的针脚是「被提到」不是「读数」**(见 §GB.2 第 1 条),别为了让针脚变绿而交一份写着 0 的报告。

### §GB.4 限度(本节自己买不到的)

1. `path_contains_all` 仍只买 **mention**,不买读数正确 —— 逐份读通仍是总监退休本行前的**手工**动作(LIMIT 11)。
2. 新不变量只认**带 `owed_row` 键**的搭车裁定;**只写在散文里的搭车对它不可见**(这正是回填十二行的理由)。
3. 它只钉**这一行**。「每条 owed 行的针脚都得有出处」是一条更大的法,而多数 owed 行不是 queue 形状的,本轮不立。
4. 八条里**没有一条被读通** —— 本节裁的是**排期与量具前提**,不是读数。

### §GB.5 [bug] GH #637 —— **一条每轮点名的 trunk 红,归因是「插入了几行」,而它教会读者整份 ratchet 是噪声**

本轮开工自检(真码 `EXIT=3`,10 条腿跑完)报 `FINDINGS: cadence queue-rulings owed-executions **trunk-red(python)**`。
那条 python 红是 `tests/test_chain_member_census.py` 的
`FAIL every judged row's recorded line matches the finding it names TODAY --
[(('bots/ability_item_usage_generic.lua', …'1585a9b8'), 8445, 8458)]`,
批测台 15:10Z 已立案 **GH #637** 并写明建议(「**把这一行从绝对行号上摘下来**,而不是把数字改成 8458 续成第五项」),
同时正确地拒绝自行改别组台账。**这是章程 2a 的活,总监的。**

⭐ **裁定按测量,不按口味。** 那个字面量 **移动了五次**:`8246→8256→8341→8423→8435→8445→8458`,
**没有一次是因为那个 finding 变了** —— 每一次都是**同一个文件里它上方的插入**
(注释行 / `urnself` gate / `grenharass` / `tpdeep` / `tpquiet`)。键
`(文件, 定位串, 8 位 hex)` 五次全部吸收(GH #442 就是为此设计的),**只有这条 freshness 检查在收费**,
而收费对象是「碰巧编辑了 `ability_item_usage_generic.lua` 的那一轮」。GH #574 早就问过该不该继续收;
**#637 把账收齐了**。

⛔ **而且它的失效方向比浪费更贵:五次里有两次没人付,每次都把 `origin/main` 留成红的。**
一条写着「有人在一个无关 finding 上方插了几行」的红 trunk,**教会下一个读者这份文件是噪声** ——
而这份文件另外十二条检查,正是「真的丢了一个 chain member 就当天变红」的那些。

**修法**:drift 改为**打印 `LINE NOTE` 并保持绿**(**与工具本身的语义对齐** —— `chain_member_census.py`
从来就是这么做的,是这条检查在跟它唱反调);顶替它的是那个数字**真正代表**的性质:
**每条 judged 行仍然有一个可用的导航行号**(缺了 / 是垃圾值 ⇒ finding 找不到,那是真缺陷,
且**无法被另一个文件里的插入触发**)。⚠️ **`8445` 这个字面量本轮不改** —— 改它就是把第五次通行费也付了,
正是 #637 说不要做的事;工具每轮打 LINE NOTE 指出今天的真实行号,导航照旧可用。
验收:`tests/test_chain_member_census.py` **all checks passed**,并逐字打出
`LINE NOTE judged row 1585a9b8 records :8445, found at :8458 today`。
反向核验(不是空断言):把该行导航值改成 `0` ⇒ **红(exit 1)**;纯注释编辑 ⇒ **绿**;
两次之后 `git diff --quiet` 对该文件逐字节 YES。

⚠️ **限度**:本节没有量「导航行号会不会一路陈旧到没用」——它现在允许无限漂移,
靠工具每轮打出今天的行号来兜底。若某天 LINE NOTE 变成常态噪声,下一个总监该考虑的是
**把行号从台账里彻底删掉**(键已经够唯一),而不是把 freshness 检查加回来。

---

## §GC 2026-09-08T1x:xxZ 总监:**两条退回出集(44 → 42),`wandlimbo` 与 `tpdead`** —— 本节最该被读的是 **§GC.2:两条 id 各自都有一份绿的、钉在真实帧上的 fixture 测试,而两份都由测试作者亲手写进了该杠杆唯一转轴的那个输入 —— 「已验证」与「条件 (a) 已买到」在这种测试上长得一模一样**;以及 **§GC.4:本节第一版的一条断言被自己的变异台当场推翻,因为 `bot.tpRespondUntil =` 是 `bot.tpRespondUntil ==` 的前缀**

### §GC.0 一句话

上一轮「下次触发」的 **①**(⭐**≥2 判定完结**,上一轮 **0**,owner P4.2 的产出指标,排在任何新裁定之前)本轮取掉:
**两条退集**,armed 串 **44 → 42**。零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、`DECISIONS_NEEDED` +0。
**先建量具再裁定**,而量具**当场推翻了自己的一半**:半 2 的对照组读 0(见 §GC.3),于是那一半的零**不作为证据使用**。
判定完结 **2**(达标)。

### §GC.1 选取依据

`arm_since.py` + `verify_coverage.py` 的 P4.2 排序键:最老一档(45 天,`lower_bound`)现存 4 条**已在 §FX/§FZ 逐条判过或具名排除**
(`tpcommit` 留集/promote 原子 prereq、`lf_rescue` 正在飞、`ownhalf`/`overchase` 留集带欠条)。
**下一档是 2026-08-19 的 20 天档**,其中 `verify=0` 的是 `cmrguard` / `tpdead` / `wandlimbo` 三条。本节取后两条,
因为两条的 (a) 都可以在**零 AWS、零新局**下判死或判活——而 `cmrguard` 不能(它要一波单臂读数,留给下一轮)。

⭐ **三条共有的、此前没被登记的读数**:`wandlimbo`/`tpdead` 在 **W39/W40/W41/W52/W53/W54/W55/W56/W57 九个波次里全部只以成员串内的一员出现,
一次都没有被单臂 arm 过**(逐波扫 `iterations/reports/batch-desk/waves/W*_wave.json`,命中长度 397–501 字节,即全量成员串,无一条短串)。
⇒ 20 天里没有任何一波在问它们的问题,而条件 (b)「批测胜负无明显负面」因此**对这两条从来没有过读数**,不是读数不好。

### §GC.2 ⭐⭐⭐ 立法级:**一份钉在真实帧上的绿测试,可以由作者亲手供给该杠杆唯一转轴的那个输入**

两条 id 各有一份 fixture 测试,两份都绿,两份都钉在真实帧上,**两份都不是条件 (a)**:

| 测试 | 真读自 dump 的 | **作者写进去的** |
|---|---|---|
| `tests/test_replay_181441_wand_limbo.lua` | HP 214/1354、最近敌人 ~2017u、泉水距 ~4600、无敌人在 1600 内 | `rawget(wand, '__spec').GetCurrentCharges = n`(触发用 **12**,不触发用 **3**) |
| `tests/test_tpdead_release.lua` | 落地帧、盟友句柄、死亡时刻 | `bot.tpRespondLoc` / `bot.tpRespondUntil` / `bot.tpRespondAlly` **三行赋值** |

⭐ **两个被写进去的输入,恰好都是该 id 唯一多出来的那一维**:
充能是 `wandlimbo` 相对已发行 magic wand 规则**唯一多出来的子句**(其余子句已发行规则自己就有);
commitment state 是 `J.GetTpCommitDefendDesire` **可达性本身**。
本轮实测:充能在 **953 个句柄上全部读 0**;commitment state 在 **1021 帧上一帧都不存在**(`td_state_present 0`)。

⇒ **两份测试都没有错,错的是把它们读成 (a)。** 这类测试问的是「**给定这个输入**,决策对不对」;
条件 (a) 问的是「**这个输入到底出没出现过**,出现时机器人决策对不对」。
**在一帧其余子句全部真读自 dump 的真实帧上,这两者极难分辨** —— 而这正是 AGENTS.md 那句
「Gate-plumbing tests are NOT local validation」**覆盖不到**的形状:它说的是纯桩测试,而这两份**不是**纯桩测试,
它们是真帧测试**加一个桩输入**,并且那个桩输入是转轴。
⇒ **这就是两条 id 一边看起来「已 fixture 验证」、一边挂着 `verify=0` 二十天的机制**,
而 `verify_coverage.py` 的 LIMITS 只写了「verify=0 不等于从未核验」,没有写「有一份绿的真帧测试也不等于核验过」。

⭕ **处方没有当轮做**(工作单元边界,登记而非发明):一个普查,列出所有
**先写 `__spec` 字段或先给 bot 赋状态、再调用被测 helper** 的 fixture 测试,让「桩了转轴」这件事从此可读。
已进总监章程基建 backlog,**不留在散文里**。

### §GC.3 ⭐⭐ 量具当场推翻了自己的一半:**对照组读 0,于是这一半的零不作为证据**

`tests/_blind_a_sweep.lua`(110 fixture / 1021 live turbo hero 帧)两半:

**半 1(`wandlimbo`),读数成立**:
`has_wand 953` / `charges_read 953` / **`charges_nonzero 0`** / **`wl_full 0`** / **`wl_nocharge 17`** / `wl_err 0` / `arm_leak 0`。
`wl_full` 是仪器的零(第一条合取被 `^Get -> 0` 兜底短路),`wl_nocharge`(去掉充能合取的同一谓词)是它盖住的域,
**两个数缺一个都什么都不说**。⭐ **17 帧里就有它自己的立案帧**:`f_181441_zuus_lowhp_limbo`(hp 0.1581 / 泉水 4598.5)——
**作者为了证明这条杠杆而冻下来的那一帧,仪器答不出来**。
两端都不带充能:`FIXLOADER_SERVES_CHARGES 0`(loader 头里逐字写着 Charges 是 "STILL REFUSED, deliberately")、
**`DUMPER_CHARGE_MENTIONS 0`**(`dumper/main.go` 里 `charge` 一次都不出现)。

**半 2(`tpdead`),对照组失败,读数因此不用**:
arm `tpdead` 单臂 ⇒ `td_armed_alone_nonnil 0`;arm `tpcommit` 单臂当**对照** ⇒ **`tc_alone_nonnil 0` 也是零**。
按 GH #171 的家规,对照为零时第一个零什么都不是。成因**量出来而不是猜出来**:
`td_state_present 0`(1021 帧全部没有 `tpRespondUntil`),因为该函数第五行要的是**活局里响应 TP 分支才会写的状态**,
而 fixture 里的 bot 从来没 TP 过。
⇒ **半 2 的两个零不是关于 `tpdead` 的证据,本节也没把它们当证据用。** 它们买到的是**第三堵墙**:
语料路径对这个函数**结构上不可达**,所以 `tpdead` 的 (a) **在语料路径上也买不到**——
与 §GA.1 已经量过的「波次路径不可分解」是**两条路径、两个不同的原因**。
半 2 的裁定依据是**源码读数**(已标注为源码读数:门在前、子句在后、写入方自述惰性、全树唯一读者)**加上** §GA.1 那 4,527 次落地的已有读数。

### §GC.4 ⭐ 变异台推翻了本节自己的一条断言(纪律 2 的正面兑现)

`tools/agent/mutstand_blind_a.sh`,**10 CAUGHT / 0 SURVIVED / control_ok=1**,五个文件还原 `git diff` 逐字节 YES。
**十发全部朝同一个方向:每一发都「解除一堵墙」或「拆掉一条理由」,即每一发都让本裁定变错** ——
这个文件唯一的失效模式不是过严,是**活得比它的题目久**。

⚠️ **M10 第一次跑 SURVIVED,而它是对的、断言是错的**:§2e 原本断言 `tests/test_tpdead_release.lua` 里存在
`bot.tpRespondUntil =`,而 **`bot.tpRespondUntil =` 是 `bot.tpRespondUntil ==` 的前缀**,
同一个文件里恰好有两处 `bot.tpRespondUntil == nil` 断言 ⇒ **把三行赋值全删掉,该断言照样绿**。
一条**比较**能满足的断言,不是关于**赋值**的断言。改成钉整条赋值语句后 CAUGHT。
(与 §FW 那次 M4 SURVIVED 同族:两次都是「按形状计数的断言看不见形状相同的另一种东西」。)

### §GC.5 落地物

- `tests/_blind_a_sweep.lua`(重语料 sweep,`_` 前缀,**不进快腿** —— Lua 检测器腿已在 120s 预算边缘,GH #358)
- `tests/test_blind_a_wandlimbo_tpdead.lua`(**11 checks / 0 failed**,毫秒级;语料读数以定值引在头里,同 `test_fieldregen_family_overlap.lua` 的做法)
- `tools/agent/mutstand_blind_a.sh`(10/10 CAUGHT;`test_mutstand_restore_trap.py` 对新台全 ok)
- `iterations/streams/test_set.md`(表头 + 本节)、`iterations/armed_since.json`(两条 `retired_at`)、
  `iterations/state.json`(`wandlimbo_RETURNED_20260908` / `tpdead_RETURNED_20260908`)、
  `iterations/owed_executions.json`(新行 `wandlimbo_charge_instrument`;`tpdying_isolation_leg` **补点名 `tpdead`**)

### §GC.6 诚实边界(本节**没有**做到的事)

1. **没有量 `wandlimbo` 在真实对局里会不会触发** —— `wl_nocharge 17` 是**去掉一条真合取**得到的,
   是隐藏域的**上界**,不是它的估计。这条界写进了 sweep 头。
2. **没有量退集之后 `tpcommit` 的读数是否真的变干净** —— §GA.1 退了 `tpdying`、本节退了 `tpdead`,
   两个释放现在都出集了,但**那要一波单臂波次**才能读,本节不发波。
3. **没有判 `cmrguard`** —— 同一档同一读数的第三条,它的 (a) 买不买得到**本节没有量**,原样留给下一轮。
4. **没有做 §GC.2 那条处方**(桩转轴普查),只登记进 backlog。
5. **没有核 `tpdead` 退集对 `promote_atoms.json` 那一行的长期影响** —— 本节只主张「退集不是 promote,故该行不动」,
   **不主张**两个 subject 都出集之后那一行还需不需要存在;它的 RELEASE CONDITION 逐字未变。
6. **patch 检查本轮未做**(低频;上一次 §GA.0 做过,无新 patch)。

---

## §GE 2026-09-09T0x:xxZ 总监:**`roamidle` 与 `campsel` 退回出集(41 → 39)** —— 本节最该被读的是 **§GE.3:本仓库的 fixture 加载器在 2026-09-02 就诊断出了本轮这个一模一样的机制、命名了它、并把它修好了 —— 修的是隔壁那个 getter**;这是「一次没有推广的修复」的**第二个实例**(第一个是 §GD.5)

### §GE.0 一句话

`roamidle` 与 `campsel` 退回出集,armed **41 → 39**。**判定完结 2**(达 owner P4.2 的 ≥2)。
零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、`DECISIONS_NEEDED` +0。
取活依据是上一轮「下次触发」的 **①**(逐字点名 `verify_coverage.py` 的 `narrat=1` 四条:
`campsel`/`pulllane`/`pullthink`/`roamidle`;本轮取其中两条)。

### §GE.1 判据:(a) 问的不是「决策对不对」

两条 id 各有一份**绿的、钉在真实帧上的**测试,而两份都由作者**亲手写进了该杠杆的转轴输入**——
与 §GC.2 完全同型。这类测试问「**给定这个输入**,决策对不对」;(a) 问「**这个输入到底出没出现过**」。
区别在于本轮两份测试都**自己把这件事写在头部**(见 §GE.2、§GE.4),所以本节不是抓错,是**采信它们的自述并去量**。

### §GE.2 `roamidle`:三条析取在语料每一帧全假,且**失败向关**

gate(`bots/mode_team_roam_generic.lua:651`)只在 `bRelocated` 上开火,而
`J.CheckBotIdleState`(`jmz_func.lua`)只经一条析取写 true:

    if bot:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE
    or botMode == BOT_MODE_ITEM
    or botMode == BOT_MODE_FARM then

`api.install` 把未知 ALL_CAPS 全局解析成**互不相同的 ≥1001 哨兵**(实测 IDLE **1174** /
ITEM **1021** / FARM **1017**),而未 spec 的 `^Get` 兜底答 **0**
⇒ 三条比较都是 `0 == 非零`,**在语料每一帧全假**,`bRelocated` **构造性不可达**。

**实测读数**(均为真跑,非推断):
* `GetCurrentActionType` 在 **110 份 fixture 中出现 0 次**;`GetActiveMode` 同样 **0 次**。
* 全套测试里**只有两个文件**提到这个 getter:它自己的绿测试,和本轮新增的盲测。
* replay 侧 `tools/batch_test/behavioral/dumper/main.go` 里 `action_type` / `ActionType` /
  `NumQueuedActions` **一次都不出现**(该文件里唯一的 "idle" 是第 675 行一句散文)。
* **驱动真帧的对照实验**(`tests/test_blind_a_roamidle_campsel.lua` [1b]/[1c]):
  在 `f_260819_181742_ss_chase_start` 上,不写转轴 ⇒ 助手**确实 latch 了 idle**(`idle == true`,
  每一条它读得到的谓词都成立)而 `bRelocated` **假**;由作者写入转轴 ⇒ **同一帧**开火。
  ⇒ 这一读数量的是**仪器**,不是一条死杠杆。

⭐ **方向与 §GD 相反,而这正是它更难被发现的原因。** `cmrguard` 的兜底 0 把 veto 环**顶开**
(它**放行**了那条要了 CM 命的通道);这一条**失败向关** —— 杠杆干脆不开火,波次读数回来是
「测了,没效果」,**没有任何计数会举手**。两个都静默,只有一个**看起来像个结果**。

### §GE.3 ⭐⭐⭐ 一次没有推广的修复(第二个实例)

`tests/mock/replay_fixture.lua:847-863`(strategy 2026-09-02 留)**逐字诊断了本轮这个机制**:

> `api.install` auto-resolves every unknown ALL_CAPS global to a distinct sentinel >= 1001.
> What was missing is the GETTER above -- and unspecced, `^Get` defaults to 0, so
> `GetItemSlotType(slot) == ITEM_SLOT_TYPE_MAIN` was **`0 == 1174`**, FALSE on every frame of
> the corpus. Every branch behind one was constructively unreachable, **failing CLOSED and
> silently**

**同一个哨兵数字(1174)、同一种比较、同一个失败方向。** 那一轮为 `GetItemSlotType` 补了 getter
并把结论写成散文;**`GetCurrentActionType` 没有补**,而一条 armed 的 id 就压在没补的那个上面。
⇒ 与 §GD.5(`AbilityDamage` 无条件装、紧挨其上的 `AbilityCastRange` 没装)构成**同一族的第二例**:
**缺陷不是没人诊断过,是诊断只落到了它被看见的那个 key 上。**
⛔ 本轮**不**顺手去补这个 getter:补它会改变 110 份 fixture 上**所有**读这条 API 的判决,
是一个独立杠杆,属于工作单元边界之外。登记为 owed 行 `roamidle_actiontype_instrument`。

### §GE.4 `campsel`:营地记录不在任何一条仪器里

转轴是 `aba_site.lua` 的 `rec = camp.cattr`,喂给 `IsEnemyCamp`(读 `.team`)与
`IsAncientCamp`(读 `.type`)。
* **fixture 侧**:语料里 `cattr` **0 命中**。而这一条**是它自己的绿测试在头部写明的** ——
  「The CAMP half is not in the corpus and **is not pretended to be**」、
  「a **DECLARED STAND-IN**」、「No count in this file is claimed to be corpus data」。
  **诚实的测试,只是它不是 (a)。**
* **replay 侧**:dumper 的 `creepSnap` **恰好是 `{t, team, x, y}`**(机器读出并排序断言),
  **无 name 无 type** ⇒ 一个营地的 `.type`(ancient)从 .dem **也重建不出来**。
  与卡死 hero-32/33/36/42 的 GH #581 是**同一堵墙**。

⚠️ **`campsel` 的 SUBJECT 半边是真的**(真英雄、真等级),所以它不是「什么都没有」——
它是**两个操作数里买到了一个**。(a) 要的是两个。

### §GE.5 退集不是 reject;`slotarb` 特别核过

⛔ gate、helper、调用点**逐字保留**,`bots/`+`game/` **零 diff**(由 [3c] 双向钉住:
gate 行还在、helper 的第二返回值还在、两条各**恰好一个**调用点)。
⚠️ **`pullcad` 陷阱**:`promote_atoms.json` **零次**点名这两条;两条的门行上都没有第二个 id。
⭐ **特别核过 `campsel` 与 `slotarb` 同住一个 wrapper**(`mode_farm_generic.lua` 的 `ClosestCamp`)——
但它们是 `GetClosestNeutralSpwan` 的**两个独立实参、各占一行**,
`slotarb` 留在集内、**功能逐字不受影响**。这正是 §BA.2 那种「被 promote/退集冻死」的形状要查的地方。
⚠️ **载体项 7 → 7 逐字不变,量出来的**:`carrier_terms.py --arm` 对两串各跑一次,
`TERMS` 行**逐字节相同**,`0 unresolved` 两次;`9 hero / 32 generic` → `9 / 30`(两条都是 generic)。
⛔ **W58 及更早不与 39-id 家族并池。**

### §GE.6 量具与纪律

* `tests/test_blind_a_roamidle_campsel.lua` —— **12 checks / 0 failed**(经
  `lua5.1 tests/run_tests.lua`,退出码 **0 未经管道**,走 `rc.sh`)。
* `tools/agent/mutstand_blind_a_roamidle_campsel.sh` —— **12 CAUGHT / 0 SURVIVED / control_ok=1**,
  八个文件还原走**树外文件副本** + `git diff --quiet` 每轮校验(实测最终 `git status` 只剩两个新文件)。
  ⭐ **每个变异都朝同一个方向跑**:要么**买到**那份缺失的读数(M1/M3/M7/M8/M11/M12),
  要么**溶掉盲的理由**(M2/M4/M5/M6/M9/M10)—— 这个文件不会因为太严而错,只会因为**活得比它的主题长**而错。
* ⚠️ **M5 第一次 SURVIVED,而它是对的、断言是错的**(纪律 2,与 §GC/§GD 同型,**第三次**):
  needle 写作裸串 `S-B`,而该串在那份测试里**出现四次**(声明、赋值标记、断言块两处),
  于是把**承重的那一处**(LABELLED SYNTHETIC 里的声明行)删掉之后仍绿。
  改钉**标签连同它所标注的操作数**(`S-B  \`bot:GetCurrentActionType()\``)后 CAUGHT。
  ⇒ 这条经验现在有三个独立现场(`GetCastRange = 1000` 两处、`tpRespondUntil =` 是 `==` 的前缀、本次),
  **共同形状是:needle 比它要钉的东西宽**。
* ⛔ **动态半(Lua 全量 ~100min,GH #124)未跑,不作声称**;本轮 `bots/` 零 diff。
* 自检 10 条腿:`114 passed / 0 failed / 2 uncertifiable`,两条 UNCERTIFIABLE 是
  `test_luacheck_gate_soakswitch.py`(容器缺 luacheck,由铁律 6 的 gate 自己买)与
  `test_selfcheck_lua_leg.py`;`trunk-red(python)` 腿再次撞 GH #358 的 **120s 预算**(**UNCERTIFIABLE 不是通过**)。

### §GE.7 下一棒

* owed 行 **`roamidle_actiontype_instrument`**:为 `GetCurrentActionType` 补加载器 getter
  (§GE.3 的推广),补上即可按 [1b] 的红重新提议入集。
* owed 行 **`campsel_camp_record_instrument`**:营地记录进语料或进 dumper(与 GH #581 同一堵墙,
  **应与 #581 一并做,不单开**)。
* ⭐ **本轮没做而下一轮该做的**:`narrat=1` 还剩 **`pulllane` 与 `pullthink`** 两条未裁
  (本轮预算花在买读数与建变异台上,**不为凑数去裁没量过的 id**)。

## §GD 2026-09-08T2x:xxZ 总监:**`cmrguard` 退回出集(42 → 41)** —— 2026-08-19 那一档 `verify=0` 的最后一条;本节最该被读的是 **§GD.2:这条杠杆的 veto 环读的是敌方技能的 cast range,而本仓库的 fixture 加载器从不读它 —— 于是 armed 的 gate 在**它自己的立案帧**上放行**;以及 **§GD.5:同一个加载器在三十行之下,已经为**相邻的那个 key** 诊断并修好了一模一样的危险**

### §GD.0 一句话

`cmrguard` 退回出集,armed **42 → 41**。**判定完结 1**(⛔ **不达 owner P4.2 的 ≥2,不粉饰**,理由 §GD.7)。
零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、`DECISIONS_NEEDED` +0。
机器键 `state.json:cmrguard_RETURNED_20260908`;量具 `tests/test_blind_a_cmrguard.lua`(**11 checks / 0 failed**)、
`tests/_blind_a_cmrguard_sweep.lua`、`tools/agent/mutstand_blind_a_cmrguard.sh`(**8 CAUGHT / 0 SURVIVED / control_ok=1**)。

### §GD.1 选取依据(不是偏好)

上一轮(§GC)的「下次触发 ①」逐字写着**判 `cmrguard`**,并写着「它的 (a) 买不买得到**本节没有量**,原样留给下一轮」(§GC.6 第 3 条)。
`arm_since.py` + `verify_coverage.py` 复读:2026-08-19 的 20 天档里,`verify=0` 的三条是 `cmrguard`/`tpdead`/`wandlimbo`,
**前两条已于 §GC 退集,本条是最后一条**。

### §GD.2 ⭐⭐⭐ 主轴:**armed 的 gate 在它自己的立案帧上放行**

`cmrguard`(`bots/BotLib/hero_crystal_maiden.lua:1612`)的判据是

```
GetUnitToUnitDistance(cm, e) <= ( hCc:GetCastRange() or 0 ) + X.nRGuardCloseBuffer   -- 400
```

除最后一项外每一项都是 dump 里的真数据。而最后一项是 **GH #34 那次收窄的全部内容**
(收窄之前 gate 是 range-blind 的,只看「有没有」不看「够不够得着」),
并且它读的是**敌方**英雄的技能句柄 —— 那正是本仓库加载器唯一不服务的地方。

实测(`tests/test_blind_a_cmrguard.lua` §1a–§1c,真帧 `f_260819_003005_cm_selfpreserve`,
即 hero.md backlog #2 / GH #34 的**立案帧**:Jakiro 持 ready 的 `ice_path` 距 CM **1138.6u**,
0.6s 后把她从通道里打断、她随即死亡):

| 读什么 | 读到 | 来源 |
|---|---|---|
| Jakiro 距离 | **1138.6** | 真帧 |
| `ice_path:GetLevel()` | ≥1 | 真帧 |
| `ice_path:GetCooldownTimeRemaining()` | 0 | 真帧 |
| `J.GetReadyHardCc(jakiro)` | **非 nil** | 真帧(能力那一半买到了) |
| `ice_path:GetCastRange()` | **0** | ⛔ `tests/mock/bot_api.lua:184` 的 `^Get -> 0` 兜底 |
| `X.cm_IsRSafeToOpen(bot)`,armed,**不写入 cast range** | **true = 放行** | `1138.6 > 0 + 400` |
| 同上,写入 `GetCastRange = 1000` | **false = 拦下** | 杠杆本身没坏 |

⇒ **仪器坏了,不是杠杆坏了。** 但 (a) 问的是「这个输入到底出没出现过」,
而在 fixture 路径上**它一次都没有出现过**。

### §GD.3 ⭐⭐ 塌缩是**全量**的,而且量出来的是**来源**不是值

`tests/_blind_a_cmrguard_sweep.lua`(110 份 fixture,~3s,`G`/`C` 行按房规钉进测试头):

```
G KV_ROSTER 5 (axe,crystal_maiden,lion,skeleton_king,zuus)
C FIXTURES 110   C HARDCC_HANDLES 487
C CR_ZERO 350    C CR_NONZERO 137
C KV_SERVED 137  C CATCHALL 350   C ACCIDENTALLY_RIGHT 100
C READY 304      C READY_ZERO 217
```

⭐ **`CR_NONZERO 137` 与 `KV_SERVED 137` 逐位相同,`CR_ZERO 350` 与 `CATCHALL 350` 逐位相同。**
也就是说:**整份语料里没有任何一个 0 是「读了 KV、发现没声明 cast range」得到的**,
每一个 0 都是兜底那一行。读得出来的四个载体(`crystal_maiden_frostbite` 600、`lion_impale` 650、
`lion_voodoo` 575、`skeleton_king_hellfire_blast` 525)**全部是焦点五英雄自己的技能**;
其余 14 个载体(jakiro/witch_doctor/ogre_magi/chaos_knight/shadow_shaman/sven/dragon_knight/
storm_spirit/earthshaker/centaur/slardar/tidehunter/axe)一律读 0。

⛔ **而 0 是分不出来的:** `axe_berserkers_call` 的真答案**就是** 0(无目标、自身半径),
它那 28 个 0 与 `jakiro_ice_path` 那 33 个 0 **走的是同一行代码**。
100/350 碰巧是对的 —— **对的值,错的理由**,且从读数上不可分辨。
剩下 250 个方向一致:**把远程 CC 一律当成自身半径**,把环缩到 400,**恰好是掐死这条 gate 的那一边**(§GB.2 形状)。

### §GD.4 ⭐ 第三例「绿的真帧测试 + 作者供给的转轴」(§GC.2 的形状)

`tests/test_replay_260819_cm_r_range.lua` 在立案帧上先做
`rawget(icePath, '__spec').GetCastRange = 1000`(它自己的注释称这是个 **under-estimate**),再断言 gate 拦下。
**那份测试没有错**:1000 大致就是引擎的答案,而「给定这个输入,决策对不对」正是子句测试该问的。
它只是**不是 (a)** —— (a) 问的是那个输入有没有被**读**到。
§GC.2 立的规律在本节第三次兑现,而这一次**被写进去的值直接决定立案帧的判决**。

⚠️ 本节把针脚从宽形改成**窄形**:`GetCastRange = 1000` 这个子串在那份文件里**出现两次**
(另一处是 Centaur 的「假装它是远程」变异),于是宽针脚在 ice_path 那行被删掉时**仍然是绿的** ——
`mutstand_blind_a_cmrguard.sh` 的 **M6 第一轮 SURVIVED,而它是对的、断言是错的**(纪律 2 的正面兑现,与 §GC.4 同型)。
改钉整条 `rawget(icePath, '__spec').GetCastRange = 1000` 之后 CAUGHT。

### §GD.5 ⭐⭐ 底下那件更贵的:**同一个加载器已经为相邻的 key 诊断并修好了同一个危险**

`tests/mock/replay_fixture.lua` 里,`AbilityCastRange` 的 getter **只在该 key 被声明时才装**
(`if cast_range ~= nil then ...`)。而**三十行之下**,`AbilityDamage` 的 getter 是**给 KV 英雄的每一条技能无条件装**的,
加载器自己的注释逐字写着理由:一条没有 `AbilityDamage` 的技能必须答 0 **因为加载器读了 KV 没找到**,
而不是因为**什么都没装、通用的 `^Get` 兜底替它答了**;两者**「从读数上不可分辨」**,
且**「作为证据并不等价:`lionqdmg` 与 `zusboltcap` 都压在那个 0 上」**。

⇒ **房子已经把这个失效模式诊断清楚、写下来、并对一个 key 修好了;紧挨着它上面的那个 key 没有修,
而一条 armed 的 id 正压在后者的 0 上。** 这不是新发现的问题,是**一次没有推广的修复**。
(`tests/test_blind_a_cmrguard.lua` §3b 解析两处分支,不引用散文。)

### §GD.6 三堵墙,与「这不是 reject」

1. **fixture 路径**:§GD.2/§GD.3。
2. **波次路径**:`cmrguard` 在 **W39/40/41/52/53/54/55/56/57/58** 里**只以全量成员串的一员出现**
   (命中长度 380–501 字节,无一条短串)⇒ **一次都没有被单臂 arm 过**,条件 (b) 也从来没有过读数。
   (与 §GC.1 对 `wandlimbo`/`tpdead` 的同一读法。)
3. **它自己的 promote 门槛结构上够不着**:`state.json:cmrguard_NOT_PROMOTED_20260820` 把 promote 条件挂在
   「**#63 + #66 的修订落地之后**」再重跑 `cmrguard_precision.py`。那两条修订就是 **`cmrcap`** 与 **`esaftershock`**,
   而 `iterations/armed_since.json` 里**两条都没有行** ⇒ **从未 armed 过**;
   `cmrcap` 还额外要求**与 `cmrguard` 同臂**(axeblink 陷阱:单独 armed 逐位无操作)。
   ⭐ 本节另量到比那条注释更强的一句:**只要 range 项是兜底的 0,`cmrcap` 在任何帧上都改变不了判决**
   —— `math.min(0, 200) == 0`,已作为断言钉进 §2c(两份 fixture 上 armed±`cmrcap` 判决逐位相同)。

⛔ **退集不是 reject**:gate(`hero_crystal_maiden.lua:1612`)、helper 体、`X.nRGuardCloseBuffer = 400`、
`X.nRGuardRangeCap = 200` **逐字保留**,`bots/`+`game/` **零 diff**;(c) 逻辑依据成立且未被取代。
重新入集的条件写进 owed 行 `cmrguard_castrange_instrument`,**不留在散文里**。

⚠️ **不掉进 `pullcad` 陷阱,查过了**:`iterations/promote_atoms.json` 里 **`cmrguard` 零次出现**(§3c 钉住),
没有任何一条 atom 的 subject/prereq 点名它 ⇒ 本次退集**没有冻死任何一个 armed 杠杆**。
⚠️ **载体项 7 → 7 逐字不变,量出来的**:`carrier_terms.py --arm` 对 42-id 与 41-id 两串各跑一次,
`TERMS` 行**逐字节相同**(`crystal_maiden` 由 `cmqreach` 承载),`0 unresolved` 两次,`10 hero → 9 hero`
⇒ 选种解空间不受影响。⛔ **W58 及更早不与 41-id 家族并池。**

⚠️ **债不是这一条 id 的**:读敌方 cast range 的调用点**恰好两个**(§3a 钉住),另一个是
`jmz_func.lua:7108` 的 `ccburst` 窗口 —— **已发行、无门、每一局都在跑**。
于是今天**没有任何 fixture 能测那条已发行路径的 delivery 项**,而且错的方向一样。
买这台仪器不是给一条退集候选帮忙。

### §GD.7 诚实边界(本节**没有**做到的事)

1. ⛔ **判定完结 1,不达 owner P4.2 的 ≥2。** 不粉饰:本轮的预算花在**买下让这条裁定成立的读数**
   (sweep + 11 条断言 + 8 发变异台)上,而 §GC 的 ① 逐字只点了这一条 id。
   **不为凑数去裁一条没量过的 id** —— 那正好是 P4.2 想禁止的方向(「推进的度量是集合变小」不是「裁定条数变大」)。
   下一轮的 ① 强制是**再取两条**,从 `verify_coverage.py` 的 `narrat=1` 四条(`campsel`/`pulllane`/`pullthink`/`roamidle`)清起。
2. **没有量 replay 路径**。`tools/batch_test/behavioral/cmrguard_counterfactual.py` 持有 datafeed 锚定的
   per-level cast range 表并**逐字声明它是 out-of-frame 锚**,所以那条路径**够得着转轴** ——
   这正是 `cmrguard` 与 `wandlimbo`(两端都瞎)的分野。本节**没有重跑它**:语料在 S3,
   重读归录像组,且 2026-08-20 的裁定**本来就点名要这次重读**(见 owed 行)。
3. **没有做「桩转轴普查」**(§GC 的 backlog 99):本节是它的第三个实例,不是它的落地。
4. **没有买仪器**。两半(KV roster 扩到 hard-CC 载体 + getter 无条件装)都只登记进 owed 行。
5. **没有重新解释 2026-08-20 的 precision ~40% / recall 1/4**:那些数出自 replay 路径,本节不碰它们。
6. **patch 检查本轮未做**(低频;上一次 §GA.0 做过,无新 patch)。

---

## §GF 2026-09-09T04:xxZ 总监:**`pulllane` 与 `pullthink` 退回出集(39 → 37)** —— 本节最该被读的是 **§GF.3:同一个加载器里同时住着两种失败模式,而只有一种会举手**;`narrat=1` 一档就此清空

### §GF.0 一句话

`pulllane` 与 `pullthink` 退回出集,armed **39 → 37**。**判定完结 2**(达 owner P4.2 的 ≥2)。
零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、`DECISIONS_NEEDED` +0。
取活依据是上一轮「下次触发」的 **①**(逐字点名 `verify_coverage.py` 的 `narrat=1` 仅剩这两条,
并逐字警告 `pulllane` 的门**带空格**)。这两条清完,**`narrat=1` 档从四条降到零**。

### §GF.1 判据:与 §GC/§GD/§GE 同一把尺

(a) 问的是「这个输入到底出没出现过」,不是「给定这个输入决策对不对」。两条 id 各有绿测试
(`tests/test_pullthink_anim_throttle.lua` 在自己头部逐字承认它 **injects the activity**;
`pulllane` 的子句用手搭的路径喂),那些测试都没错,**错的是把它们读成 (a)**。

### §GF.2 `pullthink`:两个操作数各自独立地死

门是一条合取 `bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink')`,守的是
`J.Utils.IsBotThinkingMeaningfulAction` 的提前 return 跳不跳。armed 腿要与 baseline 腿有差别,
**两个操作数都得成立**,而语料把它们**各自独立地杀掉**:

* **作用域项** —— `bot.roamCampPull` 由 `J.ShouldPullNeutralCamp` 写入,而后者
  **在全上门 + 强制 turbo 之下仍然 1100/1100 返回 nil**(原因见 §GF.5)。构造性不可达。
* **节流项** —— `IsBotThinkingMeaningfulAction` 在 **1100/1100 句柄上为 false**。
  ⭐ 关键在于:**它为 false 时 baseline 腿也不提前 return** ⇒ 两条腿在语料**每一帧逐字节相同**。
  失败**向关**:杠杆不开火,读数回来是「测了,没效果」,**没有任何计数会举手**(与 §GE 同向)。

机制:`bot:GetAnimActivity()` 未被加载器 spec,落 `bot_api.lua` 的 `^Get -> 0` 兜底,
**1100/1100 读 0**,而 0 不是引擎会发的任何 `ACTIVITY_*`。

### §GF.3 ⭐⭐⭐ 主轴:同一个加载器,两种失败模式,只有一种举手

两个输入都不在语料里。加载器对它们的处理**方向相反**:

| 输入 | 加载器行为 | 后果 |
|---|---|---|
| `GetLaneFrontLocation` | **拒答,并自报家门**:`LOADER REFUSES: … is unresolved (GH #61). The dump does not carry lane fronts; do not compare against (0,0,0). Declare your assumption …` | 9 帧当场报错,**看得见** |
| `GetAnimActivity` | **静静答 0**(`^Get -> 0` 兜底) | 1100/1100 读 0,杠杆静默失效,**没人举手** |

**同一个加载器、同一类缺失数据、相反的失败方向 —— 而拒答那一种就是解药,并且已经实现好了。**
⇒ 连续三轮的主轴都是「一次没有推广的修复」:§GD.5(`AbilityDamage` 无条件装、紧邻的
`AbilityCastRange` 没装)、§GE.3(`GetItemSlotType` 修了、`GetCurrentActionType` 没修),
**而本轮漏掉的不再是一个姊妹 getter,是一条加载器只对一个 getter 执行、对其余一概不执行的策略**。
⇒ **可迁移的处方**:凡是有 gate 压在上面的 getter,加载器应当**拒答**(像 `GetLaneFrontLocation`),
**不是答 0**(像 `GetAnimActivity` / `GetCurrentActionType` / `AbilityCastRange`)。
这三条 getter 正好是前三轮各自烧掉一整轮才挖出来的那三个。

### §GF.4 ⭐⭐ 第二件:源码注释自己的理由已经过期

`mode_roam_generic.lua:210-211` 逐字写着
「ACTIVITY_* are undefined globals under the mock, so utils.lua builds meaningfulActivities
as an **EMPTY table**」,并把它当作「this line reads false locally」的**两条独立理由之一**。

**实测为假。** `api.install` 把未知 ALL_CAPS 解析成 ≥1001 哨兵 ⇒ `ACTIVITY_RUN` **1153**、
`ACTIVITY_ATTACK` **1154**、`ACTIVITY_ATTACK2` **1155** …… 那张表是**满的**。
判据是唯一能定案的那种:**注入一个真哨兵,节流项当场翻 true**(`[2c]`,`GetAnimActivity=1154 ⇒ true`)。

**结论活着,两条理由死了一条** —— 纪律 4 的野生标本(对的答案骑在一条**已经不成立**的理由上)。
⭐ 且有实际后果:表既然是满的,`GetAnimActivity` 就是加载器**够得着**的一个 getter ⇒
`pullthink` 的节流项是这四轮裁定挖出的四个仪器缺口里**最便宜的一个,dumper 一行都不用动**。
`[2c]` 特意断言那句过期注释**仍在源码里**,所以**修好它的那一天这条断言会自己变红** ——
断言与它的主题一起退休,而不是悄悄活得比主题久。

### §GF.5 `pulllane`:第一个假设是错的,是阳性对照说的

转轴是 `J.ShouldPullNeutralCamp` 营地循环的第三条子句
`J.IsCampBesideLane( camp.location, tLanePath )`,`tLanePath` 由 armed 时 21 次
`GetLocationAlongLane` 采样搭成。

⚠️ **自己送上门的读法是错的。** `GetNeutralSpawners()` 在 **110/110 帧为 `{}`**(0 个营地句柄),
于是「营地名册就是那堵墙」看着成立 —— 而那正是 §GE 判 `campsel` 用的墙,**顺手复用极其诱人**。
**阳性对照否掉了它**:上门、强制 turbo、**再喂一个距 bot 600u 的合成己方营地**,
读数**纹丝不动**(non-nil **0/1100**,`J.IsCampBesideLane` 被调用 **0 次**)。

**归属清单(全 1100 句柄,每一个停在哪)**:

| 停在哪 | 数量 | 性质 |
|---|---|---|
| dead | 79 | 诚实域过滤 |
| `IsCore` | **929** | 诚实域过滤(这是 pos-4/5 杠杆,语料以核心为主) |
| 时间窗 60-360s | 67 | 诚实域过滤 |
| :12/:42 刻 | 14 | 诚实域过滤 |
| 800 内有敌 | 2 | 诚实域过滤 |
| `nLane == nil` | **0** | **GH #648 的论点实测成立**:引擎答 `LANE_NONE == 0`,那条 guard 打不响 |
| 够到 lane front | **9** | **而这 9 条上加载器全部拒答** |

⇒ **语料里能把问题问出口的只有 9 帧,仪器在这 9 帧上全部拒答。** (a) 买不到 ——
但诚实的说法是「**lane front 不在 dump 里**」,不是「没有营地」。
这个 9 同时是给买单人的报价:**一笔小而准的采购,不是全语料改造**。

### §GF.6 量具与自查

* `tests/test_blind_a_pulllane_pullthink.lua` —— **13 checks / 0 failed**。
* `tools/agent/mutstand_blind_a_pulllane_pullthink.sh` —— **13 CAUGHT / 0 SURVIVED / control_ok=1**,
  五文件还原走树外副本 + 每轮 `git diff --quiet` 校验。
* ⚠️ **M8 第一次 SURVIVED,而它是对的、断言是错的**(纪律 2,**第四次**)。
  `[1e]` 原本**把 helper 的五条域过滤逐条抄进测试**再数存活者;M8 把 helper 自己的拉野窗口
  6min 拉到 12min,测试**纹丝不动地绿着** —— **抄来的域看不见域在动**,那个「9」是关于**测试**的数,
  不是关于 helper 的数。改成**驱动真 helper、数够到拒答的帧**(够到拒答 ⟺ 通过全部过滤),
  一个字都不抄,M8 当场 CAUGHT。**与前三次同形:针脚比它要钉的东西宽/偏。**
* ⚠️ **`test_corpus_scale` 检测器当场逮到本轮自己的新文件**(`assert(nFrames == 110)`,GH #106/#127 的
  耦合面),已按它指定的 `tests/corpus_scale.lua` 改写(`corpus`/`universal`/`ratchet`);
  **零claim 保持等式**(模块自己写明「deliberately not softened」)。检测器复跑 **10/0**。
* ⚠️ **`lua5.1 <sweep> ` 退出 0 且零输出,那不是通过**:mock 的 `api.install` 把 `_G.print` 换成
  no-op(引擎没有控制台),于是 print 式 sweep**长得和干净跑完一模一样**。改走 `io.stderr` 才见读数。
  这是纪律 3 家族的**新形状**(不是管道吃退出码,是**被测环境吃掉 stdout**),登记备查。

### §GF.7 本节没有做的事(边界)

1. **没有买任何仪器**。两条的缺口都只登记进 `iterations/owed_executions.json`。
2. **没有 reject 任何杠杆**:gate、helper、`PULL_CAMP_LANE_GAP = 1200`、两个 `pullthink` 半边
   **逐字保留**,`bots/`+`game/` 零 diff(`[3c]` 钉住)。
3. **没有动 `pullcamp`**:它仍在集内。但它的历史读数是与 `pulllane` **同 armed** 取的,
   退掉后 `tLanePath = nil` ⇒ `J.IsCampBesideLane` 首行 `return true` ⇒ **逐字节 no-op**(已核源码),
   `pullcamp` 回到 §4 之前的选点行为。⛔ **W58 及更早不与 37-id 家族并池。**
4. **没有落地「桩转轴普查」**(§GC 的 backlog 99):本节是它的**第四个实例**,不是它的落地。
5. **没有跑动态半全量**(~100min,GH #124);`bots/` 零 diff,静态门与两个针对性套件已过。
6. **patch 检查本轮未做**(低频;§GA.0 做过,无新 patch)。

---

## §GG 2026-09-09T10:xxZ 总监:**`narrat=2` 四条的裁定 —— 一条也不退集**;本节最该被读的是 **§GG.2:前四轮把「(a) 买不到」量在了错的那条路上,而另一条路上的仪器一直躺在仓库里**

### §GG.0 一句话

`liondrainstop` / `ownhalf` / `pulldrag` / `tpgap` 四条(`verify_coverage.py` 的 `narrat=2` 一档)
**全部裁为「不退集」**:条件 (a) 的失效**不是「买不到」,是「投递没做」**(§FB.2 的第二类,
逐字不许与第一类混着写)。armed 串 **37 不变**,`bots/`+`game/` **零 diff**,零 AWS、零波次,
不发 owner 邮件,`DECISIONS_NEEDED` +0。产物:量具 `tools/agent/a_evidence_route.py`
(+ `tests/test_a_evidence_route.py` 32 检查 / `tools/agent/mutstand_a_evidence_route.sh`
**6 CAUGHT / 0 SURVIVED**),`owed_executions.json` **+4 行**,顺手修掉一条 trunk 红(§GG.5)。
取活依据是上一轮「下次触发」的 **①**(逐字点名这四条,并逐字要求 `pulldrag` **先查再裁**)。

### §GG.1 判据:三个机器读数并排,而不是第四次手工定价

前四轮(§GD/§GE/§GF)每轮用**整整一个工作单元**给一到两条 id 手工定价,结论都是「(a) 买不到 ⇒ 退集」。
本轮先问一个更早的问题:**这条 id 的 (a) 有几条路可以买?** 三个读数就够分辨:

| 读数 | 问的是 | 来源 |
|---|---|---|
| `verify` | 有没有过判决 | `verify_coverage.py` 的同一条正则、同一份语料(不许两个计数器漂移) |
| `waves` | 语料存不存在 | `W*_wave.json` 的 **`arm_string` 字段**(⛔ 不是全文子串:那些记录的散文里点名的是**被撤下**的 id) |
| `tools` | 仪器存不存在 | `tools/batch_test/behavioral/*.py` 的**主题句**是否点名这条 id |

⚠️ **分母会随仓库长,类计数不一定跟着动**:本节的读数取自裁定时刻的树
(`reports 192`);同一轮 rebase 到 `48a74f7c` 之后复跑为 `reports 193`,而
**五类计数逐位相同**。引用本节时引类计数,分母只作「这一次读了多少」的记录。

分类(五类,互斥且穷尽,由工具自己断言):`VERIFIED` / `DELIVER`(有语料 + 有主题句点名的仪器)/
`MENTION`(有语料,但只在别人正文里被点名)/ `BUILD`(有语料,无任何仪器)/ `NO-CORPUS`(没进过任何 arm 串)。

### §GG.2 ⭐⭐⭐ 主轴:全 37 条 armed id 的读数是 `VERIFIED 22 / DELIVER 12 / MENTION 3 / BUILD 0 / NO-CORPUS 0`

**15 条没有判决的 id,没有一条是「买不到」。** 每一条都在 **≥7 波**的 arm 串里活过(15 条全部 10 波,最近 W58),
12 条有工具在**自己的主题句**里点名它。§GD..§GF 三轮的退集判据全部来自 **fixture 加载器**那条路——
而 (a) 有**两条**路,另一条(批测录像上的行为检测器)**不经过加载器**,且对这 12 条**已经存在于 trunk 上**。
⛔ **这不推翻 §GE/§GF 的三条退集**(那三条判的是各自转轴子句在语料里问不出口,读数仍成立);
它说的是**提问顺序**:先问「哪条路」,再决定要不要花一轮去 fixture 侧定价。

**先例不是推理**:09-05(§FB)对 `tpdying`/`tpreach` 开的两行 owed(同样的「投递没做」形状),
**09-08 两行都被结清**(`iterations/reports/replay-check/a_evidence_tpdying.md`
`VERIFY id=tpdying verdict=INDETERMINATE episodes=4527`、`a_evidence_tpreach.md`
`VERIFY id=tpreach verdict=WORKING episodes=59`),**2/2,约 3 天**。⭐ 而那两条当时是**已经退集**才去买的 ——
**退集并不是买到 (a) 的前提**,这一条钉死了本轮「不退集」的选择。

### §GG.3 四条的逐条裁定

* **`pulldrag` DELIVER** —— `pulldrag_walk.py` 主题句逐字「(a)-evidence for the `pulldrag` soak candidate:
  WHICH WAY does the puller walk between pokes?」。⚠️ 上一轮警告的「大概率同一堵 lane-front 墙」
  **查过了,不成立**:`gated_getter_stub_census.py --id pulldrag --all` 打的是 `GetAssignedLane` **STUB0**
  —— 那是 **fixture 那条路**的墙,而这条 id 的仪器**不走 fixture**。**先查再裁的那一步救下了一次搬结论。**
* **`tpgap` DELIVER** —— `tpgap_domain.py` 主题句逐字「`tpgap` condition (a): does the gap-band retreat
  guard actually refuse?」,且**读数早在 `queue.json:strategy-14` 预登记**(方向收窄 ⇒ 子域内按压下降 +
  反向哨兵不塌,⛔ 不是「按压数必须下降」)。桩普查对它 **零 STUB0**。
* **`liondrainstop` DELIVER** —— `lion_drain_census.py` 主题句逐字「`liondrainstop` condition-(a) census」;
  ⚠️ 判据已被总监 2026-08-21 换过(`span>=2.0s` 与结局**共因**),现行是 **post-domain residual**,门槛 GH #86 §5。
* **`ownhalf` MENTION,与上面三条不是同一件事** —— 全仓**没有任何检测器在主题句点名它**;
  它唯一的出现是 `capmono_refusal.py` 正文把它当作 capmono 的**混杂因子**
  (逐字「`ownhalf`/`overchase`/`l1trade`/`l5combo` push the other way」)——**反过来的意思**。
  ⇒ 采购是**建仪器**,不是跑现成的。⛔ 仍然**不是**「(a) 买不到」:语料在,缺的是仪器,而**缺仪器是报价不是否决**。

### §GG.4 量具自己的两条纪律(它们是本节能被引用的理由)

1. **分母全打印,空分母 abort**(exit 2)。没有 wave 记录 ⇒ 全体 `NO-CORPUS`;没有检测器 ⇒ 有语料的全体 `BUILD`;
   **两种错误都长得像一次跑完了、发现债很多的普查** —— 与 §GG 前一轮那份普查的 `strip_comments` 两发同族。
2. **`DELIVER` 是「有工具在主题句点名它」,不是「这工具答得对/跑得通/域非空」**;`BUILD` 是「还没有仪器」,
   **不是「买不到」**。两条 LIMIT 逐字写在工具输出的末尾,引用本节必须连它们一起引。
   ⭐ **`MENTION` 这一类是量出来的,不是设计出来的**:第一版用**文件名**判归属,把 `liondrainstop`
   判错(它的仪器按英雄命名:`lion_drain_census.py`);第二版用**头部任意位置**,把 `ownhalf`/`overchase`
   抬成 `DELIVER`(混杂因子句)—— **两个错误方向相反,主题句是同时挡住它们的那条线**,四份手读的 docstring 是它的判据。

### §GG.5 顺手修掉的一条 trunk 红([harness],章程 2a):`test_stale_waits.py`

自检 `trunk-red(python)` 唯一那条。`stale_waits.wait_scopes` 的「借用规则」——
一个带 outstanding 标记而**不点名任何 id** 的子句,借上一子句的 id —— 判「不点名 id」用的是
**id 形状的反引号**(`BACKTICKED`)。于是 batch-desk 章程里这一句:

    …**`FROZEN none`**(`pullcad` 陷阱未复发);入集等待 `no expired admission wait`(6 章程 / 55 已结 id)

的第二个子句**明明点名了自己的主语**(自检腿的逐字输出,而且那句话的意思是**没有任何等待**),
却因为主语不是 id 形状而被判「无主语」⇒ 借来 `pullcad` ⇒ 报成一条 STALE。
**危害不是那条红本身,是它的处方**:测试逐字写着「fix the charter line, do not loosen this test」,
指向**另一个组**的、**内容完全正确**的一行散文。
修法:借用规则改判**任意反引号**(`ANY_BACKTICK`),id 抽取仍用 `BACKTICKED`(窄的那个问题保持窄)。
钉法:`tests/test_stale_waits.py` 新增 INVARIANT 8(f)/(f2) —— 现场那一行的最小复现 + (c) 不被误伤;
把修改还原 ⇒ 两条同时变红(实测 `MUT_EXIT=1`),还原后 **49 检查 0 失败**;
`mutstand_stale_waits_report.sh` 复跑 M1–M5 全 CAUGHT、`RESTORE ok`(M6 `SKIPPED` 是存量形状,非本轮引入)。
代价已写进工具 LIMIT 5b(「等 \`见上\` 裁定」这类写法会漏报 —— **少报不是造假**,方向与 LIMIT 4 一致)。

### §GG.6 本节没有做的事(边界)

1. **没有 promote、没有退集、没有 reject**,armed 串 **37 一字未动**;`bots/`+`game/` 零 diff。
2. **没有给另外 11 条 DELIVER/MENTION 开 owed 行**:本轮只为**读过 docstring 的四条**开(4 行)。
   把它推广成「按普查自动开行」是 GH #540 的内容,**仍未做**。
3. **没有跑任何检测器**:本节买的是「该跑哪一个」,不是读数。域是否非空、工具能否跑通,**都不在本节的声称里**。
4. **没有核语料保留**:`waves` 说的是这条 id 在 arm 串里活过,**不是** S3 上那批 `.dem` 现在还在。
   录像组取棒时要自己确认;拿不到就说拿不到(那本身是一条关于语料保留的发现)。
5. **没有跑 Lua 动态半全量**(~100min,GH #124);`bots/` 零 diff。
6. **patch 检查本轮未做**(低频;§GA.0 做过,无新 patch)。

---

## §GH 2026-09-09T1x:xxZ 总监:**并池 key 与闸 (ii) 一次裁完(批测台 15:13Z 交棒 1+2)** —— 本节最该被读的是 **§GH.3:这两条交棒是同一个事实读两遍,方向相反;而「可达代码相同」这个事实,按闸 (ii) 的旧措辞只被读成「没有新东西可测」,于是那一波的钱花掉了、它买到的唯一那样东西被扔掉**;以及 **§GH.2:批测台没查、而唯一能推翻结论的那条腿 —— gate 谓词自己是被调用的**

### §GH.0 裁定摘要

| 交棒 | 裁定 |
|---|---|
| 2「并池 key 请定名」 | **key 既不是成员串也不是树 SHA**,是**该臂串下两条腿实际执行的程序**。⇒ **W60 + W61 并池**,家族深度 2,至多 **8 粒配对种子** |
| 1(a)「W61 这样的复制波可不可以发」 | **本轮不予追认:没有任何一条腿授权它起飞**。⛔ 但「起飞未获授权」与「产出是浪费」是两句话,**第二句是假的**(见 §GH.3) |
| 1(b)「给闸 (ii) 一个可执行体」 | **准,但闸 (ii) 的措辞先要改**;⛔ 新措辞的第三条腿**本轮不生效**,因为它缺一个数(§GH.4)。已开 owed 行 |

零 AWS 花费(本轮总监未动 AWS)。`bots/`+`game/` **零 diff**。armed 串 **37 不动**,无 promote、无退集。

### §GH.1 先把事实摆干净(总监本轮**独立复核**,不转载批测台)

批测台 §三 的三份输入我逐条自己读了一遍,读法与它无关:

1. **臂串**:直接从 `test_set.md` **第 2 行**(不是第 3 行的散文)`split(',')` + md5 ⇒
   **37 ids / 335 bytes / `b525d51d4b4957e0e40f22f203aea641`**,与 W60、W61 两份 `arm_md5` **逐位相同**。
   `hrparity` **不在其中**(既不是列表成员,**在整行里也不作为子串出现** —— 两种查法都做了,因为
   「成员判定」与「子串判定」在 §GG 上刚刚给出过 13 波 vs 10 波两个不同的数)。
2. **树差**:`git diff f25680bc 252a5781 -- bots game` ⇒ **一个文件,+38 / −0**
   (`RC_EXIT=0`,走 `rc.sh`)。逐行读:30 行注释 + `if J.IsModeTurbo() and J.IsSoakCandidate( 'hrparity' )` +
   `then` + **两行 body(都只重绑一个 `local nOurs`)** + `end` + 空行。
   ⭐ **没有新增任何顶层 / `J.*` 定义** ⇒ 全局命名空间不变。这一条批测台没写,而它是
   「gate 后面的东西不可达」之外**另一条必须成立**的腿:一个写在 gate 块外面的新 `J.Foo` 会被别处调用,
   与 armed 与否无关。

### §GH.2 ⭐⭐ 批测台没查、而唯一能推翻结论的那条腿:**gate 谓词自己是被调用的**

「body 在未 armed 的 gate 后面 ⇒ 不可达」**不足以**推出「两波执行同一个程序」。
`J.IsModeTurbo()` 在 Turbo 下**为真**,`and` **不短路** ⇒ `J.IsSoakCandidate( 'hrparity' )`
**每一次经过 `GetLaneHarassResponse` 都真的执行了**。W61 的两条腿都比 W60 多跑这两次调用。
它们安全,**不是因为不可达,是因为纯且带缓存**(逐行核过源码):

- `GetSoakSideConf`(`jmz_func.lua:4998`)memo 进 `tSoakSideCache` ⇒ `dofile` 每个 VM **至多一次**,不是每次调用一次 I/O;
- `SoakStrArms`(`:5017`)纯字符串匹配;
- `J.IsModeTurbo`(`:11671`)memo 进 `bModeTurboCache`。

⇒ 无 I/O、无引擎调用、**无 RNG 抽取**、无副作用,返回值被丢弃。

⛔ **这条腿是可以反过来的,而且反过来就会翻盘**:两个谓词里**只要有一个抽 RNG**,
多出来的调用点**本身**就会让两波的对局序列 desync —— **臂串逐字相同也救不了**,
并池就是错的。⇒ **「可达性」不是判据的全部,「新增调用点的副作用」是它的第二半。**
本节把这一半写进判据,不是写进脚注。

### §GH.3 ⭐⭐⭐ 主轴:两条交棒是同一个事实读两遍,而旧措辞只读了让钱白花的那一遍

「W61 的可达代码与 W60 相同」这**一个**事实:

- 按闸 (ii) 的**严格读法** ⇒ **没有新东西可测**(批测台 09-05 据此拒发过同型波);
- 按并池 key ⇒ **两波测的是同一个东西** ⇒ **可以并池** ⇒ W60 的 4 粒 + W61 的至多 4 粒 = **深度 2**。

⇒ **闸 (ii) 的措辞自己有缺陷,不只是缺可执行体**:它把「**新代码**」当成了「**新信息**」。
家族深度低于 promote 门槛时,**同一臂串、可达代码相同的下一波买到的正是整个环里最稀缺的东西 ——
同一个问题上更多的配对种子**。那恰好是 promote 条件 (b) 要的量,也恰好是
**连续五波开新家族**(批测台上一轮头号交棒)结构上买不到的量。

⇒ 只读「没有新东西可测」的规则,会**先把这一波的钱花掉,再把它买到的唯一那样东西扔掉**。

### §GH.4 闸 (ii) 新措辞,以及**为什么第三条腿本轮不生效**

闸 (ii) 通过,当且仅当以下之一成立:

1. 臂串与上一波不同;**或**
2. 该臂串下**可达代码**与上一波不同(判据 = §GH.1 的两腿 **且** §GH.2 的副作用腿);**或**
3. 该家族的**配对种子深度**低于 promote 门槛,且该家族有一个活的 promote 问题。

⛔ **第 3 条腿本轮不生效,理由是它缺一个数**:我**没有**核实过 promote 门槛在
「配对种子数」上到底是几。`AGENTS.md` 的 batch-runner 侧写写着「4-seed promote bar」,
而 README **铁律 2(2026-08-01)明确取代了旧的 4-seed 显著性检验**,换成三条件,
其中 (b) 是**粗粒度**的;三条件里**没有任何一处**把 (b) 钉到一个种子数上。

⇒ **一道门槛没写出来的闸,不是闸,是另一段散文。** 我不肯用一段散文换掉另一段散文
(那正是交棒 1(b) 立案的形状)。第 3 条腿**写下来但挂起**,直到那个数被裁定。已开 owed 行。

⇒ **连带结论,先说难听的那句**:限 (1) 否、限 (2) 否、限 (3) 未生效
⇒ **W61 的起飞没有任何一条腿授权**。⛔ **不予追认**,不给它补一个事后的理由。
批测台自己把这一条登记成 breach 而不是 pass,是对的;归因也是对的
(四道闸里唯一没有可执行体的那道,正是唯一裁定落在钱后面的那道)。

⭐ 但**「未获授权」与「产出是浪费」是两句话**:第二句**假**。W61 的四粒进 W60 的池,
是自 W52 以来第一个深度 2 的家族。**钱已经花了,读数是真的,扔掉它不会把钱要回来。**

### §GH.5 ⛔ 并池的限度(写在这里,免得被读过去)

1. **并的是「种子」,不是「局」。** ⭐ **这是第一次跨波并池,于是铁律 4 (i-d) 第一次真正吃劲**:
   两波**几乎必然交出不同的局数**(W60 4/4 计分;W61 可能被回收)。
   把 8 粒**按局加权**并池,就是把 (i-d) 那个缺陷**在波次尺度上原样装回来**
   (`按局加权 = arm + side·(N_ab−N_ba)/(N_ab+N_ba)`)。
   ⇒ **每粒先 swap-average,再对全部 8 粒取算术平均。**
   ⛔ 同样禁止**把两波各自的池化均值再平均一次** —— 种子数不等时那是 mean-of-means,
   **同一个缺陷升一层**,而且长得更像一个正当操作。
2. **GH #269 的 `min_arm_depth` 是另一个「深度」,照旧逐粒生效**:薄腿的种子在**进这 8 粒之前**被丢掉,不是之后。
   ⚠️ 本节的「家族深度」= 配对**种子**数;#269 的 `arm_depth` = 一粒之内每条**腿的局**数。
   **两个量都叫 depth,不许混。**
3. **本节裁的是「行为同一性」,不是 `hrparity`。** 不 arm 它、不裁它、不给它买任何东西 ——
   `hrparity` 只能在**arm 它的那一波**上被测。
4. **不是「臂串相同就能并池」的通行证。** 两条腿缺一不可;树差一旦碰到**未 gate(已 promote)的代码**,
   哪怕臂串逐字相同,两波在**两条腿上**都不同 ⇒ **不可并池**。成员串对未 gate 的代码**一个字都说不出来**。

### §GH.6 本节没有声称的东西

1. **没有跑 Lua 动态半全量**(~100min,GH #124);`bots/`+`game/` **零 diff**。
2. **没有给闸 (ii) 写可执行体**(交棒 1(b) 准了,但那是下一个工作单元;owed 行已开)。
3. **没有裁 promote 门槛的那个数**(§GH.4);⇒ **没有对 37-id 串做任何 promote/reject 判定**。
4. **没有核 W61 的收割结果**(本轮它还在天上);本节裁的是**并池规则**,不是任何读数。
5. **没有裁交棒 3(AZ 环,GH #664)/ 4(闸 iv 按需波)/ 6($80 围栏预支)** —— 6 上一轮已裁「本波不跨」,W61 已发完,下一波仍须**跑工具**求围栏值,不许抄数。

---

## §GI 2026-09-09T22:xxZ 总监:**批测台 21:08Z 交棒 2 与 3 一次裁完(`headroom $0.292` 的下一步 / W61 四粒种子第二轮)** —— 本节最该被读的不是那两条裁定,是 **§GI.3:裁「等月初重置还是现在升级」时,顺手读到围栏那件仪器自己在说谎 —— 它把一个区域的读数印成 `account-wide`,而它保护的预算没有区域过滤器**;以及 **§GI.2:「等月初重置」这句话里藏着一个数,而那个数是 `$50` 不是 `$80`**

### §GI.0 裁定摘要

| 交棒 | 问题 | 裁定 |
|---|---|---|
| 2(GH #677) | `headroom $0.292`,下一个发波轮结构上发不出任何一波。等月初重置,还是现在把「外来支出占 MTD 过半」升级给 owner? | **两个都不选,而两个都有一半是对的**:围栏**照旧成立,下一个发波轮不发波**(§GI.1);「等重置」**作为计划被否**,因为重置后的天花板是 **`$50` 不是 `$80`**(§GI.2);「现在升级」**作为一封新邮件被否**,因为这个问题**已经在 owner 手里**(W36 邮件第 15 条,09-06 发出),本轮以**增量**入 `DECISIONS_NEEDED` 等周日的 W37 那封(§GI.4)。 |
| 3 | W61 那四粒种子(10208/10212/10390/10526)一局没跑就作废,要不要退回可用窗口? | **退回。** 判据不是「烧没烧过」而是「**S3 上有没有留下语料**」,而那个判据**已经是选种时在跑的那一条**(`seed_roster_index.py` 的交集检查),**不需要任何新表**(§GI.5)。 |
| (本轮量到,非交棒) | `wave_fence.py` 的 accrual 检查声称 `account-wide`,实读一个区域 | **修了**(RULING 5):枚举账户全部已启用区域逐区读;枚举拿不到就**退回配置区域并降级措辞而不是降级门**。4 CAUGHT / 0 SURVIVED(§GI.3)。 |

### §GI.1 围栏本轮照旧成立,而「不发波」是裁定不是等待

批测台 21:08Z 的读数原样转载(**总监零 AWS 调用,不作新声称**):MTD **`$74.308`**(免费 `budgets`,`refreshed 2026-09-09T20:23:37Z`,CE 复核 `74.3077543792` 逐位一致),W62 四台按需已起飞,闸 (iii) 现推 `headroom $0.292`。

⇒ **下一个发波轮不发波。** 理由不是「余量不够」这句体感,是**围栏那件工具会拒绝**,而**它必须当轮现跑** —— `wave_fence.py` 自己在 CLEAR 行上逐字写着「Do not copy $80.00 into a report as next month's number; re-run the tool」。⛔ **本节不预支任何跨线许可**,三条线(围栏 = 下一个未跨的 owner 告警档 / 刹车 `$90` / 批准线 `$100`)**一个字未改**。

### §GI.2 ⭐⭐⭐ 「等月初重置」这句话里藏着一个数,而它是 `$50`

围栏不是常量,是**下一个尚未跨过的 ACTUAL 告警档**(`wave_fence.py` RULING 1)。今天 MTD `$74.308` 已越 `$50`,所以围栏读作 `$80`。**10-01 ActualSpend 归零,`$50` 随之变回「未跨」⇒ 围栏回到 `$50`,不是 `$80`。**

**这不是我的算术,是那件工具的离线读数**(操作数由我给,`--actual 0.0 --limit 100 --thresholds 50,80,100 --planned 1.10 --pending 0.0`):

```
fence            : $50.00   <- lowest ACTUAL alert not yet crossed (Ruling 1)
operative ceiling: $50.00   = min(fence, brake)
headroom         : $48.900 after this wave
WAVE_FENCE: CLEAR (exit 0)
```
⚠️ 同一次输出里工具自己打了两行免责,一并抄在这里而不是抹掉:`source : OFFLINE (--actual/--limit/--thresholds). This is for tests and post-hoc audit; a launch must use the AWS read.` 与 `accrual check : SKIPPED, NOT CERTIFIED (offline mode: no live account to enumerate). $0.000 below is an assumption, not a reading`。⇒ **`$48.900` 是重构不是预报**;10-01 那天的数**必须当场跑活路径求**。

⭐ **为什么这一条是本节的主轴**:「等月初重置」听起来像「产能全部回来」,而它实际给的是 **`$50` 的天花板,不是 `$80`** —— 少 `$30`,**失效方向是往多花钱那一侧**。这与 `wave_fence.py` 头注释立案的那个缺陷**是同一个**(一个派生值被当字面量记住,而它的输入自己按月在动),**只是晚了一个月、换了一个人**:上次是 `$80` 被缓存,这次是「重置 ⇒ 回到 `$80`」被默认。

⇒ 连带一句必须写下的推论:若那笔外来支出仍在按 09-05/09-06 的节奏计费(上一轮实测**占 MTD 的 54.9%**,`$74.308 × 54.9% ≈ $40.8` / 9 天 ≈ **`$4.5`/天**,⚠️ **这是把区间平均摊开的算术,不是一条实测的日曲线**),那么 10 月的 `$50` 会在**十天出头**被吃光,而 owner 会在那时收到一封写着「dota2bot-batch 超过 50%」的邮件 —— **邮件里的大头不是本实验室花的**。「等重置」因此不是一个计划,它是一次**把同一件事推迟三周再发生一遍**。

### §GI.3 ⭐⭐ 裁这件事时读到的:围栏那件仪器自己在说谎(已修,RULING 5)

**发现**:`wave_fence.py` RULING 4 的 accrual 检查逐字打 `CERTIFIED (0 accruing instances account-wide, read this run)`,docstring 写 `the enumeration is ACCOUNT-WIDE ON PURPOSE`。**而 `ec2 describe-instances` 是区域调用**,`tools/batch_test/aws/bootstrap_creds.sh` 往 `~/.aws/config` 写死 `region = us-west-2`,`_awsx` 不传 `--region` ⇒ **读的是一个区域,印的是账户**。它保护的 `dota2bot-batch` **没有 CostFilters,也没有区域过滤器**。

⇒ 一台在 `us-east-1` 烧钱的 `c7a.16xlarge`,对这道门**逐字不可见**,而门打的是 CERTIFIED。**失效方向:往多花钱那一侧;形状:静默**;并且**恰好在花钱最多时最要紧** —— 与该文件为之而写的那个缺陷同族。⚠️ 它和本轮的主题不是巧合:`headroom $0.292` 唯一被点名的成因就是外来算力,**而本农场的泄漏检查也是 `us-west-2`(区域取自 `aws.env`)** ⇒ **两条独立的「零」，覆盖的是同一个区域**。

**修法(RULING 5,已落地)**:`ec2 describe-regions`(免费)枚举账户已启用区域,逐区 `describe-instances`,行上带 `region`;拿不到枚举(受限用户可能没有 `ec2:DescribeRegions`)就**退回配置区域并降级措辞**:零打成 `CERTIFIED WITHIN SCOPE ONLY`、附 `accrual scope :` 行、裁决行之后再追一行 `WAVE_FENCE SCOPE :`(**让免责跟着那句会被抄进报告的话走**)。
⛔ **故意不做成 exit 2**:把标签缺陷升级成永久发波中断是**政策改动**,而失效方向本来就是「诚实的标签」够用;把已经被围栏挡住的台子再断一次不是修理。
⚠️ **对批测台的告知(下一轮就会撞到)**:若真有外来实例在别的区域计费,闸 (iii) 会从 CLEAR **变成 UNCERTIFIABLE (exit 2)**(未给 `--pending` 时)。**那是修法在生效,不是回归** —— 处置是照 RULING 4 给 `--pending`,不是绕过。

**证据**:`tests/test_wave_fence.py` **71 checks / 0 failed**(改前 57 → 41 是本轮之前的基线;新增 §13/§14 两组);`/tmp/mutstand_wave_fence_scope.sh` **4 CAUGHT / 0 SURVIVED**(M1 旧措辞放回红 3、M2 退回分支自称完整红 2、M3 部分失败读成完整红 1、M4 丢掉 `--region` 红 6),control 绿,还原 `cmp` **逐字节相同**。
⭐ **一处必须留痕的现场**:第一版把「a reading, not a default」这句从降级分支里丢了,**被 2026-09-06 就写好的第 11 条断言当场逮住** —— 那句话与 scope **正交**(一个区域的零**仍然是读出来的**),RULING 5 收窄的是**声称**,不是把读数贬成假设。**我没有去改那条断言,我改回了代码。**
⚠️ **覆盖不是等价**:那两个新增的活 AWS 读(`describe-regions`、逐区 `describe-instances`)**在总监的容器里一次都没执行过** —— 总监不发 AWS 调用、凭据未 bootstrap。已开 owed 行 `wave_fence_ruling5_multiregion_first_read` 去买第一次活路径读数。

### §GI.4 升级给 owner:**不是新问题,是旧问题到期**

⛔ **本轮不发新邮件。** 这个问题**已经在 owner 手里**:`DECISIONS_NEEDED` **第 15 条**(给 `dota2bot-batch` 预算加 `Project` 过滤器 —— 原话「**这一条不是钱的问题,是「我们的刹车会被别人踩下去」**」)随 **W36 汇总邮件 2026-09-06T07:xxZ 已发出**。本轮到达的是**它的后果**,不是一个新问题;把后果重新包装成新问题去消耗 W37 的那一封,是**用一封邮件买一个已经买过的答案**。

⇒ 处置:**以增量形式追加进第 15 条**(两个数:今天 `headroom $0.292`;重置后天花板 `$50` 而非 `$80`),随**周日(2026-09-13)的 W37 汇总邮件**发出。
⭐ **提前发信的触发条件写死在这里,免得下一轮当场凭感觉判**:(甲) RULING 5 的首次多区域读数**真的读到**其它区域有外来实例在计费;或 (乙) MTD 在本农场**未发任何波**的情况下越过 `$80`。二者任一成立 ⇒ 那是「有时限的问题触及边界」,当轮提前发,不等周日。

### §GI.5 W61 四粒种子:**退回可用窗口**(交棒 3)

**裁定**:`10208 / 10212 / 10390 / 10526` **退回**。不建任何「烧过的种子」排除表。

**理由(判据是语料,不是点名)**:重用一粒种子**唯一**的害处,是同一 seed id 下**两套臂串的局被并进同一次池化读数**(铁律 4 (i-d) 同族),而那**要求语料存在**。W61 存了**零个**对象,两条独立读数:S3 `validation/` 末条仍是 W60 第四台 `2026-09-09T10:22:37Z`;`seed_roster_index.py --build` 打 `401 run prefixes in S3, 401 already indexed, 0 to scan` / `nothing new; index unchanged`。

⭐ **而这个判据不需要新建**:选种前那次 `--build` 之后的**交集检查本身就是它**。索引从 S3 建,而每一条把语料读回来的下游路径,源头也是 S3(`recover_verdict.py` 的 pool 目录是 `aws s3 cp` 下来的)⇒ **「不在索引里」⟺「对每一条下游读数都不存在」**,正是重用无害的**充要条件**。

⛔ **不许再维护第二份手工「用过」名单。** 那会在索引之外再造一个由人维护的『用过』概念 —— 正是 `wave_fence.py` 头注释写的那个形状(派生值被写成字面量,而它的输入自己会动),而**索引会动**(每一波都在长)。**右移窗口作为零成本的谨慎没有错**(批测台做得对:它拒绝用花钱的方式替总监把一个未裁的问题定死),**但它不构成先例**:每损失一波就永久退休四粒,种子池天花板(GH #285 已催十二轮)会因为**一次没有产生任何语料的损失**而下降。

⚠️ **失效方向如实记**:若哪天有一条读语料的路径**不经过 S3**(例如实例本地盘直取、或某个只在容器里存在的 pool 目录被并进读数),本裁定的前提就破了。届时要改的是**判据跟着那条路径走**,而不是回头去手工记名单。

### §GI.6 本节没有声称的东西

1. **没有跑 Lua 动态半全量**(~100min,GH #124);`bots/` + `game/` **零 diff**。
2. **零 AWS 调用**:MTD `$74.308`、`headroom $0.292`、外来支出占比 `54.9%` **全部是转载批测台的读数**,不是本轮量的。⚠️ 那 54.9% 上一轮就已登记为**未复查**,本轮仍未复查。
3. **没有裁 `PROMOTE_BAR_PAIRED_SEEDS =`**(owed 行仍欠着),⇒ **本轮无任何 promote / reject 判定**,armed 串 37 未动。
4. **没有核 W62 的收割结果**(它还在天上)。
5. **没有证明「外来支出停了」或「还在继续」** —— §GI.2 那条 `$4.5`/天是**把区间平均摊开**的算术。RULING 5 让那个问题**下一轮免费可答**,本轮没答。
6. **没有给闸 (ii) 写可执行体**(`wave_reachable_delta.py` 仍不存在),**第三轮顺延**。

## §GJ 2026-09-10T01:xxZ 总监:**批测台交回的「前提已变,请复核」(GH #683)** —— 本节最该被读的不是那条裁定,是 **§GJ.2:交回来的那个「变了的前提」在正确的时钟上根本没变;`headroom $0.292 → $2.442` 这一涨,全部来自一扇锚错了时钟的窗**;以及 **§GJ.3:那扇窗的两端各有一个缺陷,而它们是同一个缺陷的两面 —— 没有人在快照自己的钟上算 pending**

### §GJ.0 裁定摘要

| 交棒 | 问题 | 裁定 |
|---|---|---|
| 1(GH #683 甲) | `NO_WAVE_NEXT_LAUNCH_ROUND` 立时的前提是 `headroom $0.292`(发不出任何一波);现在是 `$2.442`(恰好一波 spot)。维持还是解禁? | **维持,而理由不是自由裁量**:那个「前提已变」**在正确的时钟上不成立**(§GJ.2)。按快照自己的钟算,诚实 pending = **`$5.400`**、projected = **`$79.708`**、headroom = **`$0.292`** ⇒ **任何市场的任何一波都塞不进去**。⭐ 而且钱两边都花了 ⇒ **不是「等几小时能飞」,是九月在 `$80` 围栏下已经没有下一波了**(§GJ.4)。 |
| 1(乙/丙/丁) | 若解禁该发什么 / 外来支出硬读数 / `CostFilters` 根因 | **规格(4 粒 → 8 粒加深)不否也不批,它从来没有真的可用过**(§GJ.4);外来 **`$37.435` = MTD 的 50.4%** 收下,**只补进 `DECISIONS_NEEDED` 第 15 条不另发信**(遵 §GI.4),随周日 W37 走。 |
| (本轮量到,非交棒) | `wave_fence.py` 的 accrual 检查用「此刻零台在跑」证「零元未落账」 | **修了(RULING 6)**:窗口锚到预算快照的时钟,cutoff = 快照 − `11.3h`;窗内有波 ⇒ `exit 2` 必须给 `--pending`;给了也打 `must cover` 点名每一波。5 CAUGHT / 0 SURVIVED(§GJ.3)。 |
| (连带) | 裁定该不该每轮回到总监手上 | **不该。** 授权改为**由闸自己算**:当轮现跑 + `--pending` 覆盖列出的每一波 ⇒ `exit 0` 就发,不必问总监(§GJ.5)。 |

### §GJ.1 本轮零 AWS 调用,读数全部转载

总监未 bootstrap 凭据,**零 AWS 调用,不作任何 MTD 新声称**。本节所有金额转载批测台 2026-09-10T00:14Z 报告:MTD **`$74.308`**(免费 `budgets`,**`refreshed 2026-09-09T20:23:37Z`**,CE 复核 `74.3077543792` 逐位一致);外来机型拆解 `c7a.16xlarge $23.281 + r7a.16xlarge $14.155 = $37.435`;三波市场取自各自 `W<N>_wave.json:market`(**本轮现读,不是转载**):W60 **on-demand**、W61 **spot**、W62 **on-demand**。三条线(围栏 = 下一个未跨的 owner 告警档 / 刹车 `$90` / 批准线 `$100`)**一个字未改**。

### §GJ.2 ⭐⭐⭐ 交回来的「前提已变」在正确的时钟上没变

批测台 §五 的论据恰好一句:**「W60 已滑出 12h pending 窗 ⇒ 让出 `$2.15` ⇒ headroom `$0.292 → $2.442`」**,并据此说上一轮那句「结构上发不出任何一波」**已不成立**。

⛔ **那扇窗锚在 `now`,而它要修正的 MTD 锚在预算自己的 `LastUpdatedTime`。** 两个时钟那一刻差 **3.9h**(快照 `20:23:37Z`,读它的那一刻 `00:19Z`)。pending 要回答的问题从来不是「这波是不是 12 小时内发的」,而是**「这波的钱进没进我正在减的这个 MTD」** —— 而那个 MTD 的截止时刻是**快照**,不是此刻。

按快照自己的钟算(`ACCRUAL_LAG_MAX_HOURS = 11.3`,带的**上缘**):

```
cutoff = 2026-09-09T20:23:37Z − 11.3h = 2026-09-09T09:05:37Z
W62 末台机 2026-09-09T21:24:41Z   ← 晚于快照 61 分钟,确定不在
W61 末台机 2026-09-09T15:24:29Z   ← 早于快照 5.0h,带内
W60 末台机 2026-09-09T09:23:33Z   ← 早于快照 11.0h,仍在带内(差 18 分钟)
```

⇒ **W60 的 `$2.15` 不是落账了,是滑出了一扇从来就不对的窗。** 它是 **on-demand(`$2.15`)不是 spot(`$1.10`)**,所以让出的数比报告写的还大一倍。

⇒ 诚实 pending = `2.150`(W62)+ `1.100`(W61)+ `2.150`(W60)= **`$5.400`**;
projected = `74.308 + 5.400` = **`$79.708`**;对 `$80` 的 headroom = **`$0.292`**;
一波 spot `$1.10` ⇒ **`$80.808`,越栏**。

⚠️ **诚实边界,不藏**:W60 早于快照 **11.0h**,落在 4.3–11.3h 带的**上缘** ⇒ 它**很可能已经落账**。本裁定取的是**保守侧**,措辞是「**围栏无法被证明容得下一波**」,不是「W60 一定没落账」。⭐ 而这条边界**不改变结论**,理由见 §GJ.4。

⭐ **上一轮的 `$0.292` 与本轮的 `$0.292` 是巧合,不是同一个数**:上一轮是 `74.308 + 2.150 + 1.100` 对 `$80` 差 `$2.442` 后再减一波按需 `$2.15`;本轮是 `74.308 + 5.400` 直接对 `$80`。**两条路径无关,登记以免下一轮把它读成「没动」。**

### §GJ.3 ⭐⭐ 那扇窗两端各一个缺陷,而它们是同一个(已修,RULING 6)

裁 §GJ.2 时读到的:**没有人在快照自己的钟上算 pending**,而这件事在工具与手算两边**各自独立地**出了一次。

**(a) 工具这边。** `wave_fence.py` 的 RULING 4 把前提写成双条件:

> `pending == 0 is certifiable if and only if nothing is running.`

`⇒` 那一半是对的(有东西在跑 ⇒ pending > 0),它由 `exit 2` 执行着。**`⇐` 那一半是假的**,而且假在**本农场的常态**上:一台自终止的机器对 `describe-instances` 与 ActualSpend **同时不可见** —— 钱先发生、机器先消失、账最后到。AGENTS.md 禁止无自毁路径的实例 ⇒ **波与波之间普查结构上就是零** ⇒ 那道 `CERTIFIED` **对本台自己的花费从来什么都没证**,它只逮得住**外来的长命实例** —— 而那正是它唯一被推广自的那一次事故(09-06 那台烧了一整天的 `c7a`)。

⚠️⚠️ **这句话批测台 09-06 就逐字写下来过**:「**「零台在跑」与「零元未落账」是两个命题,工具把前者当后者的证据**」(存档在 `batch-desk.md` 那一轮报告里)。RULING 4 同日落地、**没覆盖它**;RULING 5(09-09)改的是**同一个函数的同一个分支**、**也没覆盖它**。⇒ **一句写对了的诊断,在两次改到它头顶的修法之间活了四天**,直到本轮它值 `$3.250`。

**(b) 手算这边。** 批测台的 12h 窗锚在 `now`(§GJ.2)。⇒ 两边**同向失效、都朝多花钱那一侧、都无声**。

**修法(RULING 6),三条,不发明成本模型也不发明余量常数**:
1. 窗口锚在预算的 `LastUpdatedTime`,cutoff = 快照 − `11.3h`(**上缘**,不是 4.3h 下缘 —— 下缘只能证「多半已计费」);
2. 窗内有波 ⇒ **`UNCERTIFIABLE (exit 2)`,必须给 `--pending`**(与 RULING 4 逐字同一套处置),波次由**本地 JSON、免费、离线**读出,用的是闸 (i) 自己的解析器;
3. 给了 `--pending` 仍打 **`must cover : N wave(s) listed above (W62, W61, W60)`** —— **不定价,只点名**,让漏掉一波在**声称的那一刻**可见,而不是三小时后在别人的手算里。

⭐ 读不到 `LastUpdatedTime` 或记录不可解析 ⇒ **降级措辞不降级门**(退回 `now`,打 `WAVE_FENCE CLOCK :`),沿 RULING 5 的先例;⛔ **不做成永久发波中断**,那是政策改动。
⭐ **`W37`–`W39` 无 `launched_at`(早于 GH #544)**:不靠猜也不靠永久挂一条没人读的免责 —— 用闸 (i) **自己的 ruling 3**(族内编号序即时间序)拿一个**更高编号的可定日兄弟**去界定它们;界不到才留 `unread`。

⭐ **证据**:`tests/test_wave_fence.py` **90 checks / 0 failed**(§15,含 15b「快照钟逮到、`now` 钟丢掉」这一对反例)、`mutstand_wave_fence_clock.sh` **5 CAUGHT / 0 SURVIVED**、control 90/0、还原 `sha256sum -c` 逐字节相同;`test_wave_gate_keys.py` **406 / 0**、`test_pending_rulings.py` **494 / 0**、`test_mutstand_restore_trap.py` 全绿。
⚠️ **变异台自己中了一发,留痕**:M1 原本写成 `replace("        if wave_rows:\n", ..., 1)`,而我随后在**它上面**又加了一个 `if wave_rows:` 分支 ⇒ **mutant 悄悄挪到了另一个位点**,台子照旧报 CAUGHT(4 failed 变 1 failed 才露馅)。已改成**带唯一性断言的注释锚**。**一个会漂移的 mutant applier,报出来的 CAUGHT 不是它自称的那件事。**

### §GJ.4 为什么「等一等」不是答案 —— 钱两边都花了

W60/W61/W62 无论算在 `pending` 还是算进 MTD,**都已经花掉**。等快照刷新把三波全吸收,MTD 读作 **~`$79.7`**,headroom 对 `$80` 仍是 **~`$0.3`**。⇒ **不是「等几小时就能飞」,是九月在 `$80` 围栏下已经发不出下一波了**,直到 10-01 —— 而那时围栏是 **`$50` 不是 `$80`**(§GI.2,理由未变)。

⇒ 这也是 §GJ.2 那条诚实边界**不改变结论**的原因:W60 到底在 MTD 里还是在 pending 里,**只决定这 `$2.15` 记在哪一栏,不决定它花没花**。

⛔ **因此批测台 §七 那份规格(与 W62 并池、`ownhalf` 家族 4 粒 → 8 粒)不是被本裁定否掉的 —— 它从来没有真的可用过。** 本台把「九月只剩这一次机会」写进**维持的代价栏**时,那次机会已经不在了。⭐ 规格本身**质量很高且不作废**:三处树差在 37-id 臂串下逐处判不可达(调用点是**读源码**核的不是从 diff 猜的),并池结论按 §GH.5.4 成立 —— **10-01 之后第一波就照它发**,不必重做。
⭐ **代价栏订正后的真实内容**:维持的代价**不是**下游停摆(`queue.json` 全表无一行申请新波次,本台已逐行扫过),**也不是**那次加深 —— 是**九月剩下的时间里本台只能收割不能发波**。

⭐⭐ **真正能让九月重开的不是裁定,是 `dota2bot-batch` 的 `CostFilters = null`**(GH #515):外来 **`$37.435` = MTD 的 50.4%**。⇒ 若那个过滤器存在,本台九月的 MTD 是 **`$29.652 ≤ x ≤ $36.872`**(批测台只报区间不报点值,`NoInstanceType $7.220` 未拆),**离 `$80` 还有一整个月的余量**。已在 `DECISIONS_NEEDED` 第 15 条,**本轮只补这个硬数字,不另发信**(遵 §GI.4 的两个提前发信触发条件,**本轮两个都不满足**),随周日 W37 那封走。

### §GJ.5 ⭐⭐ 裁定从此不由总监每轮复议,由闸自己算

**这一条对批测台是放松不是收紧。** GH #677 那条 `NO_WAVE_NEXT_LAUNCH_ROUND` 是**一条按轮计的人裁**,而它本轮就已经暴露出人裁的两个成本:(a) 批测台读到前提变了,**不能自己改口**,只能停一轮把球交回来;(b) 我要复议,而复议靠的是**我这一轮碰巧把时钟算对了**。

⇒ 授权改为:**当轮现跑 `wave_fence.py`,`--pending` 覆盖它列出的每一波,`exit 0` 就按 §七 规格发,不必再问总监;`exit 3` 就不飞。** 裁定的内容没变(现在确实发不出),**变的是它由谁执行** —— 与本仓库反复学到的那条同源:**它是习惯就会漏,是门才不会。**
⛔ **不许抄本节的 `$5.400` / `$79.708` / `$0.292`**:与 RULING 1 同源,**围栏是时间的函数**。

### §GJ.6 本节没有声称的东西

1. **没有声称 W60 一定不在 MTD 里** —— 它在 4.3–11.3h 带的上缘,**很可能在**;取保守侧的理由写在 §GJ.2,而结论不依赖它(§GJ.4)。
2. **没有跑过 RULING 6 的活 AWS 路径**(新增的那条读是活预算的 `LastUpdatedTime`)—— 总监零 AWS 调用,**首次实跑是批测台下一轮**,已登记 `owed_executions.json:wave_fence_ruling6_first_live_read`。
3. **没有裁 W62 的 promote/reject**(4/4 粒、203 局的读数在批测台报告里,本轮未读)。
4. **没有证明外来支出停了还是会再来** —— 批测台本轮的 `0 accruing account-wide` 是**此刻**的读数,不是速率。
5. **没有动三条线**(围栏/刹车/批准线),**没有预支任何跨线许可**。
6. **没有给闸 (ii) 写可执行体**(`wave_reachable_delta.py` 仍不存在),**第四轮顺延**。
7. **没有裁 `PROMOTE_BAR_PAIRED_SEEDS =`**(`owed` 腿本轮读作 DONE 并点名该退休),**顺延**。
8. **没有处理自检 `queue-rulings` 腿新点名的 hero-51..55 路由/槽位裁定**(4 条 OTHER + 1 条 RIDESHARE),**本轮登记不处理**。

---

## §GK 2026-09-10T05:xxZ 总监:**裁 W62 的 promote/reject(§GJ.6 第 3 条,本轮结清)—— 裁定是 HOLD,而本节最该被读的不是那个字,是 §GK.2:决定性通道这一波在结构上没有读数,而它给出的那个「没有」长得和「测过了,是负的」一模一样**;以及 **§GK.3:GH #352 自己的立案句点名了两个被误读的数,它修了第一个**

### §GK.0 裁定摘要

- **W62 = HOLD。零 id promote,零 id 退集,armed 串 37 不动。**
- ⛔ **HOLD 不是 reject 的委婉说法**:reject 要的是「明显有害」的读数,而本波在鉴别 promote/reject 的那个通道上**读数不存在**,不是不好看。
- 依据:铁律 2 的三条件里,**(b)「批测显示对胜负没有明显负面影响」在本波无法被满足也无法被否证**。
  `recover_verdict.py` 自己打的 `winrate_channel: DEGENERATE`(minority side share **0.0529 < 0.20**,
  215/227 局归 dire),而工具的 stderr 逐字写着这句读数
  **`MUST NOT be cited as rule 2(b) support until the channel recovers`**。
- ⭐ 工具自己的 `suggested` 字段是 **`hold_or_reject`**,**两个字都在里面**;本裁定取 `hold` 那一半,理由在 §GK.2。

### §GK.1 本轮零 AWS 调用,读数全部转载

全部四个数字来自 `iterations/reports/batch-desk/waves/W62_verdict.json`(批测台 09-10T00:14Z 收割)。
本轮**没有**跑 `awsx`、没有发波、`bots/`+`game/` **零 diff**。

| 粒 | ab/ba 局 | `winrate` | `winrate_headroom` | 能不能投票 |
|---|---|---|---|---|
| 10601 | 42/16 | **0.500** | **0.0** | ⛔ 不能(恒等式) |
| 10607 | 31/14 | 0.516 | 0.0357 | ✅ 能 |
| 10803 | 34/24 | **0.500** | **0.0** | ⛔ 不能(恒等式) |
| 10813 | 30/12 | 0.608 | 0.4167 | ✅ 能 |

池化:`mean.winrate 0.531` / `comps_better.winrate` **2/4** / `scored_games 203` / `unfinished 0`。
经济四量:`gpm −7.20`(2/4)、`xpm +10.17`(4/4)、`deaths −0.14`(3/4)、`last_hits +0.60`(2/4);
`strata` 四量**全部** `sign_flip: true` 且 `side_gt_arm: 4/4`。

### §GK.2 ⭐⭐⭐ 为什么这是 HOLD 而不是 REJECT

**(b) 问的是胜负,而胜负这一栏这一波是空的,不是负的。**

`winrate = (r_ab + (1 − r_ba)) / 2`,r_x 是**同一个物理侧**在 x 波的胜率。
一侧横扫 ⇒ `r_ab = r_ba` ⇒ `winrate ≡ 0.500`,**与臂做了什么无关**。
10601 与 10803 的 `headroom` 是 **0.0**,意思是「0.500 是这份语料唯一能取的值」——
**那不是一次读数,是一个恒等式**。

于是本波的 `mean.winrate 0.531` 是 **三个数里两个是常数**:
`(0.500 + 0.516 + 0.500 + 0.608)/4`,而**第一和第三项无论臂正负都会是 0.500**。
⇒ 把 0.531 读成「胜率略正」是错的;把它读成「胜率没明显负面 ⇒ (b) 满足」**同样是错的**,
方向相反、错法相同 —— 两次都是拿恒等式当测量。

**经济那一栏也不能替 (b) 作证**,而且理由不是「gpm 是负的」:
`gpm −7.20` 在四量 `side_gt_arm 4/4` 之下,按 §CL 的 (i-c) **反号不是否决理由**;
`side_gt_arm 4/4` 说的是这一波抽到的阵容侧偏比效应大,**对 arm 测得多准零信息**。
⭐ 而铁律 2(b) 的主语本来就是**胜负**,不是 gpm —— 用一个侧偏没消掉的经济量去补一个
读不到的胜负量,是把两个 §CL 都管不住的缺陷叠在一起。

⛔ **本节没有声称 37 个 id 是好的。** 声称的只有一句:**W62 这份语料无权说它们是坏的,也无权说它们是好的。**

### §GK.3 ⭐⭐ GH #352 自己的立案句点名了两个数,它修了一个(已修,GH #696)

`tests/test_verdict_winrate_channel.py` 的头注释逐字:

> the tool printed `winrate 0.500` and **`comps_better winrate 0/4`**, six waves running,
> and **BOTH** were read as measurements

#352 落地的是 `winrate_headroom` —— 它让**被冻住的那个 0.500** 在同一行里读得出来。
**而 `comps_better.winrate` 照旧把生出那个 0.500 的粒计在自己的分母里。**

后果不是「数字略偏”,是**分母里坐着常数**:
本波 `comps_better.winrate 2/4`,两张反对票 **10601 与 10803 都投不出赞成票**
—— 它们的 `x > 0.5` 恒为假。⇒ 形如「`comps_better winrate ≥ 3/4`」的 promote 门在这份语料上
**不是没达到,是算术上够不着**;而**报出这件事的那个分数,和「臂输了两粒」长得一模一样**。
⭐ 在**能说话的粒**里,本波的战绩是 **2/2**。

**修法(GH #696,本轮落地)**:`recover_verdict.py` 在池化分数**旁边**再打三样 ——
`winrate_forced_seeds`(点名,不只计数)、`comps_better.winrate_measurable`、
以及一行 stderr(**两个分数都带**,给从不打开 JSON 的读者)。
⛔ **旁边,不是替换** —— 与 `winrate_headroom` 二十行之上遵的是同一条规矩:
静悄悄把被冻住的粒丢掉,会**把横扫本身藏起来**,而横扫才是发现;
两个分母之间的差,读出来的是**语料**,不只是臂。
⛔ **`0/0` 照打不省略**:缺键读作「没什么可报的」,而一波没有任何可测粒时,那**恰好**是它唯一不表示的意思。

W62 按新字段的读数(离线由 verdict 的 per-seed headroom 直接导出,**非重跑**):
`winrate_forced_seeds = [10601, 10803]` / `comps_better.winrate_measurable = 2/2` / 池化仍 `2/4`。

### §GK.4 证据

- `tests/test_verdict_winrate_comps.py`(新):**25 checks / 0 failed**,驱动真脚本读真 stdout/stderr,
  每个 case 前跑 `check_parsed()` 反空匹配守卫。
  ⭐ **承重的是 case 1(一个臂两个分数)与 case 2(什么都没冻住时两个分数必须一致)**;
  case 2 里那粒 **007 读 0.500 而 headroom 0.5** —— 它就是分「按 headroom 锚」与「按 0.500 这个值锚」的那把刀。
- `tools/agent/mutstand_verdict_winrate_comps.sh`(新):**6 CAUGHT / 0 SURVIVED**,CONTROL GREEN,
  还原 `sha256sum -c` 逐字节相同;每个 anchor 先断言**唯一**(照 §GJ 的 M1 漂移教训)。
- ⚠️ **变异台第一版的 M4 是「对的结论、错的理由」,已修并留痕**:
  它只给赋值加了 `if meas:`,于是 mutant 在**下面那行 stderr** 上 `KeyError` 当场崩,
  测试确实红了 —— 但 **case 3 的那条断言一次都没执行**。
  台子照旧印 CAUGHT,**露馅的只有 FAIL 摘要那一栏是空的**。
  ⇒ **够不到断言的 mutant,测的是解释器不是测试**;已让 mutant 自洽(stderr 改 `.get`),
  重跑后 M4 的 FAIL 行逐字是 `an all-forced wave prints 0/0 rather than omitting the key, got None`。
- 未连带红:`test_verdict_winrate` / `test_verdict_winrate_channel` / `test_verdict_arm_depth` /
  `test_verdict_strata` / `test_verdict_pool_lossless` / `test_queue_reading_census` 六个 **EXIT=0**。

### §GK.5 本节没有声称的东西

1. **没有声称 37 个 id 里任何一个是好的或坏的** —— 见 §GK.2 末。
2. **没有重跑 W62 的语料** —— 新字段对 W62 的读数是**从 verdict 里已有的 per-seed headroom 离线导出的**,
   不是 `recover_verdict.py` 在 W62 原始 `analysis.json` 上再跑一次的产物。原始语料在 S3,本轮零 AWS。
3. **没有覆盖 `winrate_undisclosed_headroom_seeds` 分支** —— 变异台的 LIMITS 里逐字写着:
   脚本在同一个 `ab_n and ba_n` 卫兵下同时写 winrate 与 headroom,**本台造不出那种语料**,
   该分支只由 case 1 的「不存在」断言反向管着。**说出来比一个悄悄少一分的 CAUGHT 数好。**
4. **没有改任何 promote 门的阈值** —— `winrate_measurable` 是**披露**,不是新门;
   谁也没被授权拿它去过一个池化分数过不了的门。
5. **没有跑 Lua 全量**(`bots/`+`game/` 一行未改),**不声称**。

## §GL 2026-09-10T0x:xxZ 总监:**GH #692(缺陷)+ GH #693(政策)一次裁完 —— 本节最该被读的不是那两条裁定,是 §GL.2:RULING 6 的降级条款被设计成「罕见」,而它从落地当天起在本账号上是 100%;以及 §GL.3:一道只有在操作员不信它时才安全的闸,不是闸**

### §GL.0 裁定摘要

- **GH #692 = 采纳并已修**(`[harness]`,章程 2a 直接修)。
- **GH #693 = 采纳,原样采纳**(政策裁定):**时钟降级 ⇒ `UNCERTIFIABLE (exit 2)`**。
- **⛔ 一处比申请方要求的更严,写在这里免得被读成笔误**:`--pending` **不能**买过一个降级的时钟。
  #693 §四 建议「处置与 RULING 4/6 的 `--pending` 同款」;**那一半不采纳**,理由是 §GL.4。
- 零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、armed 串 **37 不动**、无 promote / 无退集。
- 取活依据:上一轮「下次触发」第 ③④ 条 + **章程 2a**(`[bug]/[harness]` 直接修)+ **2d**(成本裁定)。

### §GL.1 两个 issue 是一件事的两半,所以一次裁完

| | GH #692 | GH #693 |
|---|---|---|
| 谁立的 | 批测台 09-10T03:24Z | 批测台 09-10T03:25Z(同一轮) |
| 前缀 | `[harness]` | `[batch]` |
| 说的是 | 解析器不认 CLI 给的 float epoch | 降级只碰措辞,而 §四 之后授权只读退出码 |
| 单独修会怎样 | 降级变罕见,但**罕见的降级仍然自动发钱** | 门堵上了,而它**每一轮都会挡住**(降级是 100%) |

⭐ **两条必须同一次落地,而这不是省事是算术**:(乙) 的代价与 (甲) 的触发率相乘。
epoch 不认 ⇒ 降级 100% ⇒ 单独上 (乙) 就是**永久发波中断**(那正是 RULING 5 拒绝做 exit 2 的理由);
epoch 认了 ⇒ 降级回到罕见 ⇒ (乙) 的代价降到「AWS 哪天再改一次序列化」那一档,**而那一档有 `--snapshot-instant` 兜着**。

### §GL.2 主轴:被设计成「罕见」的那条腿,从落地当天起是 100%

RULING 6 的降级条款写得很规矩 —— 它给 `clock_source` 贴标签、打免责行、
在头注释里**主动写明**「fallback 方向是许可的(`now` 更晚 ⇒ 窗更窄)」。
**那份规矩全部建立在一个未经测量的前提上:降级罕见。**

实测(批测台 03:1xZ,同一账号、同一轮、同一个预算):

| 工具 | 它读到的 `LastUpdatedTime` |
|---|---|
| `tools/batch_test/aws/check_costs.sh` | `2026-09-09T20:23:37Z` ✅ |
| `tools/batch_test/soak/wave_fence.py` | 逐字 `clock from now (budget LastUpdatedTime unreadable)` ❌ |

根因是一行 `isinstance`:`awsx budgets describe-budget --output json` 把它序列化成
**float epoch**(`1788985417.716`),而 `parse_snapshot_instant()` 的容差清单
——按它自己的 docstring——是照着 **botocore** 写的,`_read_budget()` 走的却是 **CLI 的 `--output json`**。

⭐⭐ **立案句:数据一直在,而且是对的;是解析把它丢在地上。**
「读不到」与「读到了但不认识」**在退出码上长得一样,在修法上完全不同** ——
前者的修法是去要权限,后者的修法是加一支 `isinstance`,而**两者印出来的免责行逐字相同**。

⚠️ **同族第 N 次,而这次的新意在「容差清单是照着另一条调用路径写的」**:
写清单的人查的是 botocore 的返回形状,用清单的人走的是 CLI。
两边都不是错的,**错的是没有人在这两句话之间画一条线**。

### §GL.3 §四 把「会读免责行的那个人」从回路里拿掉了

GH #683 §四(总监 09-10T01:xxZ)把发波授权从「每轮总监复议」改成算术:
**当轮现跑 + `--pending` 覆盖它列出的每一波 ⇒ `exit 0` 就发,不必问总监**。
那条改动本身是对的(批测台自己也没有异议),而它有一个未被点出的副作用:
**从那一刻起,退出码就是授权本身**,而 RULING 6 的降级**恰好不碰退出码**。

§四 的第一次执行就量到了它(批测台 03:1xZ,同一分钟内两次运行同一个工具):

| 时钟 | 工具点名的波 | `--pending` | projected | 退出码 |
|---|---|---|---|---|
| 降级 `now`(工具**实际走的**) | 只有 W62 | `$2.150` | `$77.558` | **`exit 0` CLEAR** ⇒ §四 ⇒ **发波** |
| 诚实快照(`20:23:37Z − 11.3h`) | W62+W61+W60 | `$5.400` | `$79.708` | **`exit 3` THROTTLED** |

⭐⭐⭐ **注意这里的关键,它比「工具坏了」更难看见**:降级那一路里,
批测台**照工具自己那行 `must cover : 1 wave(s) listed above (W62)` 完整照办了,一波不漏**。
**§四 的字面要求被满足了,而结果是一波要越栏的波拿到授权**(`$80.808 > $80.00`)。
没飞,是因为批测台自己手算了一遍**不信那个工具**。

⭐ **立案句:一道只有在操作员不信它时才安全的闸,不是闸。**
它此刻的安全边际,全部由「批测台每轮多做一遍手算」这个习惯提供,
而 §四 的立法目的**恰恰是把那一遍手算换成算术**。

### §GL.4 ⛔ 比申请方要求的更严的那一处,和它的理由

#693 §四 建议「处置与 RULING 4/6 的 `--pending` 同款」。**那一半不采纳。**

理由是一行算术,不是保守偏好:**决定「要覆盖哪几波」的正是那个时钟。**
`--pending` 在 RULING 4/6 里之所以够用,是因为它要对抗的是**定价**(工具不给波定价,操作员来);
而这里坏掉的是**点名**。一个覆盖了它点名的每一波的 `--pending`,
**在降级的时钟下按构造就是短的** —— 03:1xZ 那次短了 `$3.250`,而它逐条对得上账。

⇒ 降级检查放在 `certify_pending()` **所有裁决分支之前**,`pending_supplied` 给不给都一样。

⚠️ **这是对 RULING 5「⛔ 故意不做成 exit 2」的反转,而反转的范围写死在一条路径上**:
RULING 5 自己的区域标签条款**一字未动**。反转的理由不是口味变了,是 §四 换了世界 ——
RULING 5 当时的两个前提(「把标签缺陷变成永久发波中断是政策改动」+「本台此刻已经被围栏挡住」)
里,第二个已经过期,第一个被 §GL.1 的乘法解决掉了。

⭐ **门没有永久关死,这是 (乙) 能站住的第三条腿**:新增 `--snapshot-instant`,
操作员可以把在别处读到的钟(`check_costs.sh` 打得出来)**声明**给它。
它被标成 **claim 不是 reading**(`WAVE_FENCE CLOCK :` 行照旧骑在裁决行后面),
**但它是一个钟,所以闸照跑、accrual 普查不丢** ——
这比「用 `--no-accrual-check` 绕过去」严格地好:后者会连 RULING 4/5 的实例普查一起扔掉,
**为了一个时钟问题赔掉泄漏检查,是把两件事绑在一起的那种修法**。
⛔ 传进来一个读不出来的值 ⇒ **`exit 2` 当场拒**,不静默回退(静默回退等于替操作员回答一个他没问的问题,方向还是许可侧)。

### §GL.5 ⛔ 故意没有做的那一条,和它被钉在哪里

RULING 7 **没有**扩到 `why_unread`(读不出日期的波次记录)。
那一条**同样偏许可**,但它是**另一个读数、另一套修法**,而 #693 问的是时钟。
**在一个 bug fix 底下夹带一条政策改动,正是本文件反复在修的那种事。**
⇒ 它照旧是 `exit 0` 上的一条免责行,并由 `tests/test_wave_fence.py` 的**断言 16f 把这条边界钉住**:
将来哪一轮要扩,**得先去改那条断言**,改不动就说明扩的人自己也没想清楚。

### §GL.6 证据(全部本轮现跑,零 AWS)

- `tests/test_wave_fence.py` **111 checks / 0 failed**(原 90;新增 §16 共 20 条 + 15i 改锚)。
- `tools/agent/mutstand_wave_fence_ruling7.sh` **6 CAUGHT / 0 SURVIVED**,CONTROL 绿,
  还原 `sha256sum -c` **逐字节相同**。⭐ **六个 mutant 每一个都打出了具体的 FAIL 行**
  (不是靠崩溃冒充 CAUGHT —— 上一轮 M4 就是那么险些混过去的)。
- ⭐ **顺手修好一个已经漂掉的 mutant,而它是被本轮改动**撞**出来的**:
  `mutstand_wave_fence_clock.sh` 的 M2 锚在 `    clock = parse_snapshot_instant(last_updated)`(4 空格),
  RULING 7 把这一读缩进进了 else 分支 ⇒ **那个 `replace` 会一个字都不改而台子照旧给它记分**。
  已改成带唯一性断言的 8 空格锚;重跑 **5 CAUGHT / 0 SURVIVED**。
  ⚠️ **这是 09-09T22:xxZ 那一轮「会漂移的 mutant applier」教训的第二发,而这一发是别人改代码撞出来的**
  ⇒ 唯一性断言的价值不在写它的那一轮,在**下一个不知道它存在的人改到它头顶的那一轮**。
- 邻测未连带红:`test_wave_gate_keys.py` **406/0**、`test_pending_rulings.py` **501/0**、
  `test_wave_throttle.py` **55/0**、`test_mutstand_restore_trap.py` **EXIT=0**。
- ⛔ **Lua 全量未跑不声称**(`bots/`+`game/` 一行未改)。
- ⚠️⚠️ **本轮读数的诚实边界,写在最显眼处**:总监**不花 AWS 的钱** ⇒
  `1788985417.716` 是**从批测台报告里抄来的**实测值,**新的解析分支在真实预算读上一次都没被执行过**。
  这正是 #692 自己的立案教训(「咬人的那个形状从来没进过测试的输入集」)⇒
  已登记 `owed_executions.json:gh692_epoch_clock_first_live_read`,
  结清判据钉在 `wave accrual :` 行里 `clock from` 后面跟的那一串
  ——**本节故意不把它逐字拼出来**,理由见下一条。
- ⚠️⚠️ **本轮自己踩了一脚,当场改掉,留痕(这一发比上面两条都值钱)**:
  判据初稿钉的是逐字串,而**我把那一串逐字写进了这一节** ⇒
  `done_when` 的 `path` 就是 `test_set.md` ⇒ **这条常驻义务在写下的同一秒就被我自己的档案满足了**,
  `pending_rulings.py` 下一轮会安静地把它读成 DONE,**而批测台一次都没跑过那条路径**。
  ⭐ **失效形状是「判据与档案同处一个文件」,不是「判据写错了」** ——
  上一轮 `gh696_...` 侥幸躲过,靠的是那一串碰巧没被写进档案(当轮实测 0 次),
  **不是靠任何机制**。⇒ 本节改为**不逐字复述判据串**;
  重量后 `iterations/` 下该串仍是 **0 次**(已量,改后再量的)。
  ⛔ **登记为「已知的登记表盲区」,不当作已修**:`path_contains_all` 无法区分
  「下游抄回来的读数」与「上游自己写下的判据」,而**这两件事在文件里长得一模一样**。

### §GL.7 投递(章程 2.5)

| 终点 | 是什么 |
|---|---|
| `tools/batch_test/soak/wave_fence.py` | **批测台真正会跑的那个工具**(RULING 7 头注释 + 运行时行为) |
| `iterations/streams/batch-desk.md` 闸 (iii) 正文 | 那一轮真正被驱动的那张表 |
| `iterations/owed_executions.json`(34 → **35**) | 常驻义务,不属于任何一波(§DR) |
| `iterations/state.json:GH692_693_RULING7_20260910T0xxxZ` | 判决档案 |
| `iterations/streams/test_set.md §GL` | 本节,全文档案 |
| GH #692 / GH #693 追评并关闭 | 申请方读的活线程 |

### §GL.8 ⭐ 第一次活跑读数(批测台 2026-09-10T21:xxZ 转载,`owed_executions.json:gh692_epoch_clock_first_live_read` 本行结清)

**这一节是下游抄回来的读数,不是上游写下的判据** —— §GL.6 最后一条点名的那个
登记表盲区(`path_contains_all` 区分不了这两者)**在本行仍然存在**,所以来源写在最前面:
批测台 2026-09-10T21:1xZ 那一轮(**零发波轮**,闸 (iii) 自己把波拦下了)对**真实预算**
跑了 `wave_fence.py --planned 1.10 --pending 1.10` 一次,`FENCE_EXIT=3`。**新解析分支这一次真的执行了**,
它打出的那一行逐字是:

```
wave accrual     : records after 2026-09-10T08:28:38Z (= 2026-09-10T19:46:38Z - 11.3h lag, clock from budget snapshot)
```

⇒ 判据串 **`clock from budget snapshot`** 首次由活跑产生(立行当日在 `iterations/` 下 0 次,
本行是第 1 次,且**是读数不是判据**)。⭐ **要点是「不是 `now`」**:`19:46:38Z` 正是
`check_costs.sh` 同轮打的 `budget refreshed 2026-09-10T19:46:38Z`,而该轮 `now` 是 `21:1xZ`
—— **两者相差 1.5h,降级路径若仍在,窗口右端会锚在 `now` 上**,§GL.2 那条「设计成罕见、
实际 100%」的腿在本账号上**这一轮确实没有再触发**。

⚠️ **本节不声称的三件事**:(1) 一次活跑**不等于**那条腿在所有输入上都对
(#692 的立案教训正是「咬人的形状没进输入集」,一个样本换不掉那句话);
(2) 本轮 `--pending $1.100` 覆盖工具点名的 `must cover : 1 wave(s) listed above (W63)`,
**一波不漏,但本轮 `exit 3` 是钱不够,不是时钟** —— ⛔ 所以本轮**没有**复现 §GL.3 那张
「降级 vs 诚实快照」双路对照表,那张表要等一个 `exit 0` 的轮次才谈得上;
(3) RULING 6 那根**另一根**棒(`wave_fence_ruling6_first_live_read`,判据钉在
`wave accrual :` 这个新前缀上)由同一次运行同时满足 —— 该行是 `kind=manual`,
读数登记在批测台报告与章程「当前状态」里,**本节只作交叉引用,不代它结清**。

---

## §GM RULING 8 — 闸 (iv) 的吸收态,和「闸不许索要一个改变不了它自己答案的字段」

**总监 2026-09-10T10:xxZ 裁。** 立案:GH #699(批测台 06:2xZ 立,`[harness]`),
09:17Z 那一轮把它的形状**从「九月的钱过期」升级为「农场已停」** —— 而**升级的那一半才是对的**。
零 AWS、零波次、`bots/` + `game/` **零 diff**、不发 owner 邮件、armed 串 **37 不动**、
**无 promote / 无退集**。取活依据:上一轮「下次触发」第 ⑧ 条 + **章程 2a**(`[bug]/[harness]` 直接修)。

### §GM.1 缺陷不是一个错答案,是一个闭环

⭐⭐⭐ **闸 (iv) 的每一次拒绝都是局部正确的,而它们首尾相接成了一个吸收态:**

1. 闸 (iv) 判 BLINDED 时开出的处方**就是**「下一波按需」(工具自己的 `NEXT WAVE:` 那行);
2. 按需机没有 spot request ⇒ 它的码只能是 EC2 的 `StateReason.Code`
   ⇒ 只能从 `describe-instances` 读,而终止实例在那里 **~1h 老化**(GH #375),
   波次节奏把收割放在发波后 **~3h**;
3. ⇒ 按需波的行到了收割时**永久**是 `status_code: null`
   (W62 四行各带 `status_code_unrecoverable` 块,两个一手源都已用尽);
4. 闸只读 `--wave-json`,只读**上一波**,无持久状态、无绕行开关;
5. 要让「上一波」不再是 W62,**只能发一波**;发一波需要闸 `exit 0`。

⇒ **(1)–(5) 闭合。** ⭐ **这不是过期是不动点**:十月 MTD 归零、围栏从 `$80` 重开到 `$50`,
**这个闸的读数一个字都不会变**,因为它读的既不是钱也不是日历,是一份**永远补不齐的记录**。
⭐⭐ **最贵的一句:闸开出的处方,让闸在下一轮打不开它自己。**

⚠️ **同族的第二发,方向相反**:GH #661 之前按需分支**接受任何字符串**(连空串)⇒ 静默假通过;
#661 收紧成白名单 ⇒ 结构性拒绝。**失效方向翻了号,而两个都不是「读到了」。**

### §GM.2 裁定:改的是求值顺序背后的那条原则,不是宽容度

> **一道闸不许索要一个改变不了它自己答案的字段。**

实现:**缺失**的字段不再在逐机解析循环里 `raise`,而是变成一个**带名字的洞**(`Unread`);
verdict 在这个洞的**每一个可容许取值**上各算一遍(`_decide()` —— **算 verdict 的唯一那处**,
穷举点是**跑它**而不是另写一份推理,否则检查器会和被检查的规则各自漂走然后互相同意)。

- **全都一致** ⇒ 按那个答案走,把洞**逐台点名**打出来,并写明答案不依赖它;
- **有分歧** ⇒ 照旧 `exit 2`,理由改成**「这个缺的字段就是答案本身」**——
  ⭐ 那才是真的那条;**旧措辞怪的是「缺失」,于是把两种行一视同仁地拒了**。

⛔ **申请方建议的 remedy(clause (1) 短路)只采纳其结论,不采纳其形状。** 短路对 W62 成立,
但它**只挡得住第一个缺字段**:W62 的行**连存活时长也没有**(`survival_min` / `create`+`update` 全无),
短路版会在**下一行**再次拒绝 ⇒ **缺陷会原样复活,而且看起来像一个新缺陷**。
按材料性写则两个洞一起被覆盖,且 `yield <= 1` 那半**照旧正确地拒**。

### §GM.3 ⛔ 两处**故意**没有放松,它们是这条裁定能成立的全部理由

1. ⛔ **没有加任何绕行开关**(测试 26j 钉住 `--help` 里不出现 `--force/--assume/--ignore/--skip/--no-`)。
   加开关 = 把 #661 关掉的静默假通过原样放回来,只是换了个门进。
2. ⛔ **只有「缺失」当洞;「写错的值」照旧当场拒,力度一字未减** ——
   按需行带 SIR 码 / 带 spot 的 EC2 拼法 / 带 EC2 词汇表外的码(#661)/ spot 行带 EC2 码(#412)/
   未知 market / 未知 `survival_bound` / 非数字存活 / `update` 早于 `create`。
   ⭐ **理由能一句说完:自相矛盾的记录不是洞,在它上面穷举等于给一句谎话打分。**
3. ⭐⭐ **穷举把 `instance-terminated-no-capacity` 放在每一个没读到的码上,按需行也放。**
   这是**整条裁定的安全论证**:本文件 `market` 一节点名的危险方向是
   「一台 spot 机被误标 `on-demand`,它的抢占从归因里走掉,藏掉一个 BLINDED」;
   码**在**时那个矛盾检查抓得住,码**缺**时**没有东西可矛盾** ——
   挡在这一行和一个被藏起来的 BLINDED 之间的,**只剩穷举肯算那一发对抗值**。
4. ⭐ **区间不是数,洞不是值**:归因计数打成 `0..N` 的**区间**(点值会是工具自己编的);
   每台机器那一行的洞显示成 `(unread)`,**不显示成一个码、也不显示成一个分钟数**。
   bracket 量规对读不出的行**出声跳过**(沿用它对下界存活已有的先例 —— 洞比下界还弱)。

### §GM.4 W62 因此 `exit 0`,而这是一个读数不是一次耸肩

`reclaim_blind.py --wave-json iterations/reports/batch-desk/waves/W62_wave.json`
⇒ **`RECLAIM_EXIT=0` / `VERDICT: not blinded -- the wave delivered 4 paired seed(s).`**
(即 GH #699「验收方式」逐字要求的那一条,**没有给任何人填 `status_code` 的机会**)。

⭐ **答案来自 clause (1) 而不是宽容**:yield **4/4 配对**,`low_yield = paired_n <= 1` 为**假**,
归因**根本没被查到**;而 `paired` 只读 `ab`/`ba`/`arm_depth` —— **这三个字段存在,而且仍然是必填**。
256 个穷举点全部一致。**⚠️ §五 那条回填仍然要做**:收割轮不把 `ab`/`ba`/`arm_depth` 回填进
**波次记录**(闸读的是那一份,不是 verdict),yield 也会读不到,那时候洞**真的**承重,
闸会**正确地**再次 `exit 2`。

### §GM.5 ⭐ §六 的授权问题:批测台不发波是对的,一并裁掉

**批测台不许按自己的推导发波。** 授权仍然**钉死在退出码上**(GH #683 §四),
`exit 2` 逐字 `nothing was decided; this is not a pass`。
⭐ **修的是「工具说不出话」,不是「规矩」** —— 正确的出路永远是让工具**能给出**那个答案,
而不是让操作员**替它**给。**「我推导出来的通过」和「工具打出来的通过」在授权上永远不是同一个东西**;
而这一次,推导恰好是对的,**这只会让下一次推导更便宜、更容易错**。

### §GM.6 证据(全部本轮现跑,零 AWS)

| 读数 | 值 |
|---|---|
| `tests/test_reclaim_blind.py` | **119 checks / 0 failed**(原 101) |
| `tools/agent/mutstand_reclaim_materiality.sh`(**新建**) | **6 CAUGHT / 0 SURVIVED / 0 INERT** |
| `tools/agent/mutstand_reclaim_market.sh`(P3 已重新瞄准) | **8 CAUGHT / 0 SURVIVED** |
| 两台还原 | `sha256sum -c` 逐字节相同,restore 后 baseline **exit 0** |
| 邻测 | `test_wave_fence` 111/0、`test_wave_throttle` 55/0、`test_verdict_strata` 17/0 |
| 铁律 6 静态半 | `luacheck bots game`:见 §GM.8(`bots/`+`game/` **一行未改**) |

⭐⭐⭐ **变异台本轮抓到两发,而两发是同一个缺陷,一发在测试里一发在台子自己里(§GM.7)。**

### §GM.7 ⭐⭐⭐ 本轮自己踩的两脚,当场改掉,留痕

**都是同一个形状:`ln.strip().startswith(...)` 去匹配一条靠「原始缩进」区分身份的行。**

1. **测试 26k 初版**用 `ln.strip().startswith("seed 10601")` 取「每台机器那一行」——
   而下面的披露块**也**以 `seed 10601:`(四格缩进)开头 ⇒ 取到 **3 行不是 1 行** ⇒
   `len(mline) == 1` 恒假 ⇒ **它下面每一条断言都静静变成 False**。
   ⚠️ **发现它的不是我,是变异台 restore 之后的 baseline 自己红了** ——
   `BASELINE RED after restore: 119 checks, 3 failed`。
   ⭐ **一个在干净树上就红的断言,和一个抓到了 mutant 的断言,在 mutant 那一栏里长得一模一样**:
   Q2/Q3/Q4/Q5 的 FAIL 摘要里都挂着 26k,**而它们没有一个是因为 26k 才被抓的**。
2. **台子自己的指纹**写的是 `ln.strip().startswith(("yield", "attribution", "  seed"))` ——
   ⭐ **第三个前缀永远匹配不上**(strip 过的行没有前导空格)⇒ 每台机器那一行
   **整个掉出了指纹** ⇒ Q6(把没读到的存活渲染成 `0.0 min`)被记成 **INERT**。
   ⚠️ **而 INERT 的正确读法是「台子有缺陷」不是「测试很强」** —— 台子自己是这么打的,
   照做即可;若它当时打的是 CAUGHT,这一发会被当成证据存档。

⭐ **两发合起来是一条**:`.strip()` 把「这一行是什么」的信息扔掉了,而那正是**唯一**的区分依据。
⛔ **不登记为已修的通用缺陷** —— 我只改了这两处;同型写法在别处**没有普查**。

### §GM.8 投递(章程 2.5)

| 终点 | 为什么是它 |
|---|---|
| `tools/batch_test/soak/reclaim_blind.py` 自己(头部 GH #699 一节 + 运行时行为) | **投递终点是批测台真正会跑的那个工具** |
| `iterations/streams/batch-desk.md` 闸 (iv) 正文(RULING 8 段) | **那张真被驱动的表**(§DR) |
| `iterations/owed_executions.json`(35 → **36**) | 常驻义务,不属于任何一波、任何一个 id(§DR) |
| `iterations/state.json:GH699_RULING8_20260910T10xxZ` | 判决档案 |
| `iterations/streams/test_set.md §GM` | 本节,全文档案 |
| GH #699 追评并关闭 | 申请方读的活线程 |

⭐⭐ **结清判据这一轮按上一轮「下次触发 ①」修了:`done_when.path` 指向
`iterations/streams/batch-desk.md`(**执行方写的那份**),不再指向本文件。**
上一轮的失效形状是**「判据与档案同处一个文件」** ⇒ 常驻义务在写下的同一秒被自己的档案满足。
⛔ **本节因此不逐字复述判据串**,而判据串是**工具活跑才打得出来的那一行**。
⚠️ **`path_contains_all` 分不清「下游抄回来的读数」与「上游自己写下的判据」的盲区仍在**,
本轮只是把两个文件分开,**不当作那条盲区已修**。

## §GN RULING 9 — 「推的人的闸里没有 Lua 测试」,以及一个**因为什么都没断言而绿了五天**的 CI job

**总监 2026-09-10T12:5xZ。** 报告 `iterations/reports/director/20260910T125000Z.md`。
零 AWS、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件、armed 串不动、无 promote / 无退集。
取活依据:**章程 2a**(`[bug]/[harness]` 直接修)+ 上一轮「下次触发 ①」。

### §GN.0 三件产物

1. **GH #624 裁定 = 选项 1 并当轮落地**:`tools/agent/lua_gate.py` + `lua_gate_measure.py`
   + `lua_gate_manifest.json`,挂进 `.githooks/pre-push` 第三条腿(红 3 / 没跑成 2 都拒绝 push)。
2. **GH #574 关闭** —— 它问的三选一在 09-08 已按**选项 2** 落地(`test_chain_member_census.py`
   打 `LINE NOTE` 保持绿,并换上「每条 judged 行仍有一个可用导航行号」那条替代主张),
   只是 issue 没人关。**不是重新裁,是关。**
3. ⭐ **CI 的 smoke job 五天来什么都没断言**,已修 + 上钉(§GN.3)。

### §GN.1 裁定与它**故意不照抄**的那一处

**选项 1。⛔ 选项 2 不采纳,理由是它自己的失效方向**:它把一件*没人做*的事改写成一条
*要求别人做*的规矩,而现场里那条规矩**已经存在**(铁律 10 的自检确实报了 `worst exit: 3`),
#624 第 (3) 条正是「被报出来之后没人付」的那一段。**一条规矩治不了「这条规矩没人执行」。**
选项 1 也不是新发明:GH #616 在 python 那半做过一模一样的事,立案句逐字同型。

⛔ **成员资格只看实测秒数,永远不看文件名**(GH #616 约束 1),
`tests/test_lua_gate.py` check 1 用「名字与秒数故意矛盾」的 manifest 钉死它。

### §GN.2 ⭐⭐⭐ 本节最该被读的第一段:**测量把我自己的第一版设计判了死刑**

第一版逐字照抄 python 那半(cap 3.0s + 最便宜先进 + 25s),读数 `169 tests / 24.769s`
—— **一个非常健康的 `selected_count`**。把仪器对准闸真正要回答的问题
(「今天 trunk 上红着的,这个闸抓得到几条?」)之后:

| 选法 | 进闸 | 抓到今天的红 |
|---|---|---|
| 最便宜先进 25s | 169 | **3/18** |
| 最便宜先进 60s | 244 | 5/18 |
| **最贵先进 25s** | 10 | **0/18** |
| 最贵先进 40s | 17 | **0/18** |

⭐ **「红确实偏贵」为真(≥1.0s 占红的 72.2%,占全体 36.2%),而据此先拿贵的测出来更糟** ——
它把预算烧在十条恰好是绿的慢测试上。红横跨 **0.13s–5.12s**,
⇒ **不存在包含它们的便宜子集,没有任何排序能救一个小预算。**
⛔ **一个 3/18 而读数健康的闸,正是 §GN.3 在 CI 里刚抓到的那种东西**,只不过是我
**照着自己写的告诫**造出来的。⇒ **预算不再是杠杆,作用域才是**
(而这正是 #624 选项 1 的原话:「哪怕只在它们各自 touch 到的文件被改时才跑」)。

顺手**证伪**一条看起来显然的省钱路:把选中测试塞进一次 runner 调用共享 VM
—— 实测 14 个 census 单跑求和 **31.47s** vs 一次调用 **114.79s**(**0.27x,贵 3.6 倍**)。**不做批处理。**

最终旋钮从覆盖曲线上取:cap **5.5s**(3.0→12/18、4.0→14/18、5.0→16/18、
**5.5→18/18**、6.0 再买不到东西)= **饱和点里最小的那个,不是口味**;
budget **300s** 只留余量。⚠️ 只拟合了一棵树一天的样本,**曲线原样写进代码好让下一个人重扫**。
⭐ budget 第一版 200.0 **当场踩了**:它**先于 cap 触顶**,悄悄砍掉 8 条、把覆盖
**从 18/18 打回 14/18** —— 一个为成本设的旋钮无声否决了按覆盖曲线定的旋钮,**输出里没有东西举手**。

### §GN.3 ⭐⭐⭐ 本节最该被读的第二段:同一形状的第二个实例,在 CI 里**绿了五天**

`.github/workflows/ci.yml` 的 smoke job 跑的是 `lua5.1 tests/test_smoke_load.lua`。
**当场实测裸退出码**:`BARE_EXIT=0`,**输出 0 字节**。Lua 测试文件以 `return tests` 结尾,
直接跑它只是把表加载出来再返回,**一个测试体都不会被调用** ⇒ 那个自称
「every hero file parses under Lua 5.1」的 job **从 2026-09-05 CI 重建起一直是空的**,
**退出码和一次真的通过完全一样**。
⭐⭐ **两个守卫都在,而都够不着一个 workflow 文件里的 `run:` 行**(`run_tests.lua` 的 GH #200
零测试体守卫;`tools/agent/rc.sh` **逐字拒绝这条命令**,本轮开工第一条命令就被它拦过)
—— **想到了、写下来了、装在三个地方,而第四个地方没有门**,与 #624 立案句同构。
⭐⭐⭐ **失效方向**:不是漏报一条红,是**把没做的事报成做过了**;5.2+ 语法(`goto`/`table.unpack`)
按 `AGENTS.md` 分工**正是靠 smoke 兜的**,luacheck 抓不到 ⇒ 那五天那一层**账面上有、事实上没有**。
**已修 + 已上钉**(check 8,按命令**形状**匹配整族,不认某一个文件名)。
⚠️ 该 check 第一版当场踩坑:**修复注释里逐字引用了那条坏命令**,全文匹配**对着已修好的树报红**
—— **分不清「命令」与「关于命令的散文」的检测器会把修复本身报成缺陷**;现改为先剥 YAML 注释,
两个方向都验过。

### §GN.4 ⭐⭐ trunk 上红着的不是 3 条,是 **18 条**;于是闸必须带基线

上一轮记的三条是**自检那条腿在 120s 预算里读到的部分**。本轮全量测量读到 18 条,
**并逐条用「单跑、无负载」复核**(不是从测量轮推断 —— 并发会抬高秒数:
`wk_q_castrange_meter_domain` 负载下 3.597s、单跑 2.64s):`confirmed red unloaded: 18/18`。
⛔ **不做归因**(`bots/`+`game/` 一行未改),只登记来源。

十八条红意味着**一个没有基线的闸从落地第一分钟起会拒绝本仓库每一次 push**,
唯一出路是 `RULE6_BYPASS=1` —— 正是 `luacheck_gate.sh` 头注释点名的
**「把铁律 6 的闸变成铁律 6 的封锁」**,也正是 GH #707 的训练效应。
⇒ 闸的承诺改成诚实的那句:**「你没有*新增*一条红。」**
`known_red` 由工具写(`--set-known-red` 读实测结果文件),**不许手改**。
⚠️ **代价写在代码里**:被基线的测试没人再看。三条反向力 —— **每次运行逐条点名**(不只打计数)、
**转绿会打一行「把我摘掉」**、**只能由工具从实测结果重写**。
⛔ **买不到的那一半**:被基线的测试**因第二个全新原因**再红**仍读作 known**,没有通道分开
⇒ **缩短列表是唯一真正的修法**,打印里就是这么写的。

### §GN.5 证据

`tests/test_lua_gate.py` **40 checks / 0 failed**(`RC_EXIT=0`,走 `rc.sh`);
`tools/agent/mutstand_lua_gate.sh` 见报告 §3.7;
⚠️ **`bots/`+`game/` 一行未改 ⇒ 铁律 6 动态半不声称**(GH #124)。

### §GN.6 投递(章程 2.5)

`.githooks/pre-push` 正文(所有组真会跑到的那个文件)/ `iterations/streams/README.md` 铁律 6
(**那张真被驱动的表**:报告要抄的读数从两行变三行)/
`iterations/owed_executions.json:gh624_lua_gate_first_live_read`(**36 → 37**)/
本节 / GH #624 追评并关闭 / GH #574 关闭。
⚠️ **那一行的 `done_when` 比 gh699 那行弱,已在行内写明**:执行方**不特定**
(任何组的下一次 push),没有「执行方写的那份表」可锚,所以它是**提醒不是证明**。

---

## §GO RULING 10 — 一道闸指名了一个权威,并且**没有给它任何说话的地方**;而那条无声的授权,唯一能被行使的方式是**不跑这道闸**

**总监 2026-09-10T19:xxZ。** 报告 `iterations/reports/director/<本轮>.md`。
零 AWS 支出、零波次、**`bots/`+`game/` 零 diff**、不发 owner 邮件(周日 W37 那封照旧)、
armed 串不动、**无 promote / 无退集**。取活依据:**章程 2a**(`[bug]/[harness]` 直接修)+
批测台 18:14Z 报告 §六(它自己举的手)+ GH #721。

### §GO.0 三件产物

1. **裁定 = 建那个字段**:`wave_fence.py` 新增
   `--director-crossing <ceiling> / --crossing-ref <ref> / --crossing-expiry <instant>`,
   带四条约束(§GO.2)。测试 `tests/test_wave_fence.py` **136 checks / 0 failed**(原 116),
   变异台 `tools/agent/mutstand_wave_fence_ruling10.sh` **9 CAUGHT / 0 SURVIVED / 0 INERT**,
   `RESTORE: byte-identical ok`。
2. **本轮实际裁定**:九月剩余期间 operative ceiling = **`$85.00`**,
   ref `GH#721/director-20260910`,失效 **`2026-09-30T23:59:00Z`**。
   刹车 `$90` 与 owner 批准线 `$100` **一字未动**。
3. ⚠️ **一条附带的、我不解决只登记的矛盾**(§GO.4):归因的两条腿**互相打架**,
   而打架的方向说的是「本台单波 `$1.10` 覆盖档可能不是真上限」。

### §GO.1 缺陷:授权写在散文里,而行使它的唯一走法是缺席

闸 (iii) 的拒绝行从写下那天起就是:

> `Crossing needs the director's explicit ruling that round, plus the written`
> `explanation the charter owes for every crossed threshold.`

**这句话指名了一个权威。它没有给这个权威任何可以说话的地方。**
没有 flag、没有文件、没有字段 ⇒ 一个真的裁了「本轮可以跨」的总监,
递给批测台的是**一份工具无法被告知的裁定**,于是照它行事的唯一走法是**不跑这道闸**。
⛔ **那是一条无界、无日志的绕行,而且是从「缺席」这条谁也审计不了的路进去的** ——
一道闸最坏的失效不是打错答案,是**没有运行过而没有人能看出来**。

⭐ **这正是章程 2.5 那条缺陷(「裁定必须落到被裁方读的那个字段上,而不是落到档案里」)
烧进了工具本身**,而这一次被裁方是一段代码。与 GH #413 两次掉棒同族,
但更极端:那两次至少有一张表可以让义务缺席,这一次**连表都没有**。

⭐⭐ **它两周里从来没有咬过人,这是它能活两周的原因,不是它无害的证据。**
`$80` 围栏 08-28 立,而 MTD 直到 09-10 才逼近它;闸打的一直是 `CLEAR`,
于是「跨档怎么办」这条路径**一次都没有被走过**。18:14Z 是它第一次被需要:
`Headroom was $1.053, this wave needs $1.100` —— **差 `$0.047`,九月还剩 20 天**。

### §GO.2 裁定与那四条约束(每一条都是它不是绕行开关的理由)

**一道闸不许指名一个它没给出发言渠道的权威。** 字段已建,且**建得很窄**:

1. **够不到刹车。** `operative = min(ruling, brake)`;而报出**高于刹车**或**高于 owner
   批准线**的数 ⇒ **`exit 2` 当场拒,不静默夹到刹车**。
   ⛔ 夹会让**一份错裁定读起来像一份被遵守的裁定** —— 这是 §GM「沉默不许是宽松的答案」
   在另一个位置上的同一条。
2. **必须带失效时刻,且每次运行现查。** 没有 expiry 的裁定拒;过期的裁定拒,
   判词逐字是「**过期的裁定不是弱一点的裁定,它不是裁定**」。
   ⭐ 这条封的是每一份跨档裁定都有的那个失效:**为一个月写的,然后安静地变成永久上限**。
3. **必须自报家门。** `--crossing-ref` 必填并原样打印 ⇒ 当轮报告里带着**是谁批的这笔钱**,
   审计的人能去把那份裁定读出来。
4. **每一轮都自己喊出来**,包括 `exit 0` 那一行:
   `WAVE_FENCE: CLEAR (exit 0) -- gate (iii) passes ONLY BECAUSE OF RULING <ref>`,
   并把**推导出的围栏**并排打出来 ⇒ 读的人永远看得见**咬住的是哪一个**,
   以及**其中一个是裁定不是读数**。

⛔ **两个故意留的洞**:(a) MTD 已越过全部告警档(`NO FENCE`)时裁定**不救** ——
那已过 owner 批准线,是 owner 的事,总监的裁定不是它的替代品;(b) 撞刹车时也不救。

⭐⭐⭐ **而它能反过来收紧,这是它是裁定而不是开关的全部理由,也是变异台的载重条款(M8)**:
裁定报的是**上限本身**,不是「解锁」。现场算术:MTD `$84.50` 时 `$80` 已跨,
推导围栏跳到 `$100`、operative 变成刹车 `$90` ⇒ **不带裁定,那一波过**;
**带着 `$85` 的裁定,同一波被拒**。M8 把 `min(ruling, brake)` 换成
`min(max(ruling, fence), brake)`(即「只能抬不能压」)⇒ 台子当场逮住。
**一个只能买余量、永远不会花掉余量的 flag,就是绕行开关。**

### §GO.3 为什么是「跨」而不是「等到 10-01」——以及我在推翻我自己上一条结论

⚠️ **必须先说清楚这一条推翻了什么**:总监 09-10T01:xxZ 的第 15 条增量写的是
「**九月剩下的时间批测台只能收割,不能再发任何一波**」。那句话在当时是对的,
**因为当时没有任何渠道可以行使跨档裁定** —— 它把一个**缺陷的后果**记成了**月份的事实**。
本轮把那个渠道建出来了,所以那句话到期。

**跨档那一轮欠的书面解释(章程要求),就是下面这段**:

- 跨过的 `$80` 是一个**账户**告警档。`dota2bot-batch` 的 `CostFilters` 是 `null`,
  它量的是整个账号 —— 这**不是本轮的发现**,总监 09-05T22:xxZ 已经量过并写进
  `DECISIONS_NEEDED.md` 第 15 条,09-10T01:xxZ 又用 CE 机型拆解把它抬成硬读数。
  **本轮只是免费复核了一次**(`budgets describe-budgets`,`$0`):两张预算
  `dota2bot-batch $100` 与 `FFT monthly budget $150`,**都没有过滤器**,
  ActualSpend **逐位相同 `$77.847`**;告警状态 `$50 ALARM` / `$80 OK` / `$100 OK`。
- **本实验室九月自己花的是 `$29.652 ≤ x ≤ $36.872`**(09-10T01:xxZ 的 CE 机型拆解),
  对着一份 **`$100` 的项目预算**。
  ⇒ **「本项目用掉 78%」是假的;「这个账号用掉了一份为其中一个租户设的预算的 78%」是真的。**
- ⛔ **另一个租户的 `$150` 额度不授权本项目多花一分钱**。它只说明这个账号是**有意共用的**,
  外来花费是**同一个 owner 的另一摊活**,不是泄漏 —— 泄漏检查本轮仍是零
  (批测台 §七:全账号 17 区 `CERTIFIED ZERO`)。
- **`$85` 与刹车 `$90` 之间故意留 `$5`**,让刹车保持**独立止损**的功能;
  `$85` 之上照旧 `exit 3`。⇒ 这份裁定买的是**一条带子,不是一张通行证**:
  约 `$7` / 约 6 波,按闸 (i) 的 6h 节流约 1.5 天满速。用完再来找我,那是有意的。
- ⚠️ **owner 会在跨档那一轮收到抬头写着 `dota2bot-batch` 的 `$80` 告警邮件。**
  那封信**报的不是 dota2bot 的账** —— 这正是 `DECISIONS_NEEDED.md` 第 15 条要 owner
  动手的那一件事(加过滤器),**本轮不重开新问题,只在第 15 条上加一句增量**。

### §GO.4 ⚠️ 一条我不解决、只登记的矛盾:归因的两条腿互相打架

批测台 18:14Z §四 的读法是「九月 25 波 × 覆盖档 `$1.10` = **≤ $27.5**」,
并明说 `$1.10` **按定义高于任一实测点** ⇒ 那是一个**真上限**。
而 09-10T01:xxZ 的 CE 机型拆解给的是 `c6i.4xlarge`(增量原文:**农场唯一机型**)
= **`$29.652`**,**而且那是 00:14Z 的快照,当时波数还更少**。

⇒ **`$29.652 > $27.5`,两条腿不能同时为真。** 三种可能,本轮一条都不选:
(甲) `$1.10` 不是真上限(有波按需降级或跑满机时,单价高于覆盖档);
(乙) `c6i.4xlarge` 不是农场独占(外来那摊也用过这个机型);
(丙) 波次计数漏了波(15 份波记录无 `launched_at`,批测台自己登记过)。

⭐ **失效方向要紧的是 (甲)**:若覆盖档不是上限,那么闸 (iii) 的 `--pending` 估计
**系统性覆盖不足**,而 `--pending` 正是 RULING 4/6 用来扛钱的那一个数。
⇒ **交批测台**(GH #721 追评已点名),**不并进本裁定** —— 它不改变
「本实验室远低于 `$80`」这个结论($29.652–36.872 与 ≤$27.5 都远低于 `$80`)。

### §GO.5 投递(章程 2.5)

`iterations/streams/batch-desk.md` 闸 (iii) 条目(**被裁方读的那一格**,含可直接抄的命令行)/
本节(裁定全文档案)/ `iterations/owed_executions.json:gh721_crossing_ruling_first_live_read`
(**38 → 39**)/ GH #721 追评 / `DECISIONS_NEEDED.md` 第 15 条增量(**不另发信**)。
⚠️ **那一行的 `done_when` 是 `manual`,而这一次执行方是特定的**(批测台),
**不特定的是触发时机**:若九月剩余时间 MTD 不再涨、闸 (iii) 自己放行,
这一行会一直 OWED 到 09-30 裁定过期,那时**按过期退休并在退休行里写明它从未被用上** ——
那不是掉棒,是围栏没有再咬人。📌 **十月不要续期**:10-01 MTD 归零、`$50` 重新变成未跨档,
而工具会**当场拒绝**这份过期裁定(那正是约束 (2) 存在的理由)。
