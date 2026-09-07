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
  // The matrix now sits in the ma-advantage-detail host, in Mental
  // Availability's Advanced drawer, so the column check follows it there.
  // What is left on ma-advantage is the strategic quadrant and the action
  // list, both of which are focal-brand views: neither carries a
  // brand-coded element, verified by running this script with the entry
  // removed and finding none.
  var NO_BRAND_CODES = { 'cb-context': 'none', 'ma-advantage': 'none',
                         'ma-advantage-detail': 'columns',
                         'branded_reach': 'unwired', 'adhoc': 'unwired',
                         'audience_lens': 'unwired' };

  // 'unwired' pins a fact rather than passing or failing a design.
  //
  // Branded Reach, Ad Hoc and Audience Lens rendered for the first time in
  // Stage 6, on the QA extras fixture. None of the three carries a brand-code
  // attribute or subscribes to the category comparison set, so the brand
  // filter does not reach them. That is not a simplification regression:
  // these panels have never been inside the shell before, and nothing about
  // them changed. It is also not obviously wrong for all three. Audience Lens
  // is a focal-brand view whose two audiences are buyer and non-buyer of that
  // one brand, so there is no brand list to narrow. Branded Reach and Ad Hoc
  // do show brand-keyed content, and for them it is a real gap.
  //
  // Rather than mark them 'none' and quietly bless it, this asserts that they
  // show NO brand code at all. The day one of them is wired up, this check
  // fails and forces the classification to be revisited instead of drifting.
  // The Stage 6 log records it as an open gap.

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
      if (kind === 'unwired') {
        var codes = visibleBrandCodes(host);
        check(tab + '/' + stateName + '/' + leaf +
              ': the brand filter does not reach it, recorded not blessed',
              codes.length === 0,
              'now shows ' + codes.join(',') +
              ': wire it to the comparison set and reclassify it');
        return;
      }
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

  // Views that cannot narrow at all must carry no Chart brands control:
  // a control that does nothing is what made the old Dirichlet Norms filter
  // read "1 of 11" beside a table of eleven brands.
  // The two Mental Advantage leaves are the ones that genuinely cannot have
  // the control: the quadrant SVG plots one bubble per stimulus for the
  // focal brand alone, so there is no brand-keyed chart to narrow, and
  // __maAdvHiddenBrands governs matrix columns, which are a table and now
  // sit in the detail host.
  // Demographics shows a table OR a chart per card behind a view toggle, so
  // a chart is never beside its table. The other four do not narrow at all.
  var NO_CHART_FOCUS = { 'cb-context': 1, 'cb-norms': 1, 'cb-dop': 1,
                         'cb-shopper': 1, 'demographics': 1,
                         'ma-advantage': 1, 'ma-advantage-detail': 1 };

  function chartFocusHandle(mount) {
    var el = mount.parentElement;
    while (el) {
      if (el.__brChartSelector) return el.__brChartSelector;
      el = el.parentElement;
    }
    return null;
  }

  function codesInAttr(nodes, attr) {
    var seen = {};
    Array.prototype.forEach.call(nodes, function (el) {
      var v = el.getAttribute(attr);
      if (v && v !== '__avg__') seen[v] = true;
    });
    return Object.keys(seen).sort();
  }
  function codesIn(nodes) { return codesInAttr(nodes, 'data-cb-brand'); }

  function setToSorted(s) {
    var out = [];
    s.forEach(function (c) { out.push(c); });
    return out.sort();
  }

  // --- the pin clause, on the two sites added in this pass ----------------
  // Both handlers build their own title, so the only way to know the clause
  // reaches a card is to make a card. TurasPins.getAll() is the store the
  // Pinned Views tab renders from.
  function lastPinTitle() {
    if (typeof TurasPins === 'undefined' || !TurasPins.getAll) return null;
    var all = TurasPins.getAll();
    if (!all.length) return null;
    return all[all.length - 1].title || '';
  }

  function pinFunnelRelChart(panel, tab) {
    var host = panel.querySelector('.br-subpanel[data-leaf="fn-relationship"]');
    if (!host) return;
    var btn = host.querySelector('[data-fn-action="pindropdown"]');
    if (!btn) { check(tab + '/relationship: a pin control exists', false); return; }
    btn.click();
    var drop = host.querySelector('.fn-pin-dropdown') ||
               panel.querySelector('.fn-pin-dropdown');
    if (!drop) { check(tab + '/relationship: the pin dropdown opens', false); return; }
    check(tab + '/relationship: the pin dropdown opens', true);

    // Chart alone: the card carries the chart, so the clause belongs on it.
    var before = (TurasPins.getAll() || []).length;
    var chartChk = drop.querySelector(
      '.fn-pin-chk[data-fn-pin-sel="[data-fn-rel-chart-area]"]');
    check(tab + '/relationship: the dropdown offers the chart', !!chartChk);
    if (!chartChk) return;
    chartChk.checked = true;
    drop.querySelector('.fn-pin-save-btn').click();
    var t1 = lastPinTitle();
    check(tab + '/relationship: a pin of the chart is created',
          (TurasPins.getAll() || []).length === before + 1, String(t1));
    check(tab + '/relationship: the pin title carries the clause',
          !!t1 && /chart shows \\d+ of \\d+ brands/.test(t1), String(t1));

    // Table alone: nothing on that card deviates from anything, so the
    // clause must not appear.
    btn.click();
    var drop2 = host.querySelector('.fn-pin-dropdown') ||
                panel.querySelector('.fn-pin-dropdown');
    if (!drop2) return;
    var tblChk = drop2.querySelector(
      '.fn-pin-chk[data-fn-pin-sel=".fn-rel-table-wrap"]');
    if (!tblChk) return;
    tblChk.checked = true;
    drop2.querySelector('.fn-pin-save-btn').click();
    var t2 = lastPinTitle();
    check(tab + '/relationship: a table-only pin is not labelled as deviating',
          !!t2 && !/chart shows/.test(t2), String(t2));
  }

  function pinMaMetricsChart(panel, tab) {
    var host = panel.querySelector('.br-subpanel[data-leaf="ma-metrics"]');
    if (!host) return;
    var btn = host.querySelector('.ma-pin-dropdown-btn');
    if (!btn) { check(tab + '/metrics: a pin control exists', false); return; }
    btn.click();
    var drop = host.querySelector('.ma-pin-dropdown') ||
               panel.querySelector('.ma-pin-dropdown');
    if (!drop) { check(tab + '/metrics: the pin dropdown opens', false); return; }
    check(tab + '/metrics: the pin dropdown opens', true);

    // Mental Space scatter and the brand metric table, ticked together. The
    // metrics branch emits one card per element, so this makes two cards and
    // only the chart card may carry the clause.
    var before = (TurasPins.getAll() || []).length;
    var sc = drop.querySelector('input[data-ma-pin-opt="scatter"]');
    var tb = drop.querySelector('input[data-ma-pin-opt="brandtbl"]');
    check(tab + '/metrics: the dropdown offers the scatter and the table',
          !!sc && !!tb);
    if (!sc || !tb) return;
    sc.checked = true; tb.checked = true;
    drop.querySelector('.ma-pin-confirm').click();
    var made = (TurasPins.getAll() || []).slice(before);
    check(tab + '/metrics: two cards are pinned', made.length === 2,
          made.map(function (p) { return p.title; }).join(' | '));
    var chartCard = null, tableCard = null;
    made.forEach(function (p) {
      if (/Mental Space/.test(p.title || '')) chartCard = p;
      if (/Brand metrics table/.test(p.title || '')) tableCard = p;
    });
    check(tab + '/metrics: the chart card carries the clause',
          !!chartCard && /chart shows \\d+ of \\d+ brands/.test(chartCard.title),
          chartCard ? chartCard.title : 'no chart card');
    check(tab + '/metrics: the table card is not labelled as deviating',
          !!tableCard && !/chart shows/.test(tableCard.title),
          tableCard ? tableCard.title : 'no table card');
  }

  function runChartFocus(panel, tab) {
    // Scope first: only the leaves that genuinely have a table, a chart and
    // a chart-only visibility map behind them carry a mount.
    panel.querySelectorAll('.br-subpanel').forEach(function (host) {
      var leaf = host.getAttribute('data-leaf');
      if (!NO_CHART_FOCUS[leaf]) return;
      check(tab + '/' + leaf + ': carries no Chart brands control',
            host.querySelectorAll('.br-cf').length === 0,
            String(host.querySelectorAll('.br-cf').length));
    });

    var mounts = panel.querySelectorAll('.br-cf[data-chartfocus]');
    check(tab + ': Chart brands controls are mounted', mounts.length > 0,
          String(mounts.length) + ' mounts');

    // Every mount built exactly one trigger, and the control census counts
    // them by name so they never read as strays. Visibility is counted per
    // mount below, once its host has been laid out: a control inside an
    // inactive destination or a collapsed drawer has no geometry to measure.
    var built = 0;
    Array.prototype.forEach.call(mounts, function (m) {
      if (m.querySelectorAll('.br-cf-trigger').length === 1) built++;
    });
    check(tab + ': one Chart brands trigger per mount, no more',
          built === mounts.length, built + ' of ' + mounts.length);
    var census = { mounts: mounts.length, built: built, visible: 0,
                   behindShowChart: 0 };
    out.chartFocus = census;

    // Open the header on all brands so there is something to narrow from.
    panel.querySelector('.br-cmp-mode[data-cmp-set="all"]').click();

    Array.prototype.forEach.call(mounts, function (mount) {
      var scope = mount.getAttribute('data-chartfocus');
      var host = mount.closest('.br-subpanel');
      if (host) exposeHost(panel, host);
      var handle = chartFocusHandle(mount);
      check(tab + '/' + scope + ': the control reaches a split-mode handle',
            !!handle && typeof handle.setHiddenChart === 'function');
      if (!handle) return;

      var note = mount.parentElement.querySelector(
        '.br-cf-note[data-chartfocus-note="' + scope + '"]');
      var trigger = mount.querySelector('.br-cf-trigger');
      var label = trigger ? trigger.querySelector('.br-cf-label') : null;

      // Discoverability. The control has to be on screen beside the chart it
      // governs, not folded into a menu. Two chart areas ship collapsed
      // behind their panel's own "Show chart" toggle; there the control
      // appears with the chart, which is right, because with no chart there
      // is nothing to deviate.
      var areaHidden = !!(mount.parentElement &&
                          mount.parentElement.hasAttribute('hidden'));
      if (areaHidden) census.behindShowChart++;
      else if (visible(trigger)) census.visible++;
      check(tab + '/' + scope + ': the control is on screen beside its chart',
            areaHidden || visible(trigger),
            areaHidden ? 'chart area collapsed by Show chart'
                       : (visible(trigger) ? 'on screen' : 'NOT on screen'));

      // State one: no deviation.
      check(tab + '/' + scope + ': opens matching its table',
            !!note && note.hidden === true &&
            !!label && label.textContent === 'Chart brands: same as table',
            label ? label.textContent : 'no label');

      var tableBefore = setToSorted(handle.getHidden());

      // Deviate: untick the first brand the control offers that is not the
      // focal brand. The focal brand's box is locked on, because a chart
      // without it is a category chart.
      trigger.click();
      var pop = mount.querySelector('.br-cf-pop');
      check(tab + '/' + scope + ': the popover opens', !!pop && !pop.hidden);
      // Open in the DOM is not open on screen. An ancestor with overflow
      // would leave the control reachable and unusable, so the popover is
      // measured, not just read.
      // Only where the chart area is on screen. The two areas that ship
      // collapsed behind their panel's own "Show chart" toggle have no
      // geometry to measure, and no chart to deviate either.
      if (pop && !areaHidden) {
        var pr = pop.getBoundingClientRect();
        var hr = (host || mount.parentElement).getBoundingClientRect();
        check(tab + '/' + scope + ': the popover has real geometry',
              pr.width > 60 && pr.height > 40,
              Math.round(pr.width) + 'x' + Math.round(pr.height));
        check(tab + '/' + scope + ': the popover is not clipped away',
              pr.top >= hr.top - 4 && pr.left >= hr.left - 4 &&
              pr.right > pr.left,
              'pop ' + Math.round(pr.top) + ',' + Math.round(pr.left) +
              ' host ' + Math.round(hr.top) + ',' + Math.round(hr.left));
      }
      var boxes = mount.querySelectorAll('.br-cf-check');
      var locked = 0, lockedValue = null;
      Array.prototype.forEach.call(boxes, function (b) {
        if (b.disabled) { locked++; lockedValue = b.value; }
      });
      check(tab + '/' + scope + ': the focal brand cannot be dropped',
            locked === 1, locked + ' locked of ' + boxes.length);
      // And the locked one is the brand the header calls focal, so the lock
      // follows a focal change rather than sticking to whoever was first.
      var headerFocal = panel.querySelector('.br-focal-select');
      check(tab + '/' + scope + ': the locked brand is the header focal',
            !!headerFocal && lockedValue === headerFocal.value,
            lockedValue + ' vs ' + (headerFocal ? headerFocal.value : 'none'));
      // The popover offers exactly what the header shows, never more, so it
      // can only narrow.
      var offered = boxes.length;
      var headerShows = handle.getBrands().length - handle.getHidden().size;
      check(tab + '/' + scope + ': it offers only what the header shows',
            offered === headerShows, offered + ' offered, ' + headerShows + ' shown');

      // The two sites added after the first pass do not key their chart on
      // data-cb-brand, so they are read apart their own way: the Brand
      // Attitude bars carry data-fn-brand like their table rows, and the
      // Mental Space bubbles carry nothing, so they are counted.
      var relChartBefore = host ? codesInAttr(host.querySelectorAll(
        '[data-fn-rel-chart] [data-fn-brand]'), 'data-fn-brand') : [];
      var scatterBefore = host
        ? host.querySelectorAll('.ma-scatter-svg circle').length : 0;
      var barsBefore = host
        ? host.querySelectorAll('.ma-bars-svg rect').length : 0;

      var dropped = null;
      Array.prototype.forEach.call(boxes, function (b) {
        if (dropped || b.disabled) return;
        dropped = b.value;
        b.checked = false;
        b.dispatchEvent(new Event('change', { bubbles: true }));
      });
      if (!dropped) return;

      if (scope === 'relationship' && relChartBefore.length > 0) {
        var relChartAfter = codesInAttr(host.querySelectorAll(
          '[data-fn-rel-chart] [data-fn-brand]'), 'data-fn-brand');
        var relTableAfter = codesInAttr(Array.prototype.filter.call(
          host.querySelectorAll('[data-fn-rel-table] tbody tr[data-fn-brand]'),
          visible), 'data-fn-brand');
        check(tab + '/' + scope + ': the bars really drop the brand',
              relChartAfter.indexOf(dropped) < 0, relChartAfter.join(','));
        check(tab + '/' + scope + ': the table really keeps it',
              relTableAfter.indexOf(dropped) >= 0, relTableAfter.join(','));
        check(tab + '/' + scope + ': the chart has exactly one row fewer',
              relChartAfter.length === relTableAfter.length - 1,
              relChartAfter.length + ' chart, ' + relTableAfter.length + ' table');
      }
      if (scope === 'metrics' && scatterBefore > 0) {
        var scatterAfter = host.querySelectorAll('.ma-scatter-svg circle').length;
        var metricRows = Array.prototype.filter.call(
          host.querySelectorAll('.ma-metrics-table tbody tr.ma-row[data-ma-brand]'),
          visible).length;
        check(tab + '/' + scope + ': the Mental Space chart loses one bubble',
              scatterAfter === scatterBefore - 1,
              scatterBefore + ' to ' + scatterAfter);
        check(tab + '/' + scope + ': the metrics table keeps every row',
              metricRows === scatterBefore,
              metricRows + ' rows for ' + scatterBefore + ' bubbles before');
        if (barsBefore > 0) {
          check(tab + '/' + scope + ': the MMS bar chart loses its bars too',
                host.querySelectorAll('.ma-bars-svg rect').length
                  < barsBefore,
                barsBefore + ' bars before');
        }
      }

      // The table is untouched. This is the whole point of the control.
      check(tab + '/' + scope + ': the table set is unchanged',
            setToSorted(handle.getHidden()).join(',') === tableBefore.join(','),
            setToSorted(handle.getHidden()).join(','));
      // The chart set is the table set plus exactly the dropped brand.
      var wantChart = tableBefore.concat([dropped]).sort();
      check(tab + '/' + scope + ': the chart set is the table set minus one',
            setToSorted(handle.getHiddenChart()).join(',') === wantChart.join(','),
            setToSorted(handle.getHiddenChart()).join(','));

      // The deviation is marked, on the control and in a note that a
      // capture carries.
      check(tab + '/' + scope + ': the trigger names the deviation',
            !!label && /^Chart brands: \d+ of \d+$/.test(label.textContent) &&
            trigger.classList.contains('br-cf-on'),
            label ? label.textContent : 'no label');
      check(tab + '/' + scope + ': the note is shown and names what is missing',
            !!note && note.hidden === false &&
            note.textContent.indexOf('Hidden from the chart:') >= 0,
            note ? note.textContent : 'no note');
      var clause = window.brChartDeviationClause(host || mount.parentElement);
      check(tab + '/' + scope + ': a capture of the chart carries the clause',
            !!clause && window.brTitleWithChartDeviation('T', clause, true) !== 'T',
            clause);
      check(tab + '/' + scope + ': a capture without the chart does not',
            window.brTitleWithChartDeviation('T', clause, false) === 'T');

      // Where the chart and the table both key on brand codes, read them
      // apart rather than trusting the state object.
      var chartRows = host ? host.querySelectorAll(
        '.fn-rel-chart [data-cb-brand]') : [];
      var tableRows = host ? host.querySelectorAll(
        '.cb-rel-table tbody tr[data-cb-brand]') : [];
      if (chartRows.length > 0 && tableRows.length > 0) {
        var chartCodes = codesIn(chartRows);
        var tableCodes = codesIn(Array.prototype.filter.call(
          tableRows, function (tr) { return visible(tr); }));
        check(tab + '/' + scope + ': the chart really drops the brand',
              chartCodes.indexOf(dropped) < 0, chartCodes.join(','));
        check(tab + '/' + scope + ': the table really keeps it',
              tableCodes.indexOf(dropped) >= 0, tableCodes.join(','));
        check(tab + '/' + scope + ': chart equals table minus the one brand',
              chartCodes.length === tableCodes.length - 1,
              chartCodes.length + ' chart, ' + tableCodes.length + ' table');
      }

      // The capture claim, executed rather than reasoned about. The panels
      // clone their chart area with capturePortableHtml and then run
      // brStripInteractive over it. The note has to come through that and
      // the control has to be removed by it.
      var area = mount.parentElement;
      if (area && typeof TurasPins !== 'undefined' &&
          TurasPins.capturePortableHtml) {
        var captured = window.brStripInteractive(
          TurasPins.capturePortableHtml(area));
        check(tab + '/' + scope + ': the note survives a capture of the chart',
              captured.indexOf('Hidden from the chart:') >= 0,
              String(captured.length) + ' chars captured');
        check(tab + '/' + scope + ': the control does not survive it',
              captured.indexOf('br-cf-trigger') < 0 &&
              captured.indexOf('br-cf-check') < 0);
      }

      // The two pin paths added for the new sites, driven rather than read.
      // Each one is a real click through the panel's own pin dropdown, and
      // the card title is read back out of the TurasPins store, because the
      // clause is appended inside those handlers and nowhere the state
      // object would show it.
      if (scope === 'relationship') pinFunnelRelChart(panel, tab);
      if (scope === 'metrics')      pinMaMetricsChart(panel, tab);

      // The header is the source of truth: changing it clears the deviation.
      panel.querySelector('.br-cmp-mode[data-cmp-set="focal"]').click();
      check(tab + '/' + scope + ': a header change clears the deviation',
            note.hidden === true &&
            label.textContent === 'Chart brands: same as table' &&
            !trigger.classList.contains('br-cf-on'),
            label.textContent + ' note-hidden=' + note.hidden);
      check(tab + '/' + scope + ': and the chart set follows the table set',
            setToSorted(handle.getHiddenChart()).join(',') ===
            setToSorted(handle.getHidden()).join(','),
            setToSorted(handle.getHiddenChart()).join(','));

      // Back to all brands for the next mount.
      panel.querySelector('.br-cmp-mode[data-cmp-set="all"]').click();
    });

    panel.querySelector('.br-cmp-mode[data-cmp-set="focal"]').click();
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
      // Four. There were five: an Overview came first and held a card
      // telling the reader the headline picture was on the Summary tab, so
      // clicking a category landed on a page whose message was to go
      // somewhere else. It is dropped, and the reader lands on the first
      // destination that has analysis in it.
      check(tab + ': four destination buttons', btns.length === 4,
            String(btns.length));
      check(tab + ': and the first one is active on load',
            btns[0].classList.contains('active'),
            btns[0].getAttribute('data-destination'));
      check(tab + ': no Overview destination remains',
            !panel.querySelector('[data-destination="overview"]') &&
            !panel.querySelector('.br-overview-stub'));

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
        var adv = cont ? cont.querySelectorAll('.br-adv-item').length : 0;
        check(tab + '/' + id + ': destination is not empty',
              (hosts + adv) > 0,
              'hosts=' + hosts + ' advanced=' + adv);
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
                                advanced: adv });
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

        // The trigger must read as a control in every state, so the word
        // "Brands" is on it whatever is picked. Duncan read the old
        // "Focal only" and reported the selector missing.
        var N = allBrands.length;
        var bar = panel.querySelector('.br-controls');

        // State one, as the report opens.
        check(tab + ': opens on the state its config asked for',
              textEl.textContent === 'Brands: focal only' ||
              textEl.textContent === 'Brands: all ' + N, textEl.textContent);
        if (textEl.textContent === 'Brands: focal only') {
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
              textEl.textContent === 'Brands: focal + 3', textEl.textContent);
        check(tab + ': and its title spells the state out in words',
              trigger.title === 'Showing the focal brand and 3 comparators, of ' +
              N + ' brands in this category', trigger.title);
        check(tab + ': the count says how many of the category are shown',
              badge.textContent === '4/' + N && !badge.hidden,
              badge.textContent);
        checkBrandSet(panel, tab, 'compare with 3', [focal].concat(picked), allBrands);

        // No cap. The old control stopped at five by setting the sixth box
        // back to unchecked, so a reader watched a tick reverse under their
        // finger with no message. Every box is ticked here and every one
        // must stay ticked, with the published set and the visible rows
        // agreeing with the words on the trigger.
        var all = [];
        var reversed = [];
        Array.prototype.forEach.call(checks, function (c) {
          if (c.disabled) { all.push(c.value); return; }
          if (!c.checked) {
            c.checked = true;
            c.dispatchEvent(new Event('change', { bubbles: true }));
          }
          if (!c.checked) reversed.push(c.value);
          all.push(c.value);
        });
        check(tab + ': no tick is reversed, whatever the count',
              reversed.length === 0, reversed.join(',') || 'none reversed');
        check(tab + ': every brand in the category can be a comparator',
              all.length === N && sameSet(all, allBrands),
              all.length + ' of ' + N);
        check(tab + ': the trigger counts every comparator',
              textEl.textContent === 'Brands: focal + ' + (N - 1),
              textEl.textContent);
        check(tab + ': the count reaches the whole category',
              badge.textContent === N + '/' + N, badge.textContent);
        // Ticking every box is still "compare", not the all-brands mode:
        // the two are different claims and only the mode publishes a
        // category-wide view. The rows must agree either way.
        check(tab + ': ticking every box does not silently become all-brands mode',
              pop.getAttribute('data-cmp-mode') === 'compare',
              pop.getAttribute('data-cmp-mode'));
        checkBrandSet(panel, tab, 'every brand ticked', allBrands, allBrands);
        // And the widest state must not push the control bar taller. The two
        // measurements are taken back to back with only the trigger's text
        // differing, so the comparison isolates the label. Measuring the
        // opening state minutes earlier would fold in every scrollbar and
        // destination change in between, which at the harness viewport of
        // 800 pixels is enough on its own to tip the flex row onto a second
        // line whatever the label says.
        var widest = bar ? bar.getBoundingClientRect().height : 0;
        var wideText = textEl.textContent;
        textEl.textContent = 'Brands: focal only';
        var narrowest = bar ? bar.getBoundingClientRect().height : 0;
        textEl.textContent = wideText;
        check(tab + ': the control bar is laid out, so its height means something',
              narrowest > 0, String(narrowest));
        check(tab + ': the widest trigger text does not reflow the control bar',
              widest === narrowest,
              wideText + ' -> ' + widest + ', narrowest -> ' + narrowest +
              ', viewport ' + window.innerWidth);

        // State three: all brands.
        panel.querySelector('.br-cmp-mode[data-cmp-set="all"]').click();
        check(tab + ': the trigger names the all-brands state',
              textEl.textContent === 'Brands: all ' + N, textEl.textContent);
        check(tab + ': the count badge is not shown in the all-brands state',
              badge.hidden === true);
        checkBrandSet(panel, tab, 'all brands', allBrands, allBrands);

        // Back to state one, by name rather than by clearing.
        panel.querySelector('.br-cmp-mode[data-cmp-set="focal"]').click();
        check(tab + ': the trigger returns to the focal-only state',
              textEl.textContent === 'Brands: focal only', textEl.textContent);
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


      // --- Chart brands: the per-chart deviation from the header set ---
      // Stage 2 removed the split-mode brand filter, and with it the one way
      // an analyst had of hiding a brand from a chart while keeping it in
      // the table. These checks prove it is back, that it can only narrow,
      // that a deviating chart says so on its face, and that a header change
      // clears it.
      runChartFocus(panel, tab);

      // --- the route into the Summary tab, now in the controls bar ---
      // It used to be the Overview destination's only content. The route
      // itself had to survive the drop: the top-level Summary button does
      // not carry the category across, and brOpenSummaryFor() does.
      var sumBtn = panel.querySelector('.br-cat-summary-link');
      check(tab + ': the controls bar carries a route to the Summary tab',
            !!sumBtn);
      if (sumBtn) {
        var catLabel = panel.querySelector('.br-cat-select');
        var want = catLabel
          ? catLabel.options[catLabel.selectedIndex].textContent.trim()
          : (panel.querySelector('.br-control-static') || {}).textContent;
        sumBtn.click();
        var summary = document.getElementById('panel-summary');
        check(tab + ': the route opens the Summary tab',
              summary && summary.classList.contains('active'));
        var catSel = document.querySelector('[data-brsum-cat]');
        check(tab + ': the route selects this category',
              catSel && catSel.value === String(want || '').trim(),
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
    # A width a report is actually read at. Chrome headless defaults to 800,
    # where the header control bar is already on two lines whatever the
    # trigger says, which would leave the reflow check unable to fail.
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
        print("  %s %s%s" % (mark, c["name"], (" -> " + c["detail"]) if c["detail"] else ""))
    cf = res.get("chartFocus")
    if cf:
        print("\nChart brands controls: %d mounted, %d built, %d visible "
              "beside their chart, %d behind a Show chart toggle"
              % (cf["mounts"], cf["built"], cf["visible"],
                 cf["behindShowChart"]))
    print("\nDestinations reached: %d" % len(res["destinations"]))
    for d in res["destinations"]:
        print("  %s / %-9s hosts=%d advanced=%d"
              % (d["tab"], d["id"], d["hosts"], d["advanced"]))
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
