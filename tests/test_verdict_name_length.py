#!/usr/bin/env python3
"""[GH #167] The validation/ basename must fit NAME_MAX -- for TODAY's armed
string and for the one after it.

WHY THIS EXISTS
    The verdict basename was "<armed-string>_<stamp>.verdict.json" verbatim.
    The armed string only ever grows (16 ids -> 26 = 232 bytes -> 28 -> 29), so
    W7's basename hit 266 bytes and `s3 cp --recursive validation/` failed with
    [Errno 36] for EVERY file, exit non-zero, nothing landed.  Nothing warned
    when the string crossed 255: the first symptom was a harvest that read like
    a clean run under `| tail` and produced zero files.

    The interesting half is not "266 > 255".  It is that the failure was a
    FUNCTION OF A NUMBER THAT ONLY GOES UP, and no test named that number.  So
    this file pins the length at the growth frontier, not at today's value: a
    32-id string (three rulings past the current 29) must still fit.  When that
    stops being enough headroom the assertion is what says so.

HOW IT TESTS
    It runs the REAL helper (tools/batch_test/soak/soak_name.sh) -- the same
    bytes both call sites run -- on real strings.  It does not reimplement the
    naming rule and check its own arithmetic; a test that owns a second copy of
    the format is the shape test_soak_cand_ref.py's header calls out, and a
    second copy of THIS format is what let the verdict name and the run.log
    name drift into the same bug twice.

    M1 mutation: drop the collapse (return "$CAND$SUFFIX" always) -> case 2/3 red.
    M2 mutation: collapse ALWAYS (even short strings) -> case 1 red.
    M3 mutation: let a call site build the name inline again -> case 5 red.
"""
import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HELPER = os.path.join(ROOT, "tools", "batch_test", "soak", "soak_name.sh")
VALIDATE = os.path.join(ROOT, "tools", "batch_test", "soak", "validate_onspot.sh")
SPOT_RUN = os.path.join(ROOT, "tools", "batch_test", "aws", "spot_run.sh")

NAME_MAX = 255

# The live member string, read off the archive rather than hardcoded, so this
# test tracks the test set instead of a snapshot of it.
TEST_SET = os.path.join(ROOT, "iterations", "streams", "test_set.md")

failures = []
checks = []


def check(cond, label, detail=""):
    checks.append(label)
    if cond:
        print("PASS  %s" % label)
    else:
        print("FAIL  %s%s" % (label, ("\n      " + detail) if detail else ""))
        failures.append(label)


