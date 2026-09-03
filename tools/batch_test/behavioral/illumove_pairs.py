#!/usr/bin/env python3
"""`illumove` condition (a): do two controlled units of one owner BOTH move?

WHY THIS FILE EXISTS
--------------------
GH #378 §1: `X.MoveUnitsToLocation` (bots/BotLib/minion_lib/illusions.lua)
keeps ONE module-local handle.  With two controlled units alive at the same
time, the un-gated shape lets a single unit own that handle for seconds at a
stretch while its sibling stands still; the `illumove` candidate adds a
per-unit clock so both keep receiving move orders.

Replay-check 2026-09-01T18:49Z bought condition (a) for `illumove` on W35
with exactly this reading (frame by frame first, then the census), but the
census was an ad-hoc script that died with the container -- so the very next
round had to rebuild it from the report.  This file is that script, in the
tree, so a replication is a re-run and not a re-derivation.

WHAT IT MEASURES (and what it deliberately does NOT)
----------------------------------------------------
For every frame where >=2 illusions of the SAME owner are alive, each unit's
own displacement since its own previous frame is bucketed:

  both     min(dx) >= BOTH_U            -- both units are taking orders
  starved  max(dx) >= BOTH_U and min(dx) < STARVE_U   <- THE SHAPE
  neither  everything else (a fight, a stand-off, both idle)

The asymmetry is BETWEEN SIBLINGS, so the owner's own pathing is a common
term that cancels in the comparison -- that is the whole reason this estimator
is readable at all without a counterfactual.

It is NOT an effect size.  It buys rule-2 condition (a) ("does the change
actually execute and behave correctly"), never condition (b).

⭐ IDENTITY (GH #176).  A hero NAME is not an entity key: an illusion carries
the same `hero` string and the same `player_id`, differing only in `idx`.
The owner is the idx with the EARLIEST first appearance (heroes exist before
the horn, illusions never do); every other idx of that name is a copy.  That
is the same lock `stayfield_domain.Game` uses, restated here because this tool
needs the copies that Game throws away.

⭐ THE CARRIER IS THE ILLUSION RUNE, NOT A SUMMONING ABILITY (replay-check
2026-09-01T18:49Z).  W35's corpus had zero summon abilities and zero
manta/necronomicon purchases, yet 24 two-unit windows: `modifier_illusion`
ADD x2 with no accompanying ABILITY/ITEM event.  Check the modifier before
concluding a corpus has no domain for a `minion_lib/` id.

铁律 4(i-a)/(i-b): this is a COUNT with the physical-side term still in it.
All four (stratum x leg) cells are printed and none of them is ever
subtracted from another.  The judgement rule is "opposite signs across the two
strata = noise"; same-sign in both strata, with the reading tracking the ARM
leg rather than the physical side, is what makes it citable.

Usage:
    illumove_pairs.py <sweep_dir> [...]            # the four cells
    illumove_pairs.py <sweep_dir> [...] --episodes # per-episode longest starve
    illumove_pairs.py <sweep_dir> [...] --frames [--limit N]
    illumove_pairs.py <sweep_dir> [...] --hp-cut 0.40   # DC.3(甲) intersection
    illumove_pairs.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from stayfield_domain import SIDE_TEAM, canon, load_sweeps      # noqa: E402

# --- this tool's own constants.  NO GATE READS THESE. --------------------
# They are the operational definition of "was this unit taking orders this
# second", chosen at 1 Hz to match the 18:49Z hand reading (siblings walked at
# 250-380 u/s; a starved unit's coordinates were byte-identical frame to
# frame).  Exposed as flags so a reader can see how sensitive the headline is.
BOTH_U = 100.0      # moved this far in one frame => it is walking
STARVE_U = 20.0     # moved less than this => it is standing still
EPS = 1e-6

# --- MIRROR, not this tool's own.  ---------------------------------------
# The one number above the line that is NOT chosen here: it reproduces the
# owner-hp clause of the branch `illureal` opens
# (bots/FunLib/minion_lib/illusions.lua, X.ConfuseEnemyWithIllusions:
# `J.GetHP(bot) < 0.4`).  It is the intersection bound -- below it the shipped
# confuse branch is also steering the unit, so a starvation reading there is
# not attributable to the gate.  Move the Lua and this must move with it;
# tests/test_detector_source_constants.py pins the pair (HP_CENSUS: MIRROR).
HP_CUT = 0.40


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


class Units(object):
    """One timeline, keyed by (hero, idx), with the owner idx identified."""

    def __init__(self, path, interval):
        d = json.load(open(path))
        self.interval = interval
        self.streams = collections.defaultdict(list)     # (hero, idx) -> frames
        for s in d["snapshots"]:
            if "idx" not in s:
                sys.exit("FATAL: timeline has no snapshot idx; cannot key entities")
            self.streams[(canon(s["hero"]), s["idx"])].append(s)
        for v in self.streams.values():
            v.sort(key=lambda s: s["t"])

        first_t = {k: v[0]["t"] for k, v in self.streams.items()}
        owner = {}
        for (hero, idx), t0 in first_t.items():
            if hero not in owner or t0 < owner[hero][1]:
                owner[hero] = (idx, t0)
        self.owner_idx = {h: v[0] for h, v in owner.items()}
        self.copies = collections.defaultdict(list)      # hero -> [idx, ...]
        for (hero, idx) in self.streams:
            if idx != self.owner_idx[hero]:
                self.copies[hero].append(idx)

        self.team = {}
        for (hero, idx), fr in self.streams.items():
            if idx == self.owner_idx[hero]:
                self.team[hero] = fr[0]["team"]

        # `modifier_illusion` ADDs, purely to report what the carrier was.
        self.illu_add = collections.Counter()
        for e in d["events"]:
            if e.get("type") == "MODIFIER_ADD" and e.get("inflictor") == "modifier_illusion":
                self.illu_add[canon(e.get("target") or "")] += 1

    def owner_hp(self, hero, t):
        """Owner hp at EXACTLY t, or None.  Never interpolated (GH #176 #2)."""
        for s in self.streams[(hero, self.owner_idx[hero])]:
            if abs(s["t"] - t) < EPS:
                return s["hp_pct"]
        return None


def episodes(u, hero):
    """Maximal runs of frames where >=2 copies of `hero` are alive at once."""
    alive = collections.defaultdict(dict)      # t -> idx -> frame
    prev = collections.defaultdict(dict)       # t -> idx -> previous frame
    for idx in u.copies[hero]:
        fr = u.streams[(hero, idx)]
        for i, s in enumerate(fr):
            if s["hp_pct"] <= 0:
                continue
            alive[s["t"]][idx] = s
            if i > 0 and s["t"] - fr[i - 1]["t"] <= u.interval + EPS \
                    and fr[i - 1]["hp_pct"] > 0:
                prev[s["t"]][idx] = fr[i - 1]
    times = sorted(t for t, m in alive.items() if len(m) >= 2)
    out, cur = [], []
    for t in times:
        if cur and t - cur[-1] > u.interval + EPS:
            out.append(cur)
            cur = []
        cur.append(t)
    if cur:
        out.append(cur)
    return [[{"t": t, "units": alive[t], "prev": prev.get(t, {})} for t in ep]
            for ep in out]


def classify(frame, both_u, starve_u):
    """`both` / `starved` / `neither`, or None when a dx is unknown.

    A frame whose units do not all have a same-interval predecessor is NOT
    guessed at -- it is returned as None and counted separately.  Filling a
    missing dx with 0 would manufacture `starved`, i.e. push toward the
    finding.
    """
    dxs = {}
    for idx, s in frame["units"].items():
        p = frame["prev"].get(idx)
        if p is None:
            return None, {}
        dxs[idx] = dist(p["x"], p["y"], s["x"], s["y"])
    mx, mn = max(dxs.values()), min(dxs.values())
    if mn >= both_u:
        return "both", dxs
    if mx >= both_u and mn < starve_u:
        return "starved", dxs
    return "neither", dxs


def rows(games, args):
    """One row per pair-frame, tagged with stratum and leg.

    `--exclude-lowhp` drops every frame whose owner is below `--hp-cut`, i.e.
    the whole UPPER bound of `illureal`'s domain, in BOTH legs.  W35's corpus
    made this moot (the intersection was 0 frames); W36's does not, so the
    headline has to be shown to survive deleting the overlap rather than
    argued to be unaffected by it.
    """
    out, eps_out = [], []
    for run, game, _cand, _seed, side, tl in games:
        u = Units(tl, args.interval)
        armed_team = SIDE_TEAM[side]
        for hero in sorted(u.copies):
            for ep in episodes(u, hero):
                ep_rows = []
                for f in ep:
                    kind, dxs = classify(f, args.both_u, args.starve_u)
                    ohp = u.owner_hp(hero, f["t"])
                    if getattr(args, "exclude_lowhp", False) \
                            and ohp is not None and ohp < args.hp_cut:
                        continue
                    ep_rows.append({
                        "run": run, "game": game, "hero": hero, "t": f["t"],
                        "n_units": len(f["units"]), "kind": kind, "dxs": dxs,
                        "ohp": ohp,
                        "stratum": "ab" if side == "radiant" else "ba",
                        "leg": ("armed" if u.team[hero] == armed_team
                                else "baseline"),
                    })
                if not ep_rows:
                    continue
                run_len, best = 0, 0
                for r in ep_rows:
                    run_len = run_len + 1 if r["kind"] == "starved" else 0
                    best = max(best, run_len)
                eps_out.append({
                    "run": run, "game": game, "hero": hero,
                    "t0": ep_rows[0]["t"], "t1": ep_rows[-1]["t"],
                    "frames": len(ep_rows), "longest_starve_s": best * args.interval,
                    "stratum": ep_rows[0]["stratum"], "leg": ep_rows[0]["leg"],
                    "illu_add": u.illu_add.get(hero, 0),
                })
                out.extend(ep_rows)
    return out, eps_out


def cells(items):
    return [(s + "/" + l, [r for r in items if r["stratum"] == s and r["leg"] == l])
            for s in ("ab", "ba") for l in ("armed", "baseline")]


def pct(n, d):
    return (100.0 * n / d) if d else float("nan")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--both-u", type=float, default=BOTH_U)
    ap.add_argument("--starve-u", type=float, default=STARVE_U)
    ap.add_argument("--hp-cut", type=float, default=HP_CUT)
    ap.add_argument("--episodes", action="store_true")
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument("--exclude-lowhp", action="store_true",
                    help="drop frames with owner hp < --hp-cut in BOTH legs")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args()

    games = load_sweeps(args.dirs)
    fr, eps = rows(games, args)

    print("illumove_pairs -- >=2 controlled units of one owner alive on one frame")
    print("  games swept: %d | pair-frames: %d | episodes: %d"
          % (len(games), len(fr), len(eps)))
    print("  thresholds: both>=%.0fu  starved: max>=%.0fu and min<%.0fu  (1/%.1fs)"
          % (args.both_u, args.both_u, args.starve_u, args.interval))
    print("  NOT an effect size.  Buys rule-2 condition (a) only.")
    if args.exclude_lowhp:
        print("  --exclude-lowhp: owner hp < %.2f dropped in BOTH legs"
              " (the whole UPPER bound of `illureal`'s domain)" % args.hp_cut)
    print("")

    if args.frames:
        shown = 0
        for r in fr:
            if r["kind"] != "starved":
                continue
            print("%-34s %-18s t=%8.1f  %s  ohp=%s  dx=%s"
                  % (r["game"], r["hero"], r["t"], r["kind"],
                     ("%.3f" % r["ohp"]) if r["ohp"] is not None else "?",
                     " ".join("%d:%.0f" % (k, v) for k, v in sorted(r["dxs"].items()))))
            shown += 1
            if shown >= args.limit:
                break
        print("\n(%d starved frames total; showed %d)"
              % (sum(1 for r in fr if r["kind"] == "starved"), shown))
        return 0

    if args.episodes:
        for c, rs in cells(eps):
            print("-- %s: %d episode(s)" % (c, len(rs)))
            for e in sorted(rs, key=lambda e: -e["longest_starve_s"]):
                print("   %-30s %-18s t=%7.1f..%-7.1f frames=%3d longest_starve=%4.0fs"
                      % (e["game"], e["hero"], e["t0"], e["t1"], e["frames"],
                         e["longest_starve_s"]))
        return 0

    print("%-14s %6s %7s %8s %9s %9s %14s" % (
        "stratum/leg", "eps", "frames", "both%", "starved%", "neither%",
        "longest_starve"))
    for c, rs in cells(fr):
        ce = [e for e in eps if (e["stratum"] + "/" + e["leg"]) == c]
        cl = [r for r in rs if r["kind"] is not None]
        n = len(cl)
        print("%-14s %6d %7d %7.1f%% %8.1f%% %8.1f%% %11.0f s" % (
            c, len(ce), n,
            pct(sum(1 for r in cl if r["kind"] == "both"), n),
            pct(sum(1 for r in cl if r["kind"] == "starved"), n),
            pct(sum(1 for r in cl if r["kind"] == "neither"), n),
            max([e["longest_starve_s"] for e in ce] or [0])))
    unknown = sum(1 for r in fr if r["kind"] is None)
    multi = sum(1 for r in fr if r["n_units"] > 2)
    print("\n  frames with an unknown dx (no same-interval predecessor): %d"
          " -- excluded, never scored as starved" % unknown)
    print("  frames with >2 units alive: %d (scored by max/min, disclosed here)"
          % multi)

    print("\n-- episode-level separation (harder than a pooled percentage) --")
    for c, _rs in cells(fr):
        ce = [e for e in eps if (e["stratum"] + "/" + e["leg"]) == c]
        vals = sorted((e["longest_starve_s"] for e in ce), reverse=True)
        print("   %-14s n=%2d longest_starve per episode: %s"
              % (c, len(ce), ", ".join("%.0f" % v for v in vals) or "-"))

    print("\n-- DC.3(甲) intersection bound: pair-frames with owner hp < %.2f --"
          % args.hp_cut)
    for c, rs in cells(fr):
        live = [r for r in rs if r["ohp"] is not None]
        low = [r for r in live if r["ohp"] < args.hp_cut]
        print("   %-14s frames_with_owner_hp=%4d  of which hp<%.2f: %d"
              % (c, len(live), args.hp_cut, len(low)))
    print("   (`illureal` needs owner hp < %.2f AND retreating AND not"
          " dominant; the last two are unobservable here, so this count is an"
          " UPPER bound on the overlap.)" % args.hp_cut)

    print("\n-- carrier census: `modifier_illusion` ADDs per owner with copies --")
    car = collections.Counter()
    for e in eps:
        car[(e["run"], e["game"], e["hero"])] = e["illu_add"]
    with_mod = sum(1 for v in car.values() if v > 0)
    print("   owners with a two-unit episode: %d | of those carrying"
          " `modifier_illusion`: %d" % (len(car), with_mod))

    print("\n铁律 4(i-a): all four cells are printed above.  4(i-b): this count"
          "\n  still carries the physical-side term, so NEVER subtract one cell"
          "\n  from another; the readable question is whether both strata agree"
          "\n  in sign and whether the reading tracks the ARM leg.")
    return 0


def selfcheck(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--both-u", type=float, default=BOTH_U)
    ap.add_argument("--starve-u", type=float, default=STARVE_U)
    ap.add_argument("--hp-cut", type=float, default=HP_CUT)
    ap.add_argument("--exclude-lowhp", action="store_true")
    args = ap.parse_args(argv)
    games = load_sweeps(args.dirs)
    fr, eps = rows(games, args)
    bad = []

    def chk(name, ok, detail=""):
        print("  %-58s %s %s" % (name, "ok" if ok else "FAIL", detail))
        if not ok:
            bad.append(name)

    chk("every pair-frame has >=2 units alive",
        all(r["n_units"] >= 2 for r in fr))
    chk("every classified frame is in exactly one bucket",
        all(r["kind"] in ("both", "starved", "neither") for r in fr
            if r["kind"] is not None))
    chk("a frame with an unknown dx is never scored",
        all(r["kind"] is not None or not r["dxs"] for r in fr))
    chk("episode frame counts sum to the pair-frame count",
        sum(e["frames"] for e in eps) == len(fr),
        "%d vs %d" % (sum(e["frames"] for e in eps), len(fr)))
    chk("every episode is inside its own [t0, t1]",
        all(e["t0"] <= e["t1"] for e in eps))
    chk("longest starve <= episode length",
        all(e["longest_starve_s"] <= (e["t1"] - e["t0"]) + args.interval
            for e in eps))
    # The identity lock itself: a copy must not exist before the horn.
    pre_horn = 0
    for run, game, _c, _s, _side, tl in games:
        u = Units(tl, args.interval)
        for hero, idxs in u.copies.items():
            for idx in idxs:
                if u.streams[(hero, idx)][0]["t"] < 0:
                    pre_horn += 1
    chk("no copy stream starts before the horn (the idx lock)", pre_horn == 0,
        "%d violation(s)" % pre_horn)
    chk("every owner referenced by an episode has a team",
        all(e["hero"] for e in eps))
    print("\n%d of %d checks passed, %d rows" % (9 - len(bad), 9, len(fr)))
    return 2 if bad else 0


if __name__ == "__main__":
    if "--selfcheck" in sys.argv:
        sys.exit(selfcheck([a for a in sys.argv[1:]]))
    sys.exit(main())
