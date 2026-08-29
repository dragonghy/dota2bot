#!/usr/bin/env python3
"""[ratchet] A wait is a claim with an expiry date, and the expiry is machine-read.

INVARIANT 1 (the ratchet that matters).  No stream charter's LIVE 当前状态
entry may wait on an admission ruling for an id that is already in
`test_set.md`'s member string (or already promoted in `bots/`).  The
founding case: the director armed `campexit` at 2026-08-28T06:5xZ
(commit `e7e57979`), and the strategy charter then carried
"`campexit` 入集裁定仍欠" in FOUR consecutive status entries -- 07:30Z,
10:35Z, 13:55Z, 16:32Z -- the first of which printed the ruling commit's
own sha as its 开工 HEAD.  Two of those rounds then read that wait back as
"阻塞" and chose a different work unit because of it.

**A red here is fixed by editing the stale charter line, not by loosening
this test.**  If the wait is real but about something else (a promote
decision, a re-arm), say so on the line: the tool only flags a line that
asks for an ADMISSION ruling and calls it outstanding.

INVARIANT 2.  The discrimination the tool's usefulness rests on: a live
wait of another kind on the SAME armed id -- "等录像组核验 `campexit` 的
条件 (a)", which is a genuinely outstanding baton -- must not be flagged.
A detector that reddens on live batons would be turned off within a round.

INVARIANT 3.  `landed_when` answers with the commit that put the id in the
MEMBER STRING, not the one that first mentioned it in the file.  The tool's
own first cut got this wrong in the direction it exists to catch (the
待裁区 proposal is three hours older than the ruling), so the invariant is
asserted rather than trusted.

Run: python3 tests/test_stale_waits.py
"""

import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import stale_waits as sw  # noqa: E402

TEST_SET = os.path.join(REPO, "iterations", "streams", "test_set.md")
STREAMS = os.path.join(REPO, "iterations", "streams")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


def charter(body):
    """Write a synthetic charter and return its path (caller owns the dir)."""
    fd, path = tempfile.mkstemp(suffix=".md", dir=TMPDIR)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(body)
    return path


TMPDIR = tempfile.mkdtemp(prefix="stale_waits_")

SETTLED = {"campexit", "campvoid"}

LIVE_STALE = """# 章程

## Backlog
0BAND. 下一格:等总监裁 `campexit` 入集(仍挂着)。

## 当前状态(每次触发后更新)
- 2026-08-28T16:32Z:本轮做了别的。
  **交棒**:**总监**(① `campexit` 入集裁定**仍欠**,只提醒)。
- 2026-08-28T13:55Z:上一轮。
  **交棒**:**总监**(① `campexit` 入集裁定**仍欠**)。
"""

LIVE_OTHER_WAIT = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-28T16:32Z:本轮做了别的。
  **交棒**:**录像组**(等核验 `campexit` 的条件 (a),触发级逐帧)。
"""

LIVE_UNSETTLED = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-28T16:32Z:本轮。
  **交棒**:**总监**(① `bbrespawn` 入集裁定**仍欠**)。
"""

NO_STATUS = """# 章程

## Backlog
0X. 等总监裁 `campexit` 入集。
"""

# INVARIANT 6 fixtures -- see below.  The first is verbatim the strategy line
# that turned trunk red on 2026-08-28T22:15Z; the second is the escape hatch
# this exemption must NOT become.
LIVE_RERULING = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-28T22:15Z:本轮查了 `campexit` 的立案帧,六段里四段是盈利的。
  **下一格**:等总监重裁 `campexit`;**不为「落地完成度子句」开格**。
"""

# INVARIANT 7 fixtures.  Two charter conventions actually in the repo, both of
# which the tool's first cut could not read.
APPEND_ORDER = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-19T03:00Z:十天前那一轮。
  **交棒**:**总监**(① `campexit` 入集裁定**仍欠**)。
- 2026-08-28T19:03Z:最新那一轮,干净。
  **交棒**:**批测台**(本轮无请求)。
"""

BOLD_AND_BARE_BULLETS = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-01 初始化。
- **2026-08-19T00:44Z(第一次实际触发)**:旧的一轮。
- **2026-08-28T21:50Z(W22)**:最新那一轮。
  **交棒**:**总监**(① `campexit` 入集裁定**仍欠**)。
