#!/usr/bin/env python3
"""Occurrence-rate meter for "did this bot's own level-up table actually drive
the hero" (replay-check 2026-09-13T18:48Z handoff item 3).

Mapping-free by construction: instead of resolving build number -> ability name
(which needs GetAbilityList's slot rules), both sequences are reduced to their
CANONICAL SHAPE (relabel each symbol by order of first occurrence).  Two
sequences have the same shape iff they are equal up to a bijection of symbols.
A hero driven by the engine's default AI has no reason to reproduce our build's
shape; a hero driven by BotLib reproduces it exactly.

Talents are stripped from the measured sequence (GetSkillList interleaves them
at hero level 10/15/20/25; the ability build list itself carries no talents).
"""
import json
import os
import re
import sys
from collections import OrderedDict

BOTLIB = "/home/user/dota2bot/bots/BotLib"


def parse_hero_lua(hero_npc):
    """-> (builds:list[list[int]], bDeafaultAbility:bool|None) or None."""
    short = hero_npc.replace("npc_dota_hero_", "")
    # name canon: BotLib is inconsistent about underscores
    # (npc_dota_hero_vengeful_spirit -> hero_vengefulspirit.lua)
    for cand in (short, short.replace("_", "")):
        path = os.path.join(BOTLIB, "hero_%s.lua" % cand)
        if os.path.exists(path):
            break
    else:
        return None
    src = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"tAllAbilityBuildList\s*=\s*\{(.*?)\n\s*\}", src, re.S)
    builds = []
    if m:
        for row in re.findall(r"\{([0-9,\s]+)\}", m.group(1)):
            nums = [int(x) for x in re.findall(r"\d+", row)]
            if nums:
                builds.append(nums)
    dm = re.search(r"bDeafaultAbility'?\]?\s*=\s*(true|false)", src)
    default_ability = (dm.group(1) == "true") if dm else None
    return builds, default_ability


def canon(seq):
    """Relabel by order of first occurrence -> tuple of ints."""
    order = OrderedDict()
    out = []
    for s in seq:
        if s not in order:
            order[s] = len(order)
        out.append(order[s])
    return tuple(out)


def is_talent(name):
    return name.startswith("special_bonus")


def queue_slot_kind(slot, n_abil=15, n_talents=8):
    """Which entry sits at 1-based `slot` of J.Skill.GetSkillList's queue.

    Transcribed from bots/FunLib/aba_skill.lua:217 -- the slot rule, not a
    guess: a talent is placed when `i >= 10 and (i % 5 == 0 or the ability
    build is exhausted)`.  For the usual 15-ability / 8-talent hero that gives
    [a1..a9, T1, a10, a11, a12, a13, T2, a14, a15, T3..T8], so a hero holding
    13 ability points and 1 talent has consumed slots 1..14 and its HEAD is
    slot 15 = T2, the level-15 talent.
    """
    ability_idx = 1
    talent_idx = 1
    for i in range(1, n_abil + n_talents + 1):
        if i >= 10 and (i % 5 == 0 or ability_idx > n_abil):
            kind = "T%d" % talent_idx
            talent_idx += 1
        elif ability_idx <= n_abil:
            kind = "a%d" % ability_idx
            ability_idx += 1
        else:
            kind = "-"
        if i == slot:
            return kind
    return "past_end"


def measured_levelups(tl):
    """-> {hero: {idx, events, n_bodies, final_lvl, end_t}}

    `events` is the interleaved point-spend stream, oldest first:
    (t, hero_level, kind, label) with kind in {'abil','talent'}.
    """
    first_idx = {}
    bodies = {}
    for s in tl["snapshots"]:
        bodies.setdefault(s["hero"], set()).add(s["idx"])
        if s["hero"] not in first_idx:
            # snapshots are time-ordered; the first one is the pre-horn body
            first_idx[s["hero"]] = s["idx"]
    lvl = {}
    events = {}
    final_lvl = {}
    end_t = {}
    for s in tl["snapshots"]:
        h = s["hero"]
        if s["idx"] != first_idx[h]:
            continue
        final_lvl[h] = s.get("level")
        end_t[h] = s.get("t")
        abils = s.get("abilities") or []
        if h not in lvl:
            # baseline = the pre-horn frame.  Innates (fowl_play, prickly, ...)
            # are already level 1 there and must NOT count as a skill point.
            lvl[h] = {a["name"]: a["level"] for a in abils}
            continue
        cur = lvl[h]
        step = []
        tstep = []
        for a in abils:
            name = a["name"]
            if name not in cur:
                # A TALENT is not "granted late": it is absent from the pre-horn
                # frame and appears the instant it is TAKEN, so its baseline is 0
                # and its arrival IS the point spent.  Swallowing it here is what
                # made every talent invisible to this meter before (replay-check
                # 2026-09-13T21:48Z pitfall (2), GH #799 acceptance 1).
                # A scepter/shard ability (shadow_shaman_urnaconda) really is
                # granted late and keeps the baseline-at-arrival treatment.
                cur[name] = 0 if is_talent(name) else a["level"]
            if a["level"] > cur[name]:
                d = a["level"] - cur[name]
                (tstep if is_talent(name) else step).extend([name] * d)
                cur[name] = a["level"]
        if step:
            # abilities that rise in the SAME frame are one skill point spent on
            # one linked ability (nevermore_shadowraze1/2/3).  Talents never do
            # this, so they are never folded into that label.
            events.setdefault(h, []).append(
                (s.get("t"), s.get("level"), "abil", "+".join(sorted(set(step)))))
        for name in tstep:
            events.setdefault(h, []).append(
                (s.get("t"), s.get("level"), "talent", name))
    return {h: {"idx": first_idx[h], "events": events.get(h, []),
                "n_bodies": len(bodies[h]), "final_lvl": final_lvl.get(h),
                "end_t": end_t.get(h)}
            for h in first_idx}


