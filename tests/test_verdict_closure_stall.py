#!/usr/bin/env python3
"""Acceptance for tools/agent/verdict_closure_stall.py (RULING 73 ⑧(b)).

WHY THE SHAPE OF THIS SUITE.  The subject's honest answer on the day it lands is
`STALL 1 -- OK`, exit 0.  That is the same line a subject which can see nothing
prints, and this lab has paid for that confusion three times (GH #171 `SKIP` is
not a pass, GH #200 zero test bodies also exit 0, RULING 72's 0.006s false
green).  ⭐ So NON-VACUITY IS THE PRIMARY CLAIM here, and it is bought with the
REAL founding corpus, not a hand-drawn one: the 23-round stall RULING 73 found
by hand is replayed from synthetic history lines shaped exactly like
`test_set.md`'s, and the subject must go red on it.

The load-bearing claims, in the order they can fail:
  1. it goes RED on the founding case (>= 12 rounds, exit 3) and names the
     director seat -- iron rule 9's self-referential open circuit closed.
  2. AN ADMISSION DOES NOT RESET IT.  `test_set.md:142` (`arbheart` +
     `slotwait` 同轮入集) moved the member string and closed no verdict; an
     anchor keyed on "the string moved" would read that as progress, and that
     failure direction HIDES a stall.  `判定完结 0` likewise.
  3. FILING A REPORT CAN NEVER SATISFY IT (RULING 73 ⑧(b) is literal).  Adding
     reports newer than the anchor may only make the number BIGGER.
  4. an empty / unreadable corpus is exit 2, never 0 -- "0 rounds of stall" is
     precisely the reading that looks like health (RULING 55).
  5. no qualifying history line is exit 2, not a pass.
  6. a fuzzy stamp resolves to the EARLIEST instant (the loud side), so the
     count can over-state by at most one round and never under-state.
  7. the thresholds bite where iron rule 9 says: 11 green, 12 点名, 24
     DECISIONS_NEEDED.
  8. it stays cheap and executes nothing.

Run:  python3 tests/test_verdict_closure_stall.py
"""

import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SUBJECT = os.path.join(REPO, "tools", "agent", "verdict_closure_stall.py")
# Overridable ONLY so the mutation stand can point at a mutated COPY in a temp
# dir (evidence discipline 1: never write the repo file).
SUBJECT = os.environ.get("VERDICT_CLOSURE_SUBJECT", SUBJECT)

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


HEAD = ("**成员串 24**(上一行,**209 字节**,md5 `f7e1812e`)。本行 "
        "**%s 的变动:一条 `RETURNED`(退集,25 → 24,`stayfield2`)**,"
        "总监裁定全文 **§HN**;判定完结 **%s**。\n")
OLDER = ("〔沿革,上一条变动〕**成员串 25**(**220 字节**,md5 `850bdee1`)。"
         "**%s 的变动:一条 `RETURNED`(26 → 25,`stayfield`)**,全文 §HK;"
         "判定完结 **1**。\n")


def write_testset(path, head_stamp, head_closures="1", older_stamp=None,
                  head_line=None):
    body = ["# 当前测试集(测试版 = 稳定版 + 以下 armed)\n", "a,b,c\n"]
    body.append(head_line if head_line is not None
                else HEAD % (head_stamp, head_closures))
    if older_stamp:
        body.append(OLDER % older_stamp)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("".join(body))


def write_reports(path, names):
    with open(path, "w", encoding="utf-8") as fh:
        for n in names:
            fh.write("iterations/reports/director/%s.md\n" % n)


def run(testset, reports, decisions=None):
    env = dict(os.environ)
    env["VERDICT_CLOSURE_TESTSET"] = testset
    env["VERDICT_CLOSURE_REPORT_LIST"] = reports
    if decisions:
        env["VERDICT_CLOSURE_DECISIONS"] = decisions
    p = subprocess.run([sys.executable, SUBJECT], capture_output=True,
                       text=True, timeout=120, env=env)
    return p.returncode, p.stdout + p.stderr


