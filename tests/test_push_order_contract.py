#!/usr/bin/env python3
"""Acceptance for the push-order contract (director RULING 69, GH #865).

THE INCIDENT THIS PINS
----------------------
The team's standard push path is two commands, in this order:

    git push -u origin <branch> && git push origin HEAD:main

That order is not a style preference.  Two independent pieces of machinery are
keyed to it, and **both degrade silently — never loudly — when it is flipped**:

  1. `.githooks/pre-push` computes the fast Lua leg's scope as
     `git diff --name-only origin/main...HEAD`, and an EMPTY answer means RUN
     EVERYTHING (fail-closed, by design).  `git push origin HEAD:main` moves
     the local `origin/main` ref to HEAD, so any push that follows it sees an
     empty diff and pays for the whole Lua set.  Measured on the director's own
     2026-09-17T01:00Z round, which ran main-first: the main push read
     `lua gate: SKIPPED BY SCOPE`, the branch push that followed it read
     `lua 411 ran ... 639.7s`.
  2. `tools/agent/rule6_memo.py` keys one green three-leg reading by
     `(HEAD^{tree}, origin/main)`.  The same ref move changes the second half
     of that key, so the twin push of a byte-identical tree is a **guaranteed**
     MISS.  Not a probability — an identity.

Under the documented order neither fires: a branch push does not move
`origin/main`, so the second push asks the same question and the memo answers
it for free.

WHY A RATCHET AND NOT A SENTENCE.  `iterations/DECISIONS_NEEDED.md` item 17
(2026-09-17T01:00Z) proposed flipping the order to main-first and declared
"no reply = I execute it next round".  The two costs above were measured by the
batch desk **two hours later**, in `iterations/streams/batch-desk.md:12517`,
where they arrived as three mutually exclusive candidates for the director to
rule on.  The flip was one round away from landing on the strength of a
document that predated the measurement.  A rule whose only carrier is prose in
a 16k-line charter has, by this repo's own accounting, a lifetime of about one
round; this file is that rule with a way to refuse a push.

WHAT THIS DOES NOT CLAIM.  It does not claim the order is optimal, and it does
not measure anything itself.  It asserts only that the three places that must
agree still do: the rule file, the memo that quotes it, and the hook whose
scope computation is the reason it matters.  If a future ruling flips the order
on purpose, the honest path is to change those mechanisms (or accept the cost
in writing) and update this file in the same commit — which is exactly the
review this file exists to force.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RULE_FILE = os.path.join(REPO, ".claude", "rules", "claude-code.md")
MEMO = os.path.join(REPO, "tools", "agent", "rule6_memo.py")
HOOK = os.path.join(REPO, ".githooks", "pre-push")

checks = 0
failures = []


def check(cond, what):
    global checks
    checks += 1
    if not cond:
        failures.append(what)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


# A push command with its placeholder normalised, so `<branch>` and
# `<this-session-branch>` compare equal.  Everything else stays byte-exact:
# the point is that the memo QUOTES the rule file, not that it paraphrases it.
PUSH_LINE_RE = re.compile(r"git push -u origin <[^>]+>\s*&&\s*git push origin HEAD:main")


def normalise(line):
    return re.sub(r"<[^>]+>", "<BRANCH>", " ".join(line.split()))


def push_path_block(text):
    """The fenced block under the rule file's `## Push path` heading."""
    m = re.search(r"^##\s*Push path[^\n]*\n(.*?)(?=^##\s)", text, re.S | re.M)
    if not m:
        return None
    fence = re.search(r"```(?:bash)?\n(.*?)```", m.group(1), re.S)
    return fence.group(1) if fence else None


