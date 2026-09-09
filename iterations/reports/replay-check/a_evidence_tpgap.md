# `tpgap` — condition (a) evidence (owed_executions row `a_evidence_tpgap`, GH #159)

**Executor**: replay-check(录像组) · **Produced**: 2026-09-09T13:1xZ
**Ruling this discharges**: 总监 2026-09-09T10:xxZ, `iterations/streams/test_set.md` §GG
(`owed_executions.json:a_evidence_tpgap`, `done_when: iterations/reports/replay-check/a_evidence_tpgap.md does not exist yet`).
**Pre-registered reading**: `iterations/queue.json:strategy-14.acceptance` — 方向是**收窄**
(子域内按下下降 + 反向哨兵不塌),⛔ **不是**「按下数必须下降」。

```
VERIFY id=tpgap verdict=INDETERMINATE episodes=26
```

(26 = the sub-domain itself: 11 armed + 15 baseline gap-band retreat presses whose
band enemies realized lethal damage inside the 3 s channel, over 96 game-legs.
INDETERMINATE is the honest word and §5 says exactly what would move it.)

---

## 1. Wave, corpus, coverage

| | |
|---|---|
| Wave | **W60**, launched 2026-09-09T09:23Z, `--on-demand`, `--ref` pinned to `f25680bcbed59113248284bdec39f624c24e525b` |
| Seeds | 9911 / 10079 / 10097 / 10133 (4 machines, 4/4 paired — the first 4/4 since W52) |
| Games swept | **96/96** non-warmup (`26+23+21+26`), 24 warm-up skipped, **unparseable 0** |
| Sweeps | `sweep_run.sh` ×4, `SWEEP_EXIT=0` ×4 |
| TP presses examined | **8,793** (`from_home` excluded) |
| AWS | S3 **read-only**. Zero EC2, zero new wave, zero Cost Explorer. |

**Reachability — verified against the pinned tree, not against prose.**
`git show f25680bc:iterations/streams/test_set.md | sed -n 2p` ⇒ `tpgap` is
**id 16 of 37**; the string is **335 bytes**, md5 **`b525d51d4b4957e0e40f22f203aea641`**,
**digit-for-digit** the `W60_wave.json:arm_md5`. So the armed leg of this corpus
really carries the lever, and the pre-registered first suspicion for an all-zero
reading (「arm 串漏了 `tpgap`」) is **excluded by construction**.

**Tool**: `tools/batch_test/behavioral/tpgap_domain.py` — already on trunk
(written 2026-08-26; **not** written this round — `ls tools/batch_test/behavioral/ | grep tpgap`
was the first command, per the W58 lesson). `--selfcheck` **50 PASS / 0 FAIL**,
`--source` exit 0. Constants are **read from the Lua**, never retyped:
`onface_radius 350` / `band_radius 700` / `channel_seconds 3.0` / `min_speed 285`
/ `gate_id tpgap` / `3 tpLoc assignments in the retreat branch, all J.GetTeamFountain()`.

## 2. 逐帧在先 —— the load-bearing frame

**`20260909_093852_slot7` (run `…15755b`, seed 10097) `queenofpain` t=549.6, ARMED leg.**
Read frame by frame off the idx-clean track (illusions dropped by `frames_by_hero`),
then the events re-summed by hand:

```
t=544.5 hp=344  pos=( 715, 996)   step=266 u/s
t=545.5 hp=351  pos=( 316,1039)   step=401 u/s
t=547.5 hp=361  pos=( 793, 999)   step=401 u/s
t=548.5 hp=365  pos=(1061,1008)   step=268 u/s
t=549.5 hp=386  pos=(1371,1161)   step=346 u/s
t=549.6 <MODIFIER_ADD modifier_teleporting> <ITEM item_tpscroll>   -- 撤退 TP 按下
        zuus 距离 563 u  == gap 带 (350,700] 内,唯一带内敌人
t=550.0 zuus_arc_lightning 119 + zuus_static_field 11
t=550.2 static_field 7 + heavenly_jump 17 + modifier_zuus_static_field_slow
t=551.0 static_field 7 + auto 47
t=551.3 lightning_bolt 183  -> DEATH (zuus)     -- 通道第 1.7 s,3 s 没走完
```

