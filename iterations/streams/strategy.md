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
5. **`lf_rescue` 落点可达性修复(issue #37,本组最高优先)**。录像核验已完成
   (条件 (a) = WORKING + BUGGY),验收三帧**已钉好**(见 2026-08-19T13:45Z 状态)。
   冻结解除(bisect verdict 落地)后即可动手:**按候选 2** —— 把落点步行时间喂回
   `J.WillAllySurviveTpWindow` 的窗口(该函数目前把 4.0 写死在
   `GetEstimatedDamageToTarget` 调用里,需要开一个窗口入参)。
   **候选 1(落点距离门)已被真实帧证伪,不要写**;**不要动 `nVsMe < HP*0.70`**
   (总监钉死的边界)。候选 3(落地后友军已死则清 `tpRespondLoc/tpRespondUntil`)
   互补,但改的是 `tpcommit` 那块地板(与 `tpdying` 同源),单独排一轮。
   原「规则细化」条目的其余部分(链式救援闸、响应者生存力检查)已由 #37 第 3 节
   核验为**有效**,不再是待办。
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
   `midtp`/`suptp`/`lf_rescue`/`teambrain`/`ownhalf`/`tpwatch`。
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
