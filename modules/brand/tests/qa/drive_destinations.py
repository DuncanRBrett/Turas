#!/usr/bin/env python3
"""Drive a brand report's five-destination shell in headless Chrome.

There is no puppeteer or playwright in this checkout, so the report is copied,
a QA harness is injected into the copy, and Chrome renders it once with
--dump-dom. The harness runs inside the real page against the real bundled
JavaScript: it clicks every destination button, opens every Advanced drawer
and every accordion item, drives the header brand control through its three
states, and records what it saw plus any console error or uncaught exception.

The brand checks assert identity, not counts. For every host it reads which
brand codes are on screen and compares them with the set the header names,
because a count is what let two disagreeing brand filters ship. It also
asserts that exactly one focal control and one brand-set control are
visible in a category, and that no per-panel copy of either has a box on
screen while both still exist in the DOM for the header to drive.

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

  // --- the single-brand-control rule ---
  // Duncan opened a Stage 2 report and saw FOCAL BRAND twice and two brand
  // filters whose counts disagreed. Counting alone is what let that ship, so
  // these checks assert identity: which brand codes are on screen, not how
  // many. Every element that carries a brand code is swept, so a table with
  // brands as rows and a matrix with brands as columns are both covered.
  var BRAND_ATTRS = ['data-brand', 'data-cb-brand', 'data-fn-brand',
                     'data-ma-brand', 'data-demo-brand', 'data-wom-brand'];

  // Hosts with no brand-coded element to sweep. cb-context is category
  // level and has no brand dimension at all. The Mental Advantage matrix
  // keys its columns by stimulus, not by brand code, so it is checked on
  // its visible column count instead: one label column plus one per brand.
  var NO_BRAND_CODES = { 'cb-context': 'none', 'ma-advantage': 'columns' };

  // Views that cover the whole category whatever the comparison set is,
  // and say so in their own caption.
  var WHOLE_CATEGORY = { 'cb-norms': 1, 'cb-dop': 1, 'cb-shopper': 1 };

  function visibleBrandCodes(host) {
    var seen = {};
    BRAND_ATTRS.forEach(function (a) {
      host.querySelectorAll('[' + a + ']').forEach(function (el) {
        if (el.closest('.br-cmp-popover')) return;
        var v = el.getAttribute(a);
        if (!v || v === '__avg__') return;
        if (!visible(el)) return;
        seen[v] = true;
      });
    });
    return Object.keys(seen).sort();
  }

  function visibleHeadCells(host) {
    var hdr = host.querySelector('thead tr');
    if (!hdr) return 0;
    var n = 0;
    Array.prototype.forEach.call(hdr.children, function (c) {
      if (visible(c)) n++;
    });
    return n;
  }

  // Lay a host out so what it shows can be measured: activate its
  // destination, and expand its accordion item when it sits in one.
  function exposeHost(panel, host) {
    var dest = host.closest('.br-destination');
    if (dest) {
      var b = panel.querySelector('.br-destination-btn[data-destination="' +
                                  dest.getAttribute('data-destination') + '"]');
      if (b) window.switchBrandDestination(b);
    }
    var item = host.closest('.br-adv-item');
    if (item) {
      var drawerBtn = item.closest('.br-advanced')
        .querySelector('.br-advanced-toggle');
      if (drawerBtn.getAttribute('aria-expanded') !== 'true') drawerBtn.click();
      var it = item.querySelector('.br-adv-toggle');
      if (it && it.tagName === 'BUTTON' &&
          it.getAttribute('aria-expanded') !== 'true') it.click();
    }
  }

  function sameSet(a, b) {
    if (a.length !== b.length) return false;
    for (var i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
    return true;
  }

  function checkBrandSet(panel, tab, stateName, want, allBrands) {
    var wantSorted = want.slice().sort();
    panel.querySelectorAll('.br-subpanel').forEach(function (host) {
      var leaf = host.getAttribute('data-leaf');
      exposeHost(panel, host);
      var kind = NO_BRAND_CODES[leaf];
      var expect = WHOLE_CATEGORY[leaf] ? allBrands.slice().sort() : wantSorted;
      if (kind === 'none') return;
      if (kind === 'columns') {
        var vc = visibleHeadCells(host);
        check(tab + '/' + stateName + '/' + leaf + ': one column per brand shown',
              vc === expect.length + 1, vc + ' columns for ' +
              expect.length + ' brands');
        return;
      }
      var got = visibleBrandCodes(host);
      check(tab + '/' + stateName + '/' + leaf + ': shows exactly the chosen brands',
            sameSet(got, expect), got.join(',') + ' want ' + expect.join(','));
    });
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
          var wasOpen = toggle.getAttribute('aria-expanded') === 'true';
          if (!wasOpen) toggle.click();
          var body = drawer.querySelector('.br-advanced-body');
          check(tab + '/' + id + ': advanced drawer opens', !body.hidden);
          var items = drawer.querySelectorAll('.br-adv-item');
          check(tab + '/' + id + ': advanced has items', items.length > 0,
                String(items.length));
          var single = items.length === 1;
          if (single) {
            // One analysis needs one disclosure. The drawer is the
            // disclosure; the item is a heading over its content.
            var only = items[0];
            check(tab + '/' + id + ': a single item has one level of disclosure',
                  only.classList.contains('br-adv-item-single') &&
                  !!only.querySelector('.br-adv-static') &&
                  !only.querySelector('.br-adv-body').hidden);
          } else if (!wasOpen) {
            // A drawer that started closed opens on its list of titles, so
            // the reader can see what is in there before opening one.
            check(tab + '/' + id + ': the drawer opens on its list of titles',
                  drawer.querySelectorAll('.br-adv-body:not([hidden])').length === 0,
                  String(drawer.querySelectorAll('.br-adv-body:not([hidden])').length));
          }
          if (!single) {
            Array.prototype.forEach.call(items, function (item) {
              var it = item.querySelector('.br-adv-toggle');
              var ib = item.querySelector('.br-adv-body');
              // A drawer that starts open starts on its first item, so that
              // one is already expanded and the first click closes it. Only
              // a collapsed item is being asked to expand.
              var startedOpen = !ib.hidden;
              it.click();
              if (startedOpen) it.click();
              check(tab + '/' + id + '/' + item.getAttribute('data-leaf') +
                    ': one click expands the item', !ib.hidden);
              var open = drawer.querySelectorAll('.br-adv-body:not([hidden])');
              check(tab + '/' + id + ': one item expanded at a time',
                    open.length === 1, String(open.length));
            });
          }
        }

        out.destinations.push({ tab: tab, id: id, hosts: hosts,
                                stub: stub, advanced: adv });
      });

      // --- one brand control per category, and it tells the truth ---
      var focalSel = panel.querySelector('.br-focal-select');
      var trigger  = panel.querySelector('.br-cmp-trigger');
      var checks   = panel.querySelectorAll('.br-cmp-check');
      check(tab + ': one focal control on screen',
            panel.querySelectorAll('.br-focal-select').length === 1 &&
            !!focalSel && visible(focalSel));
      check(tab + ': one brand-set control on screen',
            panel.querySelectorAll('.br-cmp-trigger').length === 1 &&
            !!trigger && visible(trigger));

      // Every panel keeps its own copy, driven by the header, and none of
      // them has a box on screen. A rule scoped under .br-destination would
      // pass a count check and still show through in a pin, so this asserts
      // the rendered geometry.
      var panelFocal = panel.querySelectorAll(
        '.fn-focus-select,.ma-focus-select,.cb-focus-select,' +
        '.wom-focus-select,.demo-focal-select');
      var shownFocal = 0;
      panelFocal.forEach(function (e) { if (visible(e)) shownFocal++; });
      check(tab + ': no second focal control is visible',
            shownFocal === 0, shownFocal + ' of ' + panelFocal.length + ' shown');
      var panelFilter = panel.querySelectorAll('.bs-trigger');
      var shownFilter = 0;
      panelFilter.forEach(function (e) { if (visible(e)) shownFilter++; });
      check(tab + ': no second brand filter is visible',
            shownFilter === 0, shownFilter + ' of ' + panelFilter.length + ' shown');
      check(tab + ': the panels still carry their own controls to drive',
            panelFocal.length > 0 && panelFilter.length > 0,
            panelFocal.length + ' focal, ' + panelFilter.length + ' filter');

      if (focalSel && checks.length > 2) {
        var allBrands = [];
        Array.prototype.forEach.call(checks, function (c) { allBrands.push(c.value); });
        var textEl = panel.querySelector('.br-cmp-text');
        var badge = panel.querySelector('.br-cmp-count');
        var focal = focalSel.value;

        // State one, as the report opens.
        check(tab + ': opens on the state its config asked for',
              textEl.textContent === 'Focal only' ||
              textEl.textContent === 'All brands', textEl.textContent);
        if (textEl.textContent === 'Focal only') {
          check(tab + ': the count badge is not shown with no comparators',
                badge.hidden === true);
          checkBrandSet(panel, tab, 'focal only', [focal], allBrands);
        }

        // State two: pick three comparators.
        trigger.click();
        var pop = panel.querySelector('.br-cmp-popover');
        check(tab + ': comparison popover opens', pop && !pop.hidden);
        var picked = [];
        Array.prototype.forEach.call(checks, function (c) {
          if (c.disabled || picked.length >= 3) return;
          c.checked = true;
          c.dispatchEvent(new Event('change', { bubbles: true }));
          picked.push(c.value);
        });
        check(tab + ': the trigger names the comparison state',
              textEl.textContent === 'Compare with', textEl.textContent);
        check(tab + ': the count follows the picks',
              badge.textContent === '3' && !badge.hidden, badge.textContent);
        checkBrandSet(panel, tab, 'compare with 3', [focal].concat(picked), allBrands);

        // State three: all brands.
        panel.querySelector('.br-cmp-mode[data-cmp-set="all"]').click();
        check(tab + ': the trigger names the all-brands state',
              textEl.textContent === 'All brands', textEl.textContent);
        check(tab + ': the count badge is not shown in the all-brands state',
              badge.hidden === true);
        checkBrandSet(panel, tab, 'all brands', allBrands, allBrands);

        // Back to state one, by name rather than by clearing.
        panel.querySelector('.br-cmp-mode[data-cmp-set="focal"]').click();
        check(tab + ': the trigger returns to the focal-only state',
              textEl.textContent === 'Focal only', textEl.textContent);
        checkBrandSet(panel, tab, 'focal only again', [focal], allBrands);

        // The focal brand reaches every panel, and changing it releases the
        // brand that was focal rather than spending a comparator slot.
        trigger.click();
        var first = null;
        Array.prototype.forEach.call(checks, function (c) {
          if (!first && !c.disabled) { first = c; }
        });
        first.checked = true;
        first.dispatchEvent(new Event('change', { bubbles: true }));
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
          var womSel = panel.querySelector('.wom-focus-select');
          var demoSel = panel.querySelector('.demo-focal-select');
          check(tab + ': focal reaches the Mental Availability host',
                !maSel || maSel.value === other, maSel ? maSel.value : 'no MA host');
          check(tab + ': focal reaches the funnel host',
                !fnSel || fnSel.value === other, fnSel ? fnSel.value : 'no funnel host');
          check(tab + ': focal reaches the Category Buying host',
                !cbSel || cbSel.value === other, cbSel ? cbSel.value : 'no cat-buying host');
          check(tab + ': focal reaches the Word of Mouth host',
                !womSel || womSel.value === other, womSel ? womSel.value : 'no WOM host');
          check(tab + ': focal reaches the Demographics host',
                !demoSel || demoSel.value === other, demoSel ? demoSel.value : 'no demo host');
          var oldBox = null;
          Array.prototype.forEach.call(checks, function (c) {
            if (c.value === wasFocal) oldBox = c;
          });
          check(tab + ': the previous focal is released, not promoted',
                oldBox && !oldBox.checked,
                oldBox ? ('checked=' + oldBox.checked) : 'no checkbox');
        }
        panel.querySelector('.br-cmp-mode[data-cmp-set="focal"]').click();
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
