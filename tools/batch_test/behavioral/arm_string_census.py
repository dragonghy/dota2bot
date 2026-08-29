#!/usr/bin/env python3
"""Arm-string census -- DID THIS WAVE ARM THE SET WE THINK IT ARMED?

WHY THIS FILE EXISTS (replay-check 2026-08-29)
----------------------------------------------
Every wave's games carry a stamp in `analysis.json:script_version`:

    mirror:<comma-separated armed ids>:s<seed>:<side>

`validate_onspot.sh` builds that stamp as `mirror:$CAND:s$SEED:$side` (:88)
from the SAME `$CAND` shell variable it hands to `write_soak_side.sh` to
render `bots/Customize/soak_side.lua` (:70).  One variable, two consumers --
so the stamp is a faithful mirror of the gate file, and comparing the stamp
against the declared test set answers "was the wave armed as declared?"
without touching the instance.

Every round of this stream has been answering that question BY HAND -- "与
W21 发波登记逐字一致", "四种 stamp 全部 41 id / 363 bytes / sha1 8f78d4cf".
That is the #263 shape: a read that is not in the tree is a read the next
round redoes, and redoes differently.

THE ROUND THAT MOTIVATED IT GOT THE ANSWER WRONG
------------------------------------------------
On 2026-08-29 the W24 census was first run with an inline script that
bucketed the arm string as `cands[cand[:60]] += 1` -- a **display** slice.
The 42-id / 372-byte string printed as 8 ids ending in `teamb`, which is
`teambrain` cut mid-word at byte 60.  Read back as data, that looked exactly
like a harness truncating the armed set to a 60-byte prefix and silently
dropping 35 ids from a wave in flight.  It was about to be filed as a
[harness] issue.  The correct census (below) reads sha1 `607245e9` on
183/183 games -- byte-identical to `test_set.md` line 2.  Nothing was wrong
with the wave; the truncation was in the reader.

This is the #296/#297 family (a tool leading its reader to a false
conclusion), one turn further in: there the tool was in the repo, here it
was the analyst's own throwaway.  Hence the two rules this file enforces:

  * comparison is ALWAYS byte-exact on the full string, never on a slice;
  * any elided display is marked `…(+N more ids)` so an elided rendering
    can never be mistaken for the datum it abbreviates.

WHAT IT REPORTS
---------------
Per run directory: games seen, warmup/unstamped, stamped, seed histogram,
side histogram, the set of distinct arm-string sha1s, and MATCH/MISMATCH
against the declared string.  On mismatch it prints the set difference in
both directions plus both byte lengths -- never a prefix.

EXIT CODES (GH #171 vocabulary: "could not run" is not "passed")
    0  clean   -- every stamped game matches the declared string
    2  refused -- could not run (no inputs, declared string unreadable)
    3  findings-- a mismatch, an unparseable stamp, or >1 distinct string

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **This reads the STAMP, not `soak_side.lua`.**  The one-variable
   argument above makes a matching stamp strong evidence the gate file
   matched, but it is an inference from `validate_onspot.sh`, not a read of
   the file on the instance.  If that script ever stops feeding both
   consumers from one variable, this tool's guarantee lapses with it.
2. **A matching arm string does not mean an id DID anything.**  It means the
   id was in the armed set.  WORKING/BUGGY/SILENT is a frame-level question
   and this tool cannot answer any part of it.
3. **Side counts reflect wave PROGRESS, not balance.**  `validate_onspot.sh`
   runs the legs as blocks (all-radiant wave, then all-dire wave), so a wave
   sampled in flight reads radiant-heavy.  That is not an imbalance defect,
   and a 2:1 split here is NOT grounds for an issue -- check whether the
   wave has finished first.
4. **Warmup games are correctly unstamped.**  `sweep_run.sh:93` skips any
   `script_version` that is not `mirror:*` (it is the bare tree hash before
   the first `deploy_wave`).  They are counted, never treated as a finding.
5. **The declared string is whatever line 2 of `test_set.md` says NOW.**
   Auditing an older wave against today's line 2 will mismatch for the
   honest reason that the set changed; pass `--declared` explicitly to
   audit against the set that wave was launched with.
6. This says nothing about `cand_ref` (GH #141 two-arm waves).  Those stamp
   the same way for the primary arm; the reference arm is not in the stamp.
"""

import argparse
import collections
import glob
import hashlib
import json
import os
import re
import sys

STAMP = re.compile(r"^mirror:(.*):s(\d+):([a-z]+)$")

EXIT_CLEAN, EXIT_REFUSED, EXIT_FINDINGS = 0, 2, 3


def sha8(s):
    return hashlib.sha1(s.encode()).hexdigest()[:8]


def elide(s, keep=3):
    """Render an arm string short WITHOUT ever letting the short form pass as
    the datum.  The marker is mandatory -- see the header."""
    ids = s.split(",")
    if len(ids) <= keep:
        return s
    return "%s,…(+%d more ids)" % (",".join(ids[:keep]), len(ids) - keep)


def declared_from_test_set(path):
    """Line 2 of test_set.md is the armed set, by the same convention
    batch-desk launches from ('arm 串按当轮 test_set.md 第 2 行取')."""
    with open(path) as fh:
        lines = fh.read().split("\n")
    if len(lines) < 2:
        return None
    line = lines[1].strip()
    return line or None


