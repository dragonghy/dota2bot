#!/usr/bin/env python3
"""Frame-level probe: can a RESPAWN intervene inside lionqdmg_domain.py's
backward-looking windows?

Reads `timelines/*.json` DIRECTLY.  It deliberately imports nothing from
`lionqdmg_domain.py` -- the whole point is to measure the tool's environment
without going through the tool under test (replay-check hard rule: frame by
frame first, and never let the checked tool answer the question about itself).

Three measurements:

  D  DEATH -> ALIVE AGAIN.  For every hero DEATH event followed by a sampled
     hp<=0, the time from the DEATH event to the next hp>0 sample.  This is
     the quantity that governs any BACKWARD-looking window, and measuring it
     is the point of the file: the assumption it replaces ("Turbo halves
     respawn timers, so nothing revives inside 2 s") does not describe this
     corpus, because the fastest revivals in it are not respawns at all --
     they are Wraith King's Reincarnation, which returns him on the spot.
     Measured on W32 (10 games, 498 hero deaths): min 3.2 s, and the five
     shortest are all `skeleton_king`.

  B  BACKWARD REACH.  For every DEATH event, has the hero RESPAWNED within
     W seconds of it -- a corpse sample followed by an hp>0 sample, never a
     lone hp>0 sample?  That distinction is the whole measurement: within a
     second or two of a logged death an hp>0 sample is overwhelmingly the
     health bar lagging, which is the `stale` phenomenon itself and the exact
     opposite of a revival.  Reading it the loose way turns 0 into 19.

  C  THE DEFECT PROBE, superset form.  `stale_victim(hero, t0, sw)` pairs a
     DEATH in (t0-sw, t0] with the first sample after t0 and calls the pair
     "the log declared this death before the frame, no respawn intervened".
     That claim is unguarded.  Enumerate every (hero, death_t, sample t0)
     with t0 in [death_t, death_t + sw] and ask whether an hp>0 sample sits
     strictly between death_t and t0 -- that is exactly the pairing the
     missing guard would reject.  This is a SUPERSET of the frames the tool
     visits (it does not require Lion, reach, mana, cooldown or the damage
     band), so a zero here is a stronger statement than a zero inside the
     tool.
"""
import collections
import glob
import json
import re
import sys

SAMPLE_TOL = 1e-6
STALE_WINDOWS = (1.0, 2.0)
OUTCOME_WINDOWS = (2.0, 5.0, 10.0)


def canon(name):
    """Lowercase, drop the npc_dota_hero_ prefix, remove underscores.

    Same normalisation the tool uses (snapshots spell `vengeful_spirit`, the
    combat log spells `vengefulspirit`), reimplemented here so this probe does
    not import the file it is auditing."""
    n = (name or "").lower()
    n = re.sub(r"^npc_dota_hero_", "", n)
    return n.replace("_", "")


def load(path):
    d = json.load(open(path))
    # identity lock by earliest-appearing idx (GH #176 discipline)
    first_t = {}
    for s in d["snapshots"]:
        if "idx" not in s:
            sys.exit("FATAL: no snapshot idx in %s" % path)
        k = (canon(s["hero"]), s["idx"])
        if k not in first_t or s["t"] < first_t[k]:
            first_t[k] = s["t"]
    primary = {}
    for (hero, idx), t0 in first_t.items():
        if hero not in primary or t0 < primary[hero][1]:
            primary[hero] = (idx, t0)
    prim = dict((h, v[0]) for h, v in primary.items())

    by_hero = collections.defaultdict(list)
    for s in d["snapshots"]:
        h = canon(s["hero"])
        if prim.get(h) != s["idx"]:
            continue
        by_hero[h].append((s["t"], s.get("hp") or 0.0))
    for h in by_hero:
        by_hero[h].sort()

    deaths = collections.defaultdict(list)
    for e in (d.get("events") or ()):
        if e.get("type") != "DEATH" or not e.get("target_hero"):
            continue
        deaths[canon(e.get("target"))].append(e["t"])
    for h in deaths:
        deaths[h].sort()
    return by_hero, deaths


