#!/usr/bin/env python3
"""Un-ruled queue requests -- the §BB.4 obligation, made mechanical.

WHY THIS EXISTS (2026-08-25T13:xxZ, director)
---------------------------------------------
`test_set.md` §BB.4 (legislated 2026-08-24T19:xxZ) says a rideshare admission
proposal -- one that declares "搭车 / 不申请专波 / 零 AWS 增量" -- must be
approved or returned **in the round it arrives**, because its only cost is
not being ruled.

The rule was written and then not enforced by its own author: by
2026-08-25T13:xxZ the un-ruled pile held `campsel` (proposed 08-23T23:3xZ),
`tbearly`, `tpgap`, `tpdeathbuy`, `zusstatic` and `pulldrag` -- i.e. every
single proposal that arrived after §BB.4 was written.  Nothing was broken;
nobody was told.  The 待裁区 of `test_set.md` is prose, and prose does not
raise its hand.  This is the same shape as iron rule 10's founding case:
the detector that would have caught it did not exist, so the work rebuilt
itself by hand.

WHAT IT REPORTS
---------------
Requests in `iterations/queue.json` that are still open (`status` in
`pending`/`running`/`harvested`) and carry no `director` ruling, split into
two buckets, because they need two different rulings:

  RIDESHARE  -- the request text declares it rides an existing wave at zero
                AWS increment.  §BB.4 applies: rule it this round.
  OTHER      -- everything else (archive scans, dedicated-wave asks).  These
                still need a routing/scheduling ruling, but §BB.4's
                same-round deadline is not what binds them.

...and, since 2026-08-29 (director, §CG.5), the OTHER END of the same path:

  ORPHAN_PROPOSAL -- an admission proposal that exists ONLY as a `test_set.md`
                section, with no `queue.json` request row to carry a
                ruling, and no ruling delivered anywhere else yet.

WHY THE ORPHAN LEG EXISTS (2026-08-29T18:5xZ, director; test_set.md §CG.1)
--------------------------------------------------------------------------
`fieldsip` was proposed for admission at 10:xxZ in `test_set.md` §CE -- a
rideshare, zero AWS increment, the exact shape §BB.4 says must be ruled in
the round it arrives.  It sat un-ruled for EIGHT HOURS across three rounds,
and this tool printed, truthfully, in every one of them:

    RIDESHARE (§BB.4: rule this round): none
    OTHER (routing/slot ruling still owed): none

Because it scans `queue.json`, and `fieldsip` had no row there -- grep count
zero.  A clean read, not a clean scene.  Compare §CF's two ids (`odbuild`,
`wkqdmg`): they had rows, this tool named them for two consecutive rounds,
and they were still late -- but late with somebody shouting.  `fieldsip` was
late with NOBODY shouting, and the only path by which it was eventually
found was a human happening to read that section.  Luck is not a mechanism.

This is the mirror of §AW.1 / §BM.  Those three cases lost a RULING that
never reached the field the ruled party reads; this one lost the REQUEST.
Charter 2.5 legislated the downstream half (a ruling must land in
`director`) and never wrote the upstream half down at all -- nothing said a
proposal must first have a row.  The failure direction is UNDER-report,
which is the opposite sign from GH #276's over-asking detector, so "it errs
conservative" is not available as consolation here.

WHAT COUNTS AS "ALREADY RULED" FOR THE ORPHAN LEG
--------------------------------------------------
Two machine-readable signals, and the pair was chosen by running it against
the founding case rather than by taste:

  * the id is in `test_set.md` line 2 (the armed member string) -- admission
    IS the ruling, and the harm is over; or
  * its `iterations/state.json` entry carries a `director_ruling*` key.

Deliberately NOT a signal: the mere EXISTENCE of a `state.json` entry.  At
the founding commit (`351389e`, the round §CE landed) `fieldsip` already had
a full `state.json` entry -- the proposing stream writes one AS the proposal,
with `handoff: "director: rule on admission"` in it.  Keying off presence
would have made this leg silent on the one case it was built for.  Neither
signal alone suffices either: `aimguard` was admitted with no
`director_ruling` key anywhere, `campexit` was ejected and so is not in the
member string; each is caught by the other signal.

LIMITS FOR THE ORPHAN LEG (in addition to 1-4 below)
-----------------------------------------------------
5. A proposal with no row but an already-delivered ruling is reported as
   `ROWLESS (ruled elsewhere)` -- informational, no effect on the exit code.
   §CG.5 read literally would redden those too; they are the three historical
   sections (§BR/§BT/§BV) that predate the rule, and reddening on them every
   round is how a detector gets ignored.
6. The proposal id is parsed from the heading, after `提议入集:`.  A section
   whose heading does not yield one is reported as `UNPARSED` rather than
   dropped -- GH #171's rule: a leg that could not read is not a leg that
   read clean.
7. `UNKNOWN STATUS` names rows whose `status` is outside the vocabulary this
   tool knows.  Since the GH #317 ruling (2026-08-30) those rows are COUNTED
   AS OPEN, so they are no longer invisible to the buckets above -- see
   `is_open`.  They are still named, and that is deliberate: the ruling fixes
   what the drift costs, it does not make the drift stop happening, and a
   silent auto-accept would retire the only signal that says the vocabulary
   moved.  The tool still cannot tell a genuinely-closed state from a drifted
   spelling of an open one; it now errs toward open.  Measured 2026-08-30:
   `routed` (1), `harvested_pending_verification` (3),
   `returned_uninterpretable` (1) -- all five already ruled, so the ruling
   added no findings on the day it landed.

8. The orphan leg's LINK is `bundle`/`bundle_was`, and a rideshare request has
   an empty `bundle` by definition.  Since GH #376 the leg separates the two
   cases it used to merge: `no queue request row at all` (nothing exists) vs
   `no row LINKS it` (a row exists, naming the id only in its prose, and is
   named on the same line).  Both are orphans and both redden the exit code --
   an unlinked request has not reached the machine-read field either -- but
   only the first one means "open a row".  The second was silently telling
   directors to open a DUPLICATE, which is a defect the report creates rather
   than finds.  The prose match names CANDIDATE rows: whole-token evidence
   that somebody wrote this id into that row, never an assertion that it is
   the proposal's row.

LIMITS (read these before quoting the output)
---------------------------------------------
1. **It reports a problem, not a verdict.**  An un-ruled OTHER request may be
   legitimately parked behind a wave slot that does not exist yet
   (`RECEIVED_NOT_SCHEDULED` is a real ruling, and this tool cannot tell an
   un-ruled request from one whose ruling belongs to a future round).
2. **The RIDESHARE test is a text match** on the request's own declaration.
   A proposal that rides a wave without saying so reads as OTHER; a proposal
   that says so falsely reads as RIDESHARE.  Judge the quoted line.
3. **Age is best-effort and often unavailable.**  Routine containers clone
   shallow (50 commits at the time of writing), so a request introduced
   before the graft point has no first-appearance commit in this checkout.
   The honest output there is `age=unknown`, not a fabricated zero --
   backlog §6b's rule after the `busy-bardeen` misjudgement: when the
   evidence cannot separate two cases, say so rather than pick one.
4. It says nothing about whether a ruling is *correct*, only whether one
   exists in the machine-read field (`director`).  §BA.4 / §AW.1: a ruling
   that lives only in report prose is not delivered, and to this tool it is
   indistinguishable from no ruling at all -- which is the point.

Exit codes: 0 = no un-ruled RIDESHARE request; 3 = at least one (a finding,
not a failure).  OTHER-bucket entries never change the exit code.
"""

