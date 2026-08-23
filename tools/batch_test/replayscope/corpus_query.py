#!/usr/bin/env python3
"""Find, across MANY games, every frame where a rule SHOULD apply -- and pin the
denominator while doing it.

WHY THIS EXISTS (director backlog Section 1, owner-named; W34 ledger promoted it)
    Every stuck ruling in week 34 was stuck on README rule 2(a) -- "the replay
    group confirms the change really executes and behaves correctly in an actual
    game".  Not one was stuck on (b) or (c).  (a) is answered today by hand: a
    human picks ONE instant out of ONE replay and make_fixture.py freezes it.
    That answers "is this decision correct HERE".  It cannot answer the question
    a promotion actually turns on:

        on how many of the frames where this rule APPLIES does it fire?

    That question needs a POPULATION, and a population needs a denominator that
    somebody computed rather than asserted.  This tool computes both: it sweeps
    a corpus of timelines, evaluates a declarative predicate on every (hero,
    snapshot) frame, and reports matched-over-examined with every excluded frame
    accounted for by name.  `--fixtures` then hands the surviving frames to
    make_fixture.py in bulk, so "it fires on 11 of the 14 applicable frames" is
    a claim backed by 14 real-frame fixtures instead of one anecdote.

WHAT IT IS NOT
    Not a detector and not a verdict.  It selects frames by WORLD STATE only --
    it has no opinion about what the bot did there.  "The rule applies here" is
    this tool's output; "the rule fired here" is the fixture test's output.
    Keeping those two on opposite sides of the fixture boundary is the point:
    a selector that already knew the answer would be measuring itself.

THE THREE DISCIPLINES IT INHERITS
  1. Reuse, never re-derive (GH #67).  Timeline parsing, the hero-name
     canonicalization, the post-game frozen-tail cut (GH #43), the pause-span
     definition and the ANCIENT-DISTANCE depth convention are all imported from
     behavioral/detect.py.  The x+y depth heuristic once nearly reversed a
     conclusion; there is exactly one depth function in this repo and this file
     does not add a second.
  2. Fail loud, never default (source_constants.py's contract).  An unknown
     term, an unknown operator, a stray key, a wrong argument count -- all
     raise.  There is no `default=`.  A predicate that silently evaluated an
     unknown term as False would report a clean, plausible, wrong zero.
  3. No silent caps (Workflow rule, and the reason `--max-fixtures` prints what
     it dropped).  Every frame that does not reach the predicate is counted
     under a named exclusion, and the tool ASSERTS the accounting equation
        frames_total == pregame + paused + dead + examined
     before it prints anything.  A denominator that does not balance is a bug
     in this file, not a rounding detail, so it aborts.

VACUITY REPORTING (the part that catches a broken predicate)
    The summary prints, for every leaf clause, how many examined frames it was
    true on.  A leaf at 0/N selects nothing (typo'd item name, an ability the
    corpus never leveled, a threshold on the wrong side); a leaf at N/N is
    inert and is not narrowing anything.  Both shapes are invisible in a plain
    hit count -- the corpus_scale.lua rule ("a zero-assertion holds the
    equation") applied to predicates.

USAGE
    corpus_query.py <timeline.json>... --query q.json [--name tag]
                    [--dedup 15] [--min-t 0] [--team 2|3|both]
                    [--hero luna --hero lion] [--jsonl hits.jsonl]
                    [--fixtures OUTDIR --tag chase [--analysis-dir DIR]]
    corpus_query.py --list-terms

QUERY FORMAT (JSON; see --list-terms for the vocabulary)
    {"all": [
        {"term": "hp_pct", "lt": 0.35},
        {"term": "enemies_within", "args": [1200], "ge": 1},
        {"term": "depth", "gt": 0},
        {"not": {"term": "has_item", "args": ["item_black_king_bar"]}}
    ]}
    Combinators: {"all":[..]} {"any":[..]} {"not": node}
    Leaf: {"term": NAME, "args": [..], OP: VALUE, ...}
    Ops: lt le gt ge eq ne in nin.  Several ops on one leaf are ANDed
    (a range reads better as one leaf than as two).
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "behavioral"))
import detect  # noqa: E402  (path set above; the reuse in discipline 1)

FULL = "npc_dota_hero_"
INF = float("inf")


def bare(n):
    return n.replace(FULL, "") if n else n


class QueryError(Exception):
    """A malformed predicate. Raised, never swallowed -- see discipline 2."""


# --------------------------------------------------------------------------
# Terms.  Each takes (ctx, *args) and returns a scalar/bool/str.
# ctx carries the frame: timeline, hero, t, snapshot.
# --------------------------------------------------------------------------

class Frame(object):
    __slots__ = ("tl", "hero", "t", "s")

    def __init__(self, tl, hero, t, s):
        self.tl, self.hero, self.t, self.s = tl, hero, t, s


def _living_others(f, same_team):
    """Living heroes on (or off) the subject's team, excluding the subject."""
    my = f.tl.team(f.hero)
    out = []
    for h in f.tl.heroes:
        if h == f.hero:
            continue
        on = f.tl.team(h) == my
        if on != same_team:
            continue
        if not f.tl.alive_at(h, f.t):
            continue
        p = f.tl.pos(h, f.t)
        if p:
            out.append((h, p))
    return out


