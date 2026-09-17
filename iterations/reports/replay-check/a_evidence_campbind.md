# 条件 (a) 证据:soak candidate `campbind`,真帧 fixture 路径

**执行**:录像检查组(replay-check),2026-09-17
**结清的 owed 行**:`iterations/owed_executions.json:campbind_condition_a_fixture`
**裁定出处**:`iterations/streams/test_set.md §FX`(`campbind` RETURNED_FROM_ARMED_SET,
disposition `DOMAIN-NOT-REACHED-IN-WAVES`,armed 46 → 45;⛔ 不是 reject)
**走的是哪条出路**:**(甲) fixture 路,成了。**⛔ 不是 (乙)。

```
VERIFY id=campbind verdict=BUGGY episodes=2
```

---

## 0. 一句话

**裁定点名的那一帧取回来了,而它比裁定预期的多说了一件事:`campbind` 在 t=330.7 上
决策正确(计划营 ≠ 最近营,armed 答计划营),在 4 秒后的 t=334.7 上决策错误 ——
被它答出来的那只小野,可以在同一帧上被证明属于它本该排除的那个营地。**

⭐ 两个读数出自**同一次拉营**、**同一个 helper**、**同一份 1200u 判据**;
差别只有一件事:**中间那 4 秒里小野被拖动了**。而拖动**正是拉营这件事本身**。

---

## 1. 先结清那条「我现在核不了的前提」(§FX.5 第 3 条 / §FX.6 第 1 条)

裁定把一条前提连同后果一起挂着:目标帧属于 W46,timeline 已随容器回收,
**`.dem` 还在不在 S3 没有核**;若取不回来,该行**当场转永久退集**(`DOMAIN-NOT-REACHED`)。

**核了。取得回来。** 裸读输出:

```
$ awsx s3 ls s3://dota2bot-batch-results-4924/soak/spot_20260904_123127_1_efa7ba70095a9151930e8b1b96a9d16449c1a1f3_b77771/
   (160 行,扩展名只有 .analysis.json / .demclaim.json / .log.gz —— 0 个 .dem)
   2026-09-04 13:09:59       6940 20260904_125801_slot6.analysis.json
   2026-09-04 13:10:00        436 20260904_125801_slot6.demclaim.json
   2026-09-04 13:09:58      21322 20260904_125801_slot6.log.gz

$ awsx s3 ls s3://dota2bot-batch-results-4924/dem21/spot_20260904_123127_1_efa7ba70095a9151930e8b1b96a9d16449c1a1f3_b77771/
   (32 行,全是 .dem)
   2026-09-04 13:10:01   22122712 20260904_125801_slot6.dem
```

⭐⭐ **⛔ 一个「`soak/<run>/` 下没有 `.dem`」的读数不是「`.dem` 没了」,而按裁定写死的
后果,把它读成后者会当场把这一行永久退集掉。** 分界线在 `dem_claim.sh` 的
`dem_bulk_prefix()`:`REC_SLOTS > 1` 时 `.dem` 走 **桶级 `dem21/<run>/` 前缀**
(那里有一条不需要 `s3:PutObjectTagging` 的纯前缀 lifecycle 规则),
`soak/<run>/` 只留**永不过期的逐局归档**(`.analysis.json` / `.log.gz` / `.demclaim.json`)。
⇒ **查 `.dem` 在不在,必须查 `dem21/`,查 `soak/` 得到的恒是 0 个。**

⏳ **时限是真的**:该对象 `2026-09-04 13:10:01` 上传,21 天 lifecycle ⇒ 约 **2026-09-25 到期**
(距本轮 **8 天**)。本轮取到并落盘成 fixture,**这条时限从此对该行失效**。

---

## 2. 语料与仪器

