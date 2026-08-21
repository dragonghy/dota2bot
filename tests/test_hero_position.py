#!/usr/bin/env python3
"""A hero's POSITION comes from the soak seed; its PICK SLOT does not (GH #57).

Plain python, no pytest (matches tests/test_detect_overchase.py).

Background.  `custom_loader.ApplySoakDraft` drafts per position, and
`hero_selection.lua` seeds slot i with the position-i hero -- but
`X.ShufflePickOrder` (hero_selection.lua:312) then permutes the slots with the
ENGINE's unseeded RandomInt, swapping sSelectList[i] together with
Role.RoleAssignment[team][i] and tLaneAssignList[i].  The (hero, role, lane)
triple travels as a unit, so the hero keeps the role it was drafted for while its
slot moves.  Two detectors used to read the role off `analysis.json:team_slot`;
on 291 real mirror games that label agreed with the drafted one on 47.3% of rows.

The observation anchor is real wave data, not a synthetic construction:
tests/fixtures/seed_position_spread_20260820.json holds, for each of the 40
(seed, team, hero) pairs of wave spot_20260820_0411xx, the drafted position and
the distribution of slot-derived positions actually observed across 291 games.

Usage:  python3 tests/test_hero_position.py
"""
import io
import json
import os
import re
import sys
import tokenize

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "batch_test", "soak"))
import seed_draft  # noqa: E402

FIXTURE = os.path.join(ROOT, "tests", "fixtures", "seed_position_spread_20260820.json")

failures = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        failures.append(msg)
        print("  FAIL %s" % msg)


def aj_for(seed, pool, slot_of=None):
    """A synthetic analysis.json for `seed`; slot_of(team, hero) fixes team_slot."""
    pmap = seed_draft.position_map(seed, pool)
    players = []
    for (team, hero), pos in sorted(pmap.items()):
        slot = slot_of(team, hero) if slot_of else (pos - 1)
        players.append({"team": team, "hero": "npc_dota_hero_" + hero,
                        "team_slot": slot + (0 if team == "radiant" else 5)})
    return {"script_version": "mirror:cand:s%d:radiant" % seed, "players": players}


# `team_slot` and the `% 5 + 1` are matched separately on purpose: they are
# usually split by a subscript (`p["team_slot"] % 5 + 1`), and a regex demanding
# them adjacent misses every real call site.
_SLOT_POS = re.compile(r"%\s*5\s*\+\s*1")


def _blank_noncode(src):
    """`src` as a list of lines with string-literal and comment text blanked out.

    Every character belonging to a string literal (docstrings included) or to a
    comment is replaced by a space, so a formula QUOTED in prose stops reading as
    a call site while live code sharing a line with a trailing comment still
    does.  Blanking by column span rather than dropping whole lines is what buys
    that second half: `p["team_slot"] % 5 + 1  # old` must stay a hit.

    f-strings are the one deliberate exception.  On Python < 3.12 the whole
    f-string arrives as a single STRING token, replacement fields included, so
    blanking it would hide `f"{p['team_slot'] % 5 + 1}"` -- live code inside a
    string token.  Those are left intact: prose that quotes the formula from
    inside an f-string would false-RED, but a false RED is visible and cheap
    whereas a false GREEN is the exact defect this ratchet exists to catch.

    A file that will not tokenize raises, per this repo's fail-loud convention:
    swallowing it would turn one broken file into one silent exemption.
    """
    lines = [list(ln) for ln in src.splitlines()]
    for tok in tokenize.generate_tokens(io.StringIO(src).readline):
        if tok.type == tokenize.COMMENT:
            blank = True
        elif tok.type == tokenize.STRING:
            # tok.string starts with the prefix, e.g. rb'..' / f".." / '''..'''
            prefix = tok.string[:tok.string.index(tok.string.lstrip("bBfFrRuU")[0])]
            blank = "f" not in prefix.lower()
        elif tok.type == getattr(tokenize, "FSTRING_MIDDLE", None):
            blank = True                      # 3.12+: literal halves arrive alone
        else:
            continue
        if not blank:
            continue
        (r0, c0), (r1, c1) = tok.start, tok.end
        for r in range(r0, r1 + 1):
            row = lines[r - 1]
            lo = c0 if r == r0 else 0
            hi = c1 if r == r1 else len(row)
            for c in range(lo, min(hi, len(row))):
                row[c] = " "
    return ["".join(ln) for ln in lines]


