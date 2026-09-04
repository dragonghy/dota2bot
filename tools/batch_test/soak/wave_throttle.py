#!/usr/bin/env python3
"""Gate (i) -- the >=6h routine-wave throttle -- as an executable check.

Director ruling on GH #469 (乙), 2026-09-04.  Filed by the batch desk the same
round it breached the gate.

THE FILING STORY IS THE SPECIFICATION.  Five gates stand in front of every
launch.  Four of them are programs that print a number:

    (ii)  something new to test   seed_roster_index.py + tree diff
    (iii) cost fence              check_costs.sh
    (iv)  inputs / reclaim-blind  reclaim_blind.py
    around them                   carrier_terms.py, seed_draft.py,
                                  check_armed_wiring.py, luacheck_gate.sh

Gate (i) was prose plus an agent's mental arithmetic: the previous round wrote
an unlock time into the charter, and this round was expected to remember to
compare against it.  W44 launched 3m00s-3m13s early.  The mechanism is worth
stating plainly, because it is not forgetfulness:

    The desk read the wall clock ONCE, at 00:13:47Z, computed "unlock is 8
    minutes out", then did ~5 minutes of gate work and launched -- without
    ever re-reading the clock against the deadline.  The clock was read at
    the DECISION instant, and the gate binds at the ACTION instant.

That is not a first offence.  Reading the desk's own charter back:

    W12 (2026-08-26)  21 seconds early, "如实记录,并给出零成本的修法"
    W20 (2026-08-28)  3m31s early -- verbatim the same post-mortem:
                      "回来直接发波,没有在动作时点再比一次 ... 我把它跑在了
                      决定时点不是动作时点"
    W44 (2026-09-04)  3m00s-3m13s early, same mechanism, same sentence

Three breaches, one shape, and between W20 and W44 the desk's remedy was to
try harder (W21 polled the clock at the action instant and refused four times,
the last by 6 seconds -- it worked, and it worked because a human remembered).
A rule whose enforcement is "remember to run the arithmetic" is not a gate; it
is an intention.  This file makes gate (i) the same kind of object as the other
four: a program that prints a number and refuses.

TWO RULINGS ARE BAKED IN, because leaving them to prose is what got us here.

RULING 1 -- WHICH MACHINE ANCHORS THE WINDOW.  The desk's own records use two
different anchors and nobody ever ruled between them:

    W13-W16   "末台"  the LAST machine up      unlock = max + 6h
    W17-W44   "首台"  the FIRST machine up     unlock = min + 6h

The drift happened silently, inside the enforced range, and it moves the
deadline by the slate spread (66s on W43, 13s on W44).  Ruled: the anchor is
the LAST machine's launch (`max`).  Two reasons, neither of them taste:
(a) it is the conservative side -- a later unlock means fewer waves and less
spend, and gate (i) exists to bound spend; (b) it was the original convention,
so this is restoring a definition rather than inventing one.  The tool prints
BOTH readings and the spread, so the choice stays visible instead of buried.

    Consequence, registered rather than hidden: under this ruling W44's breach
    re-measures to 4m06s-4m19s, not 3m00s-3m13s.  It does not change W44's
    disposition -- the fence had $64 of headroom -- but the recorded number
    changes, and a ruling that quietly restates history is worse than one that
    says so.

RULING 2 -- WHAT OPENS A WINDOW.  A registered repair machine (one seed
re-flown into a wave already in flight, GH #408) does NOT open a new window;
the desk registered exactly that on W40 and W42 and it has never been
contested.  A whole new wave slate does, even when the wave it replaces banked
nothing: W44 is not a repair of W43, it is a new wave with its own four
machines and its own ~$2.15, and gate (i) bounds money, not data.

That ruling is machine-executable by accident of the existing schema and this
file leans on it deliberately: repair machines live under `rerun`, routine
slates live under `machines[]`.  This tool reads `machines[]` and nothing else,
so the distinction is structural rather than a field anyone has to remember to
set honestly.

WHAT THIS FILE REFUSES TO DO.  It never guesses a timestamp.  A record whose
machines carry no `launched_at`, or carry one this parser cannot read as a full
UTC instant (W26/W27 hold bare times of day, `18:17:02Z`, with no date), is
UNCERTIFIABLE -- exit 2, could-not-run, the vocabulary of rule 10 and the push
gate.  It is emphatically not "no anchor found, therefore unlocked".  The whole
family this repo keeps paying for -- #205's uninstallable linter, #213's push
gate that could not run, `describe-instances` answering `[]` -- is an absence
read as good news, and an unlocked throttle is the shape that spends money.

Usage:
    python3 tools/batch_test/soak/wave_throttle.py            # before a launch
    python3 tools/batch_test/soak/wave_throttle.py --exclude W44 \
        --now 2026-09-04T00:18:45Z                            # post-hoc audit

Exit codes:  0 = unlocked (clear to launch)
             2 = could-not-run / uncertifiable (NOT a pass)
             3 = throttled (finding -- launching now breaches gate (i))
"""

