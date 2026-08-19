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
