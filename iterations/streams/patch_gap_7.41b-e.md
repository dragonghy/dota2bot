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

> **2026-09-01T04:xxZ 低频 patch 检查(章程 2f)复核数据源:`patchnoteslist` 最新仍是
> **7.41e**(ts 1785394800 = 2026-07-30),117 条,**自 08-19 建档以来无新 patch**
> ⇒ 缺口的边界没变,仍是 7.41b–e 四个版本。**

## 1. 焦点五的逐条改动(全部 NUMBER-ONLY,存档备查)

| 版本 | 英雄 | 改动 | 分类 |
|---|---|---|---|
| 7.41b | Crystal Maiden | 一个技能冷却增加 | NUMBER-ONLY |
| 7.41b | Axe / Zeus / Lion / WK | 无条目 | — |
| 7.41c | 焦点五 | **全部无条目** | — |
| 7.41d | Axe | 基础生命回复 −0.5;技能施法距离 700/775/850/925 → **600/700/800/900** | NUMBER-ONLY(API 直读) |
| 7.41d | Lion | 15 级天赋 hex 冷却减少 2.5s → 2s;技能每杀伤害 30 → 25 | NUMBER-ONLY(天赋是数值改,不是替换) |
| 7.41d | Wraith King | 基础伤害 +2;吸血 14%+1%/级 → 20%+0.5%/级;10 级天赋吸血 10% → 8%;Aghs 冷却 165/135/105 → 170/140/110 | NUMBER-ONLY |
| 7.41e | Axe | 基础敏捷 20 → 18;`axe_battle_hunger` 每秒伤害下调 | NUMBER-ONLY |
| 7.41e | Zeus | `zuus_thundergods_wrath` 伤害下调;`zuus_lightning_hands` 攻速 30 → 20 **+ 一条非数值条款**(见下) | 数值 + 1 条机制,**代码零影响** |
| 7.41e | Lion / WK / CM | 无条目 | — |

**⚠ 2026-09-01 P0 按内部名重核后,本表改了两处(原文见 git 历史):**

1. **7.41d 的 Axe 施法距离改动是 `axe_battle_hunger`(战斗饥饿),不是狂战士之吼。**
   原文据此写的 `axeblink` 窗口提醒**前提不成立、已作废** —— 完整判定见 **§2.1**。
2. **7.41e 的 Zeus 条目不是纯数值。** `zuus_lightning_hands` 那条里除了攻速 30→20,
   还有一条机制条款:「开关不再破隐身、可在沉默中开关」。**它确实是 Zeus 的技能**
   (原表把它标成"机制不像 Zeus 的待核条目",见 §2 判定)。
   **代码影响为零**:全仓对 `zuus_lightning_hands` 的引用只有
   `spell_list.lua:1015` 的**加点权重**一处(`weight = 1`),我们**没有任何开关管理逻辑**
   ⇒ 无需改 Lua。但**分类不能再写 NUMBER-ONLY** —— 那会让下一个读表的人以为
   四个版本里对焦点五一条机制改动都没有。

**因此 §0 的结论需要一处精确化(方向不变):** 对焦点五,7.41b–e **需要改 Lua 的
改动仍然是零**;但"全部改动都是纯数值"**逐字讲不再成立**(上面第 2 条)。
"零结构性改动、不阻塞任何在跑的工作"这个可操作的结论**不变**。

## 2. ⚠️ 执行前必须先解决的前置项(否则整个工单会做错)

> **2026-09-01T04:xxZ 总监(P0 落地)结清这一条:前置项本身是个误读,但它防的那类
> 错误是真的 —— 而且就藏在这份文件里(见 §2.1)。**

