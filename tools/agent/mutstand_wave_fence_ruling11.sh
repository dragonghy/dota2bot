#!/usr/bin/env bash
# Mutation stand for RULING 11 (wave_fence.py: the standing-ruling registry),
# director 2026-09-10, GH #729.
# Discipline 1: restore from a FILE COPY, not an inverse edit.
#
# What these mutants are: RULING 10 built a channel whose default state is
# SILENCE -- three flags an operator has to recall and retype every round.
# Two hours after the $85 ruling was granted, the desk ran the gate with no
# flags, was refused, and filed "本台不预支".  So the registry has to be read
# by the tool, and -- this is the half that is easy to lose -- it has to SPEAK
# on every run, including when what it found was nothing or something dead.
# Each mutant is a way of making the registry quiet again, or of making it a
# laxer set of rules than the flags it replaces.
#
#   M1  the registry is never read by main() -- the loader exists, is tested,
#       and nothing calls it.  THE ORIGINAL DEFECT'S OWN SHAPE.
#   M2  an EXPIRED record is skipped SILENTLY.  LOAD-BEARING: a dead ruling
#       that says nothing is indistinguishable from a ruling never made, which
#       is 21:18Z again with the director on the wrong side of it.
#   M3  a MISSING registry is silent (same defect, the commoner input).
#   M4  the registry path skips build_crossing -- i.e. it becomes a second,
#       laxer set of rules and a record can name a number above the brake.
#   M5  two rulings in force silently pick one instead of refusing.
#   M6  a malformed registry is treated as "no ruling" instead of exit 2 --
#       a guess, in the direction of "we know nothing is in force".
#   M7  an expired FLAG stops being exit 2, i.e. the deliberate asymmetry
#       collapses in the permissive direction (Ruling 10, constraint 2).
#   M8  the refusal line goes back to demanding a ruling "that round".  THE
#       PROSE MUTANT: no arithmetic moves, and this sentence is what actually
#       blocked the wave.
#   M9  --no-crossing-file stops calling itself a skip (a skip that reads as
#       a finding of none).
set -u
SRC=tools/batch_test/soak/wave_fence.py
CP=$(mktemp /tmp/wave_fence.r11.orig.XXXXXX.py)
cp "$SRC" "$CP"

# GH #418: the trap goes in BEFORE the first mutant, not after the last one.
SUM=$(mktemp /tmp/wave_fence.r11.sum.XXXXXX)
sha256sum "$SRC" > "$SUM"
restore() { cp "$CP" "$SRC"; }
trap restore EXIT

run() {  # run() <label>
  out=$(python3 tests/test_wave_fence.py 2>&1); rc=$?
  echo "$1: rc=$rc  $(echo "$out" | tail -1)"
  echo "$out" | grep -E '^FAIL' | sed 's/^/    /'
}

run "CONTROL (unmutated)"

# M1 -- THE ORIGINAL DEFECT'S OWN SHAPE: the loader is written, is unit
# tested, and main() never reaches it.  Ruling 10 died of exactly this one
# level up (a channel nothing dialled), so it is mutant number one here.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "        elif standing is not None:\n            crossing = standing"
assert s.count(old) == 1, "M1 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "        elif standing is not None:\n            pass")
open(p,"w").write(s)
PY
run "M1 (main reads the registry, then drops what it found)"
cp "$CP" "$SRC"

# M2 -- LOAD-BEARING.  An expired record is skipped without a word.  The
# arithmetic is untouched and correct; the run simply stops saying that a
# ruling the director wrote has died.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '    for rec, when in expired:\n        notes.append("crossing registry: ruling %s EXPIRED at %s (now %s) -- "'
assert s.count(old) == 1, "M2 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, '    for rec, when in []:\n        notes.append("crossing registry: ruling %s EXPIRED at %s (now %s) -- "')
open(p,"w").write(s)
PY
run "M2 (an expired ruling dies silently)"
cp "$CP" "$SRC"

