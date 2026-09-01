#!/usr/bin/env python3
"""Which heroes does our frame corpus actually contain?  (dev-only, read-only,
zero AWS; reads tests/fixtures/ and tests/frames/ only.)

WHY THIS EXISTS
---------------
Three consecutive strategy rounds landed a gated fix whose subject hero has
ZERO appearances in the entire frame corpus:

    GH #385  tormself    -- subject: (torment) sub-units
    GH #393  immguard    -- subject: brewmaster (primal split)   corpus 0
    GH #397  hpbool      -- subject: tiny                        corpus 0
             (and #397 registered five more instances on shredder / kez /
              dawnbreaker -- corpus 0, 0, 0)

Iron rule 2 says a fix leaves the test set only after the replay group confirms
condition (a): "the change really executes and behaves correctly in a real
game".  A hero who never appears cannot buy (a) at the fixture level, so those
rounds were pre-destined to come back DOMAIN-EMPTY.  The director's §DF.6 asked
for the shape to be NAMED before it produced its third and fourth null.  #397
was the third, and measured it once, inline, inside one test file's [source S6].

This file is that reading promoted to a standing tool: seconds, local, exact,
runnable BEFORE choosing the round's lever instead of after landing it.

WHAT IT ANSWERS, AND WHAT IT DOES NOT
-------------------------------------
It answers exactly one question: **is the subject of a proposed fix present in
the corpus at all?**  That is a NECESSARY condition for a fixture-level
acceptance, never a sufficient one -- the decision domain also has to be
reachable on some archived frame, and this census cannot see domains.  So:

    corpus count 0  =>  a fixture-level acceptance is IMPOSSIBLE.  Load-bearing.
    corpus count >0 =>  an acceptance is merely NOT RULED OUT.  Weak.

The asymmetry is the whole point.  The cheap half of the reading is the half
that can say "don't bother", and that is the half three rounds did not run.

THE STRUCTURAL ESCAPE HATCH (this is the actionable half)
---------------------------------------------------------
A lever in SHARED code -- bots/mode_*.lua, bots/FunLib/*, the generic
overrides -- has every hero in the corpus as its domain, so it never pays this
price at all.  A lever in bots/BotLib/hero_<x>.lua pays it in full.  `--file`
makes that distinction the tool's answer rather than the reader's inference.

KNOWN LIMITS (do not launder these away)
----------------------------------------
* Presence is counted by scanning for `npc_dota_hero_<x>` tokens in the fixture
  text.  A fixture that names a hero only in a comment would count; none does
  today, but the read is textual, not semantic.
* The corpus is what we happened to archive, not a sample of the hero pool.  A
  zero here is a fact about our archive, not about Dota.
* `WeakHeroes` (bots/hero_selection.lua) throttles some heroes out of the draft.
  A hero on that list is fighting the draw as well as the archive -- reported,
  because it changes how expensive a future appearance would be, but it is a
  separate fact from the corpus count.
"""

import argparse
import os
import re
import sys
from collections import defaultdict

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CORPUS_DIRS = (os.path.join(REPO, "tests", "fixtures"),
               os.path.join(REPO, "tests", "frames"))
SELECTION = os.path.join(REPO, "bots", "hero_selection.lua")

HERO_RE = re.compile(r"npc_dota_hero_([a-z_0-9]+)")
GAME_RE = re.compile(r"game\s*=\s*'([^']+)'")
# A hero file's subject is its filename; shared code has no single subject.
HERO_FILE_RE = re.compile(r"BotLib[/\\]hero_([a-z_0-9]+)\.lua$")


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def collect():
    """-> (files_seen, {hero: file_count}, {hero: set(game)})"""
    counts = defaultdict(int)
    games = defaultdict(set)
    seen = 0
    for root in CORPUS_DIRS:
        if not os.path.isdir(root):
            continue
        for dirpath, _dirnames, filenames in os.walk(root):
            for fn in sorted(filenames):
                if not fn.endswith(".lua"):
                    continue
                src = read(os.path.join(dirpath, fn))
                seen += 1
                gm = GAME_RE.search(src)
                game = gm.group(1) if gm else os.path.join(dirpath, fn)
                for hero in set(HERO_RE.findall(src)):
                    counts[hero] += 1
                    games[hero].add(game)
    return seen, counts, games


