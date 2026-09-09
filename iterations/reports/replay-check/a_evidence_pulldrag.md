# `pulldrag` 条件 (a) 取证 — W60 语料 96 局

```
VERIFY id=pulldrag verdict=INDETERMINATE episodes=159
```

**一句话**:`pulldrag` 的方向改动在**帧上看得见**(一段 armed 拖拽里连续 **7 个外走步
`cos_lane ≥ 0.95` 而 `|cos_home| ≤ 0.26`**),但它**不能被提升为判决** —— 因为
⭐⭐ **这一波结构上没有「shipped 腿」**:`pulldrag` 的调用点整个长在 `pullcamp` 的
armed-only 分支里,而两者**同在一个 37-id 串**里一起 armed ⇒ 语料里只有
「armed 行为」与「什么都没有」,**从来没有出现过它要取代的那个朝泉水的拖拽**。

---

## 一、可达性(先验证,再读数)

| 项 | 读数 |
|---|---|
| `pulldrag` 在 arm 串里 | **是**,37 个里的第 **15** 个(逐字核对 sweep 日志里每局的 `cand=`) |
| 语料 | W60 四个 run,**96/96 局**宽扫,`unparseable 0`,`SWEEP_EXIT=0` ×4 |
| pinned tree | `f25680bcbed59113248284bdec39f624c24e525b` |
| 仪器 | `tools/batch_test/behavioral/pulldrag_walk.py`(**已在 trunk**,08-25 本组自己写的;本轮**零新代码**) |
| 仪器自检 | `--selfcheck` **exit 0,12/12 PASS** |
| `campbind` 污染 | **不成立**:`campbind` **不在**本波 arm 串里 ⇒ §BW/§EC.3 那条「connect 读数换了定义域、不许并池」对本波**不适用** |

## 二、⭐⭐ 头号读数:这一波没有 shipped 腿(结构事实,零 AWS 可查)

调用链逐字(读的是源码不是散文):

```
bots/mode_roam_generic.lua:383   if bot.roamCampPull ~= nil then      <- pulldrag 调用点的唯一外壳
bots/mode_roam_generic.lua:454       local vLane = J.GetLanePullDragTarget(bot, bot.roamCampPull)
bots/mode_roam_generic.lua:102-106   bot.roamCampPull = vCamp   <- roamCampPull 的唯一来源
bots/FunLib/jmz_func.lua:10337       if not J.IsSoakCandidate('pullcamp') then return nil end
```

⇒ **baseline 腿上 `bot.roamCampPull` 恒 nil,拖拽分支一次也不执行。**
于是本波两条腿分别是:

| 腿 | 营地拉扯节奏 | 拖拽落点 |
|---|---|---|
| armed | **在跑**(`pullcamp` armed) | **lane**(`pulldrag` armed) |
| baseline | **不存在** | —— |
| ⛔ 缺的那条 | 在跑 | **fountain**(shipped) |

**识别 `pulldrag` 需要的对比是「朝泉水的拖拽 vs 朝线的拖拽」,而这一波两条腿里
都没有前者。** 这不是样本不够,是**设计上答不了**:再多帧也变不出第三条腿。

⚠️ **这与 `pullcad` 陷阱不是同一件事,容易读混。** `pulldrag` 的**门**是独立的
(`turbo + pulldrag`,**故意没有**与 `pullcamp` 合取 —— 立项时的理由逐字写在
`iterations/streams/test_set.md:320`「入集提议档案」那条:合取会踩 `pullcad`
「promote 冻死点名它的门」那个陷阱),
所以 `check_armed_wiring.py` 说它 WIRED 是**对的**。出事的是**运行时的域**:
门独立,**域嵌套**。⇒ 可迁移的一句:
**「门没有合取」不蕴含「域没有嵌套」;调用点长在谁的分支里,谁就是它事实上的前置。**

## 三、逐帧在先(硬规则)

