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

# --- refusal: stdout is a PIPE ---------------------------------------------
# [director 20260831, charter backlog 22] Discipline 3 ("never measure an exit
# code through a pipe") recurred FIVE times, and every single site is the same
# command in the same slot -- the FIRST command of the round:
#
#     bash tools/agent/routine_selfcheck.sh 2>&1 | tail -60   -> harness says 0
#
# That 0 is `tail`'s.  Three consecutive rounds wrote "next trigger: no `| tail`"
# into the charter and three consecutive rounds broke it, so the charter retired
# the reminder as a fix: the command is typed BEFORE the charter is read, which
# is precisely the window a note cannot reach.  rc.sh (built 08-31T04:2xZ) is
# the shorter correct path, and it did not help for the same reason.
#
# So the guard has to live where the defect happens: here, at the moment of the
# call, in the one process that can still see the shape.
#
# THE DISCRIMINANT IS "FIFO", NOT "NOT A TTY".  The charter flagged the risk
# that a legitimate redirect would be caught; measured, the two are cleanly
# separable and the naive `[ -t 1 ]` test would indeed have been wrong:
#
#     cmd | tail        -> /dev/stdout is a FIFO      <- the defect
#     cmd > file        -> /dev/stdout is a REGFILE   <- legitimate
#     bare (harness)    -> /dev/stdout is a REGFILE   <- legitimate
#     $(cmd)            -> /dev/stdout is a FIFO      <- safe, but not separable
#
# KNOWN FALSE POSITIVE, stated rather than papered over: the last row.  Command
# substitution and `subprocess.run(capture_output=True)` are pipes that DO read
# the true exit code, and nothing visible from inside this process tells them
# apart from `| tail`.  They take the env opt-out below.  Measured cost of that
# today: ZERO call sites -- no test executes this wrapper (the three that touch
# it run slices, `HARNESS_PRE + LEG_SRC`, or read it as text), and no script in
# the repo pipes it.
#
# WHY REFUSE INSTEAD OF WARN.  A warning is the fourth reminder, and reminders
# are what the charter just retired.  A refusal costs the round a re-run, which
# is a consequence rather than a note.  It is placed before any leg runs so the
# whole message is a handful of lines -- meaning it survives even `| tail -1`,
# the very habit it exists to defeat.  Exit 2 = could-not-run (rule 10's
# vocabulary, same as run_py_tests.sh and the push gate): a refusal is NOT a
# pass, and must never be recorded as a clean self-check.
if [ -z "${SELFCHECK_PIPE_OK:-}" ] && [ -p /dev/stdout ]; then
    # ORDER IS LOAD-BEARING, and the acceptance test caught it being wrong.
    # The stderr copy goes FIRST.  Under `2>&1 | tail -1` both streams land in
    # one pipe, so whichever is written last is the line the reader sees -- and
    # the line that must survive is the VERDICT, not this aside.  Emitting the
    # aside first leaves `SELFCHECK_EXIT=2` as the final line, which is the one
    # property this whole guard exists to deliver.
    #
    # This copy is here for the OTHER shape: `| tail` written WITHOUT `2>&1`,
    # where stderr bypasses the pipe and reaches the harness directly.
    printf 'REFUSED: routine_selfcheck.sh stdout is a pipe; exit 2, nothing checked.\n' >&2
    # To stdout: that is the channel inside the pipe, so it reaches the reader
    # whether or not they wrote `2>&1`.
    printf 'REFUSED: stdout is a PIPE, so the exit code your harness reports is\n'
    printf '         the READER'"'"'s (tail/head almost always succeed), not this\n'
    printf '         script'"'"'s. This is evidence discipline 3; it has recurred 5x,\n'
    printf '         every time as the first command of the round.\n'
    printf '\n'
    printf 'Use either of these instead:\n'
    printf '  bash tools/agent/rc.sh bash tools/agent/routine_selfcheck.sh\n'
    printf '  bash tools/agent/routine_selfcheck.sh > /tmp/sc.log 2>&1; echo "EXIT=$?"\n'
    printf '\n'
    printf 'If your caller really does read the true exit code (command\n'
    printf 'substitution, subprocess capture), set SELFCHECK_PIPE_OK=1.\n'
    printf 'SELFCHECK_EXIT=2  REFUSED (nothing was checked; this is NOT a pass)\n'
    exit 2
fi

extra=()
while [ $# -gt 0 ]; do
    case "$1" in
        --comments) extra+=(--comments "$2"); shift 2 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# [director 20260828, GH #267 4b] The tally moved out to
