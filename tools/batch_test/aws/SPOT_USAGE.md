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

# escape hatch — on-demand instead of spot (~2.6x price).
# Owner 2026-08-26: this is a *capacity* fallback only. Do not pass
# --on-demand because a wave is "weight-bearing" or to avoid reclaim risk.
# Try c6i.4xlarge spot, then c6a.4xlarge spot, then --on-demand.
./spot_run.sh --on-demand

# pin ONE instance to an AZ (the 4x1 topology's guaranteed spread: one call
# per seed, a different --az in each), or rotate a single call over a list:
./spot_run.sh --count 1 --az us-west-2c
./spot_run.sh --count 4 --az us-west-2a,us-west-2b,us-west-2c,us-west-2d

# pre-#252 placement (EC2 chooses; the W17 wave that lost four instances to one
# capacity event was launched this way):
./spot_run.sh --no-az-spread
```

Options: `--count N` `--ref GITREF` `--slots S` `--hours H` `--type INSTANCE`
`--on-demand` `--az AZ[,AZ...]` `--no-az-spread` `--dry-run`.

### AZ spread ([harness] #252)

W17 (2026-08-27) launched four instances as four `--count 1` calls; EC2 put all
four in `us-west-2b` and one `instance-terminated-no-capacity` event took all
four in the **same second**, 27.5 min in. Every instance runs "ab leg, then ba
leg", so none reached its second leg: 128 games landed, all single-leg orphans,
zero usable seeds, ~$0.48. The 4x1 topology's redundancy was real; the
placement layer cancelled it.

Waves now rotate over `AZ_LIST` in `aws.env`. **The rotation offset is random
per process, not the instance index** — under 4x1 every call has `n=1`, so an
index rotation would put all four back in one AZ (the same trap as `RUN_TOKEN`
/ GH #98). Random offset makes "all four in one AZ" 4⁻³ = 1/64 instead of ~1;
**passing `--az` explicitly, one per call, is the only guarantee.** An explicit
`--az` list is walked from offset 0, so it is deterministic.

`AZ_LIST=` (empty) or `--no-az-spread` restores the exact pre-#252 call.

### When a pinned AZ has no capacity ([harness] #256)

The spread must never cost an instance, so a failed pin always ends with a
launch — but **where** it re-aims is the whole point. W18 (the first live wave
under #252) passed its acceptance and showed the residue: the old fallback
dropped the pin entirely, and EC2's own choice put 2 of 4 instances back into
`us-west-2b`, the AZ that had just zeroed two consecutive waves. Dropping the
constraint restores the correlation #252 removes, at the moment it is most
likely to be fatal — the pin failed *because* capacity is tight.

So a failed pin now walks the `AZ_LIST` ring, starting after the AZ that
failed, and only a fully exhausted ring falls back to unpinned. Two stderr
shapes, and they mean different things:

| line | meaning | report it as |
|---|---|---|
| `! <name>: re-aiming inside the ring -> <az>` | the pin failed, another ring AZ took it | not a degradation, but name "asked X, got Y" |
| `!! <name>: AZ RING EXHAUSTED …` | every AZ refused; placement abandoned | **wave-level warning** — reclaims are correlated again |

### Reading the placement off the log (#282)

W22 (2026-08-28) showed that the table above is not enough to *execute* #256's
acceptance criterion. Two instances asked for `2c`/`2d` and landed in `2a`, and
each one's whole log block was a single `launched … az=us-west-2a` line — no
failure line, no `re-aiming` line. The criterion ("if it re-aimed, the log
carries *that* line and not `az=`") was not violated; it was **unexecutable**,
because `az=` printed the script's own derived belief and nothing printed either
what the caller asked for or what EC2 answered. Two very different stories
printed byte-identically: *EC2 moved it*, and *this process never received your
`--az` at all*.

The launch path therefore now prints, **unconditionally, on the success path
too**:

```
  --az arg=us-west-2c                     <- plan header: the RAW argument received
launched <name>  id=…  run_id=…  az=us-west-2c  requested=us-west-2c  actual=us-west-2a
  ! <name>: PLACEMENT MISMATCH requested=us-west-2c actual=us-west-2a re-aimed=no <- UNEXPLAINED (#282): …
```

- `--az arg=` is the literal argument, echoed before any ring is derived — the
  one field that separates "your `--az` never arrived" (prints `<empty>`) from
  everything else. Everything downstream of it is self-consistent either way.
- `requested=` is where the instance was aimed **before** any re-aim
  (`<none>` if no placement was asked for at all).
- `actual=` is `Placement.AvailabilityZone` **as `run-instances` itself
  reports it** — the same response, no extra API call, and the only one of the
  three fields that is not this script's opinion. `<unreported>` when the API
  omits it, and an unreported placement is never counted as a mismatch.
- The `! … PLACEMENT MISMATCH` line fires whenever `requested != actual`.
  `re-aimed=yes` means the `!`/`!!` lines above it already explain the move;
  **`re-aimed=no … UNEXPLAINED (#282)`** is W22's shape and should be reported.

Per-wave check: for each instance, `requested == actual`, or there is a line
saying why not.

The retry ring is `AZ_LIST`, **not** the `--az` value: under the batch desk's
one-explicit-AZ-per-call convention the pin is a single AZ, so a retry keyed on
it would have nowhere to walk and would degrade to the #256 bug on the first
failure. Walk order is deterministic and starts after the failed AZ, so two
calls that failed in *different* AZs do not pile onto the same next one.

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
