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


def measured_levelups(tl):
    """-> {hero: (idx, [ability names in level-up order], n_bodies)}"""
    first_idx = {}
    bodies = {}
    for s in tl["snapshots"]:
        bodies.setdefault(s["hero"], set()).add(s["idx"])
        if s["hero"] not in first_idx:
            # snapshots are time-ordered; the first one is the pre-horn body
            first_idx[s["hero"]] = s["idx"]
    lvl = {}
    seq = {}
    for s in tl["snapshots"]:
        h = s["hero"]
        if s["idx"] != first_idx[h]:
            continue
        abils = s.get("abilities") or []
        if h not in lvl:
            # baseline = the pre-horn frame.  Innates (fowl_play, prickly, ...)
            # are already level 1 there and must NOT count as a skill point.
            lvl[h] = {a["name"]: a["level"] for a in abils}
            continue
        cur = lvl[h]
        step = []
        for a in abils:
            if a["name"] not in cur:
                # granted after the horn (scepter/shard: shadow_shaman_urnaconda)
                cur[a["name"]] = a["level"]
                continue
            if a["level"] > cur[a["name"]]:
                step.extend([a["name"]] * (a["level"] - cur[a["name"]]))
                cur[a["name"]] = a["level"]
        if step:
            # abilities that rise in the SAME frame are one skill point spent on
            # one linked ability (nevermore_shadowraze1/2/3).
            seq.setdefault(h, []).append("+".join(sorted(set(step))))
    return {h: (first_idx[h], seq.get(h, []), len(bodies[h])) for h in first_idx}


def main(paths):
    rows = []
    for p in paths:
        game = os.path.basename(p).replace(".timeline.json", "")
        tl = json.load(open(p))
        for hero, (idx, seq, nbodies) in sorted(measured_levelups(tl).items()):
            meta = parse_hero_lua(hero)
            talents = [x for x in seq if x.startswith("special_bonus")]
            abil = [x for x in seq if not x.startswith("special_bonus")]
            if meta is None:
                rows.append((game, hero, idx, nbodies, len(abil), len(talents),
                             "NO_BOTLIB_FILE", ""))
                continue
            builds, default_ab = meta
            if default_ab is not False:
                rows.append((game, hero, idx, nbodies, len(abil), len(talents),
                             "OUT_OF_DOMAIN(bDeafaultAbility=%s)" % default_ab, ""))
                continue
            if not builds:
                rows.append((game, hero, idx, nbodies, len(abil), len(talents),
                             "OUT_OF_DOMAIN(no build parsed)", ""))
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
                         ",".join(str(x) for x in cm)))
    hdr = ("game", "hero", "idx", "bodies", "n_abil_pts", "n_talents", "verdict", "canon_measured")
    print("\t".join(hdr))
    for r in rows:
        print("\t".join(str(x) for x in r))
    # summary
    from collections import Counter
    c = Counter(r[6].split("(")[0].split("@")[0] for r in rows)
    print("\nSUMMARY", dict(c), "total_rows=%d" % len(rows))


if __name__ == "__main__":
    main(sys.argv[1:])