**带内敌人在 3 s 通道内实际打出 396 ≥ 按下瞬间血量 371** ⇒ 这正是守卫存在要清空的那一格。
三条离线可查的 fall-through **全部排除**:

1. **贴脸(<350)**:最近敌人 563 u,守卫第二行不 return;
2. **移速 <285**:窗口内采样步长 **401 / 401 / 346 u/s**,全部 ≥285 —— 这条被**观测反驳**,不是被假设排除;
3. **rooted/stunned/hexed/nightmared**:按下瞬间 QoP 身上无任何致残 modifier(事件流里只有她自己的 `item_magic_wand`)。

**能见度也不是借口**:工具的 team-vision 见证(己方单位正在打 zuus)命中 ⇒
`J.GetNearbyHeroes(..., true, ...)` 的可见性过滤在这一帧**够得着** zuus。

⇒ **armed 腿在这一帧没有拒**,而唯一剩下的解释是引擎自己的
`GetEstimatedDamageToTarget(true, bot, 3.0, ALL)` 当时读出的值 < 371 ——
对一个 563 u 外、bolt+arc 都在手的 Zeus 而言,这恰恰是那个估计量该定的价。
**这是继 08-26 `slardar t=1382.2` 之后第二枚反例**,也是本轮 11 枚 armed 子域帧里
**唯一一枚三条 fall-through 全排除的**。

**另两枚逐帧手查过的**(同为 armed 子域,结论相反方向):
- `20260909_100233_slot6 chaos_knight t=593.9`:axe 372 u,3 s 内实打 **368 ≥ 326**,
  t=596.8 死(通道内)。但窗口内最快采样 **279 u/s < 285** ⇒ **移速 fall-through 无法排除**,
  按 UNSETTLED 记。
- `20260909_100313_slot4 lion t=345.3`:lina 542 u,`lina_slow_burn` 每秒 28,
  t=347.3 死(通道第 2.0 s)。最快采样 **254 u/s** ⇒ 同样 UNSETTLED。
  ⚠️ 值得下一棒注意的形状:**打死他的那条 DoT 名字里就带 slow**,
  而移速地板恰好把「被减速的人」整类排除在守卫域外 —— 但**本轮不下这个结论**,
  dump 里没有移速字段,`modifier_lina_slow_burn` 是否真减速本组没有独立证据。

## 3. 聚合(铁律 4 (i-a):两个分层的**读数**都登记)

`d(share)` = armed 腿该分层占其**自己那条腿的撤退按下**的比例 − baseline 腿同量。

| 分层 | armed | base | armed/局 | base/局 | radiant d(share) | dire d(share) | POOLED d(share) |
|---|---|---|---|---|---|---|---|
| **子域** mid_gap ∧ retreat ∧ realized-lethal | **11** | **15** | 0.1146 | 0.1562 | **−0.0074** | **+0.0088** | −0.0021 |
| mid_gap ∧ retreat(全带) | 150 | 198 | 1.5625 | 2.0625 | −0.0136 | −0.0443 | −0.0232 |
| mid_gap ∧ retreat ∧ 存活(误拒住这里) | 139 | 183 | 1.4479 | 1.9062 | −0.0062 | −0.0530 | −0.0211 |
| 对照 walk_guard ∧ retreat(tpsafe 的地盘) | 122 | 133 | 1.2708 | 1.3854 | −0.0177 | **+0.0521** | +0.0054 |
| 对照 far/no_enemy ∧ retreat(无带内敌) | 739 | 823 | 7.6979 | 8.5729 | +0.0313 | −0.0078 | +0.0178 |
| 对照 mid_gap ∧ travel(tpsafe2/tpreach 地盘) | 74 | 74 | 0.7708 | 0.7708 | −0.0055 | +0.0107 | −0.0001 |
| HARM mid_gap ∧ retreat ∧ 死在通道 | 47 | 57 | 0.4896 | 0.5938 | −0.0049 | +0.0016 | −0.0029 |