| 项 | 值 |
|---|---|
| 源 | `dem21/spot_20260904_123127_1_efa7ba70095a9151930e8b1b96a9d16449c1a1f3_b77771/20260904_125801_slot6.dem`(22,122,712 B) |
| 波次 | **W46**(62-id 家族;`campbind` 09-04T10:13Z 入集,W46 起首次生效) |
| dumper | `behav-dump`(cache key `46fe9c6a2b084f9b`,S3 cache HIT) |
| 采样 | `-creep-interval 0.25 -interval 0.25` ⇒ 两帧的小野样本 **dt = 0.1**,⛔ 不是批测农场默认的 3.0s |
| 时基 | dumper 的 `t` = game-clock seconds(0 = horn),与 `DotaTime()` 同基 |
| 产物 | `tests/frames/f_260904_125801_campbind_poke_3307.lua`、`..._3347.lua` |
| 断言 | `tests/test_campbind_poke_real_frame.lua`,**7 tests / 0 failures** |

**战斗日志逐字(dump 的 `events`,裁定点名的就是这两条)**:

```
330.7  DAMAGE  npc_dota_hero_spirit_breaker -> npc_dota_neutral_forest_troll_berserker
334.7  DAMAGE  npc_dota_hero_spirit_breaker -> npc_dota_neutral_kobold_taskmaster
```

即**出厂的戳在 4 秒内打了两个不同营地** —— 这正是 `campbind` 立项要停掉的行为。
主体:spirit_breaker,team 2(Radiant),`player_id 4`(pos4),level 5,net_worth 1984。

### 2.1 ⚠️ 一个必须写下来的仪器边界:`bot:GetNearbyNeutralCreeps` 这条路在 fixture 上是瞎的

`tests/mock/replay_fixture.lua`(`tOpts.neutrals` 分支)把中立单位**从主体的
`recent_damage` 行里合成出来**,并且给每一个都赋**主体自己的坐标**
(`GetLocation = Vector(u.x, u.y, 0)`)。⇒ 合成出来的小野**彼此距离恒为 0、离 bot 距离恒为 0**,
而 `campbind` 的全部内容就是「**哪只小野离计划营地近**」
⇒ **走那条路问这个问题,答案与帧无关** —— 与 §FW.2 那一型**同形**(仪器瞎,不是域空)。

⇒ 本文件的 `tNeut` **从 fixture 自己的 `creeps` 块构造**(team 4,真 x/y,无名无血量 —— 这是 `.dem` 的全部)。
施加引擎对 `GetNearby*` 的两条成文性质:半径过滤(调用点问 1400)+ 「按距离排序,最近在前」
(`docs/BOT_API_REFERENCE.md:1229`)。⭐ **顺序是「声明的」不是「dump 出来的」**,
`.dem` 不携带表顺序;§7 登记了这件事各自许可了什么、没许可什么。
📌 已单独开 issue(见 §6)。

---

## 3. t = 330.7 —— 决策正确,而且这是 owed 行索要的那一条断言

bot 在 `(-4174.5, 4781.6)`。1400u 内 **10 只**中立单位,构成**两个箱子**
(600u 单链聚类;两个箱子各自的最大展布 73.6u / 60.9u ⇒ **都在原地没动**,
阈值取 (150, 1200) 里任何值结果相同):

| 箱子 | 数量 | 质心 | 离 bot 最近 |
|---|---|---|---|
| 近箱(forest troll) | 6 | `(-3921.0, 4806.3)` | **194.3** |
| 远箱(kobold) | 4 | `(-4860.6, 3893.0)` | **1085.2** |

**质心间距 1310.3 > `PULL_CAMP_NEUTRAL_RANGE` = 1200** ⇒ helper 自己的半径**恰好把两个箱子分开**。
逐单位读数(每只对两个箱子各算一次距离):

