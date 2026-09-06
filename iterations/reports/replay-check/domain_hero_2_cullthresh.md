# hero-2 / `cullthresh` —— 条件 (a) 域普查(归档穿越口径)

**交付轮次**:录像检查组 2026-09-06T15:5xZ
**请求**:`iterations/queue.json:hero-2`(总监 §BF.2 `ROUTED_ARCHIVE_SCAN` 放行,零 EC2)
**杠杆**:`bots/BotLib/hero_axe.lua` `X.CullKillThreshold`(gated `cullthresh`,**从未 armed**)
**量具**:`tools/batch_test/behavioral/cullthresh_domain.py`(`--selfcheck` 62 PASS / 0 FAIL)
+ `tests/test_cullthresh_domain.py`(13 tests OK)

---

## 0. 一句话

**域到了,而且是本组连续多轮以来第一个到得干净的域**:69 局里
**501 次带内穿越、69/69 局都有**;可钉帧的采样瞬间 **98 个 / 81 个 episode / 45 局**,
其中 **28 帧落在 175u 之内**(18 个 episode / 16 局)。
`cullthresh` 本身**从未 armed** ⇒ 它的执行状态是 **INDETERMINATE**(语料里没有一帧是它跑的),
但**它要撬的那根分支是 WORKING 的**(见 §4 对照列)——这两件事必须分开记。

```
VERIFY id=cullthresh verdict=INDETERMINATE domain=REACHED crossings=501 games=69/69
VERIFY id=<X.ConsiderR 处决分支,出货腿> verdict=WORKING casts=449 games=69
```

---

## 1. 语料:不是抽样,是**全部可买的供给**

上一轮(09-06T10:02Z)买到的供给前提是「九月归档含 Axe 384 局 / 有 `.dem` 的 190 局」。
本轮换了口径重数,得到的是**另一个数**,两个都登记:

