#!/usr/bin/env python3
"""Ratchets for tools/agent/aoe_radius_source_census.py, and the frozen half of
the GH #502 ruling on `GetAOERadius`.

WHAT THE RULING IS.  GH #502's last open cell asked whether
`AbilityValues/radius` is the quantity the engine returns from
`Ability:GetAOERadius()` -- the question that decides whether
`crystal_maiden_freezing_field`'s KV 810 may replace the Liquipedia 835 that
`tests/test_replay_260819_cm_r_range.lua` runs two end-to-end cases on.  The
census answers it in the negative, and the negative has three legs, of which
this file freezes the two that need no network:

  (1) NO NAME IDENTITY.  Every other served getter is served because the KV
      carries a field of its own name.  There is no such field for this one:
      127 shipped-hero KV files carry 31 distinct top-level `Ability*` fields
      and not one of them contains "aoe" or "radius" (the census's question 1,
      network).
  (2) THE SNAPSHOT CANNOT BE QUOTED FOR (1) -- pinned here.  A reader who
      greps `tests/mock/special_value_shapes.lua` for `AbilityAOERadius` gets
      nothing, and that nothing is a property of the PARSER, not of the KV:
      `special_value_shape_census.parse_shapes` records a top-level field only
      if its name is in `special_value_key_census.TOP_LEVEL`, a fixed tuple.
      Absence of a name from a whitelist-filtered snapshot is not absence from
      the game.
  (3) THE FALLBACK RULE IS NOT A FUNCTION ON THE CALL SITES -- the frozen half
      pinned here.  Once name identity is gone, the only remaining rules are
      hand-written: "the key named `radius`" and "the key flagged
      `affected_by_aoe_increase`".  On the seven shipped `GetAOERadius()` call
      sites the two rules agree on exactly one key on ONE of them
      (sniper_shrapnel).  On Freezing Field itself the name rule offers
      `radius` while the flag rule offers three keys, `radius` among them --
      so picking 810 is a choice, not a read.

⭐ WHY THIS IS THE HERO GROUP'S BUSINESS AND NOT A TOOLING FOOTNOTE.  The
number that would have moved is an ANCHOR under a shipped focus-hero branch:
`abilityR:GetAOERadius() * 0.88` multiplies into every clause of CM's
`X.ConsiderR`.  Sourcing it from a key whose identity is a guess would have
replaced a number with a provenance (Liquipedia) by a number with none, and the
replacement would have read as a repair.

NOTHING HERE TOUCHES THE NETWORK.  The census's question (1) does; it is run by
hand (`python3 tools/agent/aoe_radius_source_census.py`) and its reading is
registered in the round's report, not asserted here.
"""

import os
import re
import subprocess
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import aoe_radius_source_census as C            # noqa: E402
import special_value_key_census as KEYS         # noqa: E402

SNAPSHOT = os.path.join(REPO, "tests", "mock", "special_value_shapes.lua")
CM_ULT = "crystal_maiden_freezing_field"


def snapshot_block(ability):
    """{key -> (base, [bonus names])} for one ability of the frozen snapshot.

    The snapshot is generated one key per line, so this reads it as the
    generated text it is rather than pulling in a Lua interpreter.
    """
    with open(SNAPSHOT, encoding="utf-8") as fh:
        src = fh.read()
    start = src.index("['%s'] = {" % ability)
    end = src.index("\n        },", start)
    out = {}
    for line in src[start:end].splitlines()[1:]:
        m = re.match(r"\s*\['([A-Za-z0-9_]+)'\]\s*=\s*\{\s*base\s*=\s*(.+?),"
                     r"\s*bonus\s*=\s*\{(.*)\}\s*\},?\s*$", line)
        if not m:
            continue
        base = None if m.group(2) == "nil" else m.group(2).strip("'")
        out[m.group(1)] = (base, re.findall(r"\['([A-Za-z0-9_]+)'\]", m.group(3)))
    return out


