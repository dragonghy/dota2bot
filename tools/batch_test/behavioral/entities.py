#!/usr/bin/env python3
"""Entity keying and time interpolation for the behavioural dump -- SHARED.

WHY THIS FILE EXISTS (GH #176 §5.3, replay-check 2026-08-25)
------------------------------------------------------------
Two contaminants were found frame by frame while doing `tpreach`'s condition
(a), and both are properties of how a detector reads the dump rather than of
any one detector:

  1. **A hero NAME is not an entity key.**  An illusion carries the same
     `hero` string and the same `player_id` as the hero it copies; only `idx`
     differs.  Keying frames by name concatenates the streams, and an
     interpolating read then answers with whichever unit sorted adjacent.
  2. **An interpolated `hp_pct` is not aliveness.**  Blending the last live
     sample with the first death sample yields a small POSITIVE hp and a
     position the unit never occupied -- so an `hp > 0` filter applied to the
     blend passes the corpse through, because the blend is what manufactured
     the positive hp.

The fix first shipped inside `tpreach_domain.py`.  It lives here instead
because the same pair of estimators has already drifted apart once in this
tree (`pullcamp_frames` 2026-08-25), and a copied fix is a fix with a
half-life.  `tpreach_domain.py` and `tp_channel_death.py` both import from
here; new detectors should too.

WHAT THIS MODULE DELIBERATELY DOES NOT DO
-----------------------------------------
It does not filter the DECIDING unit.  At a fatal TP press the presser's own
bracket is `[alive, dead]` by construction -- he pressed, then died -- so
applying `alive_interp` to the actor would delete exactly the rows that are
the numerator of GH #159's fatality rate.  A press event is its own proof of
aliveness.  Use `alive_interp` for the OTHER entities in a cross-entity
geometry, and plain `interp` for the actor at the decision instant.
"""
import collections

# Heroes exist in the snapshot stream before the horn; an ILLUSION does not.
# This -- not hp and not motion -- is the discriminator: illusions reach full
# health and do move.
HORN_T = 0.0

# Set by frames_by_hero so a caller can report what it dropped.
DROPPED_ENTITIES = collections.Counter()


def canon(name):
    """DISPLAY name: the `npc_dota_hero_` prefix stripped, nothing else.

    Deliberately NOT the join key -- see `hkey()`.  Its shape is load-bearing
    for readers that hold underscored literals (`tpreach_domain`'s
    `SOURCE_CITED_RANGE['crystal_maiden']`, `bbfloor_domain`'s
    `sp['hero'] == 'skeleton_king'`), so collapsing underscores HERE would
    trade one silent zero for several.
    """
    return (name or '').replace('npc_dota_hero_', '')


def hkey(name):
    """JOIN KEY for a hero across the snapshot stream and the event stream.

    THE DEFECT (GH #303, measured on W24 `2d1024ee` 2026-08-29).  The two dump
    streams do not agree on the spelling:

        snapshots: npc_dota_hero_vengeful_spirit   events: ...vengefulspirit

    8,033 actor rows and 7,545 target rows in five games had no snapshot
    counterpart under `canon()`, and every one of them was Vengeful Spirit.
    `canon()` maps the two to different keys, so a `canon()` join drops the
    hero silently -- the same family as the `skeletonking` trap (2026-08-21),
    the illusion streams (GH #176) and the `t < -60` fountain window (#292).

    THIS IS THE SAME RULE `roam_conversion.canon_hero()` ALREADY CARRIES for
    GH #82, and that is the point of putting it here rather than writing a
    third copy: the dumper derives the snapshot name from the ENTITY CLASS
    (`dumper/main.go snakeFromClass`, which re-inserts an underscore at every
    camelCase boundary) while events carry the COMBAT LOG name, so wherever
    the engine's own npc name concatenates two words the derivation invents a
    separator.  `queen_of_pain`, `vengeful_spirit` and `anti_mage` are the
    three names in this roster where that happens.

    It has to be a RULE and not an alias table: `anti_mage` never appeared in
    the corpus that motivated #82, so a table covering exactly the two
    observed heroes would have looked complete and stayed blind to it.
    `tests/test_entity_key_join.py` also pins that the rule stays
    COLLISION-FREE over every `npc_dota_hero_*` name in `bots/` -- an
    underscore-insensitive key is only safe while no two heroes collapse onto
    one token, and if two ever did the join would MERGE them, which is worse
    than the miss it repairs.
    """
    return canon(name).replace('_', '')


