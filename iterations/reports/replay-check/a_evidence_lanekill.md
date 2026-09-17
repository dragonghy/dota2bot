# `a_evidence_lanekill` —— `l1trade` / `l5combo` 的条件 (a),买在**波次录像**上

**投递物**,结清 `iterations/owed_executions.json:owed[lanekill_condition_a_detector]`
(`done_when` = `path_exists iterations/reports/replay-check/a_evidence_lanekill.md`)。
录像组 W87,2026-09-17T09:56Z。⛔ `bots/` + `game/` 一行未改;零 EC2,零 CE。

---

## 0. 一句话

**域不空 —— 这正是本行立案时怕被写错的那一句。**
波次录像上两条 helper 的可观测门在 55 局里给出 **2205 个 episode**
(`l1trade` ACTIVE 581 / `l5combo` ACTIVE 571),而 §FW.2 那条 fixture 路线在同一对
helper 上读到的是 **0 fires**。**两个数不矛盾:那个 0 是仪器状态(出向爆发估计恒为 0),
这 2205 是域的大小。**
**但本轮买不到归因**:同一份语料里,**一个可证为假的安慰剂分层**(`l5combo` 的
VETO 带,`>=2` 敌在 700u 内 ⇒ 门必假)扛着 **比活带更大、更跨种子一致**的 arm
(`arm[kill] = +0.298`,3/3 粒种子同号),而 episode 计数在**每一个带**上都偏向 armed 腿
(ACTIVE +0.80、VETO +1.43、OUT +1.09 每局)⇒ **本语料里没有任何一个 arm 能记到这两个 gate 名下。**

```
VERIFY id=l1trade verdict=INDETERMINATE episodes=581
VERIFY id=l5combo verdict=INDETERMINATE episodes=571
```

⚠️ **INDETERMINATE 的理由是归因,不是缺席** —— 与 W85 `arbheart` 同型(两个机制都支持同一结论、分不开),
⛔ **不是** `l1xpsoak` 那种「域在构造上不可达」。**下面 §5 写明买到它需要什么、以及为什么那扇门正在关上。**

---

## 1. 语料(全部已归档,零新局)

波次 **`spot_20260907_0622xx_1_523f21ba…`** 的四台实例,发波时刻 **2026-09-07T06:22Z**,
**早于**两条 id 被退集的 09-07T19:xxZ ⇒ arm 串里**逐字第一、第二位就是它们**:

```
mirror:l1trade,l5combo,tpcommit,lf_rescue,teambrain,ownhalf,overchase,fieldregen,wandbleed,
capmono,cmrguard,tpdead,zusult,wandlimbo,blinkflee,liondrainstop,odaoe,pullcamp,stayfield,
stayfield2,fieldbuy,pullcad,pulllane,pulldrag,tpgap,campsel,tbearly,tpdeathbuy,campfarm,
abilanc,bbfight,bbshort,pullthink,aimguard,campvoid,wkqdmg,fieldsip,creepthink,lionqdmg,
cmqreach,rotscope,roamidle,outlatch,illureal,slotarb,slotdust,slotpush,wandbleed2,arbheart,
campbind,zusboltdom:s<seed>:<side>
```

**51 个 id 同时 armed。这一条是本轮结论的全部支点,记住它。**

| run 尾号 | 种子 | 有效镜像局(radiant / dire) | `SWEEP_EXIT` | `unparseable` |
|---|---|---|---|---|
| `f7fa97` | 7144 | 10 / **0** | 0 | 0 |
| `8bd33f` | 7154 | 10 / 8 | 0 | 0 |
| `dc6b6d` | 7156 | 16 / 2 | 0 | 0 |
| `5acea8` | 7162 | 18 / 1 | 0 | 0 |

**宽扫 65/65 有效镜像局**(暖场局 24 个由 `sweep_run.sh` 自动跳过,`script_version` 无 `mirror:` 前缀)。

⚠️ **种子 7144 无 dire 腿 ⇒ `strata.pairing()` 判整份语料 not paired**(它的设计就是这么严的)。
**估计量因此跑在 7154/7156/7162 三粒上(55 局)**;7144 那 10 局的分层读数照 (i-a) 登记在 §3,
**但不进 arm** —— 一个没有对腿的分层差里,阵容项没有东西可抵消。