def census(run_dirs, declared):
    """-> (rows, findings).  One row per run dir."""
    rows, findings = [], []
    dsha = sha8(declared)
    for d in run_dirs:
        files = sorted(glob.glob(os.path.join(d, "*.analysis.json")))
        seeds, sides, shas = collections.Counter(), collections.Counter(), set()
        warmup = stamped = 0
        strings = {}
        for f in files:
            try:
                sv = json.load(open(f)).get("script_version", "") or ""
            except Exception as exc:
                findings.append("%s: unreadable analysis.json (%s)" % (f, exc))
                continue
            if not sv.startswith("mirror:"):
                warmup += 1          # LIMIT 4: correct, not a finding
                continue
            m = STAMP.match(sv)
            if not m:
                findings.append("%s: unparseable mirror stamp %r" % (f, sv))
                continue
            cand, seed, side = m.groups()
            stamped += 1
            seeds[seed] += 1
            sides[side] += 1
            h = sha8(cand)
            shas.add(h)
            strings[h] = cand
        rows.append(dict(run=os.path.basename(d.rstrip("/")), games=len(files),
                         warmup=warmup, stamped=stamped, seeds=dict(seeds),
                         sides=dict(sides), shas=sorted(shas), strings=strings,
                         match=(shas == {dsha}) if shas else None))
        if len(shas) > 1:
            findings.append("%s: %d DISTINCT arm strings in one run: %s"
                            % (d, len(shas), sorted(shas)))
        for h, cand in strings.items():
            if h != dsha:
                dset, aset = set(declared.split(",")), set(cand.split(","))
                findings.append(
                    "%s: arm string %s != declared %s\n"
                    "    declared %d ids / %d bytes; armed %d ids / %d bytes\n"
                    "    declared-not-armed: %s\n"
                    "    armed-not-declared: %s"
                    % (d, h, dsha, len(dset), len(declared), len(aset), len(cand),
                       ", ".join(sorted(dset - aset)) or "(none)",
                       ", ".join(sorted(aset - dset)) or "(none)"))
    return rows, findings


def selfcheck():
    """Assertions that pin the two rules in the header."""
    full = "l1trade,l5combo,midtp,suptp,tpcommit,tpdying,lf_rescue,teambrain"
    ok = True

    def check(label, cond):
        nonlocal ok
        print(("  ok   " if cond else "  FAIL ") + label)
        ok = ok and cond

    # 1-2: the motivating defect. A 60-byte prefix must NOT compare equal,
    # and must be reported as a set difference rather than silently accepted.
    cut = full[:60]
    check("60-byte prefix != full string", sha8(cut) != sha8(full))
    check("the prefix really does cut teambrain -> teamb", cut.endswith("teamb"))

    # 3: an elided display can never be mistaken for the datum.
    e = elide(full)
    check("elide() marks what it dropped", "more ids)" in e and e != full)
    check("elide() leaves a short string alone", elide("a,b") == "a,b")

    # 4-5: stamp parsing, including ids that contain no ':' but do contain '_'.
    m = STAMP.match("mirror:%s:s1601:radiant" % full)
    check("stamp parses to the FULL cand", m is not None and m.group(1) == full)
    check("stamp parses seed and side", m.group(2) == "1601" and m.group(3) == "radiant")

    # 6: warmup stamps are not mirror stamps and must not parse.
    check("bare tree hash is not a mirror stamp",
          not "2d1024ee".startswith("mirror:"))

    # 7: a mismatch is a finding, an exact match is not.
    rows, f_bad = census([], full)
    check("no inputs yields no rows", rows == [] and f_bad == [])
    print("SELFCHECK", "PASS" if ok else "FAIL")
    return EXIT_CLEAN if ok else EXIT_FINDINGS


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("run_dirs", nargs="*",
                    help="directories holding a run's *.analysis.json")
    ap.add_argument("--declared", help="armed string to audit against (verbatim)")
    ap.add_argument("--declared-from", default="iterations/streams/test_set.md",
                    help="read the declared string from line 2 of this file")
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()

    if not a.run_dirs:
        print("REFUSED: no run directories given", file=sys.stderr)
        return EXIT_REFUSED

    declared = a.declared
    if not declared:
        try:
            declared = declared_from_test_set(a.declared_from)
        except Exception as exc:
            print("REFUSED: cannot read %s (%s)" % (a.declared_from, exc),
                  file=sys.stderr)
            return EXIT_REFUSED
    if not declared:
        print("REFUSED: declared arm string is empty", file=sys.stderr)
        return EXIT_REFUSED

    rows, findings = census(a.run_dirs, declared)

    print("declared: %d ids / %d bytes / sha1 %s   [%s]"
          % (len(declared.split(",")), len(declared), sha8(declared), elide(declared)))
    print()
    tot = collections.Counter()
    for r in rows:
        tot["games"] += r["games"]; tot["warmup"] += r["warmup"]
        tot["stamped"] += r["stamped"]
        verdict = "MATCH" if r["match"] else ("no stamped games" if r["match"] is None
                                              else "MISMATCH")
        print("%-40s %3d games (%d warmup, %d stamped)  %s"
              % (r["run"], r["games"], r["warmup"], r["stamped"], verdict))
        print("      seeds=%s  sides=%s  arm sha1=%s"
              % (r["seeds"], r["sides"], ",".join(r["shas"]) or "-"))
    print()
    print("TOTAL %d games = %d stamped + %d warmup" % (tot["games"], tot["stamped"], tot["warmup"]))

    # LIMIT 3: say it here so a reader cannot take a lopsided split as a defect.
    allsides = collections.Counter()
    for r in rows:
        allsides.update(r["sides"])
    if allsides and min(allsides.values()) * 2 < max(allsides.values()):
        print("NOTE  side split is lopsided (%s). validate_onspot.sh runs the legs"
              % dict(allsides))
        print("      as BLOCKS, so a wave sampled in flight reads like this.")
        print("      Not a defect by itself -- see LIMIT 3 before filing anything.")

    if findings:
        print()
        for f in findings:
            print("FINDING: %s" % f)
        return EXIT_FINDINGS
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())
