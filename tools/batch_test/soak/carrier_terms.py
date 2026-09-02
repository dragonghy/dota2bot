#!/usr/bin/env python3
"""Derive the carrier-gate's hero terms MECHANICALLY from a wave's arm string.

Why this exists (director, 2026-08-28, GH #276): `seed_draft.py --assert-carrier`
is a good gate that was being asked the wrong question.  Its terms were HAND
WRITTEN -- the focus five -- so on W20 it spent 2 of its 5 terms on `axe` and
`skeleton_king` (the 41-id arm string contained no axe-scoped or SK-scoped id at
all) and never asked about `spirit_breaker`, the sole carrier of that wave's ONLY
newly-admitted id, `aimguard`.  W20 drafted zero spirit_breaker in 180/180 stamped
games; the gate returned exit 0; the wave ran; nothing raised a hand.  W21 (launched
2026-08-28T12:16Z, seeds 983/986/995/1138) repeated it byte for byte -- zero
spirit_breaker again -- which is what makes this a defect and not bad luck:
`--rates` puts P(spirit_breaker absent from a 4-seed wave) at 0.518.

The load-bearing requirement, and the reason a naive implementation is worse than
none: **derivation must follow the CONSUMPTION point, not the file the gate is
written in.**  Five of the six hero-scoped ids in the W20 arm string have their
`J.IsSoakCandidate(...)` sitting inside `bots/BotLib/hero_*.lua`, so one grep finds
them.  `aimguard` -- the one that actually broke -- does not: its gate is in
`bots/FunLib/jmz_func.lua` (`J.CanBeAttackedPair`) and only
`bots/BotLib/hero_spirit_breaker.lua` ever calls that function.  An implementation
that classified ids by the gate site's own filename would score 5/6 on this tree
and miss precisely the id that paid for this file.  `tests/test_carrier_terms.py`
pins that case first.

What a classification means:

  hero        every path from the gate to a mode/entry point passes through
              `hero_<name>.lua` files only => only those heroes can execute it.
              Emits one carrier term per hero.
  generic     some consumer is reachable from a generic mode/ability script that
              every hero runs => no term (any draft carries it).
  unresolved  the walk hit the depth cap or a gate literal this file cannot find.
              NOT a synonym for generic: an unchecked gate is not a passed gate,
              so the CLI exits 2 on it (same stance as `--assert-carrier`'s own
              "nothing was checked" branch).

Gate literals are found two ways: the direct `J.IsSoakCandidate('<id>')`, and the
`lf_<sub>` wrapper family, whose id literal is *built by concatenation*
(`J.IsLaneFixOn(sub)` => `'lf_' .. sub`) and therefore cannot be grepped as a
string.  Any other wrapper that synthesises an id will land in `unresolved` rather
than being silently called generic -- that is the intended failure direction.

Usage:
  carrier_terms.py --arm "id1,id2,..."          # print derivation + summary
  carrier_terms.py --arm-file iterations/streams/test_set.md --arm-line 2
  (as a library) derive_terms(ids, repo_root) -> (terms, rows, summary)
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

# Depth of the consumption walk.  Bounded so a cycle or an unexpected shape ends
# in `unresolved` (loud) instead of running forever or defaulting to generic.
MAX_DEPTH = 6

# Summon files under bots/FunLib/minion_lib/ whose owning hero is stated BY THE
# FILE -- the unit names or the ability the summon comes from -- and not by the
# filename or by anyone's Dota knowledge (GH #402).  A wrong owner here is worse
# than no entry: it would hand the carrier gate a confident, checkable-looking
# answer about a hero who cannot run the code, which is the same class of defect
# as the all-heroes expansion it replaces.  Files absent from this map resolve
# `unresolved` (exit 2, loud), never `generic`.
#
#   primal_split.lua    npc_dota_brewmaster_earth/fire/storm/void   -> brewmaster
#   familiars.lua       visage_summon_familiars                     -> visage
#   vengeful_spirit.lua vengefulspirit_nether_swap                  -> vengefulspirit
#
# Summon files that are GENERIC BY CONSTRUCTION: every hero in any draft can
# field one, so no draft can fail to carry a gate living here and `generic` --
# the class the carrier gate exempts -- is the correct answer, not a hero term.
#   illusions.lua   any hero has illusions (Manta and friends grant them to
#                   whoever buys the item, on top of the heroes whose own
#                   abilities make them).  `illumove` and `illureal` sit here,
#                   and calling them `unresolved` would have been this fix
#                   trading a wrong optimistic answer for a wrong loud one:
#                   two correctly-generic ids would have started refusing
#                   launches with exit 2.  Loud is only better when it is also
#                   true.
MINION_GENERIC = {"illusions.lua"}

# Deliberately UNMAPPED, with the reason, so the next reader does not "finish"
# the table from memory:
#   jugg.lua            X.HealingWardThink -- Healing Ward is Juggernaut's and
#                       nobody else's, but the file names no unit and no
#                       ability, so the evidence is the FILENAME. That is the
#                       exact reading `rubick_hero` exists to warn about. It
#                       needs one grep of the ward's unit name, not a guess.
#   attacking_wards.lua generic by construction (serpent wards, plague wards,
#   illusions.lua       illusions, skilled minions): several owners or any
#   minion_with_skill.lua hero at all -- a single-hero entry would be false.
#   utils.lua           shared helpers, no owner.
MINION_OWNER = {
    "primal_split.lua": "brewmaster",
    "familiars.lua": "visage",
    "vengeful_spirit.lua": "vengefulspirit",
}

GATE_RE_TMPL = r"IsSoakCandidate\s*\(\s*['\"]%s['\"]"
LANEFIX_RE_TMPL = r"IsLaneFixOn\s*\(\s*['\"]%s['\"]"
# Top-level definitions in this codebase all start at column 0, in two shapes.
FUNCDEF_RE = re.compile(r"^(?:local\s+)?function\s+([A-Za-z_][\w.:]*)\s*\(")
# `X.ConsiderItemDesire["item_tpscroll"] = function( hItem )` -- a dispatch-table
# entry.  Missing this shape is not a small omission: the upward scan then walks
# straight past it to whatever named function happens to sit above, and reports a
# body that ends 60 lines earlier as the enclosing one.  That mis-attribution is
# what put 9 of 43 live ids (`midtp`, `teambrain`, `stayfield`, `tpreach`,
# `wandbleed`, ...) in `unresolved` on the first run of this file -- each one
# "resolving" to `X.IsBaseTowerDestroyed` and then dying on the cycle check.
ANONDEF_RE = re.compile(r"^[^\s=]+.*=\s*function\s*\(")


def strip_line_comment(line):
    """Drop a Lua `--` line comment, respecting single/double quoted strings.

    A naive `line.split('--')` turns every prose mention of a helper into a call
    site; this file's call-site scan would then invent carriers out of comments
    (`hero_spirit_breaker.lua:293` mentions `J.CanBeAttackedPair` one line above
    the real call).  Long-bracket comments (`--[[ ]]`) are not handled; there are
    none inside the scanned bodies and a stray one degrades toward *more* text
    being scanned, i.e. toward `generic`, never toward a fabricated hero term.
    """
    out = []
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                out.append(c)
                i += 1
                if i < len(line):
                    out.append(line[i])
                    i += 1
                continue
            if c == quote:
                quote = None
            out.append(c)
            i += 1
            continue
        if c in "'\"":
            quote = c
            out.append(c)
            i += 1
            continue
        if c == "-" and i + 1 < len(line) and line[i + 1] == "-":
            break
        out.append(c)
        i += 1
    return "".join(out)


def lua_files(repo_root=REPO_ROOT):
    """Every .lua file under bots/, repo-relative, sorted."""
    base = os.path.join(repo_root, "bots")
    found = []
    for root, _dirs, files in os.walk(base):
        for name in files:
            if name.endswith(".lua"):
                path = os.path.join(root, name)
                found.append(os.path.relpath(path, repo_root))
    return sorted(found)


class Tree(object):
    """Comment-stripped line index of bots/, built once per run."""

    @classmethod
    def from_lines(cls, lines, repo_root=REPO_ROOT):
        """Build over an in-memory {rel: [line]} map (tests; no disk read)."""
        tree = cls.__new__(cls)
        tree.repo_root = repo_root
        tree.lines = {rel: [strip_line_comment(ln) for ln in body]
                      for rel, body in lines.items()}
        return tree

    def __init__(self, repo_root=REPO_ROOT):
        self.repo_root = repo_root
        self.lines = {}
        for rel in lua_files(repo_root):
            with open(os.path.join(repo_root, rel), encoding="utf-8", errors="replace") as fh:
                self.lines[rel] = [strip_line_comment(ln) for ln in fh.read().splitlines()]

    def hero_of(self, rel):
        """`bots/BotLib/hero_axe.lua` -> `axe`; anything else -> None.

        `bots/FunLib/rubick_hero/<x>.lua` is Rubick's handler for a STOLEN <x>
        ability, so its carrier is `rubick`, not `<x>`.  Reading the filename the
        obvious way would name a hero that cannot execute the code.

        `bots/FunLib/minion_lib/<x>.lua` is the same shape and is why this
        function grew a second special case (GH #402, director 2026-09-01):
        every one of those files is `require`d by the generic dispatcher
        `bots/FunLib/aba_minion.lua`, so the reachability walk below answered
        "every hero in the game" for a summon only one hero can field.
        `immguard` derived **128 carriers**, `seed_draft.py` evaluated them as
        one disjunction, and the gate that exists to refuse a wave whose draft
        cannot carry an armed id read `verdict=FULL satisfied=4/4` -- frozen
        TRUE, on the id whose true carrier (`brewmaster`) is not even in
        `hero_pool.txt`.  The correct reading was `UNDRAFTABLE`, verbatim as
        its sibling `tormself`/ringmaster got in the same run.
        """
        base = os.path.basename(rel)
        parent = os.path.dirname(rel)
        if parent.endswith("rubick_hero"):
            return "rubick"
        if parent.endswith("minion_lib"):
            # Mapped ONLY where the file itself names the owner's units or
            # ability -- not from the filename, and not from what a reader
            # happens to know about Dota.  Everything else is deliberately
            # absent so it resolves `unresolved` (loud, exit 2) instead of
            # inheriting the all-heroes answer this fix exists to delete.
            return MINION_OWNER.get(base)
        if parent.endswith("BotLib") and base.startswith("hero_") and base.endswith(".lua"):
            return base[len("hero_"):-len(".lua")]
        return None

    def find(self, pattern):
        """[(rel, lineno_1based)] for every comment-stripped line matching."""
        rx = re.compile(pattern)
        hits = []
        for rel, lines in self.lines.items():
            for idx, line in enumerate(lines):
                if rx.search(line):
                    hits.append((rel, idx + 1))
        return sorted(hits)

    def enclosing_function(self, rel, lineno):
        """-> (name, def_line, kind) for the column-0 definition containing `lineno`.

        `kind` is 'named' (callable by name, so the walk can continue upward),
        'anon' (a dispatch-table entry -- invoked through the table, so its name
        is not greppable and the walk stops), or None at file scope.
        """
        for idx in range(lineno - 1, -1, -1):
            line = self.lines[rel][idx]
            m = FUNCDEF_RE.match(line)
            if m:
                return m.group(1), idx + 1, "named"
            if ANONDEF_RE.match(line):
                return line.split("=")[0].strip(), idx + 1, "anon"
        return None, None, None

    def callers(self, fname, def_rel, def_line):
        """Call sites of `fname` (matched on its short name), minus its own def."""
        short = re.split(r"[.:]", fname)[-1]
        rx = re.compile(r"(?<![\w])%s\s*\(" % re.escape(short))
        hits = []
        for rel, lines in self.lines.items():
            for idx, line in enumerate(lines):
                if not rx.search(line):
                    continue
                if rel == def_rel and idx + 1 == def_line:
                    continue
                if FUNCDEF_RE.match(line):
                    continue  # another definition of the same short name
                hits.append((rel, idx + 1))
        return sorted(hits)


def _resolve_site(tree, rel, lineno, depth, seen, trail):
    """Classify one code location: ('hero', {names}) / ('generic', ...) / ('unresolved', ...)."""
    hero = tree.hero_of(rel)
    if hero:
        return "hero", {hero}, trail + ["%s:%d" % (rel, lineno)]
    if os.path.basename(rel) in MINION_GENERIC:
        return "generic", set(), trail + ["%s:%d(minion, generic by construction)"
                                          % (rel, lineno)]
    if os.path.dirname(rel).endswith("minion_lib"):
        # An unmapped summon file (GH #402).  Walking on from here reaches the
        # generic dispatcher `aba_minion.lua` and answers "every hero", which
        # is the failure this fix removes -- and it fails toward OPTIMISM, so
        # nothing raises a hand.  `unresolved` is the honest answer: exit 2,
        # could-not-run, which the launch path already refuses to treat as a
        # pass.  Adding an entry to MINION_OWNER is how this gets resolved,
        # and it must be earned by evidence in the file.
        return "unresolved", set(), trail + [
            "%s:%d(minion_lib owner not in MINION_OWNER)" % (rel, lineno)]
    if depth >= MAX_DEPTH:
        return "unresolved", set(), trail + ["%s:%d(depth cap)" % (rel, lineno)]

    fname, def_line, defkind = tree.enclosing_function(rel, lineno)
    if not fname:
        # Top-level chunk of a generic script: every hero runs it.
        return "generic", set(), trail + ["%s:%d(file scope)" % (rel, lineno)]
    if defkind == "anon":
        # A dispatch-table entry in a generic script: the engine reaches it for
        # every hero, so there is nothing hero-scoped left upstream.
        return "generic", set(), trail + ["%s:%s(dispatch entry)" % (rel, fname)]

    key = (rel, fname)
    if key in seen:
        return "unresolved", set(), trail + ["%s:%s(cycle)" % (rel, fname)]
    seen = seen | {key}

    sites = tree.callers(fname, rel, def_line)
    if not sites:
        # Nothing calls it => engine entry point (Think/Consider/...) in a generic
        # script, i.e. every hero.
        return "generic", set(), trail + ["%s:%s(entry point)" % (rel, fname)]

    heroes = set()
    step = trail + ["%s:%d->%s" % (rel, lineno, fname)]
    worst_unresolved = None
    for crel, cline in sites:
        kind, hs, sub = _resolve_site(tree, crel, cline, depth + 1, seen, step)
        if kind == "generic":
            return "generic", set(), sub
        if kind == "unresolved":
            worst_unresolved = sub
            continue
        heroes |= hs
    if not heroes:
        return "unresolved", set(), worst_unresolved or step
    return "hero", heroes, step


def gate_sites(tree, cand_id):
    """Locations that read this candidate id, including the `lf_` wrapper family."""
    sites = tree.find(GATE_RE_TMPL % re.escape(cand_id))
    if cand_id.startswith("lf_"):
        sites += tree.find(LANEFIX_RE_TMPL % re.escape(cand_id[len("lf_"):]))
    return sorted(set(sites))


def derive_id(tree, cand_id):
    """-> dict(id, kind, heroes, sites, why)."""
    sites = gate_sites(tree, cand_id)
    if not sites:
        return {"id": cand_id, "kind": "unresolved", "heroes": set(), "sites": [],
                "why": "no gate literal found in bots/"}

    heroes = set()
    kind = "hero"
    why = []
    for rel, lineno in sites:
        k, hs, trail = _resolve_site(tree, rel, lineno, 0, frozenset(), [])
        why.append("%s => %s%s" % ("%s:%d" % (rel, lineno), k,
                                   (" " + ",".join(sorted(hs))) if hs else ""))
        if k == "generic":
            kind = "generic"
            heroes = set()
            break
        if k == "unresolved":
            kind = "unresolved"
            continue
        heroes |= hs
    if kind == "hero" and not heroes:
        kind = "unresolved"
    return {"id": cand_id, "kind": kind, "heroes": heroes, "sites": sites,
            "why": "; ".join(why)}


def derive_terms(ids, repo_root=REPO_ROOT, tree=None):
    """-> (terms, rows, summary).

    `terms` is the deduplicated, sorted hero list to hand to
    `seed_draft.assert_carrier`; `rows` is one derivation dict per id; `summary`
    counts the three kinds so a reader can tell "derived 5" from "typed 5".
    """
    tree = tree or Tree(repo_root)
    rows = [derive_id(tree, i) for i in ids]
    terms = sorted({h for r in rows if r["kind"] == "hero" for h in r["heroes"]})
    summary = {
        "ids": len(rows),
        "hero_scoped": sum(1 for r in rows if r["kind"] == "hero"),
        "generic": sum(1 for r in rows if r["kind"] == "generic"),
        "unresolved": sum(1 for r in rows if r["kind"] == "unresolved"),
        "terms": len(terms),
    }
    return terms, rows, summary


def print_derivation(rows, summary, out=sys.stdout):
    for row in rows:
        print("CARRIER_DERIVE id=%s kind=%s heroes=%s via=%s"
              % (row["id"], row["kind"],
                 ",".join(sorted(row["heroes"])) or "-", row["why"] or "-"), file=out)
    # GH #276 rec 3: a bare `terms=5` cannot tell "derived 5" from "hand-typed 5".
    print("CARRIER_TERMS derived from %d armed ids: %d hero-scoped, %d generic, "
          "%d unresolved => %d term(s)"
          % (summary["ids"], summary["hero_scoped"], summary["generic"],
             summary["unresolved"], summary["terms"]), file=out)


# The soak drafter fills five positions with two heroes each (radiant + dire).
DRAFT_SLOTS = 10
PER_POSITION = 2


def draft_can_miss(carriers, pool):
    """Can SOME legal soak draft contain none of `carriers`?  None = cannot say.

    This is the mirror of `UNDRAFTABLE` and the other half of GH #402.  A term no
    draft can HIT is already refused loudly; a term no draft can MISS was passing
    silently, and that is the more dangerous direction -- `immguard`'s 128-hero
    disjunction read `verdict=FULL satisfied=4/4` for an id whose real carrier
    (`brewmaster`) is not in `hero_pool.txt` at all.  A gate row that cannot fail
    is not evidence that the wave carries the id; it is a row nobody checked.

    Why a structural test and not a `len(heroes) > N` threshold, which is what the
    issue proposed: **width is not the property that matters, position coverage
    is.**  The 12-odd heroes eligible for position 2 are, together, unmissable --
    every draft fills mid twice out of exactly that set -- so a 12-hero term can be
    frozen TRUE while a 20-hero term spread across five positions is perfectly
    informative.  Any threshold that catches the first would refuse the second.
    Asking the drafter's own question instead needs no constant at all.

    The question is Hall's condition on the complement: a carrier-free draft
    exists iff, for every subset S of positions, the non-carriers eligible for
    some position in S number at least `PER_POSITION * |S|`.  S = {1..5} subsumes
    the trivial `fewer than 10 heroes left` case.

    LIMIT -- the drafter's dead-end fallback.  `draft()` picks from the unused
    heroes eligible for the position, and only if that list is EMPTY does it fall
    back to any unused hero at all.  The reasoning above assumes the fallback does
    not fire; it cannot on a pool where every position has more eligible heroes
    than the draft has slots (currently {1:13, 2:12, 3:12, 4:15, 5:14} against 10
    slots).  Rather than assume it, this returns None -- "cannot say", exit 2 --
    the moment a position gets that thin, because a firing fallback lets a draft
    reach a hero the position-respecting model says it cannot.
    """
    try:
        rows = [(name, list(positions)) for name, positions in pool]
    except (TypeError, ValueError):
        return None                      # a bare name list carries no positions
    by_pos = {p: [n for n, ps in rows if p in ps] for p in range(1, 6)}
    if any(len(by_pos[p]) <= DRAFT_SLOTS for p in range(1, 6)):
        return None                      # fallback reachable; model not exact
    free = [ps for name, ps in rows if name not in carriers]
    for mask in range(1, 1 << 5):
        subset = [p for p in range(1, 6) if mask >> (p - 1) & 1]
        avail = sum(1 for ps in free if any(p in ps for p in subset))
        if avail < PER_POSITION * len(subset):
            return False
    return True


def assert_carrier_ids(seeds, rows, pool, out=sys.stdout):
    """Per-id carrier gate.  0 ok / 1 an id has no carrier / 2 nothing checked.

    The term of a hero-scoped id is a DISJUNCTION over its carrier heroes, not one
    term per hero: `abilanc`-shaped ids reach a dozen `hero_*.lua` consumers, and
    any ONE of them drafted makes the id executable.  Flattening those into
    independent `--assert-carrier` terms would demand all twelve in a 4-seed wave
    (40 hero slots) and refuse every launch forever -- a gate that always says no
    is as useless as one that always says yes, and costs more to discover.

    Both ends of that sentence are now enforced.  A term no draft can carry is
    `UNDRAFTABLE` (exit 1); a term no draft can miss is `OVER-BROAD` (exit 2,
    "nothing checked" -- see `draft_can_miss`).  An OVER-BROAD row is a claim
    about the DERIVATION, not about the wave: either the id really is generic and
    was mis-classified hero-scoped, or the consumption walk over-expanded the way
    it did through `minion_lib`.  Both are fixed in this file, never by re-rolling
    seeds.
    """
    from seed_draft import position_map  # local: keeps this importable standalone

    scoped = [r for r in rows if r["kind"] == "hero"]
    if not seeds or not scoped:
        print("CARRIER_GATE ids=%d seeds=%d exit=2 (nothing checked)"
              % (len(scoped), len(seeds)), file=out)
        return 2

    names = set(pool_names(pool))
    worst = 0
    for row in sorted(scoped, key=lambda r: r["id"]):
        heroes = sorted(row["heroes"])
        label = "|".join(heroes)
        draftable = [h for h in heroes if h in names]
        if not draftable:
            # No seed can ever carry it; the remedy is un-arming the id or adding
            # the hero to hero_pool.txt, never another seed search.
            print("CARRIER id=%s term=%s verdict=UNDRAFTABLE (no carrier is in "
                  "hero_pool.txt) carriers=none" % (row["id"], label), file=out)
            worst = max(worst, 1)
            continue
        missable = draft_can_miss(set(draftable), pool)
        if missable is not True:
            verdict = "OVER-BROAD" if missable is False else "UNCHECKED"
            why = ("no legal draft can miss it" if missable is False
                   else "pool shape outside draft_can_miss's model")
            print("CARRIER id=%s term=%s verdict=%s (%s; %d of %d pool heroes "
                  "carry it) carriers=every-draft"
                  % (row["id"], label, verdict, why, len(draftable), len(names)),
                  file=out)
            worst = max(worst, 2)
            continue
        satisfied = []
        for seed in seeds:
            pmap = position_map(seed, pool)
            drafted = sorted({h for (_team, h) in pmap.keys() if h in draftable})
            if drafted:
                satisfied.append(seed)
            print("CARRIER seed=%d id=%s term=%s present=%s"
                  % (seed, row["id"], label, ",".join(drafted) or "no"), file=out)
        if not satisfied:
            verdict = "ABSENT"
            worst = max(worst, 1)
        elif len(satisfied) == len(seeds):
            verdict = "FULL"
        else:
            verdict = "PARTIAL"
        print("CARRIER id=%s term=%s seeds=%d satisfied=%d verdict=%s carriers=%s"
              % (row["id"], label, len(seeds), len(satisfied), verdict,
                 ",".join(str(s) for s in satisfied) or "none"), file=out)

    print("CARRIER_GATE ids=%d seeds=%d exit=%d" % (len(scoped), len(seeds), worst), file=out)
    return worst


def pool_names(pool):
    """Accept either seed_draft's pool rows or a plain list of hero names."""
    out = []
    for entry in pool:
        out.append(entry[0] if isinstance(entry, (list, tuple)) else entry)
    return out


def parse_arm(spec):
    return [i.strip() for i in re.split(r"[,\s]+", spec.strip()) if i.strip()]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--arm", help="comma-separated armed candidate ids")
    ap.add_argument("--arm-file", help="file to read the arm string from")
    ap.add_argument("--arm-line", type=int, default=2,
                    help="1-based line of --arm-file holding the arm string (default 2)")
    ap.add_argument("--repo-root", default=REPO_ROOT)
    ap.add_argument("--quiet", action="store_true", help="print only the term list")
    args = ap.parse_args()

    if args.arm_file:
        with open(args.arm_file, encoding="utf-8") as fh:
            spec = fh.read().splitlines()[args.arm_line - 1]
    elif args.arm:
        spec = args.arm
    else:
        ap.error("need --arm or --arm-file")

    ids = parse_arm(spec)
    if not ids:
        print("CARRIER_TERMS exit=2 (empty arm string)", file=sys.stderr)
        return 2

    terms, rows, summary = derive_terms(ids, args.repo_root)
    if not args.quiet:
        print_derivation(rows, summary)
    print("TERMS %s" % (",".join(terms) or "none"))
    if summary["unresolved"]:
        # An unresolved id is a gate whose domain nobody checked.
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
