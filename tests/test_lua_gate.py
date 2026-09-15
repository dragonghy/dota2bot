#!/usr/bin/env python3
"""Acceptance for tools/agent/lua_gate.py + lua_gate_measure.py (GH #624).

WHY THIS EXISTS.  Iron rule 6's push gate ran `luacheck` (a LINTER -- it never
executes a test body) and the fast PYTHON ratchets (GH #616).  It ran no Lua
TEST.  The Lua censuses fail structurally rather than accidentally: each one
asserts "the set of X in the corpus is exactly the set that has been read", so
ANY stream landing a new gate, call site or ability instance turns one red --
and the pusher's own gate said nothing, so the red was found by the NEXT stream
to start work, hours later, with the author already gone.  GH #624 counted four
instances; on 2026-09-10 THREE were red on `main` at once
(`test_gated_helper_nesting_census.lua`, `test_lion_ult_reserve_domain.lua`,
`test_wk_q_castrange_meter_domain.lua`).

The load-bearing claims, in the order they can fail:

  1. SELECTION IS BY MEASURED SECONDS, NEVER BY FILENAME (GH #616 constraint 1,
     inherited).  Check 1 stands up a manifest where the NAME and the SECONDS
     disagree -- the file whose name screams `census` is the slow one, and it
     FAILS if it is ever run -- and pins that the seconds win.

  2. A FAILING Lua test RAISES THE EXIT CODE TO 3 and its finding text reaches
     the reader.  A gate that reports without raising is the shape GH #171
     ruled on.

  3. COULD-NOT-RUN IS NOT A PASS, at every entry point that can fail open: an
     unreadable manifest, a manifest that selects nothing, and a selected test
     that stops answering.  All exit 2, because all would otherwise be a silent
     green.

  4. A NEW test nobody has measured is RUN, not ignored.  A gate that only ever
     runs a frozen list stops gating the day someone adds a file.

  5. ⭐ THE GATE GOES THROUGH `tests/run_tests.lua`, NEVER `lua5.1 tests/x.lua`.
     A test file ends with `return tests`; running it directly loads the module,
     asserts NOTHING and exits 0 -- a did-not-run wearing a pass, which is the
     exact family GH #200 legislated against and which `tools/agent/rc.sh`
     refuses by name.  Check 5 pins it with a file that PASSES when loaded and
     FAILS when its bodies are executed: a gate taking the direct route reads
     green here.

  6. THE REAL MANIFEST KEEPS THIS RULING'S ACCEPTANCE PROMISES: nothing over
     the per-test cap is in the hook, the selected total stays inside the
     recorded budget, and every selected entry actually satisfies the stated
     rule.

  9. ⭐⭐ SCOPE SKIPS ONLY ON A POSITIVE ANSWER.  Cost is controlled by what the
     push touches, not by a seconds budget (the measurement that forced that is
     in `lua_gate_measure.py`: on the 18 tests red on trunk 2026-09-10, a 25s
     cheapest-first budget caught 3 and a 25s expensive-first budget caught 0).
     So `--if-touched` has one dangerous direction -- skipping when it should
     have run -- and check 9 pins that it FAILS CLOSED: an empty path list runs
     everything, and only a list that is non-empty AND entirely outside
     `bots/` `game/` `tests/` skips.

  7. `.githooks/pre-push` CALLS IT.  Textual here, for the same reason the
     python sibling gives: the behavioural proof spends real gate runs and
     would not fit inside this file's own budget.

  8. ⭐ NO CI STEP RUNS A LUA TEST FILE DIRECTLY.  This is check 5's claim
     applied to the other place that runs Lua tests, and it is here rather than
     in a file of its own because a claim and its enforcement drifting apart is
     how this one survived.  Found live on 2026-09-10 while ruling GH #624:
     `.github/workflows/ci.yml`'s "Smoke load (every hero file parses under Lua
     5.1)" job ran `lua5.1 tests/test_smoke_load.lua` and was measured at
     BARE_EXIT=0 with ZERO bytes of output -- green because it asserted
     nothing, since the 2026-09-05 rebuild.  `tools/agent/rc.sh` refuses that
     exact command by name, but nothing was refusing it inside a workflow file.

Run:  python3 tests/test_lua_gate.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
GATE = os.path.join(REPO, "tools", "agent", "lua_gate.py")
MEASURE = os.path.join(REPO, "tools", "agent", "lua_gate_measure.py")
MANIFEST = os.path.join(REPO, "tools", "agent", "lua_gate_manifest.json")
RUNNER = os.path.join(REPO, "tests", "run_tests.lua")
HOOK = os.path.join(REPO, ".githooks", "pre-push")

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)


PASSING = "local t = {}\nt['ok case'] = function() end\nreturn t\n"
FAILING = "local t = {}\nt['bad case'] = function() error('THE FINDING TEXT') end\nreturn t\n"
# Loads clean, asserts nothing until a body runs -- check 5's whole point.
LOADS_CLEAN_FAILS_WHEN_RUN = FAILING
HANGING = ("local t = {}\nt['hang'] = function() local x = os.time()\n"
           "while os.time() - x < 30 do end end\nreturn t\n")
# Finishes, but only after ~1s of CPU -- the point is a test whose cost is
# clearly above the noise floor of process startup, so a cost reading can be
# told apart from a constant.  os.clock (CPU seconds, sub-second resolution)
# rather than os.time (1s granularity, so a 2s window measures 1-2s).
SLOWISH = ("local t = {}\nt['slow case'] = function() local x = os.clock()\n"
           "while os.clock() - x < 1.0 do end end\nreturn t\n")


def cost_of_unmeasured(out):
    """Seconds the summary says the unmeasured half burned, or None.

    Parsed out of the summary line rather than asserted as a substring: the
    question these checks ask is what the NUMBER is, and a substring assertion
    on a sentence answers whether the sentence is there.
    """
    m = re.search(r"not in the manifest were run anyway, costing ([\d.]+)s", out)
    return float(m.group(1)) if m else None


def wall_ratio(out):
    """The `budget vs wall` ratio the summary reports, or None."""
    m = re.search(r"budget vs wall:.*?\(([\d.]+)x\)", out)
    return float(m.group(1)) if m else None


def lua_available():
    try:
        p = subprocess.run(["lua5.1", "-v"], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=30)
        return p.returncode == 0
    except Exception:
        return False


_tree_seq = [0]


def make_tree(tmp, files, manifest_tests, **manifest_extra):
    """Stand up a throwaway repo: tests/<name>.lua + the real runner + manifest.

    A FRESH directory every call.  The python sibling records why: reusing one
    `repo/` dir leaves a previous check's failing file on disk, where the gate
    correctly runs it as a NEW test and correctly reports it -- and four checks
    go red against a gate behaving exactly as specified.  The corpus, not the
    subject.

    The REAL `tests/run_tests.lua` is copied in rather than faked: the contract
    this gate depends on (filename-substring filter, non-zero when zero bodies
    ran, GH #200) belongs to that file, and a stub of it would pin the stub.
    """
    _tree_seq[0] += 1
    root = os.path.join(tmp, "repo%d" % _tree_seq[0])
    os.makedirs(os.path.join(root, "tests"))
    os.makedirs(os.path.join(root, "tools", "agent"))
    shutil.copy(RUNNER, os.path.join(root, "tests", "run_tests.lua"))
    for name, body in files.items():
        with open(os.path.join(root, "tests", name), "w") as fh:
            fh.write(body)
    manifest = {
        "per_test_cap_seconds": 3.0,
        "budget_seconds": 25.0,
        "hook_timeout_seconds": 3.0,
        "tests": manifest_tests,
    }
    manifest.update(manifest_extra)
    mpath = os.path.join(root, "tools", "agent", "lua_gate_manifest.json")
    with open(mpath, "w") as fh:
        json.dump(manifest, fh)
    return root, mpath


def run_gate(root, manifest=None, timeout=180, extra=()):
    env = dict(os.environ)
    env["LUA_GATE_ROOT"] = root
    if manifest is not None:
        env["LUA_GATE_MANIFEST"] = manifest
    return subprocess.run(
        [sys.executable, GATE] + list(extra), cwd=REPO, env=env,
        capture_output=True, text=True, timeout=timeout,
    )


if not lua_available():
    # Not a pass, and shaped so it cannot be mistaken for one (GH #171).
    print("UNCERTIFIABLE -- lua5.1 is absent and this file's subject needs it.")
    print("  Buy it:  apt-get install -y lua5.1")
    sys.exit(2)

tmp = tempfile.mkdtemp(prefix="luagate_")
try:
    # ---- 1. selection is by SECONDS, not by NAME -------------------------
    # The manifest deliberately makes the two disagree: the file whose name
    # screams "census" is the SLOW one (out), and it FAILS if it is ever run.
    root, mpath = make_tree(
        tmp,
        {"test_zzz_census.lua": FAILING, "test_aaa_plain.lua": PASSING},
        {
            "tests/test_zzz_census.lua": {"seconds": 9.0, "in_gate": False,
                                          "reason": "too_slow"},
            "tests/test_aaa_plain.lua": {"seconds": 0.1, "in_gate": True,
                                         "reason": "fast"},
        },
    )
    r = run_gate(root, mpath)
    check(r.returncode == 0,
          "1a seconds beat the name: a slow *census* file stays out (rc=%d)"
          % r.returncode)
    check("THE FINDING TEXT" not in r.stdout,
          "1b the out-of-gate file was not run at all")
    check("1 ran" in r.stdout, "1c exactly the one selected test ran")

    # ---- 2. a failing Lua test raises the exit code AND is named ---------
    root, mpath = make_tree(
        tmp,
        {"test_red.lua": FAILING, "test_green.lua": PASSING},
        {
            "tests/test_red.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"},
            "tests/test_green.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"},
        },
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3, "2a a red in-gate Lua test exits 3 (got %d)" % r.returncode)
    check("tests/test_red.lua" in r.stdout, "2b the failing test is named")
    check("THE FINDING TEXT" in r.stdout, "2c the finding text reaches the reader")
    check("1 findings" in r.stdout, "2d the banner counts the finding")

    # ---- 3. could-not-run is NOT a pass ---------------------------------
    root, mpath = make_tree(tmp, {"test_a.lua": PASSING}, {})
    r = run_gate(root, mpath)
    check(r.returncode == 2, "3a a manifest selecting 0 tests exits 2 (got %d)"
          % r.returncode)
    check("COULD NOT RUN" in r.stdout, "3b and says so unambiguously")

    root, mpath = make_tree(tmp, {"test_a.lua": PASSING},
                            {"tests/test_a.lua": {"seconds": 0.1, "in_gate": True,
                                                  "reason": "fast"}})
    with open(mpath, "w") as fh:
        fh.write("{ this is not json")
    r = run_gate(root, mpath)
    check(r.returncode == 2, "3c an unreadable manifest exits 2 (got %d)" % r.returncode)

    # A test measured FAST that now will not answer is a change of state on
    # something this gate promised to run -- exit 2, never a silent green.
    root, mpath = make_tree(
        tmp,
        {"test_slowly.lua": HANGING},
        {"tests/test_slowly.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 2,
          "3d a selected test that stops answering exits 2 (got %d)" % r.returncode)
    check("UNCERTIFIABLE" in r.stdout and "tests/test_slowly.lua" in r.stdout,
          "3e and names it as uncertifiable, not as a failure")

    # ---- 4. a NEW unmeasured test is run, not ignored --------------------
    root, mpath = make_tree(
        tmp,
        {"test_known.lua": PASSING, "test_brand_new.lua": FAILING},
        {"tests/test_known.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "4a a new unmeasured test is RUN and its red counts (got %d)" % r.returncode)
    check("tests/test_brand_new.lua" in r.stdout, "4b and it is named in the banner")

    # ---- 4B. ...and an unmeasured test that CANNOT answer is counted ------
    # THE GAP THIS CLOSES (director 2026-09-14).  Case 4 covers the unmeasured
    # test that answers.  The one that does NOT answer had no case at all, and
    # the behaviour nobody had written down was: land in `new_over_budget`, get
    # a line in the detail block, and be counted NOWHERE.  So the headline --
    # the line iron rule 6 asks every stream to quote verbatim -- read
    # `0 findings, 0 uncertifiable` on a push where SIX tests went unanswered,
    # one of them (`test_tpchew_channel_creep.lua`) already measured RED by the
    # 09-13T22:16Z round.  A SELECTED test timing out is `uncertifiable`; an
    # UNMEASURED one timing out was nothing.  Same event, two dispositions,
    # chosen by whether the file happens to have a manifest row.
    root, mpath = make_tree(
        tmp,
        {"test_known.lua": PASSING, "test_unpriced_slow.lua": HANGING},
        {"tests/test_known.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    head = [ln for ln in r.stdout.splitlines() if ln.startswith("lua gate: ")]
    check(len(head) == 1, "4c the headline is printed exactly once")
    check(bool(head) and "1 unanswered" in head[0],
          "4d the headline COUNTS the unmeasured test that could not answer "
          "(headline: %s)" % (head[0] if head else "MISSING"))
    check("tests/test_unpriced_slow.lua" in r.stdout, "4e and names it")
    # ⛔ STATED, NOT IMPLIED: the exit code is deliberately unchanged this
    # round.  Refusing the push here would refuse EVERY push until someone
    # pays for a ~25-minute re-measure, and a gate that expensive to satisfy
    # is how `RULE6_BYPASS` becomes the normal path (GH #707 / #669).  The
    # count is the round's product; the policy is a separate ruling.
    check(r.returncode == 0,
          "4f an unanswered unmeasured test does NOT refuse the push (rc=%d) "
          "-- reported, not enforced, and that is a decision not an oversight"
          % r.returncode)

    # ---- 4G. CONTROL: the field is not a constant ------------------------
    # Without this, `1 unanswered` could be satisfied by a headline that says
    # it always -- the vacuous-green shape. Same tree, a FAST new test.
    root, mpath = make_tree(
        tmp,
        {"test_known.lua": PASSING, "test_unpriced_fast.lua": PASSING},
        {"tests/test_known.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    head = [ln for ln in r.stdout.splitlines() if ln.startswith("lua gate: ")]
    check(bool(head) and "0 unanswered" in head[0],
          "4g CONTROL: a new test that DOES answer reads 0 unanswered "
          "(headline: %s)" % (head[0] if head else "MISSING"))

    # ---- 4H. the unpriced half of the run reports what it COST -----------
    # THE GAP THIS CLOSES (director 2026-09-15, GH #810).  `budget_seconds` is
    # a SELECTOR over tests that have a manifest row; it is not a bound on the
    # leg.  The gate also runs every test with NO row, and until this landed
    # that half was named but never priced -- so the summary printed
    # `cumulative budget 300.0s` on a leg the five streams were reporting at
    # 500-715s, and nothing in the output connected the two.  Trunk the day
    # this landed: 325 selected priced at 239.4s, 66 unmeasured priced at
    # nothing, and `ran` climbing 358 -> 391 in four days because every new
    # test lands unmeasured while the re-measure stays blocked on GH #810.
    # ⇒ the number that grows is the one nobody was printing.
    root, mpath = make_tree(
        tmp,
        {"test_known.lua": PASSING, "test_unpriced_slowish.lua": SLOWISH},
        {"tests/test_known.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    cost = cost_of_unmeasured(r.stdout)
    check(cost is not None,
          "4h the unmeasured half reports a COST, not just a name list")
    check(cost is not None and cost >= 1.0,
          "4i and the cost is the one actually burned -- a ~1s test reads "
          ">=1.0s (got %s)" % cost)

    # ---- 4J. CONTROL: that cost is measured, not a constant --------------
    # Same tree shape, a FAST unmeasured test.  Without this, 4i is satisfied
    # by any implementation that prints a fixed number big enough to pass.
    root, mpath = make_tree(
        tmp,
        {"test_known.lua": PASSING, "test_unpriced_fast.lua": PASSING},
        {"tests/test_known.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    fast_cost = cost_of_unmeasured(r.stdout)
    check(fast_cost is not None and fast_cost < 1.0,
          "4j CONTROL: a fast unmeasured test costs <1.0s, so the reading in "
          "4i is measured and not a constant (got %s)" % fast_cost)

    # ---- 4K. this container's speed is reported AGAINST THE MANIFEST -----
    # GH #810's knob-is-absolute-seconds problem: whichever container last ran
    # `measure` decides the whole repo's gate membership, and no reading ever
    # said so out loud.  The ratio below is that reading, taken on the
    # container that actually pays for the leg.  The manifest price here is
    # deliberately absurd (0.01s) so a ratio computed against anything else --
    # 1.0, the budget, the elapsed total -- comes out on the wrong side.
    root, mpath = make_tree(
        tmp,
        {"test_known.lua": SLOWISH},
        {"tests/test_known.lua": {"seconds": 0.01, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    ratio = wall_ratio(r.stdout)
    check(ratio is not None and ratio > 1.0,
          "4k a container slower than the manifest price reads >1.00x "
          "(got %s)" % ratio)

    # ---- 4L. CONTROL: the ratio's divisor is the manifest price ----------
    # Same file, same container, a manifest price 10000x larger.  A ratio that
    # does not divide by the manifest number cannot move here.
    root, mpath = make_tree(
        tmp,
        {"test_known.lua": SLOWISH},
        {"tests/test_known.lua": {"seconds": 100.0, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    slow_ratio = wall_ratio(r.stdout)
    check(slow_ratio is not None and slow_ratio < 1.0,
          "4l CONTROL: the same run against a 100.0s manifest price reads "
          "<1.00x, so the divisor really is the manifest (got %s)" % slow_ratio)

    # ---- 4M. the two halves of the hook keep saying it the same way ------
    # ⭐ WHY A SOURCE CHECK IS THE RIGHT INSTRUMENT HERE, AND ONLY HERE.  Every
    # other check in this file runs the gate and reads its behaviour, because
    # the claim is about behaviour.  This claim is about WORDING PARITY between
    # two sibling gates, so the text is the subject, not a proxy for it.
    #
    # It exists because the defect 4H closes was not discovered here: py_gate.py
    # diagnosed and fixed it on 2026-09-13 and lua_gate.py -- three lines away
    # in the same hook, and ~50x slower -- did not get the port until
    # 2026-09-15.  The pair has form: py's STALE MANIFEST refusal is STILL not
    # ported (deliberately, see lua_gate.py -- its remedy is the re-measure GH
    # #810 blocks).  A drift nobody can see is a drift nobody ports, so the two
    # sentences are pinned to each other and a reworder has to break this.
    shared = ("new test(s) not in the manifest were run anyway, costing ",
              "=> the hook's REAL cost this run is ")
    lua_src = open(GATE).read()
    py_src = open(os.path.join(REPO, "tools", "agent", "py_gate.py")).read()
    for i, sentence in enumerate(shared):
        check(sentence in lua_src and sentence in py_src,
              "4m%d both halves of the hook report the unpriced cost in the "
              "same words: %r (lua=%s py=%s)"
              % (i + 1, sentence, sentence in lua_src, sentence in py_src))

    # ---- 5. the gate goes through the RUNNER, not the file ---------------
    # `lua5.1 tests/test_x.lua` loads the module and asserts nothing (exit 0).
    # This file is red only if its BODIES run, so a gate taking the direct
    # route reads green here and this check goes red.
    root, mpath = make_tree(
        tmp,
        {"test_bodies_matter.lua": LOADS_CLEAN_FAILS_WHEN_RUN},
        {"tests/test_bodies_matter.lua": {"seconds": 0.2, "in_gate": True,
                                          "reason": "fast"}},
    )
    direct = subprocess.run(["lua5.1", "tests/test_bodies_matter.lua"], cwd=root,
                            capture_output=True, text=True, timeout=60)
    check(direct.returncode == 0,
          "5a the stand is valid: run DIRECTLY this file exits 0 while asserting "
          "nothing (got %d)" % direct.returncode)
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "5b the gate executed the bodies, so it is red (got %d)" % r.returncode)

    # ---- 9. scope skips only on a POSITIVE answer ------------------------
    # One red tree, driven three ways.  Every check below would still pass if
    # the gate skipped unconditionally EXCEPT 9c/9d, which is why they are the
    # point: the dangerous direction is skipping when it should have run.
    root, mpath = make_tree(
        tmp,
        {"test_red.lua": FAILING},
        {"tests/test_red.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath,
                 extra=["--if-touched", "iterations/reports/x.md", "docs/y.md"])
    check(r.returncode == 0,
          "9a a push touching no Lua path skips the leg (got %d)" % r.returncode)
    check("SKIPPED BY SCOPE" in r.stdout, "9b and names it a SCOPE decision")
    check("THE FINDING TEXT" not in r.stdout, "9b2 nothing was executed")

    r = run_gate(root, mpath, extra=["--if-touched", "bots/BotLib/hero_lion.lua"])
    check(r.returncode == 3,
          "9c a push touching bots/ runs the leg and the red stands (got %d)"
          % r.returncode)

    # FAIL CLOSED: "we could not tell" must never read as "safe to skip".
    r = run_gate(root, mpath, extra=["--if-touched"])
    check(r.returncode == 3,
          "9d an EMPTY path list runs everything rather than skipping (got %d)"
          % r.returncode)
    r = run_gate(root, mpath, extra=["--if-touched", "docs/a.md", "tests/mock/b.lua"])
    check(r.returncode == 3,
          "9e one in-scope path among out-of-scope ones still runs (got %d)"
          % r.returncode)

    # ---- 10. the known-red baseline blocks NEW reds, not old ones --------
    # This leg landed on a tree with 18 Lua tests already red, so without a
    # baseline it would have refused every push in the repo -- a blockade, not
    # a gate.  The promise is therefore "you did not ADD a red", and 10b is the
    # check that keeps that from decaying into "no red ever refuses".
    root, mpath = make_tree(
        tmp,
        {"test_old_red.lua": FAILING},
        {"tests/test_old_red.lua": {"seconds": 0.2, "in_gate": True,
                                    "reason": "fast"}},
        known_red=["tests/test_old_red.lua"],
    )
    r = run_gate(root, mpath)
    check(r.returncode == 0,
          "10a a red that was ALREADY red at landing does not refuse (got %d)"
          % r.returncode)
    check("tests/test_old_red.lua" in r.stdout and "ALREADY RED" in r.stdout,
          "10b it is still printed BY NAME, so the amnesty is not silent")

    root, mpath = make_tree(
        tmp,
        {"test_old_red.lua": FAILING, "test_new_red.lua": FAILING},
        {"tests/test_old_red.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"},
         "tests/test_new_red.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_old_red.lua"],
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "10c a NEW red still refuses even beside a baselined one (got %d)"
          % r.returncode)
    check("FAIL  tests/test_new_red.lua" in r.stdout,
          "10d and only the new one is reported as a finding")

    root, mpath = make_tree(
        tmp,
        {"test_healed.lua": PASSING},
        {"tests/test_healed.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_healed.lua"],
    )
    r = run_gate(root, mpath)
    check("GREEN again" in r.stdout,
          "10e a baselined test that now passes asks to leave the baseline")

    # A missing key must read as an EMPTY baseline, never a permissive one.
    root, mpath = make_tree(
        tmp,
        {"test_red2.lua": FAILING},
        {"tests/test_red2.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "10f no `known_red` key means NO amnesty, not total amnesty (got %d)"
          % r.returncode)

    # ---- 11. the baseline is per-CASE, so a NEW red inside a baselined
    #          file still refuses -----------------------------------------
    # The gap this closes was stated in the gate's own output and measured on
    # the real tree the day after the baseline landed: an 8-frame corpus commit
    # moved `test_wk_q_lane_reach`'s assertion from "alive on 44 corpus frames"
    # to "alive on 51" while the gate went on reading it as `known`.  Ordinary
    # drift inside an already-failing case must stay amnestied (11a) -- that is
    # what keeps the gate from becoming the blockade the baseline prevents --
    # while a case that was NOT failing at landing must refuse (11b).
    TWO_CASES_ONE_RED = (
        "local t = {}\n"
        "t['old case'] = function() error('DRIFTED PAYLOAD 51') end\n"
        "t['fresh case'] = function() end\n"
        "return t\n")
    TWO_CASES_BOTH_RED = (
        "local t = {}\n"
        "t['old case'] = function() error('DRIFTED PAYLOAD 51') end\n"
        "t['fresh case'] = function() error('A GENUINELY NEW BREAK') end\n"
        "return t\n")

    root, mpath = make_tree(
        tmp,
        {"test_cased.lua": TWO_CASES_ONE_RED},
        {"tests/test_cased.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_cased.lua"],
        known_red_cases={"tests/test_cased.lua": ["old case"]},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 0,
          "11a the SAME baselined case, with a moved payload, still does not "
          "refuse (got %d)" % r.returncode)
    check("amnestied for 1 case" in r.stdout,
          "11a2 and the printout says the amnesty is case-scoped, not total")

    root, mpath = make_tree(
        tmp,
        {"test_cased.lua": TWO_CASES_BOTH_RED},
        {"tests/test_cased.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_cased.lua"],
        known_red_cases={"tests/test_cased.lua": ["old case"]},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "11b a case that was NOT red at landing refuses even though its FILE "
          "is baselined (got %d)" % r.returncode)
    check("fresh case" in r.stdout,
          "11b2 and the new case is named, so the reader can act on it")
    check("old case" not in r.stdout.split("lua gate:")[0]
          or "NOT among them" in r.stdout,
          "11b3 the finding is about the new case, not the baselined one")

    # A file in `known_red` with NO case list keeps the OLD file-level amnesty.
    # This is the backward-compatibility direction: never MORE permissive than
    # before, and the printout must confess which entries are still blind.
    root, mpath = make_tree(
        tmp,
        {"test_cased.lua": TWO_CASES_BOTH_RED},
        {"tests/test_cased.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_cased.lua"],
    )
    r = run_gate(root, mpath)
    check(r.returncode == 0,
          "11c no case list = the legacy file-level amnesty, unchanged (got %d)"
          % r.returncode)
    check("FILE-LEVEL amnesty" in r.stdout and "carry no case list" in r.stdout,
          "11c2 and the gate says out loud that this entry is still blind")

    # An EMPTY case list is not "everything is known" -- it is "no case here
    # was ever matched", and the safe reading of an unrecognised red is NEW.
    root, mpath = make_tree(
        tmp,
        {"test_cased.lua": TWO_CASES_ONE_RED},
        {"tests/test_cased.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_cased.lua"],
        known_red_cases={"tests/test_cased.lua": []},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "11d an EMPTY case list refuses rather than amnesties (got %d)"
          % r.returncode)

    # The severe end: a baselined file that stops LOADING reports a bare
    # `FAIL: <file>` with no ` :: <case>` half, so no case name matches.  That
    # is the biggest red a file can have, and a file-level amnesty swallows it
    # whole.  Silence must not be the permissive answer.
    NO_CASE_RED = "local t = {}\nthis is not lua at all\nreturn t\n"
    root, mpath = make_tree(
        tmp,
        {"test_cased.lua": NO_CASE_RED},
        {"tests/test_cased.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_cased.lua"],
        known_red_cases={"tests/test_cased.lua": ["old case"]},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 3,
          "11f a baselined file that no longer LOADS refuses -- its red names "
          "no case, which is not the same as naming a known one (got %d)"
          % r.returncode)
    check("names no test case" in r.stdout,
          "11f2 and the reason given is the unrecognised shape, not a case name")

    # Partial shrink must be visible: still red, but red for less.  Without
    # this line "getting better" and "not moving" look identical.
    root, mpath = make_tree(
        tmp,
        {"test_cased.lua": TWO_CASES_ONE_RED},
        {"tests/test_cased.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
        known_red=["tests/test_cased.lua"],
        known_red_cases={"tests/test_cased.lua": ["old case", "fresh case"]},
    )
    r = run_gate(root, mpath)
    check(r.returncode == 0,
          "11e fewer failing cases than at landing does not refuse (got %d)"
          % r.returncode)
    check("FEWER cases" in r.stdout and "fresh case" in r.stdout,
          "11e2 and the narrowing is printed with the case that healed")

finally:
    shutil.rmtree(tmp, ignore_errors=True)

# ---- 6. the REAL manifest keeps this ruling's promises -------------------
try:
    with open(MANIFEST) as fh:
        real = json.load(fh)
except Exception as exc:
    check(False, "6a the real manifest is readable (%s)" % exc)
    real = None

if real:
    cap = float(real["per_test_cap_seconds"])
    budget = float(real["budget_seconds"])
    sel = {k: v for k, v in real["tests"].items() if v.get("in_gate")}
    check(len(sel) > 0, "6b the real manifest selects at least one test")
    check(all(v["seconds"] < cap for v in sel.values()),
          "6c nothing at or over the %.1fs per-test cap is in the hook" % cap)
    total = sum(v["seconds"] for v in sel.values())
    check(total <= budget + 1e-6,
          "6d the selected total %.2fs is inside the recorded %.1fs budget"
          % (total, budget))
    check(all(v.get("reason") for v in real["tests"].values()),
          "6e every measured test carries a reason, in or out")
    # The gate exists for the censuses; if the knobs ever exclude ALL of the
    # tests GH #624 was opened about, the gate is still 'green' and useless.
    # Named individually rather than by pattern -- these three are the issue's
    # own evidence, not a spelling.
    ratchets = ["tests/test_gated_helper_nesting_census.lua",
                "tests/test_activemode_call_site_census.lua"]
    covered = [r for r in ratchets if real["tests"].get(r, {}).get("in_gate")]
    check(len(covered) > 0,
          "6f at least one of GH #624's own named censuses is in the gate "
          "(covered: %s)" % (covered or "NONE"))
    # A baseline entry the gate never runs is an amnesty for nothing -- it
    # would sit in the manifest forever, uncounted and unprintable, and the
    # "shrink me" line could never fire for it.
    kr = real.get("known_red") or []
    outside = [r for r in kr if not real["tests"].get(r, {}).get("in_gate")]
    check(not outside,
          "6g every baselined test is one the gate actually runs: %s"
          % (outside or "all in gate"))
    check(bool(real.get("known_red_at")) if kr else True,
          "6h a non-empty baseline records when it was taken")

# ---- 7. the hook calls it ------------------------------------------------
with open(HOOK) as fh:
    hook_src = fh.read()
check("tools/agent/lua_gate.py" in hook_src, "7a .githooks/pre-push calls the gate")
check("LUA TEST" in hook_src or "lua test" in hook_src,
      "7b the hook names the leg it added")
check("--if-touched" in hook_src,
      "7c the hook passes the push's changed paths, so scope is real")
check("|| changed=\"\"" in hook_src,
      "7d and a failed diff leaves the list EMPTY, which runs everything")

# ---- 8. no CI step runs a Lua test file directly -------------------------
# Matched on the SHAPE of the command, not on one filename: `lua5.1
# tests/test_<anything>.lua` is the whole family, and a check that knew only
# `test_smoke_load.lua` would call every other spelling absent -- the defect
# shape this repo pays for most often.  `tests/run_tests.lua` is not a
# `test_*.lua` file, so the correct invocation cannot trip this.
CI = os.path.join(REPO, ".github", "workflows", "ci.yml")
if os.path.isfile(CI):
    import re
    with open(CI) as fh:
        ci_src = fh.read()
    # COMMENTS ARE STRIPPED FIRST, and that is not tidiness: the comment this
    # check's own fix left behind QUOTES the offending command verbatim, so a
    # whole-file match went red against a file that was already correct.  A
    # detector that cannot tell a command from prose about a command reports
    # the fix as the defect.
    ci_cmds = "\n".join(ln.split("#", 1)[0] for ln in ci_src.splitlines())
    direct = re.findall(r"lua5?\.?1?\s+tests/test_[A-Za-z0-9_]+\.lua", ci_cmds)
    check(not direct,
          "8a no CI step runs a Lua test file directly (a file run directly "
          "returns its table and asserts NOTHING, exit 0): %s" % (direct or "none"))
else:
    check(False, "8a .github/workflows/ci.yml is readable")

print("\n%d checks, %d failed" % (checks, len(failures)))
sys.exit(1 if failures else 0)