def main():
    # ---- 1. the rule file states the order, and states it branch-first ----
    rule_text = read(RULE_FILE)
    block = push_path_block(rule_text)
    check(block is not None,
          "rule file: `## Push path` still has a fenced command block "
          "(if this section was restructured, re-read RULING 69 before "
          "re-anchoring this test)")

    rule_cmd = None
    if block:
        # The ORDER check must not hide behind the SHAPE check. A realistic
        # flip splits the path onto two lines, which defeats the one-line
        # regex; if that were the only anchor the test would still go red, but
        # it would go red saying "the two-command path is missing" -- a true
        # sentence that misnames the defect. Order is asserted on the bare
        # token positions, so it fires whatever the surrounding punctuation.
        check("-u origin" in block and "HEAD:main" in block,
              "rule file: the push-path block still names both pushes "
              "(branch push `-u origin ...` and `HEAD:main`)")
        if "-u origin" in block and "HEAD:main" in block:
            check(block.index("-u origin") < block.index("HEAD:main"),
                  "rule file: the BRANCH push must come before `HEAD:main`. "
                  "Flipping it moves local origin/main before the second push, "
                  "which (a) empties the hook's Lua scope => run-everything "
                  "(~640s measured) and (b) makes rule6_memo a guaranteed MISS. "
                  "Both are identities, not flakes -- see GH #865 / RULING 69.")

        m = PUSH_LINE_RE.search(block)
        check(m is not None,
              "rule file: the push-path block still spells the path as the "
              "single `git push -u origin <branch> && git push origin "
              "HEAD:main` line that rule6_memo.py quotes")
        if m:
            rule_cmd = normalise(m.group(0))

    # ---- 2. the memo quotes the SAME order it is keyed to ----
    memo_text = read(MEMO)
    # Whole LINE, not a regex that can stop at whichever push it meets first:
    # a flipped quote puts `HEAD:main` first, and a pattern anchored on it
    # would return a slice with only one of the two pushes in it -- the order
    # check would then be skipped on exactly the mutant it exists to catch.
    quoted = next((ln for ln in memo_text.splitlines()
                   if "git push" in ln and "HEAD:main" in ln
                   and "-u origin" in ln), None)
    check(quoted is not None,
          "rule6_memo.py: its head note still quotes the two-push path on one "
          "line (that quote is the memo's stated premise)")
    if quoted:
        check(quoted.index("-u origin") < quoted.index("HEAD:main"),
              "rule6_memo.py: the path it quotes puts `HEAD:main` first. "
              "The memo's key is (HEAD^{tree}, origin/main); under that "
              "order the twin push is a guaranteed MISS, and the file "
              "would be documenting the one case it cannot serve.")
    m = PUSH_LINE_RE.search(memo_text)
    check(m is not None,
          "rule6_memo.py: its head note still quotes the mandated push path "
          "(that quote is the memo's stated premise; without it the key's "
          "dependence on origin/main has no explanation in the file)")
    if m and rule_cmd:
        check(normalise(m.group(0)) == rule_cmd,
              "rule6_memo.py quotes a push path that differs from the rule "
              "file's: memo=%r rule=%r. The memo's key is (HEAD^{tree}, "
              "origin/main); if the real order no longer matches the quoted "
              "one, the memo misses on every twin push and says nothing."
              % (normalise(m.group(0)), rule_cmd))

    # ---- 3. the coupling that makes the order load-bearing still exists ----
    check("origin/main" in memo_text and "rev-parse\", \"origin/main" in memo_text,
          "rule6_memo.py: the key still reads `origin/main` (this is WHY the "
          "order matters; if the key no longer depends on it, RULING 69's "
          "second cost is gone and the ruling should be re-read, not this "
          "test silenced)")

    hook_text = read(HOOK)
    check("origin/main...HEAD" in hook_text,
          ".githooks/pre-push: the Lua leg's scope is still computed against "
          "`origin/main...HEAD` (this is WHY the order matters; if scope no "
          "longer depends on that ref, RULING 69's first cost is gone)")
    check(re.search(r"empty[^\n]*RUN EVERYTHING|RUN EVERYTHING", hook_text) is not None,
          ".githooks/pre-push: an empty scope still means run-everything. "
          "That fail-closed direction is deliberate (skipping needs a positive "
          "answer); it is also what makes a post-main push expensive.")

    # ---- 4. the rule file explains the order, so the next round need not
    #         re-derive it from a 16k-line charter ----
    if block is not None:
        section = re.search(r"^##\s*Push path[^\n]*\n(.*?)(?=^##\s)",
                            rule_text, re.S | re.M).group(1)
        check("GH #865" in section,
              "rule file: the `## Push path` section must name GH #865, the "
              "issue carrying the measurement. An order with no stated reason "
              "is an order that gets flipped again -- item 17 flipped it once "
              "on a document that predated the reading.")
        check("origin/main" in section,
              "rule file: the `## Push path` section must say that pushing "
              "main first moves `origin/main` locally. The cost is invisible "
              "at the prompt: both pushes succeed, the second one just pays.")

    print("\n%d checks, %d failures" % (checks, len(failures)))
    for f in failures:
        print("  FAILED: %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
