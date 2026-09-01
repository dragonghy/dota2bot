#!/usr/bin/env python3
"""`wkqdmg` domain census -- WHERE CAN THIS LEVER EVEN BITE, AND DID IT?

WHY THIS FILE EXISTS (replay-check 2026-08-29, W25 first-verification round)
----------------------------------------------------------------------------
`wkqdmg` (armed from W25, GH #287 family) narrows what the kill-confirm branch
in `X.ConsiderQ` is allowed to claim Wraithfire Blast will do:

    bots/BotLib/hero_skeleton_king.lua:604  X.wk_GetBlastKillDamage
        shipped = ( 40 * ( qlvl - 1 ) + 100 ) * 1.68
        armed   = min( shipped, damage + blast_dot_damage * blast_dot_duration )

It is a PURE NARROWING (`math.min`): the armed leg can only WITHDRAW a claimed
kill, never invent one.  So condition (a) can only ever be read off casts that
DID happen -- the suppressed cast is unobservable by construction.

THE ARITHMETIC THAT DECIDES THE DOMAIN, AND WHY IT IS NOT WHAT THE SOURCE SAYS
------------------------------------------------------------------------------
Per Q rank, with `blast_dot_damage` PER SECOND (the correction already recorded
at hero_skeleton_king.lua:643) and `blast_dot_duration` 2.0 base, +2 from the
t10 talent `special_bonus_unique_wraith_king_facet_1`:

    qlvl    shipped   honest(dur 2)   honest(dur 4)
    1       168.0     120             160
    2       235.2     180             260
    3       302.4     240             360
    4       369.6     300             460

`min` therefore changes the number ONLY where honest < shipped.  With the talent
trained that is TRUE at qlvl 1 (160 < 168) and FALSE at qlvl 2/3/4 (260 > 235.2,
360 > 302.4, 460 > 369.6).

⭐ Now join that to the SHIPPED level-up row, which the source block never does.
`wkbuild` is NOT armed in W25, so the build is `tAllAbilityBuildList`
    {2,1,2,3,2,6,2,3,3,3,6,1,1,1,6}
whose second point is the only Wraithfire Blast point until row 12.  Measured on
real frames (this tool, `--per-cast`), Q sits at **rank 1 from hero level 2 to
hero level 12** and only reaches rank 2 at hero level 13.

    => THE LEVER'S DOMAIN IS EXACTLY "Q AT RANK 1", i.e. hero level <= 12.
    => From hero level 13 on `wkqdmg` is a byte-for-byte no-op.

The source comment reasons rank-by-rank and concludes the gap "OPENS AT LEVEL
10".  Rank-by-rank that is true.  Under the shipped build it is the wrong way
round: at hero level 10-12 Q is still rank 1, so the t10 talent CLOSES the gap
from 48 damage of narrowing (168 -> 120) down to 8 (168 -> 160), and at hero
level 13 the lever goes dead altogether.  A reader who takes "opens at level 10"
as the domain will look for this lever in exactly the phase where it cannot act.

WHAT IT REPORTS
---------------
Per leg (armed/baseline) x layer (ab/ba), over every Wraithfire Blast cast on a
HERO target:

  casts        all Q casts on a hero target
  q1           casts at Q rank 1            <- the live domain
  live48       q1 casts with WK below level 10   (narrowing 168 -> 120)
  live8        q1 casts at WK level >= 10        (narrowing 168 -> 160)
  band         casts where the SHIPPED claim reaches the target's effective HP
               and the ARMED claim does not, read off the frame BEFORE the cast
               -- the naive read, reported so the artefact stays visible
  band_pair    band on BOTH straddling frames (LIMIT 4).  The ONLY column a
               WORKING or BUGGY claim may rest on.
  in_rnge      band casts inside the kill-confirm branch's own reach
  HIT          band_pair AND in range -- what exit 3 counts
  died/surv/unk  the OUTCOME of each band_pair cast: was the target observed to
               reach hp 0 within N seconds anyway?  See THE OUTCOME COLUMN.
  stale        the frame this cast's band membership was read on had ALREADY
               been overtaken by the combat log.  See THE STALE COLUMN.

THE STALE COLUMN (added 2026-09-01, the third half of GH #361)
--------------------------------------------------------------
`lionqdmg_domain.py` grew a cell (3c) on 2026-08-31 after a frame showed its
domain being bought by a corpse the 1 Hz health bar had not caught up with.
The same contamination has to exist here, because `band` is decided by dividing
a SAMPLED hp by `1 - mr` and comparing the result against two claims -- but it
lands differently, and worse: there it inflates a count by one, here it decides
MEMBERSHIP.  A stale frame does not miscount a band cast, it manufactures one.

    stale  a DEATH event for this target in `(t - w, t]`, AND the next
           identity-locked hp sample reads <= 0 (no respawn intervened)

Both halves are required; neither is sufficient.  Turbo halves respawn timers,
so a DEATH a second ago is compatible with a live hero -- measured on this very
corpus, the one stale cast W32 produced had its victim back at 2078 hp six
seconds later.  A frame with no confirming sample is NOT counted, which makes
this a LOWER bound.

⭐ THE COLUMN IS A TEST OF LIMIT 4, NOT A SECOND STATEMENT OF IT.  The argument
says `band_pair` should reject a stale victim for free: the frame AFTER a cast
is where the health bar catches up to 0, and 0 ehp is below the armed claim.
The column exists because that is an argument, and an argument is not a
measurement.  W32's reading: 1 stale cast in 171, 0 of them `band`, 0 `band_pair`
-- consistent with the immunity and far too thin to be evidence for it.

THE OUTCOME COLUMN (added 2026-08-31T15:xxZ, the second half of GH #361)
------------------------------------------------------------------------
GH #361 was filed against `lionqdmg_domain.py`'s cell (3), which counted
"an enemy at 26 hp who escaped and healed" and "an enemy at 1 hp an ally is
killing this very second" as the same event.  `band` here is NOT that defect --
it is a straddle of two CLAIMS around one health bar, not a low-hp census, and
it is bounded above by the shipped claim, so it cannot be inflated by a corpse
about to happen.  What it shares with cell (3) is the missing half sentence:
`band` says the two claims disagreed, and says NOTHING about whether the kill
the shipped claim promised actually arrived.

    band_pair  = the shipped leg would have claimed a kill the armed leg refuses
    died       = ... and the target reached hp 0 within N s ANYWAY
    surv       = ... and the target was OBSERVED alive through the whole window
    unk        = ... and the samples ran out first

WHICH LEG IS INTERPRETABLE, AND WHY IT IS NOT `lionqdmg`'s REASON.
`lionqdmg` reads its outcome column on the baseline leg because a death on the
ARMED leg may BE the armed cast landing -- subtracting there deletes the effect.
That argument does not transfer: `wkqdmg` is a NARROWING, so it never adds a
cast and never adds a death.  The reason the armed leg is uninterpretable here
is a different one and it is structural: a band cast is by definition one the
ARMED claim does not reach, so on the armed leg the kill-confirm branch CANNOT
have produced it (except through this tool's own measurement error -- a stale
frame, an estimated resistance).  Those casts came from the other three
branches of `X.ConsiderQ`, i.e. from a DIFFERENT POPULATION, and their outcome
rate must not be differenced against the baseline leg's.  Armed rows are
printed anyway (铁律 4(i-a): every reading appears in all four cells) and
carry `NO (armed leg)`.

THE TWO COLUMNS ARE ONE-SIDED IN OPPOSITE DIRECTIONS -- do not average them.
  * `died` counts ANY death, whoever dealt it: an ally's attack, a tower, the
    dot from an older blast.  It is therefore an UPPER bound on "kills the
    narrowing could have cost", never an attribution to Wraithfire Blast
    (LIMIT 1 governs here exactly as it governs `band`).
  * `surv` requires a real sample at or past the far edge of the window, so it
    is an OBSERVATION, not an assumption -- a LOWER bound on "claims the
    narrowing withdraws for free".
  * Everything else is `unk` and is folded into NEITHER.  Folding `unk` into
    `surv` (the shape `lionqdmg` uses, where "no further samples" counts as
    survived) would make exactly one of the two columns soft, and it would be
    the one this stream's readings lean on.

`N` IS A REGISTERED CHOICE, NOT A CONSTANT OF NATURE -- the same 2/5/10 s
ladder `lionqdmg_domain.py` prints, and for the same reason: on W31 that file's
knife edge was 4 frames at N=2 s versus 0 at N=5 s.  The whole ladder is
printed so this one cannot hide either.

HOW TO RUN IT (added 2026-08-31 with `--sweep`; before that the ONLY way in was
a hand-written `--legs` tsv that lived nowhere, i.e. no reading this file ever
printed was reproducible from the tree -- GH #263's exact complaint)

    wkqdmg_domain.py --sweep <sweep_run.sh out dir> [--sweep <another>] [--per-cast]

`--sweep` reads `games_manifest.jsonl` and joins it to each timeline's draft:
the manifest's `side` is the side the CANDIDATE string was armed on, and a game
is an ARMED sample for THIS tool only when Wraith King's own team is that side.
One sweep dir per run; dirs from two different candidate strings are REFUSED
rather than pooled (two arm strings are two trees).  The per-game assignment is
printed so a reader can audit the join instead of trusting it.

EXIT CODES (GH #171 vocabulary: "could not run" is not "passed")
    0  clean   -- ran, numbers printed
    2  refused -- could not run (no inputs, unreadable timelines)
    3  findings-- an armed-leg HIT (BUGGY candidate)

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **A Q cast is not a kill-confirm cast.**  `X.ConsiderQ` has several branches
   that all end in the same cast (channeling interrupt, the teamfight
   highest-threat pick, harass).  Only the kill-confirm branch reads
   `X.wk_GetBlastKillDamage`.  Nothing in the dump says which branch fired, so
   `band` is an UPPER BOUND on kill-confirm casts, never an attribution.  This
   is the same attribution problem `blinkflee_domain.py` documents at length; do
   not re-solve it geometrically here.
2. **Magic resistance is not a snapshot field -- but it IS measurable.**
   `J.CanKillTarget` routes through `GetActualIncomingDamage(dmg,
   DAMAGE_TYPE_MAGICAL)`, which applies the target's resistance (base plus
   cloak/hood/pipe plus abilities).  No snapshot carries it.  What the dump DOES
   carry is the blast's own `DAMAGE` event, whose `value` is post-mitigation, so
   `1 - dealt/raw` recovers the effective resistance the engine actually used,
   per cast, on the very target in question.  This tool does that by default
   (`--mr auto`) and falls back to `--mr <x>` only when the cast landed no
   measurable impact.  Measured over the W25 corpus the value is NOT the
   constant 25% every earlier tool assumed: it runs 0.20-0.358 with a mode at
   0.250 (n=100) and a large second cluster at 0.300 (n=47).  Quoting a band
   count computed at a fixed 0.25 is quoting an artefact.
3. **The t10 talent is inferred, not read.**  Hero-unique talent rows are
   invisible to the dumper -- settled 2026-08-27 on the first post-cap frame (GH
   #235, hero_skeleton_king.lua:127): the bots DO train them, no frame can show
   WHICH.  So `dur = 4 if hero level >= 10 else 2` is an inference from the
   shipped `tTalentTreeList`, and it is the CONSERVATIVE one for this lever:
   assuming the talent is trained makes the armed claim LARGER (160 not 120) and
   the band NARROWER.  If the talent were somehow not trained the band would be
   wider, never narrower.
4. ⭐ **1 Hz snapshots -- AND THE BAND IS NARROWER THAN ONE SAMPLING INTERVAL.**
   The frame read for a cast is the last snapshot at or before it, so HP can be
   up to 1.0 s stale.  That is not a rounding nuisance here, it is the finding:
   the band is 48 ehp wide (120..168 at rank 1, i.e. ~34 raw HP at MR 0.30), and
   in the W25 corpus every single band candidate -- 3 armed, 4 baseline -- was
   losing 33 to 115 HP inside the ONE interval that straddles its cast, so all 7
   sit in the band on the frame BEFORE and outside it on the frame AFTER.  A
   verdict read off either frame alone is a coin flip on sampling phase.  Hence
   `band` (the frame before, the stale read a naive tool would use) is reported
   ALONGSIDE `band_pair` (in band at BOTH straddling frames), and only
   `band_pair` is allowed to support a WORKING or BUGGY claim.
5. **Corpse-freeze frames are dropped** (`--dead-window`, default 6 s): a hero's
   snapshot HP freezes across death and the frame after respawn reads full.
   This is the trap `blinkflee_domain.py` §3.2 hit; the filter is here from the
   start, and dropped casts are counted and printed, never silently absorbed.
6. **This says nothing about condition (b) or (c).**  It answers only "is the
   domain live, and did anything happen inside it".
7. **Cast range is read from the Lua, not typed here** -- but the +260 long-range
   bonus branch and the +350/+330 bonus rings are NOT modelled, so `in_range`
   uses the plain `cast range + 80` of the kill-confirm branch itself.
8. Constants (`1.68`, the `40*(lvl-1)+100` row, the special-value key names, and
   the gate's own id) are parsed OUT OF THE LUA at run time inside the function
   body's scope, not re-typed -- GH #207 family, and the scope-first rule that
   `odaoe_domain.py` skipped (GH #296).
9. **The outcome column inherits LIMIT 4 and LIMIT 5, and adds one of its own.**
   Death is read ONLY as a sampled `hp <= 0`; nothing is interpolated and no
   "hp fell a lot" heuristic exists here.  A sampling GAP inside the window
   could therefore hide a death -- unlikely rather than impossible, because the
   corpse-freeze of LIMIT 5 keeps a dead hero reading `hp <= 0` for seconds, so
   a death is normally sampled many times over.  Entity identity is locked to
   the `idx` of the frame the cast was read on (GH #176) so an illusion's or a
   clone's samples cannot supply the death; timelines with no `idx` field at all
   (hand-built fixtures) fall back to hero name and are the only place that lock
   is absent.
10. ⭐ **A lag is only reported while both witnesses can still be describing the
    SAME death** (`witness_lag`'s respawn guard, 2026-09-01).  Before that guard
    a hero who died, respawned and died again inside the 30 s probe had its
    FIRST corpse paired with its SECOND death.  On W32 that produced the whole
    of the census's positive tail: "ev AFTER hp 1 (2%), max +11.8s" was one
    phantom_assassin, and with the guard the same corpus reads 51/51 (100%)
    negative, max -0.2 s.  Casts with a respawn in between now report no lag at
    all and drop out of the census; that is deliberate, and it means the census
    n is a count of CLEAN pairs, not of casts with two witnesses.
    **This does not retract "the disagreement has both signs"** -- that rests on
    `bbfloor_domain.py`'s independent measurement (hp 0.005 from t=45.4, DEATH
    event t=48.6), not on this census.  What it does retract is any reading of
    a POSITIVE lag off this tool's own output before 2026-09-01.
"""

