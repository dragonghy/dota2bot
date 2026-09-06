#!/usr/bin/env bash
# Mutation stand for tests/test_du5_archive_census.lua (GH #464 §5,
# test_set.md §DU.8).
#
# WHAT IT IS FOR. That test file asserts on PROSE, and a prose assertion is the
# easiest kind to write blind: `find(x, 1, true)` on a string that happens to
# be somewhere in a 1.2MB file passes for reasons that have nothing to do with
# the claim. So every claim it makes is put back under a mutant a correct
# assertion MUST catch -- both directions of drift it exists to stop:
#
#   * the ARCHIVE goes stale while the corpus and its ratchets move (M4, M5) --
#     the scenario that actually happened on 09-03 and that GH #464 caught by
#     hand a day later;
#   * the archive is EDITED BACK to a superseded reading (M1, M2, M3, M8), or
#     a superseded reading is left standing beside the live one instead of
#     being demoted (M6) -- that last one is how `78/80` and `2/101` survived a
#     re-baseline in the first place;
#   * a whole carrier disappears (M7): §DU.5 has TWO copies of the
#     last-conjunct rate and the banner is the one a harvester meets first.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every single mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_du5_archive.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation -- and per its converse, first read the
# diff and confirm the mutant landed where you think). No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Owner P4.3 (2026-09-06): the two carriers this stand mutates now live in
# DIFFERENT files.  §DU.5 itself moved to the ruling archive; the harvest
# banner stayed in the live file, because a harvester meets the live file.
# Each mutant below is pointed at the half that actually holds its target --
# a mutant applied to the wrong half changes nothing and is then CAUGHT for
# the wrong reason (evidence discipline 2's converse: read the diff, confirm
# the mutant landed).  Verified per-string with grep before re-pointing.
ARCHIVE=iterations/archive/test_set_archive.md
LIVE=iterations/streams/test_set.md
CENSUS=tests/test_replay_437_wandbleed_source.lua
TEST=test_du5_archive_census.lua

TMP=$(mktemp -d)

nrun=0; ncaught=0

# INFLIGHT names the file that is mutated RIGHT NOW, or is empty when the tree
# is clean.  Load-bearing here for the same reason as in the sibling stands:
# one of the two targets is a 1.2MB archive file that is expensive to notice
# has been left mutated.
INFLIGHT=""

save() {
    cp "$1" "$TMP/$(basename "$1").orig"
    sha256sum "$1" > "$TMP/$(basename "$1").sha"
    INFLIGHT="$1"
}
restore() {
    cp "$TMP/$(basename "$1").orig" "$1"
    if ! sha256sum -c "$TMP/$(basename "$1").sha" >/dev/null; then
        echo "FATAL: restore of $1 did not verify -- stopping before anything else runs"
        exit 2
    fi
    INFLIGHT=""
}

# GH #418's trap, carried forward from mutstand_fixture_debt.sh /
# mutstand_slotwait.sh.  `trap 'rm -rf "$TMP"' EXIT` is WORSE than no trap at
# all: on an interrupt it leaves the mutant in the working tree AND deletes
# $TMP, the only copy of the original.  Order inside the handler is content,
# not style: restore first, remove the copies second.
on_exit() {
    if [ -n "$INFLIGHT" ]; then
        echo "INTERRUPTED with $INFLIGHT mutated -- restoring before exit"
        restore "$INFLIGHT"
    fi
    rm -rf "$TMP"
}
trap on_exit EXIT

# Run the test file and report its BARE exit code (rule 3: never through a pipe).
run_test() {
    lua5.1 tests/run_tests.lua "$TEST" > "$TMP/out.log" 2>&1
    echo $?
}

mutant() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-54s (the edit matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-54s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-54s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
        echo "            per its converse, first confirm the edit landed where you meant."
    fi
}

# --- M1: §DU.5 item 2 is edited back to the pre-#464 reading -----------------
# The exact defect GH #464 reported. The kept-frames ratio is the load-bearing
# NEGATIVE face of the harvest condition; reading it off the old corpus is how
# "armed drinks fewer wands" and "armed stops drinking wands" stay confusable.
m1() { perl -0pi -e 's/钉住 \*\*78\/81\*\*/钉住 **78\/80**/' "$ARCHIVE"; }
mutant "M1 item 2 reverted to the old kept-frames ratio" "$ARCHIVE" m1