⭐ **为什么三粒里两粒的 dire 腿只有 2 局和 1 局**:`validate_onspot.sh:88-89` 是
**先 radiant 波、再 dire 波**(`deploy_wave radiant … ; deploy_wave dire …`),
所以一台被时间帽/抢占截断的实例**丢掉的恒是 dire 腿**。
本波 4 台里 3 台是这个形状(0/2/1 局)。⇒ **「截断只丢局数」是错的:它丢的正是消侧偏所需的那一半。**
这条不是本行的结论,是读本行读数时必须带着的前提;**未开单**(见 §6 的处置)。

---

## 2. 量具与它的边界

**主量具:`tools/batch_test/behavioral/lanekill_commit.py`(树上已有,非本轮新建)** ——
它把两条 helper 自己的门逐条转写到帧上(role / 敌距 800·900 / 背靠队友 1000u@>=40%HP /
深度 800·400 / l5combo 的 700u 双敌否决),常量由
`tests/test_detector_source_constants.py` 钉在源码站点上(本轮实跑 **EXIT=0**,
`lanekill_commit.{ENEMY_RANGE_CORE,ENEMY_RANGE_SUP,SUP_CLOSE_RANGE,DEPTH_CORE,DEPTH_SUP,ALLY_HP_MIN}` 逐条 `ok`)。

**本轮新增的薄读数层:`tools/batch_test/behavioral/lanekill_strata.py`** ——
⛔ **不重建域**(逐字复用 `lanekill_commit.scan`),只加三样:
`arm_side`(那一局 armed 腿坐在哪个物理队)、**两个分层的读数全登记**(铁律 4 (i-a))、
以及 `strata.py` 的配对 arm(**先每粒种子 swap-average、再跨种子取算术平均**,(i-d);
share 类量走 `per_seed_share_arm`,每局计数类量走 `per_seed_arm`)。
⭐ **控制带也用同一个估计量算 arm** —— 一个带只有被同样地读,才算控制带。

### ⛔ 继承下来的超集边界(每次引用本文件都要抄这一段)

`GetEstimatedDamageToTarget` **不在 dumper 流里**,于是两条 helper 的
**最后一条合取(致命性:我方合计爆发 >= 目标 HP + 4s 回血)**与**自风险门**
(`nIncoming >= HP*0.75` / `*0.6`)**离线都不可判**。
⇒ 本文件的每一个 episode 都是**真实触发帧的超集**,`victim hp_pct <= 0.40` 是
GH #41 借来的**代理**,不镜像源码里的任何一句。
⇒ ⛔ **本文件不声称「门在这一帧为真」**;它声称的是「门的**可观测**合取在这一帧全真,
而 armed 腿在这批帧上的行为是这样」。**这正是 §FW.2 说 fixture 那条路买不到的东西,
也正是为什么这条路值得走。**

---

## 3. 两个分层的读数(铁律 4 (i-a):全登记,不论同号反号)

**三粒配对种子(55 局),ACTIVE 带,share = 该分层内的 episode 占比,`d = armed − baseline`:**

| 支 | 分层 | n(armed/base) | commit | commit_attack | kill | switch | no_dmg |
|---|---|---|---|---|---|---|---|
| l1trade | radiant | 277 / 211 | .704/.787 **d=−.083** | .563/.602 d=−.039 | .426/.441 d=−.015 | .072/.085 d=−.013 | .206/.114 d=+.092 |
| l1trade | dire | 41 / 52 | .878/.750 **d=+.128** | .561/.615 d=−.054 | .268/.365 d=−.097 | .024/.000 d=+.024 | .098/.231 d=−.133 |
| l5combo | radiant | 268 / 216 | .780/.731 d=+.048 | .593/.495 d=+.098 | .366/.356 d=+.009 | .067/.051 d=+.016 | .146/.194 d=−.049 |
| l5combo | dire | 50 / 37 | .660/.622 d=+.038 | .420/.459 d=−.039 | .160/.297 d=−.137 | .060/.081 d=−.021 | .240/.243 d=−.003 |

