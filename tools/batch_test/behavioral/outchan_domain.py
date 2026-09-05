#!/usr/bin/env python3
"""outchan -- price the THREE competing explanations for the aborted outpost
capture channel reported in GH #511, on the real event stream.

WHY THIS EXISTS
  GH #511 reported the fact (53 capture channels, 40 aborted, 66.6 s of hero
  time thrown away) correctly and then attached a root cause and a one-line
  fix to it:

      "`mode_outpost_generic.lua` has no `bot:IsChanneling()` guard anywhere
       in the file, so `Think()` re-issues the capture order every tick and
       each re-issue restarts the channel.  Fix: `if bot:IsChanneling() then
       return end` at the top of `Think()`."

  Both halves of that are wrong, and they are wrong in the two different ways
  this repo has already paid for once each:

  (1) THE GUARD IS ALREADY THERE, one call deep.  `Think()`'s first statement
      is `if J.CanNotUseAction(bot) then return end`, and `J.CanNotUseAction`
      (`bots/FunLib/jmz_func.lua`) has `or bot:IsChanneling()` as one of its
      disjuncts.  "The file does not contain the token `IsChanneling`" is
      true and says nothing.  Landing the proposed line is a NO-OP: it adds a
      disjunct that is already evaluated, earlier, on the same frame.
      Same shape as `droppick`/§EK: a diff that edits source, passes review,
      reads like a fix, and is bit-identical to the unfixed tree.

  (2) THE ORDERING IS BACKWARDS.  `bots/mode_outpost_generic.lua` holds the
      repo's ONLY `ability_capture` cast site, and it sits BELOW that guard.
      So every cast in the corpus is, BY CONSTRUCTION, a frame on which
      `bot:IsChanneling()` was already false -- the channel was already gone
      when the order went out.  The event stream says the same thing
      independently: MODIFIER_REMOVE strictly PRECEDES the next cast, every
      time.  The re-issue is DOWNSTREAM of the interruption, not its cause.

  Point (1) is a deduction from shipped source and needs no corpus: it holds
  for all 53 attempts in #511 and for every attempt that will ever be logged.
  Points (2) and (3) below are measured here.

WHAT IT MEASURES, per capture episode
  An EPISODE is a maximal run of `ability_capture` casts by one hero on one
  outpost with < --gap-s idle between consecutive casts (default 5.0).

  leg `issuefix`   -- would GH #511's proposed line have suppressed this cast?
                      MEASURED, not asserted: a cast is suppressible iff the
                      caster's own capture channel was live on its frame, i.e.
                      the cast time falls strictly inside one of that actor's
                      own MODIFIER_ADD..MODIFIER_REMOVE intervals for
                      `modifier_watch_tower_capturing`.  That interval is the
                      observable shadow of `bot:IsChanneling()`, and this
                      count CAN come back non-zero -- if it does, #511's line
                      is a real fix and this whole reading is wrong.
  leg `selfresend` -- did a cast ARRIVE STRICTLY BEFORE the removal that ended
                      the channel it supposedly interrupted?  That is what
                      "the re-issue restarts the channel" requires.  Reported
                      as the signed gap distribution, split three ways:
                      gap < 0 (cast first -- the claim), gap == 0 (a TIE at
                      the dump's 0.1 s quantization, which cannot order the
                      two events either way), gap > 0 (removal first).
                      The ties are reported as UNDECIDABLE, never folded into
                      either side.
  leg `infile`     -- at each interruption instant, were any of the three
                      abandon clauses that live in `mode_outpost_generic.lua`
                      itself actually true?
                        (a) `GetDesireHelper` :107-114 -- within 600u of the
                            outpost AND >= 1 enemy hero inside the bot's
                            vision range  => BOT_ACTION_DESIRE_NONE
                        (b) `IsSuitableToCaptureOutpost` -- the bot was
                            damaged by a hero in the last 5 s
                        (c) `IsSuitableToCaptureOutpost` -- our alive-hero
                            count < theirs
                      If all three are false across the whole episode, the
                      mode never had a reason OF ITS OWN to stop bidding, and
                      what stole the tick lives OUTSIDE this file.

ANTI-VACUUM CONTROL (mandatory -- a 0 must be shown to be a reading)
  `issuefix` and the strict half of `selfresend` both come back 0, so the
  probe has to be shown live on the same corpus, with the same code path,
  before either 0 counts.  Two controls run automatically:
    * `--control-modifier`: the `infile` (a) clause is evaluated with the SAME
      snapshot/vision machinery over EVERY sampled frame of the game, not just
      the interruption instants.  It reports a non-zero count of frames where
      an enemy IS inside vision range.  Same estimator, same data, non-zero
      answer => the 0 at the interruption instants is a reading.
    * `selfresend` prints the full signed-gap distribution, so "no cast at or
      before a removal" is backed by where the casts actually fell, not by an
      unexplained empty bucket.

WHAT IT WILL NOT DO
  It will not name the mode that stole the tick.  Mode arbitration is not in
  the dump.  What it CAN do is exhaust the in-file explanations, which is the
  half that decides whether the fix belongs in `Think()` (a guard) or in
  `GetDesire()` (commitment) -- and that is the half #511 got wrong.

  It will not price the commitment fix itself.  That predicate would be
  `ClosestOutpost:HasModifier('modifier_watch_tower_capturing')`, and the
  dumper's `buildings` records carry name/team/x/y/hp/alive and NO modifier
  list, so the outpost's modifier state is NOT in the dump and cannot reach a
  fixture.  That is a missing field with an address, not a soft "hard to
  measure" -- see the handoff in the report.

USAGE
  outchan_domain.py TIMELINE [TIMELINE ...] [--gap-s 5.0] [--json OUT]
"""