def slot_pos_hits(src):
    """1-based line numbers where `src` derives a position from team_slot.

    Only the ARITHMETIC is required to be live code.  The `team_slot` marker is
    matched against the raw line on purpose: at a real call site it is a string
    subscript (`p["team_slot"] % 5 + 1`), so demanding it outside string literals
    too would blank the very token that identifies the call site -- the first cut
    of this fix did exactly that and read the canonical form as clean.
    """
    blanked = _blank_noncode(src)
    return [i for i, raw in enumerate(src.splitlines(), 1)
            if "team_slot" in raw and _SLOT_POS.search(blanked[i - 1])]


def main():
    pool = seed_draft.load_pool()

    # 1. the stamp parser answers in both directions, and refuses rather than guesses
    print("\n[1] seed_from_stamp")
    check(seed_draft.seed_from_stamp("mirror:l1trade,tpdead:s872:radiant") == 872,
          "reads the seed out of a mirror stamp")
    check(seed_draft.seed_from_stamp("7c8b516") is None,
          "a warm-up stamp (bare tree SHA) has no seed -> None, not a default")
    check(seed_draft.seed_from_stamp(None) is None, "None input -> None")

    # 2. positions_for_game is bijective per team and matches the printed draft
    print("\n[2] positions_for_game on a well-formed game")
    pos = seed_draft.positions_for_game(aj_for(872, pool), pool)
    check(pos is not None and len(pos) == 10, "resolves all 10 rows")
    rad = seed_draft.draft(872, pool)[0]
    check(all(pos["npc_dota_hero_" + rad[p]] == p for p in range(1, 6)),
          "radiant heroes carry the positions seed_draft prints for them")
    for team in ("radiant", "dire"):
        got = sorted(v for k, v in pos.items()
                     if k.replace("npc_dota_hero_", "") in
                     [h for (t, h) in seed_draft.position_map(872, pool) if t == team])
        check(got == [1, 2, 3, 4, 5], "%s covers each position exactly once" % team)

    # 3. THE REGRESSION: the answer must not move when the pick slots are shuffled.
    #    Reverting to `team_slot % 5 + 1` flips every hero here.
    print("\n[3] the answer is invariant to the pick-slot shuffle")
    rot = {}
    for (team, hero), p in seed_draft.position_map(872, pool).items():
        rot[(team, hero)] = p % 5          # rotate every hero one slot along
    shuffled = aj_for(872, pool, slot_of=lambda t, h: rot[(t, h)])
    pos2 = seed_draft.positions_for_game(shuffled, pool)
    check(pos2 == pos, "same positions after rotating every team_slot by one")
    slot_derived = {p["hero"]: p["team_slot"] % 5 + 1 for p in shuffled["players"]}
    check(slot_derived != pos2,
          "and it genuinely disagrees with the slot-derived label on this input")

    # 4. refuse, never guess
    print("\n[4] unattributable games come back as None")
    warm = aj_for(872, pool)
    warm["script_version"] = "7c8b516"
    check(seed_draft.positions_for_game(warm, pool) is None, "no seed in stamp -> None")
    wrong = aj_for(872, pool)
    wrong["players"][0]["hero"] = "npc_dota_hero_pudge"
    check(seed_draft.positions_for_game(wrong, pool) is None,
          "a hero outside the seed's draft -> None (not a partial map)")
    short = aj_for(872, pool)
    short["players"] = short["players"][:9]
    check(seed_draft.positions_for_game(short, pool) is None, "a 9-row game -> None")

    # 5. observation anchor: 291 real games say the slot is NOT the role
    print("\n[5] real wave data (291 mirror games, 40 (seed,hero) pairs)")
    fx = json.load(open(FIXTURE))
    pairs = fx["pairs"]
    check(len(pairs) == 40, "fixture carries all 40 pairs")
    spans = sum(1 for p in pairs if len(p["slot_pos_counts"]) > 1)
    check(spans == 40,
          "40/40 pairs were observed in >1 slot-derived position -- the slot moves")
    modal = sum(1 for p in pairs
                if max(p["slot_pos_counts"], key=lambda k: p["slot_pos_counts"][k])
                == str(p["drafted_pos"]))
    check(modal >= 36,
          "but the drafted position is the MODE for %d/40 pairs -- the slot is a "
          "noisy proxy for it, not an independent fact" % modal)
    tot = sum(sum(p["slot_pos_counts"].values()) for p in pairs)
    diag = sum(p["slot_pos_counts"].get(str(p["drafted_pos"]), 0) for p in pairs)
    check(0.40 < diag / tot < 0.60,
          "slot label agrees with the drafted one on %.1f%% of rows -- a detector "
          "keyed on it is wrong about half the time" % (100.0 * diag / tot))
    check(seed_draft.position_map(pairs[0]["seed"], pool)[(pairs[0]["team"],
          pairs[0]["hero"])] == pairs[0]["drafted_pos"],
          "the fixture's drafted positions still reproduce from the seed today")

    # 6. source-level ratchet: nothing derives a position from the slot again.
    #    Sections 1-5 prove the helper is right; only this catches a consumer
    #    quietly going back to the old one-liner.  NO file is exempt -- section 7
    #    proves the prose stripping works, which is what an exemption used to buy;
    #    an exemption by filename costs the whole file's LIVE code as well, and it
    #    is whack-a-mole besides (GH #99: every new file that warns readers off
    #    the old formula by quoting it had to be named again).
    print("\n[6] no consumer recomputes position from team_slot")
    bad = []
    for base, _dirs, files in sorted(os.walk(os.path.join(ROOT, "tools"))):
        for fn in sorted(files):
            if not fn.endswith(".py"):
                continue
            path = os.path.join(base, fn)
            with open(path) as fh:
                src = fh.read()
            bad += ["%s:%d" % (os.path.relpath(path, ROOT), i)
                    for i in slot_pos_hits(src)]
    check(not bad, "no live `team_slot %% 5 + 1` under tools/ (found: %s)" % (bad or "none"))

    # 7. the stripping section 6 leans on is REACHABLE and does not over-strip.
    #    Without this, section 6 passing would be indistinguishable from section 6
    #    matching nothing at all -- the same empty-assertion trap
    #    test_detector_source_constants.py builds its synthetic file to avoid.
    print("\n[7] the prose stripper is reachable, and blanks prose only")
    probe = '\n'.join([
        '"""Docstring: #37 used `team_slot % 5 + 1`, do not."""',           # 1
        'x = 1  # comment: team_slot % 5 + 1 is wrong',                     # 2
        's = "a quoted team_slot % 5 + 1 inside a str"',                    # 3
        'live_a = p["team_slot"] % 5 + 1',                                  # 4
        'live_b = p["team_slot"] % 5 + 1  # trailing comment',              # 5
        'live_c = f"pos={p[\'team_slot\'] % 5 + 1}"',                       # 6
        'd = """team_slot % 5 + 1',                                         # 7
        'still inside the same triple-quoted string % 5 + 1 team_slot"""',  # 8
    ])
    hits = slot_pos_hits(probe)
    check(hits == [4, 5, 6],
          "reports exactly the three live lines, not the five prose ones "
          "(got %s)" % hits)
    check(slot_pos_hits('# team_slot % 5 + 1\n') == [],
          "a whole-line comment alone is not a hit")
    check(slot_pos_hits('y = p["team_slot"] % 5 + 1\n') == [1],
          "and a bare live line alone still is")
    try:
        slot_pos_hits('def f(:\n')
        tokenized_junk = True
    except Exception:
        tokenized_junk = False
    check(not tokenized_junk,
          "a file that will not tokenize raises rather than becoming a silent exemption")

    print("\n%s (%d failures)" % ("PASS" if not failures else "FAIL", len(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
