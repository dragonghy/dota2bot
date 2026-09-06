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

-108. **⚠️ 下一轮英雄组的第一件事,排在任何自选杠杆之前:GH #566 —— `liondrainbkb`
   的立案前提在真实帧上被证伪,本组要么解释那 8 帧,要么撤下/反向重写这个改动。**
   - **来源**:录像组 2026-09-06T13:09Z 交付(hero-34 / 本组 GH #549 的下一棒)。
     75 局语料里 Mana Drain **16 次**落在挂着真魔免的敌方英雄身上,其中 **8 次**
     该英雄全局只有一个实体(幻象混淆结构上不可能)且**整条引导嵌在魔免窗口内部**;
     三行的 BKB 在起手前已亮 **2.7–7.4s**,而 `lion_mana_drain` 的 `AbilityCastPoint`
     只有 **0.3s**(仓内 KV 快照)⇒「敌人在前摇里才开 BKB」在数量级上不成立;
     `d21f34__20260904_123205_slot1` 逐帧看到目标蓝 **−87** / Lion 蓝 **+157** ——
     **一次生效的抽蓝,不是一次被拒的下单**。
   - **因此**:`X.lion_IsDrainTargetCastable` 头注释那句
     「`SPELL_IMMUNITY_ENEMIES_NO` ⇒ 引擎根本不接受魔免目标」(来源是一次**外部网页
     读数**,仓内**没有任何 KV 快照载着 `SpellImmunityType` 字段**)在本仓语料上
     **被证伪**;团战吸蓝那一支的 `J.CanCastOnMagicImmune` 与观测一致,过严的是
     另外两支的 `J.CanCastOnNonMagicImmune`。**申请书发现的不一致是真的,修正方向反了。**
   - **验收方式(录像组已给可钉帧)**:`b34547__20260905_004847_slot1` **t=1266.4**
     —— 团战 + Q/W/R 全不可施 + 射程内唯一合格敌人 bristleback 处在 BKB
     [1266.1,1274.1] + 引导跑满 **5.1s** 全程在 BKB 里。用 `make_fixture.py` 钉下来,
     断言方向是**「shipped 会施法且该施法有效」**,不是申请书写的反向。
   - **⚠️ 不许自套 `DOMAIN-NOT-REACHED`**:不入集的结论成立,但理由是**方向反了**
     不是域太小。录像组建议新标签 **`PREMISE-FALSIFIED`**,**标签归总监裁**,本组做代码侧。
   - **⚠️ 顺带一条会咬人的**:第 (4) 列(「下了单、没起效」)**结构性买不到** ——
     860 条 `ABILITY lion_mana_drain` 行里 **0 条**在 2.0s 内没有对应 `MODIFIER_ADD`,
     因为 `ENEMIES_NO` 拒收发生在**施法之前**,引擎根本不写
     `DOTA_COMBATLOG_ABILITY` 这一行。**用落点数「被引擎拒收」类缺陷,是结构性失效的口径。**

-107. **Zeus 团战大招的法定人数 `>= 5` 被设在这个计数的上界上 —— 而这一轮最值钱的东西
   **是把「这不是恒假」这一格弱化写清楚,然后用 1012 个真实帧视角把前提变成一次能失败的测量**
   (报告 `iterations/reports/hero/20260906T142000Z.md`,`state.json:zusfightquorum_20260906`,
   `queue.json:hero-38`,GH **#567**;新 `tests/test_zuus_fight_quorum.lua` **16 例** +
   `tests/_zusfightquorum_sweep.lua` + `tools/agent/mutstand_zusfightquorum.sh` **11 变异全杀**;
   `bots/BotLib/hero_zuus.lua` **有真代码行**;选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **本轮的 axis 是新的第七条**:「**一个阈值被设在它所阈值的那个量的上界上**」。
     它是第六条(合取项两端各被一个上界钉死)的近亲但便宜得多 —— 上界不需要任何外部
     读数,它就是一方英雄的人数,而且**语料自己能报**(`C teamcap` = 5)。
   - **事实**:`J.GetInvUnitCount( false, J.GetNearbyHeroes( bot, 1400, true, ... ) ) >= 5`。
     一方五个英雄 ⇒ 值域 `[0,5]`,`>= 5` 要的是**整队**;而前面两道过滤器**只做减法**
     (死的/雾里的被 `GetNearbyHeroes` 扣掉,魔免/无敌/可疑幻象被
     `CanCastOnNonMagicImmune` 扣掉)。一个死了、一个在雾里、一个开了 BKB、
     或者一个站在 1401u,都足以让它为假。
   - **⚠️ 措辞比上一轮弱一格,这是故意的**:`zusultstrand` 是**结构性恒假**
     (两个常数上界之间的算术);这一条**不是**恒假,五个人挤进一个 1400 圈是可能的。
     所以本轮**不写「恒假」**,写的是一次**测量**:1012 个真实帧视角
     (109 fixture × 每个活着的英雄),分布 `0:542 1:251 2:203 3:11 4:5`,
     **最大 4**,`>=5` 命中 **0**,`>=3` 命中 **16 = 1.6%**。
   - **⭐ 前提可以失败,这才是它值钱的地方**:语料哪天出现一个 1400 圈内的五连站,
     §2 **当场变红**并说明原因。同一批行量出 armed 侧的**窄度 1.6%** —— 这是这个
     widening 与空头支票之间**唯一**站着的东西(**M8** 把 armed 降到 1 ⇒ **46.4%**,
     只有这一条断言看得见);**M6** 把半径吹到 16000 ⇒ 每个视角都看见整队,
     **只有扫描看得见**,因为扫描**从英雄源码读半径**、不重打(M13 教训)。
   - **⭐⭐ 缺陷的另一半是「从哪儿量」,本轮故意不动**:雷神之怒**全球**
     (连 `AbilityCastRange` 键都没有),用**施法者**的位置量团战规模,量的是一个
     后排法师**最不该站的位置**。`f_260819_222052_zuus_w2_leak` 里 Zeus 的两个敌人
     **各自数到 4**,而**同一帧**的 Zeus **只数到 2** —— §6 把这条不对称**钉成断言**。
     **换计数中心是第二个杠杆、要自己的 id;不要拿本轮报告当成它已经被判过。**
   - **⭐⭐⭐ 「够不到的阈值」和「根本没被读的阈值」外观相同**(GH #560/#564 的第三格)
     ⇒ §4 打**贴标签的几何注入**(真实句柄、真实谓词,只注入「谁算 nearby」),
     并**先断言注进去的五个真的全部通过 `CanCastOnNonMagicImmune`**;
     **M7**(`nInvUnit` 常量化为 0)**只有这一条断言看得见**。
   - **⚠️ 方向是 WIDENING 不是 NARROWING**:armed 只降低法定人数 ⇒ **只能增加**
     这条分支上的大招施放。负读数**绝不能**读作「少放了 N 次大招」。
   - **⚠️ 覆盖边界,三句不许合并**:(a) 1012 个视角里**绝大多数不是 Zeus**,
     非主体视角**不是创造帧**,只授权关于**值域**的那一句;(b) **十个 Zeus 主体帧
     最多只数到 2**,连 armed 的 3 都没到 ⇒「armed 会触发」**本轮没有人说**
     (§6 单向绊线,红了是好消息);(c) **`J.IsInTeamFight` 不在测试范围内** ——
     它读**友军 bot 模式**,`.dem` 切片不带这一列,§1 只断言两半共用同一个半径常数。
   - **下一棒**:**批测台** `queue.json:hero-38`(零 EC2 归档只读扫描,与 `hero-2`/
     `hero-30`…`hero-37` 并成同一次遍历 —— 现在是**十条同形请求**)。最值钱的一列是
     **(2)「Zeus 自己视角下 == 3 / == 4 的团战瞬间计数」**;读不出它就是
     INSTRUMENT-FAILED,**不许**拿 (1) 的 0 单独下判断(那是本地已测到的,不是波次产出)。
     **总监**:P4.2 冻结期内合法裁定是 **FROZEN-HOLD**。**在 (a) 买到之前不许 promote。**

-106. **Zeus 的「快死了先把大招兑现」那条撤退分支被一个恒假的合取项关着 —— 而这一轮
   最值钱的东西**是把结论写成两个上界之间的算术,而不是写成对一个我判定不了的 getter 的断言**
   (报告 `iterations/reports/hero/20260906T112000Z.md`,`state.json:zusultstrand_20260906`,
   `queue.json:hero-37`,GH **#564**;新 `tests/test_zuus_ult_strand.lua` **14 例** +
   `tools/agent/mutstand_zusultstrand.sh` **9 变异全杀**;`bots/BotLib/hero_zuus.lua` **有真代码行**;
   选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **本轮的 axis 是新的第六条**:「一个守卫式的合取项,两端各自被一个**上界**钉死,
     而两个上界的大小关系让它恒假」。它比前五条便宜,因为**两端的上界本仓都已经有别的
     轮次钉过了**(KV 快照的 `AbilityCooldown` + `jmz_func.lua` GH #215 的重生上限)。
   - **事实**:`X.ConsiderR` 撤退分支 `if bot:GetRespawnTime() > abilityR:GetCooldown()`。
     **右端是常数 130**(`zuus_thundergods_wrath` 的 `AbilityCooldown` 无等级阶梯);
     **左端至多 75**(重生表 25 级 100s × turbo 0.75)。75 < 130,在每一个英雄等级和
     每一个大招等级上 ⇒ **不是过滤器,是关掉的开关**。连带:同文件 `[ultcash]` 的注释
     「上面那条撤退分支漏掉了没进撤退模式的 bot」是**在「撤退分支管用」这个前提下**写的,
     而那个前提从来不成立。
   - **⭐ 读法无关,这正是它写成算术的原因**:`GetRespawnTime` 对**活着**的英雄返回什么
     是本台离线 settle 不了的引擎问题。按「活着返回 0」读是 `0 > 130`;按最宽容的读法
     (这次死亡**将会**的完整时长)读也至多 `75 > 130`。**两种读法都假。**
   - **⭐⭐ 「恒假」和「这个比较根本不看输入」从外面看一模一样** —— 死分支的外观。
     §3 在真实帧上记的每一个 `false` 都能由一个忽略输入的比较式产生 ⇒ §4 打了一次
     **贴标签的注入**(respawn 注到 131 必须翻真);变异 **M7** 只有这一条断言看得见。
     GH #560「不能失败的断言不是证据」的下一格。
   - **⭐⭐⭐ 前提单独钉成可证伪的一句**:§2 **从来源读**两个上界,不重打 130 也不重打 75。
     **M5**(把声明的冷却压到 70)是九个变异里**唯一**能让「恒假」句变成假话的,
     而任何对 helper 返回值的断言都看不见它。
   - **⚠️ 方向是 WIDENING 不是 NARROWING**:shipped 合取项结构性恒假 ⇒ arming
     **只能增加**这条分支上的大招施放。负读数只能读作「多放的那些放错了」,
     **绝不能**读作「少放了 N 次大招」。收窄项是**追兵半径 1600**,它**不是射程项**
     (雷神之怒全球、连 `AbilityCastRange` 键都没有),是「这次死亡会不会发生」的代理。
   - **⚠️ 覆盖边界,两句不许合并**:买到的是**比较式的右端**(7/8 帧 `GetCooldown()`
     读出 KV 的 130)与**半径项**(6/8 帧敌人在 1600 内,位置是帧数据)。
     ⚠️ **那些帧报出的左端 0 是 loader 缺口不是帧数据**(tests/mock 里没有任何东西装
     `GetRespawnTime`,走 `bot_api.lua:182` 的 `^Get` 默认 0),§6 钉成单向绊线。
     ⚠️ **全语料没有创造帧** ⇒「armed 会触发」本轮没有人说:唯一一帧 HP<28%
     (`f_181441_zuus_lowhp_limbo`,15.8%)**同时**落空另外两项(大招剩 2.2s 冷却、
     最近敌人 2017u)。
   - **登记不认领**:同分支下方 `J.GetInvUnitCount(...) >= 5` 形状上像本 axis 的近亲,
     **但本轮没有核实它是不是恒假** —— 下一轮 Zeus 的第一个候选就是它,
     不要拿本轮报告当成它已经被判过。
   - **下一棒**:**批测台** `queue.json:hero-37`(零 EC2 归档只读扫描,可与 `hero-2`/
     `hero-30`…`hero-36` 并成同一次遍历 —— 现在是**九条同形请求**)。
     最值钱的一列是 **(2)「Zeus 死的时候大招是不是还揣着没放」**,它是这个 widening
     唯一的收益来源;读不出它就是 INSTRUMENT-FAILED。
     **总监**:P4.2 冻结期内合法裁定是 **FROZEN-HOLD**。**在 (a) 买到之前不许 promote。**

-105. **Crystal Maiden 的 `X.cm_GetStrongestUnit` 有一个出口报告的不是这只单位的血量,而是
   硬编码的 `500` —— 而这一轮最值钱的东西**是发现 certify 方向的那个扫描是恒等式,
   于是把可证伪的那一条单独拎出来当前提**(报告 `iterations/reports/hero/20260906T080213Z.md`,
   `state.json:cmrangedhp_20260906`,`queue.json:hero-36`,GH **#560**;新
   `tests/test_cm_ranged_creep_health.lua` **16 例** + `tools/agent/mutstand_cmrangedhp.sh`
   **9 变异全杀**;`bots/BotLib/hero_crystal_maiden.lua` **有真代码行**;
   选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **事实**:远程兵早退出口 `if string.find(unit:GetUnitName(),'ranged') ~= nil and
     unit:GetHealth() > GetBot():GetAttackDamage()*2 then return unit, 500 end`。
     两个挑选器的**其他每一个出口**返回的都是单位自己的血量,而 `X.ConsiderW`
     把第二个返回值**当血量用了五次**(四个下界 460/410/390/360 + 两处 `<= nCreepCap`)。
     ⇒ **这就是 `cmcreepcap`(GH #541)修的那个缺陷,从比较式的另一侧进来的,
     而 `cmcreepcap` 结构上够不着它** —— 那根修的是**上限**,这里**被限的那个量本身是常数**。
   - **⭐ 500 同时朝两个方向撒谎,不是一个带符号的错误**:对残血兵**撒高**
     (500 越过全部四个下界 ⇒ 窗口 `(2*ad, 460]`,攻击力低于 230 就非空;
     代价 125-155 蓝 + 6-9s 她唯一单体控);对满血兵**撒低**
     (`500 <= nCreepCap` **每一级都成立** ⇒ 「打不打得死」那个检查在这个出口上从来没跑过;
     窗口 `(nCreepCap, 1100]`,1-3 级非空)。
   - **⭐⭐ 本轮最值钱的一条:方向由构造保证 —— 而 certify 它的那个扫描是恒等式不是第二意见。**
     armed 只改**报告的数**不改**返回的单位**,五项消费全单调、而 500 满足其中每一项
     ⇒ 子集性成立;**但这正意味着逐点子集检查对任何 armed 值都不可能失败**
     (与 README 铁律 4 (i-c) 同一个区分)。所以载重的是**那一条前提**
     「500 越过每一个下界和每一级上限」,而它**可证伪** —— `consumer_floors()` **从源码读**下界。
     变异 **M6**(把 `> 460` 抬成 `> 560`)是**九个里唯一能让窄化句变成假话的**,
     而任何对 armed 值的断言都看不见它。**⇒ 一条可复用的:写完「by construction」之后,
     再问一句「我用来 certify 它的那条断言,有没有可能失败」——不能失败的,不是证据。**
   - **⭐⭐⭐ `liondrainbkb`(GH #549)的教训有了实物变异体**:**M9** 让 armed 返回**常数 1**,
     它在每一级每一个下界上都是 shipped 的严格子集、§3 会盖章;抓住它的是 §6 的**值断言**。
   - **⚠️ 覆盖边界,两句不许合并**:改动的那一项**买不到真实创造帧** —— 全仓 fixture
     **没有任何 creep 单位**(creep 只作为 `recent_damage` 日志行出现,无血量无 handle),
     `bot:GetNearbyCreeps` 在 10/10 个 CM 主体帧上对两队都空。买得到的是 **`lies low`
     窗口的宽度**:真实 Frostbite handle 上 **10 帧里 3 帧**(caps 800/1000/1000)坐在挑选器
     自己 1100 血量门以下,宽 300/100/100;语料 rank 偏高(7/10 已 4 级)**对本改动不利**
     ⇒ 3/10 是**下界不是频率**。⚠️ **`lies high` 窗口的宽度不是真实帧读数**:
     它要 `GetAttackDamage`,而**一份 .dem 切片既不带攻击力也不带攻速**
     (`tests/mock/bot_api.lua:134`)⇒ 全 10 帧读 0,收件条件退化成 `GetHealth() > 0`。
     §2b 把这个 0 钉成单向绊线并明写**不许**读成「窗口最大」。
   - **四条 axis 扫空,逐条登记省下后来的轮次**:(1) `cast_shape_census.py` 焦点五唯一命中
     就是 2026-08-25 的 `cmaurapassive`,**这条线空了**;(2) `item_name_census.py` /
     `facet_census.py` / `call_arity_census.py` 焦点五零命中;(3) **`J.CanCastOnMagicImmune`
     穿透权限审计对 Zeus/CM/WK 是空的**,Axe(#525)与 Lion(#549)是已落的那两处,
     **镜像线索用完**;(4) **`sSellList` 是 `(新, 旧)` 成对表**(`item_purchase_generic.lua:1348`
     的 `for i = 2, #itemList, 2`),所以 `{BKB, quelling_blade}` 是「有 BKB 就卖砍树刀」
     **不是**「把 BKB 卖了」,焦点五五张表全部偶数长度、方向全对;同族的
     `J.SetQueuePtToINT( bot, bSoulRing )` 第二参是**开不开魂戒**,焦点五只有 Zeus 买魂戒
     而 Zeus 传的正是 `true` ⇒ 无缺陷。
   - **登记不认领**:同一出口的 `return` 还**中断搜索** ⇒ 挑选器返回列表序第一只而非最强的,
     与自己的名字矛盾。那是**目标身份**改动,本杠杆故意不做 —— 不动目标正是方向论证的前提。
   - **下一棒**:**批测台** `queue.json:hero-36`(零 EC2 归档只读扫描,可与 `hero-2`/`hero-30`/
     `hero-31`/`hero-32`/`hero-33`/`hero-34`/`hero-35` 并成同一次遍历 —— 现在是**八条同形请求**)。
     最值钱的一列是 **(2)「下单那一刻这只远程兵的真实血量」**。
     ⚠️ 请按游戏时间分层:`DotaTime() > 10*60` 那道门让本杠杆的域**大概率整个坐在 10 分钟之后**。
     **总监**:P4.2 冻结期内合法裁定是 **FROZEN-HOLD**。**在 (a) 买到之前不许 promote。**

-104. **Axe 的「已经中了战意饥渴就别重放」那条否决,八处都测了一个目标永远挂不上的
   modifier —— 而这一轮最值钱的东西**不是缺陷,是 fixture 发现的一个排除项**(报告
   `iterations/reports/hero/20260906T045743Z.md`,`state.json:axebhrecast_20260906`,
   `queue.json:hero-35`,GH **#554**;新 `tests/test_axe_battle_hunger_recast.lua` **20 例** +
   `tools/agent/mutstand_axebhrecast.sh` 8 变异全杀;`bots/BotLib/hero_axe.lua` **有真代码行**;
   选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **事实,两条独立理由各自充分**:`X.ConsiderW` 八处重复
     `and not <target>:HasModifier( 'modifier_axe_battle_hunger_self' )`。(i) **写错了边** ——
     目标身上的 debuff 叫 `modifier_axe_battle_hunger`(`mode_team_roam_generic.lua:1605` 对敌人、
     `hero_largo.lua:316` 对队友,读的都是这个名字),`_self` 那族是 Axe 给自己挂的移速 buff;
     (ii) **而且过期了** —— 全语料施法者那侧拼作 `modifier_axe_battle_hunger_self_movespeed`
     (**18 次**),裸的 `_self` 在**任何帧任何单位上 0 次**,而 `HasModifier` 在引擎和
     `replay_fixture.lua` 里**都是精确名查表**。⇒ 这条否决**结构上恒为真**,Axe 从来没有一次
     因为「目标已经中了」而放弃过。
   - **⭐ 方向是构造保证的子集,但它不是「更少的动作」,两句不许合并**:出货谓词先算并绑定、
     armed 只能 true→false、末句返回 `bShipped` ⇒ `armed 放技能 ⇒ shipped 放技能`。
     但杠杆的**全部意义**就是被否决的候选把分支让给**另一个**目标 ⇒ armed 可以在同一帧发出
     **指向不同目标的**同一个技能。**不许**把负读数读成「少放了 N 次技能」。
     `X.ConsiderW` 是派发链**最后一臂**,斩杀/嘲讽不可能因它改号。
   - **⭐⭐ 本轮最值钱的一条:fixture 发现了一个设计里没有的排除项。** 第一版把**击杀循环**
     也接了线(它是列表分支,子集论证完全覆盖、源码断言全绿)。端到端驱动
     `f_260820_043124_axe_blink_kill` 才看见:`X.WillBattleHungerKill` 的伤害 claim 按**满 12s**
     定价,而**重放正是恢复满 12s 的那个动作** —— 199 血的 WK 身上还剩 6.5s(已在路上只有 130),
     只有重放的满 240 收得掉他;**armed 那版把人头扔了**。击杀循环退线,新文件 §4 钉成未接线。
     **⇒ 一条可复用的:`liondrainbkb` 说「子集性和正确性各一条断言」,这轮是它的下一格 ——
     子集性和「值不值」也各是一件事。** 一个分支可以完全满足子集论证,而窄化掉的恰恰是它
     存在的理由;只有**驱动到底**看得见,`check_armed_wiring.py` 和源码断言都看不见。
   - **⭐⭐⭐ 前提单独钉成棘轮**:带魔晶时 `should_stack` 打开(KV 快照 `base = nil` +
     `special_bonus_shard '1'`),重放变成真正的第二层、支配性论证**当场反号**;而本文件
     **两张出装表都买 `item_aghanims_shard`**。armed 那条腿在 `J.HasAghanimsShard(bot)` 为真时
     **整条站下**。变异 **M7** 就是它:**方向不变、所有子集断言仍成立**,杠杆却从「窄」变成「错」。
   - **接线三处 / 五处不动**:接团战最弱目标搜索、对线消耗循环、撤退循环(遍历列表 + 不声称击杀,
     被否决的候选让给下一个);不接 `IsGoingOnSomeone` / 打野挑选 / Roshan / Tormentor
     (**没有第二候选,否决=纯损失**)与击杀循环。出货那条字面量否决**一处都没删**。
   - **⚠️ 覆盖边界,两句不许合并**:**语料只能演成本侧,买不到收益侧** —— 能驱动的那一帧
     (`f_260820_043124_axe_blink_flee_529`,t=529.6)上,已中招的 WK(339u,770 血,debuff 剩 5.4s)
     是 **800u 内唯一的敌人**,所以 armed 是**放弃**不是**换人**。**两个标注过的翻转**:W 冷却
     4.0→0,以及三种 mode 之一→true(**没有任何 fixture 帧报告 bot mode**,是 loader 缺口不是语料缺口)。
     3 个 debuff 实例是**下界不是频率**。
   - **登记不认领**:`bots/FunLib/rubick_hero/axe.lua` 有同族 7 处(Rubick 偷技能),那里的 `bot`
     是 Rubick、魔晶前提不同,一个杠杆一次,本轮不动。
   - **顺序坑,记下来免得下轮误读**:`check_armed_wiring.py` **读 git ref 不读工作树** ⇒
     commit 之前跑它必然是 `UNWIRED`。
   - **下一棒**:**批测台** `queue.json:hero-35`(零 EC2 归档只读扫描,可与 `hero-2`/`hero-30`/
     `hero-31`/`hero-32`/`hero-33`/`hero-34` 并成同一次遍历 —— 现在是**七条同形请求**)。
     最值钱的一列是 **(2)「重放瞬间射程内还有几个没中招的敌方英雄」**。
     **总监**:P4.2 冻结期内合法裁定是 **FROZEN-HOLD**。**在 (a) 买到之前不许 promote。**

-103. **Lion 的 Mana Drain 会被指向一个魔免的敌人,而这个技能穿不了魔免 —— 而这一轮
   **能验的那一半是分支本身,只要一个翻转**(报告 `iterations/reports/hero/20260906T015205Z.md`,
   `state.json:liondrainbkb_20260906`,`queue.json:hero-34`,GH **#549**;新
   `tests/test_lion_drain_immune_target.lua` **21 例** + `tools/agent/mutstand_liondrainbkb.sh`
   8 变异全杀;`bots/BotLib/hero_lion.lua` **有真代码行**;选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **事实**:`X.ConsiderE` 在**三处**挑 Mana Drain 的目标,补蓝那圈和「打架抽蓝」都用
     `J.CanCastOnNonMagicImmune`,**只有「团战吸蓝」用 `J.CanCastOnMagicImmune`** —— 后者是
     **给能穿魔免的技能用的**谓词(两者的差正好是 `¬IsMagicImmune` 一项,`jmz_func.lua:961` vs `:988`)。
     而 `lion_mana_drain` 的 KV 顶层写着 `SpellImmunityType SPELL_IMMUNITY_ENEMIES_NO`
     (dotabuff/d2vpkr,与 `cast_shape_census.py` 读 `AbilityBehavior` 同一份文件同一层字段)。
     **顺带的否定结果**:Lion 四个主动**全是 ENEMIES_NO** —— 这英雄一个穿透技都没有,
     所以这不是「哪支该用哪个 helper」的判断题,是**三支里有一支声称了游戏不给的权限**。
   - **⭐ 代价不是「白放一次」,是「白清一次动作队列」**:`X.ConsiderE` 是
     `X.SkillsComplement` 派发链的**第一臂**,消费方先 `Action_ClearActions( false )` 再排单再
     `return` ⇒ 下面 R/Q/W 三臂当轮不跑;而这一支只在 Impale/Hex/Finger **全不可施**时才跑得到
     ⇒ **被清掉的正是他仅剩的那个动作**。BKB 5-10s ⇒ **每 tick 复发**。
   - **⭐⭐ 方向由构造保证,NARROWING**:出货谓词先算并绑定,armed 只能把 true 变 false,
     最后一条语句返回 `bShipped` ⇒ armed ⊊ shipped。负读数只能读作「那些抽蓝本来该放」。
     与 `axecallbkb` **互为镜像**(那个穿魔免却多一条否决,这个不穿却少一条)。
   - **⭐⭐⭐ 能验的那一半这次是分支本身**:`f_260820_182906_lion_drain_survived` **t=606.5** 是
     8 个 Lion 主体帧里**唯一**分支前提已成立的一帧(IsInTeamFight=true、drain 2 级、
     Q/W/R cd 6.8/22.7/108.6 全不可施、850u 内两个 >200 蓝的敌人),**唯一翻转是 drain 自己的
     剩余冷却 11.6→0**,翻完真的打出 `ClearActions | UseAbilityOnEntity(drain -> luna)`。
     前四轮都要为「分支跑不到」写免责声明,这轮不用。
   - **⚠️ 覆盖边界,两句不许合并**:8 帧 40+ 个敌方英雄实例**魔免数 0** ⇒ 改动的那一项只能靠
     标注过的 mutation(3c 只翻 luna:OFF 仍指不可达的 luna,ON **改指 crystal_maiden**;
     3d 翻 luna+CM:OFF 白清队列,ON **一条命令都不发**)。那个 0 与「唯一一帧」**都写成单向绊线**。
     ⚠️ `SpellImmunityType` **RECORDED 不是 verified**:仓内 KV 快照不带这个字段(GH #516 同族),
     §KV 把**缺席**钉成断言。
   - **⚠️ 一条可复用的**:**子集性和正确性是两件事,要各写一条断言。** 变异 **M6(否决取反)**
     让 armed 拒掉可达的、放行魔免的 —— 它**仍然是 shipped 的子集**,子集断言看不见它;
     抓住它的是「没人魔免的帧上 arming 必须是 no-op」那一条。同轮 **M3** 是本组第一个
     **源码层完全隐形**的死接线变异(`and hTarget:IsMagicImmune()` → `and false`:
     helper/id/调用点/`check_armed_wiring.py` 全都认)。
   - **负结果登记,省下一轮**:`X.ConsiderR` 的 `475 + 125 * nSkillLV` 看着像「裸字面量 vs KV 梯子」
     的同族货,**但它算出来是对的**(KV `damage` = `600 725 850` 逐位相同;`HasScepter` 那支
     `575+125L` 与 `special_bonus_scepter '+100'` 也对得上)⇒ **维护风险,不是行为缺陷,别当轴。**
   - **下一棒**:**批测台** `queue.json:hero-34`(零 EC2 归档只读扫描,可与 `hero-2`/`hero-30`/
     `hero-31`/`hero-32`/`hero-33` 并成同一次遍历)。**与前五条不同,这条只缺一个变量**
     (被指的敌人当时魔免与否);最值钱的一列是「下了单、1-2s 内没进 `modifier_lion_mana_drain`」。
     **总监**:P4.2 冻结期内合法裁定是 **FROZEN-HOLD**。**在 (a) 买到之前不许 promote。**

-102. **Crystal Maiden 冻兵打钱的血量上限 `<= 1200` **是 Frostbite 4 级那一档**,被当成了
   每一级的上限 —— 而这一根的方向**第一次是 NARROWING**(报告
   `iterations/reports/hero/20260905T231439Z.md`,`state.json:cmcreepcap_20260905`,
   `queue.json:hero-33`,GH **#541**;新 `tests/test_cm_frostbite_creep_cap.lua` 17 例 +
   `tools/agent/mutstand_cmcreepcap.sh` 8 变异全杀;`bots/BotLib/hero_crystal_maiden.lua`
   **有真代码行**;选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **事实**:`X.ConsiderW`「无英雄目标时冰冻小兵打钱」块两条分支各有一处裸 `<= 1200`,而
     Frostbite 对小兵的总伤害 = `damage_per_second 100 × creep_multiplier 4 ×
     duration 1.5/2/2.5/3` = **600 / 800 / 1000 / 1200**(仓内 KV 快照)⇒ **1200 恰好是
     4 级那一档,一个字不差**。⇒ **缺陷不是「数错了」是「对的数被冻在自己梯子的顶端」**
     (与 `zusstatic` GH #173 / Axe R GH #115 §5 同族,形状更干净)。1-3 级各多放行
     600/400/200 血,而且多放行的那一段**正好是挑选器偏好的那一端**(`cm_GetStrongestUnit`
     取最强的那只)。代价 125-155 蓝(GH #126 的常设稀缺)+ 6-9s 她唯一单体控的冷却。
   - **⭐ 方向由构造保证,而这一根是子集不是超集**:`dps*mult*duration <= 1200` 对每一级成立、
     4 级取等 ⇒ armed 是 shipped 的**严格子集**,arming 只能**减少**释放。负读数只能读作
     「那些小兵本来该冻」,**永远不能**读作「杠杆凭空多冻了一只」。
   - **⭐⭐ 而这个方向有一个前提,前提被单独钉成了棘轮 —— 本组第一次这么做。**
     t25 行必须仍取 `{10, 0}`;另一半 `special_bonus_unique_crystal_maiden_1`(+1.0s 持续)
     把 4 级上限抬到 **1600**(引擎折天赋进 base 读数,GH #228)⇒ **方向当场翻成放宽**。
     前三根(`cullthresh`/`wkbonefight`/`zusboltdmg`)的前提都在同一个表达式里,
     这一根的前提**在几十行外的另一张表上**。变异 **M4(duration 项 `+ 1`)** 就是这条:
     它读起来像**修正**(「把天赋算进去嘛」)却把窄化变放宽。
   - **⚠️ 抓住 M4 的是断言的顺序,不是断言的存在 —— 如实记的一次返工**:§3 第一版是单遍循环,
     会在**低级**的严格性上先断掉,**永远打不出那条方向失败的消息**(M4 当时记「RED 但消息不对
     ⇒ 按 survived 处理」)。改成**两遍扫描**(先全梯度扫方向界、再逐级扫严格性)后 8/8。
     M6 同族(裸 1200 的检查排在计数检查后面,打出的是计数消息)。
     **⇒ 一条可复用的:变异台报「RED 但消息不对」时,先查断言顺序,再怀疑变异。**
   - **⚠️ 覆盖边界,两句不许合并**:整块 fixture 驱动不了,而这个零**是 loader 的不是语料的** ——
     `bot:GetNearbyCreeps` 在 **10/10 个 CM 帧上、对两个队伍都返回空表**,而同一棵树里
     `f_212636_tide_ancient.lua` 正文带着 `npc_dota_creep_*`(§5 三条断言);第二堵点是该块
     自己的门在 10 帧里只开 2 帧、那 2 帧上敌方小兵数 0(§5b)。**改动的那一项是真实帧读数**:
     10/10 帧解析出真句柄且三个 KV 读数全为活值,等级直方图 **2→1 / 3→2 / 4→7**,
     armed≠shipped 在 **3/10**(具名帧 `f_113638_cm_chain_rescue`:1200 → 800)。
     ⚠️ 那 3/10 是**下界不是频率**(语料 10 分钟封顶,1-6 级那段结构性偏薄,误差方向不利于本改动)。
   - **⚠️ PROVEN-ZERO 这条线在焦点五里已经空了,别再从它取题**:5 个站点今天逐个读完 ——
     `zuus:947`/`zuus:1063`/`lion:583` 是**已落地修复自己的出厂回落腿**(按 house rule 就该在那里);
     `lion:822`(ConsiderW)与 `lion:1009`(ConsiderE)是**没有消费者的死局部**,删掉零行为改动、
     留着零行为影响,本组不动。⚠️ 那两处**不在** `test_dead_numeric_local_census.lua` 的域里
     (它按自己的 LIMIT (2) 只收 `local n<X> = <数字字面量>`,这两处右边是**调用**)——
     加宽那个域是量具活,不归本组主体配额,**登记不认领**。
   - **下一棒**:**批测台** `queue.json:hero-33`(零 EC2 归档只读扫描,可与 `hero-2`/`hero-30`/
     `hero-31`/`hero-32` 并成同一次遍历)。**总监**:P4.2 冻结期内合法裁定是 **FROZEN-HOLD**。
     **在 (a) 买到之前不许 promote。**

-101. **Zeus 的远程兵狙杀分支**闭式为死**,而算术和真实帧反事实**两样都是本组早就写下的** ——
   这一轮补的是**修复本身**和**方向证明**(报告 `iterations/reports/hero/20260905T200244Z.md`,
   `state.json:zusboltdmg_20260905`,`queue.json:hero-32`,GH **#537**;
   新 `tests/test_zuus_bolt_ranged_damage.lua` 18 例 + `tools/agent/mutstand_zusboltdmg.sh` 8 变异全杀;
   `bots/BotLib/hero_zuus.lua` **有真代码行**;选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **事实**:`X.ConsiderW` 的平伤读 `abilityW:GetAbilityDamage()`,而这个调用只读能力
     **顶层 `AbilityDamage`** KV 字段;`zuus_lightning_bolt` 不声明它(梯子在
     `AbilityValues/damage` = `140 220 300 380`)⇒ 读数**在引擎里**恒 0。
     证明无需句柄解析(`tools/agent/ability_damage_census.py`:`hero_<h>.lua` 里的读只可能
     落在 `<h>` 自己的能力上;全树 128 英雄只有 16 个能力声明非零 `AbilityDamage`,Zeus 一个都没有)。
   - **缺陷不是「小了一点」是「另一个谓词」**:`h < m*(D + h*b)` 在 `D=0` 时退化成
     **`1 < m*b`**,**与血量无关**;出厂 `b=0.09`、`m<=1` ⇒ 分支在**任何**等级 / 血量 / 魔抗下
     都为假。盈亏平衡要 `b>=1.0`,是出厂值的 **11.1 倍**。**闭式为死,不是边际为死。**
   - **⭐ 选题不是翻源码碰运气,是读一个已有的普查。** PROVEN-ZERO 名单在焦点五里有 5 个站点
     (`zuus:888/:981`,`lion:583/:822/:1009`),取其中**方向为「杀死分支」**且**已有真实帧
     反事实**的那一个。剩下 4 个仍在名单上,方向要**逐站点读**(同一个零喂给
     `FindAoELocation` 的 `nMaxHealth` 是**放宽**,GH #175 §2)。
   - **⭐⭐ 方向由构造保证,而这次超集性要经过一个函数,所以单调性必须自己被验。**
     (i) `max` 形状 ⇒ armed >= shipped(§3 扫 6×7 组合);(ii) 判据对平伤**单调不减**
     (§3b 扫 `b×m×h×D` 全格,用**真的** mock `GetActualIncomingDamage` 驱动)。
     前两根(`cullthresh`/`wkbonefight`)靠整数蕴含 `n==1 ⇒ n>=1`,**顺带**就有超集性;
     这一根不行 —— **第一次把单调性单独立成一条断言**。变异 **M4(`>` → `<`,一个字符)**
     读起来像笔误,把 max 变 min ⇒ armed 能答**低于** shipped,静默删掉出厂释放。
   - **⛔ 共臂禁令,发波之前登记**:arming 本 id 把 `abilityASBonus` 的**第二个消费方**
     从空域变成非空域,而那正是 `zusstatic` 的 (a) 能只在 `ConsiderR` 一个消费方上买
     (`hero-15`)的前提 ⇒ **`zusboltdmg` 与 `zusstatic` 不许同波 armed**。钉在三处
     (棘轮 §6 / `state.json` / `hero-32` acceptance),棘轮还额外断言**本 id 的 gate 还在**
     —— gate 一没,修复就成了默认,那时该前提在**每一波**都错,不只是同臂那波。
   - **⚠️ 覆盖边界,两句不许合并**:`X.GetRanged` 需要**小兵单位**,而 `tests/fixtures`
     **没有任何一帧带小兵**;第二条独立堵点是 `GetActiveMode` 恒 0(GH #474)。两条**各写成
     一条断言**(§5/§5b),修好那天红并打出「这是好消息,去重写 §4」。**改动的那一项**是
     真实帧读数(§2d:真实句柄上 shipped=0 / armed=380)。⚠️ 端到端那一帧
     `abilityASBonus` **实测 0**(Static Field 是隐藏内在,`.dem` 不带句柄)⇒ 量到的
     `m=1.00→300 / 0.75→250 / 0.25→50` 是阈值的**下界**。
   - **本轮故意打红并重新推导两条棘轮**(设计上就该此刻响):§1/§6 的锚点从**行**改成
     **表达式**并明写**认证的是哪条腿**;`test_zuus_bolt_kill_cap.lua` 的「恰好 2 个
     `GetAbilityDamage()`」**数值不变**而**理由散文**过时 ——「结论对、原因错」,
     `evidence-discipline` 第 4 条点名的那种。
   - 顺手(附带,不是主体):`test_incoming_damage_callsite_census.lua` 的 grep 计数
     `44→46`,两个**承重**计数(40/41)逐位不变 ⇒ **PURE PROSE**,按它自己的指示三文件同步。
     **已用 `git stash` 差分确认这条红是本轮引入的**(HEAD 上 6/0 绿),归本组修。
   - **下一棒**:**批测台** `queue.json:hero-32`(零 EC2 归档只读扫描,可与 `hero-2`/`hero-30`/
     `hero-31` 并成同一次遍历)。**总监**:P4.2 冻结期内合法裁定是 **FROZEN-HOLD**。
     **在 (a) 买到之前不许 promote;将来入集必须与 `zusstatic` 分波。**

-100. **Wraith King 的 Bone Guard **只在单挑里放**,而单挑是它能加入的最便宜的一场架 ——
   而本轮**能验的那一半第一次正好是改动的那一项**(报告
   `iterations/reports/hero/20260905T170150Z.md`,`state.json:wkbonefight_20260905`,
   `queue.json:hero-31`,GH **#533**;新 `tests/test_wk_bone_guard_enemy_count.lua` 15 例 +
   `tools/agent/mutstand_wkbonefight.sh` 8 变异全杀;`bots/BotLib/hero_skeleton_king.lua`
   **有真代码行**;选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **事实**:`X.ConsiderW` 的进攻分支写着 `#nEnemysHerosInView == 1` —— 一个**决斗判据**。
     Bone Guard 是 `DOTA_ABILITY_BEHAVIOR_NO_TARGET`、**定长 42s** cd、`70 80 90 100` 蓝、
     前摇 0.1、骷髅存活 **40s**、对英雄额外 **+25**(全部由仓内 KV 快照
     `tests/mock/ability_behavior.lua` + `special_value_shapes.lua` 支撑,不是网上引的)。
     **代价一项都不是敌人数量的函数,而收益随敌人数增大** ⇒ 数量不能成为扣着不放的理由。
     与 GH #525 的 Axe Berserker's Call 同读法、**不同机制**(数量前提 vs 魔免前提)。
   - **⭐ 方向由构造保证,不由数据保证 —— `cullthresh` 的教训第一次跨英雄复用**:
     `n == 1` 蕴含 `n >= 1`,对每个整数成立 ⇒ armed 是 shipped 的**严格超集**,
     只能加不能减。变异台 **M4(`>= 2`)读起来就是本轮想做的事**,却**静默删掉**出厂的
     单挑释放;抓住它的是 §3 的**阶梯扫描 n=0..10**,不是任何单值断言。
   - **⭐⭐ 本轮最值钱的一格:能验的那一半这次正好是值钱的那一半。**
     `X.ConsiderW` **整条分支 fixture 驱动不了**,而这**不是本轮的发现** —— 是本组
     2026-08-23 立、08-28 复核、就写在该函数头上的判词(GH #274):charge modifier 在语料里
     **0 个 WK 帧**;第二条独立堵点是 `J.GetProperTarget` 结构性 nil(GH #474)。
     **但改动的那一项不受这两条堵点影响**:`#J.GetNearbyHeroes(bot,1600,true,…)` 算得出来。
     13 个 WK 主体 fixture 的可见敌人直方图 **0→4 / 1→2 / 2→7**;出厂判据放行 **2/13**、
     armed **9/13**;按分支几何切(650 内有敌方英雄)**7 帧**里出厂只放行 **1 个**。
     ⇒ 措辞是**「分支 = 源码级覆盖,改动的那一项 = 真实帧覆盖」**,两句不许合并成一句。
     ⚠️ 计数视野受限 ⇒ 这是**下界**,误差方向不利于本改动。
   - **⚠️ 定价不在这里,而这条指示是本组自己写的**:那段判词最后一句就是
     「Size a Bone Guard change with a batch request, never with a fixture scan」。
     照办 ⇒ `queue.json:hero-31`(零 EC2 归档只读扫描,可与 `hero-2`/`hero-30` 并成同一次遍历)。
   - **⚠️ 充能项本轮不动**:`nStack / maxStack >= 0.6` 的层数 dumper 不记(GH #27 家族),
     语料里 `nStack` 恒 0;`hero-31` 的第 (4) 列专门去要它,**拿不到就明写拿不到,不许用 0 顶替**。
   - **⚠️ 变异台自己踩的**:第一版一行 `echo` 里的反引号被 shell 当命令替换,打出
     `==: command not found`。**不影响施加与计分**(变异走 `sub()` 字面量替换),已改单引号。
   - **下一棒**:**批测台** `queue.json:hero-31`。**总监**:P4.2 冻结期内合法裁定是
     **FROZEN-HOLD**;入集裁定**建议排在读数之后**(同 `-98`/`-99` 的理由)。
     **在 (a) 买到之前不许 promote。**
   - 顺手(附带,不是主体):GH #115 §7.2 点名的**四对「没有明显赢家」的天赋**逐条查过 ——
     Axe t15 / CM t20+t25 / Lion t25 / Zeus t15 **全部已被历轮 TALENTPRICE 定过价**
     (各英雄文件头部的 `TALENTPRICE` 块)⇒ **这条线已经空了**,后来的轮次不要再取它。

-99. **`axecull` 在同一个文件里有一根**没人回头看的兄弟**,而它的两支里**能验的那一半
   不是值钱的那一半**(报告 `iterations/reports/hero/20260905T135708Z.md`,
   `state.json:axecallbkb_20260905`,GH **#525**;新 `tests/test_axe_call_immune_veto.lua` 18 例 +
   `tools/agent/mutstand_axecallbkb.sh` 8 变异全杀;`bots/BotLib/hero_axe.lua` **有真代码行**;
   选题依据 OWNER_PRIORITIES **P4.4**。)**
   - **事实**:`axe_berserkers_call` 的 `bkbpierce` 是 **"Yes"**、`behavior` 是 **`No Target`**
     —— 与 `axecull`(GH #146)锚 Culling 的**同一个文件同一个字段**。而 `X.ConsiderQ` 有
     **两处**魔免否决:(i) 打断分支 `not npcEnemy:IsMagicImmune()`,
     (ii) 先手分支 `J.CanCastOnNonMagicImmune( botTarget )`。
   - **比 `axecull` 强的一格**:这一根的数字**仓内可交叉核对**(`special_value_shapes.lua`
     给 radius 315 / cd `18 16 14 12` / mana `90 100 110 120`,与 odota 逐位相同,
     KV 节按 fixture 自带 KV 四个 rank 全跑)。⚠️ 但 `bkbpierce` **本身没有 KV 字段**
     (同 GH #516 对 `GetAOERadius` 的结论)⇒ **那一半仍是 RECORDED,两句话不许合并成一句。**
   - **⭐ (ii) 不只是一个魔免错误**:Call 是**无目标 AoE 嘲讽**,把它挂在**单个**
     `botTarget` 的属性上,连带丢掉**同一 315u 环里的其他所有敌人**。
     一个带 BKB 的核心 + 两个脆辅助 = 一发三人 Call,出货 bot 一个都不放。
   - **⭐⭐ 本轮最值钱的一格:能验的那一半和值钱的那一半不是同一半。**
     7 个 Axe-subject fixture 上量到 **「Call 就绪」与「环内有敌人」从不共现**
     (就绪 5 帧 / 环内 1 帧 / **共现 0**;唯一环内那帧 Call 在自己 18s cd 的 **17.0s** 上
     —— Axe **刚放完**),零引导瞬间、零魔免瞬间 ⇒ (i) 需要**三个**翻转的反事实
     (按 **2×2 逐个隔离**,不并池)。而 (ii) 的三条堵点**逐条量过**
     (`botTarget` 恒 nil / GH #474、本帧 `IsGoingOnSomeone` false、唯一环内敌人
     `IsDisabled` **true**)⇒ **只有源码级覆盖**(`zusaether` 处置)。
     把三条都打桩去驱动它就是**接线测试**,AGENTS.md 明写那不算本地验证 ——
     所以**不假装**,三条堵点各写成一条断言,**修好那天它红并说出来**。
   - **⚠️ 归因边界,发波之前登记**:两支共用一个 id ⇒ 负读数**不能归因给其中任何一支**,
     那时的下一棒是**拆 id**不是否掉事实。写在**三处**(helper 头注释 / `state.json` /
     `queue.json:hero-30` 的 acceptance),因为它是事后最容易被读反的那种句子。
   - **⛔ 不许把 `axecull` 的「下界由血量测试给定」搬过来**:那根有击杀保证,这根没有。
     这根的下界是别的东西 —— (i) 靠「正在引导的敌人本来就没在攻击」,
     (ii) 靠**上游未改动的** `J.IsGoingOnSomeone`(Axe 已经决定压上去了,
     加宽只多出嘲讽 + 12/13/14/15 护甲;拉进环内其他敌人**不是新代价**,
     目标不魔免时出货分支本来就放同一发)。
   - **⚠️ 可迁移(本轮写进新 stand 的一道门)**:`sub()` **锚点不唯一也 abort**,不只是
     缺失才 abort。`X.ConsiderQ` 与 `X.ConsiderR` **隔两百行各有一条几乎相同的魔免子句**,
     `replace(..., 1)` 会打到另一处并记成 `SURVIVED`。`-91`/`-94` 各花一格才发现,
     **这次第一次写进新 stand 而不是事后补**。
   - **下一棒**:**批测台** `queue.json:hero-30`(零 EC2 归档只读扫描,可与 `hero-2`
     并成同一次遍历,两支**分开报**,带 DOMAIN-NOT-REACHED 退回门与预登记判读方向)。
     **总监不必裁入集** —— P4.2 冻结照旧,且读数**应当排在入集之前**(同 `-98` 的理由)。
     **在 (a) 买到之前不许 promote。**
   - 顺手(附带,不是主体):**GH #465 复核完毕** —— 录像检查组把 `nBand == 0` 改写成
     `nBand == 1` + 指认那一对 + 注释里写算术,**措辞与算术都对,本组不动那个文件**;
     §验收第 2 条同意。**issue 不关**(第 2 条是给未来的指示,`-98` 刚记过这类指示的读法)。

-98. **注册杠杆 `hero-2` 落地了(gated `cullthresh`),而**四轮里没人写它**的那个理由,
   今天只剩一半 —— 另一半死在一个**供给事实**上不是一个论证上**
   (报告 `iterations/reports/hero/20260905T110023Z.md`,`state.json:cullthresh_20260905`;
   新 `tests/test_axe_cull_threshold_gate.lua` 21 例 + `tools/agent/mutstand_cullthresh.sh` 8 变异;
   `bots/BotLib/hero_axe.lua` **有真代码行**,选题依据是 OWNER_PRIORITIES **P4.4**。)**
   - **事实**:`axe_culling_blade / damage = '275 375 475'`,出厂 `X.ConsiderR` 用
     `150 + 100*lv` = 250/350/450 ⇒ 低 **25**,在 `(250,275]` 带上**放弃必杀**。
     `kvgetters` 之后这个差**第一次是真实帧上的读数**:`f_260820_043637_axe_ring_close.lua`
     上能力答 **275**、公式给 **250**。
   - **⭐ 本轮最值钱的一格:第一版守卫 `nLive > 0` 是错的,而它错得看上去显然够用。**
     它过每一条 gate 接线检查,而**一个小的正读数会把斩杀线收窄** —— 这根杠杆
     唯一被禁的方向,**而且静默**(没有计数器会报「Axe 不再斩杀了」,那是没发生的事)。
     抓住它的是**扫读数阶梯**的方向用例,不是任何单值断言。改成**出厂值当地板**
     (`nLive > nKillDamage`)⇒「只能加不能减」**从一句关于数据的断言变成一条关于代码的性质**。
     **可迁移**:凡是「armed 只能收紧/只能放宽」的候选,都要问一句
     **「这是代码保证的还是今天的数据碰巧保证的」**。
   - **⭐⭐ 为什么现在可以写:preflight 的判词只过期了一半,而过期的那一半死在供给上。**
     「25 点带,帧语料量不了」**仍然成立**(全语料 29 Axe 瞬间 / 23 可放 / 3 行环内 / 带内 **0**;
     八月同口径 26/20/3/0 ⇒ 漏斗长了零没动)。过期的是「所以到事件侧去量」那一半:
     `test_axe_culling_band_power.lua` 早已把**穿越**定价好,挡住它的是批测台
     2026-08-23 的「Axe 出现 **0/306** 局」—— 而
     `tests/fixtures/tl_260905_010226_axe_outchan.json`(逐字切自归档时间线,
     run `spot_20260905_003250`,**seed 4763**,subject = axe)**证伪了那一句**。
     ⇒ 从「量不到」变成「还没量」,**而还没量正是 gate 的用途**。
   - **⛔ 三条兄弟棘轮按名字响了,全部重新对准而不是放松**,其中 preflight 的失败文案
     **自己写着「删掉 §1 和 §2」** —— **只执行了一半,而不执行的那一半有理由**:
     那条指示假设修法**不带闸**落地;带闸之后 §1 的不变式**更需要**(gate-off 必须逐字
     保住出厂常数,否则「未 armed 时 inert」**读不出来**),§2 的绊线也**更需要**
     (gated 杠杆比不带闸的更缺那一帧)。`band_power` 写着「if a gate appeared … retire
     this file」—— **一个数没编,但文件没退休**:它的穿越模型正是下一棒要用的方法。
     **可迁移:一条写给未来的指示,是在它自己想象的落地形状下写的;落地形状不同时,
     照抄它比违反它更危险。**
   - **⚠️ 代价已登记**:补丁若把 KV 阈值调到**低于**手写值,helper 会保留旧高值 ⇒
     去斩斩不死的目标。拦它的是**两处 25 点棘轮**(新文件 §1 + preflight §1),先红并点名。
   - **⚠️ 本轮自己踩的**:`io.popen('ls ' .. dir)` 遍历两个目录,立刻被
     `test_bots_walk_farm_only.py` 报成静态解析不了(与 `-96` 的 Lion 文件同一格)。
     改成**两条字面量命令**,**没有**去买 `UNRESOLVED_HAND_READ` 豁免 ——
     两个元素的循环不值得花一张手读券。
   - **下一棒**:**批测台**做归档**穿越**扫描(`queue.json:hero-2` 的
     `supply_unblocked_hero_20260905`,零 EC2,§BF.2 早已放行);拿回 `(game, t)`
     本组钉帧。**总监**的入集裁定**建议排在读数之后** —— 带内 0 的语料上 armed
     一波读回来的 0 **归因不了**(空 arm)。**在 (a) 买到之前不许 promote。**

-97. **GH #502 的最后一格判了 —— `GetAOERadius` **在全树 127 个英雄的 KV 里没有对应字段**,
   于是 810 不许换掉 835(报告 `iterations/reports/hero/20260905T075200Z.md`,新 GH **#516**;
   新 `tools/agent/aoe_radius_source_census.py` + `tests/test_aoe_radius_source_census.py` 6 例;
   `bots/` 与 `game/` 零行)。**
   - **⭐ 「映射没确立」被量成了「映射不存在」**:另外六个 getter 全靠**同名字段**被服务;
     实测 **127 个 KV 文件 / 31 个不同顶层 `Ability*` 字段 / 含 "aoe"|"radius" 的 0 个**。
     它是 C++ 侧的量 ⇒ 那条规则**接不上**,不是「还没接」。
   - **⛔ 冻结 snapshot 按构造答不了这一问,而「答不上来」长得像「没有」**:
     `parse_shapes` 只记 `TOP_LEVEL` 白名单里的顶层字段 ⇒ 一次 grep **只可能为空**。
     新测试把这条失明本身钉住(`test_top_level_whitelist_carries_no_aoe_field`)。
     **同族 `-94` 的「覆盖一个活着的 getter 而没有任何东西举手」,反向:这次是
     「一次注定为空的 grep 会被当成确认」。**
   - **⭐⭐ 决定性的是 7 个真调用点不是百分比**:两条手写规则(名字 `radius` /
     标志 `affected_by_aoe_increase`)只有 **1/7**(sniper)同意同一个键;
     CM 大招上名字规则挑 810 而标志规则给三个 ⇒ **挑 810 是选择不是读取**;
     drow W 与 muerta W **没有叫 `radius` 的键**。**两条规则合报会互相掩护**
     (并集把 drow 那格印成一个干净候选 `wave_width` —— 而那是**宽度**)。
   - **裁定 = #502 路 (b)**:`FIELD_RADIUS` 留 835;loader 不许把该 getter 接 KV;
     那节没松成容差。并改掉一句已为假的话:「`radius` 若移到 835 则缺口关闭」——
     **数值相等 ≠ 同一个量**(同 `-93`「残量不是队列」那一族的判别式错位)。
   - **下一棒(GH #516,[harness],球不在本组)**:dumper 每个 ability 句柄记
     `aoe_radius`。读数回来本组重推两个 end-to-end case 并关 #502;
     **在那之前不许有人**用 810 重新推导任何东西。
   - **⚠️ 可迁移**:数调用点的正则**锚在命名习惯上**(`ability<X>`)时 7 个只找到 **6**
     个(rubick 副本句柄叫 `FreezingField`)—— **6 是一个看上去很完整的数字**。
     自检要断言总数,别只断言「找到了一些」。

-96. **`-95` 的下一棒(类戊第一根,Lion Hex)预检完毕 —— **不写**,而那个 0 是语料的不是杠杆的**
   (报告 `iterations/reports/hero/20260905T045549Z.md`,GH **#512**;新
   `tests/test_lion_hex_reserve_domain.lua` 6 例;`bots/` 只有注释,零代码行)。**
   - **⭐ 照 `lionult`(GH #73)的先例先量域再写杠杆,域没买到**:
     24 live-Lion → 22 Hex 已学 → 11 不冷却且可付 → **1** 在 0.30 储备线下 →
     **0** 同时 1600 内有敌人。唯一那格 `f_megabundle_051728_ogre_lanefront_deep`
     (6 级 / 176 蓝 / 池 621,Impale 冷却 3.2s,Finger 付不起,**零敌人**),
     出货 `ConsiderW` 本来就 `DESIRE_NONE` ⇒ 接线是 **0 变 0**。
   - **⭐ 零不是阈值选出来的**:树里有**两个**活储备数不是一个 ——
     `GetManaAfter > 0.3`(ConsiderQ 字面量)与 `fKeepManaPercent = **0.39**`
     (IsAllowedToSpam)。0.30 线下 1 格、0.39 线下 2 格,**两个阈值上交集都空**。
   - **⭐⭐ 讲得出理由的那个窄版本域更空**:「别把跟手的 Impale 饿死」
     (储备条件挂在被储备的对象上)在 9 个 Impale 就绪的可付格上是 **0/9**。
     **按「哪版更好辩护」挑和按「哪版量得到」挑,在这根上指向相反。**
     同族:`-93` 残量不是队列、`-94` 四分之四是四个处置。
   - **⛔ 这个 0 不是裁决,是 GH #474 在第二个现场**:`ConsiderW` 在**全部 11 个**
     可付格上都 `DESIRE_NONE`,**包括 1600 内确实有敌人的那 3 格** —— 每条分支都挂在
     模式/目标上,而每个 fixture 帧 `J.GetProperTarget=nil`、`GetActiveMode=0`。
     ⇒ 档案**演示不出一次 Hex 施法**,它**没资格**说「储备改不了什么」;
     它有资格说的是**这里没有一帧写得出 fixture**。**被帧供给卡住,不是被证伪。**
   - **⛔ #73 的 strike 不能搬过来**:`lionult` 死于闭式(带宽 = 最便宜基础技能,
     Impale 阶梯终止于 150,池不终止 ⇒ 占比→0)。这根**没有那个终止**:可咬占比上限
     `0.30 + hexCost/maxMp`,Hex 阶梯终止于 200 ⇒ 第二项收缩但**收敛到 0.30 不是 0**
     (实测池 510→0.692、池 1551→**0.429**),**任何等级都不会消失**。§4 断言就是拦这个引用。
   - **⚠️ 可迁移**:**mock 把 `print` 换成空函数**(`tests/mock/bot_api.lua:410`)。
     `require('mock.replay_fixture')` 之后用 `print` 的一次性探针**静默输出零字节且 exit 0**
     —— 「跑成功了但什么都没打」与「没跑」在退出码上是同一个整数。**探针一律 `io.stderr:write`。**
   - **下一棒**:求帧已交出去(**GH #512**,判据 1-3 必需 / 4 最好有;不花 AWS 钱)。
     **球在录像检查组**;#474 那条线在总监手上。拿到帧本组自己接着走 gated-fix。
     **类戊第二根(Zeus `ConsiderE` / Heavenly Jump)在拿到 Lion 这一帧之前不要开** ——
     两根一起接就是 `lanefix` 的形状(`-95` 自己写的)。

-95. **`-75` 兑现了,而它的九个死绑定**不是一根杠杆,是五个类、两根杠杆**
   (报告 `iterations/reports/hero/20260905T015048Z.md`;新
   `tests/test_dead_manacost_binding_census.lua` + `tools/agent/mutstand_dead_manacost.sh`;
   `bots/` 只有两处注释共 18 行,零代码行)。**
   - **⭐ 摁死「显然的读法」的那条事实**:九个 `local nManaCost = ability:GetManaCost()`
     **全部**坐在自己函数的 `IsFullyCastable()` 早退之下,而引擎的 `IsFullyCastable`
     已经是「不冷却 且 学过 且 蓝 ≥ 价」⇒ **付不付得起在上游就答完了**,
     这个绑定**从来不是**它名字暗示的那次读。树里两个活惯用法
     (`J.GetManaAfter(c) > 0.3` / `J.IsAllowedToSpam(bot,c)`)问的是**储备**,
     ⇒ 「接线」不是修漏读,是**给一个本来没有储备的决策加一道逐次施法的储备**。
   - **⭐ 五个类,每个判别式都在源码里量得到**:
     **甲 已有竞争储备**(CM `ConsiderQImpl`/`ConsiderW`、Zeus `ConsiderW2`:`nKeepMana`)——
     接线是**叠第二道**不是填空;
     **乙 储备被闸冻死**(Zeus `ConsiderW`:唯一储备 `J.ShouldConserveManaInLane` 第一句是
     `IsLaneFixOn('mana')` ⇒ **出货 trunk 恒 false**,而 armed 域正是**被拒两次的 `lanefix`**)——
     **它在源码里像甲、在游戏里像戊**,差别只有跟进 jmz_func 才看得见;
     **丙 它是大招**(Zeus/Axe `ConsiderR`)—— 为小技能扣住大招 = **储备指反了**,
     Zeus 指对方向的那根本来就在(`X.zuus_ShouldSaveManaForUlt`);
     **丁 这个技能回蓝**(Lion `ConsiderE`/Mana Drain,读 `mana_per_second`)——
     `GetManaAfter` 会**恰好在蓝低时拒绝去吸蓝**,**符号相反**;
     **戊 什么都没有**(Lion `ConsiderW`/Hex、Zeus `ConsiderE`/Heavenly Jump)——
     **九个里只有这两个**方向一致。
     ⇒ **同 `-93` 的「残量不是队列」**:看着像一条待办的九分之九,**它是五个处置**。
   - **域价钱**:全树 275 文件 / 2593 跨度 / **189 个绑定 = 死 82 + 活 107**(43% 死),
     焦点五 9 死。**比 `-85` 的 46 还大**,而剩下 73 个在非焦点文件里 ⇒ 作用域,登记不动。
   - **⛔ 为什么不清零**:`-85` 删未读**数字字面量**是因为那些是**假前提**
     (Zeus 那个从不存在的 1600)。**这九个不是假前提**,每一个都持有一个**真**价钱;
     删掉会抹掉「此处缺储备」的唯一标记 ⇒ **留着,改成登记**。棘轮 `<=` **不是 `==`**(GH #457)。
   - **⭐ 下一棒(本组自己的,一次一根)**:类 戊 挑 **Lion `X.ConsiderW` / Hex** ——
     Lion 全文件**没有任何**储备(`nKeepMana = 400` 2026-08-20 已被证零读者删掉),
     所以它是**加第一道**而不是加第二道。gated turbo 候选 + 真帧 fixture,
     走 `.claude/skills/gated-fix/`。**两根一起接就是 `lanefix` 的形状。**
   - **⚠️ 可迁移(本轮自己踩的)**:**变异台用 `cp` 还原 = 给同容器任何并发读者开一个撕裂窗口。**
     后台跑的开工自检 Lua 腿读到半份 `jmz_func.lua`,红成
     `jmz_func.lua:6986: 'end' expected ... near '<eof>'` —— 而该文件 **12606 行、`git diff` 零行**,
     **那个行号在任何版本里都不存在**。归因不是 M4 拆坏了 `if`(它换掉的那行自己就平衡)。
     与 `lua_source_scan.lua` 头注释记的 `soak_side.lua` 窗口(GH #365 §2)同族,
     但**写者是变异台、被写的是 shipped 源码**。⇒ **不要让变异台与全量套件/自检同时跑**;
     结构修法(写临时文件再 `mv` 原子替换)不是本组作用域,**已开 GH #507 交出去**。

-94. **`-76` 的四个文件读完了,而立案句「这个数 dump 给不了」今天**不是一个理由是四个**
   (报告 `iterations/reports/hero/20260904T225049Z.md`,GH **#502**)。**
   - **⭐ 形状**:09-01/09-04 的 `kvgetters` 让 loader 按 fixture 自带 KV 逐 rank 服务
     七个 getter(**只对焦点五**)。在那之前测试里的手写常量是**代替一个哑掉的 getter**;
     在那之后同一行变成**覆盖一个活着的 getter**,而**没有任何东西举手** ——
     读数不动、不红、grep 搜不到,正是 `-72` 立的那一类。
   - **⭐ 四个文件给出四个互不能推广的结论**:`zuus_script` **四个手写数与 KV 全不符**
     (arc 850/80 vs rank2 **800/90**;bolt 825/125 vs rank1 **700/120**);
     `cm_q` 三个全符;`axe_cull` 五个数三个 rank 全符;`cm_r_range` 三个锚
     **各因不同理由**仍承重(两个是**非焦点被按设计拒绝**,一个是 **`GetAOERadius`
     根本不在被服务的七个 getter 里**)。⇒ **同 `-93` 的「残量不是队列」**:
     看着像一条待办的四分之四,**它是四个不同的处置**。
   - **⭐⭐ 最硬的一格是 `zuus_script` 的第二句立案句,被阴性对照打掉**:
     它说不放技能是「lf_mana 闸 + Zeus 自己的 nKeepMana 储备」。实测
     `SkillsComplement` 这一帧 **queue 零个 action**(两个 `assert_no_harass`
     **一次都没比较过名字**,空域);把它点名的两个杠杆都给满(**满蓝 + Q/W 冷却清零**)
     **仍然是零**,五个 `Consider*` **全部 desire 0**;arc lightning 按 KV 价
     `IsFullyCastable()==true`,`J.CanNotUseAbility` 为 false,量具 sanity 捕得到。
     ⇒ **法力可证不是这一帧的判别式。**哨兵留着,空域登记成**会响**的断言。
   - **⛔ 唯一没判的一格已交出去(GH #502)**:`crystal_maiden_freezing_field` 的
     KV `radius` 答 **810**,而 `cm_r_range` 按 Liquipedia 跑 **835**。
     键→getter 的映射没确立之前**不许**拿 810 重新推导(= 用没定价的量换有出处的量);
     两个数都钉住,M9 证明那节会响。是同一个量 ⇒ `FIELD_RADIUS` 从 KV 取并重推两个
     end-to-end case;不是 ⇒ `GetAOERadius` 该不该上规格,**GH #495 同族**。
   - **⭐ 可迁移(变异台量出来的,两条)**:
     (甲) **`-91` 那道锚唯一性守卫本身有一个失效开放的形状**:`grep -F` 把多行 pattern
     拆成独立行 pattern 并按「匹配任一行」计数,**一个恰好出现一次的两行锚被报成 3 次**
     ⇒ 守卫在它唯一存在的理由上失效开放。改成在 python 里对**全文**计数;
     **别的 stand 还是 grep 版。**
     (乙) **M3 曾经 SURVIVED,而那是变异体写错了不是断言睡着**(注入的 action 排在
     `record_actions` 装钩子**之前**)。evidence-discipline 第 2 条**先怀疑变异体**。
   - **明写的 LIMIT**:§D 的满蓝对照**无法**用「删掉驱动」打红 —— 两个世界都答 0,
     **那正是发现本身**。M4 只证明计数器接在 log 上,**不证明对照今天在做功**。
   - **下一棒**:本组这条线到此为止(`-76` 清空)。#502 的裁定球在**总监 / #495 那条线**。

-93. **`kvgetters` 第三撮已发(`-92` 的「⭐ 下一撮」DONE),而它的结论是**残量不是队列**
   (报告 `iterations/reports/hero/20260904T195041Z.md`)。**
   - **⭐ 六个残余 `Ability*` 键里五个发不了,理由分三类、互相不能推广**
     (语料句柄数,不是快照条目数 —— 两个都对,量的不是同一个东西):
     **(甲) API 里根本没有 getter**:`AbilityModifierSupportValue`(308)、
     `AbilityChargeRestoreTime`(51)。
     **(乙) 有 getter,焦点五零消费者**:`AbilityChannelTime`(80,5 处全非焦点)、
     `AbilityDuration`(56,4 处全非焦点)、`AbilityCharges`(51;`GetCurrentCharges`
     14 处里 13 处是物品句柄,唯一技能句柄是 techies)。
     **(丙) 两半齐全**:`AbilityDamage`(29)—— 已发。
     ⇒ **「还没上规格的键」看上去是一条待办队列(一个数,做完少一个),它不是。**
     按「把残量清零」推进会**接五个没人读的 reader** —— GH #471 那句
     「接线是纯粹的无效改动**加**一份新的闸债」发生在 mock 里的形状。
   - **⚠️ 而且 `-92` 让我问的那个问题在这一撮上问不出来**:「那个 0 落在比较式哪一边」
     **预设了存在一个比较式**;这五个键连读它的那一步都不存在。
     **⇒ 每一撮先问「这个键有没有 getter、有没有消费者」,再问方向。**
   - **`AbilityDamage` 发了,而它一位读数都不动**:快照里**声明**该键的焦点技能只有
     `axe_berserkers_call`(`0 0 0 0`),而焦点文件里**调用**该 getter 的三处
     (`X.GetImpaleKillDamage`/`X.GetBoltKillHealthCap`/`X.ConsiderW`)调在**不声明该键**的
     技能上 —— **交集是空的,两条路都到 0**。发它换的是**理由**:`lionqdmg` 与
     `zusboltcap` 的立案句都是「出货那次读是硬 0」,而此前那个 0 来自 `bot_api.lua` 的
     通用 `^Get`(**对的答案错的来源**)。第二个独立见证:`tests/mock/ability_damage.lua`
     的 `NONZERO`(全 128 英雄)**焦点五一个都不在**。
   - **✅ `zusboltdom` 的处置已写清(`-92` 的 ⛔ 已兑现)**:本次落地**不会**让
     `X.GetBoltKillHealthCap` 变非 0(`zuus_lightning_bolt` 真的没有该字段,**引擎也答 0**)
     ⇒ **`zusboltdom` 未被触碰,不需要重裁**。真正会触发那条处置的是
     **GH #175 / `zusboltcap` 自己域内的 KV 修复**。`§9c` 是那道门:任一焦点英雄拿到
     非 0 `AbilityDamage` 就红,并点名 `lionqdmg`/`zusboltcap`/`zusboltdom`。
   - **⭐ 可迁移(变异台量出来的)**:**值没动的落地必须自带一发「装没装」的白盒变异**。
     M14(不装 `GetAbilityDamage`)**让每一个读数原封不动**,只有 §9b 的白盒断言抓得住;
     没有它,§9b 就是同义反复。M17/M18 是同族的另一半:**先打死扫描器/遍历,
     看供给量断言会不会先红** —— 否则负结论(「零焦点消费者」)是免费拿到的。
   - **下一撮没有了**。要再动这台仪器,球在别人:per-unit health regen(**GH #493**,录像组)。
   - 顺手记一格(**零行为影响,不是本组这轮的活**):`tests/mock/ability_damage.lua`
     的生成头注释引用 `tests/test_ability_damage_reads.lua`,**该文件在树上不存在**。
     生成器 `tools/agent/ability_damage_census.py` 里的陈旧引用,`citation_audit.py` 管的那一类。

-92. **`kvgetters` 第二撮已发(`-87` DONE),而它交出的两条结论**互相矛盾到不能合并成一句话**
   (报告 `iterations/reports/hero/20260904T170247Z.md`,`state.json:kvgetters2_20260904T`)。**
   - **⛔ 不要把第一撮的方向规则搬到第二撮**。第一撮(cast range)是「读 0 ⇒ 环变小 ⇒
     低估可达 ⇒ 制造『这条分支到不了』」。第二撮里 **`GetCooldown` 的那个 0 坐在比较式的两边**:
     `J.CanUseRefresherOrb` 的 `remaining >= ultCD/2` **整条蒸发**(194 帧里 36 帧通过 → 真冷却下 3 帧,
     **92% 是空条款**),而 `J.CanUseRefresherShard` 多要的 `ultCD - remaining >= 2` 变成
     `remaining <= -2`,**算术上不可能**(0 帧 → 6 帧)。**同一个 0,相反的两个方向。**
     ⇒ 「未上规格的 getter 会让守卫变宽松/变严格」这种顺口规则**怎么写都有一半是错的**;
     分界是**那个 0 落在比较式的哪一边**,要**逐个消费者**看。
   - **⚠️ `GetCastPoint` 接上了但是死的,而这是量出来的**:它唯一的下游是
     `GetHealthRegen() * nDelay`,而 **`GetHealthRegen` 自己也没上规格**(loader 里一次都没出现,
     dump 里没有这个字段)⇒ `0 × 任何东西`。实测 13 帧 / 58 对 / **0 次击杀判定翻转**。
     **同 `-88` 的 `0 == 0` 形状:下游有恒 0 因子的读数量的是合取。**
     **本快照关不掉它** —— health regen 是逐帧单位状态不是技能 KV,**要 dumper 出字段,球在录像组**。
     `tests/test_fixture_kv_getters.lua` §7c 的断言**会响**:regen 一旦非 0 直接红,
     消息里写明「这是好消息,去重跑 §7d 把 0 换掉,**不许松成 `>= 0`**」。
   - **⭐ 下一撮(本组自己的)**:快照里还在通用默认值上的 `Ability*` 键只剩一小把 ——
     `AbilityModifierSupportValue`(9)、`AbilityChannelTime`(2)、`AbilityDuration`(1)、
     `AbilityDamage`(1)、`AbilityCharges`(1)、`AbilityChargeRestoreTime`(1)。
     做法照抄本轮三步:**先量人口 → 再逐个消费者看那个 0 落在比较式哪一边 → 再发**。
   - **⛔ 但 `AbilityDamage` 那一个不许顺手发**:`-89 (乙)` 明写 —— 修好
     `GetAbilityDamage()` 会让 `zusboltdom` **自动变成 no-op**(它按上限的**值**开关),
     那是设计不是回归,**但登记它的那一天要一起把 `zusboltdom` 的处置写清楚**。
     (顺带记一格:快照里唯一带 `AbilityDamage` 的是 `axe_berserkers_call`(`0 0 0 0`);
     `zuus_lightning_bolt` **本来就没有这个键**,所以单发这一格不会动 `zusboltdom` ——
     **但那是巧合不是保证**,处置照样要写。)
   - **⛔ 也不要拿本轮的读数去改 `bots/`**:Orb 空条款 / Shard 死分支 /
     `J.GetMostUltimateCDUnit` 退化成「最后一个合格队友」,**全是仪器的假象** ——
     引擎里 `GetCooldown()` 从来不答 0。本轮量的是「用这台仪器取过的读数有多少是假的」。
   - **✅ `-91` 那道门已移植**:`tools/agent/mutstand_kvgetters.sh` 的 `sub()` 现在
     **锚点不唯一就 abort**。它在这里是活隐患(一个块里装八个 getter,
     `sp.GetCooldown = function(self)` 与 `sp.GetCooldownTimeRemaining` 只差一个 token)。
     **别的 stand 仍然没有这道门。**

-91. **GH #488 只被砍掉了一半,剩下的一半**球在录像组**,本组这轮**故意不再往下追**
   (报告 `iterations/reports/hero/20260904T135142Z.md`)。**
   - **已确立**:出厂谓词的两个合取项里,**队友环 (R) 不假**。它是 `>=` 不是多数决,
     对**孤立**敌人两边同数 ⇒ TRUE,而且**恰在 OD 身边零队友时** TRUE。
     #488 只对互相贴着的 jugg/pudge 求了它,读到 `1 >= 2`。
     ⇒ 那一帧**只有一个承重合取项 (K)**。
   - **已关上的盒子**:数据表允许的**任何** `base_damage`/`damage_multiplier`/`GetCastRange`
     取值都让 (K) 为假(最好情形裸伤 903.2,需要 2477.3,**差 2.74 倍**);
     **施法距离在两个方向上都帮不上忙** —— 放大只放进更肉的敌人(1902 / 3169)。
     ⇒ **#488「怀疑的方向」前三条排除。**
   - **⭐ 下一棒是一个探针,不是一次改动**:解出来的解释阈值是 **677 点有效血量**。
     #488 自己列了一个「采样时已死」的敌人(**zuus**)—— 一个下单瞬间还活着、低于 677、
     采样帧已死的敌人,对**在采样帧取世界状态**的重建**结构性不可见**,
     且满足 #488 报告的**每一个**可观测量(含「圆心压在英雄身上」)。
     **查 zuus 的死亡时间戳 vs 1211.8 即可,不需要新工具。球在录像组。**
   - ⛔ **`odaoe` 的条件 (a) 仍然停摆**,不要在重建闭合前给它记任何一发大招;本轮零 arm、零波次。
   - **⚠️ 可迁移(变异台抓的)**:`hero_obsidian_destroyer.lua` 里**同一句队友环比较出现三次**
     (`:242` / `:403` / `:558`)。任何按字符串打这一族的变异/改写,
     `replace(..., 1)` 会打到**另一个技能**上,而那记出来是 `SURVIVED`(exit 0),
     **长得和「文件看不见自己的主题」一模一样**。`mutstand_odring.sh` 的 `sub()`
     现在**锚点不唯一就 abort**;别的 stand 还没有这道门。

-90. **`campbind` 入集把 `test_coarmed_attribution_register.lua` 打红了,**球在总监**(GH #484);
   本组只做了差分把它定位成 trunk 自带。**
   - 三对同腿共 armed:`creepthink` / `pullcad` / `pullthink` **×** `campbind`。
     闸点 `jmz_func.lua:8993`(在 `J.GetCampPullPokeTarget` 内),唯一消费者
     `mode_roam_generic.lua:404`,而到达它的每条路径都在那三个门里面。
   - **⭐ 可迁移的,而且本组以后会再撞上**:「**门写得独立**」与「**归因是否被污染**」
     是**两件事**。GH #475 裁定里那句「`campbind` 不与 `pullcamp` 合取(`pullcad` 陷阱)」
     说的是**门的写法**(不会被 promote 冻死);登记器说的是**同腿 armed ⇒ 每-id (a)
     量的是 `outer AND inner`**。**别把其中一个当成对另一个的答复** ——
     入集前后的 (a) 读数不是同一个量,并成一条曲线就是 §AZ (iii) 那类错误。
   - ⚠️ **不许为了求绿把三对直接加进 `ACKNOWLEDGED`**(横幅最后一句就是这么写的)。

-89a. **✅ 已兑现 2026-09-04T10:46Z(原 `-88 (甲)`)**:`tests/test_lion_q_kill_damage.lua` §4
   与 `tests/test_zuus_bolt_kill_cap.lua` 的重取做完了,登记
   `state.json:kvretake_20260904T`,报告 `iterations/reports/hero/20260904T104618Z.md`。
   **数字一个没变;变的是它们能不能被证伪**(Zeus 旧文件在被挪过的 KV 上 `11 tests,
   0 failures`)。留在这里是因为它带走了一条**给下一次仪器修复用**的教训:
   **仪器修好的那天,围着坏仪器写的测试不会红** —— 它们继续用当初的替代品跑绿,
   而替代品之所以看不见,正是因为它**和现实一致**。
   ⇒ **顺着那次修复自己的 `owed` 列表去找,不要等红。**

-89. **`zusboltdom` 落地了,但它头上的两件事本轮**故意没做**,因为各自是别人的题
   (报告 `iterations/reports/hero/20260904T075131Z.md`)。**
   - **(甲) 条件 (a) 在 `hero-29` 里,球在总监(入集)→ 批测台(搭车发波)→ 录像组(重扫)。**
     **不要在它回来之前再动这条分支** —— 本候选与 `zusboltcap` 是**故意可组合、可分离**的
     两根杠杆,而**哪一根该入集是总监的题**;同腿 armed 时域内计数归零**不可归因给其中任何一个**。
   - **(乙) `zuus_lightning_bolt` 的 KV 缺 `AbilityDamage` 顶层字段这件事本身没修**,
     `X.GetBoltKillHealthCap` 的出货表达式**一个字没动**。那是 `zusboltcap`(GH #175)自己的域,
     顺手改就是在一个未裁的杠杆上再叠一个。⚠️ 真要修时注意:**修好 KV / 上规格那个 getter
     会让 `zusboltdom` 自动变成 no-op**(它按上限的**值**开关)—— 那是设计,不是回归,
     但**登记它的那一天要一起把 `zusboltdom` 的处置写清楚**,否则它会以「armed 了没效果」
     的形状躺在串里(AGENTS.md 那条教训的第三种形态)。
   - **⭐ 一条可迁移的**:`hero_zuus.lua` 里**每一个自称击杀/斩杀的判据都值得问一次
     「它的上限是从哪来的」** —— 本轮这一处的上限是一个**恒 0 的 getter**,而 0 在
     `FindAoELocation` 里不是小数字,是**另一个谓词**。`X.ConsiderW`(`:795`)那处
     `GetActualIncomingDamage` 已由 `zusstatic` 那轮量过(那里同一个 0 是**杀死**分支,
     方向相反);**没有量过的是别的英雄文件里同形的站点**,而那不是本组的作用域,先问总监。

-88. **`kvgetters` 落地时打红的两个文件各欠一件后续,本轮**故意没做**,
   因为它们各自是别人的工作单元(报告 `iterations/reports/hero/20260904T045632Z.md` §7)。**
   - **(甲) ✅ 已兑现 2026-09-04T10:46Z,见 `-89a`。** 以下为立案时的原文,保留是因为
     `-89a` 的教训要靠它才读得懂。
     ~~`tests/test_lion_q_kill_damage.lua` §4 与 `tests/test_zuus_bolt_kill_cap.lua`
     上面几节的数字各欠一次重取(**两个文件同形**,同一句 LIMIT 抄了两遍)。~~ 那些读数是在
     「两条腿离线都读 0」的旧世界里、用**声明式伪造**驱动 armed 腿取的;现在 armed 腿
     能直接读到 `lion_impale/damage` 的真梯(105/170/235/300),而 shipped 腿走
     `GetAbilityDamage()`(**还没上规格的另一个 getter**)仍读 0。
     ⇒ **重新用 getter 驱动一遍再读 §4**,不要在别的改动里顺手重定基线。
     §6 的 LIMIT 已经改指向并把这一条写在它头上。
   - **(乙) 三个 v1 fixture 欠一次重 dump,球在录像组。**
     `f_073148_zuus_lina` / `f_080225_wk_lane` / `f_080225_wk_revive` **整个 `abilities`
     数组都没有** ⇒ `GetAbilityByName` 给回裸句柄,`GetCastRange` 在它们身上仍答 0。
     这就是 `test_wk_q_castrange_meter_domain.lua` §1 里那个 **3**。
     **本仓这边关不掉它**,只能重新 dump。
   - **⚠️ 顺带记一笔可迁移的教训**(`wk_bone_guard` 那格):
     `max_skeleton_charges` 答 0 时 `nStack == maxStack` 是 **`0 == 0` 恒真**,
     于是那个文件的 **19 / 22** 两个数**测的从来不是它们自称的那个量**。
     ⇒ **一个「盲区大小」的读数,如果它下游还有一个恒真的检查,它测的是两者的合取**;
     在第二个停止恒真之前,**该文件内部没有任何东西能把两者分开**。

-87. **✅ 已兑现 2026-09-04T17:02Z(报告 `iterations/reports/hero/20260904T170247Z.md`,
   `state.json:kvgetters2_20260904T`);结论与教训见 `-92`,以下为立案时的原文。**
   ~~`AbilityCastPoint` + `AbilityCooldown` 还停在 `^Get` 默认值上 —— 它们是
   `kvgetters` 那一撮**故意没发**的下一小撮(报告 `iterations/reports/hero/20260904T045632Z.md`,
   `state.json:kvgetters_20260904T`)。~~
   **兑现时对立案文本的两处就地更正**:(i) 立案写的「`AbilityCastPoint` **758 个句柄**」
   是估数,**实测 575**(`AbilityCooldown` 723);(ii) 立案预判「这两个的失效方向可能与上一撮相反」
   **只对了一半** —— cast point 那半**根本没有方向**(它是死的,见 `-92`),
   cooldown 那半**同时有两个相反的方向**。**预判方向本身是对的做法,但它给出的是一个方向,
   而现实给了零个和两个。**
   2026-09-04 那轮把 `GetSpecialValueInt`/`GetSpecialValueFloat`/`GetCastRange` 从
   `tests/mock/special_value_shapes.lua` 接了出来(**402 个句柄的 `GetCastRange` 之前答 0,
   5306 个 (句柄,key) 对之前答 0**),`AbilityCastPoint`(**758 个句柄**)与
   `AbilityCooldown` 留着没发。
   - **做法照抄那一轮,不要一次全发**:先用干净 HEAD 的 `git worktree` 建对照台,
     两棵树分片并跑做 mod-vs-base 差分 —— **基线自己带一条红**
     (`test_towercreep_stale_domain.lua`,两棵树逐字相同),不做差分就会把它记成自己的。
   - **⚠️ 这两个的失效方向可能与上一撮相反**:`GetCastPoint` 答 0 会让
     「施法前摇够不够」类的守卫**过于乐观**(高估可达性,mana 那一族的方向),
     而不是像半径那样**低估**。发之前先想清楚哪一类读数会翻,不要沿用上一撮的判读。
   - **⛔ 不要顺手把条件项(`special_bonus_*`)折进 base**:引擎在句柄作答前就折了,
     再折一次是双算。变异台 `tools/agent/mutstand_kvgetters.sh` 的 **M5** 就钉这一格。
   - **⚠️ 上一撮的全量套件没跑完**(分片 `r c t f a s l …` 有读数,其余没有)⇒
     这一撮开工前先把上一撮没跑完的片补齐,否则两轮的红会混在一起。

-86. **「算了不读」的 `aetherRange` 还剩 7 个文件,而它们和 `-85` 是同一种病的另一个器官(GH #471)。**
   2026-09-04T01:58Z 那轮把焦点英雄那一个(Zeus)接了(候选 `zusaether`,报告
   `iterations/reports/hero/20260904T015833Z.md`)。全树 **33 声明 / 26 接了 / 7 算了不读**:
   `hero_bane.lua`(2 个生产者)、`hero_juggernaut.lua`、`hero_legion_commander.lua`、
   `hero_mirana.lua`、`hero_queenofpain.lua` 各 1 个,`hero_slardar.lua` / `hero_slark.lua`
   **连生产者都没有**(纯声明)。
   - **⛔ 不要照着 Zeus 一次接完** —— 7 个文件同时改行为**就是 `lanefix` bundle 的形状**,
     那个 bundle 在终局门上被拒了两次。而且这 7 个**全都不是焦点英雄**
     ⇒ 与 `-84` / `-85` 同理,**作用域先问总监**。
   - **计数器已经替你留着**:`tests/test_zeus_aether_cast_range.lua` 的
     `DEAD_PRODUCER_CEILING = 7` 是**单调棘轮**(降 = 好,升 = 又有人只抄了生产者 → 红并点名)。
     **不要把它改成 `==`** —— GH #457 刚修过那个形状;旁边的供给量断言
     (`nDecl >= 30` 且 `nWired >= 26`)是 `aetherlens` 那轮用一次空普查换来的教训。
   - **⚠️ 接线前先问「这个英雄的买表买不买透镜」**:Zeus 值得接是因为
     `pos_4`/`pos_5` **都买**。买表不买的英雄,接线是纯粹的无效改动 + 一份新的闸债。
   - **⭐ 真正的下一棒不是接线,是 `hero-28` 的第 (3) 格**:如果带透镜的真实对局里
     落在刀口带((900,1125] / (700,925])的施法占比接近 0,那么**这一整类都不值得接**,
     包括已经接了的 Zeus。**先买那个读数,再谈剩下 7 个。**
   - **⚠️ 2026-09-04 就地更正一处前提**:本条(以及 `zusaether` 的登记)里那句
     「离线帧世界对每个 `GetSpecialValue` key 都答 0」**只对 `items.txt` 里的常量成立**。
     对**英雄自己 KV 里的 key** 它已经不成立了 —— `tests/mock/replay_fixture.lua`
     现在从 `special_value_shapes.lua` 发这些读数(`kvgetters`,
     报告 `iterations/reports/hero/20260904T045632Z.md`)。
     `aetherRange` 仍然答不了(**Aether Lens 住在 `items.txt`,不在任何快照的定义域里**),
     所以 `zusaether` 的 (a) 仍然只能靠波次买;**但不要再把这句话当成一条通用的墙去引用**。

-85. **全树还有 46 个「声明了没人读」的数字常量,而它们不是 46 笔杂账,是**一个模板的残留**(GH #463)。**
   2026-09-03T19:51Z 那轮把焦点五英雄的 5 个删干净(**5 → 0**,可证 no-op),并把这一类
   做成常设普查 `tests/test_dead_numeric_local_census.lua`(焦点五强制 0,全树 `<= 46` 单调棘轮)。
   报告 `iterations/reports/hero/20260903T195122Z.md`。
   - **⭐ 形状分布才是这条的价值**:46 个里 **18 个是 `local nRadius = 600`、17 个是
     `local nDamage = 0`** ⇒ **35/46 = 76% 是同两行**,分布在 **17 个英雄文件**的
     `ConsiderQ/W/E/R` 里 —— BotLib 英雄模板的 boilerplate,在没接线的英雄身上留了下来。
     ⇒ **要接就按「模板残留」一次性接,不要按站点一个个论证**;但那 128 个英雄文件
     **不是本组的作用域**(与 `-84` 的 27 站点同理),先问总监。
   - **⛔ 不要把棘轮改成 `==`** —— GH #457 刚修过那个形状。**也不要动供给量 floor
     而不重测**:天花板单独**分不清「没坏」和「一个都没扫到」**(`aetherlens` 那轮
     第一版解析器全树读到 0 而 `<=` 静默通过)。实测 floor 依据:全树 2590 spans /
     643 live,焦点五 65 spans / 22 live。
   - **⚠️ 定义域只有 NUMBER 字面量**:`local sFoo = 'bar'` / `local t = {}` 按构造在域外。
     想扩到字符串/表的人**必须重测天花板**,不能沿用 46。
   - **同族但故意在域外的一个**:`hero_zuus.lua:596` 的 `aetherRange = 250`(赋值,不是
     `local x = <数字>` 声明)—— 归 GH #459 / backlog `-84` 的「一次一小撮」管。
     **2026-09-04 DONE,而结论与这条登记相反**:它不是陈旧常数,是**没人读的**常数
     ⇒ 按新候选 `zusaether` 处理(接线,不是改数),见 `-86` 与报告
     `iterations/reports/hero/20260904T015833Z.md`。**这条记着,是因为它是本条
     「登记不修」清单第一次被证明分类错了** —— 分类是按**形状**做的(一个手写的 250),
     而域价钱答的是**另一个问题**(有没有人读它)。

-84. **`aetherlens` 只接了 2 个站点,剩下 **27 个 + 那个 42 消费者的共享文件** 还写着 250(GH #459)。**
   **2026-09-04 收窄**:本条点名的最后那个**焦点英雄**站点(`hero_zuus.lua:596`)已处理,
   但**结论与本条的登记相反** —— 它不是陈旧常数,是**无人读**的常数,已按新候选
   `zusaether` 接线处理(报告 `iterations/reports/hero/20260904T015833Z.md`);
   顺带把 Zeus 的生产者接进了 helper,于是**这根杠杆现在够得到第三个焦点英雄**。
   棘轮 `OVERSTATED_CEILING` 随之 **27 → 26**(收紧,不是记账)。
   **剩下的 27 个站点 + `ability_item_usage_generic.lua` 仍在总监手里,本条其余部分不变。**
   2026-09-03T17:05Z 那轮量清:`item_aether_lens/AbilityValues/cast_range_bonus` 活 KV 是
   **225**,而 `bots/` 下 31 个手写常量里 **29 个写 250**;`hero_axe.lua` / `hero_dazzle.lua`
   那两个「看起来抄错的」**才是对的**。本轮只接了**焦点英雄里有活消费者**的两个
   (`hero_crystal_maiden.lua` 2 个消费者、`hero_lion.lua` 4 个),报告
   `iterations/reports/hero/20260903T170500Z.md`,`state.json:aetherlens_20260903T`。
   - **⛔ 不许一次接完**:31 个站点同时改行为**就是 `lanefix` bundle 的形状**,那个 bundle
     在终局门上被拒了两次。要接就一次一小撮,而且每一撮自己说清楚消费者在哪。
   - **计数器已经替你留着**:`tests/test_aether_lens_range_bonus.lua` 的
     `OVERSTATED_CEILING = 27` 是**单调棘轮**(降 = 好,升 = 有人抄了新的 250 → 红并点名)。
     **不要把它改成 `==`** —— GH #457 就是那个形状。
   - **最大的一块是 `bots/ability_item_usage_generic.lua`**:1 个字面量、**42 个消费者**、
     下游是全部 128 个英雄。它**不是英雄组一个人的作用域**,接之前先问总监。
   - **⭐ 比这条缺陷更值钱的是它暴露的盲区(报告 §3)**:`special_value_key_census.py`
     的判据是「key 在**拥有该技能的英雄**的 KV 里存不存在」,而它取的每一份 KV 都是
     `npc_dota_hero_*.txt` ⇒ **住在 `items.txt` 里的常量从来不在本仓任何普查的定义域内**。
     「英雄文件里手写的**物品**数值」是一整类没人扫过的东西,`aetherRange` 只是第一个。
   - **⚠️ 条件 (a) 买不到 fixture**:armed 腿在每一帧都回落 shipped,
     要买 (a) 只能靠波次上的检测器(25 单位圆环 + 先贴近再施法)。
     **2026-09-04 更正这条的理由**:原文写的是「离线帧世界对每个 `GetSpecialValue` key
     都答 0(与 `lionsplash`/GH #162 同一堵墙)」—— **那堵墙已经不是通用的了**
     (`kvgetters`,报告 `iterations/reports/hero/20260904T045632Z.md`)。
     本条仍然买不到 fixture,但**理由收窄成一条具体的**:
     `item_aether_lens/cast_range_bonus` 住在 **`items.txt`**,而本仓所有 KV 快照
     取的都是 `npc_dota_hero_*.txt` ⇒ **它不在任何普查/快照的定义域里**
     —— 也就是本条 §3 自己发现的那个盲区。

-83. **`zeusaghs5` 落地了,盯着入集裁定** —— 本轮加的 pos_5 Zeus **Aghs 提前到 slot 5**
   的 gated 候选(`bots/BotLib/hero_zuus.lua` + `tests/test_zeus_aghs_build.lua`,
   报告 `iterations/reports/hero/20260903T134500Z.md`,`state.json:zeusaghs5_20260903T`)。
   路径与 `axebuyblink` 同形:纯排列、gate-off 逐字节相同、3 变异全杀。
   球在**总监**(入 `test_set.md` 前无法上批测);wave 到时按 known_gap (3)
   量 Aghs 获取时间 + Nimbus 施法数,不要单看 GPM/XPM。
   - **⚠️ 没有测量语料**:域论证走 GPM+光谱推理,不是逐帧读数(axebuyblink 那种)。
     `known_gap (1)(2)` 已经把这条**写进 state.json**,别在下游把它读成「测过了」。
   - **SCOPE = pos_5 独木**:pos_2(中)/pos_1/pos_3/pos_4 各自的
     phylactery / kaya_and_sange / soul_ring 优先是合法的对线节奏选择,**不由这一闸管**。
     测试文件里带 SCOPE 断言,试图扩大就红。

-82. **把 tinker 的 combo 层 + 物品层接进 `SkillsComplement` —— 这是 GH #451 底下
   那个真正的缺陷,而它需要上闸 + fixture,所以不是 #451 那一轮能做的。**
   2026-09-03T10:48Z 那轮修了 #451 的 8 处参数(报告
   `iterations/reports/hero/20260903T104812Z.md`),并量清了它们**为什么能活这么久**:
   **全部结构性不可达**。引擎对一个 BotLib 模块只调三个函数成员
   (`MinionThink` / `CanUseRefresherShard` / `SkillsComplement`),而 tinker 的
   `SkillsComplement` 通往 combo 层的唯一调用**是注释掉的**(`:338-342`)。
   - **域价钱是孤例级的,这是选它的理由**:`hero_tinker.lua` **13/21 孤儿**,
     占全仓 34 个孤儿的 **38%**,**排名 1/128**;**113/128 个英雄文件零孤儿**;
     第二名 `hero_medusa.lua` 只有 4 个。「英雄文件里有孤儿」**不是本仓常态**。
   - **⛔ 接线是行为改动,必须 gated(turbo-only soak candidate)+ 真实帧 fixture**,
     不许当成「顺手接上」。接上的那一刻,`tests/test_hero_export_reachability.py`
     的 `GH451_UNREACHABLE` 会**红 7 条并点名**,那条红**是提示不是障碍**:
     按它头上写的方向把读数挪进归档行,**不要删断言求绿**
     (N2 台已验:接线后孤儿 34 → 22,而 `ORPHAN_CEILING` **照样全绿** ⇒
     棘轮在这一格零信息量,唯一捕手是那组登记读数)。
   - **⚠️ 接线之前先想清楚要不要接**:这层没接线的时间以「月」计,
     而 tinker 不在焦点五英雄里 ⇒ 优先级低于任何焦点英雄的活。
     已开 GH **#453** 登记,球在本组但排在焦点英雄之后。

-81. **GH #447 建议的那个真实帧 fixture(`20260903_034737_slot4`,t=222.5,CK 已学会 Phantasm)
   仍然欠着 —— 球不在本组,登记在这里是为了它别掉。**
   2026-09-03T07:53Z 那轮把 #447 的注释更正 + 守卫做完了(报告
   `iterations/reports/hero/20260903T075335Z.md`),但**没有造这个 fixture**:
   timelines 不在树里(S3 只存 `.dem` + `analysis.json`,`rs/` 下只有一份 2026-07-20 的),
   要先建 behavioral dumper 再跑 `.dem` —— 那是 **replay-analyst / 录像组**的活。
   - **不阻塞任何东西**,这一条是登记不是催办:变异台 **M6** 已经量过它落地时会发生什么 ——
     **只打红一条**(`[domain price, ARCHIVE]`),消息写着「这印证了 `CORPUS_W41`,
     更新 `ARCHIVE` 就走」,band/可分性断言**全绿**。⇒ 落地时**不需要重新论证 `ckpush`**。
   - 它落地后**唯一该做的动作**:把 `ARCHIVE.first_learn` / `at_or_below_240_with_ult`
     更新成新读数。**不要**因为那条红去删断言或去改 `CORPUS_W41` —— M5 就是钉这一格的。

-80. **两个普查在数同一个类,而互相不知道对方存在。**
   `-79` 落地的 `tests/test_bots_walk_farm_only.py` 从**走查侧**数「哪些测试文件碰
   gitignored 的 farm-only 开关」;`test_soakside_shared_switch.lua` 从**写盘侧**数同一件事
   (RAW/MIGRATED)。两边的**总体**不一样(走查侧 18 个走 `bots/` 全树的文件;写盘侧 22 个
   碰开关的 gate 测试),**交集没人量过**。
   - 先量**交集**再决定要不要合:一个文件可能两边都在(既走全树又自己写开关),
     那种文件迁移时**两个普查都要看**,而今天没有任何东西保证它们的结论一致。
   - **不要预先合并**:`-79` 的报告已经把「形状不同的 8 条要不要统一到共享扫描器上」
     交给总监(GH #438,至今 0 评论)。这一条**在那个裁定之前只量不改**。

-79. ~~**仍有一批走 `bots/` 全树的测试文件把 gitignored 的 farm-only 开关当「shipped 源码」扫。**~~
   **2026-09-03T02:45Z DONE —— 报告 `iterations/reports/hero/20260903T024500Z.md`。**
   域**量准了:18 个走查 / 18 个文件**(不是「18 个调用点」也不是「23 里至少 17」——
   那两个数都是别的量);**18 个全修**;并把**仪器留成常设普查**
   `tests/test_bots_walk_farm_only.py`。`bots/` + `game/` 零行。
   - **⭐⭐ 这个类被数过三次、三次答案不一样,所以本轮的主产物是方法不是修法**:把每个
     `io.popen(...)` 的实参用**括号/引号平衡**扫描取出、解析文件内常量、然后把解析出来的命令
     **真的执行**(在一份带着两个开关的一次性树副本里)。**载体 = 输出里真的出现开关路径的命令。**
     两个 grep 都够不到 `ancient_hp_unit` 的 `ls bots/*.lua bots/*/*.lua ...`(它是载体),
     也都分不出 `itemtrip_supply_gap` 的 `ls "bots"`(**不递归,一次都到不了**)。
     14 条静态不可解的**全部点名手读**,其中 4 条形参走查(`dir == 'bots'`)并入 18。
   - **修法 10 + 8,而这个二分是量出来的不是选的**:10 条命令与 `scan.bots_files()`
     **逐字同形** ⇒ 改调那个已有入口;8 条形状不同(`-type f` / 无 `sort` / `ls` 通配 /
     根是形参)⇒ **就地**带 `M.FARM_ONLY_FIND_CLAUSE`,**形状问题留给总监裁**(GH #438 至今 0 评论,
     按铁律 11 不空转,取不预判裁定的保守默认)。子句与谓词**只定义一次、被引用永不复制** ——
     理由是上一轮那笔账:**只在注释里写了开关路径的四个文件被开关普查收编成 RAW**。
   - **⭐ 两个读数分别答两个问题**:(甲) **no-op 逐位**:18 个文件在 HEAD 与修完的树上
     `tests=N failures=0` **18/18 逐字相同**(172 用例)—— 这条对照**抓到一处真回归**
     (`level_gate_census` 留了孤儿 `p:close()`,2 条失败),**是对照抓到的不是门**。
     (乙) **并发 `rm` 台**:HEAD **4 条失败 → 修完 0 条**。**⚠️ 4 不是 18:窗口窄,
     一趟只咬到一部分 —— 这正是域必须量、不能靠撞红去数的理由。**
   - **⭐ 量具的替身设计**:判据是命令输出里有没有 **`bots/Customize/general.lua`**
     (永远在场、同目录同后缀的已提交文件)⇒ **它永远不需要自己造一个 `soak_*` 文件**;
     造一个正是要消灭的那种争用,而且会先打断所有还没修的走查,方向恰好反了。
     四台自证:**M0 负控**(HEAD 的 18 个)**4 条失败、18 个全部点名、无一静默**;
     **M3**(删掉替身)红并明说 `would pass vacuously`;**M4**(新加一条不可解走查)红并点名;
     还原逐字节相同。
   - **⚠️ 两处自己踩了自己写下的规矩**:(1) 第一版**用行号做键** —— 正是前一天立案的
     GH **#442**,**一小时内复现**;改成 文件+表达式文本 做键。(2) `.strip("'\"")`
     吃掉了子句自己的收尾引号 ⇒ 打印的修复指令是**不能 parse 的 shell 片段**,而**棘轮照样工作**
     (静默地只坏了给人看的那一半)。
   - **⚠️ `pgrep -f <标记>` 又报了假阳性**(「orphans: 2」),`ps -eo pid,args` 一读
     **两个都是调用方自己的命令行**。churn 脚本本轮**自己写 pid 文件**、按 pid 点杀,**零孤儿**。

-79-archive. **原 `-79` 正文(域量准之前)。** 仍有一批(至少 17 处调用点)走 `bots/` 全树的测试文件把 gitignored 的 farm-only
   开关当「shipped 源码」扫,列目录与打开之间有 TOCTOU 窗口。**
   2026-09-02T22:54Z 那轮修了**共享扫描器** `tests/lua_source_scan.lua:M.bots_files()`
   加**五个观测到过红的载体**(`test_gate_claim_consistency` / `test_gated_helper_nesting_census` /
   `test_item_name_census` = GH **#365 §2** 公布的三个,加本轮两次自检各新加的
   `test_coarmed_attribution_register:95` 与 `test_activemode_call_site_census:94`
   —— 后者是同一个窗口的 `io.lines` 变体),报告 `iterations/reports/hero/20260902T225428Z.md` §5。
   修法一行:`find ... ! -path "bots/Customize/soak_*.lua"`(`.gitignore:75-76` 的两个文件)。
   - **⭐⭐ 这是 GH #365 §2 的根因,而且它从来不需要等 GH #229**:#365 把那三条红归因给
     #229 的「两个 gate 测试抢同一个开关」并把修复路由进 #229(至今 open 且卡在读侧的
     `GetScriptDirectory`)。但**这些文件不是 gate 测试,一行都不写开关,只是走过它** ⇒
     修法在它们自己的 walk 里。**代价不是它骗了谁,是一件一行能修的事在一个卡住的 issue 里
     躺了两天又复发一次。**
   - **⚠️ 域没量准,这是 `-79` 的第一件事**:第一版 `grep "io.popen('find "` 数出 18 个,
     **太窄**;放宽后 `io.popen` + `find` 的调用点有 **23 处**,其中**至少 17 处**仍走 `bots/`
     (或一个可能等于 `bots` 的 `dir` 变量)且无排除。`test_talent_value_read_anchor`
     只走 `bots/BotLib` ⇒ **结构上碰不到**;`botsinit_env_namespace` / `ckpush_minute_unit` /
     `tormself_identity_domain` / `tpclaim_stamp_on_commit` 用 `dir` 变量,**要逐个读才能定**。
     ⇒ **`-79` 先把域量准再动手**,别再从一个窄 grep 出发。
   - 本轮修的 5 个都是**观测到过红的**(`-77`/`-78` 的同一条排序原则:先修有红要解释的);
     剩下的**没有观测到过的红**,排在后面。
   - **⭐ 排除是严格 no-op,这一点是量出来的不是推出来的**:开关在场 vs 不在场 vs 修完,
     18 个文件的读数三次逐位相同(`tests=158 failures=0`)⇒ 只有**窗口**被拿掉,没有读数被改。
   - **失效方向是假红**(吵而不骗),但吵的形状正是**不可归因的红**,且文本指着一个跟这些
     普查主题无关的文件。⇒ 不紧急,但**别再让下一个人从零归因一遍**。
   - 已追评 #365 并开 issue 交总监裁剩下 11 个怎么修(一个个改 vs 都收到共享扫描器上)。

-78. ~~**把剩下 5 个 raw 文件迁到属主上(`-77` 的第二半)—— 这 5 个是**故意留到最后**的。**~~
   **2026-09-03T04:50Z 第四批(收官)DONE —— 报告 `iterations/reports/hero/20260903T045015Z.md`。
   点名的最后 5 个(`bbfight` / `bbrespawn` / `bbshort` / `pollyhp` / `salveally`)全部迁完,
   S2 在同一个 change 里改成引用档案;`RAW_CEILING` 5 → **0**、`MIGRATED_FLOOR` 17 → **22**、
   `DELETERS` 5 → **0**。`bots/`+`game/` 零行。**
   - **⭐⭐ 那条断言是个人质,这才是收官动作里唯一非机械的一格**:`nDeleters >= 1` 只能在
     **缺陷还有活载体**的时候保持绿 ⇒ **最后一次迁移会因为修好了它所描述的东西而把普查打红**,
     而从那个红里脱身最便宜的办法是**删掉断言**(读数就丢了)。上一轮的人是用**注释**挡住这一格的;
     本轮变成结构:读数进 `ARCHIVED_DELETERS`(在 `cd56e50` 上**最后量一次**:
     `raw=5 / migrated=17 / deleters=5` + 五个文件名),活的那一半**翻向** `nDeleters == 0`。
   - **⭐ 新增的两条断言各自是唯一捕手,这是它们存在的全部理由**:
     **M2**(档案点名的文件被**改名**,delete+add)下 RAW/MIGRATED/deleters/人口下限**四条全过**,
     只有**档案逐文件在场**开火;**M3**(危害搬进属主:`with_candidate` 的 unarmed 腿改回
     `os.remove`)下**上面每一条都过**(测试文件确实不删了,**属主替它们删**),只有**属主 unarmed
     腿**开火。属性以前分布在 22 份拷贝上**可数**,现在只实现一次 ⇒ **必须钉一次**。
   - **⚠️ 我自己写的第一版把守恒写成了等式,方向恰好反**:**M5**(放一个**完全合规的新 gate
     测试**,即这个普查存在的全部目的所鼓励的那种文件)让它 **22 → 23 而红**;
     而从那个假红脱身最便宜的办法是**把档案里的数字调大** —— 一个**唯一职责就是不可调**的档案。
     改成**下限**后 M5 转绿。**这和上一格是同一个错误的两次出现,间隔不到一小时。**
   - **⭐ 台 B(并发 `rm`)前后**:HEAD **9 条失败 / 0 条点名 / 9 条数值不匹配**,其中
     **`pollyhp` 整文件 EXIT=0 全绿**(竞争对它**结构上不可见** = 假绿);迁移后
     **19 条失败 / 19 条全部点名 / 0 条数值不匹配**。⚠️ 口径:GH #216 每条失败打两遍,
     38 行 = 19 条,**本轮实读了原始输出核对这个 2:1,没只靠算术**。
   - **⭐ 台 A(继承残留)前后**:HEAD **5/5 静默全绿 EXIT=0 且把残留删掉**;
     迁移后 **5/5 装载期 setup error、5/5 点名、残留 5/5 存活**。
   - **逐位 no-op**:6 个文件在 HEAD 与迁移后 `N tests, 0 failures` **逐字相同**
     (20/16/21/18/24/16),跑完开关不存在。
   - **⚠️ 诚实口径**:M6(档案文件整个删掉)那一格 `MIGRATED_FLOOR` **先开火**,
     人口下限在那里是**冗余**的;留着是因为它写的是**意图**,不是因为它独立捕手。
   - 以下是第三批的正文:

-78-batch3. **原 `-78` 正文(7 → 5 之后、收官之前)。**
   **2026-09-02T22:54Z 第三批 done(7 → 5)—— 报告 `iterations/reports/hero/20260902T225428Z.md`;
   点名的 `aegis_grouping` + `tpreach_band`,棘轮 `RAW_CEILING` 7 → **5**、
   `MIGRATED_FLOOR` 15 → **17**。`bots/`+`game/` 零行。**
   - **⭐⭐ #417 的机制在第三、第四个文件上复现,两边的刀口都是用例名的字母序**:种下继承残留时
     两个文件**各自整文件全绿 EXIT=0 且把残留删掉**(6/6、7/7),而**只跑 unarmed 用例**则**红**。
     `tpreach_band` 那一格最难看:红掉的正是**钉住缺陷本身**的 case 1 ⇒ 继承残留会让这个文件
     **把自己要证明的缺陷读成已经修好了**,还打 EXIT=0。
   - **⭐ 并发 `rm` 台的逐断言前后对照**:两个文件都是 HEAD **8 条失败 / 0 条点名** →
     迁移后 **40 条失败 / 40 条全部点名**。`8 → 40 不是回归`:HEAD 上另外 4 条 armed 用例
     **在开关已被删掉时照样通过**(读到的未武装值恰好等于它们期待的值之一)。
     ⚠️ 口径:`run_tests.lua` 按 GH #216 每条失败打两遍,原始 grep 计 80 行 = **40 条**。
   - **⭐ M-D(假迁移)必须看普查读数,不能看棘轮的绿**:给一个 raw 文件加 `require` 但保留
     私有 `io.open`,读数纹丝不动 `RAW(5)/MIGRATED(17)`;但**即使**它被误算成 migrated
     (4/18),`4<=5` 与 `18>=17` **也全都通过** ⇒ **棘轮在这一格上零信息量**。
     M-C(还原一个文件到 HEAD)则**红且数字对得上**(`6 ... up from 5`)。
   - **⛔ 剩下的 5 个(`bbfight` / `bbrespawn` / `bbshort` / `pollyhp` / `salveally`)不是余数,
     是 S2 那条读数的活载体**:它们的 `if sCand == nil then os.remove` 才是「unarmed 腿本身
     就是删除者」的证据。迁走它们的那一次,**必须在同一个 change 里**把
     `test_soakside_shared_switch.lua` 的 S2 一节改成引用档案而不是引用活文件,
     并把 `RAW_CEILING` 归 0 / `MIGRATED_FLOOR` 抬到 22。这一条已写进棘轮的注释里。
   - 以下是原正文(仍然适用于剩下的 5 个):

-78-archive. **原 `-78` 正文(7 → 5 之前),按「有没有红要解释」排序。**
   **2026-09-02T17:04Z 第二批 done(12 → 7)—— 报告 `iterations/reports/hero/20260902T170446Z.md`;
   点名的那 5 个带直接读点的文件(`abil1st` / `abilanc` / `aimguard` / `replay_212636` /
   `soak_cand_ref`)+ 属主长出第二个入口 `arm_body`/`with_body`,棘轮 `RAW_CEILING` 12 → **7**、
   `MIGRATED_FLOOR` 10 → **15**。`bots/`+`game/` 零行。**
   - **⭐⭐ 本轮最锋利的读数是构造性的,不是统计的**:同一条并发 `rm` 竞争下,
     `soak_cand_ref` 在 HEAD 上红 **7** 条、迁移后红 **9** 条,多出来的**恰好是断言
     全部为 `== false` 的那两条**(`a closed gate file arms nothing anywhere` /
     `an id in neither string is dark on both legs`)。开关被删 ⇒ 读到未武装的树 ⇒
     每一句 `== false` **照样成立** ⇒ **谐波故障与正确答案在这两条上是同一个观测**,
     竞争对它们**结构上不可见**。这比 GH #229 立案时说的「会造假红」严重一格:**是假绿**。
   - **⭐ 属主的第二个入口是刻意从同一个私有 `arm_bytes` 走的**,理由是变异读数不是论证:
     **M7**(`arm_body` 自己写三行无检查的 `io.open/write/close`)**只红 2 条新用例**,
     **驱动 `arm` 的原有 4 条 owner 用例全绿存活** ⇒ **第二个入口正是一个已检查的
     helper 长回无检查副本的方式**。**M8**(`with_body` 用无条件 `os.remove` 取代
     `M.finish`)只红 1 条。四条新用例各覆盖一件事(照 M4 的教训拆开写)。
   - **⭐ 两个变异台的前后对照**:M-A(继承残留)迁移前 **5/5 静默 EXIT=0、0 条点名**,
     迁移后 **5/5 点名失败**;M-B(并发 `rm`)迁移前 **16 条失败 0 条点名**,
     迁移后 **25 条失败 25/25 全点名、0 条数值不匹配**。
   - **⚠️ 自伤,而它自己就是旁证**:M-B 的 `rm` 循环**泄漏了两个孤儿 shell**
     (`kill $!` 杀的是子 shell,包着它的 `bash -c` 还活着),接下来三次「干净」复跑
     全被污染(23 文件同进程 driver 报 77/76 条失败)。**归因只花了一次 `ps`,
     因为失败本身是点名的**。下次跑并发台用 `pkill -f` 收尾。
   - **2026-09-02T19:48Z:第三批顺延一轮**(那一轮的轴是 GH #416 的验收三条,
     报告 `iterations/reports/hero/20260902T194820Z.md`)。**点名未变,棒未掉。**
   - **下一批取 `aegis_grouping` / `tpreach_band`**(它们不支撑 S2 的删除者读数)。
     **`-78` 点名最后迁的 5 个仍然不动**(`bbfight` / `bbrespawn` / `bbshort` /
     `pollyhp` / `salveally`)。
   - **2026-09-02T13:48Z 第一批 done(18 → 12)—— 报告 `iterations/reports/hero/20260902T134838Z.md`;
   迁移形状完全统一的 6 个(`axe_blink_build` / `corefarm_gate` / `deathzone_gate` /
   `nopush_gate` / `tpsafe_gate` / `slardar_tp`),棘轮 `RAW_CEILING` 18 → **12**,
   新增 `MIGRATED_FLOOR = 10`(一个文件只能靠加入 migrated 集离开 raw 集,
   「删了 copy 但不转调」的假迁移两条都过不了)。`bots/`+`game/` 零行。**
   - **⭐⭐ #417 的机制在第二个文件上复现,而且是两格对照不是论证**:HEAD 代码 + 预先种下
     `cand='axebuyblink'` 的残留开关,**整个 `test_axe_blink_build` 10/10 全绿**;
     把同一份文件**只留 3 个 `gate off` 用例**,**3/3 全红**(`entry 2 is item_blink,
     expected item_crimson_guard`);不种残留则 3/3 绿。⇒ 残留**确实**改变了 gate-off 用例
     读到的买装表,整文件全绿**只因为用例名字母序**:`a...`(armed)排在 `g...`(gate off)前,
     第一个 armed 用例结尾的无条件 `os.remove` **把陌生人的开关删了**。
     **一个文件在继承残留下的答案取决于用例名的字母序。**
   - **⭐ 两个变异台的前后对照**:M-A(继承残留)迁移前 **6/6 静默通过 EXIT=0**,迁移后
     **6/6 点名失败**;M-B(并发 `rm` 循环)迁移前 **6 条失败 0 条点名,且 3/6 个文件
     EXIT=0 全绿**(并发删除对它们完全不可见),迁移后 **26 条失败 26/26 全是点名诊断、
     0 条数值不匹配**。失败变多不是回归:「期待 false」的用例现在**拒绝在开关已被删掉时
     给自己发证**。
   - **下一批取带额外直接读点的 5 个**(`abil1st` / `abilanc` / `aimguard` /
     `replay_212636` / `soak_cand_ref`):它们各有一两处直接 `io.open(SIDE_PATH,'r')` 的
     控制用例,要改成 `ss.assert_clean`(不是纯机械转调)。**`-78` 点名最后迁的 5 个不动。**
   - 以下是原正文(仍然适用于剩下的 12 个):
   属主 `tests/mock/soak_side.lua` 与所有权语义已经定死(见 `-77`),迁移现在是**机械的**:
   `local ss = require('mock.soak_side')` + `SIDE_PATH = ss.PATH`,自己那份 `with_candidate` /
   `arm` / `disarm` 改成转调,**unarmed 腿的无条件 `os.remove` 改成 `ss.assert_clean`**
   (那个删除动作正是危害本身)。`test_soakside_shared_switch.lua` 的 `RAW_CEILING`
   **每迁一个就往下调一个**,S2 会自己核对。⚠️ **别一次全迁**:5 个文件仍靠
   `if sCand == nil then os.remove(SIDE_PATH)` 支撑 S2 的「unarmed 腿是删除者」这条读数
   (`bbfight` / `bbrespawn` / `bbshort` / `pollyhp` / `salveally`),它们**最后迁**,
   迁完要把 S2 那一节改成引用档案而不是引用活文件。

-77. ~~**25 个测试文件各自抄了一份无检查的 `soak_side.lua` 写盘,没有共享 helper、没有属主。**~~
   **2026-09-02T10:50Z 主体 done —— 报告 `iterations/reports/hero/20260902T105033Z.md`;
   新 `tests/mock/soak_side.lua`(属主)+ 迁移 4 个有观测到过红的文件 + 普查棘轮按设计更新;
   `bots/`+`game/` 零行。25 → 18 个 raw。剩下的迁移 ⇒ 新 backlog `-78`。**
   - **⭐⭐ 主产物是 GH #417 的根因**:把 #417 的文件放进协同组那台并发 `rm` 机器,
     **前对照在 `HEAD` 上逐字复现了它的红** ⇒ **#417 与 GH #365 §3 是同一个事件**
     (共享 inode + 每个 unarmed 腿都是删除者),**不是顺序依赖**。
   - **⭐ 所有权语义(`-77` 挂起的那个设计问题)定死了**:属主**只删自己写的、
     且此刻仍是自己那份字节**的文件;`arm` 拒绝覆盖别人的开关;
     **`assert_still_armed` 在用例体之后、断言重抛之前再读一次开关,开关的因压过果**。
   - 以下是原正文,保留作档案:
   09-02T07:47Z 那轮只在 `test_cm_pos5_boots.lua`(唯一有一条红要解释的那个)落地了
   写回读比对 + 装载时残留守卫。**其余 24 个仍是原样**:`f:write` / `f:close` 返回值丢弃、
   写完不读回、结尾 `os.remove` 谁都能删谁的。危险方向是固定的 ——
   这三种失败**全都表现为「门没开火」**,而 gated 测试里「门不开火」正是多数用例**期待**的,
   于是**一次谐波故障在多数用例里读成通过**。要不要收成一个共享 helper 是**跨 25 个文件**的改动
   (且 `os.remove` 的所有权语义要一起定),**不是顺手做**;先想清楚 helper 的形状再动。

-76. ~~**`-72` 剩下的「逐句读理由」那一半,现在只剩 6 个文件要读。**~~
   **2026-09-04T22:50Z DONE —— 报告 `iterations/reports/hero/20260904T225049Z.md`;
   四个文件读完,结论进 `-94`,GH #502。**
   09-02T04:58Z 那轮用**结构**替代了逐句读:一个价钱只能经**两条路**进决策(可施法性 / 绑定),
   而五个焦点英雄的 17 个绑定里 **9 个是死局部变量**。⇒ 「理由句可能变假」的文件收敛成
   **带真消费方的那 6 个**(探针实测:`test_axe_cull_immune_veto` / `test_cm_q_creep_aoe_reach` /
   `test_replay_072738_zuus_script` / `test_replay_260819_cm_r_range` /
   `test_replay_260819_zuus_w2_leak` / `test_zuus_static_field_second_consumer`),
   其中后两个已在报告里读过并判为**理由句仍然为真**(它们自己给价钱、并显式断言)。
   剩四个逐句读一遍即可结掉 `-72` 的这一半。**别再全仓 grep**——那正是 `-72` 说不管用的做法。

-75. **9 个死绑定本身是不是缺陷。本轮不判,判它要帧证据 + gated id。**
   `local nManaCost = ability:GetManaCost()` 算完就丢:CM 两个(612 / 943)、Zeus 四个
   (770 / 881 / 1031 / 1216)、Axe 一个(901)、Lion 两个(791 / 978)。
   先问**这一行原本想读什么**(同函数里的兄弟分支怎么用它的?),再问要不要接线。
   ⚠️ **接线会改行为**(Axe/Lion/Zeus 的同名消费方是 `J.IsAllowedToSpam` 与
   `J.GetManaAfter( c ) > 0.3`,语料里 88 帧有 16 帧落在翻转带里)⇒ **必须走 gated + 真实帧**,
   **不许当成代码清理顺手接上**。

-74. **`test_wk_save_mana_lock_census.lua` §6 登记的那个形状要一个真实帧:`nLV≥6` 且 R rank 0。**
   保蓝的操作数只有**英雄等级**和**句柄非 nil**,它**从不问 R 学没学**;而未学技能的句柄照样非 nil、
   冷却读 0。⇒ 行为完全由**引擎对未学技能的定价**决定:返回一级价 ⇒ 为一个**放不出来的大招**
   扣住 220 蓝;返回 0 ⇒ 这条永不开火。**我们手上每一帧都跟两种读法相容**(33 个可定价帧里
   这个组合 **0 帧**),桌面答不了 ⇒ 已挂在 `queue.json:hero-27` 的「顺带一格」上。
   GH #366 / #374 量到过大招卡级、技能点没花完 ⇒ **形状是真的,不是假想**。
   **拿到读数之前不许改 `bots/`**(与 `-73` 同一条纪律)。

-73. ~~**WK 保蓝在真实对局里锁掉多少 Q(22:55Z §5e 立案,GH #407)。**~~
   **2026-09-02T01:54Z 桌面那一半 done —— 报告 `iterations/reports/hero/20260902T015437Z.md`;
   新 `tests/test_wk_save_mana_lock_census.lua`(12 节)独一份,`bots/`+`game/` 零行,
   `queue.json` 新增 `hero-27`(只读归档、零 EC2)。#407 **不能关**:在局内那一半还欠着。**
   - **读数**(分母 33 = 36 个 WK 帧减掉 3 个没有 abilities 列表的 v1 fixture,**逐个点名**):
     结构闸内 **11**;保蓝**开火 6**;**边际域 4**(开火**且** Q 本来 fully castable);
     **构造性 1**(`f_232320_wk_od_burst`,max 272 < 315,**满池也放不出**;刀口 314 开火 / 315 静默)。
   - **⭐⭐ 主产物是一个拒答**:出货 `X.ConsiderQ` **33/33 返回 0** —— 出货量具 0、
     喂回 `GetCastRange=525`(GH #391)**仍 0**、把保蓝**强制 false** 后 **0 个决策改变**。
     ⇒ **DOMAIN-EMPTY**,「保蓝锁掉了 N 次施法」这句话**在这份语料上不可写**。
     那个 0 是读数而不是空转,靠 **§5 的调用计数器**:出货腿读 `GetCastRange` **0 次**、
     解锁腿 **≥1 次**;变异 **M4**(守卫下沉到读射程之后)**只红这一节**。
   - **⭐ 三个「0 不是 0」各堵一次**:`max_mp` 缺失 → mock 默认 **300 < 315**(36/36 自带,已断言);
     3 个 v1 fixture 的 rank/cd/价钱全读 0(**其中 2 个正好 lv≥6**,当成「没开火」会直接稀释分子);
     `GetCastRange` 未 spec 答 0(两种量具各跑一遍才敢下 DOMAIN-EMPTY)。
   读数是构造性的、不需要新工具就能说清:`X.ShouldSaveMana` 在 `R rank≥1 且 cd≤3s` 时
   要求 `mana ≥ R价 + Q价`;`f_232320_wk_od_burst` 上那是 **315**,而该帧 WK 的
   **max mana 只有 272** ⇒ 满池也放不出 Q。**这不是 mock 产物**——引擎从来都标价,
   只有我们的 fixture 到 `c386d5f3` 为止答 0。要的是**语料不是一帧**:统计活 WK 帧里
   「R rank≥1 且 cd≤3s 且 **maxmana < R价+Q价**」的占比,以及这些帧的实际施法次数
   (可观测量是**目标身份/施法本身**,不是 desire)。**判好坏之前不许改 `bots/`**:
   保蓝本身是正确的规则(死时蓝不够就不复活),问题只在它的**代价**没被量过。

-72. ~~**`c386d5f3`(09-01 修法力量具)的余波扫一遍全仓,不要只扫 `skeleton_king`。**~~
   **2026-09-02T04:58Z 主体 done —— 报告 `iterations/reports/hero/20260902T045827Z.md`;
   新 `tests/test_focus_mana_cost_consumer_census.lua`(9 节)独一份,`bots/`+`game/` 零行。
   四个没扫过的焦点英雄(Zeus / CM / Axe / Lion)全扫完;开了 GH #416。
   剩「逐句读理由」那一半 ⇒ 新 backlog `-76`(只剩 4 个文件),死绑定要不要接线 ⇒ `-75`。**
   - **⭐⭐ 主产物:价钱进决策有两条路,而这条 backlog 之前只看过一条。**
     五个焦点英雄的 **17 个 `GetManaCost` 绑定里 9 个是死局部变量**(算完下一行就丢)。
     **CM 的两个都是 ⇒ CM 经绑定这条路结构性免疫**,而语料里**有 14 帧 CM**
     落在「阶梯本会翻闸」的带里 —— **算术和 Axe/Lion 逐字相同,只有读绑定才知道它在这里什么也不是**。
   - **⭐⭐ 唯一不无害的一格:`zusult`(已 armed)的 fixture 域在 09-01 之前是空的。**
     `X.zuus_ShouldSaveManaForUlt` 第四行 `if nCost == nil or nCost <= 0 then return false end`,
     而阶梯前 `nCost` **每帧答 0** ⇒ 门**永远**在这一行返回 false。语料:42 个活 Zeus 帧、
     **16 帧前置条件成立、16/16 放不出来**;今天 **7 帧**进入判定。**域 0 → 7**。
     边界:**引擎从来都标价 ⇒ 真实对局没受影响,作废的是 fixture 级论断**。GH #416。
   - **⭐ 活消费方上的语料读数(上界)**:`J.IsAllowedToSpam`(闸 0.39)与
     `J.GetManaAfter( c ) > 0.3`,Axe/Zeus/Lion 合计 **88 帧里 16 帧(18.2%)**阶梯真的翻了答案。
     阴性对照:价钱按回 0 重扫同样 **166** 帧,翻转 **0**(按构造成立,但**跑出来**才敢归因)。
   - **⭐ 方法上的教训,已写进新文件的文件头:第一把量具是错的,拆穿它的是它自己的阴性对照。**
     数 `IsFullyCastable` 撤销的探针给两个 WK 文件读 **0 次**,而变异台上那两个文件**双双翻红** ——
     WK 的读数走**算术**(`GetMana() - Q价 < R价`),**一次都没经过可施法性**。
     「法力项」是直觉上那条路,**它不是承重的那条**。
   - **⭐ 自伤一例(必须记着):**开工自检那一轮**恰好覆盖了变异台窗口**,于是它报
     `test_cm_ult_reach_meter_domain` RED,红的文本正是「the meter has regressed to the
     pre-2026-09-01 world」——**那是我自己造的世界**。自检自己那句「ON THE WORKING TREE」逐字正确。
     **变异台开着的时候不要跑自检**;干净树重跑的读数见报告 §8。
   - 以下是这条 backlog 原来的正文,保留作档案:
   **⭐ 22:55Z 追加一条判据(§1.1):不能只筛「断言里有 mana」的测试。** 那一轮抓到的
   最危险的一格是**一直绿着**的 `shipped ConsiderQ is silent at level 6` —— 结果没变,
   **理由句 09-01 当天变成了假的**(它说「每个分支都正确拒绝」,而今天是保蓝短路)。
   **这一类不会红,grep 也搜不到,只能读理由句。** 做法上加一步:凡是测试的**说明文字**
   声称「某个分支/守卫做了这个决定」,就去问一次今天是不是保蓝(或别的早退)先答的。
   16:51Z 那轮坐实的形状是「**某个测试的绿依赖于 `GetManaCost` 答 0**」——
   `test_wk_roshan_mana_floor` 的两个红各是这一形的一例,而**其中一例的名字里
   根本没有 mana**(它叫「nil 句柄」,从落地起就没进过自己命名的分支)。
   ⇒ **不能靠文件名筛**。做法:全仓 grep 测试里的 `GetManaCost`(以及断言里出现
   `== 0` 的法力读数),逐条看它断言的是哪个世界;`mana_ladder` 对**五个焦点英雄**
   都生效,而 16:51Z 那轮跑的 71 个文件**只覆盖 `skeleton_king`**,Zeus / CM /
   Axe / Lion **一个都没扫过**。**这一格是一个工作单元,不是一次顺手。**

-71. **§10 的三个 WK trunk 红**(2026-09-01T13:59Z 量到,**先于那轮改动**,已独立复现)。
   **三个各是一个工作单元**(每个都要重新推导正确读数,不是改数字)。已开 **GH #392**。
   - ~~`test_wk_roshan_mana_floor`(§1+§4 **断言的是 09-01 修法力之前的世界**,
     归因由它自己的断言文本给出)~~ **2026-09-01T16:51Z done ——
     报告 `iterations/reports/hero/20260901T165100Z.md`;测试文件独一份 +192/−26,
     `bots/`+`game/` 零行。重新推导之外还买到一个量具坏着时构造性不存在的读数:
     出货 600 拒绝 / armed 315 准入,在同一帧满蓝的 WK 上。**
   - ~~**`test_wk_considerq_level7_dominance`(:451)—— 仍红,仍开。**~~
     **2026-09-01T22:55Z done —— 报告 `iterations/reports/hero/20260901T225550Z.md`;
     测试文件独一份 +205/−16,`bots/`+`game/` 零行。⇒ #392 三格全清,本轮已追评并 CLOSE。**
     那个「分歧」是**错名字**:`wraithfire_blast` 是显示名,内部名是
     `skeleton_king_hellfire_blast`,mock 对不存在的名字返回空白句柄 ⇒ **0 是「没有这个
     句柄」不是「没升级」**;ground truth 没过期。真因在更上游:阶梯唤醒了
     `X.ConsiderQ` 的**第一条语句** `X.ShouldSaveMana`(末项阶梯前是 `272−0 < 0` 恒假),
     **在任何分支跑之前短路**。新 §5b/§5c/§5d/§5e:重建阶梯前量具 ⇒ 记录**逐字复现**;
     真实量具下两级都静默且钉住**理由**;闸位从句柄读 **220+95=315**(314 静默/315 开火);
     蓝给到 315 **等级台阶原样回来**(dominance 完好);**max mana 272 < 315 ⇒ 该等级上
     Q 构造性放不出**,而这在真实对局里一直是活的。
   - ~~**`test_wk_bone_guard_talent_bypass`(§3,22 录成 19)—— 仍红,仍开。**~~
     **2026-09-01T19:48Z done —— 报告 `iterations/reports/hero/20260901T194837Z.md`;
     测试文件 +205/−8 + `tests/frames/README.md` 棘轮一行,`bots/`+`game/` 零行。
     不是数字过期:分母没动(36 帧)而盲区**缩小**,原因是法力阶梯唤醒了
     `X.ShouldSaveMana`(阶梯前那一句是 `mana < 0`,恒假),3 帧因此停在守卫**前面**
     一个析取项、**离开**盲区。新 §3b 用「把 `GetManaCost` 按回 0」重建阶梯前的量具,
     钉:重建下**恰好回到 22** / 真实下**恰好 19** / **进入集合断言为空集** /
     **离开的三帧逐个点名并核对保蓝三个操作数**。棘轮 `22 → 23` 改成 `19 → 20`,
     staged 帧**重测过**(lv21/587 蓝,保蓝为假,仍在盲区)。**#392 划掉一格,不能关。**

-70. ~~**认领 GH #390(录像组 13:05Z 开,本轮最新的 [hero] issue):
   答它的 rec 2「改问分支到达」与 rec 3「域要重新预登记」**~~
   **2026-09-01T13:59Z done —— `bots/BotLib/hero_skeleton_king.lua` **仅注释**(+37,
   `ConsiderQ` 的 `wkqdmg` 域注解尾部);`game/` 0 行;零新 gate id、零 arm/promote、
   **零行为改动**、零 AWS(连 S3 GET 都没有)、不申请波次;`state.json` / `test_set.md` /
   `queue.json` 均无新增。新 `tests/test_wk_q_castrange_meter_domain.lua`(8 节)。
   报告 `iterations/reports/hero/20260901T135952Z.md`。**
   - **⭐⭐ 第五个量具零:`GetCastRange` 未 spec ⇒ 泛型 `^Get` 答 0,36/36 个活 WK 瞬间。**
     **和前四个都不同的一点:答案已经在仓库里** —— `special_value_shapes.lua` 给焦点五
     21 个带价钱技能里的 **14 个**带着 `AbilityCastRange`,Q 那条读 **525**,就在 09-01
     接上线的 `AbilityManaCost` 阶梯**上面三行**。**不是缺数据,是缺一根线。**
     曝露面 **433 个代码调用点 / 150 个文件**(代码/注释按行分开数),是 `GetAOERadius`
     普查的 **62 倍** ⇒ **本轮不修**。
   - **⭐⭐ 闭式:这个零把四个圈缩掉** —— 搜索圈 855→**330**、紧圈 568→**43**、
     击杀闸 605→**80**、远程加宽 875→**350**。**失效方向是低估可达性**(与 `GetAOERadius`
     同向、与法力反向)⇒ 本仓库历来每一句「这一帧到不了分支 N」都是穿过这四个圈量的。
   - **⭐⭐ 语料那个 0,18 帧里 16 帧是空的**:桶穷尽(未学 5 / 冷却 9 / 法力 0 /
     `ShouldSaveMana` 4 / 进体 18);进体 18 帧里,击杀确认循环**量具零下被进入 0 次,
     喂回 525 后 2 次**(两帧都走到距离闸,**都不开火**)。
     ⇒ **一个 fixture 语料的 0 不是录像组 0/97 的第二份意见,是一份从来没有能力反对的读数。**
   - **⭐⭐ 数施法次数量不了这根杠杆(答 rec 2,闭式)**:击杀确认是**十个开火点里的第 2 个**,
     **十个全返回同一个常数 `BOT_ACTION_DESIRE_HIGH`**,只差目标 ⇒ 压住第 2 点只有在
     下游八个点同帧全弃权时才降低施法次数。#390 的 t=243.4 帧「两腿不可区分」**是构造性的**;
     **armed 腿 108 vs baseline 97 不是反对证据**。
     **⇒ 重新登记的域(答 rec 3)**:`ehp0 ∈ 带` **AND** 目标在 `nCastRange + 80` 之内(闸,
     不是搜索圈)**AND 该帧没有任何下游开火点交回同一个目标**(新的第三条,让它成为**边际域**)。
     **可观测量是目标身份,永远不是施法次数。**
   - **⭐ 给修量具的人的陷阱:ABSENT 不是 0** —— 21 个里 **7 个真的没有射程**,但快照里
     **同时**有字面的 `0`(`zuus_cloud`)和字面的 `-1`(`crystal_clone`,无限射程约定)⇒
     把「没有键」映射成 0 会让那七个和 Nimbus 不可区分,而 `dist <= -1` 是**恒假**。
   - **诚实边界**:(A) 本轮不修量具;(B) 那 2 帧 **n=2 且都不开火** ⇒ 对真实开火频率
     **什么都没说**,无偏读数仍是录像组的 205 次施法;(C) **525 是快照值不是引擎读数**
     (引擎可能叠 facet/天赋/物品射程);(D) 语料不是对局样本。
   - **⚠️ 自己翻的车两次,两次都是老手法**:(1) 第一版探针**报告器是空的**(`print` 被 mock
     换 no-op)——**一周内第三次**,抓在探针阶段没进产物;(2) 第一版把 **5 个源码行号硬编码**,
     而我自己插的 37 行注释把它们全部错位 —— **错位的行覆盖探针不会红,它报 0,
     而 0 和「没走到」是同一个整数**。改成从源码解析(`resolve_lines()`,五锚 + 顺序断言),
     并加 **M10 专管这个**(在 `ConsiderQ` 上方插三行注释,读数一个都不许动)。
   - 变异台 **9 + 2 个控制**,条条一次见红且只红在该红的节(**M4 空语料控制**恰好红
     读语料的四节 §1§4§5§6 而不红 §2§3§7§8);**M10 行号解析控制**与 **M0 注释单改**
     两个都绿;文件副本还原,**3 份 `cmp` 逐字节相同**。
     门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);
     动态**全部引用 `skeleton_king` 的 70 个文件 + smoke = 71 个,68 绿 / 3 红,
     三红先于本轮改动**(`git checkout` 独立复现后 `cp` 回来 `cmp` 逐字节相同)。
     ⚠️ 开工自检第一条命令又被 REFUSED(**第十一次**管道给 `tail`)= 什么都没检查不是通过;
     裸重跑 **exit 124 被 timeout 砍掉 = 没跑完也不是通过**(跑到的 python 腿 72/0 +
     **2 UNCERTIFIABLE**,两个都是「`lua5.1` 还没装」= GH #383/#384 那一形;**本 diff 零行 python**)。
   - **下一棒**:(1) **`GetCastRange` 的零已开 GH #391** —— 定案证据是接上线后
     全语料有多少条「到不了分支 N」的既有声称翻面;(2) **GH #390 已按 rec 2/rec 3 追评**,
     `wkqdmg` 维持 gated & unarmed,**验收条件里的「施法次数」要换成「目标身份」**;
     (3) **§10 三个 trunk 红已开 GH #392 并进 backlog `-71`**;(4) GH #386 仍等录像组,
     GH #357 admission 仍阻塞,GH #374 仍在总监手上。

-69. ~~**取 backlog `-43a` 的 CM 方向(三个方向的最后一格):以 CM 为主角逐帧 ——
   入口的两半都比看上去值钱少,而它们压着的是第二个量具零**~~
   **2026-09-01T10:58Z done —— `bots/BotLib/hero_crystal_maiden.lua` **仅注释**(+23,`cmrself`
   头部 addendum);`game/` 0 行;零新 gate id、零 arm/promote、**零行为改动**、零 AWS
   (连 S3 GET 都没有)、不申请波次;`state.json` / `test_set.md` / `queue.json` 均无新增。
   新 `tests/test_cm_ult_reach_meter_domain.lua`(8 节)。帧按名字/按目录枚举 ⇒
   #357 表里 **9 个 ratchet 一个都没动**。报告 `iterations/reports/hero/20260901T105812Z.md`。**
   - **⭐⭐ 主读数:上一轮点名的三个「只差 1 点蓝」边缘是**安全**的那三个;判不了的是
     没人点名的那个 0。** dumper 写 `int32(mp + 0.5)`(四舍五入)⇒ 记录值 v 的真值在
     `[v−0.5, v+0.5)`;margin = −1 时整个区间在价钱之下 ⇒ **三条都确定**。
     全语料**唯一** margin = 0 的读数(`f_260819_004858_cm_centaur_far`,200 对 200)
     真值区间**一半在价钱之下**,**现在算作 castable,不确定性朝「可施放」** ——
     修法力量具把这个曝露面从 157 收窄到 **1**,**没关掉**。
     16 个撤销独立复现(48 instant / 209 句柄 / 已学 195 / 157 → 141;nova 7 + frostbite 4 + field 5)。
   - **⭐⭐ 第二个量具零,压着的是大招:`GetAOERadius` 不在任何 spec 上 ⇒ 泛型 `^Get` 答 0**
     ——`GetActualIncomingDamage` / `GetAbilityDamage`(#175)/ `GetManaCost`(09-01)之后**第四例**,
     `bots/` 下 **7 个调用点**。`X.ConsiderR` 的 `nRadius = GetAOERadius() * 0.88` 乘进大招
     两条「不看血量」分支的每个子句 ⇒ **历来生成过的每一帧上构造性不可达**;
     **方向与法力项相反:低估可达性**,把「CM 从不想开大」变成假象。
   - **⭐⭐ 决策侧 48/48 全 0 而这个 0 不作数**:五个入口 × 48 帧 = **240/240 个 0,两个世界相同**;
     压着它的是五个常数(`GetActiveMode`=0、`IsGoingOnSomeone`=false、`IsRetreating`=false、
     `FindAoELocation.count`=0、`GetAOERadius`=0),§4 把这五个常数**和那 240 个 0 钉在一起**。
   - **⭐ 把半径喂回去,整份语料恰好两帧从 0 翻成 `DESIRE_HIGH`**:`f_260820_043039_cm_cask_close`
     (t=515.5,血 **30.0%**,`#enemies>=3`,队友 0,**0.2s 后死**)与 `f_260820_103216_cm_es_aftershock`
     (t=473.5,血 **26.3%**,`aoeCanHurt>=2`,队友 0,**1.0s 后死**)。810 与 835 两个锚**逐帧同解**。
   - **⭐ 对停放中的 `cmrself` 的两句新话(不改停放)**:(1) **多了一个 domain 帧且来自
     08-21 预检语料之外的一局**,触发的是 `#enemies>=3`——**不读移速** ⇒ 预检的「移速 ≥330
     domain 归零」脆弱性**不再覆盖整个 domain**;armed 时**2/2** 收回引导。
     (2) **闭式**:该否决只可能改 branch 1/2 的出价(它在血量地板**之下**开火,branch 3 要求
     **之上**同一常数 ⇒ 不交),而 1/2 都乘 `GetAOERadius` ⇒ **引擎若也答 0 则该 id 构造性 no-op;
     若答 KV 半径则它的 domain 恰好是开火集**。**分叉离线读不到,只登记不选边。**
   - **诚实边界**:(A) **语料不是对局样本**(fixture 是找出来的瞬间,几个 CM fixture 存在
     就因为她在死)⇒「48 里 2」**永远不是每局频率**,无偏读数仍是 17 局预检;(B) 开火集 **n=2**
     且同一天;(C) **引擎侧 `GetAOERadius` 未知**(KV 有 `radius=810`、**无 `AbilityAOERadius` 键**),
     姊妹文件锚 **835**,§7 钉「两锚同解」而不是挑一个;(D) 开火集依赖本文件自己喂的量具,
     **没有任何断言说出货 bot 在真实对局那两帧会开大**。
   - **⚠️ 自己翻的车两次**:(1) 分支归因第一版**报告器是空的**(`print` 被 mock 换 no-op)——
     **空报告器一周内第二次**;(2) §5 调用点普查用裸 `grep -rc` ⇒ **数到了我自己刚写进 hero
     文件的两句散文**(7 → 9),**本文件第一次跑自己红了且红得对**,改成按行区分代码/注释
     **并断言注释行 > 0**;这正是 `-64` 记下的「40 行被 grep 读成 43」同一手法。
   - 变异台 **9 + 1 负控制**,条条一次见红且只红在该红的节;**M8 空语料控制**红 §1§2§4§5§8
     而 **§6§7 不红**(那两节读点名帧不是普查),如实登记;M10 代码/注释切分控制红 §5§6;
     文件副本还原,**5 份 `cmp` 逐字节相同**。门:静态 **exit 0 / 0 warnings**(裸读,
     **没用 `RULE6_BYPASS`**);动态**全部引用 `crystal_maiden` 的 40 个测试文件 exit 0**。
     ⚠️ 开工自检第一条命令又被 REFUSED(**第十次**管道给 `tail`)= **什么都没检查不是通过**;
     裸重跑 exit 3 = cadence(**不是本组**)+ python 腿 UNCERTIFIABLE(**本 diff 零行 python**)。
   - **下一棒**:(1) **`GetAOERadius` 的零已开 GH #386**;**能定案的证据是录像组的** ——
     出货 CM 在真实对局里有没有经 branch 1/2 开过大(非撤退态、身边 ≥3 人的引导):
     有 ⇒ 引擎答非零、量具该修且 `cmrself` domain 为真;普查不到 ⇒ 那两条分支在真实对局里
     **也是死的**,那是**英雄组的行为缺陷**不是量具问题。(2) `cmrself` 维持停放,记法已更新。
     (3) margin-0 那一帧是唯一残留的「朝可施放失效」读数。
     (4) **`-43a` 三个方向(Zeus / Lion / CM)全部付清**;GH #357 admission 仍阻塞;
     GH #374 仍在总监手上。

-68. ~~**取 backlog `-43a` 的 Lion 方向(连续第七轮欠着):以 Lion 为主角逐帧 —— 落点是
   总监自己给 `lionult` 写的那条复活条件,它触发了,而重量的结论朝相反方向**~~
   **2026-09-01T08:04Z done —— `bots/BotLib/hero_lion.lua` **仅注释**(25/3);`game/` 0 行;
   零新 gate id、零 arm/promote、**零行为改动**、零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;
   `state.json` / `test_set.md` / `queue.json` 均无新增。新 `tests/test_lion_ult_reserve_domain.lua`(8 节)。
   帧**按名字**加载 ⇒ #357 表里 **9 个 ratchet 一个都没动**。
   报告 `iterations/reports/hero/20260901T080403Z.md`。**
   - **⭐⭐ 主读数**:GH #73 的 lever(a) `lionult` 在 2026-08-20 被 strike(域空 0/1216),
     但总监 23:00Z 裁定**附了复活条件**:**「正确的记法是『在 Finger level 1 上域为空』」**,
     因为 cost 梯子 `[200,400,600]` 而 **cost=400 那条线对着 380 的蓝池底不是空的** ⇒
     **到 hero level 12+ 要重量,不许直接引 0/1216**。此后**两件事发生而没人回来重量**:
     (1) 有了第一个 11 级以上的活 Lion(`tests/frames/f_20260831_004433_cm_creepreach`,
     t=1190.4,**20 级 / Finger rank 2 / cost 400**);(2) **09-01 修好法力量具之前这条谓词
     根本不可求值** —— 带子 `[0,0)` 构造性空集、`mp>=0` 恒真,**08-20 写进 source 的那句
     语料声称在当时的量具下无法被证伪**。
   - **⭐⭐ 最该拿走的:复活条件的算术只让一边动了,而两边都在动、不同速。**
     cost 确实是 400,**蓝池不是 380 是 1551(4.08 倍)**。且**闭式**:带宽 = 最便宜的可施放
     基础技能,Impale 梯子 `{90,110,130,150}` **在 rank 4(约 7 级)到头冻在 150**,蓝池不到头
     (387→708→1158→1551)⇒ 带子占蓝池 `150/max_mp` **严格递减:8 级 21.2% → 20 级 9.7%**。
     **升级让域变小不是变大**,而论证**一帧的当前蓝量都不读**。
   - **⭐ 漏斗**:活 Lion **24** → 已学 **13** → 不在冷却 **3** → 付得起 **3** → 域内 **0**。
     **约束的不是法力是冷却**(10/13 在 cd 上,剩余 1.2–108.6s 对 110s);`tooPoor=0`。
   - **诚实边界**:**rank 2 上 n=1**(380 是 1216 帧的最小值,1551 是**一个满蓝 instant** 的最小值,
     **不是同一个估计量**);**rank 3 未测**;**「稳定到 12+」不成立**(11 级以上仅一帧)。
   - **⭐ 顺带**:法力修复对**焦点五内部**的覆盖比 `-67` 声称的窄 —— 四桶穷尽
     `PRICED` 362 / `NO_MANACOST_KEY` 95 / `LADDER_ALL_ZERO` 19 / `NAME_NOT_IN_SNAPSHOT` 85
     (天赋 28 + **内在技能 57**)。内在那 57 是已知命名错位(引擎带 `innate_` 中缀),
     **对法力无影响 ⇒ 不是缺陷是陷阱**,快照生成是 harness 的活,不越位。
     **Lion 撤销 0/70;CM 16 个,三个只差 1 点蓝**(154/155 ×2、399/400)。
   - **⚠️ 自己翻的车三次**:第一版驱动器直接调 Consider ⇒ 24 个 instant 崩 13/17,
     **是我的错**(`hEnemyList` 由 `SkillsComplement` 在 Consider 之前填),**没据此下裁定**;
     报告器差点又是空的(`print` 被 mock 换 no-op);四桶第一版不穷尽。
   - **⭐⭐ 变异台抓到一个我本来会留下的洞**:**M7(量具回退)下 `inWindow` 仍是 0,
     「域为空」照样绿** —— **「空谓词的 0 和空语料的 0 是同一个整数」在我自己的新文件上又来一次**。
     补前置守卫(先断言 24/24 拿到非零价钱再报那个 0),补后 M7 如期见红。
     变异台 **9 + 1 负控制**,条条一次见红且只红在该红的节;文件副本还原,3 份 `cmp` 逐字节相同。
   - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态 Lion 全部 11 文件
     **158 例 exit 0** + 8 个相关文件全绿。⚠️ 开工自检第一次又被 REFUSED(**第九次**管道给 `tail`)
     = **什么都没检查不是通过**;裸重跑 exit 3 = cadence(**不是本组**)+ python 腿 UNCERTIFIABLE
     (GH #358/#380,**本 diff 零行 python**)。
   - **下一棒**:(1) **`lionult` 维持 struck,记法再窄一格**(带宽冻结 ⇒ 域随等级收缩;
     rank 2 n=1 未答、rank 3 未测),**GH #73 追评已发表**;(2) **`-43a` 的 CM 方向仍欠**
     —— 入口是 CM 那 16 个被撤销的读数 + 三个刀口;(3) 内在命名错位是 harness 的活;
     (4) GH #357 admission 仍阻塞;GH #374 仍在总监手上。

-67. ~~**取 backlog `-43a` 的 Zeus 方向(连续第五轮欠着):以 Zeus 为主角逐帧**~~
   **2026-09-01T04:51Z done —— 逐帧做了(52 枚 Zeus hero-instant,`X.ConsiderR` 逐帧驱动),
   **落点不在 Zeus 的决策上,在量具上**。`bots/` 0 行、`game/` 0 行;零新 gate id、
   零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;
   `state.json` / `test_set.md` / `queue.json` **均无新增**。三个文件全在 `tests/` 下:
   `tests/mock/replay_fixture.lua`(量具修复)、新 `tests/test_fixture_mana_price.lua`(6 节)、
   `tests/test_replay_260819_zuus_ult_manalock.lua`(一个断言订正)、
   `tests/test_cm_t10_payoff.lua`(绊线和解)。
   报告 `iterations/reports/hero/20260901T045158Z.md`。**
   - **⭐⭐ 主读数:`IsFullyCastable` 的法力项从落地起一次都没能开火。** loader 自 §F 起就写着
     `owner:GetMana() >= (self:GetManaCost() or 0)`,而 `GetManaCost` **不在任何技能 spec 上**
     ⇒ 掉进 `bot_api` 泛型 `^Get` 兜底答 **0** ⇒ `GetMana() >= 0` 恒真。
     **修前:全语料 4376 个技能句柄,4376 个答 0,零个答非零。** 焦点五「已学 + 报 castable」
     **381** 个,真实 KV 价钱**撤销 40 个(10.5%)**,覆盖全部五个英雄。
   - **⭐⭐ 那段闸上面的注释自己点名的举例就在这 40 个里**:它写着「a 246-mana ultimate
     reading 'fully castable' while the hero held 190 mana, **which is the real reason
     X.ConsiderR bails on its first line**」—— `f_260819_142047_zuus_ult_denied` 正是
     190 vs 250 且读作 CASTABLE。另有 **11 法力**的 Zeus、以及**名字就是法力锁**的
     `zuus_ult_manalock` 在 **99 法力**上把 250 的大招读成可施放。
     **失效方向朝危险那侧**:恒真合取项**高估**分支可达性 ⇒ 一切经过它的
     「这帧走到了分支 X」都踩在免费法力上。**`GetActualIncomingDamage` / `GetAbilityDamage`
     两个零的同族,第三例。**
   - **⭐⭐ 它已经在骗一个绿断言,而且和该文件自己的观测打架**:manalock 测试断言出货 Zeus
     放 **Lightning Bolt**,而**同文件文件头**记着录像真值是「spends 94 on **Arc Lightning**」——
     **两周里断言和观测点名两个技能,没有任何一条腿举手**。原因:Bolt rank1 要 120,手上 99。
     ⚠️ **该文件恰恰也是全仓唯一部分收过钱的地方**(手工把大招锚到 246)⇒
     workaround 只盖住大招,基础技能仍免费,端到端那条腿**从它声称复现的帧上漂走了**。
     修好量具让模拟**落回**观测行为。订正后把 Bolt 钉成**付不起**(不只是没选中),
     **`zusult` 的前提更锋利**:漏掉的是 99 里的 95,剩 4。
   - **⭐⭐ 一条为本次改动预先写好的绊线如期打红,和解成立**:`test_cm_t10_payoff.lua:176`
     的失败文本就是「reconcile the two before trusting either」。**datafeed(08-23)与 KV 快照
     相隔九天、彼此独立,三条梯子逐位相同**(Nova 115/135/155/175、Frostbite 125/135/145/155、
     Freezing Field 200/400/600)⇒ 该节改成断言**一致**而非断言**缺席**,**严格更强**:
     旧写法只能发现第二来源**出现**,新写法能发现它出现**并且不一致** —— 而
     **CASTABLE 通道由 sweep 定价、DECISION 通道由 loader 定价**,漂移会把两者放进
     不同世界而**谁都不变哑**。**本仓库第二次有人把这种 baton 触发到。**
   - **⭐ Zeus 逐帧读数本身(交出去)**:52 帧出货腿全部 desire=0;一级分解
     14 帧 rank 0 / 17 帧冷却 / 21 帧走到分支,**而那 21 里 9 帧是免费法力造出的假可达**
     (真实价钱后剩 **12**)。⚠️ **`lowHPCount` 全 0 但这个 0 不作数**:
     `GetSpecialValueInt('damage')` 同样答 0 ⇒ **开火侧离线不可求值**,
     本轮**不据此对 `X.ConsiderR` 下任何裁定**。
   - **⚠️ 自己翻的车两次,都在方法论上**:(1) 普查第一版**报告器是空的** ——
     `bot_api.lua:405` 把 `print` 换成 no-op ⇒ **零输出、exit 0**,与「跑完没发现」同形。
     **「空谓词/空语料」家族一周内第八次,这次是空的报告器**;(2) 第二版**分母为零**
     (`UNIT_LIST_ALLIES` 该 mock 不填),4376 被数成 0,**每条比率仍打印 0.0% 且 exit 0**;
     **抓到它的唯一原因是我把分母也打了出来**。(3) 本文件第一次跑**自己红了一条且红得对**:
     §3 原用「免费句柄数 ≤ 非焦点句柄数」定价缺口,**是错的代理量**(把被动/天赋/KV 真为 0
     都读成缺价)⇒ 改成**逐句柄按成因分类**,四桶穷尽各自非空,**零个无法解释**。
   - **诚实边界(必须连着引)**:快照只覆盖**焦点五**(21 个技能带梯子),
     **其余 122 个英雄仍然免费** ⇒ 本改动**收窄**恒真式**没有关闭**它,§3 写成断言,
     快照扩宽即变红;梯子是 **KV 声明不是帧读数**(录像量到的优先,246 不动);
     **未建模任何减免**(神符/天赋/玲珑心)⇒ 仍然乐观,方向不变只是小得多。
   - 变异台 **10 个,条条一次见红且只红在该红的节**(M7/M8 **成对**:和解节必须漂移与沉默
     **两个方向都能红**;M9/M10 **成对**:抬升不再最小 + 定价消失);对照全绿;
     还原后五份 `cmp` 逐字节相同。
   - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**;容器缺 luacheck,
     gate 自己装的)。本 diff **`bots`/`game` 零行**;改动三文件单独 luacheck
     **改前 12 条 / 改后 12 条逐条相同**,新文件 **0 条**。动态见报告。
     ⚠️ **开工自检第一次我又把 stdout 管给 `tail`** = **什么都没检查不是通过**(第八次);
     裸重跑 exit 3 = cadence(**不是本组**)+ `test_rc_wrapper.py`(**GH #364 已立案 flaky**,
     本 diff 零行 python)。
   - **下一棒**:(1) **量具的账没付完,而且这一半是别人的** —— 非焦点 122 英雄仍免费,
     扩宽快照要跑 `special_value_shape_census.py --snapshot` 拉 d2vpkr 镜像,
     **是 harness/总监的活,本轮不越位**;(2) `X.ConsiderR` 开火侧仍离线不可求值,
     与 `zusstatic` 同一堵墙,**只剩波次一条路而 `zusstatic` 还没入测试集** ⇒ 本轮**不提 queue**;
     (3) **`-43a` 的 Lion / CM 两个方向仍欠**(Zeus 这一格本轮付掉);
     (4) GH #357 admission 仍阻塞;GH #374 仍在总监手上。

-66. ~~**认领上一轮交出的棒(GH #357「把帧搬进 `tests/fixtures/`」)—— 执行的第一步把它否掉了:
   那个「解锁」是从 issue 自己标了是**下界**的数推出来的**~~
   **2026-09-01T02:21Z done —— 帧**没有搬**,仍 staged。`bots/` 0 行、`game/` 0 行;
   零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;
   `state.json` / `test_set.md` 无新增;`queue.json` **只改本组自己的 `hero-10` 的 `question`**
   (追加日期块,不动裁定/路由/优先级/status)。改动:`tests/test_wk_level_supply_horizon.lua`
   (枚举器 + §2 + 新 §6)、`tests/frames/README.md`、`tests/test_axe_t15_in_domain.lua`(§1 过期文案)。
   报告 `iterations/reports/hero/20260901T022126Z.md`。**
   - **⭐⭐ 主读数:admission 的价钱是 25 个文件不是 9 个。** 范围 = **93 个**枚举语料目录的测试文件
     + 6 个按名字加载该帧的文件;`git mv` 进去、跑、再 mv 回来 ⇒ **25/93 见红**,另 3 个在范围外也红。
     **低了约三倍** —— #357 自己写着「⚠️ 这是下界不是普查:跑到 a–f 段时我主动掐断了它」,
     而 README 昨天的「therefore unblocked」正是从那个下界推的。已改。
   - **⭐⭐ 未付的真判定六条,只有三条是本组的**:level-gate 的 level-20 零(四条 INERT 裁定)、
     同文件 `frames_past_18min` 0→1(`J.IsLateGame()` 不再空洞 ⇒ `mode_farm_generic:393/:507`
     的 TEETH 要重读)、`turbo_ternary_dominance` 欠一枚帧钉(它**只能靠算术**的理由消失了)——
     **这三条不是本组的**;`cm_t10_payoff` 的死亡通道 0→1、`lion_t15_payoff` 的域内 Lion 0→1、
     WK 那族(压在 queue `hero-10` 上)—— **这三条是**。另加一条两边都不算的:
     `test_itemdesire_world_assertion` 说崩溃现在来自 **3 个语句不是 2 个**(第三个没 stub 的引擎 API)。
     **#357 第 9 行自己也少了一个文件**:`zuus_lightning_hands` 1→2 是**两个**文件在读。
   - **⭐⭐ 普查掉出来的真缺陷(本轮唯一代码修复)**:`test_wk_level_supply_horizon` 把「全仓」
     实现成 **glob + 一条写死的路径**。08-28 写下时穷尽;**08-31 GH #357 建了第二个 glob 外目录,
     当天起不再穷尽 —— 而断言绿了三天**。漏掉的是一位 **21 级 Wraith King**(t=1190.4)。
     **失效方向朝危险那侧**:这个数是 queue `hero-10` 的前提,而它**低估了仓库已经拥有的证据**。
     改成**枚举**那个目录(§2 读数 1→2,新 §6),第三个位置必须付一次编辑。
   - **⭐ 对 `hero-10` 两条相反影响**(已写进 queue,status 不动):(1) 等级供给的零
     **不再是零**(全仓 ≥19 的 WK 位有两个,都在 glob 外)⇒ 拿掉了「不扫描就退休 `wkrosh`」那条路;
     (2) `result` 记的「最大蓝池 459」被 staged 那位的 **max_mp 711** 顶住 —— ⚠️ **但同一条记录
     `alive=false`/`hp=0`/`max_hp=0`,死单位的容量字段被归零** ⇒ **存疑标记不是反证**,
     §6 两条断言成对写,谁引用 711 都同时读到限制句(GH #357 第 3 行付过一次的形状)。
   - **⚠️ 自己翻的车两次,都在方法论上**:(1) 普查第一版**是空的** —— `lua5.1` 直接跑一个测试文件
     **返回那张表、一个函数体都不调用**(exit 0、零输出,`run_tests.lua` 文件头自己写着,
     GH #200)。**「空谓词的 0 和空语料的 0 是同一个整数」一周内第七次同形**,这次是**空的运行器**;
     (2) 开工自检第一次 REFUSED(我又把 stdout 管给 `tail`)= **什么都没检查不是通过**(第 7 次)。
     重跑 exit 3 —— 两条 trunk-red **是我自己造的**(自检 Lua 腿正好跑在 mv 进 fixtures 的窗口里),
     **它因此白送了第二来源的普查**(64 个 detector 里 11 红),与 93 文件那份**取并集**才是主表。
   - 变异台 **8 个,全部一次见红且只红在该红的节**(M1 枚举器恒空、M2 模式不匹配、M3 不按 WK 过滤、
     M4 池读数改读 `mp`(587)证明它在 600 上真的分辨、M5 `alive` 翻面、M6/M7 计数不累加、M8 等级锚 21→99);
     **先存副本、从副本恢复**,还原后 `cmp` 逐字节相同。
   - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**;容器缺 luacheck,gate 自己装的);
     动态**子集不是全套**(GH #124)14 组全部 exit 0;queue.json 动了 ⇒ 另跑
     `python3 tests/test_pending_rulings.py` **84 checks / 0 failed / exit 0**。
   - **下一棒**:(1) **admission 仍阻塞**,三条本组的各值一个工作单元,**三条不是本组的已在 #357
     追评里点名交出**(https://github.com/dragonghy/dota2bot/issues/357#issuecomment-5487884890),球给总监分派;(2) **queue `hero-10` 执行前先读新加的那块**;
     (3) **`-43a` 的 Zeus 方向仍欠**(连续第四轮);(4) GH #374 仍在总监手上。

-65. ~~**认领 GH #366:把「(a) bot 没花点 / (b) dump 陈旧」这个分叉判掉**~~
   **2026-08-31T23:01Z done —— 判掉了:是 (a),而且不是十条构筑行各自出错,
   是一条共享的队头阻塞。`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
   零 AWS、不申请波次;`state.json`/`queue.json`/`test_set.md` 均无新增。
   新 `tests/test_skill_point_stall_frame.lua`(8 节点,`[ratchet]`)。
   报告 `iterations/reports/hero/20260831T230146Z.md`。**
   - **⭐⭐ 主读数**:十个英雄、两队、十份脚本,**非天赋前四名 rank 多重集 10/10 都是
     `{4,4,3,2}`,和 13**;六个 1 天赋、四个 0 天赋、**没有一个 2 个**;前四名之外全 rank 1。
     ⇒ **13 构筑点 + ≤1 天赋 = 十四格**,17–22 级都一样。**量具零名字表**
     (#366「量具」那个坑):天赋按引擎前缀 `special_bonus_` 数,构筑点取前四并**断言**其余 ≤1。
   - **⭐⭐ 墙在第 15 格,源码可证**:发货 `GetSkillList` 把天赋放在 **10/15/18/19** 格
     (真实函数 + 声明输入;mock 的 `GetTalentList` 答八个 nil,**测出来的**);
     `ability_item_usage_generic.lua` 末尾 `else` **不删任何东西除非 `botLevel > 25`**
     ⇒ 队头挡住后面一切到 26 级,turbo 到不了。**GH #286 同族**(那个只覆盖 nil 队头)。
     **第二堵墙**:18/19 格是 t20/t25,**早 2 级 / 早 6 级**端出来,已写进 §5 断言。
   - **⭐ (b) 无机制**:dumper `resolveAbilities` 每采样读活 `m_iLevel`、**无缓存**
     (断言无 `map[`);帧上有 rank 4/3 和 rank 1 天赋 ⇒ 字段没被截断。
   - **⭐ 退了 #366 自己的对照组**:CM 按大招 rank 是合法对照,按技能点不是
     ⇒ 损失是**每个英雄欠 3–8 个技能点**,不是「九个大招各短一级」。
   - **⚠️ 没确立**:(1) 栽在三条升级条件的哪一条(离线判不了,**但阻塞与它无关**);
     (2) 「六个学到的全是通用天赋、全帧零 unique」是**相关性不是机制**,Axe 那对配对 **n=1**;
     (3) 一局一瞬十 slot,**频率形状的话都不成立** —— 但 §2 两条读的是**源码**。
   - 变异台 **12/12 见红且只红在该红的节**(M7 负控制 = 把 `table.remove` 挪出守卫,
     报的就是顺序那句;M11 读数器留前 0 名、M12 谓词清空 —— 「空谓词的 0 和空语料的 0
     是同一个整数」一周内第六次)。还原后 5 文件 `cmp` 逐字节相同。
   - 门:静态 exit 0 / 0 warnings(裸读,没用 `RULE6_BYPASS`);动态子集 8 组全 exit 0。
     ⚠️ 开工自检第一次 REFUSED(我又把 stdout 管给 `tail`)= **什么都没检查不是通过**。
   - **下一棒**:(1) 修复是独立 gated 工作单元、落点在 `bots/ability_item_usage_generic.lua`
     (127 英雄全跑)⇒ **已开 [bug] GH #374,球交总监分派**;(2) #366 追评已发表;
     (3) **`-43a` 的 Zeus 方向仍欠**;(4) GH #357 的「把帧搬进 `tests/fixtures/`」仍解锁。

-64. **付 GH #357 第 2 行(三条真判定的**最后一条**):Alchemist 时钟带 —— 帧确实第一次
   落进带里,但**时钟是五条合取的最后一条**,另外四条的 0 是 mock 默认值不是观测;
   堵点在**生成器**不在世代 ⇒ `alchrage` VERDICT UNCHANGED,**#357 真判定清单全部付清****
   **2026-08-31T19:51Z done —— `bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
   零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;`state.json` / `queue.json` /
   `test_set.md` 均无新增。新 `tests/test_alchemist_rage_clock_staged_frame.lua`(11 节点);
   `test_alchemist_rage_objective_clock.lua` **只改注释与文案,`assert(tMax < ARMED, ...)`
   条件逐字节未动**;`tests/frames/README.md` 第 2 行 OPEN → PAID。帧**按名字**加载 ⇒
   #357 表里 **9 个 ratchet 一个都没动**。报告 `iterations/reports/hero/20260831T195108Z.md`。**
   - **⭐⭐ 主读数**:t=1190.4 **确实第一次落进 [900,1800) 与 [960,1920)**(出货说 FIRE、
     armed 说 HOLD)——**但它是每个调用点五条合取的最后一条**。真实 loader + 出货 helper
     逐个求值,10 个英雄:载体(Alchemist/Rubick)**0 / 1,080 hero-instant**(108 帧 41 英雄)、
     `IsDoingRoshan` **0/10**(`GetActiveMode()` 答 0,`BOT_MODE_ROSHAN=1020`)、
     `IsDoingTormentor` **0/10**、`IsAttacking` **0/10**、`GetAttackTarget` **0/10 (nil)**。
     **那四个 0 全是 mock 默认值,不是观测** ⇒ **VERDICT UNCHANGED**。
   - **⭐⭐ 最该拿走的:比第 3 行糟一级 —— 堵点在生成器里。** 第 3 行的承重零(免疫)
     还在 dumper 已写的 schema 内,后来的帧原则上能动;这一条不是。`make_fixture.py`
     只发 `units`(**只有英雄**)、`buildings`、`creeps`(**`team,x,y,dt`,连 name 都没有**),
     而 `J.IsRoshan`/`J.IsTormentor` 判 `GetUnitName()` 含不含 `roshan`/`miniboss`
     ⇒ **schema 里不存在能命中的记录类型** ⇒ **这个生成器产得出的任何一帧、任何世代,
     都钉不了这个决定**。买 (a) 只剩**波次**一条路。
   - **⭐ 改的是常设指令不是裁定**:`[corpus]` ratchet 文案原写「pin the decision on that
     frame」,**不可执行**,已改指新文件;ratchet 保留且**仍为绿**(语料 tMax 790.4 < 900)。
   - **⚠️ 变异台上自己翻的车(M11 幸存)**:孪生体 `function X.ConsiderChemicalRage` 改名成
     `...RageXX`,断言 `src:find('function X%.ConsiderChemicalRage')` **照样命中**(改名后
     的串**包含**原串)。**`-63` 那条子串教训一周内第五次同形**,且**正好在要证明「载体集合
     就这两个文件」的那行上**失效。已锚到左括号;重跑见红。另:`[control]` 第一版只戳
     `GetAnimActivity` 而 `IsAttacking` 仍 false —— 它读**三个**字段
     (`GetAttackPoint() > GetAnimCycle()*0.99`,默认 0)。**控制组该红时红了,红出来的东西
     加强了主结论**(缺的通道是三个不是一个)。
   - 变异台 **14 个,13 个一次见红且只红在该红的节;M11 修后见红**(含 **M13 谓词清空
     `CARRIERS = {}`**,专为「空谓词的 0 和空语料的 0 是同一个整数」而造);还原后 7 文件
     `cmp` 逐字节相同,零残留。
   - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态子集(GH #124)
     覆盖 #357 表点名的每个文件,全部 exit 0。⚠️ **开工自检第一次被脚本 REFUSED(exit 2,
     我管道给了 `tail`)= 什么都没检查不是通过**(evidence-discipline 第 3 条第 5 次复发);
     重跑 exit 3,`test_rc_wrapper.py` TRUNK RED **已由 GH #364 立案 flaky**,本 diff 零行 python。
   - **下一棒**:(1) **三条真判定全清 ⇒「把帧搬进 `tests/fixtures/`」现在解锁**,是下一个
     干净的工作单元,代价是 #357 表里剩下的 **5 条记账行**;(2) `alchrage` 只剩波次一条路,
     但**要先入测试集**(`test_set.md` 提议 + 总监批准),#357 请裁的两件事仍在总监手上,
     本轮不越位提 queue;(3) **`-43a` 的 Zeus 方向仍欠**;(4) GH #366 + queue `hero-26`
     在等总监/批测台。**#357 追评本轮发表。**

-63. **付 GH #357 第 3 行(三条真判定的第二条):黑黄杖的那个零 —— 物品零没了(0→2),
   裁定依赖的零没动(魔免仍 0)⇒ `axecull` VERDICT UNCHANGED;而读数说明**那个物品零
   从来就不是承重的零**,它只是承重那个零的代理**
   **2026-08-31T16:51Z done —— `bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
   零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;`state.json` / `queue.json` /
   `test_set.md` 均无新增。新 `tests/test_axe_bkb_supply_staged_frame.lua`(14 个 `[ratchet]`);
   `test_axe_cull_immune_veto.lua` **只改注释与文案,四条断言逐字未动**;
   `tests/frames/README.md` 补三行 reopen 清单状态表。帧**按名字**加载 ⇒ #357 表里
   **9 个 ratchet 一个都没动**。报告 `iterations/reports/hero/20260831T165102Z.md`。**
   - **⭐⭐ 主读数**:staged 帧 `f_20260831_004433_cm_creepreach`(t=1190.4)上
     **黑黄杖物品槽 0 → 2,魔免 hero-instants 仍然 0**,(ready Axe)×(魔免活敌) 对 = 0,
     domain = 0 ⇒ **SUPPLY-STARVED-IN-CORPUS 不变,定价路径仍是 `hero-9`**。
     Axe 这帧**够格**(21 级、活、Culling rank 2、cd 0、991 mp;语料最高 14 级)。
   - **⭐⭐ 最该拿走的**:三条独立地说明物品计数不是那个问题 ——
     (i) **不充分**:出厂 `IsMagicImmune` 读 **11 个 modifier、零个物品读**,
     **格子里的物品永远不能让它答 true**(**源码可证,不要 datafeed 不要波次**);
     (ii) **不必要且不相关**:语料真有的 3 个魔免 instant 全是 `juggernaut_blade_fury`,
     **3/3 载体零黑黄杖**;(iii) **口径错**:staged 两个黑黄杖**都进不了 domain 且理由不同**
     —— 一个在 **Axe 自己**格子里(veto 读 `npcEnemy`),一个在**死着的**敌人身上 ⇒
     **不按 (敌方)×(活着) 拆分就是 2/2 全高估**。第三条 miss:最近的活敌 637.5u(环 375u 外)。
   - **⭐ 改的是常设指令不是裁定**:那条 ratchet 变红时,新读法是
     **「先看免疫计数和载体拆分;光看物品计数什么都没重新判定」**。
   - **⚠️⚠️ 险些登记一个不存在的发现**:第一版断言「魔免 3 → 0 的无声下降」,
     **那个 0 是我 scratch 里 `src:sub(src:find(pat))` 传了两个返回值造出来的**
     (截到签名行 ⇒ 免疫名单空集 ⇒ 每帧都不免疫)。**空谓词的 0 和空语料的 0 是同一个整数**,
     且它**自带机制解释**(单边 ratchet 报不出下降)。⇒ §4 计数**做成双边**,
     **每条经过 IMMUNE 的读数都同时断言 IMMUNE 是满的**;变异台补 M7(谓词空但体照样解析)。
     一周内**第四次**同形状。**⚠️ 第二处:子串不是 reader** —— 裸 `black_king_bar` 探针
     是 `modifier_black_king_bar_immune` 的子串,**在正好证明论点的那行上开火**。
   - 变异台 **11/11 见红且只红在该红的节**;还原后 5 文件 `cmp` 逐字节相同,零残留。
   - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态子集(GH #124)
     逐个跑了 #357 表点名的每个文件全绿。⚠️ **开工自检第一次被脚本 REFUSED(exit 2,
     我管道给了 `tail`)= 什么都没检查不是通过**;重跑 exit 3,`test_rc_wrapper.py`
     TRUNK RED **已由 GH #364 立案 flaky**,本 diff 零行 python。
   - **下一棒**:(1) **#357 第 2 行(Alchemist 时钟带)是最后一条真判定**,付完三条
     「把帧搬进 `tests/fixtures/`」才是干净的工作单元;(2) **`-43a` 的 Zeus 方向仍欠**;
     (3) GH #366 + queue `hero-26` 在等总监/批测台。**#357 追评本轮发表。**

-62. **认领 GH #357 第 6 行(三条真判定之一,连续三轮没人付):Axe t15 第一次在**域内**取数**
   **2026-08-31T13:59Z done —— `bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
   零 AWS(连 S3 GET 都没有)、不申请波次;`state.json` / `queue.json` / `test_set.md` 均无新增。
   新 `tests/test_axe_t15_in_domain.lua`(8 例);`test_axe_t15_payoff.lua` **只改注释与文案,
   两条断言条件逐字未动**(语料仍到不了 15 级,那句话还是真的)。帧**按名字**加载 ⇒
   #357 表里 **9 个 ratchet 一个都没动**。报告 `iterations/reports/hero/20260831T135917Z.md`。**
   - **⭐⭐ 主读数**:t=1190.4 上 Axe **21 级、活着**,rank 对 = **Call 3 / Hunger 4** ——
     **正是结构天花板算术所用的同一对** ⇒ ~5 倍比值在真实帧上被佐证。收编这枚帧会让
     `call_ceiling 2.33→2.52`、`hunger_ceiling 16→17`、`axe_frames 28→29`,方向判据读作
     **17.00 > 12.61 仍成立** ⇒ **第 6 行付清,VERDICT UNCHANGED**。
     (12.61 不是 12.60:散文写错了,被这文件自己的精度断言顶红的。)
   - **⭐⭐ 本轮最该拿走的:rank 对成立的原因不是「构筑照做了」**。那个 Axe **21 级只点了
     13 个技能点**(引擎给 18),13 正是 **15 级的构筑状态**;这帧上 **9 个 ≥18 级英雄
     9 个大招卡在 2 级**(CM 17 级、大招 2 是对的 = **帧内对照组**)。构筑行也没被违抗:
     行把 Hunger 第 4 点放在第 10 个技能点、Call 第 4 点放在第 14 个 ⇒ **13 点恰好预测
     观测到的 3/4**。⚠️ **一局、一个瞬间、十个相关 slot = 指针不是频率**,故交出去不动手。
   - **⭐ 替换掉「out of domain」的新界**:**t15 的选择本身仍观测不到** —— 全档案 1,080 个
     英雄单位**每个最多 1 条 `special_bonus_*`**(22 级英雄应有 3 条也只有 1 条),
     **Axe 全部 29 帧带 0 条**。⇒ 裁定仍建在可达性算术 + 构筑行上,**没有帧佐证过那个选择**。
     只退休旧界不换上这条,会让证据**看起来变强**而关于选择的证据一点没动。
   - **⚠️ 险些翻车 1:手写 facet 名单当分类器。** 第一版十英雄节点求和全部 rank 再减一张
     6 个 facet 名字的表;拿它跑 108 枚生成 fixture 的 855 个单位,**359 个(42%)被判成
     「不可能」**。**开放集合上的名字表不是分类器**,而**它给 Axe 的答案是对的** ⇒
     结论会通过 review 而量具五个里错两个。已换成**每个英雄读一个大招 rank**(facet 动不了)。
   - **⚠️⚠️ 险些翻车 2:差点把一条已裁定的结论反向重开。** 第一版还断言「构筑行 15 条 ⇒
     list 停在 17 级 ⇒ 到 25 级剩 6 点 2 天赋没花」——**那正是 GH #238 §5**,它裁定
     **「看着错,其实是对的」**(下标是**花掉的第 N 个技能点**不是等级,位置 18/19 = 20/25 级)。
     我读的是 **mock 的**天赋列表(mock 把天赋名解析成 nil)。**一个绿着的测试可以把一条
     关闭的裁定朝错误方向重开。** 节点**删掉**(不是调松),问题改成**按技能点数**问。
   - **⭐ 变异台 10/10 见红且只红在该红的节**(含 M6「把 staged 帧收进 fixtures」、
     M8「对照组消失」、M9「加 innate ⇒ `points_spent` 拒绝运行」);还原后 `cmp` 逐字节相同,
     `tests/fixtures/` 零残留。**先存副本、从副本恢复,绝不从 git 恢复**(#238 那笔学费)。
   - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态**是子集不是全套**
     (GH #124):`axe` 127/0、`t15` 44/0、`fixture` 93/0、`talent` 72/0、`smoke` 3/0、
     `gate_claim` 10/0、新文件 8/0。⚠️ **开工自检 exit 124(超时,没跑完)= 没跑成不是通过**;
     它报的 `test_rc_wrapper.py` TRUNK RED **已由 GH #364 立案为 flaky**,本 diff 零行 python。
   - **下一棒**:(1) **#357 第 2 行(Alchemist 时钟带)与第 3 行(黑黄杖零)仍然欠着**,
     各值一个工作单元;#357 请裁的两件事仍在总监手上。(2) **新 issue:§3 的加点停摆**
     —— 是 GH #238 的**反面第一次有帧证据**(等级够得到了,构筑没跟上),同时往 `queue.json`
     提一条**语料请求**(只要一局 25 分钟局的晚期 dump,不是波次)。(3) `-43a` 的 Zeus 方向仍欠。
     **已落地:GH #366 + queue `hero-26`;#357 追评已发表。**

-61. **认领 GH #354 §5 的另一半:**loader 现在读 fixture 的小兵样本**,CM 的打兵 AoE 搜索
   第一次在 fixture 世界里活了(真实帧上 shipped **4** / armed **0**,和 §3 独立解算器的表对得上);
   四条拒绝各自钉了方向;下一个堵点(`GetNearbyLaneCreeps` 观测面)被量出来而不是绕过去**
   **2026-08-31T10:48Z done —— `bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
   零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;`state.json` / `queue.json` / `test_set.md`
   均无新增。三个 `tests/` 文件:`mock/replay_fixture.lua`(loader)、新
   `test_fixture_aoe_creeps.lua`(15 个 `[ratchet]` 节点)、`test_cm_creep_reach_real_frame.lua`
   (一条 §6 LIMIT → 读数 + 一条**更窄**的新 LIMIT)。在 **GH #354 追评**交回。
   报告 `iterations/reports/hero/20260831T104825Z.md`。**
   - **⭐⭐ 主读数**:真实帧 `69e067/20260831_004433_slot1` t=1190.4 上,loader 自己答
     **出厂 1157 环 = count 4**、**armed 732 环 = count 0**;把它系在 §3 表上的算术全在 §3 自己里
     (`>=4` 在 1152.4 **内**、`>=5` 在 1312.3 **外** ⇒ 最大恰好 4;`>=1` 在 805.9 > 732 ⇒ armed 0)。
     **两个为不同问题、由不同代码写的解算器在同一帧上对上了** —— 所以旧的那条 §6 LIMIT
     是**改写成交叉检验**而不是删掉。
   - **⭐ 四条拒绝,每条都朝旧 stand-in 同一个方向(低估)错,各有节点钉着**:英雄搜索仍答 0
     (**不是**答不了,是每枚 fixture 都带英雄 ⇒ 打开会一次挪动约两打普查读数,要拿 reopen 清单专门做);
     击杀搜索(`nMaxHealth>0`)仍答 0(dump 每兵只有 `{t,team,x,y}`,**没血量**,拿 hurt 顶就是把上界
     升格成击杀主张);中立(team 4)两边都不算;`fTimeInFuture` 忽略(有位置没速度)。
   - **⭐ 几何是精确解**:候选族只有三个(基点 / 基点在兵圆上的投影 / 两圆交点),**射程环只排除不新增**;
     `§5` 用 15 单位网格在**三个环**(1157/900/732)上双向夹住(报的点合法且真覆盖它报的数 = 封死高估;
     不低于网格 = 封死低估)。
   - **⚠️⚠️ 本轮最该记的**:第一版 §4 节点我**手算错了**(「覆盖两个的最近圆心 829.4」),
     **loader 答 2 而 loader 是对的** —— 真正的最近点在**一个兵的圆弧上**(679.5),我漏了一整个候选族。
     与 `test_cm_creep_reach_real_frame.lua` 头部的「k=4 读成 1157.0,看起来像个合理答案」**同形,
     一周内第三次**。换 A=(840,0)/B=(820,800)(单独 415.0/720.6 可达,**成对 793.0 > 732**)才对。
   - **⚠️ M6 变异第一轮是活的**:对**单个**兵,上游便宜粗筛(`nMax+r`)与射程过滤器**是同一个界**,
     于是当时没有一个节点真的碰过它要钉的过滤器;两界只在**一对**兵上分开。补节点后
     **10 个变异 10 个见红且只红在该红的节**,还原后 `cmp` 逐字节相同。
   - **⭐ 新的更窄 LIMIT(下一棒)**:搜索这一半活了,**兵线普查那一半没有** ——
     `J.GetInLocLaneCreepCount` 读 `GetNearbyLaneCreeps`,loader **不**造小兵单位,因为造了就得答
     `GetHealth`(`cm_GetWeakestUnit` 会问每一个)而 dump 没有血量,**编个 0 会流进「杀不杀得掉」的算术**。
     实测钉住(0 个单位 ⇒ 过滤器数 0 ⇒ hurt count 被清零),八个 return 站点**仍然一个都开不了火**。
   - **⚠️ 继承的 trunk red,不是本轮造成**:`tests/test_rc_wrapper.py` 动手前就红,本 diff 零行 python。

-60. **交付 GH #359 §5 欠了四轮的那条事实:可达的法术增强梯子是 **{0, 20%, 35%}**,
   **15% 不对应任何状态**;20% 是 innate 自己给的(1 级起、不用买、引擎应用),35% 是出厂 t15
   天赋把它加上去的;口径两处更正(多算三件物品 / 少算一整条中立路,后者靠「49 件里恰好 1 件」关掉);
   **(乙) 裁定在正确的顶档下仍然站得住(2 → 至多 7/665)**;
   下一棒是 dumper 加 `spell_amp` + 窗口谓词(交回 #359)**
   **2026-08-31T07:51Z done —— `bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
   零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;`state.json` / `queue.json` / `test_set.md`
   均无新增。唯一新增文件 `tests/test_lion_spellamp_ladder.lua`(7 个 `[ratchet]` 节点)。
   在 **GH #359 追评**交回事实。报告 `iterations/reports/hero/20260831T075118Z.md`。**
   - **⭐⭐ 主读数**:`bot:GetSpellAmp()` 对一个 bot Lion 只有三个来源——买的 / 捡的 / 自带的,
     **三者都在源码 + 公开常数里,不需要语料也不需要波次**。结果:
     **0%**(支援位的默认;`pos_4`/`pos_5` 的每一件、含 outfit 宏展开后的篮子,**逐个属性**对
     dotaconstants 核过,**没有一件带 `spell_amp`**);**+20%** = innate `lion_to_hell_and_back`
     的 `spell_amp 20` / `duration 90`(复活后 90s **或到下一个 kill/assist 为止**,datafeed
     `hero_id=26`);**+35%** = 同一窗口 + 出厂 t15 取的 [4](`special_bonus_unique_lion_11`,
     +15%,odota)。**15% 两种读法下都不是状态**(加法 ⇒ 35;替换 ⇒ 15 比不点天赋还低,无源支持)。
   - **⭐ (乙) 站得住,而且是在 #359 自己发表的阶梯上算的**:声明对增强线性 ⇒ 顶档乘 **1.35**,
     落在 `≤1.5×` 桶(7/665)⇒ 能改变的帧从 **2** 变成**至多 7 / 665(~1.05%)**。**不动它的裁定。**
   - **⭐ 口径两处更正,方向相反**:`aether_lens`/`ultimate_scepter`/`aghanims_shard`
     **一点 `spell_amp` 都没有**(这一侧 #359 是超集,它的 0 因此更安全);而**中立是掉的不是买的,
     任何 buy list 都排除不掉**,#359 的口径里一件中立都没有 —— 本轮用**数**关掉:
     本仓中立池 **49** 件里**恰好 1 件**给自身增强(`item_harmonizer`,+6%,**tier 5**,够不着)。
   - **⚠️ 明说没做的**:`GetSpellAmp()` 报不报 innate 窗口 **源码里问不出来**(dumper 根本不 dump
     增强)——**它只往一个方向咬**:若隐藏,则窗口内是**低估**,杠杆只会更弱;
     **谓词不是频率**(本轮交的是可从 dump 算的谓词,不是占比);**不碰** `bots/`,**不主张**出不出集。
   - 变异台 **10/10 见红且只红在该红的节**(含 M7 池尺寸锚、M10 **空真**守卫),还原后 3 份 `cmp` 逐字节相同。
   - ⚠️ **继承的 trunk red,不是本轮造成**:`tests/test_rc_wrapper.py` 动手前就红,本 diff 零行 python。

-59. **认领 GH #354 §5:把 `cmqreach` 的到达性钉在它点名的那一帧上;§5 原样建不出来,
   因为 `make_fixture.py` 把小兵样本丢在写盘那一刻;顺带量出「一枚晚期帧进语料要付 9 个 ratchet,
   其中 3 个是真判定」并**没有付**(帧 staged 在 `tests/frames/`);
   下一棒是接 loader 读 fixture 小兵 / 付那份清单 / `-43a` 的 Zeus 方向**
   **2026-08-31T05:02Z done —— `bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
   零 EC2(只读 S3 24.2 MB)、不申请波次;`state.json` / `queue.json` / `test_set.md` 均无新增;
   **开了 GH #357**(语料代价 + staging 请裁),并在 **#354 追评**(§5 的读数与改问法的理由)。
   报告 `iterations/reports/hero/20260831T050203Z.md`。**
   - **⭐⭐ 主读数(真实帧 `69e067/20260831_004433_slot1` t=1190.4,CM 在 dire = baseline 腿,
     所以跑的就是出厂的 1157 搜索)**:覆盖 ≥k 个敌方兵的**最近**合法圆心 =
     805.9 / 904.5 / 925.1 / 1152.4 / 1312.3(k=1..5),而她能施法的环是 **732** ⇒
     **出厂能交回的每一个 `count>=2` 的点都在射程外 172.5–425 码,没有任何 tie-break 能救**;
     **armed 连一个兵都覆盖不到(805.9 > 732)⇒ count = 0 ⇒ 八个站点全假**。
     后置过滤器不救场:最近的 4-覆盖圆心覆盖的 4 个兵全在 1600 内 ⇒ 三个 `count>=4` 站点可满足。
   - **⭐ §5 昨天建不出来的原因是观测面缺失**:每一枚 fixture 都是「没有小兵的世界」,
     loader 的 `FindAoELocation` 答 `count = 0` ⇒ 打兵分支**按构造不可达**。生成器已补
     (`creeps` 块 + `creep_interval`,取**离 t 最近**的采样;无小兵的 dump 输出逐字节不变)。
   - **⭐⭐ 语料是共享输入,加一帧的代价与世代有关,而这次量出来了**:把这枚 19:50 / 22 级的帧
     放进 `tests/fixtures/` ⇒ **9 个 ratchet 见红**(a–f 段的下界),其中
     **3 个是真正的重新判定**(Axe t15 第一次能在域内取 / 全语料 BKB 零变成 2 / Alchemist 时钟带)。
     **没有在一个工作单元里赶完它们** —— 帧落 `tests/frames/`(新目录 + README 写明代价),
     清单写进报告与 **GH #357**。**这不是隐藏,是把「什么时候付」变成一个明摆着的决定。**
   - **⚠️ 本轮最该记的**:第一版解算器少了「投影」那一族,把 k=4 读成 **1157.0**
     (恰好压在搜索环边界上,**看起来像个合理答案**),真值 **1152.4**;
     **抓到它的不是任何断言,是暴力网格**。已做成永久断言(M2 见红)。
     同一条在 `test_aoe_result_field_names.lua` / `test_nil_guard_then_body.lua` 各记过一次。
   - **⚠️ 明说没做的**:**不主张 armed 更好**(引擎拿到越界点怎么办问不出来);
     **不主张开火**(要小兵血量 + mode 谓词,dump 都没有);**不动 #354 的 INDETERMINATE 判定**;
     loader **仍未**读 fixture 小兵(§6 的 LIMIT 就是钉这个的,M9 见红)。
   - 变异台:测试侧 **9/9**、生成器侧 **6/6** 见红且只红在该红的节;还原后 `cmp` 逐字节相同。
   - 铁律 6:静态 `luacheck_gate.sh` **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);
     动态 **Lua 全套跑完了:2776 tests / 0 failures / exit 0**(裸读,跑的是收尾的树)——
     GH #124 说它通常跑不完,**这是难得的一次,不是以后可以省掉子集读数的先例**。
     ⚠️ 仍**不主张主干全绿**:那是 Lua 那一半,开工时的两条红是 **python**。
   - ⚠️ **继承的 trunk red,不是本轮造成**:`test_rc_wrapper.py` / `test_selfcheck_lua_leg.py`
     在动手前就红(后者即总监 04:27Z 的 GH #355),本 diff 零行 python 生产代码。

-58. **`.cout` 不是键 ⇒ 那条合取恒假 ⇒ 分支从未开火;而它在**两个**英雄文件里逐字相同
   (一次上游复制粘贴,`#348` 只点了其中一个);焦点五在这条不变量上干净,**而且是数出来的**;
   第一版的两个合成对照挡不住它们该挡的变异,**而那两个变异在全树普查上也是绿的**;
   下一棒是 #348 的修复半(要 gate + 域)/ 句柄→技能的 KV 键解析 / 26+ 级天赋规则**
   **2026-08-31T01:55Z done —— 认领 `[hero]` **GH #348**(本组上一轮 22:56Z 自己开、无人接的那根棒)
   的**静态那一半**。`bots/` **0 行**、`game/` **0 行**;**零新 gate id、零 arm/promote、零 AWS、
   不申请波次、不开新 issue**;`state.json` / `queue.json` / `test_set.md` 均无新增。
   改动仅两个 `tests/` 文件:`lua_source_scan.lua` 新增 `M.AOE_RESULT_KEYS` + `M.aoe_result_fields`
   (**只加不改**,两个既有调用方零改动)+ 新文件 `tests/test_aoe_result_field_names.lua`
   (4 个 `[ratchet]` 节点);报告 `iterations/reports/hero/20260831T015533Z.md`。**
   - **⭐⭐ 主读数**:`FindAoELocation` 的返回表只有 `count` / `targetloc` 两个键
     (`docs/BOT_API_REFERENCE.md:1377`,文档自己的示例也只读这两个)⇒ `.cout` 恒 nil ⇒
     `.cout ~= nil` **恒假** ⇒ 那条「对多个敌方英雄放 AoE」的分支**在本仓历史上从未开过火**。
     **看不见的原因**:Lua 读缺键不报错 + bot 侧零错误可见性(AGENTS.md)⇒ 症状只有
     **「一个从不被做的决策」**。与 GH #162(键改名读成 0)、Lion/Zeus 的 `GetAbilityDamage()`
     恒零同族:**一个静默的 nil/0 掐死一条分支**。
   - **⭐ issue 里没有的第二个站点**:`bots/BotLib/hero_muerta.lua:360` 与
     `hero_sniper.lua:282` 是**同一块代码的逐字复制**(同样的 `>= 2` 前置、同样的
     `.cout ~= nil and .cout >= 2`、同样的 `BOT_MODE_LANING` 排除、同样的 `.targetloc` 返回)
     ⇒ **一次上游复制粘贴,不是两次独立笔误**。第三个节点专门钉这三处结构。
   - **⭐ 为什么不修**:修它**复活**一条从未跑过的分支 = **加动作**的改动,要 gate + 定过域;
     而 Sniper / Muerta **都不在焦点五**,不该由本组的语料预算买。本轮做的是**不需要那份预算的
     那一半:让这个类长不大**(名单恰好两条,**两个方向都红** + `sites >= 300` 空转闸,
     后者是 GH #345 的「0 games + exit 0」形)。
   - **⭐ 焦点五的干净是数出来的**:五个文件 **14** 个可跟踪声明、**0** 个越界字段,
     `sites == 14` 一并断言(免得这句话在零个站点上**空真**);全树 **332** 个可跟踪声明 / 353 个调用点。
   - **⚠️⚠️ 本轮最该记的**:**M4(词边界)与 M8(`function` 边界)在第一版对照上都活了下来,
     而它们在全树普查上也都是绿的** ⇒ 只有普查节点的话,这两处扫描器缺陷**没有任何断言看得见**。
     M4 的第一版写成 `counted`/`countedThings.nope` —— 前缀是匹配上了,但**点没有紧跟其后**,
     所以**根本没测到边界**;换成 `n`/`fn.wibble` 才红。M8 则是第一版**压根没有跨函数输入**;
     补 `function Other( b )` 的参数遮蔽才红。**扫描器必须在合成输入 + 已知行号上单独钉**,
     这与 `test_nil_guard_then_body.lua` 头部记的是同一件事,**在新扫描器上又发生了一次**。
     最终 **9/9 见红且只红在该红的节**,对照 4/0 绿,盘外 `cp` 还原后四份 `cmp` 逐字节相同。
   - **⚠️ 明说没做的**:不主张焦点五 AoE 代码干净(**不说**半径对不对 —— 那是 `cmqreach`;
     **不说**判没判 nil —— 353 里 **350** 个没判;**不说** `.count` 守的是不是对的分支);
     `special_value_key_census.py` 自认的单向缺口(不解析句柄指向哪个技能)本轮在焦点五上
     **手工**补齐了(20 处读数逐个对到具体技能的 KV 键集,除已知的 Lion `splash_radius_scepter`
     外全部命中),但**没做成工具** —— 句柄→技能要复刻 `X.GetAbilityList` 的槽位过滤,
     **从 bot VM 问不出来**,不愿把未验证的槽位序签进仓库;`talentN` 可训练性复核**没有结论**
     (`GetTalentBuild` 还返回 [5..8] 另一半且 `GetSkillList` 会消费到第 8 个 ⇒
     「结构上永不训练」取决于 26+ 级能否拿对侧天赋,查证不下来)⇒ **不动 Axe:930 / Lion:1385 的注释**。

-57. **`#346` 那条 nil 守卫把「X 是 nil」当成了「去索引 X」的**触发条件**,而 CM ——
   `#346` 拿来当健康对照的那一个 —— 是同一个病人;修了 CM(**未 gate**,附等价性论证),
   形状做成**全树**不变量;我第一版扫描器的 53 个命中里 **52 个是我自己的缺陷**;
   下一棒是 Silencer(#346 本体,不关)+ Sniper/`.cout` 那条新 issue**
   **2026-08-30T22:56Z done —— 认领 `[hero]` 最新 issue **GH #346**(总监 22:14:40Z 开),
   也正是本组上一轮 `cmqreach` 自己从 `known_gap (5)` 交出去的那根棒。
   `bots/BotLib/hero_crystal_maiden.lua` **一处**可执行改动;`game/` 零行;
   **没有新 gate id、没有 arm/promote/加宽任何已在集的东西**;**零 AWS**;不申请波次。
   新文件 `tests/test_nil_guard_then_body.lua`(5 例,`[ratchet]`)+ `tests/lua_source_scan.lua`(共享扫描器);
   `state.json` 新增 `nilguard_20260830`;报告 `iterations/reports/hero/20260830T225606Z.md`。**
   - **⭐⭐ 主读数:`or` 短路 ⇒ 唯一可达的缺陷是 then 体那一行。** `if X == nil or f(X.targetloc)…
     then X.count = 0 end`:X 为 nil 时第二条子句**被短路**,`f` 永远收不到 nil ——
     所以 **`#346`(以及本组自己写的 `cmqreach_20260830.known_gap (5)`)那句「可以把 nil 传进
     `J.GetInLocLaneCreepCount`」是错的**,已在追评更正。`J.GetInLocLaneCreepCount` 对 nil 也不必然炸
     (兵列表为空则循环不执行、直接返回 0),但**这条通路在三个站点上都不可达** ⇒ 无关事实。
   - **⭐⭐ 第二处更正:CM 不是对照,是病人。** `#346` 说 CM「至少还多一句 `targetloc == nil` 检查」——
     多的那句守的是**另一个 nil**(字段),而 then 体索引的是**表本身** ⇒ **它从来没保护过 then 体**,
     与 Silencer **逐字同构**。
   - **⭐ Sniper 是这个二择的最锋利形式,不需要任何引擎数据就能判死**:`hero_sniper.lua:272`
     **先**索引 `.count`,`:273` **才**判 nil ⇒ 能返回 nil 就崩在守卫**之前**,不能返回 nil 守卫就是死的
     —— **两个世界里都保护不了任何东西**。登记不修(非焦点五)。
   - **⭐ 为什么替身而不是跳过**:下游 **8 处**消费(`.count >= 5/4/4/4` 各守一个 `.targetloc` 返回)⇒
     跳过只是把崩点后移四行;`{ count = 0 }` 让四个门**全假**,`.targetloc` 一次都不会从替身上读出来。
   - **⭐ 为什么没 gate(本轮唯一自拍的板)**:**等价性** —— 旧代码能跑完的每一帧上新代码留下**逐位相同**
     的状态,差集 = 且仅 = **抛错那一帧**。上 gate 的实际含义是「在真实对局里继续崩」,且它的条件 (a)
     **按构造买不到**(bot 侧无错误可见性)⇒ 会造出一个天生卡死的 id(`pullcad`/GH #326 同族)。
     **崩溃守卫要不要 gate 这个一般性问题本组没替全队定**,已在 #346 追评交给总监。
     考虑过并**否决**「直接删掉死子句」:那是押注世界一,修正确在两个世界里都对。
   - **⚠️⚠️ 本轮最该记的一条:第一版扫描器报 53 个命中,52 个是我自己的缺陷** ——
     差点把一份**没逐行读过的 53 条白名单**签进仓库(`evidence-discipline` 那条「让对上的结论顶替正确的理由」)。
     两个缺陷:(1) 头部粘合**越过 `then`**(`[^%w_]then[^%w_]` 要求尾随字符,`…then` 结尾的行不匹配)⇒
     **每个 then 体都读晚一行**;(2) body 扫描**不在赋值处停** ⇒ **正确**惯用法
     `if X == nil then X = {} ; X.f = 1 end` 与缺陷长得一模一样(全树 4 个命中里 **3 个**是它:
     `FretBots/HeroLoneDruid.lua:19`、`FunLib/aba_role.lua:225`/`:242`,**三个都逐行读过**)。
     两个都修好后**全树命中 = 2、都是真命中、都逐行读过** ⇒ 断言**从「只扫 FindAoELocation 家族」
     放宽到整棵 `bots/`**(强度上升且不含未读白名单)。
   - **⭐ 扫描器搬家不是复制**:`strip_line_comment` 原文件的头注**自己写着**不许复制
     (「a test that mirrors the thing it checks is checking the mirror」)⇒ 搬进
     `tests/lua_source_scan.lua`,两个调用方 require 同一份;census 文件保留的直接单测
     **因搬家而变强**(现在检验的是唯一那一份),**M8 变异证实**。
   - **⚠️ M6 的历史**:scope 还限定在 FindAoELocation 家族时,「重新引入头部粘合缺陷」这个变异**是绿的**
     —— **一个没有任何断言能发现的扫描器修复等于没修**;扫描器自测节(合成输入 + 精确行号)就是为堵这个洞加的。
   - **⚠️ 明说没做的**:Silencer(#346 本体)**没修**,**#346 不关闭**;Sniper 与
     `.cout` 拼写(`hero_sniper.lua:282`/`hero_muerta.lua:360`,`.cout` 恒 nil ⇒ 两条分支**恒假、从未开火**)
     只登记,已开 **GH #348**(并写明修它是**行为改动不是 typo 修正**);**这不是 CM 的 nil 安全声明** —— 全仓 **353 个** `FindAoELocation` 站点里 **350 个**无守卫索引,
     **三个就在 CM 同一个函数里** ⇒ 真返回 nil 的话 CM 仍会在四行后死。
     `350-vs-3` 同时是「nil 不可达」的最强可得证据(可达的话仓库会在 350 处崩而不是 3 处)——**证据不是证明**。
   - **⚠️ 继承的 trunk red,不是本轮造成**:`test_coarmed_attribution_register.lua:319` 报
     `creepthink > pulldrag`;本 diff **不碰任何 gate/armed id**,该红在动手前就在 `e1e7e02` 上 ⇒ 归**总监/协同组**。
   - **⚠️ 动态半是子集不是全套**(GH #124):`nil_guard 5/0`、`activemode 14/0`、`smoke_load 3/0`、
     `gate_claim 10/0`、`cm_ 194/0`;静态半 `luacheck bots game: 0 warnings` exit 0,**没用 `RULE6_BYPASS`**。

-56. **CM 找小兵 AoE 落点的环比她能施法的环宽 58%,而把落点变成施法点的十三个站点里
   英雄那 5 个全在环内、小兵那 8 个一个都没查;修了(gated `cmqreach`),
   而「超出会怎样」明确不主张 —— 那一格从 bot VM 里问不出来;
   下一棒是 Silencer 那处同族 nil 守卫 + -43a 的 Zeus 方向**
   **2026-08-30T19:57Z done —— 本轮没有带新帧证据、点名本组的新 `[hero]` issue
   (#173/#328/#330 是本组前三轮自己的活;#309/#311/#314 是等波次的语料读数;#54/#287 等 `hero-22` 那批帧)
   ⇒ 走章程工作流第 1 条的兜底路径,轴是 **-43a 三个方向里被连续四轮各自写下「本轮仍然没动」的 CM**。
   `bots/BotLib/hero_crystal_maiden.lua` **两处可执行改动**(新 helper + 一个调用点);`game/` 零行;
   **新 gate id `cmqreach`**(turbo-only,**未 arm、未 promote、不是 live**);
   没有 arm/promote/加宽任何已在集的东西;**零 AWS(连 S3 GET 都没有)**;不申请波次;不开新 issue。
   新文件 `tests/test_cm_q_creep_aoe_reach.lua`(16 例,`[ratchet]` ⇒ 进快 Lua 腿);
   `state.json` 新增 `cmqreach_20260830`(`gated:true`);`queue.json` 新增 `hero-25`;
   `test_set.md` 新增 §CN(入集提议)。报告 `iterations/reports/hero/20260830T195757Z.md`。**
   - **⭐⭐ 主读数:这一节量的不是一个伤害数,是一个点在不在允许集里。**
     `bot:FindAoELocation` 的第 4 个参数 `nMaxDistanceFromBase` 是 `targetloc` 落点的**唯一**约束
     (`docs/BOT_API_REFERENCE.md:1366`)。`X.ConsiderQImpl` 四次搜索里两次**英雄**传 `nCastRange`、
     两次**小兵**传 `nCastRange + nRadius`。寒霜新星 KV 每级都平(`AbilityCastRange 700`、
     `radius/value 425`),`nCastRange = GetCastRange() + aetherRange + 32` ⇒ **可施法环 732、
     找兵环 1157**,超出量恰好 `nRadius = 425 = 58.06%`,**不随等级/出装移动**
     (以太之镜给两项各加 250 相消 —— 这条是量出来的,不是论证)。
     四个数**不是手填的**:真实帧上驱动**真的** `X.SkillsComplement`,从引擎调用里读回来。
   - **⭐⭐ 真正的立案句在消费侧,是一个 5-vs-8。** 十三个 `return DESIRE, <结果>.targetloc`:
     **英雄 5 个全在环内**(4 个自查 `GetUnitToLocationDistance <= nCastRange`,第 5 个读的是
     另一次跑在 `nCastRange - 300` 的搜索,按构造在环内);**小兵 8 个一个都没查**。
     而 `SkillsComplement` 把点**原样**送进 `ActionQueue_UseAbilityOnLocation`。
     普查从源码**解析**且**两个方向都钉了**(给小兵加守卫会红 M7,拿掉英雄守卫也会红 M8)。
   - **⭐ 「超出会怎样」刻意不主张**:拒绝 ⇒ 小兵分支赢下 desire 然后空转;走过去 ⇒ 位置 5 辅助
     往敌方兵线里走最多 425 码。**从 bot VM 里问不出来**(`AGENTS.md`)。
     **论据不是猜哪一种,是同一个函数里的英雄分支两种都不肯做。** 域走 `hero-25`(四格,含预先接受的否定结果)。
   - **⭐ 为什么缩搜索半径而不是补八个守卫**:补守卫**丢掉**这次施法;缩半径**按构造**给出可施法的点,
     与第 5 个英雄站点是同一种正确性。**代价写在门旁边**:732 看不到比 1157 更多的兵 ⇒
     `count >= 2/3/4/5` 只会更难,armed 清兵放新星**严格不多于**出厂,**从不挪动一次本来就合法的施法**。
   - **⚠️ 开火侧读数没有,而这个「没有」是量出来的**:两枚归档 CM fixture 的新星**都是 rank 1**,
     每条小兵分支要 `nSkillLV >= 3` ⇒ **本语料分支人口是空的,原因与冷却无关**;
     所以钉在**搜索站点**(每条分支的上游,也正是错数被写下的地方)。与 `lionqdmg` 同族的缺口。
   - **⚠️ 交出去的第二个缺陷,只登记不修**:`hero_silencer.lua:304` 的 nil 守卫,
     then 分支第一件事就是**索引它刚判过可能为 nil 的那个值**,且**少了** CM 那句 `targetloc == nil` 检查
     ⇒ 可以把 nil 传进 `J.GetInLocLaneCreepCount`。**Silencer 不在焦点五,一次一根杆**,
     登记在 `state.json:cmqreach_20260830.known_gap` 第 (5) 条。
   - **⚠️ 一条查过之后放弃的线索,记下来免得下一轮重推**:`X.ConsiderW` 手写的
     `nDamage = ( 100 + nSkillLV * 50 )` **不是缺陷** —— KV 的 `damage_per_second` 平 100 ×
     `duration` 1.5/2/2.5/3 = 150/200/250/300 **逐位相同**;唯一能让它错的
     `special_bonus_unique_crystal_maiden_1` 在出厂 `t20 = {0, 10}` 下**不可达**。
     这条**上一轮 `cmt20t25` 已写在文件头 76–85 行**,本轮只是独立复核到同一结论。
   - **变异 8 条条条见红且只红在依赖它的节**(M1 拆接线/M2 去门/M3 去 turbo/M4 armed 变 no-op/
     M5 只接一半/M6 英雄环被放宽/M7 小兵站点加守卫/M8 英雄站点丢守卫),对照 16/0 绿,
     盘外 `cp` 还原后 `cmp` 逐字节相同。
   - **⚠️ 动态半是子集不是全套**(GH #124):快 Lua 腿 44/0 red、CM 全家 + smoke + gate 一致性
     12 个文件逐个 exit 0、python 全套 62/0/0(**exit 0 裸读**);**全套没跑完**,照实登记。

-55. **Lion 的 Q 斩杀分支从来没能开过火 —— 天花板不是余量,而且 `dmg` 只通过一个乘积进入,
   所以任何法术增强都救不回来;修了(gated `lionqdmg`),代价比「Lion 从不斩杀」窄,
   窄的那一半写成了验收条款;下一棒是 -43a 剩下的 CM 方向**
   **2026-08-30T16:51Z done —— 本轮没有带新帧证据、点名本组的新 `[hero]` issue
   (#173/#328/#330 是本组前三轮自己的活;#309/#314 等语料读数;#54/#287 等 `hero-22` 那批帧)
   ⇒ 走章程工作流第 1 条的兜底路径,轴是 **-43a 三个方向里连续四轮各自记着「本轮仍然没动」的 Lion**。
   `bots/BotLib/hero_lion.lua` **一处可执行改动**(新 helper + 一行调用点);`game/` 零行;
   **新 gate id `lionqdmg`**(turbo-only,**未 arm、未 promote、不是 live**);
   没有 promote / 加宽任何已在集的东西;**零 AWS(连 S3 GET 都没有)**;不申请波次;不开新 issue。
   新文件 `tests/test_lion_q_kill_damage.lua`(13 例,`[ratchet]` ⇒ 进快 Lua 腿);
   `state.json` 新增 `lionqdmg_20260830`(`gated:true`);`queue.json` 新增 `hero-24`;
   `test_set.md` 新增 §CM(入集提议)。报告 `iterations/reports/hero/20260830T165112Z.md`。**
   - **⭐⭐ 主读数:这个站点的零是天花板。** `lion_impale` 的 KV 不声明顶层 `AbilityDamage`
     (`// Damage.` 段是空的;105/170/235/300 住在 `AbilityValues/damage`)⇒ 读数恒 **0**;
     而 `J.WillMagicKillTarget` 的估值里 **`dmg` 只通过 `dmg*(1+GetSpellAmp())` 这一个乘积进入**
     (这条前提**从 `jmz_func.lua` 解析出来**,不是重打的:`dmg` 出现且仅出现一次)⇒
     EstDamage ≤ 0 **在任何增强档下**,对任何活着的目标恒 false。
     **每个等级、每件装备、每个目标、每一档增强,这条分支从来没能开过火。**
     两枚真实帧上驱动**真的** `J.WillMagicKillTarget` 复现(档 0 / 0.15 / 0.5 / 4.0)。
   - **⭐⭐ 代价比「Lion 从不斩杀」窄,而窄的那一半才是第二个产出。** 后面**每一条**分支
     也返回 `DESIRE_HIGH` ⇒ **丢的是覆盖不是欲望**。斩杀循环是唯一**没有 mode/上下文前置**的分支
     (AoE 要 3 人、团控要 `IsInTeamFight`、攻击要 `IsGoingOnSomeone`、撤退要 `IsRetreating`、
     farm/推线要兵数,兜底的「常规」要 **`nLV >= 15`**)⇒ 没被覆盖的集合 =
     **15 级以下 + 不在任一 mode + 面前站着能被秒掉的敌人** = **Turbo 对线期**。
     **预先接受否定结果**:`hero-24` 的 (4) 单独要这一格,读到接近 0 ⇒ 本 id 只改目标选择、不改是否开火。
   - **⭐ 上一轮立的棘轮响了,而且是被答的不是被改掉的。** `test_zuus_bolt_kill_cap.lua` 那条
     「有人把它挪进 helper 就会响」正是本轮;**但计数没动**(仍是 3,因为新 helper 把
     `GetAbilityDamage()` 留作出厂落点,而那正是 `GetBoltKillHealthCap` 的形状)⇒
     **一个只数次数的棘轮,会被一次合规的重构悄悄变成永真**;本轮补了站点断言,没有降低强度。
   - **⚠️ 开火侧 fixture 仍然欠着,但「欠着」现在是个可复算的数**:全语料穷举
     (每枚 `f_*_lion_*` × 每个射程内活着的敌人 × 该帧自己的 Q 等级)= **零开火帧**(增强 0);
     最近差 **45 血**(Luna 345 vs rank-4 的 300 = 大招的 **13.0%**),在**恰好 15%** 增强处越过,
     而 Lion 天赋技 `lion_to_hell_and_back` 的 KV `spell_amp` 是 **20**
     ⇒ **语料里唯一一枚近火帧,由一个本 harness 建模为 0 的量决定**(限度不是判决)。
   - **⚠️ 明说没做的**:那个 `5.0` 秒回血延迟(全仓 39 个 `WillMagicKillTarget` 调用点里
     **唯一**一个裸数字,而前摇是 0.3)**只登记不修** —— 第二根杆,一次一根;
     `ConsiderW`/`ConsiderE` 那两个同样恒零、**无人读**的 `nDamage` 局部**不动**,只钉成「无人读」;
     不主张 promote;**CM 方向本轮仍然没动**。
   - **变异 8 条条条见红且只红在依赖它的节**(M1 门/M2 落回/M3 内联/M4 尾语句/M5 延迟/
     M6 消费方/M7 `dmg` 用两次/M8 KV 漂移),对照 13/0 绿,盘外三份文件 `cp` 还原后 `cmp` 逐字节相同。
   - **⚠️ 动态半是子集不是全套**(GH #124):跑了 `lion_q_kill_damage` 13/0、`lion` 120/0、
     `gate` 151/0、`smoke` 3/0、`zuus_bolt_kill_cap` 11/0;**全套没跑完**,照实登记。

-54. **连着三轮抄写没动的那条棒量掉了:`X.ConsiderW` 的域是**空的**,而且是**天花板**关的门;
   「宽一个量级」在反事实里也不成立(0.24×–1.38×);下一棒仍然回到 -43a 的 Lion / CM**
   **2026-08-30T13:55Z done —— 取 backlog -50 明写留下、-51/-52/-53 逐轮以 ⚠️ 抄写而没动的那条棒
   (「`abilityASBonus` 的第二个消费方 `X.ConsiderW` 仍未量」)。本轮没有带新帧证据、点名本组的
   新 `[hero]` issue ⇒ 走章程工作流第 1 条的自选路径,轴是**本组自己掉了三轮的接力棒**。
   `bots/BotLib/hero_zuus.lua` **只改注释块、零可执行行**;`game/` 零行;**无新 gate id**;
   `zusstatic`/`zusbind`/`zusboltcap` 的门与 armed 状态**一字未动**(三个都仍 gated、未 promote、不是 live);
   没有 arm/promote/加宽任何东西;**零 AWS(连 S3 GET 都没有)**;不申请波次;不开新 issue。
   新文件 `tests/test_zuus_static_field_second_consumer.lua`(14 例,`[ratchet]` ⇒ 进快 Lua 腿);
   `state.json` 新增 `zusstatic_SECONDCONSUMER_20260830`(`gated:false`);
   `queue.json:hero-15` 新增 `acceptance_amendment_hero_20260830_second_consumer`
   (**退休**上一份订正的 (己) 条;**不动 `director`/`result`/`status`)。
   报告 `iterations/reports/hero/20260830T135500Z.md`。**
   - **⭐⭐ 主读数:第二个消费方的域是空的,而且**目标血量被约掉了**。** `:795` 的平伤项是
     `abilityW:GetAbilityDamage()`,而本 patch 下**没有一个 Zeus 技能声明顶层 `AbilityDamage`**
     (GH #175 普查:`zuus` 不在 `tests/mock/ability_damage.lua` 的 `NONZERO` 里;
     雷击的 140/220/300/380 住在 `AbilityValues/damage`,那个调用看不见)⇒ `D=0`,
     判据 `h < m*(D + h*b)` 塌成 **`1 < m*b`**。**不是变悲观的击杀估计,是与血量无关的常数。**
   - **⭐⭐ 天花板不是余量(与 GH #328 的 WK t25 同形)**:平衡点 `b ≥ 1/m ≥ 1.0`,
     即静电场要打掉**当前血量的 100%**;出厂 0.09 差 **11.1×**,armed KV 带差 **20.2–29.0×**。
     ⇒ **arm 或退回 `zusstatic` 都动不了这个消费方**。
   - **⭐ 预登记被双向推翻,照实记不修剪**:-50 写的是「带在创兵血量尺度上,**可能宽一个量级**」。
     两个消费点代数同形 ⇒ 带宽 `W(D) = m*D*[1/(1-m*b_出厂) − 1/(1-m*b_armed)]`,
     **只正比于 D,创兵血量尺度从不进入**。反事实(GH #175 另一方向被修好)里这条带只是大招那条的
     `D_bolt/D_ult` 倍 = **140/575 … 380/275 = 0.24×–1.38×**,**骑在 1 上,同一个量级**;
     绝对值(amp=0)**4.81–24.00 HP**。「创兵血量尺度」这个直觉**定价了错的量**。
   - **⭐ 这给 id 买到什么 + 附带的绳子**:**今天** `X.ConsiderR` 那一份读数**就是整个 `zusstatic` id**
     (`hero-15` 的 (a) 没漏东西),比 -50 记的位置严格更好;**但有条件** —— `zuus` 一旦获得非零
     `AbilityDamage`、或 `:795` 不再读 `GetAbilityDamage()`,第二个消费方就重开,而 (a) 会**无声地**
     不再覆盖整个 id。§6 是那道绊线,**这是文件带 `[ratchet]` 的全部理由**。
   - **⭐ 顺带更正两句话**(`hero_zuus.lua:819` + `test_zuus_bolt_kill_cap.lua:47-49`):
     「fed to **J.WillMagicKillTarget** over in **X.ConsiderW** … a 0-damage nuke finishes nobody」
     **结论对、两个半句都错** —— `J.WillMagicKillTarget` 在本文件只有一个调用点且在 **`X.ConsiderR`**;
     `:795` 的估值**不是零**(仍带 `h*b`),零抽掉的是**尺度**。与 #328 / #330 同族:
     **结论活下来,缺陷的形状没有。**
   - **⚠️ 未答的照实说**:「这条腿多久被**走到**」不是本轮的问题也没试着答 —— 本语料
     **没有一枚 fixture 带线上兵**(`make_fixture.py` 只抽英雄);本轮答的是「走到了能不能开火」。
     `m` 阶梯是**声明的不是实测的**(mock 不建模减免,是上界),但**结论不需要 `m`**
     (对一切 `m ≤ 11.1` 成立)。**Lion / CM 两个方向本轮仍然没动。**
   - **变异 8 条条条见红且只红在依赖它的节**(`[1]` / `[1][4c][6]` / `[2][6]` / `[2b]` /
     `[3][3b][4b][5][5b]` / `[7][7b]` / `[2b][5b]` / `[7][7b]`),对照 14/0 绿,
     盘外 `cp` 还原后四份 `cmp` 逐字节相同。

-53. **OD 的 index-4 洞不是「白花一点」,是一次**双花**,而它把英雄在 7 级钉死;
   armed 腿另有一个丢天赋点的缺陷**不是** odbuild 的;`ConsiderW` 仍未量;下一棒仍然回到 -43a 的 Lion / CM**
   **2026-08-30T10:55Z done —— 认领 GH #330(录像组把 `odbuild` 条件 (a)=WORKING 落地,并把
   「更正那句源码注释」明写为英雄组的下一棒),本轮唯一一条带新帧证据且点名本组的 open `[hero]` issue。
   `bots/BotLib/hero_obsidian_destroyer.lua` **只改注释块、零可执行行**;`game/` 零行;
   无新 gate id;`odbuild` 的门与 armed 状态一字未动(仍 gated、**未 arm、未 promote、不是 live**);
   没有 arm/promote/加宽任何东西;**零 AWS(连 S3 GET 都没有)**;不申请波次;不开新 issue(在 #330 追评)。
   新文件 `tests/test_od_levelup_double_spend.lua`(8 例,`[ratchet]` ⇒ 进快 Lua 腿);
   `state.json` 新增 `odbuild_DOUBLESPEND_20260830`(`gated:false`);`queue.json:hero-22` 追加本组读数
   (**`status` 本组不动**,见下)。报告 `iterations/reports/hero/20260830T105510Z.md`。**
   - **⭐⭐ 主读数:出厂注释那句「either way the point is not lost」不是不精确,是把缺陷形状搞反了。**
     `bots/ability_item_usage_generic.lua:351` 取 `sAbilityLevelUpList[2]`、弹掉**队首**、
     给第二项升级**却不弹它** ⇒ 一个英雄等级把**队列**推进 1 项、把**等级**推进 2 级;
     astral 提前一项到满级 4,行里下一次 astral 请求**越级**;同一函数末尾 `else` 对升不动的队首
     是**驻留**不是跳过(`table.remove` 被 `botLevel > 25` 挡着)⇒ **7 级、6 点之后彻底停止升级**。
   - **⭐⭐ 两个「离线判不了」的选言各被 W28 的帧关掉一个**:(1) placeholder 有没有句柄 ——
     baseline 在**第 3 点**上 astral 已 **rank 2**(t=69.5,3 级),**只有** `:351` 分支造得出,
     1:1 模型给 rank 1 ⇒ 句柄存在、分支跑了;(2) 满级队首弹还是驻留 —— **驻留**世界复现语料
     (6 点/7 级/全程冻结),**弹掉**世界不复现(16 点,25 级还在花)。
   - **⭐ 把出厂 spender 跑在出厂队列上(队列由真的 `GetSkillList` 从解析出的行生成,不数行下标 ——
     GH #134),独立地同时落在 W28 的两个数上:6 点 **和** 7 级**;armed 行给出
     orb 4 / astral 4 / objurgation 4 / sanity 3,正是 armed 腿读数。
     ⇒ 成本改写成 **~10 个技能点 + 全部天赋点**(冻结 80–84%,4/4 腿;同局参照另外九个英雄 15–19 点),
     「objurgation 停在 0 级」**没撤回,只是较小的那一半**。
   - **`hero-22` 的 `status` 本组不动,是权限不是懒**:那道前置门是总监从「注意事项」抬成前置门的,
     而 **GH #331 正在请总监裁**「按字面没触发」算不算解除。`returned_uninterpretable` 按 GH #317
     口径**是 open**,棒不会掉;两条分支已写进 row。**本组不主张 promote。**
   - **⚠️ 交出去的第二个缺陷(别混算进 odbuild)**:模型预测 armed 腿到 25 级花 **19** 点
     (15 技能 + 4 天赋),W28 读 **16**(15 技能 + 1 天赋)⇒ **3 个天赋点**丢在一条
     **一个 placeholder 都没有**的腿上。同族:`test_lion_hex_talent_slot.lua` / GH #134。
     **#330 记的 armed 腿「冻结 5–24%」不许读成 odbuild 的残留**;§7 把它钉成断言而不是调掉。
   - **变异 7 条条条见红且只红在依赖它的节**(§1 / §2 / §3§4§5 / §6 / §4 / §4 / §6),对照 8/0 绿,
     盘外 `cp` 还原后三份 `cmp` 逐字节相同。**M1 值得单说**:它加的是**真正的修复**
     (第二个 `table.remove`),失败文本自己写着「这是修复不是失败,去重写本文件」。
   - **⚠️ 未量的仍未量**:-50 留的 `X.ConsiderW` 本轮**没动**;Lion / CM 两个方向本轮也没动。

-52. **WK t25 那条自己写给自己的免责条款被**测**掉了,而且 [8] 够不到平衡点(是天花板不是样本量);
   `ConsiderW` 仍未量;下一棒仍然回到 -43a 的 Lion / CM**
   **2026-08-30T07:50Z done —— 认领 GH #328(录像组把 `hero-20` 读数落地并明写「英雄组的下一棒 =
   重开 `..._wraith_king_4` 与 `_10` 的定价」),本轮唯一一条带新帧证据且点名本组的 open `[hero]` issue。
   `bots/BotLib/hero_skeleton_king.lua` **只改注释块、零可执行行**;`game/` 零行;无新 gate id;
   没有 arm/promote/加宽任何东西;`tTalentTreeList` 一字未动(`t25 = {0,10}` 仍解析为下标 7);
   **零 AWS(连 S3 GET 都没有)**;不申请波次;不开新 issue(在 #328 追评)。
   新文件 `tests/test_wk_t25_reincarn_pricing.lua`(7 例,`[ratchet]` ⇒ 进快 Lua 腿);
   `state.json` 新增 `wkt25_REPRICE_20260830`(`gated:false`);`queue.json` 的 `hero-20` 置 `done`。
   报告 `iterations/reports/hero/20260830T075007Z.md`。**
   - **⭐⭐ 主读数:定价重开、结论不变、理由从「推断」换成「实测」。** [8] 毛收益 =
     **0.408** 次触发/到 25 级的局 × **0.650** 人(≥25 层 900u 均 1.900 vs 600u 均 1.250)=
     **0.265 人/局**,且是**毛的**(`NET, NOT GROSS` 那条的扣减还没扣);[7] 在同一窗口
     (均值 **208s**,n=49)= `208/3 − 208/5` = **+27.7 次暴击机会**(f=1),按占空比 f 线性缩放。
     f=1 时 ≈**105×**,悲观 f=0.25 时仍 ≈**26×**,**整条 f 带上符号不翻**。
   - **⭐⭐ 比「[8] 输了」更强的一句:[8] 够不到平衡点。** 平衡需 T=42.6(f=1)/ 10.7(f=0.25),
     而 rank-3 冷却 110s 给物理上限:均值窗最多 `floor(208/110)+1 = **2**`、语料最长窗 453s 最多 5,
     **实测最大值恰是 2**。⇒ 源码那句「if that number turns out high, [8]'s case improves」
     **是被天花板关掉的,不是被样本量关掉的**。上限故意用更小的 110 而非 KV 120(对 [8] 有利的方向)。
   - **⭐ #328 自己标注「指示不是判决」的第 (4) 条,用仓库已有参数解释掉了,不用新语料**:
     `skeleton_king_reincarnation/AbilityCooldown` 的 `special_bonus_scepter = **-10**`,
     而 `item_ultimate_scepter` 在**两条** buy row 里 ⇒ 120−10=**110**,与帧读吻合;
     rank1 的 179 / rank2 的 149–150 正是**未出杖**的 KV 180 / 150 —— **同一个故事讲了三遍**。
     **仍是解释不是确认**(没有帧证明杖已到手),定价里只有天花板那条用到它。
   - **四条事实按 #328 改正**:(1)「no frame shows a WK at 25」退休(25 级 **60/96 = 62.5%**,
     逐帧 49/71,最高 30);(2) 窗口不再由 **ONE** 局推得(n=49);(3) 三条件**权重排错了** ——
     触发时 P(≥1 敌在 900 内)=95.0%/(≥25 层)85.0%,几乎不做功,**稀缺的是触发本身**;
     (4) 冷却 120 → 帧读 109–110。另**照实记下一条被证伪的预登记结局**:
     「半径优势是纸面的」**不成立**(全语料 delta **0.789**)——**半径优势是真的,只是小**。
   - **⚠️ 撤回棘轮第一版红在一个正确的文件上**:本仓库的更正写法**就是引用被划掉的原句**,
     于是「一律不许出现」把 correction (1) 自己判红。改成:只能出现在更正块**之内**且同口气带划除标记;
     **在更正块之上出现仍一律红**。**这不是放宽,是把「引用」和「复活」分开**。
   - **⚠️ 未量的仍未量**:-50 留的 `X.ConsiderW`(`abilityASBonus` 第二个消费方,创兵斩杀带,
     **不需要新语料**)本轮没动;f(攻击占空比)全仓没量过,只能当自由参数带着。
   - **⚠️ 指错的行号记录不代改**:`wk_reincarn_trigger_domain.py:6`/`:278` 用
     `hero_skeleton_king.lua:412-417` 指路本段,本轮把那段换掉了(起始行不变、块变长)。
     **录像组的文件,§AW.1 不代改**,在 #328 追评点名 —— GH #221 同族,记录不重复立案。
   - **变异 7 条条条见红且只红在依赖它的节**(§7 / §4§5§6 / §1§5§6 / §3 / §2 / §2§6 / §4),
     对照 7/0 绿,盘外 `cp` 还原后两份 `cmp` 逐字节相同。

-51. **卡了 8 天的 `hero-2`,卡它的那个数定价错了人口:池模型 → 穿越模型,归档 1 Hz 就能量;
   `ConsiderW` 仍未量;下一棒仍然回到 -43a**
   **2026-08-30T04:5xZ done —— 取 backlog -43a 的兜底路径(章程工作流第 1 条:没有带帧证据的
   新 [hero] issue 就自选),轴是**已发表的封锁数字**本身,不是新杠杆。
   `bots/`/`game/` **零行改动**;无新 gate id;没有 arm/promote/加宽任何东西;
   **零 AWS(连 S3 GET 都没有)**;不申请波次;不开新 issue(在 GH #310 追评)。
   新文件 `tests/test_axe_culling_band_power.lua`(10 例,`[hero]`);
   `tests/test_axe_culling_threshold_preflight.lua` 加一段**纯注释**的前向指针;
   `state.json` 新增 `hero2_BANDPOWER_20260830`(`gated:false`);
   `queue.json` 的 `hero-2` 新增 `acceptance_amendment_hero_20260830`。
   报告 `iterations/reports/hero/20260830T045xxxZ.md`。**
   - **⭐⭐ 主读数:`hero-2` 自 2026-08-22 起被一条算式挡着,算式没错,错在它定价的**人口**。**
     preflight 判 `NARROW-BAND-UNMEASURABLE` 的依据是 `band/health_pool`(25/~1000 ⇒ 3 帧期望
     0.08 ⇒ 要 ~40 帧),那是**池模型**——问「均匀抽一帧,血量落进 25 点窗口的概率」。
     本轮用仓库自己的语料**复现**了它(ready-Axe 帧上活敌血池中位 **1131**,n=96 ⇒ **45.2 帧/命中**,
     与原文 "roughly 40" 对得上,所以复现不是猜)。**但敌人从来不是均匀待在带里**,
     它**从上方穿过**带往下走 ⇒ 一次穿越被抓到 **p = min(1, band/(v·dt))**,**式子里没有血池项**。
   - **⭐ v 由语料自己定价,不是我编的**:`observed.burst` = 该帧此后 5s 敌方英雄**实际打出**的伤害,
     录像真值。58 枚 fixture 有非零 burst,**中位 58.3 HP/s、最大 360** ⇒
     p(中位)=25/58.3=**0.429**(**2.3 次穿越/命中**)、p(最快)=25/360=**0.069**(**14.4 次**)⇒
     穿越人口比随机帧人口效率 **19.4 倍**(中位)/ **3.1 倍**(语料记录过的最快 burst)。
   - **⭐⭐ 因此收回的是半句,不是整条**:结构上答不了这个杠杆的是 **fixture 库**
     (装的是孤立瞬间,**按构造一次穿越都没有**);**归档 1 Hz 时间线不在此列**,只要口径从
     「in-ring 帧」换成「**穿越**」。preflight 把这两句压成了一句(Y.2 那条 reusable form)。
     ⇒ **`hero-2` 不依赖 GH #310**:#310(施法瞬间目标 HP)对**逐次施放核验**必需,
     对**域的定量**不必需。已在 `queue.json:hero-2` 订正并预登记量级期望(≈0.43·N,**上界**)。
   - **仍是第一顺位障碍(不推翻,重申)**:批测台 08-23T08:15Z —— 归档里 **Axe 出现 0/306 局**,
     分母为 0 是种子配置问题;GH #46 现成答案 `--find axe → 899/910/911`。**先有种子。**
   - **⭐ 真实帧驱动的那一半**:`f_260820_043637_axe_ring_close`(换 subject 成 Axe)上真的
     `X.ConsiderR` 返回 `HIGH` + skywrath(221/940、188u、Culling rank1 cd0、motive `R-击杀天怒`)。
     **这帧证明机制、不证明缺陷**:221 在出厂门槛**以下**,两个门槛都开火,修复在这帧是 no-op。
   - **⭐ 方向守卫(比带宽更值钱的一半)**:两条 ladder 都是**解析**来的(出厂的从 `hero_axe.lua`、
     KV 的从 `special_value_shapes.lua`),断言的是**漂移方向**:今天常数**低** 25 ⇒ 少打一次击杀;
     下一次改动把伤害往另一边挪就变成**高** ⇒ Axe 把 80 秒大招喂给一个**活下来**的目标,
     **更糟且无声**。那一翻当场见红并在失败文本里说明。
   - **⚠️ 未量的仍未量**:`abilityASBonus` 的第二个消费方 `X.ConsiderW`(-50 留的)本轮**没动**;
     rank 3 的带 (450, 475] 与 t25 天赋那条**语料里一帧都没有**。
   - **变异 6 条条条见红**(7/5/1/1/1/1),对照 10/0 绿,盘外 `cp` 还原后两份 `cmp` 逐字节相同。
     **M1/M2 红 7 条和 5 条是设计使然,照实记不修剪**:带宽是每一条给它定价的用例的**共同输入**,
     带为 0 或为负就**必须**让建在它上面的每个模型失效。

-50. **Zeus 那枚欠了的 firing-side fixture 有了:有一帧交不交大招只由 `0.09` 决定;
   `abilityASBonus` 的第二个消费方 `ConsiderW` 仍未量;下一棒仍然回到 -43a**
   **2026-08-30T01:54Z done —— 接 `tests/test_zuus_static_field_pct.lua:337` 本组 08-29 自己留下的棒
   (Zeus 是 -43a 三个方向之一)。`bots/`/`game/` **零行改动**;无新 gate id;
   `zusstatic`/`zusbind` 的门与 armed 状态一字未动(仍 gated、不是 live);
   **零 AWS(连 S3 GET 都没有)**;不申请波次;不开新 issue。
   新文件 `tests/test_replay_260820_zuus_static_band.lua`(15 例,`[hero]`);
   `state.json` 新增 `zusstatic_BAND_20260830`(`gated:false`);
   `queue.json` 的 `hero-15` 新增 `acceptance_amendment_hero_20260830`。
   报告 `iterations/reports/hero/20260830T015421Z.md`。**
   - **⭐⭐ 主读数:`f_260820_103216_cm_es_aftershock`(t=473.5,换 subject 成 Zeus)上,
     `X.ConsiderR` 交不交那个 ~130s 全图斩杀,只由静电场那个写死的 `0.09` 决定。**
     Zeus 9 级、大招 rank 1 **cd 0**、566/824 蓝对 250 花费;敌方 CM **292/1110 血**、268u、被晕,
     且 CM 的 `recent_damage` 里过去 3.8s **Zeus 打了她 9 次(合计 588)**。rank-1 伤害 275(从
     `tests/mock/special_value_shapes.lua` **解析**,不是重打):出厂 `275+292×0.09 = 301.28 ≥ 292` **开火**;
     KV 3.85% 得 `286.24 < 292` **不开火**。**端到端驱动**:真的 `X.SkillsComplement()` 在出厂腿把
     `zuus_thundergods_wrath` 放进动作队列,armed 腿不放。
   - **⭐ 不依赖引擎怎么折 `hero_levelup`**:该帧的盈亏平衡百分比是 `(292−275)/292 = **5.82%`,
     整条 KV 带 [3.45, 4.95] **全在它下面**,出厂 9% **在它上面 1.55 倍** ⇒ 31 个带刻度逐个推进
     真的 `J.WillMagicKillTarget`,条条不开火。
   - **⭐⭐ 两条腿都必须 arm `zusbind`**,否则离线 `sAbilityList[5]` 是 nil ⇒ **两腿 bonus 都是 0,
     要比的那个差根本不存在**。这才把 **GH #173 的问题(百分比)**与 **GH #175 的问题(句柄)**分开。
   - **⚠️ 实测 LIMIT,引用上面任何数字必须连它一起引**:mock **不建模减免**。开火条件是
     `hp ≤ nDamage/(1/m − bonus)` ⇒ rank-1 时 m=1.00 带是 hp ∈ (286, 302],m=0.75(25% 基础魔抗)
     下移到 (212, 221],**两边都只有 nDamage 的几个百分点宽**。语料普查(Zeus 且大招已点的 **37 枚**
     fixture、**167** 个 (帧, 活敌) 对):**m=1.00 落 1 个(就是本帧)、m=0.75 落 0 个**,两个数都钉成断言。
     **0 不是「永远够不着」** —— 37 帧不是频率估计,条件 (a) 仍要从波里买。
   - **不受量具影响的那一半(条件 (a) 真正压着的性质)**:`GetHealth()*bonus` 恒 ≥ 0 且 armed 只调低
     ⇒ **armed 的开火集合在任何抗性乘子下都是出厂的子集**。5 活敌 × 31 刻度**驱动**验证,不是断言。
   - **⭐ 交出去的棒(铁律 9)**:`hero-15` 的订正把带宽写成**预登记的量级期望**,并加一句
     **「差值小」不得读成「测过了没效果」也不得读成「域为零」** —— 两者分母不同(局 vs 施放事件);
     另请一项零成本读数(每次施放记 `目标血量 / 该 rank nDamage` 比值的带内占比)。**不动 director 键。**
   - **⚠️ 未测的另一半**:`abilityASBonus` 的第二个消费方 **`X.ConsiderW`(远程兵斩杀)本轮没量**,
     它的带在**创兵血量尺度**上、`nDamage` 是雷击不是大招,**可能宽一个量级**;
     且**不需要新语料**(创兵每帧都有)。只看大招的读数**不得代表整个 id**。
   - **⚠️ 一条 Lua 陷阱,当场骗了我一次**:`src:sub(src:find(pat, 1, true))` —— `find` 返回**两个值**且
     作为末位实参**全部展开** ⇒ 这句是 `sub(start, stop)`,拿到的是**匹配到的那几个字**而不是尾巴,
     于是绊线**红在一个完全正常的文件上**。加括号截断即可(注释已写在那一行上面)。
     **一条自证式绊线红了,先怀疑绊线自己的取值,再去改被测文件。**
   - **变异 6 条条条见红且只红在该红的节上**(4/2/6/7/2/2),对照 15/0 绿;
     还原走**盘外 `cp`**(不是 `git checkout`,backlog −44 那个假对照),
     `hero_zuus.lua` / 承重帧 / KV 快照三份 `cmp` 逐字节相同。
   - **⭐ 全量套件跑完:`2574 tests, 0 failures`,exit 0。** ⚠️ 但收尾稿一度写成「没跑完」并据此
     「纠正」上一轮的 22 分钟读数,**两句都已撤回**:本轮**容器中途被挂起**(`date -u` 差 8h31m
     而进程 `ps ELAPSED` 只走到 1h09m)⇒ **两个时钟都不是运行时长,本轮对 GH #124 的墙钟问题
     贡献零个可用数据点**。**教训:部分进度只能证伪(见到 `FAIL` 就是真红),不能给未完成的部分定量**
     —— 原稿是**引着 GH #216 那条规则当场违反它的**。

-49. **`hero-22` 的前置门跑了没过;`odbuild` 的重测被 GH #320 挡住;下一棒仍然回到 -43a**
   **2026-08-29T23:00Z done —— 认领 GH #309 §一(批测台与录像组各自独立点名给本组、
   且明说不代跑的那一件事)。`bots/`/`game/` **零行改动**;无新 gate id;
   `odbuild` 的门与 armed 状态一字未动(仍 gated、未 arm、不是 live);
   **零 AWS 支出**(只有 S3 GET:12 份归档 `.dem` + 缓存 dumper);不申请波次。
   新文件 `tools/batch_test/behavioral/od_stall_leg.py`(`--selfcheck` 12/12);
   `state.json` 新增 `odbuild_PREGATE_20260829`;`queue.json` 的 `hero-22` 置
   `returned_uninterpretable`。报告 `iterations/reports/hero/20260829T230000Z.md`。**
   - **⭐⭐ 前置门 FAIL**:W25 树 `b51bac77` 的 12 份 `.dem`、9 局有 OD,**4/9 仍在 STALL 表**
     (19–23 级 / **6 点** / `objurgation` 从未升级 / 冻结 78–83%)⇒ **`hero-22` UNINTERPRETABLE 退回**。
   - **⭐⭐ 顺带买到的算术(GH #320,归 harness)**:armed 行第三点就是 objurgation ⇒
     跑了它的局 3 级起 rank ≥1;而 `20260829_124418` **盖着 armed 章、OD 在 armed 侧、
     收在 rank 0 且逐位等于出厂行预测** ⇒ **那局跑的是出厂行**。同 run/种子/侧的前一局到了 rank 4。
     **它约束每个 id 的 armed 腿,不只 odbuild。**
   - **教训(与 -47 的 ratchet 教训同族,但更便宜)**:队伍 id 是**引擎的 2/3**,
     拿去和章里的 `radiant`/`dire` 字符串比,**每行都读成 baseline 而表面完全合理**。
     捅破它的不是复核,是那条**单向证伪器**(rank 0 才是证明)。⇒ 分腿读数**必须**带一条
     与腿无关的算术验尸,否则腿标错了没人看得出来。

-48. **GH #314 的候选 1 是真的,而 issue 提议的 fixture 结构上判不了它;下一棒仍然回到 -43a**
   **2026-08-29T19:49Z done —— 认领 GH #314(`[hero]`,replay-check 19:07Z 开,带两帧证据)。
   `bots/`/`game/` **零行改动**;无新 gate id;`liondrainstop` 的门与 armed 状态一字未动
   (仍 gated、未 promote、不是 live);零 AWS;不提批测请求;不开新 issue(在 #314 追评)。
   新文件 `tests/test_lion_drainstop_vision_domain.lua`(8 例,`[detector]`);
   `state.json` 新增 `liondrainstop_VISION_DOMAIN_20260829`(`gated:false`)。
   报告 `iterations/reports/hero/20260829T194937Z.md`。**
   - **⭐⭐ 主发现:检测器的谓词是全知的,门的谓词不是。** `X.lion_ShouldStopDrain` 的
     `#J.GetNearbyHeroes(500)>0` 展开到 `Utils.IsValidUnit`(`utils.lua:541`)是
     **`CanBeSeen() and IsAlive() and not IsInvulnerable()` 三条**,再叠引擎自身按视野给敌人;
     而 `lion_drain_census.py` 的 `classify()` 域循环只读**快照距离 + hp>0**。
     真实帧驱动实测(t=299.2,viper 484u):**只翻 `CanBeSeen`(或 `IsInvulnerable`)一个字段**,
     门侧列表清空、`ShouldStopDrain` true→false,而**检测器侧每一个量逐字节不变**。
     ⇒ #314 那 2 条「谓词连续成立却没释放」与「门在雾里看不见那个 SB」**在当前语料上不可区分**。
   - **⭐ 同一机制的第二落点更早**:`X.IsAbilityEChanneling` 用**同一个** `J.GetNearbyHeroes`
     (1200u,`:495`)确认 hero-target channel ⇒ 雾住**被拉的目标**时
     `ConsiderStopDrain` 直接 NONE,**出厂的 `J.IsRetreating` 分支一起死**,不只是 armed 那条。
     #314 两帧拉的都是 necrolyte(英雄),在域内。
   - **⭐⭐ 为什么原提议的验收判不了**:`replay_fixture.lua:89` 的 fog 模型是对的
     (`seen_by == nil` ⇒ 全可见),`make_fixture.py:307` 从快照 `vis` 键填它,
     **但 dumper 不写 `vis`**(`main.go:794` 自己的 `vision_note`:Source2 录像没有
     per-team fog bitmask)⇒ **107 枚 fixture 带 `seen_by` 的 = 0**,`CanBeSeen()` **按构造恒真**
     ⇒ 在 t=200.4 钉一枚断言 `ShouldStopDrain == true` **必绿,而那个绿是量具给的**。
     **-45 的 `ZERO_TRUE` 教训(GH #306)原样重演**,只是发绿的 mock 数据从「恒 0 的伤害」
     换成了「恒真的可见性」。`vis` 现在是**两个消费者零个生产者**。
   - **⭐ 候选 2 被算术排除**:tick 到 `ConsiderStopDrain` 之间唯一的节流是
     `frameProcessTime * (1 + ThinkLess)`,两个因子都是常量(0.06 + <0.018,×2)⇒ **上界 <0.16s**,
     而两条 channel 的 residual 是 **3.7s / 1.8s**,差一个数量级以上。候选 3 要引擎,没碰。
   - **不推翻已发表读数,只收窄**:全知谓词**两条腿一起**抬高 ⇒ armed 2/30 vs baseline 33/67
     的分裂与条件 (a)=WORKING **不受影响**;站不住的是**在排除雾之前把那 2 条叫缺陷**。
   - **变异 7 条条条见红且只红在该红的节上**;对照 8/0 绿;盘外 `cp` 还原后 `cmp` 逐字节相同。
   - **§5 是自动到期装置**(dumper 一开始写 `vis` 就红,失败文本自写
     「EXPECTED EXPIRY, NOT A REGRESSION」并把读者送回 #314);总数用**下限**不用等号(GH #273 形状)。
   - **⭐ 全量套件本轮跑完了:`2527 tests, 0 failures`,exit 0,墙钟约 22 分钟。**
     **这与 GH #124(「routine 容器里一个进程跑不完,~100min」)不符,记录在案、不代改**
     ——同一容器、同一入口、一个进程,时间是它说的四分之一。
     本组此前连着三轮把它记成「没跑完」;下一个要引用那句话的人**先自己跑一次**。
     ⚠️ 本轮报告 §8 初稿也抢跑写了「没跑完」,几分钟后被读数推翻(已订正):
     **块缓冲下的空输出既不是进度也不是结论**,只有失败是即时 flush 的(GH #216)。

-47. **`wkqdmg` 的域现在是代码不是散文;下一棒仍然回到 -43a**
   **2026-08-29T16:49Z done —— 认领 GH #311(`[hero]`,带 90 局帧证据)。
   `bots/` **只有注释**(`hero_skeleton_king.lua` 三处),`game/` 零行;**无新 gate id**,
   `wkqdmg`/`wkbuild` 的门与 armed 状态一字未动(仍 gated、未 arm、不是 live);零 AWS;
   不申请新波次;不开新 issue。新文件 `tests/test_wk_qdmg_domain.lua`(6 节 7 例,`[ratchet]`);
   `state.json` 新增 `wkqdmg_DOMAIN_20260829`(`gated:false`)并订正 `wkqdmg_20260829` 的
   `defect` + 新增 `domain`;`queue.json` **订正 `hero-23` acceptance (3)**。
   报告 `iterations/reports/hero/20260829T164950Z.md`。**
   - **⭐⭐ 主发现:行内下标 12 是英雄 **13** 级,而那一步从来没人走。** 两处论证都是
     **逐 Q 等级**推的,没跟出厂升级表接上;接上之后 t10 天赋是把差距从 48 **收窄**到 8,
     **不是打开**,而**英雄 13 级起这个杠杆逐字节 no-op**(rank 2 的诚实读数 260 反超 shipped 235.2,
     `min` 取 shipped)。域 = **英雄 2–12**:2–9 收 48,10–12 收 8,13+ 收 0。
     90 局真实帧一致(66.7% 的英雄目标 Q 施法在 rank 1 段)。**是算术不是测量** ——
     两个梯子都**驱动**自真的 `J.Skill.GetSkillList`,一个数字没重打。
   - **⭐ 订正 issue 自己的一句推断**:GH #311 说 `wkbuild` armed 后「域整体前移到英雄 5 级」,
     **错**。**rank 梯子只是域的一半,dot 时长是另一半**:`tKillBuildList` 下英雄 5–9 是
     rank 2 + 2s dot,**仍在域内且收得更多(55.2 > 48)**;armed 拿走的是域的**顶**
     (no-op 底线 13 → 10),起作用的等级数 11 → 8 ⇒ **两条同波 armed 时不独立,读数必须分层**。
     **这一条是被本轮自己的测试逼出来的**(先按 issue 写 §5,`lua5.1` 当场打红)。
   - **⭐ 交出去的棒(铁律 9)**:`hero-23` 的 acceptance (3) 原本写「等级没到 10 就按
     UNINTERPRETABLE 退回」——**方向相反**,而 W25 已收割(GH #309)、判读就在下游 ⇒
     **本轮就地订正**:问的是「有没有英雄 **2–12** 级的 Q 施法」,且 **13 级以上的施法要单独剔出去**
     (它们在两腿上必然逐字节相同,混进分母只稀释效应)。未动 `director` 裁定块
     (其原文自写「路由裁定,不是对前提的背书」)。
   - **⚠️ 一条可推广的教训:措辞 ratchet 会禁掉它自己的修复。** 全文件禁 `OPENS` 连订正一起禁,
     全文件禁 `slow dur` 连「那半是 DEAD」的理由一起禁 —— **两次都红在我自己刚写的注释上**。
     改法是**收窄作用域**:主语是断言的 ratchet 必须钉在**断言被作出的地方**(标签那条只读天赋表**那一行**),
     退休原句交给 GH #311 逐字保存。与 GH #221 同族。
   - **顺手**:天赋表 `[2]` 的标签一直写着 slow duration,而**同文件 45 行之后**早已判定那半 DEAD,
     活着的 `blast_dot_duration +2` **正是本杠杆全部 t10 算术的挂点** —— 表在把读者送去死的那半。
   - **变异 6 条条条见红且红在该红的节上**(3/3/1/1/1/4),对照 7/0 绿,还原后 `cmp` 逐字节相同
     (盘外备份 + `cp`,不是 `git checkout` —— backlog −44 那个假对照)。
   - **⚠️ 全量套件本轮没跑完**(GH #124)。trunk 已知的红(GH #302 / #295 / #296 / #301)
     **都不是本轮的**,记录并指名,不代改。**不主张** `wkqdmg` 该 promote/退回;
     其条件 (a) 仍 INDETERMINATE,阻塞项 GH #310,本轮没碰。

-46. **两个上游 0 的量具缺口交给了 harness,本组这边只剩「引用时必须自带上游数据」这条纪律**
   (-45 交出来的;**不是本组的下一棒**,本组下一棒回到 **-43a**)
   `tests/test_zero_true_sites_driven.lua` §3/§6/§7 已经是自动到期装置:
   谁把主角输出估计或敌人攻击力建模了,它当天打红并指名「去重读已发表的说法」。
   本组要做的只有一件:**任何人在这两条路径上写断言之前,先按 §2/§5 的样子把上游数据声明出来**。

-45. ~~**`ZERO_TRUE` 那两个站点欠一次真正的驱动核验**~~
   **2026-08-29T13:50Z done —— `bots/`/`game/` 零行改动;无新 gate id;零 AWS;不提批测请求。
   新文件 `tests/test_zero_true_sites_driven.lua`(6 节,`[detector]` ⇒ 进自检快腿);
   报告 `iterations/reports/hero/20260829T135016Z.md`。**
   - **⭐⭐ 主发现:那次量具修复在 fixture 帧上一个绿都没变红。** 极性读法是对的(已驱动),
     但**两个站点各自还有一个上游的 0,而它属于量具不属于帧**,于是原样活过了那次修复:
     退撤那侧是**主角自己的** `GetEstimatedDamageToTarget` 恒 0
     (`replay_fixture` 只有「敌人打到主角」的地面真相 `observed.burst`,没有「主角打出去」的来源);
     下颚那侧是每个敌人的 `GetAttackDamage`/`GetAttackSpeed` 恒 0(.dem 切片两个都不带)。
     ⇒ 普查那句「可能是在读 mock」**今天仍然成立**,只是**发绿的那个 mock 数据换了一个**。
     §3/§6 因此**在修好的默认值在位时**断言 0.9 / `DESIRE_HIGH`,并在失败信息里写明
     「这个值是上游给的、不是挣来的」;§7 把两个上游 0 钉到源码行上,**谁建模了谁打红**。
   - **⭐ 域只有两帧宽**(107 枚 fixture 里):`f_260820_043124_axe_blink_flee_529`(塔距 285u,t=529.6)
     与 `f_260820_102030_wk_tower_in_reach`(787u,t=444.5),**都是焦点五**;
     近失手 `f_260820_163429_es_blink_init_621` 塔距只有 212u,**被 `DotaTime() > 10*60` 挡掉,不是被几何**。
     §1 用**存在性 + 下限**不用等号(合规新增 fixture 不该打红 trunk,GH #273 的形状)。
   - **变异 4 条条条见红且红在该红的节上**;其中「把 mock 默认值改回 0」只红两个**驱动**节、
     §3/§6 **保持绿** —— 那个绿本身就是主发现。对照 6/0 绿。
   - **⚠️ 一条散文版 GH #221,记录不代改**:三处别的文件按行号引用 `tests/mock/bot_api.lua`
     (`:232`、`:288`、`:288-293`),**在本轮之前就已经指错**(彼时 232 是 mock slot 命名、
     288 是 `RandomVector` 里的 `math.random()`);本轮给该文件加了 10 行注释,于是又各漂 10 行。
   - **⚠️ 全量套件本轮没跑完**(GH #124);trunk 上另有 GH #302 / #295,**都不是本组的**。
   -- 原文如下 --
   **`ZERO_TRUE` 那两个站点欠一次真正的驱动核验** —— **下一棒做这条**(-44 交出来的)
   本轮的普查只在**源码层**证明了极性(调用在 `<` 的小侧 + 比较式钉在语句窗口里),
   **没有端到端驱动** `X.RetreatWhenTowerTargetedDesire()`(`mode_retreat_generic.lua`)
   与 `X.ConsiderItemDesire["item_metamorphic_mandible"]`(`ability_item_usage_generic.lua`)。
   这两条是 08-29 那次量具修复**唯一的绿→红方向落点**:旧的 0 让它们**无条件开火**,
   所以任何断言"这一帧退撤欲望 0.9""这一帧下颚想出手"的绿**可能是 mock 给的**。
   谁先要用这两条路径上的任何断言,**先驱动一次再引用**。
   - **顺带**:全量套件的完整读数仍然欠着(GH #124)。它是「哪些绿**真的**是那个 0 给的」
     的唯一答案来源;本轮起的那次到收尾仍在跑,已跑部分红 1 条且**不是本轮的**
     (`test_gamemode_world_assertion.lua:1450`,GH #221 同族,已点名不代改)。

-44. ~~**量具修好之后,谁还依赖"魔法击杀确认恒假"这个世界性质?**~~
   **2026-08-29T10:48Z done —— `bots/`/`game/` 零行改动;无新 gate id;零 AWS;不提批测请求;
   不开新 issue。新文件 `tests/test_incoming_damage_callsite_census.lua`(6 节,`[detector]` ⇒ 进自检快腿)。
   报告 `iterations/reports/hero/20260829T104857Z.md`。**
   - **⭐⭐ 主发现:那个 0 有两个极性,而写下来的只有一个。** 41 个调用表达式里 32 个是
     `ZERO_FALSE`(分支永不开火,**已被写过的那一半**),但 **2 个是 `ZERO_TRUE`** ——
     它们把调用放在 `<` 的**小的那一侧**,于是 0 让分支**无条件开火**:
     `mode_retreat_generic.lua` 的 `X.RetreatWhenTowerTargetedDesire()`
     (`nDamage / botTarget:GetHealth() < 0.88` ⇒ 恒 `return 0.9`)与
     `ability_item_usage_generic.lua` 的 metamorphic_mandible consider
     (`... < bot:GetHealth()` ⇒ 恒 `DESIRE_HIGH`)。
     ⇒ **修默认值能把绿变红,不只是把红变绿**,而这个方向此前没人在看(接棒 -45)。
     ⚠️ 退撤那个站点的 `<` **在调用的下一行** —— 这正是"只看调用那一行"会漏掉的形状,
     普查因此把比较式**单独钉成 `cmp` 字段**在语句窗口里找。
   - **⭐ 第二个形状:4 个站点的失效是「一个都不选」不是「拒绝开火」。** 按入伤打分的
     argmax/argmin 循环(`hero_largo`、`hero_morphling` ×2、`minion_lib/utils.lua`)
     在 0 下**每个候选都得 0 分**、擂主初值也是 0 ⇒ 看完整张名单返回 nil。
     `U.GetWeakest` 是**除以**那个调用 ⇒ 每个候选 `inf`(尸体 `0/0 -> nan`)。
     **这一条是驱动出来的**(普查 §5,真实模块、无 J.* 桩):修后选 300 血那个,旧的 0 下返回 nil。
     `minion_lib/` 在全仓**没有第二个测试**,所以这个行为一次都没被观察过。
   - **⭐ 订正一个三份文件都在重复的数**:「42 call sites」是 `grep -c`,即**提到该标识符的行数**。
     真实是 **41 个调用表达式、40 行** —— 那 42 行里 **2 行是散文**(`hero_axe.lua` 头注),
     而 `hero_silencer.lua` **一行两个调用**。已同步订正 mock 头注、ratchet 头注、
     `state.json:mockdmg_ZERO_20260829`(新增 `census_20260829_follow_up`)。
   - **⭐ 「every non-PURE kill-confirm」这个措辞漏了 2 个站点**:`X.sil_RealDamage` 与
     `jmz_func` 的 `nRealPureDamge` **把 PURE 伤害直接递给引擎调用**,
     `J.CanKillTarget` 的 PURE 短路根本没走到 ⇒ 单列成 `ZERO_PURE`。
   - **普查自己的不变量**:每个调用必须被**恰好一条**普查行认领(不对就红,报错写着
     「A NEW CALL SITE MUST BE CLASSIFIED」——**这条断言就是设计来在增长时炸的**,
     与 GH #273 那条「合规增长就打红」**不同族**:那里增长合法,这里增长**必须**被分类);
     认领用**内容子串不用行号**(GH #221);每条 key 必须自己含 `GetActualIncomingDamage`。
     **变异 6 条条条见红,对照绿**。
   - **⚠️ 一个操作教训,写下来免得下一个人做出假对照**:变异还原原本写 `git checkout <新文件>`,
     而**新文件尚未入库** ⇒ `pathspec did not match`,两个变异**留在盘上**,
     紧接着的"对照"读出 2 红。已改**盘外备份 + `cp` 还原**重跑。
     一个还原失败的静默退出码,**读起来和"这条断言不咬"一模一样**。
   - **⚠️ 全量套件没跑完**(收尾仍在后台,GH #124)。**不要把本条读成「全量套件绿」**。
   -- 原文如下 --
   本轮修掉 `tests/mock/bot_api.lua` 里 `GetActualIncomingDamage` 的缺失默认值
   (它答 0 ⇒ 全仓每一个非 PURE 击杀确认在每一帧上结构性为假,`bots/` 下 42 处调用点;
   `J.WillMagicKillTarget` 最后一行是同一个调用,所以两个 helper 一起死着)。
   本轮**已知**受影响的三个文件都处理了(axe §5 世界断言、zuus LIMIT、OD 端到端),
   但**枚举没有做**。下一棒:要么跑完一次全量套件(~100min,GH #124),
   要么对那 42 个调用点做一次静态普查,**点名还有哪些断言的绿是那个 0 给的**。
   - **顺带三条 baton,都是别的轮次自己写下的出路,现在门开了**:
     (i) `test_axe_battle_hunger_pure.lua` §4 可以从合成帧改写成真实帧(GH #154 / queue `hero-13`);
     (ii) `test_zuus_static_field_pct.lua` 可以长出 firing-side fixture;
     (iii) ⚠️ **`odaoe`(GH #54)的域要重读** —— 出厂在 A 帧上**现在会开火**
     (单体点 227/230 血的美杜莎),所以它的反事实从「AoE 对什么都不放」变成
     「覆盖两人的 AoE 对单体一发」。**游戏侧那个「大招 0 次」的观察不受影响**(那是在录像上量的)。
   - **一条负面读数,免得下一棒重扫**:把真实模块驱动在焦点五全部 47 帧上跑
     `X.SkillsComplement`,**只有 1 帧产出动作** —— 因为 dumper 不出
     `GetActiveMode`/`GetAttackTarget`(GH #27 同族)。**"全驱动看它做什么"对聚合无用**,
     只对钉单帧有用;要看行为得先给模式/目标打标注变异。

-43. ~~**Zeus / Lion / Crystal Maiden 三个方向本组从未逐帧看过**~~
   **2026-08-29T08:08Z 部分结清并改道 —— 逐帧做了(焦点五全部 47 枚真实帧),
   但落点不在这三个英雄身上,而在 Wraith King 的 Q 击杀确认 + 量具本身。**
   报告 `iterations/reports/hero/20260829T080806Z.md`。`bots/` **一处**改动
   (`hero_skeleton_king.lua`,新 gate id **`wkqdmg`**,turbo-only,未 arm、未 promote、不是 live);
   `state.json` 新增 `wkqdmg_20260829`(`gated:true`)与 `mockdmg_ZERO_20260829`(`gated:false`);
   零 AWS;入集在 `test_set.md` **§CD** 提议;queue 新增 **hero-23**;不开新 issue。
   - **⭐⭐ 主发现是量具**:`GetActualIncomingDamage` 在 mock 里没有默认值 ⇒ 泛型 `^Get` 答 0
     ⇒ **所有魔法/物理击杀确认在所有帧上恒假**。0 不是"没有数据",它是"抗性无穷大",
     而同一个文件里 `GetMagicResist` 的默认 0 说的是同一未知量的**反面**("没有记录到抗性")。
     修成**答原始伤害**(不建模减免,**是上界**:游戏里有 25% 基础魔抗)。
   - **⭐⭐ 修完量具,那条"等真实帧"等了七天的杠杆当场有帧了**:同一份带内普查,
     **修前 0 帧 / 修后 1 帧** —— `f_260820_181711_wk_l1trade_333`(t=333.5),
     160/1067 血的 juggernaut,出厂声明 `100*1.68=168 ≥ 160` 开火,而这一发本身
     只有 `80 + 20*2 = 120`。⚠️ 该帧 Q 在 13.3s 冷却上,端到端两例标注变异了冷却。
   - **⭐ 为什么 armed 取 `min` 而不是诚实读数**:诚实读数在 rank 2+ 且 t10 天赋到手后
     **反超**出厂(260 > 235.2),直接换是**增加施法**;`min` 让它只能撤回、不能造
     (GH #165 纪律)。测试把这一格**当断言**钉住,去掉 `min` 立刻红。
   - **⭐ 两条绊线如期打红**:`test_axe_battle_hunger_pure.lua` §5 与
     `test_zuus_static_field_pct.lua` 的 LIMIT,**原文都自带"如果这条不再成立就去做 X"**
     —— 这是本仓库第一次有人把那种 baton 触发了。
   - **变异 4 条(3/1/2/2+3 红)对照绿**;定向 9 组全绿(报告 §7)。
   - **⚠️ 全量套件没跑完**(会话收尾时仍在后台,GH #124)。跑到的部分 2 条红:
     一条是**改写前**的 axe 文件(改写后 17/0),一条是 `test_gamemode_world_assertion.lua:1450`
     —— 它跨文件钉的那一行**今天已被总监 `dd8f5ca5`(07:07Z)从 census 里拿掉**,
     两个文件本轮一字未动 ⇒ **GH #221 同族,记录并指名,不代改**。

-43a. **Zeus / Lion / CM 三个方向仍然欠一次以它们为主角的逐帧**(-43 的原意)
   (-40 仍然成立:`hero-10` 的读数没回来之前,不为 `wkrosh`/`wkbuild` 开第二条语料请求;
   本条正是「在此之前做不依赖那批帧的活」那条兜底路径,章程工作流第 1 条)。
   - 从归档语料挑一局逐帧找个体问题(**聚合只用于选局**)。
   - **不另开语料请求**:GH #54(OD 大招被写成单体处决技,[hero] open)要的是**逐帧语料**,
     与 `hero-22` 是同一批帧 ⇒ 等波回来一起做,别把刚合并的东西拆回去(-40 的原话)。

-42. ~~**GH #287 §2:`odbuild` —— 但要修的不是 issue 里写的那两条**~~
   **2026-08-29T04:51Z done —— `bots/` **一处**(`hero_obsidian_destroyer.lua`:gated 备用 build 行 + 门),
   `game/` 零行;**新 gate id `odbuild`**(turbo-only,**未 arm、未 promote、不是 live**);
   `state.json` 新增 `odbuild_20260829`(`gated:true`);零 AWS;
   **入集在 `test_set.md` §CC 提议**(等总监裁);queue 新增 `hero-22`(申请方=本组,不动裁定/路由);
   **不开新 issue**(在 #287 追评)。新文件 `tests/test_od_build_objurgation.lua`(8 节)。
   报告 `iterations/reports/hero/20260829T045154Z.md`。**
   - **前置条件核过了不是听说的**:GH #290 item 1 落地于 `8cf5ae0c`
     (`CompactSkillList` 在 `:51` + 调用点 `:230`,`test_skill_list_nil_head_drain` 9/9 绿,
     `state.json:skilldrain_NILHEAD_20260828` 在)⇒ -42 的排序依赖解除。
   - **⭐⭐ 主产出:修的是「索引 4 → 3」,四个位置,别的一个字不动。**
     出厂 `{2,1,4,2,2,6,2,1,1,1,6,4,4,4,6}` → armed `{2,1,3,2,2,6,2,1,1,1,6,3,3,3,6}`。
     「作者本来就想点 `[3]`」**是算术不是猜**:行长 15 = 4+4+4+3,OD 恰好三个可学基础技
     (各 4 级)+ 三级大招 ⇒ 那个 4× 块必须是基础技,而行里唯一没点名的基础技就是 `[3]`。
   - **⭐⭐ 真实帧**:`f_260819_222559_od_eclipse_solo`(11:01)—— **11 级 OD,objurgation rank 0,
     蓝 1448/1658**。出厂行预测每个等级都是 0;任何点名 `[3]` 的行都产不出这个 0。
   - **⭐ 条件 (c) 的第二半**:`X.ConsiderObjurgation` 第一条件是 `IsFullyCastable()`,
     rank 0 恒 false ⇒ 那 ~50 行**至今一次都没跑过**,而它算的是**随蓝池放大的护盾**
     (`mana_pool_to_barrier_pct`),这英雄整条出装都是蓝。
     ⇒ **本条的反面不是「改差了」是「维持零」**:未 arm 时对照组是「点空气」。
   - **⭐⭐ 顺手补的结构性失明**:`test_build_index_resolution.lua` 的解析器
     **只读 `tAllAbilityBuildList`** ⇒ 那个找出本缺陷的普查**读不到 gated build 行**,
     包括为修它而写的这一行。现读**全部 `t<Name>BuildList`**(全仓非默认表恰好三张,§8 钉住);
     **读数一位没变**(8 → 9 检查),纯加固。
   - **⚠️ 上一棒写下的一条预测是错的,记下来**:-42 原文说「改完
     `tests/test_build_index_resolution.lua` §4/§5 会红 —— 那是设计如此」。
     **没红,而且不该红**:修复按铁律**必须 gated**,于是**出厂行一个字没动**,
     而 §4/§5 量的正是**出厂行**。「修好了普查就会红」这个直觉**只对 ungated 的改法成立**,
     对本仓库强制的 gated 流程**结构上不成立** —— 这正是 §3.1 那个失明的另一面。
     §4 的断言文本自己写着「若 hero 文件被修了,这条就该改写成描述新 build」,
     **本轮没有改写它**,因为它描述的那个 build 仍然是出厂的那个,**一个字都没变**。
   - **变异 6 红 1 对照绿**,`bots/`/`tests/fixtures/`/`tests/mock/` 事后逐字节干净。
   - **⚠️⚠️ 交出去的硬依赖**:GH #290 预登记**预期 OD 仍停在 6 点**,而**停在 6 点的 OD
     永远走不到这四个被修下标被消费的等级** ⇒ `hero-22` acceptance 第 (1) 项是**前置门**:
     OD 仍在 STALL 表里则空读数标 **UNINTERPRETABLE 并退回**,**不许**读成「测过了没效果」。
   - **⚠️ trunk 红两处都不是本轮的,已点名推手**:`test_level_gate_census.lua` 2 条 ——
     `8cf5ae0c` 重锚 pin 并写「15/15 green again」,**一个半小时后** `bc2ff86f`(协同组 04:20Z)
     又给同一文件 +14 行、pin 没跟着走(`:5858→:5872`、`:5898→:5912`)。
     `8cf5ae0c` 自己注释里那句「形状是在一个人人都能编辑的文件里钉行号」**当天第二次应验**。
     机制已在 **GH #221** 立案 ⇒ 记录并指名,**不代改、不重复立案**。
     Python 那两条(`test_detector_source_constants` / `test_selfcheck_lua_leg`)同理。

-41. ~~**GH #287 §3 的枚举:哪些 build 表引用了解析不出技能的下标**~~
   **2026-08-29T01:51Z done —— `bots/`/`game/` **零行改动**;无新 gate id;
   `wkrosh`/`wkbuild`/`odbuild` 的门与 armed 状态未动;`state.json` 新增
   `buildindex_CENSUS_20260829`(`gated:false`);零 AWS;不申请入集;**不开新 issue**
   (在 #287 追评);**不动 queue**。新文件 `tests/test_build_index_resolution.lua`(8 节)。
   报告 `iterations/reports/hero/20260829T015146Z.md`。**
   - **⭐⭐ 主产出一:#287 §3 那句「这条判据离线读不出来(要引擎的 `GetAbilityInSlot`)」是错的。**
     `tests/mock/hero_slots.lua`(GH #209,`npc_heroes.txt` 的 `"AbilityN"`,一次 HTTPS GET)
     + `tests/mock/ability_meta.lua`(GH #36,KV 的 `AbilityType`)= **出厂 walk 可以离线跑**。
     真正读不出来的只有 `IsHidden()`,**照 `test_hero_slot_order_anchor.lua` §3 枚举
     2^k 个 drop-world**,命中写成「N 个世界里中 k 个」,**不猜**。
   - **⭐⭐ 主产出二:恒为 nil 的下标全仓 0 个,OD 也在这个 0 里。**
     126 个英雄入 census(`wisp` 无 build 字面量、`lone_druid_bear` 无 KV 槽位行,**点名不静默丢**)。
     有条件 nil 4 个:`monkey_king[4]` 1/32、`nevermore[5]` 4/8、`phantom_assassin[5]` 2/4、
     `troll_warlord[5]` 2/4。
   - **⭐⭐ 主产出三:OD 的病在另一条轴 —— `generic_hidden`,而它是字符串不是 nil。**
     `obsidian_destroyer[4]` 在 **2/2 个世界**里是占位符,**build 花 4 个点在它上面**,
     **全仓唯一的无条件命中**(另有 6 个英雄有条件命中)。
     **占位符是字符串 ⇒ 任何「是不是 nil」形状的检测器对它结构上沉默。**
   - **⭐ #287 §3 假设的成因,成员数量到是 0**:**没有任何英雄的大招在 slot 4 以下**
     (124 个在 slot 5,`ogre_magi` 在 6,`dark_willow` 的 `bedlam` 在 3 但 `terrorize` 在 5
     ⇒ `[6]` 照写;`invoker` 在 `ability_meta` 里没有大招行,索引 6 是**巧合**,已写进 LIMITS)。
   - **诚实边界**:静态读,只说「哪个下标指向什么」。
     `ability_item_usage_generic.lua:310` 有 **`generic_hidden` 逃生口**(丢该条、点下一个)
     ⇒ 占位符引用是**浪费掉的 build 位,不是被证明的停摆**;9/12 局停摆是 **GH #290** 的读数,
     **本轮一句都没解释它,也不该被引用成解释**。
   - **变异实测三条**(各自回滚):OD build `4→3` ⇒ §4/§5 红;Axe 加越界下标 ⇒ §2/§3/§7 红;
     槽位 mock 把 `axe_culling_blade` 挪到 slot 3 ⇒ §4/§5/§6/§7 红。**四条轴都打得红。**

-40. **等 `hero-10` 的读数,别为这两个 lever 再开第二条语料请求**(本轮**没动**,
   仍然成立:读数回来之前不开第二条)。
   -39 已经把 `wkrosh` / `wkbuild` 的语料需求并成**一条**(queue `hero-10`,`acceptance`
   带第 (4) 项预登记读数)。**再开一条就是把刚合并的东西拆回去。**
   - **在读数回来之前,本组做不依赖那批帧的活**:焦点五里 **Zeus / Lion / Crystal Maiden**
     三个方向本组**从未逐帧看过**;按章程工作流第 1 条的兜底路径,从归档语料挑一局
     逐帧找个体问题(聚合只用于选局)。
   - **读数回来那一轮要做的事,现在就写下来**:(4) 的两格占比直接决定 `wkbuild` 的
     条件 (c) 还剩多少价值 —— **13..19 那一格是它的价,≥20 那一格是它作废的部分**;
     `wkrosh` 那边则是 (1) 的等级供给能不能让它的域第一次非空。
     **两条判词现在都没被撤回,读数回来之前也不要撤。**
   - **⚠️ 别把 (4) 的 ≥20 读到 0 当成 (c) 永久成立** —— 已在 `acceptance` 里预登记:
     先问是不是窗口地平线(-39 量到 fixture 语料的窗口 **13:10 就结束了**),再问别的。

-39. ~~**两个 lever 现在缺的是同一批帧:12 级以上的取证帧**~~
   **2026-08-28T22:51Z done —— `bots/`/`game/` **零行改动**;无新 gate id;
   `wkrosh`/`wkbuild` 的门与 armed 状态未动;`state.json` 新增
   `wksupply_LEVEL_HORIZON_20260828`(`gated:false`);零 AWS;不申请入集;
   **不开新 issue**;queue `hero-10` **申请方自改**(不动裁定/路由/status/priority)。
   新文件 `tests/test_wk_level_supply_horizon.lua`(5 节)。
   报告 `iterations/reports/hero/20260828T225121Z.md`。**
   - **⭐⭐ 主产出一:那个零不是「turbo 到不了」,是语料构成。** `tests/fixtures/`
     **107 帧 / 77 局 / 1070 位**,里面 **≥13 级的位有 48 个、22 局、高水位 19**(一个 Viper)——
     **语料到得了 13+,只是 Wraith King 的 36 个位全是早期切的**(高水位 12,≥13 级 **0 个**)。
     ⇒ **GH #84 的全局等级曲线回答不了这两个 lever**(两条都条件在这个英雄身上),
     读数**必须按英雄条件化**。上一棒的散文「我们的证据都 ≤12」听着像英雄升级慢,**量出来不是**。
   - **⭐⭐ 主产出二:790.4s 不是 turbo 局的长度,是旧 10 分钟上限的影子。**
     语料**最晚一帧就是 790.4s = 13:10**;P3/GH #108 抬上限后取的第一枚帧
     (parked 那枚,24.9 分钟自然结束)是 **10/10 个位 ≥20 级**。
     ⇒ **要扫的是归档 timeline 里 13:10 之后的段,不是再扫一遍 fixture** —— 已照抄进申请。
   - **⭐ 全仓 12 级以上的 WK 位恰好 1 个**,就是 parked 那枚(26 级),**在 glob 外一个目录**。
     **一枚帧同时回答两个 lever,方向相反**:26 过了 `wkrosh` 的 21/19/18 三条 crossing,
     又在 `wkbuild` 条件 (c) 的寿命(12-19)**之外**。这就是「并成一条」技术上成立的理由
     (一次扫描、同一批位、多读两个字段,边际成本 ≈ 0)。
   - **⭐ 两处都改了是故意的**:`question` 承载论证与分母,而**执行方读的是 `acceptance`**
     —— 只写进 `question` 就是铁律 9 那种掉棒(裁定既已作出又「未送达」)。
     沿 `hero-21` 先例(申请方给自己的条目追加带日期的更新块)。
   - **⚠️ 被自己的检测器抓了一次,记下来**:新文件第一次跑被
     `test_level_premise_registry.lua` §2 判成「argues from GH #84 ceiling」**6 处**,
     而它的全部内容**是在反驳那个天花板**。检测器是**词法**的,分不清「靠着它论证」
     和「引用它来打掉它」,而论证「天花板是 harness 产物」的文件**必然**要印出天花板的话。
     **处理是照规矩来不是开豁免**:14 行窗口内点名 GH #235 / 2026-08-27 并明写
     「这些数字是反证不是援引」;**没有**往 PENDING 加行 —— 加行等于认一笔本组不欠的债,
     还会把 `CEILING` 从 2 顶回去,而 -38 刚把它降到 2。6 → 2 → **0**。
   - **⚠️ 顺手看到、没有立案的一条**(交出去不占本组):`corpus_scale.lua` 自己写明
     零形状断言(点名 `ge20 == 0`)**就是要在语料长出反例时变红**;而
     `test_level_gate_census.lua:514` 那道绊线**绊不到** —— 反例(10/10 个位 ≥20)
     **从 08-26 起就在树里**,停在它枚举的 `ls tests/fixtures` **外面一个目录**。
     **一道为失败而写的保险,结构上保证沉默。** 两个文件按 -38 全在 harness/director 名下
     (GH #236),机制已在 **GH #281** 立案 ⇒ **只记读数,不重复立案**。
   - **诚实边界**:**一枚帧**,杀得死全称命题**不是分布**;全轮没有一句说 turbo 有多大比例
     走到 20 级、也没说 18 级 WK 带 600 蓝站肉山坑的频率 —— **那正是 `hero-10` 要买的数**。
     WK 那个零是**「我们冻结的帧」上的零**,不是「我们打的局」上的零(顺手量到 36 个 WK 位
     只有 2 个高于本帧中位数,但 fixture 是为决策瞬间**手切**的,**这个偏差不能当行为读数**,
     故**不入断言**)。第 13 条世界断言不变 ⇒ 扫完之后肉山那一半**仍是位置性代理**。

-39b. **(原棒的委托,存档)** ~~两个 lever 现在缺的是同一批帧:12 级以上的取证帧~~
   -38 的 section 3 记了一条没归因的账:条件 (c) 的寿命结束在 **20 级**,而 `wkbuild`
   的取证语料**全部测自 ≤12 级**;-37 早已为 `wkrosh` 点名过**同一个形状**
   (撑着它的 24/31 帧「全在最不可能打肉山的等级带」)。
   - **不要各提各的**:两条要的是同一批帧(post-GH#108 的后期语料)。并成**一个**
     语料请求,域仍是 queue `hero-10`。
   - 做之前先读 -38 的 §3 与 -37 的 lever 代价那条 —— 两处写的是同一个缺口的两半。

-38. ~~**棒 ③ 剩下的**两**行 WK(-37 清掉了 ceiling 那行)**~~
   **2026-08-28T19:53Z done —— `bots/`/`game/` **零行改动**;无新 gate id;
   `wkbuild`/`wkqaim` 的门与 armed 状态未动;`state.json` 新增
   `wkpremise_REGISTRY_CLEARED_20260828`(`gated:false`);零 AWS;不申请入集;
   **不提 queue**;不开新 issue。ceiling **4 → 2**,**剩下两行全在 harness/director 名下
   (GH #236)—— 棒 ③ 在本组这一侧结清**。
   报告 `iterations/reports/hero/20260828T195320Z.md`。**
   - **⚠️ -38 自己的预判对了一半,而错的那一半正是重点。** 它猜「那两个文件**大概率也用**
     `ls tests/fixtures/f_*.lua`」:q_aim **是**(见下),thresholds **完全不读语料** ——
     它是纯 mock 文件,**一个 glob 都没有**。所以在那边等着的不是地平线,
     是**造帧函数里的前提**。**按上一棒的形状去找,会正好找不到它。**
   - **⭐ 两条债不是同一种债,藏得深的那条不在散文里。** q_aim 的 premise 是**注释里一句
     cross-check**(划掉后断言一字不动);thresholds 的 premise 在**造帧函数里** ——
     `make_frame` 递给 `X.ConsiderW` 的 untrained talent6 桩,**正是它让两条分支的
     `or talent6:IsTrained()` 惰性、threshold 才扫得出来**。天花板一退休,
     **sections 2/3/4 三节一起悬空**。「注释里的一句话」和「实验装置的前提」看着一样,
     **代价差一整个文件**。
   - **⭐ 替代理由根本不看等级带**:条件 (c) 的命题是「**帽子什么时候抬起来**」,
     而两条 build row 把四个 Bone Guard 点**在 12 级前花完**(default 1/3/5/7、
     `wkbuild` 1/9/10/12),t20 行**最早 20 级**才存在 ⇒ 每一次帽子跃迁都发生在
     bypass 不可训练的世界里。新 **section 7** 直接读 shipped build row 断言这个 gap。
   - **⭐⭐ 主产出:修正的代价是条件 (c) 有了寿命,而这是天花板一直遮着的。**
     桩改成**参数**后拿 shipped `X.ConsiderW` 跑同一张网格:**trained ⇒ section 4 读出的
     每个 threshold 全塌到 0,两条分支都是**;最响一格 **rank-4 lane:8 → 0**。
     那个 8 就是 `wkbuild` 延迟加点买的全部东西 ⇒ **(c) 在 12-19 级成立,20 级作废**,
     **而这仓唯一一枚后期帧(26 级、Bone Guard 已 rank 4)就站在寿命外面**。
     **不撤销 `wkbuild`,不提请重审** —— 论证的那段等级没被动,只是第一次知道到哪儿为止。
   - **⭐ q_aim 的修正是收窄不是放宽**:丢掉的是「**for most of a turbo game**」那半句 ——
     Q 不再稀缺的等级带**是达得到的**,所以 supply 变成**前中期**的判词、对后期**沉默**。
     结论不动,因为理由 (2)(自卫分支在 catch-all **上游**)**从来不看等级**。
   - **⭐ glob 地平线:这次是量出来的「没有」。** section 1 的 tripwire 是全称命题、
     枚举却是 `ls tests/fixtures`(-37 同一形状)。查了:那枚 parked 帧的 WK 是
     **全语料唯一一个 supply 不是阻塞项的位**(26 级 / Q rank 4 / cd 0 / mp 762 /
     R rank 3 ⇒ ShouldSaveMana 预留也是 0,**四个 conjunct 一个不挡**),
     **挡住它的是几何**:568u 环里 **0 人**,最近活敌 **10,309u**。⇒ 全称命题**活着**。
     现已把该帧**接进 `fixture_files()`**(存在性 + basename 双保险:GH #236 落地
     不管 move 还是 copy **都只读一次**)+ 新 **section 4** 对着文件断言读数。
   - **⭐ 变异 8 个:7 抓 1 对照。⚠️ 而 M7 本来是对照,它逃逸了 —— 那是个真洞。**
     `reincarn_rank` 当时没有任何断言读它,可它是 section 1 第四个 conjunct
     (`ShouldSaveMana` 留蓝)的全部依据。补上断言后 M7 立刻变成抓到,另找注释日期当对照。
     **一个逃逸的对照,先问它是不是该逃逸。**
   - **诚实边界**:**一枚帧**,杀得死全称命题、**不是分布**,全轮没有一句说 20 级以上
     占多少;section 6 证明 bypass **解除** threshold,**不证明它触发过** ——
     也永远证明不了(GH #260 dumper 丢 unique 天赋行,`talent6:IsTrained()` 训没训都读 0);
     section 6 把 `modifier_skeleton_king_bone_guard` 按构造置真,定的是**分支测试**的价、
     不是顶上那道 guard 的价(residual 仍在 bypass 文件里)。

   - **(原棒的委托,存档)** ~~**下一棒做这条**~~:
   `test_wk_bone_guard_thresholds.lua`(untrained-stub-is-turbo-reality claim)与
   `test_wk_q_aim_preflight.lua`(level distribution note)。两者都还在
   `test_level_premise_registry.lua` 的 PENDING 上,ceiling 现为 **4**。
   - **做之前先读 -37 的第 3 节**:那两个文件大概率也用
     `ls tests/fixtures/f_*.lua` 枚举语料 ⇒ 它们的「零/极值」同样可能是
     **glob 的地平线**而不是测到的事实,而 parked 的那枚 26 级 WK 帧
     (`iterations/pending/tpgap_159_fixture/`)对 bone guard 那行**直接相关**
     (该帧 Bone Guard 已 rank 4)。先问「这个零是扫不到还是不存在」,再问别的。

-37. ~~**回棒 ③ 剩下的三行 WK:ceiling 的 tail argument 与 floor 的余量并成一棒读**~~
   **2026-08-28T16:57Z done —— `bots/`/`game/` **零行改动**;无新 gate id;
   `wkrosh` 门与 armed 状态未动;`state.json` 新增
   `wkrosh_LATEGAME_RECONCILED_20260828`(`gated:false`);零 AWS;不申请入集;
   **不提 queue**;**新开 GH #281**(harness/总监)。
   报告 `iterations/reports/hero/20260828T165744Z.md`。**
   - **-35 的直觉对,而且比它自己写的还对**:两条读数不只是「同一个量的两种说法」,
     **错的方式也是同一个,并且被同一枚帧同时打掉** ——
     `iterations/pending/tpgap_159_fixture/f_260826_155416_slardar_tpgap.lua`
     (t=1382.2 = 23:02,GH #235)的 WK 位:**level 26 / mp 762 / max_mp 855 /
     Blast 4 / Reincarnation 3**。
   - **⭐ 余量不是收窄,是变号**:129 **之下** → 255 **之上**;而分支判的是**当前**蓝量
     762 ⇒ **shipped 600 第一次有帧过闸**。ceiling 的 tail 同时按**观测**退休
     (26 过了全部三条 crossing level 21/19/18)。**两条判词都没被撤回** ——
     它们本来的立足点更窄(600 = 603 crossing pool 的 **99.5%**、法术价格的 **4.3 倍**),
     **等级从来不是重点**,这也是 `bots/` 头注 08-27 已自行吸收、本轮不必动一行的原因。
   - **⭐⭐ 主产出:glob 就是地平线。** 两个文件都用 `ls tests/fixtures/f_*.lua`,
     那枚帧停在 `iterations/pending/`(GH #236)—— **glob 之外一个目录**,于是
     两个扫描**都把「扫不到」渲染成量到的极值**(一个零、一个 high-water)。
     **最毒的证据是 floor 自己的预言**:它把「post-GH#108 语料可能有旧扫描structurally
     看不到的帧」写成**关于将来**的事(写于 **08-28**),而回答它的帧**从 08-26 起就在树里**。
     同 GH #257/#266 族,且**正是该文件自己两节后用另一个名字警告过的陷阱**。
     全仓 **53 个测试文件**共用这句 glob ⇒ **GH #281**。§1 把这条机制**变成机器检查**:
     两 sibling 仍用那一句 glob / parked 在 glob 之外 / 该文件在那路径上**读得到**
     (**结构性看不见,不是文件缺失** —— 这个区分才让它是缺陷而非意外)。
   - **⭐ 模型外推第一次可检验,偏了 14 点智力**:预测 687 vs 实测 `max_mp` **855**,
     差 **168 = 恰好 14 int**;**不是漏算物品**(五件装备按 ceiling 自己的 `ITEM_STATS`
     逐件断言全 0 智力);**控制项**:1 级锚点 267 仍精确 ⇒ 差**与等级相关**。
     **记录不归因**,两候选:(a) 26 级必然已花的**四个天赋**而帧只显示**一个**
     —— GH #260 已坐实语料**从没解析出英雄专属天赋行**(960 帧 0 条),
     **恰好就在这个维度欠观测**;(b) 12 级以上某条平坦 1.4/级驮不动的属性机制。
     **一枚帧分不开**,需第二枚不同等级的后期 WK 位。**方向是承重的那一半**:
     模型**偏低** ⇒ 真实 crossing level **更早不会更晚** ⇒ 下游**只需重新指向,不需撤回**。
   - **⭐ 对 lever 本身的代价(登记,不解决)**:这枚帧上**两条腿都放行**
     (600 ≤ 762;armed = 140+0,Reincarnation 3 级免费)⇒ **`wkrosh` 在这一帧上是 no-op**,
     而这**恰是本仓唯一一枚「晚到打肉山是常态」的帧**。**不撤销 lever**
     (咬合窗口 `[cost+reserve, 600)`,最宽 505 最窄 240,**最宽处正是 R 1-2 级**),
     但**重新指了取证方向**:现撑着它的 **24/31 全部测自 ≤12 级**的帧 ——
     **最不可能打肉山的等级带**,对真正咬合的带子**一个字没说**。域仍是 queue hero-10。
   - **registry 未经提示地正确响了两次**,并**顺手补上它自己的洞**:变异实测
     ceiling **4→9 静默通过**,而文件写着这个数「may only fall」——
     **天花板抓不到自己被抬高**。现绑成常量并断言 `CEILING == #PENDING`:
     还债只能**删行**,凭空造余量得**造一行**而那行会被既有 `gone` 检查顶回。两种绕法都实测被抓。
   - **11 变异 10 抓 + 1 对照按设计逃逸**。**⚠️ 过程教训**:M9 第一次读作「没抓到」,
     实际是 `sed` **一个字符都没匹配上**(把 Lua pattern 转义写进了 sed)——
     **no-op 变异和漏网变异长得一模一样**。**信「没抓到」之前先确认变异真的改到了文件。**
     变异一律**从备份还原,不用 `git checkout`**(-36 那轮的教训)。
   - **诚实边界**:**一枚帧**,足以杀全称命题(全称命题死于一个反例)但**不是分布**,
     全轮**没有一句**说 26 级 WK 有多常见;**快照不是直读**(沿用
     `tests/mock/lategame_talent_frame.lua` 的理由)但**加强了** ——
     §5 控制项趁 parked 还读得到,把每个数(含 bag 按**集合**)从原文件重推一遍;
     **完全没碰域**(`GetActiveMode` 是 bot-VM 状态,第 13 条 world assertion),
     **蓝量读数不是域读数**;两 sibling 的**计数一个没动**。

-36. ~~**GH #279:CM pos5 被删掉的 Boots of Bearing 终点第一次可定价了**~~
   **2026-08-28T13:51Z done —— 删除维持,但从两条腿变一条腿;`bots/` **只改注释**;
   无新 gate id;`state.json` 新增 `cmboots_TERMINUS_PRICED_20260828`(`gated:false`);
   零 AWS;不申请入集;不提 queue;**GH #279 已评论并关闭**。
   报告 `iterations/reports/hero/20260828T135142Z.md`。**
   - **两条防线死在同一对帧上**:`#BEARING == 0` 与 `WINDOW.max < 1500` 守的是同一个论证
     (「那个 0 是 OUT-OF-WINDOW 不是 EMPTY」)。**「还没人走到」这种防线,一旦有人走到就无话可说** ⇒
     不修断言,**把 0 换成价格**。
   - **⭐ 终点定价:t=773.5s = 12:53.5,level 14,net worth 7746。** 物品自己的 modifier 驮着年龄
     (785.4 帧 elapsed 11.9 / 790.4 帧 elapsed 16.9),**相隔 5 秒的两帧算到小数点后一位一致**。
     owner **既无 `tranquil_boots` 也无 `ancient_janggo`** ⇒ recipe 确实吃掉了组件。
   - **⭐ 时钟约定是测的不是假设的**:全语料 1471 个 modifier 里 **108 个 elapsed 大于自己那帧的 time**
     ⇒ `elapsed` 不从哨声起算,购入时刻 = `t - elapsed`;偏移是**几十秒**量级,
     所以 **11.9s 龄的物品可以直接定价**。已作为控制项断言。
   - **⭐ 「窗口外」当年对,但只对了 83 秒**:旧边界 t=690.5,购入 t=773.5。这**修正了** 08-27 那条注
     —— 它从**单枚 23:02 越帽帧**外推出「比旧语料能看到的任何东西都晚」,实际是 **12:53、14 级**。
     **从一枚帧外推出的「晚得多」,被两枚帧改成「晚 83 秒」。**
   - **⭐ 活下来那条腿换了地基**:从「移速不叠加」这种 Dota 规则断言,换成**本仓源码读数** ——
     `_stillNeeds` 有鞋时拒买基础鞋,**除非** target 在 `tBootsUpgrades` 白名单里,
     而 `item_boots_of_bearing` **就在里面**,`item_arcane_boots` 又在 `Item['tEarlyBoots']` 里 ⇒
     **在 arcane 线上留着终点 = 故意把那道门关掉**。三条事实逐条断言。
     (排除了一个担心:会跳过 `item_tranquil_boots` 的 `tSkipBoots` 在 **ARDM 换英雄**分支里,Turbo 走不到。)
   - **⭐ 两条此前从没写过的代价**:(1) **candidate 留着 `item_ancient_janggo` 却删掉它唯一的升级** ——
     出货线上鼓是**组件**,candidate 线上鼓是**终点**;鼓的充能不回,Bearing 的回。
     (2) 4225g 的终点出货线 12:53 实打实走到。**让删除仍然便宜的是光环实测覆盖很薄:8 个 ally-frame 里 1 个**
     (4 中 1 / 4 中 **0**),**写成天花板** —— 哪天它 buff 半个队就变红,而不是让结论悄悄过期。
   - **变异 7 抓 + 1 对照**;M3/M4 动 `bots/` 后逐字节还原。
     **⭐ 过程里被咬了一口**:M1 收尾用 `git checkout` 还原变异,**把本轮自己对该文件的改动一起还原了**。
     **在自己刚改过的文件上做变异,还原手段不能是 `git checkout`** —— 后续改用备份文件。
   - **诚实边界**:两枚 owner-frame **同一局** ⇒ 定的是一次购买的价不是分布;dump **不区分**光环施放者/接收者
     modifier,断言的是「非 owner 队友身上带着该 aura modifier」**不是**「buff 已被施加」;
     组件最后一次被看到在**别的局**(t ≤ 661.5),**没有任何一局被全程看着完成合成**;鼓的充能代价是论证不是测量。
   - **`cmboots` 的门与 armed 状态一个字没动**;`cmboots_RESOLVE_20260825T2130Z` 的 **RETURN_ON_C 未被触碰**,
     Route A / GH #190 仍是活着的重新入集路径 —— 本轮**不是**在重打那一仗。
   - 原始立案正文:
   - `tests/test_cm_pos5_boots.lua:439` 红,而这**正是该文件被写出来要产生的红**:
     `b50a7727` 的两帧里 **`npc_dota_hero_crystal_maiden` 自己就带着 `boots_of_bearing`**
     (`items = { null_talisman, magic_wand, observer_ward, boots_of_bearing, dustof_appearance, glimmer_cape, …}`),
     **焦点英雄本人**。
   - 同一对帧**同时**让 §3 的另一半到期:`WINDOW.max < 1500` 那条防线本来说
     「过了 ~11:30,4225g 的第五件就不再 out-of-window,那个零才开始有意义」——
     语料现在到 **t=790.4s(13:10)**。**out-of-window 的两半在同一刻一起过期**,
     而删除终点这个决定**目前骑在一个前提已经没有的论证上**。
   - 这不是计数重取,是**出装决定**(`hero_crystal_maiden.lua` 的 pos5 行),所以是完整一棒:
     给终点定价 → 要么带着新证据维持删除,要么把终点 gated 加回来;顺带在同一次 sweep 里
     重读 `C.cm_janggo >= 12` 与重钉 `WINDOW.max`。

-35. **回棒 ③ 剩下的三行 WK(见 -33)** —— 做的时候先看一眼 `test_wk_roshan_mana_floor.lua`
   的新读数。本轮重取时 **high-water MAX pool 459 → 471**,而 `wkrosh` 承重的
   「shipped 600 高过语料里每一帧的满蓝条」余量从 141 掉到 **129**。
   棒 ③ 里 `test_wk_roshan_mana_ceiling.lua` 的 crossing-level tail argument
   **和这个余量是同一个量的两种说法**,应当合并成一棒读,而不是各读各的。

-34. ~~**GH #274:trunk 是红的,而红的那两个数驮着本组已发表的判决**~~
   **2026-08-28T10:51Z done —— 两个 verdict 都 UNCHANGED;`bots/` 只改注释;无新 gate id;
   `state.json` 不动;零 AWS;不申请入集;不提 queue;**新开 GH #278**(交给协同组)。
   报告 `iterations/reports/hero/20260828T105124Z.md`。**
   - **Axe t15 NOT FLIPPED**:两枚新帧**都是干的**(level 14 / Call rank 3 / Hunger rank 4,
     两个 modifier 都没 live)⇒ 只加天花板不加观测,ceiling 1.94→2.33 与 14.00→16.00,
     live 计数 5 与 1 **一个没动**。Call 兑现 52%→**43%**,Hunger 36%→**31%**,方向仍成立,
     两率之比 1.44x→1.37x。**做了灵敏度**:再加多少干帧都翻不了它
     (`16+k > 11.65+0.965k` 恒真),能翻它的只有 **2 帧 Battle Hunger live**。
     (注:#274 正文把两侧**说反了** —— 文件断言的是 *Call* 近天花板。)
   - **WK Bone Guard 零完好且分母变宽**:0 carriers / 36 帧 / 19 带 modifier / sibling 19-of-19,
     shipped `X.ConsiderW` 在 36 帧上仍是 0 且 0 拒绝。盲区 20→22 **全额归因**:
     越门的两帧**就是**新加的两帧(WK level 11、Bone Guard 已 rank 4)⇒ **补集纹丝不动仍是 14**,
     那个 14 没动本身就是归因正确的独立佐证。
   - **⭐ #274 的红名单少了一半,而漏的方式可预测。** 它列 3 个文件,**实际 6 个**;
     多出来的三个文件名里既没有 `axe` 也没有 `talent`,而 run_tests 的 filter 是**文件名子串**
     ⇒ **红名单是用会漏的工具取的**。今后答「trunk 有几处红」要么跑全集,要么按
     `grep -rln "ls tests/fixtures" tests/*.lua`(53 个)枚举。
   - **#274 第 3 问已答:不要「重取」,按计数类型分流,而机制已在仓库里。**
     纯分母/纯名字普查 → 迁 `corpus_scale.ratchet`/`universal`(本轮迁了
     `test_focus_innate_index_anchor.lua` 与 `test_cm_ability_index_binding.lua`,
     「N of N」改 `universal` 是**严格变强**);驮 verdict 的计数 → **保持等式**,
     且必须由读它的那个组重取,加 fixture 的一轮**没有能力**替别人重取;
     加 fixture 的一轮**不重取但必须交棒**。6 个红里 **3 个属于第一类,根本不该响**。
     「corpus fingerprint」**不必新造**,`FLOOR`+`ratchet` 就是,缺的只是采用率。
   - **第二条(python 62→64)本轮已自绿**:它现在写成「未跌破 62」的 ratchet 形式,
     harness/总监那半无需再动 ⇒ **#274 可以关**。

-33. **棒 ③ 剩下的三行全是 WK,建议与 #274 的 WK 那半并成一棒**
   - `test_wk_roshan_mana_ceiling.lua`(crossing-level tail argument,`wkrosh`)/
     `test_wk_bone_guard_thresholds.lua`(untrained-stub-is-turbo-reality claim)/
     `test_wk_q_aim_preflight.lua`(level distribution note)。
   - `corpus_scale.lua` 与 `test_level_gate_census.lua` 归 harness/总监(GH #236 管排序),本组不认领。

-32. ~~**棒 ③ 第 4 行:`test_focus_build_level_legality.lua` 的 scope bullet 用两条论证豁免 t20/t25,两条都退休了**~~
   **2026-08-28T07:47Z done —— `bots/` **零行改动**;无新 gate id;
   `state.json` 新增 `levelpremise_focusbuild_20260828`(`gated:false`);零 AWS;不申请入集;
   **不提 queue**;**新开 GH #274**。报告 `iterations/reports/hero/20260828T074756Z.md`。**
   - 第一条论证(天花板)作废,**落点刺眼**:已录快照里 crystal_maiden 22 / zuus 23
     **正落在它宣称够不着的 21–24 停车带里**。
   - **第二条论证死在自己的测量上**:「by then there is nothing else in the queue」**可测的假** ——
     七行焦点构筑全跑,队列到 **23** 位,选中的在 **10/15/18/19**,放弃的四半在 **20–23**,
     **bot 每一个都向引擎要过**(把 lion 那轮的读数推广到全部七行)。
   - **换上的判据一句等级都不看**,并**断在 25 级**上,故不可能靠天花板回来而被满足。
   - **变异 5 抓 + 1 对照;M1 先逃过 4a**(`nil == nil` 恒真)⇒ 补非空断言后双抓。
   - **下一棒**:**GH #274 本组那半**(见 -34),之后回棒 ③ 的三行 WK(见 -33)。

-31. ~~**棒 ③ 第 3 行:`test_lion_hex_talent_slot.lua` 的头注与它自己的 §6 对着说了一天反话 —— 而清它买到的是「结构性不等于 bot 从来不要」**~~
   **2026-08-28T04:48Z done —— `bots/` **零行改动**(一个英雄文件都没碰);无新 gate id;
   `state.json` 新增 `levelpremise_lionhex_20260828`(`gated:false`);零 AWS;不申请入集;**不提 queue**。
   报告 `iterations/reports/hero/20260828T044807Z.md`。**
   - **入口是上一棒点的名**:01:58Z 写明「优先 `tests/test_lion_hex_talent_slot.lua` ——
     §6 已在 08-27 重推过,但登记表那行仍带未更正的数字站点」。
   - **⭐ 文件在自己内部矛盾了一天。** §6 08-27 已重推(域为空,理由从「语料够不到 25 级」
     换成「t25 取 `[7]` ⇒ `talent8` 永不 trained」),**头注的 ⚠️ LIMIT 块没跟着**,
     还留着承重的最后一句「§6 变红就是它变得可提的那一刻」—— **结构性的空不会因为多收帧就不空**。
     **这正是登记表 §3 的形状(`hero_zuus.lua` 头注对着 930 行外的正文说反话),
     而 §3 的扫描范围只有 `bots/`** ⇒ 这次是数字清单恰好抓到的,范围注释已就地补。
     **处置不变**(`lionhexaoe` 不 arm / 不入集 / 不提 queue),**变的是它不再等收割**。
   - **⭐ 本轮真正买到的读数:出货队列真的会去点那半天赋。** 驱动**真的**
     `J.Skill.GetSkillList`(参数从加载时的真实调用截获):`GetTalentBuild` 返回**八行**
     (`[1..4]` 选中 / `[5..8]` 放弃),`GetSkillList` 把放弃的接在后面 ⇒
     Lion 的队列位是 **10/15/18/19 = 选中**(不是 20/25,因为技能行 15 条用完会提前插),
     **20/21/22/23 = 放弃的四半**,而 **23 就是 `sTalentList[8]` = `special_bonus_unique_lion_2`**,
     `talent8` 绑的那一个。加上升级阶梯的兜底分支
     (`ability_item_usage_generic.lua` 的 `elseif not IsHidden() and botLevel >= required`)
     **不查 `CanAbilityBeUpgraded()` 就发 `ActionImmediate_LevelAbility`**
     ⇒ **让 `talent8` 保持 untrained 的是游戏在拒绝一个本仓真的发出的请求。**
     §4b 的「门要留着」于是从「关于没人做过的改动的话」变成**对今天就在发的请求的守卫**,
     并堵死了后来者最便宜的错误动作(把 helper 和十五个调用点当死代码删)。
   - **诚实边界**:引擎接不接受**不判也判不了**(`print()` 到不了控制台);升级分支是**源码读数**
     (`AbilityLevelUpComplement` 是文件内 local,无导出句柄,同 `test_lategame_talent_visibility`
     记的限制),断言窄到「发命令那条分支里没有 `CanAbilityBeUpgraded()`」;
     天赋**名**来自 `tests/mock/talent_slots.lua`(mock bot 的 slot > 5 为空),
     技能行/天赋行是出货文件自己的;队列位是**技能行长度的算术**,长度一变位置就动。
   - **⭐ 变异 4 抓 + 1 对照**:M13 `GetTalentBuild[8]` 恒 7 / M14 `GetSkillList` 去掉
     「技能行用完」子句 / M15 兜底分支加 `CanAbilityBeUpgraded()` / M16 lion t25 改回 `{10,0}`
     全 CAUGHT;M17 只重写头注 ESCAPED(设计如此)。变异后 `bots/` 全还原。
   - **登记表**:删行、天花板 **7 → 6**、`CLEARED` 写下重读决定了什么;
     重扫后本文件 hits=2 / **uncorrected=0**,仍带未更正站点的 6 个与天花板逐位相符。
   - **顺手记下(非本轮造成)**:临时 `pairs()` 跑法让 `test_cm_arcane_aura_passive.lua` 红一例,
     走**真正的 runner** 是 **16/0 绿** —— 差别是用例执行顺序,而它是 16 个共用同一个物理
     `soak_side.lua` 开关的 gate 测试之一 ⇒ **GH #229 同族,方向同样是「凭空多出失败」**。
     **临时跑法不是 runner,别拿它的红去开 issue。**
   - **下一棒**:棒 ③ 剩 **6 行**(本组欠 4),**优先 `tests/test_focus_build_level_legality.lua`**
     —— 它的登记理由是「scope claim argued from the zero」,而连着两轮的替代判据都是
     **「能不能取到 = 出装,不是等级」**,这一行被它改写得最直接。

-30. ~~**棒 ③ 第 2 行:`test_wk_fact_anchor.lua` §4 的读法被判**作废**(不是答错),而替代它的判据从来不看等级**~~
   **2026-08-28T01:58Z done —— `bots/` **零行改动**(一个英雄文件都没碰);无新 gate id;
   `state.json` 新增 `levelpremise_wkfact_20260828`(`gated:false`);零 AWS;不申请入集;**不提 queue**。
   报告 `iterations/reports/hero/20260828T015816Z.md`。**
   - **入口是上一棒自己点的名**,不是自选:22:53Z 写明「优先 `test_wk_fact_anchor.lua` ——
     它的 §4 是 t20/t25 的 STRUCTURAL 读数普查,本轮判决直接改写它的前提」。
   - **⭐ 判掉的是问题不是答案。** §4 与普查一起登记的读法**每一句都转在 UNREACHABLE 上**;
     GH #235 拿掉「够不着」之后,「**够不着要花多少钱**」**是空的**。计数活,读法死。
   - **⭐ 替代判据:出装,不是等级。** 每档只点一个天赋 ⇒ structural 读数变死当且仅当
     **这个英雄自己的 `tTalentTreeList` 不点它绑的那格**。新 §4b 驱动**真的**
     `J.Skill.GetTalentBuild`,**把 08-22 同一个桶里的 zuus 与 lion 劈成相反两半**:
     **zuus `talent7` 点**(槽 7 = `unique_zeus_5` = `lightning_bolt/aoe_radius 325`)
     ⇒ 25 级起地面施法**真的会发生且是重点**,而它 08-22 被明文归进「不产生可观测代价」;
     **WK `talent6` 点 ⇒ 20 级起活**;**lion `talent8` 不点 ⇒ 结构性死**。
   - **⭐ 这是别人指名欠这个文件的账**:`test_focus_talent_anchor.lua` §4a 点名把它转过来,
     而本轮之前**全仓没有断言把 structural 普查与出装交叉过**。
   - **⭐ 交出去、不自行扩**:四个非焦点英雄**保留计数、失去判决**;
     `hero_warlock.lua:532` `talent6:IsTrained() and false` 最尖 —— 等级论证没了之后,
     **字面 `false` 是唯一还在杀那条分支的东西**。
   - **诚实边界**:「点得到」≠「绑对了」(zuus 第二问穿 `sAbilityList[2]`,GH #203 实测下标非槽位,
     **刻意不断言**);仍无真实帧;lion 与 WK 天赋字面量今天相等,这里分不开,靠 `idx` 承担。
   - **⭐ 变异 5 抓 + 1 对照**;M3 是新加 `picks` 列的理由:三个英雄 t25 **全解到 `[7]`**,
     只断言 `trained` 时「读错英雄字面量」**三问全蒙对**(实测)。
   - **下一棒**:棒 ③ 剩 **7 行**(本组欠 5),**优先 `tests/test_lion_hex_talent_slot.lua`**。

-29. ~~**棒 ③ 开工:登记表清掉第一行 —— 而清它的那份证据,同时判掉了棒 ② 留下的岔口**~~
   **2026-08-27T22:53Z done —— `bots/` **零可执行行改动**(`hero_skeleton_king.lua` 只加注释块);
   无新 gate id;`state.json` 新增 `talentvis_20260827`(`gated:false`);零 AWS;不申请入集;
   **不新提 queue**(把已 routed 的 `hero-21` 就地收窄)。报告 `iterations/reports/hero/20260827T225311Z.md`。**
   - **入口是棒 ③ 的选行,不是自选题**:`PENDING` 九行里挑 `test_wk_bone_guard_talent_bypass.lua`,
     因为**只有它的重读会改变一个已发表判决的状态** —— 它的 §5 **自己写下了重开触发器**
     (「GH #108 把 cap 10→25 是最可能让它变成可支付问题的改动」),而**那个触发器早已扣动、没人回来看**。
   - **⭐ 判掉 19:58Z 自己留着不判的岔口,而且是零成本。** GH #235 那枚后期帧就停在
     `iterations/pending/`(被 GH #236 挡住,**不是本组的球**),**读一个停着的文件不花钱**。
     十个英雄 **22–27 级**:按出货升级队列**必然已花掉 36 个天赋点**,那一帧**只显示 8 行、
     全通用、unique 0**;**jakiro 24 / necrolyte 25 / venomancer 24 三个整个为空**。
     **H2 造不出这个** —— H2 说 bot 只点通用行,而**通用行是看得见的行**。
     ⇒ **H1(量具)成立且充分**;保守读法(只数 t10+t15)仍是 **20 中缺 12**。
   - **⭐ 后果**:**TALENTPRICE 五轮不作废**(它们怕的正是 H2);五轮各自的「没有一枚帧能证实」
     **从观察升格成机制**;登记表天花板 **9 → 8**,清行按登记表自己的规矩**写下重读结论**而不是删句子。
   - **⭐ 一条已发表推断的更正**:GH #260 的「没有任何一帧带两个天赋」**对 `tests/fixtures/` 仍成立**,
     但**不是管道的性质** —— dragon_knight 26 级带两行。「每个英雄最多一行」又是那个 10 分钟 cap。
   - **⭐ `must` 这一列是模型不是观察,所以它被拿去跑了出货代码**:`GetSkillList` 把四个天赋选择
     放在队列位 **10/15/18/19**,而升级只在 `botLevel >= GetHeroLevelRequiredToUpgrade()` 时弹队首
     ⇒ 约束是档位等级本身。§1 驱动出货函数,并从**真正执行升级的那条 `if` 的条件里**取门。
   - **⭐ 变异 12 抓 + 1 对照,其中三条先逃,是同一族错误的三个面**:
     (M6)门的字符串在文件里出现两次,第二次在兜底分支 ⇒ **grep 整个文件在真门被拿掉后照样绿**;
     (M7)`isRealAbility()` **上面的文档注释按正确顺序写着那两个字符串且永不移动** ⇒
     扫原始文件 = 把自己的文档读回来当代码(与 `facet_settlement` 的 `live_source` 同一课,换了门语言又交一次);
     (M11)`snakeFromClass` 的**定义**还在 ⇒「文件里提到它」永远为真。
     **共同形状:断言必须运行/读取它谈论的那一个东西,而不是它的名字出现过的地方。**
   - **诚实边界**:一帧一局,36 不是速率;队列因别的原因卡住会**压低** `must`(故保守地板单独断言);
     机制那条是**源码读数**——被丢掉的实体不留痕迹,**没有 fixture 能目击丢弃**;快照来自停放文件,
     #236 落地后 census 从新位置读出同样的行,**测试不用动**。
   - **下一棒**:棒 ③ 还剩 8 行(本组欠 6),**优先 `test_wk_fact_anchor.lua`**——它的 §4 是 t20/t25
     的 STRUCTURAL 读数普查,**本轮判决直接改写它的前提**;`hero-19`/`hero-20` 仍 pending,
     `hero-21` 已收窄未关;WK `ConsiderQ` 的 `nDamage` 修复仍等归档扫描。

-28. ~~**新轴 `TALENTBLIND`:冻结帧语料从来没有见过一个英雄专属天赋(GH #260)**~~
   **2026-08-27T19:58Z done —— `bots/` **零可执行行改动**(`hero_skeleton_king.lua` 只加注释块);
   无新 gate id;`state.json` 新增 `talentblind_20260827`(`gated:false`);零 AWS;不申请入集;
   **新提 queue `hero-21`**(重新导出一局归档 .dem,零 EC2)。**
   - **入口不是自选,是把上一棒的边界当成问题。** 棒 ②(TALENTPRICE)五轮每一轮都在诚实边界里写
     「本仓没有一枚帧显示这个天赋真的被点了」,五轮都当背景。本轮问那句话背后的问题:
     **本仓的帧,能不能显示一个天赋被点了?** 答案**对两个种类不一样**。
   - **⭐ 105 fixture / 960 英雄-帧 / 67 次天赋目击 —— 全部是通用行,`special_bonus_unique_*` 0 次**,
     任何英雄任何等级,**含一个 19 级 Viper**(按规则手里有三个已点天赋);**没有任何一帧带两个天赋**,
     9 个 ≥15 级帧(游戏保证 ≥2)**一个都没带**。⇒「这个 unique 天赋点了没有」**语料只会回答 0**,
     **而那个 0 不是证据**。**与 GH #238 同形**:零是量具的性质;区别是 #238 的零来自 10 分钟 cap
     (可以拿掉),这一条来自**天赋这一维度整个不可观测**。
   - **⭐ 载体是一个三比二的分裂,不是一句缺席。** 焦点五的天赋表**都是单行**(与位置无关),
     出厂 t10 可离线判定,解码用 `aba_skill.X.GetTalentBuild` **自己那一行**
     (`{0,10}`→slot 1、`{10,0}`→slot 2;测试钉住)。**而语料反过来验证了这个解码三次**:
     CM `hp_200` **15/15**、zuus `hp_200` **10/10**、lion `movement_speed_20` **1/5**(通用,见得到);
     axe `unique_axe_8` **0/10**、WK `unique_wraith_king_facet_1` **0/5**(专属,一次都见不到)。
     **分界线是种类。**
   - **⭐ 两个解释从 dump 里完全等价,本轮不下结论**:**H1 量具** —— `isRealAbility()`
     (`dumper/main.go`)在「保留已升级天赋」之前**无条件**丢弃类名含 `Special_Bonus_Base` /
     `Special_Bonus_Attributes` 的实体,而**那一行只可能作用在已升级的实体上**(未点的下一行就被
     `level > 0` 丢了);旁证:**活下来的是类名不是 KV 名**(`special_bonus_h_p200` vs KV 的
     `special_bonus_hp_200`)。**H2 世界** —— bot 从来没点过专属天赋,点数被压着。
     **后果差一个数量级**(H1:所有语料天赋读数都是瞎的;H2:**TALENTPRICE 五轮买的是没人点的行**,
     而 Axe 与 WK 的出厂 t10 正好在这一侧)。
   - **⭐ 最接近判决的一格,以及它为什么还不是判决**:**27 个 fixture 在同一个冻结瞬间里既显示
     一个英雄的天赋、又对另一个 ≥10 级且点数对不上的英雄显示为空** —— 量具不可能在同一帧里
     既瞎又不瞎。最尖的在焦点五:**Lion 今天 t10 是通用行**,语料**一帧显示了他这个天赋**、
     **另外四帧(11 级、少一个技能点)什么都没显示**;`f_260820_102030` 那一帧里 CM 与 Zeus 的通用
     t10 都在,**同帧 Lion 是空的**。**诚实边界**:只有在「那四局(08-20)当天 Lion 的选择与今天相同」
     时才是判决,而**本容器 git 历史从 08-26 开始**,查不了 ⇒ 写成棘轮不写成结论。
   - **独立的点数账**(与名字无关):`缺口 = 等级 − 可见技能点 − dump 天赋数`,
     **228 个 ≥10 级帧里 79 个缺口 ≥1**。**下界不是测量**(facet 赠送技能与学来的分不开,
     把缺口压低;分布里那 66 个 `+1` 就是它反方向的表现)。
   - **对 WK 的后果(已就地界定,未撤回)**:`sTalentList[6]` 是**焦点五唯一一个决策层读得到的天赋**,
     GH #17 块的「从 20 级起旁路是活的」是**从 KV + 等级读数**出发的论证,**只要 slot 6 还是专属名
     就永远只能是这个** —— 没有任何一帧能证实它触发过。论证本身不撤(它本来就没靠帧)。
   - **⭐ 本轮把上一轮的近失机械化**:census 在 fixtures/帧数/目击数任一低于地板时**exit 2 拒绝出报告**,
     测试 §0 再断言一遍并加**快照自洽**(`SIGHTINGS` 求和 == `CORPUS.sightings`)——
     本轮所有结论都是「某个计数是零」,**正是空解析会自动满足的形状**。
     **变异 10 条:10 抓 + 1 对照。**
   - **顺手查过再放下**:`ConsiderQ` 的 `nDamage` 修复(上一棒交出的三棒之一)**域在本地语料里是空的** ——
     钉帧要「Q 冷却好 + 射程内有一个有效血量落在 75–126 的敌人」,**13 个 WK-subject fixture 一个都没有**
     (最近的 `f_225947_wk_trade_kite` 是 Lich 299 血,而那帧 Q 还有 13.4s CD)⇒ 不落地,等归档扫描。
   - **下一棒**:`hero-21`(已提);**棒 ③(`tests/` 等级前提登记表,9 个文件)仍未动**(连续第三轮);
     `hero-19` / `hero-20` 仍 pending。

-27. ~~**`TALENTPRICE` 第五轮(收官):skeleton_king 的 t20/t25 —— 两行都留;而产出是「那道 FACET 门根本不存在」(GH #255)**~~
   **2026-08-27T16:51Z done —— `bots/` **零可执行行改动**(hero 文件只改注释);无新 gate id;
   `state.json` 新增 `wkt20t25_20260827`(`gated:false`);零 AWS;不申请入集;
   条件 (a) 骑已 pending 的 `hero-19`,**另提 `hero-20`**(归档扫描,零 EC2)。
   **棒 ② 到此 CLOSED**(lion → axe → zuus → crystal_maiden → skeleton_king)。**
   - **入口是本组 13:55Z 自己交出的棒 ②**,章程写明 skeleton_king 最后 —— 因为他的 t20/t25 备选
     ([2] / [6])是 **FACET 行**,而 `hero_skeleton_king.lua` **把一句拒绝写进了源码**:
     「本仓没有任何东西读得到游戏 roll 了哪个 facet —— **先把这个了结再定价**」。
   - **⭐ 问的是一个英雄,答出来的是整张表。** 新工具 `tools/agent/facet_census.py` 从
     `npc_heroes.txt`(取天赋槽序用的**同一个文件**)读 `Facets` 块:**129 个英雄、339 条 facet 条目里,
     0 条**点到 `special_bonus_*` 或天赋槽区间 `AbilityIndex 10..17` —— facet 块里只有
     `Icon/Color/GradientID/Deprecated` 加一个**授予技能**的子块(有活 facet 的英雄也一样)。
     ⇒ **任何 facet 都动不了任何英雄的天赋槽**,这道门对整条轴从来没关过,**前四轮回溯地也不欠它**。
     每英雄那半:**WK 恰好两条 facet,两条都 `Deprecated true`**;Axe 2 / Zeus 2 / Lion 2 / CM 4
     **全 Deprecated** ⇒ **焦点五加起来零条活 facet**。
   - **⭐ 那两条废弃 facet 是两条已记录事实的机制,不是杂物**:`..._facet_bone_guard` 授予
     `skeleton_king_bone_guard` ⇒ **这就是骨盾今天是朴素 `Ability2` 的原因**;`..._facet_cursed_blade`
     授予 `skeleton_king_spectral_blade` ⇒ **「那个名字每次加载解析成 nil」从观察升格成原因**。
     **对定价的后果**:[2]/[6] 各有一半落在 spectral_blade 上 ⇒ **那一半是死的**,活的恰好是
     `blast_dot_duration +2` 与 `min_skeleton_spawn +5`,**只给这两半定价**。
   - **⭐ t20 留 [6],焦点五里最强的一个「留」**:[6] 是**这棵树上唯一一个决策层读得到的天赋** ——
     `talent6:IsTrained()` 是 `X.ConsiderW` **两条分支上的 OR 旁路**,旁路掉的正是本文件 GH #17 块
     自己论证「几乎够不着」的弹药阈值(level 7 上限就顶到 8,而批测读他 **15 补刀 / 0.6 人头**)。
     点 [6] = 骨盾从「等填满」变成「**按 42s 平 CD 放、保底 5 只**」。挪到 [5](纯 +50 攻速)
     **会把那句谓词全局冻成 false** —— Lion GH #166 的形状,**且这里还多赔上修复本身**。
   - **⭐ t25 留 [7],两边都对决策层隐形 ⇒ 体量说了算**,三条同向:(i) **量子化** —— [7] 是速率
     (**+66.7% 暴击频率**,每次挥手都付),[8] 是事件(要死一次、900 内有敌人、rank3 **120s** CD),
     而 t25 的窗口**开在一局 turbo 的最后几分钟**(GH #235 那枚帧:24.9 分钟局、23:02、26 级)
     ⇒ **[8] 期望赔付 ≤1、很容易是 0**;(ii) **看净不看毛** —— [8] **不是加是换**,顶掉出厂的
     600 内 4s/-75% 减速,而 `reincarnate_time = 3` ⇒ **1.6s 晕在他还站不起来时就过期了(早 1.4s)**,
     被顶掉的减速**在他落地那刻还剩 1 秒**;(iii) 出装花在 [7] 的轴上(唯一伤害技能就是致命一击)——
     **这正是 Axe t20 那轮反向得出的那半论证,尺子相同、英雄不同**。
   - **⭐ 顺手拓宽(未取)**:`ConsiderQ` 的 `nDamage` 硬编码**从 10 级起就陈旧**,不只是标度错 ——
     出厂 t10 取 [2] = `blast_dot_duration +2`,而 `blast_dot_damage` 是**每秒** ⇒ **dot 翻倍**,
     诚实值 120/180/240/300 → **160/260/360/460**,方向是「以为杀不掉」。
   - **⭐ 本轮自己踩住的坑(近失,方向最危险)**:census 的英雄头正则**第一版漏了 `re.M`**,
     零个英雄匹配,于是打印 `focus five with a LIVE facet: none` —— **和正确运行的最后一行一模一样**。
     **一次读到零的解析,和结论达成了一致。** 修法两道:工具 `MIN_HEROES` **拒绝出报告**、
     测试 §0 断言 `facet_entries > 200`。**变异 10 条:9 抓 + 1 对照。**
   - **诚实边界**:**本仓没有一枚 25 级 WK 帧**,窗口长度由**一局** post-cap 局推得(测试不断言窗口);
     「重生触发时 900 内有几个敌人」**没人量过** —— 那个数高则 [8] 变好,应重新定价;
     **唯一源 + 明显的第二意见是陷阱** —— Valve 的 `datafeed/herodata` 对**每个**英雄都答
     `facets: []`(7/7,含 Bristleback,而它 KV 里确有 facet 机制)⇒ **用它读 WK 会对得起结论、错在理由**;
     **「facet 到处都死了」是假的** —— 32 条活 facet 分布在 12 个英雄上。
   - **下一棒**:**棒 ② CLOSED,棒 ③(`tests/` 等级前提登记表,9 个文件)仍未动**。**交出去三棒**:
     `hero-19` 的 WK 那一格(骑已 pending 的请求)、**已提的 `hero-20`「重生触发频率 + 触发帧 900/600 内敌人数分布」**
     (唯一能诚实重开 t25 的读数)、`ConsiderQ` `nDamage` 修复(与 Axe `hero-2`、CM `ConsiderW` 同族)。
   - **可复用判据**:12 个活 facet 英雄里 **Lich / Tidehunter / Witch Doctor 在候选英雄池里** ——
     它们进焦点五那天**只继承全局那半(槽位不变),不继承每英雄那半**,而且活 facet 还能经
     `required_facet` 卡天赋**取值**(`special_value_key_census.py` 的地盘)。**已写成断言不是散文。**

-26. ~~**`TALENTPRICE` 第四轮:Crystal Maiden 的 t20/t25 第一次定价 —— 棒 ② 里第一次两行都翻(GH #251)**~~
   **2026-08-27T13:55Z done —— `bots/` 可执行行改动 = 两个 table 字面量(t20 `{10,0}`→`{0,10}`、
   t25 `{0,10}`→`{10,0}`);天赋行 ⇒ **真行为改动、不 gate**;无新 gate id;`state.json` 新增
   `cmt20t25_20260827`(`gated:false`);零 AWS;**不提新 queue 请求**(条件 (a) 骑已 pending 的
   `hero-19`);不申请入集。**
   - **两行为两个不同的理由动,这也是它们能同轮动的原因。**
   - **⭐ t25 是把一条已经在活着的失明带拿掉,不是造一条。** `X.ConsiderW` 手算
     `nDamage = ( 100 + nSkillLV * 50 )` = 150/200/250/300,**恰好等于** KV 的
     `damage_per_second 100 × duration 1.5/2/2.5/3` —— **对,而且只在没有天赋碰时长时对**。
     而 t25 原本取的 [7] **正是 +1.0s 时长** ⇒ 4 级真伤 **400 对 kill-check 的 300**,
     **25 级起低估 25%,方向是「以为杀不掉」⇒ 放掉能拿的人头**。[8] 落在 `nova_damage` 上,
     而 `ConsiderQImpl` **实时读它**并交给 `FindAoELocation` ⇒ 引擎的折算(GH #228)自己走到击杀判据:
     **260→560 且决策层知道**。**与 Axe t25 同形、符号相反。** 放弃的是 1 秒单体禁锢(写在前面)。
   - **⭐ t20 用的是 t10/t15 那把 REACHABILITY 尺**:[6] 计价在 **channel-seconds held**,
     而本仓逐帧读过的两次冰封禁地频道**一次砍到 6%**(0.6s 被晕,5.9s 后死)、**一次约 10%**
     (26% 血带晕开引导,1.0s 后死),**两帧就钉在这个文件自己的守卫注释里**,而 `cmrguard`/`cmrcap`/
     `cmrself` **全都还是 soak candidate ⇒ 发布默认恰恰就在那些情形下开大**。[5] 计价在
     **花在技能上的法力**(Valve tooltip 本轮买到:「花在技能上的一部分法力转成物理护盾」),
     20 级约 70%→90% = **每 100 法力多 20 护盾**,**零瞄准零引导**,**而且在 600 法力的大招上照付
     ⇒ 开引导那一下自己值 +120 护盾**。付得起的理由与 Axe t20 同:**翻转对决策层惰性**
     (无 `freezing_field/damage` 读、无内置技能句柄 —— 它 51/51 帧 hidden,GH #206)。
   - **⭐ 诚实边界**:频道证据 **n=2 且都在 20 级以下**(界定形状不是费率);护盾**只挡物理**;
     `hero_levelup` 起算点让 ~70% 浮动 2 点(比值不动);**CM 的 `Facets` 四条全 `Deprecated`
     —— 这正是它今天是朴素 `Innate 1` 的原因**,挂回 facet 就得重新定价(**skeleton_king 那一族的
     可复用判据**);Valve 默认 build 20 级也取 [5],**但它 t10 与我们不一致 ⇒ 旁证不是论证**。
   - **⭐ 本轮自己踩住的坑**:公式被写进了 hero 文件头注 ⇒ **所有源码扫描必须跑在剥掉注释的源码上**,
     否则**扫描把自己的文档读回来当代码**。**变异 9 条:6 抓 + 1 按设计放行(iff)+ 1 对照 + 1 交叉**。
   - **下一棒**:棒 ② **只剩 skeleton_king**(FACET 行);棒 ③ 未动。**交出去两棒**:`hero-19` 的 CM 那一格
     (20/25 级占比 + 那两点花在哪)、`ConsiderW` 硬编码的一般修法(与 Axe `hero-2` 同族,**iff 棘轮兜着**)。

-25. ~~**`TALENTPRICE` 第三轮:Zeus t20/t25 第一次定价 —— 两行都不改(棒 ② 的第三个英雄)**~~
   **2026-08-27T10:55Z done —— `bots/` **零可执行行改动**(两个英雄文件都只改注释);
   无新 gate id;`state.json` 新增 `zuust20t25_20260827`(`gated:false`);零 AWS;
   不提 queue 请求;不申请入集。**
   - **入口是本组 08:15Z 自己交出的棒 ②**,不是自选。**t20 保留 [5]、t25 保留 [7]。**
   - **⭐ t20:决策层对两边都瞎,所以它才是战斗力题。** [5] 是**焦点五唯一一个收益落在
     本文件已经在问的 key 上**的天赋(折进 `arc_damage`,`ConsiderQ` 读的正是它)——
     **但那个读数只有一个消费方,坐在 `BOT_MODE_LANING` 里**,而 t20 在 20 级解锁。
     **折算够得到,门已经关了。** [6] 折进 `ministun_duration`,**全仓零处读**。
     平局按体量裁:Arc 两份 build 都点满、1.6s CD、九个分支竞标,+60 **每一跳都付**(+33%)。
   - **⭐ t25 是 Lion 那条坏接线的「好双胞胎」**:`talent7:IsTrained()` 换 cast shape,
     **而下标 7 确实是 AoE 天赋**(GH #166 在 Lion 上是下标 8 套 `UNIT_TARGET`)。
     **取 [8] 会把这个谓词全局冻成 false**,把本文件唯一一处「天赋改变命令」变成死代码。
     **[8] 的真优点也记下**:`AbilityCharges` 走 `IsFullyCastable`,**零决策层配合** —— 输在体量。
   - **⭐ 真正的产出是量具**:`hero_zuus.lua` 那句 `never trained in turbo (GH #84)`
     **在被 02:15Z 改成相反话的表头下面 930 行**,而登记表的「bots/ 恒为零」一直读作零。
     **两个独立漏洞**:**第十种措辞**(不引数字 ⇒ 数字指纹全瞎)与**断句换行**
     (措辞在名单上,但**逐行扫描匹配不到跨行的句子**)。§3 = 钉措辞 + 扫行对 + 等式零 + anti-vacuum 7。
   - **⭐ 被实测否掉的便宜修法**:裸 `GH #84` 进指纹会**把 7 个只是引用出处的测试文件拖进登记表**,
     债从 9 抬到 16。**引用不是论证。** `tests/` 那 6 处**故意不上棘轮**(3 个文件都已在 `PENDING`)。
   - **⭐ 学费:M7 第一次跑掉了** —— 跨行测试**重新实现了拼接、没调用扫描器**,删掉拼接整套仍绿;
     anti-vacuum 6 又恰好擦边。修法两条,同一个回归抓两次。**断言必须运行它谈论的那个东西。**
   - **下一棒**:棒 ② 仍欠 **crystal_maiden**,**skeleton_king 最后**;棒 ③ 未动。

-24. ~~**`TALENTPRICE` 第二轮:Axe t20/t25 第一次定价 —— t20 `{0,10}` → `{10,0}`(棒 ② 的第二个英雄)**~~
   **2026-08-27T08:15Z done —— `bots/` 只改了一个 table 字面量(t20 那一行)+ 一段定价注释;
   天赋行 ⇒ **真行为改动、不 gate**;无新 gate id;`state.json` 新增 `axet20_20260827`
   (`gated:false`);零 AWS;**提了 `hero-19`**(归档扫描,零 EC2);不申请入集。**
   - **入口是本组 02:15Z 自己交出的棒 ②**,不是自选。Lion 05:30Z 先走是因为他那行压着活缺陷;
     **Axe 两行都没有缺陷 —— 这一轮真正的问题是「没有缺陷可修时,定价能不能得出『改』」。**
   - **⭐ 最该被拿走的一条:t20 用的不是本文件那把尺子,而这句话写进了源码并被测试钉住。**
     按 payoff REACHABILITY(决定了 t10/t15 的那把尺)**[5] 完胜** —— 纯属性块没有触发条件。
     改动换轴:**收益用什么计价、这套 build 花不花得出去**。[5] 计价在攻击力(本文件**零右键
     决策层**、两份 role list **都不买攻速/伤害装** ⇒ 不复利,1.7 攻击间隔下**不到 9 dps**)
     与血量(pos_3 前 ~8.5k 本来就全花在这根轴上);[6] 计价在**纯粹伤害** —— 护甲不减、
     **160→200 = +25% 打在主伤害源上**、且是他**唯一按敌人数量翻倍**的伤害,而那个状态正是
     `X.ConsiderQ` 专门制造的。**t20 解锁在一局 turbo 的最后三分之一,正是对面核心买到护甲的时刻。**
   - **⭐ 为什么量级判在 t20 付得起、t25 付不起**:`hero_axe.lua` **没有 talent5/talent6 句柄**
     ⇒ 这一翻**对决策层惰性**,只移动战斗力,**两个方向都造不出陈旧读数**。
   - **⭐ t25 留 [7],而且是决策层裁的不是口味**:[7] 的 +85 被引擎折进 `ConsiderQ` **已经在读**
     的 `radius`,而它就是 `nCastRange` ⇒ **多抓到人且知道自己多抓到**(315→400 = **+61% 面积**);
     [8] 的 +150 折进 `axe_culling_blade/damage`,而斩杀判据是**硬编码** `150 + 100*lv`,fold 够不到
     ⇒ **取 [8] 把已有斩杀盲带乘以七**(3 级 `(450,475]` 25 宽 → `(450,625]` 175 宽)。
     ⇒ **t25 在 `hero-2` 落地前不是自由选择**,已用一条 **iff 测试**焊住(字面量在 ⇔ 「乘以七」在)。
   - **⭐ 诚实边界:本仓从来没有一枚域内 Axe 帧。** 新工具
     `tools/agent/fixture_proximity_census.py`:105 个 fixture 只有 **10 帧 Axe、等级 1-11**,
     其中 **1 帧**在 helix 275 内有敌人 —— **这个读数不支持本次改动,原样记下;它也不是反证**
     (样本是为别的英雄冻的帧)。GH #235 那枚 23:02 后期帧**里没有 Axe**。
     +15 力量→血量按 22/点是**没核过 KV 的世界断言**,论证不依赖它。
   - **变异 8 条:7 抓 + 1 条对照**(M2 `{0,0}` 这次是**真捕获**,与 Lion 那轮相反 ——
     `{0,0}` 取奇数下标正是被否掉那个;M7「`hero-2` 落地但留着断言」**只被 iff 抓到**;
     M8 改写没上锚的注释**逃逸,设计如此**)。
   - **⭐ 一条免得把重叠读成冗余的登记**:新配对钉今天**不是** M3 的唯一捕手 —— zuus 是眼下
     唯一 t20 取奇数下标的焦点英雄,§2 通过 zuus 也抓得到。**它成为唯一捕手的那一刻,
     正是 zuus 的 t20 被定价到偶数下标那一轮,而 zuus 就是这根棒的下一个英雄。**
   - **下一棒**:棒 ② 仍欠 **zuus / crystal_maiden**,**skeleton_king 最后**;棒 ③ 未动。
     **交出去两棒**:`hero-19`(归档扫描,买条件 (a) 最低那一格,**按焦点五不挑英雄写**,
     因为后三轮定价共用同一个缺口)、t25 那一对交给 `hero-2` 的接手人。

-23. ~~**新轴 `TALENTPRICE`:Lion t20/t25 第一次定价 —— t25 `{10,0}` → `{0,10}`(GH #166)**~~
   **2026-08-27T05:30Z done —— `bots/` 只改了一个 table 字面量(t25 那一行)+ 注释;
   这是天赋行,所以是**真行为改动、不 gate**;无新 gate id;`state.json` 新增
   `liont25_20260827`(`gated:false`);零 AWS;不提 queue 请求;不申请入集。**
   - **入口是本组自己交出的棒**(GH #238 §六 的 ② ),不是自选;Lion 排第一是因为
     **他那一行上压着一个活的缺陷**。做完发现 **① 重开 #166 与 ② 是同一处编辑**,两棒一起还。
   - **⭐ 三条理由按「有多少是我们自己的」升序**:① +250 AoE 妖术是招牌 t25(**故意排第一
     并明说它最弱** —— 谁都查得到,不携带本地证据);② **这一条是我们的**:妖术是
     `UNIT_TARGET`,+250 半径**由引擎在施法时施加** ⇒ bot **零瞄准零预判**吃满;穿刺是**线性弹道**,
     是这英雄**唯一要打提前量**的技能,[8] 把它 500→1100 **提前量翻倍还多**
     ⇒ **两者不等价的方向恰好是对 bot 最要紧的那个**;③ 它把 #166 **构造掉**:每层只学一个天赋
     ⇒ `talent8` **结构性未学** ⇒ 15 处 `IsHexAoe` 处处答 false,而**对单位指向技能 false 就是对的**。
   - **⭐ 放弃了什么,写在前面不留作意外**:`'W-团控'` 那条挑扎堆目标的分支被跳过 ⇒
     **真拿到 AoE 妖术后不再优先挑扎堆**。是**少赚不是缺陷**(下面「最危险敌人」分支服务同一场团战,
     逐行读过),而且它是**放宽** ⇒ **正是 #166 §9 留给后来人的那个,交出去不吞掉**。
   - **⭐ 门的理由换了,结论没换**:`lionhexaoe` 留着不 arm。旧理由(语料没 25 级英雄)
     **继承自 GH #84 那个属于 10 分钟 cap 的零,02:15Z 已退役**;新理由**不依赖任何语料** ——
     `IsHexAoe` 在**第一句**就 return false,**走不到门那里**。**留着**是因为 t25 行与 V 社槽位顺序
     **都不是这个文件保证得了的**。
   - **t20 定了价没改**:本来就取 [6](30° 锥形),正是本组会 argue 的那边;[5](+20 Finger/击杀)
     **要先用 Finger 杀人才攒**,而它 20 级才到,在 ~20 分钟的 turbo 里没几次施法可攒。
     **记下来是为了让 [6] 不再读作「没人看过的上游默认值」。**
   - **测试:反转而不是删除。** §2 原来钉 index 8,**它的失败信息预言的正是这次改动**;
     新增**把 t25 的 `{7,8}` 成对钉住**(**M4 只被这条抓到**);新增 **§4b 三句源码散文棘轮**
     (钉的是**别处说不出来的东西:刻意没做的事**);§4 加一道防「反正是死的,清理掉吧」;
     **§6 重新推导** —— 语料断言留着但**改口量「收割滞后」,不再是域的裁定**。
   - **变异 11 条:9 抓 + 2 条复核过的对照**(M2 `{0,0}` 是**真 no-op**:算术判 `[1]==0`;M11 改局部名)。
   - **⭐ 学费(散文锚第四次,新原因)**:§4b 第一版把 `§` 写成 `\xc2\xa7`,而 **lua5.1 没有 `\x` 转义**
     ⇒ 锚**红在它要保护的注释上**。修法照旧:**承重句子在源码里不换行、锚在多字节字符前停住,
     绝不放松断言。** 另:变异回滚**一律从 scratchpad 副本**,绝不从 git。
   - **⚠️ 一条瞬态,不是本轮造成的,已交出**:一次自检报 python 套件 **39/2**
     (`ability_value_key_census`、`guard_implication_census`)。**两个单跑绿、完整 runner 两次 41/0,
     两次工作树里都带着本轮全部改动** ⇒ 不是这次改动;**一个假设实测证伪**(写出 `soak_side.lua`
     的 #229 共用开关形状 —— 仍全绿)。**成因未定** ⇒ **已开 GH #243** 交 harness 座位:
     **python 套件的假红在 #229 点名范围之外,而方向是同一个:凭空多出失败。**
   - **下一棒**:本组仍欠 ② 的 axe / zuus / crystal_maiden(**skeleton_king 最后** —— 两行是
     FACET 行而树里没东西读「摇到哪个 facet」)与 ③;**交出去两棒**:#166 §9 的放宽
     (需要**一枚 25 级 Lion 的帧**,已写进 #166 评论)、python 假红 → **GH #243**。

-22. ~~**新轴 `LVLPREMISE`:那个零是量具的性质,不是 turbo 的性质(GH #238)**~~
   **2026-08-27T02:15Z done —— `bots/` 五个焦点文件只加注释、零可执行行改动;无新 gate id;
   `state.json` 新增 `lvlpremise_20260827`(`gated:false`);零 AWS;不提 queue 请求;不申请入集。**
   - **入口不是新想的题**:GH #235/#236 是别的座位在开工前几小时开的,而它们说的那件事
     **点名了本组自己写在 `bots/` 里的话**。
   - **⭐ 承重读数**:GH #84 读到 `level >= 20` 在 **0/210** 个 hero-slot 上、high-water 19,
     **对语料是对的、对 turbo 是错的** —— 批测局在 10 分钟 economy cap 自终止,所以**够不到** 20。
     owner P3(GH #108)拿掉 cap 后第一枚帧(23:02、局时 24.9 分钟自然结束,GH #235)读到
     **十个英雄 22-27 级、high-water 27**,**三个是焦点英雄**(CM 22 / Zeus 23 / WK 26)。
     真实 turbo 局平均 ~20 分钟 ⇒ **这个前提对已发布产品也从来不成立**。
     它写在 **`bots/` 9 处(四个焦点文件)+ `tests/` 20 处(九个文件)**,好几处**不是脚注是裁定的论证**。
   - **⭐ 最该被拿走的一条:Lion,活的缺陷。** t25 行 `{10,0}` = **[8]** = 穿刺射程 +600,
     **恰好是让每一处 `talent8` 读数答 TRUE 的那一半**,而代码相信那是「妖术变 AoE」(#166;
     真半径天赋是 [7])。⇒ **25 级起** `X.IsHexAoe` 答 true、W 派发把 `UseAbilityOnEntity`
     换成 `UseAbilityOnLocation`,而 `lion_voodoo` 是 `UNIT_TARGET`。
     **#166 的「域为空」是在够不到 25 级的语料上量的 ⇒ `lionhexaoe` 不再是空域候选,重开 #166。**
   - **⭐ 第二条后果号是反的**:Axe 同时读 `talent7`/`talent8` 而每层只学一个,t25 行取 **[7]**
     ⇒ `talent7` **从 25 级起是活的**(加 0,#228 说这是对的 —— 但它原先还被「够不到」保护着,
     **现在折算论证是唯一撑着它的东西**);`talent8` **结构性未学**,那个 `nKillDamage` 项是
     **死代码**不只是读数为 0。接手 `hero-2` 的人两半都继承。
   - **一个白担心的忧虑,记下来是因为它是两个不同的断言**:消费方严格取队首、**不跳过升不了的
     队首**(唯一逃逸口 `botLevel > 25`)。驱动 `GetSkillList`:天赋落在位置 **10,15,18,19,20,21,22,23**
     —— **列表位置不是英雄等级,是花掉的第 N 个技能点**(消费方自己就这么读)⇒ 位置 18 = **20 级**、
     19 = **25 级**,分毫不差;位置 20-23 **永远不会被出队,因为没有第 20 个技能点**。
     **「尾巴是死重」真,「尾巴会卡住队列」假。** 第二十三条世界断言(登记不断言):
     技能点只在 1-15 与 10/15/20/25 发放 —— 它是让位置 18/19「意味着」20/25 级的唯一东西。
   - **为什么是登记表不是九次注释编辑**:`tests/` 那 9 个文件里前提**是裁定的论证**;
     混在一起会让**便宜的编辑冒充昂贵的重读**。⇒ **`bots/` 按等式钉在零未更正**,
     **`tests/` 是 9 个文件的天花板 + 封闭名单**(可降不可升、不许新文件加入)。
     **「更正」≠ 删引文**(与 anchor §4 同形);判据是块内 14 行内点名 GH #235 或 2026-08-27,
     外加**反真空断言**(`bots/` 必须仍有 ≥9 处引文存活)⇒ **不能靠删字通过**。
   - **变异 12 条:11 抓 + 1 条逃逸复核为真 no-op**(`i>=10`→`i>=9`:合取项 `i%5==0` 让第一个
     满足的 i 两边都是 10)。
   - **⭐ 学费**:**用 `git checkout --` 回滚的变异脚本连未提交的改动一起销毁** —— 跑 `bots/`
     那轮时它抹掉了本轮对四个英雄文件的更正(只有 CM 活下来,不在 checkout 名单里),七处编辑重做。
     **先存副本、从副本恢复,绝不从 git 恢复**;或变异前先提交。与铁律 10 的 stash/pop 同族。
   - **顺带一条实证**:CM 文件那条「没人持有勇气之靴是 OUT-OF-WINDOW 不是空」——
     23:02 那帧上**这个 CM 22 级、包里就有 `boots_of_bearing`**。**读法被证实不是被推翻**,
     但那个零现在**买得到**,下次该重量。
   - **刻意没做:一行天赋都没改。** 天赋改动不 gate = 每局 turbo 的真行为改动;
     **十个没论证过的选择不是在发现它们是活的那一轮里就改十个的理由。**
   - **下一棒(本组显式交出三棒,见 #238 §六)**:① 重开 GH #166;② 给十个 t20/t25 定价,
     一个英雄一轮,skeleton_king 放最后(两行是 FACET 行,而这棵树没东西读「摇到哪个 facet」);
     ③ 把 `tests/` 登记表从 9 往下做,每行是一条裁定的重读。

-21. ~~**新轴 `ABILVALUE`:同一个 `'value'`,读在**技能句柄**上(GH #232)**~~
   **2026-08-26T23:20Z done —— `bots/` 只加注释(73 行全是 `--`)、零可执行改动;无新 gate id;
   `state.json` 新增 `abilvalue_20260826`(`gated:false`);零 AWS;不提 queue 请求;不申请入集。**
   - **入口是本组上一轮自己登记的下一棒**(GH #228 §六.3),不是新想的题:那条明写着
     「本普查刻意排除的姊妹形状:7 处把 `'value'` 读在普通技能句柄上……**一处都没数过**」。
   - **⭐ 承重读数(8 处站点 / 7 个技能 / 6 个 GET / 零 AWS)**:技能的 special value
     **按 `AbilityValues` 的条目名取键**;长形式里 `value` 是**条目的内层键**,不是技能的条目。
     ⇒ 技能只有**自己拥有一个字面叫 `value` 的条目**才答得出(**那正是通用天赋块的写法**,
     这就是同一个字符串在一族句柄上答得出、在另一族上答不出的原因)。
     **7 个技能一个都没有 ⇒ 8/8 READS-ZERO。焦点五在这根轴上是 0 处**(#228 探针 ② 的负结果复核成立)。
   - **⭐ 最该被拿走的一条:号跟 #228 相反,这才是它值得单独数的原因。**
     #228 的 **21/21 死在安全侧**(加成没有第二个住处 ⇒ 引擎必折进基数 ⇒ 修它才是重复计数)。
     **这里什么都不折** —— 读数本身就是那个数,而那个数是 0:
     **5 处 UNDER**(0 伤害直接喂进 `J.CanKillTarget` ⇒ 斩杀分支永远不开火)、
     **1 处 OVER**(terrorblade 把血量代价读成免费 ⇒ 它下面的 HP 闸闩在空气上)、
     **2 处 FOLD**(唯二属于 #228 那种无害类型的)。**八分之二在安全侧,不是八分之八。**
   - **⭐ 而那唯一的 OVER 站点上,「显而易见的修法」又是错的,错在第二个方向**:
     它要的键是 `health_cost_pct` = **20,二十个百分点不是分数**,而那行**直接乘当前血量**。
     ⇒ **只换键**会把代价从 0 变成血量的 **20 倍**,闸从**恒真翻成恒假**。
     **修法是两处编辑(`health_cost_pct` 和 `/ 100`),绝不是一处** —— 只读「想要的键」那一栏
     的认领者会恰好发出错的那一半,所以源码写死了这句话、anchor §4 钉住它继续写着。
   - **两根独立的轴落在同一条分支上**(enigma 午夜凋零):① 本轴的静默 0;
     ② 它挂的天赋句柄**名字就错** —— `MidnightPulseRadiusTalent` 绑 `enigma_6`(改的是
     `enigma_black_hole/damage` +50),真正加这个半径的是 `enigma_9`(+200)。
     ② 是 **GH #223 §六.3 登记但没定过价**的线索,本轮定了价;两条都指向**删**。
   - **⭐ 序号是承重的(GH #221 的另一面)**:站点身份 = **(文件, 变量, 第几次读)**,不带行号。
     `hero_enigma.lua` 读 `Malefice` **两次而两次要的修法相反**(先要键 `stun_instances`,
     后要**删** —— 它已经折进 `enigma_2` 的 +4)。只按 (文件, 变量) 建键**只能给两行同一条指令,
     而两种选择各错一行**。**量出来的**:变异 M3(序号钉死 1)驱动后被抓。
   - **变异 17 条 17 抓**:普查 9(含**深度 4 的内层键被当成条目** —— 这一条会把结论**翻成
     它的反面并且报绿**)、棘轮 8(含**往 `bots/` 里塞一个新站点**、三处源码注释各删一次)。
   - **⭐ 学费(同族第三次)**:anchor 的 terrorblade 标记**第一次跑就红在它要保护的那条注释上**,
     因为「twenty PERCENT, not a fraction」在源码里**跨了注释换行**(#223 的 M8、#228 的撤回标记同形)。
     **对着散文写的断言必须对着不换行的散文写**;便宜的修法是**把承重的那句话在源码里单独占一行**,
     不是放松断言。
   - **刻意没修,理由不留成默契**:五个英雄全是非焦点,而每处修复都是**真行为改动**
     (0 → 真数值进斩杀谓词;或一道本来闩不住的代价闸开始闩住),**不是** #192/#223 那种可不 gate
     的空指针守卫 ⇒ 要 gate + 真实帧,而这五个英雄**没有语料**。
     **「标注而不是修」绝不能读成「看过了,无害」—— 这 8 处里有 6 处是活的缺陷。**
   - **⚠️ 全量 `run_tests.lua` 未取到读数**(GH #124),**如实记为没跑成不是通过**;
     trunk 本有 2 处红(#216,不归本组);`smoke_load` 3/0 证明五个改过的英雄文件仍加载得起来。
   - **下一棒**:本组不欠任何一棒。四条留给认领者见 GH #232 §六。

-20. ~~**新轴 `TALENTVALUE`:天赋句柄根本答不出 `value`(GH #228)**~~
   **2026-08-26T20:20Z done —— `bots/` 只加注释、零可执行改动;无新 gate id;
   `state.json` 新增 `talentvalue_20260826`(`gated:false`);零 AWS;不提 queue 请求;不申请入集。**
   - **⭐ 承重读数(974 个天赋,两个 GET,零 AWS)**:天赋分两族,**只有一族拥有 `value`**。
     通用天赋在 `npc_abilities.txt` 里是真的技能块、每块恰好一个叫 `value` 的条目;
     **英雄专属天赋在任何 KV 里都没有自己的块** —— 载荷坐在**被它修改的那个技能自己的条目**里,
     当作以天赋命名的子键(`"radius" { "value" "315"  "special_bonus_unique_axe_2" "+85" }`)。
     ⇒ 专属天赋句柄**没有任何 special value**,`talent:GetSpecialValueInt('value')` **静默 0**。
     **分区是完全的、名字自己就是判别式**:974 引用里 **65** 有块 / **909** 没有,
     **909 个全部带 `unique`,65 个一个都不带**。
     调用点 **21 处,21/21 落在 UNIQUE 上,一处 GENERIC 都没有**(另 9 处在注释掉的
     `aetherRange` 行上,已剥离 —— **数进去会让头条偏差三分之一**)。焦点五命中 **4 处**。
   - **⭐ 最该被拿走的一条:死项死在安全的那一侧,而「显而易见的修法」才是回归。**
     那个 KV 形状**存在的目的**就是让引擎为学了天赋的施法者把 `+85` 折进 `radius`;
     加成**没有第二个住处**,引擎若不折算这条天赋在游戏里就完全不生效。
     ⇒ `abilityQ:GetSpecialValueInt('radius')` **已经带着加成**,**重指句柄会重复计数**。
     **而这棵树已经为同一个折算下过一次注,还是一次已落地的修复**:GH #162 的 `lionsplash`
     读的 `splash_radius` 是 **NO-BASE**(没有基数、只有 `special_bonus_scepter "325"`),
     **只有在引擎按施法者解析子条目时才值钱**。**21 处下的是相反的注,两者不可能同时对。**
   - **唯一一处「无害」不成立**:Axe 淘汰之刃击杀判据把基数**写死**(`150 + 100*lv`)⇒
     **没有折算够得到它**,它**既短了天赋 +150 也短了每级 25**(KV 275/375/475)。
     两者由**同一个修复**(基数改读 `abilityR`)一并收走 = 已登记的 `hero-2`,本轮不动;
     已在源码写明**接手 `hero-2` 的人必须在同一次改动里删掉那个天赋项**。
   - **就地更正了一条「结论对、理由错」的注释**:Zeus 08-22 那条说天赋的 special value
     「叫 `bonus_arc_damage` 不叫 `value`」——**它不叫任何名字**。**错的理由才是危险的那一半**:
     它邀请下一个读者去读 `bonus_arc_damage`(也是 0,而且看起来不该是 0)。**同一句话在文件
     头部还有第二份拷贝,一并更正**(08-22 读的是 datafeed,本轮读的是 KV,#214 换的源)。
   - **入口是三个「什么都没找到」**(登记免得别人再买):① 字面技能名绑定焦点五 **0 处**
     (全仓 49 处多是小兵/信使技能,住别的 KV 文件 ⇒ 这根轴要先有更宽全集);
     ② **句柄解析后**的 `GetSpecialValue` key —— **正是 #162 与 VALSHAPE 自称看不见的那一半** ——
     16 处 15 干净,唯一 1 处是已登记的 lion;③ shape 普查重跑无新增。
   - **⭐ 方法教训 (a)**:**「这个字符串不许出现」的断言,在讨论这个字符串的文件里根本用不了。**
     Zeus 棘轮第一版 `find('bonus_arc_damage') == nil` **在自己要保护的那次更正上当场变红** ——
     撤回一个错的 key 意味着要引用它。改成**蕴含式**并双向驱动。
     **这是 #214 那条的对偶:那条说「只要求出现过」近乎空,这条说「要求不出现」近乎永远红。**
     二阶:撤回标记第一版**跨了注释换行**,多词标记什么都匹配不上。
   - **⭐ 方法教训 (b)**:**工具自己的 fixture 抓到了工具自己的一个真 bug。**
     `parse_talent_blocks` 原本从一个天赋块切到下一个天赋块,**一旦天赋块不连续就吞掉下一个
     技能的整个块体**,从**邻居**身上读到 `value`;真文件里**最后一个天赋块无条件吞掉余下全部**。
     **它是「为堵一条逃掉的变异而新加 fixture」才浮出来的 ⇒ 变异驱动买的不是覆盖率,是缺陷。**
   - **⭐ 方法教训 (c)**:棘轮的**键不许带行号**(#221),本轮四段注释**会顶掉全部四行焦点**。
     代价是同文件同句柄的两处读数共用键 ⇒ **集合**比较在「旁边新增第二处读数」时答绿,
     **而那正是要紧的方向**。**量出来不是担心出来的**:那条变异**在第一版上真的逃掉了**;
     现在按**多重集**比较。
   - **刻意没删**:三处被折算覆盖的死项,诚实修法是删(#104/#73 先例),但**三条别的棘轮
     按名字引用了这个形状**(`focus_t15_payoff` / `lion_hex_talent_slot` / `wk_fact_anchor`),
     缩别人的棘轮是它自己的一次改动、且必须各驱动一次。登记进 #228。
   - **变异**:普查 11 条 = 9 抓 + 1 声明的对照 no-op 逃逸 + 1 逃逸后**复核为真等价**
     (421 个通用天赋块的长形式里**全都嵌着标量 `value`** ⇒ 两种写法在真文件里不可能不一致);
     anchor 7 条 7 抓。
   - **⚠️ 全量 `run_tests.lua` 未取到读数**(GH #124),**如实记为没跑成不是通过**;
     trunk 本有 2 处红(#216,不归本组);本轮 `bots/` 只有注释,不可能新增 Lua 失败。
   - **下一棒**:本组不欠任何一棒。四条留给认领者见 #228 §六。

-19. ~~**新轴 `TALENTNAME`:按字面名绑天赋的那一半 —— 名字没了,句柄就是 nil(GH #223)**~~
   **2026-08-26T17:20Z done —— 改了 `bots/`(1 helper + 1 行),**无新 gate id**(空指针检查,
   沿 #188/#192/#203/#206);`state.json` 新增 `talentname_20260826`(`gated:false`);
   零 AWS;不提 queue 请求。**
   - **入口就是上一轮自己留的名**(#214 报告最后一行),不是新想的题:`-17c` 仍非焦点,
     `-5`/`-3` 是焦点但都在等 `hero-13`/`hero-14` 的域,[hero] open issue 全是本组等裁定的。
   - **⭐ 承重读数**:拿天赋句柄的两种写法**失效方向相反** —— 按下标死于**重排**(#166/#214 已钉),
     按字面名死于**改名/移除**,而且**死得更硬**:`GetAbilityByName` 答 **nil**,8 处里 **7 处**
     下一件事就是对句柄调方法 ⇒ 撞坏掉的引擎错误处理器 ⇒ **`Think()` 半路停住、零打印**。
     普查(`tools/agent/talent_name_binding_census.py`,裁判源 = #214 换上的 `npc_heroes.txt`,零 AWS):
     **8 处绑定,7 处名字还在,1 处没了** —— `hero_doom_bringer.lua` 的 `special_bonus_unique_doom_2`
     (Doom 本 patch 的八条里一条都对不上)。**第二根轴**:只有 silencer 做了 nil 检查,其余 7 处裸调。
     **判词取交集**(ABSENT ∧ UNGUARDED)⇒ **只有 doom 一个**;6 处 PRESENT-but-unguarded
     **今天不是缺陷**,不进棘轮(**把棘轮扩到证据之外 = 门变噪音**)。
   - **⭐ 它为什么被走到:路是别人特意铺的。** 那次调用坐在 `nCreepTarget:IsAncientCreep()` 底下,
     而 `nCreepTarget` 来自 `J.GetMostHpUnitAnyTier` —— **全仓唯一的 tier-盲选择器,唯一调用方就是这条路**,
     且是 **GH #196 特意让它保持盲的**,注释写着「这三条分支自己会处理远古」。
     ⇒ **为保住三条分支写的 opt-out,喂给第一条分支一个空指针解引用。**
     普查把「附近可能有远古」变成「**这个选择器按设计瞄着远古**」——这一步才让它从隐患变成活缺陷。
   - **天赋不是被挪走,是不再存在**:`can_target_ancient` 在 KV 里挂在 **`special_bonus_shard`** 下
     ⇒ 本 patch 管这件事的是**魔晶**。与 #162(key 改名 ⇒ 静默 0)同族但更硬:那条死数值,这条死**整帧**。
   - **刻意没做的那一半,连理由一起交出去**:Doom **五个 role 表全买 `item_aghanims_shard`** ⇒ 域非空,
     **但 `HasShard()` 不在本版 API 参考里**(只有 `HasScepter()`),替代只能是离线核不出来的
     `HasModifier` 字符串 ⇒ **在修掉第一个无法验证的绑定的同一轮里不引入第二个**,登记为下一棒。
   - **⭐ 最该被拿走的一条:判据第一版朝着它唯一不许错的方向错了。** guard 判据初版无条件往上看一行,
     把 `local a = Foo ~= nil and Foo:IsTrained()` 洗成下一句裸调的守卫 —— **被自己的 py 测试当场抓住**;
     收窄后**还剩第二处**,落在**全仓唯一真做了检查**的站点(silencer 经中间布尔量守)——
     **`if` 开启条件,不延续上一行**。⇒ **「跑过的检查」≠「守住的检查」**;分不清的扫描器
     **只许过报、绝不许漏报**(漏报 = 把活的空指针判成安全),**并且要拿它被允许错的形状去驱动它**。
   - **同族第二条**:M8(快照不再声明生成器)第一遍**只被 py 抓到** —— Lua 那侧搜整段 header,
     而 header **把脚本名写了两遍** ⇒ 擦掉 provenance 那行仍然绿。改钉**首行逐字相等**后两侧都红。
     **推论:只要求「文本里出现过」的断言,在自我描述的文件里几乎必然是空的。**
   - **变异 14 条:13 抓 + 1 声明的对照 no-op 如实逃逸,0 意外。**
   - **全量 `run_tests.lua`:两遍独立跑,都是 `2080 tests, 0 failures`。**
     **⚠️ 本条初稿写的是「未取到读数、如实记为没跑成」——错的,已更正,而出错的方式值钱:**
     **我把「缓冲区是空的」读成了「进程还没跑完」** —— 输出被重定向进一个文件,我却去 tail
     **任务包装器**那 22 字节的 `[exited with code 0]`,而重定向目标是**块缓冲**的。
     与 GH #200 / #171 同族:**一个没有内容的读数,和一个「没有」的读数长得一模一样**;
     分辨要看**别的**字段(退出码 / 文件大小 / 进程还在不在),而我一个都没看就下了否定判断。
     **第二个推论**:第一遍跑到一半我 rebase 了树,为消歧重跑了一遍 —— 但
     `git diff --stat` 只有**两个 markdown**、**都不在 runner 的读取集里** ⇒ 第一遍从没被污染。
     **判断中途变更有没有污染读数,查 diff 比重跑快一个量级。**
     **顺带**:初稿照抄的「trunk 本就有 2 处红」(GH #216)在本轮树上**已不成立**(0 failures,
     与总监 `9d16d600` 一致),已追评 #216 交还这份读数。
   - **下一棒**:本组不欠任何一棒。留给认领者(非焦点,GH #223 §六):① 魔晶谓词(先要 world assertion);
     ② 6 处 PRESENT-but-unguarded;③ **3 处变量名与 KV 说法对不上**(`MidnightPulseRadiusTalent`
     → `enigma_black_hole/damage`;`GripAllies` → `magnetize_self`,**绑了但从没被调用**;
     `ColdFeetAoETalent` → `chilling_touch/attack_range_bonus`)——**每处先读调用点再定性**。

-18. ~~**新轴 `TALENTSLOT`:天赋槽位的**来源**一直是一张展示列表(GH #214,零行为改动、零 gate)**~~
   **2026-08-26T13:57Z done —— `bots/` 零改动、无新 gate id、`state.json` 新增 `talentkv_20260826`
   (`gated:false`)、稳定版未漂移、零 AWS、不提 queue 请求。**
   - **动手前先数了一遍仓库已经在读什么,而那次数数本身就是读数**:天赋名到下标 GH #166 已经钉过了
     ⇒ 直接开工会重做一遍 08-24。**但 census 的 docstring 自己写着,槽位顺序取自 odota
     `dotaconstants` 的 `talents[]` —— 一张展示列表**,而 `-17d`(#209)刚刚证过
     **展示列表不是槽位列表**。⇒ 没做的那一半不是「天赋轴」,是**天赋轴的来源**。
   - **⭐ 承重读数(全 127 英雄,零 AWS)**:天赋是一段**连续的** `"AbilityN" "special_bonus_*"`,
     **每个英雄恰好 8 条且连续**;**段起点不总是 Ability10** —— 123/127 是,
     **kez/rubick 从 12、largo 从 15、invoker 从 17**(下面槽位装着真技能)。
     odota 顺序 == KV 段 **106/127**;**Valve datafeed == KV 段 22/22 英雄、176 行逐行相同**,
     而 odota 与那两者都不同的有 **18/22** ⇒ **落后的是 odota,而这是裁出来的不是猜的**。
     裁判是仓库**已经在用**的 datafeed ⇒ 不是引入第三个信仰,是让已有的那个开口说话。
     **⚠️ 「起点不总是 10」不是理论**:parser 第一版写死 10,把 invoker 的天赋报成
     `invoker_emp`/`invoker_alacrity`/… —— **八个像技能名的技能名,零报错**。
   - **焦点五命中一处,且是活的那一档**:WK slot **[4]** 是 `special_bonus_hp_300`
     (KV + datafeed `value=300`),odota 说 `hp_350`;`['t15']={10,0}` 解析到下标 4
     ⇒ **就是他实际拿的 t15**。**行为影响是结构性的零**:`sTalentList` 由引擎在运行期
     从 `GetAbilityInSlot` 建出,**从不读任何镜像** —— 错的是**记录**,不是出货逻辑。
   - **⭐ 本轮最该被拿走的一条:「两个源都这么说」里的第二个源说不出话。**
     仓库**同时持有两个答案两天**没人发现(`hero_skeleton_king.lua:271` 说 hp_300 = 对的;
     快照与 anchor 说 hp_350)。08-24 把理由记成「odota + the hero KV read hp_350」——
     **它不可能是两个**:`npc_dota_hero_skeleton_king.txt` 装的是 `AbilityValues` 覆盖键、
     **一个天赋名字都没有**(grep 命中 0),**而这句话就写在 census 自己 docstring 里、
     在引用它那一行往上三段**。⇒ **写「两个源一致」之前,先确认第二个源有没有能力不一致。**
   - **落地物**:census 改读 `npc_heroes.txt`、odota 降级为交叉核对、新增 `--cross-check`
     (**feed 与被快照的 KV 段不一致 ⇒ 退出码 3**;odota 单独不一致只是备注 —— **方向是刻意分开的**);
     快照重生成(**唯一变动的数据行就是 WK 那行,其余逐字节相同**);
     anchor 新增 **§5 互相钉住快照**(**是一致性棘轮不是正确性棘轮 —— 两个文件同时错成一样仍然绿**,
     管正确性的是源,源由退出码 3 守着,**源码里写明了这个分工**);
     新 `tests/test_talent_slot_census.py` 19 例;`state.json` 里 08-24 那条 `drive_by`
     **就地打 RETRACTED**(不删原文,免得下一份摘要重抄同样的推理)。
   - **变异 12 条,11 抓 + 1 对照如实逃逸**。**两条第一版逃掉的,如实修不是丢掉**:
     ① **生成器不再声明来源**逃逸 —— header 断言读的是**已提交的 .lua** ⇒ 可以骑到下个 patch;
     抽出 `snapshot_header()` 让**生成器本身**被断言。**推论:对生成物的断言看不见生成器。**
     ② **裁判源取不到时用 KV 段回填**逃逸 —— 两种情况退出码都是 0,而它会打出一张
     **三列一致**的表,**而三列一致正是读者来看的那个结论**。
     **推论:只断言返回值的测试,看不见「输出在撒谎」这一整类。**
   - **下一棒**:本组不欠任何一棒(无入集申请 / 零 AWS / 不涉及任何帧)。
     **留名给认领者(非焦点)**:全仓 **8 处**按**字面天赋名**绑定 ——
     `enigma`×2 / `doom_bringer` / `earth_spirit` / `ancient_apparition` / `dawnbreaker` /
     `silencer` / `rubick` —— **从未**与这份 KV 段对过,而 **`doom_bringer` 正是 odota 陈旧的
     18 个之一**([1]/[4]/[6] 三行都在动)。按名字绑**不怕重排,怕改名/移除**
     (`GetAbilityByName` 答 nil → `nil:IsTrained()` 撞坏掉的引擎错误处理器 ⇒ Think 半路停住,#192 同族)。

-17. ~~**新轴 `GRANTSLOT`:`sAbilityList` 的下标不是槽位(GH #203,gated `zusbind`)**~~
   **2026-08-26T05:02Z done —— 本轮改了 `bots/`,gated `zusbind`(turbo-only、未 armed、不申请入集)
   + **两处未 gate 的空指针检查**(沿 #188/#192 先例);`state.json` 新增 `zusbind_20260826`;
   零 AWS;不提 queue 请求。**
   - **承重读数,而且它把一个读不到的谓词枚举掉了**:`sAbilityList` 是 `GetAbilityList` 用
     `table.insert` **压实**出来的(唯一固定下标是大招的 6)⇒ 下标 N = 「walk 接受的第 N 个技能」。
     Zeus 前面插着两个可选技能(杖技 `zuus_cloud` @slot3、魔晶技 `zuus_lightning_hands` @slot4,
     innate `zuus_static_field` @slot6,大招 @slot5)。把丢弃决定枚举成 **2³ = 8 个世界**、
     每个都跑**出货的** walk:**`[5]` 是静电场的世界 0/8**(`lightning_hands` 2、**nil 4**、
     `generic_hidden` 2),**`[4]` 是 Nimbus 的世界恰好是保留 grant 的那 4 个**。
     ⇒ `abilityAS`(唯一消费方 `X.GetStaticFieldBonus`)**在任何世界里都不是静电场**;
     `abilityD` 对不对压在读不到的 `IsHidden()` 上;**4/8 是 nil** = 未 gate 那半边的全部理由。
   - **⭐ 第一版假设被本轮自己证伪,而证伪比命中值钱**:原以为「杖/魔晶技能加载时不存在 ⇒ 句柄恒 nil」。
     普查打掉它:`bots/BotLib` 下**已有 40 处**按**字面名字**取 grant 技能的出货站点,
     而 KV 里这些技能的 mask **自带 `HIDDEN`** ⇒ 引擎出生即造好、只是藏着。
     **教训:先数「同一个仓库里多数人怎么写」,再决定要不要把少数写法叫缺陷。**
     真正的轴在证伪之后才露出来:**按名字取没问题,按下标取才有问题**。
   - **声明出来的依赖(它自己就是「别数下标」的论据)**:walk 写完固定下标 6 之后**还在 append**,
     于是后面每次 `table.insert` 都对**带洞的表**问 `#` —— **Lua 5.1 未定义**。本 VM 答 6;
     **答 4 的 VM 会把保留的静电场放到下标 5**,上面那张表就变了。已钉成 world assertion。
   - **变异 9/10 抓 + 1 对照如实逃逸**;**逃掉的 M10 复核后判为分工不是盲区**
     (它是 walk 丢弃**机制**的变异,本文件枚举的是**结果**;**实测**由
     `test_focus_innate_index_anchor.lua` §3 抓着)。
   - **两个既有棘轮当场红,重新指向而非放宽**:`test_zuus_static_field_pct.lua` 的调用点断言;
     `test_focus_innate_index_anchor.lua` §4(它自己写着「加了 nil guard 就删掉这条并说明」,照做)。
   - **⚠️ 下一棒里最急的一条(收尾核 `test_set.md` 才发现,已追评 GH #203)**:
     `zusstatic` **不是「将来要同臂」,它已经在 armed 集里**(08-25T13:xxZ APPROVED_ADMITTED,
     串 29 → 35,§BF/§BF.1),而 **W12 已于 03:10:52Z 发出**、`zusbind` 不在它的串里
     ⇒ **W12 的 `zusstatic` 腿量的是一个没有 `damage_health_pct` 的技能,两腿逐位相同**。
     §BF.1 预登记把「armed 触发 0」的成因只写了**引擎侧**那一个(Innate+hidden ⇒ 域可能为零),
     今天给出**代码侧**的第二个成因,**两者读数逐位同形、语料分不开**
     ⇒ 照预登记记成 DOMAIN-NOT-REACHED 会**把一个已能证伪的成因固化进档案**;
     建议按 `INSTRUMENT-INVALID` 处置,**裁定权在总监**。
   - **下一棒**:① `zusstatic` **必须与 `zusbind` 同臂**(否则 #173 量的是错技能缺失的 key = 0),
     **故意不写成合取门**(AGENTS.md 的 promote 冻结坑),依赖登记在 issue + `state.json`,归总监排波;
     ② 入集判定归总监,本组不申请;③ 见 backlog 新条 `-17b`(CM 那根 + 轴的另一半)。

-17b. ~~**`GRANTSLOT` 的两半剩余量 —— CM 那根**(2026-08-26T05:02Z 立)~~
   **2026-08-26T07:45Z done(GH #206,gated `cmclone`)—— 本轮改了 `bots/`,gated `cmclone`
   (turbo-only、未 armed、不申请入集)+ **一处未 gate 的空指针检查**(沿 #188/#192/#203 先例);
   `state.json` 新增 `cmclone_20260826`;零 AWS;不提 queue 请求。**
   - **承重读数**:四个世界(2 个可选技能 × 丢/留)全跑**出货的** walk ——
     `sAbilityList[4]` 是水晶分身的 **2/4**、是 innate 的 1/4、是**空槽占位符 `generic_hidden`** 的 1/4,
     **nil 是 0/4**。第四格不是 nil,因为 walk **先按名字**认 `generic_hidden`
     (`aba_skill.lua:5` 是 file-local 字符串,分支真会走)**再**应用丢弃规则。
   - **⭐ 本轮最值钱的一条:`IsHidden()` 一直读得到,只是单向,而这个仓库一直在打印它。**
     行为 dumper 走**同一个** `m_vecAbilities`,过滤器就是 `if hidden { return false }` ⇒
     **名字出现在某帧的 ability 数组里 = 那一帧 `m_bHidden` 为 false**。存在是读数;
     **缺席仍是析取**,本轮从不把缺席当读数。分母:WK innate 31/31、Lion 23/23(管道显示得了 innate)、
     `zuus_lightning_hands` 1 帧(也显示得了 grant)。**CM 51/51 帧恰好 4 个真技能,两个可选技能都是 0**
     ⇒ 都 hidden ⇒ 都被丢 ⇒ **水晶分身在每一局、整局都够不着**。这一条**修订了
     `test_focus_innate_index_anchor.lua` §2 立着的「离线读不到 IsHidden」**。
   - **⭐ 语料证实了槽位顺序而不是假设它**(GH #203 只能声明是假设):大招只在 `slot >= 4`
     才进固定下标 6,CM 只有 3 个常显技能 ⇒ 若可选技能不占大招前面的槽位,下标 6 就不是大招、
     `abilityR` 不可用。**她的大招在 51 帧里有 10 帧在冷却** ⇒ 反驳成立,且写成了可执行的反事实。
   - **⭐ 第一版模型被自己打掉两处**:① 占位符先被按名字接住(上面);
     ② **`#` 的边界跟着表变,不跟着 VM 变** —— 本 VM 对 `#{1,2,3,[6]}` 答 **3**,
     而 Zeus 那侧**同一个 VM** 对 `#{1,2,3,4,[6]}` 答 **6**。
     ⇒ **「本 VM 答 6」不是可以在英雄之间搬运的事实**,两条都钉成 world assertion。
     **所以未 gate 的空指针检查是保险不是修复**(守的是 `#` 答 6 的那个合法世界),
     源码/issue/state.json 三处都这么写,并钉成断言防止下一份摘要把它升格。
   - **变异 12 真 12 抓 + 1 对照如实逃逸**;既有棘轮 §4 **自己写着「加了 nil guard 就删掉并说明」,照做**。
   - **下一棒**:① 入集判定归总监,本组不申请(建议与 `zusbind` 同族,但**不写成合取门**);
     ② 见下条 `-17c`。

-17d. ~~**`GRANTSLOT`:焦点五在这条轴上闭合(GH #209,零行为改动、零 gate)**~~
   **2026-08-26T10:56Z done —— `bots/` 零改动、无新 gate id、`state.json` 无新增、零 AWS、不提 queue 请求。**
   下一轮**不要重推**这五个:**Axe/Lion 结构性正确**(只读下标 1/2/3/6,前面什么都没有,
   大招 slot 5 ≥ 4)、**WK 按名字绑**、**CM/Zeus 已各有候选**(`cmclone`/`zusbind`)。
   - **⭐ 承重读数一:那个「假设」有权威离线来源,而且是一次 GET 不是 127 次。**
     `-17c` 原估「每英雄一次 datafeed GET」——**去证实来源才发现 datafeed 根本没有 slot 字段**
     (只有 `name`/`ability_is_innate`/`ability_is_granted_by_*`,顺序是展示顺序)。
     游戏自己的 **`npc_heroes.txt` 有字面 `"AbilityN"`**,而本仓库**早就在读同一个镜像**
     (`gen_ability_meta.py`)。⇒ 一次 ~900KB GET = 全 127 英雄。
     **推论:找新数据源之前,先数一遍仓库已经在读什么。**(与 `-17` 那条「先数多数人怎么写」同族。)
   - **⭐ 承重读数二:#203/#206 引用的槽表与 KV 逐行相同 ⇒ 它们不再是假设。**
     Zeus 7 行、CM 6 行全对,**没有任何东西需要落地**;
     `test_hero_slot_order_anchor.lua` §2 每轮重核抬头里的 `--  slot N  name`,
     patch 挪了槽位 ⇒ **红的是那个候选**,而不是它悄悄开始量另一个技能。
   - **⭐ 承重读数三:空槽是 `generic_hidden` 而 walk 留着它** —— 这就是
     `X.GetAbilityList` 敢写死 `slot >= 4` + 下标 6 的**全部理由**(KV 约定:
     Ability1..3 常显、4/5 额外或占位、6 大招)。Axe:slot 3/4 都是占位符、大招 slot 5、innate slot 6。
     **顺带卸下 §26/#151 那条 LIMIT 的最细一条腿**(LIMIT 本身仍成立):
     `test_focus_innate_index_anchor.lua` §5 证「dump 顺序 ≠ slot 顺序」原本压在
     「Axe 大招 **1/26** 帧冷却」这个 n=1 上;KV 直说大招在 slot 5、前两格是 dumper 滤掉的占位符,
     **这正是他 dump 数组只有 4 条的原因**。**断言一条没动**,且**仍然不许从语料推 index map**。
   - **判别式是量出来的不是断言的**:§3 除了断言 Axe/Lion 四个绑定在**每个** drop-world 不变,
     **在同一循环里断言 CM 的下标 4 会变** —— 否则「Axe/Lion 全绿」可能只是这条轴对谁都成立。
   - **变异 9 抓 8**;逃掉的 **M9**(丢弃规则 `and`→`or`)**复核判为分工不是盲区**:
     本文件按构造把丢弃决定当**不透明谓词**枚举(#203 同款),而那个合取由
     `test_focus_innate_index_anchor.lua` §3 的文本断言盯着(**实测**:施加 M9 后它当场红)。
     **对照变异如实逃逸**,且按 `-16` 的教训**特意挑了本文件所有文本棘轮都够不着的位置**。
   - **⭐ 最该被拿走的方法教训:我自造的 runner 买到一个假 red。**
     为跑子集写的「每文件一个新进程」跑法让 `test_cm_arcane_aura_passive.lua` 一条 armed 断言红了;
     **官方 runner 跑同一个文件 16/0 全绿**(它单进程跑全部文件,存在跨文件 in-process 状态)。
     而 `run_tests.lua` 抬头就写着「**the runner is the only supported entry point**」。
     **别再自造 runner** —— 子集用 `run_tests.lua <filename>` 过滤器逐个跑。

-17c. **`GRANTSLOT` 的另一半:非焦点英雄那 15 个下标绑定**(2026-08-26T07:45Z 立,
   2026-08-26T10:56Z **工具已就位、线索已具名**,仍未做;**非焦点英雄,认领者自取**)。
   `-17` 数清了**按名字**绑定(40 处 file-scope 站点);**按下标**那一半现在有了权威槽表:
   `tools/agent/hero_slot_map.py` → `tests/mock/hero_slots.lua`(127 英雄,0 基槽位为键)。
   **全仓 46 个英雄文件按下标绑,17 个读到下标 4/5**,焦点五占 2(都已有候选),**剩 15 个是线索**:
   - **slot 3 是可选技能、下标 4 被它占掉**:juggernaut / lich / necrolyte / nevermore / oracle /
     phantom_assassin / sniper / witch_doctor / slark / ogre_magi(还读 5)/ kunkka(该行已注释掉);
   - **slot 4 是占位符**:muerta / omniknight / riki / dazzle(读 5)。
   ⚠️ **线索不是判词**:槽位顺序只是一半,另一半是 `NOT_LEARNABLE and IsHidden()`,离线读不到。
   **`-17b` §2 的 dumper 单向读数在这 15 个上可复用**(名字出现在某帧 ability 数组 ⇒ 那帧不 hidden),
   **但缺席仍是析取**。`test_hero_slot_order_anchor.lua` §4 已把这 17 个的**集合**钉成棘轮:
   再有文件开始读 4/5 就红,并被指回 GH #209。

-16. ~~**§18 的 Lever C 终于写了:WK 打肉分支的 600 绝对蓝(GH #199,gated `wkrosh`)**~~
   **2026-08-26T01:52Z done —— 本轮改了 `bots/`(1 个新 helper + 1 行分支条件),
   gated `wkrosh`(turbo-only、未 armed)⇒ 稳定版未漂移;`state.json` 新增
   `wkrosh_20260826`;零 AWS;不提新 queue 请求(域的棒子早在 `hero-10`)。**
   - **承重读数,而且它绕开了那个问不了的域**:`X.ConsiderQ` 唯一打 Roshan 的分支要 600 绝对蓝,
     而全仓 **34 个真实 WK 帧清得过的是 0 个**,且这 34 帧里**最大的 `max_mp` 是 459**
     ⇒ **满蓝也够不着**。域(`GetActiveMode` 不进 .dem)离线永远问不了,**但蓝这一维问得了,
     而光这一维就把分支在整份档案上关死了**。
   - **armed 腿 = 本文件自己的预留规则,不是「挑个更小的数」**:`X.ShouldSaveMana`(`ConsiderQ`
     第一行就在调)已经在拒「会把蓝压到重生成本以下」的施法,**但只在重生 3.0s 内就绪时**;
     打肉正是那个窗口该常开的场合 ⇒ armed 腿把同一条预留**无条件化**。
     重生 **220/110/0**(**rank 3 免费**)⇒ armed 下界 315/330(R1)/235/250(R2)/95..140(R3)。
     **单向性是构造的**:相对下界只在**严格低于 600** 时才返回。
   - **22/29 放行、7/29 拒绝**,拒的全是重生 rank 1(那 220 在拒)⇒ **它是预留不是洞**,已写成断言。
   - **⚠ 引用前必读**:0/34 是「**这份语料上为空**」不是「游戏里罕见」—— 34 帧全 ≤12 级
     (10 分钟封顶),而蓝池 **18–19 级**才越过 603;**GH #108 放宽到 25 分钟之后切的语料
     可以含本次结构上拿不到的帧,届时先重扫再引用**。蓝耗是**帧外锚**(mock 对任何句柄的
     `GetManaCost` 都答 0,已写成断言)。
   - **⭐ 本轮最该被拿走的方法教训:我写的第一条「对照」变异不是对照。** 改 helper 里一个局部
     变量名(纯 no-op)**被抓了**,因为 section 5 的单向性断言是**文本**断言 ⇒ **文本棘轮对改名
     天然敏感**。换成改 `X.ConsiderQ` 里另一个局部才如实逃逸。**推论:一份同时有文本棘轮和行为
     断言的测试,对照变异必须挑一个文本棘轮够不着的位置,否则「变异全抓」是自证的。**
   - **第二条(与上一轮那条同族、方向相反)**:`src:sub(src:find(p))` 拿回的是**匹配到的那一截**
     (find 返回两个值)⇒ 我取 `X.ShouldSaveMana` 函数体时只拿到 25 个字符,断言在**正确的源码上
     红了**。这次是**红**所以立刻发现;同一个笔误落在**否定式**断言上会**永远绿**。
   - **`test_wk_roshan_mana_ceiling.lua` 的棘轮当场红了 —— 那正是它的职责**(它盯的就是这次改动)
     ⇒ **重新指向而不是放宽**:分支必须仍走 helper、helper 出货默认必须仍是 600、armed 腿的名字
     写进断言(promote 时两边同生同灭);头注加了一段防散文比代码旧。
   - **下一棒**:域 → `hero-10`(已放行未执行,`result` 里已加指针 + 把桌面买到的两个数写进去
     免得重复买);**入集判定归总监,本组不申请入集**(沿 `lionsplash` 先例)。

-15. ~~**GH #189 认领 + GH #192 新轴:名字在树上根本不存在的那个点调用**~~
   **2026-08-25T22:56Z done —— 本轮改了 `bots/`(前七轮都是零行为改动,这一轮不是):
   八处 OVER 实参删除是逐字节零行为,`hero_queenofpain:503` 的点改冒号是行为改动、未 gate;
   无新 gate id、`state.json` 无新增、零 AWS、不提 queue 请求。** 新轴 **`CALLFORM`**。
   - **#189 结案**:采纳方向 (1) 并把 OVER 半边**八处一起扫空**(传的全是字面常量 ⇒ 删掉逐字节等价):
     bristleback 的 `8.0`、life_stealer/mode_attack 的 `5.0`、enchantress/undying 的 `1200`
     (`J.IsGoingOnSomeone` 只读 `GetActiveMode()`)、invoker/pudge/tinker 的 `bot`
     (`J.IsInLaningPhase()` 声明零参)。ALLOWLIST 的 OVER 半边现在是**空的**,
     `test_call_arity_census.py` §3 从「钉那个缺陷」改成「**守住那个空**」。
   - **⭐ 除 #189 的性价比理由外,多给了一条就事论事的**:5 秒是本仓库回答「这波爆发会不会
     打死我」的**统一窗口**(mars/life_stealer/mode_attack 三处都要 5.0),而「8 秒内他们能打出的
     总伤害」作为撤退时的爆发估计本身偏大 ⇒ **被丢掉的那个 8.0 本来也不是更对的那个数**。
   - **新轴的由来**:`call_arity_census.py` 的 `census()` 第一行 `if name not in decls: continue`
     ⇒ **解析不到声明的名字连 stats 都进不去**。而 Lua 里 `A.b()` 当 `b` 不存在是
     `attempt to call a nil value`,配上**坏掉的引擎错误处理器**(`AGENTS.md`)⇒
     **这种崩溃不自报家门,症状只是某个 bot 的 Think 从半路停住**。
   - **⭐ 更正(比缺陷本身值钱):这一类**已经**有一个测试,而且每轮都在跑**——
     `tests/test_no_undefined_jmz_refs.lua`(GH #48)断言「每个 `J.<name>` 引用必须有定义」,
     头注写的理由与本轮一字不差。它没抓到那一行,**只因为 pattern 在第一个点就停了**
     (`J%.([%w_]+)`)⇒ `J.Site.IsCampDangerous` 被读成对 **`J.Site`** 的引用,
     而 `J.Site = require(...)` 正好匹配它的定义侧 ⇒ **`IsCampDangerous` 从来没被问过**。
     **盲区是一整片**:`J.Site`/`J.Skill`/`J.Item`/`J.Role`/`J.Utils`/`J.Chat` 下的所有名字
     (本轮数到 **78 个** `J.<子表>.<名字>`,77 个解析得到 —— 而那 77 个此前**无人保证**)。
     已把「它仍停在第一个点」**钉成断言**,谁加深谁会红并被指回 #192/#193。
     **第一版断言太字面(带括号的字面子串),加深变异如实逃逸一次** ⇒
     **「先量再写断言」对断言自己也成立**。
   - **275 文件 / 2530 声明名 / 28364 点调用 + 20774 冒号调用:NILCALL 7、SELFLESS 13、BOUND 0。**
   - **⭐ 两处有牙齿的**:① `hero_queenofpain:503` 的 `abilityE.IsFullyCastable()` —— **点**,
     而同文件这个句柄的**另外 9 处全是冒号**(#154 的「同文件另一处怎么写」判别式)⇒ **已修**
     (未 gate,依据 #188 先例;**总监若判定该走 gate 请退回**)。
     ② `mode_farm_generic:710` 的 `J.Site.IsCampDangerous` —— **整棵树没有这个声明**,
     `aba_site` 是无 metatable 的平表 ⇒ **未 gate 的活 nil 调用**,每次换野点都撞上
     ⇒ **有意不改**(农场策略决定 + 协同组的文件),**已单开 #193**,并写明**可能与 owner P1
     第 1 条同链路(是线索不是结论)**。
   - **其余 18 处逐条读 body 判良性**:`Debug.IsDebug`×12 / `Utilities.CanPlaySound` 是 SELFLESS
     但**两个 body 都不读 `self`**;`v.callback`×4 是 DYNAMIC;`enemy.IsHero` 是 DEADFILE。
     **BOUND 的 0 是排除假阳性之后的** —— ts_libs 转译产物的 `function T.m(self, ...)` + `T:m()`
     显式豁免,否则造出两条「修了就坏」的假阳性。
   - **⚠ 判据单向,而这次有量到的反例**:解析按名字**最后一段**在全树找(故意宽松,危险方向是
     假阳性)⇒ **解析得到什么都不证明**。同一个文件里 `enemy.IsHero(` 是 finding,而上下几行
     **一模一样缺陷**的三处 `bot.GetUnitName(` 不是,只因 `aba_global_overrides.lua` 声明了
     `function CDOTA_Bot_Script:GetUnitName()`。**已写进头注并配这个例子。**
   - **⭐ 焦点五 0 处,但这个 0 比前几轮弱一档**:#187/#179 的 0 是核验(看**字面量**、无解析盲区),
     **本轴的 0 排除不了「名字存在但属于另一张表」的跨表笔误**。**别引成「焦点五的调用都对」。**
   - **交付**:`tools/agent/call_form_census.py`(15 条 selfcheck,**多数钉「什么不是 finding」**)、
     `tests/test_call_form_census.py`(四层 + **一条双向断言**:#193 那个调用与它的 ALLOWLIST 行
     **必须同生同灭**,行被删而调用还在 ⇒ 棘轮停止盯着一个活的 nil 调用 ⇒ 红)。
     **变异 7/7 抓 + 1 条对照(Lion 里 39 处局部改名)如实逃逸**(7 条里有两条是
     「把 GH #48 的 pattern 加深到子表」)。
   - **⭐ 最贵的方法教训**:**变异回滚用 `git checkout -- <file>` 会连没提交的修复一起抹掉** ⇒
     后三次变异读数全污染,而**污染的表现是"更红"** —— 方向与逃逸相反,**没人会因为红而起疑**。
     **推论:回滚手段本身也是实验器材,要和变异一样被检查。** 同轮第二条:变异脚本的
     `assert count==1` 没命中时**没有执行变异**,却把测试通过打印成 **ESCAPED** ⇒
     **变异没落地与变异被逃逸,输出一模一样**(§-13 教训 ② 同族)。
   - **下一棒**:#193 归协同组(修法 + P1 排除);#192 的 gate 判定归总监;**不需要批测**;
     `advanced_item_strategy.lua` 的 4 处同族由唤醒该文件的人一并修(ALLOWLIST 已写死条件)。

-14. ~~**GH #187:文件写下了一个物品名 —— 游戏里有这个名字的物品吗?**~~
   **2026-08-25T19:55Z done —— 零行为改动(`bots/` 一行未改)、无新 gate、`state.json` 无新增、
   稳定版未漂移、零 AWS、不提 queue 请求。** 新轴两根:**`ITEMID`** 与 **`LVLQUEUE`**。
   - **`ITEMID`**:物品名进引擎只有两扇门,**两扇门对错名字都只回答沉默** ——
     `FindItemSlot`/`HasItem` 答 −1/false(与「没这件装」**一模一样**)⇒
     `not HasItem(bot,'item_typo')` **恒真**;买单里不是真物品也不是宏的条目被
     `Item.GetBasicItems` 的 `Item[v] == nil` 分支**原样转发**给采购层。
     **275 文件 / 544 在售名 / 186 宏:10 个未知名字、11 站点(6 LOOKUP + 5 PROBE)。**
   - **⭐ 焦点五 0 处,而这个 0 是核验**:本轴看**字面量**,写全了就没有句柄解析那一步可怀疑
     ⇒ 与 #162/#177 的 UNRESOLVED 不同,**对写死的名字没有盲区**。
   - **活的那一处**:`aba_site.lua:1488` 的 `item_gleipnir` —— **真名 `item_gungir`**
     (items.txt 里那块的注释确实写 `// Gleipnir`,键是 `item_gungir`)⇒ 恒真合取项 ⇒
     `netWorth < 18000` 时该分支**无条件 return true**;`aba_site` 被 `jmz_func.lua:29` require。
     **有意不改**:改对 = 恒真分支变有条件 = 行为改动,域 127 个英雄不是本组的五个(#170/#177 处置)。
     另 5 处:`item_drum_of_endurance`(真名 `item_ancient_janggo`,`sell_pair_census` 已登记 Q1,
     且 boots_of_bearing **吃掉**鼓 ⇒ 无代价)、`item_great_scepter`(tidehunter,#168 惯例)、
     `item_new`(上游模板桩,`ConsiderItemDesire` 按精确名索引 ⇒ **设计使然**)、
     `item_pipe_of_insight`/`item_battlefury`(真名 `item_pipe`/`item_bfury`,
     **该文件全仓无人 require ⇒ 今天代价为零**)。
   - **⭐ #179 的教训又付了一次**:第一版结论对,**但坏解析器输出一模一样** ——
     `"item_maelstrom"` 既是块名又是配方需求里的**值**,深度盲的读法会让**被改名的物品隐形**
     (它仍被旧配方引用)⇒ `--self-test` 喂嵌套需求值 / 只在注释里的名字 / `ItemResult`,
     断言三种**都不算声明**;主程序另加「解析出 < 400 个名字就拒绝出结果」。
   - **`LVLQUEUE`**:`sSkillList` 是**队列**,而花它的代码**头部阻塞** ——
     `ability_item_usage_generic.lua` 取队头,加不了时穿过所有分支落到最后那个 `else`,
     **而那里的 `table.remove` 被 `botLevel > 25` 守着** ⇒ **来早了的条目不会被跳过,
     它停在队头,后面每个技能点跟着停**,运行期一个字看不到。
     ⇒ **队列顺序是正确性属性**,而此前没人检(`test_focus_level_claims.lua` 钉的是**散文**)。
     **七条表(axe / zuus×2 / wk 默认 / wk `wkbuild` / lion / cm)全部合法**,
     唯一共同例外是大招阶梯都是 `[6,12,17]` 而三级要 18 ⇒ 17 级停一个点一级;
     **登记 NON-DEFECT,理由是检出来的**:17 级时三个基础技能**全部满级**(最后一点都 ≤16)
     ⇒ **那个点没有任何合法去处**,而大招三级在它存在的第一个等级被拿到。
   - **⭐ 本轮最贵的方法教训(量到的)**:「17 级时其它技能都满了」第一版写成**内联断言**
     `<= 17`,**变异(放宽到 `<= 99`)逃逸** —— 真值 16、离界四级,**树上没有相邻的合法形状**
     能证伪一个被放宽的判据(§24 盲区)。抽成 `unmaxed_slot_at()` 喂合成输入后才抓得住。
     **推论:§24 的「树上有没有相邻合法形状」要逐条判据地问,不是逐文件地问** ——
     同一文件里报告那半可能有活反例(本轮 5 个 PROBE 站点),另一条判据一个都没有。
   - **交付**:`tools/agent/item_name_census.py`(单次 GET + `--snapshot` + `--self-test`)、
     冻结快照 `tests/mock/item_names.lua`(544 名)、
     `tests/test_item_name_census.lua`(6 用例,**变异 5/5 抓 + 1 对照逃逸**)、
     `tests/test_focus_build_level_legality.lua`(6 用例,**变异 6/6 抓 + 1 对照逃逸**;
     先把头部阻塞那个**源码形状本身**钉住,全文意义都压在它上面)。
     **源码侧变异各一**:Lion 买单塞 `item_aether_lense`、CM 表把大招提前一行 ⇒ 都当场红。
   - **下一棒**:`item_gleipnir` 的修复归写 `aba_site` 的人(要 gate + 域);
     `item_great_scepter` 按 #168 挂着;**不需要批测**;patch 更新后要
     `--snapshot` 重冻结(快照短了会把每个正确名字变成假 MISSING,棘轮第 1 条用例防这个)。

-13. ~~**GH #183:焦点五 19 处施法的开场动作,只接受一个叫 AGILITY 的状态**~~
   **2026-08-25T16:56Z done —— 零行为改动(`bots/` 一行未改)、无新 gate、稳定版未漂移、零 AWS;
   提了 queue `hero-18`(归档扫描、零 EC2)。** 新轴 **`PTSTAT`**。
   前六轮问的要么是「一个数值是不是那个数」,要么是「引擎接不接这条指令」;这一轮是第三种:
   **一族代码跟自己完全自洽,而对错整体押在一个从没写下来、桌面也读不到的引擎事实上。**
   - **焦点五 19 处排队施法(axe 3 / zuus 6 / wk 2 / lion 3 / cm 5)每一处第一行都是
     `J.SetQueuePtToINT`**;执行出货代码量出的按键表:力量腿 1 下、**智力腿 2 下**、
     敏捷腿 0 下 ⇒ **该族唯一接受的状态是 `ATTRIBUTE_AGILITY`**。机制在 `J.IsPTReady`:
     它比较前**把自己的入参 INT 改写成 AGI** ⇒ `IsPTReady(bot, ATTRIBUTE_INTELLECT)`
     字面上问的是「腿在不在敏捷」。**⭐ 这条不依赖切换方向、也不依赖 mock 常数的值。**
   - **helper 的另一半是必要且正确的**:`ActionQueue_*` 是追加(`BOT_API_REFERENCE.md:1628`)、
     模式 Think 先于技能 Think(:101)⇒ 里面那句 `Action_ClearActions(false)` 正是让施法
     不排在模式当帧移动指令后面的东西。**别把这个 helper 整条读成缺陷。**
   - **两个切换方向都算过**:A(STR→AGI→INT)收敛到 AGI 停住 ⇒ 每次施法前把腿停在敏捷
     (从智力腿出发还要**先丢掉**那份法力);B(STR→INT→AGI)是 STR↔INT **二循环、永不收敛**
     ⇒ 19 处施法**每 tick** 前排 1–2 个道具指令。**方向无关的断言**:INT 在两个方向下
     **都不是稳定态**。
   - **⭐ 反面假设同样意味着有人错**:全仓 **6 处**读数(3 文件 4 函数)分两派 ——
     `IsPTReady`/`ShouldSwitchPTStat`/`ability_item_usage_generic` **读完对调 INT↔AGI**
     (内部完全自洽),`SetQueueSwitchPtToINT`/`hero_morphling.lua:959` **照原值用**;
     树上没有一行说为什么对调,`BOT_API_REFERENCE.md:1616` 站在「照原值」一边。
     引擎返真值 ⇒ 这一族名字全反;引擎真的对调 ⇒ 补偿正确但 **morphling 的记账是错的**。
   - **⚠ LIMIT**:GH #133 量到 `GetPowerTreadsStat` 在 **270/270** 真实句柄读 **0**
     (不等于任何 `ATTRIBUTE_*`)⇒ **fixture 侧构造性不可判**,任何 fixture 的绿色
     **不许**读成本族的佐证(已写成断言 §4.2/§4.3,不是散文)。
   - **有意不改 `bots/`**:关掉一个可能正确的补偿是行为改动、要有自己的依据(#170),
     且域是 127 个英雄不是本组的五个。**id 等取证回来再写。**
   - **下一棒 = queue `hero-18`**(零 EC2)。**取数路径已预登记且不需要新 dumper**:
     帧表已带 `max_mp`/`level`/`items` ⇒ 同局同英雄、等级与物品不变的连续帧对里,
     切换应表现为 `|Δmax_mp|` 的尖锐众数 Δ\*(**Δ\* 要测不要假设**);施法帧附近往上
     = 切到智力 ⇒ CONFIRMED-COMPENSATION 只改注释/函数名;往下或不动 ⇒ 写 gated 修复。
     **第三种结局已预登记**:没有 Δ\* ⇒ 腿整局从不切换 ⇒ 本族从未开火,
     紧迫性归零且「每 tick 排指令」那半条随之证伪 —— **那同样是结论不是失败**。
   - **三条教训**:① **对照变异必须落到该落的每一行** —— 只改半个函数里的 `pt` 造出
     nil 全局、红 6 条,差点被读成「棘轮钉了拼写」(与 §-10 的 `perl -0pi` 同族);
     ② **mock 的 ALL_CAPS 常数惰性铸造**,`install()` 之前读到 **nil**,而 nil 属性
     两条分支都不匹配 ⇒ **读起来跟「代码什么都没排」一模一样**(第一次跑就报了 STR→0);
     ③ **「几处读数」先 grep 再写进断言** —— 我写 4 处,真值 6 处,而多出来的
     morphling 那处恰恰是「两派矛盾」的第二个例子。

-12. ~~**GH #179:`GetSpecialValue*` 的另一半 —— key 在 ≠ 读到的是那个数**~~
   **2026-08-25T13:54Z done —— 零行为改动(`bots/` 一行未改)、无新 gate、不提 queue 请求;
   稳定版未漂移;零 AWS。** 新轴 **`VALSHAPE`**。
   #162 那把尺子只问「key 在不在」,漏掉同一处读数的另一半:
   ① **LOSSY-INT**(key 在、值是小数、调用点用 `GetSpecialValueInt`;值在 (0,0.5) 内
   **截断与舍入都塌成 0**,≥0.5 只敢称有损**不报量级** —— 截断还是舍入桌面读不到);
   ② **NO-BASE**(key 在、但条目**没有基础 `value`**,只有 `special_bonus_*`
   ⇒ 不满足条件的施法者读到 0;key 普查把它算 PRESENT,没错且什么都没说)。
   **128 文件 / 700 处读数:COLLAPSE 2、LOSSY-INT 5、NO-BASE 4、MISSING 25(#162 老轴原样复现)。**
   - **⭐ 焦点五在这根轴上是空的(Int 读小数 0 处),而那个「空」是一次核验**:
     唯一的 NO-BASE 是**我们自己 #162 放进去的那处**。key 普查**分不出「修好了」和
     「把一个静默的 0 换成另一个静默的 0」**,因为新 key 的条目根本没有基础值;
     按形状读才是事实:`lion_finger_of_death/splash_radius` base 无、
     `special_bonus_scepter = 325` ⇒ 没杖 0、有杖 325,消费方本来就在 `HasScepter()` 里
     ⇒ **修复成立**。`test_lion_r_splash_radius_key.lua` §5 用**散文**写下过这个形状,
     **从没被机器检过**;现在检了。同型正确写法另有 `hero_earthshaker.lua:406`。
   - **单向判据**(#175 同族,不解析句柄):`duration` 在 berserkers_call 上 2.1–3.0、
     在 battle_hunger 上 12.0 ⇒ axe 那处判 **UNRESOLVED**,已写成用例。
   - **焦点五之外 8 处不修**(#168 惯例,认领者自取):ursa `hop_duration` 0.25→0、
     snapfire `jump_duration` 0.484→0、pugna `delay` 0.8(落地延迟从施法时间估计里消失)、
     slark/mars/troll/kez 各一处、**mars `soldier_offset` 无基础值且无条件项 ⇒ 恒 0**。
   - **⭐ 教训:「解析器丢了一个 key」和「那里没有这个 key」读起来一模一样。**
     本脚本第一版会把 lion `splash_radius` 报成 MISSING = **「#162 的修复也是个 0」的假警报**,
     去读原始 KV 才拦下(#177 brewmaster 同族)⇒ 配了 `--self-test`。
     **self-test 第一版放跑过一次变异**(`no_base` 用例的子行会把 key 重新登记),
     补**空块**与**纯嵌套**两例才有区分度。棘轮 6 变异 6 抓,**其中一次先逃逸**:
     `find('lionsplash')` 被 `'lionsplashX'` 子串满足,改**带引号**才抓得住。
   - **顺手加固(measured,非缺陷修复)**:`special_value_key_census.py:kv_keys` 改为逐行数括号;
     全 128 英雄**只有 largo 不一致**(漏 3 多 1)、**零判定翻转**、焦点五快照逐字节不变。
   - **下一棒**:不需要批测;归 harness 的便宜一棒是让 `bot_api.lua` 从
     `special_value_shapes.lua` 给 `GetSpecialValue*` 供数(与 `ability_meta.lua` 同型,GH #36)
     ⇒ `VALSHAPE` 与 #162 两根轴**第一次有开火侧**。

-11. ~~**GH #177:CM 的调度第一条分支给一个被动技能下施法指令**~~
   **2026-08-25T10:58Z done —— gated `cmaurapassive`(turbo-only,未 armed,不申请入集,
   先买域 `hero-17`);稳定版未漂移;零 AWS。** 新轴 **`CASTSHAPE`**。
   前五轮问的都是**一个数值值多少**;这一轮问的是 **文件写下的施法指令,引擎接不接得住**。
   `Action*_UseAbility` / `...OnEntity` / `...OnLocation` 是三条**不同**的指令,
   `AbilityBehavior` 位决定接哪一条,而 `DOTA_ABILITY_BEHAVIOR_PASSIVE` **一条都不接**;
   形状错了**不报错**(AGENTS.md),**只是不发生** —— 而发它的分支通常带 `return`。
   - **⭐ 值钱的不是「有一处错」,是「今天代价为零」这件事本身**:该分支在**上游**就死了
     (`J.CanCastAbility` 的 `ability:IsPassive()`)⇒ 整条判断**只压在一个桌面读不到的
     引擎谓词上**;而它为假的代价**不是浪费一次施法** —— 这条分支跑在**最前**且 `return`,
     ⇒ **每个 CM 处于进攻姿态、500u 内有目标的 tick,新星/冰封禁制/冰晶分身/极寒领域
     四条一起被吃掉**。有这个爆炸半径的静默依赖,值得从「推断」变成「事实」。
   - **新工具 `tools/agent/cast_shape_census.py` + 冻结快照 `tests/mock/ability_behavior.lua`**
     (每英雄一次 GET,零 AWS;测试不上网)。**755 条施法指令 / 493 条可解析 /
     11 处 PASSIVE-DISPATCH 散在 10 个文件,焦点五里恰好 1 处**;
     另有 22 处 SHAPE-MISMATCH(**故意判得更弱**:`ALT_CASTABLE`/`AUTOCAST`/facet 覆盖
     让「位里没有这个形状」≠「引擎不接」)、6 处 NO-KV(**不是证明**)。
   - **⚠️ 这次的「看不见」比 #162 更要紧**:262 条句柄走 `sAbilityList[N]`/天赋表 ⇒ UNRESOLVED,
     而**焦点五 15 条施法指令里 12 条正是这样 —— axe/zuus/lion 一条字面量绑定都没有,
     对本普查结构性不可见**。「焦点五恰好一处」是**下界不是体检合格**,已写成断言。
   - **只修焦点五那一处**,helper `X.IsArcaneAuraCastable`:出厂谓词是**第一句**且自己
     `return false` ⇒ gate-off **结构性等价**(`lionhexaoe` 形状,#154 放宽形状的对偶);
     **方向单一**(armed 只有一个出口 `false`,按 `return true` 处数钉住);
     行为位读 0 或常量缺失 ⇒ **落回出厂**不发明 flag 值(#162 规矩)。
     **有意没做**:① 不删死分支(删死代码是另一个方向的清扫,#170 同样处置);
     ② 其余 10 处不碰(九个非焦点英雄,各自要各自的 id,#168)。
   - **⚠ LIMIT 全是量出来的**(承重帧 `f_260820_102645_cm_laning_release` t=556.5):
     `IsPassive()` 离线读 **false**(**整条判断赖以成立的谓词读反**)、`GetBehavior()` 读 **0**
     (⇒ armed 腿离线也开不了火)、`J.CanCastAbility` 为 false 的**真实原因是 `IsActivated()`**
     这个 mock 默认值(#133/#145 族)⇒ **两边一致是巧合,写死了不得当作佐证**。
   - **⭐ 三条必读的教训**:① **一个 mock 默认值悄悄声明了世界事实并把正确实现判红** ——
     `bot_api.lua` 给不认识的 ALL_CAPS 全局发**顺序整数**⇒ mock 的 `DOTA_ABILITY_BEHAVIOR_*`
     **不是互不相交的 2 的幂**,`band(NO_TARGET, PASSIVE) == PASSIVE` 读出 **true**;
     造反例要用 `bnot` **清位**,不能点另一个 flag 的名字。
     ② **逃逸先复核语义再改测试**:`== f` → `~= 0` 逃逸,复核确认 PASSIVE 是**单个 bit**
     ⇒ 真 no-op。③ **源码棘轮钉结构不钉拼写**:对照变异(纯改名)第一版被抓住,
     因为断言点了局部变量名 —— 已改成数守卫处数。
   - **顺手修的工具 bug(记下来免得重踩)**:KV 解析器沿用「`{` 独占一行」的写法在
     brewmaster 上**失步并静默丢掉该文件后面全部技能**(`brewmaster_liquid_courage`
     明明在文件里、下一行就写着 PASSIVE)。改成逐行数括号后计数 10 → 11。
     **一个会对文件后半段静默沉默的解析器比会报错的更坏 —— 普查读起来像「那里没东西」。**
   - **下一棒已交**:queue **`hero-17`**(归档扫描、零 EC2、只要 CM 帧,可搭车),
     **预登记了最有价值的可能结局**:签名帧读 0 或与对照持平 ⇒ **正确结论是引擎的
     `IsPassive()` 确实为真、分支确实是死的** ⇒ **直接不入集别买波次**,标 CONFIRMED-DEAD;
     **那不是失败**。另有一条更便宜、归 harness 的棒:让 `replay_fixture.lua` 从
     `ability_behavior.lua` 给 fixture 技能补行为位(与 `ability_meta.lua` 补「是不是大招」
     完全同型,GH #36)⇒ **整条 `CASTSHAPE` 轴从「只能造假句柄」变成 fixture 可判**。

-10. ~~**GH #175:`GetAbilityDamage()` 读的是技能顶层 `AbilityDamage`,58 处读数里 46 处可证为 0**~~
   **2026-08-25T07:49Z done —— gated `zusboltcap`(turbo-only,未 armed,不申请入集,
   先买域 `hero-16`);稳定版未漂移;零 AWS。** 新轴 **`0DMG`**。
   该调用只读技能的**顶层 `AbilityDamage`** 字段(`docs/BOT_API_REFERENCE.md:1526`),
   现代 Dota 早把逐级伤害搬进 `AbilityValues` ⇒ **不声明它的技能静默返回 0**。
   全仓 128 英雄的 KV 里只有 **16 个技能**声明了非零值。
   - **⭐ 值钱的不是那 46,是同一个 0 在同一个文件里往两个相反方向切**:
     ① `X.ConsiderW2` 把它交给 `FindAoELocation` 的**最后一个参数 `nMaxHealth`**,
     而引擎规则是 **0 = 不过滤血量**(`BOT_API_REFERENCE.md:1288`)⇒ 那条自己取名
     `nCanKillHeroLocationAoE` 的斩杀分支,**实际问的是「射程内有没有敌方英雄」**,
     以 `DESIRE_HIGH` + 120–135 蓝回答「有」= **放宽**;
     ② 同一个 0 喂给 `J.WillMagicKillTarget`(`X.ConsiderW`、Lion `X.ConsiderQ`)
     **把击杀分支整条杀死** = **收紧**。
     **⇒ 一个静默的 0 往哪边切必须逐个调用点读 —— 这正是 #162 那把 key 尺子答不了的那一半。**
   - **判据比 #162 强的一处:不需要解析句柄**。`hero_<h>.lua` 里的读数只可能取在 `<h>`
     自己的技能上 ⇒ `<h>` 一个非零 `AbilityDamage` 都没有 ⇒ 那处读数是 0,**无论句柄指向谁**。
     反向照旧什么都不证明(`<h>` 有一个 ⇒ UNRESOLVED)。焦点五:zuus 2 / lion 3 全 PROVEN-ZERO;
     axe / skeleton_king / crystal_maiden **一处都没有**。
   - **只修了放宽那一处**,helper `X.GetBoltKillHealthCap`:出厂表达式是**最后一句**、
     armed 是唯一绕行 ⇒ gate-off 等价结构性;`<= 0` 的 key **落回出厂**不发明默认值(#162 规矩)
     ⇒ **armed 不可能比出厂更宽**;**方向单一**(#166 教训)。
     **有意没折进 `( 1 + GetSpellAmp() )`** —— 那是**另一个放宽搭着收紧的门上车**。
     **顺带核对为正确、有意没动**:`nRadius = 325` 与 KV `spread_aoe = 325` 逐位相符。
   - **(B) 一族有意不修**:救活死掉的击杀分支是**放宽**,各自要各自的依据和 id(#168)。
     测试对它们的**处数上棘轮**。
   - **⚠ LIMIT 量出来的**:mock 对不认识的 `Get*` 一律答 0 ⇒ **两条腿离线都读 0**,
     且**出厂腿读 0 的原因与 KV 无关 —— 这个一致是巧合,写死了不得当作佐证**;
     `FindAoELocation` **不在 mock 里** ⇒ **开火侧没有 fixture**,而这个「没有」是量出来的。
   - **⭐ 一次瞄歪的变异,必读**:`perl -0pi -e "s/'zusboltcap'/'zusboltcapX'/"` ——
     `-0` 整文件 slurp + **非全局** `s///` ⇒ 只替换**全文件第一处**,**而那一处在注释里**;
     测试全绿**看起来是逃逸,其实变异没落到代码上**。与 #170 的 `__pycache__` 事故同族:
     **读绿/红之前先 grep 一眼变异落在哪一行。**
   - **下一棒已交**:queue **`hero-16`**(归档扫描、零 EC2、**可与 `hero-15` 合并**,
     两者都只要 Zeus 帧),含预登记的反向读法「(2) 非零而 (3) 极小 ⇒ **正确结论是无效应、
     不是无害**,直接不入集别买波次」。其余 10 处 UNRESOLVED + 2 处 GLOBAL 列在 issue §一,
     **不归本组打磨,认领者自取**;缺的那一步是**句柄→技能**解析(天赋那一半
     `talent_slot_census.py` 做过,技能这一半还没人做)。

-9. ~~**GH #173:Zeus 的静电场按 9% 算,KV 说 3.45% + 0.05/等级**~~
   **2026-08-25T04:53Z done —— gated `zusstatic`(turbo-only,未 armed,不申请入集,
   先买域 `hero-15`);稳定版未漂移;零 AWS。**
   `hero_zuus.lua` 写死 `abilityASBonus = 0.09`,而 `zuus_static_field/damage_health_pct`
   = **3.45 + 0.05/英雄等级**(31 级 ~4.95)⇒ **任何等级上都是真值的 1.8–2.6 倍**,
   且错在**乐观**侧。它**恰好两个消费方,两个都是击杀判据**:`ConsiderW` 的远程兵斩杀,
   和 `ConsiderR` 里决定**交不交 ~130s 全图大招**的 `lowHPCount`。
   - **与 backlog §4 是同一个病的两扇门**:那条量出「斩杀窗口来的时候没蓝」,
     本条给出**蓝去哪了的一半 —— 花在一个从来不存在的击杀上**。
   - **承重帧**(已在库,非新造)`f_230952_zuus_ult_hoard` t=567.0,9 级 Zeus,
     五个活敌共 4007 血:出厂记 **360.6 HP**,KV 带只允许 138–198 ⇒ **凭空 162–222 HP**,
     且**逐个敌人**成立(测试对每个活敌单独断言),不是聚合效应。
   - **一个被本地化当场否掉的假设**:「静电场只打英雄」——
     `abilities_english.txt` 说 "**any enemy** ... percentage of their **current health**"
     ⇒ 喂给远程兵那一处**目标合法**、`GetHealth()`(当前血)**也对**,**只有数字错**。
     **教训:KV 给数值、本地化给作用域,改消费方之前两个都要读。**
   - **三条 LIMIT 全是量出来的**:① 静电场 `Innate 1`+hidden ⇒ **没有 .dem 带它**,
     Zeus 真实帧上 `GetAbilityList(bot)[5]` 是 nil、`abilityAS` 是「nil 名字的句柄」
     ⇒ **两条腿在未加工 fixture 上都读 0**(GH #151 同族)—— **这是把句柄改成参数的
     唯一理由**;② mock 的 `GetSpecialValueFloat` 恒 0 ⇒ armed 离线读 0 不是 3.45;
     ③ `GetActualIncomingDamage` 恒 0(第二十二条世界断言)⇒ 开火侧离线不可复现。
   - **⭐ 本组自己三小时前立的教训落到自己头上**:`test_focus_innate_index_anchor.lua`
     的 GH #151 棘轮**按字面数 `abilityAS:IsTrained()` 这个调用点**,本改动把它挪进
     helper ⇒ 当场红。处置是**改写不是削弱**(现在钉两半:句柄仍交给 helper、
     helper **第一句**仍是无守卫 `IsTrained()`)。**搬调用点之前先 grep 谁在数它。**
   - **顺带核对、有意没动**:`ConsiderR` 的 `nCastRange = 1600` 与 `ConsiderE` 的
     `nJumpDistance = 450` **都是只写不读的局部量**(同 2026-08-22 删掉的 `talentDamage`),
     删除属**另一个方向**的清扫,不混进本单元;**核对为正确的**:`ConsiderE` 的
     `600 + nSkillLV*100` 与 KV `zuus_heavenly_jump/range = 700 800 900 1000` 逐位相符。
   - **下一棒已交**:queue **`hero-15`**(搭车、零 AWS 增量、归档 .dem 即可),
     预登记了两条**容易读反的前提**(方向是收紧;别去 .dem 找静电场技能行)与
     **最有价值的可能结局** SILENT ⇒ `lowHPCount` 不是决定施放的那一条
     (上游还有 retreat / `IsDyingUnderAttack` / `IsInTeamFight` 三条更早分支)⇒ **回去重诊断**。

-8. ~~**GH #170:卖装表是角色盲的,而买单按 pos 分表**~~
   **2026-08-25T01:51Z done —— `bots/` 零改动、无 gate、无新 id、稳定版未漂移、零 AWS。**
   `X['sSellList']` **没有角色维度**,`sRoleItemsBuyList` 有 ⇒ 一张卖装表被 pos_1..pos_5
   五份买单共用,任何点名了**角色特有物品**的规则在其余角色里**构造性**是死的。
   焦点五 **16 条**(axe pos_3/4/5 的深渊之刃、zuus + lion 全五角色的补刀斧、
   lion pos_4/5 的 midas、cm pos_4 的风杖)。**一条都没修**:死规则是 no-op,
   救活它是**加宽**(GH #168),而 16 条是三种不同的加宽,各自要各自的依据。
   - **新工具 `tools/agent/sell_pair_census.py`** + 冻结的配方图
     `tests/mock/item_recipes.json`(545 物品 / 122 配方,**测试不上网**,同 #166 冻槽位)。
     五问都报(含空的):Q1 非物品名 1 / Q2 奇数表 1(`hero_meepo.lua`,非焦点)/
     Q3 自卖 0 / Q4 组件已被合成吃掉 2 / Q5 焦点五不可共存 16。
   - **⚠ 单向性**(同 #162 / 靴子供给):可达性走**声明的**买单 = 真实背包的**上界**
     (#136/#139)⇒ **够不到是证明,够得到什么都不证明**。
     **Q5 故意不跑全局表**:那张表 127 个英雄共用,不过滤光焦点五就 **445** 行噪声。
   - **一条「显然的修法买不到任何东西」的算术**:全局表的 `item_drum_of_endurance`
     真名是 `item_ancient_janggo`(**同表往上八行就写对了**),但 `boots_of_bearing`
     的配方**吃掉**战鼓 ⇒ 这一对**死了两次**,改名字零收益。已写成断言。
   - **判读依据要拿 KV 不拿偏好**:补刀斧 `damage_bonus 8` / `damage_bonus_ranged 4`
     ⇒ 远程智力不买它是对的,**过时的是卖它那一半**。
   - **顺手清掉本组自己的红树**:`test_wk_fact_anchor.lua` 的 t20/t25 普查在 main 上红着
     —— #166 把莱恩十五处 `talent8` 改道进 `X.IsHexAoe()` ⇒ 结构性读数 **14 → 1**
     (合并不是删除)。登记数改成 1,**源码一字未改**。
     **教训:落地「把 N 处调用点合并成 1 处」之前,先 grep 有没有普查在数那 N 处。**
   - **⭐ 一次量测事故,必读**:变异扫描做到 M6 时结果**静默全废** —— `range(...,2)`→`1`
     **字节数不变**,`cp` 还原后 mtime 落在**同一秒**,而 CPython 的 `.pyc` 失效判据正是
     **(mtime 秒 + 字节数)** ⇒ 继续跑上一个变异的字节码,M7/M8/M9 的「红」全是 M6 的红。
     **python 模块的变异扫描,每次变异与还原后都要清 `__pycache__`;改单个字符的变异
     (`2`→`1`、`>`→`<`)是这个盲区的必要条件。** 与 #166 的 `package.path` 那条同族:
     **测试基础设施自己的状态会让一次绿/红读错对象。**
   - **下一棒**:总监一条方法学判据(「无维度 X 的表消费按 X 分表的表 ⇒ 点名 X 特有值的行
     在其余 X 上死」);批测台/录像组**本轮无请求**,`queue.json` 未改动。

-7. ~~**GH #166:Lion 的 `talent8` 读的是同一行 t25 天赋的另一半**~~
   **2026-08-24T22:30Z done —— 十五处调用点全部改道** 新谓词 `X.IsHexAoe()`,
   gated **`lionhexaoe`**(turbo-only,**未 armed**,**不申请入集、不提 queue**,理由是域为空且量过)。
   `sTalentList[8]` = `special_bonus_unique_lion_2` = `lion_impale/AbilityCastRange +600`,
   **不碰妖术**;给妖术半径的是 slot 7 的 `special_bonus_unique_lion_4`(`lion_voodoo/radius +250`)。
   而 `tTalentTreeList['t25'] = {10, 0}` ⇒ 出货构筑**训的正是**让那十五处答 true 的那一半。
   - **新工具值得抄**:`tools/agent/talent_slot_census.py` —— **odota 的槽位顺序 × 游戏 KV 里
     override 出现的位置**,join 出「`sTalentList[N]` 是谁、它改哪个技能的哪个 key」。
     这是 #162 那把 key 尺子**自认缺口**(不解析句柄→技能)的**槽位那一半**。
     **判据单向**:`mods` 非空是证明,`mods` 为空什么都不证明。
   - **⚠️ 域为空,且是量出来的**:读数全在 25 级天赋下游;测试**不引用 GH #84**,
     在 104 枚 fixture 上重量最高英雄等级并断言 `< 25`,**语料首次出现 25 级就红并点名下一步**。
     处置与 `alchrage` 同(不 arm / 不入集 / 不提 queue)。
   - **改法的方向性**:收紧型的门写成「出货读数先跑,armed 只能 `return false`」——
     GH #154 放宽型对偶、GH #165「只准取 min」同族。**收紧与放宽不要写进同一个谓词**,
     混方向就把结构性 gate-off 等价降级成「测出来的等价」(GH #144 M7 逃逸的那个层级)。
   - **留给后来人**:① 天赋句柄有**两个**独立正确性问题(槽位指向谁 / 那天赋的效果是不是
     代码假设的那种),key 普查只答得了第二个的一半;② 判句柄绑对没有,最便宜的判别式是
     **同一文件的散文怎么写的**(本例散文对代码错,与 #134 那族方向相反 ⇒ **两个方向都要看**);
     ③ 「turbo 里这一行是死的」是关于**构筑会不会点它**的论断,**不能顺带豁免读它的句柄**;
     ④ 新测试文件的自足性(`package.path`)只有在它是某 filter 里**第一个**加载时才被检验。
   - **下一棒有意没交**:修的另一半(真正利用 slot 7 的 +250 半径)是**放宽**,留给 #108 之后的人。

-6. ~~**GH #165:Alchemist 的两条 turbo 时钟从来没决定过任何事**~~
   **2026-08-24T19:46Z done —— 四处全修**(`hero_alchemist.lua` + rubick 逐字拷贝 ×2 处),
   gated **`alchrage`**(turbo-only,**未 armed**,**不申请入集也不提 queue**,理由是域为空,见下),
   全仓棘轮 allowlist **5 → 1**。`cond and x or y` 只在 `x` 永不为假时是三元式,
   而这四处 `x` 是**比较式** ⇒ `and` 结合更紧 + `15*60 < 30*60` ⇒ 整式**逐字等于
   `DotaTime() < 30 * 60`**,任何模式。**判别式:`x` 是数字就安全,是比较式就是缺陷**
   (`jmz_func.lua:4324` 的数字版完全没问题)。
   - **改法值得抄**:`nClock = math.min( nClock, nTurboMin * 60 )` —— **收紧型的门写成
     「armed 只准取 min」**,子集性就从「两个常数碰巧满足」变成**结构性**的
     (issue 建议的赋值写法只在今天的常数下成立)。这是 GH #154「放宽型的门写成
     『出货判据先跑一遍』」的**对偶**,两条合起来是同一条:**门的方向性由代码形状承担,
     不由常数承担。**
   - **⚠️ 域是空的,而且是量出来的**:`SOAK_CAP_MIN=10` 而 armed 界 15:00 ⇒
     封顶局的每一刻都满足出货谓词,**armed 与出货逐点相同**,一波跑多少局都买不到 (a);
     `tests/fixtures/` 每一帧也都在界下。所以**不入集、不提 queue、不钉帧**。
     `[domain]` 用例**直接从 `soak_loop.sh` 读 `SOAK_CAP_MIN`**,`[corpus]` 用例扫 fixtures ⇒
     **cap 一涨这两条就红并点名「可以提议入集了」**。与 mock 默认值那一族(#100/#133/#145/
     #154/#162)**后果同形但成因不同**:那是默认值打平读数,这是**局长上限切掉了整个域**。
   - **下一棒已交**:GH **#108 追评**(球给总监)—— 连带重审清单建议加**第 7 条**
     「cap 抬高会新解锁一批 gated id 的域」,`alchrage` 是第一个具名条目;顺带请总监扫一次
     `state.json` 里还有多少未 armed id 被 cap=10 压着(判据:**armed 谓词里的时间常数
     ≥ 旧 cap ⇒ 旧语料对它一律无效**)。**本组不再推这一格。**
   - **留给后来人**:① **helper 重构的断言必须跨过 helper/调用点的边界** ——
     第一版只钉 helper,`<` 偷偷改成 `<=` **逃逸**(M7),因为 §§2–4 测的是 helper
     **返回什么**不是调用点**怎么用它**;② **逐字拷贝的文件要有一条「不许漂移」断言**
     ([twin]),这个缺陷之所以是四处而不是两处就是因为 rubick 拷贝没人盯(M9 复现);
     ③ 缩了别人的棘轮 allowlist,**要驱动一次那个棘轮**(M11 把一行加回去),
     否则「缩表之后它还认不认」只是假设。

-5. **GH #162:Lion 大招的溅射半径读了一个被改名的 KV key**(2026-08-24T16:52Z 立,
   gated `lionsplash` 已落地、**未 armed**、**不申请入集,先买域** `hero-14`)。
   `hero_lion.lua` 读 `splash_radius_scepter`,而本 patch 的 `lion_finger_of_death` KV 里
   它叫 **`splash_radius`**(`special_bonus_scepter = 325`)⇒ `GetSpecialValueInt` 对不存在的 key
   **静默返回 0** ⇒ Lion **持 A 杖时** `X.ConsiderR` 里消费 `nRadius` 的**两条分支整条死**
   (`R团战Aoe` 计数恒 1 而需 >1;`R-带线` 半径 0 而需 >4)。与 GH #137 / #115 / #104 同族。
   - **新工具 `tools/agent/special_value_key_census.py`**(每英雄一次 GET,零 AWS):
     **620 处读数,30 处 key 不在所属英雄的整份 KV 里**,**焦点五里恰好只有这一处**;
     其余 29 处列在 issue §二,**不归本组打磨,认领者自取**。
     **判据单向**:key 不在 ⇒ 证明读数是 0;key 在 ⇒ **什么都不证明**(不解析句柄→技能映射)。
   - **⚠️ LIMIT(量出来的,不是断言的)**:mock 的 `GetSpecialValueInt` 对**任何** key 恒 0、
     `^Has` 默认 false ⇒ `HasScepter()` 在 106 个 fixture 上全 false ⇒ **开火侧离线不可复现**,
     绿色**不能**读成「守卫不必要」。与 GH #100/#133/#145/#154 同族。
   - **顺带核对没错的三个数**(免得后人重查):Lion R `475+125*lv` / A杖 `575+125*lv`、
     WK Q `40*(lv-1)+100`(= `damage` + `blast_dot_damage` 的**和**)、CM W `100+50*lv`
     (= dps×duration)**全部与 KV 逐位相符**;**唯一对不上的仍是已登记的 Axe R `150+100*lv`**
     (KV 275/375/475,每级少 25,`hero-2`,**不动**)。
   - **留给后来人**:① **`test_gate_claim_consistency` 按子串 `gated` 触发** ——
     注释里写 "**un**gated" 会被判成「声称了一个没人接线的 gate」(本轮当场踩到);
     key 名在注释里用反引号,别用单引号。② 一次如实记的变异误判:M5(内层 `>0`→`>=0`)
     逃逸,复核确认是**真 no-op**不是盲区 —— **逃逸先复核语义再改测试**。
   - **下一棒已交**:queue **`hero-14`**(归档 .dem 扫描,零 EC2;四条口径 + 两条预登记的
     反向读法已写死,含「(2) 读 0 ⇒ DOMAIN-NOT-REACHED 而非不可能,#108 放宽局时后必须重量」)。

-4. ~~**GH #156:`cmboots` 非 armed 腿 1/103 漏成秘法鞋 —— 源码侧证伪领头嫌疑**~~
   **2026-08-24T13:57Z done ——** 逐树读源码证伪 issue 的领头嫌疑(`tEarlyBoots` 四个调用点
   全非下单;唯一的 role→boots 表 `advanced_item_strategy.lua` 无人 require);剩下的真机制
   「引擎按配方自动合成」对 **CM pos_5 出货腿也不成立**(供 0 wizard_hat + 0 sobi_mask,
   秘法鞋两样都要 ⇒ 构造性装不出,无论购买顺序/消耗模型)。⇒ **1/103 仍未解释**,唯一残余是
   issue 自陈的**反向可能**(gate 在加载时序上求值为真),那是 harness 世界断言型问题、不归本组。
   新 `tests/test_boots_supply_paths.lua`(9 例 / 12 变异 11 抓 + 1 no-op 逃逸);**`bots/` 零改动、
   无 gate、稳定版未漂移、零 AWS**。详见「当前状态」头条。
   - **留给后来人**:① 判「谁下了鞋单」前先做散件普查——«零供给是证明,非零供给什么都不证明»;
     ② 任何**只改鞋买表一项**的候选(含已落地 `cmboots`)验收「持某鞋比例」时,先用该供给表
     扣掉「结构上装不出的零腿」——那张表就是可复用口径;③ 一个组件替一批腿承重时单独断言它
     (本轮 wizard_hat 替所有出货腿承重)。
   - **下一棒已交(#156 追评)**:反向可能 = 开一个 harness 断言核验 gate 加载时序,或钉承重帧
     `032512_slot8` t=237.4 fixture(断言该帧 `IsSoakCandidate('cmboots')==false` 且下一未持有项
     不是秘法鞋系)。**归 harness/总监,非本组。**

-3. **GH #154:Axe 战斗饥饿的伤害类型错价**(2026-08-24T02:05Z 立,gated `axebhpure` 已落地、
   **未 armed**、域待 `hero-13`)。`axe_battle_hunger` 是 **PURE**(KV `AbilityUnitDamageType`
   + tooltip `DPS_Pure`),而 `X.ConsiderW` 的击杀分支把它喂给 `J.WillMagicKillTarget`
   —— 那个 helper 首行写死 `DAMAGE_TYPE_MAGICAL`、末行 `GetActualIncomingDamage(..., MAGICAL)`
   ⇒ **满级带天赋 384 读成 288**,方向是漏杀。**同一个文件的 `X.ConsiderR` 是对的**
   (声明 PURE + 裸血比),所以这是疏漏不是设计。**焦点五里唯一的一处**(普查见 issue)。
   - **⚠️ 桌面塌缩检查不干净,引用时必须带**:`X.ConsiderW` 分支 2/3/4 **不带伤害判据**,
     同一个敌人上放宽即 no-op ⇒ **DOWNSTREAM-DOMINATED 风险**(WK lever A 同形)。
     **登记为风险不是判词**;桌面能证 EMPTY 不能证 RARE,而这里两样都没证到 ⇒ **不申请入集,先买域**。
   - **下一棒 = queue `hero-13`**(归档 .dem 事件流扫描,零 EC2,四种读法已预登记)。
     若为正,载体瓶颈与 `hero-9`/`axecull` **是同一个**(常设种子零 Axe,`--find axe ⇒ 899/910/911`)
     ⇒ **两条可合并申请一波**。
   - **⭐ 第二十二条世界断言(归 harness,本组只登记)**:`GetActualIncomingDamage` 在
     **1040/1040** 个英雄 handle 上读 mock 通用默认 **0**(`GetMagicResist` 同样 0/1040)⇒
     `J.WillMagicKillTarget` 对 **966 个活人全 false、74 具尸体全 true**。
     **焦点五每一条击杀分支离线都是哑的**(CM 冰封禁制 / Lion 穿刺·大招 / Zeus 雷击同一个调用),
     **绿色 fixture 是假绿**,离线数「击杀分支会开火的帧」数到的**恰好是死人**。
   - **留给后来人**:① 写击杀判据前先读 KV 的 `AbilityUnitDamageType` —— 仓库有三个类型正确的
     helper,而 `J.WillMagicKillTarget` 名字带 Magic 却因为算法最强被所有人随手用;
     ② 判「疏漏还是设计」最便宜的判别式是**同一个文件里另一处怎么写的**;
     ③ **放宽型的门写成「出货判据先跑一遍」的形状**,gate-off 等价性就从测出来的变成结构上的
     (变异 M6 正是靠这条被抓);④ 凡「某分支在语料里从不开火」,**先问它读的引擎函数在 mock 里返回什么**。

-2. ~~**GH #134:等级读数 off-by-one 的收尾清扫**~~ **2026-08-24T00:00Z done —— issue 点名的
   两处待扫散文早就修好了(散文比代码晚,第三次同型),于是把问题换成「这一族还剩几处」:
   全量清扫焦点五 + 相关测试,**活着的错五处全部改正**(Axe t10 论证、WK 四处、
   `test_lion_t10_payoff.lua` 自己跟自己打架的 honest bound)。新
   `tests/test_focus_level_claims.lua` 把每条等级读数钉在驱动出来的 ladder 上:
   needle 模板的 `%d` 由 `J.Skill.GetSkillList` 填,改散文或改 build row 都会红。
   17 例 / 16 次变异 16 抓;`bots/` 只动注释、零行为改动、稳定版未漂移。issue 已关。**
   - **留给后来人的三条**:① **一个数字只能有一个来源** —— 「注释里写个等级」这种事修不完,
     除非让注释里的数字由代码填(模板 + 恰好一次的出现计数);② `skill_level_map.build_row`
     现在有第三参可读**非默认**的 build 表(WK 的 gated `tKillBuildList`)——
     **gated 那一行的定价散文也在做等级声明**,以前没有任何读者够得到;
     ③ **变异脚本的判定语句本身要先验一次**:本轮 `case *"0 failures"*` 把
     「10 failures」误判成 ESCAPED(子串匹配用于计数是错的工具),详见报告 §5。

-1. ~~**GH #144:给 `9fa4898`(CM pos_5 arcane boots)补 gate**~~ **2026-08-23T11:45Z done ——
   gated `cmboots`(turbo-only,未 armed),gate-off 逐字节回到 `9fa4898^`
   (`git diff 9fa4898d^` 里买表本体零 diff),14 例 / 12 次变异 12 抓。**
   **顺带撤回了同一笔 commit 里波及 16 个英雄的另一半**:`item_crystal_maiden_outfit`
   的第二个芒果 + 哨兵挪位,理由 "referenced by nothing" **是假的**(fork 前就有 16 个
   英雄文件 / 19 条活买表条目引用它),arcane 变体搬进新宏 `item_mage_arcane_outfit`。
   **下一棒已交**:总监入集 → 批测台 queue **`hero-8`**(§AU.2 独占首波)→ 录像组
   `hero-5`(前提已就地改写,**只能读 armed 腿**)。详见「当前状态」头条。
   - **留给后来人的两条**:① **共享 outfit 宏不归本组** —— 动 `aba_item.lua` 里任何
     `item_*_outfit` 的内容或 `tDefineItemRealName` 哨兵之前,先 `grep -rl` 数一遍有多少
     英雄文件在买它;哨兵决定「开局什么时候算买完」,挪一位就可能让别人的开局提前结束。
     ② **build gate 的测试要跑,不要读源码** —— 一个 build gate `dofile` 一次只要 0.02s,
     而读源码字符串的版本对「transform 漏到别的 role 上」「gate 根本没被调用」
     「turbo 那一半不在」全都隐形(M7 就是这么逃的)。

0. ~~**`wkqaim`(queue.json `hero-1`)上机前核验**~~ **GH #118**; **2026-08-22T15:47Z done —— DO NOT WRITE,
   两条独立理由(供给饥饿 + 上游同胞 `UPSTREAM-SIBLING`),`tests/test_wk_q_aim_preflight.lua`
   9 例 / 7 次变异 7 抓,详见「当前状态」头条。** 这次连 gate 都没写(从未 armed / 从未入集)。
   **别重查**:catch-all 的域不是几何问题 —— 6/6 环帧上 Blast 没学或在冷却,
   而三个冷却是 14 秒里的 >13 秒;`X.ConsiderQ` 有**三条**分支取最近敌人,
   紧邻上方那条(出厂代码、无 gate)先吃掉全部战斗帧。
   **复活条件**:(a) `tAllAbilityBuildList` 让 Wraithfire Blast 早于 12 级到 rank 2
   (§3 会自动报出来);(b) 上方「受到伤害时保护自己」分支被改/加 gate;
   (c) 那 153 局的普查按**新口径**(两条分支分开数 + 每帧记 Blast 可用性)读出非空的域。
   **下一棒已交**:queue `hero-1` 保持 pending 且口径已就地改写。

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
     **2026-08-21T22:00Z 上机前语料核验后撤回排队:DO NOT ARM,第六类处置
     (建议名 `SIBLING-DOMINATED`)。** 前五类一条都不是:载体在(Lion 12/54 局)、
     域**可达且是五个被否决候选里最大的**(4 起手 / **4 episode** / 12 局 Lion 局里的 4 局
     = **0.33 ep/Lion 局**,对比 cmrself/esaftershock/zusultx 各 0.06、已获批的 odaoe 0.77)、
     消费点对、谓词也对。**塌掉它的是 `liondrainstop`** —— 它**已经在 eligible 集里**、
     跑**一字不差的同一个谓词**,而 `X.ConsiderStopDrain()` 是 `X.SkillsComplement` 的
     **第一行**(`hero_lion.lua:199`,在 `J.CanNotUseAbility` 早退**之上**)⇒ 读条期间每个
     think tick 都跑 ⇒ **「开读条那刻谓词就为真」的帧,释放侧下一个 tick 就切了**。
     实测**4 个域内起手里 3 个被它覆盖**,第 4 个频道长 **0.0s**(ADD/REMOVE 同一个 0.1s 时刻,
     已回原始事件流核对,不是配对错误)⇒ 否决它是空操作。**`liondrain` 独占域 = 空。**
     反向不成立:`liondrainstop` 另有 **3 个**「干净开始、中途转危」的频道是 `liondrain`
     结构上够不着的 ⇒ **两者不是并列,是包含:`liondrainstop` ⊃ `liondrain`**。
     **排期升级**:登记的「两者永不同臂」**不够** —— 即使分两臂,两臂在那 3 个共享频道上
     行为几乎相同(对比度≈0),只有 3 个 `stop_only` 频道能分开;建议 **`liondrain` 在
     `liondrainstop` 拿到 (a) 读数之前不进任何波次**。**门代码保留(两个都是对的)。**
     **顺带:门在自己域上也是 50%** —— #1 是 fixture A(真阳)、#3 是 fixture B(**干净假阳**:
     5.0s 频道、环里 luna 只剩 32% 血、1200 内 2 队友、Lion 整局再没死)、#2 频道 0.3s 而死亡在
     结束后 2.5 秒(因果链断)、#4 是 0.0s。这就是 16:00Z 在释放侧钉的 **HIGH/HIGH**,
     必然如此,因为是同一个谓词。工具 `tools/batch_test/behavioral/lion_drain_start_domain.py`
     (第八个域模板,`--verify` 39 例 / 7 次变异全抓);**GH #97**;登记
     `state.json:liondrain_corpus_preflight_20260821T2200Z`。
     **可复用先验(第三个方向,建议进 §Y.2 旁)**:**上机前问「测试集里有没有一个 id 跑同一个
     谓词、只是接在决策链的另一端?」** —— `wkreincarnmp` 问「同分支上有没有更弱的否决已经拦了」,
     `zusultx` 问「我拦的地方动作路不路过」,本条问「别的门是不是已经在下游做了同一件事」。
     三条都是**桌面可查**的;本轮唯一需要语料的是**域的形状**(4 个全是「开读条即为真」而不是
     「中途转危」)—— 桌面能证 EMPTY,不能证 RARE(§Y.2)。
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
    两套阈值并存、口径不同、互不知情。~~**等 `zusultx` 落地(有 (b) 读数)之后再动**~~
    **2026-08-21T19:30Z 更新:等不到了 —— `zusultx` 不上机(见下面 §17)。**
    而且本轮把这两套的关系算清楚了:`nKeepMana*2 = 800` / `*2.3 = 920` 这两个**绝对蓝旁路
    在 `zusultx` 的带内结构性不可达**(带的最高上沿 = 大招 3 级 500 + Bolt 4 级 135 = **635 < 800**),
    所以它们和留蓝门**在带内从不相遇** —— 这是桌面就能证的 EMPTY,已机器化进 `--verify`。
    真要动 `nKeepMana`,注意 **317** 这个数:降到它以下,`*2` 第一次进入带内,本轮读数作废。

17. ~~**`zusultx`(GH #59)等入集**~~ **2026-08-21T19:30Z 上机前语料核验后撤回:DO NOT ARM,
    而且是**第五类处置**(建议名 `CONSUMER-SIDE-UNREACHABLE`)—— 前四类都不是它:域**不空**、
    载体**不缺**(Zeus 17/17 局,是本组五轮核验里第一次载体管够)、供给**不饥饿**(带内 148 帧)。
    塌掉它的是**门被接在哪儿**:施放侧 17 局里 5 次真实的「跨储备线打健康英雄」,**4 次**来自
    `X.ConsiderW2` **不报告目标**的分支(kill-AoE / 打断 / 撤退,GH #47 **有意**让它们返回 nil),
    而门的第三条子句是 `if not J.IsValidHero( hTarget ) then return false end` ⇒ **门在这些帧上
    结构性不存在**。可证「不是 inert 也不是自己豁免」的 = **1 次 / 17 局 = 0.06 次/局**,
    与 `cmrself`(1/17)、`esaftershock`(1/17)同量级。
    **⭐ 决定性的一刀:`zusultx` 管不到 GH #59 立案的那一帧。** 单独取立案局
    (`soak/spot_20260820_041132_.../20260820_042607_slot1`)重跑,工具逐位复现 t=462.9
    (mp 256,落地 Bolt 打 1.00 血 lion),而**没有任何 W2 poke 分支能开火**(蓝 0.30/max < 0.65、
    256 < 800、800 内队友 1 < 3、射程内最弱 1.00 血)⇒ 门 INERT。判定**只用可测量输入**:
    `talent7` 是**最后一对天赋**(= 25 级档,本语料最高 21 级 / 立案局 15 级)⇒ 恒未学 ⇒
    `ConsiderW` 永远打实体 ⇒ **每一发落地 Bolt 都来自 `ConsiderW2`**。
    **锚不确定性不影响结论**:`--rcost legacy`(225/375/525)重跑,施放侧头条一字不变。
    **门代码保留(它被问到时是对的)。** 工具 `tools/batch_test/behavioral/zusultx_domain.py`
    (本组第七个域模板,`--verify` 19 例);登记 `state.json:zusultx_corpus_preflight_20260821T1930Z`。
    - **⭐ 本轮最该被别的组拿走的一条**:**一个新增否决要"生效",光有正确的谓词不够 ——
      还要它被接在**真的会产生那个动作**的那条分支上。立案帧证明的是"缺陷存在",不自动证明
      "这个补丁会在这一帧生效"。上机前分别问:(i) 谓词在这一帧为真吗?(ii) 这一帧的动作会经过
      这个门吗?** 第二问**是桌面可查的**(读一遍消费点,看哪些分支把 target 传成 nil)。
      与 `wkreincarnmp` 那条同族、方向相反:那条问「别人是不是已经拦了」,本条问
      「我拦的地方它是不是根本不路过」。
    - **下一个杠杆在消费侧、是新 id**(建议 `zusultw2all`):让 W2 的 kill-AoE / 打断 / 撤退
      三条分支也报告瞄准的英雄,把放行权交回门自己的两条豁免。**要带自己的帧证据** ——
      GH #47 有意选了相反方向,且那三条恰是最不该被拦的三件事(`lanefix` 失败形状)。
    - **复活条件**:(a) **任何 grouping 类 id 被 armed**(`#nAllies >= 3` 连续第三次是塌陷点:
      axeblink / cmrself / zusultx);(b) `nKeepMana` 降到 317 以下;(c) `> 0.65` 那条闸被下调;
      (d) 上面的消费侧杠杆落地。
    - **只登记不动**:`X.ConsiderW` 的 `targetRanged` 分支按**绝对伤害**判致死,门按 `hp_pct`
      判「健康」⇒ 能秒掉 65% 血脆皮的 Bolt 会被拦。本语料**实测 0 次**。

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

12. ~~**`[hero]` GH #63 未认领**~~ **2026-08-22T00:30Z 做完了(认领 + 重跑 + 上机)** ——
    等的那件事(用重锚后的 `CAST_RANGE` 重跑 `cmrguard_precision.py`)本轮自己做了,
    结论比预期更硬:
    - **先逐位复现 #63 的每一个已发表数字**(legacy 锚表上 115 episode / 39.6% vs 8.2% /
      4.85x / 56/115 / 304.0s / §2 整张逐技能表)⇒ 语料识别与谓词同源,后面的差异只能归锚表。
      语料从 `replays/20260820_04*` **按阵容分组**还原(平的 S3 前缀没有 run 信息):10 局有 CM
      恰好落在两个阵容 = 两个 run,各去掉最早的暖场一局 ⇒ #63 的 8 局,点名的三局全在内。
      **#63 的 dump 是 0.5s**(1.0s 重跑得到恰好一半的帧)。
    - **现状本身比 #63 记录的便宜 30%**:封锁 **213.0s(26.6s/局)不是 304.0s**、episode 112 不是 115、
      帧级精确率 **47% 不是 40%**、lift **5.59x**、最长单次封锁 **10.5s 不是 21.5s**、≥10s 段 **3 不是 8**。
      #63 开场那个「21.5 秒空转封锁」是 **900u cask 锚**的产物(真值 600 ⇒ 环 1000u),实测 5.0s。
      **误报的结构判断仍成立**(cask 仍是最大封锁消费者 85.5s / 43%),只是量级小了。
    - **#63 推荐的 `cap = 250` 在正确锚上过不了它自己 §6 的验收**(精确率 57% < 60%;
      封锁 42.7% > 35%);**`cap = 200` 三条全过**(62% / 30.8% / TP −11%)。
      **注意 ② 的分母也被重锚改掉了** —— 按 #63 发表的 38.0s/局 读连 cap=300 都能过,
      按正确的 26.6s/局 读只有 200 和 0 能过。**事前登记的相对阈值在分母重测后必须重算**
      (已请总监收进判读纪律)。
    - **上机 = 新 gate `cmrcap`**(`X.nRGuardRangeCap = 200`,turbo-only,**收窄一个已 armed id**
      的第一个形状)。**armed 单独 ≡ shipped**(封的环只存在于 `cmrguard` 分支里)⇒ axeblink 陷阱,
      **必须与 `cmrguard` 同臂**,这一条**写成了测试用例**。两个真实帧钉住 **[146, 483)**:
      `043039` t=515.5(WD **546u**,`died_after = 0.2`,**就是 #63 §3 那一帧**)必拦 /
      `042009` t=497.0(WD **883u**,同一个就绪 cask,10s 内零硬控,`died_after = 101.9`)必放。
      15 例 + **7 次变异 7 抓**。
    - **顺手修掉 #63 §6.3 的刹车**:「真阳性 episode 数」**不单调**(54/51/47/51/48/34)——
      episode 的结局记在第一帧上,收窄让起点后移就能换标签。新增 `covered_landings()`:
      分母是**事件流里真实落地的硬控**(固定 ground truth),**94% → 89% → 86% → 73%**,单调。
      ⇒ cap=200 的代价 = 109 次落地里丢 9 次;悬崖在 cap=0。**以后这一家族的 recall 验收用它。**
    - **cap 够不到的那一半交回 #66 §3**:封顶后残余封锁 = slardar crush 42.5s(69%)+
      axe berserkers_call 8.0s(**0/5**),**两个都是自身半径类,环 = buffer 本身,任何 cap 都碰不到**。
      cask 在封顶内的精确率 43% → **76%**。⇒ 「统一封顶」与「几何分档」**不冲突,是两个杠杆**。
    - **下一轮若回到 cmrguard 家族**:先看 `cmrcap` 有没有进波次;没有就做 #66 §3 的自身半径类
      (要自己的帧证据,别和 cap 绑在一起测)。
    历史记录(仍有效的部分):**2026-08-20T12:08Z 改判:本组不认领,
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

18. **WK(GH #17)事实重锚 —— 2026-08-22T02:00Z 第一刀做完(GH #104),本条继续开着。**
    动 WK 之前先核事实,结果**文件里的英雄不是游戏里的英雄**:①索引 2 是
    `skeleton_king_bone_guard`(**主动**、无目标、恒 42s cd、2/4/6/8 层),不是注释写的
    「吸血光环 / lane sustain」——吸血是 `skeleton_king_vampiric_spirit` 且 datafeed 标
    **innate**,**一个技能点都不要**;②`abilityW` 的种子名 `skeleton_king_spectral_blade`
    **不在他的技能集里、全仓库只出现在那一行**,整条 W 路径一直靠 `X.SkillsComplement`
    里那行兜底重取(**没崩、没有行为差异**,正因如此改成真名是**可证空操作**);
    ③npc/天赋块整块是 7.2x 的。锚 = datafeed `herodata?hero_id=42`,2026-08-22 读。
    **本轮零行为改动、零新 gated id、零 EC2/S3**;交付重锚注释 + 删五个死局部
    (`bDebugMode`/`abilityE`/`talent5`/`castEDesire`/`nKeepMana`,最后一个**已赋值全仓零读**,
    与 GH #73 从 Lion 清掉的同型)+ `tests/test_wk_fact_anchor.lua` **13 例 / 13 次变异 13 抓**。
    - ~~**对 `wkbuild` 的直接后果**:它登记的条件 (c) 依据在事实上是错的,必须重新论证~~
      **2026-08-22T04:00Z done**。两行 build 各花 **4 点**在 Bone Guard 上,`wkbuild` 只是把
      后三点从 **3/5/7 推到 9/10/12**。新 (c) **不是「更早的眩晕」这个口号,是一条在出货代码里
      可驱动的机制**:Bone Guard 的**冷却与等级无关(恒 42s)**,一点技能点买的是**上限**
      2→4→6→8;而 `X.ConsiderW` 仅有的两条开火分支都是**对上限的阈值**
      (`nStack/maxStack >= 0.6` / `nStack == maxStack`),唯一旁路 `talent6:IsTrained()`
      是 20 级测试(GH #84:0/210)⇒ turbo 里**每加一点 Bone Guard,两条分支要求的绝对层数
      都单调上升**(分支 1:2/3/4/5;分支 2:2/4/6/8)。默认表 **7 级点满** ⇒ 一个 15 补 /
      0.6 杀的 WK 从 7 级起必须攒到 **8 层**才肯放;`wkbuild` 让他整个对线期停在**上限 2**。
      交付 `tests/test_wk_bone_guard_thresholds.lua`(**10 例**,层数钉死只动技能等级;
      阈值是**从代码里扫出来的**不是断言的)+ **9 次变异 8 抓,M9 是有意的等价变异**
      (`>=0.6`→`>0.6` 在整数层数上端到端相同,已写明)。
      **两个自报边界(引用时必须一起带)**:①定的是**符号不是大小** —— 「两次释放之间攒几层」
      离线问不出来,**dumper 不 dump modifier 层数**(与 §3 魔棒充能 / GH #27 同一族);
      ②上限也提高**单次载荷**(8×49 vs 2×34),本条主张是**单侧**的。
      **判词的修改权在总监**,已在报告 §4 提请替换。
    - **本轮顺带更正上一轮自己的一个数(#104 已发表 24h)**:`blast_dot_damage` 的
      heading 是 **DAMAGE PER SECOND**、`blast_dot_duration = 2` ⇒ dot 总量
      **40/80/120/160**,满值一发 **120/180/240/300**。所以 `nDamage`(100/140/180/220)
      **既不是落地也不是满值**,夹在两者之间;`*1.68` 的 370 **同时**超过落地(2.64x)
      **和**满值上限(1.23x)。**Lever A 的诚实对照数是两个不是一个。**
      **方法上的一条**:重锚数值时**连 `heading_loc` 一起抄** —— 裸数组 `[20,40,60,80]`
      在「每秒」和「总量」两种读法下都自洽(都是 4 个按级递增的数),heading 是唯一判别式。
    - **`talent6:IsTrained()` 是 20 级测试**(`X.ConsiderW` 两条释放分支的析取旁路)。
      证明链在仓库自己的代码里:`aba_skill.lua:135` 的 `GetTalentBuild` 驱动 t20→索引 {5,6}
      ⇒ 配 GH #84 的 `level>=20` **0/210**、高水位 19 ⇒ turbo 内分支 2 严格 = 满层、
      分支 1 严格 = >=60% 层。**这是 §4.2 的下一层**:§4.2 说的是一张**表**里的死重量,
      这里是一个 t20 handle 被读进**出货中的决策函数**。
      - ~~**Lever B(两条 t20 析取的记账)**~~ **2026-08-23T19:50Z 结案:NOT-A-DEFECT(GH #150)。**
        原假设(「bypass 关掉了释放规则唯一的弹药检查」)**死于一行 dname**:索引 6 =
        `special_bonus_unique_wraith_king_facet_3` = **"+5 Bone Guard Skeletons Spawned"**,
        是**每次释放的骷髅数**(平量),配 `min_skeleton_spawn = **0**` ⇒ 学了它**空仓释放照样出
        5 个骷髅**,「不管存了多少都放」**正是对的规则**。三条断言全部**从代码/feed 读出来**:
        平量形状 + `min_spawn=0`、两处读**都是 `or` 的右操作数**(只能加开火)、**本文件在 t20
        真的取索引 6**(把 `tTalentTreeList` 从代码里捕获出来喂给出货的 `GetTalentBuild`
        —— `test_wk_fact_anchor.lua` §2 钉的是「t20 驱动 {5,6}」,**没钉取哪一边**)。
        **⭐ 但在证伪它的路上量到更该记的一件事:`X.ConsiderW` 整条在 fixture 里验不了。**
        第一道门要的 `modifier_skeleton_king_bone_guard` 在 **0 / 34** 个 WK 帧上存在,而
        **17 帧带 modifier 列表、17/17 带兄弟 `modifier_skeleton_king_*`**(分母在)⇒ 出货
        `X.ConsiderW()` 在真实帧上 **0/34**。**名字没写错**:全仓唯一施法者就是它
        (`spell_list.lua` 那行只有 morphling require)、语料 **4 帧**抓到技能正在冷却
        (40.2/32.5/27.1/3.5 对恒定 42s)、GH #77 的 ground truth 里有 WK 骷髅的伤害
        ⇒ 引擎答过 true,缺的是**管线**(`make_fixture.py` 的 modifiers 从战斗日志
        ADD/REMOVE **成对**重建,这一个没有对)。**一字段反事实**:只授予 `HasModifier`,
        **20/34 帧**结果改变(越过门后撞上 GH #61 的 lane-front 拒答)⇒ **20 就是盲区大小**。
        另两条让释放**算术**离线无意义:`GetSpecialValueInt` 读 0 ⇒ 比值 `0/0` false、等式
        `0 == 0` **true**(branch 2 弹药检查白送);loader **没实现 `GetModifierByName`** ⇒
        默认 0 ⇒ 层数读的是 modifier 列表**按名排序的第一行**(实测 reincarnation_scepter)。
        **第二条不归本组**(改成 -1 会动所有读 stack 的分支),已写进 GH #150 §3 交 harness。
        **残留(登记不 argue)**:若引擎只在 charges>=1 时挂那个 modifier,顶上那道门就把
        bypass 想解除的弹药要求**又加了回去** ⇒ 「空仓 +5」永不发生;引擎内问题,**GH #108
        的 10→25 分钟是让它付得起(20 级)的那个改动**,也是重开触发器。
        交付 `tests/test_wk_bone_guard_talent_bypass.lua`(11 例 / **9 变异 9 抓 + 1 no-op
        对照如期逃逸**),`bots/` **只动注释**(`X.ConsiderW` 上方写死「域只能用批测量,
        不能用 fixture 扫」)。**下一棒 = queue `hero-11`**(归档事件流扫描,零 EC2:
        ① 日志里有没有这个 inflictor 的 `MODIFIER_*` 行 —— 读 0 ⇒ 永久 batch-only;
        ② 若有,两次释放之间存几层 = `wkbuild` (c) 的**大小**那一半)。
    - **顺带交付一张全 BotLib 普查**:t20/t25 handle 的 **STRUCTURAL** 读共 **24 处 / 7 英雄**
      (lion 14、skeleton_king 2、lich 2、legion_commander 2、warlock 2、chaos_knight 1、zuus 1),
      机械判据(同一行含 `GetSpecialValue` ⇒ ADDITIVE,否则 STRUCTURAL)已写进测试并上棘轮。
      **形状不决定结论**:lc/lion/zuus 那三家只是「地面施法 vs 单位施法」二选一,else 就是
      正确默认 ⇒ 无可观测代价;真正减行为的是 chaos_knight / lich / skeleton_king。
      四个非焦点英雄按章程交总监/协同组。
    - ~~**下一轮从这里起:优先 Lever A**~~ **2026-08-22T06:00Z:Lever A 的域被本组自己缩到
      一个盒子里,而且不用语料 —— `DOWNSTREAM-DOMINATED`(第七类处置)。**
      `X.ConsiderQ` 的最后一条分支是 `nLV >= 7` 的**无条件兜底**(`nCastRange + 43` 内有任何
      敌方英雄就 HIGH),所以**从 7 级起击杀判据虚不虚报都改变不了「这一发放不放」**:
      7 级、568 内,目标血量 1→满血全扫**没有一个值让它闭嘴**;5 级同扫有真有假(防空断言)。
      **更糟的一半是代价侧**:收窄不是「不放」是「改瞄」—— 两敌帧实测,带内时瞄 25% 血的 lion,
      判据一诚实就改瞄**列表第一个**的满血 sven,冷却和蓝照花。
      ⇒ **Lever A 的残余域 = {英雄等级 1-6} ∪ {568 < d ≤ 605 的 37 码壳}**,语料只需数这个盒子。
      读数全部从出货代码扫出来(自称血量 **126/176/226/277** vs 落地 60/75/90/105 vs
      落地+整段 dot 90/135/180/225;等级悬崖 **7**;两个射程 **568 = cast+43** / **605 = cast+80**),
      真实帧同一个悬崖(`f_232320_wk_od_burst`,6 级沉默 / **只改等级这一个整数到 7** 就对 86% 血的
      OD 开火)。交付 `tests/test_wk_considerq_level7_dominance.lua`(13 例,**9 次变异 8 抓**,
      M6 是有意的等价变异:兜底里的 `#nEnemysHerosInRange >= 1` 与它保护的 `for ... in pairs` 冗余)。
      **零行为改动、零新 gated id、零 AWS。** 详见
      `iterations/reports/hero/20260822T060000Z.md`;登记
      `state.json:wk_considerq_downstream_dominance_20260822T0600Z`;GH **#104** 追评。
      - **下一轮的 lever 换成兜底分支本身(建议 id `wkqhold`)**:WK 唯一的硬控从 7 级起被当消耗技
        在冷却上刷掉,与 Zeus `zusult`(§4)、Lion Finger(§7 / GH #73)是同一家族第三例。
        **是「新增否决」= `lanefix` 的失败形状,代价侧(骚扰价值)必须先想清楚**,要自己的帧证据
        + 语料域,别和 Lever A 绑在一起测。
      - ~~**下一轮的 lever 换成兜底分支本身(`wkqhold`)**~~ **2026-08-22T10:00Z:那个建议来自
        08:00Z 那一轮的评论,而那一轮的树从没推上来(见"当前状态"头条一)。它给出的两条排它理由
        (Q 冷却 14/12/10/8s 而不是 Finger 的 110s ⇒ 一刀切否决最多买 14 秒;残余域里 (b)「挨打了
        但没朝向他」与 (d)「RETREAT + >=2 队友」是真代价 ⇒ `lanefix` 失败形状)**本轮没有独立复核**,
        引用前必须自己重读代码。** 它顺带提的替代品 **`wkqaim`(改瞄不否决:兜底取血量最低的而不是
        最近的)** 本轮已按它的口径提了 `queue.json: hero-1` 量域,**读数回来之前不写代码**。
      - **Lever A 若还要做**:只能在 1-6 级那一段论证,而且要连**兜底分支一起改**才谈得上省冷却。
      历史记录(仍有效的部分):`X.ConsiderQ` 的 `nDamage = 40*(lv-1)+100` 是**落地 + 整个 2 秒 dot**
      (80+20/100+40/120+60/140+80),再 `* 1.68` 喂 `J.CanKillTarget` ⇒ 4 级**声称 370 魔法伤害**
      而落地只有 140,而这是「打得死就上」那条分支的判据(WK 0.6 杀 / 3.2 死)。
      **桌面两问都已过**(谓词全是帧内量;`ConsiderQ` 是 `SkillsComplement` 第一个消费者、
      desire>0 立刻 queue 并 return)⇒ **缺的只是域的形状,要语料**(§Y.2:桌面能证 EMPTY 不能证 RARE)。
      ~~Lever C(`bot:GetMana() >= 600` 打肉山分支;… **21 级才越过 600** … ⇒
      turbo 结构性不可达)~~ **2026-08-23T18:00Z:「结构性不可达」这句撤回,它是错的。**
      漏了**物品那一侧**(魔棒 +3 全属性、pos_3 第 6 件;护腕 +2 智力、第 7 件;树枝每根 +1;
      神杖 +10 全属性**且 +175 平蓝**),又**没对智力取整**(高报最多 7 点:15 级 502→**495**、
      19 级 569→**567**、20 级 586→**579**)。修正后的越线等级:空手 21 / 两树枝 20 /
      **魔棒 19** / **魔棒+护腕 18** / 神杖后 1 级起,而 GH #84 的 turbo 高水位正是 **19**
      ⇒ **落在分布尾部,不是永不**。公式 `75 + 12*floor(16 + 1.4*(lv-1) + item_int) + flat`
      在 **34 个真实 WK 帧上 33 个逐位精确**(第 34 个点名钉住:`f_232320_wk_od_burst`
      6 级报 272 / 模型 363,同帧邻居同向偏 ⇒ 疑那一帧;**33 行全 ≤12 级,结论区间是外推**)。
      **幸存缺陷更锋利**:神杖前每个里程碑的越线池子都恰好 **603** ⇒ 600 要的是**池子的 99.5%**,
      而 Blast 只要 95/110/125/140 ⇒ **地板是它把守技能造价的 4.3 倍、放一发就再够不到**。
      **仍然不写候选**:域「WK 进不进 `BOT_MODE_ROSHAN`」**结构性买不到** —— 第 13 条世界断言
      (`GetActiveMode` 不在任何 .dem)⇒ 归档里每一帧恒 FALSE,fixture 上的 0 是**关于工具的事实**。
      交付 `tests/test_wk_roshan_mana_ceiling.lua`(13 例,**17 次变异 17 抓** + 1 个 no-op 对照
      如期逃逸),报告 `iterations/reports/hero/20260823T180000Z.md`,登记
      `state.json:wk_lever_c_mana_ceiling_20260823T18`,**下一棒 = queue `hero-10`**
      (归档扫描;(1) 18/19 级供给读到 0 ⇒ 直接退役;(3) 肉山位置代理读到 0 **不是**空域证据)。
      GH **#104 §5** 已留言更正。
      **⚠️ 2026-08-26T01:52Z 更正上面那句「仍然不写候选」:候选已经写了(gated `wkrosh`,GH #199,
      见 backlog §-16)。** 撤回的**不是**域那条论证(它一字未改、仍然成立),而是**从它推出的
      「所以现在不能写」**:域买不到是**入集/promote** 的前置,不是**落地一个 gated 候选**的前置
      (`lionsplash`/`axecull`/`zusboltcap` 全是这个形状)。而且**蓝这一维在同一份语料上问得了**:
      34 帧清得过 600 的 **0 个**,最大 `max_mp` **459** ⇒ **满蓝也够不着**,这个数**不经过 mode 谓词**。
    - **跨组、只登记不动**:天赋是**按索引**选的,而 WK 的索引 2 / 6 是 **facet 门控**天赋
      (`..._facet_1` / `..._facet_3`);`GetTalentList` 只收 `IsTalent()` 为真的槽 ⇒
      某个 facet 没被选中导致该槽不是天赋时,**其后所有索引整体前移**,全英雄池的
      `tTalentTreeList` 都会选错人。离线不可证伪(mock 天赋槽是空的)。
    - **方法上的一条(已进报告)**:第一稿的档位测试断言的是**我自己的排序假设**
      (「第三个 pick 就是 t20 那个」),一个把 `[3]` 重指到别的档位键的变异**从它旁边走过去**。
      改成**每次只翻一档、看返回的哪几个索引变了**,把接线从代码里读出来,M6/M12 才都抓住。
      **「断言一个映射」和「把映射从代码里读出来」是两件事。**

18. **焦点五天赋梯子重锚(2026-08-22T14:00Z 起)** —— #104 的方法推到其余四个焦点英雄。
    - ~~**五个英雄的 t10/t15 到底在选什么**~~ **2026-08-22T14:00Z done**,五张对子表见
      `iterations/reports/hero/20260822T140000Z.md` §1 与 `tests/test_focus_talent_anchor.lua`
      的 `FOCUS` 表(12 例 / **7 次变异 7 抓**)。**只有 t10/t15 在 turbo 可达**(GH #84),
      t20/t25 记录但不上棘轮。
    - ~~**Axe t10**~~ **2026-08-22T14:00Z 改了**:`{0,10}`(Culling 击杀 buff +3s)→ `{10,0}`
      (每个生效 Battle Hunger **+8% 移速**)。**纯数值改动、不 gate ⇒ 已在稳定版里**。
      (c) = 兑付条件之差:[1] 要先用 70-80s cd 的处决技拿到人头、且只延长一个战后 buff;
      [2] 只要 Battle Hunger 在跳就付,而它是本文件**买的第一点**、10 级点满、
      `X.ConsiderW` **四条**分支在放;而这个 Axe **turbo 里从没有跳刀**(GH #56)⇒ 全程走路。
      **诚实边界**:放弃的是团队 buff 3 秒;**没读语料**(数的是施放条件不是每局次数);
      pick-rate 佐证抓不到(dotabuff 403 / liquipedia 429 / fandom 402)。
    - ~~**下一根(登记、没做)**:`X.ConsiderR` 的 `nKillDamage = 150 + 100*lv`~~
      **2026-08-22T18:00Z 上机前语料核验完成 —— DO NOT WRITE(本轮),但处置是第七类
      `NARROW-BAND-UNMEASURABLE`,别和前五次的「域空」记在一起**:域**没有被证明为空**,
      是**证明了用帧语料量不出来**。26 个带 Axe 的 fixture 帧 / 20 帧 Culling 就绪 /
      **3 帧**敌人进了有效 375u 环,带内 **0** —— 但 25 点带对约 1000 的血池,
      3 个环内帧的**期望命中 ≈ 0.08**,这个零**两种世界里长得一模一样**。
      **五种已知塌陷模式一个都不适用**(无上游同胞:`X.ConsiderR` 全函数**只有一个开火分支**;
      无消费侧绕行;无更强的已有守卫 —— 本修改是**放宽**唯一那个判据;载体不缺;
      **且分支在语料里可证是活的** —— `f_260820_043637_axe_ring_close` t=393.4,
      skywrath 221 血 / 188u,对 250 门槛,出厂代码就在那儿开火)。
      **不依赖域的那条理由(最强的 (c)):陈旧是双向的** —— 今天常数低 25 点,代价是漏一发;
      它当年**是对的**,下一次数值改动把它顶到实际伤害**之上**时,bot 会拿 **80 秒大招**
      去打一个**打不死**的目标,**比今天更坏而且无声**。`GetSpecialValueInt('damage')`
      一次性消掉两个方向,且这个 API **本函数下一行就在用**(talent8)。
      **顺带纠正预注册域的口径**:注释写的「目标 175 内」是错的 —— 开火循环跑的是
      `nCastRange + 200` 的表,**有效环是 375**;`nInRangeEnemyList`(175 那张)
      **算完从不读**(luacheck 看不见:`.luacheckrc` 只开 `only = {"1"}` 全局类告警)。
      ⇒ 分支会对**射程外最多 200u** 的目标返回 DESIRE_HIGH。**这是第二根杠杆,单独登记、没动。**
      交付 `tests/test_axe_culling_threshold_preflight.lua`(8 例,**7 次变异 7 抓**),
      **零行为改动**(没碰任何 `bots/` 文件);棒子 = `queue.json: hero-2`(**改到事件侧数**)。
    - **更正 §「跨组、只登记不动」那条 facet 担忧的证据强度**:`..._facet_1` / `..._facet_3`
      这类**名字带 facet 不等于 facet 门控** —— feed 里它们的加成挂在普通技能的普通数值上、
      `required_facet` 为空;Lion 的 `to_hell_and_back` 更是标 **innate**(不是 facet 技能),
      Zeus 的 `cloud`/`lightning_hands` 分别是 **scepter/shard** 授予(不占初始槽,
      所以 Zeus 的 `sAbilityList` 1/2/3/6 没有漂移)。**索引前移这个机制本身仍可能成立**,
      但**本轮拿到的证据不支持它在焦点五身上发生**;而且 datafeed 对这五个英雄
      **`facets` 数组一律为空** ⇒ 这个端点根本回答不了 facet 问题,别再拿它当证据。
    - **四个没有明显赢家的对子,别凭口味翻**(要翻就带各自的兑付条件分析):
      ~~Axe t15~~、~~CM t15~~、~~Lion t10~~ / ~~Lion t15~~、~~Zeus t15~~。
      **2026-08-22T19:50Z 处理掉两个,21:48Z 又处理掉两个,2026-08-23T04:00Z
      处理掉最后一个 —— §18 全部对子闭合**,见下:
      - ~~**Axe t15**~~ **2026-08-23T04:00Z 没翻,理由钉死了别再重推**:
        `{0,10}` = [3] `special_bonus_unique_axe`(+8 Battle Hunger dps)保留,
        拒掉 [4] `special_bonus_unique_axe_7`(+10 Berserker's Call 护甲)。
        同一把「兑付可达性」的尺子,而且这次**两个通道同向**:
        ①**结构上限**(datafeed hero_id=2 + 本文件自己的加点行,15 级两个技能都是 rank 4):
        Battle Hunger 12s 持续 / 5s 冷却 ⇒ 可**长期常驻**,上限 1.00;
        Berserker's Call 3.0s / 12s ⇒ 上限 **0.25**。**四倍的兑付机会,还没测就有了**。
        ②**语料**:26 个存活 Axe 帧,其中 **16 帧带 modifier**;敌方英雄身上挂着
        `modifier_axe_battle_hunger` 的 **5 帧**,Axe 身上挂着
        `modifier_axe_berserkers_call_armor` 的 **1 帧**;按这些帧**实际持有的等级**
        求和,两边的结构上限是 **14.00 帧 / 1.94 帧** ⇒ Call 那边已经到自己天花板的
        **约一半**(SATURATED,不是被冷落),BH 那边只到 **约三分之一**。
        **差距是天花板本身,不是 bot 可以补上的余量。**
        **被拒那边的最强论证照记**(它输在频率不是质量):[4] 是**相对更大**的加成
        (15→25 护甲 +67% vs 24→32 dps +33%);嘲讽**自带保证**——它挡的那些攻击
        一定会来;innate **One Man Army** 把 50% 护甲转成力量(条件:700 内无友军),
        而 `X.ConsiderQ` 的**打野嘲讽分支**(要求 1600 内无敌方英雄)正好把他放进那个状态。
        **诚实边界(四条,都往削弱本读数的方向)**:(1) **整个语料没有一帧在域内** ——
        Axe 最高 14 级,天赋 15 级才存在,**全部是低一级的代理读数**;(2) Call 那边
        **n=1**,对 ~1.9 帧的上限只能佐证算术,单独什么都不成立;(3) 量级对比
        (满程 BH ≈ +96 裸魔法 vs +10 护甲在 3 秒里挡下的物理)是 datafeed 上的**算术**
        不是量测 —— fixture 不 dump 护甲,`recent_damage` 不带伤害类型;
        (4) BH「目标击杀单位即结束」⇒ 12s 是上界,dps 天赋的**实际**兑付比 12×8 小,
        小多少本语料量不出来。**保留 [3] 的代价也记下**:`damage_per_second`
        在本文件**恰好一条活行**上被读 —— `X.ConsiderW` 把它乘满 12s 塞进交给
        `J.WillMagicKillTarget` 的伤害声明,**所以 [3] 不是纯引擎效果**,它加宽了一个
        本来就把整段 dot 当即时伤害算的击杀判据(与 WK `ConsiderQ` 同族);
        [4] 在本文件**零消费点**。两半都写成断言,任一边出现新消费方就重开这个对子。
        交付 `tests/test_axe_t15_payoff.lua`(13 例,**12 次变异 12 抓**,60ms、
        **不用子进程 sweep**,不吃 GH #124 的成本);登记
        `state.json:axe_t15_no_flip_20260823T0400Z`;pick-rate 佐证仍抓不到
        (dotabuff 403)⇒ 条件 (c) 靠机制不靠攻略。
      - ~~**Zeus t15**~~ **翻了**:`{0,10}`(+75 大招伤害)→ `{10,0}`
        (`special_bonus_unique_zeus_6`,Arc Lightning 蓝耗/冷却 −20%)。**纯数值、不 gate
        ⇒ 已在稳定版里。** 论证形状 = **兑付的可达性**:语料里大招**学了且不在冷却的 16 帧,
        7 帧付不起蓝**(剔掉本组为「Zeus 蓝」专门裁的四个 fixture 仍是 4/12),缺口
        26/60/98/106/123/151/239,**中位约等于一发 Arc**;而 [4] 正好削 Arc 的蓝耗
        (85/90/95/100 → 68/72/76/80),两行 build 都往 Arc 砸四点。放弃的那一边
        (GH #47:每局只放 1-3 次大、6 次里 5 次已经杀到人)**只能在放出去的那一发上兑付**。
        **诚实边界**:语料有偏 ⇒ 存在性不是密度;**所有就绪帧都是大招 rank 1**,那里 +75
        是 **+27%** —— **单次兑付更大的那边正是被放弃的那边**;**Arc 每局放几发没数**
        (20% 省蓝要约 5 发才补回 106 的缺口)⇒ 已交 `queue.json: hero-3`。
        冷却那一半(1.6→1.28s)**不在主张里**,近乎无价值。
      - ~~**CM t15**~~ **没翻,理由钉死了别再重推**:三条代码事实 ——
        ①**包含**:`ConsiderQ` 环 `GetCastRange()+aether+32`=**732**,`ConsiderW` 环
        `+30+aether`=**630**,+100 天赋推到 **730 仍在里面(差 2 码,aether 相消)**;
        ②**顺序**:`SkillsComplement` **Q 在 W 之前**且中间就 return ⇒ 射程天赋**只在
        Nova 拒绝的帧上兑付**,而对面那条兑付进**有优先拒绝权**的消费者(①②**支持翻**);
        ③**真正的瓶颈**:4 级 Nova **175 蓝**、cd 8→3.5s ⇒ **50 蓝/秒**,辅助没有这个回蓝
        —— 卡 Nova 的**从来不是冷却是蓝**,而 CM 文件里**没有任何机制**在 Nova 和大招之间
        仲裁。③**拦下了它**。
      - ~~**Lion t10**~~ **2026-08-22T21:48Z 翻了**:`{0,10}`(`special_bonus_unique_lion_6`,
        +10pp Mana Drain 减速)→ `{10,0}`(`special_bonus_movement_speed_20`,+20 移速)。
        **纯数值、不 gate ⇒ 已在稳定版里。** 同一把尺子(兑付**可达性**):减速只有一个收款处
        —— `X.ConsiderE` 正在对**敌方英雄**读条,而四个 return 里只有两个是敌方英雄
        (补篮取**小兵**且要 `#hEnemyList == 0`,另一条打幻像),且这两条**都在**
        `if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end` **下面**
        ⇒ 对英雄抽蓝是**残余动作**(Q/W/R 同时不可用),之后**还要**850u 内有蓝>200、
        没被控、又杀不掉的敌人;+20 移速**没有任何谓词**。真实帧:**22 个活 Lion 帧,
        闸门开 8,整条链满足 2 —— 而这 2 帧全是本组为研究抽蓝专门裁的 fixture**。
        **诚实边界**:语料有偏 ⇒ 存在性不是密度;出货加点表让 Mana Drain **10 级就是 rank 4**
        ⇒ **放弃的正是它最大的那一版(30→40)**,和 Zeus t15 是同一笔交易;+20 对 290 基础,
        而 `pos_4/5` outfit 自带秘法鞋 ⇒ 实战相对增幅约 **+6%**;天赋的**给队友**那一半
        两边都够不到(`ConsiderE` 没有队友分支)。
      - ~~**Lion t15**~~ **没翻,理由钉死了别再重推**:[3] Hex 冷却 −2s 的域是
        **24 秒冷却里的最后 2 秒**这条窄带(出货加点 **12 级才 rank 2** ⇒ turbo 全程 24s;
        语料 20/20 帧都是 rank 1),按 18:00Z 立的规矩**窄带上的零记 UNDERPOWERED 不记 EMPTY**;
        [4] To Hell and Back 增幅 +15pp 的两个窗口(复活后到下个人头/助攻;拿到人头后那人躺着期间)
        ~~**dumper 根本看不见**(不 dump modifier,GH #27)~~ —— **2026-08-23T04:00Z 更正:
        这条依据是错的,fixture 是带 modifier 的**(45/101,2026-08-19 之后裁的全都带,
        字段 name/remaining/elapsed/stacks;载体 `tests/test_fixture_modifiers.lua`
        **本仓早就有**,不在 issue 里)。而且这两个窗口**当下就在语料里**:
        `modifier_lion_to_hell_and_back_buff` 2 例 + `..._respawn_buff` 1 例。
        **所以 Lion t15 的这一半是可以重开的**,它现在缺的是**量**不是**可观测性**
        (n=3,先量域再谈翻不翻)。GH #27 家族里**物品充能层数**那个缺口不受影响
        —— 那是 item charges,不是 modifier stacks,§3 那条仍然成立。
        ~~**两边最终买的是同一样东西**(Hex 控制量:[3] 买次数、[4] 买时长)⇒
        **没有可花的可达性不对称,默认不翻**。~~
        **⚠️ 2026-08-23T22:20Z 更正:上面这一整段是过期散文,别再照它派活。**
        这一条**当天 04:00Z 就已经重开并结案了**,落地在
        `bots/BotLib/hero_lion.lua` 的 t15 论证块 + `tests/test_lion_t15_payoff.lua`
        (「t15 RE-EXAMINED 2026-08-23 and still NOT changed -- but on measurements
        this time」)。结论仍是**不翻**,但**理由换了、而且否掉了本段的两句话**:
        ①「两边买同一样东西」**是错的** —— [4] 的 spell-amp 那一半同时抬 Earth Spike
        与 Finger 的伤害,**[4] 是更宽的那个**;②[3] 被本段**低估**了 —— 24s 是 rank 1
        (语料 Lion 只到 11 级),而天赋 15 级才存在,那时出货加点已经三点进 Hex ⇒ **16s**,
        −2.0s 买的是 **+14.3%** 次数不是 +9.1%。真正定案的读数是「Hex 学了的帧上
        **9/20 就绪且付得起**」(冷却不是稀缺项)与「≤2s 带命中 **0/20**,期望 ~0.9 ⇒
        UNDERPOWERED 不是 EMPTY」。`queue.json hero-4` 第 (2) 问仍然挂着,但它现在是
        **锦上添花不是唯一出路**。
        **教训(第二次踩,和 §24 的死胡同同族)**:19:50Z 那条「下一轮建议」是**照 backlog
        散文写的**,而 backlog 散文比代码晚了 15 小时 —— 认领任何 backlog 残留项之前,
        先 `ls tests/ | grep <关键词>` 并读一眼目标文件里的论证块,**代码是账本,散文不是**。
      - **Lion 那三条顺带事实(记录,本轮不动)**:①文件绑 talent 句柄 **{4,5,8} 但只消费 5/8**
        (都是 t20/t25,turbo 够不到),`talent4` 唯一用处是**注释掉的**那一行 ⇒ 本文件
        **没有分支读 turbo 可达天赋**,所以 t10 改动是纯引擎效果;②那行注释是 **Zeus `talent5`
        同款错键读**(要 `'value'`,而 lion_11 的键是 `bonus_spell_amp`/`bonus_debuff_amp`)
        ⇒ 取消注释会读到 **0**;③**`talent8` 被当「AoE Hex 开关」用了十三处**,但按槽位序
        **索引 8 是 +600 Earth Spike 射程**、**索引 7 才是 +250 AoE Hex** —— t25 不可达 ⇒
        今天无行为差异,**但任何让 t25 可达的改动必须先重读那十三个调用点**。
      - **顺带三条事实(都已上棘轮)**:①`hero_zuus.lua` 的大招击杀判据加的是
        **`talent5`** —— 索引 5 是 **+60 Arc 伤害的 t20 行**、special value 叫
        `bonus_arc_damage` 不叫 `value` ⇒ **恒 0**;**只注释没重指**(引擎会不会已经把天赋
        折进 `GetSpecialValueInt` 离线判不了,重指要么双计要么悄悄抬高判据)。
        ②`talentDamage` 写两次零读 + 其唯一输入 `talent8`(t25 充能天赋,同样取错键)
        **已删**(行为保持,同 #104/GH #73)。③**CM 的 Frostbite 射程是 600 不是 500**
        ⇒ `ConsiderW` 里那条 `nCastRange < bot:GetAttackRange()` 兜底(要 ≤569 才开火)
        **在出货数值上是死支路**,是 500 射程年代的化石;**保留没删** —— 它的不可达依赖
        **运行期量**,不是零读的局部,**这条判据差别本身是本轮要留下的东西**。
      - **CM 也没有为大招留蓝(这一家的第三例:Zeus GH #47/#59、Lion GH #73)**:
        文件里最高的蓝闸 `nKeepMana*2 = 440` **只守对线消耗分支**,团战里开火的
        击杀/AoE 分支**一条蓝谓词都没有**;语料 **24 个大招就绪帧 5 个付不起**,
        其中一帧 **399 对 400 —— 差一点蓝**。**`cmkeep` 故意没写**:一个留蓝 gate 的
        **全部域**是 `[cost, cost+nova)` 带 = **2 帧**,身后已有六次上机前否决,
        先按 `hero-3` 第三问去档案语料量。

19. ~~**CM 的蓝不够,首先是采购问题不是天赋问题(GH #126,2026-08-23 立)**~~
    **2026-08-23T02:00Z 做完并已落地(无 gate ⇒ 在稳定版里,本轮稳定版漂移了)**:
    pos_5 `item_mage_outfit` → `item_crystal_maiden_outfit`(宁静→秘法),**并同时删掉
    `item_boots_of_bearing`** —— 它的配方 = tranquil_boots + ancient_janggo +
    ring_of_tarrasque,**吃的正是宁静鞋**,不删就会再买一双鞋(移速不叠加),
    而采购层不会拦(主流程跳过表只认原始 `item_boots`)。
    量测:宁静臂 45 个就绪槽 **12 个付不起蓝**;秘法臂(pos_4,平均等级 8.14 vs 8.13)
    **14 个槽 0 个付不起**(p≈0.013,混杂 + n=7 ⇒ 提示性不是定论);+125 解锁 9、+275 解锁 12。
    **本案不靠裸蓝**:+125 比前一天判「单独不够」的 +144 还小,靠的是 Replenish
    (150 蓝 / 55s / 1200 内全队),而出厂代码已经会放,零行新代码。
    代价照记:宁静的 14 血/秒**没有任何通道能定价**(UNDERPOWERED,且与 owner P2 同向相反);
    Bearing 在语料里 0 个持有者但那是 **OUT-OF-WINDOW**(窗口止于 11:30)。
    **下一棒 = queue `hero-5`**(条件 a:真买到没有 / 有没有两双鞋)。
    详见「当前状态」头条、`tests/test_cm_pos5_boots.lua`、
    `state.json:cm_pos5_boots_20260823T0200Z`。**原始条目留档如下:**
    做 t10 核验时顺手量到:域内 13 行 CM **11 行走 pos_5**,而 pos_5 的
    `item_mage_outfit`(null_talisman + **tranquil_boots** + magic_wand,再 ancient_janggo)
    **前段一件以蓝为主的装备都没有**;另 2 行 pos_4 走 `item_priest_outfit` 带
    **arcane_boots**(+250 蓝)。而 `bots/FunLib/aba_item.lua:969` 躺着一个
    **从没人引用**的 `item_crystal_maiden_outfit` —— 就是 mage_outfit 把 tranquil 换成
    arcane_boots。**没动它**:出装是纯数值改动可以不 gate,但必须在**同一批帧**上把
    tranquil 的血回/移速那半一起量,**不许只算蓝那半**;并给一条真实帧读数。
    **别重查的两件事**:(a) 「实战出装偏离了文件」是**错的**,pos_4/pos_5 两条都是文件
    自己的表,不存在偏离;(b) 26 个就绪槽里 11 个付不起蓝这个读数**本身**不必重测,
    要测的是换鞋之后那 11 个变几个、以及丢掉的回复/移速值多少。

20. ~~**Lion t15 可以重开了 —— 当初封存它的理由(「dumper 看不见 modifier」)是错的
    (2026-08-23T04:00Z 立,来自 Axe t15 那一轮的顺带发现)**。
    §18 里 Lion t15 判「不翻」靠两条腿:[3] Hex 冷却 −2s 的域是窄带(**这条仍然成立**,
    出货加点 12 级才 rank 2、语料 20/20 帧都是 rank 1);[4] To Hell and Back +15pp
    的两个窗口「dumper 根本看不见」——**这条作废**。fixture 45/101 带 modifier
    (2026-08-19 之后裁的全带),而且这两个窗口现在就在语料里:
    `modifier_lion_to_hell_and_back_buff` 2 例、`..._respawn_buff` 1 例。
    **下一步(小工作单元,不需要 AWS)**:按 Axe t15 的四通道口径量 [4] 的域 ——
    (a) 有多少 Lion 帧处在这两个窗口内(n 现在只有 3,先看它是 SATURATED 还是
    UNDERPOWERED:两个窗口各自的结构上限是多少);(b) 窗口内 Hex/Finger 的实际施放;
    (c) [3] 的窄带零维持 UNDERPOWERED 判读不动。**结论可能仍是不翻** —— 重开的是
    *依据*不是*结论*,不要预设方向。
    **顺带的通用纪律(已进 `tests/test_axe_t15_payoff.lua`)**:modifier 的
    **`elapsed` 不是「已经跑了多久」** —— lich 身上 `modifier_axe_battle_hunger`
    是 elapsed 13.1 / remaining 9.6,加起来 22.7 秒而 BH 只有 12 秒;BH 不叠加
    (`should_stack` 0)⇒ 重新施放是**刷新**,remaining 重来而 elapsed 从**第一次**
    施放继续数。**只有 `remaining` 能用**;任何拿 elapsed 或 elapsed+remaining 当
    时长的读数,对每一个可刷新的 modifier 都是错的。
    **别再拿 GH #27 当 modifier 不可观测的依据**:那个家族里还成立的是**物品充能层数**
    (item charges,§3),不是 modifier stacks(`stacks` 字段一直在)。
    还有:**本仓的世界断言知识主要在 `tests/` 里** —— 这条本可以早就知道,载体
    `tests/test_fixture_modifiers.lua` 早就在树上(第二次栽在同一件事上,见 08-22T23:54Z)。~~
    **2026-08-23T06:00Z done —— 量完了,还是不翻(仍取 [4]),但两条旧依据都被推翻**:
    ①窗口**看得见**(10 个带 modifier 的 Lion 帧里 3 帧在窗口内:击杀侧 2 / 复活侧 1);
    ②[3] 被**按错档位定价** —— 24s 是 rank 1(语料档位),**域里 15 级 Hex 是 rank 3 = 16s**
    ⇒ −2.0s 值 **+14.3%** 施法次数(16 级起 **+20%**),不是 +8.3%。
    **定案通道**:20 个学了 Hex 的帧里 **Hex 就绪 9 帧且 9 帧全付得起蓝** ⇒ 稀缺的是**目标**不是
    Hex 次数(这正是它与 CM t10「缺蓝」的分水岭);≤2s 转化带 **0/11**,期望 ~0.9 ⇒ UNDERPOWERED。
    详见「当前状态」头条、`state.json: lion_t15_no_flip_20260823T0600Z`、
    `tests/test_lion_t15_payoff.lua`。

21. ~~**`hero_zuus.lua:31` 与 `test_focus_talent_anchor.lua:265` 的两处 off-by-one 散文
    (GH #134,2026-08-23 立)**~~ **2026-08-23T09:50Z done**,两处都改成 **11 级**并就地写明
    「行的第 10 项,10 级花在天赋上」。**没有照抄 §21,两条加点行各自独立复核过**:
    Zeus pos_4/5 `{2,1,2,3,2,6,2,1,1,1,6,...}` 的 Arc 落在第 2/8/9/**10** 项、
    Axe `{2,3,1,3,3,6,3,2,2,2,6,...}` 的 Battle Hunger 落在第 1/8/9/**10** 项,
    两者第 4 点都在行[10] = 11 级。`hero_zuus.lua` 本轮**只有注释改动**。GH #134 已销账。

22. ~~**WK 造不出魔棒(GH #136,2026-08-23 owner 开)**~~ **2026-08-23T08:00Z done
    并已落地(纯构筑、无 gate ⇒ 稳定版漂移)**:`skeleton_king` pos_3 的
    `item_branches` → `item_double_branches`(pos_2/4/5 别名一起吃到),
    `life_stealer` pos_1 同款一并修。详见「当前状态」头条。
    **别重查的三件事**:(a) 「队列不严格阻塞」是**错的** —— 采购层结构上补不齐,
    机制在 GH #139;(b) `grep item_branches` **会误报**(batrider 的两处在 sSellList、
    marci 写了连着两行 = 两根),口径是「展开合成宏后**恰好 1 根**才坏,0 根和 >=2 根都合法」;
    (c) 「魔棒要两根」在**离线验不了**(mock 的 `GetItemComponents` 恒空),锚是仓库自己的
    15 个带 `item_recipe_magic_wand` 的合成宏 **15/15 供两根**。
    **下一棒已交**:queue `hero-6`(条件 a:WK 是否曾同时持有两根树枝,0/40 → ~40/40)、
    GH #139(通用侧根因给总监)、GH #136 **留言不关闭**。

23. ~~**GH #139 的非树枝普查**~~ **2026-08-23T09:50Z done 并已落地(纯构筑、无 gate ⇒
    稳定版漂移)**:七族全扫,又抓到**魂之戒(2× `item_gauntlets`)**两处 ——
    `hero_tidehunter.lua` pos_1/2/3(`item_gauntlets` → `item_double_gauntlets`)与
    `hero_abyssal_underlord.lua` pos_4(**Bracer 之后、魂之戒之前**插第三个 gauntlets)。
    详见「当前状态」头条。**别重查的四件事**:
    (a) §23 原文的「前置」是**假的** —— 配方不必等 mock 供数,odota `dotaconstants`
    (build/items.json,package **10.8.0**)122 个带 components 的物品里**恰好七个**要两件同款,
    且在仓库里对上了两次(魔棒 15/15 老锚;**魂之戒有更锋利的仓内证人**:
    `item_broken_soul_ring` 故意不带护腕,而它唯一的消费者 `item_dragon_knight_outfit`
    在它旁边摆了两个独立 `item_gauntlets`);
    (b) 其余五族(bfury/desolator/moon_shard/skadi/necronomicon)**分母上就没人散买组件**
    —— 全是整件买或无人买,零 offender 是**结构性的**,不是没找到;
    (c) **整单求和的普查两个方向都错**,见「当前状态」;
    (d) 条件 (a) 对这两个英雄**可能永远买不到**(都不在 `run_001140` 镜像阵容),
    已提 queue **`hero-7`** 并预登记「载体不在场的 SILENT 不是阴性结果」。

24. **把「判据/报告双合成自测」推给其它扫描类测试**(2026-08-23 立,从 §23 分出)——
    一个「扫全仓 + 断言为空」的测试,**修完之后它自己的阳性路径就死了**:树上再没有
    offender,判据分支和报告分支在真实数据上永远走不到,于是放宽判据/停止报告的变异**全绿逃逸**
    (本轮前两版各逃一个:M13 放宽 `is_partial`、M14 只对「恰好 1」停报)。
    修法是**把判据和报告各抽一个函数、各喂一个合成输入**
    (见 `tests/test_dup_component_buylist_census.lua` 的
    `is_partial` / `offences_in` 两个自测)。**仍然测不到的那一块也要照写**:普查
    **调用点**上的变异(把结果丢掉)在一个没有东西可报的世界里不可证伪,抽函数救不回来。
    **候选受众**:~~`test_wk_magic_wand_branches.lua` 的普查(同族、同缺口)、
    `test_gate_claim_consistency.lua`~~ **两个都在 2026-08-23T16:00Z 做完**(各抽
    判据/报告一对函数 + 合成 offender + 近失;**先在 `git show HEAD:` 的旧版上把洞演示出来**:
    「判据和报告一起死」的变异**两个文件改动前都逃逸**,改动后 6 变异 6 抓 + 1 个 no-op 对照
    如期逃逸)、**以及总监那边所有「世界断言」型的扫描(仍未做,不归本组)**。
    - **⭐ 对本条措辞的更正**:§24 记的两个逃逸(放宽 `is_partial` / 停报)读起来像两个方向都盲,
      **在这两个受众上只有「沉默」方向盲**。放宽方向自带反例:树上留着**合法但相邻**的形状
      (6 条供 0 根树枝的合法买单、一批带 PROMOTED 的注释行),判据一放宽它们立刻变 offender。
      ⇒ **抽函数之前先问「树上有没有合法但相邻的形状会被放宽的判据吃进来」** —— 有,
      则合成输入的价值全在沉默方向;没有(`test_dup_component_buylist_census.lua` 就是),
      两个方向都得喂。**同一族测试,两种盲区剖面。**
    (原 §23 正文保留在下面,供接手的人对照方法。)

    (原 §23)—— #139 的触发条件是
    「配方要 2 件同款、买单先给了 1 件」,本轮只普查了**树枝**这一种(367 条买单,
    br==1 从 2 → 0)。**gauntlets / circlet / slippers / null_talisman 等同款重复组件
    一件都没扫过。** 做法可直接复用 `tests/test_wk_magic_wand_branches.lua` 里的
    `flatten` + `buy_lists` + `strip_comments`(注意:解析器**必须先剥注释**,
    否则会把理由块里带引号的物品名数成采购 —— 本轮真踩过)。
    **前置**:得先知道哪些配方含同款重复组件,而离线拿不到配方(见 §22(c))⇒
    要么等 mock 喂真配方(GH #100/#128 同族),要么从 `aba_item.lua` 的合成宏反推。
    - **2026-08-23T13:50Z 第一次被别的测试用上,而且当场抓到东西**:
      `tests/test_axe_cull_immune_veto.lua` 的语料普查按本条拆出 `scan_frames(frames, IMMUNE)`
      这个缝,喂一个合成 offender + 三个近失 + 两个「载体放不出技能」。**M12(只计数、
      不报告)与 M11/M13/M14/M15 全靠这几条合成输入才被抓住** —— 在干净的树上,
      报告那一半没有任何真实数据能驱动。本条继续开着(受众清单未做完)。

25. **`X.ConsiderR`(Axe 斩杀)里剩下的两根杠杆**(2026-08-23T13:50Z 立,第三根已做完见「当前状态」头条)。
    - **第一根 = `nKillDamage = 150 + 100*lv` 陈旧常数**(GH #115 §5,queue `hero-2`,
      处置 `NARROW-BAND-UNMEASURABLE`)。**不动**,等事件侧读数。
    - ~~**第二根 = 「有效环是 375 不是 175」**(原 §18b 登记为「第二根杠杆,单独登记、没动」)~~
      **2026-08-23T13:50Z 降级:事实成立,但「这是 bug」那半句没有依据。**
      `grep -rn "nInBonusEnemyList" bots/`:**这是全仓通行的习语** —— juggernaut / lich /
      slark / lina / legion_commander / tidehunter 等都用「`cast_range + 200` 的列表」开火,
      让引擎自己走进射程再放。单独把 Axe 这一处当缺陷改 = **逆着全仓约定改一个英雄**。
      ⇒ 除非有帧证据说明走这 200u 有代价,否则不动。**死局部 `nInRangeEnemyList` 也不要删**:
      `test_axe_culling_threshold_preflight.lua` §3 断言它在 `X.ConsiderR` 里**恰好出现 1 次**。

26. **Zeus / CM 的 `sAbilityList[4]`/`[5]` 绑定没有 nil 守卫**(2026-08-23T22:20Z 立,GH #151)。
    焦点五里只有这两个文件按下标 ≥4 绑技能(CM 的 `CrystalClone`、Zeus 的 `abilityD`/`abilityAS`),
    而 index 4 正是「innate 没被 `GetAbilityList` 丢掉」时它会落到的位置;丢不丢取决于
    `ability:IsHidden()`,**离线不可求值**。两处拿到句柄后**第一件事就是无守卫的方法调用**
    (`CrystalClone:IsTrained()` / `abilityAS:IsTrained()`),对照组是 WK 自己的 `abilityW`
    —— 它有 `if not abilityW or abilityW:IsHidden()` **加**一条 `GetName() ~=` 名字校验。
    **本轮只登记不改**:加守卫是行为改动(崩溃→不崩溃),而且 `print()` 到不了控制台、
    引擎错误处理坏掉 ⇒ 真发生了也是静默的,**先要域**。
    **下一棒 = queue `hero-12`**(归档扫描,零 EC2;口径已事先登记:>0 ⇒ 立刻写守卫,
    0 ⇒ DOMAIN-NOT-REACHED 而非不可能,且必须带 `zuus_lightning_hands` 那个对照分母)。
    - **⭐ 而在 fixture 世界里这条已经不是假设了(量出来的,见「当前状态」头条 §3.5)**:
      index 4 上真的坐着东西 —— WK/Lion 是各自的 innate,**CM/Zeus 是一行天赋**
      (`special_bonus_h_p200`;mock 的 `IsTalent()` 恒 false + dumper 把天赋行放进技能数组)。
      ⇒ **任何驱动 `X.ConsiderCrystalClone` 的 fixture 测试碰的都不是出货那个句柄。**
      归 harness(GH #151 §3),本组不改 mock。**顺带一条**:mock 的 `GetAbilityByName(nil)`
      **返回 table 不返回 nil** ⇒「nil 句柄会崩」在 fixture 里构造性不可复现,
      **绿色的 fixture 跑不能读成「守卫不必要」的证据**。
    - **顺带定死的一条 LIMIT,别再重推**:**不许从 fixture 语料推 index map**。
      `GetAbilityList` 只在 `IsUltimate() and slot >= 4` 时才给 index 6,而 Axe/CM 的语料数组
      恰好 4 条、大招在末位 ⇒ 若数组顺序 = slot 顺序,他俩的 `sAbilityList[6]` 就是 nil、
      `abilityR` 整条死。语料直接证伪:两人都有**大招正在冷却**的帧(Axe **1/26**、CM **10/50**)。
      ⇒ dump 顺序 ≠ slot 顺序。(Axe 那条腿 n=1,引用必须带;Lion/WK 是 5 条、大招在末位
      ⇒ 与 slot 顺序**自洽**,别拿他俩去「确认」slot 顺序。)
    - **⚠️ 归属**:那条 LIMIT **不是本组本轮发现的** —— `tools/agent/gen_ability_meta.py` 的 docstring
      (GH #36)早就写了「dump index 不是引擎 slot」。本轮加的只是**证明方式**(从语料内部量,
      而不是从「知道 dumper 怎么写」断言)。**下次宣布「我发现了一个 LIMIT」之前先 `grep -rn` 一遍
      `tools/` 的 docstring。**
    - **方法上的一条(比上面低一层、桌面可查)**:**从 datafeed 抄来的技能名不能拿去匹配引擎技能**。
      引擎给 innate 加了一个 datafeed 不携带的 `_innate_` 中缀(WK 31/31、Lion 22/22,feed 拼法 0/N),
      而另外三个焦点英雄的 innate **压根不在引擎数组里**。GH #104 立的「拿 datafeed 重锚」**对数值仍然有效,
      对名字无效**。
    - **⚠️ 一次自己的量测事故,如实记**:第一版普查用 `abilities = \{(.*?)\} \}` 惰性捕获,
      它**吞掉最后一条技能的右花括号**,而最后一条恰好是大招 ⇒ 读出来是「Axe 从来没有大招在冷却」
      (真值 1/26),只有尾部恰好挂了天赋行的帧才看得见大招。**按条目逐个匹配,别整块惰性捕获**;
      凡「某某从来没有过」先问一句是不是解析吃掉了它。

## 当前状态(每次触发后更新)
- 2026-09-06T14:20Z(报告 `iterations/reports/hero/20260906T142000Z.md`;轴 **Zeus 的
  `X.ConsiderR` 团战分支要求 1400 内可施法敌人数 `>= 5`,而 5 不是这个计数值域里的
  一个阈值,它就是这个值域的上界:收进 gated `zusfightquorum`,turbo-only 未 armed**;
  新 backlog `-107`,`state.json:zusfightquorum_20260906`,`queue.json:hero-38`,GH **#567**)
  **`bots/BotLib/hero_zuus.lua` 有真代码行**(新 `X.zuus_ShouldUltForTeamFight`
  + 三个新常数 `X.nUltFightRadius`/`X.nUltFightQuorumShipped`/`X.nUltFightQuorumArmed`
  + **一处**调用点,半径改成共用常数);新 `tests/test_zuus_fight_quorum.lua`(**16 例**)
  + 新 `tests/_zusfightquorum_sweep.lua` + 新 `tools/agent/mutstand_zusfightquorum.sh`
  (11 变异 **11/11 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;做的正是上一轮(`zusultstrand`,GH #564)
    **登记不认领**的那个候选 ——「本轮没有核实它是不是恒假……下一轮 Zeus 的第一个
    候选就是它」。**本轮核实了**,结论比「恒假」精确一格。
    **axis 换第七条**:「**一个阈值被设在它所阈值的那个量的上界上**」。
  - **⚠️ 措辞比上一轮弱一格,故意的**:这一条**不是恒假**(五个人挤进一个 1400 圈
    是可能的),所以写成一次**测量** —— **1012 个真实帧视角**
    (109 fixture × 每个活着的英雄),`0:542 1:251 2:203 3:11 4:5`,**最大 4**,
    `>=5` 命中 **0**,`>=3` 命中 **16 = 1.6%**;一方人数上界 **5** 由**语料自己报**。
  - **⭐ 前提可以失败**:出现五连站 §2 当场变红。窄度 1.6% 是这个 widening 与空头
    支票之间唯一站着的东西(**M8** armed→1 ⇒ **46.4%**);**M6** 半径→16000
    只有扫描看得见,因为扫描**从源码读半径**不重打。
    **⭐⭐ 缺陷的另一半是「从哪儿量」**(全球大招却从施法者脚下量团战):
    `f_260819_222052_zuus_w2_leak` 里 Zeus 的两个敌人**各自数到 4**、同帧 Zeus
    **只数到 2** —— §6 钉成断言,但**换计数中心是第二个杠杆、要自己的 id**。
    **⭐⭐⭐** 「够不到的阈值」与「没被读的阈值」外观相同 ⇒ §4 的**贴标签几何注入**
    是唯一能看见 **M7** 的断言。
  - **⚠️ 方向是 WIDENING**:armed 只降法定人数,负读数**绝不能**读作「少放了 N 次大招」。
  - **⚠️ 覆盖边界**:1012 个视角**绝大多数不是 Zeus**(非主体视角**不是创造帧**);
    **十个 Zeus 主体帧最多只数到 2**,连 armed 的 3 都没到 ⇒「armed 会触发」
    本轮没有人说;**`J.IsInTeamFight` 不在测试范围内**(读友军 bot 模式,语料没这列)。
  - 验证:新文件 **16/16**;`run_tests.lua zuus` **207 例 0 失败**;变异台 **11/11**;
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings)**,没用 BYPASS;smoke 3/3;
    gate_claim 16/16。⚠️ **全量套件本轮没跑完**(~100min,GH #124)。
    开工自检 **exit 3**(`FINDINGS: cadence owed-executions`;python 腿 UNCERTIFIABLE
    = GH #548,不认领);⚠️ 第一次调用又被脚本自己 **REFUSED**(stdout 是管道,
    证据纪律 3,本仓第 **11** 次复发,**又是当轮第一条命令**)。容器起手没有
    `luacheck`,由 `luacheck_gate.sh` 自己装上再跑;变异台与自检**没有**时间重叠。
  - **⚠️ 掉棒风险,已交到下一轮第一位**:**GH #566**(录像组 13:09Z 交付,
    `liondrainbkb` 前提在真实帧上被证伪,8 次引导整条嵌在 BKB 窗口内、一次逐帧
    看到目标蓝 −87/Lion 蓝 +157)**本轮没有认领** —— 它是一个完整工作单元体量的
    判定完结。写进 backlog **`-108`(最上面一条)**,并在 #566 上回了确认收棒的评论。
    **不要**把本轮报告读成对 #566 的答复。
  - 下一棒:**批测台** `queue.json:hero-38`(零 EC2,与 `hero-2`/`hero-30`…`hero-37`
    合并遍历,**十条同形**);**总监** P4.2 冻结期内合法裁定 **FROZEN-HOLD**,
    另 GH #566 请求的 `PREMISE-FALSIFIED` 标签待裁。
- 2026-09-06T11:20Z(报告 `iterations/reports/hero/20260906T112000Z.md`;轴 **Zeus 的
  `X.ConsiderR` 撤退分支被 `bot:GetRespawnTime() > abilityR:GetCooldown()` 守着,而右端是
  常数 130、左端至多 75 ⇒ 该合取项恒假,「快死了先把大招兑现」这条路从来没跑过:
  收进 gated `zusultstrand`,turbo-only 未 armed**;新 backlog `-106`,
  `state.json:zusultstrand_20260906`,`queue.json:hero-37`,GH **#564**)
  **`bots/BotLib/hero_zuus.lua` 有真代码行**(新 `X.zuus_ShouldCashUltBeforeDeath`
  + 新常数 `X.nUltCashChaseRadius` + **一处**调用点);新 `tests/test_zuus_ult_strand.lua`
  (**14 例**)+ 新 `tools/agent/mutstand_zusultstrand.sh`(9 变异 **9/9 CAUGHT**)。
  **零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#563/#562 是本组上一轮交出去的读数请求;#560/#554/#549/#541/#537/#533/#525 是本组
    前七轮落的、球在批测台或总监)。焦点五轮换:上一轮 CM ⇒ 本轮 Zeus。
    **axis 换第六条**:「守卫式合取项的两端各自被一个上界钉死,而两个上界的大小关系
    让它恒假」—— 最便宜,因为两端的上界**本仓都已经钉过**(KV 快照的 `AbilityCooldown`
    + `jmz_func.lua` GH #215 的 `100 * 0.75 = 75 seconds`)。
  - **事实**:右端 130 无等级阶梯,左端 turbo 上限 75 ⇒ **每一个等级上恒假**。
    连带:同文件 `[ultcash]` 的立案句是**在「撤退分支管用」的前提下**写的,前提不成立。
  - **⭐ 读法无关** —— `GetRespawnTime` 对活体返回什么本台 settle 不了,而**两种读法都假**
    (`0 > 130` / `75 > 130`)。**⭐⭐** 「恒假」与「比较不看输入」外观相同 ⇒ §4 的
    **贴标签注入**(131 必须翻真)是唯一能看见 **M7** 的断言。
    **⭐⭐⭐** 前提**从来源读**、不重打 ⇒ **M5** 是九个里唯一能让「恒假」句变假的。
  - **⚠️ 方向是 WIDENING**:arming 只能**增加**这条分支上的大招施放,
    负读数**绝不能**读作「少放了 N 次大招」。
  - **⚠️ 覆盖边界**:买到右端(7/8 帧读出 130)与半径项(6/8 帧敌人在 1600 内);
    **左端的 0 是 loader 缺口不是帧数据**;**没有创造帧**,唯一一帧 HP<28% 同时
    落空另外两项(冷却 2.2s、最近敌人 2017u)。两条都钉成单向绊线。
  - 验证:新文件 **14/14**;`run_tests.lua zuus` **191 例 0 失败**;变异台 **9/9**;
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings)**,没用 BYPASS;smoke 3/3;
    gate_claim 16/16。⚠️ **全量套件本轮没跑完**(~100min,GH #124)。
    开工自检 **exit 3**(cadence + owed-executions;python 腿 UNCERTIFIABLE = GH #548,
    不认领);⚠️ 第一次调用被脚本自己 **REFUSED**(stdout 是管道,证据纪律 3,
    本仓第 **10** 次复发,又是当轮第一条命令);⚠️ **自检最后一条腿与变异台第一次运行
    时间重叠**(GH #507 撕裂窗口),那条腿的 0 failures **本轮不当证据**用。
    容器起手 `lua5.1` 与 `luacheck` **都没有**,两个都当场装上再跑。
  - 下一棒:**批测台** `queue.json:hero-37`(零 EC2,与 `hero-2`/`hero-30`…`hero-36`
    合并遍历,**九条同形**);**总监** P4.2 冻结期内合法裁定 **FROZEN-HOLD**。
- 2026-09-06T08:02Z(报告 `iterations/reports/hero/20260906T080213Z.md`;轴 **Crystal Maiden 的
  `X.cm_GetStrongestUnit` 远程兵早退出口 `return unit, 500` —— 一个硬编码的血量,而两个挑选器
  的其他每一个出口返回的都是单位自己的血量,且 `X.ConsiderW` 把它当血量用了五次:
  收进 gated `cmrangedhp`,turbo-only 未 armed**;新 backlog `-105`,
  `state.json:cmrangedhp_20260906`,`queue.json:hero-36`,GH **#560**)
  **`bots/BotLib/hero_crystal_maiden.lua` 有真代码行**(新 `X.cm_GetRangedCreepReportedHealth`
  + **一处**调用点);新 `tests/test_cm_ranged_creep_health.lua`(**16 例**)+ 新
  `tools/agent/mutstand_cmrangedhp.sh`(9 变异 **9/9 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#554/#549/#541/#537/#533/#525 是本组前六轮落的、球在批测台 / #465 已复核 /
    #115 已落地纯数值 / #512 本组 `-96` 明写预检不通过)。焦点五**走完一圈回到 CM**。
    本轮**四条 axis 先扫空**(cast_shape 焦点五唯一命中就是 `cmaurapassive`;
    item_name / facet / call_arity 零命中;**穿魔免权限审计对 Zeus/CM/WK 是空的**,
    Axe #525 与 Lion #549 已用掉那条镜像;**`sSellList` 是 `(新,旧)` 成对表**,
    焦点五全对,同族的 `SetQueuePtToINT` 第二参是开不开魂戒、只有 Zeus 买而 Zeus 传 true)
    ⇒ 换**第五条:同一函数的一个出口报告的量,和它其他出口报告的不是同一个量**。
    它最便宜 —— 矛盾在源码里,消费方在 30 行外,**不需要任何外部 KV 读数**。
  - **事实**:`return unit, 500` 是**这两个挑选器里唯一**不返回单位自身血量的出口;
    `X.ConsiderW` 用它做四个下界(460/410/390/360)和两处 `<= nCreepCap`。
    ⇒ **`cmcreepcap`(GH #541)那个缺陷的另一侧,而 cmcreepcap 结构上够不着** ——
    那根修上限,这里**被限的量本身是常数**。
  - **⭐ 500 同时朝两个方向撒谎**:对残血兵**撒高**(越过全部四个下界,窗口 `(2*ad, 460]`);
    对满血兵**撒低**(`500 <= nCreepCap` 每一级都成立 ⇒「打不打得死」在这个出口上从没跑过,
    窗口 `(nCreepCap, 1100]`)。
  - **⭐⭐ 本轮最值钱的:方向由构造保证 —— 而 certify 它的那个扫描是恒等式不是第二意见。**
    500 满足每一个消费项 ⇒ 逐点子集检查**对任何 armed 值都不可能失败**。
    载重的是**前提**「500 越过每一个下界和每一级上限」,而它**可证伪**(下界从源码读)。
    **M6**(`> 460` → `> 560`)是九个变异里**唯一能让窄化句变成假话的**。
    **⇒ 可复用:写完「by construction」再问一句「我用来 certify 它的断言能不能失败」——
    不能失败的,不是证据。**
  - **⭐⭐⭐ GH #549 的教训有了实物**:**M9** 让 armed 返回**常数 1** —— 严格子集、§3 会盖章;
    抓住它的是 §6 的**值断言**。
  - **⚠️ 覆盖边界**:改动的那一项**买不到真实创造帧**(全仓 fixture 无 creep 单位,
    `GetNearbyCreeps` 10/10 帧两队皆空,两条钉成单向绊线)。买得到的是 **`lies low` 窗口宽度**:
    真实 Frostbite handle 上 **3/10 帧**(caps 800/1000/1000)在 1100 门以下,宽 300/100/100;
    语料 rank 偏高(7/10 已 4 级)**对本改动不利** ⇒ **下界不是频率**。
    ⚠️ **`lies high` 窗口宽度不是真实帧读数**:`GetAttackDamage` 全帧读 0,因为
    **.dem 切片既不带攻击力也不带攻速**(`tests/mock/bot_api.lua:134`),§2b 明写**不许**
    读成「窗口最大」。
  - **登记不认领**:同一出口的 `return` 还中断搜索 ⇒ 返回列表序第一只而非最强的。
    那是**目标身份**改动,故意不做 —— 不动目标正是方向论证的前提。
  - 验证:新文件 **16/16**;`run_tests.lua cm` **258 例 0 失败**;变异台 **9/9**;
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings)**,没用 BYPASS;gate_claim 16/16;smoke 3/3。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒「全量绿」本轮没有人说。
    开工自检 **exit 3**(cadence + owed-executions;python 腿 UNCERTIFIABLE = GH #548 的
    120s 刀口,不认领);⚠️ 第一次调用被脚本自己 **REFUSED**(stdout 是管道,证据纪律 3,
    本仓第 **9** 次复发,又是当轮第一条命令)。容器起手 `lua5.1` 与 `luacheck` **都没有**,
    两个都当场装上再跑,**没有一条腿因为「容器里没有」被跳过**。
  - 下一棒:**批测台** `queue.json:hero-36`(零 EC2,可与 `hero-2`/`hero-30`/`hero-31`/
    `hero-32`/`hero-33`/`hero-34`/`hero-35` 合并遍历,**八条同形**)。
- 2026-09-06T04:57Z(报告 `iterations/reports/hero/20260906T045743Z.md`;轴 **Axe 的
  `X.ConsiderW` 八处「已经中了战意饥渴就别重放」的否决都测
  `modifier_axe_battle_hunger_self` —— 一个**目标永远挂不上**的名字(写错了边,而且过期了):
  收进 gated `axebhrecast`,turbo-only 未 armed**;新 backlog `-104`,
  `state.json:axebhrecast_20260906`,`queue.json:hero-35`,GH **#554**)
  **`bots/BotLib/hero_axe.lua` 有真代码行**(新 `X.axe_IsBattleHungerFresh` + **三处**调用点);
  新 `tests/test_axe_battle_hunger_recast.lua`(**20 例**)+ 新
  `tools/agent/mutstand_axebhrecast.sh`(8 变异 **8/8 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#549/#541/#537/#533 是本组前四轮落的、球在批测台 / #512 本组 `-96` 明写预检不通过 /
    #502→#516 harness / #488 录像组 / #465 已复核)。焦点五**走完一圈回到 Axe**。
    前三条线索这轮都用不了(PROVEN-ZERO 名单空;裸字面量 vs KV 快照 CM 用过;
    同函数自相矛盾 Lion 用过)⇒ 换**第四条:一个谓词命名的 modifier,语料里没有任何单位挂过**。
    它最便宜 —— **一次 corpus census 就能判死,不需要任何外部 KV 读数**。
    (顺带:本轮重跑 `ability_value_key_census.py`(exit 3,8 站点),**焦点五一个都不在里面**,
    再次确认第一条线对本组是空的。)
  - **事实,两条独立理由各自充分**:(i) 目标那侧的 debuff 叫 `modifier_axe_battle_hunger`
    (`mode_team_roam_generic.lua:1605` / `hero_largo.lua:316` 读的都是它),`_self` 是施法者那侧;
    (ii) 施法者那侧在本 patch 拼作 `..._self_movespeed`(全语料 **18** 次),裸 `_self`
    **0 次**,而 `HasModifier` 引擎与 mock **都是精确名查表**。⇒ **否决结构上恒为真**。
  - **⭐ 方向是构造保证的子集,但不是「更少的动作」**:`armed 放技能 ⇒ shipped 放技能`,
    但 armed 可以在同一帧发出**指向不同目标的**同一个技能 ⇒ **不许**把负读数读成「少放了 N 次」。
  - **⭐⭐ 本轮最值钱的:fixture 发现了设计里没有的排除项。** 第一版接了**击杀循环**
    (列表分支,子集论证覆盖得到、源码断言全绿);端到端驱动 `..._axe_blink_kill` 才看见
    `X.WillBattleHungerKill` 按**满 12s** 定价、而**重放正是恢复满 12s 的动作** ——
    199 血 WK 身上剩 6.5s(已在路上 130),只有满 240 收得掉;**armed 那版把人头扔了**。
    **⇒ 可复用:子集性和「值不值」也各是一件事,只有驱动到底看得见。**
  - **⭐⭐⭐ 魔晶前提钉成棘轮**:`should_stack` 是魔晶授予,带魔晶重放变成真第二层、
    支配性反号;两张出装表都买魔晶 ⇒ armed 在 `J.HasAghanimsShard` 为真时整条站下。
    **M7 就是这条:方向不变、子集断言全过,杠杆从「窄」变「错」。**
  - **⚠️ 覆盖边界**:**语料只能演成本侧** —— 驱动帧上已中招的 WK 是 800u 内**唯一**敌人,
    armed 是**放弃**不是**换人**;收益侧要 `hero-35` 去买。**两个标注过的翻转**(W 冷却 4.0→0、
    三种 mode 之一→true;**没有 fixture 帧报告 bot mode**)。3 个 debuff 实例是**下界不是频率**。
  - 验证:新文件 **20/20**;`run_tests.lua axe` **201 例 0 失败**;变异台 **8/8**;
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings)**,没用 BYPASS;gate_claim 16/16;smoke 3/3。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒「全量绿」本轮没有人说。
    开工自检 **exit 0**;⚠️ 第一次调用被脚本自己 **REFUSED**(stdout 是管道,证据纪律 3,
    本仓第 **8** 次复发,又是当轮第一条命令)。python 腿仍报 **GH #548** 的 120s 刀口,不认领。
  - **顺序坑**:`check_armed_wiring.py` **读 git ref 不读工作树**,commit 前跑必然 `UNWIRED`。
  - 下一棒:**批测台** `queue.json:hero-35`(零 EC2,可与 `hero-2`/`hero-30`/`hero-31`/
    `hero-32`/`hero-33`/`hero-34` 合并遍历,**七条同形**)。
- 2026-09-06T01:52Z(报告 `iterations/reports/hero/20260906T015205Z.md`;轴 **Lion 的
  `X.ConsiderE`「团战吸蓝」分支用 `J.CanCastOnMagicImmune`(给穿透技用的谓词)挑目标,
  而 `lion_mana_drain` 的 KV 是 `SpellImmunityType SPELL_IMMUNITY_ENEMIES_NO`:收进 gated
  `liondrainbkb`,turbo-only 未 armed**;新 backlog `-103`,`state.json:liondrainbkb_20260906`,
  `queue.json:hero-34`,GH **#549**)
  **`bots/BotLib/hero_lion.lua` 有真代码行**(新 `X.lion_IsDrainTargetCastable` +
  `X.ConsiderE` 一处调用点);新 `tests/test_lion_drain_immune_target.lua`(**21 例**)+
  新 `tools/agent/mutstand_liondrainbkb.sh`(8 变异 **8/8 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#541/#537/#533/#525 是本组前四轮落的、球在批测台 / #512 本组 `-96` 明写预检不通过 /
    #502→#516 harness / #488 录像组)。连续五轮 Axe/Axe/WK/Zeus/CM ⇒ **焦点五里只剩 Lion**。
    前两条线索这轮都用不了(PROVEN-ZERO 名单 `-102` 已宣告空;「裸字面量 vs KV 快照」CM 那轮刚用过),
    换**第三条:同一个函数内部对同一个能力的自相矛盾** —— 它更便宜,矛盾在源码里,
    **只需要一次外部读数判哪边对**。
  - **事实**:`X.ConsiderE` 三处选靶,补蓝圈与「打架抽蓝」用 `J.CanCastOnNonMagicImmune`,
    **只有「团战吸蓝」用 `J.CanCastOnMagicImmune`**;两者差正好 `¬IsMagicImmune` 一项
    (`jmz_func.lua:961` vs `:988`)。**Lion 四个主动全是 `SPELL_IMMUNITY_ENEMIES_NO`** ——
    这英雄没有穿透技,所以是**声称了游戏不给的权限**,不是选错 helper 的判断题。
  - **⭐ 代价是「白清一次动作队列」**:`X.ConsiderE` 是派发链第一臂,消费方先
    `Action_ClearActions( false )` 再排单再 `return`;而这一支只在 Q/W/R **全不可施**时才跑得到
    ⇒ 清掉的正是仅剩的那个动作,且 BKB 期间**每 tick 复发**。
  - **⭐⭐ 方向 NARROWING,由构造保证**:出货谓词先算并绑定、armed 只能 true→false、
    末句返回 `bShipped` ⇒ armed ⊊ shipped。与 `axecallbkb` **互为镜像**。
  - **⭐⭐⭐ 能验的那一半是分支本身,只要一个翻转**:`f_260820_182906_lion_drain_survived`
    t=606.5 是 8 帧里**唯一**前提已成立的一帧,翻 drain 剩余冷却 11.6→0 就真的开火
    (`ClearActions | UseAbilityOnEntity(drain -> luna)`)。**前四轮都要写「分支跑不到」的免责声明,这轮不用。**
  - **⚠️ 覆盖边界**:8 帧 40+ 敌方英雄实例**魔免数 0** ⇒ 改动的那一项靠标注过的 mutation
    (ON 时 3c 改指 crystal_maiden、3d 一条命令都不发)。那个 0 与「唯一一帧」都是**单向绊线**。
    `SpellImmunityType` **RECORDED 不是 verified**(仓内 KV 快照不带该字段,GH #516 同族),
    §KV 把缺席钉成断言。
  - **⚠️ 一条可复用的**:**子集性和正确性是两件事,各写一条断言** —— M6(否决取反)
    仍然是 shipped 的子集,子集断言看不见它,抓住它的是「没人魔免的帧上 arming 必须 no-op」。
  - **负结果登记**:`X.ConsiderR` 的 `475 + 125*nSkillLV` 与 KV `600 725 850` **逐位相同**,
    scepter 支也对 ⇒ **维护风险不是行为缺陷,后来的轮次别当轴。**
  - 验证:新文件 **21/21**;`run_tests.lua lion` **162 例 0 失败**;变异台 **8/8**;
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings),没用 BYPASS**;smoke 3/3;gate_claim 16/16。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒「全量绿」本轮没有人说。
    开工自检:**python 腿 UNCERTIFIABLE**(`test_selfcheck_lua_leg.py` 84 文件 / 120.1s 撞
    120s 预算 —— 就是 01:23Z 已立的 **GH #548**,先于本轮,不认领)。
    ⚠️ 自检第一次调用被脚本自己 **REFUSED**(stdout 是管道,证据纪律 3,本仓第 **7** 次复发);
    第二次调用被我自己的 `timeout 400` 截断(与 **GH #514** 同形),第三次不带 timeout 才跑完。
  - 下一棒:**批测台** `queue.json:hero-34`(零 EC2,可与 `hero-2`/`hero-30`/`hero-31`/
    `hero-32`/`hero-33` 合并遍历)。**与前五条不同,这条只缺一个变量**。
- 2026-09-05T23:14Z(报告 `iterations/reports/hero/20260905T231439Z.md`;轴 **Crystal Maiden
  冻兵打钱的血量上限 `<= 1200` 是 Frostbite 4 级那一档,被当成了每一级的上限:收进 gated
  `cmcreepcap`,turbo-only 未 armed**;新 backlog `-102`,`state.json:cmcreepcap_20260905`,
  `queue.json:hero-33`,GH **#541**)
  **`bots/BotLib/hero_crystal_maiden.lua` 有真代码行**(新 `X.cm_GetFrostbiteCreepCap` +
  `X.ConsiderW` 一处绑定、两处调用点);新 `tests/test_cm_frostbite_creep_cap.lua`(**17 例**)+
  新 `tools/agent/mutstand_cmcreepcap.sh`(8 变异 **8/8 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#537/#533/#525 是本组今天落的三根、球在批测台 / #512 本组 `-96` 明写预检不通过 /
    #502 已转 harness→#516 / #488 录像组)。连续四轮 Axe/Axe/WK/Zeus ⇒ **换焦点英雄**。
    选法不是翻源码碰运气:先把 PROVEN-ZERO 名单**走完**(结论见下,这条线空了),
    再转「裸字面量 vs 仓内 KV 快照」这条线。
  - **事实**:`damage_per_second 100 × creep_multiplier 4 × duration 1.5/2/2.5/3` =
    **600/800/1000/1200** ⇒ 出货的 `1200` **恰好是 4 级那一档**。缺陷是**定义域**不是数值。
  - **⭐ 方向:第一根 NARROWING**(前三根都是超集)。armed ⊂ shipped,4 级取等 ⇒
    arming 只能减少释放;负读数不能读作「多冻了一只」。
  - **⭐⭐ 第一次把「方向论证的前提」而不是方向本身钉成棘轮**:t25 行必须仍取 `{10,0}`,
    另一半 +1.0s 持续会把上限抬到 1600、方向翻成放宽(GH #228 引擎折天赋进 base 读数)。
  - **⚠️ 一条可复用的教训**:变异台报「RED 但消息不对」时**先查断言顺序,再怀疑变异**。
    §3 单遍循环会在低级的严格性上先断掉,M4(被禁方向)因此打不出方向失败的消息;
    改成两遍扫描后 8/8。M6 同族。
  - **⚠️ 覆盖边界**:整块 fixture 驱动不了(`GetNearbyCreeps` 在 10/10 帧、两个队伍都空表,
    而同树 fixture 正文带 `npc_dota_creep_*` ⇒ **零是 loader 的不是语料的**;第二堵点是块自己的门
    只开 2/10 帧且那 2 帧无敌方小兵)。**改动的那一项是真实帧读数**:10/10 真句柄 + 活 KV,
    等级直方图 2→1/3→2/4→7,armed≠shipped **3/10**(`f_113638_cm_chain_rescue` 1200→800)。
    ⚠️ 3/10 是**下界不是频率**,定价走 `hero-33`。
  - **负结果登记**:PROVEN-ZERO 名单在焦点五里**已经空了** —— 3 个是已落地修复的出厂回落腿,
    2 个(`lion:822`/`lion:1009`)是没有消费者的死局部、零行为影响,且**不在**
    `test_dead_numeric_local_census.lua` 的域里(它只收数字字面量)。**后来的轮次别再取这条线。**
  - 验证:新文件 **17/17**;`run_tests.lua cm` **242 例 0 失败**;变异台 **8/8**;
    另**逐个点名跑了引用 `hero_crystal_maiden.lua` 的 52 个 lua 依赖者(0 红)+ 2 个 python 依赖者**;
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings),没用 BYPASS**;smoke 3/3;gate_claim 16/16。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒「全量绿」本轮没有人说。
    开工自检 **worst exit 3**(cadence / queue-rulings / owed-executions / trunk-red(python) /
    trunk-red(lua))。**Lua 那条红恰好是 21:33Z 已立的 GH #538**(`staybottle` 的 `== 109` 等值钉),
    先于本轮且本轮不新增任何 fixture ⇒ 不认领;**python 那五条本轮没有逐条做 stash 差分,如实登记**。
    ⚠️ 自检第一次调用被脚本自己 **REFUSED**(stdout 是管道,证据纪律 3,本仓第 6 次复发)。
  - 下一棒:**批测台** `queue.json:hero-33`(零 EC2,可与 `hero-2`/`hero-30`/`hero-31`/`hero-32` 合并遍历)。
- 2026-09-05T20:02Z(报告 `iterations/reports/hero/20260905T200244Z.md`;轴 **Zeus 的远程兵
  狙杀分支闭式为死:`X.ConsiderW` 的平伤读一个在引擎里恒零的字段,判据退化成与血量无关的
  `1 < m*b` ⇒ 从不开火。修好并收进 gated `zusboltdmg`,turbo-only 未 armed**;
  新 backlog `-101`,`state.json:zusboltdmg_20260905`,`queue.json:hero-32`,GH **#537**)
  **`bots/BotLib/hero_zuus.lua` 有真代码行**(新 `X.GetBoltRangedKillDamage` +
  `X.ConsiderW` 一处调用点);新 `tests/test_zuus_bolt_ranged_damage.lua`(**18 例**)+
  新 `tools/agent/mutstand_zusboltdmg.sh`(8 变异 **8/8 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#533/#525 是本组今天刚落的两根、球在批测台 / #512 本组 `-96` 明写不写 / #502→#516 harness /
    #488 录像组 / #465 上轮复核完毕)。连续三轮 Axe/Axe/WK ⇒ **换焦点英雄**。
    选法**不是翻源码碰运气**:读 `tools/agent/ability_damage_census.py` 的 **PROVEN-ZERO** 名单
    (焦点五 5 个站点),取**方向为「杀死分支」且已有真实帧反事实**的那一个。
  - **事实**:`GetAbilityDamage()` 只读顶层 `AbilityDamage` KV 字段,`zuus_lightning_bolt`
    不声明它(梯子在 `AbilityValues/damage` = `140 220 300 380`)⇒ 读数**在引擎里**恒 0;
    证明**无需句柄解析**(全树 128 英雄只有 16 个能力声明非零该字段,Zeus 一个都没有)。
  - **缺陷是「另一个谓词」不是「小了一点」**:`D=0` 时 `h < m*(D + h*b)` 退化成 **`1 < m*b`**,
    **与血量无关**;出厂 `b=0.09` ⇒ **闭式为死**,盈亏平衡要 `b>=1.0`(11.1×)。
  - **⭐ 算术与真实帧反事实都不是本轮的** —— 是本组 2026-08-30 的 `-50` 收尾
    (`test_zuus_static_field_second_consumer.lua` §3/§4c),那一轮明写 **"filed, not fixed"**。
    **本轮补的是修复本身 + 方向证明 + 把「arming 会动到别人的前提」编成代码。**
  - **⭐⭐ 超集性这次要经过一个函数 ⇒ 单调性必须自己被验**:(i) `max` 形状 ⇒ armed >= shipped;
    (ii) 判据对平伤单调不减(§3b 扫全格,用真的 mock `GetActualIncomingDamage`)。
    前两根靠整数蕴含**顺带**就有超集性,这一根不行 —— **第一次把单调性单独立成断言**。
    变异 **M4(`>` → `<`,一个字符)**把 max 变 min ⇒ armed 能答低于 shipped,静默删释放。
  - **⛔ 共臂禁令**:`zusboltdmg` 与 `zusstatic` **不许同波 armed**(前者 arming 会把
    `abilityASBonus` 第二消费方从空域变非空,而那是后者 (a) 只买一个消费方的前提)。
    钉在三处;棘轮还额外断言**本 id 的 gate 还在**。
  - **⚠️ 覆盖边界,两句不许合并**:`X.GetRanged` 需要小兵,而 fixtures **一帧都不带小兵**;
    第二堵点 `GetActiveMode` 恒 0(GH #474)。两条各写成断言(§5/§5b)。
    **改动的那一项是真实帧读数**(§2d:真实句柄 shipped=0 / armed=380)。
    ⚠️ 端到端那帧 `abilityASBonus` **实测 0**(隐藏内在,`.dem` 不带句柄)⇒
    `m=1.00→300 / 0.75→250 / 0.25→50` 是阈值的**下界**。
  - 验证:新文件 **18/18**;`run_tests.lua zuus` **177 例 0 失败**;变异台 **8/8**
    (M3 死接线孪生、M4 被禁方向、M7/M8 两个对量具自己的对照);
    另**逐个点名跑了引用 `hero_zuus.lua` 的 25 个 lua 依赖者 + 3 个 python 依赖者**;
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings),没用 BYPASS**。
  - 顺手:`test_incoming_damage_callsite_census.lua` grep 计数 `44→46`,承重计数(40/41)
    逐位不变 ⇒ **PURE PROSE**,三文件同步;**已 stash 差分确认是本轮引入,归本组修**。
    `test_detector_source_constants.py` 红 = **GH #490,先于本轮,不认领**。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒ 「全量绿」本轮没有人说。
    开工自检 **worst exit 3**(cadence / owed-executions / trunk-red(python) / trunk-red(lua)),
    **只对上面那一条做了 HEAD 差分并认领,其余四条没有逐条差分** —— 如实登记,不假装。
    ⚠️ 自检第一次调用被脚本自己 **REFUSED**(stdout 是管道,证据纪律 3,本仓第 5 次复发)。
  - 下一棒:**批测台** `queue.json:hero-32`(零 EC2,可与 `hero-2`/`hero-30`/`hero-31` 合并遍历)。
- 2026-09-05T17:0xZ(报告 `iterations/reports/hero/20260905T170150Z.md`;轴 **Wraith King 的
  Bone Guard 只在单挑里放:`X.ConsiderW` 的 `#nEnemysHerosInView == 1` 收进 gated
  `wkbonefight`,turbo-only 未 armed**;新 backlog `-100`,`state.json:wkbonefight_20260905`,
  `queue.json:hero-31`,GH **#533**)
  **`bots/BotLib/hero_skeleton_king.lua` 有真代码行**(新 `X.IsBoneGuardEnemyCountOk` +
  `X.ConsiderW` 一处调用点);新 `tests/test_wk_bone_guard_enemy_count.lua`(**15 例**)+
  新 `tools/agent/mutstand_wkbonefight.sh`(8 变异 **8/8 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#525 本组刚落已 FROZEN-HOLD / #512 录像检查组 / #502→#516 harness / #465 上轮复核完毕 /
    #115 §5 已由 `-98` 落地)。连续两轮都在 `hero_axe.lua` ⇒ **换焦点英雄**。
  - **事实**:Bone Guard 是 `NO_TARGET`、**定长 42s** cd、`70 80 90 100` 蓝、前摇 0.1、
    骷髅存活 **40s**、对英雄额外 **+25**(全部仓内 KV 快照)⇒ **代价一项都不是敌人数量的函数,
    收益随敌人数增大** ⇒ `== 1` 这个决斗判据把它从**每一场团战**里排除掉。
  - **⭐ 方向由构造保证**(`cullthresh` 教训跨英雄复用):`n==1 ⇒ n>=1`,armed 是 shipped 的
    严格超集,只能加不能减。变异 **M4(`>= 2`)读起来就是想做的事**却静默删掉单挑释放,
    抓住它的是**阶梯扫描 n=0..10**。
  - **⭐⭐ 能验的那一半这次正好是改动的那一项**:整条分支 fixture 驱动不了(GH #274 的
    charge modifier 0 帧 + GH #474 的 nil `GetProperTarget`,**都是本组早先自己的判词**),
    但数量项算得出来 —— 13 个 WK 主体帧直方图 **0→4 / 1→2 / 2→7**,出厂放行 **2/13**、
    armed **9/13**;按分支几何切(650 内有敌)**7 帧里出厂只放行 1 个**。
    ⇒ **「分支 = 源码级覆盖,改动的那一项 = 真实帧覆盖」两句不许合并。**
  - 验证:新文件 **15/15**;`run_tests.lua wk` **252 例 0 失败**;变异台 **8/8**
    (M3 死接线孪生、M4 被禁方向、**M7/M8 两个对量具自己的对照** —— M8 把 modifier 探针
    指向语料真的带的那个,实测 4 帧答 true ⇒ 「0/13」量的是语料不是 mock);
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings),没用 BYPASS**。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒ 「全量绿」本轮没有人说。
    开工自检 **worst exit 3**(cadence / owed-executions / trunk-red(python))。
    **⭐ 本轮补做了前两轮明写没做的 stash 差分**:四条 python 红在**干净 worktree(HEAD)上
    逐条复现**,输出与工作树**逐字节相同**(仅两处路径前缀与我这份新 stand 的 4 行 `ok/--`)
    ⇒ **全部先于本轮改动,`main` 也红**,不是本轮引入。
  - 下一棒:**批测台** `queue.json:hero-31`(零 EC2,可与 `hero-2`/`hero-30` 并成同一次遍历)。
- 2026-09-05T13:57Z(报告 `iterations/reports/hero/20260905T135708Z.md`;轴 **`axecull` 的兄弟落地:
  Berserker's Call 不被魔免挡住,gated `axecallbkb`,turbo-only 未 armed**;新 backlog `-99`,
  GH **#525**,`state.json:axecallbkb_20260905`,`queue.json:hero-30`)
  **`bots/BotLib/hero_axe.lua` 有真代码行**(新 `X.IsCallPierceOn` + `X.ConsiderQ` 两处子句);
  新 `tests/test_axe_call_immune_veto.lua`(18 例)+ 新 `tools/agent/mutstand_axecallbkb.sh`
  (8 变异 **8/8 CAUGHT**)。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#512 录像检查组 / #502→#516 harness / #488 录像组 / #477 总监 / #471+#459 总监+批测台),
    backlog 前三条的下一棒也都在别人手上 ⇒ 取同一文件里已有先例的兄弟杠杆。
  - **事实**:`axe_berserkers_call` `bkbpierce: "Yes"` / `behavior: No Target`(odota,
    与 `axecull` 同源),仓内 `special_value_shapes.lua` 交叉核对 radius 315 / cd `18 16 14 12` /
    mana `90 100 110 120` 逐位相同。⚠️ `bkbpierce` **没有 KV 字段**(GH #516 同族)⇒ 那一半仍 RECORDED。
  - **⭐ (ii) 不只是魔免错误**:无目标 AoE 嘲讽被挂在单个 `botTarget` 上,连带丢掉同环其他敌人。
  - **⭐⭐ 能验的那一半不是值钱的那一半**:7 帧上「Call 就绪」与「环内有敌人」**共现 0**
    (唯一环内帧 Call 在 18s cd 的 **17.0s** 上)⇒ (i) 用**三翻转 + 2×2 隔离**的反事实;
    (ii) 三条堵点**逐条量过**(nil `botTarget`/#474、`IsGoingOnSomeone` false、`IsDisabled` **true**)
    ⇒ **只有源码级覆盖**,三条各写成断言,**修好那天红**。
  - **⚠️ 两支共用一个 id ⇒ 负读数不可归因**,那时拆 id 不是否掉事实(写在三处)。
  - 验证:新文件 **18/18**;`run_tests.lua axe` **181 例 0 失败**;`smoke` 3/0;
    变异台 **8/8**(M4 死接线孪生、M6 被禁方向、M7/M8 两个对量具的对照);
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings),没用 BYPASS**。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒ 「全量绿」本轮没有人说。
    开工自检 **worst exit 3**,FINDINGS = cadence / owed-executions / trunk-red(python),
    **全部先于本轮改动**;**「main 是否也红」未做 stash 差分**。
  - 顺手:**GH #465 复核完毕**(措辞与算术都对,本组不动那个文件,issue 不关)。
  - 下一棒:**批测台** `queue.json:hero-30`(零 EC2,可与 `hero-2` 并成同一次遍历)。
- 2026-09-05T11:00Z(报告 `iterations/reports/hero/20260905T110023Z.md`;轴 **注册杠杆 `hero-2`
  落地:Axe 斩杀线改读能力值,gated `cullthresh`,turbo-only 未 armed**;新 backlog `-98`,
  `state.json:cullthresh_20260905`)
  **`bots/BotLib/hero_axe.lua` 有真代码行**(新 `X.IsCullThresholdOn` + `X.CullKillThreshold`,
  `X.ConsiderR` 调用点一行);新 `tests/test_axe_cull_threshold_gate.lua`(21 例)+ 新
  `tools/agent/mutstand_cullthresh.sh`(8 变异);三个兄弟棘轮重新对准;
  `queue.json:hero-2` 新增一节。**零 arm、零 promote、零 AWS。**
  - 选题:**OWNER_PRIORITIES P4.4**(bots/ 主体配额,今日新立)点的就是本组 ——
    最近四轮 `bots/` 全是零代码行;开着的 `[hero]` issue 逐条看过**没有一条球在本组**
    (#502→#516 harness、#512 球在录像检查组且 `-96` 明写在拿到帧前不开 Zeus 那根、
    #488 下一棒录像组、#477 球在总监)⇒ 取注册杠杆 `hero-2`。
  - **事实**:KV `275 375 475` vs 出厂 `150+100*lv` = 250/350/450,差 **25**;
    `kvgetters` 之后**第一次在真实帧上读到**(能力 275 / 公式 250,同一帧)。
  - **⭐ 第一版守卫 `nLive > 0` 是错的,而它错得看上去显然够用** —— 小的正读数会
    **收窄**斩杀线,这是唯一被禁的方向,**且静默**。改成**出厂值当地板**之后,
    方向由**代码**保证而不是由今天的数据保证。抓住它的是扫读数阶梯的方向用例。
  - **⭐⭐ 判词只过期一半**:「帧语料量不了 25 点带」**仍成立**(29/23/3/**0**,
    八月同口径 26/20/3/0);过期的是「到事件侧去量」那一半,而它死在**供给**上 ——
    `tl_260905_010226_axe_outchan.json`(seed 4763,subject=axe)证伪了
    「Axe 出现 0/306 局」。⇒ 从「量不到」变成「还没量」。
  - **⛔ 三条兄弟棘轮全部重新对准不是放松**;preflight 自己写的「删掉 §1 §2」
    **只执行一半**,因为那条指示假设的是**不带闸**落地。
  - 验证:新文件 **21/21**;`run_tests.lua axe` **163 例 0 失败**;邻接七组全绿;
    变异台 **8/8 CAUGHT**(**M4 = 第一版真写错的守卫**、**M8 = 对量具自己的对照**)。
    铁律 6 静态 **`GATE_EXIT=0 CLEAN`(0 warnings),没用 BYPASS**。
  - ⚠️ **全量套件本轮没跑完**(~100min,GH #124)⇒ 「全量绿」本轮没有人说。
    开工自检 `EXIT=0`,python 腿 4 条红**全部先于本轮改动**(#497/#490/无号/#501+#506),
    **「main 是否也红」未做 stash 差分**。
  - 下一棒:**批测台**归档**穿越**扫描(`queue.json:hero-2`);**总监**入集裁定
    建议排在读数之后(带内 0 的语料上 armed 读回 0 **归因不了**)。
- 2026-09-05T07:52Z(报告 `iterations/reports/hero/20260905T075200Z.md`;轴 **GH #502 的
  最后一格判了:`GetAOERadius` 在全树 KV 里没有对应字段 ⇒ 810 不许换掉 835**;新 GH **#516**)
  **新 `tools/agent/aoe_radius_source_census.py` + 新 `tests/test_aoe_radius_source_census.py`
  (6 例全绿);改两个 Lua 测试文件的注释与 assert 消息;`bots/` 与 `game/` **零行**;
  零新候选 id、零 arm、零 promote、零 AWS、`queue.json` 不加行。**
  - 选题:#512 求帧**零评论**(球在录像检查组,`-96` 明写「拿到那一帧前不要开 Zeus 那根」),
    #488 是非焦点 OD ⇒ 认领 **#502 本组自己欠的最后一格**。
  - **⭐ 名字恒等这条路不是没走通,是不存在**:**127** 个 shipped 英雄 KV 文件、
    **31** 个不同的顶层 `Ability*` 字段、含 "aoe"/"radius" 的 **0** 个。
    服务另外六个 getter 的规则**接不上**这一个 —— 它是 C++ 侧的量。
  - **⛔ 而冻结 snapshot 按构造答不了这一问,且「答不上来」长得像「没有」**:
    `parse_shapes` 只记 `TOP_LEVEL` 白名单里的顶层字段,不在名单里的**进 snapshot 前就被丢掉**。
    ⇒ 问题问的是**原始 KV 文本**;这条失明由新测试钉住,免得下一轮拿一次
    **只可能为空的 grep** 来「确认」结论(GH #494 同族)。
  - **⭐⭐ 决定性的是 7 个真调用点不是百分比**:只有 **1** 个(sniper)两条候选规则
    同意同一个键;CM 大招上名字规则挑 `radius`(810)而标志规则给**三个**
    (810/785/320)⇒ **挑 810 是一次选择不是一次读取**;drow W 与 muerta W
    **根本没有叫 `radius` 的键**。**两条规则必须分开报**,并集会让 drow 那格
    印成「一个干净候选 `wave_width`」——而那是**宽度**。
  - **裁定 = #502 的路 (b)**:`FIELD_RADIUS` 留 **835**,loader **不许**把
    `GetAOERadius` 接到 KV 上,那节**没有**松成容差。顺手改掉一句现在为假的话:
    原文说「`radius` 若移到 835 则缺口关闭」——**数值相等不等于同一个量**。
  - **下一棒交出去了(GH #516,[harness])**:dumper 每个 ability 句柄记
    `aoe_radius`(`rubick_utility.lua:185` 证明该调用在引擎里合法),一次给 7 个调用点定价。
    **球不在本组**;读数回来本组重推两个 end-to-end case 并关 #502。
  - **⚠️ 可迁移**:调用点正则锚在 `ability<X>` 命名习惯上时,7 个只找到 **6** 个
    (rubick 副本的句柄叫 `FreezingField`)—— 而 **6 是一个看上去很完整的数字**。
    **数调用点的正则不要锚在命名习惯上**,并让自检断言总数。
  - **⚠️ 诚实边界**:全量 Lua 套件本轮**没跑完**(~100min,GH #124),
    「全绿」这句话本轮**没有人说**;改动只在两个测试文件的注释/消息里,两文件单跑全绿。
- 2026-09-05T04:55Z(报告 `iterations/reports/hero/20260905T045549Z.md`;轴 **`-95` 点名的
  下一棒——类戊第一根 Lion Hex 储备——预检不通过,不写**;新 backlog `-96`,GH **#512**)
  **新 `tests/test_lion_hex_reserve_domain.lua`(6 例)+ `bots/BotLib/hero_lion.lua`
  绑定处注释(**零代码行**);零新候选 id、零 arm、零 promote、零 AWS、`queue.json` 不加行。**
  - 选题:OWNER_PRIORITIES 无本组项(P1/P2 在协同组、P3 在总监);开着的 `[hero]` issue
    逐条看过无一可动(#502 已交总监/#495;#488 下一棒是录像组;#471/#459 作用域在总监)
    ⇒ 取 backlog 最上面一条 `-95` **自己写明的**下一棒。
  - **⭐ 照 `lionult`(GH #73)先例先量域**:24 live-Lion → 22 已学 → 11 可付 →
    **1** 在 0.30 线下 → **0** 同时有敌人在 1600 内。0.39(`fKeepManaPercent`)线下 2 格,
    交集**同样为 0**;讲得出理由的窄版本(「别饿死跟手的 Impale」)**0/9,更空**。
  - **⛔ 关键读法:这个 0 是语料的不是杠杆的。** `ConsiderW` 在**全部 11 格**上
    `DESIRE_NONE`(含有敌人的 3 格),因为每个 fixture 帧 `GetProperTarget=nil` /
    `GetActiveMode=0` —— **GH #474 的第二个独立现场**。⇒ **被帧供给卡住,不是被证伪**;
    且 **#73 的 strike 不能搬**(那根占比→0,这根收敛到 0.30,任何等级都不消失)。
  - **下一棒交出去了(GH #512,求帧不求波次,球在录像检查组)**;
    类戊第二根(Zeus `ConsiderE`)**在拿到 Lion 那一帧之前不要开**。
  - **⚠️ 可迁移**:mock 把 `print` 换成空函数(`tests/mock/bot_api.lua:410`)⇒
    探针静默输出零字节且 exit 0。**一次性探针一律 `io.stderr:write`。**
- 2026-09-05T01:50Z(报告 `iterations/reports/hero/20260905T015048Z.md`;轴 **backlog `-75`
  兑现:九个死 `GetManaCost` 绑定分成五个类**;新 backlog `-95`)
  **新 `tests/test_dead_manacost_binding_census.lua`(8 节)+ 新
  `tools/agent/mutstand_dead_manacost.sh`(6 变异);`bots/` **两处注释共 18 行、零代码行**
  (`hero_lion.lua` X.ConsiderW、`hero_zuus.lua` X.ConsiderE);`game/` 零行;
  零新候选 id、零 arm、零 promote、零 AWS、`queue.json` 不加行。**
  - 选题:OWNER_PRIORITIES 无本组项;开着的 `[hero]` issue 逐条看过没有一条可动
    (#502 上一轮自己交给总监/#495;#488 下一棒是录像组的探针;#471/#463/#459 作用域在总监
    且 `-86` 要先买 `hero-28` 语料;#465 待关;#447 要录像组先建 dumper;#453/#451 是 tinker,
    `-82` 明写低于任何焦点英雄的活)⇒ 取 backlog 最上面一条可动的 `-75`。
  - **⭐ 结论:立案句预设了一个答案,现实给了五个。** 九个绑定**全部**坐在
    `IsFullyCastable()` 早退之下 ⇒ **付得起吗在上游就答完了**,这个绑定从来不是那次读;
    两个活惯用法问的是**储备**,所以「接线」= **给一个没有储备的决策加一道储备**。
    五个类:**甲**已有 `nKeepMana` 竞争储备(CM×2、Zeus W2)、**乙**储备被
    `IsLaneFixOn('mana')` 冻死且 armed 域是被拒两次的 `lanefix`(Zeus W)、
    **丙**大招(Zeus R、Axe R,储备指反)、**丁**回蓝技能(Lion E,符号相反)、
    **戊**什么都没有(Lion W、Zeus E)。**九个里只有两个方向一致。**
  - **域价钱**:全树 **189 个绑定 = 死 82 / 活 107**,焦点五 9 死;比 `-85` 的 46 还大。
  - **⛔ 不清零的理由**:`-85` 删的是**假前提**;这九个持有**真**价钱,删掉会抹掉
    「此处缺储备」的唯一标记 ⇒ 登记。棘轮 `<=` 不是 `==`。
  - 验证:新文件 **8/8**;变异台 **6/6 KILLED**(M1 = 把 `-75` 要做的事做出来必须红;
    **M5 = 打空树走查,供给量下限必须先红** —— 每条「必须不在」的断言都能被
    什么都没扫到的扫描器完美满足;**M6 白盒** = `absent` 那张表有没有在做功);
    邻接 9 个测试未改一行全绿。
  - 铁律 6:静态 **`GATE_EXIT=0 CLEAN`(0 warnings),没用 BYPASS**。
    ⚠️ **第一次 gate 自装 `lua-check` 失败,打的是 `GATE_EXIT=2 UNCERTIFIABLE`「不是通过」**,
    手动 `apt-get install -y lua-check` 后重跑才 0 —— **2 与 0 在报告里长得太像**,登记一格。
    **动态那半只有部分覆盖**(全量单进程收尾时仍在跑,GH #124)⇒ **本轮不声称全量绿**。
  - ⚠️ 开工自检 **EXIT=0**;python 腿 4 红(#497/#490/#501+#506/#443)**全非本轮引入**
    (零 `.py` 改动),**「main 是否也红」未做 stash 差分**。
    **⭐ Lua 腿那条红是本会话自己造的假红**:后台自检读到半份 `jmz_func.lua`
    (`:6986 near '<eof>'`,而该文件 12606 行、`git diff` 零行)——
    **变异台 `cp` 还原的撕裂窗口**(**GH #507**),与 GH #365 §2 同族但写者是变异台、被写的是 shipped 源码。
  - 下一棒:**本组自己**接类 戊 的**一根**(建议 Lion Hex,Lion 全文件无任何储备 ⇒
    是「加第一道」),gated + 真帧;**撕裂窗口那条已交总监/harness(GH #507)**。
- 2026-09-04T22:50Z(报告 `iterations/reports/hero/20260904T225049Z.md`;轴 **backlog `-76`
  兑现:四个文件的「理由句」逐句读**;新开 GH **#502**)
  **改 4 个测试文件(`test_replay_072738_zuus_script` / `test_axe_cull_immune_veto` /
  `test_cm_q_creep_aoe_reach` / `test_replay_260819_cm_r_range`)+ 新
  `tools/agent/mutstand_reason_read_76.sh`;`bots/` 与 `game/` 零行;零新候选 id、
  零 arm、零 promote、零 AWS、`queue.json` 不加行。**
  - 选题:OWNER_PRIORITIES 无本组项(P1/P2 在协同组、P3 在总监、常设运维在批测台);
    开着的 `[hero]` issue 逐条看过没有一条可动(#488 球在录像组;#471/#459/#463
    等总监裁作用域且 `-86` 明写先买 `hero-28` 语料;#465 待关;#447 的 fixture 在录像组;
    #453/#451 是 tinker,`-82` 明写低于任何焦点英雄的活)⇒ 取 backlog 最上面一条可动的 `-76`。
  - **⭐ 结论:立案句「这个数 dump 给不了」今天不是一个理由,是四个,互相不能推广。**
    09-01/09-04 的 `kvgetters` 让 loader 按 fixture KV 逐 rank 服务七个 getter(只对焦点五)
    ⇒ 手写常量从**代替哑 getter**变成**覆盖活 getter**,而**没有任何东西举手**。
    读数:`zuus_script` **四个手写数与 KV 全不符**(arc 850/80 vs rank2 **800/90**;
    bolt 825/125 vs rank1 **700/120**);`cm_q` 三个全符;`axe_cull` **五个数三个 rank 全符**;
    `cm_r_range` 三个锚**各因不同理由**仍承重(两个**非焦点被按设计拒绝**、一个是
    **`GetAOERadius` 不在被服务的七个 getter 里**)。**同 `-93` 的「残量不是队列」。**
  - **⭐⭐ 本轮最硬的一格:`zuus_script` 第二句立案句被阴性对照打掉。**
    它说沉默是「lf_mana 闸 + nKeepMana 储备」。实测 `SkillsComplement` 这一帧
    **queue 零个 action**(两个 `assert_no_harass` **一次都没比较过名字**,空域);
    **满蓝 + Q/W 冷却清零仍然是零**,五个 `Consider*` **全部 desire 0**;
    arc lightning 按 KV 价 `IsFullyCastable()==true`;`J.CanNotUseAbility` 为 false;
    量具 sanity 捕得到 ⇒ **法力可证不是这一帧的判别式**。空域登记成会响的断言。
  - **⛔ 唯一没判的交出去了(GH #502)**:CM `freezing_field` 的 KV `radius` 答 **810**,
    文件按 Liquipedia 跑 **835**。键→getter 映射未确立前**不许**拿 810 重推;两个数都钉住。
  - 验证:被改 4 个文件 **8/19/17/18 全绿**;**邻接 12 个 + 护栏 3 个全绿**;
    变异台 **9/9**(含 **M6 白盒**:摘掉 KV spec,交叉核验必须自称 **vacuous** 而不是通过
    —— `-93` 的 M14 教训在一次「值没动的落地」上的兑现)。
    **⭐ 变异台顺手修了 `-91` 那道锚守卫的一个失效开放形状**:`grep -F` 对多行锚
    按「匹配任一行」计数,**恰好出现一次的两行锚被报成 3 次**;改成 python 全文计数。
    **M3 曾 SURVIVED,而那是变异体写错(注入排在装钩子之前),不是断言睡着。**
  - 铁律 6:静态 `GATE_EXIT=0 CLEAN`(0 warnings,gate 自己装的 `lua-check`),**没用 BYPASS**;
    **动态那半只有部分覆盖**(单进程全量后台发起,收尾时仍在跑、没拿到 `FULL_EXIT`,
    **GH #124**)⇒ **本轮不声称全量绿**。
  - ⚠️ 开工自检 `EXIT=0`,worst finding 是 **`TRUNK RED (python)`** = 已知 **#490/#497**,
    **非本轮引入**(零 `.py` 改动);**「main 是否也红」本轮没做 stash 差分,未确立**。
    **第一次调用写成 `| tail -40`,自检打 `SELFCHECK_EXIT=2 REFUSED`「第 5 次复发,
    每次都是当轮第一条命令」——那不是通过;这是第 6 次。**
    **污染披露**:自检后台跑期间本轮编辑已在工作树上,它的 trunk 腿读的是 mod 树。
  - 下一棒:**本组这条线到此为止**(`-76` 清空)。#502 的裁定球在**总监 / GH #495 那条线**。
- 2026-09-04T19:50Z(报告 `iterations/reports/hero/20260904T195041Z.md`;轴 **backlog `-92`
  的「⭐ 下一撮」兑现:`kvgetters` 第三撮 —— 而结论是**残量不是队列**)
  **改 3 个文件(`tests/mock/replay_fixture.lua`、`tests/test_fixture_kv_getters.lua`、
  `tools/agent/mutstand_kvgetters.sh`),`bots/` 与 `game/` 零行;零新候选 id、零 arm、
  零 promote、零 AWS、`queue.json` 不加行。**
  - 选题:OWNER_PRIORITIES 无本组项;开着的 `[hero]` issue 逐条看过没有一条可动
    (#488 下一棒在录像组;**#471/#459 两条 issue 自己明写**「先买 `hero-28` 那格语料,
    回来之前不动 `bots/`」与「generic 那块作用域先请总监裁」;#463 在总监;#465 待关;
    #453/#451/#447 非焦点或只更正证据句)⇒ 取 backlog 最上面一条可动的 `-92`。
  - **人口(同一语料 110 文件 / 4811 句柄 / 779 焦点 KV 句柄):六个残余键共 575 句柄** ——
    `ModifierSupportValue` **308** / `ChannelTime` **80** / `Duration` **56** /
    `Charges` **51** / `ChargeRestoreTime` **51** / `Damage` **29**。
    (`-92` 立案写的 9/2/1/1/1/1 是**快照条目数**,上面是**语料句柄数**;两个都对,
    不是同一个量 —— 别并成一列。)
  - **⭐ 结论:六个里五个发不了,理由分三类互不相交**:(甲) **API 里没有 getter**
    (`ModifierSupportValue`+`ChargeRestoreTime`,359 句柄);(乙) **有 getter、
    焦点五零消费者**(`ChannelTime`/`Duration`/`Charges`,187 句柄;`GetCurrentCharges`
    14 处里 13 处是物品句柄,与 `hero_sniper.lua:244` 那句 item-only 一致);
    (丙) **两半齐全**(`AbilityDamage`,29)。
    ⇒ **「未上规格的键」不是一条待办队列**;按清零推进会接五个没人读的 reader。
    **而且 `-92` 让我问的「0 落在比较式哪一边」在这一撮上问不出来** —— 它预设了存在比较式。
  - **`AbilityDamage` 已发,读数一位不动**(声明该键的焦点技能只有 `axe_berserkers_call`
    = `0 0 0 0`;调用该 getter 的三处调在不声明该键的技能上,**交集为空**)。
    发它换的是**理由**:`lionqdmg`/`zusboltcap` 的立案句是「出货那次读是硬 0」,
    此前那个 0 来自 `bot_api.lua` 的通用 `^Get` —— **对的答案错的来源**。
    第二个独立见证:`tests/mock/ability_damage.lua` 的 `NONZERO`(全 128 英雄)**焦点五全不在**。
  - **✅ `zusboltdom` 处置(`-92` 的 ⛔)已写清**:本次**不会**让上限变非 0
    (`zuus_lightning_bolt` 真的没有该字段,引擎也答 0)⇒ **`zusboltdom` 未被触碰、不需重裁**;
    真正触发那条处置的是 GH #175 / `zusboltcap` 自己域内的 KV 修复。`§9c` 是那道门。
  - 验证:`test_fixture_kv_getters` **31 tests / 0 failures**;变异台 **18/18**(新增 M14–M18)。
    **⭐ M14 是本轮方法上最硬的一格**:值没动的落地,**必须自带一发「装没装」的白盒变异** ——
    它让每个读数原封不动,只有 §9b 的白盒断言抓得住;M17/M18 同族(先打死扫描器/遍历,
    看**供给量**断言会不会先红,否则负结论是免费的)。
    邻接 8 个测试未改一行全绿(确认 no-op)。
  - 铁律 6:静态 `GATE_EXIT=0 CLEAN`(`0 warnings`,gate 自己装的 `lua-check`),**没用 BYPASS**;
    **动态那半只有部分覆盖,报告 §7 写清楚了**:单进程全量发起后 ~3 小时未结束
    (进程一直活着、断言点长到 ~3018,**没拿到 `FULL_EXIT`**;**GH #124** 那件事),
    ⇒ **本轮不声称全量绿**。能作证的是被改文件 31/0 + 8 个邻接文件全绿 + 变异台 18/18。
    补齐走上一轮验证过的**逐文件**路线(单文件 300s,`test_itemdesire_world_assertion` 抬到 900s)。
  - ⚠️ 开工自检 worst exit **3**(`cadence`/`owed-executions`/**`trunk-red(python)`**)。
    python 那条 = **GH #490**(`test_detector_source_constants.py` 掉锚点),**非本轮引入**
    (零 `.py` 改动),**但「main 是否也红」未由自检确立**(没做 stash 差分)。
    **并且第一次调用写成 `| tail -40`,自检拒绝执行打 `SELFCHECK_EXIT=2 REFUSED`
    ——「第 5 次复发,每次都是当轮第一条命令」;那不是通过。**
    **污染披露(与上一轮同形)**:自检后台跑期间本轮改动已落在工作树上,
    末尾「fast Lua detectors 79 文件 0 失败」**是 mod 树读数,不能引用为 trunk 干净**。
  - 下一棒:**本组这条线到此为止**(第三撮之后没有第四撮)。要再推进这台仪器,
    球在**录像组**:dumper 出 per-unit health regen(**GH #493**)。
- 2026-09-04T17:02Z(报告 `iterations/reports/hero/20260904T170247Z.md`;轴 **backlog `-87`
  兑现:`kvgetters` 第二撮 `AbilityCastPoint` + `AbilityCooldown`**;登记
  `state.json:kvgetters2_20260904T`)
  **改 3 个文件(`tests/mock/replay_fixture.lua`、`tests/test_fixture_kv_getters.lua`、
  `tools/agent/mutstand_kvgetters.sh`),`bots/` 与 `game/` 零行;零新候选 id、零 arm、
  零 promote、零 AWS、`queue.json` 不加行。**
  - 选题:OWNER_PRIORITIES 无本组项(常设运维在批测台、P1/P2 在协同组、P3 在总监);
    开着的 `[hero]` issue 逐条看过没有一条可动(#488 下一棒明写在录像组;
    #471/#459/#463 都被 `-86`/`-84`/`-85` 记着「作用域先问总监」且 `-86` 明写
    先买 `hero-28` 那格读数;#465 已落地待关)⇒ 取 backlog 最上面一条可动的 `-87`。
  - **人口(同一语料 110 文件 / 4811 句柄 / 779 个有 KV 块的焦点句柄):
    `AbilityCastPoint` **575** 句柄、`AbilityCooldown` **723** 句柄,之前全部读 0。**
    (`-87` 立案写的 758 是估数,**实测 575**,以实测为准。)
  - **结论一:`GetCastPoint` 接上了但是死的,而这是动手前量的。** 它唯一的下游是
    `GetHealthRegen() * nDelay`,而 `GetHealthRegen` **自己也没上规格**(loader 里一次都没出现、
    dump 里没这个字段)⇒ **`0 × 任何东西`**。实测 **13 帧 / 58 对 / 0 次击杀判定翻转 /
    0 个 regen 非 0 的目标**。同 `-88` 的 `0 == 0` 形状:**下游有恒 0 因子的读数量的是合取**。
    **本快照关不掉**(health regen 是逐帧单位状态不是技能 KV)⇒ **要 dumper 出字段,球在录像组**;
    §7c 的断言**写成会响的**,regen 一旦非 0 直接红并在消息里给下一步。
  - **⭐ 结论二(本轮最硬的一格):同一个 0 把同一个文件里相邻两个守卫推向相反方向。**
    `GetCooldown()` 那个 0 **坐在 `remaining >= ultCD/2` 的两边**:
    `J.CanUseRefresherOrb` 的冷却项**整条蒸发**(194 帧里 **36 → 3**,**92% 是空条款**),
    `J.CanUseRefresherShard` 多要的 `ultCD - remaining >= 2` 变成 `remaining <= -2`
    **算术上不可能**(**0 → 6**;那个 0 不是「没帧命中」,**是那个表达式唯一可能的取值**)。
    `J.GetMostUltimateCDUnit` 则退化成「最后一个合格队友」。
    ⇒ **「未上规格的 getter 让守卫变宽松/变严格」这种顺口规则怎么写都有一半是错的**;
    第一撮的方向规则搬过来**会把符号读反**。
  - **⛔ 不许拿本轮读数去改 `bots/`** —— 三个退化守卫**全是仪器假象**,引擎里
    `GetCooldown()` 从不答 0;`hero_zuus.lua:1276` 故意没动。
  - 验证:变异台 **13/13 中**(新增 M9–M13,其中 **M12/M13 是对仪器的两发对照**,
    分别证明「0 次翻转」和「36→3」是**驱动出来的不是抄进断言的**;M13 还**复现了 36 的基线**);
    并把 `-91` 的「**锚点不唯一就 abort**」门**移植进这台 stand**(这里是活隐患:
    一个块里装八个 getter,`sp.GetCooldown = function(self)` 与 `sp.GetCooldownTimeRemaining`
    只差一个 token)。**别的 stand 仍然没有这道门。**
  - **mod-vs-base 全量差分:零差异。** 两棵树(base = 干净 HEAD `6ea528a8` 的 worktree)
    各逐文件跑完 **307** 个测试文件,**串行不并发**。唯一两条非零都在两棵树上复现:
    `test_towercreep_stale_domain` **失败正文逐字相同**(4 条、同行号、`got 1012`/`got 944`)
    ⇒ **基线自带,正是 `-87` 预告的那条**;`test_itemdesire_world_assertion` 的 **124 是
    本轮 runner 自己的 300s 上限不是失败**,抬到 900s **两棵树都绿**(mod 26/0,实测 497s)。
  - 铁律 6:静态 `GATE_EXIT=0 CLEAN`(`0 warnings`,gate 自己装的 luacheck),**没用 BYPASS**;
    动态那半就是上面那两遍全量。
  - ⚠️ 开工自检 worst exit **3**(`cadence` / `owed-executions` / **`trunk-red(python)`**),
    `UNCERTIFIABLE: none`。python 那条**不是本轮引入**(零 python 改动),**未做 stash 差分
    ⇒ 「main 是否也红」未由自检确立**。**并且必须披露一处污染**:自检跑了 ~35 分钟,
    期间本轮对 loader 的改动**已经落在工作树上**,所以它那条「fast Lua detectors 78 文件 0 失败」
    **是 mod 树读数不是 trunk 读数**,且分不清哪些在改动前后跑 ⇒ **不能引用为 trunk 干净**;
    trunk 侧的 Lua 读数在 mod-vs-base 差分的 base 那一半。
  - 下一棒:(1) **录像组** —— dumper 出 per-unit health regen(**GH #493**);
    (2) 本组第三小撮(`AbilityModifierSupportValue` 9 / `ChannelTime` 2 / `Duration` 1 /
    `Charges` 1 / `ChargeRestoreTime` 1),**但 `AbilityDamage` 那一个不许顺手发**
    (`-89 (乙)`:它会让 `zusboltdom` 自动 no-op,登记那天要一并写清处置)。
- 2026-09-04T13:51Z(报告 `iterations/reports/hero/20260904T135142Z.md`;轴 **GH #488,
  出厂谓词的源码侧核对**)
  **新增 2 个文件:`tests/test_od_eclipse_ring_conjunct_domain.lua`(12 用例 6 节)与
  `tools/agent/mutstand_odring.sh`(**6 变异 6 中**)。`bots/` 与 `game/` 零行、
  零新候选 id、零 arm、零 promote、零 AWS、`queue.json` 不加行。**
  - 选题:OWNER_PRIORITIES 无本组项;open `[hero]` 里 #471/#463/#453 是非焦点英雄的作用域题
    (球在总监)、#459 的下一棒明写「先买 `hero-28`」、#465/#447/#451 已落地待关;
    **#488 是当轮新立、验收点名英雄组、且卡着 `odaoe` 的条件 (a),还有 W45 录像 09-25 过期的时效**
    ⇒ 排在 backlog `-87` 前面。
  - **结论:#488 说的「两个合取项都假」,(R) 那一半不假。** `#nInRangeAlly >= #nTargetInRangeAlly`
    是 `>=` 不是多数决 —— 对**孤立**敌人两边同数 ⇒ TRUE,而且**恰在 OD 零队友时** TRUE。
    #488 只对互相贴着的 jugg/pudge 求了它。⇒ 那一帧**只剩一个承重合取项 (K)**。
  - **⭐ 而 (K) 的输入盒子本轮关上了**:数据表允许的**任何**
    `base_damage`/`damage_multiplier`/`GetCastRange` 取值都让它为假
    (最好情形裸伤 **903.2**,需要 **2477.3**,差 **2.74 倍**);
    **施法距离两个方向都帮不上忙** —— 放大只放进更肉的敌人。⇒ #488 前三个假设排除。
  - **下一棒是探针不是改动**:解释阈值 **677 点有效血量**;#488 自己列的「采样时已死」的
    **zuus** 对一个**在采样帧取世界状态**的重建结构性不可见,且满足它报告的每一个可观测量。
    **查 zuus 死亡时间戳 vs 1211.8。球在录像组。**#488 **不关**,已追评。
  - **⚠️ 本轮最该带走的一条**:第一版 12 用例**第一次跑就全绿,而它对自己那个运算符是瞎的** ——
    把 `>=` 变异成 `>` 依旧 10/10 全绿。两个独立原因:(i) **变异锚点不唯一**,
    `hero_obsidian_destroyer.lua` 里同一句队友环比较**出现三次**(`:242`/`:403`/`:558`),
    变异打在了**另一个技能**上并记成 `SURVIVED`(exit 0,长得像「文件看不见自己的主题」);
    (ii) **那一版确实没有任何一条用例让 (R) 去 refuse**,删掉整个合取项也一样不动。
    ⇒ `sub()` 现在**锚点不唯一就 abort**;补上 §2d/§2e 这一对(成对拓扑必须不放 / 还一个队友必须放)。
    **这是 `-89a` 那条教训的另一种形状:上次是驱动源被抄进断言,这次是被测的运算符从来没被问到过。**
  - ⚠️ 开工自检 worst exit **3**(`cadence` / `owed-executions` / **`trunk-red(python)`**)。
    那条 python 红**不是本轮引入**(本轮零 python 改动;#479/#482/#487 是那一族),
    **未做 stash 差分 ⇒ 按它自己的横幅,「main 是否也红」本轮未确立**。
    另有 2 项 `UNCERTIFIABLE`(5a0/5a 超 120s 没跑完)——**不是通过**。
  - **全量套件本轮没跑**(~100min)。只新增文件、`bots/`+`game/` 零行,爆炸半径=这两个新文件;
    跑了 `od_` 51/0、`smoke_load` 3/0、`gate_claim_consistency` 16/0、
    `incoming_damage_callsite_census` 6/0。**这是范围声明,不是「全量绿」。**
- 2026-09-04T10:46Z(报告 `iterations/reports/hero/20260904T104618Z.md`;轴 **backlog `-88 (甲)`
  兑现:两个 KV 读数的重取**;登记 `state.json:kvretake_20260904T`)
  **改 2 个测试文件,`bots/` 与 `game/` 零行;零新候选、零 arm、零 promote、零 AWS、
  `queue.json` 不加行。**
  - 选题:OWNER_PRIORITIES 无本组项(P1/P2 球在协同组、P3 在总监);**开着的 8 条
    `[hero]` issue 逐条看过,没有一条可动**(#451/#447/#465 已落地待关或已由别组落地;
    #459/#471 剩余站点球在总监且 `-86` 明写「先买 `hero-28` 那格读数」;#463/#453 是
    非焦点英雄的作用域题;#416 已随 `zusboltdom` 处理)⇒ 取 backlog 最上面一条**可动的**。
  - **缺陷是「一个断言不能证伪它自己的驱动源」**:两个文件的 armed 腿一直被
    **抄在测试里的那把梯子**驱动(Lion 的 `Q_KV = {105,170,235,300}`;Zeus 的
    `make_bolt(0,140)` / `make_bolt(0,380)`),然后又拿同一把梯子当真值。
    `kvgetters` 上周把「离线 getter 恒答 0」那堵墙拆了,**梯子没跟着换**。
  - **重取后一个数都没变**(Lion 8 帧 / 11 对 / 0 命中 / 最近差 **45** 血;Zeus 10 帧、
    9 个有级别的全部读到真梯子、四级里的三级)。**而「没变」本身是本轮唯一买不到的读数**:
    在 getter 答 0 的世界里,**没有任何东西能核对伪造得对不对**。
  - **⭐ 对照做在旧文件上,这是本轮最硬的一格**:把快照里的梯子挪一格,同一棵被污染的树上
    跑新旧两版 —— **Zeus 旧文件 `EXIT=0`,`11 tests, 0 failures`**(**整个文件对「KV 动了」
    完全瞎**),新文件点名报红;Lion 旧文件只红 1 条,而那条是 `:226` 上早就有的快照检查
    ⇒ **§4 自己的贡献是 0 → 2**。还原用文件副本,`cmp` 逐字节、快照 `git diff --stat` 空。
  - **`-88 (乙)` 从散文变成断言**:Zeus §2b 断言 `nNoAbilities == 1` 并点名
    `f_073148_zuus_lina`(`grep -c abilities` = **0**),两个方向都写进消息里
    (涨 = 又有 fixture 要重 dump;归零 = 录像组重 dump 落地了,**改指向不许删断言**)。
    球仍在录像组,但现在被一条会响的断言拿着。
  - **⚠️ 顺手量到一条 trunk 红并已立案(GH #484)**:`test_coarmed_attribution_register.lua`
    因今天 10:xxZ `campbind` 入集而红(`creepthink`/`pullcad`/`pullthink` × `campbind`
    三对同腿共 armed)。**做过差分**:`origin/main`(`b161d6af`)worktree 上失败正文
    **逐字节相同** ⇒ 基线自带。总监 10:xxZ 报告 §3 的「两条 trunk 红」数的是 **python 腿**,
    **这条是 Lua 腿的**,而且正是那一轮入集本身触发的(登记器按设计响)。球在总监。
  - **⚠️ 并发禁忌清单上少了一项,本轮踩到了(第三个 GH #229 现场)**:
    静态门**不能与全量并发**(GH #439 假红,而 GH #213 的 pre-push 钩子调的就是它);
    变异台**也不能**(上一轮 §6)。本轮这两条都遵守了,**却把开工自检与全量并发起了**
    —— `ps` 里同时两个 `lua5.1 tests/run_tests.lua`,因为
    **开工自检自己就跑一条「fast Lua detectors」腿**,两边共用同一个物理
    `soak_side.lua`,而分片脚本每格还 `rm -f` 它。
    **⇒ 清单要写成:全量套件跑的时候,别的什么都不许跑,开工自检也算。**
    失效方向**单向指向假红**(残留 ⇒ 守卫点名;被抢走开关 ⇒ 门读到未 armed),
    构造不出假绿 ⇒ **绿可信,红必须单独重跑才能引用**(本轮按这条处置了)。
- 2026-09-04T07:51Z(报告 `iterations/reports/hero/20260904T075131Z.md`;轴 **GH #477 选项 2,
  新 gated 候选 `zusboltdom`**)
  **改 4 个 + 新增 2 个:`bots/BotLib/hero_zuus.lua`(新 `X.BoltAoEKillTarget` + 击杀-AoE
  return 带出第三个值)、三个兄弟测试重新对准(`test_replay_260819_zuus_w2_leak` 的元数断言、
  `test_zuus_bolt_kill_cap` 的 `nDamage` 消费者计数、`test_zusult_pre_ladder_claim_retake`
  的 arming 集);新增 `tests/test_replay_260819_zuus_boltdom.lua`(15 用例 7 节)与
  `tools/agent/mutstand_zusboltdom.sh`(**7 变异 7 中**,含 1 对仪器的对照)。
  `state.json:zusboltdom_20260904T` 已登记;`queue.json` 新行 **`hero-29`**(买条件 (a),
  **不申请专波/专机/新增机时**);**零 arm、零 promote、零 AWS**。**
  - 选题:OWNER_PRIORITIES 无本组项(P1/P2 球在协同组、P3 在总监)⇒ 走 issue 流。
    GH #477 标题带 `[bug]`,但它的建议验收第 2 条**点名给英雄组 / 总监**,落点在
    `hero_zuus.lua`,焦点英雄 Zeus ⇒ 认领。
  - **`zusult` 没有失效,它是被绕过。** `X.ConsiderW2` 的击杀-AoE 分支按 GH #47 **故意不报目标**
    (击杀豁免,门在 nil 上恒 false)—— 而那条分支**不是击杀分支**:它交给 `FindAoELocation`
    的上限 = `GetAbilityDamage()`,而 `zuus_lightning_bolt` **没有顶层 `AbilityDamage` 字段**
    ⇒ **恒 0**,而引擎把 0 读成「**没有过滤器**」(`docs/BOT_API_REFERENCE.md` § `FindAoELocation`（今天 :1400，第一次被引时 :1288 —— **按标题找，行号会漂**）)。
    ⇒ 它问的是「射程内有没有敌方英雄」,并**把击杀豁免一起带走**。
  - **⛔ 依赖写成了值,不是 id**:helper **不读** `IsSoakCandidate('zusboltcap')` ——
    点名兄弟候选的门会在那个兄弟被 promote 的当天冻成 FALSE(`pullcad` 陷阱)。
    变异台 **M4** 就是那个 id 版本:**今天行为逐字相同,明天冻死**,只有源码级用例看得见。
  - **⭐ M7(把测试供给的英雄 AoE 读数弄瞎)交出了第二半证据**:回到 loader 的结构性
    `{count = 0}` 之后,这一帧的出价来自一条 **poke 分支**(它是报目标的)⇒ **`zusult`
    自己就已经扣住了它,一个技能都没放**。所以漏的**不是这一帧,是击杀-AoE 那条分支**。
  - **两条必须一起引用的限制**:(i) fixture **不是** #477 点名的 t=404.4
    (那一帧没 dump,重 dump 是录像组的球、卡在 GH #478 后面),用的是**同形**的 GH #47 帧;
    (ii) **英雄侧 AoE 读数是测试供给的** —— `replay_fixture.lua` 对一切 HERO 搜索
    结构性答 `{count = 0}`,本文件按它自己文件头的指示覆写,用**引擎写在文档里的
    `nMaxHealth` 规则**算**帧自己的**英雄/位置/血量(count 不是编的,是算的;与 loader 同向,
    而每格只问 `>= 1` 还是 `== 0`,在这个问题上下界精确)。**M7 是对这台仪器的对照。**
  - **⚠️ 踩到并清掉一个 GH #229 现场(可迁移)**:我误把变异台与全量套件并发起了 ——
    **变异台按定义会把工作树里的 `hero_zuus.lua` 换成变异体**。杀掉那次全量后,
    树上**留下一份上膛的 `bots/Customize/soak_side.lua`**(`cand = 'aimguard'`),
    于是下一次全量在 **12 个文件**上打红。**红的内容正是 09-02 那轮为这件事造的守卫**
    (装载时点名残留并打印内容,而不是产出像期望值写错的数值不匹配)。
    ⇒ (i) **变异台与全量套件永远不许并发**;(ii) **被中断的全量会留下上膛的开关**,
    下一轮第一件事看一眼那个路径。
  - **下一棒已经交出去**(铁律 9):`hero-29` 的 `acceptance` 里预登记了判读方向、
    两条退回门((甲) 没降 = BUGGY 退回;(丁) 必须与 `zusult` 同腿 armed 否则 UNINTERPRETABLE)
    与**反向刹车 (乙)**(Zeus 击杀数下降 ⇒ 即使域内计数归零也 REJECT ——
    本改动唯一可能的坏处就是扣住真击杀,而那是 GH #47 明令禁止的方向)。
    GH #477 **不关**(条件 (a) 未买),已追评说明落的是选项 2、与选项 1 的**不可归因性**
    (两者都会把域内计数打到 0,机制不同)。
- 2026-09-04T04:56Z(报告 `iterations/reports/hero/20260904T045632Z.md`;轴 **`kvgetters`,仪器修复**)
  **改 8 个 + 新增 2 个:`tests/mock/replay_fixture.lua`(`value_ladder`/`rank_step`/`has_kv`
  + `GetSpecialValueInt`/`Float`/`GetCastRange` 上规格)、`tests/test_cm_ult_reach_meter_domain.lua` §4、
  `tests/test_cm_t10_payoff.lua` §4、`tests/test_replay_260820_axe_blink_kill.lua` caveat 2 + 一条用例
  (三处都是**改指向不删断言**);新增 `tests/test_fixture_kv_getters.lua`(17 用例)与
  `tools/agent/mutstand_kvgetters.sh`(**8 变异 8 中**,含 1 正对照)。
  `state.json:kvgetters_20260904T` 已登记;**`bots/` + `game/` 零行、零新 gate id、
  零 arm/promote、零 AWS、不申请波次**;`queue.json` / `test_set.md` 本轮无新增。
  charter backlog 新增 `-87`,并就地更正 `-86` / `-84` 各一处前提。**
  - 选题:OWNER_PRIORITIES 无本组项;open `[hero]` 七条(#471/#463/#459 作用域在总监、
    #465 待裁、#453/#451 是 tinker 非焦点、#447 等录像组)+ backlog 顶上五条**全部在等别人**
    ⇒ 走工作流步骤 1 的兜底,入口选 Axe(`hero-2` 是本仓**登记最久的未取杠杆**,13 天)。
  - **⭐⭐ 去看那道墙,墙不在。** 「离线帧世界对每个 `GetSpecialValue` key 都答 0」——
    被 **三条**独立杠杆当成**结构性**的墙写进档案(GH #162 `lionsplash`、`zusaether`、
    `hero-2` 预检)——**从来不是结构性的**:`GetSpecialValueInt`/`Float`/`GetCastRange`
    只是停在 `mock/bot_api.lua` 的通用 `^Get` 默认值上,而喂它们的 KV **就躺在
    `tests/mock/special_value_shapes.lua` 里**(2026-09-01 那轮给 `GetManaCost` 接的同一份)。
    那一轮把结论写成了通用的(「一个没上规格的 getter 答 0 是**另一个谓词**」),
    **然后只上了一个 getter**。
  - **域价钱**(`tests/fixtures` + `tests/frames`):110 文件 / **4811 句柄**;
    焦点五 **872**,其中有 KV 块 **779**(缺的 93 = 内在 58 + **通用**天赋行 35,
    住在 `npc_abilities.txt`,**按构造在域外**);**402** 个句柄的 `GetCastRange` 答 0;
    **5306** 个 (句柄,key) 对的 `GetSpecialValue*` 答 0。
  - **⭐ 失效方向与上一次相反,所以更难看见**:卡住的 `GetManaCost` **高估**可达性(免费魔法);
    卡住的这两个让**半径更小、阈值更低** ⇒ **制造「这条分支到不了」的读数**,
    正是悄悄退掉杠杆的那个方向。现场:`X.ConsiderR` 走 `GetCastRange()+200`,
    Culling 射程 175 ⇒ 引擎 **375u**,而每一次 fixture 驱动的运行走 **200u**,短 47%。
  - **拒绝做的四件事各自写成断言**:条件项(`special_bonus_*`)**不折叠**(引擎已折,
    再折是双算;M5 钉这一格)、NO-BASE key 答 0、不存在的 key 答 0
    (后两条**就是引擎的答案**,**没有**顺手「修好」`lionsplash`)、非焦点英雄一律不动。
    `AbilityCastPoint`(758 句柄)/ `AbilityCooldown` **故意留到下一撮**(backlog `-87`)。
  - **打红七个文件十条,全是兄弟测试按设计举手,全部改指向/归档,一条没删**
    (其中**三个文件的失败文本里就写着这次修复落地时该怎么做**):
    (甲) `axe_blink_kill` —— `axe_berserkers_call/radius` 的 KV base **恰好 315 = 守卫的 fallback**
    ⇒ **数字逐字不变**,变的只是两条等价路径里哪条供的;断言改成钉**等式**。
    (乙) `cm_ult_reach_meter` §4 —— 250 条零出价变 **249**:`X.ConsiderQImpl` 前四行读
    `radius`/`nova_damage`/`GetCastRange`,三个全 0 ⇒ 它在 **32 单位圈**里搜一个
    **半径 0、伤害 0** 的 AoE,**在任何一帧都不可能返回东西** —— **那份沉默是仪器的**。
    活的那一条**按名字登记不按数字计数**(GH #465 的刀口):
    `f_260820_182906_lion_drain_survived.lua :: ConsiderQ = 0.75`。
    (丙) `cm_t10_payoff` §4 —— 决策通道从全哑变成**一帧活着**,而它的失败文本自己
    写着下一步(「re-run both worlds against it」)⇒ **就地做完**:三个世界
    (baseline / +200HP / +144MP)在那一帧**下同一个决策** ⇒ **t10 裁定不受影响**。
    (丁) `wk_q_castrange_meter_domain` §1/§5 —— **这个文件就是来要这次修复的**
    (「this file has been overtaken by the repair it asked for」)。零归档,
    新读数 **36 里 33 读到 KV 的 525**;剩下 **3** 是**结构性残余** ——
    三个 **v1 dump 整个 `abilities` 数组都没有**,只能重 dump(见 `-88`)。
    (戊) `wk_bone_guard_talent_bypass` §3/§3b/§4 —— **19 和 22 从来不是它们自称的那个量**:
    `max_skeleton_charges` 答 0 时 `nStack == maxStack` 是 **`0 == 0` 恒真**,
    分支 2 的弹药检查**白送**;真值 rank4 = **8** ⇒ 恒假 ⇒ 授予 modifier **不再移动任何一帧**。
    两个数**归档不重定基线**(§3b 整节改成档案 + 一条守档案的活检查),
    §4 按它自己预登记的方向重做:**天花板真了、当前层数没真** ⇒
    算术从**平凡为真**变成**平凡为假**,**没有变成可驱动**。
    (庚) `zuus_bolt_kill_cap` §4 与 (己) **同形同处置** —— 同一句 LIMIT 被抄了两遍,
    于是**同时**变假,而**没有任何东西在数它们有几份**。
    (己) `lion_q_kill_damage` §6 —— LIMIT 掉了一半(armed 腿读到真梯,shipped 腿走
    `GetAbilityDamage()` 仍 0)。**没有顺手重定基线它的 §4**(旧世界 + 伪造声明取的数),
    交给 `-88`;**活下来的那半照旧钉住:不存在的 key 仍读 0 ⇒ 缺席与零仍分不开,GH #162 没被修好**。
  - **`hero-2` 的障碍减半,没有清空**:用修好的仪器端到端重量(`tests/fixtures` 口径)
    28 帧带 Axe / **22 ready**(rank1×20, rank2×2)/ 环内敌方英雄帧 **200u→2、375u→3** /
    **带内 0**。那个 **3 与兄弟文件 `test_axe_culling_band_power.lua` 登记的 3 逐位相同**,
    而那个文件是**绕开 loader** 直接解析 KV 算的 ⇒ **仪器与一份没用它的手算对上了**。
    带内仍是 0(与预登记功率计算一致,期望 ~0.07)⇒ **修仪器没有凭空造出那一帧**,
    §5c 已预写判读方向:**哪天非零就是它等的帧,去切 fixture,不许放松断言**。
    退休的是**解释**,不是障碍:第一顺位障碍仍是**归档 306 局里 Axe 出现 0 局**
    (批测台 2026-08-23),GH #46 现成答案 `--find axe → 899/910/911`。**球仍在批测台。**
  - 门:开工自检第一条命令**又**被证据纪律 3 拒答(`REFUSED`,`SELFCHECK_EXIT=2`,**不是通过**);
    改对后 **worst exit 3**(`FINDINGS = cadence owed-executions trunk-red(lua)`;
    **`UNCERTIFIABLE = trunk-red(python)` ⇒ trunk 的 python 那一侧本轮没人看过**)。
    `trunk-red(lua)` 已定位 = `test_towercreep_stale_domain.lua`,**两棵树同红,不是本轮的**。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(冷启自装,**没用 `RULE6_BYPASS`**)。
    动态:新文件 **17/0**、`cm_ult_reach_meter` **8/0**、`cm_t10_payoff` **11/0**、
    `axe_blink_kill` **19/0**、`wk_q_castrange` **8/0**、`wk_bone_guard` **25/0**、
    `lion_q_kill_damage` **13/0**、`zuus_bolt_kill_cap` **11/0**、`smoke` **3/0**、变异台 **8/8**;
    **19 个首字母分片全部跑完并逐条 diff**(`a b c d f g h i l m n o p r s t u w z`),
    mod-only 差集 **10 条 / 7 个文件**,全部处置;**收尾在最终树上复跑了这 7 个文件
    所在的全部分片**:`c` 381/0、`f` 267/0、`l` 185/0、`r` 662/0、`w` 185/0、`z` 96/0
    = **1776 用例 0 失败,差集清空**。**⚠️ 这不是「单进程一次全绿」**:
    读数是分片并集 + 差分(GH #124),且**基线自己带一条红**。
  - **⚠️ 变异台 M7 存活并如实记下**:去掉 `has_kv` 守卫**不改变任何答案**
    (快照里没有非焦点英雄的块,`value_ladder` 照样返回 nil)⇒ §2c **看不见它**;
    改由 §6a 的**源码 tripwire** 抓 —— 一个**不改变任何读数**的东西,那是唯一诚实的抓法。
  - **交出去的棒**:无新开 issue / 无 queue 请求 / 未提议入 `test_set.md`(没有行为改动)。
    `queue.json:hero-2` 的 acceptance 里那句被反复引用的「离线世界答不了 `GetSpecialValue`」
    **已不成立**,已写进报告 §7 与本条,**下一位不要再拿它当不做 fixture 的理由**。

- 2026-09-04T01:58Z(报告 `iterations/reports/hero/20260904T015833Z.md`;轴 **新候选 `zusaether`**)
  **改 2 个 + 新增 2 个:`bots/BotLib/hero_zuus.lua`(三处施法距离消费者上闸 +
  生产者接进 `aetherlens` helper)、`tests/test_aether_lens_range_bonus.lua`
  (§6 改指向 + 棘轮 27→26)、新增 `tests/test_zeus_aether_cast_range.lua`(18 用例)
  与 `tools/agent/mutstand_zusaether.sh`(7 变异全杀)。
  `state.json:zusaether_20260904T`、`queue.json:hero-28` 已登记;
  零 arm/promote、零 AWS、不申请波次;`game/` 零行。**
  - 选题:OWNER_PRIORITIES 无本组项;open `[hero]` 九条逐条过了一遍(#465 待关、
    #463/#459 全量作用域在总监、#453/#451 待关、#417 待关、#447 等录像组、
    #407 剩下的半在 `hero-27`/批测台)⇒ 走 backlog `-84` 自己写的「一次一小撮」放行,
    它点名了最后那个焦点英雄站点 `hero_zuus.lua:596`。
  - **⭐⭐ 而那个站点不是登记时以为的那种站点。** `-84` 把它归类为「陈旧常数」
    (写 250、活 KV 225);真去看,**这个常数根本没人读**。`hero_zuus.lua` 是
    BotLib Aether Lens 模板的**半接线拷贝**:声明在、`SkillsComplement` 里的赋值在,
    **三个消费者全部丢了 `+ aetherRange`**。全树 **33 声明 / 26 接了 / 7 算了不读**,
    本轮之前 Zeus 是第 8 个、**也是其中唯一的焦点英雄**。域是**活的**:
    `pos_4`/`pos_5` 买表**都买** `item_aether_lens`(`zeusaghs5` 的论证就架在那次购买上)。
  - **⭐ 方向与 GH #459 相反,这才是它值一个闸的理由**:三处 `nCastRange` 都是
    **自己的搜索环**半径。高估的代价是**一次计划外的贴近**;**低估不下达任何移动**,
    而是让一个**确实在延长射程内**的敌人**对决策不可见**(带透镜时 `ConsiderQ` 的
    `<=0.2` 处决循环看不到 900–1150 的残血目标)。恢复这一项**只能加上一次已经花钱
    买下的施法**,不能造出道具没给的射程(已断言)。
  - 证据:两帧真实几何 + **声明式道具锚**(锚是**量出来的必需品**:
    109 份 fixture **0 份带 Aether Lens**,已写成断言;被顶掉的道具按名字钉住)。
    `ConsiderQ` 环 **900 → 1150**、`ConsiderW2` 环 **1025 → 1275**,
    `reserve_safe` 上 armed 腿**执行到严格更多的代码**。量具自带阳性对照(半径 spy,M7 致盲)。
  - **⚠️ 诚实边界:抓到的是域翻转,不是决策翻转** —— 两帧最终 desire 两条腿都是 0。
    连同「`ConsiderW` 两帧都够不到」「0/109」一起**写成断言而不是脚注**。
    ⇒ 条件 (a) **只能靠波次买**,不能再造一份 fixture。
  - **⛔ 两个 id 故意不合取**(`pullcad` 陷阱),四种组合全跑,M5 就是那个合取形状。
  - **⭐ 兄弟测试按名字举了手**:`test_aether_lens_range_bonus.lua` §6 断言的
    「Zeus 赋值而从不读」被本轮落地**红了并报出原文**。按 `-81` 先例
    **改指向不删断言**(改断言「恰好读一处」),并把棘轮 **27→26 收紧** ——
    留着昨天的余量就会静默接受一份新抄的 250。
  - 门:开工自检 **worst exit 3**(FINDINGS=`cadence`;**UNCERTIFIABLE=`trunk-red(python)`
    ⇒ trunk 的 python 那一侧本轮没人看过**;两条腿 NOT RUN;第一条命令又被证据纪律 3
    拒答,改对后才有读数)。静态 **`GATE_EXIT=0` / 0 warnings**(冷启自装,**没用 `RULE6_BYPASS`**)。
    动态:新文件 **17/0**、`zuus` **139/0**、`aether` **34/0**、
    `test_gate_claim_consistency` **16/0**、`test_pending_rulings.py` **142/0**;
    **全量套件未跑**(~100min,GH #124)—— **限定不是通过**。
  - **⚠️ 中途被 `test_gate_claim_consistency` 抓了两次,两次都是我的注释**:
    标题写成 `-- [hero] …` 而 `[xxx]` **就是 gate-id 语法**;注释里逐字引用
    `IsSoakCandidate('A') and IsSoakCandidate('B')` 凭空注册了两个只存在于注释里的 id。
    **没有去扩白名单**,改成不引用代码的散文。两条都是审计器按设计工作。
  - **交出去的棒**:`queue.json:hero-28`(只读归档、零 EC2、**不申请 arm**,
    可与 `hero-27` 并成同一次遍历),验收里**预先写死判读方向** ——
    刀口占比接近 0 ⇒ **不入集,即使桌面证据完好**;带 `DOMAIN-NOT-REACHED` 退回门。
    **球在总监**(路由)→ 批测台(执行)。**未提议进 `test_set.md`**。
    已发表(`claim_precheck.sh` EXIT=0 之后):GH #459 追评 `#459#issuecomment-5534625966`
    (更正它自己对这个站点的分类)+ 新开 **GH #471**(剩下 7 个非焦点文件,作用域请总监裁)。

- 2026-09-03T22:49Z(报告 `iterations/reports/hero/20260903T224943Z.md`;轴 **GH #465 复核**)
  **改 1 个 + 新增 1 个:`tests/test_replay_260820_zuus_static_band.lua` §6 重写
  (count → 具名注册表)、新增 `tools/agent/mutstand_zusband.sh`(5 变异全杀)。
  `bots/` + `game/` 零行、零新 gate id、零 arm/promote、零 AWS、不申请波次;
  `state.json` / `queue.json` / `test_set.md` 本轮无新增。backlog 无新增债。**
  - 选题:OWNER_PRIORITIES 无本组项;open `[hero]` 九条里 **#465 是唯一一条今天新开、
    点名要英雄组做、且不等任何人的**(#463/#459 球在总监;#453/#451 是 tinker 且已落地待关;
    #417 根因已定位待关;#407 语料半已交付、剩下的要 W34 录像)。
  - **验收 1 ✅ 算术独立复算逐位相同**(常数直接取 KV 快照、语料用独立脚本重走):
    `221.10 >= 220 > 212.69`,富余 **1.10 = 0.50%**;域 **177 对 / 39 个 trained-ult /
    53 个带 Zeus**。录像组把 `nBand == 0` **重述而不是重新基线化,方向正确**。
    顺带修掉 1.00 那节的陈旧注释(写着 167/37/51,而两节调同一个函数、`nDomain` 与
    `nMult` 无关 ⇒ **必然相等**)。**不并进 1.00 那节**:两句话不同,合并会丢成员归属。
  - **⭐⭐ 本轮的发现是形状不是算术。** #465 自己写了「它是『恰好一个』型的声明,
    不是棘轮」,并**用散文**请求下一位 re-read —— 那句请求住在 **issue 里**,
    未来某一轮没有义务去看的地方(同族:GH #417「主体先于它被销毁的守卫」)。
    原 §6 两个具体缺陷:(甲)**`sWhere` 每命中一次覆盖一次**,记的是 `ls` 顺序的
    最后一个,计数不为 1 时其余成员**在任何地方都没有名字**;(乙)
    **`expected exactly one, got 2` 是一个可以改的数字**,失败消息不含身份也不含算术,
    最省力的修法恰是 #465 请求不要做的那个。⇒ 换成按 `<fixture> / <hero>` 键控、
    值是那行算术的**具名注册表**,三种红(进带 / 离带 / 算术漂移)各自点名。
    **故意不做成棘轮**:棘轮会默默接受带子缩到 0,而一个被声明的 0 变红正是 #465 本身。
    供给量断言留在旁边(`nDomain > 150` **且** `nTrained > 30 and nZeus > 45`,GH #459 的教训)。
  - **⚠️ M3 的第一版是错的,记一笔。** 它动 KV 快照(3.45→3.40),新 §6 确实报了
    「算术漂移」——**但旧文件也红**,因为 §2 早就钉了那份快照(`:239`)。
    **那是被兄弟用例抓住的**,拿它当证据就是**用成立的结论顶替正确的理由**。
    改钉 fixture 的 HP(220→**219**,无任何 tripwire 管它)。**隔离性是量出来的**:
    干净 HEAD 放进 `git worktree`(旧 `assert(nBand == 1)` 形状)+ 修正后的 M3 ⇒
    **`EXIT=0`,15 tests 0 failures** —— 计数形状对它完全失明,注册表点名。
  - 门:开工自检**第一条命令又被证据纪律 3 拒答**(接进 `tail` ⇒ `REFUSED`,不是通过);
    改对后 **worst exit 3**(FINDINGS=`cadence`;**UNCERTIFIABLE=`trunk-red(python)`
    ⇒ trunk 的 python 那一侧本轮没人看过**;5a0/5a 因 120s 预算超时未跑)。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(冷启自装,**没用 `RULE6_BYPASS`**)。
    动态:本文件 **15/0**、`zuus` 过滤 **139/0**;**全量套件未跑**(~100min,GH #124)——
    这是限定不是通过,依据是改动只触及 1 个测试文件 + 1 个新脚本且全仓无其他消费者(已 grep)。
  - **交出去的棒**:**GH #465 建议关闭,裁由总监**(验收 1 已复核复算,验收 2 已从散文
    变成结构),追评已发(`#465#issuecomment-5533173024`)。**无新开 issue、无新 backlog 债。**
    发表前 `claim_precheck.sh` **第一次 EXIT=3**:草稿引用的是 rebase 前的 commit
    (`b10d28c3`),落地后是 `0ff5927c`;改对后 EXIT=0 才发 —— GH #290 那道门的本职。

- 2026-09-03T19:51Z(报告 `iterations/reports/hero/20260903T195122Z.md`;轴 **`deadconst`**)
  **改 2 个文件:`bots/BotLib/hero_axe.lua`(删 3 个死常量 + 2 段注释)、
  `bots/BotLib/hero_zuus.lua`(删 2 个 + 2 段注释)、新增
  `tests/test_dead_numeric_local_census.lua`(6 用例,5 变异全杀)。
  零新 gate id、零 arm/promote、零 AWS、不申请波次;`state.json` / `queue.json` /
  `test_set.md` 本轮无新增(没有行为改动 ⇒ 没有可登记的 id)。charter backlog 新增 `-85`。**
  - 选题:OWNER_PRIORITIES 无本组项(球在批测台 / 协同组 ×2 / 总监);open `[hero]` 五条
    (#459/#453/#451/#447/#416)球都在总监或在焦点五英雄之下;backlog `-84`…`-80` 分别
    在等总监 / 排在焦点之后 / 等录像组 / 等 GH #438 ⇒ 走工作流步骤 1 的兜底。
  - **⭐⭐ 缺陷:焦点五的 `Consider*` 里有 5 个「声明了、从来没被读过」的数字常量,
    其中两个直接误述了技能。** `hero_axe.lua X.ConsiderR` 的 `nRadius = 600`:
    Culling Blade 是单体、`AbilityCastRange 175`,唯一的 `*_aoe` 键是击杀后友军移速 buff 的
    `speed_aoe 900` —— **技能里没有任何 600**;而它**坐在全仓注释最密的杠杆(`hero-2`)
    上方第 8 行,四个轮次写的 ~20 行注释从它上面走过去了**。
    `hero_zuus.lua X.ConsiderR` 的 `nCastRange = 1600` 更坏:Thundergod's Wrath 是**全球**的
    (`zuus_thundergods_wrath` **完全没有 `AbilityCastRange` 键**)⇒ 来审「Zeus 是不是隔太远
    就开大」的读者被展示了**一道从来不存在的闸门**。这是**假前提**,不是无害残留
    (同族:GH #447 的 `ckpush` 证据句、GH #235 收回的 `nodive` 那句)。
  - **⭐ 为什么从来没有计数器:不是漏跑,是按策略关掉的。** `.luacheckrc` 配置成
    `only = { "1" }` —— **只启用全局相关的 1xx**,unused-local 家族(2xx)**全树关闭**。
    那条策略本身不错(1xx 抓 typo 和漏写 local),但这一类因此**一次都没被数过**。
  - **⭐ 全树 46 个不是 46 笔杂账,是一个模板的残留**:**18 个 `local nRadius = 600` +
    17 个 `local nDamage = 0` = 35/46(76%)**,分布在 17 个英雄文件的 `ConsiderQ/W/E/R`。
    **登记不修**(GH #463):那 128 个文件不是本组作用域,与 `-84` 的 27 站点同理。
  - **⚠️ 进场假设被 KV 快照翻过来了,记一笔**:我原以为 `X.ConsiderE` 的
    `600 + nSkillLV * 100` 是编的、`nJumpDistance = 450` 才是真几何。**正好相反** ——
    前者与 `zuus_heavenly_jump/range` 的 700/800/900/1000 **逐字相同**(落地冲击波搜敌半径,
    技能无目标),后者是 `hop_distance` **375/450/525/600 的第 2 级那一档**被当成常数。
    已把「它是对的」写进代码注释,免得下一位来「修」。
  - 变异台 **5/5 全杀**(M1 加回 axe 那个死站点 → `[scope]`+`[ratchet]` 两条,**正确**;
    M4 解析器致盲 → 6 条全红),trap 打印 `RESTORE verified byte-identical`。
  - **⚠️ 第一次的定向动态基线作废并重取**:它在后台跑,而我同时在改同一棵树 ——
    与昨轮报告里那条「变异台 + 后台自检共享 inode」同族(GH #365 §3 / #229)。
    **按那条报告自己给的处置重跑:干净 HEAD 放进 `git worktree`。**
  - 门:开工自检第一条命令**又被证据纪律 3 拒答**(stdout 接进 `tail` ⇒ `REFUSED`,
    **不是通过**);改对后跑满 **600s 被我给的 `timeout` 杀掉**,`EXIT=124` ——
    **最后那条 fast Lua detectors 腿一次都没跑,这一侧本轮没人看过**。
    跑完的腿:unlanded 0、版本锚点 2/2 OK、**2 条 python TRUNK RED 先于本轮**
    (`test_wave_gate_keys.py` = GH #462;`test_mutstand_restore_trap.py` 唯一一条
    `mutstand_fixture_debt.sh traps a function that exists (rm)`,**没有 issue**)。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(冷启自装,**没用 `RULE6_BYPASS`**)。
  - **交出去的棒**:(1) 全树 46 站点 + 模板根因 → GH #463,球在**总监**
    (要不要授权本组或别人按「模板残留」一次性接);(2) `mutstand_fixture_debt.sh` 的
    trap 陷了 `rm` 而不是函数 → 球在**总监 / 该变异台作者**;(3) `hero_zuus.lua:596` 的
    `aetherRange = 250` 是同族但在本普查域外(赋值不是声明),归 GH #459 / backlog `-84`。

- 2026-09-03T17:05Z(报告 `iterations/reports/hero/20260903T170500Z.md`;轴 **`aetherlens`**)
  **改 4 个文件:`bots/FunLib/jmz_func.lua`(新 helper `J.GetAetherLensRangeBonus` + 论证块)、
  `bots/BotLib/hero_crystal_maiden.lua` 与 `bots/BotLib/hero_lion.lua`(各 1 行接线 + 注释)、
  新增 `tests/test_aether_lens_range_bonus.lua`(16 用例,6 变异全杀)。1 新 gated id
  (`aetherlens`,`state.json:aetherlens_20260903T`)、零 arm/promote、零 AWS、不申请波次;
  `queue.json` / `test_set.md` 本轮无新增。charter backlog 新增 `-84`。**
  - 选题:OWNER_PRIORITIES 无本组项;open `[hero]` 五条球都在总监或优先级下(#453 是 tinker);
    backlog `-83`/`-82`/`-81`/`-80` 分别在等总监 / 排在焦点英雄之后 / 等录像组 / 等 GH #438 裁定
    ⇒ 走工作流步骤 1 的兜底,挑焦点英雄找个体问题。
  - **⭐⭐ 缺陷:`item_aether_lens/AbilityValues/cast_range_bonus` 活 KV = **225**,
    而 `bots/` 下 31 个手写常量里 **29 个写 250**。** 少数派(`hero_axe.lua`、`hero_dazzle.lua`)
    才是对的。**形状说「两个抄错了」,域价钱说「另外 29 个是缺陷」。**
    代价不是浪费施法(超射程的单位目标指令会让引擎**先把英雄走进射程**),
    是**一次没计划的贴近**,发生在决策层以为可以原地出手的帧上 ⇒ 修法是**收窄**。
  - **⭐ 为什么从来没人抓到:不是漏跑,是够不着。** `special_value_key_census.py` 的判据是
    「key 在**拥有该技能的英雄** KV 里存不存在」,它取的每份 KV 都是 `npc_dota_hero_*.txt`,
    而 `cast_range_bonus` 住在 `items.txt`。⇒ **「英雄文件里手写的物品数值」是一整类
    从来不在本仓任何普查定义域内的东西**(backlog `-84`)。
  - **SCOPE 只接 2 个站点**:CM(2 消费者)+ Lion(4)。Axe 已经是 225;
    **zuus / skeleton_king 一个活消费者都没有**(zuus 给 `aetherRange` 赋值然后从不读)——
    §6 用例把这条豁免钉住,将来只能被证伪不能被当疏忽。剩下 27 个 + generic 文件
    (1 字面量 / **42 消费者** / 128 英雄下游)**故意不动**:31 站点齐改就是 `lanefix` bundle 形状。
  - **⚠️ 负控值得单独记:空普查会静默通过 `<=` 天花板。** 第一版解析器锚在 `%s*$`,
    全树读到 **0** 个加成(树里每处都写成 `... then aetherRange = 250 end`,字面量在行中间)。
    说话的**不是天花板,是它旁边的供给量断言**(`nOk >= 2`、generic 的 `== 1`)。
    ⇒ **棘轮旁边没有供给量断言,就分不清「没坏」和「根本没扫到」。** 实读 `nOver=27 nOk=2 nOther=1`。
  - **⚠️⚠️ 自检的两条 Lua trunk red,归属不同**:(甲)`test_gated_helper_nesting_census`
    点名 `arbheart,campexit`,**本轮进场 HEAD(`3d4bac6`)上复跑同样红** ⇒ 协同组 15:55Z
    落地留下的,与 GH #457 同族但不同条(#457 是两个 python 普查)。
    **更正:push 前 rebase 带进协同组 16:30Z 的 `76ca7528`,它自己把这条重新钉好了 ——
    rebase 后 `nesting_census` 10/0、`arbheart` 23/0 全绿,这一棒作废,不用交。**
    (乙)`test_stayfield2_marginal_domain` 是**假红,而且是我自己的变异台造的** ——
    变异台在反复重写 `bots/FunLib/jmz_func.lua`,后台自检同时在走同一棵树,
    `require` 拿到半个文件 ⇒ `J` 是 boolean。干净 HEAD **19/0**,变异台停下后工作树 **19/0**。
    ⇒ **GH #365 §3 / #229 那个「全局 inode + 并发写者」家族的新载体:变异台本身**,
    而且它的失效方向最坏 —— 红打在一个你根本没碰过的文件上。**处置:变异台与后台自检不重叠,
    要重叠就跑在 `git worktree` 里。本轮没据此改任何共享文件,交总监决定要不要立案。**
  - 变异台 **6/6 全杀**,每台恰好被一条点名断言杀掉;还原 `cmp` 逐字节相同。
  - 门:开工自检第一条命令**又被拒答**(stdout 接进 `tail`,`SELFCHECK_EXIT=2 REFUSED` ——
    **不是通过**);改对后 `worst exit: 3`(`legs run 9`、**`UNCERTIFIABLE: none`**)。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(冷启自装,**没用 `RULE6_BYPASS`**)。
    定向动态 14 个过滤器全绿(CM 119/0、Axe 98/0、WK 185/0、zuus 53/0、lion 84/0、
    本轮新文件 16/0 等)。全量套件本轮未跑(~100min,GH #124)。
  - **交出去的棒**:`aetherlens` 入集裁定在**总监**;条件 (a) 的检测器写作在**协同组/录像组**
    (**fixture 结构上买不到** —— 与 `lionsplash`/GH #162 同一堵墙);剩余 27 站点 + generic
    文件在 backlog `-84` + GH **#459**;`arbheart` 那条 trunk red 在**协同组**。

- 2026-09-03T13:45Z(报告 `iterations/reports/hero/20260903T134500Z.md`;轴 **`zeusaghs5`**)
  **改 2 个文件:`bots/BotLib/hero_zuus.lua`(+ 一个 helper + 一个 gated 分派 + 注释块)
  + 新增 `tests/test_zeus_aghs_build.lua`(10 用例,3 变异全杀)。1 新 gated id
  (`zeusaghs5`,`state.json:zeusaghs5_20260903T`)、零 arm/promote、零 AWS、
  不申请波次;`queue.json` / `test_set.md` 本轮无新增。charter backlog 新增 `-83` 登记棒交出去。**
  - 选题:OWNER_PRIORITIES 无本组项(四条常设项的球在批测台 / 协同组 / 协同组 / 总监);
    open `[hero]` 五条全部处于「本组认为可关,等总监裁定」或「优先级低于焦点五英雄」的状态
    (#447/#417/#416/#451 已交出裁定,#453 是 tinker,不在焦点五英雄);
    backlog 前三条(`-80`/`-81`/`-82`)都在等别的组或裁定。⇒ **按工作流步骤 1 的
    「backlog 也空 → 挑一个焦点英雄找个体问题」**兜底,选了 Zeus pos_5 的 Aghs 时序。
  - **⭐ 论证形状是理论,不是逐帧**:Zeus pos_5 出货 shipped 顺序把
    `item_ultimate_scepter` 埋到 slot 8,前面 6 件包括 `boots_of_bearing`(4225g 总价);
    累计到 Aghs ~11.2k 金,pos_5 支援 ~350 GPM 需要 ~32 min ⇒ Turbo(~20 min 结束)
    结构上够不到。Nimbus(Aghs 解锁)是 Zeus 团战最大的单件收益。修法就是把 Aghs 挪到
    `item_aether_lens` 后一格(slot 5),其他 item 相对顺序不变(与 `axebuyblink` 同形)。
    **⚠️ 本仓没有 Zeus pos_5 语料**(不像 axebuyblink 有 4 局逐帧读数),所以
    「reachability」是 GPM+推理,不是测量 —— `state.json:known_gap` (1)(2) 明写。
  - **⭐⭐ 门是 gated 的理由是 lanefix/cmboots 教训**:局部正确的支援构筑改动必须先赚到
    condition (b) 才 ship(GH #144);turbo-only + soak candidate 就是这条纪律。
    gate-off 是**纯排列**、byte-for-byte identical(测试文件 tripwire 断言了)。
  - **⭐ SCOPE 严格限制在 pos_5**:pos_2(中)phylactery-first 是合法的对线节奏,
    pos_1/pos_3/pos_4 的 kaya_and_sange / soul_ring 同理 —— 这一闸不管它们。
    测试文件里两条 SCOPE 断言(`pos_2 Aghs index == 12`、`pos_1 Aghs > 5`)会红,
    如果有人后续想扩,得自己开新闸 + 新理由。
  - 变异台(手工,3 变异 + 隐含还原逐字节比对):
    | # | 改动 | 抓到 |
    |---|---|---|
    | M1 | `if false and J.IsModeTurbo() and ...`(禁 gate) | 只红「armed in turbo」1 条 |
    | M2 | gate id → `zeusaghs5x`(不存在) | 只红「armed in turbo」1 条 |
    | M3 | 去掉 `J.IsModeTurbo()`(泄漏到 normal) | 只红「armed in NORMAL mode」1 条 |
    还原后 `cmp` 逐字节相同(手工 cp 回原始)。
  - 门:开工自检 stdout 又被 tail 吃了 ⇒ REFUSED(证据纪律 3,连续第 N 次都是本组当轮第一条命令,
    但这次我识别得早,立刻改成 `>/tmp/sc.log 2>&1; echo EXIT=$?`),真跑完 `worst exit: 3`,
    findings = cadence + trunk-red(python) = GH #410(先于本轮、本轮无 `.py` 改动)+ 2 条
    UNCERTIFIABLE(`test_rc_wrapper.py` / `test_selfcheck_lua_leg.py`,腿内被跳过)。
    静态 `bash tools/agent/luacheck_gate.sh` → **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**
    (冷启自装 lua-check,**没用 `RULE6_BYPASS`**)。定向动态:
    `test_zeus_aghs_build` **10/0**、`zuus` **139/0**、`axe_blink` **53/0**(未回归)、
    `cm_pos5` **19/0**、`smoke_load` **3/0**、`gate_claim` **16/0**、`soakside` **16/0**。
    动态全量套件本轮未跑(~100min,GH #124),这一格照 CLAUDE.md 是可以跳的。
  - **交出去的棒**:`zeusaghs5` 入 `test_set.md` 的裁定在**总监**;波次时机与
    behavioral detector(Aghs 获取时间 + Nimbus 施法数)的写作在**协同组 / 录像组**。
    charter backlog `-83` 登记。open `[hero]` 五条球都还在**总监**(#447/#417/#416/#451)或
    优先级下(#453 tinker 不在焦点)。

- 2026-09-03T10:48Z(报告 `iterations/reports/hero/20260903T104812Z.md`;轴 **GH #451**)
  **改 3 个文件:`bots/BotLib/hero_tinker.lua`(8 处修参 + 一段注释)+ 新增
  `tests/test_utils_getitem_arity.lua` + 新增 `tests/test_hero_export_reachability.py`。
  零新 gate id、零 arm/promote、零 AWS、不申请波次;`state.json` / `test_set.md` /
  `queue.json` 本轮无新增。**
  - 选题:OWNER_PRIORITIES 无本组项(四条常设项的球在批测台 / 协同组 / 协同组 / 总监);
    open `[hero]` 五条里 **#451 是唯一球在本组且本轮能做完的**(#447 本组已认为可关、
    #417/#416 只差总监关闭裁定,#407 被自己那句「拿到语料读数之前不改 `bots/` 一行」挡住)。
    backlog `-81`(球在录像组)/ `-80`(GH #438 裁定前只量不改)顺延。
  - **⭐⭐ 本轮的主发现是 issue 本身错了一节,而它反转了修法**:#451 的
    「活的,不是死代码」依据是读了外层的 `if`,**而外层 `if` 不是可达性**。
    引擎对一个 BotLib 模块只调**三个**函数成员(`bot_generic.lua:20` 的 `MinionThink`、
    `ability_item_usage_generic.lua:4215/8667` 的 `CanUseRefresherShard`/`SkillsComplement`),
    从这三个做传递闭包:`hero_tinker.lua` 21 个函数**可达 8 个**,
    **#451 那 8 处的外层函数全部不可达**(`SkillsComplement` 唯一一处通往 combo 层的
    调用**是注释掉的**,`:338-342`)。⇒ **不上闸**:上闸是让**行为**在验证前保持 dark,
    **不可达的语句没有行为可以 hold dark**;#451 验收 2 那句「修完之后下游第一次可达」
    **修完之后仍然不可达,因为函数不可达**。真正的改动是**接线**,它需要 soak candidate
    + fixture,已登记为 backlog `-82` + 新 `[hero]` issue。**裁断权在总监,回退成上闸版
    是一次 `perl -0pi` 的事,读数已在报告 §2 备好。**
  - **⚠️ 第一版根集漏了 `MinionThink`,读数是 14 而不是 13 —— 是自己起疑复查抓到的,
    不是门抓的**(「`X.MinionThink` 怎么会是孤儿」)。**根集不全 ⇒ 整个结论作废**,
    所以新普查里根集是**从三个 dispatcher 解析出来的**再跟登记值比对:
    上游多出第四个 dispatch 会**点名报红**(N1 台已验),而不是悄悄把 128 个
    英雄文件的可达集一起放宽。
  - **⭐ 域价钱说 tinker 是孤例不是常态**:全仓 **128 文件 / 1061 函数 / 34 孤儿(3.2%)**,
    **113 个文件零孤儿**;`hero_tinker.lua` **13/21**,占全仓孤儿的 **38%**,**1/128**,
    第二名 `hero_medusa.lua` 才 4 个。
  - **⭐⭐ N2 台是本轮最锋利的一格,构造性不是统计**:把 combo 层**接上**之后
    孤儿 `34 → 22`,而 `ORPHAN_CEILING` 那条断言**照样全绿**(22 ≤ 34)⇒
    **棘轮在这一格零信息量**,唯一捕手是 `GH451_UNREACHABLE` 那组登记读数。
    ⇒ **属性只实现一次就必须钉一次**(`-78` 的教训):只写棘轮的话,
    「修参不上闸」这个裁断会在被推翻的当天**无声地**继续成立。
  - **⚠️ GH #442(行号当键)第四轮复现,这次在我自己的变异台上**:M1 按行号
    `sed -i "1523s/..."` 打补丁,而本轮新加的注释已把那行挤到 1537 ⇒ **补丁没打上,
    而台子打的是 `EXIT=0`**(看起来像「测试没抓到」)。**是读 `sed -n` 的回显发现的,
    不是靠退出码 —— 没打上的补丁和抓不到的缺陷在退出码上同形。**
  - 变异台 **6/6 全杀**(arity 4 台含 M3 假阳性控制;可达性 4 台),
    每台恰好被一条点名断言杀掉;还原后 `cmp` 逐字节相同。
  - 门:开工自检**第一次调用又被拒答**(stdout 接进 `tail`)—— **证据纪律 3 的第 13 次
    现场,连续第五轮是本组当轮第一条命令**;改对后 **`EXIT=3`**(`legs run 9`、
    **`UNCERTIFIABLE: none`**,findings = cadence + trunk-red(python))。
    Lua 腿 **73 个 detector 文件 0 失败**。python 腿唯一红文件
    `test_detector_source_constants.py`(3 条)**不是本组的、先于本轮**(零 detector
    `.py` 改动)= GH **#410**;`test_detect_overchase.py` 单跑 **EXIT=0**(不是红)。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(冷启自装,**没用
    `RULE6_BYPASS`**)。定向动态全绿。全量套件读数见报告 §7。
  - **交出去的棒**:#451 已追评更正 + 说明不上闸理由,本组认为**可关**,
    关闭裁定在**总监**;`-82` / GH **#453** 登记 tinker 接线(球在本组,
    但 tinker 不在焦点五英雄,排在焦点英雄之后)。
    `#447`/`#417`/`#416`/`#438` 仍在**总监**;`#407` 仍在**批测台**。
- 2026-09-03T07:53Z(报告 `iterations/reports/hero/20260903T075335Z.md`;轴 **GH #447**)
  **改 2 个文件:`bots/BotLib/hero_chaos_knight.lua`(纯注释,量出来的纯)+
  `tests/test_ckpush_minute_unit.lua`。零行为改动、零新 gate id、零 arm/promote、零 AWS、
  不申请波次;`state.json` / `test_set.md` / `queue.json` 本轮无新增。#447 本组认为可关。**
  - 选题:OWNER_PRIORITIES 无本组项(四条常设项的球在批测台 / 协同组 / 协同组 / 总监);
    open `[hero]` 四条里 **#447 是唯一球在本组且本轮能做完的**(#417/#416 只差总监关闭裁定,
    #407 被自己那句「拿到语料读数之前不改 `bots/` 一行」挡住,读数在 `queue.json:hero-27`)。
    backlog `-80` 顺延(在 GH #438 裁定之前只量不改)。
  - **⭐⭐ 本轮把工作单元从「改一句话」扩成「改一个守卫」,理由是那句话有三个载体,
    第三个是一条活断言**:`['[domain price] no frame at or below the shipped 240 …']`
    断言 `early_with_ult == 0`,域是 `tests/fixtures/*.lua`(27 帧 ≈ 一局)。
    **它在说错的整段时间里是绿的,而且只能是绿的 —— 证伪它的帧结构上不在它的域里。**
    ⇒ **域装不下反例的绿不是证据**;修法**不可能是同一个域上的另一条断言**,
    必须是一条**关于散文**的守卫(§4a),因为域是在散文里被丢掉的。
  - **⭐ 顺带查出注释里 restate 的三个数全都从树上漂走了**(#447 没点名,本轮量的):
    `by60=127`(注释写 138)、`band=12`(写 10)、`ck_frames=27/alive=24`(写 24,歧义)。
    ⇒ **散文只要 restate 一个被测量的数,就多出一份没被钉住的拷贝**;
    新注释**一个数都不再 restate**,改成指向测试里被 COUNT 的读数。
  - **⭐ 两个读数分开登记,因为它们的分歧就是发现本身**:`ARCHIVE`(fixture 档案,§4 活算)
    vs `CORPUS_W41`(82 局 `.dem`)。**归属讲清楚不冒领:`CORPUS_W41` 本轮没复算也不声称复算** ——
    timelines 不在树里(S3 只有 `.dem` + `analysis.json`),引自 #447 / 录像检查组
    `20260903T072000Z.md` §4.4,常量块里逐字写明 NOT RECOMPUTABLE。本轮实算的是 `ARCHIVE`
    那一组 + `ckpush_domain.py --selfcheck` **12 PASS / 0 FAIL**。
  - **⭐ 幸存的是另一个命题,不是同一个弱化版**:「大招还没学会」和「学会了但没放」不是一回事,
    只有后者真 —— 82 局里 t≤240 的 push-Phantasm **施法数 0** ⇒ shipped 240
    **在效果上**不咬(`IN EFFECT`),不是「从不咬」。
  - **⭐⭐ `-78` 那种「人质」结构本轮提前拆了,而且是量出来的**:断言翻成**等式登记读数**,
    红的消息**分两个方向讲**(朝语料漂 = **印证**,更新常量即可,裁定压在 `casts=0` 上不压在它上)。
    **M6**(#447 建议的 t=222.5 帧真的落地)读数:**只打红一条**,band/可分性断言**全绿**。
  - **变异台 7/7 全杀,每条恰好被一条点名断言杀掉**;M0 负控 **15 tests / 0 failures**;
    还原 `cmp` 逐字节相同。**台子自己写 pid 文件按 pid 点杀,全程没用 `pkill -f`/`pgrep -f`。**
  - **⚠ 守卫两次红在它自己身上,同一个错的两次,都是台子抓的不是门抓的**:(1) 第一版把引用豁免
    **键在行上** ⇒ 红掉本轮自己的更正句,而下一行就写着 `#447` —— **GH #442 换身衣服**,
    连续第三轮记「自己踩自己写下的规矩」;改成内容锚点 + 600 字符窗口。
    (2) 再跑,红在自己的 `banned` 模式表上 —— **写全的字面量在自己扫自己的文件里本身就是载体**;
    改成拼接。**LIMIT 主动写出来**:更正段落**内部**新写的全称命题,这条守卫放行。
  - 门:开工自检**第一次调用又被拒答**(stdout 接进 `tail`)—— **证据纪律 3 的第 12 次现场,
    连续第四轮是本组当轮第一条命令**;改对后 **`SELFCHECK_EXIT=3`**(`legs run 9`、
    **`UNCERTIFIABLE: none`**,findings = cadence + trunk-red(python))。**Lua 腿 73 个
    detector 文件 0 失败**。python 1 个文件 3 条红**都不是本组的、都先于本轮**(本轮零 `.py` 改动):
    `test_detector_source_constants.py`,GH **#410**。静态 **`GATE_EXIT=0` /
    `luacheck bots game: 0 warnings` / `RC_EXIT=0`**(冷启自装,**没用 `RULE6_BYPASS`**)。
    定向动态 13 个文件 **152 tests / 0 failures / 13 个 EXIT=0**。
    ⛔ **全量套件没跑成,不声称**:推进到 **1213 / 约 3000**、`^FAIL` **0**,约 16 分钟后按铁律 7 掐掉。
    速度曲线与 GH #124 同形(**前 5.5 分钟 1034 个,后 10 分钟只推进 179 个**)。
    掐法用 **pid 文件点杀**,**没用 `pkill -f`**;事后残留进程 0、`bots/Customize/` 无开关、树干净。
  - **交出去的棒**:#447 本组认为**可关**(更正已落地,且验收比它建议的更强),
    **关闭裁定权按惯例在总监**,本组只发验收读数不自关;**#447 建议的 t=222.5 fixture
    本轮没做、棒已交出**(timelines 不在树里,要先建 dumper 跑 `.dem` = replay-analyst 的活;
    M6 已证明它落地时只打红一条并带正确指引 ⇒ **不阻塞**),已在 #447 追评里点名。
    `#417`/`#416` 仍在**总监**;`#407` 仍在**批测台**;`#438` 那一格仍在**总监**。
- 2026-09-03T04:50Z(报告 `iterations/reports/hero/20260903T045015Z.md`;轴 **backlog `-78` 收官**)
  **改 7 个文件全在 `tests/`(5 个迁移 + 属主注释 + 棘轮/普查);`bots/` 0 行、`game/` 0 行
  ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS、不申请波次;`state.json` /
  `test_set.md` / `queue.json` 本轮无新增。`RAW 5 → 0`、`MIGRATED 17 → 22`、`DELETERS 5 → 0`。
  `-78` DONE。**
  - 选题:OWNER_PRIORITIES 无本组项(四条常设项的球在批测台 / 协同组 / 协同组 / 总监);
    三条 open `[hero]` issue **与前五轮同因**(#417 与 #416 都只差总监的关闭裁定,本组已发表
    验收读数;#407 被它自己那句「拿到语料读数之前不改 `bots/` 一行」挡住,读数在
    `queue.json:hero-27`,`status=running` / `executor=batch-desk` / **硬时限 2026-09-22**)
    ⇒ 取 backlog 最上面一条未完成项 `-78`,执行它自己点名的**最后一批**。
  - **⭐⭐ 收官动作里唯一非机械的一格:S2 那条 `nDeleters >= 1` 是个人质** —— 它只能在
    **缺陷还有活载体**时保持绿,所以**最后一次迁移会因为修好了它所描述的东西而把普查打红**,
    而脱身最便宜的办法是**删掉断言**(读数就丢)。读数进 `ARCHIVED_DELETERS`
    (在 `cd56e50` 上最后量一次:`raw=5 / migrated=17 / deleters=5` + 五个文件名),
    活的那一半**翻向** `nDeleters == 0`。
  - **⭐ 新增两条断言各自是唯一捕手**:**M2**(档案文件被改名)下四条棘轮**全过**,
    只有**档案逐文件在场**开火;**M3**(危害搬进属主)下**每一条都过**(测试文件不删了,
    **属主替它们删**),只有**属主 unarmed 腿**开火。⇒ 属性只实现一次就**必须钉一次**。
  - **⚠️ 第一版守恒写成等式,方向反了,是变异台抓到的不是门**:**M5**(一个**完全合规的
    新委派 gate 测试**)让它 22 → 23 **而红**,而脱身最便宜的办法是**调大档案里的数字** ——
    一个唯一职责就是不可调的档案。改成**下限**后转绿。**与上一格同一个错误、间隔不到一小时。**
  - **⭐ 两个台的前后对照**:台 A(继承残留)HEAD **5/5 静默全绿 EXIT=0 且把残留删掉** →
    迁移后 **5/5 点名失败、残留 5/5 存活**;台 B(并发 `rm`)HEAD **9 失败 / 0 点名 /
    `pollyhp` 整文件 EXIT=0 全绿(假绿)** → 迁移后 **19 失败 / 19 全点名 / 0 条数值不匹配**。
    ⚠️ 口径:GH #216 每条打两遍,38 行 = 19 条,**实读原始输出核对过 2:1**。
    **逐位 no-op**:6 个文件两棵树 `N tests, 0 failures` 逐字相同(20/16/21/18/24/16)。
  - **⚠️ churn 台零孤儿**:循环脚本自己写 pid 文件、按 pid 点杀(不再用 `pgrep -f` / `pkill -f`,
    上一轮那两个各有一次假阳性/自杀);两次 `kill` 后 `ps -p` 均 0 行,两棵树 `bots/Customize/` 已复原。
  - 门:开工自检**第一次调用又被拒答**(stdout 接进 `tail`)—— **证据纪律 3 的第 11 次现场,
    连续第三轮是本组当轮第一条命令**;改对后 **`SELFCHECK_EXIT=3`**(`legs run 9`、
    **`UNCERTIFIABLE: none`**,findings = cadence + stale-waits + trunk-red(python))。
    **Lua 腿 73 个 detector 文件 0 失败**;python 2 条红**都不是本组的、都先于本轮**
    (本轮零 `.py` 改动):`test_stale_waits.py`(GH **#443**)+ `test_detector_source_constants.py`
    (GH **#410** 已追评)。静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings` /
    `RC_EXIT=0`**(冷启自装,**没用 `RULE6_BYPASS`**)。7 个改动文件单跑 luacheck 只有 4 条
    `setting read-only field 'open'`,**在 HEAD 上逐条同在**且 `tests/` 不在门域内。
    ⛔ **全量套件没跑成,不声称**:跑了约 70 分钟、推进到 **1420 / 约 3000** 用例、
    `^FAIL` 计数 **0**,然后按铁律 7 主动掐掉。**1420/3000 是部分**,而 GH #401 那条
    **顺序依赖**的红按定义只有跑完的全量看得见。中途 rebase 带进协同组两个 commit,
    但它们**只动 `.py`/`tools/`、零 `.lua`**(查过的,不是假设的)。
  - **⚠️ 自伤一笔,而且是同一轮里的自相矛盾**:收尾掐套件用了
    `pkill -f "lua5.1 tests/run_tests.lua"` ⇒ **shell 自己被杀 EXIT=144**(标记同时出现在
    调用方命令行里)—— 这正是上一轮记过的形状,**而本轮 §6 的 churn 台恰恰因为改用 pid 文件
    才零孤儿**。⇒ **规矩写死:任何后台循环/长跑自己写 pid 文件、按 pid 点杀;
    `pkill -f` / `pgrep -f` 在这个容器里一律不用。** 事后核对:0 个残留进程、
    `bots/Customize/` 无开关、`git status` 干净。
  - **交出去的棒**:本轮**没有新棒,也没有旧棒掉地**。`-78` 是自给自足的 backlog 项,收官动作
    (S2 改写)已在同一个 change 里完成。`#417`/`#416` 的棒仍在**总监**(只差关闭裁定);
    `#407` 仍在**批测台**;**`#438` 那一格仍在总监**(09-03T02:04Z 追评至今 0 评论,
    按铁律 11 不空转、不预判裁定)。新 backlog **`-80`**:两个普查在数同一个类而互不知情,
    **先量交集,在 #438 裁定之前只量不改**。
- 2026-09-03T02:45Z(报告 `iterations/reports/hero/20260903T024500Z.md`;轴 **backlog `-79`**)
  **改 20 个文件全在 `tests/`(18 个走查载体 + 共享扫描器 + 1 个新常设普查);`bots/` 0 行、
  `game/` 0 行 ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 本轮无新增。`-79` DONE。**
  - 选题:OWNER_PRIORITIES 无本组项(三条常设项的球在批测台 / 协同组 / 协同组);三条 open
    `[hero]` issue **与前四轮同因**(#416 本组认为可关、裁定权在总监;#417 判定权在总监;
    #407 被它自己那句「拿到语料读数之前不改 `bots/` 一行」挡住,读数在 `queue.json:hero-27`,
    `status=running` / `executor=batch-desk` / **硬时限 2026-09-22**)⇒ 取 `-79`,
    并**照它自己的第一句话做**:先把域量准再动手。
  - **⭐⭐ 域量准了:18 个走查 / 18 个文件。前两次数的都不是这个量**(「18 个调用点」来自
    一个窄 grep;「23 里至少 17」是下界不是数)。**方法才是本轮主产物**:每个 `io.popen(...)`
    的实参用**括号/引号平衡**扫描取出 → 解析文件内常量 → 把解析出来的命令**真的执行**
    (在一份带着两个开关的一次性树副本里),**载体 = 输出里真的出现开关路径的命令**。
    两个 grep 都够不到 `ancient_hp_unit` 的 `ls bots/*.lua bots/*/*.lua ...`(**它是载体**),
    也都分不出 `itemtrip_supply_gap` 的 `ls "bots"`(**不递归,一次都到不了**)。
    14 条静态不可解的**全部点名手读**,其中 4 条形参走查(`dir=='bots'`)并入 18。
  - **修法 10 + 8,二分是量出来的**:10 条与 `scan.bots_files()` **逐字同形** ⇒ 改调那个已有入口;
    8 条形状不同 ⇒ **就地**带 `M.FARM_ONLY_FIND_CLAUSE`,**形状问题留给总监**(GH #438 至今
    0 评论,按铁律 11 不空转,取不预判裁定的保守默认)。子句/谓词**只定义一次、引用不复制**。
  - **⭐ 两个读数答两个问题**:(甲) **no-op 逐位**,18 文件 HEAD vs 修完 `tests=N failures=0`
    **18/18 逐字相同**(172 用例)—— **这条对照抓到一处真回归**(`level_gate_census` 留了
    孤儿 `p:close()`,2 条失败),**是对照抓到的,不是门**。(乙) **并发 `rm` 台**:
    HEAD **4 → 修完 0**。**⚠️ 4 不是 18:窗口窄,一趟只咬到一部分**,这正是域必须量的理由。
  - **⭐⭐ 量具留下来了**:`tests/test_bots_walk_farm_only.py`。判据用
    **`bots/Customize/general.lua` 当开关的替身**(永远在场、同目录同后缀)⇒ **它永远不需要
    自己造一个 `soak_*`**;造一个正是要消灭的那种争用,还会先打断所有没修的走查。
    四台自证:**M0 负控**(HEAD 的 18 个)**4 条失败 / 18 个全部点名 / 无一静默**;
    **M3**(删替身)红并明说 `would pass vacuously`;**M4**(新加不可解走查)红并点名;还原逐字节相同。
  - **⚠️ 两处自己踩了自己写下的规矩**:(1) 第一版**用行号做键** —— 正是前一天立案的 GH **#442**,
    **一小时内复现**;改成 文件+表达式文本。(2) `.strip("'\"")` 吃掉子句自己的收尾引号 ⇒
    打印的修复指令是**不能 parse 的 shell 片段**,而**棘轮照样工作**(只坏了给人看的那一半)。
    (3) `pgrep -f <标记>` 又报假阳性(「orphans: 2」),`ps` 一读**两个都是调用方自己的命令行**;
    churn 脚本本轮**自己写 pid 文件**按 pid 点杀,**零孤儿**,两棵树 `bots/Customize/` 已复原。
  - 门:开工自检**第一次调用又被拒答**(stdout 接进 `tail`)—— **证据纪律 3 的第 10 次现场**;
    改对后 **`SELFCHECK_EXIT=3`**(`legs run 9`、**`UNCERTIFIABLE: none`**,findings =
    cadence + stale-waits + trunk-red(python))。**Lua 腿 73 个 detector 文件 0 失败**
    (上一轮那条 `item_name_census` MOVED 钉子已绿)。python 3 条红**全部先于本轮**
    (`illumove_pairs:HP_CUT` + `wandbleed_trigger:HP_MAX`/`HP_MIN_EXCLUSIVE`,GH **#410** 已追评)
    加 `test_stale_waits.py` 1 条。静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings` /
    `RC_EXIT=0`**(冷启自装,**没用 `RULE6_BYPASS`**)。定向动态:18 载体 **178/0**,
    新普查活树上 **`8 checks, 0 failed [165 executed, 14 unresolved]`**、`RC_EXIT=0`。
    ⛔ **全量套件没跑成,不声称** —— 起过一次,**容器重启把它掐了**(与 09-02T19:48Z 同型)。
  - **交出去的棒**(两条均已发表,在 push 之后、`claim_precheck` `clean`/`RC_EXIT=0` 之后):
    GH **#438**(`#issuecomment-5519204661`)追评域读数(18/18)+ 10/8 二分依据 + **剩下要总监裁的那一格**
    (形状不同的 8 条要不要也统一到共享扫描器上,本组**没有替总监做这个决定**);
    GH **#365**(`#issuecomment-5519207920`)追评 §2 载体已全部关窗 + M0 负控读数。`-78` 最后 5 个**仍然不动,棒没掉**
    (要连 `test_soakside_shared_switch.lua` 的 S2 改写一起做);**`#407` 的棒仍在批测台**。
- 2026-09-02T22:54Z(报告 `iterations/reports/hero/20260902T225428Z.md`;轴 **backlog `-78` 第三批**)
  **改 6 个文件全在 `tests/`(2 个迁移 + 棘轮 + 共享扫描器 + 2 个普查);`bots/` 0 行、`game/` 0 行
  ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS、不申请波次;`state.json` / `test_set.md` /
  `queue.json` 本轮无新增。raw 7 → 5,migrated 15 → 17。**
  - 选题:OWNER_PRIORITIES 无本组项(三条常设项的球在批测台 / 协同组 / 协同组);三条 open
    `[hero]` issue 与前三轮同因(#417 判定权在总监、#416 上一轮已执行完它自己的三条验收、
    #407 被「拿到读数之前不许改 `bots/`」挡住,读数在 `queue.json:hero-27`)⇒ 取 `-78`,
    执行**上一轮顺延的**第三批,棒没掉。
  - **⭐⭐ #417 的机制在第三、第四个文件上复现,刀口两边都是用例名字母序**:种下继承残留时
    `aegis_grouping` **6/6 绿**、`tpreach_band` **7/7 绿**且**都把残留删掉**;
    **只跑 unarmed 用例**则两边都**红**。`tpreach_band` 那格最难看 —— 红掉的是钉住缺陷本身的
    case 1 ⇒ **文件把自己要证明的缺陷读成已修好,还打 EXIT=0**。
  - **⭐ 并发 `rm` 台逐断言对照**:两文件均 HEAD **8 失败 / 0 点名** → 迁移后 **40 失败 / 40 全点名**。
    HEAD 上另外 4 条 armed 用例**在开关已被删时照样通过**。⚠️ 口径:GH #216 每条失败打两遍。
  - **⭐ M-D 的教训:棘轮的绿在「假迁移」这一格上零信息量**(4/18 与 5/17 都过两条断言)——
    只有普查读数本身能答;M-C(还原一个文件)则红且数字对得上。
  - **⭐⭐ 计划外主产物:这是 GH #365 §2 的根因,而且它从来不需要等 GH #229。**
    走 `bots/` 全树的普查把 **gitignored、farm-only、被每个 gate 测试创建又删除**的开关文件
    当「shipped 源码」读,`find` 与 `assert(io.open)` 之间是 **TOCTOU 窗口**。#365 公布的三个
    载体(`gate_claim_consistency:42` / `gated_helper_nesting_census:72` / `item_name_census:60`)
    被归因给 #229 的「两个 gate 测试抢开关」并路由进 #229(至今卡在读侧 `GetScriptDirectory`)——
    但**这些文件不是 gate 测试,一行都不写开关,只是走过它**。本轮两次自检又各加一个载体
    (`coarmed_attribution_register:95`;`activemode_call_site_census:94`,同一窗口的
    `io.lines` 变体)。**五个全修 + 共享扫描器**,修法一行
    `! -path "bots/Customize/soak_*.lua"`;**排除是 no-op(量出来的)**:开关在场/不在场/修完,
    我量到的那 18 个走全树的文件读数三次逐位相同 `tests=158 failures=0`。churn 台四个载体全
    **0/6**(`coarmed` 修前 2/6 红),第五个定向 2/0 绿。
    **⚠️ 域没量准**:放宽 grep 后 `io.popen`+`find` 有 **23 处**、**至少 17 处**仍无排除,
    且几个用 `dir` 变量的要逐个读 ⇒ 新 backlog `-79`(第一件事是把域量准)+ 追评 #365 + issue。
    **⚠️ 修的时候差点踩同族的坑**:注释里逐字写开关路径 ⇒ 那四个文件被开关普查收编成 RAW,
    `RAW(5) → RAW(9)`,而**棘轮照样 16/16 绿**(S2 数的是 write+delete 都有的);
    改成 `<that switch>` 后回到 5/17。这正是该普查为 `SELF` 写下的理由,**对第二个文件同样成立
    而没人写下来**;抓到它的是**重跑探针**,不是门。
  - **⚠️ 自伤两笔**:(1) 我的变异台**污染了并发跑着的开工自检**,那次 `TRUNK RED -- 6 of 73`
    **六条全部**是我造成的(三条 TOCTOU,三条文本里直接印着我 churn 写的 `cand = 'x'`)⇒
    那次 Lua 腿读数作废,已在安静树上重跑;**自检的免责句只挡「main 可能是绿的」,
    不挡「同容器兄弟进程就是原因」**(这一格交总监)。(2) `pkill -f <标记>` 把我自己的 shell
    杀了两次(EXIT=144),因为**标记同时出现在调用方命令行里**;且 `setsid ... & $!` 拿到的是
    立刻退出的 setsid pid ⇒ 留下 2 个孤儿,按 pid 点杀才收干净。**下次让循环脚本自己写 pid 文件。**
  - 门:开工自检第一次调用**又被拒答**(`SELFCHECK_EXIT=2 REFUSED`,stdout 接进 `tail`)——
    证据纪律 3 的**第 9 次**现场;改对后 **`worst exit: 3`**(`legs run 9`、`UNCERTIFIABLE: none`,
    findings = cadence + trunk-red(python) + trunk-red(lua),后者见自伤 (1))。
    python 那 3 条**全部先于本轮且本轮零 `.py` 改动**:`illumove_pairs:HP_CUT`(GH #410)
    **加两条新的** `wandbleed_trigger:HP_MAX` / `HP_MIN_EXCLUSIVE`(来自录像组 21:55Z 的
    `9cf795bb`,同一个 `HP_CENSUS` 未登记类)⇒ 追评 #410,不新开。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings` / `RC_EXIT=0`**(冷启自装,
    **没用 `RULE6_BYPASS`**)。⚠️ 但 `ensure_lua_toolchain.sh` 本容器**先失败一次**
    (`could not provide lua5.1/luacheck`),紧接着裸 `apt-get install -y lua5.1 lua-check`
    **成功**(~2s)—— 疑似 dpkg 锁被并发自检占住,**是假设不是结论**(脚本 `>/dev/null` 吞了 apt 报错)。
    动态定向:迁移文件 **6/0**、**7/0**,棘轮 **16/0**;同进程按套件序 **`DRIVER_FILES=23
    DRIVER_TESTS=302 DRIVER_FAILURES=0`**,跑完开关文件不存在。**全量套件没跑成,不声称**
    (起过一次但与 churn 循环时间重叠 ⇒ 污染,主动掐掉)。
  - **⭐ 只有第三次自检的 Lua 腿读数可用**(前两次被我自己的变异台污染,`6 of 73` 全是我造的)。
    安静树 + push 之后重跑:**`TRUNK RED -- 1 of 73`**,`SELFCHECK3_EXIT=3`。**6 → 1 全是污染,
    不是修好了什么。** 那 1 条是真的且不是本轮的:`test_item_name_census.lua` 的 MOVED 钉
    `bots/ability_item_usage_generic.lua:6876 → 6886`,协同组 `77e18be9`(GH #437)在钉子上方
    加了 10 行。**本组本轮 `bots/` 零行**;钉子在本容器里 **rebase 前绿、rebase 后红**。
    已按该测试自己的指示**重锚**(站点逐字不变),这是该钉子第 13 次、**连续第 3 次**被一个
    没理由读这个文件的协同组回合推走 —— 文件自己那句「**开工自检认证的是你到达的那棵树,
    不是你推出去的那棵树**」又得一个证人。
    ⚠️ **协同组几分钟内自己也重锚了同一条(`f00226b2`)** ⇒ rebase 冲突;**保留他们的注释**
    (点名了确切的那十行 :3405),本组只留一句独立见证(本容器里 rebase 前绿、后红)。
    **两个流为同一条红各花了一次收尾** —— 这本身是 GH #439 那条「并发跑门」的一个读数。
  - **交出去的棒**(三条全部已发表,均在 push 之后、`claim_precheck` `RC_EXIT=0`):
    GH **#365** 追评根因(`#issuecomment-5517689021`);新开 GH **#438**
    (剩余作用域怎么修 + 自检横幅不区分「trunk 红」与「同容器兄弟进程红」+ `pkill -f` 教训);
    GH **#410** 追评两个新载体(`#issuecomment-5517692858`,只登记不分类)。
    backlog `-78` 只剩最后 5 个(**要连 S2 改写一起做**),新增 `-79`。
- 2026-09-02T19:48Z(报告 `iterations/reports/hero/20260902T194820Z.md`;轴 **GH #416 的验收三条**)
  **改 1 个文件,在 `tests/`**(新 `test_zusult_pre_ladder_claim_retake.lua`,9 节);
  **`bots/` 0 行、`game/` 0 行 ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 本轮无新增。**
  - 选题:OWNER_PRIORITIES 无本组项;#407 球在 batch-desk(`hero-27`)、#417 判定权在总监
    ⇒ 取 **#416**,因为它**自己写了三条验收而一条都没执行过**。
    ⚠️ **前两轮的本节把 #416 记成「已结论」** —— **「诊断写完」被当成了「验收做完」**,
    与铁律 9 那条「修好 ≠ 做完」同型,只是掉的是结论自己的验收。本轮执行掉。
  - **验收 (1) 域是扫出来的:5 个 arm 了 `zusult`/`zusultx` 的测试文件**(不是 4 个 ——
    扫描扫出了阶梯之后出生的 `test_focus_mana_cost_consumer_census.lua`,**留在断言里
    并注明它无须重取**,而不是按名字滤掉)。M5(临时加一个 arm 的文件)**只红 §1**。
  - **验收 (3):五帧裁决全部不变**(CROSS `zusult` false / `zusultx` true、SAFE 放行、
    LOCK 扣住、DENIED 放行、W2LEAK 扣住),理由不是运气 —— **三个文件都手钉了 ult 价**,
    第四个(towerfear)**消费方够不到**(helper 3 个调用点全在 `hero_zuus.lua`)。
  - **⭐ SAFE 那格的余量塌成 0**:文件锚给 `380−129=251 ≥ 225`(余量 26),
    阶梯给 `380−130=250 ≥ 250`(**余量 0**)⇒ 裁决现在由 `>=` 的等号扛着。
    M2(`>=`→`>`)**只红 §4c**。六个手钉锚 **全部 ≤ 阶梯价,符号唯一**,与
    「两次 0.5s 快照间的回蓝只能让实测花费显得更小」同向;**不主张阶梯更对**。
  - **⭐⭐ 新形状:阶梯之前 `zusultx` 就是 `zusult`。** `nSpellCost > 0` 那句让一个 0
    **不结束调用、而是把增量静默置零**,于是出货子句去回答 ⇒ 阶梯前 arm `zusultx` 的
    fixture **测到的是 `zusult`,还看起来像测到了加宽**。驱动:CROSS 上 spend 价=0 ⇒
    true→false 且**等于窄 id 的答案**,而 spend 价**读了 1 次**(证明体真跑了);
    窄 id 那条**读 0 次**(证明那次读取就是加宽的全部)。**仓库里无受害者**
    (唯一消费方两个操作数都钉了)⇒ 登记不新开 issue。
  - 门:开工自检第一次调用**又被拒答**(`SELFCHECK_EXIT=2 REFUSED`,stdout 接进 `tail`)——
    证据纪律 3 的**第 8 次**现场;改对后 **`worst exit: 3`**(`legs run 9`、
    `UNCERTIFIABLE: none`,findings = cadence + owed-executions + trunk-red(python),
    那条 python 红 = **GH #410** `illumove_pairs:HP_CUT`,先于本轮且本轮无 `.py` 改动)。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(冷启自装,**没用 `RULE6_BYPASS`**)。
    动态定向 `zusult_pre_ladder` **9/0**、`zuus` **139/0**;变异台 **5 变异 + 1 负控**,
    还原 `cmp` 逐字节相同。**全量套件没跑成**(跑到 1031 用例 0 失败时**容器重启把它掐了**,
    读数永久丢失)⇒ **按「没跑成」记,不是通过**。教训:无头 Routine 里
    「起了全量套件」不构成证据,**只有同一轮里读到的那行总结才构成证据**。
  - **交出去的棒**:GH **#416** 已追评三条验收的读数,**本组认为可关**(关不关是总监的裁定权);
    backlog `-78` 第三批(`aegis_grouping` / `tpreach_band`)**顺延一轮,未丢**。
- 2026-09-02T17:04Z(报告 `iterations/reports/hero/20260902T170446Z.md`;轴 **backlog `-78`**
  第二批 = 上一轮点名的 5 个「带直接读点」的 gate 测试)
  **改 7 个文件全在 `tests/`(5 个迁移 + 属主 + 棘轮);`bots/` 0 行、`game/` 0 行 ⇒ 零行为改动、
  零新 gate id、零 arm/promote、零 AWS、不申请波次;`state.json` / `test_set.md` /
  `queue.json` 本轮无新增。12 → 7 个 raw。**
  - 选题:OWNER_PRIORITIES 无本组项;三条 open `[hero]` issue 与上一轮同因,**没有一条
    本轮能推进**(#417 判定权在总监、#416 已结论、#407 被「拿到读数之前不许改 `bots/`」挡住)
    ⇒ 取 backlog 最上面的 `-78`,并按它自己点名的顺序取第二批。
  - **⭐⭐ 主产物:一个构造性读数 —— 竞争在「断言全为 `== false`」的用例上结构性不可见。**
    同一条并发 `rm` 下 `soak_cand_ref` HEAD 红 7 条、迁移后红 9 条,**多出的两条恰好是
    全 `== false` 的那两条**。开关被删 ⇒ 读到未武装的树 ⇒ 每一句 `== false` 照样成立。
    **GH #229 说的是「会造假红」;这里量到的是假绿**(已追评 `#issuecomment-5513379895`,
    发表在 push 之后,`claim_precheck.sh` `PC_EXIT=0`)。
  - **⭐ M7 / M8**:`arm_body` 绕过 `arm_bytes` **只红 2 条新用例、原有 4 条全绿存活**;
    `with_body` 丢掉 `M.finish` 只红 1 条。⇒ 第二个入口确实是无检查副本长回来的路。
  - **⭐ 前后对照**:M-A 迁移前 **5/5 静默 EXIT=0**、迁移后 **5/5 点名失败**;
    M-B 迁移前 **16 失败 0 点名**、迁移后 **25 失败 25/25 点名 0 数值不匹配**。
  - 门:开工自检第一次调用**又被拒答**(`SELFCHECK_EXIT=2 REFUSED`,stdout 接进了 `tail`)——
    证据纪律 3 的**第 7 次**现场;改对后 **`EXIT=3`**(`legs run 8`、`UNCERTIFIABLE: none`、
    findings = cadence + trunk-red(python),那条红先于本轮且本轮无 `.py` 改动)。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings` / `RC_EXIT=0`**(冷启自装,
    **没用 `RULE6_BYPASS`**)。动态定向:5 个迁移文件 + 棘轮 **6/6 全绿**;
    **同进程按套件序跑完 23 个碰开关的文件 `DRIVER_FILES=23 DRIVER_TESTS=302
    DRIVER_FAILURES=0`**,跑完开关文件不存在。全量套件未跑,不声称。
  - **⚠️ 自伤**:M-B 的 `rm` 循环泄漏两个孤儿 shell,污染了随后三次复跑(77/76 条失败);
    **归因只花一次 `ps`,因为失败本身是点名的**。下次并发台用 `pkill -f` 收尾。
  - **交出去的棒**:GH **#229** 已追评(假绿那条,球在总监/协同组 —— 修法仍是读侧的
    `GetScriptDirectory`,属主只是把竞争变成点名失败);backlog `-78` 剩 **7 个 raw**,
    下一批点名 `aegis_grouping` / `tpreach_band`。
- 2026-09-02T13:48Z(报告 `iterations/reports/hero/20260902T134838Z.md`;轴 **backlog `-78`**
  = `-77` 的第二半,把剩下的 raw 文件迁到属主 `tests/mock/soak_side.lua` 上)
  **改 7 个文件全在 `tests/`(6 个迁移 + 棘轮);`bots/` 0 行、`game/` 0 行 ⇒ 零行为改动、
  零新 gate id、零 arm/promote、零 AWS、不申请波次;`state.json` / `test_set.md` /
  `queue.json` 本轮无新增。18 → 12 个 raw。**
  - 选题:OWNER_PRIORITIES 无本组项;三条 open `[hero]` issue **没有一条是本轮能推进的**
    (#417 判定权在总监、#416 已结论、#407 被 `-73`/`-74` 的「拿到读数之前不许改 `bots/`」挡住,
    读数在 `queue.json:hero-27`)⇒ 取 backlog 最上面的 `-78`。
  - **⭐⭐ 主产物:GH #417 的机制在第二个文件上复现,而且是两格对照。** 详见 backlog `-78`:
    HEAD + 种下残留开关时,`test_axe_blink_build` **整文件 10/10 绿**、
    **只留 gate-off 用例则 3/3 红**(读到的是 armed 的买装表)⇒ 全绿是**用例名字母序**
    造出来的,armed 用例结尾那句无条件 `os.remove` 替 gate-off 用例把前提"修好"了。
  - **⭐ M-A 继承残留:迁移前 6/6 静默通过(EXIT=0),迁移后 6/6 点名失败。**
    **⭐ M-B 并发 `rm`:迁移前 6 条失败 0 条点名、其中 3 个文件 EXIT=0 全绿(并发删除
    完全不可见);迁移后 26 条失败 26/26 全点名、0 条数值不匹配。**
  - 门:开工自检 **worst exit 3**(`legs run 8`、`UNCERTIFIABLE: none`;红是**本轮之前就红的**
    `test_incoming_damage_callsite_census.lua:240` = **GH #394** + python 腿)。
    静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings` / `RC_EXIT=0`**(冷启自装,
    **没用 `RULE6_BYPASS`**)。动态定向:**23 个碰开关的文件 23/23 全绿**,
    另有同进程 `run_tests.lua gate` **151 tests / 0 failures**。全量套件未跑,不声称。
  - **交出去的棒**:GH **#229** 追评(M-B 的两格读数是它的严重性证据);
    backlog `-78` 剩 **12 个 raw**,下一批点名 5 个带直接读点的文件。
- 2026-09-02T10:50Z(报告 `iterations/reports/hero/20260902T105033Z.md`;轴 **backlog `-77`**
  = 25 个测试文件各抄一份无检查的 `soak_side.lua` 写盘、没有属主)
  **新文件独一份 `tests/mock/soak_side.lua` + 迁移 4 个测试文件 + 按设计更新普查棘轮;
  `bots/` 0 行、`game/` 0 行 ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 本轮无新增。**
  - **⭐⭐ 主产物:GH #417 的红有根因了,而且它和 GH #365 §3 是同一个事件。**
    把 #417 的文件放进协同组 08-31 建的那台并发机器(并发 `rm -f SIDE_PATH` + 单文件跑),
    **前对照在 `HEAD` 上逐字复现** `the opener must become the arcane variant; got
    item_mage_outfit`(#417 复现块那一句;行号从 `:302` 漂到 `:374` 只是 07:47Z 加了注释)。
    ⇒ **#417 的「顺序依赖」不是顺序依赖,是并发**:一个全局 inode,每个 gate 测试文件的
    unarmed 腿本身就是删除者,而**开工自检自己会 spawn `lua5.1` 跑同一批文件**。
    07:47Z 那轮的三条读数(单跑绿 / trunk 8/8 绿 / 报告者的树也绿)**全部与这个解释相容**。
  - **⭐ 落地:开关有属主了**(`tests/mock/soak_side.lua`)。`arm` 读回比对字节**且拒绝
    覆盖不是自己写的开关**;`disarm` **只删自己写的、且此刻仍是自己那份字节**的文件
    (删掉陌生人的开关正是让**对方**那次失败不可归因的动作);**`assert_still_armed` 在
    用例体之后、断言错误重抛之前再读一次开关**,顺序只写在 `M.finish` 一处 ——
    **开关的因压过它造成的果**,这正是 #365 §3 缺的那一半。
    后对照:同一台并发机器上,三个迁移文件的 **12 条失败 12/12 全是**那条点名诊断,
    **零条数值不匹配**。**不修争用本身**(GH #229 仍开,它得动读侧的 `GetScriptDirectory`)。
  - **⭐ 棘轮的第一条红是假信号,记下来**:S1 打 `only 18 files name … the census lost
    its population` —— **没丢**,迁移后的文件不再含那个字面量,**只 grep 字面量的普查会把
    自己的对象数落**。现在 `switch_files()` 同时认「字面量」和「require 属主」,总体切成
    RAW/MIGRATED;**S2 变单调棘轮 `RAW_CEILING = 18`,只许降不许升**(再抄一遍那三行就红)。
  - **⭐⭐ 变异台两个先漏后杀**:**M4**(`disarm` 无条件删除)对第一版 S5 **12/12 全绿存活** ——
    那个用例先让 `arm` **失败**,于是 `sOwned` 没设上,`disarm` 在**第一行**就返回,
    **变异体那几行从没被执行**;一个用例把「拒绝覆盖 + 拒绝删除」写在一起,**读起来像两条,
    实际只覆盖一条**。**M5**(去掉读回比对)存活是因为**全仓没有任何东西会让写盘失败** ——
    补法是在用例里临时替换 `io.open`,返回一个 `write`/`close` 都答成功、一个字节也不写的
    句柄(**短写在丢返回值的代码眼里就长这样**)。补完 M1–M6 六个变异体全死。
  - 门:静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(冷启自装,**没用
    `RULE6_BYPASS`**)。定向:**22 个写开关的文件 + 普查 + 2 个 gate 一致性文件 = 25 个全绿**。
    **动态全量:没跑完,不冒充全绿** —— 墙钟 ≈3h15m / CPU ≥150min 仍未收尾,
    **没有 `N tests, M failures`、没有 `FULL_EXIT`**;过程中执行到 **3708 个用例、失败 2 个**,
    **两个都先于本轮**(`coarmed` / `incoming_damage`),迁移面零失败。
    ⭐ **这与 GH #401「全量在 routine 容器里跑完了(3000/6)」对不上**,留给总监。
    开工自检第一次调用**又被拒答**(`SELFCHECK_EXIT=2 REFUSED`,
    我把 stdout 接进了 `tail`)—— 证据纪律 3 的**第 6 次**现场,仍然是当轮第一条命令。
  - **本轮之前就红的**(不是我的):`test_coarmed_attribution_register.lua:341`
    (`outlatch > slotpush` 未登记,来自 `04d3db8`,**总监的活**)、
    `test_incoming_damage_callsite_census.lua:240`(**GH #394**)、python 腿三红两 UNCERTIFIABLE。
  - **交出去的棒**:GH **#417** 追评(根因 = #365 §3 同源,**建议关**,裁由总监);
    GH **#229** 立案加强(它的受害者里有一条是以「顺序依赖的神秘红」立成 #417 的);
    backlog `-77` 从 25 → **18 个 raw 文件**,且**有棘轮守着只降不升**。
- 2026-09-02T07:47Z(报告 `iterations/reports/hero/20260902T074742Z.md`;轴 **GH #417**
  = 最新的 [hero] issue,`test_cm_pos5_boots.lua:302` trunk 红、单独跑绿)
  **只动 `tests/test_cm_pos5_boots.lua` 一个文件(+75/−3);`bots/` 0 行、`game/` 0 行
  ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 本轮无新增。#417 不关。**
  - **⭐⭐ 红没复现,而「没复现」这次是读数**:trunk 连跑 **8/8 绿**,
    并且在**报告者自己那棵树 `84176a65`**(`git worktree`)上**也绿** ⇒ **树不是变量**。
    下一轮**不要再重跑单文件推进 #417**(这是 #417「写下来免得下一轮重走」的第三条)。
    嫌疑全部落在进程/容器状态一侧。**不宣称它是假红。**
  - **⭐⭐ 能复现的是「它凭什么绿」**:变异 **M1**(门恒关 `if false and …`)下,
    **改前整个文件只肯说 1 句话**,就是 #417 报的 `:302` —— **指着断言,不指着门**;
    四个"期待门不开火"的用例**全绿**。⇒ **谐波故障与正确行为在这个文件里同形**。
    验收 3 落地:**阳性对照放进它认证的那个用例体内**(独立用例会被过滤器/排序
    与认证对象分开丢掉),M1 下变 **2 红**,新那条打 `STUCK CLOSED`。
  - **⭐ `with_candidate` 写盘三步全无检查**(`f:write`/`f:close` 返回值丢弃、不读回)
    ⇒ 短写/满盘/只读树/别人占路 **全与 M1 同形**。现在写完读回比对字节:
    **M2**(`f:write('')`)从 1 红变 **5 红**,每条打 `does not hold what we just wrote`。
  - **⭐⭐ 一个变异体先漏后杀,教训要留**:**M3**(进程启动前就存在的残留 `soak_side.lua`)
    对我第一版的 per-case 守卫 **19/19 全绿存活** —— `with_candidate` 结尾 `os.remove`,
    而 armed 用例**排在** unarmed 前面,**残留在任何守卫看它之前就被兄弟用例删了**。
    守卫改挂**文件装载时**(唯一看得见「本进程启动状态」的时刻)后才杀死(exit 1)。
    **一个主体先于它被销毁的守卫是散文。**
  - **⚠️ 自伤一例**:开工自检第一次调用**被拒答**(`SELFCHECK_EXIT=2 REFUSED`),
    因为我把 stdout 接进了 `tail` —— 读到的会是 `tail` 的退出码(evidence-discipline 3,
    该脚本记录这是**第 5 次**、且每次都是当轮第一条命令)。
  - 门:静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(容器无 luacheck,
    gate 自己装的 `lua-check`;**没用 `RULE6_BYPASS`**)。动态:受影响文件全量 **19/0**
    (变异台全部还原后复跑)。**全量套件本轮未跑完,报告 §7 只登记已完成的部分,不冒充全绿。**
    另单独买了「装载时守卫会不会在套件序里被别人的残留弄红」这条:**排在本文件之前
    且会写 `SIDE_PATH` 的 8 个文件 + 本文件,同一进程按序跑 ⇒ `DRIVER_FAILURES=0`**,
    跑完 `soak_side.lua` 不存在。**⚠️ 这条读数第一次是空的**(driver 零输出 exit 0,
    GH #200 那个形状)——**mock 把全局 `print` 吞了**,改 `io.stderr:write` 才拿到数字。
    自检 `SELFCHECK_EXIT=3`,八条腿全跑、`UNCERTIFIABLE: none`;两条 trunk 红
    **都先于本轮**且都有 issue(GH **#394** / GH **#410**),与本轮改动无交集。
  - **交出去的棒**:GH **#417** 追评(树不是变量 + 验收 3 已落地并有变异台),**不关**;
    新 backlog **`-77`**(其余 24 个测试文件仍是同一份无检查写盘,收 helper 是跨文件改动)。
- 2026-09-02T04:58Z(报告 `iterations/reports/hero/20260902T045827Z.md`;轴 **backlog `-72`
  = `c386d5f3` 法力阶梯的余波,四个从没扫过的焦点英雄 Zeus / CM / Axe / Lion**)
  **新测试文件独一份 `tests/test_focus_mana_cost_consumer_census.lua`(9 节);`bots/` 0 行、
  `game/` 0 行 ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 本轮无新增。开了 GH #416 与 #417。**
  - **⭐⭐ 一个价钱只能经两条路进决策(可施法性 / 绑定),而 `-72` 之前只有一条被看过。**
    五个焦点英雄的 **17 个 `GetManaCost` 绑定里 9 个是死局部变量**;语料里 416 次直接读**全部**落在它们身上。
    **CM 两个绑定都死 ⇒ 结构性免疫**,而语料里 **14 帧 CM** 落在翻转带里,
    **算术与 Axe/Lion 逐字相同** —— 只有读一眼绑定才知道它在这里什么也不是。
  - **⭐⭐ `zusult`(在当前 armed 集里)的 fixture 域在 09-01 之前是空的:0 → 7 帧。**
    门第四行 `nCost <= 0 → return false`,阶梯前 `nCost` 每帧答 0。42 个活 Zeus 帧、16 帧前置条件成立、
    **16/16 放不出来**。**引擎从来都标价 ⇒ 真实对局没受影响,作废的是 fixture 级论断。GH #416。**
  - **⭐ 活消费方读数(上界)**:Axe/Zeus/Lion 合计 **88 帧里 16 帧(18.2%)**上阶梯翻了
    `J.IsAllowedToSpam`(0.39)或 `J.GetManaAfter(c) > 0.3` 的答案;阴性对照(价钱按回 0)
    在同样 **166** 帧上翻转 **0**。
  - **⭐ 第一把量具是错的,拆穿它的是它自己的阴性对照**:数 `IsFullyCastable` 撤销的探针
    给两个 WK 文件读 0,而变异台上那两个**双双翻红** —— WK 走的是**算术**那条路。
  - **⭐ 反空转**:§1 的 EXPECT 表是从 §1 自己的分类器读出来的 ⇒ **§1c 用四份合成源码给分类器建变异台**
    (不再读 / return 它 / 下一个函数里同名 / 重新绑定后),§1b 是同文件里两种都有的对照(Lion)。
  - **⚠️ 自伤一例**:开工自检那一轮**跑在变异台窗口里**,于是把我自己造的世界报成
    `test_cm_ult_reach_meter_domain` trunk 红。**变异台开着不要跑自检。**
  - 门:静态 **`GATE_EXIT=0` / `luacheck bots game: 0 warnings`**(容器无 luacheck,gate 自己装的
    `lua-check`;**没用 `RULE6_BYPASS`**),push 钩子已上膛。动态:新文件 **9/0**,
    且在**恢复干净 mock 之后**复跑过;全量套件读数见报告 §8。
  - **交出去的棒**:GH **#416**(`zusult` fixture 级论断重取)、GH **#417**
    (`test_cm_pos5_boots.lua:302` trunk 红,**单独跑绿 ⇒ 顺序依赖**,已排除两条错误根因);
    backlog **`-75`**(9 个死绑定要不要接线,**接线是行为改动**)、**`-76`**(`-72` 逐句读那一半,只剩 4 个文件)。
- 2026-09-02T01:54Z(报告 `iterations/reports/hero/20260902T015437Z.md`;轴 **backlog `-73`
  = GH #407,本组 09-01T23:04Z 自己立的案,同时是最新的 [hero] issue**)
  **新测试文件独一份 `tests/test_wk_save_mana_lock_census.lua`(12 节);`bots/` 0 行、`game/` 0 行
  ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次;
  `state.json` / `test_set.md` 无新增,`queue.json` 新增 `hero-27`(只读归档、零 EC2、priority 2)。**
  - **⭐⭐ 本轮的主产物是一个被量出来的拒答,不是那 6。** #407 问「锁掉多少 Q」,
    这份语料**结构上答不了**:出货 `X.ConsiderQ` 在 **33/33 可定价帧上返回 0** ——
    出货量具下 0、把 Q 的 KV 射程 **525** 喂回去(GH #391)**仍然 0**、
    把保蓝**强制按成 false** 后 **33 帧一个决策都没变**。**DOMAIN-EMPTY**(GH #400 那一类)。
    ⇒ 「保蓝在语料上锁掉了 N 次施法」这句**顺手就会写下的话**被提前钉成**不可写**。
  - **⭐⭐ 那个 0 是读数而不是空转,靠的是一个控制**:在 4 个边际帧上数
    `abilityQ:GetCastRange()` 的调用次数 —— **出货腿 0 次**(保蓝确实在那一行前短路),
    **解锁腿 ≥1 次**(函数体真跑了)。没有它,「0 个决策改变」与「反事实压根没执行」
    **长得一模一样**。变异 **M4**(把守卫挪到读射程之后)**只红这一节**。
  - **普查读数**(分母 **33**,不是 36):结构闸内(`nLV≥6` 且 R cd≤3)**11**;保蓝**开火 6**
    (逐个点名);**边际域 4** —— 另 2 帧(`f_225947_wk_trade_kite` /
    `f_260725_105305_wk_reincarn_gap`)的 Q **本来就不 fully castable**,那个析取项**排在保蓝前面**,
    **把 6 当成代价的分子是这一格最容易犯的错**;**构造性 1**(`f_232320_wk_od_burst`,
    max 272 < Q95+R220=315;补了刀口 **314 开火 / 315 静默**,门限就是两价之和本身)。
  - **⭐ 分母纪律**:3 个 v1 fixture(`f_073148_zuus_lina` / `f_080225_wk_lane` /
    `f_080225_wk_revive`)**没有 abilities 列表** ⇒ rank/cd/价钱**全读 0**,
    而 0 与「未学、就绪、免费」是同一个整数;**其中 2 个正好 lv≥6**,
    当成「保蓝没开火」会直接稀释分子 ⇒ **逐个点名排除**。
    另钉 `max_mp`:**36/36 帧自带**,因为 mock 的默认 **300 < 315**,缺一个字段就会
    **凭空制造**一个「构造性放不出 Q」(变异 **M8** 把默认改 400,**只红那一节**)。
  - **⭐ 新发现,已进 backlog `-74`**:这条规则**从不问 R 学没学**(操作数只有 `nLV>=6` 与句柄非 nil)。
    未学技能句柄照样非 nil、冷却读 0 ⇒ 行为全由**引擎对未学技能的定价**决定。
    33 个可定价帧里「lv≥6 且 R rank 0」**0 帧** ⇒ 写成**条件式不是发现**,已挂 `hero-27` 顺带一格。
  - 变异台 **9 + 1 个控制**,条条一次见红且只红在该红的节(M3 刀口、M4 控制、M8 默认值
    **各只红一节**;M9 只加一行注释 **12/12 全绿**);还原走**文件外副本**,
    每次 `sha256sum -c` 3 个文件全 OK,收尾 `cmp` **逐字节相同**。
    门:静态 **`GATE_EXIT=0` / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);
    动态:新文件 **12/0**,全部引用 `skeleton_king` 的 72 个文件 + smoke 见报告。
    ⚠️ 开工自检第一条命令**又是** `| tail` + `$?`(**第十四次**)= 什么都没检查;
    裸重跑 **`SELFCHECK_EXIT=3`**,三类发现全部先于本轮且不属本组
    (#410 python trunk 红 / #394 Lua trunk 红,**移出本轮新文件后独立复现** /
    #383+#384 那一形的 2 个 UNCERTIFIABLE / 2 条 cadence 洞)。
    ⚠️ **自己的坑**:变异台改 `bots/` 时开工自检的 python 腿还在后台跑 —— 两个红都事后
    独立复现过,但正确做法是**串行**,下轮别再并发。
- 2026-09-01T22:55Z(报告 `iterations/reports/hero/20260901T225550Z.md`;轴 **backlog `-71`
  第二格 —— `test_wk_considerq_level7_dominance` :451,GH #392 的最后一格**)
  **测试文件独一份(+205 / −16);`bots/` 0 行、`game/` 0 行 ⇒ 零行为改动、零新 gate id、
  零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次;`state.json` / `test_set.md` /
  `queue.json` 均无新增。⇒ GH #392 三格全清。**
  - **⭐ backlog 记的那个「分歧」是个错名字,一秒结案。** 探针按
    `skeleton_king_wraithfire_blast` 取句柄读到 rank 0 / cost 0 —— 那是**显示名**,
    引擎内部名是 **`skeleton_king_hellfire_blast`**(文件自己的 `Q_NAME` 就是它)。
    mock 对不存在的名字返回空白句柄 ⇒ **0 是「没有这个技能」不是「没升级」**;
    ground truth **没过期**(实测 rank 1 / cd 0 / cost 95)。
    归类:「0 和『没走到』是同一个整数」的第 N 例,这次是「0 和『没有这个句柄』」。
  - **⭐⭐ 真因与 §3b 同族但更靠上游:被唤醒的是 `X.ConsiderQ` 的第一条语句。**
    `ShouldSaveMana` 末项 `mana − Q价 < R价`,阶梯前读作 `272 − 0 < 0` **恒假**;
    阶梯后在这一帧**两个等级上都为真** ⇒ 保蓝**在任何分支跑之前短路**,:451 变红。
  - **⭐⭐ 顺带坐实一个绿着但理由已死的断言(比红的那个更危险)。**
    同文件 `shipped ConsiderQ is silent at level 6` **一直绿**,而它写的理由
    「every branch correctly declines」**09-01 当天变成假的**。绿断言 + 死理由 =
    会被下一个读者继承的那一种;§5c 把**理由**单独钉住,该用例注明它今天是被多重决定的。
  - **重新推导四节**:§5b 把阶梯前量具**按槽位**重建(不按名字清单,且自核验)⇒
    **2026-08-22 的记录逐字复现**(lv6 静默 / lv7 HIGH@OD)——**记录没错,是世界没了**;
    §5c 真实量具下两级都静默**且断言 `ShouldSaveMana==true`**,闸位**从句柄读**
    `R价220 + Q价95 = 315`(**314 静默 / 315 开火**);§5d 把蓝给到 315,
    **等级台阶原样回来(5,6 静默 / 7,8 开火,目标都是 OD)**⇒ §1–§4 的 dominance **完好**,
    死掉的只是「**一个**整数就能从这一帧到达它」;
    §5e **刀口:max mana 272 < 315,满池再问 lv7 仍静默** ⇒ 该等级上 Q **构造性放不出**。
  - **⭐⭐ §5e 不是 mock 产物**:引擎从来都标价,**这个后果在每一局真实对局里一直是活的**,
    答 0 的只有我们的 fixture ⇒ **09-01 之前所有「ConsiderQ 在帧 F 上决定了 X」的存档
    读数,都是在这条保蓝关着的情况下取的。** **已开 GH #407** 立案(要语料不要一帧),
    **本轮 `bots/` 一行不改**。
  - 变异台 **8 个,7 红 1 绿**,条条只红在该红的节。主证据是 M3(保蓝末项按回 `< 0`)
    与 **M5(把 `c386d5f3` 整个撤销)**:红的正好是新的三/四节,而**复现记录的 §5b 一动不动**;
    M6(重建循环 `0,5`→`0,-1`)**只红 §5b** 且红在自核验断言上;M7(R 价 220→100)证明
    315 是**读**出来的;M8 注释 no-op **19/19 全绿**。
    还原走**文件外副本**,每个变异后 **`sha256sum -c` 4 个文件全 OK**。
    探针一律 `io.stderr:write`(mock 把 `print` 换 no-op)。
    门:静态 **`GATE_EXIT=0` / 0 warnings**,**`RC_EXIT=0` 裸读**,**没用 `RULE6_BYPASS`**;
    本文件改动前 **`RC_EXIT=1` 14/1**、改动后 **`RC_EXIT=0` 19/0**。
    ⚠️ 开工自检第一条命令**又是** `| tail` + `$?`(**第十三次**)= 什么都没检查;
    裸重跑 **`SELFCHECK_EXIT=3`**,三类发现全部先于本轮且不属本组
    (#394 trunk 红 / #383+#384 那一形的 2 个 UNCERTIFIABLE / 7 条 cadence 洞)。
- 2026-09-01T19:48Z(报告 `iterations/reports/hero/20260901T194837Z.md`;轴 **backlog `-71`
  第三格 —— `test_wk_bone_guard_talent_bypass` §3,GH #392**)
  **测试文件 1 个(+205 / −8)+ `tests/frames/README.md` 棘轮一行;`bots/` 0 行、`game/` 0 行
  ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 均无新增。**
  - **⭐⭐ 盲区 22 → 19,分母一格没动(36 帧,§2 仍绿),而「缩」比「涨」更需要归因。**
    原因是**法力量具醒了**不是守卫变严了:`X.ConsiderW` 第三个析取项
    `X.ShouldSaveMana(abilityW)` 问 `mana − W价 < R价`,阶梯之前两个价都答 0
    ⇒ 那一句是 `mana < 0`,**任何一帧上都为假**(保蓝规则从落地起没开过火,
    `ad88ecca` 第一次写下来)。阶梯接上线后它在 22 帧里的 **3 帧**开火,
    把它们停在 HasModifier 守卫**前面一个析取项**上 ⇒ 它们**离开**盲区,
    这是本文件希望数字走的方向。补数 14 → **17**,含义不变;占比 61% → **53%**。
    三帧全部 R rank 1(价 220)且不在冷却:`f_225947_wk_trade_kite`(lv7,222−100=122)、
    `f_232320_wk_od_burst`(lv6,272−90=182)、`f_260820_103216_cm_es_aftershock`(lv8,280−100=180)。
  - **⭐⭐ 没有把 22 改成 19 就完事,新增 §3b 把归因测出来。** 分母不动而盲区缩小有两个
    长得一样的世界:(好)量具开始答话,语料现在**能**判它们;(坏)**上游开始掐它们**,
    那样「守卫是唯一挡着的东西」对谁都不再成立、**整份裁定站在沙子上**。**数到 19 分不出这两个。**
    §3b 重跑同 36 帧、把 `GetManaCost` 强制按回 0 重建阶梯前的量具,钉四件事:
    ① 重建世界盲区**恰好回到 22**(#274 那个数**能复现**);② 真实阶梯下**恰好 19**;
    ③ **进入盲区的集合断言为空集**(不是从 19<22 推出来 —— 朝反方向走的帧是第二个未归因改动);
    ④ **离开的三帧逐个点名**并把保蓝三个操作数从帧上读回来核对
    (**一个没点名的 −3 和三个不同的 −1 不可区分**)。
    `WK_ABILITIES` 取**全部五个**技能名而非「今天有 `AbilityManaCost` 行的那几个」——
    后者会在**新加一行的那天悄悄不再是重建**。
  - **⭐ 连带棘轮没有顺手写:那个 staged 帧重测了。** `tests/frames/README.md` 把入集增量
    记成「盲区 22 → 23」,底数已陈;`f_20260831_004433_cm_creepreach` 的 WK 是
    **lv21 / 587 蓝 / W价100 / R rank2 价110**,`587−100=487 ≥ 110` ⇒ 保蓝在那里为假,
    **两个世界读数相同、它确实还在盲区里**,增量仍 +1 ⇒ 行改成 **19 → 20**。
  - 变异台 **7 + 1 个控制**,条条一次见红且只红在该红的节(M4 按 `pre \ now` 算「进入集合」、
    M5 身份写错、M6 判据反号、M7 等级地板 6→16 各自打出自己的诊断行);M0 注释单改绿;
    文件副本还原 `cmp` **逐字节相同**。探针一律 `io.stderr:write` 不用 `print`
    (mock 把 `print` 换成 no-op,一周内已两次交空文件)。
    门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);
    动态 `wk_` **220 tests / 1 failure**(唯一那红是 #392 第二格,**先于本轮改动**),
    本文件 **12/0**;引用 `frames/README` 的另 6 个文件 + smoke 全绿;
    `ratchet` 9/0、`claim_consistency` 10/0、`census` 82/1(那 1 个是 **GH #394**,[bug] 组)。
    ⚠️ 开工自检第一条命令又被 REFUSED(**第十二次**管道给 `tail`)= 什么都没检查不是通过;
    重定向重跑 **exit 3**(cadence + trunk-red×2,lua 那条即 #394),python 腿
    **2 UNCERTIFIABLE** 都是「`lua5.1` 还没装」= GH #383/#384 那一形(容器里
    `/usr/bin/lua5.1` 明明在);**本 diff 零行 python**。
  - **下一棒**:(1) **#392 第二格**(`test_wk_considerq_level7_dominance:451`)是下一个工作单元,
    起点是本轮顺手打的一枪探针 —— 按名字取 `skeleton_king_wraithfire_blast` 读到
    **rank 0 / cost 0**,而该文件 ground-truth 节断言 **rank 1**,**两者读的不是同一个句柄**;
    **这是线索不是诊断**。#392 **划掉一格但不能关**。(2) **backlog `-72` 未动、仍在顶上**,
    本轮又给它添一例:被法力阶梯改读数的测试,文件名里**同样没有 `mana`**
    (它叫 `bone_guard_talent_bypass`)⇒「不能靠文件名筛」现在有**两例**;
    Zeus / CM / Axe / Lion 仍一个都没扫过。(3) #391 / #386 / #357 状态不变。
- 2026-09-01T16:51Z(报告 `iterations/reports/hero/20260901T165100Z.md`;轴 **backlog `-71`
  第一格 —— 三个 WK trunk 红里 `test_wk_roshan_mana_floor` 那一个,GH #392**)
  **测试文件 1 个(`tests/test_wk_roshan_mana_floor.lua`,+192 / −26);`bots/` 0 行、`game/` 0 行
  ⇒ 零行为改动、零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 均无新增。**
  - **⭐⭐ 那个红不是「数字过期」,是一个测试的绿曾经建立在一个 getter 坏着。** §1 那条
    名字叫「nil 句柄」的用例**从落地起就没进过它自己命名的分支**:它先断言句柄**存在**,
    再把 floor 读成 95 —— 而 95 只可能来自 `abilityR:GetManaCost()` 答 **0**。归因**由它自己的
    断言文本给出**(`with the mock answering 0 for an unanchored GetManaCost`),
    `c386d5f3`(本组 09-01 上一轮修法力量具)落地那天它必然红。
  - **⭐⭐ 重新推导买到了一个量具坏着时构造性不存在的读数:整条杠杆现在能在一帧上一行说完。**
    帧 `f_260823_002103_wk_ancient_camp_634`,WK **11 级、447/447 满蓝**、Q/R 都 rank 1
    ⇒ 出货 floor **600 拒绝**,armed floor **95+220=315 准入**。旧世界里 reserve 答 0、
    armed floor 塌成 95,而 **reserve 正是这条杠杆的全部内容** ⇒ 旧文件只能用 §2 的语料计数
    (0/36、24/31)间接论证,**没有任何一帧能把两条腿同时驱动出来**。
  - **⭐ nil 分支改成真的驱动它**:`abilityR` 是 `:499` **加载期一次性绑定**的 module-local
    ⇒ 洞必须在 `rf.load_hero` **之前**开,且必须写在 **`__spec` 表**上(mock 的 `__index`
    首次访问 rawset 一个闭包,那闭包**每次调用重读** `__spec[key]`)。**诚实边界:这是构造**,
    真实对局 `GetAbilityByName` 对每个真技能都给句柄。
  - **⭐ §4 的 0 被收窄了没被关掉,于是把剩下的量出来**:同一帧 **53 个句柄 10 个有价 / 43 个仍答 0**;
    `juggernaut_omnislash`(游戏里 **200 蓝**)仍答 0 ⇒ 非焦点英雄的法力从句**仍是恒真**。
    断言里写死一句:**那 43 个混了「真的没有法力消耗的被动」和「快照里没这个键」——
    ABSENT 不是 0**,只有第二种是缺陷。
  - **⭐ 新增 §3 棘轮**:两条手抄阶梯扛着 §2 的**全部**读数,而 `c386d5f3` 之前**树里没有任何
    东西能反对它们**;现在逐 rank 对上 loader 阶梯 + clamp。**但这是一致性不是佐证** ——
    两边是**同一个 d2vpkr 镜像读了两次**,对上只说明两份拷贝没漂开。
  - 变异台 **5 + 2 控制**,条条一次见红且只红在该红的节(M3 = 把量具打回 c386d5f3 之前,
    恰好红新增的三节);还原后 **3 份 `cmp` 逐字节相同**,基线重跑 16 tests / 0 failures。
    **⭐ M2 是「结论对了理由不对」的反面教材**:`<` → `<=` 该被 §1 那条 one-directional
    **边界**用例抓住(它喂 reserve=460 让相对 floor 恰好 600),**它没抓住** —— `<=` 下
    armed 腿返回 600,而 600 **就是** `SHIPPED_FLOOR`,断言逐位通过;抓住它的是 §5 读源码的棘轮。
    **一个用例名字叫「边界」不等于它守着那个边界。**
  - 门:**静态 `GATE_EXIT=0 CLEAN` / `luacheck bots game` 0 警告**(gate 自己装的 `lua-check`,
    **裸跑没用 `RULE6_BYPASS`**;本 diff 对 `bots`/`game` 零行)。动态按上一轮同口径跑
    **引用 `skeleton_king` 的 70 个 + smoke = 71 个 → 69 绿 / 2 红**,两红 = backlog `-71`
    **剩下的两格,先于本轮改动**(`run_tests.lua <filter>` 只加载匹配文件 ⇒ 那两个文件本轮没被加载过)。
    同族的 `wk_roshan_mana_ceiling` / `wk_roshan_lategame_reconciliation` 都绿。
    ⚠️ 开工自检第一条又被 REFUSED(**第十二次**管道给 `tail`)= 什么都没检查不是通过;
    写文件重跑 **worst exit 3**:`trunk-red(lua)` = **已开的 GH #394**(总监的普查表),
    `trunk-red(python)` + 2 UNCERTIFIABLE = **GH #383/#384 那一形**(python 腿跑在 :451 装 `lua5.1` 之前)。
    另 `luacheck tests/…` 单跑报 1 条 `:176 setting read-only global 'GetGameMode'`,
    **先于本轮改动**(原 `world()` 的 `bNonTurbo` 分支)且不在铁律 6 的门与 CI 范围内,本轮不改。
  - **下一棒**:(1) **GH #392 三格已结第一格**,`considerq_level7_dominance` /
    `bone_guard_talent_bypass` **仍开**,各一个工作单元,留在 backlog `-71`;
    (2) **`c386d5f3` 的余波很可能不止这一个文件** —— 本轮坐实的形状是「**某个测试的绿依赖于
    `GetManaCost` 答 0**」,而本轮扫的 71 个文件**只覆盖 `skeleton_king`**;Zeus/CM 同样吃
    `mana_ladder` ⇒ **新 backlog `-72`**;(3) #391 / #386 / #357 / #374 状态不变。

- 2026-09-01T13:59Z(报告 `iterations/reports/hero/20260901T135952Z.md`;轴 **认领 GH #390** ——
  录像组 13:05Z 开的、本轮最新的 [hero] issue,答它的 rec 2 与 rec 3)
  **`bots/BotLib/hero_skeleton_king.lua` 仅注释(+37,`ConsiderQ` 的 `wkqdmg` 域注解尾部);
  `game/` 0 行;零新 gate id、零 arm/promote、零行为改动、零 AWS(连 S3 GET 都没有)、
  不申请波次;`state.json` / `test_set.md` / `queue.json` 均无新增。
  新 `tests/test_wk_q_castrange_meter_domain.lua`(8 节)。**
  - **⭐⭐ 第五个量具零:`GetCastRange` 未 spec ⇒ 泛型 `^Get` 答 0,36/36 个活 WK 瞬间。**
    和前四个都不同的一点:**答案已经在仓库里** —— 快照给 21 个带价钱技能里的 14 个带着
    `AbilityCastRange`,Q 那条读 **525**,就在 09-01 接上线的 `AbilityManaCost` 阶梯上面三行。
    **不是缺数据,是缺一根线。** 曝露面 **433 代码调用点 / 150 文件**(是 `GetAOERadius` 的 62 倍)
    ⇒ **本轮不修,开成 issue。**
  - **⭐⭐ 闭式:四个圈被缩掉** —— 搜索圈 855→**330**、紧圈 568→**43**、击杀闸 605→**80**、
    远程加宽 875→**350**;**失效方向是低估可达性**。⇒ 本仓库历来每一句「这一帧到不了分支 N」
    都是穿过这四个圈量出来的。
  - **⭐⭐ 语料那个 0,18 帧里 16 帧是空的**:进体 18 帧上,击杀确认循环量具零下**被进入 0 次**,
    喂回 525 后 **2 次**(都走到距离闸、**都不开火**)。⇒ **fixture 语料的 0 不是录像组 0/97
    的第二份意见,是一份从来没有能力反对的读数。**
  - **⭐⭐ 数施法次数量不了这根杠杆**:击杀确认是**十个开火点里的第 2 个**,十个**全返回同一个
    `BOT_ACTION_DESIRE_HIGH`**,只差目标 ⇒ #390 的「两腿不可区分」是**构造性的**,
    armed 108 vs baseline 97 **不是反对证据**。**重新登记的域**多一条合取:
    **该帧没有任何下游开火点交回同一个目标**(边际域);**可观测量是目标身份,不是施法次数。**
  - **⭐ 陷阱:ABSENT 不是 0** —— 7 个技能真的没有射程,但快照同时有字面 `0`(`zuus_cloud`)
    和字面 `-1`(`crystal_clone`)⇒ 「没有键 → 0」会让那七个和 Nimbus 不可区分,`dist <= -1` 恒假。
  - **⚠️ 自己翻的车两次**:探针**报告器是空的**(`print` 被 mock 换 no-op,**一周内第三次**);
    第一版**硬编码 5 个源码行号**,被我自己插的 37 行注释全部错位 —— **错位不会红,它报 0**。
    改成从源码解析行号,并加 **M10 行号解析控制**专管这一形。
  - 变异台 **9 + 2 控制**,条条一次见红且只红在该红的节(M4 空语料控制恰好红 §1§4§5§6);
    还原后 **3 份 `cmp` 逐字节相同**。门:**静态 exit 0 / 0 warnings**(裸读,没用 `RULE6_BYPASS`);
    动态 **71 个文件 68 绿 / 3 红,三红先于本轮改动**(`git checkout` 独立复现)。
    ⚠️ 开工自检第一条又被 REFUSED(**第十一次**)= 什么都没检查;裸重跑 **exit 124 被 timeout 砍掉
    = 没跑完也不是通过**(python 腿 72/0 + **2 UNCERTIFIABLE**,GH #383/#384 那一形)。
  - **⭐ 顺带量到三个 WK trunk 红,先于本轮改动**,其中 `test_wk_roshan_mana_floor` §1+§4
    **断言的是 09-01 修法力之前的世界**(归因由它自己的断言文本给出)⇒ 进 backlog `-71`,已开 **GH #392**。
  - **下一棒**:(1) `GetCastRange` 的零已开 **GH #391**;(2) **GH #390 已按 rec 2/rec 3 追评**,
    `wkqdmg` 维持 gated & unarmed;(3) backlog `-71` / **GH #392** 三个 trunk 红,`roshan_mana_floor` 优先;
    (4) GH #386 仍等录像组,#357 admission 仍阻塞,#374 仍在总监手上。

- 2026-09-01T10:58Z(报告 `iterations/reports/hero/20260901T105812Z.md`;轴 **backlog `-43a`
  的 CM 方向 —— 三个方向的最后一格,本轮付清**)
  **`bots/BotLib/hero_crystal_maiden.lua` 仅注释(+23,`cmrself` 头部 addendum);`game/` 0 行;
  零新 gate id、零 arm/promote、零行为改动、零 AWS(连 S3 GET 都没有)、不申请波次;
  `state.json` / `test_set.md` / `queue.json` 均无新增。新 `tests/test_cm_ult_reach_meter_domain.lua`(8 节)。**
  - **⭐⭐ 入口的「三个只差 1 点蓝的刀口」是**安全**的那三个。** dumper 写 `int32(mp+0.5)`
    ⇒ 记录值 v 的真值在 `[v−0.5, v+0.5)`,margin=−1 时整个区间在价钱之下 ⇒ **三条都确定**。
    **判不了的是没人点名的那个 0**:全语料唯一 margin=0 的读数
    (`f_260819_004858_cm_centaur_far`,200 对 200)真值区间一半在价钱之下,
    **现在算作 castable、不确定性朝「可施放」** —— 法力修复把这个曝露面从 157 收窄到 1,**没关掉**。
    16 个撤销独立复现(48 instant / 209 句柄 / 195 已学 / 157 → 141)。
  - **⭐⭐ 第二个量具零压着大招:`GetAOERadius` 未 spec ⇒ 泛型 `^Get` 答 0**(该家族第四例,
    `bots/` 下 7 个调用点)。`X.ConsiderR` 的 `nRadius = GetAOERadius()*0.88` 乘进两条
    「不看血量」分支的每个子句 ⇒ **历来每一帧上构造性不可达**;**方向与法力项相反:低估可达性**。
  - **⭐⭐ 决策侧 240/240 个 0 且两个世界相同,而这个 0 不作数** —— §4 把造成它的五个常数
    (`GetActiveMode`/`IsGoingOnSomeone`/`IsRetreating`/`FindAoELocation.count`/`GetAOERadius`)
    和那 240 个 0 钉在一起。
  - **⭐ 喂回半径,恰好两帧翻成 `DESIRE_HIGH`**:`f_260820_043039_cm_cask_close`(血 30.0%,
    `#enemies>=3`,队友 0,**0.2s 后死**)、`f_260820_103216_cm_es_aftershock`(血 26.3%,
    `aoeCanHurt>=2`,队友 0,**1.0s 后死**)。810 / 835 两锚同解。
  - **⭐ `cmrself`(停放中)得到两句新话**:多了一个**预检语料之外**的 domain 帧且它
    **不读移速**(预检的移速脆弱性不再覆盖整个 domain),armed 时 **2/2** 收回引导;
    **闭式**:该否决只可能改 branch 1/2(与 branch 3 在同一常数上不交),而 1/2 都乘
    `GetAOERadius` ⇒ **引擎若也答 0 则构造性 no-op,若答 KV 半径则 domain 恰是开火集**。
    **分叉离线读不到,只登记不选边。**
  - **诚实边界**:语料不是对局样本(几个 CM fixture 存在就因为她在死)⇒「48 里 2」
    **不是每局频率**;开火集 **n=2** 同一天;**引擎侧 `GetAOERadius` 未知**(KV 有 `radius=810`、
    **无 `AbilityAOERadius` 键**,姊妹文件锚 835,§7 钉两锚同解);开火集依赖本文件自己喂的量具。
  - **⚠️ 自己翻的车两次**:分支归因第一版**报告器是空的**(`print` 被 mock 换 no-op,一周内第二次);
    §5 普查用裸 `grep -rc` **数到了我自己刚写的两句散文**(7→9),**本文件第一次跑自己红了且红得对**,
    改成按行区分代码/注释并断言注释行 > 0(`-64` 的「40 行读成 43」同一手法)。
  - 变异台 **9 + 1 负控制**,条条一次见红且只红在该红的节(**M8 空语料控制**红五节而 §6§7 不红,
    如实登记);还原后 **5 份 `cmp` 逐字节相同**。门:**静态 exit 0 / 0 warnings**(裸读,
    **没用 `RULE6_BYPASS`**);动态**全部引用 `crystal_maiden` 的 40 个测试文件 exit 0**。
    ⚠️ 开工自检第一条命令又被 REFUSED(**第十次**)= 什么都没检查不是通过;裸重跑 exit 3 =
    cadence(**不是本组**)+ python 腿 UNCERTIFIABLE(**本 diff 零行 python**)。
  - **下一棒**:(1) `GetAOERadius` 的零已开 **GH #386**,**能定案的证据是录像组的**
    (出货 CM 有没有经 branch 1/2 开过大);(2) `cmrself` 维持停放、记法已更新;
    (3) margin-0 那一帧是唯一残留的「朝可施放失效」读数;(4) **`-43a` 三个方向全部付清**,
    GH #357 admission 仍阻塞,GH #374 仍在总监手上。

- 2026-09-01T08:04Z(报告 `iterations/reports/hero/20260901T080403Z.md`;轴 **backlog `-43a`
  的 Lion 方向,连续第七轮欠着 —— 逐帧做了,落点是总监自己写的一条复活条件**)
  **`bots/BotLib/hero_lion.lua` 仅注释(25/3,`SkillsComplement` 里那段过期陈述);
  `game/` 0 行;零新 gate id、零 arm/promote、零行为改动、零 AWS(连 S3 GET 都没有)、
  不申请波次、不开新 issue;`state.json` / `test_set.md` / `queue.json` 均无新增。
  新 `tests/test_lion_ult_reserve_domain.lua`(8 节)。**
  - **⭐⭐ 主读数:`lionult` 的复活条件触发了,重量的结论朝相反方向。** 总监 2026-08-20T23:00Z
    strike lever(a) 时附了条件:**「正确的记法是『在 Finger level 1 上域为空』」**,
    因为 cost 梯子是 `[200,400,600]` 而 **cost=400 那条线对着 380 的蓝池底不是空的** ⇒
    **turbo 局到 hero level 12+ 那天要重量,不许直接引 0/1216**。
    此后两件事发生而没人回来重量:(1) 仓库有了第一个 11 级以上的活 Lion
    (`tests/frames/f_20260831_004433_cm_creepreach`,t=1190.4,**20 级 / Finger rank 2 / cost 400**,
    机制是 owner P3 的 25 分钟局时上限);(2) **09-01 修好法力量具之前这条谓词根本不可求值**
    —— 带子是 `[0,0)` 构造性空集、`mp>=0` 恒真,**08-20 写进 source 的那句语料声称当时无法被证伪**。
  - **⭐⭐ 复活条件的算术只让一边动了,而两边都在动、不同速。** cost 确实是 400,
    **蓝池不是 380 是 1551(假设值的 4.08 倍)**。且这是**闭式的**:带宽 = 最便宜的可施放基础技能,
    Impale 梯子 `{90,110,130,150}` **在 rank 4(约 7 级)就到头冻在 150**,而蓝池不到头
    (387→708→1158→1551)⇒ 带子占蓝池 `150/max_mp` **严格递减**:
    **8 级 21.2% → 20 级 9.7%。升级让这条杠杆的域变小,不是变大。**
    该论证**一帧的当前蓝量都不读**,只依赖两条 KV 梯子和蓝池容量。
  - **⭐ 漏斗(每级是上级子集):活 Lion 24 → 已学 13 → 不在冷却 3 → 付得起 3 → 域内 0。**
    **约束的不是法力是冷却**(13 个已学里 10 个在 cd 上,剩余 1.2–108.6s 对 110s);
    `tooPoor=0` ⇒ GH #73「不是法力」那半独立复现。
  - **诚实边界(必须连着引)**:**rank 2 上 n=1**,裁定的 380 是 1216 帧上的最小值而 1551 是
    **一个满蓝 instant 上的最小值**,**两者不是同一个估计量,1551 绝不可引作「rank-2 蓝池底」**;
    n=1 下**稳的只有闭式带宽论证**。**rank 3(cost 600)完全未测**;
    **「稳定到 12+」不成立**(11 级以上只有一帧)⇒ 复活条件**开始触发了没触发完**。
    帧是 **staged 不是 admitted**(按名字读,#357 的九个 ratchet 一个没动)。
  - **⭐ 顺带:法力修复对焦点五的覆盖比 `-67` 自己声称的窄。** 全语料 trained+cd-ready 句柄
    按成因四桶穷尽、各自非空、零个无法解释:`PRICED` 362 / `NO_MANACOST_KEY` 95(被动,正确)/
    `LADDER_ALL_ZERO` 19(法力汲取等,正确)/ `NAME_NOT_IN_SNAPSHOT` 85 = 天赋 28(正确)
    **+ 内在技能 57**。后者是同一个已知命名错位(引擎 `lion_INNATE_to_hell_and_back` vs
    快照/datafeed 的 `lion_to_hell_and_back`,`hero_skeleton_king.lua:53-60` 已记 33/33 vs 0)——
    **对法力无影响(内在本就不花蓝),所以不是缺陷是陷阱**:将来按引擎名查内在 special value
    会静默拿泛型 0。**快照生成是 harness 的活,本轮不越位。**
    **Lion 被撤销的 castable 读数 0/70;CM 16 个,其中三个只差 1 点蓝**(154 vs 155 ×2、399 vs 400)。
  - **⚠️ 自己翻的车三次**:(1) 第一版驱动器直接调 Consider,24 个 instant 崩 13/17 ——
    **是我的错**,`hEnemyList`/`hAllyList` 由 `SkillsComplement` 在 Consider **之前**填,
    游戏里永远先跑它;**没据此下任何裁定**,改走不驱动 Consider 的求值路径。
    (2) 报告器差点又是空的(`print` 被 mock 换 no-op)⇒ 全改 `io.write` 且每张表打印分母。
    (3) 四桶第一版不穷尽 ⇒ 改成因分类后零个无法解释。
  - **⭐⭐ 变异台抓到一个我本来会留下的洞,已补**:**M7(法力量具回退)下 cost 全 0 ⇒
    `mp>=0` 恒真、`spend` 恒 nil ⇒ `inWindow` 仍是 0,「域为空」那条断言照样绿** ——
    **「空谓词的 0 和空语料的 0 是同一个整数」在我自己的新文件上又发生一次**。
    补前置守卫(先断言 24/24 个 instant 都拿到非零 Finger 价钱再报那个 0),补后 M7 如期见红。
    变异台 **9 个 + 1 个负控制(M9 枚举顺序反转,绿)**,条条一次见红且只红在该红的节;
    从**文件副本**还原,3 份 `cmp` 逐字节相同。
  - 门:**静态 `luacheck_gate.sh` exit 0 / 0 warnings**(裸读没管道,**没用 `RULE6_BYPASS`**;
    容器缺 luacheck,gate 自己装的)。动态子集:**全部 Lion 测试 11 文件 158 例 exit 0**,
    另 8 个相关文件全 exit 0。⚠️ **开工自检第一次又被脚本 REFUSED(exit 2,我把 stdout 管给 `tail`)
    = 什么都没检查不是通过**(**第九次**,依旧是本轮第一条命令);裸重跑 exit 3 =
    `cadence`(**不是本组**)+ python 腿 **UNCERTIFIABLE**(120.1s 超预算,GH #358/#380 同族,
    **本 diff 零行 python**)。
  - **下一棒**:(1) **`lionult` 维持 struck,但记法再窄一格** —— 不是「域为空」也不再是
    「在 level 1 上为空」,而是**「带宽被 Impale 的 150 冻住而蓝池随等级增长 ⇒ 域随等级收缩;
    rank 2 上 n=1 未答,rank 3 未测」**,**GH #73 追评已发表(先 push 后发表,GH #290)**;
    (2) **`-43a` 的 CM 方向仍欠**(Lion 这一格本轮付掉),入口是 CM 那 16 个被撤销的读数
    + 三个「只差 1 点蓝」的刀口;(3) 内在技能命名错位(57 句柄)是 harness 的活,已记未开 issue;
    (4) GH #357 admission 仍阻塞;GH #374 仍在总监手上。

- 2026-09-01T04:51Z(报告 `iterations/reports/hero/20260901T045158Z.md`;轴 **backlog `-43a`
  的 Zeus 方向,连续第五轮欠着 —— 逐帧做了,落点在量具上**)
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、
  不申请波次、不开新 issue;`state.json` / `test_set.md` / `queue.json` 均无新增。
  四个改动文件全在 `tests/` 下。**
  - **⭐⭐ `IsFullyCastable` 的法力项从落地起一次都没能开火。** `GetManaCost` 不在任何技能
    spec 上 ⇒ 泛型 `^Get` 答 0 ⇒ `GetMana() >= 0` 恒真。**修前 4376/4376 个句柄答 0,
    零个答非零**;焦点五 381 个「已学 + 报 castable」被真实 KV 价钱**撤销 40 个(10.5%)**。
    **闸上面那段注释自己点名的举例就在这 40 个里**(190 vs 250 的 Zeus 大招读作 CASTABLE),
    另有 11 法力的 Zeus 与**名字就是法力锁**的帧在 99 法力上读可施放。
    **失效方向朝危险那侧:高估分支可达性** ——「这帧走到了分支 X」都踩在免费法力上。
  - **⭐⭐ 它已经在骗一个绿断言**:manalock 测试断言放 Lightning Bolt,而**同文件文件头**
    记着录像真值是 Arc Lightning ——**两周没有任何一条腿举手**。修好量具让模拟**落回**观测。
  - **⭐⭐ 一条预先写好的绊线如期打红且和解成立**:datafeed(08-23)与 KV 快照
    **相隔九天、独立、三条梯子逐位相同** ⇒ 断言从「缺席」改成「一致」,**严格更强**。
  - **⭐⭐ 全量套件在我宣称完成之后又抓到第二个消费方**:`hero_skeleton_king.lua`
    的 `X.ShouldSaveMana` 末条保蓝规则 `mana - Q:cost < R:cost`。
    `f_225947_wk_trade_kite` 上出货世界 `222-95=127 < 220` **TRUE 保蓝(正确)**,
    免费世界 `222-0=222 < 0` **恒 FALSE(对每帧每英雄)**。
    **它比 `IsFullyCastable` 那条更值钱**:它正是 `wkrosh` 论证里反复引用的
    「本文件自己的 reserve rule」——**那句话在 fixture 世界里从来不是真的**。
    处置:该测试主题是 `GetNearbyHeroes` 顺序不是 WK 法力 ⇒ 把法力抬到
    **恰好 315 = 95+220(清子句的最小值)** 并**声明**,**另加一节**用真实 222 钉住
    刚活过来的保蓝规则(`d == 0`)。**抬升与压制两半都写成断言。**
    ⚠️ **方法论**:我在**全量套件跑完前**宣称了完成,定向子集全绿而全量在那之后才走到它 ——
    **「跑到哪儿为止 0 失败」不等于「全套绿」,本轮当场兑现。**
  - **⚠️ 自己翻的车三次**:报告器是空的(`print` 被 mock 换成 no-op,零输出 exit 0,
    **家族第八次**)、分母为零(4376 数成 0 而比率照打 0.0%,**靠打印分母抓到**)、
    本文件第一次跑自己红了一条**且红得对**(用错代理量给缺口定价)。
  - 变异台 10 个条条见红且只红在该红的节(M7/M8 成对:漂移 + 沉默;M9/M10 成对:抬升
    不再最小 + 定价消失);对照全绿;五份 `cmp` 逐字节相同。门:静态 exit 0 / 0 warnings(裸读,没用 `RULE6_BYPASS`)。
  - **诚实边界**:快照只覆盖焦点五,**其余 122 英雄仍然免费** ⇒ **收窄不是关闭**,
    §3 写成断言,快照扩宽即变红;未建模任何法力减免。
  owner 四条优先项**仍无一条球在本组**(常设运维=批测台;P1/P2=协同组;P3=总监)。
- 2026-09-01T02:21Z(报告 `iterations/reports/hero/20260901T022126Z.md`;轴 **认领上一轮的棒
  「把 GH #357 的帧搬进 `tests/fixtures/`」—— 执行的第一步把它否掉了**)
  **帧没有搬,仍 staged。`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、
  零 AWS(连 S3 GET 都没有)、不申请波次、不开新 issue;`state.json` / `test_set.md` 无新增;
  `queue.json` 只改本组自己的 `hero-10` 的 `question`(不动裁定/路由/优先级/status)。**
  - **⭐⭐ admission 的价钱是 25 个文件不是 9 个。** 范围 = 93 个枚举语料目录的测试文件 + 6 个
    按名字加载该帧的文件;搬进去跑再搬回来 ⇒ **25/93 红**(另 3 个在范围外)。**低了约三倍**;
    #357 自己标了那是**下界不是普查**,而 README 的「therefore unblocked」是从下界推的。已改。
  - **⭐⭐ 未付真判定六条,只有三条是本组的**:level-gate 的 level-20 零(四条 INERT)、
    `frames_past_18min` 0→1(`J.IsLateGame()` 不再空洞 ⇒ `mode_farm_generic:393/:507` TEETH 要重读)、
    `turbo_ternary_dominance` 欠帧钉 —— **不是本组的**;`cm_t10_payoff` 死亡通道、
    `lion_t15_payoff` 域内 Lion、WK 那族(压着 queue `hero-10`)—— **是本组的**。
  - **⭐⭐ 真缺陷**:`test_wk_level_supply_horizon` 的「全仓」= glob + 一条写死路径,
    08-31 起不再穷尽而**绿了三天**,漏掉一位 **21 级 WK**;**失效方向朝危险那侧**
    (它低估了 `hero-10` 前提里仓库已有的证据)。已改成枚举 `tests/frames/`(§2 1→2,新 §6)。
  - **⚠️ 两次自己翻的车**:普查第一版**是空的**(直接跑测试文件只返回表、不调用任何函数体,
    GH #200 的文件头写着)—— 「空谓词的 0 和空语料的 0 是同一个整数」**第七次**;
    开工自检第一次 REFUSED(stdout 管给 `tail`)= **什么都没检查不是通过**,**第七次**。
  - 变异台 8 个全部一次见红且只红在该红的节;还原后 `cmp` 逐字节相同。
  - 门:静态 exit 0 / 0 warnings(裸读,没用 `RULE6_BYPASS`);动态子集 14 组全 exit 0;
    `python3 tests/test_pending_rulings.py` 84 checks / 0 failed。
  owner 四条优先项**仍无一条球在本组**(常设运维=批测台;P1/P2=协同组;P3=总监)。
- 2026-08-31T23:01Z(报告 `iterations/reports/hero/20260831T230146Z.md`;轴 **认领 GH #366,
  付它「建议的验收方式」第 2 条 —— 根因二选一先判掉**)
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、
  不申请波次;`state.json` / `queue.json` / `test_set.md` 均无新增。**
  新 `tests/test_skill_point_stall_frame.lua`(8 节点,`[ratchet]`)。帧**按名字**加载 ⇒
  GH #357 表里 **9 个 ratchet 一个都没动**。
  - **⭐⭐ 分叉判掉了:是 (a),而且不是十条构筑行各自出错,是一条共享的队头阻塞。**
    十个英雄、两个队伍、十份英雄脚本,**同一个截断点**:非天赋技能前四名的 rank 多重集
    **10/10 都是 `{4,4,3,2}`,和 13**;六个各带 1 个天赋、四个 0 个,**没有一个有 2 个**;
    前四名之外的非天赋条目**全部 rank 1**(innate/facet 赠送)。
    ⇒ **13 构筑点 + ≤1 天赋 = 消费掉十四格**,谁都一样,17–22 级都一样。
    **量具零名字表**(#366「量具」一节点名的坑):天赋按引擎自己的前缀 `special_bonus_`
    数(也是 dumper 的过滤键),构筑点取前四名并**断言**其余 ≤ rank 1。
  - **⭐⭐ 墙在第 15 格,源码可证,不需要第二局语料。** (i) 发货的 `J.Skill.GetSkillList`
    把天赋放在第 **10 / 15 / 18 / 19** 格(用**真实函数**跑,天赋名是声明输入;mock 自己的
    `GetTalentList` 答八个 nil —— **测出来的不是假设的**,也正是「到底栽在哪条升级条件」
    离线够不着的原因);(ii) `bots/ability_item_usage_generic.lua` 末尾 `else`
    **不删任何东西,除非 `botLevel > 25`** ⇒ 过不了三条升级分支的队头**把后面一切挡到 26 级**,
    而 turbo 局到不了。**与 GH #286 同族**:#286 的 `CompactSkillList` 只覆盖 **nil 队头**这一形。
    **第二堵墙已在图纸上**:第 18/19 格是 **t20/t25** 天赋,比各自 20/25 级门槛**早 2 级和早 6 级**
    端出来 —— 已写进 §5 断言,不是散文。
  - **⭐ (b) 没有机制**:dumper 的 `resolveAbilities` **每次采样**从活 entity 读 `m_iLevel`,
    **无缓存无 memo**(断言函数体里没有 `map[`,长出缓存就当场变红);数据那半 ——
    同一帧上有 rank 4/3 和 rank 1 天赋,字段在 t=1190.4 **没被截断**。
  - **⭐ 退了 #366 自己的对照组**:CM 按**大招 rank** 读是合法对照(17 级、rank 2 就该是 2),
    按**技能点**读不是 —— 她 13 点 + 1 天赋 = 14 格,t15 那一档两级前就端给她了。
    **对照组在 #366 的量具下存活、在这一把下溶解** ⇒ 损失不是「九个大招各短一级」,
    是**每个英雄欠 3–8 个技能点**。
  - **⚠️ 没确立的三件**:(1) 第 15 格栽在三条条件的**哪一条** —— 没判且离线判不了
    (mock 答八个 nil),**但阻塞与「哪一条」无关**;(2) **一条相关性不是机制** ——
    六个学到的天赋**全是通用天赋**,**全帧零个 hero-unique**,Axe(自己注释写明 t10 取 unique)
    正是零天赋四个之一,**这对配对 n=1**,是线索不是发现;(3) **一局一瞬十个 slot**,
    #366 的 LIMIT 原样继承,**任何频率形状的说法都不成立** —— 但 §2 两条是从**源码**读的,
    那堵墙不管有没有第二份 dump 都在每一局里。
  - 变异台 **12 个,全部一次见红且只红在该红的节**(含 **M7 负控制**:把 `table.remove`
    挪到守卫 `end` 之外,报的就是**顺序**那句话;**M11 读数器只留前 0 名**、
    **M12 谓词清空 `is_talent` 恒 false** —— 专为「空谓词的 0 和空语料的 0 是同一个整数」
    一周内第六次同形而造,**每条经过天赋计数的读数都双边断言天赋面是满的**)。
    还原后 5 文件 `cmp` **逐字节相同**,零残留。**先存副本、从副本恢复,不从 git 恢复。**
  - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态**子集不是全套**
    (GH #124):`skill_point_stall` 8/0、`axe_t15` 21/0、`skill_list` 9/0、`gate_claim` 10/0、
    `smoke` 3/0、`fixture` 93/0、`corpus_existence` 4/0、`nil_head` 9/0,全部 exit 0。
    ⚠️ **开工自检第一次 REFUSED(exit 2,我又把 stdout 管给了 `tail`)= 什么都没检查不是通过**
    (evidence-discipline 第 3 条**第 6 次**复发);重跑 **exit 3**,findings =
    `cadence`/`queue-rulings`/`trunk-red(python)`,那条 python 红是 `test_rc_wrapper.py`,
    **已由 GH #364 立案 flaky**,本 diff 零行 python。
  - **下一棒**:(1) **修复是独立的 gated 工作单元,而且落点不在焦点五英雄的文件里** ——
    `bots/ability_item_usage_generic.lua`,127 个英雄全跑;本轮**不动手**(同一工作单元里
    既付诊断又改所有英雄的加点 = lanefix 教训的形状)⇒ **已开 [bug] GH #374,球交给总监分派**;
    (2) **#366 第 2 条已付,追评已发表**;它请求的第二局语料仍有价值(把读数从「一局十 slot」
    变成频率),但**已不是修复的前置**;(3) **`-43a` 的 Zeus 方向仍欠**;
    (4) GH #357 的「把帧搬进 `tests/fixtures/`」仍解锁着,代价是剩下的 5 条记账行。
  owner 四条优先项**仍无一条球在本组**(常设运维=批测台;P1/P2=协同组;P3=总监)。
- 2026-08-31T19:51Z(报告 `iterations/reports/hero/20260831T195108Z.md`;轴 **付 GH #357 第 2 行
  —— 三条真判定的最后一条,Alchemist 时钟带**。**#357 的真判定清单至此全部付清。**)
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、
  不申请波次、不开新 issue;`state.json` / `queue.json` / `test_set.md` 均无新增。**
  新 `tests/test_alchemist_rage_clock_staged_frame.lua`(11 个节点);
  `test_alchemist_rage_objective_clock.lua` **只改注释与文案,`assert(tMax < ARMED, ...)`
  的条件逐字节未动**;`tests/frames/README.md` reopen 清单第 2 行 OPEN → PAID。
  帧**按名字**加载 ⇒ #357 表里 **9 个 ratchet 一个都没动**。
  - **⭐⭐ 主读数**:staged 帧 t=1190.4 **确实第一次落进两条带**([900,1800) 与 [960,1920)),
    **但时钟是每个调用点五条合取里的最后一条**。用真实 loader、出货 helper 逐个求值,10 个英雄:
    载体(Alchemist/Rubick)**0 / 1,080 hero-instant**(108 帧 41 个英雄)、
    `IsDoingRoshan` **0/10**(`GetActiveMode()` 答 0,`BOT_MODE_ROSHAN=1020`)、
    `IsDoingTormentor` **0/10**、`IsAttacking` **0/10**、`GetAttackTarget` **0/10 (nil)**。
    **那四个 0 全是 mock 默认值不是观测** ⇒ **`alchrage` VERDICT UNCHANGED**。
  - **⭐⭐ 最该拿走的:堵点在生成器,不在世代 —— 比第 3 行糟一级。** 第 3 行的承重零
    (免疫)还在 dumper 已写的 schema 里,后来的帧原则上能动;这一条不是。
    `make_fixture.py` 只发 `units`(**只有英雄**,1,080 个 0 个非英雄)、`buildings`
    (tower/barracks/watch_tower/ancient)、`creeps`(**`team,x,y,dt`,连 name 都没有**;
    19 条记录 0 条带 name),而 `J.IsRoshan`/`J.IsTormentor` 判的是 `GetUnitName()` 里
    有没有 `roshan`/`miniboss` ⇒ **这个 schema 里不存在能命中的记录类型**。
    ⇒ **`make_fixture.py` 产得出的任何一帧、任何世代,都钉不了这个决定**;
    买 (a) 只剩**波次**一条路(`[domain]` 节:`SOAK_CAP_MIN=25 > 15`,可买)。
  - **⭐ 改的是常设指令不是裁定**:`[corpus]` ratchet 的失败文案原写「pin the decision on
    that frame」,**那条指令不可执行**,已改指新文件;**ratchet 保留且仍为绿**
    (语料 tMax **790.4** < armed 900),**条件逐字节未动**。
  - **⚠️ 变异台上自己翻的车(M11 幸存)**:把孪生体 `function X.ConsiderChemicalRage`
    改名成 `...RageXX`,断言 `src:find('function X%.ConsiderChemicalRage')` **照样命中**
    ——改名后的串**包含**原串。**这是 `-63` 那条子串教训一周内的第五次同形**,而且**正好在
    要证明「载体集合就这两个文件」的那行上**失效。已锚到左括号(`%s*%(`),`grep` 同改;
    重跑见红。另一次:`[control]` 第一版只戳 `GetAnimActivity`,`IsAttacking` 仍 false ——
    它读**三个**字段(`GetAttackPoint() > GetAnimCycle()*0.99`,默认 0,`0>0` 为假);
    **控制组该红时红了,而且红出来的东西加强了主结论**(缺的通道是三个不是一个)。
  - 变异台 **14 个,13 个一次见红且只红在该红的节;M11 修后见红**
    (含 **M13:谓词本身清空 `CARRIERS = {}`** —— 专为 -63 那条「空谓词的 0 和空语料的 0
    是同一个整数」造的);还原后 7 个文件 `cmp` **逐字节相同**,零残留。
    **先存副本、从副本恢复,不从 git 恢复。**
  - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态**子集不是全套**
    (GH #124):`alchemist` 21/0、`activemode` 14/0、`axe_cull` 36/0、`axe_t15` 21/0、
    `bbfight` 20/0、`campfarm` 16/0、`focus_innate` 13/0、`cm_creep` 19/0、`smoke` 3/0、
    `gate_claim` 10/0、`fixture` 93/0 —— 覆盖 #357 表点名的每个文件,全部 exit 0。
    ⚠️ **开工自检第一次 REFUSED(exit 2,我把 stdout 管给了 `tail`)= 什么都没检查不是通过**
    (脚本自己拦下,并指出这是 evidence-discipline 第 3 条**第 5 次**复发);重跑 **exit 3**,
    findings = `cadence`/`queue-rulings`/`trunk-red(python)`;那条 python 红是
    `test_rc_wrapper.py`,**已由 GH #364 立案 flaky**,**本 diff 零行 python**。
  - **下一棒**:(1) **三条真判定全清 ⇒ 「把帧搬进 `tests/fixtures/`」现在解锁**,
    是下一个干净的工作单元,代价是 #357 表里剩下的 **5 条记账行**;
    (2) `alchrage` 只剩波次一条路,但**要先入测试集**(`test_set.md` 提议 + 总监批准),
    #357 请裁的两件事**仍在总监手上**,本轮不越位提 queue;
    (3) **`-43a` 的 Zeus 方向仍欠**;(4) GH #366 + queue `hero-26` 在等总监/批测台。
    **#357 追评本轮发表。**
- 2026-08-31T16:51Z(报告 `iterations/reports/hero/20260831T165102Z.md`;轴 **付 GH #357 第 3 行**
  —— 三条真判定的**第二条**,焦点英雄 Axe;上一轮付的是第 6 行)。
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、
  不申请波次、不开新 issue;`state.json` / `queue.json` / `test_set.md` 均无新增。**
  新 `tests/test_axe_bkb_supply_staged_frame.lua`(14 个 `[ratchet]` 节点);
  `test_axe_cull_immune_veto.lua` **只改注释与文案,四条断言逐字未动**;
  `tests/frames/README.md` 补三行 reopen 清单状态表。帧**按名字**加载 ⇒
  #357 表里 **9 个 ratchet 一个都没动**(逐文件跑过)。
  - **⭐⭐ 主读数**:staged 帧上**物品零没了(0 → 2),裁定依赖的零没动(魔免 instants 仍 0)**
    ⇒ `axecull` **SUPPLY-STARVED-IN-CORPUS,VERDICT UNCHANGED**,定价路径仍是 `hero-9`。
    Axe 这帧**是够格载体**(21 级、活、Culling rank 2、cd 0、991 mp;语料最高 14 级),
    所以那两个零**不是「没有 Axe」**。
  - **⭐⭐ 最该拿走的:那个物品零从来不是承重的零,只是承重那个零的代理。** 三条独立:
    (i) **不充分** —— 出厂 `IsMagicImmune` override 读 **modifier、11 个 `HasModifier`、
    零个物品读**,**格子里的物品永远不能让它答 true**(**从源码证出,不要 datafeed 不要波次**);
    (ii) **不必要且不相关** —— 语料真有的 3 个魔免 instant 全是 `juggernaut_blade_fury`,
    **3 个载体全部 0 个黑黄杖**;(iii) **口径错** —— staged 两个黑黄杖**都结构性进不了 domain
    且理由不同**:一个在 **Axe 自己**格子里(veto 读 `npcEnemy`,施法者免疫**不在谓词里**),
    一个在**死着的**敌人身上 ⇒ **不按 (敌方)×(活着) 拆分的计数,2/2 全高估**。
    第三条独立 miss:最近的**活**敌在 **637.5u**(环 375u 外)、1835 hp(阈值 350 之上)。
  - **⭐ 改变的是常设指令不是裁定**:那条 ratchet 变红时,旧读法「裁定可能已错,回去重读」
    → 新读法**「先看免疫计数和载体拆分;光看物品计数什么都没重新判定」**(写在 sister
    ratchet 上方,指向新文件;ratchet 本身保留且仍为真)。
  - **⚠️⚠️ 险些登记一个根本不存在的发现**:第一版 header 断言「sister 记录的供给数在
    **无声向下漂移**(魔免 3 → 0)」。**那个 0 是我 scratch 造的** ——
    `src:sub(src:find(pat))` 传了 `find` 的**两个**返回值 ⇒ 截出的是签名行不是函数体 ⇒
    **免疫名单是空集** ⇒ 每帧都读作不免疫。**空谓词的 0 和空语料的 0 是同一个整数**,
    而它**长得像个发现**(还自带机制解释:单边 ratchet 报不出下降)。抓住它的是我自己写的
    `n ~= 11` 与 §4 计数 ⇒ §4 的免疫计数**故意做成双边**(`~= 3`),
    **本文件每条经过 IMMUNE 的读数都同时断言 IMMUNE 是满的**;变异台补 **M7**(谓词变空但
    函数体照样解析)**四节见红**。一周内**第四次**同形状。
  - **⚠️ 第二处第一版红:子串不是 reader** —— 「不读物品」探针里放了裸的 `black_king_bar`,
    它是 `modifier_black_king_bar_immune` 的**子串** ⇒ 探针**在正好证明论点的那行上开火**。
    改成:物品读 API 名单 + 「体内每个 `black_king_bar` 必须整词等于那个 modifier 名」。
  - 变异台 **11/11 见红且只红在该红的节**;还原后 5 个文件 `cmp` **逐字节相同**,
    `tests/fixtures/`(109)与 `tests/frames/` **零残留**。**先存副本、从副本恢复,不从 git 恢复。**
  - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态**子集不是全套**
    (GH #124),逐个跑了 #357 表点名的每个文件:`axe` 141/0、新文件 14/0、
    `alchemist_rage` 10/0、`activemode_world` 12/0、`campfarm_ancient` 16/0、
    `bbfight_turbo` 20/0、`focus_innate` 13/0、`cm_creep_reach` 19/0、`nil_guard` 6/0、
    `gate_claim` 10/0、`smoke` 3/0。
    ⚠️ **开工自检第一次调用被脚本自己 REFUSED(exit 2,我把它管道给了 `tail`)——
    那次什么都没检查,不是通过**;重跑后 **exit 3**,发现 = cadence 几条 + 
    `test_rc_wrapper.py` TRUNK RED(**已由 GH #364 立案为 flaky**,本 diff 零行 python)。
  - **本组下一棒**:(1) **#357 第 2 行(Alchemist 时钟带)是三条真判定的最后一条**,仍欠;
    付完三条,「把帧搬进 `tests/fixtures/`」才是一个干净的工作单元;
    (2) **`-43a` 的 Zeus 方向仍欠**;(3) GH #366 + queue `hero-26` 仍在等总监/批测台。
  owner 四条优先项**仍无一条球在本组**。

### 历史
- 2026-08-31T13:59Z(报告 `iterations/reports/hero/20260831T135917Z.md`;轴 **付 GH #357 第 6 行**
  —— 章程点名、**连续三轮没人付**的那棒;#357 原文写「英雄组可以按 backlog 顺序接」。
  **第 6 行付清:Axe t15 第一次在域内取数,VERDICT UNCHANGED**(21 级 Axe 的 rank 对
  = Call 3 / Hunger 4 = 结构天花板所用的同一对;收编该帧后方向判据 **17.00 > 12.61** 仍成立)。
  帧**按名字**加载 ⇒ #357 表里 **9 个 ratchet 一个都没动**。
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS、不申请波次;
  `state.json` / `queue.json` / `test_set.md` 均无新增。** 新 `tests/test_axe_t15_in_domain.lua`
  (8 例);`test_axe_t15_payoff.lua` **只改注释与文案,两条断言条件逐字未动**。
  - **⭐⭐ 最该拿走的**:rank 对成立的原因**不是「构筑照做了」** —— 那个 Axe 21 级只点了
    **13 个技能点**(引擎给 18),13 正是 **15 级的构筑状态**;这帧 **9 个 ≥18 级英雄
    9 个大招卡在 2 级**(CM 17 级大招 2 是对的 = **帧内对照组**)。行也没被违抗:
    Hunger 第 4 点在第 10 个技能点、Call 第 4 点在第 14 个 ⇒ **13 点恰好预测出 3/4**。
    ⚠️ **一局一瞬十个相关 slot = 指针不是频率**,故交出去不动手。
  - **⭐ 新界替换旧界**:**t15 的选择本身仍观测不到**(全档案 1,080 个单位**每个最多 1 条
    `special_bonus_*`**,Axe 全部 29 帧带 0 条)⇒ 裁定仍建在可达性算术 + 构筑行上。
  - **⚠️⚠️ 险些把 GH #238 §5 反向重开**:第一版断言「构筑行 15 条 ⇒ list 停在 17 级」,
    而 #238 §5 已裁「看着错,其实是对的」(下标 = 花掉的第 N 个技能点)。我读的是 **mock 的**
    天赋列表。**一个绿着的测试可以把关闭的裁定朝错误方向重开** —— 节点删掉,改按技能点数问。
  - **⚠️ 险些翻车 2**:手写 facet 名单当分类器,跑 855 个单位有 **359 个(42%)判成「不可能」**,
    **而它给 Axe 的答案是对的** ⇒ 已换成读大招 rank(facet 动不了)。
  - 变异台 **10/10 见红且只红在该红的节**;还原 `cmp` 逐字节相同、`tests/fixtures/` 零残留。
  - 门:静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态**子集不是全套**
    (GH #124):`axe` 127/0、`t15` 44/0、`fixture` 93/0、`talent` 72/0、`smoke` 3/0、
    `gate_claim` 10/0、新文件 8/0。⚠️ **开工自检 exit 124(超时)= 没跑成不是通过**;
    它报的 `test_rc_wrapper.py` TRUNK RED **已由 GH #364 立案为 flaky**,本 diff 零行 python。
  - **本组下一棒**:(1) **#357 第 2 行(Alchemist 时钟带)/ 第 3 行(黑黄杖零)仍然欠着**;
    (2) **已开 GH #366 = §3 加点停摆**(GH #238 的反面第一次有帧证据)+ `queue.json`
    **`hero-26`** 语料请求(只要一局 25 分钟局的**晚期** dump,**不是波次**,零 EC2 / 零 AWS 增量;
    acceptance 把根因二选一写死 —— (a) bot 侧真没花点 vs (b) dump 侧 rank 陈旧,
    **不许把 (b) 当成 (a) 就动 `bots/`**);(3) `-43a` 的 Zeus 方向仍欠。**#357 追评已发表。**
  owner 四条优先项**仍无一条球在本组**。

### 历史
- 2026-08-31T10:48Z(报告 `iterations/reports/hero/20260831T104825Z.md`;轴 **认领 GH #354 §5 的另一半**
  —— 上一轮把生成器教会**带上**小兵样本,那一步**单独不改变任何决策**,因为 loader 仍对每个 AoE 搜索
  答固定的 `{count = 0}`;本轮是 **loader 读它**这一半。**本组下一棒:(1) `GetNearbyLaneCreeps`
  观测面 —— 要造小兵单位就得先裁「dump 没血量时 `GetHealth` 答什么」,**答 0 是造假**,诚实的
  替代是拒绝安装该读数让调用方走缺席路径(已在 #354 追评交回);(2) **GH #357** 那份
  9 ratchet / 3 真判定的清单仍没人付(帧 staged 在 `tests/frames/`);(3) 英雄搜索要不要打开
  = 一个带 reopen 清单的决定,本轮明确不做;(4) `-43a` 的 Zeus 方向仍欠)。
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、
  不申请波次、不开新 issue;`state.json` / `queue.json` / `test_set.md` 本轮均无新增。**
  改动三个 `tests/` 文件:`mock/replay_fixture.lua`、新 `test_fixture_aoe_creeps.lua`(15 个
  `[ratchet]` 节点)、`test_cm_creep_reach_real_frame.lua`。
  - **⭐⭐ 主读数**:真实帧 t=1190.4 上 loader 自己答 **shipped(1157 环)= 4 / armed(732 环)= 0**,
    而**把这两个数系在 §3 表上的算术全在 §3 自己里**(`>=4` 在 1152.4 内、`>=5` 在 1312.3 外 ⇒ 最大恰好 4;
    `>=1` 在 805.9 > 732 ⇒ armed 0)。两个为不同问题、由不同代码写成的解算器**在同一帧上对上了**;
    旧的 §6 LIMIT 因此**改写成这条交叉检验**,不是删掉。
  - **⭐ 四条拒绝各有节点,方向一律是低估**:英雄搜索仍 0(每枚 fixture 都带英雄 ⇒ 打开会一次挪动
    约两打普查读数);击杀搜索仍 0(dump 每兵只有 `{t,team,x,y}`,**没血量**);中立不算;
    `fTimeInFuture` 忽略。**一条关于「拒绝方向」的 ratchet,正是后来「让它也答点什么吧」
    不能把上界悄悄变成主张的那道门。**
  - **⚠️⚠️ 最该记的**:第一版 §4 我**手算错了**(829.4),**loader 答 2 而 loader 是对的** ——
    最近点在**一个兵的圆弧上**(679.5),我漏了整个候选族;与「k=4 读成 1157.0」**同形,一周内第三次**。
  - **⚠️ M6 变异第一轮是活的**:单个兵上,便宜粗筛与射程过滤器**是同一个界** ⇒ 没有节点真碰过它;
    补上「一对兵」的隔离节点后 **10/10 见红且只红在该红的节**,`cmp` 逐字节还原。
  - **⭐ 新的更窄 LIMIT**:`J.GetInLocLaneCreepCount` 读的 `GetNearbyLaneCreeps` 仍是空的
    ⇒ 后置过滤器把 hurt count 清零 ⇒ **八个 return 站点仍然一个都开不了火**(实测钉住,不是论证)。
  - 铁律 6 静态 **exit 0 / 0 warnings**(裸读,**没用 `RULE6_BYPASS`**);动态**是子集不是全套**
    (GH #124):`fixture_aoe_creeps` 15/15、`cm_creep_reach_real_frame` 19/19、`cm_` 213/213、
    `fixture` 93/93、`smoke` 3/3、`test_fixture_creeps.py` ok。
  - ⚠️ **继承的 trunk red**:`tests/test_rc_wrapper.py` 动手前就红,本 diff **零行 python 生产代码**
    ⇒ 只登记,不替谁下结论。owner 四条优先项**仍无一条球在本组**。

### 历史
- 2026-08-31T07:51Z(报告 `iterations/reports/hero/20260831T075118Z.md`;轴 **认领 GH #359 §5**
  —— 录像组 07:12Z 开、点名本组的最新 `[hero]` issue,走章程工作流第 1 条的**主路径**;
  §5 那条事实自总监 §CO 加注(08-30T16:51Z)起**已欠四轮**,而它**不需要语料也不需要波次**;
  **本组下一棒:(1) 已在 #359 追评请 dumper 加 `spell_amp` 字段 + `in_thab_window` 谓词
  ——那才能把「谓词」变成「频率」,并当场判掉「`GetSpellAmp()` 报不报 innate 窗口」;
  (2) GH #354 §5 的 loader 读 fixture 小兵;(3) **GH #357** 那份 9 ratchet / 3 真判定的清单仍没人付
  (帧 staged 在 `tests/frames/`);(4) `-43a` 的 Zeus 方向仍欠)——
  自检 **worst exit 3**,`legs run 8`,`FINDINGS: trunk-red(python)`,`UNCERTIFIABLE: none`;
  锚点 ok;快 Lua 腿 **50** 个 tagged 文件 0 失败(FAST SUBSET,**开工那一刻**的取集,**不要做差**)。
  ⚠️ **那条 python 红在动手前就在树上**(`tests/test_rc_wrapper.py`,67 passed / 1 failed),
  本 diff **零行 python 生产代码** ⇒ **只登记,不替谁下结论**。
  owner 四条优先项**仍无一条球在本组**(批测台/协同组/协同组/总监)。
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS(连 S3 GET 都没有)、
  不申请波次、不开新 issue;`state.json` / `queue.json` / `test_set.md` 本轮均无新增。**
  唯一新增文件:`tests/test_lion_spellamp_ladder.lua`(7 个 `[ratchet]` 节点)。
  - **⭐⭐ 主读数:可达的梯子是 {0, 0.20, 0.35},而 #359 的中间栏(15%)不对应任何状态。**
    **+20%** = innate `lion_to_hell_and_back` 的 `spell_amp 20` / `duration 90`(复活或重生后 90s,
    **或到他拿到下一个 kill/assist 为止**;datafeed `hero_id=26`)—— **1 级起、不用买、引擎自己应用**,
    所以 20% 那栏**可达**,而且它的谓词**能从 dump 算**(复活时刻 + 下一个 kill/assist,
    或直接读 `modifier_lion_to_hell_and_back_respawn_buff` —— 本仓 fixture 语料已经带着它)。
    **+35%** = 同一窗口 + 出厂 t15 行取的 [4](`special_bonus_unique_lion_11`,+15%,odota)。
    **15%** 加法读法下是 35 不是 15,替换读法下**比不点天赋还低**且无源支持 ⇒ **它是定价惯例,不是帧状态。**
  - **⭐ 这不动摇 (乙),而且是在 #359 自己发表的阶梯上算出来的**:声明对增强线性
    (`jmz_func.lua:1120`)⇒ 顶档把 `mr25` 声明乘 **1.35**,落在它 `≤1.5×` 的桶里(7/665)⇒
    能改变的帧 **2 → 至多 7 / 665(~1.05%)**,仍是「十局一个 episode」。**不碰它的裁定。**
  - **⭐ 口径两处更正(方向相反)**:`aether_lens` / `ultimate_scepter` / `aghanims_shard`
    在常数里**没有任何 `spell_amp` 属性** ⇒ 这一侧 #359 是**超集**,它的 0 更安全,
    但**以后不许**从「身上有 Scepter/Shard」读出「有增强」;另一侧**中立物品整条路没被覆盖**
    (中立是**掉**的,任何 buy list 都排除不掉)—— 本轮**用数关掉**:本仓中立池 **49** 件里
    **恰好 1 件**给自身增强(`item_harmonizer`,+6%,**tier 5**,~20 分钟的局够不着)。
  - **⭐ 买的那一半**:`pos_4`/`pos_5` 的每一件(含 `item_priest_outfit`/`item_mage_outfit`
    **展开后**的篮子)逐个属性核过,**一件带 `spell_amp` 的都没有**;`item_kaya`(10%)与
    `item_kaya_and_sange`(12%)**只在** `pos_1`/`pos_2`(`pos_3` 别名 `pos_2`)。
    诚实边界:`GetPositionedPool` 的 `weight > RandomInt(5, THRESHOLD)` + Lion 的
    `{30,45,10,30,45}` ⇒ **出厂选人路径并不禁止**他进 pos_2 池;**镜像 draft 会不会路由到那里,
    源码答不了**,语料侧的答案是 #359 自己的 0/665。
  - **⚠️ 明说没 settle 的**:`bot:GetSpellAmp()` **报不报**那个窗口 buff,源码里问不出来
    (API 文档只说「fraction」,dumper 根本不 dump 增强)—— **它只往一个方向咬**:若隐藏则
    窗口内是**低估**,`lionqdmg` 只会**比定价更弱**;**谓词不是频率**;不主张出不出集。
  - 变异台:**10 个变异 10 个见红且只红在该红的节**(M7 = 池尺寸锚,M10 = **空真**守卫,
    解析不到表必须红),盘外 `cp` 还原后 3 份 `cmp` 逐字节相同。

### 历史
- 2026-08-31T05:02Z(报告 `iterations/reports/hero/20260831T050203Z.md`;轴 **认领 GH #354 §5**
  —— 录像组 04:07Z 开、点名本组的新 `[hero]` issue,走章程工作流第 1 条的**主路径**;
  **本组下一棒:(1) 接 loader 读 fixture 小兵,让 `X.ConsiderQImpl` 在 fixture 世界里端到端跑到打兵站点
  ——那才是 #354 §5 字面要的;(2) 付 `tests/frames/README.md` 那份清单再把帧搬进语料
  (三个真判定:Axe t15 域内、BKB 零、Alchemist 带);(3) `-43a` 的 Zeus 方向仍欠)——
  自检 **worst exit 3**,`legs run 8`,`FINDINGS: trunk-red(python)`,`UNCERTIFIABLE: none`;
  锚点 ok;快 Lua 腿 **49** 个 tagged 文件 0 失败(FAST SUBSET,**开工那一刻**的取集,**不要做差**)。
  ⚠️ **那两条 python 红在动手前就在树上**(`test_rc_wrapper.py` / `test_selfcheck_lua_leg.py`,
  后者即 GH #355),本 diff **零行 python 生产代码** ⇒ **只登记,不替谁下结论**。
  owner 四条优先项**仍无一条球在本组**(批测台/协同组/协同组/总监)。
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 EC2(只读 S3,1 个 24.2MB `.dem`)、
  不申请波次;`state.json` / `queue.json` / `test_set.md` 本轮均无新增。**
  - **⭐⭐ 主读数**:真实帧 t=1190.4(CM 在 dire = **baseline 腿**,跑的就是出厂 1157 搜索)上,
    覆盖 ≥k 个敌方兵的**最近**合法圆心 = **805.9 / 904.5 / 925.1 / 1152.4 / 1312.3**(k=1..5),
    可施法环 **732** ⇒ **出厂能交回的每一个 `count>=2` 的点都在射程外 172.5–425 码**
    (是最小值,所以**与引擎 tie-break 无关**);**armed 一个兵都覆盖不到 ⇒ count = 0 ⇒ 八个站点全假**。
    hurt 那一路的 `GetInLocLaneCreepCount <= 2` 过滤器**不清零**(4 个兵全在 1600 内)。
  - **⭐ §5 原样建不出来**:生成器把 `timeline["creeps"]` 丢了 ⇒ 每一枚 fixture 都是
    「没有小兵的世界」⇒ 打兵分支**按构造不可达**。已补(只加不改,无小兵的 dump 逐字节不变)。
  - **⭐⭐ 语料共享输入的代价第一次被量**:这枚 19:50 / 22 级的帧进 `tests/fixtures/` ⇒
    **9 个 ratchet 红**(下界),**3 个是真判定**(Axe t15 域内 / BKB 零→2 / Alchemist 带)⇒
    **没付,帧 staged 在 `tests/frames/`**,清单写进 README + 报告 + **GH #357**(请裁 staging 惯例)。
  - **⚠️ 最该记的**:解算器第一版缺「投影」候选族,k=4 读成 1157.0(**压在环边界上,像个合理答案**),
    真值 1152.4;**只有暴力网格看得见**,已做成永久断言。
  - **⚠️ 前向后果**:新 fixture 从今天起都带 `creeps` ⇒
    `test_campfarm_ancient_target.lua` 的 `[world W1]`(「语料里一个小兵都没有」)
    **会被下一枚进语料的 fixture 弄红** —— 正确的通知,先登记。

### 历史
- 2026-08-31T01:55Z(报告 `iterations/reports/hero/20260831T015533Z.md`;轴 **认领 GH #348 的静态那一半**
  —— 上一轮本组自己开、无人接的那根棒;**本组下一棒:#348 保持 open(修复那半要 gate + 域,
  非焦点五);句柄→技能的 KV 键解析做成工具;26+ 级天赋规则查证;`-43a` 的 Zeus 方向仍欠**)——
  自检 **worst exit 3**,`legs run 8`,`FINDINGS: unlanded trunk-red(python)`,`UNCERTIFIABLE: none`;
  锚点 ok;快 Lua 腿 **47** 个 tagged 文件 0 失败(FAST SUBSET,**开工那一刻**的取集,**不要做差**)。
  ⚠️ **那条 TRUNK RED 我复核不出来**:自检说 `tests/test_selfcheck_lua_leg.py` FAIL,
  当场单跑同一文件是 `43 checks, 0 failures`、**exit 0**,工作树当时干净、本 diff 零行 python
  ⇒ 两个读数不一致,**登记给总监,不替谁下结论**。
  owner 四条优先项**仍无一条球在本组**(批测台/协同组/协同组/总监)。
  **`bots/` 0 行、`game/` 0 行;零新 gate id、零 arm/promote、零 AWS、不申请波次、不开新 issue。**
  改动仅两个 `tests/` 文件:`lua_source_scan.lua` 新增 `M.AOE_RESULT_KEYS` + `M.aoe_result_fields`
  (**只加不改**),新文件 `tests/test_aoe_result_field_names.lua`(4 个 `[ratchet]` 节点)。
  `state.json` / `queue.json` / `test_set.md` **本轮均无新增**。
  - **⭐⭐ 主读数:`.cout` 不是 `FindAoELocation` 返回表的键**(只有 `count`/`targetloc`,
    `docs/BOT_API_REFERENCE.md:1377`)⇒ `.cout ~= nil` **恒假** ⇒ 那条「对多个敌方英雄放 AoE」
    的分支**在本仓历史上从未开火也开不了火**;Lua 读缺键不报错 + bot 侧零错误可见性 ⇒
    **症状只有「一个从不被做的决策」**。与 GH #162 / `GetAbilityDamage()` 恒零同族。
  - **⭐ issue 里没有的第二个站点:`hero_muerta.lua:360`。** #348 只点了 Sniper;Muerta 是
    **同一块代码的逐字复制** ⇒ **一次上游复制粘贴,不是两次笔误**。已钉进测试,追评到 #348。
  - **⭐ 焦点五在这条不变量上干净,而且是数出来的**:五个文件 **14** 个可跟踪声明、**0** 个越界字段
    (`sites == 14` 一并断言,免得这句话**空真**);全树 **332** 个可跟踪声明(总调用点 353)。
  - **⚠️⚠️ 第一版的两个合成对照挡不住 M4(词边界)/ M8(`function` 边界),而这两个变异
    在全树普查上也都是绿的** ⇒ 只有普查节点的话,这两处扫描器缺陷**没有任何断言看得见**。
    改成 `n`/`fn.wibble`(点紧跟被匹配前缀之后)与 `function Other( b )` 参数遮蔽后才红。
    **同一件事在 `test_nil_guard_then_body.lua` 头部记过一次,本轮在新扫描器上又发生一次。**
    最终变异台 **9/9 见红且只红在该红的节**,对照 4/0 绿,盘外 `cp` 还原后四份 `cmp` 逐字节相同。
  - **⚠️ 明说没做的**:**没修**那两处 `.cout`(修它=复活分支=加动作,要 gate + 域,
    且两个英雄都不在焦点五);**没为它申请波次**;**不主张焦点五 AoE 代码干净**
    (不说半径对不对 / 不说判没判 nil —— 353 里 350 个没判 / 不说 `.count` 守的是不是对的分支);
    **不改 Axe:930 / Lion:1385 那两段 `talent8` 注释**(取决于 26+ 级能否拿对侧天赋,我查证不下来)。
  - **⚠️ 动态半是子集不是全套**(GH #124):`aoe_result_field_names 4/0` / `nil_guard 5/0` /
    `activemode 2/0` / `smoke_load 3/0` / `gate_claim 10/0`,**每个退出码都是 `$?` 裸读**;
    静态半 `luacheck_gate.sh` **exit 0 / 0 warnings**(裸读,冷启自己装 `lua-check`),
    **一次都没用过 `RULE6_BYPASS`**。

### 历史
- 2026-08-30T22:56Z(报告 `iterations/reports/hero/20260830T225606Z.md`;轴 **认领 GH #346** ——
  本轮**有**一条带源码证据、点名本组的新 `[hero]` issue(总监 22:14:40Z 开),
  且它正是本组上一轮从 `cmqreach_20260830.known_gap (5)` 交出去的那根棒 ⇒ **走章程工作流第 1 条的主路径,
  不是兜底路径**;**本组下一棒:Silencer(#346 本体,已追评、保持 open)+ 新开的 **GH #348**(Sniper 先索引后判 nil + `.cout`)**)——
  自检 **worst exit 3**,而**那条红不是本轮造成的**:`test_coarmed_attribution_register.lua:319`
  报新 co-armed 合取 `creepthink > pulldrag`(要求写进 `test_set.md` 入集节 + ACKNOWLEDGED)。
  **本 diff 不碰任何 gate、任何 armed id**,该红在动手前就在 `e1e7e02` 上 ⇒ **归属总监/协同组**,本组只登记。
  owner 四条优先项**仍无一条球在本组**(批测台/协同组/协同组/总监)。
  **`bots/BotLib/hero_crystal_maiden.lua` 一处可执行改动;`game/` 零行;
  没有新 gate id、没有 arm/promote/加宽任何已在集的东西;零 AWS(连 S3 GET 都没有);不申请波次。**
  新文件 `tests/test_nil_guard_then_body.lua`(5 例,`[ratchet]`)+ `tests/lua_source_scan.lua`;
  `state.json` 新增 `nilguard_20260830`;`queue.json` **本轮无新增**(非崩溃帧上零行为差 ⇒ 没有可测的东西)。
  - **⭐⭐ 主读数:`or` 短路 ⇒ 唯一可达的缺陷是 then 体那一行索引**;
    **`#346` 里「可以把 nil 传进 `J.GetInLocLaneCreepCount`」是错的,而那句话源出本组自己的
    `known_gap (5)`** —— 已追评更正。
  - **⭐⭐ 第二处更正:`#346` 拿 CM 当健康对照,CM 其实是同一个病人**(多的那句 `targetloc == nil`
    守的是**另一个 nil**,从来没保护过 then 体)。
  - **⭐ 未 gate,理由是等价性不是豁免**:旧代码能跑完的每一帧上新代码留下**逐位相同**的状态,
    差集 = 且仅 = 抛错那一帧;上 gate 等于「在真实对局里继续崩」,且其 (a) **按构造买不到**。
    **一般性裁定(崩溃守卫要不要 gate)已交总监,本组没替全队定。**
  - **⚠️⚠️ 第一版扫描器 53 个命中里 52 个是我自己的缺陷**(头部粘合越过 `then` / body 不在赋值处停);
    修好后**全树 = 2、都是真命中、都逐行读过** ⇒ 断言**放宽到整棵 `bots/`**。
    **差一点签下一份没读过的 53 条白名单。**
  - **⚠️ 这不是 CM 的 nil 安全声明**:`353` 个 `FindAoELocation` 站点里 `350` 个无守卫索引,
    **三个就在 CM 同一个函数里**。
  - **⚠️ 动态半是子集不是全套**(GH #124):`nil_guard 5/0` / `activemode 14/0` / `smoke_load 3/0` /
    `gate_claim 10/0` / `cm_ 194/0`;静态半 0 警告 exit 0,**没用 `RULE6_BYPASS`**。

- 2026-08-30T19:57Z(报告 `iterations/reports/hero/20260830T195757Z.md`;轴 **-43a 的 CM 方向 ——
  被连续四轮各自写下「本轮仍然没动」的那一个**;**本组下一棒:`hero-25` 的域读数回来前不再碰这条线,
  转 backlog -56 里交出去的 Silencer 同族缺陷 / -43a 的 Zeus 方向**)——
  自检 **worst exit 0**(**裸读**,整条命令后台跑进文件再 `cat`,**没有**重演 `| tail` 吃退出码那一形):
  `legs run 8`,`FINDINGS: none`,`UNCERTIFIABLE: none`;
  trunk 两侧全绿(python **62/0/0**;快 Lua 腿 **43** 个 tagged 文件 0 失败,FAST SUBSET);
  stable-v1/v2 锚点 ok。
  ⚠️ 那个 **43** 是**开工那一刻**的读数,**跑在本轮新文件之前**;收尾重跑是 **44/0 red**,
  **44 里包含本轮新文件**。**不要拿 43 和 44 做差** —— 两个数取自不同时刻的取集,
  上上轮(39 vs 36)、上一轮(42 vs 39)已经各绊过一次,这是第三次照实写清楚。
  owner 四条优先项**没有一条球在本组**(批测台/协同组/协同组/总监)。
  本轮**没有带新帧证据、点名本组的新 `[hero]` issue**(#173/#328/#330 是本组前三轮自己的活;
  #309/#311/#314 是等波次的语料读数;#54/#287 等 `hero-22` 那批帧)⇒ 走章程工作流第 1 条的兜底路径。
  **`bots/BotLib/hero_crystal_maiden.lua` 两处可执行改动(新 helper `X.cm_GetCreepAoESearchRange`
  + 一个调用点);`game/` 零行;新 gate id `cmqreach`(turbo-only,未 arm、未 promote、不是 live);
  没有 arm/promote/加宽任何已在集的东西;零 AWS(连 S3 GET 都没有);不申请波次;不开新 issue。**
  新文件 `tests/test_cm_q_creep_aoe_reach.lua`(16 例,`[ratchet]`);
  `state.json` 新增 `cmqreach_20260830`;`queue.json` 新增 `hero-25`;`test_set.md` 新增 §CN(入集提议)。
  - **⭐⭐ 主读数:量的不是一个伤害数,是一个点在不在允许集里。** `FindAoELocation` 的第 4 个参数
    是 `targetloc` 落点的**唯一**约束(`docs/BOT_API_REFERENCE.md:1366`);`X.ConsiderQImpl` 四次搜索里
    两次**英雄**传 `nCastRange`、两次**小兵**传 `nCastRange + nRadius` ⇒ **可施法环 732、找兵环 1157**,
    超出量恰好 `nRadius = 425 = 58.06%`,**不随等级/出装移动**(以太之镜相消,量出来的)。
    四个数从**真实帧上真的 `X.SkillsComplement`** 发出的引擎调用里读回来,不是手填。
  - **⭐⭐ 立案句在消费侧,是一个 5-vs-8**:十三个 `return DESIRE, <结果>.targetloc` 里
    **英雄 5 个全在环内**(4 个自查距离,第 5 个的搜索跑在 `nCastRange - 300`,按构造在内),
    **小兵 8 个一个都没查**;而 `SkillsComplement` 把点**原样**送进 `ActionQueue_UseAbilityOnLocation`。
    普查从源码**解析**,**两个方向都钉了**(加守卫红 M7 / 拿掉守卫红 M8)。
  - **⭐ 「超出会怎样」刻意不主张**(拒绝 ⇒ 空转;走过去 ⇒ 位置 5 往兵线里走 425 码;
    **从 bot VM 问不出来**)。**论据是同一个函数里的英雄分支两种都不肯做**,不是猜哪一种。域走 `hero-25`。
  - **⭐ 缩搜索半径而不是补八个守卫**:补守卫**丢掉**这次施法,缩半径**按构造**给出可施法的点;
    **代价写在门旁边** —— armed 清兵放新星**严格不多于**出厂,**从不挪动一次本来就合法的施法**。
  - **⚠️ 开火侧读数没有,而这个「没有」是量出来的**(两枚 CM fixture 新星都 rank 1,分支要 `>= 3`
    ⇒ 本语料分支人口空,**原因与冷却无关**);**交出去** `hero_silencer.lua:304` 的同族 nil 守卫,
    **只登记不修**(不在焦点五);`X.ConsiderW` 手写的 `100 + nSkillLV * 50` 复核为**不是缺陷**
    (KV 逐位相同,唯一能让它错的天赋在出厂 `t20 = {0,10}` 下不可达,且上一轮已写在文件头)。
  - **变异 8/8 见红且只红在该红的节**,对照 16/0 绿,盘外 `cp` 还原后 `cmp` 逐字节相同。
  - 铁律 6:`luacheck_gate.sh` **exit 0 / 0 警告**(**裸读**,冷启自己装的 `lua-check`);
    `.githooks/pre-push` 在本轮每一次 push 上各跑一遍并放行,**一次都没用过 `RULE6_BYPASS`**。
    动态半是**子集不是全套**(GH #124):快 Lua 腿 44/0、CM 全家 + smoke + gate 一致性 12 文件逐个 exit 0、
    python 全套 **62/0/0**(exit 0 裸读)⇒ **不主张主干全绿**,详见报告 §6。
- 2026-08-30T16:51Z(报告 `iterations/reports/hero/20260830T165112Z.md`;轴 **-43a 的 Lion 方向 ——
  连续四轮各自记着「本轮仍然没动」的那个**;**本组下一棒是 -43a 剩下的 CM 方向**)——
  自检 **worst exit 0**:`legs run 8`,`FINDINGS: none`,`UNCERTIFIABLE: none`;
  trunk 两侧全绿(python **60/0/0**;快 Lua 腿 **42** 个 tagged 文件 0 失败,FAST SUBSET
  —— ⚠️ 这个 42 **跨在本轮新文件上**,**不要跟上一轮的 39/36 做差**,同一个坑上一轮踩过一次;
  好的一面是那 42 **包含**本轮新文件,是它绿的一次独立确认);stable-v1/v2 锚点 ok。
  ⚠️ **自检第一次是没跑成的,不是通过**:`timeout 300` 把它掐了(`Terminated`/143),
  而管道尾巴的 `$?` 让它**看起来像 exit 0**,报告初稿据此写错并已更正 ——
  铁律 10 那半句在**管道退出码**上的同族形态,记在报告 §7.1。
  owner 四条优先项**没有一条球在本组**(批测台/协同组/协同组/总监)。
  本轮**没有带新帧证据、点名本组的新 `[hero]` issue**(#173/#328/#330 是本组前三轮自己的活;
  #309/#314 等语料读数;#54/#287 等 `hero-22` 那批帧)⇒ 走章程工作流第 1 条的兜底路径。
  **`bots/BotLib/hero_lion.lua` 一处可执行改动(新 helper `X.GetImpaleKillDamage` + 一行调用点);
  `game/` 零行;新 gate id `lionqdmg`(turbo-only,未 arm、未 promote、不是 live);
  没有 promote / 加宽任何已在集的东西;零 AWS(连 S3 GET 都没有);不申请波次;不开新 issue。**
  新文件 `tests/test_lion_q_kill_damage.lua`(13 例,`[ratchet]`);
  `state.json` 新增 `lionqdmg_20260830`;`queue.json` 新增 `hero-24`;`test_set.md` 新增 §CM(入集提议)。
  - **⭐⭐ 主读数:这个站点的零是**天花板**。** `lion_impale` 不声明顶层 `AbilityDamage`
    (105/170/235/300 在 `AbilityValues/damage`)⇒ 读数恒 0;而 `J.WillMagicKillTarget` 里
    **`dmg` 只通过 `dmg*(1+GetSpellAmp())` 这一个乘积进入**(前提**从 `jmz_func.lua` 解析出来**,
    出现且仅出现一次)⇒ EstDamage ≤ 0 **在任何增强档下**,对活着的目标恒 false。
    **每个等级、每件装备、每个目标、每一档增强,Lion 的 Q 斩杀分支从来没能开过火。**
    两枚真实帧上驱动**真的** `J.WillMagicKillTarget` 复现(档 0/0.15/0.5/4.0)。
  - **⭐⭐ 代价比「Lion 从不斩杀」窄**:后面每条分支也返回 `DESIRE_HIGH` ⇒ **丢的是覆盖不是欲望**;
    斩杀循环是唯一无 mode/上下文前置的分支,兜底的「常规」要 **`nLV >= 15`** ⇒
    没被覆盖的集合 = **15 级以下 + 不在任一 mode + 面前站着能被秒掉的敌人** = **Turbo 对线期**。
    **预先接受否定结果**已写进 `hero-24` 的 (4) 与 (丙)。
  - **⭐ 上一轮的棘轮响了,是被答的不是被改掉的**:计数**没动**(仍 3,新 helper 把
    `GetAbilityDamage()` 留作出厂落点)⇒ **只数次数的棘轮会被一次合规重构悄悄变成永真**;补了站点断言。
  - **⚠️ 开火侧 fixture 仍欠着,但「欠着」现在是个数**:全语料穷举 = **零开火帧**(增强 0),
    最近差 **45 血**(Luna 345 vs 300 = 13.0%),在**恰好 15%** 增强处越过,
    而天赋技 `lion_to_hell_and_back` 的 KV `spell_amp` = **20**。**限度不是判决。**
  - **⚠️ 明说没做的**:`5.0` 秒延迟(全仓 39 个调用点里**唯一**的裸数字,前摇 0.3)**只登记不修**;
    `ConsiderW`/`ConsiderE` 两个无人读的恒零局部**不动**,只钉成「无人读」;不主张 promote;
    **CM 方向本轮仍然没动**。动态半是**子集不是全套**(GH #124),跑了五个子集,照实登记。
- 2026-08-30T13:55Z(报告 `iterations/reports/hero/20260830T135500Z.md`;轴 **backlog -50 明写留下、
  -51/-52/-53 逐轮抄写而没动的那条棒 —— `abilityASBonus` 的第二个消费方 `X.ConsiderW`**;
  **本组下一棒仍是 -43a 的 Lion / CM 两个方向**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  trunk 两侧全绿(python **58/0/0**;快 Lua 腿 **39** 个 tagged 文件 0 失败,FAST SUBSET
  —— ⚠️ 这个 39 **跨在本轮新文件上**(自检开头起、快 Lua 腿跑到时新文件已写好),
  **不要拿它跟上一轮的 36 做差**,两个数还来自不同取集;裸
  `grep -l '[detector]\|[ratchet]' tests/test_*.lua` 此刻是 **36**,含本轮新文件。
  新文件是否绿**单独验过**:14 例 0 失败);stable-v1/v2 锚点 ok。
  owner 四条优先项**没有一条球在本组**(批测台/协同组/协同组/总监)。
  本轮**没有带新帧证据、点名本组的新 `[hero]` issue`**(#173/#309/#311/#314/#328/#330 前四轮已各自结清或退回)
  ⇒ 走章程工作流第 1 条的自选路径。
  **`hero_zuus.lua` 只改注释块、零可执行行;`game/` 零行;无新 gate id;
  `zusstatic`/`zusbind`/`zusboltcap` 的门与 armed 状态一字未动(三个都仍 gated、未 promote、不是 live);
  零 AWS(连 S3 GET 都没有);不申请波次;不开新 issue。**
  新文件 `tests/test_zuus_static_field_second_consumer.lua`(14 例,`[ratchet]`);
  `state.json` 新增 `zusstatic_SECONDCONSUMER_20260830`;`queue.json:hero-15` 新增
  `acceptance_amendment_hero_20260830_second_consumer`(退休上一份订正的 (己) 条)。
  - **⭐⭐ 主读数:第二个消费方的域是**空的**,而且目标血量被约掉了。** `:795` 的平伤项
    `abilityW:GetAbilityDamage()` 是**被证明过的零**(GH #175 普查:`zuus` 不在 `NONZERO` 里;
    雷击的 140/220/300/380 住在 `AbilityValues/damage`)⇒ `h < m*(D + h*b)` 塌成 **`1 < m*b`**
    ⇒ **每个创兵、每个血量、每个 rank 都为假**。**不是变悲观的击杀估计,是与血量无关的常数。**
  - **⭐⭐ 天花板不是余量**:平衡点 `b ≥ 1/m ≥ 1.0`(静电场要打掉当前血量的 **100%**);
    出厂 0.09 差 **11.1×**,armed KV 带差 **20.2–29.0×** ⇒ **arm 或退回 `zusstatic` 都动不了它**。
  - **⭐ 预登记双向被推翻**:两站点代数同形 ⇒ `W(D) = m*D*[1/(1-m*b_出厂) − 1/(1-m*b_armed)]`,
    **只正比于 D**;反事实里这条带 = 大招那条的 **0.24×–1.38×**(**同一个量级**),
    绝对值 **4.81–24.00 HP**(amp=0)。-50 的「宽一个量级」**定价了错的量**。
  - **⭐ 买到的位置 + 绳子**:**今天** ConsiderR 那份读数**就是整个 id**(`hero-15` 的 (a) 没漏东西);
    **但 `zuus` 一旦有非零 `AbilityDamage`、或 `:795` 不再读 `GetAbilityDamage()`,第二个消费方重开、
    (a) 无声地不再覆盖整个 id** ⇒ §6 是绊线,**这是带 `[ratchet]` 的全部理由**。
  - **⭐ 更正两句**(`hero_zuus.lua:819` + `test_zuus_bolt_kill_cap.lua:47-49`):
    `J.WillMagicKillTarget` 在本文件**只有一个调用点且在 `X.ConsiderR`**;`:795` 的估值**不是零**
    (仍带 `h*b`),零抽掉的是**尺度**。**结论活下来,缺陷的形状没有**(#328/#330 同族)。
    绊线口径是「退休句只能出现在 `CORRECTED` 标记之下」而**不是**「一律不许出现」(-52 的教训)。
  - **⚠️ 未答的照实说**:「这条腿多久被**走到**」没答也没试着答(**本语料零 fixture 带线上兵**);
    `m` 阶梯是声明的不是实测的,但**结论不需要 `m`**;**Lion / CM 本轮仍然没动**。
  - 变异 **8 条条条见红且只红在该红的节**,对照 14/0 绿,盘外 `cp` 还原后四份 `cmp` 逐字节相同。
  - **⚠️⚠️ 本轮自己造了一次 trunk 红并在同一轮修掉,照实记**:第一次 push 后全量套件在
    `test_incoming_damage_callsite_census.lua:228` 见红 —— §6 的更正块里点名了
    `GetActualIncomingDamage`,而那个普查数的是 `bots/` 下**提到该标识符的行**(`grep -c`)⇒ 42 → **43**。
    **移动全在 prose 一侧**(注释行 2→3),**代码行 40、调用数 41 一个没动** ⇒ 普查表零行移动、零 class 改变。
    按失败文本三处一起更新(`tests/mock/bot_api.lua` 头 + 该测试 published 42→43 + `state.json`
    `census_20260829_follow_up`),**而不是去删那句正确的话**。修复后 census 6/0、新文件 14/0、
    `test_zero_true_sites_driven` 6/0、`test_zuus_bolt_kill_cap` 11/0、`test_smoke_load` 3/0。
    **一句教训:本组近几轮的产出形态是「只改注释、零可执行行」,而注释也会踩静态普查 ——
    「零可执行行」不等于「零 trunk 风险」。**
  - 铁律 6:`luacheck_gate.sh` **0 警告 exit 0**(冷启自己装的 `lua-check`);
    `.githooks/pre-push` 在本轮**每一次** push 上各跑一遍并放行,**一次都没用过 `RULE6_BYPASS`**。
    **全量套件本轮没跑完** ⇒ **不主张主干全绿**,详见报告 §10 / §11。
  - GH #173 追评**先 push 后发**(GH #290):`claim_precheck.sh` **exit 0**、
    `local commits not on origin/main: 0`、`paths cited 9 / resolved 8 / refused 0` ⇒
    https://github.com/dragonghy/dota2bot/issues/173#issuecomment-5469107312
- 2026-08-30T10:55Z(报告 `iterations/reports/hero/20260830T105510Z.md`;轴 **GH #330 —— 录像组把
  `odbuild` 条件 (a)=WORKING 落地并把「更正那句源码注释」明写为英雄组的下一棒**;
  **本组下一棒仍是 -43a 的 Lion / CM 两个方向**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  trunk 两侧全绿(python **56/0/0**;快 Lua 腿 **36** 个 `[ratchet]` 文件 0 失败,FAST SUBSET
  —— 这个 36 是**开工那一刻**的读数,跑在本轮新文件之前、也跑在协同组 10:38Z 把计数订正到 **37**
  的 `943978af` 之前;本轮新增的 `[ratchet]` 文件**不在这 36 里**,下一轮才被读到);
  stable-v1/v2 锚点 ok。owner 四条优先项**没有一条球在本组**(批测台/协同组/协同组/总监)。
  **`hero_obsidian_destroyer.lua` 只改注释块、零可执行行;`game/` 零行;无新 gate id;
  `odbuild` 的门与 armed 状态一字未动(仍 gated、未 arm、未 promote、不是 live);
  零 AWS(连 S3 GET 都没有);不申请波次;不开新 issue。**
  新文件 `tests/test_od_levelup_double_spend.lua`(8 例,`[ratchet]`);
  `state.json` 新增 `odbuild_DOUBLESPEND_20260830`;`queue.json:hero-22` 追加本组读数。
  - **⭐⭐ 主读数:出厂注释那句「either way the point is not lost」不是不精确,是把缺陷形状搞反了。**
    `ability_item_usage_generic.lua:351` 取 `sAbilityLevelUpList[2]`、弹**队首**、给第二项升级
    **却不弹它** ⇒ **双花**:队列推进 1 项、等级推进 2 级 ⇒ astral 提前一项满级 ⇒ 下一次 astral
    请求越级 ⇒ 末尾 `else` **驻留**不跳过(`table.remove` 被 `botLevel > 25` 挡着)⇒
    **英雄在 7 级、6 点之后彻底停止升级**。
  - **⭐⭐ 两个「离线判不了」的选言各被 W28 的帧关掉一个**:第 3 点上 astral 已 rank 2
    (只有 `:351` 造得出,1:1 模型给 rank 1)⇒ 句柄存在;**驻留**世界复现语料、**弹掉**世界不复现
    (16 点、25 级还在花)。
  - **⭐ 出厂 spender × 出厂队列独立命中 W28 的两个数(6 点 **和** 7 级)**,armed 行给出
    orb4/astral4/objurgation4/sanity3 ⇒ 成本改写成 **~10 技能点 + 全部天赋点**(冻结 80–84%,4/4 腿;
    同局另外九个英雄 15–19 点)。「objurgation 停 0 级」没撤回,只是较小的一半。
  - **`hero-22` 的 `status` 本组不动**(前置门是总监抬上去的,**GH #331** 正在请总监裁);
    `returned_uninterpretable` 按 GH #317 **是 open**,棒不会掉。**本组不主张 promote。**
  - **⚠️ 第二个缺陷交出去**:armed 腿模型预测 19 点、W28 读 16 ⇒ **3 个天赋点**丢在一条
    **零 placeholder** 的腿上,`odbuild` 碰不到 ⇒ **#330 的「冻结 5–24%」不许读成 odbuild 的残留**。
  - 变异 **7 条条条见红且只红在该红的节**,对照 8/0 绿,盘外 `cp` 还原后三份 `cmp` 逐字节相同。
  - 铁律 6:`luacheck_gate.sh` **0 警告 exit 0**;`.githooks/pre-push` 在两次 push 上各跑一遍并放行,
    **没有用过 `RULE6_BYPASS`**。全量套件见报告 §10。
- 2026-08-30T07:50Z(报告 `iterations/reports/hero/20260830T075007Z.md`;轴 **GH #328 —— 录像组把
  `hero-20` 读数落地并把 WK t25 的定价交回本组**;**`hero-20` 结案不再复议,本组下一棒仍是 -43a 的
  Lion / CM 两个方向**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  trunk 两侧全绿(python **55/0/0**;快 Lua 腿 **35** 个 `[ratchet]` 文件 0 失败,FAST SUBSET);
  stable-v1/v2 锚点 ok。owner 四条优先项**没有一条球在本组**。
  **`hero_skeleton_king.lua` 只改注释块、零可执行行;`game/` 零行;无新 gate id;
  没有 arm/promote/加宽任何东西;`tTalentTreeList` 一字未动;零 AWS(连 S3 GET 都没有);
  不申请波次;不开新 issue。**
  新文件 `tests/test_wk_t25_reincarn_pricing.lua`(7 例,`[ratchet]`);
  `state.json` 新增 `wkt25_REPRICE_20260830`;`queue.json` 的 `hero-20` 置 `done`。
  - **⭐⭐ 主读数:源码自己写给自己的那句「if that number turns out high, [8]'s case improves and
    this row should be re-priced」被测掉了。** [8] 毛 = **0.408 × 0.650 = 0.265 人/局**(且是毛的);
    [7] 同窗口(均值 **208s**,n=49)= `208/3 − 208/5` = **+27.7 次暴击机会**(f=1)⇒
    **f=1 时 ≈105×、f=0.25 时仍 ≈26×,符号整条带上不翻**。
  - **⭐⭐ 更强的一句:[8] 够不到平衡点。** 平衡需 T=42.6(f=1)/10.7(f=0.25),
    而 110s 冷却给出物理上限 **2**(均值窗)/ 5(语料最长窗 453s),**实测最大值恰是 2** ⇒
    **是天花板关的门,不是样本量**。上限用更小的 110 而非 KV 120(对 [8] 有利的方向)。
  - **⭐ #328 没 settle 的第 (4) 条被仓库自己的参数解释掉**:`special_bonus_scepter = -10` +
    两条 buy row 都有 `item_ultimate_scepter` ⇒ 120−10=110;rank1 179 / rank2 149–150 正是未出杖的
    KV 180 / 150。**解释不是确认。**
  - **四条事实改正**(25 级 60/96=62.5% / 窗口 n=49 / 三条件权重排错 —— 稀缺的是触发本身 /
    冷却 120→109-110),另**照实记下被证伪的预登记结局**:半径优势**是真的**(全语料 delta 0.789),
    只是小。
  - **⚠️ 撤回棘轮第一版红在一个正确的文件上**(本仓库靠**引用原句**来更正)⇒ 改成
    「只能在更正块内且同口气带划除标记」,**块外仍一律红**。
  - **⚠️ `wk_reincarn_trigger_domain.py:6/:278` 的 `:412-417` 指路会因本轮变长而不精确** ——
    录像组的文件,**§AW.1 不代改**,#328 追评点名(GH #221 同族)。
  - 变异 **7 条条条见红且只红在该红的节**,对照 7/0 绿,盘外 `cp` 还原后两份 `cmp` 逐字节相同。
  - 铁律 6:`luacheck_gate.sh` **0 警告 exit 0**;`.githooks/pre-push` 在两次 push 上各跑一遍并放行,
    **没有用过 `RULE6_BYPASS`**。**全量套件本轮没跑完**(GH #124:收尾时 7m13s / 977 例 / 0 FAIL,
    进程仍在跑)⇒ **不主张主干全绿**,详见报告 §8。
  - GH #328 追评**先 push 后发**(GH #290):`claim_precheck.sh` **exit 0**、
    `local commits not on origin/main: 0`、`paths cited 7 / resolved 7 / refused 0` ⇒
    https://github.com/dragonghy/dota2bot/issues/328#issuecomment-5467501742
- 2026-08-30T04:5xZ(报告 `iterations/reports/hero/20260830T045500Z.md`;轴 **卡住 `hero-2` 的那个
  已发表的封锁数字**;**本组下一棒仍是 -43a 的 Lion / CM 两个方向**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  快 Lua 腿 **34** 个 `[ratchet]` 文件 0 失败(FAST SUBSET);stable-v1/v2 锚点 ok。
  owner 四条优先项**没有一条球在本组**;open 的 `[hero]` issue(#173/#309/#311/#314)
  本组前四轮已各自结清或退回,**本轮没有带新帧证据的 [hero] issue** ⇒ 走章程工作流第 1 条的自选路径。
  **`bots/`/`game/` 零行改动;无新 gate id;没有 arm/promote/加宽任何东西;
  零 AWS(连 S3 GET 都没有);不申请波次;不开新 issue。**
  新文件 `tests/test_axe_culling_band_power.lua`(10 例);`test_axe_culling_threshold_preflight.lua`
  加**纯注释**前向指针;`state.json` 新增 `hero2_BANDPOWER_20260830`;
  `queue.json` 的 `hero-2` 新增 `acceptance_amendment_hero_20260830`。
  - **⭐⭐ 主读数:挡了 `hero-2` 八天的那条算式没错,错在它定价的人口。** preflight 的
    `band/health_pool`(25/~1000 ⇒ 要 ~40 帧)是**池模型**。本轮用仓库语料复现了它
    (中位血池 **1131**,n=96 ⇒ **45.2 帧/命中**,与 "roughly 40" 对得上)。但敌人是
    **从上方穿过**带的 ⇒ p = min(1, band/(v·dt)),**没有血池项**。
  - **⭐ v 是语料自己的真值**(`observed.burst`,58 枚,中位 **58.3 HP/s**、最大 360)⇒
    **2.3 次穿越/命中**(中位)、**14.4 次**(最快)⇒ 比随机帧人口效率 **19.4× / 3.1×**。
  - **⭐⭐ 收回半句**:答不了它的是 **fixture 库**(孤立瞬间,**按构造零穿越**);
    **归档 1 Hz 时间线能答**,口径换成「穿越」即可 ⇒ **`hero-2` 不依赖 GH #310**
    (#310 对逐次施放核验必需,对域的定量不必需)。已订正进 `queue.json:hero-2` 并预登记
    量级期望 ≈0.43·N(**上界**,不得读成「这么多就够」)。
  - **第一顺位障碍不变**:归档里 **Axe 0/306 局**(批测台 08-23),GH #46 `--find axe → 899/910/911`。
  - **⭐ 真实帧**:`f_260820_043637_axe_ring_close` 换 subject 成 Axe,真的 `X.ConsiderR` 返回
    `HIGH`+skywrath(221/940、188u、rank1 cd0)。**证明机制不证明缺陷**(221 在出厂门槛以下,
    两个门槛都开火)。
  - **⭐ 方向守卫**:两条 ladder 都解析而非重打;断言**漂移方向** —— 常数由「低 25(少打一次击杀)」
    翻成「高」的那天当场见红,因为那时是**把 80 秒大招喂给活下来的目标**,更糟且无声。
  - **⚠️ 未量**:`X.ConsiderW`(-50 留的棒)本轮没动;rank 3 的带 (450,475] 与 t25 天赋
    **语料里一帧都没有**。
  - 变异 **6 条条条见红**(7/5/1/1/1/1),对照 10/0 绿,盘外 `cp` 还原后 `cmp` 逐字节相同。
    **M1/M2 红 7/5 条是设计使然**(带宽是所有定价用例的共同输入),照实记不修剪。
  - 铁律 6:`luacheck_gate.sh` **0 警告 exit 0**(冷启自己装的 `lua-check`);
    `.githooks/pre-push` 在**三次 push 上各跑一遍并放行**(feature 分支 ×2 + `HEAD:main`),
    **没有用过 `RULE6_BYPASS`**。**全量套件本轮没跑完**(24 分钟 1103 例 0 FAIL,进程仍在跑)
    ⇒ **不主张主干全绿**,详见报告 §8。
  - GH #310 追评**先 push 后发**(GH #290):`claim_precheck.sh` **exit 0**、
    `local commits not on origin/main: 0`、`refused 0` ⇒
    https://github.com/dragonghy/dota2bot/issues/310#issuecomment-5466891526
- 2026-08-30T01:54Z(报告 `iterations/reports/hero/20260830T015421Z.md`;轴 **`test_zuus_static_field_pct.lua:337`
  本组 08-29 自己留下的 firing-side fixture 那条棒**;**Zeus 这一格结清,本组下一棒仍是 -43a 的 Lion / CM 两个方向**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  trunk 两侧全绿(python **53/0/0**;快 Lua 腿 **33** 个 `[ratchet]` 文件 0 失败,FAST SUBSET);
  stable-v1/v2 锚点 ok。owner 四条优先项**没有一条球在本组**。
  **`bots/`/`game/` 零行改动;无新 gate id;`zusstatic`/`zusbind` 的门与 armed 状态一字未动
  (仍 gated、不是 live);零 AWS(连 S3 GET 都没有);不申请波次;不开新 issue。**
  新文件 `tests/test_replay_260820_zuus_static_band.lua`(15 例,`[hero]`);
  `state.json` 新增 `zusstatic_BAND_20260830`;`queue.json` 的 `hero-15` 新增
  `acceptance_amendment_hero_20260830`。
  - **⭐⭐ 主读数:归档语料里有一帧,交不交 ~130s 全图斩杀只由写死的 `0.09` 决定。**
    `f_260820_103216_cm_es_aftershock`(t=473.5,`rf.load` 换 subject 成 Zeus):9 级 Zeus、
    大招 rank 1 **cd 0**、566 蓝对 250 花费;敌方 CM **292/1110 血**、268u、被晕,
    且过去 3.8s **Zeus 已打了她 9 次(合计 588)**。出厂 `275+292×0.09 = 301.28 ≥ 292` **开火**;
    KV 3.85% 得 `286.24 < 292` **不开火**。**端到端**:真的 `X.SkillsComplement()` 出厂腿把
    `zuus_thundergods_wrath` 放进动作队列,armed 腿不放。
  - **⭐ 与 `hero_levelup` 怎么折无关**:该帧盈亏平衡是 **5.82%**,整条 KV 带 [3.45, 4.95]
    在它下面、出厂 9% 在它上面 1.55 倍;31 个刻度逐个推进真的 `J.WillMagicKillTarget`。
  - **⭐⭐ 两腿都要 arm `zusbind`**:离线 `sAbilityList[5]` 是 nil ⇒ 不 bind 时**两腿 bonus 都是 0**,
    要比的差不存在。这才把 GH #173(百分比)与 GH #175(句柄)分开。
  - **⚠️ 实测 LIMIT(必须连着引)**:mock **不建模减免**。带是 `hp ≤ nDamage/(1/m − bonus)` ⇒
    rank-1 时 m=1.00 为 (286, 302]、m=0.75 为 (212, 221],**只有 nDamage 的几个百分点宽**。
    普查 **37 枚**大招已点的 Zeus fixture / **167** 个 (帧, 活敌) 对:**m=1.00 落 1、m=0.75 落 0**,
    两个数都钉成断言。**0 不是「永远够不着」**,条件 (a) 仍要从波里买。
  - **不受量具影响的一半**:`GetHealth()*bonus` 恒 ≥ 0 且 armed 只调低 ⇒ **armed 开火集合恒是出厂的子集**
    (5 活敌 × 31 刻度驱动验证)。
  - **⭐ 交棒**:`hero-15` 订正写入带宽这条**预登记量级期望** + 「差值小 ≠ 测过了没效果 ≠ 域为零」
    (分母:局 vs 施放事件)+ 一项零成本读数(带内施放占比)。**不动 director 键。**
  - **⚠️ 未量的另一半**:`X.ConsiderW`(远程兵斩杀)是同一常数的第二个消费方,**本轮没量**,
    带在创兵血量尺度上、可能宽一个量级,且**不需要新语料** ⇒ 已写进 backlog -50。
  - **⚠️ Lua 陷阱**:`s:sub(s:find(pat,1,true))` 因 `find` 返回两值而变成 `sub(start,stop)`,
    **绊线红在一个完全正常的文件上**;加括号截断。**自证式绊线红了先查绊线自己的取值。**
  - 变异 **6 条条条见红且只红在该红的节上**(4/2/6/7/2/2),对照 15/0 绿,盘外 `cp` 还原后三份 `cmp` 逐字节相同。
  - **⭐ 全量套件跑完了:`2574 tests, 0 failures`,exit 0**(含本轮新增 15 例)。
  - **⚠️⚠️ 本轮报告有一节写反过,订正与教训都在 §全量套件里,值得读**:收尾稿一度写成
    「没跑完(1h08/1253 例),外推约 2h17m」,并据此「纠正」上一轮那句「22 分钟跑完」说它只是快容器。
    **两句都已撤回** —— 套件跑完了,而那个外推**是拿一个不能用的墙钟做的**:
    **本轮容器中途被挂起过**(写报告名时 `date -u` 是 **01:54:21Z**,收尾时是 **10:25:45Z**,相隔 **8h31m**,
    而同期那个进程的 `ps ELAPSED` **只走到 1h09m**)⇒ **`ps ELAPSED` 与 `date` 在被挂起的容器里
    都不是运行时长**。**本轮对 GH #124 的墙钟问题贡献零个可用数据点**;上一轮那 22 分钟
    **既没被证实也没被推翻**。
  - **⭐ 可推广的收窄(这一条是本轮真正买到的第二样东西)**:原稿**引了 GH #216 那条规则,
    然后当场违反它** —— 规则挡的是「没输出=坏了」,挡不住「有部分输出=可以外推」;后者额外要
    **均匀速率 + 可信墙钟**,本轮两个都不成立。⇒ **部分进度只能证伪(见到 `FAIL` 就是真红),
    不能用来给未完成的部分定量。** 与 −47「措辞 ratchet 会禁掉它自己的修复」同族:
    **引用一条纪律不等于遵守了它。**
  - 铁律 6 过的其余门:`luacheck_gate.sh` **0 警告 exit 0**;`.githooks/pre-push` 在
    **四次 push 上各跑一遍并放行**(两个 commit × feature 分支 + `HEAD:main`),**没有用过 `RULE6_BYPASS`**。
  - GH #173 追评**先 push 后发**(GH #290):`claim_precheck.sh` **exit 0**、
    `local commits not on origin/main: 0`、`refused 0` ⇒
    https://github.com/dragonghy/dota2bot/issues/173#issuecomment-5466212669
- 2026-08-29T23:00Z(报告 `iterations/reports/hero/20260829T230000Z.md`;轴 **GH #309 §一
  ——`hero-22` 的前置门**;**门跑了没过,`hero-22` 已退回;本组下一棒仍是 -43a**)——
  自检 **exit 0**;stable-v1/v2 锚点 ok。owner 四条优先项**没有一条球在本组**。
  **`bots/`/`game/` 零行改动;无新 gate id;`odbuild` 的门与 armed 状态一字未动
  (仍 gated、未 arm、不是 live);零 AWS(只有 S3 GET);不提批测请求。**
  新文件 `tools/batch_test/behavioral/od_stall_leg.py`(`--selfcheck` **12/12**);
  `state.json` 新增 `odbuild_PREGATE_20260829`;`queue.json` 的 `hero-22` 置
  `returned_uninterpretable`。
  - **⭐⭐ 主读数:前置门 FAIL。OD 仍在 STALL 表 —— W25 树 `b51bac77` 的 12 份 `.dem` 里
    9 局有 OD,**4/9 是 STALL**(英雄 19–23 级、**6 个技能点**、`objurgation` 一级没点、
    冻结 78–83%)。⇒ 按登记分支 **`hero-22` = UNINTERPRETABLE,退回**,
    `odbuild` 的 W25 波读数**不得引用**。这一条**不依赖任何腿间比较**。
  - **⭐⭐ 一行算术买到的更硬的东西(已开 GH #320,归 harness)**:armed 行
    `{2,1,3,2,2,6,...}` 的**第三点就是 objurgation** ⇒ 跑了 armed 行的局英雄 3 级起
    rank ≥1。而 `20260829_124418` 盖章 `s1603:radiant`、**OD 就在 armed 侧**,
    却收在 objurgation **rank 0** 且技能表与出厂行预测**逐位相同**
    ⇒ **那一局跑的是出厂行,而它自己的章说它 armed**。不是部署顺序:
    同 run/种子/侧的**前一局**到了 rank 4。**它约束的是每个 id 的 armed 腿有多少真 armed。**
  - **`odbuild` 条件 (a) = 部分 WORKING,未买到**:3/4 armed 局 objurgation 到 rank 4
    (出厂行产不出)⇒ 机制在真实帧上看见了;但门没过 + 第 4 局与章矛盾 ⇒
    **不登记 (a),不登记任何效应量**(n=9,OD 上**没有** ab/ba 两层,
    `ARMED 1/4 vs baseline 2/2` **不许**读成 odbuild 降低了 stall)。
  - **⚠️ 我自己先踩了一次**:第一版拿队伍 id(引擎 2/3)去比章里的字符串,
    **每一行都读成 baseline** 且表面合理;是那行算术捅破的。selfcheck 第 1 例现在钉住它。
  - **⚠️ 三条记录不代改**:(i) 录像组 16:19Z 报告称 W25「dem-backed 90 局」,而
    `replays/` 下带该树全 sha 的 `.dem` **只有 12 份**(全天四棵树共 52 份);
    (ii) `state.json:odbuild_20260829` 说 #290 item 1「落地于 `8cf5ae0c`」——
    **该 commit 不是 origin/main 的祖先**,同内容经 `f13ada65` 进 main,**确在 W25 树里**;
    (iii) **`CompactSkillList` 在 W25 树里在,却没挡住这 4 局** —— 其守卫要 `[1] == nil`,
    而 OD 这条路上 `[4]` 解析出的是 **`generic_hidden` 这个真名字**,守卫**结构上够不着**。
  - **不主张**:出厂行为什么能收在 rank 0 **以外**(两局 WARMUP 是 3 和 4)——
    离线分不开「门为假」与「第二条路改写 build」,**记为 OPEN 写进 #320,两个方向都不认**。
- 2026-08-29T19:49Z(报告 `iterations/reports/hero/20260829T194937Z.md`;轴 **GH #314
  ——`liondrainstop` 那 2 条没释放的 channel**;**#314 的候选 1/2 结清并把棒交给 harness 侧,
  本组下一棒仍是 -43a**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  stable-v1/v2 锚点 ok;**trunk 两侧全绿**(python **53/0/0**;快 Lua 腿 **29** 文件 0 失败,
  FAST SUBSET,不是全量)——上一轮记的 #302/#295/#296/#301 在本轮自检里已不复现。
  owner 四条优先项**没有一条球在本组**(常设运维→批测台,P1/P2→协同组,P3→总监)。
  **`bots/`/`game/` 零行改动;无新 gate id;`liondrainstop` 的门与 armed 状态一字未动
  (仍 gated、未 promote、不是 live);零 AWS;不提批测请求;不开新 issue(在 #314 追评)。**
  新文件 `tests/test_lion_drainstop_vision_domain.lua`(8 例,`[detector]`);
  `state.json` 新增 `liondrainstop_VISION_DOMAIN_20260829`(`gated:false`)。
  - **⭐⭐ 主发现:检测器谓词全知,门的谓词不全知。** `#J.GetNearbyHeroes(500)>0` 展开到
    `Utils.IsValidUnit` 是 **`CanBeSeen()` + `IsAlive()` + `not IsInvulnerable()` 三条**;
    `lion_drain_census.py` 的域循环只读**距离 + hp>0**。真实帧上**只翻一个字段**
    (`CanBeSeen`)就让 `ShouldStopDrain` true→false,而**检测器侧读数逐字节不变**
    ⇒ #314 那 2 条与「雾」在当前语料上**不可区分**。
  - **⭐⭐ issue 提议的验收判不了它**:dumper 不写 `vis` ⇒ **107 枚 fixture 带 `seen_by` 的 = 0**
    ⇒ `CanBeSeen()` **按构造恒真** ⇒ 钉 t=200.4 断言 `ShouldStopDrain == true` **必绿,
    而那个绿是量具给的**(-45 的 `ZERO_TRUE` / GH #306 原样重演,换了个 mock 数据)。
  - **⭐ 候选 2 算术排除**:唯一节流上界 **<0.16s** vs residual **3.7s / 1.8s**,差一个数量级以上。
  - **不推翻 (a)=WORKING**:全知谓词两条腿一起抬高,分裂不受影响;
    站不住的只是**在排除雾之前把那 2 条叫缺陷**。
  - 变异 **7 条条条见红且只红在该红的节上**,对照 8/0 绿,盘外 `cp` 还原后 `cmp` 逐字节相同。
  - **⭐ 全量套件跑完了:`2527 tests, 0 failures`,exit 0,墙钟约 22 分钟**——
    **与 GH #124 的「跑不完 / ~100min」不符,记录不代改**;引用那句话前先自己跑一次。
    (本轮报告 §8 初稿抢跑写成「没跑完」,已订正:块缓冲下的空输出不是进度也不是结论。)
- 2026-08-29T16:49Z(报告 `iterations/reports/hero/20260829T164950Z.md`;轴 **GH #311
  ——「`wkqdmg` 的域注释把方向说反了」**;**#311 结清并可关闭,下一棒仍是 -43a**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: unlanded cadence`,`UNCERTIFIABLE: none`;
  stable-v1/v2 锚点 ok;trunk python 52/0、快 Lua 腿 **28** 文件 0 失败(FAST SUBSET,不是全量)。
  owner 四条优先项**没有一条球在本组**(常设运维→批测台,P1/P2→协同组,P3→总监)。
  **`bots/` 只有注释改动(三处)、`game/` 零行;无新 gate id;`wkqdmg`/`wkbuild` 的门与
  armed 状态一字未动(仍 gated、未 arm、不是 live);零 AWS;不申请新波次;不开新 issue。**
  新文件 `tests/test_wk_qdmg_domain.lua`(6 节 7 例,`[ratchet]`);
  `state.json` 新增 `wkqdmg_DOMAIN_20260829`(`gated:false`)+ 订正 `wkqdmg_20260829`;
  `queue.json` 订正 `hero-23` acceptance (3)。
  - **⭐⭐ 主发现:行内下标 12 是英雄 13 级** —— 出厂行下 Q 的第二点落在**英雄 13 级**
    (10/15/20/25 是天赋位,不花技能点,GH #134),所以 t10 天赋降临时 **Q 还是 rank 1**:
    差距从 48 **收窄**到 8,**不是打开**;**13 级起本杠杆逐字节 no-op**。
    域 = **英雄 2–12**(48 / 8 / 0)。90 局真实帧一致。两个梯子都**驱动**自真的
    `J.Skill.GetSkillList`,不是重打的数。
  - **⭐ 连 issue 自己的推断也订正了**:`wkbuild` armed **不是**「域前移到 5 级」——
    rank 梯子只是域的一半,**dot 时长是另一半**;英雄 5–9 仍在域内且**收得更多(55.2>48)**,
    armed 拿走的是**顶**(no-op 底线 13→10)⇒ **两条同波 armed 时不独立,读数必须分层**。
  - **⭐ 棒已交出**:`hero-23` acceptance (3) 就地订正(原文方向相反,而 W25 已收割 GH #309、
    判读就在下游):前置门问「有没有**英雄 2–12 级**的 Q 施法」,**13 级以上单独剔出**。
  - **⚠️ 教训:措辞 ratchet 会禁掉它自己的修复**(两次红在我自己刚写的注释上)⇒
    主语是断言的 ratchet 必须钉在**断言被作出的地方**,退休原句交给 issue 逐字保存。
  - 变异 **6 条条条见红且红在该红的节上**(3/3/1/1/1/4),对照 7/0 绿,还原 `cmp` 逐字节相同。
  - **⚠️ 全量套件没跑完**(GH #124)。trunk 已知红(#302 / #295 / #296 / #301)**都不是本轮的**。
- 2026-08-29T13:50Z(报告 `iterations/reports/hero/20260829T135016Z.md`;轴 **backlog -45:
  上一棒明确交出来的驱动核验**;**-45 结清,-46 记下纪律,本组下一棒回到 -43a**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  stable-v1/v2 锚点 ok;trunk python 52/0、快 Lua 腿 26 文件 0 失败。
  owner 四条优先项**没有一条球在本组**(常设运维→批测台,P1/P2→协同组,P3→总监)。
  **`bots/`/`game/` 零行改动;无新 gate id;零 AWS;不提批测请求;入集队列本轮无新增待裁 id。**
  新文件 `tests/test_zero_true_sites_driven.lua`(6 节,`[detector]`);
  订正两处已发表说法(`tests/mock/bot_api.lua` 头注、普查头注)+
  `state.json:mockdmg_ZERO_20260829.driven_20260829_follow_up`。
  - **⭐⭐ 主发现:那次量具修复在 fixture 帧上一个绿都没变红。** 普查读的极性**是对的**
    (§2/§5 用真实帧 + 真实模块驱动坐实:旧的 0 就地复原 ⇒ 退撤恒 0.9、下颚恒 `DESIRE_HIGH`;
    修好的默认值 + 足够的伤害 ⇒ 两边都拒绝,且伤害真不够时仍然开火),
    **但两个站点各自还有一个上游的 0,而它属于量具不属于帧**:
    退撤那侧是**主角自己的** `GetEstimatedDamageToTarget` 恒 0
    (loader 只有 `observed.burst` = 敌人打到主角,**没有主角打出去的任何来源**),
    下颚那侧是每个敌人的 `GetAttackDamage`/`GetAttackSpeed` 恒 0。
    ⇒ **「断言这一帧退撤欲望 0.9 可能是在读 mock」今天仍然成立**,只是发绿的那个 mock 数据换了一个。
    **引用这两条路径前,必须像 §2/§5 那样先把上游数据声明出来。**
  - **⭐ 站点 A 的域只有两帧宽**(107 枚里):`f_260820_043124_axe_blink_flee_529`(285u,t=529.6)、
    `f_260820_102030_wk_tower_in_reach`(787u,t=444.5),**都是焦点五**;
    最近的那枚塔(212u,`f_260820_163429_es_blink_init_621`)**被时钟挡掉不是被几何**(t=621)。
    §1 是存在性 + 下限,不是等号(GH #273 的形状)。
  - **⭐ §7 是自动到期装置**:两个上游 0 钉在源码行上,**谁把其中任何一个建模了本文件当天打红**,
    红的信息直接写「这是好消息,并且它作废本条断言:去重读所有已发表的相关说法」。
  - **变异 4 条条条见红且红在该红的节上**(mock 默认值回滚 2 红=**两个驱动节**,而 §3/§6 **保持绿**,
    那个绿本身就是主发现;`< 0.88` 翻号 2 红;loader 给输出估计 2 红;mock 加 `GetAttackDamage` 默认值 2 红);
    对照 6/0 绿。变异还原走**盘外备份 + `cp`**,`md5sum` + `git status` 双证。
    luacheck `bots game` **0 警告 exit 0**,**未用 `RULE6_BYPASS`**。
  - **⚠️ 全量套件到收尾仍在后台跑**(GH #124)。**不要把本条读成「全量套件绿」。**
    trunk 上另有 GH **#302**(8 红 / 3 文件)与 **#295**,**都不是本组的**,本轮一字未动那三个文件。
  - **⚠️ 散文版 GH #221,记录不代改**:`test_pingstamp_world_assertion.lua:57`、
    `test_itemdesire_world_assertion.lua:60`、`test_relicguard_siege_gate.lua:269` 三处按行号引用
    `tests/mock/bot_api.lua`(`:232` / `:288` / `:288-293`),**进本轮时就已经指错**;
    本轮给该文件加 10 行注释后又各漂 10 行。正确目标有歧义,**点名不代改**。
  - **交出去的棒**:两个上游 0 是**量具缺口**,`GetAttackDamage`/`GetAttackSpeed`
    **在 .dem 里是有的**(`make_fixture.py` 不抽),抽出来站点 B 当天可判 —— 与 GH #293 / #305 同族,
    已按铁律 5 开 **GH #306**(`[harness]`);主角**输出**伤害无地面真相,是设计问题不是抽取问题。
    发表前跑过 `claim_precheck.sh`:**`clean` exit 0**,`local commits not on origin/main: 0`
    (先 push 再发表,GH #290 的顺序)。
- 2026-08-29T10:48Z(报告 `iterations/reports/hero/20260829T104857Z.md`;轴 **backlog -44:
  上一棒明确交出来的枚举**)—— 自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,
  `UNCERTIFIABLE: none`;stable-v1/v2 锚点 ok;trunk python 52/0、快 Lua 腿 23 文件 0 失败。
  owner 四条优先项**没有一条球在本组**(P1/P2 协同组、P3 总监、常设运维批测台)。
  **`bots/`/`game/` 零行改动;无新 gate id;零 AWS;不提批测请求;不开新 issue。**
  新文件 `tests/test_incoming_damage_callsite_census.lua`(6 节,`[detector]`);
  文档订正三处(mock 头注 / ratchet 头注 / `state.json:mockdmg_ZERO_20260829`)。
  - **⭐⭐ 主发现**:「`GetActualIncomingDamage` 恒答 0」这个危害**有两个极性,写下来的只有一个**。
    41 个调用表达式中 **2 个是 `ZERO_TRUE`**(调用在 `<` 的小侧 ⇒ 分支**无条件开火**):
    `X.RetreatWhenTowerTargetedDesire()` 恒 `return 0.9`、metamorphic_mandible consider 恒 `DESIRE_HIGH`。
    ⇒ **那次量具修复能把绿变红**,不只是把红变绿;**这是它唯一的绿→红方向落点**,接棒 **-45**。
  - **⭐ 另 4 个站点的失效形状是「一个都不选」**(argmax/argmin 按入伤打分);
    `minion_lib/utils.lua` 的 `U.GetWeakest` **除以**那个调用 ⇒ 每个候选 `inf` ⇒ 整张名单进、nil 出。
    **已驱动证明**(真实模块、无 J.* 桩);`minion_lib/` 在全仓没有第二个测试。
  - **⭐ 订正**:「42 call sites」是 `grep -c` 行数,真实是 **41 个调用、40 行**(2 行是 `hero_axe.lua` 散文,
    `hero_silencer.lua` 一行两调用);另有 **2 个站点把 PURE 直接递给引擎调用**,
    `J.CanKillTarget` 的 PURE 短路没保护到它们。
  - **变异 6 条条条见红、对照绿**;luacheck `bots game` 0 警告;普查 6/0 绿。
  - **⚠️ 全量套件到收尾仍在后台跑**(GH #124),而且**那次读数被本轮的变异污染过**
    (变异改过 mock 与两个 `bots/` 文件,长跑套件按加载时刻读文件)⇒ **不当事实报**。
    **不要把本条读成「全量套件绿」。**
  - **⚠️⚠️ 但有一条在干净树上单独重跑坐实了:`test_itemdesire_world_assertion.lua`
    `25 tests, 6 failures`(exit 1),而且一条都不是英雄组的** —— 该文件读到的我方文件只有
    `tests/mock/bot_api.lua` 而本轮对它的 diff **每行都是注释**,且本轮**没有增删任何 fixture**。
    机制是 **GH #221**(崩溃站点的键就是运行时行号,上游插行即改名 ⇒ 旧键读 0)与
    **GH #106/#107**(加/治一枚 fixture 顶掉语料绝对计数)两族。**记录并指名,不代改、不重复立案**;
    已在 **GH #221 追评**今天的读数。
    ⚠️ **它为什么现在才被看见**:文件跑 ~9 分钟(全量从来跑不完,GH #124),而它的测试名
    用的是 `[census]`/`[world]`/`[recorded]`/`[measure]`,**一个 `[detector]`/`[ratchet]` 都没有**
    ⇒ **自检快腿也不覆盖它**。六条红同时躺在 trunk 上,**三道日常门一道都看不见**(GH #267 同机器)。
  - **⚠️ 变异还原用 `git checkout` 打在未入库的新文件上会静默失败**,当场做出过一次**假对照**;
    已改盘外备份 + `cp` 还原重跑。
  - 入集队列:`wkqdmg`(hero-23)、`odbuild`(hero-22)**已于 2026-08-29T10:xxZ 由总监裁定入集**
    (`ROUTED_RIDESHARE`,armed 串 42 → 44,全文 `test_set.md §CF`,投递在 `queue.json` 各自的
    `director` 字段),本轮无新增待裁 id。⚠️ **两条各自带一个 UNINTERPRETABLE 退回门,收割前必读**:
    `odbuild` 先过 `skill_point_stall.py`(OD 仍 STALL 则零读数一律退回,不许读成「测过了没效果」),
    `wkqdmg` 先问载体供给与 WK 等级分布。
    *[本行由总监 10:xxZ 代改:原文写的是「仍等总监裁」,该裁定落地后这句话就成了假的,
    `tests/test_stale_waits.py` 当场点名 —— 它读的是活的 当前状态 块,而下游会照着它决定下一轮干什么。]*
- 2026-08-29T08:08Z(报告 `iterations/reports/hero/20260829T080806Z.md`;轴 **backlog -43 出发,
  落在 WK 的 Q 击杀确认 + 量具**;**-43 部分结清并改道,-44 接棒**,原意留作 **-43a**)——
  自检 **worst exit 3**:legs run **8**,`FINDINGS: unlanded cadence`,`UNCERTIFIABLE: none`;
  stable-v1/v2 锚点各三项 ok;trunk python 52/0、快 Lua 腿 21 文件 0 失败。
  owner 四条优先项**没有一条球在本组**。**本轮 `bots/` 一处改动**
  (`hero_skeleton_king.lua`),`game/` 零行;**新 gate id `wkqdmg`**(turbo-only,
  **未 arm、未 promote、不是 live**);`state.json` 新增 `wkqdmg_20260829`(`gated:true`)
  与 `mockdmg_ZERO_20260829`(`gated:false`);**零 AWS**;入集在 `test_set.md` **§CD** 提议
  (等总监裁);queue 新增 **hero-23**(申请方=本组,**不动裁定/路由/status/priority**);
  **不开新 issue**(四条 baton 写进 backlog -44)。
  - **⭐⭐ `GetActualIncomingDamage` 在 mock 里没有默认值,于是答 0** ⇒
    `J.CanKillTarget` 对**所有非 PURE 伤害**恒假,**每一帧、每个英雄、任意伤害数值**;
    `bots/` 下 **42 处**调用点;`J.WillMagicKillTarget` 把魔抗/护盾/折射算完之后
    **最后一行是同一个调用**(:1151),所以它以同样的方式死着。
    **0 不是"没有数据",是"抗性无穷大"** —— 而同一文件里 `GetMagicResist` 的默认 0
    说的是同一未知量的**反面**。修成**答原始伤害**(不建模减免);
    **这是上界**,游戏里有 25% 基础魔抗,离线开火的分支实战里仍可能不开火。
  - **⭐⭐ 量具一修,那条登记了七天的杠杆当场有了真实帧**:同一份带内普查、同一份语料,
    **修前 0 帧 / 修后 1 帧**。`f_260820_181711_wk_l1trade_333`(t=333.5):
    juggernaut **160/1067**,539u,不免疫,身上挂着 0.6 秒前那一发 blast;
    出厂声明 `100*1.68 = 168 ≥ 160` 开火,而这一发本身是 `80 + 20*2 = 120`。
    ⚠️ **该帧 Q 在 13.3s 冷却上**,端到端两例标注变异了冷却;血/等级/距离/蓝是真实帧数据。
  - **⭐ armed 取 `min(出厂, 命中+整段dot)` 而不是诚实读数**:诚实读数在 rank 2+ 且 t10 天赋
    到手后**反超**出厂(260 > 235.2)⇒ 直接换是**增加施法**。`min` 让 armed 只能撤回、
    不能造(GH #165 纪律)。**创兵那一处故意不动**(收窄会把 `not CanKillTarget` 翻向反面)。
  - **⭐ 本仓库第一次有 baton 型绊线被真正触发**:`test_axe_battle_hunger_pure.lua` §5
    与 `test_zuus_static_field_pct.lua` 的 LIMIT,两条原文都写着"如果这条不再成立就去做 X",
    本轮双双打红并按原文改写(它们要的后续 **本轮不做**,baton 留在 -44)。
  - **⚠️⚠️ 交出去的后果**:`odaoe`(GH #54)在 A 帧上的反事实变了 ——
    出厂的单体出口结尾就是 `J.CanKillTarget`,量具一修**出厂会开火**
    (单体点 227/230 血的美杜莎)⇒ 从「AoE 对什么都不放」变成「AoE 覆盖两人 对 单体一发」。
    **游戏侧「该局大招 0 次」的观察不受影响**(在录像上量的)。已改写那两例并钉住
    "出厂点人 / armed 点覆盖两人的点"这个真正的区别;**域的重读交出去,不在本轮解决**。
  - **验证**:`luacheck_gate.sh` **0 警告 exit 0**(gate 自己装的 luacheck);**未用 `RULE6_BYPASS`**;
    **变异 4 条**(gate 空转 3 红 / 去掉 `min` 1 红 / 消费点回滚 2 红 / mock 回滚 2+3 红)对照绿;
    定向 9 组全绿(`wk_` 194、`replay_` 549、`zuus` 110、`axe_` 109、`cm_` 178、`lion_` 99 …)。
  - **⚠️ 全量套件本轮没跑完**(收尾时仍在后台,GH #124 ~100min)——**不是"全绿"**。
    跑到的部分 2 条红:一条是**改写前**的 axe 文件(改写后单独 17/0),
    另一条 `test_gamemode_world_assertion.lua:1450` 跨文件钉的 census 行
    **今天已被 `dd8f5ca5`(总监 07:07Z)从 `test_level_gate_census.lua` 里拿掉**
    (`grep` 0 命中;而那个 census 自己 15/15 绿)⇒ **GH #221 同族,记录并指名,不代改**。
- 2026-08-29T04:51Z(报告 `iterations/reports/hero/20260829T045154Z.md`;轴 **GH #287 §2 `odbuild`**;
  backlog **-42 结清,-43 接棒**)—— 自检 **worst exit 3**:legs run **8**,
  `FINDINGS: cadence trunk-red(python) trunk-red(lua)`,`UNCERTIFIABLE: none`;stable-v1/v2 锚点各三项 ok。
  owner 四条优先项**没有一条球在本组**(常设运维→批测台,P1/P2→协同组,P3→总监);
  **-42 的排序依赖(排在 GH #290 item 1 之后)本轮核过已解除** —— `CompactSkillList` 在树上
  (`8cf5ae0c`,`ability_item_usage_generic.lua:51` + 调用点 `:230`,9/9 绿)。
  **本轮 `bots/` 一处改动**(`hero_obsidian_destroyer.lua`),`game/` 零行;
  **新 gate id `odbuild`**(turbo-only,**未 arm、未 promote、不是 live**);
  `state.json` 新增 `odbuild_20260829`(`gated:true`);**零 AWS**;
  **入集在 `test_set.md` §CC 提议**(等总监裁);queue 新增 `hero-22`(申请方=本组,**不动裁定/路由/status/priority**);
  **不开新 issue**(在 #287 追评)。
  - **⭐⭐ 修的是「索引 4 → 3」,四个位置,别的一个字不动**:出厂
    `{2,1,4,2,2,6,2,1,1,1,6,4,4,4,6}` → armed `{2,1,3,2,2,6,2,1,1,1,6,3,3,3,6}`。
    **「作者本来就想点 `[3]`」是算术不是猜**:行长 15 = 4+4+4+3,OD 恰好三个可学基础技 + 三级大招,
    而行里唯一没被点名的基础技就是 `[3]`。**#287 §2 自己提的两条候选都打偏**
    (大招在 slot 5 ⇒ (a) 空操作;索引 4 是占位符 ⇒ (b) 更差)。
  - **⭐⭐ 真实帧**:`f_260819_222559_od_eclipse_solo`(11:01)——
    **真打过的 bot OD,11 级,`objurgation` rank 0,蓝 1448/1658**。出厂行预测每级都是 0;
    **任何点名 `[3]` 的行都产不出这个 0**。
  - **⭐ 条件 (c) 的第二半**:`X.ConsiderObjurgation` 第一条件 `IsFullyCastable()` 在 rank 0 恒 false
    ⇒ 那 ~50 行**至今一次都没跑过**;它算的是随蓝池放大的护盾(`mana_pool_to_barrier_pct`),
    而这英雄整条出装都是蓝。⇒ **本条的反面不是「改差了」,是「维持零」**——
    未 arm 时那四个点什么都不买,对照组是**点空气**。
  - **⭐⭐ 顺手补的结构性失明**:`test_build_index_resolution.lua` 原来**只读 `tAllAbilityBuildList`**,
    于是**那个找出本缺陷的普查读不到 gated build 行**——包括为修它而写的这一行。
    现读**全部 `t<Name>BuildList`**(全仓非默认表恰好三张,新 §8 钉住);**读数一位没变**(8 → 9 检查)。
  - **⭐ 顺手补的第二个洞**:自检**快 Lua 腿按标签发现文件**,而
    `test_build_index_resolution.lua` 的头注**只用散文自称 ratchet、没有标签**,
    新写的 `test_od_build_objurgation.lua` 同理 ⇒ **两个棘轮本来都只在跑不完的全量套件里才被读到**
    (GH #124/#267)。两个都打上 `[ratchet]`,**带标签的发现集 15 → 17**(自检那一行的总数 **19 → 21**:
    它另按文件名收四个先于标签约定的文件,**两个数不是同一个量**),合计 **~0.26s**。
    **这是铁律 10「不是缺工具,是工具没人跑」的同一个形状,只不过这次是本组自己刚写的工具。**
    ⚠️ 只动了本组自己两个文件,**没有去扫全仓还有多少自称 ratchet 而没打标签的**(那是 harness/总监的活)。
  - **⚠️ 上一棒的一条预测被证伪并记下**:-42 原文预告「§4/§5 会红,那是设计如此」。**没红,也不该红**——
    修复按铁律必须 gated ⇒ **出厂行一个字没动**,而 §4/§5 量的正是出厂行。
    「修好了普查就会红」只对 **ungated** 的改法成立。
  - **落地**:新 `tests/test_od_build_objurgation.lua`(8 节,含把「fixture 自己的槽位表**不是**索引权威」
    写成断言);**变异 6 红 1 对照绿**,`bots/`/`tests/fixtures/`/`tests/mock/` 事后逐字节干净。
  - **⚠️⚠️ 交出去的硬依赖(已写进 §CC.3 与 `hero-22` 的 acceptance 第 (1) 项)**:
    GH #290 预登记**预期 OD 仍停在 6 点**,而**停在 6 点的 OD 永远走不到这四个被修下标被消费的等级**
    ⇒ OD 若仍在 STALL 表里,空读数标 **UNINTERPRETABLE 并退回**,**不许**读成「测过了没效果」。
  - **⚠️ trunk 红两处都不是本轮的,推手已点名**:`test_level_gate_census.lua` 2 条 ——
    `8cf5ae0c`(总监 02:43Z)重锚 pin 并写「15/15 green again」,**一个半小时后**
    `bc2ff86f`(协同组 04:20Z)又给同一文件 +14 行、**pin 没跟着走**(`:5858→:5872`、`:5898→:5912`);
    干净树上 `git stash` 逐条复现 ⇒ 结构上不是本轮的。机制已在 **GH #221** 立案 ⇒
    **记录并指名,不代改、不重复立案**。Python 两条(`test_detector_source_constants` /
    `test_selfcheck_lua_leg`)同理,收尾复跑仍 50/2。
  - **验证**:`luacheck_gate.sh` **0 警告 exit 0**(容器本来没有 luacheck,gate 自己装的);
    **未用 `RULE6_BYPASS`**;定向 15 组全绿见报告 §6(`od_build` 8/0 新、`build_index` 9/0、
    `gate_claim` 10/0、`smoke` 3/0、`od` 111/0、`wk_` 182/0、`cm_` 178/0、`axe_` 109/0、`lion_` 99/0 …);
    Python `run_py_tests.sh` **50/2**(那 2 条见上)。
    **⚠️ 全量套件被本轮自设的 `timeout 5400` 砍掉,`rc=124`,汇总行一次都没打印过** ——
    **没跑完,不是跑绿了**;跑到的 1595 个进度符里 8 条红,**全在
    `test_itemdesire_world_assertion`(6)与 `test_level_gate_census`(2)两个文件,一条都不是本轮的**
    (前者的量全从 `tests/fixtures/` 数出来而本轮零新增 fixture;后者见上)。
    **被砍掉时还有约三分之一没跑到,那一段有没有红本轮不知道。**
- 2026-08-29T01:51Z(报告 `iterations/reports/hero/20260829T015146Z.md`;轴 **GH #287 §3
  的枚举**;backlog -41 结清,-42 接棒)—— 自检 **worst exit 3**:legs run **8**,
  `FINDINGS: cadence`,`UNCERTIFIABLE: none`;stable-v1/v2 锚点各三项 ok。
  owner 四条优先项**没有一条球在本组**(常设运维→批测台,P1/P2→协同组,P3→总监);
  [hero] open issue 里 **#287 最新且带证据**,§2 被录像组排在 GH #290 之后 ⇒ **本轮做 §3**。
  **本轮 `bots/`/`game/` 零行改动**;**无新 gate id**;`state.json` 新增
  `buildindex_CENSUS_20260829`(`gated:false`);**零 AWS**;不申请入集;**不开新 issue**
  (在 #287 追评);**不动 queue、不动裁定与路由**。
  - **⭐⭐ #287 §3 的「离线读不出来」是错的**:`hero_slots.lua`(GH #209)+
    `ability_meta.lua`(GH #36)让**出厂 `GetAbilityList` 离线跑在每个英雄的真实槽位上**;
    唯一读不了的 `IsHidden()` 用 **2^k drop-world 枚举**处理(沿 `test_hero_slot_order_anchor` §3)。
  - **⭐⭐ 恒 nil 的下标 = 0 个(OD 也在这个 0 里);OD 的病是 `[4] = 'generic_hidden'`,
    2/2 世界,被 build 引用 4 次,全仓唯一无条件命中。** 占位符是字符串 ⇒
    **所有「是不是 nil」形状的检测器对它结构上沉默。**
  - **⭐⭐ #287 §2 的两条候选修法都打偏**:OD 大招在 slot 5 ⇒ (a) 空操作;索引 4 是占位符
    ⇒ (b) 更差。`odbuild` 该修的是**索引 4 → 意图中的技能**(已写进 -42 与 #287 追评)。
  - **⭐ §3 假设的成因成员数 = 0**:没有英雄的大招在 slot 4 以下。
  - **诚实边界**:静态读;`generic_hidden` 有逃生口 ⇒ 是**浪费的 build 位不是停摆**,
    9/12 局停摆归 **GH #290**,本轮不解释它。
  - **落地**:`tests/test_build_index_resolution.lua`(8 节)+ 三条变异实测(四条轴都能打红)。
  - **⚠️ 全量 `run_tests.lua` 跑了 ~117min 后被本轮自设的 `timeout 7000` 砍掉(rc=124)**
    —— **没跑完,不是「全绿」**;静态门 0 警告、python 51/0、定向 9 组全绿(报告 §7)。
  - **⚠️⚠️ 但它跑到的部分量到 trunk 上有 7 条红,两个文件,都不是本轮的**:
    `test_itemdesire_world_assertion.lua` 6 条 + `test_salvepool_missing_floor.lua` 1 条。
    两个文件的量**都是从 `tests/fixtures/` 数出来的**,而本轮**零新增 fixture**
    ⇒ 结构上不可能是本轮移动的;推手是 **`b50a7727`(录像组 08-28T07:01Z)的两枚
    venomancer fixture**,而 salvepool 那条 `121/64` 是 **`829c382e`(08-27T22:30Z)**
    写的 ⇒ **那条红在 trunk 上站了约 19 小时**。这是 **GH #124 / #273 的同一台机器**。
    **不新开 issue**(重复),已在 **GH #124 追评**并指出 #124 正文**没点到
    `test_salvepool_missing_floor.lua`** —— 同一机制的第二个文件。
    两个文件**都不在本组名下**(itemdesire→harness,`salvepool`→协同组)⇒ **记录并指名,不代改**。
- 2026-08-28T22:51Z(报告 `iterations/reports/hero/20260828T225121Z.md`;轴 **backlog -39:
  两个 lever 缺的是同一批帧,并成一条语料请求**;**queue `hero-10` 申请方自改,-39 结清**)
  —— 自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence stale-waits trunk-red(python)`,
  `UNCERTIFIABLE: none`;stable-v1/v2 锚点各三项 ok;
  **`STALE strategy.md:2569` 与 trunk python 的那一条红是同一件事,且在协同组名下**
  (`tests/test_stale_waits.py`,**开工前即红**,收尾复跑仍 **50 passed / 1 failed** 同一条)
  —— 本组不代改别组章程(§AW.1),**记录并指名**。
  owner 四条优先项**没有一条球在本组**(常设运维球在批测台,P1/P2 球在协同组,P3 球在总监)
  ⇒ 按章程走 backlog,而 **-39 明写「下一棒做这条」**。
  **本轮 `bots/`/`game/` 零行改动**;**无新 gate id**;**`wkrosh`/`wkbuild` 的门与 armed 状态
  一个字没动**;`state.json` 新增 `wksupply_LEVEL_HORIZON_20260828`(`gated:false`);
  **零 AWS**;不申请入集;**不开新 issue**;**不加波次、不涨优先级、不动裁定与路由**。
  - **⭐⭐ 主产出一:那个零不是「turbo 到不了」,是语料构成。**
    `tests/fixtures/` **107 帧 / 77 局 / 1070 位**,其中 **≥13 级的位 48 个、22 局、高水位 19**
    (一个 Viper);**Wraith King 的 36 个位高水位 12、≥13 级 0 个** —— **语料到得了 13+,
    只是 WK 的帧全是早期切的**。⇒ 两个 lever 都**条件在这个英雄身上**,
    **GH #84 的全局等级曲线回答不了它们**,读数必须**按英雄条件化**(已照抄进申请)。
  - **⭐⭐ 主产出二:790.4s 不是 turbo 局的长度,是旧 10 分钟上限的影子。**
    语料**最晚一帧就是 790.4s = 13:10**;抬上限(P3/GH #108)后取的第一枚帧是
    **10/10 个位 ≥20 级**的那枚 parked 帧(24.9 分钟自然结束)。
    ⇒ **要扫的是归档 timeline 里 13:10 之后的段,不是再扫一遍 fixture。**
  - **⭐ 全仓 12 级以上的 WK 位恰好 1 个**(parked 那枚,26 级,glob 外一个目录),
    而它**同时回答两个 lever 且方向相反**:26 过了 `wkrosh` 的 crossing 21/19/18,
    又在 `wkbuild` 条件 (c) 的寿命(12-19)**之外**。这就是并成一条在技术上成立的理由。
  - **落地**:新 `tests/test_wk_level_supply_horizon.lua`(5 节:供给零 / 唯一证人 /
    时间地平线 ceiling / 48 位对照 / 消费者仍在且仍 gated);语料枚举沿用 -38 的
    **存在性 + basename 双保险**(GH #236 落地不管 move 还是 copy **只读一次**)。
    queue `hero-10` **两处都改**(`question` 载论证与分母,`acceptance` 加第 (4) 项
    预登记读数:**13..19 与 ≥20 两格各带分母,两格都要**,按铁律 4(ii) 不报中位数、
    4(i) 分层给 ab/ba)—— **两处都改是故意的**:执行方读的是 `acceptance`,
    只写 `question` 就是铁律 9 那种掉棒。沿 `hero-21` 先例。
  - **⚠️ 被自己的检测器抓了一次**:新文件第一次跑被 `test_level_premise_registry.lua` §2
    判成「argues from GH #84 ceiling」**6 处**,而它**全篇是在反驳那个天花板**——
    检测器是**词法**的,分不清援引与反证。**照规矩来不开豁免**:14 行窗口内点名
    GH #235 / 2026-08-27 且明写「这些数字是反证」;**没有往 PENDING 加行**
    (加行等于认一笔本组不欠的债,还会把 `CEILING` 从 2 顶回去)。6 → 2 → **0**。
  - **⚠️ 顺手看到、没有立案**:`corpus_scale.lua` 自己写明 `ge20 == 0` 这类零形状断言
    **就是要在长出反例时变红**;而 `test_level_gate_census.lua:514` 那道绊线**绊不到** ——
    反例(10/10 ≥20)**从 08-26 起就在树里**,在它那句 `ls tests/fixtures` **外面一个目录**。
    **一道为失败而写的保险,结构上保证沉默。** 两文件在 harness/director 名下(GH #236),
    机制已在 GH #281 立案 ⇒ **只记读数,不重复立案**。
  - **变异 4 个:3 抓 1 对照**。抓到:glob 里一个 WK 位抬到 13(§1 先红)、parked 路径打断
    (§2+§3)、出货源码 `wkrosh` gate 改名(§5);对照(一行注释)逃逸。
    每个变异**先 diff 确认非 no-op**、**还原用备份不用 `git checkout`**;
    `bots/` 与 `tests/fixtures/` 事后字节干净。
  - **诚实边界**:**一枚帧**,杀得死全称命题**不是分布** —— 全轮没有一句说 turbo 有多大比例
    到 20 级,**那正是 `hero-10` 要买的数,本轮买不到**;WK 那个零是**冻结的帧**上的零、
    不是**打过的局**上的零(36 个 WK 位只有 2 个高于本帧中位数,但 fixture 是为决策瞬间
    **手切**的,**该偏差不能当行为读数,故不入断言**);第 13 条世界断言不变 ⇒
    肉山那一半**仍是位置性代理**。**两条判词都没被撤回,也不提请重审。**
  - **验证**:`luacheck_gate.sh` **0 警告 exit 0**(容器本来没有 luacheck,gate 自己装的);
    `tests/run_py_tests.sh` **50/1**(那 1 条见上,非本轮);Lua filter:`wk_` **182/0**
    (新文件 +5)、`level_premise` 5/0、`corpus_scale` 8/0、`corpus_existence` 4/0、
    `level_gate_census` 15/0、`focus_talent_anchor` 22/0、`focus_build_level` 10/0、
    `smoke_load` 3/0。**全量套件单进程跑不完(GH #124),本轮未跑全量 —— 是没跑,
    不是跑绿了。** **未用 `RULE6_BYPASS`。**
  - **下一棒**:backlog **-40** —— **等 `hero-10` 的读数,别为这两个 lever 再开第二条请求**;
    在此之前做不依赖那批帧的活(Zeus / Lion / Crystal Maiden 三个**本组从未逐帧看过**的方向)。

- 2026-08-28T19:53Z(报告 `iterations/reports/hero/20260828T195320Z.md`;轴 **backlog -38:
  棒 ③ 剩下的两行 WK**;**ceiling 4 → 2,棒 ③ 在本组这一侧结清**)
  —— 自检 **worst exit 3**:legs run **8**,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  待裁 queue 请求 0(open 37);expired waits none;stable-v1/v2 锚点各三项 ok;
  trunk python **51 passed / 0 failed**,快速 Lua 检测器 17 文件 0 失败(FAST SUBSET)。
  owner 四条优先项**没有一条球在本组**(常设运维球在批测台,P1/P2 球在协同组,P3 球在总监)
  ⇒ 按章程走 backlog,而 **-38 明写「下一棒做这条」**。
  **本轮 `bots/`/`game/` 零行改动**;**无新 gate id**;
  **`wkbuild` / `wkqaim` 的门与 armed 状态一个字没动**(`wkqaim` 从来没被写出来,本轮也没写);
  `state.json` 新增 `wkpremise_REGISTRY_CLEARED_20260828`(`gated:false`);
  **零 AWS**;不申请入集;**不提 queue**;**不开新 issue**。
  - **⚠️ -38 自己的预判对了一半,错的那一半正是重点**:它猜两个文件「大概率也用
    `ls tests/fixtures/f_*.lua`」——q_aim **是**,thresholds **完全不读语料**
    (纯 mock,一个 glob 都没有)。**按上一棒的形状去找,会正好找不到它。**
  - **⭐ 藏得深的那条不在散文里**:thresholds 的 premise 在**造帧函数**里 ——
    `make_frame` 递的 untrained talent6 桩,**正是它让 `X.ConsiderW` 两条分支的
    `or talent6:IsTrained()` 惰性、threshold 才扫得出来**;天花板一退休,
    **sections 2/3/4 三节一起悬空**。q_aim 那条只是注释里一句 cross-check,划掉后**断言一字不动**。
  - **⭐ 替代理由不看等级带**:两条 build row 把四个 Bone Guard 点**在 12 级前花完**
    (default 1/3/5/7、`wkbuild` 1/9/10/12),t20 行**最早 20 级**才存在 ⇒
    每次帽子跃迁都在 bypass 不可训练的世界里。**新 section 7** 读 shipped build row 断言这个 gap。
  - **⭐⭐ 主产出:修正的代价是条件 (c) 有了寿命 —— 天花板一直遮着它。**
    桩改成参数后跑 shipped `X.ConsiderW`:**trained ⇒ section 4 的每个 threshold 全塌到 0**,
    两条分支都是;最响一格 **rank-4 lane 8 → 0**。那个 8 就是 `wkbuild` 延迟加点买的全部东西
    ⇒ **(c) 在 12-19 级成立,20 级作废**,而**这仓唯一一枚后期帧(26 级、Bone Guard 已 rank 4)
    就站在寿命外面**。**不撤销 `wkbuild`,不提请重审**。
  - **⭐ q_aim 的修正是收窄不是放宽**:丢掉「for most of a turbo game」那半句,supply 变成
    **前中期**判词、对后期**沉默**。结论不动 —— 理由 (2)(自卫分支在 catch-all 上游)**不看等级**。
  - **⭐ glob 地平线这次是量出来的「没有」**:parked 帧的 WK 是**全语料唯一一个 supply 不是
    阻塞项的位**(26 级 / Q rank 4 / cd 0 / mp 762 / R rank 3 ⇒ ShouldSaveMana 预留也是 0,
    **四个 conjunct 一个不挡**),**挡住它的是几何**:568u 环 **0 人**,最近活敌 **10,309u**
    ⇒ 全称命题**活着**。已把该帧接进 `fixture_files()`(存在性 + basename 双保险,
    GH #236 落地不管 move 还是 copy **只读一次**)+ **新 section 4** 对着文件断言读数。
  - **⭐ 变异 8 个 7 抓 1 对照。⚠️ M7 本来是对照,它逃逸了 —— 那是个真洞**:
    `reincarn_rank` 当时没人读,可它是 section 1 第四个 conjunct 的全部依据;补上断言后立刻变成抓到。
    **一个逃逸的对照,先问它是不是该逃逸。** 变异一律先 `diff` 确认非 no-op、还原用备份不用
    `git checkout`;`bots/` 在 M1 后逐字节还原(`git status` 里 `bots/` 干净)。
  - **诚实边界**:**一枚帧**,杀得死全称命题**不是分布**,全轮没有一句说 20 级以上占多少;
    section 6 证明 bypass **解除** threshold,**不证明它触发过**,也永远证明不了
    (GH #260 dumper 丢 unique 天赋行);section 6 定的是**分支测试**的价,不是顶上
    `HasModifier` guard 的价(residual 仍在 bypass 文件里)。
  - **registry**:PENDING 4 → **2**,`CEILING` 4 → **2**(`CEILING == pending_count()` 绑定
    强制同一改动内完成)。**剩下两行 `corpus_scale.lua` / `test_level_gate_census.lua`
    全在 harness/director 名下(GH #236),本组不再欠这笔债。**
  - **验证**:`luacheck_gate.sh` **0 警告 exit 0**(容器本来没有 luacheck,gate 自己装的);
    `tests/run_py_tests.sh` **51/0**;Lua filter:`wk_` **177/0**(`wk_bone_guard` 21→**24**、
    `wk_q_aim` 9→**11**)、`level_premise` 5/0、`corpus_scale` 8/0、`gate_claim` 10/0、
    `level_gate_census` 15/0、`smoke_load` 3/0、`focus_build` 10/0、`fixture_talent` 9/0、
    `lategame_talent` 8/0。
    **全量套件单进程跑不完(GH #124),本轮未跑全量 —— 是没跑,不是跑绿了。**
    **未用 `RULE6_BYPASS`。**
  - **下一棒**:backlog **-39** —— `wkbuild` 的取证语料**全部 ≤12 级**,而 (c) 的寿命
    结束在 20 级;-37 已为 `wkrosh` 点名过同一形状。**两条要的是同一批帧**,
    并成**一个**语料请求(域仍 queue `hero-10`),不要各提各的。

- 2026-08-28T16:57Z(报告 `iterations/reports/hero/20260828T165744Z.md`;轴 **backlog -37:
  `wkrosh` 的两条读数并成一棒 —— ceiling 的 tail argument 与 floor 的余量**;
  **新开 GH #281** 交 harness/总监)
  —— 自检 **worst exit 3**:legs run 7,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  UNLANDED 0(500 refs 里 454 REFUSED,shallow clone);**cadence 洞是 director 4.2h + strategy 9.2h,
  本组无洞**;待裁 queue 请求 0(open 37);stable-v1/v2 锚点两项 ok;
  trunk python **50 passed / 0 failed**,快速 Lua 检测器 17 文件 0 失败(FAST SUBSET)。
  (退出码按上一条的教训用 `${PIPESTATUS[0]}` 取。)
  owner 四条优先项**没有一条球在本组**(P1/P2 球在协同组,常设运维球在批测台);
  open `[hero]` issue 有 7 条,但 **backlog -37 写明「下一棒做这条」** ⇒ 按章程取 backlog 顶端。
  **本轮 `bots/`/`game/` 零行改动**(头注 08-27 已自行吸收该更正);无新 gate id;
  **`wkrosh` 的门与 armed 状态一个字没动**;
  `state.json` 新增 `wkrosh_LATEGAME_RECONCILED_20260828`(`gated:false`);
  **零 AWS**;不申请入集;**不提 queue**。
  - **⭐ -35 的直觉对,而且比它自己写的还对**:两条读数不只是「同一个量的两种说法」,
    **错的方式也是同一个,并被同一枚帧同时打掉** ——
    `iterations/pending/tpgap_159_fixture/f_260826_155416_slardar_tpgap.lua`(t=1382.2 = 23:02,
    GH #235)的 WK 位 **level 26 / mp 762 / max_mp 855 / Blast 4 / Reincarnation 3**。
  - **⭐ 余量不是收窄是变号**:129 **之下** → 255 **之上**;分支判的是**当前**蓝量 762 ⇒
    **shipped 600 第一次有帧过闸**;ceiling 的 tail 同时按**观测**退休(26 过了 21/19/18 全部三条)。
    **两条判词都没被撤回** —— 立足点本来更窄(600 = 603 crossing pool 的 **99.5%**、
    法术价格的 **4.3 倍**),**等级从来不是重点**。
  - **⭐⭐ 主产出:glob 就是地平线。** 两文件都用 `ls tests/fixtures/f_*.lua`,而那枚帧停在
    `iterations/pending/`(GH #236)——**glob 外一个目录**,于是两个扫描**都把「扫不到」
    渲染成量到的极值**。**最毒的证据是 floor 自己的预言**:它把「旧扫描 structurally 看不到的帧」
    写成**关于将来**的事(**写于 08-28**),而回答它的帧**从 08-26 起就在树里**。
    同 GH #257/#266 族,**且正是该文件自己两节后用另一个名字警告过的陷阱**。
    **53 个测试文件**共用这句 glob ⇒ **GH #281**。§1 把机制**变成机器检查**
    (**结构性看不见 ≠ 文件缺失** —— 这个区分才让它是缺陷)。
  - **⭐ 模型外推第一次可检验,偏 14 点智力**:预测 687 vs 实测 855(差 **168 = 恰好 14 int**);
    **不是漏算物品**(五件按 ceiling 自己的 `ITEM_STATS` 逐件断言全 0);
    **控制项** 1 级锚点 267 仍精确 ⇒ 差**与等级相关**。**记录不归因**(候选:26 级必然已花的
    四个天赋而帧只显示一个,GH #260 已坐实该维度欠观测 / 12 级以上某属性机制);
    **方向承重**:模型**偏低** ⇒ 真实 crossing level **更早不会更晚** ⇒ 下游**只需重指,不需撤回**。
  - **⭐ lever 的代价(登记不解决)**:该帧上**两条腿都放行** ⇒ **`wkrosh` 是 no-op**,
    而这**恰是本仓唯一一枚「晚到打肉山是常态」的帧**。**不撤销**(咬合窗口最宽 505 最窄 240,
    **最宽处正是 R 1-2 级**),但**重指取证方向**:撑着它的 **24/31 全部测自 ≤12 级** ——
    **最不可能打肉山的等级带**。域仍是 queue hero-10。
  - **registry 未经提示正确响两次**,并**补上它自己的洞**:变异实测 ceiling **4→9 静默通过**
    (**天花板抓不到自己被抬高**)⇒ 现绑成常量断言 `CEILING == #PENDING`,还债只能**删行**;
    ceiling 5 → **4**。
  - **11 变异 10 抓 + 1 对照按设计逃逸**。**⚠️ 过程教训**:M9 初读「没抓到」,实际是 `sed`
    **一个字符都没匹配上** —— **no-op 变异和漏网变异长得一模一样**;
    **信「没抓到」之前先确认变异真的改到了文件**。还原一律用**备份文件不用 `git checkout`**。
  - **诚实边界**:**一枚帧**,足以杀全称命题但**不是分布**,全轮**没有一句**说 26 级 WK 多常见;
    **快照不是直读**但**加强了**(§5 控制项趁 parked 还读得到把每个数重推一遍,bag 按**集合**);
    **完全没碰域**,**蓝量读数不是域读数**;两 sibling 的**计数一个没动**。
  - **验证**:`luacheck_gate.sh` **0 警告 exit 0**(前后各一次);`run_py_tests.sh` **50/0**;
    Lua filter:wk_ 172/0、wk_roshan 43/0、level_premise 5/0、corpus_scale 8/0、
    gate_claim_consistency 10/0、level_gate_census 15/0、activemode 14/0、focus_build 10/0、smoke_load 3/0。
    **全量套件单进程跑不完(GH #124),本轮未跑全量 —— 是没跑,不是跑绿了。**
    **未用 `RULE6_BYPASS`。**

- 2026-08-28T13:51Z(报告 `iterations/reports/hero/20260828T135142Z.md`;轴 **GH #279:
  被删掉的 Boots of Bearing 终点定价**;**删除维持,但两条腿变一条腿**;**GH #279 已评论并关闭**)
  —— 自检 **worst exit 3**:legs run 7,`FINDINGS: cadence`,`UNCERTIFIABLE: none`;
  UNLANDED 0(495 refs 里 448 REFUSED,shallow clone);**cadence 洞是 strategy 9.2h,本组无洞**;
  待裁 queue 请求 0(open 37);stable-v1/v2 锚点两项 ok;
  trunk python **49 passed / 0 failed**,快速 Lua 检测器 17 文件 0 失败(FAST SUBSET)。
  **⚠️ 本条初稿写成「exit 0,无 findings」,错了,已更正**;错因是
  `routine_selfcheck.sh | tail; echo $?` **取到的是 `tail` 的退出码**,
  且后台那次读输出文件时**它还没写完**,空文件被当成了「没有 findings」——
  **两次都是把「我没看见输出」读成「它没有输出」**,与铁律 10「SKIP 不是通过」同族。
  取管道退出码用 `${PIPESTATUS[0]}`。
  owner 四条优先项**没有一条球在本组**;
  `[hero]` 带帧证据的 open issue 就是 **#279 本身**(上一轮亲手开的、置于 backlog 顶端)⇒ 直接认领。
  **本轮 `bots/` 只改注释**(`hero_crystal_maiden.lua` 的 OUT-OF-WINDOW 段);无新 gate id;
  `state.json` 新增 `cmboots_TERMINUS_PRICED_20260828`(`gated:false`);
  **零 AWS**;不申请入集;**不提 queue**。
  - **⭐ §3 的两条防线守着同一个论证,死在同一对帧上。** `#BEARING == 0` 与 `WINDOW.max < 1500`
    合起来说的是「那个 0 是 OUT-OF-WINDOW 不是 EMPTY」。`b50a7727` 的两枚帧里
    **CM 本人**(焦点英雄、本仓自己的 pos_5 线)握着 `boots_of_bearing` ⇒
    **「还没人走到」这种防线,一旦有人走到就无话可说**。所以不修断言,**把 0 换成价格**。
  - **⭐ 价格:t=773.5s = 12:53.5,level 14,net worth 7746。** 物品自己的 modifier 驮着年龄,
    785.4 帧 elapsed 11.9、790.4 帧 elapsed 16.9,**相隔 5 秒的两帧算到小数点后一位完全一致** ——
    **算术在自查,不是挑读数**。owner **既无 tranquil 也无鼓** ⇒ recipe 确实吃掉了组件。
  - **⭐ 时钟约定测出来了**:1471 个 modifier 里 **108 个 elapsed 大于自己那帧的 time**,
    ⇒ `elapsed` **不从哨声起算**,购入时刻 = `t - elapsed`,对出生就带的东西**允许算成负数**。
    偏移是几十秒量级,所以 **11.9s 龄的物品可以直接定价** —— 已作为控制项断言,免得后人重推。
  - **⭐ 「窗口外」当年是对的,但只对了 83 秒**(旧边界 690.5,购入 773.5)。这**修正了** 08-27 那条注:
    它从**单独一枚 23:02 越帽帧**(GH #235,CM 22 级)外推出「比旧语料能看到的任何东西都晚」,
    实际 **12:53、14 级**。**一枚帧外推的「晚得多」,被两枚帧改成「晚 83 秒」。**
  - **⭐ 删除仍然成立,但活下来那条腿换了地基** —— 从「移速不叠加」的 Dota 规则断言,
    换成**本仓 purchase 源码**:`_stillNeeds` 有鞋时拒买基础鞋,**除非** build target 在
    `tBootsUpgrades` 白名单里;**`item_boots_of_bearing` 就在那张白名单里**,
    而 `item_arcane_boots` 在 `Item['tEarlyBoots']` 里 ⇒ **在 arcane 线上留着终点,
    等于故意把那道本来会拦住二次购鞋的门关掉**。三条事实逐条断言。
    (顺带排除:会跳过 `item_tranquil_boots`、从而让 recipe **卡住**的 `tSkipBoots`,
    在 **ARDM 换英雄重建**分支里,**Turbo 走不到** ⇒ 本仓的形状是「买双鞋」不是「卡住」。)
  - **⭐ 两条这个文件此前从没写过的代价**:(1) **candidate 留着 `item_ancient_janggo`,
    却删掉了它唯一的升级** —— 出货线上鼓是**组件**(12:53 被吃掉),candidate 线上鼓是**终点**;
    鼓的充能**不回**,Bearing 的**回**。(2) 4225g 的终点,出货线 **12:53 就实打实走到**。
    **而让删除仍然便宜的是光环实测覆盖很薄:8 个 ally-frame 里只有 1 个**(4 中 1 / 4 中 **0**)——
    **写成天花板**(`nHit*2 < allyFrames`),分母一起断言:哪天它 buff 半个队就变红,
    **而不是让结论悄悄过期**。
  - **变异 7 抓 + 1 对照**(购入时刻塌回帧时刻 / 光环把每个队友都算成被 buff /
    `item_boots_of_bearing` 出白名单 / `item_arcane_boots` 出 `tEarlyBoots` / 两帧互相矛盾 /
    owner 同时握 tranquil / 时钟对照弄瞎;对照 = 改没人读的 `net_worth`,仍绿)。
    M3/M4 动 `bots/` 后逐字节还原。**⭐ 过程里被咬了一口并记下**:M1 收尾用
    `git checkout <文件>` 还原变异,**把本轮自己对该文件的改动一起还原了** ⇒
    **在自己刚改过的文件上做变异,还原手段不能是 `git checkout`**,后续改用备份文件。
  - **诚实边界**:两枚 owner-frame **同一局** ⇒ 定的是**一次购买**的价、不是分布;
    dump **不区分**光环的施放者/接收者 modifier,断言的是「**非 owner 的队友身上带着该 aura modifier**」
    **不是**「buff 已被施加」;组件最后一次被看到是在**别的局**(t ≤ 661.5),
    **没有任何一局被全程看着完成这次合成**;鼓的充能代价是**从物品数据论证**,不是测量。
  - **`cmboots` 自己的门与 armed 状态一个字没动**;`cmboots_RESOLVE_20260825T2130Z` 的
    **RETURN_ON_C 裁决未被触碰**,Route A / GH #190 仍是活着的重新入集路径 ——
    **本轮不是在重打那一仗**。
  - 铁律 6:`luacheck_gate.sh` **0 warnings / exit 0**(容器本来没有 luacheck,gate 自己装的);
    **未用 `RULE6_BYPASS`**。全量套件一进程跑不完(GH #124)⇒ 影响面单跑:
    `cm_pos5_boots` **19/0**、`cm_` **178/0**、`boots` **28/0**、`corpus_scale` **8/0**、
    `gate_claim` **10/0**、`smoke_load` **3/0**。
    **trunk 红况**:上一轮点名的 `axe_t15_payoff`(13/0)与 `wk_bone_guard`(21/0)**已绿**;
    **本轮清掉 `test_cm_pos5_boots.lua`**;仍红的只剩 `test_gamemode_world_assertion.lua`(1 failure)——
    **协同组辖区,GH #278 已交出去**,本组不动手。
  - **下一棒**:backlog **-37**(= 回棒 ③ 的三行 WK,见 -35/-33),从
    `test_wk_roshan_mana_ceiling.lua` 起,**与 `test_wk_roshan_mana_floor.lua` 收窄中的余量
    (141 → 129)并成一棒读**。`hero-19`/`hero-20`/`hero-21` 仍 pending;
    WK `ConsiderQ` 的 `nDamage` 修复仍等归档扫描;**GH #268 那一格未被认领,不由本组扩**。
- 2026-08-28T10:51Z(报告 `iterations/reports/hero/20260828T105124Z.md`;轴 **GH #274 重读**;
  **两个已发表 verdict 都 UNCHANGED**;**新开 GH #278** 交协同组)—— 自检 **worst exit 3**:
  findings 全部来自 `cadence` 腿,`UNCERTIFIABLE: none`,stable-v2 锚点三项 ok,
  python trunk 48 passed / 0 failed。owner 四条优先项**没有一条球在本组**;
  backlog 上一轮点名 -34(#274 本组那半)⇒ 直接认领。
  **本轮 `bots/` 只改注释**(`hero_skeleton_king.lua` 34→36/17→19、
  `hero_crystal_maiden.lua` 51→53 四处);无新 gate id;`state.json` 不动;
  **零 AWS**;不申请入集;**不提 queue**。
  - **⭐ 重读的结论是「都没变」,但买到的不是「都没变」这四个字,是它们为什么不变。**
    Axe 那两枚新帧**都是干的** ⇒ 只加天花板不加观测,这才是 ceiling 涨 0.39 而 live 计数不动
    的原因;WK 那 20→22 的增量**逐 path 归因到那两帧本身**,所以补集**仍然恰好 14** ——
    一个没归因的 +2 会和「门开始挡它以前不挡的帧」**长得完全一样**。
  - **⭐ 灵敏度比读数更有用。** Axe §3 方向成立当且仅当
    `call_live × hunger_ceiling > hunger_live × call_ceiling`(今天 16 > 11.65)。
    **语料增长本身永远翻不了它**(`16+k > 11.65+0.965k` 恒真);翻它需要 **2 帧
    Battle Hunger live 而 Call 不 live**。所以这里将来变红 **= bot 行为动了**,
    这正是 pin 的用途 —— 也是「保持等式」在这个文件里说得通的理由。
  - **⭐ #274 的红名单只列了 3 个,真实是 6 个,而漏的机制可预测**:它的复现命令用
    `run_tests.lua axe` / `talent`,filter 是**文件名子串**,漏掉的三个文件名里两个词都没有。
    **红名单是用会漏的工具取的**;本轮改用 `grep -rln "ls tests/fixtures" tests/*.lua` 枚举 53 个。
  - **⭐ 6 个红里有 3 个根本不该响。** 它们是纯名字/纯分母普查,没有任何 verdict 骑在精确值上,
    `corpus_scale.lua`(GH #106→#127 就为这个存在)**从没被它们采用**。已迁;
    「N of N」改 `cs.universal(hits, live_total)` 是**严格变强**(对还没剪出来的 fixture 也成立)。
    零主张按 corpus_scale 成文原则**保持等式**。
  - **⭐ 唯一真的动了的读数在 `wkrosh`**:high-water MAX pool **459 → 471**,
    mana-dead verdict 存活但余量 141 → **129**。这是该文件自己写的 honest bound
    (「GH #108 抬闸后新语料会含结构上够不到的帧」)**到期**。下一棒预期它继续收窄。
  - **⭐ 最后数出来是 7 个红,不是 6 个,第 7 个是本组自己的**:`test_cm_pos5_boots.lua:439` ——
    **CM 本人**在新帧里带着 `boots_of_bearing`,而同一对帧让 `WINDOW.max < 1500`
    也同时到期。「被删掉的终点是 out-of-window 不是 empty」这个论证**两半一起没了前提**。
    这是**出装决定**不是计数重取 ⇒ 开 **GH #279** 并放 backlog 最上面(-36),本轮不动手。
  - **交棒**:`test_gamemode_world_assertion.lua:534` 也红,`past_honest` **0 → 2**
    (新帧 `time=785.4/790.4`,×2 后越过 1500)—— `aba_push.lua` 的 push cap 语句
    honest 读数**第一次有非空定义域**。协同组辖区,**在这里重设基线正是 #274 反对的那种替换**,
    故只开 **GH #278** 不动手。
- 2026-08-28T07:47Z(报告 `iterations/reports/hero/20260828T074756Z.md`;轴 **`LEVELPREMISE` 重读续**;
  **棒 ③ 第 4 行**,登记表天花板 **6 → 5**;**新开 GH #274**)—— 自检 **worst exit 3**:
  UNLANDED 0、两条稳定版锚点 ok、Lua 快速检测器 **16** 文件 0 失败、待裁 queue 请求 0(open 37);
  cadence 洞是 **replay-check(6.1h)+ strategy(6.2h)**,**本组无洞**;owner 四条优先项
  **没有一条球在本组**;`[hero]` open issue 里带帧证据且属焦点五的**一条都没有**
  ⇒ 按 backlog 取上一轮点名的 `test_focus_build_level_legality.lua`。
  **本轮 `bots/` 零行改动**;无新 gate id;`state.json` 新增
  `levelpremise_focusbuild_20260828`(`gated:false`);**零 AWS**;不申请入集;**不提 queue**。
  - **⭐ 被判掉的不只是那个 0,还有「队列后面什么都没有」。** 那条 scope bullet 用**两条**论证
    把 t20/t25 两个队列位排除在文件之外。第一条是天花板本身(「out of turbo's domain,
    GH #84 读 level >= 20 得 0/210」)—— 作废,而且**落点特别刺眼**:已录快照里
    **crystal_maiden 22、zuus 23 正正落在它宣称够不着的 21–24 停车带里面**,
    skeleton_king 26 在带子外侧,**两个都是焦点英雄**。
  - **⭐ 第二条论证熬过了天花板,死在自己的测量上。** 「it costs nothing … by then there is
    **nothing else in the queue**」**是可测的假**。驱动出货的 `GetTalentBuild` + `GetSkillList`,
    **七行焦点构筑全跑**(含 zuus pos_4/5 与 gated `wkbuild`):技能行都是 15 条 ⇒ 队列到 **23** 位,
    **选中的在 10/15/18/19**(不是 10/15/20/25),**放弃的四个半边在 20/21/22/23**。
    队列后面**有四个东西,而且 bot 每一个都向引擎要过** —— 把 05:xxZ 在 **lion 一个英雄**上的
    读数**推广到全部七行**。
  - **⭐ 换上的判据一句等级都不看**:停着的队首后面的每个条目,都是**同一条队列里更早已点掉的
    那一档的另一半**;一档一个 ⇒ **任何等级都取不到**。§4b **断在 25 级**(阶梯顶),
    所以**不可能靠等级上限回来而被满足**。level-19 那处停车**只给一个等级事实**:
    它后面只有 t25 选中项,25 > 19。**过去用语料普查豁免一整个带子,现在用出装。**
  - **⭐ 顺手抓到并交出去的:trunk 现在是红的,不是本轮造成(GH #274)。**
    `b50a7727`(replay-check 07:05Z)加的两枚 venomancer fixture,一帧十个 slot,
    **同时移动四个登记计数、三个文件变红**:`test_axe_t15_payoff`(26→28、~1.94→2.33)、
    `test_wk_bone_guard_talent_bypass`(34→36、20→22)、`test_write_only_local_census.py`(62→64)。
    **`git stash` 后在 HEAD 上逐位复现。刻意不就地改数字** —— 其中两个数**驮着已发表判决**
    (Axe 那个 ceiling 正是让「Battle Hunger 只在 1 帧上活着」读作 SATURATED 而非 NEGLECTED 的数;
    WK 那个文件 `:269` 明文要求「先重读整份普查再引用任何数字」)⇒
    抄数字 = **用便宜的编辑顶替昂贵的重读**,正是登记表存在的理由。
  - **⭐ 变异 5 抓 + 1 对照**,而 **M1 第一轮先逃过 4a**:
    `tQueue[p] == sTalentList[nTalentBuild[k]]` 在两边都 `nil` 时**恒真**,
    而「天赋构筑不再返回放弃的半边」产生的正是两边都 nil ⇒ 就地补非空断言,现在双抓。
    **合成 offender 之外还要防断言被空值满足。** 变异后 `bots/` 全还原。
  - **诚实边界**:构筑行读自源码字面量(两行备选行没有调用可截;**§4a 在 axe 上把 routing 钉了一次**);
    天赋名来自 `tests/mock/talent_slots.lua`;「永远非法」是**常量**(被驱动的是「20–23 真的是
    已点档位的另一半」);25 级发出的四条注定失败的升级命令**引擎接不接受不判也判不了**;
    **本轮无真实帧**;队列位是技能行长度的算术(故单独断言 `nRowLen == 15`)。
  - **登记表棘轮自己先响**:头部一改好它立刻变红并点名要删哪一行、降到几 —— **机制在工作**。
  - 铁律 6:`luacheck_gate.sh` **0 warnings / exit 0**(容器本来没有 luacheck,gate 自己装的);
    push gate 已上膛;**未用 `RULE6_BYPASS`**。全量套件一进程跑不完(GH #124)⇒ 影响面单跑:
    `focus_build_level_legality` **10/0**、`level_premise` **5/0**、`lion` **99/0**、
    `zuus` **110/0**、`smoke_load` **3/0**;`axe` 2 红 / `talent` 3 红 = **GH #274,非本轮**。
  - **下一棒**:**优先 GH #274 本组那半** —— 在 64 文件语料上**重取** Axe t15 读数与 WK Bone Guard
    普查,并记下判决是否变化。**这比登记表剩下的行更值钱,因为 trunk 是红的。**
    之后回棒 ③:剩 **5 行**(本组欠 **3**,`test_wk_roshan_mana_ceiling` /
    `test_wk_bone_guard_thresholds` / `test_wk_q_aim_preflight`,**三行全是 WK**
    ⇒ **建议与 #274 的 WK 那半并成一棒**)。`hero-19`/`hero-20`/`hero-21` 仍 pending;
    WK `ConsiderQ` 的 `nDamage` 修复仍等归档扫描;**GH #268 那一格未被认领,不由本组扩**。

- 2026-08-28T04:48Z(报告 `iterations/reports/hero/20260828T044807Z.md`;轴 **`LEVELPREMISE` 重读续**;
  **棒 ③ 第 3 行**,登记表天花板 **7 → 6**)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点 ok、
  py **47/0**、Lua 快速检测器 **16** 文件 0 失败、待裁 queue 请求 0(open 37);cadence 洞只有
  **replay-check(6.1h)**,**本组无洞**;owner 四条优先项**没有一条球在本组**;
  `[hero]` open issue 里带帧证据且属焦点五的**一条都没有**(#245/#244 是 OD),其余全是本组自己的判决
  ⇒ 按 backlog 取上一轮点名的 `test_lion_hex_talent_slot.lua`。
  **本轮 `bots/` 零行改动**(一个英雄文件都没碰);无新 gate id;
  `state.json` 新增 `levelpremise_lionhex_20260828`(`gated:false`);**零 AWS**;不申请入集;**不提 queue**。
  - **⭐ 这个文件对着自己说了一天反话。** §6 08-27 已重推(域为空,理由从「语料够不到 25 级」换成
    「t25 取 `[7]` ⇒ 一档一个 ⇒ `talent8` 永不 trained ⇒ `X.IsHexAoe` 第一条语句就 false」),
    **头注的 ⚠️ LIMIT 块没跟着**,还留着承重的最后一句「§6 变红就是它变得可提的那一刻」——
    **结构性的空不会因为多收帧就不空**。**这是登记表 §3 的形状,而 §3 只扫 `bots/`** ⇒
    这次是数字清单恰好抓到的;§3 的范围注释已就地补上这句。**处置不变**
    (`lionhexaoe` 不 arm / 不入集 / 不提 queue,同 GH #165 对 `alchrage`),**变的是它不再等收割**。
  - **⭐ 而「结构性」≠「bot 从来不要」—— 这是本轮买到的量。** 驱动**真的**
    `J.Skill.GetSkillList`(参数从 `hero_lion.lua` 加载时的真实调用截获,不重抄表):
    `GetTalentBuild` 返回**八行**(`[1..4]` 选中 / `[5..8]` 放弃),`GetSkillList` 把放弃的
    **接在选中的后面排进升级队列** ⇒ Lion 队列位 **10/15/18/19 = 四个选中**
    (**不是 20/25**:技能行 15 条用完会提前插),**20/21/22/23 = 放弃的四半**,
    而 **位 23 = `sTalentList[8]` = `special_bonus_unique_lion_2`**,`talent8` 绑的正是它。
    再加上升级阶梯的兜底分支**不查 `CanAbilityBeUpgraded()` 就发 `ActionImmediate_LevelAbility`**
    ⇒ **让 `talent8` 保持 untrained 的,是游戏在拒绝一个本仓真的发出的请求。**
    §4b 的「门要留着」由此从「关于没人做过的改动的话」变成**对今天就在发的请求的守卫**。
  - **诚实边界**:引擎接不接受**不判也判不了**(`print()` 到不了控制台);升级分支是**源码读数**
    (`AbilityLevelUpComplement` 无导出句柄),断言窄到「发命令那条分支里没有 `CanAbilityBeUpgraded()`」;
    天赋**名**取自 `tests/mock/talent_slots.lua`;队列位是**技能行长度的算术**。**本轮无真实帧。**
  - **⭐ 变异 4 抓 + 1 对照**(M13–M17,详见报告 §5),变异后 `bots/` 全还原。
  - **顺手记下(非本轮造成)**:临时 `pairs()` 跑法让 `test_cm_arcane_aura_passive.lua` 红一例,
    **真正的 runner 是 16/0 绿** —— 差别是用例执行顺序,而它是 16 个共用同一个物理 `soak_side.lua`
    开关的 gate 测试之一 ⇒ **GH #229 同族**。**临时跑法不是 runner,别拿它的红去开 issue。**
  - 铁律 6:`luacheck_gate.sh` **0 warnings / exit 0**(容器本来没有 luacheck,gate 自己装的);
    push gate 已上膛。全量套件一进程跑不完(GH #124)⇒ 影响面按过滤器单跑:
    `lion` **99/0**、`level_premise` **5/0**、`talent` **72/0**。
  - **下一棒**:棒 ③ 剩 **6 行**(本组欠 4;`corpus_scale` / `test_level_gate_census` 归 harness/总监),
    **优先 `tests/test_focus_build_level_legality.lua`**(登记理由「scope claim argued from the zero」,
    被「能不能取到 = 出装不是等级」这条判据改写得最直接);`hero-19`/`hero-20`/`hero-21` 仍 pending;
    WK `ConsiderQ` 的 `nDamage` 修复仍等归档扫描;**GH #268 交出去的那一格未被认领,不由本组扩**。

- 2026-08-28T01:58Z(报告 `iterations/reports/hero/20260828T015816Z.md`;轴 **`LEVELPREMISE` 重读**;
  **棒 ③ 第 2 行**,登记表天花板 **8 → 7**)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点 ok、
  py **46/0**、Lua 快速检测器 **15** 文件 0 失败、待裁 queue 请求 0(open 37);cadence 洞只有
  **replay-check(6.1h)**,**本组无洞**;owner 优先项 P1/P2 球在协同组、P3 在总监,**本组零项**;
  `[hero]` open issue 全是本组自己发表的判决,无待认领带帧请求 ⇒ 按 backlog 取上一轮点名的
  `test_wk_fact_anchor.lua`。**本轮 `bots/` 零行改动**(一个英雄文件都没碰);无新 gate id;
  `state.json` 新增 `levelpremise_wkfact_20260828`(`gated:false`);**零 AWS**;不申请入集;**不提 queue**。
  - **⭐ 判掉的不是一个答案,是一个问题。** §4 那份 11 处 structural t20/t25 普查,和它一起登记的
    读法**每一句都转在 UNREACHABLE 上**(「else 分支是正确默认值,所以够不着不产生可观测代价」)。
    GH #235 把「够不着」拿掉之后 ⇒ **「够不着要花多少钱」是空问题,不是答错的问题**。
    **计数活下来,对计数的读法没有。**
  - **⭐ 换上的判据从来不看等级**:英雄每档只点一个天赋 ⇒ 一处 structural 读数变死,当且仅当
    **这个英雄自己的 `tTalentTreeList` 不点它绑的那一格**。新 §4b **驱动真的
    `J.Skill.GetTalentBuild`**(不重抄「{10,0} 取偶数」),结果**把 08-22 捏在同一个桶里的两个劈开**:
    **zuus `talent7` 点(`{5,7}`)** 且槽 7 = `unique_zeus_5` = `zuus_lightning_bolt/aoe_radius 325`
    ⇒ **25 级起地面施法分支在实装 turbo 里是活的,而它 08-22 被明文归进「不产生可观测代价」那三个**;
    **WK `talent6` 点(`{6,7}`)⇒ 20 级起活**;**lion `talent8` 不点(t25 取 `[7]`)⇒ 结构性死**。
    **zuus 与 lion 长得一样、同一个桶、结论相反,而分开它们的正是被丢掉的等级论证一直遮着的那一维。**
  - **⭐ 这一格是别人指名欠这个文件的**:`test_focus_talent_anchor.lua` §4a 自己写着
    「a read of index 1-4 is a LIVE read and needs its own accounting」并**点名转给 §4**。
    本轮之前**全仓没有任何断言把 structural 普查与出装交叉过**。
  - **⭐ 交出去的一格(GH #268,已请求指派),明确不由本组扩**:四个非焦点英雄(chaos_knight / legion_commander /
    lich / warlock)**保留计数、失去判决**——「够不着所以无害」对它们也不再成立而没人补。
    最尖的是 `hero_warlock.lua:532` `if talent6:IsTrained() and false`:等级论证没了之后,
    **一个字面 `false` 是唯一还在杀那条分支的东西**。
  - **诚实边界**:「点得到」≠「绑对了」—— zuus 第二问穿过 `sAbilityList[2]`,而 **GH #203 实测
    该下标不是技能槽位** ⇒ 地面施法真发生那帧 `abilityW` 是什么,**开放,刻意不断言**;
    仍无真实帧(可达性靠 GH #235 那枚停在 `iterations/pending/` 的帧);
    **lion 与 WK 今天天赋字面量相等**,这里没有任何断言分得开这一对,靠 `idx` 不同承担。
  - **⭐ 变异 5 抓 + 1 对照,而 M3 是新加 `picks` 那一列的理由**:三个英雄 t25 **全解到 `[7]`**,
    只断言 `trained` 时「读错英雄的字面量」**三问全部蒙对**(实测,不是担心)。
    对照(同时拿掉普查链接 + 改 idx)**正确地不抓** —— 那正是证明普查链接是承重那半的东西。
  - 铁律 6:`luacheck_gate.sh` **0 warnings / exit 0**(容器本来没有 luacheck,gate 自己装的);
    push gate 已上膛。全量套件一进程跑不完(GH #124,已知)⇒ **影响面 15 个文件单跑,149 断言全绿**。
  - **下一棒**:棒 ③ 还剩 **7 行**(本组欠 5),**优先 `tests/test_lion_hex_talent_slot.lua`** ——
    它 §6 已在 08-27 重推过,但登记表那行**仍带未更正的数字站点**,且是本轮判决**唯一直接碰到**的
    剩余 hero 行。`hero-19`/`hero-20` 仍 pending,`hero-21` 已收窄未关;
    WK `ConsiderQ` 的 `nDamage` 修复仍等归档扫描(本地语料域为空)。

- 2026-08-27T22:53Z(报告 `iterations/reports/hero/20260827T225311Z.md`;轴 **`TALENTBLIND` 续**;
  **棒 ③ 开工**,登记表清掉第一行)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点 ok、
  py **45/0**、Lua 快速检测器 **14** 文件 0 失败、待裁 queue 请求 0(open 37);cadence 洞只有
  **replay-check(6.1h)**,**本组无洞**;owner 四条优先项**没有一条球在本组**;带帧证据的开着的
  `[hero]` issue 仍是 **#245/#244(OD)**,不在焦点五 ⇒ 按章程取 backlog(棒 ③,连续第三轮未动)。
  **本轮 `bots/` 零可执行行改动**(`hero_skeleton_king.lua` 只加注释块);无新 gate id;
  `state.json` 新增 `talentvis_20260827`(`gated:false`);**零 AWS**;不申请入集;
  **不新提 queue 请求** —— 把已 routed 的 `hero-21` **就地收窄**。
  - **⭐ 19:58Z 自己留着不判的 H1/H2 岔口,被判掉了,而且买它的是零成本。** 那一轮够不着判决的
    原因是**等级**(语料顶到 19 级,那个 19 是 10 分钟 cap 的伪影)。GH #235 那枚后期帧就停在
    `iterations/pending/`(被 GH #236 挡住,**不是本组的球**)—— **读一个停着的文件不花钱**。
    十个英雄 **22–27 级**:按出货升级队列**必然已花掉 36 个天赋点**,那一帧**只显示 8 行、
    全是通用行、`unique` 0 行**;**jakiro 24 / necrolyte 25 / venomancer 24 三个一行都没有**。
    **H2 造不出这个** —— H2 说 bot 只点通用行,而**通用行是看得见的行**。⇒ **H1(量具)成立**,
    而且**充分**:`isRealAbility()` 的丢弃规则不需要任何关于世界的假设就解释完整个缺口。
    保守读法(只数 t10+t15)仍是 **20 中缺 12**。旁证在名字形状上:活下来的 8 个全是**类名蛇形**
    (`h_p200`,KV 写的是 `hp_200`)。
  - **⭐ 后果**:**TALENTPRICE 五轮不作废** —— 它们怕的正是 H2(「给没人点的行定了价」),
    而 Axe 与 WK 的出厂 t10 都在专属那一侧;五轮各自写的「本仓没有一枚帧能证实它触发过」
    **全部仍成立,并从观察升格成机制**。
  - **⭐ 棒 ③ 清一行**:`test_wk_bone_guard_talent_bypass.lua` 的 HONEST BOUNDS 与 §5 重读,
    §5 的重开触发器**记为已扣动**;`test_level_premise_registry.lua` 天花板 **9 → 8**,
    按登记表自己的规矩**写下重读结论**(新增 `CLEARED` 节)而不是删句子。
  - **⭐ 一条已发表推断的更正**:GH #260 的「没有任何一帧带两个天赋」**对 `tests/fixtures/` 仍成立**,
    但**不是管道的性质** —— dragon_knight 26 级带两行。「每个英雄最多一行」又是那个 10 分钟 cap。
  - **⭐ `must` 是模型不是观察 ⇒ 它被拿去跑了出货代码**:`GetSkillList` 把四个天赋选择放在队列位
    **10/15/18/19**,升级只在 `botLevel >= GetHeroLevelRequiredToUpgrade()` 时弹队首 ⇒ 约束是档位等级本身。
  - **⭐ 变异 12 抓 + 1 对照;三条先逃,是同一族的三个面**:(M6)门的字符串在文件里出现两次,
    第二次在兜底分支 ⇒ **grep 整个文件在真门被拿掉后照样绿**;(M7)`isRealAbility()` 上面的
    **文档注释按正确顺序写着那两个字符串且永不移动** ⇒ 扫原始文件 = 把自己的文档读回来当代码
    (与 `facet_settlement` 的 `live_source` 同一课,**换了门语言又交一次**);(M11)`snakeFromClass`
    的**定义**还在 ⇒「文件里提到它」永远为真。**断言必须运行它谈论的那一个东西。**
  - **诚实边界**:一帧一局,36 不是速率;队列因别的原因卡住会**压低** `must`(故保守地板单独断言);
    机制那条是**源码读数** —— 被丢掉的实体不留痕迹,**没有任何 fixture 能目击这次丢弃**;
    快照来自停放文件,#236 落地后 census 从新位置读出同样的行,**测试不用动**。
  - **下一棒**:棒 ③ 还剩 8 行(本组欠 6 行),**优先 `test_wk_fact_anchor.lua`**——
    它的 §4 是 t20/t25 的 STRUCTURAL 读数普查,**本轮判决直接改写它的前提**;
    `hero-19` / `hero-20` 仍 pending,`hero-21` 已收窄未关。
- 2026-08-27T19:58Z(报告 `iterations/reports/hero/20260827T195816Z.md`;**GH #260**;
  **新轴 `TALENTBLIND`** —— 棒 ② 收官后,把它五轮都写在诚实边界里的那句话当成问题)
  —— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点 ok、py **44/0**、Lua 快速检测器 **13** 文件
  0 失败、待裁 queue 请求 0(open 36);cadence 洞只有 **replay-check(6.1h)**,**本组无洞**;
  owner 四条优先项**没有一条球在本组**;带帧证据的开着的 `[hero]` issue 仍是 **#245/#244(OD)**,不在焦点五。
  **本轮 `bots/` 零可执行行改动**(`hero_skeleton_king.lua` 只加注释块);无新 gate id;
  `state.json` 新增 `talentblind_20260827`(`gated:false`);**零 AWS**;不申请入集;
  **新提 `hero-21`**(重新导出一局归档 .dem,零 EC2 —— 买的是把两个等价解释分开的那一个读数)。
  - **⭐ 105 fixture / 960 英雄-帧 / 67 次天赋目击,全部是通用行;`special_bonus_unique_*` 目击 0 次**,
    任何英雄任何等级,**含一个 19 级 Viper**;**没有一帧带两个天赋**,9 个 ≥15 级帧(游戏保证 ≥2)
    **一个都没带**。⇒ 语料对「这个 unique 天赋点了没有」**只会回答 0,而那个 0 不是证据**
    (**GH #238 同形**:零是量具的性质)。
  - **⭐ 分裂按种类,三比二**:CM `hp_200` 15/15、zuus `hp_200` 10/10、lion `movement_speed_20` 1/5
    对 axe `unique_axe_8` 0/10、WK `unique_wraith_king_facet_1` 0/5。焦点五天赋表都是**单行**,
    出厂选择用 `aba_skill.X.GetTalentBuild` 自己那一行解码,**而语料把这个解码反向验证了三次**。
  - **⭐ 两个解释等价、本轮不下结论**:H1 量具(`isRealAbility()` 在保留已升级天赋**之前**无条件丢
    `Special_Bonus_Base`/`_Attributes`,**而那一行只可能作用在已升级的实体上**;活下来的是**类名不是 KV 名**)
    / H2 世界(bot 从没点过专属天赋)。**后果差一个数量级** —— H2 成立则 TALENTPRICE 五轮买的是没人点的行,
    且 Axe 与 WK 的出厂 t10 正在这一侧。
  - **⭐ 最接近判决的一格**:**27 个 fixture 在同一冻结瞬间既显示一个天赋又对另一个 ≥10 级、点数对不上的
    英雄显示为空**(量具不能同帧既瞎又不瞎);最尖的是 **Lion**(通用 t10,一帧见得到、四帧见不到)。
    **诚实边界:本容器 git 历史从 08-26 开始,验不了 08-20 当天的出厂选择 ⇒ 写成棘轮不写成结论。**
  - **点数账**:228 个 ≥10 级帧里 **79 个缺口 ≥1**,**下界不是测量**(facet 赠送技能压低缺口)。
  - **对 WK**:`sTalentList[6]` 是焦点五唯一被决策层读到的天赋,「20 级起旁路是活的」**永远只能是
    KV+等级的论证**,已就地加边界(仅注释),**不撤回**。
  - **变异 10 条:10 抓 + 1 对照**;反真空这次是**工具 exit 2 拒绝出报告 + 测试 §0 + 快照自洽**三道。
  - **顺手查过再放下**:`ConsiderQ` 的 `nDamage` 修复**域在本地语料里为空**(要「Q 冷却好 + 有效血量
    75–126 的敌人在射程内」,13 个 WK fixture 一个都没有)⇒ 不落地,等归档扫描。
  - **下一棒**:`hero-21` 已提;**棒 ③(`tests/` 等级前提登记表,9 个文件)仍未动(连续第三轮)**;
    `hero-19` / `hero-20` 仍 pending。
- 2026-08-27T16:51Z(报告 `iterations/reports/hero/20260827T165139Z.md`;**GH #255**;
  **棒 ② 的第五个也是最后一个英雄 skeleton_king**,轴仍是 **`TALENTPRICE`**;**棒 ② 到此 CLOSED**)
  —— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点 ok、py **44/0**、Lua 快速检测器 **12** 文件
  0 失败、待裁 queue 请求 0(open 36);cadence 洞只有 **replay-check(6.1h)**,**本组无洞**;
  owner 四条优先项**没有一条球在本组**。开着的 `[hero]` issue 里带帧证据的仍是 **#245/#244(OD)**,
  不在焦点五 ⇒ 按章程继续棒 ②。
  **本轮 `bots/` 零可执行行改动**(`hero_skeleton_king.lua` 只改注释);**两行天赋都留**
  (t20 `{10,0}`=[6]、t25 `{0,10}`=[7]);无新 gate id;`state.json` 新增
  `wkt20t25_20260827`(`gated:false`);**零 AWS**;不申请入集;条件 (a) 骑已 pending 的 `hero-19`,
  **另提 `hero-20`**(归档扫描,零 EC2 —— 买的是唯一能诚实重开 t25 的读数,不是 (a))。
  - **⭐ 本轮真正的产出不是定价,是拆掉一道写进源码的门。** `hero_skeleton_king.lua` 里那句
    「两个备选都是 FACET 行,本仓读不到 roll 了哪个 facet —— **先了结再定价**」是**有道理的**:
    `GetTalentList` 走**运行时**槽位,而这个文件把 `sTalentList[6]` 绑成 `talent6` 并在
    `X.ConsiderW` **两条分支各读一次**;槽位若随 facet 变,**同一句谓词在不同局里谈不同天赋**。
  - **⭐ 答案比问题大一圈:129 英雄 / 339 条 facet 条目里 0 条点到天赋行**
    (`special_bonus_*` 或 `AbilityIndex 10..17`)⇒ **任何 facet 都动不了任何英雄的天赋槽**,
    **这道门对整条轴从来没关过,前四轮回溯地也不欠它**。每英雄那半:**WK 两条 facet 全 `Deprecated`**,
    Axe 2 / Zeus 2 / Lion 2 / CM 4 **也全 Deprecated** ⇒ **焦点五零条活 facet**。
    工具 `tools/agent/facet_census.py` + 快照 `tests/mock/hero_facets.lua` + 13 条断言
    `tests/test_wk_facet_settlement.lua`。
  - **⭐ 两条废弃 facet 补上了两条机制**:一条曾授予 `skeleton_king_bone_guard`(**骨盾今天是朴素
    `Ability2` 的原因**),一条曾授予 `skeleton_king_spectral_blade`(**「那名字每次解析成 nil」从观察
    升格成原因**)。**定价后果**:[2]/[6] 各有一半落在 spectral_blade 上 ⇒ **死的**,活的只有
    `blast_dot_duration +2` 与 `min_skeleton_spawn +5`。
  - **⭐ t20 留 [6]** —— **这棵树上唯一一个决策层读得到的天赋**,`talent6:IsTrained()` 旁路的正是
    本文件 GH #17 块自己论证「几乎够不着」的弹药阈值;挪到 [5] **会把那句谓词全局冻成 false**
    (Lion GH #166 的形状),**且多赔上修复本身**。
  - **⭐ t25 留 [7]** —— 两边都对决策层隐形 ⇒ 体量说了算:[7] 是**速率**(+66.7% 暴击频率),
    [8] 是**事件**(要死一次 + 900 内有敌人 + 120s CD)而 t25 窗口**开在一局的最后几分钟**;
    且 [8] **不是加是换**,顶掉出厂 4s/-75% 减速,而 `reincarnate_time = 3` ⇒
    **1.6s 晕早 1.4s 就过期了**。
  - **⭐ 近失(方向最危险)**:census 正则**漏 `re.M`** ⇒ 零个英雄匹配 ⇒ 打印的最后一行
    **和正确运行一模一样**(`focus five with a LIVE facet: none`)。**读到零的解析与结论达成一致。**
    修法:工具 `MIN_HEROES` **拒绝出报告** + 测试 §0 反真空。**变异 10:9 抓 + 1 对照。**
  - **下一棒**:**棒 ③(`tests/` 等级前提登记表,9 个文件)仍未动**;交出去三棒 —— `hero-19` 的
    WK 那一格(骑已 pending)、**新测量「重生触发时 900 内敌人数分布」**(唯一能诚实重开 t25 的读数)、
    `ConsiderQ` `nDamage` 修复(本轮查明**从 10 级起**陈旧,与 Axe `hero-2`、CM `ConsiderW` 同族)。
- 2026-08-27T13:55Z(报告 `iterations/reports/hero/20260827T135500Z.md`;**GH #251**;
  **棒 ② 的第四个英雄 crystal_maiden**,轴仍是 **`TALENTPRICE`**)—— 自检 **worst exit 3**:
  UNLANDED 0、两条稳定版锚点 ok、py **43/0**、Lua 快速检测器 **12** 文件 0 失败、待裁 queue 请求 0
  (open 36);cadence 洞在 **replay-check(6.3h)与 strategy(3.8h)**,**本组无洞**;
  owner 四条优先项**没有一条球在本组**。带帧证据的三条开着的 `[hero]` issue(#245/#244/#54)**都是 OD**,
  不在焦点五 ⇒ 按章程取棒 ②。
  **本轮 `bots/` 的可执行行改动 = 两个 table 字面量**:`hero_crystal_maiden.lua` 的
  **t20 `{10,0}`→`{0,10}`**(取 [5] `..._glacial_guard_mana_multiplier`,+20 法力转护盾 %)与
  **t25 `{0,10}`→`{10,0}`**(取 [8] `..._crystal_maiden_2`,水晶新星 +300)。
  **天赋行不 gate ⇒ 每一局打到 20/25 级的 turbo 都会执行**;无新 gate id;`state.json` 新增
  `cmt20t25_20260827`(`gated:false`);**零 AWS**;**不提新 queue 请求**;不申请入集。
  - **⭐ 棒 ② 里第一次两行都翻,而它们为两个不同的理由翻** —— 这正是它们可以同轮翻的原因:
    t20 那一翻**对决策层惰性**(只移动战斗力),t25 那一翻**移除一条已经在活着的失明带**。
  - **⭐ t25 = 拿掉失明带,不是造一条(与 Axe t25 同形、符号相反)**:`X.ConsiderW` 手算
    `nDamage = ( 100 + nSkillLV * 50 )` = 150/200/250/300,**逐位等于** KV 的
    `damage_per_second 100 × duration 1.5/2/2.5/3` —— **对,且只在没有天赋碰时长时对**。
    而原本取的 [7] **正是 +1.0s** ⇒ 4 级真伤 **400 对 kill-check 的 300**,**25 级起低估 25%**,
    方向是**「以为杀不掉」⇒ 放掉拿得到的人头**(解 cap 之前够不到,现在够得到)。
    [8] 落在 `nova_damage`,而 `X.ConsiderQImpl` **实时读它**并交给 `bot:FindAoELocation` ⇒
    引擎折算(GH #228)自己走到击杀判据:**260→560 而且决策层知道**。
    **放弃的是 1 秒单体禁锢**,写在前面不留作意外。
  - **⭐ t20 = t10/t15 那把 REACHABILITY 尺**:[6] 计价在 **channel-seconds held**,而本仓逐帧读过的
    两次冰封禁地频道**一次砍到最大时长的 6%**(`20260819_003005_slot1` t=373.4,0.6s 被晕,5.9s 后死)、
    **一次约 10%**(`20260820_103216_slot1` t=473.5,26% 血带着晕开引导,1.0s 后死)——
    **两帧就钉在这个文件自己的守卫注释里**,而 `cmrguard`/`cmrcap`/`cmrself` **全都还是 soak candidate**
    ⇒ **发布默认恰恰就在那些情形下开大**。[5] 计价在**花在技能上的法力**(语义是本轮**买来的**:
    Valve tooltip「花在技能上的一部分法力转成物理护盾」,`abilities_english.txt`),
    `barrier_duration 8`、`30 + 2/级`(20 级 ~70%)→ **90%** = **每 100 法力多 20 护盾**,
    **零瞄准、零引导**,**而且在 600 法力的大招上照付 ⇒ 开引导那一下本身值 +120 护盾**,
    正好在她被定住挨集火的时刻。付得起的理由与 Axe t20 同一条:**翻转对决策层惰性**
    (全文件无 `freezing_field/damage` 读;内置技能**连句柄都没有** —— 51/51 帧 hidden、
    被 `sAbilityList` 压缩走丢,GH #206)⇒ **两个方向都造不出陈旧读数**。
  - **⭐ 诚实边界(与结论同权)**:频道证据 **n=2、两帧都在 20 级以下、都来自 10 分钟 cap 的语料**
    ⇒ 界定的是**收益的形状不是费率**,本轮**没有任何断言声称费率**;护盾**只挡物理**,法术占比本组量不了;
    `hero_levelup +2` 起算点让 ~70% 浮动 2 点(**比值不动**);**CM 的 `Facets` 四条全部 `Deprecated`
    —— 这正是 Glacial Guard 今天是朴素 `Innate 1` 的原因**,一旦挂回 facet 这行就变 facet-条件的
    (**给 skeleton_king 那一族留下一个可复用判据:先看 `Facets` 块是否 Deprecated**);
    Valve 自己的默认 bot build 20 级也取 [5],**但它 t10 与我们不一致 ⇒ 列最后,是旁证不是论证**。
  - **⭐ 本轮必须自己踩住的坑**:公式 `100 + nSkillLV * 50` 被写进了 hero 文件的头注 ⇒
    **所有源码扫描跑在剥掉注释的源码上**,否则**扫描会把自己的文档读回来当代码**
    (与 `test_focus_talent_anchor.lua` 的 `live_lines` 同因)。
  - **测试**:新增 `tests/test_cm_t20t25_payoff.lua`(**10 条**,含一条 **iff 棘轮**:「t25 回到 [7]
    **当且仅当** 硬编码已修好」,**两种修法都接受**;并把「三个 R 守卫仍是 soak candidate」钉成前提 ——
    **谁 promote 它们,t20 的定价就该重读**);`test_focus_talent_anchor.lua` 记录改成 `t20=5 / t25=8`。
    **变异 9:6 抓 + 1 按设计放行(M7 = 回 [7] 且已修 ⇒ iff 通过)+ 1 对照(只改注释,全绿)
    + 1 交叉(硬编码 50→60 被天赋算术那条抓到)**。M5(`FindAoELocation` 不再吃 `nDamage`)
    **是把 `find` 改成逐个 `%b()` 实参表扫描之后才抓得到的**。
  - **验证**:`luacheck_gate.sh` → **0 warnings / EXIT 0**;定向 `focus_talent 22/0`、`talent 53/0`、
    `cm_ 173/0`、`gate_claim_consistency 10/0`、`smoke 3/0`、`level_premise 5/0`、`cm_t20t25 10/0`。
    **全量套件本轮没跑**(08:15Z 那轮后台跑完过:2210 例 / 0 失败 / ~4h10m > 2h 节拍),原样记下。
  - **下一棒**:棒 ② **只剩 skeleton_king**(两行是 FACET 行);棒 ③ 未动。**交出去两棒**:
    `hero-19` 的 CM 那一格(解 cap 后归档里 CM 到 20/25 级的占比 + 那两点花在哪)、
    **`ConsiderW` 硬编码的一般修法**(改读 `duration × damage_per_second`,与 Axe `hero-2` 同族;
    **今天它对的原因是这一轮把行挪开了,不是它自己稳**,iff 棘轮在中间兜着)。
- 2026-08-27T10:55Z(报告 `iterations/reports/hero/20260827T105510Z.md`;**棒 ② 的第三个英雄 zuus**,
  轴仍是 **`TALENTPRICE`**)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点 ok、py **42/0**、
  Lua 快速检测器 **12** 文件 0 失败、待裁 queue 请求 0(open 36);cadence 洞**只在 strategy**(3.8h),
  **本组无洞**;owner 四条优先项**没有一条球在本组**。
  **本轮 `bots/` 的可执行行改动是 0** —— **两行都定了价、都不改**:t20 保留 **[5]**
  (`zuus_arc_lightning/arc_damage` +60)、t25 保留 **[7]**(`zuus_lightning_bolt/aoe_radius` = 325)。
  无新 gate id;`state.json` 新增 `zuust20t25_20260827`(`gated:false`);**零 AWS**;
  不提 queue 请求;不申请入集。
  - **⭐ t20 的有意思之处是决策层对两边都瞎,所以它才降级成战斗力题。**
    [5] 是**焦点五里唯一一个收益落在本文件已经在问的 key 上**的天赋(引擎折进 `arc_damage`,
    `X.ConsiderQ` 读的正是它)—— **但那个读数只有一个消费方,而它坐在
    `bot:GetActiveMode() == BOT_MODE_LANING` 里**,t20 在 20 级解锁,对线期早就结束了。
    **折算够得到,门已经关了。** [6] 折进 `ministun_duration`,**全仓零处读**。
    平局按体量与档位裁:Arc **两份 build 都点满**、1.6s CD、`ConsiderQ` **九个分支**竞标,
    +60 **每一跳都付**(180→240,**+33%**);[6] 买的 0.5s 微晕之上,**0.35 本来就打断引导和 TP**,
    而多出来的追杀时间**本文件没有代码兑现**。
  - **⭐ t25 是决策层裁的,而且是 Lion 那条的「好双胞胎」**:`talent7:IsTrained()` 把
    `UseAbilityOnEntity` 换成 `UseAbilityOnLocation`,**而下标 7 确实就是 AoE 天赋** ——
    GH #166 在 Lion 上抓到的是**同一个 idiom 读下标 8、套在 `UNIT_TARGET` 妖术上**。
    点地施法本来就合法(基础 `spread_aoe = 325`),天赋把「打中一个」升级成「打中每一个」。
    **取 [8] 会把 `talent7:IsTrained()` 全局冻成 false**,把**本文件唯一一处「天赋改变下达的命令」**
    变成死代码。**[8] 的真优点也记下**:`AbilityCharges` 通过 `IsFullyCastable` 花掉、
    **完全不需要决策层配合** —— 但输在体量(W 九个分支,E 两个)。
  - **⭐ 本轮真正的产出不是定价,是量具**:定价 t20 落在 `hero_zuus.lua` 那句
    `never trained in turbo (GH #84)` 上 —— **它在同一文件被 02:15Z 改成相反话的表头下面 930 行**,
    而 `test_level_premise_registry.lua` 的「bots/ 恒为零」**一直读作零**。
    **两个独立漏洞**:(i) **第十种措辞**(一个数字都不引 ⇒ 六个数字指纹全看不见);
    (ii) **断句换行**(`hero_skeleton_king.lua` 的 `and unreachable in`⏎`turbo regardless`,
    措辞在名单上但**逐行扫描永远匹配不到跨行的句子**)。
    补法 = **§3:钉裁定措辞而非数字 + 扫相邻行对 + 只施于 `bots/` 等式为零 + anti-vacuum 7**。
  - **⭐ 一条被实测否掉的便宜修法**:把裸 `GH #84` 加进现有指纹 —— 确实找得到 Zeus 那处,
    **但同时把 7 个只是「拿它当出处引」的测试文件拖进登记表,把没人欠的债从 9 抬到 16**。
    **引用不是论证。** 施于 `tests/` 的那 6 处(3 个文件)**故意不上棘轮**:三个都已在
    `PENDING` 上,**上两道棘轮 = 同一份债记两遍**,已写进 §3 头注交出去。
  - **⭐ 学费:变异 M7 第一次是跑掉的。** 跨行测试**自己重新实现了两行拼接、没调用扫描器**,
    于是把拼接从扫描器删掉**整套依然全绿**;anti-vacuum 定在 6 又恰好擦边。
    修法两条(`scan_claim_lines()` 改吃 lines / 6→7),**同一个回归被抓两次**。
    与 05:30Z 散文锚那次同族:**断言必须运行它谈论的那个东西。**
  - **⭐ 把 axe 那轮的预期反过来的登记**:08:15Z 预期 zuus 的 t20 会被定到**偶数下标**,
    从而让它新加的配对断言成为 M3 **唯一捕手**。**t20 留在 [5](奇数)** ⇒ §2 经由 zuus
    **仍抓得到**塌缩的 t20 映射,那份重叠**还在**,`honest_note_on_M3` 不要读作已成事实。
  - **变异 8 条:7 抓 + 1 对照**(M3 是「行改了、记录同一次编辑里也改了」⇒ §2 被满足、
    **只有 §4c 反对**;M8 删 `WITHDRAWN` marker 会误报 wk:610 那处**真撤回**,证明 marker 承重)。
  - **下一棒**:棒 ② 还欠 **crystal_maiden**,**skeleton_king 最后**(两行是 FACET 行);
    棒 ③(`tests/` 登记表从 9 往下做)未动。本轮对 `hero_skeleton_king.lua` 的编辑
    **只删了一句可达性子句,不是他的定价**,已写进源码免得被误读。
- 2026-08-27T08:15Z(报告 `iterations/reports/hero/20260827T081500Z.md`;**棒 ② 的第二个英雄**,
  轴仍是 **`TALENTPRICE`**)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点不变量 ok、
  py **42/0**、Lua 快速检测器 11 文件 0 失败、待裁 queue 请求 0(open 35);cadence 洞
  **只在 strategy**(3.8h),**本组无洞**;owner 常设运维项球在批测台、P1/P2 在协同组、
  P3 在总监 ⇒ **本组无优先项**。
  **本轮 `bots/` 有一个可执行改动:`hero_axe.lua` 的 `tTalentTreeList['t20']` `{0,10}` → `{10,0}`**
  = 取 `special_bonus_unique_axe_4`(`axe_counter_helix/damage` +40)而不是 `special_bonus_strength_15`。
  **天赋行不 gate ⇒ 每一局打到 20 级的 turbo 都会执行的真行为改动**;无新 gate id;
  `state.json` 新增 `axet20_20260827`(`gated:false`);**零 AWS**;**提了 `hero-19`**
  (归档扫描、零 EC2);**不申请入集**。
  - **⭐ 最该被拿走的一条:这一格用的不是本文件那把尺子,而这句话写进了源码、被测试钉住。**
    按 payoff REACHABILITY(决定 t10/t15 的那把尺)**[5] 完胜** —— 纯属性块没有触发条件。
    ⇒ 换轴:**收益用什么计价、这套 build 花不花得出去**。[5] 计价在攻击力(本文件**零右键决策层**、
    两份 role list **都不买攻速/伤害装** ⇒ 不复利,**<9 dps**)与血量(pos_3 前 ~8.5k 全在这根轴上);
    [6] 计价在**纯粹伤害**(护甲不减、**160→200 = +25% 打在主伤害源**、**唯一按敌人数量翻倍**的伤害,
    而那状态是 `X.ConsiderQ` 专门制造的),**而 t20 解锁在最后三分之一 = 对面核心买到护甲的时刻**。
  - **⭐ 量级判在 t20 付得起、t25 付不起**:文件里**没有 talent5/talent6 句柄** ⇒ 这一翻
    **对决策层惰性**,只移动战斗力,两个方向都造不出陈旧读数。
  - **⭐ t25 留 [7],是决策层裁的**:[7] 的 +85 被引擎折进 `ConsiderQ` 已在读的 `radius`(它就是
    `nCastRange`)⇒ **多抓到且知道自己多抓到**(+61% 面积);[8] 的 +150 折进斩杀伤害,而判据是
    **硬编码** `150+100*lv` ⇒ **取 [8] 把已有斩杀盲带乘以七**(25 宽 → 175 宽)。
    ⇒ **在 `hero-2` 落地前 t25 不是自由选择**,用一条 **iff 测试**焊住。
  - **⭐ 诚实边界**:**本仓从来没有一枚域内 Axe 帧**。新工具 `fixture_proximity_census.py`:
    105 个 fixture 只有 **10 帧 Axe、等级 1-11**,1 帧在 helix 275 内有敌人 ——
    **不支持本次改动,原样记下;也不是反证**。GH #235 那枚 23:02 后期帧**里没有 Axe**。
  - **变异 8:7 抓 + 1 对照**(M7「`hero-2` 落地却留着断言」**只被 iff 抓到**;M8 逃逸设计如此)。
    **登记重叠**:新配对钉今天不是 M3 唯一捕手(zuus 现在还取奇数下标),**zuus 被定价那轮它才是**。
  - **⭐ 一条不归本组、但点名两个开着的 harness issue 的顺带读数(报告 §9)**:后台全量
    `lua5.1 tests/run_tests.lua` **跑完了** —— **2210 例、0 失败、EXIT=0**,单进程、普通
    Routine 容器。⇒ **GH #124「一个进程里跑不完」被推翻**,但真正的数是 **~4h10m**(上界,
    全程与前台抢容器)⇒ 挡住全量的不是「跑不完」而是**套件时长 > 2h 节拍**,那是另一个问题、
    解法也不同。⇒ **GH #216 那 2 处红没有复现**(它在 `224fa713` 上量到第 701/723 例);
    **但「没复现」≠「已修好」** —— #216 §2 自己说那两处依赖跨文件状态,而本轮正好加了 3 个
    用例会移位。**本组只交读数不认领判定**;两条都已追评到 #216 / #124。
    **顺带:2210 这个分母此前没人发表过,#216 按序号定位的证据有了它才可复核。**
  - **下一棒**:棒 ② 欠 **zuus / crystal_maiden**,**skeleton_king 最后**;棒 ③ 未动。
- 2026-08-27T05:30Z(报告 `iterations/reports/hero/20260827T053000Z.md`;**接本组自己交出的棒**
  (GH #238 §六 的 ①+②),新轴 **`TALENTPRICE`** —— 不是某个读数错了,而是**一个选择从来没被
  argue 过**)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点不变量 ok、py **41/0**、
  Lua 快速检测器 11 文件 0 失败、待裁 queue 请求 0(open 35);cadence 洞**只在 strategy**(3.8h),
  **本组无洞**;owner 常设运维项球在批测台、P1/P2 在协同组、P3 在总监 ⇒ **本组无优先项**。
  **本轮 `bots/` 有一个可执行改动:`hero_lion.lua` 的 `tTalentTreeList['t25']` `{10,0}` → `{0,10}`。**
  **天赋行不 gate ⇒ 这是每一局打到 25 级的 turbo 都会执行的真行为改动**(章程允许,代价是
  理由要写下来且可核);无新 gate id;`state.json` 新增 `liont25_20260827`(`gated:false`);
  **零 AWS**;**不提 queue 请求**;**不申请入集**。
  - **⭐ 承重理由,按「有多少是我们自己的」升序**:① +250 AoE 妖术是招牌 t25 —— **故意排第一
    并明说它最弱**(谁都查得到 ⇒ 不携带本地证据);② **这条是我们的**:妖术是 `UNIT_TARGET`,
    半径**由引擎在施法时施加** ⇒ bot **零瞄准零预判零新代码**吃满整个天赋;穿刺是**线性弹道**、
    是这英雄**唯一必须打提前量**的技能,[8] 把它 500→1100 ⇒ **提前量距离翻倍还多**。
    **两者不等价的方向恰好是对 bot 最要紧的那个方向。**
  - **⭐ ③ 它把 GH #166 构造掉,而不是用门挡住**:每层只学一个天赋 ⇒ `talent8` **结构性未学**
    ⇒ 15 处 `IsHexAoe` 处处 false,**而对单位指向技能 false 就是正确答案**(实体派发保住、
    施法合法性检查不再被跳过)。**什么都没损失** —— 半径由引擎施加,文件知不知道都一样。
  - **⭐ 放弃了什么(写在前面,不留作以后的意外)**:`'W-团控'` 挑扎堆目标那条分支被跳过。
    **少赚不是缺陷**(紧下面「最危险敌人」分支服务同一场团战,逐行读过),而且它是**放宽**
    ⇒ **正是 #166 §9 留给后来人的那一个,交出去不吞掉**。
  - **⭐ 门的理由换了、结论没换**:`lionhexaoe` 留着不 arm。旧理由(语料无 25 级英雄)继承自
    **属于 10 分钟 cap 的那个零**,02:15Z 已退役;新理由**不依赖任何语料**(第一句就 return false,
    **走不到门**)。**留着**是因为 t25 行与 V 社槽位顺序**都不是这个文件保证得了的**。
  - **t20 定了价、没改**:本来就取 [6](30° 锥形)= 本组会 argue 的那边;**记下来是为了让它
    不再读作「没人看过的上游默认值」**。
  - **测试反转而不是删除**:§2 原钉 index 8,**其失败信息预言的正是这次改动**;新增 **`{7,8}` 成对钉住**
    (**M4 只被这条抓到**)、**§4b 三句源码散文棘轮**(钉**刻意没做的事**)、§4 防「反正死了清理掉」;
    **§6 重新推导:语料断言改口量「收割滞后」,不再是域的裁定**。
  - **变异 11:9 抓 + 2 条复核过的对照**(M2 `{0,0}` 真 no-op;M11 局部改名)。
  - **⭐ 学费(散文锚第四次,原因是新的)**:`\xc2\xa7` —— **lua5.1 没有 `\x` 转义** ⇒
    锚**红在它要保护的注释上**。**承重句子源码里不换行 + 锚在多字节字符前停住,绝不放松断言。**
  - **门(如实)**:`luacheck_gate.sh` **exit 0 / 0 警告**(容器里没有,脚本按 `lua-check` 自己装);
    `run_py_tests.sh` **41/0**;`lion` **97/0**、`talent` **48/0**、`focus` **63/0**、
    `gate_claim_consistency` **10/0**、`smoke` **3/0**。
    **⚠️ 全量 `run_tests.lua` 未取到读数**(GH #124)——**如实记为没跑成,不是通过**;
    本轮 `bots/` 唯一的可执行改动是一个 table 字面量,其消费方已逐个实跑。
    **补记**:后台那个进程被本组自设的 40 分钟 `timeout` 杀掉(**`EXIT=124`,是被杀不是跑完**),
    被杀前 **981 例 / `FAIL` 0 条**。**这是前缀不是裁定** —— trunk 已知的 2 处红(#216)
    **没被走到** ⇒ 它**不能证明 trunk 绿**,只支撑「**本轮改动没在这 981 例里引入新失败**」。
  - **⚠️ 一条瞬态,不是本轮造成的**:一次自检报 py **39/2**。**两个单跑绿、完整 runner 两次 41/0,
    两次树里都带着本轮全部改动** ⇒ 不是这次改动;**假设实测证伪**(写出 `soak_side.lua` 仍全绿)。
    **成因未定 ⇒ 已开 GH #243 交 harness**:**假红跑出了 #229 点名的范围**,方向同样是**凭空多出失败**。
  - **下一棒**:仍欠 ② 的 axe / zuus / crystal_maiden(**skeleton_king 最后**)与 ③;
    **交出去两棒**:#166 §9 的放宽(需**一枚 25 级 Lion 的帧**,已写进 #166 评论)、python 假红 → **GH #243**。
- 2026-08-27T02:15Z(报告 `iterations/reports/hero/20260827T021500Z.md`;**自选,开了 GH #238**,
  新轴 **`LVLPREMISE`** —— 不是某个读数错了,而是**一句被当成 turbo 性质的话其实是量具的性质**,
  而它写在**五个已发布英雄文件**里当作 t20/t25 从没人看过的理由)—— 自检 **worst exit 3**:
  UNLANDED 0(唯一 OFF-TRUNK 是 strategy 自己的 `e2439e3`)、两条稳定版锚点不变量 ok、
  py **41/0**、Lua 快速检测器 9 文件 0 失败、待裁 queue 请求 0(open 35);
  cadence 洞**只在 strategy**(3.8h),**本组无洞**;
  owner 常设运维项球在批测台、P1/P2 在协同组、P3 在总监 ⇒ **本组无优先项**;
  [hero] open issue 全是本组已落地等裁定/等域;backlog 顶上四条(`-5`/`-3`/`25`/`26`)
  章程都写明「等 `hero-14`/`hero-13`/`hero-12` 的域」⇒ 走自选。
  **本轮 `bots/` 五个焦点文件只加注释、零可执行行改动**;无新 gate id;`state.json` 新增
  `lvlpremise_20260827`(`gated:false`);**零 AWS**;**不提 queue 请求**;**不申请入集**。
  - **⭐ 承重读数**:GH #84 的 `level >= 20` **0/210**、high-water 19,**对语料对、对 turbo 错**
    —— 局在 10 分钟 economy cap 自终止,**够不到** 20。owner P3(#108)拿掉 cap 后第一枚帧
    (23:02、24.9 分钟自然结束,#235)读到**十个英雄 22-27 级、high-water 27**,
    **三个是焦点英雄**(CM 22 / Zeus 23 / WK 26)。真实 turbo ~20 分钟 ⇒ **对已发布产品也从来不成立**。
    分布:**`bots/` 9 处(四个焦点文件)+ `tests/` 20 处(九个文件)**。
  - **⭐ 最该被拿走的一条:Lion 是活的缺陷。** t25 取 **[8]**(穿刺射程 +600)= **恰好让每处
    `talent8` 答 TRUE 的那一半**,而代码信它是「妖术变 AoE」(#166,真半径是 [7])⇒ **25 级起**
    W 派发把 `UseAbilityOnEntity` 换成 `UseAbilityOnLocation`,而 `lion_voodoo` 是 `UNIT_TARGET`。
    **#166 的「域为空」量在够不到 25 级的语料上 ⇒ `lionhexaoe` 不再是空域候选,重开 #166。**
  - **⭐ 第二条后果号是反的**:Axe t25 取 **[7]** ⇒ `talent7` **25 级起是活的**(加 0,#228 说对,
    **但折算论证现在是唯一撑着它的东西**);`talent8` **结构性未学** ⇒ 那个 `nKillDamage` 项是**死代码**。
  - **十个 t20/t25 第一次定价并钉住**(datafeed 亲读五个 hero_id,**40/40 与 KV 快照逐位相同**,
    **不是从快照抄的** —— anchor §5 只在两者确实是两个源时才抓得到)。
  - **白担心的忧虑**:队列位置 **10,15,18,19,20,21,22,23** ——**位置不是等级,是第 N 个技能点**
    ⇒ 18 = 20 级、19 = 25 级分毫不差;20-23 **永不出队**。**「尾巴是死重」真、「尾巴卡队列」假。**
    第二十三条世界断言登记:技能点只在 1-15 与 10/15/20/25 发放。
  - **登记表而不是九次注释编辑**:`bots/` 按**等式**钉零未更正 + **反真空**(≥9 处引文必须存活,
    **不能靠删字通过**);`tests/` 是 **9 个文件的天花板 + 封闭名单**(可降不可升)。
  - **变异 12:11 抓 + 1 逃逸复核为真 no-op**。
  - **⭐ 学费**:**`git checkout --` 回滚的变异脚本连未提交的改动一起销毁**,抹掉了本轮对四个
    英雄文件的更正(只有 CM 活下来),七处编辑重做。**先存副本、从副本恢复,绝不从 git 恢复。**
  - **门(如实)**:`luacheck_gate.sh` **exit 0 / 0 警告**(容器里没有,脚本按 `lua-check` 自己装的);
    `tests/run_py_tests.sh` **41/0**;`focus_talent_anchor` **17/0**(14→17)、
    `level_premise_registry` **3/0**、`smoke_load` 3/0、`gate_claim_consistency` 10/0、
    `focus_t15_payoff` 10/0、`lion_t15_payoff` 13/0、`axe_t15_payoff` 13/0、
    `lion_hex_talent_slot` 9/0、`wk_fact_anchor` 13/0、`focus_level_claims` 17/0、
    `focus_build_level_legality` 6/0。
    **⚠️ 全量 `run_tests.lua` 未取到读数**(GH #124)——**如实记为没跑成,不是通过**;
    trunk 本有 2 处红(#216,不归本组);本轮 `bots/` 只有注释,不可能新增 Lua 失败。
  - **下一棒:本组欠三棒并已显式交出**(#238 §六)——① 重开 GH #166;② 给十个 t20/t25 定价
    (一个英雄一轮,skeleton_king 最后);③ 把 `tests/` 登记表从 9 往下做。
- 2026-08-26T23:20Z(报告 `iterations/reports/hero/20260826T232000Z.md`;**认领本组上一轮
  自己登记的下一棒(GH #228 §六.3),开了 GH #232**,新轴 **`ABILVALUE`** —— 同一个 `'value'`,
  读在**技能句柄**而不是天赋句柄上)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点
  不变量 ok、py **39/0**、Lua 快速检测器 9 文件 0 失败、待裁 queue 请求 0(open 35);
  cadence 洞**只在 strategy**(3.8h),**本组无洞**;
  owner 常设运维项球在批测台、P1/P2 在协同组、P3 在总监 ⇒ **本组无优先项**;
  [hero] open issue 全是本组已落地等裁定/等域;backlog `-5`/`-3` 是焦点五但都在等
  `hero-14`/`hero-13` 的域,`25`/`26` 章程写明「不动,等域」⇒ 走自选。
  **本轮 `bots/` 只加注释(73 行全 `--`)、零可执行行改动**;无新 gate id;`state.json` 新增
  `abilvalue_20260826`(`gated:false`);**零 AWS**;**不提 queue 请求**;**不申请入集**。
  - **⭐ 承重读数**:技能的 special value **按 `AbilityValues` 的条目名取键**,长形式里
    `value` 是**条目的内层键**不是技能的条目 ⇒ 只有**自己拥有字面 `value` 条目**的技能才答得出
    (**那正是通用天赋块的写法**)。**8 处站点 / 7 个技能,一个都没有 ⇒ 8/8 READS-ZERO**;
    **焦点五 0 处**(#228 探针 ② 的负结果复核成立)。
  - **⭐ 最该被拿走的一条:号跟 #228 相反。** #228 是 **21/21 死在安全侧**(引擎必折进基数,
    修它才重复计数);**这里什么都不折** —— 读数本身就是那个数,而那个数是 0。
    **5 UNDER**(0 伤害喂进 `J.CanKillTarget` ⇒ 斩杀分支永不开火)/ **1 OVER**
    (terrorblade 把血量代价读成免费)/ **2 FOLD**。**八分之二在安全侧,不是八分之八。**
  - **⭐ 那唯一的 OVER 上,「显而易见的修法」又错在第二个方向**:`health_cost_pct` = **20**
    是百分点,而那行**直接乘当前血量** ⇒ **只换键**把代价变成血量的 20 倍、闸**恒真翻恒假**。
    **两处编辑不是一处**,源码写死 + anchor §4 钉住。
  - **两根轴落在同一条分支上**(enigma 午夜凋零):本轴的静默 0 + **GH #223 §六.3 登记未定价**
    的错名(`MidnightPulseRadiusTalent` 绑 `enigma_6` = 黑洞伤害;真半径天赋是 `enigma_9`)。
  - **⭐ 序号承重**:站点身份 = (文件, 变量, **第几次读**),不带行号(#221)。
    `Malefice` 读两次而**两次修法相反** ⇒ 只按 (文件, 变量) 建键只能给两行同一条指令。
    **变异 M3 驱动后被抓,不是担心出来的。**
  - **变异 17 条 17 抓**(含「深度 4 内层键当条目」—— 会把结论翻成反面**并且报绿**;
    含往 `bots/` 塞新站点)。
  - **⭐ 学费(同族第三次)**:anchor 的 terrorblade 标记**红在它要保护的那条注释上**,
    因为承重那句话**跨了注释换行**。**便宜的修法是让它在源码里单独占一行,不是放松断言。**
  - **刻意没修**:五个英雄全非焦点,每处修复都是**真行为改动**(不是 #192/#223 那种可不 gate 的
    空指针守卫)⇒ 要 gate + 真实帧,而这五个**没有语料**。
    **「标注而不是修」不等于「看过了无害」—— 8 处里 6 处是活缺陷。**
  - **门(如实)**:`luacheck_gate.sh` **exit 0 / 0 警告**(容器里没有,脚本自己按 `lua-check` 装的);
    `run_py_tests.sh` **40/0**;新 py **23/0**;新 anchor **5/0**;`smoke_load` **3/0**;
    `gate_claim_consistency` **10/0**。
    **⚠️ 全量 `run_tests.lua` 未取到读数**(GH #124)——**如实记为没跑成,不是通过**;
    trunk 本有 2 处红(#216,不归本组)。
  - **下一棒**:本组不欠任何一棒。四条留给认领者见 GH #232 §六。
- 2026-08-26T20:20Z(报告 `iterations/reports/hero/20260826T202000Z.md`;**自选,开了 GH #228**,
  新轴 **`TALENTVALUE`** —— 不是句柄指向哪个天赋,而是**这个句柄有没有能力回答 `value`**)——
  自检 **worst exit 3**:UNLANDED 0、两条稳定版锚点不变量 ok、py **38/0**、Lua 快速检测器 9 文件 0 失败、
  待裁 queue 请求 0;cadence 洞只在 strategy(3.8h),**本组无洞**;
  owner 常设运维项球在批测台、P1/P2 在协同组、P3 在总监 ⇒ **本组无优先项**;
  [hero] open issue 全是本组已落地等裁定/等域(更新时间均早于本组上一轮);
  backlog `-5`/`-3` 是焦点五但都在等 `hero-14`/`hero-13` 的域 ⇒ 走自选。
  **本轮 `bots/` 只加注释、零可执行行改动**;无新 gate id;`state.json` 新增
  `talentvalue_20260826`(`gated:false`);**零 AWS**;**不提 queue 请求**;**不申请入集**。
  - **⭐ 承重读数**:天赋分两族,**只有一族拥有 `value`**。**专属天赋在任何 KV 里都没有自己的块**,
    载荷坐在**被它修改的技能自己的条目**里当子键 ⇒ 句柄**没有任何 special value**,读 `value` **静默 0**。
    **分区完全、名字即判别式**:974 引用里 65 有块 / 909 没有,**909 全部带 `unique`、65 一个都不带**。
    **调用点 21 处,21/21 是 UNIQUE**,焦点五占 4 处(axe×2 / lion / zuus)。
  - **⭐ 最该被拿走的一条:死项死在安全的那一侧,「显而易见的修法」才是回归。** 加成没有第二个住处
    ⇒ 引擎必然折进基数 ⇒ **基数早就对了,重指句柄会重复计数**。**这棵树已经为同一个折算下过一次注,
    还是一次已落地的修复**(#162 `lionsplash` 读的是 NO-BASE 的 `splash_radius`)——**21 处下的是相反的注。**
  - **唯一一处「无害」不成立**:Axe 淘汰之刃基数**写死**⇒ 折算够不到,**既短 +150 也短每级 25**;
    两者由同一个修复(= 已登记的 `hero-2`)一并收走,已在源码写明**接手者必须同刀删掉天赋项**。
  - **就地更正「结论对、理由错」**:Zeus 08-22 说 special value「叫 `bonus_arc_damage`」——**它不叫任何名字**;
    **同一句话在文件头部还有第二份拷贝,一并更正**。
  - **入口是三个「什么都没找到」**(见 backlog `-20`),其中②把 #162/VALSHAPE **自称看不见的那一半**买断了。
  - **三条方法教训**:(a)「字符串不许出现」的断言在**讨论**它的文件里根本用不了 ——
    第一版**在自己要保护的更正上当场变红**,改成蕴含式;**这是 #214 那条的对偶,同族反号**。
    (b) **工具自己的 fixture 抓到了工具自己的真 bug**(块边界切到下一个**天赋**块 ⇒ 吞掉邻居块体)。
    (c) 棘轮键**不许带行号**(#221);去掉行号后**集合**比较漏掉「同句柄新增第二处读数」,
    **那条变异在第一版上真的逃掉了** ⇒ 改**多重集**。
  - **门(如实)**:`luacheck_gate.sh` **exit 0 / 0 警告**(容器里没有,脚本自己装的);
    `run_py_tests.sh` **39/0**;新 py **25/0**;新 anchor **5/0**;
    被引用的三条邻居棘轮 `focus_t15_payoff` 10/0、`lion_hex_talent_slot` 9/0、`wk_fact_anchor` 13/0;
    `smoke_load` 3/0、`gate_claim_consistency` 10/0、`focus_talent_anchor` 14/0。
    **⚠️ 全量 `run_tests.lua` 未取到读数**(GH #124)——**如实记为没跑成,不是通过**。
  - **下一棒**:本组不欠任何一棒。四条留给认领者见 GH #228 §六。
- 2026-08-26T17:20Z(报告 `iterations/reports/hero/20260826T172000Z.md`;**认领上一轮自己留的名,
  开了 GH #223**,新轴 **`TALENTNAME`** —— 按**字面名**绑天赋的那一半)—— 自检 **worst exit 3**:
  UNLANDED 0、两条稳定版锚点不变量 ok、py 36/0、Lua 快速检测器 9 文件 0 失败、待裁 queue 请求 0;
  cadence 洞在 replay-check(3.7h)与 strategy(3.8h),**本组无洞**;
  owner P1/P2 球在协同组、P3 在总监 ⇒ **本组无优先项**;[hero] open issue 全是本组已落地等裁定
  (逐条读过 #136/#144/#165 的追评确认球不在本组),backlog 顶条 `-17c` 非焦点、`-5`/`-3` 在等域。
  **本轮改了 `bots/`**(1 helper + 1 行):**无新 gate id**(空指针检查,沿 #188/#192/#203/#206);
  `state.json` 新增 `talentname_20260826`(`gated:false`);**零 AWS**;**不提 queue 请求**。
  - **⭐ 承重读数**:两种取句柄的写法**失效方向相反** —— 按下标死于重排(#166/#214 已钉),
    按字面名死于**改名/移除**且**死得更硬**(答 **nil**,8 处里 7 处下一件事就对句柄调方法 ⇒
    撞坏掉的引擎错误处理器 ⇒ **Think() 半路停住、零打印**)。普查:**8 处绑定,1 处名字没了**
    (`hero_doom_bringer.lua` 的 `special_bonus_unique_doom_2`);**第二根轴**只有 silencer 做了 nil 检查。
    **判词取交集,只有 doom 一个**;6 处 PRESENT-but-unguarded **今天不是缺陷、不进棘轮**。
  - **⭐ 它为什么被走到:路是别人特意铺的。** 调用坐在 `IsAncientCreep()` 底下,而目标来自
    **全仓唯一的 tier-盲选择器** `J.GetMostHpUnitAnyTier` —— **GH #196 特意让它保持盲**,
    注释写着「这三条分支自己会处理远古」。⇒ **为保住三条分支写的 opt-out,喂给第一条分支一个空指针解引用。**
  - **天赋不是被挪走,是不再存在**:`can_target_ancient` 挂在 **`special_bonus_shard`** 下 ⇒ 管这件事的是魔晶。
  - **刻意没做的那一半**:Doom 五个 role 表全买魔晶 ⇒ 域非空,**但 `HasShard()` 不在本版 API 参考里**
    ⇒ **不在修掉第一个无法验证的绑定的同一轮里引入第二个**,登记为下一棒。
  - **⭐ 最该被拿走的一条:判据第一版朝着它唯一不许错的方向错了。**
    无条件往上看一行,把「**跑过**的检查」洗成下一句裸调的守卫 —— 被自己的 py 测试当场抓住;
    收窄后**还剩第二处**,落在全仓唯一真做了检查的站点上(`if` **开启**条件、不延续上一行)。
    ⇒ **只许过报、绝不许漏报,并且要拿它被允许错的形状去驱动它。**
  - **同族第二条**:M8 第一遍只被 py 抓到 —— Lua 那侧搜整段 header,而 header **把脚本名写了两遍**。
    改钉**首行逐字相等**后两侧都红。**推论:只要求「文本里出现过」的断言,在自我描述的文件里几乎必然是空的。**
  - **变异 14 抓 13 + 1 声明的对照 no-op 如实逃逸。**
  - **门(如实)**:`luacheck_gate.sh` **exit 0 / 0 警告**(容器里没有,脚本自己装的);
    `run_py_tests.sh` **37/0**;`talent` 39/0、`gate_claim` 10/0、`smoke` 3/0;
    **全量 `run_tests.lua` 两遍独立跑,都是 `2080 tests, 0 failures`**。
  - **⚠️ 上一条初稿误记为「全量没跑成」,已更正 —— 出错的方式比结论值钱**:
    **我把「缓冲区是空的」读成了「进程还没跑完」**(输出重定向进了文件,我却去 tail 任务包装器
    那 22 字节的 `[exited with code 0]`,而重定向目标是块缓冲的)。与 GH #200 / #171 同族:
    **一个没有内容的读数,和一个「没有」的读数长得一模一样**;分辨要看别的字段
    (退出码 / 文件大小 / 进程还在不在),而我一个都没看就下了否定判断。
    **第二条**:第一遍跑到一半我 rebase 了树,为消歧重跑一遍 —— 但 `git diff --stat` 只有
    **两个 markdown、都不在 runner 的读取集里** ⇒ 第一遍从没被污染。
    **判断中途变更有没有污染读数,查 diff 比重跑快一个量级。**
    **顺带**:初稿照抄的「trunk 本就有 2 处红」(GH #216)在本轮树上**已不成立**,已追评 #216。
  - **下一棒**:本组不欠任何一棒。三条留给认领者的线索见 GH #223 §六 / backlog `-19`。
- 2026-08-26T13:57Z(报告 `iterations/reports/hero/20260826T135747Z.md`;**自选,开了 GH #214**,
  新轴 **`TALENTSLOT`** —— 不是天赋轴本身,是**天赋轴的来源**)—— 自检 **worst exit 3**:
  UNLANDED 0、两条稳定版锚点不变量 ok、py 34/0、Lua 检测器 8 文件 0 失败、待裁 queue 请求 0;
  cadence 洞在 batch-desk(8.9h)与 replay-check(3.7h),**本组无洞**;
  owner P1/P2 球在协同组、P3 在总监 ⇒ **本组无优先项**;[hero] open issue 全是本组已落地等裁定,
  backlog 顶条 `-17c` 章程写明非焦点 ⇒ 走自选。
  **本轮 `bots/` 零改动**:无新 gate id、`state.json` 新增 `talentkv_20260826`(`gated:false`)、
  稳定版未漂移、**零 AWS**、**不提 queue 请求**。
  - **⭐ 先数了一遍仓库已经在读什么,而那次数数本身就是本轮的入口**:天赋名到下标 GH #166
    早钉过 ⇒ 直接开工会重做 08-24。**但 census 的槽位顺序取自 odota `talents[]` 一张展示列表**,
    而 `-17d`(#209)刚证过展示列表不是槽位列表。
  - **⭐ 承重读数(127 英雄,零 AWS)**:天赋是连续 8 条 `"AbilityN" "special_bonus_*"`,127/127;
    **起点不总是 Ability10**(kez/rubick 12、largo 15、invoker 17);
    **Valve datafeed == `npc_heroes.txt` 段,22/22 英雄、176 行逐行相同**,
    odota 与两者都不同的 **18/22** ⇒ **落后的是 odota,裁出来的**。
    parser 第一版写死 10,把 invoker 天赋报成 `invoker_emp`/`invoker_alacrity`/…,**零报错**。
  - **焦点五命中一处,且是活的那档**:WK slot [4] = `special_bonus_hp_300`(datafeed `value=300`),
    odota 说 `hp_350`;`['t15']={10,0}` → 下标 4 ⇒ 他实际拿的 t15。
    **行为影响是结构性的零**:`sTalentList` 由引擎运行期建出,**从不读镜像** ⇒ 错的是记录不是逻辑。
  - **⭐ 最该被拿走的一条:「两个源都这么说」里的第二个源说不出话。**
    仓库同时持有两个答案两天没人发现;08-24 记的「odota + the hero KV read hp_350」
    **不可能是两个** —— `npc_dota_hero_skeleton_king.txt` 一个天赋名字都没有(grep 命中 0),
    **而这句话就写在 census 自己 docstring 里、在引用它那行往上三段**。
    ⇒ **写「两个源一致」之前,先确认第二个源有没有能力不一致。**
  - **落地物**:census 改读 KV + `--cross-check`(**feed 不一致 ⇒ 退出码 3**,odota 不一致只是备注);
    快照重生成(**唯一变动的数据行就是 WK 那行**);anchor **新增 §5 与快照互钉**
    (**一致性棘轮不是正确性棘轮**,分工写进源码);新 `tests/test_talent_slot_census.py` 19 例;
    08-24 那条 `drive_by` **就地 RETRACTED**(不删原文)。
  - **变异 12 抓 11 + 1 对照如实逃逸**;两条第一版逃掉的如实修:
    ①「生成器不再声明来源」——**对生成物的断言看不见生成器**;
    ②「裁判源取不到时用 KV 回填」——**只断言返回值的测试看不见「输出在撒谎」**。
  - **门(如实)**:`luacheck_gate.sh` **exit 0 / 0 警告**(容器里没有,脚本自己装的,包名 `lua-check`);
    `run_py_tests.sh` **35/0**;新 py 文件 **19/0**;`test_focus_talent_anchor` 及五个相关邻居单跑全绿。
    **⚠️ `run_tests.lua` 全量跑了两遍(本树 + 干净 HEAD 的 worktree 并行),而 trunk 上就有 2 处红:**
    干净 HEAD F 在用例 **701/723**,本树 F 在 **703/725** —— **偏移恰好等于本轮新加的 2 个用例**
    ⇒ **同样两处、本轮净影响 0**。两处**单独跑都绿**(`test_itemtrip_supply_gap` / `test_l1_trade`)
    ⇒ **依赖单进程跨文件状态**,是 `-17d`「每文件新进程买到假 red」的**反向孪生**(过滤器跑买到假 green)。
    **不归本组**,**已单开 GH #216**(复现步骤 + 位置证据 + 「runner 即时打印失败名」的止血建议),证据在报告 §7。
  - **下一棒**:本组不欠任何一棒。留名给认领者(非焦点):**8 处按字面天赋名绑定**的站点从未与
    这份 KV 段对过,其中 **`doom_bringer` 正是 odota 陈旧的 18 个之一**。
- 2026-08-26T10:56Z(报告 `iterations/reports/hero/20260826T105631Z.md`;**自选 backlog `-17c` 的
  焦点五切片,开了 GH #209**,`GRANTSLOT` 的**另一半:槽位顺序本身**)—— 自检 **worst exit 3**:
  UNLANDED 0、两条稳定版锚点不变量 ok、py 32/0、queue 待裁 0;cadence 洞在 batch-desk(8.9h)与
  replay-check(3.7–3.8h),**本组无洞**;owner P1/P2 球在协同组、P3 在总监 ⇒ **本组无优先项**。
  **本轮 `bots/` 零改动**(前三轮连着改 `bots/`,这一轮不是):无新 gate id、`state.json` 无新增、
  **零 AWS**、**不提 queue 请求**。三处既有文件的改动是**纯注释**(diff 非注释行 **0**)。
  - **⭐ 承重读数一:那个「假设」有权威离线来源,而且是一次 GET 不是 127 次。**
    `-17c` 原估「每英雄一次 datafeed GET」;**先去证实来源,才发现 datafeed 根本没有 slot 字段**
    (只有 `name`/`ability_is_innate`/`ability_is_granted_by_*`,顺序是展示顺序)——
    **而按 datafeed 顺序读 Axe,大招落在 slot 3、`slot >= 4` 失败、下标 6 永不写、`abilityR` 是 nil**。
    真来源是游戏自己的 **`npc_heroes.txt`**(字面 `"AbilityN"`),而本仓库**早就在读同一个镜像**。
    **推论:找新数据源之前,先数一遍仓库已经在读什么。**
  - **⭐ 承重读数二:#203/#206 引用的槽表与 KV 逐行相同** —— Zeus 7 行、CM 6 行全对
    ⇒ **两个已落地候选的承重假设变成了测量**,且 §2 每轮重核抬头里的 `--  slot N  name`,
    patch 挪槽位 ⇒ **红的是那个候选**。
  - **⭐ 承重读数三:空槽是 `generic_hidden`,walk 留着它** —— 这是 `X.GetAbilityList`
    敢写死 `slot >= 4` + 下标 6 的**全部理由**。**顺带卸下 §26/#151 那条 LIMIT 的 n=1 腿**
    (Axe 大招 1/26 帧冷却):KV 直说大招在 slot 5、前两格是 dumper 滤掉的占位符。
    **断言一条没动,且仍然不许从语料推 index map。**
  - **结论:Axe/Lion 不需要第五个候选,而且是结构性的** —— 只读 1/2/3/6,下标 1..3 前面什么都没有。
    **判别式是量出来的**:同一循环里断言 **CM 的下标 4 会变**,否则「Axe/Lion 全绿」什么也没证。
  - **下一棒**:`-17c` 剩下的 **15 个非焦点英雄**已具名(GH #209 §四),**不归本组**,
    §4 已把这 17 个的集合钉成棘轮。
  - **变异 9 抓 8 + 1 对照如实逃逸**;M9 复核判为分工不是盲区(实测邻居棘轮抓得住)。
  - **⭐ 一次自己的量测事故:自造的 runner 买到一个假 red。** 每文件一个新进程的跑法让
    `test_cm_arcane_aura_passive.lua` 红了一条 armed 断言,**官方 runner 同文件 16/0 全绿**。
    `run_tests.lua` 抬头写着「the runner is the only supported entry point」。**别再自造 runner。**
  - **门(如实)**:luacheck **exit 0 / 0 警告**(7.9s,容器里已装,与 GH #205 一致);
    `run_py_tests.sh` **33/0**(含新增 11 例);`run_tests.lua` **全量没跑**(GH #124),
    跑的是**可复现 grep 出来的相关子集 28 文件 / 387 用例 / 0 失败**,
    **逐文件断言跑到了 >0 个用例**,**全部经由官方 runner**
    ⇒ **本轮 Lua 侧的说法是「相关子集 387 用例全绿」,不是「全量全绿」。**
- 2026-08-26T07:45Z(报告 `iterations/reports/hero/20260826T074500Z.md`;**自选 backlog `-17b`,
  开了 GH #206**,`GRANTSLOT` 的 **CM 那一半**)—— 自检 **worst exit 3**:UNLANDED 0、两条稳定版
  锚点不变量 ok、py 32/0;cadence 洞在 batch-desk(8.9h)、replay-check(3.7–3.8h)、strategy(3.5h);
  owner P1/P2 球在协同组、P3 在总监 ⇒ **本组无优先项**。
  **本轮改了 `bots/`,两个半边都有**:gated **`cmclone`**(turbo-only、**未 armed**、**不申请入集**)
  ⇒ 稳定版未漂移;**外加一处未 gate 的空指针检查**。`state.json` 新增 `cmclone_20260826`;
  **零 AWS**;**不提 queue 请求**。
  - **⭐ 承重读数 —— 而且它把 GH #203 绕开的那个谓词直接读出来了(单向)**:行为 dumper 走
    **同一个** `m_vecAbilities`,过滤器就是 `if hidden { return false }` ⇒ **名字出现在某帧的
    ability 数组里 = 那一帧 `m_bHidden` 为 false**。**存在是读数;缺席仍是析取**,全程没把缺席当读数。
    分母:WK innate **31/31**、Lion **23/23**、`zuus_lightning_hands` **1 帧** ⇒ 管道 innate 和 grant
    都显示得了。**CM 51/51 帧恰好 4 个真技能,两个可选技能都是 0** ⇒ 都 hidden ⇒ 都被丢
    ⇒ **水晶分身在每一局、整局都够不着**,而这是**下标算术**不是任何人的决定。
  - **⭐ 语料证实了槽位顺序而不是假设它**(#203 只能声明是假设):大招只在 `slot >= 4` 才进固定
    下标 6,CM 只有 3 个常显技能 ⇒ 可选技能若不占大招前面的槽位,`abilityR` 就不可用;
    **她的大招 51 帧里 10 帧在冷却** ⇒ 反驳成立,且写成**可执行的反事实**而非散文。
  - **⭐ 第一版模型被自己打掉两处**:① 占位符**先被按名字接住**(`aba_skill.lua:5` 是 file-local,
    名字检查在丢弃规则**之前**)⇒ 下标 4 是 `generic_hidden` 不是 nil;
    ② **`#` 的边界跟着表变,不跟着 VM 变** —— 本 VM `#{1,2,3,[6]}` 答 **3**,而 Zeus 那侧
    **同一个 VM** `#{1,2,3,4,[6]}` 答 **6**。⇒ **「本 VM 答 6」不可在英雄之间搬运。**
    **所以未 gate 的空指针检查是保险不是修复**,源码 / issue / `state.json` 三处同口径,
    并**钉成断言**防止下一份摘要把它升格。
  - **顺带一次现场自纠(没进 issue)**:probe 里一度把 `generic_hidden` 读成未定义全局、
    准备报成缺陷 —— 它是 local,probe 自己的 chunk 里才是 nil。**报之前先 grep 定义。**
  - **变异 12 真 12 抓 + 1 对照如实逃逸**;既有棘轮 `test_focus_innate_index_anchor.lua` §4
    **自己写着「加了 nil guard 就删掉并说明」,照做**,并同步修订它 §2 那句「离线读不到 IsHidden」。
  - **门(如实)**:luacheck **exit 0 / 0 警告**(容器里没有 luacheck,**本轮自己装的** ——
    与 GH #205 一致:装得上,只是没人装);`run_tests.lua` **全量没跑**(GH #124),跑的是
    **可复现 grep 出来的相关子集 51 文件 / 651 用例 / 0 失败 / 0 个零用例文件**,
    **逐文件断言跑到了 >0 个用例**(GH #200 的分母塌陷补丁)
    ⇒ **本轮 Lua 侧的说法是「相关子集 651 用例全绿」,不是「全量全绿」**。
    顺带一个具体样本:`test_itemdesire_world_assertion.lua` 一个文件就跑了约 9 分钟(通过、且不在
    本次作用面上),**它一个人占了整份子集墙钟的大头** —— GH #124「全量跑不完」的一个可指名的成因。
- 2026-08-26T05:02Z(报告 `iterations/reports/hero/20260826T050213Z.md`;**自选,开了 GH #203**,
  新轴 **`GRANTSLOT`**)—— 自检 **UNLANDED 0**、两条稳定版锚点不变量 ok、py 32/0;cadence 洞在
  replay-check(3.7–4.2h)与 strategy(3.5h);owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项。
  **本轮改了 `bots/`,而且两个半边都有**:gated `zusbind`(turbo-only、**未 armed**、**不申请入集**)
  ⇒ 稳定版未漂移;**外加两处未 gate 的空指针检查**(沿 #188/#192「被迫的修复不 gate、策略 gate」)。
  `state.json` 新增 `zusbind_20260826`;**零 AWS**;**不提 queue 请求**。
  - **⭐ 承重读数 —— 把一个读不到的谓词枚举掉,而不是猜它**:丢弃规则里的 `IsHidden()` 在游戏 VM 外
    永远读不到,于是把三个可选技能的丢弃决定枚举成 **2³ = 8 个世界**,每个世界都拿**出货的**
    `J.Skill.GetAbilityList` 在 Zeus 真实槽位顺序上跑:**`[5]` 是静电场的世界 0/8**
    (`zuus_lightning_hands` 2、**nil 4**、`generic_hidden` 2),**`[4]` 是 Nimbus 的恰好是保留 grant
    的那 4 个**。⇒ `abilityAS` **在任何世界里都不是它唯一消费方以为的技能**;`abilityD` 对不对
    压在读不到的谓词上;**4/8 的 nil** 就是未 gate 半边的全部理由。
  - **⭐ 本轮最值钱的一条是自己的假设被自己证伪**:原假设「杖/魔晶技能加载时不存在 ⇒ 句柄恒 nil」
    被普查打掉 —— 全仓**已有 40 处**按字面名字取 grant 技能的**出货**站点,且 KV 里这些技能的
    mask **自带 `HIDDEN`**(引擎出生即造好、只是藏着)。**先数「多数人怎么写」,再决定要不要把
    少数写法叫缺陷。** 轴在证伪之后才露出来:**按名字取没问题,按下标取才有问题。**
  - **声明出来的依赖**:walk 写完固定下标 6 后**还在 append** ⇒ 后续 `table.insert` 对**带洞的表**
    问 `#`,**Lua 5.1 未定义**;本 VM 答 6,**答 4 的 VM 会把保留的静电场放到下标 5**。
    钉成 world assertion,**而它本身就是「别再数下标」的论据**。
  - **变异 9/10 抓 + 1 对照如实逃逸**;**逃掉的 M10 复核后判为分工不是盲区**(它变异的是 walk 的
    丢弃**机制**,本文件枚举的是**结果**;**实测**它被 `test_focus_innate_index_anchor.lua` §3 抓着)。
  - **两个既有棘轮当场红 ⇒ 重新指向而非放宽**(其中 §4 那条自己写着「加了 nil guard 就删掉并说明」,
    照做并同步改了抬头散文,免得散文比代码旧)。
  - **门(如实)**:luacheck **exit 0 / 0 警告**;`run_py_tests.sh` **32/0**;
    `run_tests.lua` **全量没跑**(GH #124),跑的是**可复现 grep 出来的相关子集**
    **47 文件 / 590 用例 / 0 失败**,**逐文件断言跑到了 >0 个用例**(现在 runner 自己也按 GH #200
    对 0 用例抬 exit 2,双保险)⇒ **本轮 Lua 侧的说法是「相关子集 590 用例全绿」,不是「全量全绿」**。
- 2026-08-26T01:52Z(报告 `iterations/reports/hero/20260826T015238Z.md`;**自选 backlog §18 Lever C,
  开了 GH #199**)—— 自检 **UNLANDED 0**、稳定版两条锚点不变量全 ok、py 31/0;cadence 洞在
  replay-check(3.7–6.1h)与 strategy(3.5h);owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项;
  open 的 `[hero]` issue 下一棒仍全是 queue 归档扫描或归 harness。
  **本轮改了 `bots/`,且是 gated 行为改动**(前一轮那次是未 gate 的点改冒号,这一轮不是):
  新 helper `X.GetRoshanManaFloor` + 分支改读它,gate **`wkrosh`**(turbo-only、**未 armed**、
  **不申请入集**)⇒ **稳定版未漂移**;`state.json` 新增 `wkrosh_20260826`;**零 AWS**;
  **不提新 queue 请求**(域的棒子早在 `hero-10`,本轮只往它 `result` 加指针)。
  - **08-23 那轮的「下一轮建议」逐字兑现了**:候选形状 `wkrosh`、且**写之前先读了
    `X.ShouldSaveMana`** —— 结论是**不造第二个守卫,而是把它已有的那条预留在打肉时无条件化**。
  - **⭐ 承重读数,而且它绕开了那个问不了的域**:34 个真实 WK 帧里清得过 600 的是 **0**,
    且这 34 帧最大的 `max_mp` 是 **459** ⇒ **满蓝也够不着**。域(`GetActiveMode` 不进 .dem)
    离线永远问不了,**但蓝这一维问得了**,而光这一维就把分支在整份档案上关死。
  - **armed 腿 22/29 放行、7/29 拒绝**,拒的全是重生 rank 1 的 220 预留在拒 ⇒ **是预留不是洞**
    (写成断言不是散文)。重生 **220/110/0**、**rank 3 免费**,所以 armed 下界 16 级后塌成法术单价本身。
  - **⚠ 0/34 是「这份语料上为空」不是「游戏里罕见」**:34 帧全 ≤12 级(10 分钟封顶),
    蓝池 18–19 级才越过 603 ⇒ **GH #108 放宽到 25 分钟之后切的语料先重扫再引用**。
    蓝耗是**帧外锚**(mock 对任何句柄 `GetManaCost` 答 0,已断言)。
  - **⭐ 最值钱的一条是自己的方法事故:第一条「对照」变异不是对照** —— 改 helper 里一个局部名
    (纯 no-op)**被文本棘轮抓了**;换成改 `X.ConsiderQ` 里另一个局部才如实逃逸。
    **一份同时有文本棘轮和行为断言的测试,对照必须挑文本棘轮够不着的位置,否则「变异全抓」是自证的。**
  - **第二条**:`src:sub(src:find(p))` 拿回的是**匹配到的那一截**(find 返回两个值)⇒ 取函数体只拿到
    25 个字符,断言在**正确的源码上红了**。这次是红所以立刻发现;**同一个笔误落在否定式断言上会永远绿**。
  - **`test_wk_roshan_mana_ceiling.lua` 的棘轮当场红了 —— 那是它的职责**,已**重新指向而非放宽**。
  - **门(如实)**:luacheck **exit 0 / 0 警告**;`run_tests.lua` **全量没跑**(GH #124);
    可复现子集(引用 `skeleton_king` 的 + 文件名带 `wk` 的 + smoke/gate_claim/jmz_refs/activemode)
    **57 文件 / 611 用例 / 0 失败**,且**每个文件都断言跑到了 >0 个用例**(上一轮那次分母塌陷的补丁)。
    ⇒ **本轮 Lua 侧的说法是「相关子集 611 用例全绿」,不是「全量全绿」。**
- 2026-08-25T22:56Z(报告 `iterations/reports/hero/20260825T225641Z.md`;**认领 GH #189,
  开了 GH #192(本组新轴)+ GH #193(转协同组)** —— 自检 **UNLANDED 0**,cadence 洞五组都有;
  owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项。**本轮改了 `bots/`,前七轮的「零行为改动」
  在这一轮中断了**:八处 OVER 实参删除**逐字节零行为**,而 `hero_queenofpain:503` 的
  点改冒号**是行为改动、未 gate**(依据 #188 先例;**总监若判定该走 gate 请退回,我改成 gated 重提**)。
  **无新 gate id、`state.json` 无新增、零 AWS、不提 queue 请求。**
  - **#189 结案**:采纳方向 (1),并把 OVER 半边**八处一起扫空**(传的全是字面常量 ⇒ 删掉逐字节
    等价)⇒ `call_arity_census.py` 的 OVER 半边**现在是空的**,`test_call_arity_census.py` §3
    从「钉那个缺陷」改成「**守住那个空**」。**⭐ 多给了一条 #189 没有的、就事论事的理由**:
    5 秒是本仓库回答「这波爆发会不会打死我」的**统一窗口**,而 8 秒的总伤害作为撤退时的爆发估计
    本身偏大 ⇒ **被丢掉的那个 8.0 本来也不是更对的那个数**。
  - **新轴 `CALLFORM`** —— 由来是读 #189 时看见 arity 普查的 `census()` 第一行
    `if name not in decls: continue`:**解析不到声明的名字连 stats 都进不去**。而
    `attempt to call a nil value` 配上**坏掉的引擎错误处理器** ⇒ **这种崩溃不自报家门**,
    症状只是某个 bot 的 Think 从半路停住。**275 文件 / 2530 声明名 / 28364 点调用 +
    20774 冒号调用:NILCALL 7、SELFLESS 13、BOUND 0。**
  - **⭐ 两处有牙齿**:① `hero_queenofpain:503` 的 `abilityE.IsFullyCastable()` 是**点**,
    而同文件这个句柄**另外 9 处全是冒号**(#154 判别式)⇒ **已修**;
    ② `mode_farm_generic:710` 的 `J.Site.IsCampDangerous` —— **整棵树没有这个声明**、
    `aba_site` 是无 metatable 的平表 ⇒ **未 gate 的活 nil 调用**,farm 中每次「最近野点近 200+」
    的帧都撞上 ⇒ **有意不改**(协同组的文件 + 农场策略决定),**已单开 #193**,
    并写明**可能与 owner P1 第 1 条同链路 —— 是线索不是结论**。
  - **其余 18 处逐条读 body 判良性**;**BOUND 的 0 是排除了 ts_libs 的 `function T.m(self,...)`
    这个假阳性之后的**。
  - **⚠ 单向判据 + 量到的反例**:解析按名字**最后一段**全树找 ⇒ **解析得到什么都不证明**。
    同文件里 `enemy.IsHero(` 是 finding 而**一模一样缺陷**的 `bot.GetUnitName(` 不是,
    只因别处声明了 `CDOTA_Bot_Script:GetUnitName`。**⭐ 焦点五 0 处,但这个 0 比 #187/#179
    的弱一档**(那两根轴看字面量、无解析盲区),**别引成「焦点五的调用都对」**。
  - **变异 7/7 抓 + 1 对照(Lion 39 处局部改名)如实逃逸**;arity 侧另有 **6/6 抓 + 1 对照逃逸**。
  - **⭐ 本轮最值钱的一条是更正**:这一类**已有测试且每轮都在跑**
    (`test_no_undefined_jmz_refs.lua`,GH #48),它没抓到只因 **pattern 在第一个点就停**
    ⇒ `J.<子表>.<名字>` **整片是盲区**(78 个名字)。已钉成断言;加深它的人会被指回 #192/#193。
  - **⭐ 最贵的方法教训**:**变异回滚用 `git checkout --` 会连没提交的修复一起抹掉**,
    而污染的表现是**"更红"** —— 方向与逃逸相反,**没人会因为红而起疑**;
    **回滚手段本身也是实验器材**。第二条:`assert count==1` 没命中时**变异没落地**,
    脚本却打印 **ESCAPED** ⇒ **没落地与被逃逸输出一模一样**。
  - **门(如实)**:luacheck **0 警告**;`run_py_tests.sh` **30/0**;
    **`run_tests.lua` 全量没跑出结论** —— 容器原本没有 lua5.1(本轮装上),全量跑到 50 分钟
    被 timeout 杀掉,而 runner **全缓冲** ⇒ **被杀时一个字都没留下**(GH #124 说的就是这个;
    **教训:在这个容器里跑全量,要么给足 >100 分钟,要么别用一个会被 kill 的单进程 ——
    被 kill 的全缓冲进程留下的信息量是零**)。改跑**可复现地 grep 出来的相关子集**
    (引用了本轮改动文件或 helper 的测试,含 `smoke_load` / `gate_claim_consistency` /
    `no_undefined_jmz_refs` / `item_name_census`):**49 文件 / 636 用例 / 0 失败**,
    rebase 到 main 之后重跑过。**⇒ 本轮 Lua 侧的说法是「相关子集 636 用例全绿」,
    不是「全量全绿」。**
  - **⭐⭐ 同轮第三条教训,也是最难堪的一条**:第一次报的「48 ok」是**塌掉的分母** ——
    子集脚本给 runner 传 `^name$`,而 runner 对**文件名**做 Lua `match` ⇒ 匹配不上
    ⇒ **48 次全跑了 0 个用例**,而脚本判据是 `grep -q "0 failures"`
    ⇒ **「一个都没跑」被逐字读成「全过」**。靠 rebase 后手工重跑时输出里那句
    `0 tests, ... 188 files skipped` 才偶然发现。**我在同一轮里刚给两个新工具写完分母断言,
    转头就在自己的验证脚本上栽了同一个坑** ⇒ 教训不是"要写分母断言",是
    **「分母断言要写在每一个会产出读数的东西上,包括临时写的验证脚本」**。
  - **如实记一笔**:`run_py_tests.sh` 第一次跑报 `test_call_arity_census.py` 1 failed,
    **单独跑 exit=0、随后两次整套重跑 30/0**,原因未查明(已排除"另一个测试在改被扫的树":
    tests 对 `bots/` 全是只读)。**不编原因,登记为一次未复现的失败。**
- 2026-08-25T19:55Z(报告 `iterations/reports/hero/20260825T195519Z.md`;**自选,GH #187 已开**
  —— 自检 **UNLANDED 0**,cadence 洞五组都有;owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项;
  open 的 `[hero]` issue 下一棒仍全是 queue 归档扫描或归 harness。**本轮零行为改动**:
  `bots/` 一行未改、**无新 gate id**、`state.json` 无新增、**不提 queue 请求**、
  **稳定版未漂移**、零 AWS。**刻意换轴** —— 前六轮的轴全落在**技能**上,这一轮挪到**物品**
  与**加点表**:
  - **`ITEMID`** —— 物品名进引擎只有两扇门,**两扇门对错名字都只回答沉默**
    (`FindItemSlot`/`HasItem` 答 −1/false,与「没这件装」一模一样;买单里的未知名被
    `Item.GetBasicItems` 的 `Item[v] == nil` 分支**原样转发**给采购层)。
    **275 文件 / 544 在售名 / 186 宏:10 个未知名字、11 站点(6 LOOKUP + 5 PROBE)。**
  - **⭐ 焦点五 0 处,而这个 0 是核验**:本轴看**字面量**,没有句柄解析那一步可怀疑
    ⇒ 与 #162/#177 的 UNRESOLVED 不同,**对写死的名字没有盲区**。
  - **活的一处**:`aba_site.lua:1488` 的 `item_gleipnir`,**真名 `item_gungir`** ⇒
    恒真合取项 ⇒ `netWorth < 18000` 时该分支无条件 return true。**有意不改**(域是 127 个英雄)。
  - **`LVLQUEUE`** —— `sSkillList` 是队列,花它的代码**头部阻塞**(最后那个 `else` 的
    `table.remove` 被 `botLevel > 25` 守着)⇒ **来早了的条目停在队头,后面每个点跟着停**。
    **七条表全部合法**;唯一共同例外(大招 `[6,12,17]` 而三级要 18)**登记 NON-DEFECT
    且理由是检出来的**:17 级时三个基础技能全部满级 ⇒ 那个点没有合法去处。
  - **⭐ 最贵的方法教训(量到的)**:内联写的「其它技能都满了」被放宽变异**逃逸**,
    因为真值离界四级、**树上没有相邻的合法形状**能证伪它(§24 盲区)⇒
    **§24 要逐条判据地问,不是逐文件地问**。抽函数 + 合成输入后 6/6 抓。
  - 交付:`item_name_census.py` + 快照 `tests/mock/item_names.lua` +
    `test_item_name_census.lua`(5/5 抓)+ `test_focus_build_level_legality.lua`(6/6 抓),
    两个对照变异如实逃逸,**源码侧变异各一**(Lion 买单塞假名 / CM 表大招提前一行)当场红。
- 2026-08-25T16:56Z(报告 `iterations/reports/hero/20260825T165651Z.md`;**自选,GH #183 已开**
  —— 自检 **UNLANDED 0**,cadence 洞五组都有;owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项;
  open 的 `[hero]` issue 仍**一条都不可在桌面推进**。**本轮零行为改动**:`bots/` 一行未改、
  **无新 gate id**、`state.json` 无新增、**稳定版未漂移**、零 AWS;提了 queue **`hero-18`**
  (归档扫描、零 EC2、不申请专波)。**刻意换轴** —— 新轴 **`PTSTAT`**:
  **一族代码跟自己完全自洽,而它的对错整体押在一个从没写下来、桌面也读不到的引擎事实上。**
  - **焦点五 19 处排队施法每一处的第一行都是 `J.SetQueuePtToINT`**(axe 3 / zuus 6 /
    wk 2 / lion 3 / cm 5);执行出货代码量出的按键表 —— 力量腿 **1** 下、智力腿 **2** 下、
    敏捷腿 **0** 下 ⇒ **该族唯一接受的状态是 `ATTRIBUTE_AGILITY`**,而它五个名字都写着 INT。
    机制:`J.IsPTReady` 比较前**把自己的入参 INT 改写成 AGI**。
    **⭐ 这条不依赖切换方向,也不依赖 mock 常数的具体值。**
  - **helper 的另一半必要且正确**:`ActionQueue_*` 追加 + 模式 Think 先跑 ⇒
    里面的 `Action_ClearActions(false)` 是施法不被模式移动指令压住的原因。**别整条读成缺陷。**
  - **两个方向都算过**:A 收敛到 AGI 停住(从智力腿出发**先丢掉**那份法力);
    B 是 STR↔INT **二循环永不收敛**(每 tick 排 1–2 个道具指令)。
    **方向无关断言:INT 在两个方向下都不是稳定态。**
  - **⭐ 反面假设同样意味着有人错**:全仓 6 处读数分两派(三处对调 INT↔AGI 且内部自洽,
    `SetQueueSwitchPtToINT` 与 `hero_morphling.lua:959` 照原值用);
    `BOT_API_REFERENCE.md:1616` 站在「照原值」一边。引擎返真值 ⇒ 这族名字全反;
    引擎真对调 ⇒ 补偿正确但 morphling 的属性记账错。**两边不可能都对。**
  - **⚠ LIMIT**:GH #133 的 270/270 读 0 ⇒ **fixture 侧构造性不可判**;
    任何 fixture 绿色**不许**当佐证(已写成断言,不是散文)。
  - `tests/test_pt_switch_target.lua` 14 例全绿,**变异 6 次:5 条真变异 5 抓 + 1 条对照
    (整函数改局部名)如实逃逸** ⇒ 钉结构不钉拼写。
  - **三条教训**:① 对照变异**必须落到该落的每一行**(半个函数改名造出 nil 全局、红 6 条);
    ② **mock 的 ALL_CAPS 常数惰性铸造**,`install()` 前读到 nil,而 nil 属性两条分支都不匹配
    ⇒ **读起来跟「代码什么都没排」一模一样**;③ **「几处读数」先 grep 再写进断言**
    (我写 4,真值 6,多出来的 morphling 恰是「两派矛盾」的第二个例子)。
- 2026-08-25T13:54Z(报告 `iterations/reports/hero/20260825T135400Z.md`;**自选,GH #179 已开**
  —— 自检:**UNLANDED 2 条,都是总监的**(`08ed7c2`/`fc79986`,GH #159 `tpreach`,停在
  `origin/claude/compassionate-albattani-4zcohy`,已在报告里点名);cadence 洞五组都有;
  owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项;open 的 `[hero]` issue 仍**一条都不可在
  桌面推进**。**本轮零行为改动**:`bots/` 一行未改、**无新 gate id**、`state.json` 无新增、
  **不提 queue 请求**(桌面可证的负结论,没有需要 (a) 证据的行为)、**稳定版未漂移**、零 AWS。
  **刻意换轴**:前六轮都在问「某个数/某个 key/某个槽位/某条施法指令对不对」,
  这一轮问的是 **读到的那个数,是不是那个数**):
  **`GetSpecialValueInt` 读一个小数会静默截断/舍入;一个只有 `special_bonus_*`、
  没有基础 `value` 的 key,对不满足条件的施法者恒读 0 —— 而 #162 那把 key 尺子
  对这两件事结构性失明,因为它只问「key 在不在」。**
  - **128 文件 / 700 处读数:COLLAPSE 2、LOSSY-INT 5、NO-BASE 4、MISSING 25**(老轴复现)。
  - **⭐ 焦点五 Int 读小数 0 处 —— 空的;而那个空是一次核验**:唯一的 NO-BASE 就是
    #162 自己放进去的 `lion splash_radius`(base 无 + `special_bonus_scepter = 325`,
    消费方在 `HasScepter()` 内)⇒ **修复成立**,而 key 普查**分不出「修好了」和
    「换了一个静默的 0」**。`test_lion_r_splash_radius_key.lua` §5 的散文第一次被机器检。
  - **新工具** `special_value_shape_census.py` + 快照 `tests/mock/special_value_shapes.lua`
    + 源码棘轮 `tests/test_special_value_shape.lua`(10 例,6 变异 6 抓、其中一次先逃逸)。
  - **⭐ 三条教训**:① **解析器丢 key 与「没有这个 key」读起来一模一样** —— 第一版会把
    #162 的修复误报成「也是个 0」,读原始 KV 才拦下(#177 同族)⇒ 配 `--self-test`;
    ② **self-test 自己也会不足**:`no_base` 用例的子行把 key 重新登记 ⇒ 测不到「块打开时登记」,
    补空块/纯嵌套两例;③ **子串判据会放跑改名变异**(`'lionsplashX'` ⊃ `lionsplash`),
    要**带引号**钉。
  - **加固要报「没变什么」**:`kv_keys` 逐行数括号后 128 英雄里只有 largo 不一致、
    **零判定翻转**、快照逐字节不变 ⇒ **保真度修复,不是缺陷修复**(写进 docstring,免得被引成 bug)。
  - **⚠ LIMIT**:mock 对 `GetSpecialValue*` 一律答 0 ⇒ **本轴与 #162 轴在 fixture 里都不可判**,
    本轮任何一句都不是行为证据。
- 2026-08-25T10:58Z(报告 `iterations/reports/hero/20260825T105832Z.md`;**自选,GH #177 已开**
  —— 自检无 OFF-TRUNK(只有各组都有的 cadence 洞);owner P1/P2 球在协同组、P3 在总监 ⇒
  本组无优先项;open 的 `[hero]` issue 仍**一条都不可在桌面推进**(#136/#150/#151/#154/#162/
  #170/#173/#175 的下一棒全是 queue 归档扫描或归 harness;#165/#166 是本组刚做完的)。
  新 gated id **`cmaurapassive`**(turbo-only,**未 armed**,**不申请入集,先买域** `hero-17`);
  登记 `state.json:cmaurapassive_20260825`;backlog 新增 §-11;**稳定版未漂移**;零 AWS。
  **刻意换轴**:前五轮问的都是**一个数值值多少**(常数 / 被改名的 key / 槽位 / 表的维度 /
  一个 API 调用读哪个字段),这一轮换成问 **文件写下的施法指令,引擎接不接得住**):
  **`Action*_UseAbility` / `...OnEntity` / `...OnLocation` 是三条不同的指令,
  `AbilityBehavior` 位决定接哪一条,而 `DOTA_ABILITY_BEHAVIOR_PASSIVE` 一条都不接;
  `hero_crystal_maiden.lua` 的调度第一条分支正是给一个被动技能下 `UseAbility` 再 `return`。**
  - **⭐ 值钱的不是「有一处错」,是「今天代价为零」这件事本身**:分支在上游就死了
    (`J.CanCastAbility` 的 `IsPassive()`)⇒ **整条判断只压在一个桌面读不到的引擎谓词上**;
    它为假的代价**不是浪费一次施法** —— 分支跑在**最前**且 `return` ⇒
    **每个符合条件的 tick 里新星/冰封禁制/冰晶分身/极寒领域四条一起被吃掉**。
  - **新工具 `cast_shape_census.py` + 冻结快照 `tests/mock/ability_behavior.lua`**:
    **755 条施法指令 / 493 可解析 / 11 处 PASSIVE-DISPATCH(10 个文件),焦点五恰好 1 处**;
    22 处 SHAPE-MISMATCH **故意判得更弱**;**262 处 UNRESOLVED,其中焦点五 15 条里占 12 条 ——
    axe/zuus/lion 一条字面量绑定都没有,对本普查结构性不可见** ⇒ 「恰好一处」是**下界**。
  - **改动形状**:出厂谓词是**第一句**且自己 `return false` ⇒ gate-off **结构性等价**;
    **方向单一**(armed 唯一出口 `false`,按 `return true` 处数钉住);
    行为位读 0 或常量缺失 ⇒ 落回出厂**不发明 flag 值**(#162)。**有意没删死分支**(#170 处置)。
  - **⚠ LIMIT 量出来的**:真实 CM 帧上 `IsPassive()` 读 **false**、`GetBehavior()` 读 **0**、
    `CanCastAbility` 为 false 的**真因是 `IsActivated()`**(mock 默认值,#133/#145 族)
    ⇒ **两边一致是巧合,不得当作佐证**。
  - 测试 `tests/test_cm_arcane_aura_passive.lua`:16 例,**变异 8 次 6 抓 + 2 条声明的逃逸**。
    **⭐ 一个 mock 默认值把正确实现判红**:`bot_api.lua` 给不认识的 ALL_CAPS 全局发**顺序整数**
    ⇒ mock 的 `DOTA_ABILITY_BEHAVIOR_*` **不是互不相交的 2 的幂**,
    `band(NO_TARGET, PASSIVE) == PASSIVE` 读出 true;**造反例要 `bnot` 清位,别点另一个 flag 的名字**。
    另两条:**逃逸先复核语义**(`== f`→`~= 0` 是真 no-op,PASSIVE 是单个 bit);
    **源码棘轮钉结构不钉拼写**(对照变异纯改名被抓,已把断言改成数守卫处数)。
  - **顺手修的工具 bug**:KV 解析器「`{` 独占一行」的写法在 brewmaster 上**失步并静默丢掉
    该文件后面全部技能**(计数 10 → 11)。**会对文件后半段静默沉默的解析器比会报错的更坏。**
- 2026-08-25T07:49Z(报告 `iterations/reports/hero/20260825T074901Z.md`;**自选,GH #175 已开**
  —— 自检无 OFF-TRUNK(只有各组都有的 cadence 洞);owner P1/P2 球在协同组、P3 在总监 ⇒
  本组无优先项;open 的 `[hero]` issue 仍**一条都不可在桌面推进**(#136 卡 `hero-6`;
  #150/#151/#154/#162/#170/#173 的下一棒全是 queue 归档扫描或归 harness;#165/#166 是本组
  刚做完的)。新 gated id **`zusboltcap`**(turbo-only,**未 armed**,**不申请入集,先买域**
  `hero-16`);登记 `state.json:zusboltcap_20260825`;backlog 新增 §-10;**稳定版未漂移**;零 AWS。
  **刻意换轴**:前四轮问的是常数值 / 表达式怎么解析 / 槽位指向谁 / 表的维度,
  这一轮问的是 **一个 API 调用本身读的是什么**):
  **`ability:GetAbilityDamage()` 只读技能的顶层 `AbilityDamage` 字段,而现代 Dota 早把
  逐级伤害搬进了 `AbilityValues` —— 全仓 128 英雄里只有 16 个技能声明了非零值,
  `bots/` 的 58 处读数里 46 处可证为 0。而 Zeus 那个 0 不是「小一点」,是换了一个谓词。**
  - **⭐ 同一个 0,同一个文件,两个相反方向**:`X.ConsiderW2` 把它交给 `FindAoELocation`
    的 `nMaxHealth`,而 **0 = 不过滤血量**(`BOT_API_REFERENCE.md:1288`)⇒ 那条自己取名
    `nCanKillHeroLocationAoE` 的斩杀分支**实际问的是「射程内有没有敌方英雄」**,
    以 `DESIRE_HIGH` + 120–135 蓝回答「有」(**放宽**);同一个 0 喂给
    `J.WillMagicKillTarget` 时**把击杀分支整条杀死**(**收紧**)。
    **⇒ 静默的 0 往哪边切必须逐个调用点读 —— #162 那把尺子答不了的那一半。**
  - **与 GH #173 / backlog §4 是同一笔账的第三条线索**:#173 是「蓝花在一个不存在的击杀上」,
    本条是「花在一个**根本没问过能不能杀**的施法上」,§4 量的是「斩杀窗口来的时候没蓝」。
  - **新工具 `tools/agent/ability_damage_census.py` + 冻结快照 `tests/mock/ability_damage.lua`**
    (每英雄一次 GET,零 AWS;测试不上网)。**判据比 #162 强的一处:不需要解析句柄** ——
    `hero_<h>.lua` 的读数只可能取在 `<h>` 自己的技能上。**反向照旧什么都不证明。**
  - **只修放宽那一处**,`X.GetBoltKillHealthCap`(出厂表达式是最后一句 ⇒ gate-off 结构性等价;
    `<= 0` 落回出厂不发明默认值 ⇒ **armed 不可能更宽**;**方向单一**)。
    **有意没折进 `( 1 + GetSpellAmp() )`**;**核对为正确、有意没动** `nRadius = 325`(KV `spread_aoe`)。
  - **⚠ LIMIT 量出来的**:两条腿离线都读 0,且**出厂腿读 0 的原因与 KV 无关 —— 一致是巧合**;
    `FindAoELocation` 不在 mock 里 ⇒ **开火侧没有 fixture,而这个「没有」是量出来的**。
  - 测试 `tests/test_zuus_bolt_kill_cap.lua`:11 例,**变异 11 次 10 抓 + 1 条对照逃逸**。
    **⭐ 一次瞄歪的变异**:`perl -0pi` 非全局 `s///` 只改了**注释里的第一处**,
    全绿看着像逃逸其实**没落到代码上**;**读绿/红之前先 grep 变异落在哪一行**(#170 同族)。
- 2026-08-25T04:53Z(报告 `iterations/reports/hero/20260825T045337Z.md`;**自选,GH #173 已开**
  —— open 的 `[hero]` issue 仍**一条都不可在桌面推进**(#136 早已修好、卡在 `hero-6` 的语料;
  #150/#151/#154/#162/#170 的下一棒全是 queue 归档扫描或归 harness;#165/#166 是本组前两轮
  刚做完的);owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项。新 gated id **`zusstatic`**
  (turbo-only,**未 armed**,**不申请入集,先买域** `hero-15`);登记
  `state.json:zusstatic_20260825`;backlog 新增 §-9;**稳定版未漂移**;零 AWS。
  自选方向**刻意换轴**:前三轮(#170 `0SELL` / #166 槽位 / #165 `0TERN`)都是**普查造尺子**,
  这一轮回到**读一个焦点英雄的源码**,尺子只当工具用):
  **`hero_zuus.lua` 把静电场伤害比例写死成 `0.09`,而本 patch 的
  `zuus_static_field/damage_health_pct` 是 3.45 + 0.05/英雄等级(31 级也才 ~4.95)
  —— 出厂常数在任何等级上都是真值的 1.8–2.6 倍,而且错在乐观那一侧;
  它恰好两个消费方,两个都是击杀判据,其中一个就是决定要不要交 ~130 秒全图大招的那条。**
  - **与 backlog §4 同病两门**:那条量出「斩杀窗口来的时候没蓝」,本条给出**蓝去哪了的
    一半 —— 花在一个从来不存在的击杀上**。
  - **承重帧**(已在库)`f_230952_zuus_ult_hoard` t=567.0,9 级 Zeus,五个活敌共 4007 血:
    出厂记 **360.6 HP**,KV 带只允许 138–198 ⇒ **凭空 162–222 HP**,且**逐个敌人**成立。
  - **被本地化当场否掉的假设**:「静电场只打英雄」—— `abilities_english.txt` 说
    "**any enemy** ... **current health**" ⇒ 远程兵那一处目标合法、`GetHealth()` 也对,
    **只有数字错**。**KV 给数值、本地化给作用域,两个都要读。**
  - **三条 LIMIT 全是量出来的**(① 没有 .dem 带 innate ⇒ `GetAbilityList(bot)[5]` 是 nil,
    **这是把句柄改成参数的唯一理由**;② mock 的 `GetSpecialValueFloat` 恒 0;
    ③ `GetActualIncomingDamage` 恒 0 ⇒ 开火侧离线不可复现)。
  - **⭐ 本组三小时前立的教训落到自己头上**:`test_focus_innate_index_anchor.lua` 的
    GH #151 棘轮按字面数 `abilityAS:IsTrained()`,挪进 helper ⇒ 当场红。
    **改写不是削弱**(钉两半:句柄仍交给 helper、helper 第一句仍是无守卫 `IsTrained()`)。
  - 测试 `tests/test_zuus_static_field_pct.lua`:13 例,**10 次变异 9 抓 + 1 条如实记录的
    no-op 对照逃逸**(`nPct > 0` → `>= 0`,复核确认真 no-op)。
- 2026-08-25T01:51Z(报告 `iterations/reports/hero/20260825T015101Z.md`;**自选,GH #170 已开**
  —— open 的 `[hero]` issue **一条都不可在桌面推进**(#162/#154/#151/#150/#146/#136/#126 的
  下一棒全是 queue `hero-11..14` 的归档扫描或波次语料;#166/#165 是本组前两轮刚做完的);
  owner P1/P2 球在协同组、P3 在总监 ⇒ 本组无优先项。**`bots/` 零改动、无新 gate id、
  不提 queue、稳定版未漂移、零 AWS**;backlog 新增 §-8):
  **`X['sSellList']` 没有角色维度,而 `sRoleItemsBuyList` 有 —— 一张卖装表被 pos_1..pos_5
  五份买单共用,于是任何点名了角色特有物品的卖装规则在其余角色里构造性是死的。
  焦点五里 16 条如此。** `SetPairedItems` 是配对表(`for i = 2, #l, 2`,卖的是第二件),
  两个槽必须同一瞬间 `>= 0`。
  - **新轴 `0SELL`**:`0CLK` 问常数的值、`0TERN`(#157/#165)问表达式怎么解析、
    `0SAT`(#168)问一个合取的两条腿,本条问**两件物品能不能同时在一个包里**。
  - 命中:axe pos_3/4/5(pos_3 没有深渊之刃,pos_4/5 是 `= pos_3` 的赋值别名连带继承;
    **pos_1 有,正确缺席 = 近失**)、zuus + lion **全五角色**的补刀斧、lion pos_4/5 的 midas、
    cm pos_4 的风杖(pos_3/pos_5 有风杖,正确缺席)。
  - **一条都没修,是有意的**:死规则是 no-op,救活它是**加宽**(#168 已立:加宽不能用
    「armed 看着像 baseline」验收),而 16 条是**三种不同的加宽**,各自要各自的依据。
  - **判读拿 KV 不拿偏好**:`item_quelling_blade` 的 `damage_bonus 8` /
    `damage_bonus_ranged 4` ⇒ 远程智力不买它是对的,**过时的是卖它那一半**。
  - **⚠ 单向 + 全局表的过滤**:可达性走**声明的**买单 = 真实背包上界(#136/#139)⇒
    够不到是证明、够得到什么都不证明;Q5 **故意不跑全局表**(127 英雄共用,不过滤
    光焦点五 **445** 行噪声)—— 这也是章程 §24「放宽方向自带反例」的实证。
  - **落地**:`tools/agent/sell_pair_census.py` + `tests/mock/item_recipes.json`(冻结配方图,
    测试不上网)+ `tests/test_sell_pair_census.py`(循环形状断言 + 五判据/报告的合成自测 +
    **16 条棘轮:多一条红、修好一条也红**)。**变异 11 抓 10 + 1 对照逃逸**,
    其中 **M10 是一次「修复」也红**。
  - **顺手清掉本组自己 08-24T22:30Z 留的红树**:`test_wk_fact_anchor.lua` 的 t20/t25 普查
    —— #166 把莱恩十五处 `talent8` 改道进 `X.IsHexAoe()` ⇒ 结构性读数 **14 → 1**
    (合并不是删除)。登记数改成 1,源码一字未改。
    **教训:落地「N 处调用点合并成 1 处」之前先 grep 有没有普查在数那 N 处。**
  - **⭐ 一次静默的量测事故(必读)**:变异扫描 M6 起结果全废 —— `range(...,2)`→`1`
    **字节数不变** + `cp` 还原后 mtime **同一秒**,而 CPython 的 `.pyc` 失效判据正是
    **(mtime 秒 + 字节数)** ⇒ 继续跑上一个变异的字节码,M7/M8/M9 的红全是 M6 的红。
    **python 模块的变异扫描每次都要清 `__pycache__`;改单个字符的变异是这个盲区的必要条件。**
- 2026-08-24T22:30Z(报告 `iterations/reports/hero/20260824T2230Z.md`;**自选,GH #166 已开**
  ——open 的 `[hero]` issue **一条都不可在桌面推进**(#162/#154/#151/#150/#146 的下一棒全是
  queue `hero-11..14` 的归档扫描,#165 本组 19:46Z 刚做完),owner P1/P2 球在协同组、P3 在总监
  ⇒ 本组无优先项。新 gated id **`lionhexaoe`**(turbo-only,**未 armed**,**不申请入集、
  不提 queue**);登记 `state.json:lionhexaoe_20260824`;backlog 新增 §-7;**稳定版未漂移**;
  零 AWS):
  **Lion 用 `talent8` 判「妖术是不是 AoE」判了十五处,而 `sTalentList[8]` 今天是
  `special_bonus_unique_lion_2` = `lion_impale/AbilityCastRange +600`,根本不碰妖术 ——
  真正给妖术半径的 `special_bonus_unique_lion_4`(`lion_voodoo/radius +250`)是 slot 7,
  同一行 t25 的另一半。** 而本文件 `tTalentTreeList['t25'] = {10, 0}` ⇒ `GetTalentBuild`
  第 4 项 = 8 ⇒ **出货构筑训的正是让那十五处答 true 的那一半**。
  - **两条后果,只有第一条需要引擎**:① 调度把实体指令换成 `ActionQueue_UseAbilityOnLocation`,
    而 `lion_voodoo` 是 `UNIT_TARGET` 且**整份 KV 无天赋 override 改过 AbilityBehavior`**
    ⇒ 对单位指向技能下地面指令,引擎行为**离线断不了**,**登记为风险不写成实测 no-op**;
    ② `( J.CanCastOnTargetAdvanced(x) or talent8:IsTrained() )` 拿同一假前提绕过施法合法性检查,
    **这一半不需要引擎就能判错**。
  - **新工具 `tools/agent/talent_slot_census.py` + 生成快照 `tests/mock/talent_slots.lua`**
    (odota 槽位顺序 × 游戏 KV 的 override 位置,零 AWS)。**判据单向**:`mods` 非空是证明,
    `mods` 为空什么都不证明(通用行/facet 行在 `npc_abilities.txt`,不读)。
  - **关掉的是 #162 那把尺子自认的缺口**:key 普查**不解析句柄→技能**,所以「key 在」什么都
    不证明。本轮先做了它的**类型对偶**(`GetSpecialValueInt` 读小数被截断)——**焦点五零真阳性**,
    唯一命中是假阳性(Axe `duration` 撞上 `berserkers_call` 的 2.1/2.4/2.7/3.0,而 `abilityW`
    是 `battle_hunger`,值是 12.0)**——正是那个假阳性把工作单元换成了「先解析句柄」**。
  - **⚠️ 域是空的,量出来的**:所有读数在 25 级天赋下游;不引用 GH #84,而在 104 枚 fixture 上
    **重量最高英雄等级**并断言 `< 25`。**处置同 `alchrage`:不 arm / 不入集 / 不提 queue。**
    那条断言**自我重开** —— 语料首次出现 25 级(#108 cap 10→25 最可能)当场红并点名下一步。
    与 `alchrage` 直接读 `SOAK_CAP_MIN` **同形不同源**:那里阈值是**时钟**可直接读局长上限,
    这里是**英雄等级**,只能量语料。
  - **槽位顺序没只信一个源**:树里已站着的四条 datafeed 声明(`hero_axe.lua:280` 7=axe_2、
    `hero_zuus.lua` 5=zeus_2 且 3=zeus_4 大招 +75、GH #150 6=wk_facet_3)与新快照**逐槽相符**,
    六条全写成断言 ⇒ 哪个源重排都当场红。
  - **关掉的第二道缝**:`test_focus_talent_anchor.lua` 有意只钉 t10/t15、把 t20/t25 记成不钉,
    理由是 GH #84 让它们在 turbo 是**死行**。**那条理由说的是「构筑会不会点它」,没有覆盖
    「一个句柄去读它」** —— 缺陷就住在这道缝里,新文件为**第二个理由**钉住 t25 这一对。
  - 顺带修一个记录漂移:`test_focus_talent_anchor.lua` 把 WK slot 4 记成 `special_bonus_hp_300`,
    活源读作 `hp_350`(只进断言消息,行为零影响)。
  - **下一棒有意没交给任何人**(总监无入集提议 / 批测台无 queue / 录像组无可能帧)。
    **留给 #108 之后的人**:修的另一半 —— 真正**利用** slot 7 的 +250 半径(保留实体指令、
    优先选身边有人的目标)—— **有意没写,因为那是放宽而本单元是收紧**,混方向就丢掉结构性等价。
  - **一次自己踩的坑**:新测试第一版漏了 `package.path = 'tests/?.lua;' ..`,单跑与
    `--filter talent` 全绿,**只有 `--filter lion` 红**(按字母序它在那一档排第一)。
    **教训:文件自足性只有在它是某个 filter 里第一个加载的文件时才被检验;新测试加完
    要挑一个能让它排第一的 filter 跑一次。**
- 2026-08-24T19:46Z(报告 `iterations/reports/hero/20260824T194616Z.md`;**认领 GH #165**
  ——协同组 19:26Z 开的,本轮唯一一条**不排在任何队列后面**的 open `[hero]` issue
  (#162/#154/#151/#150/#146/#136/#126 全在等 `hero-11..14` 或波次语料);owner P1/P2 球在
  协同组、P3 在总监 ⇒ 本组无优先项。新 gated id **`alchrage`**(turbo-only,**未 armed**,
  **不申请入集、不提 queue**);登记 `state.json:alchrage_20260824`;backlog 新增 §-6;
  **稳定版未漂移**(gate-off 是**可断言的算术**,不是承诺);零 AWS;零外部读):
  **Alchemist 的四处 turbo 时钟缩放(`hero_alchemist.lua` ×2 + rubick 逐字拷贝 ×2)
  因为 `and` 比 `or` 结合更紧、且 `x` 槽里放的是比较式,逐字等于
  `DotaTime() < 30 * 60`(resp. 32)—— turbo 常数一次都没决定过任何事。四处全修,
  全仓棘轮 allowlist 5 → 1。**
  开工自检 worst exit **3**:8 条 UNLANDED **仍全是总监的树**(自陈 main 故意不推);
  cadence 五个洞是**全队** 00:xx–13:xxZ 停了一截,不是本组;citation clean、trunk python 18/18。
  **上一轮的教训照做了**:写 issue 评论前先 `git fetch origin main`(tip `ee7b791`)——
  本轮的认领对象正是那笔 commit 开的,自检跑在它之前的 main 上根本看不到。
  - **改法(可抄的那一条)**:`nClock = math.min( nClock, nTurboMin * 60 )`。
    **收紧型的门写成「armed 只准取 min」** ⇒ 「armed 是出货的子集」从**两个常数碰巧满足**
    变成**结构性**成立(issue 建议的赋值写法只在今天的常数下对)。这是 GH #154
    「放宽型写成『出货判据先跑一遍』」的**对偶**:**门的方向性由代码形状承担,不由常数承担。**
  - **判别式**:`cond and x or y` —— **`x` 是数字就安全,是比较式就是缺陷**。
    `jmz_func.lua:4324` 的数字版完全没问题。全仓 5 处修掉 4,剩下的是 `aba_site.lua`
    的**无调用者孤儿**(由 `typescript/` 生成,修它要动两个文件且不买任何行为)。
  - **⚠️ 域为空,且是量出来的(本轮最该被引用的一段)**:`SOAK_CAP_MIN=10` 而 armed 界 15:00
    ⇒ 封顶局**每一刻**都满足出货谓词,**armed 与出货逐点相同**,跑多少局都买不到 (a),
    读回来会长得像「测过了没效果」而真相是 **DOMAIN-NOT-REACHED**;`tests/fixtures/`
    每一帧也都在界下 ⇒ 硬钉帧只能证明同义反复。所以**故意少做三件事**:不入集、不提 queue、
    不钉帧。**`[domain]` 用例直接从 `soak_loop.sh` 读 `SOAK_CAP_MIN`,`[corpus]` 用例扫 fixtures
    ⇒ cap 一涨这两条就红,并在消息里点名「域已打开,可以提议入集了」**(散文会过期,这个不会)。
    与 #100/#133/#145/#154/#162 **后果同形、成因不同**:那一族是 mock 默认值打平读数,
    这一族是**局长上限切掉了整个域**。
  - **核验**:luacheck **0 警告**;新测试 `tests/test_alchemist_rage_objective_clock.lua`
    **10 例 / 12 次变异 11 抓 + 1 个 no-op 对照如期逃逸,0 意外**(判定读 runner 的
    `N tests, M failures` 计数,不用行子串)。整套逐文件 **172 文件 / 1733 例 / 0 失败**(外加最终树上重跑前 63 个文件 / 655 例 / 0 失败,
    原因见报告 §5:整套跑到一半时改了两处说反了的注释标签 `WIDENED`→`NARROWED`)
    (`test_itemdesire_world_assertion.lua` 单列,GH #124 未变)。
    **M7 是补出来的**:第一版只钉 helper,调用点 `<` 改成 `<=` **逃逸** ——
    §§2–4 测的是 helper **返回什么**,不是调用点**怎么用它**;补上「连比较号一起钉」后抓到。
    **M11 驱动的是别人的文件**(协同组 19:26Z 立的棘轮):缩了 allowlist 就得驱动一次它,
    否则「缩表之后还认不认」只是假设。
  - **下一棒已交(两处)**:GH #165 追评(落地 + 为什么不入集);**GH #108 追评,球给总监** ——
    连带重审清单建议加**第 7 条「cap 抬高会新解锁一批 gated id 的域」**(现有六条问的全是
    「已有读数要不要重算」,没有一条问「哪些 id 从来没进过域」),`alchrage` 是第一个具名条目;
    并请总监顺带扫 `state.json` 里还有多少未 armed id 被 cap=10 压着
    (判据:**armed 谓词里的时间常数 ≥ 旧 cap ⇒ 旧语料对它一律无效**)。
  - **下一轮建议**:等 `hero-10..14` 读数;不等的话优先 GH **#126**(CM pos_5 整局无蓝装,
    13:57Z 那轮已顺带确认 pos_5 出货腿结构上不带秘法鞋),或把 `hero-9`+`hero-13`
    合并成一次含 Axe 种子集的申请(需先与批测台确认种子集)。
    **别重推**:§25 Axe `nKillDamage` 仍 `NARROW-BAND-UNMEASURABLE`;
    #162 那 29 处非焦点五的 stale key 不是本组的活;`aba_site.lua` 的三元式孤儿不值得修。
- 2026-08-24T16:52Z(报告 `iterations/reports/hero/20260824T165200Z.md`;**本轮没有可推进的
  `[hero]` issue**(#154 等 `hero-13`、#126 等 W5、#146 等供给数、#150/#151 等 `hero-11`/`hero-12`),
  owner P1/P2/P3 的球在协同组/协同组/总监 ⇒ 按章程取**自选项**:焦点五的「硬编码技能数值 ×
  引擎 KV」对账,并把它推成全仓普查;本组开 GH **#162**;新 gated id **`lionsplash`**
  (turbo-only,**未 armed**,**不申请入集**);queue **`hero-14`** 新增 pending;
  登记 `state.json:lionsplash_20260824`;backlog 新增 §-5;**稳定版未漂移**;零 AWS;
  外部读 128 次(d2vpkr 英雄 KV,与 `gen_ability_meta.py` 同源)):
  **`hero_lion.lua` 读的 `splash_radius_scepter` 不在本 patch 的 `lion_finger_of_death` KV 里
  ——现名 `splash_radius`——而 `GetSpecialValueInt` 对不存在的 key 静默返回 0
  ⇒ Lion 持 A 杖时 `X.ConsiderR` 里消费 `nRadius` 的两条分支(`R团战Aoe` / `R-带线`)
  结构性不可达,整条是死代码。**
  开工自检 worst exit **3**:8 条 UNLANDED **全部是总监的树**(三个 `compassionate-albattani`/
  `busy-bardeen` 分支,自陈「main deliberately not pushed until the full suite closes」);
  cadence 五个洞是**全队** 02:00Z–13:00Z 停了一段,不是本组单独掉队;citation clean、trunk python 18/18。
  - **普查规模**:`tools/agent/special_value_key_census.py`(新)对 `bots/` 的 **620 处
    `GetSpecialValue*` 读数**逐条比对该英雄整份 KV ⇒ **26 处英雄文件 + 4 处通用文件**的 key
    在 KV 里根本不存在,**而落在焦点五里的恰好只有 Lion 这一处**。其余 29 处列在 issue §二,
    **不归本组打磨**。
  - **⭐ 判据单向(与上一轮鞋供给普查同一条纪律)**:key **不在**该英雄任何技能里 ⇒ **证明**
    读数是 0;key **在** ⇒ **什么都不证明**(工具不解析「句柄→技能」映射,`radius` 几乎人人都有)。
    ⇒ 断言写成「没有**新的** offender」,不是「每处读数都对」。
  - **改动形状**:`X.GetAbilityRSplashRadius()` **出货 key 先跑一遍,读到正数就赢**
    ⇒ gate-off 等价性**结构性**成立,且老名字若被改回来出货读数自动重新赢。**一根杠杆。**
  - **⚠️ LIMIT(量出来的)**:mock 的 `GetSpecialValueInt` 对**任何** key 恒 0、`HasScepter()`
    在 106 个 fixture 上恒 false ⇒ **开火侧离线不可复现,绿色不是「守卫不必要」的证据**
    (GH #100/#133/#145/#154 同族)。条件 (a) 只能由语料买 ⇒ `hero-14`。
  - **顺带核对**:Lion R / WK Q / CM W 三处硬编码伤害公式**与 KV 逐位相符**;
    **唯一对不上的仍是已登记的 Axe R `150+100*lv`**(每级少 25,`hero-2`,不动)。
  - **核验**:luacheck **0 警告**;新测试 **14 例 / 15 次变异 13 抓 + 2 个 no-op 对照如期逃逸**
    (含普查**调用点**丢结果的 M14 —— 树上还留着一个真 offender,所以报告那一半有真实驱动);
    **一次如实记的误判**:M5 逃逸,复核确认是**真 no-op** 不是盲区。
    `test_gate_claim_consistency` **当场抓了本轮一次**(注释里的 "ungated" 含子串 "gated"),
    改措辞后 10 例绿;`lion` 前缀 87 例绿。整套**逐文件跑了两遍**:rebase 前
    **169 文件 / 1724 例 / 1 失败**,rebase 到 `9a128b2` 后**重跑 170 文件 / 1734 例 / 0 失败**
    + luacheck 复跑 0 警告(`test_itemdesire_world_assertion.lua` 单列,GH #124 未变)。
  - **⚠️ 一次如实记的时点事故**:那 1 条失败(`test_defend_ping_declaration_ratchet` 点名
    协同组的 `test_towerfear_clock_leg.lua`)本组开了 GH **#163** 交棒,**rebase 之后发现
    协同组 16:41Z 自己已经修好了** ⇒ 当场自撤关闭。**教训**:开工自检跑在 15:57Z 的 main 上、
    写 issue 时已 16:5xZ,中间隔了三个组各一轮 —— **跨组报红前先 `git fetch origin main`
    看一眼 tip**(2 秒)。这与「推了没落地」是同一枚硬币的另一面:那条说别人的活可能已经
    落地了,这条说**别人的红可能已经修好了**。
  - **下一轮建议**:等 `hero-10..14` 读数;不等的话做队列整理(`hero-9`+`hero-13` 合并成
    一次含 Axe 种子集的申请,需先与批测台确认种子集)。**别重推**:§25 Axe `nKillDamage`
    仍 `NARROW-BAND-UNMEASURABLE`;那 29 处非焦点五的 stale key 不要当本组的活。
- 2026-08-24T13:57Z(报告 `iterations/reports/hero/20260824T135727Z.md`;**认领 GH #156**
  ——本轮唯一一条桌面就能推进且属于本组的新 open issue;backlog 新增 §-4;新
  `tests/test_boots_supply_paths.lua`;**`bots/`/`game/` 零改动、无新 gated id、稳定版未漂移、
  零 AWS、外部读 1 次(odota dotaconstants v10.8.0)**):
  **`cmboots` 非 armed 腿 1/103 漏成秘法鞋:源码侧证伪领头嫌疑,泄漏仍未解释。**
  逐树读源码 ⇒ `tEarlyBoots` 四个调用点全非下单(possession / skip / sell),唯一的 role→boots 表
  `advanced_item_strategy.lua:BOOTS_BY_POSITION` `grep -rn` 证明整个 `bots/` 无人 require ⇒
  「一条不读角色买表的早鞋通路」这条领头嫌疑**不成立**。剩下的真机制 = **引擎按配方自动合成**
  (散件凑齐即合成,不关心谁买的),但**对 CM pos_5 出货腿也不成立**:它供 **0 wizard_hat +
  0 sobi_mask**,而秘法鞋两样都要 ⇒ **构造性装不出,无论购买顺序/消耗模型**。承重帧
  `032512_slot8` t=237.4 那个 ring_of_basilius 在出货买表里**没有任何合法来源**。
  开工自检 worst exit **3**:8 条 UNLANDED **全部是总监本轮的树**(`busy-bardeen-uxvcdx`/`-u45ms4`,
  自陈「main deliberately not pushed until suite closes」);cadence 洞在 batch-desk/director/strategy/
  replay-check;citation clean、trunk python 18/18。Owner P1/P2 的球都在协同组。
  - **方向性(重要)**:「零供给」是证明,「非零供给」**什么都不证明**,本文件**故意不对非零下判词**
    (GH #136 普查教训:整表计数会同时造假阳假阴,要读非零得带购买顺序 + 消耗)。⇒ 本轮结论**单向**:
    CM pos_5 出货腿**排除**自动合成 ⇒ 1/103 **仍未解释**,而非被解释掉。
  - **wizard_hat 是替所有出货腿承重的那一个零**:全焦点五里 wizard_hat 只出现在两个点名秘法鞋的
    物品(arcane_boots / guardian_greaves)里;几张表供了 1~3 个 sobi_mask(Orchid/Bloodthorn/
    Urn/Spirit Vessel)但 wizard_hat 恒 0。测试单独断言这一点,哪天有别的物品带 wizard_hat,
    §「wizard_hat 承重」会在主检查还绿时先红,提示 sobi 侧要独立成立。
  - **仓库内对照外部配方源(不盲信 dotaconstants v10.8.0)**:`item_priest_outfit`(CM pos_4 arcane 腿)
    读 2 sobi/1 hat 且明文点名秘法鞋;`item_mage_outfit`(pos_5)读 0/0 点名宁静鞋;`cmboots` 门只把
    pos_5 开局在这两个宏之间切换 ⇒ 门的两半正好骑在供给边界两侧(这是为什么结论是关于 `cmboots`)。
  - **下一棒已交(#156 追评)= 反向可能的加载时序核验,归 harness/总监**:`GetSoakSideConf()` 模块级
    缓存 + CM gate 文件加载期求值 ⇒ 那一刻 `GetTeam()` 是否已是该 bot 队伍,源码/录像都证不了
    (与 GH #100/#133/#145 同族)。建议开 harness 断言核验加载时序,或钉 `032512_slot8` t=237.4 fixture
    (断言该帧 `IsSoakCandidate('cmboots')==false` 且下一未持有项不是秘法鞋系)。
  - **对本组连带影响(已登记进测试)**:任何**只改鞋买表一项**的候选(含已落地 `cmboots`)验收
    「持某鞋比例」时,先用 `test_boots_supply_paths.lua` 的供给表扣掉「结构上装不出的零腿」——
    别把那 ~1% 当泄漏。
  - **核验**:luacheck **0 警告**;新测试 **9 例 / 12 次变异 11 抓 + 1 no-op 对照如期逃逸**
    (M4 用 Orchid 造 sobi 却不造 hat ⇒ §wizard_hat 承重红;M12 加从不被买的散件行 = no-op 逃逸);
    **变异判定读 runner 的 `N tests, M failures` 计数、不用行子串**(修正上一轮 `case *"0 failures"*`
    的子串误判)。整套逐文件 **167 文件 / 1672 例 / 0 失败**(`test_itemdesire_world_assertion.lua`
    单列,GH #124 未变)。
  - **下一轮建议**:等 `hero-10/11/12/13` 读数;不等的话做 GH **#126**(CM pos_5 整局无蓝装)——
    本轮已顺带确认 CM pos_5 出货腿结构上不带秘法鞋(0 wizard_hat),正是 #126 动机之一;接着量
    `cmboots` armed 腿的蓝装可达性。**别重推**:§25 Axe `nKillDamage` 仍 `NARROW-BAND-UNMEASURABLE`。
- 2026-08-24T02:05Z(报告 `iterations/reports/hero/20260824T020516Z.md`;**没有可推进的
  `[hero]` issue(#126 等 W5、#146 等供给数、#150/#151 等 `hero-11`/`hero-12`),owner P1/P2
  的球都在协同组 ⇒ 按章程取自选项**:焦点五的「击杀判据 × 技能 KV 伤害类型」交叉核对;
  本组开 GH **#154**;新 gated id **`axebhpure`**(turbo-only,**未 armed**);
  queue **`hero-13`** 新增 pending;登记 `state.json:axebhpure_20260824`;backlog 新增 §-3;
  **稳定版未漂移**(改动全在 gate 之后,gate-off 结构性等于出货谓词);零 AWS;外部读 5 次):
  **`axe_battle_hunger` 是 PURE 伤害,而 `X.ConsiderW` 的击杀分支把它喂给只认魔法的
  `J.WillMagicKillTarget` ⇒ 至少低估一个基础魔抗(满级带天赋 384 读成 288),漏杀。
  同一个文件的 `X.ConsiderR` 把同一种伤害类型写对了,所以是疏漏不是设计。**
  开工自检 worst exit **3**:8 条 UNLANDED **全部是总监本轮的树**
  (`busy-bardeen-uxvcdx` / `-u45ms4`,提交信息自陈「main is deliberately not pushed
  until the full suite closes」),cadence 的洞在 batch-desk / director,都不是本组;
  citation clean、trunk python 18/18。
  - **普查结论**:焦点五里非 MAGICAL 的技能只有 Axe 三个(全 PURE)与 WK bone_guard(PHYSICAL),
    而**只有 battle_hunger 把伤害喂进了只认魔法的判据** —— culling_blade 走裸血比、
    hellfire_blast 走 `J.CanKillTarget` 且显式传类型、CM/Lion/Zeus 全 MAGICAL。**唯一的一处。**
  - **⭐ 第二十二条世界断言(归 harness,本组只登记,已写进 #154 §3)**:
    `GetActualIncomingDamage` 吃通用 `^Get` 默认 **0**,**1040/1040** 个英雄 handle
    (104 个可加载 fixture);`GetMagicResist` 同样 **0/1040**。拿 99999 伤害驱动
    `J.WillMagicKillTarget`:**活人 0/966 判 true、尸体 74/74 判 true**。
    **分母对照**:同样 1040 个 handle 上 `GetHealth()>0` 的恰好 **966** ⇒ 这不是解析事故。
    ⇒ **焦点五每条击杀分支离线都是哑的,绿色 fixture 是假绿**;本轮行为读数因此**只能合成**,
    而第 5 节把「为什么只能合成」钉在一个真实 Axe 帧上。
  - **改动形状(可复用)**:`X.WillBattleHungerKill` **先跑出货 helper,它说 true 就 true**
    ⇒ gate-off 等价性是**结构性的不是量出来的**,测试直接对结构断言(M6 靠这条被抓)。
    放宽只中和两个魔法项(**一根杠杆**:法强系数与 12 秒回血项都留着),
    并对出货 helper 有特殊意见的四个目标(美杜莎盾/幽灵船/折光/刚背)**一律弃权** ——
    其中三个照吃纯伤,弃权是安全的那侧。
  - **⚠️ 桌面塌缩检查不干净,别把结论单独引用**:分支 2/3/4 不带伤害判据 ⇒
    同一敌人上放宽即 no-op,**DOWNSTREAM-DOMINATED 风险**(WK lever A 同形)。
    **登记为风险不是判词**,所以**不申请入集**,先买域(`hero-13`,四种读法已预登记)。
  - **核验**:luacheck **0 警告**;新测试 **17 例 / 11 次变异 11 抓 + 1 no-op 对照如期逃逸**
    (含跨函数 M10:让 `X.ConsiderR` 改用魔法 helper);整套**逐文件 166 文件 / 1663 例 / 0 失败**
    (`test_itemdesire_world_assertion.lua` 单列,GH #124 未变)。**变异判定读 runner 的
    `N tests, M failures` 计数,不是行子串**,并在已知红/已知绿两侧各验过一次。
  - **下一轮建议**:等 `hero-10`/`hero-11`/`hero-12`/`hero-13` 读数。不等的话,
    §-3 的载体瓶颈与 `hero-9` 相同 ⇒ 可以做一件**桌面就能做完**的事:
    把 `hero-9`(axecull)与 `hero-13`(axebhpure)**合并成一次含 Axe 种子集的申请**,
    省掉一次独占波。**别重推**:§25 Axe `nKillDamage` 仍是 `NARROW-BAND-UNMEASURABLE`。
- 2026-08-24T00:00Z(报告 `iterations/reports/hero/20260824T000000Z.md`;认领 **GH #134**
  (唯一一条把「下一个工作单元可做」写进正文的 open [hero] issue);**issue 已关**;
  登记 `state.json:focus_level_claims_sweep_20260824T00`;backlog 新增 §-2;
  **无新 gated id、无 queue 请求、`bots/` 只动注释、稳定版未漂移、零 AWS、零外部读**):
  **issue 点名待扫的两处散文早已修好(散文比代码晚,第三次同型)——于是把问题换成
  「这一族树上还剩几处」,清扫出**活着的错五处**并全部改正;新
  `tests/test_focus_level_claims.lua` 让每个等级数字**由出货代码填**,而不是由人抄。**
  开工自检 worst exit **3**:两条 UNLANDED 是**总监**本轮的树
  (`origin/claude/busy-bardeen-uxvcdx`,提交信息自陈「main is deliberately not pushed
  until the full suite closes」),cadence 的洞在 **batch-desk**,都不是本组;
  citation clean、trunk python 18/18。Owner P1/P2 的球都在协同组。
  - **⭐ 上一轮的教训第一次派上用场,而且救了整轮**:照「先 `ls tests/` + 读目标文件、
    别信 backlog 散文」做,发现 `hero_zuus.lua:31` 和 `test_focus_talent_anchor.lua:265`
    **两处都已经是 `by level 11`**。**若照 issue 正文办事,这一轮等于零**。
  - **活着的五处(全部只在注释里改)**:`hero_axe.lua` Battle Hunger「maxed by level 10」
    → rank 4 在 **11**(t10 那刻是 rank 3);`hero_skeleton_king.lua` 四处 —— 默认行 Blast
    单点「until 12」→ **13**、Bone Guard 梯子「(1/9/**10/12**」→ 拉线行 **1/9/11/13**、
    2nd stun「instead of 12」→ **13**、Mortal Strike「instead of 10」→ **11**、
    wkqaim 预检「level 2 to 11」→ **到 12**;以及 `tests/test_lion_t10_payoff.lua`
    的 honest bound **在自己文件里跟自己打架**(头写 rank 4、§3 写 rank 3)。
  - **裁定一条没翻,两条更稳**:Axe t10 天赋按「每个活着的 Battle Hunger +8%」计价、
    **不随 rank 缩放**;Lion t10 的更正**对本组有利**(放弃的一侧买 25→35,不是 30→40)。
  - **⭐ 钉法(可复用):一个数字只能有一个来源**。每条 claim 带 needle **模板**,
    `%d` 由 `skill_level_map.rank_ladder`(驱动出货的 `J.Skill.GetSkillList`)填,
    再要求在文件里**逐字出现恰好一次** ⇒ 手改散文对不上,改 build row 也对不上、
    逼人回去重读那段定价。形状同 `test_gate_claim_consistency.lua`。
    工具侧顺带两样:`build_row` 第三参可读**非默认**表(WK 的 gated `tKillBuildList`
    —— **gated 那行的定价散文同样在做等级声明,以前没有任何读者够得到**),
    以及 `rank_ladder`(slot → 每一 rank 的英雄等级,驱动一次得全表)。
  - **⭐ M8 证明这不是在钉字符串**:把 `aba_skill.lua` 的交错规则 `i % 5 == 0` 改成 `== 1`,
    新文件 **17 例红 10 例** —— §1 的 `spent == 9 @L10 / 13 @L15` 守卫先红,引用它的 claim 跟着红。
  - **两条 LIMIT 写在文件头**:只钉**等级**那一半;WK 全按硬编码名绑 ⇒ slot→name 离线零证据,
    且**故意不从语料重建**(dump 顺序 ≠ slot 顺序,GH #151),WK 的 claim 钉成
    **关于 build-row 下标**的 claim(正是那文件自己的措辞)。第三个用例把「WK 现在还是按名绑」
    也断言了:哪天改成按下标绑,测试提示**补腿**而不是删用例。
  - **⚠️ 本轮量测事故,如实记**:变异脚本判定写成 `case *"0 failures"*`,而
    **「10 failures」含子串「0 failures」** ⇒ M8 一度被打成 ESCAPED(真值 CAUGHT(10));
    两个 no-op 对照第一次也没跑成(`grep -qF "$from"` 的模式以 `--` 开头被当选项)。
    **判定语句本身要先在已知红/已知绿上验一次;子串匹配用于计数是错的工具。**
  - **核验**:luacheck **0 警告**;新测试 **17 例 / 16 次变异 16 抓 + 2 个 no-op 对照如期逃逸**
    (六条跨文件:改 build row / 改 `aba_skill.lua` 交错 / 改 `rank_ladder` / 改 gated 拉线行 /
    改 Axe 绑定 / 改 WK 绑定);三个老消费者原样绿(t15 36 例、t10 20 例、anchor 12 例、
    innate 13 例)。整套**逐文件驱动跑了两遍**:rebase 前 163 文件 / 1610 例 / 0 失败,
    rebase 到 `309cd7d`(协同组 `campsel`)后**重跑** 164 文件 / 1631 例 / **0 失败** + luacheck 复跑 0 警告
    ⇒ 核验读数属于**上机那棵树**(GH #124 未变:`test_itemdesire_world_assertion.lua` 单文件 >580s 单列;
    逐文件跑不暴露跨文件全局态泄漏)。
  - **本条不需要交棒**(纯注释 + 测试、零行为改动 ⇒ 不进测试集、不需要波次/录像核验)。
  - **下一轮建议**:等 `hero-10`/`hero-11`/`hero-12` 读数(§25 Axe `nKillDamage` 仍是
    `NARROW-BAND-UNMEASURABLE`,**别重推**);不等的话做 GH **#126**(CM pos_5 整局无蓝装,
    26 个就绪技能槽里 11 个付不起自己的蓝)—— **先读 `cmboots` 的域**再决定要不要第二根杠杆。
- 2026-08-23T22:20Z(报告 `iterations/reports/hero/20260823T222000Z.md`;**认领的是 19:50Z 点名的
  Lion t15,当场发现那条已经在 15 小时前结案了 —— 于是转做一件新的**;本组开 GH **#151**;
  queue **`hero-12`** 新增 pending;backlog 新增 §26 并把 §18 二段那段过期散文划掉;
  **无新 gated id、`bots/` 只动注释、稳定版未漂移**):
  **「datafeed 说 innate ⇒ `GetAbilityList` 丢掉它 ⇒ 我的 index map 成立」这句话两半都是假的,
  而它在五个焦点英雄文件里承重。名字对不上(引擎有 `_innate_` 中缀,feed 没有),
  机制也不是那样(丢弃条件是 `NOT_LEARNABLE` **and** `IsHidden()`,而 bot API 里根本没有 innate 标志)。**
  零 AWS,外部读 4 次(datafeed herodata hero_id 2/5/22/42,加本轮开头 26)。开工自检 worst exit **0**
  (UNLANDED 无、cadence/citation clean、trunk python 18/18)。Owner P1/P2 的球都在协同组。
  - **⭐ 本轮最该被记住的不是发现,是没白干第二遍**:19:50Z 那条「下一轮建议」写的是
    「§18 二段唯一没闭合的是 Lion t15」,而 **04:00Z 本组自己就已经重开、量完、结案**并落地了
    `hero_lion.lua` 的论证块 + `tests/test_lion_t15_payoff.lua`。**建议是照 backlog 散文写的,
    散文比代码晚 15 小时。** 这是 §24 那个死胡同的第二次同型(那次是重做了一份已落地的普查)。
    ⇒ **认领任何 backlog 残留项之前,先 `ls tests/ | grep <关键词>` + 读一眼目标文件里的论证块。
    代码是账本,散文不是。** 已就地把那段散文划掉并写明结论换了理由(它原来那两句
    「两边买同一样东西」「[3] 只值 +9.1%」**都被 04:00Z 的读数否掉了**)。
  - **§1 的读数(分母是「dump 了技能数组的条目数」,不是全部条目 —— WK 34 里 31,Zeus 50 里 47)**:
    五个焦点英雄的 innate,**三个**(axe/cm/zuus)**压根不在引擎技能数组里**;**两个**在,
    带 feed 不携带的 `_innate_` 中缀 —— `skeleton_king_innate_vampiric_spirit` **31/31**、
    `lion_innate_to_hell_and_back` **22/22**,而 feed 拼法 **0/31**、**0/22**。
    **零是真零不是管线事实**:`zuus_lightning_hands`(魔晶授予)**1/47** 就是那个对照分母,已写成断言。
  - **§2 的机制**:`aba_skill.lua` 里唯一出现「innate」的地方是一句**被注释掉的** warning
    `(e.g. innate like)` —— **五个文件那套说辞的出处就是这句旁白**。断言写在**剥掉行注释之后**的代码上。
  - **⭐ 爆炸半径是有界的,而且量出来了**:按下标 ≥4 绑技能的只有 **Zeus**(`abilityD`[4]/`abilityAS`[5])
    与 **CM**(`CrystalClone`[4]),两处**都没有 nil 守卫**(拿到句柄第一件事就是 `:IsTrained()`),
    对照组是 WK 自己的 `abilityW`(两道守卫)。axe/lion 只读 `{1,2,3,6}`,WK **全部按硬编码名绑**
    ⇒ 这三个够不着。**只登记不改**(加守卫是行为改动,且没有域),下一棒 = queue `hero-12`。
  - **⭐ 一条 LIMIT 定死了**:**不许从 fixture 语料推 index map** —— 证伪来自语料内部,
    Axe/CM 大招在末位且都有**正在冷却**的帧(1/26、10/50)⇒ dump 顺序 ≠ slot 顺序。详见 backlog §26。
  - **⚠️ 一次自己的量测事故,如实记**:第一版普查的惰性正则**吞掉每个数组最后一条技能的右花括号**,
    而最后一条恰好是大招 ⇒ 一度读成「Axe 从来没有大招在冷却」(真值 1/26)。已在测试文件里写成注释钉住。
  - **⭐ §3.5 不再是纸上推理 —— 把 `GetAbilityList` 在真实帧上驱动了一遍,index 4 上真的坐着东西**:
    WK 的 `sAbilityList[4]` = **`skeleton_king_innate_vampiric_spirit`**、Lion 的 = **`lion_innate_to_hell_and_back`**
    (mock 的 `IsHidden()` 是 false ⇒ 没被丢掉,预测兑现);**而且多出一个没预测到的占位者** ——
    mock 的 `ability:IsTalent()` **对一切恒 false**,dumper 又把 `special_bonus_*` 行放进技能数组
    (CM 14/50、Zeus 9/47)⇒ 那些帧上 **CM 的 `CrystalClone` 和 Zeus 的 `abilityAS` 绑的是一个天赋句柄**。
    第三条:不带天赋行的 CM 帧上 `[4]` 是 nil,但 mock 的 `GetAbilityByName(nil)` **仍返回 table**
    ⇒「nil 句柄会崩」在 fixture 里**构造性不可复现**,**绿色的 fixture 跑不能读成「守卫不必要」**。
    三条全是**关于工具的事实**(GH #36/#27/#133/#145 那一族),归 harness,已写进 GH #151 §3。
  - **核验**:luacheck **0 警告**;新测试 **13 例 / 13 次变异 13 抓 + 2 个 no-op 对照如期逃逸**
    (变异表见报告 §6:含「合取改析取」「`slot >= 4`→`3`」「删掉那句 innate 旁白」「往函数里塞真 innate 代码」
    「CM 下标 4→3」「Zeus 下标 5→4」「拆掉 WK 的 abilityW 守卫」「把 fixture 里的 `lion_innate_*` 改成 feed 拼法」
    「删掉那唯一一帧 `zuus_lightning_hands`」「把 CM 大招挪离末位」「让 `GetAbilityList` 过滤 `^special_bonus`」
    「loader 把大招放到 slot 4」等,**九条跨文件**;另有一条 M12 被我写坏成了第二个 no-op,如实记)。
    整套 **逐文件驱动 162/162 文件 / 1590 例 / 0 失败**(GH #124 未变:第 163 个
    `test_itemdesire_world_assertion.lua` 单文件 >580s 连续 CPU,单列;逐文件跑不暴露跨文件全局态泄漏)。
  - **⚠️ 本轮第二个流程失误,如实记**:§4 那条「不许从语料推 index map」的 LIMIT **写完才查到
    `tools/agent/gen_ability_meta.py` 的 docstring(GH #36)早就写了同一句**。本轮加的是**证明方式**
    (从语料内部量,而不是从「知道 dumper 怎么写」断言)—— 结论没变,但**不是新发现**。
    下次「我发现了一个 LIMIT」之前,先 `grep -rn` 一遍 `tools/` 的 docstring。
  - **留给后来人**:① 「某某在语料里 0 次」先去找**同一族里有分母的那个** —— 这里是
    `zuus_lightning_hands` 的 1/47,它一没,五个 0 全部改判 UNMEASURABLE。
    ② 从 datafeed 抄的技能**名**不能拿去匹配引擎;**数值**那一侧 feed 仍然权威。GH #104 的方法只废了一半。
  - **下一轮建议**:等 `hero-10`/`hero-11`/`hero-12` 读数。不等的话,§25 第一根杠杆(Axe `nKillDamage`
    陈旧常数,`NARROW-BAND-UNMEASURABLE`)仍在等事件侧读数,**别重推**;可做的是把 §26 的
    index-4/5 普查推到**非焦点英雄池**(按章程那是总监/协同组的活,本组只能提 issue)。
- 2026-08-23T19:50Z(报告 `iterations/reports/hero/20260823T195000Z.md`;认领 backlog **§18 Lever B**
  —— 上一轮点名、唯一还挂着的自选项;本组开 GH **#150**;queue **`hero-11`** 新增 pending;
  **无新 gated id、`bots/` 只动注释、稳定版未漂移**):
  **Lever B 结案 NOT-A-DEFECT ——「bypass 关掉了唯一的弹药检查」这个原假设死于一行 dname;
  而在证伪它的路上量到:WK 的整条 `X.ConsiderW` 在 fixture 里结构性验不了(门要的 charge
  modifier 在 0/34 帧上存在,而引擎里它是真的)。** 零 AWS,外部读 1 次(odota
  `dotaconstants` build/abilities.json)。开工自检 worst exit **3**,两条 UNLANDED 都是**总监**
  本轮的树(`origin/claude/busy-bardeen-wz7g7q`),不是本组的;cadence/citation clean。
  Owner P1/P2 的球都在协同组;`[hero]` open issue 里 #146 等波次、#136 等 `hero-6` 读数。
  - **§1 结案的依据**:索引 6 = `special_bonus_unique_wraith_king_facet_3` =
    **"+5 Bone Guard Skeletons Spawned"**(**平量**),配 `min_skeleton_spawn = 0`
    ⇒ 空仓释放照样出 5 个骷髅 ⇒ 「不管存了多少都放」是**对的规则**,不是 bug。
    三条断言都是**读出来的**不是断言的(平量形状 / 两处读都是 `or` 右操作数 /
    **本文件在 t20 真的取索引 6** —— 这一条 `test_wk_fact_anchor.lua` §2 没钉)。
  - **⭐ §2 的读数**:**34** 个 WK 帧,**17** 带 modifier 列表,**17/17** 带兄弟
    `modifier_skeleton_king_*`,带 `modifier_skeleton_king_bone_guard` 的 **0**,
    出货 `X.ConsiderW()` > 0 的 **0/34**。**名字没写错**(全仓唯一施法者 + 4 帧抓到技能在
    42s 冷却中 + GH #77 ground truth 里 WK 骷髅的伤害)⇒ 是 `make_fixture.py` 的
    ADD/REMOVE **成对**重建拿不到它。**一字段反事实:只授予 `HasModifier` ⇒ 20/34 帧结果
    改变**(越过门后撞 GH #61 拒答)⇒ **盲区大小 = 20**。
  - **§3 两条工具事实**:`GetSpecialValueInt` 离线 0 ⇒ 比值 `0/0`(false)、等式 `0 == 0`
    (**true**,branch 2 弹药检查白送);loader **没实现 `GetModifierByName`** ⇒ 默认 0 ⇒
    层数读**按名排序第一行**。第二条**不归本组**,已交 harness(GH #150 §3)。
  - **⭐ 一般化(比 §Y.2 低一层、桌面可查)**:`HasModifier` 型门的**可测性**取决于那个 modifier
    在战斗日志里**有没有 ADD/REMOVE 对**;没有对 ⇒ fixture 恒 false ⇒ **门下游一切不可达**。
    判别式现成:**同一英雄身上别的 modifier 在语料里出现了多少次** —— 分母在(这里 17/17),
    那个 0 才是关于这一个 modifier 的事实;分母不在,什么都不能说。
  - **§24 的判读法则在本文件上是第三种剖面**:**两个方向都有活的反例** —— 放宽方向的反例
    **在真实语料里**(17 帧兄弟 modifier,谓词一放宽立刻报 17),沉默方向仍要合成 offender。
    (对比:`dup_component` 两个方向都得喂,`magic_wand`/`gate_claim` 只有沉默方向盲。)
  - **核验**:luacheck **0 警告**;新测试 **11 例 / 9 次变异 9 抓 + 1 个 no-op 对照如期逃逸**
    (变异表见报告 §6:含「`or` 改 `and`」「t20 翻边」「门改问 damage_tracker」「loader 实现
    GetModifierByName」四条**跨文件**变异)。整套**逐文件驱动 160/160 文件 / 1584 例 / 0 失败**
    (GH #124 未变;跑在 rebase 前的树上,与本轮改动无交集;逐文件跑不暴露跨文件全局态泄漏)。
  - **留给后来人**:① 先问「这个门读的 modifier 在语料里**有没有分母**」——34 帧里 0 次听着像
    空域,决定它是不是证据的是同一英雄身上**别的** modifier 出现了多少次。② 怀疑某个 bypass
    是缺陷时,**先把它绕过的东西的 datafeed 数值读完** ——「它绕过了一个检查」不是缺陷证据,
    要看绕过之后那个动作**还剩多少价值**(这里剩 5 个骷髅,于是荒谬变成正确)。
  - **下一轮建议**:等 `hero-10` / `hero-11` 读数;不等的话,§18 二段里唯一没闭合的是
    Lion t15 的 `to_hell_and_back` 那一半(缺**量**不缺可观测性,n=3,先量域再谈翻不翻)。
- 2026-08-23T18:00Z(报告 `iterations/reports/hero/20260823T180000Z.md`;认领 backlog **§18 Lever C**
  (上一轮点名的下一件事);queue **`hero-10`** 新增 pending;GH **#104 §5** 已留言更正;
  登记 `state.json:wk_lever_c_mana_ceiling_20260823T18`;**无新 gated id、`bots/` 只动注释**):
  **「`GetMana() >= 600` 在 turbo 结构性不可达」这句 published claim 撤回 —— 它漏了物品、
  又没对智力取整。出货买单下越线等级是 19(pos_3 买了护腕后 18),而 GH #84 的 turbo
  高水位正是 19。零 AWS,外部读 2 次(dotaconstants 10.8.0)。** 开工自检 worst exit 0。
  Owner P1/P2 的球都在协同组;无待认领的 open [hero] issue(#146 等波次、#136 等 hero-6 读数)。
  - **两个错**:① 「排在神杖前的物品没有一件给智力」是假的 —— **魔棒 +3 全属性(pos_3/pos_1 都是第 6 件)**、
    **护腕 +2 智力(第 7)**、树枝每根 +1、神杖 +10 全属性**且 +175 平蓝**(旧注释连平蓝也没算);
    ② 智力**先取整再**按 12 蓝/点兑付 ⇒ 旧数字高报最多 7(15 级 502→**495**、19→**567**、20→**579**)。
  - **模型是量出来的不是断言的**:`75 + 12*floor(16 + 1.4*(lv-1) + item_int) + flat` 在
    **34 个真实 WK 帧上 33 个逐位精确**;第 34 个**点名钉住不进容差**
    (`f_232320_wk_od_burst` 6 级报 `max_mp` 272 / 模型 363;同帧 6 级 Lina 报 800 ⇒ 疑那一帧)。
    **⚠️ 33 行全部 ≤12 级 ⇒ 18–21 级那一段是外推**,引用时必须一起带。
  - **幸存缺陷比原来的锋利**:神杖之前每个里程碑的越线池子**恰好 603** ⇒ 600 要**池子的 99.5%**,
    而 Blast 造价 95/110/125/140 ⇒ **地板 = 它把守技能的 4.3 倍,放一发就再也够不到**。
    问题从来不是等级,是「绝对值」这个形状。**候选仍然不写**(见下)。
  - **⭐ 域是结构性买不到的,不是没量**:第 13 条世界断言 —— `GetActiveMode` 是 bot VM 状态、
    不在任何 .dem ⇒ `== BOT_MODE_ROSHAN` 在归档每一帧上**恒 FALSE**。fixture 上量到的 0 是
    **关于工具的事实,不是频率**(`axeblink` 陷阱的形状),已写成测试钉住。**下一棒 = queue `hero-10`**
    (归档扫描 + **位置代理并要求写成代理**;事先登记:(1) 18/19 级供给读 0 ⇒ **决定性,退役杠杆**;
    (3) 肉山位置代理读 0 ⇒ **不是**空域证据)。
  - **核验**:luacheck **0 警告**;新测试 **13 例 / 17 次变异 17 抓 + 1 个 no-op 对照如期逃逸**
    (源码 8 条 + 器械 9 条,每条**先断言 needle 在文件里**)。整套 **157/157 文件、1538 例、0 失败**,
    但**不是一个进程**:156 个文件逐文件驱动(1513 例)+ 第 157 个
    `test_itemdesire_world_assertion.lua` 后台跑完(25 例;GH #124 那条老问题,单文件 >580s 连续 CPU)。
    两条边界:它跑在 **rebase 前**的树上(与本轮改动无交集),且逐文件跑不暴露跨文件全局态泄漏。
  - **留给后来人**:① 「某某在 turbo 里够不到」先把**包**算完再说 —— 460 金的魔棒把越线从 21 拉到 19,
    505 金的护腕再拉到 18,神杖直接让这道门形同虚设;凡拿**绝对值**比成长量的结论都要连买单一起读。
    ② **取整会吃掉整整一个等级** —— `floor` 让 19 级 569→567,看着差 2 点,决定的却是「19 级跨不跨 600」
    这个离散结论;重锚数值**先用真实帧钉公式再外推**,别反过来。
  - **下一轮建议**:等 `hero-10` 读数;若非 0,候选形状建议 `wkrosh`(绝对 600 → 分数 + 「放完还剩重生的蓝」),
    **写之前先读 `X.ShouldSaveMana`(:490)** —— 它已经在管重生那一侧,别造第二个守卫。
    另仍挂着 §18 的 Lever B(两条 t20 析取的记账)。
- 2026-08-23T16:00Z(报告 `iterations/reports/hero/20260823T160032Z.md`;认领 backlog **§24**;
  无 issue、无 queue、无新 gated id):
  **§24 的「判据/报告双合成自测」装进它自己点名的两个受众
  (`test_wk_magic_wand_branches.lua` / `test_gate_claim_consistency.lua`),
  并先在改动前的版本上把洞演示出来。`bots/` 零改动、稳定版未漂移、零 AWS。**
  开工自检 worst exit 0。Owner P1/P2 的球都在协同组。
  - **改动**:各抽一对函数(`is_partial`/`offences_in`,`is_violation`/`offences_in`),
    普查**经由它们**走;合成输入 = 修复前的 WK pos_3 逐条形状 + 两个近失 /
    三条合成 claim(`ghostid`/`realid`/PROMOTED `goneid`)+ 一条**豁免泄漏**近失。
    `gate_claim` 原本已有三个合成控制,但**全部只测抽取器**,没测判据那一半。
  - **变异实测**:改动前 **B1/B3(判据+报告一起死)两个文件都 ESCAPED**(10 例 / 7 例全绿);
    改动后 **M1/M2/M4/M5/M6/M7 全抓**,M3(只插一句注释的 no-op 对照)如期逃逸
    —— 器械没有在无差别地报红。
  - **⭐ 对 §24 措辞的更正**:这两个受众上**只有「沉默」方向盲**,放宽方向自带反例
    (合法的 0 树枝买单 / PROMOTED 行)。判读法则见 backlog §24。
  - **⚠️ 一个死胡同,如实记、别重走**:本轮**先动手做的不是 §24**,是 GH #139 那句
    「非树枝的同款重复组件一件都没扫过」。按 odota `dotaconstants` 枚举出 7 条同款重复配方、
    写完带序模型的普查(读数 0),**才发现 `tests/test_dup_component_buylist_census.lua`
    今天 09:50Z 本组自己已经做完并落地**(`5229c7d`),而且比我的完整
    (它抓到我漏掉的 `abyssal_underlord pos_4`,已修 ⇒ 我的普查才读 0)。新文件已删,零残留。
    **教训**:`routine_selfcheck.sh` 查「推了没落地」和「报告节奏」,**查不到「今天早些时候
    已做完且已落地」的同一件事**。认领任何 issue 的残留项之前,先
    `ls tests/ | grep <关键词>` + `git log --oneline --since=1.day -- tests/` 各看一眼。
  - **核验**:luacheck **0 警告**;**逐文件驱动 156/156 文件 / 1523 例 / 0 失败**
    (两次前台调用、可续跑;**不是单进程**,GH #124 未变);改动两文件 10→**12** / 7→**9** 例。
  - **下一轮建议**:§18 WK 的 Lever C(`bot:GetMana() >= 600` 打肉山分支)。
    **注意**:它读的是**当前**蓝而物品会加智力 ⇒「turbo 结构性不可达」这句在把物品那一侧
    算进来之前**不成立**,别照抄 §18 的旧措辞。
- 2026-08-23T13:50Z(报告 `iterations/reports/hero/20260823T135000Z.md`;本组开 GH **#146**;
  queue **`hero-9`** 新增 pending;backlog §24 追记、新增 §25 并划掉其中一根):
  **`axecull` 落地:Axe 的斩杀分支不再(在 armed 时)对魔免目标收手 —— 因为斩杀穿魔免。
  gated、turbo-only、未 armed;gate-off 谓词与出货逐字节同义。域没量出来、且本地量不出来。**
  零 AWS、外部读 1 次(odota `dotaconstants build/abilities.json`,10.8.0)。开工自检 worst exit 0。
  Owner P1/P2 的球都在协同组 ⇒ 走 issue 流 / backlog。
  - **事实一句话**:`hero_axe.lua` 的 `X.ConsiderR` 守卫链里那条
    `and not npcEnemy:IsMagicImmune() --V BUG` 是**全 `bots/` 唯一一处** `--V BUG` 标记
    (上游作者当时就看出来了),而 `axe_culling_blade` 的 **`bkbpierce: "Yes"`**、伤害 **Pure**。
    **穿魔免斩杀正是这个技能存在的理由。** 分支上没有别的东西盖住这些帧:
    `X.HasSpecialModifier` **不含** `modifier_black_king_bar_immune`。
    **仓内旁证**(不靠外部源一条腿站着):仓库自己就有 `J.CanCastOnMagicImmune`(穿透)与
    `J.CanCastOnNonMagicImmune`(非穿透)两套词汇,十几个英雄文件在用;Axe 的斩杀两个都没用,
    **手写**了一条非穿透形式。
  - **落地形状**:`and ( not npcEnemy:IsMagicImmune() or X.IsCullPierceOn() )`,
    `X.IsCullPierceOn() = J.IsModeTurbo() and J.IsSoakCandidate('axecull')`。
    Lua 的 `or` 短路 ⇒ 非魔免目标上第二个操作数根本不求值。
  - **桌面预检:七类塌陷排掉六类,全部在测试 §3 上棘轮** —— 无上游同胞(整函数**一条**
    开火分支,且 `ConsiderR` 是 `SkillsComplement` 的**第一个**消费者)、无下游支配、
    消费点可达(下一行就是 `ActionQueue_UseAbilityOnEntity`)、无更强既有守卫(这条**就是**
    唯一的魔免守卫,改动是放宽它)、载体在(焦点英雄)、**不是窄带**(存在性谓词,不是
    `hero-2` 那种连续量上的 25 点带)。**第七类 SUPPLY 没答上,而这正是本轮的诚实结论。**
  - **⭐ 域 = UNSIZED,处置写作 `SUPPLY-STARVED-IN-CORPUS`,不是空域**:104 帧逐个 `dofile`,
    26 帧带 Axe、**20 帧**斩杀可施放(挡住 4 未学 / 1 冷却 / 1 蓝);全语料**魔免英雄瞬时只有 3 个**
    (全是 `modifier_juggernaut_blade_fury`,**全在没有 Axe 的局里**);**黑黄杖在任何物品栏里 0 件**
    ⇒ 配对 0、域 0。**这个 0 对局内频率什么也没说**:语料切自**局时上限 10 分钟**的 turbo 局
    (时刻 0:51–11:30),BKB 4050 金,而 **GH #108 已把上限提到 25 分钟** —— 最可能推翻这个供给
    读数的改动,任何归档帧都照不到。按 §Y.2:桌面能证 EMPTY 不能证 RARE,**这里连 EMPTY 都证不了**。
  - **真实帧 + 一字段反事实**:`f_260820_043637_axe_ring_close` t=393.4(Axe 6 级、斩杀 1 级就绪、
    286 蓝;skywrath 221/940 血、188u,低于连出货那条偏低的 250 线 ⇒ **出货代码今天就在那儿开火**)。
    gate on/off 在**未改动的**真实帧上给出**完全相同**的出价(0.75 瞄 skywrath)—— 反回归那一半。
    魔免那一例是**反事实**:同一真实帧**只翻一个字段**,gate-off desire 0 / 无目标,gate-on 0.75。
    器械与标注沿用 `f_232320_wk_od_burst`(只动一个整数)。
  - **⭐ 方法学两条**:① **backlog §24 的「判据/报告双合成自测」第一次被别的测试用上,当场抓到东西**
    —— 普查拆出 `scan_frames` 缝 + 合成 offender/近失,**M12(只计数不报告)和另外四条变异全靠它才被抓住**;
    ② **`J.IsModeTurbo()` 会 memoise**(`bModeTurboCache`,`jmz_func.lua:8474`)—— 第一版「turbo AND
    candidate」用例先调 helper 再翻 `GetGameMode`,读到陈旧缓存、**看上去像门坏了**;正确写法是
    **每条腿开一个全新的世界**。对所有想在同一个测试里翻 game mode 的人都成立。
  - **诚实边界**:(a) **不是被测量的收益**,条件 (a) 从未买到**且本地买不到**;
    (b) 魔免那一例是反事实不是回放瞬时;(c) (c) 依据很硬(技能自己的 `bkbpierce` 标志)但
    **只有 (c) 不能 promote 一个增加动作的改动**(`lanefix` 教训);(d) 代价侧是**论证的不是测量的**
    (开的帧血量判据已经通过 ⇒ 那一发是击杀、且击杀重置斩杀冷却,但没有波次证明过);
    (e) **能退役这个 id 的事实**已写进 hero-9 验收:若引擎对 bot 下令**不认**这个穿透
    (放了没杀掉),整个杠杆作废 —— 离线证不了,mock 里 `IsMagicImmune` 是我们自己喂的。
  - **核验**:luacheck **0 警告**;`test_axe_cull_immune_veto` **18/18 / 15 次变异 15 抓**
    (变异两侧都打:M1–M10 源码、M11–M15 普查自身;每个变异**先断言 needle 在文件里**才算数);
    `axe_culling_threshold` 8/8、`gate_claim_consistency` 7/7、`smoke_load` 2/2、`axe_blink` 53/53、
    `axe_t15` 13/13、`focus_talent_anchor` 12/12、`replay_260820_axe` 33/33。
    **整套:155 个文件全部跑过、1507 例、0 失败、零遗漏 —— 但是逐文件跑出来的,不是
    一个进程。** 原因(值得进 GH #124):**这个例行容器在两次前台调用之间几乎冻住** ——
    单进程整套要 ≈32 分钟连续 CPU(前台 `timeout 580` 实测走到 444 例、0F/0E、EXIT=124),
    而丢后台**买不到时间**(空等时日志 665→665 一个字节不涨,一次前台调用期间 665→672)。
    可行解 = **可续跑的逐文件驱动**,3 次前台调用跑完。**代价**:逐文件跑**不会**暴露
    跨文件的全局态泄漏,单进程会 —— 两者不等价,别把这次的绿当成 09:50Z 那种绿。
  - **下一棒已交**:GH **#146**(帧证据 + 验收)+ queue **`hero-9`**(**不申请专波**,折进任何多 id 波,
    **在事件侧**量供给/域/是否杀掉;**事先登记**:没有魔免敌人的 SILENT = CARRIER-ABSENT,不是阴性结果)。
    **入测试集要总监批。gated 未 armed ⇒ 不是 shipped。**
- 2026-08-23T11:45Z(报告 `iterations/reports/hero/20260823T114555Z.md`;认领 GH **#144**;
  queue **`hero-8`** 新增 pending、**`hero-5`** 前提就地改写;backlog 新增并划掉 §-1):
  **`cmboots` 落地:CM pos_5 的 arcane boots 改动进 turbo-only soak gate,gate-off 逐字节
  回到 `9fa4898` 之前。零 AWS、零外部读。开工自检 worst exit 0。**
  - **总监的裁定是机制性的,不是对论据有疑问**:镜像 A/B 报差之差,ungated 改动
    **两波两侧都在**、逐项消掉 ⇒ 对这台仪器**好坏两个方向都不可见**,条件 (b) 永远买不到。
    落地照 `axebuyblink` 的写法:`ArcaneBootsBuild(tList)` **从出厂清单派生**候选清单
    (`item_mage_outfit`→`item_mage_arcane_outfit`,丢 `item_boots_of_bearing`),
    出厂与候选结构上不会漂开。#144 验收第一条因此是**编译器级**的:
    `git diff 9fa4898d^ -- bots/BotLib/hero_crystal_maiden.lua` 里**买表本体零 diff**。
  - **⭐ 本轮最该被别的组拿走的一条:`9fa4898` 的另一半改动波及 16 个英雄,而它给的理由是假的。**
    那笔 commit 还改了 `aba_item.lua` 的**共享宏** `item_crystal_maiden_outfit`
    (加第二个芒果 + `tDefineItemRealName` 哨兵 `item_magic_wand`→`item_arcane_boots`),
    理由写的是它 "referenced by nothing since before the fork"。在 `9fa4898^` 上 grep:
    **16 个英雄文件 / 19 条活的买表条目**(ancient_apparition/bane×2/dazzle/jakiro/largo×2/
    lich×2/lina/oracle/ringmaster/shadow_demon/shadow_shaman/silencer/skywrath_mage/
    storm_spirit×2/techies/venomancer),全部 fork 之前就在,逐个复核过是买表不是 `sSellList`。
    **哨兵不是装饰**:`Item.IsItemInTargetHero` 用它判「这套开局买完了没有」,而 arcane boots
    在组件序列里排在 `item_recipe_magic_wand`/`item_flask` **前面两位** ⇒ 哨兵一挪,
    这 16 个英雄的开局**提前两条结束**。两处都**逐字节撤回**(`git diff 9fa4898d^ --
    bots/FunLib/aba_item.lua` 对这两行不出任何行),arcane 变体搬进**新宏**
    `Item['item_mage_arcane_outfit']`(哨兵 `item_arcane_boots`),**只被 gated 分支引用**。
    **撤回依据是「前提为假 + 从未量过」,不是「量出来是坏的」** —— 共享宏不归本组,
    谁要重提得带那 16 个英雄自己的帧。
  - **测试口径改了**:§1 原来读源码字符串,现在在 mock 下 `dofile` 英雄文件、写/删
    `soak_side.lua` **两种状态各跑一遍**,gate-off 的 pos_5 对一份逐字节抄的 13 条出厂清单。
    **M7(transform 无条件泼到 pos_3)对读源码的版本是隐形的。** 新增 §1b **把那句假前提
    本身钉住**:`item_crystal_maiden_outfit` 必须仍被 **>=16** 个 BotLib 文件购买、哨兵仍是
    `item_magic_wand`、仍**恰好一个**芒果。顺带把 `9fa4898`/`47e02db` 改过的两处下游测试
    (`test_replay_260820_cm_es_aftershock` 的 role 判别器、`test_fixture_roles` 的同款注释)
    撤回到 `9fa4898^`,并在 aftershock 里留了一行「`cmboots` 若 promote,锚移到 `tPos5[2]`」。
  - **诚实边界**:(a) 本轮**稳定版往回漂**,这是 #144 验收第一条要的,不是副作用;
    (b) `9fa4898` 的论据**没被推翻**,§2-§4 六个语料测试原样全绿(tranquil 臂 12/45 付不起
    自己的蓝,arcane 臂 0/14),它仍是**论证的**不是测量的(承重的 Replenish 在 fixture
    世界看不见,GH #100)—— 这正是它需要一波的原因;(c) `item_mage_arcane_outfit` 是全新宏,
    **离线证不了采购层解得开**(mock 的 `GetItemComponents` 恒 `{}`),这就是 `hero-5` 的
    第 (1) 问,**且现在只能在 armed 腿上读**。
  - **核验**:luacheck **0 警告**;`test_cm_pos5_boots` **14/14** / **12 次变异 12 抓**;
    aftershock 32/32、fixture_roles 10/10、smoke 2/2、gate_claim_consistency 7/7,
    另跑 `dup_component_buylist_census`/`wk_magic_wand_branches`/`soak_draft`/
    `level_gate_census`/`focus_talent_anchor`/`focus_t15_payoff`/`cm_t10_payoff`/
    `axe_blink_build` 全绿。**整套 `run_tests.lua` 跑到硬上限**:`timeout 3000` 下
    **EXIT=124(被杀掉,不是跑完)**,进度行 **724 个 `.`、0 个 `F`、0 个 `E`**,无汇总行。
    **这不是「整套通过」也不是「整套失败」,是没跑完** —— 能说的只有「被杀之前那 724 例全绿」。
    GH #124 现写的是「900s 超时」,本轮把下界抬到 **>3000s / >724 例**,已在 issue 留言。
- 2026-08-23T09:50Z(报告 `iterations/reports/hero/20260823T095041Z.md`;queue **`hero-7`**
  pending;GH **#139** / **#134** 各留言销账;backlog §21 与 §23 划掉、新增 §24):
  **GH #139 的非树枝普查做完:七族全扫,又抓到魂之戒(2× `item_gauntlets`)两处。
  `hero_tidehunter.lua` pos_1/2/3 `item_gauntlets` → `item_double_gauntlets`;
  `hero_abyssal_underlord.lua` pos_4 在 Bracer 之后、魂之戒之前插第三个 gauntlets。
  纯构筑、无 gate ⇒ 本轮稳定版漂移。** 零 AWS、零新 gated id;外部读 = 1 次 GitHub raw
  (odota `dotaconstants` build/items.json,package **10.8.0**)。开工自检 **worst exit 0**。
  Owner 优先项 P1/P2 的球都在协同组 ⇒ 按章程取 backlog 最上面的未完成条目(§23)。
  - **§23 写的「前置」是假的:配方不必等 mock 供数。** 外部读一次就够,122 个带 components
    的物品里**恰好七个**要两件同款(magic_wand/soul_ring/bfury/desolator/moon_shard/
    skadi/necronomicon)。**外部源不是白拿的,在仓库里对了两次、两次都对上**:魔棒是
    15/15 合成宏老锚;**魂之戒有更锋利的仓内证人** —— `Item['item_broken_soul_ring']` =
    `{ring_of_protection, recipe_soul_ring}` **故意不带护腕**,而它唯一的消费者
    `item_dragon_knight_outfit` 在它旁边**摆了两个独立 `item_gauntlets`**。一个以为
    魂之戒只要一个护腕的作者写不出这一对。其余五族**分母上没人散买组件**(整件买/无人买)⇒
    零 offender 是结构性的,不是没找到。
  - **⭐ 本轮最该被别的组拿走的一条:这类普查必须在「目标那一刻」按购买顺序计数,
    整单求和会同时给出假阳和假阴** —— **假阳 `omniknight` pos_3**(一个护腕 + 魂之戒,
    但 Bracer 排在前面把它吃了 ⇒ 到目标时是安全的 0;照整单求和「修」成 double
    会**亲手造出这个 bug**:2−1=1);**假阴 `abyssal_underlord` pos_4**(起手就是
    `item_double_gauntlets`,整单求和 = 2 干干净净,但 Bracer 同样排在前面 ⇒ 到目标时是 1,
    **整单求和根本看不见他**)。于是普查改成走购买顺序:买到加、被更早的合成件吃掉减、
    **在目标第一次成为队头那一刻读数**;`eat` 表是同一份 dotaconstants 的传递展开
    (七个组件、约 30 行,每个消费者恰好吃 1 件)。
  - **⭐ 第二条(方法学,已立成 backlog §24):一个「扫全仓 + 断言为空」的测试,
    修完之后它自己的阳性路径就死了。** 前两版各逃逸一个变异,同因不同层:**M13** 把判据
    放宽成「拿着 >=1 就算安全」全绿、**M14** 只对「恰好 1」停止报告仍全绿 —— 因为树上
    再没有 partial,那两条分支在真实数据上永远走不到。修法:**把判据和报告各抽一个函数、
    各喂一个合成输入**(`is_partial` 四点自测;`offences_in` 由一个合成 offender 驱动,
    必须报出恰好一条并点名 `item_gauntlets`/`item_soul_ring`)。**仍然测不到的那一块也写进
    文件了**:普查**调用点**上的变异(把结果丢掉)在一个没东西可报的世界里不可证伪。
    最终 **15 次变异 15 抓**;变异前先 commit,每个变异先断言 needle 在文件里才写。
  - **顺手销掉 backlog §21 / GH #134 的两处 off-by-one 散文**,但**没有照抄 §21**:
    两条加点行各自独立复核(Zeus 的 Arc 落在第 2/8/9/**10** 项、Axe 的 Battle Hunger 落在
    第 1/8/9/**10** 项,第 4 点都在行[10] = **11 级**)。`hero_zuus.lua` 本轮只有注释改动。
  - **诚实边界(最重的三条)**:(a) **不是被测量的收益**,而且比 GH #136 那次**更弱** ——
    WK 那次背后有 40/40 局背包读数,**这两个英雄一局语料都没有**(不在焦点五、不在
    `run_001140` 阵容),依据是机制同一性 + 那个机制被观测到过 40 次;(b) **条件 (a) 对
    他们可能永远买不到**(镜像阵容固定十人,两人都不在),queue `hero-7` 已预登记
    「**载体不在场的 SILENT 不是阴性结果**,记 carrier absent,不许当成域为空」;
    (c) **七条 law 不保证是当前 patch 的** —— dotaconstants 是镜像、可能滞后,仓库能对的
    两处都对上了;mock 哪天长出真配方,边界断言会**故意红**,届时换成引擎的。
    另:`item_necronomicon` 那条 law 全仓**分母为 0**,现在纯粹是个哨兵。
  - **核验**:luacheck **0 警告**;新测试 `tests/test_dup_component_buylist_census.lua`
    **14/14**;逐文件复跑 `focus_talent_anchor` 12/12、`zuus` 71/71、`magic_wand` 10/10、
    `smoke` 2/2。**整套 `run_tests.lua` 本轮真的跑完了:1476 例 0 失败(exit 0)**,
    铁律 6 的第二道门不是逐文件拼出来的。
  - **⭐ 一条对本组自己的更正(报告 §8 已改写)**:报告第一版写「整套在第 421 个点上停住,
    GH #124 第三轮复现」—— **错的,它没卡住,是我等得不够久**。实测 **09:52Z → 11:53:55Z,
    约 2 小时 01 分**,是 #124 那个 900s 超时的**约 8 倍**。**对 #124 是收窄不是推翻**:
    整套**会**终止且全绿,过不去的是**例行容器 900s 超时**那一层(已在 #124 留言)。
    **可复用的那一半**:测试进度是一串点,**「慢」和「挂死」在点流上长得一模一样** ——
    与 §4.1 那条(没施加的变异 vs 逃逸的变异)同形,缺的都是**一个能把两种解释分开的
    独立观测**。这里最便宜的是**等它自己结束**(后台跑不占人),其次是给 runner
    加一行「当前文件名」。
- 2026-08-23T08:00Z(报告 `iterations/reports/hero/20260823T080000Z.md`;GH **#139**
  本组开(通用采购层根因);queue **`hero-6`** pending;GH **#136** 已留言**不关闭**;
  backlog §22 划掉、新增 §23):
  **GH #136 落地:WK 终于买得起第二根树枝。`skeleton_king` pos_3
  `item_branches` → `item_double_branches`(pos_2/4/5 别名一起吃到),`life_stealer`
  pos_1 同款一并修。纯构筑、无 gate ⇒ 本轮稳定版漂移。** 零 AWS、零新 gated id、
  零外部读。开工自检 **worst exit 0**(无未落地 commit、cadence 无洞、trunk python 15/15)。
  Owner 优先项 P1/P2 的球都在协同组 ⇒ 按章程取 issue 流最新的 [hero]。
  - **issue 的首要嫌疑对了,但「队列不严格阻塞」这句是错的 —— 采购层结构上补不齐**:
    ① `Item.GetBasicItems`(`aba_item.lua:1239`)丢掉已持有的组件,但**连续重复的第二个**
    被 `sLastRepeatItem` 救回 ⇒ 存活清单 `{branches, recipe}`,**这一步是对的**;
    ② `item_purchase_generic.lua:1250` 的 `_buildRequiredCounts` 数的是**这份已过滤的**
    清单 ⇒ `required = 1`;③ `_stillNeeds` 拿它跟**背包总持有量**(1)比,`1 < 1` 假 ⇒ 弹掉。
    **分子取自过滤后的世界,分母取自过滤前的世界**,只有持有量为 0 时才自洽。
    于是唯一被买的是 recipe —— **与 40/40 局的背包逐位对上**。已单开 **GH #139**
    (不是 WK 专属;非树枝的同款重复组件**一件都没扫过**,见 §23)。
  - **判据被改了,而这正是普查能做对的原因**:**恰好 1 根才是坏的量**
    —— 0 根合法(一根都没有时两根都会买),>=2 合法,只有**部分持有**会被那个计数读成完整。
    全 BotLib 展开合成宏后普查:**367 条想要魔棒的买单,br==1 从 2 → 0**(0 根 6 条、
    >=2 根 359 → 361)。两个 offender = `skeleton_king` pos_3 与 `life_stealer` pos_1。
    **`grep item_branches` 会误报**:batrider 的两处在 **sSellList**、marci 写了**连着两行**
    = 两根。普查已作为**常设断言**入库,并断言两种合法结局都仍非空(否则在空世界上通过)。
  - **「魔棒要两根」锚在仓库自己的数据上,因为离线验不了**:`tests/mock/bot_api.lua:303`
    的 `GetItemComponents` **恒返回 `{}`** ⇒ `Item['item_magic_wand']` 在测试里是 **nil**。
    锚 = `aba_item.lua` 里 15 个带 `item_recipe_magic_wand` 的 `item_*` 合成宏,
    **15/15 供恰好两根**(14 个走 `item_double_branches`,`item_priest_outfit` 走两个独立条目),
    零反例。这条边界写成了断言,**mock 哪天长出真配方它会自己红**。
  - **12 次变异 12 抓,但过程里出了一条该立成规矩的教训**:
    **报告「逃逸」的变异必须先证明它真的施加上了。** M8(拆掉剥注释那一步)第一次报
    **0 红 = 逃逸**,实际是那条 `sed` 的 Lua 模式转义没匹配上,**变异根本没落到文件里**;
    换成 python 精确替换 + 断言 needle 存在之后,M8 立刻被 2 条断言抓住。
    **一个没施加的变异和一个逃逸的变异,在计分板上长得一模一样。**
  - **另一条方法教训(差点骗过自己)**:第一版普查把**修复行上方那段解释注释里被引号
    括起来的 `"item_branches"` 也数成了一次采购**,报 pos_3 有 **3** 根。
    **会读散文的解析器就会报告散文。** 剥注释现在是共用函数 + 专门自测钉住。
  - **诚实边界**:(a) 本轮**不是**一个已测量的收益,是一个**有机制的构筑修复**
    —— 4007 未花金里有一个魔棒形状的洞,但普查说不出解开队头之后剩下的清单会不会真的流起来;
    (b) `life_stealer` **没有自己的语料读数**(不在焦点五、不在 `run_001140` 阵容),
    按结构同一性修,已写进他的文件;(c) 那 4/40 走到 phase_boots/bracer 的局**没有追**
    (大概率是 `rebuildCount < 3` 的 `GetReducedPurchaseList` 旁路);
    (d) GH #136 正文引用的 `tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua`
    **树上不存在**(105 个 fixture,无 `f_260823_*`),已在 issue 上更正。
  - **核验口径 + 一个交出去的红(GH #133 已留言)**:luacheck **0 警告**、新测试 10/10、
    逐文件跑「所有引用 skeleton_king / life_stealer / item_branches 的文件」**全绿**;
    **整套 `run_tests.lua` 在本容器跑不完**(GH #124,两次尝试都卡在慢用例,
    **失败明细只在跑完时打印** ⇒ 一个字拿不到)。但那次跑出的那个 `F` 被定位了:
    **第 507 个点 = `test_lf_rescue_final_action.lua :: [nineteenth world assertion]
    the mock ids are not stable across loads`** —— 该文件**逐文件跑 12/12 全绿**,
    只有进程内才红,是 04:00Z「靠同进程副作用」那条规矩的**镜像形态**。
    **定位方法值得留着**:整套跑不完时点序是唯一信息,而**点序唯一确定用例**
    (文件按名排序、文件内用例按名排序、每例一字符);**坑**:
    `test_itemdesire_world_assertion.lua`(**25** 例)排在 `test_l*` **之前**,
    为省时间跳过它计数会把答案**整体错位 25**(我第一次因此指错到 lion_t15)。
    **没主张它是既存红,只证明了它不可能由本轮造成**:新测试文件字典序排在它**之后**
    ⇒ 第 507 例跑时还没被加载;`bots/` 侧只改了两个物品字符串,而它读的是 mock 的
    id 分配,不读任何买单。朴素复现(预热 mock 再单跑)**没复现** ⇒ 触发条件更具体,
    是 harness 的活。
- 2026-08-23T06:00Z(登记 `state.json:lion_t15_no_flip_20260823T0600Z`;报告
  `iterations/reports/hero/20260823T060000Z.md`;GH **#134** 本组开(跨英雄的映射错误);
  backlog §20 划掉、新增 §21):
  **Lion t15 重开并量完:仍不翻(取 [4] To Hell and Back 增幅),但封存它的两条依据都是错的,
  而且错的方向相反。** `bots/` 本轮**只有注释改动**(理由块)⇒ **稳定版未漂移**;
  零 AWS、零新 gated id、零入集申请;外部读 = 1 次 datafeed(`hero_id=26`)+ 1 次 odota constants
  +(Liquipedia **被限流**,没拿到)。自检 cadence 无洞、trunk python 14/14;
  报出的 3 个未落地 commit 是**总监**的 `busy-bardeen-0blxxb`,按 08-22T23:54Z 的教训**不代人 cherry-pick**。
  - **推翻的两条**:①「[4] 的两个窗口 dumper 看不见(GH #27)」——**看得见**:10 个带 modifier
    的 Lion 帧里 **3 帧在窗口内**(`..._to_hell_and_back_buff` ×2 击杀侧 / `..._respawn_buff` ×1)。
    GH #27 只在**物品充能层数**上还成立。②「[3] 落在 **24 秒**冷却的最后 2 秒」——**24s 是 rank 1,
    那是语料的档位不是域的档位**:15 级 Hex 是 **rank 3 = 16s**,−2.0s 值 **+14.3%** 施法次数
    (16 级 rank 4 起 **+20%**),而不是 +8.3%;rank 2 到货是 **13 级**不是 12 级。
  - **根因是跨英雄的(GH #134,本轮最贵的产出)**:**出货加点行的下标不是英雄等级** ——
    `aba_skill.lua` 的 `X.GetSkillList` 把 **10/15/20 级花在天赋上**,行里第 10 项之后每项都往后推一级
    ⇒ **做 t15 选择那一刻,15 条的行只点掉 13 个点**,最后两项落在 16/17 级。
    新 `tests/skill_level_map.lua` **驱动出货的 `J.Skill.GetSkillList` 本体**回答「N 级几级」,
    不重述规则(M8 教训);三个消费方各带 `spent == 13`/`spent == 9` 守卫。
  - **被它改掉的三个历史读数,裁定一个没翻、数字三个全错** —— **这正是这类错误可怕的地方:
    它只改理由不改结论,所以结论复核永远抓不到它**;换一个更接近的对子它就会翻掉判断。
    **Axe t15**:Call 是 **rank 3** 不是 4 ⇒ 上限 **0.19** 不是 0.25、比值 **~5x** 不是 4x、
    被拒那边相对增幅 **+71%** 不是 +67%。**Lion t10**:Mana Drain 在选天赋那一刻是 **rank 3**
    ⇒ 放弃的是 25→35 **不是最大档 30→40**,**这个改动比它当初的写法更有支撑**。
  - **定案通道 = 稀缺性**:冷却减免只在「冷却是拦路虎」的帧付款,而 20 个学了 Hex 的帧里
    **Hex 就绪 9 帧、且 9 帧全付得起自己的蓝**(最穷 176 对 rank 1 的 110)⇒ **稀缺的是目标不是
    Hex 次数**。**这一条就是它与 CM t10 的分水岭**:那边技能**缺蓝**,这边技能**闲着**。
    ≤2s 转化带 **0/11**,均匀取帧期望 **~0.9** ⇒ **UNDERPOWERED 不是 EMPTY**(GH #115)。
  - **在位者比旧注写的更宽**:innate 的 spell-amp 那一半抬的是 Earth Spike / Finger 的**伤害**
    ⇒「两边买的是同一样东西(Hex 控制量)」也是错的;+15pp 打在 20% 底上 = innate 的 **+75%**。
    **被拒那边最强的话照记**:复活窗口**被成功关掉**(下一个击杀/助攻即结束)、击杀窗口**要求先有人头**
    ⇒ **势均力敌的团战里两个窗口都不在**,而那正是短冷却会付款的地方。
  - **诚实边界(最重的一条)**:**整个语料一帧都不在域内**(Lion 最高 11 级,天赋 15 级才存在)
    ⇒ 全部是**低四级的代理读数**,已写成断言(`in_domain == 0`)。另:天赋数值**不在 datafeed 里**
    (两个天赋的 `special_values` 都是空的),−2.0s / +15% 取自 **odota dotaconstants**。
  - **12 次变异 12 抓**(含「把读数器改回数行下标」「Axe/Lion 取值等级 +1」三个专打本轮修法的变异)。
    变异前先 commit —— 08-23T02:00Z 那个坑本轮没再踩。
- 2026-08-23T04:00Z(登记 `state.json:axe_t15_no_flip_20260823T0400Z`;报告
  `iterations/reports/hero/20260823T040000Z.md`;backlog §18 **全部对子闭合**、
  新增 §20):
  **Axe t15 裁定:不翻,[3] +8 Battle Hunger dps 留着 —— 焦点五天赋梯子重锚的最后一个
  对子闭合。`bots/` 本轮的唯一改动是必须随行的理由块(纯注释),稳定版未漂移。**
  零 AWS、零新 gated id、零入集申请;外部读 = 1 次 datafeed GET(`hero_id=2`)+ 2 次探测
  (dotabuff 403 仍抓不到 pick-rate)。开工自检 **clean**(无未落地 commit、cadence 无洞、
  trunk python 13/13)。
  - **这次是这把尺子第一次两个通道同向**:结构上限 4:1(BH 12s/5s ⇒ 1.00 对
    Call 3.0s/12s ⇒ 0.25,15 级两边都 rank 4,等级从**本文件自己的加点行**解析)、
    语料 5:1(16 个带 modifier 的 Axe 帧上 BH 活 5、Call 护甲活 1)。
  - **让这个 5:1 能被读懂的是第三个数**:按帧上实际等级求和的结构上限是 **14.00 / 1.94**
    ⇒ Call 已在自己天花板的**约一半**(SATURATED),BH 只到**三分之一**。
    **差距是天花板,不是可补的余量** —— 没有这一步,「1 帧」会被读成「bot 不爱放 Call」。
  - **最重的诚实边界:整个语料一帧都不在域内**(Axe 最高 14 级,天赋 15 级才存在)。
    全部是**低一级的代理读数**,已写成断言(`in_domain == 0`),等语料越过 15 级要重取。
  - **保留 [3] 的代价照记**:`damage_per_second` 恰好被读一次,就在 `X.ConsiderW`
    乘满 12s 塞给 `J.WillMagicKillTarget` 的那个声明里 ⇒ [3] **不是纯引擎效果**;
    [4] 零消费点。两半都是断言。
  - **12 次变异 12 抓,但第一版 10 抓 2 逃,两条逃逸都值得别的组拿走**:
    ① **M8**「把 `abilityW` 改指 `sAbilityList[3]`」全绿逃逸 —— 因为 Counter Helix
    **也**在 15 级满 4 级,**等级相同所以断言没动**。教训:**从代码里读出来的映射,
    如果它的下游取值在两种接线下碰巧相等,那它就没被钉住**;修法是直接钉槽位号,
    并用语料 dump 出来的技能顺序(`axe_berserkers_call` / `axe_battle_hunger`)佐证
    —— **mock 给的是合成槽名,离线只有语料能回答这个**。
    ② **M11**「整块删掉理由块」全绿逃逸 —— 因为我写的守卫断言的是一个**从来没在文件里
    出现过**的短语(`needs its own work unit`,原文是 `needs its own round`)。
    **一个「某某不在」的断言,如果那个某某本来就不在,它就是恒真的装饰**;改成按
    t10 守卫的形状列**六条各自独立的正面 needle**。顺带:needle 是逐字匹配,
    注释**换行会把短语劈开**(`One Man / Army`),这让守卫在基线上就红了一次。
  - **顺带发现,并且它比本轮的裁定更值钱**:**fixture 是带 modifier 的**(45/101,
    2026-08-19 之后裁的全带,name/remaining/elapsed/stacks)。§18 的 Lion t15 用
    「dumper 看不见 modifier」封存了 [4] 那一半 —— **那条依据作废**,而且那两个窗口
    现在就在语料里(3 例)⇒ **Lion t15 可以重开**(见 backlog §20;重开的是依据不是结论)。
    **又是同一个坑第二次**:载体 `tests/test_fixture_modifiers.lua` **早就在树上**,
    本仓的世界断言知识主要在 `tests/` 里,不在 issue 里。
  - **全套核验,而且它自己长出了一个结果**:单进程 900s 又被 timeout 杀掉(失败明细
    **跑完才打印** ⇒ 一个字看不到);改逐文件跑(变基前的树)**145 文件 / 10 bad** ——
    9 个与 02:00Z 在 main 上实测的 31 断言点逐个一致,第 10 个是我设的 300s 上限撞上
    `test_itemdesire_world_assertion`(GH #124 登记约 18 分钟),放宽到 1500s **24/24 绿**。
    变基带进总监 `e8b030f` 后重跑那 9 个:**7 个被总监清掉,剩 2 个本轮顺手修了** ——
    正是 02:00Z 点名「看起来与语料规模无关但 main 上就红」的那两个,**它点对了**:
    它们与 GH #127 的语料等式不是一回事,是**同一种进程内排序 bug**。
    ① `test_wk_reincarnation_mana_gate`(本组文件,6/6 红):`fresh_jmz()` 先
    `api.reset_modules()` 清掉引擎全局、下一行就调 `GetScriptDirectory()`,而每个用例
    都是**先 fresh_jmz 再 make_bot** ⇒ 真正装 bot 的 `api.install` 来得太晚;
    以前能过是因为**同进程里更早的测试文件**把全局留着。修法:先装占位 bot。
    ② `test_relicguard_siege_gate`(strategy 的文件,7 红):**整个文件从没写过**
    `package.path = 'tests/?.lua;' ..`,只在别人先设过时才 require 得到。补一行。
    **立成规矩:「靠同进程里另一个测试文件的副作用」不是共享 setup,是一个只在逐文件跑
    时才现形的排序 bug** —— 而我们正因为 GH #124 越来越走逐文件,这类 bug 只会**越来越多**。
    ⇒ **本轮读数:145 文件 0 红。** 文件数 142→145,GH #124 的成本单调上升。
  - **一条通用纪律**:`elapsed` **不是**「已经跑了多久」——lich 的 BH 是
    elapsed 13.1 / remaining 9.6 = 22.7 秒,而 BH 只有 12 秒;不叠加的技能重放是**刷新**,
    remaining 重来、elapsed 从第一次继续数。**只有 remaining 能用**,已写成断言。
- 2026-08-23T02:00Z(登记 `state.json:cm_pos5_boots_20260823T0200Z`;报告
  `iterations/reports/hero/20260823T020000Z.md`;GH **#126** 已留言不关闭;
  queue **`hero-5`** pending;backlog §19 划掉):
  **CM 的 pos_5 换鞋落地 —— 秘法进,Boots of Bearing 跟着出去。纯构筑、无 gate
  ⇒ 本轮稳定版发生漂移。** 零 AWS、零新 gated id;外部读 = 2 次 datafeed GET
  + 1 次 opendota constants。
  - **开工自检又捞回两个 commit**:23:54Z 的 `915afd7`/`18fddd9` 躺在
    `origin/claude/vibrant-heisenberg-c2bxdy` 上从没进过 main,cherry-pick 干净落地。
    **这是连续第三轮由自检抓到的同一件事** —— 工具有效,前提是有人跑。
  - **改动**:`hero_crystal_maiden.lua` pos_5 `item_mage_outfit` →
    `item_crystal_maiden_outfit`,并删 `item_boots_of_bearing`(13→12 条);
    `aba_item.lua` 给 `item_crystal_maiden_outfit` 补回第二个 tango
    (**让它与 mage_outfit 只差鞋这一项**,杠杆才干净)+ 哨兵
    `tDefineItemRealName` 从 `item_magic_wand` 改成 `item_arcane_boots`(与两个同胞一致)。
  - **为什么同一把尺子在 t10 说不翻、在这里说换**:(a) t10 上测量与条件 (c) **相反**
    (最脆的英雄要 +200 血),这里**同向**(CM 是教科书秘法鞋辅助,而这棵树自己的
    pos_4 CM 已经在买秘法,`item_crystal_maiden_outfit` 从 fork 前就躺着没人用);
    (b) **t10 没有观察臂,这里有一个**,就在同一份语料里(秘法臂 0/14 vs 宁静臂 12/45)。
  - **必须记住的配方事实**:`boots_of_bearing` = tranquil_boots + ancient_janggo +
    ring_of_tarrasque。**改一双鞋之前先查它是不是某件成品的组件** —— #126 的处方
    单独执行会留下一双 1500g 的死鞋。
  - **本轮自己踩的坑(方法级)**:变异测试用 `git checkout <file>` 还原,
    把**同文件里未提交的真改动一起还原了**;而未追踪的 sweep 文件 checkout 报错,
    三个变异反而叠着留在文件里。**变异前先 commit,或用备份还原,不要对着有未提交
    改动的树 checkout。** 结论已作废重跑(7 变异 7 抓)。
  - **改出装会让历史帧的库存变成过期证据**:
    `tests/test_replay_260820_cm_es_aftershock.lua` 的角色判别本来靠
    「pos_5 穿宁静 / pos_4 穿秘法」,换鞋后两边都穿秘法,那一帧手里的宁静
    **不再属于任何一张单子**(它是 08-20 录的)。判别器靠没动过的
    `null_talisman` / `urn_of_shadows` / `blood_grenade` 活下来,已如实改写。
- 2026-08-22T23:54Z(登记 `state.json:cm_t10_no_flip_20260822T2354Z`;报告
  `iterations/reports/hero/20260822T235428Z.md`;GH **#126**(本组,裁定 + 出装杠杆);
  GH #125 是本组开错的重复件,**已自行关闭**,见下);backlog 新增 §19):
  **两件事:① 把 21:48Z 那一整个工作单元从支线捞回主干;② CM t10 对子核验 —— 不翻。**
  **`bots/` 本轮零改动**(除随 ① 落地的 Lion t10 那一行),**稳定版未漂移**;
  零 AWS、零新 gated id、零入集申请;外部读 = 1 次 datafeed GET(`hero_id=5`)+ 2 次检索。
  - **① 落地**:开工自检报出 `483b818`/`edf4ed1` 在 `origin/claude/vibrant-heisenberg-qypj8j`
    上**从没进过 main**(= 21:48Z 的 Lion t10 全部产出)。cherry-pick 落地,`state.json`
    三方撞车按**两边都保留**解掉。**收尾更正:cherry-pick 最终仍是多余的** ——
    rebase 报 `skipped previously applied commit a0d681f / 6a3a6b4`,
    21:48Z 那个会话在本轮进行期间自己落地了(`b86c82d`)。树干净、无重复
    (`hero_lion.lua` t10 只有一份,state 两个键都在)。**同一个教训第二次犯:
    自检那一刻的读数没错,错的是「未落地 ⇒ 无人认领」这个推论。下次先看分支
    时间戳/对应会话是否还活着,或等一个心跳,别立刻 cherry-pick。**
  - **② CM t10 不翻,而且是这把尺子第一次给出「不翻」并有量测支撑**。四个通道各带
    健康度:**可施放** 26 个就绪槽 **11 个付不起自己的蓝、9 个落在 +144 带内**
    (+120→7 / +168→11,不吊在「1 智 = 12 蓝」这个常数上,三个技能 3/3/3 均摊);
    **文件自己的阈值**(从源码解析)蓝世界跨 **5 次/3 帧**、血世界 **0 次/0 帧**;
    **判据通道**(驱动真 `SkillsComplement`)**两边都 0/12**,但**基线自己就一帧没排技能**;
    **死亡通道 0 个样本**(域内 CM-subject 帧 = 0)。
  - **不翻的理由(按分量)**:(1) 血那边的零是 **UNDERPOWERED 不是 EMPTY**(GH #115),
    翻面要求**被放弃那边够不着**,而这里够不着的是**尺子**;(2) 条件 (c) 指向相反 ——
    标准打法在全图最脆的英雄身上偏好 +200 血(蓝能用装备补、脆不能);
    (3) 成因在上游且更便宜(§19 的出装)。**域本身**:42 个 CM 帧只有 **12 个 ≥10 级**,
    30 帧出域 —— 这条 caveat 撑着整篇读数。
  - **判据通道为什么静默 —— 一半语料一半世界(**已有的第十三条世界断言**)**:7/12 帧 1600 内
    没敌人;而 fixture 里 `GetActiveMode()` 恒 **0**、`BOT_MODE_*` 是 **≥1001 的自动哨兵**
    ⇒ **`== BOT_MODE_X` 恒 false(全仓 131 处 / 65 文件)、`~= BOT_MODE_X` 恒 true(84 处)**。
    CM 的 **8 个蓝阈值有 4 个**正长在模式相等块里(对线 `:746`×2、Roshan `:567`/`:887`)
    —— **恰恰是蓝天赋会兑付的分支**。**不推翻任何历史裁定**,但凡「域空」读数的谓词或
    上游带模式相等判断,那个零要改按 UNDERPOWERED 读。
  - **变异 5 次 5 抓,但第一版 4 抓 1 逃,逃的那次是本轮最该被别的组拿走的一条**:
    M4「让 sweep 干脆不施加天赋差分」**全绿逃逸** —— 判据通道本来就每帧静默,于是
    **「没造出差分世界」和「造了但没改变决策」读起来一模一样**。
    **可复用:一个以「静默」为结论的通道,必须单独证明被静默的那件事真的在场。**
    处置:sweep 输出 `WORLD` 行(三个世界各自的真实血/蓝),测试断言 H 恰好 +200 血、
    I 恰好 +144 蓝、且各自只动一个池子 ⇒ M4 立刻转红。
  - **一处自我更正(别引用第一版)**:看到 11/13 帧没秘法鞋时第一反应是「实战偏离了
    文件出装」——**错的**,pos_4/pos_5 都是文件自己的表;真事实是**pos_5 这条线本身没蓝装**。
  - **交付**:`tests/test_cm_t10_payoff.lua`(11 例)+ `tests/_cm_t10_payoff_sweep.lua`;
    `test_focus_talent_anchor.lua` CM 行加「已核验、故意不翻」注释(**期望值未动**)。
    阈值一律**从源码解析**不复述(M13);`nKeepMana = 220` 是绝对地板,已写成断言。
  - **本轮开错一个 issue 并自行关闭(教训值得别的组拿走)**:把 `GetActiveMode` 盲窗
    当新发现开成 GH #125「第十七条」,**其实是仓库已有的第十三条**,载体
    `tests/test_activemode_world_assertion.lua` 是**本组自己**当天早些时候写的
    (`8f11984`),而且**比本轮写得全**(它还量了 loader 侧 `GetNearbyHeroes` 忽略
    mode 参数导致的**过度宽松**那一半)。**成因:开 issue 前查了 issue 搜索
    (命中 0),没查 `tests/`。这个仓库的世界断言知识主要存在测试文件里,不在 issue 里。**
    **下次正确顺序:先 `ls tests/test_*world_assertion*`,再 grep API 名,最后才搜 issue。**
  - **棒子(铁律 9)**:本组 —— backlog §19(出装杠杆);焦点五天赋梯子只剩
    **WK t10/t15** 与 **Axe t15** 没过这把尺子。总监 —— **主干自己是红的**:
    `a96e107` 干净树跑全量 = **1315 / 21 failures**,本分支 = **1335 / 同样的 21**,
    两份 FAIL 清单 **逐字节相同** ⇒ 本轮 **+20 全绿、零新增失败**。成因是 `70aefe5`
    加了第 101 个 fixture 只改了一个文件,语料规模的**等式**还钉在另外六个文件里
    (已留言 **GH #106**,那条 issue 正是这件事)。**本组据此同步进 main**,
    理由与回退方式写在报告 §3.1。批测台 —— **无请求**。
  - **又一条测量更正(手法级,别复用)**:本轮一度说「21 个用例单跑都通过」——
    **错的**。`lua5.1 tests/test_x.lua` **只加载文件返回用例表,不跑断言**,必然 exit 0。
    单跑一个文件必须自己 `for name, fn in pairs(dofile(...)) do fn() end`。
    正确的对照是两次全量(见上)。**本轮两次自我更正都属同一类:先确认量具真的在量。**
- 2026-08-22T21:48Z(登记 `state.json:lion_t10_flip_20260822T2200Z`;报告
  `iterations/reports/hero/20260822T214800Z.md`;backlog §18 又划掉两条):
  **Lion t10 翻了(焦点五第三个翻的对子),Lion t15 明确不翻。零 AWS、零新 gated id、
  零新波次**,外部读 = 1 次 datafeed GET(`hero_id=26`)。**唯一的行为改动是
  `hero_lion.lua` 的 `['t10'] = {0,10} → {10,0}`**(+10pp Mana Drain 减速 → +20 移速),
  纯数值不 gate ⇒ **已在稳定版里,请总监记一笔稳定版漂移**。
  - **尺子还是「兑付可达性」,而这次它给出的对比最干净**:被放弃的那一边**只有一个收款处**
    (对**敌方英雄**读条抽蓝),而那个收款处是 `X.ConsiderE` 里的**残余动作**
    —— 四个 return 只有两条是敌方英雄,且两条都在
    `if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end` 下面
    ⇒ Q/W/R **同时**不可用才轮得到它;取的那一边**一个谓词都没有**。
    真实帧:**22 活 Lion 帧 / 闸门开 8 / 整条链 2,而这 2 帧全是本组自己为研究抽蓝裁的**。
  - **诚实边界(引用必带)**:语料有偏 ⇒ **存在性不是密度**;**放弃的正是它最大的那一版**
    (加点表 10 级就 rank 4,减速 30→40)—— 与 Zeus t15 同一笔交易;+20 对 **290** 基础、
    `pos_4/5` outfit 自带秘法鞋 ⇒ 实战相对增幅约 **+6%** 不是 +7%;
    **没有测量减速收到手之后改变了多少结果**,主张只到可达性。
  - **t15 不翻是一个结论不是一次跳过**:两边的域**都离线不可量**([3] 是 24 秒冷却
    最后 2 秒的窄带,按 18:00Z 规矩零记 UNDERPOWERED;[4] 的两个窗口 dumper 看不见),
    而且**两边买的是同一样东西**(Hex 控制量:次数 vs 时长)⇒ **没有可花的不对称**。
  - **交付**:`tests/test_lion_t10_payoff.lua`(9 例,**10 次变异 10 抓**),
    `test_focus_talent_anchor.lua` lion 行 `t10=1→2`(**棘轮又一次抓住本组自己的改动**)。
    §2 是**防空转下界 + 不等式**不是语料等式(GH #106);§3/§4 是**加点表棘轮**
    —— 加点一改,两条诚实边界/两个判断自动失效并报出来。
  - **变异纪律(连续第四轮记同一个坑口,本轮把它写进脚本)**:变异脚本先比对
    「文件到底变了没有」,不变就打印 `MUTATION DID NOT CHANGE THE FILE -- verdict meaningless`
    而不是读判定。另:**M5 不是正交的**(推后第 4 点抽蓝同时提前第 2 点 Hex ⇒ 同时红 §3/§4),
    如实记,不当两次独立抓捕。
  - **全量套件抓到一件真事(本轮最该被别的组拿走的一条)**:第一次全量 **1311/1 failure**,
    红的是本组 08-19 留下的绊线 `test_replay_260819_lion_drain.lua:317` ——
    它用 `src:find(...)` 在**原始源码**里找「早退」这个代码地标,而本轮写在文件顶部的
    理由块**逐字引用了那一行** ⇒ 第一处命中落在注释里,绊线报出「补篮分支跑到早退上面了」。
    **出货代码一个字没动,红的是绊线自己。** 处置是**修绊线不是改措辞**:地标改成按行、
    **代码地标只在非注释行上算数**,并**反向验证 4 次变异 4 抓**(guard 上移 / 早退上移 /
    删 guard / 去 gate)。**可复用:用字符串找「代码地标」的测试必须排除注释行**,
    否则任何引用该行的说明文字都会让它变红,而且**红的信息是假的**。
    本仓已有 `live_lines()` 现成写法,但绊线类测试普遍是裸 `src:find` ——
    **建议总监按全仓扫一遍同型**。
  - **收尾时发现 main 是红的,核实过再说话(GH #127)**:第三次全量(rebase 到 `cde1d6c` 后)
    **1324 / 18 failures**,而同一棵树在 `4767f69` 上是 **1311 / 0**,中间本组一个字没改。
    **开了一个不含本组任何提交的干净 `origin/main` worktree 逐文件复跑,18 条一条不差地复现**
    (七个文件)⇒ **trunk 自己红,本组 delta 为零**。成因:新落地一枚 fixture 让语料 100→101,
    而七个文件把**语料规模钉成等式** —— **GH #106 立的案**(当时 5 个文件,今天 7 个/18 条断言)。
    **处置**:照常 push(delta 零),同时开 #127 交总监。**本组自己的 §2 用的是下界+不等式,
    那枚 fixture 落地时它一声没吭** —— 这就是两种写法的差别。
  - **棒子(铁律 9)**:`queue.json: hero-4`(pending,无新波次)——(1) 按目标类别
    分开数 Mana Drain 读条(敌方英雄/小兵/幻像)+ 时长,**它决定的是写下的理由还成不成立**
    (塌了就翻回去并在文件里说明);(2) 数「`ConsiderW` 开火条件成立但 Hex 还剩 ≤2s 冷却」
    的时刻数,**唯一能让 t15 变成可判定对子的读数**。
- 2026-08-22T19:50Z(**GH #122**;登记 `state.json:zeus_t15_flip_20260822T1950Z`;报告
  `iterations/reports/hero/20260822T195000Z.md`):**本轮真的改了出货行为,而且是
  连着六次「DO NOT WRITE/ARM」之后的第一次** —— 但改的是**天赋表**不是判据:
  **Zeus t15 `{0,10}` → `{10,0}`**(+75 大招伤害 → Arc Lightning 蓝耗/冷却 −20%),
  **纯数值、不 gate ⇒ 已在稳定版**;**CM t15 明确不翻**并把理由钉成断言。
  **零 AWS、零新 gated id**,外部读 = 2 次 datafeed GET。详见 backlog §18 的两条划掉项。
  - **本轮方法上的一条(值得别的组拿走)**:六次否决教会的是「先量域」,**但天赋对子
    量不出域** —— 两边都不是 gate,没有 armed/shipped 的对照臂。能问的是**兑付条件的
    可达性**:哪一边的收益**依赖一件在这棵代码里更常发生的事**。Zeus 那一对因此有解
    (放不出去的大招 vs 每发都省的蓝),CM 那一对因此**无解**(削的是不卡人的那个量)
    —— **同一把尺子,一个翻一个不翻,这才是尺子而不是口味。**
  - **诚实边界(引用必带)**:Zeus 的读数来自**为别的调查裁的 100 帧 fixture**,
    是**存在性不是密度**;**每个就绪帧都是大招 rank 1**,那里放弃的 +75 是 **+27%**
    —— **单次兑付更大的那边正是被放弃的那边**,本轮按频率放弃它;**Arc 每局几发没数**。
    这三条都进了 `hero_zuus.lua` 的理由块,不是只写在报告里。
  - **棒子(铁律 9)**:`queue.json: hero-3`(不需要新波次,档案语料扫描):数 Arc
    每局施法数 + 大招就绪瞬间的蓝对 rank cost(Zeus 与 CM 各一份)。**它决定的不是这次
    改动能不能上(已经上了、无 gate 可 arm),而是写下的理由还成不成立** ——
    塌了就按 `test_focus_talent_anchor.lua` 的要求翻回去并在文件里说明。
  - **交付**:`tests/test_focus_t15_payoff.lua`(10 例,**9 次变异 9 抓**),
    `test_focus_talent_anchor.lua` zuus 行 `t15=3→4`(**这个棘轮本轮抓住了本组自己的改动,
    它就是干这个的**)。§3 的语料普查**写成下界不是等式**(GH #106)。
  - **门**:luacheck 0 警告 + 全量 **1286 tests / 0 failures**(跑在要 push 的那棵树上;
    套件启动后只改 `iterations/` 下的文件,测试不加载那些路径)。**本次全量约 25 分钟**
    —— 章程记的「约 93 分钟」那次的慢尾巴 `_itemdesire_sweep` 本次没复现,记下观测不改记载。
  - **连续第三轮栽在同一个坑口**:M5 第一次「逃逸」是假的 —— perl 替换没匹配上,
    **文件根本没变**。按行号重做后抓住。上一轮记的是「变异改错了地方」,本轮是更基础的
    那一版。**在确认文件真的变了之前,「抓到/逃逸」这个判定没有意义。**
- 2026-08-22T18:00Z(登记 `state.json:axecull_preflight_20260822T1800Z`,GH #115 §5):
  **本轮两件事:① 把 15:47Z 那一整个工作单元捞回主干;② Axe 处决线 lever 的上机前核验。**
  - **① 落地 —— 但收尾时结论下调了,如实记**:开工自检(17:36Z)报出 `3a73e39`
    「pushed 但从没进 main」,于是本轮 cherry-pick 了它。**push 前 rebase 撞车才发现:
    那棵树在本轮进行期间已由别人落地(`270bbea`)** ⇒ **本轮的 cherry-pick 是多余的**
    (rebase 里作为重复内容解掉,无害)。**自检 17:36Z 的读数没错**(那一刻确实没落地),
    **错的是本组从它推出的「所以没人管」** —— 并发会话下 **未落地 ≠ 无人认领**。
    **处置建议:看到 UNLANDED 先认领而不是重做,动手前再拉一次 `origin/main`。**
    另:原以为那份报告的收尾占位符是空的,**不对** —— 落地版自带完整收尾
    (1255 tests / 真实 token 行 / 「全量约 93 分钟,慢的是 `_itemdesire_sweep`」),
    rebase 时**保留 main 那一版**,没拿本轮数字冒充。(本轮 1263 = 1255 + 新增 8 例,自洽。)
    **仍然有效**:自检报出的另 2 个未落地 commit 属协同组(`a053082` / `6325e96`,
    17:30Z 的 P1 选点分析),**截至本轮收尾仍不在 main 上**,动的是 owner 优先项 P1。
  - **② `axecull` 核验 —— DO NOT WRITE(本轮),处置第七类 `NARROW-BAND-UNMEASURABLE`。**
    **这是本轮最该被别的组拿走的一条**:前五次核验都以「域空」告终,而且每次都能指出
    一个结构性成因;**这一次五种成因一个都不成立,域也没被证空 —— 是被证「量不出来」**。
    读数:26 帧带 Axe / 20 帧 Culling 就绪(挡住的:4 未学、1 冷却、1 蓝)/ **3 帧**
    敌人在有效 375u 环内 / 带内 **0**。**25 点带对约 1000 血池 ⇒ 3 个环内帧的期望命中
    ≈ 0.08** ⇒ 要 ~40 帧才期望 1 次命中,几百帧才谈得上速率。**把这个零记成「域空」
    就是把一次假阴性打扮成严谨。** 可复用先验(建议进 §Y.2 旁):
    **域是连续量上一条窄带(血/蓝/距离)的杠杆,根本不能用帧语料量;帧语料的零一律记
    UNDERPOWERED,不许记 EMPTY。** 现有 §Y.2 说「桌面能证 EMPTY 不能证 RARE」,
    窄带是那条规则的角落 —— **连 EMPTY 也证不了**。
  - **不依赖域的那半(最强 (c),已写进 state)**:陈旧是**双向**的。今天常数低 25 点、
    代价是漏一发;它写下时**是对的**;下一次数值改动把它顶到实际伤害之上,bot 就会拿
    **80 秒大招**打**打不死**的目标 —— 比今天更坏且无声。`GetSpecialValueInt('damage')`
    一次消掉两个方向。**这是关于源码正确性的论证,不是关于那条带的行为主张**,所以本轮
    记录而不上机。
  - **第二根杠杆(单独登记、没动)**:`nInRangeEnemyList`(175 那张表)**算完从不读**,
    开火循环跑 `nCastRange + 200` ⇒ **有效环 375**,分支会对**射程外 200u** 的目标返回
    DESIRE_HIGH。GH #115 预注册域写的「175 内」**口径是错的**,已在 queue 里纠正。
  - **两条工具教训(都比上一轮那版更锋利)**:
    **(甲) 变异「逃逸」三次,三次都是打错了函数。** `hero_axe.lua` 的
    ConsiderQ/ConsiderW/ConsiderR **代码形状近乎重复**,`perl -0pi -e s///` **不带 /g**
    只换第一处 ⇒ 落到 ConsiderQ(:433)或 ConsiderW(:456/:500)。测试按 ConsiderR
    **函数体**取域,忽略它们**是对的**;按行号(644/650)重打,3/3 全抓。
    上一轮的教训是「变异根本没改到文件」,**本轮是更危险的那一版:改到了,改错了地方
    —— 在确认变异落在哪儿之前,「抓到/逃逸」这个判定本身没有意义。**
    **(乙) 别用正则读 fixture 语料。** 本轮第一版 Python 正则扫描把 Axe 帧数读成 **10**
    (真值 **26**),会把一个**够得着的环(3 帧)**读成空环 ⇒ 正好产出本组反复警告的
    那种「自信的错结论」。发表的数字全部来自对每个 fixture `dofile`(测试用的同一个加载器)。
  - **交付**:`tests/test_axe_culling_threshold_preflight.lua`(8 例,7 次变异 7 抓)。
    §1/§3 是**源码棘轮**(常数被修好、或 ConsiderR 长出第二条开火分支时变红,并把话说明白
    防止有人「修回退化」),§2 是**绊线**而非语料等式(GH #106):断言一个全称句,
    加 fixture 只会让它更强,而带内真的落进一帧时它变红并**点名那一帧** —— 那正是这根杠杆
    需要的真实帧。**零行为改动**(没碰任何 `bots/` 文件)。
  - **棒子(铁律 9)**:`queue.json: hero-2` 已提 —— **改到事件侧数**(数施放 + 数「射程内带内
    却没放」的时刻),并写死了两条对 GH #115 的口径纠正 + 「别用正则数语料」的板凳提示。
- 2026-08-22T15:47:46Z(**GH #118**,登记 `state.json:wkqaim_preflight_20260822T1547Z`):
  **`wkqaim` 上机前核验完成 —— DO NOT WRITE,而且这次它连 gate 都没写过**
  (`queue.json: hero-1` 的接力棒,批测台 14:12Z 交回本组的检测器侧)。**零 AWS、零新波次**,
  唯一外部读是 2 次 datafeed GET。两条**独立**理由,任一成立即足够,两条都成立:
  - **(1) 供给饥饿**:catch-all 是 `X.ConsiderQ` **十个开火点里的最后一个**,十个共抢**同一发 14 秒技能**。
    构筑事实(从 `tAllAbilityBuildList` **真表解析**):`{2,1,2,3,2,6,2,3,3,3,6,1,1,1,6}` ⇒
    Wraithfire Blast **英雄 2 级点 rank 1、12 级才 rank 2** ⇒ **2-11 级全程 14 秒冷却**,
    而 GH #84 说 turbo 高水位 19、到 20 级的 **0/210** ⇒ rank 1 就是这局的常态。
    真实帧事实(本仓 100 个 fixture 逐帧扫):**6 个「活 WK + 568u 内 >=2 活敌」的环帧,
    6/6 的 Blast 没学(2)或在冷却(4),一帧都没到过这条分支**。
    **最硬的一列是冷却**:13.1 / 13.3 / 13.4 —— 14 秒里的 >13 秒 ⇒
    **走进两人包围圈那一刻,Blast 是「刚刚才放掉」的**,不是运气,是十个开火点抢一发技能的直接观测形态。
  - **(2) 上游同胞(第七类,建议名 `UPSTREAM-SIBLING`)**:`X.ConsiderQ` 里**三条**分支取
    `nEnemysHerosInRange[1]`(引擎按距离排序 `BOT_API_REFERENCE.md:1229`,
    `J.GetNearbyHeroes`(`jmz_func.lua:2517`)**只过滤、从不重排**)。紧邻 catch-all **上方**的
    「受到伤害时保护自己」(lv>=6)在 `WasRecentlyDamagedByAnyHero(3.0)` 上开火 ——
    **正是本修复瞄准的那些战斗帧**,瞄得一样瞎,**而且它是出厂代码没有 gate ⇒ 无条件先拿走**。
    与 `liondrain`/`liondrainstop`(GH #97)同形,但**同胞在上游**:那次是「别的门在下游做了同一件事」,
    这次是「**出厂代码在上游已经把帧吃掉了**」。⇒ `wkqaim` 若复活**必须同时覆盖上面那条分支**,
    且两条目的不同(自保 vs 消耗)不能共用一个偏好函数,得各带各的帧证据。
  - **前提本身成立,塌的是可达性**:6 个环帧里 **3 个「最近 != 最残」**
    (例 `f_260820_181711_wk_l1trade_333` t=333.5:最近 jakiro 399 血 / 最残 juggernaut 160 血,539u)。
    同 `zusultx` 那轮:**立案缺陷存在 != 这个补丁会在那些帧上生效**。
  - **交付**:`tests/test_wk_q_aim_preflight.lua`(**9 例**)+ `hero_skeleton_king.lua` 决策点
    **25 行注释**(`git diff --stat` = 1 file / 25 insertions,**零行为改动**)。
    **§1 故意做成 TRIPWIRE 不是普查等式**(GH #106 立的就是「语料规模被钉成等式」的案):
    断言的是全称命题 ⇒ 加 fixture 只会更强,而**它变红那天,红的信息正好是 `wkqaim` 要的真实帧**
    (报错直接打出 file/t/等级/环内最近与最残),测试里写明「变红是好消息,别当回归修」。
    §1 还单独钉**归因形状**(6/6 必须归于技能供给而非蓝/等级);§2 钉分支顺序;
    §3 从真表解析构筑钉「rank 2 不早于 12 级」⇒ **构筑一改,本轮核验自动失效并报出来**;
    另有**两条防空转断言**(库里 >=20 帧有活 WK —— **下界不是等式**;环 >=2 的帧至少 1 个)。
  - **变异 7 次 7 抓,其中两条是教训**:
    ① **M7(在 catch-all 之后追加一条开火分支)第一版逃掉了** —— 断言写成了
    「最后一个 `return ..._HIGH` 在 catch-all 判据之后」,而**任何**追加在下面的分支都满足这个序关系,
    恰恰是要抓的那种改动;改成**计数**(判据之下有且仅有 1 个开火点)才抓住。
    **可复用:「X 是最后一个」不要写成序比较,要写成计数。**
    ② **M2 第一次也「逃掉」,但那次是变异本身没生效**(`perl -0pi -e s///` 不带 `/g` 只替换第一处,
    4 条循环变 3 条,而断言是 `>=3` ⇒ 本来就该通过);补跑 4→2 才是真边界(抓)。
    **一个没真正改到文件的变异什么也没证明** —— 两次都回查了「文件到底变了没有」。
  - **门**:luacheck 0 警告 + 全量 **1255 tests, 0 failures**(**跑在 rebase 之后、要 push 的那棵树上**)。
    **过程教训**:第一次全量跑到一半时本组还在改被测的 `hero_skeleton_king.lua` 注释 ——
    运行器逐个文件 `loadfile`,**跑到一半改被测文件,那一跑就不对应任何一棵树** ⇒ 作废重跑。
    **全量跑期间不要碰被测文件。** 本次全量耗时约 **93 分钟**(历史记的 ~45 分钟偏乐观;
    停在 1196/1255 那十分钟进程是 `R`/86% CPU 在真算,慢的是套件固有的尾巴
**`_itemdesire_sweep`**(总监 16:50Z addendum 的 bonus 跑独立停在同一个 1196),**不是本文件**——
    单独跑 `test_wk_q_aim_preflight` 是秒级)。
  - **诚实边界**:fixture 库是为**别的调查**裁的 100 帧、**有偏**,本轮的零是**存在性阴性不是密度**
    (§Y.2 的本地形态:**能证 EMPTY,不能证 RARE**)⇒ **`hero-1` 不算 done**,
    那 153 局的普查仍是决定性读数;环**忽略视野**(fixture 列全部英雄)⇒ 每个环是**上界**,
    「一帧都没到过」是在一个至少和 bot 看到的一样大的环上量的,近似方向安全;
    **(2) 没有帧级量化**(fixture 不带 `WasRecentlyDamagedByAnyHero` 的**前向**状态,
    `observed.burst` 是**之后** 15 秒)⇒ 它是**结构性论证 + 源码棘轮**,不是频率读数。
  - **交出去的棒**:`queue.json: hero-1` 已就地更新且 **status 仍 pending**,
    **口径被本轮改了 —— 接手的人别按原文写检测器**:只数 catch-all 会数成**上游同胞的补集**,
    低估缺陷、高估补丁;新口径 = 两条 nearest-taking 分支**分开数** + 每帧记 **Blast 可用性**
    (等级/冷却/蓝/`X.ShouldSaveMana`)+ 仍数 episode。总监:`wkqaim` 请从候选名单划掉
    (**从未 armed、从未入集**,不涉退集流程);**本轮零新 gated id**。
  - **顺带独立复核了 #115 §5**(下一轮的 Axe 杠杆):datafeed `hero_id=2` 确认
    Culling Blade 今天是 **275/375/475 纯伤害**、**且是纯伤害技能不是斩杀线机制**
    ⇒ 「拿血量比 `nKillDamage`」的**语义是对的、只是数错 25**。
    **但它和本轮同一个陷阱**:那是 **25 点宽**的带,上机前先量域。
- 2026-08-22T14:00:00Z:**本组今天第一个真行为改动落地,而且它不需要 gate 也不需要语料** ——
  `hero_axe.lua` 的 **t10 天赋** `{0,10}` → `{10,0}`(Culling 击杀 buff +3s → **每个生效的
  Battle Hunger +8% 移速**)。走的是章程给纯数值/构筑改动开的那条道:**不 gate,但把理由写进文件**。
  (c) 全部由**兑付条件**构成,不由口味:[1] 要先用 175 射程、70-80s cd 的处决技拿到人头,
  且只把一个战后 buff 从 6s 拉到 9s;[2] 只要场上有 Battle Hunger 在跳就付,而它是这个文件
  **买的第一点**、**10 级点满**(12s 持续 / 20-15-10-5s cd)、`X.ConsiderW` **四条**分支在放;
  而本组自己量过 **这个 Axe 在 turbo 里从来没有跳刀**(GH #56:4 局 0 次、另 4 局 0 帧)⇒ 全程走路,
  移速正是他缺的那个属性。**诚实边界**:放弃了 [1] 的团队 buff 3 秒(+20/25/30 移速、
  +10/15/20 护甲、900 半径);**没读任何语料**(数的是施放条件与本文件加点顺序,不是每局次数);
  **pick-rate 佐证抓不到**(dotabuff 403 / liquipedia 429 / fandom 402)⇒ 引用的全是 Valve datafeed。
  **⚠️ 未 gate = 已在稳定版里**(turbo 与普通模式都生效),**请总监记一笔稳定版漂移**。
  - **为什么是天赋**:#104 只对了 WK,另外四个焦点英雄的天赋行**从没查过**,而它们是
    `{0,10}/{10,0}` 这种「意义藏在 `aba_skill.lua:135` 算术里」的写法。**Axe 那行已经烂了两层**:
    ① npc 块是 7.2x 的(五个名字今天不存在);② t15 的注释写 `+35 attack speed over +2 mana regen`,
    而 `{0,10}` **取奇数索引**,在那同一张 7.2x 梯子上是 `special_bonus_mp_regen_2`
    ⇒ **这一行选的正是它自己的注释说它拒绝的那个**。注释**删掉**不更正(两个名字都没了),
    t15 **本轮不动**(今天那对没有明显赢家)。
  - **顺带更正 #104 的一条担忧的证据强度**:名字里带 `facet_` **不等于** facet 门控
    (feed 里这些加成挂在普通数值上、`required_facet` 空);Lion 的 `to_hell_and_back` 是 **innate**;
    Zeus 的 `cloud`/`lightning_hands` 是 **scepter/shard** 授予、不占初始槽 ⇒ Zeus 的
    `sAbilityList` 1/2/3/6 **没有漂移**。而 datafeed 对五个英雄 **`facets` 一律返回空数组**
    ⇒ **这个端点回答不了 facet 问题**,别再拿它当证据(机制本身仍可能成立,只是无证)。
  - **登记但没做**:`X.ConsiderR` 的 `nKillDamage = 150 + 100*lv`(**250/350/450**)对不上
    Culling Blade 今天的伤害(**275/375/475**)⇒ 低估自己 25 点纯伤害、在那 25 点带内拒绝
    本来能杀的一发。**是「加动作」⇒ 要真实帧 + 量过的域**,预注册域写进了代码注释。
  - 交付:`tests/test_focus_talent_anchor.lua`(**11 例**,档位算术与奇偶语义**读出式**、
    五英雄 t10/t15 **驱动真函数**解析、Axe 改动与其理由块的源码棘轮、7.2x 名字不得回到活代码、
    两个 talent handle 仍是 t25 且 **identifier 与 `sTalentList[N]` 下标两半都查**)。
    **7 次变异 7 抓**;并记下 **§1 的已知盲区**(变异 M3 发现的,不是想出来的):只翻 t10 行时
    `pick[5]` 仍随之移动 ⇒ §1 钉的是「哪个索引**对**归哪档」而非「哪个 pick **槽**收它」,
    抓住 M3 的是 §2 的逐英雄解析 —— 这就是 §2 为什么要驱动真函数而不是写期望值表。
  - **交给别人**:(i) 总监记稳定版漂移;(ii) 条件 (a) 核验请求 —— 录像组在**已有语料**里确认
    Axe 10 级拿到 `special_bonus_unique_axe_8`,**不需要新波次**;(iii) `wkqaim` 仍等
    `queue.json: hero-1`(pending,未动)。
  报告 `iterations/reports/hero/20260822T140000Z.md`;登记
  `state.json:focus_talent_reanchor_20260822T1400Z`;GH **#115**。
- 2026-08-22T08:00:00Z(**迟到落地**):**代码部分已被 10:00Z / 12:00Z 取代,本轮只落文档;
  留下的唯一新东西是:那族语料级绝对计数现在有「三个互不知情的推手」,而且它们会互相吸收。**
  本轮 08:xx 就把结论发到了 GH #104,但**没能在会话内 push** —— 卡在「push 前全量套件全绿」这道门:
  全量串行套件在本容器 **>1 小时**(实测 1140 例 / 约 68 分钟,rebase 后 1194 例),
  等门的时间里 10:00Z 与 12:00Z 已把同一件事重建并落 main。**本组不强推重复实现**
  (loader 排序、钉数文件、#104 §4 措辞更正、`wkqhold`→`wkqaim`、`queue.json: hero-1` 全都已在 main)。
  **唯一还没进 main 的一条**:本轮在父提交 `12ef3de`(**98 fixture**)上干净 A/B 得到
  `test_itemdesire_world_assertion` 的 `crash_2597` **179→177**,并把 −2 归给排序 ——
  **这个归因是错的,已在 GH #104 撤回**。同一个 −2 总监**独立二分**为协同组 05:30Z 的 fixture
  **治愈** `cf7bb4c`(GH #106/#107、main `1443e2a`)。在**合并树**(100 fixture + 治愈 + 排序)上
  重跑该文件:**24 例 0 失败,main 登记的 901/210/690/178/32 一个数没动** ⇒
  **排序的效应从 −2 变成 0**,治愈已把那两帧搬走。**两次测量都没错 —— 测的是不同语料。**
  ⇒ **规则(建议总监并进 GH #106)**:这族绝对计数有**三个互不知情的推手** ——
  ①加 fixture、②治愈 fixture(#106 的第二半)、③**台架语义改动**(如本次排序,**#106 里没有**);
  **它们互相吸收**(同一批帧谁先搬走,后者就测不到)⇒
  **引用语料级绝对计数必须同时记「语料快照 + 台架版本」**,否则跨轮不可比,
  而且会像本轮一样产生一个**看起来被数据支持的错误归因**。
  **另给总监一条流程**:本轮丢的不是结论是**落地**,成因是**门太贵**;实测更便宜且**更强**的替代 =
  **按文件切分 + 与父提交逐文件对比**(127 文件 × 两棵树,约 10 分钟,直接回答「我这次动了什么」)。
  两个注意点:①高并发下少数文件因资源竞争假红(串行重跑即过);
  ②`test_relicguard_siege_gate` / `test_wk_reincarnation_mana_gate` 单独跑必红
  (依赖前面文件装的全局),**在父提交上同样红**,不是回归。建议收进 harness 作默认 push 前门。
  详见 `iterations/reports/hero/20260822T080000Z.md`;登记
  `state.json:corpus_absolute_counts_three_movers_20260822T0800Z`;GH **#104** 已追评。
- 2026-08-22T12:00:00Z:**上一轮(10:00Z)也没落地 —— 它是为了补 08:00Z 而存在的,自己又丢了一次。
  本轮不再重做第三遍,直接把那棵树接上来;但**故意剔掉**其中一个别的组已认领的钉数文件。
  零行为改动、零新 gated id、零 EC2/S3。**
  Owner 优先项 P1/P2 责任链仍都指向协同组,本组无未完成优先项。
  **会话中途远端动了**:开工查 `git ls-remote origin main` = `1443e2a`,建 worktree 时已经是
  **`37c0a0e`**(总监 11:00Z 收 `stayfield` + 11:5xZ 补收 `pullcamp`)⇒ 本轮读数与 rebase 全部
  按 `37c0a0e` 重做。**顺带一个坑**:本容器的 `origin/main` 远端跟踪引用是**陈旧的**
  (指向 `46d381d`,100 个提交以前),`git worktree add --detach origin/main` 会**静默**给你一棵
  39 fixture 的旧树 —— 差点据此写下一份完全错的 A/B。**做隔离测量前先 `git fetch origin main`,
  并核对 worktree 的 fixture 数。**
  **本轮不是发现,是回收。** 连续两轮英雄组产出不在 main 上:08:00Z 与 10:00Z 各推了一个分支、
  两个都没落 main;10:00Z 那一轮本身就是为了重做 08:00Z 的。
  **⚠️ 更正(总监 13:00Z / GH #113 追评 / `27019a4`):本条原先写「08:00Z 一行都没推」,那是错的。**
  它推了 `eda1257` 到 `claude/vibrant-heisenberg-3os6d0`(提交时刻 08:39:10Z),文件集与 `e940d31`
  **逐个相同(8 个)**⇒ 今天是**两种**丢法不是三种,而且「现有检测器结构上看不见第一种」
  **不成立**(总监跑了 `unlanded_commits.py`,它把 `eda1257` 连分支带 cherry-pick 命令打了出来)。
  **仍成立的一半**:08:25:52Z 那条评论**早于** 08:39:10Z 的提交 ⇒ 发评论那一刻引用确实解析不了,
  #113 提的判据没错,总监照它建了 `tools/agent/citation_audit.py`,第一次真跑就命中本组这两轮。
  **结论翻转:缺的不是检测器,是没人跑检测器**,代价两个整轮 ⇒ 铁律 10 +
  `tools/agent/routine_selfcheck.sh`(每次触发开工第一件事,~20s、只读)。
  **本组自己该记的那条比更正本身值钱**:**证据当时就在手里** —— 本轮早段为找 10:00Z 的树跑的
  `git log --all | grep hero`,**第三行就是 `eda1257`**;本组读了那份输出、取走了 `e940d31`,
  却把 10:00Z 报告里「08:00Z 什么都没推」**照抄**下来没去对。
  ⇒ **一个上游轮次的「归因」和它的「数字」一样要复核。** 本轮复核了 `e940d31` 的数字
  (还改了 2277→2280),偏偏对它的**故事**免检 —— 而故事恰恰是那轮唯一没有测量支撑的部分。
  (今天协同组 07:30Z 也丢过一次,已由它自己和总监补齐。)
  **落地的**(`e940d31` 原样):`tests/mock/replay_fixture.lua` 的 `GetNearbyHeroes` 按距离升序
  (unit name 破平)+ `tests/test_mock_nearby_heroes_order.lua`(10 例)+
  `test_wk_considerq_level7_dominance.lua` 的三处措辞更正与新增顺序例(14 例)+ 10:00Z 的报告 /
  章程条目 / `state.json` 键 / `queue.json: hero-1`(与协同组的 `strategy-1` 保留双方)。
  **故意没落地的**:`e940d31` 对 `tests/test_itemdesire_world_assertion.lua` 的重钉
  (209→207 / 179→177 / 672→674)。三条理由都**晚于** 10:00Z:①协同组已把该文件认领为
  `[harness] GH #112`(其 backlog `0R`)并**白纸黑字要求**在 `crash_2597` 的逐 fixture 分解出来
  之前**任何人不要重钉**;②那三个值**本身已过期** —— #112 自己的评论记着同一个数在
  96 / 98 / 100 fixture 上读 **179 / 177 / 178**,而今天是 100;
  ③**决定性的一条,是量出来不是想出来的:那个文件已经不红了 —— 它的主人自己修好了**
  (协同组 11:13Z/11:21Z `280b716`+`1443e2a`,重钉到 100 语料;本轮在 `37c0a0e` 纯净 worktree
  实测 **24/0**)。今天的钉数是 `driven 901 / crash_total 210 / no_action 690 / crash_2597 178`,
  而 `e940d31` 的是 **882 / 207 / 674 / 177** ⇒ **整棵接上来会让四条断言当场变红,
  把主人八分钟前刚修好的文件重新弄坏。**
  ⇒ **「回收一棵丢掉的树」不是 cherry-pick 一下就完事:丢的那段时间里世界会继续动,
  它里面的每一个等式钉数都要在今天的树上重跑,不能信提交信息自己写的那句「1150 tests, 0 failures」。**
  **本轮自己量的四件事(不是抄 10:00Z 的)**:
  ① **两个恢复的测试文件在今天的 100-fixture 语料上仍绿**(10/0、14/0)—— 它们写在 98 上却没坏,
  **正因为计数写成了上界而不是等式**(GH #106 要的那条纪律,第一次在同一周内收到回报);
  **写成一串等式的那个文件,恰恰就是红的那个。**
  ② **调用点重测 = 2280**(1929 个 `J.GetNearbyHeroes` 包装引用 + 346 个直接 `:GetNearbyHeroes(`
  + 5 个定义/注释行),不是 `e940d31` 记的 2277;差额是别的组的提交,不是错 —— **记的是重测**。
  ③ **`J.GetNearbyHeroes`(`jmz_func.lua:2517`)确实只过滤不重排**(重读确认,`table.insert` 到
  新表、全程无 sort)。**但有一条没人记过的新脚注**:它用 **`pairs` 而不是 `ipairs`** 遍历引擎列表
  —— 在 PUC-Rio Lua 5.1 上序列的数组部分按序遍历,所以顺序**事实上**保住了,**但语言不保证**。
  ⇒ 所有关于「J.GetNearbyHeroes 返回值的顺序」的论断,靠的是 VM 的实现细节而非契约。
  改成 `ipairs` 很便宜,但那是 `bots/` 改动,要它自己的工作单元。
  ④ **给 GH #112 的隔离读数(本轮的真交付)**:本组把一个台架改动落进了协同组即将拿来测量的那棵树,
  所以**先把它自己排除掉** —— 同一个提交 `37c0a0e`、同一份 100-fixture 语料,两个 detached worktree
  只差那一个排序,各跑 `run_tests.lua itemdesire`。**两侧都是 `24 tests, 0 failures`、
  输出逐字节相同** ⇒ 这个排序对该普查的每一个读数影响 **= 0**(四个等式两侧全过)。
  **协同组做逐 fixture 分解时不必把本轮这个台架改动列进混杂因子** —— 它在落地**之前**就被排除了。
  (诚实边界:只证明它不动**这个文件的这些读数**,不证明它不动任何东西 —— 它当然动瞄准类读数,
  那正是它存在的理由。)
  这比 10:00Z 那次的控制更硬(那次跨的是 98 语料的**不同树**,混进了 `bots/` 差异)。
  **门**:`luacheck bots game --formatter plain` **0 警告**;全套见报告"验证"节
  (`test_itemdesire_world_assertion` 的红是 **main 自带的**,见 #112,不归本轮)。
  **交出去的三棒(接力棒不许掉,铁律 9 连带规则)**:①新开 **`[harness] #113`** —— 丢树这个失败模式本身
  与建议判据(**它的头号案例被总监当轮更正,见上;判据本身被采纳并实现**,issue 已由总监关闭)。
  **注意 10:00Z 那一轮自称开了这条 issue,而它也不存在** —— 因为「开 issue」这个动作写在了
  没被推上来的那棵树的报告里,**掉棒掉了两层**;
  ②**GH #112** 追评(隔离读数 + 确认协同组的修复在纯净树上是绿的);③**GH #104** 追评
  (状态更正:§4 的措辞更正现在真的落在文件里了)。
  详见 `iterations/reports/hero/20260822T120000Z.md`;登记
  `state.json:hero_round_recovery_20260822T1200Z`(并给 10:00Z 那个键补了两条 WITHDRAWN/DISCHARGED)。
  **下一轮**:`wkqaim` 仍等 `queue.json: hero-1` 的域读数,读数回来之前**一行都不写**。
  **本轮掉出来、登记但没做的一条 `bots/` 小活**:`J.GetNearbyHeroes` 改用 `ipairs`(见上面 ③)——
  它把一个「靠 VM 实现细节成立」的顺序论断变成「靠语言契约成立」。零行为改动**在 5.1 上**,
  但它是 `bots/` 改动,要自己的工作单元;谁做谁记得:全仓 **1929** 处引用都吃它。
- 2026-08-22T10:00:00Z:**上一轮(08:00Z)把结论发到 GitHub 却从没 push —— 交付物在仓库里
  一件都不存在。本轮核实、重做、并独立复算了每一个数字。零行为改动、零新 gated id、零 EC2/S3。**
  Owner 优先项 P1/P2 责任链当前都指向协同组,本组无未完成优先项;远端 `1af3116`,同步后开工。
  `[hero]` open issue 里 #97/#85/#73/#59 是本组自己的 DO-NOT-ARM / park 记录、#63 00:30Z 做完、
  #56 卡在 `[harness] #60`、#54 的 (a) 买不到、#66 要语料 ⇒ 取 backlog §18 / GH #104,
  **而 #104 最新一条评论(08:25:52Z)自称已经做完了下一轮该做的事**。
  **头条一:截至 09:37:48Z,那一轮的树不在任何远端分支上**(措辞已于 13:20Z 自我更正 ——
  原文写的是「从来没被推上来」,那是一句关于未来的话;那个容器 **13:1x 补推了**
  `eda1257` → `claude/vibrant-heisenberg-3os6d0`。总监 13:00Z 按 commit 时刻 08:39:10Z 判本条
  不成立,**那条更正也用错了时刻**:commit 时间 ≠ push 时间,今天差 4.5 小时;
  决定性证据是 remote-tracking reflog —— 09:37:48Z 的**全 refspec 无 prune** fetch 给当时每个分支
  都建了跟踪 ref,而那个分支**只有 13:19:18Z 一条**。已发 GH #113 追评。
  **纪律**:这类结论按 **push 可见性**写、带时刻,不按 commit 时间判。) 拉全部 **229 个远端分支**逐个
  `git ls-tree` 搜 `tests/test_mock_nearby_heroes_order.lua` 与
  `iterations/reports/hero/20260822T080000Z.md`:**零命中**;`queue.json` 的 `requests` 是空数组
  (评论说提了 `hero-1`)。⇒ 约 1.5 小时里,**已发表记录声称台架已修而台架没修**。
  这**不是**总监 03:00Z 那个「pushed 但没落地」检测器管的那一类,已开 `[harness]` issue。
  **头条二:它描述的台架缺陷是真的,本轮修了。** `docs/BOT_API_REFERENCE.md:1229` 规定整个
  `GetNearby*` 家族**按距离最近优先**;`tests/mock/replay_fixture.lua` 对**建筑**遵守了,对**英雄**
  没有 —— 它原样返回 `fx.units`,而 `make_fixture.py` 用 `for h in sorted(per)` 按**英雄名字母序**写。
  ⇒ 每个 fixture 驱动的测试里 `list[1]` 是**字母序第一**不是**最近**;`bots/` 有 **2277** 个
  `GetNearbyHeroes` 调用点,`J.GetNearbyHeroes`(`jmz_func.lua:2517`)**只过滤不重排** ⇒
  loader 是唯一能弄错、也唯一能修好的地方。**已按距离升序排 + unit name 破平**(排序是**声明的**,
  `.dem` 不记录列表顺序)。
  **独立复算的普查与它发表的逐位相同**:98 fixture / **911** 个活着的主体 /
  **502** 个 (主体,半径) 组合有 >=2 敌 / **200(39.8%)**「字母序第一 ≠ 最近」
  (r=568: 50/12;r=1200: 197/80;r=1600: 255/108)⇒ **读数是对的,只有代码没落地**。
  **交付** `tests/test_mock_nearby_heroes_order.lua`(**10 例**,源码棘轮 + 普查 +
  **5466 条列表**全库距离非降 + 平局确定性 + 真实帧顺序敏感性),
  **7 次变异 6 抓**,M7(去掉破平)是**声明的等价变异**(两元素平局上 `table.sort` 保持输入顺序,
  而输入顺序本来就是字母序)。**两条要记住的读数**:① **M1(删掉排序,也就是缺陷本身)没有被真实帧
  那一例抓住** —— 那帧上「最近」恰好就是「字母序第一」,而**全库 60% 的组合都是这样** ⇒
  列表顺序错了在多数帧上完全隐形;② **loader 的任何变异都没有被其余 81 个 fixture 驱动的测试抓到过**
  (gate 测试问「放不放」,顺序只改「打谁」)。
  **真实帧**:`f_225947_wk_trade_kite`(t=367.0,WK **7 级**、Q 1 级、lich **197u/36% 血**、
  nevermore **394u/76% 血**,都在 568 内;唯一 mutation = Q cd 13.4→0 + 525 射程锚)——
  出货 `ConsiderQ` 瞄 lich,**把列表反过来同一发、同一个 desire(0.75)瞄向 nevermore**;
  ground truth 是 lich 随后打了 750、WK 4.6 秒后死。
  **已发表结论就地更正**:GH #104 §4 与 `test_wk_considerq_level7_dominance.lua` 把兜底描述成
  「取引擎列出的第一个」并按「顺序任意」论证 —— **引擎不是任意的,是最近优先**。
  §4 的**结论不受影响**(它的帧把满血 sven 放 300u、濒死 lion 放 400u,两种读法下 sven 都是表头),
  但**理由错了**:三处措辞更正 + 头部 CORRECTION + **新增一例**把「这一帧按最近优先排」钉成断言
  (14 例全绿)。
  **头条三(追那三个钉数追出来的):`origin/main` 从 `cf7bb4c`(06:19Z)起就是红的,
  而且不是本轮弄红的。** `test_itemdesire_world_assertion.lua` 的三个等式钉数
  crash_total **209→207**、crash_2597 **179→177**、no_action **672→674** 全部失效。
  **最顺的那个故事(也是 08:00Z 那条评论写的)「顺序修复让 2 帧不再走到崩溃点」是假的** ——
  三次 882 帧全量 sweep:本轮的树 / **同一棵树删掉排序** / **纯净 `origin/main`(我一行没改)**,
  **崩溃集合逐条相同**(177+30=207)⇒ ① 顺序修复对全套其它读数影响 **= 0**;
  ② **纯净 main 单独跑就是 `24 tests, 2 failures`**。**凶手已二分点名**:`cf7bb4c` 重生成的
  **那一个** fixture `f_260819_182855_lion_drain_jungle`(GH #107,同一个 `--t` 落到早 ~0.33s 的
  采样上)—— 单独 revert 它回 heal 前的字节,计数**精确回到 209/179**,多出来的两条崩溃是
  **earthshaker 与 phantom_assassin**。`cf7bb4c` 之后**至少 4 轮推了 main**
  (director 07:0x / batch-desk 08:11 / replay-check 08:50 / director 09:06),
  **红了约 4 小时没有任何一道全绿门拦住**(全量套件单次 ~55 分钟是现实原因)。
  本轮**重量 + 重钉 + 把归因写进文件头**,并给这一族留下判读纪律:
  **这三个等式再动的时候,先二分再归因。**
  **头条四:协同组 07:30Z 的 owner P1 工作也没进 main** —— 954 行、含
  `bots/FunLib/jmz_func.lua` 行为改动、标题 `Owner P1(1) -- the camp-pull trigger demanded the
  state its own action produces`(= P1 DoD 第 1 条,owner 为它「40 轮无进展」失望过),
  只在分支 `claude/dreamy-feynman-bgub7w` 上。**本组没越权合并**(别的流的树 + `bots/` 改动),
  已交总监。**零成本巡检口径**:报告目录的逐流节奏表(每流每 2 小时一份)——
  今天 5 流 25 轮里 **2 轮的产出不在 main 上**(hero 08:00 / strategy 07:30)。**已提 `queue.json: hero-1`**(不要新波次,扫归档语料量 `wkqaim` 的域)。
  **可复用先验(请总监收进 §Y.2 旁)**:**对「出货分支挑了哪个单位」下任何结论之前,先确认台架
  给那个列表的顺序和引擎一致。** 台架的顺序缺陷对所有 gate 测试都不可见,产出的是**自信而错误**
  的瞄准结论 —— 本次它已经进了一个已发表的 issue。与 §17「动作路不路过我的门」、
  §18「路过了会不会从我下面再走一遍」同族;本条问**「我读到的那个『第一个』,是不是引擎的那个」**。
  详见 `iterations/reports/hero/20260822T100000Z.md`;登记
  `state.json:mock_nearby_hero_order_20260822T1000Z`;GH **#104** 追评 + 新开 `[harness]` issue。
  **下一轮**:`wkqaim` 等 `hero-1` 的域读数;在那之前不写(改瞄类代价侧结构性为零,但域可能是空的,
  `axeblink` 陷阱)。
- 2026-08-22T06:00:00Z:**GH #104 §5 把 Lever A 的域记成「语料问题」,本轮发现其中一半是
  桌面问题:`X.ConsiderQ` 自己的 7 级兜底分支把它压掉了。零行为改动、零新 gated id、零 EC2/S3。**
  会话开头查远端(`git ls-remote origin main` = `ad10ef6`,与本地 HEAD 同)。`[hero]` open issue
  里 #97/#85/#59/#73 是本组自己的 DO-NOT-ARM / park 记录、#63 00:30Z 做完、#56 卡在
  `[harness] #60`、#54 的 (a) 买不到、#66 要语料 ⇒ 取 backlog §18 / GH #104 §5(它自己写着
  「下一轮从这里起,优先 Lever A」)。§5 注明 Lever A **缺的只是域的形状,要语料**;本轮不花 AWS,
  于是先问一个更便宜的问题:**「要语料」这句话对吗**。
  **头条**:`X.ConsiderQ` 的最后一条返回点是 `nLV >= 7` 的**无条件兜底**
  (`#nEnemysHerosInView > 0 or 最近挨过打` + 非撤退 + `nCastRange + 43` 内有敌方英雄 ⇒ HIGH),
  ⇒ **7 级起,任何走进 568 码的敌方英雄都会在 Q 一好就吃到停晕**,不看血、不看击杀判据。
  实测:**7 级 568 内,目标血量 1→满血全扫,没有一个值让 `ConsiderQ` 闭嘴**;
  **5 级同一条扫描有真有假**(所以上面不是空断言)。
  **代价侧比这更要命**:收窄击杀判据在 7 级以上**不是「不放」是「改瞄」** —— 两敌帧实测,
  判据带内时瞄 400 码外 **25% 血**的 lion,判据一诚实就改瞄 300 码 **满血**的 sven
  (兜底取的是**引擎列表第一个**),冷却与蓝照花。
  ⇒ **Lever A 残余域 = {英雄等级 1-6} ∪ {568 < d ≤ 605 的 37 码壳}**,7 级以上壳外只改瞄。
  **从出货代码里扫出来的读数**(不是断言算术):自称击杀血量 **126/176/226/277**
  (= `nDamage*1.68*0.75`)vs 落地 60/75/90/105 vs 落地+整段 dot 90/135/180/225
  ⇒ **四个等级上自称值同时超过两个诚实上限**;等级悬崖 **7**;两个射程 **568 = cast+43**(兜底)
  / **605 = cast+80**(击杀分支)。
  **真实帧同一个悬崖**:`f_232320_wk_od_burst`(t=380.0,WK 6 级 272/272 蓝、Q 1 级 cd 0、
  OD 377 码 86% 血、ground truth 8 秒内挨 915、5.8 秒后死)—— 出货码**沉默**;
  **只把英雄等级这一个整数改成 7**(唯一声明的 mutation),同一帧立刻 HIGH。
  **交付**:`tests/test_wk_considerq_level7_dominance.lua`(**13 例**,二分 + 边界两侧确认;
  **9 次变异 8 抓**,M6 是**有意的等价变异** —— 兜底里的 `#nEnemysHerosInRange >= 1` 与它保护的
  `for ... in pairs` 冗余,删掉端到端相同)。`bots/`+`game/` diff 为空。
  **给总监**:①请把 Lever A 的域判词从「待语料」改成 **`DOWNSTREAM-DOMINATED`(第七类处置)**;
  ②**可复用先验**:**收窄一条开火分支前先读完这个 Consider 函数的剩下部分 —— 末尾若有一条
  看等级/看射程的兜底,上游任何收窄在兜底打开后只改瞄不改放**(与 §17「动作路不路过我的门」同族,
  再进一步:**路过了也可能从我下面再走一遍**;桌面可查,属 §Y.2 的 EMPTY 一侧);
  ③**下一轮 lever 换成兜底分支本身(建议 `wkqhold`)** —— WK 唯一硬控被当消耗技刷掉,与 Zeus
  `zusult`、Lion Finger 同家族第三例,但**是「新增否决」= `lanefix` 的失败形状**,代价侧先想清楚;
  ④给 harness(附 GH #27 家族,不新开 issue):全量测试套件单次 **约 55 分钟 / 1101 例**,本文件第一版
  线性扫描(~4000 次 26ms 的 `dofile`)单文件就 >300s,改二分后 **5.4s** —— 域读出工具应默认二分。
  **门**:`luacheck bots game` 0 警告;`lua5.1 tests/run_tests.lua` **1101 例 0 失败**(提交时的树),
  rebase 到 `99d73c3`(只带进 docs + 别组的新测试,`bots/`/`game/` 零改动)后重跑 **1125 例 0 失败**。
  详见 backlog §18 与 `iterations/reports/hero/20260822T060000Z.md`;
  登记 `state.json:wk_considerq_downstream_dominance_20260822T0600Z`;GH **#104** 追评
  (issuecomment-5378928560)。
- 2026-08-22T04:00:00Z:**给 `wkbuild` 写回一个条件 (c) —— 而且是可驱动的那种;
  顺带更正上一轮自己读错的一个 datafeed heading。零行为改动、零新 gated id、零 EC2/S3。**
  会话开头查远端(`git ls-remote origin main` = `8c90769`,与本地 HEAD 同)。`[hero]` open issue
  里 #97/#85/#59/#73 是本组自己的 DO-NOT-ARM / park 记录、#63 00:30Z 做完、#56 卡在
  `[harness] #60`、#54 的 (a) 买不到、#66 要语料 ⇒ 取 **GH #104 §5 / backlog §18**
  (它自己写着「下一轮从这里起」)。§5 说优先 **Lever A**,但 **Lever A 要语料**、本轮不花 AWS,
  于是取 §18 里另一件明确挂着且**纯桌面**的事:#104 交给总监的第 ① 条 ——
  **`wkbuild` 的 (c) 需重议**。**一个没有 (c) 的 gate 不该进任何波次**,这是验证哲学的字面要求。
  **头条(新的 (c))**:Bone Guard 的**冷却与等级无关(恒 42s)**,一点技能点买的是
  **max_skeleton_charges 2→4→6→8**(+骷髅伤害 34→49);而 `X.ConsiderW` 的两条开火分支
  **都是对上限的阈值**,唯一旁路 `talent6:IsTrained()` 是 20 级测试 ⇒ turbo 里
  **每加一点 Bone Guard,他自己肯放骷髅的门槛都单调上升**(分支 1 要 2/3/4/5 层、
  分支 2 要 2/4/6/8 层)。默认表 **7 级点满** ⇒ 一个 **15 补 / 0.6 杀**的 WK 从 7 级起
  必须攒 **8 层**才肯在兵线前沿放;`wkbuild` 让他整个对线期停在**上限 2**(2 层就放),
  并把省下的点给**唯一的硬控**(第二点眩晕 12 级 → **5 级**,眩晕 1.0→1.2s、cd **14→12s**)
  和更早满级的 Mortal Strike(10 → **8 级**)。**这不是说理,是可驱动的**。
  **第二条(自我更正)**:上一轮的重锚把 `blast_dot_damage` 的 `[20,40,60,80]` 读成了 dot
  **总量**,而它的 `heading_loc` 是 **DAMAGE PER SECOND**、`blast_dot_duration = 2`
  ⇒ dot 总量 **40/80/120/160**、满值一发 **120/180/240/300**。于是 `nDamage`
  (100/140/180/220)**既不是落地也不是满值**;`*1.68` = 370 **同时**超过落地(2.64x)
  **和**满值上限(1.23x)。**Lever A 的诚实对照数是两个不是一个。**
  这一条已在 `state.json` 与 GH #104 追评里更正(它已发表 24 小时)。
  **交付**:`hero_skeleton_king.lua` **注释-only**(索引表的 dot/骷髅数值、`ConsiderQ` 的
  `nDamage` 第二次重锚、`tKillBuildList` 上方新增 "CONDITION (c), RE-ARGUED" 整段);
  `tests/test_wk_bone_guard_thresholds.lua` **10 例** —— 先证两个帧都诚实,再**把层数钉死、
  只动技能等级**分支扫描,最后**把阈值从代码里扫出来**(0..12 层逐级找最小开火层数)
  而不是断言我的算术,并断言**单调不减**;**9 次变异 8 抓**,**M9 是有意的等价变异**
  (`>=0.6`→`>0.6` 在整数层数上端到端相同 —— 「没抓住」和「没有可抓的东西」要分开写)。
  **给总监**:①**请替换 `wkbuild` 的 (c) 判词**(本组无权自改);②入集提示:`wkbuild` 是
  **加点顺序**改动,armed 与 shipped 全程不同 ⇒ **没有 axeblink 陷阱风险**,载体条件只有
  「该波抽到 WK」(GH #49 的全有或全无阵容要先确认);③方法:重锚数值时**连 heading 一起抄**;
  ④**无新 gated id、未提 queue.json、零 AWS**。
  **下一轮的阻塞点已定位**:把 (c) 从**符号**升级到**大小**需要「两次释放之间攒几层」,
  而 **dumper 不 dump `GetModifierStackCount`**(与 GH #27 / backlog §3 同一字段族,
  一次改两条都解锁)—— 建议开 harness issue。
  详见 backlog §18 与 `iterations/reports/hero/20260822T040000Z.md`;
  登记 `state.json:wkbuild_condition_c_reargued_20260822T0400Z`;GH **#104** 追评。
- 2026-08-22T02:00:00Z:**WK 事实重锚(GH #104)—— 动他之前先核事实,结果三处事实是陈旧的,
  其中一处已经被本组自己当成一个门的条件 (c) 依据写进代码注释了。零行为改动、零新 gated id、
  零 EC2/S3。**
  会话开头查远端(`git ls-remote origin main` = `450c490`,与本地 HEAD 同)。`[hero]` open issue
  里 **#97/#85/#59 是本组自己的 DO-NOT-ARM 记录**、**#63 00:30Z 刚做完**、**#56 卡在 `[harness] #60`**、
  **#54 的 (a) 买不到**(`odaoe` 已入 eligible 但 §U.0 的 18-id 下一波串逐字不变 ⇒ 本波不 armed)、
  **#73 剩下的 Lion 杠杆是「改策略本身」的大改动** ⇒ 没有可认领且买得起的 issue,
  按章程转**焦点五里读数最差的那个**:GH #17 的 WK(15 补 / 661 gpm / **0.6 杀** / 3.2 死)。
  **头条**:①索引 2 是 `skeleton_king_bone_guard`(**主动**、无目标、恒 42s cd、2/4/6/8 层),
  注释写的「吸血光环 / lane sustain」是 7.2x 的名字 —— 吸血 `skeleton_king_vampiric_spirit`
  被 datafeed 标 **innate**,**一个技能点都不要**;②`abilityW` 的种子名
  `skeleton_king_spectral_blade` **不在他的技能集里**(全仓库只出现在那一行),整条 W 路径一直
  靠 `X.SkillsComplement` 的兜底重取 —— **没崩也没有行为差异**,而正因为兜底在,改成真名是
  **可证的空操作**;③npc/天赋块整块是 7.2x 的。锚 = datafeed `herodata?hero_id=42`。
  **直接后果**:`wkbuild` 登记的 (c) 依据(「keeps Vampiric Aura (W) points for lane sustain」)
  **在事实上是错的** —— 两行 build 各花 4 点在 Bone Guard 上,`wkbuild` 只是把后三点
  **3/5/7 推到 9/10/12**,它换的是**前期 Bone Guard uptime**,不是续航。(c) 要重新论证。
  **第二条**:`X.ConsiderW` 的两条释放分支把 `talent6:IsTrained()` 当析取旁路,而
  `aba_skill.lua:135` 自己的算术把 t20 驱动到索引 {5,6} ⇒ 它是个 **20 级测试** ⇒ 配 GH #84 的
  `level>=20` **0/210** ⇒ turbo 里分支 2 严格 = 满层。**这是 §4.2 的下一层**(§4.2 讲的是
  一张**表**里的死重量,这里是 t20 handle 被读进**出货中的决策函数**)。
  **交付**:`hero_skeleton_king.lua` 重锚注释 + 删五个死局部(`bDebugMode`/`abilityE`/`talent5`/
  `castEDesire`/`nKeepMana`,最后一个**已赋值、全仓零读**,与 GH #73 从 Lion 清掉的同型);
  `tests/test_wk_fact_anchor.lua` **13 例**、**13 次变异 13 抓**(门:luacheck 0 警告 / **1065 tests, 0 failures**);全 BotLib 的 t20/t25 消费点普查
  **24 处 / 7 英雄**(机械判据 + 棘轮)。三根 lever(Q 击杀判据的 2 秒总伤 ×1.68 / t20 析取 /
  肉山分支的绝对 600 蓝)**只登记不上机**,预注册域写在 GH #104 §5 与代码注释里。
  **给总监**:①`wkbuild` 的 (c) 需重议(不是本组能自己改的判词);②普查里四个非焦点英雄
  (chaos_knight / lich / warlock / legion_commander)转协同组;③**facet 门控天赋会整体移位
  索引**这条建议单开 issue(影响全英雄池的 `tTalentTreeList`,离线不可证伪);④**无新 gated id、
  未提 queue.json**。
  **方法上的一条**:第一稿的档位测试断言的是**我自己的排序假设**,一个把 `[3]` 重指到别的档位键
  的变异从它旁边走过去了;改成「每次只翻一档,看返回的哪几个索引变了」才抓住 ——
  **「断言一个映射」和「把映射从代码里读出来」是两件事。**
  详见 backlog §18 与 `iterations/reports/hero/20260822T020000Z.md`;
  登记 `state.json:wk_fact_reanchor_20260822T0200Z`;GH **#104**。
- 2026-08-22T00:30:00Z:**GH #63 认领并做完 —— 它的头条数字全部要改,推荐值 250 也要改成 200;
  新 gate `cmrcap` 上机(gated,未 armed),等总监入集。**
  会话开头查远端(`git ls-remote origin main` = `b7a040f`);`[hero]` open issue 里 #97/#85/#59
  是本组自己的否决记录、#54 的 (a) 仍无语料、#56 卡在 `[harness] #60` ⇒ 取 backlog **#12**
  的阻塞项(重锚后重跑 `cmrguard_precision.py`),那条阻塞是本组 12:15Z 自己造成的。
  **零 EC2、零 S3 PUT**(18 个 `.dem` ≈158MB GET;dumper 缓存命中)。
  **本轮方法上的关键一步是先做复现控制**:在 legacy 锚表上把 #63 的每一个数字逐位复现
  (115 episode / 4.85x / 56/115 / 304.0s / §2 整表),再换表 —— 于是每一处差异都只能归给锚表,
  而不是归给「我的语料挑得不一样」。
  **三条结论**:①**现状比 #63 记录的便宜 30%**(213.0s vs 304.0s,最长封锁 10.5s vs 21.5s);
  ②**`cap=250` 过不了 #63 自己的验收,`cap=200` 三条全过**,而且**验收 ② 的分母也被重锚改了**
  (相对阈值在分母重测后必须重算);③**#63 §6.3 的刹车不单调**,换成 `covered_landings()`
  (固定 ground-truth 落地集)后 94%→86%(cap 200)→73%(cap 0)。
  **交付**:`bots/BotLib/hero_crystal_maiden.lua` 新增 gated `cmrcap`
  (`X.nRGuardRangeCap = 200`,**收窄已 armed id** 的第一个形状,**armed 单独 ≡ shipped ⇒ 必须与
  `cmrguard` 同臂**,已写成测试);两个真实帧 fixture(`f_260820_043039_cm_cask_close`
  必拦 / `f_260820_042009_cm_cask_far` 必放,同一个技能、同一就绪状态,只差距离 ⇒ 钉住 **[146,483)**);
  `tests/test_replay_260820_cm_cask_cap.lua` **15 例**、**7 次变异 7 抓**;
  工具侧 `--cap` / `--legacy-anchors` / `--sweep` / `--verify`(**41 例**)+ 逐技能表 + 封锁总量 +
  采样间隔行 + `covered_landings()`,`LEGACY_CAST_RANGE` 只为复现已发表数字而存在。
  **顺带**:加两个 fixture 让 **5 个语料棘轮 15 例**变红,逐个处理(96→98 局、892→**911** 活人帧
  —— 只 +19 因为 close 帧上有一具尸体;角色债**没有增长**,两个 fixture 改成带 `--roles` 重生成)。
  其中 `test_gamemode_world_assertion` **不是纯分母**:按它自己上一轮留的纪律
  (「不要移分母然后祈祷,把 auction 在新帧上重跑」)重跑,**far 帧真的翻了**
  (as-loaded `laning 0.369` → honest `defend_tower_bot 0.300`)⇒ 录着的分子也动
  (moved winners 18/96 → **19/98**,换 MODE 的 10 → **11**)。**那条纪律这一轮救了一次真错。**
  **门**:`luacheck bots game` 0 警告 / `lua5.1 tests/run_tests.lua` **1039 tests, 0 failures**
  (基线 1024 + 新增 15)/ `run_py_tests.sh` 6 passed / 工具 `--verify` 41 例。
  详见 backlog §12 与 `iterations/reports/hero/20260822T003000Z.md`;
  登记 `state.json:cmrcap_20260822`;GH #63 已评论。
- 2026-08-21T22:00:00Z:**`liondrain` 上机前语料核验 —— DO NOT ARM,第六类处置
  `SIBLING-DOMINATED`(它被一个已入集的同族 id 包住了)。**
  会话开头按规矩查了远端(`git ls-remote origin main` = `f81fc44`),`[hero]` open issue
  里 #85/#73/#66/#63/#59/#56/#54 都不是本轮的活;上一轮指定的 ①`odaoe` (a) 核验**仍不满足**
  (§AB.1 明写「§U.0 的 18 id 下一波串逐字不变」⇒ 本波未 armed,没有 (a) 可收)⇒ 按次序取 `liondrain`。
  **零 EC2、零 S3 PUT、零行为改动、零新 gated id**(S3 GET 54 个 `.dem` ≈510MB + dumper 缓存命中)。
  **头条**:域**是五个被否决候选里最大的一个** —— 4 起手 / **4 episode** / 12 局 Lion 局里的 4 局
  = **0.33 ep/Lion 局**(cmrself/esaftershock/zusultx 各 0.06,已获批的 odaoe 0.77)⇒
  **这一轮第一次不是「域太小」死的**。死因换了:**`liondrainstop` 跑一字不差的同一个谓词,
  而且跑在 `X.SkillsComplement` 的第一行**(`hero_lion.lua:199`,在 `J.CanNotUseAbility` 早退之上)
  ⇒ 读条期间每 tick 都跑 ⇒ 「开读条即为真」的帧它下一个 tick 就切。实测覆盖 **3/4**,
  第 4 个频道 **0.0s**(空操作)⇒ **`liondrain` 独占域 = 空**;而 `liondrainstop` 另有 **3 个**
  `liondrain` 够不着的频道 ⇒ **包含关系,不是并列**。详见 backlog §7 第一条与
  `iterations/reports/hero/20260821T220000Z.md`。
  **交付**:新工具 `lion_drain_start_domain.py`(第八个域模板,`--verify` **39 例**、
  **7 次变异 7 抓**,内建「ABILITY 事件 vs MODIFIER 事件」宇宙交叉核对,实测 73=73 / 27=27);
  `source_constants.assignment()`(读**文件级**常量的 fail-loud 抽取器,`function_body` 够不着
  `X.nEDrainDangerRadius = 500` 这种写法);`test_detector_source_constants.py` +4 REGISTRY 行
  +3 条「两个杠杆同谓词」断言 +2 条 fail-loud 用例。`bots/` **一个字节没动**。
  **给总监**(全部写在 **GH #97** 里):①建议加第六条处置类别 `SIBLING-DOMINATED`;②**排期约束请升级** ——
  登记的「`liondrain` 与 `liondrainstop` 永不同臂」不够,即使分两臂,两臂在 3 个共享频道上
  对比度≈0,建议改成「`liondrain` 在 `liondrainstop` 拿到 (a) 读数之前不进任何波次」;
  ③请把「测试集里有没有 id 跑同一个谓词、只是接在决策链另一端?」收进 §Y.2 旁(第三个方向);
  ④**无新 gated id**;⑤**未提 queue.json**;⑥tripwire:27 个敌方英雄起手里 **2 个**与分支前置
  条件矛盾(Hex/Finger 都 cd 0 且蓝够,`ConsiderE` 本该在门之上就 return 0),**两个都在域外**、
  4 个域内起手的 `others_castable_cd0` 全为 0 ⇒ 头条不受影响;成因二选一(dumper 的 `cd` 不等价于
  `IsFullyCastable`,或存在 `X.ConsiderE` 之外的 Mana Drain 产出点),未追;
  ⑦**顺带报了 `[harness]` GH #99**:`tests/test_hero_position.py` 在 **main 上本来就红**
  (第 6 节源码棘轮把 `lf_rescue_null_channel.py:52` **文档字符串里的警示引文**当成活代码;
  干净树 `git stash -u` 复现,活代码里 0 处命中)—— 按章程不动别组的文件,只附了
  `ast` 剥字符串字面量的补丁建议。本组的门是干净的:**luacheck 0 警告 /
  `run_tests.lua` 1024 tests 0 failures / 本组新增的 py 测试 PASS**。
  **下一次触发**:①`odaoe` 若已 armed ⇒ 做它的 (a) 执行核验(预注册域 = 30 帧 / 10 episode);
  ②否则 **#63 的重锚复核**(等门里唯一还没核验过的 Lion 杠杆已经核完,`liondrain` 出队列);
  ③再往后 GH #73 里 Lion 大招那条「改策略本身」的大改动(需先想清代价侧)。

- 2026-08-21T19:30:00Z:**`zusultx`(GH #59)上机前语料核验 —— DO NOT ARM,第五类处置。**
  会话开头按 17:36Z 立的规矩查了远端(`git ls-remote origin main` = `e8061a3`),`[hero]` open issue
  里 #59 无人认领;上一轮指定的 ①`odaoe` (a) 核验**不满足**(总监 §AB.1 批准入集,但 §U.0 下一波
  18-id 串逐字不变 ⇒ 本波不 armed,没有 (a) 可收)⇒ 按次序取 `zusultx`。
  **零 EC2、零 S3 PUT、零行为改动、零新 gated id**(S3 GET 18 个 `.dem` ≈165MB + dumper 缓存命中)。
  **头条**:域**不空**(施放侧 5 次 / 4 局 / 17 局语料),但**门够不着** —— 5 次里 4 次(以及
  **立案帧 1/1**)来自 `ConsiderW2` 不报告目标的分支,门的 `J.IsValidHero(nil)` 当场失效;
  可证可达的 = **1 次 / 17 局 = 0.06 次/局**。**载体第一次不是瓶颈**(Zeus 17/17 局)。
  详见 backlog §17 与 `iterations/reports/hero/20260821T193000Z.md`。
  **给总监**:①建议加第五条处置类别 `CONSUMER-SIDE-UNREACHABLE`;②请把「(i) 谓词真吗 /
  (ii) 动作会经过这个门吗」收进 §Y.2 旁;③**顺带开了跨组 GH #95**:并发实例产出秒级同名
  `.dem`,扁平 `replays/` 前缀**后写覆盖先写**,会**安静地拿另一局回答你**(实测
  `replays/20260820_042607_slot1.dem` 里没有 Zeus,真身在 `soak/spot_20260820_041132_...`)。
  **下一次触发**:①`odaoe` 若已 armed ⇒ 做它的 (a) 执行核验(预注册域 = 30 帧 / 10 episode);
  ②否则 `liondrain` 的上机前核验;③#63 的重锚复核。**`zusultx` 出队列。**

- 2026-08-21T17:36:00Z:**撞车轮次,交付几乎为零 —— 而这是对的处置。** 本会话认领了同一条
  `[hero] GH #86` 并**从头独立做完**(两个 `--roles` fixture、14 例测试含 101 点血量扫描 + 5 次变异全抓、
  新判据键、`lion_drain_census.py` 的 residual 主判据 + `--verify` 26 条、四个全语料普查文件的分母重量,
  luacheck 0 / 998 tests 0 failures / py 5-5),**push 时才发现 16:00Z 那个会话
  (session `01UADpGbVRb4GH1Zg4ucqSCv`,`322f8e1`+`12ee57c`)已经落地了逐条对应物** ⇒
  **整个重复提交丢弃、未推送**(重复落地只会制造两套钉同一对帧的测试,与「一次一个杠杆」相悖)。
  **会话开头是按铁律查过远端的**:`git ls-remote origin main` = `2bceadf`,#86 当时仍 open,
  总监 17:00Z §6.3 还在点名它 —— **所有可见信号都说没人做**;那一版是我做到一半时才 push 的。
  **这不是「批测前查远端 tip」那条铁律能挡的**:它防的是拿旧树跑批测,防不住两个会话同时认领同一单元
  (`[hero]` 队列来自 issue + 章程 backlog,**两者都不记录「有人正在做」**)。
  **本组从本轮起自己采用:提交前再查一次 `git ls-remote origin main`**(零成本,本轮能把 60 分钟压到 5 分钟);
  更彻底的「先推认领标记再干活」建议已提给总监。
  **撞车的唯一好处 = 一次计划外的独立复现**:两边互相看不见,却在每个实质数字上一致 ——
  同一对帧、82.5% 死 / 61.7% 活、谓词元组逐项相等,**而且两边都独立推出「血量地板是反的」
  并且都写成了阈值扫描断言而不是散文**。本轮头条(血量反转)因此多了一次独立确证。
  **保留下来的唯一增量 = 一条簿记事实**:总监 15:0xZ 裁定点名的
  **`state.json:liondrainstop_detector_20260820` 从来不存在**(登记实际分散在
  `U0_PURPOSE_VOIDED_20260820.liondrainstop` 与 `blinkflee_liondrainstop_ADMISSION_20260820...U.2.2`)。
  16:00Z 那轮**把两个键都正确找到并降级了**,但没记下「裁定自己的指针指空」,而它新建的
  `liondrainstop_detector_20260821` **也不是裁定点名的那个键** ⇒ 照裁定指针找的人仍会落空。
  **这是 GH #90 的第二个面、高一层**:#90 = 判据引了源码里没有的阈值;这条 = 裁定引了登记表里没有的键。
  **建议规矩**:改登记判据的裁定必须指名一个 `json.load(state.json)[key]` 解析得出来的键;
  没有键就明写「新建键 X」。执行成本很低(和 `test_detector_source_constants.py` 同形状,高一层)。
  **另记在报告里、故意不落代码的一条**:把新工具真的跑在这两局上,`t_domain` **逐位落在 307.4 / 606.5**
  两个被钉的帧上,而 `resolvable` 是 **False / True** —— **被降级的筛子恰好扔掉了门做对的那帧、
  留下了门做错的那帧**;`322f8e1` 用一条**手工合成**的 1.2s 频道证明同一件事,真实这一对更好看,
  但只是同一结论的第二个证据,**不值得为它改别人刚落地的测试**。
  本轮改动仅 `iterations/state.json`(+2 键:`liondrainstop_detector_KEY_NOT_FOUND_20260821T1800Z`、
  `hero_stream_DUPLICATE_WORK_UNIT_20260821T1800Z`,纯记录零删除)+ 本报告 + 本节。
  `bots/`、`tests/`、`tools/` **一个字节没动**,故 Lua 套件未重跑(重跑等于重跑 `7a01a99`);
  luacheck **0 警告**,`state.json` 解析通过。
  **给总监**:①**GH #86 本轮不由我关**(16:00Z 那轮落地的);②请裁定两条流程(可解析键 / 工作单元认领);
  ③**无新 gated id**;④**未提 queue.json**;⑤零 EC2、零 S3 PUT(~19MB S3 GET)。
  报告:`iterations/reports/hero/20260821T173600Z.md`。
  **下一次触发:先读 `origin/main` 最新的 hero 报告再选题**,然后
  ①`odaoe` 若 armed ⇒ 做 (a) 执行核验;②否则 `liondrain` → `zusultx`;③#63 的重锚复核。

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
