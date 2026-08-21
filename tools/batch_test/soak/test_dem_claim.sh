#!/usr/bin/env bash
# Offline tests for dem_claim.sh ([harness] #75).
#
# What this CAN prove: the attribution logic itself -- that a slot claims its
# own file out of a pool of concurrent recorders, that two slots never claim the
# same file, that a single-recorder instance still behaves exactly as it did
# before #75, and that an unidentifiable file is left alone rather than guessed.
# What it CANNOT prove: that the Dota 2 dedicated server actually names its .dem
# in the console log, or stamps +hostname into the demo header. Those are the
# two facts the first REC_SLOTS=1 wave measures for free via the claim sidecar,
# and until one of them is confirmed the multi-recorder path claims nothing.
#
#   bash tools/batch_test/soak/test_dem_claim.sh
set -u
cd "$(dirname "$0")"
. ./dem_claim.sh

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export DEM_CLAIM_LOCK="$TMP/lock"
PASS=0; FAIL=0

ok() { # <name> <actual> <expected>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   $1"
    else FAIL=$((FAIL+1)); echo "  FAIL $1: got [$2] want [$3]"; fi
}
jget() { printf '%s' "$1" | python3 -c 'import json,sys;print(json.load(sys.stdin)[sys.argv[1]])' "$2"; }

# a .dem whose header carries a +hostname stamp, like the real recorder's would
mkdem() { mkdir -p "$(dirname "$1")"; { printf 'PBDEMS2\0'; printf 'soak_%s' "$2"; head -c 400 /dev/zero | tr '\0' 'x'; } > "$1"; }

echo "== 1. logname claim wins, and moves the file out of the pool =="
RD="$TMP/r1"; mkdir -p "$RD"
mkdem "$RD/auto-a.dem" 20260821_000000_slot1
mkdem "$RD/auto-b.dem" 20260821_000000_slot7
sleep 0.01; touch "$RD/auto-a.dem"          # slot 1's file is the NEWEST
J=$(dem_claim 7 20260821_000000_slot7 "$RD" "replays/auto-b.dem" 16 "$TMP/s7.dem")
ok "method"        "$(jget "$J" method)"    "logname"
ok "moved"         "$([ -s "$TMP/s7.dem" ] && echo yes)" "yes"
ok "left the pool" "$([ -e "$RD/auto-b.dem" ] && echo yes || echo no)" "no"
ok "did not touch the other slot's file" "$([ -s "$RD/auto-a.dem" ] && echo yes)" "yes"
ok "mtime would have been WRONG here"     "$(jget "$J" by_mtime)" "auto-a.dem"

echo "== 2. hostname claim when the log named nothing =="
RD="$TMP/r2"; mkdir -p "$RD"
mkdem "$RD/auto-a.dem" 20260821_000000_slot1
mkdem "$RD/auto-b.dem" 20260821_000000_slot7
sleep 0.01; touch "$RD/auto-a.dem"
J=$(dem_claim 7 20260821_000000_slot7 "$RD" "" 16 "$TMP/s7b.dem")
ok "method"   "$(jget "$J" method)" "hostname"
ok "the right file" "$(head -c 64 "$TMP/s7b.dem" | tr -d '\0' | grep -c slot7)" "1"

echo "== 3. more than one recorder + nothing identifies the file => NO claim =="
RD="$TMP/r3"; mkdir -p "$RD"
mkdem "$RD/auto-a.dem" someone_else
J=$(dem_claim 7 20260821_000000_slot7 "$RD" "" 16 "$TMP/s7c.dem")
ok "method"          "$(jget "$J" method)" "none"
ok "nothing shipped" "$([ -e "$TMP/s7c.dem" ] && echo yes || echo no)" "no"
ok "file left in place for the reaper" "$([ -s "$RD/auto-a.dem" ] && echo yes)" "yes"

echo "== 4. single recorder falls back to mtime = exactly the pre-#75 behaviour =="
RD="$TMP/r4"; mkdir -p "$RD"
mkdem "$RD/old.dem" whatever; sleep 0.01
mkdem "$RD/new.dem" whatever
J=$(dem_claim 1 20260821_000000_slot1 "$RD" "" 1 "$TMP/s1.dem")
ok "method"     "$(jget "$J" method)"    "mtime"
ok "newest won" "$(jget "$J" by_mtime)"  "new.dem"

echo "== 5. two slots racing the same pool cannot both win =="
RD="$TMP/r5"; mkdir -p "$RD"
mkdem "$RD/auto-a.dem" 20260821_000000_slot3
J3=$(dem_claim 3 20260821_000000_slot3 "$RD" "" 16 "$TMP/w3.dem")
J4=$(dem_claim 4 20260821_000000_slot3 "$RD" "" 16 "$TMP/w4.dem")   # same stamp on purpose
ok "first claims"        "$(jget "$J3" method)" "hostname"
ok "second finds it gone" "$(jget "$J4" method)" "none"
ok "one copy exists"     "$([ -e "$TMP/w3.dem" ] && [ ! -e "$TMP/w4.dem" ] && echo yes)" "yes"

echo "== 6. discarded/replays/ is searched too (the engine sometimes files it there) =="
RD="$TMP/r6"; mkdir -p "$RD/discarded/replays"
mkdem "$RD/discarded/replays/auto-d.dem" 20260821_000000_slot9
J=$(dem_claim 9 20260821_000000_slot9 "$RD" "" 16 "$TMP/s9.dem")
ok "method" "$(jget "$J" method)" "hostname"

echo "== 7. the reaper drops dead files and spares live ones =="
RD="$TMP/r7"; mkdir -p "$RD"
mkdem "$RD/live.dem" x
mkdem "$RD/dead.dem" x; touch -d '90 minutes ago' "$RD/dead.dem"
dem_reap "$RD" 20
ok "dead reaped" "$([ -e "$RD/dead.dem" ] && echo yes || echo no)" "no"
ok "live spared" "$([ -s "$RD/live.dem" ] && echo yes)" "yes"

echo "== 8. an empty pool is not an error =="
RD="$TMP/r8"; mkdir -p "$RD"
J=$(dem_claim 2 t "$RD" "" 1 "$TMP/s2.dem")
ok "method"     "$(jget "$J" method)"     "none"
ok "candidates" "$(jget "$J" candidates)" "0"

echo
echo "dem_claim: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
