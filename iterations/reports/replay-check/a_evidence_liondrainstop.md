# `a_evidence_liondrainstop` — 结清行(录像组 2026-09-17T06:46Z,W86)

```
VERIFY id=liondrainstop verdict=WORKING episodes=8
```

⛔ **先读这一节,否则会把这份产物读成它不是的东西。**

## 0. 这一行欠的是什么,以及它为什么欠了六天

`owed_executions` 里 `a_evidence_liondrainstop` 的 `done_when` 逐字是:

```
iterations/reports/replay-check/a_evidence_liondrainstop.md does not exist yet
```

⭐⭐ **而这条义务本身在 2026-09-09 就已经履行完毕,并且已经被消费掉了**:

- `iterations/reports/replay-check/20260909T184000Z.md:242` 逐字带着
  `VERIFY id=liondrainstop verdict=WORKING episodes=36`(W60 语料);
- 总监 2026-09-11T10:54:30Z 以 commit **`92648c81`** 按 `test_set.md §GU.2`
  **promote 了 `liondrainstop`**,armed 34 → 32,锚点 `stable-v7`。
  该 commit 的 diff 逐字:
  `- if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainstop' ) ) then return false end`
  `+ if not J.IsModeTurbo() then return false end`

⇒ **条件 (a) 早就买到了,而且正是它支撑了 promote。**

### 0.1 ⛔ 本节初稿的结论是错的,这里把它改掉(不是补充,是**推翻**)

初稿写的是:「`done_when` 探的是一个文件名,投递物落在日期报告里
⇒ **该行在构造上永远读 OWED**,每个取活的轮次都会被它烧掉一轮」。

**这句话被本轮自己的推送闸当场证伪。** 我创建本文件之后第一次 `git push`
被 `tests/test_pending_rulings.py` 拒了(`997 checks, 1 failed`),逐字:

```
FAIL: 7 live registry rows read BORN-DONE (a_evidence_liondrainstop, …)
      but the ceiling is 6
```

⇒ **这一行是可以被结清的,我刚刚就结清了它。** 判据没有「在构造上永不满足」,
它只是**要求一份放在那个路径上的产物**,而那份产物在 2026-09-17 之前确实**不存在**。
⇒ **registry 没有说谎,读 OWED 是对的。**

⭐ **正确的缺陷比初稿那条窄,但它是真的**,而且是**记账链路**的缺陷不是判据的缺陷:

本行 `ruling` 字段把「不退集」建立在**三个并排的机器读数**上,第一个逐字是
**`verify=0`(从来没有 VERIFY 行)**。

- 该前提在 **2026-09-09T10:xxZ** 成立(立行那一刻);
- **同日 18:40Z**,即 **8 小时后**,`20260909T184000Z.md:242` 写下了 VERIFY 行 ⇒ **前提变假**;
- **2026-09-11T10:54:30Z**,总监**以那份证据 promote 了这个 id**;
- **而这一行没有被那次 promote 关掉、也没有被更新**,继续以一个已经变假的前提
  向录像组要一份**已经交付并且已经被消费掉**的证据,**要了六天**。

⇒ **缺陷 = 一次 promote 消费了某条 owed 行索要的证据,而没有任何东西把两者连起来。**
⛔ 不是「判据不可满足」,⛔ 也不是「registry 读错了」。

⭐ **顺带一条对 registry 有利的现场**:LIMIT 14 的 BORN-DONE 棘轮**工作正常**,
它在我结清的同一刻就抓住了「这一行从没被人看见过 OWED」这个风险,并逼我把
2026-09-17T06:36:23Z 那次真实的 OWED 读数记进 `unmet_at_ruling`(见该字段)。
**本轮的记账动作是被棘轮逼出来的,不是我自觉做的**,照登。

本文件的存在结清了这一行 —— 那是**记账动作**,不是新证据。真正的新证据在 §1 以下。

## 1. 那么本轮真正买到的是什么

既然 (a) 已在 09-09 买到,本轮**不重买 (a)**。本轮买的是一个此前没人问过的问题:

