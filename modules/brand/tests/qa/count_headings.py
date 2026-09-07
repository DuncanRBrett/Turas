#!/usr/bin/env python3
"""Count, per destination pane, the tables a reader sees and the headings
that name them.

Duncan's complaint that this script measures: a destination "just lists
everything and shows CEP and attribute tables but does not say what they
are". The measure has to come out of the rendered DOM, not the source,
because a heading hidden by a collapsed ancestor is not a label a reader
can see. That distinction has already caused two bugs in this programme.

What it does, per category tab and per destination pane:

  1. Activates the category tab and the destination.
  2. Expands every disclosure a reader can open inside that pane: the
     Advanced drawer and each Advanced item. "How this works" is left
     closed on purpose: it holds methodology, not tables.
  3. Counts every visible data table (a `table` with at least one body
     row, `offsetParent` non-null).
  4. Counts every visible heading. A heading is `h1`..`h6`, or an element
     carrying `role="heading"`, or one of the panel-native title classes
     listed in TITLE_CLASSES.
  5. Walks the pane in document order and pairs each table with the
     heading that most recently preceded it. A table whose nearest
     preceding heading is shared with an earlier table, or which has no
     preceding heading at all, is reported as unnamed.

Usage:
    python3 count_headings.py REPORT.html [REPORT2.html ...] [--json OUT]
    python3 count_headings.py BEFORE.html AFTER.html --compare

Exit status is 0 unless --require-named is given and some table is
unnamed, or the harness itself failed to report.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

DRIVER = r"""
<script>
(function () {
  var TITLE_CLASSES = ['cb-section-title', 'br-element-title',
                       'ma-section-title', 'ma-subsection-title',
                       'fn-section-title', 'fn-title', 'br-leaf-title',
                       'cb-norms-chart-title', 'cb-ctx-subtitle',
                       'ma-adv-focal-title', 'cb-dop-title', 'cb-shopper-title',
                       'demo-card-title', 'br-adv-toggle'];

  function visible(el) {
    if (!el) return false;
    if (el.hidden) return false;
    if (el.offsetParent === null &&
        getComputedStyle(el).position !== 'fixed') return false;
    var r = el.getBoundingClientRect();
    return (r.width > 0 && r.height > 0);
  }

  function isStrictHeading(el) {
    return /^H[1-6]$/.test(el.tagName);
  }

  function isHeading(el) {
    if (isStrictHeading(el)) return true;
    if (el.getAttribute && el.getAttribute('role') === 'heading') return true;
    for (var i = 0; i < TITLE_CLASSES.length; i++) {
      if (el.classList && el.classList.contains(TITLE_CLASSES[i])) return true;
    }
    return false;
  }

  function isDataTable(el) {
    if (el.tagName !== 'TABLE') return false;
    return el.querySelectorAll('tbody tr, tr').length > 0;
  }

  function text(el) {
    return (el.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 90);
  }

  function openDrawer(pane) {
    // The Advanced drawer itself. Its items are an accordion that keeps
    // one open at a time, so they are opened one by one in walkAdvanced()
    // rather than all at once here.
    pane.querySelectorAll('.br-advanced-toggle').forEach(function (b) {
      if (b.getAttribute('aria-expanded') !== 'true') b.click();
    });
  }

  function walk(pane) {
    var order = [];
    var it = document.createNodeIterator(pane, NodeFilter.SHOW_ELEMENT);
    var el;
    while ((el = it.nextNode())) {
      if (!visible(el)) continue;
      if (isHeading(el)) order.push({ kind: 'h', el: el, text: text(el),
                                      strict: isStrictHeading(el) });
      else if (isDataTable(el)) order.push({ kind: 't', el: el,
                                             text: text(el) });
    }
    return order;
  }

  // One pane's numbers, from a walk already taken. Split out so the same
  // arithmetic serves the whole pane and each tier of it.
  function summarise(order) {
    var headings = order.filter(function (o) { return o.kind === 'h'; });
    var tables = order.filter(function (o) { return o.kind === 't'; });
    // Pair each table with the heading that most recently preceded it. A
    // heading already spent on an earlier table does not name this one:
    // two tables under one heading means the second is unnamed.
    var lastHeading = null, spent = null, pairs = [];
    order.forEach(function (o) {
      if (o.kind === 'h') { lastHeading = o.text; spent = false; return; }
      if (lastHeading === null) {
        pairs.push({ table: o.text, heading: null, shared: false });
      } else {
        pairs.push({ table: o.text, heading: lastHeading,
                     shared: spent === true });
        spent = true;
      }
    });
    var unnamed = pairs.filter(function (p) {
      return p.heading === null || p.shared;
    });
    return {
      tables: tables.length,
      headings: headings.length,
      strictHeadings: headings.filter(function (h) { return h.strict; }).length,
      unnamed: unnamed.length,
      headingText: headings.map(function (h) { return h.text; }),
      unnamedTables: unnamed.map(function (p) {
        return { table: p.table, under: p.heading };
      }),
      allTables: pairs
    };
  }

  // The Advanced drawer is a one-at-a-time accordion, so each item is
  // opened, walked and left; the totals are the sum over the items. The
  // item's own toggle is its heading and is visible either way.
  function walkAdvanced(advEl) {
    var order = [];
    advEl.querySelectorAll('.br-adv-item').forEach(function (item) {
      var tog = item.querySelector('.br-adv-toggle');
      if (tog && tog.tagName === 'BUTTON' &&
          tog.getAttribute('aria-expanded') !== 'true') tog.click();
      order = order.concat(walk(item));
    });
    return order;
  }

  function run() {
    var out = { report: location.pathname.split('/').pop(), panes: [] };

    document.querySelectorAll('.brand-tab-panel, [id^="panel-cat-"]')
      .forEach(function (p) {});

    var catPanels = Array.prototype.filter.call(
      document.querySelectorAll('[id^="panel-cat-"]'),
      function (p) { return p.querySelector('.br-destination'); });

    catPanels.forEach(function (panel) {
      var tab = panel.id.replace(/^panel-/, '');
      if (typeof window.switchBrandTab === 'function') {
        window.switchBrandTab(tab);
      }
      var group = null;
      var firstDest = panel.querySelector('.br-destination');
      if (firstDest) group = firstDest.getAttribute('data-group');

      panel.querySelectorAll('.br-destination').forEach(function (pane) {
        var dest = pane.getAttribute('data-destination');
        var btn = panel.querySelector(
          '.br-destination-btn[data-destination="' + dest + '"]');
        if (btn && typeof window.switchBrandDestination === 'function') {
          window.switchBrandDestination(btn);
        }
        // First the pane as it opens, with nothing expanded: that is what
        // a reader meets. Then again with the Advanced drawer opened, so
        // the drawer's own headings are counted where they can be read.
        var mainEl = pane.querySelector('.br-dest-main');
        var advEl = pane.querySelector('.br-advanced');
        var mainOrder = mainEl ? walk(mainEl) : [];
        openDrawer(pane);
        var advOrder = advEl ? walkAdvanced(advEl) : [];
        var rec = summarise(mainOrder.concat(advOrder));
        rec.group = group;
        rec.dest = dest;
        rec.main = mainEl ? summarise(mainOrder) : null;
        rec.advanced = advEl ? summarise(advOrder) : null;
        out.panes.push(rec);
      });
    });

    var pre = document.createElement('pre');
    pre.id = 'turas-heading-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }

  function boot() { setTimeout(function () { try { run(); } catch (e) {
    var pre = document.createElement('pre');
    pre.id = 'turas-heading-result';
    pre.textContent = JSON.stringify({ error: String(e && e.stack || e),
                                       panes: [] });
    document.body.appendChild(pre);
  } }, 1500); }

  if (document.readyState === 'complete') boot();
  else window.addEventListener('load', boot);
})();
</script>
"""


def build_copy(src):
    html = open(src, encoding="utf-8").read()
    j = html.rindex("</body>")
    html = html[:j] + DRIVER + html[j:]
    fd, path = tempfile.mkstemp(suffix="_headings.html")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path


def measure(src):
    path = build_copy(src)
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox",
           "--allow-file-access-from-files", "--window-size=1280,900",
           "--virtual-time-budget=40000", "--dump-dom", "file://" + path]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    os.unlink(path)
    m = re.search(r'<pre id="turas-heading-result">(.*?)</pre>',
                  proc.stdout, re.S)
    if not m:
        raise RuntimeError("harness did not report for %s:\n%s"
                           % (src, proc.stderr[-2000:]))
    body = (m.group(1).replace("&amp;", "&").replace("&lt;", "<")
            .replace("&gt;", ">").replace("&quot;", '"'))
    res = json.loads(body)
    res["report"] = os.path.basename(src)
    return res


def show(res, verbose=True):
    print("\n%s" % res["report"])
    if res.get("error"):
        print("  harness error: " + res["error"])
        return
    print("  %-9s %-9s %-12s %-12s %-12s %-9s %7s" %
          ("category", "dest", "main t/h", "advanced t/h", "pane t/h",
           "pane t/h1-6", "unnamed"))
    for p in res["panes"]:
        def th(d):
            return "-" if not d else "%d/%d" % (d["tables"], d["headings"])
        print("  %-9s %-9s %-12s %-12s %-12s %-9s %7d" %
              (p["group"], p["dest"], th(p.get("main")),
               th(p.get("advanced")),
               "%d/%d" % (p["tables"], p["headings"]),
               "%d/%d" % (p["tables"], p["strictHeadings"]),
               p["unnamed"]))
        if verbose and p["unnamedTables"]:
            for u in p["unnamedTables"]:
                print("        unnamed: %s" %
                      (u["table"][:66] +
                       ("   [under: %s]" % u["under"] if u["under"] else
                        "   [no heading above it]")))


def main(argv):
    rest = argv[1:]
    args = []
    skip = False
    for i, a in enumerate(rest):
        if skip:
            skip = False
            continue
        if a == "--json":
            skip = True
            continue
        if a.startswith("--"):
            continue
        args.append(a)
    if not args:
        print(__doc__)
        return 2
    if not os.path.exists(CHROME):
        print("Chrome not found at", CHROME)
        return 2
    verbose = "--quiet" not in argv
    results = [measure(a) for a in args]
    for r in results:
        show(r, verbose)
    if "--compare" in argv and len(results) == 2:
        before, after = results
        print("\nBefore and after, per destination pane")
        print("  %-10s %-10s %-18s %-18s" %
              ("category", "dest", "tables (b -> a)", "headings (b -> a)"))
        keyed = {}
        for p in before["panes"]:
            keyed[(p["group"], p["dest"])] = p
        for p in after["panes"]:
            b = keyed.get((p["group"], p["dest"]))
            print("  %-10s %-10s %-18s %-18s unnamed %s -> %s" %
                  (p["group"], p["dest"],
                   "%s -> %s" % (b["tables"] if b else "-", p["tables"]),
                   "%s -> %s" % (b["headings"] if b else "-", p["headings"]),
                   b["unnamed"] if b else "-", p["unnamed"]))
    out = None
    if "--json" in argv:
        i = argv.index("--json")
        if len(argv) > i + 1:
            out = argv[i + 1]
    if out:
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(results, fh, indent=2)
        print("\nwrote " + out)
    if "--require-named" in argv:
        bad = sum(p["unnamed"] for r in results for p in r["panes"])
        print("\n%d unnamed table(s)" % bad)
        return 0 if bad == 0 else 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
