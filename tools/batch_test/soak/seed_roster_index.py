#!/usr/bin/env python3
"""seed -> roster index, built from the per-game `analysis.json` already in S3.

Why this exists (director test_set.md **V.6**, 2026-08-20T21:00Z): every
hero-specific soak candidate (`blinkflee` needs a blink carrier, `liondrainstop`
needs Lion, `cmrguard` needs CM) can only buy condition-(a) evidence if the
drafted roster contains its carrier -- and seed picking has so far been blind
("896 has Lion" was found by accident).  `seed_draft.py` answers the *forward*
question analytically for any seed; this tool answers the two questions only the
S3 archive can answer:

  1. **ground truth** -- which roster did a seed *actually* draft in the games we
     already paid for (independent of the Lua port in `seed_draft.py`), and
  2. **corpus census** -- how many banked games (and on which candidate side)
     exist for that seed *right now*, i.e. what a zero-spend re-read can use.

It reads only `*.analysis.json` (a few KB each), never the `.dem` files, so a
full rebuild costs a fraction of a cent in GETs and no EC2 time at all.

Stamp convention (see `recover_verdict.py`): the per-game `script_version` field
is `mirror:<cand>:s<seed>:<side>` for a validation game and the bare tree SHA for
a warm-up game.  Warm-up games carry no seed and are counted separately.

Usage:
  seed_roster_index.py --build              # incremental: only new run prefixes
  seed_roster_index.py --build --full       # rescan every run prefix
  seed_roster_index.py --seed 888 906       # rosters (+ banked game counts)
  seed_roster_index.py --find lion          # which banked seeds contain Lion
  seed_roster_index.py --find lion,zuus     # ... contain both
  seed_roster_index.py --find axe,earthshaker,obsidian_destroyer --min 2   # >=2 of them
  seed_roster_index.py --verify             # index vs seed_draft.py derivation
  seed_roster_index.py --summary            # corpus census, one line per seed
"""
import argparse
import concurrent.futures
import json
import os
import re
import sys
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
INDEX_PATH = os.path.join(REPO, "iterations", "data", "seed_roster_index.json")
BUCKET = "dota2bot-batch-results-4924"
PREFIX = "soak/"
CA_BUNDLE = "/root/.ccr/ca-bundle.crt"
STAMP_RE = re.compile(r"^mirror:(?P<cand>.*):s(?P<seed>\d+):(?P<side>radiant|dire)$")

_tls = threading.local()


def canon(hero):
    """`npc_dota_hero_lion` -> `lion` (the canon form used by seed_draft.py)."""
    return (hero or "").replace("npc_dota_hero_", "")


def client():
    """A per-thread S3 client with the same hygiene as the `awsx` wrapper:
    the agent proxy injects placeholder AWS_* env vars that shadow the real key,
    and TLS goes through the proxy CA bundle."""
    c = getattr(_tls, "s3", None)
    if c is None:
        try:
            import botocore.session
        except ImportError:
            # `session_setup.sh` installs aws-cli v1, which ships botocore
            # vendored under `awscli.` and does NOT expose a top-level botocore.
            from awscli import botocore
            from awscli.botocore import session  # noqa: F401
            sys.modules.setdefault("botocore", botocore)
        for var in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN"):
            os.environ.pop(var, None)
        kw = {}
        if os.path.exists(CA_BUNDLE):
            kw["verify"] = CA_BUNDLE
        c = botocore.session.get_session().create_client("s3", **kw)
        _tls.s3 = c
    return c


def list_analysis_keys():
    """All `*.analysis.json` keys under soak/, grouped by run prefix."""
    runs = {}
    paginator = client().get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET, Prefix=PREFIX):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if not key.endswith(".analysis.json"):
                continue
            run = key[len(PREFIX):].split("/")[0]
            runs.setdefault(run, []).append(key)
    return runs


def fetch(key):
    body = client().get_object(Bucket=BUCKET, Key=key)["Body"].read()
    return json.loads(body)


