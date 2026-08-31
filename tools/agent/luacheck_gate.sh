#!/usr/bin/env bash
# Iron rule 6's STATIC half, as a command that cannot be silently skipped.
#
# GH #205 (director ruling 2026-08-26T12:xxZ).  This is NOT the whole of rule 6
# and is named for the half it is: the dynamic half is still
# `lua5.1 tests/run_tests.lua` (and per AGENTS.md / GH #124 the full suite does
# not finish in one process in a Routine container).  A wrapper whose name
# claims more than it asserts is a trap this repo has already paid for once
# (GH #198 §2), so the name stays narrow.
#
# What it adds over typing `luacheck bots game --formatter plain` yourself:
#   1. it BUYS luacheck first (tools/agent/ensure_lua_toolchain.sh) instead of
#      concluding the container cannot run the gate -- the entire GH #205
#      defect;
#   2. it cannot be passed by not running: a gate that could not run exits 2
#      with an UNCERTIFIABLE banner deliberately unlike the pass line, which is
#      the GH #171 ruling applied to a new leg rather than re-learned on it.
#
# Exit 0 clean, 2 uncertifiable (luacheck absent and unbuyable), 3 warnings.
# Same three values as tools/agent/routine_selfcheck.sh, on purpose.
#
# Usage:  bash tools/agent/luacheck_gate.sh [paths...]     (default: bots game)
set -u
cd "$(dirname "$0")/../.."

# --- pipe hazard: a VERDICT LINE, deliberately NOT §22's refusal -------------
# [director 20260831T21:xxZ, charter backlog 22 residual, GH #372]
#
# Same defect as §22 (evidence discipline 3: `cmd | tail` reports the READER's
# exit code, not this script's), same reader, one slot later:
#
#     bash tools/agent/luacheck_gate.sh 2>&1 | tail -5      -> harness says 0
#
# routine_selfcheck.sh answers that shape by REFUSING when /dev/stdout is a
# FIFO.  Four director rounds carried "port the guard here" and four
# deliberately did not.  Measured 2026-08-31, that caution was right and the
# port would have been an outage:
#
#     git runs pre-push hooks with stdout as a FIFO  (probed: pipe:[...])
#
# and .githooks/pre-push calls this file bare, mapping any non-zero to PUSH
# REFUSED.  A verbatim port therefore refuses EVERY push in the repo, for every
# stream, in every container -- turning rule 6's gate into rule 6's blockade,
# reachable only by the RULE6_BYPASS escape hatch that exists to record a
# SKIPPED gate.  The two legitimate pipe readers §22 could truthfully call
# "ZERO call sites" are non-zero here: the hook, plus two python acceptance
# files that run this gate under capture_output.
#
# So the site's shape forbids the refusal form, and the fix is the additive one:
# ALWAYS end on a machine-readable verdict, on stdout, written LAST.
#   * `| tail -1`      -> the verdict is the surviving line.
#   * `2>&1 | tail -1` -> still the verdict: it is written after everything.
#   * the hook, the tests, `> file`, bare -> one extra line, exit code untouched.
# Unconditional on purpose: a line that only appears when something looks wrong
# is a fourth reminder (what §22 retired), and one that fired on every push
# would train its own readers to skip it.  This one carries the answer rather
# than a warning about the question.
#
# WHAT IT DOES NOT BUY, stated rather than implied: a reader who pipes and looks
# at neither the exit code nor the last line still learns nothing.  This makes
# the truth SURVIVE the pipe; it cannot make anyone read it.  §22's refusal is
# still the stronger form and stays where its call sites allow it.
verdict() {
    case "$1" in
        0) printf 'GATE_EXIT=0  CLEAN (iron rule 6 static half passed)\n' ;;
        3) printf 'GATE_EXIT=3  RED (warnings above; iron rule 6 static half FAILED)\n' ;;
        *) printf 'GATE_EXIT=%s  UNCERTIFIABLE (the gate did NOT run; this is NOT a pass)\n' "$1" ;;
    esac
    exit "$1"
}

targets=("$@")
[ "${#targets[@]}" -gt 0 ] || targets=(bots game)

. tools/agent/ensure_lua_toolchain.sh

if ! ensure_lua_tool luacheck; then
    # Deliberately not shaped like the clean line below.  `SKIP (no luacheck)`
    # and `luacheck: 0 warnings` differed in neither channel a reader has, and
    # that -- not the missing package -- is how a mandatory push gate went
    # unrun for its whole life.
    printf 'UNCERTIFIABLE -- the luacheck gate did NOT run (no luacheck, and the install attempt failed).\n'
    printf '  Iron rule 6 static half is UNCHECKED. This line is NOT a pass.\n'
    printf '  Buy it with: apt-get install -y lua-check   (measured 5.5s, 2026-08-26; the\n'
    printf '  package is lua-check, NOT luacheck -- see tools/agent/ensure_lua_toolchain.sh)\n'
    verdict 2
fi

out=$(luacheck "${targets[@]}" --formatter plain 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" | head -40
    printf 'LUACHECK RED -- iron rule 6 requires 0 warnings on the WORKING TREE.\n'
    printf '  Whether main is red too is NOT established by this line: re-run after `git stash`.\n'
    verdict 3
fi

printf 'luacheck %s: 0 warnings\n' "${targets[*]}"
verdict 0
