#!/usr/bin/env python3
"""Ratchet + reverse assertions for the lost-chain-member census.

WHAT THE CLASS IS.  A copy-pasted conjunct whose one token was never changed.
The chain keeps the length the author intended -- a reader counts the right
number of `and`s and moves on -- while one member of the intended set is
silently absent.  Every gate this repo runs is blind to it: it is valid Lua (so
`test_smoke_load.lua` loads it), it touches no undefined global (so `luacheck
bots game`, whose `.luacheckrc` sets `only = {"1"}`, is silent), and its only
in-game symptom is a check that never happens -- no crash, no log, on a
platform where `print()` never reaches the server console at all.

⭐ THE CRITERION THAT DOES THE WORK.  A duplicate operand is a FACT; "a member
was dropped" is a CLAIM, and the claim needs a witness: sibling code that
enumerates the intended set COMPLETE and so names what is missing, or a chain
that the repeat makes vacuous.  Twelve duplicates are in the corpus; four have
such a witness and eight do not, and section 2 pins the discriminator in both
directions -- including `ability_item_usage_generic.lua:8256`, which wears the
dropped-member shape and fails the test, because the repo's only sibling
enumeration of that set is already fully covered by the chain that repeats.

⭐ AND THE FIRST DRAFT OF THIS SWEEP FOUND HALF THE CLASS.  It split only the
OUTERMOST and/or chain of a condition and reported ten duplicates -- a number
that looked like a completed sweep.  Two of the four dropped-member sites are
parenthesised sub-chains (`(HasItem(a) or HasItem(b) or HasItem(b))` in
hoodwink, `(#x >= 1 and #x >= 1)` in snapfire), so top-level-only missed 2 of 4
while printing a denominator.  Section 2 pins the descent, because a splitter
that stops at depth 0 is the shape of an honest-looking sweep that is half a
sweep.

⭐ THE HOLE THIS OPENS IN AN EXISTING CENSUS.  `write_only_local_census.py`
asks "is this local ever read".  A self nil-guard IS a read, so a local that is
fetched, guarded, and never actually consulted answers YES and stays invisible.
Section 4 asserts that hole rather than describing it -- and it took a
surviving mutant to make the assertion honest.  The first draft asserted only
"nEnemyTowers is absent from the output", which is true for a DULLER reason:
that census's default scope is nine decision files, so no hero file is a
candidate at all.  The claim is now made under `--all` and carries a positive
control: the SAME identifier IS reported in three sibling files
(hero_antimage, hero_morphling, rubick_hero/antimage) and is NOT reported in
dark_seer.  Same name, same scan, same run -- so the silence is about that
site's guard and nothing else.

FIVE LAYERS.

  LAYER 0 -- the premise (section 0).  The shipped sites really are written the
  way this test claims.  Asserted against the SOURCE TEXT, not against the
  tool, so tool and source cannot drift into agreeing with each other about a
  file that changed underneath both.

  LAYER 1 -- the ratchet (section 1).  Exact counts, with the DENOMINATORS
  pinned beside them.  A zero and a scanner that reached nothing print the same
  `FINDINGS 0` unless the chain count and the local count are checked too
  (GH #329: the quantity you report has to be the quantity you measured).

  LAYER 2 -- the reverse assertions (section 2).  Both detectors live entirely
  in a definition, so each definition is pinned on a synthetic corpus.  The
  dangerous direction is the FALSE POSITIVE: a correct chain reported as a
  defect is how a later round "repairs" working code.

  LAYER 3 -- the domain price (section 3), measured rather than asserted, and
  DOUBLE-SIDED.  Both dropped-member sites sit in heroes the fixture archive
  does not contain, so condition (a) cannot be bought and neither is repaired.
  If a future corpus does carry them this section goes red and says so -- that
  is the day the repair becomes buyable, and it must not pass silently.

  ⛔ Section 3 also pins the trap GH #431 paid for: a zero read off a token the
  corpus does not use looks exactly like a zero read off an empty domain.  So
  BOTH spellings are asserted (`npc_dota_hero_kunkka` and bare `kunkka`), and a
  hero the corpus DOES hold is asserted non-zero beside them, so the reading
  cannot be an artefact of the grep.

  LAYER 4 -- the blind spot (section 4).  The claim that
  `write_only_local_census.py` cannot see a guard-only local is asserted
  against that tool's actual output.

Run: python3 tests/test_chain_member_census.py   (or tests/run_py_tests.sh)
"""

