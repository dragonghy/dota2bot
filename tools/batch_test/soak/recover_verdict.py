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
# [GH #269] "BOTH waves present" was the whole gate, and it cannot tell
# `ba_games=1` from `ba_games=15`.  W19's seed 928 passed it with ab=41/ba=1,
# and because the seed reading is (ab + ba) / 2 -- each leg 50% regardless of
# depth -- ONE dire game decided half of that seed.  It moved the wave mean by
# 76.5 gpm (-23.4 with the sound seed alone, -99.9 with 928 folded in) while
# `scored_games`, `unfinished`, `per_seed`, `mean` and `suggested` all looked
# normal.  The only field that could show it was `ba_games` itself.  Third
# member of the family that fails toward danger (W14 basename collisions,
# W17-R's "non-empty per_seed != a usable seed"); the first two left READING
# advice, and this recurrence is the proof that reading advice is not a gate.
#
# THE GATE IS ON THE SEED'S ARM DEPTH, NOT ON min(ab, ba).  The estimator says
# which quantity to gate:  Var[(ab + ba) / 2] = (s^2/ab + s^2/ba) / 4
#                                             = s^2 / (2 * H),  H = 2ab/(ab+ba)
# -- the harmonic mean of the two leg counts.  So H is not a taste parameter
# dressed up: it is literally HOW MANY GAMES PER LEG THIS SEED IS WORTH, and a
# single threshold on it rejects both failure shapes that a raw min() needs two
# knobs for (a leg that is a rounding error, and two legs that are both thin).
# W19 separates cleanly: the poison seed is worth 1.95 games/leg, the sound one
# 21.5.  MIN_ARM_DEPTH = 8 sits between with margin on both sides, and (since
# H <= 2 * min(ab, ba)) it also guarantees the thin leg alone holds >= 4 games.
#
# Weighting the legs by game count instead (option B of #269) is refused on
# arithmetic, not taste: the two-wave average exists to cancel the ~+1.5k
# Radiant side bias (CLAUDE.md), and 41:1 weighting turns the seed back into an
# un-swapped single-side read -- it does not merely hide the thin arm, it
# reinstates the bug the average was built to prevent.
#
# REVISION CONDITION, registered so lowering the number is never quiet: if a
# wave is ever zeroed BY THIS GATE (>= 2 seeds have both legs non-empty and all
# of them fall below the threshold), that is a report about the wave's shape,
# not a reason to lower MIN_ARM_DEPTH.
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

# [GH #269] Keep this literal in sync with validate_onspot.sh's embedded copy
# (tests/test_verdict_arm_depth.py asserts both carry the same number): the
# farm's happy path runs THAT copy, so a gate that lives only here is a gate
# the farm does not have.
MIN_ARM_DEPTH_DEFAULT = 8
min_arm_depth = MIN_ARM_DEPTH_DEFAULT
if "--min-arm-depth" in argv:
    i = argv.index("--min-arm-depth")
    if i + 1 >= len(argv):
        sys.exit("--min-arm-depth needs a value (games per leg, default %d)"
                 % MIN_ARM_DEPTH_DEFAULT)
    try:
        min_arm_depth = float(argv[i + 1])
    except ValueError:
        sys.exit("--min-arm-depth takes a number, got %r" % argv[i + 1])
    if min_arm_depth < MIN_ARM_DEPTH_DEFAULT:
        # Same discipline as --allow-pooled-basenames: an override announces
        # that it is a SKIP, not a pass, so the line can be quoted in a report.
        sys.stderr.write(
            "--min-arm-depth %g LOWERED from the default %d: thin-arm seeds "
            "are being SCORED. This is a SKIP of the GH #269 gate, NOT a pass.\n"
            % (min_arm_depth, MIN_ARM_DEPTH_DEFAULT))