# tools/agent/selfcheck_tally.sh so that a leg's exit level is recorded WITH THE
# LEG THAT RAISED IT.  `note` keeps its name and its signature -- every call
# site below is unchanged -- but each leg now announces itself with `sc_leg`
# first, and the tail prints the breakdown.  The reason is in that file's
# header: for ~22 hours a real trunk red and a long-standing cadence gap were
# the same integer, and every report in the window attributed the 3 to cadence
# BY HAND.
#
# Sourced with a leading `./` for the same reason try_install_lua51 is: the
# lua-leg test runs a slice of this file with an empty PATH, and a bare-name `.`
# would search PATH and find nothing.  The wrapper cd's to the repo root above.
. ./tools/agent/selfcheck_tally.sh
note() { sc_note "$1"; }

# [director 20260826, GH #171] A leg that DID NOT RUN is uncertifiable, not
# clean.  Every `SKIP (no python3)` below used to be one unremarkable line with
# no effect on the exit code -- i.e. indistinguishable from a clean read in BOTH
# channels a reader has.  That is the same defect GH #171 measured on the Lua
# leg (see its long note further down), one dependency over.
unchecked() {
    printf 'UNCERTIFIABLE -- %s did NOT run (no python3). This line is NOT a pass.\n' "$1"
    note 2
}

# [director 20260826, GH #213] FIRST, because a leg that dies later must not
# take the arming with it -- and because this leg is the cheap one: it runs
# nothing, it sets one local git config key so that `git push` runs rule 6's
# static gate (tools/agent/luacheck_gate.sh) instead of relying on the pusher
# remembering.  The body lives in tools/agent/arm_push_gate.sh (bounded,
# guarded, loud on failure); this stays a two-line delegation for the same
# reason try_install_lua51 did -- one copy of the properties, asserted once.
#
# Not the fifth leg GH #205 rejected: that one would have RUN luacheck at 开工,
# on an unchanged tree, answering a different question than rule 6 asks.  This
# arms; the 13s still costs at the push, where it belongs.
sc_leg 'push-gate'
printf '=== iron rule 6 push gate (arm for this container) ===\n'
bash tools/agent/arm_push_gate.sh || note 2

sc_leg 'unlanded'
printf '\n=== unlanded work (pushed to a branch, never landed) ===\n'
python3 tools/agent/unlanded_commits.py --fetch
note $?

sc_leg 'cadence'
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
sc_leg 'queue-rulings'
printf '\n=== un-ruled queue requests (director field) ===\n'
if command -v python3 >/dev/null 2>&1; then
    python3 tools/agent/pending_rulings.py --no-age
    note $?
else
    unchecked 'the un-ruled-queue check'
fi

# Added 2026-08-28T19:xxZ (strategy).  The leg above watches ONE end of the
# delivery path -- a request nobody ruled.  The other end had nothing on it:
# a stream still recording "等总监裁 `X` 入集(仍挂着)" after that ruling
# landed.
#
# Measured founding case: `campexit` was admitted at 06:5xZ and commit
# `e7e57979` put it in `test_set.md` line 2; the strategy charter then carried
# "`campexit` 入集裁定仍欠" in FOUR consecutive 当前状态 entries, and the first
# of them printed `开工 HEAD == e7e5797` -- the ruling commit -- in its own
# report.  The leg above ran in all four rounds and said `un-ruled: none`,
# truthfully: the wait was never a queue request, so the instrument that
# reports pending rulings could not see it, and nobody reconciled the two.
#
# The cost is not the sentence.  Two of those rounds picked their work unit by
# reading their own 下一格 as 阻塞 -- an expired wait breaks nothing, reddens
# nothing, and quietly decides what the next rounds do.
#
# It is a QUESTION like the others (see the tool's LIMITS): a stream may be
# waiting on a SECOND ruling about an already-armed id, which this tool cannot
# tell from an expired admission wait.  But LOOK.
sc_leg 'stale-waits'
printf '\n=== expired waits (ruling already landed) ===\n'
if command -v python3 >/dev/null 2>&1; then
    python3 tools/agent/stale_waits.py --no-age
    note $?
else
    unchecked 'the expired-wait check'
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
sc_leg 'stable-anchors'
printf '\n=== stable version anchors (铁律 3) ===\n'
if command -v python3 >/dev/null 2>&1; then
    python3 tools/agent/stable_anchors.py
    note $?
