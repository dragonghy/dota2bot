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
# POOLING FOUR RUNS (the 4x1 topology every wave since W10 uses) -- [GH #225]
#   Give each run its OWN subdirectory and point this tool at the parent:
#
#     for r in 7f0cc4 552d6b 4f267b ffdcb6; do
#       aws s3 cp s3://<bucket>/soak/<run-$r>/ ./pool/$r/ --recursive \
#           --exclude "*" --include "*.analysis.json"
#     done
#     python3 recover_verdict.py ./pool <cand-id>
#
#   The collection below walks the tree and keys games by PATH, not by
#   basename, so nothing is lost.  Flattening four runs into one directory --
#   the obvious thing to do, and what the single-run usage above invites --
#   is the failure this tool now refuses: per-game files are named
#   `<YYYYmmdd_HHMMSS>_slot<N>.analysis.json` with no run token (soak_loop.sh:76),
#   the four instances are launched in the same second, and their slot cadence
#   matches, so cross-run basename collisions are the NORM, not an accident.
#   W14 measured it: 208 files became 188, 184 scored games became 170, and the
#   effect size moved 3.6 gpm -- and NOTHING raised a hand, because `cp` had
#   already destroyed the evidence at the filesystem layer and this tool could
#   only ever see the survivors.  `scored_games` shrank too, but no wave has an
#   expected count to compare it against (W12 23 / W13 24 / W14 24 drained
#   games), so 170 looked exactly as normal as 184.
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
#
# REFUSALS (exit 2, always with the count that motivated them) -- [GH #225].
# Every one of these used to be a silent drop, and a silent drop in THIS tool
# fails toward danger: it still prints a verdict, still prints `suggested`, and
# the number it prints is wrong by an amount nobody can bound after the fact.
#   R1  the same basename at >1 path with identical bytes -> the same game
#       would be counted twice (a pool downloaded into both `pool/` and
#       `pool/runX/`).  Both halves of that predicate are load-bearing: same
#       basename with DIFFERENT bytes is the legitimate cross-run case fix (A)
#       exists to support, and identical bytes under DIFFERENT basenames is two
#       games that merely scored alike, which is a synthetic corpus's business
#       and not a duplicate.
#   R2  one directory holding raw-tag basenames from >1 seed -> a flattened
#       multi-run pool, i.e. the W14 shape above.  One run carries exactly one
#       seed (mirror_ab.sh takes SEED as an argument and runs its two waves
#       sequentially), so two seeds under raw tag names in ONE directory means
#       `cp` has already been given the chance to overwrite.  Overridable with
#       --allow-pooled-basenames for a corpus whose layout is known-safe by
#       other means; the override prints that it is a SKIP, not a pass.
#   R3  a file that does not parse -> a lost game.  Overridable with
#       --allow-unparseable, same discipline.
import json, glob, statistics, sys, re, os, hashlib

run_dir, cand = sys.argv[1], sys.argv[2]
argv = sys.argv[3:]
cand_ref = ""
if "--cand-ref" in argv:
    i = argv.index("--cand-ref")
    if i + 1 >= len(argv):
        sys.exit("--cand-ref needs a value (the reference leg's armed string)")
    cand_ref = argv[i + 1]
allow_pooled = "--allow-pooled-basenames" in argv
allow_unparseable = "--allow-unparseable" in argv

# soak_loop.sh:76 -- TAG="$(date +%Y%m%d_%H%M%S)_slot$SLOT".  A basename that
# still matches this carries NO run token, so two runs can collide on it.  A
# basename that does not match it (the batch desk's `<run>__<tag>` rename) has
# already been disambiguated by the caller and is not R2's business.
RAW_TAG_BASENAME = re.compile(r"^\d{8}_\d{6}_slot\d+\.analysis\.json$")
STAMP_SEED = re.compile(r"^mirror:%s:s(\d+):" % re.escape(cand))