def rounds(n, day=15, start_hour=0):
    """n distinct director report stamps, all after 2026-09-14T16:00Z."""
    out = []
    for i in range(n):
        d = day + (start_hour + i * 2) // 24
        h = (start_hour + i * 2) % 24
        out.append("202609%02dT%02d0000Z" % (d, h))
    return out


root = tempfile.mkdtemp(prefix="verdict_closure_")
try:
    ts = os.path.join(root, "test_set.md")
    rp = os.path.join(root, "reports.txt")
    dn = os.path.join(root, "DECISIONS_NEEDED.md")
    with open(dn, "w", encoding="utf-8") as fh:
        fh.write("nothing here\n")

    # --- 1. the founding case: 23 rounds with the string frozen -------------
    write_testset(ts, "2026-09-14T16:xxZ")
    write_reports(rp, rounds(23))
    rc, out = run(ts, rp, dn)
    check(rc == 3, "1a: the founding 23-round stall must exit 3 (got %d)" % rc)
    check("STALL         : 23" in out,
          "1b: it must COUNT 23, not merely go red\n     %s" % out)
    check("DIRECTOR SEAT ITSELF" in out,
          "1c: the finding must name the inspecting seat -- that is the open "
          "circuit iron rule 9 has on itself")
    check("carries NO 判定完结 line" in out,
          "1d: the DECISIONS_NEEDED cross-read must report the empty file")

    # --- 2. an ADMISSION must not reset the counter -------------------------
    adm = ("**成员串 26**(上一行)。本行 **2026-09-17T10:xxZ 的变动:"
           "`arbheart` + `slotwait` 同轮入集**(24 → 26,全文 §DU)。\n")
    write_testset(ts, None, older_stamp="2026-09-14T16:xxZ", head_line=adm)
    rc_adm, out_adm = run(ts, rp, dn)
    check(rc_adm == 3,
          "2a: an admission line moves the member string but closes NO verdict "
          "-- it must NOT reset the stall (got exit %d)" % rc_adm)
    check("2026-09-14T16:xxZ" in out_adm,
          "2b: the anchor must walk back to the newest line that really closed "
          "a verdict\n     %s" % out_adm)
    zero = HEAD % ("2026-09-17T10:xxZ", "0")
    write_testset(ts, None, older_stamp="2026-09-14T16:xxZ", head_line=zero)
    rc_zero, _ = run(ts, rp, dn)
    check(rc_zero == 3, "2c: `判定完结 0` is not a closure (got exit %d)" % rc_zero)

    # --- 3. report names are the denominator, never the satisfier -----------
    write_testset(ts, "2026-09-14T16:xxZ")
    write_reports(rp, rounds(40))
    rc_more, out_more = run(ts, rp, dn)
    check(rc_more == 3 and "STALL         : 40" in out_more,
          "3a: filing 17 MORE reports must make the number bigger, never "
          "greener (got exit %d)" % rc_more)
    check("DENOMINATOR ONLY" in out_more,
          "3b: the output must say so where a reader will see it")

    # --- 4. an empty or unreadable corpus is NOT zero -----------------------
    write_reports(rp, [])
    rc_empty, out_empty = run(ts, rp, dn)
    check(rc_empty == 2,
          "4a: an empty report corpus must be UNCERTIFIABLE, not a 0-round "
          "stall (got exit %d)" % rc_empty)
    check("UNCERTIFIABLE" in out_empty and "not a pass" in out_empty.lower(),
          "4b: and it must not read like a pass")
    rc_gone, _ = run(ts, os.path.join(root, "no-such-file.txt"), dn)
    check(rc_gone == 2, "4c: an unreadable corpus is exit 2 (got %d)" % rc_gone)

    # --- 5. no qualifying history line ---------------------------------------
    write_reports(rp, rounds(23))
    with open(ts, "w", encoding="utf-8") as fh:
        fh.write("# 当前测试集\na,b,c\n成员串 24,没有任何变动戳。\n")
    rc_noanchor, out_noanchor = run(ts, rp, dn)
    check(rc_noanchor == 2,
          "5a: no `<stamp> 的变动` + `判定完结` line anywhere is exit 2 "
          "(got %d)" % rc_noanchor)
    check("UNCERTIFIABLE" in out_noanchor, "5b: and it says so")

    # --- 6. fuzzy stamps resolve to the EARLIEST instant (the loud side) ----
    write_testset(ts, "2026-09-17T2x:xxZ")
    write_reports(rp, ["20260917T210000Z", "20260917T220000Z"])
    rc_fuzz, out_fuzz = run(ts, rp, dn)
    check("2026-09-17T20:00:00Z" in out_fuzz,
          "6a: `2x:xx` must resolve to 20:00:00Z -- earliest, i.e. the reading "
          "that can only OVER-count\n     %s" % out_fuzz)
    check("STALL         : 2" in out_fuzz,
          "6b: both 21:00Z and 22:00Z are then after the anchor")
    check(rc_fuzz == 0, "6c: two rounds is still green (got %d)" % rc_fuzz)

    # --- 7. the thresholds bite where iron rule 9 says ----------------------
    write_testset(ts, "2026-09-14T16:xxZ")
    write_reports(rp, rounds(11))
    rc11, _ = run(ts, rp, dn)
    write_reports(rp, rounds(12))
    rc12, out12 = run(ts, rp, dn)
    write_reports(rp, rounds(24))
    rc24, out24 = run(ts, rp, dn)
    check(rc11 == 0, "7a: 11 rounds is below iron rule 9's门槛 (got %d)" % rc11)
    check(rc12 == 3 and "点名" in out12,
          "7b: the 12th round is the 点名 escalation (got %d)" % rc12)
    check(rc24 == 3 and "DECISIONS_NEEDED" in out24.split("FINDING")[-1],
          "7c: the 24th escalates to DECISIONS_NEEDED (got %d)" % rc24)

    # --- 8. the real repo, read as the 开工自检 leg reads it -----------------
    p = subprocess.run([sys.executable, SUBJECT], capture_output=True,
                       text=True, timeout=120, cwd=REPO)
    real = p.stdout + p.stderr
    check(p.returncode in (0, 3),
          "8a: on the real repo the leg must COMPUTE a number, not fall back "
          "to UNCERTIFIABLE (got %d)\n     %s" % (p.returncode, real))
    check("STALL         :" in real, "8b: and print the stall line")

    # --- 9. it stays cheap and executes nothing -----------------------------
    bindir = tempfile.mkdtemp(prefix="verdict_closure_bin_")
    trip = os.path.join(bindir, "TRIPPED")
    for name in ("lua5.1", "luacheck"):
        pth = os.path.join(bindir, name)
        with open(pth, "w") as fh:
            fh.write("#!/bin/sh\ntouch %s\nexit 0\n" % trip)
        os.chmod(pth, 0o755)
    env = dict(os.environ)
    env["PATH"] = bindir + os.pathsep + env.get("PATH", "")
    t0 = time.time()
    subprocess.run([sys.executable, SUBJECT], capture_output=True, text=True,
                   timeout=120, env=env, cwd=REPO)
    elapsed = time.time() - t0
    check(not os.path.exists(trip),
          "9a: the leg must execute no test/linter -- it is text + set "
          "arithmetic, and the design rests on nobody skipping it")
    check(elapsed < 10.0, "9b: a full run costs well under 10s (%.2fs)" % elapsed)
    print("  NOTE  subject cost on this container: %.2fs" % elapsed)
    shutil.rmtree(bindir, ignore_errors=True)
finally:
    shutil.rmtree(root, ignore_errors=True)

print("\n%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)