else
    unchecked 'the stable-anchor invariants'
fi

# [director 20260826, GH #198 §3] Both TRUNK RED banners below used to end
# "failing before you changed anything".  That was a canned string, not a
# finding: BOTH legs run the WORKING TREE, so the clause asserted something the
# check never established.  Strategy 01:38Z hit the concrete cost -- their own
# edit displaced a line-number-pinned row in test_level_gate_census.lua
# (:599 -> :637) and the banner told them main was already red; `git stash`
# showed main at 15/15 green.  Read literally, the next reader ships their own
# red.  Now the banners name the working tree and name what would settle it.
#   [director 20260829] That specific generator is gone: test_level_gate_census
# .lua no longer keys on line numbers (it keys on source text), so an insertion
# above a row is green.  The banner wording still matters -- BOTH legs still run
# the working tree, and any other red reaches the reader the same way.  What the
# 08-29 round found is that the wording was never the whole gap: on that day the
# banner printed TRUNK RED correctly and three streams landed on it anyway, one
# of them launching a paid wave.  See iterations/DECISIONS_NEEDED.md section 14.
#   DELIBERATELY NOT auto-stashing to answer it here: a selfcheck that mutates
# the tree can strand a session's uncommitted work if it dies between stash and
# pop, and 开工自检 is the one command every stream runs before touching
# anything.  Printing the command the reader can choose to run is the cheap
# half; doing it for them is not worth that failure mode.
sc_leg 'trunk-red(python)'
printf '\n=== trunk health (python test suite) ===\n'
if command -v python3 >/dev/null 2>&1; then
    suite=$(bash tests/run_py_tests.sh 2>&1); suite_rc=$?
    # [director 20260901, GH #380] KEEP THE EVIDENCE.  Everything below the
    # green path used to reach the reader through `grep -E '^(FAIL|...)'`, and
    # run_py_tests.sh indents each failing test's OWN output by six spaces
    # (`sed 's/^/      /'`).  An anchored grep drops every one of those lines.
    # So the runner went to the trouble of capturing $out and printing it, and
    # this leg threw it away -- leaving the banner and a filename.
    #   Measured cost, this round: 开工自检 printed `FAIL tests/test_rc_wrapper
    # .py` + TRUNK RED and nothing else.  The suite was green on the very next
    # run, and the test was green 30/30 standalone, so that discarded text was
    # the ONLY copy of the evidence for an intermittent red -- and the leg
    # deleted it.  Re-running is not a recovery: a flake that does not
    # reproduce is gone for good.
    #   This is the same failure family as GH #243/#267 approached from the
    # other side.  Those two fixed WHICH banner gets printed; the banner has
    # been right since.  What no round could do is answer "red because of
    # what?" -- and the leg's own note above says a false TRUNK RED is what
    # teaches people to ignore the line.  A red you cannot diagnose is
    # indistinguishable from one, so it costs the same trust.
    #   The full text now goes to a log OUTSIDE the tree, named on stdout.
    # Writing under $TMPDIR keeps the "this leg never mutates the working
    # tree" property that the auto-stash note above turns on; the tail printed
    # inline is a view, and the log is the data (tools/agent/rc.sh's RC_LOG
    # idiom, and its test's words: "the tail is a view, not the data").
    py_log=""
    if [ "$suite_rc" -ne 0 ]; then
        py_log=$(mktemp "${TMPDIR:-/tmp}/selfcheck_py_XXXXXX.log" 2>/dev/null) || py_log=""
        [ -n "$py_log" ] && printf '%s\n' "$suite" > "$py_log" 2>/dev/null
    fi
    # The runner's own indent is the detail channel; 40 lines is a view of it.
    sc_py_detail() {
        printf '%s\n' "$suite" | grep -E '^      ' | head -40
        if [ "$(printf '%s\n' "$suite" | grep -cE '^      ')" -gt 40 ]; then
            printf '      ... (truncated at 40 lines)\n'
        fi
        [ -n "$py_log" ] && printf 'PY_LOG: %s  (full output -- the lines above are a view, not the data)\n' "$py_log"
        return 0
    }
    if [ "$suite_rc" -eq 0 ]; then
        printf '%s\n' "$suite" | tail -1
    elif [ "$suite_rc" -eq 2 ]; then
        # [director 20260827, GH #243] The runner's exit 2 means some test could
        # not read its input.  Calling that TRUNK RED is a claim about main that
        # the reading does not support -- and it is exactly the false red #243
        # measured (one round read 39/2 where two later runs of the same tree
        # read 41/0).  Uncertifiable is not a pass either: it still notes 2.
        printf '%s\n' "$suite" | grep -E '^(UNCERTIFIABLE|uncertifiable:|[0-9]+ passed)' || true
        sc_py_detail
        printf 'UNCERTIFIABLE -- a python test did NOT run (could not read its input). This line is NOT a pass,\n'
        printf '  and it is NOT evidence that trunk is red: re-run on a quiet tree (nothing writing under bots/).\n'
        note 2
    else
        # `uncertifiable:` is in this alternation on purpose.  A run can be BOTH
        # red and un-run -- this round's was, `71 passed, 1 failed, 1
        # uncertifiable` -- and only the exit-2 branch used to name the un-run
        # file.  The exit-1 branch reports the strictly worse tree, so it was
        # the branch that named LESS of what was wrong.
        printf '%s\n' "$suite" | grep -E '^(FAIL|failed:|UNCERTIFIABLE|uncertifiable:|[0-9]+ passed)' || true
        sc_py_detail
        printf 'TRUNK RED -- a python test is failing ON THE WORKING TREE.\n'
        printf '  Whether main is red too is NOT established by this line: re-run after `git stash`.\n'
        note 3
    fi
