#!/usr/bin/env python3
# Recover a mirrored-A/B verdict from a run's per-game analysis.json when a spot
# RECLAIM killed the instance before validate_onspot.sh computed/uploaded it.
# The games are already in S3 (uploaded per-game), stamped mirror:CAND:sSEED:side
# by soak_loop's ab_version read -- so the verdict is fully recoverable offline.
#
#   aws s3 cp s3://<bucket>/soak/<run>/ ./g/ --recursive \
#       --exclude "*" --include "*.analysis.json"
#   python3 recover_verdict.py ./g <cand-id> [--cand-ref <ref-armed-string>]
#
# [GH #141] --cand-ref declares that the wave was a TWO-ARM bisect: the
# reference leg carried its own armed string (soak_side.lua's `cand_ref`)
# instead of running stable. The math below is unchanged -- it is still
# candidate-leg minus reference-leg -- but the MEANING is armA-minus-armB, not
# candidate-minus-stable, so the verdict is stamped contrast=two_arm. A two-arm
# reading placed next to single-arm readings compares two different quantities
# and, once archived, cannot be told apart after the fact; the stamp is what
# keeps that from happening. The flag is declarative: the per-game files carry
# no record of the reference leg's string, so the caller must pass what it
# deployed.
#
# Replicates validate_onspot.sh's math exactly (mirror: candidate-side minus
# baseline-side, averaged over the radiant-wave and dire-wave to cancel side
# bias; positive gpm/xpm/last_hits = candidate better, negative deaths better).
# `winrate` is added on top of that four-metric set (neutral 0.5, see wr()
# below); `suggested` deliberately still reads gpm only -- changing the
# automated promote hint is a policy change, not a side effect of adding a
# metric (test_set.md AS.4).
# Only seeds with BOTH waves present are scored; partial seeds are reported but
# excluded from the mean.
import json, glob, statistics, sys, re, os

run_dir, cand = sys.argv[1], sys.argv[2]
argv = sys.argv[3:]
cand_ref = ""
if "--cand-ref" in argv:
    i = argv.index("--cand-ref")
    if i + 1 >= len(argv):
        sys.exit("--cand-ref needs a value (the reference leg's armed string)")
    cand_ref = argv[i + 1]

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

# --- winrate: the quantity README rule 2(b) names, and that this tool did not
# compute for the first fifty director rulings ------------------------------
# Rule 2(b) reads "the batch shows no obvious negative effect on WINS/LOSSES",
# but the four metrics above are all per-player ECONOMY means.  Every game's
# analysis.json has carried `winner` since analyze_log.py:120 -- nothing was
# ever missing from the corpus, this tool just never read it.
#
# HOW TO READ IT -- this is not a second, independent witness (test_set.md
# AS.1b).  analyze_log.py:80-85 rewrites `winner` to `econ_winner` (= the team
# with more total gold) for every game that hits the referee's ~30-game-minute
# cap, so for most games winner == sign(team gold delta), and team gold is gpm
# times duration.  The winrate is a SIGN-COARSENED read of the same signal.
#
# It is still worth having because it answers a different question: gpm is a
# 5-player mean ("by how much"), winner is a per-game team-total binary ("how
# often").  A -42 gpm mean can come from one hero collapsing while the team
# still wins more games than it loses -- and 2(b) names the latter.
#
# Hence winner_by is printed alongside, always: only games that ended because
# an ancient fell carry information independent of gold.  [GH #108] That bucket
# now has its own name, `engine_natural`, and reading the old `engine` bucket as
# "ended naturally" is wrong in BOTH directions: it used to also hold sub-cap
# forcewin artifacts whose engine winner happened to agree with the gold (so it
# over-counted), and under SOAK_CAP_MIN=25 a real natural win is no longer rare
# (so it under-counts what the cap change bought).  `engine_natural` is the
# gold-independent bucket, and its share is the natural-end rate #108 is judged
# by.  If it is small, so is the independence.
def wr(games, cand_team):
    """Candidate-side win rate over games that actually finished.

    Returns (wins, scored) -- games with winner None ("game did not finish")
    are excluded from BOTH, so the denominator is reported, never assumed.
    """
    scored = [a for a in games if a.get("winner") in ("radiant", "dire")]
    return sum(1 for a in scored if a["winner"] == cand_team), len(scored)

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
        # same two-wave average as the economy metrics, for the same reason
        # (it cancels the ~+1.5k Radiant side bias, CLAUDE.md).
        ab_w, ab_n = wr(AB, "radiant")
        ba_w, ba_n = wr(BA, "dire")
        row["scored_games"] = ab_n + ba_n
        row["unfinished"] = (len(AB) - ab_n) + (len(BA) - ba_n)
        if ab_n and ba_n:
            row["winrate"] = round(((ab_w / ab_n) + (ba_w / ba_n)) / 2, 3)
    rows.append(row)

v = {"cand": cand, "cand_ref": cand_ref or None,
     "contrast": "two_arm" if cand_ref else "vs_stable",
     "recovered_locally": True, "per_seed": rows, "mean": {}, "comps_better": {}}
complete = [r for r in rows if "gpm" in r]
for m in ("gpm", "xpm", "deaths", "last_hits"):
    xs = [r[m] for r in complete if m in r]
    if not xs:
        continue
    v["mean"][m] = round(statistics.mean(xs), 2)
    neg = m == "deaths"
    v["comps_better"][m] = "%d/%d" % (sum(1 for x in xs if (x < 0 if neg else x > 0)), len(xs))

# winrate is a rate, not a delta: neutral is 0.5, not 0.  Kept out of the loop
# above so the ">0 is better" convention there stays literally true.
wrs = [r["winrate"] for r in rows if "winrate" in r]
if wrs:
    v["mean"]["winrate"] = round(statistics.mean(wrs), 3)
    v["comps_better"]["winrate"] = "%d/%d" % (sum(1 for x in wrs if x > 0.5), len(wrs))
    v["winrate_neutral"] = 0.5
    v["scored_games"] = sum(r.get("scored_games", 0) for r in rows)
    v["unfinished_games"] = sum(r.get("unfinished", 0) for r in rows)
    # The independence disclosure (see the wr() header): only `engine` games
    # were not rewritten to the economic winner.
    by = {}
    for a in games:
        if a.get("winner") in ("radiant", "dire"):
            by[a.get("winner_by") or "unknown"] = by.get(a.get("winner_by") or "unknown", 0) + 1
    v["winner_by"] = by
    v["winrate_independent_of_gold"] = "%d/%d games" % (by.get("engine", 0),
                                                        sum(by.values()) or 0)

g = v["mean"].get("gpm"); d = v["mean"].get("deaths")
v["suggested"] = ("promote" if (g is not None and g > 5 and complete and
    int(v["comps_better"]["gpm"].split('/')[0]) * 2 > len(complete) and (d is None or d <= 0))
    else "hold_or_reject")
print(json.dumps(v, indent=1))
