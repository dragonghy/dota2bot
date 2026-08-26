#!/usr/bin/env bash
# Arm iron rule 6's static gate for THIS container (GH #213, option 甲).
#
# `.githooks/pre-push` travels with the clone; `core.hooksPath` does NOT -- it
# lives in `.git/config`, which every fresh container recreates empty.  So the
# hook needs one install step per container, and "needs somebody to remember an
# install step" is GH #213 itself, moved up a level.
#
# It is broken by hanging the install on the ONE command every stream already
# runs at 开工 (tools/agent/routine_selfcheck.sh, iron rule 10).  That is not a
# fifth leg of the selfcheck in the sense GH #205 rejected: #205 refused to make
# 开工 RUN luacheck, because at 开工 you have changed nothing and the gate asks
# "is what I changed clean" -- a different axis from the selfcheck's "is trunk
# red".  Arming costs ~5ms and runs nothing; the gate's 13s still lands where it
# belongs, at the push.
#
# BOUNDARY (the selfcheck's own line is "what can this check destroy"): this
# writes one key to `.git/config` and never touches the working tree.  The
# refusal to auto-stash stands untouched -- a selfcheck dying mid-stash strands
# uncommitted work; a `core.hooksPath` line strands nothing, and is undone with
# `git config --unset core.hooksPath`.
#
# NOT SILENT ON FAILURE (GH #213 acceptance).  ensure_lua_toolchain.sh may fail
# silently because its caller decides what a missing tool means; here the
# failure IS the finding -- an unarmed gate is a push path with nothing in it,
# and that is precisely the state this file exists to end.
#
# Exit 0 armed (or already armed), 1 not armed (reason printed).
#
# Usage:  bash tools/agent/arm_push_gate.sh
set -u
cd "$(dirname "$0")/../.." 2>/dev/null || {
    printf 'PUSH GATE NOT ARMED -- could not reach the repo root from %s.\n' "$0"
    exit 1
}

want='.githooks'

command -v git >/dev/null 2>&1 || {
    printf 'PUSH GATE NOT ARMED -- no git on PATH; iron rule 6 has nothing holding it this session.\n'
    exit 1
}
git rev-parse --git-dir >/dev/null 2>&1 || {
    printf 'PUSH GATE NOT ARMED -- not inside a git work tree.\n'
    exit 1
}

[ -x "$want/pre-push" ] || {
    printf 'PUSH GATE NOT ARMED -- %s/pre-push is missing or not executable.\n' "$want"
    # Deliberately NOT printing a `git checkout --` here: this script's own
    # acceptance forbids work-tree-mutating commands in it, and a suggestion is
    # a command with an extra step -- in a container holding a session's
    # uncommitted work, that is the one shape not worth the convenience.
    printf '  chmod +x it, or restore it from the index; rule 6 is honour-system until you do.\n'
    exit 1
}

current=$(git config --get core.hooksPath 2>/dev/null || true)

if [ -n "$current" ] && [ "$current" != "$want" ]; then
    # Somebody chose a different hooks dir on purpose.  Overwriting a deliberate
    # choice to install our own is the kind of helpfulness that gets a tool
    # switched off, and a disarmed-but-loud gate beats a silent fight over one
    # config key.
    printf 'PUSH GATE NOT ARMED -- core.hooksPath is already %s (not %s); left alone.\n' \
        "$current" "$want"
    printf '  Point it at %s yourself if you want the rule 6 gate: git config core.hooksPath %s\n' \
        "$want" "$want"
    exit 1
fi

if [ "$current" = "$want" ]; then
    printf 'push gate armed (core.hooksPath=%s, already set)\n' "$want"
    exit 0
fi

# Bounded for the same reason ensure_lua_toolchain.sh is: a hang in the one
# command every stream runs at 开工 reads as "still working" and eats a trigger.
timeout 10 git config core.hooksPath "$want" >/dev/null 2>&1 || {
    printf 'PUSH GATE NOT ARMED -- `git config core.hooksPath %s` failed.\n' "$want"
    exit 1
}
# Read back rather than trust the write: the whole family of defects this file
# belongs to is "it was written down and then read back as an established fact".
[ "$(git config --get core.hooksPath 2>/dev/null || true)" = "$want" ] || {
    printf 'PUSH GATE NOT ARMED -- core.hooksPath did not read back as %s.\n' "$want"
    exit 1
}
printf 'push gate armed (core.hooksPath=%s); `git push` now runs the rule 6 static gate\n' "$want"
exit 0