# M3 -- the same defect on the commoner input: no registry at all, no line.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '        notes.append("crossing registry: none at %s -- no standing ruling. "'
assert s.count(old) == 1, "M3 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, '        _unused = ("crossing registry: none at %s -- no standing ruling. "')
open(p,"w").write(s)
PY
run "M3 (a missing registry says nothing)"
cp "$CP" "$SRC"

# M4 -- the registry becomes a laxer channel than the flags: no
# build_crossing, so Ruling 10's four constraints hold on one path only.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '''    crossing, err = build_crossing(rec["ceiling"], rec["ref"], rec["expiry"],
                                   brake=brake, owner_line=owner_line,
                                   now=moment)'''
assert s.count(old) == 1, "M4 anchor is not unique -- refusing to mutate blind"
new = '''    crossing, err = ({"ceiling": float(rec["ceiling"]),
                      "ref": str(rec["ref"]).strip(),
                      "expiry": str(rec["expiry"])}, None)'''
s = s.replace(old, new)
open(p,"w").write(s)
PY
run "M4 (the registry path skips Ruling 10's constraints)"
cp "$CP" "$SRC"

# M5 -- two rulings in force, and the tool picks one rather than refusing.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if len(live) > 1:"
assert s.count(old) == 1, "M5 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "M5 (two live rulings: pick one silently)"
cp "$CP" "$SRC"

# M6 -- a registry we cannot parse is read as "no ruling in force".  That is
# a guess wearing a reading's clothes.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '''    except Exception as exc:
        return None, notes, ('''
assert s.count(old) == 1, "M6 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, '''    except Exception as exc:
        return None, notes, None or (''')
s = s.replace('''            "and guessing 'none' answers a question nobody asked."
            % (path, exc))''',
              '''            "and guessing 'none' answers a question nobody asked."
            % (path, exc)) and None''')
open(p,"w").write(s)
PY
run "M6 (an unparseable registry reads as 'nothing in force')"
cp "$CP" "$SRC"

# M7 -- the deliberate asymmetry collapses the permissive way: an expired
# ruling ASSERTED this round by flag stops being exit 2.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if moment > when:\n        return None, (\"the crossing ruling %s expired at %s and it is now %s. \""
assert s.count(old) == 1, "M7 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:\n        return None, (\"the crossing ruling %s expired at %s and it is now %s. \"")
open(p,"w").write(s)
PY
run "M7 (an expired flag is accepted)"
cp "$CP" "$SRC"

# M8 -- THE PROSE MUTANT.  Not one number moves.  The refusal line goes back
# to demanding a ruling issued "that round", which is the sentence the desk
# obeyed two hours after the money was granted.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '"director crossing ruling that has NOT EXPIRED at this "\n                "instant -- it does NOT have to have been issued this round; "'
assert s.count(old) == 1, "M8 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, '"director crossing ruling that round; "\n                "" '
                   '"" ')
open(p,"w").write(s)
PY
run "M8 (the refusal demands a ruling issued THIS ROUND again)"
cp "$CP" "$SRC"

# M9 -- opting out stops calling itself a skip, so a run that did not look
# reads like a run that looked and found nothing.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '''        print("crossing registry: NOT CONSULTED (--no-crossing-file). A "
              "standing ruling may be in force and this run did not look; "
              "that is a SKIP, not a finding of none.")'''
assert s.count(old) == 1, "M9 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, '        print("crossing registry: no standing ruling.")')
open(p,"w").write(s)
PY
run "M9 (a skip reads as a finding of none)"
cp "$CP" "$SRC"

# The restore is PROVEN, not asserted.
if sha256sum -c "$SUM" > /dev/null 2>&1; then
  echo "RESTORE: byte-identical ok (sha256sum -c)"
else
  echo "RESTORE: DIFFERS -- STOP, the tree still carries a mutant"; trap - EXIT; rm -f "$SUM"; exit 2
fi
# GH #492 ssEL.7: disarm BEFORE removing the copy.
trap - EXIT
rm -f "$CP" "$SUM"