```
d_bot=  194.3   d_kobold= 1280.6 out   d_troll=   68.5 IN
d_bot=  224.1   d_kobold= 1295.8 out   d_troll=   34.6 IN
d_bot=  252.7   d_kobold= 1309.7 out   d_troll=    2.4 IN
d_bot=  279.5   d_kobold= 1352.1 out   d_troll=   44.9 IN
d_bot=  294.3   d_kobold= 1295.9 out   d_troll=   73.6 IN
d_bot=  296.7   d_kobold= 1332.3 out   d_troll=   45.1 IN
d_bot= 1085.2   d_kobold=   60.9 IN    d_troll= 1280.0 out
d_bot= 1122.3   d_kobold=   51.4 IN    d_troll= 1302.5 out
d_bot= 1131.5   d_kobold=   39.8 IN    d_troll= 1324.5 out
d_bot= 1155.0   d_kobold=   47.1 IN    d_troll= 1337.5 out
   -> 在 kobold 箱 1200u 内: 4 | 在 troll 箱内: 6 | 同时在两个箱内: 0
```

⭐ **「同时在两个箱内 = 0」是这一帧可判读的全部理由**,`tests/test_campbind_poke_real_frame.lua §1` 断言它。

**决策读数**(`§2`/`§3`/`§4`):

| 配置 | vCamp | `J.GetCampPullPokeTarget` 返回 |
|---|---|---|
| 出厂(gate 关) | 任一 | `tNeut[1]`(troll 箱,194.3u) |
| armed | **kobold 箱** | **一只 kobold** —— ⛔ 不是 `tNeut[1]`,两者相距 > 1200 |
| armed | troll 箱 | `tNeut[1]`(与出厂逐字相同) |
| armed 但非 Turbo | kobold 箱 | `tNeut[1]`(杠杆惰性) |

⇒ **owed 行索要的那句断言成立**:armed 返回的**计划营地**与 `tNeut[1]` 的**最近营地**
是**不同的箱子**。⭐ 而这正是 §FX.4 在 **97 局两份独立语料**上只量到 **1 次、且不可归属**的那个可判读面 ——
fixture 断言的是**决策**,⛔ 不需要位移归属,那道 **250u 阈值在这里不存在**。

⚠️ **哪一个箱子是当时真正的计划营,不可恢复**:`bot.roamCampPull` 来自 `GetNeutralSpawners()`,
是引擎地图数据,`.dem` 不携带。⇒ 本文件**两个指派都断言**(§3 与 §4),⛔ 不猜其中一个。

---

## 4. t = 334.7 —— 同一次拉营,4 秒后,同一个判据答错

同一个 helper、同一份 1200u 判据、同一对箱子(箱子坐标取自 §3 那个**两营皆静止**的帧)。
bot 已走到 `(-4674.5, 4318.7)`:

```
d_bot=  175.6   d_kobold=  637.2 IN    d_troll=  736.2 IN     <-- tNeut[1]
d_bot=  417.4   d_kobold=   60.9 IN    d_troll= 1280.0 out
d_bot=  464.8   d_kobold=   39.8 IN    d_troll= 1324.5 out
d_bot=  478.3   d_kobold=   51.4 IN    d_troll= 1302.5 out
d_bot=  504.6   d_kobold=   47.1 IN    d_troll= 1337.5 out
d_bot=  563.7   d_kobold= 1021.1 IN    d_troll=  413.9 IN
d_bot=  705.0   d_kobold= 1150.0 IN    d_troll=  254.6 IN
d_bot=  856.7   d_kobold= 1280.6 out   d_troll=   68.5 IN
d_bot=  896.4   d_kobold= 1309.7 out   d_troll=    2.4 IN
d_bot=  898.5   d_kobold= 1295.9 out   d_troll=   73.6 IN
   -> 在 kobold 箱内: 7 | 在 troll 箱内: 6 | **同时在两个箱内: 3**
```

**§3 的分割没了。** 而且**不是因为营地动了** —— 营地是箱子,箱子不动;
动的是**被拖出来的小野**。

**那 3 只里最靠前的一只就是 `tNeut[1]`**(175.6u)⇒ 计划 kobold 营时,
armed 返回的是 **`tNeut[1]` 自己**,即**出厂答案**。`campbind` 在这一帧上**没有绑住任何东西**。

