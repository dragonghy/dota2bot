#!/usr/bin/env python3
"""Census: which talents the frozen real-frame corpus can SHOW you -- and which
it is structurally blind to.

WHY THIS EXISTS (hero group, 2026-08-27)
----------------------------------------
Five consecutive hero rounds priced talent rows (the TALENTPRICE baton, GH #238
-> #251 -> #255).  Every one of them argued from the game's own KV, and every
one of them recorded, as an honest bound, that no frame in this repo shows the
talent actually trained.  This script asks the question those five rounds kept
deferring: **can a frame in this repo show a trained talent at all?**

The answer is one-sided, and it is not the same for the two KINDS of talent:

  * GENERIC rows (`special_bonus_hp_200`, `special_bonus_attack_damage_25`,
    `special_bonus_movement_speed_20`, ...) DO appear in the dumped ability
    array -- 67 times across the corpus, and every one of them is exactly the
    row the hero's shipped `tTalentTreeList` picks.
  * HERO-UNIQUE rows (`special_bonus_unique_*`) appear **zero** times, in any
    fixture, on any hero, at any level -- including a Viper at hero level 19,
    who by the game's own rules holds three trained talents.

So the corpus is silent about `special_bonus_unique_*`, which is 7 of the 8
slots on a typical hero and BOTH sides of most rows this desk has priced.

WHAT THIS PROVES, AND WHAT IT DOES NOT
--------------------------------------
It PROVES the corpus cannot answer "was this unique talent trained?" -- a read
that can only ever come back zero is not evidence about the world.  That is the
whole finding, and it is enough to disqualify a class of argument.

It does NOT decide WHY the zero is there.  Two accounts survive it, and they are
observationally identical from a dump:

  H1 (INSTRUMENT)  the dumper drops unique talents.  Its own filter
      (`isRealAbility`, tools/batch_test/behavioral/dumper/main.go) discards any
      entity whose class name contains `Special_Bonus_Base` or
      `Special_Bonus_Attributes` BEFORE the branch that keeps leveled talents.
      That first line only ever does work on an entity that IS leveled -- an
      untrained talent is already dropped by `level > 0` on the next line -- so
      it is load-bearing exactly on trained talents.  Note also that the names
      that DO survive are class names, not KV names (`special_bonus_h_p200`,
      not the KV's `special_bonus_hp_200`), which is what makes "generic rows
      have their own C++ class, unique rows share a base class" a live account.
  H2 (WORLD)  the bots never train a unique talent -- the point is unspent or
      lands elsewhere.

They differ enormously in consequence (H1 = every corpus talent read is blind;
H2 = five rounds of pricing bought rows nobody ever takes), and NOTHING in this
repo separates them today.  Separating them needs one re-dump of one archived
replay with the filter's first line removed; that is a harness question and it
is filed as one.

WHY THE CROSS-TAB IS THE LOAD-BEARING HALF
------------------------------------------
"No unique talent in the corpus" would be uninteresting if no bot ever picked
one.  The cross-tab closes that hole on the focus five, whose talent tables are
single-row (role-independent), by decoding what each of them actually picks:

    aba_skill.X.GetTalentBuild:  {0, 10} -> slot 1     {10, 0} -> slot 2

  crystal_maiden t10 -> slot 1  special_bonus_hp_200          SEEN (generic)
  zuus           t10 -> slot 2  special_bonus_hp_200          SEEN (generic)
  lion           t10 -> slot 2  special_bonus_movement_speed_20  SEEN (generic)
  axe            t10 -> slot 2  special_bonus_unique_axe_8    NEVER SEEN
  skeleton_king  t10 -> slot 2  special_bonus_unique_..._facet_1  NEVER SEEN

Three of five picks are generic and the corpus shows each of them, by name, on
the hero that picks it.  The two unique picks are invisible.  The split is by
KIND, not by hero and not by level.

Usage:

    python3 tools/agent/fixture_talent_census.py             # census
    python3 tools/agent/fixture_talent_census.py --snapshot  # write the Lua table

Network: none.  Reads tests/fixtures/*.lua, tests/mock/talent_slots.lua and
bots/BotLib/hero_*.lua off disk.  Zero AWS.
"""

import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIXTURE_GLOB = os.path.join(ROOT, "tests", "fixtures", "*.lua")
SLOTS_MOCK = os.path.join(ROOT, "tests", "mock", "talent_slots.lua")
SNAPSHOT = os.path.join(ROOT, "tests", "mock", "fixture_talent_sightings.lua")

FOCUS = ("axe", "zuus", "skeleton_king", "lion", "crystal_maiden")

