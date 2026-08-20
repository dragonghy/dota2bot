# 批测台(batch-desk)章程

## 使命
唯一有权花 AWS 钱的 agent。稳定地生产"测试版 vs 稳定版"的镜像批测数据并归档到
S3,让录像组和其他 agent 有料可分析。**不做判断分析,不写 bot 代码。**

## 每次触发的工作流
1. `bash tools/batch_test/aws/session_setup.sh` 引导 AWS(每个新会话必做);
   之后一律用 `awsx`,不用裸 `aws`。
2. `bash tools/batch_test/aws/check_costs.sh` — 查 MTD 花费和在跑资源。
   - **MTD ≥ $90:停止启动任何付费工作**,只做收割/清理,并开
     `[batch] 预算刹车已触发` issue 通知总监。
   - 发现不该在跑的实例:终止它,报告里写明。
3. 收割:扫 `s3://dota2bot-batch-results-4924/validation/` 新 verdict;
   **一律用 `tools/batch_test/soak/recover_verdict.py` 从 S3 逐局数据全量重算**
   (实例自产 verdict 两次不完整,已定为标准收割路径)。结果写进报告 +
   更新 `iterations/queue.json` 对应请求的 status/result。
4. 决定本轮要不要开新批测(优先级从高到低):
   a. `iterations/queue.json` 里 status=pending 的请求(先进先出,priority 高者先);
   b. 队列为空:跑一轮例行"测试版 vs 稳定版"(测试集见
      `iterations/streams/test_set.md`,镜像草稿,armed=测试集全 id 逗号串)。
      **例行波次节流(2026-08-19,防预算烧穿:每波实测 ~$0.5-1.5,若每
      2h 一波则月成本 $180+,远超 $50/月预算)**:满足全部三条才启动——
      (i) 距上一次例行波次启动 ≥ 6 小时;
      (ii) 有新东西可测:bots/ 或 test_set.md 自上一波测过的 commit 之后
           有变更,或当前 tree+测试集的累计种子数 < 8;
      (iii) 当月已花 + 本波预估 ≤ $45(给 $50 的 AWS Budget 留余量;
            owner 批准线另算,见铁律)。
      不满足就跳过启动,报告里写明是哪条不满足。queue.json 的显式请求
      不受 (i)(ii) 节流,只受成本约束;
   c. 稳定版 vs upstream 基线(74727e4a)目前缺 harness 支持 — 已知缺口,
      若还没有对应 [harness] issue 就开一个,不要自己改 harness。
5. 启动纪律:**先 `git ls-remote origin main` 核对远端 tip 等于要测的树**
   (2026-07-23 险些测错树);镜像草稿候选验证用 `spot_run.sh --validate
   "<CAND> <SEEDS> --games N"`(2026-08-19 更正:此前这里误写成 `aws_run.sh`,
   那是另一个更老的纯 old-ref-vs-new-ref 脚本,没有 `--validate`/`CAND` 概念;
   `iterations/state.json` 里记录的历次真实启动全部用的是 `spot_run.sh
   --validate`,详见 `.claude/agents/batch-runner.md`);自毁 Spot + 看门狗;
   Spot 等不到就 on-demand(小时级没多少钱);启动后把请求标记 status=running。
6. 结束前再跑一次 check_costs.sh 确认无泄漏。
7. **报告必须带局数**(owner 2026-08-19 要求):每份报告固定一节写明
   (a) 上一波次的最终有效局数(per seed、per side,ab/ba 不对称要注明),
   (b) 本轮在跑波次的实时进度(S3 `soak/<run_id>/` 里 analysis.json 计数,
   注明暖场局不算有效局)。启动型报告写预期局数,收割型报告写实测局数。

## 与其他 agent 的接口
- 输入:`iterations/queue.json`(请求队列;别的 agent 只能往这里提请求)。
- 输出:S3 逐局数据(soak/<run_id>/)+ verdict(validation/)+
  `iterations/reports/batch-desk/<UTC时间戳>.md` 报告 +
  queue.json 状态更新。录像组依赖 S3 归档,千万别删逐局数据。
- 问题上报:开 `[batch] ...` 或 `[harness] ...` issue。

## 硬知识(不要重新踩坑)
- 镜像批测 stamp 约定 `mirror:<cand>:s<seed>:<side>`;radiant 侧偏置 ≈ +1.5k
  金,必须换边取平均。
- soak-loop 是长驻进程:bash harness 改动要重启 soak 循环,Lua 改动不用。
- 详细操作手册:`.claude/agents/batch-runner.md`(launch/监控/恢复/成本细节)。

## 当前状态(每次触发后更新)
- 2026-08-01 初始化。付费波次此前处于暂停;owner 已批准继续测试预算,
  MTD ~$85(账单有滞后),刹车线 $90 — **本月剩余额度很小,优先收割和排队,
  启动新批测前先看成本**。queue.json 当前无 pending 请求。
- 2026-08-19T00:11Z:本 stream 首次实际触发(此前只有章程文档,无执行记录)。
  新计费月已重置,MTD=$3.45,远低于刹车线,未触发预算刹车。收割:S3 上
  07-31 的历史数据早已被建组前的会话完整收割分析(数字与 state.json 一致,
  抽查复核过),本轮无新数据。queue.json 为空 → 按章程 (b) 跑例行"测试版 vs
  稳定版":test_set.md 现行 14-id 全集(12-id 复审组 + wandbleed + tpwatch,
  这是该全集首次上过 S3)首次整体验证,mirrored-draft,2 台 spot 共 4 种子
  (851-854),commit 96f49dc,预估花费 $1-1.5。跑中实例:
  `spot_20260819_001001_1_main`(种子851/852)、`spot_20260819_001007_1_main`
  (种子853/854),均自毁 spot + 看门狗,预计 verdict ~2-3h 后落地(约
  2026-08-19 02:10-03:10 UTC),下次触发用 recover_verdict.py 收割。启动前
  确认无泄漏,结束前复查仍无泄漏。顺带修正了本章程步骤5里的脚本名错误
  (`aws_run.sh` → `spot_run.sh --validate`,历史启动实际一直用的是后者)。
  详见 `iterations/reports/batch-desk/20260819T001111Z.md`。
