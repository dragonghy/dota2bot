#!/usr/bin/env python3
"""[wandlimbo] domain + effect reader over dumper timelines.

WHAT THE ID DOES (source of truth: bots/FunLib/jmz_func.lua
J.ShouldDrinkWandInLimbo, call site bots/ability_item_usage_generic.lua
'低血游荡').  Armed, a bot holding a magic wand / magic stick / holy locket
drinks it during a quiet low-HP drift.  ALL of these must hold:

  * turbo AND J.IsSoakCandidate('wandlimbo')      -- leg, from the wave stamp
  * charges >= 6                                  -- NOT OBSERVABLE OFFLINE
  * HP <= 25% of max
  * (maxHP - HP) >= charges * 15                  -- "the whole draught lands"
  * no enemy hero within 1600
  * distance from own fountain > 2500

WHAT THIS SCRIPT MEASURES

  domain   -- the frames satisfying every condition a timeline CAN see.
              Charges are not in the dumper snapshot, so this is a strict
              SUPERSET of the true trigger set: it can FALSIFY ("the gate
              never had a frame to fire on") but it cannot CONFIRM a firing
              rate.  Same asymmetry the charter records for the camp ids.
  effect   -- from each domain frame, the largest HP gain by the same entity
              within EFFECT_WINDOW seconds while still nobody inside 1600.
              A full draught is charges*15 HP delivered in one instant, so
              >= MIN_DRAUGHT (6 * 15 = 90) in one sample step is the
              observable signature.  A wand/stick draught restores 15 MANA
              per charge as well, so the SAME step must also gain mana -- the
              co-signal is reported next to every HP jump and is what refutes
              the impostors (see LIMIT 2 and the worked case below).

  Worked case that made the mana co-signal mandatory:
  W23 638395/20260829_001847_slot8, spirit_breaker idx=1352, t=1119.4 --
  +206 HP in one step, in a 12-frame clean in-domain episode, nobody within
  3000, on the ARMED leg.  On HP alone it reads as the one firing in the
  whole sample.  Mana went 573 -> 504 (-69) on that very step and the item
  list changed blade_of_alacrity + boots_of_elven -> yasha: it is an item
  assembly, not a draught.  HP-only would have booked a WORKING.

LIMITS -- read these before quoting a number out of this script.

 1. CHARGES ARE INVISIBLE.  `domain` is an upper bound on firings, never a
    count of them.  A zero domain is evidence; a large domain is not.
 2. AN HP JUMP IS NOT UNIQUELY A WAND.  Mekansm / Guardian Greaves (~250
    instant), a Holy Locket active, an allied heal (Dazzle, Oracle, Warlock,
    Chen, an allied Mekansm) and a buyback all clear MIN_DRAUGHT.  That is
    why the reading is always a TWO-LEG DIFFERENCE: the baseline leg carries
    the same background sources and no wandlimbo, so only the armed-minus-
    baseline gap is attributable, and even that only weakly (see 4).
 3. NOT A SALVE.  A healing salve is ~400 HP over ~16s = ~25 HP/sample; it
    cannot reach MIN_DRAUGHT in one step at the ~1 Hz sample rate.  Regen
    from items/talents is smaller still.  This is what makes the jump
    discriminator worth anything at all.
 4. BOTH LEGS LIVE IN THE SAME GAME, so they are NOT independent samples --
    a fight that pushes one team's cores to 20% HP is the same fight that
    keeps the other team's heroes healthy.  Per 铁律 4(i) every reading is
    reported split by ab / ba (which physical side carried the armed leg);
    a difference that flips sign between the two layers is noise.
 5. ILLUSIONS (GH #176).  Entities are keyed (hero, idx) and only bodies born
    before the horn (t < 0) count -- as a hero AND as an enemy.  An illusion
    counted as an enemy would silently shrink the domain (the gate needs the
    1600 ring EMPTY), i.e. bias this reading toward "domain too small".
 6. THE 1600 RING USES SAMPLED FRAMES ONLY, never interpolation (GH #176's
    second half: interpolated hp/positions invent both corpses and contacts).
    Between samples an enemy can enter and leave the ring unseen, so the
    ring test, too, is a necessary condition on a superset.
 7. FOUNTAINS are estimated per team from that team's OWN first 10 sampled
    seconds, not from a map constant and NOT from the `t < -60` window that
    cm_r_selfstate_domain.py / es_aftershock_domain.py use.  That window is
    not safe: a whole team can arrive in the dumper's stream after -60 (real
    case in the fountain_of docstring), and then the estimator returns None
    for exactly one team.  Whatever a caller does with that None it is doing
    it to ONE LEG ONLY, so the artifact looks like a leg effect.  This was
    found by this script failing that way on its own first run.
 8. `hp_pct` is the dumper's, and max HP is recovered as hp/hp_pct, so a
    frame with hp_pct == 0 contributes nothing (it is a corpse anyway).
 9. THE MANA CO-SIGNAL IS NECESSARY, NOT SUFFICIENT.  It kills the impostor
    above, but BUYING an item raises current HP and current mana together and
    instantly (any strength+intelligence item -- bracer, null talisman, and
    every big assembly).  Over the W23 domain the `+mana too` column reads
    ab 9 armed / 13 baseline and ba 6 / 13, i.e. MORE on the leg that cannot
    drink at all -- that column is measuring purchases, not draughts.  The
    reading that survives is the CLEAN-episode one (no enemy within 2400, no
    HP loss in the prior 3 s, so no shipped rule and not 'wandbleed'
    either), where the count is 0 on both legs in both layers.
"""
import argparse
import collections
import glob
import json
import math
import os
import re
import sys