import argparse
import datetime as _dt
import json
import os
import re
import sys

DEFAULT_WAVES_DIR = os.path.join(
    "iterations", "reports", "batch-desk", "waves"
)
DEFAULT_WINDOW_HOURS = 6.0

_WAVE_RE = re.compile(r"^W(\d+)_wave\.json$")

# A full UTC instant and nothing else.  Bare times of day (`18:17:02Z`, the
# W26/W27 shape) and naive datetimes are refused on purpose -- see the module
# docstring: a timestamp this parser has to guess at is the one that spends
# money.
_INSTANT_RE = re.compile(
    r"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?Z$"
)


class Uncertifiable(Exception):
    """The check could not be run.  Exit 2.  This is not a pass."""


def parse_instant(text, where):
    """Parse a full UTC instant, or refuse by name."""
    if text is None:
        raise Uncertifiable("%s has no launched_at" % where)
    if not isinstance(text, str):
        raise Uncertifiable(
            "%s launched_at is %s, not a string" % (where, type(text).__name__)
        )
    m = _INSTANT_RE.match(text.strip())
    if not m:
        raise Uncertifiable(
            "%s launched_at %r is not a full UTC instant "
            "(YYYY-MM-DDThh:mm:ssZ). A bare time of day cannot be dated."
            % (where, text)
        )
    y, mo, d, h, mi, s = (int(g) for g in m.groups())
    try:
        return _dt.datetime(y, mo, d, h, mi, s, tzinfo=_dt.timezone.utc)
    except ValueError as exc:
        raise Uncertifiable("%s launched_at %r: %s" % (where, text, exc))


def list_wave_records(waves_dir):
    """Every W<n>_wave.json in the directory, highest wave number first."""
    if not os.path.isdir(waves_dir):
        raise Uncertifiable("waves dir %s does not exist" % waves_dir)
    found = []
    for name in os.listdir(waves_dir):
        m = _WAVE_RE.match(name)
        if m:
            found.append((int(m.group(1)), name))
    if not found:
        raise Uncertifiable("no W*_wave.json under %s" % waves_dir)
    found.sort(key=lambda pair: pair[0], reverse=True)
    return found


def load_record(waves_dir, name):
    path = os.path.join(waves_dir, name)
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError) as exc:
        raise Uncertifiable("%s could not be read: %s" % (name, exc))


def find_anchor(waves_dir, exclude=()):
    """The most recent wave slate that opened a throttle window.

    Returns (wave_name, launches, skipped) where `launches` is the list of
    parsed instants and `skipped` names every record walked past, so a walk-back
    is always visible in the output rather than silently changing the answer.
    """
    exclude = {e.upper() for e in exclude}
    skipped = []
    for _number, name in list_wave_records(waves_dir):
        wave_id = name.split("_", 1)[0]
        if wave_id.upper() in exclude:
            skipped.append("%s (excluded on the command line)" % wave_id)
            continue
        record = load_record(waves_dir, name)
        machines = record.get("machines")
        if not machines:
            # Ruling 2: no routine slate, so no window opened here.  A `rerun`
            # block is deliberately not consulted.
            skipped.append("%s (no machines[] -- opened no window)" % wave_id)
            continue
        launches = [
            parse_instant(
                machine.get("launched_at"),
                "%s machine %d (seed %s)"
                % (wave_id, index, machine.get("seed", "?")),
            )
            for index, machine in enumerate(machines)
        ]
        return wave_id, launches, skipped
    raise Uncertifiable(
        "walked every wave record without finding a slate that opened a "
        "window; skipped: %s" % ("; ".join(skipped) or "none")
    )


