#!/usr/bin/env python3
"""Build a team-dispatch A/B bot script directory for same-match adversarial testing.

Radiant loads version NEW, Dire loads version OLD (swap sides across the batch
to cancel side bias). Produces three directories under --out:

    <out>/bots          # dispatcher shims, link this into scripts/vscripts/bots
    <out>/bots_ab_new   # full tree of --new ref
    <out>/bots_ab_old   # full tree of --old ref

Every .lua file in bots/ is a one-line dispatcher that dofiles the same relative
path from bots_ab_new or bots_ab_old based on GetTeam(). Because the scripts
resolve their own requires via GetScriptDirectory() (which points at the shim
dir), all internal loads re-enter the dispatcher and stay consistent per team.

ASSUMPTION TO VERIFY IN-GAME (first run): each team's bots run in a separate
Lua VM, so GetTeam() is constant within a VM and module caches don't leak
across teams. The dispatcher logs '[AB] <team> -> <version>' once per VM;
check the console log for exactly two distinct lines.

Usage:
    make_ab_build.py --old <git-ref> --new <git-ref> [--swap] --out /path/ab_build
    (run from the repo root; refs can be branches, tags, or commit SHAs)
"""
import argparse
import os
import shutil
import subprocess
import sys

DISPATCH_TEMPLATE = """-- generated A/B dispatcher; do not edit (make_ab_build.py)
-- GetScriptDirectory() is '<...>/vscripts/bots'; versions sit next to it.
local _base = GetScriptDirectory():gsub('[/\\\\]bots$', '')
local _ab_new, _ab_old = _base .. '/{new_dir}', _base .. '/{old_dir}'
local _team_is_radiant = (GetTeam() == (TEAM_RADIANT or 2))
local _root = _team_is_radiant and {radiant_pick} or {dire_pick}
if not _AB_LOGGED then
    _AB_LOGGED = true
    print('[AB] team=' .. tostring(GetTeam()) .. ' -> ' ..
        (_root == _ab_new and 'NEW' or 'OLD'))
end
-- game-style dofile: no .lua extension (matches aba_minion loading convention)
return dofile(_root .. '/{relpath}')
"""


def git_export(ref, dest):
    os.makedirs(dest, exist_ok=True)
    tar = subprocess.Popen(
        ["git", "archive", ref, "bots"], stdout=subprocess.PIPE)
    subprocess.check_call(["tar", "-x", "-C", dest, "--strip-components=1", "bots"],
                          stdin=tar.stdout)
    if tar.wait() != 0:
        sys.exit(f"git archive {ref} failed")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", required=True, help="git ref for the OLD (baseline) version")
    ap.add_argument("--new", required=True, help="git ref for the NEW (candidate) version")
    ap.add_argument("--out", required=True)
    ap.add_argument("--swap", action="store_true",
                    help="swap sides: Radiant=OLD, Dire=NEW (for side-bias cancelling)")
    args = ap.parse_args()

    out = os.path.abspath(args.out)
    new_dir, old_dir = os.path.join(out, "bots_ab_new"), os.path.join(out, "bots_ab_old")
    shim_dir = os.path.join(out, "bots")
    for d in (new_dir, old_dir, shim_dir):
        if os.path.exists(d):
            shutil.rmtree(d)

    git_export(args.new, new_dir)
    git_export(args.old, old_dir)

    # dispatcher picks by team; --swap flips the assignment
    radiant_pick = "_ab_old" if args.swap else "_ab_new"
    dire_pick = "_ab_new" if args.swap else "_ab_old"

    # In-game these dirs sit next to each other under scripts/vscripts/; the
    # dispatcher needs their runtime paths relative to the vscripts root.
    rt_new, rt_old = "bots_ab_new", "bots_ab_old"

    count = 0
    for root, _dirs, files in os.walk(new_dir):
        for fname in files:
            if not fname.endswith(".lua"):
                continue
            rel = os.path.relpath(os.path.join(root, fname), new_dir)
            shim_path = os.path.join(shim_dir, rel)
            os.makedirs(os.path.dirname(shim_path), exist_ok=True)
            with open(shim_path, "w") as f:
                f.write(DISPATCH_TEMPLATE.format(
                    new_dir=rt_new, old_dir=rt_old,
                    radiant_pick=radiant_pick, dire_pick=dire_pick,
                    relpath=rel.replace(os.sep, "/")[:-4]))
            count += 1

    # files that exist only in OLD still need shims (deleted in NEW)
    for root, _dirs, files in os.walk(old_dir):
        for fname in files:
            if not fname.endswith(".lua"):
                continue
            rel = os.path.relpath(os.path.join(root, fname), old_dir)
            shim_path = os.path.join(shim_dir, rel)
            if not os.path.exists(shim_path):
                os.makedirs(os.path.dirname(shim_path), exist_ok=True)
                with open(shim_path, "w") as f:
                    f.write(DISPATCH_TEMPLATE.format(
                        new_dir=rt_new, old_dir=rt_old,
                        radiant_pick=radiant_pick, dire_pick=dire_pick,
                        relpath=rel.replace(os.sep, "/")[:-4]))
                count += 1

    sides = "Radiant=OLD, Dire=NEW" if args.swap else "Radiant=NEW, Dire=OLD"
    print(f"A/B build ready at {out} ({count} dispatchers; {sides})")
    print("Install: link/copy bots, bots_ab_new, bots_ab_old into "
          "<dota>/game/dota/scripts/vscripts/")


if __name__ == "__main__":
    main()