def load_index():
    if os.path.exists(INDEX_PATH):
        with open(INDEX_PATH) as fh:
            return json.load(fh)
    return {"source": "s3://%s/%s" % (BUCKET, PREFIX), "runs_scanned": [],
            "seeds": {}, "hero_index": {}}


def save_index(idx):
    os.makedirs(os.path.dirname(INDEX_PATH), exist_ok=True)
    idx["hero_index"] = build_hero_index(idx["seeds"])
    idx["runs_scanned"] = sorted(idx["runs_scanned"])
    with open(INDEX_PATH, "w") as fh:
        json.dump(idx, fh, indent=1, sort_keys=True)
        fh.write("\n")


def build_hero_index(seeds):
    out = {}
    for seed, rec in seeds.items():
        for hero in rec["radiant"] + rec["dire"]:
            out.setdefault(hero, []).append(int(seed))
    return {h: sorted(set(v)) for h, v in sorted(out.items())}


def merge_game(idx, run, game):
    """Fold one analysis.json into the index. Returns 'seeded'|'warmup'|'skip'.

    A seed is supposed to pin exactly one roster (`ApplySoakDraft` derives the
    draft from the seed so both team VMs agree).  Games that disagree are NOT
    dropped: every distinct roster is kept as a variant with its own game count,
    the majority variant becomes the seed's roster, and the rest are reported as
    `off_roster_games` -- those are games where the soak draft did not take.
    """
    stamp = game.get("script_version") or ""
    m = STAMP_RE.match(stamp)
    if not m:
        return "warmup" if stamp else "skip"
    seed, side, cand = m.group("seed"), m.group("side"), m.group("cand")
    roster = {"radiant": [], "dire": []}
    for p in game.get("players", []):
        team = p.get("team")
        if team in roster:
            roster[team].append(canon(p.get("hero")))
    if len(roster["radiant"]) != 5 or len(roster["dire"]) != 5:
        return "skip"
    for t in roster:
        roster[t].sort()

    rec = idx["seeds"].setdefault(seed, {"variants": [], "runs": [], "cands": []})
    for var in rec["variants"]:
        if var["radiant"] == roster["radiant"] and var["dire"] == roster["dire"]:
            break
    else:
        var = {"radiant": roster["radiant"], "dire": roster["dire"], "games": 0,
               "games_by_cand_side": {"radiant": 0, "dire": 0}, "runs": []}
        rec["variants"].append(var)
    var["games"] += 1
    var["games_by_cand_side"][side] += 1
    if run not in var["runs"]:
        var["runs"].append(run)
    if run not in rec["runs"]:
        rec["runs"].append(run)
    if cand not in rec["cands"]:
        rec["cands"].append(cand)
    return "seeded"


def finalize(idx):
    """Promote each seed's majority roster variant to the seed's roster."""
    for seed, rec in idx["seeds"].items():
        variants = sorted(rec["variants"], key=lambda v: -v["games"])
        rec["variants"] = variants
        top = variants[0]
        rec["radiant"] = top["radiant"]
        rec["dire"] = top["dire"]
        rec["games"] = top["games"]
        rec["games_by_cand_side"] = top["games_by_cand_side"]
        rec["off_roster_games"] = sum(v["games"] for v in variants[1:])
    idx["off_roster_total"] = sum(r["off_roster_games"] for r in idx["seeds"].values())
    idx["off_roster_seeds"] = sorted((s for s, r in idx["seeds"].items()
                                      if r["off_roster_games"]), key=int)


