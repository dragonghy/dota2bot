#!/usr/bin/env python3
"""Decide whether the wave just harvested was RECLAIM-BLINDED, and therefore
whether the NEXT wave escalates off spot.

Why this exists (director ruling on GH #271, 2026-08-28)
--------------------------------------------------------
The batch desk's degradation ladder (batch-desk.md §5) escalates on
`InsufficientInstanceCapacity`, which is a LAUNCH-TIME error.  The dominant
failure mode for seven waves running was not that: `run-instances` returned
fine, `InstanceLifecycle=spot` checked out, and the machine was then taken
away MID-FLIGHT with `instance-terminated-no-capacity`.  So the ladder's
only path to `--on-demand` was structurally unreachable, and owner GH #158's
"除非没有 spot 的机器" had no observable form.  This file is that form.

The loss is a STEP, not a proportion.  A wave machine runs seed S twice --
first the `ab` leg, then the `ba` leg -- and `mirror_ab.sh` flips legs by
writing one file (`bots/Customize/soak_side.lua`) over SSM after the ab leg
has banked TARGET games.  A machine reclaimed before that flip yields a pure
single-leg orphan whose `arm_depth` is 0.0, no matter how long it lived:

    W19-R  16.8 min -> ab26/ba0  NO-PAIR
    W19-R  34.8 min -> ab10/ba0  NO-PAIR     <- lived 2x as long, bought the same
    W20    30.8 min -> ab26/ba0  NO-PAIR
    W21    42.6 min -> ab30/ba12 paired      <- 8 more minutes, 1 whole seed

What the trigger is, and why it is not "count the reclaims"
-----------------------------------------------------------
A wave is BLINDED iff BOTH:

  (1) it yielded <= 1 paired seed, and
  (2) at least one machine was reclaimed (`instance-terminated-no-capacity`)
      before the changeover point.

Clause (1) is the yield, and clause (2) is the ATTRIBUTION.  Both are load
bearing and each one alone misclassifies the measured history:

    wave    machines  reclaimed  paired   yield<=1?  reclaim?   verdict
    W17        4          4        0        yes        yes      BLINDED
    W17-R      4          4        0        yes        yes      BLINDED
    W18        4          2        2        no         yes      ok
    W19        4          3        1        yes        yes      BLINDED
    W19-R      3          3        0        yes        yes      BLINDED
    W20        4          1        3        no         yes      ok
    W21        4          0        4        no         no       ok

"Count the reclaims >= 2" would have fired on W18, a wave that delivered half
its seeds.  Clause (2) is the more important of the two: without it a wave
that bought nothing for a reason on-demand CANNOT FIX (a harness bug, a bad
seed set, an AMI that will not boot) escalates to a ~3x more expensive
instrument aimed at a problem it does not treat.  Do not drop it to "simplify".

Why <= 1 and not = 0: `mirror_multi.sh`'s own file header says a single seed
is a per-comp reading and not the population mean, so a one-seed wave is not
a wave-level answer either -- it is an orphan with better paperwork.

The changeover constant is BRACKETED, not chosen
------------------------------------------------
Longest orphan observed: 34.8 min (W19-R).  Shortest paired survivor: 42.6
min (W21 seed 995).  Every value in (34.8, 42.6] classifies all 27 machines
observed so far identically; 40 sits inside that bracket.  The number is
therefore a reading, not a preference -- and readings expire.  So this file
re-checks the bracket against its own input on every run: a reclaimed machine
that lived PAST the threshold and still came back unpaired, or a paired seed
from a machine that died BEFORE it, means the flip point has moved.  That is
`BRACKET VIOLATED` and exit 2 -- re-derive the constant -- and not a quiet
answer computed with a number the data just contradicted.  Same stance as
GH #267 test 6: a gauge is not allowed to disagree with itself in silence.

Exit codes (the 0/1/2 vocabulary of GH #171 / #205 / #213)
----------------------------------------------------------
  0  NOT BLINDED   -- next wave launches spot, as always.  GH #158 unchanged.
  1  BLINDED       -- next wave launches `--on-demand`, ONE wave, then reverts.
  2  could-not-run -- missing fields, unknown SIR status codes, or a violated
                      bracket.  Nothing was decided; this is not a pass.

There is no persisted state: the answer is a function of the previous wave's
own harvest, which the desk already computes.  One-shot by construction --
an on-demand wave cannot satisfy clause (2), so it always hands the next wave
back to spot.

Usage
-----
  reclaim_blind.py --wave-json wave.json          # or `-` for stdin
  reclaim_blind.py --wave-json - --changeover-min 40 --min-arm-depth 8

Input JSON:
  {"wave": "W21",
   "machines": [
     {"seed": 983, "status_code": "instance-terminated-by-user",
      "create": "2026-08-28T12:16:36Z", "update": "2026-08-28T13:01:33Z",
      "ab": 28, "ba": 14, "arm_depth": 18.67},
     ...]}

`survival_min` may be given directly instead of create/update.  `arm_depth`
is optional: when present it is held to --min-arm-depth (default 8, matching
GH #269's MIN_ARM_DEPTH), when absent pairing falls back to ab>0 and ba>0 and
the per-machine line says so rather than pretending the depth was checked.
"""
import argparse
import datetime as _dt
import json
import sys