### 3.1 承重帧 —— armed 腿,一段真正的拖拽

`…_7a68aa/20260909_100909_slot3`,**lion**,dire 队 = **armed 腿**(`ba(cand=dire)` 层),
营地 `(-3910,4829)`,lane=**TOP**,`lane_pt=(-3906,6031)`,`home=(7051,6316)`。
**两条射线在这里近乎垂直**:到线 **1,201 u**,到泉水 **11,070 u**。

| t | step | cos_home | cos_lane | d_camp | foll |
|---|---|---|---|---|---|
| 278.4 | — | — | — | 13 | 7 | ← **POKE**(hp 1.00→0.91)
| 279.4 | 325 | **+0.26** | **+0.99** | 333 | 7 |
| 280.4 | 218 | **−0.14** | **+0.98** | 543 | 0 |
| 281.4 | 396 | **+0.07** | **+1.00** | 939 | 2 |
| 282.4 | 18 | +0.40 | −0.83 | 922 | 2 | ← 折返
| 283.4 | 396 | +0.06 | −0.98 | 529 | 0 | ← 回营地
| 284.4 | 154 | **−0.19** | **+0.97** | 677 | 7 |
| 285.4 | 335 | **−0.19** | **+0.95** | 1005 | 4 |
| 288.4 | 56 | **−0.13** | **+0.98** | 531 | 7 |
| 289.4 | 388 | **−0.12** | **+0.98** | 913 | 0 |
| 290.4 | 33 | +0.16 | −0.90 | 881 | 1 | ← **POKE**

**7 个外走步全部 `cos_lane ≥ 0.95`,其中 `|cos_home| ≤ 0.26`。**
shipped 的那条(朝 11,070 u 外的泉水)会把这 7 步打成 `cos_home ≈ +1`。
**这是这份语料里 `pulldrag` 最像"在生效"的一段。**

### 3.2 ⛔ 但阴性对照把它拦下了 —— baseline 腿走出同样的方向

`…_7a68aa/20260909_095701_slot8`,**lion**,dire 队,该局 `cand=radiant` ⇒ **baseline 腿**
(分支**不可能执行**),同一族营地 `(-3926,4840)`,同一条 TOP 线:

| t | step | cos_home | cos_lane | d_camp |
|---|---|---|---|---|
| 228.5 | 81 | +0.92 | −0.22 | 52 | ← **POKE**(唯一一次)
| 230.5 | 343 | −0.09 | **+0.96** | 375 |
| 231.5 | 219 | +0.49 | **+0.97** | 553 |
| 233.5→241.5 | — | ↑ | ↓ | **934 → 1,163 单调远离** |

**戳完之后朝线走,`cos_lane` 一样打到 +0.96/+0.97** —— 而这条腿上那段代码**根本没运行**。
⇒ ⭐ **「朝线走」不是这个杠杆的签名**:它是**辅助戳完野之后回线的默认动作**,
杠杆恰好把落点设成了同一个方向。**判别子必须比方向更强。**

区别**看得见但归不到 `pulldrag` 头上**:armed 那段是**多次戳 + 每次折返**(拉扯节奏),
baseline 那段是**戳一次就走**。可**节奏归 `pullcamp`/`pullcad`,不归 `pulldrag`** ——
本 id 的全部内容只是那一步**指向哪里**(charter §4a 归属纪律)。

## 四、聚合(铁律 4 (i-a):两层读数都登记;(i-b):反号=噪声)

四个真营地由**最近邻**匹配(裕度 ≥1,323 u,见 §六限度 1):
`(180,−5194) (3983,−5029) (−3913,4816) (−845,4933)`。

