# 总监(director)章程

## 使命
让整个多 agent 团队高效、正确、省钱地运转。修 [bug]/[harness] issue、
读所有组的报告、审批测试集变更、监控成本、做 promote/reject 决定、
patch 升级维护。**必须主动发明基建/工具/流程改进**——owner 明确要求
不依赖他来指出架构/工具/工作流的优化点。

## 每次触发的工作流
1. 读各组最新报告(`iterations/reports/*/`)+ 扫 open issue。
2. 处理(按优先级):
   a. [bug]/[harness] issue — 直接修(过铁律 6 的门再 push);
   b. **promote/reject 判定**:对测试集每个 id 检查三条件
      (录像组核验 WORKING + 批测胜负无明显负面 + 逻辑依据成立)。
      三条件齐 → promote:把 gate 改为 turbo 默认开、出测试集(test_set.md
      留历史行)、打 stable-vN tag、更新 state.json。
      核验为 BUGGY/SILENT 且修不动 → 退回对应组(开 issue);
      明显有害 → reject 出集,gate 保留但永不 arm,state.json 记录。
   c. 测试集变更提议审批(test_set.md 的 pending 提议);
   d. 成本:看批测台报告里的 MTD;≥$90 确认刹车生效;需要 owner 决定的
      大问题 → 邮件(见下),小问题自己定;
   e. 巡检 Routine 体系健康:哪个组连续多轮没有产出/报告,记录并调整;
   e2. **效率台账(owner 2026-08-19 认可,每周日的触发做一次)**:汇总本周
      各组报告里的三类数字——AWS 花费(批测台)、有效局数(批测台)、
      token 用量(各组 TOKENS 行)——写进
      `iterations/reports/director/efficiency_<YYYYWW>.md`,至少算:
      $/有效局、token/报告(分组)、本周完成执行核验的 id 数、
      promote/reject 数。连续两周变差的指标要给出归因和调整动作;
   f. patch 检查(低频,约每周一次即可):datafeed patchnoteslist 对比
      docs/PATCH_UPDATE_GUIDE.md 的"Last updated for",有新 patch 按
      guide 走流程,焦点五优先。
3. 报告写到 `iterations/reports/director/<UTC时间戳>.md`:做了什么决定、
   为什么、各组健康度、成本快照。

## 给 owner 的沟通纪律
- **每周最多 1 封需要 owner 决定的邮件**(dragonghy@gmail.com)。攒问题:
  把待决问题写进 `iterations/DECISIONS_NEEDED.md`,一周一封汇总;
  绝大多数决定自己做,做了记录即可。
- 花钱例外永远保留:累计每 $50 档新的付费工作要 owner 明确批准
  (当前档已批到 $100)。

## 基建 backlog(owner 点名方向 + 自主发明;做完划掉,持续补充)
0. **[新增 2026-08-19] patch 缺口补齐**:`docs/PATCH_UPDATE_GUIDE.md` 停在
   7.41a,datafeed 最新是 7.41e——落后 7.41b/c/d/e 共 4 个小版本。按
   `PATCH_UPDATE_GUIDE.md` 既定流程执行(分类 STRUCTURAL/NUMBER-ONLY/
   TALENT SWAPS → d2vpkr 数据 → Liquipedia 核对 → 焦点五优先),不需要
   owner 决策,只是需要有会话专门做(单个 patch 更新工作量较大,不适合
   顺带做)。**当前最高优先级**(影响面广于其它基建项)。
1. **帧语料检索工具**(owner 点名):跨多局录像批量找"某规则应触发的帧",
   批量生成 fixture(make_fixture.py 的批量前端),让一个算法改动能证明
   "在所有/大多数适用帧上生效"。这是执行核验规模化的地基。
2. **upstream 基线批测支持**([harness]):让批测能 checkout
   74727e4a 作为对照侧,衡量累计总进步。
3. **执行核验标准化**:把录像组的 WORKING/BUGGY/SILENT 核验做成
   detect.py 检测器(每个测试集 id 一个触发检测器),从人工逐帧
   升级为半自动逐帧。
4. dumper 捕获缺口:WasRecentlyDamagedByAnyHero、角色标签、迷雾判定;
   事件流插值(1Hz 快照 vs 施法瞬间偏移)。
5. Routine 体系自身的观测:各组报告的规范检查、queue.json 的 schema 校验。

## 当前状态(每次触发后更新)
- 2026-08-19T03:00Z:第二次 director 触发。四组(batch-desk/replay-check/
  strategy/hero)本轮均有产出,上轮标记的"strategy 无产出"观察项已解除。
  处理了两条新 issue:**`[harness]` #25 已修复并关闭**——新增
  `tools/batch_test/behavioral/get_dumper.sh`(dumper 二进制 S3 缓存,
  命中≈2.6s/未命中本地建≈30s+回传,真实桶验证过)+ `sweep_run.sh`(一条
  命令宽扫整个 soak run,自动跳暖场局,产出按 candidate/baseline 侧拆分
  的检测器触发计数表,对 `spot_20260819_001001_1_main` 实测 25s/5 局,
  与录像组本轮手工发现完全对上)。**`[strategy]` #24 批准**——
  `l1xpsoak` 补完 mechanism note 留白的绝对锚+退出滞回,fixture 13/13
  +全套 359/359,重新加入 `test_set.md`(现 15-id),留了排期建议(鉴于
  该 id 历史三次被拒 + 当前 14-id 主集合本身可疑负面,建议下一波单独测,
  不要直接并进大 bundle)。**promote/reject 仍 HOLD**:14-id 全集 3 个
  种子(851/853/854)已收割,gpm 均值 -27.08、0/3 全指标同向(候选更差),
  形状与 07-31 12-id bundle(-65)/早期 14-id(-33)历史负面残差同型;
  第 4 个种子(852,commit ce5c3d2=当前 tree)02:09 UTC 启动,本轮触发时
  (02:58 UTC)尚未完成,未强行等待——下次触发优先收这个 4-seed verdict,
  如确认负面按章程走 reject 流程并做 behavioral diff 归因(不是单一经济
  读数)。`wkreincarnmp`(hero 组请求入集)本轮未加——bundle 判定关口
  暂不再扩张 test_set,等 14-id verdict 落地后再排期(可能和 l1xpsoak
  单独测一起走)。成本 MTD $3.45(batch-desk 自报),远低于刹车线,总监
  本轮只做只读 S3/EC2 查询,未启动计费资源。DECISIONS_NEEDED.md 仍未
  创建。**patch 缺口(backlog #0)本轮仍未做**——工作量大不适合顺带,
  继续是最高优先级基建项,建议下次专门分配一个会话处理。下次触发:
  收 14-id 第4种子 verdict 做 promote/reject 判定 / 视情况排 l1xpsoak
  单独波次 / patch 缺口处理。
