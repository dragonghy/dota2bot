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

import hashlib
import json
import os
import re
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


def raw_member_line(path=TEST_SET):
    """Line 2 exactly as stored, so byte/md5 claims are checked on the real bytes."""
    with open(path, encoding="utf-8") as fh:
        return fh.read().splitlines()[1].strip()


def declared_member_record(path=TEST_SET):
    """Line 3's self-record of line 2 -> (count, bytes|None, md5|None), or None.

    Line 3 reads e.g. `**成员串 27**(上一行,**239 字节**,md5 `76a8...`)`.
    Count is required (it is what replaced the old size floor); the byte count
    and md5 are optional because older rounds did not always record them, and a
    missing one must not be reported as a MISMATCH -- absent and wrong are
    different findings, and conflating them is how a check earns a bump instead
    of a fix.  Scoped to line 3 on purpose: the archive further down the file
    quotes historical member strings with their own counts, and a fuzzy search
    would happily match one of those (the same reason member_string_ids reads
    positionally).
    """
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    if len(lines) < 3:
        return None
    line = lines[2]
    m_count = re.search(r"\*\*成员串\s*(\d+)\s*\*\*", line)
    if not m_count:
        return None
    m_bytes = re.search(r"\*\*(\d+)\s*字节\*\*", line)
    m_md5 = re.search(r"md5\s*`([0-9a-f]{32})`", line)
    return (int(m_count.group(1)),
            int(m_bytes.group(1)) if m_bytes else None,
            m_md5.group(1) if m_md5 else None)


# ---------------------------------------------------------------- invariant 1
requests = pr.load_requests(QUEUE)
members = member_string_ids()

check(len(members) == len(set(members)), "member string has duplicate ids")

# WAS `check(len(members) >= 29, ...)` -- a FLOOR written 2026-08-24, back when
# the armed set only ever grew.  Owner priority P4.2 (2026-09-05) inverted the
# direction: new ids are frozen out and the set must shrink to <= 20, and the
# director's output metric IS the set getting smaller.  The floor therefore
# asserted the opposite of the standing priority, and because it sat at exactly
# the then-current size it went red on the FIRST withdrawal that moved it
# (2026-09-12, outlatch + rotscope, 29 -> 27) and would have gone red on every
# P4.2 withdrawal after that.
#
# This is GH #106 / #127 / #538's family verbatim -- AN ASSERTION THAT WRITES A
# POPULATION SIZE AS A LITERAL -- and §7d's rule for that family is not "bump
# the literal", it is "assert the record's INTERNAL SELF-CONSISTENCY instead".
# Bumping 29 to 27 would buy one round and re-arm the same trap.
#
# What the floor was really guarding is line 2 being silently truncated or
# mangled by a bad edit.  Line 3 already declares the count, the byte length and
# the md5 of line 2 in prose, so checking line 2 AGAINST ITS OWN RECORD is a
# strictly stronger instrument than any floor: it catches truncation, it catches
# an edit that forgets to update the record, and it never goes stale.  It also
# turns three numbers that were decorative prose into checked values.
declared = declared_member_record()
check(declared is not None,
      "test_set.md line 3 no longer declares `**成员串 N**` -- the member "
      "string's self-record is what replaced the old size floor, so losing "
      "the record is itself the finding")
if declared is not None:
    d_count, d_bytes, d_md5 = declared
    check(len(members) == d_count,
          "member string holds %d ids but line 3 declares %d -- one of the two "
          "was edited without the other" % (len(members), d_count))
    line2 = raw_member_line()
    if d_bytes is not None:
        check(len(line2.encode("utf-8")) == d_bytes,
              "member string is %d bytes but line 3 declares %d"
              % (len(line2.encode("utf-8")), d_bytes))
    if d_md5 is not None:
        actual_md5 = hashlib.md5(line2.encode("utf-8")).hexdigest()
        check(actual_md5 == d_md5,
              "member string md5 is %s but line 3 declares %s"
              % (actual_md5, d_md5))

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

# On the REAL queue: nothing that declares itself a rideshare may be sitting in
# the OTHER bucket.  This is deliberately NOT written against DECLARATION_FIELDS
# -- it sweeps every string the requester wrote, minus the fields LIMIT 2
# excludes because they are somebody else's sentence about the request.  A
# field-list-shaped assertion would only ratchet on the list the fix happened
# to pick; this one still fires the day a stream invents a fourth prose field
# and writes 搭车 into it, and the repair is then to widen DECLARATION_FIELDS
# rather than to discover the miss by eye eight rounds later.
NOT_THE_REQUESTERS_PROSE = ("director", "result", "notes")


def declares_rideshare_anywhere(req):
    parts = []
    for key, value in req.items():
        if key in NOT_THE_REQUESTERS_PROSE:
            continue
        if isinstance(value, str):
            parts.append(value)
    text = " ".join(parts)
    return [m for m in pr.RIDESHARE_MARKERS if m in text]


_ride, _other = pr.partition(requests)
misfiled = [(r.get("id"), declares_rideshare_anywhere(r))
            for r in _other if declares_rideshare_anywhere(r)]
check(not misfiled,
      "rows in the OTHER bucket that declare a rideshare in their own prose -- "
      "§BB.4's 'rule it this round' cannot fire for these: %r" % (misfiled,))

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

# ...and the declaration is read WHEREVER the stream wrote it.  Every row above
# puts the phrase in `question`; that is exactly the assumption that made this
# leg answer `none` for eight rounds while self-declared rideshares sat in
# OTHER.  Measured on the real queue 2026-09-04: 59 rows declare a rideshare,
# 23 of them nowhere but `axis`/`acceptance`.  The two shapes below are those
# 23, in their two real spellings.
check(pr.is_rideshare({"axis": "soak candidate 'wkqdmg' 的条件 (a)。搭车、零 AWS 增量、"
                               "不申请专波 —— 任一带 skeleton_king 载体的波次即可。",
                       "question": "条件 (a) 取证。"}),
      "a declaration written into `axis` read as OTHER (hero-23's real shape)")
check(pr.is_rideshare({"question": "回城取货次数差。",
                       "acceptance": "**零 AWS 增量**:本条不申请专波,搭任意已排定波次顺路即可。"}),
      "a declaration written into `acceptance` read as OTHER (strategy-6's real shape)")