def _dists(f, same_team):
    me = (f.s["x"], f.s["y"])
    return [(h, math.hypot(p[0] - me[0], p[1] - me[1])) for h, p in _living_others(f, same_team)]


def _count_within(f, same_team, radius):
    return sum(1 for _, d in _dists(f, same_team) if d <= radius)


def _nearest(f, same_team):
    ds = [d for _, d in _dists(f, same_team)]
    return min(ds) if ds else INF


def _hero_damage_index(tl):
    """Per-timeline index of hero-sourced damage TO each hero, for bisect.

    Built once per timeline, not once per frame: the naive scan is
    O(frames x events), which on a real 600s game is ~10^8 comparisons for a
    single term.  Cached on the Timeline the same way detect.py caches its
    pause spans.
    """
    cache = getattr(tl, "_hero_dmg_index", None)
    if cache is not None:
        return cache
    per = {}
    for e in tl.events:
        if e.get("type") != "DAMAGE" or not e.get("actor_hero"):
            continue
        tgt = e.get("target")
        if not e.get("target_hero"):
            continue
        row = per.setdefault(tgt, ([], [0]))
        row[0].append(e["t"])
        row[1].append(row[1][-1] + e.get("value", 0))
    tl._hero_dmg_index = per
    return per


def _recent_damage(f, window):
    """Hero-sourced damage dealt TO the subject in [t-window, t].

    Hero-sourced only: creep and tower damage answer a different question and
    every consumer of this term so far has meant "was I being fought".
    """
    import bisect
    row = _hero_damage_index(f.tl).get(f.hero)
    if not row:
        return 0
    times, cum = row
    hi = bisect.bisect_right(times, f.t)
    lo = bisect.bisect_left(times, f.t - window)
    return cum[hi] - cum[lo]


def _ability(f, name):
    for a in f.s.get("abilities") or []:
        if a.get("name") == name:
            return a
    return None


TERMS = {
    # name: (arity, fn, one-line doc)
    "t":            (0, lambda f: f.t, "game-clock seconds of this frame"),
    "hero":         (0, lambda f: bare(f.hero), "subject's bare hero name"),
    "team":         (0, lambda f: f.tl.team(f.hero), "2=Radiant 3=Dire"),
    "hp":           (0, lambda f: f.s["hp"], "current HP"),
    "hp_pct":       (0, lambda f: f.s["hp_pct"], "current HP fraction 0..1"),
    "mp":           (0, lambda f: f.s.get("mp", 0), "current mana"),
    "mp_pct":       (0, lambda f: f.s.get("mp_pct", 0.0), "current mana fraction 0..1"),
    "level":        (0, lambda f: f.s["level"], "hero level"),
    "net_worth":    (0, lambda f: f.s.get("net_worth", 0), "gold value of hero + items"),
    "tp_cd":        (0, lambda f: f.s.get("tp_cd", 0.0), "TP cooldown remaining (0 = ready)"),
    "x":            (0, lambda f: f.s["x"], "world x"),
    "y":            (0, lambda f: f.s["y"], "world y"),
    # ANCIENT-DISTANCE convention, imported not re-derived: >0 = past the
    # midline toward the enemy, <0 = in our own half.  See detect._depth_anc.
    "depth":        (0, lambda f: detect._depth_anc(f.tl.team(f.hero), f.s["x"], f.s["y"]),
                     "dist(own base)-dist(enemy base); >0 = past midline toward them"),
    "enemies_within": (1, lambda f, r: _count_within(f, False, r), "count of LIVING enemy heroes within radius"),
    "allies_within":  (1, lambda f, r: _count_within(f, True, r), "count of LIVING allied heroes within radius (excl. self)"),
    "nearest_enemy_dist": (0, lambda f: _nearest(f, False), "distance to nearest living enemy hero (inf if none)"),
    "nearest_ally_dist":  (0, lambda f: _nearest(f, True), "distance to nearest living ally (inf if none)"),
    "has_item":     (1, lambda f, n: n in (f.s.get("items") or []), "true if the item is in the subject's inventory"),
    "ability_level": (1, lambda f, n: (_ability(f, n) or {}).get("level", 0), "leveled rank of the named ability (0 = absent/unleveled)"),
    "ability_ready": (1, lambda f, n: bool(_ability(f, n)) and (_ability(f, n) or {}).get("level", 0) > 0
                      and (_ability(f, n) or {}).get("cd", 0.0) <= 0.0,
                      "true if the named ability is leveled and off cooldown"),
    "recent_damage_taken": (1, _recent_damage, "hero-sourced damage taken in the last N seconds"),
}

