#!/usr/bin/env python3
"""The set of bots/*.lua files the Dota bot VM can actually reach, as a FILE.

WHY THIS IS A FILE AND NOT A SNIPPET IN A REPORT (strategy charter 0NEXT29,
2026-09-16T10:23Z).  The closure was rebuilt from scratch three rounds running
by three independent throwaway implementations, and the readings disagreed:
226 / 226 / 227 out of 275.  Nobody could say which file the difference was,
because not one of the three name lists was ever written down.  A census set
that is rebuilt every round is itself a reading with no ratchet, so this module
lands the set and tests/test_bots_reach_closure.py pins its size and its
edge kinds.

THE THREE EDGE KINDS, and why leaving any of them out yields a plausible wrong
answer rather than an obvious failure:

  * ``require( GetScriptDirectory()..'/X' )`` -- the ordinary edge.
  * ``dofile( ... )`` -- ``bot_generic.lua:6`` loads the per-hero BotLib file
    this way, and ``aba_ability_usage.lua`` reaches ``FunLib/aba_minion`` only
    through a dofile.  A require-only walk reads 190, i.e. 36 files short,
    and every one of those 36 is a file the engine really does execute.
  * ``pcall(require, ...)`` -- ``hero_selection.lua:41`` reaches
    ``FunLib/aba_matchups`` only this way.

The reverse assertion in the test deliberately anchors on ``aba_minion`` and
``aba_matchups`` rather than on ``jmz_func``: jmz_func is required by nearly
every file, so its presence in the result is satisfied by ANY of the three
walks and therefore carries almost no information.  A missing edge shows up
only at the leaves.

LIMITS -- quoting a number out of this module means quoting these too:
  * The walk is SYNTACTIC.  A path built at run time from a variable is not
    followed; the only dynamic form handled is bot_generic's per-hero dofile,
    which is expanded to every ``BotLib/hero_*.lua`` because the engine picks
    the one matching the drafted hero.
  * "Reachable" says the loader can get there.  It does not say any function
    in the file has a live call site -- that is the inverse-gate census'
    question, not this one.
  * Files under bots/Customize/ are gitignored farm gate files; the walk
    reports them only if they exist in the working tree.
"""

from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BOTS_DIR = os.path.join(REPO_ROOT, "bots")

# The engine loads these by fixed path and name (AGENTS.md: "Layout is
# load-bearing").  bot_generic is the per-hero entry, hero_selection the
# draft entry, and every mode_/ability_/item_ script is polled directly.
ROOT_GLOBS = (
    "hero_selection.lua",
    "bot_generic.lua",
    "ability_item_usage_generic.lua",
    "item_purchase_generic.lua",
    "team_desires.lua",
    "mode_*.lua",
    "ability_item_usage_*.lua",
    "item_purchase_*.lua",
)

# require( GetScriptDirectory()..'/FunLib/x' ) and pcall(require, ...<same>)
# share this tail; dofile( GetScriptDirectory() .. "/BotLib/" .. ... ) does not
# end in a literal, so it is handled separately below.
_LITERAL_PATH = re.compile(r"""GetScriptDirectory\(\s*\)\s*\.\.\s*['"]/([A-Za-z0-9_/\-]+)['"]""")
_DOFILE_HERO = re.compile(r"""dofile\s*\(\s*GetScriptDirectory\(\s*\)\s*\.\.\s*['"]/BotLib/['"]""")


def _root_files() -> list[str]:
    import glob

    out: list[str] = []
    for pattern in ROOT_GLOBS:
        for path in sorted(glob.glob(os.path.join(BOTS_DIR, pattern))):
            rel = os.path.relpath(path, REPO_ROOT)
            if rel not in out:
                out.append(rel)
    return out


def _hero_files() -> list[str]:
    import glob

    return sorted(
        os.path.relpath(p, REPO_ROOT)
        for p in glob.glob(os.path.join(BOTS_DIR, "BotLib", "hero_*.lua"))
    )


def edges_from(rel_path: str) -> set[str]:
    """Every bots/*.lua file `rel_path` can load, by the three edge kinds."""
    full = os.path.join(REPO_ROOT, rel_path)
    try:
        with open(full, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError:
        return set()

    out: set[str] = set()
    for stem in _LITERAL_PATH.findall(text):
        candidate = os.path.join("bots", stem + ".lua")
        if os.path.isfile(os.path.join(REPO_ROOT, candidate)):
            out.add(candidate)
    # bot_generic.lua:6 -- the per-hero BotLib dofile, whose tail is built from
    # the drafted hero's name.  The engine resolves exactly one of these per
    # bot; the closure has to contain all of them.
    if _DOFILE_HERO.search(text):
        out.update(_hero_files())
    return out


def closure() -> list[str]:
    """Breadth-first closure over the engine's entry points."""
    seen: set[str] = set()
    queue = list(_root_files())
    while queue:
        current = queue.pop()
        if current in seen:
            continue
        seen.add(current)
        for nxt in edges_from(current):
            if nxt not in seen:
                queue.append(nxt)
    return sorted(seen)


def all_bots_files() -> list[str]:
    out: list[str] = []
    for dirpath, _dirnames, filenames in os.walk(BOTS_DIR):
        for name in sorted(filenames):
            if name.endswith(".lua"):
                out.append(os.path.relpath(os.path.join(dirpath, name), REPO_ROOT))
    return sorted(out)


def main(argv: list[str]) -> int:
    reached = closure()
    every = all_bots_files()
    if "--unreached" in argv:
        for rel in every:
            if rel not in reached:
                print(rel)
        return 0
    if "--count" in argv:
        print("REACH %d/%d" % (len(reached), len(every)))
        return 0
    for rel in reached:
        print(rel)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
