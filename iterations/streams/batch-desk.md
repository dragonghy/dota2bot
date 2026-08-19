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
