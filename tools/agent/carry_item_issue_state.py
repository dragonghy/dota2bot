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
    NO-HANDOFF    最新一条 entry 根本没写『下次触发』  ⇒ finding(exit 3),见下

NO-HANDOFF(RULING 67,2026-09-16T19:0xZ)
----------------------------------------
第一版把「最新 entry 没有清单」和「没有语料 / 语料过期 / 正则零命中」**归到同一个
出口(exit 2 UNCERTIFIABLE)**,而这两件事在**性质**上不同:

  * 没有语料 / 语料过期 = **这一轮没人能看** —— 环境问题,本轮无解,沉默是对的;
  * 最新 entry 没有清单 = **一个在完全可读的语料上被正面观测到的事实** ——
    棒掉了,而且掉在总监自己手里。

⇒ 后者判 **finding(exit 3)**,不判 UNCERTIFIABLE。
**立案现场**:`2026-09-16T15:55Z`(RULING 66)那条 entry 收尾没写『下次触发』;
下一轮(19:0xZ)跑本腿,逐字读回

    entry 2026-09-16T15:55Z: no『下次触发』segment
    scanned  : 1 entry (of 86), 0 carry segment(s), 0 GH ref(s)
    UNCERTIFIABLE -- zero GH refs extracted ... (anti-empty-match)

—— **三行都是真的,而合起来读像「本轮没什么可查」**;真相是 13:18Z 那份 **10 条**
清单(含 `GH #810/#240/#528`)从此**没有任何一条腿在看它**。
⚠️ **失效方向与本仓那一族逐字同型**:UNCERTIFIABLE 读起来像「工具没跑成」,
于是**掉棒被读成了工具问题**,而工具问题下一轮自己会好,掉棒不会。

**回落(fallback)—— 只在 NO-HANDOFF 这一种情形下开**:往回走到最近一条**写了**清单
的 entry,把**那一份**当作当下的活棒去交叉读,并打印距离(几条 entry / 几小时)。
⭐ **这不是违反 LIMITS 3,是 LIMITS 3 的前提失效**:那一条说旧清单「已经被下一轮取代」
所以不该对它开火 —— **而一份清单是被下一份清单取代的,不是被下一轮取代的**。
下一轮没写清单时,旧的那份**就是现役的棒**,回落读它恰恰是唯一正确的作用域。

⛔ **NO-HANDOFF 本身是 finding,与回落读到什么无关**:哪怕回落清单里每个号都 open,
本腿仍然 exit 3 —— 要被修的是**这一轮没交棒**,而修法只有一个:**本轮把清单写出来**。

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
3. **默认只看最新一条 entry —— 除非最新那条没写清单。** 旧 entry 里的清单**通常**已经被
   下一轮的清单取代,拿它出 finding 等于对着历史开火;`--entries N` 可以放宽,但那时打出
   来的是**历史**不是**当下**。⭐ **唯一的例外是 NO-HANDOFF**(见上):最新 entry 没写清单
   时**没有东西取代旧清单**,于是回落到最近一份清单读到的是**当下**,不是历史。
   回落只跳过**没有清单**的 entry,遇到第一份清单就停,距离照登。

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


def _line_around(text, pos):
    """-> (line_text, offset_of_pos_within_line)."""
    start = text.rfind("\n", 0, pos) + 1
    end = text.find("\n", pos)
    if end < 0:
        end = len(text)
    return text[start:end], pos - start


def is_list_mark(text, pos):
    """True when the『下次触发』at `pos` is the anchor of an actual list.

    Two conditions, both read off the line the mark sits on:

      * the mark is **inside a bold run** -- an odd number of `**` before it on
        that line.  Every list this charter has ever written bolds the mark
        (`**下次触发**:`, `**⑨ 下次触发**:`, `**下次触发**(⭐ …):`);
      * a colon (`:` or `:`) follows it **on the same line**.  A list announces
        itself; a sentence that merely talks about the list does not.

    ⛔ Neither condition alone survives the real corpus, and that is why the
    registered hole `carry_mark_prose_vs_list` sat OWED with both of its
    candidate anchors refuted: a bare `**下次触发**` anchor misses
    `**⑨ 下次触发**:`, and a bare colon anchor misses `**下次触发**(⭐ …):`.
    The conjunction catches all three shapes and rejects both prose shapes this
    charter actually writes (`⇒ 进下次触发 ⑭。` and `上一轮「下次触发 ①」逐字…`).

    Measured on the whole charter the day this landed: **94 entries, 0 of them
    had a carry mark without a qualifying list anchor.**
    """
    line, off = _line_around(text, pos)
    if line[:off].count("**") % 2 == 0:
        return False
    tail = line[off + len(u"下次触发"):]
    return (":" in tail) or (u":" in tail)


