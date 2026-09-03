#!/usr/bin/env python3
"""Which boolean chains in `bots/` lost a member?  (dev-only, read-only, zero
AWS; reads `bots/**.lua` only.)

WHY THIS EXISTS
---------------
The single most productive real-world defect is a copy-pasted conjunct whose
one token was never changed.  It leaves the chain the SAME LENGTH as the author
intended -- the reader counts the right number of `and`s and moves on -- while
one member of the intended set is silently absent.  Two shapes carry it, and
this tool runs BOTH because they are the same defect seen from two sides:

  A. DUP-OPERAND.  Two operands of one top-level `and`/`or` chain are the same
     text.  Either the duplicate is idempotent (harmless), or the second copy
     was supposed to name a different member and the chain lost that member.

  B. PARITY-BREAK.  A local is fetched, nil-guarded, and never actually read.
     In this codebase a nil-guard almost always travels WITH its substantive
     read -- `nX ~= nil and #nX >= 3`.  When one guard in a chain has no such
     companion while its siblings in the SAME chain do, the companion is what
     went missing.

⭐ WHY B IS NOT ALREADY COVERED BY `write_only_local_census.py`.  That census
asks "is this local ever read".  A self nil-guard IS a read, so it answers YES
and stays silent -- the guard EATS the read that would have exposed the local.
`bots/BotLib/hero_dark_seer.lua:415` is exactly that: `nEnemyTowers` is
fetched, guarded at :419, and its count is never consulted, and the write-only
census reports 18 findings without it.  Read every future zero from that
census with this hole in mind: it cannot see a local whose only read is its
own guard.

⭐ THE TWO DETECTORS CROSS-CONFIRM.  They were written independently and they
name the same line at `hero_dark_seer.lua:417`: the duplicated operand
(`#nInRangeEnemy == 0`, twice) IS the parity break (`nEnemyTowers` guarded but
never counted).  Neither detector was told about the other's answer.

WHAT IT ANSWERS, AND WHAT IT DOES NOT
-------------------------------------
It answers a SYNTACTIC question and nothing else.  A duplicate operand is a
fact about the text; whether the duplicate is a harmless idempotent repeat or
a dropped member is a JUDGEMENT, and every finding carries one in `JUDGED`.
It does not answer whether a repair can ever be validated: that is the domain
price, and only `corpus_hero_census.py` plus the fixture archive answer it.
Run the cheap falsifier BEFORE choosing a lever (GH #400 / #422 / #426 / #431).

KNOWN LIMITS (do not launder these away)
----------------------------------------
* Operands are compared as NORMALIZED TEXT (whitespace removed), not
  semantically.  `#a>=#b` and `#b<=#a` are two operands to this tool.
  Under-reports; never over-reports.
* Detector B collects a local's occurrences over the WHOLE FILE, not over its
  lexical scope.  A same-named local in another function therefore DISQUALIFIES
  the candidate rather than admitting it -- again the under-reporting
  direction, deliberately.
* A re-assignment (`X = ...` after the `local`) counts as a non-guard
  occurrence, so a local that is guarded and then overwritten is not reported.
* Conditions are joined textually from `if`/`elseif`/`while` up to the first
  `then`/`do`, at most 30 lines.  A condition containing an inline
  `function() ... end` is mis-cut; none exists in the corpus today.
* Comment stripping is textual (`--` outside a balanced quote count), the same
  approximation every other census here uses.
* A duplicate operand is not automatically a BUG -- `CaptBot ~= nil and
  CaptBot ~= nil` in TypeScript-generated Lua is noise.  The tool reports; the
  reader judges, and the judgement is stored here.
* ⭐ A judgement is anchored to the CHAIN TEXT (GH #442), so editing that chain
  -- even in a way that leaves the duplicate standing -- retires the anchor and
  the finding goes `*NEW*` again.  That is the intended direction: the sentence
  the judgement argues about is the chain, so a changed chain is an unjudged
  chain.  It is NOT insertion-proofing gone wrong; insertions elsewhere in the
  file do not touch it.
* One residual line-number dependence remains and is deliberate: `conditions()`
  joins at most MAX_JOIN_LINES lines, so inserting enough lines INSIDE a
  multi-line condition can move the `then` out of reach and change the joined
  text.  That is a changed chain by this tool's definition, and it goes red.

WHY THE KEY IS NOT A LINE NUMBER (GH #442)
------------------------------------------
It used to be `(relpath, condition_start_line, operand)`.  On 2026-09-02 commit
`77e18be9` inserted TEN COMMENT LINES at `ability_item_usage_generic.lua:3406`;
the judged polliwog duplicate slid from :8246 to :8256, stopped matching its
key, printed `*NEW*`, and took four assertions red -- with nothing in `bots/`
changed.  The same +10 re-anchored `item_name_census`'s pin the same night
(`f00226b`).  Two tools, one insertion: that is the shape of the key, not bad
luck.  The cost is worse than the noise: a ratchet whose whole purpose is "a
NEW duplicate goes red the day it lands" teaches its readers to skip its red.

The replacement key is `(relpath, operand, anchor)` where `anchor` is a short
hash of the NORMALIZED CHAIN TEXT the duplicate sits in.  Insertions above it
do not move it.  The failure mode a content key introduces -- a genuinely new
duplicate silently absorbed into an existing judgement -- is closed by making
ambiguity LOUD rather than by preferring the first match: two live findings
under one key, or two judged rows under one key, print `AMBIGUOUS ANCHOR` and
exit 3.  The line number is still recorded, but only as a place to look; when
it drifts the tool prints `LINE NOTE` and stays green.
"""