def weak_heroes():
    """Names on the WeakHeroes throttle list, or None if it cannot be read."""
    if not os.path.isfile(SELECTION):
        return None
    src = read(SELECTION)
    m = re.search(r"WeakHeroes\s*=\s*\{(.*?)\}", src, re.S)
    if not m:
        return None
    return set(HERO_RE.findall(m.group(1)))


def subject_of(path):
    """The hero a path is about, or None when the path is shared code."""
    m = HERO_FILE_RE.search(path.replace("\\", "/"))
    return m.group(1) if m else None


def verdict(hero, counts, games, weak):
    n = counts.get(hero, 0)
    if n == 0:
        tag = "DOMAIN-EMPTY"
        note = ("a fixture-level acceptance of condition (a) is IMPOSSIBLE for "
                "this subject -- pick another lever, or expect the ruling to "
                "come back DOMAIN-EMPTY")
    else:
        tag = "PRESENT"
        note = ("presence is NECESSARY, not sufficient: the decision domain "
                "still has to be reachable on one of these frames")
    if weak is not None and hero in weak:
        note += ("; and it is on the WeakHeroes throttle list, so it is "
                 "fighting the draw as well as the archive")
    return tag, n, len(games.get(hero, ())), note


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--hero", action="append", default=[],
                    help="hero short name (e.g. tiny); repeatable")
    ap.add_argument("--file", action="append", default=[],
                    help="a repo path; hero files answer for their subject, "
                         "shared code answers SHARED (no domain price)")
    ap.add_argument("--top", type=int, default=0,
                    help="print only the N most-present heroes (0 = all)")
    args = ap.parse_args(argv)

    seen, counts, games = collect()
    if seen == 0:
        print("CORPUS UNREADABLE: no .lua frames under %s"
              % " or ".join(CORPUS_DIRS), file=sys.stderr)
        print("exit 2 -- could-not-run, which is NOT an answer", file=sys.stderr)
        return 2
    weak = weak_heroes()

    print("=" * 74)
    print("CORPUS HERO CENSUS  (dev-only, read-only, zero cost)")
    print("=" * 74)
    print("frame files read : %d" % seen)
    print("distinct heroes  : %d" % len(counts))
    if weak is None:
        print("WeakHeroes list  : UNREADABLE (hero_selection.lua changed shape?)")
    else:
        print("WeakHeroes list  : %d name(s)" % len(weak))

    queried = list(args.hero)
    shared, filed = [], []
    for path in args.file:
        sub = subject_of(path)
        (filed if sub else shared).append((path, sub))
        if sub:
            queried.append(sub)

    if shared:
        print()
        print("-- SHARED CODE: no domain price --")
        for path, _ in shared:
            print("  %-52s SHARED   every hero in the corpus is its domain"
                  % path)

    if queried:
        print()
        print("-- QUERIED SUBJECTS --")
        worst = 0
        for hero in queried:
            tag, n, ng, note = verdict(hero, counts, games, weak)
            print("  %-22s %-12s files=%-4d games=%-4d" % (hero, tag, n, ng))
            print("      %s" % note)
            if tag == "DOMAIN-EMPTY":
                worst = 3
        print()
        print("exit %d -- %s" % (worst, "0 means every queried subject is present"
                                if worst == 0 else
                                "3 means at least one subject has corpus 0"))
        return worst

    print()
    print("-- PRESENCE, most-present first (files / distinct games) --")
    rows = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    if args.top:
        rows = rows[:args.top]
    for hero, n in rows:
        mark = "  <- WeakHeroes" if weak and hero in weak else ""
        print("  %5d  %4d  %s%s" % (n, len(games[hero]), hero, mark))
    print()
    print("a hero NOT listed above has corpus 0: a fixture-level acceptance of")
    print("condition (a) is impossible for it until the archive grows.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
