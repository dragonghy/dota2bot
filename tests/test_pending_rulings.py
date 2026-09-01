#!/usr/bin/env python3
"""[ratchet] The three invariants behind test_set.md §BB.4 / §BA.4 / §CG.5.

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

INVARIANT 3 (§CG.5, added 2026-08-29 by the director).  The orphan leg must
fire on ITS OWN FOUNDING CASE.  `fieldsip` was proposed in `test_set.md` §CE
at 10:xxZ with no `queue.json` row, and this tool printed `none` for three
consecutive rounds while the proposal sat un-ruled for eight hours.  The
regression row below rebuilds exactly that state -- section present, no row,
not in the member string, and a `state.json` entry that the PROPOSING stream
wrote -- and requires an ORPHAN_PROPOSAL out of it.  The last clause is the
load-bearing one: keying "already ruled" off the mere existence of a
`state.json` entry passes every other test in this file and is silent on the
one case the leg exists for.

What invariant 3 does NOT assert: that the real tree currently has zero
orphans.  An un-ruled proposal is a transient the director clears in-round,
and reddening every stream's test run over the director's inbox would create
pressure to weaken the tool.  The exit-3 selfcheck leg is what reports that.
What IS pinned on the real tree is parser health -- every proposal heading
still yields an id -- because a parser that silently stops matching would
turn this leg back into the `none` it was built to stop printing.

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

# GH #317 (director ruling 2026-08-30, 甲 variant): a status outside the
# vocabulary counts as OPEN, not closed.  The old rule (`status in
# OPEN_STATES`) answered False for every unrecognised spelling, which took the
# row out of BOTH buckets -- `hero-20` sat unseen for two days that way.
for st in ("routed", "harvested_pending_verification",
           "returned_uninterpretable", "totally_made_up"):
    check(pr.is_open({"status": st}),
          "GH #317: drifted status %s read as closed" % st)
check(pr.is_open({"id": "x"}), "GH #317: a row with no status read as closed")
# The point of the ruling is visibility, so assert the end state, not just the
# predicate: a drifted-status un-ruled row must REACH a bucket.
drifted = {"id": "hero-20", "status": "routed", "question": "archive scan"}
ride, other = pr.partition([drifted])
check(drifted in ride + other,
      "GH #317: a drifted-status un-ruled row still reaches neither bucket")
# ...and a genuinely closed row must not, or the ruling would flood the buckets.
check(pr.partition([{"id": "y", "status": "done"}]) == ([], []),
      "GH #317: a closed row leaked into a bucket")

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

# ---------------------------------------------------------------- invariant 3
# Parser health on the real archive.  Every §XX section that declares itself an
# admission proposal must still yield an id; a heading form that stops matching
# is how this leg would quietly become the `none` it was built to stop printing.
ts_text = pr.read_test_set(TEST_SET)
real_proposals = pr.find_proposals(ts_text)
check(len(real_proposals) >= 7,
      "proposal-heading parser found %d sections, fewer than the 7 on record"
      % len(real_proposals))
check(all(cand for _s, cand, _h in real_proposals),
      "a real proposal heading yielded no id: %r"
      % [s for s, cand, _h in real_proposals if not cand])
check({s for s, _c, _h in real_proposals} >= {"BK", "BR", "BT", "BV", "CC", "CD", "CE"},
      "a known proposal section stopped being recognised")
by_section = {s: cand for s, cand, _h in real_proposals}
check(by_section.get("BK") == "abilanc", "§BK's proposal id read wrong")
check(by_section.get("BR") == "aimguard", "§BR's proposal id read wrong")
check(by_section.get("CE") == "fieldsip", "§CE's proposal id read wrong")

# The id must come from the POSITION AFTER THE MARKER, not from "first backtick
# in the line".  Measured 2026-08-29: on all seven archived headings the two
# rules agree -- §BK backticks the contrast id `campdanger` and §BR the
# withdrawn `abil1st`, but both do so AFTER the proposal.  So the real corpus
# cannot tell the rules apart, and the mutation that swaps them survives every
# check above.  This synthetic is the discriminator: a heading that names the
# withdrawn id first, which the archive is one edit away from containing.
lead_md = ("# t\naaa\n\n"
           "## §ZY 2026-01-01 协同组撤回对 `abil1st` 的建议,并提议入集:`aimguard`(GH #1)\n")
check([c for _s, c, _h in pr.find_proposals(lead_md)] == ["aimguard"],
      "a backticked id BEFORE the marker was parsed as the proposal")

# The member string reader must be positional (line 2), not a fuzzy search --
# the archive quotes historical member strings, and matching one of those would
# score every ejected id as still armed.
armed = pr.armed_ids(ts_text)
check(set(members) == armed, "armed_ids disagrees with the line-2 member string")
check("fieldsip" in armed, "fieldsip missing from the member string")
# There are 13 bare member-string lines in the file; 12 are historical strings
# quoted inside archive sections, the oldest 16 ids long.  A reader that lands
# on any of them scores every id admitted since as un-armed, which silences the
# orphan leg's resolution signal in exactly the direction that hides work.
stale_md = "# t\ncur1,cur2,cur3\n\ntext\nold1,old2\nmore text\n"
check(pr.armed_ids(stale_md) == {"cur1", "cur2", "cur3"},
      "armed_ids read a member string other than line 2")
check(pr.armed_ids("# t\n") == set(), "armed_ids invented ids from a file with no line 2")
check(pr.armed_ids("# t\nnot a member string, with spaces\n") == set(),
      "armed_ids parsed prose as a member string")

# Token equality, not substring: `stayfield` and `stayfield2` are both real ids.
rows = [{"id": "r1", "bundle": "stayfield2", "status": "pending"}]
check(pr.queue_rows_for("stayfield2", rows), "exact bundle token not matched")
check(not pr.queue_rows_for("stayfield", rows),
      "`stayfield` matched a `stayfield2` row -- substring match, not token match")
check(pr.queue_rows_for("b", [{"id": "r2", "bundle": "a, b, c"}]),
      "comma-separated bundle token not matched")
check(pr.queue_rows_for("x", [{"id": "r3", "bundle": "", "bundle_was": "x"}]),
      "bundle_was not consulted")

# ruled_in_state: a ruling key means ruled; an entry alone does NOT.
proposing_entry = {"e": {"id": "zz", "handoff": "director: rule on admission"}}
check(not pr.ruled_in_state("zz", proposing_entry),
      "a bare state.json entry read as a ruling -- this is the founding case's shape")
check(pr.ruled_in_state("zz", {"e": {"id": "zz", "director_ruling": "APPROVED"}}),
      "director_ruling not read as a ruling")
check(pr.ruled_in_state("zz", {"e": {"id": "zz", "director_ruling_20260829": "EJECTED"}}),
      "a dated re-ruling key not read as a ruling")
check(not pr.ruled_in_state("zz", {"e": {"id": "zz", "director_ruling": "  "}}),
      "a blank ruling value read as a ruling")

# THE FOUNDING CASE, rebuilt.  §CE present, no queue row, not armed, and a
# state.json entry written by the proposing stream.
FOUNDING_MD = (
    "# test set\n"
    "aaa,bbb,ccc\n"
    "\n"
    "## §CE 2026-08-29T10:xxZ 协同组提议入集:`fieldsip`(owner P2 的第一根杠杆)\n"
)
founding_state = {"fieldsip_20260829": {"id": "fieldsip",
                                        "handoff": "director: rule on admission"}}
orph, rowless, unparsed = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), [], pr.armed_ids(FOUNDING_MD), founding_state)
check([(s, c) for s, c, _r, _rows in orph] == [("CE", "fieldsip")],
      "the founding case did not produce an ORPHAN_PROPOSAL: %r" % (orph,))
check(not rowless and not unparsed, "the founding case leaked into another bucket")

# ...and each resolution signal alone must silence it, because neither is
# universal: `aimguard` was admitted with no ruling key, `campexit` was ejected
# and so is not in the member string.
armed_md = FOUNDING_MD.replace("aaa,bbb,ccc", "aaa,bbb,fieldsip")
orph2, rowless2, _u = pr.classify_proposals(
    pr.find_proposals(armed_md), [], pr.armed_ids(armed_md), founding_state)
check(not orph2 and len(rowless2) == 1,
      "admission into the member string did not silence the orphan leg")
ruled_state = {"fieldsip_20260829": {"id": "fieldsip", "director_ruling": "EJECTED"}}
orph3, rowless3, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), [], pr.armed_ids(FOUNDING_MD), ruled_state)
check(not orph3 and len(rowless3) == 1,
      "a delivered director_ruling did not silence the orphan leg")

# A row exists but is closed: a ruling has nowhere to land, so it is an orphan.
closed_row = [{"id": "q1", "bundle": "fieldsip", "status": "done"}]
orph4, _rl, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), closed_row, set(), founding_state)
check(len(orph4) == 1 and "closed" in orph4[0][2],
      "an unruled proposal whose only row is closed was scored as covered")
open_row = [{"id": "q1", "bundle": "fieldsip", "status": "pending"}]
orph5, _rl, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), open_row, set(), founding_state)
check(not orph5, "an open row did not cover the proposal")

# ---------------------------------------------------------------- GH #376
# A rideshare row has an EMPTY `bundle` by definition (it asks for no wave), so
# the link key the orphan leg reads is blank on every correctly-filed one.  The
# leg must then say "there is a row and nothing links it", not "there is no
# row" -- the second sentence's instruction is `open a queue request row`, and
# following it produces a SECOND row for one proposal.  Measured 2026-09-01:
# strategy-27 (`roamidle`) and strategy-28 (`outlatch`) were both filed by the
# proposing stream, per §CG.5, and both were reported as `no queue request row
# at all`.  A false positive that CREATES the defect it reports if obeyed.
unlinked = [{"id": "strategy-27", "bundle": "", "status": "pending",
             "question": "`fieldsip` (GH #370, proposal §CE): the callee orders."}]
orph6, _rl, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), unlinked, set(), founding_state)
check(len(orph6) == 1, "an unlinked row left the orphan bucket (it must stay a "
                       "finding -- only the instruction changes): %r" % (orph6,))
# Read through a default rather than orph6[0] directly: when the bucket is
# empty, the interesting output is the named check above, and an IndexError
# here would kill the run before the FAIL summary ever prints.
reason6, rows6 = (orph6[0][2], orph6[0][3]) if orph6 else ("", [])
check("no queue request row at all" not in reason6,
      "a row that exists was reported as no row at all: %r" % (reason6,))
check("LINKS" in reason6 and "bundle" in reason6,
      "the unlinked finding does not name the link field: %r" % (reason6,))
check(rows6 == ["strategy-27"],
      "the unlinked finding did not name the candidate row: %r" % (rows6,))
# (It stays a finding: the end-to-end exit-code check for this shape is at the
# bottom of this file, where subprocess is imported.  Severity is unchanged --
# an unlinked request has not reached the machine-read field either -- and if
# it ever went quiet, the fix would have retired the leg it was fixing.)
# A real orphan -- nothing anywhere -- must still say so, or the new branch has
# swallowed the founding case.
orph7, _rl, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), [], set(), founding_state)
check(orph7[0][2] == "no queue request row at all",
      "the true-orphan wording was lost: %r" % (orph7[0][2],))
# Whole-token in prose too: `stayfield` must not answer for `stayfield2`.
check(pr.rows_naming_in_prose(
    "fieldsip", [{"id": "q", "status": "pending", "axis": "fieldsip2 rides"}]) == [],
    "a prose substring matched -- token equality is not enforced in prose")
check(pr.rows_naming_in_prose(
    "fieldsip", [{"id": "q", "status": "pending", "axis": "FIELDSIP -- `fieldsip` rides"}]),
    "a prose mention in `axis` was not seen")
# Only OPEN rows are candidates: a closed row cannot carry a ruling, so pointing
# at one is the same bad instruction by another route.
check(pr.rows_naming_in_prose(
    "fieldsip", [{"id": "q", "status": "done", "question": "`fieldsip` rides"}]) == [],
    "a closed row was offered as a link candidate")
closed_prose = [{"id": "q", "bundle": "", "status": "done",
                 "question": "`fieldsip` rides"}]
orph8, _rl, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), closed_prose, set(), founding_state)
check(orph8[0][2] == "no queue request row at all",
      "a closed prose-only row was treated as a link candidate: %r" % (orph8[0][2],))
# The link field itself is never a prose field: if it were, this function could
# never report the case it exists for.
check(pr.rows_naming_in_prose(
    "fieldsip", [{"id": "q", "status": "pending", "bundle": "fieldsip"}]) == [],
    "`bundle` was read as prose -- the two readings must stay separate")

# LIMIT 6: a heading whose id cannot be read is reported, never dropped.
bad_md = "# t\naaa,bbb\n\n## §ZZ 2026-01-01 协同组提议入集:那个新杠杆\n"
_o, _rl, unp = pr.classify_proposals(
    pr.find_proposals(bad_md), [], pr.armed_ids(bad_md), {})
check([s for s, _h in unp] == ["ZZ"], "an unreadable proposal heading was dropped")

# A ruling section must not be mistaken for a proposal section.
ruling_md = "# t\naaa\n\n## §CG 2026-08-29T18:5xZ 总监裁定:`fieldsip`(§CE)**入集**\n"
check(pr.find_proposals(ruling_md) == [],
      "a 总监裁定 section was parsed as an admission proposal")

# LIMIT 7: statuses outside the vocabulary now COUNT AS OPEN (GH #317), but
# must still be NAMED -- the ruling fixes what the drift costs, it does not
# stop the drift, and a silent auto-accept would retire the only signal that
# says the vocabulary moved.  Measured on the real queue: `routed`,
# `harvested_pending_verification` and `returned_uninterpretable` are in use.
check(pr.unknown_status_rows([{"id": "a", "status": "routed"}]),
      "an out-of-vocabulary status was not reported")
check(not pr.unknown_status_rows([{"id": "a", "status": "pending"}]),
      "a known status was reported as unknown")

# The exit contract, end to end.  An orphan must redden the process, not just
# print a line -- the selfcheck leg reads the exit code, and a finding that
# only exists in stdout is the `SKIP is not a pass` shape (GH #171).
import subprocess  # noqa: E402
import tempfile  # noqa: E402

tmp = tempfile.mkdtemp()
paths = {}
for name, blob in (("queue.json", {"requests": []}),
                   ("state.json", founding_state)):
    paths[name] = os.path.join(tmp, name)
    with open(paths[name], "w", encoding="utf-8") as fh:
        json.dump(blob, fh)
paths["md"] = os.path.join(tmp, "test_set.md")
with open(paths["md"], "w", encoding="utf-8") as fh:
    fh.write(FOUNDING_MD)
run = subprocess.run(
    [sys.executable, os.path.join(REPO, "tools", "agent", "pending_rulings.py"),
     "--no-age", "--queue", paths["queue.json"], "--test-set", paths["md"],
     "--state", paths["state.json"]],
    capture_output=True, text=True)
check(run.returncode == 3,
      "an orphan proposal did not redden the exit code (got %d)" % run.returncode)
check("ORPHAN_PROPOSAL" in run.stdout and "fieldsip" in run.stdout,
      "the orphan was not named on stdout")
# ...and an unreadable test_set.md is UNCERTIFIABLE (exit 2), never a clean 0.
run2 = subprocess.run(
    [sys.executable, os.path.join(REPO, "tools", "agent", "pending_rulings.py"),
     "--no-age", "--queue", paths["queue.json"],
     "--test-set", os.path.join(tmp, "no-such-file.md"), "--state", paths["state.json"]],
    capture_output=True, text=True)
check(run2.returncode == 2, "a missing test_set.md exited %d, not 2" % run2.returncode)
check("UNCERTIFIABLE" in run2.stdout, "a leg that could not run did not say so")

# GH #376 end to end: the unlinked-row shape is still exit 3, still an
# ORPHAN_PROPOSAL, and names the row rather than telling anyone to open one.
unlinked_queue = os.path.join(tmp, "queue_unlinked.json")
with open(unlinked_queue, "w", encoding="utf-8") as fh:
    json.dump({"requests": [{"id": "strategy-27", "stream": "strategy", "bundle": "",
                             "status": "pending", "priority": 3,
                             "question": "`fieldsip` (GH #370) rides along.",
                             "director": {"ruling": "ROUTED", "wave": "any", "at": "x",
                                          "ref": "y"}}]}, fh)
run3 = subprocess.run(
    [sys.executable, os.path.join(REPO, "tools", "agent", "pending_rulings.py"),
     "--no-age", "--queue", unlinked_queue, "--test-set", paths["md"],
     "--state", paths["state.json"]],
    capture_output=True, text=True)
check(run3.returncode == 3,
      "an unlinked row stopped reddening the exit code (got %d)" % run3.returncode)
check("no queue request row at all" not in run3.stdout,
      "end to end, an existing row was still reported as no row at all")
check("strategy-27" in run3.stdout.split("orphan admission proposals")[-1],
      "end to end, the candidate row was not named in the orphan block")

print("%d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
