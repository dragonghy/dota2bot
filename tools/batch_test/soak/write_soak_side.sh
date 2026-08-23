#!/usr/bin/env bash
# [GH #141] The ONE place that renders bots/Customize/soak_side.lua.
#
#   write_soak_side.sh <side> <cand> <seed>        -> stdout, one Lua line
#   CAND_REF='a,b' write_soak_side.sh ...          -> two-arm wave
#
# WHY A SHARED RENDERER
#   Two callers used to hold their own copy of the printf format
#   (validate_onspot.sh deploy_wave, mirror_ab.sh deploy).  Adding an optional
#   field to a format that lives in two places is exactly the shape GH #67
#   names: the copies drift, and the drift is invisible because nothing reads
#   both.  Everything that writes the gate file now renders it here.
#
# THE CONTRACT THAT MATTERS
#   With CAND_REF unset the output is BYTE-IDENTICAL to what the callers wrote
#   before this script existed:
#       return { side = 'radiant', cand = 'creeppull', seed = 888 }
#   That is not a nicety.  The blast radius of the gate file is every gated fix
#   in the tree, so "unset behaves as before" is the precondition of the
#   feature, not its bonus.  tests/test_soak_cand_ref.py pins the exact bytes.
#
#   With CAND_REF set, `cand_ref` is emitted and jmz_func's J.IsSoakCandidate
#   arms it on the OTHER leg -- the wave becomes armA-vs-armB rather than
#   candidate-vs-stable.  A verdict computed from such a wave is NOT comparable
#   with a single-arm verdict; recover_verdict.py stamps it contrast=two_arm so
#   the difference survives archiving (see that script and GH #141 §3.4).
set -uo pipefail
SIDE="${1:?side (radiant|dire)}"
CAND="${2:?cand id / bundle}"
SEED="${3:?seed}"
CAND_REF="${CAND_REF:-}"

if [ -z "$CAND_REF" ]; then
    printf "return { side = '%s', cand = '%s', seed = %s }\n" "$SIDE" "$CAND" "$SEED"
else
    printf "return { side = '%s', cand = '%s', cand_ref = '%s', seed = %s }\n" \
        "$SIDE" "$CAND" "$CAND_REF" "$SEED"
fi
