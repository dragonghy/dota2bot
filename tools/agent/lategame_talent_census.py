#!/usr/bin/env python3
"""[hero] Late-game talent visibility: how many trained talents does a frozen
frame SHOW, against how many the shipped level-up routine must have spent?

WHY.  GH #260 (hero, 2026-08-27) read the whole 105-fixture corpus and found 67
talent sightings, every one a GENERIC row, and zero `special_bonus_unique_*` on
any hero at any level.  It left two explanations standing as equals and refused
to choose:

    H1 INSTRUMENT  dumper/main.go isRealAbility() drops any class name holding
                   `Special_Bonus_Base` / `_Attributes` BEFORE the line that
                   keeps upgraded talents -- and hero-unique talents have no
                   dedicated engine class, so they are all Special_Bonus_Base.
    H2 WORLD       the bots never train unique talents.

The consequences differ by an order of magnitude (under H2 the five TALENTPRICE
rounds priced rows nobody takes), and the queue request filed to separate them
(`hero-21`) buys a re-dump.

This tool separates them WITHOUT the re-dump, by using levels the 10-minute cap
used to hide.  The shipped level-up path is a QUEUE, not a level-indexed map:
X.GetSkillList (FunLib/aba_skill.lua) parks the four talent picks at queue
positions 10, 15, 18 and 19 of a 15-entry ability build, and
ability_item_usage_generic.lua pops the head only when
`botLevel >= GetHeroLevelRequiredToUpgrade()`, banking the point otherwise.  The
binding constraint is therefore the tier level itself, so a bot at hero level L
has trained min(4, (L-10)//5 + 1) talents.  Count those against what the frame
shows.  H2 cannot explain a hero showing FEWER rows than tiers it passed: under
a perfect instrument every trained talent is a row, whichever row it is.

The headline is reported twice.  The FULL reading takes all four tiers; the
CONSERVATIVE one counts only t10 and t15 -- the two tiers reached long before
any queue stall could still be pending -- so that the verdict survives even a
reader who disbelieves the queue model above.

SCOPE.  Fixture-shaped Lua under tests/fixtures/ plus iterations/pending/ (the
first post-cap frame, GH #235, is still parked there behind GH #236 -- reading a
parked file costs nothing and landing it is not this desk's call).

EXIT  0 report written / 2 refused to report (floor not met).  The conclusions
here are all of the form "a count is short", which is the shape a broken parse
satisfies for free, so the floors are not decoration.
"""

import os
import re
import sys

ROOTS = ['tests/fixtures', 'iterations/pending']

# Floors.  Below any of these the census is not evidence about anything.
MIN_FILES = 50
MIN_SLOTS = 500
MIN_SIGHTINGS = 20
MIN_LATE_SLOTS = 10          # level >= 20; the whole point of the run

TALENT_TIERS = (10, 15, 20, 25)

HERO_RE = re.compile(r"\{ name = '(npc_dota_hero_[a-z0-9_]+)'")
LEVEL_RE = re.compile(r"\blevel = (\d+)")
ABIL_ROW_RE = re.compile(r"name = '([a-z0-9_]+)', level = (\d+)")


def guaranteed_talents(level, tiers=TALENT_TIERS):
    """Talent points the shipped level-up routine has spent by hero level."""
    return sum(1 for t in tiers if level >= t)


def balanced_block(text, start):
    """The `{...}` block beginning at `start`, brace-balanced."""
    depth = 0
    for i in range(start, len(text)):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return text[start:]


def parse_units(text):
    """[(hero, level, [talent names], n_non_talent_ability_rows)] for one file."""
    out = []
    for m in HERO_RE.finditer(text):
        block = balanced_block(text, m.start())
        lvl = LEVEL_RE.search(block)
        if not lvl:
            continue
        abil_at = block.find('abilities =')
        talents, abilities = [], 0
        if abil_at >= 0:
            for name, alvl in ABIL_ROW_RE.findall(balanced_block(
                    block, block.index('{', abil_at))):
                if name.startswith('special_bonus'):
                    talents.append(name)
                elif int(alvl) > 0:
                    abilities += 1
        out.append((m.group(1), int(lvl.group(1)), talents, abilities))
    return out


