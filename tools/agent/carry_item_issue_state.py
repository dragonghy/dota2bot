#!/usr/bin/env python3
"""交叉读「下次触发」清单里的每个 `GH #<n>`,让**关闭的 issue 被当未完待办抄写**时举手。

WHY THIS EXISTS (RULING 63, 2026-09-16T07:0xZ;登记行
`iterations/owed_executions.json:carry_item_issue_state_crossread`)
------------------------------------------------------------------
总监章程「当前状态」节每轮结尾写一份『下次触发』清单,下一轮把它抄下来再顺延。
2026-09-16T04:05Z 那一轮的第 ⑦ 条逐字是:

    ⑦**GH #523**(**连续第十轮未取**)

而 **GH #523 已于 2026-09-08T13:12:53Z 关闭** —— 它第一次作为「存量」出现在总监报告里
(`iterations/reports/director/20260909T101220Z.md`)就**已经在关闭之后**。
于是那个计数器每轮加一,读起来越来越像一个被忽视的活 issue,而它指的名字早就结清了。

⛔ **而失效方向是双面的,这一条只买其中一面。** #523 正文里有两件事,关闭时只验收了第一件;
第二件(`claim_precheck.sh` 的前向引用假阳,后来的 FORWARD-REF 类)在 09-05 被「并进 #523」之后
**再没有一行机器可读的登记** ⇒ issue 一关,它对全队隐形 11 天。
**一个已完成的名字在攒紧迫感,一件真未完的事在无人看见 —— 两者是同一次抄写的两面。**

⇒ 本腿判的是**名字的状态**,不是**活干完了没有**。它能说的只有一句:
「你抄的这个号已经关了」。真正剩下的活该怎么办,由读到这一行的人决定 ——
要么把名字从清单里划掉,要么按章程 §2.6 给剩下的那件事**一行机器可读的登记**
(`owed_executions.json`),⛔ **不许把它留在散文里继续抄**。

WHAT IT REPORTS
---------------
输入是章程的「当前状态」节(默认只看**最新 N 条**,N=1)。对其中『下次触发』那一段里
的每一个 `GH #<n>`:

    OK            issue 语料说它 `open`
    STALE-CARRY   issue 语料说它 `closed`  ⇒ finding(exit 3)
    UNCERTIFIABLE 语料读不到它 / 没有语料 / 语料过期  ⇒ exit 2,**不是 OK**

三态是 RULING 55 的直接后果,不是谨慎的姿态:**一次 `list_*` 读不到某个号,
不能证明那个号不存在** —— 那一轮实测 `get_comments` 滞后 **8.8 分钟**,
而据此写下的三件产物(补开 issue、补发评论、两处指控)**三件都是错的**。
所以这里「语料里没有」永远读作**未核实**,永远不读作 open,也永远不读作 closed。

⛔ **过期语料只会静默,不会指控。** 语料比 `--max-age-hours` 旧 ⇒ 整轮降级为
UNCERTIFIABLE,**不出 finding**。理由是方向不对称:陈旧语料漏掉一次关闭,代价是本腿这一轮
少说一句话;陈旧语料把一个**重开**的 issue 说成 closed,代价是有人照着把一条活着的待办
从清单里划掉 —— 与 RULING 55「代价永远落在被误判的那一方身上」同一条纪律。

ANTI-EMPTY-MATCH
----------------
「清单里没有关闭的 issue」和「正则一个号都没匹配到」印出来长得一样,这个仓库已经在
#29 / #31 / #34 / #37 / #95 / #103 上栽过六次。所以每次都打分母
(扫了几条 entry / 找到几段『下次触发』/ 抽出几个号 / 解析了几个),
且**抽到零个号的一轮 exit 2,不是 exit 0**。

ISSUE 语料从哪来
----------------
一份 JSON 快照,默认 `iterations/data/issue_state_snapshot.json`:

    {"fetched_at": "2026-09-16T10:00:00Z",
     "source": "mcp__github__list_issues(state=all) dragonghy/dota2bot",
     "issues": {"523": {"state": "closed", "closed_at": "2026-09-08T13:12:53Z"}}}

刷新由**有 MCP 的那一轮**做(Routine 容器里 `gh` CLI 不存在,铁律 11 又禁止在权限提示上
坐等)⇒ 本腿按构造是**只读、离线、零网络**的,拿不到新语料时它说「未核实」,
⛔ **不会自己去猜**。

LIMITS(引用本工具输出前先读这三条)
------------------------------------
1. **它不判活干完了没有。** 见上:关闭的 issue 里可以躺着真未完的第二件事(#523 就是)。
   STALE-CARRY 是「这个**名字**不该再被抄」,不是「这件事做完了」。
2. **它不知道那个号为什么被写在清单里。** 一个作为**档案引用**出现的 `GH #<n>`
   (「族属 GH #290」)与一个作为**待办**出现的号,在正则眼里一样。所以 finding 是
   「看一眼」,不是判决 —— 与 `stable_anchors.py` 的 MOVED 同一条措辞纪律。
3. **默认只看最新一条 entry。** 旧 entry 里的清单已经被下一轮取代,拿它出 finding 等于
   对着历史开火。`--entries N` 可以放宽,但那时打出来的是**历史**不是**当下**。

Usage:
    python3 tools/agent/carry_item_issue_state.py
    python3 tools/agent/carry_item_issue_state.py --issues <snapshot.json> --entries 2
    python3 tools/agent/carry_item_issue_state.py --selfcheck

Exit 0 clean, 2 uncertifiable (含语料缺失/过期/零匹配), 3 findings.
"""

