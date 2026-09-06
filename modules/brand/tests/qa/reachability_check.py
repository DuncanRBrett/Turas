#!/usr/bin/env python3
"""Compare the reachable surface of two brand HTML reports.

Stage 2 of the brand simplification rehomes every analysis behind five
destinations. Nothing may be lost, and no pin anchor, section id or Excel
export target may change. This script is the gate for that claim: it lists
every data-subpanel and every data-section in an old report and a new one and
asserts the sets are equal, and it compares the JSON islands so a rehoming
cannot quietly change a number.

Usage:
    python3 reachability_check.py OLD.html NEW.html
Exit status 0 when the reports agree, 1 otherwise.
"""
import json
import re
import sys
from collections import Counter

# A value containing a quote or a JS concatenation fragment came from the
# script bundle, not from the page markup.
BAD = re.compile(r"['+]|\$\{")


def attr_values(html, attr):
    vals = re.findall(r'%s="([^"]*)"' % attr, html)
    return {v for v in vals if v and not BAD.search(v)}


def element_ids(html):
    ids = re.findall(r'\sid="(section-[^"]+)"', html)
    return {i for i in ids if not BAD.search(i)}


NUM = re.compile(r'-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?')


def islands(html):
    """Every application/json island, keyed by its class, with its numbers.

    Returns ({class: {numeric content, ...}}, skipped) with duplicate payloads
    collapsed. A split render can point several hosts at one payload, so the
    comparison is on the distinct payloads a class carries, not on a count.

    A body that does not parse as JSON is NOT compared. The page carries the
    whole JavaScript bundle in a <script> of its own, and that bundle contains
    the literal text of island tags it builds at runtime, so a regex sweep
    finds spans that are source code rather than data. Harvesting digits out
    of those and calling them "identical" would be an accident, not a check,
    and the bundle is a file this work edits. They are counted and named
    instead.
    """
    out = {}
    skipped = []
    pat = re.compile(
        r'<script type="application/json"[^>]*class="([^"]+)"[^>]*>(.*?)</script>',
        re.S)
    pat2 = re.compile(
        r'<script type="application/json"[^>]*>(.*?)</script>', re.S)
    seen_spans = []
    for m in pat.finditer(html):
        cls = m.group(1).strip()
        seen_spans.append((m.start(), m.end()))
        nums = _numbers(m.group(2))
        if nums is None:
            skipped.append(cls)
            continue
        out.setdefault(cls, set()).add(nums)
    for m in pat2.finditer(html):
        if any(s <= m.start() < e for s, e in seen_spans):
            continue
        nums = _numbers(m.group(1))
        if nums is None:
            skipped.append("(no class)")
            continue
        out.setdefault("(no class)", set()).add(nums)
    return out, skipped


def _numbers(body):
    """Numeric content of one island, or None when the body is not JSON."""
    body = body.replace("\\u003c", "<")
    try:
        parsed = json.loads(body)
    except Exception:
        return None
    return tuple(NUM.findall(json.dumps(parsed, sort_keys=True)))


def report(name, old, new):
    ok = True
    missing = sorted(old - new)
    added = sorted(new - old)
    if missing:
        ok = False
        print("  LOST from %s (%d): %s" % (name, len(missing), ", ".join(missing)))
    if added:
        ok = False
        print("  NEW in %s (%d): %s" % (name, len(added), ", ".join(added)))
    if ok:
        print("  %s: %d values, identical" % (name, len(old)))
    return ok


def main(old_path, new_path):
    old = open(old_path, encoding="utf-8").read()
    new = open(new_path, encoding="utf-8").read()
    ok = True

    print("Reachability")
    ok &= report("data-subpanel", attr_values(old, "data-subpanel"),
                 attr_values(new, "data-subpanel"))
    ok &= report("data-section", attr_values(old, "data-section"),
                 attr_values(new, "data-section"))
    ok &= report("section ids", element_ids(old), element_ids(new))

    print("JSON islands")
    o_isl, o_skip = islands(old)
    n_isl, n_skip = islands(new)
    if o_skip or n_skip:
        print("  not JSON, not compared: old %d %s, new %d %s"
              % (len(o_skip), sorted(set(o_skip)),
                 len(n_skip), sorted(set(n_skip))))
        if sorted(o_skip) != sorted(n_skip):
            ok = False
            print("  the set of unparseable spans changed between the reports")
    ok &= report("island classes", set(o_isl), set(n_isl))
    for cls in sorted(set(o_isl) & set(n_isl)):
        if o_isl[cls] == n_isl[cls]:
            print("  %s: %d distinct payload(s), numeric content identical"
                  % (cls, len(o_isl[cls])))
        else:
            ok = False
            print("  %s: NUMERIC CONTENT DIFFERS (old %d distinct, new %d)"
                  % (cls, len(o_isl[cls]), len(n_isl[cls])))

    print("Result:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