def refuse(title, lines):
    """Die loudly, in rec_slot_cost.py's house style: exit 2, never a number."""
    sys.stderr.write("REFUSED (recover_verdict.py, GH #225): %s\n" % title)
    for ln in lines:
        sys.stderr.write("  %s\n" % ln)
    sys.exit(2)


# Keyed by PATH, walked recursively: this is the whole of fix (A).  `**` with
# recursive=True matches zero directories too, so the single-run flat usage in
# the header keeps working unchanged.
paths = sorted(glob.glob(os.path.join(run_dir, "**", "*.analysis.json"),
                         recursive=True))
loaded, unparseable, by_digest = {}, [], {}
for f in paths:
    try:
        raw = open(f, "rb").read()
        a = json.loads(raw.decode("utf-8"))
    except Exception as e:
        unparseable.append("%s  (%s)" % (f, str(e)[:100]))
        continue
    loaded[f] = a
    by_digest.setdefault((os.path.basename(f),
                          hashlib.sha256(raw).hexdigest()), []).append(f)

if unparseable and not allow_unparseable:
    refuse("%d of %d files did not parse -- each one is a lost game"
           % (len(unparseable), len(paths)),
           unparseable[:20] +
           (["... and %d more" % (len(unparseable) - 20)] if len(unparseable) > 20 else []) +
           ["re-download them, or pass --allow-unparseable to score without them"])

dups = [ps for ps in by_digest.values() if len(ps) > 1]
if dups:
    refuse("%d game(s) are present at more than one path -- scoring this pool "
           "would count them twice" % len(dups),
           [" == ".join(ps) for ps in dups[:10]] +
           (["... and %d more" % (len(dups) - 10)] if len(dups) > 10 else []) +
           ["delete the redundant copy; do not let this tool guess which one you meant"])

# R2: per DIRECTORY, which seeds appear under a still-raw tag basename.
seeds_per_dir = {}
for f, a in loaded.items():
    m = STAMP_SEED.match(a.get("script_version") or "")
    if m and RAW_TAG_BASENAME.match(os.path.basename(f)):
        seeds_per_dir.setdefault(os.path.dirname(f) or ".", set()).add(m.group(1))
pooled_dirs = sorted((d, sorted(s)) for d, s in seeds_per_dir.items() if len(s) > 1)
if pooled_dirs and not allow_pooled:
    refuse("a flattened multi-run pool: one directory holds raw tag basenames "
           "from %d seeds" % sum(len(s) for _, s in pooled_dirs),
           ["%s  seeds=%s" % (d, ",".join(s)) for d, s in pooled_dirs] +
           ["one run carries one seed, so these came from >1 run and `cp` has "
            "already had the chance to overwrite games silently (W14: 208 -> 188)",
            "give each run its own subdirectory and point this tool at the parent",
            "or pass --allow-pooled-basenames if this layout is safe by other means"])
if pooled_dirs and allow_pooled:
    sys.stderr.write("--allow-pooled-basenames: R2 SKIPPED, NOT PASSED. "
                     "Losslessness of %d pooled director%s is UNVERIFIED.\n"
                     % (len(pooled_dirs), "y" if len(pooled_dirs) == 1 else "ies"))

games = list(loaded.values())

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
     "recovered_locally": True, "per_seed": rows, "mean": {}, "comps_better": {},
     # [GH #225] The input census, printed every run.  `scored_games` alone
     # could never expose a lossy download because no wave has an expected
     # count to compare it against; `files_seen` CAN be reconciled against the
     # S3 object count by the caller, and `source_dirs` says whether the pool
     # was flattened.  A number you can check beats a number you must trust.
     "input": {"files_seen": len(paths), "games_loaded": len(games),
               "source_dirs": len(set(os.path.dirname(f) for f in loaded)),
               "unparseable": len(unparseable),
               "pooled_basename_dirs_overridden": len(pooled_dirs) if allow_pooled else 0}}
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
