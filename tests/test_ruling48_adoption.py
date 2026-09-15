#!/usr/bin/env python3
"""Drive the real `tools/agent/ruling48_adoption.py` over synthetic reports.

Every case runs the actual script as a subprocess against a throwaway report
tree, so a mutation in the script is visible here.  No part of the scanner is
reimplemented in this file -- a second copy of the parser would drift and then
agree with itself (the `append_ledger.py` lesson, batch-desk 2026-09-15T12:15Z).
"""

from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "tools" / "agent" / "ruling48_adoption.py"

CHECKS = 0
FAILED = 0


def check(name: str, got, want) -> None:
    global CHECKS, FAILED
    CHECKS += 1
    if got != want:
        FAILED += 1
        print(f"FAIL {name}: got {got!r}, want {want!r}")
    else:
        print(f"ok   {name}")


def run(reports: dict[str, str], since: str = "20260101T000000Z") -> tuple[int, str]:
    """Write `{'<stream>/<ts>.md': body}` into a temp tree and scan it."""
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td) / "reports"
        for rel, body in reports.items():
            p = root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(body, encoding="utf-8")
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--reports", str(root), "--since", since],
            capture_output=True, text=True,
        )
        return proc.returncode, proc.stdout


def main() -> int:
    # 1. The prescribed form, with a real count, is clean and is summed.
    rc, out = run({"replay-check/20260915T094327Z.md":
                   "**零 EC2 / 零 CE / S3 读取 13 个 `.dem` + 13 个 `.analysis.json`(出网未计价)**\n"})
    check("exact N -> exit 0", rc, 0)
    check("exact N -> itemised numerals are summed", "MULTIPLIABLE N  : 26" in out, True)

    # 2. A round with no cost line at all is a FINDING, never a zero.  This is
    #    the whole subject of RULING 48: silence must not read as "spent nothing".
    rc, out = run({"strategy/20260915T073438Z.md": "本轮只改了 tests/,没有成本那一节。\n"})
    check("missing line -> exit 3", rc, 3)
    check("missing line -> named as NO_LINE", "FINDING NO_LINE" in out, True)

    # 3. The banned third segment. A report may not satisfy the cost question
    #    with `零支出` -- that is the form the ruling exists to outlaw.
    rc, out = run({"replay-check/20260915T101700Z.md":
                   "成本:**零 EC2 / 零 CE / 零支出**(只读 S3)\n"})
    check("banned 零支出 -> exit 3", rc, 3)
    check("banned 零支出 -> named as BANNED", "FINDING BANNED" in out, True)

    # 4. REGRESSION (this bug shipped and was caught before any claim rested on
    #    it): `零 S3 读取` CONTAINS the substring `S3 读取`, so matching the
    #    segment alone classified a prose zero as OK_N and printed
    #    `prose zeros: 0`.  The numeral, not the segment, is the test.
    rc, out = run({"hero/20260915T105533Z.md":
                   "**成本:零 EC2 / 零 CE / 零 S3 读取**(本轮一个对象都没下)\n"})
    check("prose zero -> exit 0 (compliant in substance)", rc, 0)
    check("prose zero -> NOT counted as OK_N", "OK_PROSE_ZERO" in out, True)
    check("prose zero -> tallied as a prose zero", "prose zeros     : 1" in out, True)

    # 5. An approximate N is a finding: the exact count was in the writer's hands.
    rc, out = run({"replay-check/20260915T125314Z.md":
                   "**零 EC2 / 零 CE / S3 读取 104 个 `.dem` + 约 200 个 `.analysis.json`**\n"})
    check("approximate N -> exit 3", rc, 3)
    check("approximate N -> still summed, not discarded", "MULTIPLIABLE N  : 304" in out, True)

    # 6. A report carrying the line twice (summary + cost section) must not have
    #    its declared read shrunk by the weaker copy.
    rc, out = run({"replay-check/20260915T094327Z.md":
                   "摘要:**零 EC2 / 零 CE / 零 S3 读取**\n\n"
                   "## 成本\n**零 EC2 / 零 CE / S3 读取 26 个对象(出网未计价)**\n"})
    check("duplicate lines -> the larger declaration wins", "MULTIPLIABLE N  : 26" in out, True)

    # 7. An empty window is exit 2 -- could not run, which is not a pass.
    rc, out = run({"hero/20260101T000000Z.md": "x\n"}, since="20990101T000000Z")
    check("empty window -> exit 2", rc, 2)
    check("empty window -> says it is not a pass", "NOT a pass" in out, True)

    # 8. The window bounds are honoured (a pre-ruling report is out of scope).
    rc, out = run({"hero/20260915T070000Z.md": "no cost line\n",
                   "hero/20260915T105533Z.md":
                   "**零 EC2 / 零 CE / S3 读取 5 个对象**\n"},
                  since="20260915T071500Z")
    check("pre-window report excluded -> exit 0", rc, 0)
    check("pre-window report excluded -> 1 report scanned", "1 report(s)" in out, True)

    print(f"\n{CHECKS} checks, {FAILED} failed")
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