**未配对的种子 7144(10 局,radiant 腿,⛔ 不进 arm,照 (i-a) 登记)**:
`l1trade` ACTIVE armed n=88 / base n=44,`commit` .977/.955、`commit_attack` .591/.750、`kill` .193/.409;
`l5combo` ACTIVE armed n=105 / base n=40,`commit` .657/.675、`commit_attack` .419/.500、`kill` .210/.500。

⭐ **`l1trade` 的 `commit` 两层反号** —— 照 **(i-e)(甲)** 这**不是**否决理由,层内 delta
只是中间量;估计量是 arm,见 §4。照 **(i-a)** 在这里先登记完。

---

## 4. 估计量:arm(每粒种子 swap-average → 跨种子算术平均)

**`l1trade`**

| 带 | arm[episodes/局] | arm[commit] | arm[commit_attack] | arm[kill] | arm[no_dmg] |
|---|---|---|---|---|---|
| **ACTIVE**(门可真) | **+0.801** spread .208 **3/3** | **+0.072** spread **.044** **3/3** | +0.033 spread .104 2/3 | −0.012 spread .188 1/3 | **−0.050** spread .051 **0/3**(即 3/3 同为负) |
| **OUT**(声称门必假) | +1.089 spread 1.299 3/3 | −0.005 spread .113 2/3 | +0.006 spread **.510** 2/3 | +0.023 spread .311 2/3 | −0.019 spread .073 2/3 |

**`l5combo`**

| 带 | arm[episodes/局] | arm[commit] | arm[commit_attack] | arm[kill] | arm[switch] | arm[no_dmg] |
|---|---|---|---|---|---|---|
| **ACTIVE** | **+2.418** spread .669 3/3 | −0.091 spread **.448** 1/3 | −0.030 spread **.358** 1/3 | −0.106 spread .103 **0/3** | +0.033 spread .178 2/3 | +0.057 spread .221 1/3 |
| **VETO**(门**可证为假**) | **+1.433** spread 1.638 3/3 | −0.062 spread **.033** **0/3** | +0.053 spread .424 1/3 | **+0.298** spread .355 **3/3** | +0.022 spread **.010** **3/3** | +0.039 spread .044 **3/3** |
| **OUT** | +1.116 spread 2.035 3/3 | +0.067 spread .067 **3/3** | +0.110 spread .182 **3/3** | −0.113 spread .321 1/3 | −0.055 spread .165 1/3 | +0.002 spread .120 1/3 |

**怎么读(按 (i-c):管精度的是 arm 自己的跨种子离散度,不是反号):**

1. ⭐⭐ **`l5combo` 的 VETO 带是本轮最重的一格。** 那个带的定义是**门可证为假**
   (`nCloseEnemies >= 2` 直接 `return nil`),几何在其余方面与 ACTIVE 同类。
   它却扛着 **`arm[kill] = +0.298`(3/3 同号)**、`arm[switch] = +0.022`(spread **0.010**,3/3)、
   `arm[no_dmg] = +0.039`(3/3)—— **比 ACTIVE 带上任何一个读数都更大、更一致**。
   ⇒ **一个安慰剂带上的效应大过活带,就把活带上那些效应的归因权取消了。**
2. **`arm[episodes/局]` 在三个带上全部为正、全部 3/3**(+0.80 / +1.43 / +1.09)——
   armed 腿**在哪里都**更常出现在「低血敌人在身边」的几何里。
   **这是全局的 bundle 效应,不是带特异的**,⇒ 不能记到这两个 gate 名下。
3. `l1trade` **确实**有一格看着像带特异:`arm[commit] = +0.072`,**spread 仅 .044**、3/3 同号,
   而同一支的 OUT 控制带是 `−0.005`(spread .113,2/3,骑在零上)。
   ⛔ **本文件不据此判 WORKING,两条独立理由**:
   (甲) **那个控制带是漏的** —— 见 §5.2,OUT 里有 **27.0%**(armed)/ **25.3%**(baseline)
   的 episode,`J.IsInLaningPhase()` **仍然为真**,helper 根本没死;
   (乙) 同一份语料上 `l5combo` 的**可证为假的**带给出了更大更一致的 arm(第 1 点)
   ⇒ 「带特异 ⇒ 可归因」这条推理**在本语料里被现场证伪过一次**。
   ⇒ 剩下的不确定**在归因,不在是否有行为差**。

