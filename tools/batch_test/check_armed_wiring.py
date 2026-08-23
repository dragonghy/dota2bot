#!/usr/bin/env python3
"""Assert that every soak id in a wave's armed string is actually WIRED on the
tree that wave is going to check out.

WHY THIS EXISTS (director ruling 2026-08-23T11:xxZ, batch-desk 10:15Z section 7).
The 12:11Z wave pins tree `7159ff3`.  The `campgrade` id's only call site --
`J.Site.RefreshCamp(bot, J.IsModeTurbo() and J.IsSoakCandidate('campgrade'))` --
arrived in `498bad4`, which is AFTER that tree.  Arm `campgrade` on `7159ff3`
and it is a byte-level no-op: the string carries it, the id count matches, the
verdict comes back "no effect", and NOTHING COUNTS THE ABSENCE.  That is the
`creeppull`/`pullcamp` failure over again (an id read as "tested, neutral" when
the thing under test never ran), except bought for real money and read as
evidence for a promote.

The batch desk already checks this by hand.  Two things make the hand check
unsafe, and both are why this is a script with an exit code instead of a table
a human reads:

  1. A TOO-TIGHT pattern fails LOUDLY and wastes a round.  `IsSoakCandidate('x')`
     with no spaces reported 3/24 on a tree where 24 were wired, because the
     source writes `J.IsSoakCandidate( 'x' )`.  Scary, harmless.
  2. A TOO-LOOSE pattern fails SILENTLY and buys a false negative.  A bare
     substring search counts the id where it appears in a COMMENT -- and the
     jmz_func lanefix block comments the exact call it is about to make, one
     line above making it.  This one ships.

And a 0 is not self-explanatory: `lf_rescue` legitimately has no literal call
site (it is dispatched through `J.IsLaneFixOn`), so "expected 0" is a reading
already in circulation for the one id where it is true.  Rather than keep an
allowlist of ids allowed to read 0 -- an allowlist is a place to hide a
regression -- this resolves the indirect form too, so every id has to come out
PROVABLY wired.

Two wiring forms are recognised, both proven by source on the pinned ref:

  direct   J.IsSoakCandidate( '<id>' )
  lanefix  id is `lf_<sub>` and some site calls J.IsLaneFixOn( '<sub>' ),
           AND J.IsLaneFixOn itself still builds the id with `'lf_' .. sub`.
           The second half matters: delete that concat and every lf_* id in
           the string dies at once, with no other symptom.

LIMITS (say these out loud when citing a clean run):
  * WIRED means a call site EXISTS on that tree.  It does not mean the site is
    reachable, that its predicate can be true, or that the id does anything.
    "Wired" is the floor under conditions (a)/(b), not a substitute for either.
  * Comment stripping is `--` outside of nothing: a `--` inside a Lua string
    literal before the call would hide a real site (reads UNWIRED -- the loud
    direction).  No such site exists in this repo today.
  * It reads `bots/` and `game/` only, because that is all the game loads.

Usage:
    python3 tools/batch_test/check_armed_wiring.py --ref <sha> --cand "id1,id2,..."

Exit 0 = every id wired, 1 = at least one UNWIRED (do not launch), 2 = usage
or git error (nothing was checked -- not a pass).
"""
import argparse
import os
import re
import subprocess
import sys

PATHS = ['bots/', 'game/']