def arm_depth(ab, ba):
    """Games-per-leg this seed is worth: harmonic mean of the two leg counts.

    Var[(ab+ba)/2] == s^2 / (2 * arm_depth), so this is the depth of the
    balanced pair that would read as precisely as this unbalanced one.  0 when
    either leg is empty (there is no pair to be worth anything).
    """
    return (2.0 * ab * ba / (ab + ba)) if (ab and ba) else 0.0

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
    # [GH #269] Published on EVERY row, scored or not -- the failure this
    # replaces was invisible precisely because the row carried no field that
    # said how thin it was.
    row["arm_depth"] = round(arm_depth(len(AB), len(BA)), 2)
    if not (AB and BA):
        row["scored"] = False
        row["excluded"] = "NO-PAIR"
    elif row["arm_depth"] < min_arm_depth:
        row["scored"] = False
        row["excluded"] = "THIN-ARM"
    else:
        row["scored"] = True
    if row["scored"]:
        for m in ("gpm", "xpm", "deaths", "last_hits"):
            ab = M([sv(a, "radiant", m) for a in AB]) - M([sv(a, "dire", m) for a in AB])
            ba = M([sv(a, "dire", m) for a in BA]) - M([sv(a, "radiant", m) for a in BA])
            row[m] = round((ab + ba) / 2, 2)
            # [GH #329, rule 4(i)-a] The two STRATUM READINGS, published beside
            # the swap-average that consumed them.  Before this the row carried
            # `ab_games`/`ba_games` -- COUNTS -- and rule 4(i) asks for READINGS,
            # so six rounds satisfied it with the wrong quantity and the seventh
            # satisfied it by recomputing these numbers BY HAND off the corpus.
            # The hand step is the hazard, not the omission: the natural way to
            # pool 275 ab games against 137 ba games by hand is to weight by
            # game count, and that puts (275-137)/412 = 0.335 of the side term
            # straight into the answer -- on W27+W28 that is -17.40 gpm on a
            # +26.60 reading, two thirds of the effect, with nothing out of
            # place to look at.  A number the tool refuses to print is a number
            # somebody computes some other way.
            row[m + "_ab"] = round(ab, 2)
            row[m + "_ba"] = round(ba, 2)
    # [GH #269] The census is computed for every PAIRED seed, scored or not.
    # Before the depth gate "paired" and "scored" were the same predicate, so
    # leaving it inside the scored branch would silently withdraw the game
    # counts from exactly the waves the gate exists to expose -- the gate would
    # take the evidence for itself down with it.
    if AB and BA:
        # same two-wave average as the economy metrics, for the same reason
        # (it cancels the ~+1.5k Radiant side bias, CLAUDE.md).
        ab_w, ab_n = wr(AB, "radiant")
        ba_w, ba_n = wr(BA, "dire")
        row["scored_games"] = ab_n + ba_n
        row["unfinished"] = (len(AB) - ab_n) + (len(BA) - ba_n)
        # [GH #269] SECOND instance of the same defect in this same function:
        # the winrate legs are the FINISHED counts, which can be far thinner
        # than the leg counts already gated above (a seed with 41/15 games can
        # carry a single finished dire game), and `if ab_n and ba_n` is the
        # very predicate #269 says cannot tell 1 from 15.  Same estimator, same
        # 50/50 average, so the same depth gate applies -- measured on its own
        # denominators, never inherited from the economy gate.  No `scored`
        # check is needed here and none is implied: finished counts are <= leg
        # counts, so winrate_arm_depth <= arm_depth always, and a seed the
        # economy gate rejected can never pass this one.
        row["winrate_arm_depth"] = round(arm_depth(ab_n, ba_n), 2)
        if row["winrate_arm_depth"] >= min_arm_depth:
            row["winrate"] = round(((ab_w / ab_n) + (ba_w / ba_n)) / 2, 3)
        elif ab_n and ba_n:
            row["winrate_excluded"] = "THIN-ARM"
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