# The converse the widening must NOT break: a marker in somebody ELSE's field.
# `result` and `director` carry the batch desk's cost bookkeeping and the
# director's rulings, where "零 EC2" is a statement ABOUT the wave, not the
# requester's declaration.  Reading those would turn a dedicated-wave ask into
# a rideshare on the strength of a note written after it was scheduled --
# an over-inclusion that would arrive looking exactly like the fix.
check(not pr.is_rideshare({"question": "请开一条独占波,4 台 4 种子。",
                           "result": "批测的收尾核查:零 EC2 泄漏,实例已自毁。",
                           "director": {"ruling": "APPROVED -- 搭 W45"}}),
      "a marker in `result`/`director` (not the requester's prose) read as a "
      "rideshare declaration")

# End to end: the bucket, not just the predicate.  A `none` printed above a row
# that belongs in the bucket is the whole defect, so assert where the row LANDS.
axis_only = {"id": "hero-28", "status": "pending",
             "axis": "归档 .dem 扫描;**零 EC2、零新局、零 AWS 增量、不申请专波**。",
             "question": "新 gated 候选 `zusaether` 的条件 (a) 取证。"}
aride, aother = pr.partition([axis_only])
check([r["id"] for r in aride] == ["hero-28"],
      "an axis-only rideshare declaration did not reach the RIDESHARE bucket")
check(aother == [], "the same row also leaked into OTHER")

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

# ---- owner P4.3 (2026-09-06): the corpus above is now TWO files ----
# The split moved every ruling section out of `test_set.md`, and ALL 23
# proposal sections went with them.  The checks above pass only because
# `read_test_set` reads the archive as well.  Without this negative control
# they would keep passing for the wrong reason on the day someone "simplifies"
# that reader: `find_proposals` would see 0 sections and the orphan leg would
# print `ORPHAN_PROPOSAL: none` -- green because its INPUT vanished, which is
# the one way this tool must never go quiet.  Measured live before the split
# was committed: 23 proposals with the archive, 0 without.
live_only = pr.read_test_set(TEST_SET, archive="")
check(len(pr.find_proposals(live_only)) == 0,
      "the live file alone still carries proposal sections -- this control no "
      "longer discriminates, re-derive it before trusting the checks above")
check(len(real_proposals) == 23,
      "proposal sections scanned = %d, not the 23 the split measured"
      % len(real_proposals))
# ...and the concatenation must not disturb the POSITIONAL reader: the armed
# string is line 2 of the live file, and the archive is appended, never
# prepended.  A reader that landed on an archived historical member string
# would score every id admitted since as un-armed.
check(pr.armed_ids(ts_text) == pr.armed_ids(live_only),
      "appending the archive moved line 2 -- armed_ids now reads a different "
      "member string")

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

# ---- the THIRD resolution signal: PROMOTED (director 2026-09-07) ----------
# A promote extinguishes both older signals at once -- the id leaves the member
# string BECAUSE it was ruled, and the promote record is not a `director_ruling`
# key -- so without this the round that promotes an id converts its own proposal
# section into a permanent ORPHAN_PROPOSAL (exit 3, every round after).  Found
# live promoting `ckpush`; §DQ went orphan the moment the row closed.
orph5b, rowless5b, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), closed_row, set(), founding_state,
    promoted={"fieldsip"})
check(not orph5b,
      "a PROMOTED id with only closed rows was still scored as an orphan")
check(not rowless5b,
      "a promoted proposal that DOES have a row belongs in no bucket at all; "
      "`rowless` is for proposals with no row (it prints as 'ruled elsewhere')")
# ...and the boundary in the other direction: promoting SOMETHING ELSE must not
# silence anything.  (Default-empty is asserted too: the older call sites in
# this file pass no `promoted` at all and must keep their verdicts.)
orph5c, _rl, _u = pr.classify_proposals(
    pr.find_proposals(FOUNDING_MD), closed_row, set(), founding_state,
    promoted={"some_other_id"})
check(len(orph5c) == 1 and "closed" in orph5c[0][2],
      "an unrelated promoted id silenced the orphan leg")

# The registry reader itself, both directions.  It must read `promoted_ids`
# off the anchor rows and must NOT invent one from a malformed registry.
import tempfile as _tempfile  # noqa: E402

_anch = os.path.join(_tempfile.mkdtemp(), "anchors.json")
with open(_anch, "w", encoding="utf-8") as fh:
    json.dump({"anchors": [{"name": "stable-v1", "promoted_ids": ["aa", "bb"]},
                           {"name": "stable-v2", "promoted_ids": ["cc"]}]}, fh)
check(pr.promoted_ids(_anch) == {"aa", "bb", "cc"},
      "promoted_ids did not read the anchor registry: %r" % (pr.promoted_ids(_anch),))
check(pr.promoted_ids(os.path.join(os.path.dirname(_anch), "nope.json")) == set(),
      "a missing registry must read as no promotes, never as a crash")
with open(_anch, "w", encoding="utf-8") as fh:
    fh.write("{not json")
check(pr.promoted_ids(_anch) == set(),
      "an unparseable registry must read as no promotes")
# And the live registry must actually carry the promotes this repo has made --
# an empty answer here would make the new signal vacuous without failing.
check(len(pr.promoted_ids()) >= 6,
      "the live stable-anchor registry names %d promoted id(s); this repo has "
      "made at least 6, so the signal has gone blind"
      % len(pr.promoted_ids()))

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

# ---------------------------------------------------------------- invariant 4
# THE DOMAIN PRICE ON THE UN-RULED ROW (director 2026-09-01, §DG.7.1).
#
# Three consecutive rounds armed a lever whose subject hero has corpus 0, so
# condition (a) could never be bought at the fixture level.  The census that
# answers this in seconds existed as of 2026-09-01T19:21Z; what did not exist
# was any path by which a director writing a ruling would SEE it.  These rows
# pin the wiring, and each of the four failure directions is a shape that
# looks exactly like working code:
#
#   * a price that reads only `question` (a subject declared in `acceptance`
#     goes silently unpriced),
#   * a price that fires on any hero NAMED in the prose rather than on the
#     file the change edits (every request about a fight prices five heroes),
#   * a census failure that renders as silence instead of UNCERTIFIABLE,
#   * a price that reddens the exit code (LIMIT 8 -- it is a fact to weigh,
#     not a defect; a detector that shouts every round stops being read).

import contextlib                                                # noqa: E402
import datetime                                                  # noqa: E402
import io                                                        # noqa: E402

check(pr.subjects_of({"question": "fix `bots/BotLib/hero_tiny.lua:487`"}) == ["tiny"],
      "subjects_of missed a hero file named in question")
check(pr.subjects_of({"acceptance": "read bots/BotLib/hero_axe.lua"}) == ["axe"],
      "subjects_of ignores `acceptance` -- a subject declared there is unpriced")
