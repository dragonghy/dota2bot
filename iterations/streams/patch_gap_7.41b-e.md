# Patch 缺口工单:7.41b / 7.41c / 7.41d / 7.41e

总监 2026-08-19T11:10Z 建档。**这份文件的目的是把 backlog #0 从"一个说不清多大、
每轮被 issue 挤掉的黑盒"变成一份可以分片执行的清单**,并回答一个从没被回答过的
问题:**这个缺口现在到底卡住了谁?**

## 0. 结论先说(本轮唯一的新信息)

**对当前五个焦点英雄(Axe / Zeus / Wraith King / Lion / Crystal Maiden),
7.41b–7.41e 的全部改动都是纯数值,没有一条结构性改动。** 数值由游戏 API 直接
提供(`GetSpecialValueInt` / `GetCastRange` / `GetCooldown` 等),我们的 Lua 不需要
任何改动。已 `grep` 核对:仓库里没有对 `axe_berserkers_call` 施法距离一类的硬编码
(唯一相关的新代码 `J.ShouldHoldAxeBlinkForCall` 读的是 `GetSpecialValueInt('radius')`,
不是字面量)。

**因此:patch 缺口不阻塞英雄打磨、不阻塞测试集判定、不影响任何 armed id 的判读。**
它连续四轮被 `[bug]` 抢占**没有造成实际损失**——之前之所以被标成"最高优先级",
是因为**没人量过它的影响面**。本轮起把 backlog #0 从"最高优先级"降为**按分片排期**
(下面 §3 的分片,每片都能塞进一个工作单元),不再挤占 `[bug]`/判定类工作。

数据来源:`https://www.dota2.com/datafeed/patchnoteslist`(最新 = **7.41e**,
ts 1785394800)+ 四个 `patchnotes?version=` 拉取。`docs/PATCH_UPDATE_GUIDE.md`
的 "Last updated for" 仍是 **7.41a**,**本轮不改**——分片没做完就改它等于伪造进度。

## 1. 焦点五的逐条改动(全部 NUMBER-ONLY,存档备查)

| 版本 | 英雄 | 改动 | 分类 |
|---|---|---|---|
| 7.41b | Crystal Maiden | 一个技能冷却增加 | NUMBER-ONLY |
| 7.41b | Axe / Zeus / Lion / WK | 无条目 | — |
| 7.41c | 焦点五 | **全部无条目** | — |
| 7.41d | Axe | 基础生命回复 −0.5;技能施法距离 700/775/850/925 → **600/700/800/900** | NUMBER-ONLY(API 直读) |
| 7.41d | Lion | 15 级天赋 hex 冷却减少 2.5s → 2s;技能每杀伤害 30 → 25 | NUMBER-ONLY(天赋是数值改,不是替换) |
| 7.41d | Wraith King | 基础伤害 +2;吸血 14%+1%/级 → 20%+0.5%/级;10 级天赋吸血 10% → 8%;Aghs 冷却 165/135/105 → 170/140/110 | NUMBER-ONLY |
| 7.41e | Axe | 基础敏捷 20 → 18;一个技能伤害下调 | NUMBER-ONLY |
| 7.41e | Zeus | 一个技能伤害下调(+ 一条 datafeed 归到 hero 22 但机制不像 Zeus 的条目,见 §2 警告) | NUMBER-ONLY / 待核 |
| 7.41e | Lion / WK / CM | 无条目 | — |

值得单独记一笔的是 **Axe 施法距离在 1 级从 700 降到 600**:它不需要改代码,但
它**改变了新 gated 修复 `axeblink` 的有效窗口**(通用进攻性闪烁分支用的是
500..施法距离)。`axeblink` 的核验帧如果取自 7.41a 之前的录像,窗口比线上宽——
英雄组核验时知道这一点即可,不需要动代码。

## 2. ⚠️ 执行前必须先解决的前置项(否则整个工单会做错)

**datafeed 的 hero id 与经典 `hero_id` 不一定是同一套编号。** 本轮拉取里出现了
自相矛盾的映射(例如 7.41e 里归在 hero 22 名下的"切换形态不再破隐身、攻速 30→20"
根本不是 Zeus 的机制;7.41c 里"Treant (19)"/"Bristle (155)" 也对不上经典编号)。