def _flat(k):
    """The underscore-free token `hkey` keys on, for an ALREADY-canon name."""
    return (k or '').replace('_', '')


class HeroMap(dict):
    """`{display name: value}` whose LOOKUPS join across the two spellings.

    Why a mapping and not 20 edited call sites.  Every consumer of
    `frames_by_hero` / `death_times` reaches its rows the same way --
    `frames.get(canon(event_name))` -- so normalising inside the lookup fixes
    all of them at once and cannot be half-applied.  The stored KEYS stay in
    display form, because iteration feeds report columns and equality tests
    that hold underscored names (see `canon`'s note); only the query is
    normalised.

    WHAT THIS DOES NOT COVER, so nobody reads it as more than it is: a site
    that compares two strings directly rather than looking one up, e.g.
    `canon(ev['target']) == hero`.  Those are listed in GH #303.
    """

    def __init__(self, *a, **kw):
        dict.__init__(self, *a, **kw)
        self._alias = {}
        for k in self:
            self._alias.setdefault(_flat(k), k)

    def _resolve(self, k):
        if dict.__contains__(self, k):
            return k                      # exact hit always wins
        return self._alias.get(_flat(k), k)

    def __setitem__(self, k, v):
        dict.__setitem__(self, k, v)
        self._alias.setdefault(_flat(k), k)

    def __contains__(self, k):
        return dict.__contains__(self, self._resolve(k))

    def __getitem__(self, k):
        return dict.__getitem__(self, self._resolve(k))

    def get(self, k, default=None):
        return dict.get(self, self._resolve(k), default)


def join_gaps(timeline, key=canon):
    """Hero names in the EVENT stream with no counterpart in the SNAPSHOT
    stream under `key` -- `{name: row count}`.

    This is GH #303's acceptance metric, and it is the only reading that makes
    the failure loud: a join that drops a hero produces a smaller number, not
    an error, so the thing to measure is the DENOMINATOR the join threw away.
    Called with the default `canon` it reports the defect; called with `hkey`
    it should report nothing.
    """
    have = {key(s['hero']) for s in timeline.get('snapshots', ())}
    gaps = collections.Counter()
    for e in timeline.get('events', ()):
        for side, flag in (('actor', 'actor_hero'), ('target', 'target_hero')):
            nm = e.get(side)
            if not nm or not str(nm).startswith('npc_dota_hero_'):
                continue
            if flag in e and not e.get(flag):
                continue
            if key(nm) not in have:
                gaps[nm] += 1
    return dict(gaps)