check(pr.subjects_of({"axis": "bots/BotLib/hero_lion.lua"}) == ["lion"],
      "subjects_of ignores `axis`")
check(pr.subjects_of({"question": "hero_zuus.lua and bots/BotLib/hero_zuus.lua"}) == ["zuus"],
      "subjects_of did not de-duplicate, or matched a bare filename")
check(pr.subjects_of({"question": "bots/mode_farm_generic.lua + bots/FunLib/jmz_func.lua"}) == [],
      "shared code was given a domain price it does not owe")
check(pr.subjects_of({"question": "npc_dota_hero_tiny got tossed by npc_dota_hero_axe"}) == [],
      "a hero merely NAMED in prose was priced as the change's subject")
check(pr.subjects_of({"bundle": "hero_tiny", "id": "hero-9"}) == [],
      "a subject was guessed from bundle/id instead of read from a path")

_counts, _weak = pr._census()
check(_counts is not None, "the census could not run from inside pending_rulings")
check(_counts and _counts.get("crystal_maiden", 0) > 0,
      "sanity: a focus hero is absent from the corpus, so the census is misreading")


# A test_set.md with no proposal sections at all, so the orphan leg cannot
# contribute to the exit code and the price is the only thing under test.
# (Pointing these rows at the REAL test_set.md was the first cut, and it reads
# exit 3 -- from orphans, since the synthetic queue has none of the real rows.
# That would have made the LIMIT 8 assertion pass for a reason unrelated to
# the price, in whichever direction: evidence discipline 4.)
_bare_md = os.path.join(tmp, "test_set_no_proposals.md")
with open(_bare_md, "w", encoding="utf-8") as fh:
    fh.write("# member string below\nalpha,beta\n\nno proposal sections here.\n")


def _run_main(queue_path, census=None):
    """Drive the real main() and return (exit code, stdout)."""
    saved_argv, saved_census = sys.argv, pr._census
    if census is not None:
        pr._census = census
    sys.argv = ["pending_rulings.py", "--no-age", "--queue", queue_path,
                "--test-set", _bare_md, "--state",
                os.path.join(REPO, "iterations", "state.json")]
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            rc = pr.main()
    finally:
        sys.argv, pr._census = saved_argv, saved_census
    return rc, buf.getvalue()


def _run_owed(owed_path):
    """Drive the real main() in --owed-only mode and return (exit code, stdout)."""
    saved_argv = sys.argv
    sys.argv = ["pending_rulings.py", "--owed-only", "--owed", owed_path]
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            rc = pr.main()
    finally:
        sys.argv = saved_argv
    return rc, buf.getvalue()


def _row(qid, path, extra=None):
    row = {"id": qid, "stream": "strategy", "bundle": "", "status": "pending",
           "priority": 3, "question": "rides along; edits %s" % path,
           "director": ""}
    row.update(extra or {})
    return row


_tmp_queue = os.path.join(tmp, "queue_domain.json")
with open(_tmp_queue, "w", encoding="utf-8") as fh:
    json.dump({"requests": [_row("strategy-90", "bots/BotLib/hero_tiny.lua"),
                            _row("strategy-91", "bots/BotLib/hero_axe.lua"),
                            _row("strategy-92", "bots/mode_farm_generic.lua")]}, fh)

rc4, out4 = _run_main(_tmp_queue)
check("DOMAIN-EMPTY  tiny: corpus 0" in out4,
      "a corpus-0 subject was not priced DOMAIN-EMPTY on its un-ruled row")
check("domain        axe: corpus" in out4 and "DOMAIN-EMPTY  axe" not in out4,
      "a present subject was mispriced (census wired wrong, or 0 read as present)")
check("strategy-92" in out4 and "hero_" not in out4.split("strategy-92")[1].split("total open")[0],
      "a shared-code row was given a price line")
# LIMIT 8: the price informs the ruling; it does not fail the round.  All three
# rows are OTHER-bucket, so the run is a clean 0 even carrying a DOMAIN-EMPTY.
check(rc4 == 0, "the domain price changed the exit code (got %d, want 0)" % rc4)

rc5, out5 = _run_main(_tmp_queue, census=lambda: (None, None))
check("DOMAIN price UNCERTIFIABLE" in out5,
      "a census that could not run rendered as silence instead of UNCERTIFIABLE")
# Split defensively: the mutation stand caught M2 and M5 by CRASHING here on
# an absent line rather than by naming the defect, and a stack trace tells the
# next reader which line blew up, not which invariant broke.
_unc_tail = out5.split("DOMAIN price UNCERTIFIABLE", 1)
check(len(_unc_tail) > 1 and "tiny" in _unc_tail[1].split("\n")[0],
      "the UNCERTIFIABLE line did not name the subjects it failed to price")
check("DOMAIN-EMPTY" not in out5,
      "a census that could not run still asserted an emptiness it never read")
check(rc5 == 0, "the UNCERTIFIABLE price changed the exit code (got %d)" % rc5)

# ------------------------------------------- invariant 5: the hold keeps a baton
# HOLD-DOMAIN-EMPTY is the one ruling that clears its own row out of the un-ruled
# buckets while leaving real work owed -- iron rule 9's founding shape, where the
# creep-pull fix vanished from every queue for 37 rounds because closing its
# issue was read as finishing it.  The watch is what carries it, so it is pinned:
# blocked stays quiet, UNBLOCKED reddens (a state change owing a re-ruling), and
# a census that cannot run says so rather than implying the hold still stands.


def _held_row(qid, path):
    return {"id": qid, "stream": "strategy", "bundle": "", "status": "pending",
            "priority": 3, "question": "rides along; edits %s" % path,
            "director": {"ruling": "HOLD-DOMAIN-EMPTY", "wave": "none",
                         "at": "x", "ref": "y", "note": "z"}}


check(len(pr.held_for_domain([_held_row("s-1", "bots/BotLib/hero_tiny.lua")])) == 1,
      "held_for_domain missed a HOLD-DOMAIN-EMPTY row")
check(pr.held_for_domain([dict(_held_row("s-1", "x"), status="done")]) == [],
      "held_for_domain carried a CLOSED row -- a settled hold is not a baton")
check(pr.held_for_domain([{"id": "s-2", "status": "pending",
                           "director": {"ruling": "ROUTED"}}]) == [],
      "held_for_domain claimed a row that carries some other ruling")

_watch_blocked = os.path.join(tmp, "queue_hold_blocked.json")
with open(_watch_blocked, "w", encoding="utf-8") as fh:
    json.dump({"requests": [_held_row("strategy-93", "bots/BotLib/hero_tiny.lua")]}, fh)