def carry_segment_info(entry_text):
    """-> (segment_or_None, kind, n_marks, n_anchors, n_shadowing)

    kind is `"list"` when a real list anchor was found, `"prose-fallback"` when
    the entry mentions『下次触发』but never anchors a list (then the segment is
    the LAST mention, i.e. exactly the pre-RULING-75 behaviour), and `None`
    when the entry has no mention at all (RULING 67's NO-HANDOFF).

    WHY THE ANCHOR, AND NOT "THE LAST MENTION" (RULING 75, 2026-09-18)
    -----------------------------------------------------------------
    The first version took the **last**『下次触发』in the entry, because the
    narrative routinely discusses the list before the list appears and taking
    the first mention dragged the whole narrative into scope (three false
    findings on the round that landed this leg).

    That rule has the mirror-image failure and it fired on real corpus: a
    mention that comes **after** the list truncates the list away.  Entry
    `2026-09-18T01:15Z` ends with a `[同轮收尾追加,push 之后]` block whose ⑳
    reads, verbatim, `⇒ 进下次触发 ⑭。` — a later mention with no `GH #` after
    it.  The leg therefore read:

        scanned  : 1 entry (of 94), 1 carry segment(s), 0 GH ref(s)
        UNCERTIFIABLE -- zero GH refs extracted ... (anti-empty-match)

    while the live list three lines above it carried **8** refs
    (`#856 #867 #240 #843 #859 #810 #548 #528`), none of which was cross-read.

    ⚠️ **The exit code is the expensive half.** `1 carry segment(s)` is true,
    `0 GH ref(s)` is true, and exit 2 says — in this leg's own words (RULING 67)
    — "nobody could look this round, and that fixes itself next round".  It does
    not fix itself: the mention is a permanent part of that entry, so every
    later round reads the same silent 0.  This is the same shape RULING 67 was
    written to abolish, arriving through the segment picker instead of through
    the corpus.

    ⛔ **"The latest mention that yields refs" was tried and refuted by the
    corpus**, which is the only reason this docstring can name a rule at all:
    on entry `2026-09-11T04:19Z` the list itself carries no `GH #` at all, and
    that rule walks back past it to a narrative quote (`上一轮「下次触发 ①」`)
    and reports `#624 / #739` — refs that were never carried.  The anchor test
    reads that entry correctly (no refs), and over all 94 entries it changes
    exactly **one** answer: the broken one.
    """
    hits = list(CARRY_MARK_RE.finditer(entry_text))
    if not hits:
        return None, None, 0, 0, 0
    anchors = [h for h in hits if is_list_mark(entry_text, h.start())]
    if not anchors:
        # No list was ever anchored -- fall back to the old rule rather than
        # accuse.  This is the registered hole `carry_mark_prose_vs_list`: an
        # entry that only TALKS about the list still reads as if it had one.
        # ⛔ Deliberately not promoted to NO-HANDOFF here: 0 of 94 real entries
        # take this branch, so there is no live evidence to calibrate against,
        # and a false NO-HANDOFF accuses the round that did write its list.
        # What changed is that the branch is no longer silent (see audit()).
        return entry_text[hits[-1].start():], "prose-fallback", len(hits), 0, 0
    chosen = anchors[-1]
    shadowing = sum(1 for h in hits if h.start() > chosen.start())
    return (entry_text[chosen.start():], "list", len(hits), len(anchors),
            shadowing)


