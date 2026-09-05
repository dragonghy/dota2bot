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

...and, since 2026-09-02 (director, §DR), the THIRD end of the same path,
reachable only with `--owed-only`:

  OWED_EXECUTION -- a ruling that WAS delivered, into the very field the
                ruled party reads, and whose EXECUTION is still owed.
                Since 2026-09-05 (GH #518) such a row also reads IN-FLIGHT
                when a session has pushed a claim on it inside the TTL; see
                `claim_status` and LIMIT 12.

WHY THE OWED LEG EXISTS (2026-09-02T19:xxZ, director; test_set.md §DR)
----------------------------------------------------------------------
GH #413's ruling (rebuild `rec_slot_baseline.json` on `--rec-slots 8`; zero
EC2, zero wave cost) was made at 10:16Z on 2026-09-02 and dropped TWICE the
same day.

  * W38's harvest round (12:15Z) dropped it, and the director's diagnosis was
    charter 2.5's: the ruling had gone into a GitHub comment and into the
    `test_set.md` archive, not into a field the batch desk reads.  The
    remedy applied that round was to write it into `batch-desk.md`'s harvest
    checklist, immediately below the GH #412 ruling that the SAME ROUND had
    obeyed.
  * W39's harvest round (18:30Z) dropped it AGAIN -- out of the field it had
    just been delivered into.

