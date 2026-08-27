# 待落地:GH #159 的 `tpgap` 铁证帧 fixture(被 GH #236 挡住)

**状态**:两个文件都**做完并验证过**(fixture 6/6 测试全绿、`luacheck` 0 警告),
但**故意没有放进 `tests/fixtures/` 与 `tests/`**。原因不是它们有问题,是仓库还没准备好接收
**任何**后期帧 —— 见 **GH #236**。

## 文件

| 文件 | 落地目标路径 |
|---|---|
| `f_260826_155416_slardar_tpgap.lua` | `tests/fixtures/` |
| `test_replay_260826_155416_slardar_tpgap.lua` | `tests/` |

`mv` 这两个文件到目标路径就是全部的落地动作 —— **前提是 GH #236 的排序决定已经做出**。
直接 `mv` 而不处理 #236,会让 **16 个测试文件当场变红**(本轮实测:147 个语料相关文件跑完,
`RAN=147 RED=16`),外加录像组本轮已经自己修好的 2 个(`test_level_gate_census.lua`、
`test_turbo_ternary_dominance.lua`)与 1 个 python 计数(`test_write_only_local_census.py`
的 62→63)。**合计 19 个文件**。

## 为什么被挡住(一句话)

owner 优先项 **P3(批测局时上限 10 → 25 分钟,GH #108)**落地后,批测局第一次能打到自然结束
(本帧所在局 24.9 分钟)。而全仓库约 19 个普查文件把**「我们的语料永远到不了后期 / 20 级 /
25 级 / BKB」写成了前提** —— 那些零**从来都是 10 分钟 cap 的伪影**,不是 turbo 的性质。
**第一枚后期帧同时引爆全部。** 这不是本 fixture 的问题:**W14/W15 之后的每一枚 fixture 都会撞同一堵墙。**

## 复现配方(不依赖本目录,约 2 分钟)

```bash
bash tools/batch_test/aws/session_setup.sh
BIN=$(bash tools/batch_test/behavioral/get_dumper.sh)
source tools/batch_test/aws/aws.env
T=039cb1ae82ae5c83ef4d64e2d1c99007e3b0f13e
RUN=spot_20260826_151427_1_${T}_a2baf3          # 注意是 a2baf3,不是 2c6d8e(GH #234)
awsx s3 cp "s3://${S3_BUCKET}/dem21/${RUN}/20260826_155416_slot4.dem" .
awsx s3 cp "s3://${S3_BUCKET}/soak/${RUN}/20260826_155416_slot4.analysis.json" .
$BIN 20260826_155416_slot4.dem > 155416_slot4.timeline.json
python3 tools/batch_test/replayscope/make_fixture.py 155416_slot4.timeline.json \
    --t 1382.2 --hero slardar --window 3.0 \
    --roles 20260826_155416_slot4.analysis.json \
    -o tests/fixtures/f_260826_155416_slardar_tpgap.lua
```

`--window 3.0` **不是默认值**,是刻意取的:它等于守卫自己的 `nChannelSeconds`,
这样 `observed.burst` 才是 `GetEstimatedDamageToTarget(true, bot, 3.0, ALL)` 的**量纲正确**的替身。

产出应当是 `burst={'npc_dota_hero_bristleback': 451}`、`died_after=2.8` —— 与
19:16Z 报告 §4.1 的 451 / 2.8 逐位吻合。

## 帧的正确地址(GH #234 更正)

| 项 | 正确值 | 19:16Z 报告写的 |
|---|---|---|
| run | `..._a2baf3` | `..._2c6d8e`(**错**) |
| seed | **895** | 906(**错**) |
| 局 / 时刻 / 主体 | `20260826_155416_slot4` / t=1382.2 / slardar | 同(对) |
| armed 腿 | dire(slardar team 3) | 同(对) |