def carry_segment(entry_text):
    """The『下次触发』list of one entry, or None when the entry has none."""
    return carry_segment_info(entry_text)[0]


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

    # RULING 67: 最新 entry 没写『下次触发』⇒ 棒掉了(finding),并回落到最近一份
    # 清单去读 —— 一份清单是被**下一份清单**取代的,不是被下一轮取代的。
    handoff_gap = None
    if carry_segment(entries[0][1]) is None and not any(
            carry_segment(text) is not None for _, text in scanned):
        fallback = None
        for idx in range(len(scanned), len(entries)):
            if carry_segment(entries[idx][1]) is not None:
                fallback = (idx, entries[idx][0])
                scanned = list(scanned) + [entries[idx]]
                break
        handoff_gap = (entries[0][0], fallback)

    issues, corpus_note = load_snapshot(snapshot_path, now, max_age_hours)
    out.append("corpus   : %s" % corpus_note)

    findings, uncertifiable, ok = [], [], []
    segments = 0
    for ts, text in scanned:
        seg, kind, n_marks, n_anchors, shadowing = carry_segment_info(text)
        if seg is None:
            out.append("entry %s: no『下次触发』segment" % ts)
            continue
        segments += 1
        if kind == "prose-fallback":
            out.append("CARRY-PROSE   entry %s: %d『下次触发』mention(s), "
                       "none of them anchors a list (bold + a colon on the same line). "
                       "Reading the last mention -- registered hole "
                       "`carry_mark_prose_vs_list`; this is a note, not a finding"
                       % (ts, n_marks))
        elif shadowing:
            out.append("CARRY-ANCHOR  entry %s: %d『下次触发』mention(s), "
                       "%d of them a list anchor; read from the last anchor, so the "
                       "%d later prose mention(s) no longer truncate the list "
                       "(RULING 75)" % (ts, n_marks, n_anchors, shadowing))
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

    if handoff_gap is not None:
        newest_ts, fallback = handoff_gap
        out.append("NO-HANDOFF    entry %s ends with no『下次触发』list -- the baton was "
                   "dropped by the round that wrote it, not by the environment" % newest_ts)
        if fallback is None:
            out.append("              no earlier entry carries a list either -- "
                       "nothing to fall back to")
        else:
            idx, ts = fallback
            newest_dt, back_dt = parse_ts(newest_ts), parse_ts(ts)
            if newest_dt and back_dt:
                age = ", %.1fh older" % (
                    (newest_dt - back_dt).total_seconds() / 3600.0)
            else:
                # 本仓的散文时刻惯例允许 `T10:1xZ`,那种戳算不出小时数。
                # ⛔ 不许因此把年龄一声不响地省掉:「回落了 1 条」与「回落到 30 小时前」
                # 对读的人是两件事,而省略号让它们印出来一模一样。
                age = ", age not computable (fuzzy stamp)"
            out.append("CARRY-FROM    %s (%d entr%s back%s) is still the live list, and "
                       "is read below -- a list is superseded by the NEXT list, not by "
                       "the next round"
                       % (ts, idx, "y" if idx == 1 else "ies", age))

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

    if total == 0 and handoff_gap is None:
        out.append("UNCERTIFIABLE -- zero GH refs extracted; a clean bill and an "
                   "empty match print the same, so this is exit 2 (anti-empty-match)")
        return 2, out
    if findings or handoff_gap is not None:
        out.append("")
        if findings:
            out.append("%d closed issue(s) still being carried as pending work."
                       % len(findings))
            out.append("⛔ 这不是说那件事做完了 —— 关闭的 issue 里可以躺着真未完的第二件"
                       "(GH #523 就是)。两条出路二选一:把名字从清单里划掉,或者按章程 §2.6 "
                       "给剩下的那件事一行机器可读的 owed 登记。不许留在散文里继续抄。")
        if handoff_gap is not None:
            out.append("⛔ NO-HANDOFF 本身就是 finding,与回落清单读到什么无关(RULING 67):"
                       "要被修的是**这一轮没交棒**,而修法只有一个 —— 本轮把『下次触发』写出来。"
                       "⚠️ 它不读作 UNCERTIFIABLE:没有语料是「这一轮没人能看」,"
                       "没写清单是「棒掉了」,后者下一轮不会自己好。")
        if total == 0:
            out.append("⚠️ 回落之后仍然是 0 个 GH ref(anti-empty-match 的分母照登):"
                       "清单可能本来就不带号,那一格本腿没有话说。")
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

    # RULING 67: 最新 entry 没写清单 ⇒ finding + 回落读上一份清单。
    nohandoff = os.path.join(root, "nohandoff.md")
    with open(nohandoff, "w", encoding="utf-8") as fh:
        fh.write(SELFCHECK_CHARTER.replace(
            "  **下次触发**:①GH #523 ②GH #810 ③GH #4242 / #4243 ④裸号 #77 不收",
            "  本轮收尾忘了写清单。"))
    rc4, lines4 = audit(nohandoff, snap, 1, 48.0, now=now)
    body4 = "\n".join(lines4)
    if rc4 != 3 or "NO-HANDOFF" not in body4:
        fails.append("a newest entry with no carry list must be a finding (got rc=%d)" % rc4)
    if "CARRY-FROM    2026-09-16T04:05Z" not in body4:
        fails.append("NO-HANDOFF must fall back to the last entry that carries a list")
    if "STALE-CARRY   GH #523" not in body4:
        fails.append("the fallen-back list must actually be cross-read")

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
