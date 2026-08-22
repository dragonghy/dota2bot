#!/usr/bin/env python3
"""Attribute rescue TPs to lf_rescue on a replay timeline, and trace the landing.

Written for issue #37 (replay-check, 2026-08-19). Read-only: consumes the
dumper timeline + analysis.json that sweep_run.sh already produces, launches
nothing and costs nothing.

Two passes:
  A) TP-CAST pass  -- for every item_tpscroll cast by an armed-side hero,
     test whether the J.GetRescueTpTarget preconditions held at the cast
     instant (ITEM events are 0.1s-accurate, unlike the 1Hz snapshots).
     Those are the candidate rescue TPs; then trace where they landed.
  B) OPPORTUNITY pass -- for every 1Hz frame, enumerate (responder, ally)
     pairs that satisfy every OBSERVABLE precondition. Superset of real
     triggers (GetEstimatedDamageToTarget is not in the replay, so the
     nVsMe / WillAllySurviveTpWindow damage gates cannot be judged offline).

The landing is what makes attribution possible: J.GetNearbyLocationToTp is
deterministic (nearest ALIVE own tower, offset 575 toward the ally), so a
landing that matches it is lf_rescue, and one anchored on a different tower
(typically one under attack) is a defend-TP branch whose cast instant merely
coincided. In the #37 wave that separated 11 real rescues from 9 lookalikes.

Two gotchas paid for already: `buildings` contains watch_tower/barracks/ancient
as well as tower (exclude the rest when picking "nearest tower"), and corpse
frames carry hp_pct == 0.

IDENTITY (2026-08-22, GH #69 section 6): snapshots are keyed by hero NAME, and a
hero's illusions/copies carry the same name.  Merging them and taking "the last
frame with t <= t" hands back a copy on 2.80% of calls (median position error
3,087 u).  That is not a rounding error here -- measured on the `lf_rescue`
bisect corpus it reaches three separate predicates in `gate()`:
  * the diver count, where a copy standing in for the body HIDES the enemy who
    is at that instant killing the ally (`20260819_143059_slot1` t=488.4:
    chaos_knight's body 62 u from the dying Venomancer and alive, while the copy
    the merged map returned sat 1,844 u away reading hp 0 -> divers 2, not 3);
  * the responder's `dist > 3500` clause, where a copy parked next to the ally
    makes a real cross-map rescuer look local and the cast is discarded
    (`20260819_122930_slot1` t=456.5: Lich body 6,049 u from its own copy);
  * the ally's `hp_pct < 0.35` clause, where a copy's HP is substituted for the
    body's and invents a dying ally (`20260819_143611_slot1` t=476.0:
    chaos_knight copy 0.289 vs body 0.648).
So `TL` locks onto the body by entity id, keyed on EARLIEST first appearance (the
body is present from the ~-75s pre-game frame, a copy is not).  `hp`, `hp_max`
and `items` cannot separate them: the copies in this corpus are field-for-field
identical to the body.  `IDX_LOCK = False` (or --legacy-merge-by-name) restores
the old merged behaviour for reproducing a pre-2026-08-22 reading; the measured
cell-by-cell delta is in tp_attribution_idxlock_audit.py.

Usage: tp_attribution.py <timeline.json> <analysis.json> <radiant|dire> [--json out]
       where <side> is the mirror stamp's armed side for that game
       (see games_manifest.jsonl from sweep_run.sh).
"""
import json, math, os, sys, argparse
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "soak"))
import seed_draft  # noqa: E402  -- the only correct source of a hero's position

RAD, DIRE = 2, 3

# Lock every by-name snapshot lookup onto the body entity (see IDENTITY above).
# Set False only to reproduce a reading published before 2026-08-22.
IDX_LOCK = True


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def primary_idx(snapshots):
    """{hero: idx of the body}, keyed on EARLIEST first appearance.

    Same rule as axe_blink_domain.primary_idx.  Frame count is the weaker
    discriminator (a copy can outlive the body's visible frames); first
    appearance is the one the charter mandates.
    """
    first = {}
    for s in snapshots:
        key = (s["hero"], s["idx"])
        if key not in first or s["t"] < first[key]:
            first[key] = s["t"]
    out = {}
    for (hero, idx), t0 in first.items():
        if hero not in out or t0 < out[hero][1]:
            out[hero] = (idx, t0)
    return {h: v[0] for h, v in out.items()}