OPS = {
    "lt": lambda a, b: a < b,
    "le": lambda a, b: a <= b,
    "gt": lambda a, b: a > b,
    "ge": lambda a, b: a >= b,
    "eq": lambda a, b: a == b,
    "ne": lambda a, b: a != b,
    "in": lambda a, b: a in b,
    "nin": lambda a, b: a not in b,
}


# --------------------------------------------------------------------------
# Predicate compilation.  Compiling up front (rather than walking the JSON per
# frame) is what makes an unknown term a startup error instead of a per-frame
# surprise on whichever game happens to reach it first.
# --------------------------------------------------------------------------

class Leaf(object):
    def __init__(self, term, args, checks, label):
        self.term, self.args, self.checks, self.label = term, args, checks, label
        self.true_count = 0
        self.reached = 0

    def __call__(self, f):
        self.reached += 1
        v = TERMS[self.term][1](f, *self.args)
        ok = True
        for op, want in self.checks:
            try:
                ok = bool(OPS[op](v, want))
            except TypeError as exc:
                raise QueryError("term %s produced %r, which cannot be compared with %s %r: %s"
                                 % (self.label, v, op, want, exc))
            if not ok:
                break
        if ok:
            self.true_count += 1
        return ok


def compile_node(node, leaves):
    if not isinstance(node, dict):
        raise QueryError("query nodes must be objects, got %r" % (node,))
    keys = set(node)
    combinators = keys & {"all", "any", "not"}
    if combinators:
        if len(keys) != 1:
            raise QueryError("a %s node takes no other keys, got %s"
                             % (sorted(combinators)[0], sorted(keys)))
        kind = keys.pop()
        if kind == "not":
            inner = compile_node(node["not"], leaves)
            return lambda f: not inner(f)
        subs = node[kind]
        if not isinstance(subs, list) or not subs:
            raise QueryError("%s takes a non-empty list of nodes" % kind)
        compiled = [compile_node(s, leaves) for s in subs]
        if kind == "all":
            # Evaluated in written order and short-circuiting, so a later
            # clause is only offered the frames its predecessors passed.  That
            # is why every leaf carries its OWN denominator (`reached`) and the
            # summary prints true/reached, not true/examined: a count against a
            # denominator it was never offered is the exact bug this tool
            # exists to stop other people shipping.
            return lambda f: all(c(f) for c in compiled)
        return lambda f: any(c(f) for c in compiled)

    if "term" not in node:
        raise QueryError("leaf node needs a \"term\" key, got %s" % sorted(keys))
    term = node["term"]
    if term not in TERMS:
        raise QueryError("unknown term %r (see --list-terms)" % term)
    arity, _, _ = TERMS[term]
    args = node.get("args", [])
    if not isinstance(args, list):
        raise QueryError("%s: \"args\" must be a list" % term)
    if len(args) != arity:
        raise QueryError("term %s takes %d argument(s), got %d" % (term, arity, len(args)))
    checks = []
    for k, v in node.items():
        if k in ("term", "args"):
            continue
        if k not in OPS:
            raise QueryError("unknown operator %r on term %s (ops: %s)"
                             % (k, term, " ".join(sorted(OPS))))
        checks.append((k, v))
    if not checks:
        # A bare term with no comparison is truthiness, which for a boolean
        # term is what everyone means.  For a numeric term it is a silent
        # "!= 0" and has bitten nobody yet only because nobody has written it.
        checks.append(("eq", True))
    checks.sort()
    label = "%s%s %s" % (term,
                         ("(" + ",".join(repr(a) for a in args) + ")") if args else "",
                         " ".join("%s %r" % (k, v) for k, v in checks))
    leaf = Leaf(term, args, checks, label)
    leaves.append(leaf)
    return leaf