def main(paths):
    rows = []
    for p in paths:
        game = os.path.basename(p).replace(".timeline.json", "")
        tl = json.load(open(p))
        for hero, rec in sorted(measured_levelups(tl).items()):
            idx, nbodies = rec["idx"], rec["n_bodies"]
            ev = rec["events"]
            meta = parse_hero_lua(hero)
            talents = [e[3] for e in ev if e[2] == "talent"]
            abil = [e[3] for e in ev if e[2] == "abil"]
            # the wall: last point spent, and how long the hero sat on the
            # unspent ones afterwards (GH #799).
            last_t = ev[-1][0] if ev else None
            last_lvl = ev[-1][1] if ev else None
            fin = rec["final_lvl"]
            stall = (round(rec["end_t"] - last_t, 1)
                     if (ev and rec["end_t"] is not None and last_t is not None)
                     else None)
            # queue position consumed = one per point, talents included; the
            # HEAD is the next slot.  GetSkillList (aba_skill.lua:217) with a
            # 15-entry build lays out [a1..a9, T1, a10..a13, T2, a14, a15, T3..].
            if meta is None:
                rows.append((game, hero, idx, nbodies, len(abil), len(talents),
                             "NO_BOTLIB_FILE", "",
                             last_lvl, fin, stall, "?"))
                continue
            builds, default_ab = meta
            n_abil_slots = max((len(b) for b in builds), default=15)
            head = queue_slot_kind(len(ev) + 1, n_abil_slots)
            tail = (last_lvl, fin, stall, head)
            if default_ab is not False:
                rows.append((game, hero, idx, nbodies, len(abil), len(talents),
                             "OUT_OF_DOMAIN(bDeafaultAbility=%s)" % default_ab,
                             "") + tail)
                continue
            if not builds:
                rows.append((game, hero, idx, nbodies, len(abil), len(talents),
                             "OUT_OF_DOMAIN(no build parsed)", "") + tail)
                continue
            # a hero with several rows picks one at random (GetRandomBuild):
            # matching ANY row is a match, so enumerate them.
            cm = canon(abil)
            n = len(cm)
            verdict = None
            if n == 0:
                verdict = "NO_POINTS"
            else:
                worst = None
                for build in builds:
                    cb = canon(build)
                    if cm == cb[:n]:
                        verdict = "MATCH" if n == len(cb) else "MATCH_PREFIX"
                        break
                    bad = next(i for i in range(n) if i >= len(cb) or cm[i] != cb[i])
                    worst = bad if worst is None else max(worst, bad)
                if verdict is None:
                    verdict = "DEVIATION@%d" % (worst + 1)
                if len(builds) > 1:
                    verdict += "[of %d rows]" % len(builds)
            rows.append((game, hero, idx, nbodies, n, len(talents), verdict,
                         ",".join(str(x) for x in cm)) + tail)
    hdr = ("game", "hero", "idx", "bodies", "n_abil_pts", "n_talents", "verdict",
           "canon_measured", "last_pt_lvl", "final_lvl", "stall_s", "head_slot")
    print("\t".join(hdr))
    for r in rows:
        print("\t".join(str(x) for x in r))
    # summary
    from collections import Counter
    c = Counter(r[6].split("(")[0].split("@")[0] for r in rows)
    print("\nSUMMARY", dict(c), "total_rows=%d" % len(rows))

    # GH #799: the wall.  Only rows whose hero actually earned enough levels to
    # be ABLE to spend past slot 14 can say anything about a stuck head.
    wall = [r for r in rows if r[8] is not None and r[9] is not None
            and r[9] >= 16 and r[6].startswith(("MATCH", "DEVIATION"))]
    print("\nWALL rows(final_lvl>=16, in-domain)=%d" % len(wall))
    hc = Counter("%s @%d pts" % (r[11], r[4] + r[5]) for r in wall)
    print("WALL head_slot histogram", dict(hc))
    for r in sorted(wall, key=lambda r: (r[11], r[0])):
        print("  %-34s %-26s pts=%2d+%dT head=%-4s last_pt_lvl=%-3s "
              "final_lvl=%-3s stalled=%ss"
              % (r[0], r[1], r[4], r[5], r[11], r[8], r[9], r[10]))


def events_mode(paths, want):
    for p in paths:
        game = os.path.basename(p).replace(".timeline.json", "")
        tl = json.load(open(p))
        for hero, rec in sorted(measured_levelups(tl).items()):
            if want and want not in hero:
                continue
            print("\n== %s %s idx=%s final_lvl=%s end_t=%s"
                  % (game, hero, rec["idx"], rec["final_lvl"], rec["end_t"]))
            for i, (t, lv, kind, lab) in enumerate(rec["events"], 1):
                print("  #%-2d t=%-8s herolvl=%-3s %-6s %s" % (i, t, lv, kind, lab))


if __name__ == "__main__":
    argv = sys.argv[1:]
    if argv and argv[0] == "--events":
        events_mode([a for a in argv[2:]], argv[1])
    else:
        main(argv)