"""

# A bare-date bullet as a BLOCK BOUNDARY.  Caught by mutation M7, not by
# inspection: allowing `**` while still requiring `T` passed every other check
# here, because in BOLD_AND_BARE_BULLETS the bare date is merely the oldest
# entry.  Make it the line right after the live one and the omission bites --
# an unrecognised boundary lets the live block swallow the next entry, and the
# stale wait recorded there becomes a finding against the CURRENT round.
BARE_DATE_BOUNDARY = """# 章程

## 当前状态(每次触发后更新)
- **2026-08-28T21:50Z(W22)**:最新那一轮,干净。
- 2026-08-01 初始化。等总监裁 `campexit` 入集(仍挂着)。
"""

LIVE_RERULING_PLUS_STALE = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-28T22:15Z:本轮。
  **下一格**:等总监重裁 `campexit`。
  **交棒**:**总监**(① `campvoid` 入集裁定**仍欠**)。
"""

# --- INVARIANT 1: the founding shape is caught, and only in the live block ---
p = charter(LIVE_STALE)
live, rest = sw.split_charter(p)
hits = sw.stale_hits(live, SETTLED)
check(len(hits) == 1, "live block: expected exactly 1 stale wait, got %d" % len(hits))
check(hits and hits[0][2] == ["campexit"], "stale wait did not name campexit")
check(all("13:55Z" not in t for _n, t in live),
      "live block leaked into the previous status entry (it must stop at the next bullet)")
# The identical sentence in the backlog and in the older status entry is history.
check(len(sw.stale_hits(rest, SETTLED)) == 2,
      "history occurrences miscounted: %d" % len(sw.stale_hits(rest, SETTLED)))

# Every line is in exactly one of the two halves -- a guard that silently drops
# a bucket is worse than no guard (test_pending_rulings.py's partition rule).
with open(p, encoding="utf-8") as fh:
    total = len(fh.read().splitlines())
check(len(live) + len(rest) == total,
      "split_charter lost or duplicated lines: %d + %d != %d" % (len(live), len(rest), total))

# --- INVARIANT 2: a live baton of another kind on the same armed id ---
p2 = charter(LIVE_OTHER_WAIT)
live2, _rest2 = sw.split_charter(p2)
check(sw.stale_hits(live2, SETTLED) == [],
      "flagged a live verification baton (等录像组核验) as an expired admission wait")

# A wait on an id that is NOT armed is the legitimate case pending_rulings.py
# covers, and must stay silent here.
p3 = charter(LIVE_UNSETTLED)
live3, _rest3 = sw.split_charter(p3)
check(sw.stale_hits(live3, SETTLED) == [], "flagged a wait on an un-armed id")

# --- INVARIANT 4: mention is not use ---
# The round that REPORTS an expired wait quotes it.  Without the block-scoped
# exemption the tool reddens on the very report that fixes its own finding --
# measured: this test file's own charter entry tripped it twice.  A detector
# that punishes the fix is a detector that gets switched off in one round.
REPORTING_BLOCK = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-28T19:0xZ:本组连续四轮写着「等总监裁 `campexit` 入集(仍挂着)」,
  而那条裁定 06:5xZ 就落了地 —— `campexit` **已入集**,四条过期行已就地更正。
  **交棒**:**总监**(① `campvoid` 入集裁定**仍欠**)。
"""
p5 = charter(REPORTING_BLOCK)
live5, _rest5 = sw.split_charter(p5)
hits5 = sw.stale_hits(live5, SETTLED)
check([i for _n, _t, ids in hits5 for i in ids] == ["campvoid"],
      "the exemption is not id-scoped: expected only campvoid, got %s"
      % [ids for _n, _t, ids in hits5])
check(sw.resolved_in_block(live5) >= {"campexit"},
      "resolved_in_block missed an id declared 已入集 in the same block")

# --- INVARIANT 5: an admission RECORD is not an admission WAIT ---
# Found by mutation, not by inspection: dropping the "still outstanding" half
# of the match survived every other check here, i.e. nothing asserted that the
# factual line a stream writes the round an id lands ("本轮 `campvoid` 入集")
# stays silent.  Both halves must be required, and both must be asserted.
RECORD_BLOCK = """# 章程