# --------------------------------------------------------------------------
# The sweep
# --------------------------------------------------------------------------

class Accounting(object):
    """Every frame in the corpus lands in exactly one bucket, by design.

    Exclusions are tested in a fixed order and counted once, so the totals form
    an equation rather than four independent tallies that happen to look right.
    check() raises if it does not balance: an unbalanced denominator means the
    sweep skipped frames nobody named, and a population claim built on it would
    be wrong in the direction that flatters the claim.
    """

    def __init__(self):
        self.total = 0
        # Dropped by detect.Timeline BEFORE this file sees them: the dumper
        # keeps emitting frozen snapshots for ~25s after the game ends (GH #43).
        # It is counted here rather than left upstream because a denominator
        # that quietly starts 37% below the file's own snapshot count is the
        # same defect as an unnamed cap -- on the synthetic corpus this bucket
        # is 180 of 484 rows.
        self.postgame = 0
        self.out_of_window = 0   # outside [--min-t, --max-t]
        self.paused = 0
        self.dead = 0
        self.examined = 0
        self.matched = 0

    def check(self):
        parts = (self.postgame + self.out_of_window + self.paused
                 + self.dead + self.examined)
        if parts != self.total:
            raise AssertionError(
                "frame accounting does not balance: total=%d but "
                "postgame+out_of_window+paused+dead+examined=%d" % (self.total, parts))
        if self.matched > self.examined:
            raise AssertionError("matched=%d exceeds examined=%d" % (self.matched, self.examined))


def game_id(path):
    """Stable short id for a timeline file, for hit rows and fixture names.

    Prefers the run's own <HHMMSS>_slot<N> stamp when the filename carries one
    (that is what every fixture in tests/fixtures/ is named after); otherwise
    the sanitized stem, so a hand-made corpus still gets distinct ids.
    """
    stem = os.path.basename(path)
    for suf in (".timeline.json", ".json"):
        if stem.endswith(suf):
            stem = stem[: -len(suf)]
            break
    m = re.search(r"(\d{6})_(slot\d+)$", stem)
    if m:
        return "%s_%s" % (m.group(1), m.group(2))
    m = re.search(r"(\d{6})$", stem)
    if m:
        return m.group(1)
    return re.sub(r"[^A-Za-z0-9_]+", "_", stem)


def sweep_one(path, predicate, args, acct):
    with open(path) as fh:
        doc = json.load(fh)
    tl = detect.Timeline(doc)
    pauses = detect._paused_spans(tl)

    raw_counts = {}
    for s in doc.get("snapshots", []):
        raw_counts[s["hero"]] = raw_counts.get(s["hero"], 0) + 1

    def in_pause(t):
        return any(a <= t <= b for a, b in pauses)

    gid = game_id(path)
    hits = []
    # Union, not just tl.snaps: a hero whose every snapshot fell past the
    # post-game cut is absent from tl.snaps entirely, and skipping it here
    # would drop its rows out of the equation instead of into `postgame`.
    for hero in sorted(set(raw_counts) | set(tl.snaps)):
        if args.hero and bare(hero) not in args.hero:
            continue
        if args.team != "both" and tl.team(hero) != int(args.team):
            continue
        kept_snaps = tl.snaps.get(hero, [])
        cut = raw_counts.get(hero, 0) - len(kept_snaps)
        acct.total += cut
        acct.postgame += cut
        for s in kept_snaps:
            acct.total += 1
            t = s["t"]
            if t < args.min_t or (args.max_t is not None and t > args.max_t):
                acct.out_of_window += 1
                continue
            if in_pause(t):
                acct.paused += 1
                continue
            if s["hp"] <= 0:
                acct.dead += 1
                continue
            acct.examined += 1
            f = Frame(tl, hero, t, s)
            if predicate(f):
                acct.matched += 1
                hits.append({
                    "game": gid, "timeline": path, "hero": bare(hero), "t": round(t, 2),
                    "hp_pct": round(s["hp_pct"], 3), "level": s["level"],
                    "x": round(s["x"]), "y": round(s["y"]),
                    "depth": round(detect._depth_anc(tl.team(hero), s["x"], s["y"])),
                })
    return hits