---

## 5. 逐帧(硬规则:先逐帧后聚合;聚合只用来选看哪几帧)

### 5.1 钉帧一 —— `commit` 可以在**演员整段不动手**的帧上为真

**`run f7fa97` / `20260907_062353_slot7`**(种子 7144,armed=radiant,⛔ 该局不进 §4 的 arm)
**`t = 72.4`**,`l1trade` ACTIVE,actor = **necrolyte**(core,armed 腿),victim = **skeleton_king**。
量具读作 **`commit = True`**。逐帧实读 `71.0 ≤ t ≤ 77.0` 全事件:

| t | necrolyte | skeleton_king |
|---|---|---|
| 71.4 | hp 0.90,(x,y)=(−6000, 4858) | hp 0.406,(−5940, **5503**) |
| 72.4 | hp 0.917,(−5991, 5078) | hp 0.351,(−5915, **5749**) |
| 73.4 | hp 0.943,(−6037, **4916**) | hp 0.351,(−5878, **6109**) |
| 74.4 | hp 0.960,(−6056, **4696**) | hp 0.363,(−5838, 5987) |
| 75.4 | hp 0.986,(−6001, 4810) | hp 0.382,(−5887, 5753) |
| 76.4 | hp 1.000,(−5992, 5026) | hp 0.394,(−5644, 5764) |

- SK 在**离开**(y 5503 → 6109),necrolyte **没有跟**(y 5078 → 4696),两者距离从 676u 拉开;
- 窗口内 necrolyte 的 `ABILITY` 事件数 = **0**,对 SK 的**自动攻击**(`inflictor = dota_unknown`)数 = **0**;
- 该窗口 necrolyte 打到 SK 的伤害,**逐条全部**是 `necrolyte_heartstopper_aura`(71–77s 共 10 次;
  同段它还对 `creep_badguys_ranged` 打了 29 次、`creep_badguys_melee` 21 次)——
  **一个不需要任何决策的光环。**

⇒ **这一帧上 `commit=True` 记录的是「站着没动」。** 量具的 docstring 自己点过这个风险
(Zeus static field 那例)并给了 `commit_attack` 作为对策,**但 `commit` 仍是它 per-seed 表与
DiD 表的主量**。本轮把它**量成了读数**:配对语料 859 个 `commit=True` 的 ACTIVE episode 里,
**无任何自动攻击**的占 `l1trade` armed **22.5%** / baseline **22.4%**、
`l5combo` armed **25.6%** / baseline **31.5%**;其中**只由一个非攻击技能扛起**的最大单格是
`necrolyte_heartstopper_aura` **18 例**(armed)与 `skeleton_king_hellfire_blast` **17 例**(baseline)。
⭐ **诚实登记:在这份配对语料里这份污染大体两腿对称**(单粒未配对的 7144 上是 39.5% vs 21.4%,反号且不对称)
⇒ **它是量具缺陷,不是本轮任何结论的解释**。已开单,见 §6。

### 5.2 钉帧二 —— **控制带是漏的**(本轮最可引用的一条)

`lanekill_commit.py` 的 `OUT` 带定义为 `t ∈ [520, 900)`,docstring 逐字称
「both helpers hard `return nil` (IsInLaningPhase)」。**源码不是这么写的**
(`bots/FunLib/jmz_func.lua:14297` `J.IsInLaningPhase`):

```
nFloor   = turbo and 8*60  (= 480)
nSoftEnd = turbo and 10*60 (= 600)
if nTime < nFloor then return true end
if nTime < nSoftEnd and GetBot():GetNetWorth() < 8000 then return true end
```

⇒ **`t ∈ [520, 600)` 且净值 < 8000 的那些帧,laning phase 仍然为真,两条 helper 都活着。**
`net_worth` **就在 dumper 的 snapshot schema 里**,所以这个漏是直接可量的:

> **配对语料 OUT 带 814 个 episode:armed 128/474 = 27.0%、baseline 86/340 = 25.3% 落在漏里。**