因此 **§3 的任何一片开工前,第一步都是拿到权威的 id → 内部名映射**
(datafeed 的 herolist 端点,或 d2vpkr 数据),再按 CLAUDE.md 的硬规矩
**在 Liquipedia 上核对技能/天赋名**。**不要凭 patch note 摘要直接改 Lua。**
上面 §1 的焦点五结论不受这条影响:焦点五在四个版本里要么无条目,要么条目本身
是纯数值(即使 id 映射错了,错的方向只会是"我们以为有改动其实没有")。

## 3. 分片清单(每片 = 一个工作单元)

| 片 | 内容 | 依赖 | 影响面 |
|---|---|---|---|
| **P0** | 建立 hero id → 内部名的权威映射脚本(`tools/patch/hero_id_map.py` 或等价),并把 §1/§4 的条目重新按内部名核对一遍 | 无 | 阻塞 P1–P3 |
| **P1** | 中立物品结构性改动:7.41b **Consecrated Wraps** 的 hallowed 层数改成物品充能(仓库里 5 个英雄的购买表引用了 `item_consecrated_wraps`)、**Demonic Warrior** 移除真视。按 CLAUDE.md 规矩**两份中立物品文件都要改**(`Buff/` + `FretBots/`) | P0 | 中立物品逻辑 |
| **P2** | 天赋替换(不是数值改):7.41c 有 ≥6 个英雄整条天赋被换,7.41e 还有 3 个。逐个改 `tTalentTreeList`。**焦点五一个都不在里面**,所以这片是非焦点英雄的账面维护 | P0 | 非焦点英雄 |
| **P3** | 通用机制变化,影响我们已有的判定逻辑,**优先级高于 P2**:① 7.41c "飞行视野无法看进/看出 Roshan 坑"(与 gated `roshgate` 直接相关);② 7.41d TP 卷轴自购回城落点更靠近远古 + 传送效果部分跟随被移动的引导单位(我们有一整族 TP 纪律 id:`midtp`/`suptp`/`tpcommit`/`tpsafe2`/`tpwatch`);③ 7.41c Bloodstone 配方 600→700g(合成价表) | P0 | gated id 的判读前提 |
| **P4** | 全部核对完之后,才把 `docs/PATCH_UPDATE_GUIDE.md` 的 "Last updated for" 改成 7.41e,并按 guide 记一条更新日志 | P1–P3 | 文档 |

**排期建议**:P3 值得优先(它是唯一可能让**现有 gated id 的判读前提失效**的一片);
P1 次之;P2 可以一直往后排——它对焦点五零影响,是纯账面工作。

## 4. 非焦点英雄的结构性改动(存档,归入 P2/P3,不逐条展开)

- 7.41b:Consecrated Wraps 改充能、Demonic Warrior 移除真视、Spellover 加 0.1s
  内置 CD、若干英雄机制改(Phantasm 幻象数固定 3、Poof 不再共享 TP 冷却、
  Meepo 物品加成按分身数惩罚、某技能不再溅射、某技能激活时间 0.3s→0)。
- 7.41c:Roshan 坑飞行视野、Bloodstone 配方、Harpoon 对被禁锢施法者无效、
  Astral Step 超距改为朝向施放、Overload 每 3 级一层、Split Earth 取消初始 CD、
  ≥6 个英雄天赋替换、Lone Druid 共享吸血按通用规则(对小兵 40% 惩罚)。
- 7.41d:天辉/夜魇泉水恢复光环半径、TP 卷轴落点与引导跟随、迷雾在队伍频道广播、
  魔杖不再被某技能充能、Gyrocopter 夜视/弹幕不再同时攻击 2 个目标、Mars Bulwark
  开关转向、Clockwerk 对零蓝英雄仍推击。
- 7.41e:Twin Gate 引导可被缠绕打断、Rapier 法强不叠加、若干隐身/切换形态不再破
  隐身、Sonic Wave 快速两次施放伤害叠加、幻象视野惩罚移除、3 个英雄天赋替换。
