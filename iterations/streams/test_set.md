# 当前测试集(测试版 = 稳定版 + 以下 armed)
creeppull,pullcamp,l1trade,l5combo,midtp,suptp,tpcommit,lf_rescue,teambrain,ownhalf,overchase,fieldregen,wandbleed,tpwatch,l1xpsoak

维护者:协同组提议增删,总监批准并修改本文件。
promote 出集(进稳定版)或 reject 出集都要在本文件留一行历史记录。

## 总监提醒(下一波涉及 l1xpsoak 时读)
`l1xpsoak` 历史上三次被拒(-61 solo 0/2;-49.4 solo 123 局镜像 x2),owner 明确
"MUST-DO,重设计后回测试集,不是悄悄埋掉"(`iterations/state.json` 606)。本次
重新入集只代表**条件 (c)(逻辑依据)和 fixture 级本地验证已过**——协同组
2026-08-19 补上了 mechanism note 里明确留白的两项(绝对锚 + 退出滞回,见
issue #24 / `iterations/reports/strategy/20260819T011551Z.md`);条件 (a)
(录像组核验真实对局执行正确)还没做,要等它在真实批测里 armed 过之后才能核。
**同时当前 14-id 组合本身正显示可疑的一致负向 gpm 信号**(3 seed 均值 -27.08,
0/3 全指标同向,`iterations/reports/batch-desk/20260819T020919Z.md`,与
07-31 的 12-id bundle -65/-74.5 历史同型)。**强烈建议 l1xpsoak 的下一波
按 07-31 A1/A2 bisect 的先例单独测(solo 或至少与现有 14-id 分开跑)**,
不要直接并进这个已经可疑的大 bundle——否则两个问题(l1xpsoak 本身有效性 /
14-id bundle 的残差负面)会互相污染,谁也说不清。batch-desk 排期时参考这条。

## 历史
- 2026-08-01 初始化:12-id 复审组 + wandbleed + tpwatch。l1xpsoak 不在集内(重设计中)。
- 2026-08-19 总监批准 `l1xpsoak` 重新入集(issue #24):协同组补完
  mechanism note 遗留的绝对锚 + 退出滞回重设计,fixture 验证 13/13
  (`tests/test_l1_xpsoak.lua`)+ 全套 359/359,luacheck 0 警告。条件 (a)
  待下一波真实对局核验,条件 (b) 待批测;建议单独测,见上方提醒。
