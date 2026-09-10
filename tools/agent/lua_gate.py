#!/usr/bin/env python3
"""Iron rule 6's fast Lua TEST leg, for the push hook (GH #624).

Runs the Lua ratchets `tools/agent/lua_gate_measure.py` measured as cheap
enough for a hook, and reports in the repo's 0/2/3 vocabulary:

    0  clean          every in-scope test passed
    2  could not run  something in scope did not produce an answer
    3  findings       an in-scope test failed

`.githooks/pre-push` refuses the push on BOTH 2 and 3, exactly as it already
does for the Lua static half and the python half.  "Could not run" reading as
"allowed" is how GH #171's SKIP and GH #205's `Unable to locate package` each
became an established fact.

WHAT WAS MISSING WITHOUT IT (GH #624).  The hook covered `luacheck` (a LINTER --
it never executes a test body) and the fast PYTHON ratchets (GH #616).  The Lua
census/ratchet tests were in no push gate at all.  Their failure mode is
structural, not accidental: a census asserts "the set of X in the corpus is
exactly the set that has been read", so ANY stream landing a new gate, call
site or ability instance turns one red -- and the pusher's own gate said
nothing, so the red was found by the NEXT stream to start work, hours later,
with the author already gone.  Measured four times by 2026-09-10; on that
morning THREE were red on `main` simultaneously.

⛔ MEMBERSHIP IS BY MEASURED SECONDS, NEVER BY FILENAME.  See the header of
`lua_gate_measure.py`; this file only reads the manifest that tool writes.

THE ONE DISTINCTION THAT CARRIES WEIGHT, inherited verbatim from `py_gate.py`.
A test that does not answer inside its timeout is handled by whether we had
ALREADY MEASURED IT:

  * measured fast, now times out -> a CHANGE OF STATE on a test this gate
    promised to run.  Exit 2, push refused, re-measure.
  * never measured (new file)    -> out of scope, named in the banner, no
    refusal.  It was never promised; 开工自检 and the full suite still cover it.

⚠️ WHAT THIS DOES NOT CLAIM.  Not the Lua suite.  The full run is ~100 min in
one process (GH #124) and stays where it is; every test this gate leaves out is
named with a `reason` in the manifest, so "why was this not caught at push
time" is answerable without guessing.  A wrapper whose banner claims more than
it asserts is a trap this repo has already paid for (GH #198 §2).

⭐⭐ SCOPE IS CONTROLLED BY WHAT THE PUSH TOUCHES, NOT BY A SECONDS BUDGET, and
that is the ruling's load-bearing choice.  See `lua_gate_measure.py`'s
BUDGET_SECONDS note for the measurement that forced it: on the 18 tests red on
trunk the day this landed, a 25s cheapest-first budget caught 3 and a 25s
expensive-first budget caught 0, because the reds run from 0.13s to 5.12s and
no cheap subset contains them.  So the hook runs EVERY sub-cap test -- but only
when the push actually carries Lua corpus or tests (`--if-touched`, GH #624
option 1 word for word: "even if only run when the files they each touch are
changed").  A report-only push, which is most of them, costs nothing.

⚠️ WHAT THE SCOPING GIVES UP, stated rather than implied: a push that touches no
Lua no longer NOTICES a red another stream left on trunk.  GH #616 valued that
side effect explicitly.  It is given up on purpose -- a gate that taxes every
push 2.5 minutes teaches its users `RULE6_BYPASS=1`, which is the failure GH
#707 is open about -- and 开工自检 still reads trunk every round.
⛔ The scope test FAILS CLOSED: an unreadable path list, an empty one, or any
error means RUN EVERYTHING.  Skipping is only ever done on a positive answer.

Usage:  python3 tools/agent/lua_gate.py [--list] [--if-touched <path>...]
"""
import json
import os
import re
import subprocess
import sys
import time

# this file is tools/agent/<me>.py -- three dirnames up is the repo root
_DEFAULT_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
# Overridable so tests/test_lua_gate.py can stand up a throwaway repo and drive
# every branch.  An override is ANNOUNCED at the top of every run (see main): a
# gate that can be pointed somewhere else quietly is a gate that can be dodged
# quietly.
ROOT = os.environ.get("LUA_GATE_ROOT") or _DEFAULT_ROOT
MANIFEST = os.environ.get("LUA_GATE_MANIFEST") or os.path.join(
    ROOT, "tools", "agent", "lua_gate_manifest.json"
)
LUA = os.environ.get("LUA_BIN", "lua5.1")

EXIT_CLEAN = 0
EXIT_UNRUN = 2
EXIT_FINDINGS = 3


