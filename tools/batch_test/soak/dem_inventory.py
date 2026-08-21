#!/usr/bin/env python3
"""Per-run `.dem` inventory for the results bucket — the enumerable form of the
director's Z.4 point 4 ("retire corpus by naming run prefixes, one at a time").

Z.4 rejected a size-based lifecycle rule for reclaiming the historical
`soak/**.dem` corpus, on the grounds that a deletion rule's predicate must be
identity (key/prefix) and never a proxy. What it approved instead is manual,
per-run retirement: the replay stream declares a run's corpus exhausted, the
director names that run, and only then does it go. That lever needs a list
nobody has had to hand-assemble: which runs hold `.dem` files, how much they
weigh, how old they are, and which seeds/heroes they are evidence for.

This tool builds that list from a plain `s3 ls --recursive` (read-only; it
never deletes, tags, or writes to the bucket) joined against
`iterations/data/seed_roster_index.json` for the seed/roster columns.

Retention context this table is read against (as of 2026-08-21):
  * `soak/<run>/**.dem`  — never expires. The historical corpus. This is what
    per-run retirement is for.
  * `dem21/<run>/**.dem` — plain-prefix 21-day expiry (`dem21-expire-21d`).
    Where bulk (`REC_SLOTS>1`) recordings land; nothing to retire by hand.
  * `replays/<TAG>.dem`  — flat slot-1 mirror, never expires, deliberately kept
    (owner re-watch + behavioural sweeps). Reported as its own line so that
    "recording storage is capped" is never said without it.
  * `soak/<run>/**.analysis.json|.log.gz` — the per-game archive. NEVER a
    deletion target; reported per run only so a retirement decision can see
    that retiring the `.dem` leaves the numbers intact.

Usage:
    aws s3 ls s3://<bucket>/soak/    --recursive > soak.txt
    aws s3 ls s3://<bucket>/replays/ --recursive > replays.txt
    python3 dem_inventory.py --soak soak.txt --replays replays.txt \
        [--dem21 dem21.txt] [--index iterations/data/seed_roster_index.json] \
        [--min-gb 0] [--json out.json]

    python3 dem_inventory.py --verify     # offline self-test, no S3, no args
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict

GB = 1024.0 ** 3
# us-west-2 S3 Standard, the only class this bucket uses.
USD_PER_GB_MONTH = 0.023


def parse_ls(path):
    """Parse `aws s3 ls --recursive` output into (date, size, key) tuples.

    Format is `YYYY-MM-DD HH:MM:SS <size> <key>`. Keys here never contain
    spaces (run ids and tags are generated), but split with maxsplit so that a
    key which did would survive intact rather than being truncated.
    """
    rows = []
    with open(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            parts = line.split(None, 3)
            if len(parts) < 4:
                continue  # `PRE <prefix>/` lines and any non-object noise
            date, _time, size, key = parts
            if not size.isdigit():
                continue
            rows.append((date, int(size), key))
    return rows


def run_of(key):
    """`soak/<run>/<rest>` -> `<run>`; anything shallower -> None."""
    parts = key.split("/")
    if len(parts) >= 3 and parts[0] in ("soak", "dem21"):
        return parts[1]
    return None


def invert_index(index):
    """run id -> {"seeds": [...], "games": n} from the seed roster index."""
    by_run = defaultdict(lambda: {"seeds": set(), "games": 0})
    for seed, rec in (index.get("seeds") or {}).items():
        for run in rec.get("runs") or []:
            by_run[run]["seeds"].add(int(seed))
    return by_run


def build(soak_rows, replay_rows, dem21_rows, index):
    by_run = defaultdict(
        lambda: {
            "dem_count": 0,
            "dem_bytes": 0,
            "archive_count": 0,
            "archive_bytes": 0,
            "unattributed_count": 0,
            "first": None,
            "last": None,
        }
    )

    for date, size, key in soak_rows:
        run = run_of(key)
        if run is None:
            continue
        rec = by_run[run]
        if key.endswith(".dem"):
            rec["dem_count"] += 1
            rec["dem_bytes"] += size
            if "/unattributed/" in key:
                rec["unattributed_count"] += 1
        else:
            rec["archive_count"] += 1
            rec["archive_bytes"] += size
        rec["first"] = date if rec["first"] is None else min(rec["first"], date)
        rec["last"] = date if rec["last"] is None else max(rec["last"], date)

    seeds_by_run = invert_index(index)
    for run, rec in by_run.items():
        rec["seeds"] = sorted(seeds_by_run.get(run, {}).get("seeds", []))

    dem21_bytes = sum(s for _d, s, k in dem21_rows if k.endswith(".dem"))
    dem21_count = sum(1 for _d, _s, k in dem21_rows if k.endswith(".dem"))
    replay_bytes = sum(s for _d, s, k in replay_rows if k.endswith(".dem"))
    replay_count = sum(1 for _d, _s, k in replay_rows if k.endswith(".dem"))

    runs_with_dem = {r: v for r, v in by_run.items() if v["dem_count"]}
    return {
        "runs": by_run,
        "totals": {
            "runs_total": len(by_run),
            "runs_with_dem": len(runs_with_dem),
            "soak_dem_count": sum(v["dem_count"] for v in by_run.values()),
            "soak_dem_bytes": sum(v["dem_bytes"] for v in by_run.values()),
            "soak_archive_count": sum(v["archive_count"] for v in by_run.values()),
            "soak_archive_bytes": sum(v["archive_bytes"] for v in by_run.values()),
            "dem21_count": dem21_count,
            "dem21_bytes": dem21_bytes,
            "replays_flat_count": replay_count,
            "replays_flat_bytes": replay_bytes,
        },
    }


def render(inv, min_gb=0.0, top=None):
    t = inv["totals"]
    out = []
    out.append(
        "soak/**.dem (never expires)   : %5d files  %8.2f GB  ~$%.2f/mo  across %d runs"
        % (
            t["soak_dem_count"],
            t["soak_dem_bytes"] / GB,
            t["soak_dem_bytes"] / GB * USD_PER_GB_MONTH,
            t["runs_with_dem"],
        )
    )
    out.append(
        "dem21/**.dem (21d prefix rule): %5d files  %8.2f GB  ~$%.2f/mo"
        % (t["dem21_count"], t["dem21_bytes"] / GB, t["dem21_bytes"] / GB * USD_PER_GB_MONTH)
    )
    out.append(
        "replays/*.dem (flat, kept)    : %5d files  %8.2f GB  ~$%.2f/mo  <- slot-1 mirror, never expires"
        % (
            t["replays_flat_count"],
            t["replays_flat_bytes"] / GB,
            t["replays_flat_bytes"] / GB * USD_PER_GB_MONTH,
        )
    )
    out.append(
        "soak/** per-game archive      : %5d files  %8.2f GB  ~$%.2f/mo  <- NEVER a deletion target"
        % (
            t["soak_archive_count"],
            t["soak_archive_bytes"] / GB,
            t["soak_archive_bytes"] / GB * USD_PER_GB_MONTH,
        )
    )
    out.append("")
    out.append(
        "retirable units (soak/<run>/**.dem), heaviest first; "
        "'archive' stays behind in every case:"
    )
    out.append(
        "%-52s %5s %8s %8s  %-10s %-10s %s"
        % ("run", "dems", "GB", "$/mo", "first", "last", "seeds")
    )
    rows = sorted(
        ((r, v) for r, v in inv["runs"].items() if v["dem_count"]),
        key=lambda kv: -kv[1]["dem_bytes"],
    )
    shown = 0
    for run, v in rows:
        gb = v["dem_bytes"] / GB
        if gb < min_gb:
            continue
        if top is not None and shown >= top:
            out.append("  ... %d more runs below the cut" % (len(rows) - shown))
            break
        seeds = ",".join(str(s) for s in v["seeds"]) or "-"
        out.append(
            "%-52s %5d %8.2f %8.2f  %-10s %-10s %s"
            % (run, v["dem_count"], gb, gb * USD_PER_GB_MONTH, v["first"], v["last"], seeds)
        )
        shown += 1
    return "\n".join(out)


def _verify():
    """Offline self-test: no S3, no bucket, no network."""
    import tempfile

    fails = []

    def ok(label, got, want):
        if got != want:
            fails.append("%s: got %r want %r" % (label, got, want))

    sample = (
        "2026-07-19 05:49:21       5151 soak/run_A/g1.analysis.json\n"
        "2026-07-19 05:49:19      26430 soak/run_A/g1.log.gz\n"
        "2026-07-19 06:00:00     9000000 soak/run_A/g1.dem\n"
        "2026-08-20 18:08:55     8000000 soak/run_B/g2.dem\n"
        "2026-08-20 18:09:55     7000000 soak/run_B/unattributed/x.dem\n"
        "2026-08-20 18:10:00        100 soak/run_B/g2.analysis.json\n"
        "                           PRE soak/run_C/\n"
        "2026-08-20 18:11:00       1234 soak/toplevel-not-a-run.json\n"
    )
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "soak.txt")
        with open(p, "w") as fh:
            fh.write(sample)
        rows = parse_ls(p)
        ok("parse skips PRE lines and keeps objects", len(rows), 7)

        empty = os.path.join(d, "empty.txt")
        open(empty, "w").close()
        ok("empty listing parses to nothing", parse_ls(empty), [])

    ok("run_of soak", run_of("soak/run_A/g1.dem"), "run_A")
    ok("run_of dem21", run_of("dem21/run_A/g1.dem"), "run_A")
    ok("run_of nested unattributed", run_of("soak/run_B/unattributed/x.dem"), "run_B")
    ok("run_of top-level key", run_of("soak/toplevel.json"), None)
    ok("run_of foreign prefix", run_of("replays/tag.dem"), None)

    index = {"seeds": {"101": {"runs": ["run_A"]}, "102": {"runs": ["run_A", "run_B"]}}}
    inv = build(rows, [("2026-08-20", 500, "replays/t.dem")], [], index)

    ok("run_A dem count", inv["runs"]["run_A"]["dem_count"], 1)
    ok("run_A archive count", inv["runs"]["run_A"]["archive_count"], 2)
    ok("run_B counts unattributed as a dem", inv["runs"]["run_B"]["dem_count"], 2)
    ok("run_B unattributed tally", inv["runs"]["run_B"]["unattributed_count"], 1)
    ok("run_B archive count", inv["runs"]["run_B"]["archive_count"], 1)
    ok("archive bytes exclude dems", inv["runs"]["run_A"]["archive_bytes"], 5151 + 26430)
    ok("dem bytes exclude archive", inv["runs"]["run_A"]["dem_bytes"], 9000000)
    ok("first date", inv["runs"]["run_A"]["first"], "2026-07-19")
    ok("last date", inv["runs"]["run_B"]["last"], "2026-08-20")
    ok("seeds joined from index", inv["runs"]["run_A"]["seeds"], [101, 102])
    ok("seeds for run with one", inv["runs"]["run_B"]["seeds"], [102])
    ok("run with no dem is still listed", "toplevel-not-a-run.json" in inv["runs"], False)
    ok("runs_with_dem", inv["totals"]["runs_with_dem"], 2)
    ok("flat replay mirror counted separately", inv["totals"]["replays_flat_count"], 1)
    ok("dem21 empty is zero not error", inv["totals"]["dem21_count"], 0)
    ok(
        "soak dem total",
        inv["totals"]["soak_dem_count"],
        inv["runs"]["run_A"]["dem_count"] + inv["runs"]["run_B"]["dem_count"],
    )

    text = render(inv)
    ok("render mentions run_A", "run_A" in text, True)
    ok("render marks the flat mirror as kept", "never expires" in text, True)
    ok("min_gb cut drops small runs", "run_A" in render(inv, min_gb=1.0), False)

    # A run whose dems are gone but whose archive remains must not reappear as
    # a retirement candidate — that is the post-retirement steady state.
    retired = {k: v for k, v in inv["runs"].items()}
    retired["run_A"] = dict(retired["run_A"], dem_count=0, dem_bytes=0)
    ok("retired run drops off the candidate table", "run_A" in render({"runs": retired, "totals": inv["totals"]}), False)

    if fails:
        print("FAIL (%d):" % len(fails))
        for f in fails:
            print("  " + f)
        return 1
    print("dem_inventory self-test: all checks passed")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--soak", help="`s3 ls s3://<bucket>/soak/ --recursive` output")
    ap.add_argument("--replays", help="`s3 ls s3://<bucket>/replays/ --recursive` output")
    ap.add_argument("--dem21", help="`s3 ls s3://<bucket>/dem21/ --recursive` output")
    ap.add_argument("--index", default="iterations/data/seed_roster_index.json")
    ap.add_argument("--min-gb", type=float, default=0.0, help="hide runs lighter than this")
    ap.add_argument("--top", type=int, default=None, help="show only the N heaviest runs")
    ap.add_argument("--json", help="also write the full inventory as JSON here")
    ap.add_argument("--verify", action="store_true", help="offline self-test; no S3")
    args = ap.parse_args()

    if args.verify:
        return _verify()

    if not args.soak:
        ap.error("--soak is required (or use --verify)")

    soak_rows = parse_ls(args.soak)
    replay_rows = parse_ls(args.replays) if args.replays else []
    dem21_rows = parse_ls(args.dem21) if args.dem21 else []
    index = {}
    if args.index and os.path.exists(args.index):
        with open(args.index) as fh:
            index = json.load(fh)

    inv = build(soak_rows, replay_rows, dem21_rows, index)
    print(render(inv, min_gb=args.min_gb, top=args.top))

    if args.json:
        serialisable = {
            "totals": inv["totals"],
            "runs": {r: v for r, v in inv["runs"].items()},
        }
        with open(args.json, "w") as fh:
            json.dump(serialisable, fh, indent=1, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