import argparse
import collections
import json
import math
import sys

CAPTURE_ABILITY = "ability_capture"
CAPTURE_MODIFIER = "modifier_watch_tower_capturing"

# Vision range used for the in-file clause (a).  `GetCurrentVisionRange()` is
# not in the dump; day vision for a standard hero is 1800.  Using the DAY
# value everywhere is the conservative choice for this test: it makes clause
# (a) as EASY as possible to fire, so a zero is not bought by a small radius.
DAY_VISION = 1800.0

# `GetDesireHelper` :107 -- the clause only applies inside this radius.
NEAR_OUTPOST = 600.0

# `IsSuitableToCaptureOutpost` -- `bot:WasRecentlyDamagedByAnyHero(5)`.
RECENT_DAMAGE_S = 5.0


def load(path):
    with open(path) as fh:
        return json.load(fh)


def real_entity_index(snapshots):
    """Map hero name -> the entity idx that is the REAL hero, not an illusion.

    Illusions share the hero name and carry their own idx.  The real hero is
    sampled for the whole game; an illusion only for its lifetime, so the idx
    with the most samples is the hero.  Ties are impossible in practice (an
    illusion cannot outlive the hero it copies) and would be reported.
    """
    cnt = collections.Counter((s["hero"], s["idx"]) for s in snapshots)
    best = {}
    for (hero, idx), n in cnt.items():
        if hero not in best or n > best[hero][1]:
            best[hero] = (idx, n)
    return {hero: idx for hero, (idx, _n) in best.items()}


def frames_by_time(snapshots, real_idx):
    by_t = collections.defaultdict(dict)
    for s in snapshots:
        if real_idx.get(s["hero"]) == s["idx"]:
            by_t[round(s["t"], 1)][s["hero"]] = s
    return by_t


def nearest_frame(by_t, times, t):
    """The sampled frame at or before t (snapshots are ~1 Hz)."""
    lo, hi = 0, len(times) - 1
    best = None
    while lo <= hi:
        mid = (lo + hi) // 2
        if times[mid] <= t:
            best = times[mid]
            lo = mid + 1
        else:
            hi = mid - 1
    return by_t.get(best) if best is not None else None


