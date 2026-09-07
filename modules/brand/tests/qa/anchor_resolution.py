#!/usr/bin/env python3
"""Every anchor an analyst may have saved still resolves, and resolves to content.

Stage 5 consolidates the report's export toolbars and its commentary boxes.
Both of those carried `data-section` values, so removing them could take an
anchor off the page, and moving one could leave it resolving onto an empty
div. Analysts have typed these names into Section_Insights sheets and saved
pins against them, so neither is acceptable.

The script lists every `data-section` value and every `section-` element id in
an OLD report, then, in a real browser on the NEW report, replays the exact
resolution rule the report itself uses and asserts each anchor still lands on
something with content in it.

The resolution rule is the one in `js/brand_pins.js` brCaptureContent() and
`js/brand_report.js` _brExportPanel(), in that order:

    1. document.getElementById("section-" + anchor)
    2. for a pf- anchor, getElementById(anchor.replace(/^pf-/, "pf-subtab-"))
    3. the first element with [data-section="<anchor>"] that is not a BUTTON

"Content" means the root holds a table, a chart (an SVG that is not a toolbar
icon), one of the pin capture hooks, or a commentary textarea. A resolve onto
a bare wrapper counts as a failure: the anchor would be live and the pin it
produced would be empty, which is the quiet version of losing it.

Usage:
    python3 anchor_resolution.py OLD.html NEW.html [--keep]
Exit status 0 when every old anchor resolves to content in the new report.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# A value carrying a quote or a template fragment came out of the script
# bundle's own source text, not out of the page markup. Same filter the
# reachability gate uses.
BAD = re.compile(r"['+]|\$\{")


SCRIPT = re.compile(r"<script\b.*?</script>", re.S | re.I)


def markup_only(html):
    """The page's own markup, with every script body removed.

    The bundle contains the literal text of markup it builds at runtime, so a
    scan of the whole file reports ids and anchors that are not on the page.
    The reachability gate learned the same lesson; this is the same fix.
    """
    return SCRIPT.sub("", html)


def anchors_in(html):
    vals = re.findall(r'data-section="([^"]*)"', markup_only(html))
    return sorted({v for v in vals if v and not BAD.search(v)})


def section_ids_in(html):
    ids = re.findall(r'\sid="(section-[^"]+)"', markup_only(html))
    return sorted({i for i in ids if not BAD.search(i)})


HARNESS = """
<script>
window.__anchorProbe = function (anchors, ids) {
  function resolve(a) {
    var el = document.getElementById("section-" + a);
    if (!el && /^pf-/.test(a)) {
      el = document.getElementById(a.replace(/^pf-/, "pf-subtab-"));
    }
    if (!el) {
      var c = document.querySelectorAll('[data-section="' + a + '"]');
      for (var i = 0; i < c.length; i++) {
        if (c[i].tagName !== "BUTTON") { el = c[i]; break; }
      }
    }
    return el;
  }
  function hasContent(el) {
    if (!el) return false;
    if (el.querySelector("table")) return true;
    if (el.querySelector("[data-pin-as-table], [data-pin-as-chart], [data-fn-rel-chart-area]")) return true;
    if (el.querySelector("textarea")) return true;
    var svgs = el.querySelectorAll("svg");
    for (var i = 0; i < svgs.length; i++) {
      if (!svgs[i].closest("button")) return true;
    }
    return false;
  }
  var out = { resolved: {}, content: {}, ids: {} };
  anchors.forEach(function (a) {
    var el = resolve(a);
    out.resolved[a] = !!el;
    out.content[a] = hasContent(el);
  });
  ids.forEach(function (i) { out.ids[i] = !!document.getElementById(i); });
  return out;
};
</script>
"""


def probe(path, anchors, ids, keep=False):
    src = open(path, encoding="utf-8", errors="replace").read()
    payload = json.dumps({"a": anchors, "i": ids})
    runner = (
        HARNESS
        + "<script>window.addEventListener('load',function(){setTimeout(function(){"
        + "var p=" + payload + ";"
        + "var d=document.createElement('div');d.id='__probeout';"
        + "d.textContent=JSON.stringify(window.__anchorProbe(p.a,p.i));"
        + "document.body.appendChild(d);},700);});</script>\n"
    )
    src = src.replace("</head>", runner + "</head>", 1)
    fd, tmp = tempfile.mkstemp(suffix=".html")
    os.write(fd, src.encode("utf-8"))
    os.close(fd)
    try:
        out = subprocess.run(
            [CHROME, "--headless", "--disable-gpu", "--no-sandbox",
             "--virtual-time-budget=10000", "--dump-dom", "file://" + tmp],
            capture_output=True, text=True, timeout=600).stdout
    finally:
        if keep:
            print("harness kept at", tmp)
        else:
            os.unlink(tmp)
    m = re.search(r'<div id="__probeout">(.*?)</div>', out, re.S)
    if not m:
        print("FAIL: the probe produced no output", file=sys.stderr)
        sys.exit(1)
    return json.loads(m.group(1))


def main():
    args = [a for a in sys.argv[1:] if a != "--keep"]
    keep = "--keep" in sys.argv
    if len(args) != 2:
        print(__doc__)
        sys.exit(2)
    old_path, new_path = args
    old = open(old_path, encoding="utf-8", errors="replace").read()
    old_anchors = anchors_in(old)
    old_ids = section_ids_in(old)
    print("old report: %d data-section anchors, %d section ids"
          % (len(old_anchors), len(old_ids)))

    res = probe(new_path, old_anchors, old_ids, keep=keep)

    failures = []
    for a in old_anchors:
        if not res["resolved"].get(a):
            failures.append("anchor %s does not resolve in the new report" % a)
        elif not res["content"].get(a):
            failures.append("anchor %s resolves onto a root with no table, "
                            "chart or textarea in it" % a)
    for i in old_ids:
        if not res["ids"].get(i):
            failures.append("element id %s is gone from the new report" % i)

    ok = len(old_anchors) + len(old_ids) - len(failures)
    print("%d of %d anchors and ids resolve to content"
          % (ok, len(old_anchors) + len(old_ids)))
    for f in failures:
        print("  FAIL " + f)
    if failures:
        sys.exit(1)
    print("PASS")


if __name__ == "__main__":
    main()