# SIR status codes this file knows how to read.  Anything else is UNKNOWN and
# forces exit 2 rather than being guessed into one of these buckets: guessing
# "probably a self-terminate" is exactly the direction that hides a reclaim.
SELF_TERMINATED = "instance-terminated-by-user"
RECLAIMED = "instance-terminated-no-capacity"
KNOWN_CODES = (SELF_TERMINATED, RECLAIMED)

DEFAULT_CHANGEOVER_MIN = 40.0
DEFAULT_MIN_ARM_DEPTH = 8.0

# The measured bracket the default constant sits inside.  Printed every run so
# the next person can see what would narrow it.
BRACKET_LO = 34.8   # longest orphan observed (W19-R)
BRACKET_HI = 42.6   # shortest paired survivor observed (W21 seed 995)


class Undecidable(Exception):
    """Raised when the input cannot be read.  Maps to exit 2, never to 0."""


def _parse_ts(value, where):
    if not isinstance(value, str):
        raise Undecidable("%s: timestamp is not a string (%r)" % (where, value))
    text = value.strip().replace("Z", "+00:00")
    try:
        return _dt.datetime.fromisoformat(text)
    except ValueError:
        raise Undecidable("%s: unparseable timestamp %r" % (where, value))


def survival_minutes(machine, where):
    """Minutes the machine was alive, from an explicit field or create/update."""
    if "survival_min" in machine:
        try:
            return float(machine["survival_min"])
        except (TypeError, ValueError):
            raise Undecidable("%s: survival_min is not a number" % where)
    if "create" in machine and "update" in machine:
        start = _parse_ts(machine["create"], where)
        end = _parse_ts(machine["update"], where)
        delta = (end - start).total_seconds() / 60.0
        if delta < 0:
            raise Undecidable("%s: update precedes create" % where)
        return delta
    raise Undecidable("%s: needs survival_min, or both create and update" % where)


def classify_machine(machine, changeover_min, min_arm_depth, where):
    """One machine -> (survival, code, paired, depth_checked)."""
    code = machine.get("status_code")
    if code not in KNOWN_CODES:
        raise Undecidable("%s: unknown SIR status_code %r (known: %s)"
                          % (where, code, ", ".join(KNOWN_CODES)))
    survival = survival_minutes(machine, where)

    for field in ("ab", "ba"):
        if field not in machine:
            raise Undecidable("%s: missing leg count %r" % (where, field))
        try:
            int(machine[field])
        except (TypeError, ValueError):
            raise Undecidable("%s: leg count %r is not an integer" % (where, field))
    ab, ba = int(machine["ab"]), int(machine["ba"])

    paired = ab > 0 and ba > 0
    depth_checked = False
    if paired and machine.get("arm_depth") is not None:
        try:
            depth = float(machine["arm_depth"])
        except (TypeError, ValueError):
            raise Undecidable("%s: arm_depth is not a number" % where)
        depth_checked = True
        if depth < min_arm_depth:
            paired = False
    return survival, code, paired, depth_checked


def check_bracket(rows, changeover_min):
    """Both directions the changeover constant can go stale.

    Returns a list of human-readable violations.  Empty list = the constant
    still separates this input the way it separated the seven waves it was
    read off of.
    """
    bad = []
    for row in rows:
        seed, survival, code, paired = row["seed"], row["survival"], row["code"], row["paired"]
        if code == RECLAIMED and survival > changeover_min and not paired:
            bad.append("seed %s: reclaimed at %.1f min (PAST the %.1f min flip) "
                       "yet unpaired -- the flip point moved later"
                       % (seed, survival, changeover_min))
        if paired and survival < changeover_min:
            bad.append("seed %s: paired after only %.1f min (BEFORE the %.1f min flip) "
                       "-- the flip point moved earlier"
                       % (seed, survival, changeover_min))
    return bad


