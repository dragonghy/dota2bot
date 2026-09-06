#!/usr/bin/env bash
# Mutation stand for tests/test_fn_body_boundaries.py (GH #547).
#
# A boundary test that passes proves nothing until a wrong boundary makes it
# fail.  Three mutants, each one a splitter put back the way it was before the
# fix that motivated this file:
#
#   M1  source_constants.function_body terminates at the next `^function`
#       (the pre-GH #547 shape -- over-reads whatever sits between).
#   M2  wkqdmg_domain._fn_body counts only a line that STARTS with `end`
#       (the pre-a2caace8 shape -- the 22-lines-read-as-567 incident).
#   M3  blinkflee_domain._fn_body drops its `\nend` anchor and takes the first
#       `end` anywhere (over-reads nothing, under-reads at the first one-line
#       block -- the opposite error, which must also be caught).
#
# RESTORE DISCIPLINE (GH #418 family, and the two stands the 09-06T01:19Z round
# found doing exactly this wrong): the pristine copies live OUTSIDE the temp
# dir the trap deletes, the EXIT trap CALLS restore, and the run ends by
# proving byte-identity with sha256sum.  A stand that can leave a mutant in the
# tree is worse than no stand.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BEHAV=tools/batch_test/behavioral
TEST=tests/test_fn_body_boundaries.py
SC=$BEHAV/source_constants.py
WKD=$BEHAV/wkqdmg_domain.py
BFD=$BEHAV/blinkflee_domain.py

BAK="$(mktemp -d)"          # holds the originals; NOT the dir the trap wipes
cp "$SC" "$BAK/sc.orig"
cp "$WKD" "$BAK/wkd.orig"
cp "$BFD" "$BAK/bfd.orig"
sha256sum "$SC" "$WKD" "$BFD" > "$BAK/manifest.sha256"

restore() {
    cp "$BAK/sc.orig" "$SC"
    cp "$BAK/wkd.orig" "$WKD"
    cp "$BAK/bfd.orig" "$BFD"
}
verify_restore() {
    sha256sum -c --quiet "$BAK/manifest.sha256" \
        && echo "restore verified (sha256 identical)" \
        || { echo "RESTORE FAILED -- the tree still holds a mutant"; return 1; }
}
# Armed only now that `restore` and the backups both exist, and BEFORE the
# first mutation: this is the whole window in which the trap has to be right.
trap 'restore; rm -rf "$BAK"' EXIT

run_test() { python3 "$TEST" >/dev/null 2>&1; echo $?; }

base=$(run_test)
if [ "$base" -ne 0 ]; then
    echo "UNCERTIFIABLE: the test is not green before any mutation (exit $base)"
    exit 2
fi
echo "baseline: PASS (exit 0)"

killed=0
survived=0
unlanded=0

mutate() {   # <label> <file> <python-inline-edit>
    local label="$1" file="$2" edit="$3"
    if ! python3 - "$file" <<PY
import sys, re
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
before = s
$edit
assert s != before, 'the edit changed nothing -- the anchor moved'
open(p, 'w', encoding='utf-8').write(s)
PY
    then
        # An edit that did not land is NOT a surviving mutant: nothing was
        # measured.  Saying "SURVIVED" here would report a test weakness that
        # does not exist (and hide one that might).
        echo "UNLANDED  $label  (the mutation never applied -- NOT a survivor, nothing measured)"
        restore
        unlanded=$((unlanded + 1))
        return
    fi
    local rc
    rc=$(run_test)
    if [ "$rc" -eq 0 ]; then
        echo "SURVIVED  $label  (test still exit 0 -- it does not measure this)"
        survived=$((survived + 1))
    else
        echo "KILLED    $label  (test exit $rc)"
        killed=$((killed + 1))
    fi
    restore
}

# M1 -- put the shared reader back on "next ^function".
mutate "M1 function_body terminates at the next ^function" "$SC" "
old = '''    return src[starts[0]:function_span(src, starts[0],
                                       '%s (%s)' % (func, os.path.basename(path)))]'''
new = '''    nxt = re.compile(r'^function\\\\s', re.M).search(src, starts[0] + 1)
    return src[starts[0]:nxt.start() if nxt else len(src)]'''
assert old in s, 'M1 anchor missing'
s = s.replace(old, new)
"

# M2 -- put wkqdmg back on \"only a line that starts with end closes\".
mutate "M2 wkqdmg counts only line-initial end" "$WKD" "
old = '    return len(_OPEN_RE.findall(line)), len(_END_RE.findall(line))'
new = ('    return (len(_OPEN_RE.findall(line)),\n'
       '            1 if line.lstrip().startswith(\'end\') else 0)')
assert old in s, 'M2 anchor missing'
s = s.replace(old, new)
"

# M3 -- blinkflee takes the first `end` anywhere, not the one at column 0.
# Written with chr(92) instead of a literal backslash: this edit passes through
# a shell heredoc, and an escaping slip there produces an edit that silently
# does nothing -- which is exactly what the UNLANDED branch above exists for.
mutate "M3 blinkflee anchors on any end, not a line-initial one" "$BFD" "
lines = s.split(chr(10))
for k, ln in enumerate(lines):
    if 're.escape(fname)' in ln:
        lines[k] = ln.replace(chr(92) + 'nend', 'end')
s = chr(10).join(lines)
"

echo
echo "KILLED=$killed SURVIVED=$survived UNLANDED=$unlanded"
verify_restore || exit 1
[ "$survived" -eq 0 ] && [ "$unlanded" -eq 0 ] || exit 1
exit 0
