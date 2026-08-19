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
2. ~~**CM 大招时机**~~ 2026-08-19 first-cut done — 见"当前状态"。新 gate
   `cmrguard`(自保检查,敌方近战硬控就绪时不开大),真实帧 fixture 通过。
   **原假设(#nEnemysHeroesInRange>=3 无脑绕过 aoeCanHurtCount)未被证实**,
   留作后续可选深挖项(不阻塞本条划掉)。
3. **魔棒/芒果死手帧**:低血限进(d23 lowhp_limbo)时身上有魔棒充能/
   芒果却不用的案例(lich 帧已有);查焦点五的同类帧。
4. **Zeus 大招击杀确认**:全图大招抢残血 vs 浪费在满血团上的帧差分。
5. **Axe 跳吼目标质量**:跳进人堆 vs 跳单人的选择核查(配合 d24
   deep_solo_death 找反例)。
6. ~~**WK reincarnation 真实帧 fixture**~~ 2026-08-19 done —— 委托
   replay-analyst 找到真实帧(spot_20260725_102532_1_main slot1, t=373.5,
   mp=189/387 落在 160/220 gap 里),`tests/fixtures/
   f_260725_105305_wk_reincarn_gap.lua` + `tests/
   test_replay_260725_wk_reincarn_gap.lua`,gate ON/OFF 两条路径校验通过。
   **下一步不是本组的活**:`wkreincarnmp` 进 `test_set.md` 需要 director
   批准(本组无权自改),已在本次报告里提出,等 director 下次触发采纳。

## 当前状态(每次触发后更新)
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
