#!/usr/bin/env python3
"""Acceptance for tools/agent/py_gate.py + py_gate_measure.py (GH #616).

WHY THIS EXISTS.  Iron rule 6's push gate covered the Lua static half only, so
the python ratchets had no gate at all: the only leg that ran them was the
director's 开工自检, one stream every 2h.  A red therefore sat on `main` for
half a day while the stream that tripped it had already ended its round
(measured: `test_bots_walk_farm_only.py` ~2h on 09-07, seven simultaneous reds
on 09-05, and again live on 09-08 while this file was being written).

The load-bearing claims, in the order they can fail:

  1. SELECTION IS BY MEASURED SECONDS, NEVER BY FILENAME (GH #616 constraint 1).
     This is the claim with real history behind it.  "Anything named *ratchet*
     goes in the gate" is this repo's most-repeated defect shape -- a detector
     that knows one spelling calls every other spelling absent; the 09-08
     `"sha256sum" in src` finding was that shape on a file that had ALREADY been
     fixed for it once.  So check 1 stands up a manifest where the name and the
     seconds DISAGREE, and pins that the seconds win.

  2. FINDINGS AND COULD-NOT-RUN BOTH RAISE THE EXIT CODE, 3 and 2, and the
     failure text NAMES the test and carries its own finding.  A gate that
     reports without raising is the shape GH #171 ruled on.

  3. `SKIP` / could-not-run is NOT a pass, at every entry point that can fail
     open: an unreadable manifest, and a manifest that selects nothing.  Both
     are exit 2, because both would otherwise be a silent green.

  4. A NEW test nobody has measured is RUN, not ignored.  A gate that only ever
     runs a frozen list stops gating the day someone adds a file.

  5. THE REAL MANIFEST KEEPS GH #616's ACCEPTANCE PROMISES: no 120s-class leg
     (`test_selfcheck_lua_leg.py`, GH #358) is in the hook, the selected total
     does not double the Lua half's measured 18s, and every selected entry
     actually satisfies the stated rule.

  6. `.githooks/pre-push` CALLS IT (textually here; the BEHAVIOURAL proof that
     it refuses on both 2 and 3 lives in tests/test_py_gate_hook.py, which is
     split out because it spends two real luacheck runs -- ~26s -- and this
     file has to stay inside its own gate's budget.  That split is not an
     exemption: the rule is applied to this file exactly as to any other, by
     measured seconds.)

Run:  python3 tests/test_py_gate.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
GATE = os.path.join(REPO, "tools", "agent", "py_gate.py")
MEASURE = os.path.join(REPO, "tools", "agent", "py_gate_measure.py")
MANIFEST = os.path.join(REPO, "tools", "agent", "py_gate_manifest.json")
HOOK = os.path.join(REPO, ".githooks", "pre-push")

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)


PASSING = "import sys\nprint('ok')\nsys.exit(0)\n"
FAILING = "import sys\nprint('THE FINDING TEXT')\nsys.exit(1)\n"
UNRUN = "import sys\nprint('could not read my corpus')\nsys.exit(2)\n"
HANGING = "import time\ntime.sleep(30)\n"


_tree_seq = [0]


def make_tree(tmp, files, manifest_tests, **manifest_extra):
    """Stand up a throwaway repo: tests/<name>.py + a py_gate manifest.

    A FRESH directory every call, and that is not tidiness.  The first draft
    reused one `repo/` dir, so `test_zzz_ratchet.py` from check 1 was still on
    disk during checks 3 and 4 -- where it is absent from the manifest, and the
    gate therefore correctly ran it as a NEW test and correctly reported its
    failure.  Four checks went red against a gate that was behaving exactly as
    specified.  The corpus, not the subject.
    """
    _tree_seq[0] += 1
    root = os.path.join(tmp, "repo%d" % _tree_seq[0])
    os.makedirs(os.path.join(root, "tests"))
    os.makedirs(os.path.join(root, "tools", "agent"))
    for name, body in files.items():
        with open(os.path.join(root, "tests", name), "w") as fh:
            fh.write(body)
    manifest = {
        "per_test_cap_seconds": 3.0,
        "budget_seconds": 12.0,
        "hook_timeout_seconds": 2.0,
        "tests": manifest_tests,
    }
    manifest.update(manifest_extra)
    mpath = os.path.join(root, "tools", "agent", "py_gate_manifest.json")
    with open(mpath, "w") as fh:
        json.dump(manifest, fh)
    return root, mpath


def run_gate(root, manifest=None, timeout=120):
    env = dict(os.environ)
    env["PY_GATE_ROOT"] = root
    if manifest is not None:
        env["PY_GATE_MANIFEST"] = manifest
    return subprocess.run(
        [sys.executable, GATE], cwd=REPO, env=env,
        capture_output=True, text=True, timeout=timeout,
    )


tmp = tempfile.mkdtemp(prefix="pygate_")
try:
    # ---- 1. selection is by SECONDS, not by NAME -------------------------
    # The manifest deliberately makes the two disagree: the file whose name
    # screams "ratchet" is the SLOW one (out), and it FAILS if it is ever run.
    # A name-based selector goes red here; a seconds-based one stays green.
    root, mpath = make_tree(
        tmp,
        {"test_zzz_ratchet.py": FAILING, "test_aaa_plain.py": PASSING},
        {
            "tests/test_zzz_ratchet.py": {"seconds": 9.0, "in_gate": False,
                                          "reason": "over_per_test_cap"},
            "tests/test_aaa_plain.py": {"seconds": 0.1, "in_gate": True,
                                        "reason": "fast"},
        },
    )
    r = run_gate(root, mpath)
    check(r.returncode == 0,
          "1a: the SLOW test named *ratchet* must stay out of the gate -- "
          "membership is the manifest's measured seconds, not the filename "
          "(got exit %d: %r)" % (r.returncode, (r.stdout + r.stderr)[-400:]))
    check("test_zzz_ratchet" not in r.stdout.split("scope:")[0],
          "1b: and it must not have been run at all (its finding text would "
          "appear above the banner)")
    check("THE FINDING TEXT" not in r.stdout,
          "1c: (the sharp form of 1b) the excluded test's own output must be "
          "absent -- if it appears, it ran")

    # 1d: the inverse, so 1a cannot be satisfied by a gate that runs nothing.
    root, mpath = make_tree(
        tmp,
        {"test_zzz_ratchet.py": FAILING, "test_aaa_plain.py": PASSING},
        {
            "tests/test_zzz_ratchet.py": {"seconds": 0.1, "in_gate": True,
                                          "reason": "fast"},
            "tests/test_aaa_plain.py": {"seconds": 0.1, "in_gate": True,
                                        "reason": "fast"},
        },
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "1d: (control) the SAME file, marked fast, IS run and its failure "
          "raises exit 3 -- otherwise 1a passes vacuously (got %d)"
          % r.returncode)

    # ---- 2. findings raise 3, and the text names the test AND the finding --
    check("tests/test_zzz_ratchet.py" in r.stdout,
          "2a: the refusal text must NAME the failing test file (GH #616 "
          "acceptance) -- got %r" % r.stdout[-400:])
    check("THE FINDING TEXT" in r.stdout,
          "2b: and carry the test's OWN finding, not just its name -- a "
          "reader must not have to re-run it to learn what broke")

    # ---- 3. could-not-run is NOT a pass, at every failure-open entry ------
    root, mpath = make_tree(
        tmp, {"test_a.py": UNRUN},
        {"tests/test_a.py": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 2,
          "3a: a test that exits 2 (could not run) makes the gate exit 2, not "
          "0 -- 'could not run' reading as 'allowed' is GH #171 and GH #205 "
          "(got %d)" % r.returncode)
    check("UNCERTIFIABLE" in r.stdout and "not a pass" in r.stdout,
          "3b: and says so in words that cannot be read as a pass")

    # unreadable manifest
    root, mpath = make_tree(tmp, {"test_a.py": PASSING}, {})
    with open(mpath, "w") as fh:
        fh.write("{ this is not json")
    r = run_gate(root, mpath)
    check(r.returncode == 2,
          "3c: an unreadable manifest is exit 2, not 0 -- a gate that fails "
          "open on its own config is not a gate (got %d)" % r.returncode)

    r = run_gate(root, os.path.join(tmp, "does_not_exist.json"))
    check(r.returncode == 2,
          "3d: a MISSING manifest likewise (got %d)" % r.returncode)

    # a manifest that selects nothing
    root, mpath = make_tree(
        tmp, {"test_a.py": PASSING},
        {"tests/test_a.py": {"seconds": 9.0, "in_gate": False,
                             "reason": "over_per_test_cap"}},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 2,
          "3e: a manifest that selects ZERO tests is exit 2, not a green run "
          "over an empty set -- that is the quietest way for this gate to "
          "stop gating (got %d)" % r.returncode)

    # ---- 3f. measured-fast-now-hangs is a change of state, not a skip -----
    root, mpath = make_tree(
        tmp, {"test_a.py": HANGING},
        {"tests/test_a.py": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath, timeout=60)
    check(r.returncode == 2,
          "3f: a test the manifest measured FAST that now will not answer is "
          "exit 2 -- the gate promised to run it, so silence is a change of "
          "state, not an exclusion (got %d)" % r.returncode)

    # ---- 4. a NEW, never-measured test is RUN, not ignored ---------------
    root, mpath = make_tree(
        tmp, {"test_known.py": PASSING, "test_brand_new.py": FAILING},
        {"tests/test_known.py": {"seconds": 0.1, "in_gate": True,
                                 "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "4a: a test file absent from the manifest is still RUN -- a gate "
          "that only runs a frozen list stops gating the day someone adds a "
          "file (got %d)" % r.returncode)
    check("test_brand_new.py" in r.stdout,
          "4b: and it is named in the output")

    # 4c: a new test that is SLOW is excluded rather than refusing -- it was
    # never promised, and the full suite still covers it.  But it must be
    # named, so the exclusion is an act and not a silence.
    root, mpath = make_tree(
        tmp, {"test_known.py": PASSING, "test_brand_new_slow.py": HANGING},
        {"tests/test_known.py": {"seconds": 0.1, "in_gate": True,
                                 "reason": "fast"}},
    )
    r = run_gate(root, mpath, timeout=60)
    check(r.returncode == 0,
          "4c: a NEW test over the hook budget is excluded, not a refusal -- "
          "it was never promised (got %d)" % r.returncode)
    check("EXCLUDED" in r.stdout and "test_brand_new_slow.py" in r.stdout,
          "4d: and the exclusion is printed BY NAME -- an unnamed exclusion "
          "is the silence this whole file exists to remove")

    # ---- 5. the REAL manifest keeps GH #616's acceptance promises ---------
    if not os.path.exists(MANIFEST):
        print("py_gate: manifest missing at %s" % MANIFEST)
        sys.exit(2)
    with open(MANIFEST) as fh:
        real = json.load(fh)
    rt = real["tests"]
    cap = float(real["per_test_cap_seconds"])
    budget = float(real["budget_seconds"])

    slow_leg = "tests/test_selfcheck_lua_leg.py"
    check(slow_leg in rt and not rt[slow_leg]["in_gate"],
          "5a: the 120s leg (%s, GH #358) must be measured AND out of the "
          "hook -- GH #616 acceptance says so explicitly" % slow_leg)

    over_cap = [k for k, v in rt.items() if v["in_gate"] and v["seconds"] > cap]
    check(not over_cap,
          "5b: every selected test actually satisfies the stated rule "
          "(seconds <= %.1f) -- the manifest must not merely CLAIM the rule; "
          "offenders: %s" % (cap, over_cap))

    total = sum(v["seconds"] for v in rt.values() if v["in_gate"])
    check(total <= budget + 1e-6,
          "5c: the selected total (%.2fs) fits the recorded budget (%.1fs)"
          % (total, budget))
    check(total < 18.0,
          "5d: and does not double the Lua static half's measured 18s cold "
          "(GH #616 acceptance) -- got %.2fs" % total)
    check(real.get("selected_count") == sum(1 for v in rt.values() if v["in_gate"]),
          "5e: the manifest's own selected_count agrees with its rows -- a "
          "summary that drifts from the data it summarises is how a stale "
          "manifest looks green")
    check(len(rt) >= 100,
          "5f: the manifest covers the whole suite (%d rows) -- a manifest "
          "missing files silently converts them into 'new, unmeasured'"
          % len(rt))

    # ---- 6. the hook calls it, and refuses on BOTH 2 and 3 ---------------
    with open(HOOK) as fh:
        hook_src = fh.read()
    check("py_gate.py" in hook_src,
          "6a: .githooks/pre-push must actually CALL the python gate -- a "
          "gate nobody runs is GH #113/#205/#213, three times over")

    check("prc" in hook_src and "exit 1" in hook_src,
          "6b: and map its non-zero exits to a refusal.  The BEHAVIOURAL proof "
          "(both 2 and 3 really refuse) is tests/test_py_gate_hook.py -- this "
          "line is only the wiring, and a textual check is not the assertion")

    # 6e: a pipe must not change the gate's exit code.  git runs pre-push
    # hooks with stdout as a FIFO (measured 2026-08-31, test_ensure_lua_
    # toolchain.py 5e); a gate that goes non-zero on a FIFO refuses every
    # push in the repo.
    root, mpath = make_tree(
        tmp, {"test_a.py": PASSING},
        {"tests/test_a.py": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    env = dict(os.environ)
    env["PY_GATE_ROOT"], env["PY_GATE_MANIFEST"] = root, mpath
    fifo = subprocess.run(
        ["bash", "-c", "set -o pipefail; %s %s | cat > /dev/null"
         % (sys.executable, GATE)],
        cwd=REPO, env=env, capture_output=True, text=True, timeout=120,
    )
    check(fifo.returncode == 0,
          "6e: a FIFO stdout must NOT make the clean gate non-zero -- that is "
          "the pre-push hook's actual shape (got %d)" % fifo.returncode)

    # ---- 7. the measure tool's selection function, directly --------------
    sys.path.insert(0, os.path.join(REPO, "tools", "agent"))
    import py_gate_measure as pgm

    rows = [
        {"path": "t/slow.py", "seconds": 9.0, "timed_out": False},
        {"path": "t/fast.py", "seconds": 0.5, "timed_out": False},
        {"path": "t/mid.py", "seconds": 2.0, "timed_out": False},
        {"path": "t/hang.py", "seconds": 20.0, "timed_out": True},
    ]
    sel, tot = pgm.select(rows, per_test_cap=3.0, budget=2.0)
    check(sel["t/slow.py"]["reason"] == "over_per_test_cap",
          "7a: over the per-test cap is recorded with its reason")
    check(sel["t/hang.py"]["reason"] == "over_per_test_cap",
          "7b: a test that timed out while being measured is out too")
    check(sel["t/fast.py"]["in_gate"] is True,
          "7c: cheapest-first, the cheap one gets in")
    check(sel["t/mid.py"]["reason"] == "over_cumulative_budget",
          "7d: and the next one is refused by the BUDGET, with that reason "
          "recorded -- 'why is this out' must be readable without re-running "
          "the measurement (got %r)" % sel["t/mid.py"]["reason"])
    check(abs(tot - 0.5) < 1e-6,
          "7e: the reported total counts only what is in (got %.3f)" % tot)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("\npy_gate: %d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)