So the 2.5 remedy is not sufficient, and W39 says why in its own report.  A
harvest round is driven by `W<N>_wave.json:harvest_obligations`, a per-wave
machine-read list; the desk's report walks it item by item ("十二条").  GH
#412 is item 10 of that list.  GH #413 is charter prose, because the list is
authored AT LAUNCH and a STANDING obligation -- one that belongs to no
particular wave -- has no row to be authored into.  The desk then audited
itself against the list, found twelve of twelve, and was right.

    A complete-looking checklist is what a dropped standing baton looks
    like, for the same reason `W28_wave.json`'s `skip_not_pass_lines`
    enumerated seven absences without room for the eighth (GH #332): the
    missing item has nowhere to be missing FROM.

Hence: not a fourth copy of the ruling, but a home that is machine-read, not
wave-scoped, and run by every stream in every round.  There is exactly one
such surface -- `routine_selfcheck.sh` -- so the registry lives at
`iterations/owed_executions.json` and is read here, under its own selfcheck
leg (`owed-executions`) so that GH #267's attribution names it rather than
folding it into `queue-rulings`.

Each row carries a `done_when` the ruling itself can state as an acceptance
criterion, and the three states are DONE / OWED / UNCERTIFIABLE.  The
asymmetry is deliberate and is the whole point of the file: a condition that
could not be READ is never reported as executed.

LIMITS FOR THE OWED LEG (in addition to 1-8 below)
---------------------------------------------------
9.  **It cannot see a ruling nobody registered.**  Same shape as
    `test_wave_gate_keys.py`'s own last limit -- the list is maintained by
    hand, from the director's rulings, and is not derived from anything.
    Registering the row IS the act being asked for; the leg only makes
    forgetting it visible afterwards.
10. **A row is only as good as its `done_when`.**  `kind: manual` is
    honestly available and buys nothing but a recurring reminder, so it is
    reported as OWED with that said in as many words.  A `done_when` that
    checks the wrong artefact reads DONE while the baton is still on the
    floor, and no test in this repo can tell.
11. **It grades the artefact, never the work.**  §DO's row asks whether the
    committed profile says `rec_slots: 8`; it cannot ask whether the corpus
    behind it was W37+W38.
12. **A claim is a say-so, and the tool cannot check it.**  `claimed_by` /
    `claimed_at` (GH #518) buy one thing: an owed row that somebody has
    STARTED reads IN-FLIGHT instead of OWED, so the second session of the
    round does not redo the first session's work unit.  Three things it does
    not buy, each of which has to stay said out loud because the field looks
    like it buys them:
      * it is **not a lock** -- taking a claimed row is allowed, and the
        taker is asked to say why in their report;
      * it cannot tell a live claimant from a dead one, only from an old one
        (`CLAIM_TTL_HOURS`), nor a genuine claim from a row re-claimed every
        round to keep the leg quiet -- the director's health sweep reads the
        claim lines, and that is the only check there is;
      * it works only if the claim was **pushed before the work** and the
        reader's clone is fresh.  A claim that lands with the finished work
        is a record, not a signal.
    An unreadable or half-written claim reads OWED, never IN-FLIGHT: the
    conservative side of this leg is the one that keeps the baton visible.

LIMITS (read these before quoting the output)
---------------------------------------------
1. **It reports a problem, not a verdict.**  An un-ruled OTHER request may be
   legitimately parked behind a wave slot that does not exist yet
   (`RECEIVED_NOT_SCHEDULED` is a real ruling, and this tool cannot tell an
   un-ruled request from one whose ruling belongs to a future round).
2. **The RIDESHARE test is a text match** on the request's own declaration,
   read across `axis` + `question` + `acceptance` (see `DECLARATION_FIELDS`).
   A proposal that rides a wave without saying so reads as OTHER; a proposal
   that says so falsely reads as RIDESHARE.  Judge the quoted line.  It does
   NOT read `director` / `result` / `notes`: a marker there is somebody else's
   sentence about the request (a cost note, a ruling), not the requester's
   declaration, and reading it would classify a dedicated-wave ask as a
   rideshare on the strength of the batch desk's own bookkeeping.
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

THE DOMAIN PRICE, PRINTED ON THE ROW (2026-09-01T2x:xxZ, director; §DG.7.1)
---------------------------------------------------------------------------
Three consecutive strategy rounds landed a gated fix whose subject hero has
ZERO appearances in the frame corpus (`tormself`, `immguard`/brewmaster,
`hpbool`/tiny).  Iron rule 2 condition (a) -- the replay group confirms the
change really executes -- **cannot be bought at the fixture level for a hero
who never appears**, so all three were pre-destined to come back DOMAIN-EMPTY.

The strategy stream built the reading that answers this in seconds
(`tools/agent/corpus_hero_census.py`, 2026-09-01T19:21Z) and asked the
director to make it a standing pre-admission step.  A step is a checklist
line, and this file's own charter measured a checklist line's follow-through
at 1/6.  So it is wired **here** instead: onto the un-ruled row itself, in
the one view a ruling is written from.  The price is not something the
director must remember to look up; it is on screen next to the id being
ruled.

It stays INFORMATIONAL on purpose (LIMIT 8).  A DOMAIN-EMPTY subject is a
fact the ruling has to weigh -- often the reason to hold a lever rather than
arm it -- not a defect in the request, and reddening every round on a fact
nobody can fix is how a detector stops being read (GH #276).

Exit codes: 0 = no un-ruled RIDESHARE request; 3 = at least one (a finding,
not a failure).  OTHER-bucket entries and the domain price never change the
exit code.

8. **The domain price is NECESSARY-only, and it is textual.**  `corpus 0`
   means a fixture-level acceptance is impossible; `corpus >0` means only
   that it is not ruled out -- the decision domain still has to be reachable
   on one of those frames, which no census can see.  Subjects are read as
   `bots/BotLib/hero_<x>.lua` paths named in the request's own prose, so a
   request that never names its file gets no price line (silence here is
   "not asked", never "present"), and a shared-code lever correctly gets
   none because every hero in the corpus is its domain.  When the census
   itself cannot run, the row says UNCERTIFIABLE -- which is not a pass.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
QUEUE = os.path.join(REPO, "iterations", "queue.json")
TEST_SET = os.path.join(REPO, "iterations", "streams", "test_set.md")
STATE = os.path.join(REPO, "iterations", "state.json")
OWED = os.path.join(REPO, "iterations", "owed_executions.json")

# The vocabulary, after the GH #317 ruling (director 2026-08-30).  CLOSED is
# the authoritative half: a row is open unless it says one of these.  OPEN
# stays listed because it is the vocabulary streams are asked to write, and
# because `unknown_status_rows` reports anything outside the pair -- but it is
# no longer what `is_open` keys off.
OPEN_STATES = ("pending", "running", "harvested")
CLOSED_STATES = ("done", "rejected")

# How long a pushed claim keeps reading IN-FLIGHT before it falls back to OWED
# (GH #518, director 2026-09-05; test_set.md §ER.2 / §ES).
#
# The number is picked from the collision it exists to stop, not from taste.
# On 2026-09-05 two director sessions took `mock_getvelocity_ultloc` in the
# same window: one ran 03:5x-08:xxZ (~4h04m), the other 06:5x-07:3xZ (~40m),
# overlapping by ~35 minutes.  A TTL shorter than the LONGER session re-opens
# exactly that case -- the first session's claim would have expired at 09:5xZ
# under a 6h TTL but at 06:5xZ under 3h, i.e. right as the second session
# started reading.  So 6h, and the failure directions are asymmetric on
# purpose: an over-long claim is LOUD (the row prints IN-FLIGHT with the
# claimant and the age, and a claim is never a lock), while a too-short one is
# SILENT (two OWED rows that look identical, which is the whole defect).
CLAIM_TTL_HOURS = 6

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


# The prose fields a rideshare declaration is actually written into.  Same
# triple as SUBJECT_FIELDS below and for the same reason -- a stream writes the
# framing of its request wherever it fits, not into a field this tool named --
# but kept as a separate constant on purpose: the two answer different
# questions, and narrowing one later must not silently narrow the other.
#
# `director` / `result` / `notes` are deliberately absent; see LIMIT 2.
DECLARATION_FIELDS = ("axis", "question", "acceptance")


def is_rideshare(req):
    """Does the request declare, in its own prose, that it rides a wave?

    Reads all three prose fields.  It used to read `question` alone, and that
    is how §BB.4's "rule it this round" obligation went eight rounds without
    firing once for the requests it was written for.

    MEASURED on the real queue the day this was fixed (2026-09-04, 71 rows):
    59 rows declare a rideshare in their prose, and **23 of them declare it
    nowhere but `axis` or `acceptance`** -- so the bucket answered `none` while
    they sat in OTHER.  The founding observation (director, 2026-09-02) was
    three such rows whose `axis` read, verbatim, the phrase this predicate
    matches on: 搭车、零 AWS 增量、不申请专波.  Every one of the 23 was checked
    by hand for a negated or quoted use before this widened; there were none,
    and none of them asks for a wave.

    Same family as GH #317 on `is_open` and GH #332 / §DR: the leg that exists
    to raise a hand for a class of row was reading a place that class does not
    write to, and its `none` was indistinguishable from a clean queue.  The
    failure direction is the argument for widening rather than the tidiness of
    it: an over-inclusive RIDESHARE bucket costs one extra look in some round,
    where the under-inclusive one cost the obligation its entire visibility.
    """
    text = " ".join(str(req.get(field) or "") for field in DECLARATION_FIELDS)
    return any(marker in text for marker in RIDESHARE_MARKERS)


# ------------------------------------------------------------- domain price
# A hero file's subject is its filename (AGENTS.md: the engine loads
# `bots/BotLib/hero_<internal_name>.lua` by fixed path), so the path IS the
# subject and no name mapping is needed.  Only the BotLib form is read:
# `bots/mode_*.lua`, `bots/FunLib/*` and the generic overrides have every
# hero in the corpus as their domain and owe nothing here.
HERO_FILE_IN_PROSE = re.compile(r"bots/BotLib/hero_([a-z_0-9]+)\.lua")

# The prose fields a request writes its own subject into.  `bundle` and `id`
# are deliberately NOT read: a bundle name is not a path, and guessing a
# subject from an id is how a census starts answering questions it was not
# asked.
SUBJECT_FIELDS = ("axis", "question", "acceptance")


def subjects_of(req):
    """Hero subjects this request names by file path, sorted, de-duplicated."""
    text = " ".join(str(req.get(k) or "") for k in SUBJECT_FIELDS)
    return sorted(set(HERO_FILE_IN_PROSE.findall(text)))


def _census():
    """(counts, weak) from the real census tool, or (None, None) if it cannot run.

    Imports `corpus_hero_census` rather than re-walking the corpus: two
    implementations of "is this hero present" would drift, and the one that
    drifts silently is the copy nobody tests.
    """
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import corpus_hero_census as census
        seen, counts, _games = census.collect()
        if seen == 0:
            return None, None
        return counts, census.weak_heroes()
    except Exception:          # noqa: BLE001 -- could-not-run, reported as such
        return None, None


def domain_price(req, counts, weak):
    """-> list of (hero, count, on_weak_list) for the subjects this row names."""
    return [(h, counts.get(h, 0), bool(weak) and h in weak)
            for h in subjects_of(req)]


# A ruling that holds a lever for an empty corpus is the one ruling that
# REMOVES its own row from the un-ruled buckets while leaving real work owed.
# Iron rule 9's founding case is exactly that shape -- the creep-pull fix
# vanished from every queue for 37 rounds because closing its issue was
# mistaken for finishing it.  So the hold is spelled in the machine field, and
# the watch below carries the baton until the archive answers.
HOLD_RULING = "HOLD-DOMAIN-EMPTY"


def held_for_domain(requests):
    """Open rows whose ruling holds them until their subject enters the corpus."""
    out = []
    for req in requests:
        if not is_open(req):
            continue
        director = req.get("director")
        if not isinstance(director, dict):
            continue
        if str(director.get("ruling") or "").strip().upper().startswith(HOLD_RULING):
            out.append(req)
    return out


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


# ------------------------------------------------------------- OWED_EXECUTION

def load_owed(path=OWED):
    """Read the owed-execution registry.  A missing file is an EMPTY registry.

    That asymmetry is deliberate.  The registry is written by hand, so "no
    file" is the honest state of a tree in which no ruling has been
    registered -- there is nothing to be silent ABOUT.  A file that exists
    and cannot be parsed is a different animal and is reported (main()).
    """
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return json.load(fh).get("owed", [])


def owed_status(row, repo=REPO):
    """Evaluate one row's `done_when`.  Returns (state, detail).

    state is DONE / OWED / UNCERTIFIABLE.  A condition that could not be READ
    yields UNCERTIFIABLE, never DONE (GH #171's rule, and here the failure
    direction is what matters: a vanished artefact must not read as
    "executed").
    """
    cond = row.get("done_when") or {}
    kind = cond.get("kind")
    if kind == "manual":
        return ("OWED",
                "no machine check (kind=manual) -- this row is a reminder, not a gate")
    if kind not in ("json_value", "path_exists", "path_absent"):
        return "UNCERTIFIABLE", "done_when kind %r is not one this tool can read" % (kind,)
    rel = cond.get("path") or ""
    full = os.path.join(repo, rel)
    if kind == "path_exists":
        there = os.path.exists(full)
        return ("DONE" if there else "OWED",
                "%s %s" % (rel, "exists" if there else "does not exist yet"))
    if kind == "path_absent":
        there = os.path.exists(full)
        return ("DONE" if not there else "OWED",
                "%s %s" % (rel, "is still there" if there else "is gone"))
    try:
        with open(full, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError) as exc:
        return "UNCERTIFIABLE", "could not read %s (%s)" % (rel, exc)
    key = cond.get("key")
    if not isinstance(doc, dict) or key not in doc:
        return "UNCERTIFIABLE", "%s carries no key %r" % (rel, key)
    got, want = doc[key], cond.get("equals")
    return ("DONE" if got == want else "OWED",
            "%s:%s = %r (the ruling's acceptance criterion is %r)" % (rel, key, got, want))


def parse_utc(text):
    """Parse an ISO-8601 UTC stamp, or return None.

    Deliberately strict.  The house style for report and charter prose is a
    FUZZED stamp -- `2026-09-05T07:xxZ` -- and that is not a time; a claim
    written that way must not silently become a six-hour hold on somebody
    else's work unit.  It reads UNREADABLE, which falls back to OWED.
    """
    if not isinstance(text, str) or not text.strip():
        return None
    raw = text.strip()
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    try:
        stamp = datetime.datetime.fromisoformat(raw)
    except ValueError:
        return None
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=datetime.timezone.utc)
    return stamp.astimezone(datetime.timezone.utc)


def claim_status(row, now=None):
    """Evaluate one row's claim.  Returns (state, detail).

    state is UNCLAIMED / IN-FLIGHT / EXPIRED / UNREADABLE.

    WHY THIS EXISTS (GH #518, director 2026-09-05; test_set.md §ER.2)
    -----------------------------------------------------------------
    `mock_getvelocity_ultloc` named its executor "director 或 协同组(谁先取到)"
    and its trigger "any round with slack can take it".  Those two sentences
    hand "who does it" to first-come-first-served while the row carries NO
    FIELD saying somebody already started -- so a row being worked on and a
    row nobody has ever touched are byte-for-byte identical to the second
    reader.  Two sessions did the right thing on 2026-09-05 and one whole work
    unit was thrown away.  Note the direction: the OWED leg raises its hand at
    every session every round, and the PURPOSE of that hand is to make someone
    take the row -- so the better this leg works, the more certain the
    collision.  Same root as backlog §6b's false-abandonment: a presence field
    cannot separate "nobody is on it" from "somebody is in flight".

    THE THREE THINGS THIS IS NOT
    ----------------------------
    * **Not a lock.**  A claim is an activity signal.  Anyone may still take a
      claimed row -- believing the claimant died is a legitimate reason -- and
      is asked to say so in their report.  Making it a lock would import
      §6b's cost with the sign flipped: a dead claimant would park a baton
      permanently.
    * **Not retroactive.**  The claim has to be PUSHED before the work, not
      written next to it at the end.  A claim that reaches `origin/main` after
      the collision window is a record, not a signal -- the second session
      reads the tree it cloned at start.
    * **Not evidence of progress.**  It says a session said it started.  The
      `done_when` still grades the artefact, unchanged (LIMIT 11).
    """
    now = now or datetime.datetime.now(datetime.timezone.utc)
    by, at = row.get("claimed_by"), row.get("claimed_at")
    if by is None and at is None:
        return "UNCLAIMED", "no claim on this row"
    if row.get("claimable") is False:
        # A standing CONSTRAINT (`mock_isprefix_ordering`: "don't relax `^Is`
        # before the `^Get` roster is done") is not a baton anybody takes --
        # it has no completion state, and its entire job is to say OWED in
        # every round until the day somebody is about to violate it.  Letting
        # a claim quiet such a row for six hours would be this fix building
        # the very silence it was written against, so the claim is refused
        # rather than honoured.
        return ("UNREADABLE",
                "row is claimable:false (a standing constraint, not a takeable "
                "baton -- it is SUPPOSED to report OWED every round); the claim "
                "by %r is ignored" % (by,))
    if not by or not at:
        # Half a claim names nobody or no instant.  Falling back to OWED is
        # the conservative side here: the cost is a possible collision, while
        # honouring it would suppress real work on an unreadable say-so.
        return ("UNREADABLE",
                "claim is half-written (claimed_by=%r claimed_at=%r); both are "
                "required -- reading this as OWED" % (by, at))
    stamp = parse_utc(at)
    if stamp is None:
        return ("UNREADABLE",
                "claimed_at=%r is not an ISO-8601 UTC instant (the fuzzed house "
                "style `T07:xxZ` is not a time) -- reading this as OWED" % (at,))
    age_h = (now - stamp).total_seconds() / 3600.0
    if age_h < 0:
        return ("UNREADABLE",
                "claimed_at=%s is in the future -- reading this as OWED" % (at,))
    if age_h <= CLAIM_TTL_HOURS:
        return ("IN-FLIGHT",
                "claimed by %s at %s (%.1fh ago, expires after %dh) -- a claim "
                "is an activity signal, NOT a lock" % (by, at, age_h, CLAIM_TTL_HOURS))
    return ("EXPIRED",
            "claimed by %s at %s (%.1fh ago, past the %dh TTL) -- treat as "
            "unclaimed; the claimant may have died mid-round"
            % (by, at, age_h, CLAIM_TTL_HOURS))


def render_owed(rows, now=None):
    """Print the OWED_EXECUTION section.  Returns the exit level (0 or 3)."""
    print("=== owed executions (rulings delivered; execution still owed) ===")
    print("registry rows: %d" % len(rows))
    finding = False
    inflight = 0
    for row in rows:
        state, detail = owed_status(row)
        claim, claim_detail = claim_status(row, now=now)
        # The claim can only soften a row that is still owed.  A DONE row's
        # claim is bookkeeping -- it must not turn "retire me" into "somebody
        # is on it", which would be a claim outranking the artefact.
        shown = "IN-FLIGHT" if (state == "OWED" and claim == "IN-FLIGHT") else state
        head = "  %-11s %-22s %-10s executor=%s" % (
            shown, row.get("id", "?"), row.get("issue", "?"), row.get("executor", "?"))
        print(head)
        print("      trigger: %s   ruled_at: %s"
              % (row.get("trigger", "?"), row.get("ruled_at", "?")))
        print("      done_when: %s" % detail)
        if claim != "UNCLAIMED":
            if state == "DONE":
                # Say who held it, but never in the IN-FLIGHT vocabulary: on a
                # row whose artefact has arrived, "somebody is on it" is a
                # stale sentence sitting one line under "retire this row".
                print("      claim: bookkeeping only (row is DONE) -- held by %r at %r"
                      % (row.get("claimed_by"), row.get("claimed_at")))
            else:
                print("      claim: %s -- %s" % (claim, claim_detail))
        missed = row.get("missed") or []
        if missed:
            print("      already missed %d round(s):" % len(missed))
            for m in missed:
                print("        - %s" % m)
        if state == "DONE":
            # The baton arrived.  Say so and ask for the row to be retired --
            # a registry nobody prunes becomes wallpaper, which is the GH #276
            # failure this file keeps being warned about.
            print("      -> executed; the director should retire this row")
        elif shown == "IN-FLIGHT":
            inflight += 1
            print("      -> somebody is already on this one; prefer another baton. "
                  "Taking it anyway is allowed -- say in your report why.")
        else:
            finding = True
    if not rows:
        print("OWED_EXECUTION: none")
    if inflight:
        # Printed because the exit code alone would now under-report: an
        # all-in-flight registry exits 0, and "clean read" must not be
        # mistaken for "nothing is owed".  Same sentence family as the
        # RIDESHARE/OTHER counters above.
        print("OWED_EXECUTION: %d in flight (claimed within %dh) -- NOT a finding "
              "this round, and NOT executed either" % (inflight, CLAIM_TTL_HOURS))
    return 3 if finding else 0


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
    ap.add_argument("--owed", default=OWED)
    ap.add_argument("--owed-only", action="store_true",
                    help="print ONLY the OWED_EXECUTION section (its own "
                         "selfcheck leg, so GH #267 attribution names it)")
    args = ap.parse_args()

    if args.owed_only:
        # Deliberately the only mode in which this section prints.  A section
        # that appeared in the default run too would either lie in the exit
        # attribution (`queue-rulings` blamed for an owed baton) or print
        # without counting -- and "printed but does not count" is the exact
        # family of defect this file exists to stop.
        try:
            rows = load_owed(args.owed)
        except (OSError, ValueError) as exc:
            print("=== owed executions (rulings delivered; execution still owed) ===")
            print("UNCERTIFIABLE -- could not read %s (%s). This line is NOT a pass."
                  % (args.owed, exc))
            return 2
        return render_owed(rows)

    requests = load_requests(args.queue)
    ride, other = partition(requests)

    counts, weak = _census()

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
            subjects = subjects_of(r)
            if not subjects:
                continue                      # LIMIT 8: not asked, not "present"
            if counts is None:
                print("      DOMAIN price UNCERTIFIABLE -- the corpus census could "
                      "not run; this line is NOT a clean read (subjects: %s)"
                      % ", ".join(subjects))
                continue
            for hero, n, on_weak in domain_price(r, counts, weak):
                if n == 0:
                    print("      DOMAIN-EMPTY  %s: corpus 0 -- condition (a) CANNOT "
                          "be bought at the fixture level; hold the lever or "
                          "expect a DOMAIN-EMPTY harvest" % hero)
                else:
                    print("      domain        %s: corpus %d file(s)%s -- present is "
                          "NECESSARY, not sufficient"
                          % (hero, n, " [WeakHeroes]" if on_weak else ""))

    print("=== un-ruled queue requests (director field empty) ===")
    render(ride, "RIDESHARE (§BB.4: rule this round)")
    render(other, "OTHER (routing/slot ruling still owed)")
    print("total open requests: %d" % sum(1 for r in requests if is_open(r)))

    # ------------------------------------------------------------ domain watch
    held = held_for_domain(requests)
    unblocked = []
    if held:
        print("\n=== domain watch (rows held until their subject enters the corpus) ===")
        for r in held:
            for hero, n, _weak in (domain_price(r, counts, weak) if counts is not None
                                   else []):
                if n == 0:
                    print("  %-12s %-16s corpus 0   STILL BLOCKED -- the hold stands"
                          % (r.get("id"), hero))
                else:
                    unblocked.append((r.get("id"), hero, n))
                    print("  %-12s %-16s corpus %-3d UNBLOCKED -- the archive now "
                          "carries this subject; RE-RULE the row"
                          % (r.get("id"), hero, n))
            if counts is None:
                print("  %-12s UNCERTIFIABLE -- the census could not run, so whether "
                      "the hold still stands was NOT read this round" % r.get("id"))

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

    # An UNBLOCKED hold reddens: unlike the price itself (LIMIT 8, a standing
    # fact), it is a state CHANGE that owes a re-ruling, it is rare, and the
    # director clears it in-round -- so it cannot become the every-round noise
    # GH #276 warns about.
    return 3 if (ride or orphans or unblocked) else 0


if __name__ == "__main__":
    sys.exit(main())