### 4.1 ⭐⭐ 钉死「它是一只 troll」:0.25s 逐样本反向最近邻追踪

`creeps` 没有 id,所以**归属靠连续性买,不靠名字**。对 `t=334.8` 那只
`(-4571.0, 4460.6)` 做反向追踪(每步位移都远小于断链阈值 400u,**全程无跳变**):

```
t=334.80  (-4571.0, 4460.6)  step= 49.3   d_kobold= 637.2  d_troll= 736.2
t=334.00  (-4491.2, 4570.2)  step= 86.3   d_kobold= 771.4  d_troll= 617.1
t=333.30  (-4388.7, 4738.5)  step=147.9   d_kobold= 968.3  d_troll= 472.6
t=332.50  (-4107.2, 4767.6)  step=147.8   d_kobold=1154.4  d_troll= 190.2
t=331.50  (-3984.1, 4766.5)  step= 24.6   d_kobold=1237.4  d_troll=  74.6
t=331.30  (-3953.4, 4818.3)  step= 60.2   d_kobold=1295.8  d_troll=  34.6
t=331.00  (-3953.4, 4818.3)  step=  0.0   d_kobold=1295.8  d_troll=  34.6
t=330.80  (-3953.4, 4818.3)  step=  0.0   ...
  ...  t=328.00 起逐样本坐标逐位相同(静止 >= 3 秒)
```

⇒ **t=330.7 时它坐在 `(-3953.4, 4818.3)`:离 troll 箱 34.6u、离 kobold 箱 1295.8u,
且此前 3 秒一动没动。它是一只被拖出来的 forest troll。**
与 §2 战斗日志一致:331.3s `forest_troll_berserker` 开始打 spirit_breaker。

### 4.2 缺陷的形状(⚠️ 这是判据的缺陷,不是这一帧的巧合)

helper 把「**属于计划营地**」实现成「**离计划营地那个点 ≤ 1200u**」。
⇒ **一只已经被从另一个营地拖出来的小野,满足这个判据。**
而拉营**就是把小野拖出来**,所以这个失效模式**长在杠杆自己的作用域正中间**,
⛔ 不是边缘情况:两个箱子间距 1310u,只要另一箱的小野朝计划营方向走出 ~110u 就进来了。

⭐ **归属证明不依赖「当时计划的是哪个营」**:追踪证明这只单位属于 troll 箱,这是帧的性质;
「它是否真的被错误地答出来」才依赖计划营。⇒ 本报告把两件事分开写。

### 4.3 ⛔ 这**不是**单调性失效

入集裁定的安全论证是「armed 的戳集 ⊆ 出厂戳集」。**那条仍然成立** ——
armed 的答案永远是 `tNeut` 的成员,只会更少不会更多。
§4 证伪的是**绑定主张**(注释逐字:`POKE THE CAMP WE PLANNED`),⛔ 不是安全论证。
⇒ 判 **BUGGY 不判 reject**:这是行为不正确,不是有害。

---

## 5. 仪器自证:变异台 3 变异 3 CAUGHT

⛔ 绿测试可以因为错误的理由而绿。逐条(改 `bots/FunLib/jmz_func.lua` 的副本,跑,还原):

| 变异 | 预期被谁抓 | 实测 |
|---|---|---|
| M1 `PULL_CAMP_NEUTRAL_RANGE` 1200 → 2000 | §3(kobold 半径吞掉 troll 箱 ⇒ 退化成 `tNeut[1]`) | **CAUGHT**,恰是 §3,1 failure |
| M2 删掉 `campbind` 闸(恒生效) | §2(出厂腿不再答 `tNeut[1]`) | **CAUGHT**,恰是 §2,1 failure |
| M3 距离判据 `<=` → `>=` | §3 / §4 / §6 | **CAUGHT**,3 failures |

