# 批量对局测试流水线 (Batch Match Testing Pipeline)

在无头 (headless) 模式下批量运行 Dota 2 bot 对局，汇总胜率与经济指标，用于
A/B 验证 bot 脚本改动。**本工具只在开发机上运行，不属于创意工坊交付物。**

> 状态：脚手架已就绪，但控制台日志的具体格式（胜负判定行、指标行）需要在
> 第一次真实运行后校准 —— 见下方「首跑校准」。

## 前置条件

1. 一台 Linux 机器（本地或云 VM），8-16 核 CPU。每局约占 250MB 内存、1-2 个核。
   **并行上限 5-10 局**（资源约束）。
2. 通过 SteamCMD 安装 Dota 2（需要拥有 Dota 2 的 Steam 账号，免费游戏登录即可）：

   ```bash
   steamcmd +force_install_dir ~/dota2 +login <account> +app_update 570 validate +quit
   ```

3. 把本仓库的 `bots/` 目录链接到游戏脚本目录：

   ```bash
   mkdir -p ~/dota2/game/dota/scripts/vscripts
   ln -s /path/to/dota2bot/bots ~/dota2/game/dota/scripts/vscripts/bots
   ```

## 用法

```bash
# 跑 10 局，最多 5 局并行，4 倍速：
./run_batch.sh -n 10 -j 5 -t 4 -d ~/dota2 -o results/run1

# 解析并汇总一次批跑的结果：
python3 report.py results/run1

# A/B 对比两次批跑（例如改动前 vs 改动后）：
python3 report.py results/baseline results/candidate
```

每局的控制台输出保存在 `<outdir>/game_<N>.log`，解析后的单局指标存为
`<outdir>/game_<N>.json`。

## A/B 测试的两种形态

1. **新脚本 vs 默认 bot**：临时把 `bots/` 链接换成只含 `hero_selection.lua`
   受限英雄池的版本，对面队伍不放脚本（默认 bot）。Dota 的本地 bot 脚本对
   两队同时生效，因此「一队用脚本、一队默认」需要在脚本内部按队伍禁用 ——
   OHA 目前无此开关，**首跑时验证**：若不可行，退化为形态 2。
2. **版本 A vs 版本 B（推荐）**：两次批跑都在相同设置下进行（同英雄池、同
   随机种子集），A 用旧代码、B 用新代码，对比两组的胜率/GPM/XPM 分布。
   由于两队都由同一份脚本控制，取「天辉视角胜率」无意义；改用
   镜像英雄池（Radiant 池固定为被测英雄，Dire 随机）并对比被测英雄的
   个体指标（GPM/XPM/KDA/对局时长）。

## 首跑校准

`parse_log.py` 中的正则基于常见的 Source 2 控制台输出模式，以下几处需要
对照真实日志校准：

- 胜负行：搜索 `Building: ... Fort ... destroyed` 或游戏结束时 FretBots 的
  统计输出（`bots/FretBots/` 会在游戏结束时打印数据）。
- 指标行：OHA/FretBots 打印的 GPM/XPM/KDA 行格式。
- 若控制台完全静默,启动参数加 `-condebug`（把 console 输出写到
  `game/dota/console.log`）。

校准后更新 `parse_log.py` 顶部的 `PATTERNS` 字典即可。

## 加速与调试

- `+host_timescale 4` 需要 `+sv_cheats 1`（脚本已带）。8 倍速在弱机器上会掉逻辑帧，建议 ≤4。
- 游戏内调试：`dota_bot_reload_scripts`（热重载）、`dota_all_vision 1`。
- 世界状态导出（后续接 dotaservice 式分析时用）：
  `-botworldstatetosocket_radiant 12120 -botworldstatetosocket_dire 12121 -botworldstatetosocket_frames 10`
