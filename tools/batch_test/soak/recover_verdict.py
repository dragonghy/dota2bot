#!/usr/bin/env python3
# Recover a mirrored-A/B verdict from a run's per-game analysis.json when a spot
# RECLAIM killed the instance before validate_onspot.sh computed/uploaded it.
# The games are already in S3 (uploaded per-game), stamped mirror:CAND:sSEED:side
# by soak_loop's ab_version read -- so the verdict is fully recoverable offline.
#
#   aws s3 cp s3://<bucket>/soak/<run>/ ./g/ --recursive \
#       --exclude "*" --include "*.analysis.json"
#   python3 recover_verdict.py ./g <cand-id>
#
# Replicates validate_onspot.sh's math exactly (mirror: candidate-side minus
# baseline-side, averaged over the radiant-wave and dire-wave to cancel side
# bias; positive gpm/xpm/last_hits = candidate better, negative deaths better).
# Only seeds with BOTH waves present are scored; partial seeds are reported but
# excluded from the mean.
import json, glob, statistics, sys, re, os

run_dir, cand = sys.argv[1], sys.argv[2]

games = []
for f in glob.glob(os.path.join(run_dir, "*.analysis.json")):
    try:
        a = json.load(open(f))
        games.append(a)
    except Exception:
        pass

def sv(a, t, m):
    return [p.get(m) or 0 for p in a.get("players", []) if p.get("team") == t]

def M(xss):
    xs = [x for s in xss for x in s]
    return statistics.mean(xs) if xs else 0

# group by stamp
by_stamp = {}
for a in games:
    st = a.get("script_version") or ""
    by_stamp.setdefault(st, []).append(a)

seeds = sorted(set(re.match(r"mirror:%s:s(\d+):" % re.escape(cand), st).group(1)
                   for st in by_stamp if st.startswith("mirror:%s:" % cand)))

rows = []
for seed in seeds:
    rs = "mirror:%s:s%s:radiant" % (cand, seed)
    ds = "mirror:%s:s%s:dire" % (cand, seed)
    AB, BA = by_stamp.get(rs, []), by_stamp.get(ds, [])
    row = {"seed": seed, "ab_games": len(AB), "ba_games": len(BA)}
    if AB and BA:
        for m in ("gpm", "xpm", "deaths", "last_hits"):
            ab = M([sv(a, "radiant", m) for a in AB]) - M([sv(a, "dire", m) for a in AB])
            ba = M([sv(a, "dire", m) for a in BA]) - M([sv(a, "radiant", m) for a in BA])
            row[m] = round((ab + ba) / 2, 2)
    rows.append(row)

v = {"cand": cand, "recovered_locally": True, "per_seed": rows, "mean": {}, "comps_better": {}}
complete = [r for r in rows if "gpm" in r]
for m in ("gpm", "xpm", "deaths", "last_hits"):
    xs = [r[m] for r in complete if m in r]
    if not xs:
        continue
    v["mean"][m] = round(statistics.mean(xs), 2)
    neg = m == "deaths"
    v["comps_better"][m] = "%d/%d" % (sum(1 for x in xs if (x < 0 if neg else x > 0)), len(xs))

g = v["mean"].get("gpm"); d = v["mean"].get("deaths")
v["suggested"] = ("promote" if (g is not None and g > 5 and complete and
    int(v["comps_better"]["gpm"].split('/')[0]) * 2 > len(complete) and (d is None or d <= 0))
    else "hold_or_reject")
print(json.dumps(v, indent=1))