**⛔ 子域两层反号(radiant −0.0074 / dire +0.0088)。** 这是**计数类、侧偏未消除**的估计量,
按**铁律 4 (i-b)** ⇒ **噪声,不写进结论**。工具自己也是这么判的,逐字:

```
VERDICT  tpgap condition (a): REFUSE
  ab and ba disagree on the sign of the sub-domain gap -- noise by 铁律 4 (i), not a reading
```

**逐种子的子域格子**(登记分母,回答 strategy-14 预登记的第二嫌疑「子域太稀」):

| 种子 | armed r/d | baseline r/d | 局数 |
|---|---|---|---|
| 9911 | 0 / 2 | 5 / 0 | 26 |
| 10079 | 3 / 0 | 1 / 1 | 23 |
| 10097 | 1 / 3 | 3 / 1 | 21 |
| 10133 | 2 / 0 | 4 / 0 | 26 |

**每格 0–5。** 子域密度 armed **0.11 / 局**、baseline **0.16 / 局** —— 96 局只买到 26 个
episode。**这不是「放宽谓词」的理由**(预登记逐字禁止),是**分母本身的读数**:
按这个密度,把子域的侧偏噪声压下去需要的语料是**几百局量级**,不是一波。

**反向哨兵(比主判据更重要的那条)—— 没有塌**:
撤退按下 armed **1011** vs baseline **1154**(占全部按下 23.35% vs 25.85%,**两层同号**);
撤退 TP 存活率 armed **86.3%** vs baseline **85.2%**(radiant 87.9/83.4、dire 83.1/89.0)。
⇒ 「错拒把一条命换掉」的那个失败模式,**在这份语料里没有出现**。

## 4. 帧审计全表(11 枚 armed 子域按下,逐枚单独定案)

| 局 | 英雄 | t | hp | near | 最快采样 | 判定 |
|---|---|---|---|---|---|---|
| 093852_slot7 | queenofpain | 549.6 | 371 | 563 | 346 | **SHOULD-HAVE-REFUSED** |
| 100233_slot6 | chaos_knight | 593.9 | 326 | 372 | 279 | UNSETTLED(移速) |
| 100313_slot4 | lion | 345.3 | 74 | 542 | 254 | UNSETTLED(移速) |
| 093854_slot6 | queenofpain | 684.5 | 237 | 606 | 205 | UNSETTLED(移速) |
| 100251_slot3 | crystal_maiden | 488.3 | 25 | 698 | 207 | UNSETTLED(移速) |
| 095024_slot7 | chaos_knight | 179.4 | 175 | 410 | 390 | UNSETTLED(能见度) |
| 095108_slot5 | tidehunter | 741.4 | 334 | 421 | 328 | UNSETTLED(能见度) |
| 095049_slot2 | zuus | 645.9 | 181 | 468 | 359 | UNSETTLED(能见度) |
| 100300_slot4 | tidehunter | 1071.8 | 123 | 612 | 289 | UNSETTLED(能见度) |
| 095439_slot4 | chaos_knight | 1053.5 | 474 | 665 | 316 | UNSETTLED(能见度) |
| 094119_slot3 | pudge | 952.0 | 212 | 695 | 364 | UNSETTLED(能见度) |

**0 EXCUSED / 1 SHOULD-HAVE-REFUSED / 10 UNSETTLED.**

⭐ **这张表本身是本轮的头号读数,而它讲的是仪器不是杠杆**:11 枚里 **10 枚**倒在
**恰好两个 dump 里没有的字段**上 —— **4 枚移速**(`GetCurrentMovementSpeed()`,
snapshot 无该字段,只能用位移采样的**下界**代替)、**6 枚能见度**
(`J.GetNearbyHeroes(..., true, ...)` 只数**可见**敌人,而 dump 是上帝视角;
team-vision 见证是**单向的**:命中证明看得见,不命中什么都不证明)。
**0 EXCUSED** 这一格尤其要读清楚:不是「没有一枚该被豁免」,是**这台仪器一枚都豁免不了**。
⇒ 「拒绝是缺席,离线看不见」(08-26 §6 第 3 条)之外,现在多了一句更硬的:
**放行也定不了案** —— 除非那一帧恰好同时满足「采样步长 ≥285」**且**「见证命中」,
本轮 96 局只出现 **1 次**。