import argparse
import collections
import hashlib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lua_corpus  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

#: Shortest operand text worth comparing.  Below this the "duplicate" is noise
#: like `i` or `n ~= 0`, and the chain is not an enumeration of members.
MIN_OPERAND_CHARS = 7

#: Detector A judgements.  One row is
#: `(relpath, operand_text, chain_anchor, line_last_seen, why)`; the KEY is the
#: first three (GH #442) and `line_last_seen` is navigation only.  Recompute an
#: anchor with `--anchors`.
_JUDGED_DUP_ROWS = [
    ("bots/BotLib/hero_dark_seer.lua", "#nInRangeEnemy==0", "91a07320", 417,
        "GH #434 DROPPED-MEMBER.  The third guard in the chain reads "
        "`nEnemyTowers ~= nil and #nInRangeEnemy == 0`; its two siblings each "
        "pair their own guard with their own count, so the intended operand is "
        "`#nEnemyTowers == 0` and the enemy-tower check is absent.  Detector B "
        "names the same line from the other side.  REGISTERED, NOT REPAIRED: "
        "dark_seer has corpus 0 (corpus_hero_census.py --hero dark_seer => "
        "DOMAIN-EMPTY, exit 3), so condition (a) cannot be bought."),
    ("bots/BotLib/hero_kunkka.lua", "Combo2Time~=0", "226746e3", 277,
        "GH #434 DROPPED-MEMBER.  The combo-in-progress guard tests "
        "Combo1/Combo2/Combo2.  The same file enumerates all THREE combo "
        "timers COMPLETE four times over -- declarations :226-228, the cast "
        "condition :257-259, and the resets :238-240 / :261-263 / :271-273 -- "
        "and each combo arms its own timer (:288 / :300 / :311), so the third "
        "operand is `Combo3Time ~= 0`.  A running combo 3 therefore does not "
        "stop a new combo from being queued on top of it.  REGISTERED, NOT "
        "REPAIRED: kunkka has corpus 0 (DOMAIN-EMPTY), so condition (a) cannot "
        "be bought."),
    ("bots/BotLib/hero_hoodwink.lua", "J.HasItem(bot,'item_mjollnir')",
     "54e8cad0", 278,
        "GH #434 DROPPED-MEMBER, repair direction UNDETERMINED.  The acorn-shot "
        "push gate reads `(HasItem(maelstrom) or HasItem(mjollnir) or "
        "HasItem(mjollnir))`; a literal repeat inside a disjunction of "
        "`HasItem` predicates cannot be intentional, so a third item was meant. "
        "Which one is NOT decidable from the repo: aba_site.lua:682 enumerates "
        "{bfury, maelstrom, mjollnir, radiance}, advanced_item_strategy.lua:315 "
        "enumerates {maelstrom, mjollnir, radiance, battlefury}, and the "
        "maelstrom upgrade path itself offers item_gungir (which this repo does "
        "buy).  Three witnesses, three different completions.  REGISTERED, NOT "
        "REPAIRED, and it would stay unrepaired even with a corpus: hoodwink "
        "has corpus 0 AND sits on the WeakHeroes throttle list."),
    ("bots/BotLib/hero_snapfire.lua", "#nTargetInRangeAlly>=1", "8de0a0c7", 672,
        "GH #434 DROPPED-MEMBER, and its witness is the chain itself.  The "
        "guard reads `(#nTargetInRangeAlly >= 1 and #nTargetInRangeAlly >= 1) "
        "or #nTargetInRangeAlly == 0`, which over a table length is `x >= 1 or "
        "x == 0` -- a TAUTOLOGY, so the whole `if` is a no-op wrapper and the "
        "branch below it is unconditional.  The member that went missing is "
        "named one line up: :666-667 declare `nInRangeAlly` beside "
        "`nTargetInRangeAlly` and :669 guards BOTH, so the intended first "
        "operand is `#nInRangeAlly >= 1`.  REGISTERED, NOT REPAIRED: snapfire "
        "has corpus 0 (DOMAIN-EMPTY)."),
    ("bots/BotLib/hero_disruptor.lua", "J.CanCastOnNonMagicImmune(enemyHero)",
     "3e0318d4", 378,
        "IDEMPOTENT.  Same predicate, same argument, no sibling enumeration in "
        "the chain -- re-testing it changes nothing."),
    ("bots/BotLib/hero_ember_spirit.lua", "nInRangeAlly~=nil", "287cfad0", 529,
        "IDEMPOTENT.  `nInRangeAlly` IS substantively read later in the same "
        "chain, so this is a repeated guard, not a lost member."),
    ("bots/BotLib/hero_tiny.lua", "J.IsValidTarget(botTarget)", "02aa798f", 729,
        "IDEMPOTENT.  Same predicate, same argument."),
    ("bots/FunLib/captain_mode.lua", "CaptBot~=nil", "86d2bd7e", 97,
        "IDEMPOTENT.  TypeScript-generated Lua (`typescript/` is dev-only and "
        "not the Workshop deliverable); the emitter doubled the null check."),
    ("bots/FunLib/rubick_hero/crystal_maiden.lua", "notJ.IsRealInvisible(bot)",
     "c5cb9de1", 735,
        "IDEMPOTENT.  The rubick twin of CM's clone logic; the shipped "
        "`hero_crystal_maiden.lua` was rewritten by this project and does not "
        "share this chain, so there is no sibling that names a lost member."),
    ("bots/ability_item_usage_generic.lua",
     "J.CanCastOnNonMagicImmune(npcEnemy)", "b6e7e7da", 3189,
        "IDEMPOTENT.  Same predicate, same argument, inside the hurricane-pike "
        "loop."),
    ("bots/mode_team_roam_generic.lua", "notJ.IsRoshan(nEnemysCreeps[1])",
     "c16e3513", 1058,
        "IDEMPOTENT.  Same predicate, same subscript."),
    # ⭐ THE ROW GH #442 WAS OPENED FOR.  `line_last_seen` moved 8246 -> 8256 on
    # 2026-09-02 (ten COMMENT lines inserted at :3406) and the row is now keyed
    # by the chain text instead, so that shift is a `LINE NOTE`, not a red.
    ("bots/ability_item_usage_generic.lua",
     'notallyHero:HasModifier("modifier_juggernaut_healing_ward_heal")',
     "1585a9b8", 8256,
        "IDEMPOTENT.  The polliwog-charm heal filter repeats one member of the "
        "already-being-healed set.  It LOOKS like the dropped-member shape and "
        "is not: the repo's only sibling enumeration of that set "
        "(ability_item_usage_generic.lua:2362-2365, the salve ally scan) is "
        "{filler_heal, elixer_healing, flask_healing, "
        "juggernaut_healing_ward_heal} and this chain already carries all four "
        "plus two more.  No sibling names a missing member, so nothing here "
        "says WHICH modifier the second copy should have been -- and inventing "
        "one would be an ungated behaviour change on a guess."),
]