import argparse
import datetime
import json
import os
import re
import sys

DEFAULT_CHARTER = "iterations/streams/director.md"
DEFAULT_SNAPSHOT = "iterations/data/issue_state_snapshot.json"
STATUS_HEADING = "## 当前状态"
# 「当前状态」节里一条 entry 的起始行,例:`- **2026-09-16T07:02Z**:...`
# ⚠️ **分钟位可以是 `x`**:本仓的散文时刻惯例是「**2026-09-16T10:1xZ**」(登记行的
# `ruled_at` 也这么写)。第一版只认纯数字,⇒ 落地那一轮自己的新条目**被静默跳过**,
# 工具转头去读**上一轮**的清单,而读数长得一模一样(`scanned: 1 entry (of 65)`)——
# 失效方向是「对着一张已经被取代的清单报干净」。是这条腿自己在真语料上撞出来的。
ENTRY_RE = re.compile(r"^- \*\*(\d{4}-\d{2}-\d{2}T[\dxX]{2}:[\dxX]{2}Z)\*\*")
CARRY_MARK_RE = re.compile(r"下次触发")
GH_REF_RE = re.compile(r"GH\s*#(\d+)")
# 「GH #538 / #528」这种链式写法里,第二个号**没有** `GH` 前缀。第一次真语料
# 读数(2026-09-16)上,清单第 ⑧ 条逐字是「GH #538 / #528 / patch 缺口 P3」——
# 只认 `GH #` 的那一版当场漏掉 `#528`。⛔ 而裸 `#<n>` 本身不收:章程里 `#` 也用来
# 写别的东西,收进来会把 finding 稀释掉,而稀释一个探测器的代价在本仓是记过账的
# (GH #276:稳定假阳等于没人再读)。只收**紧跟在一个已认下的号后面**的那一串。
CHAIN_REF_RE = re.compile(r"\s*[/、,,]\s*#(\d+)")


def parse_ts(text):
    """`2026-09-16T07:02Z` / `...:02:03Z` -> aware datetime, or None."""
    if not isinstance(text, str):
        return None
    t = text.strip()
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%MZ"):
        try:
            return datetime.datetime.strptime(t, fmt).replace(
                tzinfo=datetime.timezone.utc)
        except ValueError:
            continue
    return None