def main(dirs):
    files = []
    for d in dirs:
        files.extend(sorted(glob.glob(d.rstrip("/") + "/*.json")))
    lat = []                       # A
    reach = collections.Counter()  # B
    reach_den = 0
    c_pairs = 0                    # C denominator
    c_straddle = 0                 # C numerator (the missing guard would fire)
    c_stale_shape = 0              # pairs that ALSO have the confirming corpse
    c_stale_straddle = 0
    examples = []
    for f in files:
        by_hero, deaths = load(f)
        for h, ds in deaths.items():
            series = by_hero.get(h)
            if not series:
                continue
            for dt in ds:
                # --- A: corpse -> next hp>0 -------------------------------
                # A RESPAWN is the dead->alive TRANSITION, never a lone hp>0
                # sample: within a second or two of a logged death an hp>0
                # sample is overwhelmingly the health bar lagging, which is the
                # `stale` phenomenon itself and the opposite of a respawn.
                zero = next((t for t, hp in series
                             if t >= dt - SAMPLE_TOL and hp <= 0), None)
                if zero is not None:
                    up = next((t for t, hp in series if t > zero and hp > 0), None)
                    if up is not None:
                        # D, the quantity that actually governs a BACKWARD
                        # window: logged death -> hero sampled alive again.
                        lat.append((up - dt, f, h, dt, zero, up))
                # --- B: has the hero RESPAWNED within W of the death? -----
                reach_den += 1
                for w in (1.0, 2.0, 5.0, 10.0):
                    if zero is not None and zero <= dt + w and any(
                            hp > 0 for t, hp in series if zero < t <= dt + w):
                        reach[w] += 1
                # --- C: the defect probe ----------------------------------
                for sw in STALE_WINDOWS:
                    for t0, hp0 in series:
                        if not (dt - SAMPLE_TOL <= t0 <= dt + sw + SAMPLE_TOL):
                            continue
                        if hp0 <= 0:
                            continue   # the tool only looks at LIVING victims
                        c_pairs += 1
                        # THE GUARD'S ACTUAL PREDICATE: a corpse sample strictly
                        # between the logged death and the frame.  The frame's
                        # own sample is hp>0 by construction, so a 0 in between
                        # already IS the dead->alive transition -- and a merely
                        # LAGGING bar never goes 0 and then positive inside one
                        # death, which is what makes this the whole test.
                        straddle = any(hp <= 0 for t, hp in series
                                       if dt < t < t0 - SAMPLE_TOL)
                        nxt = next((hp for t, hp in series
                                    if t > t0 + SAMPLE_TOL), None)
                        confirmed = nxt is not None and nxt <= 0
                        if confirmed:
                            c_stale_shape += 1
                        if straddle:
                            c_straddle += 1
                            if confirmed:
                                c_stale_straddle += 1
                                if len(examples) < 5:
                                    examples.append((f, h, dt, t0, sw))
    lat.sort()
    print("files: %d" % len(files))
    print()
    print("D  DEATH EVENT -> HERO SAMPLED ALIVE AGAIN (governs any BACKWARD window)")
    if lat:
        v = [x[0] for x in lat]
        print("   n=%d  min=%.1fs  p05=%.1fs  median=%.1fs  max=%.1fs"
              % (len(v), v[0], v[int(0.05 * len(v))], v[len(v) // 2], v[-1]))
        print("   under 3s: %d   under 6s: %d"
              % (sum(1 for x in v if x < 3.0), sum(1 for x in v if x < 6.0)))
        print("   SHORTEST FIVE (frame-level audit material):")
        for d, f, h, dt, z, up in lat[:5]:
            print("     %+.1fs  %-16s %-18s death=%.1f corpse=%.1f alive=%.1f"
                  % (d, h, f.split("/")[-1][:22], dt, z, up))
    else:
        print("   n=0")
    print()
    print("B  ALIVE AGAIN WITHIN W OF A LOGGED DEATH   (denominator %d deaths)"
          % reach_den)
    for w in (1.0, 2.0, 5.0, 10.0):
        print("   W=%4.1fs : %d" % (w, reach[w]))
    print()
    print("C  stale_victim PAIRINGS (superset of the frames the tool visits)")
    print("   (death, living sample) pairs inside STALE_WINDOWS : %d" % c_pairs)
    print("   ... of which the next sample confirms a corpse    : %d"
          % c_stale_shape)
    print("   ... with a RESPAWN strictly in between (guard would fire) : %d"
          % c_straddle)
    print("   ... both (a MISCOUNTED stale frame)               : %d"
          % c_stale_straddle)
    for e in examples:
        print("   example: %s %s death=%.1f frame=%.1f sw=%.1f" % e)


if __name__ == "__main__":
    main(sys.argv[1:])
