#!/usr/bin/env bash
# Buy the Lua toolchain iron rule 6 needs, instead of declaring it absent.
#
# WHY THIS FILE EXISTS (GH #205, director ruling 2026-08-26T12:xxZ, option B).
#
# Iron rule 6 has two halves: `luacheck bots game --formatter plain` (static) and
# `lua5.1 tests/run_tests.lua` (dynamic).  In a Routine container neither binary
# is present at session start, and for the whole life of the rule that absence
# was written down -- in comments, in reports, in "容器无 luacheck,跳过" lines --
# and then READ BACK BY THE NEXT ROUND AS AN ESTABLISHED FACT.  It never was one:
#
#   apt-get install -y lua5.1     4s   (director 08-26; two streams measured the
#                                       same thing independently before that)
#   apt-get install -y lua-check  5.5s (director 08-26T12:5xZ, THIS container)
#   luacheck bots game            13s  (0 warnings on trunk)
#
# So the static half of the push gate costs 5.5s to buy and 13s to run, and it
# had never once been run in a Routine container.  GH #171 fixed the same defect
# for the interpreter; this is its other half, and its failure direction is
# worse: #171 lost a READING, this lost a GATE -- every round that changed Lua
# and pushed, pushed without passing rule 6's first door.
#
# ⚠️ THE PACKAGE NAME IS ITS OWN LAYER OF THE SAME ERROR.  #205 was opened
# quoting "luacheck 是 luarocks 包,不在 apt 里", and the ruling round then
# measured a two-step luarocks route (5s + 7s) and believed it.  Both were wrong
# in the same direction: the Debian package is `lua-check`, NOT `luacheck`, so
# `apt-get install luacheck` says `Unable to locate package` -- which reads
# exactly like "not in apt".  `.github/workflows/ci.yml:15` has had the right
# name in it the entire time.  strategy 10:34Z is who noticed.  Keep the map
# below authoritative and keep CI as its cross-check.
#
# CONTRACT (this is the shared half; the GATE is the caller's -- see
# tools/agent/luacheck_gate.sh and iron rule 6):
#   ensure_lua_tool <tool>   -> 0 if the tool is now runnable, 1 if it is not.
#   * already present  : silent, 0.  (Never re-installs: an unconditional
#                        apt-get would tax every trigger for nothing.)
#   * installed here   : one line on stdout, 0.
#   * could not install: SILENT, 1.  The caller decides what a missing tool
#                        means for IT -- but per GH #171 the caller must not
#                        make that a line shaped like a pass.
#
# Bounded (`timeout`), guarded (apt-get must exist; root or passwordless sudo),
# and best-effort: with no apt, no sudo, or no network, behaviour is byte for
# byte what it was before this file existed.  No new failure mode.
#
# Usage:
#   . tools/agent/ensure_lua_toolchain.sh   # sourced: defines ensure_lua_tool
#   bash tools/agent/ensure_lua_toolchain.sh lua5.1 luacheck   # or run directly

# Deliberately no `apt-get update`: it is the expensive half (tens of seconds,
# and the half that hangs on a half-there network), while the install off the
# existing lists is the 4-6s that was measured.
ensure_lua_tool__pkg() {
    case "$1" in
        lua5.1)   printf 'lua5.1\n' ;;
        luacheck) printf 'lua-check\n' ;;   # NOT `luacheck` -- see the note above
        *)        return 1 ;;
    esac
}

ensure_lua_tool() {
    local tool="${1:-}"
    [ -n "$tool" ] || return 1

    # Only when missing.  A selfcheck that apt-gets unconditionally taxes every
    # trigger to buy something it already has.
    command -v "$tool" >/dev/null 2>&1 && return 0

    local pkg
    pkg=$(ensure_lua_tool__pkg "$tool") || return 1

    command -v apt-get >/dev/null 2>&1 || return 1
    local as_root=""
    if [ "$(id -u)" != 0 ]; then
        command -v sudo >/dev/null 2>&1 || return 1
        sudo -n true >/dev/null 2>&1 || return 1
        as_root="sudo"
    fi
    # A hang in the one command every stream runs at 开工 reads as "still
    # working" and blocks the trigger; that is why this is bounded and not
    # merely fast in the case we measured.
    timeout 120 $as_root apt-get install -y "$pkg" >/dev/null 2>&1 || return 1
    command -v "$tool" >/dev/null 2>&1 || return 1
    printf 'installed %s (it was missing; apt package %s, bounded)\n' "$tool" "$pkg"
    return 0
}

# Run directly -> ensure each named tool; exit 1 if any could not be bought.
# `$0` ends in this file's name only when executed, not when sourced.
case "${0##*/}" in
    ensure_lua_toolchain.sh)
        rc=0
        for t in "$@"; do
            ensure_lua_tool "$t" || { printf 'could not provide %s\n' "$t" >&2; rc=1; }
        done
        exit "$rc"
        ;;
esac