- 2026-08-19T02:09:19Z:收割上一波次(14-id 全集,种子 851-854)——
  `recover_verdict.py` 逐局重算发现**种子 852 完全无数据**(该实例 4h 窗口全耗在种子
  851 上,60 局,没能轮到 852;不是抢占,是单波窗口内种子分配不均)。3 种子(851/853/854,
  合计 182 局有效局)结果:gpm 均值 **-27.08**,xpm -22.16,deaths +0.25,last_hits
  -0.80,`comps_better` 全部 0/3(候选组一致更差),与 07-31 已记录的同组合残差
  (-18~-26 gpm)方向一致 —— 判读留给协同组/录像组。本会话执行 `git push origin
  HEAD:main` 把落后 10 个 commit 的 origin/main 追平到当前 tip(ce5c3d2);核对
  96f49dc→ce5c3d2 之间 `bots/`/`game/` 唯一改动(`jmz_func.lua`,l1xpsoak 重设计)
  gated 且不在当前 test_set.md 内,不影响本次候选组合行为。为补齐 4-seed 判定门槛,
  未重开全波次,而是单独补跑种子 852(同 14-id 组合,现 tip):实例
  `spot_20260819_020910_1_main`,c6i.4xlarge spot,16 槽,4h 看门狗,15 局,预估
  $0.4-0.5,预计 ~1.5-2h 后落地。MTD $3.45,远低于刹车线,启动前后均确认无泄漏。
  详见 `iterations/reports/batch-desk/20260819T020919Z.md`。下次触发用
  `recover_verdict.py` 标准路径收割种子 852,与本轮 851/853/854 合并成完整 4-seed
  数据集。
- 2026-08-19T04:08:01Z:收割种子 852 补跑(`spot_20260819_020910_1_main`,已完成
  自毁,130 对象),`recover_verdict.py` 单独算出 gpm -57.13(0/1)。与已收割的
  851/853/854 合并成**完整 4-seed 数据集**(14-id 全集,不含 `l1xpsoak`):
  gpm 均值 **-34.59**,xpm -25.71,deaths +0.24,last_hits -1.21,`comps_better`
  四指标全部 **0/4**——与 07-31 历史同型组合的负向残差方向一致,这是该 14-id
  组合迄今唯一完整的 4-seed 判定,判读/promote-reject 留给协同组/总监。有效局数:
  851=60、852=57、853=74、854=48,合计 239 局。queue.json 空,无 pending 请求。
  例行波次三条件检查:(i) 距上次例行波次启动(00:11Z)仅 ~3h57min,未满 6h ——
  **不满足,本轮不启动新批测**;(ii) bots/+test_set.md 自 96f49dc 起有变更(CM
  Freezing Field 门控 + l1xpsoak 重设计 + test_set.md 新增 l1xpsoak)——满足;
  (iii) 预算 $3.45 MTD 远低于 $45 月度围栏——满足。建议下次满足三条件时把
  `l1xpsoak` 单独测,不要并入已显示可疑负向残差的 14-id 大 bundle(test_set.md
  里协同组/总监已留此提醒)。启动前后 check_costs.sh 均确认无在跑实例、无泄漏。
  详见 `iterations/reports/batch-desk/20260819T040801Z.md`。
- 2026-08-19T06:07:59Z:MTD **$3.45**,无在跑实例,未触发任何预算刹车。收割:
  `validation/` 与 `soak/` 均无 04:08Z 之后的新对象,**本轮无新数据可收割**;
  queue.json 仍为空。例行波次三条件:(ii)(iii) 满足,(i) 实际间隔 5h58min、
  **比 6h 门槛差约 2 分钟**——因该条款立法目的是防预算烧穿而当前 MTD 距围栏有
  数量级余量,且总监在 test_set.md 明写 l1xpsoak 是"下一波最高优先级、必须单独
  测",故照常启动并在报告里如实记录该形式差额(总监若要求严格按字面执行,下次
  按整点对齐)。本波按总监指示测 **`l1xpsoak` solo**(不与 12-id 残组或
  `lf_rescue` bisect 混跑)。**配置改进:一台实例只跑一个种子**——上一波 2-seed/4h
  的实例把窗口全耗在种子 851 上、852 完全饿死只能事后补跑,读
  `validate_onspot.sh` 确认种子是串行处理(每种子 = radiant+dire 两 wave,每 wave
  ~35min stall 上限),故改为 **4 台 × 1 种子**,结构上杜绝饿死,一轮拿全 4-seed。
  启动:seeds 855/856/857/858 → `spot_20260819_060925_1_main` /
  `_060928_1_main` / `_060932_1_main` / `_060935_1_main`(c6i.4xlarge spot ×4,
  16 槽,3h 看门狗,`--games 15`,树 `ce2c5df` = 远端 main tip 已核对),
  预估 $1.5-2,预计 ~07:40-08:40 UTC 落地,预期 ≥120 局有效局。上一波最终局数:
  851=60、852=57、853=74、854=48,合计 239。启动前后 check_costs.sh / describe-instances
  均确认无泄漏(结束时恰好 4 台,全是本轮有意启动的自毁 spot)。下次触发用
  `recover_verdict.py` 标准路径收割。
  详见 `iterations/reports/batch-desk/20260819T060759Z.md`。
- 2026-08-19T08:08:00Z:**纯收割轮,零支出,未启动任何批测**。MTD **$3.47**,无在跑
  实例,无泄漏,未触发任何预算刹车。收割 `l1xpsoak` solo 波次(4 台 × 1 种子,
  855-858,229 局有效局 + 23 局暖场;1-seed/实例的改法奏效,**四种子两 wave 全齐、
  无饿死**):`recover_verdict.py` 全量重算 → gpm **+6.44**、xpm -0.69、deaths +0.05、
  last_hits -0.05,`comps_better` 2/4·2/4·1/4·1/4。因录像组已证实候选侧≈基线侧
  (97.3% 帧同判),这波按总监点名要求当作**镜像 draft 的经验零点**:
  **per-seed gpm delta σ = 30.24(极差 58.6),4-seed 均值 SE = 15.12**;
  换算后 14-id 全集那次的四个指标 z = -2.71 / -3.55 / +2.56 / -2.83,**全在有害方向
  且超出噪声** → 总监的 HOLD 判定被这次校准**支持**而非削弱。同时确立一条纪律:
  **单种子 gpm 差 ±30 属于纯噪声,不得据以对任何 id 下结论**。已开 `[batch]` issue
  #30 把零点表交给协同组/总监。**收割操作新坑**:同波次多实例的 per-game 文件名会
  跨 run 撞车(同秒级启动),直接 `s3 cp` 到同一目录静默丢了 15.9% 的局——必须先分
  run 下载再带前缀合并。启动决策:queue.json 为空,例行波次条件 (i) 距上一波仅 ~2h
  (差 4 小时),**不满足即不启动**(与上一轮差 2 分钟的目的解释不同,本轮无例外情形)。
  下一波最早 12:09Z 后,按 test_set.md 第 3 条做 **`lf_rescue` bisect**(现行 armed
  集已是 13 id,`l1xpsoak` 退出);配置建议:保持 4 台 × 1 种子,**`--games` 提到
  20-25** 以免 dire wave 被截断(本波 dire 仅 80 局 vs radiant 149)。
  详见 `iterations/reports/batch-desk/20260819T080800Z.md`。
