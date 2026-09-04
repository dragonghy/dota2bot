#!/usr/bin/env python3
"""Ratchet for `campsel_domain.premise_sites()`'s DOC-FIELD parse (GH #241 audit).

WHY THIS FILE EXISTS
--------------------
`tests/test_detector_source_constants.py` asks two questions of the API
reference's `GetNeutralSpawners()` row:

    (A)  set(doc_fields) >= {'team', 'type'}      -- "the section still parses"
    (B)  doc_fields.get('type') != 'int'          -- "the retired refuter did
                                                     not come back"

and (A) exists, in its own words, because "if this section stops parsing, the
audit above is reading nothing".  On 2026-09-04 that is exactly what happened.
Strategy's 07:45Z landing (GH #480) rewrote the `.type` row's annotation from a
bare word into a sentence that wraps a line:

    - `type` (unverified -- **and the method that settled `.team` provably
      cannot settle it**): ...

The parser was `^-\\s*`(\\w+)`\\s*\\((\\w+)\\)` -- the WHOLE parenthetical had to
be one bare word -- so the row matched nothing and `type` left `doc_fields`
entirely.  (A) went red and said so.  (B) went **quietly true by absence**: a
refuter-detector cannot see an `int` in a key that is not there.

That asymmetry is what this file pins.  Restoring green was never the job;
restoring the CONTENT of (B) was, and green alone cannot tell the two apart.

WHAT IS PINNED
--------------
  LAYER 1 -- the live tree.  The shipped doc must still yield both keys, and
  `type` must carry a real annotation rather than a placeholder.

  LAYER 2 -- the failure direction.  An annotation that re-asserts the retired
  scalar type must still be READ as `int`, whether it is written `(int)` or
  `(int, but see ...)`.  This is the load-bearing case: the naive widening
  (`\\(([^)]*)\\)`, i.e. capture up to the closing paren) also turns the tree
  green, and it would report `'int, but see ...'` -- which is `!= 'int'`, so
  check (B) would pass on a doc that had put the refuter back.  Green is
  reachable two ways and only one of them is the fix.

  LAYER 3 -- the reverse assertion.  A checker that cannot fail is not a
  checker: the old regex is re-applied to the live doc and must NOT find
  `type`, which is what makes LAYER 1 a reading and not a tautology.

Usage:  python3 tests/test_campsel_premise_doc_parse.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))

import campsel_domain as CS                                    # noqa: E402

API_DOC = os.path.join(ROOT, 'docs', 'BOT_API_REFERENCE.md')

OLD_RE = r'^-\s*`(\w+)`\s*\((\w+)\)'          # the form that went blind

failures = []


def check(name, ok, detail=''):
    print('  %-4s %s%s' % ('ok' if ok else 'FAIL', name,
                           '' if ok else '   [%s]' % detail))
    if not ok:
        failures.append(name)


def fields(doc_text):
    """Run the real parser over a doc body supplied by this test."""
    return CS.premise_sites(srcs={'doc': doc_text})['doc_fields']


def doc_with_type_row(row):
    """The live doc with the `.type` bullet replaced by `row`.

    Built from the shipped file rather than from a hand-written stub so the
    section header, the terminator and the surrounding rows are the real ones:
    a stub can pass while the actual section shape has moved.
    """
    src = open(API_DOC, encoding='utf-8').read()
    m = re.search(r'###\s*`GetNeutralSpawners\(\)`(.*?)(?=\n###\s)', src, re.S)
    assert m, 'the GetNeutralSpawners section is gone -- this file cannot run'
    body = m.group(1)
    # The `.type` bullet runs to the next bullet at column 0.
    m2 = re.search(r'^-\s*`type`\s*\(.*?(?=^- `)', body, re.S | re.M)
    assert m2, 'no `type` bullet in the live section'
    return src[:m.start(1)] + body[:m2.start()] + row + body[m2.end():] \
        + src[m.end(1):]


def main():
    print('=== LAYER 1: the live doc parses, and `type` carries an annotation ===')
    live = CS.premise_sites()['doc_fields']
    check('both premise fields are present in the shipped doc',
          set(live) >= {'team', 'type'}, str(live))
    check('`type` is annotated `unverified` (the row GH #480 rewrote)',
          live.get('type') == 'unverified', str(live.get('type')))
    check('`team` is still annotated `settled`',
          live.get('team') == 'settled', str(live.get('team')))

    print()
    print('=== LAYER 2: the refuter is still read through a rich annotation ===')
    cases = [
        ('bare word, the pre-GH #480 form',
         '- `type` (int): "small, medium, large, ancient"\n', 'int'),
        ('THE LOAD-BEARING ONE -- int plus prose in the same parenthesis',
         '- `type` (int, but see the note below): a scalar\n', 'int'),
        ('int announced across a wrapped line',
         '- `type` (int -- **and the retired row said so\n  out loud**): x\n', 'int'),
        ('the shipped shape: a non-scalar leading word',
         '- `type` (unverified -- **cannot be settled\n  this way**): x\n', 'unverified'),
    ]
    for name, row, want in cases:
        got = fields(doc_with_type_row(row)).get('type')
        check('%s -> %r' % (name, want), got == want, repr(got))

    print()
    print('  (an annotation read as %r is what makes check (B) in '
          'test_detector_source_constants.py fire; a value of '
          "'int, but see ...' would be != 'int' and pass)" % 'int')

    print()
    print('=== LAYER 3: reverse assertion -- the old regex really is blind here ===')
    src = open(API_DOC, encoding='utf-8').read()
    m = re.search(r'###\s*`GetNeutralSpawners\(\)`(.*?)(?=\n###\s)', src, re.S)
    section = m.group(1) if m else ''
    old = dict(re.findall(OLD_RE, section, re.M))
    check('the old `\\((\\w+)\\)` form finds `team` on this doc',
          'team' in old, str(sorted(old)))
    check('the old form does NOT find `type` -- LAYER 1 is a reading, not a '
          'tautology', 'type' not in old, str(sorted(old)))

    print()
    if failures:
        print('%d FAILED: %s' % (len(failures), ', '.join(failures)))
        return 1
    print('all checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
