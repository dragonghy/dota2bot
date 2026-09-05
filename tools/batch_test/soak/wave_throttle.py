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
slates live under `machines[]`.  The distinction stays structural rather than a
field anyone has to remember to set honestly.

RULING 3 -- WHAT COUNTS AS A SLATE (director, 2026-09-05, GH #534).  Reading
`machines[]` AND NOTHING ELSE was the previous sentence of this docstring, and
it was wrong in the direction that spends money.  Y1 -- the P4.1 upstream
yardstick wave -- flew on the OLD ref-vs-ref path (`aws_run.sh`), which puts its
single machine under `instance` and never writes a `machines[]`.  The file is
also named `Y1_wave.json`, which the record scanner's `^W(\d+)_wave\.json$` did
not match at all.  So a whole wave, up at 15:16:56Z for ~$1.09, was invisible to
gate (i): run at 18:07Z the tool anchored on W48 (12:24:12Z) and printed unlock
18:24:12Z, three hours EARLIER than the conservative truth (~21:17Z).  Nothing
errored; the gate simply let money be spent sooner.  Same family as #205's
uninstallable linter and `describe-instances` answering `[]`: an absence read as
good news.

    Ruled: gate (i) bounds MONEY, so anything that put a billed machine up
    opens a window, whatever harness wrote the record.  A record with no
    `machines[]` opens a window from its single-machine blocks -- `instance` and
    `instance_actual`, both when both are present, because both were billed
    (Y1's `instance` is the 167s attempt that cost ~$0.03 and its
    `instance_actual` is the one that measured).  `rerun` is still excluded:
    ruling 2 is untouched.

    Ordering is ruled with it, because the wave-number walk-back was a proxy for
    time that only holds INSIDE one family (W48 > W43 is also later; Y1 vs W48
    is not a comparison at all).  The walk-back now runs per family, and the
    anchor is the candidate with the LATEST last machine -- the same
    conservative side as ruling 1, one level up.  Every family's candidate is
    printed with its own unlock, so the choice is visible rather than buried.

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

# `W44_wave.json`, and also `Y1_wave.json` -- the ref-vs-ref family (ruling 3).
# The family prefix is captured because the numeric walk-back is only a time
# ordering WITHIN a family.
_WAVE_RE = re.compile(r"^([A-Za-z]+)(\d+)_wave\.json$")

# Single-machine blocks, consulted only when a record has no `machines[]`.
# Order is presentation only -- every present block is read and the LAST one up
# anchors (ruling 1).  `rerun` is deliberately absent (ruling 2).
_SOLO_KEYS = ("instance_actual", "instance")

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
    """Wave records grouped by family, each family highest number first.

    Returns a list of (family, [(number, filename), ...]) with the families in
    a stable order.  The numeric sort is a time ordering only inside a family
    (ruling 3), which is exactly the scope it is used at.
    """
    if not os.path.isdir(waves_dir):
        raise Uncertifiable("waves dir %s does not exist" % waves_dir)
    families = {}
    for name in os.listdir(waves_dir):
        m = _WAVE_RE.match(name)
        if m:
            families.setdefault(m.group(1).upper(), []).append(
                (int(m.group(2)), name)
            )
    if not families:
        raise Uncertifiable("no <family><n>_wave.json under %s" % waves_dir)
    out = []
    for family in sorted(families):
        records = families[family]
        records.sort(key=lambda pair: pair[0], reverse=True)
        out.append((family, records))
    return out


def slate_launches(record, wave_id):
    """The parsed launch instants of every billed machine in one record.

    Returns [] when the record opened no window at all.  `machines[]` is the
    routine-slate shape; a record without one falls back to its single-machine
    blocks (ruling 3).  `rerun` is never consulted (ruling 2).
    """
    machines = record.get("machines")
    if machines:
        return [
            parse_instant(
                machine.get("launched_at"),
                "%s machine %d (seed %s)"
                % (wave_id, index, machine.get("seed", "?")),
            )
            for index, machine in enumerate(machines)
        ]
    launches = []
    for key in _SOLO_KEYS:
        block = record.get(key)
        if isinstance(block, dict):
            launches.append(
                parse_instant(
                    block.get("launched_at"), "%s %s" % (wave_id, key)
                )
            )
    return launches


def load_record(waves_dir, name):
    path = os.path.join(waves_dir, name)
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError) as exc:
        raise Uncertifiable("%s could not be read: %s" % (name, exc))


def find_anchor(waves_dir, exclude=()):
    """The most recent wave that opened a throttle window, across all families.

    Returns (wave_name, launches, skipped, candidates) where `launches` is the
    list of parsed instants, `skipped` names every record walked past (so a
    walk-back is always visible in the output rather than silently changing the
    answer), and `candidates` is each family's own newest window-opener as
    (wave_id, last_launch) -- printed so that ruling 3's choice between families
    stays on the page.
    """
    exclude = {e.upper() for e in exclude}
    skipped = []
    candidates = []
    for _family, records in list_wave_records(waves_dir):
        for _number, name in records:
            wave_id = name.split("_", 1)[0]
            if wave_id.upper() in exclude:
                skipped.append("%s (excluded on the command line)" % wave_id)
                continue
            record = load_record(waves_dir, name)
            launches = slate_launches(record, wave_id)
            if not launches:
                # Ruling 2: no billed slate, so no window opened here.  A
                # `rerun` block is deliberately not consulted.
                skipped.append(
                    "%s (no machines[] and no single-machine block -- opened "
                    "no window)" % wave_id
                )
                continue
            candidates.append((wave_id, launches))
            break
    if not candidates:
        raise Uncertifiable(
            "walked every wave record without finding a slate that opened a "
            "window; skipped: %s" % ("; ".join(skipped) or "none")
        )
    # Ruling 3: across families the anchor is the LATEST last machine -- the
    # conservative side, one level up from ruling 1.
    wave_id, launches = max(candidates, key=lambda pair: max(pair[1]))
    return wave_id, launches, skipped, candidates


def check(waves_dir=DEFAULT_WAVES_DIR, window_hours=DEFAULT_WINDOW_HOURS,
          now=None, exclude=()):
    """Run the gate.  Returns (exit_code, list_of_report_lines)."""
    lines = []
    try:
        if now is None:
            now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0)
        wave_id, launches, skipped, candidates = find_anchor(
            waves_dir, exclude=exclude
        )
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

    if len(candidates) > 1:
        for cand_id, cand_launches in sorted(
            candidates, key=lambda pair: max(pair[1]), reverse=True
        ):
            lines.append(
                "family candidate : %-4s last machine %s -> unlock %s%s"
                % (
                    cand_id,
                    max(cand_launches).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    (max(cand_launches) + _dt.timedelta(hours=window_hours))
                    .strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "  <- ANCHOR (ruling 3: the latest)"
                    if cand_id == wave_id else "",
                )
            )
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