- 2026-08-19T10:06:55Z:**纯运维轮,零支出,未启动任何批测**。MTD **$3.4651**,无在跑
  实例,无泄漏,未触发任何预算刹车。收割:`validation/` 与 `soak/` 均无 08:08Z 之后
  的新对象,**无新数据**;queue.json 仍为空。启动决策:例行波次条件 (ii)(iii) 满足,
  **(i) 距上一波(06:09Z)仅 3h58min、差约 2 小时,不满足即不启动**(与 06:07Z 那轮
  "差 2 分钟"的目的解释不同,本轮无例外情形);下一波最早 **12:09Z**。远端核对照做了
  (`git ls-remote origin main` = `7f48356` = 本地 HEAD)。
  **本轮产出两件"免费"的准备工作**:
  (1) **章程 4c 缺口立案 → GH #33 `[harness]`**(检索确认此前从无对应 issue)。查清了
  确切位置而非笼统"缺支持":链路 A(gate 式,现役 `spot_run.sh --validate` →
  `validate_onspot.sh` → `soak_side.lua`)有镜像/种子/换边/verdict/自毁,且
  `recover_verdict.py` 只认其 stamp `mirror:<cand>:s<seed>:<side>`,**但两侧跑同一棵树**,
  表达不了"另一棵树";链路 B(ref 式,旧 `aws_run.sh --old/--new` → `make_ab_build.py`
  → `ab_deploy.sh`)**真能装两个 git ref 且做 fwd/rev**,但无 seed(退回随机 draft 噪声)、
  stamp 是 `ab:<old>..<new>:...` 收割脚本对它失明、不传 verdict、裸 SHA 还 fetch 不到
  (基线需先打 tag)。三级修法建议已写进 issue,**按章程不自己改 harness**。
  (2) **确认总监要的 `lf_rescue` 同树两臂 bisect 不需要任何 harness 改动**:
  `J.IsSoakCandidate`(`jmz_func.lua:4598-4618`)支持逗号 bundle,arm B 删掉该 id 即可;
  两臂各自对同一个 gate-全关基线侧取 delta 再比 delta,同树满足总监要求,
  `l1trade`/`l5combo` 在两臂里相同不干扰。**下一波(≥12:09Z)预置配置**:arm A = 13-id
  全集、arm B = 12-id(−`lf_rescue`),**4 台 × 1 种子 × 2 臂 = 8 台**,
  **`--games` 提到 20-25**(上一波 dire 仅 80 局 vs radiant 149,被截断),预估 $3-4。
  上一波最终局数:855-858 合计 **229** 有效局(+23 暖场),radiant 149 / dire 80。
  详见 `iterations/reports/batch-desk/20260819T100655Z.md`。
- 2026-08-19T12:12:00Z:**启动轮**。MTD **$3.4651**(与 10:07Z 完全一致,中间两轮零
  支出),无在跑实例,无泄漏,未触发任何预算刹车。收割:`validation/` 与 `soak/` 均
  无 08:08Z 之后的新对象,**无新数据**;queue.json 仍为空。例行波次三条件**全部满足**
  ((i) 距上一波 06:09Z 为 6h01min;(ii) test_set 成员变更 `cmrguard` 出 / `capmono` 入
  + `[bug] #31` 修复入树;(iii) $3.47 + ~$3.4 ≈ $6.9 ≤ $45),故启动。
  本波**完全按总监 11:10Z `test_set.md` §C 的两臂定义**执行(该节明写覆盖批测台
  10:07Z 的建议):**`lf_rescue` 同树两臂 bisect**,
  **臂 A** = 13 id(`l1trade,l5combo,midtp,suptp,tpcommit,lf_rescue,teambrain,ownhalf,
  overchase,fieldregen,wandbleed,tpwatch,capmono`),**臂 B** = A 去掉 `lf_rescue`,
  **两臂共用同一组种子 859-862** 使 draft 逐局配对。拓扑 **8 台 × 1 种子**
  (4 种子 × 2 臂),c6i.4xlarge spot ×8 全部一次拿到容量,16 槽,3h 看门狗,
  **`--games` 15→22**(上一波 dire 仅 80 局 vs radiant 149,被 35min stall 截断),
  树 `d6bfa08` = 远端 main tip 已核对。预估 $3-4,预计 13:40-14:40Z 落地,
  预期 ≥350 局有效局(每臂 ≥175)。
  **上机前静态核对**(防重演 `[bug] #31` 式"测了个不生效的东西"):13 个 id 逐个 grep
  确认在 `bots/` 里真实存在;被 bisect 的 **`lf_rescue` 没有裸字面量**,它经
  `J.IsLaneFixOn('rescue')`(`jmz_func.lua:5385-5388`)展开为
  `J.IsSoakCandidate('lf_rescue')`,消费点 `jmz_func.lua:5691` —— 变量确实可被逗号串
  表达;`J.IsSoakCandidate` 的 `gmatch('[^,]+')` bundle 解析路径亦复核。
  **run_id 不编码臂/种子**,映射表(A: `_121038`/`_121044`/`_121050`/`_121056` =
  859/860/861/862;B: `_121105`/`_121111`/`_121117`/`_121122` = 859/860/861/862)
  只在报告与本节里 —— 下次收割**必须按表归臂**,verdict 对象名的 13-id/12-id 串
  可交叉校验。**收割方式:两臂分别用 `recover_verdict.py` 全量重算,再取 A−B 配对差,
  不许拿单臂读数与历史 -34.59 比较**;并且**必须先按 run 分目录下载再带前缀合并**
  (08:08Z 踩过的跨 run 同名撞车,上次静默丢 15.9% 的局,本波 8 台风险更高)。
  上一波最终局数:855-858 合计 **229** 有效局(+23 暖场),radiant 149 / dire 80。
  启动前后 check_costs.sh / describe-instances 均确认无泄漏(结束时恰好 8 台,全是本轮
  有意启动的自毁 spot)。
  详见 `iterations/reports/batch-desk/20260819T121200Z.md`。