**原文(存档,判定见下):**「datafeed 的 hero id 与经典 `hero_id` 不一定是同一套编号。
本轮拉取里出现了自相矛盾的映射(例如 7.41e 里归在 hero 22 名下的"切换形态不再破隐身、
攻速 30→20"根本不是 Zeus 的机制;7.41c 里"Treant (19)"/"Bristle (155)"也对不上经典编号)。」

**判定:三条"证据"逐条不成立。** 用 `tools/patch/hero_id_map.py` 把 id 与 Valve 自己的
名字表做 join(不是用眼睛读 note 正文):

| 原文的疑点 | join 的读数 | 结论 |
|---|---|---|
| hero 22 的条目"不是 Zeus 的机制" | `hero_id 22 → npc_dota_hero_zuus`,该条目的 `ability_id 1110 → **zuus_lightning_hands**`(魔晶技能,本来就是个开关) | **是 Zeus**,原文误读 |
| "Treant (19)" | `19 → npc_dota_hero_tiny` | 经典编号,**19 从来不是 Treant** |
| "Bristle (155)" | `155 → npc_dota_hero_largo` | 经典编号,**155 从来不是 Bristle** |

后两条的形状值得记一笔:**datafeed 从没打过 "Treant"/"Bristle" 这两个标签,
那是读者自己按印象补的**,然后拿"补出来的名字对不上编号"当成"编号体系对不上"的证据。
⇒ **datafeed 的 hero id 就是经典 `hero_id`**(herolist 127 英雄逐一可查),
`abilitylist`/`itemlist` 同理是权威表。

**但那条"不要凭 patch note 摘要直接改 Lua"的硬规矩照旧成立,而且本轮当场兑现了一次
—— 见 §2.1。** 真正需要留神的前置项换成下面这条:

**⚠ `heroes` 数组里不是每个 `hero_id` 都是英雄。** 7.41c/d/e 各有一条挂在
`hero_id 1961` 名下,它不在 herolist 里;它的 `ability_id 1348 →
`lone_druid_spirit_bear_demolish`` ⇒ 是**熊灵(Lone Druid 的 Spirit Bear),
一个单位不是英雄**。工具把这种 id 报成 `UNKNOWN_HERO` 并把从技能名推出来的归属
打上 `INFERRED` 标签(**永远不计进 resolved**),**不猜**。

**四个版本的 join 读数(`hero_id_map.py --version <v>`,裸读退出码)**:

| 版本 | heroes | abilities | items | 未解析 | exit |
|---|---|---|---|---|---|
| 7.41b | 61/61 | 67/67 | 21/23(+2 节标题) | 0 | **0** |
| 7.41c | 81/82 | 87/87 | 15/15 | 1(=1961 熊灵) | 3 |
| 7.41d | 81/82 | 99/99 | 16/18(+2 节标题) | 1(=1961 熊灵) | 3 |
| 7.41e | 56/57 | 62/62 | 32/34(+2 节标题) | 1(=1961 熊灵) | 3 |

**315 个技能 id 全部解析,零未知**;唯一的未解析 hero id 在四个版本里是同一个熊灵。
(「节标题」= `neutral_items` 里 `is_general_note: true` 的 "Artifacts"/"Enchantments"
表头行,携带 `ability_id: -1`;它们**不是没解析出来的 id**,单独归桶,
否则一条真的解析失败会被埋进这两行的常态噪声里。)

### 2.1 本轮当场兑现的一次:§1 把 Axe 的改动挂错了技能

§1 原表和它下面那段"值得单独记一笔"把 7.41d 的 Axe 施法距离改动
(700/775/850/925 → 600/700/800/900)理解成 **Berserker's Call**,并据此写下
「它改变了新 gated 修复 `axeblink` 的有效窗口」+「英雄组核验时知道这一点即可」。

**join 的读数:那条改动的 `ability_id 5008 → `axe_battle_hunger`` —— 是战斗饥饿,
不是狂战士之吼。** 而 `axeblink` 的判据(`J.ShouldHoldAxeBlinkForCall`,
`jmz_func.lua:9386`)读的是 `axe_berserkers_call` 的 **`radius`**(不是任何施法距离),
它引用的"通用进攻性闪烁分支"用的 `nCastRange` 是**跳刀自己的 1200**
(`ability_item_usage_generic.lua:1516` 的字面量),同样与 Axe 的技能无关。

⇒ **`axeblink` 的有效窗口在 7.41b–e 一格没动**;§1 那段给英雄组的提醒
**前提不成立,作废**。这正是原前置项要防的错误(凭 note 摘要认技能),
只不过它发生在**判定文档自己**身上,而不是在 Lua 里 —— 代码零改动,
所以它没造成损失,**但它已经作为"核验时要知道的事实"发布过一次**。

## 3. 分片清单(每片 = 一个工作单元)

| 片 | 内容 | 依赖 | 影响面 |
|---|---|---|---|
| ~~**P0**~~ | ~~建立 hero id → 内部名的权威映射脚本,并把 §1/§4 的条目重新按内部名核对一遍~~ **2026-09-01T04:xxZ 完成** | 无 | ~~阻塞 P1–P3~~ **P1–P3 解锁** |
| **P1** | 中立物品结构性改动:7.41b **Consecrated Wraps** 的 hallowed 层数改成物品充能(仓库里 5 个英雄的购买表引用了 `item_consecrated_wraps`)、**Demonic Warrior** 移除真视。按 CLAUDE.md 规矩**两份中立物品文件都要改**(`Buff/` + `FretBots/`) | P0 | 中立物品逻辑 |
| **P2** | 天赋替换(不是数值改):7.41c 有 ≥6 个英雄整条天赋被换,7.41e 还有 3 个。逐个改 `tTalentTreeList`。**焦点五一个都不在里面**,所以这片是非焦点英雄的账面维护 | P0 | 非焦点英雄 |
| **P3** | 通用机制变化,影响我们已有的判定逻辑,**优先级高于 P2**:① 7.41c "飞行视野无法看进/看出 Roshan 坑"(与 gated `roshgate` 直接相关);② 7.41d TP 卷轴自购回城落点更靠近远古 + 传送效果部分跟随被移动的引导单位(我们有一整族 TP 纪律 id:`midtp`/`suptp`/`tpcommit`/`tpsafe2`/`tpwatch`);③ 7.41c Bloodstone 配方 600→700g(合成价表) | P0 | gated id 的判读前提 |
| **P4** | 全部核对完之后,才把 `docs/PATCH_UPDATE_GUIDE.md` 的 "Last updated for" 改成 7.41e,并按 guide 记一条更新日志 | P1–P3 | 文档 |

**排期建议**:P3 值得优先(它是唯一可能让**现有 gated id 的判读前提失效**的一片);
P1 次之;P2 可以一直往后排——它对焦点五零影响,是纯账面工作。

### 3.1 P0 交付物(2026-09-01T04:xxZ)

- `tools/patch/hero_id_map.py` —— 把 patch note 里的每个数字 id 与 Valve 自己的
  三张名字表做 join,**解析不出来就单独点名,绝不猜**。
  三个 id 空间各有各的端点(**这是坑**):
  `herolist`(英雄) / `abilitylist`(英雄技能) / `itemlist`(物品);
  **两个技能端点的载荷都挂在 `itemabilities` 这个键下面**,于是 abilitylist 看起来
  像该装物品——它不装(item 208/139 在 abilitylist 里查不到,在 itemlist 里查得到)。
  今天这两张表 **0 个 id 重叠**,所以查错表只会得到 MISSING 而不是一个错名字;
  但那是**今天这份 feed 的实测性质,不是保证**,所以 `check_disjoint()` 把它断言住:
  一旦重叠就 **exit 2 拒绝出证**(重叠会让一个物品 id 解析成一个技能名 —— 错、
  自信、而且安静)。
  退出码沿用仓库惯例:**0 全解析 / 2 没跑成(源缺失、不可解析、不变量破) / 3 有未解析 id**。
  用法:`python3 tools/patch/hero_id_map.py --cache-dir <dir> [--fetch] --version 7.41e [--focus|--json]`。
- `tests/test_hero_id_map.py` —— **40 checks / 0 failed(裸读 exit 0)**。
  变异台 **6 条全红 + CONTROL 绿**,每条变异后 `sha256sum -c` 均 OK(树外 `cp` 还原,
  未用 `git checkout`)。
  **⚠ 方法自伤照实登记:M3(用 `-1` 而不是 `is_general_note` 标志分类)第一遍是绿的。**
  按证据纪律 2 先怀疑断言:那两条规则在原有用例上**逐字同判** —— 那条不带标志的 `-1`
  没有 `title`,于是两种规则都把它归进 unknown 桶。补了**两条能把规则分开的合成用例**
  (带 title 但无标志的 `-1`;带标志但 id 为正的表头)之后,M3 由**四条具名断言**打红。
  这两条现场 feed 从没出现过,**纯语料的测试永远分不开这两条规则**。

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