def evaluate(wave, changeover_min=DEFAULT_CHANGEOVER_MIN,
             min_arm_depth=DEFAULT_MIN_ARM_DEPTH):
    """wave dict -> (exit_code, list_of_lines).  Never raises Undecidable."""
    lines = []
    name = wave.get("wave", "(unnamed)") if isinstance(wave, dict) else "(unnamed)"
    lines.append("=== reclaim-blind check (GH #271 ruling) -- wave %s ===" % name)
    lines.append("changeover %.1f min  (measured bracket %.1f < x <= %.1f)  "
                 "min_arm_depth %.1f" % (changeover_min, BRACKET_LO, BRACKET_HI,
                                         min_arm_depth))

    if not isinstance(wave, dict):
        lines.append("UNDECIDABLE: top level is not an object")
        return 2, lines
    machines = wave.get("machines")
    if not isinstance(machines, list) or not machines:
        lines.append("UNDECIDABLE: no `machines` list -- nothing was checked, "
                     "and nothing checked is not a pass")
        return 2, lines

    rows = []
    try:
        for i, machine in enumerate(machines):
            if not isinstance(machine, dict):
                raise Undecidable("machine[%d]: not an object" % i)
            seed = machine.get("seed", "?")
            where = "seed %s" % seed
            survival, code, paired, depth_checked = classify_machine(
                machine, changeover_min, min_arm_depth, where)
            rows.append({"seed": seed, "survival": survival, "code": code,
                         "paired": paired, "depth_checked": depth_checked,
                         "ab": int(machine["ab"]), "ba": int(machine["ba"])})
    except Undecidable as exc:
        lines.append("UNDECIDABLE: %s" % exc)
        return 2, lines

    for row in rows:
        how = "depth-checked" if row["depth_checked"] else "ab/ba only (no arm_depth given)"
        lines.append("  seed %-8s %6.1f min  %-34s ab%-3d/ba%-3d  %s  [%s]"
                     % (row["seed"], row["survival"], row["code"],
                        row["ab"], row["ba"],
                        "PAIRED " if row["paired"] else "NO-PAIR", how))

    violations = check_bracket(rows, changeover_min)
    if violations:
        lines.append("BRACKET VIOLATED -- the changeover constant no longer separates "
                     "this input; re-derive it before trusting any verdict:")
        for v in violations:
            lines.append("    %s" % v)
        lines.append("UNDECIDABLE: refusing to answer with a number the data just "
                     "contradicted (this is exit 2, not a pass and not a BLINDED)")
        return 2, lines

    paired_n = sum(1 for r in rows if r["paired"])
    early_reclaims = [r for r in rows
                      if r["code"] == RECLAIMED and r["survival"] < changeover_min]

    lines.append("yield      : %d paired seed(s) of %d machine(s)" % (paired_n, len(rows)))
    lines.append("attribution: %d machine(s) reclaimed before the flip" % len(early_reclaims))

    low_yield = paired_n <= 1
    if low_yield and early_reclaims:
        lines.append("VERDICT: BLINDED -- yield <= 1 AND the loss is capacity.")
        lines.append("NEXT WAVE: launch --on-demand (ONE wave), then revert to spot.")
        lines.append("  GH #158 stands: a spot machine that cannot be KEPT past the flip "
                     "is a spot machine we did not get.")
        return 1, lines
    if low_yield:
        lines.append("VERDICT: not blinded -- yield <= 1, but NO machine was reclaimed "
                     "before the flip.")
        lines.append("NEXT WAVE: spot.  On-demand does not treat this: whatever ate the "
                     "yield, it was not capacity.  Diagnose the harness instead.")
        return 0, lines
    lines.append("VERDICT: not blinded -- the wave delivered %d paired seed(s)." % paired_n)
    lines.append("NEXT WAVE: spot (the default; GH #158 unchanged).")
    return 0, lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--wave-json", required=True,
                    help="path to the harvested wave's JSON, or - for stdin")
    ap.add_argument("--changeover-min", type=float, default=DEFAULT_CHANGEOVER_MIN)
    ap.add_argument("--min-arm-depth", type=float, default=DEFAULT_MIN_ARM_DEPTH)
    args = ap.parse_args(argv)

    try:
        if args.wave_json == "-":
            wave = json.load(sys.stdin)
        else:
            with open(args.wave_json) as handle:
                wave = json.load(handle)
    except (OSError, ValueError) as exc:
        print("=== reclaim-blind check (GH #271 ruling) ===")
        print("UNDECIDABLE: could not read --wave-json: %s" % exc)
        return 2

    code, lines = evaluate(wave, args.changeover_min, args.min_arm_depth)
    for line in lines:
        print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
