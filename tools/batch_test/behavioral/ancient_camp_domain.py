#!/usr/bin/env python3
"""Census of hero-vs-ANCIENT-camp engagements in behav-dump timelines.

WHY THIS EXISTS
---------------
2026-08-23T06:36Z replay-check saw a level-11 Wraith King with a
starting-item inventory walk from the fountain to the Radiant ancient camp,
stand still for 28 s trading with an Ancient Granite Golem + Ancient Rock
Golems, burn his salve at 62% HP, and finally TP home at 16.8% HP -- for
166 gold and 400 XP, with no enemy hero within 6,000 units the whole time.

That single episode is frame-evidence; this tool answers "how often".

WHAT IT MEASURES
----------------
An *episode* = a maximal run of DAMAGE events (either direction) between one
hero and any ancient-camp neutral, with gaps <= --gap seconds.  Per episode
it records the hero's level at engagement, the HP fraction burned, the gold
credited by ancient kills inside the episode, and how the episode ENDED
(walked off / TP'd home / died).

WHAT IT DOES *NOT* MEASURE
--------------------------
- It cannot see WHY the hero was there (farm mode vs. wandering into aggro).
  `t_first_taken` vs `t_first_dealt` is the only hint it offers: if the
  hero's own first hit lands before the camp's, he opened the fight.
- Attack damage is not in the dump, so the `bot:GetAttackDamage() <= 80`
  clause of aba_site.RefreshCamp cannot be evaluated; only level is.
- Neutral HP is not sampled, so "was the camp nearly dead" is unanswerable.

ANCIENT UNIT SET
----------------
Matched by name substring (printed in the summary with per-name counts so a
reader can audit the list), but the SET ITSELF was fixed geometrically, not
by name: a real ancient unit is fought at exactly two map spots.  See
NOT_ANCIENT_DESPITE_NAME -- "ancient" inside a neutral's name is a growth
stage, not a camp tier, and taking it at face value inflated this census by
2.7x.  `--audit-locations` reprints the evidence on any corpus.

FREEZE TAIL (GH #130) -- AND A CORRECTION TO HOW IT IS APPLIED
--------------------------------------------------------------
Measured on this corpus (40 games, run_001140): the frozen tail is exactly
the span between the LAST EVENT and the LAST SNAPSHOT -- 23.9-24.9 s,
median 24.45.  Events stop; snapshots keep being emitted.

So an episode built from DAMAGE events can never live inside the tail, and a
guard that cuts `t_last_event - 25 s` deletes 25 seconds of REAL play.  The
first version of this file did exactly that and dropped 40 of 161 episodes
(24.8%) -- including the level-11 Wraith King episode that motivated the
tool.  The guard now cuts at `t_last_snapshot - --tail` (default 0 => no
event-side cut at all) and reports the measured tail span per corpus.
Snapshot-derived columns are clamped to `t_last_event`.
"""
import argparse
import glob
import json
import math
import os
import sys
from collections import Counter, defaultdict

HERO = "npc_dota_hero_"

# Ancient-camp neutrals.  Substring match against the dumped entity name.
ANCIENT_MARKS = (
    "granite_golem",
    "rock_golem",
    "black_dragon",
    "black_drake",
    "thunder_lizard",
    "prowler_",
)

# DO NOT add a name just because it contains "ancient".  Measured on
# run_001140 (40 games): `npc_dota_neutral_ancient_frog_mage` is fought at
# (-953, 4499) and (518, -4784) -- the SAME spots as `froglet` and
# `grown_frog_mage`, i.e. it is the third GROWTH stage of an ordinary camp's
# creep, not an ancient-camp unit.  Including the frog family inflated this
# census from 60 episodes to 161.  The tier test that actually works is
# geometric: a real ancient unit resolves to exactly TWO map clusters, both
# at |x| ~ 4000-5000, y ~ 0 (the four ancient camps).  --audit-locations
# prints the clusters; the selfcheck asserts the 2-cluster property.
NOT_ANCIENT_DESPITE_NAME = ("ancient_frog",)
ANCIENT_CLUSTER_MIN_ABS_X = 3500.0
ANCIENT_CLUSTER_MAX_ABS_Y = 1500.0

DEFAULT_GAP = 8.0
# 0.0 = no event-side cut; see the FREEZE TAIL note above.  Raise it only to
# test sensitivity, never to "be safe" -- being safe here deletes real play.
DEFAULT_TAIL = 0.0
DEFAULT_AFTER = 20.0