| 层 | 腿 | n | lane_win | home_win | still(1s) | mean_pl | mean_pf |
|---|---|---|---|---|---|---|---|
| ab(cand=radiant) | armed | 31 | 12 (39%) | 10 (32%) | 18 (58%) | **−45** | +174 |
| ab(cand=radiant) | baseline | 11 | 9 (**82%**) | 2 (18%) | 2 (18%) | **+411** | +149 |
| ba(cand=dire) | armed | 50 | 38 (**76%**) | 10 (20%) | 13 (26%) | **+328** | +67 |
| ba(cand=dire) | baseline | 9 | 4 (44%) | 0 (0%) | 7 (78%) | +71 | −88 |

多戳(节奏)子集里,`cos_lane ≥ 0.7` 的步子占比:

| 层 | armed | baseline |
|---|---|---|
| ab | **18%** (3/17) | **60%** (6/10) |
| ba | **67%** (31/46) | **0%** (0/3) |

⛔ **两层每一种切法都反号**,而这是**计数类 + 侧偏未消除**的量
⇒ 按铁律 **4(i-b) 记为噪声,不写进结论**。
**反号在这里还有结构解释,不是运气**:子域由**四个物理营地**定义,而营地**属于某一侧**,
所以 ab 层与 ba 层抽的**根本是不同的营地和不同的线几何**,估计量**没有消掉侧偏**,
每格样本 3–50。**这个反号不会靠加局数消失。**

## 五、⚠️ 两条仪器缺陷(本轮顺手量出来的,影响的不只是本 id)

### 5.1 dumper 输出**不确定**,且 detect.py 对顺序敏感

同一个 `.dem`、同一个二进制(`md5 fb6b9fd0…`)连跑两遍:

```
tl1  5687ac66dc34c4c77e049c72ee77d54c
tl2  7e3a2a8105f8475d8075a7edb6721912   <- 不同
sweep 0aefa51f7bac8d66815560766edb7186  <- 又一个
```

**内容相同、顺序不同**(逐流核对):
`snapshots`/`creeps`/`buildings`/`wards` **same_multiset=True, same_order=False**;
`events` 顺序稳定。—— 这是 **Go map 迭代顺序**的形状。

`detect.py` 在**固定 timeline** 上是确定的(同一份跑两遍 md5 逐位相同),
但它**对顺序敏感**,于是同一局的 findings 变成 **111 / 114 / 116**,
13 个检测器里 **6 个**逐次不同。

**在整份语料上的后果**:同一份 **96 局**、同一份代码(`detect.py`/`sweep_run.sh`
自上一轮起零 diff),本轮宽扫表与上一轮(09-09T13:15Z 报告 §二)**13 个检测器里 11 个对不上**:

| 检测器 | 上一轮 | 本轮 | Δ |
|---|---|---|---|
| idle_while_ally_dies | 412 | 424 | **+2.9%** |
| died_with_ult_ready | 717 | 729 | +1.7% |
| sandwiched_walk | 3127 | 3163 | +1.2% |
| enemy_overchase_unpunished | 156 | 159 | +1.9% |
| tp_home_wasteful | 653 | 647 | −0.9% |
| …(另 6 个) | | | |
| lowhp_limbo / missed_cs_at_tower | 139 / 543 | 139 / 543 | **逐位相同** |

⇒ **宽扫表不是可复现的读数。** 它现在只被当作选点用(铁律 4(i-b) 已经不许它进结论),
**那条纪律恰好一直挡着这个缺陷**;但任何**把宽扫计数当读数**的用法都在沙上。

**本组自己的读数不受影响,而且是查过的不是猜的**:`pullcamp_domain` 的帧索引是
`self.frames[hero][t] = s` 字典,**只有出现重复 `(hero,idx,t)` 键时**才会 last-write-wins;
实测该局 **0 个重复键** ⇒ 顺序打乱对本文所有数字是**恒等变换**。

### 5.2 `neutrals_at()` 把「不知道」洗成「没有跟」