def dedup(hits, window):
    """Collapse runs of near-identical frames: a 1Hz corpus reports a 20-second
    condition as twenty 'independent' frames, which would inflate every
    population claim by the sampling rate.  One hit per (game, hero) per window.
    """
    kept, last = [], {}
    for h in sorted(hits, key=lambda h: (h["game"], h["hero"], h["t"])):
        key = (h["game"], h["hero"])
        prev = last.get(key)
        if prev is None or h["t"] - prev >= window:
            kept.append(h)
            last[key] = h["t"]
    return kept


def make_fixtures(hits, args, log):
    out_dir = args.fixtures
    os.makedirs(out_dir, exist_ok=True)
    script = os.path.join(_HERE, "make_fixture.py")
    made, failed = [], []
    todo = hits
    if args.max_fixtures is not None and len(todo) > args.max_fixtures:
        # Named, printed, and carried into the summary -- a cap the reader
        # cannot see reads as "that was the whole population".
        log.append("CAP fixtures requested=%d generated=%d dropped=%d reason=--max-fixtures"
                   % (len(todo), args.max_fixtures, len(todo) - args.max_fixtures))
        todo = todo[: args.max_fixtures]
    for h in todo:
        name = "f_%s_%s_%s_t%d.lua" % (h["game"], h["hero"], args.tag, int(h["t"]))
        dest = os.path.join(out_dir, name)
        cmd = [sys.executable, script, h["timeline"], "--t", "%.2f" % h["t"],
               "--hero", h["hero"], "--window", str(args.window), "-o", dest]
        roles = analysis_for(h["timeline"], args.analysis_dir)
        if roles:
            cmd += ["--roles", roles]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode == 0:
            made.append(dest)
            h["fixture"] = dest
        else:
            failed.append((name, (proc.stderr or proc.stdout).strip().splitlines()[-1:] or [""]))
    return made, failed


def analysis_for(timeline_path, analysis_dir):
    """The analysis.json beside a timeline, if the caller pointed at one.

    Absent roles, replay_fixture.lua falls back to draft-slot order, which
    GH #57 measured at 47.3% accurate -- so any downstream test that reads
    jmz.GetPosition needs this, and the summary says when it was missing
    rather than letting a half-blind fixture pass for a whole one.
    """
    if not analysis_dir:
        return None
    stem = os.path.basename(timeline_path)
    for suf in (".timeline.json", ".json"):
        if stem.endswith(suf):
            stem = stem[: -len(suf)]
            break
    for cand in (stem + ".analysis.json", stem + ".json"):
        p = os.path.join(analysis_dir, cand)
        if os.path.exists(p):
            return p
    return None