## 5. 判定与它的边界

**`tpgap` 条件 (a):INDETERMINATE(第一次在 4 粒种子 96 局上量,不是 NOT BOUGHT 的重复)。**

三件事各自站着,不互相顶替:

1. **聚合层**:子域两层反号 ⇒ 按铁律 4 (i-b) **不构成读数**;工具独立地判 REFUSE。
   全带分层(mid_gap ∧ retreat)两层**同号下降**(−0.0136 / −0.0443),
   ⛔ **但那不是 `tpgap` 的域** —— 37-id 捆绑波里任何撤退相关杠杆都可能造成它,
   而对照 `walk_guard`(两层 −0.0177 / +0.0521)与 `far/no_enemy`(+0.0313 / −0.0078)
   自己就不干净 ⇒ **本组不把全带的下降记到 `tpgap` 头上**。
2. **帧层**:**1 枚反例**(§2),**0 枚正例**。守卫「拒了」的证据仍然是零 —— 结构上如此
   (拒绝 = 一次没发生的按下),所以 (a) 只能靠反例累积或靠仪器补齐。
3. **反向哨兵不塌**(§3)⇒ 「它错拒了一堆撤退」这条替代解释,本轮**可以排除**。

**能把它移出 INDETERMINATE 的,只有两件事之一**(都不需要新波、不花 AWS):

- **(甲) 仪器**:dumper 的 snapshot 补 **移动速度** 与 **每英雄可见性**两个字段
  ⇒ 本轮 10 枚 UNSETTLED 立刻可定案,且此后每一波都自动买得到。**本轮已开 issue**(§6)。
- **(乙) 语料**:在**不放宽谓词**的前提下把子域 episode 从 26 堆到几百 ——
  按本轮实测密度(0.11 / 局 armed),那是 ~1000 局量级,**比 (甲) 贵得多**。

⛔ **本组不裁 promote/reject、不申请波次、不改 bot Lua、不花 AWS 钱。**

## 6. 交棒

- **GH #159 追评**:本文全文读数 + §2 承重帧 + §4 的仪器读数。
- **新 [harness] issue(GH #662)**:请求 dumper snapshot 补 `move_speed` 与 `visible_to_team`
  两个字段。验收:同一份 W60 语料重跑 `tpgap_domain.py`,`0 EXCUSED / 1 SHOULD-HAVE-REFUSED /
  10 UNSETTLED` 里的 **10 枚 UNSETTLED 全部落到 EXCUSED 或 SHOULD-HAVE-REFUSED**。
  ⭐ 它不是一条 id 的债:`tp_channel_death.py` 全家(`tpreach`/`tpcommit`/`tpdying`/`tpdead`)
  与任何以「可见敌人」或「移速」为子句的杠杆,都卡在同一堵墙上。
- **帧建议(给协同组/总监,不是本组的判定)**:若要为这条 lever 钉 fixture,
  用 `20260909_093852_slot7 t=549.6 queenofpain`(§2)——
  仓库里第二枚、也是本轮唯一一枚三条 fall-through 全排除的真实帧:
  `make_fixture.py <timeline> --t 549.6 --hero queenofpain`。
  ⚠️ 落地价目表见 GH #659 的教训(fixture 入 `tests/fixtures/` 会改动其它断言的分母),
  **本组不代付**。

## 7. 复现

```bash
bash tools/batch_test/aws/session_setup.sh                    # S3 只读
for R in …7689b5 …be701b …15755b …7a68aa; do
  bash tools/batch_test/behavioral/sweep_run.sh \
      s3://dota2bot-batch-results-4924/soak/spot_20260909_0923*_1_f25680bc…_$R/
done                                                          # SWEEP_EXIT=0 ×4
python3 tools/batch_test/behavioral/tpgap_domain.py --selfcheck   # 50 PASS / 0 FAIL
python3 tools/batch_test/behavioral/tpgap_domain.py \
        tools/batch_test/behavioral/.sweep_out/spot_20260909_0923*_1_*
```

`bots/` / `game/` / `tests/` / `tools/` 本轮**一行未改**。