rc6, out6 = _run_main(_watch_blocked)
check("STILL BLOCKED" in out6 and "strategy-93" in out6,
      "a held row lost its baton: the domain watch did not name it")
check(rc6 == 0, "a hold that still stands reddened the exit code (got %d)" % rc6)

_watch_open = os.path.join(tmp, "queue_hold_unblocked.json")
with open(_watch_open, "w", encoding="utf-8") as fh:
    json.dump({"requests": [_held_row("strategy-94", "bots/BotLib/hero_axe.lua")]}, fh)
rc7, out7 = _run_main(_watch_open)
check("UNBLOCKED" in out7 and "RE-RULE" in out7,
      "the archive gained the subject and the watch did not call for a re-ruling")
check(rc7 == 3,
      "an UNBLOCKED hold did not redden the exit code (got %d, want 3)" % rc7)

rc8, out8 = _run_main(_watch_blocked, census=lambda: (None, None))
check("UNCERTIFIABLE" in out8 and "NOT read this round" in out8,
      "a census that could not run left the hold looking checked")
check("STILL BLOCKED" not in out8,
      "the watch asserted a hold still stands on a reading it never took")

# ---------------------------------------------------------------- INVARIANT 4
# (§DR, director 2026-09-02T19:xxZ.)  The OWED_EXECUTION leg must fire on ITS
# OWN FOUNDING CASE: GH #413's ruling, delivered into the field the batch desk
# reads and STILL not executed a round later.  The row below rebuilds exactly
# that state -- the acceptance criterion the ruling itself wrote (`rec_slots:
# 8`), evaluated against a profile that still says 1 -- and requires an OWED
# with the executor named, because a finding nobody can route is a finding
# nobody acts on.
#
# What invariant 4 does NOT assert: that the real registry is currently empty.
# An owed baton is what the registry is FOR, and reddening every stream's test
# run over the director's outbox is how a detector stops being read -- the
# invariant-3 reasoning, one leg over.  The exit-3 selfcheck leg reports it.
# What IS pinned on the real tree is row health: every row carries the fields a
# reader needs to route it, and a `done_when` this tool can actually evaluate.

_owed_dir = os.path.join(tmp, "owed")
os.makedirs(_owed_dir, exist_ok=True)


def _profile(name, rec_slots):
    path = os.path.join(_owed_dir, name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"rec_slots": rec_slots, "games": 305}, fh)
    return path


def _owed_registry(name, rows):
    path = os.path.join(_owed_dir, name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"owed": rows}, fh)
    return path


def _row_413(done_when):
    # Absolute paths on purpose: os.path.join(REPO, abs) == abs, so the row
    # drives the real main() against a temp artefact without a repo write.
    return {"id": "recslot8_baseline", "issue": "GH #413",
            "executor": "batch-desk", "trigger": "the next harvest round",
            "ruled_at": "2026-09-02T10:16Z", "ruling": "rebuild the baseline",
            "done_when": done_when}


def _jv(path):
    return {"kind": "json_value", "path": path, "key": "rec_slots", "equals": 8}


rc9, out9 = _run_owed(_owed_registry(
    "owed_open.json", [_row_413(_jv(_profile("still_1.json", 1)))]))
check("OWED" in out9 and "recslot8_baseline" in out9,
      "the founding case did not produce an OWED row")
check("batch-desk" in out9 and "GH #413" in out9,
      "an owed baton was reported without naming its executor and its issue")
check(rc9 == 3, "an owed execution did not redden the exit code (got %d, want 3)" % rc9)

rc10, out10 = _run_owed(_owed_registry(
    "owed_done.json", [_row_413(_jv(_profile("rebuilt_8.json", 8)))]))
check("DONE" in out10 and "retire" in out10,
      "an executed ruling was not reported DONE with a call to retire the row")
check(rc10 == 0,
      "a satisfied done_when still reddened the exit code (got %d, want 0)" % rc10)

rc11, out11 = _run_owed(_owed_registry(
    "owed_gone.json", [_row_413(_jv(os.path.join(_owed_dir, "no_such.json")))]))
check("UNCERTIFIABLE" in out11,
      "a done_when whose artefact vanished was not reported UNCERTIFIABLE")
check("DONE" not in out11,
      "a condition that could not be READ was reported as executed")
check(rc11 == 3, "an unreadable done_when read as a pass (got %d, want 3)" % rc11)

rc12, out12 = _run_owed(_owed_registry(
    "owed_manual.json", [_row_413({"kind": "manual"})]))
check("no machine check" in out12 and rc12 == 3,
      "a manual row pretended to be a gate, or stopped reddening")

rc13, out13 = _run_owed(_owed_registry(
    "owed_bogus.json", [_row_413({"kind": "vibes"})]))
check("UNCERTIFIABLE" in out13 and rc13 == 3,
      "an unknown done_when kind was silently accepted")

rc14, out14 = _run_owed(_owed_registry("owed_empty.json", []))
check("OWED_EXECUTION: none" in out14 and rc14 == 0,
      "an empty registry did not read clean")

_broken = os.path.join(_owed_dir, "owed_broken.json")
with open(_broken, "w", encoding="utf-8") as fh:
    fh.write("{not json")
rc15, out15 = _run_owed(_broken)
check("UNCERTIFIABLE" in out15 and rc15 == 2,
      "a registry that could not be parsed read as a clean registry "
      "(got %d, want 2)" % rc15)

check(pr.load_owed(os.path.join(_owed_dir, "no_registry_here.json")) == [],
      "a missing registry raised instead of reading as empty")

# ------------------------------------------------- INVARIANT 6: the claim field
#
# GH #518 (director 2026-09-05; test_set.md §ER.2 / §ES).  Two director
# sessions took `mock_getvelocity_ultloc` in the same window and one whole
# work unit was thrown away, because an owed row being worked on and an owed
# row nobody has ever touched are byte-for-byte identical.  The failure
# direction is the point: the OWED leg raises its hand at every session in
# every round, and the purpose of that hand is to make somebody take the row
# -- so the better this leg works, the more certain the collision.
#
# What is pinned here is not "a claim exists" but the four ways a claim is
# ALLOWED to fail, all of which fall back to OWED.  A claim that silences a
# row it should not have silenced is this fix building the defect it was
# written against, so those cases get the load-bearing checks.

_now = datetime.datetime(2026, 9, 5, 12, 0, 0, tzinfo=datetime.timezone.utc)


def _stamp(hours_ago):
    return (_now - datetime.timedelta(hours=hours_ago)).strftime("%Y-%m-%dT%H:%M:%SZ")


def _claimed(done_when, claim, extra=None):
    row = _row_413(done_when)
    row.update(claim)
    row.update(extra or {})
    return row


