#!/usr/bin/env bash
# Mutation stand for tools/batch_test/soak/reclaim_blind.py: the `market` key
# that the GH #408 refill ruling requires (P1-P3, P6-P8) and the GH #412
# write-side diagnosis (P4, P5).  Director 2026-09-02.
# Run by hand when either of those or tests/test_reclaim_blind.py is edited.
#
# DISCIPLINE (inherited from mutstand_carrier_minion.sh, and each clause was
# paid for by a real mis-scoring):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * bare exit codes -- the test writes a log and `$?` is read with no pipe;
#   * a mutant whose target string is absent ABORTS rather than scoring caught;
#   * __pycache__ purged between mutants (the test imports the module, so a
#     stale .pyc makes the mutant on the stand a different program from the one
#     in the interpreter);
#   * a behavioural fingerprint decides INERT, and the probes below deliberately
#     include on-demand / mislabelled / drift rows -- a fingerprint that never
#     reaches the mutated branch cannot tell a no-op from a change.
#
# What this stand caught on its first run, in its own author's tests: P8
# SURVIVED.  The test for a typo'd market value ("ondemand") asserted only the
# exit code, and with the market vocabulary check deleted the row fell through
# to the spot path, tripped the GH #412 EC2-shape diagnosis, and exited 2 anyway
# -- the right conclusion reached by a reason that was not the one under test.
# The fix was a second row that has nothing else to trip on (a typo'd market
# carrying a valid SIR code), not a louder assertion on the first.
#
# Usage: bash tools/agent/mutstand_reclaim_market.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/batch_test/soak/reclaim_blind.py
TEST=tests/test_reclaim_blind.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_rb.XXXXXX")
cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }
restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || { echo "RESTORE FAILED"; exit 2; }
}

apply_mutant() {
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # P1: the default flips.  Every wave recorded before 2026-09-02 carries SIR
    #     codes and no `market`, so they all become self-contradicting rows.
    #     Loud, and wrong about ten flown waves.
    "P1": ('market = machine.get("market", MARKET_SPOT)',
           'market = machine.get("market", MARKET_ON_DEMAND)'),
    # P2: the contradiction check goes.  A spot machine mislabelled on-demand
    #     now passes, and its reclaim leaves the attribution clause -- this is
    #     the one direction that HIDES a BLINDED wave.
    "P2": ("        if code in KNOWN_CODES:\n            raise Undecidable(\n"
           '                "%s: market says on-demand but status_code %r is SIR "',
           "        if False:\n            raise Undecidable(\n"
           '                "%s: market says on-demand but status_code %r is SIR "'),
    # P3: an on-demand row may say nothing about how its machine ended.  The
    #     record stops being complete and nothing says so.
    "P3": ("        if code is None:\n            raise Undecidable(", "        if False:\n            raise Undecidable("),
    # P4: the GH #412 diagnosis is removed -- back to `unknown SIR status_code`,
    #     the sentence that pointed two rounds of reports at the market when the
    #     cause was our own harvest write.
    "P4": ("    if isinstance(code, str) and code.startswith(EC2_CODE_PREFIXES):",
           "    if False:"),
    # P5: the fallback GH #412 explicitly did NOT want: read the sibling key and
    #     answer anyway.  It is the cheapest mutant here and the only one that
    #     turns a drifting write convention into a supported one.
    "P5": ("    if isinstance(code, str) and code.startswith(EC2_CODE_PREFIXES):",
           "    if isinstance(machine.get('sir_status_code'), str):\n"
           "        return machine['sir_status_code']\n"
           "    if isinstance(code, str) and code.startswith(EC2_CODE_PREFIXES):"),
    # P6: the EC2-shape refusal is applied to on-demand rows too.  Over-broad:
    #     a legitimate refill (whose ONLY possible code is EC2 vocabulary) is
    #     refused, so the ruling's own machine can never be recorded.
    "P6": ("    if market == MARKET_ON_DEMAND:", "    if False:"),
    # P7: on-demand machines stop counting toward yield.  The refill buys a
    #     seed and the gate does not see it -- the wave reads BLINDED and the
    #     NEXT wave escalates too, off a seed we actually bought.
    "P7": ("    paired = ab > 0 and ba > 0",
           "    paired = ab > 0 and ba > 0 and market == MARKET_SPOT"),
    # P8: an unrecognised market value is silently read as spot instead of
    #     refused.  A typo in the harvest ("ondemand") then classifies the row
    #     under the wrong vocabulary.
    "P8": ('    if market not in KNOWN_MARKETS:', "    if False:"),
}
old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