WAND_ITEMS = ("magic_wand", "magic_stick", "holy_locket")
HP_FRAC = 0.25
ENEMY_RING = 1600.0
FOUNTAIN_MIN = 2500.0
MIN_CHARGES = 6
HP_PER_CHARGE = 15
MIN_DRAUGHT = MIN_CHARGES * HP_PER_CHARGE  # 90
EFFECT_WINDOW = 3.0
EPISODE_GAP = 3.0

STAMP = re.compile(r"^mirror:(?P<cand>.*):s(?P<seed>\d+):(?P<side>radiant|dire)$")


def load_timeline(path):
    with open(path) as fh:
        return json.load(fh)


def real_bodies(snaps):
    """(hero, idx) keys of entities sampled before the horn.

    LIMIT 5: the discriminator is BIRTH TIME, not hp and not motion.  An
    illusion shares the hero name and the player_id and differs only in idx.
    """
    born = collections.defaultdict(lambda: math.inf)
    for s in snaps:
        k = (s["hero"], s["idx"])
        if s["t"] < born[k]:
            born[k] = s["t"]
    return {k for k, t0 in born.items() if t0 < 0.0}


def fountain_of(snaps, team):
    """Median position of a team over ITS OWN first 10 sampled seconds.

    NOT `t < -60` (the window cm_r_selfstate_domain.py and
    es_aftershock_domain.py use).  Entities enter the dumper's stream one at a
    time and a whole team can arrive after -60: in W23
    9e514b/20260829_001836_slot7 the earliest dire sample is t = -54.4, so a
    `t < -60` window returns NOTHING for dire while radiant estimates fine.
    The failure is silent and ONE-SIDED, which is worse than noisy -- see
    LIMIT 7.  Anchoring to the team's own arrival makes the window exist for
    every team that was sampled at all, and it stays pre-horn.
    """
    ts = [s["t"] for s in snaps if s["team"] == team]
    if not ts:
        return None
    t0 = min(ts)
    cut = min(t0 + 10.0, 0.0)
    xs = sorted(s["x"] for s in snaps if s["team"] == team and s["t"] <= cut)
    ys = sorted(s["y"] for s in snaps if s["team"] == team and s["t"] <= cut)
    if not xs:
        return None
    return xs[len(xs) // 2], ys[len(ys) // 2]


def episodes(times, gap=EPISODE_GAP):
    """Per-GAME run splitting (never pool games: test_set.md Z.2)."""
    out = []
    for t in sorted(times):
        if out and t - out[-1][-1] <= gap:
            out[-1].append(t)
        else:
            out.append([t])
    return out


def scan_game(tl, armed_side):
    """-> per-leg dict of domain frames / episodes / draught-sized HP jumps."""
    snaps = tl.get("snapshots") or []
    if not snaps:
        return None
    bodies = real_bodies(snaps)
    fountains = {2: fountain_of(snaps, 2), 3: fountain_of(snaps, 3)}
    armed_team = 2 if armed_side == "radiant" else 3
    # Diagnostic for LIMIT 7: would the `t < -60` window have had samples?
    legacy_empty = {
        team: not any(s["team"] == team and s["t"] < -60 for s in snaps)
        for team in (2, 3)
    }
    earliest = {
        team: min([s["t"] for s in snaps if s["team"] == team] or [None])
        for team in (2, 3)
    }

    by_t = collections.defaultdict(list)
    by_ent = collections.defaultdict(list)
    for s in snaps:
        k = (s["hero"], s["idx"])
        if k not in bodies:
            continue
        by_t[round(s["t"], 3)].append(s)
        by_ent[k].append(s)
    for v in by_ent.values():
        v.sort(key=lambda s: s["t"])

    legs = {
        "armed": collections.defaultdict(list),
        "baseline": collections.defaultdict(list),
    }
    per_hero = collections.defaultdict(lambda: collections.Counter())

    for k, frames in by_ent.items():
        team = frames[0]["team"]
        leg = "armed" if team == armed_team else "baseline"
        fount = fountains.get(team)
        for i, s in enumerate(frames):
            hp, pct = s.get("hp") or 0, s.get("hp_pct") or 0
            if hp <= 0 or pct <= 0:
                continue  # corpse (LIMIT 8)
            if not any(it in WAND_ITEMS for it in (s.get("items") or [])):
                continue
            if pct > HP_FRAC:
                continue
            max_hp = hp / pct
            if (max_hp - hp) < MIN_CHARGES * HP_PER_CHARGE:
                continue  # "the whole draught lands", at the 6-charge floor
            if fount is None:
                continue
            if math.hypot(s["x"] - fount[0], s["y"] - fount[1]) <= FOUNTAIN_MIN:
                continue
            if enemy_in_ring(by_t, s, team, bodies):
                continue

            legs[leg]["frames"].append((k[0], s["t"]))
            per_hero[(leg, k[0])]["frames"] += 1

            gain, t_gain, dmp = best_gain(frames, i, by_t, team, bodies)
            if gain >= MIN_DRAUGHT:
                legs[leg]["jumps"].append(
                    (k[0], s["t"], t_gain, round(gain, 1), round(dmp or 0, 1))
                )
                per_hero[(leg, k[0])]["jumps"] += 1
                if (dmp or 0) >= MIN_DRAUGHT:
                    legs[leg]["draughts"].append(
                        (k[0], s["t"], t_gain, round(gain, 1), round(dmp or 0, 1))
                    )

    out = {
        "diag": {
            "legacy_t60_empty": {str(k): v for k, v in legacy_empty.items()},
            "earliest_t": {str(k): v for k, v in earliest.items()},
            "fountain": {str(k): v for k, v in fountains.items()},
        }
    }
    for leg in ("armed", "baseline"):
        frames = legs[leg]["frames"]
        eps = []
        for hero in {h for h, _ in frames}:
            eps.extend(episodes([t for h2, t in frames if h2 == hero]))
        out[leg] = {
            "frames": len(frames),
            "episodes": len(eps),
            "heroes": len({h for h, _ in frames}),
            "jumps": legs[leg]["jumps"],
            "draughts": legs[leg]["draughts"],
        }
    return out


def enemy_in_ring(by_t, s, team, bodies):
    """LIMIT 6: sampled frames only, no interpolation."""
    for o in by_t.get(round(s["t"], 3), ()):
        if o["team"] == team:
            continue
        if (o["hero"], o["idx"]) not in bodies:
            continue
        if (o.get("hp") or 0) <= 0:
            continue
        if math.hypot(o["x"] - s["x"], o["y"] - s["y"]) < ENEMY_RING:
            return True
    return False


def best_gain(frames, i, by_t, team, bodies):
    """Largest single-step HP gain within EFFECT_WINDOW, with its mana co-signal.

    Single STEP, not cumulative: a draught is instantaneous, and a cumulative
    window sums ordinary regen into the same number.  `dmp` is the mana change
    on that same step -- a real draught restores 15 mana per charge, so a
    negative dmp says the HP came from somewhere else (see the worked case in
    the module docstring).
    """
    t0 = frames[i]["t"]
    best, t_best, dmp = 0.0, None, None
    for j in range(i + 1, len(frames)):
        f, prev = frames[j], frames[j - 1]
        if f["t"] - t0 > EFFECT_WINDOW:
            break
        if (f.get("hp") or 0) <= 0 or (prev.get("hp") or 0) <= 0:
            break
        if enemy_in_ring(by_t, f, team, bodies):
            break
        step = f["hp"] - prev["hp"]
        if step > best:
            best, t_best = step, f["t"]
            dmp = f.get("mp", 0) - prev.get("mp", 0)
    return best, t_best, dmp


def selfcheck():
    """Synthetic frames pinning the two things this script got wrong first try."""
    ok = [0, 0]

    def check(name, cond):
        ok[0 if cond else 1] += 1
        print("  %-62s %s" % (name, "PASS" if cond else "FAIL"))

    # --- LIMIT 7: the `t < -60` window, and why it is not used here ---------
    late = [
        {"t": -54.4 + i, "hero": "h", "idx": 1, "team": 3, "x": 6800, "y": 6500,
         "hp": 100, "hp_pct": 1.0, "mp": 0, "items": []}
        for i in range(8)
    ]
    check(
        "team arriving after -60 still gets a fountain",
        fountain_of(late, 3) is not None,
    )
    check(
        "and it is that team's own corner, not the map centre",
        fountain_of(late, 3)[0] > 5000,
    )
    check("a team never sampled at all is still None", fountain_of(late, 2) is None)
    early = late + [
        {"t": -70.0, "hero": "g", "idx": 2, "team": 2, "x": -6800, "y": -6500,
         "hp": 100, "hp_pct": 1.0, "mp": 0, "items": []}
    ]
    check("the legacy window would have been empty for dire only",
          not any(s["team"] == 3 and s["t"] < -60 for s in early)
          and any(s["team"] == 2 and s["t"] < -60 for s in early))

    # --- the mana co-signal: the yasha assembly must NOT read as a draught --
    frames = [
        {"t": 0.0, "hp": 235, "hp_pct": 0.108, "mp": 573, "team": 2, "x": 0, "y": 0},
        {"t": 1.0, "hp": 441, "hp_pct": 0.204, "mp": 504, "team": 2, "x": 0, "y": 0},
    ]
    gain, _, dmp = best_gain(frames, 0, collections.defaultdict(list), 2, set())
    check("the +206 HP step is seen", gain >= MIN_DRAUGHT)
    check("but its mana co-signal refutes a draught", dmp < 0)
    frames[1]["mp"] = 573 + 206  # what a real draught looks like
    gain, _, dmp = best_gain(frames, 0, collections.defaultdict(list), 2, set())
    check("a real draught passes both", gain >= MIN_DRAUGHT and dmp >= MIN_DRAUGHT)

    # --- cumulative regen must not be summed into a step -------------------
    creep = [
        {"t": float(i), "hp": 100 + 15 * i, "hp_pct": 0.1, "mp": 0,
         "team": 2, "x": 0, "y": 0}
        for i in range(9)
    ]
    gain, _, _ = best_gain(creep, 0, collections.defaultdict(list), 2, set())
    check("8 x 15 HP of regen is not one 120 HP draught", gain < MIN_DRAUGHT)

    print("selfcheck: %d pass, %d fail" % tuple(ok))
    return 0 if ok[1] == 0 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*", help="*.json from behav-dump")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument(
        "--stamps",
        help="JSON map {timeline basename without .json: 'mirror:...:sSEED:side'}",
    )
    ap.add_argument("--verbose", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        sys.exit(selfcheck())
    if not a.timelines or not a.stamps:
        ap.error("timelines and --stamps are required unless --selfcheck")

    with open(a.stamps) as fh:
        stamps = json.load(fh)

    layers = {
        "ab": collections.Counter(),
        "ba": collections.Counter(),
    }
    jump_rows = []
    seen = 0
    for path in sorted(a.timelines):
        base = os.path.basename(path)[:-5] if path.endswith(".json") else path
        st = stamps.get(base)
        if not st:
            print(f"skip (no stamp / warm-up): {base}", file=sys.stderr)
            continue
        m = STAMP.match(st)
        if not m:
            print(f"skip (unparseable stamp): {base} {st!r}", file=sys.stderr)
            continue
        side = m.group("side")
        layer = "ab" if side == "radiant" else "ba"
        res = scan_game(load_timeline(path), side)
        if res is None:
            print(f"skip (empty timeline): {base}", file=sys.stderr)
            continue
        seen += 1
        layers[layer]["games"] += 1
        for leg in ("armed", "baseline"):
            layers[layer][f"{leg}_frames"] += res[leg]["frames"]
            layers[layer][f"{leg}_episodes"] += res[leg]["episodes"]
            layers[layer][f"{leg}_jumps"] += len(res[leg]["jumps"])
            layers[layer][f"{leg}_draughts"] += len(res[leg]["draughts"])
            for row in res[leg]["jumps"]:
                jump_rows.append((base, layer, leg) + tuple(row))

    print(f"games read: {seen}")
    print()
    hdr = (f"{'layer':>6} {'games':>6} {'leg':>9} {'frames':>7} {'episodes':>9} "
           f"{'hp>=90':>8} {'+mana too':>10}")
    print(hdr)
    print("-" * len(hdr))
    for layer in ("ab", "ba"):
        c = layers[layer]
        for leg in ("armed", "baseline"):
            print(
                f"{layer:>6} {c['games']:>6} {leg:>9} {c[f'{leg}_frames']:>7} "
                f"{c[f'{leg}_episodes']:>9} {c[f'{leg}_jumps']:>8} "
                f"{c[f'{leg}_draughts']:>10}"
            )
    print()
    print("NOTE: domain is a SUPERSET (charges invisible) -- see LIMITS 1-2.")
    print("      'hp>=90' alone is NOT a draught; '+mana too' is the column that")
    print("      survives the impostor in the module docstring.")
    if a.verbose and jump_rows:
        print("\ndraught-sized HP gains inside the domain:")
        for r in jump_rows:
            print("  ", r)


if __name__ == "__main__":
    main()
