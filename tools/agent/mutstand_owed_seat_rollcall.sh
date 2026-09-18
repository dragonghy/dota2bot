#!/usr/bin/env bash
# Mutation stand for INVARIANT 7 of tests/test_pending_rulings.py (the owed-by-seat
# roll-call and the --executor view; director 2026-09-18, [harness] baton 1 from
# iterations/reports/replay-check/20260918T184821Z.md §四).
#
# The question is the only one worth asking about a new view: CAN IT GO RED, and
# red for the RIGHT reason?  The four mutants below are the four ways this view
# can be wrong while still printing a full, plausible table -- which is exactly
# how the defect it was built against (73 undifferentiated OWED lines) reads.
#
# Restore is by FILE COPY + `sha256sum -c`, never by re-applying an inverse edit
# (evidence-discipline rule 1), and every exit code is read BARE -- no pipe
# stands between a command and `$?` (rule 3).  CONTROL must be green before any
# mutant is believed (rule 2).
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 2

TOOL=tools/agent/pending_rulings.py
SUITE=tests/test_pending_rulings.py
BAK="$(mktemp -d)"
cp "$TOOL" "$BAK/tool.py" || exit 2
( cd "$BAK" && sha256sum tool.py > sums.txt ) || exit 2

caught=0
survived=0
aborted=0

restore() {
    cp "$BAK/tool.py" "$TOOL" || exit 2
    ( cd "$BAK" && sha256sum -c --status sums.txt ) || {
        echo "ABORT: restore did not reproduce the original bytes"
        exit 2
    }
}

# GH #418: the copy-back is the ONLY thing standing between this stand and a
# committed mutant, so it is armed BEFORE the first mutation and stays armed.
trap restore EXIT

run_suite() {
    python3 "$SUITE" > "$BAK/out.txt" 2>&1
    echo $?
}

mutate() {  # mutate <label> <file> <python snippet that edits it>
    local label="$1" file="$2" code="$3"
    python3 - "$file" <<PY
# -*- coding: utf-8 -*-
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
orig = s
$code
if s == orig:
    sys.exit(7)
io.open(p, "w", encoding="utf-8").write(s)
PY
    local rc=$?
    if [ "$rc" -eq 7 ]; then
        echo "ABORT $label: byte-identical file -- the anchor is gone, not the mutant"
        aborted=$((aborted + 1))
        return 1
    fi
    if [ "$rc" -ne 0 ]; then
        echo "ABORT $label: mutator failed with $rc"
        aborted=$((aborted + 1))
        return 1
    fi
    return 0
}

verdict() {  # verdict <label> <exit code>
    local label="$1" rc="$2"
    if [ "$rc" -ne 0 ]; then
        echo "CAUGHT   $label (suite exit $rc)"
        caught=$((caught + 1))
    else
        echo "SURVIVED $label (suite exit 0) -- suspect the ASSERTION, not the mutant"
        survived=$((survived + 1))
    fi
}

# --- CONTROL -----------------------------------------------------------------
rc=$(run_suite)
if [ "$rc" -ne 0 ]; then
    echo "ABORT: CONTROL is red (exit $rc); nothing below would mean anything"
    tail -5 "$BAK/out.txt"
    restore
    exit 2
fi
echo "CONTROL  green (exit 0)"

# --- M1: the head cut disappears (whole-field match) -------------------------
# THE founding defect.  `gh290_...`'s executor prose names 批测台 /
# `director.executor` / `hero-20` inside the clause explaining why the OLD
# two-stream routing meant nobody -- so a whole-field reader files the one row
# RULING 77 disambiguated under FOUR seats, and prints a full table doing it.
if mutate M1 "$TOOL" '
s = s.replace("    head = raw[:cut].strip()\n    return head or raw.strip()",
              "    return raw.strip()", 1)
'; then
    verdict "M1 executor matched over the whole prose field" "$(run_suite)"
fi
restore

# --- M2: the token boundaries go (queue ids read as seats) -------------------
if mutate M2 "$TOOL" '
s = s.replace(r"(?<![a-z_-])hero(?![a-z0-9_-])", "hero", 1)
s = s.replace(r"(?<![a-z_.-])director(?![a-z0-9_.-])", "director", 1)
'; then
    verdict "M2 queue-id citations read as assignments" "$(run_suite)"
fi
restore

# --- M3: the roll-call follows the filter ------------------------------------
# The quiet one: every line still prints, the numbers are just the filtered
# population -- i.e. "my seat is clean" wearing "the registry is clean".
if mutate M3 "$TOOL" '
s = s.replace("    for row in hidden_rows:\n", "    for row in []:\n", 1)
'; then
    verdict "M3 roll-call + exit code computed over the filtered set" "$(run_suite)"
fi
restore

# --- M4: DONE rows counted as owed -------------------------------------------
# Failure direction is the point: a stream\x27s one number goes UP as its work
# lands, so the table rewards nobody and is eventually ignored.
if mutate M4 "$TOOL" '
s = s.replace("""    open_states = [e for e in entries if e[1] not in ("DONE", "IN-FLIGHT")]""",
              "    open_states = list(entries)", 1)
'; then
    verdict "M4 DONE rows inflate a seat's owed count" "$(run_suite)"
fi
restore

# --- M5: the filter stops being fail-open ------------------------------------
# An UNROUTED row is one nobody is pointed at; hiding it behind a filter gives
# a baton with no owner a second reason to be missed.
if mutate M5 "$TOOL" '
s = s.replace("            if executor in seats or not seats:",
              "            if executor in seats:", 1)
'; then
    verdict "M5 --executor hides the UNROUTED rows" "$(run_suite)"
fi
restore

echo "STAND caught=$caught survived=$survived aborted=$aborted"
[ "$survived" -eq 0 ] && [ "$aborted" -eq 0 ] && exit 0
exit 3
