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
with open(os.path.join(REPO, "iterations", "state.json"), encoding="utf-8") as fh:
    state = json.load(fh)
for a in anchors:
    check("%s: state_json_key %s not in state.json" % (a["name"], a["state_json_key"]),
          a["state_json_key"] in state)


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

if failures:
    print("FAIL (%d):" % len(failures))
    for f in failures:
        print("  " + f)
    sys.exit(1)

print("ok -- %d anchors, %d ancestry assertion(s) skipped (objects below graft point)"
      % (len(anchors), skipped))
