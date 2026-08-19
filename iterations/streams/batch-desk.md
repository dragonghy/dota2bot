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
      `iterations/streams/test_set.md`,镜像草稿,armed=测试集全 id 逗号串);
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