def load_manifest(path=MANIFEST):
    with open(path) as fh:
        return json.load(fh)


def discover(root=ROOT):
    d = os.path.join(root, "tests")
    if not os.path.isdir(d):
        return []
    return sorted(
        os.path.join("tests", f)
        for f in os.listdir(d)
        if f.startswith("test_") and f.endswith(".lua")
    )


def partition(manifest, on_disk):
    """Split the on-disk tests into (selected, skipped, unmeasured, missing).

    Membership comes from the manifest's `in_gate` flag, which
    lua_gate_measure.py sets from MEASURED SECONDS.  Nothing here looks at a
    filename to decide whether a test belongs in the gate.
    """
    tests = manifest.get("tests", {})
    on_disk = set(on_disk)
    selected, skipped = [], []
    for rel, meta in sorted(tests.items()):
        if rel not in on_disk:
            continue
        (selected if meta.get("in_gate") else skipped).append(rel)
    unmeasured = sorted(on_disk - set(tests))
    missing = sorted(
        rel for rel, meta in tests.items() if meta.get("in_gate") and rel not in on_disk
    )
    return selected, skipped, unmeasured, missing


def ensure_lua(root=ROOT):
    """Buy lua5.1 if the container lacks it; return True if it is runnable.

    GH #205's whole finding was that "the container does not have it" was
    treated as an unchangeable fact for the life of a mandatory gate.  The
    helper is bounded, guarded and silent on failure, and measured 4s.
    """
    helper = os.path.join(root, "tools", "agent", "ensure_lua_toolchain.sh")
    if not os.path.isfile(helper):
        return _lua_runs()
    try:
        subprocess.run(
            ["bash", helper, LUA],
            cwd=root,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=120,
        )
    except Exception:
        pass
    return _lua_runs()