def _render(rows):
    """Drive render_owed at a FIXED `now` and return (exit code, stdout)."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = pr.render_owed(rows, now=_now)
    return rc, buf.getvalue()


_open_jv = _jv(_profile("claim_still_1.json", 1))       # done_when unsatisfied
_done_jv = _jv(_profile("claim_rebuilt_8.json", 8))     # done_when satisfied

rc16, out16 = _render([_claimed(_open_jv, {})])
check("OWED" in out16 and "IN-FLIGHT" not in out16 and rc16 == 3,
      "an unclaimed owed row stopped reading OWED -- the pre-#518 behaviour "
      "must be exactly what an unclaimed row still gets")

rc17, out17 = _render([_claimed(_open_jv, {"claimed_by": "director 2026-09-05T09:5xZ",
                                           "claimed_at": _stamp(1)})])
check("IN-FLIGHT" in out17, "a fresh claim did not read IN-FLIGHT")
check("director" in out17 and "NOT a lock" in out17,
      "an in-flight row was printed without naming the claimant and saying a "
      "claim is not a lock -- both are what stops the reader treating it as one")
check(rc17 == 0,
      "a claimed row still reddened the exit code (got %d, want 0); the point "
      "of the field is that the next session has nothing to pick up here" % rc17)
check("in flight" in out17,
      "an all-in-flight registry exited 0 with no summary line -- a clean read "
      "would then be indistinguishable from 'nothing is owed'")

rc18, out18 = _render([_claimed(_open_jv, {"claimed_by": "director",
                                           "claimed_at": _stamp(pr.CLAIM_TTL_HOURS + 1)})])
check("EXPIRED" in out18 and "IN-FLIGHT" not in out18 and rc18 == 3,
      "an expired claim kept holding the row -- a claimant that died mid-round "
      "must not park a baton (backlog §6b's cost, sign-flipped)")
check("director" in out18,
      "an expired claim was dropped without naming who had claimed it")

rc19, out19 = _render([_claimed(_open_jv, {"claimed_by": "director"})])
check("UNREADABLE" in out19 and "IN-FLIGHT" not in out19 and rc19 == 3,
      "half a claim (no claimed_at) was honoured; an unreadable claim must "
      "fall back to OWED, never suppress real work on an unreadable say-so")

# The house style for report and charter prose fuzzes the minutes.  A claim
# written that way is the likeliest wrong claim anybody will write, and it
# must not become a six-hour hold.
rc20, out20 = _render([_claimed(_open_jv, {"claimed_by": "director",
                                           "claimed_at": "2026-09-05T07:xxZ"})])
check("UNREADABLE" in out20 and "IN-FLIGHT" not in out20 and rc20 == 3,
      "the fuzzed house-style stamp `T07:xxZ` was accepted as a claim instant")

rc21, out21 = _render([_claimed(_open_jv, {"claimed_by": "director",
                                           "claimed_at": _stamp(-3)})])
check("UNREADABLE" in out21 and "IN-FLIGHT" not in out21 and rc21 == 3,
      "a claim stamped in the future was honoured")

# LOAD-BEARING.  `mock_isprefix_ordering` is a standing VETO with no
# completion state; reporting OWED every round IS its whole job.  Letting a
# claim quiet it for six hours would be this fix manufacturing the silence it
# was written against.
rc22, out22 = _render([_claimed(_open_jv, {"claimed_by": "director",
                                           "claimed_at": _stamp(1)},
                                extra={"claimable": False})])
check("IN-FLIGHT" not in out22 and rc22 == 3,
      "a claim silenced a claimable:false standing constraint -- that row is "
      "supposed to say OWED in every round until somebody is about to break it")
check("claimable:false" in out22,
      "a refused claim was not explained; a reader would see OWED and think "
      "the claim never landed")

# A claim must not outrank the artefact in either direction.
rc23, out23 = _render([_claimed(_done_jv, {"claimed_by": "director",
                                           "claimed_at": _stamp(1)})])
check("DONE" in out23 and "retire" in out23 and "IN-FLIGHT" not in out23 and rc23 == 0,
      "a claim on an EXECUTED row turned 'retire me' into 'somebody is on it'")

check(pr.claim_status({})[0] == "UNCLAIMED",
      "a row with no claim fields did not read UNCLAIMED")
check(pr.parse_utc("2026-09-05T07:00:00Z") == datetime.datetime(
          2026, 9, 5, 7, 0, 0, tzinfo=datetime.timezone.utc),
      "a plain UTC stamp did not parse")
check(pr.parse_utc("2026-09-05T09:00:00+02:00") == datetime.datetime(
          2026, 9, 5, 7, 0, 0, tzinfo=datetime.timezone.utc),
      "an offset stamp was not normalised to UTC")
for _bad in (None, "", "   ", "yesterday", "2026-09-05T07:xxZ", 17):
    check(pr.parse_utc(_bad) is None,
          "parse_utc accepted %r as an instant" % (_bad,))

# Real-tree health: any claim actually written into the registry must be
# READABLE.  A live row carrying an unreadable claim is the case where a
# stream believes it has claimed a baton and the tool disagrees silently.
for _r in pr.load_owed():
    _cs, _cd = pr.claim_status(_r)
    check(_cs != "UNREADABLE" or _r.get("claimable") is False,
          "live owed row %r carries a claim this tool cannot read: %s"
          % (_r.get("id"), _cd))

# Row health on the REAL registry -- LIVE rows AND RETIRED ones.  Retired rows
# are included because without them this loop goes VACUOUS the moment the
# registry empties: the round that retired the founding row watched the check
# count drop 129 -> 123, which is a guard that stopped guarding without saying
# so (this file's own recurring subject).  A retired row is still a row a
# reader may act on -- it is the record of what was owed and how it was
# settled -- so parsing it is not busywork, and it keeps the parser pinned on
# real data even when nothing is currently owed.
_real_rows = pr.load_owed()
try:
    with open(os.path.join(REPO, "iterations", "owed_executions.json"),
              encoding="utf-8") as _fh:
        _real_rows = _real_rows + (json.load(_fh).get("retired") or [])
except (OSError, ValueError):
    pass
check(_real_rows, "the owed registry has neither a live nor a retired row -- this "
                  "loop is asserting nothing (see the comment above)")
for _r in _real_rows:
    for _f in ("id", "issue", "executor", "trigger", "done_when"):
        check(_r.get(_f), "real owed row %r is missing %s" % (_r.get("id"), _f))
    _st, _ = pr.owed_status(_r)
    check(_st in ("DONE", "RESIDUAL", "OWED", "UNCERTIFIABLE"),
          "real owed row %r produced an unknown state" % _r.get("id"))

# ---- done_when kind `path_contains_all` (director 2026-09-06, LIMIT 11).
# The defect it answers: `hero_domain_scan_2_30_31` accumulated eight rideshare
# readings onto ONE report path, and `path_exists` read DONE when seven of them
# were missing.  So the load-bearing assertion is the pair -- the SAME file is
# DONE under path_exists and OWED under path_contains_all.
import shutil                                                    # noqa: E402

_tmpdir = tempfile.mkdtemp(prefix="pr_contains_")
try:
    _art = os.path.join("iterations", "reports", "x", "scan.md")
    os.makedirs(os.path.join(_tmpdir, os.path.dirname(_art)))
    with open(os.path.join(_tmpdir, _art), "w", encoding="utf-8") as _fh:
        _fh.write("# scan\n\nhero-2 reading here.\nhero-30 reading here.\n")

    _row_exists = {"done_when": {"kind": "path_exists", "path": _art}}
    _row_all = {"done_when": {"kind": "path_contains_all", "path": _art,
                              "contains": ["hero-2", "hero-30", "hero-31"]}}
    check(pr.owed_status(_row_exists, repo=_tmpdir)[0] == "DONE",
          "path_exists did not go DONE on an existing artefact")
    _st, _detail = pr.owed_status(_row_all, repo=_tmpdir)
    check(_st == "OWED",
          "a rideshare artefact missing one of its readings still read %s" % _st)
    check("hero-31" in _detail and "1 of 3" in _detail,
          "the OWED detail did not name WHICH reading is absent: %s" % _detail)

    with open(os.path.join(_tmpdir, _art), "a", encoding="utf-8") as _fh:
        _fh.write("hero-31 reading here.\n")
    _st, _detail = pr.owed_status(_row_all, repo=_tmpdir)
    check(_st == "DONE", "all readings present still read %s" % _st)
    check("not correctness" in _detail,
          "the DONE line did not keep LIMIT 11's boundary visible: %s" % _detail)

    # An empty `contains` would pass on any file at all -- that is the old
    # defect wearing the new kind's name, so it must refuse rather than pass.
    check(pr.owed_status({"done_when": {"kind": "path_contains_all",
                                        "path": _art, "contains": []}},
                         repo=_tmpdir)[0] == "UNCERTIFIABLE",
          "path_contains_all with no needles did not refuse")
    # A missing artefact is OWED (the work is not done), never UNCERTIFIABLE.
    check(pr.owed_status({"done_when": {"kind": "path_contains_all",
                                        "path": "nope.md",
                                        "contains": ["hero-2"]}},
                         repo=_tmpdir)[0] == "OWED",
          "a missing rideshare artefact did not read OWED")
finally:
    shutil.rmtree(_tmpdir, ignore_errors=True)

# The real registry's rideshare leg must actually USE it -- a kind nobody
# reaches is a kind that proves nothing.
_ride = [r for r in pr.load_owed() + (_real_rows or [])
         if r.get("id") == "hero_domain_scan_2_30_31"]
check(_ride and _ride[0].get("done_when", {}).get("kind") == "path_contains_all",
      "the eight-reading rideshare row is not on the kind that checks its ids")

# ---- done_when kind `text_absent` (director 2026-09-05 §EV, landed 2026-09-08,
# GH #523).  The defect it answers: `outlatch_check1b_reason` reasoned correctly
# from "no assertion reads whether a comment is CORRECT" to `kind: manual`, and
# never asked the readable half -- whether the two wrong sentences are still
# THERE.  So the load-bearing assertion is again a PAIR on the SAME file: OWED
# while the sentence is in it, DONE once it is gone.
#
# Every assertion below is written in the FALSE-POSITIVE direction: the failure
# that costs something here is a row reading DONE while the wrong sentence is
# still shipped, or while the artefact it was supposed to be in has vanished.
_tmpdir = tempfile.mkdtemp(prefix="pr_textabsent_")
try:
    _art = os.path.join("tests", "test_guard.lua")
    os.makedirs(os.path.join(_tmpdir, "tests"))
    _wrong = "if this fails, the guard landed"
    _also = "the whole 75%-abort finding is about that missing guard"

    def _write(body):
        with open(os.path.join(_tmpdir, _art), "w", encoding="utf-8") as fh:
            fh.write(body)

    _write("-- %s\n-- %s\nlocal x = 1\n" % (_wrong, _also))
    _row = {"done_when": {"kind": "text_absent", "path": _art,
                          "text": [_wrong, _also]}}
    _st, _detail = pr.owed_status(_row, repo=_tmpdir)
    check(_st == "OWED",
          "a file that still carries both wrong sentences read %s" % _st)
    check("2 of 2" in _detail and _wrong in _detail,
          "the OWED detail did not name WHICH sentence is still there: %s" % _detail)

    # One of two removed is still OWED -- the kind is `text_absent`, not
    # `some_text_absent`, and a half-done edit is the case that would most
    # easily be waved through.
    _write("-- %s\nlocal x = 1\n" % (_also,))
    _st, _detail = pr.owed_status(_row, repo=_tmpdir)
    check(_st == "OWED", "one of two wrong sentences left still read %s" % _st)
    check("1 of 2" in _detail, "the partial OWED detail lost the count: %s" % _detail)

    _write("-- the guard is asserted below\nlocal x = 1\n")
    _st, _detail = pr.owed_status(_row, repo=_tmpdir)
    check(_st == "DONE", "both wrong sentences gone still read %s" % _st)
    check("not correctness" in _detail,
          "the DONE line did not keep LIMIT 11's boundary visible: %s" % _detail)

    # THE false positive this kind can have: deleting the file makes every
    # needle absent.  "The file is gone" is `path_absent`'s case; here it must
    # refuse, because a vanished artefact is not an executed ruling (GH #171).
    os.remove(os.path.join(_tmpdir, _art))
    _st, _detail = pr.owed_status(_row, repo=_tmpdir)
    check(_st == "UNCERTIFIABLE",
          "a DELETED artefact read %s -- absent-because-deleted is this "
          "kind's only false positive" % _st)
    check("path_absent" in _detail,
          "the refusal did not point at the kind that owns the deleted-file "
          "case: %s" % _detail)

    # An unreadable path (a directory) is the same refusal, reached through
    # the other door: os.path.exists is true and the read raises.
    _row_dir = {"done_when": {"kind": "text_absent", "path": "tests",
                              "text": [_wrong]}}
    check(pr.owed_status(_row_dir, repo=_tmpdir)[0] == "UNCERTIFIABLE",
          "an unreadable path did not refuse")

    # An empty / unwritable needle set is absent from every file, so it would
    # pass on any file at all -- the old defect wearing the new kind's name.
    _write("-- %s\n" % (_wrong,))
    for _bad in ([], None, "", [""], [_wrong, ""], [_wrong, 3]):
        check(pr.owed_status({"done_when": {"kind": "text_absent",
                                            "path": _art, "text": _bad}},
                             repo=_tmpdir)[0] == "UNCERTIFIABLE",
              "text_absent with an unreadable needle set (%r) did not refuse"
              % (_bad,))

    # A bare string is the shape a hurried author writes, and dropping it
    # would refuse a perfectly readable row; accept it as one needle.
    _st, _ = pr.owed_status({"done_when": {"kind": "text_absent",
                                           "path": _art, "text": _wrong}},
                            repo=_tmpdir)
    check(_st == "OWED", "a bare-string needle read %s, not OWED" % _st)
finally:
    shutil.rmtree(_tmpdir, ignore_errors=True)

# The kind must be reachable through the whitelist, not just implemented below
# it -- an unlisted kind reads UNCERTIFIABLE and the branch is dead code.  This
# one runs against the REAL repo, so the needle is BUILT AT RUNTIME: the first
# version quoted the absent string as a literal, which put it in the very file
# it was asserting the string to be absent from, and the check failed on its
# own text (LIMIT 11's "read the file through", collected immediately).
_absent_needle = "".join(["no-such", "-needle-", "%08x" % 0xDEADBEEF])
check(pr.owed_status({"done_when": {"kind": "text_absent",
                                    "path": "tests/test_pending_rulings.py",
                                    "text": [_absent_needle]}})[0] == "DONE",
      "text_absent is implemented but not reachable through the kind whitelist")
# ⚠ No LIVE registry row uses `text_absent` yet: its founding case
# (`outlatch_check1b_reason`) was retired before the kind existed.  That is a
# real limit and is recorded as one rather than papered over with a row
# invented to make an assertion pass -- the next ruling of the "take that
# sentence out" shape is the one that should carry it.

# ---- the `residual` field (director 2026-09-08, GH #627, LIMIT 13).
# The defect it answers: a `done_when` that outlived its obligation reads DONE
# forever, and the leg then prints "the director should retire this row" at a
# row whose OWN PROSE says it must not be retired.  Measured on two live rows
# (`roshan_pit_daynight_fix`, `hero_domain_scan_2_30_31`).  So the load-bearing
# assertion is again a PAIR: the same row, same satisfied key, DONE without the
# field and RESIDUAL with it.
_tmpdir = tempfile.mkdtemp(prefix="pr_residual_")
try:
    _art = os.path.join("tests", "test_landed.lua")
    os.makedirs(os.path.join(_tmpdir, "tests"))
    with open(os.path.join(_tmpdir, _art), "w", encoding="utf-8") as _fh:
        _fh.write("-- the pin landed\n")

    _base = {"id": "r", "done_when": {"kind": "path_exists", "path": _art}}
    check(pr.owed_status(_base, repo=_tmpdir)[0] == "DONE",
          "the control row (no residual, key satisfied) did not read DONE")

    _with = dict(_base, residual="one wave's behavioural reading is still owed")
    _st, _detail = pr.owed_status(_with, repo=_tmpdir)
    check(_st == "RESIDUAL",
          "a satisfied key + a recorded residual read %s, not RESIDUAL" % _st)
    check("behavioural reading" in _detail,
          "the RESIDUAL detail dropped the residual text itself: %s" % _detail)
    # The key's own reading must SURVIVE the overlay: "the artefact arrived"
    # is true and is half the reason a reader needs the row.
    check("exists" in _detail,
          "the RESIDUAL detail hid the machine key's own reading: %s" % _detail)

    # An unmet key keeps its own sharper sentence -- the overlay must not
    # replace "the file is not there" with "there is a residual".
    _unmet = {"id": "r", "residual": "still owed",
              "done_when": {"kind": "path_exists", "path": "nope.lua"}}
    _st, _detail = pr.owed_status(_unmet, repo=_tmpdir)
    check(_st == "OWED", "an unmet key with a residual read %s, not OWED" % _st)
    check("nope.lua" in _detail,
          "the residual overlay swallowed the unmet key's own detail: %s" % _detail)

    # A residual nobody can read must refuse rather than vanish: dropping it
    # restores the exact "retire me" line the field exists to stop.
    for _bad in (True, "", "   ", 3, []):
        check(pr.owed_status(dict(_base, residual=_bad), repo=_tmpdir)[0]
              == "UNCERTIFIABLE",
              "an unreadable residual (%r) did not refuse" % (_bad,))

    # ...and the arrow line, which is the part a human actually acts on.
    # `render_owed` reads the REAL repo, so the rendered pair points its key
    # at a file that is certainly there -- this test file.
    _rbase = {"id": "r", "issue": "-", "executor": "-", "trigger": "-",
              "done_when": {"kind": "path_exists",
                            "path": os.path.join("tests",
                                                 "test_pending_rulings.py")}}
    _rwith = dict(_rbase, residual="one wave's behavioural reading is still owed")
    _out = io.StringIO()
    with contextlib.redirect_stdout(_out):
        _lvl = pr.render_owed([_rwith])
    _text = _out.getvalue()
    check(_lvl == 3, "a RESIDUAL row did not raise the leg's exit level")
    check("NOT retirable" in _text,
          "the RESIDUAL arrow line did not say the row is not retirable:\n%s" % _text)
    check("should retire this row" not in _text,
          "the RESIDUAL row still printed the retire line -- that sentence IS "
          "the defect this field answers:\n%s" % _text)
    # Control: the same row without the field must still print it, or the
    # check above is satisfied by a tool that never prints the line at all.
    _out = io.StringIO()
    with contextlib.redirect_stdout(_out):
        pr.render_owed([_rbase])
    check("should retire this row" in _out.getvalue(),
          "the control (no residual) stopped asking for retirement -- the "
          "assertion above would then be vacuous")
finally:
    shutil.rmtree(_tmpdir, ignore_errors=True)

# The registry must actually carry the field -- a field nobody reaches proves
# nothing (same sentence as the rideshare check above, same reason).
_res_rows = [r for r in pr.load_owed() if isinstance(r.get("residual"), str)
             and r["residual"].strip()]
check(_res_rows,
      "no live row carries `residual`; the two rows measured on 2026-09-08 "
      "(roshan_pit_daynight_fix / hero_domain_scan_2_30_31) were the reason "
      "for the field, so an empty set means one of them lost it")

# ------------------------------------------- INVARIANT 7: iron rule 4(i-a)
# The leg (director 2026-09-12) has two ratchets and two informational counts,
# and every check below pins a failure mode that ACTUALLY HAPPENED while it was
# being written -- the first one happened to the director, in the reading that
# motivated the leg.

def _scan(rid, acceptance, at="2026-09-01", result="", status="pending"):
    return {"id": rid, "status": status, "acceptance": acceptance,
            "result": result,
            "director": {"ruling": "APPROVED-SCAN", "at": at}}


def _strata_run(rows):
    _out = io.StringIO()
    with contextlib.redirect_stdout(_out):
        _lvl = pr.render_strata(rows)
    return _lvl, _out.getvalue()


# 7a. THE LOOSE MARKER. A bare `分层` reads two rows that stratify by the
# LEVER's own variable as carriers of the ab/ba clause. This is not a
# hypothetical: the first cut of the census scored 12 carriers against a true
# 10, and both inventions landed on the "this row is fine" side of the ledger.
check(not pr.names_strata("按 Frostbite 等级分层给,不许并池"),
      "`按 Frostbite 等级分层给` counted as the ab/ba clause -- that is "
      "stratification by the lever's own variable (hero-33), a different "
      "obligation that shares a word")
check(not pr.names_strata("要按 (4) 的分层看目标换了没有"),
      "`按 (4) 的分层` counted as the ab/ba clause (hero-35)")
check(pr.names_strata("按铁律 4(i) **ab / ba 两层分开报**"),
      "the real phrasing ten rows use was NOT read as the clause -- the "
      "markers must stay harvested, not invented")
check(pr.names_strata("铁律 4(i-a):两个分层的**读数**都要登记"),
      "the 4(i-a) phrasing was not read as the clause")

# 7b. THE RATCHET FIRES ON A NEW SILENT ROW, AND ONLY ON A NEW ONE. A leg that
# reddened on the whole backlog would be the always-full section GH #276 warns
# about; a leg that never reddens is decoration. Both directions are pinned.
_lvl, _txt = _strata_run([_scan("x-new", "give N frames", at=pr.STRATA_CUTOFF)])
check(_lvl == 3, "a scan ruled on the cutoff date with a silent acceptance "
                 "did not raise the leg's exit level")
check("x-new" in _txt, "the new silent row was not named:\n%s" % _txt)
_lvl, _txt = _strata_run([_scan("x-old", "give N frames", at="2026-09-11")])
check(_lvl == 0, "a PRE-cutoff silent row drove the exit code -- the backlog "
                 "is informational by construction")
check("BACKLOG" in _txt and "x-old" in _txt,
      "the pre-cutoff row was neither counted nor named; a backlog that is "
      "invisible is the thing the cutoff traded away:\n%s" % _txt)

# 7c. AN UNREADABLE RULING DATE FALLS INTO THE BACKLOG, NOT THE RATCHET. The
# house style fuzzes the time, and a director who writes `at: "2026-09-xxZ"`
# must not be reddened on a date the tool could not read.
_lvl, _txt = _strata_run([_scan("x-fuzzy", "give N frames", at="soon")])
check(_lvl == 0 and "x-fuzzy" in _txt,
      "an unreadable `at` was ratcheted instead of parked in the backlog -- "
      "the conservative side is the backlog:\n%s" % _txt)

# 7d. THE LEG THAT TESTS THE HYPOTHESIS. Population 0 on the day it landed, by
# construction: not one of the ten clause-carrying rows had been harvested, so
# "the clause buys the disclosure" was UNTESTED, never demonstrated. The first
# row to land here is that evidence.
_ordered = _scan("x-ord", "按铁律 4(i) ab / ba 两层分开报",
                 result="2026-09-12 录像组交付读数:1,843 帧 / 257 episode",
                 status="delivered-and-consumed")
_lvl, _txt = _strata_run([_ordered])
check(_lvl == 3, "an acceptance that ORDERED the ab/ba disclosure and a "
                 "harvest that arrived without it did not raise the exit level "
                 "-- that row is the only evidence that the clause is not "
                 "sufficient")
check("STRATA_ORDERED_NOT_DELIVERED" in _txt and "x-ord" in _txt,
      "the ordered-not-delivered row was not named:\n%s" % _txt)
# Control: the same row whose harvest DOES name the strata must go quiet, or
# the check above is satisfied by a leg that fires on every delivery.
_delivered = dict(_ordered, result="录像组交付:ab / ba 两层分别 +2.1 / +1.8")
_lvl, _txt = _strata_run([_delivered])
check(_lvl == 0 and "STRATA_ORDERED_NOT_DELIVERED: none" in _txt,
      "a harvest that DID disclose both strata still fired the leg:\n%s" % _txt)

# 7e. `is_delivery` MUST NOT BE A LENGTH THRESHOLD. Measured: `hero-10`'s
# result is a hero-desk pointer and `hero-51`'s is a ruling transcript -- both
# long, neither a harvest. A length rule reads them as deliveries and the leg
# starts answering a question nobody asked.
check(not pr.is_delivery({"status": "pending", "result": "x" * 4000}),
      "a 4,000-character note with no delivery marker was read as a harvest "
      "-- that is the length threshold this predicate exists to avoid")
check(pr.is_delivery({"status": "delivered-and-consumed", "result": "short"}),
      "a row whose STATUS says delivered was not read as a delivery")
check(pr.is_delivery({"status": "pending", "result": "批测台部分交付(分母侧)"}),
      "a partial harvest parked on a `pending` row was missed -- `hero-1` is "
      "exactly that shape, and it is the row that reports `radiant 77 / dire "
      "76` (side GAME COUNTS) with the reading itself pooled, i.e. the #329 "
      "failure verbatim")

# 7f. THE LEG MUST BE MEASURING A NON-EMPTY SET ON THE REAL QUEUE. A census
# whose population went to zero is a census nobody can be wrong about -- same
# sentence, same reason, as the `residual` check above.
_real = pr.load_requests()
_real_scans = [r for r in _real if pr.is_scan_ruling(r)]
check(len(_real_scans) >= 20,
      "the real queue carries %d approved-SCAN rows; 40 were read on "
      "2026-09-12, so a collapse this large means `is_scan_ruling` stopped "
      "matching the ruling vocabulary" % len(_real_scans))
check(any(pr.names_strata(str(r.get("acceptance") or "")) for r in _real_scans),
      "not one approved-SCAN row on the real queue names the ab/ba clause -- "
      "ten did on 2026-09-12, so the markers have drifted off the prose")

print("%d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
