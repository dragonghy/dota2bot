# `outlatch` 条件 (a) — 真帧 fixture 证据

投递物,对应 `iterations/owed_executions.json:outlatch_condition_a_fixture`
(裁定 `outlatch` RETURNED_OUT_OF_TEST_SET_ON_A,总监 2026-09-12,全文
`iterations/streams/test_set.md §HA.1`,处置 **INSTRUMENT-BLIND**)。

交付轮:录像检查组 2026-09-17T15:xxZ(W89)。
测试文件:**`tests/test_outlatch_latch_real_frame.lua`**(8 tests / 0 failures)。

---

## 〇、这一行欠的是什么,以及为什么树上已有的那个文件不算

owed 行的验收句逐字要三样东西:

1. 一份 **`tests/fixtures/` 的真帧** fixture;
2. 那一帧上 `GetUnitList(UNIT_LIST_ALL)` **不含任何 `#DOTA_OutpostName_*`**;
3. 一条断言:**armed 时 `DidWeGetOutpost` 未被置位**(或 `NextOutpostScanTime`
   被推进 ⇒ 下一秒会重扫),**而 shipped 时它被置位**。

并且逐字写明:⛔ **`tests/test_outlatch_scan_postcondition.lua` 不算** —— 它是
**静态源码棘轮**(读一个文件证明机制),不是真帧 fixture。

本文件交付的正是这三样:shipped 的模式文件被**真的加载并驱动**,判词读自
**运行中的代码**,不读自源码文本。

---

## 一、真帧

| | |
|---|---|
| 局 | `20260905_010205_slot7`(run `spot_20260905_003250_1_…_695907`,seed 4763,armed=夜魇) |
| 波次 | **W47**(62-id 家族第二波) |
| 时刻 | `t = 1350.5`(22:30) |
| 主体 | `luna`(天辉 ⇒ **baseline 腿**,本帧不属于任何 armed id) |
| 切片 | `tests/fixtures/tl_260905_010205_luna_outchan.json` |
| fixture | `tests/fixtures/outchan/f_260905_010205_luna_channel.lua` |

选它的理由只有一个,且是**语料级**的:它是**全仓唯一**一份 building 表里带着
**两座 `watch_tower`** 的切片(`tests/_outpost_gate_sweep.lua` 2026-09-17 复跑:
112 份 fixture,**1039 个 `UNIT_LIST_ALL` 条目,0 个 outpost**)。同一帧
`tests/test_outcommit_channel_hold.lua` 已经在用,两份文件读的是同一份 dump。

---

## 二、判词(两条腿,同一帧,逐条可复跑)

`OUTPOST_RESCAN_INTERVAL = 1.0`。两条腿各自 `dofile` 一份新的模式文件
(`Outposts` / `DidWeGetOutpost` / `NextOutpostScanTime` 都是**文件局部**,
共用一份会让第二条腿读到第一条腿的闩)。时钟以 10Hz 驱动。

### (甲) shipped:一次扫描,然后这个模式对这个 bot **永久死亡** — `[frame F3]`

| 读数 | 值 |
|---|---|
| 第一 tick 的出价 | `0.000` (NONE) |
| 6 个游戏秒 / 61 个 tick 后的扫描次数 | **1** |
| 那 61 个 tick 里的出价 | 全部 `0.000` |
| **outpost 变为可枚举之后**再 6 秒的扫描次数 | 仍然 **1** |
| **outpost 变为可枚举之后**的出价 | 仍然 `0.000` |

⇒ `DidWeGetOutpost` 在**那一次空扫之后就被置位**,而它是唯一会让生产者
(`table.insert(Outposts, unit)`)再跑一次的东西 ⇒ `GetClosestOutpost` 此后
恒答 `nil`,`GetDesireHelper` 恒答 NONE,`Think()` 里 `:117` 那条连续指令
**这一局再也到不了**。**无报错、无重试、无声音。**

### (乙) armed:每个游戏秒重扫一次,**找到了才闩** — `[frame F4]`

| 读数 | 值 |
|---|---|
| 第一 tick 的出价 / 扫描次数 | `0.000` / **1** |
| 第一个游戏秒结束时的扫描次数 | **2**(= `t0` 与 `t0+1.0`,**不是**每 tick 一次) |
| outpost 变为可枚举之后的扫描次数 | **3**,然后**停住** |
| 停住时的出价 | **`0.720`** |

⇒ armed 时 `DidWeGetOutpost` 在空扫后**未被置位**,`NextOutpostScanTime` 被推进
`+1.0`,**下一个游戏秒确实重扫**;第一次**看见** outpost 的那次扫描把闩关上
(第 3 次之后不再扫),模式**活过来**。

那个 `0.720` **不是本文件里打的常数**:断言拿 fixture 自己的几何复算
`RemapValClamped(GetUnitToUnitDistance(bot, outpost), 3000, 0, VERYLOW, HIGH)`
并比到 `1e-9`。

### (丙) 对照:第一扫就看见时,armed 与 shipped **逐位相同** — `[frame F5]`

| | shipped | armed |
|---|---|---|
| 出价 | `0.720` | `0.720` |
| 6 秒内扫描次数 | 1 | 1 |

⇒ 这个改动在**本来就正常的那条路上零代价、零行为差**。另有两条门对照:
**非 Turbo**、**只 arm 另一个 id(`outcommit`)** ⇒ 两者都回到 shipped 的 1 次扫描。

