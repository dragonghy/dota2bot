# 录像检查组(replay-check)章程

## 使命
逐帧看每一批批测的录像,回答两个问题:
1. **执行核验**:测试集里 armed 的每个改动,在实际对局中到底是
   正常生效 / 有 bug / 完全没触发?(这是新验证哲学的条件 (a),
   没有这个核验任何改动都不能 promote。)
2. **找新问题**:观察中发现的新改进机会,开 issue 交给对应组。

**硬规则:先逐帧后聚合。** 聚合统计只用来选看哪几局/哪几段,不构成结论;
结论必须落到具体局、具体时刻、具体英雄能看见什么。

## 吞吐要求(owner 2026-08-19 提出:每轮只看 2-3 局说不过去)
每轮触发采用**宽扫 + 深查**两层,报告必须写明两层各自的覆盖数字:
- **宽扫(必做,覆盖全部新局)**:对上一波次所有未检的有效局跑
  dumper timeline + detect.py 全套检测器,汇总每个 armed id 的触发次数
  分布(哪些局触发了、哪些局该触发没触发)。这层是批量脚本,不逐帧,
  目标是 100% 局数覆盖,并为深查选点。
- **深查(逐帧,有指标)**:每轮至少逐帧核验 **6 局**(或宽扫标记的全部
  可疑时刻,取多者;首轮工具搭建可豁免,之后不豁免)。优先级:
  (1) 宽扫发现"该触发没触发"(SILENT 嫌疑)的局;(2) 核验记录最少的
  armed id 对应场景;(3) 输得离谱/赢得离谱的局。
- 报告固定一节:`宽扫 X/Y 局;深查 Z 局;每 id 触发计数表`。
- dumper 构建太慢拖累吞吐属于 [harness] 问题,开 issue 给总监,
  不要自己吞下这个时间成本。
