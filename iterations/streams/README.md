# 工作流架构(2026-08-01 owner 批准)

五个独立 Routine agent + 主会话整合者。每个 agent 每次触发是全新会话:
先读本目录自己的章程 + `state.json`,做**一个工作单元**,commit+push,更新自己
的章程内"当前状态"节,然后结束。互相通过仓库文件协作,不直接通信。

## 铁律(所有流共守)
1. **只有批测台可以花 AWS 的钱**。其他流要批测,往 `iterations/queue.json`
   里追加申请(格式见该文件头注释),等批测台执行后在自己章程里读结果。
2. 预算:MTD 刹车线 $90(owner 批准线 $100)。批测台负责执行与记账。
3. 验证纪律不变:先逐帧后聚合;fixture 先行;gated 出厂;**小组验证,
   永不大杂烩**(≤5 id/波);promote 建议提给主会话,不自行 promote。
4. push 前:`luacheck bots game --formatter plain` 0 警告 +
   `lua5.1 tests/run_tests.lua` 全绿。只 push origin main。
5. 提交信息不写模型名。冲突时 rebase 重试,仍冲突就只更新自己的 stream 文件
   记录阻塞,等主会话仲裁。
6. 工作单元要小(一次触发 ≤1 个修复/1 份分析/1 次收割),干完就结束会话。
