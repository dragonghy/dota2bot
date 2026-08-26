#!/usr/bin/env bash
# One command every routine trigger runs at 开工, before claiming any work.
#
# WHY THIS EXISTS -- and it is not the reason GH #113 gives.
#
# #113 reported three rounds on 2026-08-22 whose output never reached `main`,
# and diagnosed the first (hero 08:00Z) as STRUCTURALLY invisible to
# `unlanded_commits.py`, on the grounds that it "never pushed, not even a
# branch".  Measured at 12:5xZ that day, that is false: the 08:00Z tree is on
# `origin/claude/vibrant-heisenberg-3os6d0` as `eda1257` (committed 08:39:10Z),
# with the SAME EIGHT FILES the 10:00Z round then rebuilt from scratch.
#
# So the detector built at 03:00Z would have found all three shapes.  Nobody ran
# it.  The 10:00Z round paid a full trigger to re-derive work that was sitting on
# a remote branch, and the 12:00Z round paid again to land it.
#
# A detector nobody runs is the dead S3 lifecycle rule of test_set.md Z.4: on the
# books, matching nothing.  This wrapper is the cheap half of the fix -- the
# half that makes the checks happen.
#
# Exit 0 clean, 2 uncertifiable, 3 findings.  Findings are a QUESTION (see each
# tool's LIMITS): an OFF-TRUNK branch may be work already relanded under a
# different SHA, and a cadence GAP may be a trigger that legitimately had
# nothing to file.  Look before concluding -- but LOOK.
#
# Usage:  bash tools/agent/routine_selfcheck.sh [--comments <gh-comments.json>]
set -u
cd "$(dirname "$0")/../.."

extra=()
while [ $# -gt 0 ]; do
    case "$1" in
        --comments) extra+=(--comments "$2"); shift 2 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

worst=0
note() { [ "$1" -gt "$worst" ] && worst="$1"; return 0; }

printf '=== unlanded work (pushed to a branch, never landed) ===\n'
python3 tools/agent/unlanded_commits.py --fetch
note $?

printf '\n=== report cadence + published citations ===\n'
python3 tools/agent/citation_audit.py --cadence --fetch "${extra[@]+"${extra[@]}"}"
note $?

# Is trunk itself red?  Added 2026-08-22T14:5xZ (director), after GH #116: a
# tool landed at 13:15Z re-introduced `team_slot % 5 + 1` -- a hero->position
# rule this repo had already MEASURED at 47.3% accuracy (GH #57), retired, and
# ratcheted against -- and shipped a creeppull (a)-verdict built on it.  The
# ratchet caught it within 100 minutes and sat red on `origin/main`; the only
# missing step was somebody running the suite.
#
# That is the same shape as this wrapper's own reason for existing (a detector
# nobody runs), so it belongs in the same 开工 command.  The whole py suite is
# 11 files and runs in seconds -- cheap enough that "is main red right now?"
# stops depending on who happens to reach their push gate first.
#
# A red here is a QUESTION like the others -- it may be someone else's in-flight
# breakage, not yours -- but LOOK.
#
# This block USED to end "NOT the Lua suite: that one needs lua5.1 + minutes,
# and is the push gate's job (README rule 6), not 开工's."  That exemption cost
# a red trunk on 2026-08-24T22:55Z (1d41fb1, strategy): a fresh corpus-size pin
# reddened tests/test_corpus_scale.lua's detector, and it sat red on origin/main
# for ~5 hours across five stream triggers -- batch-desk 00:19Z, strategy
# 01:24Z, replay-check 01:35Z, hero 01:51Z, batch-desk 03:12Z -- every one of
# which ran THIS script and got a clean trunk-health line, because the leg it
# ran was the python one.
#
# That is GH #116's shape for the third time, and the second time in this very
# file: "the ratchet caught it; the only missing step was somebody running the
# suite."  The exemption's premise was also wrong in the half that mattered --
# the whole Lua suite is minutes, but the detectors are NOT.  They read the tree
# instead of loading fixtures: 8 files / 78 checks / 4.9s measured, against a
# ~48-minute full suite (the 00:5xZ full run measured 3h01m / 1796 tests).
# The push gate still owns the full suite; 开工 now owns the tree-scanning
# subset, which is exactly the subset ANYONE'S landing can redden.
#
# Discovery is by tag, not by list, so it cannot rot: a test named
# `[detector] ...` or `[ratchet] ...` is picked up the day it is written.  Four
# tree-scanners predate the convention and are named explicitly; tag new ones
# rather than extending that list.
#
# WHY `[census]` IS NOT A DISCOVERY TAG, though it names the same kind of claim.
# The four reds that were actually sitting on origin/main on 2026-08-25 were
# test_corpus_scale (1), test_level_gate_census (2), and test_wk_fact_anchor
# (1).  Covering all four is the goal, and `[census]` looked like the way to
# reach the middle one -- but the tag marks what a test CLAIMS, not what it
# COSTS, and adding it drags in the sweep family of GH #124: measured, the
# tagged set went from 4.2s to **7m08s**, which is not a 开工 check any more.
# So the two fast ones are named instead (276ms and 345ms), and the tag set
# stays the two that have never cost more than milliseconds.  If you are about
# to add a tag here, TIME the resulting set first.
#
# LIMIT -- the runtime is a property of TODAY'S members, not of the tag.  Four
# files in tests/ take >25s just to LOAD (their top-level sweeps run at require
# time: test_creeppull_zone_clause, test_fieldcreep_veto,
# test_fightback_world_assertion, test_towerfear_clock_leg).  None of them is
# tagged today.  If one ever is, 开工 gets that cost silently and every trigger
# pays it.  Deliberately NOT guarded with a per-file timeout: a timeout would
# report a slow detector as a red one, and a false TRUNK RED is worse than a
# slow selfcheck -- it is the thing that teaches people to ignore the line.  If
# the count below stops being seconds, move the slow file's sweep behind a
# function instead of dropping it from the set.
# Added 2026-08-25T13:xxZ (director), after test_set.md §BF.0.  §BB.4 says a
# rideshare admission proposal must be approved or returned in the round it
# arrives, because its only cost is not being ruled.  Measured at 13:xxZ, that
# rule's enforcement record since it was written was 0/6: `campsel` had sat
# un-ruled for four rounds, `tpgap`/`tbearly`/`tpdeathbuy` for three.
#
# Nothing was broken and nobody was told, because the 待裁区 of test_set.md is
# prose and prose does not raise its hand -- an empty `director` field appeared
# in no selfcheck output, and the batch desk's full-set waves ran fine six ids
# short without an error, a lost game, or a missing verdict.
#
# Same shape as this wrapper's own header (a detector nobody runs), one step
# earlier: a detector nobody WROTE.  Cheap -- it reads one JSON file.
#
# It is a QUESTION like the others (see the tool's LIMITS): an un-ruled request
# may be legitimately parked behind a wave slot that does not exist yet, and
# `RECEIVED_NOT_SCHEDULED` is a real ruling this tool cannot tell from silence.
# But LOOK.
printf '\n=== un-ruled queue requests (director field) ===\n'
if command -v python3 >/dev/null 2>&1; then
    python3 tools/agent/pending_rulings.py --no-age
    note $?
