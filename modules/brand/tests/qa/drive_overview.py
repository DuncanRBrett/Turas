#!/usr/bin/env python3
"""Drive the Stage 3 Overview of a brand report in headless Chrome.

Same shape as drive_destinations.py: the report is copied, a QA harness is
injected into the copy, and Chrome renders it once with --dump-dom, so the
harness runs inside the real page against the real bundled JavaScript.

What it asserts, on the Overview (the Summary tab):
  the four headline tiles render a value, not the en dash placeholder;
  every tile's comparison is a Stage 2 slot that names its source, and no
    tile hard-codes a "vs category average" sentence;
  exactly one tile carries a rank, and it is the Mental Market Share tile;
  every tile's link resolves: clicking it lands on a real destination in a
    real category tab, and the destination it lands on is the one the tile
    names;
  "What the numbers say" renders at least one derived sentence;
  the two Why blocks are split by concept and each names its own source;
  "Opportunities to examine" renders, and on a brand with no under-indexers
    it says so plainly rather than promoting the least-strong item;
  the "How this works" drawer starts collapsed and opens, and holds the
    "Which penetration is which" block;
  no console error or uncaught exception anywhere in the run.

Usage:
    python3 drive_overview.py REPORT.html [--keep]
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
  var out = { checks: [], errors: qa.errors, tiles: [], routes: [],
              funnel: null };
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

  function report() {
    var pre = document.createElement('pre');
    pre.id = 'turas-qa-result';
    pre.textContent = JSON.stringify(out);
    document.body.appendChild(pre);
  }

  function run() {
    // Land on the Summary tab, which is the Overview.
    var sumBtn = $('.br-tab-btn[data-tab="summary"]');
    check('the Summary tab button exists', !!sumBtn);
    if (sumBtn) sumBtn.click();

    var root = $('.brsum-root');
    check('the Overview panel is in the page', !!root);
    if (!root) { report(); return; }

    // ---- The headline tiles ------------------------------------------
    var strip = $('[data-brsum-tiles]', root);
    check('the headline tile strip renders', !!strip && visible(strip));
    var tiles = strip ? $$('.brsum-tile', strip) : [];
    check('there are four headline tiles, not six', tiles.length === 4,
          'found ' + tiles.length);

    var ranked = 0;
    tiles.forEach(function (t) {
      var key   = t.getAttribute('data-brsum-tile');
      var value = txt($('[data-brsum-tile-value]', t));
      var label = txt($('[data-brsum-tile-label]', t));
      var slot  = $('[data-compare-slot]', t);
      var rank  = $('[data-brsum-tile-rank]', t);
      var go    = $('.brsum-tile-go', t);
      var hasRank = !!(rank && !rank.hidden && txt(rank));
      if (hasRank) ranked++;
      out.tiles.push({ key: key, label: label, value: value,
                       compareSource: slot ? slot.getAttribute('data-compare-source') : null,
                       compareValue: txt($('.br-compare-value', slot || t)),
                       rank: hasRank ? txt(rank) : null,
                       dest: t.getAttribute('data-brsum-dest'),
                       go: txt(go) });
      check('tile ' + key + ' shows a figure, not the placeholder',
            !!value && value !== '\\u2013', value);
      check('tile ' + key + ' carries a comparison slot naming its source',
            !!slot && !!slot.getAttribute('data-compare-source'));
      check('tile ' + key + ' hard-codes no "vs category average" sentence',
            (t.textContent || '').toLowerCase().indexOf('vs category average') === -1);
      check('tile ' + key + ' has a link to its destination',
            !!go && !!t.getAttribute('data-brsum-dest'));
    });
    check('exactly one tile carries a rank', ranked === 1, 'ranked=' + ranked);
    var mmsTile = $('[data-brsum-tile="mms"]', root);
    var mmsRank = mmsTile ? $('[data-brsum-tile-rank]', mmsTile) : null;
    check('the rank sits on the Mental Market Share tile',
          !!mmsRank && !mmsRank.hidden && txt(mmsRank).indexOf('Rank') === 0,
          txt(mmsRank));

    // ---- What the numbers say ----------------------------------------
    var verdict = $('[data-brsum-verdict-body]', root);
    var lines = verdict ? $$('p', verdict) : [];
    check('What the numbers say renders at least one sentence',
          lines.length > 0, 'lines=' + lines.length);
    check('it does not fall through to a bare brand-in-category clause',
          lines.length > 1 || (lines[0] && txt(lines[0]).length > 40),
          lines[0] ? txt(lines[0]) : '');
    check('the retired conversion-gap diagnosis is gone',
          (txt(verdict) || '').indexOf('conversion gap') === -1);

    // ---- The two Why blocks ------------------------------------------
    var working = $('[data-brsum-card-body="working"]', root);
    var weak    = $('[data-brsum-card-body="weak"]', root);
    check('the moments block renders', !!working && txt(working).length > 0);
    check('the associations block renders', !!weak && txt(weak).length > 0);
    check('the moments block names Category Entry Points',
          (txt(working) || '').indexOf('Category Entry Point') >= 0);
    check('the associations block names attributes',
          (txt(weak) || '').toLowerCase().indexOf('attribute') >= 0);
    check('the two blocks are not the same list',
          txt(working) !== txt(weak));

    // ---- Opportunities to examine ------------------------------------
    var opp = $('[data-brsum-card-body="opportunities"]', root);
    check('Opportunities to examine renders', !!opp && txt(opp).length > 0);
    var oppText = txt(opp) || '';
    check('it is not labelled Protect, Build and Investigate',
          oppText.indexOf('Investigate') === -1);
    out.opportunities = oppText;
    // On a focal brand with no defend and no build item the block must say
    // so; a fallback item is allowed but must be labelled as a rule of thumb.
    var noneEl = $('[data-brsum-opp-none]', opp || document);
    if (noneEl) {
      check('with no defend or build item the block says so plainly',
            txt(noneEl).length > 0, txt(noneEl));
      var fb = $$('[data-brsum-opp-kind="rule-of-thumb"]', opp);
      fb.forEach(function (el) {
        check('a fallback item is labelled a rule of thumb',
              (el.textContent || '').toLowerCase().indexOf('rule of thumb') >= 0);
      });
    }

    // ---- How this works drawer ---------------------------------------
    var drawer = $('.brsum-howto', root);
    check('the How this works drawer exists', !!drawer);
    var toggle = drawer ? $('.brsum-howto-toggle', drawer) : null;
    var dbody  = drawer ? $('.brsum-howto-body', drawer) : null;
    check('the drawer starts collapsed', !!dbody && dbody.hidden === true);
    if (toggle) toggle.click();
    check('the drawer opens', !!dbody && dbody.hidden === false);
    check('the drawer holds the Which penetration is which block',
          !!dbody && !!$('[data-brsum-pen-notes]', dbody) &&
          (txt($('[data-brsum-pen-notes]', dbody)).indexOf('Which penetration is which') >= 0),
          dbody ? txt($('[data-brsum-pen-notes]', dbody)).slice(0, 60) : '');
    check('the drawer holds the methodology text',
          !!dbody && !!$('.t-callout', dbody));

    // ---- Every tile link resolves ------------------------------------
    tiles.forEach(function (t) {
      var key  = t.getAttribute('data-brsum-tile');
      var dest = t.getAttribute('data-brsum-dest');
      var go   = $('.brsum-tile-go', t);
      if (!go) { check('tile ' + key + ' has a link', false); return; }
      go.click();
      var panel = $('.br-panel.active');
      var pid = panel ? panel.id : '';
      var active = $('.br-destination.active[data-destination="' + dest + '"]');
      var landedOn = active && visible(active);
      out.routes.push({ tile: key, dest: dest, panel: pid,
                        landed: !!landedOn });
      check('tile ' + key + ' lands on a category panel',
            pid.indexOf('panel-cat-') === 0, pid);
      check('tile ' + key + ' lands on the ' + dest + ' destination',
            !!landedOn);
      var btn = $('.br-destination-btn.active[data-destination="' + dest + '"]');
      check('tile ' + key + ' leaves the ' + dest + ' button active', !!btn);
      // Back to the Overview for the next tile.
      if (sumBtn) sumBtn.click();
    });

    // ---- The route reads the selection, not the first option ----------
    // The report this runs on has one full-depth category, so the routing
    // has only ever been driven with one option in the picker. A picker
    // with one item is a picker that has not been tested. A second option
    // is inserted here, carrying an id no panel answers to, and the two
    // cases are driven: with the real category selected the tile must still
    // land on it, and with the unanswerable one selected the tile must make
    // no route rather than throwing or landing somewhere arbitrary.
    //
    // This does not prove routing across two REAL categories. The second
    // option carries no data of its own and no panel is built for it. It
    // closes the "reads options[0]" gap and no more.
    var sel = root.querySelector('[data-brsum-cat]');
    if (sel && sel.options.length) {
      var realValue = sel.value;
      var fake = document.createElement('option');
      fake.value = '__qa_no_such_category__';
      fake.textContent = 'QA, no such category';
      fake.setAttribute('data-cat-id', 'qa-no-such-category');
      sel.insertBefore(fake, sel.options[0]);

      // Case 1: the real category is selected, but is no longer first.
      sel.value = realValue;
      if (sumBtn) sumBtn.click();
      var tile1 = $('.brsum-tile[data-brsum-tile="mms"] .brsum-tile-go', root);
      if (tile1) tile1.click();
      var p1 = $('.br-panel.active');
      check('the route reads the selected option, not the first one',
            !!p1 && p1.id === 'panel-cat-dss', p1 ? p1.id : '');

      // Case 2: an id no panel answers to leaves the reader where they are.
      if (sumBtn) sumBtn.click();
      sel.value = fake.value;
      var before = $('.br-panel.active');
      var beforeId = before ? before.id : '';
      var tile2 = $('.brsum-tile[data-brsum-tile="mms"] .brsum-tile-go', root);
      if (tile2) tile2.click();
      var after = $('.br-panel.active');
      check('a category with no panel makes no route and does not throw',
            !!after && after.id === beforeId,
            beforeId + ' -> ' + (after ? after.id : ''));

      sel.removeChild(fake);
      sel.value = realValue;
      if (sumBtn) sumBtn.click();
    }

    // ---- The mini funnel draws the same view the funnel page opens on --
    // Stage 4. The card used to draw each stage on its own base while the
    // funnel destination opened on the nested chain: two shapes from one
    // dataset, with nothing on the page saying which was which.
    var fBody = $('[data-brsum-card-body="funnel"]', root);
    var fMeta = $('[data-brsum-card-meta="funnel"]', root);
    check('the buying funnel card renders', !!fBody && visible(fBody));
    var bIsland = $('script.brsum-data') || $('.brsum-data');
    var bd = null;
    try { bd = JSON.parse(bIsland.textContent); } catch (e) { bd = null; }
    var catSel = $('[data-brsum-cat]', root);
    var catKey = catSel ? catSel.value : null;
    var catBlk = (bd && bd.categories && catKey) ? bd.categories[catKey] : null;
    var fb = catBlk ? catBlk.funnel : null;
    var brandSel = $('[data-brsum-brand]', root);
    var bcode = brandSel ? brandSel.value : null;
    if (fBody && fb && fb.available && bcode) {
      // The Overview's mini funnel must agree with the funnel destination
      // about which mode the report is in. On a routed survey both draw the
      // nested chain; where the questionnaire asked every question of
      // everyone, the funnel destination has no nested view and the
      // Overview must not draw one either.
      var fnIsland = $('script.fn-panel-data') || $('.fn-panel-data');
      var fnPd = null;
      try { fnPd = JSON.parse(fnIsland.textContent); } catch (e) { fnPd = null; }
      var fnGated = !(fnPd && fnPd.meta && fnPd.meta.gating &&
                      fnPd.meta.gating.gated === false);
      check('the mini funnel agrees with the funnel destination on the mode',
            !!fb.nested === fnGated,
            'overview nested=' + String(fb.nested) + ', funnel gated=' +
              String(fnGated));
      var series = (fb.nested && fb.brands_nested) ? fb.brands_nested[bcode]
                                                   : (fb.brands || {})[bcode];
      var shown = $$('.brsum-mf-focal .brsum-mf-pct', fBody)
                    .map(function (e) { return txt(e); });
      out.funnel = {
        nested: !!fb.nested, shown: shown, meta: txt(fMeta),
        expected: (series || []).map(function (v) {
          return (v == null || isNaN(v)) ? '\u2013'
                 : Math.round(v * 100) + '%';
        })
      };
      check('the card draws the series the payload says it draws',
            JSON.stringify(out.funnel.shown) ===
            JSON.stringify(out.funnel.expected),
            out.funnel.shown.join(' ') + ' vs ' +
            out.funnel.expected.join(' '));
      if (fb.nested) {
        check('the card says on its face that it is nested',
              /Nested/.test(txt(fMeta)), txt(fMeta));
        var absSeries = (fb.brands || {})[bcode] || [];
        check('the nested series really differs from the absolute one',
              JSON.stringify(series) !== JSON.stringify(absSeries));
      }

      // --- the words on the page, mode by mode ---------------------------
      // Duncan's ruling of 7 September 2026: a nested funnel only where the
      // questionnaire gated the questions. Stage 3 built the Overview when
      // the funnel was nested for everyone, so on an ungated report the card
      // was still titled "Buying funnel" and Opportunities still said the
      // largest step down was a share "of the stage before it". These checks
      // fail on that behaviour.
      var fCard = $('[data-brsum-card="funnel"]', root);
      var fTitle = fCard ? txt($('.brsum-card-title', fCard)) : null;
      var oppBody = $('[data-brsum-card-body="opportunities"]', root);
      var oppTxt = oppBody ? txt(oppBody) : '';
      var note = $('[data-brsum-funnel-note]', root);
      out.funnelWords = { title: fTitle, gated: fnGated,
                          note: note ? txt(note) : null,
                          section: fCard ? fCard.getAttribute('data-section') : null };
      check('the buying card keeps its anchor whatever it is titled',
            out.funnelWords.section === 'brsum-funnel', out.funnelWords.section);
      if (fnGated) {
        check('routed: the card is titled as a funnel',
              fTitle === 'Buying funnel', String(fTitle));
        check('routed: no separate-measures note under the bars', !note);
        check('routed: Opportunities reports the conversion',
              /of the stage before it/.test(oppTxt),
              oppTxt.slice(-160));
      } else {
        check('not routed: the card is not titled as a funnel',
              !!fTitle && !/funnel/i.test(fTitle), String(fTitle));
        check('not routed: the base line says separate measures',
              /Separate measures/.test(txt(fMeta)), txt(fMeta));
        check('not routed: a note under the bars says why', !!note,
              note ? txt(note) : 'no note');
        check('not routed: Opportunities claims no nesting',
              !/of the stage before it/.test(oppTxt) &&
              !/step down/.test(oppTxt),
              oppTxt.slice(-200));
        check('not routed: and says what the figures are instead',
              /separate measures/.test(oppTxt) &&
              /not a conversion/.test(oppTxt),
              oppTxt.slice(-200));
      }
    }

    check('no console error or uncaught exception', qa.errors.length === 0,
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
    fd, path = tempfile.mkstemp(suffix="_overview_qa.html")
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

    print("\nHeadline tiles")
    for t in res["tiles"]:
        print("  %-4s %-32s %-8s compare=%-18s(%s) rank=%s -> %s"
              % (t["key"], t["label"], t["value"], t["compareValue"],
                 t["compareSource"], t["rank"] or "none", t["go"]))

    print("\nTile routes")
    for r in res["routes"]:
        print("  %-4s -> %-9s %-18s landed=%s"
              % (r["tile"], r["dest"], r["panel"], r["landed"]))

    if res.get("funnel"):
        f = res["funnel"]
        print("\nBuying funnel card")
        print("  nested=%s  shown=%s" % (f["nested"], " ".join(f["shown"])))
        print("  base: %s" % f["meta"])

    if res.get("funnelWords"):
        w = res["funnelWords"]
        print("\nWhat the buying card is called")
        print("  routed=%s  title=%r  anchor=%s" %
              (w["gated"], w["title"], w["section"]))
        if w["note"]:
            print("  note: %s" % w["note"])

    if res.get("opportunities"):
        print("\nOpportunities to examine")
        print("  " + res["opportunities"][:600])

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
