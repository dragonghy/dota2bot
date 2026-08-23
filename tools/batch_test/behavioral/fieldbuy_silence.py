#!/usr/bin/env python3
"""Why does a salve sit in the backpack when a per-frame rescuer is running?

GH #123 §5 (strategy, 2026-08-22T21:06Z) handed this question back to the replay
desk: `TrySwapInvItemForFlask()` is reached from `GetDesireHelper` on EVERY
frame for EVERY mode file, throttled ~6.2s -- so how can a salve stay in the
backpack for 30 seconds?  GH #123 §3 (replay desk, 2026-08-23T05:10Z) narrowed
it: 9 of 11 field-STUCK windows showed no nine-slot signature change AT ALL --
not the salve, not the clarity, not anything.  The silence is FAMILY-WIDE, so
the suspicion moved one level upstream, to `GetDesireHelper`'s early return or
to the `GetActiveMode() == BOT_MODE_WARD` branch (which does not even stamp the
throttle).  That grid square was handed to the strategy group.

WHY THIS TOOL EXISTS
--------------------
That 9/11 is a single-run reading (34 games of one wave).  This desk has twice
published a single-wave reading that later turned out to be an artifact of the
wave (#117's 离家中位数; #120/itemtrip's in-band/out-of-band bucket ratio), and
both times the tell was that nobody had measured the between-wave variance of
the quantity being read.  So:

  (1) replicate the family-silence rate on an INDEPENDENT wave, and
  (2) test the one upstream hypothesis that is observable offline.

WARD, AND WHAT AN INVENTORY CAN AND CANNOT SAY ABOUT IT
-------------------------------------------------------
`GetActiveMode() == BOT_MODE_WARD` cannot be read from a replay: the dumper
carries no mode (dumper/main.go has no mode field at all).  What a replay CAN
read is a NECESSARY condition -- ward mode exists to plant a ward, and
`mode_ward_generic` bids on a ward the bot is CARRYING.  So the test is
one-directional and is reported as one:

  * ward-holding strongly enriched in the silent windows -> the hypothesis
    survives this corpus and is worth a Lua-side experiment;
  * ward-holding at or below the control rate -> the necessary condition is
    absent, and the WARD branch cannot be the general cause of the silence.

It can REFUTE.  It cannot confirm: holding a ward does not put a bot in ward
mode, and the bid can lose to another mode on the same frame.

CONTROL GROUP, stated before the numbers
----------------------------------------
The comparison is between two populations that differ ONLY in the outcome the
rescuer is supposed to produce, on the same item, in the same corpus:

  STUCK    -- salve lands in slots 6-8, never reaches 0-5, never gets used
              within the watch window, still there 5s on (fieldbuy_domain's
              `_stuck_in_backpack`, unchanged -- this tool does not re-define
              the population #123 reported).
  RESCUED  -- salve lands in slots 6-8 and DOES reach 0-5 (or leaves the nine
              slots) inside the same window.  This is the rescuer visibly
              working; 05:10Z pinned one such frame (182012_slot1 t=372.2,
              Δ=6.0s).
  SHORT    -- ⭐ NEITHER, and the first draft of this tool did not have it.
              `_stuck_in_backpack` returns False on THREE different grounds,
              and only two of them mean "rescued": the third is `saw_late ==
              False`, i.e. the window ran out (death, disconnect, end of data)
              before the 5s settle point, so nothing is known.  Reading STUCK's
              complement as RESCUED silently folded those undecidable windows
              into the control -- and they are exactly the windows where the
              salve never moved, which would have biased the control's silence
              rate UPWARD and made the comparison read weaker than it is.  The
              selfcheck assertion "RESCUED can never be silent" is what caught
              it; it is kept below as a live assertion, not a comment.

All three are conditioned on the gain being IN FIELD (outside the fountain
ring), so no population is contaminated by stash pickups.

REGISTERED TRAPS THIS TOOL OBEYS (charter iterations/streams/replay-check.md)
----------------------------------------------------------------------------
  * freeze tail (#130): the last ~25.0s of every replay is frozen, so a window
    that reaches into it would read as "nothing ever changed" BY CONSTRUCTION.
    Gains whose watch window is not entirely clear of the tail are DROPPED, and
    the drop count is printed.  05:10Z checked this by hand (min 87s of margin);
    here it is a guard, not a hand check.
  * corpse frames carry an EMPTY items list -- they are not "no ward" and not a
    signature change.  Only alive frames with an items row are scored, and the
    alive-frame count is printed per population so a corpse-dominated window
    cannot masquerade as silence.
  * idx lock / canon hero names come from Game (stayfield_domain), unchanged.
  * armed-string guard: this tool reads BOTH legs on purpose (the rescuer is
    shipped, ungated code), but it still refuses a corpus where `fieldbuy` was
    never armed, because the STUCK population only exists downstream of it.

HONEST BOUND ON THE SILENCE MEASURE ITSELF (inherited from 05:10Z §3)
---------------------------------------------------------------------
"The nine-slot signature never changed" is a PROXY for "the rescuer did not
run".  A call that returns -1, or a swap between two identically-named items,
leaves no trace.  What is directly observed is only "the salve never moved".

Read-only, offline; consumes sweep_run.sh output dirs.  Touches no AWS
resource beyond the S3 reads sweep_run.sh already did.
"""
import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from stayfield_domain import (                     # noqa: E402
    Game, load_sweeps, usable_items, DEATH_BLANK_S,
)
from fieldbuy_domain import (                      # noqa: E402
    CAND_ID, FLASK, all_items, has_items_row, flask_gains,
    BACKPACK_WATCH_S, FOUNTAIN_PICKUP_U,
)

