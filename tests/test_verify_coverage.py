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


RAN = []


def chk(name, cond, detail=""):
    print("      %-4s %s%s" % ("ok" if cond else "FAIL", name,
                               "" if cond else "  -- " + detail))
    RAN.append(name)
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

        # ------------------------------------------------------------------
        # CITATIONS ARE NOT VERDICTS (2026-09-18, director; filed by the replay
        # desk 15:42Z).  A report that QUOTES another document's VERIFY line
        # was scoring it as a fresh verdict for the quoting round.  Ten of 191
        # matches on the live corpus were quotations, and the classes are not
        # equal: seven only dragged `last_report` forward (up to 6 days), one
        # INVERTED a verdict (a 09-17 quote of a 09-11 INDETERMINATE buried the
        # real 09-15 WORKING), and one INVENTED one -- `ownhalf` read WORKING
        # out of a round whose own text says it made zero verdicts, because
        # REVIEWING the owed row that exists to withhold exactly that evidence
        # copies its acceptance sentence into the corpus, once per round.
        #
        # The direction matters more than the count: the two earlier defects in
        # this tool under-counted (manufactured condition-(a) DEBT); this one
        # manufactures SATISFACTION, and condition (a) gates every promote.
        ts3 = os.path.join(d, "test_set3.md")
        with open(ts3, "w") as fh:
            fh.write("# header\nkappa,lambda,mu,nu\n")
        rep5 = os.path.join(d, "reports5")
        os.makedirs(rep5)
        # The real verdict, three days before anyone quotes it.
        with open(os.path.join(rep5, "20260910T000000Z.md"), "w") as fh:
            fh.write("VERIFY id=kappa verdict=INDETERMINATE episodes=900\n")
        # A later round that quotes OTHER verdicts.  Three shapes, all real:
        # an evidence table citing a report path, a pasted `grep` hit, and an
        # owed row's acceptance sentence quoted as a blockquote whose field
        # name sits on the NEIGHBOURING row.
        with open(os.path.join(rep5, "20260913T000000Z.md"), "w") as fh:
            fh.write(
                "| `a_evidence_kappa` | `VERIFY id=kappa verdict=WORKING "
                "episodes=2` | `iterations/reports/replay-check/"
                "20260901T000000Z.md:9` |\n\n"
                "iterations/reports/replay-check/20260910T000000Z.md:1:"
                "VERIFY id=lambda verdict=WORKING episodes=5\n\n"
                "`iterations/owed_executions.json` 的 `mu_bar` 行,"
                "`done_when_note` 逐字:\n\n"
                "> **裸读得出的验收句**:某一轮报告打出\n"
                "> `VERIFY id=mu verdict=WORKING`,且 episodes 来自 >=6 局\n")
        rc7, out7 = run(ts3, rep5, ("--all",))
        rows7 = {ln.split()[0]: ln.split() for ln in out7.splitlines()
                 if ln[:1].isalpha() and len(ln.split()) >= 5
                 and ln.split()[1].isdigit()}
        chk("a quoted VERIFY line is not counted",
            rows7.get("kappa", [None, "?"])[1] == "1", str(rows7.get("kappa")))
        # (ii) of the desk's acceptance: not merely uncounted -- it must not
        # become the id's verdict either.  These are separate failures: the
        # `abilanc` instance kept the count honest-looking and still answered
        # the WRONG verdict, which is the reading a promote would act on.
        chk("a quoted VERIFY line does not become last_verdict",
            rows7.get("kappa", [None, None, "?"])[2] == "INDETERMINATE"
            and rows7["kappa"][3] == "900", str(rows7.get("kappa")))
        chk("a quoted line does not drag last_report forward",
            rows7.get("kappa", [None, None, None, None, "?"])[4]
            == "20260910T000000", str(rows7.get("kappa")))
        chk("a pasted grep hit citing a report path is not a verdict",
            rows7.get("lambda", [None, "?"])[1] == "0",
            str(rows7.get("lambda")))
        chk("an owed row's acceptance sentence, quoted, is not a verdict",
            rows7.get("mu", [None, "?"])[1] == "0", str(rows7.get("mu")))
        chk("the tool SAYS how many it did not count",
            "not counted: 3 citation(s)" in out7, out7[:300])
        chk("--show-citations names file, line and id",
            "20260913T000000Z.md:1" in run(ts3, rep5, ("--show-citations",))[1],
            run(ts3, rep5, ("--show-citations",))[1][:400])

        # ANTI-VACUUM FOR THE CITATION RULE, and it is not decoration: the
        # rule keys on the ROW, so the same string with no source named on it
        # MUST still count.  Without this the checks above are satisfied by any
        # mutant that simply stops counting -- i.e. by the very under-count
        # this file's 09-06 fix was written against.
        rep6 = os.path.join(d, "reports6")
        os.makedirs(rep6)
        with open(os.path.join(rep6, "20260913T000000Z.md"), "w") as fh:
            fh.write("VERIFY id=kappa verdict=WORKING episodes=2\n")
        _, out8 = run(ts3, rep6, ("--all",))
        rows8 = {ln.split()[0]: ln.split() for ln in out8.splitlines()
                 if ln[:1].isalpha() and len(ln.split()) >= 5
                 and ln.split()[1].isdigit()}
        chk("anti-vacuum: the same line with no source named IS counted",
            rows8.get("kappa", [None, "?", "?"])[1] == "1"
            and rows8["kappa"][2] == "WORKING", str(rows8.get("kappa")))

        # THE WIDENING IS OWED-MARKER-ONLY, AND THIS PINS THE LIMIT.  A summary
        # head at this desk is a blockquote AND routinely names other reports;
        # if a bare path widened over the block, every verdict stated in a
        # summary head would vanish -- the under-count direction again, this
        # time dressed as a fix.  Measured on the live corpus: 2 of 191 matches
        # sit in a blockquote at all, and both quote an owed row.
        rep7 = os.path.join(d, "reports7")
        os.makedirs(rep7)
        with open(os.path.join(rep7, "20260914T000000Z.md"), "w") as fh:
            fh.write("> **一句话**: picking up where\n"
                     "> `iterations/reports/replay-check/20260910T000000Z.md`\n"
                     "> left off:\n"
                     "> `VERIFY id=nu verdict=WORKING episodes=40`\n")
        _, out9 = run(ts3, rep7, ("--all",))
        rows9 = {ln.split()[0]: ln.split() for ln in out9.splitlines()
                 if ln[:1].isalpha() and len(ln.split()) >= 5
                 and ln.split()[1].isdigit()}
        chk("a verdict in a summary blockquote that cites a report still counts",
            rows9.get("nu", [None, "?"])[1] == "1", str(rows9.get("nu")))

        # OFF-VOCABULARY TOKENS.  `verdict=([A-Z]+)` cut `NOT-ARMED` down to
        # `NOT` and filed it as a verdict -- 12 lines on the live corpus, all
        # of them on ids outside the armed string, so the table never showed
        # it and nothing would have until one of those ids was armed.
        rep8 = os.path.join(d, "reports8")
        os.makedirs(rep8)
        with open(os.path.join(rep8, "20260914T000000Z.md"), "w") as fh:
            fh.write("VERIFY id=kappa verdict=NOT-ARMED episodes=4\n")
        _, out10 = run(ts3, rep8, ("--all", "--show-citations"))
        rows10 = {ln.split()[0]: ln.split() for ln in out10.splitlines()
                  if ln[:1].isalpha() and len(ln.split()) >= 5
                  and ln.split()[1].isdigit()}
        chk("NOT-ARMED is not counted as a verdict",
            rows10.get("kappa", [None, "?"])[1] == "0",
            str(rows10.get("kappa")))
        chk("NOT-ARMED is parsed whole, never truncated to NOT",
            "NOT-ARMED" in out10 and "kappa NOT |" not in out10, out10[:400])
        chk("an off-vocabulary token is reported, not silently dropped",
            "1 off-vocabulary token(s)" in out10, out10[:300])

        # could-not-run must be distinguishable from clean (evidence discipline)
        rc3, _ = run(os.path.join(d, "nope.md"), rep)
        chk("missing arm string exits 2 (could not run), never 0", rc3 == 2,
            "rc=%d" % rc3)
        rc4, _ = run(ts, os.path.join(d, "no_such_dir"))
        chk("missing reports dir exits 2, never 0", rc4 == 2, "rc=%d" % rc4)

    # COUNTED, NOT WRITTEN DOWN.  This line said `17` while 17 checks ran and
    # still said a literal when 31 did -- a number in a report that no command
    # produced.  It now reports what actually executed.
    print("\n%d checks, %d failed" % (len(RAN), len(FAILED)))
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
