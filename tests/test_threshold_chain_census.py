#!/usr/bin/env python3
"""Ratchet + reverse assertions for the dead-rung (threshold ladder) census.

WHAT THE CLASS IS.  A graded rule written as `if X >= A then ... elseif X >= B
then ...` is unreachable in its second rung whenever `B >= A`, because the
first rung already matched every input the second one wants.  The repo contains
exactly ONE such ladder today, and every gate this project runs is blind to it:
it is valid Lua (so `test_smoke_load.lua` loads it), it touches no undefined
global (so `luacheck bots game`, whose `.luacheckrc` sets `only = {"1"}`, is
silent), and its only in-game symptom is a number that stays one tier low --
with no crash and no log, on a platform where `print()` never reaches the
server console at all.

FOUR LAYERS.

  LAYER 0 -- the premise (section 0).  The shipped site really is written in
  the ascending order this test claims.  Asserted against the SOURCE TEXT, not
  against the tool, so tool and source cannot drift into agreeing with each
  other about a file that changed underneath both.

  LAYER 1 -- the ratchet (section 1).  Exactly one finding, at that site, dead
  in BOTH legs, with the denominator pinned too.  A new ladder goes red the day
  it lands.  A ZERO also goes red: a scan that reached nothing and a corpus
  that is clean print the same `FINDINGS 0` unless the chain count is checked.

  LAYER 2 -- the reverse assertions (section 2).  The scan's value is entirely
  in the definition of "subsumes", so each half of that definition is pinned on
  a synthetic corpus.  The dangerous direction is the FALSE POSITIVE: a
  correctly-ordered descending ladder must NOT be reported, or a later round
  "fixes" a working ladder into a broken one.

  LAYER 3 -- the domain price (section 3).  The one finding is NOT repaired,
  and this section is the reason, measured rather than asserted: the fixture
  archive holds zero blink and zero enhancement inventories, so no frame in it
  can ever exercise the ladder and condition (a) cannot be bought.  It is
  pinned DOUBLE-SIDED.  If a future corpus does carry them, this section goes
  red and says so -- that is the day the repair becomes buyable, and it must
  not pass silently.

  ⛔ Section 3 also pins the trap that nearly ate this reading.  Fixtures store
  inventories with the `item_` PREFIX STRIPPED (`'blink'`, not `'item_blink'`),
  so the obvious grep for `item_blink` returns zero on a corpus that could be
  full of them.  The first measurement in this round was exactly that grep.
  Both spellings are asserted here, with the non-empty denominator beside them,
  so a zero can never again be read off the wrong token.

Run: python3 tests/test_threshold_chain_census.py   (or tests/run_py_tests.sh)
"""

import glob
import importlib.util
import os
import re
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "threshold_chain_census.py")

failures = []


def check(label, cond, detail=""):
    if cond:
        print("  ok   %s" % label)
    else:
        print("  FAIL %s%s" % (label, ("  -- " + detail) if detail else ""))
        failures.append(label)


