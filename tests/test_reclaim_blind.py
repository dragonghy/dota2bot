#!/usr/bin/env python3
"""Acceptance for tools/batch_test/soak/reclaim_blind.py (director ruling, GH #271).

The thing under test is a CLASSIFIER, so the load-bearing acceptance is that it
reproduces the seven waves that were actually flown -- not that it prints a
verdict.  Several wrong implementations print perfectly good verdicts:

  * "escalate when >= 2 machines were reclaimed" passes W17/W17-R/W19-R/W20/W21
    and fires on W18, a wave that delivered half its seeds.  Test 3 is that wave.
  * "escalate whenever the wave yielded <= 1 paired seed" passes every wave in
    the corpus and then aims a 3x-more-expensive instrument at a harness bug the
    instrument cannot fix.  Test 7 is that wave (low yield, zero reclaims).
  * "trust the 40-minute constant forever" answers confidently on data that has
    already contradicted it.  Tests 9 and 10 are the two directions it can drift.

Data provenance -- read before changing a number here:

  W21, W20      per-machine survival / legs / arm_depth published by the batch
                desk in GH #271 comments (2026-08-28).  Verbatim.
  W19-R         per-machine survival published (SIR dump in the issue body), and
                per-seed ab/ba published -- but the seed<->survival MAPPING was
                not.  The pairing used below is arbitrary; the verdict is
                invariant to it (all three are reclaimed, unpaired, sub-flip),
                which is why using it is honest and why this note exists.
  W17, W17-R,   only aggregates were published (machines, usable seeds, cost).
  W18, W19      The rows below are RECONSTRUCTED from the published outcome:
                a machine recorded as reclaimed-and-unusable is written as
                reclaimed + sub-flip + ba=0, a machine recorded as usable is
                written as self-terminated + past-flip + both legs.  These rows
                test the DECISION RULE against the published verdict; they are
                not timing evidence and must not be cited as such.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SOAK = os.path.join(ROOT, "tools", "batch_test", "soak")
TOOL = os.path.join(SOAK, "reclaim_blind.py")
sys.path.insert(0, SOAK)

import reclaim_blind as rb          # noqa: E402

CHECKS = []


def check(cond, label):
    CHECKS.append((bool(cond), label))
    return bool(cond)


def m(seed, survival, code, ab, ba, depth=None):
    row = {"seed": seed, "survival_min": survival, "status_code": code,
           "ab": ab, "ba": ba}
    if depth is not None:
        row["arm_depth"] = depth
    return row


SELF = rb.SELF_TERMINATED
GONE = rb.RECLAIMED

# --- the seven flown waves -------------------------------------------------
W21 = {"wave": "W21", "machines": [
    {"seed": 983, "status_code": SELF, "create": "2026-08-28T12:16:36Z",
     "update": "2026-08-28T13:01:33Z", "ab": 28, "ba": 14, "arm_depth": 18.67},
    {"seed": 986, "status_code": SELF, "create": "2026-08-28T12:16:40Z",
     "update": "2026-08-28T13:10:34Z", "ab": 39, "ba": 19, "arm_depth": 25.55},
    {"seed": 995, "status_code": SELF, "create": "2026-08-28T12:16:44Z",
     "update": "2026-08-28T12:59:17Z", "ab": 30, "ba": 12, "arm_depth": 17.14},
    {"seed": 1138, "status_code": SELF, "create": "2026-08-28T12:16:48Z",
     "update": "2026-08-28T13:01:50Z", "ab": 29, "ba": 14, "arm_depth": 18.88},
]}

W20 = {"wave": "W20", "machines": [
    m(947, 54.1, SELF, 35, 19, 24.63),
    m(959, 30.8, GONE, 26, 0, 0.0),
    m(971, 54.7, SELF, 32, 14, 19.48),
    m(974, 61.8, SELF, 32, 22, 26.07),
]}

W19R = {"wave": "W19-R", "machines": [
    m(928, 16.8, GONE, 26, 0, 0.0),
    m(930, 34.8, GONE, 10, 0, 0.0),
    m(932, 34.7, GONE, 26, 0, 0.0),
]}

W19 = {"wave": "W19", "machines": [
    m(901, 20.0, GONE, 24, 0), m(902, 22.0, GONE, 18, 0),
    m(903, 25.0, GONE, 21, 0), m(904, 55.0, SELF, 30, 16),
]}

W18 = {"wave": "W18", "machines": [
    m(881, 28.0, GONE, 22, 0), m(882, 31.0, GONE, 19, 0),
    m(883, 53.0, SELF, 31, 15), m(884, 56.0, SELF, 30, 17),
]}

W17 = {"wave": "W17", "machines": [m(861 + i, 12.0 + i, GONE, 8, 0) for i in range(4)]}
W17R = {"wave": "W17-R", "machines": [m(871 + i, 15.0 + i, GONE, 9, 0) for i in range(4)]}


def run_cli(wave, extra=()):
    proc = subprocess.run(
        [sys.executable, TOOL, "--wave-json", "-", *extra],
        input=json.dumps(wave), capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def main():
    # --- 1..2: the two healthy waves, and the "not already lit" property -----
    code, lines = rb.evaluate(W21)
    text = "\n".join(lines)
    check(code == 0, "1a W21 (4/4 paired, zero reclaims) -> exit 0")
    check("VERDICT: not blinded" in text, "1b W21 says not blinded")
    check("NEXT WAVE: spot" in text, "1c W21 keeps the next wave on spot")
    check("BLINDED --" not in text, "1d W21 does not print a BLINDED verdict")
    check("4 paired seed(s) of 4 machine(s)" in text, "1e W21 yield line reads 4/4")
    check("34.80 < x <= 40.63" in text, "1f the measured bracket is printed every run")
    check("margin above the constant 0.63 min" in text,
          "1g ... at a precision that still shows the margin (40.6 would not)")

    code, lines = rb.evaluate(W20)
    check(code == 0, "2a W20 (3 paired, 1 reclaim) -> exit 0")
    check("3 paired seed(s)" in "\n".join(lines), "2b W20 yield line reads 3")

    # --- 3: the wave that kills "count the reclaims" ------------------------
    code, lines = rb.evaluate(W18)
    text = "\n".join(lines)
    check(code == 0, "3a W18 (2 reclaims BUT 2 paired) -> exit 0, not an escalation")
    check("2 machine(s) reclaimed before the flip" in text,
          "3b W18 still reports the 2 reclaims (the yield is what vetoes, not blindness)")

    # --- 4..6: the four blinded waves ---------------------------------------
    for wave, label in ((W19R, "4 W19-R"), (W19, "5 W19"),
                        (W17, "6a W17"), (W17R, "6b W17-R")):
        code, lines = rb.evaluate(wave)
        text = "\n".join(lines)
        check(code == 1, "%s -> exit 1 BLINDED" % label)
        check("NEXT WAVE: launch --on-demand (ONE wave)" in text,
              "%s directs one on-demand wave, not a permanent switch" % label)

    # --- 7: the attribution clause (the expensive one to drop) --------------
    dud = {"wave": "hypothetical", "machines": [
        m(1, 55.0, SELF, 30, 0), m(2, 56.0, SELF, 28, 0),
        m(3, 57.0, SELF, 31, 0), m(4, 58.0, SELF, 29, 0)]}
    code, lines = rb.evaluate(dud)
    text = "\n".join(lines)
    check(code == 0, "7a zero yield with ZERO reclaims -> exit 0 (on-demand cannot fix it)")
    check("not capacity" in text, "7b it says why: whatever ate the yield, it was not capacity")
    check("--on-demand" not in text.split("NEXT WAVE")[1],
          "7c it does not direct an on-demand wave")

    # 7d: the one-shot property falls straight out of 7a -- an on-demand wave
    # has no reclaims, so it can never satisfy clause (2) and can never latch.
    ondemand = {"wave": "escalated", "machines": [
        m(1, 50.0, SELF, 30, 2, 1.5), m(2, 51.0, SELF, 28, 1, 0.9),
        m(3, 52.0, SELF, 31, 0), m(4, 53.0, SELF, 29, 0)]}
    check(rb.evaluate(ondemand)[0] == 0,
          "7d an escalated wave hands the next one back to spot (no latch)")

    # --- 8: arm_depth is held to GH #269's floor when it is supplied --------
    # Both reclaims are sub-flip on purpose: a reclaim PAST the flip that came
    # back unpaired is a bracket violation (test 9), not a yield reading, and
    # mixing the two would have this case exercising the wrong branch.
    shallow = {"wave": "shallow", "machines": [
        m(1, 45.0, SELF, 30, 3, 3.0), m(2, 25.0, GONE, 28, 0, 0.0),
        m(3, 47.0, SELF, 31, 2, 2.1), m(4, 20.0, GONE, 29, 0, 0.0)]}
    code, lines = rb.evaluate(shallow)
    text = "\n".join(lines)
    check(code == 1, "8a paired-but-shallow seeds do not count as yield -> BLINDED")
    check("0 paired seed(s)" in text, "8b shallow seeds are reported as zero yield")
    check(rb.evaluate(shallow, min_arm_depth=0.0)[0] == 0,
          "8c --min-arm-depth 0 admits them again (the floor is the knob, not baked in)")
    check("depth-checked" in text and "ab/ba only" in "\n".join(rb.evaluate(W19)[1]),
          "8d each machine line says whether depth was actually checked")

    # --- 9..10: the two directions the changeover constant can drift --------
    late = {"wave": "drift-late", "machines": [
        m(1, 50.0, GONE, 30, 0), m(2, 20.0, GONE, 12, 0),
        m(3, 55.0, SELF, 30, 15), m(4, 56.0, SELF, 31, 16)]}
    code, lines = rb.evaluate(late)
    text = "\n".join(lines)
    check(code == 2, "9a reclaimed PAST the flip yet unpaired -> exit 2, not a verdict")
    check("BRACKET VIOLATED" in text, "9b it names the violation")
    check("VERDICT" not in text, "9c it does not also print a verdict beside the refusal")

    early = {"wave": "drift-early", "machines": [
        m(1, 20.0, SELF, 12, 8), m(2, 45.0, SELF, 30, 15),
        m(3, 46.0, SELF, 31, 16), m(4, 47.0, SELF, 30, 14)]}
    code, lines = rb.evaluate(early)
    check(code == 2, "10a paired BEFORE the flip -> exit 2")
    check("moved earlier" in "\n".join(lines), "10b it names which way the flip moved")

    # --- 11..14: could-not-run is its own answer, and it is not a pass ------
    unknown = {"wave": "u", "machines": [m(1, 30.0, "marked-for-stop", 10, 0)]}
    code, lines = rb.evaluate(unknown)
    check(code == 2, "11a an unknown SIR status_code -> exit 2, never guessed into a bucket")
    check("unknown SIR status_code" in "\n".join(lines), "11b it names the code it could not read")

    noleg = {"wave": "n", "machines": [{"seed": 1, "survival_min": 30.0, "status_code": GONE, "ab": 10}]}
    check(rb.evaluate(noleg)[0] == 2, "12 a missing leg count -> exit 2")

    check(rb.evaluate({"wave": "e", "machines": []})[0] == 2, "13a empty machine list -> exit 2")
    check(rb.evaluate({"wave": "e"})[0] == 2, "13b absent machine list -> exit 2")
    check(rb.evaluate([])[0] == 2, "13c a non-object payload -> exit 2")

    backwards = {"wave": "b", "machines": [
        {"seed": 1, "status_code": SELF, "create": "2026-08-28T13:00:00Z",
         "update": "2026-08-28T12:00:00Z", "ab": 10, "ba": 5}]}
    check(rb.evaluate(backwards)[0] == 2, "14a update before create -> exit 2")
    badts = {"wave": "b", "machines": [
        {"seed": 1, "status_code": SELF, "create": "yesterday",
         "update": "2026-08-28T12:00:00Z", "ab": 10, "ba": 5}]}
    check(rb.evaluate(badts)[0] == 2, "14b an unparseable timestamp -> exit 2")

    # --- 15: no exit-2 path is allowed to look like an escalation -----------
    for wave, label in ((late, "drift-late"), (early, "drift-early"),
                        (unknown, "unknown-code"), (noleg, "missing-leg")):
        text = "\n".join(rb.evaluate(wave)[1])
        # Deliberately not `"BLINDED" not in text`: the refusal is allowed to
        # SAY "this is not a BLINDED".  What must be absent is a directive --
        # a VERDICT line or a NEXT WAVE line beside an answer it did not give.
        check("VERDICT:" not in text and "NEXT WAVE" not in text,
              "15 %s: an undecidable input never directs a wave" % label)

    # --- 16: create/update and survival_min agree ---------------------------
    # 12:16:36Z -> 13:01:33Z is 44m57s = 44.95 min.  The desk published "44.9",
    # which is that number TRUNCATED, so the check is against the arithmetic and
    # not against the rounding in the report -- asserting the printed "44.9"
    # would pin a display convention and call it a measurement.
    derived = rb.survival_minutes(W21["machines"][0], "seed 983")
    check(abs(derived - 44.95) < 0.001,
          "16a survival from create/update = 44.95 min (published 44.9, truncated)")
    check(abs(rb.survival_minutes(m(1, 44.95, SELF, 1, 1), "x") - derived) < 1e-9,
          "16b an explicit survival_min reads the same as the derived one")

    # --- 18: the bracket edges stay tied to the machines they were read off -
    # A bracket edge is a READING.  Asserting the literal 40.63 would only pin
    # a typo-free copy; these pin the arithmetic on the row it came from, so a
    # future edit that moves the edge without a machine behind it fails here.
    W24_1633 = {"seed": 1633, "status_code": SELF,
                "create": "2026-08-29T06:18:41Z", "update": "2026-08-29T06:59:19Z",
                "ab": 27, "ba": 13, "arm_depth": 17.55}
    hi = rb.survival_minutes(W24_1633, "W24 seed 1633")
    check(abs(hi - rb.BRACKET_HI) < 0.005,
          "18a BRACKET_HI is W24 seed 1633's own survival (%.2f min)" % hi)
    _, _, hi_paired, _, _ = rb.classify_machine(W24_1633, 40.0, 8.0, "W24 seed 1633")
    check(hi_paired, "18b ... and that machine is PAIRED -- an unpaired row cannot set the upper edge")
    lo = rb.survival_minutes(m(930, 34.8, GONE, 10, 0, 0.0), "W19-R seed 930")
    check(abs(lo - rb.BRACKET_LO) < 0.005,
          "18c BRACKET_LO is W19-R seed 930's own survival (the longest orphan)")
    check(rb.BRACKET_LO < rb.DEFAULT_CHANGEOVER_MIN <= rb.BRACKET_HI,
          "18d the default constant still sits inside the bracket it is read off of")

    # --- 19..22: survival_bound -- a lower bound is sound in ONE direction --
    def lb(row):
        row = dict(row)
        row["survival_bound"] = "lower"
        return row

    # 19: the unsound direction is skipped, and skipped OUT LOUD.  Same input
    # as test 10 (paired before the flip) with the number relabelled a bound.
    early_lb = {"wave": "W28-shaped", "machines": [
        lb(m(1850, 39.68, SELF, 28, 14, 18.67)), lb(m(1938, 52.63, SELF, 42, 16, 23.17)),
        lb(m(2130, 40.83, SELF, 28, 14, 18.67)), lb(m(2142, 53.43, SELF, 34, 24, 28.0))]}
    code, lines = rb.evaluate(early_lb)
    text = "\n".join(lines)
    check(code == 0, "19a a lower bound below the flip does not fire 'moved earlier' -> exit 0")
    check("BRACKET VIOLATED" not in text, "19b ... and no violation is claimed")
    check("bracket    : SKIPPED" in text and "1850" in text,
          "19c ... but the skip is printed and names the machine")
    check("LOWER BOUND" in text, "19d ... and says why it was skipped")
    check("VERDICT: not blinded" in text and "4 paired seed(s)" in text,
          "19e ... and the verdict the two clauses give is still reached")
    # The same rows called exact are exactly test 10 again: the label is what
    # changed the answer, which is the whole point of having the label.
    exact_same = {"wave": "same-rows-exact",
                  "machines": [dict(x, survival_bound="exact") for x in early_lb["machines"]]}
    check(rb.evaluate(exact_same)[0] == 2,
          "19f the identical rows labelled EXACT still exit 2 -- the bound is load bearing")

    # 20: the sound direction stays armed on a lower bound.
    late_lb = {"wave": "drift-late-lb", "machines": [
        lb(m(1, 50.0, GONE, 30, 0)), lb(m(2, 55.0, SELF, 30, 15)),
        lb(m(3, 56.0, SELF, 31, 16)), lb(m(4, 57.0, SELF, 30, 14))]}
    code, lines = rb.evaluate(late_lb)
    check(code == 2, "20a reclaimed PAST the flip yet unpaired still fires on a lower bound")
    check("BRACKET VIOLATED" in "\n".join(lines), "20b ... and it is a real violation, not a skip")

    # 21: the attribution clause is UNDECIDABLE on a reclaimed lower bound
    # under the flip -- the case where guessing either way flips the verdict.
    # Yield must be <= 1 for the attribution clause to be load bearing: with 3
    # paired seeds the verdict is exit 0 whatever the reclaim is doing, and the
    # test would prove nothing about the clause it claims to be about.
    attr = {"wave": "attr", "machines": [
        lb(m(1, 20.0, GONE, 12, 0, 0.0)), lb(m(2, 22.0, GONE, 14, 0, 0.0)),
        lb(m(3, 25.0, GONE, 11, 0, 0.0)), lb(m(4, 57.0, SELF, 30, 14, 18.8))]}
    code, lines = rb.evaluate(attr)
    text = "\n".join(lines)
    check(code == 2, "21a a reclaimed lower bound under the flip -> exit 2, not a guess")
    check("attribution clause" in text, "21b ... and it names the clause it could not evaluate")
    check("VERDICT:" not in text and "NEXT WAVE" not in text,
          "21c ... and never directs a wave off an answer it did not give")
    # Called exact, the very same wave IS decidable -- and it is a BLINDED one.
    attr_exact = {"wave": "attr-exact",
                  "machines": [dict(x, survival_bound="exact") for x in attr["machines"]]}
    check(rb.evaluate(attr_exact)[0] == 1,
          "21d the same wave with exact readings is a BLINDED (exit 1) -- so exit 2 above "
          "was suppressing a real escalation, not inventing one")

    # 22: an unnameable bound is exit 2, and absence still means exact.
    check(rb.evaluate({"wave": "b", "machines": [
        dict(m(1, 30.0, SELF, 10, 5), survival_bound="approx")]})[0] == 2,
          "22a an unknown survival_bound -> exit 2, never guessed into a bucket")
    check("unknown survival_bound" in "\n".join(rb.evaluate({"wave": "b", "machines": [
        dict(m(1, 30.0, SELF, 10, 5), survival_bound="approx")]})[1]),
          "22b ... and it names the value it could not read")
    check(rb.evaluate(W21)[0] == 0 and rb.survival_bound(W21["machines"][0], "x") == "exact",
          "22c an absent survival_bound means exact -- every pre-existing wave reads unchanged")

    # --- 17: end to end through the CLI ------------------------------------
    code, out = run_cli(W21)
    check(code == 0, "17a CLI on W21 exits 0")
    check("wave W21" in out, "17b CLI names the wave")
    code, out = run_cli(W19R)
    check(code == 1, "17c CLI on W19-R exits 1")
    code, out = run_cli(W21, extra=("--changeover-min", "60"))
    check(code == 2, "17d CLI honours --changeover-min (60 makes W21 self-contradictory)")

    failed = [label for ok, label in CHECKS if not ok]
    for ok, label in CHECKS:
        print("%s  %s" % ("PASS" if ok else "FAIL", label))
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