else
    printf 'SKIP (no python3)\n'
fi

# Added 2026-08-26T01:0xZ (director).  The director charter's 『下次触发』 list
# carried "stable-v1/stable-v2 打 tag" for TEN consecutive rounds, each round
# deferring it as not-done.  Measured on 08-26: both refs had been on `origin`
# the whole time, and `stable-v1` pointed at exactly the right commit.  What did
# not exist was a *tag* -- and this container's credentials cannot push one
# (refs/tags/* is a hard HTTP 403; the same session, same credentials, pushes
# branches fine).  So the deferred action was also un-doable.
#
# The root cause is one level earlier than the wrapper's other checks: not "a
# detector nobody runs" and not "prose that does not raise its hand", but a
# WRONG CRITERION.  Every round answered "is the anchor built?" with `git tag
# -l`, which is empty by construction, and a wrong criterion never raises its
# hand either.  Ten rounds of a director trigger went to a question that a
# 2-second read answers.
#
# It is a QUESTION like the others (see the tool's LIMITS): a MOVED anchor may
# be a legitimate relocation, and in a shallow container invariant 3 comes back
# UNCERTIFIABLE rather than ok.  But LOOK.
printf '\n=== stable version anchors (铁律 3) ===\n'
if command -v python3 >/dev/null 2>&1; then
    python3 tools/agent/stable_anchors.py
    note $?
else
    printf 'SKIP (no python3)\n'
fi

printf '\n=== trunk health (python test suite) ===\n'
if command -v python3 >/dev/null 2>&1; then
    if suite=$(bash tests/run_py_tests.sh 2>&1); then
        printf '%s\n' "$suite" | tail -1
    else
        printf '%s\n' "$suite" | grep -E '^(FAIL|failed:|[0-9]+ passed)' || true
        printf 'TRUNK RED -- a test is failing before you changed anything.\n'
        note 3
    fi
else
    printf 'SKIP (no python3)\n'
fi

printf '\n=== trunk health (fast Lua detectors) ===\n'
if command -v lua5.1 >/dev/null 2>&1; then
    # By tag, so a detector written tomorrow is covered without editing this
    # file.  The four trailing names predate the tag convention (see the
    # `[census]` note above for why the last two are named and not tagged).
    files=$( { grep -l '\[detector\]\|\[ratchet\]' tests/test_*.lua 2>/dev/null
               ls tests/test_gate_claim_consistency.lua \
                  tests/test_data_consistency.lua \
                  tests/test_level_gate_census.lua \
                  tests/test_wk_fact_anchor.lua 2>/dev/null
             } | sort -u )
    ran=0 red=0
    for f in $files; do
        ran=$((ran + 1))
        if ! out=$(lua5.1 tests/run_tests.lua "$(basename "$f")" 2>&1); then
            red=$((red + 1))
            printf '%s\n' "$out" | grep -E '^(FAIL:|      )' | head -4
        fi
    done
    if [ "$ran" -eq 0 ]; then
        # Discovery matching nothing is the dead-lifecycle-rule failure this
        # wrapper's own header warns about: on the books, matching nothing.
        printf 'NO DETECTORS FOUND -- discovery matched 0 files; the tag or the paths moved.\n'
        note 3
    elif [ "$red" -gt 0 ]; then
        printf 'TRUNK RED -- %d of %d Lua detector file(s) failing before you changed anything.\n' \
            "$red" "$ran"
        note 3
    else
        printf '%d detector file(s), 0 failures\n' "$ran"
    fi
else
    printf 'SKIP (no lua5.1 -- apt-get install lua5.1)\n'
fi

printf '\nselfcheck worst exit: %d\n' "$worst"
exit "$worst"