# --- M2: §DU.5 item 3 is edited back to the mixed-unit rate ------------------
# §DU.8.2's finding. This clause is the DOMAIN-NOT-REACHED ruler, and the old
# value reads the domain ~2x SMALLER than it is -- the direction that makes a
# harvester accept a zero.
m2() { perl -0pi -e 's/命中率是 \*\*3\/81 = 3\.70%\*\*/命中率是 **2\/101**/' "$ARCHIVE"; }
mutant "M2 item 3 reverted to the mixed-unit rate" "$ARCHIVE" m2

# --- M3: the top-of-file harvest banner keeps the old rate -------------------
# The SECOND carrier. A test that only looked inside §DU.5 would call this
# green, and the banner is the copy a harvester meets first.
m3() { perl -0pi -e 's/最后一项本地命中率 \*\*3\/81 = 3\.70%\*\*/最后一项本地命中率只有 2\/101/' "$LIVE"; }
mutant "M3 the harvest banner keeps the old rate" "$LIVE" m3

# --- M4: the corpus grew; the census test was re-nailed, the archive was not --
# THE scenario this file exists for, and the one that really happened on 09-03.
# Nothing in the archive is edited at all -- the mutant is entirely in the
# measurement -- so only a test that DERIVES the archive's numbers can see it.
m4() { perl -0pi -e 's/cs\.ratchet\(#c\.fresh_frames, 81,/cs.ratchet(#c.fresh_frames, 82,/' "$CENSUS"; }
mutant "M4 fresh-frame ratchet moved, archive untouched" "$CENSUS" m4

# --- M5: the same, on the other ratchet --------------------------------------
# Both halves of the ratio have to be live. A file that read only the
# denominator would keep passing while the numerator drifted.
m5() { perl -0pi -e 's/cs\.ratchet\(#blocked, 3,/cs.ratchet(#blocked, 4,/' "$CENSUS"; }
mutant "M5 blocked-frame ratchet moved, archive untouched" "$CENSUS" m5

# --- M6: the superseded value is left STANDING, not demoted ------------------
# The mechanism of the original defect, isolated. Both numbers present, one of
# them no longer true, and no marker telling a reader which. An assertion that
# only checked "the new number is in there somewhere" passes this.
m6() { perl -0pi -e 's/⛔ 原写作 `78\/80`/⛔ 另见 `78\/80`/' "$ARCHIVE"; }
mutant "M6 old kept ratio left undemoted beside the live one" "$ARCHIVE" m6

# --- M7: a carrier is deleted outright ---------------------------------------
# Deleting the banner is not a fix for a stale banner. The assertion must fail
# on absence, not pass because there is nothing left to disagree with.
#
# ⚠️ The first draft of this mutant matched nothing and the stand said so:
# the pattern was written `/收割前必读(§DU\.5)/` with ASCII parens, while the
# archive uses the FULL-WIDTH pair -- three bytes each, no 0x28 anywhere. In
# byte-mode perl the ASCII `(` is a capture group, so the pattern asked for
# `收割前必读§DU.5`, which is in no file. Without the `cmp -s` NO-OP branch in
# `mutant` this would have printed CAUGHT-or-SURVIVED off a run that never
# mutated anything. Anchor on the plain phrase instead.
m7() { perl -ni -e 'print unless /收割前必读/' "$LIVE"; }
mutant "M7 the harvest banner line is deleted" "$LIVE" m7

# --- M8: right numerator, wrong denominator ----------------------------------
# The original defect's exact shape, re-introduced with today's numerator: a
# frame count over the victim/attacker-pair denominator. It LOOKS re-nailed.
m8() { perl -0pi -e 's/命中率是 \*\*3\/81 = 3\.70%\*\*/命中率是 **3\/102 = 2.94%**/' "$ARCHIVE"; }
mutant "M8 frame numerator over the pair denominator again" "$ARCHIVE" m8

echo
echo "baseline (unmutated tree):"
rc=$(run_test)
if [ "$rc" -eq 0 ]; then
    echo "  GREEN  exit=$rc"
else
    echo "  RED    exit=$rc -- the stand proves nothing until the baseline is green"
    cat "$TMP/out.log"
    exit 1
fi

echo
echo "$ncaught/$nrun caught"
[ "$ncaught" -eq "$nrun" ] || exit 1