import argparse
import bisect
import collections
import glob
import json
import os
import re
import sys

EXIT_CLEAN, EXIT_REFUSED, EXIT_FINDINGS = 0, 2, 3

WK = "npc_dota_hero_skeleton_king"
QNAME = "skeleton_king_hellfire_blast"

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
HERO_LUA = os.path.join(REPO, "bots", "BotLib", "hero_skeleton_king.lua")


# ----------------------------------------------------------------- Lua anchors

def _fn_body(src, name):
    """Body of `function X.<name>(...)` up to its matching bare `end`.

    Scope FIRST, findall second.  Feeding a whole hero file to a regex is how
    odaoe_domain.py matched a courier's constant (GH #296)."""
    m = re.search(r"^function\s+X\.%s\s*\(" % re.escape(name), src, re.M)
    if not m:
        return None
    depth, i, start = 0, m.start(), None
    for line in src[m.start():].split("\n"):
        s = line.strip()
        if re.match(r"^(function|if|for|while|do)\b", s) or s.endswith(" do"):
            depth += 1
        if re.match(r"^end\b", s):
            depth -= 1
            if depth == 0:
                break
        if start is None:
            start = 0
        i += len(line) + 1
    return src[m.start():i]


def lua_anchors():
    """-> dict of the constants this tool's arithmetic depends on, or None."""
    try:
        src = open(HERO_LUA).read()
    except OSError:
        return None
    body = _fn_body(src, "wk_GetBlastKillDamage")
    if not body:
        return None
    a = {}
    m = re.search(r"\(\s*(\d+)\s*\*\s*\(\s*hAbility:GetLevel\(\)\s*-\s*1\s*\)"
                  r"\s*\+\s*(\d+)\s*\)\s*\*\s*([\d.]+)", body)
    if not m:
        return None
    a["step"], a["base"], a["mult"] = int(m.group(1)), int(m.group(2)), float(m.group(3))
    # The gate inside this body must name exactly this one id (GH #207 family).
    a["ids"] = re.findall(r"IsSoakCandidate\(\s*'([a-z0-9_]+)'\s*\)", body)
    a["keys"] = re.findall(r"GetSpecialValue\w+\(\s*'([a-z_]+)'\s*\)", body)
    m = re.search(r"nImpact\s*\+\s*nDotDps\s*\*\s*nDotDur", body)
    a["honest_form"] = bool(m)
    return a


# KV rows for skeleton_king_hellfire_blast, per rank.  These are the ability's
# own datafeed values; they are NOT in the Lua (the gate reads them off the live
# handle), so they are typed here and pinned by --selfcheck against the two
# ladders the source block states in prose.
KV_IMPACT = {1: 80, 2: 100, 3: 120, 4: 140}
KV_DOT_DPS = {1: 20, 2: 40, 3: 60, 4: 80}
KV_DOT_DUR_BASE = 2.0
KV_DOT_DUR_TALENT = 4.0
Q_CAST_RANGE = 550.0
MR_FALLBACK = 0.25          # LIMIT 2 -- only when the cast landed nothing measurable

# Outcome window (THE OUTCOME COLUMN above).  A REGISTERED CHOICE, not a source
# constant, and deliberately the same 2/5/10 ladder `lionqdmg_domain.py` prints
# so the two ids' outcome cells are read on one clock.  Re-register it the day a
# corpus shows victims taking longer than 5 s to reach hp 0.
OUTCOME_WINDOWS = (2.0, 5.0, 10.0)
OUTCOME_HEADLINE_S = 5.0
OUTCOMES = ("died", "surv", "unk")
SAMPLE_TOL_S = 0.05         # 1 Hz snapshots; a sample "at t0" is not "after t0"
# The DEATH-event column (THE SECOND OUTCOME COLUMN) reads the same instant off
# the combat log instead of the health bar.  The tolerance is deliberately the
# SAME number, not an independently tuned one: the two columns exist to be read
# against each other, and a second knob would make every disagreement
# ambiguous between "the clocks differ" and "the tolerances differ".
EVENT_TOL_S = SAMPLE_TOL_S
# How far past a cast the cross-read looks for BOTH witnesses when measuring
# their lag.  Wider than the 10 s ladder on purpose: the lag is a property of
# the recording, and clipping it at the ladder's edge would silently drop
# exactly the late-event cases that motivate carrying two columns.
LAG_PROBE_S = 30.0
# STALE-VICTIM WINDOW (2026-09-01, GH #361 -- the third column of that thread,
# ported here from `lionqdmg_domain.py`'s cell (3c)).  A REGISTERED CHOICE, and
# deliberately the SAME short ladder that file registered, so the two ids'
# stale columns are read on one clock.  1.0 s is one sampling interval: the
# smallest window in which the health bar can be a whole frame behind the log.
STALE_WINDOWS = (1.0, 2.0)
STALE_HEADLINE_S = 1.0