def frames_by_hero(timeline):
    """Real heroes only, keyed by hero -- ILLUSIONS AND DUPLICATE ENTITIES DROPPED.

    THE BUG THIS EXISTS TO KILL (replay-check 2026-08-25, caught frame by
    frame on `20260825_061900_slot11 spirit_breaker t=574.8`).  In that game
    `npc_dota_hero_lina` is THREE snapshot streams -- idx 1507 (the hero,
    sampled from t=-54) and idx 857 / 2400 (illusions, both from t=490, both
    reaching hp_pct 1.00).  Keying by name concatenates all three into one
    list with three rows at every timestamp, and an interpolating read then
    searches a list whose neighbours belong to different units.

    That is not hypothetical.  The first cut of `tpreach_domain` classified
    that press as ADDED with "lina at 736 u" while the real lina was 3,837 u
    away walking the other way; the 736 came from an illusion standing 486 u
    from the bot.  18 of 60 sampled W9 games carry duplicate (t, hero) rows.

    It is also the SAME distinction the engine-side predicate makes and the
    detectors were silently not making: `J.CanEnemyInterruptTpChannel` skips
    `J.IsSuspiciousIllusion( hEnemy )` before testing reach at all.  Counting
    an illusion as a band enemy measures a guard the bot does not have.

    Returns (frames_by_name, team_by_name), each frame list sorted by t.
    """
    ent = collections.defaultdict(list)
    meta = {}
    for s in timeline['snapshots']:
        ent[s['idx']].append(s)
        meta[s['idx']] = (canon(s['hero']), s['team'])
    fr, team = {}, {}
    for idx, ss in sorted(ent.items()):
        ss.sort(key=lambda s: s['t'])
        h, tm = meta[idx]
        if ss[0]['t'] > HORN_T:
            DROPPED_ENTITIES[h] += 1
            continue
        if h in fr:
            # two pre-horn entities under one name: keep the longer-lived one
            # and count the other, rather than letting sort order decide
            DROPPED_ENTITIES[h] += 1
            if len(ss) <= len(fr[h]):
                continue
        fr[h] = ss
        team[h] = tm
    # HeroMap, not dict: an event-side lookup spells Vengeful Spirit without
    # the underscore and would otherwise miss every one of its rows (GH #303).
    return HeroMap(fr), HeroMap(team)


def interp(frames, t):
    """Position/state at t, linearly interpolated between bracketing samples.

    Returns None outside the unit's sampled span -- never clamps, because a
    clamped read would silently answer with a frame from before the unit
    existed (or after it stopped being sampled) and those answers look normal.

    `frames` must be sorted by t (frames_by_hero guarantees it).
    """
    if not frames or t < frames[0]['t'] or t > frames[-1]['t']:
        return None
    lo, hi = 0, len(frames) - 1
    while lo < hi - 1:
        mid = (lo + hi) // 2
        if frames[mid]['t'] <= t:
            lo = mid
        else:
            hi = mid
    a, b = frames[lo], frames[hi]
    span = b['t'] - a['t']
    if span <= 0:
        return dict(t=t, x=float(a['x']), y=float(a['y']),
                    hp_pct=float(a['hp_pct']), level=a['level'])
    w = (t - a['t']) / span
    return dict(t=t,
                x=a['x'] + (b['x'] - a['x']) * w,
                y=a['y'] + (b['y'] - a['y']) * w,
                hp_pct=a['hp_pct'] + (b['hp_pct'] - a['hp_pct']) * w,
                level=a['level'])


# A death is followed by a LEAKED positive-hp sample often enough that a
# resurrection test has to survive one.  The replay-check charter's standing
# measurement is "the leak is never longer than 0.30 s"; measured against the
# DEATH EVENT rather than the death frame it is wider than that --
# `20260824_003733_slot10` has witch_doctor dying at t=406.10 and still
# sampled at hp=0.081 on t=406.5, a 0.40 s leak, with hp=0 from 407.5 on.  A
# 0.35 s window therefore read that corpse as resurrected.
#
# So the test is not a time window at all: a resurrection needs TWO CONSECUTIVE
# positive-hp samples.  A leak is a single decaying frame; a hero who is
# actually back up stays up for many samples.  This also keeps Wraith King
# right -- he resurrects IN PLACE (charter, 2026-08-21), so any "respawn =
# jumped to the fountain" rule mis-times him by tens of seconds, while two
# live frames in a row are two live frames in a row wherever he is standing.


def death_times(timeline):
    """{hero: [death timestamps]} from the EVENT stream.

    The events carry the exact instant; the snapshots carry it only to the
    next ~1 s tick.  Same asymmetry the charter records for TP presses.
    """
    out = collections.defaultdict(list)
    for e in timeline.get('events', ()):
        if e.get('type') == 'DEATH' and e.get('target_hero'):
            out[canon(e.get('target'))].append(e['t'])
    for h in out:
        out[h].sort()
    # Keys here are EVENT spellings while every caller asks with a SNAPSHOT
    # spelling (`deaths.get(hero)` with `hero` from frames_by_hero), so this is
    # the same join as frames_by_hero's, taken from the other side (GH #303).
    return HeroMap(out)


