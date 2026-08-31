#!/usr/bin/env bash
# rc.sh -- run a command, get a SHORT tail AND its TRUE exit code.
#
# WHY THIS FILE EXISTS.  Evidence discipline 3 ("never measure an exit code
# through a pipe") had recurred five times before this file, and the sixth
# recurrence is what finally paid for it -- with the first CONTROLLED reading
# anyone had taken of the defect:
#
#     bash tools/agent/routine_selfcheck.sh 2>&1 | tail -60   -> harness said 0
#     bash tools/agent/routine_selfcheck.sh >log 2>&1; rc=$?  -> rc=3
#
# Same command, same tree, the same minute.  The piped run reported CLEAN on a
# round whose trunk was RED.  Every prior site was reconstructed afterwards from
# prose; this one is a side-by-side, so the mechanism is no longer in dispute:
# `a | tail` returns TAIL's status, and tail essentially always succeeds.
#
# THE REASON IT KEPT RECURRING IS NOT IGNORANCE, IT IS ECONOMICS.  The agent
# wants two things at once -- a short tail (context is finite) and the exit code
# -- and the only ONE-LINER that gives the tail is the pipe.  The correct form
# (`cmd >log 2>&1; rc=$?; tail -40 log`) is three statements and a temp path you
# have to invent.  A rule that makes the right thing longer than the wrong thing
# loses on a long enough timeline, which is what the five recurrences measured.
# So this file does not warn about the pipe; it makes the correct path SHORTER:
#
#     bash tools/agent/rc.sh <cmd> [args...]
#
# WHAT MAKES THE READING SURVIVE A PIPE.  The exit code is printed as the LAST
# LINE of output.  So even `bash tools/agent/rc.sh cmd | tail -5` -- the very
# habit this file exists to defeat -- still shows the true code in the TEXT,
# where `$?` no longer can.  The banner is in-band on purpose: an out-of-band
# mechanism is one the caller can forget, and forgetting is the failure mode.
# The wrapper also exits WITH that code, so bare use reads correctly too.
#
# SECOND TRAP, FOUND THE SAME ROUND (and it is the same family).  A `tests/*.lua`
# detector ends with `return tests` -- it is a MODULE, not a script.  So
#
#     lua5.1 tests/test_coarmed_attribution_register.lua   -> exit 0, ran NOTHING
#
# and that 0 is a did-not-run wearing a pass, exactly like SIGTERM's 143 and
# argparse's 2.  It was caught only because a mutation stand was built on top of
# it and the mutant survived (discipline 2).  A bare exit code does not save you
# here -- the code is honestly 0 -- so the wrapper REFUSES this invocation and
# names the runner that does run the tests.
#
# Usage:
#   bash tools/agent/rc.sh [-n LINES] <cmd> [args...]
#   bash tools/agent/rc.sh -n 20 -- lua5.1 tests/run_tests.lua test_foo.lua
#
# Exit codes: the command's own, or 2 when this wrapper REFUSED to run it
# (2 = could-not-run, the same vocabulary as rule 10 / run_py_tests.sh / the
# push gate -- a refusal is not a pass).

set -u

LINES=40
while [ $# -gt 0 ]; do
    case "$1" in
        -n) LINES="${2:-40}"; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
    esac
done

if [ $# -eq 0 ]; then
    printf 'usage: bash tools/agent/rc.sh [-n LINES] <cmd> [args...]\n' >&2
    printf 'RC_EXIT=2  REFUSED (no command given)\n'
    exit 2
fi

# --- refusal: a Lua module run as a script ---------------------------------
# `lua5.1 tests/test_x.lua` on a file whose last non-blank line is `return
# <name>` loads the module and exits 0 having asserted nothing.  Discriminant is
# the file's own last line, not its path, so a self-running .lua still works.
if [ "$(basename -- "$1")" = "lua5.1" ] || [ "$(basename -- "$1")" = "lua" ]; then
    target="${2:-}"
    case "$target" in
        *.lua)
            if [ "$(basename -- "$target")" != "run_tests.lua" ] && [ -r "$target" ]; then
                last=$(grep -vE '^[[:space:]]*(--.*)?$' -- "$target" | tail -1)
                case "$last" in
                    return\ *)
                        printf 'REFUSED: %s ends with `%s` -- it is a MODULE, not a script.\n' \
                            "$target" "$last" >&2
                        printf 'Running it directly loads it and asserts NOTHING, then exits 0.\n' >&2
                        printf 'That 0 is a did-not-run wearing a pass (same family as SIGTERM 143\n' >&2
                        printf 'and argparse 2). Use the runner, which actually executes the tests:\n' >&2
                        printf '  bash tools/agent/rc.sh lua5.1 tests/run_tests.lua %s\n' \
                            "$(basename -- "$target")" >&2
                        printf 'RC_EXIT=2  REFUSED (%s is a module; nothing would have run)\n' "$target"
                        exit 2
                        ;;
                esac
            fi
            ;;
    esac
fi

log=$(mktemp "${TMPDIR:-/tmp}/rc.XXXXXX")

# THE LOAD-BEARING TWO LINES.  No pipe, no `timeout`, nothing between the
# command and `$?` -- any intervening command would overwrite it, which is the
# same defect one layer down.
"$@" > "$log" 2>&1
rc=$?

printf 'RC_CMD: %s\n' "$*"
printf 'RC_LOG: %s (%s line(s); last %s shown)\n' \
    "$log" "$(wc -l < "$log" | tr -d ' ')" "$LINES"
printf -- '---\n'
tail -n "$LINES" -- "$log"
printf -- '---\n'

# Name the two codes that read like a completed run but are not.
case "$rc" in
    143) printf 'NOTE: 143 = killed by SIGTERM (usually `timeout`). That is DID NOT RUN, not clean.\n' ;;
    2)   printf 'NOTE: 2 is this repo'"'"'s could-not-run code (rule 10, run_py_tests.sh, push gate),\n'
         printf '      and argparse also answers a missing required flag with 2. Not a pass.\n' ;;
esac

# LAST LINE, ALWAYS.  This is the whole design: it survives `| tail`.
printf 'RC_EXIT=%d  (bare exit code of: %s)  RC_LOG=%s\n' "$rc" "$*" "$log"
exit "$rc"
