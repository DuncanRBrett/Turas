#!/usr/bin/env python3
"""Drive a brand report's five-destination shell in headless Chrome.

There is no puppeteer or playwright in this checkout, so the report is copied,
a QA harness is injected into the copy, and Chrome renders it once with
--dump-dom. The harness runs inside the real page against the real bundled
JavaScript: it clicks every destination button, opens every Advanced drawer
and every accordion item, exercises the comparison-set control, and records
what it saw plus any console error or uncaught exception.

Usage:
    python3 drive_destinations.py REPORT.html [--keep]
Exit status 0 when every check passed, 1 otherwise.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Installed first, in <head>, so it is in place before the report's own
# bundle runs and can catch anything that bundle throws.
HOOK = """
<script>
window.__turasQa = { errors: [], log: [] };
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

DRIVER = """
<script>
(function () {
  var qa = window.__turasQa;
  var out = { checks: [], errors: qa.errors, destinations: [] };
  function check(name, ok, detail) {
    out.checks.push({ name: name, ok: !!ok, detail: detail || '' });
  }
  function visible(el) {
    if (!el) return false;
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  }

  function run() {
    var catPanels = document.querySelectorAll('.br-panel[id^="panel-cat-"]');
    check('at least one category panel', catPanels.length > 0,
          String(catPanels.length));

    catPanels.forEach(function (panel) {
      // The category tab has to be showing for offsetWidth to mean anything.
      var tab = panel.id.replace(/^panel-/, '');
      window.switchBrandTab(tab);

      var btns = panel.querySelectorAll('.br-destination-btn');
      check(tab + ': five destination buttons', btns.length === 5,
            String(btns.length));

      Array.prototype.forEach.call(btns, function (btn) {
        var id = btn.getAttribute('data-destination');
        window.switchBrandDestination(btn);

        var cont = panel.querySelector(
          '.br-destination[data-destination="' + id + '"]');
        check(tab + '/' + id + ': container exists', !!cont);
        check(tab + '/' + id + ': container is shown',
              cont && cont.classList.contains('active'));

        // Not empty: the main view has a host, or the Overview card, and the
        // rendered height is non-zero.
        var main = cont ? cont.querySelector('.br-dest-main') : null;
        var hosts = main ? main.querySelectorAll('.br-subpanel').length : 0;
        var stub = main ? main.querySelectorAll('.br-overview-stub').length : 0;
        var adv = cont ? cont.querySelectorAll('.br-adv-item').length : 0;
        check(tab + '/' + id + ': destination is not empty',
              (hosts + stub + adv) > 0,
              'hosts=' + hosts + ' stub=' + stub + ' advanced=' + adv);
        check(tab + '/' + id + ': destination has height',
              cont && cont.getBoundingClientRect().height > 0,
              cont ? String(Math.round(cont.getBoundingClientRect().height)) : 'none');

        // Advanced drawer: open it, then expand each accordion item.
        var drawer = cont ? cont.querySelector('.br-advanced') : null;
        if (drawer) {
          var toggle = drawer.querySelector('.br-advanced-toggle');
          toggle.click();
          var body = drawer.querySelector('.br-advanced-body');
          check(tab + '/' + id + ': advanced drawer opens', !body.hidden);
          var items = drawer.querySelectorAll('.br-adv-item');
          check(tab + '/' + id + ': advanced has items', items.length > 0,
                String(items.length));
          Array.prototype.forEach.call(items, function (item) {
            var it = item.querySelector('.br-adv-toggle');
            var ib = item.querySelector('.br-adv-body');
            // The accordion toggles, so an already-expanded item needs two
            // clicks to end up expanded. The first item starts expanded.
            it.click();
            if (ib.hidden) it.click();
            check(tab + '/' + id + '/' + item.getAttribute('data-leaf') +
                  ': accordion item expands', !ib.hidden);
            var open = drawer.querySelectorAll('.br-adv-body:not([hidden])');
            check(tab + '/' + id + ': one item expanded at a time',
                  open.length === 1, String(open.length));
          });
        }

        out.destinations.push({ tab: tab, id: id, hosts: hosts,
                                stub: stub, advanced: adv });
      });

      // --- comparison-set control ---
      var focalSel = panel.querySelector('.br-focal-select');
      var checks = panel.querySelectorAll('.br-cmp-check');
      check(tab + ': comparison control present', !!focalSel && checks.length > 0,
            'brands=' + checks.length);
      if (focalSel && checks.length > 2) {
        var trig = panel.querySelector('.br-cmp-trigger');
        trig.click();
        var pop = panel.querySelector('.br-cmp-popover');
        check(tab + ': comparison popover opens', pop && !pop.hidden);

        // Pick two comparators.
        var picked = [];
        Array.prototype.forEach.call(checks, function (c) {
          if (c.disabled || picked.length >= 2) return;
          c.checked = true;
          c.dispatchEvent(new Event('change', { bubbles: true }));
          picked.push(c.value);
        });
        var badge = panel.querySelector('.br-cmp-count');
        check(tab + ': comparator count shown', badge && badge.textContent === '2',
              badge ? badge.textContent : 'none');

        // The hidden set published to the shared store must exclude the
        // focal brand and the two comparators, and nothing else may be shown.
        var store = window._brandSelectorCategoryStore || {};
        var group = panel.id.replace(/^panel-cat-/, '');
        var hidden = store[group];
        if (hidden) {
          var focalHidden = hidden.has(focalSel.value);
          var compHidden = picked.some(function (p) { return hidden.has(p); });
          check(tab + ': comparison set keeps focal visible', !focalHidden);
          check(tab + ': comparison set keeps comparators visible', !compHidden);
          check(tab + ': comparison set hides the rest', hidden.size > 0,
                'hidden=' + hidden.size);
        } else {
          check(tab + ': comparison set reached the shared store', false,
                'no entry for ' + group);
        }

        // Change the focal brand and read it back off a panel.
        var other = null;
        Array.prototype.forEach.call(focalSel.options, function (o) {
          if (!other && o.value !== focalSel.value) other = o.value;
        });
        if (other) {
          var wasFocal = focalSel.value;
          focalSel.value = other;
          focalSel.dispatchEvent(new Event('change', { bubbles: true }));
          var maSel = panel.querySelector('.ma-focus-select');
          var fnSel = panel.querySelector('.fn-focus-select');
          var cbSel = panel.querySelector(
            'select.cb-focus-select[data-cb-action="focus"]');
          check(tab + ': focal reaches the Mental Availability host',
                !maSel || maSel.value === other,
                maSel ? maSel.value : 'no MA host');
          check(tab + ': focal reaches the funnel host',
                !fnSel || fnSel.value === other,
                fnSel ? fnSel.value : 'no funnel host');
          check(tab + ': focal reaches the Category Buying host',
                !cbSel || cbSel.value === other,
                cbSel ? cbSel.value : 'no cat-buying host');

          // Changing the focal brand must not promote the old focal into a
          // comparator slot the reader never picked.
          var oldBox = null;
          Array.prototype.forEach.call(checks, function (c) {
            if (c.value === wasFocal) oldBox = c;
          });
          check(tab + ': the previous focal is released, not promoted',
                oldBox && !oldBox.checked,
                oldBox ? ('checked=' + oldBox.checked) : 'no checkbox');
          // A brand promoted to focal stops being a comparator, so the
          // expected count drops by one when the new focal was picked.
          var want = String(2 - (picked.indexOf(other) >= 0 ? 1 : 0));
          check(tab + ': comparator count follows the picks, nothing added',
                badge && badge.textContent === want,
                badge ? (badge.textContent + ' want ' + want) : 'none');
        }

        var clear = panel.querySelector('.br-cmp-clear');
        if (clear) clear.click();
      }

      // --- the Overview route into the Summary tab ---
      var stubBtn = panel.querySelector('.br-overview-stub-btn');
      if (stubBtn) {
        stubBtn.click();
        var summary = document.getElementById('panel-summary');
        check(tab + ': overview route opens the Summary tab',
              summary && summary.classList.contains('active'));
        var catSel = document.querySelector('[data-brsum-cat]');
        var label = panel.querySelector('.br-overview-stub h3');
        var want = label ? label.textContent.replace(/^Overview:\s*/, '') : '';
        check(tab + ': overview route selects this category',
              catSel && catSel.value === want,
              catSel ? (catSel.value + ' vs ' + want) : 'no select');
        window.switchBrandTab(tab);
      }
    });

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
      ok: false, detail: String(e && e.stack || e) }], errors: qa.errors,
      destinations: [] });
    document.body.appendChild(pre);
  } }, 1200); }

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
    html = html[:j] + DRIVER + html[j:]
    fd, path = tempfile.mkstemp(suffix="_qa.html")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    src = argv[1]
    keep = "--keep" in argv
    path = build_copy(src)
    if not os.path.exists(CHROME):
        print("Chrome not found at", CHROME)
        return 2
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox",
           "--allow-file-access-from-files",
           "--virtual-time-budget=30000", "--dump-dom", "file://" + path]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    dom = proc.stdout
    m = re.search(r'<pre id="turas-qa-result">(.*?)</pre>', dom, re.S)
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
        mark = "ok  " if c["ok"] else "FAIL"
        print("  %s %s%s" % (mark, c["name"], (" -> " + c["detail"]) if c["detail"] else ""))
    print("\nDestinations reached: %d" % len(res["destinations"]))
    for d in res["destinations"]:
        print("  %s / %-9s hosts=%d stub=%d advanced=%d"
              % (d["tab"], d["id"], d["hosts"], d["stub"], d["advanced"]))
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