> **promote 之后,这个已经没有 gate 的默认行为,在真实对局里真的在执行吗?**

这不是多余的:promote 把 `IsSoakCandidate` 去掉之后,该行为**在两条腿上都开着**,
于是**任何 armed/baseline 对比对它都失效**,它从此**掉出所有波次的 arm 串**
(本轮语料的 27-id 串里确实没有 `liondrainstop`)。
⇒ **一个 promoted 默认此后没有任何例行读数在看它。** 本轮补的正是这一眼。

## 2. 语料与口径

- **W69**,4 个 run(`spot_20260912_0926{22,24,27,29}_1_main_*`),`SWEEP_EXIT=0` ×4,
  16 局中 4 局 warmup、**12 局入集**、`unparseable 0`;9 局有 Lion。
- **post-promote 成立(实测,不是推断)**:promote commit `92648c81` 落于
  **2026-09-11T10:54:30Z**,W69 发波于 **2026-09-12T09:26Z**,晚 ~22.5 小时;
  run 名里的 `_main_` 即 clone 自 main。
- arm 串 **27 id,12 局逐字同一串**(`distinct arm strings: 1`),
  **不含 `liondrainstop`**(已 promote)、**不含 `liondrain`**(出厂释放路径两腿相同);
  **含 `lionqdmg`** —— 09-09 那轮必须排除的同一个混杂项,见 §4。
- 量具 `tools/batch_test/behavioral/lion_drain_census.py`,`--verify` **33 asserts OK**;
  `CENSUS_EXIT=0`;采样间隔 **1.0s**(量具自报)。
- ⚠️ `stamps.json` **树里没有任何写入方**(`grep` 全仓零命中),本轮由
  `games_manifest.jsonl` 现搭;这是量具契约的一个缺口,登记在此。

## 3. 帧证据(硬规则:先逐帧后聚合)

### 3.1 钉帧 `20260912_094133_slot1`(seed 13052,**BASE 腿**,Lion=dire)

⭐ **选它是因为它是最难被别的机制解释的那一条**,不是因为它最好看。

| t | 事件(逐字取自 event 流) |
|---|---|
| 277.9 | `ABILITY lion_mana_drain` + `MODIFIER_ADD modifier_lion_mana_drain` → tidehunter。此刻 tidehunter **458u**,**已在 500u 危险环内** |
| 277.9–282.5 | **4.6s**,环内始终有敌方英雄(458→418→380→343u),**但 Lion 在 2.0s 窗口内没有被任何英雄伤害** ⇒ 谓词第二合取项 FALSE ⇒ **引导不被切,正确** |
| 282.5 | `DAMAGE actor=tidehunter target=lion infl=tidehunter_anchor_smash value=139`,`actor_hero=true`;tidehunter **263u** ⇒ **两个合取项同时成立,谓词翻真** |
| 282.7 | `MODIFIER_REMOVE modifier_lion_mana_drain` ⇒ **谓词翻真后 0.2s 释放** |

**判别子(为什么这不可能是别的东西干的)** —— 逐条实测 281.5–283.5 **全部**事件:

1. **不是被打断**:282.5 落到 Lion 身上的**唯一**东西是
   `modifier_tidehunter_anchor_smash`(减伤 debuff)+ 139 伤害。
   **Anchor Smash 不带控制**;而 Dota 的引导**不被单纯伤害打断**
   ⇒ **引擎侧没有任何机制在这一刻结束这条引导。**
2. **不是自己打断自己**:窗口内 Lion **零** `ABILITY` 事件(最后一次是 276.3 的 voodoo)。
3. **不是 Lion 死了**:全局 Lion 的 `DEATH` 最近一次在 **t=576.4**,离此 294s。
4. **不是目标死了/走出射程**:tidehunter 在 282.5 仍活着(正是他在放技能)且 **263u**。
5. **不是 `lionqdmg`**:该 id 只在 **CAND** 腿 armed,**本局 Lion 在 BASE 腿**。
6. **⚠️ 不是自然到期,但差得不多** —— 见 §3.2:自然上限 **5.1s**,本条 span **4.8s**
   ⇒ **实际省下 0.3s**,**低于量具自己的 `MIN_CUT = 0.5`**。
   ⇒ ⛔ **这一条证明的是「释放发生了、且卡在谓词那一帧」,不是「省下了多少」。**
   两者不是同一个命题,本文件不把前者写成后者。

