#!/usr/bin/env python3
"""Pins tools/batch_test/behavioral/odaoe_liveness.py.

The load-bearing assertion is `hero_centred_cover`: it encodes a fact about the
SOURCE (the shipped branch returns `enemyHero:GetLocation()`, the gated branch
may return a midpoint) and is the only discriminator in that file that does not
depend on a damage model, on fog, or on how stale the sampled mana is.  It is
also the one that FALSIFIED the `odaoe` verdict -- it reads 5 on the armed leg
and 5 on the baseline leg, where the gate is provably inert -- so its behaviour
has to be nailed down or the falsification cannot be trusted either.

Run: python3 tests/test_odaoe_liveness.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools", "batch_test", "behavioral"))
import odaoe_liveness as L  # noqa: E402

CHECKS = 0
FAILS = 0


def eq(got, want, label):
    global CHECKS, FAILS
    CHECKS += 1
    if got != want:
        FAILS += 1
        print(f"FAIL {label}: got {got!r} want {want!r}")


def pt(x, y):
    return {"x": float(x), "y": float(y)}


def test_leg_of():
    # The leg assignment is the whole experiment: get it backwards and every
    # count swaps legs while still looking like a plausible table.
    eq(L.leg_of(2, "radiant"), "armed", "radiant OD on a radiant-armed game")
    eq(L.leg_of(3, "dire"), "armed", "dire OD on a dire-armed game")
    eq(L.leg_of(2, "dire"), "baseline", "radiant OD on a dire-armed game")
    eq(L.leg_of(3, "radiant"), "baseline", "dire OD on a radiant-armed game")
    eq(L.leg_of(3, " Dire "), "armed", "the side stamp is trimmed and folded")
    # An unusable stamp must NOT default into a leg: defaulting sends every
    # unstamped game to one side, and that bias has a sign.
    eq(L.leg_of(2, None), None, "missing stamp")
    eq(L.leg_of(2, ""), None, "empty stamp")
    eq(L.leg_of(2, "radiant_side"), None, "near-miss stamp is not a match")
    eq(L.leg_of(1, "radiant"), None, "team 1 is not a playing team")


def test_ult_casts_and_victims():
    ev = [{"type": "ABILITY", "actor": L.OD, "inflictor": L.ULT, "t": 5.0},
          {"type": "ABILITY", "actor": L.OD, "inflictor": L.ULT, "t": 200.0},
          {"type": "ABILITY", "actor": L.OD,
           "inflictor": "obsidian_destroyer_astral_imprisonment", "t": 5.2},
          {"type": "ABILITY", "actor": "npc_dota_hero_lina",
           "inflictor": L.ULT, "t": 5.4},
          {"type": "DAMAGE", "actor": L.OD, "inflictor": L.ULT, "t": 5.0,
           "target": "npc_dota_hero_pudge", "target_hero": True},
          {"type": "CRITICAL_DAMAGE", "actor": L.OD, "inflictor": L.ULT,
           "t": 5.0, "target": "npc_dota_hero_zuus", "target_hero": True},
          {"type": "DAMAGE", "actor": L.OD, "inflictor": L.ULT, "t": 5.0,
           "target": "npc_dota_creep_badguys_melee", "target_hero": False},
          {"type": "DAMAGE", "actor": L.OD, "inflictor": L.ULT, "t": 5.0,
           "target": "npc_dota_hero_pudge", "target_hero": True}]
    eq(L.ult_casts(ev), [5.0, 200.0], "both ult casts, in time order")
    v = L.cast_victims(ev, 5.0, 1.0)
    eq(sorted(v), ["npc_dota_hero_pudge", "npc_dota_hero_zuus"],
       "hero victims are de-duplicated and creeps excluded")
    eq(len(L.cast_victims(ev, 200.0, 1.0)), 0,
       "the second cast has no damage of its own")
    eq(len(L.cast_victims(ev, 5.0, 0.0)), 2,
       "a zero window still catches same-tick damage")


def test_followed_by_cast():
    eq(L.followed_by_cast(100.0, [102.5], 2.0), None, "just outside the window")
    eq(L.followed_by_cast(100.0, [101.9], 2.0), 101.9, "just inside the window")
    eq(L.followed_by_cast(100.0, [99.9, 101.0], 2.0), 101.0,
       "the earlier cast is BEFORE the frame and must not be claimed")
    eq(L.followed_by_cast(100.0, [], 2.0), None, "no casts at all")


def test_hero_centred_cover():
    # The shipped branch centres the circle ON an enemy hero; the gated branch
    # may centre it on a midpoint. So "no hero-centred circle holds all the
    # victims" is the model-free signature of a NON-shipped cast.
    a, b = pt(0, 0), pt(400, 0)
    eq(L.hero_centred_cover([a, b], [a, b], 500.0, 0.0), True,
       "400 apart fits a 500 circle on either hero")
    eq(L.hero_centred_cover([a, pt(600, 0)], [a, pt(600, 0)], 500.0, 0.0), False,
       "600 apart needs the midpoint")
    eq(L.hero_centred_cover([a, pt(1000, 0)], [a, pt(1000, 0)], 500.0, 0.0), False,
       "1000 apart does not even fit the midpoint, let alone a hero centre")
    eq(L.hero_centred_cover([a, pt(600, 0)], [pt(300, 0)], 500.0, 0.0), True,
       "a bystander standing at the midpoint makes it hero-centred")
    eq(L.hero_centred_cover([a], [a], 500.0, 0.0), True, "one victim always fits")
    eq(L.hero_centred_cover([a, pt(600, 0)], [], 500.0, 0.0), False,
       "an empty enemy list can never cover anything")
    # ONLY an enemy hero's own position may serve as a centre. Placed far from
    # the origin on purpose: a mutant that quietly appends (0, 0) to the centre
    # list survives every case that happens to sit near the origin, and the
    # first version of this test was exactly that case (M5).
    far_a, far_b = pt(6000, -2000), pt(6000, -2600)
    eq(L.hero_centred_cover([far_a, far_b], [far_a, far_b], 500.0, 0.0), False,
       "600 apart, far from origin: still needs a midpoint")
    eq(L.hero_centred_cover([far_a, far_b], [pt(6000, -2300)], 500.0, 0.0), True,
       "and a real enemy standing between them rescues it")
    # The sharp form of the same trap: a pair straddling the map origin, whose
    # MIDPOINT is (0, 0). Only a centre list contaminated with a literal origin
    # turns this True -- and only this shape can tell the two apart, because a
    # bogus centre is invisible unless it alone covers every victim.
    eq(L.hero_centred_cover([pt(0, 400), pt(0, -400)],
                            [pt(0, 400), pt(0, -400)], 500.0, 0.0), False,
       "a pair straddling the origin is still not hero-centred")
    # The tolerance is the sub-second the victims kept moving. It must be an
    # ADDITIVE slack on the radius, and it must be able to flip a marginal case
    # -- that is exactly why the caller keeps it small and reports it.
    eq(L.hero_centred_cover([a, pt(560, 0)], [a, pt(560, 0)], 500.0, 0.0), False,
       "560 apart fails at zero tolerance")
    eq(L.hero_centred_cover([a, pt(560, 0)], [a, pt(560, 0)], 500.0, 100.0), True,
       "the same pair passes once 100u of movement is allowed")
    # Two dimensions, not one: a diagonal spread must use real distance.
    eq(L.hero_centred_cover([a, pt(300, 400)], [a, pt(300, 400)], 500.0, 0.0), True,
       "a 3-4-5 diagonal of exactly 500 is covered")
    eq(L.hero_centred_cover([a, pt(400, 400)], [a, pt(400, 400)], 500.0, 0.0), False,
       "a 566u diagonal is not -- so the test is not reading only x")


def main():
    test_leg_of()
    test_ult_casts_and_victims()
    test_followed_by_cast()
    test_hero_centred_cover()
    print(f"test_odaoe_liveness: {CHECKS} checks / {FAILS} failures")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