# Anti-vacuum floors.  A parse that silently matched nothing would print
# "unique sightings: 0" -- the SAME last line a correct run prints.  That shape
# cost this desk a near-miss one round ago (facet_census.py, missing re.M), so
# the refusal is mechanical rather than remembered.
MIN_FIXTURES = 50
MIN_HERO_FRAMES = 500
MIN_SIGHTINGS = 20


def _unit_blocks(src):
    """Yield (hero_short_name, level, [ability names]) for one fixture file."""
    for block in re.split(r"\n    \{ name = ", src)[1:]:
        m = re.match(r"'(npc_dota_hero_[^']+)'", block)
        if m is None:
            continue
        lv = re.search(r" level = (\d+)", block)
        ab = re.search(r"abilities = \{(.*?)\}\s*\},", block, re.S)
        if lv is None or ab is None:
            continue
        names = re.findall(r"name = '([^']*)', level = (-?\d+)", ab.group(1))
        yield m.group(1)[len("npc_dota_hero_"):], int(lv.group(1)), names


def is_talent(name):
    return name.startswith("special_bonus")


def is_unique(name):
    # The dumper snake-cases a CLASS name, so a unique row could reach us as
    # `special_bonus_unique_...` either way; match on the token, not a prefix.
    return "unique" in name


def skill_points_on_abilities(names):
    """Skill points visibly spent on abilities in one dumped ability array.

    Innates cost no point and the dump still carries them at level 1 (every
    Wraith King frame carries skeleton_king_INNATE_vampiric_spirit, GH #36
    note in hero_skeleton_king.lua), so they are excluded by name.

    LOWER BOUND, not an equality: a facet-granted ability also costs no point
    and this cannot tell one from a learned ability, so the count can only be
    too HIGH -- which makes the deficit below too SMALL.  The finding is that
    the deficit exists, so a conservative bias is the right direction.
    """
    return sum(int(lvl) for n, lvl in names
               if not is_talent(n) and "_innate_" not in n)


def collect():
    # (fixture, hero, level, [talent names], ability points visible)
    frames = []
    fixtures = sorted(glob.glob(FIXTURE_GLOB))
    for path in fixtures:
        with open(path) as fh:
            src = fh.read()
        base = os.path.basename(path)
        for hero, level, names in _unit_blocks(src):
            talents = [n for n, _ in names if is_talent(n)]
            frames.append((base, hero, level, talents,
                           skill_points_on_abilities(names)))
    return fixtures, frames


# ---------------------------------------------------------------- shipped pick

def parse_slot_names():
    """hero -> {slot: talent name} out of the generated talent_slots mock."""
    out = {}
    hero = None
    with open(SLOTS_MOCK) as fh:
        for line in fh:
            m = re.match(r"\s*\['([a-z_]+)'\] = \{\s*$", line)
            if m:
                hero = m.group(1)
                out[hero] = {}
                continue
            m = re.match(r"\s*\[(\d)\] = \{ name = '([^']+)'", line)
            if m and hero:
                out[hero][int(m.group(1))] = m.group(2)
    return out


def parse_shipped_pick(hero):
    """(slot, rows) for this hero's t10 pick; rows = number of role tables.

    Decoding is aba_skill.X.GetTalentBuild's own arithmetic:
        nTalentBuildList[1] = ( tTalentTreeList['t10'][1] == 0 and 1 or 2 )
    i.e. {0, 10} takes slot 1 and {10, 0} takes slot 2.
    """
    path = os.path.join(ROOT, "bots", "BotLib", "hero_%s.lua" % hero)
    with open(path) as fh:
        src = fh.read()
    src = re.sub(r"--[^\n]*", "", src)          # never read our own prose back
    body = re.search(r"tTalentTreeList = \{(.*?)\n\}", src, re.S)
    if body is None:
        return None, 0
    rows = re.findall(r"\['t10'\]\s*=\s*\{\s*(\d+)\s*,\s*(\d+)\s*\}", body.group(1))
    if not rows:
        return None, 0
    slots = set(1 if int(a) == 0 else 2 for a, _ in rows)
    return (slots.pop() if len(slots) == 1 else None), len(rows)


