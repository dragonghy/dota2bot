#!/usr/bin/env python3
"""The `ownhalf` DiD must be read against an internal null, not against zero.

`ownhalf_domain.py` prints two difference-in-differences lines:

  real    = [(armed-baseline) on ownhalf ] - [(armed-baseline) on nearmiss]
  placebo = [(armed-baseline) on shipped ] - [(armed-baseline) on nearmiss]

The `shipped` band is the SAME Lua on both legs (the lever cannot be in it),
so the placebo line is what this estimator returns when the lever is known to
be absent.  On W62 the placebo is NOT small: `engaged` came back
ab -20.8 / ba +23.2 on one run and ab -21.5 / ba +22.3 on another -- the same
shape and nearly the same magnitude as the `engaged` reading that the
2026-09-10T03:4xZ round had put in its headline.  Reading the real DiD against
zero would have credited the lever with that.

What this test pins is not a number from that corpus -- it is the property
that makes the comparison meaningful:

  1. both lines come out of the SAME function with different band arguments,
     so nobody can quietly turn the placebo into a different statistic;
  2. on a corpus where the two legs are identical by construction, BOTH lines
     are 0 (the estimator returns nothing on nothing);
  3. an effect injected into the `ownhalf` band alone moves the real line and
     leaves the placebo at 0 -- i.e. the placebo is a null, not a copy;
  4. an effect injected into a leg ACROSS ALL BANDS (plain leg asymmetry,
     which is what the placebo exists to catch) moves BOTH lines together.

Property 4 is the one with teeth: it is the case where the real DiD looks
like a finding and is not one.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools', 'batch_test', 'behavioral'))

import ownhalf_domain as ohd                                    # noqa: E402

FAILURES = []


def check(label, ok, detail=''):
    print('%-4s %s%s' % ('ok' if ok else 'FAIL', label,
                         ('  -- ' + detail) if detail else ''))
    if not ok:
        FAILURES.append(label)


def ep(side, leg, band, closed, engaged=False):
    return {'side': side, 'leg': leg, 'band': band, 'frames': 1,
            'closed': closed, 'engaged': engaged}


def did_lines(eps):
    """Run report() and pull the two DiD blocks back out of its stdout."""
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        ohd.report(ohd.tally(eps), games=1)
    out = buf.getvalue().splitlines()
    got = {}
    key = None
    for line in out:
        if line.startswith('DISCONTINUITY AT THE CONSTANT'):
            key = 'real'
        elif line.startswith('PLACEBO'):
            key = 'placebo'
        elif line.startswith('BAND SIZE'):
            key = None
        elif key and line.startswith('  ab:'):
            got[(key, 'ab')] = line
        elif key and line.startswith('  ba:'):
            got[(key, 'ba')] = line
    return got


def closed_pp(line):
    """'  ab: closed  +8.1 pp   engaged -11.1 pp' -> 8.1"""
    tok = line.split('closed')[1].split('pp')[0].strip()
    return float(tok)


def corpus(closed_by):
    """One episode per (side, leg, band) cell; `closed_by` picks the outcome."""
    eps = []
    for side in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            for band in ('shipped', 'nearmiss', 'ownhalf'):
                # 10 episodes per cell so a rate can be a round number
                n_closed = closed_by(side, leg, band)
                for i in range(10):
                    eps.append(ep(side, leg, band, i < n_closed))
    return eps


# --- 1. the two lines are the same function, different bands ----------------
src = open(os.path.join(HERE, '..', 'tools', 'batch_test', 'behavioral',
                        'ownhalf_domain.py')).read()
check('placebo and real DiD both go through did()',
      "did(stratum, 'ownhalf', 'nearmiss')" in src
      and "did(stratum, 'shipped', 'nearmiss')" in src,
      'a placebo computed by separate code can drift away from being a null')

# --- 2. identical legs => both lines are zero -------------------------------
flat = did_lines(corpus(lambda side, leg, band: 5))
for stratum in ('ab', 'ba'):
    check('identical legs: real DiD is 0 (%s)' % stratum,
          closed_pp(flat[('real', stratum)]) == 0.0,
          flat[('real', stratum)].strip())
    check('identical legs: placebo DiD is 0 (%s)' % stratum,
          closed_pp(flat[('placebo', stratum)]) == 0.0,
          flat[('placebo', stratum)].strip())

# --- 3. an ownhalf-only effect moves the real line, not the placebo ---------
def lever_only(side, leg, band):
    return 8 if (leg == 'armed' and band == 'ownhalf') else 5


lev = did_lines(corpus(lever_only))
for stratum in ('ab', 'ba'):
    check('ownhalf-only effect shows up in the real DiD (%s)' % stratum,
          closed_pp(lev[('real', stratum)]) == 30.0,
          lev[('real', stratum)].strip())
    check('ownhalf-only effect leaves the placebo at 0 (%s)' % stratum,
          closed_pp(lev[('placebo', stratum)]) == 0.0,
          lev[('placebo', stratum)].strip())

# --- 4. a whole-leg asymmetry moves BOTH lines (the case with teeth) --------
# The armed leg closes more everywhere EXCEPT nearmiss.  This is not the
# lever -- the lever cannot touch `shipped` -- but the real DiD reports it as
# +30pp all the same.  The placebo reports the same +30pp, which is exactly
# how a reader is supposed to find out.
def leg_asymmetry(side, leg, band):
    if leg == 'armed' and band in ('ownhalf', 'shipped'):
        return 8
    return 5


asym = did_lines(corpus(leg_asymmetry))
for stratum in ('ab', 'ba'):
    real = closed_pp(asym[('real', stratum)])
    plac = closed_pp(asym[('placebo', stratum)])
    check('leg asymmetry inflates the real DiD (%s)' % stratum,
          real == 30.0, asym[('real', stratum)].strip())
    check('...and the placebo reports it too, so it is catchable (%s)'
          % stratum,
          plac == real,
          'real %+.1f vs placebo %+.1f -- equal means "this is not the lever"'
          % (real, plac))

# --- 4b. the CONTROL band is actually subtracted ----------------------------
# Added after a mutation stand: replacing `vals[treated] - vals[control]` with
# `vals[treated]` -- i.e. deleting the whole difference-in-differences idea and
# reporting the raw band signature -- SURVIVED checks 1-4.  It survived because
# every corpus above leaves the nearmiss control at the same rate on both legs,
# so the subtracted term was 0 and the two statistics coincided.  A control
# that never moves cannot demonstrate that it is being used.
def control_only(side, leg, band):
    return 8 if (leg == 'armed' and band == 'nearmiss') else 5


ctl = did_lines(corpus(control_only))
for stratum in ('ab', 'ba'):
    check('a nearmiss-only effect is SUBTRACTED from the real DiD (%s)'
          % stratum,
          closed_pp(ctl[('real', stratum)]) == -30.0,
          ctl[('real', stratum)].strip() + ' (raw ownhalf signature is 0)')
    check('a nearmiss-only effect is SUBTRACTED from the placebo (%s)'
          % stratum,
          closed_pp(ctl[('placebo', stratum)]) == -30.0,
          ctl[('placebo', stratum)].strip())

# --- 5. the band-size line exists (GH #695: a number ships with its code) ---
check('band-size ratio is printed by the tool, not by hand',
      'BAND SIZE (pair-frames' in src and 'GH #695' in src,
      'the 9.46x that could not be adjudicated was a hand number with no code')

print('')
if FAILURES:
    print('%d failure(s): %s' % (len(FAILURES), ', '.join(FAILURES)))
    sys.exit(1)
print('ownhalf placebo-null contract: all checks passed')
