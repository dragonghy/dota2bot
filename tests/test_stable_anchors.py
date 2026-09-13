#!/usr/bin/env python3
"""tools/agent/stable_anchors.py -- the three invariants, and the registry itself.

WHY: the tool exists because a wrong criterion never raises its hand (the
director asked `git tag -l` for ten rounds and got "not done" every time, while
both refs sat on origin).  A test that only ran the happy path would be the same
shape one level up, so each of the three invariants is asserted in BOTH
directions -- ok and the failure it is supposed to catch -- and the registry is
checked against the repo's own git history rather than against itself.
"""

import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import stable_anchors as sa  # noqa: E402

failures = []


def check(label, cond, detail=""):
    if not cond:
        failures.append("%s%s" % (label, (" -- " + detail) if detail else ""))


A = "a" * 40
B = "b" * 40


def anchor(ref_sha=A, promote=None, ref="refs/heads/stable-vX"):
    return {
        "name": "stable-vX",
        "ref": ref,
        "ref_sha": ref_sha,
        # promote == ref_sha keeps invariant 3 trivial, so the EXISTS/PINNED
        # assertions below never touch git objects (they must pass in a shallow
        # container too).
        "promote_commit": promote if promote is not None else ref_sha,
        "promoted_ids": ["fakeid"],
        "promoted_at": "2026-01-01T00:00:00Z",
    }


# ---- invariant 1: EXISTS -------------------------------------------------
code, lines = sa.check(anchor(), {"refs/heads/stable-vX": A})
check("EXISTS ok should be exit 0", code == 0, "got %d" % code)
check("EXISTS ok should print ok", any("EXISTS   ok" in ln for ln in lines))

code, lines = sa.check(anchor(), {"refs/heads/other": A})
check("missing ref must be a finding", code == 3, "got %d" % code)
check("missing ref must say MISSING", any("MISSING" in ln for ln in lines))
check("missing ref must print a restore command",
      any("git push origin" in ln for ln in lines))

# ---- invariant 2: PINNED -------------------------------------------------
code, lines = sa.check(anchor(), {"refs/heads/stable-vX": B})
check("moved ref must be a finding", code == 3, "got %d" % code)
check("moved ref must say MOVED", any("MOVED" in ln for ln in lines))
check("moved ref must show both shas",
      any(A[:12] in ln and B[:12] in ln for ln in lines))

# ---- invariant 3: SHIPPED, and the shallow-clone refusal -----------------
code, lines = sa.check(anchor(), {"refs/heads/stable-vX": A})
check("promote==ref must be trivially identical",
      any("trivially identical" in ln for ln in lines))

# Two fake shas that are certainly not objects in this repo => the tool must
# REFUSE (exit 2), never report ok.  This is the discipline that separates
# "checked and fine" from "could not check".
code, lines = sa.check(anchor(ref_sha=A, promote=B), {"refs/heads/stable-vX": A})
check("absent objects must be uncertifiable, not ok", code == 2, "got %d" % code)
check("uncertifiable must say so", any("UNCERTIFIABLE" in ln for ln in lines))
check("uncertifiable must say how to buy it",
      any("--deepen" in ln for ln in lines))

# ---- no remote at all ----------------------------------------------------
code, lines = sa.check(anchor(), None)
check("no remote must be uncertifiable", code == 2, "got %d" % code)

# ---- the registry itself -------------------------------------------------
with open(os.path.join(REPO, "iterations", "stable_anchors.json"), encoding="utf-8") as fh:
    registry = json.load(fh)

anchors = registry.get("anchors", [])
check("registry must not be empty", len(anchors) >= 2, "got %d" % len(anchors))

names = [a["name"] for a in anchors]
check("registry must be in stable-vN order", names == sorted(names), str(names))
check("registry names must be unique", len(set(names)) == len(names), str(names))

for a in anchors:
    for field in ("name", "ref", "ref_sha", "promote_commit", "promoted_ids",
                  "state_json_key"):
        check("%s missing field %s" % (a.get("name", "?"), field), field in a)
    check("%s ref_sha must be a full sha" % a["name"], len(a["ref_sha"]) == 40)
    check("%s promote_commit must be a full sha" % a["name"],
          len(a["promote_commit"]) == 40)
    check("%s ref must live under refs/" % a["name"], a["ref"].startswith("refs/"))

# Every anchor must name a promote record that actually exists in state.json --
# otherwise the registry could drift into describing a promote nobody made.
#
# state_json_key is a STRING or a LIST OF STRINGS, and the list form is the fix
# for a real red rather than a convenience.  A promote round can land TWO
# independent state records (2026-09-06 promoted odbuild and illumove, one key
# each), and the stable-v4 row wrote them as the single string
# "odbuild_PROMOTE_20260906 + illumove_PROMOTE_20260906".  That is not a key, so
# this check went red -- correctly, and a round late, because nothing at write
# time asked what shape the field had.  Joining two keys with " + " reads fine to
# a human and is unresolvable to every reader; the list makes the plural case
# expressible, and the per-element lookup below keeps the join red.
with open(os.path.join(REPO, "iterations", "state.json"), encoding="utf-8") as fh:
    state = json.load(fh)


