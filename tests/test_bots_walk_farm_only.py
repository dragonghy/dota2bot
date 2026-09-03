#!/usr/bin/env python3
"""[ratchet] A test that walks `bots/` must not walk over the farm-only switches.

`bots/Customize/` holds two gitignored, farm-only, TRANSIENT files --
`soak_side.lua` (the gate switch) and `soak_pool.lua`.  Every gate test in this
suite creates and deletes the first one.  A scanner that LISTS it and then
OPENS it has a window between the two, and the caller's `assert(io.open(path))`
turns that window into a red whose text names a file the caller has no business
reading.  GH #365 §2 published exactly that red on three files, attributed it to
GH #229 (contention BETWEEN GATE TESTS) and routed the fix there -- where it is
still blocked.  It never needed to wait: those files are not gate tests, they
never write the switch, they only walk over it, and the walk is theirs.

WHY THIS FILE EXISTS RATHER THAN A THIRD ROUND OF FIXES.  The class has now
been counted three times and each count was different -- "18 call sites" (a
`grep "io.popen('find "`, too narrow), then "at least 17 of 23", then the real
answer.  A defect class whose SIZE nobody can state is a class that comes back;
this file is the instrument, kept, so the next arrival is a red rather than a
rediscovery.

HOW IT MEASURES (and the one place it does not).  Every `io.popen(...)`
argument in `tests/*.lua` is extracted with a paren/quote-balanced scan over
comment-stripped source, its file-local string constants are resolved, and each
fully-resolved command is then EXECUTED.  A command REACHES the switch
directory iff its real output contains `bots/Customize/general.lua` -- a
committed file that is always present, sitting in the same directory with the
same extension, so it stands in for the switches without this test having to
CREATE one.  Creating a real `soak_*` file to probe with would be the very
contention the rule exists to remove (and would break every walk that has not
been fixed yet, which is the wrong way round).

  LIMIT, stated because it is load-bearing: this measures the ENUMERATION, not
  the read.  `tests/test_ancient_hp_unit.lua` cannot use `find`'s `! -path`
  (it enumerates with an `ls` glob), so it closes the window on the READ side
  with `lua_source_scan.is_farm_only`; its command still reaches, legitimately,
  and it is named in READ_SIDE_FILTERED below.  A second entry there must be
  argued, not appended.

  LIMIT 2: a command built from a function PARAMETER (`'find ' .. dir ..`)
  cannot be resolved statically -- its value is whatever its callers pass.
  Those are not skipped: they are listed in UNRESOLVED_HAND_READ with the
  argument each caller actually passes, and an unresolved command that is NOT
  on that list is a FINDING.  A new walk therefore costs a hand read, which is
  the whole point; it cannot join the population in silence.

Run: python3 tests/test_bots_walk_farm_only.py
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TESTS = os.path.join(REPO, "tests")

# The literal is defined once, in tests/lua_source_scan.lua, and read from
# there -- a second copy of it is the defect this file's own subject warns
# about (four files that merely named the path in a COMMENT were swept into the
# switch-writer census as RAW on 2026-09-02).
SCANNER = os.path.join(TESTS, "lua_source_scan.lua")

# A file that is always present in the switches' own directory, used as their
# proxy so this test never has to create one.  See HOW IT MEASURES above.
PROXY = "bots/Customize/general.lua"

# `find`-shaped walks that legitimately reach and filter on the READ side.
READ_SIDE_FILTERED = {
    "tests/test_ancient_hp_unit.lua": "enumerates with an `ls` glob, which has "
    "no `! -path`; filters with lua_source_scan.is_farm_only before reading",
}

# Commands built from a parameter or a non-constant, hand-read on 2026-09-03.
# The value is what the call sites actually pass.
UNRESOLVED_HAND_READ = {
    # -- built from a function parameter: the value is whatever callers pass --
    """tests/test_botsinit_env_namespace.lua  ::  'find ' .. dir .. " -name '*.lua' -type f " .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' 2>/dev/null'""":
        "listLua('bots') x2 and listLua('tests/fixtures'); carries the clause",
    """tests/test_ckpush_minute_unit.lua  ::  'find ' .. dir .. ' -name "*.lua" ' .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' 2>/dev/null'""":
        "lua_files_under('bots'); carries the clause",
    """tests/test_tormself_identity_domain.lua  ::  "find " .. dir .. " -name '*.lua' " .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' | sort'""":
        "luaFiles('bots') x2 and luaFiles('tests/fixtures'); carries the clause",
    """tests/test_tpclaim_stamp_on_commit.lua  ::  'find ' .. dir .. ' -name "*.lua" ' .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' | sort'""":
        "lua_files_under('bots'); carries the clause",
    """tests/test_itemtrip_supply_gap.lua  ::  'ls "' .. dir .. '"'""":
        "ls('bots', ...) x2 and ls('tests/fixtures', ...); `ls \"bots\"` is NOT "
        "recursive, so it never reaches bots/Customize/ at all",
    """tests/run_tests.lua  ::  'ls "' .. root .. '"'""":
        "root == 'tests' (arg[0]'s directory)",
    """tests/test_wk_roshan_lategame_reconciliation.lua  ::  sCmd""":
        "glob_files(GLOB), GLOB == 'ls tests/fixtures/f_*.lua'",

    # -- corpus walks that never enter bots/ at all --------------------------
    """tests/test_cm_ult_reach_meter_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "dir in {tests/fixtures, tests/frames}",
    """tests/test_lion_ult_reserve_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "dir in {tests/fixtures, tests/frames}",
    """tests/test_wk_q_castrange_meter_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "dir in {tests/fixtures, tests/frames}",
    """tests/test_fixture_mana_price.lua  ::  'ls ' .. d .. ' 2>/dev/null'""":
        "d in {tests/fixtures, tests/frames}",
    """tests/test_level_premise_registry.lua  ::  'ls ' .. pattern .. ' 2>/dev/null'""":
        "ls('tests/*.lua')",

    # -- grep -r over bots/: a DIFFERENT failure mode, registered on purpose --
    # grep opens each file itself, so there is no list-then-open window and no
    # TOCTOU red.  What a switch could do here is MATCH and perturb a count --
    # content-dependent, not structural.  Neither pattern is a shape a
    # `return { side=..., cand=..., seed=... }` table can satisfy, so both are
    # clean today; the entry exists so the next reader does not have to
    # re-derive that this class is different rather than missed.
    'tests/test_abil1st_first_unit_reader.lua  ::  "grep -rn \'" .. pattern .. "\' bots/"':
        "count(pattern) over bots/, content-dependent, see the note above",
    'tests/test_abilanc_ancient_selector.lua  ::  "grep -rn \'" .. pattern .. "\' bots/"':
        "count(pattern) over bots/, content-dependent, see the note above",
}