**钉帧(直接读 timeline,非经量具):`run 8bd33f` / `20260907_062353_slot7`,`t = 585.4`,
`npc_dota_hero_spirit_breaker`,`net_worth = 3124`,`level 9`,`hp_pct 0.228`。**
`585.4 < 600` 且 `3124 < 8000` ⇒ `J.IsInLaningPhase()` 返回 **true** ⇒
`J.ShouldSupportComboKill` 在这一帧**没有** `return nil`。
⭐ 时基已核:dumper 的 `t` 逐字是「game-clock seconds (0 = horn)」(`dumper/main.go:20-21`),
**与 `DotaTime()` 同基**,⛔ 不需要再减 `game.start_time`。

⇒ **这条直接削弱 §4 第 3 点里我自己本来想用的那个论证** —— 照登。

### 5.3 逐帧三 —— 设计中的「4 秒粘滞锁」在**两条腿上都看不见**

gate 的卖点是 4s sticky target。三个可观测判别子(全在 dumper 流里):
`atk_n`(窗口内落在 victim 身上的自动攻击次数)、`split`(同窗口内既打了 victim **又**打了别的敌方英雄
—— 锁若生效应当禁止)、`aura_only`。配对语料 ACTIVE 带 1152 个 episode:

| 支 | 分层 | 腿 | n | atk_n 均值 | atk>=2 | **split** | aura_only |
|---|---|---|---|---|---|---|---|
| l1trade | radiant | armed | 277 | 1.01 | 33.2% | **28.9%** | 14.1% |
| l1trade | radiant | baseline | 211 | 0.97 | 28.4% | **27.5%** | 18.5% |
| l1trade | dire | armed | 41 | 0.83 | 22.0% | **34.1%** | 31.7% |
| l1trade | dire | baseline | 52 | 0.98 | 32.7% | **44.2%** | 13.5% |
| l5combo | radiant | armed | 268 | 0.98 | 31.0% | 25.0% | 18.7% |
| l5combo | radiant | baseline | 216 | 0.74 | 22.2% | 22.7% | 23.6% |
| l5combo | dire | armed | 50 | 0.64 | 16.0% | 24.0% | 24.0% |
| l5combo | dire | baseline | 37 | 0.76 | 27.0% | 18.9% | 16.2% |

**「强锁」形状(`atk_n >= 4` 且 `split=False`)在 1152 个 ACTIVE episode 里共 4 个:
armed 3 个、baseline 1 个。** 逐帧看 armed 那三个里最干净的一个
(`run 5acea8` / `20260907_064849_slot2`,种子 7162,armed=radiant,`t=331.5`,sniper → viper,
6 次自动攻击、victim 于 `t=335.2` 死亡):**它不是一次线上 2 打 1** —— 同窗口内
sven/zuus/witch_doctor/crystal_maiden 全在场并各自开技能,viper 最后是被
`npc_dota_badguys_tower1_bot` 打死的。⇒ **这是一次团战,不是 gate 描述的那件事。**

⭐ **顺带量出来的一条(§6 开单):域的时间重心不在"对线期"。**
ACTIVE episode 的**中位时刻 `l1trade` 245.5s / `l5combo` 242.5s**,
**t ≥ 300s 的占 37.2%(l1trade 216/581)、36.8%(l5combo 210/571)**。
Turbo 的 `IsInLaningPhase()` 硬底是 **480s**、软延到 **600s**,而 Turbo 一局 ~20 分钟
⇒ **这两条「只在对线期」的杠杆,实际活到整局的一半**,域里塞满了中期团战。
这与「深度缰绳」当年的教训(跨图追杀)同族:**限定词写在一个不度量它想度量那件事的量上。**

---

## 6. 本轮开出的单(全文见 issue)

1. **GH #874 [harness]** `lanekill_commit.py` 的 `OUT` 控制带在 `[520,600)` 上**不是零通道**
   —— 27.0% / 25.3% 的 episode 里 `IsInLaningPhase()` 仍为真;钉帧 §5.2。
   建议:`OUT_START` 抬到 **600**,或按 snapshot 的 `net_worth >= 8000` 过滤;
   验收 = 重跑本文件的 §4 OUT 行,漏率读 0。