- **[2026-08-19 总监已修,issue #25]** 上面两个瓶颈现在有工具了:
  `BIN=$(bash tools/batch_test/behavioral/get_dumper.sh)`(S3 缓存优先,
  命中≈2-3s,不用每会话重建)+ `bash tools/batch_test/behavioral/
  sweep_run.sh s3://.../soak/<run_id>/`(一条命令宽扫整波次,自动跳过
  暖场局,产出 `sweep_summary.md` 每检测器触发计数表,按 candidate/
  baseline 侧拆分)。已在真实数据(`spot_20260819_001001_1_main`)验证
  跑通,25s 处理 4 局。**注意**:`sweep_run.sh` 用的是 `detect.py` 现有
  15 个通用行为检测器(TP/超前/漏杀等),不是逐 armed-id 的专用检测器——
  后者是章程 backlog 第 3 条(执行核验标准化),仍待做。宽扫表只回答
  "哪些局/哪些检测器值得深查",armed id 的三条件核验仍要逐帧完成。

## 每次触发的工作流
1. 看 `iterations/reports/batch-desk/` 最新报告 + S3
   `soak/<run_id>/`,找出上一批还没被检查过的对局
   (在自己的报告里维护"已检查 run_id/对局"清单,别重复看)。
2. 没有新批次:从历史归档里挑测试集中**执行核验记录最少的 id** 补课,
   或者自由巡查(free hunt)找新问题。
3. 下载 .dem → 用 dumper(`tools/batch_test/behavioral/`)出 timeline →
   ReplayScope / detect.py 检测器辅助定位 → **逐帧还原关键决策**
   (死亡、TP、拉野、撤退),核对 armed id 的预期行为。
4. 每个核验结论记录格式:`<id>: WORKING | BUGGY | SILENT`,
   附帧证据(run_id/对局/时刻/英雄/当时视野内有什么)。
5. 值得修的发现 → 开 issue:[strategy]/[hero] 给对应组,[bug] 给总监;
   必须带帧证据 + 建议 fixture 钉哪一帧
   (`tools/batch_test/replayscope/make_fixture.py <timeline> --t <sec> --hero <name>`)。
6. 报告写到 `iterations/reports/replay-check/<UTC时间戳>.md`:
   本轮看了什么、每个 armed id 的核验状态累计表、开了哪些 issue。

## 工具坑(已花过学费,别再踩)
- dumper 事件里英雄名**没有下划线**(如 skeletonking)— 匹配前先 canon 化。
- 窗口统计必须过滤暂停段(detect.py 的 _paused_spans)。
- dumper 是 1Hz 快照,施法瞬间的位置会滞后一拍;深度符号约定见
  `.claude/agents/replay-analyst.md`(完整操作手册,先读它)。
- 已知捕获缺口:WasRecentlyDamagedByAnyHero、角色标签、迷雾判定 —
  遇到影响结论的缺口开 [harness] issue,不要硬猜。

## 当前状态(每次触发后更新)
- 2026-08-01 初始化。测试集 14 个 id(见 test_set.md)执行核验记录:
  teambrain/tpwatch/midtp/suptp 在 07-29~07-31 波次里有过行为验证
  (TP 落地死亡 4.8x→0.66x),其余 id 需要系统性补核验。已检查清单为空。
- **2026-08-19T00:44Z(第一次实际触发)**:看了
  `spot_20260819_001001_1_main`(batch-desk 00:11Z 启动的例行波次,14-id 全集,
  种子 851)两局带 `mirror:` stamp 的对局(`20260819_001945_slot1` radiant=armed,
  `20260819_002958_slot1` dire=armed;另一局 `20260819_001046_slot1` 是暖场局
  script_version 无 mirror 前缀,armed 未生效,已排除——见报告"方法论坑")。
  - `midtp`/`suptp`:**WORKING**,两局独立帧证据(TP 触发条件、落地位置、
    塔边队友受击全部对上代码);局1 落地后因 dragon_knight 加入+Zeus 大招
    翻盘(非 armed id 问题,团战方差),局2 落地后有效纠缠+清线。
  - `tpcommit`:circumstantial **WORKING**(QoP 落地后 13s+ 持续交战未秒回城),
    证据强度较弱,待补强。
  - `tpwatch`(已有 07-29~07-31 验证记录,本轮未新增证据)。
  - `creeppull`/`pullcamp`/`l1trade`/`l5combo`/`lf_rescue`/`teambrain`/
    `ownhalf`/`overchase`/`fieldregen`/`wandbleed`:仍是核验记录最少的 id,
    本轮两局未出现对应场景,**下一轮优先看**。
  - 排查一次 `detect.py` 的 `tp_home_wasteful` 检测器误报(帧证据显示是
    "半血脱战回泉水回血"的正常行为,不是任何 armed id 的锅,也非新 bug)——
    未开 issue,记录在报告里防止重复排查。
  - 已检查 run_id/局:`spot_20260819_001001_1_main` 的
    `20260819_001945_slot1`、`20260819_002958_slot1`(已核验),
    `20260819_001046_slot1`(暖场局,已确认作废)。该波次其余种子
    (852/853/854,来自另一实例 `spot_20260819_001007_1_main`)及后续新局
    留给下一轮。
  - 完整报告:`iterations/reports/replay-check/20260819T004401Z.md`
- **2026-08-19T02:36-03:30Z(第二次触发,宽扫+深查两层)**:batch-desk 02:09Z 报告
  显示同一 14-id 全量测试集(vs 稳定版)三个种子(851/853/854)gpm/xpm 全部同向
  负偏差(均值 gpm -27.08,854 最差 -63.8)。本轮委托两个 replay-analyst 子代理
  并行补完 `spot_20260819_001001_1_main`(种子851剩余2局)+
  `spot_20260819_001007_1_main`(种子853全4局+种子854全4局)——**10/10 局宽扫,
  8/10 局逐帧深查**(超过章程 6 局下限)。两个 run_id 的全部 12 局 mirror 有效局
  (14 dem 减 2 暖场局)现已 100% 检查完毕。
  - `ownhalf`:**WORKING**,本轮 3 局独立帧证据(002443 zeus×2 越境死区、001937
    SK、003005 CM),均在 1200-3000u 死区正确捕获入侵者。
  - `overchase`:**WORKING(倾向,样本小)**,854 组唯一一次 `[20]` 检测器命中在
    baseline 侧,未见 armed 侧反例。
  - `fieldregen`:**WORKING**,002443 局 PA t≈608-618s 场外补给帧证据干净。
  - `lf_rescue`:**混合 WORKING+SILENT**——002443 局 Oracle→Axe 触发正确;
    001937 局 Crystal Maiden→Lina 前置条件全满足但落地在泉水非目标位置,SILENT。
    已评论 issue #21(结构性提醒:与已拒绝的 lf_recover/lf_support 同属跨图 TP
    机制,建议单独做 GPM 差分而非只看单帧正确性)。
  - `creeppull`/`pullcamp`:**SILENT(10/10 局)**,两侧对称沉默(0-400s 窗口内
    无经典拉野痕迹)。已评论 issue #13,怀疑触发窗口/阈值与 Turbo 兵线节奏不匹配
    ——若属实,测试集 14 个 id 实际只有 12 个在起作用,是下次判读前应先修的前置
    问题。
  - `l1trade`/`l5combo`/`teambrain`/`wandbleed`:证据不足或无压力样本,不下结论。
  - `midtp`/`suptp`/`tpcommit`/`tpwatch`:低优先级未深挖,沿用既有 WORKING 记录。
  - 非-armed-id 新发现:854 组 `20260819_005355_slot1` 局 DIRE(armed 侧,输)
    集火目标全打辅助、从不针对滚雪球的 Lina(0死/1574GPM 断层第一),已开新
    issue #26([strategy])。
  - -27gpm 负偏差**未找到直接 BUGGY 机制**,两条线索留给协同组/批测台下一步
    (lf_rescue 结构性提醒 + creeppull/pullcamp 疑似全 SILENT)。
  - 待补:`spot_20260819_020910_1_main`(种子852补跑,02:09Z 启动,本轮触发时
    仍在跑)留给下一轮。
  - 完整报告:`iterations/reports/replay-check/20260819T033000Z.md`