def is_ancient(name):
    if not name.startswith("npc_dota_neutral"):
        return False
    if any(m in name for m in NOT_ANCIENT_DESPITE_NAME):
        return False
    return any(m in name for m in ANCIENT_MARKS)


def is_hero(name):
    return name.startswith(HERO)


def bare(n):
    return n.replace(HERO, "")


def load(path):
    with open(path) as fh:
        return json.load(fh)


def hero_frames(tl):
    """t -> hero -> snapshot, plus a sorted time index per hero."""
    by_hero = defaultdict(list)
    for s in tl["snapshots"]:
        by_hero[s["hero"]].append(s)
    for h in by_hero:
        by_hero[h].sort(key=lambda s: s["t"])
    return by_hero


def frame_at(frames, t):
    """Last snapshot at or before t (the decision-side convention: never read
    a frame from the future of the instant being described)."""
    lo, hi, best = 0, len(frames) - 1, None
    while lo <= hi:
        mid = (lo + hi) // 2
        if frames[mid]["t"] <= t:
            best = frames[mid]
            lo = mid + 1
        else:
            hi = mid - 1
    return best


def episodes_for_game(tl, path, gap=DEFAULT_GAP, tail=DEFAULT_TAIL,
                      after=DEFAULT_AFTER):
    ev = tl["events"]
    if not ev:
        return [], {}
    t_last_event = max(e["t"] for e in ev)
    t_last_snap = max((s["t"] for s in tl["snapshots"]), default=t_last_event)
    freeze_span = round(t_last_snap - t_last_event, 2)
    # cut relative to the last SNAPSHOT (the frozen tail's own end), not the
    # last event -- see the module docstring.
    t_end = t_last_snap
    frames = hero_frames(tl)
    teams = tl["game"]["teams"]

    exchanges = defaultdict(list)   # hero -> [(t, dealt, taken, unit)]
    names = Counter()
    for e in ev:
        if e["type"] != "DAMAGE":
            continue
        a, tg = e["actor"], e["target"]
        if is_hero(a) and is_ancient(tg):
            exchanges[a].append((e["t"], float(e.get("value") or 0), 0.0, tg))
            names[tg] += 1
        elif is_ancient(a) and is_hero(tg):
            exchanges[tg].append((e["t"], 0.0, float(e.get("value") or 0), a))
            names[a] += 1

    # hero deaths and TP presses, for the "how did it end" column
    deaths = defaultdict(list)
    tp_press = defaultdict(list)
    regen = defaultdict(list)
    kills = defaultdict(list)        # hero -> [(t, unit)] ancient kills
    gold = defaultdict(list)         # hero -> [(t, value)]
    for e in ev:
        ty, a, tg = e["type"], e["actor"], e["target"]
        if ty == "DEATH" and is_hero(tg) and is_hero(a):
            deaths[tg].append(e["t"])
        elif ty == "DEATH" and is_hero(tg):
            deaths[tg].append(e["t"])
        elif ty == "DEATH" and is_hero(a) and is_ancient(tg):
            kills[a].append((e["t"], tg))
        if ty == "MODIFIER_ADD" and is_hero(tg) and e.get("inflictor") == "modifier_teleporting":
            tp_press[tg].append(e["t"])
        if ty == "ITEM" and is_hero(a) and e.get("inflictor") in (
                "item_flask", "item_tango", "item_clarity", "item_bottle",
                "item_faerie_fire", "item_magic_stick", "item_magic_wand"):
            regen[a].append((e["t"], e["inflictor"]))
        if ty == "GOLD" and is_hero(tg):
            gold[tg].append((e["t"], float(e.get("value") or 0)))

    out = []
    dropped_tail = 0
    for h, rows in exchanges.items():
        rows.sort()
        cur = [rows[0]]
        groups = []
        for r in rows[1:]:
            if r[0] - cur[-1][0] <= gap:
                cur.append(r)
            else:
                groups.append(cur)
                cur = [r]
        groups.append(cur)

        for g in groups:
            t0, t1 = g[0][0], g[-1][0]
            if t1 >= t_end - tail:
                dropped_tail += 1
                continue
            fr = frames.get(h) or []
            f0 = frame_at(fr, t0)
            if f0 is None:
                continue
            hps = [s["hp_pct"] for s in fr if t0 <= s["t"] <= t1 + 0.5]
            dealt = sum(r[1] for r in g)
            taken = sum(r[2] for r in g)
            dealt_ts = [r[0] for r in g if r[1] > 0]
            taken_ts = [r[0] for r in g if r[2] > 0]
            g_kills = [k for k in kills.get(h, []) if t0 <= k[0] <= t1 + 1.0]
            g_gold = sum(v for t, v in gold.get(h, []) if t0 <= t <= t1 + 1.0)
            # nearest enemy hero over the episode (min across sampled frames)
            near = None
            for s in fr:
                if not (t0 <= s["t"] <= t1):
                    continue
                for h2, fr2 in frames.items():
                    if h2 == h or teams.get(h2) == teams.get(h):
                        continue
                    s2 = frame_at(fr2, s["t"])
                    if s2 is None or s2["hp_pct"] <= 0:
                        continue
                    dd = math.dist((s["x"], s["y"]), (s2["x"], s2["y"]))
                    near = dd if near is None else min(near, dd)
            died = any(t1 <= dt <= t1 + after for dt in deaths.get(h, []))
            # A TP pressed inside the episode's tail still "ends" it: the
            # channel takes ~3 s and the camp keeps hitting during it, so the
            # last exchange lands AFTER the press.  Measured case: WK presses
            # at 654.9, last golem hit at 657.3 -- a t1-2.0 window missed it.
            tped = any(t1 - 5.0 <= tt <= t1 + after for tt in tp_press.get(h, []))
            used = [r[1] for r in regen.get(h, []) if t0 <= r[0] <= t1]
            out.append({
                "game": os.path.basename(path).replace(".json", ""),
                "hero": bare(h),
                "t0": round(t0, 1),
                "t1": round(t1, 1),
                "dur": round(t1 - t0, 1),
                "level": f0["level"],
                "hp0": round(f0["hp_pct"], 3),
                "hp_min": round(min(hps), 3) if hps else None,
                "hp_end": round(hps[-1], 3) if hps else None,
                "dealt": round(dealt),
                "taken": round(taken),
                "kills": len(g_kills),
                "gold": round(g_gold),
                "opened": bool(dealt_ts and taken_ts and dealt_ts[0] < taken_ts[0]),
                # Where the fight was.  Ancient camps resolve to exactly two
                # map clusters per side (see the ANCIENT UNIT SET note), so the
                # sign of x is which team OWNS the camp -- the only thing
                # `IsCampAllowedForLevel`'s enemy-camp clause needs.
                "x0": round(f0["x"]),
                "y0": round(f0["y"]),
                "nearest_enemy": round(near) if near is not None else None,
                "regen_used": used,
                "ended_tp_home": tped,
                "ended_death": died,
                "items0": [i for i in f0["items"] if i],
            })
    return out, {"names": names, "dropped_tail": dropped_tail,
                 "t_end": t_end, "freeze_span": freeze_span}


