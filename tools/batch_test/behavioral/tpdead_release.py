#!/usr/bin/env python3
"""Condition-(a) verifier for the `tpdead` soak candidate (GH #37 rec 3).

`tpdead` releases the tpcommit DEFEND floor (clears bot.tpRespondUntil /
tpRespondAlly, returns nil sooner) the moment the ally a rescue TP was
stamped for is no longer alive -- so the responder is not held in DEFEND,
walking at a fight that no longer exists, for the rest of the 12s pin.

This driver reuses tp_attribution.scan() to attribute rescue TPs (landing must
match the deterministic J.GetNearbyLocationToTp within --land-err), keeps only
the ones whose rescued ally DIES inside the 12s pin window (tpdead's trigger),
and measures, per attributed rescue, the responder's motion in the settled
post-landing frames RELATIVE TO tpRespondLoc (= ally location at cast), gated on
whether the pin WOULD have held (an enemy still within 1600 of tpRespondLoc).

The discriminator: with tpdead ARMED, a full-HP responder walks AWAY from
tpRespondLoc while the pin condition still holds (released); with it DISARMED,
the responder holds position near tpRespondLoc for the whole window (pinned).
The enemy-present gate is what makes the release attributable to tpdead and not
to the floor's own "no enemy near respLoc -> return nil" self-release clause.

Read-only: consumes the timelines/analysis that sweep_run.sh already produced,
launches nothing, costs nothing. Requires a .sweep_out dir built by sweep_run.sh.

Usage:
  tpdead_release.py <sweep_out_dir>...  [--land-err 600] [--json out.json]
Each <sweep_out_dir> is one run's tools/batch_test/behavioral/.sweep_out/<run>/.
Whether tpdead is armed for a run is read from games_manifest.jsonl's cand list.

Gotchas paid for already (see replay-check.md 工具坑):
- the 1Hz TP-landing jump makes a naive first->last displacement huge-negative
  (the responder appears one frame before it teleports in); measure only frames
  where the responder is already within --settle-radius of tpRespondLoc and >=
  1.5s past the cast.
- snapshots[].hero carries the underscored full name; DEATH events' target does
  too in recent dumps (canon-check both).
- release != forced retreat: a released responder may still engage the divers
  if normal-mode desire wants to (honest non-attributable frames), so the
  finding is a DIRECTIONAL population diff + frame exemplars, not every frame.
"""
import json, os, sys, math, argparse, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tp_attribution as TA


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def rescues_where_ally_dies(sweep_dir, land_err):
    """Yield (rec, tl, tpdead_on) for attributed rescues whose ally dies in window."""
    d = sweep_dir.rstrip("/") + "/"
    for line in open(d + "games_manifest.jsonl"):
        g = json.loads(line)
        game, side = g["game"], g["side"]
        tlp = d + "timelines/%s.timeline.json" % game
        ajp = d + "analysis/%s.analysis.json" % game
        if not os.path.exists(tlp):
            continue
        try:
            ch, _ = TA.scan(tlp, ajp, side)
        except Exception as e:
            print("[warn] scan failed %s: %s" % (game, e), file=sys.stderr)
            continue
        on = "tpdead" in g["cand"].split(",")
        tl = TA.TL(tlp)
        for r in ch:
            if r.get("land_pred_err", 1e9) if "land_pred_err" in r else None:
                pass
            # recompute landing error here (scan does not store it)
            if "land_xy" not in r or "pred_xy" not in r:
                continue
            if dist(r["land_xy"], r["pred_xy"]) > land_err:
                continue
            if not r.get("ally_died_15s"):
                continue
            r.update(run=os.path.basename(sweep_dir.rstrip("/")), game=game,
                     side=side, seed=g.get("seed"), tpdead=on)
            yield r, tl


def measure(rec, tl, settle_radius=7000):
    R, A, tc, side = rec["responder"], rec["ally"], rec["t"], rec["side"]
    armed = TA.RAD if side == "radiant" else TA.DIRE
    foes = [h for h in tl.teams if tl.teams[h] != armed]
    asn_c = tl.at(A, tc)
    if not asn_c:
        return None
    rloc = (asn_c["x"], asn_c["y"])
    deaths = [e["t"] for e in tl.events
              if e["type"] == "DEATH" and e["target"] == A and tc <= e["t"] <= tc + 12]
    if not deaths:
        return None
    dt = deaths[0]
    seq = []
    for fr in tl.frames:
        if fr < max(dt, tc + 1.5) - 0.1 or fr > tc + 12.2:
            continue
        rs = tl.at(R, fr, tol=0.6)
        if not rs or rs.get("hp_pct", 0) <= 0:
            continue
        drl = dist((rs["x"], rs["y"]), rloc)
        if drl > settle_radius:
            continue  # not landed yet / off-map (the 1Hz jump)
        ne = sum(1 for f in foes
                 if (lambda fs: fs and fs.get("hp_pct", 0) > 0
                     and dist((fs["x"], fs["y"]), rloc) <= 1600)(tl.at(f, fr, tol=0.6)))
        seq.append((fr, drl, ne))
    if len(seq) < 2:
        return None
    return dict(arm="ON" if rec["tpdead"] else "OFF", run=rec["run"][:22],
                game=rec["game"][-14:], resp_hp=round(rec["resp_hp"], 2),
                settled_disp=round(seq[-1][1] - seq[0][1]),
                pin_held_frames=sum(1 for s in seq if s[2] > 0), frames=len(seq))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("sweep_dirs", nargs="+")
    ap.add_argument("--land-err", type=float, default=600)
    ap.add_argument("--json")
    a = ap.parse_args()
    rows = []
    for sd in a.sweep_dirs:
        for rec, tl in rescues_where_ally_dies(sd, a.land_err):
            m = measure(rec, tl)
            if m:
                rows.append(m)
    for arm in ("ON", "OFF"):
        s = [r for r in rows if r["arm"] == arm]
        away = sum(1 for r in s if r["settled_disp"] > 400)
        ds = sorted(r["settled_disp"] for r in s)
        med = ds[len(ds) // 2] if ds else None
        print("%s n=%d median_settled_disp=%s moved_AWAY(>400u)=%d/%d"
              % (arm, len(s), med, away, len(s)))
    if a.json:
        json.dump(rows, open(a.json, "w"), indent=1)
        print("wrote %s (%d rows)" % (a.json, len(rows)), file=sys.stderr)
