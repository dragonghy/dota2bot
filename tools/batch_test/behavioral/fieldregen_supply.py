#!/usr/bin/env python3
"""Execution-verification probe for the owner-P2 "野区续航" supply pair:
`fieldregen` (mid-game salve re-purchase) and `wandbleed` (chronic ranged
bleed wand drink).  Read-only, offline; consumes sweep_run.sh output dirs.

Why a dedicated probe (and not detect.py): both ids are *supply-side* levers
whose whole point is that a wrecked hero heals IN THE FIELD instead of going
home.  detect.py has no item-acquisition or item-usage predicate at all, so
neither id has ever had an (a) reading.  owner priority P2 DoD #2 requires
exactly this ((a) evidence for the fieldregen/wandbleed family).

Domains are transcribed from the source, not invented:

  fieldregen -- bots/item_purchase_generic.lua:776
      IsModeTurbo() and IsSoakCandidate('fieldregen')
      and not J.IsInLaningPhase()          <- reconstructed EXACTLY, see below
      and bot:IsAlive() and J.GetHP(bot) < 0.45
      and FindItemSlot('item_flask') < 0 and FindItemSlot('item_tango') < 0
      and not IsThereHealingInStash(bot)   <- NOT observable offline (dilutes)
      and GetEmptyInventoryAmount(bot) >= 1
      and botDistanceFromFountain > 2500
      and botGold >= GetItemCost('item_flask')   <- NOT observable (dilutes)
      and GetItemStockCount('item_flask') > 1    <- NOT observable (dilutes)
      and not HasModifier('modifier_flask_healing')
      and not HasModifier('modifier_fountain_aura_buff')  <- fountain dist proxy

  wandbleed -- bots/ability_item_usage_generic.lua:3321
      IsModeTurbo() and IsSoakCandidate('wandbleed')
      and nHPrate < 0.45 and nCharges >= 5        <- charges NOT observable
      and bot:WasRecentlyDamagedByAnyHero(2.0)
    The shipped rule one block above already fires at (hp<0.4 or mp<0.3) with an
    enemy inside 1000u, so wandbleed's OWN territory is the frames where the
    nearest visible enemy hero is BEYOND 1000u.  That is the band scored here.

J.IsInLaningPhase() (jmz_func.lua:9194) is reconstructed exactly for turbo with
neither 'c2' nor 'c4' armed (verified against the wave's armed string):
    laning  <=>  t < 480  or  (t < 600 and net_worth < 8000)
`net_worth` is a real snapshot field, so the soft extension is evaluated per
frame rather than approximated by a flat cutoff.

Registered traps this tool obeys:
  * idx lock by EARLIEST APPEARANCE (charter 08-22T04:05Z 甲/乙/丙) -- illusions
    copy hp/items field-for-field, so identity can only come from `idx`.
  * corpse frames carry an empty `items` list, which would make "no flask and no
    tango" trivially true -- domain requires a non-empty inventory AND excludes
    the 1.0s post-DEATH window (charter #78 leak band <=0.30s, 3x margin).
  * "<= t 的最后一帧" for every cross-unit lookup, with a max gap of one sampling
    interval (charter 08-21T12:39Z).
  * fountain centroid carries a positive control (charter 08-22T08:50Z 乙).
  * sampling interval is recorded in the output; sweep_run.sh passes no
    -interval, i.e. main.go's 1.0s default (charter 08-21T10:51Z).
  * #102 sweep-completeness sentinel: sweep_summary.md must exist and its
    "games swept:" count must equal the manifest line count; the count is the
    FIRST INTEGER AFTER THE COLON (charter 08-22T06:55Z 甲).
  * timelines are indexed by (run, basename), never basename alone (charter
    08-22T08:50Z 丙).

Usage:
    fieldregen_supply.py <sweep_dir> [<sweep_dir> ...] [--interval 1.0]
    fieldregen_supply.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import json
import os
import re
import sys

RADIANT, DIRE = 2, 3
SIDE_TEAM = {"radiant": RADIANT, "dire": DIRE}

LOW_HP = 0.45              # both ids share this literal
FOUNTAIN_MIN_U = 2500.0    # fieldregen: botDistanceFromFountain > 2500
SHIPPED_WAND_RANGE = 1000.0  # the shipped wand rule's enemy radius
RECENT_DMG_S = 2.0         # WasRecentlyDamagedByAnyHero(2.0)
DEATH_BLANK_S = 1.0        # #78 leak band is <=0.30s; 3x margin
CENTROID_WINDOW_S = 3.0
DELIVERY_S = 90.0          # courier delivery slack for a stash purchase


def canon(name):
    """Canonicalise a hero name from either the event or the snapshot side."""
    if not name:
        return None
    n = name.lower()
    if n.startswith("npc_dota_hero_"):
        n = n[len("npc_dota_hero_"):]
    return n.replace("_", "")


def games_swept_count(summary_path):
    """First integer after the colon on the 'games swept:' line."""
    with open(summary_path) as fh:
        for line in fh:
            if "games swept" in line:
                m = re.search(r"games swept[^:]*:\s*(\d+)", line)
                if m:
                    return int(m.group(1))
    return None


def load_sweeps(dirs):
    """Yield (run, game, cand, seed, side, timeline_path) with #102 sentinel."""
    out = []
    for d in dirs:
        run = os.path.basename(os.path.normpath(d))
        summary = os.path.join(d, "sweep_summary.md")
        manifest = os.path.join(d, "games_manifest.jsonl")
        if not os.path.exists(summary):
            sys.exit("FATAL #102: no sweep_summary.md in %s (incomplete sweep)" % d)
        rows = [json.loads(l) for l in open(manifest) if l.strip()]
        swept = games_swept_count(summary)
        if swept is None or swept != len(rows):
            sys.exit("FATAL #102: %s says 'games swept: %s' but manifest has %d lines"
                     % (d, swept, len(rows)))
        for r in rows:
            tl = os.path.join(d, "timelines", "%s.timeline.json" % r["game"])
            if not os.path.exists(tl):
                sys.exit("FATAL: missing timeline %s" % tl)
            out.append((run, r["game"], r["cand"], r["seed"], r["side"], tl))
    return out


