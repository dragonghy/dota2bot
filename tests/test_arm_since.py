#!/usr/bin/env python3
"""[ratchet] tools/agent/arm_since.py -- the three ways it can lie.

WHY EACH CHECK EXISTS (a check without a failure mode is decoration).

1. THE PARSER MUST MATCH A FORM, NOT A KEYWORD.  The first draft matched any
   line containing 入集 and collected every backticked id on it.  On the real
   file that read `**⚠️ 收割前必读(§DK.3,`slotarb` 的入集是条件性的...` as an
   admission event for `slotarb` -- a warning about a past admission, dated by
   whatever section happened to be above it.  A wrong date here is worse than
   no date: it is P4.2's sort key, so a false-old row promotes an id to the
   front of the 退集 queue and a false-new row hides one.  The negative rows
   below are the exact prose forms that live in test_set.md today
   (`不提入集` / `重新入集路径` / `的入集是条件性的` / `X 退集`).

2. AN ARMED ID WITH NO ROW MUST BE A FINDING, NOT A BLANK.  The registry's
   whole job is that admitting an id without recording when is caught in the
   same round.  A tool that prints "-" and exits 0 for an unpinned id is the
   `pending_rulings.py` "none" shape: it looks like an answer.

3. A RETIRED ID MUST BE STAMPED, NOT DELETED.  `retired_at` is what lets a
   re-admitted id say how long its PREVIOUS stint was.  Deleting the row on
   退集 passes every other check in this file and silently destroys that.

WHAT THIS FILE DOES NOT ASSERT: that any particular date in the real registry
is CORRECT.  The tool reads prose; the prose can be wrong.  What is pinned is
that a disagreement between the prose and an `exact` pin is REPORTED and never
silently auto-corrected (check 4), because "the archive was rewritten" and
"the pin is wrong" are indistinguishable from inside the tool.

Run: python3 tests/test_arm_since.py
"""

import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "arm_since.py")

checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


def load_tool():
    sys.path.insert(0, os.path.join(REPO, "tools", "agent"))
    import arm_since  # noqa: E402
    return arm_since


def run_in(root):
    """Run the tool against a synthetic repo root; return (rc, stdout)."""
    env = dict(os.environ)
    p = subprocess.run([sys.executable, os.path.join(root, "tools", "agent",
                                                     "arm_since.py"), "--all"],
                       capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def build_root(tmp, armed, rows, extra_md=""):
    for d in ("tools/agent", "iterations/streams", "iterations/reports/director"):
        os.makedirs(os.path.join(tmp, d), exist_ok=True)
    with open(TOOL, encoding="utf-8") as fh:
        src = fh.read()
    with open(os.path.join(tmp, "tools/agent/arm_since.py"), "w",
              encoding="utf-8") as fh:
        fh.write(src)
    with open(os.path.join(tmp, "iterations/streams/test_set.md"), "w",
              encoding="utf-8") as fh:
        fh.write("# head\n" + ",".join(armed) + "\n" + extra_md + "\n")
    with open(os.path.join(tmp, "iterations/armed_since.json"), "w",
              encoding="utf-8") as fh:
        json.dump({"ids": rows}, fh, ensure_ascii=False)
    with open(os.path.join(tmp, "iterations/state.json"), "w",
              encoding="utf-8") as fh:
        json.dump({}, fh)


# ---------------------------------------------------------------- check 1
A = load_tool()
armed = ["slotarb", "campsel", "towerfear", "zzz"]

POSITIVE = [
    ("2026-09-04T10:xxZ 的变动:`campsel` 入集**(60 → 61", "campsel"),
    ("- **`slotarb` 入集**(协同组 02:0xZ 提议", "slotarb"),
    ("`campsel` / `slotarb` **三条同轮入集**(44 → 47", "campsel"),
]
for text, want in POSITIVE:
    got = [i for i, _d, _l in A.scan_text("2026-09-04T00:00Z\n" + text, armed)]
    check("admission form is matched: %s" % want, want in got,
          "line=%r got=%r" % (text[:40], got))

NEGATIVE = [
    "**⚠️ 收割前必读(§DK.3,`campsel` 的入集是条件性的,这一条不成立时",
    "- **甲 → 总监**:`campsel` 登记在案,本轮**不提入集**(P4.2 冻结)",
    "⛔ 退集不是 reject,gate 逐字保留;`campsel` 重新入集**路径写在 §FB.5",
    "1. **`campsel` 退集**(61 → 60)—— armed 17 天,`verify_coverage.py` 读 verify=0",
]
for text in NEGATIVE:
    got = [i for i, _d, _l in A.scan_text("2026-09-04T00:00Z\n" + text, armed)]
    check("non-admission prose is NOT an event: %r" % text[:22], not got,
          "got=%r" % (got,))

# ---------------------------------------------------------------- checks 2-4
with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, ["aaa", "bbb"],
               {"aaa": {"armed_since": "2026-08-01", "precision": "exact",
                        "source": "x"}})
    rc, out = run_in(tmp)
    check("armed id with no row => exit 3", rc == 3, "rc=%d" % rc)
    check("armed id with no row => named UNPINNED", "UNPINNED" in out
          and "bbb" in out, out[-400:])

