#!/usr/bin/env python3
"""Strip real client abbreviations out of the PUBLISHED demo report.

The v2 renderer's own source comments name the studies each behaviour was
proven on. That is fine inside Turas and inside a client deliverable, but the
website demo is a public file and a visitor can read its source. Every hit is
in a JavaScript or CSS comment, plus two inert string literals in the
self-test, so replacing the token changes no behaviour.

Usage: scrub_client_names.py <in.html> <out.html>
"""
import re
import sys

REPLACEMENTS = [
    (r"\bCCPB\b", "a tracker study"),
    (r"\bSACAP\b", "the sample fixture"),
    (r"\bSACS\b", "a staff survey"),
    (r"\bCCS\b", "a box-only study"),
    (r"\bIPK\b", "a brand study"),
    (r"\bASSA\b", "a client study"),
    (r"\bVAS\b", "a client study"),
    (r"sacap", "fixture"),
]

CHECK = ["CCPB", "SACAP", "sacap", "SACS", "CCS", "IPK", "ASSA", "VAS",
         "Helderberg", "Electrum", "Peninsula", "Coca-Cola"]


def main() -> int:
    src, dst = sys.argv[1], sys.argv[2]
    text = open(src, encoding="utf-8").read()
    for pattern, replacement in REPLACEMENTS:
        text, n = re.subn(pattern, replacement, text)
        print(f"  {pattern:20} -> {n} replaced")
    open(dst, "w", encoding="utf-8").write(text)

    remaining = {t: len(re.findall(r"\b" + re.escape(t) + r"\b", text))
                 for t in CHECK}
    remaining = {k: v for k, v in remaining.items() if v}
    print("remaining client tokens:", remaining or "none")
    return 1 if remaining else 0


if __name__ == "__main__":
    sys.exit(main())