def build():
    fixtures, frames = collect()
    if len(fixtures) < MIN_FIXTURES or len(frames) < MIN_HERO_FRAMES:
        sys.stderr.write(
            "REFUSING TO REPORT: parsed %d fixtures / %d hero-frames, floors are "
            "%d / %d. A parse that matched nothing prints the same last line as a "
            "correct run.\n" % (len(fixtures), len(frames), MIN_FIXTURES,
                                MIN_HERO_FRAMES))
        sys.exit(2)

    sightings = [(f, h, lv, t) for (f, h, lv, ts, _pts) in frames for t in ts]
    if len(sightings) < MIN_SIGHTINGS:
        sys.stderr.write("REFUSING TO REPORT: %d talent sightings, floor is %d.\n"
                         % (len(sightings), MIN_SIGHTINGS))
        sys.exit(2)

    slot_names = parse_slot_names()
    focus = {}
    for hero in FOCUS:
        slot, rows = parse_shipped_pick(hero)
        name = (slot_names.get(hero) or {}).get(slot) if slot else None
        seen = sum(1 for s in sightings if s[1] == hero)
        focus[hero] = {
            "slot": slot, "rows": rows, "name": name,
            "kind": ("unique" if name and is_unique(name) else
                     "generic" if name else "?"),
            "sightings": seen,
            "frames_lv10": sum(1 for f in frames if f[1] == hero and f[2] >= 10),
            "deficit_lv10": sum(1 for f in frames
                                if f[1] == hero and f[2] >= 10
                                and (f[2] - f[4] - len(f[3])) >= 1),
        }

    per_talent = collections.Counter((h, t) for (_, h, _, t) in sightings)

    # Point accounting.  A hero at level L holds L skill points and a talent
    # costs the level's point, so
    #     deficit = L - (points visibly on abilities) - (talents dumped)
    # is the number of points the frame cannot account for.  A deficit of 1 is
    # exactly the shape of "the level-10 talent is not in this dump" -- whether
    # it was trained and dropped, or never trained, this cannot say.
    deficits = collections.Counter(
        lv - pts - len(ts) for (_f, _h, lv, ts, pts) in frames)

    # The frame that separates the instrument from the world, if one exists:
    # a single fixture where one hero's generic talent IS dumped while another
    # hero at level >= 10 carries a deficit and no talent at all.  The dumper
    # cannot be blind and not-blind in the same frame.
    split = []
    by_fixture = collections.defaultdict(list)
    for row in frames:
        by_fixture[row[0]].append(row)
    for fx, rows in sorted(by_fixture.items()):
        shown = [r for r in rows if r[3]]
        blind = [r for r in rows
                 if r[2] >= 10 and not r[3] and (r[2] - r[4]) >= 1]
        if shown and blind:
            split.append((fx, sorted(r[1] for r in shown),
                          sorted(r[1] for r in blind)))

    return {
        "fixtures": len(fixtures),
        "hero_frames": len(frames),
        "frames_lv10": sum(1 for f in frames if f[2] >= 10),
        "frames_lv15": sum(1 for f in frames if f[2] >= 15),
        "frames_lv20": sum(1 for f in frames if f[2] >= 20),
        "max_level": max(f[2] for f in frames),
        "sightings": len(sightings),
        "unique_sightings": sum(1 for s in sightings if is_unique(s[3])),
        "sightings_lv15": sum(1 for s in sightings if s[2] >= 15),
        "max_talents_on_one_frame": max((len(f[3]) for f in frames), default=0),
        "zero_talent_frames_lv10": sum(1 for f in frames
                                       if f[2] >= 10 and not f[3]),
        "deficit_frames_lv10": sum(1 for f in frames
                                   if f[2] >= 10 and (f[2] - f[4] - len(f[3])) >= 1),
        "split_fixtures": len(split),
        "per_talent": per_talent,
        "deficits": deficits,
        "split": split,
        "focus": focus,
    }


def report(d):
    print("=== fixture talent census ===")
    print("fixtures                     : %d" % d["fixtures"])
    print("hero-frames                  : %d" % d["hero_frames"])
    print("  at hero level >= 10        : %d  (of which 0 talents: %d)"
          % (d["frames_lv10"], d["zero_talent_frames_lv10"]))
    print("  at hero level >= 15        : %d  (game guarantees >= 2 talents)"
          % d["frames_lv15"])
    print("  at hero level >= 20        : %d" % d["frames_lv20"])
    print("  highest level seen         : %d" % d["max_level"])
    print("talent sightings             : %d" % d["sightings"])
    print("  hero-unique (unique)       : %d" % d["unique_sightings"])
    print("  on a level >= 15 frame     : %d" % d["sightings_lv15"])
    print("  most on one frame          : %d" % d["max_talents_on_one_frame"])
    print()
    print("--- what the corpus DOES show (hero, talent, frames) ---")
    for (hero, talent), n in sorted(d["per_talent"].items()):
        print("    %-18s %-34s %d" % (hero, talent, n))
    print()
    print("--- point accounting: level - ability points - talents dumped ---")
    for k in sorted(d["deficits"]):
        print("    %+d : %d frames" % (k, d["deficits"][k]))
    print("    frames at level >= 10 with a deficit >= 1: %d"
          % d["deficit_frames_lv10"])
    print()
    print("--- fixtures where ONE frame both shows and hides a talent ---")
    print("    (instrument cannot be blind and not-blind in the same frame)")
    for fx, shown, blind in d["split"][:8]:
        print("    %-46s shows %-28s blind %s"
              % (fx, ",".join(shown), ",".join(blind)))
    print("    ... %d such fixtures in total" % d["split_fixtures"])
    print()
    print("--- focus five: shipped t10 pick vs what the corpus can show ---")
    for hero in FOCUS:
        f = d["focus"][hero]
        print("    %-15s rows=%d slot=%s %-8s %-42s frames>=10: %2d  sightings: %d"
              % (hero, f["rows"], f["slot"], f["kind"], f["name"],
                 f["frames_lv10"], f["sightings"]))