2. **GH #875 [harness]** `commit` 把**无决策伤害**(光环/被动)算作 commit,而 per-seed 表与 DiD
   用的正是 `commit`;干净的那个量(`commit_attack`)就在同一张表上三行之外。
   建议:加 `commit_decision`(自动攻击 ∪ 定向施法,排除纯光环/被动 inflictor),
   DiD 与 per-seed 表改用它;验收 = §5.1 那 18 例 `heartstopper_aura` 单扛的 episode 读 False。
3. **[strategy] (未开单,见下)** 两条 helper 的「只在对线期」限定由 `IsInLaningPhase()` 承担,
   而它在 Turbo 的硬底 480s / 软延 600s 让杠杆活到整局一半;
   域中位时刻 245.5s / 242.5s,37.2% / 36.8% 的 episode 在 300s 之后。
   ⛔ **不是本轮的 (a) 结论**,是复活这两条 id 之前该先谈的作用域问题。

⛔ **没给 `l1trade` / `l5combo` 本身开单** —— 核验结论不是病例。
⛔ **没为 §1 那条「截断恒丢 dire 腿」开单**:本轮只有一波的现场,且它可能是
批测台已知的时间帽行为;**交给批测台在自己的语料上判**,写在本轮报告的交棒里。

---

## 7. 买到它还需要什么 —— **以及为什么这扇门正在关上**

本行的 (a) 买不到归因,唯一缺的东西是**隔离**:一条 `l1trade`(或 `l5combo`)**单独 armed**
的腿,或者哪怕一条 arm 串**只差这一个 id** 的对照波。本轮语料是 **51 个 id 同开**。

⛔ **而这条路现在是关着的,两道锁**:

1. 两条 id **2026-09-07T19:xxZ 已 RETURNED_FROM_ARMED_SET**(`state.json:l1trade_RETURNED_20260907`)
   ⇒ **此后没有任何一波会 arm 它们** ⇒ 不会再有新语料。
2. 已归档的 `.dem` **约 2026-10-02 到期**(距本轮约 **15 天**)⇒ **现存语料也在倒计时**。

⇒ **这一行的形状是:一个仍然欠着的条件 (a),它唯一可能的语料有到期日,而 registry 里没有任何字段装那个日期。**
与 W86 的 GH #871 **同类反号**:那次是「证据已交付而 owed 行不知道」,这次是「证据的**来源**会过期而 owed 行不知道」。
**已按这一条开单(GH #876 [bug]),并把处置口径写在这里,免得下一轮重新推导:**

- **保守默认(本轮采用)**:**接受 INDETERMINATE 作为本行的交付**。
  本行 `done_when` 只判产物存在(LIMIT 11),其裸读验收句要的是
  ——「两条 helper 各自的 `VERIFY` 行 + 检测器读的是**波次录像**而不是 `tests/fixtures` + ab/ba 两个分层的读数」——
  **三条本文件逐条满足**(§0 / §1+§2 / §3)。⛔ 它**没有**要求结论是 WORKING。
- **若总监要 WORKING/BUGGY**:那需要**发波**(隔离腿),**球在批测台**,而 MTD 在刹车线上
  ⇒ 本轮**只登记,不请求**(铁律 1)。**并且要在 10-02 之前决定**,否则连"重跑旧语料"这条退路也没有了。

---

## 8. 可复现命令(全部只读)

```bash
bash tools/batch_test/aws/session_setup.sh                      # AWS_SETUP_EXIT=0
for r in f7fa97 8bd33f dc6b6d 5acea8; do
  bash tools/batch_test/behavioral/sweep_run.sh \
    "s3://dota2bot-batch-results-4924/soak/spot_20260907_0622*_1_523f21ba*_$r/"
done                                                            # SWEEP_EXIT=0 x4
python3 tests/test_detector_source_constants.py                 # EXIT=0
python3 tools/batch_test/behavioral/lanekill_commit.py  <三个配对 run 的 .sweep_out 目录>
python3 tools/batch_test/behavioral/lanekill_strata.py  <同上>   # §3 + §4
```