class TL:
    def __init__(self, path):
        d = json.load(open(path))
        self.teams = d["game"]["teams"]
        self.events = sorted(d["events"], key=lambda e: e["t"])
        snaps = d["snapshots"]
        if IDX_LOCK and snaps and "idx" not in snaps[0]:
            sys.exit("[fatal] %s: this timeline has no snapshots[].idx, so the "
                     "body cannot be told from a copy; re-dump with the current "
                     "dumper or set IDX_LOCK=False and accept the artifact"
                     % path)
        prim = primary_idx(snaps) if IDX_LOCK else {}
        self.n_copy_entities = (len({(s["hero"], s["idx"]) for s in snaps}) - len(prim)
                                if IDX_LOCK else None)
        self.snaps = defaultdict(list)
        for s in snaps:
            if IDX_LOCK and prim.get(s["hero"]) != s["idx"]:
                continue
            self.snaps[s["hero"]].append(s)
        for h in self.snaps:
            self.snaps[h].sort(key=lambda s: s["t"])
        # frame times (union, rounded).  Built from the body frames under the
        # lock: on the 32-game lf_rescue corpus the copies contributed 0 unique
        # timestamps in 32/32 games, so pass B's loop domain is unchanged there
        # -- that is a reading of that corpus, not a property of the dumper.
        self.frames = sorted({round(s["t"], 1)
                              for v in self.snaps.values() for s in v})
        # buildings: per timestamp list
        self.bld = defaultdict(list)
        for b in d["buildings"]:
            self.bld[round(b["t"], 1)].append(b)
        self.bld_times = sorted(self.bld)

    def at(self, hero, t, tol=1.2):
        """snapshot of hero nearest t (<= t preferred)"""
        arr = self.snaps.get(hero)
        if not arr:
            return None
        best = None
        for s in arr:
            if s["t"] <= t + 0.01:
                best = s
            else:
                break
        if best is None or t - best["t"] > tol:
            # allow slightly-later frame
            for s in arr:
                if abs(s["t"] - t) <= tol:
                    return s
            return None
        return best

    def towers(self, t, team):
        """alive towers of `team` at the building-snapshot nearest t"""
        if not self.bld_times:
            return []
        bt = min(self.bld_times, key=lambda x: abs(x - t))
        return [b for b in self.bld[bt]
                if b["team"] == team and b["alive"] and "tower" in b["name"]]


def fountain(team):
    return (-7200.0, -6666.0) if team == RAD else (7000.0, 6500.0)


def alive(s):
    return s is not None and s.get("hp_pct", 0) > 0