def key_list(value):
    """The keys an anchor names, as a list. Anything else stays empty => red."""
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and value and all(isinstance(v, str) for v in value):
        return list(value)
    return []


for a in anchors:
    keys = key_list(a["state_json_key"])
    check("%s: state_json_key must be a string or a non-empty list of strings, "
          "got %r" % (a["name"], a["state_json_key"]), bool(keys))
    for k in keys:
        check("%s: state_json_key %s not in state.json" % (a["name"], k),
              k in state)

# Both directions of the shape rule, on synthetic input -- the registry itself is
# clean, so without these the branch that decides what counts as a key is never
# walked.
check("a plain key is accepted", key_list("roamstale_PROMOTED_20260819T2300Z") ==
      ["roamstale_PROMOTED_20260819T2300Z"])
check("two keys as a list are accepted", key_list(["a", "b"]) == ["a", "b"])
check("the ' + ' join is NOT a key list", key_list("a + b") == ["a + b"],
      "it must stay a single unresolvable key so the lookup below reds it")
check("an empty list is not a key list", key_list([]) == [])
check("a list of non-strings is not a key list", key_list([1, 2]) == [])


def rev_parse(sha):
    proc = subprocess.run(["git", "cat-file", "-e", sha + "^{commit}"],
                          cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.returncode == 0


# Ancestry is asserted only when the objects are present.  A shallow container
# must not fail this test -- but it must not silently pass the assertion either,
# so the skip is counted and printed.
skipped = 0
for a in anchors:
    if not (rev_parse(a["promote_commit"]) and rev_parse(a["ref_sha"])):
        skipped += 1
        continue
    proc = subprocess.run(
        ["git", "merge-base", "--is-ancestor", a["promote_commit"], a["ref_sha"]],
        cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    check("%s: promote_commit must be an ancestor of ref_sha" % a["name"],
          proc.returncode == 0)

# ---------------------------------------------------------------------------
# coverage -- every promote in the SOURCE must be covered by a registered
# anchor.  This section runs the registry backwards, and that direction is the
# whole point of it.
#
# WHY IT EXISTS (2026-09-13, director).  Everything above this line reads
# `stable_anchors.json` first and then asks whether each row is healthy.  A
# promote whose row was **never written** is therefore invisible: it is not a
# row, so nothing checks it, so the tool prints ok.  `stable_anchors.json`'s own
# `_doc` says "漏登记不会自己举手 -- 加那一行就是让它会", but adding a row only
# makes THAT anchor checked; it does nothing for the next one somebody forgets.
#
# It was not hypothetical.  `zusult` + `zusboltdom` were promoted 2026-09-11
# (gate deleted in bots/BotLib/hero_zuus.lua, machine key
# state.json:zusult_zusboltdom_PROMOTE_20260911) and went two days and a dozen
# routine triggers with no row and no ref, through a week in which the director
# registered four other anchors correctly.  Nothing was red.  The miss was found
# by hand while counting promotes for a weekly ledger -- i.e. by luck.
#
# So the assertion starts from the tree that actually ships: each
# `PROMOTED ... (was soak-candidate '<id>')` note under bots/ + game/ marks a
# gate that a promote deleted, and every such id must be either covered by an
# anchor or on the frozen pre-registry list below.
SRC_DIRS = ("bots", "game")

# TWO spellings, and the second one is why this is a list rather than one regex.
# The first draft of this section matched only `was soak-candidate '<id>'` and
# reported a clean 23/23 partition -- while silently missing two promoted ids:
# `pushguard` is annotated `was soak candidate 'pushguard'` (NO HYPHEN, three
# files) and `tpsafe2`'s note carried no id-bearing clause at all until this
# round added one.  The scan said "every promote in the source" and meant "every
# promote spelled the way I happened to grep for".
#
# That is the 2026-09-13T04:3xZ finding turned on its author: *a ratchet
# narrower than the defect it names reads exactly like a ratchet that is
# holding* -- it prints ok every round, and ok means "none where I can see".
# It was caught only because the AGENTS.md reconciliation below was added as an
# independent second source; the regex alone could never have reported its own
# blind spot.
PROMOTE_NOTES = (
    re.compile(r"was soak[- ]candidate '([a-z0-9_]+)'"),
    re.compile(r"PROMOTED \(was '([a-z0-9_]+)'\)"),
)

# Promoted before the anchor registry existed (stable-v1, 2026-08-19).  There is
# no anchor for these and there never will be -- inventing one would mean
# inventing a ref_sha for a tree state nobody recorded.  FROZEN: this list must
# never grow.  A new promote goes in `stable_anchors.json`, not here, and the
# count below is asserted so that appending to it cannot pass review unseen.
PRE_REGISTRY = frozenset([
    "deathzone", "fight", "lanesurv", "nodive", "punish", "pushguard",
    "regroup", "skyburst", "tphome", "tpsafe", "tpsafe2", "vsafe",
])
check("the pre-registry allowlist is frozen at 12 ids", len(PRE_REGISTRY) == 12,
      "got %d -- a new promote belongs in stable_anchors.json, not on this list"
      % len(PRE_REGISTRY))


def promoted_in_source():
    found = {}
    for top in SRC_DIRS:
        for root, _dirs, files in os.walk(os.path.join(REPO, top)):
            for fn in files:
                if not fn.endswith(".lua"):
                    continue
                path = os.path.join(root, fn)
                with open(path, encoding="utf-8", errors="replace") as fh:
                    text = fh.read()
                for pat in PROMOTE_NOTES:
                    for pid in pat.findall(text):
                        found.setdefault(pid, os.path.relpath(path, REPO))
    return found


source_ids = promoted_in_source()
# A corpus that came back empty would make every assertion below vacuously true,
# which is the failure mode this whole section is about.  Refuse it.
check("the source scan must find promote notes at all", len(source_ids) >= 20,
      "found %d -- an empty scan passes coverage vacuously" % len(source_ids))

# The independent second source.  AGENTS.md keeps a hand-maintained list of the
# promoted turbo defaults, written by people, in a file nobody edits to make a
# test pass.  Every id it names must be visible to the scan above.
#
# This is the assertion that catches a blind spot in the SCAN ITSELF, which no
# amount of care inside the regex can do: a pattern cannot report the promote it
# does not match.  It is deliberately one-directional -- AGENTS.md's list must
# be a subset of the scan, not equal to it -- because the prose is allowed to
# lag a fresh promote, while the scan missing a documented one is a defect.
AGENTS_MD = os.path.join(REPO, "AGENTS.md")
with open(AGENTS_MD, encoding="utf-8", errors="replace") as fh:
    agents_text = fh.read()
#
# The capture stops at the first "(" after the list, and that bound is load-
# bearing rather than tidy: the paragraph continues past the ids into a caveat
# sentence naming `nodive2` and `ownhalf` as the extensions that STAY GATED.  A
# capture that ran to the blank line swallowed those two and reported them as
# missing promotes -- i.e. the reconciliation's first run failed on its own
# parsing, not on the tree.  A list-scraper that also scrapes the sentence
# explaining what is NOT on the list is worse than no scraper: it manufactures
# findings, and findings that are always wrong get ignored, including the real
# one underneath them.
m = re.search(r"\*\*Promoted turbo defaults[^*]*\*\*\s*(.*?)\(", agents_text, re.S)
check("AGENTS.md must still carry a 'Promoted turbo defaults' list", m is not None,
      "the reconciliation below is vacuous without it")
if m:
    documented = set(re.findall(r"`([a-z0-9_]+)`", m.group(1)))
    # 15 ids as of 2026-09-13.  The floor is asserted, not the exact count: a
    # new promote legitimately grows this list, while a reworded header that
    # silently shrinks the capture is the failure this section cannot survive.
    check("the documented promote list must not have shrunk", len(documented) >= 15,
          "got %d (%s) -- a vacuous reconciliation is the thing this guards "
          "against; check the AGENTS.md wording the capture depends on"
          % (len(documented), ", ".join(sorted(documented))))
    for pid in sorted(documented):
        check("%s: AGENTS.md calls it a promoted turbo default, but the source "
              "scan does not see it" % pid, pid in source_ids,
              "either the promote note is missing/spelled differently in "
              "bots/, or PROMOTE_NOTES needs the spelling")

anchored_ids = set()
for a in anchors:
    for pid in a.get("promoted_ids", []):
        check("promoted id %r is claimed by two anchors" % pid,
              pid not in anchored_ids)
        anchored_ids.add(pid)

for pid, where in sorted(source_ids.items()):
    check("%s: promoted in %s but no anchor row and not pre-registry" % (pid, where),
          pid in anchored_ids or pid in PRE_REGISTRY,
          "add a row to iterations/stable_anchors.json")

# The other direction: an anchor may not claim a promote the tree does not have.
# This is what catches a promote that was reverted, or a row typed from a report
# rather than from the source.
for pid in sorted(anchored_ids):
    check("%s: an anchor claims this promote but bots/+game/ has no "
          "\"was soak-candidate '%s'\" note" % (pid, pid),
          pid in source_ids)

# The pre-registry list is an exemption, not a parking lot: each member must
# still be a live promote in the tree, so a stale id cannot sit here covering
# for nothing.
for pid in sorted(PRE_REGISTRY):
    check("%s: on the pre-registry list but not promoted in the tree" % pid,
          pid in source_ids)
    check("%s: on the pre-registry list AND anchored -- pick one" % pid,
          pid not in anchored_ids)

if failures:
    print("FAIL (%d):" % len(failures))
    for f in failures:
        print("  " + f)
    sys.exit(1)

print("ok -- %d anchors, %d promoted id(s) in source (%d anchored, %d pre-registry), "
      "%d ancestry assertion(s) skipped (objects below graft point)"
      % (len(anchors), len(source_ids), len(anchored_ids), len(PRE_REGISTRY), skipped))
