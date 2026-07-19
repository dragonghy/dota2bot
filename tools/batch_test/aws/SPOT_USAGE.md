# Parallel Spot Soak Farms — Usage & Cost Safety

`spot_run.sh` launches **N parallel spot soak-farm instances**. Each one boots
from the baked AMI, refreshes the repo + game, generates the soak draft pool,
deploys, runs the soak farm, ships **every finished game to its own S3 run
prefix**, and **self-terminates**. This multiplies experiment throughput: run
several A/B experiments at once instead of serially, at ~60-70% less compute
cost than on-demand.

## Quick start

```bash
bash tools/batch_test/aws/bootstrap_creds.sh     # once per session; then use awsx

# 1 spot farm on main, 14 slots, 3h watchdog:
./spot_run.sh

# 4 parallel spot farms, each its own tag + S3 prefix:
./spot_run.sh --count 4

# 3 farms, each running experiment branch `my-exp`, 2h cap:
./spot_run.sh --count 3 --ref my-exp --hours 2

# print the plan without launching:
./spot_run.sh --count 4 --dry-run

# escape hatch — on-demand instead of spot (no reclaim risk, ~2.6x price):
./spot_run.sh --on-demand
```

Options: `--count N` `--ref GITREF` `--slots S` `--hours H` `--type INSTANCE`
`--on-demand` `--dry-run`.

Each instance is tagged `dota2bot-soak-spot-<n>` (or `dota2bot-soak-od-<n>` for
on-demand) and writes to `s3://<bucket>/soak/spot_<stamp>_<n>_<ref>/`. Distinct
tag + prefix per instance means N farms never collide.

## One-time account prerequisite (owner action, admin required)

Spot launches need the account's **EC2 Spot service-linked role**
(`AWSServiceRoleForEC2Spot`). It is normally auto-created on first spot use, but
the restricted `dota2bot-agent` IAM user is **not** permitted to create service-
linked roles, so the account owner must create it **once** with admin/root
credentials:

```bash
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com
```

Until this exists, `spot_run.sh` (spot mode) fails with
`AuthFailure.ServiceLinkedRoleCreationNotPermitted`. `--on-demand` works without
it. This is a single, free, account-level action — after it, all future spot
launches through the restricted user succeed.

## Pricing: on-demand vs spot (us-west-2, sampled 2026-07-19)

| Instance | vCPU / RAM | On-Demand | Spot (live) | Savings |
|---|---|---|---|---|
| **c6i.4xlarge** (default) | 16 / 32 GB | **$0.68/h** | **~$0.257/h** | **~62%** |
| c6a.4xlarge | 16 / 32 GB | $0.61/h | ~$0.248/h | ~59% |
| c5.4xlarge | 16 / 32 GB | $0.68/h | ~$0.237/h | ~65% |

Live spot floats; recheck before a big run:

```bash
awsx ec2 describe-spot-price-history --region us-west-2 \
  --instance-types c6i.4xlarge c6a.4xlarge c5.4xlarge \
  --product-descriptions "Linux/UNIX" \
  --start-time "$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%S)" \
  --query 'SpotPriceHistory[].[InstanceType,AvailabilityZone,SpotPrice]' --output table
```

**What N parallel spot farms cost** (c6i.4xlarge @ ~$0.257/h, 3h watchdog):

| Farms | $/hr | 3h run | vs same on-demand |
|---|---|---|---|
| 1 | $0.26 | ~$0.77 | $2.04 |
| 4 | $1.03 | ~$3.09 | $8.16 |
| 8 | $2.06 | ~$6.17 | $16.32 |

8 spot farms for 3h (~$6) is cheaper than **3** on-demand farms, for 8x the
parallel throughput.

## Cost guardrails (layered)

1. **`--instance-initiated-shutdown-behavior terminate`** — a stopped box never
   lingers; shutdown = terminate = billing stops.
2. **Watchdog `shutdown -h +<hours*60>`** baked into user-data — default **3h**,
   hard cap regardless of progress. Verify on any instance with `shutdown --show`
   (`Shutdown scheduled for …`). Outer bound available via `--hours 12`.
3. **One-time spot request** (`SpotInstanceType=one-time`,
   `InstanceInterruptionBehavior=terminate`) — a reclaim terminates and does
   **not** silently relaunch. A tiny in-user-data poller flushes in-flight
   analysis JSON to S3 on the ~2-min interruption notice; finished games were
   already shipped per-game, so a reclaim loses at most a few in-flight games.
4. **`check_costs.sh`** — run before and after every batch. Lists all
   `dota2bot-*` running instances and month-to-date spend. Anything running that
   shouldn't be: `awsx ec2 terminate-instances --region us-west-2 --instance-ids <id>`.
5. **AWS Budget backstop** (`dota2bot-batch`, freeze at 100%) — last line, not
   the primary control.

**Spend policy:** every $50 of cumulative AWS spend needs the owner's approval
before launching further paid work. Track it with `check_costs.sh`; when a new
$50 tier would be crossed, stop and ask first. Before launching many farms at
once, multiply `count x $0.26/h x hours` and confirm it stays under the tier.

## Monitoring & teardown

```bash
# running spot farms (tag-based; IDs change per launch):
awsx ec2 describe-instances --region us-west-2 \
  --filters Name=tag:Name,Values=dota2bot-soak-spot-* \
            Name=instance-state-name,Values=pending,running \
  --query 'Reservations[].Instances[].[InstanceId,InstanceLifecycle,State.Name,Tags[?Key==`soak-run`]|[0].Value]' \
  --output table

aws s3 ls s3://<bucket>/soak/                       # per-run result prefixes
awsx ec2 terminate-instances --region us-west-2 --instance-ids <id ...>   # kill early
```

Do **not** confuse these with the standing on-demand farm
(`i-08b59ef7130025860`, tag `dota2bot-diag`) — the spot farms carry
`dota2bot-soak-spot-*` tags.
