#!/usr/bin/env python3
"""wk_savemana_domain.py -- archive census of Wraith King's `X.ShouldSaveMana`.

Answers the in-game half of GH #407 / `queue.json:hero-27` off an EXISTING
`.dem` corpus.  Zero EC2, zero new games.

WHY A CORPUS SCAN AND NOT A FIXTURE.  The desk-side census
(`tests/test_wk_save_mana_lock_census.lua`) is DOMAIN-EMPTY: on all 33
priceable WK fixture frames the shipped `X.ConsiderQ` returns 0, and forcing
the mana lock to false changes no decision on any of them.  So the fixture
corpus cannot answer "how often does the lock actually refuse a Q that would
otherwise have been cast".  This script asks the same question of real games.

THE PREDICATE, byte for byte from `bots/BotLib/hero_skeleton_king.lua:1932`:

    bShipped = nLV >= 6
           and nAbility ~= nil
           and abilityR ~= nil
           and abilityR:GetCooldownTimeRemaining() <= 3.0
           and ( bot:GetMana() - nAbility:GetManaCost() < abilityR:GetManaCost() )

and it is consulted as the second disjunct of the FIRST statement of
`X.ConsiderQ` (`:1001`):

    if not abilityQ:IsFullyCastable() or X.ShouldSaveMana( abilityQ ) then
        return BOT_ACTION_DESIRE_NONE, 0

Lua `or` short-circuits, so the lock can only change an outcome on a frame
where Q was ALREADY fully castable.  That intersection is the marginal domain
and it is the number this scan exists to produce; the bare "lock fires" count
is an upper bound on it, not a substitute for it.

PRICING (KV, not guessed).  Two independent reads agree:
  - `npc_dota_hero_skeleton_king.txt` as quoted in hero_skeleton_king.lua:567
    and :583 (read 2026-08-26)
  - the Dota 2 datafeed hero_id=42 pull of 2026-08-21 quoted in
    `wk_reincarn_domain.py`
      skeleton_king_hellfire_blast  AbilityManaCost  95 / 110 / 125 / 140
      skeleton_king_reincarnation   AbilityManaCost  220 / 110 / 0

LIMITS -- read these before quoting any number out of this script.
  L1  `cd` in a behav-dump snapshot is the last NETWORKED cooldown remaining,
      fresh only to the last entity update, so the `<= 3.0` leg is +/- one
      snapshot (1.0 game-second at the default interval).
  L2  A frame is sampled once per game-second.  A lock that opens and shuts
      inside one interval is invisible; every count here is a 1 Hz sample of a
      continuous predicate, NOT a count of engine ticks.
  L3  R at rank 0 is UNPRICEABLE here.  The predicate calls
      `abilityR:GetManaCost()` without ever asking whether R is trained, and
      what the engine answers for an UNLEARNED ability is a bot-API question a
      replay cannot answer.  Those frames are counted and reported separately
      and are excluded from every priced cell -- they are never silently
      folded in at cost 220.
  L4  This script reads the SHIPPED predicate only.  `X.ShouldSaveMana` carries
      no gate, so the armed/baseline leg of the wave cannot change its value by
      construction; the leg is nevertheless reported where it is recoverable.
"""
import json, os, sys, glob, collections

WK = 'npc_dota_hero_skeleton_king'
Q_NAME = 'skeleton_king_hellfire_blast'
R_NAME = 'skeleton_king_reincarnation'

# rank -> mana cost.  rank 0 = unlearned = UNPRICEABLE (see L3).
Q_COST = {1: 95, 2: 110, 3: 125, 4: 140}
R_COST = {1: 220, 2: 110, 3: 0}

CD_READY = 3.0      # abilityR:GetCooldownTimeRemaining() <= 3.0
FOLLOW_WINDOW = 2.0  # cell (4): "within the next 2 seconds"


