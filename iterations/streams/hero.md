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
   mock-tested; REAL-FRAME FIXTURE STILL PENDING (see 当前状态)。找到真实帧
   前不要 promote / 不要排批测。
2. **CM 大招时机**:Freezing Field 被打断/空放的帧核查,接近生效半径 +
   有控制掩护才开。
3. **魔棒/芒果死手帧**:低血限进(d23 lowhp_limbo)时身上有魔棒充能/
   芒果却不用的案例(lich 帧已有);查焦点五的同类帧。
4. **Zeus 大招击杀确认**:全图大招抢残血 vs 浪费在满血团上的帧差分。
5. **Axe 跳吼目标质量**:跳进人堆 vs 跳单人的选择核查(配合 d24
   deep_solo_death 找反例)。
6. **WK reincarnation 真实帧 fixture**(接上面#1):找一局 WK 6-11 级、
   团战中蓝量落在 100-250 区间的真实录像帧,`make_fixture.py` 钉帧,
   用 `tests/mock/replay_fixture.lua` 重跑 `J.IsWkReincarnationArmed` 校验
   gate ON/OFF 两条路径;通过后才能进 `iterations/queue.json` 排批测。
   本组无录像归档/AWS 访问,可能需要请 replay-analyst 代找帧。

## 当前状态(每次触发后更新)
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
