# `tpdying` — condition (a) evidence (owed_executions row `a_evidence_tpdying`, GH #35)

**Executor**: replay-check(录像组) · **Produced**: 2026-09-06T04:04Z
**Ruling this discharges**: 总监 2026-09-05T22:xxZ, `iterations/streams/test_set.md` §FB.2 上半行 / §FB.5 第 1 条.

`VERIFY id=tpdying verdict=INDETERMINATE episodes=4527`

The two detectors §A'.3 constraint 3 named **did not exist** — that is why (a)
was unbought for 17 armed days. Both are built and run below, on a large and
richly occupied domain, and **both read 4/4 seeds in the direction the source
predicts**. The verdict is INDETERMINATE anyway, and §6 says exactly why: the
signal cannot be separated from `tpcommit`/`tpdead`, which act on the same
population in the same wave.

---

## 1. Wave, corpus, coverage

| | |
|---|---|
| Wave | **W49**, launched 2026-09-05T21:19:57Z, `--ref` pinned to `066219d61009c35357de49cfe3e8521940b09109` |
| Seeds | 5404, 5502, 5574, 5705 |
| Games | **72/72 scored games swept**, 24 warm-up skipped, **unparseable 0** |
| Sweeps | `sweep_run.sh` ×4, `SWEEP_EXIT=0` ×4 |
| Game-legs in the census | **70** |
| Response-TP landings examined | **4,527** |
| AWS | S3 **read-only**. Zero EC2, zero new wave, zero Cost Explorer. |

