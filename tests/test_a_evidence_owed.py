#!/usr/bin/env python3
"""Assertions for the condition-(a) obligation leg (`tools/agent/a_evidence_owed.py`).

WHAT IS PINNED AND WHY, in the order this leg can hurt someone:

  SECTION 1 -- THE FAILURE DIRECTION, which is the entire reason GH #540 was
  filed.  Every way this leg can break produces a SMALLER, cleaner-looking
  answer: an unreadable registry, a registry whose `owed` key is a dict, a
  census subprocess that died -- each of them, read loosely, says "nothing is
  owed", which is the exact sentence 40 armed ids hid behind.  So each is
  asserted to be exit 2 with a stderr banner, never exit 0.

  SECTION 2 -- THE RULE.  Verdict OR owed row; neither is a finding (exit 3).
  Both halves are asserted in both directions, because a leg that reddens for
  everything is as useless as one that never reddens: an id with a VERIFY line
  and an id with a row must both come back green.

  SECTION 3 -- THE TWO COVERAGE FORMS, and the one that is deliberately NOT a
  form.  `a_evidence_<id>` is the convention the hand-written rows use;
  `covers_ids` is for one row discharging several ids (a detector run answers
  every id in its own subject line).  ⛔ A RETIRED row is not coverage, and
  that is a decision, not an oversight: `done_when: path_exists` judges that an
  artefact exists, not that a verdict appeared (pending_rulings LIMIT 11), so
  "retired, and still no VERIFY line" is the precise state this leg exists to
  shout about.  If retirement counted, the registry could close its own case.

  SECTION 4 -- THE LIVE TREE, INVARIANTS ONLY.  The count of unowed ids changes
  every wave and every delivery round; asserting it here would make this file a
  liability that reddens on someone else's good work.  What is asserted is what
  must hold on any tree: the leg runs, its exit is 0 or 3 (never a crash, never
  a could-not-run on a healthy repo), its own arithmetic adds up, and every
  live `a_evidence_*` row in the registry still parses under the convention the
  tool documents.

EXIT: 0 pass, 1 an assertion failed, 2 could not run.
"""
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "agent", "a_evidence_owed.py")
ROUTE = os.path.join(ROOT, "tools", "agent", "a_evidence_route.py")
REGISTRY = os.path.join(ROOT, "iterations", "owed_executions.json")

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


SUBJECT_TOOL = (
    '#!/usr/bin/env python3\n'
    '"""`%s` condition (a): does the guard fire in a real game?\n'
    '\n'
    'Body prose that names nobody.\n'
    '"""\n'
)


def build_route_tree(base, ids, verified=(), name="t"):
    """A synthetic tree for a_evidence_route: every id armed, one wave, one
    subject-line tool each (so every id is DELIVER), and a VERIFY line only for
    the ids named in `verified`.

    ⚠️ `name` gives each tree its OWN directory, and it is not tidiness: the
    first draft wrote every tree to one base, so building the with-VERIFY tree
    silently re-wrote the bare one, and the two later cases read a verdict
    nobody in those cases had written.  Both failures pointed at the tool.
    """
    base = os.path.join(base, name)
    os.makedirs(base, exist_ok=True)
    ts = os.path.join(base, "test_set.md")
    with open(ts, "w", encoding="utf-8") as fh:
        fh.write("# synthetic test set\n%s\n" % ",".join(ids))
    wdir = os.path.join(base, "waves")
    bdir = os.path.join(base, "behavioral")
    rdir = os.path.join(base, "reports")
    for d in (wdir, bdir, rdir):
        os.makedirs(d, exist_ok=True)
    with open(os.path.join(wdir, "W99_wave.json"), "w", encoding="utf-8") as fh:
        json.dump({"arm_string": ",".join(ids)}, fh)
    for i in ids:
        with open(os.path.join(bdir, "%s_domain.py" % i), "w",
                  encoding="utf-8") as fh:
            fh.write(SUBJECT_TOOL % i)
    lines = ["# synthetic replay-check report\n"]
    for i in verified:
        lines.append("VERIFY id=%s verdict=WORKING episodes=7\n" % i)
    with open(os.path.join(rdir, "20260909T000000Z.md"), "w",
              encoding="utf-8") as fh:
        fh.write("".join(lines))
    return ["--route-args",
            " ".join(shlex.quote(x) for x in
                     ["--test-set", ts, "--waves", wdir,
                      "--behavioral", bdir, "--reports", rdir])]


def write_registry(path, owed=(), retired=()):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"_note": "synthetic", "owed": list(owed),
                   "retired": list(retired)}, fh)
    return path


def states(out):
    """{id: state} parsed from the printed sections."""
    got = {}
    section = None
    for line in out.splitlines():
        if line.startswith("nothing is raising a hand"):
            section = "UNOWED"
        elif line.startswith("owed row exists"):
            section = "OWED"
        elif line.startswith("note, NOT a finding"):
            section = "NOTE"
        elif line.startswith("LIMITS") or line.startswith("FINDING"):
            section = None
        elif section and line.startswith("  ") and line.strip():
            got[line.split()[0]] = section
    return got


