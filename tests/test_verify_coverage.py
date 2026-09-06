#!/usr/bin/env python3
"""Ratchet for tools/agent/verify_coverage.py -- the condition-(a) counter.

The value of this census is entirely in what it REFUSES to conflate: a
machine-readable VERIFY line (countable, what the ledger asks for) versus a
verdict word sitting near an id in prose (weak, generous, not evidence).  If
those two columns ever merge, the tool starts reporting coverage that was never
bought, which is worse than the `未单独计` it replaced.  So the checks below
pin the SEPARATION, not just the parsing.

Run: python3 tests/test_verify_coverage.py     (exit 0 clean / 1 failed)
"""
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools/agent/verify_coverage.py")

FAILED = []


def chk(name, cond, detail=""):
    print("      %-4s %s%s" % ("ok" if cond else "FAIL", name,
                               "" if cond else "  -- " + detail))
    if not cond:
        FAILED.append(name)


def run(test_set, reports, extra=()):
    p = subprocess.run(
        [sys.executable, TOOL, "--test-set", test_set, "--reports", reports,
         *extra],
        capture_output=True, text=True)
    return p.returncode, p.stdout


def main():
    with tempfile.TemporaryDirectory() as d:
        ts = os.path.join(d, "test_set.md")
        with open(ts, "w") as fh:
            fh.write("# header\nalpha,beta,gamma,delta\n")
        rep = os.path.join(d, "reports")
        os.makedirs(rep)
        # alpha: a real VERIFY line.  beta: prose verdict only.  gamma: named
        # but with no verdict anywhere near it.  delta: never mentioned at all.
        with open(os.path.join(rep, "20260901T000000Z.md"), "w") as fh:
            fh.write("VERIFY id=alpha verdict=WORKING episodes=7\n\n"
                     "beta looked fine to me, call it WORKING for now.\n\n"
                     "gamma appears here with no judgement of any kind.\n")
        rc, out = run(ts, rep, ("--all",))

        chk("exit 0 when it ran", rc == 0, "rc=%d" % rc)
        chk("counts the armed set off line 2", "armed ids: 4" in out, out[:200])
        chk("counts only machine-readable VERIFY lines",
            "ids with >=1 machine-readable VERIFY line: 1" in out, out[:300])

        rows = {ln.split()[0]: ln.split() for ln in out.splitlines()
                if ln[:1].isalpha() and len(ln.split()) >= 5
                and ln.split()[1].isdigit()}
        chk("alpha carries its verdict and count",
            rows.get("alpha", [None, None, None])[1] == "1"
            and rows["alpha"][2] == "WORKING", str(rows.get("alpha")))
        # THE SEPARATION, which is the whole point of the tool:
        chk("beta: prose verdict does NOT become a VERIFY count",
            rows.get("beta", [None, "?"])[1] == "0", str(rows.get("beta")))
        chk("beta: prose verdict IS visible in the narrat column",
            rows.get("beta", [None, None, None, None, None, "0"])[5] == "1",
            str(rows.get("beta")))
        chk("gamma: mentioned without a verdict scores 0 in BOTH columns",
            rows.get("gamma", [None, "?", None, None, None, "?"])[1] == "0"
            and rows["gamma"][5] == "0", str(rows.get("gamma")))

        blind = out.split("BLIND SPOTS", 1)[1] if "BLIND SPOTS" in out else ""
        chk("blind spots = never-VERIFYed AND never-judged-in-prose",
            "gamma" in blind and "delta" in blind and "beta" not in blind
            and "alpha" not in blind, blind[:200])
        chk("blind-spot count is stated, not just listed",
            "-- 2:" in blind, blind[:120])

        # anti-vacuum: the checks above must be able to FAIL.  A corpus with no
        # VERIFY line at all has to move the counter, or they prove nothing.
        rep2 = os.path.join(d, "reports2")
        os.makedirs(rep2)
        with open(os.path.join(rep2, "20260901T000000Z.md"), "w") as fh:
            fh.write("nothing verified here at all\n")
        rc2, out2 = run(ts, rep2, ("--all",))
        chk("anti-vacuum: empty corpus reads 0 covered, not 1",
            rc2 == 0 and "ids with >=1 machine-readable VERIFY line: 0" in out2,
            out2[:200])

        # ------------------------------------------------------------------
        # MARKUP TOLERANCE (2026-09-06).  The desk writes the step-7 line
        # wrapped in markdown emphasis / a code span, which is how the
        # charter's own examples render.  The original `^VERIFY` anchor
        # dropped 26 of 59 real lines on the live corpus (44.1%) and printed
        # seven ARMED ids as verify=0 that had verdicts -- one of them
        # `roshdist`, recorded BUGGY.  Under-counting here manufactures
        # condition-(a) debt and sends rounds back over finished work, so the
        # wrapped forms are pinned here alongside the separation checks above.
        ts2 = os.path.join(d, "test_set2.md")
        with open(ts2, "w") as fh:
            fh.write("# header\nepsilon,zeta,eta,theta,iota\n")
        rep3 = os.path.join(d, "reports3")
        os.makedirs(rep3)
        with open(os.path.join(rep3, "20260906T000000Z.md"), "w") as fh:
            fh.write(
                "**`VERIFY id=epsilon verdict=WORKING episodes=12`**\n\n"
                "- **`VERIFY id=zeta verdict=BUGGY episodes=77`** (and then\n"
                "  some trailing prose on the same bullet)\n\n"
                "⇒ `VERIFY id=eta verdict=SILENT episodes=0`。\n\n"
                "| desk | give one `VERIFY id=… verdict=…` line |\n"
                # A meta sentence that names a REAL armed id in the template
                # position with an ELLIPSIS verdict.  This is the case that
                # separates "loose enough to see markup" from "loose enough to
                # invent verdicts": a pattern with `verdict=(\\S+)` scores a
                # verdict for `theta` here, `verdict=([A-Z]+)` cannot.  The
                # earlier ellipsis-id row does NOT test this -- its id is `…`,
                # which matches no armed id, so the assertion passed under a
                # mutant and proved nothing (mutation stand M3, 2026-09-06).
                "next round write `VERIFY id=theta verdict=…` on its own line.\n"
                "theta is otherwise named here with no verdict token.\n")
        rc5, out5 = run(ts2, rep3, ("--all",))
        rows5 = {ln.split()[0]: ln.split() for ln in out5.splitlines()
                 if ln[:1].isalpha() and len(ln.split()) >= 5
                 and ln.split()[1].isdigit()}
        chk("bold+code-span wrapped VERIFY line is counted",
            rows5.get("epsilon", [None, "0"])[1] == "1", str(rows5.get("epsilon")))
        chk("bullet-wrapped line keeps its verdict, not the markup",
            rows5.get("zeta", [None, None, "?"])[2] == "BUGGY",
            str(rows5.get("zeta")))
        chk("episodes stops at the digits, never swallows trailing markup",
            rows5.get("zeta", [None, None, None, "?"])[3] == "77",
            str(rows5.get("zeta")))
        chk("mid-sentence code span after a CJK arrow is counted",
            rows5.get("eta", [None, "0"])[1] == "1", str(rows5.get("eta")))
        # THE SEPARATION STILL HOLDS: dropping the `^` anchor must not let a
        # sentence that merely DESCRIBES the convention score as a verdict.
        # `iota` is armed and appears only inside that table row's ellipsis
        # form, so a regex that stopped requiring a literal id + CAPS verdict
        # would light it up here.
        chk("a row describing the format is not a verdict for any id",
            rows5.get("iota", [None, "?"])[1] == "0"
            and rows5.get("theta", [None, "?"])[1] == "0",
            "iota=%s theta=%s" % (rows5.get("iota"), rows5.get("theta")))
        chk("wrapped corpus moves the headline count to 3",
            "ids with >=1 machine-readable VERIFY line: 3" in out5, out5[:300])

        # DEDUP: this desk states one verdict twice per report (summary head +
        # body).  That is one verdict; counting it twice inflates the ledger.
        rep4 = os.path.join(d, "reports4")
        os.makedirs(rep4)
        with open(os.path.join(rep4, "20260906T010000Z.md"), "w") as fh:
            fh.write("`VERIFY id=epsilon verdict=WORKING episodes=12`\n\n"
                     "body argues it, then restates:\n"
                     "**`VERIFY id=epsilon verdict=WORKING episodes=12`**\n")
        _, out6 = run(ts2, rep4, ("--all",))
        rows6 = {ln.split()[0]: ln.split() for ln in out6.splitlines()
                 if ln[:1].isalpha() and len(ln.split()) >= 5
                 and ln.split()[1].isdigit()}
        chk("the same verdict restated in one report counts once",
            rows6.get("epsilon", [None, "?"])[1] == "1",
            str(rows6.get("epsilon")))

        # could-not-run must be distinguishable from clean (evidence discipline)
        rc3, _ = run(os.path.join(d, "nope.md"), rep)
        chk("missing arm string exits 2 (could not run), never 0", rc3 == 2,
            "rc=%d" % rc3)
        rc4, _ = run(ts, os.path.join(d, "no_such_dir"))
        chk("missing reports dir exits 2, never 0", rc4 == 2, "rc=%d" % rc4)

    print("\n%d checks, %d failed" % (17, len(FAILED)))
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
