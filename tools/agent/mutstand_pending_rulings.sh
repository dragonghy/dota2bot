#!/usr/bin/env bash
# Mutation stand for the domain-price, domain-watch and owed-execution legs of
# tools/agent/pending_rulings.py (director 2026-09-01 §DH; owed leg 2026-09-02 §DR).
# Not part of any suite -- run by hand when either leg or
# tests/test_pending_rulings.py is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3), plus one this stand
# learned the hard way:
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- the test writes to a log file, and `$?` is
#     read with no pipe between it and the command;
#   * a mutant whose target string is absent ABORTS: a no-op edit that scores
#     as "caught" is the stand lying about what was on the bench;
#   * ⭐ __pycache__ IS PURGED BETWEEN MUTANTS. The first run of this stand
#     reported M8 as caught -- by M7's failure signature. The test imports
#     `pending_rulings` as a module, and a stale .pyc meant the mutant on the
#     bench was not the mutant in the interpreter. The conclusion ("caught")
#     was right and the reason was another mutant's: evidence-discipline 4,
#     found only because the wrong assertion named it.
#
# Usage: bash tools/agent/mutstand_pending_rulings.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/agent/pending_rulings.py
TEST=tests/test_pending_rulings.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_pr.XXXXXX")

cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }

restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || {
        echo "RESTORE FAILED -- $SRC does not match its pre-mutation checksum"; exit 2; }
}

# A stand that is interrupted between `apply_mutant` and `restore` leaves the
# MUTANT in the working tree, where the next `git add -A` commits it. That is
# not hypothetical: see GH #418 and iterations/state.json:slotdust_gh418_20260902
# -- an un-gated `<` -> `<=` reached main as part of a gated fix, and the round's
# own mutation log names that exact edit as a mutant it had applied. The trap
# makes the restore unconditional; the loop still calls restore explicitly, which
# is harmless because restore is idempotent.
trap restore EXIT

apply_mutant() {   # $1 = mutant id; writes the mutated source or exits non-zero
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # -- the domain price ---------------------------------------------------
    "M1": ('SUBJECT_FIELDS = ("axis", "question", "acceptance")',
           'SUBJECT_FIELDS = ("question",)'),
    "M2": ('HERO_FILE_IN_PROSE = re.compile(r"bots/BotLib/hero_([a-z_0-9]+)\\.lua")',
           'HERO_FILE_IN_PROSE = re.compile(r"npc_dota_hero_([a-z_0-9]+)")'),
    "M3": ("                if n == 0:", "                if False:"),
    "M5": ('''                print("      DOMAIN price UNCERTIFIABLE -- the corpus census could "
                      "not run; this line is NOT a clean read (subjects: %s)"
                      % ", ".join(subjects))
                continue''', "                continue"),
    # -- the domain watch ---------------------------------------------------
    "M6": ('if str(director.get("ruling") or "").strip().upper().startswith(HOLD_RULING):',
           "if False:"),
    "M7": ("    return 3 if (ride or orphans or unblocked) else 0",
           "    return 3 if (ride or orphans) else 0"),
    "M8": (".startswith(HOLD_RULING)", " is not None"),
    "M9": ('''for hero, n, _weak in (domain_price(r, counts, weak) if counts is not None
                                   else []):''',
           "for hero, n, _weak in domain_price(r, counts or {}, weak):"),
    # -- the owed-execution leg (§DR, 2026-09-02) ---------------------------
    # M10 is the one that matters most: it is the failure DIRECTION the leg
    # was built around -- an artefact that cannot be read must never read as
    # "the ruling was executed".
    "M10": ('        return "UNCERTIFIABLE", "could not read %s (%s)" % (rel, exc)',
            '        return "DONE", "could not read %s (%s)" % (rel, exc)'),
    "M11": ("    return 3 if finding else 0", "    return 0"),
    "M12": ('''        head = "  %-9s %-22s %-10s executor=%s" % (
            state, row.get("id", "?"), row.get("issue", "?"), row.get("executor", "?"))''',
            '''        head = "  %-9s %-22s" % (state, row.get("id", "?"))'''),
    "M13": ('''    if kind == "manual":
        return ("OWED",''',
            '''    if kind == "manual":
        return ("DONE",'''),
}
if mut == "M4":
    # the price reddens -- LIMIT 8's inverse, and the shape that turns a fact
    # to weigh into an every-round shout.
    old = "    return 3 if (ride or orphans or unblocked) else 0"
    new = ("    _price_red = any(n == 0 for r in (ride + other)\n"
           "                     for _h, n, _w in (domain_price(r, counts, weak) if counts else []))\n"
           "    return 3 if (ride or orphans or unblocked or _price_red) else 0")
else:
    old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

echo "== mutation stand: $SRC / $TEST"
worst=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13; do
    purge_pyc
    if ! apply_mutant "$m"; then
        echo "$m  APPLY-FAILED -- stand aborted rather than score a no-op as caught"
        restore; exit 2
    fi
    python3 "$TEST" > "$WORK/$m.log" 2>&1
    rc=$?                                  # bare: no pipe between test and $?
    sha=$(sha256sum "$SRC" | cut -c1-12)
    if [ "$rc" -eq 0 ]; then
        echo "$m  SURVIVED (sha=$sha) -- the tests do not pin this behaviour"
        worst=3
    else
        echo "$m  CAUGHT   (sha=$sha, exit $rc)"
    fi
    grep -E "^[0-9]+ checks|^FAIL" "$WORK/$m.log" | sed 's/^/       /'
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
rc=$?
echo "baseline after restore: exit $rc :: $(head -1 "$WORK/baseline.log")"
[ "$rc" -eq 0 ] || { echo "BASELINE RED after restore -- the stand left damage"; exit 2; }
exit $worst