def load_tool():
    spec = importlib.util.spec_from_file_location("threshold_chain_census", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def scan_synthetic(mod, body):
    """Run the scanner over a one-file corpus and return its findings."""
    with tempfile.TemporaryDirectory() as tmp:
        os.makedirs(os.path.join(tmp, "bots"))
        with open(os.path.join(tmp, "bots", "synthetic.lua"), "w") as fh:
            fh.write(body)
        return mod.scan(tmp)


mod = load_tool()

# ---------------------------------------------------------------- section 0
print("=== 0. premise: the shipped ladder is really written ascending ===")
SITE = os.path.join(REPO, "bots", "ability_item_usage_generic.lua")
with open(SITE, encoding="utf-8") as fh:
    site_lines = fh.read().split("\n")

check("the source file is readable and long enough",
      len(site_lines) >= 1560, "only %d lines" % len(site_lines))

first_rung = site_lines[1540] if len(site_lines) > 1540 else ""
dead_rung = site_lines[1542] if len(site_lines) > 1542 else ""
check("line 1541 is the `>= 7.5*60 / 15*60` rung",
      "7.5*60" in first_rung and "15*60" in first_rung and ">=" in first_rung,
      repr(first_rung))
check("line 1543 is the `>= 12.5*60 / 25*60` rung, and it is an `elseif`",
      "12.5*60" in dead_rung and "25*60" in dead_rung
      and dead_rung.strip().startswith("elseif"),
      repr(dead_rung))
check("the two rungs read the same left-hand quantity (DotaTime())",
      "DotaTime()" in first_rung and "DotaTime()" in dead_rung)
check("the ladder is ASCENDING, which is what makes rung 2 unreachable",
      12.5 > 7.5 and 25 > 15)
check("the dead rung's body is the +135 tier that never applies",
      "135" in "\n".join(site_lines[1543:1545]),
      repr(site_lines[1543:1545]))
# The ladder lives inside the keen-eyed branch; if that moves, the whole
# reading moves with it, so it is named here rather than assumed.
check("the ladder sits in the item_enhancement_keen_eyed branch",
      "item_enhancement_keen_eyed" in "\n".join(site_lines[1537:1541]),
      repr(site_lines[1537:1541]))

# ---------------------------------------------------------------- section 1
print("=== 1. ratchet: exactly one dead rung in bots/, and a real denominator ===")
findings, chains = mod.scan()
check("the scan actually reached the corpus (denominator, not just a zero)",
      chains >= 3500, "if-chains seen = %d" % chains)
check("exactly one dead rung in the whole of bots/",
      len(findings) == 1, "findings = %s" % [
          (f["file"], f["first_line"], f["dead_line"]) for f in findings])
if len(findings) == 1:
    f = findings[0]
    check("it is the known site",
          (f["file"], f["first_line"], f["dead_line"])
          == ("bots/ability_item_usage_generic.lua", 1541, 1543),
          str((f["file"], f["first_line"], f["dead_line"])))
    check("dead in BOTH legs (this is not a turbo-only defect)",
          sorted(f["dead_in"]) == ["normal", "turbo"], str(f["dead_in"]))
    check("the turbo thresholds are the 7.5 / 12.5 minute pair",
          (f["first"][1][0], f["dead"][1][0]) == (450.0, 750.0),
          str((f["first"][1][0], f["dead"][1][0])))
check("every finding carries a judgement (a NEW one must be visible as new)",
      all((f["file"], f["first_line"], f["dead_line"]) in mod.JUDGED
          for f in findings))

# ---------------------------------------------------------------- section 2
print("=== 2. reverse assertions: what 'subsumes' means, both directions ===")

DESCENDING_OK = """
function X.F()
	if DotaTime() >= 750 then
		return 135
	elseif DotaTime() >= 450 then
		return 125
	end
end
"""
check("a correctly-ordered DESCENDING `>=` ladder is NOT reported",
      len(scan_synthetic(mod, DESCENDING_OK)[0]) == 0)

ASCENDING_BAD = """
function X.F()
	if DotaTime() >= 450 then
		return 125
	elseif DotaTime() >= 750 then
		return 135
	end
end
"""
check("an ascending `>=` ladder IS reported",
      len(scan_synthetic(mod, ASCENDING_BAD)[0]) == 1)

ASCENDING_LE_OK = """
function X.F()
	if nHp <= 0.2 then
		return 1
	elseif nHp <= 0.5 then
		return 2
	end
end
"""
check("a correctly-ordered ASCENDING `<=` ladder is NOT reported",
      len(scan_synthetic(mod, ASCENDING_LE_OK)[0]) == 0)

DESCENDING_LE_BAD = """
function X.F()
	if nHp <= 0.5 then
		return 2
	elseif nHp <= 0.2 then
		return 1
	end
end
"""
check("a descending `<=` ladder IS reported",
      len(scan_synthetic(mod, DESCENDING_LE_BAD)[0]) == 1)

MIXED_OPS = """
function X.F()
	if nHp >= 0.5 then
		return 2
	elseif nHp <= 0.2 then
		return 1
	end
end
"""
check("a band (`>=` then `<=`) is NOT reported -- opposite directions never subsume",
      len(scan_synthetic(mod, MIXED_OPS)[0]) == 0)

OTHER_LHS = """
function X.F()
	if DotaTime() >= 450 then
		return 1
	elseif GameTime() >= 750 then
		return 2
	end
end
"""
check("two DIFFERENT quantities are not a ladder",
      len(scan_synthetic(mod, OTHER_LHS)[0]) == 0)

EXTRA_CONJUNCT = """
function X.F()
	if DotaTime() >= 450 then
		return 1
	elseif bReady and DotaTime() >= 750 then
		return 2
	end
end
"""
check("a rung with an extra conjunct is skipped (it may be what makes it live)",
      len(scan_synthetic(mod, EXTRA_CONJUNCT)[0]) == 0)

TRAILING_CONJUNCT = """
function X.F()
	if DotaTime() >= 450 then
		return 1
	elseif DotaTime() >= 750 and bReady then
		return 2
	end
end
"""
check("a conjunct glued to the RIGHT of the threshold is skipped too",
      len(scan_synthetic(mod, TRAILING_CONJUNCT)[0]) == 0)

SEPARATE_IFS = """
function X.F()
	if DotaTime() >= 450 then
		return 1
	end
	if DotaTime() >= 750 then
		return 2
	end
end
"""
check("two separate `if`s are two chains, not one ladder",
      len(scan_synthetic(mod, SEPARATE_IFS)[0]) == 0)

TURBO_ONLY = """
function X.F()
	if DotaTime() >= (J.IsModeTurbo() and 450 or 900) then
		return 1
	elseif DotaTime() >= (J.IsModeTurbo() and 750 or 600) then
		return 2
	end
end
"""
turbo_only = scan_synthetic(mod, TURBO_ONLY)[0]
check("a ladder dead in TURBO but live in normal is reported as turbo-only",
      len(turbo_only) == 1 and turbo_only[0]["dead_in"] == ["turbo"],
      str([f["dead_in"] for f in turbo_only]))

THIRD_RUNG = """
function X.F()
	if DotaTime() >= 450 then
		return 1
	elseif DotaTime() >= 500 then
		return 2
	elseif DotaTime() >= 600 then
		return 3
	end
end
"""
check("a three-rung ascending ladder reports every dead rung, not just the first",
      len(scan_synthetic(mod, THIRD_RUNG)[0]) == 3,
      str(len(scan_synthetic(mod, THIRD_RUNG)[0])))

COMMENTED_OUT = """
function X.F()
	if DotaTime() >= 450 then
		return 1
	-- elseif DotaTime() >= 750 then
	end
end
"""
check("a commented-out rung is not a rung",
      len(scan_synthetic(mod, COMMENTED_OUT)[0]) == 0)

EQUAL_THRESHOLDS = """
function X.F()
	if DotaTime() >= 450 then
		return 1
	elseif DotaTime() >= 450 then
		return 2
	end
end
"""
check("an EQUAL repeated threshold is dead too (>= is not strict)",
      len(scan_synthetic(mod, EQUAL_THRESHOLDS)[0]) == 1)

# ---------------------------------------------------------------- section 3
print("=== 3. domain price: why the one finding is registered, not repaired ===")
fixtures = sorted(glob.glob(os.path.join(REPO, "tests", "fixtures", "*.lua")))
check("the fixture archive is non-empty (denominator for every zero below)",
      len(fixtures) >= 90, "%d fixture(s)" % len(fixtures))

blob = []
for p in fixtures:
    with open(p, encoding="utf-8") as fh:
        blob.append(fh.read())
blob = "\n".join(blob)

inv_tokens = set()
for m in re.finditer(r"items\s*=\s*\{([^}]*)\}", blob):
    for tok in m.group(1).split(","):
        tok = tok.strip().strip("'\"")
        if tok:
            inv_tokens.add(tok)

check("inventories really are recorded (a zero below is a zero, not an absence)",
      len(inv_tokens) >= 40 and "magic_wand" in inv_tokens,
      "%d distinct item token(s)" % len(inv_tokens))
check("⛔ and they are recorded WITHOUT the `item_` prefix -- the trap",
      not any(t.startswith("item_") for t in inv_tokens),
      str(sorted(t for t in inv_tokens if t.startswith("item_"))[:5]))

# ⛔ THE CORRECTED READING.  The round's first pass claimed the corpus held no
# blink either.  It does -- eight fixtures -- and the claim was an artefact of
# grepping the quoted token `'blink'` against inventories that spell it
# `blink_dagger`.  Both halves of that mistake (the `item_` prefix and the
# suffix) are pinned below, because the ladder is DOMAIN-EMPTY for a reason
# that survives being wrong about blink: the ENHANCEMENT is what is missing.
blink = sorted(t for t in inv_tokens if "blink" in t)
enh = sorted(t for t in inv_tokens if "enhancement" in t or t == "keen_eyed"
             or t == "magnifying_monocle")
check("blink IS in the corpus, spelled `blink_dagger` -- the near-miss, pinned "
      "so a future round cannot re-derive the wrong zero from `'blink'`",
      blink == ["blink_dagger"], str(blink))
check("⭐ DOMAIN-EMPTY, and this is the load-bearing zero: not one fixture "
      "inventory holds ANY enhancement, so the branch guarding the ladder "
      "(`HasItemInInventory('item_enhancement_keen_eyed')`) is false on every "
      "archived frame",
      enh == [], str(enh))
check("the wrong-token grep reads zero for BOTH spellings, and neither is "
      "evidence on its own (pinned so the readings can never be confused)",
      "item_blink" not in blob and "item_enhancement" not in blob)

# The ladder's own gate is a TIME as well as an item, and the archive DOES
# reach past 750 s -- barely.  Both halves are load-bearing and neither may be
# a frozen count: the comfortable "the corpus is early" was this round's first
# draft and it was FALSE, so the reach is asserted non-zero; and "barely" is a
# statement about the archive's SHAPE, so it is asserted as a share of the
# archive, not as `== 2`.
#
# ⛔ WHY NOT `len(late) == 2` (GH #457).  That was the assertion until a single
# new fixture past 750 s landed and turned it red -- a red that says nothing
# about this census, this ladder, or this corpus's domain price.  A denominator
# (or a numerator riding on one) deserves freezing only when it should not
# move; pinned to a corpus every round adds fixtures to, an exact count is not
# a ratchet but an alarm clock set to a date.  The share below rings on the day
# the archive genuinely stops being late-thin -- i.e. on the day "only just"
# stops being true -- and stays quiet for the ordinary landing that moves the
# count by one.  Recorded reading when this shape was written: 3 of 620
# (0.48%); the ceiling is 1%, a ~2x margin.
times = [float(m.group(1)) for m in re.finditer(r"\bt\s*=\s*([\d.]+)", blob)]
late = [t for t in times if t >= 750.0]
check("the archive does reach the 750 s rung (not one frame -- the reading "
      "the round's first draft got backwards), but only just: late frames are "
      "under 1% of the archive",
      len(times) >= 600 and len(late) >= 1 and len(late) * 100 <= len(times),
      "frames=%d late=%d (%.2f%%) max=%.1f"
      % (len(times), len(late), 100.0 * len(late) / max(1, len(times)),
         max(times)))

# The three conditions are independent, and the fix is unbuyable unless ALL
# THREE land on one frame.  That conjunction is the actual domain price.
late_and_blink = 0
for p in fixtures:
    with open(p, encoding="utf-8") as fh:
        txt = fh.read()
    if "blink_dagger" not in txt:
        continue
    if any(float(m.group(1)) >= 750.0
           for m in re.finditer(r"\bt\s*=\s*([\d.]+)", txt)):
        late_and_blink += 1
check("not one fixture is BOTH past 750 s AND holding a blink -- so even "
      "granting the enhancement for free, no archived frame separates the "
      "two rungs",
      late_and_blink == 0, "%d fixture(s)" % late_and_blink)

# ---------------------------------------------------------------- verdict
print()
if failures:
    print("FAIL %d/%d" % (len(failures), len(failures) + 0))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("PASS -- threshold chain census ratchet + reverse assertions")
sys.exit(0)