def claims(qlvl, hero_level, anchors):
    """-> (shipped, armed).  The two numbers J.CanKillTarget is handed."""
    shipped = (anchors["step"] * (qlvl - 1) + anchors["base"]) * anchors["mult"]
    dur = KV_DOT_DUR_TALENT if hero_level >= 10 else KV_DOT_DUR_BASE
    honest = KV_IMPACT[qlvl] + KV_DOT_DPS[qlvl] * dur
    return shipped, min(shipped, honest)


# ------------------------------------------------------------------ timelines

def snap_index(tl):
    """hero name -> (sorted times, snapshots)."""
    by = collections.defaultdict(list)
    for s in tl.get("snapshots", []):
        by[s["hero"]].append(s)
    out = {}
    for h, rows in by.items():
        rows.sort(key=lambda s: s["t"])
        out[h] = ([s["t"] for s in rows], rows)
    return out


def at(idx, hero, t):
    """Last snapshot of `hero` at or before `t` (LIMIT 4)."""
    if hero not in idx:
        return None
    ts, rows = idx[hero]
    i = bisect.bisect_right(ts, t) - 1
    return rows[i] if i >= 0 else None


def straddle(idx, hero, t):
    """(before, after) -- the two snapshots the cast falls between (LIMIT 4).

    The whole `band_pair` discipline rests on this pair: a target whose HP falls
    across the interval is in the band on one frame and out on the other, and
    which one you read is sampling phase, not behaviour."""
    if hero not in idx:
        return None, None
    ts, rows = idx[hero]
    i = bisect.bisect_right(ts, t) - 1
    before = rows[i] if i >= 0 else None
    after = rows[i + 1] if 0 <= i + 1 < len(rows) else None
    return before, after


def measured_mr(tl_events, target, t, qlvl, window=2.0):
    """1 - dealt/raw off the blast's own DAMAGE event -> the resistance the
    ENGINE used on this target (LIMIT 2).  None when nothing landed."""
    best = None
    for e in tl_events:
        if e.get("type") != "DAMAGE" or e.get("inflictor") != QNAME:
            continue
        if e.get("target") != target or not (t <= e["t"] <= t + window):
            continue
        v = e.get("value") or 0
        if best is None or v > best:
            best = v
    if not best:
        return None
    mr = 1.0 - float(best) / KV_IMPACT[qlvl]
    # A KILLING BLOW IS CLIPPED to the target's remaining HP, and a clipped
    # value reads back as absurd "resistance" -- the W25 corpus produced a
    # 0.838 that way on a 27 HP spirit_breaker.  Stacked cloak/hood/pipe tops
    # out near 0.50, so anything past 0.60 is a clip, not a resistance: refuse
    # it and fall back rather than return a fabricated number.
    return mr if -0.05 <= mr <= 0.60 else None


def recently_dead(idx, hero, t, window):
    """LIMIT 5 -- corpse-freeze frames abut respawn frames."""
    if hero not in idx:
        return False
    ts, rows = idx[hero]
    lo = bisect.bisect_left(ts, t - window)
    hi = bisect.bisect_right(ts, t)
    return any(rows[i].get("hp", 1) <= 0 or rows[i].get("hp_pct", 1) <= 0.0
               for i in range(lo, hi))


def target_series(idx, hero, ident):
    """REAL (t, hp) samples of ONE entity, identity-locked (LIMIT 9).

    Rows carrying an `idx` different from the frame the cast was read on are
    dropped, so an illusion or a clone can never supply the death (GH #176).
    Rows with no `idx` at all -- hand-built fixtures -- keep the old
    name-only behaviour, which is the only place that lock is absent."""
    if hero not in idx:
        return []
    _, rows = idx[hero]
    out = []
    for s in rows:
        if ident is not None and s.get("idx") is not None and s["idx"] != ident:
            continue
        out.append((s["t"], s.get("hp") if s.get("hp") is not None else 0.0))
    return out


def outcome(series, t0, window):
    """'died' | 'surv' | 'unk' over (t0, t0 + window] -- see THE OUTCOME COLUMN.

    died  a REAL sample reads hp <= 0 inside the window.  Nothing is
          interpolated and there is no "hp fell a lot" heuristic (LIMIT 9).
    surv  no such sample AND the entity is still sampled at or past the far
          edge of the window: survival OBSERVED, not assumed.
    unk   the samples ran out first (game over, recording stopped).  Folded
          into NEITHER of the other two -- that is the whole point of having
          three outcomes instead of two."""
    lo, hi = t0 + SAMPLE_TOL_S, t0 + window + SAMPLE_TOL_S
    edge, covered = t0 + window - SAMPLE_TOL_S, False
    for t, hp in series:
        if t <= lo:
            continue
        if t <= hi and hp <= 0:
            return "died"
        if t >= edge:
            covered = True
    return "surv" if covered else "unk"


def death_index(tl_events):
    """hero name -> sorted DEATH-event times.

    NOTE THE IDENTITY LOSS, it is the price of this column: a combat-log entry
    carries names, not entity indices (dumper/main.go's OnCMsgDOTACombatLogEntry
    emits actor/target/inflictor as names), so the `idx` lock `target_series`
    applies (GH #176) HAS NO COUNTERPART HERE.  An illusion's death is logged
    under its hero's own name and this index cannot tell the two apart.  That
    makes `dout`'s `died` a WEAKER identity claim than `out`'s, which is one of
    the two reasons the columns are printed side by side instead of merged."""
    by = collections.defaultdict(list)
    for e in tl_events:
        if e.get("type") != "DEATH" or not e.get("target_hero"):
            continue
        tgt = e.get("target")
        if tgt:
            by[tgt].append(e["t"])
    for k in by:
        by[k].sort()
    return by


def event_horizon(tl_events):
    """The last instant the combat log witnesses anything at all.

    This is the DEATH column's coverage test, and it is deliberately a
    GAME-level horizon rather than a per-entity one: absence of a DEATH event
    is not evidence the entity was still being watched, so the only honest
    question the event stream can answer is "was the recording still running".
    Reading the horizon off the events alone (not off the snapshots) keeps this
    column a second, independent witness; it errs toward `unk`, which folds
    into NEITHER of the other two columns and is therefore the safe side."""
    ts = [e["t"] for e in tl_events if e.get("t") is not None]
    return max(ts) if ts else None


def outcome_ev(deaths, horizon, t0, window):
    """'died' | 'surv' | 'unk' over (t0, t0 + window] read off DEATH events.

    Same three states and same ladder as `outcome()` so the two columns can be
    put next to each other -- but they are NOT interchangeable and must never
    be averaged or folded into one number:

      * `died` here is a combat-log fact, not a sampled health bar, so it does
        not wait for the next 1 Hz snapshot; on the W30 band_pair cast the
        event led the first `hp<=0` sample by 1.1 s.
      * `died` here is NOT identity-locked (see `death_index`).
      * The event stream can also LAG the health bar in the other direction:
        `bbfloor_domain.py` measured a skeleton_king whose position was frozen
        and hp 0.005 from t=45.4 while the DEATH event landed at t=48.6.  The
        disagreement therefore has BOTH signs and no column is a strict
        refinement of the other."""
    if horizon is None:
        return "unk"
    lo, hi = t0 + EVENT_TOL_S, t0 + window + EVENT_TOL_S
    for t in deaths:
        if lo < t <= hi:
            return "died"
    return "surv" if horizon >= t0 + window - EVENT_TOL_S else "unk"


def stale_cast(deaths, series, t0, window):
    """Had the combat log ALREADY buried this cast's target at the frame read?

    WHY THIS LANDS HARDER HERE THAN IT DID ON `lionqdmg` (GH #361, 2026-09-01).
    There, cell (3) is a COUNT of low-hp frames and a stale frame inflates the
    count by one.  Here the stale hp is divided by `1 - mr` into `ehp` and then
    compared against two claims, so the contamination decides MEMBERSHIP -- not
    how many band casts there are, but whether THIS cast is one at all.  A
    corpse the health bar has not caught up with reads as a live target sitting
    in the 48-ehp band, which is the exact shape a `band` count is made of.

    ⭐ THE PREDICTION THIS COLUMN EXISTS TO TEST, rather than assert.
    LIMIT 4 already says a single-frame band read is a coin flip on sampling
    phase, and `band_pair` (in band on BOTH straddling frames) is the answer.
    A stale victim should therefore fail `band_pair` for free: the frame AFTER
    the cast is the one where the health bar catches up to hp 0, and 0 ehp is
    below the armed claim.  That is an ARGUMENT, and the reason to count this
    column is that an argument is not a measurement.  Read the `band_pair`
    column of the stale table before quoting the immunity.

    THE PREDICATE IS NOT `lionqdmg`'s, and the difference is in the second half:

      * first half, identical: a DEATH event for this target in
        `(t0 - window, t0]`.  Alone it is not enough -- Turbo respawn timers
        are halved, so a hero who died seconds ago can legitimately be alive.
      * second half, STRONGER HERE: the next hp sample must read `<= 0`, and
        `series` is the IDENTITY-LOCKED series (GH #176, `target_series`), not
        a by-name lookup.  An illusion's samples cannot supply the
        confirmation.  The DEATH side stays name-only (`death_index` has no
        counterpart lock), so the two halves are asymmetric -- an illusion's
        death can still open the first half, and only a real corpse can close
        the second.

    A frame with no further samples is NOT stale by this test (nothing confirms
    it), which keeps the count a LOWER bound -- the safe direction for a finding
    that says a column is over-counted.
    """
    if not any(t0 - window - EVENT_TOL_S <= t <= t0 + EVENT_TOL_S for t in deaths):
        return False
    nxt = next((hp for t, hp in series if t > t0 + SAMPLE_TOL_S), None)
    return nxt is not None and nxt <= 0