def check(waves_dir=DEFAULT_WAVES_DIR, window_hours=DEFAULT_WINDOW_HOURS,
          now=None, exclude=()):
    """Run the gate.  Returns (exit_code, list_of_report_lines)."""
    lines = []
    try:
        if now is None:
            now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0)
        wave_id, launches, skipped = find_anchor(waves_dir, exclude=exclude)
    except Uncertifiable as exc:
        return 2, [
            "UNCERTIFIABLE: %s" % exc,
            "gate (i) DID NOT RUN. That is not a pass -- do not launch on it.",
            "WAVE_THROTTLE: UNCERTIFIABLE (exit 2)",
        ]

    for note in skipped:
        lines.append("skipped %s" % note)

    first, last = min(launches), max(launches)
    window = _dt.timedelta(hours=window_hours)
    unlock = last + window                      # Ruling 1: anchor on the last
    unlock_first = first + window               # the other reading, shown

    lines.append("anchor wave      : %s (%d machine(s))" % (wave_id, len(launches)))
    lines.append("first machine up : %s" % first.strftime("%Y-%m-%dT%H:%M:%SZ"))
    lines.append("last machine up  : %s  <- the anchor (GH #469 ruling 1)"
                 % last.strftime("%Y-%m-%dT%H:%M:%SZ"))
    lines.append("slate spread     : %ds" % int((last - first).total_seconds()))
    lines.append("window           : %gh" % window_hours)
    lines.append("unlock           : %s" % unlock.strftime("%Y-%m-%dT%H:%M:%SZ"))
    lines.append("  (the other reading, anchored on the FIRST machine, would "
                 "unlock %s)" % unlock_first.strftime("%Y-%m-%dT%H:%M:%SZ"))
    lines.append("now              : %s" % now.strftime("%Y-%m-%dT%H:%M:%SZ"))

    delta = int((now - unlock).total_seconds())
    if delta >= 0:
        lines.append("margin           : +%ds past unlock" % delta)
        lines.append("WAVE_THROTTLE: UNLOCKED (exit 0) -- gate (i) passes at "
                     "this instant. RE-RUN IT AT THE LAUNCH INSTANT: it is the "
                     "action, not the decision, that the gate binds.")
        return 0, lines
    short = -delta
    lines.append("margin           : %ds SHORT of unlock" % short)
    lines.append("A launch at this instant BREACHES gate (i) by %dm%02ds."
                 % (short // 60, short % 60))
    lines.append("WAVE_THROTTLE: THROTTLED (exit 3) -- do not launch. Wait %ds."
                 % short)
    return 3, lines


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Gate (i): the >=6h routine-wave throttle, as a check."
    )
    parser.add_argument("--waves-dir", default=DEFAULT_WAVES_DIR)
    parser.add_argument("--window-hours", type=float,
                        default=DEFAULT_WINDOW_HOURS)
    parser.add_argument(
        "--now",
        help="UTC instant to test against (default: the real clock). For "
             "post-hoc audit only -- never pass this before a launch.",
    )
    parser.add_argument(
        "--exclude", action="append", default=[], metavar="WAVE",
        help="wave id to ignore when looking for the anchor, e.g. W44. Use it "
             "to ask 'was that wave allowed to fly?' after the fact.",
    )
    args = parser.parse_args(argv)

    now = None
    if args.now:
        try:
            now = parse_instant(args.now, "--now")
        except Uncertifiable as exc:
            print("UNCERTIFIABLE: %s" % exc)
            print("WAVE_THROTTLE: UNCERTIFIABLE (exit 2)")
            return 2

    code, lines = check(
        waves_dir=args.waves_dir,
        window_hours=args.window_hours,
        now=now,
        exclude=args.exclude,
    )
    for line in lines:
        print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
