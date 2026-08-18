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
1. **WK 重生蓝保留**:大招好了却因缺蓝白给(检测器 d22 died_with_ult_ready
   有历史命中)— 蓝量低于重生消耗时的技能/出手节制。
2. **CM 大招时机**:Freezing Field 被打断/空放的帧核查,接近生效半径 +
   有控制掩护才开。
3. **魔棒/芒果死手帧**:低血限进(d23 lowhp_limbo)时身上有魔棒充能/
   芒果却不用的案例(lich 帧已有);查焦点五的同类帧。
4. **Zeus 大招击杀确认**:全图大招抢残血 vs 浪费在满血团上的帧差分。
5. **Axe 跳吼目标质量**:跳进人堆 vs 跳单人的选择核查(配合 d24
   deep_solo_death 找反例)。

## 当前状态(每次触发后更新)
- 2026-08-01 初始化。测试集里与本组相关的 id:wandbleed(魔棒放血规则)、
  fieldregen(野区补给回购)。焦点五各英雄尚无系统性个体核查记录。