with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, ["aaa"],
               {"aaa": {"armed_since": "2026-08-01", "precision": "exact",
                        "source": "x"},
                "ghost": {"armed_since": "2026-07-01", "precision": "exact",
                          "source": "x"}})
    rc, out = run_in(tmp)
    check("row not in the armed string and unstamped => exit 3", rc == 3,
          "rc=%d" % rc)
    check("row not in the armed string and unstamped => STALE ROW",
          "STALE ROW" in out and "ghost" in out, out[-400:])

with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, ["aaa"],
               {"aaa": {"armed_since": "2026-08-01", "precision": "exact",
                        "source": "x"},
                "ghost": {"armed_since": "2026-07-01", "precision": "exact",
                          "source": "x", "retired_at": "2026-09-01"}})
    rc, out = run_in(tmp)
    check("a STAMPED retired row is clean => exit 0", rc == 0,
          "rc=%d out=%s" % (rc, out[-300:]))

with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, ["aaa"],
               {"aaa": {"armed_since": "2026-08-01", "precision": "exact",
                        "source": "x"}},
               extra_md="本行 **2026-09-04T10:xxZ 的变动:`aaa` 入集**(1 → 2)")
    rc, out = run_in(tmp)
    check("prose disagreeing with an exact pin => exit 3", rc == 3, "rc=%d" % rc)
    check("prose disagreeing with an exact pin => CONTRADICTION, not a silent "
          "rewrite", "CONTRADICTION" in out and "2026-08-01" in out, out[-400:])
    after = json.load(open(os.path.join(tmp, "iterations/armed_since.json"),
                           encoding="utf-8"))
    check("a CONTRADICTION does not edit the registry",
          after["ids"]["aaa"]["armed_since"] == "2026-08-01",
          str(after["ids"]["aaa"]))

with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, ["aaa"], {})
    os.remove(os.path.join(tmp, "iterations/armed_since.json"))
    rc, out = run_in(tmp)
    check("missing registry => could-not-run 2, not a pass", rc == 2,
          "rc=%d" % rc)
    check("missing registry => banner says it is not a pass",
          "NOT a pass" in out, out[-300:])

# ------------------------------------------------------- the real tree
rc = subprocess.run([sys.executable, TOOL], capture_output=True, text=True)
check("the real registry pins every armed id (exit 0)", rc.returncode == 0,
      "rc=%d\n%s" % (rc.returncode, rc.stdout[-600:]))

failed = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    if not ok:
        print("FAIL  %s\n        %s" % (name, detail))
print("%d checks, %d failed" % (len(checks), len(failed)))
sys.exit(1 if failed else 0)