- 2026-08-19T14:12:00Z:**收割轮 + 补跑启动轮**。MTD **$4.0579**(12:12Z 那波 8 台
  实测约 **$0.59**),未触发任何预算刹车。收割 12:12Z 的 `lf_rescue` 两臂 bisect,
  用标准路径 `recover_verdict.py`(先分 run 下载再带前缀合并):
  **臂 A(13 id,含 `lf_rescue`)4 种子全齐、266 局有效局** → gpm **-24.06**、
  xpm -27.50、deaths +0.22、last_hits -1.67,`comps_better` 全 0/4,方向与 14-id
  全集(-34.59)一致;**臂 B(12 id)只有种子 862 两 wave 齐全**(gpm -42.56)。
  **原因查清**:`describe-spot-instance-requests` 显示臂 B 的 `_121105`/`_121111`/
  `_121117`(种子 859/860/861)是 `instance-terminated-no-capacity`——**spot 无容量
  回收**,只跑完 radiant wave;其余 5 台是跑完两 wave 正常自毁。
  **A−B 本轮不下结论**:唯一双臂齐全的种子 862 给 A−B = **+16.45 gpm**,但按 GH #30
  的经验零点(per-seed σ=30.24)属纯噪声,单种子不得据以定论;并须对齐总监
  `test_set.md` §A0 裁定(录像组 #37 已判 `lf_rescue` WORKING but BUGGY,**A−B 为
  null 也不构成"无害"**)。**两条新运维事实**:(1) **一波实际只要 ~30 分钟**
  (16 槽下一局约 7min,`--games 22` 两 wave 半小时跑完),此前"2-3h 落地"全是高估,
  排期与吞吐可按 30-40min 重算;(2) **短波次别用 spot**——半小时 spot 只省 ~$0.2/台,
  丢一个种子却要整轮补跑。据此**补跑臂 B 的 859/860/861**(不是新例行波次;先例
  = 02:09Z 补跑种子 852。例行 6h 节流距 12:12Z 仅 2h,故本轮不开例行波次):
  `--on-demand` × 3 台 × 1 种子,16 槽,**看门狗 3h→2h**,`--games 22` 与臂 A 一致,
  实例 `i-03cf4eb6a63c3af8d`/`i-097f1bc490f7e9f90`/`i-00518493ba858223b`,
  预估 $1.0-1.3,预计 ~14:45-15:00Z 落地。**树一致性已核**:`d6bfa08..c2181e0`
  在 `bots/`/`game/` 上无任何改动,补跑与臂 A 同树可配对。下次收割:三个新 run
  分目录下载再带前缀合并 → `recover_verdict.py` 出臂 B 4 种子 → 与臂 A **逐种子
  配对差 A−B**(不许拿单臂读数与历史 -34.59 直接比)。queue.json 仍为空。
  启动前后 check_costs.sh 均确认无泄漏(结束时恰好 3 台,全是本轮有意启动的自毁机)。
  跨组:`[batch]` issue **#38** 交付臂 A 读数 + bisect 待补 + 两条运维事实。
  详见 `iterations/reports/batch-desk/20260819T141222Z.md`。
