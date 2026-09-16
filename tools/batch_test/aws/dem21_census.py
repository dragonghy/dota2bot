#!/usr/bin/env python3
"""Per-cohort census of the `dem21/` prefix WITH the expiry anchor computed,
not remembered.

WHY THIS EXISTS
    2026-09-16T15:11Z the desk pinned the lifecycle sweep lag of the 08-25
    cohort into a ~3h window and registered the band as `[21h, 24h]`.  The
    band was written without saying WHAT it is a lag FROM, and that omission
    is not recoverable later: the anchor is the creation timestamp of the
    objects, and the rule being measured DELETES those objects.  Once a
    cohort is swept there is no way to re-derive which anchor a past round
    used, so a band recorded without its anchor can never be checked again --
    it can only be copied forward.

    It also fails in the dangerous direction.  Re-deriving the same
    observation against the anchor S3 actually documents
    (`Expiration.Days` = creation time + N days, ROUNDED UP to the next UTC
    midnight) gives `[12h, 15h]`, and moves the 08-26 cohort's due instant
    from "today" to `2026-09-17T00:00Z`.  The round that wrote the band read
    the 08-26 cohort as `已到期仍在桶里` (overdue, still in the bucket) and
    started a lag clock on it.  Under the documented anchor that cohort was
    not due at all, so the clock had no referent -- an overstated lag makes
    the bucket look healthy for longer than it is, which is the half that
    nobody comes looking for.

    So the anchor stops being prose.  This script reads the cohorts and the
    expiry rule as data and prints the due instant per cohort, so no round has
    to remember the rounding rule and no future round has to guess which one
    was used.

WHAT IT REFUSES TO DO
    It will not assume `21` days.  The prefix is NAMED `dem21/`, which is
    exactly the kind of name that keeps looking right after the rule behind it
    changes; a hardcoded 21 against a 14-day rule mis-dates every prediction
    silently and in the same dangerous direction.  Pass the live lifecycle
    JSON (`--lifecycle`) or say the number out loud (`--expire-days`).

READINGS ARE FREE OF DOWNLOADS
    Input is an `s3 ls --recursive` listing and a
    `s3api get-bucket-lifecycle-configuration` JSON.  This script downloads no
    objects and issues no AWS call of its own (RULING 48: a round that runs it
    still reports `S3 读取 0 个对象`).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timedelta, timezone

# `2026-08-26 03:26:04       2097152 dem21/<key>`
_LINE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})\s+(?P<time>\d{2}:\d{2}:\d{2})\s+(?P<size>\d+)\s+(?P<key>\S.*)$"
)


def expiry_instant(created: datetime, days: int) -> datetime:
    """S3 `Expiration.Days`: creation time + days, rounded UP to next UTC midnight.

    The round-up is the whole point of computing this rather than writing
    `creation date + days` in a report: for any object not created exactly at
    00:00:00Z the two differ by up to 24h, and every observed sweep so far sits
    inside that difference.
    """
    t = created + timedelta(days=days)
    midnight = t.replace(hour=0, minute=0, second=0, microsecond=0)
    if t == midnight:
        return midnight
    return midnight + timedelta(days=1)


def expire_days_from_lifecycle(doc: dict, prefix: str) -> int:
    """Pull `Expiration.Days` for the rule whose filter covers `prefix`.

    Refuses on 0 matches and on >1 match rather than picking one: two enabled
    rules over the same prefix is a real configuration whose effective expiry
    this script has no business guessing.
    """
    hits = []
    for rule in doc.get("Rules", []):
        if rule.get("Status") != "Enabled":
            continue
        days = (rule.get("Expiration") or {}).get("Days")
        if days is None:
            continue
        rp = rule.get("Prefix")
        if rp is None:
            rp = (rule.get("Filter") or {}).get("Prefix")
        if rp is None:
            and_block = (rule.get("Filter") or {}).get("And") or {}
            rp = and_block.get("Prefix")
        if rp is None:
            continue
        if prefix.startswith(rp) or rp.startswith(prefix):
            hits.append((rule.get("ID", "<no id>"), int(days)))
    if not hits:
        raise SystemExit(
            f"REFUSED: no Enabled lifecycle rule with Expiration.Days covers '{prefix}'. "
            "Nothing is expiring; a census that printed due dates anyway would be inventing them."
        )
    if len({d for _, d in hits}) > 1:
        raise SystemExit(
            "REFUSED: %d Enabled rules with different Expiration.Days cover '%s': %s. "
            "Pick with --expire-days; this script will not choose an effective expiry for you."
            % (len(hits), prefix, ", ".join(f"{i}={d}d" for i, d in hits))
        )
    return hits[0][1]


def census(lines, prefix, days, now):
    cohorts: dict[str, dict] = {}
    unparsed = 0
    skipped_other_prefix = 0
    for raw in lines:
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped:
            continue
        # `--summarize` trailer. Matched on the STRIPPED line: the real output
        # indents `Total Size:` by three spaces, so a prefix test against the
        # raw line lets it through and it surfaces as a bogus unparsed-line
        # WARNING -- the noisy side, which is how this one was caught.
        if stripped.startswith("Total Objects:") or stripped.startswith("Total Size:"):
            continue
        m = _LINE.match(line)
        if not m:
            # Never folded into a benign bucket: an unreadable line is a
            # listing-format change, and a format change that classifies itself
            # as "nothing here" is the failure this file exists to avoid.
            unparsed += 1
            continue
        if not m.group("key").startswith(prefix):
            skipped_other_prefix += 1
            continue
        created = datetime.strptime(
            f"{m.group('date')}T{m.group('time')}Z", "%Y-%m-%dT%H:%M:%SZ"
        ).replace(tzinfo=timezone.utc)
        day = m.group("date")
        c = cohorts.setdefault(
            day,
            {"day": day, "n": 0, "bytes": 0, "first": created, "last": created, "expiries": set()},
        )
        c["n"] += 1
        c["bytes"] += int(m.group("size"))
        c["first"] = min(c["first"], created)
        c["last"] = max(c["last"], created)
        c["expiries"].add(expiry_instant(created, days))

    out = []
    for day in sorted(cohorts):
        c = cohorts[day]
        exps = sorted(c["expiries"])
        due = exps[0]
        age_h = (now - due).total_seconds() / 3600.0
        out.append(
            {
                "day": day,
                "objects": c["n"],
                "bytes": c["bytes"],
                "gb": round(c["bytes"] / 1e9, 2),
                "first": c["first"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                "last": c["last"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                "due": due.strftime("%Y-%m-%dT%H:%M:%SZ"),
                # More than one distinct expiry inside one creation-day cohort
                # is reported, not averaged away.
                "due_spread": [e.strftime("%Y-%m-%dT%H:%M:%SZ") for e in exps],
                "overdue_hours": round(age_h, 2) if age_h >= 0 else None,
                "hours_until_due": round(-age_h, 2) if age_h < 0 else None,
                "status": "OVERDUE" if age_h >= 0 else "not due",
            }
        )
    return out, unparsed, skipped_other_prefix


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--listing", required=True, help="output of `aws s3 ls <bucket>/<prefix> --recursive`")
    ap.add_argument("--prefix", default="dem21/")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--lifecycle", help="output of `s3api get-bucket-lifecycle-configuration` (JSON)")
    g.add_argument("--expire-days", type=int, help="say the number out loud instead")
    ap.add_argument("--now", help="UTC instant to age against (default: real now); %%Y-%%m-%%dT%%H:%%M:%%SZ")
    ap.add_argument("--json", action="store_true", help="machine-readable rows on stdout")
    args = ap.parse_args(argv)

    if args.lifecycle:
        with open(args.lifecycle) as fh:
            doc = json.load(fh)
        days = expire_days_from_lifecycle(doc, args.prefix)
        source = f"{args.lifecycle} (live rule, read this run)"
    else:
        days = args.expire_days
        source = "--expire-days on the command line (NOT read from the bucket)"

    now = (
        datetime.strptime(args.now, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        if args.now
        else datetime.now(timezone.utc)
    )

    with open(args.listing) as fh:
        rows, unparsed, other = census(fh, args.prefix, days, now)

    total_n = sum(r["objects"] for r in rows)
    total_b = sum(r["bytes"] for r in rows)

    if args.json:
        print(json.dumps({"expire_days": days, "days_source": source, "now": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                          "cohorts": rows, "unparsed_lines": unparsed,
                          "objects": total_n, "bytes": total_b}, indent=2))
    else:
        print(f"prefix           : {args.prefix}")
        print(f"Expiration.Days  : {days}   <- {source}")
        print("anchor           : creation time + Days, ROUNDED UP to next UTC midnight (S3 documented rule)")
        print(f"now              : {now.strftime('%Y-%m-%dT%H:%M:%SZ')}")
        print(f"objects / bytes  : {total_n} / {total_b} ({total_b / 1e9:.2f} GB)")
        print("")
        print(f"{'cohort':<12}{'n':>6}{'GB':>9}  {'last created':<22}{'due (computed)':<22}{'status':<10}")
        for r in rows:
            age = (
                f"OVERDUE {r['overdue_hours']}h"
                if r["status"] == "OVERDUE"
                else f"due in {r['hours_until_due']}h"
            )
            print(f"{r['day']:<12}{r['objects']:>6}{r['gb']:>9.2f}  {r['last']:<22}{r['due']:<22}{age:<10}")
            if len(r["due_spread"]) > 1:
                print(f"{'':<12}  ^ {len(r['due_spread'])} distinct due instants in this cohort: "
                      + ", ".join(r["due_spread"]))

    # Its own line, never folded into the census line: a number you have to
    # find among four others is a number nobody finds.
    if unparsed:
        print(
            f"WARNING: {unparsed} listing line(s) did not parse -- listing format change, "
            "NOT an empty bucket. The counts above are short by that many lines.",
            file=sys.stderr,
        )
    print(f"census: {len(rows)} cohort(s), {total_n} object(s), {unparsed} unparsed line(s), "
          f"{other} line(s) outside '{args.prefix}'", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