def cluster_points(pts, radius=900.0):
    cs = []
    for x, y in pts:
        for c in cs:
            if math.dist((x, y), (c[0] / c[2], c[1] / c[2])) < radius:
                c[0] += x
                c[1] += y
                c[2] += 1
                break
        else:
            cs.append([x, y, 1])
    return sorted([(int(c[0] / c[2]), int(c[1] / c[2]), c[2]) for c in cs],
                  key=lambda z: -z[2])


def location_clusters(paths, min_hits=8):
    """Where on the map is each neutral name actually fought?  This is the
    camp-tier test that name matching cannot do (see NOT_ANCIENT_DESPITE_NAME)."""
    locs = defaultdict(list)
    for p in paths:
        tl = load(p)
        frames = hero_frames(tl)
        for e in tl["events"]:
            if e["type"] != "DAMAGE":
                continue
            a, tg = e["actor"], e["target"]
            if is_hero(a) and tg.startswith("npc_dota_neutral"):
                h, n = a, tg
            elif a.startswith("npc_dota_neutral") and is_hero(tg):
                h, n = tg, a
            else:
                continue
            s = frame_at(frames.get(h) or [], e["t"])
            if s:
                locs[n.replace("npc_dota_neutral_", "")].append((s["x"], s["y"]))
    out = {}
    for n, pts in locs.items():
        out[n] = [c for c in cluster_points(pts) if c[2] >= min_hits]
    return out