def status_entries(charter_text):
    """Return [(ts_string, entry_text)] newest-first, as written in the charter.

    「当前状态」节按约定是**新的在上**,所以文件顺序就是时间顺序;这里不排序,
    因为排序会把一条时间戳写错的 entry 悄悄挪位置,而那正是要看见的东西。
    """
    lines = charter_text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith(STATUS_HEADING):
            start = i + 1
            break
    if start is None:
        return []
    end = len(lines)
    for i in range(start, len(lines)):
        if lines[i].startswith("## "):
            end = i
            break
    entries = []
    cur_ts, cur = None, []
    for line in lines[start:end]:
        m = ENTRY_RE.match(line)
        if m:
            if cur_ts is not None:
                entries.append((cur_ts, "\n".join(cur)))
            cur_ts, cur = m.group(1), [line]
        elif cur_ts is not None:
            cur.append(line)
    if cur_ts is not None:
        entries.append((cur_ts, "\n".join(cur)))
    return entries


def carry_segment(entry_text):
    """The『下次触发』tail of one entry, or None when the entry has no list.

    ⚠️ **取最后一次出现,不是第一次。** 清单按惯例是 entry 的尾巴,而 entry 的**正文**
    经常要谈论这件事本身(本轮这条 entry 就写着「对『下次触发』段里每个 `GH #<n>` 交叉读」)
    ⇒ 取第一次出现会把整段叙事拖进作用域,叙事里每个引用过的号都变成 finding。
    第一版就是这么写的,落地当轮自己报了三个假阳(`#523` / `#538` / `#276`),
    而**稳定假阳是探测器停止被阅读的开始**(GH #276 —— 它本人当场作为假阳出现,是巧合也是佐证)。
    """
    hits = list(CARRY_MARK_RE.finditer(entry_text))
    if not hits:
        return None
    return entry_text[hits[-1].start():]


def refs_in(segment):
    """Issue numbers cited in a carry segment, de-duplicated, in first-seen order."""
    seen, out = set(), []

    def take(n):
        if n not in seen:
            seen.add(n)
            out.append(n)

    for m in GH_REF_RE.finditer(segment):
        take(m.group(1))
        pos = m.end()
        while True:
            c = CHAIN_REF_RE.match(segment, pos)
            if not c:
                break
            take(c.group(1))
            pos = c.end()
    return out


def load_snapshot(path, now, max_age_hours):
    """-> (issues_dict_or_None, note).  issues None means: do not answer anything.

    ⛔ 三种「不答」都归一到 None:文件不在、解析不了、太旧。归一是有意的 ——
    调用方对它们的处置完全相同(UNCERTIFIABLE),分开只会让下一个读代码的人
    以为其中某一种可以出 finding。
    """
    if not os.path.exists(path):
        return None, "no issue corpus at %s (run the refresh recipe in --help)" % path
    try:
        with open(path, encoding="utf-8") as fh:
            blob = json.load(fh)
    except (OSError, ValueError) as exc:
        return None, "issue corpus unreadable: %s" % exc
    issues = blob.get("issues")
    if not isinstance(issues, dict):
        return None, "issue corpus has no `issues` map"
    fetched = parse_ts(blob.get("fetched_at"))
    if fetched is None:
        return None, "issue corpus has no parseable `fetched_at`"
    age_h = (now - fetched).total_seconds() / 3600.0
    if age_h > max_age_hours:
        return None, ("issue corpus is %.1fh old (> %.1fh) -- withheld: a stale "
                      "corpus can accuse a REOPENED issue" % (age_h, max_age_hours))
    if age_h < 0:
        return None, "issue corpus `fetched_at` is in the future (%.1fh)" % age_h
    return issues, "issue corpus %s, fetched %s (%.1fh old), %d issues" % (
        path, blob.get("fetched_at"), age_h, len(issues))


def state_of(issues, number):
    """-> 'open' / 'closed' / None (not in corpus -> UNCERTIFIABLE, never open)."""
    row = issues.get(str(number))
    if row is None:
        return None, None
    if isinstance(row, str):
        st, closed_at = row, None
    elif isinstance(row, dict):
        st, closed_at = row.get("state"), row.get("closed_at")
    else:
        return None, None
    if not isinstance(st, str):
        return None, None
    st = st.strip().lower()
    if st not in ("open", "closed"):
        return None, None
    return st, closed_at