def lua_files():
    files = []
    for root in ROOTS:
        for dirpath, _dirnames, filenames in os.walk(root):
            for fn in sorted(filenames):
                if fn.endswith('.lua') and (fn.startswith('f_') or root == 'tests/fixtures'):
                    files.append(os.path.join(dirpath, fn))
    return sorted(files)


def is_unique(name):
    return name.startswith('special_bonus_unique_')


def main():
    files, slots = [], []
    for path in lua_files():
        try:
            with open(path, 'r', encoding='utf-8') as fh:
                text = fh.read()
        except OSError:
            continue
        units = parse_units(text)
        if not units:
            continue
        files.append(path)
        for hero, level, talents, abilities in units:
            slots.append((path, hero, level, talents, abilities))

    sightings = sum(len(s[3]) for s in slots)
    late = [s for s in slots if s[2] >= 20]

    print('=' * 74)
    print('LATE-GAME TALENT VISIBILITY CENSUS  (dev-only, zero cost)')
    print('=' * 74)
    print('files parsed  : %d' % len(files))
    print('hero-slots    : %d' % len(slots))
    print('talent rows   : %d  (unique rows: %d)'
          % (sightings, sum(1 for s in slots for t in s[3] if is_unique(t))))
    print('slots >= 20   : %d' % len(late))

    problems = []
    if len(files) < MIN_FILES:
        problems.append('files %d < %d' % (len(files), MIN_FILES))
    if len(slots) < MIN_SLOTS:
        problems.append('hero-slots %d < %d' % (len(slots), MIN_SLOTS))
    if sightings < MIN_SIGHTINGS:
        problems.append('talent rows %d < %d' % (sightings, MIN_SIGHTINGS))
    if len(late) < MIN_LATE_SLOTS:
        problems.append('slots at level >= 20: %d < %d' % (len(late), MIN_LATE_SLOTS))
    if problems:
        print()
        print('REFUSING TO REPORT -- ' + '; '.join(problems))
        print('Every headline below would have been "a count is short", which is')
        print('exactly what an empty parse produces for free.  Fix the scan (or')
        print('say why the corpus lost its late-game frames) before quoting this.')
        return 2

    print()
    print('-- THE LATE-GAME SLOTS, one row per hero-slot --')
    print('%-18s %5s %5s %5s  %s' % ('hero', 'lvl', 'must', 'seen', 'rows'))
    must_total, seen_total = 0, 0
    for _path, hero, level, talents, _abilities in sorted(late, key=lambda s: s[1]):
        must = guaranteed_talents(level)
        must_total += must
        seen_total += len(talents)
        print('%-18s %5d %5d %5d  %s'
              % (hero[len('npc_dota_hero_'):], level, must, len(talents),
                 ', '.join(t[len('special_bonus_'):] for t in talents) or '-'))

    floor_total = sum(guaranteed_talents(s[2], (10, 15)) for s in late)

    print()
    print('-- THE ARITHMETIC --')
    print('talent points the shipped routine spent : %d' % must_total)
    print('talent rows the frames actually show    : %d' % seen_total)
    print('trained-but-invisible                   : %d  (%.1f%%)'
          % (must_total - seen_total,
             100.0 * (must_total - seen_total) / must_total if must_total else 0.0))
    print('  conservative (t10 + t15 only)         : %d of %d invisible'
          % (floor_total - seen_total, floor_total))
    print('unique rows among the visible ones      : %d'
          % sum(1 for s in late for t in s[3] if is_unique(t)))
    print('max rows on any one late-game slot      : %d'
          % max(len(s[3]) for s in late))
    print()
    print('H2 (the bots never train unique talents) predicts a hero at level L')
    print('carries exactly min(4,(L-10)//5+1) rows, whichever rows they are.  A')
    print('deficit is a property of the instrument, not of the world.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
