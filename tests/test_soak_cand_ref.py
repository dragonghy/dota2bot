#!/usr/bin/env python3
"""[GH #141] The two-arm wave's harness half: gate file + verdict accounting.

WHY THIS EXISTS
    test_set.md §AS.3 froze the test set behind one non-lucky thaw condition --
    a BISECT wave, two arms inside one tree.  That wave could not be launched:
    soak_side.lua held a single `cand` string, so the reference leg armed
    nothing, and "two arms in one wave" was not hard but INEXPRESSIBLE.  #141
    adds an optional `cand_ref`.

    The Lua half (which ids light up on which leg) is pinned by
    tests/test_soak_cand_ref_gate.lua.  This file pins the two harness halves:

      1. WHO RENDERS THE GATE FILE.  Two callers used to hold their own copy of
         the printf format.  The blast radius of that file is every gated fix,
         so the precondition of the feature is that with CAND_REF unset the
         bytes are the ones that were being written before -- not "equivalent",
         the same bytes.  BYTES_UNSET below is the historical literal, and the
         drift check asserts nobody grew a second copy of the format.

      2. HOW THE VERDICT IS ARCHIVED.  A two-arm wave's number is armA-minus-armB,
         NOT candidate-minus-stable.  The arithmetic is identical, which is
         exactly why it is dangerous: filed next to single-arm readings it
         silently compares two different quantities, and after archiving there
         is nothing left to tell them apart.  Both verdict writers
         (recover_verdict.py and the copy embedded in validate_onspot.sh) must
         carry `cand_ref` and stamp `contrast`.

         That is GH #141 §4.3's M3 mutation: drop the field -> this goes red.

HOW IT TESTS
    It runs the REAL scripts -- the real renderer, the real recover_verdict.py,
    and the verdict block literally extracted out of validate_onspot.sh -- on
    real temp corpora.  Nothing here reimplements a formula and checks its own
    arithmetic; a test that imports a copy is the shape GH #67 names.
"""
import json, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOAK = os.path.join(ROOT, "tools", "batch_test", "soak")
RENDER = os.path.join(SOAK, "write_soak_side.sh")
RECOVER = os.path.join(SOAK, "recover_verdict.py")
VALIDATE = os.path.join(SOAK, "validate_onspot.sh")
MIRROR = os.path.join(SOAK, "mirror_ab.sh")

# The exact line the two callers wrote before write_soak_side.sh existed.
# Kept as a literal on purpose: a test that rebuilt it from the same format
# string the code uses would agree with any change, including a wrong one.
BYTES_UNSET = "return { side = 'radiant', cand = 'creeppull', seed = 888 }\n"

failures = []


def check(cond, msg):
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def render(side, cand, seed, cand_ref=None):
    env = dict(os.environ)
    if cand_ref is None:
        env.pop("CAND_REF", None)
    else:
        env["CAND_REF"] = cand_ref
    p = subprocess.run(["bash", RENDER, side, cand, str(seed)],
                       capture_output=True, text=True, env=env)
    check(p.returncode == 0, "renderer exits 0 (%s)" % (p.stderr.strip() or "no stderr"))
    return p.stdout


# --------------------------------------------------------------------------
# 1. The precondition: CAND_REF unset => the historical bytes, unchanged.
# --------------------------------------------------------------------------
out = render("radiant", "creeppull", 888)
check(out == BYTES_UNSET,
      "CAND_REF unset renders the pre-#141 bytes exactly (%r)" % out)

# The empty string is what an unset shell variable degrades to once it has
# passed through `CAND_REF="${CAND_REF:-}"` and been re-exported by a caller.
# If empty were treated as "set", every ordinary wave would silently become a
# two-arm wave whose reference leg arms nothing under a `contrast=two_arm`
# label -- a mislabelled reading, which is worse than a wrong one.
check(render("radiant", "creeppull", 888, cand_ref="") == BYTES_UNSET,
      "CAND_REF='' is treated as unset, not as an empty second arm")

# The two shapes nobody writes by hand still have to round-trip.
check(render("dire", "all", 7) == "return { side = 'dire', cand = 'all', seed = 7 }\n",
      "'all' renders unchanged")
check(render("dire", "a,b,c", 7) == "return { side = 'dire', cand = 'a,b,c', seed = 7 }\n",
      "a comma bundle renders unchanged")

# --------------------------------------------------------------------------
# 2. The feature: CAND_REF set => cand_ref lands in the file.
# --------------------------------------------------------------------------
two = render("radiant", "x,shared", 888, cand_ref="y,shared")
check(two == "return { side = 'radiant', cand = 'x,shared', cand_ref = 'y,shared', seed = 888 }\n",
      "CAND_REF set renders cand_ref (%r)" % two)