# The frozen tail every replay in this corpus carries (#130, GH-registered,
# measured at ~25.0s over 40 sampled games).  A watch window overlapping it
# would show an unchanging inventory for a reason that has nothing to do with
# the rescuer, so windows are required to clear it with this much room.
FREEZE_TAIL_S = 25.0

# "Nothing changed for thirty seconds" is only a statement about behaviour if
# there were thirty seconds of frames to look at.  At the 1.0s sampling
# interval a full window is ~30 frames; FULL windows are the ones the silence
# rate is reported on, because a two-frame window is silent for free.  This is
# a measurement floor of this tool, not a mirror of anything in the Lua.
FULL_MIN_FRAMES = 20

# Own-fountain ring: inside this the bot is home (same constant the family's
# other tools use for "the stash hands it over by itself").
HOME_RING_U = FOUNTAIN_PICKUP_U
# A one-sample displacement no hero can walk.  The charter's measured ceiling
# over this corpus's hero pool is 660 u/s (registered 2026-08-23T09:09Z, after
# a stale 550 fired a fatal guard); 3000u in one 1.0s sample is 4.5x that, so
# the classification is TP-or-nothing, not a haste call.
TP_JUMP_U = 3000.0

# Ward items as the dumper writes them (the `item_` prefix is stripped; verified
# against a real timeline before use, per the charter's item-naming trap).
# `ward_dispenser` is the stacked observer+sentry container and counts: a bot
# holding it is a bot the ward mode can bid for.
WARD_ITEMS = ("observer_ward", "sentry_ward", "ward_dispenser")


def holds_ward(s):
    return any(i in WARD_ITEMS for i in all_items(s))


def window_frames(g, hero, t0, span):
    """Alive, inventory-bearing frames in (t0, t0+span]."""
    out = []
    for s in g.track.get(hero, ()):
        if s["t"] <= t0 or s["t"] > t0 + span:
            continue
        if s["hp_pct"] <= 0 or not has_items_row(s):
            continue
        if any(0.0 <= s["t"] - td < DEATH_BLANK_S for td in g.deaths.get(hero, ())):
            continue
        out.append(s)
    return out


def last_frame_t(g):
    t = 0.0
    for tr in g.track.values():
        if tr:
            t = max(t, tr[-1]["t"])
    return t