def annotate_positions(idx):
    """Attach the drafted position of each hero, derived by `seed_draft.py`.

    Positions are NOT in `analysis.json` (`team_slot` carries per-game engine
    entropy, not the role -- see seed_draft.py), so they come from the offline
    port.  Each seed is marked `positions_verified` only when that same port
    reproduces the S3 roster hero-for-hero; if it does not, the positions are
    dropped rather than guessed.
    """
    sys.path.insert(0, HERE)
    try:
        import seed_draft
    except Exception as exc:
        print("[build] seed_draft.py unavailable (%s); positions not annotated" % exc)
        return
    pool = seed_draft.load_pool()
    verified = 0
    for seed, rec in idx["seeds"].items():
        rad, dire = seed_draft.draft(int(seed), pool)
        derived = {"radiant": sorted(canon(h) for h in rad.values()),
                   "dire": sorted(canon(h) for h in dire.values())}
        match = derived["radiant"] == rec["radiant"] and derived["dire"] == rec["dire"]
        rec["positions_verified"] = match
        if match:
            verified += 1
            rec["positions"] = {canon(h): p for p, h in list(rad.items()) + list(dire.items())}
        else:
            rec.pop("positions", None)
    print("[build] positions annotated for %d/%d seeds (port reproduces the S3 roster)"
          % (verified, len(idx["seeds"])))


def cmd_build(args):
    idx = load_index()
    if args.full:
        idx = {"source": idx["source"], "runs_scanned": [], "seeds": {},
               "hero_index": {}}
    known = set(idx["runs_scanned"])
    runs = list_analysis_keys()
    todo = {r: k for r, k in runs.items() if r not in known}
    print("[build] %d run prefixes in S3, %d already indexed, %d to scan"
          % (len(runs), len(runs) - len(todo), len(todo)))
    if not todo:
        print("[build] nothing new; index unchanged")
        return 0
    keys = [(r, k) for r, ks in sorted(todo.items()) for k in sorted(ks)]
    print("[build] fetching %d analysis.json ..." % len(keys))
    counts = {"seeded": 0, "warmup": 0, "skip": 0, "error": 0}
    lock = threading.Lock()

    def work(item):
        run, key = item
        try:
            return run, fetch(key), None
        except Exception as exc:  # keep going; report at the end
            return run, None, exc

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for n, (run, game, exc) in enumerate(pool.map(work, keys), 1):
            if exc is not None:
                counts["error"] += 1
                continue
            with lock:
                counts[merge_game(idx, run, game)] += 1
            if n % 2000 == 0:
                print("  ... %d/%d" % (n, len(keys)))
    idx["runs_scanned"] = sorted(known | set(todo))
    finalize(idx)
    annotate_positions(idx)
    save_index(idx)
    print("[build] games: %d seeded, %d warm-up, %d unusable, %d fetch errors"
          % (counts["seeded"], counts["warmup"], counts["skip"], counts["error"]))
    print("[build] %d seeds, %d distinct heroes -> %s"
          % (len(idx["seeds"]), len(idx["hero_index"]), INDEX_PATH))
    print("[build] off-roster games (soak draft did not take): %d across %d seeds"
          % (idx["off_roster_total"], len(idx["off_roster_seeds"])))
    for seed in idx["off_roster_seeds"]:
        rec = idx["seeds"][seed]
        print("  seed %-7s %d off-roster / %d on-roster  (%d roster variants)"
              % (seed, rec["off_roster_games"], rec["games"], len(rec["variants"])))
    return 0


def show_seed(idx, seed):
    rec = idx["seeds"].get(str(seed))
    if rec is None:
        print("seed %s: no banked games" % seed)
        return
    print("seed %s: %d banked games (cand-radiant %d / cand-dire %d), %d runs"
          % (seed, rec["games"], rec["games_by_cand_side"]["radiant"],
             rec["games_by_cand_side"]["dire"], len(rec["runs"])))
    pos = rec.get("positions") or {}
    for team in ("radiant", "dire"):
        cells = ["%s%s" % (h, ("(p%d)" % pos[h]) if h in pos else "") for h in rec[team]]
        print("  %-7s: %s" % (team, " ".join(cells)))
    if not rec.get("positions_verified", False):
        print("  (positions unavailable: seed_draft.py does not reproduce this roster)")


def cmd_seed(args):
    idx = load_index()
    for s in args.seed:
        show_seed(idx, s)
    return 0


