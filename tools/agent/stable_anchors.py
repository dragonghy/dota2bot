#!/usr/bin/env python3
"""稳定版锚点核对 —— 让「锚点建了没有」变成一条读数,而不是一次猜测。

WHY THIS EXISTS (2026-08-26T01:0xZ, director)
---------------------------------------------
铁律 3 说稳定版 = `origin/main` 上所有 gate 关闭的默认行为,每次 promote 打一个
`stable-vN` 锚点。总监章程把「打 stable-vN tag」列进 promote 流程。

从 2026-08-24 起,director 章程「当前状态」节的『下次触发』清单**连续十轮**记着
「`stable-v1`/`stable-v2` 打 tag(第 N 轮积压)」,每轮顺延,最后一轮甚至给自己
立了「再顺延就必须写进 DECISIONS_NEEDED」的规矩。

2026-08-26 真去量了一下,发现十轮问的是个错问题:

  * 两个 ref **早就在 origin 上**(`refs/heads/stable-v1` / `refs/heads/stable-v2`),
    而 `stable-v1` 恰好就指着正确的 promote commit;
  * 真正不存在的是 **tag** —— 而本容器的凭据 **推不了 tag**:`git push origin
    stable-v1 stable-v2` 稳定 HTTP 403,同一次会话同一套凭据 push branch 成功。
    也就是说那十轮里被顺延的动作,**做也做不成**;
  * 更根本的是:**没有任何机器可读的记录**说锚点在哪。于是每一轮总监都用
    「`git tag -l` 是空的」当判据去回答「锚点建了没有」,答案永远是「没有」。

这与本文件所在目录里另外两个工具的成因逐字同型(`unlanded_commits.py` 的
「检测器没人跑」、`pending_rulings.py` 的「散文不会举手」),这里再早一步:
**判据本身是错的,而错判据不会举手**。散文说「打 tag」,仓库里存的是 branch ref,
两边从来没有对过账。

WHAT IT REPORTS
---------------
读 `iterations/stable_anchors.json`,对每个登记的锚点核三条不变量:

  1. EXISTS   -- ref 在 origin 上存在(`git ls-remote`,零成本);
  2. PINNED   -- 它仍然指着登记的 `ref_sha`;
  3. SHIPPED  -- `ref_sha` 与 `promote_commit` 之间 `bots/` + `game/` 逐字节相同。
                 这是铁律 3 定义锚点的**唯一**维度;`tests/` `tools/`
                 `iterations/` 的漂移不影响锚点正确性,故**不看**。

LIMITS (read these before quoting the output)
---------------------------------------------
1. **MOVED 是问题不是判决。** 一次合法的锚点重定位(比如把 ref 挪到一个
   shipped-tree 相同、但历史更整齐的 commit)与一次误推在这里长得一样。看一眼,
   然后要么改登记表要么改 ref —— 但**要看**。
2. **不变量 3 在浅克隆里买不到。** routine 容器默认 depth 50,promote commit 通常
   在 graft point 以下 ⇒ 对象不在本地,`git diff` 无从谈起。此时本工具报
   **UNCERTIFIABLE(exit 2)而不是 OK**,与 `unlanded_commits.py` 的 REFUSED 同一
   条纪律:**不知道就说不知道,不许把「没查」记成「没问题」**。
   要买到它:`git fetch --deepen=400 origin main`(实测 ~3s)。
3. **它不核 promote 本身对不对。** 三条件(录像 (a) / 批测 (b) / 逻辑 (c))住在
   `state.json` 的 promote 记录里,由总监判;这里只核**锚点指对了没有**。
4. **ref_kind 是 branch 不是 tag,这是记录不是缺陷**(见 json 的 `_doc`)。
   branch ref 可变 ⇒ 不变量 2 就是给这件事兜底的那一条。

Usage:  python3 tools/agent/stable_anchors.py [--no-remote]

Exit 0 clean, 2 uncertifiable, 3 findings.
"""

import json
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGISTRY = os.path.join(REPO, "iterations", "stable_anchors.json")
SHIPPED = ["bots/", "game/"]