def score_window(g, hero, t_gain):
    """The readings, on one backpack landing.

    `moved` is derived POSITIVELY (the salve was seen in a drinkable slot, or
    left the nine slots altogether) rather than as the complement of STUCK --
    see the SHORT population in the module docstring for why the complement is
    the wrong thing to take.
    """
    fr = window_frames(g, hero, t_gain, BACKPACK_WATCH_S)
    sigs = set(tuple(all_items(s)) for s in fr)

    # ⭐ `moved` is NOT "the flask left the nine slots".  Frame-by-frame on
    # 9b1fe4/20260823_122351_slot10 spirit_breaker t=517.5 the salve reads
    # present / present / ABSENT / present / ABSENT on consecutive 1.0s samples
    # while the bot's coordinates are frozen at the same 10,040u -- an item row
    # that is stale or partial on alternating frames, not five item movements.
    # Absence is therefore not evidence of consumption or handover.  The two
    # signals that ARE reliable: the salve seen in a drinkable slot (a position,
    # not an absence), and modifier_flask_healing going on (an event).
    #
    # DIRECTION, because it decides how #123's number should be read: the
    # shipped `_stuck_in_backpack` treats absence as "gone -> not stuck", so
    # flicker makes STUCK UNDER-count.  #123's 12.9% is a lower bound.
    drank = any(t_gain < t <= t_gain + BACKPACK_WATCH_S
                for t in g.mod_add.get((hero, "modifier_flask_healing"), ()))
    moved = any(FLASK in usable_items(s) for s in fr) or drank
    absent = [i for i, s in enumerate(fr) if FLASK not in all_items(s)]
    flicker = bool(absent) and any(
        FLASK in all_items(s) for s in fr[absent[0] + 1:])
    return {
        "alive": len(fr),
        "sigs": len(sigs),
        "silent": len(sigs) <= 1,
        "full": len(fr) >= FULL_MIN_FRAMES,
        "moved": moved,
        "drank": drank,
        "flicker": flicker,
        # ⭐ the second thing the selfcheck forced out: a rescue that happened
        # between the gain frame and the very next sample leaves ONE signature
        # in the window, so "silent" and "rescued" are not exclusive after all.
        # Recorded per row so the assertion below can be exact instead of
        # approximately true.
        "moved_at_first": bool(fr) and FLASK in usable_items(fr[0]),
        "ward_any": any(holds_ward(s) for s in fr),
        "ward_all": bool(fr) and all(holds_ward(s) for s in fr),
        # ⭐ What the frame-by-frame pass found and the silence table cannot
        # say: where the bot GOES while the undrinkable salve rides along.
        "home": _went_home(g, fr),
    }


def _went_home(g, fr):
    """('tp'|'walk', t) the first time the bot is inside its own fountain ring.

    Split on the one-sample displacement, not on a modifier: the charter's
    `modifier_teleporting` trap says the channel frames are not the decision
    frames, and here the question is only "did it end up at the fountain",
    which the position answers directly.
    """
    prev = None
    for s in fr:
        d = g.dist_fountain(s)
        if d is None:
            continue
        if d <= HOME_RING_U:
            if prev is not None and prev[0] - d > TP_JUMP_U:
                return ("tp", s["t"])
            return ("walk", s["t"])
        prev = (d, s["t"])
    return None


def scan_game(g, run, game):
    """Every IN-FIELD backpack landing in one game, classified and scored."""
    horizon = last_frame_t(g) - FREEZE_TAIL_S
    out, dropped = [], 0
    for hero in g.track:
        for (t, fdist, usable, stuck) in flask_gains(g, hero):
            if usable:
                continue                       # landed straight in slots 0..5
            if fdist is None or fdist <= FOUNTAIN_PICKUP_U:
                continue                       # stash pickup, not a field drop
            if t + BACKPACK_WATCH_S > horizon:
                dropped += 1                   # #130 freeze tail
                continue
            row = score_window(g, hero, t)
            if not row["alive"]:
                dropped += 1                   # window is all corpse
                continue
            if row["moved"]:
                pop = "RESCUED"
            elif stuck:
                pop = "STUCK"
            else:
                pop = "SHORT"                  # window ran out; nothing known
            row.update(run=run, game=game, hero=hero, t=t, fdist=fdist, pop=pop)
            out.append(row)
    return out, dropped