def scan(tlpath, ajpath, side):
    tl = TL(tlpath)
    aj = json.load(open(ajpath))
    # Position comes from the SEED's draft, never from `team_slot` -- the pick
    # slot is reshuffled per game by the engine's unseeded RandomInt and is only
    # 47.3% accurate as a role label (GH #57).  Unattributable games (warm-ups
    # carry no seed in the stamp) get an empty map, so `pos.get(...)` falls back
    # to its declared default instead of to a coin flip.
    pos = seed_draft.positions_for_game(aj)
    if pos is None:
        print("[warn] %s: no seed in the mirror stamp -- positions unknown, every "
              "pos-conditioned branch falls back to its declared default"
              % ajpath, file=sys.stderr)
        pos = {}
    armed_team = RAD if side == "radiant" else DIRE
    heroes = list(tl.teams)
    mine = [h for h in heroes if tl.teams[h] == armed_team]
    foes = [h for h in heroes if tl.teams[h] != armed_team]

    deaths = defaultdict(list)
    for e in tl.events:
        if e["type"] == "DEATH":
            deaths[e["target"]].append(e["t"])

    def last_death_before(h, t):
        d = [x for x in deaths[h] if x <= t]
        return d[-1] if d else -999

    def gate(t, R, A, rs, asn):
        """returns (ok, reasons_failed) for the observable lf_rescue predicates"""
        bad = []
        if t <= 0 or t > 900:
            bad.append("t_window")
        if rs["hp_pct"] < 0.60:
            bad.append("resp_hp<60")
        if t - last_death_before(R, t) < 15.0:
            bad.append("fresh_respawn")
        if t < 480 and pos.get(R, 5) <= 3:
            bad.append("core_in_laning")
        d = dist(rs["x"], rs["y"], asn["x"], asn["y"])
        if d <= 3500:
            bad.append("dist<=3500")
        if asn["hp_pct"] >= 0.35:
            bad.append("ally_hp>=35")
        divers = [f for f in foes
                  if alive(tl.at(f, t)) and dist(tl.at(f, t)["x"], tl.at(f, t)["y"],
                                                 asn["x"], asn["y"]) <= 900]
        if not (1 <= len(divers) <= 2):
            bad.append("divers=%d" % len(divers))
        for b in tl.towers(t, armed_team):
            if dist(b["x"], b["y"], asn["x"], asn["y"]) <= 900:
                bad.append("ally_under_own_tower")
                break
        return (not bad), bad, divers, d

    # ---------- pass A: TP casts ----------
    cast_hits = []
    for e in tl.events:
        if e["type"] != "ITEM" or e["inflictor"] != "item_tpscroll":
            continue
        R = e["actor"]
        if tl.teams.get(R) != armed_team:
            continue
        t = e["t"]
        rs = tl.at(R, t)
        if not alive(rs):
            continue
        for A in mine:
            if A == R:
                continue
            asn = tl.at(A, t)
            if not alive(asn):
                continue
            ok, bad, divers, d = gate(t, R, A, rs, asn)
            if not ok:
                continue
            # landing trace
            land = None
            for dt in (3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0):
                cand = tl.at(R, t + dt, tol=0.6)
                if cand and dist(cand["x"], cand["y"], rs["x"], rs["y"]) > 1500:
                    land = cand
                    break
            a_land = tl.at(A, land["t"]) if land else None
            # predicted landing per J.GetNearbyLocationToTp
            tw = tl.towers(t, armed_team)
            pred = None
            if tw:
                nearest = min(tw, key=lambda b: dist(b["x"], b["y"], asn["x"], asn["y"]))
                vx, vy = asn["x"] - nearest["x"], asn["y"] - nearest["y"]
                n = math.hypot(vx, vy) or 1
                pred = (nearest["x"] + vx / n * 575, nearest["y"] + vy / n * 575)
            fx, fy = fountain(armed_team)
            rec = dict(t=t, responder=R, resp_pos=pos.get(R), resp_hp=rs["hp_pct"],
                       ally=A, ally_hp=asn["hp_pct"], dist=round(d),
                       divers=[x for x in divers],
                       ally_xy=[asn["x"], asn["y"]],
                       resp_xy=[rs["x"], rs["y"]])
            if land:
                rec["land_t"] = land["t"]
                rec["land_xy"] = [land["x"], land["y"]]
                rec["land_to_ally"] = round(dist(land["x"], land["y"],
                                                 a_land["x"], a_land["y"])) if alive(a_land) else None
                rec["land_to_ally_at_cast"] = round(dist(land["x"], land["y"], asn["x"], asn["y"]))
                rec["land_to_fountain"] = round(dist(land["x"], land["y"], fx, fy))
                rec["ally_alive_at_land"] = bool(alive(a_land))
            if pred:
                rec["pred_xy"] = [round(pred[0]), round(pred[1])]
                rec["pred_to_ally"] = round(dist(pred[0], pred[1], asn["x"], asn["y"]))
                rec["pred_to_fountain"] = round(dist(pred[0], pred[1], fx, fy))
            # outcome: ally death / responder death within 15s
            rec["ally_died_15s"] = any(t <= x <= t + 15 for x in deaths[A])
            rec["resp_died_15s"] = any(t <= x <= t + 15 for x in deaths[R])
            cast_hits.append(rec)

    # ---------- pass B: opportunity frames ----------
    opps = []
    for t in tl.frames:
        if t <= 0 or t > 900:
            continue
        for A in mine:
            asn = tl.at(A, t, tol=0.6)
            if not alive(asn) or asn["hp_pct"] >= 0.35:
                continue
            for R in mine:
                if R == A:
                    continue
                rs = tl.at(R, t, tol=0.6)
                if not alive(rs):
                    continue
                ok, bad, divers, d = gate(t, R, A, rs, asn)
                if ok:
                    opps.append(dict(t=t, responder=R, resp_pos=pos.get(R),
                                     ally=A, ally_hp=asn["hp_pct"], dist=round(d),
                                     divers=divers, tp_cd=rs.get("tp_cd")))
    return cast_hits, opps


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("timeline")
    ap.add_argument("analysis")
    ap.add_argument("side")
    ap.add_argument("--json")
    ap.add_argument("--legacy-merge-by-name", action="store_true",
                    help="merge same-name entities as before 2026-08-22 "
                         "(reproduces older readings; see IDENTITY in the "
                         "module docstring for what it costs)")
    a = ap.parse_args()
    if a.legacy_merge_by_name:
        IDX_LOCK = False        # module scope: this block IS module level
        print("[warn] --legacy-merge-by-name: same-name copies are merged; "
              "2.80% of snapshot lookups return a copy", file=sys.stderr)
    ch, op = scan(a.timeline, a.analysis, a.side)
    out = dict(timeline=a.timeline, side=a.side, cast_hits=ch, opportunities=op)
    if a.json:
        json.dump(out, open(a.json, "w"), indent=1)
    print("cast_hits=%d opportunity_frames=%d (distinct episodes ~%d)"
          % (len(ch), len(op), len({(o["responder"], o["ally"], int(o["t"] // 10)) for o in op})))
    for r in ch:
        print(json.dumps(r))
