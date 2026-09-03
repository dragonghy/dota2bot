#!/usr/bin/env python3
"""Runs `slotdust_arbitration.py`'s corpus-free selfcheck battery from the suite.

WHY THIS FILE EXISTS.  `tests/run_py_tests.sh` only loops over `tests/test_*.py`,
so a probe that is only ever invoked by hand is a probe nothing in the tree runs
-- the GH #243 shape, same as `tests/test_fieldsip_domain.py`.

⭐ WHAT IS ACTUALLY BEING PROTECTED HERE: THE ITEM-NAME VOCABULARY.
The probe's first run over W40 put 10 casts on the BASELINE leg of a column
whose baseline is structurally zero.  One of the two causes was that its B3
exclusion asked snapshot `items[]` for `"item_radiance"`, and snapshot `items[]`
never says `item_radiance` -- it says `radiance`.  Over that corpus the combat
log's 87 distinct `item_*` inflictor names and `items[]`'s 164 distinct names
share NOTHING, and for several items the map is not even a prefix strip
(`item_dust` -> `dustof_appearance`, `item_bottle` -> `empty_bottle`).

An `item_`-prefixed literal tested against `items[]` is therefore not a rare
miss but ALWAYS false, and it fails silently in the PERMISSIVE direction for
every "the enemy does not carry X" exclusion.  That is a whole class of defect,
not one typo, so it is pinned here from both sides: the snapshot spelling must
block, and the combat-log spelling must NOT be what the probe looks for.

The second cause is pinned too: `WasRecentlyDamagedByPlayer` is per-PLAYER, so a
summon's or illusion's damage counts for the engine while its combat-log actor
is not a hero.  Filtering the B4 exclusion on `actor_hero` leaves B4 reachable
on exactly those frames.
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROBE = os.path.join(REPO, "tools", "batch_test", "behavioral",
                     "slotdust_arbitration.py")


def main():
    if not os.path.exists(PROBE):
        print("FAIL: %s is missing" % PROBE)
        return 1

    # The probe's own battery. Its exit code is read from a DIRECT call --
    # never through a pipe (evidence discipline 3).
    proc = subprocess.run([sys.executable, PROBE, "--selfcheck"],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = proc.stdout.decode("utf-8", "replace")
    print(out, end="" if out.endswith("\n") else "\n")
    if proc.returncode != 0:
        print("FAIL: slotdust_arbitration.py --selfcheck exit %d" % proc.returncode)
        return 1
    if "0 fail" not in out:
        print("FAIL: selfcheck did not report a clean battery")
        return 1

    # The vocabulary trap, asserted against the module rather than the CLI so a
    # future edit that reintroduces the combat-log spelling fails HERE.
    sys.path.insert(0, os.path.dirname(PROBE))
    import slotdust_arbitration as S

    ok = True
    if S.RADIANCE.startswith("item_"):
        print("FAIL: RADIANCE is the combat-log spelling; snapshot items[] "
              "never carries an `item_` prefix (probe LIMIT 9)")
        ok = False
    if S.DUST != "item_dust":
        print("FAIL: DUST must stay the COMBAT-LOG spelling -- it is matched "
              "against events[].inflictor, not against items[]")
        ok = False

    # The B4 exclusion must not be narrowed back to hero-sourced damage.
    snaps = []
    for pid in range(10):
        team = S.RADIANT if pid < 5 else S.DIRE
        for t in (-30.0, 9.0, 11.0):
            snaps.append({"t": t, "hero": "npc_dota_hero_h%d" % pid,
                          "idx": 100 + pid, "team": team, "player_id": pid,
                          "x": 0.0 if pid == 5 else 9000.0, "y": 0.0,
                          "hp": 500, "hp_pct": 0.5, "items": [""] * 9})
    events = [
        {"t": 9.6, "type": "DAMAGE", "actor": "npc_dota_lycan_wolf1",
         "target": "npc_dota_hero_h5", "inflictor": "", "value": 40,
         "actor_hero": False, "target_hero": True},
        {"t": 10.0, "type": "ITEM", "actor": "npc_dota_hero_h5",
         "target": "npc_dota_hero_h5", "inflictor": "item_dust", "value": 0,
         "actor_hero": True, "target_hero": True},
    ]
    res, rows, _ = S.scan_game({"snapshots": snaps, "events": events}, "dire")
    if res["armed"]["blocked_b4_recent_damage"] != 1 or res["armed"]["exclusive"] != 0:
        print("FAIL: summon damage did not disarm the B4 exclusion (LIMIT 10)")
        ok = False

    if not ok:
        return 1
    print("test_slotdust_arbitration: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
