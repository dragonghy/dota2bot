#!/usr/bin/env python3
"""Contract test for tools/agent/token_usage.py (director, 2026-08-23, backlog 7b).

What is being pinned: one API response is written to a Claude Code transcript as
ONE RECORD PER CONTENT BLOCK, and every one of those records carries a copy of
the SAME `message.usage`.  Summing records therefore bills a multi-block
response two or three times.  Measured on the director's own transcript the day
this was found: 31 usage-bearing records for 17 distinct message.ids, all copies
byte-identical, 1.89x inflation on input and 1.99x on output.

Why a test and not just the fix: the number this tool prints is the input to the
weekly efficiency ledger's cross-group comparison, and the inflation factor is a
function of blocks-per-response -- so it is NOT a shared constant that cancels
out between groups.  A silent regression here does not produce an obviously
wrong number, it produces a plausible one that ranks the groups by how many
parallel tool calls they batch.

This test drives the REAL script as a subprocess and reads its real stdout.  It
does not import tally() and assert on it in isolation, because the failure mode
that started all of this (GH #67, and again in the fixture writer on 08-22) is a
fix that lands in a helper nothing on the shipping path calls.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, os.pardir, "tools", "agent", "token_usage.py")

failures = []


def check(cond, label):
    if cond:
        print("ok   " + label)
    else:
        print("FAIL " + label)
        failures.append(label)


def usage(inp, cache_read, cache_creation, out):
    return {"input_tokens": inp, "cache_read_input_tokens": cache_read,
            "cache_creation_input_tokens": cache_creation,
            "output_tokens": out}


def rec(msg_id, u, text="x"):
    return {"type": "assistant",
            "message": {"id": msg_id, "role": "assistant", "usage": u,
                        "content": [{"type": "text", "text": text}]}}


def write_transcript(path, records):
    with open(path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")


def run(*paths):
    proc = subprocess.run([sys.executable, SCRIPT, *paths],
                          capture_output=True, text=True)
    if proc.returncode != 0:
        raise AssertionError("script exited %d: %s" % (proc.returncode, proc.stderr))
    line = [ln for ln in proc.stdout.splitlines() if ln.startswith("TOKENS ")]
    assert len(line) == 1, "expected exactly one TOKENS line, got %r" % proc.stdout
    fields = dict(kv.split("=", 1) for kv in line[0].split()[1:])
    return {k: int(v.replace(",", "")) for k, v in fields.items()}, proc.stdout


# --- section 1: the fixture must actually contain the shape under test --------
# Anti-vacuity guard, written BEFORE the assertions it protects.  Without it a
# fixture that accidentally had no duplicate ids would pass against a
# non-deduping implementation, which is exactly the bug this file exists for.
U_MULTI = usage(100, 1000, 10, 50)
U_SOLO = usage(7, 70, 0, 3)
MULTI_BLOCKS = 3
records = ([rec("msg_multi", U_MULTI, "block%d" % i) for i in range(MULTI_BLOCKS)]
           + [rec("msg_solo", U_SOLO)]
           + [{"type": "user", "message": {"role": "user", "content": "hi"}}])

ids = [r["message"]["id"] for r in records if "usage" in (r.get("message") or {})]
check(len(ids) - len(set(ids)) == MULTI_BLOCKS - 1,
      "fixture really contains a %d-block response (else the test is vacuous)"
      % MULTI_BLOCKS)
check(len({json.dumps(r["message"]["usage"], sort_keys=True)
           for r in records[:MULTI_BLOCKS]}) == 1,
      "the duplicate blocks carry identical usage, as observed in the wild")

tmpdir = tempfile.mkdtemp(prefix="tokusage_")
p1 = os.path.join(tmpdir, "a.jsonl")
write_transcript(p1, records)

# --- section 2: dedupe on message.id ------------------------------------------
got, stdout = run(p1)
want_in = (U_MULTI["input_tokens"] + U_MULTI["cache_read_input_tokens"]
           + U_MULTI["cache_creation_input_tokens"]
           + U_SOLO["input_tokens"] + U_SOLO["cache_read_input_tokens"]
           + U_SOLO["cache_creation_input_tokens"])
want_out = U_MULTI["output_tokens"] + U_SOLO["output_tokens"]
naive_in = want_in + (MULTI_BLOCKS - 1) * (
    U_MULTI["input_tokens"] + U_MULTI["cache_read_input_tokens"]
    + U_MULTI["cache_creation_input_tokens"])

check(naive_in != want_in,
      "deduped and naive totals differ on this fixture (the test can fail)")
check(got["total_in"] == want_in,
      "total_in counts each response once (%d, not the naive %d)" % (want_in, naive_in))
check(got["out"] == want_out, "out counts each response once (%d)" % want_out)
check(got["turns"] == 2, "turns counts API responses, not content blocks")
check("usage_records: 4 (blocks; 2 duplicate)" in stdout,
      "the duplicate count is reported, so the raw number stays inspectable")

# --- section 3: ids must not merge ACROSS transcripts -------------------------
# Subagent transcripts are separate files; nothing guarantees the ids in them are
# globally unique, and merging two real responses would undercount.
p2 = os.path.join(tmpdir, "b.jsonl")
write_transcript(p2, [rec("msg_multi", U_SOLO)])
got2, _ = run(p1, p2)
check(got2["turns"] == 3, "same message.id in a second transcript is its own response")
check(got2["out"] == want_out + U_SOLO["output_tokens"],
      "cross-transcript id collision does not swallow tokens")

# --- section 4: records with no message.id are counted, not merged ------------
# Not observed in the wild; the format is not ours, so the undercounting
# direction is the one to refuse.
p3 = os.path.join(tmpdir, "c.jsonl")
write_transcript(p3, [{"type": "assistant", "message": {"usage": U_SOLO}},
                      {"type": "assistant", "message": {"usage": U_SOLO}}])
got3, stdout3 = run(p3)
check(got3["out"] == 2 * U_SOLO["output_tokens"],
      "unkeyed records are counted individually, never merged under a None key")
check("records without message.id: 2" in stdout3,
      "unkeyed records are called out rather than silently folded in")

print()
if failures:
    print("%d check(s) FAILED" % len(failures))
    sys.exit(1)
print("all checks passed")