def cmd_find(args):
    idx = load_index()
    wanted = [canon(h.strip()) for h in args.find.split(",") if h.strip()]
    need = args.min or len(wanted)          # default: every named hero must be there
    hits = []
    for seed, rec in idx["seeds"].items():
        roster = set(rec["radiant"]) | set(rec["dire"])
        present = [h for h in wanted if h in roster]
        if len(present) >= need:
            hits.append((int(seed), rec, present))
    if not hits:
        print("no banked seed has >=%d of: %s" % (need, ", ".join(wanted)))
        print("(banked seeds only -- use seed_draft.py --find to search unplayed seeds)")
        return 1
    for seed, rec, present in sorted(hits, key=lambda x: (-len(x[2]), -x[1]["games"])):
        side = "radiant" if set(present) <= set(rec["radiant"]) else (
            "dire" if set(present) <= set(rec["dire"]) else "split")
        pos = rec.get("positions") or {}
        who = " ".join("%s%s" % (h, ("(p%d)" % pos[h]) if h in pos else "") for h in present)
        print("seed %-6s %4d banked games  side: %-7s  cand-radiant %3d / cand-dire %3d  %s"
              % (seed, rec["games"], side, rec["games_by_cand_side"]["radiant"],
                 rec["games_by_cand_side"]["dire"], who))
    return 0


def cmd_summary(args):
    idx = load_index()
    tot = 0
    for seed in sorted(idx["seeds"], key=int):
        rec = idx["seeds"][seed]
        tot += rec["games"]
        print("%-6s %4d games  r%3d/d%3d  %s | %s"
              % (seed, rec["games"], rec["games_by_cand_side"]["radiant"],
                 rec["games_by_cand_side"]["dire"],
                 " ".join(rec["radiant"]), " ".join(rec["dire"])))
    print("-- %d seeds, %d banked validation games, %d runs indexed"
          % (len(idx["seeds"]), tot, len(idx["runs_scanned"])))
    return 0


def cmd_verify(args):
    """Cross-check the S3 ground truth against seed_draft.py's offline port."""
    sys.path.insert(0, HERE)
    try:
        import seed_draft
    except Exception as exc:
        print("cannot import seed_draft.py: %s" % exc)
        return 2
    idx = load_index()
    pool = seed_draft.load_pool()
    ok = bad = 0
    for seed in sorted(idx["seeds"], key=int):
        rec = idx["seeds"][seed]
        rad, dire = seed_draft.draft(int(seed), pool)
        derived = {"radiant": sorted(canon(h) for h in rad.values()),
                   "dire": sorted(canon(h) for h in dire.values())}
        if derived["radiant"] == rec["radiant"] and derived["dire"] == rec["dire"]:
            ok += 1
        else:
            bad += 1
            print("MISMATCH seed %s" % seed)
            for t in ("radiant", "dire"):
                print("  %-8s s3=%s" % (t, " ".join(rec[t])))
                print("  %-8s py=%s" % ("", " ".join(derived[t])))
    print("-- seed_draft.py vs S3 ground truth: %d/%d seeds match, %d mismatch"
          % (ok, ok + bad, bad))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build", action="store_true", help="scan S3 and (re)build the index")
    ap.add_argument("--full", action="store_true", help="with --build: rescan every run prefix")
    ap.add_argument("--jobs", type=int, default=32, help="parallel S3 GETs (default 32)")
    ap.add_argument("--seed", nargs="+", type=int, help="show the roster of these seeds")
    ap.add_argument("--find", help="comma-separated heroes; print banked seeds containing all")
    ap.add_argument("--min", type=int, help="with --find: seeds containing at least N of them")
    ap.add_argument("--summary", action="store_true", help="one line per banked seed")
    ap.add_argument("--verify", action="store_true", help="index vs seed_draft.py derivation")
    args = ap.parse_args()
    if args.build:
        return cmd_build(args)
    if args.seed:
        return cmd_seed(args)
    if args.find:
        return cmd_find(args)
    if args.summary:
        return cmd_summary(args)
    if args.verify:
        return cmd_verify(args)
    ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
