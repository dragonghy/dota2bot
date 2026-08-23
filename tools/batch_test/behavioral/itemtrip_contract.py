#!/usr/bin/env python3
"""Discharge `itemtrip`'s pre-registered contract from real frames.

WHY THIS TOOL EXISTS -- the prediction was registered BEFORE the wave.
`bots/mode_item_generic.lua` installs a `GetDesire` only when the soak id
`itemtrip` is armed; that GetDesire returns `BOT_MODE_DESIRE_NONE` on the
wasteful profile and **nil** everywhere else.  Its header states plainly that
the nil branch rests on an undischarged engine contract
(`docs/BOT_API_REFERENCE.md:52`, zero users in this tree) and names the two
outcomes it cannot tell apart from the source:

  * nil FALLS THROUGH -> armed == built-in bid minus the wasteful frames,
    i.e. the lever as designed;
  * nil is read as 0  -> item mode is OFF for the whole armed game, which is
    what `bots/--mode_item_generic.lua` did before somebody renamed it.

and it registers the discriminator: "if item-mode home trips drop only in
#120's wasteful profile the contract holds; if they drop to ~0 the contract is
false".  This tool is that discriminator, run on the first wave where
`itemtrip` was armed (06:11Z 2026-08-23, 25-id string).

METHOD.  It consumes the `--jsonl` rows of `hometp_highhp.py` (the same tool
that produced #120's 643/76 attribution) and splits the UNEXPLAINED population
-- the rows no branch in `bots/` can explain, i.e. the observable shadow of
Valve's built-in BOT_MODE_ITEM -- by whether `J.IsWastefulItemTrip` could have
fired on that row's pre-cast frame:

  IN-DOMAIN      every clause of the predicate that a replay can see is
                 satisfied  ->  the armed leg's GetDesire returned NONE here,
                 so an armed row in this bucket is the lever failing.
  OUT-OF-DOMAIN  at least one clause is DEFINITELY false (an enemy inside
                 1600, or the fountain closer than 5000) -> the armed leg
                 returned nil here.  This bucket is the control: it is where
                 the two contract branches disagree.
  UNRESOLVED     the attributed-damage clause cannot be scored offline on this
                 row (see below).  Never counted into either verdict.

THE THREE HONEST BOUNDARIES, stated up front:

 1. `hometp_highhp.py` only carries `hit6` = WasRecentlyDamagedByAnyHero(6.0)
    (the 撤退:2 clause), while the predicate reads 3.0 AND requires the hero
    that dealt it to still be within 3000.  So a row with `hit6` and the
    nearest enemy inside 3000 is UNRESOLVED, not in-domain -- the 6s lookback
    can only over-report danger, so this only ever SHRINKS the in-domain
    bucket, never inflates it.
 2. The bot's mode is invisible in a replay (13th world assertion).
    "unexplained" is a necessary-condition attribution, not a mode readout:
    it means no branch in bots/ could have produced the TP.  Every claim below
    is about that population, and is stated that way.
 3. This population is home *TPs*.  Item mode can also walk, and a walk home
    is not in `hometp_highhp.py`'s population at all.  So a drop measured here
    is a drop in the TP half; silence here is NOT proof the mode never ran.

Usage:
  itemtrip_contract.py <rows.jsonl> --games-armed N --games-base N
  itemtrip_contract.py --selfcheck
"""

import argparse
import json
import os
import sys

HP_FLOOR = 0.55       # jmz_func.lua:4994  (J.GetHP < 0.55 -> not wasteful)
RING_U = 1600.0       # :4998
ATTR_U = 3000.0       # :5003  the ring the attributed-damage clause sweeps
FDIST_MIN = 5000.0    # :5014  GetDistanceFromAllyFountain < 5000 -> not it


def classify(r):
    """IN / OUT / UNRESOLVED for one home-TP row, from its pre-cast frame."""
    hp = r.get("hp")
    if hp is None or hp < HP_FLOOR:
        # hometp_highhp's population is hp > HP_HI already; a row below the
        # floor would be a caller error, not a classification.
        return "UNRESOLVED", "hp below the predicate floor"

    n1600 = r.get("n_enemy_1600")
    fdist = r.get("fdist")
    if n1600 is None or fdist is None:
        return "UNRESOLVED", "missing ring or fountain distance"

    if n1600 > 0:
        return "OUT", "enemy inside 1600 (%d)" % n1600
    if fdist < FDIST_MIN:
        return "OUT", "fountain %.0fu < 5000" % fdist

    # Only the attributed-damage clause is left, and it is the one the row
    # cannot score exactly (boundary 1 in the docstring).
    if r.get("hit6"):
        emin = r.get("enemy_min")
        if emin is None or emin <= ATTR_U:
            return "UNRESOLVED", "hit within 6s and nearest enemy %s" % (
                "unknown" if emin is None else "%.0fu <= 3000" % emin)
        return "IN", "hit within 6s but nearest enemy %.0fu > 3000" % emin
    return "IN", "no hero damage in 6s"


def per_game(n, games):
    return (n / float(games)) if games else float("nan")