# Behavioural fingerprint: what the module ANSWERS on six probe waves.  Probe 1
# is a pre-#408 wave (nothing may move there); 2-6 each reach one of the new
# branches.  Equal fingerprint = the stand edited text, not a program.
fingerprint() {
    python3 - <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), "tools", "batch_test", "soak"))
import reclaim_blind as rb

SELF, GONE = rb.SELF_TERMINATED, rb.RECLAIMED
EC2 = "Client.UserInitiatedShutdown"


def mach(seed, surv, code, ab, ba, depth=None, **extra):
    row = {"seed": seed, "survival_min": surv, "status_code": code,
           "ab": ab, "ba": ba}
    if depth is not None:
        row["arm_depth"] = depth
    row.update(extra)
    return row


PROBES = {
    # a pre-#408 wave: no `market` anywhere, must keep reading as spot
    "legacy": [mach(1, 55.0, SELF, 30, 15, 18.0), mach(2, 54.0, SELF, 28, 14, 17.0),
               mach(3, 5.4, GONE, 0, 0), mach(4, 50.0, SELF, 26, 13, 16.0)],
    # the wave GH #408 produces: a reclaim plus its on-demand refill
    "refilled": [mach(1, 55.0, SELF, 30, 15, 18.0), mach(2, 54.0, SELF, 28, 14, 17.0),
                 mach(3, 5.4, GONE, 0, 0),
                 mach(3, 50.0, EC2, 26, 13, 16.0, market="on-demand")],
    # the same wave without the refill: BLINDED, so "refilled" is a real answer
    "norefill": [mach(2, 54.0, SELF, 28, 14, 17.0), mach(3, 5.4, GONE, 0, 0)],
    # a spot machine wearing an on-demand label (the hiding direction)
    "mislabel": [mach(1, 55.0, SELF, 30, 15, 18.0),
                 mach(2, 5.4, GONE, 0, 0, market="on-demand")],
    # W36 as the harvest actually wrote it (GH #412)
    "drift": [mach(2745, 1.6, "Server.SpotInstanceTermination", 0, 0,
                   sir_status_code="instance-terminated-no-capacity"),
              mach(2838, 57.5, SELF, 42, 16, 18.0)],
    # an on-demand row with no code at all, and a typo'd market value
    "nocode": [{"seed": 1, "market": "on-demand", "survival_min": 50.0,
                "ab": 20, "ba": 10}],
    "badmarket": [mach(1, 50.0, EC2, 20, 10, 12.0, market="ondemand")],
}

for name, machines in PROBES.items():
    code, lines = rb.evaluate({"wave": name, "machines": machines})
    text = "\n".join(lines)
    tags = [t for t in ("BLINDED", "not blinded", "UNDECIDABLE", "WRITE-SIDE",
                        "contradicts itself", "unknown market",
                        "unknown SIR status_code", "on-demand")
            if t in text]
    yields = [ln.strip() for ln in lines
              if ln.strip().startswith(("yield", "attribution"))]
    print("%s=%d:%s:%s" % (name, code, "|".join(tags), "|".join(yields)))
PY
}

purge_pyc
fingerprint > "$WORK/fp.base" 2>&1

echo "== mutation stand: $SRC / $TEST"
worst=0
for m in P1 P2 P3 P4 P5 P6 P7 P8; do
    purge_pyc
    if ! apply_mutant "$m"; then
        echo "$m  APPLY-FAILED -- stand aborted rather than score a no-op as caught"
        restore; exit 2
    fi
    fingerprint > "$WORK/fp.$m" 2>&1
    if cmp -s "$WORK/fp.base" "$WORK/fp.$m"; then
        echo "$m  INERT -- the source changed and the behaviour did not; this is a"
        echo "       DEFECT IN THE STAND, not a finding about the tests"
        restore; worst=2; continue
    fi
    python3 "$TEST" > "$WORK/$m.log" 2>&1
    rc=$?
    sha=$(sha256sum "$SRC" | cut -c1-12)
    if [ "$rc" -eq 0 ]; then
        echo "$m  SURVIVED (sha=$sha) -- behaviour moved and no test noticed"
        worst=3
    else
        echo "$m  CAUGHT   (sha=$sha, exit $rc)"
    fi
    grep -E "^FAIL " "$WORK/$m.log" | head -4 | sed 's/^/       /'
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
rc=$?
echo "baseline after restore: exit $rc :: $(tail -1 "$WORK/baseline.log")"
[ "$rc" -eq 0 ] || { echo "BASELINE RED after restore"; exit 2; }
exit $worst