def snapshot(d):
    L = []
    L.append("-- GENERATED by tools/agent/fixture_talent_census.py --snapshot "
             "-- do not hand-edit.")
    L.append("--")
    L.append("-- What the frozen real-frame corpus (tests/fixtures/*.lua) can and")
    L.append("-- cannot show about TRAINED talents.  Generic rows appear by name;")
    L.append("-- hero-unique (`special_bonus_unique_*`) rows appear ZERO times, on")
    L.append("-- any hero, at any level -- including a level-19 frame that holds")
    L.append("-- three trained talents by the game's own rules.")
    L.append("--")
    L.append("-- This is a BLINDNESS registry, not a claim about what bots train.")
    L.append("-- See tools/agent/fixture_talent_census.py for the two accounts")
    L.append("-- (dumper filter / never trained) the corpus cannot separate.")
    L.append("--")
    L.append("-- Regenerate:")
    L.append("--   python3 tools/agent/fixture_talent_census.py --snapshot")
    L.append("")
    L.append("local X = {}")
    L.append("")
    L.append("X.CORPUS = {")
    for k in ("fixtures", "hero_frames", "frames_lv10", "frames_lv15",
              "frames_lv20", "max_level", "sightings", "unique_sightings",
              "sightings_lv15", "max_talents_on_one_frame",
              "zero_talent_frames_lv10", "deficit_frames_lv10",
              "split_fixtures"):
        L.append("    %s = %d," % (k, d[k]))
    L.append("}")
    L.append("")
    L.append("-- hero -> talent name -> number of fixture frames showing it")
    L.append("X.SIGHTINGS = {")
    heroes = sorted(set(h for (h, _) in d["per_talent"]))
    for hero in heroes:
        L.append("    ['%s'] = {" % hero)
        for (h, t), n in sorted(d["per_talent"].items()):
            if h == hero:
                L.append("        ['%s'] = %d," % (t, n))
        L.append("    },")
    L.append("}")
    L.append("")
    L.append("-- focus five: the t10 row their shipped tTalentTreeList picks,")
    L.append("-- decoded by aba_skill.X.GetTalentBuild ({0,10} -> slot 1,")
    L.append("-- {10,0} -> slot 2), and how often the corpus shows that hero any")
    L.append("-- talent at all.  rows = number of role tables (1 = role-blind).")
    L.append("X.FOCUS_T10 = {")
    for hero in FOCUS:
        f = d["focus"][hero]
        L.append("    ['%s'] = { slot = %s, rows = %d, name = '%s', kind = '%s', "
                 "sightings = %d, frames_lv10 = %d, deficit_lv10 = %d },"
                 % (hero, f["slot"], f["rows"], f["name"], f["kind"],
                    f["sightings"], f["frames_lv10"], f["deficit_lv10"]))
    L.append("}")
    L.append("")
    L.append("-- Fixtures where ONE frozen instant both SHOWS a trained talent on")
    L.append("-- one hero and shows none on another hero who is level >= 10 and")
    L.append("-- cannot account for all his skill points.  A dumper cannot be")
    L.append("-- blind and not-blind inside the same frame, so these are where")
    L.append("-- the instrument story and the never-trained story come apart.")
    L.append("X.SPLIT = {")
    for fx, shown, blind in d["split"]:
        L.append("    { fixture = '%s', shows = { %s }, blind = { %s } },"
                 % (fx,
                    ", ".join("'%s'" % s for s in shown),
                    ", ".join("'%s'" % s for s in blind)))
    L.append("}")
    L.append("")
    L.append("return X")
    with open(SNAPSHOT, "w") as fh:
        fh.write("\n".join(L) + "\n")
    print("wrote %s" % os.path.relpath(SNAPSHOT, ROOT))


def main(argv):
    d = build()
    report(d)
    if "--snapshot" in argv:
        print()
        snapshot(d)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