def audit(charter_path, snapshot_path, entries_n, max_age_hours, now=None):
    """-> (exit_code, lines)."""
    now = now or datetime.datetime.now(datetime.timezone.utc)
    out = []
    try:
        with open(charter_path, encoding="utf-8") as fh:
            charter = fh.read()
    except OSError as exc:
        return 2, ["UNCERTIFIABLE -- charter unreadable: %s" % exc]

    entries = status_entries(charter)
    if not entries:
        return 2, ["UNCERTIFIABLE -- no『%s』entries parsed out of %s"
                   % (STATUS_HEADING, charter_path)]
    scanned = entries[:max(1, entries_n)]

    issues, corpus_note = load_snapshot(snapshot_path, now, max_age_hours)
    out.append("corpus   : %s" % corpus_note)

    findings, uncertifiable, ok = [], [], []
    segments = 0
    for ts, text in scanned:
        seg = carry_segment(text)
        if seg is None:
            out.append("entry %s: no『下次触发』segment" % ts)
            continue
        segments += 1
        for n in refs_in(seg):
            if issues is None:
                uncertifiable.append((ts, n, "no usable corpus"))
                continue
            st, closed_at = state_of(issues, n)
            if st is None:
                uncertifiable.append((ts, n, "not in corpus -- NOT the same claim as `open`"))
            elif st == "closed":
                findings.append((ts, n, closed_at))
            else:
                ok.append((ts, n))

    total = len(findings) + len(uncertifiable) + len(ok)
    out.append("scanned  : %d entr%s (of %d), %d carry segment(s), %d GH ref(s)"
               % (len(scanned), "y" if len(scanned) == 1 else "ies",
                  len(entries), segments, total))

    for ts, n, closed_at in findings:
        entry_ts = parse_ts(ts)
        closed_ts = parse_ts(closed_at)
        gap = ""
        if entry_ts and closed_ts:
            gap = "  (%.1fd before that entry)" % (
                (entry_ts - closed_ts).total_seconds() / 86400.0)
        out.append("STALE-CARRY   GH #%s closed %s%s -- carried in『下次触发』of %s"
                   % (n, closed_at or "(time unknown)", gap, ts))
    for ts, n, why in uncertifiable:
        out.append("UNCERTIFIABLE GH #%s -- %s  [entry %s]" % (n, why, ts))
    if ok:
        out.append("OK            %s" % ", ".join("GH #%s" % n for _, n in ok))

    if total == 0:
        out.append("UNCERTIFIABLE -- zero GH refs extracted; a clean bill and an "
                   "empty match print the same, so this is exit 2 (anti-empty-match)")
        return 2, out
    if findings:
        out.append("")
        out.append("%d closed issue(s) still being carried as pending work." % len(findings))
        out.append("⛔ 这不是说那件事做完了 —— 关闭的 issue 里可以躺着真未完的第二件"
                   "(GH #523 就是)。两条出路二选一:把名字从清单里划掉,或者按章程 §2.6 "
                   "给剩下的那件事一行机器可读的 owed 登记。不许留在散文里继续抄。")
        return 3, out
    if uncertifiable:
        out.append("")
        out.append("%d ref(s) unverified -- UNCERTIFIABLE is NOT a pass (RULING 55: "
                   "a list read that misses a number does not prove anything about it)."
                   % len(uncertifiable))
        return 2, out
    out.append("")
    out.append("every carried GH ref is open.")
    return 0, out


# --------------------------------------------------------------------------
# selfcheck: 内建语料,证明三态各自可达。⛔ 它不替代 tests/ 的棘轮,
# 它买的是「这个文件今天还能跑」,不是「它判得对」。
# --------------------------------------------------------------------------
SELFCHECK_CHARTER = """# x

## 当前状态(每次触发后更新)
- **2026-09-16T07:02Z**:立案正文里提到 GH #999(叙事,不是待办)。
  **下次触发**:①GH #523 ②GH #810 ③GH #4242 / #4243 ④裸号 #77 不收
- **2026-09-16T04:05Z**:上一轮。
  **下次触发**:①GH #523(连续第十轮未取)

## 别的节
"""