import argparse
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
QUEUE = os.path.join(REPO, "iterations", "queue.json")
TEST_SET = os.path.join(REPO, "iterations", "streams", "test_set.md")
STATE = os.path.join(REPO, "iterations", "state.json")

# The vocabulary, after the GH #317 ruling (director 2026-08-30).  CLOSED is
# the authoritative half: a row is open unless it says one of these.  OPEN
# stays listed because it is the vocabulary streams are asked to write, and
# because `unknown_status_rows` reports anything outside the pair -- but it is
# no longer what `is_open` keys off.
OPEN_STATES = ("pending", "running", "harvested")
CLOSED_STATES = ("done", "rejected")

# The declarations a rideshare proposal makes about itself.  Kept as literal
# substrings on purpose: these are the exact phrases the streams write, and a
# looser regex would start classifying dedicated-wave asks as rideshares.
RIDESHARE_MARKERS = (
    "搭车",
    "零 AWS 增量",
    "不申请专波",
    "不申请新波",
    "NO NEW WAVE NEEDED",
    "NO WAVE",
    "零 EC2",
)


def load_requests(path=QUEUE):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh).get("requests", [])


def is_open(req):
    """Open unless the row explicitly says it is closed (GH #317, 甲 variant).

    This used to be `status in OPEN_STATES`, which answered False for every
    spelling the tool did not recognise -- so a drifted status took the whole
    row out of BOTH buckets and the request sat there unseen.  `hero-20` is
    the measured case: `status="routed"`, `director` empty, its ruling written
    into `result` by the batch desk, invisible to this tool for two days.

    Keying off CLOSED instead flips the failure direction, which is the whole
    reason for the ruling: a spelling drift now costs one extra look in some
    round (the row shows up as open and, if genuinely un-ruled, is named),
    where before it cost the request its visibility.  Over-asking is the
    tolerable error here; GH #276's "asked until nobody read it" warning is
    about a detector that fires every round, not about one extra row.

    A missing `status` key is open for the same reason.
    """
    return req.get("status") not in CLOSED_STATES


