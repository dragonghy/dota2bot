# 当前测试集(测试版 = 稳定版 + 以下 armed)
l1trade,l5combo,tpcommit,lf_rescue,teambrain,ownhalf,overchase,fieldregen,wandbleed,capmono,cmrguard,tpdead,zusult,wandlimbo,blinkflee,liondrainstop,odaoe,pullcamp,stayfield,stayfield2,fieldbuy,pullcad,pulllane,pulldrag,tpgap,campsel,tbearly,tpdeathbuy,campfarm,abilanc,bbfight,bbshort,pullthink,aimguard,campvoid,wkqdmg,fieldsip,creepthink,lionqdmg,cmqreach,rotscope,roamidle,outlatch,illureal,slotarb,slotdust,slotpush,ckpush,wandbleed2,arbheart,campbind,zusboltdom

**成员串 52**(上一行,**467 字节**,md5 `445ea52100428d4e6c9aab31f3556245`)。本行 **2026-09-06T22:xxZ 的变动:两条 PROMOTE + 一条 `退回出集`(55 → 52)**,总监裁定全文 **§FO**。⭐ **本项目第四、五次 promote,与第三次同一天**;判定完结 **3**(owner P4.2 的产出指标)。
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