#: Detector B judgements, same row shape: the key is
#: `(relpath, local_name, init+chain anchor)`.
_JUDGED_PARITY_ROWS = [
    ("bots/BotLib/hero_dark_seer.lua", "nEnemyTowers", "db87fc39", 415,
        "GH #434 DROPPED-READ.  `bot:GetNearbyTowers(700, true)` is fetched, "
        "guarded at :419, and its count is never consulted; the two siblings "
        "in the same chain each carry their own count.  Invisible to "
        "write_only_local_census.py because the guard counts as a read.  "
        "REGISTERED, NOT REPAIRED: dark_seer corpus 0."),
]


def build_judged(rows):
    """`rows` -> ({key: why}, {key: line_last_seen}, [keys written twice]).

    ⛔ The third return value is the whole point of not writing these tables as
    dict literals.  A dict literal with two identical keys keeps the LAST one
    and says nothing; that is exactly the silent-absorption failure a content
    key could introduce, arriving through the front door.  Here it is collected
    and printed as AMBIGUOUS ANCHOR, and it makes the tool exit 3.
    """
    table, lines, collisions = {}, {}, []
    for relpath, tail, anchor_hex, line, why in rows:
        key = (relpath, tail, anchor_hex)
        if key in table:
            collisions.append(key)
        table[key] = why
        lines[key] = line
    return table, lines, collisions