## 当前状态(每次触发后更新)
- 2026-08-28T19:0xZ:本轮 `campvoid` 入集,arm 串 41 → 43 id。
"""
p6 = charter(RECORD_BLOCK)
live6, _rest6 = sw.split_charter(p6)
check(sw.stale_hits(live6, SETTLED) == [],
      "an admission RECORD (no outstanding word) was read as an admission WAIT")

# --- INVARIANT 6: a SECOND ruling is not an expired FIRST one ---
# Measured, not imagined: this exact line turned trunk red the day after the
# tool landed.  Strategy's 22:15Z entry asked the director to RE-rule an id it
# knew was already armed ("等总监重裁 `campexit`", GH #288) -- the wait LIMIT 1
# named and the docstring told streams to phrase this way -- and `重裁` matched
# ADMISSION_MARKERS through `裁 `.  INVARIANT 2 is the same discrimination one
# wording over; a detector that reddens on live batons gets switched off.
p7 = charter(LIVE_RERULING)
live7, _rest7 = sw.split_charter(p7)
check(sw.stale_hits(live7, SETTLED) == [],
      "flagged a 重裁 (re-ruling) request as an expired admission wait")

# ...and the exemption is LINE-scoped, so it cannot be used as a block-wide
# silencer: a genuinely expired admission wait on ANOTHER id in the same entry
# still has to be found.  Block scope would have made 重裁 an escape hatch --
# the failure direction the mention/use exemption (LIMIT 6) already warns about.
p8 = charter(LIVE_RERULING_PLUS_STALE)
live8, _rest8 = sw.split_charter(p8)
check([i for _n, _t, ids in sw.stale_hits(live8, SETTLED) for i in ids] == ["campvoid"],
      "the 重裁 exemption leaked past its own line: got %s"
      % [ids for _n, _t, ids in sw.stale_hits(live8, SETTLED)])

# The exemption must not swallow the founding shape, which carries no
# re-ruling word at all.  (Belt-and-braces on INVARIANT 1's fixture.)
check(len(sw.stale_hits(sw.split_charter(charter(LIVE_STALE))[0], SETTLED)) == 1,
      "the 重裁 exemption swallowed the founding expired admission wait")

# --- INVARIANT 7: "live" is the newest entry, in either charter convention ---
# Both halves were measured on the real tree on 2026-08-29, not imagined.
#
# (a) Position is not recency.  `director.md` and `batch-desk.md` APPEND, so
# the topmost bullet under 当前状态 is the OLDEST -- the tool was scanning the
# 2026-08-19 entry, ninety-odd entries stale, and printing "no expired wait".
p9 = charter(APPEND_ORDER)
live9, rest9 = sw.split_charter(p9)
check(live9 and "19:03Z" in live9[0][1],
      "live block is the topmost entry, not the newest: got %r"
      % (live9[0][1][:40] if live9 else None))
check(sw.stale_hits(live9, SETTLED) == [],
      "an oldest-first charter's stale HISTORY line was read as its live claim")
check(len(sw.stale_hits(rest9, SETTLED)) == 1,
      "the old entry should still be scanned as history, got %d"
      % len(sw.stale_hits(rest9, SETTLED)))

# (b) A bullet the regex cannot see is a charter the tool never reads.
# `replay-check.md` bolds its timestamps and opens with a bare date, so the
# original `^- 20\d\d-\d\d-\d\dT` matched zero bullets there -- empty live
# block, clean report, nothing ever scanned.  Silent-dark, the direction that
# does not raise a hand.
p10 = charter(BOLD_AND_BARE_BULLETS)
live10, _rest10 = sw.split_charter(p10)
check(live10 != [], "a charter with bolded timestamps produced an EMPTY live block")
check(live10 and "21:50Z" in live10[0][1],
      "bolded-bullet charter picked the wrong live entry: got %r"
      % (live10[0][1][:40] if live10 else None))
check([i for _n, _t, ids in sw.stale_hits(live10, SETTLED) for i in ids] == ["campexit"],
      "the founding shape went unfound in a bolded-bullet charter")

p11 = charter(BARE_DATE_BOUNDARY)
live11, rest11 = sw.split_charter(p11)
check(sw.stale_hits(live11, SETTLED) == [],
      "a bare-date bullet was not read as a boundary: the live block swallowed "
      "the next entry and its history line became a finding")
check(len(sw.stale_hits(rest11, SETTLED)) == 1,
      "the bare-date entry should still be scanned as history, got %d"
      % len(sw.stale_hits(rest11, SETTLED)))

# Every stream charter in the REAL repo must yield a non-empty live block.  A
# charter whose bullets the regex cannot parse reports clean forever, so the
# coverage itself has to be asserted, not assumed.
for _path in sw.charter_files(STREAMS):
    with open(_path, encoding="utf-8") as fh:
        _has_header = any(t.startswith(sw.STATUS_HEADER) for t in fh.read().splitlines())
    if not _has_header:
        continue
    check(sw.split_charter(_path)[0] != [],
          "%s has a 当前状态 header but the tool reads NO live block from it"
          % os.path.basename(_path))

# A file with no 当前状态 header has an empty live block -- not an error.
p4 = charter(NO_STATUS)
live4, rest4 = sw.split_charter(p4)
check(live4 == [], "a charter without 当前状态 produced a live block")
check(len(sw.stale_hits(rest4, SETTLED)) == 1, "history scan missed the backlog line")

# --- input handling: could-not-run is exit 2, never a silent pass ---
onel = charter("only one line\n")
try:
    sw.armed_ids(onel)
    check(False, "a one-line test_set.md did not raise InputError")
except sw.InputError:
    check(True, "InputError on a file with no member string")
try:
    sw.armed_ids(os.path.join(TMPDIR, "no-such-file.md"))
    check(False, "a missing test_set.md did not raise InputError")
except sw.InputError:
    check(True, "InputError on a missing file")

# --- INVARIANT 3: landed_when reads the member string, not the whole file ---
landed = sw.landed_when("campexit", TEST_SET)
if landed is None:
    # Honest unknown (shallow clone) -- LIMIT of the tool, not a failure.
    check(True, "landed_when unknown (shallow clone)")
else:
    sha = landed.split()[0]
    blob = subprocess.run(["git", "-C", REPO, "show",
                           "%s:iterations/streams/test_set.md" % sha],
                          capture_output=True, text=True)
    line2 = blob.stdout.splitlines()[1] if blob.returncode == 0 and \
        len(blob.stdout.splitlines()) > 1 else ""
    check("campexit" in [t.strip() for t in line2.split(",")],
          "landed_when named %s, whose line 2 does not carry campexit" % sha)
check(sw.landed_when("no_such_gate_id_xyzzy", TEST_SET) is None,
      "landed_when invented a landing commit for an id that was never armed")

# --- the real corpus: the ratchet ---
try:
    armed = sw.armed_ids(TEST_SET)
    charters = sw.charter_files(STREAMS)
except sw.InputError as exc:
    print("UNCERTIFIABLE -- %s" % exc)
    sys.exit(2)

# The corpus premise: armed_ids really read a populated member string, so that
# `not live_findings` below means "nothing found" and not "nothing scanned".
# The canary id is deliberately a CURRENTLY-armed one, so an ejection breaks
# this line loudly rather than hollowing the ratchet out in silence.  It was
# `campexit` until the director ejected it on 2026-08-29 (test_set.md §CA,
# 43 -> 42 ids) -- exactly the event this check is built to notice.  Swapping
# the canary to another armed id is the intended repair; deleting the check is
# not.  The size floor makes a truncated line 2 fail even if the canary happens
# to survive it.
check("campvoid" in armed,
      "the canary id is not in the member string -- rewrite this test's premise")
check(len(armed) >= 30,
      "member string parsed to only %d ids -- line 2 looks truncated" % len(armed))
settled = armed | sw.promoted_ids(os.path.join(REPO, "bots"))
check("creeppull" in settled, "promoted ids not read from bots/ PROMOTED notes")
live_findings = [(os.path.basename(path), n, t)
                 for path, hits, _hist in sw.scan(charters, settled)
                 for n, t, _ids in hits]
check(not live_findings,
      "a charter's LIVE 当前状态 waits on an admission ruling that already landed: %s "
      "-- fix the charter line, do not loosen this test" % live_findings)

for name in os.listdir(TMPDIR):
    os.unlink(os.path.join(TMPDIR, name))
os.rmdir(TMPDIR)

print("%d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
