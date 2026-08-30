#!/usr/bin/env python3
"""Every wave record must carry a key for each gate the wave had to pass.

Director ruling on GH #332 (c), 2026-08-30.

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

Scope: waves from W28 on.  Earlier records are left alone on purpose -- they
were written before the key existed, and back-dating a requirement onto them
would open a permanent red account for waves nobody can re-fly.  That is the
`pending_rulings.py` (甲) precedent: a check that is red from birth for
historical reasons is a check people stop reading.
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

# gates key -> the gate it stands for.  A wave record must have a key whose
# name contains the substring; the surrounding ordinal (i_, ii_, iv_...) is the
# desk's own convention and is not pinned here.
REQUIRED_GATES = {
    "reclaim_blind": "GH #271 reclaim-blind check (tools/batch_test/soak/reclaim_blind.py)",
}

CHECKS = []


def check(cond, label):
    CHECKS.append((bool(cond), label))
    return bool(cond)


def wave_number(filename):
    """W28_wave.json -> 28.  Returns None for pooled/other records."""
    match = re.match(r"^W(\d+)_wave\.json$", filename)
    return int(match.group(1)) if match else None


def main():
    if not os.path.isdir(WAVES):
        print("FAIL  the waves directory does not exist: %s" % WAVES)
        return 1

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

        for needle, description in sorted(REQUIRED_GATES.items()):
            hits = [k for k in gates if needle in k]
            check(hits, "W%d records the %s under a `gates` key containing %r"
                        % (number, description, needle))
            for key in hits:
                value = gates[key]
                # Only structural: a key present with an empty value is the
                # same absence wearing the key's name.
                check(isinstance(value, str) and value.strip(),
                      "W%d's `%s` is a non-empty string (a blank value is the "
                      "absence this file exists to catch, wearing the key)"
                      % (number, key))

    failed = [label for ok, label in CHECKS if not ok]
    for ok, label in CHECKS:
        print("%s  %s" % ("PASS" if ok else "FAIL", label))
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