class Game(object):
    """One timeline with identity locked to the primary idx per hero."""

    def __init__(self, path, interval):
        d = json.load(open(path))
        self.interval = interval
        self.teams = d["game"]["teams"]

        # --- idx lock: primary entity = EARLIEST APPEARANCE (charter 04:05Z) ---
        first_t, self.copies = {}, 0
        for s in d["snapshots"]:
            if "idx" not in s:
                sys.exit("FATAL: timeline has no snapshot idx; cannot lock identity")
            key = (canon(s["hero"]), s["idx"])
            if key not in first_t or s["t"] < first_t[key]:
                first_t[key] = s["t"]
        primary = {}
        for (hero, idx), t0 in first_t.items():
            if hero not in primary or t0 < primary[hero][1]:
                primary[hero] = (idx, t0)
        self.primary_idx = {h: v[0] for h, v in primary.items()}

        self.track = collections.defaultdict(list)   # hero -> [snapshot]
        self.by_t = collections.defaultdict(list)    # t -> [snapshot] (locked)
        for s in d["snapshots"]:
            h = canon(s["hero"])
            if s["idx"] != self.primary_idx.get(h):
                self.copies += 1
                continue
            s["_hero"] = h
            self.track[h].append(s)
            self.by_t[round(s["t"], 3)].append(s)
        for v in self.track.values():
            v.sort(key=lambda s: s["t"])
        self.times = sorted(self.by_t)

        self.events = d["events"]
        self.deaths = collections.defaultdict(list)
        self.hero_damage = collections.defaultdict(list)   # victim -> [t]
        self.item_use = collections.defaultdict(list)      # (hero,item) -> [t]
        for e in self.events:
            if e["type"] == "DEATH" and e.get("target_hero"):
                self.deaths[canon(e["target"])].append(e["t"])
            elif e["type"] == "DAMAGE" and e.get("actor_hero") and e.get("target_hero"):
                self.hero_damage[canon(e["target"])].append(e["t"])
            elif e["type"] == "ITEM" and e.get("actor_hero"):
                self.item_use[(canon(e["actor"]), e["inflictor"])].append(e["t"])
        for v in self.hero_damage.values():
            v.sort()

        # --- fountain centroid per team, from the first CENTROID_WINDOW_S ---
        self.fountain = {}
        t0 = self.times[0] if self.times else 0.0
        acc = collections.defaultdict(list)
        for t in self.times:
            if t > t0 + CENTROID_WINDOW_S:
                break
            for s in self.by_t[t]:
                acc[s["team"]].append((s["x"], s["y"]))
        for team, pts in acc.items():
            self.fountain[team] = (sum(p[0] for p in pts) / len(pts),
                                   sum(p[1] for p in pts) / len(pts))

    def team_of(self, hero):
        tr = self.track.get(hero)
        return tr[0]["team"] if tr else None

    def frame_at(self, hero, t):
        """Last frame with time <= t, and only if within one sampling interval."""
        tr = self.track.get(hero)
        if not tr:
            return None
        lo, hi, best = 0, len(tr) - 1, None
        while lo <= hi:
            mid = (lo + hi) // 2
            if tr[mid]["t"] <= t:
                best = tr[mid]
                lo = mid + 1
            else:
                hi = mid - 1
        if best is None or t - best["t"] > self.interval + 1e-6:
            return None
        return best

    def recently_died(self, hero, t):
        return any(0.0 <= t - td < DEATH_BLANK_S for td in self.deaths.get(hero, ()))

    def damaged_by_hero_within(self, hero, t, window):
        return any(t - window <= td <= t for td in self.hero_damage.get(hero, ()))

    def nearest_enemy_dist(self, hero, t):
        me = self.frame_at(hero, t)
        if me is None:
            return None
        best = None
        for other, tr in self.track.items():
            if other == hero:
                continue
            if self.team_of(other) == me["team"]:
                continue
            fr = self.frame_at(other, t)
            if fr is None or fr["hp_pct"] <= 0:
                continue
            d = ((fr["x"] - me["x"]) ** 2 + (fr["y"] - me["y"]) ** 2) ** 0.5
            if best is None or d < best:
                best = d
        return best