JUDGED_DUP, JUDGED_DUP_LINES, JUDGED_DUP_COLLISIONS = build_judged(_JUDGED_DUP_ROWS)
JUDGED_PARITY, JUDGED_PARITY_LINES, JUDGED_PARITY_COLLISIONS = build_judged(
    _JUDGED_PARITY_ROWS)

COND_KW = re.compile(r"\b(if|elseif|while)\b")
CUT_KW = re.compile(r"\b(then|do)\b")
LOCAL_DECL = re.compile(r"^\s*local\s+([A-Za-z_]\w*)\s*=\s*(\S.*)$")
NAME_RE = re.compile(r"(?<![\w.:])([A-Za-z_]\w*)(?![\w])")
MAX_JOIN_LINES = 30


def strip_comments(text):
    """House comment strip: cut at the first `--` with balanced quotes before it."""
    out = []
    for line in text.split("\n"):
        i = line.find("--")
        if i >= 0 and (line[:i].count('"') + line[:i].count("'")) % 2 == 0:
            line = line[:i]
        out.append(line)
    return out


def split_top(expr, sep):
    """Split `expr` on `sep` (`and`/`or`) at bracket depth 0."""
    parts, depth, cur, i = [], 0, "", 0
    while i < len(expr):
        c = expr[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if depth == 0:
            m = re.match(r"\b%s\b" % sep, expr[i:])
            if m and (i == 0 or not (expr[i - 1].isalnum() or expr[i - 1] == "_")):
                parts.append(cur)
                cur = ""
                i += m.end()
                continue
        cur += c
        i += 1
    parts.append(cur)
    return [p.strip() for p in parts if p.strip()]


def conditions(lines):
    """Yield (start_line, end_line, condition_text) for every if/elseif/while."""
    out = []
    for i, line in enumerate(lines):
        m = COND_KW.search(line)
        if not m:
            continue
        buf = line[m.end():]
        j = i
        while not CUT_KW.search(buf) and j - i < MAX_JOIN_LINES and j + 1 < len(lines):
            j += 1
            buf += " " + lines[j]
        cut = CUT_KW.search(buf)
        text = buf[:cut.start()] if cut else buf
        out.append((i + 1, j + 1, " ".join(text.split())))
    return out


def norm(text):
    return re.sub(r"\s+", "", text)


def anchor(text):
    """Short content anchor over normalized text (GH #442).

    Eight hex digits, which is plenty: it is not a security hash and it is
    scoped by (file, operand) already.  A collision inside one scope does not
    silently pass either -- it lands in the AMBIGUOUS ANCHOR path with every
    other two-findings-one-key case.
    """
    return hashlib.sha1(norm(text).encode("utf-8")).hexdigest()[:8]


def dup_key(f):
    """Detector A key: file + duplicated operand + the chain it sits in."""
    return (f["file"], f["operand"], anchor(f["cond"]))


def parity_key(f):
    """Detector B key: file + local name + its initializer AND its chain.

    The initializer alone is too weak (`bot:GetNearbyTowers(700, true)` is
    written in several files and could be written twice in one), and the chain
    alone would ignore which local the judgement is about.
    """
    return (f["file"], f["name"], anchor(f["init"] + "|" + f["cond"]))


def guard_of(operand):
    """Name if `operand` is exactly `NAME ~= nil` / `NAME == nil` (either order)."""
    m = re.match(r"^([A-Za-z_]\w*)\s*[~=]=\s*nil$", operand)
    if m:
        return m.group(1)
    m = re.match(r"^nil\s*[~=]=\s*([A-Za-z_]\w*)$", operand)
    return m.group(1) if m else None


def chain_scopes(cond):
    """`cond` plus every nested bracket-group interior, deduplicated.

    A chain does not always sit at the outermost level: two of the five
    dropped-member sites in this corpus are parenthesised sub-chains
    (`(HasItem(a) or HasItem(b) or HasItem(b))`).  A top-level-only splitter
    reports neither, so the descent is not a nicety -- it is 2 of 5.
    """
    scopes, seen, queue = [], set(), [cond]
    while queue:
        cur = queue.pop(0)
        key = norm(cur)
        if not key or key in seen:
            continue
        seen.add(key)
        scopes.append(cur)
        depth, start = 0, None
        for i, c in enumerate(cur):
            if c == "(":
                depth += 1
                if depth == 1:
                    start = i + 1
            elif c == ")":
                depth -= 1
                if depth == 0 and start is not None:
                    queue.append(cur[start:i])
                    start = None
    return scopes


def scan_dup(rel, conds):
    """Detector A: an operand repeated inside one and/or chain, at any depth."""
    found, chains = [], 0
    for start, _end, cond in conds:
        if not cond:
            continue
        for scope in chain_scopes(cond):
            for sep in ("and", "or"):
                parts = split_top(scope, sep)
                if len(parts) < 2:
                    continue
                chains += 1
                counts = collections.Counter(norm(p) for p in parts)
                for text, n in sorted(counts.items()):
                    if n > 1 and len(text) >= MIN_OPERAND_CHARS:
                        found.append({"file": rel, "line": start, "sep": sep,
                                      "operand": text, "times": n,
                                      "cond": scope})
    return found, chains


def scan_parity(rel, lines, conds):
    """Detector B: a local whose ONLY read is its own nil-guard, in a chain
    whose siblings do pair their guard with a substantive read."""
    found, guard_only, declared = [], 0, 0
    by_line = {}
    for start, end, cond in conds:
        for n in range(start, end + 1):
            by_line.setdefault(n, (start, cond))

    # One tokenising pass for the whole file, not one full scan per local: the
    # per-local form is quadratic and made this census the slowest thing in
    # tests/run_py_tests.sh for no answer it did not already have.
    index = collections.defaultdict(list)
    for ln, line in enumerate(lines, 1):
        for hit in NAME_RE.finditer(line):
            index[hit.group(1)].append((ln, hit.start(), hit.end()))

    for ln, line in enumerate(lines, 1):
        m = LOCAL_DECL.match(line)
        if not m:
            continue
        name, init = m.group(1), m.group(2).strip()
        declared += 1
        sites, only_guard = [], True
        for l2, col_a, col_b in index.get(name, ()):
            if l2 == ln:
                continue
            other = lines[l2 - 1]
            sites.append(l2)
            after, before = other[col_b:], other[:col_a]
            if re.match(r"\s*[~=]=\s*nil\b", after):
                continue
            if re.search(r"\bnil\s*[~=]=\s*$", before):
                continue
            only_guard = False
        if not sites or not only_guard:
            continue                       # unread locals belong to the other census
        guard_only += 1

        # Sibling parity, inside the chain that holds the guard.
        hit = by_line.get(sites[0])
        if not hit:
            continue
        start, cond = hit
        parts = split_top(cond, "and")
        if len(parts) < 2:
            continue
        guards, substantive = set(), set()
        for p in parts:
            g = guard_of(p)
            if g:
                guards.add(g)
                continue
            for w in re.findall(r"(?<![\w.:])([A-Za-z_]\w*)(?![\w])", p):
                substantive.add(w)
        complete = sorted(guards & substantive)
        if name in substantive or not complete:
            continue
        found.append({"file": rel, "line": ln, "name": name, "init": init,
                      "guard_line": sites[0], "cond_line": start,
                      "siblings": complete, "cond": cond})
    return found, guard_only, declared


def scan(root=None):
    dup, parity = [], []
    chains = locals_seen = guard_only = 0
    for path in lua_corpus.bots_lua_files(root):
        rel = os.path.relpath(path, root or REPO).replace(os.sep, "/")
        lines = strip_comments(lua_corpus.read_lua(path, errors="replace"))
        conds = conditions(lines)
        d, c = scan_dup(rel, conds)
        p, g, n = scan_parity(rel, lines, conds)
        dup += d
        parity += p
        chains += c
        guard_only += g
        locals_seen += n
    return dup, parity, chains, guard_only, locals_seen


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=None, help="corpus root (default: repo)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--anchors", action="store_true",
                    help="print every finding's content key and exit 0 "
                         "(how you re-anchor a row after editing a chain)")
    args = ap.parse_args()

    try:
        dup, parity, chains, guard_only, locals_seen = scan(args.root)
    except lua_corpus.CorpusVanished as exc:
        lua_corpus.uncertifiable(exc, "chain_member_census")
        return 2

    if args.anchors:
        for f in sorted(dup, key=lambda x: (x["file"], x["line"])):
            print("DUP     %s  %-14s  line %d  %s"
                  % (dup_key(f) + (f["line"], f["operand"])))
        for f in sorted(parity, key=lambda x: (x["file"], x["line"])):
            print("PARITY  %s  %-14s  line %d  %s"
                  % (parity_key(f) + (f["line"], f["name"])))
        return 0

    # AMBIGUOUS ANCHOR (GH #442).  Two findings under one key, or two judged
    # rows under one key, mean a judgement cannot say WHICH site it judges.
    # Preferring the first match here is the silent-absorption failure that a
    # content key would otherwise buy in exchange for insertion-proofing: a
    # genuinely new duplicate would inherit an old verdict and never print
    # `*NEW*`.  So it is loud instead, and it is red.
    ambiguous = []
    for label, keys, collisions in (
            ("judged row written twice (dup)", [], JUDGED_DUP_COLLISIONS),
            ("judged row written twice (parity)", [], JUDGED_PARITY_COLLISIONS),
            ("two findings, one key (dup)",
             [dup_key(f) for f in dup], []),
            ("two findings, one key (parity)",
             [parity_key(f) for f in parity], [])):
        for key, n in sorted(collections.Counter(keys).items()):
            if n > 1:
                ambiguous.append((label, key, n))
        for key in collisions:
            ambiguous.append((label, key, 2))
    for label, key, n in ambiguous:
        print("AMBIGUOUS ANCHOR  %s:%s [%s]  %s x%d  -- a judgement cannot "
              "name WHICH site it judges; split the anchor (edit one chain or "
              "widen the key), do not pick one." % (key + (label, n)))

    # Denominators first.  A zero reading and a scanner that reached nothing
    # print the same FINDINGS 0 unless the denominator is beside it (GH #329:
    # the quantity you report has to be the quantity you measured).
    print("SCANNED   and/or chains %d" % chains)
    print("SCANNED   locals with an initializer %d  (guard-only %d)"
          % (locals_seen, guard_only))

    def line_note(key, line, lines_table):
        """A judged row whose recorded line moved.  Navigation, never a red.

        This is where the old key shape's four red assertions used to come
        from.  It prints because a reader looking the site up wants the new
        number; the row itself is still matched, because the key is the chain.
        """
        was = lines_table.get(key)
        if was is not None and was != line:
            print("               LINE NOTE  judged row records :%d, this "
                  "finding is at :%d (insertion above; the key is the chain "
                  "text, so this is not a finding)." % (was, line))

    novel = 0
    for f in sorted(dup, key=lambda x: (x["file"], x["line"], x["operand"])):
        key = dup_key(f)
        known = key in JUDGED_DUP
        novel += 0 if known else 1
        print("DUP-OPERAND    %s:%d  [%s x%d]  %s%s" % (
            f["file"], f["line"], f["sep"], f["times"], f["operand"],
            "" if known else "   *NEW*"))
        # LINE NOTE prints even under --quiet: it is a FACT about this run (a
        # recorded line no longer matches), not the judgement prose --quiet is
        # there to suppress, and it is the one line that tells a reader why a
        # number they wrote down moved.
        if known:
            line_note(key, f["line"], JUDGED_DUP_LINES)
        if not args.quiet:
            print("               cond   %s" % f["cond"][:150])
            if known:
                print("               judged: %s" % JUDGED_DUP[key])
            else:
                print("               anchor %s  (re-anchor a judged row with "
                      "--anchors; a CHANGED CHAIN is meant to land here)"
                      % key[2])

    for f in sorted(parity, key=lambda x: (x["file"], x["line"])):
        key = parity_key(f)
        known = key in JUDGED_PARITY
        novel += 0 if known else 1
        print("PARITY-BREAK   %s:%d  %s = %s%s" % (
            f["file"], f["line"], f["name"], f["init"][:60],
            "" if known else "   *NEW*"))
        if known:
            line_note(key, f["line"], JUDGED_PARITY_LINES)
        if not args.quiet:
            print("               guarded at :%d, never read; siblings that DO "
                  "pair guard+read: %s" % (f["guard_line"], ", ".join(f["siblings"])))
            if known:
                print("               judged: %s" % JUDGED_PARITY[key])
            else:
                print("               anchor %s  (--anchors)" % key[2])

    # A judged row that matches nothing.  Informational on purpose: the honest
    # reasons (the site was repaired, the chain was rewritten) are ordinary,
    # and the dishonest one -- a rewrite that kept the duplicate -- already
    # goes red from the *NEW* side in the same run.
    for label, table, live in (("dup", JUDGED_DUP, {dup_key(f) for f in dup}),
                               ("parity", JUDGED_PARITY,
                                {parity_key(f) for f in parity})):
        for key in sorted(set(table) - live):
            print("STALE JUDGEMENT  %s  %s:%s [%s]  matches no finding today "
                  "(informational; retire the row)" % ((label,) + key))

    total = len(dup) + len(parity)
    print("FINDINGS  %d  (dup %d, parity %d; judged %d, new %d; ambiguous %d)"
          % (total, len(dup), len(parity), total - novel, novel, len(ambiguous)))
    if ambiguous:
        return 3
    if not total:
        return 0
    return 3 if novel else 0


if __name__ == "__main__":
    sys.exit(main())
