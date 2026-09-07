# 当前测试集(测试版 = 稳定版 + 以下 armed)
tpcommit,lf_rescue,ownhalf,overchase,fieldregen,wandbleed,cmrguard,tpdead,zusult,wandlimbo,blinkflee,liondrainstop,odaoe,pullcamp,stayfield,stayfield2,fieldbuy,pullcad,pulllane,pulldrag,tpgap,campsel,tbearly,tpdeathbuy,campfarm,abilanc,bbfight,bbshort,pullthink,aimguard,campvoid,wkqdmg,fieldsip,creepthink,lionqdmg,cmqreach,rotscope,roamidle,outlatch,illureal,slotarb,slotdust,wandbleed2,arbheart,zusboltdom

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
