#!/usr/bin/env python3
"""Acceptance for the FORWARD-REF path class (GH #523 second item, §9b).

THE INCIDENT THIS PINS
----------------------
The director round of 2026-09-05T13:00Z registered an owed row whose
`done_when` was `{kind: path_exists, path: tools/agent/mutstand_text_absent.sh}`
and said so in its report.  `claim_precheck.sh` answered, on a tree where the
registering commit had ALREADY been pushed:

    MISSING   path    tools/agent/mutstand_text_absent.sh
    1 finding(s)
    DO NOT PUBLISH YET

The tool was not wrong about the fact -- the file really was not there.  It was
wrong about what the fact means.  `kind: path_exists` names the artifact the
NEXT work unit must build; a row of that kind whose path already exists would
be a row that was born discharged.  So the absence is the CONTENT of the
citation, and the tool was telling a publishable report not to be published --
for every report of that shape, not once.  A stable false positive is how a
detector stops being read (GH #276), which is why IGNORED-BY-DESIGN exists too.

Exposure was not one path: on 2026-09-16 the live registry carried 7 more
`path_exists` rows whose artifact was absent by construction.

THE LOAD-BEARING CLAIMS
-----------------------
  1. a draft citing a live row's acceptance artifact exits 0, and prints the
     path under FORWARD-REF naming the row that earns it -- forgiven OUT LOUD,
     because a silent amnesty and a correct one have the same exit code;
  2. scope: a plain unpushed path still exits 3 with MISSING.  Without this,
     `return "FORWARD-REF"` unconditionally passes claim 1;
  3. scope: a RETIRED row earns nothing.  After retirement the artifact is
     supposed to exist, so its absence is a real finding;
  4. scope: `kind: path_exists` only.  Every other kind wants its `path` to be
     there (`text_absent` reads a file it requires to exist), so absence under
     those kinds is a finding;
  5. the guard: the registry is read from TRUNK.  A row that exists only in
     this container forgives nothing -- and pushing that same row flips the
     same draft to exit 0, so the guard is a guard and not a constant refusal;
  6. on-trunk resolution wins: a path that is on trunk AND is a live row's
     `done_when.path` reads OK, never FORWARD-REF;
  7. an unparseable registry withholds the downgrade repo-wide (fail closed).

Run:  python3 tests/test_citation_audit_forward_ref.py
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TOOL = os.path.join(REPO, "tools", "agent", "claim_precheck.sh")
REGISTRY = "iterations/owed_executions.json"

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)
    else:
        print("  ok    %s" % label)


def git(args, cwd):
    subprocess.run(["git"] + args, cwd=cwd, check=True, capture_output=True, text=True)


def write(path, text):
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def write_registry(root, owed, retired=(), raw=None):
    """The registry as this test needs it; `raw` writes bytes verbatim."""
    path = os.path.join(root, REGISTRY)
    if raw is not None:
        write(path, raw)
        return
    write(path, json.dumps({"owed": list(owed), "retired": list(retired)},
                           ensure_ascii=False, indent=1))


def row(row_id, kind, path):
    return {"id": row_id, "done_when": {"kind": kind, "path": path}}


def run(draft, repo):
    env = dict(os.environ, CLAIM_PRECHECK_REPO=repo)
    p = subprocess.run(["bash", TOOL, draft], cwd=REPO, env=env,
                       capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def main():
    root = tempfile.mkdtemp(prefix="citfwd-")
    try:
        # A real origin + a real clone, same shape as test_citation_audit_ignored:
        # git is the part that can be wrong, so it is not mocked.
        origin = os.path.join(root, "origin.git")
        seed = os.path.join(root, "seed")
        os.makedirs(seed)
        git(["init", "-q", "-b", "main"], seed)
        git(["config", "user.email", "t@t"], seed)
        git(["config", "user.name", "t"], seed)
        write(os.path.join(seed, "bots/BotLib/hero_axe.lua"), "-- tracked\n")
        write(os.path.join(seed, "tools/agent/already_here.py"), "# tracked\n")
        write_registry(seed, owed=[
            # the live case: artifact absent, and that is the point of the row
            row("gate_ii_new_to_test", "path_exists",
                "tools/agent/wave_reachable_delta.py"),
            # claim 4: a live row of another kind, path also absent
            row("outlatch_check1b_reason", "text_absent",
                "tests/test_outlatch_capture_liveness.py"),
            # claim 6: a live path_exists row whose artifact IS on trunk
            row("already_landed_row", "path_exists",
                "tools/agent/already_here.py"),
        ], retired=[
            # claim 3: retired -> the artifact is supposed to be there
            row("text_absent_done_when_kind", "path_exists",
                "tools/agent/mutstand_text_absent.sh"),
        ])
        git(["add", "-A"], seed)
        git(["commit", "-q", "-m", "seed"], seed)
        # `-b main` on the bare repo: without it HEAD points at `master` and the
        # clone checks nothing out, failing every case for an unrelated reason.
        git(["init", "-q", "--bare", "-b", "main", origin], root)
        git(["remote", "add", "origin", origin], seed)
        git(["push", "-q", "-u", "origin", "main"], seed)

        clone = os.path.join(root, "clone")
        git(["clone", "-q", origin, clone], root)
        git(["config", "user.email", "t@t"], clone)
        git(["config", "user.name", "t"], clone)

        draft = os.path.join(root, "draft.md")

        # --- claim 1: the incident itself, and it must print the reason.
        write(draft, "The row's acceptance artifact is "
                     "`tools/agent/wave_reachable_delta.py`, which the next work "
                     "unit builds.\n")
        rc, out = run(draft, clone)
        check(rc == 0, "live path_exists artifact alone -> exit 0 (was 3, the #523 shape)")
        check("FORWARD-REF" in out and "wave_reachable_delta.py" in out,
              "the forgiven path is printed by name, not silently dropped")
        check("gate_ii_new_to_test" in out,
              "the printed line names the owed row that earns the downgrade")
        check("MISSING" not in out, "no MISSING line for an absence by construction")

        # --- claim 2: scope.  An ordinary unpushed path is still a finding.
        write(os.path.join(clone, "tests/test_brand_new.lua"), "-- local only\n")
        git(["add", "-A"], clone)
        git(["commit", "-q", "-m", "local work"], clone)
        write(draft, "See `tests/test_brand_new.lua` and "
                     "`tools/agent/wave_reachable_delta.py`.\n")
        rc, out = run(draft, clone)
        check(rc == 3, "an ordinary unpushed path still exits 3")
        check("MISSING" in out and "test_brand_new.lua" in out,
              "the unpushed path is still named MISSING")
        check("FORWARD-REF" in out and "wave_reachable_delta.py" in out,
              "both classes coexist in one draft, each on its own line")

        # --- claim 3: a retired row earns nothing.
        write(draft, "`tools/agent/mutstand_text_absent.sh` was that row's "
                     "artifact.\n")
        rc, out = run(draft, clone)
        check(rc == 3 and "MISSING" in out,
              "a RETIRED row's artifact is not forgiven -- by then it should exist")
        check("FORWARD-REF" not in out,
              "retirement removes the downgrade, it does not keep it")

        # --- claim 4: kinds other than path_exists earn nothing.
        write(draft, "`tests/test_outlatch_capture_liveness.py` is what that "
                     "`text_absent` row reads.\n")
        rc, out = run(draft, clone)
        check(rc == 3 and "MISSING" in out,
              "a live row of another kind is not forgiven (its path must EXIST)")
        check("FORWARD-REF" not in out,
              "the downgrade is scoped to kind=path_exists, not to any done_when.path")

        # --- claim 5: the guard.  A registry row that lives only here must not
        # speak for a reader's checkout.
        local_reg = json.loads(open(os.path.join(clone, REGISTRY),
                                    encoding="utf-8").read())
        local_reg["owed"].append(row("registered_only_here", "path_exists",
                                     "tools/agent/container_only.py"))
        write_registry(clone, local_reg["owed"], local_reg["retired"])
        write(draft, "`tools/agent/container_only.py` -- owed HERE, unknown to "
                     "trunk.\n")
        rc, out = run(draft, clone)
        check(rc == 3 and "MISSING" in out,
              "a registry row that is only in this container does NOT forgive")
        check("FORWARD-REF" not in out,
              "the registry is read from trunk, so an unpushed row buys nothing")
        # ... and pushing that same row flips the same draft: a guard, not a
        # constant refusal.
        git(["add", "-A"], clone)
        git(["commit", "-q", "-m", "register row"], clone)
        git(["push", "-q", "origin", "main"], clone)
        rc, out = run(draft, clone)
        check(rc == 0 and "FORWARD-REF" in out,
              "pushing the registering commit restores the downgrade")

        # --- claim 6: on-trunk resolution wins over the registry.
        write(draft, "`tools/agent/already_here.py` is on trunk AND is a live "
                     "row's done_when.path.\n")
        rc, out = run(draft, clone)
        check(rc == 0, "a tracked path named by a live row is still fine")
        check("FORWARD-REF" not in out,
              "on-trunk resolution wins over the registry (OK, not FORWARD-REF)")

        # --- claim 7: an unreadable registry withholds the downgrade repo-wide.
        write_registry(clone, [], raw="{not json at all\n")
        git(["add", "-A"], clone)
        git(["commit", "-q", "-m", "break registry"], clone)
        git(["push", "-q", "origin", "main"], clone)
        write(draft, "`tools/agent/wave_reachable_delta.py` under a broken "
                     "registry.\n")
        rc, out = run(draft, clone)
        check(rc == 3 and "MISSING" in out,
              "an unparseable registry fails CLOSED: MISSING keeps its meaning")
        check("FORWARD-REF" not in out,
              "no path is downgraded while the registry cannot be read")
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("\n%d checks, %d failures" % (checks, len(failures)))
    for f in failures:
        print("  FAILED: %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
