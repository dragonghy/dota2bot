#!/usr/bin/env python3
"""Assertions for the condition-(a) route census (`tools/agent/a_evidence_route.py`).

WHAT IS PINNED AND WHY, in the order the census can hurt someone:

  SECTION 1 -- THE DENOMINATOR RATCHET.  Every failure mode of this census
  produces a SMALLER, CLEANER-LOOKING answer, never an error: with no wave
  records every id reads NO-CORPUS, with no behavioural tools every id with a
  corpus reads BUILD, and both read as "a finished census that found a lot of
  debt".  That is the same shape as the two defects `gated_getter_stub_census`
  shipped with (§GG), and a director who quoted either would have withdrawn ids
  from the test set for a reason that was about the reader.  So each empty
  denominator is asserted to be exit 2, and exit 2 is asserted to print
  nothing that could be mistaken for a census.

  SECTION 2 -- THE PARTITION.  One class per id, all five classes reachable,
  and the sum equals the id count.  A census whose buckets do not add up is
  reporting a number about itself.

  SECTION 3 -- THE TWO DISCRIMINATORS THAT WERE MEASURED, NOT CHOSEN.
    (i) membership is read from the `arm_string` FIELD, never by substring over
        the wave record: those records name withdrawn ids in prose
        (`arm_delta_vs_W57`: "REMOVED: `tpdead`, `wandlimbo`"), so a substring
        scan over-counts exactly the ids a ruling is about.  Measured on the
        real tree while this was written: substring said `pulldrag` rode 13
        waves, the field says 10.
    (ii) DELIVER requires the id in the tool's SUBJECT line, not merely in its
        head.  A filename rule was tried first and got `liondrainstop` wrong --
        its purpose-built condition-(a) census is named after the hero
        (`lion_drain_census.py`) -- while a head-anywhere rule promotes
        `ownhalf` on the strength of `capmono_refusal.py` naming it as a
        CONFOUNDER ("`ownhalf` ... push the other way").  Both errors are
        represented here as fixtures, so neither rule can come back silently.

  SECTION 4 -- THE LIVE TREE, INVARIANTS ONLY.  Numbers on the real repo change
  every wave; asserting them here would make this file a liability.  What is
  asserted is what must hold on any tree: exit 0, non-zero denominators, and
  the partition.

EXIT: 0 pass, 1 an assertion failed, 2 could not run.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "agent", "a_evidence_route.py")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL %s" % label)


def run(args):
    p = subprocess.run([sys.executable, TOOL] + args,
                       capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def build_tree(base, ids, waves, tools, reports):
    """waves: {name: arm_string or None-with-prose}; tools: {file: text};
    reports: {file: text}."""
    ts = os.path.join(base, "test_set.md")
    with open(ts, "w", encoding="utf-8") as fh:
        fh.write("# synthetic test set\n%s\n" % ",".join(ids))
    wdir = os.path.join(base, "waves")
    bdir = os.path.join(base, "behavioral")
    rdir = os.path.join(base, "reports")
    for d in (wdir, bdir, rdir):
        os.makedirs(d, exist_ok=True)
    for name, rec in waves.items():
        with open(os.path.join(wdir, name), "w", encoding="utf-8") as fh:
            json.dump(rec, fh)
    for name, text in tools.items():
        with open(os.path.join(bdir, name), "w", encoding="utf-8") as fh:
            fh.write(text)
    for name, text in reports.items():
        with open(os.path.join(rdir, name), "w", encoding="utf-8") as fh:
            fh.write(text)
    return ["--test-set", ts, "--waves", wdir, "--behavioral", bdir,
            "--reports", rdir]


def rows_of(out):
    """Parse the printed table into {id: (class, verify, waves)}."""
    got = {}
    started = False
    for line in out.splitlines():
        if line.startswith("id  "):
            started = True
            continue
        # The table ends at LIMITS.  Without this break the prose below it
        # ("* DELIVER says a tool DECLARES ...") parses as a row whose id is
        # `*` -- caught the first time this file ran, and worth keeping as a
        # comment: a loose reader of a tool's own output is the same defect
        # class the tool is about.
        if line.startswith("LIMITS"):
            break
        if not started or not line.strip() or line[0].isspace():
            continue
        f = line.split()
        if len(f) >= 4 and f[1] in ("VERIFIED", "DELIVER", "MENTION", "BUILD",
                                    "NO-CORPUS"):
            got[f[0]] = (f[1], int(f[2]), int(f[3]))
    return got


# ---------------------------------------------------------------- fixtures
SUBJECT_TOOL = (
    '#!/usr/bin/env python3\n'
    '"""`alpha` condition (a): does the guard actually refuse?\n\n'
    'Long body text that mentions beta far below the subject line.\n'
    '%s\n'
    'beta appears only here, deep in the head, as a confounder note.\n"""\n'
) % ("filler line\n" * 40)

