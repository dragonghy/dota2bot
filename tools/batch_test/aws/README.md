# AWS 按需批量测试 —— 资源管理方案

核心原则：**没有常驻实例**。平时账户里只留一个 AMI 镜像（快照存储费约
$2-3/月）和 S3 里的测试结果（几乎免费）。每次批跑用一条命令拉起一台
Spot 实例，跑完自动把结果传到 S3 并**自我销毁**，双保险防止忘关机。

```
成本模型（us-west-2 参考价）：
- 待机成本：AMI 快照 ~45GB ≈ $2.3/月 + S3 结果 <$0.1/月
- 单次批跑：c6i.4xlarge (16核) Spot ≈ $0.25/小时
  100 局 ≈ 5-6 小时 ≈ $1.5/次
- 双保险：批跑完 shutdown 自毁 + cloud-init 看门狗超时强制自毁（默认 12h）
```

## 一次性准备（约 1.5 小时，需要你在场）

### 1. AWS 侧（10 分钟）
```bash
# 用你的 AWS 账号执行（需要 aws cli 已配置）：
./setup_aws.sh          # 创建: S3 桶、IAM 实例角色(仅限写该桶)、安全组、预算告警($20/月)
```
产出写入 `aws.env`（桶名/角色/安全组 ID），后续脚本都读它。

### 2. 烘焙 AMI（约 1 小时，其中 Steam 登录需要你输入）
```bash
./bake_ami.sh start     # 拉起一台按需实例并打印 SSH 命令
ssh ubuntu@<ip>
  # 在实例上：
  curl -O https://raw.githubusercontent.com/dragonghy/dota2bot/<branch>/tools/batch_test/aws/setup_on_instance.sh
  bash setup_on_instance.sh    # 装 steamcmd/依赖/克隆仓库
  steamcmd +force_install_dir /opt/dota2 +login <STEAM账号> +app_update 570 validate +quit
  #        ↑ 建议注册一个专用小号（Dota 2 免费）；首次登录要输 Steam Guard 验证码，
  #          登录凭据会缓存在镜像里，以后自动批跑不再需要人工输入
exit
./bake_ami.sh finish    # 从该实例创建 AMI，然后销毁实例
```
AMI ID 会写入 `aws.env`。**此后所有批跑都不再需要人工介入。**

### 3. 游戏版本更新
Dota 2 出补丁后镜像里的游戏会过期。user-data 里默认带
`+app_update 570`（用缓存凭据自动更新，一般几分钟）。大版本更新后建议
重新 bake 一次 AMI 免得每次启动都下载很久。

## 日常批跑（一条命令，无人值守）

```bash
# 同局对抗 A/B：100 局（50 正 + 50 换边），新版=当前分支，旧版=main
./aws_run.sh -n 100 --old main --new claude/continue-previous-context-k3l87y

# 跑完后（收到预算告警邮件前它早就自毁了）：
./fetch_results.sh      # 从 S3 拉结果并出 A/B 报告
```

`aws_run.sh` 做的事：起 Spot 实例（`--instance-initiated-shutdown-behavior
terminate`）→ user-data 里 git 拉指定分支 → `make_ab_build.py` 生成正/反
两个方向的构建 → `run_batch.sh` 各跑一半 → 结果 `aws s3 sync` → `shutdown`
（= 实例销毁）。看门狗：cloud-init 开头注册 `shutdown -h +720`（12 小时
硬上限），正常结束时提前触发。

## 成本核查（随时安心检查）

```bash
./check_costs.sh
# 输出：当前是否有实例在跑（应该是 0，除非批跑中）、本月已花费、AMI 快照占用
```

预算告警：`setup_aws.sh` 建了 $20/月 预算，超 80% 发邮件到你的账号邮箱。

## 故障处理

- **Spot 实例被回收**（概率低）：结果丢失，重跑即可；`aws_run.sh --on-demand`
  可改用按需实例（贵 ~3 倍但不会被回收）。
- **实例卡死没自毁**：看门狗 12h 兜底；`check_costs.sh` 看到异常实例后
  `aws ec2 terminate-instances --instance-ids <id>` 手动杀。
- **Steam 凭据过期**（长期未用可能发生）：重新 bake AMI 走一次登录。