def _lua_runs():
    try:
        p = subprocess.run(
            [LUA, "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30
        )
        return p.returncode == 0
    except Exception:
        return False


def run_one(rel, timeout, root=ROOT):
    """Return (rc, output, seconds, timed_out); rc is None on timeout.

    The runner takes a FILENAME SUBSTRING, not a path (`tests/run_tests.lua`
    header), so the basename is what goes on the command line.  Running the
    file directly instead would load the module and assert NOTHING while
    exiting 0 -- a did-not-run wearing a pass, which the runner's own GH #200
    guard exists to prevent.  This gate therefore only ever goes through the
    runner.
    """
    name = os.path.basename(rel)
    t0 = time.time()
    try:
        p = subprocess.run(
            [LUA, "tests/run_tests.lua", name],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
        return p.returncode, p.stdout.decode("utf-8", "replace"), time.time() - t0, False
    except subprocess.TimeoutExpired as exc:
        out = (exc.output or b"").decode("utf-8", "replace")
        return None, out, time.time() - t0, True


# `FAIL: <file> :: <case>` and its numbered twin `FAIL[3]: <file> :: <case>`.
# The runner prints both (once at the failure, once in the trailing summary);
# a set dedupes them.
FAIL_CASE_RE = re.compile(r"^FAIL(?:\[\d+\])?:\s+\S+\s+::\s+(.+?)\s*$", re.M)


def failing_cases(out):
    """The set of test-CASE names named in a runner's FAIL lines.

    WHY THE CASE NAME IS THE RIGHT GRAIN (director 2026-09-10, GH #624 follow-on).
    The case name is a literal string in the test file, so it is STABLE while
    the numbers inside the assertion move.  Measured, not assumed: across the
    8-frame corpus commit `44a83380`, `test_wk_q_lane_reach`'s assertion moved
    from "alive on 44 corpus frames" to "alive on 51" while its case name --
    "§1 the corpus puts an enemy in the band on 6 of 38 Wraith King frames" --
    was byte-identical on both sides.

    That is what makes a case-level baseline affordable: it does NOT re-refuse
    on ordinary corpus drift (which would turn the gate back into the blockade
    the baseline exists to prevent), and it DOES refuse when a baselined file
    starts failing somewhere it never failed before.

    ⛔ An empty return from a red file is not "no new cases" -- it is a red
    whose shape this parser does not recognise, and the caller treats it as
    new.  Silence must not be the permissive answer.
    """
    return {m.group(1) for m in FAIL_CASE_RE.finditer(out)}


def indent(text, pad="      "):
    return "".join(pad + line + "\n" for line in text.rstrip("\n").split("\n"))


# A path under one of these can change what a Lua test asserts.  `bots/` and
# `game/` are the corpus every census walks; `tests/` is the tests themselves
# (and their fixtures and mocks).  Everything else -- reports, charters,
# `tools/`, `iterations/` -- cannot turn a Lua test red, which is what makes
# skipping them safe rather than merely cheap.
IN_SCOPE_PREFIXES = ("bots/", "game/", "tests/")


def touches_lua(paths):
    """True if this push can move a Lua test's answer.  FAILS CLOSED.

    Returns True for an empty or unparseable list: "we could not tell" and "it
    is safe to skip" are different sentences, and a gate that confuses them is
    the whole family of defect this repo keeps paying for (GH #171 SKIP,
    GH #205, and the CI smoke job found while ruling GH #624 -- three separate
    cases of a did-not-run wearing a pass).
    """
    if not paths:
        return True
    return any(p.startswith(IN_SCOPE_PREFIXES) for p in paths if p)


def main(argv):
    if os.environ.get("LUA_GATE_ROOT") or os.environ.get("LUA_GATE_MANIFEST"):
        print("LUA GATE REDIRECTED -- root=%s manifest=%s (not the repo's own)"
              % (ROOT, MANIFEST))
    try:
        manifest = load_manifest()
    except Exception as exc:  # missing, unreadable, malformed
        print("LUA GATE COULD NOT RUN -- manifest unreadable: %s" % exc)
        print("  Regenerate it:  python3 tools/agent/lua_gate_measure.py")
        return EXIT_UNRUN

    cap = float(manifest.get("per_test_cap_seconds", 3.0))
    timeout = float(manifest.get("hook_timeout_seconds") or max(cap * 5.0, 20.0))

    if "--if-touched" in argv:
        paths = [a for a in argv[argv.index("--if-touched") + 1:]
                 if not a.startswith("--")]
        if not touches_lua(paths):
            print("lua gate: SKIPPED BY SCOPE -- this push touches no %s path."
                  % "/".join(p.rstrip("/") for p in IN_SCOPE_PREFIXES))
            print("  %d path(s) offered, none of which can move a Lua test's "
                  "answer: %s" % (len(paths), " ".join(sorted(paths)[:8])))
            print("  This is a SCOPE decision, not a pass and not a skip of a "
                  "gate that had something to say (GH #624).")
            return EXIT_CLEAN

    on_disk = discover()
    selected, skipped, unmeasured, missing = partition(manifest, on_disk)

    if "--list" in argv:
        for rel in selected:
            print("IN   %s  (%.2fs)" % (rel, manifest["tests"][rel]["seconds"]))
        for rel in skipped:
            m = manifest["tests"][rel]
            print("OUT  %s  (%.2fs, %s)" % (rel, m["seconds"], m["reason"]))
        for rel in unmeasured:
            print("NEW  %s  (never measured)" % rel)
        return EXIT_CLEAN

    if not selected:
        print("LUA GATE COULD NOT RUN -- the manifest selected 0 tests.")
        print("  Regenerate it:  python3 tools/agent/lua_gate_measure.py")
        return EXIT_UNRUN

    if not ensure_lua():
        # Deliberately not shaped like the clean line at the bottom.  This is
        # GH #171's ruling applied to a new leg rather than re-learned on it.
        print("LUA GATE COULD NOT RUN -- no %s, and the install attempt failed."
              % LUA)
        print("  This line is NOT a pass. Buy it with: apt-get install -y %s" % LUA)
        return EXIT_UNRUN

    # The baseline of tests already red when this leg landed.  See
    # `lua_gate_measure.py:set_known_red` for why it exists and what it costs;
    # the short version is that this leg landed on a tree with 18 Lua tests
    # already red, so its promise is "you did not ADD a red", not "the suite is
    # green".  A missing key is an EMPTY baseline, never a permissive one.
    known_red = set(manifest.get("known_red") or ())
    # Per-file: the set of test-CASE names that were failing when the baseline
    # was taken.  A file listed in `known_red` but absent here keeps the old
    # file-level amnesty (backward compatible, and never more permissive than
    # before); a file present here is amnestied only for THOSE cases.
    known_cases = manifest.get("known_red_cases") or {}

    t0 = time.time()
    findings, unrun, new_over_budget = [], [], []
    known_hit, healed, healed_cases = [], [], []
    ran = 0

    for rel in selected:
        rc, out, secs, timed_out = run_one(rel, timeout)
        if timed_out:
            # Measured fast, now will not answer: a change of state on a test
            # this gate promised to run.  Not a pass.
            unrun.append((rel, "timed out after %.0fs (manifest says %.2fs)"
                          % (secs, manifest["tests"][rel]["seconds"]), out))
        elif rc == 0:
            ran += 1
            if rel in known_red:
                healed.append(rel)
        elif rel in known_red:
            ran += 1
            expected = known_cases.get(rel)
            if expected is None:
                # Legacy file-level baseline: no case list was recorded, so
                # there is nothing to compare against and the old amnesty
                # stands.  The ⛔ line below still names this case.
                known_hit.append(rel)
                continue
            seen = failing_cases(out)
            new_cases = sorted(seen - set(expected))
            if not seen:
                findings.append((rel, "baselined, but this red names no test "
                                 "case at all -- a shape the baseline never "
                                 "saw, so it is NOT covered by it", out))
            elif new_cases:
                findings.append((rel, "baselined for %d case(s), but these are "
                                 "NOT among them: %s"
                                 % (len(expected), "; ".join(new_cases)), out))
            else:
                known_hit.append(rel)
                gone = sorted(set(expected) - seen)
                if gone:
                    healed_cases.append((rel, gone))
        else:
            findings.append((rel, "exit %d" % rc, out))
            ran += 1

    # New tests nobody has measured yet: run them, but a slow one is out of
    # scope rather than a refusal -- this gate never promised to carry it.
    for rel in unmeasured:
        rc, out, secs, timed_out = run_one(rel, timeout)
        if timed_out:
            new_over_budget.append(rel)
        elif rc == 0:
            ran += 1
        else:
            findings.append((rel, "exit %d" % rc, out))
            ran += 1

    elapsed = time.time() - t0

    for rel, why, out in findings:
        print("FAIL  %s  (%s)" % (rel, why))
        print(indent(out), end="")
    for rel, why, out in unrun:
        print("UNCERTIFIABLE  %s  (%s -- not a pass and not a failure)" % (rel, why))
        if out.strip():
            print(indent(out), end="")

    print(
        "\nlua gate: %d ran, %d findings, %d uncertifiable, %d known-red, %.1fs"
        % (ran, len(findings), len(unrun), len(known_hit), elapsed)
    )
    if known_hit:
        # BY NAME, every run.  A baseline that shows only as a count is an
        # amnesty nobody can act on; the whole defence against this list
        # becoming permanent is that it is impossible to read the gate's output
        # without reading the list.
        print("  %d test(s) were ALREADY RED when this leg landed (GH #624) and"
              " did not refuse this push:" % len(known_hit))
        for rel in known_hit:
            n = len(known_cases.get(rel) or ())
            print("      %s%s" % (rel, ("  [amnestied for %d case(s); any OTHER"
                                        " case refuses]" % n) if n else
                                  "  [FILE-LEVEL amnesty -- any red here reads"
                                  " as known]"))
        print("  ⛔ this list is not an exemption and it is meant to SHRINK.")
        blind = [r for r in known_hit if not known_cases.get(r)]
        if blind:
            print("  ⛔ %d of them carry no case list, so a SECOND, NEW reason"
                  " there still reads as known -- re-take the baseline to give"
                  " them one: %s" % (len(blind), " ".join(blind)))
    if healed:
        print("  %d baselined test(s) are GREEN again -- take them off the"
              " baseline so they start refusing again:" % len(healed))
        for rel in healed:
            print("      %s" % rel)
        print("  python3 tools/agent/lua_gate_measure.py --set-known-red <file>")
    if healed_cases:
        # Partial shrink: the file is still red, but strictly less of it is.
        # Without this line the only visible states are "red" and "green", and
        # a baseline that is quietly getting smaller looks identical to one
        # that is not moving at all.
        print("  %d baselined test(s) are red for FEWER cases than at landing"
              " -- re-take the baseline so the amnesty narrows with them:"
              % len(healed_cases))
        for rel, gone in healed_cases:
            print("      %s  (no longer failing: %s)" % (rel, "; ".join(gone)))
    print(
        "  scope: %d fast Lua ratchets (selected by measured seconds < %.1fs, "
        "cumulative budget %.1fs)" % (len(selected), cap, manifest.get("budget_seconds", 0.0))
    )
    print(
        "  NOT claimed here: %d slower Lua tests -- the full suite (~100 min, "
        "GH #124) is still the only thing that runs them all." % len(skipped)
    )
    if unmeasured:
        print("  %d new test(s) not in the manifest were run anyway: %s"
              % (len(unmeasured), " ".join(unmeasured)))
    if new_over_budget:
        print("  %d new test(s) exceeded the hook budget and were EXCLUDED: %s"
              % (len(new_over_budget), " ".join(new_over_budget)))
        print("  (re-measure to record them: python3 tools/agent/lua_gate_measure.py)")
    if missing:
        print("  %d manifest test(s) are gone from disk (renamed/deleted): %s"
              % (len(missing), " ".join(missing)))

    if findings:
        return EXIT_FINDINGS
    if unrun:
        return EXIT_UNRUN
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