---

## 三、仪器自证(变异台)

`bots/mode_outpost_generic.lua` 从文件副本还原,退出码**未经管道**读取:

| 变异 | 内容 | 结果 | 抓它的那一节 |
|---|---|---|---|
| **M1** | 把修复回退成 `DidWeGetOutpost = true`(无条件闩) | **CAUGHT** (2 failures) | `[frame F4]` + `[source]` |
| **M2** | 把门恒真(`local bRescan = true or …`)⇒ shipped 也重扫 | **CAUGHT** (3 failures) | `[frame F3]` + 两条门对照 |
| **M3** | `OUTPOST_RESCAN_INTERVAL = 1.0 → 100.0` | **CAUGHT** (1 failure) | `[frame F4]` 的间距断言 |

**3 变异 3 CAUGHT**,且各自被**应该抓它的那一节**抓到。
还原核对 `sha256sum -c` → `OK`(`SHACHECK=0`)。

另有一条**仪器自己的对照**,写在文件头:扫描计数器数的是**调用路径上一切**对
`UNIT_LIST_ALL` 的读取(`J.IsTeamPushingHighGround` / `J.GetEnemiesAroundAncient` /
`J.GetEnemiesNearLoc` 都在路径上)。`[frame F3]` 实测 61 个 tick 总共 **1** 次
⇒ **本帧上其他消费者的贡献被这条读数自己界定为 0**,所以 (乙) 的计数是本文件的扫描。

---

## 四、⛔ 这份证据**买不到**什么(先于任何数字读)

- **(B1) 供给,不是对局事实。** 本帧的空扫是 loader **自己声明的缺口** ——
  `tests/mock/replay_fixture.lua` 在自己的注释里写着它不向 `UNIT_LIST_ALL`
  注入任何结构物,`tests/_outpost_gate_sweep.lua` 量到后果(1039 条目 / 0 outpost)。
  ⇒ 本文件把它**当作空扫的替身台**,而**真实对局里这段代码跑的那一刻是否真的会拿到空扫**,
  是**域的问题**;outpost **根本不在 dump 里**,这正是 §HA.1 把那个零判成
  **INSTRUMENT-BLIND** 而不是 `DOMAIN-NOT-REACHED` 的原因。
  ⛔ **本轮不退休那个处置**,也**不把 `episodes` 读成对局里观察到的触发**。
- **(B2) harness,不是对局事实。** `IsEnemyTier2Down` 在本帧为真,是因为切片只带
  两座 watch tower ⇒ loader 的 `GetTower` 每个槽都答 `nil`。两条腿**完全相同**,
  `[frame F1]` **断言它**而不是假设它(与 `test_outcommit_channel_hold.lua` 的 bound (3) 同一句声明)。
- **(B3) 时钟是规定量。** fixture 是**一个瞬间**;`DotaTime` 被本文件推进,用来量那
  1.0s 的重扫间距。其余帧事实(位置、血量、building 表)**冻结在 t=1350.5**
  ⇒ 最后一 tick 的 `0.720` 是**这一帧的几何**,不是"六秒后 luna 会在哪"的预测。
- **(B4)** "可枚举"那两条腿里的 outpost 句柄,`GetTeam`/`GetLocation`/`IsAlive`
  **委托给 loader 从 dump 建出来的真 building 句柄**(`[frame F1]` 断言这层委托读的是
  dump 的数)。⭐ 而**空扫那两条腿——也就是 owed 行真正要的那两条——什么都不注入**,
  用的就是 loader 自己的列表。

---

## 五、`VERIFY` 行,与 GH #424 三段分界的处置

```
VERIFY id=outlatch verdict=WORKING episodes=1 scope=POSTCONDITION-ON-REAL-FRAME domain=NOT-OBSERVED
```

**逐字说明取自哪一段**(这是 `outlatch_three_era_incomparability` / GH #424 那一行
`done_when` 索要的句子):本读数取自 **W47** 的一局,即三段里的 **第 II 段
(W39–W53,`slotpush` armed、两条腿不对称)**。⛔ **没有并池**:它是
**一帧**,`episodes=1`,**不含任何跨段(或跨波)的合并**。
⭐ 且按 `outlatch_condition_a_fixture` 那一行自己写的:*"fixture 钉的是一帧不是一池波次,
所以 GH #424 那道三段分界对本行不适用"* —— 本轮照此执行,但**不代表本组替总监退休那一行**:
那一行是否因此 `done_when` 满足,**编排权在总监**。

**`WORKING` 的作用域,写死在读数里**:买到的是**后置条件**
(空扫之后 shipped 闩死、armed 重扫且找到即闩、正常路上零差),
⛔ **没有**买到"真实对局里触发过" —— `domain=NOT-OBSERVED`,理由是 (B1)。
⛔ 任何人不得把这一行读成「`outlatch` 可以 promote 了」:条件 (b)(批测无明显负面)
仍然没有,且 `outlatch` **当前不在测试集里**。

---

## 六、复跑方法

```bash
lua5.1 tests/run_tests.lua outlatch_latch_real_frame   # 8 tests, 0 failures
lua5.1 tests/_outpost_gate_sweep.lua                   # 语料普查(stderr)
```