# [GH #329, rule 4(i)-a/-c] The wave-level stratum readings and the side term.
#
# `side` is the nuisance parameter the swap-average exists to cancel:
#     arm = (ab + ba)/2      side = (ab - ba)/2
# so `ab` and `ba` carry opposite signs EXACTLY when |side| > |arm|.  That is an
# identity, not a diagnosis -- which is the whole content of the #329 ruling.
# `sign_flip` is therefore published as a DISCLOSURE, never as a verdict: it
# says the lineups this wave drew favour one physical side harder than the fix
# moves the metric, and it says nothing whatever about how precisely `arm` is
# measured (a fix with arm == +26.60 on every single seed would flip here too).
# The quantity that does speak to precision is the across-seed spread of `arm`
# itself, which is `mean` + `comps_better` + the #269 depth gate, above.
v["strata"] = {}
for m in ("gpm", "xpm", "deaths", "last_hits"):
    pairs = [(r[m + "_ab"], r[m + "_ba"]) for r in complete
             if m + "_ab" in r and m + "_ba" in r]
    if not pairs:
        continue
    ab_m = statistics.mean(a for a, _ in pairs)
    ba_m = statistics.mean(b for _, b in pairs)
    v["strata"][m] = {
        "ab": round(ab_m, 2), "ba": round(ba_m, 2),
        "side": round((ab_m - ba_m) / 2, 2),
        # `ab*ba < 0` rather than a sign comparison, because that IS the
        # identity: |side| > |arm|  <=>  (ab-ba)^2 > (ab+ba)^2  <=>  ab*ba < 0.
        # A stratum reading of exactly 0 is |side| == |arm|, not a flip, and a
        # `(ab > 0) != (ba > 0)` spelling calls it one.
        "sign_flip": ab_m * ba_m < 0,
        "side_gt_arm": "%d/%d" % (sum(1 for a, b in pairs
                                      if abs(a - b) > abs(a + b)), len(pairs)),
    }

# winrate is a rate, not a delta: neutral is 0.5, not 0.  Kept out of the loop
# above so the ">0 is better" convention there stays literally true.
wrs = [r["winrate"] for r in rows if "winrate" in r]
if wrs:
    v["mean"]["winrate"] = round(statistics.mean(wrs), 3)
    v["comps_better"]["winrate"] = "%d/%d" % (sum(1 for x in wrs if x > 0.5), len(wrs))
    v["winrate_neutral"] = 0.5
# [GH #269] The census hangs off "a wave was counted", NOT off "a winrate
# survived the gate".  Left coupled to `wrs`, a wave of nothing but thin seeds
# -- the exact shape this gate exists to expose -- would print no game counts
# at all, so the gate would take the evidence for itself down with it.
if any("scored_games" in r for r in rows):
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

# [GH #269] The exclusion is published at the top level, not left for a reader
# to reconstruct from per-seed rows.  `ba_games` was already the only field
# that could show the W19 defect, and nobody reads a per-seed field they have
# no reason to suspect.
v["min_arm_depth"] = min_arm_depth
v["thin_arm_seeds"] = [{"seed": r["seed"], "ab_games": r["ab_games"],
                        "ba_games": r["ba_games"], "arm_depth": r["arm_depth"]}
                       for r in rows if r.get("excluded") == "THIN-ARM"]
v["thin_arm_winrate_seeds"] = [r["seed"] for r in rows
                               if r.get("winrate_excluded") == "THIN-ARM"]
if v["thin_arm_seeds"]:
    sys.stderr.write(
        "GH #269 depth gate: %d seed(s) EXCLUDED from the mean as THIN-ARM "
        "(arm_depth < %g games/leg): %s\n"
        % (len(v["thin_arm_seeds"]), min_arm_depth,
           ", ".join("s%s(ab=%d,ba=%d,depth=%.2f)"
                     % (r["seed"], r["ab_games"], r["ba_games"], r["arm_depth"])
                     for r in v["thin_arm_seeds"])))
# The registered revision condition (see the header): a wave zeroed BY THIS
# GATE is a report about the wave, not an argument for a smaller number.
paired = [r for r in rows if r.get("excluded") != "NO-PAIR"]
if len(paired) >= 2 and not complete:
    sys.stderr.write(
        "GH #269 depth gate: WAVE ZEROED BY THE GATE -- %d paired seeds, none "
        "at %g games/leg. Report the wave's shape; do NOT lower the gate.\n"
        % (len(paired), min_arm_depth))

g = v["mean"].get("gpm"); d = v["mean"].get("deaths")
v["suggested"] = ("promote" if (g is not None and g > 5 and complete and
    int(v["comps_better"]["gpm"].split('/')[0]) * 2 > len(complete) and (d is None or d <= 0))
    else "hold_or_reject")
print(json.dumps(v, indent=1))