def main():
    base = tempfile.mkdtemp(prefix="aeo_test_")
    try:
        # ------------------------------------------------------------------
        print("1. the failure direction (every break must be exit 2, not "
              "'nothing is owed')")
        tree = build_route_tree(base, ["alpha", "beta"])
        reg = os.path.join(base, "reg.json")
        write_registry(reg)

        rc, out, err = run(["--registry", os.path.join(base, "nope.json")]
                           + tree)
        check(rc == 2, "a registry that cannot be opened is exit 2 (got %d)" % rc)
        check("AEO_COULD_NOT_RUN" in err,
              "...and says so on stderr, in the repo's could-not-run word")
        check("UNOWED" not in out,
              "...and prints no table a reader could mistake for a census")

        bad = os.path.join(base, "bad.json")
        with open(bad, "w", encoding="utf-8") as fh:
            json.dump({"owed": {"not": "a list"}}, fh)
        rc, out, err = run(["--registry", bad] + tree)
        check(rc == 2, "an `owed` that is not a list is exit 2 (got %d)" % rc)
        check("would read UNOWED" in err,
              "...and the banner names the misreading it prevents")

        rc, out, err = run(["--registry", reg, "--route",
                            os.path.join(base, "no_such_census.py")] + tree)
        check(rc == 2, "a census subprocess that fails is exit 2 (got %d)" % rc)
        check("a_evidence_route.py exited" in err,
              "...and quotes the census's own exit rather than swallowing it")

        # ------------------------------------------------------------------
        print("\n2. the rule: a verdict OR an owed row; neither is a finding")
        rc, out, err = run(["--registry", reg] + tree)
        check(rc == 3, "two bare armed ids => exit 3 (got %d)" % rc)
        check(states(out) == {"alpha": "UNOWED", "beta": "UNOWED"},
              "...and both are listed UNOWED: %s" % states(out))

        vtree = build_route_tree(base, ["alpha", "beta"], verified=["alpha"],
                                 name="verified")
        rc, out, err = run(["--registry", reg] + vtree)
        st = states(out)
        check(rc == 3 and st == {"beta": "UNOWED"},
              "an id with a VERIFY line drops out of the finding: rc=%d %s"
              % (rc, st))

        write_registry(reg, owed=[{"id": "a_evidence_beta"}])
        rc, out, err = run(["--registry", reg] + vtree)
        check(rc == 0, "verdict for one + owed row for the other => exit 0 "
                       "(got %d)" % rc)
        check("every armed id carries a verdict or an owed row" in out,
              "...and the clean line says which two things it accepted")

        # ------------------------------------------------------------------
        print("\n3. the coverage forms -- and the one that is not a form")
        write_registry(reg, owed=[{"id": "a_evidence_alpha"},
                                  {"id": "a_evidence_beta"}])
        rc, out, err = run(["--registry", reg] + tree)
        check(rc == 0, "the `a_evidence_<id>` convention covers (got %d)" % rc)

        write_registry(reg, owed=[{"id": "w62_delivery_round",
                                   "covers_ids": ["alpha", "beta"]}])
        rc, out, err = run(["--registry", reg] + tree)
        check(rc == 0, "one row with `covers_ids` covers several (got %d)" % rc)
        check(states(out) == {"alpha": "OWED", "beta": "OWED"},
              "...and both read OWED against that row: %s" % states(out))

        # The decision, asserted in the direction that costs something.
        write_registry(reg, owed=[{"id": "a_evidence_alpha"}],
                       retired=[{"id": "a_evidence_beta"}])
        rc, out, err = run(["--registry", reg] + tree)
        st = states(out)
        check(rc == 3 and st.get("beta") == "UNOWED",
              "a RETIRED row is not coverage -- retired with no VERIFY line is "
              "the state this leg exists for: rc=%d %s" % (rc, st))
        check(st.get("alpha") == "OWED",
              "...while the open row beside it still covers")

        # A covering row for an id nobody armed is a note, not a finding:
        # withdrawal does not destroy the ability to buy (a) from banked
        # corpus (test_set.md §FB.4).
        write_registry(reg, owed=[{"id": "a_evidence_alpha"},
                                  {"id": "a_evidence_beta"},
                                  {"id": "a_evidence_ghost"}])
        rc, out, err = run(["--registry", reg] + tree)
        check(rc == 0, "a row naming an unarmed id does not redden (got %d)" % rc)
        check(states(out).get("ghost") == "NOTE",
              "...it is reported as a note: %s" % states(out))

        # ------------------------------------------------------------------
        print("\n4. the live tree (invariants only -- the counts move weekly)")
        rc, out, err = run([])
        check(rc in (0, 3),
              "live run is clean or a finding, never a crash or could-not-run "
              "(got %d; stderr: %s)" % (rc, err.strip()[:200]))
        if rc in (0, 3):
            rc_j, out_j, _ = run(["--json"])
            data = json.loads(out_j)
            c = data["counts"]
            check(c["verdict"] + c["owed"] + c["unowed"] == c["armed"],
                  "live arithmetic adds up: %d+%d+%d != %d"
                  % (c["verdict"], c["owed"], c["unowed"], c["armed"]))
            check(c["armed"] == len(data["rows"]),
                  "live rows == armed ids")
            check((rc == 3) == (c["unowed"] > 0),
                  "the exit code and the unowed count agree")
            rc_r = subprocess.run([sys.executable, ROUTE, "--json"],
                                  capture_output=True, text=True)
            route_ids = json.loads(rc_r.stdout)["denominators"]["ids"]
            check(c["armed"] == route_ids,
                  "this leg reads the same arm string as the census it quotes "
                  "(%d vs %d)" % (c["armed"], route_ids))

        with open(REGISTRY, encoding="utf-8") as fh:
            live = json.load(fh)
        named = [r.get("id") for r in live.get("owed", [])
                 if isinstance(r, dict) and isinstance(r.get("id"), str)
                 and r["id"].startswith("a_evidence_")]
        check(all(len(r) > len("a_evidence_") for r in named),
              "every live `a_evidence_*` row parses to a non-empty id: %s"
              % named)
    finally:
        shutil.rmtree(base, ignore_errors=True)

    print("\n%d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  - %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
