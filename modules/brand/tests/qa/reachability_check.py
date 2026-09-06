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

    Returns {class: [sorted numeric content, ...]} with duplicate payloads
    collapsed. A split render can point several hosts at one payload, so the
    comparison is on the distinct payloads a class carries, not on a count.
    """
    out = {}
    pat = re.compile(
        r'<script type="application/json"[^>]*class="([^"]+)"[^>]*>(.*?)</script>',
        re.S)
    pat2 = re.compile(
        r'<script type="application/json"[^>]*>(.*?)</script>', re.S)
    seen_spans = []
    for m in pat.finditer(html):
        cls = m.group(1).strip()
        body = m.group(2)
        seen_spans.append((m.start(), m.end()))
        out.setdefault(cls, set()).add(_numbers(body))
    # Any island without a class attribute is reported rather than skipped.
    unclassed = 0
    for m in pat2.finditer(html):
        if any(s <= m.start() < e for s, e in seen_spans):
            continue
        unclassed += 1
        out.setdefault("(no class)", set()).add(_numbers(m.group(1)))
    return out, unclassed


def _numbers(body):
    body = body.replace("\\u003c", "<")
    try:
        parsed = json.loads(body)
        body = json.dumps(parsed, sort_keys=True)
    except Exception:
        pass
    return tuple(NUM.findall(body))


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
    o_isl, o_un = islands(old)
    n_isl, n_un = islands(new)
    if o_un or n_un:
        print("  islands with no class attribute: old %d, new %d" % (o_un, n_un))
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
