# Spot Instance Migration Plan

Status: **planned, not yet implemented.** The current soak farm runs on a
single on-demand `c6i.4xlarge`. This document is the runbook for switching the
farm (and win-rate A/B batches) to Spot to cut cost ~60%. Bake stays
on-demand. Implement this after the current 48h soak run finishes.

## Why our workload fits Spot

The soak farm is fault-tolerant by construction: every finished game ships its
log + analysis to S3 immediately, so a reclaimed instance loses at most the
~16 in-flight games (a few dollars of compute, no saved state). Win-rate A/B
is the same — per-game results accumulate in S3; an interruption just means we
resume accumulating on a fresh instance. This is exactly the "run when capacity
is available, don't need a guaranteed always-on box" profile Spot is for.

## Pricing (us-west-2 / Oregon, sampled 2026-07-19; Spot floats, recheck at cutover)

| Instance | vCPU / RAM | On-Demand | Spot | Discount | Spot @ 730h/mo |
|---|---|---|---|---|---|
| c6i.4xlarge (current) | 16 / 32 GB | $0.68/h | ~$0.256/h | -62% | ~$187 |
| m6i.4xlarge | 16 / 64 GB | $0.77/h | ~$0.225/h | -71% | ~$164 |
| c5.4xlarge | 16 / 32 GB | $0.68/h | ~$0.236/h | -65% | ~$172 |
| c7i.4xlarge | 16 / 32 GB | $0.71/h | ~$0.247/h | -65% | ~$180 |
| c6a.4xlarge | 16 / 32 GB | $0.61/h | ~$0.247/h | -60% | ~$180 |
| **c6i.8xlarge** | **32 / 64 GB** | $1.36/h | ~$0.47/h | -65% | ~$343 |

Recheck live before cutover:
```bash
awsx ec2 describe-spot-price-history --region us-west-2 \
  --instance-types c6i.4xlarge m6i.4xlarge c5.4xlarge c7i.4xlarge c6a.4xlarge \
  --product-descriptions "Linux/UNIX" \
  --start-time "$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%S)" \
  --query 'SpotPriceHistory[].[InstanceType,AvailabilityZone,SpotPrice]' --output table
```

## Savings

- **Same throughput (16 slots on a 4xlarge):** ~$497/mo on-demand -> ~$187/mo
  Spot ≈ **62% off / ~$310 saved per month**. A 48h run: **$33 -> $12**.
- **Same budget, more throughput:** a `c6i.8xlarge` Spot ($0.47/h) is *cheaper*
  than today's on-demand 4xlarge ($0.68/h) yet has **32 vCPU = ~2x parallel
  games**. ~3000 games / 48h instead of ~1500, for less money. Best
  price/performance option.

## Target architecture: self-healing Auto Scaling Group

```
EC2 Auto Scaling Group  (desired=1, min=0, max=1)
  mixed-instances policy:
    capacity = 100% spot
    instance types = [c6i.4xlarge, c6a.4xlarge, c5.4xlarge, m6i.4xlarge, c7i.4xlarge]
    allocation strategy = price-capacity-optimized
    across all AZs
  launch template:
    AMI = ami-0a990a26d89c66547 (batch runner, game baked in)
    IAM instance profile = dota2bot-batch-runner
    user-data: on boot, start the farm (systemd unit below)
    tag: Name=dota2bot-soak
```

Reclaim -> ASG launches a replacement from the cheapest available
type/AZ automatically. The replacement boots, the systemd unit starts the
farm, results resume flowing to S3. No human in the loop.

Diversifying across 5 instance types x 4 AZs makes simultaneous unavailability
of all of them very unlikely, so effective interruption impact is minimal.

## Implementation checklist (scripts to write)

1. **`bake` add-on — farm systemd unit.** Add to the AMI (re-bake or push via
   SSM once): `/etc/systemd/system/dota2bot-soak.service` that runs
   `farm_start.sh <N> <run_id>` on boot as `ubuntu`. N chosen by vCPU count
   (nproc-2 or a measured optimum). Pull latest repo before starting. Derive
   run_id from a fixed rolling scheme or an S3-stored value so replacements
   append to the same run prefix.
2. **`setup_asg.sh`** — create launch template + ASG (params above). Idempotent.
3. **Spot interruption handler (optional).** A tiny systemd unit polling
   `http://169.254.169.254/latest/meta-data/spot/instial-action`; on notice,
   gzip+upload in-flight `/opt/soak/slot*/stdout_*.log` before the 2-min cutoff.
4. **Monitoring: tag-based instance lookup.** Update the autonomous-loop checks
   to resolve the instance by `Name=dota2bot-soak` tag rather than a hardcoded
   ID (ASG replaces instances -> IDs change). One helper:
   `awsx ec2 describe-instances --filters Name=tag:Name,Values=dota2bot-soak
   Name=instance-state-name,Values=running --query
   'Reservations[].Instances[0].InstanceId'`.
5. **`aws_run.sh` (A/B batches)** already supports `--instance-market-options
   MarketType=spot`; add `--on-demand` escape hatch (present) and default the
   A/B path to spot with the same diversified types via a small fleet request.
6. **Teardown:** `asg_stop.sh` sets desired=0 (kills the farm cheaply without
   deleting the ASG); `asg_delete.sh` removes ASG + launch template.

## What stays on-demand

- **AMI bake** (`bake_ami.sh`): needs an uninterrupted ~1h run to download the
  game and snapshot. One-off, cheap, not worth Spot risk.
- Any future step that must complete a single long transaction without restart.

## Cutover procedure (when we pull the trigger)

1. Finish/stop the current on-demand soak run; terminate the on-demand box.
2. Re-check live Spot prices (command above); adjust the type list if one is
   spiking.
3. Add the systemd farm unit to the AMI (SSM one-shot or re-bake).
4. `setup_asg.sh` -> ASG comes up on Spot, farm auto-starts.
5. Switch autonomous monitoring to tag-based lookup.
6. Watch one interruption cycle (or simulate via ASG instance refresh) to
   confirm self-heal + result continuity.

## Risks / honest tradeoffs

- **Capacity gaps:** when all chosen types are constrained, ASG may not launch
  for minutes-to-longer. Fine for non-deadline iteration; the farm just pauses.
- **Added moving parts:** ASG + launch template + systemd + tag-based
  monitoring vs. today's single `run-instances`. More to reason about.
- **Price drift:** Spot prices move; the ~62% figure is a snapshot. Recheck at
  cutover. `price-capacity-optimized` allocation already steers toward cheap +
  stable pools.
- **Budget backstop unchanged:** the $100 budget + 100% freeze still applies;
  Spot only makes it much harder to approach.
