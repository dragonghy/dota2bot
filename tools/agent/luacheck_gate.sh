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
    exit 2
fi

out=$(luacheck "${targets[@]}" --formatter plain 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" | head -40
    printf 'LUACHECK RED -- iron rule 6 requires 0 warnings on the WORKING TREE.\n'
    printf '  Whether main is red too is NOT established by this line: re-run after `git stash`.\n'
    exit 3
fi

printf 'luacheck %s: 0 warnings\n' "${targets[*]}"
exit 0
