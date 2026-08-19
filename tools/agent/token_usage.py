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


def main():
    paths = sys.argv[1:] or find_transcripts()
    tot = {"input_tokens": 0, "output_tokens": 0,
           "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}
    turns = 0
    for path in paths:
        with open(path, errors="replace") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                usage = (rec.get("message") or {}).get("usage")
                if not isinstance(usage, dict):
                    continue
                turns += 1
                for k in tot:
                    v = usage.get(k)
                    if isinstance(v, (int, float)):
                        tot[k] += int(v)
    billed_in = (tot["input_tokens"] + tot["cache_read_input_tokens"]
                 + tot["cache_creation_input_tokens"])
    print(f"transcripts: {len(paths)}")
    print(f"model_turns: {turns}")
    print(f"input_tokens (uncached): {tot['input_tokens']:,}")
    print(f"cache_read_input_tokens: {tot['cache_read_input_tokens']:,}")
    print(f"cache_creation_input_tokens: {tot['cache_creation_input_tokens']:,}")
    print(f"output_tokens: {tot['output_tokens']:,}")
    print(f"TOKENS total_in={billed_in:,} out={tot['output_tokens']:,} "
          f"turns={turns}")


if __name__ == "__main__":
    main()