def git(args, repo):
    p = subprocess.run(['git'] + args, cwd=repo, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def strip_comment(line):
    """Return the part of a Lua line before its `--` comment, if any."""
    i = line.find('--')
    return line if i < 0 else line[:i]


def grep_lines(ref, repo):
    """Every bots//game/ line at `ref` that mentions either gate helper.

    One git call; all matching is done here so the two patterns can never
    drift apart between the direct and the indirect form.
    """
    rc, out, err = git(['grep', '-n', '-E', 'IsSoakCandidate|IsLaneFixOn',
                        ref, '--'] + PATHS, repo)
    # git grep exits 1 on "no match", which is a legitimate (if alarming)
    # answer; anything else is a broken ref and must not read as "0 wired".
    if rc not in (0, 1):
        sys.stderr.write('git grep failed on ref %r: %s\n' % (ref, err.strip()))
        sys.exit(2)
    rows = []
    for raw in out.splitlines():
        # <ref>:<path>:<lineno>:<text>
        parts = raw.split(':', 3)
        if len(parts) < 4:
            continue
        _, path, lineno, text = parts
        code = strip_comment(text)
        if code.strip():
            rows.append((path, int(lineno), code))
    return rows


def direct_sites(rows, sid):
    pat = re.compile(r"IsSoakCandidate\(\s*(['\"])%s\1\s*\)" % re.escape(sid))
    return [(p, n) for p, n, c in rows if pat.search(c)]


def lanefix_sites(rows, sub):
    pat = re.compile(r"IsLaneFixOn\(\s*(['\"])%s\1\s*\)" % re.escape(sub))
    return [(p, n) for p, n, c in rows if pat.search(c)]


def lanefix_dispatcher(rows):
    """Is J.IsLaneFixOn still composing the per-fix id from its argument?"""
    pat = re.compile(r"IsSoakCandidate\(\s*(['\"])lf_\1\s*\.\.")
    return [(p, n) for p, n, c in rows if pat.search(c)]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--cand', required=True,
                    help="the armed string exactly as it will be deployed, "
                         "comma-separated")
    ap.add_argument('--ref', default='HEAD',
                    help='the tree the wave will check out (default HEAD)')
    ap.add_argument('--repo', default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), '..', '..'))
    a = ap.parse_args()

    ids = [s.strip() for s in a.cand.split(',') if s.strip()]
    if not ids:
        sys.stderr.write('empty armed string -- nothing to check\n')
        return 2
    dupes = sorted({i for i in ids if ids.count(i) > 1})
    rows = grep_lines(a.ref, a.repo)
    dispatch = lanefix_dispatcher(rows)

    unwired = []
    print('ref   %s' % a.ref)
    print('ids   %d (%s)' % (len(ids), 'no duplicates' if not dupes
                             else 'DUPLICATED: ' + ','.join(dupes)))
    print('%-16s %-8s %-5s %s' % ('id', 'form', 'sites', 'first site'))
    for sid in ids:
        sites = direct_sites(rows, sid)
        form = 'direct'
        if not sites and sid.startswith('lf_'):
            # The indirect form needs BOTH halves; a live call site with a
            # dead dispatcher is exactly as unwired as no call site at all.
            sub = sid[3:]
            sub_sites = lanefix_sites(rows, sub)
            if sub_sites and dispatch:
                sites, form = sub_sites, 'lanefix'
            elif sub_sites and not dispatch:
                form = 'NO-DISPATCH'
            else:
                form = 'UNWIRED'
        elif not sites:
            form = 'UNWIRED'
        first = '%s:%d' % sites[0] if sites else '-'
        if form in ('UNWIRED', 'NO-DISPATCH'):
            unwired.append((sid, form))
        print('%-16s %-8s %-5d %s' % (sid, form, len(sites), first))

    if dupes:
        print('\nDUPLICATE ids in the armed string: %s' % ','.join(dupes))
    if unwired:
        print('\nNOT WIRED ON %s -- DO NOT LAUNCH:' % a.ref)
        for sid, form in unwired:
            if form == 'NO-DISPATCH':
                print('  %s: J.IsLaneFixOn( %r ) exists but J.IsLaneFixOn no '
                      'longer builds \'lf_\' .. sub -- every lf_* id is dead'
                      % (sid, sid[3:]))
            else:
                print('  %s: no call site on this tree. Either the wiring '
                      'commit is NEWER than the pinned ref (pin a newer tree), '
                      'or the id was never wired (drop it from the string). '
                      'Arming it here measures nothing and reads as neutral.'
                      % sid)
        return 1
    print('\nall %d armed ids wired on %s' % (len(ids), a.ref))
    return 0


if __name__ == '__main__':
    sys.exit(main())