def is_laning(t, net_worth):
    """J.IsInLaningPhase() for turbo with neither c2 nor c4 armed."""
    if t < 480.0:
        return True
    if t < 600.0 and net_worth < 8000:
        return True
    return False


def has(items, name):
    return any(i == name for i in items if i)


def inv_nonempty(items):
    return any(i for i in items)


def empty_slots(items):
    # snapshots expose 9 slots (6 backpack-inclusive + stash-ish tail); the
    # engine's GetEmptyInventoryAmount counts the 6 real ones.
    return sum(1 for i in items[:6] if not i)


def scan_fieldregen(g):
    """Frames in fieldregen's observable domain + whether a flask followed."""
    rows, blanked = [], 0
    for hero, tr in g.track.items():
        for s in tr:
            t = s["t"]
            if t < 0 or s["hp_pct"] <= 0 or s["hp_pct"] >= LOW_HP:
                continue
            if not inv_nonempty(s["items"]):
                continue
            if g.recently_died(hero, t):
                blanked += 1
                continue
            if is_laning(t, s.get("net_worth", 0)):
                continue
            if has(s["items"], "flask") or has(s["items"], "tango") \
               or has(s["items"], "tango_single"):
                continue
            if empty_slots(s["items"]) < 1:
                continue
            fx = g.fountain.get(s["team"])
            if fx is None:
                continue
            dist = ((s["x"] - fx[0]) ** 2 + (s["y"] - fx[1]) ** 2) ** 0.5
            if dist <= FOUNTAIN_MIN_U:
                continue
            rows.append({"hero": hero, "t": t, "hp": s["hp_pct"],
                         "fountain_dist": dist, "net_worth": s.get("net_worth"),
                         "team": s["team"]})
    # collapse to episodes: same hero, gap > 5s starts a new one
    eps = []
    for hero in sorted(set(r["hero"] for r in rows)):
        hr = sorted((r for r in rows if r["hero"] == hero), key=lambda r: r["t"])
        cur = None
        for r in hr:
            if cur is None or r["t"] - cur["t_end"] > 5.0:
                cur = {"hero": hero, "t_start": r["t"], "t_end": r["t"],
                       "frames": 1, "hp_min": r["hp"], "team": r["team"],
                       "fountain_dist": r["fountain_dist"]}
                eps.append(cur)
            else:
                cur["t_end"] = r["t"]
                cur["frames"] += 1
                cur["hp_min"] = min(cur["hp_min"], r["hp"])
    # outcome: flask acquired (appears in inventory) or drunk, after t_start
    for e in eps:
        tr = g.track[e["hero"]]
        got = None
        for s in tr:
            if s["t"] <= e["t_start"] or s["t"] > e["t_start"] + DELIVERY_S:
                continue
            if has(s["items"], "flask"):
                got = s["t"]
                break
        drank = [t for t in g.item_use.get((e["hero"], "item_flask"), ())
                 if e["t_start"] < t <= e["t_start"] + DELIVERY_S]
        e["flask_acquired_t"] = got
        e["flask_drunk_t"] = drank[0] if drank else None
    return eps, blanked, len(rows)


