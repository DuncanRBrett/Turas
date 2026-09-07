#!/usr/bin/env python3
"""Drive every Excel export button in a brand report, in headless Chrome.

The workbook builder in brand_report.js reads the rendered table, so the only
honest test of it is the rendered table. The node test beside it drives the
same function against a stub DOM, which can only assert what the stub was
built to say. This script runs the real bundle against the real report: it
clicks every destination's Excel button and every Advanced drawer's, captures
the workbook the click would have downloaded, and checks it against the cells
that were on screen when it was taken.

What it asserts, for each scope:

  * a category-average figure with a range rail beneath it is written as the
    figure, never as the figure and the two bounds run together. That is the
    615172 defect, found on 7 September 2026 by opening an exported workbook
    in LibreOffice: 61% with a 51 to 72 rail became the number 615172;
  * both bounds reach the workbook, in cells of their own;
  * a label stays a label. Every visible label-column cell is present as a
    String, so "5 Roses" is not the number 5 and "1/9" is not 1;
  * a row the reader's brand filter has hidden is not in the file, and the
    brands that are on screen all are;
  * every worksheet is well-formed XML that a spreadsheet program can parse.

It also records what it does not assert: how many tables each scope exported,
and how many computed styles the builder reads to decide what is visible,
which is the cost that grows with the size of a destination. Time is not
reported. Headless Chrome runs this under a virtual clock that does not
advance during synchronous script, so any figure would be a made-up zero.

Usage:
    python3 drive_excel_export.py REPORT.html [--keep] [--xml-dir DIR]

--xml-dir writes each captured workbook out as SpreadsheetML, which is what
you then open in LibreOffice. Exit status 0 when every check passed.
"""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

HOOK = """
<script>
window.__turasQa = { errors: [], blobs: [] };
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
})();
// The export ends in a Blob and an anchor click. Record the one and stop the
// other, so the real button is pressed and nothing is downloaded.
(function () {
  var RealBlob = window.Blob;
  window.Blob = function (parts, opts) {
    try {
      if (opts && String(opts.type || '').indexOf('excel') !== -1) {
        window.__turasQa.blobs.push(Array.prototype.join.call(parts, ''));
      }
    } catch (err) { window.__turasQa.errors.push('blob capture: ' + err); }
    return new RealBlob(parts, opts);
  };
  window.Blob.prototype = RealBlob.prototype;
  // An export with nothing to take calls alert(), and a native dialog stops
  // headless Chrome dead. Recorded and dismissed, so a button that refuses is
  // a reported failure rather than a hung run.
  window.alert = function (msg) {
    window.__turasQa.errors.push('alert: ' + String(msg));
  };
  var realClick = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function () {
    if (this.hasAttribute('download')) return;
    return realClick.apply(this, arguments);
  };
})();
</script>
"""