⭐ **段内阴性对照是自带的**:同一条引导的前 4.6s,敌人**已经在环内**却**没有被切**。
⇒ 释放跟的是**第二合取项(近期被英雄伤害)**,不是单纯的距离。
任何「Lion 总体少拉一会儿」的解释都解释不了这个**段内**的先不切后切。

### 3.2 自然上限 = 5.1s(实测,不是查表)

97 条 channel 的 span 分布在 **5.1s 处堆出一个众数:15 条恰好 5.1、4 条 5.0**,
**没有一条超过 5.1**。与 Lion 法力汲取 5s 引导时长一致(+1 个 0.1s 计量 tick)。
⇒ 后文「省下多少」一律按 `cut = 5.1 − span` 计。

### 3.3 八条域内 channel 全表(⛔ 不做任何过滤,含上面那条)

| tag | seed | leg | t0 | t_dom | t1 | residual | span | cut | target |
|---|---|---|---|---|---|---|---|---|---|
| 094133_slot1 | 13052 | **BASE** | 277.9 | 282.5 | 282.7 | **0.20** | 4.8 | 0.3 | tidehunter |
| 095331_slot1 | 13052 | **BASE** | 213.5 | 213.5 | 213.7 | **0.20** | 0.2 | 4.9 | creep_ranged |
| 095331_slot1 | 13052 | **BASE** | 373.4 | 373.5 | 373.6 | **0.10** | 0.2 | 4.9 | ogre_magi |
| 100254_slot1 | 13019 | **BASE** | 242.4 | 242.5 | 242.6 | **0.10** | 0.2 | 4.9 | warlock |
| 100254_slot1 | 13019 | **BASE** | 1204.4 | 1207.5 | 1207.9 | **0.40** | 3.5 | 1.6 | venomancer |
| 095226_slot1 | 13019 | CAND | 1010.4 | 1010.5 | 1010.5 | **0.00** | 0.1 | 5.0 | juggernaut |
| 095226_slot1 | 13019 | CAND | 1231.9 | 1232.5 | 1233.5 | **1.00** | 1.6 | 3.5 | skeleton_king |
| 095226_slot1 | 13019 | CAND | 1238.4 | 1238.5 | 1238.5 | **0.00** | 0.1 | 5.0 | juggernaut |