# The rendered line is Lua source that the game will `dofile`. Parsing it with
# the real interpreter is the only check that says so; skipped, loudly, when the
# container has no lua5.1 (the python suite runs in 开工自检 where it may not).
lua = subprocess.run(["bash", "-c", "command -v lua5.1"], capture_output=True, text=True)
if lua.returncode == 0:
    prog = ("local t = assert(loadstring(io.read('*a')))()\n"
            "print(t.side, t.cand, t.cand_ref, t.seed)\n")
    p = subprocess.run(["lua5.1", "-e", prog], input=two, capture_output=True, text=True)
    check(p.returncode == 0 and p.stdout.split() == ["radiant", "x,shared", "y,shared", "888"],
          "the rendered two-arm line is Lua that loads to the right table (%r)"
          % (p.stdout.strip() or p.stderr.strip()))
    p = subprocess.run(["lua5.1", "-e", prog], input=BYTES_UNSET, capture_output=True, text=True)
    check(p.returncode == 0 and p.stdout.split() == ["radiant", "creeppull", "nil", "888"],
          "the single-arm line loads with cand_ref absent (nil), not empty (%r)"
          % (p.stdout.strip() or p.stderr.strip()))
else:
    print("SKIP lua5.1 absent: the rendered lines were not parsed by the real interpreter")

# --------------------------------------------------------------------------
# 3. Drift: exactly one place renders the gate file.
# --------------------------------------------------------------------------
# A second copy of the format is how this file's own bug got here: the field
# would be added to one copy and the other would keep writing the old shape,
# invisibly, because nothing reads both.
renderers = []
for dirpath, _, names in os.walk(os.path.join(ROOT, "tools")):
    for n in names:
        f = os.path.join(dirpath, n)
        try:
            body = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for m in re.finditer(r"return \{ side = ", body):
            line = body[m.start():body.find("\n", m.start())]
            renderers.append((os.path.relpath(f, ROOT), line.strip()))

# The one deliberate exception is validate_onspot.sh's teardown, which closes
# the gate rather than deploying a wave: `side = false` is not a rendering of a
# wave and takes no fields.
teardown = [r for r in renderers if "side = false" in r[1]]
waves = [r for r in renderers if "side = false" not in r[1]]
check(len(teardown) == 1 and teardown[0][0].endswith("validate_onspot.sh"),
      "the only literal gate-file write left is the teardown in validate_onspot.sh: %r" % teardown)
check([r[0] for r in waves] == ["tools/batch_test/soak/write_soak_side.sh"] * len(waves)
      and len(waves) >= 1,
      "every wave rendering of soak_side.lua lives in write_soak_side.sh: %r" % waves)

for caller in (VALIDATE, MIRROR):
    body = open(caller).read()
    check("write_soak_side.sh" in body,
          "%s calls the shared renderer" % os.path.basename(caller))
    check('CAND_REF="${CAND_REF:-}"' in body,
          "%s accepts an optional CAND_REF" % os.path.basename(caller))

# --------------------------------------------------------------------------
# 4. mirror_ab.sh sends the same remote command it used to.
# --------------------------------------------------------------------------
# That caller does not write the file locally: it ships a printf into an SSM
# JSON document, where every ' has to reach the remote shell as \047. Rendering
# first and escaping after must reproduce the hand-written literal byte for
# byte, or the wave deploys a gate file the game cannot load. The real function
# is extracted from the script and executed -- not re-typed here.
fn = re.search(r"^ssm_side_line\(\) \{.*?^\}", open(MIRROR).read(), re.S | re.M)
check(fn is not None, "ssm_side_line() found in mirror_ab.sh")
# ...and is the thing deploy() actually sends. A correct renderer the caller
# does not call is the same failure as no renderer at all.
dep = re.search(r"^deploy\(\) \{.*?^\}", open(MIRROR).read(), re.S | re.M)
check(dep is not None and "ssm_side_line" in dep.group(0),
      "deploy() takes its printf format from ssm_side_line, not a local literal")
if fn:
    harness = (
        'set -uo pipefail\n'
        'HERE=%s\nCAND=nodive\nSEED=424242\nCAND_REF="${CAND_REF:-}"\n' % SOAK
        + fn.group(0) + "\nssm_side_line radiant\n")
    env = dict(os.environ); env.pop("CAND_REF", None)
    p = subprocess.run(["bash", "-c", harness], capture_output=True, text=True, env=env)
    old = ("return { side = \\\\047radiant\\\\047, cand = \\\\047nodive\\\\047, "
           "seed = 424242 }")
    check(p.stdout == old,
          "unset CAND_REF reproduces the pre-#141 SSM format byte for byte (%r)" % p.stdout)
    env["CAND_REF"] = "y"
    p = subprocess.run(["bash", "-c", harness], capture_output=True, text=True, env=env)
    check("cand_ref = \\\\047y\\\\047" in p.stdout,
          "CAND_REF reaches the SSM format with the same \\047 escaping (%r)" % p.stdout)

# --------------------------------------------------------------------------
# 5. Verdict accounting, on both verdict writers.
# --------------------------------------------------------------------------
CAND = "testcand"