def witness_lag(series, deaths, t0):
    """(event_t - first hp<=0 sample t) within LAG_PROBE_S, or None.

    Positive = the combat log was LATE relative to the health bar; negative =
    the health bar was late (the sampling-lag shape).  Returned per cast so a
    reader can audit the disagreement instead of taking this file's word for
    which column moved.

    ⭐ THE RESPAWN GUARD, and the frame that bought it (replay-check
    2026-09-01, read off `93546a/20260831_215858_slot1`, W32 `ab/armed`):

        1229.5  DEATH storm_spirit -> phantom_assassin   (the Q cast is at the
                SAME logged instant, on the same target)
        1229.5  snapshot still carries PA at hp 90
        1230.5  first snapshot at hp 0        <- this corpse belongs to 1229.5
        1235.5  snapshot hp 2078              <- RESPAWNED (Turbo, 6 s)
        1242.3  DEATH storm_spirit -> phantom_assassin   (a SECOND death)

    Unguarded, this paired the 1230.5 corpse with the 1242.3 death and reported
    `lag = +11.8 s`, i.e. "the combat log trailed the health bar by 11.8 s".
    It did not: the log was on time for the death that corpse came from, and a
    whole life happened in between.  That single reading was the ONLY positive
    sign in W32's 52-cast census -- the census read "ev AFTER hp 1 (2%), max
    +11.8s" entirely off a hero who died twice inside the 30 s probe.

    So a lag is only reported while BOTH witnesses can still be describing the
    same death: the search for the event stops at the first sample that shows
    the entity alive again.  A cast with a respawn in between yields None and
    is left out of the census rather than folded in with a fabricated sign.
    Turbo halves respawn timers, which is exactly why a 30 s probe -- correct
    for the lag itself -- is long enough to span a full death-respawn-death."""
    hi = t0 + LAG_PROBE_S
    zero = next((t for t, hp in series if t0 + SAMPLE_TOL_S < t <= hi and hp <= 0), None)
    if zero is None:
        return None
    respawn = next((t for t, hp in series if t > zero and hp > 0), None)
    lim = hi if respawn is None else min(hi, respawn)
    ev = next((t for t in deaths if t0 + EVENT_TOL_S < t <= lim), None)
    return None if ev is None else ev - zero


def qlevel(snap):
    for a in snap.get("abilities", []):
        if a.get("name") == QNAME:
            return a.get("level", 0)
    return 0


def scan(tl, anchors, mr, dead_window):
    """-> (rows, dropped).  One row per Wraithfire Blast cast on a hero."""
    idx = snap_index(tl)
    deaths_by_hero = death_index(tl.get("events", []))
    horizon = event_horizon(tl.get("events", []))
    rows, dropped = [], 0
    for e in tl.get("events", []):
        if e.get("type") != "ABILITY" or e.get("inflictor") != QNAME:
            continue
        if not e.get("target_hero"):
            continue
        t, tgt = e["t"], e.get("target")
        ws, tsnap = at(idx, WK, t), at(idx, tgt, t)
        if ws is None or tsnap is None:
            dropped += 1
            continue
        if recently_dead(idx, tgt, t, dead_window) or recently_dead(idx, WK, t, dead_window):
            dropped += 1
            continue
        q = qlevel(ws)
        if q < 1 or q > 4:
            dropped += 1
            continue
        shipped, armed = claims(q, ws["level"], anchors)
        mr_used, mr_src = mr, "assumed"
        if mr is None:                                  # --mr auto
            m = measured_mr(tl.get("events", []), tgt, t, q)
            mr_used, mr_src = (m, "measured") if m is not None else (MR_FALLBACK, "fallback")
        ehp = tsnap["hp"] / (1.0 - mr_used)
        _, after = straddle(idx, tgt, t)
        ehp_after = after["hp"] / (1.0 - mr_used) if after is not None else None
        dist = ((ws["x"] - tsnap["x"]) ** 2 + (ws["y"] - tsnap["y"]) ** 2) ** 0.5
        in_band = armed < ehp <= shipped
        in_band_after = (ehp_after is not None and armed < ehp_after <= shipped)
        series = target_series(idx, tgt, tsnap.get("idx"))
        tgt_deaths = deaths_by_hero.get(tgt, [])
        out = dict(("out_%s" % w, outcome(series, t, w)) for w in OUTCOME_WINDOWS)
        # The SECOND outcome column, read off the combat log.  Kept as its own
        # set of keys and never reconciled into the first: two readings, not
        # one improved reading (see `outcome_ev`).
        out.update(("dout_%s" % w, outcome_ev(tgt_deaths, horizon, t, w))
                   for w in OUTCOME_WINDOWS)
        # The DOMAIN column, not an outcome one: it asks whether the frame this
        # cast's band membership was read on had already been overtaken by the
        # combat log (see `stale_cast`).
        out.update(("stale_%s" % w, stale_cast(tgt_deaths, series, t, w))
                   for w in STALE_WINDOWS)
        rows.append({
            "t": t, "target": tgt, "hero_level": ws["level"], "qlvl": q,
            "shipped": shipped, "armed": armed, "hp": tsnap["hp"], "ehp": ehp,
            "hp_after": after["hp"] if after is not None else None,
            "ehp_after": ehp_after, "mr": mr_used, "mr_src": mr_src,
            "dist": dist,
            # the only casts the lever is about: shipped reaches, armed does not
            "band": in_band,
            # LIMIT 4 -- the only form allowed to support a verdict
            "band_pair": in_band and in_band_after,
            "in_range": dist <= Q_CAST_RANGE + 80,
            # the target's own hp samples over the headline window, so a reader
            # can check the outcome verdict without re-running this tool
            "traj": [hp for ts_, hp in series
                     if t + SAMPLE_TOL_S < ts_ <= t + OUTCOME_HEADLINE_S + SAMPLE_TOL_S],
            # the raw witnesses behind the two columns, so a disagreement can
            # be audited without re-running the tool
            "death_ev": [ts_ for ts_ in tgt_deaths
                         if t + EVENT_TOL_S < ts_ <= t + LAG_PROBE_S],
            "lag": witness_lag(series, tgt_deaths, t),
        })
        rows[-1].update(out)
    return rows, dropped


# ------------------------------------------------------------------- selfcheck

