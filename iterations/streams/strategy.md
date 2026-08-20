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
   **卡在**:请录像组在已付过钱的语料上数「HOLD 合格帧之后 8s 内 subject 死掉」的比例
   (已在 GH #74/#71 留言);接近 0 ⇒ 按现状 armed,可观 ⇒ armed 前必须加逼近威胁项。
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
   **下一批(一次一个,不要批量刷)**:性价比最高的是 `f_260820_043124_axe_blink_kill`
   (**与 blinkflee 两帧同一局**,角色已知:axe 槽位 2 → 抽签 pos 3),然后两个 `cm_es_*`、
   两个 `lion_drain_*`、两个 `od_eclipse_*`。**每治一个都要重读它钉住的结论并写下来**
   —— 治一帧可能翻掉它钉的东西,那正是这件事的意义。
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
   ~~`tpwatch`~~(**2026-08-20T01:45Z 已查:出价这一层送到了、也赢了,但它抬的是**
   **已经在跑的那个 mode(shipped retreat 已 0.75),而 retreat 没有 `Think()` ⇒ 结构上
   没有落点;判据本身还是滞后指标。建议出集,见 GH #52 与当前状态节。这是本族的新亚型:
   出价完好 + 赢下竞价 + 零效果**)、
   `midtp`/`suptp`(**2026-08-19T19:30Z 查了一半**:触发闸门的可达性缺陷已定位并修复
   → gated `tparrive`,见 issue #44。**仍未查的另一半**:(i) 物品循环的槽位顺序
   `{5,4,3,2,1,0,15,16}` 把 TP 卷轴排最后,任何当帧想用的其他物品都抢在响应 TP 前面;
   (ii) `ability_item_usage_generic.lua:5089+` 的「先命中先 return」guard 链 ——
   `lf_rescue` 排在 `midtp` 之前且两者可同帧成立,而两者共用
   `J.TryTakeTpResponseSlot()` 那个 6 秒一人的全队配额)、
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