- **2026-08-19T04:51Z(第三次触发)**:检查 batch-desk 04:08Z 报告
  确认已收割的 `spot_20260819_020910_1_main`(种子 852 补跑,单独 gpm -57.13)。
  委托 replay-analyst 子代理完成宽扫+深查。宽扫 63/63 局(analysis.json
  级);现存 `.dem` 只有 4 波次里各 1 局(结构性上限,非偷懒,上一轮已记录同现象),
  3/3 全部逐帧深查。三个 run_id(`spot_20260819_001001_1_main`/
  `spot_20260819_001007_1_main`/`spot_20260819_020910_1_main`,即整个
  14-id 全集 4-seed 波次)**现已 100% 检查完毕**。
  - `creeppull`/`pullcamp`:**SILENT 累计 13/13 局**,证据已扎实,评论 issue #13
    建议直接查代码触发阈值。
  - `ownhalf`/`overchase`:**WORKING(重新确认)**,检测器计数继续偏向候选侧。
  - `wandbleed`:**WORKING(circumstantial,上调)**,找到 4+ 处血量<45%+
    敌距>1000u 用魔杖的用例,充能数不可见故非确证。
  - `teambrain`:**首次拿到压力样本,MIXED**——一局干净 WORKING(4人 regroup
    反打零损失),一局可疑(TP 落地点远离实际战场,孤立友军被点杀)。评论 issue
    #23,建议钉 fixture 核对 `J.ShouldAllowDefendTp` 落地目标逻辑。
  - `l1trade`/`l5combo`:**证据仍不足(连续三轮)**,dumper 缺 lane-role 字段,
    録像推断到头,需要工具增强或直接代码级 fixture。
  - 种子 852 单独 -57.13 gpm **未找到 armed-id BUGGY 机制**——归因为该种子固定
    draft 的英雄池强度不对称(拆分 wave 后 armed=radiant 侧 +128.22,
    armed=dire 侧 -242.48,方向相反且与 armed 方无关,纯 hero-matchup 效应)。
    提醒批测台/协同组:4-seed 均值(-34.59)才是该信的数字,单种子读数会被
    draft 偏置误导。
  - 非-armed-id 新发现:Luna 独自越境送死(与 issue #26 镜像,已评论)。
  - 完整报告:`iterations/reports/replay-check/20260819T045112Z.md`
- **2026-08-19T06:45Z(第四次触发)**:对象是 batch-desk 06:07Z 启动的
  **`l1xpsoak` solo 波次**(4 台各 1 种子:`spot_20260819_060925/060928/
  060932/060935_1_main`,种子 855-858)。触发时波次仍在跑,已落 16 个 `.dem`。
  **宽扫 12/12 有效镜像局(4 个暖场局自动跳过);深查 6 局**。
  - `l1xpsoak`:**SILENT(被支配 / 不可区分)** —— 措辞关键:不是"门从未为真",
    而是**即使为真,产出的行为与已 promote 的默认 `lanesurv` 逐字相同**。
    代码级:唯一消费点 `mode_retreat_generic.lua:252` 丢弃了锚点 Vector(重设计
    的"绝对锚"卖点对位置不再有任何影响,只剩滞回状态位),且入场条件是
    `ShouldRetreatLaneBurst` 的真子集、返回同一个 `BOT_MODE_DESIRE_HIGH`。
    帧级:335 个入场几何 episode 里 **236 (70.4%) 的 1100 内已有 >=2 敌**
    (敌人集合完全相同,逐位同判)、**326 (97.3%) 有 >=1 敌**,只有
    **9 (2.7%)** 落在 l1xpsoak 独占的 1100-1200 环;这 9 帧逐帧还原,armed 侧
    core 场景**无一**出现可归因的回泉水位移(855 DK t=140.5 撤退发生在独占帧
    之前且随后掉头打赢换血;856 sniper t=123.5 反而前压;857 luna t=304.5
    HP 23% 在自家一塔前晃 15s+ 无回撤)。另 3 局拍到干净回撤(858 SK 2300u、
    858 necro、855 DK 站桩)但入场帧 n1100=2,归因不到本 id。
    **→ 本波批测读数不能当作 `l1xpsoak` 的条件 (b):两侧在 97.3% 的帧上跑的
    是同一条规则,正负都是噪声。** 已开 issue **#28 [strategy]**,含两条改法
    建议 + 建议钉帧 `spot_20260819_060932_1_main`/`20260819_061819_slot1`
    t=304.5 luna(本波唯一干净独占帧)。
  - 新发现 **#29 [bug]**:`mode_retreat_generic` 链上 241(`lf_chase`,HIGH)、
    252(`l1xpsoak`,HIGH)排在 259(`tpwatch`,**VERYHIGH**)之前,先命中先
    return → "TP 读条被打死立刻中断"这条最高优先级规则被两条 gated 的 HIGH
    降级。本波不受影响(tpwatch 未 armed),但上一次 14-id 全集两者同时 armed
    —— 是 -34.59 gpm 负偏差的结构性候选解释(id 之间非独立)。
  - 工具缺口(不硬猜):dumper 不落 `GetEstimatedDamageToTarget`,"爆发 >= 75%
    HP"永远无法离线判定(本轮 335 episode 是真实触发的超集),滞回带 40%-75%
    完全不可测;lane-role 字段仍缺(连续第四轮记录)。已写进 #28,未单开 issue。
  - 已检查:上述 4 个 run_id 各 3 局(共 12 局)全部宽扫完毕,暖场局
    `_061017/_061020_slot1` 已确认作废。波次后续新局留给下一轮,但按本轮结论
    继续加局对 `l1xpsoak` 定性无帮助(瓶颈是机制不可区分,不是样本量)。
  - 完整报告:`iterations/reports/replay-check/20260819T064500Z.md`
- **2026-08-19T08:50Z(第五次触发)**:batch-desk 08:08Z 是纯收割轮,**无新波次**,
  06:09Z 那波的 16 个 `.dem` 与上一轮已检的完全重合(零新增)。按章程第 2 条转向
  **核验记录最少的 id**:`l1trade`/`l5combo`(连续三轮"证据不足")。对象是它们唯一
  armed 过的三个 run(14-id 全集波次 `_001001`/`_001007`/`_020910`)。
  **宽扫 15/15 有效镜像局;深查 6 局;帧级机会扫描覆盖全部 15 局 333 个 episode。**
  (更正上一轮记录:那三个 run 的 `.dem` 不是"各 1 局",实际有 5+9+4=18 个。)
  - `l1trade`:**SILENT**。`l5combo`:**SILENT**。与 `l1xpsoak` 同类——不是
    "门没开",而是**设计出价在生效域内结构上不可达 + 全部可观测门满足的窗口里
    两侧无可归因差异**。
    代码级:两分支出价 0.92,但 `GetDesire()` 的 `CapForLanePush`
    (`mode_team_roam_generic.lua:78-90`)在 laning phase 把 >0.9 一律压到
    **0.72 < BOT_MODE_DESIRE_HIGH(0.75)**;两个 helper 又都硬性只在 laning
    phase 返回非 nil(`jmz_func.lua:6582`/`:6652`)→ **cap 条件是规则生效域的
    超集**,0.92 永远不可达,且有效出价对血量非单调(满血 0.72,~48% 血 ~0.90)。
    两分支都没设 `bDefensiveCollapse`(`punishDive`/`overchase` 设了),`divecap`
    豁免也未 armed。
    帧级差分(armed vs baseline):"4s 内本人对目标造成伤害"= l1trade 57.9% vs
    65.8%、l5combo 62.7% vs 73.2%;击杀转化 38.3% vs 41.4%、44.1% vs 51.8%
    —— **armed 侧全面更低**,无一项朝设计方向。
    关键帧:`_004003` t=246.4 Ogre(p3)对 9% 血 DK 的 ignite 正在跳却**切走去
    打 CM**(sticky+4s commit-lock 若生效不可能);`_002958` t=214.4 DK(p4)+
    核心 SB 在 73u,对 13% 血 PA **11 秒零伤害**;`_002451` t=183.5 Lich 对 9% 血
    Pudge 594u 一路走开。存疑不采信的两帧(`_002443` Axe / `_023010` DK 12% 血)
    是 self-risk 门**正确抑制**,已如实标注。
    边界:dumper 不落 `GetEstimatedDamageToTarget` → 致命性/self-risk 门离线
    不可判定,333 episode 是真实触发集的**超集**。
  - 已开 **issue #31 [bug]**(总监):含算术推导 + 差分表 + 6 局帧证据 +
    两处建议钉帧 fixture,并指出**现有 `tests/test_l1_trade.lua`/`test_l5_combo.lua`
    只测 helper,零测试覆盖 `CapForLanePush` 之后的最终出价**。建议按
    `creeppull`/`pullcamp`/`l1xpsoak` 先例把两个 id 移出 armed 集(它们留在集里
    会继续污染残差判读)。
  - **工具缺口已解决(连续四轮记录的 lane-role)**:不需要 dumper 增强,
    **位置 = `analysis.json:team_slot` % 5 + 1**(`aba_role.lua:13` 的
    `RoleAssignment` 是固定 [1,2,3,4,5] 循环表)。15 局补刀梯度验证:
    31.6/31.7/20.9/15.1/13.8,单调且量级正确。以后分位置的检测器直接用。
  - 新踩的坑(记录):机会扫描必须排除 `hp_pct==0` 的**尸体帧**(首版 577 个
    "机会"全是尸体);1Hz 滞后会让"死亡刚好在 t0 前 0.2s"的 episode 误标未击杀。
  - 未定性但下一轮优先:宽扫 `idle_while_ally_dies` 候选侧 32:22 偏高且三个 run
    方向一致;`overextend_alone` 分 run 反号(36:17 vs 2:16)判为噪声。
  - 完整报告:`iterations/reports/replay-check/20260819T084950Z.md`
- **2026-08-19T11:00Z(第六次触发)**:batch-desk 10:07Z 是**纯运维轮,零支出、
  未启动波次**(节流条件 (i) 差约 2h,下一波最早 12:09Z);S3 `soak/` 零新增 `.dem`。
  按章程第 2 条转向**核验记录最少的 id** —— 这次答案不含糊:**`cmrguard`**,
  它今天才入集、**从未 armed 过、执行核验记录为 0**,而且**下一波会第一次 arm 它**。
  本轮做**上机前反事实核验**(把门在真实帧上离线重放)。
  **宽扫 14/14 局(现存录像里全部含 CM 的 mirror 有效局);深查 5 局。**
  - `cmrguard`:**NOT-YET-EXECUTED**(反事实重建,非执行核验)。
    14 局 CM 真实开大 14 次,门会否决其中 **5 次(36%)**;逐个跟踪否决者之后
    12s 有没有真把硬控放出来:**1 次明确误报**(`_004858` t=423.4,centaur 在
    1326u 持 `hoof_stomp`,12s 内从未施放且单调走远到 3077u;hoof_stomp 是
    自身半径 315 的 AoE,根本够不着),**1 次威胁不迫近**(`_061821` t=521.5,
    SK 的 blast **12.0s 后**才放,门这 12s 一次没解除,CM 血 1.00→0.03),
    3 次大概率正确(含代码注释里的立案帧 `_003005` t=372.5 jakiro 1139u —— 我的
    重建**逐字命中**该帧,保真度自检通过)。
  - **根因(代码级 + in-repo 先例)**:`J.GetReadyHardCc` 的 docstring 明说返回
    handle 就是让调用方 **range-check**,但 `cm_IsRSafeToOpen` 调布尔包装
    `J.HasReadyHardCc` 把 handle 丢了(`grep`:全仓库唯一一处)。而
    `jmz_func.lua:4773-4787` 的 `ccburst` 注释记录着**同一缺陷在 2026-07-23
    的批测 bisect 里已经付费诊断并收窄过**("range-blind … prime single-id
    suspect of the passive-stack death signature"),现成模板
    `<= ( hCc:GetCastRange() or 0 ) + 250` 还恰好正确处理 hoof_stomp 这类技能。
    → **"消费方丢掉 helper 特意返回的精度"的第三例**(#28 锚点 Vector、
    #31 出价被下游 cap、本例 handle),建议总监并进 test_set.md §0b 复发类别。
  - **已开 issue #34 [hero]**:5 帧证据表 + 关键帧轨迹 + 建议**两帧一起钉**
    fixture(`_004858` t=423.4 必须放行 / `_003005` t=372.5 必须拦住),
    避免重演 `lanefix` 的"单点正确、整体变差"。未越权调阈值(n=5 不足以定
    `+250`,#3 的 822u 擦边)。
  - **⚠️ 可测性警告(已写进 #34,下一波前必读)**:基频 **1.0 次开大/局 ×
    36% 改判 ≈ 0.36 次/局**;`ConsiderR` 主分支(≥3 敌在 ~735u)14 局只成立
    **2 个窗口且零开大**。对照 GH #30 的经验零点(σ≈30 gpm/seed,SE≈15),
    **这个量级在 gpm 上不可能被看见** → 下一波 `cmrguard` 若读数为 null,
    **既不构成"无效"也不构成"无害"**,条件 (b) 必须用行为检测器(开大次数、
    开大后 10s 死亡率)判,否则是拿噪声发通行证(`l1xpsoak` 翻版)。
  - **新工具坑**:dumper 会用同一 class name 吐出多个实体(`main.go:79` 的
    `idx` 就是消歧用的)。跟踪单个敌人时间序列**必须先锁 `idx`** —— 没锁的
    第一版把 shadow_shaman 的轨迹污染成两条交错假轨迹,会直接得出错误结论。
    比"尸体帧 `hp_pct==0`"更隐蔽。
  - 完整报告:`iterations/reports/replay-check/20260819T110000Z.md`