def selfcheck(anchors):
    fails, ran = [], []

    def ck(name, cond):
        ran.append(name)
        print("  %-58s %s" % (name, "PASS" if cond else "FAIL"))
        if not cond:
            fails.append(name)

    print("wkqdmg_domain --selfcheck")
    ck("hero lua parsed", anchors is not None)
    if anchors is None:
        return 1
    ck("gate names exactly ['wkqdmg']", anchors["ids"] == ["wkqdmg"])
    ck("shipped row is 40*(lvl-1)+100 times 1.68",
       (anchors["step"], anchors["base"], anchors["mult"]) == (40, 100, 1.68))
    ck("honest form is impact + dps*dur", anchors["honest_form"])
    ck("gate reads exactly the three KV keys",
       sorted(anchors["keys"]) == ["blast_dot_damage", "blast_dot_duration", "damage"])
    # the two ladders the source block states in prose
    ck("impact ladder 80/100/120/140",
       [KV_IMPACT[i] for i in (1, 2, 3, 4)] == [80, 100, 120, 140])
    ck("impact+whole-dot (dur 2) is 120/180/240/300",
       [KV_IMPACT[i] + KV_DOT_DPS[i] * 2 for i in (1, 2, 3, 4)] == [120, 180, 240, 300])
    ck("impact+whole-dot (dur 4) is 160/260/360/460",
       [KV_IMPACT[i] + KV_DOT_DPS[i] * 4 for i in (1, 2, 3, 4)] == [160, 260, 360, 460])
    ck("shipped ladder 168/235.2/302.4/369.6",
       [round(claims(i, 1, anchors)[0], 1) for i in (1, 2, 3, 4)] == [168.0, 235.2, 302.4, 369.6])
    # THE DOMAIN CLAIM -- the thing this whole file exists to state
    ck("below level 10 the lever narrows at rank 1 (168 -> 120)",
       claims(1, 9, anchors)[1] == 120)
    ck("at level >= 10 the lever still narrows at rank 1 (168 -> 160)",
       claims(1, 12, anchors)[1] == 160)
    ck("at level >= 10 rank 2 is a NO-OP",
       claims(2, 13, anchors)[1] == claims(2, 13, anchors)[0])
    ck("at level >= 10 rank 3 is a NO-OP",
       claims(3, 14, anchors)[1] == claims(3, 14, anchors)[0])
    ck("at level >= 10 rank 4 is a NO-OP",
       claims(4, 16, anchors)[1] == claims(4, 16, anchors)[0])
    # the trap the last round paid for
    tl = {"events": [{"t": 100.0, "type": "ABILITY", "inflictor": QNAME,
                      "target": "npc_dota_hero_lion", "target_hero": True}],
          "snapshots": [
              {"t": 99.0, "hero": WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9, "level": 5,
               "abilities": [{"name": QNAME, "level": 1}]},
              {"t": 96.0, "hero": "npc_dota_hero_lion", "x": 100, "y": 0, "hp": 0, "hp_pct": 0.0, "level": 5},
              {"t": 99.0, "hero": "npc_dota_hero_lion", "x": 100, "y": 0, "hp": 700, "hp_pct": 1.0, "level": 5}]}
    rows, dropped = scan(tl, anchors, 0.25, 6.0)
    ck("a cast whose target was dead within 6 s is dropped", rows == [] and dropped == 1)
    tl["snapshots"][1]["hp"] = 400
    tl["snapshots"][1]["hp_pct"] = 0.4
    tl["snapshots"][2]["hp"] = 100          # ehp 133.3 -> between 120 and 168
    rows, dropped = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-1 cast at ehp 133 is in the band", len(rows) == 1 and rows[0]["band"])
    tl["snapshots"][2]["hp"] = 200          # ehp 266.7 -> above the shipped claim
    rows, _ = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-1 cast the shipped claim cannot reach is NOT in the band",
       len(rows) == 1 and not rows[0]["band"])
    tl["snapshots"][2]["hp"] = 80           # ehp 106.7 -> both claims reach
    rows, _ = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-1 cast BOTH claims reach is NOT in the band",
       len(rows) == 1 and not rows[0]["band"])
    tl["snapshots"][0]["abilities"][0]["level"] = 3
    tl["snapshots"][0]["level"] = 14
    tl["snapshots"][2]["hp"] = 200
    rows, _ = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-3 cast can never be in the band (lever is a no-op there)",
       len(rows) == 1 and not rows[0]["band"])
    # --- LIMIT 4: the frame-pair discipline, and LIMIT 2: measured resistance
    def one(hp_before, hp_after, dealt=None, mr=0.25, qlvl=1, wklvl=5):
        ev = [{"t": 100.0, "type": "ABILITY", "inflictor": QNAME,
               "target": "npc_dota_hero_lion", "target_hero": True}]
        if dealt is not None:
            ev.append({"t": 100.3, "type": "DAMAGE", "inflictor": QNAME,
                       "target": "npc_dota_hero_lion", "target_hero": True, "value": dealt})
        tl = {"events": ev, "snapshots": [
            {"t": 99.5, "hero": WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9, "level": wklvl,
             "abilities": [{"name": QNAME, "level": qlvl}]},
            {"t": 99.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": hp_before, "hp_pct": 0.5, "level": 5},
            {"t": 100.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": hp_after, "hp_pct": 0.3, "level": 5}]}
        r, _ = scan(tl, anchors, mr, 6.0)
        return r[0] if r else None

    r = one(110, 108)                       # ehp 146.7 -> in band on both frames
    ck("a steady target in the band counts as band_pair", r and r["band"] and r["band_pair"])
    r = one(110, 40)                        # collapsing target -- the W25 shape
    ck("a target collapsing across the interval is band but NOT band_pair",
       r and r["band"] and not r["band_pair"])
    r = one(110, 108, dealt=56, mr=None)    # 1 - 56/80 = 0.30
    ck("--mr auto measures 0.300 off a 56-damage impact at rank 1",
       r and r["mr_src"] == "measured" and abs(r["mr"] - 0.30) < 1e-9)
    r = one(27, 0, dealt=13, mr=None)       # the clipped killing blow
    ck("a killing-blow clip is REFUSED, not read as 0.84 resistance",
       r and r["mr_src"] == "fallback" and abs(r["mr"] - MR_FALLBACK) < 1e-9)
    r = one(160, 158, qlvl=2, wklvl=13, mr=0.25)
    ck("no rank-2 cast can be band_pair either", r and not r["band_pair"])

    # --- the outcome column ------------------------------------------------
    # Built through scan(), not by calling outcome() on a hand-made list: the
    # thing that can rot silently is the WIRING (which entity's samples, which
    # t0), not the three-way arithmetic.
    def cast_with(after_samples, ident=None, tgt_idx=None, events=(), after_hp=108,
                  after_idx=None, after_frame=True):
        """One rank-1 band cast at t=100 whose target then has `after_samples`
        as (t, hp) [, idx] rows.  `events` appends extra combat-log rows, which
        is the ONLY way to drive the DEATH-event column -- it does not read
        snapshots at all, and its coverage horizon is the last event.

        `after_hp` is the STRADDLING frame (t=100.5), the one `band_pair` and
        `stale_cast`'s confirming half both read; it defaults to a second band
        frame so the outcome cases above stay `band_pair` casts."""
        snaps = [
            {"t": 99.5, "hero": WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9, "level": 5,
             "abilities": [{"name": QNAME, "level": 1}]},
            {"t": 99.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": 110, "hp_pct": 0.5, "level": 5},          # ehp 146.7 -> band
            {"t": 100.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": after_hp, "hp_pct": 0.5, "level": 5}]
        if not after_frame:
            # NO sample after the cast at all -- the only way to reach the
            # `nxt is None` branch, which the straddling frame otherwise always
            # satisfies.  (2026-09-01: the "no further samples is not stale"
            # check was written without this and asserted nothing; the mutation
            # stand's M5 survived until the fixture could express the case.)
            snaps.pop(2)
        if tgt_idx is not None:
            snaps[1]["idx"] = tgt_idx
            # `after_idx` exists so the straddling frame can belong to a
            # DIFFERENT entity than the cast frame -- the only way to put an
            # illusion's corpse in the slot the identity lock has to reject
            if after_frame:
                snaps[2]["idx"] = tgt_idx if after_idx is None else after_idx
        for row in after_samples:
            s = {"t": row[0], "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
                 "hp": row[1], "hp_pct": 0.1, "level": 5}
            if len(row) > 2:
                s["idx"] = row[2]
            snaps.append(s)
        tl = {"events": [{"t": 100.0, "type": "ABILITY", "inflictor": QNAME,
                          "target": "npc_dota_hero_lion", "target_hero": True}]
                        + list(events),
              "snapshots": snaps}
        rr, _ = scan(tl, anchors, 0.25, 6.0)
        return rr[0] if rr else None

    def death_ev(t, target="npc_dota_hero_lion", target_hero=True):
        return {"t": t, "type": "DEATH", "actor": "npc_dota_hero_other",
                "target": target, "target_hero": target_hero}

    def tick_ev(t):
        """A non-DEATH combat-log row: it moves the coverage horizon and
        nothing else, which is how `surv` is separated from `unk` here."""
        return {"t": t, "type": "DAMAGE", "actor": "npc_dota_hero_other",
                "target": "npc_dota_hero_lion", "target_hero": True, "value": 1}

    alive = [(t, 60) for t in (101.5, 102.5, 103.5, 104.5, 105.5, 106.5)]
    r = cast_with(alive)
    ck("a target sampled alive past the window edge is surv",
       r and r["band_pair"] and r["out_5.0"] == "surv")
    r = cast_with([(101.5, 40), (102.5, 0), (103.5, 0), (104.5, 0), (105.5, 0)])
    ck("a target sampled at hp 0 inside the window is died",
       r and r["out_5.0"] == "died")
    r = cast_with([(101.5, 60), (102.5, 60)])
    ck("a target whose samples stop before the edge is unk, NOT surv",
       r and r["out_5.0"] == "unk")
    r = cast_with([])
    ck("a target with no samples at all after the cast is unk", r and r["out_5.0"] == "unk")
    # the knife edge N is registered for: a death at t0+7s
    r = cast_with([(101.5, 60), (103.5, 60), (105.5, 60), (107.0, 0), (109.5, 0)])
    ck("a death at +7 s is not died at 2 s or 5 s but is at 10 s",
       r and r["out_2.0"] != "died" and r["out_5.0"] != "died" and r["out_10.0"] == "died")
    ck("that same cast is surv (not unk) at the shorter windows",
       r and r["out_2.0"] == "surv" and r["out_5.0"] == "surv")
    # identity lock (LIMIT 9): an illusion's corpse is not the target's
    r = cast_with([(101.5, 60, 7), (102.5, 0, 9), (103.5, 60, 7),
                   (104.5, 60, 7), (105.5, 60, 7), (106.5, 60, 7)], tgt_idx=7)
    ck("a hp-0 sample under a DIFFERENT idx does not make the target died",
       r and r["out_5.0"] == "surv")
    # a corpse BEFORE the cast is the dead-window's job, never the outcome's
    ck("the outcome window never looks backwards",
       outcome([(95.0, 0), (99.0, 0), (101.0, 50), (105.5, 50)], 100.0, 5.0) == "surv")
    ck("a sample exactly at t0 is not 'after' t0",
       outcome([(100.0, 0), (101.0, 50), (105.5, 50)], 100.0, 5.0) == "surv")
    ck("the three outcomes are exhaustive and exclusive",
       all(outcome(s, 100.0, 5.0) in OUTCOMES
           for s in ([], [(105.5, 50)], [(101.0, 0)], [(101.0, 50)])))
    ck("the headline window is on the printed ladder",
       OUTCOME_HEADLINE_S in OUTCOME_WINDOWS)

    # --- the SECOND outcome column (DEATH events) ---------------------------
    # Same wiring discipline: driven through scan(), never by calling
    # outcome_ev() on a hand-made list, because the thing that rots is which
    # entity's events and which t0 -- not the three-way arithmetic.
    r = cast_with(alive, events=[tick_ev(106.5)])
    ck("ev: no DEATH event and the log still running is surv",
       r and r["band_pair"] and r["dout_5.0"] == "surv")
    r = cast_with(alive, events=[death_ev(102.5), tick_ev(106.5)])
    ck("ev: a DEATH event inside the window is died", r and r["dout_5.0"] == "died")
    r = cast_with(alive, events=[tick_ev(102.0)])
    ck("ev: a log that stops before the window edge is unk, NOT surv",
       r and r["dout_5.0"] == "unk")
    r = cast_with(alive)
    ck("ev: no events after the cast at all is unk", r and r["dout_5.0"] == "unk")
    r = cast_with(alive, events=[death_ev(107.0), tick_ev(111.0)])
    ck("ev: a DEATH at +7 s is died at 10 s only, and surv (not unk) below",
       r and r["dout_2.0"] == "surv" and r["dout_5.0"] == "surv"
       and r["dout_10.0"] == "died")
    r = cast_with(alive, events=[death_ev(95.0), tick_ev(106.5)])
    ck("ev: the window never looks backwards", r and r["dout_5.0"] == "surv")

    # --- the STALE column (a DOMAIN test, not an outcome one) --------------
    # Same wiring discipline again: driven through scan(), because what rots is
    # WHICH series and WHICH deaths get handed to stale_cast, not its two-line
    # arithmetic.  The band frame here is the 99.5 snapshot (hp 110 -> ehp
    # 146.7, inside 120..168), so a stale hit means that frame was a corpse.
    SW0, SW1 = STALE_WINDOWS
    # the real shape: hp 110 on the frame BEFORE (in band), 0 on the frame
    # AFTER, and the log already carrying the DEATH before the cast instant
    corpse = dict(after_hp=0,
                  after_samples=[(101.5, 0), (102.5, 0), (103.5, 0), (104.5, 0)])

    def stale_cast_row(death_t=99.7, **kw):
        kw = dict(corpse, **kw)
        evs = kw.pop("events", None)
        if evs is None:
            evs = ([] if death_t is None else [death_ev(death_t)]) + [tick_ev(106.5)]
        return cast_with(kw.pop("after_samples"), events=evs, **kw)

    r = stale_cast_row()
    ck("stale: a DEATH just before the frame + a confirming sample is stale",
       r and r["stale_%s" % SW0])
    ck("stale: that same cast is still counted in `band` (the point of the column)",
       r and r["band"])
    ck("stale: and it is NOT band_pair -- LIMIT 4 rejects it for free",
       r and not r["band_pair"])
    r = stale_cast_row(death_t=101.4)
    ck("stale: a DEATH just AFTER the cast is the ordinary outcome case, not stale",
       r and not r["stale_%s" % SW0] and r["out_5.0"] == "died")
    r = cast_with([(101.5, 60), (102.5, 60), (103.5, 60), (104.5, 60),
                   (105.5, 60), (106.5, 60)],
                  events=[death_ev(99.7), tick_ev(106.5)])
    ck("stale: a DEATH before the frame with NO confirming sample is not stale "
       "(Turbo respawn is fast)", r and not r["stale_%s" % SW0])
    r = stale_cast_row(death_t=None)
    ck("stale: a confirming sample with NO prior DEATH is not stale either",
       r and not r["stale_%s" % SW0])
    r = cast_with([], after_frame=False, events=[death_ev(99.7), tick_ev(106.5)])
    ck("stale: no samples after the frame at all is NOT stale (lower bound)",
       r and not r["stale_%s" % SW0])
    ck("...and that really is the no-sample case, not a live one masking it",
       r and r["hp_after"] is None)
    r = stale_cast_row(death_t=98.7)
    ck("stale: a DEATH older than the window is out at %gs and in at %gs" % (SW0, SW1),
       r and not r["stale_%s" % SW0] and r["stale_%s" % SW1])
    r = stale_cast_row(death_t=100.0)
    ck("stale: a DEATH exactly at the cast instant counts (the log won the tie)",
       r and r["stale_%s" % SW0])
    r = stale_cast_row(events=[death_ev(99.7, target="npc_dota_hero_axe"),
                               tick_ev(106.5)])
    ck("stale: another hero's DEATH does not make this victim stale",
       r and not r["stale_%s" % SW0])
    r = stale_cast_row(events=[death_ev(99.7, target_hero=False), tick_ev(106.5)])
    ck("stale: a non-hero DEATH row does not make this victim stale",
       r and not r["stale_%s" % SW0])
    # the half this file strengthens over lionqdmg's: the confirming sample is
    # identity-locked, so an illusion's corpse cannot close the predicate.
    # The straddling frame carries the OTHER idx, so the target's own next
    # sample is alive and the corpse is never confirmed.
    r = cast_with([(101.5, 60, 7), (102.5, 60, 7), (103.5, 60, 7),
                   (104.5, 60, 7), (105.5, 60, 7), (106.5, 60, 7)],
                  tgt_idx=7, after_idx=9, after_hp=0,
                  events=[death_ev(99.7), tick_ev(106.5)])
    ck("stale: a hp-0 sample under a DIFFERENT idx does not confirm the corpse",
       r and not r["stale_%s" % SW0])
    ck("stale: the headline window is on the printed ladder",
       STALE_HEADLINE_S in STALE_WINDOWS)
    r = cast_with(alive, events=[death_ev(100.0), tick_ev(106.5)])
    ck("ev: a DEATH exactly at t0 is not 'after' t0", r and r["dout_5.0"] == "surv")
    r = cast_with(alive, events=[death_ev(102.5, target="npc_dota_hero_axe"),
                                 tick_ev(106.5)])
    ck("ev: another hero's DEATH is not the target's",
       r and r["dout_5.0"] == "surv")
    r = cast_with(alive, events=[death_ev(102.5, target_hero=False), tick_ev(106.5)])
    ck("ev: a non-hero DEATH row is not the target's",
       r and r["dout_5.0"] == "surv")
    ck("ev: the three outcomes are exhaustive and exclusive",
       all(outcome_ev(d, h, 100.0, 5.0) in OUTCOMES
           for d in ([], [101.0], [107.0]) for h in (None, 100.0, 110.0)))
    ck("ev: no horizon at all is unk, never surv",
       outcome_ev([], None, 100.0, 5.0) == "unk")

    # THE TWO COLUMNS DISAGREE IN BOTH DIRECTIONS -- the whole reason they are
    # printed side by side rather than reconciled into one.  Both shapes are
    # measured facts: the sampling lag on W30's band_pair cast (event +1.1 s,
    # first hp<=0 sample +2.2 s) and the late combat-log entry bbfloor_domain
    # measured (hp 0.005 from t=45.4, DEATH event t=48.6).
    r = cast_with([(101.5, 60), (102.5, 60), (103.5, 60), (104.5, 60),
                   (105.5, 60), (106.5, 60)],
                  events=[death_ev(104.0), tick_ev(106.5)])
    ck("hp says surv while ev says died (event leads the health bar)",
       r and r["out_5.0"] == "surv" and r["dout_5.0"] == "died")
    r = cast_with([(101.5, 0), (102.5, 0), (103.5, 0), (104.5, 0), (105.5, 0)],
                  events=[death_ev(107.5), tick_ev(111.0)])
    ck("hp says died while ev says surv (combat log trails the health bar)",
       r and r["out_5.0"] == "died" and r["dout_5.0"] == "surv")
    ck("...and that cast's lag is reported positive (ev AFTER hp)",
       r and r["lag"] is not None and abs(r["lag"] - 6.0) < 1e-9)
    r = cast_with([(101.5, 60), (102.5, 0), (103.5, 0), (104.5, 0), (105.5, 0)],
                  events=[death_ev(101.4), tick_ev(106.5)])
    ck("a lag the other way is reported negative (hp behind the event)",
       r and r["lag"] is not None and abs(r["lag"] + 1.1) < 1e-9)
    # THE RESPAWN GUARD -- W32's only positive lag was this shape (see
    # `witness_lag`).  Same samples as the "+6.0" case above, plus a respawn
    # between the corpse and the second death.
    r = cast_with([(101.5, 0), (102.5, 0), (103.5, 0), (104.5, 900), (105.5, 900)],
                  events=[death_ev(107.5), tick_ev(111.0)])
    ck("a DEATH on the far side of a RESPAWN is not this corpse's lag",
       r and r["lag"] is None)
    ck("...and that cast is still reported died by BOTH columns (only the lag drops)",
       r and r["out_5.0"] == "died" and r["dout_10.0"] == "died")
    r = cast_with([(101.5, 0), (102.5, 0), (103.5, 0), (104.5, 900), (105.5, 900)],
                  events=[death_ev(103.0), tick_ev(111.0)])
    ck("a DEATH before the respawn is still measured (the guard is a limit, "
       "not a veto)", r and r["lag"] is not None and abs(r["lag"] - 1.5) < 1e-9)
    ck("the two columns are separate keys -- neither overwrites the other",
       r and r["out_5.0"] == "died" and r["dout_5.0"] == "died"
       and "out_5.0" in r and "dout_5.0" in r)
    # the identity loss is REGISTERED, not hidden: the event column cannot do
    # what the hp column's idx lock does, and a test that pretended otherwise
    # would be the place that lie would live
    r = cast_with([(101.5, 60, 7), (102.5, 60, 7), (103.5, 60, 7), (104.5, 60, 7),
                   (105.5, 60, 7), (106.5, 60, 7)], tgt_idx=7,
                  events=[death_ev(102.5), tick_ev(106.5)])
    ck("ev: an illusion's DEATH cannot be excluded (identity loss, registered)",
       r and r["out_5.0"] == "surv" and r["dout_5.0"] == "died")

    # the four ConsiderQ branches must still be in the tree, or this argument
    # silently expires (blinkflee_domain.py's lesson)
    src = open(HERO_LUA).read()
    ck("kill-confirm branch still reads wk_GetBlastKillDamage",
       "J.CanKillTarget( npcEnemy, X.wk_GetBlastKillDamage( abilityQ ), nDamageType )" in src)
    ck("ConsiderQ still has a channeling-interrupt branch above it",
       "npcEnemy:IsChanneling()" in src)
    ck("ConsiderQ still has a teamfight branch below it",
       "J.IsInTeamFight( bot, 1200 )" in src)
    ck("wkbuild is still a SEPARATE gate from wkqdmg",
       "J.IsSoakCandidate( 'wkbuild' )" in src)
    print("%d PASS / %d FAIL" % (len(ran) - len(fails), len(fails)))
    return 1 if fails else 0


# -------------------------------------------------------------- sweep -> legs

TEAM_OF_SIDE = {"radiant": 2, "dire": 3}

# LAYER CONVENTION, registered here because it is a choice and not a fact:
# `ab` is the game whose CANDIDATE-armed side is radiant, `ba` the swapped
# mirror.  It is the physical side of the arming, not of Wraith King, so the
# radiant-side bias (+1.5k gold; the reason 铁律 4(i-a) exists) lands in a
# stratum rather than in the difference between the legs.
LAYER_OF_SIDE = {"radiant": "ab", "dire": "ba"}

GATE_ID = "wkqdmg"


class SweepRefused(Exception):
    """Could not build legs from the sweep dirs -- exit 2, never a silent 0."""


def from_sweeps(dirs):
    """-> (timeline paths, legs map, audit rows) from sweep_run.sh output.

    Which leg a game is on is NOT the manifest's `side` on its own: `side` is
    the side the CANDIDATE string was armed on, and this tool reads Wraith
    King's casts, so the game is an ARMED sample only when WK's own team is
    that side.  A tool that skipped that join would label half the corpus
    backwards and still print a full table.

    THE LEGS MAP IS KEYED BY PATH, NOT BY GAME NAME, and that is not tidiness.
    A soak game's name is a wall-clock stamp plus a slot (`20260831_003227_slot1`),
    so two runs of the SAME wave launched seconds apart produce the SAME name
    for two DIFFERENT games -- W30 has exactly that: `20260831_003227_slot1`
    exists under run 89e581 (seed 2204, WK team 3, radiant armed -> BASELINE)
    and again under run 69e067 (seed 2315, WK team 2, radiant armed -> ARMED),
    i.e. the same key with OPPOSITE legs.  A name-keyed map silently keeps
    whichever dir came last and files the other game on the wrong leg; the
    2026-08-31T16:45Z reading printed `ab/armed 5, ab/baseline 1` against an
    audit table that says 4 and 2, and nothing raised a hand."""
    paths, legs, rows, arm_strings = [], {}, [], set()
    seen_names = {}
    for d in dirs:
        man = os.path.join(d, "games_manifest.jsonl")
        if not os.path.exists(man):
            raise SweepRefused("no games_manifest.jsonl under %s" % d)
        for line in open(man):
            line = line.strip()
            if not line:
                continue
            m = json.loads(line)
            game, side = m["game"], m.get("side")
            if side not in TEAM_OF_SIDE:
                raise SweepRefused("game %s has no armed side in the manifest" % game)
            arm_strings.add(m.get("cand") or "")
            tl_path = os.path.join(d, "timelines", game + ".timeline.json")
            if not os.path.exists(tl_path):
                continue                       # swept but undumped: not a zero
            try:
                teams = json.load(open(tl_path))["game"]["teams"]
            except Exception:
                raise SweepRefused("unreadable timeline %s" % tl_path)
            wk_team = teams.get(WK)
            rows.append({"game": game, "run": os.path.basename(d.rstrip("/")),
                         "seed": m.get("seed", "?"), "side": side,
                         "wk_team": wk_team if wk_team is not None else "-",
                         "layer": LAYER_OF_SIDE[side],
                         "armed": wk_team == TEAM_OF_SIDE[side]})
            leg = (rows[-1]["armed"], rows[-1]["layer"])
            prev = seen_names.get(game)
            # A collision is REPORTED, never resolved silently -- and a
            # same-leg collision is reported too: two distinct games sharing a
            # name is a fact about the corpus whether or not it changed a cell.
            rows[-1]["dup"] = prev is not None
            if prev is not None:
                rows[-1]["dup_of"] = prev
            seen_names[game] = os.path.abspath(tl_path)
            if wk_team is None:
                continue                       # no Wraith King in this draft
            paths.append(tl_path)
            legs[os.path.abspath(tl_path)] = leg
    if not arm_strings:
        raise SweepRefused("the sweep dirs carry no games at all")
    if len(arm_strings) > 1:
        raise SweepRefused("the sweep dirs mix %d different candidate strings; "
                           "pooling them would average two different trees"
                           % len(arm_strings))
    arms = list(arm_strings)[0].split(",")
    if GATE_ID not in arms:
        raise SweepRefused("'%s' is not in this wave's candidate string (%d ids), "
                           "so its armed leg does not exist here"
                           % (GATE_ID, len(arms)))
    if not paths:
        raise SweepRefused("no swept game carries a Wraith King")
    return paths, legs, rows


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*", help="timeline .json files (dumper output)")
    ap.add_argument("--legs", help="tsv: <basename>\\t<armed 0|1>\\t<layer ab|ba>")
    ap.add_argument("--sweep", action="append", default=[],
                    help="a sweep_run.sh output dir: derives the timelines AND "
                         "the legs from games_manifest.jsonl (repeatable). The "
                         "hand-written --legs tsv was the only way to run this "
                         "tool until 2026-08-31, i.e. its readings were not "
                         "reproducible from the tree (GH #263).")
    ap.add_argument("--mr", default="auto",
                    help="magic resistance: 'auto' measures it off the blast's own "
                         "DAMAGE event per cast (default), or a fixed float (LIMIT 2)")
    ap.add_argument("--dead-window", type=float, default=6.0)
    ap.add_argument("--per-cast", action="store_true")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args()

    anchors = lua_anchors()
    if args.selfcheck:
        return EXIT_CLEAN if selfcheck(anchors) == 0 else EXIT_FINDINGS
    if anchors is None:
        print("REFUSED: could not parse X.wk_GetBlastKillDamage out of %s" % HERO_LUA)
        return EXIT_REFUSED
    sweep_rows = []
    if args.sweep:
        try:
            paths, sweep_legs, sweep_rows = from_sweeps(args.sweep)
        except SweepRefused as exc:
            print("REFUSED: %s" % exc)
            return EXIT_REFUSED
        args.timelines = list(args.timelines) + paths
        if args.legs:
            print("REFUSED: --sweep derives the legs; passing --legs too would "
                  "leave which one won invisible in the output")
            return EXIT_REFUSED

    if not args.timelines:
        print("REFUSED: no timelines")
        return EXIT_REFUSED

    mr_arg = None if str(args.mr).lower() == "auto" else float(args.mr)

    legs = {}
    if args.legs:
        for line in open(args.legs):
            p = line.split()
            if len(p) >= 3:
                legs[p[0]] = (p[1] == "1", p[2])
    if args.sweep:
        legs = sweep_legs
        print("legs derived from %d sweep dir(s) -- one row per game, audit them:"
              % len(args.sweep))
        print("  %-28s %-8s %-8s %-8s %-10s %s" %
              ("game", "seed", "armedside", "wk_team", "-> leg", "run"))
        for r in sweep_rows:
            print("  %-28s %-8s %-8s %-8s -> %-7s %s%s" %
                  (r["game"], r["seed"], r["side"], r["wk_team"],
                   "%s/%s" % (r["layer"], "armed" if r["armed"] else "baseline"),
                   r.get("run", "?"), "   <- DUPLICATE NAME" if r.get("dup") else ""))
        print("  (%d game(s) carry no Wraith King and are excluded, not zeroed)"
              % sum(1 for r in sweep_rows if r["wk_team"] == "-"))
        dups = sum(1 for r in sweep_rows if r.get("dup"))
        if dups:
            # The census table below is keyed by PATH, so these are counted
            # separately and correctly.  The line exists because the games are
            # indistinguishable by name in every OTHER artefact (per-cast rows,
            # the fixture stamps, hand-written --legs tsvs), so a reader
            # quoting a game name out of this run needs the run tag too.
            print("  ⚠ %d game name(s) appear in more than one run dir -- a soak "
                  "game name is a wall-clock stamp, so distinct games COLLIDE.\n"
                  "    They are kept apart here (the legs map is keyed by path), "
                  "but quote game names with their run tag." % dups)

    agg = collections.defaultdict(lambda: collections.Counter())
    dropped_total, games, per_cast, lags = 0, 0, [], []
    for path in args.timelines:
        base = os.path.basename(path).replace(".json", "")
        # PATH first, name second: --sweep keys by path precisely because two
        # runs of one wave can produce the same game name (see from_sweeps).
        # The hand-written --legs tsv can only key by name, so it keeps that
        # lookup -- and inherits the collision it cannot see.
        leg = legs.get(os.path.abspath(path), legs.get(base))
        if leg is None:
            continue
        if args.sweep:
            # so a per-cast line names a game the reader can actually find
            base = "%s/%s" % (os.path.basename(
                os.path.dirname(os.path.dirname(os.path.abspath(path))))[-6:], base)
        armed, layer = leg
        key = (layer, "armed" if armed else "baseline")
        try:
            tl = json.load(open(path))
        except Exception:
            dropped_total += 1
            continue
        rows, dropped = scan(tl, anchors, mr_arg, args.dead_window)
        dropped_total += dropped
        games += 1
        agg[key]["games"] += 1
        for r in rows:
            agg[key]["casts"] += 1
            # counted on EVERY cast, not just the band ones: the base rate is
            # what says whether a zero in the band column is immunity or just
            # a corpus with no stale frames in it at all
            for sw in STALE_WINDOWS:
                if r["stale_%s" % sw]:
                    agg[key]["cast_stale_%s" % sw] += 1
            if r["qlvl"] == 1:
                agg[key]["q1"] += 1
                agg[key]["live48" if r["hero_level"] < 10 else "live8"] += 1
            if r["band"]:
                agg[key]["band"] += 1
                for sw in STALE_WINDOWS:
                    if r["stale_%s" % sw]:
                        agg[key]["band_stale_%s" % sw] += 1
                        if r["band_pair"]:
                            agg[key]["bp_stale_%s" % sw] += 1
                if r["band_pair"]:
                    agg[key]["band_pair"] += 1
                if r["in_range"]:
                    agg[key]["in_range"] += 1
                if r["band_pair"] and r["in_range"]:
                    agg[key]["hit"] += 1
                if r["band_pair"]:
                    # the outcome column is counted on band_pair ONLY: `band`
                    # alone is a sampling-phase coin flip (LIMIT 4), and an
                    # outcome hung off a coin flip is still a coin flip
                    for w in OUTCOME_WINDOWS:
                        agg[key]["bp_%s_%s" % (r["out_%s" % w], w)] += 1
                        agg[key]["bpd_%s_%s" % (r["dout_%s" % w], w)] += 1
                        if r["out_%s" % w] != r["dout_%s" % w]:
                            agg[key]["bp_disagree_%s" % w] += 1
                r["game"] = base
                per_cast.append((key, r))
            elif args.per_cast:
                r["game"] = base
                per_cast.append((key, r))
            # The lag census is taken over EVERY cast with two witnesses, not
            # just the band ones: the lag is a property of the RECORDING, not
            # of the lever, and band_pair is far too thin to characterise it
            # (W30 has exactly one).  It is therefore NOT a reading about
            # wkqdmg and must never be differenced armed-vs-baseline.
            if r["lag"] is not None:
                lags.append(r["lag"])

    print("wkqdmg domain census -- %d game(s), mr=%s, dead-window %.1fs, %d cast(s) dropped"
          % (games, args.mr, args.dead_window, dropped_total))
    print("shipped/armed claim ladder (hero lvl >=10): " +
          "  ".join("q%d %.1f/%.0f" % (q, claims(q, 12, anchors)[0], claims(q, 12, anchors)[1])
                    for q in (1, 2, 3, 4)))
    print()
    print("%-6s %-9s %6s %6s %5s %7s %6s %5s %9s %8s %4s" %
          ("layer", "leg", "games", "casts", "q1", "live48", "live8", "band",
           "band_pair", "in_rnge", "HIT"))
    for layer in ("ab", "ba"):
        for leg in ("armed", "baseline"):
            c = agg[(layer, leg)]
            print("%-6s %-9s %6d %6d %5d %7d %6d %5d %9d %8d %4d" %
                  (layer, leg, c["games"], c["casts"], c["q1"],
                   c["live48"], c["live8"], c["band"], c["band_pair"],
                   c["in_range"], c["hit"]))

    print()
    print("outcome of the band_pair casts -- did the target reach hp 0 anyway?")
    print("  died = ANY death, whoever dealt it (UPPER bound on kills the narrowing could cost)")
    print("  surv = observed alive at the far edge of the window (LOWER bound on free withdrawals)")
    print("  unk  = the witness ran out first; folded into NEITHER column")
    print("  TWO INDEPENDENT WITNESSES, PRINTED SIDE BY SIDE AND NEVER MERGED:")
    print("    hp.*  sampled hp<=0, identity-locked to the cast frame's idx (1 Hz grid)")
    print("    ev.*  DEATH combat-log events, NOT identity-locked (names only)")
    print("    The disagreement has BOTH signs -- the event can lead the health")
    print("    bar (sampling lag) or trail it (late combat-log entry) -- so")
    print("    neither column refines the other and 'dis' is a reading, not an error.")
    print("%-6s %-9s %5s %10s %16s %16s %5s  %s" %
          ("layer", "leg", "N(s)", "band_pair",
           "hp: died/surv/unk", "ev: died/surv/unk", "dis", "interpretable"))
    for layer in ("ab", "ba"):
        for leg in ("armed", "baseline"):
            c = agg[(layer, leg)]
            note = ("yes" if leg == "baseline" else
                    "NO (armed leg: band_pair cannot come from the kill-confirm branch)")
            for w in OUTCOME_WINDOWS:
                print("%-6s %-9s %5.1f %10d %16s %16s %5d  %s" %
                      (layer, leg, w, c["band_pair"],
                       "%d/%d/%d" % (c["bp_died_%s" % w], c["bp_surv_%s" % w],
                                     c["bp_unk_%s" % w]),
                       "%d/%d/%d" % (c["bpd_died_%s" % w], c["bpd_surv_%s" % w],
                                     c["bpd_unk_%s" % w]),
                       c["bp_disagree_%s" % w],
                       note if w == OUTCOME_HEADLINE_S else ""))

    print()
    print("stale victims -- was the band frame's target ALREADY dead per the combat log?")
    print("  DOMAIN column, not an outcome one: a corpse the 1 Hz health bar has not")
    print("  caught up with reads as a live target sitting inside the 48-ehp band, so a")
    print("  stale frame does not miscount a band cast -- it MANUFACTURES one.")
    print("  LOWER BOUND: a frame with no confirming sample after it is not counted.")
    print("  The `bp` column is the test of LIMIT 4's own claim: `band_pair` should")
    print("  reject a stale victim for free (the frame after is where hp reaches 0).")
    print("  Headline window %.1fs = one sampling interval (registered choice)."
          % STALE_HEADLINE_S)
    print("%-6s %-9s %5s %6s %6s %10s %11s %10s  %s" %
          ("layer", "leg", "N(s)", "casts", "band", "band_pair",
           "stale casts", "of them band", "...and band_pair"))
    for layer in ("ab", "ba"):
        for leg in ("armed", "baseline"):
            c = agg[(layer, leg)]
            for sw in STALE_WINDOWS:
                print("%-6s %-9s %5.1f %6d %6d %10d %11d %10d  %d" %
                      (layer, leg, sw, c["casts"], c["band"], c["band_pair"],
                       c["cast_stale_%s" % sw], c["band_stale_%s" % sw],
                       c["bp_stale_%s" % sw]))

    print()
    print("witness lag census -- (DEATH event t) minus (first sampled hp<=0 t), over")
    print("  EVERY cast with both witnesses inside %.0fs, band or not.  This is a" % LAG_PROBE_S)
    print("  property of the RECORDING, not of the lever: do NOT difference it")
    print("  armed-vs-baseline, and do not read it as an effect size.")
    if lags:
        srt = sorted(lags)
        neg = sum(1 for v in srt if v < 0)
        pos = sum(1 for v in srt if v > 0)
        # 铁律 4(ii): a small-range quantity gets mean + distribution + the
        # share past the threshold that matters, never a bare median.
        big = sum(1 for v in srt if abs(v) >= 1.0)
        print("  n=%d   ev BEFORE hp %d (%.0f%%) | equal %d | ev AFTER hp %d (%.0f%%)"
              % (len(srt), neg, 100.0 * neg / len(srt), len(srt) - neg - pos,
                 pos, 100.0 * pos / len(srt)))
        print("  min %+.1fs  median %+.1fs  mean %+.1fs  max %+.1fs   |lag| >= 1.0s: %d (%.0f%%)"
              % (srt[0], srt[len(srt) // 2], sum(srt) / len(srt), srt[-1],
                 big, 100.0 * big / len(srt)))
        print("  A NEGATIVE lag is the one that bites the hp column's SHORT rungs:")
        print("  the combat log already said dead while the 1 Hz grid had not")
        print("  sampled hp<=0 yet, so `out_2.0` can read `surv` -- an OBSERVED-")
        print("  alive claim -- for a hero the log says was already dead.")
    else:
        print("  n=0 -- no cast in this corpus had both witnesses; nothing is claimed.")

    if per_cast:
        print("\nper-cast:")
        for key, r in sorted(per_cast, key=lambda kr: (kr[0], kr[1]["t"])):
            print("  %-4s %-8s %-30s t=%7.1f wk=%2d q%d %-16s hp %4d->%-4s "
                  "ehp %6.1f->%-6s mr=%.3f(%s) claims %.1f/%.0f d=%5.0f %s"
                  % (key[0], key[1], r["game"], r["t"], r["hero_level"], r["qlvl"],
                     r["target"].replace("npc_dota_hero_", ""), r["hp"],
                     r["hp_after"] if r["hp_after"] is not None else "-",
                     r["ehp"],
                     ("%.1f" % r["ehp_after"]) if r["ehp_after"] is not None else "-",
                     r["mr"], r["mr_src"][0], r["shipped"], r["armed"], r["dist"],
                     # --per-cast appends EVERY cast, not just band ones, so
                     # the third state has to exist: before 2026-08-31 a cast
                     # at ehp 931 (five times the shipped claim) printed
                     # "band(before only)", which is a label that lies about
                     # the one thing this file is counting.
                     ("BAND_PAIR" if r["band_pair"] else
                      "band(before only)" if r["band"] else "not in band")
                     # the stale flag rides on the cast line because the whole
                     # point of the column is that the reader can go find the
                     # frame; a count with no way back to the instant is the
                     # thing GH #361 was filed about
                     + ("  STALE<=%gs" % STALE_HEADLINE_S
                        if r["stale_%s" % STALE_HEADLINE_S] else
                        "  stale<=%gs" % STALE_WINDOWS[-1]
                        if r["stale_%s" % STALE_WINDOWS[-1]] else "")))
            print("        outcome hp %5.1fs=%-4s (2s=%-4s 10s=%-4s)  target hp after: %s"
                  % (OUTCOME_HEADLINE_S, r["out_%s" % OUTCOME_HEADLINE_S],
                     r["out_2.0"], r["out_10.0"],
                     " ".join("%d" % hp for hp in r["traj"]) or "(no samples)"))
            print("        outcome ev %5.1fs=%-4s (2s=%-4s 10s=%-4s)  DEATH events: %s  lag=%s"
                  % (OUTCOME_HEADLINE_S, r["dout_%s" % OUTCOME_HEADLINE_S],
                     r["dout_2.0"], r["dout_10.0"],
                     " ".join("+%.1f" % (ts_ - r["t"]) for ts_ in r["death_ev"]) or "(none)",
                     ("%+.1fs (ev %s hp)" % (r["lag"], "AFTER" if r["lag"] > 0 else "before"))
                     if r["lag"] is not None else "n/a (only one witness)"))

    armed_hits = agg[("ab", "armed")]["hit"] + agg[("ba", "armed")]["hit"]
    if armed_hits:
        print("\nFINDINGS: %d armed-leg cast(s) in the band on BOTH straddling frames "
              "and inside branch reach (BUGGY CANDIDATE -- LIMIT 1 before calling it that)"
              % armed_hits)
        return EXIT_FINDINGS
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())