else
    unchecked 'the python trunk-health suite'
fi

# [director 20260826, GH #171] This leg USED to end `SKIP (no lua5.1 --
# apt-get install lua5.1)` with no `note`, on the stated ground that "an absent
# interpreter is not a failing test".  That ground is still correct and is NOT
# what changed.  What changed is the measurement: from the day this leg landed
# it had, in a Routine container, NEVER ONCE RUN.  Two streams reported the same
# live shape within 100 minutes of each other -- batch-desk 21:14Z and strategy
# 22:52Z -- and the strategy one is the load-bearing case: a real red
# (test_item_name_census, 1fcfcd83) sat on main ~3h while the selfcheck printed
# SKIP.  GH #171's original sentence was "the detector caught it; nobody ran the
# gate."  The gate now exists, and it printed SKIP every round.  Same outcome,
# new reason.
#
# `SKIP` and `PASS` were the same thing in both machine-readable channels: one
# unremarkable line, and no effect on the exit code.  So the leg is now
# UNCERTIFIABLE (`note 2`) rather than silent -- which is not a new policy but
# this wrapper's own three-value convention (header: "Exit 0 clean, 2
# uncertifiable, 3 findings"), applied to a leg that was skipping it.  It is
# deliberately NOT `note 3`: a missing interpreter is not a red trunk, and a
# false TRUNK RED is what teaches people to ignore the line (see the LIMIT note
# above).
#
# AND the interpreter is bought before it is declared missing.  Treating "no
# lua5.1" as an immutable environment fact was the actual error: measured three
# times independently -- batch-desk 08-25 ("seconds"), strategy 08-25 ("~20s"),
# director 08-26 (**4s**, root, no `apt-get update` needed) -- the install is
# cheaper than the reading it unblocks.  Bounded, best-effort, and silent on
# failure: if apt is absent, or we are non-root without passwordless sudo, or
# the network is down, the fall-through is exactly today's behaviour plus the
# UNCERTIFIABLE banner.  No new failure mode.
#
# NOT A CONTRADICTION with the "deliberately not auto-stashing" note above: that
# refuses to mutate the WORKING TREE, because a selfcheck dying between stash
# and pop strands a session's uncommitted work.  Installing a package touches no
# repo state and can strand nothing.  The line is what the check can destroy.
#
# The helper is defined AFTER this leg's banner printf, not before it, and that
# placement is load-bearing: tests/test_selfcheck_lua_leg.py isolates "the leg"
# as the source from that printf onward and runs it.  Defined above the banner,
# the helper would be outside the isolated source, the end-to-end case would run
# a `try_install_lua51: command not found` that happens to fall through to the
# same branch, and the test would look green while exercising nothing.  That is
# this file's own recorded trap (test 2a2: "a test that mirrors the thing it
# checks is checking the mirror") wearing different clothes.
sc_leg 'trunk-red(lua)'
printf '\n=== trunk health (fast Lua detectors) ===\n'

