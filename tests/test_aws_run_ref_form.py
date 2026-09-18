#!/usr/bin/env python3
"""Ratchet for the P4.1 ruler-wave launch defect ([harness], batch-desk 2026-09-18).

The defect, stated as the mechanism rather than the symptom:

  aws_run.sh built the A/B build command by pasting a literal 'origin/' in
  front of BOTH caller refs:

      make_ab_build.py --old 'origin/$OLD_REF' --new 'origin/$NEW_REF'

  That is correct for a branch name and *categorically wrong* for a commit
  SHA or a tag: 'origin/<sha>' is not a ref, and git rejects it outright
  ("not a valid object name").  make_ab_build.py resolves its refs with
  `git archive <ref> bots`, so the run dies before a single game is played.

  This is exactly the form P4.1 needs -- `stable(main) vs upstream(74727e4a)`,
  an old-ref given as a bare SHA -- which is why the highest-priority owed
  wave could not have launched even with budget headroom.  It stayed hidden
  because every wave since has gone through spot_run.sh --validate, a
  different path that never touches these two lines.

  Failure direction is the dangerous one only in cost, not in data: the
  missing bots dirs trip ab_guard (Y1, 2026-09-05), so the run refuses to
  play instead of uploading an A/A of stock bots as if it were a result.

What this file covers, and what it does NOT:
  * The ref-form fix is covered BEHAVIOURALLY -- aws_run.sh is really run
    (with `aws` stubbed, so nothing is launched and no AWS call is made),
    the rendered user-data is captured, and the resolver lifted out of it is
    executed against a REAL temporary git repo with a branch, a tag and a
    bare SHA.
  * The shallow-clone deepening is covered STRUCTURALLY ONLY (the guard's
    presence and its is-shallow condition).  Whether the AMI's /opt/dota2bot
    is in fact shallow cannot be read from a dev container, and this file
    does NOT claim it either way.

Run:  python3 tests/test_aws_run_ref_form.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
AWS_RUN = os.path.join(ROOT, "tools", "batch_test", "aws", "aws_run.sh")

failures = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        print("  FAIL %s" % msg)
        failures.append(msg)


def render_user_data(argv):
    """Run aws_run.sh for real with `aws` stubbed; return the user-data it built.

    Nothing is launched: the stub intercepts `ec2 run-instances`, dumps the
    --user-data argument and returns a fake instance id.
    """
    src = open(AWS_RUN).read()
    anchor = "source aws.env\n"
    assert anchor in src, "aws_run.sh no longer sources aws.env"
    dump = os.path.join(tempfile.mkdtemp(), "user_data.sh")
    stub = (
        'aws() {\n'
        '    if [ "$1" = "ec2" ] && [ "$2" = "run-instances" ]; then\n'
        '        while [ $# -gt 0 ]; do\n'
        '            if [ "$1" = "--user-data" ]; then printf "%s" "$2" > ' + dump + '; fi\n'
        '            shift\n'
        '        done\n'
        '        echo "i-stubbed0000000"; return 0\n'
        '    fi\n'
        '    return 0\n'
        '}\n'
    )
    src = src.replace(anchor, anchor + stub, 1)
    tmp = os.path.join(os.path.dirname(dump), "aws_run_stub.sh")
    with open(tmp, "w") as fh:
        fh.write(src)
    os.chmod(tmp, 0o755)
    # aws_run.sh does `cd "$(dirname "$0")"` then `source aws.env`, so the
    # config has to sit next to the stub copy.
    shutil.copy(os.path.join(os.path.dirname(AWS_RUN), "aws.env"),
                os.path.join(os.path.dirname(dump), "aws.env"))
    proc = subprocess.run(["bash", tmp] + argv, capture_output=True, text=True)
    if not os.path.exists(dump):
        raise AssertionError(
            "aws_run.sh produced no user-data (rc=%d)\nstdout:%s\nstderr:%s"
            % (proc.returncode, proc.stdout, proc.stderr))
    return open(dump).read()


def make_repo():
    """A real git repo with a branch, a tag and a commit reachable only by SHA."""
    d = tempfile.mkdtemp()
    run = lambda *a: subprocess.run(a, cwd=d, check=True, capture_output=True)
    run("git", "init", "-q", "-b", "main")
    run("git", "config", "user.email", "t@t")
    run("git", "config", "user.name", "t")
    os.mkdir(os.path.join(d, "bots"))
    open(os.path.join(d, "bots", "x.lua"), "w").write("-- x\n")
    run("git", "add", "-A")
    run("git", "commit", "-qm", "c1")
    sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=d,
                         capture_output=True, text=True, check=True).stdout.strip()
    run("git", "tag", "v-test")
    # give the repo an 'origin/main' remote-tracking ref without a network
    run("git", "update-ref", "refs/remotes/origin/main", sha)
    return d, sha


def resolver_says(repo, ref):
    """Run the resolve_ref lifted from the rendered user-data. Returns (rc, out)."""
    body = re.search(r"^resolve_ref\(\) \{.*?^\}", USER_DATA, re.S | re.M)
    assert body, "resolve_ref() not found in the rendered user-data"
    # the instance runs every git call through 'sudo -u ubuntu'; locally we are
    # already the owner of the temp repo, so neutralise just that prefix
    fn = body.group(0).replace("sudo -u ubuntu ", "")
    script = fn + '\nresolve_ref "$1"\n'
    p = subprocess.run(["bash", "-c", script, "-", ref], cwd=repo,
                       capture_output=True, text=True)
    return p.returncode, p.stdout.strip()


print("== rendering the real user-data (nothing is launched) ==")
USER_DATA = render_user_data(["-n", "4", "--old", "74727e4a66ab38d16fdb09800a19ab6c0c82c6b9",
                              "--new", "main"])
print("  rendered %d bytes" % len(USER_DATA))

print("\n== 1. the defect itself: no hardcoded origin/ prefix on a caller ref ==")
check("--old 'origin/" not in USER_DATA,
      "user-data does not paste origin/ in front of --old")
check("--new 'origin/" not in USER_DATA,
      "user-data does not paste origin/ in front of --new")
check("$OLD_ARCHIVE_REF" in USER_DATA and "$NEW_ARCHIVE_REF" in USER_DATA,
      "make_ab_build.py is handed the RESOLVED refs")
# both directions (fwd and the --swap rev leg) must use the resolved refs
check(len(re.findall(r'make_ab_build\.py --old "\$OLD_ARCHIVE_REF"', USER_DATA)) == 2,
      "both A/B legs (fwd and --swap rev) use the resolved refs")

print("\n== 2. resolver behaviour against a real git repo ==")
repo, sha = make_repo()
rc, out = resolver_says(repo, "main")
check(rc == 0 and out == "origin/main",
      "a branch name resolves to origin/<name>, got rc=%d %r" % (rc, out))
rc, out = resolver_says(repo, sha)
check(rc == 0 and out == sha,
      "a bare SHA resolves to itself (NOT origin/<sha>), got rc=%d %r" % (rc, out))
rc, out = resolver_says(repo, "v-test")
check(rc == 0 and out == "v-test",
      "a tag resolves to itself, got rc=%d %r" % (rc, out))
rc, out = resolver_says(repo, "no-such-ref-anywhere")
check(rc != 0,
      "an unresolvable ref fails loudly (rc!=0), got rc=%d %r" % (rc, out))

print("\n== 3. positive control: the OLD form really was broken ==")
# Proves the fix addresses a real mechanism rather than matching a conclusion:
# git itself must reject 'origin/<sha>' in the very call make_ab_build.py makes.
p = subprocess.run(["git", "archive", "origin/" + sha, "bots"], cwd=repo,
                   capture_output=True)
check(p.returncode != 0,
      "git archive origin/<sha> is rejected (rc=%d) -- the old form could not work"
      % p.returncode)
p = subprocess.run(["git", "archive", sha, "bots"], cwd=repo, capture_output=True)
check(p.returncode == 0 and len(p.stdout) > 0,
      "git archive <bare sha> succeeds -- the new form works")

print("\n== 4. unresolvable ref dies at the ref, not later as a build failure ==")
check("cannot resolve --old ref" in USER_DATA and "cannot resolve --new ref" in USER_DATA,
      "the user-data names the ref as the cause, not 'A/B build failed'")
# anchor on the real INVOCATION, not on the word: the file also mentions
# make_ab_build.py inside the Y1 comment, well above it.
_first_build = re.search(r"^sudo -u ubuntu python3 tools/batch_test/make_ab_build\.py",
                         USER_DATA, re.M)
check(_first_build is not None
      and USER_DATA.index("OLD_ARCHIVE_REF=") < _first_build.start(),
      "refs are resolved BEFORE the first build attempt")

print("\n== 5. shallow deepening (STRUCTURAL only -- the AMI is not readable here) ==")
check("--is-shallow-repository" in USER_DATA,
      "the deepen step is guarded on the clone actually being shallow")
check("git fetch --unshallow origin" in USER_DATA,
      "a shallow clone is deepened before refs are resolved")
check(USER_DATA.index("--is-shallow-repository") < USER_DATA.index("resolve_ref() {"),
      "deepening happens before resolution")

print("")
if failures:
    print("FAILED %d check(s):" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")