| 量 | 读数 | 口径 |
|---|---|---|
| `replays/` 里带 run 标签的 `.dem` | **780** | 全仓库归档,不限九月 |
| 其中有 `analysis.json` 可读英雄表的 | **780 / 780** | — |
| **`players[].hero` 含 `npc_dota_hero_axe` 的** | **70**(9.0%) | 23 个 run |
| 成功 dump 出时间线的 | **69 / 70** | 1 局 dumper 读不了(GH #258 同族) |

⚠️ **与上一轮 190 的差别要写清楚,不要当成矛盾**:上一轮数的是「九月归档 3,308 局
里含 Axe 的局」并按 run 推算可扫数;本轮数的是「`replays/` 前缀里**实际存在 `.dem`
且其 `analysis.json` 的 `players` 里有 Axe**」的局,**一局一局验的**。本轮这 70 局是
**能真正扫到的全集**,覆盖率 **69/70 = 98.6%**,不是分层抽样 —— 所以下面没有抽样误差这一项。

**侧别分层(铁律 4(i-a),披露)**:语料本身 Axe 在 **radiant 46 局 / dire 23 局**(2:1)。
所有下游计数的侧别比都落在这个比上(穿越 328/173、带内帧 63/35、对照列 409/223),
⇒ 按 **4(i-b)**:检测器计数是**侧偏未消除**的估计量,这里两层**同号且比例与供给一致**,
**没有侧别信号可读**,也**不构成**任何结论的支撑。

---

## 2. 带的定义:按**代码**写,不按申请书写(本轮的第一处订正)

申请书、GH #115、helper 头注三处都把域写成 `(150 + 100*lv, damage[lv]]`。
`X.ConsiderR` 里的比较是

```lua
npcEnemy:GetHealth() + npcEnemy:GetHealthRegen() * 0.8 < nKillDamage
```

—— **严格小于**。所以「出货腿拒、armed 腿收」的充要条件是

```
150 + 100*lv  <=  hp_eff  <  damage[lv]
```

即**左闭右开** `[250,275) / [350,375) / [450,475)`。两个端点**各自换了一侧**:
`hp_eff == 250` **在**域内(出货腿拒它),`hp_eff == 275` **不在**(armed 腿也拒)。
带宽仍是 25,**没有任何已发表的量级因此改变** —— 但**一帧钉不钉得住由端点决定**:
本轮 §5 的 centaur 那一帧 `hp = 350` 整,**只有按代码口径它才在域内**。
钉死在 `tests/test_cullthresh_domain.py::BandIsReadOffTheCode`。

---

## 3. 域读数(穿越口径 = 申请书 2026-08-30 预登记的那个口径)

```
games scanned                      : 69
1 Hz frames                        : 113,753
Axe alive + Culling fully castable : 69,006
  ... eligible enemy inside 375u   : 6,968
  ... eligible enemy inside 175u   : 2,383
eligible in-ring enemy-frames      : 8,786
Culling Blade casts (event side)   : 449
illusion samples discarded (#176)  : 656,762

crossings, 375u ring               : 501   in 69 game(s)
crossings, 175u ring               : 136
expected captures  sum p           : 77.07      (UPPER bound)
health velocity  mean / max (HP/s) : 335.9 / 1855.0
crossings slow enough to be caught : 17  (3.4%,  v <= 25 HP/s)

band-occupied enemy-frames         : 98   in 45 game(s)
band episodes                      : 81   (inside 175u: 18 episodes / 28 frames / 16 games)
  ... target died within 5s        : 58
  ... a Culling cast followed <=2s : 47
```

**三个互相独立的估计量对上了,这是本轮最该信的一件事**:

| 估计量 | 预测带内采样帧 | 来源 |
|---|---|---|
| 穿越模型 `Σ min(1, 25/(v·dt))` | **77.1** | 申请书 2026-08-30 预登记(**上界**) |
| 池模型 `n_ring · 25 / median_maxhp` | **125.4** | 申请书原文(被订正的那个模型) |
| **实测** | **98** | 本轮 |

实测落在两个模型之间,离穿越模型 **+27%**、离池模型 **−22%**。
⇒ 预登记的「上界」读法**在这份语料上没有被违反**(98 > 77 的差来自**带内滞留**:
有目标不是穿过带而是**停在带里**,见 §5 的 medusa 与 ember 两帧),
而池模型的高估也在预期方向。**没有任何一个模型需要事后重挑。**

⚠️ **不要把 `crossings=501` 读成「501 次本可执行的击杀」**。一次穿越只说
「那一秒里目标的血真的经过了那条带」;`p_capture` 中位数很低(平均 336 HP/s ⇒
大多数穿越是**一跳打穿**),那意味着**真实的 bot 在 1/30s 的 tick 上有没有看到带内的那一瞬,
这份 1 Hz 语料答不了**。501 是**域存在性**的证据,98 是**可钉帧**的证据,两者不可互换。

---

## 4. 对照列:被撬的那根分支到底开不开火?(本轮新增,由 §5 的帧逼出来)

一个把「没人到得了的分支」拓宽的杠杆买不到任何东西。所以本轮加了一列
**已经在出货线以下**的瞬间(`hp < 150+100·lv`,其余条件全同),它**不是域**,
**永远不与带内帧并池**(charter 4a 的最简形式,钉在
`tests/test_cullthresh_domain.py::ControlColumnIsNotThePayoffColumn`):

```
instants already under the SHIPPED line : 632   (inside 175u: 172)
  ... 175u 内按 episode 归并            : 141 个 episode
  ... 其中 2s 内真的落了一次 Culling    : 59  (41.8%)
  ... 目标 5s 内反正死了(死于任何来源) : 102 (72.3%)
Culling Blade 施法事件                  : 449  (6.5 次/局)
```

⇒ **`X.ConsiderR` 的处决分支 = WORKING**,不是 SILENT:它每局落 6.5 次大招,
且 175u 内「已经在出货线以下」的 141 个 episode 里有 **59 个**在 2s 内真的斩了。
剩下的 82 个多数是**目标死于队友**(102/141 在 5s 内死掉),不是分支哑火。

**这一列直接决定 hero-2 的价值判断**:杠杆拓宽的是一根**确实在开火**的分支,
所以带内那 98 帧不是「拓宽了一条死路」。

---

## 5. 逐帧核验:8 个瞬间 / 8 局 / 8 个 run(章程下限 6)

先逐帧后聚合。每一条都给了「当时 Axe 能看见什么」。

### 5.1 ⭐ 首选可钉帧 —— 全血核心站在 29u,被定住,出货腿拒斩

`20260905_125159_slot1__spot_20260905_122410_1_54b839d1469eb9a855534644480c8f72399ff7f3_272131`
**t = 874.5,目标 `medusa`,Axe dire,R rank 2(cd=0,mp=401 ≥ 125)**

```
t=873.0  MODIFIER_REMOVE  medusa: modifier_teleporting     <- 她 TP 落地
t=873.5  medusa d=95.9  hp=362  pct=1.000                  <- 满血,且满血就是 362
t=873.8  MODIFIER_ADD    lion -> medusa: modifier_lion_impale   <- 我方 Lion 定住她
t=874.5  medusa d=29.0  hp=362  pct=1.000   AXE hp=2130 mp=401  <<< 焦点帧
t=874.7  DAMAGE  axe -> npc_dota_goodguys_tower1_top  v=40  <- Axe 在打塔
t=876.5  MODIFIER_REMOVE lion -> medusa: modifier_lion_impale
t=877.8  ITEM    necrolyte -> medusa: item_glimmer_cape     <- 她被队友隐身救走
t=878.3  MODIFIER_ADD  necrolyte -> medusa: modifier_invisible
```

rank-2 带 `[350,375)`,`hp = 362` **在带内**。出货腿 `362 >= 350` ⇒ **拒**;
armed 腿 `362 < 375` ⇒ **斩**。当时 Medusa **被 Lion 定住 2.7 秒**、距 Axe **29u**、
**满血**(她的血池就是这么低,mana shield 吃伤害 —— 独立核对:她死前 25s 内承伤
**1,308**,血只掉 **830**,差额正是 mana shield,所以 `hp` 这一列本身是准的)。
Axe 那一瞬在**打塔**。Medusa 下一次死亡在 **192 秒之后**。

> **这是本请求 `acceptance` 明写要的那个 `(game, t)`。** 建议英雄组直接
> `make_fixture.py <timeline> --t 874.5 --hero axe` 钉住「shipped 不放、armed 放」。

### 5.2 一秒的提前量 = 一个跑掉的 PA

`20260829_004436_slot1__spot_20260829_001650_1_72a8cf754e99683e6472f404cfe6c8bbec7617c3_638395`
**t = 939.5,目标 `phantom_assassin`,Axe radiant,R rank 2**

```
t=936.4  ABILITY/DEATH  axe -> sven  axe_culling_blade      <- 斩杀成功,大招 CD 被刷新
t=938.5  pa hp=468  d=134.6
t=939.5  pa hp=354  d= 70.7   R(cd=0)                       <<< 带内 [350,375)
t=940.5  pa hp=220  d=148.0   R(cd=0)   <- 已在出货线以下,仍在 175u 内
t=941.5  pa hp=195  d=407.7                                 <- 跑出环
```

armed 腿在 **939.5** 就收(354 < 375),出货腿要等到 **940.5**(220 < 350)。
实际结果:**一次都没斩**,PA 带着 195 血跑掉,**379 秒后才死**。
⇒ 这一帧同时是**杠杆的收益侧证据**和**出货腿边界的成本证据**:
940.5 那一帧出货腿条件已满足却没落地,而 941.5 她就出环了 ——
1 Hz 语料**无法**区分「bot 没选它」与「真实在环内的窗口 < 0.3s 施法前摇」,
所以这里**只登记现象,不下 BUGGY 判词**。

### 5.3 rank-3 带,目标随即隐身

`20260828_063300_slot1__spot_20260828_061645_..._60e52a` **t=1293.4,`lion`,rank 3**
`hp=457` ∈ `[450,475)`,d=82.7。**1293.7 lion 开雾隐(glimmer),1294.2 invisible。**
armed 腿在隐身**前 0.3 秒**收得住;出货腿(457 ≥ 450)收不住。
Lion 2.6s 后仍死于 `axe_counter_helix` ⇒ **域成立,净收益小**。诚实登记。

### 5.4 ⚠️ 反例:armed 腿会往 False Promise 里砍

`20260828_123152_slot1__spot_20260828_121642_..._11c470` **t=1015.5,`ember_spirit`,rank 2**
`hp=362` ∈ 带内,d=120.6。**但 1015.4(焦点帧前 0.1 秒)`oracle_false_promise` 落在他身上**
(`MODIFIER_ADD ember_spirit modifier_oracle_false_promise_timer`,同 tick)。
False Promise 期间目标不能死;这一斩**会被浪费**(大招进 75s CD)。
`X.HasSpecialModifier` 的七个名字里**没有** `modifier_oracle_false_promise_timer` ——
**这是一个独立于 `cullthresh` 的既有缺口**,而且**不是假设**:全语料
`axe_culling_blade` 的 **449 次施法里有 2 次真的落在 False Promise 窗口内部**
(`20260828_124358_slot1__spot_20260828_121642_1_4b2ee33416df1f41617387c93838052296c2aab7_11c470`
**t=958.7 → sniper**、
**t=1452.9 → oracle**)。出货腿在 350 以下同样会砍进去 ⇒ 本轮按新问题开 issue,
**不作为 `cullthresh` 的阻塞项**。语料里该 modifier 的真名只有 `..._timer` 一个
(52 次 ADD/REMOVE),**照抄这个名字,不要写 `modifier_oracle_false_promise`**。

### 5.5 抢刀 0.6 秒,可能挤掉另一次斩

`20260905_123920_slot1__spot_20260905_122410_..._272131` **t=1314.5,`ogre_magi`,rank 3**
`hp=473` ∈ `[450,475)`,d=128.6,被 Lion 定住。**1315.1 ogre 死于 dragon_knight;
1315.6 Axe 把大招落给了 `shadow_shaman` 并斩杀。**
⇒ armed 腿若在 1314.5 斩 ogre,**队友那颗人头变成 Axe 的**,但 **1315.6 对
shadow_shaman 那次斩就没了**(CD 75s)。**不是每个带内帧都是净赚** —— 登记。

### 5.6 175u 边界上的一帧

`20260902_033228_slot1__spot_20260902_033141_1_main_26717d` **t=1346.5,`lich`,rank 3**
`hp=460`,**d=173.7(175u 之内,擦边)**。lich 0.4s 后死于小兵。收益 = 一颗人头的归属。

### 5.7 出货腿在 0.8 秒后自己接住了(WORKING 的正面帧)

`20260829_004509_slot1__spot_20260829_001654_..._9d4293` **t=643.4,`shadow_shaman`,rank 2**
`hp=365` ∈ 带内,d=85.1。**644.2 Axe 斩杀成功**(那时血已掉到 ~107)。
⇒ 杠杆在这里只买到 **0.8 秒**提前量。**这一帧是 §4 那句「分支 WORKING」的现场版。**

### 5.8 端点帧:`hp = 350` 整

`20260828_121728_slot1__spot_20260828_121638_..._460956` **t=640.9,`centaur`,rank 2**
`hp = 350` 整,d=87.0。**只有按 §2 的代码口径(左闭)它才在域内**;按申请书的散文口径
(左开)这一帧会被丢掉。Axe 那 0.6 秒后把大招给了 `pudge`(斩杀成功),
centaur 带着 336 血跑掉,**148.7 秒后才死**。

---

## 6. 量具与反面钉死

- `tools/batch_test/behavioral/cullthresh_domain.py` —— `--selfcheck` **62 PASS / 0 FAIL**;
  `--frames` 打可钉帧与穿越清单;`--list-modifiers` 打这份语料里真实出现过的守卫名单。
- `tests/test_cullthresh_domain.py` —— **13 tests OK**,从**反面**要求量具拒收本轮头条
  三种可能被造出来的形状:
  1. **幻象**(本语料丢弃 **656,762** 个同名快照样本 —— 幻象血低,按名字取帧会把
     一份幻象普查写成英雄普查,GH #176 的出生时刻守卫是唯一挡住它的东西);
  2. **穿越不定向**(把回血/复活的上穿也算进去,头条免费翻倍);
  3. **不检 cd / 蓝 / 等级 / 排除名单**(把地图当成分支来数)。
  外加 §2 的端点与 §4 的「一帧只能进一列」。

---

## 7. 结论与下一棒

1. **条件 (a) 的**域**这一半买到了,而且是干净的**:`DOMAIN-REACHED`,
   501 穿越 / 69 局全覆盖 / 98 个可钉采样帧 / 18 个 175u 内的 episode。
2. **`cullthresh` 的执行核验仍是 INDETERMINATE** —— 它从未 armed
   (`test_set.md` 里 `cullthresh` 出现 **0** 次),语料里没有一帧是它跑的。
   要买到「真的执行且行为正确」,**必须有一波把它 armed**。
3. **§5.1 那一帧是本请求 `acceptance` 点名要的 `(game, t)`**,交给英雄组钉 fixture。
4. **P4.2 入集冻结期内本组不申请入集**,只交读数与可钉帧。合法裁定是 `FROZEN-HOLD`。
5. **新问题(与本杠杆无关,独立开 issue)**:`X.HasSpecialModifier` 缺
   `modifier_oracle_false_promise`(§5.4 的实帧)。
