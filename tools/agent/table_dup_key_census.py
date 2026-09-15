#!/usr/bin/env python3
"""Census: duplicate explicit keys inside one Lua table constructor.

Shape class (backlog 0NEXT24): "syntactically legal but semantically always
wrong".  `{ [4] = a, [4] = b }` is valid Lua 5.1 -- the parser keeps the LAST
assignment and the earlier value is silently gone.  Neither automatic reader on
the push gate can see it: luacheck is a linter and says nothing about the
*semantics* of a table constructor, and the smoke loader only asks whether the
file loads (it does).  So the hit count is part of the conclusion:
1 hit = a typo, 50 hits = a convention we would be misreading.

Brace-accurate, not an indentation heuristic: comments and string literals are
blanked (newlines preserved, so line numbers stay true), then brace/paren depth
is tracked and a key is only parsed where a field can actually start.

Exit codes: 0 = no duplicates, 3 = duplicates found, 2 = could not run.
"""

import re
import sys
from pathlib import Path

IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def blank_comments_and_strings(src):
    """Replace comments/strings with spaces, preserving length and newlines."""
    out = list(src)
    i, n = 0, len(src)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    def long_bracket(start):
        """If src[start] opens a long bracket [=*[, return (level, body_start)."""
        if src[start] != "[":
            return None
        j = start + 1
        eq = 0
        while j < n and src[j] == "=":
            eq += 1
            j += 1
        if j < n and src[j] == "[":
            return eq, j + 1
        return None

    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            lb = long_bracket(i + 2)
            if lb:
                eq, body = lb
                close = src.find("]" + "=" * eq + "]", body)
                end = n if close < 0 else close + eq + 2
            else:
                nl = src.find("\n", i)
                end = n if nl < 0 else nl
            blank(i, end)
            i = end
        elif c in "'\"":
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c or src[j] == "\n":
                    j += 1
                    break
                j += 1
            blank(i, min(j, n))
            i = min(j, n)
        elif c == "[":
            lb = long_bracket(i)
            if lb:
                eq, body = lb
                close = src.find("]" + "=" * eq + "]", body)
                end = n if close < 0 else close + eq + 2
                blank(i, end)
                i = end
            else:
                i += 1
        else:
            i += 1
    return "".join(out)


def scan(src):
    """Return [(line, key, first_line)] for every duplicate key in one table."""
    code = blank_comments_and_strings(src)
    assert len(code) == len(src), "blanking must preserve offsets"
    n = len(code)
    line_of = [0] * (n + 1)
    ln = 1
    for i, ch in enumerate(code):
        line_of[i] = ln
        if ch == "\n":
            ln += 1
    line_of[n] = ln

    stack = []  # each: {"keys": {key: line}, "depth": paren/bracket depth}
    field_start = False
    dups = []
    i = 0
    while i < n:
        c = code[i]
        if c.isspace():
            i += 1
            continue

        top = stack[-1] if stack else None

        if c == "{":
            stack.append({"keys": {}, "depth": 0})
            field_start = True
            i += 1
            continue
        if c == "}":
            if stack:
                stack.pop()
            field_start = False
            i += 1
            continue
        if top and c in "([":
            # A '[' here is only an index/expression: a field-start '[' is
            # consumed by the key parser below before we ever reach this line.
            if not (c == "[" and field_start):
                top["depth"] += 1
                field_start = False
                i += 1
                continue
        if top and c in ")]":
            if top["depth"] > 0:
                top["depth"] -= 1
            field_start = False
            i += 1
            continue
        if top and c in ",;" and top["depth"] == 0:
            field_start = True
            i += 1
            continue

        if field_start and top and top["depth"] == 0:
            key, j = parse_key(code, i, src)
            field_start = False
            if key is not None:
                if key in top["keys"]:
                    dups.append((line_of[i], key, top["keys"][key]))
                else:
                    top["keys"][key] = line_of[i]
                i = j
                continue
        field_start = False
        i += 1
    return dups


def parse_key(code, i, src):
    """Parse `[expr] =` or `name =` at i. Return (key, index_after_'=').

    Structure is read off `code` (comments/strings blanked) but the key TEXT is
    sliced out of `src`: blanking turns `["foo"]` into `[     ]`, so reading the
    key off `code` would collapse every distinct string key to one empty key --
    which reads back as a pile of duplicates that are not there.
    """
    n = len(code)
    if code[i] == "[":
        depth, j = 0, i
        while j < n:
            if code[j] == "[":
                depth += 1
            elif code[j] == "]":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j >= n:
            return None, i
        inner = src[i + 1 : j].strip()
        k = j + 1
        while k < n and code[k].isspace():
            k += 1
        if k < n and code[k] == "=" and not code.startswith("==", k):
            return "[%s]" % re.sub(r"\s+", "", inner), k + 1
        return None, i

    m = IDENT.match(code, i)
    if m:
        k = m.end()
        while k < n and code[k].isspace():
            k += 1
        if k < n and code[k] == "=" and not code.startswith("==", k):
            return m.group(0), k + 1
    return None, i


def main(argv):
    roots = argv[1:] or ["bots"]
    files = []
    for r in roots:
        p = Path(r)
        files.extend(sorted(p.rglob("*.lua")) if p.is_dir() else [p])

    total = 0
    for f in files:
        try:
            src = f.read_text(encoding="utf-8", errors="replace")
        except OSError as e:
            print("CENSUS could-not-run: %s: %s" % (f, e))
            return 2
        for line, key, first in scan(src):
            total += 1
            print("%s:%d: duplicate key %s in one constructor (first at :%d)"
                  % (f, line, key, first))

    print("CENSUS scanned=%d files, duplicate_keys=%d" % (len(files), total))
    return 3 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