def scan_wandbleed(g, band_u=SHIPPED_WAND_RANGE):
    """Frames in wandbleed's OWN territory (enemy beyond the shipped 1000u).

    `band_u` exists because 1Hz sampling moves a hero +-400u between frames
    (charter 08-22T06:55Z): an episode whose nearest enemy reads 1008u can have
    been inside the shipped rule's 1000u radius on the actual cast frame.
    Scoring at band_u=1400 buys a contamination-free read at the cost of supply.
    """
    rows, blanked, no_enemy_read = [], 0, 0
    for hero, tr in g.track.items():
        for s in tr:
            t = s["t"]
            if t < 0 or s["hp_pct"] <= 0 or s["hp_pct"] >= LOW_HP:
                continue
            if not inv_nonempty(s["items"]):
                continue
            if g.recently_died(hero, t):
                blanked += 1
                continue
            if not (has(s["items"], "magic_wand") or has(s["items"], "magic_stick")):
                continue
            if not g.damaged_by_hero_within(hero, t, RECENT_DMG_S):
                continue
            d = g.nearest_enemy_dist(hero, t)
            if d is None:
                no_enemy_read += 1
                continue
            if d <= band_u:
                continue          # shipped rule's territory, not wandbleed's
            rows.append({"hero": hero, "t": t, "hp": s["hp_pct"], "enemy": d,
                         "team": s["team"]})
    eps = []
    for hero in sorted(set(r["hero"] for r in rows)):
        hr = sorted((r for r in rows if r["hero"] == hero), key=lambda r: r["t"])
        cur = None
        for r in hr:
            if cur is None or r["t"] - cur["t_end"] > 5.0:
                cur = {"hero": hero, "t_start": r["t"], "t_end": r["t"], "frames": 1,
                       "hp_min": r["hp"], "enemy_min": r["enemy"], "team": r["team"]}
                eps.append(cur)
            else:
                cur["t_end"] = r["t"]
                cur["frames"] += 1
                cur["hp_min"] = min(cur["hp_min"], r["hp"])
                cur["enemy_min"] = min(cur["enemy_min"], r["enemy"])
    for e in eps:
        used = []
        for item in ("item_magic_wand", "item_magic_stick"):
            used += [t for t in g.item_use.get((e["hero"], item), ())
                     if e["t_start"] - 1.0 <= t <= e["t_end"] + 3.0]
        e["wand_used_t"] = min(used) if used else None
    return eps, blanked, len(rows), no_enemy_read


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sweeps", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0,
                    help="dumper sampling interval the sweep used (default 1.0s)")
    ap.add_argument("--wand-band", type=float, default=SHIPPED_WAND_RANGE,
                    help="nearest-enemy floor for wandbleed's own territory "
                         "(1000 = the shipped rule's radius; 1400 = +-400u "
                         "single-frame motion margin on top of it)")
    ap.add_argument("--selfcheck", action="store_true",
                    help="field-by-field guards; nonzero exit on any violation")
    args = ap.parse_args()

    games = load_sweeps(args.sweeps)
    cands = set(g[2] for g in games)
    if len(cands) != 1:
        sys.exit("FATAL: sweep dirs carry %d distinct armed strings; refusing to "
                 "pool them: %s" % (len(cands), sorted(cands)))
    armed_ids = sorted(cands.pop().split(","))
    for need in ("fieldregen", "wandbleed"):
        if need not in armed_ids:
            sys.exit("FATAL: '%s' is not in this wave's armed string; this probe "
                     "would score a gate that was never on" % need)

    fr = {"armed": [], "base": []}
    wb = {"armed": [], "base": []}
    tot_copies = tot_blank_fr = tot_blank_wb = 0
    fr_frames = wb_frames = wb_noread = 0
    percentroid = []
    per_game = []

    for run, game, cand, seed, side, tl in games:
        g = Game(tl, args.interval)
        armed_team = SIDE_TEAM[side]
        tot_copies += g.copies
        fe, b1, n1 = scan_fieldregen(g)
        we, b2, n2, nr = scan_wandbleed(g, args.wand_band)
        tot_blank_fr += b1
        tot_blank_wb += b2
        fr_frames += n1
        wb_frames += n2
        wb_noread += nr
        for e in fe:
            e.update(run=run, game=game, seed=seed, side=side)
            fr["armed" if e["team"] == armed_team else "base"].append(e)
        for e in we:
            e.update(run=run, game=game, seed=seed, side=side)
            wb["armed" if e["team"] == armed_team else "base"].append(e)
        # positive control for the fountain centroid: the two team centroids
        # must sit far apart (opposite corners of the map).
        if RADIANT in g.fountain and DIRE in g.fountain:
            rx, ry = g.fountain[RADIANT]
            dx, dy = g.fountain[DIRE]
            percentroid.append(((rx ** 2 + ry ** 2) ** 0.5,
                                (dx ** 2 + dy ** 2) ** 0.5,
                                ((rx - dx) ** 2 + (ry - dy) ** 2) ** 0.5))
        per_game.append((run, game, seed, side, len(fe), len(we)))

    print("# fieldregen / wandbleed execution probe (owner P2 supply family)")
    print()
    print("games            : %d" % len(games))
    print("sampling interval: %.1fs" % args.interval)
    print("armed ids        : %d (%s ... %s)" % (len(armed_ids), armed_ids[0], armed_ids[-1]))
    print("idx-locked copies dropped: %d snapshots" % tot_copies)
    print("post-DEATH frames blanked: fieldregen %d, wandbleed %d (#78 guard, %.1fs)"
          % (tot_blank_fr, tot_blank_wb, DEATH_BLANK_S))
    if percentroid:
        rr = [p[0] for p in percentroid]
        dd = [p[1] for p in percentroid]
        sep = [p[2] for p in percentroid]
        print("fountain centroid positive control: |radiant| %.0f-%.0f, |dire| %.0f-%.0f,"
              " separation %.0f-%.0f u over %d games"
              % (min(rr), max(rr), min(dd), max(dd), min(sep), max(sep), len(percentroid)))

    print()
    print("## fieldregen -- domain frames %d, episodes armed %d / baseline %d"
          % (fr_frames, len(fr["armed"]), len(fr["base"])))
    for leg in ("armed", "base"):
        eps = fr[leg]
        acq = sum(1 for e in eps if e["flask_acquired_t"] is not None)
        drk = sum(1 for e in eps if e["flask_drunk_t"] is not None)
        print("  %-5s: %3d episodes, flask acquired within %.0fs: %d, drunk: %d"
              % (leg, len(eps), DELIVERY_S, acq, drk))
    print()
    print("## wandbleed -- own territory (enemy > %.0fu) frames %d, episodes armed %d / baseline %d"
          % (args.wand_band, wb_frames, len(wb["armed"]), len(wb["base"])))
    print("  frames dropped for no enemy read: %d" % wb_noread)
    for leg in ("armed", "base"):
        eps = wb[leg]
        used = sum(1 for e in eps if e["wand_used_t"] is not None)
        print("  %-5s: %3d episodes, wand/stick used: %d (%.1f%%)"
              % (leg, len(eps), used, 100.0 * used / len(eps) if eps else 0.0))

    print()
    print("## per-game domain supply (run, game, seed, armed-side, fr eps, wb eps)")
    for row in sorted(per_game):
        print("  %s %s s%s %-7s fr=%d wb=%d" % row)

    print()
    print("## fieldregen episodes (every one, both legs)")
    for leg in ("armed", "base"):
        for e in sorted(fr[leg], key=lambda x: (x["game"], x["t_start"])):
            print("  [%s] %s %s t=%.1f-%.1f hp_min=%.3f fountain=%.0fu nw_ok "
                  "acq=%s drank=%s"
                  % (leg, e["game"], e["hero"], e["t_start"], e["t_end"],
                     e["hp_min"], e["fountain_dist"],
                     ("%.1f" % e["flask_acquired_t"]) if e["flask_acquired_t"] else "-",
                     ("%.1f" % e["flask_drunk_t"]) if e["flask_drunk_t"] else "-"))

    print()
    print("## wandbleed episodes with the wand actually drunk")
    for leg in ("armed", "base"):
        for e in sorted((x for x in wb[leg] if x["wand_used_t"] is not None),
                        key=lambda x: (x["game"], x["t_start"])):
            print("  [%s] %s %s t=%.1f-%.1f hp_min=%.3f enemy_min=%.0fu used=%.1f"
                  % (leg, e["game"], e["hero"], e["t_start"], e["t_end"],
                     e["hp_min"], e["enemy_min"], e["wand_used_t"]))

    if args.selfcheck:
        rc = 0
        # 1. every episode's frames must be >= 1 and t_end >= t_start
        for d in (fr, wb):
            for leg in d:
                for e in d[leg]:
                    if e["frames"] < 1 or e["t_end"] < e["t_start"]:
                        print("SELFCHECK FAIL: malformed episode %r" % e)
                        rc = 2
        # 2. no fieldregen episode may already hold a flask/tango at t_start
        for leg in fr:
            for e in fr[leg]:
                g = None
                for run, game, cand, seed, side, tl in games:
                    if game == e["game"] and run == e["run"]:
                        g = Game(tl, args.interval)
                        break
                s = g.frame_at(e["hero"], e["t_start"])
                if s is None or has(s["items"], "flask") or has(s["items"], "tango"):
                    print("SELFCHECK FAIL: %s %s t=%.1f already had healing"
                          % (e["game"], e["hero"], e["t_start"]))
                    rc = 2
        # 3. laning-phase predicate must reject a pre-480s frame outright
        if is_laning(479.9, 99999) is not True or is_laning(600.1, 0) is not False:
            print("SELFCHECK FAIL: is_laning() disagrees with jmz_func.lua:9194")
            rc = 2
        # 4. the fountain centroids must be far apart in EVERY game
        for r, d, sep in percentroid:
            if sep < 10000:
                print("SELFCHECK FAIL: fountain centroids only %.0fu apart" % sep)
                rc = 2
        print()
        print("SELFCHECK: %s" % ("PASS" if rc == 0 else "FAIL"))
        sys.exit(rc)


if __name__ == "__main__":
    main()