`CREEP_STALE = 1.6`(`pullcamp_domain.py:107`),而 creeps **每 3.00 s 才采一次**
(实测 554/554 个间隔全是 3.0 s)⇒ **每 3 秒里有 1.4 秒(47%)`creep_sample()` 返回 `None`**。
`creep_sample` 自己**写得很小心**(显式陈旧上限,注释逐字「never a fixed offset」),
出事的是消费点:`pulldrag_walk.py` 里 `nb = g.neutrals_at(t2) or []` ——
**`None`(不知道)与 `[]`(没有野跟着)在这一行合流了**,`following` 记 0。

**方向是单边的**:shipped 的 DRAG 谓词要求 `following > 0`,所以缺样本一律把
`shipped_drag` **压成 False**。本轮 159 行里 `following==0` 占 **57 行(36%)**。
⇒ 本文**没有**拿 `shipped` 那一列当论据(§二用的是源码调用链,不是这一列)。

与 §GF.3 那条**同族**:`GetLaneFrontLocation` **大声拒答**、`GetAnimActivity` **静静答 0**;
这里是**同一个选择第三次出现**,而且这次拒答的实现(返回 `None`)**已经写好了**,
是消费点用 `or []` 把它抹掉的。

## 六、限度(登记,不藏)

1. **§四的四营地是最近邻匹配,不是逐字相等**:`--selfcheck` 的营地坐标是刷新点,
   语料里的是**首次刷野的位置**,两者差 **21 / 81 / 109 / 161 u**,而第二近的候选
   **≥1,323 u** ⇒ 匹配唯一。⚠️ 本轮**第一次用 60 u 容差,把四个里的三个漏掉了**
   (只剩 18 行、单层),**是那个「n=0 的另一层」提醒了我**,不是我先想到的。
2. **另 9 个营地(45 armed 行)不在 `--selfcheck` 认证的垂直性范围内**,
   本文的方向论证**只用四个真拉野营地**;另 9 个只登记不引用。
3. **`pulldrag_frames.py` 不传 `--side` 会静默把腿标反**(本轮踩到:承重帧那局
   打的是 `leg=baseline`,而它其实是 armed)。**它只影响那行表头文字,不影响坐标与
   cos**,但**报告里照抄表头就会把结论写反**。建议给该工具加一条:无 `--side` 时拒答。
4. **条件 (a) 的三选一本轮给不出**:不是 WORKING(阴性对照走出同方向)、
   不是 SILENT(帧上确实有 `cos_lane ≥0.95` 的连续外走步)、不是 BUGGY(没有任何
   反常执行的证据)⇒ **INDETERMINATE**,而**理由是设计不是数据量**(§二)。
5. **没有量**:armed 腿上那 7 步到底是 `GetLanePullDragTarget` 发的,还是 lane/farm
   模式发的 —— **模式与分支是 bot-VM 状态,`.dem` 里没有**(即 census 的 STOPPER 4)。
   这是 §二那条隔离腿请求存在的**第二个**理由。

## 七、交出去的东西

1. **[batch] 隔离腿请求**:一条 `pullcamp` armed、`pulldrag` **不** armed 的腿。
   先例:`owed_executions.json:tpdying_isolation_leg` 同形。
   **验收写死**:同一份 `pulldrag_walk.py` 在该腿上,四真营地子域的
   `mean_pf` 应显著为正且 `cos_home ≥ 0.7` 的步子占多数(shipped 的朝泉水拖拽);
   若该腿也走线,则 `pulldrag` 在真实引擎里**本来就是 no-op**,直接退集。
2. **[harness] dumper 顺序不确定**(§5.1)。**验收写死**:同一 `.dem` 连跑两次,
   timeline **md5 逐位相同**;并在 `sweep_run.sh` 里加一条这个自检。
3. **[bug] `neutrals_at` 的 `or []`**(§5.2)。**验收写死**:缺样本时消费点**拒答**
   (记 `unknown`),而不是记 0;`shipped_drag` 分母改成"有样本的帧"。