def report(rows, ga, gb, cases):
    def sel(leg, pred=lambda r: True):
        return [r for r in rows if r["leg"] == leg and pred(r)]

    print("=== population (hometp_highhp rows, pre-cast HP > 0.55) ===")
    print("%-9s %5s %8s   %s" % ("leg", "rows", "/game", "games"))
    for leg, ng in (("armed", ga), ("baseline", gb)):
        s = sel(leg)
        print("%-9s %5d %8.3f   %d" % (leg, len(s), per_game(len(s), ng), ng))

    unex = [r for r in rows if r["labels"] == ["unexplained"]]
    print("\n=== UNEXPLAINED only (the BOT_MODE_ITEM shadow, #120's 76) ===")
    print("%-14s %8s %8s %8s %8s %8s" %
          ("bucket", "armed", "/game", "base", "/game", "ratio"))
    tot = {}
    for bucket in ("IN", "OUT", "UNRESOLVED"):
        a = [r for r in unex if r["leg"] == "armed"
             and classify(r)[0] == bucket]
        b = [r for r in unex if r["leg"] == "baseline"
             and classify(r)[0] == bucket]
        tot[bucket] = (len(a), len(b))
        ra, rb = per_game(len(a), ga), per_game(len(b), gb)
        ratio = ("%.2f" % (ra / rb)) if rb else "n/a"
        print("%-14s %8d %8.3f %8d %8.3f %8s"
              % (bucket, len(a), ra, len(b), rb, ratio))

    print("\n=== contract discrimination ===")
    (ia, ib), (oa, ob) = tot["IN"], tot["OUT"]
    ira, irb = per_game(ia, ga), per_game(ib, gb)
    ora, orb = per_game(oa, ga), per_game(ob, gb)
    print("  in-domain  armed %.3f/game vs baseline %.3f/game" % (ira, irb))
    print("  out-domain armed %.3f/game vs baseline %.3f/game" % (ora, orb))
    print("  The lever can only act in-domain.  So:")
    print("    * in-domain DOWN and out-domain FLAT -> nil falls through, "
          "contract HOLDS, lever WORKING")
    print("    * BOTH near zero on the armed leg      -> nil read as 0, "
          "item mode OFF all game, contract FALSE")
    print("    * in-domain FLAT                       -> lever SILENT "
          "(or this population is not item mode)")

    print("\n=== in-domain armed rows (each one is the lever not firing) ===")
    ind = [r for r in unex if r["leg"] == "armed" and classify(r)[0] == "IN"]
    ind.sort(key=lambda r: -(r.get("fdist") or 0))
    for r in ind[:cases]:
        t = r.get("trip") or {}
        print("  %s %s %-22s t=%.1f hp=%.2f fdist=%.0f enemy_min=%s "
              "trip=%ss gain=%s"
              % (r["run"][-6:], r["game"], r["hero"], r["t_cast"], r["hp"],
                 r["fdist"],
                 "%.0f" % r["enemy_min"] if r.get("enemy_min") else "none",
                 ("%.1f" % t["trip_s"]) if t.get("trip_s") else "?",
                 ",".join(t.get("items_gain") or []) or "-"))
    if len(ind) > cases:
        print("  ... %d more" % (len(ind) - cases))


def selfcheck():
    """Guards on the classifier itself.  Each mirrors a clause in the Lua."""
    ok = True

    def chk(name, cond):
        nonlocal ok
        print("  %-46s %s" % (name, "PASS" if cond else "FAIL"))
        ok = ok and cond

    base = {"hp": 0.9, "n_enemy_1600": 0, "fdist": 9000.0,
            "hit6": False, "enemy_min": 8000.0}

    def with_(**kw):
        d = dict(base)
        d.update(kw)
        return d

    chk("clean healthy far frame -> IN", classify(base)[0] == "IN")
    chk("enemy inside 1600 -> OUT",
        classify(with_(n_enemy_1600=1))[0] == "OUT")
    chk("fountain 4999 -> OUT", classify(with_(fdist=4999.0))[0] == "OUT")
    chk("fountain 5000 -> IN", classify(with_(fdist=5000.0))[0] == "IN")
    chk("hit6 with enemy 2000 -> UNRESOLVED",
        classify(with_(hit6=True, enemy_min=2000.0))[0] == "UNRESOLVED")
    chk("hit6 with enemy 9000 -> IN",
        classify(with_(hit6=True, enemy_min=9000.0))[0] == "IN")
    chk("hit6 with unknown enemy -> UNRESOLVED",
        classify(with_(hit6=True, enemy_min=None))[0] == "UNRESOLVED")
    chk("hp below floor -> UNRESOLVED", classify(with_(hp=0.4))[0]
        == "UNRESOLVED")
    # The ring clause must dominate the distance clause: a row with BOTH an
    # enemy near and a short walk is OUT for the ring reason, and either
    # reason keeps it out of the in-domain bucket.
    chk("enemy near AND close fountain -> OUT",
        classify(with_(n_enemy_1600=2, fdist=100.0))[0] == "OUT")
    # A missing field must never silently read as in-domain.
    chk("missing fdist -> UNRESOLVED", classify(with_(fdist=None))[0]
        == "UNRESOLVED")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("jsonl", nargs="?")
    ap.add_argument("--games-armed", type=int, default=0)
    ap.add_argument("--games-base", type=int, default=0)
    ap.add_argument("--cases", type=int, default=15)
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        sys.exit(0 if selfcheck() else 1)

    if not a.jsonl or not os.path.exists(a.jsonl):
        sys.exit("usage: itemtrip_contract.py <rows.jsonl> "
                 "--games-armed N --games-base N")
    rows = [json.loads(x) for x in open(a.jsonl) if x.strip()]
    if not rows:
        sys.exit("[fatal] no rows")
    report(rows, a.games_armed or 1, a.games_base or 1, a.cases)


if __name__ == "__main__":
    main()
