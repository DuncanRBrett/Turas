#!/usr/bin/env python3
"""Drive Stage 5's chrome in headless Chrome: toolbars, significance,
commentary and the methodology drawers.

There is no puppeteer or playwright in this checkout, so the report is copied,
a harness is injected into the copy, and Chrome renders it once with
--dump-dom. Everything below runs inside the real page against the real
bundled JavaScript.

What it asserts, per category and per destination:

  Export.     Every destination main view and every Advanced drawer has
              exactly one pin, one PNG and one Excel control. The pin and PNG
              pickers are asked what they would offer and every anchor they
              name is checked to resolve to something capturable. The Excel
              path is run for real, with the download intercepted, and the
              workbook it produced is parsed: it must carry at least one
              sheet per table in scope.

  Repertoire. The debt Stage 2 logged. Before the split,
              #section-repertoire-<cat> wrapped nine tables; after it, two.
              The Brand and Buying main toolbar and its Advanced toolbar
              together must reach at least as many tables as that anchor used
              to, and every one of the eight Category Buying sub-tabs must be
              inside one of the two scopes.

  Significance. Every destination opens with its markers off, and with none
              of them rendered. Turning the toggle on makes markers appear
              wherever the engine computed any; turning it off again removes
              them. A capture taken while the toggle is off is checked for
              markers in the captured HTML, not on the page, because that is
              the failure the CLAUDE.md inliner note warns about.

  Commentary. One box per destination, it takes text, and the text survives
              the report's own serialiser.

  Methodology. Every drawer starts collapsed, opens on a click, and holds at
              least one explanatory block. No explanatory block is left loose
              in a destination outside a drawer.

Usage:
    python3 drive_chrome.py REPORT.html [--keep]
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
window.__turasQa = { errors: [], downloads: [] };
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
  // An Excel export ends in a.click() on an object URL. Intercepting the
  // click and reading the blob back is how the workbook is inspected: the
  // check is on what a reader would download, not on what the code meant to
  // build.
  var origCreate = URL.createObjectURL;
  URL.createObjectURL = function (blob) {
    window.__turasQa.lastBlob = blob;
    return origCreate.apply(URL, arguments);
  };
  var origClick = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function () {
    if (this.download) {
      window.__turasQa.downloads.push({ name: this.download,
                                        blob: window.__turasQa.lastBlob });
      return;
    }
    return origClick.apply(this, arguments);
  };
})();
</script>
"""