def pct(n, d):
    return f"{100.0 * n / d:.1f}%" if d else "n/a"


def med(xs):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    return xs[len(xs) // 2]


def run(paths, gap, tail, after, level_cut, verbose):
    eps, names, dropped, games = [], Counter(), 0, 0
    spans = []
    for p in paths:
        tl = load(p)
        e, meta = episodes_for_game(tl, p, gap, tail, after)
        eps.extend(e)
        names.update(meta.get("names", Counter()))
        dropped += meta.get("dropped_tail", 0)
        if meta.get("freeze_span") is not None:
            spans.append(meta["freeze_span"])
        games += 1

    print(f"games                {games}")
    print(f"ancient episodes     {len(eps)}   (cut by --tail={tail}: {dropped})")
    if spans:
        print(f"freeze tail (GH #130) span = last_snapshot - last_event: "
              f"min {min(spans)} med {med(spans)} max {max(spans)} "
              f"-- episodes are event-driven, so none live inside it")
    print(f"ancient unit names   {dict(names.most_common())}")
    if not eps:
        return eps
    low = [e for e in eps if e["level"] <= level_cut]
    print(f"\n-- all episodes --")
    print(f"  median duration    {med([e['dur'] for e in eps])}s")
    print(f"  median hp burned   {med([round(e['hp0'] - (e['hp_min'] or e['hp0']), 3) for e in eps])}")
    print(f"  median gold        {med([e['gold'] for e in eps])}")
    print(f"  ended TP home      {sum(e['ended_tp_home'] for e in eps)}  ({pct(sum(e['ended_tp_home'] for e in eps), len(eps))})")
    print(f"  ended in death     {sum(e['ended_death'] for e in eps)}  ({pct(sum(e['ended_death'] for e in eps), len(eps))})")
    print(f"  hero opened it     {sum(e['opened'] for e in eps)}  ({pct(sum(e['opened'] for e in eps), len(eps))})")
    print(f"\n-- level <= {level_cut} at engagement (aba_site.RefreshCamp says these should be excluded) --")
    print(f"  episodes           {len(low)}  ({pct(len(low), len(eps))})")
    if low:
        print(f"  median duration    {med([e['dur'] for e in low])}s")
        print(f"  median hp burned   {med([round(e['hp0'] - (e['hp_min'] or e['hp0']), 3) for e in low])}")
        print(f"  median gold        {med([e['gold'] for e in low])}")
        print(f"  ended TP home      {sum(e['ended_tp_home'] for e in low)}  ({pct(sum(e['ended_tp_home'] for e in low), len(low))})")
        print(f"  ended in death     {sum(e['ended_death'] for e in low)}  ({pct(sum(e['ended_death'] for e in low), len(low))})")
    lv = Counter(e["level"] for e in eps)
    print(f"\n  level histogram    {dict(sorted(lv.items()))}")
    heavy = sorted(eps, key=lambda e: -(e["hp0"] - (e["hp_min"] or e["hp0"])))[:12]
    print("\n-- worst 12 by HP burned --")
    for e in heavy:
        print(f"  {e['game'][:22]:22s} {e['hero']:16s} t={e['t0']:6.1f}-{e['t1']:6.1f} "
              f"lvl={e['level']:2d} hp {e['hp0']:.3f}->{e['hp_min']:.3f} "
              f"gold={e['gold']:4d} kills={e['kills']} "
              f"near={e['nearest_enemy']} tp={int(e['ended_tp_home'])} died={int(e['ended_death'])}")
    if verbose:
        print("\n-- all rows --")
        for e in sorted(eps, key=lambda e: (e["game"], e["t0"])):
            print(json.dumps(e))
    return eps


# ---------------------------------------------------------------- selfcheck
def _mk(events, snaps, teams, t_end=400.0):
    """Synthetic timeline.  The trailing filler event matters: the freeze-tail
    guard reads the game's end off the LAST event, so a fragment that stops
    right after the exchange would have its whole exchange sitting inside the
    tail and get dropped.  (Caught by this file's own selfcheck on the first
    run -- two "failures" that were the fixture's fault, not the guard's.)"""
    events = list(events) + [{"t": t_end, "type": "GOLD",
                              "actor": "dota_unknown", "target": "dota_unknown",
                              "inflictor": "dota_unknown", "value": 0}]
    return {"events": events, "snapshots": snaps, "game": {"teams": teams}}


def selfcheck(real_paths):
    ok, fail = 0, 0

    def chk(name, cond):
        nonlocal ok, fail
        if cond:
            ok += 1
            print(f"  PASS {name}")
        else:
            fail += 1
            print(f"  FAIL {name}")

    chk("is_ancient granite", is_ancient("npc_dota_neutral_granite_golem"))
    chk("is_ancient rock", is_ancient("npc_dota_neutral_rock_golem"))
    chk("NOT ancient: ancient_frog_mage (growth stage, not camp tier)",
        not is_ancient("npc_dota_neutral_ancient_frog_mage"))
    chk("NOT ancient: grown_frog", not is_ancient("npc_dota_neutral_grown_frog"))
    chk("is_ancient prowler shaman", is_ancient("npc_dota_neutral_prowler_shaman"))
    chk("not ancient: mud golem", not is_ancient("npc_dota_neutral_mud_golem"))
    chk("not ancient: centaur khan", not is_ancient("npc_dota_neutral_centaur_khan"))
    chk("not ancient: hero", not is_ancient("npc_dota_hero_skeleton_king"))
    chk("not ancient: janggo item name", not is_ancient("item_ancient_janggo"))

    H = "npc_dota_hero_axe"
    A = "npc_dota_neutral_granite_golem"
    # snapshots run 25 s past the last event, exactly like a real replay's
    # frozen tail (GH #130, measured 23.9-24.9 s on run_001140)
    snaps = [{"t": float(t), "hero": H, "x": 0.0, "y": 0.0, "hp": 100,
              "hp_pct": max(0.0, 1.0 - 0.02 * t), "mp": 0, "max_mp": 1,
              "mp_pct": 0.0, "level": 9, "items": ["flask", "", ""]}
             for t in range(0, 156)]
    ev = []
    for t in range(10, 40):
        ev.append({"t": float(t), "type": "DAMAGE", "actor": H, "target": A,
                   "inflictor": "dota_unknown", "value": 50})
        ev.append({"t": t + 0.4, "type": "DAMAGE", "actor": A, "target": H,
                   "inflictor": "dota_unknown", "value": 70})
    ev.append({"t": 120.0, "type": "DAMAGE", "actor": H, "target": A,
               "inflictor": "dota_unknown", "value": 1})
    tl = _mk(ev, snaps, {H: 2}, t_end=130.0)
    eps, meta = episodes_for_game(tl, "synthetic.json", tail=DEFAULT_TAIL)
    chk("two episodes: the exchange plus the lone t=120 hit", len(eps) == 2)
    chk("default tail=0 drops nothing (GH #130 correction)",
        meta["dropped_tail"] == 0)
    chk("freeze span = last snapshot - last event",
        meta["freeze_span"] == 25.0)
    # last snapshot is 155.0, so --tail 36 cuts at 119.0: it drops the lone
    # t=120 hit and keeps the 10-40 s exchange.  Cutting the same 36 s off the
    # last EVENT (130.0) would cut at 94.0 and drop the same one episode --
    # so the check that separates the two conventions is the 25 s difference:
    # --tail 26 (event end 104.0 vs snapshot end 129.0) must drop NOTHING.
    eps_keep, meta_keep = episodes_for_game(tl, "synthetic.json", tail=26.0)
    chk("--tail 26 measured off the snapshot end drops nothing",
        meta_keep["dropped_tail"] == 0 and len(eps_keep) == 2)
    eps_cut, meta_cut = episodes_for_game(tl, "synthetic.json", tail=36.0)
    chk("an explicit --tail cuts from the snapshot end, not the event end",
        meta_cut["dropped_tail"] == 1 and len(eps_cut) == 1)
    eps = [e for e in eps if e["dur"] > 1.0]
    if eps:
        e = eps[0]
        chk("hero opened it (his hit lands first)", e["opened"] is True)
        chk("duration spans the exchange", 29.0 <= e["dur"] <= 30.0)
        chk("level read from the frame at t0", e["level"] == 9)
        chk("hp burned is measured, not assumed", e["hp0"] > e["hp_min"])

    # gap splitting
    ev2 = [{"t": 10.0, "type": "DAMAGE", "actor": H, "target": A,
            "inflictor": "x", "value": 5},
           {"t": 30.0, "type": "DAMAGE", "actor": H, "target": A,
            "inflictor": "x", "value": 5}]
    eps2, _ = episodes_for_game(_mk(ev2, snaps, {H: 2}), "s2.json")
    chk("a 20s gap splits into two episodes", len(eps2) == 2)

    # TP-home tagging
    ev3 = list(ev[:20]) + [{"t": 22.0, "type": "MODIFIER_ADD", "actor": H,
                            "target": H, "inflictor": "modifier_teleporting",
                            "value": 0}]
    eps3, _ = episodes_for_game(_mk(ev3, snaps, {H: 2}), "s3.json")
    chk("TP press after the last exchange is tagged", eps3 and eps3[0]["ended_tp_home"])

    # regen tagging
    ev4 = list(ev) + [{"t": 25.0, "type": "ITEM", "actor": H, "target": H,
                       "inflictor": "item_flask", "value": 0}]
    eps4, _ = episodes_for_game(_mk(ev4, snaps, {H: 2}), "s4.json")
    chk("in-episode salve is tagged", eps4 and "item_flask" in eps4[0]["regen_used"])

    # ---- real-corpus assertions (only if a corpus was handed in) ----
    if real_paths:
        eps5 = []
        for p in real_paths[:8]:
            tl = load(p)
            e, _ = episodes_for_game(tl, p)
            eps5.extend(e)
        chk("real corpus yields episodes", len(eps5) > 0)
        chk("every episode has a level", all(e["level"] is not None for e in eps5))
        chk("no episode has negative duration", all(e["dur"] >= 0 for e in eps5))

        cl = location_clusters(real_paths)
        bad = {n: c for n, c in cl.items() if is_ancient("npc_dota_neutral_" + n)
               and len(c) > 2}
        chk(f"every ancient name resolves to <=2 map clusters (offenders {bad})",
            not bad)
        offside = {}
        for n, cs in cl.items():
            if not is_ancient("npc_dota_neutral_" + n):
                continue
            for x, y, _ in cs:
                if abs(x) < ANCIENT_CLUSTER_MIN_ABS_X or abs(y) > ANCIENT_CLUSTER_MAX_ABS_Y:
                    offside.setdefault(n, []).append((x, y))
        chk(f"ancient clusters sit at |x|>=3500, |y|<=1500 (offenders {offside})",
            not offside)
        frog = cl.get("ancient_frog_mage") or []
        chk("the frog family is NOT counted as ancient "
            "(same spots as froglet, so name-tier would be wrong)",
            not is_ancient("npc_dota_neutral_ancient_frog_mage")
            and (not frog or any(abs(x) < ANCIENT_CLUSTER_MIN_ABS_X for x, _, _ in frog)))

    print(f"\nselfcheck: {ok} PASS / {fail} FAIL")
    return 0 if fail == 0 else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("timelines", nargs="*", help="timeline .json files or a directory")
    ap.add_argument("--gap", type=float, default=DEFAULT_GAP)
    ap.add_argument("--tail", type=float, default=DEFAULT_TAIL,
                    help="freeze-tail guard, GH #130")
    ap.add_argument("--after", type=float, default=DEFAULT_AFTER,
                    help="window after the last exchange for death/TP tagging")
    ap.add_argument("--level-cut", type=int, default=11,
                    help="aba_site.RefreshCamp's own ancient threshold")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--audit-locations", action="store_true",
                    help="print where each neutral name is actually fought "
                         "(the camp-tier test that name matching cannot do)")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args()

    paths = []
    for t in args.timelines:
        if os.path.isdir(t):
            paths.extend(sorted(glob.glob(os.path.join(t, "*.json"))))
        else:
            paths.append(t)

    if args.selfcheck:
        return selfcheck(paths)
    if not paths:
        ap.error("no timelines given")
    if args.audit_locations:
        cl = location_clusters(paths)
        print(f"{'neutral':26s} {'anc?':5s} clusters (x, y, hits)")
        for n, cs in sorted(cl.items(), key=lambda kv: -sum(c[2] for c in kv[1])):
            if not cs:
                continue
            tag = "ANC" if is_ancient("npc_dota_neutral_" + n) else ""
            print(f"{n:26s} {tag:5s} {cs[:6]}")
        print()
    run(paths, args.gap, args.tail, args.after, args.level_cut, args.verbose)
    return 0


if __name__ == "__main__":
    sys.exit(main())