def game(stamp, gpm):
    """One analysis.json in the shape analyze_log.py emits."""
    return {
        "script_version": stamp, "winner": "radiant", "winner_by": "economy_30min_cap",
        "econ_winner": "radiant",
        "players": ([{"team": "radiant", "gpm": gpm, "xpm": gpm, "deaths": 5,
                      "last_hits": 100} for _ in range(5)]
                    + [{"team": "dire", "gpm": 500, "xpm": 500, "deaths": 5,
                        "last_hits": 100} for _ in range(5)]),
    }


def run_recover(extra):
    d = tempfile.mkdtemp()
    for seed in ("11", "22"):
        for side, gpm in (("radiant", 560), ("dire", 500)):
            g = game("mirror:%s:s%s:%s" % (CAND, seed, side), gpm)
            with open(os.path.join(d, "%s_%s.analysis.json" % (seed, side)), "w") as f:
                json.dump(g, f)
    p = subprocess.run([sys.executable, RECOVER, d, CAND] + extra,
                       capture_output=True, text=True)
    check(p.returncode == 0, "recover_verdict exits 0 (%s)" % p.stderr.strip()[:200])
    return json.loads(p.stdout) if p.returncode == 0 else {}


v = run_recover([])
# Anti-vacuous guard first: a verdict that parsed nothing would satisfy any
# assertion about a field it also does not have.
check(len(v.get("per_seed", [])) == 2, "recover_verdict actually scored the corpus (2 seeds)")
check("cand_ref" in v and v["cand_ref"] is None,
      "single-arm verdict carries cand_ref = null, not a missing key: %r" % v.get("cand_ref", "<missing>"))
check(v.get("contrast") == "vs_stable",
      "single-arm verdict is stamped contrast=vs_stable: %r" % v.get("contrast"))

v2 = run_recover(["--cand-ref", "y,shared"])
check(len(v2.get("per_seed", [])) == 2, "two-arm run scored the same corpus")
check(v2.get("cand_ref") == "y,shared",
      "two-arm verdict records the reference leg's armed string: %r" % v2.get("cand_ref"))
check(v2.get("contrast") == "two_arm",
      "two-arm verdict is stamped contrast=two_arm: %r" % v2.get("contrast"))
check(v2.get("mean") == v.get("mean"),
      "the arithmetic is unchanged -- only the accounting differs: %r vs %r"
      % (v2.get("mean"), v.get("mean")))

# A --cand-ref with no value must abort, not silently score a wave whose second
# arm nobody recorded.
p = subprocess.run([sys.executable, RECOVER, tempfile.mkdtemp(), CAND, "--cand-ref"],
                   capture_output=True, text=True)
check(p.returncode != 0, "a bare --cand-ref is refused, not defaulted")

# The farm does not run recover_verdict.py on the happy path -- it runs the
# copy embedded in validate_onspot.sh. Extract that block and drive it, so the
# field cannot be present in the offline tool and missing in the online one.
body = open(VALIDATE).read()
blk = re.search(r'python3 - "\$CAND" "\$SEEDS" "\$RESULTS" "\$CAND_REF".*?\n(.*?)\nPY\n',
                body, re.S)
check(blk is not None, "validate_onspot.sh's verdict block found (and takes $CAND_REF)")
if blk:
    src = blk.group(1)
    rows = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    rows.write(json.dumps({"seed": "11", "gpm": 12.0, "xpm": 3.0,
                           "deaths": -0.1, "last_hits": 1.0}) + "\n")
    rows.close()
    for ref, want in (("", "vs_stable"), ("y,shared", "two_arm")):
        p = subprocess.run([sys.executable, "-c", src, CAND, "11", rows.name, ref],
                           capture_output=True, text=True)
        check(p.returncode == 0, "onspot verdict block runs (%s)" % p.stderr.strip()[:200])
        if p.returncode == 0:
            ov = json.loads(p.stdout)
            check(ov.get("per_seed"), "onspot verdict block actually read the rows")
            check(ov.get("contrast") == want,
                  "onspot verdict stamps contrast=%s for cand_ref=%r (got %r)"
                  % (want, ref, ov.get("contrast")))
            check(ov.get("cand_ref") == (ref or None),
                  "onspot verdict records cand_ref=%r (got %r)" % (ref or None, ov.get("cand_ref")))

# --------------------------------------------------------------------------
# 6. The launcher can actually ask for a two-arm wave.
# --------------------------------------------------------------------------
# Without this leg the feature is a rule written down but not landed -- exactly
# what GH #141 §1 is about. --cand-ref must reach validate_onspot.sh AND must
# not be parsed as a seed on the way.
spot = open(os.path.join(ROOT, "tools", "batch_test", "aws", "spot_run.sh")).read()
check("--cand-ref" in spot, "spot_run.sh understands --cand-ref in --validate")
check("CAND_REF='$vref'" in spot, "spot_run.sh exports CAND_REF to validate_onspot.sh")
check("'s/--cand-ref [^ ]*//'" in spot or "-e 's/--cand-ref [^ ]*//'" in spot,
      "spot_run.sh strips --cand-ref out of the seed list")

print("\n%d failed" % len(failures))
sys.exit(1 if failures else 0)