def is_unruled(req):
    """No machine-read ruling.

    Absent field and null both count (§AW.1).  So does a `director` dict whose
    `ruling` is blank -- added 2026-08-26 (director, GH #218's round) after this
    tool reported `none` on a queue that contained `strategy-18`, whose field
    reads `{"ruling": "", "wave": "", "at": "", "ref": ""}`.

    That shape is what a stream writes when it files the request and leaves the
    director's axis for the director to fill; it is EXACTLY the state this tool
    exists to name, and it was the one state that got past it.  The old test
    (`in (None, {}, "")`) asked whether the FIELD was empty; the question the
    tool is for is whether the RULING is.  A scaffolded-but-blank dict answers
    "yes" to the second and "no" to the first, so it scored as ruled and left
    `strategy-18` invisible for as long as it has been open.

    Same family as the defect that turned up in the same round on the other
    side of the delivery path -- `test_set.md`'s line 2 sat four rounds behind a
    ruling that had been made (GH #210).  One end of the path had a ruling that
    never reached the field; this end had a field that never reached a ruling.
    Neither raised a hand, and both were found by eye.
    """
    director = req.get("director")
    if director in (None, {}, ""):
        return True
    if isinstance(director, dict):
        # `ruling: null` must not survive as the string "None" -- the first cut
        # of this fix wrote `str(director.get("ruling", "")).strip()` and read a
        # JSON null as a four-character ruling.  Caught by the row that spells
        # that case out, which is why the rows enumerate the blanks instead of
        # testing one representative of them.
        ruling = director.get("ruling")
        return ruling is None or not str(ruling).strip()
    return False


def is_rideshare(req):
    text = req.get("question", "") or ""
    return any(marker in text for marker in RIDESHARE_MARKERS)


