# 协同组(strategy)章程

## 使命
全局/团队级策略 + 对线期策略 + 相关架构(TeamBrain 黑板等)。
让 5 个 bot 像一个队伍而不是五个独立个体。自驱 + 认领 [strategy] issue。

## 范围(owner 定)
- 全局策略分发:TeamBrain(团队共享 Lua VM 黑板)及其后续阶段;
- TP 纪律 / 支援仲裁 / 推进-防守姿态(midtp、suptp、tpcommit、ownhalf、
  overchase、pushguard 一族);
- **对线期策略归本组**:拉野(owner:拉野是肯定要做的,数据不对=设计或实现错)、
  兵线控制、换血、吃经验;标准策略要上网检索佐证(验证哲学条件 (c))。

## 每次触发的工作流
1. 扫 [strategy] 前缀的 open issue(dragonghy/dota2bot),优先处理带帧证据的;
   没有 issue 就从下面 backlog 取最上面一条。
2. 改动纪律(铁律之上的本组细则):
   - 每个行为改动 **gated**(`J.IsSoakCandidate('<id>')`,turbo-only),
     新 id 要在 `iterations/state.json` 登记;
   - **必须带真实帧 fixture**(make_fixture.py → tests/fixtures/ →
     tests/mock/replay_fixture.lua),gate-plumbing 测试不算本地验证;
   - 想进测试集:改 `iterations/streams/test_set.md` 提议(留历史行),
     总监批准;需要批测数据就往 `iterations/queue.json` 提请求;
   - **一次动一个小杠杆**。lanefix 大捆绑两次被拒(gpm −74.5/−88.7)的教训:
     局部各自正确 ≠ 集体涌现好。
3. push 前过铁律 6 的门(luacheck 0 警告 + 测试全绿)。
4. 报告写到 `iterations/reports/strategy/<UTC时间戳>.md`。

## Backlog(优先级从上到下,做完划掉、发现新的补进来)
1. ~~**l1xpsoak 重设计**~~ **代码已完成(2026-08-19),等总监重新入
   test_set.md**:绝对锚(落脚点进入时算一次、缓存在 bot 上,不再逐帧按
   当前坐标重算)+ 退出滞回(进入判据不变:≥2 敌方 within 1200 + 爆发
   ≥75% 血量;退出判据更松:敌方清零/健康队友抵达/爆发跌破 40% 血量)
   已落地(`bots/FunLib/jmz_func.lua` `J.ShouldXpSoakLane`),真实帧
   fixture 4 新用例(`tests/test_l1_xpsoak.lua`,复用
   `f_231411_ck_zoned.lua`)+ 全量 359 测试 + luacheck 0 警告全绿。
   已开 issue #24 请总监审批重新入集 + 排期验证批测(不确定是否有效,
   只是消掉了两个已知病灶,仍需批测验证是否真的解决 -49gpm 信号)。
2. **−18 econ 残差归因**:两波 8/8 seed 稳定的 −18 gpm 残差,嫌疑:
   lf_rescue 位移税 / ownhalf+overchase 姿态成本 / tpcommit 残余 /
   全局"响应预算"缺失。用批测归档录像做行为差分,别再开专门批测。
3. **TeamBrain phase 2:响应预算** — 全队对同一事件的响应人数/位移上限
   (与 −18 残差假说同源,可能一并解决)。
4. **suptp × midtp 协同仲裁**(owner:suptp 需要和 midtp 协同)。
5. **lf_rescue 规则细化**(owner:仔细思考规则;当前版本已有链式救援闸 +
   响应者生存力检查,需录像核验后再定)。
6. **拉野节奏打磨**:当前 6:00 宵禁 + 和平期 veto;检索标准拉野时机
   (波次时间差、双拉条件)对齐实现。

## 当前状态(每次触发后更新)
- 2026-08-01 初始化。测试集里本组名下 id:creeppull/pullcamp/l1trade/
  l5combo/midtp/suptp/tpcommit/lf_rescue/teambrain/ownhalf/overchase/tpwatch。
  l1xpsoak 不在集内,等重设计。
- 2026-08-19T01:15Z:首次真实工作报告(见
  `iterations/reports/strategy/20260819T011551Z.md`)。完成 l1xpsoak 重设计
  代码(绝对锚 + 退出滞回),fixture 验证 + 全套测试 + luacheck 全绿,已
  push。**l1xpsoak 仍不在 test_set.md 里**(该文件编辑权在总监)——已开
  issue #24 请总监审批重新入集并排期验证批测。未花 AWS 钱,未提批测请求。
