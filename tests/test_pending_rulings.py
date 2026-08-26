#!/usr/bin/env python3
"""[ratchet] The two invariants behind test_set.md §BB.4 / §BA.4.

INVARIANT 1 (the ratchet that matters).  Every id in `test_set.md`'s member
string that HAS a queue request must have a **delivered** ruling -- a
non-empty `director` field on that request.  §BA.4's founding case was a
ruling that existed in prose and in the archive but not in the field the
batch desk reads, so the desk's conservative default ran opposite to it.
An id that is ARMED while its request carries no ruling is that same shape,
one step further along: the wave is already spending money on it.

INVARIANT 2.  `tools/agent/pending_rulings.py` partitions correctly.  A
guard that silently drops a bucket is worse than no guard, so the partition
is asserted exhaustive and disjoint on both synthetic input and the real
queue.

Run: python3 tests/test_pending_rulings.py
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import pending_rulings as pr  # noqa: E402

QUEUE = os.path.join(REPO, "iterations", "queue.json")
TEST_SET = os.path.join(REPO, "iterations", "streams", "test_set.md")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


def member_string_ids(path=TEST_SET):
    """The armed member string is line 2 of test_set.md, comma separated.

    LIMIT: this is a positional read, deliberately.  The file's own header
    calls that line the member string, and a fuzzy search would happily
    match one of the historical strings quoted further down in the archive
    sections -- which is exactly the failure this test exists to prevent.
    """
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    line = lines[1].strip()
    assert line and "," in line and " " not in line, (
        "test_set.md line 2 is not a bare member string: %r" % line[:120])
    return [s for s in line.split(",") if s]


# ---------------------------------------------------------------- invariant 1
requests = pr.load_requests(QUEUE)
members = member_string_ids()

check(len(members) == len(set(members)), "member string has duplicate ids")
check(len(members) >= 29, "member string shrank below its 2026-08-24 size (29)")

# Scoped to OPEN requests, and the scope is a finding rather than a
# convenience: run unscoped, this check goes red on `pullcamp` via
# strategy-1/strategy-2, both `done`.  Those two predate the `director` field
# itself (added 2026-08-23T15:xxZ, §AW.1), so they are not undelivered
# rulings -- they are requests that closed before there was a field to
# deliver into.  A closed request also cannot misroute a wave: the batch desk
# selects on `director.wave` among OPEN requests.  Anything still open is
# live, and that is what this pins.
undelivered = []
for mid in members:
    for req in requests:
        bundle = [b.strip() for b in (req.get("bundle") or "").split(",") if b.strip()]
        if mid in bundle and pr.is_open(req) and pr.is_unruled(req):
            undelivered.append((mid, req.get("id"), req.get("status")))
check(not undelivered,
      "armed ids whose queue request carries no delivered ruling: %r" % (undelivered,))

# ---------------------------------------------------------------- invariant 2
ride, other = pr.partition(requests)
open_unruled = [r for r in requests if pr.is_open(r) and pr.is_unruled(r)]
ids = lambda bucket: {r["id"] for r in bucket}  # noqa: E731

check(ids(ride) | ids(other) == ids(open_unruled), "partition is not exhaustive")
check(not (ids(ride) & ids(other)), "partition buckets overlap")
check(all(not pr.is_unruled(r) or not pr.is_open(r)
          for r in requests if r["id"] not in ids(open_unruled)),
      "a request outside the buckets is both open and un-ruled")

# Emptiness shapes: absent field, null, {} and "" must all read as un-ruled,
# because §AW.1's whole point is that "no machine-readable ruling" is one
# state however it is spelled.
for empty in (None, {}, ""):
    check(pr.is_unruled({"id": "x", "director": empty}), "empty %r read as ruled" % (empty,))
check(pr.is_unruled({"id": "x"}), "absent director field read as ruled")
check(not pr.is_unruled({"id": "x", "director": {"ruling": "APPROVED_ADMITTED"}}),
      "a real ruling read as un-ruled")

# A SCAFFOLDED-BUT-BLANK dict is the shape that got past this tool (director
# 2026-08-26, GH #218's round): `strategy-18` carried
# {"ruling": "", "wave": "", "at": "", "ref": ""} -- written by the stream that
# filed the request, leaving the director's axis for the director -- and the old
# `in (None, {}, "")` test scored it as RULED, so the tool printed `none` on a
# queue that owed a §BB.4 rideshare ruling.  The old test asked whether the
# FIELD was empty; the question this tool is for is whether the RULING is.
for blank in ("", "   ", "\n", None):
    check(pr.is_unruled({"id": "x", "director": {"ruling": blank, "wave": "", "at": ""}}),
          "blank ruling %r inside a scaffolded dict read as ruled" % (blank,))
check(pr.is_unruled({"id": "x", "director": {"wave": "W9", "at": "2026-01-01"}}),
      "a director dict with no `ruling` key at all read as ruled")
# ...and the converse must still hold: a real ruling is not un-ruled just
# because its siblings are blank.  Without this row the fix could be "return
# True whenever any field is empty", which would flood the tool with noise.
check(not pr.is_unruled({"id": "x", "director": {"ruling": "REJECTED", "wave": "", "at": ""}}),
      "a real ruling with blank siblings read as un-ruled")

# Open states.  A harvested request still owes a resolve ruling -- that is
# backlog §12's case and the reason `harvested` is in the open set.
for st in ("pending", "running", "harvested"):
    check(pr.is_open({"status": st}), "%s not treated as open" % st)
for st in ("done", "rejected"):
    check(not pr.is_open({"status": st}), "%s treated as open" % st)

# Rideshare classification is a text match on the request's own declaration.
check(pr.is_rideshare({"question": "搭车,不申请专波,零 AWS 增量。"}), "zh rideshare missed")
check(pr.is_rideshare({"question": "NO NEW WAVE NEEDED -- archive scan"}), "en rideshare missed")
check(not pr.is_rideshare({"question": "请开一条独占波,4 台 4 种子。"}), "dedicated wave misread")
check(not pr.is_rideshare({}), "missing question field misread as rideshare")

# The exit contract: RIDESHARE non-empty => 3, and OTHER alone never reddens.
check(pr.partition([{"id": "a", "status": "done", "director": None}]) == ([], []),
      "a closed request leaked into the buckets")
synth = [{"id": "a", "status": "pending", "question": "搭车"},
         {"id": "b", "status": "pending", "question": "独占波"},
         {"id": "c", "status": "pending", "director": {"ruling": "APPROVED"},
          "question": "搭车"}]
sride, sother = pr.partition(synth)
check([r["id"] for r in sride] == ["a"], "synthetic rideshare bucket wrong")
check([r["id"] for r in sother] == ["b"], "synthetic other bucket wrong")

# first_seen must answer None rather than fabricate a date when the shallow
# clone cannot see the introducing commit (tool LIMIT 3).
check(pr.first_seen("no-such-request-id-xyzzy") is None,
      "first_seen invented an age for an id that was never in the file")

print("%d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