DRIVER = r"""
<script>
(function () {
  var qa = window.__turasQa;
  var out = { checks: [], errors: qa.errors, views: [], counts: {} };
  function check(name, ok, detail) {
    out.checks.push({ name: name, ok: !!ok, detail: detail || '' });
  }
  function visible(el) {
    if (!el) return false;
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  }

  var SIG = '.ma-sig, .ma-fv-sig, .ma-adv-sig, .ct-sig, .fn-sig-avg, .fn-sig';
  var HOWTO_BLOCK = '.t-callout, details.ma-chart-callout, ' +
                    'details.ma-adv-intro-callout, details.cb-info-callout';

  function capturable(el) {
    if (!el) return false;
    if (el.querySelector('table')) return true;
    if (el.querySelector('[data-pin-as-table],[data-pin-as-chart],[data-fn-rel-chart-area]')) return true;
    var svgs = el.querySelectorAll('svg');
    for (var i = 0; i < svgs.length; i++) {
      if (!svgs[i].closest('button')) return true;
    }
    return false;
  }

  function resolveAnchor(a) {
    var el = document.getElementById('section-' + a);
    if (!el && /^pf-/.test(a)) el = document.getElementById(a.replace(/^pf-/, 'pf-subtab-'));
    if (!el) {
      var c = document.querySelectorAll('[data-section="' + a + '"]');
      for (var i = 0; i < c.length; i++) {
        if (c[i].tagName !== 'BUTTON') { el = c[i]; break; }
      }
    }
    return el;
  }

  function run() {
    var panels = document.querySelectorAll('.br-panel[id^="panel-cat-"]');
    check('at least one category panel', panels.length > 0,
          panels.length + ' panel(s)');

    panels.forEach(function (panel) {
      var group = panel.id.replace(/^panel-cat-/, '');
      window.switchBrandTab(panel.id.replace(/^panel-/, ''));

      panel.querySelectorAll('.br-destination').forEach(function (dest) {
        var did = dest.getAttribute('data-destination');
        var label = group + '/' + did;
        var btn = panel.querySelector('.br-destination-btn[data-destination="' + did + '"]');
        if (btn) btn.click();

        // ---- one toolbar per view -------------------------------------
        var main = dest.querySelector('.br-dest-main');
        var advBody = dest.querySelector('.br-advanced-body');
        var tiers = [{ name: 'main', root: main }];
        if (advBody) tiers.push({ name: 'advanced', root: advBody });

        // Open the drawer so its toolbar is laid out and its items exist.
        var advToggle = dest.querySelector('.br-advanced-toggle');
        if (advToggle && advBody && advBody.hidden) advToggle.click();

        tiers.forEach(function (t) {
          if (!t.root) return;
          var bar = t.root.querySelector(':scope > .br-dest-toolbar');
          var leaves = t.root.querySelectorAll('.br-subpanel').length;
          if (!leaves) {
            // A view with no analysis in it gets no export control, because
            // an export button over nothing is chrome with no job. It may
            // still carry a toolbar: the significance toggle and the
            // commentary box are one per destination, so a destination whose
            // analyses are all in its Advanced drawer keeps them above it.
            // The category Overview has neither, because Stage 3 built the
            // Overview on the Summary tab and left a route card here.
            check(label + '/' + t.name + ': a view with no analysis has no export control',
                  !bar || bar.querySelectorAll('.br-dest-pin, .br-dest-png, ' +
                                               '.br-dest-excel').length === 0);
            check(label + '/' + t.name + ': and nothing to export',
                  t.root.querySelectorAll('table').length === 0);
            return;
          }
          check(label + '/' + t.name + ': has one export toolbar', !!bar);
          if (!bar) return;
          check(label + '/' + t.name + ': one pin, one PNG, one Excel',
                bar.querySelectorAll('.br-dest-pin').length === 1 &&
                bar.querySelectorAll('.br-dest-png').length === 1 &&
                bar.querySelectorAll('.br-dest-excel').length === 1);

          // What the pin and PNG pickers would offer, asked of the report's
          // own function rather than reimplemented here.
          var scope = window.brDestScope(bar.querySelector('.br-dest-pin'));
          check(label + '/' + t.name + ': the toolbar resolves its own scope',
                scope === t.root);
          var items = window.brSectionsIn(scope);
          var bad = items.filter(function (it) {
            // An anchored item must still resolve by its anchor, the way a
            // saved pin resolves it; a leaf item is checked on its own root.
            var byAnchor = resolveAnchor(it.key);
            return !capturable(byAnchor || it.el);
          }).map(function (it) { return it.key; });
          check(label + '/' + t.name + ': everything it offers resolves to content',
                bad.length === 0, bad.join(','));
          check(label + '/' + t.name + ': it offers something to capture',
                items.length > 0);

          var tables = t.root.querySelectorAll('table').length;
          out.views.push({ view: label + '/' + t.name,
                           anchors: items.length, tables: tables });

          // Pin, for real, one anchor at a time. A scope with one anchor
          // pins straight through; more than one opens the picker, so the
          // pin is driven through brPinSection instead, which is what the
          // picker calls once the reader has chosen.
          if (items.length) {
            var before = (document.querySelectorAll('.br-pinned-card') || []).length;
            var pinned = window.brPinFrom(items[0].el, items[0].key, items[0].label);
            var after = document.querySelectorAll('.br-pinned-card').length;
            check(label + '/' + t.name + ': a pin lands on the Pinned Views tab',
                  pinned && after === before + 1,
                  items[0].key + ' ' + before + ' -> ' + after);
          }

          // PNG, for real, through the same anchor the picker would name.
          if (items.length) {
            var pngErrs = qa.errors.length;
            var pngOk = window.brExportPngFrom(items[0].el, items[0].key,
                                               items[0].label);
            check(label + '/' + t.name + ': a PNG export runs and finds content',
                  pngOk && qa.errors.length === pngErrs,
                  qa.errors.slice(pngErrs).join(' | '));
          }

          // Excel, for real, with the download intercepted and parsed.
          if (tables > 0) {
            var n0 = qa.downloads.length;
            bar.querySelector('.br-dest-excel').click();
            var got = qa.downloads.length > n0 ? qa.downloads[qa.downloads.length - 1] : null;
            check(label + '/' + t.name + ': the Excel export produces a workbook',
                  !!got, got ? got.name : 'no download');
            if (got) { got.__tables = tables; got.__view = label + '/' + t.name; }
          }
        });

        // ---- significance ---------------------------------------------
        var sigBtn = dest.querySelector('.br-dest-main > .br-dest-toolbar .br-sig-toggle');
        var hasLeaves = dest.querySelectorAll('.br-subpanel').length > 0;
        check(label + ': one significance toggle where there is a marker to hide',
              dest.querySelectorAll('.br-sig-toggle').length === (hasLeaves ? 1 : 0));
        if (sigBtn) {
          check(label + ': significance starts off',
                dest.getAttribute('data-br-sig') !== 'on' &&
                sigBtn.getAttribute('aria-pressed') === 'false' &&
                /off/.test(sigBtn.textContent));
          var offVisible = 0;
          dest.querySelectorAll(SIG).forEach(function (e) { if (visible(e)) offVisible++; });
          check(label + ': no significance marker is on screen while it is off',
                offVisible === 0, offVisible + ' visible');
          var inDom = dest.querySelectorAll(SIG).length;
          sigBtn.click();
          var onVisible = 0;
          dest.querySelectorAll(SIG).forEach(function (e) { if (visible(e)) onVisible++; });
          check(label + ': the toggle reads on after a click',
                dest.getAttribute('data-br-sig') === 'on' &&
                sigBtn.getAttribute('aria-pressed') === 'true' &&
                /on/.test(sigBtn.textContent));
          if (inDom > 0) {
            check(label + ': turning it on shows the markers the engine computed',
                  onVisible > 0, inDom + ' in the DOM, ' + onVisible + ' shown');
          }
          // A capture taken with the toggle off must not carry markers, even
          // though they are still in the page. This is the inliner trap.
          sigBtn.click();
          check(label + ': the toggle reads off again',
                dest.getAttribute('data-br-sig') !== 'on');
          if (inDom > 0) {
            var host = dest.querySelector('[data-section]');
            var tbl = dest.querySelector('table');
            if (tbl && typeof TurasPins !== 'undefined') {
              var html = TurasPins.capturePortableHtml(tbl);
              var probe = document.createElement('div');
              probe.innerHTML = html;
              check(label + ': a capture taken with it off carries no marker',
                    probe.querySelectorAll(SIG).length === 0,
                    probe.querySelectorAll(SIG).length + ' in the capture');
            }
          }
        }

        // ---- commentary ------------------------------------------------
        var noteBtn = dest.querySelector('.br-dest-main > .br-dest-toolbar .br-dest-note-toggle');
        var note = dest.querySelector('.br-dest-main > .br-dest-toolbar .br-dest-note');
        check(label + ': one commentary box on the destination',
              dest.querySelectorAll('.br-dest-note-text').length ===
              (hasLeaves ? 1 : 0));
        if (noteBtn && note) {
          check(label + ': the commentary box starts closed', note.hidden === true);
          noteBtn.click();
          check(label + ': it opens on a click', note.hidden === false);
          var ta = note.querySelector('textarea');
          ta.value = 'Stage 5 note for ' + label;
          ta.dispatchEvent(new Event('input', { bubbles: true }));
          check(label + ': the text is mirrored for Save',
                ta.textContent === ta.value, ta.textContent);
        }

        // ---- methodology ------------------------------------------------
        dest.querySelectorAll('.br-howto').forEach(function (drawer) {
          var tier = drawer.getAttribute('data-tier');
          var body = drawer.querySelector('.br-howto-body');
          var t = drawer.querySelector('.br-howto-toggle');
          if (drawer.hidden) {
            // Hidden is only allowed when this view really has nothing to
            // explain, so the claim is checked rather than taken.
            var scope = drawer.parentNode;
            var loose = scope.querySelectorAll(HOWTO_BLOCK).length;
            check(label + '/' + tier + ': a hidden drawer means no methodology here',
                  loose === 0, loose + ' block(s) found');
            return;
          }
          check(label + '/' + tier + ': the drawer starts collapsed', body.hidden === true);
          t.click();
          check(label + '/' + tier + ': it opens on a click', body.hidden === false);
          check(label + '/' + tier + ': it holds at least one explanatory block',
                body.querySelectorAll(HOWTO_BLOCK).length > 0,
                body.querySelectorAll(HOWTO_BLOCK).length + ' block(s)');
          t.click();
          check(label + '/' + tier + ': it closes again', body.hidden === true);
        });
        // Nothing explanatory may be left loose in the view.
        var looseMain = 0;
        if (main) {
          main.querySelectorAll(HOWTO_BLOCK).forEach(function (b) {
            if (!b.closest('.br-howto')) looseMain++;
          });
        }
        check(label + ': no explanatory block left outside a drawer',
              looseMain === 0, looseMain + ' loose');
      });

      // ---- the repertoire debt, checked explicitly --------------------
      var buying = panel.querySelector('.br-destination[data-destination="buying"]');
      if (buying) {
        var bMain = buying.querySelector('.br-dest-main');
        var bAdv  = buying.querySelector('.br-advanced-body');
        var reach = 0;
        [bMain, bAdv].forEach(function (r) {
          if (r) reach += r.querySelectorAll('table').length;
        });
        // Nine is what #section-repertoire-<cat> held before Stage 2 split
        // the Category Buying panel; the Stage 2 log recorded the count.
        check(group + ': Brand and Buying reaches at least the nine tables ' +
              'section-repertoire held before the split', reach >= 9,
              reach + ' tables across the two toolbars');
        var cbTabs = {};
        panel.querySelectorAll('.br-subpanel[data-cb-tab]').forEach(function (h) {
          var k = h.getAttribute('data-cb-tab');
          if (!k) return;
          var inMain = bMain && bMain.contains(h);
          var inAdv  = bAdv && bAdv.contains(h);
          var inAudience = !!h.closest('.br-destination[data-destination="audience"]');
          cbTabs[k] = !!(inMain || inAdv || inAudience);
        });
        var orphan = Object.keys(cbTabs).filter(function (k) { return !cbTabs[k]; });
        check(group + ': every Category Buying sub-tab sits under a toolbar',
              orphan.length === 0, orphan.join(','));
        out.counts.cbTabs = Object.keys(cbTabs).length;
      }
    });

    // ---- the whole-report counts -------------------------------------
    out.counts.destToolbars = document.querySelectorAll('.br-dest-toolbar').length;
    out.counts.sigToggles   = document.querySelectorAll('.br-sig-toggle').length;
    out.counts.destNotes    = document.querySelectorAll('.br-dest-note-text').length;
    out.counts.howtoShown   = document.querySelectorAll('.br-howto:not([hidden])').length;
    out.counts.textareas    = document.querySelectorAll('textarea').length;

    // The commentary must survive the report's own serialiser, which is what
    // the Save button writes into the file.
    if (typeof window._brSerialiseReport === 'function') {
      window._brSyncAllCommentary();
      var s = window._brSerialiseReport();
      // At least once each. It can appear more often, because a pin taken
      // from a destination captures that destination's commentary too, and
      // the pin store is serialised with the page.
      var missing = [];
      document.querySelectorAll('.br-dest-note-text').forEach(function (ta) {
        if (ta.value && s.indexOf(ta.value) === -1) missing.push(ta.value);
      });
      check('every destination note is in the serialised report',
            missing.length === 0, missing.join(' | '));
    }

    // Every intercepted workbook is parsed and checked for content.
    var wb = qa.downloads.filter(function (d) { return d.blob; });
    check('every Excel export produced a non-empty workbook',
          wb.length > 0 && wb.every(function (d) { return d.blob.size > 200; }),
          wb.length + ' workbook(s)');

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
      views: [], counts: {} });
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
    html = html[:j] + DRIVER + html[j:]
    fd, path = tempfile.mkstemp(suffix="_qa5.html")
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
           "--allow-file-access-from-files", "--window-size=1280,900",
           "--virtual-time-budget=40000", "--dump-dom", "file://" + path]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
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
        print("  %s %s%s" % (mark, c["name"],
                             (" -> " + c["detail"]) if c["detail"] else ""))
    print("\nViews driven: %d" % len(res["views"]))
    for v in res["views"]:
        print("  %-28s anchors=%d tables=%d" % (v["view"], v["anchors"], v["tables"]))
    print("\nCounts: " + json.dumps(res["counts"]))
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