import glob
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "chain_member_census.py")
WRITE_ONLY = os.path.join(REPO, "tools", "agent", "write_only_local_census.py")

failures = []


def check(label, cond, detail=""):
    if cond:
        print("  ok   %s" % label)
    else:
        print("  FAIL %s%s" % (label, ("  -- " + detail) if detail else ""))
        failures.append(label)


def load_tool():
    spec = importlib.util.spec_from_file_location("chain_member_census", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def source_lines(rel):
    with open(os.path.join(REPO, rel), encoding="utf-8", errors="replace") as fh:
        return fh.read().split("\n")


def sole(indices, what):
    """The ONE index a locator found, asserted unique (GH #442).

    Section 0 used to name literal line numbers.  On 2026-09-02 ten inserted
    COMMENT lines moved two of them and took this file red with nothing in
    `bots/` changed.  A content locator says the same thing without the drift,
    and requiring UNIQUENESS keeps it an assertion rather than a search: if a
    second site with this shape ever lands, this goes red and names both,
    instead of silently pinning whichever came first.
    """
    check("locator is unique -- %s" % what, len(indices) == 1,
          "%d match(es) at line(s) %s" % (len(indices), [i + 1 for i in indices]))
    return indices[0] if indices else 0


def synthetic(body, name="probe.lua"):
    """Write `body` into a throwaway corpus root and scan it."""
    root = tempfile.mkdtemp(prefix="chainmember_")
    os.makedirs(os.path.join(root, "bots"))
    with open(os.path.join(root, "bots", name), "w", encoding="utf-8") as fh:
        fh.write(body)
    return root


cmc = load_tool()


# ---------------------------------------------------------------- section 0
print("=== 0. premise: the shipped sites are written as claimed (source text) ===")

ds = source_lines("bots/BotLib/hero_dark_seer.lua")
dsi = sole([i for i, l in enumerate(ds)
            if "local nEnemyTowers = bot:GetNearbyTowers(700, true)" in l],
           "dark_seer fetches the enemy towers into a local")
check("dark_seer:%d pairs its OWN guard with its OWN count" % (dsi + 3),
      "nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 3" in ds[dsi + 2],
      ds[dsi + 2].strip())
check("dark_seer:%d pairs its OWN guard with its OWN count" % (dsi + 4),
      "nInRangeEnemy ~= nil and #nInRangeEnemy == 0" in ds[dsi + 3],
      ds[dsi + 3].strip())
check("dark_seer:%d guards nEnemyTowers but counts nInRangeEnemy again"
      % (dsi + 5),
      "nEnemyTowers ~= nil and #nInRangeEnemy == 0" in ds[dsi + 4],
      ds[dsi + 4].strip())
check("dark_seer: nEnemyTowers appears exactly twice in the whole file",
      sum(len(re.findall(r"(?<![\w.:])nEnemyTowers(?![\w])", l)) for l in ds) == 2,
      "declaration + its own guard, and nothing else")

kk = source_lines("bots/BotLib/hero_kunkka.lua")
kki = sole([i for i in range(len(kk) - 2)
            if "Combo1Time ~= 0" in kk[i] and "Combo2Time ~= 0" in kk[i + 1]
            and "Combo2Time ~= 0" in kk[i + 2]],
           "kunkka tests Combo1/Combo2/Combo2 exactly once")
check("kunkka:%d-%d tests Combo1/Combo2/Combo2" % (kki + 1, kki + 3),
      True, " | ".join(x.strip() for x in kk[kki:kki + 3]))
kkw = sole([i for i in range(len(kk) - 2)
            if "Combo3Time ~= 0" in kk[i] and "Combo1Time ~= 0" in kk[i + 1]
            and "Combo2Time ~= 0" in kk[i + 2]],
           "kunkka enumerates all three timers exactly once")
check("kunkka: the WITNESS at :%d-%d enumerates all three timers"
      % (kkw + 1, kkw + 3), kkw < kki,
      "the complete enumeration sits ABOVE the defective one")
trios = [i for i in range(len(kk) - 2)
         if "Combo1Time = 0" in kk[i] and "Combo2Time = 0" in kk[i + 1]
         and "Combo3Time = 0" in kk[i + 2]]
check("kunkka: the WITNESS -- FOUR complete three-timer blocks (one "
      "declaration, three resets)", len(trios) == 4,
      str([i + 1 for i in trios]))
check("kunkka: the first of them is the DECLARATION, the rest are resets",
      trios and "local Combo1Time" in kk[trios[0]]
      and all("local" not in kk[i] for i in trios[1:]),
      " | ".join(kk[i].strip() for i in trios))
check("kunkka: Combo3Time IS armed, so the missing member is reachable state",
      any("Combo3Time = DotaTime()" in l for l in kk))

HEALS = ("modifier_filler_heal", "modifier_elixer_healing",
         "modifier_flask_healing", "modifier_juggernaut_healing_ward_heal")
aiug = source_lines("bots/ability_item_usage_generic.lua")
pw = sole([i for i in range(len(aiug) - 1)
           if aiug[i].strip() == aiug[i + 1].strip()
           and "modifier_juggernaut_healing_ward_heal" in aiug[i]],
          "aiug repeats a heal modifier on two adjacent lines exactly once")
check("aiug:%d-%d really does repeat one heal modifier" % (pw + 1, pw + 2),
      True, aiug[pw].strip())
four = [i for i in range(len(aiug) - 3)
        if all(any(m in l for l in aiug[i:i + 4]) for m in HEALS)]
check("aiug: a FOUR-member sibling heal set exists above the repeating chain",
      four and four[0] < pw, str([i + 1 for i in four]))
polliwog = "\n".join(aiug[pw - 7:pw + 4])
check("aiug: the repeating chain ALREADY carries all four of them "
      "(so no sibling names a missing member)",
      all(m in polliwog for m in HEALS))

hw = source_lines("bots/BotLib/hero_hoodwink.lua")
hwi = sole([i for i, l in enumerate(hw) if l.count("item_mjollnir") == 2],
           "hoodwink repeats item_mjollnir on exactly one line")
check("hoodwink:%d repeats item_mjollnir inside a parenthesised or-chain"
      % (hwi + 1), "item_maelstrom" in hw[hwi], hw[hwi].strip())
aba = source_lines("bots/FunLib/aba_site.lua")
adv = source_lines("bots/FunLib/advanced_item_strategy.lua")
check("hoodwink: THREE sibling enumerations name THREE different completions, "
      "so the repair direction is undetermined",
      any("item_bfury" in l and "item_radiance" in l for l in aba)
      and any("item_battlefury" in l for l in adv))

sf = source_lines("bots/BotLib/hero_snapfire.lua")
sfi = sole([i for i, l in enumerate(sf)
            if l.count("#nTargetInRangeAlly >= 1") == 2],
           "snapfire repeats #nTargetInRangeAlly >= 1 on exactly one line")
check("snapfire: the repeat makes the guard a TAUTOLOGY (x>=1 or x==0)",
      "#nTargetInRangeAlly == 0" in sf[sfi + 1], sf[sfi + 1].strip())
decl = [i for i in range(len(sf) - 1) if "local nInRangeAlly" in sf[i]
        and "local nTargetInRangeAlly" in sf[i + 1]]
near = [i for i in decl if i < sfi]
check("snapfire: the missing member is declared just above and guarded "
      "beside its twin",
      near and any("nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil" in l
                   for l in sf[near[-1]:sfi]),
      " | ".join(x.strip() for x in sf[near[-1]:near[-1] + 4]) if near else "")


# ---------------------------------------------------------------- section 1
print("=== 1. ratchet: exact findings AND their denominators ===")

visited = []
dup, parity, chains, guard_only, locals_seen = cmc.scan(visited=visited)

# ⛔ THE DENOMINATORS ARE FLOORS, NOT PINS (GH #457).  They were `== 10946`,
# `== 16088` and `== 45` until 09-03, when two gated landings and one new
# fixture moved two of them within fourteen hours -- three reds that said
# nothing about this census.  A denominator deserves freezing only when it
# should not move; pinned to a corpus that grows every round, an exact count is
# not a ratchet but an alarm clock set to a date, and the ratchet it looks like
# is the FINDINGS ratchet below (`dup`/`parity`, keyed by content), which does
# go red the day a new site lands and must not be diluted by neighbours that
# ring on the calendar.
#
# What the exact counts actually bought is M4 in the mutation stand: a corpus
# walk pointed at nothing reports FINDINGS 0, which is indistinguishable from a
# clean tree.  A floor buys that, and buys it permanently.  What a floor does
# NOT buy is a walk that drops a FILE OR TWO -- so that half is bought below by
# `visited`, as a relation against the corpus listing, which stays true however
# large bots/ becomes.  Floors are set at ~2/3 of the reading on the day this
# shape was written (chains 10950, locals 16094, guard-only 45), low enough
# that ordinary growth and ordinary deletion never reach them and high enough
# that a half-blind sweep does.
check("denominator floor: and/or chains scanned (all depths) -- collapse "
      "detector, NOT a pinned count",
      chains >= 7000, str(chains))
check("denominator floor: locals with an initializer", locals_seen >= 10000,
      str(locals_seen))
check("denominator floor: guard-only locals", guard_only >= 30, str(guard_only))
# ⭐ THE PART OF THE OLD PIN THAT WAS WORTH KEEPING, IN THE SHAPE THAT KEEPS IT.
# Not "the walk read 275 files" (a count, which moves) but "the walk read
# exactly the corpus, in order, no more and no fewer" (a relation, which does
# not).  This is what catches a walk that goes half-blind rather than fully
# blind -- the direction the floors above cannot see and the findings ratchet
# only sees when the dropped file happened to hold a finding.
check("coverage: the walk read EVERY corpus file and nothing else "
      "(the invariant a floor cannot buy)",
      visited == cmc.lua_corpus.bots_lua_relpaths(),
      "read %d, corpus %d, first difference: %s"
      % (len(visited), len(cmc.lua_corpus.bots_lua_relpaths()),
         next((a for a, b in zip(visited + [None],
                                 cmc.lua_corpus.bots_lua_relpaths() + [None])
               if a != b), "none")))
check("duplicate operands == 12", len(dup) == 12, str(len(dup)))
check("parity breaks == 1", len(parity) == 1, str(len(parity)))

dup_keys = {cmc.dup_key(d) for d in dup}
par_keys = {cmc.parity_key(p) for p in parity}
check("every duplicate is judged (a NEW one goes red the day it lands)",
      dup_keys == set(cmc.JUDGED_DUP),
      str(dup_keys ^ set(cmc.JUDGED_DUP)))
check("every parity break is judged", par_keys == set(cmc.JUDGED_PARITY),
      str(par_keys ^ set(cmc.JUDGED_PARITY)))
# ⭐ GH #442: the key must not BE a line number, and every judged row must
# still resolve to exactly one live finding -- that is the pair of properties
# the old shape had one of.
check("no judged key carries a line number (the anchor is 8 hex of the chain)",
      all(isinstance(k[2], str) and re.fullmatch(r"[0-9a-f]{8}", k[2])
          for k in list(cmc.JUDGED_DUP) + list(cmc.JUDGED_PARITY)),
      str([k for k in cmc.JUDGED_DUP if not isinstance(k[2], str)]))
check("no two judged rows share a key (a dict literal would have eaten one)",
      cmc.JUDGED_DUP_COLLISIONS == [] and cmc.JUDGED_PARITY_COLLISIONS == [],
      str(cmc.JUDGED_DUP_COLLISIONS + cmc.JUDGED_PARITY_COLLISIONS))
check("no two live findings share a key either (each judgement names ONE site)",
      len(dup_keys) == len(dup) and len(par_keys) == len(parity),
      "%d keys for %d findings" % (len(dup_keys) + len(par_keys),
                                   len(dup) + len(parity)))
# The line numbers are still recorded, and they are still correct today.  They
# are navigation: when one drifts the tool prints LINE NOTE and stays green.
check("every judged row's recorded line matches the finding it names TODAY",
      all(cmc.JUDGED_DUP_LINES[cmc.dup_key(d)] == d["line"] for d in dup)
      and all(cmc.JUDGED_PARITY_LINES[cmc.parity_key(p)] == p["line"]
              for p in parity),
      str([(cmc.dup_key(d), cmc.JUDGED_DUP_LINES[cmc.dup_key(d)], d["line"])
           for d in dup if cmc.JUDGED_DUP_LINES[cmc.dup_key(d)] != d["line"]]))

dropped = [k for k, v in cmc.JUDGED_DUP.items() if v.startswith("GH #434 DROPPED")]
check("exactly FOUR duplicates are judged dropped-member, eight idempotent",
      len(dropped) == 4 and len(cmc.JUDGED_DUP) - len(dropped) == 8,
      str(sorted(dropped)))
check("the four dropped-member sites are dark_seer / hoodwink / kunkka / snapfire",
      sorted(f for f, _o, _a in dropped) == [
          "bots/BotLib/hero_dark_seer.lua", "bots/BotLib/hero_hoodwink.lua",
          "bots/BotLib/hero_kunkka.lua", "bots/BotLib/hero_snapfire.lua"],
      str(sorted(dropped)))
# HALF the class hides one bracket down.  Assert it on the two real conditions:
# splitting only the outermost level finds nothing there.
for rel, operand in (("bots/BotLib/hero_hoodwink.lua",
                      "J.HasItem(bot,'item_mjollnir')"),
                     ("bots/BotLib/hero_snapfire.lua",
                      "#nTargetInRangeAlly>=1")):
    body = "\n".join(source_lines(rel))
    # Located by the duplicate itself, not by a line number (GH #442).
    hits = [(s, c) for s, _e, c in cmc.conditions(cmc.strip_comments(body))
            if cmc.norm(c).count(operand) >= 2]
    line, cond = hits[sole(list(range(len(hits))),
                           "%s holds %s twice in one condition"
                           % (os.path.basename(rel), operand))] if hits \
        else (0, "")
    top = {sep: [cmc.norm(p) for p in cmc.split_top(cond, sep)]
           for sep in ("and", "or")}
    check("%s:%d has NO duplicate at the outermost level..." % (rel, line),
          all(len(v) == len(set(v)) for v in top.values()), str(top))
    deeper = [s for s in cmc.chain_scopes(cond) if s != cond]
    check("...but chain_scopes descends and finds one", any(
        len([cmc.norm(p) for p in cmc.split_top(s, sep)])
        != len({cmc.norm(p) for p in cmc.split_top(s, sep)})
        for s in deeper for sep in ("and", "or")))

# ⭐ The cross-confirmation: two detectors written apart, one line.
check("the two detectors meet on the SAME dark_seer chain",
      any(d["file"] == "bots/BotLib/hero_dark_seer.lua" and d["line"] == 417
          for d in dup)
      and parity[0]["file"] == "bots/BotLib/hero_dark_seer.lua"
      and parity[0]["guard_line"] == 419)
check("the parity break names the two siblings that DO pair guard+read",
      parity[0]["siblings"] == ["nEnemyLaneCreeps", "nInRangeEnemy"],
      str(parity[0]["siblings"]))

rc = subprocess.call([sys.executable, TOOL, "--quiet"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
check("all findings judged => the tool exits 0 (3 is reserved for a NEW one)",
      rc == 0, "exit %d" % rc)


# ---------------------------------------------------------------- section 2
print("=== 2. reverse assertions: the false-positive direction ===")

clean = """
local X = {}
function X.f(bot)
    local nAlphaList = bot:GetNearbyTowers(700, true)
    local nBravoList = bot:GetNearbyCreeps(700, true)
    if nAlphaList ~= nil and #nAlphaList == 0
    and nBravoList ~= nil and #nBravoList == 0
    then
        return 1
    end
end
return X
"""
d, p, c, g, n = cmc.scan(synthetic(clean))
check("a correct chain -- every guard with its own read -- is NOT reported",
      d == [] and p == [], "dup=%s parity=%s" % (d, p))
check("...and the scan really ran on it (denominator non-zero)", c > 0, str(c))

broken = clean.replace("nAlphaList ~= nil and #nAlphaList == 0",
                       "nAlphaList ~= nil and #nBravoList == 0")
d, p, _, _, _ = cmc.scan(synthetic(broken))
check("the same chain with one token unchanged IS reported by both detectors",
      len(d) == 1 and len(p) == 1 and p[0]["name"] == "nAlphaList",
      "dup=%s parity=%s" % (d, p))

lonely = """
local X = {}
function X.f(bot)
    local aether = J.IsItemAvailable('item_aether_lens')
    if aether ~= nil then return 1 end
end
return X
"""
d, p, _, g, _ = cmc.scan(synthetic(lonely))
check("a guard-only local with NO parity-complete sibling is NOT reported "
      "(the `aether` existence-test idiom, 44 of the 45)",
      p == [], str(p))
check("...but it IS counted in the guard-only denominator", g == 1, str(g))

read_too = """
local X = {}
function X.f(bot)
    local nA = bot:GetNearbyTowers(700, true)
    local nB = bot:GetNearbyCreeps(700, true)
    if nA ~= nil and #nA == 0 and nB ~= nil and #nB >= 3 and #nA < 9 then
        return 1
    end
end
return X
"""
_, p, _, g, _ = cmc.scan(synthetic(read_too))
check("a local read substantively is not guard-only at all", g == 0, str(g))
check("...so it is not a parity break either", p == [], str(p))

# The guard predicate is the whole of detector B, so it is pinned directly --
# and ANCHORED at both ends.  Without the trailing anchor a compound operand
# reads as a bare guard and a correct existence test turns into a "defect".
check("guard_of accepts exactly the bare guard",
      cmc.guard_of("nA ~= nil") == "nA" and cmc.guard_of("nA == nil") == "nA"
      and cmc.guard_of("nil ~= nA") == "nA")
check("guard_of REFUSES a compound operand that merely starts like one",
      cmc.guard_of("nA ~= nil and #nA == 0") is None
      and cmc.guard_of("nA ~= nil or bFoo") is None
      and cmc.guard_of("#nA ~= nil") is None,
      "unanchored, these three all read as a guard on nA")

short = """
local X = {}
function X.f(a, b)
    if a > 1 and a > 1 then return 1 end
end
return X
"""
d, _, _, _, _ = cmc.scan(synthetic(short))
check("an operand under MIN_OPERAND_CHARS is noise, not an enumeration member",
      d == [] and cmc.MIN_OPERAND_CHARS == 7, str(d))

nested = """
local X = {}
function X.f(bot)
    if bot:GetHealth() > 300 and (bot:IsAlive() or bot:IsAlive()) then return 1 end
end
return X
"""
d, _, _, _, _ = cmc.scan(synthetic(nested))
check("a duplicate INSIDE brackets is found -- by the DESCENT, not by the "
      "outer split (the outer chain's operands are distinct)",
      [x["sep"] for x in d] == ["or"]
      and d[0]["cond"] == "bot:IsAlive() or bot:IsAlive()", str(d))

depth_ok = """
local X = {}
function X.f(bot)
    if bot:GetHealth() > 300 and (bot:IsAlive() or bot:IsChanneling()) then return 1 end
end
return X
"""
d, _, _, _, _ = cmc.scan(synthetic(depth_ok))
check("...and a bracket group with DISTINCT operands is still not reported",
      d == [], str(d))


# ------------------------------------------------------- section 2b (GH #442)
print("=== 2b. the KEY: insertion-proof, chain-sensitive, ambiguity-loud ===")

dupey = """
local X = {}
function X.f(bot)
    local nAlpha = bot:GetNearbyTowers(700, true)
    if nAlpha ~= nil and #nAlpha == 0 and #nAlpha == 0 then return 1 end
end
return X
"""
d_before, _, _, _, _ = cmc.scan(synthetic(dupey))
# The literal 2026-09-02 event: ten COMMENT lines above the site.
shifted = ("-- c\n" * 10) + dupey
d_after, _, _, _, _ = cmc.scan(synthetic(shifted))
check("one duplicate before and after ten inserted comment lines",
      len(d_before) == 1 and len(d_after) == 1,
      "%d / %d" % (len(d_before), len(d_after)))
check("⭐ the LINE moved by exactly ten -- this is the 2026-09-02 event",
      d_after[0]["line"] - d_before[0]["line"] == 10,
      "%d -> %d" % (d_before[0]["line"], d_after[0]["line"]))
check("...and the KEY did not move (the old key shape lost the row here)",
      cmc.dup_key(d_before[0]) == cmc.dup_key(d_after[0]),
      "%s vs %s" % (cmc.dup_key(d_before[0]), cmc.dup_key(d_after[0])))

# The other direction, and it is the one a content key must not get wrong: an
# EDITED chain is an unjudged chain, so the anchor has to move with the text.
edited = dupey.replace("nAlpha ~= nil and", "nAlpha ~= nil and bot:IsAlive() and")
d_edit, _, _, _, _ = cmc.scan(synthetic(edited))
check("editing the chain DOES move the anchor (a changed chain is unjudged)",
      len(d_edit) == 1 and cmc.dup_key(d_edit[0]) != cmc.dup_key(d_before[0]),
      str(cmc.dup_key(d_edit[0])))
check("...and the operand and file components are unchanged, so only the "
      "anchor carries the difference",
      cmc.dup_key(d_edit[0])[:2] == cmc.dup_key(d_before[0])[:2])

# Ambiguity, both sources.  Preferring the first match is the silent
# absorption a content key would otherwise buy; the tool refuses instead.
twin = dupey + dupey.replace("local X = {}", "").replace("return X", "")
d_twin, _, _, _, _ = cmc.scan(synthetic(twin))
check("two IDENTICAL chains in one file are two findings under ONE key",
      len(d_twin) == 2
      and len({cmc.dup_key(x) for x in d_twin}) == 1,
      str([cmc.dup_key(x) for x in d_twin]))
row = ("bots/probe.lua", "#nAlpha==0", "deadbeef", 4, "IDEMPOTENT.  probe.")
table, lines_, collisions = cmc.build_judged([row, row])
check("...and two judged rows under one key are COLLECTED, not silently "
      "collapsed the way a dict literal would",
      len(table) == 1 and collisions == [row[:3]], str(collisions))
check("build_judged keeps the recorded line beside the key, out of it",
      lines_[row[:3]] == 4 and len(list(table)[0]) == 3)


# ---------------------------------------------------------------- section 3
print("=== 3. domain price: measured, double-sided, and token-checked ===")

fixtures = sorted(glob.glob(os.path.join(REPO, "tests", "fixtures", "*.lua")))
# ⛔ The label says NON-EMPTY and the assertion said `== 107` (GH #457): the
# name stated the load-bearing property and the number stated a date.  What
# this control is for is M9 -- a glob that matches nothing turns every zero
# below into a statement about the empty set.  A floor buys exactly that, and
# it is the shape `tests/test_threshold_chain_census.py` already uses for the
# same archive one file over.
check("the fixture archive is NON-EMPTY (this is the denominator)",
      len(fixtures) >= 90, "%d fixture(s)" % len(fixtures))

blobs = []
for f in fixtures:
    with open(f, encoding="utf-8", errors="replace") as fh:
        blobs.append(fh.read())


def files_with(token):
    return sum(1 for b in blobs if token in b)


# ⛔ GH #431: a zero read off a token the corpus does not use is
# indistinguishable from a zero read off an empty domain.  Both spellings.
for hero in ("dark_seer", "kunkka", "hoodwink", "snapfire"):
    check("corpus holds 0 files with 'npc_dota_hero_%s'" % hero,
          files_with("npc_dota_hero_" + hero) == 0,
          str(files_with("npc_dota_hero_" + hero)))
    check("corpus holds 0 files with the bare token '%s' either" % hero,
          files_with(hero) == 0, str(files_with(hero)))
# Non-zero, not `== 53` (GH #457): this control's whole job is to separate a
# real absence from a broken reader (M10, which answers 0 for everything), and
# "non-zero" is that job stated exactly.  The 53 was a fixture count -- it moved
# the next time anyone archived a CM frame, which is a thing this team does on
# purpose, every week.
check("...and the SAME grep on a hero the corpus DOES hold is non-zero, "
      "so the zeros above are not an artefact of the token",
      files_with("npc_dota_hero_crystal_maiden") > 0,
      str(files_with("npc_dota_hero_crystal_maiden")))
# ⛔ The two-spelling rule is not hypothetical on THIS corpus.  One hero is
# present under two spellings with different counts, so a reading taken off the
# wrong one is off by a large factor while looking like a clean number.  The
# claim is that the two spellings DISAGREE and that neither is the empty
# reading -- a relation between two readings of the same corpus, which is what
# catches M11 (a reader that collapses the spellings) and which no landing can
# falsify.  The counts themselves (3 vs 19 when this was written) are fixture
# counts and were pinned exactly until GH #457.
vs_a = files_with("npc_dota_hero_vengefulspirit")
vs_b = files_with("npc_dota_hero_vengeful_spirit")
check("the spelling really does move the number: vengeful spirit reads "
      "differently under its two spellings, same corpus, same hero, and "
      "neither reading is zero",
      vs_a > 0 and vs_b > 0 and vs_a != vs_b, "%d vs %d" % (vs_a, vs_b))
check("neither hero's abilities appear either (a second, independent token)",
      files_with("dark_seer_ion_shell") == 0
      and files_with("kunkka_torrent") == 0)

rc = subprocess.call([sys.executable,
                      os.path.join(REPO, "tools", "agent",
                                   "corpus_hero_census.py"),
                      "--hero", "dark_seer", "--hero", "kunkka",
                      "--hero", "hoodwink", "--hero", "snapfire"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
check("corpus_hero_census agrees: exit 3 == at least one DOMAIN-EMPTY subject",
      rc == 3, "exit %d" % rc)

for key, why in list(cmc.JUDGED_DUP.items()) + list(cmc.JUDGED_PARITY.items()):
    if why.startswith("GH #434 DROPPED"):
        check("%s [%s] carries the not-repaired reason in its judgement"
              % (key[0], key[1]), "NOT REPAIRED" in why)


# ---------------------------------------------------------------- section 4
print("=== 4. the hole this opens in write_only_local_census ===")

ROW = re.compile(r"^WRITE-ONLY\s+(\S+)\s+(\S+):(\d+)", re.M)


def write_only_rows(*args):
    out = subprocess.run([sys.executable, WRITE_ONLY] + list(args),
                         capture_output=True, text=True).stdout
    return out, {(m.group(1), m.group(2)) for m in ROW.finditer(out)}


# The claim has TWO layers and both are measured, because the first draft of
# this section asserted only "nEnemyTowers is absent from the output" and a
# mutant that CLOSED the hole survived it -- the name is absent from the
# default run for a duller reason: hero files are not in the default scope.
default_out, default_rows = write_only_rows()
check("write_only_local_census ran and reported findings", "FINDINGS" in default_out)
check("layer 1 -- its DEFAULT scope is the nine decision files, so no "
      "BotLib/hero_*.lua local is a candidate at all",
      default_rows and not any(f.startswith("bots/BotLib/") for _n, f in default_rows),
      str(sorted(f for _n, f in default_rows))[:200])

all_out, all_rows = write_only_rows("--all")
check("...so the claim has to be made under --all, where hero files ARE "
      "scanned (306 findings)",
      len(all_rows) == 306, str(len(all_rows)))
# Positive control, and it is the strongest one available: the SAME identifier
# in three sibling files IS reported.  So the silence on dark_seer is about
# that site's guard, not about the name, the file type, or the scan.
siblings = sorted(f for n, f in all_rows if n == "nEnemyTowers")
check("layer 2 -- the positive control: the same name IS reported in three "
      "sibling files", siblings == ["bots/BotLib/hero_antimage.lua",
                                    "bots/BotLib/hero_morphling.lua",
                                    "bots/FunLib/rubick_hero/antimage.lua"],
      str(siblings))
check("...and yet dark_seer's nEnemyTowers is NOT among them -- the guard "
      "EATS the read",
      ("nEnemyTowers", "bots/BotLib/hero_dark_seer.lua") not in all_rows,
      "if this goes red the hole is closed and this section is obsolete")
check("...while THIS census does see it",
      parity[0]["name"] == "nEnemyTowers"
      and parity[0]["file"] == "bots/BotLib/hero_dark_seer.lua")


print()
if failures:
    print("%d FAILED: %s" % (len(failures), "; ".join(failures)))
    sys.exit(1)
print("all checks passed")