checks = 0
failures = []


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        failures.append(msg)


def key_of(rel, expr):
    """Identity of a call site: file + the expression, whitespace-collapsed.

    THE LINE NUMBER IS NOT IN IT.  A key carrying a line number turns every
    unrelated edit above a site into a red -- GH #442 is that exact defect,
    filed the day before this file was written, and this file's first draft
    reproduced it within the hour.
    """
    return "%s  ::  %s" % (rel, " ".join(expr.split()))


def strip_comments(src):
    """Blank out `--` line comments, honouring quoted strings, keeping lines."""
    out, quote, i, n = [], None, 0, len(src)
    while i < n:
        c = src[i]
        if quote:
            out.append(c)
            if c == "\\" and i + 1 < n:
                i += 1
                out.append(src[i])
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            out.append(c)
        elif c == "-" and src[i + 1 : i + 2] == "-":
            while i < n and src[i] != "\n":
                i += 1
            out.append("\n")
            i += 1
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def popen_calls(src):
    """(lineno, argument expression) for every io.popen( ... ) in `src`."""
    out, key = [], "io.popen"
    at = src.find(key)
    while at != -1:
        j = at + len(key)
        while j < len(src) and src[j] in " \t":
            j += 1
        if src[j : j + 1] == "(":
            i, depth, quote, start = j + 1, 1, None, j + 1
            while i < len(src) and depth:
                c = src[i]
                if quote:
                    if c == "\\":
                        i += 1
                    elif c == quote:
                        quote = None
                elif c in "\"'":
                    quote = c
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if not depth:
                        break
                i += 1
            out.append((src.count("\n", 0, at) + 1, src[start:i]))
        at = src.find(key, at + len(key))
    return out


def split_concat(expr):
    """Top-level `..` operands of a Lua expression."""
    parts, buf, quote, i = [], "", None, 0
    while i < len(expr):
        c = expr[i]
        if quote:
            buf += c
            if c == "\\" and i + 1 < len(expr):
                i += 1
                buf += expr[i]
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            buf += c
        elif c == "." and expr[i + 1 : i + 2] == ".":
            parts.append(buf)
            buf = ""
            i += 1
        else:
            buf += c
        i += 1
    parts.append(buf)
    return parts


def resolve(expr, consts, clause, depth=0):
    if depth > 6:
        return None
    text = ""
    for part in split_concat(expr):
        p = part.strip()
        if not p:
            continue
        if len(p) > 1 and p[0] == p[-1] and p[0] in "\"'":
            body = p[1:-1]
            for a, b in (('\\"', '"'), ("\\'", "'"), ("\\\\", "\\")):
                body = body.replace(a, b)
            text += body
        elif p.endswith("FARM_ONLY_FIND_CLAUSE"):
            text += clause
        elif p in consts:
            sub = resolve(consts[p], consts, clause, depth + 1)
            if sub is None:
                return None
            text += sub
        else:
            return None
    return text


# --- the clause, read from its single definition ------------------------------
try:
    scanner_src = open(SCANNER, encoding="utf-8").read()
except OSError as exc:
    print("UNCERTIFIABLE -- cannot read %s: %s" % (SCANNER, exc))
    sys.exit(2)

