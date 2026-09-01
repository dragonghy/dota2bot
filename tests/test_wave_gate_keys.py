#!/usr/bin/env python3
"""Every wave record must carry a key for each gate the wave had to pass.

Director ruling on GH #332 (c), 2026-08-30.
Extended 2026-09-01 from one gate to all four (GH #396); see EXTENSION below.

The filing story is the whole specification.  `reclaim_blind.py` -- the gate
GH #271 put in front of every launch -- was not run before W27 and was not run
before W28.  Nothing noticed, and the reason nothing noticed is worth stating
plainly: `W27_wave.json:gates` was `null` and `W28_wave.json:gates` held the
three throttle keys and no fourth, and BOTH records looked complete.  W28's
record even had a `skip_not_pass_lines` field that enumerated seven flags it
had not used -- an inventory of absences that did not have room for this one.

    A gate that did not run prints nothing, and nothing is what a passing
    gate's absence also looks like.  This is the same shape as #205 (a
    linter nobody could install read as a clean tree), #213 (a push gate
    that could not run read as a push that passed), and the entry the batch
    desk logged the same day: `describe-instances` answering `[]` with exit
    0 for an instance that no longer exists, where the empty list is
    indistinguishable from the good news "zero preemptions".

So the key is REQUIRED, and an absent key is a FINDING, not a pass.  What the
key SAYS is deliberately not constrained: this file refuses to grade prose.  It
asserts the record has a place where the answer must go, which is exactly the
property whose absence let two waves fly ungated.

EXTENSION (2026-09-01, GH #396) -- one needle guarded four gates' worth of
record, and the other three were free to be renamed away.

W35 renamed all three ordinal gate keys into prose sentences
(`i_throttle_6h` -> `(i) >=6h since last routine wave`, and so on) and dropped
`iv_inputs` entirely.  Exactly one check raised its hand: the `reclaim_blind`
one, because it was the only gate pinned by name.  Three gates were renamed
and a fourth vanished, in silence, in the same commit.

    A check that judges by name translates a rename into "the check does
    not exist" -- and reports that as a pass.  Same family as the
    self-check's own `UNKNOWN STATUS (vocabulary drift)` (GH #317).

The remedy is not one more literal.  The desk's vocabulary has genuinely
drifted twice inside the enforced range and BOTH dialects were legitimate
bookkeeping:

    gate (i)    W28-W30 `i_six_hour`    W31-W34 `i_throttle_6h`
                W35     `(i) >=6h since last routine wave`
    gate (iii)  W28-W30 `iii_cost`      W31-W34 `iii_budget`
                W35     `(iii) MTD + estimate <= $80`

So each gate carries an ALIAS SET, matched against the key name after
normalisation (lowercase, every run of non-alphanumerics -> `_`; that single
step is what lets `(ii) something new to test` and `ii_new_to_test` hit the
same needle).  A *new* dialect still goes red -- deliberately: the alias set is
where a rename gets acknowledged, one line, on purpose, instead of silently.

Scope: waves from W28 on, and each gate from the first wave whose records
actually carried it (`first_wave` below).  Earlier records are left alone on
purpose -- they were written before the key existed, and back-dating a
requirement onto them would open a permanent red account for waves nobody can
re-fly.  That is the `pending_rulings.py` (甲) precedent: a check that is red
from birth for historical reasons is a check people stop reading.  Note what
`first_wave` does and does not say: it is a statement about when the DESK
started recording the gate, never a finding that the gate did not apply.

LIMITS (quote these when citing this file):
  - It grades the PRESENCE and NON-EMPTINESS of a key, never the answer.
    W33/W34/W35 all record `reclaim_blind` values that say in as many words
    "UNCERTIFIABLE -- NOT A PASS", and this file calls all three PASS,
    correctly and uselessly.  "The gate was recorded" and "the gate was
    passed" are two different readings and only the first is bought here.
  - It cannot see a gate the desk never wrote down under any name in any
    wave: the required list is maintained by hand from the batch-desk
    charter's own four-gate list, not derived from anything.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
WAVES = os.path.join(ROOT, "iterations", "reports", "batch-desk", "waves")

# The wave this requirement starts at.  See the scope note in the docstring.
FIRST_ENFORCED_WAVE = 28

# The four launch gates, as the batch-desk charter states them:
#   (i) >=6h since the last routine wave, (ii) something new to test,
#   (iii) MTD + estimate under the fence, (iv) inputs -- which is a compound:
#   no harvest owed AND the GH #271 reclaim-blind check.
# Each entry: a key must exist whose NORMALISED name contains at least one
# alias.  The surrounding ordinal (i_, ii_, iv_, `(iii)`) is the desk's own
# convention and is deliberately not pinned.
REQUIRED_GATES = [
    {
        "id": "i_throttle",
        "description": "gate (i), >=6h since the last routine wave",
        "aliases": ("throttle", "six_hour", "6h"),
        "first_wave": 28,
    },
    {
        "id": "ii_new_to_test",
        "description": "gate (ii), something new to test",
        "aliases": ("new_to_test", "new_to_be_tested"),
        "first_wave": 28,
    },
    {
        "id": "iii_budget",
        "description": "gate (iii), MTD + estimate under the fence",
        "aliases": ("budget", "cost", "mtd", "fence"),
        "first_wave": 28,
    },
    {
        "id": "iv_inputs",
        "description": "gate (iv) first half, inputs -- no harvest owed",
        # W28-W30 recorded gate (iv) as the reclaim-blind half only; the
        # inputs half first appears as a key in W31.  See the `first_wave`
        # note in the docstring: this is about the record, not the gate.
        "aliases": ("inputs", "harvest"),
        "first_wave": 31,
    },
    {
        "id": "iv_reclaim_blind",
        "description": ("gate (iv) second half, GH #271 reclaim-blind check "
                        "(tools/batch_test/soak/reclaim_blind.py)"),
        "aliases": ("reclaim_blind",),
        "first_wave": 28,
    },
]

CHECKS = []


def check(cond, label):
    CHECKS.append((bool(cond), label))
    return bool(cond)


def normalize_key(key):
    """`(ii) something new to test` -> `_ii__something_new_to_test`.

    One step, and it is the step that makes an alias survive the ordinal
    convention changing shape.  Runs of non-alphanumerics collapse to a
    single `_` so that `(iii) MTD + estimate` and `iii_mtd_estimate` agree.
    """
    return re.sub(r"[^a-z0-9]+", "_", key.lower())


def wave_number(filename):
    """W28_wave.json -> 28.  Returns None for pooled/other records."""
    match = re.match(r"^W(\d+)_wave\.json$", filename)
    return int(match.group(1)) if match else None


def grade_gates(number, gates, record):
    """Run every in-scope required gate against one record's `gates` dict.

    Pure, so the synthetic stand below drives the same code the real corpus
    does -- a stand that exercised a copy of this logic would be asserting
    something about the copy.
    """
    for gate in REQUIRED_GATES:
        if number < gate["first_wave"]:
            continue
        hits = [k for k in gates if any(a in normalize_key(k)
                                        for a in gate["aliases"])]
        if not check(hits, "%s records %s under a `gates` key matching one of "
                            "%r" % (record, gate["description"],
                                    list(gate["aliases"]))):
            continue
        for key in hits:
            value = gates[key]
            # Only structural: a key present with an empty value is the
            # same absence wearing the key's name.
            check(isinstance(value, str) and value.strip(),
                  "%s's `%s` is a non-empty string (a blank value is the "
                  "absence this file exists to catch, wearing the key)"
                  % (record, key))


def synthetic_stand():
    """Prove every needle is load-bearing, on inputs the corpus cannot supply.

    Evidence discipline rule 2: a needle that is never the reason a check
    fails is indistinguishable from a needle that is not there.  On the real
    corpus every gate is present in almost every record, so the real corpus
    cannot tell a working alias set from a vacuous one.  These synthetics
    can, and they run on every invocation rather than by hand.
    """
    dialects = {
        "W28-W30": {
            "i_six_hour": "PASS", "ii_new_to_test": "PASS",
            "iii_cost": "PASS", "iv_reclaim_blind": "PASS",
        },
        "W31-W34": {
            "i_throttle_6h": "PASS", "ii_new_to_test": "PASS",
            "iii_budget": "PASS", "iv_inputs": "PASS",
            "iv_reclaim_blind": "PASS",
        },
        "W35 prose": {
            "(i) >=6h since last routine wave": "SATISFIED",
            "(ii) something new to test": "SATISFIED",
            "(iii) MTD + estimate <= $80": "SATISFIED",
            "(iv) inputs: no harvest owed": "SATISFIED",
            "reclaim_blind": "SATISFIED",
        },
    }

    # (a) Every recorded dialect passes.  Without this the alias sets could
    # drift into pinning one vocabulary and calling the others a finding --
    # which is the very failure being fixed, pointed the other way.
    for name, gates in dialects.items():
        before = len(CHECKS)
        # W31 is >= every first_wave, so all five gates are in scope; the
        # W28-W30 dialect is graded at 28, where iv_inputs is not required.
        number = 28 if name == "W28-W30" else 31
        grade_gates(number, gates, "SYNTH[%s]" % name)
        failed = [lab for ok, lab in CHECKS[before:] if not ok]
        del CHECKS[before:]
        check(not failed, "synthetic: the %s dialect satisfies every in-scope "
                          "gate (else the alias set pins one vocabulary): %r"
                          % (name, failed))

    # (b) Drop one gate at a time from a complete record: exactly that gate
    # must be the one to object.  This is the check that each needle is the
    # reason something fails, one needle at a time.
    complete = dict(dialects["W31-W34"])
    for gate in REQUIRED_GATES:
        gates = {k: v for k, v in complete.items()
                 if not any(a in normalize_key(k) for a in gate["aliases"])}
        check(len(gates) < len(complete),
              "synthetic: the %s alias set matches something in the complete "
              "record (a needle that matches nothing can never fail)"
              % gate["id"])
        before = len(CHECKS)
        grade_gates(31, gates, "SYNTH[drop %s]" % gate["id"])
        failed = [lab for ok, lab in CHECKS[before:] if not ok]
        del CHECKS[before:]
        check(len(failed) == 1 and gate["description"] in failed[0],
              "synthetic: dropping %s is caught, and by its own check alone "
              "(got %d objection(s): %r)"
              % (gate["id"], len(failed), failed))

    # (c) An unknown dialect is a finding, not a pass.  This is the property
    # W35 needed and did not have: a rename must cost somebody one line in
    # REQUIRED_GATES rather than passing in silence.
    renamed = {k: v for k, v in complete.items() if "throttle" not in k}
    renamed["i_cadence_window"] = "PASS"
    before = len(CHECKS)
    grade_gates(31, renamed, "SYNTH[unknown dialect]")
    failed = [lab for ok, lab in CHECKS[before:] if not ok]
    del CHECKS[before:]
    check(len(failed) == 1,
          "synthetic: a gate renamed to a dialect no alias covers is a "
          "FINDING (got %d objection(s))" % len(failed))

    # (d) A key present with a blank value is the absence wearing the key.
    blanked = dict(complete)
    blanked["iv_reclaim_blind"] = "   "
    before = len(CHECKS)
    grade_gates(31, blanked, "SYNTH[blank value]")
    failed = [lab for ok, lab in CHECKS[before:] if not ok]
    del CHECKS[before:]
    check(len(failed) == 1 and "non-empty" in failed[0],
          "synthetic: a blank gate value is caught by the non-emptiness "
          "check (got %r)" % failed)

    # (e) first_wave really scopes: at W28 the inputs half is not required,
    # at W31 it is.  Asserted both ways so the scoping cannot quietly become
    # "never required" (which would retire the gate by accident).
    no_inputs = {k: v for k, v in complete.items() if "inputs" not in k}
    for number, want_failure in ((28, False), (31, True)):
        before = len(CHECKS)
        grade_gates(number, no_inputs, "SYNTH[no inputs @W%d]" % number)
        failed = [lab for ok, lab in CHECKS[before:] if not ok]
        del CHECKS[before:]
        check(bool(failed) == want_failure,
              "synthetic: a record without the inputs half is %s at W%d"
              % ("a FINDING" if want_failure else "in scope-free silence",
                 number))


def main():
    if not os.path.isdir(WAVES):
        print("FAIL  the waves directory does not exist: %s" % WAVES)
        return 1

    synthetic_stand()

    records = []
    for name in sorted(os.listdir(WAVES)):
        number = wave_number(name)
        if number is not None:
            records.append((number, name))

    check(records, "0a there is at least one wave record to check "
                   "(an empty directory is not a pass)")
    enforced = [(n, f) for n, f in records if n >= FIRST_ENFORCED_WAVE]
    check(enforced, "0b at least one record falls in the enforced range "
                    "(W%d+) -- otherwise this file is asserting nothing"
                    % FIRST_ENFORCED_WAVE)

    # Every gate must be in scope for at least one real record, or its entry
    # is decoration: `first_wave` above the newest wave asserts nothing while
    # looking like a requirement.
    newest = max([n for n, _ in enforced], default=0)
    for gate in REQUIRED_GATES:
        check(gate["first_wave"] <= newest,
              "0c the %s entry is in scope for at least one real record "
              "(first_wave=%d, newest wave=W%d)"
              % (gate["id"], gate["first_wave"], newest))

    for number, name in enforced:
        path = os.path.join(WAVES, name)
        try:
            with open(path) as handle:
                wave = json.load(handle)
        except (OSError, ValueError) as exc:
            check(False, "W%d %s: unreadable (%s)" % (number, name, exc))
            continue

        gates = wave.get("gates")
        if not check(isinstance(gates, dict),
                     "W%d has a `gates` object (null/absent is 'not run', "
                     "never a pass)" % number):
            continue

        grade_gates(number, gates, "W%d" % number)

    failed = [label for ok, label in CHECKS if not ok]
    for ok, label in CHECKS:
        print("%s  %s" % ("PASS" if ok else "FAIL", label))
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    if failed:
        # A red here is a bookkeeping debt on a wave record, never a bug in
        # bots/ or game/ -- say so, because four other streams read this
        # output every 2h and the cheapest red is the one nobody has to
        # re-diagnose.
        print("\nWHAT A RED HERE MEANS: a wave record is missing a gate key, "
              "or carries one under a name no alias covers.\n"
              "  Owner: the batch desk (it is the only seat that knows "
              "whether the gate ran).\n"
              "  Fix:   add the key to the record with an honest value -- "
              "`UNCERTIFIABLE` if it did not run.\n"
              "         Do NOT invent a value to turn this green; that is "
              "the exact failure this file was written against.\n"
              "  If instead the desk renamed a gate on purpose, the fix is "
              "one alias in REQUIRED_GATES above,\n"
              "         which is the acknowledgement a silent rename skips.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