# [director 20260826, GH #205] The install BODY moved out to
# tools/agent/ensure_lua_toolchain.sh and this is now a two-line delegation.
# Reason: rule 6's OTHER half (luacheck) needed the identical bounded/guarded/
# silent-on-failure buy, and a second copy of it is a second thing to keep
# right.  The properties that made it safe are asserted on the shared file now
# (tests/test_ensure_lua_toolchain.py), not here.
#
# Sourced with a leading `./` so it resolves with NO PATH at all: case 6 of
# tests/test_selfcheck_lua_leg.py runs this leg with an empty PATH, and a
# bare-name `.` would search PATH and find nothing.  The wrapper cd's to the
# repo root at the top, so the relative path is the repo's.
#
# The helper is still DEFINED AFTER this leg's banner printf, and that placement
# is still load-bearing: the test isolates "the leg" as the source from that
# printf onward and runs it.  Defined above the banner, the delegation would be
# outside the isolated source and the end-to-end case would exercise nothing.
try_install_lua51() {
    . ./tools/agent/ensure_lua_toolchain.sh 2>/dev/null || return 1
    ensure_lua_tool lua5.1
}

if ! command -v lua5.1 >/dev/null 2>&1; then
    try_install_lua51 || true
fi
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
            # [director 2026-09-01, GH #387 §3] THE FILE NAME IS PRINTED FIRST,
            # AND UNCONDITIONALLY.  The extract below is a filter over the
            # runner's own FAIL format, and a file can be red without ever
            # producing one: test_cm_ult_reach_meter_domain.lua killed the
            # runner from OUTSIDE a test body, so the filter matched nothing and
            # the whole leg reported `TRUNK RED -- 1 of 69` with no name.  Every
            # reader of that line then had to re-run all 69 files to learn which
            # one -- the batch desk did (12:18Z), and so did this round.  A red
            # that withholds where it is costs a round per reader.
            printf 'RED  %s\n' "$(basename "$f")"
            det=$(printf '%s\n' "$out" | grep -E '^(FAIL:|      )' | head -4)
            if [ -n "$det" ]; then
                printf '%s\n' "$det"
            else
                # No FAIL line at all means the runner did not get to report:
                # hand over its last words rather than nothing.
                printf '%s\n' "$out" | tail -3 | sed 's/^/  | /'
            fi
        fi
    done
    if [ "$ran" -eq 0 ]; then
        # Discovery matching nothing is the dead-lifecycle-rule failure this
        # wrapper's own header warns about: on the books, matching nothing.
        printf 'NO DETECTORS FOUND -- discovery matched 0 files; the tag or the paths moved.\n'
        note 3
    elif [ "$red" -gt 0 ]; then
        printf 'TRUNK RED -- %d of %d Lua detector file(s) failing ON THE WORKING TREE.\n' \
            "$red" "$ran"
        printf '  Whether main is red too is NOT established by this line: re-run after `git stash`.\n'
        note 3
    else
        # [director 20260826, GH #216 §5] The line NAMES ITS DOMAIN.  It read
        # `8 detector file(s), 0 failures`, and a reader with only that line in
        # front of them takes it for "trunk's Lua side was looked at this
        # round".  It is 8 of ~200 files, chosen by TAG -- and the round this
        # was written found the counter-example: tests/test_item_name_census.lua
        # had been red on main for over five hours across four landings, and
        # carries no [detector]/[ratchet] tag, so this leg had never once
        # discovered it.  Same family as the `SKIP` this leg's else-branch
        # already fixed (GH #171) and the empty smoke gate (GH #200): what makes
        # a green line dangerous is not being wrong, it is being read as
        # covering more than it does.  Nothing about WHAT runs changes here --
        # widening the subset is GH #124's problem and costs ~100min.
        printf '%d tagged detector file(s), 0 failures -- FAST SUBSET, not the full suite.\n' "$ran"
        printf '  Untagged tests (and anything needing one process for the whole suite) are NOT covered here.\n'
    fi
else
    # Deliberately NOT shaped like the pass line above.  `SKIP (no lua5.1)` and
    # `8 detector file(s), 0 failures` shared a visual region and an exit code;
    # that is the whole defect GH #171's two follow-ups reported.
    printf 'UNCERTIFIABLE -- the Lua detector leg did NOT run (no lua5.1, and the install attempt failed).\n'
    printf '  Trunk Lua side is UNCHECKED this round. This line is NOT a pass.\n'
    printf '  Buy it with: apt-get install -y lua5.1   (measured 4s, 2026-08-26)\n'
    note 2
fi

sc_report
worst=$(sc_worst)
printf '\nselfcheck worst exit: %d\n' "$worst"
exit "$worst"