def selfcheck():
    import tempfile
    now = datetime.datetime(2026, 9, 16, 12, 0, 0, tzinfo=datetime.timezone.utc)
    root = tempfile.mkdtemp(prefix="carryitem-selfcheck-")
    charter = os.path.join(root, "director.md")
    snap = os.path.join(root, "snap.json")
    with open(charter, "w", encoding="utf-8") as fh:
        fh.write(SELFCHECK_CHARTER)
    with open(snap, "w", encoding="utf-8") as fh:
        json.dump({"fetched_at": "2026-09-16T11:00:00Z",
                   "issues": {"523": {"state": "closed",
                                      "closed_at": "2026-09-08T13:12:53Z"},
                              "810": {"state": "open"}}}, fh)
    fails = []

    rc, lines = audit(charter, snap, 1, 48.0, now=now)
    body = "\n".join(lines)
    if rc != 3 or "STALE-CARRY   GH #523" not in body:
        fails.append("closed carried ref must be a finding (got rc=%d)" % rc)
    if "UNCERTIFIABLE GH #4242" not in body:
        fails.append("a ref absent from the corpus must read UNCERTIFIABLE")
    if "GH #999" in body:
        fails.append("only the『下次触发』segment is in scope; #999 leaked in")
    if "GH #4243" not in body:
        fails.append("a chained `/ #<n>` ref must be taken (the #528 shape)")
    if "GH #77" in body:
        fails.append("a bare `#<n>` outside a chain must NOT be taken")

    rc2, lines2 = audit(charter, os.path.join(root, "nope.json"), 1, 48.0, now=now)
    if rc2 != 2 or "STALE-CARRY" in "\n".join(lines2):
        fails.append("a missing corpus must withhold findings (got rc=%d)" % rc2)

    stale = os.path.join(root, "stale.json")
    with open(stale, "w", encoding="utf-8") as fh:
        json.dump({"fetched_at": "2026-09-01T11:00:00Z",
                   "issues": {"523": {"state": "closed"}}}, fh)
    rc3, lines3 = audit(charter, stale, 1, 48.0, now=now)
    if rc3 != 2 or "STALE-CARRY" in "\n".join(lines3):
        fails.append("a stale corpus must withhold findings (got rc=%d)" % rc3)

    import shutil
    shutil.rmtree(root, ignore_errors=True)
    for f in fails:
        print("SELFCHECK FAILED: %s" % f)
    print("SELFCHECK %s" % ("ALL PASS" if not fails else "%d FAILED" % len(fails)))
    return 0 if not fails else 3


def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        epilog="refresh recipe (a round that HAS GitHub MCP): dump "
               "list_issues(state=all) into %s as "
               '{"fetched_at": "<UTC now>", "issues": {"<n>": {"state": ..., '
               '"closed_at": ...}}}' % DEFAULT_SNAPSHOT)
    ap.add_argument("--charter", default=DEFAULT_CHARTER)
    ap.add_argument("--issues", default=DEFAULT_SNAPSHOT,
                    help="issue-state snapshot JSON (default: %s)" % DEFAULT_SNAPSHOT)
    ap.add_argument("--entries", type=int, default=1,
                    help="how many newest『当前状态』entries to scan (default 1)")
    ap.add_argument("--max-age-hours", type=float, default=48.0,
                    help="older corpus withholds findings (default 48)")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args(argv)

    if args.selfcheck:
        return selfcheck()

    rc, lines = audit(args.charter, args.issues, args.entries, args.max_age_hours)
    for line in lines:
        print(line)
    print("VERDICT  : %s (exit %d)" % ({0: "OK", 2: "UNCERTIFIABLE", 3: "FINDINGS"}[rc], rc))
    return rc


if __name__ == "__main__":
    sys.exit(main())
