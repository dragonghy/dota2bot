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
0b. **旧 fixture 逐个补真实世界(modifier + 挨打史)**。生成器与 loader 都已支持
   (modifier 2026-08-19T23:25Z;`recent_damage` 2026-08-20T01:45Z),但**有意没有批量
   重生成**:给一帧补上真实 buff/debuff 或真实的挨打史可能**翻掉**它钉住的那个决定,
   那正是这件事的意义。**一次一个、每次重读结论**。
   ~~优先级最高的是 `tpwatch` 相关的帧~~ **`tpwatch` 已做完(2026-08-20T01:45Z,GH #52):
   判据本体跑完了,结论是负的,建议出集,不要再花轮次在它身上。**
   ~~**下一批候选**:`aba_defend` 的「我在不在挨打」guard 群(`830/939/1137/1253`)~~
   **1253 已做完(2026-08-20T03:36Z):翻面了,产出 gated `defstale`**;**830 不要做**
   (整条分支靠 `jmz.GetPosition`,GH #53 证明 fixture 里全队 pos 都是 1,断言不算证据)。
   **仍未做**:`aba_defend:939`(`enemiesOnHG >= 2 and not recentlyHit` 的高地分支 ——
   `recentlyHit` 此前恒假 ⇒ **那条 `return VeryLow` 一直恒被走**)、`aba_defend:1137`、
   `jmz_func.lua:1302/1498/3618/4648`。
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
   670s,只覆盖前 8 分钟(#37 第 4 节)——未动,独立排一轮。
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
  **`defstale` gated 未 armed**,入集申请见 GH issue;**排期建议:不要给它单独一条臂**
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