clause = None
for line in scanner_src.splitlines():
    if line.startswith("M.FARM_ONLY_FIND_CLAUSE"):
        # Strip the OUTER quote only.  `.strip("'\"")` eats the clause's own
        # closing `"` as well, and the damage is silent: the ratchet still
        # works, but the repair instruction it prints is a shell fragment that
        # does not parse.
        clause = line.split("=", 1)[1].strip()
        if len(clause) > 1 and clause[0] == clause[-1] and clause[0] in "'\"":
            clause = clause[1:-1]
        break
if not clause:
    print("UNCERTIFIABLE -- lua_source_scan.lua no longer defines "
          "M.FARM_ONLY_FIND_CLAUSE; this test's premise is gone")
    sys.exit(2)
check("soak_" in clause, "the clause read back does not mention the switches: %r" % clause)

# --- premise: the proxy is where this test believes it is ---------------------
check(os.path.exists(os.path.join(REPO, PROXY)),
      "%s is gone -- the proxy for the switches no longer exists, so 'reaches' "
      "would answer no for every command and this ratchet would pass vacuously"
      % PROXY)

# --- scan ---------------------------------------------------------------------
reaching, unresolved, executed = [], [], 0
for name in sorted(os.listdir(TESTS)):
    if not name.endswith(".lua"):
        continue
    rel = "tests/" + name
    src = open(os.path.join(TESTS, name), encoding="utf-8").read()
    consts = {}
    for raw in strip_comments(src).splitlines():
        stripped = raw.strip()
        if stripped.startswith("local ") and "=" in stripped:
            head, _, val = stripped.partition("=")
            var = head[len("local "):].strip()
            if var.isidentifier():
                consts.setdefault(var, val.strip().rstrip(","))
    for lineno, expr in popen_calls(strip_comments(src)):
        cmd = resolve(expr, consts, clause)
        if cmd is None:  # try dropping a trailing top-level `, <message>`
            depth, quote, cut, i = 0, None, None, 0
            while i < len(expr):
                c = expr[i]
                if quote:
                    if c == "\\":
                        i += 1
                    elif c == quote:
                        quote = None
                elif c in "\"'":
                    quote = c
                elif c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
                elif c == "," and depth == 0:
                    cut = i
                    break
                i += 1
            if cut is not None:
                cmd = resolve(expr[:cut], consts, clause)
        if cmd is None:
            unresolved.append(key_of(rel, expr))
            continue
        if cmd.startswith("lua5.1 "):
            continue  # a sub-sweep: its own popens are separate rows
        try:
            proc = subprocess.run(["bash", "-c", cmd], cwd=REPO, timeout=60,
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired):
            unresolved.append(key_of(rel, expr))
            continue
        executed += 1
        if PROXY.encode() in proc.stdout and "soak_" not in cmd:
            reaching.append((rel, lineno, cmd))

# The scanner must have looked at something.  A census pointed at nothing
# reports zero findings and exits clean (GH #345), which here would read as
# "the class is gone" one edit after the extractor stopped matching.
check(executed >= 100,
      "only %d io.popen commands executed -- the extractor stopped matching, so "
      "'no findings' would mean 'nothing scanned'" % executed)

offenders = [r for r in reaching if r[0] not in READ_SIDE_FILTERED]
check(not offenders,
      "a tests/ walk reaches bots/Customize/ without excluding the farm-only "
      "switches -- add %s to the find, or filter with lua_source_scan."
      "is_farm_only, or route the walk through lua_source_scan.bots_files(): %s"
      % (clause, ["%s:%d" % (f, n) for f, n, _ in offenders]))

# The named read-side exception must still actually reach; if it stops
# reaching, the entry is stale and should be deleted rather than kept as a
# standing excuse.
still_reaching = {r[0] for r in reaching}
for path in READ_SIDE_FILTERED:
    check(path in still_reaching,
          "%s no longer reaches bots/Customize/ -- delete its READ_SIDE_FILTERED "
          "entry rather than leaving a standing exemption" % path)
    check("is_farm_only" in open(os.path.join(REPO, path), encoding="utf-8").read(),
          "%s is exempted on the grounds that it filters on the read side, and it "
          "no longer calls is_farm_only" % path)

new_unresolved = [u for u in unresolved if u not in UNRESOLVED_HAND_READ]
check(not new_unresolved,
      "a tests/ io.popen command cannot be resolved statically and is not on the "
      "hand-read list -- read it, then add it to UNRESOLVED_HAND_READ with the "
      "value its callers pass (do not delete this check): %s" % new_unresolved)

stale = [u for u in UNRESOLVED_HAND_READ if u not in unresolved]
check(not stale,
      "UNRESOLVED_HAND_READ names call sites that no longer exist (the line moved "
      "or the walk went away) -- re-read and update: %s" % stale)

print("%d checks, %d failed  [%d commands executed, %d unresolved]"
      % (checks, len(failures), executed, len(unresolved)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