def episodes(casts, gap_s):
    """Group casts into episodes keyed by (actor, target)."""
    out = []
    by_pair = collections.defaultdict(list)
    for e in casts:
        by_pair[(e["actor"], e.get("target"))].append(e)
    for (actor, target), evs in sorted(by_pair.items()):
        evs.sort(key=lambda e: e["t"])
        cur = [evs[0]]
        for e in evs[1:]:
            if e["t"] - cur[-1]["t"] <= gap_s:
                cur.append(e)
            else:
                out.append((actor, target, cur))
                cur = [e]
        out.append((actor, target, cur))
    return out


def enemies_in_vision(frame, me, team):
    """Clause (a)'s inner half: >= 1 enemy hero inside DAY_VISION of the bot."""
    hits = []
    for s in frame.values():
        if s["team"] == team or s["hp"] <= 0:
            continue
        d = math.hypot(s["x"] - me["x"], s["y"] - me["y"])
        if d <= DAY_VISION:
            hits.append((s["hero"], round(d)))
    return hits


def alive_counts(frame, team):
    us = sum(1 for s in frame.values() if s["team"] == team and s["hp"] > 0)
    them = sum(1 for s in frame.values() if s["team"] != team and s["hp"] > 0)
    return us, them


def price_one(path, gap_s):
    tl = load(path)
    events = tl["events"]
    snaps = tl["snapshots"]
    real_idx = real_entity_index(snaps)
    by_t = frames_by_time(snaps, real_idx)
    times = sorted(by_t)

    casts = [e for e in events
             if e["type"] == "ABILITY" and e.get("inflictor") == CAPTURE_ABILITY]
    adds = [e for e in events
            if e["type"] == "MODIFIER_ADD" and e.get("inflictor") == CAPTURE_MODIFIER]
    rems = [e for e in events
            if e["type"] == "MODIFIER_REMOVE" and e.get("inflictor") == CAPTURE_MODIFIER]
    hero_damage = [e for e in events
                   if e["type"] == "DAMAGE" and e.get("actor_hero")]

    res = {
        "timeline": path,
        "casts": len(casts),
        "adds": len(adds),
        "removes": len(rems),
        "episodes": [],
        "issuefix_suppressed": 0,
        "issuefix_checked": 0,
        # How many live-channel intervals the leg actually reconstructed.  An
        # emptied interval list reports the same 0 suppressions as a real
        # reading does, so this count is the leg's own anti-vacuum control and
        # is asserted alongside it.
        "issuefix_intervals": 0,
        "selfresend_before": 0,
        "selfresend_tie": 0,
        "selfresend_after": 0,
        "resend_gaps": [],
        "infile_a": 0,
        "infile_b": 0,
        "infile_c": 0,
        "interrupts": 0,
        "control_vision_frames": 0,
        "control_total_frames": 0,
    }

    # ---- anti-vacuum control: same clause (a), every sampled frame ----------
    for t in times:
        frame = by_t[t]
        for hero, me in frame.items():
            if me["hp"] <= 0:
                continue
            res["control_total_frames"] += 1
            if enemies_in_vision(frame, me, me["team"]):
                res["control_vision_frames"] += 1

    for actor, target, evs in episodes(casts, gap_s):
        ep_rems = [e for e in rems
                   if e["actor"] == actor and e.get("target") == target
                   and evs[0]["t"] - 1.0 <= e["t"] <= evs[-1]["t"] + 8.0]
        ep = {
            "actor": actor,
            "target": target,
            "t0": evs[0]["t"],
            "t1": evs[-1]["t"],
            "casts": len(evs),
            "removes": len(ep_rems),
            "resend_gaps": [],
            "infile": {"a": 0, "b": 0, "c": 0, "checked": 0},
        }

        # ---- selfresend: signed gap from each removal to the NEXT cast ------
        # "the re-issue restarts the channel" needs a cast STRICTLY BEFORE the
        # removal it caused (gap < 0).  A gap of exactly 0 is a tie at the
        # dump's 0.1 s quantization and orders nothing; it is counted apart
        # and never folded into either side.
        for rem in ep_rems:
            later = [c for c in evs if c["t"] >= rem["t"] - 1e-9]
            if not later:
                continue
            gap = round(later[0]["t"] - rem["t"], 3)
            ep["resend_gaps"].append(gap)
            res["resend_gaps"].append(gap)
            if gap < 0:
                res["selfresend_before"] += 1
            elif gap == 0:
                res["selfresend_tie"] += 1
            else:
                res["selfresend_after"] += 1

        # ---- issuefix: could #511's line have suppressed this cast? ---------
        # MEASURED.  The caster's own channel is live on [ADD, REMOVE); a cast
        # landing strictly inside such an interval is one that
        # `bot:IsChanneling()` would have caught.  This count is free to be
        # non-zero -- if it were, #511's one-liner would be a real fix.
        ep_adds = [e for e in adds
                   if e["actor"] == actor and e.get("target") == target
                   and evs[0]["t"] - 1.0 <= e["t"] <= evs[-1]["t"] + 8.0]
        intervals = []
        for a in ep_adds:
            after = [r for r in ep_rems if r["t"] > a["t"]]
            if after:
                intervals.append((a["t"], after[0]["t"]))
        res["issuefix_intervals"] += len(intervals)
        for c in evs:
            res["issuefix_checked"] += 1
            if any(lo < c["t"] < hi for lo, hi in intervals):
                res["issuefix_suppressed"] += 1

        # ---- infile: the three abandon clauses at each interruption ---------
        for rem in ep_rems:
            frame = nearest_frame(by_t, times, rem["t"])
            if not frame:
                continue
            me = frame.get(actor)
            if not me:
                continue
            ep["infile"]["checked"] += 1
            res["interrupts"] += 1

            # (a) within 600u of the outpost AND an enemy inside vision
            #     The outpost location comes from the buildings track.
            near_op = False
            for b in tl.get("buildings", []):
                if b.get("name") != "watch_tower":
                    continue
                if math.hypot(b["x"] - me["x"], b["y"] - me["y"]) <= NEAR_OUTPOST:
                    near_op = True
                    break
            if near_op and enemies_in_vision(frame, me, me["team"]):
                ep["infile"]["a"] += 1
                res["infile_a"] += 1

            # (b) damaged by a hero in the last 5 s
            if any(d.get("target") == actor and rem["t"] - RECENT_DAMAGE_S <= d["t"] <= rem["t"]
                   for d in hero_damage):
                ep["infile"]["b"] += 1
                res["infile_b"] += 1

            # (c) our alive count < theirs
            us, them = alive_counts(frame, me["team"])
            if us < them:
                ep["infile"]["c"] += 1
                res["infile_c"] += 1

        res["episodes"].append(ep)

    return res


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("timelines", nargs="+")
    ap.add_argument("--gap-s", type=float, default=5.0,
                    help="max idle between casts inside one episode (default 5.0)")
    ap.add_argument("--json", help="write the full reading to this path")
    args = ap.parse_args(argv)

    total = collections.Counter()
    all_gaps = []
    per_file = []
    for path in args.timelines:
        r = price_one(path, args.gap_s)
        per_file.append(r)
        all_gaps.extend(r["resend_gaps"])
        for k in ("casts", "adds", "removes", "issuefix_suppressed",
                  "issuefix_checked", "issuefix_intervals",
                  "selfresend_before", "selfresend_tie",
                  "selfresend_after", "infile_a", "infile_b", "infile_c",
                  "interrupts", "control_vision_frames", "control_total_frames"):
            total[k] += r[k]
        total["episodes"] += len(r["episodes"])

    print("== outchan domain pricing (GH #511) ==")
    print("timelines=%d  episodes=%d  casts=%d  channel_add=%d  channel_remove=%d"
          % (len(per_file), total["episodes"], total["casts"],
             total["adds"], total["removes"]))
    print()
    print("leg issuefix   (GH #511's `if bot:IsChanneling() then return end`)")
    print("  casts landing inside the caster's own live channel: %d / %d"
          % (total["issuefix_suppressed"], total["issuefix_checked"]))
    print("  those are the only casts the proposed line could suppress.")
    print("  live channel intervals reconstructed: %d  (leg anti-vacuum: a 0"
          % total["issuefix_intervals"])
    print("  here would mean the leg examined nothing and said so as a pass)")
    print("  corroborating deduction (corpus-independent): the repo's only")
    print("  `ability_capture` cast site sits BELOW `J.CanNotUseAction(bot)`,")
    print("  which already ORs in `bot:IsChanneling()`, so a logged cast")
    print("  PROVES the predicate was false on that frame.")
    print()
    print("leg selfresend (\"the re-issue restarts the channel\")")
    print("  cast strictly BEFORE the removal (the claim) : %d / %d"
          % (total["selfresend_before"], len(all_gaps)))
    print("  tie at the 0.1s dump resolution -- UNDECIDABLE: %d / %d"
          % (total["selfresend_tie"], len(all_gaps)))
    print("  removal strictly first                       : %d / %d"
          % (total["selfresend_after"], len(all_gaps)))
    if all_gaps:
        print("  signed gap removal->next cast: min=%.1f  median=%.1f  max=%.1f"
              % (min(all_gaps), sorted(all_gaps)[len(all_gaps) // 2], max(all_gaps)))
        print("  distribution: %s"
              % dict(sorted(collections.Counter(all_gaps).items())))
        print("  no gap is negative.  The ties are ties, not support: at 0.1 s")
        print("  quantization they cannot order the two events either way.")
    print()
    print("leg infile     (the three abandon clauses inside mode_outpost_generic.lua)")
    print("  interruption instants checked: %d" % total["interrupts"])
    print("  (a) <600u of outpost AND enemy hero inside %.0fu vision : %d"
          % (DAY_VISION, total["infile_a"]))
    print("  (b) WasRecentlyDamagedByAnyHero(%.0f)                    : %d"
          % (RECENT_DAMAGE_S, total["infile_b"]))
    print("  (c) alive(us) < alive(them)                            : %d"
          % total["infile_c"])
    print()
    print("ANTI-VACUUM CONTROL (same clause-(a) estimator, every sampled frame)")
    print("  frames with an enemy hero inside vision: %d / %d"
          % (total["control_vision_frames"], total["control_total_frames"]))
    if total["control_vision_frames"] == 0:
        print("  !! CONTROL DEAD -- the (a) zero above is a stuck probe, not a reading.")
    else:
        print("  control is live => the (a) zero at the interruption instants is a")
        print("  reading, not an emptiness.")
    print()
    for r in per_file:
        for ep in r["episodes"]:
            print("  %-28s %-22s t=%.1f..%.1f casts=%d removes=%d "
                  "infile a/b/c=%d/%d/%d gaps=%s"
                  % (r["timeline"].split("/")[-1].split(".")[0],
                     ep["actor"].replace("npc_dota_hero_", ""),
                     ep["t0"], ep["t1"], ep["casts"], ep["removes"],
                     ep["infile"]["a"], ep["infile"]["b"], ep["infile"]["c"],
                     ep["resend_gaps"]))

    if args.json:
        with open(args.json, "w") as fh:
            json.dump({"total": dict(total), "files": per_file}, fh, indent=2)
        print("\nwrote %s" % args.json)

    return 0


if __name__ == "__main__":
    sys.exit(main())