def git(*args):
    """Run a git command; return (ok, stdout)."""
    proc = subprocess.run(
        ["git"] + list(args),
        cwd=REPO,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return proc.returncode == 0, proc.stdout.strip()


def have_object(sha):
    """True if the commit object is present locally (false in a shallow clone)."""
    ok, _ = git("cat-file", "-e", sha + "^{commit}")
    return ok


def remote_shas():
    """Map refname -> sha for every branch on origin.  One network round trip."""
    ok, out = git("ls-remote", "--heads", "origin")
    if not ok:
        return None
    shas = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 2:
            shas[parts[1]] = parts[0]
    return shas


def check(anchor, remote):
    """Return (worst_exit, [lines]) for one anchor."""
    name = anchor["name"]
    ref = anchor["ref"]
    want = anchor["ref_sha"]
    promote = anchor["promote_commit"]
    lines = []
    worst = 0

    # ---- invariant 1 + 2: the ref exists and still points where we recorded ----
    if remote is None:
        lines.append("  EXISTS   UNCERTIFIABLE -- git ls-remote failed (offline?)")
        worst = max(worst, 2)
    elif ref not in remote:
        lines.append("  EXISTS   MISSING -- %s is not on origin" % ref)
        lines.append("           restore:  git push origin %s:%s" % (want[:12], ref))
        worst = max(worst, 3)
    else:
        lines.append("  EXISTS   ok (%s)" % ref)
        got = remote[ref]
        if got == want:
            lines.append("  PINNED   ok (%s)" % want[:12])
        else:
            lines.append("  PINNED   MOVED -- registry says %s, origin says %s"
                         % (want[:12], got[:12]))
            lines.append("           A legitimate relocation and a mis-push look the "
                         "same here.  Look, then fix ONE side.")
            worst = max(worst, 3)

    # ---- invariant 3: the shipped tree is byte-identical to the promote commit ----
    if promote == want:
        lines.append("  SHIPPED  ok (ref IS the promote commit -- trivially identical)")
    elif not (have_object(promote) and have_object(want)):
        lines.append("  SHIPPED  UNCERTIFIABLE -- shallow clone, objects below the "
                     "graft point")
        lines.append("           buy it:  git fetch --deepen=400 origin main   (~3s)")
        worst = max(worst, 2)
    else:
        ok, _ = git("diff", "--quiet", promote, want, "--", *SHIPPED)
        if ok:
            lines.append("  SHIPPED  ok (%s..%s: bots/ game/ byte-identical)"
                         % (promote[:12], want[:12]))
        else:
            _, stat = git("diff", "--stat", promote, want, "--", *SHIPPED)
            lines.append("  SHIPPED  DIFFERS -- the anchor's shipped tree is not the "
                         "promoted tree")
            for row in stat.splitlines()[-3:]:
                lines.append("           " + row.strip())
            worst = max(worst, 3)

    return worst, ["%s  ids=%s  promoted=%s" % (name,
                                                ",".join(anchor.get("promoted_ids", [])),
                                                anchor.get("promoted_at", "?"))] + lines


def main():
    no_remote = "--no-remote" in sys.argv[1:]

    try:
        with open(REGISTRY, encoding="utf-8") as fh:
            registry = json.load(fh)
    except FileNotFoundError:
        print("REGISTRY MISSING -- %s" % os.path.relpath(REGISTRY, REPO))
        print("Nothing records where the stable anchors point, which is the exact")
        print("condition this tool was written for.  See the file's git history.")
        return 3
    except ValueError as exc:
        print("REGISTRY UNREADABLE -- %s" % exc)
        return 3

    anchors = registry.get("anchors", [])
    if not anchors:
        # Discovery matching nothing is the dead-lifecycle-rule shape the
        # selfcheck wrapper's own header warns about: on the books, matching
        # nothing.  Say so rather than printing a clean run.
        print("NO ANCHORS REGISTERED -- the registry is empty; every promote since")
        print("the last recorded one is unanchored.")
        return 3

    remote = None if no_remote else remote_shas()
    worst = 0
    for anchor in anchors:
        exit_code, lines = check(anchor, remote)
        worst = max(worst, exit_code)
        for line in lines:
            print(line)
        print()

    verdict = {0: "OK", 2: "UNCERTIFIABLE", 3: "FINDINGS"}[worst]
    print("%d anchor(s) checked -- %s" % (len(anchors), verdict))
    return worst


if __name__ == "__main__":
    sys.exit(main())
