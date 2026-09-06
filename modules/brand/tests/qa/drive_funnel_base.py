#!/usr/bin/env python3
"""Drive the funnel's base toggle in headless Chrome.

Same shape as drive_destinations.py and drive_overview.py: the report is
copied, a QA harness is injected into the copy, and Chrome renders it once
with --dump-dom, so the harness runs inside the real page against the real
bundled JavaScript.

What it asserts, on the first funnel panel it finds:
  the nested view is the active toggle on load, and the figure on screen is
    the one the nested attribute carries;
  the nested figure equals the chain count over the weighted total, read
    back out of the panel's own JSON island, not out of the markup that was
    rendered from it;
  the nested chain never rises from one stage to the next, while the
    absolute view on the same data does rise somewhere (so the two views
    are provably different on this report, and the test would notice if the
    toggle silently did nothing);
  clicking each of the four toggles rewrites the table, the mini funnels
    and the summary cards to that view, and the cards agree with the table;
  no significance mark of either kind is on screen in the nested view, and
    the marks come back in the absolute view when the engine gave any;
  the category-average row's range bar is drawn at the same base as the
    figure above it, so the figure sits inside its own band in every view;
  the bar chart carries the figure for the active base at a LATE stage,
    where the chain and the absolute figure are not the same number;
  the "How this works" drawer starts collapsed and opens;
  the Excel export names the view it carries;
  no console error or uncaught exception anywhere in the run.

Usage:
    python3 drive_funnel_base.py REPORT.html [--keep]
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
  var out = { checks: [], errors: qa.errors, views: [], focal: null,
              exportBase: null };
  function check(name, ok, detail) {
    out.checks.push({ name: name, ok: !!ok, detail: detail || '' });
  }
  function visible(el) {
    if (!el) return false;
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  }
  function txt(el) { return el ? (el.textContent || '').trim() : ''; }
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) {
    return Array.prototype.slice.call((r || document).querySelectorAll(s));
  }
  function pctOf(td) {
    var v = txt($('.fn-pct-primary', td));
    return v;
  }

  function report() {
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }

  function run() {
    var panel = $('.fn-panel');
    check('a funnel panel is in the page', !!panel);
    if (!panel) { report(); return; }

    // The panel has to be on screen for its controls to be clickable, so
    // walk up and reveal every hidden ancestor the shell put it behind.
    var el = panel;
    while (el && el !== document.body) {
      if (el.hidden) el.hidden = false;
      if (el.classList && el.classList.contains('br-tab-panel')) {
        el.classList.add('active');
        el.style.display = 'block';
      }
      if (el.style && el.style.display === 'none') el.style.display = '';
      el = el.parentElement;
    }

    var island = $('.fn-panel-data', panel) ||
                 $('#' + (panel.getAttribute('data-island-host') || '') +
                   ' .fn-panel-data');
    var pd = null;
    try { pd = JSON.parse(island.textContent); } catch (e) { pd = null; }
    check('the panel payload parses', !!pd);
    if (!pd) { report(); return; }

    var nW = Number(pd.meta.n_weighted);
    var focal = pd.meta.focal_brand_code;
    var stageKeys = pd.table.stage_keys || [];
    out.focal = focal;

    // Independent expectation, computed here from the payload rather than
    // read off the markup the same payload produced.
    var want = {};
    (pd.table.cells || []).forEach(function (c) {
      if (c.brand_code !== focal) return;
      want[c.stage_key] = {
        chain: (c.base_chain_filtered == null) ? null
               : c.base_chain_filtered / nW,
        abs: c.pct_absolute,
        nested: c.pct_nested,
        aware: c.pct_aware
      };
    });

    // ---- Which mode the report is in ----------------------------------
    // The nested chain exists only where the questionnaire routed the
    // questions. On an ungated instrument R renders no chain button, the
    // default is each stage on its own, and the page says why. Both modes
    // are driven here, so this gate covers whichever the report is in.
    var gated = !(pd.meta.gating && pd.meta.gating.gated === false);
    out.gated = gated;
    var notice = $('[data-fn-gating]', panel);
    check('the panel says on its face which mode it is in', !!notice,
          notice ? notice.getAttribute('data-fn-gating') : 'none');
    check('the notice agrees with the payload',
          !!notice && notice.getAttribute('data-fn-gating') ===
            (gated ? 'gated' : 'ungated'));
    check('the notice gives a reason, not just a label',
          !!notice && txt(notice).length > 60, notice ? txt(notice) : 'none');

    var defaultMode = gated ? 'chain' : 'total';
    var defaultField = gated ? 'chain' : 'abs';

    // ---- The default view --------------------------------------------
    var active = $('.fn-base-switcher .sig-btn-active', panel);
    check('a base toggle is active on load', !!active);
    check('the active toggle on load is the default for this mode',
          !!active && active.getAttribute('data-fn-pctmode') === defaultMode,
          (active ? active.getAttribute('data-fn-pctmode') : 'none') +
            ', expected ' + defaultMode);
    check('at most one toggle says funnel',
          $$('.fn-base-switcher .sig-btn', panel).filter(function (b) {
            return /funnel/i.test(txt(b));
          }).length === (gated ? 1 : 0));
    check('the chain toggle is offered only where the survey routed',
          !!$('.fn-base-switcher [data-fn-pctmode="chain"]', panel) === gated);

    var row = $('tr.fn-row-focal', panel);
    check('the focal row is in the table', !!row);

    function readRow() {
      var got = {};
      stageKeys.forEach(function (k) {
        var td = $('tr.fn-row-focal td[data-fn-stage="' + k + '"]', panel);
        got[k] = td ? pctOf(td) : null;
      });
      return got;
    }
    function readCards() {
      var got = {};
      stageKeys.forEach(function (k) {
        var card = $('.fn-card-funnel[data-fn-stage="' + k + '"]', panel);
        got[k] = card ? txt($('.tk-hero-value', card)) : null;
      });
      return got;
    }
    function pct(v) {
      return (v == null || isNaN(v)) ? null : Math.round(v * 100) + '%';
    }

    var modes = [
      { mode: 'total',    field: 'abs' },
      { mode: 'previous', field: 'nested' },
      { mode: 'aware',    field: 'aware' }
    ];
    if (gated) modes.unshift({ mode: 'chain', field: 'chain' });

    // Load state first, without clicking anything.
    var onLoad = readRow();
    stageKeys.forEach(function (k) {
      var expect = pct(want[k][defaultField]);
      check('on load, ' + k + ' shows the ' + defaultMode + ' figure',
            onLoad[k] === expect,
            'screen ' + onLoad[k] + ', payload ' + expect);
    });

    // The chain must not rise; the absolute view on this data must rise
    // somewhere, so the two views are provably different here.
    var chainVals = stageKeys.map(function (k) { return want[k].chain; });
    var absVals   = stageKeys.map(function (k) { return want[k].abs; });
    var chainRises = false, absRises = false;
    for (var i = 1; i < chainVals.length; i++) {
      if (chainVals[i] > chainVals[i - 1] + 1e-9) chainRises = true;
      if (absVals[i] > absVals[i - 1] + 1e-9) absRises = true;
    }
    if (gated) {
      check('the nested chain never rises', !chainRises,
            chainVals.map(function (v) { return pct(v); }).join(' '));
      check('the two views differ somewhere on this report',
            JSON.stringify(chainVals) !== JSON.stringify(absVals));
    } else {
      // The cumulative counts stay in the payload, because "% of previous"
      // and "% of those aware" are the conversion ratios this mode reports
      // and both are honest intersections. What must not survive is the
      // "% of all" view, which draws the chain as the whole funnel. So the
      // rendered cells carry no chain figure of their own: every
      // data-fn-pct-chn equals its cell's own data-fn-pct-abs.
      var chainAttrsMatchAbs = true, sampled = 0;
      $$('tr.fn-row-focal td[data-fn-stage], tr.fn-row-competitor td[data-fn-stage]',
         panel).forEach(function (td) {
        var chn = td.getAttribute('data-fn-pct-chn');
        var abs = td.getAttribute('data-fn-pct-abs');
        if (chn == null || abs == null) return;
        sampled += 1;
        if (chn !== abs) chainAttrsMatchAbs = false;
      });
      check('no rendered cell carries a chain figure of its own',
            sampled > 0 && chainAttrsMatchAbs, sampled + ' cells sampled');
      check('and the chain view cannot be reached from the controls',
            !$('.fn-base-switcher [data-fn-pctmode="chain"]', panel));
    }

    // ---- Each toggle -------------------------------------------------
    modes.forEach(function (m) {
      var btn = $('.fn-base-switcher [data-fn-pctmode="' + m.mode + '"]', panel);
      check('the ' + m.mode + ' toggle exists', !!btn);
      if (!btn) return;
      btn.click();
      var got = readRow();
      var cards = readCards();
      out.views.push({ mode: m.mode, label: txt(btn), row: got, cards: cards });
      check('the ' + m.mode + ' toggle becomes the active one',
            btn.classList.contains('sig-btn-active'));
      stageKeys.forEach(function (k) {
        var expected = pct(want[k][m.field]);
        if (expected == null) return;
        check(m.mode + ': ' + k + ' reads its own view',
              got[k] === expected,
              'screen ' + got[k] + ', payload ' + expected);
        check(m.mode + ': the card at ' + k + ' agrees with the table',
              cards[k] === got[k],
              'card ' + cards[k] + ', table ' + got[k]);
      });
      // Significance marks.
      var marks = $$('tr.fn-row-focal .ct-sig, tr.fn-row-focal .fn-sig-avg,' +
                     ' tr.fn-row-competitor .ct-sig,' +
                     ' tr.fn-row-competitor .fn-sig-avg', panel);
      if (m.mode === 'chain') {
        check('the nested view shows no significance mark at all',
              marks.length === 0, marks.length + ' found');
        var cardMarks = $$('.fn-card-funnel .fn-sig', panel);
        check('and none on the summary cards either',
              cardMarks.length === 0, cardMarks.length + ' found');
      } else {
        out.views[out.views.length - 1].marks = marks.length;
      }
      // The card strip says which base it is drawn on.
      var note = $('[data-fn-cards-base-note]', panel);
      check(m.mode + ': the card strip names its base',
            !!note && txt(note).indexOf('Base:') === 0 && txt(note).length > 6,
            txt(note));

      // The category-average row draws a range bar under its figure. The
      // bar, the tick and the lo/hi labels are base-dependent like the
      // figure, and a figure sitting outside its own band is the symptom
      // of the two being computed at different bases.
      stageKeys.forEach(function (k) {
        var td = $('tr.fn-row-avg-all td[data-fn-brand="__avg__"]' +
                   '[data-fn-stage="' + k + '"]', panel);
        if (!td) return;
        var lim = $$('.ma-ci-limits span', td).map(function (e) {
          return parseFloat(txt(e));
        });
        var shown = parseFloat(pctOf(td));
        if (lim.length < 2 || isNaN(shown) || isNaN(lim[0]) || isNaN(lim[1])) {
          return;
        }
        check(m.mode + ': the avg figure at ' + k + ' sits inside its band',
              shown >= lim[0] - 1 && shown <= lim[1] + 1,
              shown + ' in [' + lim[0] + ', ' + lim[1] + ']');
      });

      /* Bar view: it plots one stage across brands and used to read the
         absolute figure whatever the toggle said. A LATE stage is chosen
         on purpose: at the first stage the chain and the absolute figure
         are the same number, so the check would pass on a chart that
         ignored the toggle entirely. */
      var barBtn = $('button[data-fn-view="bar"]', panel);
      var lateStage = stageKeys[stageKeys.length - 1];
      var stageChip = $('.fn-stk-emph-chip[data-fn-stk-emphasis="' +
                        lateStage + '"]', panel);
      if (barBtn && stageChip) {
        barBtn.click();
        stageChip.click();
        var wantBar = pct(want[lateStage] ? want[lateStage][m.field] : null);
        var barTexts = $$('.fn-bar-svg text', panel).map(function (t) {
          return txt(t);
        });
        if (wantBar != null) {
          check(m.mode + ': the bar view carries the figure for ' + lateStage,
                barTexts.indexOf(wantBar) >= 0,
                'wanted ' + wantBar + ', saw ' +
                barTexts.slice(0, 10).join(' '));
        }
        // And its title names the base it drew, rather than the one it
        // used to hard-code.
        var barTitle = barTexts.length ? barTexts[0] : '';
        check(m.mode + ': the bar chart title names its base',
              barTitle.indexOf('% of total respondents') === -1 ||
              m.mode === 'total', barTitle);
        check(m.mode + ': the bar chart title names its stage, not the key',
              barTitle.indexOf(lateStage) === -1, barTitle);
        var slopeBtn = $('button[data-fn-view="slope"]', panel);
        if (slopeBtn) slopeBtn.click();
      } else {
        check(m.mode + ': the bar view and its stage chips are reachable',
              !!barBtn && !!stageChip,
              'bar=' + !!barBtn + ' chip=' + !!stageChip);
      }
    });

    // Some view other than the nested one must be able to show a mark, or
    // this report simply has no significant cells and the suppression
    // check above proves nothing. Report which it is rather than assert.
    var withMarks = out.views.filter(function (v) { return v.marks > 0; });
    out.marksSeenIn = withMarks.map(function (v) { return v.mode; });

    // ---- Back to the default, so the page is left as it opened -------
    var chainBtn = $('.fn-base-switcher [data-fn-pctmode="chain"]', panel);
    if (chainBtn) chainBtn.click();

    // ---- The explainer ------------------------------------------------
    var howto = $('[data-fn-base-howto]', panel);
    check('the base explainer is on the page', !!howto);
    if (howto) {
      var body = $('.fn-base-howto-body', howto);
      var btn2 = $('.fn-base-howto-toggle', howto);
      check('the explainer starts collapsed', !!body && body.hidden === true);
      check('it names the missing significance mark',
            !!body && /Significance marks/.test(body.textContent || ''));
      if (btn2) {
        btn2.click();
        check('it opens on click', !!body && body.hidden === false);
        check('and reports itself as expanded',
              btn2.getAttribute('aria-expanded') === 'true');
        btn2.click();
        check('and closes again', !!body && body.hidden === true);
      }
    }

    // ---- The Excel export names its view ------------------------------
    // The export builds an HTML workbook and hands it to a Blob download.
    // Intercepting the Blob is the only way to read it without a file
    // system, so URL.createObjectURL is wrapped for one click.
    var captured = null;
    var realCreate = URL.createObjectURL;
    var realClick = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function () {
      if (this.download) return;
      return realClick.apply(this, arguments);
    };
    var realBlob = window.Blob;
    window.Blob = function (parts, opts) {
      if (parts && parts.length && typeof parts[0] === 'string' &&
          parts[0].indexOf('Base:') !== -1) captured = parts[0];
      return new realBlob(parts, opts);
    };
    URL.createObjectURL = function () { return 'blob:qa'; };
    var exportBtn = $('[data-fn-action="exporttable"]', panel);
    if (exportBtn) exportBtn.click();
    window.Blob = realBlob;
    URL.createObjectURL = realCreate;
    HTMLAnchorElement.prototype.click = realClick;
    var baseRow = captured
      ? (captured.match(/class="mode"[^>]*>([^<]*)</) || [])[1] : null;
    out.exportBase = baseRow || null;
    check('the Excel export carries a base line', !!baseRow, baseRow || 'none');
    check('the export names the view it was taken in',
          !!baseRow && (gated ? /nested funnel/i : /of those aware/i)
            .test(baseRow), baseRow || 'none');

    check('no console error and no uncaught exception', qa.errors.length === 0,
          qa.errors.slice(0, 3).join(' | '));
    report();
  }

  if (document.readyState === 'complete') setTimeout(run, 400);
  else window.addEventListener('load', function () { setTimeout(run, 400); });
})();
</script>
"""


def build_copy(src):
    html = open(src, encoding="utf-8").read()
    i = html.index("<head>") + len("<head>")
    html = html[:i] + HOOK + html[i:]
    j = html.rindex("</body>")
    html = html[:j] + DRIVER + html[j:]
    fd, path = tempfile.mkstemp(suffix="_funnel_base_qa.html")
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
        print("  %s %s%s" % (mark, c["name"],
                             (" -> " + c["detail"]) if c["detail"] else ""))

    print("\nFocal brand: %s" % res.get("focal"))
    print("The focal row, by view")
    for v in res["views"]:
        cells = " ".join("%s" % (x or "-") for x in v["row"].values())
        print("  %-9s %-24s %s%s"
              % (v["mode"], v["label"], cells,
                 ("   marks=%d" % v["marks"]) if "marks" in v else ""))
    if res.get("marksSeenIn"):
        print("Significance marks appeared in: %s"
              % ", ".join(res["marksSeenIn"]))
    else:
        print("No view on this report carried a significance mark, so the "
              "nested suppression is asserted against an empty set here.")
    if res.get("exportBase"):
        print("Excel base line: %s" % res["exportBase"][:160])

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