def first_seen(req_id, path=QUEUE):
    """First commit in *this checkout* that introduced the request id.

    Returns an ISO date string, or None when the answer is not available --
    a shallow clone whose graft point is newer than the request, or a git
    that refuses to run at all.  LIMIT 3: None means unknown, never zero.
    """
    needle = '"id": "%s"' % req_id
    try:
        out = subprocess.run(
            ["git", "-C", REPO, "log", "--format=%aI", "-S", needle, "--", path],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    lines = [ln for ln in out.stdout.splitlines() if ln.strip()]
    return lines[-1] if lines else None


# --------------------------------------------------------------------------
# The orphan leg (§CG.5).  Everything below reads `test_set.md` and
# `state.json`; nothing above it does.
# --------------------------------------------------------------------------

# A proposal section's heading, e.g.
#   ## §CE 2026-08-29T10:xxZ 协同组提议入集:`fieldsip`(owner P2 ...)
# The id is the FIRST backticked token after the marker, on purpose: several
# real headings also backtick a contrast id (§BK names `campdanger`) or a
# withdrawal (§BR names `abil1st`), and those are not what is being proposed.
PROPOSAL_HEADING = re.compile(r"^##\s+§(\S+)\s")
PROPOSAL_MARKER = "提议入集"
PROPOSED_ID = re.compile(PROPOSAL_MARKER + r"\s*[:：]\s*`([a-z][a-z0-9_]*)`")

# Any key that records a director's ruling on the id.  Spelled as a prefix
# because the archive uses `director_ruling` and `director_ruling_<date>` for
# a re-ruling (see `campexit_20260828`, which carries both).
RULING_KEY_PREFIX = "director_ruling"


def read_test_set(path=TEST_SET):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def armed_ids(text):
    """The armed member string, which is line 2 of `test_set.md`.

    Positional by design, same as tests/test_pending_rulings.py's reader: a
    fuzzy search would happily match one of the historical member strings
    quoted in the archive sections further down, and then every ejected id
    would read as still armed.
    """
    lines = text.splitlines()
    if len(lines) < 2:
        return set()
    line = lines[1].strip()
    if not line or "," not in line or " " in line:
        return set()
    return {s for s in line.split(",") if s}


def find_proposals(text):
    """[(section, id_or_None, heading)] for every admission-proposal section."""
    out = []
    for line in text.splitlines():
        if PROPOSAL_MARKER not in line:
            continue
        head = PROPOSAL_HEADING.match(line)
        if not head:
            continue
        cand = PROPOSED_ID.search(line)
        out.append((head.group(1), cand.group(1) if cand else None, line.strip()))
    return out


def queue_rows_for(cand, requests):
    """Rows whose `bundle` (or `bundle_was`) names this id, as a whole token.

    Token equality, not substring: `stayfield` and `stayfield2` are both real
    ids, and a substring match would let either answer for the other.
    """
    rows = []
    for req in requests:
        tokens = set()
        for field in ("bundle", "bundle_was"):
            value = req.get(field) or ""
            tokens.update(t for t in re.split(r"[^A-Za-z0-9_]+", str(value)) if t)
        if cand in tokens:
            rows.append(req)
    return rows


# The free-text fields a request writes its own story into.  Deliberately NOT
# `bundle`/`bundle_was` -- this function exists to find the rows those two
# fields MISSED.
PROSE_FIELDS = ("axis", "question", "acceptance")


def rows_naming_in_prose(cand, requests):
    """Open rows that name this id in free text, whole-token (GH #376).

    `queue_rows_for` is the LINK: it keys on `bundle`/`bundle_was`.  A rideshare
    request has an empty `bundle` by definition -- it asks for no wave, so there
    is no bundle to name -- and the convention that made the link work at all
    (write the candidate id into `bundle` anyway) was never written down.  The
    day a correctly-filed rideshare row leaves it blank, the orphan leg says
    `no queue request row at all` about a row that is sitting right there.

    That sentence is not merely wrong, it is ACTIONABLY wrong: the finding's
    instruction is "open a queue request row", and following it produces a
    SECOND row for one proposal -- a defect the reporter did not have until it
    read the report.  So the tool must be able to tell "there is no row" from
    "there is a row and nothing links it".

    Whole-token, same rule and same reason as `queue_rows_for`: `stayfield` must
    not answer for `stayfield2`.  Open rows only: a closed row cannot carry a
    ruling, so pointing at one would be the same bad instruction by another
    route.  These are CANDIDATES, never an assertion of correspondence -- a
    prose mention is evidence that somebody wrote this id into this row, not
    proof that this row is the proposal's row, and the caller says so.
    """
    rows = []
    for req in requests:
        if not is_open(req):
            continue
        tokens = set()
        for field in PROSE_FIELDS:
            value = req.get(field) or ""
            tokens.update(t for t in re.split(r"[^A-Za-z0-9_]+", str(value)) if t)
        if cand in tokens:
            rows.append(req)
    return rows


def load_state(path=STATE):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def ruled_in_state(cand, state):
    """True when some `state.json` entry for this id carries a ruling key.

    NOT the same question as "does an entry exist" -- see the module docstring:
    the proposing stream writes the entry as part of proposing, so presence is
    a proposal signal, and using it here would have silenced the founding case.
    """
    for value in state.values():
        if not isinstance(value, dict) or value.get("id") != cand:
            continue
        for key in value:
            if key.startswith(RULING_KEY_PREFIX) and str(value[key]).strip():
                return True
    return False


def classify_proposals(proposals, requests, armed, state):
    """(orphans, rowless_ruled, unparsed).

    orphans is the only bucket that reddens the exit code; each entry is
    (section, id, reason, [row ids]).
    """
    orphans, rowless_ruled, unparsed = [], [], []
    for section, cand, heading in proposals:
        if cand is None:
            unparsed.append((section, heading))
            continue
        rows = queue_rows_for(cand, requests)
        ruled = cand in armed or ruled_in_state(cand, state)
        row_ids = [r.get("id") for r in rows]
        if not rows:
            if ruled:
                rowless_ruled.append(
                    (section, cand, "no queue request row at all", row_ids))
            else:
                # GH #376: distinguish "no row" from "a row nothing links".
                # Same severity (still an orphan, still exit 3 -- an unlinked
                # request has not reached the machine-read field either), a
                # different INSTRUCTION: link it, do not open a second one.
                prose = rows_naming_in_prose(cand, requests)
                if prose:
                    orphans.append(
                        (section, cand,
                         "no row LINKS it (`bundle` empty) -- set `bundle` on the "
                         "open row(s) below; do NOT open a second row",
                         [r.get("id") for r in prose]))
                else:
                    orphans.append(
                        (section, cand, "no queue request row at all", row_ids))
        elif not any(is_open(r) for r in rows) and not ruled:
            orphans.append(
                (section, cand, "only closed rows -- a ruling has nowhere to land", row_ids))
    return orphans, rowless_ruled, unparsed


def unknown_status_rows(requests):
    known = set(OPEN_STATES) | set(CLOSED_STATES)
    return [r for r in requests if r.get("status") not in known]


def partition(requests):
    """Open+un-ruled requests, split into (rideshare, other).

    The two buckets are disjoint and together hold every open un-ruled
    request -- asserted by tests/test_pending_rulings.py, because a guard
    that silently drops a bucket is worse than no guard.
    """
    open_unruled = [r for r in requests if is_open(r) and is_unruled(r)]
    ride = [r for r in open_unruled if is_rideshare(r)]
    other = [r for r in open_unruled if not is_rideshare(r)]
    return ride, other


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--queue", default=QUEUE)
    ap.add_argument("--test-set", default=TEST_SET)
    ap.add_argument("--state", default=STATE)
    ap.add_argument("--no-age", action="store_true",
                    help="skip the git first-appearance lookup (faster)")
    args = ap.parse_args()

    requests = load_requests(args.queue)
    ride, other = partition(requests)

    def render(bucket, title):
        if not bucket:
            print("%s: none" % title)
            return
        print("%s: %d" % (title, len(bucket)))
        for r in bucket:
            age = "unknown" if args.no_age else (first_seen(r["id"], args.queue) or "unknown")
            print("  %-12s status=%-9s prio=%s bundle=%-24s first_seen=%s"
                  % (r.get("id"), r.get("status"), r.get("priority"),
                     r.get("bundle") or "-", age))

    print("=== un-ruled queue requests (director field empty) ===")
    render(ride, "RIDESHARE (§BB.4: rule this round)")
    render(other, "OTHER (routing/slot ruling still owed)")
    print("total open requests: %d" % sum(1 for r in requests if is_open(r)))

    unknown = unknown_status_rows(requests)
    if unknown:
        # LIMIT 7: since GH #317 these are COUNTED AS OPEN (so they reach the
        # buckets above); they are still named because the drift itself is the
        # thing worth seeing.  A question, not a verdict.
        print("UNKNOWN STATUS (counted as open per GH #317; vocabulary drift): %d"
              % len(unknown))
        for r in unknown:
            print("  %-12s status=%-32s ruled=%s"
                  % (r.get("id"), r.get("status"), not is_unruled(r)))

    # ---------------------------------------------------------------- §CG.5
    try:
        text = read_test_set(args.test_set)
    except OSError as exc:
        print("\n=== orphan admission proposals (test_set.md sections with no queue row) ===")
        print("UNCERTIFIABLE -- could not read %s (%s). This line is NOT a pass."
              % (args.test_set, exc))
        return 2

    proposals = find_proposals(text)
    orphans, rowless_ruled, unparsed = classify_proposals(
        proposals, requests, armed_ids(text), load_state(args.state))

    print("\n=== orphan admission proposals (test_set.md sections with no queue row) ===")
    print("proposal sections scanned: %d" % len(proposals))
    if orphans:
        print("ORPHAN_PROPOSAL (§CG.5: open a queue request row, then rule it): %d"
              % len(orphans))
        for section, cand, reason, row_ids in orphans:
            print("  §%-4s id=%-14s %s%s"
                  % (section, cand, reason,
                     (" (rows: %s)" % ", ".join(row_ids)) if row_ids else ""))
    else:
        print("ORPHAN_PROPOSAL (§CG.5: open a queue request row, then rule it): none")
    if rowless_ruled:
        # LIMIT 5: informational.  These are the pre-rule sections; reddening
        # on them every round is how a detector gets ignored.
        print("ROWLESS (ruled elsewhere -- informational): %d" % len(rowless_ruled))
        for section, cand, _reason, _rows in rowless_ruled:
            print("  §%-4s id=%s" % (section, cand))
    if unparsed:
        # LIMIT 6: a heading this tool could not read is not a heading it read
        # clean (GH #171).
        print("UNPARSED proposal headings (id not readable): %d" % len(unparsed))
        for section, heading in unparsed:
            print("  §%-4s %s" % (section, heading[:110]))

    return 3 if (ride or orphans) else 0


if __name__ == "__main__":
    sys.exit(main())