def ability(snap, name):
    # `or ()`, not a default: the Go dumper marshals a nil slice as JSON `null`,
    # so the key is PRESENT and `.get(k, ())` still hands back None.  A hero has
    # no resolvable abilities on pre-horn frames, so this is the common case,
    # not an edge one -- it took out 55 of the first 79 games on the first pass.
    for a in snap.get('abilities') or ():
        if a['name'] == name:
            return a
    return None


def analyse(path):
    """One timeline -> one per-game record.  Returns None if the game has no WK."""
    with open(path) as fh:
        tl = json.load(fh)

    teams = (tl.get('game') or {}).get('teams') or {}
    if WK not in teams:
        return None

    snaps = [s for s in (tl.get('snapshots') or ()) if s['hero'] == WK]
    if not snaps:
        return None

    # ILLUSIONS.  A hero and its illusions share a class name, so `hero` alone
    # selects all of them -- that is exactly what `idx` exists to disambiguate.
    # Measured on this corpus: 12 of 78 games carry WK illusions (usually 3
    # entities at the same `t`, once 5, all sharing player_id, with hp/mana
    # within 1 of each other), which multiplies that game's frame count and
    # silently multiplies every cell computed from it.  It was found only
    # because two independently-derived episode counts disagreed (514 vs 317);
    # nothing in the totals themselves looked wrong.  The real hero is the entity that
    # persists across the whole game; an illusion is transient, so take the idx
    # with the most frames (ties -> lowest idx, for determinism).
    by_idx = collections.Counter(s['idx'] for s in snaps)
    real_idx = min(by_idx, key=lambda i: (-by_idx[i], i))
    n_entities = len(by_idx)
    snaps = [s for s in snaps if s['idx'] == real_idx]

    # Every Q cast this WK actually made, for cell (4).
    q_casts = sorted(
        (e['t'], e.get('target'), bool(e.get('target_hero')))
        for e in tl.get('events') or ()
        if e.get('type') == 'ABILITY'
        and e.get('actor') == WK
        and e.get('inflictor') == Q_NAME
    )
    q_times = [t for t, _, _ in q_casts]

    def followed_by_q(t):
        """(cast?, target, target_is_hero) for the first Q in (t, t+2.0]."""
        for ct, tgt, th in q_casts:
            if t < ct <= t + FOLLOW_WINDOW:
                return True, tgt, th
        return False, None, None

    rec = {
        'game': os.path.basename(path).replace('.timeline.json', ''),
        'wk_team': teams[WK],
        'n_snaps': len(snaps),
        'n_entities': n_entities,   # >1 means this game carried WK illusions
        'n_live': 0,
        'levels': collections.Counter(),
        # (2) structural gate
        'gate': 0,
        # gate frames we cannot price, split by which operand is unlearned
        'gate_r_rank0': 0,
        'gate_q_rank0': 0,
        'gate_priceable': 0,
        # (3) the two shares, both measured on gate_priceable
        'fire': 0,
        'constructive': 0,
        # the marginal domain: fire AND Q was otherwise fully castable
        'marginal': 0,
        # (4) cost side, measured on fire frames
        'fire_followed_by_q': 0,
        'fire_followed_targets': collections.Counter(),
        'marginal_followed_by_q': 0,
        # episode (run-length) view of the fire frames, for iron rule 4 (ii)
        'fire_episodes': 0,
        'marginal_episodes': 0,
        'q_casts_total': len(q_times),
        # raw readings kept so the report can quote them rather than a derived share
        'max_mp_on_constructive': [],
        'mana_on_marginal': [],
    }

    prev_fire = prev_marg = False
    fire_frames = []      # (t, is_marginal) for every fire frame, in order
    for s in snaps:
        if s['hp'] <= 0:
            prev_fire = prev_marg = False
            continue
        rec['n_live'] += 1
        lvl = s['level']
        rec['levels'][lvl] += 1

        r = ability(s, R_NAME)
        q = ability(s, Q_NAME)

        # --- (2) the structural gate: nLV >= 6 and R handle non-nil and R ready
        if not (lvl >= 6 and r is not None and q is not None and r['cd'] <= CD_READY):
            prev_fire = prev_marg = False
            continue
        rec['gate'] += 1

        # --- L3: unpriceable operands are counted, never folded in
        if r['level'] == 0:
            rec['gate_r_rank0'] += 1
            prev_fire = prev_marg = False
            continue
        if q['level'] == 0:
            rec['gate_q_rank0'] += 1
            prev_fire = prev_marg = False
            continue
        rec['gate_priceable'] += 1

        qc, rc = Q_COST[q['level']], R_COST[r['level']]
        mana, maxmp = s['mp'], s['max_mp']

        fire = (mana - qc) < rc
        if not fire:
            prev_fire = prev_marg = False
            continue
        rec['fire'] += 1
        if not prev_fire:
            rec['fire_episodes'] += 1
        prev_fire = True

        # (3) constructive: a FULL pool still cannot pay Q+R, so the lock is
        # not "wait for mana", it is "never".  max_mp is read raw, per (乙).
        if maxmp < qc + rc:
            rec['constructive'] += 1
            rec['max_mp_on_constructive'].append(maxmp)

        # the marginal domain -- IsFullyCastable would have passed
        marg = q['cd'] <= 0.0 and mana >= qc
        if marg:
            rec['marginal'] += 1
            rec['mana_on_marginal'].append(mana)
            if not prev_marg:
                rec['marginal_episodes'] += 1
        prev_marg = marg

        # (4) cost observable -- the cast itself and the target identity, never a desire
        hit, tgt, th = followed_by_q(s['t'])
        if hit:
            rec['fire_followed_by_q'] += 1
            rec['fire_followed_targets'][('hero:' if th else 'nonhero:') + str(tgt)] += 1
            if marg:
                rec['marginal_followed_by_q'] += 1
        # Keep the raw frame times so the episode view below can be derived
        # honestly: the frame-level share double-counts inside one lock episode
        # (one Q can sit within 2s of several consecutive fire frames), and the
        # unit that answers "did the lock merely DELAY the cast" is the EPISODE.
        fire_frames.append((s['t'], marg))

    # --- episode view of cell (4): group consecutive fire frames (<= 1.0s apart,
    # the snapshot interval) into episodes and score the LAST frame of each.
    eps, cur = [], None
    for t, m in fire_frames:
        if cur is not None and t - cur['end'] <= 1.0:
            cur['end'] = t
            cur['marg'] = cur['marg'] or m
        else:
            if cur: eps.append(cur)
            cur = {'start': t, 'end': t, 'marg': m}
    if cur: eps.append(cur)
    rec['fire_ep'] = len(eps)
    rec['marg_ep'] = sum(1 for e in eps if e['marg'])
    rec['fire_ep_followed'] = sum(1 for e in eps if followed_by_q(e['end'])[0])
    rec['marg_ep_followed'] = sum(1 for e in eps if e['marg'] and followed_by_q(e['end'])[0])
    rec['fire_ep_len_s'] = [round(e['end'] - e['start'] + 1.0, 1) for e in eps]

    rec['levels'] = dict(rec['levels'])
    rec['fire_followed_targets'] = dict(rec['fire_followed_targets'])
    return rec


def main():
    paths = []
    for a in sys.argv[1:]:
        paths.extend(sorted(glob.glob(a)) if any(c in a for c in '*?[') else [a])
    out = []
    for p in paths:
        try:
            r = analyse(p)
        except Exception as exc:            # a lost game is reported, never skipped silently
            out.append({'game': os.path.basename(p), 'error': repr(exc)})
            continue
        if r is not None:
            out.append(r)
    json.dump(out, sys.stdout, ensure_ascii=False)


if __name__ == '__main__':
    main()
