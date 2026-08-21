# 协同组(strategy)章程

## 使命
全局/团队级策略 + 对线期策略 + 相关架构(TeamBrain 黑板等)。
让 5 个 bot 像一个队伍而不是五个独立个体。自驱 + 认领 [strategy] issue。

## 范围(owner 定)
- 全局策略分发:TeamBrain(团队共享 Lua VM 黑板)及其后续阶段;
- TP 纪律 / 支援仲裁 / 推进-防守姿态(midtp、suptp、tpcommit、ownhalf、
  overchase、pushguard 一族);
- **对线期策略归本组**:拉野(owner:拉野是肯定要做的,数据不对=设计或实现错)、
  兵线控制、换血、吃经验;标准策略要上网检索佐证(验证哲学条件 (c))。

## 每次触发的工作流
1. 扫 [strategy] 前缀的 open issue(dragonghy/dota2bot),优先处理带帧证据的;
   没有 issue 就从下面 backlog 取最上面一条。
2. 改动纪律(铁律之上的本组细则):
   - 每个行为改动 **gated**(`J.IsSoakCandidate('<id>')`,turbo-only),
     新 id 要在 `iterations/state.json` 登记;
   - **必须带真实帧 fixture**(make_fixture.py → tests/fixtures/ →
     tests/mock/replay_fixture.lua),gate-plumbing 测试不算本地验证;
   - 想进测试集:改 `iterations/streams/test_set.md` 提议(留历史行),
     总监批准;需要批测数据就往 `iterations/queue.json` 提请求;
   - **一次动一个小杠杆**。lanefix 大捆绑两次被拒(gpm −74.5/−88.7)的教训:
     局部各自正确 ≠ 集体涌现好。
3. push 前过铁律 6 的门(luacheck 0 警告 + 测试全绿)。
4. 报告写到 `iterations/reports/strategy/<UTC时间戳>.md`。