def list_terms():
    print("terms (arity in brackets):")
    for name in sorted(TERMS):
        arity, _, doc = TERMS[name]
        print("  %-22s [%d]  %s" % (name, arity, doc))
    print("\noperators: %s" % " ".join(sorted(OPS)))
    print("combinators: all any not")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("timelines", nargs="*", help="dumper timeline JSON files (one per game)")
    ap.add_argument("--query", help="path to the predicate JSON, or the JSON itself")
    ap.add_argument("--name", default="query", help="label for the summary lines")
    ap.add_argument("--dedup", type=float, default=15.0,
                    help="collapse hits for the same hero within this many seconds (0 = keep all)")
    ap.add_argument("--min-t", type=float, default=0.0, help="ignore frames before this game-clock second")
    ap.add_argument("--max-t", type=float, default=None, help="ignore frames after this game-clock second")
    ap.add_argument("--team", default="both", choices=("2", "3", "both"), help="restrict the subject's team")
    ap.add_argument("--hero", action="append", default=[], help="restrict to this bare hero name (repeatable)")
    ap.add_argument("--jsonl", help="write every kept hit as one JSON object per line")
    ap.add_argument("--fixtures", help="generate a real-frame fixture per kept hit into this directory")
    ap.add_argument("--tag", help="short name used in generated fixture filenames (required with --fixtures)")
    ap.add_argument("--window", type=float, default=5.0, help="make_fixture.py ground-truth window")
    ap.add_argument("--analysis-dir", help="directory of matching analysis.json files, for fixture roles (GH #57)")
    ap.add_argument("--max-fixtures", type=int, default=None,
                    help="stop after N fixtures; the drop is printed, never silent")
    ap.add_argument("--list-terms", action="store_true", help="print the term vocabulary and exit")
    args = ap.parse_args()

    if args.list_terms:
        list_terms()
        return 0
    if not args.timelines or not args.query:
        ap.error("need at least one timeline and --query (or --list-terms)")
    if args.fixtures and not args.tag:
        ap.error("--fixtures needs --tag (fixture filenames must say what they are)")

    raw = args.query
    if os.path.exists(raw):
        with open(raw) as fh:
            raw = fh.read()
    try:
        spec = json.loads(raw)
    except ValueError as exc:
        raise SystemExit("--query is neither a readable file nor valid JSON: %s" % exc)

    leaves = []
    try:
        predicate = compile_node(spec, leaves)
    except QueryError as exc:
        raise SystemExit("query error: %s" % exc)

    acct = Accounting()
    log = []
    all_hits = []
    games_with_hits = set()
    missing_tl = []
    for path in args.timelines:
        if not os.path.exists(path):
            missing_tl.append(path)
            continue
        try:
            hits = sweep_one(path, predicate, args, acct)
        except QueryError as exc:
            raise SystemExit("query error on %s: %s" % (path, exc))
        if hits:
            games_with_hits.add(game_id(path))
        all_hits += hits

    if missing_tl:
        # Loud, and it changes the denominator the reader is about to quote.
        raise SystemExit("missing timeline file(s), refusing to report a population "
                         "over a corpus that is not all there: %s" % " ".join(missing_tl))

    acct.check()
    kept = dedup(all_hits, args.dedup) if args.dedup > 0 else list(all_hits)

    print("CORPUS name=%s timelines=%d frames_total=%d postgame=%d out_of_window=%d "
          "paused=%d dead=%d examined=%d"
          % (args.name, len(args.timelines), acct.total, acct.postgame, acct.out_of_window,
             acct.paused, acct.dead, acct.examined))
    print("POPULATION matched=%d deduped=%d dedup_window=%.1fs games_with_hits=%d/%d"
          % (acct.matched, len(kept), args.dedup, len(games_with_hits), len(args.timelines)))
    for leaf in leaves:
        # true/reached, plus a named verdict for the two vacuous shapes: a
        # clause nothing satisfies selects an empty population, and a clause
        # everything satisfies narrows nothing.  Both look fine in a hit count.
        note = ""
        if leaf.reached and leaf.true_count == 0:
            note = "  VACUOUS(selects nothing)"
        elif leaf.reached and leaf.true_count == leaf.reached:
            note = "  INERT(narrows nothing)"
        elif not leaf.reached:
            note = "  UNREACHED(an earlier clause never let a frame through)"
        print("CLAUSE true=%d/%d reached  %s%s"
              % (leaf.true_count, leaf.reached, leaf.label, note))
    by_hero = {}
    for h in kept:
        by_hero[h["hero"]] = by_hero.get(h["hero"], 0) + 1
    for hero in sorted(by_hero, key=lambda k: (-by_hero[k], k)):
        print("HERO %s %d" % (hero, by_hero[hero]))

    if args.jsonl:
        with open(args.jsonl, "w") as fh:
            for h in kept:
                fh.write(json.dumps(h, sort_keys=True) + "\n")
        print("WROTE %s (%d hits)" % (args.jsonl, len(kept)))

    if args.fixtures:
        made, failed = make_fixtures(kept, args, log)
        for line in log:
            print(line)
        print("FIXTURES made=%d failed=%d dir=%s roles=%s"
              % (len(made), len(failed), args.fixtures,
                 "yes" if args.analysis_dir else "NONE(draft-slot fallback, GH #57)"))
        for name, why in failed:
            print("FIXTURE_FAIL %s %s" % (name, why[0] if why else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