def name(cand, suffix):
    """The helper's stdout, or a sentinel when it refuses.

    A refusal is returned rather than raised so that a mutant which makes the
    helper refuse shows up as a NAMED red check instead of a traceback that
    stops the file halfway and hides the checks after it.
    """
    r = subprocess.run(["bash", HELPER, cand, suffix],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return "<REFUSED exit=%d %s>" % (r.returncode, r.stderr.strip())
    return r.stdout


def live_member_string():
    with open(TEST_SET, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            # The member string is the first bare comma-joined id line.
            if line and "," in line and re.fullmatch(r"[a-z0-9_,]+", line):
                return line
    return ""


VERDICT_SUFFIX = "_20260824_181423_4-32.verdict.json"
RUNLOG_SUFFIX = "_20260824_1814_run.log"

# ---------------------------------------------------------------- case 1
# Short strings pass through VERBATIM.  Every basename already in the bucket
# keeps meaning what it meant, and an isolation wave (1-3 ids) stays readable.
short = "creeppull,pullbeat"
check(name(short, VERDICT_SUFFIX) == short + VERDICT_SUFFIX,
      "case 1: short armed string is kept verbatim",
      "got %r" % name(short, VERDICT_SUFFIX))

# A string sitting just UNDER the limit is still verbatim -- the boundary is
# NAME_MAX itself, not a safety margin someone will later mistake for the rule.
edge = "a" * (NAME_MAX - len(VERDICT_SUFFIX))
check(name(edge, VERDICT_SUFFIX) == edge + VERDICT_SUFFIX,
      "case 1b: a basename of exactly NAME_MAX bytes is not collapsed")

# ---------------------------------------------------------------- case 2
# The string that actually broke: W7's 26 ids.
W7 = ("l1trade,l5combo,midtp,suptp,tpcommit,tpdying,lf_rescue,teambrain,ownhalf,"
      "overchase,fieldregen,wandbleed,capmono,cmrguard,tpdead,zusult,wandlimbo,"
      "blinkflee,liondrainstop,odaoe,pullcamp,stayfield,stayfield2,fieldbuy,"
      "fieldcreep,pullcad")
check(len((W7 + VERDICT_SUFFIX).encode()) > NAME_MAX,
      "case 2a: the W7 basename really did overflow (regression anchor)",
      "%d bytes" % len((W7 + VERDICT_SUFFIX).encode()))
w7name = name(W7, VERDICT_SUFFIX)
check(len(w7name.encode()) <= NAME_MAX,
      "case 2b: W7's basename now fits",
      "%d bytes: %s" % (len(w7name.encode()), w7name))

# ---------------------------------------------------------------- case 3
# The growth frontier.  Today's set is 29; assert three rulings of headroom.
# Both suffixes, because run.log is only ~12 bytes shorter than the verdict --
# it does not escape the bug, it arrives one wave later.
live = live_member_string()
check(bool(live), "case 3a: the member string is readable from test_set.md")
n_live = len([x for x in live.split(",") if x]) if live else 0
grown = live + "".join(",futureid%d" % i for i in range(1, 4)) if live else ""
for label, suffix in (("verdict", VERDICT_SUFFIX), ("run.log", RUNLOG_SUFFIX)):
    for what, s in (("live (%d ids)" % n_live, live), ("live+3", grown)):
        if not s:
            continue
        got = name(s, suffix)
        check(len(got.encode()) <= NAME_MAX,
              "case 3: %s basename fits for %s" % (label, what),
              "%d bytes: %s" % (len(got.encode()), got))

# ---------------------------------------------------------------- case 4
# A collapsed name stays human-identifiable AND machine-recoverable: two
# different armed strings must not collide, and the sha1 must be reproducible
# from the `cand` field the verdict JSON already carries.
sha = hashlib.sha1(W7.encode()).hexdigest()[:12]
check(w7name == "l1trade+26ids-%s%s" % (sha, VERDICT_SUFFIX),
      "case 4a: collapsed name = <first-id>+<n>ids-<sha1[:12]>",
      "got %s" % w7name)
other = W7 + ",tpreach"
check(name(other, VERDICT_SUFFIX) != w7name,
      "case 4b: two different armed strings collapse to different names")

# ---------------------------------------------------------------- case 5
# Neither call site may rebuild the name inline.  Two copies of this format is
# how the verdict object and the run.log object ended up with the same bug --
# and only one of them was reported.
for path, label in ((VALIDATE, "validate_onspot.sh"), (SPOT_RUN, "spot_run.sh")):
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    body = "\n".join(l for l in src.splitlines() if not l.lstrip().startswith("#"))
    inline = re.findall(r"validation/\$\{?(?:CAND|vcand)\b", body)
    check(not inline,
          "case 5: %s builds the validation/ basename via soak_name.sh" % label,
          "inline construction still present: %r" % inline)
    check("soak_name.sh" in body,
          "case 5b: %s calls the helper" % label)

# ---------------------------------------------------------------- case 6
# An impossible suffix must FAIL LOUDLY.  The defect being fixed was a silent
# overflow; a silent truncation would be the same defect with a different tail.
r = subprocess.run(["bash", HELPER, W7, "_" + "x" * 300], capture_output=True, text=True)
check(r.returncode != 0 and "255" in r.stderr,
      "case 6: an unfixable suffix exits non-zero and says why",
      "exit %d, stderr %r" % (r.returncode, r.stderr.strip()))

print("\n%d checks, %d failed" % (len(checks), len(failures)))
sys.exit(1 if failures else 0)