还原核对:`sha256sum -c` → `bots/FunLib/jmz_func.lua: OK`。
⛔ 三次变异的退出码都是**直接读的**,未经管道。

---

## 6. ⚠️ 一处**有意的偏离**,连同它的实测代价一起登记

owed 行的裸读验收句逐字要求「一个新的 **`tests/fixtures/`** 帧」。**本轮没有放进 `tests/fixtures/`,
放进了 `tests/frames/`。** 理由是量出来的,不是偏好:

```
                                    无本轮两帧      有本轮两帧
test_axe_hunger_camp_reach          23 tests, 0 failures  →  23 tests, 2 failures
test_cm_kill_confirm_quantifier     13 tests, 0 failures  →  13 tests, 1 failures
test_fieldcreep_magnitude_operand    7 tests, 0 failures  →   7 tests, 2 failures
```

逐字红线:`the corpus moved: 144 frames, was 142`、`unit rows across the corpus: 1440, was 1420`。
⇒ **trunk 在这三个文件上是绿的,本轮两帧把 5 条断言顶红。**

`tests/fixtures/` **同时是普查语料**(约两打测试 glob 它并在其上取读数),
`tests/frames/README.md` 就是为这件事存在的:**帧是真的、同一个脚本生成的、按名字加载,
但留在 glob 之外,直到有人专门付那份账**。⭐ 把两帧塞进 `tests/fixtures/` 只会让
**一个绿的树变红**,而那些普查断言**正是为了让语料移动被专门付账**才存在的。

⇒ **实质(真帧 fixture + 那条断言 + `VERIFY` 行)逐条交付;差别只有货架。**
入集这两帧到 `tests/fixtures/` 是**另一个工作单元**,价钱已量在上表(至少 3 文件 / 5 断言),
已按 README 的惯例登记进 `tests/frames/README.md` 的表。
⛔ **本轮不自行改写 owed 行的验收句** —— 措辞是不是该从「`tests/fixtures/` 的帧」
放宽成「真帧 fixture(含 `tests/frames/` 的暂存货架)」,**编排权在总监**。

---

## 7. 诚实边界(本文件**没有**做到的事)

1. **没有买到「哪个营是当时的计划营」** —— `GetNeutralSpawners()` 是引擎地图数据,
   `.dem` 不携带。两个指派都断言,⛔ 不猜。⇒ §4 的错误答案**在计划营是 kobold 时成立**;
   计划营若是 troll,那一帧的答案反而正确。**但 §4.2 的判据缺陷与计划营无关。**
2. **没有证明这些 poke 帧真的到达了这个 helper** —— 调用点在 `bot.roamCampPull ~= nil`
   和 3s 节流后面,两者 dump 都不携带。战斗日志显示戳确实落了,这是本语料能到的最近处。
3. **`tNeut` 的表顺序是声明的不是 dump 的** —— `.dem` 不携带顺序。
   ⭐ **这件事对两个结论的影响不对称,已钉在 §7**:§3 的结论**与顺序无关**
   (troll 箱被整体排除,任何顺序都只能答 kobold);§4 的结论**依赖顺序**
   (helper 用 `pairs` 返回**第一个**落在半径内的成员)。
4. **没有说 armed 更好** —— 条件 (b) 是批测的问题,§FX.4 已把它读成噪声(W53 三粒 arm 极差 64.1)。
5. **⛔ 本轮没有为 `campbind` 请求任何波次** —— 它已退集,arm 串里没有它;
   本行要的是条件 (a),不是重新入集。重新入集与否**编排权在总监**。

---

## 8. 成本三段(铁律 1 / RULING 48)

**零 EC2 / 零 CE / S3 读取 2 个对象(出网未计价)** = 1 个 `.dem`(22.1 MB,dump 后保留在容器内,未入库)
+ 1 个 dumper 二进制(cache HIT);另 **2 次 `s3 ls`**。⛔ 不写「零支出」。