⛔ **No gpm/xpm is used anywhere in this file** (§A'.3 constraint 3).

## 2. ⭐ Reachability — checked first, because this id has the shape that hides a zero

`tpdying`'s clause sits **inside** `J.GetTpCommitDefendDesire`, whose second
line is `if not J.IsSoakCandidate( 'tpcommit' ) then return nil end`
(`bots/FunLib/jmz_func.lua:8913`, clause at `:8958`). **Armed alone, `tpdying`
is byte-for-byte inert** (§A'.4).

This is the **converse of the `suptp` finding of 2026-09-06**: there an
`A or B` disjunction made `B` weightless *because* `A` was co-armed; here an
enclosing gate makes this id weightless *unless* its partner **is** co-armed.
Common shape: **whether an id has any effect depends on another id in the same
arm string, while the verdict is booked against the single id.**
`check_armed_wiring.py` calls both WIRED and is right to — its LIMITS say it
checks that a call site exists, not that the predicate can be true.

**Verified for W49**: `git show 066219d6:iterations/streams/test_set.md` line 2
carries `tpcommit` (position 5) *and* `tpdying` (position 6) of 61 ids. The new
tool refuses to print a reading at all if `tpcommit` is absent
(`--assert-arm`), rather than emitting a clean-looking zero:

```
reachability VERIFIED: both `tpdying` and its enclosing `tpcommit` gate are armed in this wave (61 ids)
```

## 3. The two detectors §A'.3 named — built this round

New tool: **`tools/batch_test/behavioral/tpdying_release.py`**
(`--selfcheck`: **23 PASS / 0 FAIL, exit 0**).

**Domain — "a response TP landing".** The three stamp sites
(`ability_item_usage_generic.lua:5207` gated rescue, `:5229` gated `midtp`
tower-fight, `:5412` the **shipped** defend TP) all write
`bot.tpRespondUntil = DotaTime() + 12.0`. Their observable signature: the
channel **completed** (`modifier_teleporting` MODIFIER_REMOVE, then the hero is
elsewhere), the destination is **not** the bot's own fountain (a retreat TP goes
home; all three response branches do not), and the trip is longer than the
shipped defend TP's own floor `nMinTPDistance - 500 = 5000 u`.

* **Detector (1)** — "death rate within 10 s of a response TP landing".
  Anchored on **DEATH events**, never on an interpolated `hp_pct` (GH #176 ②)
  and never on "did he jump to the fountain": Wraith King reincarnates in place
  (charter 2026-08-21), and he is exactly the kind of hero a response TP is.
* **Detector (2)** — "frames still pinned in DEFEND after landing". There is no
  bot-mode field in the dump, so this is a **positional proxy**: post-landing
  snapshots inside the 12 s commitment window in which the hero is still within
  `--pin-radius` of the point he landed on. The release lets the promoted
  retreat (which the 0.85 floor was outbidding) win, and a released responder
  walks away. Reported at **three radii** so the reading cannot be a property of
  one radius, plus an independent companion — **median drift at +12 s** — which
  asks the same question as a distance instead of a count.

**Predicted direction, fixed by the source before measuring**: the clause can
only ever `return nil` sooner — it can never raise or create a pin (pinned in
the selfcheck). So armed ⇒ **fewer** pinned frames, **more** drift, and if the
release is worth anything, a **lower** post-landing death rate.

## 4. Iron rule 4(i-a): both strata, always

| stratum | leg | landings | died ≤10 s | death/landing | pinned frames | pinned/landing |
|---|---|---|---|---|---|---|
| radiant | armed | 1262 | 32 | 0.0254 | 8785 | 6.96 |
| radiant | baseline | 1431 | 50 | 0.0349 | 9758 | 6.82 |
| dire | armed | 986 | 15 | 0.0152 | 6588 | 6.68 |
| dire | baseline | 848 | 21 | 0.0248 | 6136 | 7.24 |

Per-stratum leg deltas (armed − baseline):

| quantity | radiant | dire | strata agree? |
|---|---|---|---|
| death rate / landing | **−0.0096** | **−0.0096** | **yes** |
| pinned frames / landing (r=1200) | +0.142 | −0.554 | **no** |

⚠️ The pinned-frame count **flips sign between the strata on this table**, and
is registered as such. The flip is not a radius artifact — it reproduces at
r=800, 1200 and 1600.

## 5. Per-seed swap-average (4(i-c)) — the estimator with the side bias removed

Printed by the tool itself (`by_seed`), not hand-computed — 4(i-d)'s lesson is
that six rounds satisfied the disclosure rule with the wrong hand-made
quantity. Arithmetic mean across seeds, **never weighted by landings or games**.

| quantity | seed 5404 arm | 5502 | 5574 | 5705 | **mean arm** | seeds in predicted direction |
|---|---|---|---|---|---|---|
| **(1)** death rate /landing — predict DOWN | −0.0022 | −0.0045 | −0.0023 | −0.0245 | **−0.0084** | **4/4** |
| **(2)** pinned frames /landing r=1200 — predict DOWN | −0.145 | −0.372 | −0.028 | −0.290 | **−0.2089** | **4/4** |
| companion: median drift at +12 s — predict UP | +65.3 | +277.0 | +107.0 | +61.5 | **+127.7 u** | **4/4** |

The §4 sign flip on detector (2) is the identity `|side| > |arm|` and not a
diagnosis (4(i-c)): once each seed's ab and ba are swap-averaged, all four
seeds move the same way, on all three quantities.

Relative size of detector (1): baseline post-landing death rate ≈ 3.0 %, and
the swap-averaged reduction is −0.84 pp — roughly a **28 % relative** drop in
deaths within 10 s of landing.

## 6. ⛔ Why this is INDETERMINATE and not WORKING — attribution (charter 4a)

**The armed leg carries 61 ids, and three of them act on this exact population:**

* **`tpcommit`** *creates* the pin. Off the candidate, `GetTpCommitDefendDesire`
  returns nil on its second line, so the **baseline leg has no pin at all** —
  its "pinned frames" are just heroes standing where they landed.
* **`tpdead`** is a *second release* of the same pin, on the rescue branch
  (`bot.tpRespondAlly` dead), written into the same function eight lines below.
* **`teambrain`** arbitrates the shipped defend TP itself (`J.ShouldAllowDefendTp`,
  `:5398`) — it changes *which* landings exist, i.e. the denominator.

So `armed − baseline` here is the **net of pin creation and both releases,
plus a moved denominator** — a bundle differential. Charter 4a is explicit that
a single aggregate differential may not be booked to one id, and this one has a
sharper problem than usual: **`tpcommit` pushes pinned frames UP and the two
releases push them DOWN**, so even the *sign* of the observed −0.209 does not
decompose without an isolation leg.

The reading is therefore recorded as **evidence about the response-TP landing
population under the 61-id bundle**, which is what it is, and **not** as
`tpdying`'s trigger-level (a).

**What would settle it**, cheapest first:

1. **An isolation leg** — one wave with `tpcommit` armed and `tpdying` **not**,
   against the same seeds. This is the only clean separation, and it costs a
   batch wave (batch desk's money, not the replay desk's call). Filed as an
   issue this round.
2. **A trigger-level detector** (charter 4a's own prescription: buy (a) at the
   trigger, frame by frame) — reconstruct `J.IsIncomingBurstLethal( bot, 3.0 )`
   on the landing frames and check that the armed leg walks away on exactly the
   frames where it is true while the baseline leg stays. Offline reconstruction
   of that predicate is the known-hard case the charter warns about
   (`IsFullyCastable` includes mana, 2026-08-20), so this is real work, not a
   free alternative.

## 7. What is settled, and is worth keeping

Three things this file buys outright, independent of the attribution problem:

1. **The two detectors §A'.3 demanded now exist and are self-checked.** Their
   absence is the whole reason this id sat armed for 17 days with verify=0.
2. **The domain is richly occupied** — 4,527 landings over 70 game-legs. A future
   SILENT verdict for this id can never be blamed on scenario scarcity.
3. **The reachability trap is now mechanised.** `--assert-arm` makes it
   impossible for a later round to report a clean zero for `tpdying` from a wave
   in which `tpcommit` was not armed.

## 8. Reproduction

```bash
python3 tools/batch_test/behavioral/tpdying_release.py --selfcheck   # 23 PASS / 0 FAIL
ARM=$(git show 066219d6:iterations/streams/test_set.md | sed -n '2p')
python3 tools/batch_test/behavioral/tpdying_release.py \
        --label "W49 (4 seeds, 72 scored games)" --assert-arm "$ARM" \
        --out rows.jsonl <sweep_out>/*/
```

## 9. Note for the director

`tpdying` is currently **out of the set** (退集 2026-09-05, 61 → 60). §FB says
the retraction was not a reject and did not destroy the ability to buy (a).
This file is the attempt, and it lands one step short of (a) for a reason that
was **built into the id at admission**, not created by this round: an id whose
gate is nested inside another id's gate cannot have its own (a) bought from an
all-on mirrored wave. That is a general property, not a fact about `tpdying` —
worth checking against the rest of the set before the next admission.
