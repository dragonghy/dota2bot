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

    # ---- 4e-4g. FAIL-OPEN IS BOUNDED BY COST ------------------------------
    # ⚠️ 2026-09-13 (director, baton 丙).  4a-4d pin that a new test is RUN and
    # NAMED.  Neither of them, nor 5d below, ever asked what the fail-open path
    # COSTS -- so between 09-08 and 09-13 seventeen files accumulated outside
    # the manifest at a measured 29.500s per push, while the banner went on
    # reciting `cumulative budget 12.0s` and 5d went on asserting 11.9s.  Real
    # hook cost 41.5s against a 12.0s budget, 246% over, nothing red.
    # The quantity was never wrong; it was never TAKEN.
    SLOW_PASS = "import time, sys\ntime.sleep(0.4)\nprint('ok')\nsys.exit(0)\n"
    known = {"tests/test_known.py": {"seconds": 0.1, "in_gate": True,
                                     "reason": "fast"}}

    # 4e/4f: drift PAST the slack refuses the push and says why.
    root, mpath = make_tree(
        tmp,
        {"test_known.py": PASSING,
         "test_drift_a.py": SLOW_PASS, "test_drift_b.py": SLOW_PASS},
        dict(known), unmeasured_slack_seconds=0.5,
    )
    r = run_gate(root, mpath)
    check(r.returncode == 2,
          "4e: unmeasured work past the stated slack is a STALE MANIFEST and "
          "refuses the push (exit 2, 'could not run' -- the manifest is this "
          "gate's own input), got %d" % r.returncode)
    check("STALE MANIFEST" in r.stdout and "py_gate_measure.py" in r.stdout,
          "4f: and the refusal names the one-command remedy -- a refusal "
          "without a remedy is what drives people onto RULE6_BYPASS "
          "(GH #707/#669)")
    check("REAL cost" in r.stdout,
          "4f2: the banner states the run's REAL seconds next to the budget. "
          "The old banner printed both numbers and compared neither, which is "
          "how 41.5s sat under a line reading '12.0s' for five days")

    # 4g: and UNDER the slack it stays open.  This is the half that must not
    # regress: a red for every new test file would price a ~4min re-measure
    # into every push, and the bound is on cost precisely so that one cheap
    # newcomer is free.
    root, mpath = make_tree(
        tmp, {"test_known.py": PASSING, "test_one_newcomer.py": PASSING},
        dict(known), unmeasured_slack_seconds=3.0,
    )
    r = run_gate(root, mpath)
    check(r.returncode == 0,
          "4g: a cheap newcomer under the slack is still FAIL-OPEN (exit 0) -- "
          "bounding fail-open must not become abolishing it, got %d"
          % r.returncode)

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

    # ⚠️ 2026-09-11 (director): 5c USED TO BE `row_sum <= budget`, and it was
    # RED on trunk for reasons that had nothing to do with the hook's speed.
    # The generator selected on the raw measured float and wrote each row
    # `round(x, 3)`, so the row sum drifts from the number the selection
    # actually used by up to n * 5e-4 -- row sum 12.029 against a recorded
    # 11.996 over 84 rows, i.e. 0.033s, which is enough to cross a 12.0s budget
    # the selection never crossed.  So the two questions are asked separately:
    #   5c  -- did the SELECTION stay inside the budget?  (its own number)
    #   5c2 -- do the ROWS still agree with that number?  (catches hand-edits)
    # Splitting them is strictly stronger than the old single check: a row
    # hand-edited upward by 0.5s used to be indistinguishable from rounding
    # noise, and now it is not.  The generator was fixed in the same change to
    # round before selecting, so `allowance` collapses to ~0 on the next
    # re-measure; it is kept because the CURRENT manifest predates that fix.
    row_sum = sum(v["seconds"] for v in rt.values() if v["in_gate"])
    recorded = float(real["selected_total_seconds"])
    n_sel = sum(1 for v in rt.values() if v["in_gate"])
    check(recorded <= budget + 1e-6,
          "5c: the selection's own total (%.3fs) fits the recorded budget "
          "(%.1fs)" % (recorded, budget))
    allowance = n_sel * 5e-4 + 1e-6
    check(abs(row_sum - recorded) <= allowance,
          "5c2: the rows (%.3fs over %d selected) disagree with the manifest's "
          "own selected_total_seconds (%.3fs) by %.3fs, more than the %.3fs "
          "that rounding each row to 3 decimals can explain. Either a row was "
          "hand-edited or the summary is stale -- re-measure, do not adjust"
          % (row_sum, n_sel, recorded, abs(row_sum - recorded), allowance))
    # 5d reads the ROWS, deliberately: it is the wall-clock claim, so the
    # quantity that matters is what will actually be run, and the 6s of
    # headroom is far wider than any rounding drift.
    # ⚠️ 2026-09-13 (director): 5d IS A CLAIM ABOUT THE SELECTED SET, AND ITS
    # LABEL USED TO READ AS A CLAIM ABOUT THE RUN.  `row_sum` cannot see the
    # fail-open path, so on 09-13 it read 11.90s -- green, six seconds of
    # headroom -- while the hook really spent 41.5s.  The wording is now exact
    # about which set it bounds, and 5f below is what keeps that set the whole
    # story.  Same shape as the 5c rounding note: the number was never wrong,
    # it was answering a different question than the one being asked of it.
    # ⚠️ 2026-09-16 (director, RULING 61): 5d USED TO READ `row_sum < 18.0`, AND
    # THE PREMISE IT ENCODED HAD EXPIRED 6 DAYS EARLIER.  That 18.0 was GH
    # #616's acceptance sentence -- "the Lua static half costs 18s cold, this
    # half should not double it" -- and GH #624 added a THIRD leg to the same
    # hook on 09-10 (`lua_gate.py`, 500-733s measured across the five streams).
    # So the check went on policing a ratio against a reference that is now 2%
    # of the hook, and the 12.0s budget it defended was excluding 30 ratchets
    # that each satisfied the per-test cap -- the EXPENSIVE end of the
    # qualifying set, because selection is cheapest-first.  The old 5d was
    # GREEN throughout: it was never wrong, it was answering a question nobody
    # was asking any more.  Same shape as the 5c and 5f notes above, one level
    # up -- there a number answered the wrong question, here a PREMISE did.
    #
    # What replaces it is the premise's actual job, stated so it can be read:
    # `budget_seconds` is a BACKSTOP against this leg growing unwatched, never
    # a chooser between tests that each already satisfy the per-test cap.  It
    # is doing that job exactly when it excludes nobody.  When it starts to
    # bind, that is a decision someone should make on purpose -- so it reddens
    # here instead of silently evicting the most substantial ratchets, which is
    # how `tests/test_bots_walk_farm_only.py` came to be outside the gate it is
    # most often red in (GH #843).
    by_budget = sorted(k for k, v in rt.items()
                       if not v["in_gate"] and v["reason"] == "over_cumulative_budget")
    check(not by_budget,
          "5d: the cumulative budget (%.1fs, rows %.2fs) is EVICTING %d test(s) "
          "that each satisfy the %.1fs per-test cap: %s. The budget is a "
          "backstop, not a chooser -- cheapest-first means the evicted are the "
          "ones that do the most work. Two causes, and they need different "
          "answers: the suite genuinely grew (re-derive the backstop in "
          "tools/agent/py_gate_measure.py and say so), or this container "
          "measured slow (re-measure on a quiet box before touching the knob). "
          "⛔ Do NOT resolve this by leaving the eviction in place -- that is "
          "the silence RULING 61 removed"
          % (budget, row_sum, len(by_budget), cap, " ".join(by_budget)))
    check(real.get("selected_count") == sum(1 for v in rt.values() if v["in_gate"]),
          "5e: the manifest's own selected_count agrees with its rows -- a "
          "summary that drifts from the data it summarises is how a stale "
          "manifest looks green")
    # ⚠️ 2026-09-13 (director): 5f USED TO BE `len(rt) >= 100`, AND ITS OWN
    # COMMENT NAMED THE DEFECT IT COULD NOT DETECT -- "a manifest missing files
    # silently converts them into 'new, unmeasured'".  A constant floor is
    # satisfied by a manifest missing ANY number of files as long as 100 rows
    # remain, so on 09-13 it was green at 114 rows against 131 files on disk:
    # 17 uncovered, converted into exactly the silent fail-open the comment
    # warned about.  A floor is a claim about the manifest's size; coverage is
    # a relation between the manifest and the disk, and only the second one is
    # the thing being asserted.  Read the disk.
    #
    # WHY A SLACK RATHER THAN ZERO: this test runs inside the gate it audits,
    # so red-on-any-new-file would price a ~4min re-measure into every stream's
    # next push.  The slack is what keeps that from being the deal.
    #
    # AND WHY THIS EXISTS AT ALL, given py_gate.py now bounds unmeasured COST:
    # the two bounds fail apart, and that is the point.  Twenty newcomers at
    # 0.1s cost 2.0s -- under the gate's 3.0s slack, never red there -- while
    # leaving the manifest twenty files stale and its selected_* summary
    # increasingly fictional.  The gate bounds what a push SPENDS; this bounds
    # how far the manifest has drifted from the suite it claims to describe.
    on_disk = sorted(
        os.path.join("tests", f) for f in os.listdir(os.path.join(REPO, "tests"))
        if f.startswith("test_") and f.endswith(".py")
    )
    uncovered = [rel for rel in on_disk if rel not in rt]
    COVERAGE_SLACK = 5
    check(len(uncovered) <= COVERAGE_SLACK,
          "5f: the manifest has drifted from the suite -- %d of %d on-disk "
          "tests are in no row, over the slack of %d, so each one runs "
          "fail-open on every push with its cost recorded nowhere. "
          "Re-measure (python3 tools/agent/py_gate_measure.py); do not raise "
          "the slack. Uncovered: %s"
          % (len(uncovered), len(on_disk), COVERAGE_SLACK,
             " ".join(uncovered) or "(none)"))
    check(len(rt) >= 100,
          "5f2: and the manifest is not vacuously small (%d rows) -- the "
          "coverage check above compares two sets, so it also passes when "
          "BOTH have collapsed; this is the floor under that" % len(rt))
    check(float(real.get("unmeasured_slack_seconds") or 0) > 0,
          "5g: the real manifest records unmeasured_slack_seconds, so the gate "
          "reads the bound instead of falling back to a derived default -- a "
          "knob the generator does not write down is a knob nobody can audit")

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

    # 7f/7g: the generator must DECIDE with the number it WRITES DOWN.  It used
    # to select on the raw float and store round(x, 3), which is how the real
    # manifest ended up with a row sum 0.033s above its own recorded total and
    # 0.029s above a budget the selection never crossed (see section 5).  Rows
    # whose third decimal is not the last one are the whole test: with the old
    # code `tot` is the raw sum and the rows are rounded, so 7f fails.
    rows2 = [
        {"path": "t/a.py", "seconds": 0.10049, "timed_out": False},
        {"path": "t/b.py", "seconds": 0.20051, "timed_out": False},
        {"path": "t/c.py", "seconds": 0.30049, "timed_out": False},
    ]
    sel2, tot2 = pgm.select(rows2, per_test_cap=3.0, budget=10.0)
    row_sum2 = sum(v["seconds"] for v in sel2.values() if v["in_gate"])
    check(abs(row_sum2 - tot2) < 1e-9,
          "7f: the rows sum EXACTLY to the reported total (rows %.6f vs total "
          "%.6f) -- a generator that decides with one number and records "
          "another hands every downstream check a quantity it cannot verify"
          % (row_sum2, tot2))
    check(all(v["seconds"] == round(v["seconds"], 3) for v in sel2.values()),
          "7g: and every recorded second really is the 3-decimal value, so the "
          "budget comparison and the stored row are the same number")

    # 7h-7j: A RE-MEASURE CAN REMOVE PROTECTION, AND MUST SAY SO.
    # ⚠️ 2026-09-13 (director).  Selection is greedy cheapest-first against a
    # SATURATED budget (11.79s of 12.0s), so two things evict incumbents: new
    # cheap arrivals, and plain measurement jitter.  Both were observed today,
    # minutes apart on the same tree -- the 18:5xZ re-measure admitted 10
    # newcomers and dropped 9 incumbents including `test_push_gate_hook.py`,
    # the acceptance test FOR THIS GATE; the 19:0xZ one dropped
    # `test_arm_since.py` on jitter alone while nothing about the suite had
    # changed.  The tool printed `85 of 131 selected` and `84 of 131 selected`
    # and named no departure either time.
    # A count is not a membership: those two totals differ by one, and the
    # membership differs by nineteen.
    check(hasattr(pgm, "previous_membership"),
          "7h: the generator reads the manifest it is about to overwrite -- "
          "without the BEFORE set there is nothing to diff, and eviction "
          "stays invisible")
    mtmp = os.path.join(tmp, "prev_manifest.json")
    with open(mtmp, "w") as fh:
        json.dump({"tests": {
            "tests/a.py": {"seconds": 0.1, "in_gate": True, "reason": "fast"},
            "tests/b.py": {"seconds": 9.0, "in_gate": False,
                           "reason": "over_per_test_cap"},
        }}, fh)
    check(pgm.previous_membership(mtmp) == {"tests/a.py"},
          "7i: and reads the IN-GATE set specifically -- diffing all measured "
          "rows instead would call every row a member and report no eviction "
          "ever, which is indistinguishable from the bug")
    check(pgm.previous_membership(os.path.join(tmp, "no_such_file.json")) is None,
          "7j: a first run (no previous manifest) yields None, not an empty "
          "set -- empty would report every selected test as newly ADMITTED, "
          "and a diff that cries wolf on run one gets ignored on run two")

    # 7k-7n: A TOOL THAT SIGKILLS TESTS OWES THE CLEANUP THEY COULD NOT DO.
    # ⚠️ 2026-09-13 (director).  measure_one() caps each test and subprocess's
    # timeout path ends in kill(), so no `finally` runs.
    # `tests/test_lua_corpus_stability.py` arms bots/Customize/soak_side.lua
    # and disarms it in a `finally`; it takes >20s, so every measure pass on
    # this container kills it there and leaves the switch armed.  Measured
    # today: lua_gate.py exit 3 with 20+ FAILs -> exit 0 with none, on nothing
    # but deleting that file.  It is gitignored, so `git status` stayed clean
    # and the next stream would have inherited a red push-gate with no diff.
    swtmp = os.path.join(tmp, "switchrepo")
    os.makedirs(os.path.join(swtmp, "bots", "Customize"))
    full_switch = os.path.join(swtmp, pgm.SWITCH)

    # 7k: the real case -- absent before, armed by a killed test, removed after.
    before = pgm.snapshot_arming_switch(swtmp)
    with open(full_switch, "w") as fh:
        fh.write("return { side = 'radiant', cand = 'x', seed = 1 }\n")
    acted = pgm.restore_arming_switch(swtmp, before)
    check(acted and not os.path.exists(full_switch),
          "7k: a switch a killed test left ARMED is removed -- this is the "
          "shape actually observed, and its whole danger is that it is "
          "gitignored, so nothing else in the round would have shown it")

    # 7l: a switch that legitimately existed BEFORE is put back, not deleted.
    # The farm really does own this file; a cleanup that always deletes would
    # disarm a live soak run, which is worse than what it fixes.
    with open(full_switch, "w") as fh:
        fh.write("return { side = 'dire', cand = 'realwave', seed = 7 }\n")
    before = pgm.snapshot_arming_switch(swtmp)
    os.unlink(full_switch)
    pgm.restore_arming_switch(swtmp, before)
    check(os.path.exists(full_switch),
          "7l: a switch that was there BEFORE the pass is restored, not left "
          "deleted -- the farm owns this file and the tool is only cleaning "
          "up after its own kills")
    with open(full_switch) as fh:
        check("realwave" in fh.read(),
              "7m: and restored BYTE-FOR-BYTE -- a killed test that rewrote it "
              "to cand='x' must not leave the farm arming the wrong candidate, "
              "which is a wave that measures something nobody asked for")

    # 7m2: THE CASE THAT SEPARATES "RESTORE" FROM "DELETE", and it had to be
    # added after a surviving mutant said so.  7l and 7m both simulate a killed
    # test that DELETED the switch, so at restore time it is absent either way
    # -- and a mutant that deletes the switch unconditionally (`if now:` for
    # `if not existed and now:`) passed all of them, because the branch it
    # breaks is `existed AND still present` and no case above ever reached it.
    # The mutation's real-world direction is the bad one: a live farm soak run
    # owns this file, and unconditional deletion DISARMS IT mid-wave while
    # printing a line that says the cleanup worked.
    with open(full_switch, "w") as fh:
        fh.write("return { side = 'dire', cand = 'realwave', seed = 7 }\n")
    before = pgm.snapshot_arming_switch(swtmp)
    with open(full_switch, "w") as fh:          # a killed test REWROTE it
        fh.write("return { side = 'radiant', cand = 'x', seed = 1 }\n")
    pgm.restore_arming_switch(swtmp, before)
    check(os.path.exists(full_switch),
          "7m2: a switch that existed before and was REWRITTEN by a killed "
          "test is restored, never deleted -- deleting it disarms a live farm "
          "wave, which is a worse outcome than the leftover being cleaned up")
    with open(full_switch) as fh:
        check("realwave" in fh.read(),
              "7m3: ...and with the ORIGINAL candidate, not the test's "
              "cand='x' -- the farm would otherwise spend a wave measuring a "
              "candidate nobody requested")

    # 7n: the quiet case stays quiet.
    os.unlink(full_switch)
    before = pgm.snapshot_arming_switch(swtmp)
    check(pgm.restore_arming_switch(swtmp, before) is False,
          "7n: an untouched switch reports NO action -- a cleanup that "
          "announces itself every run is one nobody reads on the run that "
          "matters")

    # 7o: and the measure pass actually WIRES it, in a `finally` -- the four
    # checks above all drive the function directly, so they would every one of
    # them stay green against a tool that never calls it.  Textual, and named
    # as such: this is the wiring, not the assertion (same split as 6a/6b).
    with open(MEASURE) as fh:
        msrc = fh.read()
    check("snapshot_arming_switch(ROOT)" in msrc
          and "finally:" in msrc
          and "restore_arming_switch(ROOT" in msrc,
          "7o: py_gate_measure.py must snapshot the switch before the pass and "
          "restore it in a `finally` -- cleanup that only runs on the happy "
          "path is absent from exactly the runs that need it (a KeyboardInterrupt "
          "mid-pass leaves the switch armed just as a SIGKILL does)")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("\npy_gate: %d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)
