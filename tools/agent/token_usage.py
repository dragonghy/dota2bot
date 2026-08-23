#!/usr/bin/env python3
"""Sum this session's token usage from its Claude Code transcript.

Each assistant turn in the transcript JSONL carries message.usage
(input_tokens, output_tokens, cache_read_input_tokens,
cache_creation_input_tokens). Summing them gives the session's total
consumption so far — run at the end of a work unit and paste the line
into the report.

Usage: python3 tools/agent/token_usage.py [transcript.jsonl ...]
Without arguments, sums ALL transcripts under ~/.claude/projects/ — in a
fresh Routine container that is exactly this run (main session plus any
subagents it spawned).

DEDUPLICATION (added 2026-08-23T00:51Z, director; backlog 7b).  One API
response is written to the transcript as ONE RECORD PER CONTENT BLOCK, and
every one of those records carries a copy of the SAME `message.usage`
object.  A response that emits a sentence of prose plus two parallel tool
calls therefore lands three usage-bearing records with identical numbers.
The pre-fix code summed records, so it billed that response three times.

Measured on the director's own 2026-08-23T00:51Z transcript: 31
usage-bearing records for 17 distinct `message.id`s, 0 of the 17 with
divergent usage across its copies, total inflation 1.89x on input and
1.99x on output.  That is the whole of the `turns=126` anomaly registered
as backlog 7b -- the scope was never wrong (one container, one run), the
COUNTING was.

Why this matters more than the size of the error: the inflation factor is
a function of BLOCKS PER RESPONSE, so it is not shared across groups.  A
tool-heavy round inflates more than a prose-heavy one, which means the raw
numbers systematically punish whichever group batches the most parallel
tool calls.  Any cross-group comparison built on the pre-fix numbers is
comparing counting artefacts, not work.

We dedupe on `message.id` and keep the FIRST copy.  Records with no
`message.id` (none observed, but the format is not ours) are counted
individually and reported separately rather than silently merged under a
`None` key -- merging them would undercount, which is the worse direction.
"""
import glob
import json
import os
import sys


def find_transcripts():
    home = os.path.expanduser("~")
    cands = glob.glob(os.path.join(home, ".claude", "projects", "*", "*.jsonl"))
    if not cands:
        sys.exit("no transcript found under ~/.claude/projects/")
    return sorted(cands)


FIELDS = ("input_tokens", "output_tokens",
          "cache_read_input_tokens", "cache_creation_input_tokens")


def tally(paths):
    """Return (totals, responses, records, unkeyed) over the given transcripts.

    `responses` counts distinct API responses (deduped on message.id);
    `records` counts usage-bearing JSONL lines, i.e. the pre-fix number.
    """
    tot = dict.fromkeys(FIELDS, 0)
    seen = set()
    records = 0
    unkeyed = 0
    for path in paths:
        with open(path, errors="replace") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                msg = rec.get("message") or {}
                usage = msg.get("usage")
                if not isinstance(usage, dict):
                    continue
                records += 1
                key = msg.get("id")
                if key is None:
                    unkeyed += 1
                else:
                    # (path, id) so two transcripts cannot collide on an id.
                    key = (path, key)
                    if key in seen:
                        continue
                    seen.add(key)
                for k in FIELDS:
                    v = usage.get(k)
                    if isinstance(v, (int, float)):
                        tot[k] += int(v)
    return tot, len(seen) + unkeyed, records, unkeyed


def main():
    paths = sys.argv[1:] or find_transcripts()
    tot, responses, records, unkeyed = tally(paths)
    billed_in = (tot["input_tokens"] + tot["cache_read_input_tokens"]
                 + tot["cache_creation_input_tokens"])
    print(f"transcripts: {len(paths)}")
    print(f"api_responses: {responses}")
    print(f"usage_records: {records} (blocks; {records - responses} duplicate)")
    if unkeyed:
        print(f"records without message.id: {unkeyed} (counted individually)")
    print(f"input_tokens (uncached): {tot['input_tokens']:,}")
    print(f"cache_read_input_tokens: {tot['cache_read_input_tokens']:,}")
    print(f"cache_creation_input_tokens: {tot['cache_creation_input_tokens']:,}")
    print(f"output_tokens: {tot['output_tokens']:,}")
    print(f"TOKENS total_in={billed_in:,} out={tot['output_tokens']:,} "
          f"turns={responses}")


if __name__ == "__main__":
    main()
