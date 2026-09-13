#!/usr/bin/env bash
# Mutation stand for `cmcreepclock` (tests/test_cm_w_creep_clock.lua).
#
# Evidence discipline:
#   * the tree is restored from a FILE COPY, never from `git checkout` (a stand
#     that restores through git silently launders an unrelated dirty edit);
#   * the verdict reads the runner's own "N tests, M failures" COUNT, never a
#     line substring -- "10 failures" contains "0 failures" (GH #154);
#   * M0 is a deliberate NO-OP control: a stand on which every mutant dies,
#     including one that changed nothing, is measuring the harness and not the
#     assertions.
set -u

SRC=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_w_creep_clock.lua
TMP=$(mktemp -d)
cp "$SRC" "$TMP/src.bak"
restore() { cp "$TMP/src.bak" "$SRC"; }
trap 'restore; rm -rf "$TMP"' EXIT

run() {
  lua5.1 -e "
    local ok, t = pcall(dofile, '$TEST')
    if not ok then io.stderr:write('0 tests, 1 failures\n') os.exit(0) end
    local p, f = 0, 0
    for _, fn in pairs(t) do
      if pcall(fn) then p = p + 1 else f = f + 1 end
    end
    io.stderr:write(('%d tests, %d failures\n'):format(p + f, f))
  " 2>&1 >/dev/null
}

fails() { run | sed -n 's/.*, \([0-9][0-9]*\) failures/\1/p'; }

mutate() { # name  perl-expression  expect(CAUGHT|SURVIVED)
  local name="$1" expr="$2" expect="$3"
  restore
  perl -0pi -e "$expr" "$SRC"
  if cmp -s "$SRC" "$TMP/src.bak" && [ "$expect" = CAUGHT ]; then
    echo "  !! $name: MUTATION DID NOT APPLY (needle missed) -- not a result"
    BAD=$((BAD+1)); return
  fi
  local n; n=$(fails)
  local got=CAUGHT; [ "$n" = 0 ] && got=SURVIVED
  if [ "$got" = "$expect" ]; then
    echo "  ok $name: $got ($n failures)"
    OK=$((OK+1))
  else
    echo "  !! $name: expected $expect, got $got ($n failures)"
    BAD=$((BAD+1))
  fi
}

OK=0; BAD=0
echo "mutation stand: cmcreepclock"

restore
base=$(fails)
[ "$base" = 0 ] || { echo "  !! baseline is not green ($base failures)"; exit 3; }
echo "  ok M-base: clean tree is green (0 failures)"
OK=$((OK+1))

mutate "M0 no-op control (comment text only)" \
  "s/turbo value that halves it\./turbo value that halves it (control)./" SURVIVED

mutate "M1 lever made a no-op (turbo == shipped)" \
  "s/X\.nWCreepClockTurbo   = 5 \* 60/X.nWCreepClockTurbo   = 10 * 60/" CAUGHT

mutate "M2 direction inverted (turbo > shipped)" \
  "s/X\.nWCreepClockTurbo   = 5 \* 60/X.nWCreepClockTurbo   = 15 * 60/" CAUGHT

mutate "M3 turbo conjunct dropped (fires in normal mode)" \
  "s/if J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'cmcreepclock' \)/if J.IsSoakCandidate( 'cmcreepclock' )/" CAUGHT

mutate "M4 legs swapped (armed returns the shipped threshold)" \
  "s/return DotaTime\(\) > X\.nWCreepClockTurbo/return DotaTime() > X.nWCreepClockShipped/" CAUGHT

mutate "M5 unarmed leg no longer the shipped expression" \
  "s/return DotaTime\(\) > X\.nWCreepClockShipped\n\nend/return DotaTime() > X.nWCreepClockTurbo\n\nend/" CAUGHT

mutate "M6 gate names another lever's id" \
  "s/J\.IsSoakCandidate\( 'cmcreepclock' \)/J.IsSoakCandidate( 'cmtfclock' )/" CAUGHT

mutate "M7 one call site reverted to the bare literal" \
  "s/and \( X\.cm_IsCreepClockOpen\(\)\n\t\t\t\tor \( nEnemysStrongestCreeps2/and ( DotaTime() > 10 * 60\n\t\t\t\tor ( nEnemysStrongestCreeps2/" CAUGHT

mutate "M8 both call sites reverted to the bare literal" \
  "s/X\.cm_IsCreepClockOpen\(\)/DotaTime() > 10 * 60/g" CAUGHT

mutate "M9 shipped constant retuned (header/test say 10*60)" \
  "s/X\.nWCreepClockShipped = 10 \* 60/X.nWCreepClockShipped = 8 * 60/" CAUGHT

mutate "M10 gate-inside-a-gate (second soak call in the helper)" \
  "s/	if J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'cmcreepclock' \)/	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmcreepclock' ) and J.IsSoakCandidate( 'cmfarcreep' )/" CAUGHT

restore
echo
echo "mutstand cmcreepclock: $OK/$((OK+BAD))"
[ "$BAD" -eq 0 ] || exit 3
