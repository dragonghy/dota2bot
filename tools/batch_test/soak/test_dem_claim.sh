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
dem_reap "$RD" 20 2>/dev/null
ok "dead reaped" "$([ -e "$RD/dead.dem" ] && echo yes || echo no)" "no"
ok "live spared" "$([ -s "$RD/live.dem" ] && echo yes)" "yes"

echo "== 8. the reaper RESCUES a dead file before dropping it (#75 X.1 乙) =="
# a stub `aws` that records what it was asked to do instead of calling S3
cat > "$TMP/fakeaws" <<'STUB'
#!/usr/bin/env bash
echo "$@" >> "$FAKEAWS_LOG"
[ -n "${FAKEAWS_FAIL:-}" ] && exit 1
exit 0
STUB
chmod +x "$TMP/fakeaws"
export FAKEAWS_LOG="$TMP/aws.log"; : > "$FAKEAWS_LOG"
DEM_AWS="$TMP/fakeaws"
RD="$TMP/r9"; mkdir -p "$RD/discarded/replays"
mkdem "$RD/live9.dem" x
mkdem "$RD/dead9.dem" x;                       touch -d '90 minutes ago' "$RD/dead9.dem"
mkdem "$RD/discarded/replays/dead9b.dem" x;    touch -d '90 minutes ago' "$RD/discarded/replays/dead9b.dem"
SUM=$(dem_reap "$RD" 20 "s3://bkt/soak/run7" 2>&1 >/dev/null)
ok "summary counts both"   "$SUM" "dem_reap: rescued=2 upload_failed=0 dropped=0"
ok "uploaded under unattributed/, keyed by the file's own basename" \
   "$(grep -c 's3 cp .*dead9.dem s3://bkt/soak/run7/unattributed/dead9.dem --quiet' "$FAKEAWS_LOG")" "1"
ok "the discarded/ one too"  \
   "$(grep -c 's3 cp .*discarded/replays/dead9b.dem s3://bkt/soak/run7/unattributed/dead9b.dem' "$FAKEAWS_LOG")" "1"
ok "no tagging call at all (the instance profile has no s3:PutObjectTagging)" \
   "$(grep -c 'put-object-tagging' "$FAKEAWS_LOG")" "0"
ok "rescued file then dropped" "$([ -e "$RD/dead9.dem" ] && echo yes || echo no)" "no"
ok "live file never uploaded"  "$(grep -c live9 "$FAKEAWS_LOG")" "0"
ok "live file spared"          "$([ -s "$RD/live9.dem" ] && echo yes)" "yes"

echo "== 9. a failed upload keeps the file for the next pass, but not forever =="
export FAKEAWS_FAIL=1
RD="$TMP/r10"; mkdir -p "$RD"
mkdem "$RD/recent.dem" x; touch -d '30 minutes ago' "$RD/recent.dem"    # dead, < hard age
mkdem "$RD/ancient.dem" x; touch -d '600 minutes ago' "$RD/ancient.dem" # past hard age
SUM=$(dem_reap "$RD" 20 "s3://bkt/soak/run7" 2>&1 >/dev/null)
ok "summary"              "$SUM" "dem_reap: rescued=0 upload_failed=2 dropped=1"
ok "retried next pass"    "$([ -s "$RD/recent.dem" ] && echo yes)" "yes"
ok "disk not leaked"      "$([ -e "$RD/ancient.dem" ] && echo yes || echo no)" "no"
unset FAKEAWS_FAIL
DEM_AWS=aws

echo "== 10. an empty pool is not an error =="
RD="$TMP/r8"; mkdir -p "$RD"
J=$(dem_claim 2 t "$RD" "" 1 "$TMP/s2.dem")
ok "method"     "$(jget "$J" method)"     "none"
ok "candidates" "$(jget "$J" candidates)" "0"

echo "== 11. bulk .dem prefix: retention lives in the key, not in a tag =="
ok "REC_SLOTS=1 returns the prefix untouched (pre-#75 key, never expires)" \
   "$(dem_bulk_prefix 's3://bkt/soak/spot_2026_1_abc' 1)" "s3://bkt/soak/spot_2026_1_abc"
ok "default arg is 1 too" \
   "$(dem_bulk_prefix 's3://bkt/soak/spot_2026_1_abc')" "s3://bkt/soak/spot_2026_1_abc"
ok "REC_SLOTS>1 moves the run under the expiring dem21/ tree" \
   "$(dem_bulk_prefix 's3://bkt/soak/spot_2026_1_abc' 16)" "s3://bkt/dem21/spot_2026_1_abc"
ok "the bucket is carried over, not hardcoded" \
   "$(dem_bulk_prefix 's3://other-bucket/soak/r1' 4)" "s3://other-bucket/dem21/r1"
ok "a prefix that is not under soak/ is still moved whole, not mangled" \
   "$(dem_bulk_prefix 's3://bkt/elsewhere/r1' 4)" "s3://bkt/dem21/elsewhere/r1"
# The per-game archive the replay stream depends on must NEVER move: only the
# .dem upload and the reaper take the bulk prefix.
ok "soak_loop uploads the per-game archive to S3_PREFIX" \
   "$(grep -c 'aws s3 cp .*analysis_\$TAG.json "\$S3_PREFIX/\$TAG.analysis.json"' soak_loop.sh)" "1"
ok "soak_loop uploads the .dem to DEM_PREFIX" \
   "$(grep -c 'aws s3 cp "\$MINE" "\$DEM_PREFIX/\$TAG.dem"' soak_loop.sh)" "1"
ok "soak_loop reaps into DEM_PREFIX" \
   "$(grep -c 'dem_reap "\$REPLAYDIR" \$((GAME_CAP_MIN + 5)) "\$DEM_PREFIX"' soak_loop.sh)" "1"
ok "soak_loop no longer makes a call the instance profile cannot make" \
   "$(grep -c 'put-object-tagging' soak_loop.sh)" "0"

echo
echo "dem_claim: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