**7/8 的 residual ≤ 0.4s**(采样间隔 1.0s ⇒ 半格以内);`leak_only 0`(#78 尸体帧零污染);
7/8 目标是英雄。

## 4. 聚合(⛔ 只在逐帧之后,且只用于定位,不用于判词)

量具读数(`CENSUS_EXIT=0`):

| 分层 | games | channels | 域内 | residual n / mean / median / sd |
|---|---|---|---|---|
| all | 9 | 97 (hero-target 55, zero-snap 25) | 8 | 8 / **0.25** / 0.15 / 0.33 |
| lion_cand_side | 5 | 56 | 3 | 3 / 0.333 / 0.0 / 0.577 |
| lion_base_side | 4 | 41 | 5 | 5 / **0.20** / 0.20 / 0.122 |
| lion_cand_side/**ab** | 4 | 45 | 3 | 3 / 0.333 / 0.0 / 0.577 |
| lion_base_side/**ab** | 2 | 25 | 3 | 3 / 0.167 / 0.20 / 0.058 |
| lion_cand_side/**ba** | 1 | 11 | 0 | **0 / — / — / —** |
| lion_base_side/**ba** | 2 | 16 | 2 | 2 / 0.25 / 0.25 / 0.212 |

**铁律 4 (i-a):两个分层的读数都登记在上表**(含 `ba` 的 cand 腿 **n=0** 这个空格)。
⛔ **但本轮不形成 arm 估计量,理由是构造性的**:`liondrainstop` 已 promote ⇒
**两条腿都是 gate-ON** ⇒ cand/base 之差对这个 id **不是 arm**,是别的 26 个 id 的合力。
(i-c)/(i-e) 的 swap-average 在此**无对象**,⛔ 不编造。

### 4.1 承重的对照是「域内 vs 域外」,而且它在 **BASE 腿内部**就成立

| leg | 组 | n | mean span | median | 打满上限(≥5.0) | mean cut |
|---|---|---|---|---|---|---|
| BASE | **域内** | 5 | 1.78 | **0.20** | **0/5** | 3.32 |
| BASE | 域外 | 28 | 3.16 | **3.30** | **8/28** | 1.94 |
| CAND | **域内** | 3 | 0.60 | 0.10 | **0/3** | 4.50 |
| CAND | 域外 | 36 | 2.86 | 2.60 | **11/36** | 2.24 |
| 池化 | **域内** | **8** | 1.34 | **0.20** | **0/8 (0%)** | — |
| 池化 | 域外 | **64** | 2.99 | **2.95** | **19/64 (30%)** | — |

⛔ `zero_snap`(BASE 8 / CAND 17)**从两组里都剔除**,不折进「域外」——
它们在构造上偏短,折进去会把对照组往短里拉,正是本对照最容易被做假的地方。

统计(自写,正态近似 + 并列修正 / Fisher 精确):

- 池化:Mann-Whitney **z=−2.81, p=0.0050**;打满上限 0/8 vs 19/64,Fisher **p=0.100**。
- **BASE 腿单独**:Mann-Whitney **z=−1.77, p=0.077**;0/5 vs 8/28,Fisher **p=0.302**。

### 4.2 ⛔ 这个对照**不是**干净的,必须自己说出来

「域内 channel 更短」**部分是共因的**:域内 = 敌人在 500u 内 **且** Lion 刚被英雄打过
⇒ Lion 更可能随后被控/被杀 ⇒ **引导因机械原因变短**,与 gate 无关。
⭐ **这正是 2026-08-21 总监废掉 `span>=2.0s` 过滤的那条共因**(Fisher p=0.0040),
**换了一件衣服又出现在这里**。
⇒ **§4.1 只能定位,不能判词;判词只能由 §3.1 那种段内先不切后切的帧证据出。**

### 4.3 跨语料参照(⛔ DEMONSTRATION,不是估计量)

量具自印的 gate-OFF 归档基线:**mean 1.91 / median 1.6 / sd 1.66, n=64**(196 局)。
W60(promote 前)域内 residual:armed **1.653 / 0.995** vs baseline **2.434 / 2.940**。
本轮(promote 后)**BASE 腿 0.20**(n=5)。

⇒ **变的正是 baseline 腿**:promote 前它读 1.9–2.9,promote 后读 0.20。
**「promote 没落到实例树上」这个假设预测 baseline 腿仍读 ~1.9–2.9,实测否掉。**
⛔ **但这是跨语料、跨波、跨阵容的比较,n=5**,不是配对读数,
**不满足 GH #86 §5 的任何一档**(效应 ≥2.0s,或 ≥12 粒双臂种子)。
本轮效应 1.71s,**低于 2.0s**;种子 **4 粒**,低于 12。
⇒ ⛔ **本文件不声称按 §5 重新确立 (a)。(a) 是 09-09 那 36 个 episode 确立的。**

## 5. 判定与它的确切范围

```
VERIFY id=liondrainstop verdict=WORKING episodes=8
```

`episodes=8` 口径 = **W69 全部域内 channel 数**(BASE 5 + CAND 3;分层读数见 §4 表)。

**WORKING 具体指什么(逐字,别扩大)**:
- ✅ **执行已被帧级证明**:§3.1 有一条 BASE 腿(**零 soak id armed**)的引导,
  在谓词翻真后 **0.2s** 被释放,而引擎侧**没有任何机制**能在那一刻结束它
  (五条判别子逐条实测排除),段内还自带 4.6s 的「谓词假 ⇒ 不切」阴性对照。
  ⇒ **promoted 的默认在真实对局里确实在跑,不是死代码。**
- ❌ **本轮没有买到「省下多少」**:钉帧本身只省 0.3s(< `MIN_CUT` 0.5);
  效应量 1.71s 不过 §5 的 2.0s 门槛,种子 4 < 12。
- ❌ **本轮没有买到 (b)**:「Lion 因此活得更久 / 胜率更好」归批测台,与 09-09 边界逐字相同。

⚠️ **为什么不判 INDETERMINATE**:INDETERMINATE 的用法(见 W85 的 `arbheart`)是
**两个互斥机制同时支持同一结论、本台分不开**。这里不是那个形状:
§3.1 的五条判别子**已经把「不是 gate 干的」那一侧逐条关掉了**,
剩下的不确定性只在**效应量**上,不在**是否执行**上。
⛔ 把「量不准效应量」写成「不知道它是否执行」是把两个问题混成一个。

⚠️ **为什么不判 SILENT**:SILENT 会被 §3.1 那一帧直接证伪。

## 6. 本轮开出的两条结构缺陷(详见 GH issue / 当轮报告 §5)

1. **[harness] 一次 promote 消费了某条 owed 行索要的证据,而没有任何东西把两者连起来**
   (§0.1;⛔ **不是**初稿写的「判据在构造上不可满足」,那条已被本轮推送闸证伪并删除)。
   本行 `ruling` 的第一个前提 `verify=0` 在立行后 **8 小时**变假,
   **两天后**总监正是以那份证据 promote 了该 id,而这一行**六天**没被关掉也没被更新。
   ⇒ 建议的验收:promote 一个 id 时,检索 `owed_executions.json` 中 `issue`/`ruling`/`executor`
   任一字段点名该 id 的活行,并在同一个工作单元里关闭或改写它们。
2. **[harness] `lion_drain_census.py --split-is` 没有「post-promote」这一档。**
   两个取值 `null-channel`(两腿都 gate-OFF)与 `armed-vs-baseline`(cand 腿 gate-ON)
   **都不描述本轮语料**(两腿都 gate-ON)。默认档会往读者眼前打印
   **`BOTH legs gate-OFF; the cand/base split says nothing about this id`** ——
   后半句**对**,前半句**自 2026-09-11 起是假的**。
   ⭐ 这正是同目录 `arm_string_census.py` 文件头点名的 **#296/#297 家族**
   (量具把读者领到一个错结论),而且**发生在一个 promote 之后必然出现的语料上**。

## 7. 边界(引数字必须连着引)

1. ⛔ 本文件**不重新确立 (a)**,不请求撤销或重开 §GU.2 的 promote。
2. `n=8` 域内 channel、**4 粒种子**、12 局;`ba` 分层的 cand 腿 **n=0**。
3. §4.1 的域内/域外对照**与结局共因**(§4.2),只定位不判词。
4. §4.3 跨语料,**不是配对估计量**。
5. 自然上限 5.1s 是**本语料实测众数**(15/97 恰好落在那里),不是查表值。
6. `WasRecentlyDamagedByAnyHero` 引擎侧不可离线读,量具用 DAMAGE 事件代理,
   **方向偏超集**(量具文件头自述);§3.1 的 anchor_smash 是一次**直接命中的**
   `actor_hero=true` 伤害,不吃这个代理的模糊地带。
7. `stamps.json` 树里无写入方,本轮现搭(§2)。

## 8. 成本(RULING 48 三段)

**零 EC2 / 零 CE / S3 读取 29 个对象(出网未计价)**
= 16 个 `.analysis.json` + 12 个 `.dem`(dump 后即删)+ 1 个 dumper 二进制(cache HIT);
另 **4 次 `s3 ls`**。容器落盘 307 MB。⛔ 不写「零支出」。