CONFOUNDER_TOOL = (
    '#!/usr/bin/env python3\n'
    '"""gamma clean-domain refuse-collapse rate: two-arm DiD verifier.\n\n'
    'WHY DiD AND NOT A SINGLE ARM\n'
    '  A single armed arm cannot isolate gamma: delta pushes the other way.\n"""\n'
)

FAR_TOOL = (
    '#!/usr/bin/env python3\n'
    '"""epsilon domain census.\n\n'
    '%s\n'
    'zeta is named only here, past the head window.\n"""\n'
) % ("padding line to push the next mention past HEAD_CHARS\n" * 120)


def main():
    if not os.path.exists(TOOL):
        print("COULD NOT RUN: %s missing" % TOOL)
        return 2

    base = tempfile.mkdtemp(prefix="aer_test_")
    try:
        # ---------------------------------------------------- section 1
        print("section 1 -- the denominator ratchet")
        ids = ["alpha"]
        good_waves = {"W1_wave.json": {"wave": "W1", "arm_string": "alpha"}}
        good_tools = {"alpha_domain.py": SUBJECT_TOOL}
        good_reports = {"r.md": "nothing here\n"}

        args = build_tree(base, ids, good_waves, good_tools, good_reports)
        rc, out, err = run(args)
        check(rc == 0, "healthy tree exits 0 (got %d)" % rc)
        check("A-EVIDENCE-ROUTE" in out, "healthy tree prints the census")

        empty = tempfile.mkdtemp(prefix="aer_empty_")
        for flag in ("--waves", "--behavioral", "--reports"):
            a2 = list(args)
            a2[a2.index(flag) + 1] = empty
            rc, out, err = run(a2)
            check(rc == 2, "%s empty => exit 2 (got %d)" % (flag, rc))
            check("A-EVIDENCE-ROUTE" not in out,
                  "%s empty prints no census table" % flag)
            check("AER_COULD_NOT_RUN" in err,
                  "%s empty says why on stderr" % flag)

        # A wave record with no arm_string field is not a corpus record.  If
        # this were tolerated, a directory of malformed records would read as
        # "every id NO-CORPUS", which is a withdrawal recommendation for the
        # entire test set.
        b2 = tempfile.mkdtemp(prefix="aer_noarm_")
        a2 = build_tree(b2, ids, {"W1_wave.json": {"wave": "W1"}},
                        good_tools, good_reports)
        rc, out, err = run(a2)
        check(rc == 2, "wave records without arm_string => exit 2 (got %d)" % rc)
        check("none carried a parseable arm_string" in err,
              "unparseable waves name themselves on stderr")
        shutil.rmtree(b2, ignore_errors=True)

        # ---------------------------------------------------- section 2
        print("section 2 -- the partition, all five classes")
        b3 = tempfile.mkdtemp(prefix="aer_cls_")
        ids = ["alpha", "beta", "gamma", "delta", "epsilon"]
        waves = {"W1_wave.json": {"wave": "W1",
                                  "arm_string": "alpha,beta,gamma,delta"},
                 "W2_wave.json": {"wave": "W2",
                                  "arm_string": "alpha,beta,gamma,delta"}}
        tools = {"alpha_domain.py": SUBJECT_TOOL,       # subject  => DELIVER
                 "capmono_refusal.py": CONFOUNDER_TOOL,  # gamma subj, delta deep
                 }
        reports = {"r.md": "VERIFY id=alpha verdict=WORKING episodes=12\n"}
        a3 = build_tree(b3, ids, waves, tools, reports)
        rc, out, err = run(a3)
        check(rc == 0, "classifier tree exits 0 (got %d)" % rc)
        got = rows_of(out)
        check(got.get("alpha", ("?",))[0] == "VERIFIED",
              "a VERIFY line wins over everything else (alpha)")
        check(got.get("beta", ("?",))[0] == "MENTION",
              "beta: named deep in alpha's head => MENTION (got %s)"
              % (got.get("beta"),))
        check(got.get("gamma", ("?",))[0] == "DELIVER",
              "gamma: named in a subject line => DELIVER (got %s)"
              % (got.get("gamma"),))
        check(got.get("delta", ("?",))[0] == "MENTION",
              "delta: named only as a confounder => MENTION, never DELIVER "
              "(got %s)" % (got.get("delta"),))
        check(got.get("epsilon", ("?",))[0] == "NO-CORPUS",
              "epsilon: in no arm string => NO-CORPUS (got %s)"
              % (got.get("epsilon"),))
        check(len(got) == 5, "every id gets exactly one row (got %d)" % len(got))
        check("VERIFIED 1  DELIVER 1  MENTION 2  BUILD 0  NO-CORPUS 1" in out,
              "the header counts match the rows")

        # BUILD is reachable: same tree, minus every tool that names it.
        b4 = tempfile.mkdtemp(prefix="aer_build_")
        a4 = build_tree(b4, ["zeta"],
                        {"W1_wave.json": {"wave": "W1", "arm_string": "zeta"}},
                        {"alpha_domain.py": SUBJECT_TOOL}, {"r.md": "x\n"})
        rc, out, err = run(a4)
        got = rows_of(out)
        check(got.get("zeta", ("?",))[0] == "BUILD",
              "an id with a corpus and no naming tool => BUILD (got %s)"
              % (got.get("zeta"),))
        shutil.rmtree(b4, ignore_errors=True)

        # ---------------------------------------------------- section 3
        print("section 3 -- the two measured discriminators")
        # (i) prose naming a WITHDRAWN id is not membership.
        b5 = tempfile.mkdtemp(prefix="aer_prose_")
        a5 = build_tree(b5, ["alpha", "beta"],
                        {"W1_wave.json": {
                            "wave": "W1",
                            "arm_string": "alpha",
                            "arm_delta_vs_W0": "REMOVED: beta, wandlimbo"}},
                        {"alpha_domain.py": SUBJECT_TOOL}, {"r.md": "x\n"})
        rc, out, err = run(a5)
        got = rows_of(out)
        check(got.get("beta", ("?", 0, 9))[2] == 0,
              "an id named only in a wave record's PROSE has waves=0 (got %s)"
              % (got.get("beta"),))
        check(got.get("alpha", ("?", 0, 0))[2] == 1,
              "the arm_string member has waves=1 (got %s)" % (got.get("alpha"),))
        shutil.rmtree(b5, ignore_errors=True)

        # (ii) a mention past the head window is not a mention at all.
        b6 = tempfile.mkdtemp(prefix="aer_far_")
        a6 = build_tree(b6, ["zeta"],
                        {"W1_wave.json": {"wave": "W1", "arm_string": "zeta"}},
                        {"epsilon_domain.py": FAR_TOOL}, {"r.md": "x\n"})
        rc, out, err = run(a6)
        got = rows_of(out)
        check(got.get("zeta", ("?",))[0] == "BUILD",
              "a name past HEAD_CHARS does not count as an instrument (got %s)"
              % (got.get("zeta"),))
        shutil.rmtree(b6, ignore_errors=True)

        # (iii) the VERIFY reader is verify_coverage's, so a verdict written in
        # markdown emphasis -- the form that hid 26 of 59 lines from the old
        # anchored regex -- still counts here.
        b7 = tempfile.mkdtemp(prefix="aer_emph_")
        a7 = build_tree(b7, ["alpha"],
                        {"W1_wave.json": {"wave": "W1", "arm_string": "alpha"}},
                        {"alpha_domain.py": SUBJECT_TOOL},
                        {"r.md": "- **`VERIFY id=alpha verdict=BUGGY "
                                 "episodes=77`**\n"})
        rc, out, err = run(a7)
        got = rows_of(out)
        check(got.get("alpha", ("?",))[0] == "VERIFIED",
              "an emphasised VERIFY line is still a verdict (got %s)"
              % (got.get("alpha"),))
        shutil.rmtree(b7, ignore_errors=True)
        shutil.rmtree(b3, ignore_errors=True)

        # ---------------------------------------------------- section 4
        print("section 4 -- the live tree, invariants only")
        rc, out, err = run([])
        check(rc == 0, "live tree exits 0 (got %d)" % rc)
        head = out.splitlines()[0] if out else ""
        check(head.startswith("A-EVIDENCE-ROUTE"), "live tree prints a header")
        nums = [int(x) for x in head.replace("A-EVIDENCE-ROUTE", "").split()
                if x.isdigit()]
        check(len(nums) == 4 and all(n > 0 for n in nums),
              "every live denominator is non-zero: %s" % (nums,))
        rc, out, err = run(["--json"])
        check(rc == 0, "live --json exits 0 (got %d)" % rc)
        data = json.loads(out)
        check(sum(data["counts"].values()) == data["denominators"]["ids"],
              "live partition: classes %d == ids %d"
              % (sum(data["counts"].values()), data["denominators"]["ids"]))
        check(len(data["rows"]) == data["denominators"]["ids"],
              "live rows == ids")
    finally:
        shutil.rmtree(base, ignore_errors=True)

    print("\n%d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  - %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