def alive_at(frames, deaths, t):
    """Is this unit alive at t, anchored on death EVENTS where they exist?

    WHY THIS EXISTS BESIDE THE BRACKET RULE.  `alive_interp`'s bracket test is
    conservative in one direction: an enemy who dies 0.6 s AFTER a press still
    has a death frame in the press's bracket, so the bracket rule drops him
    even though he was alive, on his feet, and hitting the presser at the
    decision instant.  That is a false NEGATIVE in exactly the population GH
    #159 counts, and swapping one silent error for another is not a fix.

    The death EVENT settles it exactly.  Resurrection is read back from the
    frames rather than assumed: any sampled positive-hp frame more than
    DEATH_LEAK_S after the death means the unit is up again -- which is also
    the reading Wraith King needs, since he resurrects IN PLACE and any
    "respawn = jumped to the fountain" rule mis-times him (charter, 2026-08-21).

    With no death event on record it falls back to the bracket rule, so a
    DEATH the dumper missed still cannot read as alive.
    """
    if not deaths:
        # no death on record for this unit at all: the dumper may simply have
        # missed one, so fall back to the conservative bracket rule.
        return _bracket_alive(frames, t)
    td = None
    for d in deaths:
        if d <= t and (td is None or d > td):
            td = d
    if td is None:
        # He dies later in this game, but not yet.  This is the whole point of
        # the event anchor: the bracket around t contains the death frame of a
        # death that has not happened yet, and the bracket rule would drop a
        # unit that is standing there hitting the presser.
        return True
    for i, s in enumerate(frames):
        if not (td < s['t'] <= t and s['hp_pct'] > 0):
            continue
        nxt = frames[i + 1] if i + 1 < len(frames) else None
        if nxt is None or nxt['hp_pct'] > 0:
            return True   # two live frames in a row (or the stream ends here)
    return False


def _bracket_alive(frames, t):
    """Both bracketing samples show the unit alive.  See alive_interp()."""
    if not frames or t < frames[0]['t'] or t > frames[-1]['t']:
        return False
    lo, hi = 0, len(frames) - 1
    while lo < hi - 1:
        mid = (lo + hi) // 2
        if frames[mid]['t'] <= t:
            lo = mid
        else:
            hi = mid
    return frames[lo]['hp_pct'] > 0 and frames[hi]['hp_pct'] > 0


def alive_interp(frames, t, deaths=None):
    """interp(), but only when BOTH bracketing samples show the unit alive.

    With `deaths` supplied (from `death_times`), the exact event anchor in
    `alive_at` replaces the bracket test -- see that function for why the
    bracket alone trades one silent error for another.

    THE LEAK THIS CLOSES (replay-check 2026-08-25, caught frame by frame on
    `20260825_063640_slot6 lina t=376.4`).  Viper died at t=375.7.  His last
    live sample is 375.5 at 918 u and his next sample, 376.5, is a death
    frame.  Interpolating the press instant 376.4 between them blends a live
    frame with a dead one: the resulting hp_pct is ~0.05 -- comfortably above
    zero -- and the resulting POSITION is a point viper never occupied, 768 u
    away, right inside the blind band.  A corpse was thereby counted as an
    enemy able to break a TP channel.

    Filtering on the interpolated hp cannot catch this, because the blend is
    what manufactures the positive hp.  The bracketing samples have to be
    checked instead -- the same shape as the `closed='death'` fix in
    `towerfear_domain` (2026-08-25) and the charter's standing note that a
    dropped death frame leaves a hole and the next frame is the fountain.
    """
    if deaths is None:
        if not _bracket_alive(frames, t):
            return None
    elif not alive_at(frames, deaths, t):
        return None
    return interp(frames, t)