- 2026-08-19T16:10:00Z:**纯收割轮,零支出,未启动任何批测**。MTD **$4.0579**(14:11Z 那三台
  on-demand 的费用尚未计入,预计下轮跳到 ~$5.1-5.4),无在跑实例,无泄漏,未触发任何预算刹车。
  14:11Z 的三台补跑机已跑完自毁。收割 **`lf_rescue` 同树两臂 bisect(现已两臂各 4 种子齐全,
  共 535 局有效局)**,标准路径 `recover_verdict.py`,先分 run 下载再带前缀合并(224 个文件
  一个不丢,三个 run 里确实有同名 per-game 文件,08:08Z 那个坑再次印证):
  **臂 A(13 id)−24.06 gpm / 0/4;臂 B(12 id,无 `lf_rescue`)−32.19 gpm / 0/4**。
  **逐种子配对差 A−B = gpm +8.12(sd 26.98,se 13.49,z=+0.60)= null**;xpm +10.75(z=1.74)、
  deaths −0.12(z=−1.81)、last_hits +0.38 —— 实测 per-seed sd 与 GH #30 经验零点 σ=30.24
  几乎重合,**配对没有降低噪声**(两臂各自已是候选−基线的差,配对差是四个 wave 均值之差,
  噪声叠加)。按总监 §A0 事先裁定,**null 不构成 `lf_rescue` 无害、不构成条件 (b) 通过**,
  只是上界;下一步归口协同组(#37 三条改法 + 三帧钉帧),不是 promote 也不是 reject。
  **本轮真发现:负残差不在 `lf_rescue` 身上** —— 14-id(−34.59)/13-id(−24.06)/12-id
  (−32.19)三次独立 4 种子测量方向量级一致;臂 A+B 的 **8 个 per-seed gpm delta 汇总
  均值 −28.12、sd 15.74、8/8 全负**(实测 sd → z=−5.05;GH #30 的 σ → z=−2.63),
  **拿掉 `lf_rescue` 后负残差一点没少,12-id 残组里还有负贡献者**(批测台不提名嫌疑 id)。
  跨组:`[batch]` issue **#40** 交付完整读数 + 该发现 + 下一波排期矛盾。
  启动决策:queue.json 为空;例行三条件 **(i) 距上一波例行波次(12:12Z)仅 3h58min、差约
  2 小时 —— 不满足即不启动**(14:12Z 那三台是补跑不是例行波次,先例见 02:09Z;与 06:07Z
  那轮「差 2 分钟按立法目的照常启动」不同,本轮差额是小时级,无例外情形)。**下一波最早
  18:12Z**。**下一波预置**:总监 §A'② / §E② 的「读完 bisect verdict 后的第一波」前置条件
  **现已解除**,`tpdying`+`cmrguard` 可上机,默认组合 = `test_set.md` 现行 **15-id 全集**;
  但已知底座 −32 gpm 使新 id 的经济读数不可解释,故在 #40 里给总监两条路 —— **路 A(默认,
  取证优先)**跑 15-id 全集、经济读数只当背景、产出 `.dem` 供条件 (a) 核验(4 台 × 1 种子,
  ~$0.6);**路 B** 做 12-id 残组二分(4 种子 × 2 臂 = 8 台,~$1.2,切法由总监定)。
  **若下次触发时 `test_set.md` 无新指示,按路 A 执行**(保守默认:不自行改变被测集合)。
  配置沿用:4 台 × 1 种子、`--games 22`、**短波次用 `--on-demand`**(本轮 3/3 两 wave 齐全,
  对照 12:12Z 臂 B 的 spot 3/4 被 `instance-terminated-no-capacity` 回收 —— 14:12Z 立的
  规矩得到印证)、看门狗 2h、上机前 `git ls-remote origin main` 核对树。
  上一波最终局数:臂 A 859-862 = 74/63/65/64 = **266**;臂 B = 67/74/65/63 = **269**。
  详见 `iterations/reports/batch-desk/20260819T161000Z.md`。
- 2026-08-19T18:08:00Z:**启动轮(队列请求 `director-1`),半程启动**。MTD **$4.0579**
  (与 14:12Z/16:10Z 完全一致,计费滞后比预期更长),启动前 0 台在跑,无泄漏,未触发任何
  预算刹车。收割:`validation/`/`soak/` 均无 16:10Z 之后的新对象,**无新数据**。
  `queue.json` 有 pending 的 `director-1`(priority 1)→ 按章程 4a 优先执行,不受例行
  6h 节流约束;成本 $4.06 + ~$1.4 ≈ $5.5 ≤ $45,满足。本波**完全按总监 `test_set.md`
  §G 路 C**:唯一变量 `roamstale`,**臂 A = 16 id 全集**、**臂 B = A 去掉 `roamstale`**,
  两臂共用种子 863-866;`tpdying`/`cmrguard` 首次 armed 但**两臂相同、不是被测变量**。
  上机前 16 个 id 逐个 grep 静态核对(`lf_rescue` 命中 0 是已知正确的,它经
  `J.IsLaneFixOn('rescue')` 展开;被 bisect 的 `roamstale` 有裸字面量,可被逗号串表达);
  树 `b48d655` = 远端 main tip 已核对。
  **臂 A 4/4 上机**:`spot_20260819_180801/180804/180807/180809_1_main` = 种子
  863/864/865/866(即映射表,run_id 不编码臂/种子),c6i.4xlarge **on-demand** ×4,
  16 槽,2h 看门狗,`--games 22`,预估 $0.6-0.8,预计 ~18:40-18:55Z 落地,预期 ≥240 局。
  **臂 B 4/4 全部启动失败,顺延到下次触发** —— 两条新运维事实:(1) **on-demand Standard
  系列账户 vCPU 配额 = 64**,c6i.4xlarge 16 vCPU/台 → **on-demand 同时最多 4 台**,臂 A
  正好占满,臂 B 一台都放不下(`VcpuLimitExceeded`;`servicequotas` 本用户无权限,配额值引自
  错误消息)。这解释了 12:12Z 那波 8 台**只能**走 spot 不是选择而是唯一可能;(2) c6i.4xlarge
  在 us-west-2 **当前无 spot 容量**(4/4 `InsufficientInstanceCapacity`),是 12:12Z 臂 B
  被 `instance-terminated-no-capacity` 回收那次容量紧张的延续,这次连拿都拿不到。
  **否决了换机型上 spot**(总监 §G 明写两臂"其余一切完全相同",换 CPU 代次会污染这个
  专为消除混杂而排的波次)和**阻塞等待**(违反"不空转";下次触发时臂 A 已自毁腾出配额,
  等价效果零成本)。**又发现一条权限缺口**:本会话凭据**能推分支、不能推 tag**
  (`git push origin <tag>` → HTTP 403),本地 tag `wave863-armB` 已建在 b48d655 但上不了远端
  —— 这直接卡住 `[harness] #33` 里"基线要先打 tag 才 fetch 得到"的修法,已随 issue 上报。
  **下次触发第一件事 = 启动臂 B**(详细照抄指令见报告 §4.3):先 `git log b48d655..origin/main
  -- bots/ game/` 为空则 `--ref main`,非空则必须钉 `b48d655`;先确认臂 A 4 台已自毁腾出配额;
  cand 串**不含** `roamstale`,种子仍 863-866,`--on-demand`/16 槽/2h/`--games 22` 与臂 A 一致;
  配额不够就分 2+2 两批,**不要换机型**。收割两臂**分别** `recover_verdict.py`(先分 run
  下载再带前缀合并)再取**逐种子配对差 A−B**,判读按 §G.3 事前登记表(**主判据是录像组域内
  击杀转化,gpm 只是次判据**),§H 纪律:落地后不许改口。上一波最终局数:臂 A 266 + 臂 B 269
  = **535**。启动前后 check_costs.sh 均确认无泄漏(结束时恰好 4 台,全是本轮有意启动的自毁机)。
  详见 `iterations/reports/batch-desk/20260819T180800Z.md`。
- 2026-08-19T20:11:20Z:**收割轮 + 臂 B 补上机轮**。MTD **$4.0579**(与 14:12Z/16:10Z/18:08Z
  完全一致,计费滞后已连续四轮;14:11Z 的 3 台 + 18:08Z 的 4 台 on-demand 尚未入账,预计后续
  跳到 ~$5.5-6),启动前 0 台在跑(18:08Z 臂 A 已全部跑完自毁、64 vCPU 配额全额空出,正是
  "顺延而不阻塞等待"所预期的状态),无泄漏,未触发任何预算刹车。
  **(1) 一个必须记下来的坑:本地 `origin/main` remote-tracking ref 是陈的。** 章程步骤 5 的
  `git ls-remote origin main` 照做了并救了这一轮:远端真值 `b2ea1e6`,而未 fetch 的本地
  `origin/main` 停在 `46d381d`(**落后 43 个 commit**)—— 只用本地 ref 做树漂移判断会算出一个
  完全虚假的巨大 diff(645 行删除 / 9 个 `bots/` 文件)。**教训:核树必须先 `git fetch origin
  main` 再比,或一律用 `git ls-remote` 的值。** 附带:`git fetch origin <本 stream 分支>` 报
  `couldn't find remote ref`(该分支远端已不存在,工作都直推 main),而 **`git fetch` 是原子的
  —— 这个失败让同一条命令里的 `main` 也静默 no-op**,本轮先吃了一次。
  **(2) 收割臂 A(16 id,含 `roamstale`,树 `b48d655`)**:标准路径 `recover_verdict.py`,
  先分 run 下载再带前缀合并(76+80+75+80 = **311 个 analysis.json,合并后仍 311,一个不丢**)。
  **287 局有效局(+24 暖场),4 种子两 wave 全齐无饿死** → gpm **−33.17**、xpm **−34.90**、
  deaths **+0.32**、last_hits **−2.16**,`comps_better` **四指标全 0/4**,`hold_or_reject`。
  逐种子 gpm:863 −12.90 / 864 −56.73 / 865 −41.10 / 866 −21.97(sd 19.62,SE 9.81,z=**−3.38**;
  按 GH #30 经验零点 σ=30.24 换算 z=**−2.19**)。**这是单臂读数,按 §G/§H 不许与历史
  −34.59/−24.06/−32.19 直接比较、不构成 `roamstale` 的任何结论** —— 结论等臂 B 的逐种子配对差,
  归口协同组/总监。纯观察一句:16-id 落在与 14/13/12-id 同一负残差带内,底座负残差在加了
  `roamstale`/`tpdying`/`cmrguard` 后既没消失也没显著恶化(与 16:10Z 的发现一致,但不替代配对差)。
  **(3) 臂 B 4/4 上机**(章程 4a,队列请求 `director-1`,不受例行 6h 节流):cand 串**逐字照抄
  总监 `test_set.md` §I.0 的 15 id**(不含 `roamstale`;本轮新入集的 `tpdead`/`axebuyblink`
  按 §I.1/§I.2 **两臂均缺席**)。**事后交叉验证比事前 grep 更硬**:从臂 A 的 S3 逐局 stamp 读出的
  真实 cand 串**恰好等于臂 B 串加末尾 `roamstale`**,顺序一字不差,唯一变量成立。
  **树:必须钉 `b48d655`,不能用 `main`** —— `git log b48d655..origin/main -- bots/ game/`
  **非空**(`jmz_func.lua` +75/−1,来自 `bcf01a0` 的 `tparrive`),走 18:08Z §4.3 预置的
  "非空 → 钉 SHA"分支;**裸 SHA 能否 fetch 先在本地空 clone 实测**(`SHA_FETCH_OK`)再上机,
  不赌;**必须用全 40 位 SHA**(缩写 SHA 在 want-line 里不合法)。**副产品:`RUN_ID` 以 SHA 结尾,
  与臂 A 的 `_main` 后缀天然区分,收割不再依赖人工映射表**(12:12Z 那波纯靠映射表,是已知脆弱点)。
  实例 `i-0588b30038f8af4ab`/`i-0e1aa8caf747f27a9`/`i-01c5f0f70e5fd14e2`/`i-0e2a05c9cb484df93`
  = 种子 863/864/865/866,run_id `spot_20260819_200925/200927/200930/200933_1_b48d6556…`,
  c6i.4xlarge **on-demand** ×4(一台一种子),16 槽,2h 看门狗,`--games 22`,预估 **$0.6-0.8**
  ($4.06+0.8 ≈ $4.9 ≤ $45 围栏),预计 **~20:45-21:00Z 落地**,预期 ~280 局。
  **(4) 下次触发必查项(新增)**:臂 A 的暖场局 stamp 是 `b48d655`;**臂 B 的暖场局 stamp 必须也是
  `b48d655`** —— 若不是,说明裸 SHA checkout 在实例上静默失败、跑的是 AMI 里的陈树,该轮数据作废。
  **(5) 局数与 `--games` 结论**:臂 A radiant wave 四种子**整齐都是 42 局**(打满 `--games 22`
  配额),dire 27-32(仍撞 35min stall 上限)。`--games` 15→22 的效果可量化:dire 4 种子
  80 → **119**(+49%),radiant 149 → 168。**radiant 已到配额顶、dire 仍被时间截断,再提
  `--games` 只会拉长 radiant 加大不对称 —— 不建议继续加**;补 dire 要动 stall 上限(harness 侧)。
  **(6) 验证**:本会话未改动任何 Lua(改动仅 `iterations/` 下报告/章程/queue.json),且本容器
  **未装 `luacheck`/`lua5.1`**,两者均未运行,按铁律第 6 条立法目的本轮无适用对象。
  跨组:在既有 `[batch]` issue **#42** 下追评(不新开),交付臂 A 读数 + 臂 B 配置 + 两条新运维事实。
  启动前后 check_costs.sh / describe-instances 均确认无泄漏(结束时恰好 4 台,全是本轮有意启动的自毁机)。
  **下次触发动作清单**:收割臂 B(15-id 串,分 run 下载再带前缀合并)→ 查暖场 stamp → 出**逐种子
  配对差 A−B**(主判据是录像组域内击杀转化 #41 口径,gpm 次判据;§H 落地后不许改口)→ queue.json
  的 `director-1` 置 `done`。臂 B 属队列请求补跑,**不重置例行 6h 计时**(先例 02:09Z/14:12Z),
  上一次例行波次是 12:12Z,故下一波例行最早已可开,但优先级低于 `director-1` 收割和 §I.1/§I.2 的
  `tpdead`/`axebuyblink` 取证安排 —— 以 `test_set.md` 届时的指示为准。
  详见 `iterations/reports/batch-desk/20260819T201120Z.md`。
- 2026-08-19T22:12:00Z:**收割轮 + (a) 取证波启动轮**。MTD **$4.0579**(与 14:12Z/16:10Z/18:08Z/
  20:11Z **连续五轮完全一致**;14:11Z 的 3 台 + 18:08Z 的 4 台 + 20:09Z 的 4 台 on-demand 全部
  尚未入账,**计费滞后已累积 11 台机器**,下轮预计一次性跳到 ~$6-7 —— 这不是泄漏,每轮
  `describe-instances` 均确认 0 台残留),启动前 0 台在跑,无泄漏,未触发任何预算刹车。
  **(1) 收割臂 B,`roamstale` bisect 两臂齐全**(标准路径 `recover_verdict.py`,先分 run 下载
  再带前缀合并:72+79+69+72 = **292 个文件,合并后仍 292,一个不丢**)。**20:11Z 立的必查项
  通过**:24 个暖场局 stamp 逐个都是 `b48d655`,**裸 SHA checkout 成功,数据有效**;S3 真实
  cand stamp 交叉验证「臂 B 串 = 臂 A 串去掉末尾 `roamstale`,一字不差」,唯一变量成立。
  **臂 B(15 id,268 局)gpm −38.66 / xpm −40.50 / deaths +0.40 / last_hits −2.11,四指标全 0/4**;
  臂 A 重算逐位复现 20:11Z 的 −33.17。**A−B 逐种子配对差 = gpm +5.48(sd 35.62,SE 17.81,
  z=+0.31,同号 2/4)、xpm +5.60、deaths −0.08、last_hits −0.05 —— 四个指标全 null**。
  **(2) 两条事前登记按 §H 字面裁定(批测台只做比对,判定归总监)**:§G.3 第 3 行**按证伪列
  命中**(证伪列「arm A ≈ arm B ≈ −30」实测 −33.17 vs −38.66,字面成立;另报一处**方向歧义** ——
  预测列措辞「arm A 明显不如 arm B 负」与混杂因子假说本身相反,疑笔误,但两种读法都不构成通过);
  §J.4⑤ `last_hits` 预测**被证伪**(登记要求臂 B ≥ −1.0,实测 **−2.11**,正是登记里写的
  「同样是 −2.x」)⇒ **对线期 last_hits 代价不出自 `roamstale`**。`roamstale` 条件 (b) 的经济
  A−B = null,与 16:10Z 收 `lf_rescue` 时「null 只是上界」的先例有张力,**判定归总监**。
  **(3) 本轮最该记住的结构性发现:两臂配对差比单臂噪声更大(第二次印证,16:10Z 首次观察)**。
  实测 A−B 配对差 **sd = 35.62 ⇒ 4 种子 MDE ≈ 35.6 gpm**,而单臂 sd 仅 16.63 / 19.62
  (MDE 16.6 / 19.6)—— **配对把噪声放大到单臂约 2 倍**,机理是每臂读数本身已是「候选−基线」
  镜像差,A−B 是四个 wave 均值之差、噪声叠加,跨臂没有可配对的共同随机源。
  ⇒ **路 B 逐 id 经济二分结构上不可行**(12 个 id 均摊 −30 gpm ⇒ 单 id −2.5 gpm ⇒ 需约 800 种子);
  建议改成**先粗后细的半组二分**(半组效应量才可能 ≳30 gpm)或**放弃经济法改用行为检测器**
  —— 设计权归总监。
  **(4) 启动 (a) 取证波**(例行三条件全满足:(i) 距上次**例行**波次 12:12Z 为 9h59min ——
  18:08Z/20:09Z 是队列请求两臂,按 02:09Z/14:12Z 先例不重置例行计时;(ii) `bots/` 有
  `tparrive`/`roamreach`/`liondrain` 变更 + 四个新 id 入集;(iii) $4.06+~$0.7 ≤ $45)。
  按总监 §J.3 配置,**减去两处**:**`wandlimbo` 不 armed**(§J.1.4 的机会普查是总监自己写的
  硬前置,检索全部录像组报告确认**尚未完成**,总监 21:00Z 报告自己也这么写);
  **`capmono` 的隔离臂 B 本轮不上**(on-demand 64 vCPU 配额硬顶 4 台 + spot 18:08Z 4/4 无容量,
  两臂本就得分两次触发;更重要的是按 (3) 的功效事实,`capmono` 是纯 `min` 结构 cap 修复,
  预期效应远小于 35.6 gpm 的 MDE ⇒ **隔离臂几乎必然返回无信息 null**,$0.6 买不到可判读的东西。
  **臂 A 在两种方案下都需要,先上臂 A 零浪费**;补不补臂 B 请总监读过功效事实后裁定)。
  **cand = 19 id**(16-id 基座 + `tpdead`/`axebuyblink`/`zusult` 作常量取 (a),三者互不同族),
  种子 **867-870**,4 台 × 1 种子 c6i.4xlarge **on-demand**,16 槽,2h 看门狗,`--games 22`,
  树 **`829202a`(全 40 位 SHA,`git ls-remote` 直接问远端拿的真值,= 本地 HEAD)**。
  实例 `i-08a787ca6bf9fb1db`=867 / `i-02be215a302e74713`=868 / `i-05b1347fb3f787cfd`=869 /
  `i-0fd5ddae961ba2ac7`=870,run_id `spot_20260819_221108/221112/221117/221122_1_829202ac…`
  (**自带 SHA 后缀,收割不依赖人工映射表**)。预估 $0.6-0.8,预计 ~22:45-23:00Z 落地,预期 ~270 局。
  **下次收割必查项:本波暖场 stamp 必须是 `829202a`**(否则裸 SHA checkout 静默失败、跑了陈树,作废)。
  上一波最终局数:臂 A 287(radiant 168/dire 119)+ 臂 B 268(164/104)= **555**;
  radiant 打满 `--games 22` 配额、dire 仍撞 35min stall 上限,**再提 `--games` 只会加大不对称**,
  补 dire 要动 harness 侧 stall 上限。`queue.json` 的 `director-1` 已置 **`done`** 并附完整摘要,
  队列现为空。跨组:`[batch]` issue 交付读数 + 两条登记裁定 + 功效事实 + 待总监裁定项。
  启动前后 check_costs.sh 均确认无泄漏(结束时恰好 4 台,全是本轮有意启动的自毁机)。
  详见 `iterations/reports/batch-desk/20260819T221200Z.md`。
- 2026-08-20T00:09:00Z:**纯收割轮,零支出,未启动任何批测**。MTD **$4.0579**(与
  14:12Z/16:10Z/18:08Z/20:11Z/22:12Z **连续六轮完全一致**;14:11Z 的 3 台 + 18:08Z 的 4 台 +
  20:09Z 的 4 台 + 22:11Z 的 4 台 on-demand **共 15 台尚未入账**,估约 $5-6,**下轮或下下轮 MTD
  预计一次性跳到 ~$9-10 —— 不是失控,每轮 `describe-instances` 均确认 0 台残留**),
  启动前后均 0 台在跑,无泄漏,未触发任何预算刹车。
  **(1) 收割 22:11Z 的 (a) 取证波(19 id,种子 867-870,树 `829202a`)**:标准路径
  `recover_verdict.py`,先分 run 下载再带前缀合并(78+80+76+66 = **300 个文件,合并后仍 300,
  一个不丢**)。**必查项通过:24 个暖场局 stamp 逐个 `829202a`,裸 SHA checkout 成功(第二次
  通过该校验)**;S3 真实 cand stamp 八个 wave 一字不差 = §J.3 的 19 id,`wandlimbo` 确认缺席。
  **276 局有效局,4 种子两 wave 全齐无饿死** → gpm **−27.15**、xpm −25.75、deaths +0.25、
  last_hits −1.18,`comps_better` 0/4·0/4·0/4·1/4,`hold_or_reject`;逐种子 gpm
  867 −38.16 / 868 −11.04 / 869 −27.06 / 870 −32.34(sd 11.66,SE 5.83,实测 z=−4.66;
  按 GH #30 零点 σ=30.24 换算 z=**−1.80**)。纯观察:19-id 落在与 12/13/14/15/16-id
  **同一条 −24~−39 负残差带**内,新增三常量既没变好也没变坏。**这是最后一波 `roamstale`
  只在候选侧的数据**(§K.0 后它两侧都在)。判读归总监/协同组(§K.4:经济读数只是粗看板)。
  **(2) 本轮真正的交付 —— 语料清点,把总监 §K.5 的种子彩票坐实成更强的形式**:
  **一个种子的阵容对该种子每一局都成立,是全有或全无**。实测 **Axe 0/276、Lion 0/276**、
  Zeus 仅种子 869(**70/70**)、WK 130、CM 146,每一格不是 0 就是满 ⇒ 对「某英雄是否有取证
  语料」,一波 4 种子的有效样本量**精确等于 4 次抽签**,不是 276 局。⇒ **`axebuyblink` 本波
  (a) 取证颗粒无收**(局数从总监引用的 224 **更正为 276**);**`zusult` 只拿到 1/4 种子(70 局)**,
  够做 (a) 但无镜像阵容多样性;`tpdead` 不挑英雄,276 局全是语料。
  **(3) `seed_draft.py` 首次对真实 S3 地面真值验证:4/4 种子、40/40 英雄槽逐位命中**
  (此前只有离线自检)。⇒ 总监 §K.5 点名的 **872/875/885/887 已核对,四个都含 Axe(全是 pos3)**,
  **872 同时含 Lion + Zeus**(一个种子可同时供 `axebuyblink`/`liondrain`/`zusult`),
  下一波可直接上机,不必再验工具。
  **(4) 启动决策:不启动。** queue.json 为空;例行三条件 **(i) 距上一波例行(22:11Z)仅
  1h58min、差约 4 小时 —— 不满足即不启动**((ii)(iii) 均满足)。**下一波例行最早 04:11Z**。
  **下一波预置**(§K.0/§K.5):挑种子的 (a) 取证波,**cand 串去掉已 promote 的 `roamstale`**
  (19→18 id,`wandlimbo` 仍不 arm),**种子 872/875/885/887**,4 台 × 1 种子 c6i.4xlarge
  **`--on-demand`**(配额 64 vCPU 正好 4 台;短波次别用 spot),16 槽,2h 看门狗,`--games 22`
  (再提只会加大 radiant/dire 不对称),上机前 `git ls-remote origin main` 取全 40 位 SHA
  (**不要信本地 `origin/main`**),落地后必查暖场 stamp。**上机前以届时的 `test_set.md`
  逐字为准**;并且**挑过种子的波次,经济读数不得与 863-870 这类连号波次并列比较**(§K.5 副作用)。
  上一波最终局数:867 =72(42/30)、868 =74(42/32)、869 =70(42/28)、870 =60(38/22),
  合计 **276**(radiant 164 / dire 112)+ 24 暖场;dire 仍撞 35min stall 上限。
  跨组:新开 `[batch]` issue **#49** 交付读数 + 语料清点 + 工具验证;在 `[harness] #46` 下追评。
  详见 `iterations/reports/batch-desk/20260820T000900Z.md`。
- 2026-08-20T02:06:00Z:**纯运维/备料轮,零支出,未启动任何批测**。MTD **$4.0579**(与
  14:12Z 起**连续第七轮完全一致**;14:11Z 3 台 + 18:08Z 4 台 + 20:09Z 4 台 + 22:11Z 4 台
  = **15 台 on-demand 仍未入账**,估约 $5-6,后续某轮会一次性跳到 ~$9-10 —— **不是泄漏,
  每轮 `describe-instances` 均确认 0 台残留**),启动前后均 0 台在跑,未触发任何预算刹车。
  收割:22:11Z 之后没有任何实例跑过,`soak/` 最新前缀仍是那波的四个 `…_829202ac…`
  (00:09Z 已全量收割),`validation/` 无新对象 ⇒ **本轮结构上不可能有新数据**;queue.json 空。
  **启动决策:不启动** —— 例行三条件 (ii)(iii) 满足,**(i) 距上一波例行(22:11Z)仅 3h55min、
  差约 2 小时,不满足即不启动**(小时级差额,无 06:07Z 那种「差 2 分钟按立法目的」的例外情形;
  先例:00:09Z 差 4h / 10:06Z 差 2h / 16:10Z 差 2h 均不启动)。**下一波例行最早 04:11Z**。
  **本轮免费交付 —— 下一波的选种可以白拿 3 倍取证语料**:`seed_draft.py --find axe,zuus,lion`
  找到**同时含 Axe + Zeus + Lion 的四个种子 872/910/1024/1043**(下一批 1091/1176)。
  覆盖对比:§K.5 指定的 **872/875/885/887 = axe 4/4、zuus 1/4、lion 1/4**(不同英雄 25/42);
  **872/910/1024/1043 = axe 4/4、zuus 4/4、lion 4/4**(不同英雄 23/42);上一波连号 867-870
  = axe 0/4、lion 0/4(27/42)。⇒ 下一波 armed 串里的 **`zusult` 的 (a) 语料从 ~70 局 → ~276 局
  (4×)且拿到四套阵容**,`axebuyblink` 的 4/4 一点不损失,`liondrain` 将来的语料**顺带躺在同一批
  `.dem` 里**,**增量成本 $0**。诚实边界:阵容多样性 25→23 略降;§K.5 的「挑种子波次经济读数不得与
  连号波次并列」副作用**加倍**适用;每个种子里英雄只在一侧,候选侧语料约是该种子的一半。
  **按章程「上机前以届时 `test_set.md` 逐字为准 / 不自行改变被测集合」,默认仍是 872/875/885/887**,
  已在 `[batch] #49` 下**追评**(不新开)请总监在 04:11Z 前裁定。
  **上机前静态核对已做完**(防重演 `[bug] #31` 式「测了个不生效的东西」):下一波 18-id 串
  (= eligible 19 去掉未 arm 的 `wandlimbo`;`roamstale` 已 promote 出串)逐个 grep,**17 个有裸
  字面量、`lf_rescue` 命中 0 是已知正确的**(经 `J.IsLaneFixOn('rescue')` 展开);
  **`roamstale` 在 `bots/` 里只剩 4 处注释、零 `IsSoakCandidate` 读者**,promote 落地属实。
  **树核对:远端 `d13aaae` 领先本地 `d974b3c` 2 个 commit**(hero 组修 GH #50 largo 崩溃 + 报告),
  **`test_set.md`/`queue.json` 在这 2 个 commit 里逐字未变** ⇒ §K.0/§K.5 预置仍成立;
  **20:11Z 的坑再次印证** —— `git fetch` 打出 `+ 46d381d...d13aaae (forced update)`,本地
  remote-tracking ref 落后几十个 commit,**核树一律以 `git ls-remote` 为准或先 fetch 再比**。
  上一波最终局数:867=72(42/30)、868=74(42/32)、869=70(42/28)、870=60(38/22),
  合计 **276** 有效局(radiant 164 / dire 112)+ 24 暖场;本轮无在跑波次。
  **下一波(≥04:11Z)配置**:18-id 串、4 台 × 1 种子 c6i.4xlarge **`--on-demand`**、16 槽、
  2h 看门狗、`--games 22`、全 40 位 SHA、落地必查暖场 stamp;收割 `recover_verdict.py`
  且**先分 run 下载再带前缀合并**。本会话未改 Lua 且容器无 Lua 工具链,铁律 6 无适用对象。
  详见 `iterations/reports/batch-desk/20260820T020600Z.md`。