def collect(rows, interval):
    eps, dropped, games = [], 0, 0
    for (run, game, cand, seed, side, path) in rows:
        assert CAND_ID in cand.split(","), (
            "armed-string guard: %s not in %s" % (CAND_ID, game))
        g = Game(path, interval)
        got, drop = scan_game(g, run, game)
        eps.extend(got)
        dropped += drop
        games += 1
        del g
    return eps, dropped, games


def _rate(n, d):
    return (100.0 * n / d) if d else 0.0


def report(eps, dropped, games):
    print("== fieldbuy backpack silence: replication + WARD test ==")
    print("games: %d   in-field backpack landings scored: %d   dropped: %d"
          % (games, len(eps), dropped))
    print("   (dropped = watch window overlapped the %.0fs freeze tail (#130),"
          % FREEZE_TAIL_S)
    print("    or the whole window was corpse frames)")
    print("")
    by = collections.defaultdict(list)
    for e in eps:
        by[e["pop"]].append(e)
    print("-- 1. family silence: distinct nine-slot signatures in the %.0fs window --"
          % BACKPACK_WATCH_S)
    print("   05:10Z on one run of the 18:11Z wave: 9 of 11 field-STUCK windows silent (81.8%)")
    print("   silence is scored ONLY on FULL windows (>= %d alive frames): a"
          % FULL_MIN_FRAMES)
    print("   two-frame window is silent for free and would inflate every rate here.")
    print("%-9s %6s %6s %9s %9s %11s %11s"
          % ("pop", "n", "full", "silent", "rate", "med sigs", "med alive"))
    for pop in ("STUCK", "RESCUED", "SHORT"):
        v = by.get(pop, [])
        if not v:
            print("%-9s %6d %6s %9s %9s %11s %11s"
                  % (pop, 0, "-", "-", "-", "-", "-"))
            continue
        fu = [e for e in v if e["full"]]
        sil = sum(1 for e in fu if e["silent"])
        sg = sorted(e["sigs"] for e in fu) or [0]
        al = sorted(e["alive"] for e in v)
        print("%-9s %6d %6d %9d %8.1f%% %11d %11d"
              % (pop, len(v), len(fu), sil, _rate(sil, len(fu)),
                 sg[len(sg) // 2], al[len(al) // 2]))
    print("")
    print("   RESCUED is the arithmetic floor, not a free control: a rescue IS a")
    print("   signature change, so its silent rate is 0 by construction.  SHORT is")
    print("   the undecidable remainder (window ran out before the settle point) and")
    print("   is reported apart from both.  They are")
    print("   printed to show the populations were separated as intended, and the")
    print("   ALIVE column is the one that carries information -- if STUCK windows")
    print("   simply had fewer scorable frames, silence would be a sampling")
    print("   artifact rather than a behaviour.")
    print("")
    print("-- 2. ⭐ WARD necessary-condition test (can refute, cannot confirm) --")
    print("   holding a ward is necessary for GetActiveMode()==BOT_MODE_WARD;")
    print("   the mode itself is not in the replay.")
    print("%-9s %6s %11s %8s %11s %8s"
          % ("pop", "n", "ward ANY", "rate", "ward ALL", "rate"))
    for pop in ("STUCK", "RESCUED", "SHORT"):
        v = by.get(pop, [])
        if not v:
            continue
        wa = sum(1 for e in v if e["ward_any"])
        wl = sum(1 for e in v if e["ward_all"])
        print("%-9s %6d %11d %7.1f%% %11d %7.1f%%"
              % (pop, len(v), wa, _rate(wa, len(v)), wl, _rate(wl, len(v))))
    sv = [e for e in eps if e["silent"] and e["full"]]
    if sv:
        wa = sum(1 for e in sv if e["ward_any"])
        print("")
        print("   among SILENT FULL windows of any population: %d/%d hold a ward (%.1f%%)"
              % (wa, len(sv), _rate(wa, len(sv))))
    print("")
    fl = sum(1 for e in eps if e["flicker"])
    dk = sum(1 for e in eps if e["drank"])
    print("-- 1b. measurement note: item-row flicker --")
    print("   rows where the salve vanished from the nine slots and came back")
    print("   inside the window: %d of %d (%.1f%%).  Absence is NOT departure;"
          % (fl, len(eps), _rate(fl, len(eps))))
    print("   `_stuck_in_backpack` reads absence as departure, so #123's STUCK")
    print("   rate is a LOWER bound.  Salves actually drunk in-window: %d." % dk)
    print("")
    print("-- ⭐ 2b. WHERE THE BOT WENT while the undrinkable salve rode along --")
    print("   this is the reading the silence table cannot produce, and it is the")
    print("   one that touches owner P2: J.HasFieldRegenSource reads slots 0..5, so")
    print("   a salve sitting in 6..8 is INVISIBLE to `stayfield`/`stayfield2` --")
    print("   the very ids meant to veto the trip home.")
    print("%-9s %6s %11s %8s %11s %11s"
          % ("pop", "n", "went home", "rate", "by TP", "on foot"))
    for pop in ("STUCK", "RESCUED", "SHORT"):
        v = by.get(pop, [])
        if not v:
            continue
        h = [e for e in v if e["home"]]
        tp = sum(1 for e in h if e["home"][0] == "tp")
        print("%-9s %6d %11d %7.1f%% %11d %11d"
              % (pop, len(v), len(h), _rate(len(h), len(v)), tp, len(h) - tp))
    print("")
    print("-- 3. per-run split (a single-run reading is what started this) --")
    per = collections.defaultdict(lambda: collections.Counter())
    for e in eps:
        c = per[e["run"][-6:]]
        c[e["pop"]] += 1
        if e["pop"] == "STUCK" and e["silent"] and e["full"]:
            c["silent"] += 1
        if e["pop"] == "STUCK" and e["ward_any"]:
            c["ward"] += 1
    print("%-8s %8s %9s %9s %8s" % ("run", "STUCK", "RESCUED", "silent", "ward"))
    for run in sorted(per):
        c = per[run]
        print("%-8s %8d %9d %9d %8d"
              % (run, c["STUCK"], c["RESCUED"], c["silent"], c["ward"]))
    print("")
    print("-- 4. the longest silent STUCK windows (deep-dive candidates) --")
    for e in sorted([x for x in eps if x["pop"] == "STUCK" and x["silent"]
                     and x["full"]],
                    key=lambda x: -x["alive"])[:12]:
        print("   %s/%s  %-18s t=%.1f  d(fnt)=%.0fu  alive=%d  ward=%s  home=%s"
              % (e["run"][-6:], e["game"], e["hero"], e["t"], e["fdist"],
                 e["alive"], "Y" if e["ward_any"] else "n",
                 ("%s@%.1f" % e["home"]) if e["home"] else "-"))


# --------------------------------------------------------------------------
def selfcheck(eps, dropped, games):
    checks = []

    def ck(name, cond, detail=""):
        checks.append((name, bool(cond), detail))

    ck("scored something", len(eps) > 0, "n=%d" % len(eps))
    ck("every row lands in exactly one of the three populations",
       all(e["pop"] in ("STUCK", "RESCUED", "SHORT") for e in eps))
    ck("STUCK and SHORT both mean the salve never moved",
       all(not e["moved"] for e in eps if e["pop"] in ("STUCK", "SHORT")))
    ck("RESCUED means it positively moved",
       all(e["moved"] for e in eps if e["pop"] == "RESCUED"))
    ck("a drink always counts as moved", all(e["moved"] for e in eps if e["drank"]))
    ck("the flicker artifact is real in this corpus (absence is not departure)",
       sum(1 for e in eps if e["flicker"]) > 0,
       "flicker rows=%d" % sum(1 for e in eps if e["flicker"]))
    ck("no scored window is all-corpse", all(e["alive"] >= 1 for e in eps))
    ck("signature count is at least 1 wherever a frame exists",
       all(e["sigs"] >= 1 for e in eps))
    ck("silent <=> exactly one signature",
       all(e["silent"] == (e["sigs"] <= 1) for e in eps))
    ck("a silent RESCUED window is one the rescue beat to the first sample",
       all(e["moved_at_first"] for e in eps
           if e["pop"] == "RESCUED" and e["silent"]))
    ck("a rescue INSIDE a full window always leaves >=2 signatures",
       all(e["sigs"] >= 2 for e in eps
           if e["pop"] == "RESCUED" and e["full"] and not e["moved_at_first"]))
    ck("home classification is tp or walk or nothing",
       all(e["home"] is None or e["home"][0] in ("tp", "walk") for e in eps))
    # NOT `ck(..., True)`.  A placeholder that cannot fail is the exact shape
    # this desk keeps catching in other people's harnesses; the classifier is
    # driven on synthetic tracks instead.
    class _FakeG(object):
        def __init__(self, ds):
            self.ds = ds

        def dist_fountain(self, s):
            return self.ds[s["t"]]

    def _frames(ts):
        return [{"t": t} for t in ts]

    fk = _FakeG({1.0: 9000.0, 2.0: 8600.0, 3.0: 100.0})
    ck("an 8600u -> 100u step in one sample is classified TP",
       _went_home(fk, _frames([1.0, 2.0, 3.0])) == ("tp", 3.0))
    fk2 = _FakeG({1.0: 2600.0, 2.0: 2200.0, 3.0: 1900.0})
    ck("a 2200u -> 1900u step into the ring is classified walk",
       _went_home(fk2, _frames([1.0, 2.0, 3.0])) == ("walk", 3.0))
    fk3 = _FakeG({1.0: 9000.0, 2.0: 8600.0})
    ck("never reaching the ring returns nothing",
       _went_home(fk3, _frames([1.0, 2.0])) is None)
    ck("FULL windows are a real subset (the floor bites)",
       0 < sum(1 for e in eps if e["full"]) < len(eps))
    ck("ward_all implies ward_any", all(e["ward_any"] for e in eps if e["ward_all"]))
    ck("every gain is out in the field (stash pickups excluded)",
       all(e["fdist"] > FOUNTAIN_PICKUP_U for e in eps))
    ck("watch window is the one #123 reported on", BACKPACK_WATCH_S == 30.0,
       "got %.1f" % BACKPACK_WATCH_S)

    # holds_ward reads the WHOLE nine slots on purpose: a ward in the backpack
    # still makes the bot a ward-mode candidate (the mode swaps it up itself).
    ck("holds_ward sees a backpack ward",
       holds_ward({"items": ["a", "b", "c", "d", "e", "f", "sentry_ward"]}))
    ck("holds_ward is false on an empty corpse row", not holds_ward({"items": []}))
    ck("holds_ward does not fire on a lookalike",
       not holds_ward({"items": ["ward_of_nothing", "wardplate"]}))
    ck("usable_items and all_items disagree exactly on the backpack",
       usable_items({"items": list("abcdefgh")}) == list("abcdef")
       and all_items({"items": list("abcdefghi")}) == list("abcdefghi"))

    # The freeze-tail guard has to actually drop things, or it is decoration
    # that would silently pass a corpus where every window ran into the tail.
    ck("freeze-tail/corpse guard is live (it dropped at least one landing)",
       dropped > 0, "dropped=%d" % dropped)
    ck("guard is not eating the corpus", dropped < 5 * max(len(eps), 1),
       "dropped=%d scored=%d" % (dropped, len(eps)))
    ck("games were actually read", games > 0, "games=%d" % games)

    for name, ok, detail in checks:
        print("  %-4s %s %s" % ("ok" if ok else "FAIL", name, detail))
    bad = sum(1 for _, ok, _ in checks if not ok)
    print("selfcheck: %d/%d" % (len(checks) - bad, len(checks)))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()
    rows = load_sweeps(a.dirs)
    if not rows:
        sys.exit("no games")
    eps, dropped, games = collect(rows, a.interval)
    if a.selfcheck:
        sys.exit(selfcheck(eps, dropped, games))
    report(eps, dropped, games)


if __name__ == "__main__":
    main()