## Backlog(优先级从上到下,做完划掉、发现新的补进来)
0i. **【2026-08-21T11:32Z 新增,(甲) 已做完,(乙) 是下一条】等级常数的 Turbo 不可达
   (GH #84,总监交接)**。**(甲) 分类表已交并钉成棘轮**(`tests/test_level_gate_census.lua`,
   15 例):22 行 = **6 TEETH / 12 INERT / 4 REDUNDANT**,**6 条 TEETH 全在通用文件**
   (`item_purchase:228`、`mode_farm:285/392/506/535`、`aiug:5749`)。
   两条对 #84 的修正已留言:(i) **牙齿与 AND/OR 不对齐**(3 合取 + 3 析取);
   (ii) **§5 的筛子「合取 ∧ N>=20」选出 4 行且全是 INERT**,而 6 条 TEETH 的 N 全是 15/18
   —— 建议筛子改成「判读 = TEETH」;(iii) 被点名为「无害析取」的 392/506 的承重腿
   `J.IsLateGame()` 在 Turbo 是 `DotaTime() > 18*60`,**全档 94 帧无一成立**(真 helper 实跑)。
   **下一条(本组自己接)**:从 6 条 TEETH 里挑 **一条** 做完整形状 —— gated + 真实帧 +
   **断言最终 desire**(不是断言分支可达)。~~建议 `mode_farm_generic:285`~~
   **2026-08-21T13:48Z:`285` 结构上做不了,那一帧不存在也买不到 —— 见下面第 0j 条
   (第十三条世界断言)。语料请求已撤回。**
   ~~**改取 `mode_farm_generic:535`**~~ **2026-08-21T15:46Z:`535` 也做不了 (乙) 的形状,
   但卡点可以买到 —— 见下面第 0k 条。两半分开量了:情境这一半**活的**(872 存活英雄帧里
   **3 帧**满足内层 `if` 每一个子句,等级 4/11/11,敌人 55–167u,2–3 队友 ⇒ TEETH 得到实证),
   外层的 `runMode` **从不同时成立**(`X.ShouldRun ~= 0` 只有 5/940 帧,交集空)。
   **语料请求是活的**(不像 #84 那次是撤回):要一帧 farm `ShouldRun` 非 0 且同帧 900 内 ≥2 队友、
   `attackRange+50` 内有非魔免敌人。**下一轮默认改取 `item_purchase_generic:228`**
   (自家 t3 掉血 ⇒ 留买活钱,同样不读 mode、不读 runMode 这类文件局部状态)。
   **2026-08-21T17:58Z:`228` 也做不了 —— 而且理由和前两条都不一样:它在 Turbo 里根本不跑。**
   那道门在 `GeneralPurchase()`(192-363)里,而这个函数只有一个调用点(1276):
   `if GetGameMode() == 23 then TurboModeGeneralPurchase() else GeneralPurchase() end`。
   真实 Turbo 走另一条腿 ⇒ 整个函数、连同 `t3AlreadyDamaged` 的四写两读和 `:272` 的
   留买活钱一起不跑;`TurboModeGeneralPurchase`(366-437)**自己没有买活留钱**
   ⇒ **Turbo 的采购里根本不存在买活留钱**,原因在等级常数**上面 1048 行**。
   **(甲) 对 `228` 的 TEETH 判读据此更正。三条 TEETH 三个不同的卡点**:
   `285` = dumper 缺口(买不到)/ `535` = 语料缺口(**能买,请求活的**)/ `228` = 不在 Turbo 里(没什么可买的)。
   **下一轮默认改取 `ability_item_usage_generic:5749`**(守遗迹 TP,另外四项 AND 都是活的 Turbo 状态)。
   规矩照旧:**断言最终 desire,不是断言分支可达**;掉 farm desire ≠ 去打架。
   **顺带记的第二个杠杆(不折进本条)**:自动买活三条路径在 Turbo 全关
   —— `aiug:568` 的 `ancient:GetHealth() < 0.8`(**单位错配**,该开 `[bug]`)、
   `:582` 的等级 >24、`:578` 的 `nFullRespawnTime < 60` 早退(**推论,harness 判不了**,
   `GetRespawnTime` 不在 dump 里)。已成 `[recorded]` 用例。
0l. **【2026-08-21T17:58Z 新增,已钉住、不要改 bots/、不要改 mock】第十五条世界断言:
   fixture 世界同时是 Turbo 和不是 Turbo,分界线是拼写**。
   `GetGameMode() == GAMEMODE_TURBO` → **TRUE 96/96**;`GetGameMode() == 23` → **FALSE 96/96**。
   引擎里两者同数(`GAMEMODE_TURBO` 就是 23),`bots/` 还自带自愈行
   (`if GAMEMODE_TURBO == nil then GAMEMODE_TURBO = 23 end`,`hero_selection:45` / `aiug:16`)
   ⇒ **不是 `bots/` 的缺陷**。成因是 mock 的两条「帮忙」叠加:
   (1) `bot_api.lua` 把未知 ALL_CAPS 自动解析成 1001 起的哨兵 ⇒ `GAMEMODE_TURBO` = 1149,
   **并且因此永不为 nil ⇒ 那两条自愈行永远不执行**;
   (2) `replay_fixture.lua:487` 用**名字**声明世界是 Turbo,继承同一个哨兵。
   **九处字面量 `23` 的比较站在错的一边**(`item_purchase:1080/1082/1276`、`mode_laning:156`、
   `mode_team_roam:1146`、`aba_defend:239`、`global_cache:207`、`override_generic/mode_laning:31`、
   `aba_push:58`),名字拼法(`J.IsModeTurbo`,**94 个调用点**)全读 TRUE。
   裂缝**穿过一个表达式**(`aba_push:171-172`:阈值按名字、操作数按数字)和**一个表构造式**
   (同文件 `currentTime` 按数字、四个 `isXxxGame/isLaningPhase` 兄弟按名字)。
   **有多大**:全竞价 96 帧 × 21 mode × 两读法 = 2016 格,**只动 21 格(全是对线出价)**,
   但**竞价赢家动 18/96**,其中**赢家 mode 本身换了 10 条**(7 → `defend_tower_bot`、3 → `retreat`)
   ⇒ **10/96 帧上 fixture 说「在对线」而诚实世界说「在防守/在跑」**(第十四条只动 1 个赢家)。
   **方向是机制不是统计**:`mode_laning_generic:156` 的 `*1.65` 每帧都关,而 242-244 是
   `currentTime <= X` 阶梯 ⇒ **每个 fixture 落在更早的台阶、出价更高** ⇒ **全仓库竞价级结论
   在 22% 语料上系统偏向对线**。
   **诚实边界**:裂缝穿过的那条推塔封顶 **0/96 两读法都不动**(诚实读法要 `DotaTime>750s`,
   全档最晚 690.5s,批测 ~640s 自终止)—— 与 (甲) 给 `J.IsLateGame()` 记的是同一条边界。
   **记账不动手的三条**:① 三条 turbo 时钟膨胀里 **两条写了没人读**(`aba_defend:239`、
   `global_cache:207`;全仓库只有两个读者且都在 `aba_push`,`:240` 那条还要求敌方有真人)——
   同 `towerreach` 三写零读;② 七处 `== GAMEMODE_ARDM` **靠运气站对边**,只修 TURBO 不修 ARDM
   是半个修法;③ **更正本组上一轮自己的数**(第十四条自查里的 `retnear armed → laning 0.369`)。
   **归总监**(`[harness]` **GH #93**):mock 该不该把 `GAMEMODE_*` 定成引擎真值。
   **本组建议:该** —— 与 #61/#81/#89/#91 不同,这里**没有任何东西需要建模**,
   `bots/` 自己已经写下正确值两次;代价已量:M12 一行让本文件 **8 条断言变红**。
   已成 `tests/test_gamemode_world_assertion.lua`(24 例,14 条变异),
   `state.json:gamemode_WORLD_ASSERTION_15_20260821`。
   **给全组补的做法**:**「变异只让源码钉子变红、行为断言全不动」是信号不是通过** ——
   多半意味着你钉的站点不是语料实际经过的那个。本轮 M4 就是这样翻出一个事实错误
   (把 21 次对线出价变化记在 `override_generic` 那份上,而它只对
   `Utils.BuggyHeroesDueToValveTooLazy` 的英雄 `dofile`;活的是 `mode_laning_generic:156`)。
   与上一轮编目的两条**空断言**形状不同:那两条是测试自己的毛病,这条是**世界模型**的毛病。
   另:上一轮 M7 的形状(测量重述常数却没钉常数)**本轮以 M9 复发** ⇒ 当检查项跑,别当经验记。
   **给全组补的第二条做法(M16,是全套跑抓出来的、不是我设计的变异)**:
   本文件的诚实探针**泄漏给了后面的测试文件** —— `GAMEMODE_TURBO` 是普通全局,
   `run_tests.lua` 是**一个进程按字母序跑完所有 `test_*.lua`**,最后一次 `world(path,true)`
   把 `23` 留在原地 ⇒ **本文件之后每一个测试文件都在诚实世界里跑**,等于把本文件量出来的
   「21 帧出价 / 18 帧赢家」位移**静悄悄施加到别人的断言上**,全套跑出现 3 个 `F`。
   **这正是本文件在讲的事,由本文件亲手犯了一次。** 已修(`unprobe()`)并**把「后继者继承到
   什么」写成断言**。⇒ **凡是用 rawset 全局做探针的用例,必须有一条断言描述「本文件跑完之后
   世界是什么样」** —— 单文件跑永远发现不了,全套跑也只给你一个不相干文件名上的 `F`。
0k. **【2026-08-21T15:46Z 新增,已钉住、不要改 bots/、不要改 loader、不要给 mock 打桩】
   第十四条世界断言:惰性初始化的时钟戳,让「第一次调用」永远是自己的初始化调用**。
   形状(`mode_farm_generic:123-126`):`GameStates.defendPings = ... or { pingedTime = GameTime() }`
   紧接着 `if GameTime() - pingedTime <= 5.0 then return DESIRE_NONE end`。
   游戏里没问题(表开局填一次);**fixture 里 VM 只活一次调用** ⇒ 两行读同一次时钟 ⇒
   差值**恰好 0** ⇒ **守卫每帧触发**。**两个互相独立的原因,修掉显眼的那个什么都不会变**:
   (1) mock 的 `GameTime()` 是常数 0 而 loader 把 `DotaTime()` 接到真实帧时间(**两个差整整一局的时钟**);
   (2) 戳是**用它稍后要比的那个时钟**初始化的 —— **(2) 单独就够**,已写成变异探针断言。
   **四个已发布站点共用这个键,三个挡在出价前面**:`mode_farm_generic:123`、
   `mode_side_shop_generic:50`、`aba_push:222`(**三条推塔出价都从这里来**)、
   `aba_defend:881`(只挡 ping,防守出价不受影响,但它是共享键的**写者**)。
   **有多大(94 申报 subject)**:farm **94/94 地板** → 声明陈旧后 88 地板 / **1 真出价** / **5 崩溃**;
   三条推塔 68/94 → **36/94**(**戳单独按住 32 条**);side_shop 94/94 → 94/94(**阴性对照**);
   **21 个可驱动 mode 的竞价赢家 94 帧里变 1 帧**(`f_260820_043120_viper_defend_paired`,
   `defend_tower_bot 0.100` → **`push_tower_bot 0.920`**)。**出价动得多、结果动得少,两半都在用例里。**
   **它还替 farm 藏了一次崩溃**:`GetRoshanDesire`(`mode_farm_generic:370`)未打桩 ⇒
   **`mode_farm_generic` 是第三个「跑不起来的 mode 文件」**(#62 §0d 只点了两个),
   而且**此前不可能被发现**(守卫 124 行返回、崩溃 370 行)。它是真引擎 API(`.luacheckrc` 里有)
   ⇒ **mock 缺口不是 `bots/` 笔误**。**回读 (甲) 分类表**:崩溃点上面一行就是 (甲) 判 REDUNDANT 的
   `mode_farm_generic:369`(`GetLevel() >= 23`)—— 那条判读**从源码读的、不可能从帧读**,已成断言。
   **归总监的两个口径决定**(`[harness]` **GH #91**):① loader 替所有测试声明「最近没人 ping 防守」
   还是每个测试自己声明(**本组建议照 GH #61 定案:每个测试自己声明**,给 `rf` 加一个
   **有名字的**助手,让假设是用例里看得见的一行);② 要不要给 `GetRoshanDesire` 打桩。
   **本组今后写任何竞价级用例,必须先声明这条假设并说明口径**,否则读的是地板不是这一帧。
   已成 `tests/test_pingstamp_world_assertion.lua`(18 例),
   `state.json:pingstamp_WORLD_ASSERTION_14_20260821`。
0j. **【2026-08-21T13:48Z 新增,已钉住、不要改 bots/、不要改 loader】第十三条世界断言:
   fixture 上没有人处在任何 mode**。`bot:GetActiveMode()` 是 **bot VM 自己的状态**,不是实体属性
   ⇒ 不在 `.dem` 里 ⇒ 每个 fixture 都不带 ⇒ mock 落到 `default_for('Get*') = 0`,而每个
   `BOT_MODE_*` 是 ≥1001 的 auto-id ⇒ **`GetActiveMode() == BOT_MODE_任何东西` 在
   872 英雄帧 × 24 个 mode 名 × 210 个已发布比较行上恒 FALSE**(含 `BOT_MODE_NONE`)。
   实测:八条 J 谓词(`IsRetreating`/`IsGoingOnSomeone`/`IsDefending`/`IsPushing`/`IsLaning`/
   `IsDoingRoshan`/`IsShopping`/`IsFarming`)**各 0/872**;`GetSpecialModeAllies` **0 次非空**。
   **比前十二条更坏:两个方向同时错且相反** —— 脚本侧比较恒 FALSE,**引擎侧过滤被 loader 丢掉**
   (`function(self, radius, enemies, _)`,872/872 帧带 ATTACK 过滤与不过滤等长)⇒
   `J.IsInTeamFight` 反而在 **71/872** 帧读 TRUE(过度宽松)。
   **直接后果**:`J.GetTeamFightLocation` 末端是 `GetCenterOfUnits(GetSpecialModeAllies(...))`,
   而 **`GetCenterOfUnits({})` 按已发布代码返回 `Vector(0,0)` = 地图原点、不是 nil** ⇒
   全档 188 团队帧里 6 个非 nil、**6/6 在原点**,#84 §5 要的「非 nil ∧ <2500 ∧ 核心」
   **7 个英雄帧全是幻影**(合格是因为站在河道附近)。**再买语料也没用**:dumper 字段表已钉,
   不含任何 mode 形状字段;供上它就等于**建模**「当时 bot 在想什么」。
   **凡是在 fixture 上 fork 在 mode / 上述八条谓词 / `GetTeamFightLocation` 上的断言,
   读的都是常数,和它来自的那一局无关。**
   **一条不是 harness 假象的读数(记账,不动手)**:35 个消费方全只测 `~= nil`,而游戏里
   `IsInTeamFight(member,**1500**,不含自己)` 成立、`GetSpecialModeAllies(member,**1400**,含自己)`
   可空 ⇒ 1400–1500 的壳里两个 ATTACK 队友就能让 35 个读者同时收到「团战在河道中心」。
   **本 harness 判不了**,要动先要游戏内观察或 labelled synthetic。
   已成 `tests/test_activemode_world_assertion.lua`(13 例,九次变异全绿),
   `state.json:activemode_WORLD_ASSERTION_13_20260821`,`[harness]` **GH #89** 交总监决定 loader 口径
   (本组建议**不要**让 loader 认 mode:那会一次性移动 30 + 71 个读数,而且只能靠建模)。
0y. ~~**item_blink 撤退分支被烧成 15s CD 的腿**(GH #71,英雄组交接)~~ **已做完
   (2026-08-20T17:15Z):helper `J.ShouldHoldBlinkFlee` + gated `blinkflee`,两帧钉住
   (f_260820_043124_axe_blink_flee_529/555),8 例 + 五次变异全绿。gated 未 armed,
   入集申请见 GH #71 留言。issue #71 的建议 #2(敌方威胁地板)**留作第二个杠杆**,
   不折进这条 gate**。
   **2026-08-20T21:30Z 续(GH #74 §1.5(3) / 总监 §10.1,已做完)**:第二个英雄 + 第二个波次的
   fixture 对已钉(`f_260820_162859_es_blink_flee_615` HOLD / `f_260820_163429_es_blink_init_621`
   放行),11 例 + 六次变异全绿。**但读出一条负面结果:HOLD 集不同质** —— 三帧门读数相同,
   ground truth 2 活 1 死(ES **+6.0s 死于 viper 1175**,第一发伤害落在决策后 ~1.5s ⇒
   2.0s **回看窗**结构上看不见「还没开火的杀伤位敌人」)。⇒ **#71 建议 #2 那条「敌方威胁地板」
   从「留作第二个杠杆」升级为「armed 前的可能前置」**,但**先要 §5 那个数**(见下):
   **不要照着这一帧 n=1 调阈值**(lanefix 教训)。
   ~~**卡在**:请录像组在已付过钱的语料上数「HOLD 合格帧之后 8s 内 subject 死掉」的比例~~
   **2026-08-21T09:30Z:这个数收到了,0y 不再卡住**(录像组 GH #74 09:00Z 在**已付过钱**的 0411xx
   归档上答:5 次真实撤退腿,反事实重放 **5/5 会 HOLD、5/5 事后 15s 内没死**)。本轮把它做成仓库维护的台账
   (`test_replay_260820_axe_blink_flee.lua` 的 `[recorded]` 用例,跨 5 枚 fixture):
   **3 枚撤退腿 HOLD 帧 / 1 次 8s 内死亡 / 0 次可归因于 hold** —— 那 1 次(es 614.9)
   **实际发生的那次闪现也没能阻止死亡**(viper 1175→779→594→515 追上来照样打死,#74 §1.3(B))⇒
   要证明 hold 有代价,需要一帧「真实闪现确实脱离了且人活下来」的 HOLD 合格帧,**全语料没有**。
   ⇒ **#71 建议 #2 的「敌方威胁地板」退回「第二个杠杆」,不再是 armed 前置**(21:30Z 曾临时升格)。
   **是否 armed 归总监**(§AB.7 已把 (a) 定案在归档上,三条约束照旧),本组不重复申请入集。
   **2026-08-21T09:30Z 另一半产出(认领 GH #74 §5)**:钉上这一族**唯一缺的那一半** ——
   `f_260820_042612_axe_blink_init_573`(seed 887, armed=radiant, Axe 在 armed 侧),
   **第一枚 guard 读 FALSE、而且是 HP 地板做的决定的真实帧**(33.3% 血;6.0s 回看窗内零英雄伤害
   ⇒ 伤害子句安静,不能记它头上;juggernaut 在 648 ⇒ 分支前置满足,门是真的被问到了 ——
   这正是它与 es 621.0 那枚「放行」帧的区别,那枚是**前置**放行的,不是门)。
   ground truth:进攻腿(cos −0.999)落点距 jugg 183,**+2.9s 把 46% 血的 jugg 打死**,血量没掉到 28% 以下。
   FALSE 方向此前**只有变异**(把真实帧血量改到 60%)。**bots/ 一位没动。**
0z. **~~【新的头号阻塞,2026-08-20T07:30Z】lane front 是地图原点(GH #61)~~
   #61 已落地(director 17:00Z, 71b510c)**:`rf.load` 显式 refuse `GetLaneFrontLocation`,
   每个测试自己声明假设。**本组名下三条子任务的现状**:
   - **`DefendThink:1441` 的恒真否决**(原文 `1418`,代码飘动到 `1441`;已发布未 gated 的动作类缺陷):
     **状态层已钉住**(2026-08-20T19:25Z,本报告):`tests/test_defnum_recent_hit_parity.lua`
     的 MECHANISM 循环补断言 `#ds.nInRangeAlly >= #ds.nInRangeEnemy` 在 POKED/PAIRED/WD 三帧
     实证为 TRUE;两处 [reverse] 源码钉子(shape + ungated)。**动作层未钉**:三个 fixture
     的 subject 都在 ~8k 外,`ds.distanceToLane >> 1600`,DefendThink 走 elif 分支
     `Action_MoveToLocation` 而不是 `Action_AttackMove`,line 1441 的 AttackMove 分支
     结构不可达;不伪造 lane front 到 subject 附近(那不是 declare an assumption,那是模拟游戏)。
     **(a) 语料请求已路由 replay-check(GH #62 追评)**:要一份 `defend won + dist<1600 +
     无更早 return` 的真实帧。
   - **`aba_defend:1139` 的死代码**(`0 > n` 恒假):已在 GH #62 定为死代码,不产 gate,
     由 `defnum` 的注释统一记账,无需新单独工作。
   - **`defnum` 入集申请(GH #62)**:归总监决策。本组这轮不改立场。
   **顺带的纪律**(继续有效):本组今后凡是要断言最终出价的用例,先跑一遍「把 lane front 挪离原点」这个变异;
   会 FAIL 的断言就是骑在桩上的断言,必须如实标注(`defclose` 已因此在 GH #58 标注)。
0. **「命令的边界」普查 —— 2026-08-19T23:25Z 已做完枚举,范围收窄**。
   全仓库 `bOnce=false` / `Action_MoveToUnit` 站点已逐个 grep 过:
   `mode_defend_tower_*` / `mode_attack` / `mode_push_tower_*` **根本不含**连续型
   单位命令(原条目那一行作废);`mode_outpost_generic:117` 打的是静止建筑,无尾巴;
   `mode_team_roam_generic:569` 是非英雄目标。**只剩 `mode_roam_generic` 的九处**
   (642–871),而且它们形状完全一致:**授权是一个会到点消失的 modifier 计时器
   (MoM berserk 6.0s / WK-helm 重生 / marci unleash / muerta / chronosphere /
   static link / tether / pulse nova),命令却是连续的**,出价分支读的是同一个
   modifier,释放同样只住在 `Think` 里 —— 与 `roamreach` 逐条同构、且更确定。
   **但本轮取到的唯一一份 MoM 实证不支持改动**(见下面 23:25Z 状态:那 4 秒打死了 CM;
   前 3 秒是被 Frostbite 缠住,不是陈旧命令)。**下一步:先要一帧「buff 到期 →
   目标逃走 → 追出去且零收益」的实证再动**;工具链已经能取到了(fixture 现在带
   真实 modifier)。**不要照着窗口 2 那种「泉水里开 MoM」去写** —— 那是物品使用
   问题,归英雄/物品组。
   **已知不通的路**:想在**命令已经在执行之后**回收它,唯一落点是每帧都跑的
   `ability_item_usage_generic.lua`(mode 之外唯一的全局 Think)——那是**另一个杠杆**,
   不要和「下达时带边界」合做。
0a. **等一份带基地攻防的语料再做的三条**(2026-08-20T05:30Z 记下,11:30Z 扩了一条;机制已确认、证据取不到)。
   **新增第三条(2026-08-20T11:30Z)**:`mode_retreat_generic.X.ShouldRun:774` 的
   `#hEnemyHeroList >= #hAllyHeroList` —— **两边都是 0 时恒真**,即「周围一个人都没有」被读成
   「我在这里被压制」,而它把出价推到 `BOT_MODE_DESIRE_ABSOLUTE * 1.1`(全系统最高、压过一切),
   每 2 秒重评一次 ⇒ **一个人站在敌方兵营边上、周围没有任何敌人,只要对面还有 2 个人活着,就被永久赶回去**。
   **取不到帧的原因**:5 局 63,350 帧里**没有任何一帧**把英雄放到敌方兵营 800 以内,五局全部以
   `economy_10min_cap` 在 ~640s 自终止、只掉一塔。与下面两条同一个语料缺口。
   **顺带在本轮出局的**:`ShouldRun:740`(6 级前深入不要追)在本语料里 **0 帧** ——
   `enemyFountainDistance < 8111` 对 6 级以下英雄从未成立,整条是死的。
   要做先向批测台/录像组要**打到基地**的局(与下面两条一起要,一次要够)。
   `aba_defend:939`(`enemiesOnHG >= 2 and not recentlyHit` 的高地分支)与 `enemiesAtAncient >= 1`
   那条支线,以及同一函数里的**顺序缺陷**:`panic.floor`(0.94/0.96)在 1155 行用 `math.max` 压上去,
   1170 行紧接着**无条件** `nDefendDesire = nDefendDesire * 0.4`(`recentlyHit`)再 `min(..., Low)`
   ⇒ **写成地板的东西被下游乘掉**(`enemiesOnHG` 那条被 `not recentlyHit` 挡住,所以只有遗迹告急
   那条 0.94 会撞上)。**取不到帧的原因**:批测局在基地攻防发生之前就自终止,2026-08-20 04:3x 波次
   六局里**离任一遗迹最近的敌人是 4925 码**(`BASE_THREAT_RADIUS` 是 2600、panic 那条要 2200)。
   要做先向批测台/录像组要**打到基地**的局。
0c. **【2026-08-20T23:30Z 起有棘轮了,并且已经治了第一对】** 第二层债务
   (**有 `player_id`、无 `roles`** ⇒ 每次 `jmz.GetPosition` 都是槽位)此前**一条棘轮都没有**;
   现在是 `tests/test_fixture_roles.lua` 的 `SLOT_DERIVED_ROLES`,**双向棘轮**,治好 2 个后**剩 8 个**
   (其中 `f_221200_od_roles.lua` **永远治不好** —— 裸树 sha `829202a` 无 seed,`positions_for_game` 拒绝;
   它同时是角色契约的**锚点**,其 `EXPECT` 就是 loader 的无 roles 回退,已单独钉成用例说明这一点)。
   **已做完的第一对**:`defstale` 的 BAIL/CONTROL 两帧(seed 868)—— **pin 成立**,但世界变了
   (CONTROL 的 subject **核心→辅助翻面**),且**离失效只差一级等级**(`aba_defend:922` 的按位置取阈值
   等级门:pos1@5 = 0.00 vs pos3@5 = 0.30)。详见当前状态节。
   **~~下一批~~ `f_260820_043124_axe_blink_kill` 已做完(2026-08-21T05:30Z)**:pin 成立,
   **13 条原用例逐条未改**,而且这次把「为什么成立」也钉住了 —— 那条 guard **一次角色都不读**
   (零次读取已成断言)。**真正动的东西在外面一层**:`Item.GetRoleItemsBuyList` 用角色当 key,
   这枚 **`axebuyblink` 的 (a) 证据帧**(全语料唯一一次 Axe 真拿着跳刀)此前**一直对着错的
   出装表读** —— 真值 `pos_3`(blink 排第 **4**,前面多一件 Crimson Guard),不是槽位说的
   `pos_2`(= `pos_1` 表,blink 排第 3)⇒ **加强** GH #56 的立论(已留言)。
   顺带量出**第二条**:`J.GetPosition`(包装)与 `Role.GetPosition`(模块)**不是同一个函数**,
   **nil 地板还不一样**(2 vs 3),且 `aba_role` 之外**只有两个**调用点 ——
   `jmz_func:8070` 与 **`aba_item:1600`(出装表 key,唯一绕过包装的)**。不是缺陷(模块自带地板),
   但**给全组一条做法更新:数「这一帧读了几次角色」必须同时 hook 两个入口**,只 hook
   `J.GetPosition` 会漏掉出装那一路(上一轮 `defstale` 消费方是 `aba_defend`,走包装,结论不受影响)。
   棘轮 **8 → 7**。详见 `iterations/reports/strategy/20260821T053000Z.md` 与
   `state.json:axeblinkkill_ROLE_HEAL_20260821`。
   **`f_260820_102645_cm_es_reach` 已做完(2026-08-21T07:40Z)**:pin 成立,**48 条消费方用例
   (两个 cmrguard 文件各 24)逐条未改**,原因已成断言 —— `X.cm_IsRSafeToOpen` 与 `X.ConsiderR()`
   **各读 0 次位置**(两个入口都数)。**但这一帧的划分翻了两个**(sniper 核心→辅助、viper 辅助→核心),
   subject CM 是置换的**不动点**(槽位 5 = 抽签 5)⇒ 唯一那次角色读取(出装表 key,`aba_item:1600`)
   **恰好不动**,这枚 fixture 因此是上一轮 Axe 那条发现的 **CONTROL**。棘轮 **7 → 6**。
   **本轮真正值钱的是第十二条世界断言,在地图另一边(见下面第 0h 条)。**
   **下一批(一次一个,不要批量刷)**:`f_260820_103216_cm_es_aftershock`(同一对的另一半,
   建议先取,好把这对的结论一起收口)、两个 `lion_drain_*`、两个 `od_eclipse_*`。
   **每治一个都要重读它钉住的结论并写下来** —— 治一帧可能翻掉它钉的东西,那正是这件事的意义。
   **并且不许拿「核心/辅助划分通常稳定」当跳过某一帧的理由**:三次治疗三种结果 ——
   `defstale`(seed 868)翻了一个核心、`axe_blink_kill`(seed 885)五个全动零翻面、
   `cm_es_reach`(seed 906)三个动、**翻了两个** —— 那是**每帧的测量**,不是规律。
0h. **【2026-08-21T07:40Z 新增,已钉住、不要批量改】第十二条世界断言:`--roles` 结构上够不到敌人,
   fixture 上每个敌人都是 pos 3 / `IsCore` = true**。全语料实测 **93 fixture / 465 个敌方英雄 /
   读到非 3 的 0 个**。**不是生成器少写**(十个英雄的抽签位置全写了,loader 也全 `rawset` 成
   `assignedRole`),是 `aba_role.GetPosition` 的敌方分支**把它扔掉**:
   `role = GetEnemyPosition(pid); if role ~= nil then return role end; return 3`,
   而 `GetEnemyPosition` 的缓存只有 `enemy_role_estimation.UpdateEnemyHeroPositions()` 会填、
   **loader 一次都没调过**。⇒ **凡是在 fixture 上 fork 在敌人位置或 `J.IsCore(敌人)` 上的断言,
   读的都是常数,和它来自的那一局无关。**
   **估计器现在跑得起来了**(要 `GetUnitList(UNIT_LIST_ENEMY_HEROES)`,2026-08-20 才接通,
   所以这个问题以前问不出来):手动 warm 一次,本帧答 bristleback 1 / zuus 3 / earthshaker 2 /
   juggernaut 5 / jakiro 4 —— 1..5 的置换,**与抽签一致 0/5**。**这不是给估计器判死刑**
   (它读的是观察到的表现,和抽签本就是两个问题);能报的是 **`J.GetPosition` 用同一个名字
   对友军答抽签、对敌人答估计,消费方分不出来**。
   **本条不产 gate、不改 bots/、不改 loader**:让 loader 调估计器会**一次性移动全部 93 个 fixture
   的敌方位置**,而 `test_fixture_roles.lua` 存在的意义就是不许发生这种事。已钉成全语料棘轮 +
   源码钉子(敌方分支必须仍覆盖 `role`、仍 `return 3`、**不得**读 `assignedRole`),
   估计器的答案也先记进用例,让将来要动的人手上先有体量。**决定权交总监**(已开 `[harness]` **GH #81**)。
   ~~**仓库里现存每一个 fixture 的角色都还是槽位派生的**(2026-08-20T05:30Z 记下)~~。loader 现在
   支持抽签角色(`make_fixture.py --roles <analysis.json>`),但**只有本轮新生成的两个 fixture 带**;
   其余全部落到 `RoleAssignment[team][i]` = 抽签槽位,本轮六局实测与抽签真值吻合 **23/60 = 38%**
   (总监 GH #57 全语料口径 47.3%)。**凡是在 fixture 里 fork 在 `jmz.GetPosition` 上的断言,
   只有 ~40% 的把握描述了它来自的那一局** —— `J.IsCore`、`ShouldDefend`、`GetClosestAllyPos`、
   `lf_rescue` 的核心豁免、`suptp` 的辅助判定全在这条线上。做法同 0b:**一次一个、重生成、重读结论**,
   不要批量刷。**本组已经被这个坑咬过一次**(本轮第一版钉帧,见当前状态节)。
0e. **仓库里现存每一个 fixture 的 `observed.burst` 都可能混着幻象伤害**(2026-08-20T13:30Z 记下)。
   战斗日志只认名字不认实体,生成器现在会**检测并 withhold**(`ground_truth_ambiguous` /
   `recent_damage_ambiguous`),但**只有本轮新生成的三个 fixture 带这个检查**。
   `observed.burst` 是 **`J.WillAllySurviveTpWindow`(已发布未 gated)**、`J.IsIncomingBurstLethal`、
   `J.ShouldRetreatLaneBurst` 的**唯一验收输入** ⇒ **凡是用 burst 钉住的 TP 生存/爆发结论,
   若那一帧有幻象在场都要重读**(`lf_rescue` 的 #37 三帧、`tpdead`、`f_182552_warlock_ult_hoard`)。
   做法同 0b/0c:**一次一个、重生成、重读结论**,不要批量刷。判据是现成的:重跑
   `make_fixture.py`,看它是否吐出 `ground_truth_ambiguous`。
   **顺带给录像组的**:任何按英雄名统计伤害的检测器(`tpdying_landing.py` 的 REALIZED-LETHAL 替身、
   `tp_attribution.py`、`watch_deaths.py`)有同一个漏洞。
0f. **【2026-08-21T01:20Z 新增,等语料】`J.ShouldInitiateLaneKill` / `J.ShouldSupportComboKill`
   的候选循环取「引擎列表里第一个过门的」,不是「最好杀的」**。实证帧
   `f_260820_181711_wk_l1trade_333`:循环返回 **jakiro(399 血、满机动)**,放过同一份候选列表里的
   **juggernaut(160 血 = 15%、正被 WK 自己的 `hellfire_blast` 定住、剩 2.4s、539u)**,后者门槛只要
   前者的 **1/2.5**。标准打法是集火那个已经要死的(条件 (c) 可检索佐证)。
   **卡在哪**:这个对比只在「两个候选**都**过致命门」的 burst 值上存在,而致命门读的
   `GetEstimatedDamageToTarget`(我方出伤)**不在 dumper 流里** —— 那个值只在 labelled synthetic 下存在
   (真实那一帧连 jakiro 一个都过不了:门槛 399,我方英雄 4s 实产 44)。
   **⇒ 无 (a) 帧就不 armed**(`lfcorelane` 同一条规矩;照一帧 + 一个合成数调选靶顺序正是 `lanefix` 的入口)。
   **要什么**:一份能答出 `GetEstimatedDamageToTarget` 的语料,或一帧「两个候选都过门」的实证。
   已写成 `tests/test_replay_260820_181711_wk_l1trade.lua` 的 `[recorded]` 用例 +
   `state.json:l1trade_STAR_FRAME_NOT_A_FIRING_20260821`。
   **顺带给全组的口径**:凡是靠致命性子句的分支(`l1trade`/`l5combo`/`ShouldPunishDive` 的 lethal 支线),
   **fixture 上一律不可判**,因为 loader 的 `GetEstimatedDamageToTarget` 只答**敌 → subject**。
   写这类用例必须像本轮一样**把「唯一阻塞项是它」写成断言**,而不是让 helper 返回 nil 就算完。
0g. **【2026-08-21T03:19Z 新增,已钉住、不要改代码】TP 全队配额台账的时间戳是双写,
   单删任何一个都是无声的**。`J.TryTakeTpResponseSlot`(`jmz_func.lua:5706`)里 `tTpQuota.t`
   在**重置分支**和**取票路径**各写一次,**每一个单独看都是 dead store**(实测:单删任一个,
   10 条断言逐位全绿);**两个都删** ⇒ `nNow - tTpQuota.t` 永远 > 6 ⇒ 每次调用都重置 ⇒
   **`TryTakeTpResponseSlot` 永远返回 true**,全队配额**静默变成无限**,fix B 要治的
   COLLECTIVE TP(≥3 人同瞬 TP,3 张卷轴 + ~200s 步行换零干预)原样复发,**没有报错、
   没有日志、没有别的测试会红**。危险正在于:删「那句冗余赋值」**第一次是对的,第二次是灾难**,
   而第一次的安全恰好是第二次的理由。**已钉成断言**(`tests/test_tpresponse_quota_chain.lua`
   的 `[reverse] the quota timestamp is written TWICE and neither write may go`)。
   **本条不产 gate、不改 bots/** —— 现行行为是对的,要防的是未来的"清理"。
   **发现方式值得记一笔:它是变异跑出来的,不是读出来的** —— 本轮 test 7 的第一版
   (断言"窗口从最后一次成功取票起算")**是空的**,M6 全绿才把双写翻出来。
   同一轮 M7 也抓出第二条空断言(只验了取票前有 `and`,没验它是**最后一个**)。
   ⇒ **本组今后凡是"第一次跑就全绿"的用例,变异是硬前置,不是可选项。**
   **未验证边界**:`tTpQuota` 是否真是全队一份,本 harness 判不了(mock 每测新载一次 jmz_func,
   每 bot 一份 VM 看起来完全一样);shipped 注释断言它共享,只有游戏内观察能定。
0b. **旧 fixture 逐个补真实世界(modifier + 挨打史 + 结构)**。生成器与 loader 都已支持
   (modifier 2026-08-19T23:25Z;`recent_damage` 2026-08-20T01:45Z),但**有意没有批量
   重生成**:给一帧补上真实 buff/debuff 或真实的挨打史可能**翻掉**它钉住的那个决定,
   那正是这件事的意义。**一次一个、每次重读结论**。
   ~~优先级最高的是 `tpwatch` 相关的帧~~ **`tpwatch` 已做完(2026-08-20T01:45Z,GH #52):
   判据本体跑完了,结论是负的,建议出集,不要再花轮次在它身上。**
   ~~**下一批候选**:`aba_defend` 的「我在不在挨打」guard 群(`830/939/1137/1253`)~~
   **1253 已做完(2026-08-20T03:36Z):翻面了,产出 gated `defstale`**;**830 不要做**
   (整条分支靠 `jmz.GetPosition`,GH #53 证明 fixture 里全队 pos 都是 1,断言不算证据)。
   **939 已查(2026-08-20T05:30Z):现在第一次可达了,但当前语料取不到实证帧,移到上面第 0a 条。**
   查它的路上撞到**第六条世界断言(结构不可寻址)**并修好(见当前状态节),产出 gated `defclose`;
   **代价是翻掉了上一轮自己的 `defstale` 可达性结论,已在 GH #55 撤回**。
   ~~**仍未做**:`aba_defend:1137`~~ **1137/1196/1418 已查(2026-08-20T07:30Z,GH #62):
   三条同源 —— `ds.nInRangeEnemy` 被上游提前 return 钉成常数 0 ⇒ 1137 是死代码、1196 读的是
   「我是不是一个人」、1418 恒真。1196 产出 gated `defnum`;1137 与 1418 卡在 #61(见第 0z 条)。**
   **仍未做**:`jmz_func.lua:1302/1498/3618/4648`。
   **新可达面(2026-08-20T09:30Z 接通,11 个调用点)**:`GetUnitList(UNIT_LIST_ALL)` 此前在每个 fixture 里
   **恒为空**(第九条世界断言,已修,见当前状态节)。第一次可达的:`mode_retreat_generic` 的**整张出价表**
   (两张英雄表都从它来)、**`J.WeAreStronger`(每个半径、每个 fixture 此前都是空队伍对空队伍)**、
   `mode_laning_generic`/`mode_roshan_generic`/`mode_outpost_generic`/`item_purchase_generic` 的世界扫描,
   以及若干英雄文件。本轮只动了其中一条(退却的人数对比 → `retnear`),**其余每一条都还没有人在真实帧上看过**。
   ~~点名下一批:`X.ShouldRun` 的强制退却链、`RetreatWhenTowerTargetedDesire`~~
   **两条 2026-08-20T11:30Z 已查**:`ShouldRun` 的 774/740 两条**在本语料里 0 帧**(774 移到第 0a 条,
   740 是死的);`RetreatWhenTowerTargetedDesire` **域有 774 帧但断言不了** —— 它的两个触发条件读
   `nEnemyTowers[1]:GetAttackTarget()` 与 `bot:GetEstimatedDamageToTarget(...)`,**都不在 dump 里**。
   **它里面有一条记账、暂不动的**:`GetEstimatedDamageToTarget`(文档已是「对该目标」的估计)
   再喂给 `botTarget:GetActualIncomingDamage(...)` ⇒ **减伤算了两次**;全仓库 91 个调用点里
   **只有 2 处**这么写(本处与 `hero_dazzle:314`),是**离群写法不是惯例**。方向是「更敢越塔」
   (与已知的死亡问题相反)且真实帧上验收不了 ⇒ 要动先要一份能答出这两个引擎量的语料。
   **`C.enemyNearbyExtra` 的塔威胁子句仍然做不了**(要建筑的攻击力/攻速,dump 不带,见 §0d);
   同理 `C.haveEnemyTowerThreat`(三写零读的标定标志,`towerreach` 的物证)也只能旁证、不能当闸门。
   **新可达面(2026-08-20T11:30Z 接通,203 个调用点)**:`bot:GetNearbyTowers`(183)与
   `bot:GetNearbyBarracks`(20)此前在每个 fixture 里恒为空(第十条世界断言,已修)。
   第一次可达的:`mode_retreat_generic` 的 `C.allyTowers1200`/`C.enemyTowers1200`(本轮动了其中一条
   → `towerreach`)、塔光环的友军加成、`ShouldRun` 的四条塔分支,以及 `aba_push`/`aba_defend`/
   英雄文件里**每一处**「我旁边有没有塔」。**其余每一条都还没有人在真实帧上看过。**
0d. **两个 mode 文件在任何 fixture 上都跑不起来,而所有竞价级测试都用 `pcall` 悄悄吞掉了它们**
   (2026-08-20T09:30Z 发现,归总监):`mode_rune_generic:487`(`GetRuneSpawnLocation` nil)、
   `mode_secret_shop_generic:63`(`GetCourierState` nil)。**推论:本仓库过去每一条「谁赢下这一帧」的结论
   都默默排除了这两个 mode 而没有声明**(含本组 `test_tpwatch_channel_bid.lua`)。本组今后写竞价用例
   一律照 `tests/test_retnear_radius_parity.lua` 的做法**把跑不起来的 mode 点名断言**,口径写成
   「在跑得起来的 mode 里」。补不补桩(符文点是地图静态常量)是 #61 同类的口径问题,已在 #61 留言。
   **新可达面(2026-08-20T05:30Z 接通)**:`GetDefendDesireHelper` 的**整个下半段**第一次可以在
   真实帧上跑 —— `ShouldDefend`(5 个 `GetClosestAllyPos` 调用点)、`capBoost`/`baseFloor`、
   panic 地板、`recentlyHit` 衰减、`ConsiderPingedDefend`、tier/血量 remap。本轮只动了其中一条
   (`GetClosestAllyPos`),**其余每一条都还没有人在真实帧上看过**。
   **新可达面(2026-08-20T03:36Z 接通,39 个调用点)**:`GetHeroLastSeenInfo`(28)+
   `J.GetLastSeenEnemiesNearLoc`(11)第一次可达。最值钱的下一批:上面的 `aba_defend:939`、
   `aba_push` 的 last-seen 消费方、`mode_retreat_generic` 的 `GetLastSeenEnemies*`。
   挑一个**已发布未 gated** 的消费方先做,这样翻掉的结论直接就是线上行为。
   新缺陷族,和「最终出价可达性」(第 8 条)平级但是**下一层**:
   **`Action_*` 里的连续型命令(`bOnce=false`、`Action_MoveToUnit` 等)在它的 mode
   不再赢下竞价之后没有任何人会再评估它** —— mode 的 `Think` 不被调用,写在 `Think`
   里的 leash/释放也就不可达。凡是「一帧成立的条件 → 下一条连续命令」的地方都要查:
   命令的**持续时间**必须由它自己带边界,不能靠「下一帧再判一次」。
   `roamreach` 只修了 `mode_team_roam_generic` 的两个英雄攻击点;**还没查的**:
   其余 mode 文件里的 `Action_AttackUnit(x, false)` / `Action_MoveToUnit`
   (`mode_defend_tower_*`、`mode_roam`、`mode_attack`、`mode_push_tower_*` 都有),
   以及 `ability_item_usage_generic.lua` 里的追击类命令。
   **做法**:两帧一组(下达帧 + 背书消失帧),在两帧上重建**整场 mode 竞价**证明
   「发起的 mode 已经不赢了」,然后断言命令类型。工具链已经现成,照抄
   `tests/test_roamreach_bounded_chase.lua`。
   **已知不通的路**:想在**命令已经在执行之后**回收它,唯一落点是每帧都跑的
   `ability_item_usage_generic.lua`(mode 之外唯一的全局 Think)——那是**另一个杠杆**,
   不要和「下达时带边界」合做。
1. ~~**l1xpsoak 重设计**~~ ~~**等总监重新入 test_set.md**~~ **已结案
   (2026-08-19T07:17Z):代码退役,滞回改挂新 gate `lanehyst`**。见 issue #28
   与 `iterations/reports/strategy/20260819T071719Z.md`。**不要再复活
   `l1xpsoak`**;若将来还想做"站住不动吃经验"的姿态,先读
   `state.json:l1xpsoak_RETIREMENT_20260819` 里的接缝分析(撤退 mode 没有
   `Think()`,移动权在引擎手里)。
   待办:`lanehyst` 入 `test_set.md` 需总监批准(已在 #28 申请)。
2. **−18 econ 残差归因**:两波 8/8 seed 稳定的 −18 gpm 残差,嫌疑:
   lf_rescue 位移税 / ownhalf+overchase 姿态成本 / tpcommit 残余 /
   全局"响应预算"缺失。用批测归档录像做行为差分,别再开专门批测。
3. **TeamBrain phase 2:响应预算** — 全队对同一事件的响应人数/位移上限
   (与 −18 残差假说同源,可能一并解决)。
4. **suptp × midtp 协同仲裁**(owner:suptp 需要和 midtp 协同)。
5. **`lf_rescue` 落点可达性(issue #37)—— 候选 3 已实现(gated `tpdead`),
   候选 1 与候选 2 **都已被真实帧证伪,不要再写****。见 2026-08-19T17:45Z 状态。
   **仍然待办的那一半**:`tpdead` 只回收已经浪费的 12s 承诺,**不阻止那次注定
   到不了的 TP**(卷轴 + 位移照花),而 #37 的经济账主要在后者。已知不通的路:
   落点距离门(候选 1,B 1579 比 C 1746 还近)、加宽生存窗口(候选 2,按到达窗口
   读会**否决唯一成功的那次救援**,C 258 ≥ 246)。**下一个可试方向**:
   (i) 把**回复量**建进生存判据(C 帧活下来靠的就是它);(ii) 触发处要求落点与
   友军**同侧/同一战场**,而不是「最近的存活塔」—— 但这要改
   `J.GetNearbyLocationToTp` 的调用方,它被整个 TP 家族共用,属于**共享消费路径**
   (总监 §0b 第九例),必须单独测。两条都建议**先要一次帧证据再动**。
   **不要动 `nVsMe < HP*0.70`**(总监钉死的边界)。
   原「规则细化」条目的其余部分(链式救援闸、响应者生存力检查)已由 #37 第 3 节
   核验为**有效**,不再是待办。
   另:`lf_rescue` 的 `DotaTime() < 8*60` 核心豁免按普通模式节奏写,Turbo 均局
   670s,只覆盖前 8 分钟(#37 第 4 节)。**静态审计完(2026-08-20T15:30Z)**:与 canonical
   `J.IsInLaningPhase()` 差集 = **t ∈ [480,600] 且 rescuer nw<8000**(Turbo 该窗口低净值核心是常态);
   替换会让一批低净值核心少发一批 rescue,方向单调向 #37 病灶靠近。候选 gate `lfcorelane`(armed 时把
   该行改成 `J.IsInLaningPhase()`)方案定,但**当前 fixture 一帧不覆盖差集**(`123012` 局所有可寻址帧
   rescuer 的 TP 都已消耗、gate 那一行结构不可达)⇒ **不 armed**;(a) 语料请求已路由 replay-check
   (GH #37 留言;§5.3 补决定帧时顺手多存一帧 subject=rescuer 的 fixture 回来后一次性入 test_set)。
6. **`pullcamp` 为什么也 13/13 SILENT**(接 issue #13,creeppull 死分支已解,
   见下面 2026-08-19T05:16Z 状态)。它**不是**死分支,静态查不出必然矛盾;
   最可疑的是**位置要求与均衡要求互相打架**:触发要求"我方兵线前沿越过中点
   +400 推向敌方"(辅助通常跟波在线上),同时要求"1400 内可见中立小兵 +
   1500 内有己方野点"(野点在身后靠塔一侧)。需要**帧证据**定性:找一帧
   :12 窗口内支援位的真实坐标 vs 己方拉野点坐标(向录像组要)。
7. **拉野节奏打磨**:当前 6:00 宵禁 + 和平期 veto;检索标准拉野时机
   (波次时间差、双拉条件)对齐实现。
8. **「最终出价可达性」全组普查**(2026-08-19T09:16Z 新增,由 #29/#31/`capmono`
   三连引出)。总监已把规矩立进 `test_set.md`:**凡是在注释里论证「这个值要压过
   X」的分支,验收必须断言最终出价(过完所有下游变换),不是 helper 返回值**。
   本组名下还没按这条规矩查过的 id:~~`tpcommit`~~(**2026-08-19T11:35Z 已查,
   发现域缺口 → gated `tpdying`,见 issue #35 与当前状态节**)、
   ~~`ownhalf`~~(**2026-08-19T15:34Z 已查:出价这一层 PASS —— 0.72 过完 cap 仍赢下
   竞价;但下游一层撞到动作缺陷 → gated `roamstale`,见 issue #39 与当前状态节**)、
   ~~`l1trade`~~(**2026-08-21T01:20Z 已查(GH #77):出价层 GH #31 早已钉过;本轮补上动作层 ——
   在真实帧上 armed 下 0.92 过完 cap、赢下每一个可驱动 mode、Think 只发一条打在自己目标上的
   `Action_AttackUnit`。**动作层干净**,本族第一次读出「出价 + 动作双双完好」。反倒读出两条别的:
   (i) 域内不可判的致命子句(见第 0f 条);(ii) #77 §4 的 ⭐ 钉帧不是一次触发。**),
   ~~`tpwatch`~~(**2026-08-20T01:45Z 已查:出价这一层送到了、也赢了,但它抬的是**
   **已经在跑的那个 mode(shipped retreat 已 0.75),而 retreat 没有 `Think()` ⇒ 结构上
   没有落点;判据本身还是滞后指标。建议出集,见 GH #52 与当前状态节。这是本族的新亚型:
   出价完好 + 赢下竞价 + 零效果**)、
   ~~`midtp`/`suptp`~~(**2026-08-19T19:30Z 查了一半**:触发闸门的可达性缺陷已定位并修复
   → gated `tparrive`,见 issue #44。**另一半 2026-08-21T03:19Z 查完**:
   ~~(ii) `ability_item_usage_generic.lua:5089+` 的「先命中先 return」guard 链 ——
   `lf_rescue` 排在 `midtp` 之前且两者可同帧成立,共用 `J.TryTakeTpResponseSlot()`
   那个 6 秒一人的全队配额~~ **(ii) 已证伪,结构性地不存在**:
   `J.GetNearbyLocationToTp` 是**全函数**(函数体零 `return nil`、零裸 `return`,
   末尾无条件 `return nFountain`)⇒ 两个调用方的 `if vRescueLoc ~= nil then` /
   `if vTpLoc ~= nil then`(5103/5127)**是死代码**,`lf_rescue` 取到票之后
   **结构上掉不出来**,`midtp` 不可能被自己人堵。四个真实帧 + 源码穷举双取证;
   顺带钉掉:两个 helper **各只有一个调用点**、取票在两处**都是 `and` 链最后一个合取**。
   **(i) 仍然成立但卡在语料**:`nItemSlot` 第 7 位才是 TP 槽,循环首个 desire>0 即 return
   ⇒ 当帧想用主物品栏任一件东西的 bot 根本不评估 `ConsiderItemDesire["item_tpscroll"]`。
   **不动它的理由**:抢跑物品多为一帧性(用掉进 cd),是「一帧延迟」还是「持续饿死」
   取决于 earlier slot **连续赢多少帧** —— 要数语料,照静态形状改共享消费路径正是 `lanefix` 入口。
   零支出计数请求已路由录像组(GH #37 留言)。
   **顺带澄清**:`J.LaneRegenItemToUse` 确实排在整个物品循环之前且 early-return,
   但挂在 `J.IsLaneFixOn('salve')` 上而 `lanefix` 不在 armed 集 ⇒ 当前波次惰性,已写成断言。
   见 `tests/test_tpresponse_quota_chain.lua` 与 `state.json:tpquota_NO_LEAK_20260821`)、
   `lf_rescue`/`teambrain`。
   **加一条做法(2026-08-19T15:34Z 立):出价断言通过之后不要停,再往下走一层断言
   动作** —— 总监 §0b 对动作类缺陷的推论(「断言动作真的达成了 helper 假设的那个状态」)
   本来就适用于每一条,而 `ownhalf` 正是「出价干净、动作全丢」的第一例。驱动方式已经
   现成:`tests/test_roamstale_collapse_action.lua` 用 `replay_fixture.record_actions`
   在真实帧上连跑两帧 `GetDesire()`+`Think()`,可直接照抄。
   **查 `tpcommit` 时补好的工具链让这件事对后面几条便宜了很多**:mock 的
   `BOT_MODE_DESIRE_*`/`BOT_ACTION_DESIRE_*` 现在带真实 0..1 值(此前是自动常量
   元表发的任意 id,`Defend.GetDefendDesire` 实测返回 1008/1009,跨模式比出价
   是在比垃圾),`bots/mode_defend_tower_*_generic.lua` 与
   `bots/mode_retreat_generic.lua` 现在可以直接 dofile 并在真实帧上驱动
   `GetDesire()`。新写 bid 测试不必再在文件里各自重定义常量。
   **`midtp`/`suptp` 的特殊情况(已查明,记在这里省得重查)**:它们的出价数值
   在物品链里是**惰性的** —— `ability_item_usage_generic.lua` 的物品循环只判
   `nItemDesire > 0`,从不跨物品比大小;真正的优先级是槽位顺序
   `{5,4,3,2,1,0,15,16}`,**TP 卷轴排最后**,任何当帧想用的其他物品都抢在响应 TP
   前面。所以这两条的「最终出价」问题不是数值问题,是**顺序/可达性**问题。已知的两类下游变换:模式文件里
   `GetDesire()` 对 `GetDesireHelper()` 的后处理(farm 的 0.45 cap、team_roam 的
   CapForLanePush、roshan 的 announce),以及「先命中先 return」的 guard 链
   (#29 已修 retreat 链,**TP 决策链 `ability_item_usage_generic.lua:5089+`
   还没查** —— `lf_rescue` 排在 `midtp` 前面,两者可同帧成立)。
   建议做法:一条一条来,每条配一个像 `tests/test_lanekill_bid_reachable.lua` /
   `tests/test_capmono_ceiling.lua` 那样直接驱动最终出价的测试。

## 当前状态(每次触发后更新)
- 2026-08-21T17:58Z:**接 GH #84 §5 的下一条**(上一轮定的默认取件 `item_purchase_generic:228`)。
  **`bots/` 一位没动,`tests/mock/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_gamemode_world_assertion.lua`(**24 例**,约 35 秒)。**两个交付。**
  **(一) 对 §5**:`228` 也做不了,**理由与前两条都不同 —— 它在 Turbo 里根本不跑**。
  门在 `GeneralPurchase()`(192-363),唯一调用点 1276 行是
  `if GetGameMode() == 23 then TurboModeGeneralPurchase() else GeneralPurchase() end`;
  真实 Turbo 走另一条腿 ⇒ 整函数 + `t3AlreadyDamaged` 四写两读(函数外 0 次,已断言)
  + `:272` 的留买活钱一起不跑,而 `TurboModeGeneralPurchase` 自己没有买活留钱(逐行断言)
  ⇒ **Turbo 的采购里根本不存在买活留钱**,原因在等级常数**上面 1048 行**。
  **(甲) 的 TEETH 判读据此更正**;**三条 TEETH 三个卡点**(`285` dumper 缺口 / `535` 语料缺口(**活的**)/
  `228` 不在 Turbo 里)。**下一轮默认取 `ability_item_usage_generic:5749`。**
  **(二) 第十五条世界断言**(细节见 backlog 第 0l 条):**fixture 世界同时是 Turbo 和不是 Turbo,
  分界线是拼写** —— 按名字 **96/96 TRUE**、按字面量 23 **0/96**,九处已发布比较站在错的一边。
  成因是 mock 的自动常量表把 `GAMEMODE_TURBO` 造成 1149,**并因此让 `bots/` 自带的两条自愈行
  永远不执行**。**这条是目前按结果算最大的一条**:全竞价 2016 格只动 21 格(全是对线出价),
  却**改变 18/96 帧的竞价赢家**,其中 **10 条换了赢家 mode**(7 → `defend_tower_bot`、3 → `retreat`)
  —— 第十四条只动 1 个。方向是机制:`mode_laning_generic:156` 的 `*1.65` 每帧都关,
  阶梯在 242-244 ⇒ **每个 fixture 都落在更早的台阶上,出价更高** ⇒ 全仓库竞价结论
  **在 22% 语料上系统偏向对线**。
  **本轮更正了本组上一轮自己发表的一个数**(第十四条自查里的 `retnear armed → laning 0.369`),
  已成双向断言;**另外 11 个做竞价级断言的文件本轮一个都没重跑**(0b/0c 一次一个)。
  **口径决定交总监**(`[harness]` **GH #93**):mock 该不该把 `GAMEMODE_*` 定成引擎真值。
  **本组建议:该** —— 与 #61/#81/#89/#91 不同,**这里没有任何东西需要建模**;代价已量:
  M12 一行让本文件 **8 条断言变红**;且必须与 `GAMEMODE_ARDM` 一起做,否则是半个修法。
  **验收**:luacheck **0 warnings**(`bots/` 零改动);全套 **1023 tests, 0 failures**(rebase 后最终门);新文件 **26 tests, 0 failures**;
  **14 条变异,逐条验「变异真的生效」+「回滚真的生效」**,其中 M8 是**假变异**(落到了另一个函数,
  两个采购函数含同一段魔晶代码)、M9 是上一轮 M7 形状的复发、**M4 翻出一个事实错误**
  (见 0l 末尾那条新做法)。
  **语料在本轮进行中长大了,棘轮当场响了**:rebase 时英雄组两枚 `lion_drain` fixture 落地(94 → 96),
  本文件三条写死分母的断言当场变红。**没有直接改分母**,而是在那两枚新帧上把整场竞价两种读法各跑一遍
  (`lion_drain_lethal` 两读法都 `retreat 0.750`;`lion_drain_survived` 两读法都 `defend_tower_bot 0.300`,
  **各 0 个格子动**)⇒ **分子全部未变,只有分母 94 → 96**,两枚新帧已按名字钉进用例。
  详见 `iterations/reports/strategy/20260821T175822Z.md`。
- 2026-08-21T15:46Z:**接 GH #84 §5 的下一条**(上一轮定的默认取件 `mode_farm_generic:535`)。
  **`bots/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_pingstamp_world_assertion.lua`(**18 例**;全套 **976 tests, 0 failures**)。
  **两个交付。**
  **(一) 对 §5**:`535` 也做不了 (乙) 的形状 —— **但这次卡点可以买到,语料请求是活的,不是撤回。**
  两半分开量:**情境这一半活的**(**872 存活英雄帧里 3 帧**满足内层 `if` **每一个**子句 ——
  `f_260819_142047` chaos_knight lvl4 / venomancer@158u / 2 队友;`f_260819_222559`
  dragon_knight lvl11 / lich@167u / 3 队友;同帧 juggernaut lvl11 / lich@55u / 3 队友 ⇒
  **这 3 帧上等级门是唯一挡在刷钱和 `Action_AttackUnit` 之间的东西**,(甲) 判的 TEETH 拿到实证);
  **外层 `runMode` 从不同时成立**(`X.ShouldRun ~= 0` 只有 **5/940**,交集空,两个方向都验)。
  **与 `285` 的区别要记住**:`285` 卡 **dumper 缺口**(再买也没有),`535` 卡**语料缺口**
  (`ShouldRun` 是当帧纯函数)。顺带钉住两条:`ShouldRun` 的 `<1000` 腿与块的 `>2200`
  **在触发帧上区间不交**;**fixture 只看得见 runMode 段的开口**(保持 `shouldRunTime` 秒不重问,
  返回值当时长用)⇒ **第三种 harness 盲区**,「5/940」不能读成游戏内频率。
  **(二) 第十四条世界断言**(细节见 backlog 第 0k 条):惰性时钟戳让第一次调用永远是自己的初始化调用 ⇒
  **farm / side_shop / 三条推塔出价在每个 fixture 上都被按在地板上**;farm **94/94 地板**,
  三条推塔 **68 → 36**(戳单独按住 32 条),**21 个 mode 的竞价赢家 94 帧里变 1 帧**
  (`defend_tower_bot 0.100` → **`push_tower_bot 0.920`**)。**出价动得多、结果动得少,两半都断言了。**
  **它还替 farm 藏了一次崩溃**(`GetRoshanDesire` 未打桩 ⇒ **第三个跑不起来的 mode 文件**),
  而崩溃点上面一行正是 (甲) 判 REDUNDANT 的 `369` —— **那条判读不可能从帧读**,已成断言。
  **两个口径决定交总监**(`[harness]` **GH #91**):loader 要不要替所有测试声明这条假设、要不要给
  `GetRoshanDesire` 打桩。本组建议照 GH #61 定案:**每个测试自己声明**(给 `rf` 加有名字的助手)。
  **验收**:luacheck **0 warnings**(bots/ 零改动);全套 **976 tests, 0 failures**;
  **16 条变异,14 条一次就红,2 条(M4/M7)先漏后修再红** —— 逐条跑,**每条都验了
  「变异真的生效」+「回滚真的生效」**(11:32Z 与 13:48Z 那两条方法学规则的合并用法)。
  详见 `iterations/reports/strategy/20260821T154643Z.md`。
- 2026-08-21T13:48Z:**认领 GH #84 §5 的下一条**(总监 13:02Z 裁定批准的排序:从 6 条 TEETH
  里挑一条做 (乙) 的完整形状,优先 `mode_farm_generic:285`,**但前置条件必须先满足** ——
  先要一帧「团战点在 2500 内且 subject 是核心」的实证)。
  **本轮把「等语料」变成「已测量」:那一帧不存在,而且买不到。**
  **`bots/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_activemode_world_assertion.lua`(**13 例**,929 → 942)。
  **第十三条世界断言**(细节见 backlog 第 0j 条):`GetActiveMode` 是 bot VM 状态、不是实体属性
  ⇒ 不在 `.dem` ⇒ 不在任何 fixture ⇒ mock 答 0,而 `BOT_MODE_*` 全是 ≥1001 的 auto-id ⇒
  **872 英雄帧 × 24 个 mode 名 × 210 个已发布比较行全 FALSE**;八条 J 谓词各 **0/872**。
  **两个方向相反地错**:脚本侧比较恒假,引擎侧过滤被 loader 静默丢掉(872/872 帧等长)⇒
  `J.IsInTeamFight` 在 **71/872** 帧读 TRUE。
  **对 #84 的交付**:`GetTeamFightLocation` 的空答案是 `Vector(0,0)`(**地图原点,不是 nil**)⇒
  6/188 团队帧非 nil、**6/6 在原点**,§5 要的 7 个「核心 + 2500 内」帧**全是幻影**,七行已逐条钉死。
  **语料请求撤回**(dumper 字段表已钉,不含 mode;供上它=建模)。⇒ **`285` 结构上做不了**,
  下一轮改取 `mode_farm_generic:535`(不读 mode、域可寻址),备选 `item_purchase_generic:228`。
  **另记一条不是 harness 假象的**:35 个消费方只测 `~= nil`,而 1500(不含自己)/1400(含自己)
  的半径错配在游戏里能把「团战在河道中心」发给所有读者 —— **本 harness 判不了**,
  记成候选杠杆 + 前置条件,不是本轮的改动。
  **验收**:luacheck **0 warnings**(bots/ 零改动);929 → 942;**九次变异全部按预期 FAIL**
  (逐条跑、每条验回滚)。**方法学补一条**:M8 第一版是**假变异**(把 `x = 99999` 插在 Lua 表
  真实 `x` 的**前面**,重复键后写的赢 ⇒ 什么都没动、测试全绿,差点记成 MISSED)⇒
  **「变异跑绿」在确认变异本身生效之前不算数**(与 11:32Z 那条「回滚没生效不算数」配套)。
  详见 `iterations/reports/strategy/20260821T134849Z.md`。
- 2026-08-21T11:32Z:**认领 GH #84 (甲)**(09:30Z 之后唯一的新 `[strategy]` issue,总监第三十次触发
  10:58Z 开)。它 §5 的第一步正好是本组要的形状:**零成本、纯桌面、一次一个杠杆**。
  **`bots/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_level_gate_census.lua`(**15 例**,914 → 929)。
  **先独立复现分母再分类**:22 处 / 通用 12 / N>=20 12 三个数逐个对上;语料侧自算
  94 fixture / 67 局 / 940 槽 ⇒ **level>=20 = 0、最高 19、>=18 只有 1**。
  **分类表(判据不是 AND/OR)**:去掉等级子句后这条分支的目的在 Turbo 还有没有活的定义域 ——
  `INERT`(等级测试**就是分支的主语**,「20 级英雄该干什么」⇒ 不可达不移除任何可观察行为,是死重不是缺陷)/
  `TEETH`(等级是**外挂在 10 级就成立的目的上的成熟度代理** ⇒ 常数是唯一把它关着的东西)/
  `REDUNDANT`(兄弟析取支用活谓词承载同一目的)。**合计 6 / 12 / 4,6 条 TEETH 全在通用文件。**
  **三条读出来的东西(都已成断言)**:
  (1) **牙齿与 AND/OR 不对齐** —— 3 合取(`item_purchase:228`、`mode_farm:535`、`aiug:5749`)
  + 3 析取(`mode_farm:285/392/506`);
  (2) **#84 §5 的筛子会把自己要找的东西筛掉** —— 「合取 ∧ N>=20」选出 4 行(`aiug:149/582`、
  `aba_site:760/824`)**且四行全是 INERT**,而 **6 条 TEETH 的 N 全部是 15 或 18**,包括 #84 自己
  点名的头号候选 `mode_farm:285`(N=18)⇒ 建议筛子改成「判读 = TEETH」;
  (3) **被点名为「无害析取」的 392/506,承重腿是空的** —— `J.IsLateGame()`(`jmz_func:4337`)
  在 Turbo 是 `DotaTime() > 18*60`,而**全档最晚一帧 t = 690.5s**,用真实帧跑**真 helper** 实测 false。
  **诚实边界**:批测局 ~640s 自终止 ⇒ 「无一帧过 18 分钟」既是 Turbo 的性质**也是 harness 的性质**
  (真实 Turbo 均局 ~20 分钟);**不是采样假象的是等级那一列**(0/940)。
  **反向读的两条**:`aba_site:760/824` 被 #84 点名「合取有牙齿」,本轮读 **INERT** —— 主语是 20 级英雄,
  上一行 `:757`(level>=10)与调用方 `:617-625` 的 `pos<=3` 兜底阶梯(支 <10/<15/**<20**)已经回答了
  20 级以下的世界;**但它确实够到焦点英雄**(`skeleton_king` 在 `:1001` 委派进 bristleback,
  `luna` 在 `:853` 委派进 huskar),两条委派边已成断言。
  **副产品(只记账、不动手,另一个杠杆)**:自动买活三条路径在 Turbo 全关,三个互相独立的原因 ——
  `:568` 的 `ancient:GetHealth() < 0.8`(**单位错配**,该开 `[bug]`)、`:582` 的等级 >24、
  `:578` 的 `nFullRespawnTime < 60` 早退(**推论不是测量**:`GetRespawnTime` 不在 dump 里,
  已如实标注为待游戏内核验)。
  **验收**:luacheck **0 warnings**(bots/ 零改动);测试 914 → 929。**十一次变异全部按预期 FAIL**。
  **另记一笔给全组的做法**:第一版把变异**叠**着跑(失败数 2→2→2→4→5→6→7 单调递增),
  原因是回滚那条 `git checkout -- <paths>` 里含一个**未跟踪**的新文件 ⇒ **整条命令失败、什么都没回滚**。
  ⇒ **「变异结果」在确认回滚生效之前不算数**;逐条重跑后 11/11 干净。
  详见 `iterations/reports/strategy/20260821T113239Z.md`。
- 2026-08-21T09:30Z:**认领 GH #74 §5**(07:40Z 之后唯一有新动静的 `[strategy]` issue:录像组 08:50Z
  第二十九次触发 + 总监 09:07Z 裁定)。§5 建议钉的两帧里,「必须 HOLD」那枚本组 08-20 已钉过;
  **「必须放行」那枚是新的,而且填的是这一族的结构性空洞**。
  **产出**:`tests/fixtures/f_260820_042612_axe_blink_init_573.lua`(`042612_slot1`,seed 887,
  armed=radiant,Axe 在 armed 侧,t=573.0 = `item_blink`@573.2 的**施法前最后一格**,#66 §0;
  带 `--roles`,生成器**没有**打 `ground_truth_ambiguous`/`recent_damage_ambiguous`);
  `tests/test_replay_260820_axe_blink_flee.lua` **8 → 14 例**。
  **`bots/` 一位没动,gate 逐字未改、仍未 armed,不申请入集(§AB.7 已定案)。**
  **第一件产出:FALSE 方向此前只有变异,现在有帧了。** 已钉的四帧里三枚 HOLD、一枚「放行」是**分支前置**
  放行的(es 621.0,1200 内 0 敌,门自己仍答 true —— #74 §3 自报);录像组 09:00Z 归档扫描的 5 次真实
  撤退腿又是 **5/5 HOLD**。⇒ 让 guard 说 false 此前只能**把真实帧血量改到 60%**。这一帧是真的:
  **33.3% 血**、**6.0s 回看窗内零英雄伤害**(伤害子句安静 ⇒ **HP 地板是唯一决定项**,已成断言:
  把同一帧抬到 75% 门就翻)、**juggernaut 在 648**(分支前置满足,门真的被问到)。
  **ground truth 说放行是对的**:进攻腿(cos(朝自家远古) **−0.999**,位移 569),落点距 jugg **183**,
  **+2.9s 把 46% 血的 jugg 打死**(`t=576.1 DEATH axe -> juggernaut`),全程没掉到 28% 以下,`died_after=36.9`。
  **第二件产出:把「hold 的代价」从三份报告里的散文变成仓库维护的一个数**(`[recorded]` 台账,跨 5 枚 fixture):
  **3 枚撤退腿 HOLD 帧 / 1 次 8s 内死亡 / 0 次可归因于 hold** —— 详见上面 backlog 第 0y 条(0y 的阻塞已解除)。
  **第三件:一条工具事实(登记,不动工具)** —— `make_fixture.py` 只收 `type == "DAMAGE"`,
  **整类丢掉 `CRITICAL_DAMAGE`**(158/322/325 三处),而录像组 09:00Z 的谓词是「DAMAGE + CRITICAL_DAMAGE」
  ⇒ **两个工具对同一个量定义不一致**。本轮能说清两半:(i) **布尔读数不受影响** —— 本局 6 条 crit
  **全部**有同瞬同 actor 的 `DAMAGE` 孪生行,`WasRecentlyDamagedBy*` 不会失明,**只有量级读数暴露**
  (本帧 `burst = 134` 而非 375,已写成 `[limitation]` 断言);(ii) 唯一一个干净测量
  (`lich t=413.1`:血 444→358 掉 **86**,而同瞬 `DAMAGE=79` / `CRITICAL_DAMAGE=109`)说
  **`DAMAGE` 才是实际落地伤害、crit 行是信息行** ⇒ **生成器的过滤大概率是对的,反而是
  「DAMAGE+CRITICAL」的谓词会重复计数**。n=1 干净样本 ⇒ **只登记不动手**(改工具会一次性移动全部
  fixture 的 burst,0h 同一条纪律),已在 #74 留言。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **908 → 914(+6)**。**九次变异全部按预期 FAIL**:M1 摘 HP 地板 /
  M2 地板 0.70→0.30 / M3 塞一条 `dt=1.0` 英雄伤害 / M5 把 jugg 推出 1200 / M6 burst 134→375 /
  M7 `died_after` 36.9→6.0 / M8 jugg 改满血 / M10 抹掉 es 614.9 的死亡 / M11 给 axe 529.6 编一个死亡。
  **M4(摘伤害子句)只红旧帧不红本帧 —— 不是漏网,那正是「HP 地板是唯一决定项」的另一种说法**,如实登记。
  **另记一笔给全组**:M3 第一版是**无效变异**(插入点落在 unit 表外面,成了 `units` 数组上的游离键,
  测试照样全绿)—— 改 fixture 做变异时 `}, },` 的双层收尾极易插错一层,**「变异没红」要先怀疑变异本身**。
  `state.json` 新增 `blinkflee_HP_FLOOR_FRAME_20260821`。
  未花 AWS 计费资源(只读 S3:1 个 `.dem` 9.0 MiB + 1 个 `.analysis.json` + 缓存命中的 dumper;
  未启动任何实例,未提批测请求)。详见 `iterations/reports/strategy/20260821T093000Z.md`。
- 2026-08-21T07:40Z:**没有可认领的新 `[strategy]` issue**(05:30Z 之后只有 `[hero] #54/#56`、
  `[bug] #78`、`[harness] #80/#75` 有新动静;`[strategy]` open 集最新留言仍是 03:23Z 的 #37,
  上一轮已判定不认领),照章程接 backlog **第 0c 条**,治它点名的下一枚:
  **`f_260820_102645_cm_es_reach`**(seed 906,armed=radiant,可归属)。
  **产出**:fixture 用 `make_fixture.py --roles` **重生成**(**逐字节只多了 `roles` 表** ——
  units / 38 座建筑 / 整个 `observed` 段 `burst={earthshaker:99}`、`died_after=106.9` 全部逐字相同,
  且**没有** `ground_truth_ambiguous`);`tests/test_replay_260820_cm_es_aftershock.lua` **24 → 27 例**
  (+3 RE-READ),`tests/test_fixture_roles.lua` **7 → 10 例**,棘轮 **7 → 6**。
  **bots/ 一位没动,不推 gate,不申请入集。**
  **重读结论:pin 成立,而且说得出为什么** —— `X.cm_IsRSafeToOpen` 与 `X.ConsiderR()`
  **各读 0 次位置**(两个入口都 hook;各配一条非空性断言,免得「零读取」= 「什么都没跑」)⇒
  两个消费方文件的 **48 条用例结构上**不可能被治疗动到(两文件通篇不出现 `IsCore`/`GetPosition`)。
  **世界确实动了,而且这次翻了**:五个队友动了三个(sk 2→3、sniper 3→**4**、viper 4→**2**),
  **核心/辅助划分翻了两个**(sniper 核心→辅助、viper 辅助→核心)。三次治疗三种结果
  (868 翻一个 / 885 全动零翻 / 906 翻两个)⇒ 已把这条对照写进 `test_fixture_roles.lua` 头部与断言。
  **唯一那次角色读取在英雄文件 dofile 的那一刻**:`Item.GetRoleItemsBuyList` → `aba_item:1600` →
  `Role.GetPosition`(全仓库唯一绕过 J 包装的调用点,上一轮量的),而**这一帧恰好不动** ——
  CM 是置换的**不动点**(槽位 5 = 抽签 5)⇒ **这枚 fixture 是上一轮 Axe 那条发现的 CONTROL**。
  机制照样活着(驱动真实 `hero_crystal_maiden.lua`:pos_5 13 件 blood_grenade 起手 /
  pos_1=2=3 13 件 mage_outfit→shadow_amulet→veil / **pos_4 只有 11 件** priest_outfit 起手)⇒
  **位置错一格换的是整套装,不是换顺序**。
  **本轮真正值钱的:第十二条世界断言,在地图另一边(详见 backlog 第 0h 条)** ——
  **`--roles` 结构上够不到敌人**,全语料 **93 fixture / 465 个敌方英雄 / 读到非 3 的 0 个**,
  `J.IsCore(敌人)` 恒 true。原因在 `aba_role.GetPosition` 的敌方分支覆盖掉 `assignedRole` 并
  `return 3`,而填缓存的 `UpdateEnemyHeroPositions()` **loader 一次都没调过**。
  估计器**现在跑得起来了**(2026-08-20 才接通 `GetUnitList(UNIT_LIST_ENEMY_HEROES)`),
  warm 一次答 bb 1 / zuus 3 / es 2 / jugg 5 / jakiro 4 —— 置换,**与抽签一致 0/5**;
  **不修**(会一次性移动全部 93 个 fixture),钉成全语料棘轮 + 源码钉子,决定权交总监(已开 `[harness]` **GH #81**)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **902 → 908(+6)**。**九次变异全部按预期 FAIL**(按 0g 纪律,
  新用例第一次跑就全绿 ⇒ 变异是硬前置):M1 摘 `roles` / M2 sniper 抽签 4→3 / M3 敌方分支改读
  `assignedRole` / M4 往 guard 里塞一次 `J.GetPosition` / M6 让 loader warm 估计器(三条同时红)/
  M7 扰动 `GetEnemyPosition` / M8 `pos_5` 别名到 `pos_3` / M9 出装 key 改走 J 包装 /
  M10 合并两个角色入口 / M11 把治好的 fixture 塞回债务清单(棘轮反向)。
  `state.json` 新增 `cmesreach_ROLE_HEAL_20260821`。
  未花 AWS 计费资源(只读 S3:1 个 `.dem` 8.7 MiB + 1 个 `.analysis.json` + 缓存命中的 dumper;
  未启动任何实例,未提批测请求)。详见 `iterations/reports/strategy/20260821T074000Z.md`。
- 2026-08-21T05:30Z:**没有可认领的新 `[strategy]` issue**(03:19Z 之后只有 `[bug] #78` 与
  `[harness] #75` 有新动静,`[strategy]` open 集 13 条**一条新留言都没有**),照章程接 backlog
  **第 0c 条**,治它自己点名的下一枚:**`f_260820_043124_axe_blink_kill`**(seed 885,可归属)。
  **产出**:fixture 用 `make_fixture.py --roles` **重生成**,`tests/test_replay_260820_axe_blink_kill.lua`
  **13 → 19 例**(+6 RE-READ),`tests/test_fixture_roles.lua` 棘轮 **8 → 7** + 头部补一条对照说明。
  **bots/ 一位没动,不推 gate,不申请入集。**
  **重读结论:pin 成立,而且这次说得出为什么** —— `J.ShouldHoldAxeBlinkForCall` 在这一帧上
  **问了 0 次位置**(已成断言),所以 13 条原用例**结构上**不可能被角色治疗动到;
  「它们全绿」第一次是一句有内容的话,而不是侥幸。
  **世界确实动了**:我方**五个队友全部**换读数(viper 1→2、**axe 2→3**、sniper 3→1、CM 4→5、ES 5→4),
  但**核心/辅助划分一位没翻**(`{viper,axe,sniper}` 两边都是核心)—— 这是**关于这一帧的测量**,
  上一轮 `defstale`(seed 868)同样的治疗**翻掉了一个核心**,已把这条对照写进 `test_fixture_roles.lua` 头部。
  **敌方抽签恰好是恒等置换**(已查,不是假设)。顺带补上**真实建筑血量**(38 座里 5 座不满血:
  0.943/0.572/0.179/0.149/**0.0**),此前每个 fixture 每座建筑都满血。
  **本轮真正值钱的:margin 在外面一层,而且正好是这一帧存在的理由。**
  `Item.GetRoleItemsBuyList` = `'pos_'..Role.GetPosition(bot)` ⇒ **角色决定整张出装表**,
  而这一帧是**全语料唯一一次 Axe 真的拿着跳刀**的帧(`axebuyblink` 的 (a) 证据帧)。
  驱动**真实的 `hero_axe.lua`**测出:抽签 **pos_3** = tank_outfit → **crimson_guard** → blade_mail →
  **blink(第 4)**;槽位 **pos_2**(= `pos_1` 表)= sven_outfit → blade_mail → **blink(第 3)**;
  armed 之后两个世界的 blink 前缀**合流**(都第 2),但**起手包仍分叉**(tank vs sven)。
  ⇒ **这枚 (a) 证据帧此前一直对着错的出装表读**,`axebuyblink` 在这个 Axe 身上要跨的沟
  **比记录里深一整件装备** ⇒ **加强** GH #56 的立论(已留言)。**本组不改 `hero_axe.lua`**(英雄组地盘)。
  **第二条产出**:`J.GetPosition`(包装)与 `Role.GetPosition`(模块)**不是同一个函数对象**,
  **nil 地板还是不同的数**(包装 2 / 模块 3);`aba_role` 之外**只有两个**调用点 ——
  `jmz_func:8070` 与 **`aba_item:1600`(出装表 key,唯一绕过包装的那个)**。**不是缺陷**
  (模块自带地板;强喂 nil 才会得到 `'pos_nil'` ⇒ `X.sBuyList = nil`,那是变异下的假设,如实登记),
  **危险在于两个地板都是天然的「顺手清理」目标,而其中一个决定每个英雄买什么**。
  ⇒ **给全组的做法更新:数角色读取次数必须同时 hook 两个入口**,只 hook `J.GetPosition`
  会漏掉出装那一路(`defstale` 那轮消费方是 `aba_defend`、走包装,**结论不受影响**)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动,收尾 git status 干净);
  `lua5.1 tests/run_tests.lua` **896 → 902(+6)**。**十次变异全部按预期 FAIL**(新用例第一次跑就全绿,
  按 0g 纪律变异是硬前置):M1 摘 `roles` / M2 角色 3→2 / M3 摘建筑血 / **M4 给 guard 塞一次
  `J.GetPosition` → 「零次读取」那条** / M5 包装地板 2→1 / M6 删模块地板 3 / M7 出装 key 改写 /
  M8 `pos_2` 改成 `pos_3` 别名 / M9 `axebuyblink` 只重排 `pos_1` / M10 加第三个 `Role.GetPosition` 调用点。
  `state.json` 新增 `axeblinkkill_ROLE_HEAL_20260821`。
  未花 AWS 计费资源(只读 S3:1 个 `.dem` 8.8 MiB + 1 个 `.analysis.json` + 缓存命中的 dumper;
  未启动任何实例,未提批测请求)。详见 `iterations/reports/strategy/20260821T053000Z.md`。
- 2026-08-21T03:19Z:**不认领 GH #77**(唯一有新动静的 `[strategy]` issue,录像组 02:36Z 的 `[bug] #78`
  零支出复读:头条 −17.0pp → **−17.5pp 判 P1 站住**,但**收回**「第一次越过噪声底」的强度措辞,
  承重指标从 DiD 换成 **ACTIVE 带 4/4 同号 SD 6.9 的 −15.7pp** + **内生 placebo 带**(修后反而更强
  no-op +6.1pp / 生效带 −19.7pp ⇒ 总监的「掩护假说」被否证)。它给本组的唯一动作项是「换 §4 举例帧」,
  那要扫语料,属录像组;排期决定权在总监)。照章程接 backlog **第 8 条**里 `midtp`/`suptp`
  **唯一没查过的那一半**(挂了很多轮;两个 id **都在 armed 集**,不需要新语料)。
  **产出**:`tests/test_tpresponse_quota_chain.lua` **10 例**。**bots/ 一位没动,不推 gate,不申请入集。**
  **头条是一条否定:怀疑的配额泄漏结构性地不存在。** `J.GetNearbyLocationToTp` 是**全函数**
  (函数体零 `return nil`、零裸 `return`,末尾无条件 `return nFountain`;`J.GetTeamFountain` 也不返 nil,
  真为 nil 是**抛错**不是返回 nil)⇒ 两个调用方的 `if vRescueLoc ~= nil then`(5103)/
  `if vTpLoc ~= nil then`(5127)**是死代码**,`lf_rescue` 取到全队票之后**结构上掉不出来**,
  「同帧把自己的 `midtp` 堵死」**不可能发生**。⇒ **backlog 第 8 条的 (ii) 作废。**
  两条独立取证都写成断言(单独一条都不够:读源码排除不了运行期抛错,四帧排除不了没走到的分支):
  源码穷举 + **四个真实帧**(GH #37 验收三帧 + `f_071423_sky_rescue`)实测均返回真实坐标。
  顺带钉掉:两个 helper **各只有一个调用点**(无「出价评估顺手吃票」)、取票在两处**都是 `and` 链
  最后一个合取**(无「取完票后面还有条件否决」)。
  **第二条产出(变异跑出来的,不是读出来的,已入 backlog 第 0g 条)**:配额台账 `tTpQuota.t`
  **双写**,重置分支与取票路径各一次,**每个单独看都是 dead store**(单删任一个,10 条断言逐位全绿);
  **两个都删** ⇒ 每次调用都重置 ⇒ **`TryTakeTpResponseSlot` 永远返回 true**,全队配额**静默变成无限**,
  fix B 要治的 COLLECTIVE TP 原样复发,**零报错零日志**。危险在于删「那句冗余赋值」**第一次对、第二次是灾难**,
  而第一次的安全恰是第二次的理由 ⇒ 钉成「两处都必须在」。**不改 bots/**:现行行为是对的,要防的是未来的"清理"。
  **仍然成立的那一半 (i)**:`nItemSlot` **第 7 位**才是 TP 槽、循环首个 desire>0 即 return
  ⇒ 当帧想用主物品栏任一件东西的 bot **根本不评估** `ConsiderItemDesire["item_tpscroll"]`
  (`lf_rescue`/`midtp`/`suptp` 一并跳过)。**不动它**:抢跑物品多为一帧性,是「一帧延迟」还是
  「持续饿死」取决于 earlier slot **连续赢多少帧** —— 要数语料,照静态形状改共享消费路径正是 `lanefix` 入口。
  零支出计数已路由录像组(GH #37 留言)。**顺带澄清**本组自己写过的一条担心:`J.LaneRegenItemToUse`
  确实排在整个物品循环之前且 early-return,但挂在 `J.IsLaneFixOn('salve')` 上、`lanefix` 不在 armed 集
  ⇒ 当前波次惰性,已写成断言(免得哪天 arm 它时没人意识到那同时是一次 TP 响应链改动)。
  **未验证边界(如实登记)**:`tTpQuota` 是否真是全队一份,本 harness 判不了(mock 每测新载一次
  jmz_func,每 bot 一份 VM 看起来完全一样);只有游戏内观察能定。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **886 → 896(+10)**。**11 次变异全部按预期 FAIL,其中 2 次抓出本轮
  自己写的空断言并当场重写** —— M6(删取票 stamp)全绿 ⇒ 翻出双写、重写 test 7;M7(取票后追加
  `and true`)全绿 ⇒ 发现只验了「前面有 `and`」没验「是最后一个」、重写 test 8。
  **⇒ 立一条本组纪律:凡「第一次跑就全绿」的用例,变异是硬前置,不是可选项。**
  其余:M1 塞 `return nil`/M2 破坏无条件尾/M3 改落点 guard/M4 两触发器间插 `return`/M5 窗口 6→2/
  M6b 单删重置 stamp/M6d 单删取票 stamp/M6c 两个都删(5、6、7 三条红)/M7b 加第三个消费方/
  M8 TP 槽挪到首位/M9 拿掉 regen gate。
  `state.json` 新增 `tpquota_NO_LEAK_20260821`。
  未花 AWS 钱(**未读 S3**、未启动任何计费资源、未提批测请求)。
  详见 `iterations/reports/strategy/20260821T031912Z.md`。
- 2026-08-21T01:20Z:**第四次有可认领的新 `[strategy]` issue**,认领 **GH #77**(录像组 00:53Z:
  `l1trade` 域内普攻率 −17.0pp、方向与设计相反,§4 点名一枚 ⭐ 钉帧)。按章程 backlog **第 8 条**
  把 `l1trade` 的**动作层**第一次驱到真实帧上(出价层 GH #31 钉过,动作层从来没人驱过)。
  **产出**:`tests/fixtures/f_260820_181711_wk_l1trade_333.lua`(s906/armed=radiant,`--roles`)+
  `tests/test_replay_260820_181711_wk_l1trade.lua` **12 例**。**bot Lua 一位没动,不推 gate,不申请入集。**
  **头号产出是一条否定:#77 §4 的 ⭐ 钉帧根本不是一次 `l1trade` 触发。** 每一条**能答**的子句都过
  (turbo/laning/IsCore/pos3/bBacked sniper 545u@0.547/2 敌<=800 jakiro 83 + jugg 539/self-risk **79 vs 526.5**/
  depth **−908** 与 **−435**(都在我方半场)/可攻击),**唯一挡住的是离线不可判的致命子句** ——
  `J.GetTotalEstimatedDamageToTarget(我方)` 在**每个 fixture 上恒为 0**(loader 只答**敌→subject**
  的 burst,#77 §2 的超集边界;已写成机制断言:授予这**一个** getter 即触发)。
  **ground truth 判死**:门槛 = jakiro **399**(fixture 无回血 ⇒ 已声明为**下界**);录像事件流实测
  t∈[333.5,337.5] 我方两名近处**英雄**打在 jakiro 身上 **44**(全是 sniper,**WK 0**;另有骷髅兵 82 +
  小兵 28 **不计入**,该 helper 只遍历英雄)⇒ 引擎估计要**高估 >9 倍**门才开。
  **⇒ WK 那 8 秒沉默不能记在 `l1trade` 头上**(逐帧核实:329.7 对 **juggernaut** 暴击普攻 124+68、
  332.5 对 juggernaut 放 hellfire_blast,此后到 343.1 只有 DoT)。**这不否定 §3 的聚合 −17.0pp**,
  只是缩小它可能来自哪。顺带:该 episode 的**目标归属**也偏了 —— WK 交战的是 **juggernaut(15% 血、
  被自己眩晕)**,不是检测器选中的 jakiro。
  **第二条产出:动作层干净。** 致命性以 labelled synthetic 授予后,armed 下 `GetDesire()` = **0.92**
  (GH #31 的 `bLaneKillCommit` cap 豁免**在真实帧上成立**,没被压回 0.72 悬崖)、**赢下每一个可驱动
  mode**(唯一非零对手 `mode_retreat_generic` **0.407**,已钉数值)、Think **只发一条
  `Action_AttackUnit(jakiro, false)`**;shipped bid 0 / 零动作;非 turbo 零。无 roamstale 族的病
  (不是上一帧的小兵、`targetUnit` 没被 leash/`X.CanBeAttacked` 清掉、动作旗标在位)。
  **⇒ #77 §3.2 的「一个攻击指令都没发」不是 `mode_team_roam_generic` 消费路径产的。**
  **说不了的那一半(§0d 口径,已点名断言)**:shipped 侧 WK 的驱动者是 `mode_laning_generic`,
  它在**任何 fixture 上都加载不了**(GH #61)⇒ 本帧能说「沉默不来自这里」,**说不了「来自哪里」**。
  一并点名断言不可驱动的:`mode_defend_tower_*` / `mode_push_tower_*` / `mode_rune_generic` /
  `mode_ward_generic`,以及 `mode_attack_generic` 不定义 `GetDesire`。
  **记账、不成 gate(见 backlog 新增第 0f 条)**:候选循环取「引擎列表里**第一个**过门的」而不是
  「**最好杀的**」—— 这一帧取 jakiro(门槛 399、满机动),放过同列表里 juggernaut(160 血 = 15%、
  被 WK 自己的眩晕定住、门槛只要 1/2.5)。域需要「两个都过门」的 burst 值,**只在 synthetic 下存在**
  ⇒ 沿用 `lfcorelane` 那条规矩,**无 (a) 帧就不 armed**。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **874 → 886(+12)**。**七次变异全部按预期 FAIL**:
  M1 摘 `IsSoakCandidate` → shipped 惰性 1;M2 摘该 helper 的 `IsModeTurbo` → 非 turbo 惰性 1;
  M3 深度闸方向对调 → 4;M4 拿掉 GH #31 cap 豁免 → armed 动作层 1(0.92→0.72);
  M5 Think 末支改 `Action_MoveToLocation` → 1;**M6 fixture 里 jakiro hp 399→99 → ground truth 2**
  (证明门槛读真实帧不是常量);**M7 jakiro 的 `observed.burst` 79→0 → self-risk 1**(证明读真 ground truth)。
  `state.json` 新增 `l1trade_STAR_FRAME_NOT_A_FIRING_20260821`;**GH #77 已留言**(三件:⭐ 帧别再被
  引用成「l1trade 干的」/ §3.2 的机制不在这条消费路径里、下一步看 `mode_laning_generic`(卡 #61)与
  英雄脚本 / 给 §7 bisect 的事前登记补充:消费路径已从嫌疑名单划掉,那条臂的读数更好归因)。
  未花 AWS 钱(只读 S3:缓存命中的 dumper + 1 个 `.dem` + 1 个 `.analysis.json`,未启动任何计费资源,
  未提批测请求)。详见 `iterations/reports/strategy/20260821T012000Z.md`。
- 2026-08-20T23:30Z:没有可认领的新 `[strategy]` issue(open 集与 21:30Z 逐条相同;总监 23:00Z/23:20Z
  两轮的产出是 §W 与 [harness] #75,没给本组新指令),照章程接 backlog **第 0c 条**,按它自己写的
  「一次一个、重生成、重读结论」挑 **`defstale` 那一对帧**(本组自己的 gate;消费方 `aba_defend`
  是全仓库角色分叉最密的文件;两局 `script_version = mirror:…:s868:*` **可归属**)。
  **产出**:两枚 fixture 用 `make_fixture.py --roles` **重生成**(soak seed 868),
  `tests/test_defstale_defend_bail.lua` **+4 例**(RE-READ 节)、`tests/test_fixture_roles.lua` **+2 例**。
  **bot Lua 一位没动。**
  **世界确实变了**:BAIL(drow)槽位 3 → **抽签 pos 1**(仍是核心,只有数字动);
  CONTROL(jakiro)槽位 3 → **抽签 pos 5**,**核心→辅助翻面**,且该帧**五个队友全部**换读数。
  顺带补上**真实建筑血量**(drow 自家上路一塔 **0.561**,此前每个 fixture 每座建筑都满血;
  `aba_defend` 的紧迫度乘数与「这一塔已丢」早退都是这个数的 remap)。
  **重读结论:pin 成立** —— 三个变体(只加 roles / 只加建筑血 / 两者)下 9 条原有用例全绿,
  三车道出价与动作**逐位相同**(BAIL 0.30×3,CONTROL 0.10×3)。
  **并且把「不是废话」写成了断言**:被驱动的帧**真的在读角色**(BAIL **15 次**、CONTROL **18 次**),
  且每次都被答以抽签值 —— 免得这条结论日后退化成「其实从来没问过」。
  **本轮真正值钱的:margin 只有一级。** `GetDefendDesireHelper` 的**第一个**角色分叉
  (`aba_defend.lua:922`)是**按位置取阈值的等级门**(pos 1/2 要 6 级、pos 3 要 5 级、pos 4/5 要 4 级)。
  drow 这帧 6 级:作为槽位 pos 3 超阈值一整级,作为抽签 pos 1 超阈值**零级**。**同帧反事实(测量,已入用例)**:
  pos1@6=**0.30**、pos3@6=**0.30**、pos3@5=**0.30**、**pos1@5=0.00(整条 defend 出价没了)**。
  ⇒ **「角色没改变结论」是关于 6 级这一帧的事实,不是关于这个门的事实。**
  **顺带补上第二层棘轮(此前完全没有)**:`test_fixture_roles.lua` 只棘轮了第一层(无 `player_id` ⇒
  全队 pos 1);**有 `player_id`、无 `roles`**(⇒ 每次 `GetPosition` 都是槽位,GH #57 47.3%)此前
  **一条棘轮都没有**。现为 `SLOT_DERIVED_ROLES`,治好 2 个后**剩 8 个**,双向棘轮。
  **并把锚点的说法改对**:`f_221200_od_roles.lua` 是角色契约的锚点,而它**自己就是槽位派生且永远治不好**
  —— `script_version` 是裸树 sha `829202a`(无 `:s<seed>:`),`positions_for_game` **拒绝**它;
  它的 `EXPECT`(`pos = team_slot + 1`)**正好是 loader 的无 roles 回退**。锚点仍证明名册/player_id 链
  (五人五个互不相同的位置、含已死者),**不证明**那五个数字是抽签角色。已单独钉成用例。
  **机制备忘**(省得重推):`X.ShufflePickOrder` 把 `sSelectList[i]` 与 `Role.RoleAssignment[team][i]`
  **一起换** ⇒(英雄, 角色)整体移动、**只有槽位在动**;loader 没有 shuffle 可重放,无 `roles` 时读的是
  **未打乱的恒等表**。
  **不推 gate、不改 bot Lua、不申请入集、不批量刷剩下 7 个**(治一帧可能翻掉它钉的结论,批量会淹掉翻面)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **868 → 874**。**六次变异全部按预期 FAIL**:
  M1 BAIL 退回槽位世界 → defstale 4 条 + 棘轮点名;M2 CONTROL 退回 → 2 条;M3 只摘建筑血 → 结构血量那条;
  **M4 `aba_defend:922` 阈值 6→7 → BAIL 出价 0.30 → 0**(独立佐证一级 margin);
  M5 删 `pos==1` 合取 → 角色读取次数 15→12;M6 阈值 6→1 → 5 级反事实塌掉。
  `state.json` 新增 `defstale_ROLE_REREAD_20260820`;GH #55 已留言。
  未花 AWS 钱(只读 S3:缓存命中的 dumper + 4 个 `.analysis.json` + 2 个 `.dem`,未启动任何计费资源,
  未提批测请求)。详见 `iterations/reports/strategy/20260820T233000Z.md`。
- 2026-08-20T21:30Z:**第三次有可认领的新 `[strategy]` issue**,认领 **GH #74 §1.5(3)**
  (录像组 20:49Z 上机前语料核验;总监 21:15Z 追加裁定 §10.1 已把它升格为指令:
  「**立刻做零支出的 fixture 对**,把 #71 的证据从『一局一个 Axe』扩到『两波两个英雄』,
  不依赖任何新波次」)。**#74 的两帧归属已独立复现**(自己从 `.dem` 读,不转述):
  施法 t 精确落在 615.2 / 621.3,自家远古坐标取自 buildings 流,几何与伤害账本全部吻合。
  **产出**:两枚真实帧 fixture ——
  `f_260820_162859_es_blink_flee_615`(决策帧 t=614.9,**#66 §0 施法前最后一帧**口径;
  ES 1528/1528=**100%**、viper**1091**在 1200 内、lookback 零英雄伤害;位移 1416、
  d(自家远古) 8583→7171 = **−1412 朝家** ⇒ **撤退腿**)与
  `f_260820_163429_es_blink_init_621`(t=621.0;**1200 内 0 敌**、1600 内 3 队友;
  d(自家远古) 13227→**13974 = +747 远离**、落进 viper 420/SK 548 ⇒ **进攻起手**);
  `tests/test_replay_260820_es_blink_flee.lua` **11 例**。**bot Lua 一位没动。**
  **本轮真正值钱的是一条关于本组自己这个门的负面结果:`blinkflee` 的 HOLD 集不同质。**
  三帧门读数**完全一样**(turbo+armed+HP≥70%+2s 内无英雄伤害 ⇒ HOLD),ground truth 却 2:1 劈开:
  axe 529.6 burst **{}** 活、axe 555.2 burst **{}** 活、**ES 614.9 viper 1175、+6.0s 死**。
  机制:ES 帧**第一发英雄伤害落在决策时刻之后 ~1.5s**,`WasRecentlyDamagedByAnyHero(2.0)` 是
  **回看窗**,对「1091 外还没开火的 viper」与「四周真没威胁」给出同一读数 ⇒ **§0b 老形状
  (判据是滞后指标),这次落在本组自己写的门上**。
  **对 #71 条件 (c) 的两半做的事不同**:「撤退闪现是 15s CD 误用」这半**被加强**
  (形状在第二个英雄、两局独立复现;且 ES **闪了也没跑掉** —— 朝家 1416 之后照样被 viper 打死,
  CD 什么都没买到);**「hold 的代价是零」这半在这一帧上不成立,以后不能再无条件写**。n=3,
  与录像组 #74 §2.4 自报 `liondrainstop` 反例同一种自我举报。
  **另钉一条**:PASS 帧上 `J.ShouldHoldBlinkFlee` **也返回 true** ⇒ **门分辨不了进攻起手和逃跑**;
  保下那次进攻闪现的是撤退分支**自己的前置** `#nInRangeEnemy >= 1`(该帧 0 敌)⇒ armed 与 shipped
  **逐位相同**。写成断言,免得把门不具备的分辨力记到它头上。
  **不收窄 gate**(失效模式 n=1,照一帧调阈值正是 `lanefix` −74.5/−88.7 的入口)、**不申请入集**
  (19:00Z 已 admit,无新 armed 语义)、**不提批测请求**(#74 已证 (a) 在当前种子结构买不到,0.0625 次/局)。
  **交出去的零支出活(合 §V.7 pre-flight)**:请录像组在**已付过钱**的语料上数一个数 ——
  「HOLD 合格帧之后 **8s 内 subject 死掉**」的比例;接近 0 ⇒ 可按现状 armed,可观 ⇒ armed 前必须
  加一条**逼近威胁**项。已留言 **GH #74** 与 **#71**。
  **世界断言合规**:#69 两帧生成器**均未**打 `ground_truth_ambiguous`/`recent_damage_ambiguous`
  ⇒ ground truth 可引用,并**写成断言**;#61 不读 lane front;#58 不消费 `GetTower`;两枚 fixture 均带 `--roles`。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **857 → 868**(+11)。**六次变异全部按预期 FAIL**:
  (a) 调用点摘掉 guard → wiring 钉子 1;(b) 删 `IsSoakCandidate` → gate-OFF 惰性 3;
  (c) 删 `IsModeTurbo` → 非 turbo 惰性 2;(d) HP 地板 0.70→1.01 → HOLD 类 5;
  (e) 反转 2.0s 伤害子句 → 7;(f) fixture `died_after` 6.0→nil → `[limitation]` 那条 1
  (证明它读真 ground truth,不是常量)。`state.json` 新增 `blinkflee_ES_PAIR_20260820`。
  未花 AWS 钱(只读 S3:缓存命中的 dumper + 2 个 `.dem` + 2 个 `.analysis.json`,未启动任何计费资源)。
  详见 `iterations/reports/strategy/20260820T213000Z.md`。
- 2026-08-20T19:25Z:没有可认领的新 `[strategy]` issue —— 唯一带新证据的 **GH #72**
  是录像检查组的 `capmono` 隔离核验(SILENT,不 promote,不构成有害证据 + 登记
  「行为通道检测器的经验零点 ≈ ±15pp/种子 SE 7.5」),决定权在总监(admit/reject/
  test_set),不是本组要写的 Lua 或测试。**#61 已在 17:00Z 由总监落地**
  (`git show 71b510c`:`rf.load` 显式 refuse `GetLaneFrontLocation`,6 个测试
  同步声明假设),所以照章程接 backlog **第 0z 条**「`DefendThink:1418`
  (代码飘动到 `1441`) 恒真否决,已发布未 gated 的动作类缺陷,lane front 一能用就是
  最值钱的下一个」。
  **产出**:**状态层钉子**——`tests/test_defnum_recent_hit_parity.lua` 的 MECHANISM
  循环末尾追加 `#ds.nInRangeAlly >= #ds.nInRangeEnemy` 断言,POKED/PAIRED/WD 三帧
  实证为 TRUE(第三条腿与 `defnum`(1219)/dead-code(1139)/`defstale`(1314)
  同源);加两条 [reverse] 源码钉子——(i) `#ds.nInRangeAlly >= #ds.nInRangeEnemy`
  子串必存;(ii) 用 `src:match` 捕获整行 if,断言 line 1441 **未 gated**
  (若哪天有人加了 `IsSoakCandidate(...)`,backlog 「已发布未 gated 的动作类缺陷」
  这条说法必须更新)。
  **动作层未钉,已如实登记**:三个 fixture 的 subject 都在离最远建筑 ~8k 处,
  `ds.distanceToLane[lane] >> 1600`,DefendThink 走 `dist > SEARCH_RANGE_DEFAULT * 1.7`
  的 elif 分支(`Action_MoveToLocation`),line 1441 的 `Action_AttackMove` 分支
  在这些 fixture 上结构不可达。**拒绝伪造 lane front 到 subject 附近来强开 dist<1600**
  ——那不是「declare an assumption」(per #61 discipline),那是模拟游戏世界。
  **(a) 语料请求已路由 replay-check(GH #62 追评)**:要一份 turbo 防守帧
  `subject.dist_to_defendLoc < 1600` + defend 赢下竞价 + 无更早 action 分支抢先 return
  (baseThreat/HG/enemies at hub/visible enemies/creeps/ShouldDefend+bld 全 miss),
  下一轮语料回来后一次性入 test_set + 决定候选杠杆(delete 死码 / `#pathEnemies`
  替换 / `#enemiesAtHub` 替换)。
  **不推 gate**(动作层未验收,单动 gate 违反本组「一次一个小杠杆 + 局部正确 ≠
  emergent 好」的教训);**不改 bot Lua**(行为一位没动);**不申请入 test_set**
  (第三条腿无 armed 语义)。
  **世界断言合规**:不新增读 `GetLaneFrontLocation` 的断言(继承 #61 landing 时既有
  [limitation] 测试的 explicit declare origin 记账);状态层结论只读
  `bot._defend.nInRangeEnemy`(helper 写入,不经 lane front);幻象污染(#69)不涉及
  (读的是 hero 集合不是伤害账本);结构不可寻址(第 6 条,#58)不涉及
  (不消费 `GetTower`)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bot 侧未动);
  `lua5.1 tests/run_tests.lua` **857/857 → 857/857**(不变;循环体追加 assert 不改
  例数;两处 [reverse] 是既有测试内的断言追加)。**三次变异全部按预期 FAIL**:
  (i) 强填 `ds.nInRangeEnemy` 为非空表 → MECHANISM 三帧同时 FAIL;
  (ii) 把 line 1441 方向对调 `#ds.nInRangeEnemy >= #ds.nInRangeAlly` → [reverse]
  shape pin FAIL;
  (iii) line 1441 前加 `IsSoakCandidate("defwin") and` → [reverse] ungated pin FAIL。
  `state.json` 新增 `defthink_third_leg_pin_20260820`;backlog 第 0z 条改写
  (landing 后:状态层钉住,动作层等 (a) 语料);GH #62 已追评(第三条腿状态层钉住
  + 动作层语料请求)。
  未花 AWS 钱(未启动任何计费资源,未提批测请求,未读 S3——本轮完全是本地
  Lua + 静态审计)。详见 `iterations/reports/strategy/20260820T192500Z.md`。
- 2026-08-20T17:15Z:**第二次有可认领的新 `[strategy]` issue**,认领 **GH #71**
  (英雄组 15:20Z 定位交接:`item_blink` 的**撤退分支**在 `bots/ability_item_usage_generic.lua:1503-1518`,
  两次把 15s CD 烧在 84%/81% HP 的空开跳,几何指纹 cos(→ancient)+0.997/+0.998,距离 1326/1162)。
  **头号产出**:gated **`blinkflee`** —— 新增 helper `J.ShouldHoldBlinkFlee(bot)` 挂进撤退分支
  内层 if 的**最后一条合取**;仅在 turbo + 'blinkflee' armed **且** HP ≥ 70% **且**
  `WasRecentlyDamagedByAnyHero(2.0) == false` 时**否决**该次撤退闪现,不能新增任何闪现。
  **两帧钉住(都从 20260820_043124_slot1,和 `f_260820_043124_axe_blink_kill.lua` 同一局)**:
  `f_260820_043124_axe_blink_flee_529` (t=529.6, HP 84.2%, SK@339 但攻击分支被 <500 硬门挡住,
  上次英雄伤害 3.2s 前, `WasRecentlyDamagedByAnyHero(2.0)=false`) —— armed 下 `ShouldHoldBlinkFlee=true`;
  `f_260820_043124_axe_blink_flee_555` (t=555.2, HP 81.3%, 800 内 0 队友, 仅一次 2.5s 前的 4 点近战小兵) ——
  armed 下 `ShouldHoldBlinkFlee=true`。
  **验收**:`tests/test_replay_260820_axe_blink_flee.lua` **8 例**(两帧 × {gate OFF/gate ON/非 turbo};
  HP 突变 <70% 释放;近 2s 有英雄伤害释放;源码探针断言 guard 在 IsRetreating 分支的 HIGH return 上)。
  **五次变异**:删修复导致钉帧 HOLD 断言坏 2、gate 常开(非 turbo 也 HOLD)导致「turbo 惰性」断言坏 1、
  HP 阈值改到 0.5 使 84%/81% 均放行 2 —— 全部按预期失败。**838/838(基线 830)+ luacheck 0 警告。**
  **不做 (b)/(c) 决断**:入集申请见 GH #71 留言;`blinkflee` gated **未 armed**,排期建议**混波带着走**
  (足迹极窄:两帧上都是 `IsRetreating + 单独 enemy in 1200` 的合取,与 `retnear`/`towerreach`/`defnum`
  /`aba_defend` 族的分支域完全不重叠 —— 是**物品使用**这条线,不是**mode 出价**这条线;
  A-B 归因不冲突)。
  **世界断言检查**:该分支**不读 `GetLaneFrontLocation`**(#61 无关);guard 只读 `bot.GetHealth`
  /`bot.GetMaxHealth`(dump 真值)与 `WasRecentlyDamagedByAnyHero`(fixture.recent_damage,#69 幻象
  污染只波及 `burst` / `died_after`,不波及本地帧 subject 自身的 `recent_damage` **且**两帧战场都无本体幻象)。
  `state.json` 新增 `blinkflee_20260820`;GH #71 已留言(条件 (a) 已 pin、入集申请)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 1 个 `.dem` + 1 个 `.analysis.json`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260820T171500Z.md`。
- 2026-08-20T15:30Z:没有可认领的新 `[strategy]` issue(open 集与 13:30Z 相同)。绕过所有基础设施墙
  (#61、缺基地攻防语料、幻象污染重读交 replay-check、AWS $-tier)⇒ 唯一可干的静态审计题目是 backlog
  **第 5 条**「`lf_rescue` 的 `DotaTime() < 8*60` 核心豁免按普通模式节奏写,独立排一轮」。
  **静态审计结论**:`bots/FunLib/jmz_func.lua:5862` 那一行的 hardcoded `8*60` 与 canonical
  `J.IsInLaningPhase()` 的 turbo hard floor **完全相同**,差别只在 **t ∈ [480, 600] 且 rescuer 净值 < 8000**
  一段窗口 —— canonical 下核心豁免继续生效(不救),shipped 下已经放开(可救)。Turbo 均局 670s,九分钟核心
  净值 < 8000 是常态(见 13:30Z §5 三帧 3068–3997)⇒ 替换会让一批低净值核心少发一批 rescue,**方向单调向
  #37 病灶靠近**(#37 第 3 节:20/50 attributed rescues 15s 内死了,rescue 已过多)。
  **不 push gate 的理由**:候选 `lfcorelane` 想 armed(turbo-only)把该行改成 `J.IsInLaningPhase()`,
  armed 效果集是 shipped 的父集,不新增动作。但**当前 fixture 语料一帧都不覆盖差集**:
  `f_260819_123012_dk_rescue_far` (t=568.4 subject=DK) DP 视角看,DP items 里已无 `item_tpscroll`
  (下一帧就是 `dp_landed_dead`)⇒ `GetRescueTpTarget(DP)` 早退于 line 5865 tp-check、gate 那一行**结构不可达**;
  `dp_landed_dead` (t=574.4) TP 已消耗;`lich_rescue_doomed` (t=201.3) lich 是辅助不触发核心豁免;
  `axe_rescue_ok` (t=145.4) t<480 是豁免生效帧,armed 与 shipped 逐位相同;`cm_chain_rescue` (t=256.0) 辅助+t<480 同样。
  ⇒ **无 (a) 帧就不 armed**(#28 类错误已被本组交过一次学费,不再重犯)。已把已知语料缺口
  「rescuer=核心 + TP 在身 + t∈[480,600] + nw<8000 的**决定帧**」交给 replay-check(有 S3 corpus + 原始
  timeline + subject 重投能力)。已在 **GH #37** 底下留言(§5.3 补 t=8–10min 决定帧时**顺手多存一帧
  subject=rescuer 的 fixture**,回来一次性入 test_set)。
  **不动代码,不改 test,不加 fixture**。luacheck bots game --formatter plain:0 警告(基线一致);
  lua5.1 tests/run_tests.lua:830 tests, 0 failures(基线一致,本轮未添加任何测试)。
  `state.json` 新增 `lfcorerescue_lane_gate_audit_20260820`(方向、可寻址帧域、语义 diff、不 armed 理由)。
  backlog 第 5 条改成「静态审计完 + gate 方案定 + (a) 语料请求已路由 replay-check」。
  未花 AWS 钱(未启动任何计费资源,未提批测请求)。详见 `iterations/reports/strategy/20260820T153000Z.md`。
- 2026-08-20T13:30Z:**第一次有可认领的新 `[strategy]` issue**,认领 **GH #68**
  (录像检查组 12:48Z 交的 `tpdying` 首次条件 (a) 核验,§5.3 点名要钉两帧)。
  **#61 仍未有着落**(第 0z 条继续卡着),但本轮结论**不骑它的桩**:所有判据都在不读 lane front 的路径上,
  出价层两侧用同一个 `GetLaneFrontLocation` 覆盖(与 `test_tpcommit_release_domain.lua` 同一套)。
  **头号产出是第十一条没人声明过的世界断言,并且已修**:**`.dem` 的战斗日志只认名字,不认实体**。
  快照流带 `idx`,所以生成器一直能干净地剔掉幻象;**战斗日志不能** —— 每条 `DAMAGE`/`DEATH` 行的
  `actor`/`target` 都是**裸英雄名**,幻象用它复制的那个英雄的名字 ⇒ `observed.burst`
  (每个 fixture 头部写着「damage each enemy hero **ACTUALLY** dealt to the subject」)
  **混着打在本体复制品身上的伤害**,`recent_damage` 反向同理。
  **实测**:`20260820_102030` t=639.5 tidehunter,名字口径 3s 实伤 **849**(lion 64/slardar 229/
  ogre 211/OD 329/necro 16),而本体实体 idx 1316 同这三秒 **1419 → 1452 → 1435 → 1423(它在回血)**
  —— 849 点全打在幻象 idx 2537 上(存活 613.5–640.5,离本体 **4000u**)。**GH #68 §1.3 正是把这个数
  读成「一秒吃 1063」**。影响面:loader 把它装成 `GetEstimatedDamageToTarget`,是
  **`J.WillAllySurviveTpWindow`(已发布未 gated)**、`J.IsIncomingBurstLethal`、`J.ShouldRetreatLaneBurst`
  的唯一输入;`recent_damage` 喂四个 `WasRecentlyDamagedBy*`(670 个调用点)。
  **修复是拒绝不是修补**(拆「本体那一份」要靠血量轨迹 = 建模,与 #61 同一条线):subject 或任何
  记账为打了它的英雄在窗口内有复制品存活 ⇒ withhold `burst`/`damage`/`died_after`,写
  `observed.ground_truth_ambiguous`;反向同判据写 `recent_damage_ambiguous`。接线前后 **787 → 806,无历史结论翻面**。
  **本轮缺陷本体:GH #68 的条件 (a) 站不住。** `tpdying` 的立论把 `J.IsInLaningPhase` 当时钟读,
  **它不是时钟**:turbo 下是 `t < 8*60` **或** `t < 10*60 且自己净值 < 8000` ⇒ **8:00–10:00 之间
  取决于响应者自己的钱包**,而九分钟时净值 < 8000 是常态。三帧实测:`103644` t=492.4 necro(3997)
  **对线期 true、`ShouldRetreatLaneBurst` true ⇒ shipped 自己就放掉了 pin,armed `tpdying` 逐位相同**;
  `102645` t=556.5 CM(3068)**对线期 true**;`102030` t=639.5 tide 才真的 false(前提在 10:00 后成立)。
  ⇒ **#68 §1.1 排除预判半边的那一步(「t=556>480 ⇒ 结构性 false」)在那帧上不成立**;独立第二条:
  实伤替身下该帧判据读 **false**(实伤 261 vs 血池 504),armed pin 仍是 0.85,出价逐位不变;
  ground truth 记下不当论据(CM `died_after = 39.0`,活下来了)。**不要再为 `tpdying` 买 (a) 语料。**
  **负结果:#68 §5.1 的阈值解耦本地验证不了** —— necro 帧严格比较本来就通过(1080 ≥ 965),
  tide 帧根本没有可归属 burst;而替身**忽略 `bCurrentlyAvailable`**,恰恰是 #68 §2.3 指认的机制
  ⇒ 与 `RetreatWhenTowerTargetedDesire` 同类「域有帧但断言不了」。**故本轮不交新 gate**,
  只把立论改对(`jmz_func.lua` **仅注释** + `state.json`),行为一位没动;
  也**没有把 `tpdying` 提出集**(它顺手去掉了「生存释放依赖响应者钱包」这件事,是同一缺陷更锋利的说法)。
  验收 `tests/test_fixture_illusion_ground_truth.lua` **10 例** + `tests/test_tpdying_laning_domain.lua` **9 例**。
  **五次变异:生成器发污染数据+摘 loader 闸门 2、生成器不标 `recent_damage_ambiguous` 2、
  净值软延长 8000→0 5、turbo 软结束 10min→8min 4、`tpdying` 释放改无条件 1。806/806(基线 787)+ luacheck 0 警告;rebase 到 main 后 830/830。**
  本轮开 **GH #69**(幻象污染,交总监定回读范围),已留言 **#68**(条件 (a) 未成立)与 **#35**(立论域修正)。
  `state.json` 新增 `fixture_illusion_ground_truth_20260820`、`tpdying_DOMAIN_CORRECTION_20260820`。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 4 个 `.dem` + 4 个 `.analysis.json`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T133000Z.md`。
- 2026-08-20T11:30Z:没有可认领的新 `[strategy]` issue(#65/#62/#58/#55/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #66/#63/#59/#56/#54 归英雄组,#64/#61/#60/#49/#46/#43/#42 归总监与批测台);**#61 总监 11:00Z 那轮仍未处理**
  (工作单元是 #64/#52),第 0z 条仍卡着,照章程接 **第 0b 条**,做它上一轮点名的
  「`X.ShouldRun` 的强制退却链 / `RetreatWhenTowerTargetedDesire`」。
  **本轮先量域再选杠杆**(5 局 turbo 录像、0.5s 间隔、**63,350 个存活英雄-帧**),四条点名候选里
  **三条当场出局**:`ShouldRun:774`(基地深处)**0 帧**、`ShouldRun:740`(6 级前深入)**0 帧**、
  `RetreatWhenTowerTargetedDesire` 域有 774 帧但**两个触发条件都读 dump 没有的引擎状态**
  (`GetAttackTarget` / `GetEstimatedDamageToTarget`)⇒ 真实帧上断言不了。
  **头号顺带产出是第十条没人声明过的世界断言,并且已修**:`tests/mock/bot_api.lua` 对任何
  `GetNearby*` 一律答 `{}`,而 loader **只覆盖过 `GetNearbyHeroes` 一个** ⇒
  **`bot:GetNearbyTowers`(183 个调用点)与 `bot:GetNearbyBarracks`(20 个)在每个 fixture 里都是空的**
  ——白话:**「这附近没有任何塔,也没有任何兵营,对任何人都是」**,而同一个 fixture 早就带着每座建筑的
  真实队伍/坐标/存活/血量(GH #58 那轮接的,只是过去只能从 `GetTower`/`UNIT_LIST_*_BUILDINGS` 拿)。
  光在 `mode_retreat_generic` 就掏空了 `C.allyTowers1200`/`C.enemyTowers1200`、**整个
  `RetreatWhenTowerTargetedDesire`**、`ShouldRun` 的四条分支。修复是 restoration(只给存活的、
  按距离升序、**不含前哨**,两条都写成断言),接线前后 **745/745,无历史结论翻面**。
  **仍故意没伪造**:建筑的攻击力/攻速不在 dump ⇒ `C.haveEnemyTowerThreat` 在 fixture 里永远为假
  (写成 `LIMITATION` 用例);`GetNearbyLaneCreeps`/`GetNearbyCreeps` 仍是 `{}`(注入小兵是建模)。
  **本轮缺陷本体(GH #67)**:「四周什么都没有 ⇒ −0.25」折扣**左半边标定、右半边不标定** ——
  `#nEnemyTowers` 是 `C.enemyTowers1200`,**1200 内有任何敌塔就一票否决**,而塔的攻击距离是 **700**。
  **作者原意有物证**:同一函数 490 行前算好了 `C.haveEnemyTowerThreat`(1200 内某敌塔 5s 打掉我一半血),
  **全仓库三写零读** ⇒ §0b 家族**新亚型:同一个问题在同一个函数里有两份实现,精确的那份没接线**。
  **交付 gated `towerreach`(turbo-only)**:armed 时否决只数**够得着我**的塔(**800**,是本文件自己
  表示「我正站在敌塔跟前」的那个数);armed 否决集是 shipped 的**子集** ⇒ 折扣只可能更常生效 ⇒
  **出价只降不升**,不新增动作、不碰别的出价。**不用 `haveEnemyTowerThreat` 当闸门**是因为塔的
  攻击力/攻速不在 dump,那样就没有真实帧能验收(局限已写成断言)。
  **域实测**:15,563 帧满足左半边(离自家泉水 >4000 且 3200 内无敌人),其中 **695 帧被塔否决**,
  **500 帧(71.9%)否决它的塔够不着**;抽 28 帧(每英雄间隔 ≥6s)成 25 个 fixture(3 个因无种子归属被拒,GH #57),
  驱动**全部 mode**:出价变 **23/25**,**竞价当选者变 2/25(8%)**,**其余 mode 一条都没动**;
  2 帧不变是结构性的(`X.ShouldRun` 先开火、在折扣行之上就 return 了 `ABSOLUTE*1.1`)。
  钉帧 `f_260820_102030_wk_tower_out_of_reach`(t=436,**Wraith King 焦点英雄**、284/1154=24.6%、8 级、
  离自家泉水 13,722、**3200 内 0 敌**、唯一敌塔在 **1090**):shipped **0.3836 赢**,armed **0.1336**
  ⇒ `mode_laning_generic` 0.369 赢。**GROUND TRUTH 记下不当论据**:它原地吃药回血到 46% 没被碰,
  之后北上被杀、复活、再死。对照帧 `f_260820_102030_wk_tower_in_reach`(同局同英雄 8.5s 后、塔在 **787**)
  **armed 逐位相同**;第二帧 `f_260820_103630_lina_tower_ring` 是足迹诚实的那一半(降 0.25,决定不变)。
  **不骑 #61 的桩**:先在已知敏感帧上证明探针是活的,再证明**本帧任何 mode 的出价都不读 lane front**。
  验收 `tests/test_towerreach_out_of_range_veto.lua` **12 例** + `tests/test_fixture_nearby_structures.lua` **6 例**。
  **五次变异:删修复 3、gate 常开 5、gate 忽略 turbo 1、reach 半径 800→1200 3、拆 loader 建筑查询 13
  (全部落在两个新文件内)。763/763(基线 745)+ luacheck 0 警告。**
  `state.json` 新增 `towerreach_20260820`、`fixture_nearby_structures_20260820`、`corpus_gap_no_base_assault_20260820`。
  **`towerreach` gated 未 armed**,入集申请见 **GH #67**;**排期建议:混波带着走**(足迹 0.83%、单调向下、
  与 `aba_defend` 族不重叠)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 5 个 `.dem` + 5 个 `.analysis.json`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T113000Z.md`。
- 2026-08-20T09:30Z:没有可认领的新 `[strategy]` issue(#62/#58/#55/#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #63/#59/#56/#54/#50 归英雄组,#61/#60/#49/#46/#43/#42 归总监与批测台);**#61 总监 09:00Z 明确说本轮没处理、仍归他们**,
  所以第 0z 条仍卡着,照章程接 **第 0b 条**,按它点名的「**挑一个已发布未 gated 的 last-seen 消费方先做**」,
  选 `mode_retreat_generic.lua:493-508` 的「last-seen 补数」。
  **头号发现是第九条没人声明过的世界断言,并且已修**:`tests/mock/replay_fixture.lua` 的 `GetUnitList`
  只回答 `ENEMY_HEROES`/`ALLIED_HEROES`,其余落 `{}` ⇒ **`GetUnitList(UNIT_LIST_ALL)` 在每个 fixture 里都是空的**
  —— 不是「没有小兵」,**连英雄都没有**。白话:**「这个世界里,任何地方都没有任何单位」**。
  `bots/` 下精确 **11 个**调用点,两个分量极重:**`mode_retreat_generic.buildContext` 的两张英雄表都从它来**
  (⇒ 每帧 `#nAllyHeroes`/`#nEnemyHeroes` 都是 0,退却出价整段「我是不是被人数压制」**拿 0 和 0 比**)、
  **`J.WeAreStronger(bot, r)`**(⇒ 每个半径**空队伍对空队伍**)。修复是 restoration(英雄位置是 dump 真值),
  **含自己**,接线前后 **714/714,无历史结论翻面**。**故意没伪造并写成断言**:小兵/召唤物/建筑仍不在这张表里
  (建筑不注入是因为唯一消费方要 `GetAttackDamage()*GetAttackSpeed()`,dump 不带)。已在 **GH #61** 留言。
  **顺带发现、没修**:`mode_rune_generic:487`(`GetRuneSpawnLocation` nil)与 `mode_secret_shop_generic:63`
  (`GetCourierState` nil)**在任何 fixture 上都跑不起来**,而**仓库里每一个竞价级测试都用 `pcall` 悄悄吞掉了它们**
  (含本组的 `test_tpwatch_channel_bid.lua`)⇒ 过去每条「谁赢下这一帧」都默认排除了这两个 mode 却没说;
  本轮验收改成**点名断言**,口径写成「在跑得起来的 mode 里」。归总监(与 #61 同类口径问题)。
  **本轮缺陷本体(GH #65)**:退却出价里**做比较的两边不是同一次测量** —— 两张英雄表与 `bWeAreStronger`
  都在 **1600**,而 last-seen 补数按 **3200** 取并**覆盖**敌人计数(`if unseenCount > #nEnemyHeroes then ...`),
  于是 `敌 - 友 > 0`(每多一个 +0.1875)与 `not stronger and 敌 >= 友`(+0.25)**左边 3200、右边 1600**。
  **r=3200 是 r=1600 的四倍面积** ⇒ 偏向「被压制」是**几何造成的**:**站在我 1700 外的队友抵不掉 3100 外的敌人**;
  3200 还超出自己白天视野 1800 ⇒ 宽计数在 1800 外加进来的每个人都是**队友**看见的(离队友近、不是离我近)。
  **交付 gated `retnear`(turbo-only)**:armed 时**可能替换 nearby 计数的那个数按 1600 取**;宽计数照旧计算、
  照旧喂下面那条「四周什么都没有就 −0.25」(那条本来就要宽地平线)⇒ **只动一个杠杆**,且**只可能压低或维持**出价。
  **没走的路**:把队友那边放宽到 3200(`nAllyNearbyCount` 还管着 Oracle/Dazzle/Satanic/Slark 那块折扣,一动就是好几个杠杆)。
  **域实测**:六局 43,256 英雄-帧(视野按各队自己的视野源**建模**,`.dem` 无逐队雾位图 GH #27,按模型报):
  宽计数覆盖近计数 **7,908 帧(18.3%)**,退却出价变化 **6,556 帧(15.2%)**(0.25:4892 / 0.4375:748 / 0.1875:736 /
  0.625:102 / ≥0.8125:29),抽 40 帧驱动**全部 22 个 mode**,**竞价当选者变 4 帧(10%)**。
  钉帧 `f_260820_043637_axe_ring_alone`(t=641.4,axe **89% 血**、**1600 内既无队友也无敌人**、三敌在
  **2974/3086/3172**):shipped **0.6904 赢**,armed **0.0654** ⇒ **`mode_laning_generic` 0.369 赢**,其余 mode 逐位不变;
  **GROUND TRUTH 记下不当论据**:它往回走后 **t=655–675+ 站在原地不动、97% 血、零受伤**。
  对照帧 `f_260820_043637_axe_ring_close`(同局同英雄同 89% 血、敌人在 188/741 即 1600 内)**armed 逐位相同**;
  第二帧 `f_260820_043140_luna_ring_bid` 是**足迹诚实的那一半**:0.777 → 0.339 但**退却仍然赢**(出价低 ≠ 决定变)。
  **本轮的正面结果:这条不骑在 #61 的桩上** —— 三个不同非原点 lane front 跑变异,结论与两个退却出价**逐位不变**
  (退却 mode 不读 lane front),而变异**是活的**(把 `mode_defend_tower_top_generic` 从 0.1275 挪走)。**已写成断言。**
  验收 `tests/test_retnear_radius_parity.lua` **11 例** + `tests/test_fixture_unit_list_all.lua` **4 例**。
  **五次变异:删修复 3、gate 常开 5、gate 忽略 turbo 1、拆 `UNIT_LIST_ALL` 接线 9、窄计数不经 gate 5。
  729/729(基线 714)+ luacheck 0 警告。** `state.json` 新增 `retnear_20260820` 与 `fixture_unitlist_all_20260820`。
  **`retnear` gated 未 armed**,入集申请见 **GH #65**;**排期建议:混波带着走**(足迹窄、方向单调,
  且与 `defclose`/`defstale` 的 `aba_defend` 族不重叠,同波不污染归因)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 6 个 `.dem` + 6 个 `.analysis.json`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T093000Z.md`。
- 2026-08-20T07:30Z:没有可认领的新 `[strategy]` issue(#58/#55/#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #59/#56/#54/#50 归英雄组,#60/#49/#43/#46/#42 归总监与批测台),接 backlog **第 0b 条**,
  做上一轮点名的「`GetDefendDesireHelper` 下半段没人在真实帧上看过的那几条」里的一条。
  **头号发现是第七条没人声明过的世界断言,而且是迄今最宽的一条(GH #61)**:
  `tests/mock/replay_fixture.lua` **从来没有接过 `GetLaneFrontLocation`** ⇒ `bot_api.lua:285` 的桩生效,
  **任何 team、任何 lane、任何 frontOffset 一律 (0,0,0)**。白话:**「两队的前线,在三条路上,都在河道正中」**。
  `bots/` 下 **125 个调用点**读它;在 `aba_defend` 里它让 `ds.defendLoc` = 原点、
  `ds.distanceToLane[lane]` = 「我离河道多远」——**三条路同一个数**,「我离这条路近不近」结构上分不出三条路——
  而这个数正是 `:1102` 提前 return 与 `:1156` 的 `dist > 4000` 衰减的判据。
  实测(钉帧 viper):`distanceToLane` 三路都是 **2040**,真实的「viper 到自家上路一塔」是 **8084**。
  **故意没有伪造它**:从 creep 流(每 3s 采样、无路别、无存活位)重建前线是**建模**不是还原 ground truth,
  `frontOffset` 更无从还原 —— 与前面几次 loader 修复不是同一类东西,上报交总监定夺。
  **它翻掉了什么(实测)**:把桩挪离原点,**上一轮 `defclose` 的 3 条用例当场 FAIL** ⇒
  `defclose` 的「最终出价 / 竞价从 laning 翻成 defend_tower_mid」这一层**不是桩无关的**
  (机制层与 2883 帧域实测**完全不受影响**)。已在 **GH #58** 如实留言。
  **本轮的缺陷本体(GH #62)**:`ds.nInRangeEnemy` 被赋值的**下一句**就是
  `if #ds.nInRangeEnemy > 0 ... return VeryLow` ⇒ **整个下半段它恒为空**,而下面有三个消费方照读不误:
  `:1139`(`0 > n`,**整块死代码**)、`:1196`(`0 >= n`,**读的是「我 1600 内有没有队友」**,
  不是「我是不是被压制」,且触发时我 1600 内一个敌人都没有)、`DefendThink:1418`
  (`n >= 0`,**恒真** ⇒ 作者写的「被压制就别攻击移动进 hub」这条否决**近乎死掉**,**已发布未 gated**)。
  §0b 家族**新亚型:使比较失效的是上游一个提前 return 把一侧钉成常数**,分支语义在该处**无法表达**。
  **顺带加强了 #55**:`defstale` 的 `#pathEnemies > #ds.nInRangeEnemy` 右边恒为 0 ⇒ 那条闸门就是
  **「5s 内挨过英雄打 + 1600 内有任何 last-seen 敌人 ⇒ 退向泉水并作废该帧其余 defend 分支」**,
  比原来写的「和自己的旧拷贝比大小」**更强更简单**(利好 promote 判断)。已留言。
  **交付 gated `defnum`(turbo-only,纯移除)**:只动 `:1196`,移除
  `math.min(nDefendDesire, BotActionDesire.Low)`;armed **只可能抬高出价**,不新增动作、不碰别的出价;TS 源同步。
  **先做了然后被自己实测否掉的版本(负结果)**:把比较改指到函数自己 80 行前算好的 hub 计数
  (`#lEnemies`/`nEffAllies`)——域内 **541/549 触发 vs shipped 308/549**,
  会把一次意外变成**系统性的认输规则**(两个敌人站塔边就放弃这座塔)。测试里有反向断言钉住它不许进树。
  **方向依据 (c)**:那个 `min` 只在衰减前出价 > 0.625 时才生效 ⇒ 经血量 remap 意味着
  **血量接近满 + 引擎自认这条路急需防守**,恰恰是值得去的防守,而 0.25 在竞价里几乎必输;
  让上一行的 `* 0.4` 按比例衰减比一票否决好。
  钉帧 `f_260820_043120_viper_defend_poked`(t=398.5,viper **92.4% 血**、0.7s 前被 ember 打过、
  **1600 内 0 敌 0 友**、自家还站着的上路一塔 1200 内 **3 个敌人**;**GROUND TRUTH 记下但不当论据**:
  它当时在中路对线补兵、之后留在原地打小兵血还在涨,**shipped 的 laning 与它实际做的事一致**);
  对照帧 `f_260820_043120_viper_defend_paired`(同局同英雄、1600 内有队友 ⇒ armed **逐位相同**);
  第二帧 `f_260820_043524_wd_defend_alone`(闸门跑到、cap 生效、armed 抬了出价,**而出价仍小到赢不了任何东西**)。
  **足迹与「为什么本轮不申请入集」**:这条分支出来的出价**按构造 ≤ 0.4**(上一行 `* 0.4`),打不过 laning 的 0.446;
  26 个抽样域内帧跑全部 22 个 mode 的真 `GetDesire()`:8 帧出价变、**3 帧竞价当选者变**(且只在 `GetDefendLaneDesire == 1.0`),
  **但那 3 帧全是「离塔 7–8k、离原点只有 ~2k」** ⇒ **翻面骑在 #61 的桩上,不算数**。
  test_set.md §8「必须断言最终出价」在这个世界里**满足不了**(不是满足了但结果不好),
  故 **`defnum` gated 未 armed、本轮不申请入集**,等 #61 有着落再申请。
  验收 `tests/test_defnum_recent_hit_parity.lua` **11 例**(前提全断言、机制断言、退化断言、单调性断言、
  移除的正是 `Low`、三个对照组、两条源码级反向断言、**把局限写成断言**的 `[limitation]` 用例)。
  **四次变异:gate 永远打不开恰好 3、gate 常开恰好 3、拆 recent-damage 接线本文件 2 条前提、
  lane front 挪离原点本文件 4 条 + `defclose` 3 条。682/682(基线 671)+ luacheck 0 警告。**
  `state.json` 新增 `defnum_20260820` 与 `fixture_lanefront_gap_20260820`。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 7 个 `.dem` + 10 个 `.analysis.json`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260820T073000Z.md`。
- 2026-08-20T05:30Z:没有可认领的新 `[strategy]` issue(#55/#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #56/#54/#50 归英雄组,其余归总监与批测台),接 backlog **第 0b 条**,按上一轮点名做 **`aba_defend`
  的「我在不在挨打」guard 群(939)**。**结果绕到更下面一层**:939 那一族根本没被任何 fixture 跑到过。
  **又一条没人声明过的世界断言(第六条):结构不可寻址。** loader 此前把 `GetTower(team, i)` 按
  **存活塔的位置**寻址(对「循环 i=0..10 再归约」的读者够用,GH #37 只需要这个),`GetBarracks` 是
  `nil`,`GetAncient` 给**两边**都发一个位于**地图原点**的 4500 血单位;而 mock 把未覆盖的 ALL_CAPS
  解析成哨兵整数 ⇒ **只问一个具名槽位**的读者 `GetTower(team, TOWER_MID_1)` 在**每个 fixture 里**
  都拿 nil。`GetFurthestBuildingOnLaneHelper` 正是这样的读者,而 `GetDefendDesireHelper` 紧接着
  `if not IsValidBuildingTarget(furthestBuilding) then return None end` ⇒ **每个 fixture 每条路的防守
  出价都只来自那七个提前 return,`GetDefendDesireHelper` 的整个下半段结构上不可达**(`ShouldDefend`、
  `capBoost`/`baseFloor`、panic 地板、`recentlyHit` 衰减、`ConsiderPingedDefend`、tier/血量 remap)。
  白话:**「这支队伍在任何一条路上都没有建筑,两家遗迹叠在河道里」**。修复:槽位**从几何推导**
  (不写死坐标)且在**全量建筑集**上推导(掉塔不会重新编号幸存者);真实 `TOWER_*`/`BARRACKS_*` 整数;
  阵亡槽位仍返回 nil;`GetAncient` 发各队真实遗迹;建筑补 `OriginalGet*`(`J.GetHP` 对己方读未 hook
  的取值器,此前 nil 崩)与**真实血量分数**(生成器新增 `hp`,`aba_defend` 读它两次)。
  **翻掉了本组自己上一轮的结论(如实撤回)**:`defstale` 钉的那帧
  (`f_260819_223607_drow_defend_bail` t=330.4)原断言「defend 0.30 赢下竞价」只在没有建筑的世界成立
  (那里 `mode_laning_generic` 出价 **0**、push 恒 0.05);接上之后**同一帧 laning 0.446 > defend 0.30
  ⇒ laning 赢,`DefendThink` 很可能根本没跑**。与该文件早已记着的 ground truth 自洽(那个 drow 留下来
  **补兵**=对线行为)。用例改名 `WITHDRAWN` 并断言新数字;03:36Z 那轮的域实测(32/45、1/45)是**上界
  不是测量**。已在 **GH #55** 留言:gate 不撤,但**条件 (a) 现在缺证据**,请重排。
  **头号产出 gated `defclose`(turbo-only)**:`aba_defend.GetClosestAllyPos` —— 每一条「这几个位置里
  只有最近的那个可以守这座建筑」规则的仲裁器 —— 把列表当 1-based 扫(TS 源 `j = 1..length` 读
  `tPosList[j]`,tstl 忠实译成 `tPosList[j+1]`)⇒ **每张列表的第一个角色从来不参与比较**,而
  `bestPos or tPosList[1]` 的兜底返回的**正是那个没被比较过的角色**。`{4,5}` 只可能答 5(**不看距离**;
  没有存活 5 号时答 4,同样不看距离)、`{2,3}` 只可能答 3(兜底 2)、`{2,3,4,5}` **永远不可能答 2**
  ⇒ **只要队里还有一个存活的 3/4/5 号,挨过打的 1 号和 2 号就被禁止防守任何建筑**。距离比较对每张
  列表的第一个角色是**惰性的**,tie-break 退化成比角色编号。**域实测(角色用 GH #57 的 seed 抽签
  真值)**:六局录像 **2883** 个「自家塔还在 + 1600 内有敌方英雄」的建筑-帧,shipped 与真正最近者
  不同 **{4,5} 32.8% / {2,3} 59.8% / {2,3,4,5} 37.6%**;五个调用点全在 `aba_defend`。
  钉帧 `f_260820_043140_wd_defend_token`(t=297.5:**满血 4 号 witch_doctor 站在自家 99% 血中路一塔
  915 外**,塔 1600 内恰好 1 敌,wd 自己 1600 内 0 敌所以 helper 真走到 `ShouldDefend`;它是**全队离
  那座塔最近的,近四倍**。shipped 经 `{4,5}` 把令牌发给 3981 外的 5 号;3 号**已阵亡** ⇒ `{2,3}`
  一个候选都找不到 ⇒ 兜底点名 **6996 外的 2 号**,全队最远的人)。**最终出价**:lane desire 0 时
  中路 0.100 → **0.250**(shouldDef 地板);0.30 时 0.363 → **0.474**,赢家从 `laning`(0.446)翻成
  **`defend_tower_mid`**;**0.50/0.70 时 shipped 赢的是 `defend_tower_BOT`**,armed 选**塔上有敌人、
  英雄就站在旁边**的中路。对照帧 `f_260820_043710_lich_defend_pos5`(4 号 lich 1118,5 号真的更近 800)
  armed 在四个取值上**逐位 no-op** ⇒ 钉的是「最近者赢」不是「4 号总赢」。ground truth 记下来但**不当
  论据**:那个 wd 离开塔走到地图右下角,t=334 杀掉 vengeful_spirit、t=368 阵亡;它丢下的塔 t=599.5 被拆。
  **必须挑明:不单调** —— 纠错不是旋钮,相对 shipped **既可能增加也可能移除**一个防守者。
  **本轮自曝并已重做**:总监 GH #57 在本轮进行中落地(位置来自**种子抽签**,不是 `team_slot%5+1`,
  吻合率 47.3%),而本组第一版钉帧与第一版域实测**都是按槽位算的** —— 第一版钉的
  `f_260820_043637_viper_defend_token`(已删)按槽位说 viper 是 4 号,**抽签真值是 2 号**,而 2 号本来
  就能过 `ShouldDefend` ⇒ **那帧根本没有缺陷**。**在进 main 之前发现并重做**:交出**第二条 mock
  保真度修复** —— `make_fixture.py --roles <analysis.json>` 经 `seed_draft.py` 由种子推出抽签位置
  (英雄名 canon 化,匹配不全**报错拒绝出半张表**),loader 写 `bot.assignedRole`;没有该字段的
  fixture 逐字节不变 ⇒ **没有历史结论翻面**,但**仓库里现存每个 fixture 的角色都还是槽位派生的**
  (本轮六局实测吻合 23/60 = 38%),凡是在 fixture 里 fork 在 `GetPosition` 上的断言只有 ~40% 把握
  描述了它来自的那局 —— **已进 backlog 第 0c 条**。域实测用真值重算后**数字更大**(32.8/59.8/37.6,
  槽位口径是 35.5/47.4/20.3)。
  验收 `tests/test_defclose_defender_arbitration.lua` **11 例**(前提全断言、机制断言、最终出价层
  断言并重建整场竞价、守错路断言、对照帧四个取值逐位相同、非 turbo 对照、id 隔离、两条源码级反向
  断言;局限明写:`GetDefendLaneDesire` 是引擎状态、`.dem` 不带(GH #27),所以**扫**而不假装知道)。
  **四次变异:删修复恰好 4、gate 常开恰好 5、让 loader 忽略抽签角色恰好 7、拆塔槽位接线恰好 3
  (其余 647 不动)。658/658(基线 647)+ luacheck 0 警告。** `state.json` 新增
  `fixture_structures_20260820` 与 `defclose_20260820`。**`defclose` gated 未 armed**,入集申请见
  **GH #58**;**排期建议:单独占一条臂**(足迹宽且不可分离),且**不要与 `defstale` 同波**。
  **故意没做**:`aba_defend:939` 本身与 panic 地板被 `recentlyHit*0.4` 乘掉的顺序缺陷 —— 机制已确认,
  但**本轮六局里离任一遗迹最近的敌人是 4925 码**(批测局在基地攻防之前就自终止),取不到实证帧。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 6 个 `.dem` + 6 个 `.analysis.json`,未启动任何计费资源),
  未提批测请求。
  详见 `iterations/reports/strategy/20260820T053000Z.md`。
- 2026-08-20T03:36Z:没有可认领的新 `[strategy]` issue(#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #54/#53/#51/#50 归英雄组与总监),接 backlog **第 0b 条**,按上一轮点名的下一批候选做
  **`aba_defend` 的「我在不在挨打」guard 群**。**主动放弃 830**(它整条分支靠
  `jmz.GetPosition`,而 GH #53 已证明 fixture 世界全队 pos 都是 1),选 **1253**
  (`DefendThink` 的动作类闸门,**已发布未 gated**)。
  **又一条没人声明过的世界断言(第五条)**:`bot_api.lua:278` 把 `GetHeroLastSeenInfo` 桩成 `{}`,
  **同时** loader 的 `GetTeamPlayers` **无视 team 参数**两边都发己方下标 ⇒ 所有读者的
  `for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) ... info[1]` 循环体**结构上不可达**
  ⇒ **每个 fixture、每一帧 `J.GetLastSeenEnemiesNearLoc` 恒返回空列表**(白话:「谁也没见过任何
  敌人,在任何地方」)。可达面 `GetHeroLastSeenInfo` **28** 个调用点 + `J.GetLastSeenEnemiesNearLoc`
  **11** 个,横跨 `aba_defend`(防守出价 / `GetThreatenedLane` / `ShouldDefend` 人头 / `DefendThink`
  路况)、`aba_push`、`jmz_func`、`utils`、`ability_item_usage_generic`、`mode_retreat_generic` 等。
  修复:己方那一半由总监同期 GH **#53** 的 roster 修复接管(真实 `player_id`);本轮补**敌方**
  (有 `player_id` 用真值,否则自己的 id 段,必然互斥,**只发给存活单位**),
  `GetHeroLastSeenInfo(id)` 发**真实帧坐标 + `time_since_seen = 0`**(没 fixture 带视野,GH #27;
  将来有 `seen_by` 则看不见的给 **999** = 用不了的记忆,**不编陈旧坐标**)。
  **顺带第二个缺口**:`TEAM_RADIANT/TEAM_DIRE` 此前是**自动哨兵整数**,而 `GetTeam()` 发真值 2/3
  ⇒ 每处 `Team == TEAM_DIRE` 恒假 ⇒ **`J.GetTeamFountain` 把天辉泉水发给夜魇英雄**,fixture 里
  每一个「向自家泉水后退」的落点都指着地图反角。补 2/3/4。**两条修复在当前语料上都是加法**:
  **没有任何已钉住的结论翻面**(rebase 前 605/605 → 605/605;合到 GH #53 之上后 610 → **625**)(但今后关于 last-seen / 泉水方向的断言
  必须晚于本次修复才算数)。
  **接上之后一条已发布未 gated 的判据当场翻面。** `DefendThink` 的「别走进火里」闸门
  (`#pathEnemies > #ds.nInRangeEnemy`)**两边是同一个查询**
  `GetLastSeenEnemiesNearLoc(botLocation, 1600)`:左边按 500ms 分桶,右边写在
  `GetDefendDesireHelper` **最底部、7 条提前 return 之下**,而其中一条
  (`#closeEnemiesDefend > 0 and #closeAlliesDefend >= #closeEnemiesDefend`)的触发条件**恰好**
  就是 `DefendThink` 会跑的那种帧(900 内正在打架),且 `bot._defend` **从不复位**。
  ⇒ **这条比较只可能被新旧差买到**,一旦为真就 `return`,把该帧其余所有分支作废。
  §0b 家族,**亚型新**:陈旧的不是句柄而是**计数**,且是**和自己的旧拷贝**比大小 ——
  分支写下来的语义**根本无法表达**。
  钉帧 `f_260819_223607_drow_defend_bail`(t=330.4,drow **609/780=78%**,自家 56% 血上路一塔
  **929** 外,3.8s 前被 ogre 打过,1600 内**恰好 1 个**敌人):shipped 出
  **`Action_MoveToLocation` 向泉水 641**(唯一动作);**GROUND TRUTH:它留下来了 —— t=332.6 补兵、
  t=336.9 拿 120 经验、t=338.0–339.9 对 ogre 打出 254,42.5 秒后才死**。当帧**全部脚本 mode**
  竞价 defend **0.30 赢**,所以 Think 真的会跑。对照帧 `f_260819_222526_jakiro_defend_fresh`
  (900 内 2 敌 1 友 ⇒ helper 走到底部写下活的 2)闸门**诚实为假**,两个世界逐位相同。
  **域实测(不是猜)**:三局录像里「5s 内挨英雄打 + 距自家建筑 1600 内 + 1600 内有敌人」的
  英雄-帧共 **1437**;抽 45 帧驱动真代码,闸门**条件为真 32/45(71%)**(27 次是 `nInRangeEnemy`
  仍为 0),**但 defend 赢下脚本竞价只有 1/45**(挨打时 retreat 通常 0.5–1.0 压过它);另 70 帧
  随机样本里 defend 赢 26 次、**没有一次闸门为真**。**真实缺陷,足迹很窄**(且是下界,引擎自带
  mode 拿不到,GH #27)。
  改动:gated **`defstale`**(turbo-only,**纯移除**),`bots/FunLib/aba_defend.lua` +
  **TS 源同步**;armed **只可能移除**那一条 `Action_MoveToLocation`+`return`,不新增动作、
  不改任何出价。**故意没做的那一半**:把 PATH 那边改指到 `ds.defendLoc`(helper 顶部就刷新)
  才是作者注释的意思 —— **下一个杠杆**,等 `defstale` 测出中性或更好再在干净基线上加。
  验收 `tests/test_fixture_last_seen.lua` **6 例** + `tests/test_defstale_defend_bail.lua` **9 例**
  (动作断言全部驱动真的 `aba_defend`:一帧内先跑三条 lane 出价再跑 `DefendThink`;前提全断言、
  机制断言、重建整场脚本竞价证可达并把 GH #27 局限写进测试、非 turbo 对照、对照帧逐位相同、
  两条反向断言)。**四次变异:删修复恰好 2、gate 常开恰好 3、拆 last-seen 接线恰好 8(其余 617
  一条不动)、`TEAM_DIRE` 退回哨兵恰好 1。625/625(基线 610)+ luacheck 0 警告。**
  `state.json` 新增 `fixture_last_seen_20260820` 与 `defstale_20260820`。
  **`defstale` gated 未 armed**,入集申请见 **GH #55**;**排期建议:不要给它单独一条臂**
  (足迹窄,浪费),混波带着走或与将来的「意图修复」一起测。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 3 个 `.dem`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T033630Z.md`。
- 2026-08-20T01:45Z:没有可认领的新 `[strategy]` issue(#45/#44/#41/#37/#35/#28/#26 全是本组
  遗留,#50/#51 归英雄组与总监),接 backlog **第 0b 条**,按它点名的最高优先级做 **`tpwatch`**。
  **本轮 `bots/`、`game/` 零改动**(`git status bots game` 空,无新 gate,未提批测请求),
  产出是**一条 mock 保真度修复 + 一条负结果 + 一条出集建议(GH #52)**。
  **又一条没人声明过的世界断言**:`tests/mock/bot_api.lua` 对未覆盖的 `Is*/Has*/Can*/`**`Was*`**
  一律答 false ⇒ **每个 fixture 里每个单位 `WasRecentlyDamagedBy*` 恒 false**,而 `bots/` 下有
  **670 个调用点**读这一族(AnyHero 527)。与 §F 的 `GetTower`/`GetIncomingTrackingProjectiles`、
  上一轮的 `HasModifier` 同类。`observed.damage` **代替不了**:它向**后**看(ground truth),
  这一族向**前**看(bot 在 t 已知的事)。修复:`make_fixture.py` 逐单位输出 `recent_damage`
  (`dt`= t 之**前**的秒数、`kind`=hero/tower/creep/other、`actor` 用**快照名**避开
  `queenofpain` canon 坑、丢自伤)+ 顶层 `recent_window`(默认 6.0s);`replay_fixture.lua`
  **只在该块存在时**装那四个读法 ⇒ **老 fixture 逐字节不变**(有回归护栏)。顺带补两个 mock
  全局(都是新可达之后才发作):`GetIncomingTeleports`(列表;`mode_laning_generic` 在任何
  「最近挨过打」的帧上**硬崩**)、`GetShopLocation`(`mode_secret_shop_generic` 文件作用域就读,
  不接则整个 mode 加载不了)。
  **`tpwatch` 判据本体第一次跑完,结论是负的。** 钉两帧(同一局同一主角,**都取自候选侧**,
  该局 stamp 含 `tpwatch` 且 juggernaut team 2 = radiant ⇒ **armed**):
  `f_260819_222030_jugg_tp_start`(t=437.1,读条 0.1s,733/1154)与
  `f_260819_222030_jugg_tp_eaten`(t=439.5,读条 2.5s,313/1155,**剩 0.5s**)。
  **GROUND TRUTH:读条 t=440.0 完好落地,他又活了 103.5 秒** —— 扛完读条就是这帧的正确决定。
  **缺陷是 §0b 出价类的新亚型:出价完好、赢下竞价、却什么都没改变,因为它抬的是已经在跑的那个
  mode。** 重建当帧**全部 22 个 mode 文件**:shipped `mode_retreat_generic` **0.75**(已 promote
  的反越塔 guard,同一条链里就在 `tpwatch` 下面六行)已经赢,次高 `mode_laning_generic` **0.446**;
  armed 只把 0.75 抬到 **0.9**,重新选举当选者 ⇒ 没有 mode 变化 ⇒ 引擎不重新下令;而
  `mode_retreat_generic` **只有 `GetDesire()`、没有 `Think()`**,那 +0.15 结构上没有落点。
  **判据本身还是滞后指标**:11 局里 8 次满足其伤害阈值的读条,判据**最早只在落地前 1.2s** 成立
  (jugg 1.2 / DK 1.0 / sniper 0.9 / centaur 0.5,另 3 次只在死或落地那一瞬),1 次从未成立;
  **armed 侧有真实窗口的 2 次读条 100% 跑完**,没有一次被放弃 —— 与机制分析互相印证。
  **本轮不写 gated 修复**:接缝错(抬出价 ≠ 下指令)+ 判据错(滞后),不是差一个闸门;且回收
  已下达的命令按 backlog 第 0 条**只能落在 `ability_item_usage_generic`,是另一个杠杆**。
  验收 `tests/test_fixture_recent_damage.lua` **6 例** + `tests/test_tpwatch_channel_bid.lua`
  **7 例**(**所有 desire 驱动真的 mode 文件 `GetDesire()`**;前提全断言、guard 链走到 261 行
  逐条断言、全 22 个 mode 竞价两个世界各跑一遍、`mode_retreat_generic` 仍无 `Think()` 的**源码级
  反向断言**、回归护栏、两条反向断言)。**两次变异:拆 loader 接线恰好 6 条 FAIL(其余 588 条
  一条不动)、让读法忽略 interval 恰好 3 条 FAIL。594/594(基线 581)+ luacheck 0 警告。**
  `state.json` 新增 `fixture_recent_damage_20260820`。**建议见 GH #52:把 `tpwatch` 移出 armed
  测试集**(真实帧上可证明 inert,留在集里只会稀释同波其它 id 的归因)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 11 个 `.dem` + 6 个 `.analysis.json`,未启动任何
  计费资源),未提批测请求。详见 `iterations/reports/strategy/20260820T014500Z.md`。
- 2026-08-19T23:25Z:没有可认领的新 `[strategy]` issue(#45/#44/#35 在等总监批入集,
  #37 剩下那一半明确要求先要帧证据),接 backlog **第 0 条**「命令的边界」普查。
  **本轮零行为改动**(`git status bots game` 空,无新 gate,未提批测请求),
  产出是**普查结论 + 让普查可执行的工具链 + 一条负结果 + 一条 bug 上报**。
  **普查枚举做完了,范围收窄**:`mode_defend_tower_*`/`mode_attack`/`mode_push_tower_*`
  根本不含连续型单位命令;outpost 打的是静止建筑;team_roam:569 是非英雄目标。
  **只剩 `mode_roam_generic` 九处**(642–871),形状与 `roamreach` 逐条同构且**更确定**
  ——授权是**会到点消失的 modifier 计时器**,命令却是连续的,释放只住在 `Think` 里。
  **但这九处一条都没法在真实帧上验收**,原因就是本轮真正的发现:
  **`tests/mock/bot_api.lua` 对未覆盖的 `Is*/Has*/Can*` 答 false ⇒ repo 里
  每一个 fixture、每一个英雄、每一帧 `HasModifier(任何名字)==false`、`NumModifiers()==0`。**
  这是一条没人声明过的世界断言(没人被缠绕/晕/沉默/变羊/在读 TP/带任何 buff),
  与 §F 记的 `GetTower`、`GetIncomingTrackingProjectiles` **同一类**。两个静默后果:
  (1) 整段已发布分支结构上不可达 —— 上述九处、`item_tpscroll` 开头那张十条否决表,
  以及 **`J.ShouldAbandonTpChannel`(本组 gated id `tpwatch`,在 eligible 集内)第一行
  就是 `HasModifier('modifier_teleporting')` ⇒ 它的逻辑本体从来没有在任何真实帧上
  跑过一行**;(2) 测试可以断言错的东西还全绿(本轮那一帧的主角**其实被缠绕**,
  旧世界把他呈现成可自由走动)。
  修复:`make_fixture.py` 用 `MODIFIER_ADD/REMOVE` 配对重建 t 时刻仍生效的 modifier
  (`name/remaining/elapsed/stacks`),`replay_fixture.lua` 接上五个引擎读法;
  **没有该字段的老 fixture 逐字节不变**(有回归护栏)。`stacks` 数的是**日志事件条数**、
  不是引擎计数器(combat log 的 stack 数值语义未定),**暂不可用来钉
  `J.GetModifierCount(...) >= N`**(注释已写死)。
  钉帧 `f_260819_223607_sniper_rooted`(`20260819_223607_slot1` @ t=563.5),同一帧
  **同时真实带**控制(Frostbite 2.0s)、增益(MoM berserk 5.0s)、读条(drow
  `modifier_teleporting` 1.8s,565.3 无干扰落地)。
  **头号产出之二是负结果**:本局仅有的两次 MoM **都不支持** `roamreach` 那种伤害 ——
  窗口 1 buff 到期后那 4 秒**打死了 CM**(+554 金 +922 经验),且开头 3 秒是被
  Frostbite 缠住(「站着不动」不是陈旧命令的证据);窗口 2 是刚复活在泉水开 MoM、
  6 秒内 1600 无敌人(**物品使用**问题,归英雄组)。**照这帧写修复就是照误读写修复**,
  故本轮不写 gated 修复。
  验收 `tests/test_fixture_modifiers.lua` **11 例**:前提全断言;**缺口断言用已发布未
  gated 的消费方** `J.CanBeAttacked`(本帧 false,**只摘掉 Frostbite** 其余逐位不变则
  翻 true);`tpwatch` 可达性用「只有越过第一行才会写的 `tpChannelStartHealth` 戳」证明,
  且本帧正确答案 false **是因为对的理由**;单位隔离 / 多一格索引扫描 / 老 fixture 回归
  护栏 / 两条反向断言。**两次变异:拆 loader 接线恰好 8 条 FAIL,让生成器不再输出恰好
  9 条 FAIL。556/556(基线 545)+ luacheck 0 警告。** `state.json` 新增
  `fixture_modifiers_20260819`。
  **顺带发现一个未修的 bug(已开 `[bug]` issue)**:`J.CanBreakTeleport`
  (`jmz_func.lua:4418`)调用**不存在的** `J.GetCastPoint`(邻居叫 `GetCastDelay`),
  目标真带 `modifier_teleporting` 就崩;从没人发现是因为**没有 fixture 造得出这个
  modifier**,且它目前**零调用者**。归总监,本轮不动。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 2 个 `.dem`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T232500Z.md`。
- 2026-08-19T21:30Z:认领 **GH #45**(同时是总监 `test_set.md` §J.4 ⑥ 点名归口本组的
  钉帧任务)。钉了两帧(**同一局同一个响应者**,都从 `.dem` 独立重建过):
  `f_260819_181742_ss_chase_start`(t=312.5,**命令被下达**,gap 805)与
  `f_260819_181742_ss_chase_stalled`(t=318.5,**6 秒后没有任何东西还在为它背书**,
  gap 760)。事件层 ground truth 比 issue 更硬:**t=305–333 之间该英雄对英雄的伤害
  事件与施法事件都是 0**,第一次施法是 t=333.3 打一只小兵(已放弃追击之后),DK 从
  23% 回到 42%;Centaur 全程在旁(656u→218u),是 **2 打 1 追残血却零输出**。
  **机制被证明,同时证伪了 #45 §3 的猜想。** 链条:(1) **`ownhalf` 且只有 `ownhalf`**
  (逐个 id 单独 armed 试过)在 t=312.5 打开 `J.ShouldPunishDive`,team_roam 出价
  **0.72** 并赢下竞价(laning 0.446,其余全 0);(2) 它的 `Think` 下的是
  `Action_AttackUnit(target, false)` —— **连续型**命令,而当帧 gap 805 **超过该英雄
  全部触及范围**(普攻 400 / Ether 500 / Shackles 400 / Hex 550);(3) t=318.5
  **一条分支都不成立、出价 0**,另一个 mode 赢 ⇒ 引擎**不再调用 team_roam 的 `Think`**,
  而这个 mode 唯一自带的释放(>1800 leash)就住在 `Think` 里 ⇒ 命令**既无背书也无可达
  释放**却仍在执行。**一帧成立的 collapse 分支买到一次横穿地图的追击。**
  §0b 家族的**动作类**变体,亚型新:**出价与动作在各自那一帧都对,缺的是动作在出价停止
  之后的边界**。证伪的是 #45 §3 前半句(「分支持续出价 + 某个力往回拉」)——**分支 6 秒内
  就停了,追击照旧**,不需要任何回拉力解释那个 644–870u 的环。
  与 `roamstale` 的关系:这是它的**送达**那一半(shipped 侧陈句柄恰好吞掉这条命令,
  总监 §J.4 ③),**不是 fixture 能证的**,如实标注为臂 A/B 差分推断。
  改动:gated `roamreach`(turbo-only,**只改 `mode_team_roam_generic.lua`**):
  新 `_roamreach_ThreatReach`(普攻距离或**已学会且当前可施放**技能的施法距离取大)+
  `_roamreach_BoundedChase`,armed 时**英雄**目标超出触及范围就下
  `Action_MoveToLocation(目标位置)`——**有限**命令,挂在 `Think` 的两个英雄攻击点。
  **不改任何一处出价**(断言 armed 后仍 0.72);触及范围内的目标、**任何非英雄目标**
  逐字节不变;**单独 armed 是逐位 no-op**(断言)⇒ **不可单拎成一臂**,同
  `tpdying`/`tpdead` 的排期形状。**没有动 `ownhalf`/`roamstale`/`ShouldPunishDive`
  一个字节。** 验收 `tests/test_roamreach_bounded_chase.lua` **11 例**,全部驱动真的
  `GetDesire()`+`Think()`:前提全断言、机制断言(每个真实触及距离都短于 805)、
  归因断言(逐 id 隔离)、缺陷断言(shipped `bOnce=false`;6 秒后出价 0 且另一 mode 赢)、
  四个对照组(进入范围/非英雄/非 turbo/合成 900 施法距离让承诺重新合法)、反向断言;
  **两次变异**:删修复恰好 2 条 FAIL,gate 常开恰好 2 条 FAIL。
  **529/529(基线 518)+ luacheck 0 警告**。`state.json` 新增 `roamreach_20260819`。
  **`roamreach` gated 未 armed**,入集申请见 GH #45 + `test_set.md` §I.7 追加行;
  **两条排期硬约束**:①不可单拎成一臂;②它绑的是 `roamstale` 送达的同一条命令,
  **不要与测量 `roamstale` 的波次同 arm**。顺带记下一条 harness 缺口(未开 issue,
  已进 `state.json`):`.dem` **不带每帧 mode 也不带 unit order**,「哪个 mode 在跑」
  只能靠在该帧重建整场竞价推断(同类 GH #27)。
  未花 AWS 钱(只读 S3:1 个命中缓存的 dumper + 1 个 `.dem`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T213000Z.md`。
- 2026-08-19T19:30Z:没有可认领的新 `[strategy]` issue(#37 由总监 19:00Z 裁定
  `tpdead` 入集、issue 保持 open,剩下那一半要先要帧证据;#41 已被 `roamstale` 解决,
  录像组 18:56Z 确认;#39 已获批)。接 backlog 第 8 条,**本轮 `midtp`/`suptp`**。
  **找到 §0b 家族的第 11 例,亚型是新的:使无效的机制来自调用方自己的前置条件。**
  `J.ShouldTpSupportTowerFight` 要求响应者**离塔 > 3500**、目标取自**塔 1200 内**,
  而 `J.SafeToCommitFight` 只统计**目标 1200 内**的人 —— 响应者**至少在自己的判据外
  2300 码**(三帧全部断言)。于是「可打才去」实际问的是「**没有我这仗是不是已经没事**」:
  **1 人被 2 人越塔(它存在的理由)恰好被拒,2v2(不需要人)恰好放行**;
  它自己的 HEAT GATE 让倒置变成系统性的 —— 唯一确定被数进去的友军**被要求**正在挨打。
  改动:gated `tparrive`(turbo-only,只在 `midtp`/`suptp` armed 时可达),新纯谓词
  `J.SafeToCommitFightOnArrival` 把**正在赶来的响应者**数进两条分支(`depthnum` 的深入
  +1 余量原样保留);**没动 `J.SafeToCommitFight` 本身**(共享消费路径,§0b 第九例)。
  可分离性:多一个友军只能抬高两条分支 ⇒ armed 是 shipped 的**严格超集**,
  **只可能新增响应,不可能删除或改指到另一座塔**;单独 armed 是逐位 no-op,**不可单拎成一臂**;
  与 `roamstale` 无交集,不干扰在跑的 bisect。
  验收 `tests/test_tparrive_collapse_gate.lua` **16 例**,三帧取自**臂 A 的同一局**
  (`20260819_183613_slot1`)、**同一个响应者**(风灵满血 7 级、TP 就绪、1600 内无敌人),
  只有交战点人头数不同:`..._outnumbered`(t=309.4,Jakiro **38% 被 2 人越塔**,风灵在
  **7809** 外,shipped **拒绝** / armed **响应**)、`..._lost`(t=310.4,**1 秒后**,0v2,
  两臂**都拒绝**——防止退化成「总是去」)、`..._parity`(t=378.9,2v2,两臂响应**同一座塔**)。
  前提全断言、机制本身断言(2300 分离 + 响应者确实不在自己的名单里)、人头数逐个断言、
  缺陷本身断言;**最终决策层**断言落点非 nil + 源码级钉住 helper 返回到 HIGH 出价之间
  只有那两个条件;含反向断言。**两次变异**:删修复恰好 3 条 FAIL,gate 常开恰好 2 条 FAIL
  (其中一条是**既有的** `test_mid_tp_support.lua`,独立见证 gate 默认是关的)。
  **518/518(基线 502)+ luacheck 0 警告**。`state.json` 新增 `tparrive_20260819`。
  **必须挑明**:本候选**故意推翻** `test_mid_tp_support.lua` 里写死的 shipped 意图
  (「outnumbered 不许拉 TP」,正是 1v2)。新测试里有一条 `[intent]` 用例把冲突写进代码;
  **promote 时那条测试必须重写、不能删**。
  **顺带更正本组 13:45Z 的一个说法**:那轮说接上 `GetTower`/`UNIT_LIST_*_BUILDINGS` 后
  「自家塔下」否决不再恒 false —— **当时不成立**。loader 的 building 没有 `IsBuilding`,
  而所有 shipped 读者都过 `J.IsValidBuilding` → `unit:IsBuilding()`,mock 默认 nil ⇒
  **整张表 100% 被拒**,塔循环与那条否决**仍然不可达**。本轮加 `IsBuilding = true` 才接通;
  接通前后既有测试**逐条同绿**(502→502),**无历史结论需重看**,但今后关于这两条路径的
  断言必须晚于本次修复才算数。
  **`tparrive` gated 未 armed**,入 test_set.md 已在 **GH #44** 申请;排期提示:
  它只改「去不去」不改**落点**,而 #37 的落点缺陷仍在,armed 后会作用在更多次响应上 ——
  建议**不要与 `lf_rescue` 落点类改动同波**。
  未花 AWS 钱(只读 S3 取 1 个预编译 dumper + 3 个 `.dem`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T193000Z.md`。
- 2026-08-19T17:45Z:**冻结解除后接 backlog 第 5 条(GH #37,本组最高优先)**。
  没有可认领的新 `[strategy]` issue —— #41 是录像组 16:45Z 立的,但总监 17:00Z 已裁定
  (路 C),它的机制就是上一轮交的 `roamstale`(#39,已获批入集),没有留给本组的动作。
  冻结令解除依据:`5a327f5` 已落地 bisect verdict(A−B = +8.12 gpm,z=0.60,null)。
  **本轮头号产出是负结果:候选 2 也被同一组验收帧证伪。** 上一轮说「候选 2 能分开
  三帧」是在**概念层**比「到达时间 vs ground truth 存活时间」;而门里唯一能拿到的是
  `GetEstimatedDamageToTarget(window) < 友军当前血量`。给 `make_fixture.py` 加了
  `observed.damage`(**逐事件**英雄伤害时间线,默认 30s 视野;`observed.burst` 只回答
  一个窗口,而候选 2 问的是另一个),按各帧自己的到达窗口重算门的那条比较:
  **A 548/430 否决(对)、B 96/225 放行(错)、C 258/246 否决(错得致命 —— 那是本波
  唯一一次按设计工作的救援;Axe 25% 血硬吃 258 还活 151 秒,靠回血/药膏,门不建模回复)**。
  dumper 漏计使 258 是**下界**,数据越全对 C 的否决只会越确定,所以这一半站得住;
  B 那行是软的一半(漏计可能翻面),没拿来当结论。
  **于是改走候选 3:gated `tpdead`(turbo-only,且只在 `tpcommit` armed 时可达)** ——
  救援分支多盖一个 `bot.tpRespondAlly`(**为谁**去的),另两条答**地点**的应答 TP
  显式清空该戳;`J.GetTpCommitDefendDesire` 里若戳着的友军已阵亡则清戳、`return nil`。
  **地板 0.85 / 12s 窗口 / 两条既有释放一个字没动,`nVsMe < HP*0.70` 没碰**。
  可分离性同 `tpdying`:只可能把地板变成 nil,**单独 armed 是逐位 no-op**,不可单拎成
  一臂;与 `roamstale` 无交集,不干扰下一波 bisect。
  验收用**三个新的落地后真实帧**(各自 cast 后 6.0s,人已落地仍在承诺内):
  `f_260819_123012_dp_landed_dead`(DK cast 后 **4.7s 死**,响应者离尸体 **5876**)、
  `f_260819_122930_lina_landed_dead`(Lich **2.9s 死**,读条都没走完)、
  `f_260819_123546_jakiro_landed_ok`(Axe **活着**)。
  `tests/test_tpdead_release.lua` 9 例,**所有 desire 断言驱动真的
  `mode_defend_tower_mid_generic.lua` `GetDesire()`**;前提全断言(窗口内/响应者存活/
  两条既有释放沉默/触发点 1600 内仍有敌人/友军生死按 DEATH 事件);**缺陷本身被断言**
  (shipped 三帧**全给 0.85**,含两具尸体);armed 后两具尸体的承诺掉下去、**活的那次
  原样 0.85**;含反向断言(armed 永远不能把 nil 变成地板)+ **戳而非「队里有人死了」
  才是判据**的对照;**两次变异**:删修复恰好 2 条 FAIL,gate 常开恰好 1 条 FAIL。
  **489/489(基线 479)+ luacheck 0 警告**。`state.json` 新增 `tpdead_20260819`。
  **`tpdead` gated 未 armed**,入 test_set.md 已在 **GH #37** 申请。
  **明说没解决的那一半**:`tpdead` 只回收浪费掉的 12s 承诺,**不阻止那次到不了的 TP**
  ——#37 的经济账主要在后者,后续方向见 backlog 第 5 条。
  未花 AWS 钱(只读 S3 取 3 个 `.dem` + 命中 dumper 缓存,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T174500Z.md`。
- 2026-08-19T15:34Z:**`lf_rescue` 冻结令仍有效**(臂 B 补跑 verdict 未落地,
  `origin/main` 仍停在总监 15:00Z 的 `4993b4b`),本轮 `git diff` 里**没有 `lf_rescue` /
  `jmz_func.lua` 的任何一个字节**。没有可认领的新 `[strategy]` issue,接 backlog 第 8 条
  「最终出价可达性」普查,**一次一条,本轮 `ownhalf`**。
  **出价这一层 `ownhalf` 干净**(负结果,如实记录):在它自己的立案帧
  `f_232228_wk_ownhalf_standoff`(t=340=5:40)上,原始 0.98 被 `CapForLanePush` 砍到
  **0.72**,但 0.72 仍**赢下模式竞价**(`mode_laning_generic` 同帧 **0.446**,其余 16 个
  mode 文件全 **0**)—— 它**不是** #29/#31/#32/#35 那种出价域缺口。
  **但补验收时在下游一层撞到新缺陷**(总监 §0b 第八例,**新亚型:出价完好且赢了竞价,
  被本 mode 自己的 `Think()` 丢掉**):`mode_team_roam_generic.lua` 的 `hTargetCreep`
  **只有一个写者**(last-hit 分支),**位于全部六条提前 return 的出价分支之下**
  (`ConsiderHelpWhenCoreIsTargeted`/`ConsiderHelpAlly` **已发布** + `ownhalf`/`overchase`
  (**armed**)/`l1trade`/`l5combo`),**从不复位**;而 `Think()` **第一件事**就是读它并
  `return`。于是**每一帧只要那六条之一赢下竞价,这个模式就去打上一帧那只小兵,永远碰不到
  自己算出来的集火目标** —— 这机械地解释了 `ownhalf` 的立案观察本身(232228:WK 满血、
  晕就绪,在 69% 血落单 Jugg 旁 ~1000 码悬停 17 秒)。
  改动:gated `roamstale`(turbo-only),在 `GetDesireHelper` 开头清 `hTargetCreep`;
  可分离性同 `capmono` 的「纯 min」——last-hit 分支每帧到达时都会重新赋值,所以 armed
  差集**恰好**是「某条提前分支返回了」的帧,**只可能移除一次残留小兵攻击、不可能新增**,
  且**不改变任何一处出价**。验证 `tests/test_roamstale_collapse_action.lua` 7 例
  (真实帧两帧端到端驱动真的 `GetDesire()`+`Think()`;帧事实全断言;**无小兵对照组**证明
  小兵就是机制;普通补刀帧 armed/shipped 逐位相同;**反向断言**钉住写者数量,别人正经修掉
  时自曝过期;**两次变异测试**:删修复恰好挂 2 条,gate 常开恰好挂 1 条)。
  顺带补 mock 保真度缺口:`GetIncomingTrackingProjectiles` 默认从 `0` 改为 `{}`
  (引擎返回列表;此前任何驱动真补刀/来袭伤害路径的测试都会 `pairs` 崩溃 —— 是崩溃不是
  假绿,无历史结论需重看)。**462/462(基线 455)+ luacheck 0 警告**。
  `state.json` 新增 `roamstale_20260819` 与 `ownhalf_BID_AUDIT_20260819`。
  **`roamstale` gated 未 armed**,入 test_set.md 待总监批(已开 issue **#39**)。
  **排期硬提示:它横跨六条分支(含两条已发布、一条此刻 armed 的 `overchase`),必须单独
  测量,不可与 `ownhalf`/`overchase`/`l1trade`/`l5combo` 任何一条的 bisect 同波 armed。**
  未花 AWS 钱(本轮零 AWS 调用、零 S3 读),未提批测请求。详见
  `iterations/reports/strategy/20260819T153447Z.md`。
- 2026-08-19T13:45Z:认领 **issue #37**(总监 13:12Z 归口本组)。总监冻结令:
  verdict 落地前**不许动 `lf_rescue` 代码** —— 本轮严格遵守,
  **`git status bots game` = 0 个文件**,无行为改动、无新 gate、`state.json` 未改。
  做的是冻结令没覆盖、且**必须先做**的那一半:总监要求的验收形状(「三帧一起钉」)
  **在旧工具链里无法表达**。两处 mock 保真度缺口互相掩盖:
  (1) `bot_api.lua:264` 把 `GetTower` 桩成 `nil`,于是
  `J.GetNearbyLocationToTp` 在**每一个 fixture 里**都落到「一座塔都不剩」的兜底
  → **返回泉水**(此前所有 TP 落点断言测的都是真实对局里不会发生的退化路径;
  同一缺口还让 `GetRescueTpTarget` 的「友军在自家塔下」否决恒为 false);
  (2) mock `Vector` 没有 `__div`,即使接上塔,算 575 偏移时也会直接崩。
  已补:`make_fixture.py` 输出 `buildings`(dumper 本就在落这份数据)、
  loader 接 `GetTower`/`UNIT_LIST_*_BUILDINGS`(**阵亡结构缺席**=引擎语义)、
  `Vector.__div`。**没有 `buildings` 的老 fixture 逐字节不变**(有回归护栏钉住)。
  钉住三帧(Python 从 .dem 独立重建 + Lua fixture 世界跑出,两边逐位吻合):
  `f_260819_123012_dk_rescue_far`(落点→友军 **5623**,友军 4.7s 后死)、
  `f_260819_122930_lich_rescue_doomed`(**1579**,2.9s 后死)、
  `f_260819_123546_axe_rescue_ok`(**1746**,活)。
  **两条实质结论**:(i) **候选改法 1「落点距离门」被证伪** —— 必须拒绝的 B(1579)
  比必须放行的 C(1746)**还近**,任何砍掉 B 的天花板都会连本波唯一一次有效救援
  一起砍掉(录像组报的 1857/1585 与我重建的顺序相反,但两版都相距 <300 码,
  **距离维度上根本不可分**,结论不依赖哪版更准);(ii) **候选 2「把落点距离喂回
  生存窗口」能分开全部三帧且两向余量充足**(A 超预算 4.6×、B 超 2.9×、C 富余 17×,
  对移速取值不敏感)。顺带证实 **shipped 的 `J.WillAllySurviveTpWindow` 三帧全返回
  true**,分不开任何东西 —— 它的 4.0s 预算**全花在读条上**,一点没留给落地后要走的路。
  验证 `tests/test_lf_rescue_landing_reach.lua` 6 例(前提全是断言出来的;
  含证伪断言、可分性断言、老 fixture 回归护栏;**两次变异测试**:拆塔接线恰好 3 条
  FAIL,拆 `__div` 恰好 4 条 FAIL)。**450/450(基线 444)+ luacheck 0 警告**。
  **下一轮交接**:冻结解除后按**候选 2** 写 gated 修复(不要写距离门),验收直接用
  这三个 fixture;**不要动 `nVsMe < HP*0.70`**(总监钉死的边界);候选 3 与候选 2
  互补但应**排在其后单独做**(它改的是 `tpcommit` 那块地板,与上轮 `tpdying` 同源,
  合做就是一次变两个量)。未花 AWS 钱(只读 S3 取 3 个 `.dem` + 命中 dumper 缓存,
  未启动任何计费实例),未提批测请求。详见
  `iterations/reports/strategy/20260819T134500Z.md`。
- 2026-08-19T11:35Z:没有可认领的新 `[strategy]` issue(#32 已被总监 11:10Z 批准
  入集,本轮关闭;#28/#26 是本组遗留),接 backlog 第 8 条「最终出价可达性」普查,
  **一次一条,本轮做 `tpcommit`**。发现 **#29/#31/#32 同族的第四例**:
  `J.GetTpCommitDefendDesire` 的 0.85 落地地板,其释放条件
  `GetHP < 0.40 or J.ShouldRetreatLaneBurst(bot)` 里**预判的那一半**
  (`ShouldRetreatLaneBurst`,第三行 `if not J.IsInLaningPhase() then return false end`)
  在**这块地板自己的生效域里结构性失效** —— 地板只能从两个响应 TP 分支到达,而它们
  要求 6 级 + >3500 码跨图,所以钉住的帧压倒性在对线期之后,释放只剩「已经掉到 40%
  以下」。这正是当初写这个释放要堵的「站在原地被磨死」形状,**减掉了让它奏效的那一半**。
  改动:gated `tpdying`(turbo-only,且**只有在 `tpcommit` 也 armed 时才可达**),
  新纯谓词 `J.IsIncomingBurstLethal`(与 `ShouldRetreatLaneBurst` 同一个 mana/cd-aware
  估算器,去掉对线期门),armed 时**只可能提前释放**,结构上不可能抬高或制造钉死;
  地板值 0.85 / 12s 窗口 / 原释放**一个字没动**。
  验证 `tests/test_tpcommit_release_domain.lua` 9 例,锚在真实帧
  `f_182552_warlock_ult_hoard`(t=626=10:26,术士 53.4% 血,狙击手 1008 码外,
  ground truth:打出 **669** 进 546 的血池,**2.3s 后死**);两个前提
  (`IsInLaningPhase()==false`、`GetHP>0.40`)都是**断言出来的**;**所有 desire
  断言驱动真的 mode 文件 `GetDesire()`**(§0b 规矩):armed tpcommit → defend
  **0.85** vs retreat **−0.05**(就在他被打死那一帧);shipped → 0.1;+tpdying → 0.1。
  含反向断言(shipped 释放哪天被改成域正确的,测试自曝过期)+ 两次变异测试。
  **427/427 + luacheck 0 警告**。顺带补了四处 mock 保真度缺口(见 backlog 第 8 条)。
  `state.json` 新增 `tpdying_20260819`。**`tpdying` gated 未 armed**,入 test_set.md
  待总监批(已开 issue **#35** 申请;排期提示:单独 armed 是 no-op)。
  **另发现但未动**:响应 TP 的落点(`J.GetNearbyLocationToTp` → 最近**存活**己方塔前
  575 码,无塔回落**泉水**)从来没有和触发点做过距离校验,而 `WillAllySurviveTpWindow`
  只预算 4.0s、**不含落地后走过去的时间** —— 这能机械地解释录像组 `20260819T033000Z`
  里那个「前置条件全满足但落地在泉水」的 `lf_rescue` 帧。**故意没动**:一次一个杠杆,
  且 `lf_rescue` 是马上要跑的 bisect 的被测变量。未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T113516Z.md`。
- 2026-08-19T09:16Z:没有可认领的新 `[strategy]` issue(#28/#26 都是本组上一轮
  自己的遗留),于是接住总监 09:04Z 关闭的 **#31 没覆盖的另一半**。总监对
  `l1trade`/`l5combo` 的修法是**豁免**(它们硬性要求对线期,cap 域是其生效域的
  严格超集);**仍被 cap 的四条分支没人管**,其中 `overchase` 此刻就在 armed 集内。
  缺陷:`_divecap_CapForLanePush` 注释写 `soft ceiling`、代码是**悬崖**
  (只砍 `>0.9`,砍到 0.72,低于原样放行的整个 (0.72, 0.9] 带),而四条分支出价
  都是 `RemapValClamped(HP, 0, 0.5|0.6, NONE, 0.98)` → **有效出价对血量非单调,
  峰值 ~46% 血**:满血 0.72(输给已 promote 的 lanesurv 0.75),43% 血 0.843
  (赢),36% 血 0.71(输)。**最没资格打的人是唯一被钉进架子里的人**,而这四条
  都没有 lane-kill 那样的 `ShouldReleaseLaneCommit` 自释放 —— wave13 卷宗实锤过
  的钉死送命形状。这是 #29/#31 同族缺陷的**第三例**。改动:gated `capmono`
  (turbo-only),armed 时把悬崖换成真天花板 `min(desire, 0.72)`,**天花板的值不动**;
  armed 路径是纯 min,**只可能降低出价**,所以结构上不可能造成那个让 `divecap`
  至今留暗的「过度投入」风险。验证:`tests/test_capmono_ceiling.lua` 12 例,
  锚在真实帧 `f_222428_lion_lich_burst`(Lion 354/823=43.0% 血 @ t=314,
  Lich 660u + Axe 800u,2200 内无队友;录像 ground truth:Lich 打出 436,
  **6.9s 后 Lion 死亡**);该帧的「cap 真的生效」+「lanesurv 真的出 0.75」都是
  **断言出来的**;含 21 点血量扫描直接驱动真的全局 `GetDesire()`(只强制触发器),
  以及一条**反向断言**(未 armed 时必须仍非单调,悬崖被改掉时测试自曝过期)。
  两次变异测试:删掉修复 → 恰好 3 条 armed 断言 FAIL(报错打印真实倒置
  `0.881 → 0.72 as HP rose to 0.5`);gate 强制常开 → 恰好 5 条已发布行为断言 FAIL。
  **408/408 + luacheck 0 警告**。`state.json` 新增 `capmono_20260819`。
  **`capmono` gated 未 armed**,入 test_set.md 待总监批(已开 issue **#32** 申请)。
  未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T091647Z.md`。
- 2026-08-01 初始化。测试集里本组名下 id:creeppull/pullcamp/l1trade/
  l5combo/midtp/suptp/tpcommit/lf_rescue/teambrain/ownhalf/overchase/tpwatch。
  l1xpsoak 不在集内,等重设计。
- 2026-08-19T01:15Z:首次真实工作报告(见
  `iterations/reports/strategy/20260819T011551Z.md`)。完成 l1xpsoak 重设计
  代码(绝对锚 + 退出滞回),fixture 验证 + 全套测试 + luacheck 全绿,已
  push。**l1xpsoak 仍不在 test_set.md 里**(该文件编辑权在总监)——已开
  issue #24 请总监审批重新入集并排期验证批测。未花 AWS 钱,未提批测请求。
- 2026-08-19T03:20Z:issue #24 已由总监批准入集(`test_set.md` 已含
  `l1xpsoak`,commit `15a9262`),协同组关闭该 issue。认领 issue #26(集火
  目标选择不看"谁在滚雪球"),定位代码路径(`GetAttackableWeakestUnitFromList`
  双向复用于治疗/攻击目标、多数英雄自动攻击目标其实来自引擎原生 AI,脚本层
  只在少数特例显式打分),委托 replay-analyst 子代理拿录像建真实帧 fixture,
  逐帧复核后发现原始 issue 的直觉判断在具体帧层面站不住(Lina 当时在近战
  射程外,DK 换目标打不到她,死因是远程爆发而非目标选择)——**判断证据不足
  以支撑负责任的行为改动,没有写 gated 修复**,只落地工具链补强(dumper→
  fixture→mock loader 全链路补上 net_worth 字段,今后经济类修复可直接用
  真实身价做本地验证)+ 帧证据 fixture 存档 + issue #26 评论留下两个建议
  方向(同射程多候选场景重新取帧 / 转向撤退-威胁评估角度,可能与 backlog
  `−18 econ 残差归因` 同源)。全量 366/366 测试 + luacheck 0 警告。未花
  AWS 钱(replay-analyst 走它自己职责内的只读 S3),未提批测请求(无行为
  改动可测)。详见 `iterations/reports/strategy/20260819T032018Z.md`。
- 2026-08-19T07:17Z:认领 issue #28(总监 06:55Z 把 `l1xpsoak` 退回本组,要求在
  "让锚点真正驱动移动" / "取消独立 id、滞回收进 lanesurv" 两条路里二选一)。
  **选路径 2,并做保守细化:滞回不改已 promote 的默认,而是挂新 gate
  `lanehyst`**(未 armed 时 shipped 判定逐字节不变,armed 时可单独测量)。
  放弃路径 1 的**新证据**:`mode_retreat_generic.lua` 只有 `GetDesire()`、
  **没有 `Think()`**,撤退时的移动/TP/逃生全在引擎内置实现里——"站在锚点 hold"
  等于给最安全攸关的 mode 重写整套 Think,而 mode-Think 替换正是 A1 分析判定
  `l1xpsoak` −50 gpm 的主因。改动本体:`J.ShouldRetreatLaneBurst` 在 true 帧
  盖时间戳,基础门槛没过时于 **2.0s 窗口**内继续 true(条件:无 peel 队友 +
  incoming 仍 ≥40% 血量);**刻意有时间上限**,可抹平闪烁但永远变不成停车刹车。
  依据 (c):对阈值附近闪烁的二值控制信号加 Schmitt trigger,本仓库 l1kite 的
  kite-lock 是同一味药。同时**退役 `l1xpsoak` 全部代码**(helper + 消费块 +
  旧测试),留墓碑注释。验证:新 `tests/test_lanehyst.lua` 7 例全跑真实帧
  `f_231411_ck_zoned`,非空验证(关死 gate 恰好 2 条 hold 断言 FAIL),
  **381/381 测试 + luacheck 0 警告**。`state.json` 新增 `lanehyst_20260819` 与
  `l1xpsoak_RETIREMENT_20260819`。**`lanehyst` gated 未 armed**,入 test_set.md
  待总监批(已在 #28 评论申请)。未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T071719Z.md`。
- 2026-08-19T05:16Z:认领 issue #13(总监 04:54 点名本组"直接看代码里的触发
  条件")。**找到 `creeppull` 13/13 局 SILENT 的根因:它是一个可证明的死分支**
  ——`mode_roam_generic` 用 `J.IsLanePullSafe`(1800 内有敌人就 false)闸住
  `J.ShouldCreepPullLane`,而后者**必须**有一个 1000 内的敌方英雄当勾兵仇恨的
  攻击目标,两者互斥,自 20260723 rehome 起从未执行过一次。修复:拆分两种拉线
  的安全规则——拉野(离开兵线进野区)保留和平期规则不动;勾线改用新的
  `J.IsCreepPullSafe`(健康 + 1000 内至少一个对线者 + **1000–1800 环里没有多余
  的人**+ 最多 2 个),把问题从"有没有人可见"改成"有没有**多余**的人可见",
  同时保留 wave13 那个 163732 埋伏形状的否决。**没有新 soak id**(改动活在既有
  `creeppull` 闸门内,未 armed 对局逐字节不变,state.json 无需登记)。真实帧
  fixture 6 例(`tests/test_replay_creeppull_reachable.lua`,含端到端在真实帧上
  出 pull intent + 埋伏帧/轮转帧/残血帧仍被否决),非空验证:临时把新闸门改回
  旧别名恰好 2 条可达性断言 FAIL。377/377 测试 + luacheck 0 警告。已在 #13 评论
  申请 **`creeppull` 重新入 test_set.md**(`pullcamp` 不申请,触发条件未查清,
  已进 backlog 第 6 条)。未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T051642Z.md`。