DRIVER = """
<script>
(function () {
  var qa = window.__turasQa;
  var out = { checks: [], errors: qa.errors, scopes: [], xml: [] };
  function check(name, ok, detail) {
    out.checks.push({ name: name, ok: !!ok, detail: detail == null ? '' : String(detail) });
  }

  // ---------------------------------------------------------------- reading
  // A worksheet, as arrays of typed cells. Deliberately a second reader,
  // written from the file format rather than from the builder, so a builder
  // that writes nonsense cannot also make this agree with it.
  function sheetsOf(xml) {
    return xml.split('<Worksheet ').slice(1).map(function (chunk) {
      var nm = /^ss:Name="([^"]*)"/.exec(chunk);
      var rows = chunk.split('<Row>').slice(1).map(function (r) {
        var cells = [], re = /<Cell><Data ss:Type="([^"]+)">([\\s\\S]*?)<\\/Data><\\/Cell>/g, m;
        while ((m = re.exec(r)) !== null) {
          cells.push({ type: m[1],
                       value: m[2].replace(/&lt;/g, '<').replace(/&gt;/g, '>')
                                  .replace(/&amp;/g, '&') });
        }
        return cells;
      });
      return { name: nm ? nm[1] : '', rows: rows };
    });
  }
  function everyCell(sheets) {
    var all = [];
    sheets.forEach(function (s) {
      s.rows.forEach(function (r) { r.forEach(function (c) { all.push(c); }); });
    });
    return all;
  }
  function digits(s) { return String(s).replace(/[^0-9]/g, ''); }
  // A brand name reaches the workbook XML-escaped. "Cape Herb & Spice" is
  // written "Cape Herb &amp; Spice", so a raw search for it finds nothing and
  // would report a leak as clean, or a present row as missing.
  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;');
  }
  function shown(el) {
    if (!el) return false;
    var cs = getComputedStyle(el);
    return cs.display !== 'none' && cs.visibility !== 'hidden';
  }
  // Visible on screen AND in a visible row, which is the pair the workbook
  // is supposed to agree with.
  function liveCells(scope, sel) {
    return Array.prototype.filter.call(scope.querySelectorAll(sel), function (td) {
      if (!shown(td)) return false;
      var tr = td.closest('tr');
      return !tr || shown(tr);
    });
  }

  // --------------------------------------------------------------- the DOM
  // The tables a scope's Excel button will take, resolved the way
  // _brExportRoot resolves them.
  function tablesIn(root) {
    var t = root.querySelectorAll('table.br-table');
    if (t.length === 0) t = root.querySelectorAll('table');
    return t;
  }

  function railOf(td) {
    var lim = td.querySelector('.ma-ci-limits');
    if (!lim || !shown(lim)) return null;
    var sp = lim.querySelectorAll('span');
    if (sp.length < 2) return null;
    return { lo: sp[0].textContent.trim(), hi: sp[1].textContent.trim() };
  }
  function figureOf(td) {
    var v = td.querySelector('.ct-val');
    if (v) return v.textContent.trim();
    var clone = td.cloneNode(true);
    clone.querySelectorAll('.ma-ci-bar-wrap, .ma-ci-limits').forEach(function (e) {
      e.remove();
    });
    return clone.textContent.trim();
  }

  // ------------------------------------------------------------- the checks
  function analyse(name, scope, xml) {
    var sheets = sheetsOf(xml);
    var cells = everyCell(sheets);
    var vals = {}, strVals = {};
    cells.forEach(function (c) {
      vals[c.value] = true;
      if (c.type === 'String') strVals[c.value] = true;
    });

    // Well-formed enough to open: one Worksheet per exported table, every
    // Row closed, no stray ampersand outside an entity.
    var nTables = tablesIn(scope).length;
    check(name + ': one worksheet per table', sheets.length === nTables,
          sheets.length + ' worksheets for ' + nTables + ' tables');
    var body = xml.replace(/&(amp|lt|gt);/g, '');
    check(name + ': no unescaped ampersand', body.indexOf('&') === -1);

    // 1. The 615172 defect. Every visible cell with a range rail beneath it.
    var railed = liveCells(scope, 'td').filter(function (td) {
      return !!railOf(td);
    });
    railed.forEach(function (td, i) {
      var r = railOf(td), f = figureOf(td);
      var run = digits(f) + digits(r.lo) + digits(r.hi);
      if (run.length >= 4) {
        check(name + ': rail cell ' + i + ' is not run together with its bounds',
              !vals[run], 'looked for the cell value ' + run +
              ' from ' + f + ' ' + r.lo + ' ' + r.hi);
      }
      check(name + ': rail cell ' + i + ' figure ' + f + ' reached the workbook',
            vals[String(parseFloat(digits(f) === '' ? 'x' :
                 f.replace(/[%,\\s]/g, '')))] === true, 'figure ' + f);
      check(name + ': rail cell ' + i + ' bounds reached the workbook',
            vals[String(parseFloat(r.lo.replace(/[%,\\s]/g, '')))] === true &&
            vals[String(parseFloat(r.hi.replace(/[%,\\s]/g, '')))] === true,
            r.lo + ' to ' + r.hi);
    });
    // What the visibility test costs. Headless Chrome runs this driver under
    // a virtual clock that does not advance during synchronous script, so a
    // wall-clock reading here would be a fabricated zero. Counting the calls
    // the builder makes to getComputedStyle measures the same thing without
    // a clock: it is the one operation the walk performs per node.
    var calls = 0;
    if (typeof window._brTablesToWorkbook === 'function') {
      var realCS = window.getComputedStyle;
      window.getComputedStyle = function () {
        calls += 1;
        return realCS.apply(window, arguments);
      };
      try { window._brTablesToWorkbook(tablesIn(scope), 'timing'); }
      finally { window.getComputedStyle = realCS; }
    }
    out.scopes.push({ name: name, tables: nTables, sheets: sheets.length,
                      railed: railed.length, bytes: xml.length,
                      styleCalls: calls });
    if (calls > (out.mostStyleCalls || 0)) out.mostStyleCalls = calls;

    // 2. Labels stay labels. A label column cell whose text is not wholly a
    // number must be in the workbook as a String carrying that text.
    //
    // A FOCAL badge is a pill the page draws beside the brand name, so the
    // workbook may carry it as a separate word or leave it out. Both are
    // labels; neither is a number. The check accepts either and nothing else.
    var labels = liveCells(scope, 'td.ct-label-col, td.cb-label-col, td.fn-label-col');
    var badLabel = null, nLabels = 0;
    labels.forEach(function (td) {
      var clone = td.cloneNode(true);
      var badges = [];
      clone.querySelectorAll('.ma-focal-badge, .fn-focal-badge, .cb-focal-badge, ' +
                             '.cb-dop-pc-focal-badge').forEach(function (b) {
        badges.push(b.textContent.trim());
        b.remove();
      });
      clone.querySelectorAll('.ma-ci-bar-wrap, .ma-ci-limits, button, input')
           .forEach(function (e) { e.remove(); });
      var t = clone.textContent.replace(/\\s+/g, ' ').trim();
      if (!t || /^[+-]?[0-9.,]+%?$/.test(t)) return;
      nLabels += 1;
      var want = [t];
      if (badges.length) want.push((t + ' ' + badges.join(' ')).trim());
      var ok = want.some(function (w) { return !!strVals[w]; });
      if (!ok && badLabel === null) badLabel = want.join(' | ');
    });
    if (nLabels) {
      check(name + ': every label reached the workbook as a label (' +
            nLabels + ')', badLabel === null, badLabel);
    }
  }

  // ------------------------------------------------------------- the drive
  function expandDrawers(scope) {
    document.querySelectorAll('.br-advanced-toggle').forEach(function (b) {
      if (b.getAttribute('aria-expanded') !== 'true') b.click();
    });
    document.querySelectorAll('.br-adv-toggle').forEach(function (b) {
      if (b.tagName === 'BUTTON' && b.getAttribute('aria-expanded') !== 'true') {
        b.click();
      }
    });
  }

  function pressExcel(btn) {
    var before = qa.blobs.length;
    var t0 = (performance && performance.now) ? performance.now() : 0;
    btn.click();
    var t1 = (performance && performance.now) ? performance.now() : 0;
    if (qa.blobs.length === before) return null;
    return { xml: qa.blobs[qa.blobs.length - 1], ms: t1 - t0 };
  }

  function boot() { setTimeout(function () {
    try {
      // Every category tab, so the whole report is exercised, not the one
      // that happens to open first.
      var catBtns = document.querySelectorAll('.br-cat-btn, [data-cat-tab]');
      var groups = {};
      document.querySelectorAll('.br-dest-excel').forEach(function (b) {
        groups[b.getAttribute('data-group')] = true;
      });
      expandDrawers();

      Object.keys(groups).forEach(function (g) {
        document.querySelectorAll(
          '.br-dest-excel[data-group="' + g + '"]').forEach(function (btn) {
          var d = btn.getAttribute('data-destination');
          var tier = btn.getAttribute('data-tier') || 'main';
          var navBtn = document.querySelector(
            '.br-destination-btn[data-group="' + g + '"][data-destination="' + d + '"]');
          if (navBtn && typeof window.switchBrandDestination === 'function') {
            window.switchBrandDestination(navBtn);
          }
          expandDrawers();
          var scope = window.brDestScope(btn);
          if (!scope) return;
          if (tablesIn(scope).length === 0) return;
          var got = pressExcel(btn);
          var name = g + '/' + d + '/' + tier;
          if (!got) { check(name + ': the Excel button produced a workbook', false); return; }
          analyse(name, scope, got.xml);
          if (out.xml.length < 20) {
            out.xml.push({ name: name, b64: btoa(unescape(encodeURIComponent(got.xml))) });
          }
        });
      });

      // The section buttons, which are the other entry point. _brExportPanel
      // takes an anchor rather than a destination scope, and the five that
      // survive Stage 5 are the four Portfolio sub-tabs and Category Buying's
      // repertoire table. The Portfolio tab sits outside the destination
      // shell, so the sweep above never reaches it, and the portfolio
      // footprint is where the "1/9" that parseFloat read as 1 lives.
      // Resolved the way _brExportPanel resolves it: several elements carry
      // the same data-section, and the one holding a table is the panel.
      function panelScope(id) {
        var seen = [], best = null;
        function offer(el) {
          if (!el || seen.indexOf(el) !== -1) return;
          seen.push(el);
          if (!best) best = el;
        }
        offer(document.getElementById('section-' + id));
        if (/^pf-/.test(id)) {
          offer(document.getElementById(id.replace(/^pf-/, 'pf-subtab-')));
        }
        document.querySelectorAll('[data-section="' + id + '"]').forEach(offer);
        for (var i = 0; i < seen.length; i++) {
          if (seen[i].querySelector && seen[i].querySelector('table')) return seen[i];
        }
        return best;
      }
      // The Portfolio panel builds each sub-tab's table when the sub-tab is
      // first shown, so every one is clicked before its button is pressed.
      // Without this the four portfolio scopes hold no table and the sweep
      // would pass by exporting nothing.
      document.querySelectorAll('.pf-sub-btn').forEach(function (b) {
        b.click();
      });
      var seenPanel = {};
      document.querySelectorAll('[onclick*="_brExportPanel"]').forEach(
        function (btn) {
          var m = /_brExportPanel\(['"]([^'"]+)['"]\)/.exec(
            btn.getAttribute('onclick') || '');
          if (!m || seenPanel[m[1]]) return;
          seenPanel[m[1]] = true;
          var scope = panelScope(m[1]);
          if (!scope) {
            check('section ' + m[1] + ': the button resolves its anchor', false);
            return;
          }
          var got = pressExcel(btn);
          check('section ' + m[1] + ': the button produced a workbook', !!got,
                tablesIn(scope).length + ' tables in the scope it resolves to');
          if (!got) return;
          analyse('section/' + m[1], scope, got.xml);
          out.xml.push({ name: 'section-' + m[1],
                         b64: btoa(unescape(encodeURIComponent(got.xml))) });
        });

      // Significance markers. A panel draws them inside the cell, beside the
      // figure, so turning them on is the other way a figure can stop being a
      // figure. Counting the number cells with the markers off and then on
      // says whether it does.
      var g1 = Object.keys(groups)[0];
      var sigBtn = document.querySelector(
        '.br-sig-toggle[data-group="' + g1 + '"][data-destination="mental"]');
      var sigExcel = document.querySelector(
        '.br-dest-excel[data-group="' + g1 + '"][data-destination="mental"][data-tier="main"]');
      if (sigBtn && sigExcel) {
        var navS = document.querySelector(
          '.br-destination-btn[data-group="' + g1 + '"][data-destination="mental"]');
        if (navS) window.switchBrandDestination(navS);
        function numberCount(xml) {
          return (xml.match(/ss:Type="Number"/g) || []).length;
        }
        var before = pressExcel(sigExcel);
        sigBtn.click();
        var after = pressExcel(sigExcel);
        if (before && after) {
          check('significance on: no figure stops being a number',
                numberCount(after.xml) === numberCount(before.xml),
                numberCount(before.xml) + ' number cells off, ' +
                numberCount(after.xml) + ' on');
          out.sigDiff = [];
          var b = sheetsOf(before.xml), a = sheetsOf(after.xml);
          for (var si = 0; si < a.length && si < b.length; si++) {
            for (var ri = 0; ri < a[si].rows.length; ri++) {
              var ar = a[si].rows[ri], br2 = b[si].rows[ri] || [];
              for (var ci = 0; ci < ar.length; ci++) {
                if (br2[ci] && br2[ci].type === 'Number' &&
                    ar[ci].type !== 'Number') {
                  out.sigDiff.push(b[si].name + ' r' + ri + ' c' + ci + ': ' +
                                   br2[ci].value + ' -> ' + ar[ci].value);
                }
              }
            }
          }
        } else {
          check('significance on: the view exports in both states', false);
        }
        sigBtn.click();
      }

      // The reader's brand filter, driven through the control the reader
      // uses rather than through the API behind it. Focal only is the
      // narrowest of its three states, so what is left in the workbook after
      // it is the clearest statement of whether the file follows the view.
      var g0 = Object.keys(groups)[0];
      var maBtn = document.querySelector(
        '.br-dest-excel[data-group="' + g0 + '"][data-destination="mental"][data-tier="main"]');
      var navBtn = document.querySelector(
        '.br-destination-btn[data-group="' + g0 + '"][data-destination="mental"]');
      var focalBtn = document.querySelector(
        '.br-cmp-mode[data-cmp-set="focal"]');
      if (maBtn && navBtn && focalBtn) {
        window.switchBrandDestination(navBtn);
        focalBtn.click();
        var scope = window.brDestScope(maBtn);
        // The brand columns of the matrix, and whether each is on screen
        // after the click. Read from the page, not from the filter's state.
        var onScreen = [], offScreen = [];
        scope.querySelectorAll('th[data-ma-brand]').forEach(function (th) {
          var code = th.getAttribute('data-ma-brand');
          if (!code || code === '__avg__') return;
          var clone = th.cloneNode(true);
          clone.querySelectorAll('.ma-focal-badge, .ct-sort-indicator, button')
               .forEach(function (e) { e.remove(); });
          var nm = clone.textContent.replace(/\\s+/g, ' ').trim();
          if (!nm) return;
          (shown(th) ? onScreen : offScreen).push(nm);
        });
        check('brand filter: Focal only narrows the matrix on screen',
              offScreen.length > 0 && onScreen.length > 0,
              onScreen.length + ' shown, ' + offScreen.length + ' hidden');
        var got = pressExcel(maBtn);
        if (!got) {
          check('brand filter: the filtered view exports', false);
        } else {
          var leaked = offScreen.filter(function (nm) {
            return got.xml.indexOf('>' + esc(nm) + '<') !== -1;
          });
          check('brand filter: a brand the reader hid is not in the workbook',
                leaked.length === 0, 'leaked ' + leaked.join(', '));
          var lost = onScreen.filter(function (nm) {
            return got.xml.indexOf('>' + esc(nm) + '<') === -1;
          });
          check('brand filter: every brand still on screen is in the workbook',
                lost.length === 0, 'missing ' + lost.join(', '));
          out.xml.push({ name: 'brand-filtered', b64:
            btoa(unescape(encodeURIComponent(got.xml))) });
        }
        // The same question where the brands are ROWS, which is the shape
        // the defect was reported against. The Brand Funnel puts one row per
        // brand in Brand and Buying, and the filter hides a row with
        // style.display rather than a column.
        var fnBtn = document.querySelector(
          '.br-dest-excel[data-group="' + g0 + '"][data-destination="buying"][data-tier="main"]');
        var navF = document.querySelector(
          '.br-destination-btn[data-group="' + g0 + '"][data-destination="buying"]');
        if (fnBtn && navF) {
          window.switchBrandDestination(navF);
          var fnScope = window.brDestScope(fnBtn);
          // A report opens in Focal only, so the narrowing is done the other
          // way round: widen to All brands first, take that workbook, then
          // narrow again and take the second. The pair is what says the file
          // followed the reader rather than happening to agree with it.
          var allFirst = document.querySelector(
            '.br-cmp-mode[data-cmp-set="all"]');
          if (allFirst) allFirst.click();
          var wideNames = [];
          fnScope.querySelectorAll('tr[data-fn-brand]').forEach(function (tr) {
            var td = tr.querySelector('td');
            if (!td || !shown(tr)) return;
            var c = td.cloneNode(true);
            c.querySelectorAll('.fn-focal-badge, button').forEach(
              function (e2) { e2.remove(); });
            var nm = c.textContent.replace(/\s+/g, ' ').trim();
            if (nm) wideNames.push(nm);
          });
          var gotWide = pressExcel(fnBtn);
          if (gotWide) {
            var absent = wideNames.filter(function (nm) {
              return gotWide.xml.indexOf(esc(nm)) === -1;
            });
            check('brand filter: All brands puts every funnel row in the workbook',
                  wideNames.length > 1 && absent.length === 0,
                  wideNames.length + ' rows, missing ' + absent.join(', '));
          }
          if (focalBtn) focalBtn.click();
          var rowsOn = [], rowsOff = [];
          fnScope.querySelectorAll('tr[data-fn-brand]').forEach(function (tr) {
            var td = tr.querySelector('td');
            if (!td) return;
            var clone = td.cloneNode(true);
            clone.querySelectorAll('.fn-focal-badge, button')
                 .forEach(function (e2) { e2.remove(); });
            var nm = clone.textContent.replace(/\s+/g, ' ').trim();
            if (!nm) return;
            (shown(tr) ? rowsOn : rowsOff).push(nm);
          });
          check('brand filter: Focal only narrows the funnel rows on screen',
                rowsOff.length > 0 && rowsOn.length > 0,
                rowsOn.length + ' shown, ' + rowsOff.length + ' hidden');
          var gotF = pressExcel(fnBtn);
          if (!gotF) {
            check('brand filter: the filtered funnel exports', false);
          } else {
            var leakedRows = rowsOff.filter(function (nm) {
              return gotF.xml.indexOf('>' + esc(nm) + '<') !== -1;
            });
            check('brand filter: a brand row the reader hid is not in the workbook',
                  leakedRows.length === 0, 'leaked ' + leakedRows.join(', '));
            var lostRows = rowsOn.filter(function (nm) {
              return gotF.xml.indexOf(esc(nm)) === -1;
            });
            check('brand filter: every brand row still on screen is in the workbook',
                  lostRows.length === 0, 'missing ' + lostRows.join(', '));
          }
        }

        var allBtn = document.querySelector('.br-cmp-mode[data-cmp-set="all"]');
        if (allBtn) allBtn.click();
      } else {
        check('brand filter: a Mental Availability export and a filter exist',
              false, 'button ' + !!maBtn + ' nav ' + !!navBtn +
              ' focal control ' + !!focalBtn);
      }
    } catch (err) {
      out.errors.push('driver: ' + (err && err.stack ? err.stack : String(err)));
    }
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }, 1500); }

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
    fd, path = tempfile.mkstemp(suffix="_xlqa.html")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    src = argv[1]
    keep = "--keep" in argv
    xml_dir = None
    if "--xml-dir" in argv:
        xml_dir = argv[argv.index("--xml-dir") + 1]
        os.makedirs(xml_dir, exist_ok=True)
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

    print("\nScopes exported: %d" % len(res["scopes"]))
    for s in res["scopes"]:
        print("  %-34s tables=%2d sheets=%2d railed cells=%2d %7d bytes "
              "%6d style reads"
              % (s["name"], s["tables"], s["sheets"], s["railed"], s["bytes"],
                 s.get("styleCalls") or 0))
    print("\nMost computed-style reads in one workbook: %d"
          % (res.get("mostStyleCalls") or 0))

    if xml_dir:
        for x in res.get("xml", []):
            fn = os.path.join(
                xml_dir, re.sub(r"[^A-Za-z0-9]+", "_", x["name"]) + ".xml")
            with open(fn, "wb") as fh:
                fh.write(base64.b64decode(x["b64"]))
            print("  wrote " + fn)

    if res.get("sigDiff"):
        print("\nCells that stop being numbers when significance is on:")
        for d in res["sigDiff"][:20]:
            print("  " + d)

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