class SelfTest(unittest.TestCase):
    def test_parser_self_test_passes(self):
        # Read the process's OWN exit code (subprocess, not a pipe into a
        # reader whose success would be reported instead -- evidence
        # discipline 3, the reason routine_selfcheck.sh now refuses a pipe).
        proc = subprocess.run(
            [sys.executable, "tools/agent/aoe_radius_source_census.py", "--self-test"],
            cwd=REPO, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("SELFTEST ok", proc.stdout)


class SnapshotIsBlindToTheQuestion(unittest.TestCase):
    """Leg (2): the frozen snapshot cannot answer question (1), by construction.

    This is the ratchet that stops the census's conclusion from being
    "confirmed" later by a grep that could only ever come back empty.
    """

    def test_top_level_whitelist_carries_no_aoe_field(self):
        aoeish = [n for n in KEYS.TOP_LEVEL
                  if "aoe" in n.lower() or "radius" in n.lower()]
        self.assertEqual(aoeish, [], (
            "special_value_key_census.TOP_LEVEL now whitelists %s. The snapshot "
            "can carry an AoE field from here on, so re-run "
            "tools/agent/aoe_radius_source_census.py: leg (1) of the GH #502 "
            "ruling was measured on a KV that had no such field at all." % aoeish))

    def test_snapshot_absence_is_not_evidence(self):
        with open(SNAPSHOT, encoding="utf-8") as fh:
            src = fh.read()
        # Both halves matter: the name is absent AND the parser would have
        # dropped it. Asserting only the first would BE the mistake this
        # test exists to prevent.
        self.assertNotIn("AbilityAOERadius", src)
        self.assertNotIn("AbilityAOERadius", KEYS.TOP_LEVEL)


class FallbackRuleOnTheCallSites(unittest.TestCase):
    """Leg (3), frozen: the call sites and what each rule offers them."""

    def test_seven_call_sites_and_their_handles(self):
        sites = C.call_sites()
        self.assertEqual(len(sites), 7, (
            "GetAOERadius call sites under bots/: expected 7, got %d. "
            "tests/test_cm_ult_reach_meter_domain.lua section 5 counts the same "
            "seven; if the tree really changed, both move together." % len(sites)))
        resolved = sorted({a for _, _, _, a in sites if a})
        self.assertEqual(resolved, [
            "crystal_maiden_freezing_field",
            "drow_ranger_wave_of_silence",
            "muerta_the_calling",
            "sniper_shrapnel",
        ], resolved)
        # The stolen handle stays UNRESOLVED, and that is the honest answer --
        # a census that "resolved" it would be claiming to know which ability
        # Rubick holds.
        unresolved = [(f, h) for f, _, h, a in sites if a is None]
        self.assertEqual(unresolved, [("bots/FunLib/rubick_utility.lua", "ability")])

    def test_freezing_field_name_rule_picks_810_out_of_three_flagged_keys(self):
        block = snapshot_block(CM_ULT)
        named = sorted(k for k in block if k == C.NAMED)
        flagged = sorted(k for k, (_b, bonus) in block.items() if C.AOE_FLAG in bonus)
        self.assertEqual(named, ["radius"])
        self.assertEqual(flagged, ["explosion_max_dist", "explosion_radius", "radius"], (
            "the flag rule's candidate set on CM's ultimate moved. The GH #502 "
            "ruling rests on it offering MORE THAN ONE key here, which is what "
            "makes picking `radius` a choice rather than a read."))
        self.assertEqual(block["radius"][0], "810")
        # The two other flagged keys are real, different quantities -- pinned so
        # nobody reads the three as three names for one number.
        self.assertEqual(block["explosion_radius"][0], "320")
        self.assertEqual(block["explosion_max_dist"][0], "785")

    def test_two_call_sites_have_no_key_named_radius_at_all(self):
        """The name rule does not merely mis-pick on those two -- it is empty.

        Both `drow_ranger_wave_of_silence` and `muerta_the_calling` are read
        through `GetAOERadius()` by shipped code and neither declares a key
        named `radius`. This is why the census reports the two rules
        separately: merged, the flag rule's `wave_width` would print as one
        clean candidate for a call site the name rule cannot serve at all --
        and `wave_width` is a WIDTH.
        """
        # Frozen, off the census's own fixture rather than the network: the KV
        # shapes these two abilities have are what the fixture's `flag_only`
        # and multi-candidate cases model.
        shapes = C.SHAPES.parse_shapes(C.SELF_TEST_KV)
        named, flagged = C.candidates_split(shapes["flag_only"])
        self.assertEqual(named, [])
        self.assertEqual(flagged, ["wave_width"])


if __name__ == "__main__":
    unittest.main()
