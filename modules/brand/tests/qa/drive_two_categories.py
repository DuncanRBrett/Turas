#!/usr/bin/env python3
"""Drive two full-depth categories in one brand report, in headless Chrome.

Why this exists
---------------
brApplyAllComparisonSets() loops over the distinct data-group values it finds
and applies each category's comparison set. It has only ever run against one
group, because the IPK fixture carries exactly one full-depth category and the
three example config generators are broken on main. A loop that has only ever
seen one item is a loop that has not been tested.

What this proves, exactly
-------------------------
The fixture's one full-depth category panel is CLONED in the browser, before
the panel scripts register, under a second category key. Both panels then
register real BrandSelector subscribers with real tables and real charts.
The script asserts that:

  * two distinct data-group values are present and both are driven;
  * each header's comparison set reaches only its own category's panels, so
    picking comparators in one leaves the other untouched;
  * a Chart brands deviation in one category does not leak into the other;
  * nothing throws and no console error is raised across two groups.

What this does NOT prove
------------------------
The clone is the same category twice. It carries the same brand list, the same
numbers and the same labels. So this says nothing about two categories with
DIFFERENT brand lists, and nothing about the category switcher's behaviour on
real, differently shaped data. It closes the "the loop has never iterated"
gap and no more. A real second full-depth category cannot be built from this
fixture without inventing survey data, which is not done.

Usage:
    python3 drive_two_categories.py REPORT.html [--keep]
Exit status 0 when every check passed, 1 otherwise.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

HOOK = """
<script>
window.__turasQa = { errors: [] };
window.addEventListener('error', function (e) {
  window.__turasQa.errors.push('uncaught: ' + (e.message || String(e)));
});
window.addEventListener('unhandledrejection', function (e) {
  window.__turasQa.errors.push('rejection: ' + String(e.reason));
});
(function () {
  var real = console.error;
  console.error = function () {
    window.__turasQa.errors.push('console.error: ' +
      Array.prototype.map.call(arguments, String).join(' '));
    return real.apply(console, arguments);
  };
  var warn = console.warn;
  console.warn = function () {
    window.__turasQa.errors.push('console.warn: ' +
      Array.prototype.map.call(arguments, String).join(' '));
    return warn.apply(console, arguments);
  };
})();
</script>
"""

# Runs during parsing, so it is in place before every panel's
# DOMContentLoaded handler registers its BrandSelector subscriber.
CLONE = """
<script>
(function () {
  var src = document.querySelector('.br-panel[id^="panel-cat-"]');
  if (!src) return;
  var oldId = src.id.replace(/^panel-cat-/, '');
  var newId = 'zz2';
  var html = src.outerHTML
    .split(oldId).join(newId)
    .split(oldId.toUpperCase()).join(newId.toUpperCase());
  var holder = document.createElement('div');
  holder.innerHTML = html;
  var clone = holder.firstElementChild;
  clone.classList.remove('active');
  src.parentNode.insertBefore(clone, src.nextSibling);

  var btn = document.querySelector('.br-tab-btn[data-tab="cat-' + oldId + '"]');
  if (btn) {
    var nb = btn.cloneNode(true);
    nb.setAttribute('data-tab', 'cat-' + newId);
    nb.classList.remove('active');
    nb.textContent = 'Cloned category';
    btn.parentNode.insertBefore(nb, btn.nextSibling);
  }
  window.__turasClone = { from: oldId, to: newId };
})();
</script>
"""

DRIVER = """
<script>
(function () {
  var qa = window.__turasQa;
  var out = { checks: [], errors: qa.errors };
  function check(name, ok, detail) {
    out.checks.push({ name: name, ok: !!ok, detail: detail || '' });
  }
  function sorted(s) { var a = []; s.forEach(function (c) { a.push(c); }); return a.sort(); }

  function header(group) {
    return {
      focal: document.getElementById('br-focal-select-' + group),
      trigger: document.querySelector('.br-cmp-trigger[data-group="' + group + '"]'),
      pop: document.querySelector('.br-cmp-popover[data-group="' + group + '"]'),
      text: document.querySelector('.br-cmp-text[data-group="' + group + '"]')
    };
  }

  function panelHandles(group) {
    var panel = document.getElementById('panel-cat-' + group);
    var seen = [];
    panel.querySelectorAll('.fn-panel, .ma-panel, .cb-panel, .wom-panel')
      .forEach(function (p) {
        if (p.__brChartSelector) seen.push(p.__brChartSelector);
      });
    return seen;
  }

  function run() {
    var groups = [];
    document.querySelectorAll('.br-cmp-popover[data-group]').forEach(function (p) {
      var g = p.getAttribute('data-group');
      if (groups.indexOf(g) < 0) groups.push(g);
    });
    check('two distinct categories on the page', groups.length === 2,
          groups.join(','));
    if (groups.length !== 2) { finish(); return; }

    // brApplyAllComparisonSets ran on load across both groups.
    groups.forEach(function (g) {
      var h = header(g);
      check(g + ': the header rendered its opening state',
            !!h.text && (h.text.textContent === 'Focal only' ||
                         h.text.textContent === 'All brands'),
            h.text ? h.text.textContent : 'no text');
      check(g + ': its panels registered a split-mode handle',
            panelHandles(g).length > 0, String(panelHandles(g).length));
    });

    var a = groups[0], b = groups[1];
    document.querySelectorAll('.br-tab-btn').forEach(function (t) {
      if (t.getAttribute('data-tab') === 'cat-' + a) window.switchBrandTab('cat-' + a);
    });

    // Drive category A to all brands and leave B alone.
    document.querySelector('.br-cmp-popover[data-group="' + a +
      '"] .br-cmp-mode[data-cmp-set="all"]').click();
    var aHidden = panelHandles(a).map(function (h) { return h.getHidden().size; });
    var bHidden = panelHandles(b).map(function (h) { return h.getHidden().size; });
    check(a + ': all brands empties every hidden set in its own category',
          aHidden.every(function (n) { return n === 0; }), aHidden.join(','));
    check(b + ': the other category is untouched by it',
          bHidden.every(function (n) { return n > 0; }), bHidden.join(','));
    check('the two headers disagree, which is the point',
          header(a).text.textContent !== header(b).text.textContent,
          header(a).text.textContent + ' vs ' + header(b).text.textContent);

    // Now the other way round, so neither ordering is privileged.
    document.querySelector('.br-cmp-popover[data-group="' + b +
      '"] .br-cmp-mode[data-cmp-set="all"]').click();
    check(b + ': all brands reaches the second category too',
          panelHandles(b).every(function (h) { return h.getHidden().size === 0; }),
          panelHandles(b).map(function (h) { return h.getHidden().size; }).join(','));

    // A Chart brands deviation is panel-local, so it must not cross groups.
    var mountA = document.querySelector(
      '#panel-cat-' + a + ' .br-cf[data-chartfocus]');
    var mountB = document.querySelector(
      '#panel-cat-' + b + ' .br-cf[data-chartfocus]');
    check('both categories carry Chart brands controls', !!mountA && !!mountB);
    if (mountA && mountB) {
      mountA.querySelector('.br-cf-trigger').click();
      var dropped = null;
      mountA.querySelectorAll('.br-cf-check').forEach(function (cb) {
        if (dropped || cb.disabled) return;
        dropped = cb.value;
        cb.checked = false;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
      });
      var noteA = mountA.parentElement.querySelector('.br-cf-note');
      var noteB = mountB.parentElement.querySelector('.br-cf-note');
      check(a + ': its own chart deviates', noteA && noteA.hidden === false,
            noteA ? noteA.textContent : 'no note');
      check(b + ': the other category does not', noteB && noteB.hidden === true,
            noteB ? ('hidden=' + noteB.hidden) : 'no note');

      // And a header change in the OTHER category leaves it alone, while a
      // header change in its own clears it.
      document.querySelector('.br-cmp-popover[data-group="' + b +
        '"] .br-cmp-mode[data-cmp-set="focal"]').click();
      check(a + ': a header change next door does not clear it',
            noteA.hidden === false, 'hidden=' + noteA.hidden);
      document.querySelector('.br-cmp-popover[data-group="' + a +
        '"] .br-cmp-mode[data-cmp-set="focal"]').click();
      check(a + ': its own header change does clear it',
            noteA.hidden === true, 'hidden=' + noteA.hidden);
    }

    finish();
  }

  function finish() {
    check('no console error and no uncaught exception', qa.errors.length === 0,
          qa.errors.slice(0, 8).join(' | '));
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }

  function boot() { setTimeout(function () { try { run(); } catch (e) {
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify({ checks: [{ name: 'harness ran',
      ok: false, detail: String(e && e.stack || e) }], errors: qa.errors });
    document.body.appendChild(pre);
  } }, 1500); }

  if (document.readyState === 'complete') boot();
  else window.addEventListener('load', boot);
})();
</script>
"""


def build_copy(src):
    html = open(src, encoding="utf-8").read()
    i = html.index("<head>") + len("<head>")
    html = html[:i] + HOOK + html[i:]
    j = html.rindex("</body>")
    html = html[:j] + CLONE + DRIVER + html[j:]
    fd, path = tempfile.mkstemp(suffix="_2cat.html")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    keep = "--keep" in argv
    path = build_copy(argv[1])
    if not os.path.exists(CHROME):
        print("Chrome not found at", CHROME)
        return 2
    proc = subprocess.run(
        [CHROME, "--headless", "--disable-gpu", "--no-sandbox",
         "--allow-file-access-from-files", "--virtual-time-budget=30000",
         "--dump-dom", "file://" + path],
        capture_output=True, text=True, timeout=300)
    m = re.search(r'<pre id="turas-qa-result">(.*?)</pre>', proc.stdout, re.S)
    if not m:
        print("The QA harness did not report. Chrome stderr:")
        print(proc.stderr[-2000:])
        if keep:
            print("copy kept at", path)
        return 1
    body = (m.group(1).replace("&amp;", "&").replace("&lt;", "<")
            .replace("&gt;", ">").replace("&quot;", '"'))
    res = json.loads(body)
    failed = [c for c in res["checks"] if not c["ok"]]
    for c in res["checks"]:
        print("  %s %s%s" % ("ok  " if c["ok"] else "FAIL", c["name"],
                             (" -> " + c["detail"]) if c["detail"] else ""))
    if res["errors"]:
        print("\nConsole errors and exceptions (%d):" % len(res["errors"]))
        for e in res["errors"][:20]:
            print("  " + e)
    print("\n%d checks, %d failed" % (len(res["checks"]), len(failed)))
    if not keep:
        os.unlink(path)
    else:
        print("copy kept at", path)
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
