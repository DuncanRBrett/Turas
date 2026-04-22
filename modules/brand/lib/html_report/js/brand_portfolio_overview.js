// ==============================================================================
// BRAND MODULE - PORTFOLIO OVERVIEW INTERACTIVITY
// ==============================================================================
// Client-side rerender of the Overview subtab when the focal brand picker
// changes. The R renderer emits a JSON blob at #pf-overview-data; this module
// swaps the hero KPIs, ranked bar chart, summary table, and deep-dive cards
// for the newly selected focal brand without a round-trip.
// ==============================================================================

(function () {
  'use strict';

  function ready(fn) {
    if (document.readyState !== 'loading') { fn(); return; }
    document.addEventListener('DOMContentLoaded', fn);
  }

  function parseData() {
    var el = document.getElementById('pf-overview-data');
    if (!el) return null;
    try { return JSON.parse(el.textContent || '{}'); }
    catch (e) { console.warn('[pfo] Failed to parse overview JSON:', e); return null; }
  }

  function esc(s) {
    if (s === null || s === undefined) return '';
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
  function fmtPct(v) {
    if (v === null || v === undefined || isNaN(v)) return '\u2014';
    return Math.round(v) + '%';
  }
  function fmtNum(v, d) {
    if (v === null || v === undefined || isNaN(v)) return '\u2014';
    return Number(v).toFixed(d == null ? 1 : d);
  }

  // ---- Hero KPIs ----
  function renderHero(payload, focalCode, focalColour) {
    var cats = payload.categories || {};
    var catKeys = Object.keys(cats);
    var nTotal = catKeys.length;
    var awareVals = [];
    var nDeep = 0;
    catKeys.forEach(function (k) {
      var c = cats[k];
      var v = (c.awareness_pct || {})[focalCode];
      if (v != null && !isNaN(v) && v > 0) awareVals.push(v);
      if (c.analysis_depth === 'full') nDeep++;
    });
    var avg = awareVals.length
      ? awareVals.reduce(function (a, b) { return a + b; }, 0) / awareVals.length
      : null;

    function card(value, label) {
      return '<div class="pf-kpi-card"><div class="pf-kpi-value">' +
        esc(value) + '</div><div class="pf-kpi-label">' + esc(label) + '</div></div>';
    }

    return '<div class="pf-hero-strip">' +
      card(awareVals.length + ' of ' + nTotal,
           'Categories where ' + focalCode + ' has awareness') +
      card(fmtPct(avg), 'Average awareness across categories with presence') +
      card(String(nDeep), 'Deep-dive categories in the study') +
      card(String(nTotal), 'Total categories tracked') +
      '</div>';
  }

  // ---- Ranked bar chart ----
  function renderChart(payload, focalCode, focalColour) {
    var cats = payload.categories || {};
    var rows = Object.keys(cats).map(function (k) {
      var c = cats[k];
      var v = (c.awareness_pct || {})[focalCode];
      return {
        name: c.cat_name,
        depth: c.analysis_depth || 'awareness_only',
        val: (v == null || isNaN(v)) ? null : v
      };
    });
    if (rows.length === 0) {
      return '<p style="color:#94a3b8;padding:16px 0;">No awareness data to display.</p>';
    }
    rows.sort(function (a, b) {
      var av = a.val == null ? -1 : a.val, bv = b.val == null ? -1 : b.val;
      return bv - av;
    });
    var max = Math.max.apply(null, rows.map(function (r) {
      return r.val == null ? 0 : r.val;
    }));
    if (!isFinite(max) || max <= 0) max = 100;

    var bars = rows.map(function (r) {
      var pct = r.val == null ? 0 : (r.val / max) * 100;
      var badge = r.depth === 'full'
        ? '<span class="pfo-depth-badge pfo-depth-full">Deep-dive</span>'
        : '<span class="pfo-depth-badge pfo-depth-aware">Awareness</span>';
      return '<div class="pfo-bar-row">' +
        '<div class="pfo-bar-label">' + esc(r.name) + badge + '</div>' +
        '<div class="pfo-bar-track"><div class="pfo-bar-fill" style="width:' +
        pct.toFixed(1) + '%;background:' + esc(focalColour) + ';"></div></div>' +
        '<div class="pfo-bar-value">' + fmtPct(r.val) + '</div></div>';
    }).join('');

    return '<h3 class="pfo-section-title">Focal brand awareness ranked by category</h3>' +
      '<div class="pfo-bars">' + bars + '</div>';
  }

  // ---- Summary table ----
  function buildTableRow(c, focalCode) {
    var aware = c.awareness_pct || {};
    var focal = aware[focalCode];
    var vals = Object.keys(aware)
      .map(function (k) { return aware[k]; })
      .filter(function (v) { return v != null && !isNaN(v); });
    var rank = (focal == null || isNaN(focal))
      ? null
      : vals.filter(function (v) { return v > focal; }).length + 1;
    var leader = vals.length ? Math.max.apply(null, vals) : null;
    var gap = (focal != null && leader != null) ? leader - focal : null;

    var dd = (c.deep_dive || {})[focalCode] || null;
    return {
      name: c.cat_name,
      depth: c.analysis_depth || 'awareness_only',
      cat_usage: c.cat_usage_pct,
      focal: focal,
      rank: rank, n_brands: vals.length, gap: gap,
      pen: dd ? dd.penetration_pct : null,
      scr: dd ? dd.scr_pct : null,
      vol: dd ? dd.vol_share_pct : null,
      freq: dd ? dd.freq_mean : null
    };
  }

  function renderTable(payload, focalCode) {
    var cats = payload.categories || {};
    var rows = Object.keys(cats).map(function (k) {
      return buildTableRow(cats[k], focalCode);
    });
    if (rows.length === 0) return '';
    rows.sort(function (a, b) {
      var av = a.focal == null ? -1 : a.focal;
      var bv = b.focal == null ? -1 : b.focal;
      return bv - av;
    });

    var head = '<thead><tr>' +
      '<th class="pfo-th-cat">Category</th>' +
      '<th class="pfo-th-depth">Type</th>' +
      '<th class="pfo-th-num">Cat. usage</th>' +
      '<th class="pfo-th-num">Focal awareness</th>' +
      '<th class="pfo-th-num">Rank</th>' +
      '<th class="pfo-th-num">Gap to leader</th>' +
      '<th class="pfo-th-num">Penetration</th>' +
      '<th class="pfo-th-num">SCR</th>' +
      '<th class="pfo-th-num">Vol share</th>' +
      '<th class="pfo-th-num">Freq</th></tr></thead>';

    var body = rows.map(function (r) {
      var pill = r.depth === 'full'
        ? '<span class="pfo-pill pfo-pill-deep">Deep-dive</span>'
        : '<span class="pfo-pill pfo-pill-aware">Awareness</span>';
      var rankTxt = r.rank == null ? '\u2014' : '#' + r.rank + ' of ' + r.n_brands;
      var gapTxt = r.gap == null ? '\u2014'
        : (r.gap <= 0.5 ? '<span class="pfo-gap-leader">Leader</span>' :
           '\u2212' + Math.round(r.gap) + ' pp');
      function tdNum(v, fmt) {
        var na = (v == null || isNaN(v)) ? ' pfo-td-na' : '';
        return '<td class="pfo-td-num' + na + '">' + fmt(v) + '</td>';
      }
      return '<tr>' +
        '<td class="pfo-td-cat">' + esc(r.name) + '</td>' +
        '<td>' + pill + '</td>' +
        '<td class="pfo-td-num">' + fmtPct(r.cat_usage) + '</td>' +
        '<td class="pfo-td-num pfo-td-focal">' + fmtPct(r.focal) + '</td>' +
        '<td class="pfo-td-num">' + rankTxt + '</td>' +
        '<td class="pfo-td-num">' + gapTxt + '</td>' +
        tdNum(r.pen, fmtPct) + tdNum(r.scr, fmtPct) +
        tdNum(r.vol, fmtPct) + tdNum(r.freq, function (v) { return fmtNum(v, 1); }) +
        '</tr>';
    }).join('');

    return '<h3 class="pfo-section-title">Category detail</h3>' +
      '<div class="pfo-table-scroll"><table class="pfo-table">' +
      head + '<tbody>' + body + '</tbody></table></div>' +
      '<p class="pfo-table-note">Rank = focal brand\u2019s position on awareness within the category. ' +
      'Gap = pct-point distance from the category leader. ' +
      'Penetration/SCR/Vol/Freq available for deep-dive categories only.</p>';
  }

  // ---- Deep-dive strip ----
  function renderDeepStrip(payload, focalCode) {
    var cats = payload.categories || {};
    var deepKeys = Object.keys(cats).filter(function (k) {
      return cats[k].analysis_depth === 'full' && cats[k].deep_dive;
    });
    if (deepKeys.length === 0) return '';

    var cards = deepKeys.map(function (k) {
      var c = cats[k];
      var dd = c.deep_dive || {};
      var focal = dd[focalCode] || {};
      var rows = (c.brand_codes || []).map(function (bc) {
        var d = dd[bc]; if (!d) return null;
        return {
          code: bc, name: (c.brand_names || {})[bc] || bc,
          pen: d.penetration_pct, scr: d.scr_pct,
          isFocal: bc === focalCode
        };
      }).filter(Boolean)
        .sort(function (a, b) {
          return (b.scr == null ? -1 : b.scr) - (a.scr == null ? -1 : a.scr);
        }).slice(0, 5);

      var rankBody = rows.map(function (r, i) {
        var cls = r.isFocal ? ' class="pfo-deep-focal"' : '';
        return '<tr' + cls + '><td>#' + (i + 1) + ' ' + esc(r.name) + '</td>' +
          '<td class="pfo-td-num">' + fmtPct(r.scr) + '</td>' +
          '<td class="pfo-td-num">' + fmtPct(r.pen) + '</td></tr>';
      }).join('');

      var focalIdx = rows.findIndex(function (r) { return r.isFocal; });
      var focalRankTxt = focalIdx >= 0 ? '#' + (focalIdx + 1) : 'Not top 5';

      return '<div class="pfo-deep-card">' +
        '<div class="pfo-deep-card-head">' +
        '<span class="pfo-deep-card-title">' + esc(c.cat_name) + '</span>' +
        '<span class="pfo-deep-card-rank">Focal: ' + esc(focalRankTxt) + ' by SCR</span></div>' +
        '<div class="pfo-deep-card-kpis">' +
        '<div><span class="pfo-kpi-mini-v">' + fmtPct(focal.scr_pct) + '</span>' +
        '<span class="pfo-kpi-mini-l">SCR</span></div>' +
        '<div><span class="pfo-kpi-mini-v">' + fmtPct(focal.penetration_pct) + '</span>' +
        '<span class="pfo-kpi-mini-l">Penetration</span></div>' +
        '<div><span class="pfo-kpi-mini-v">' + fmtPct(focal.vol_share_pct) + '</span>' +
        '<span class="pfo-kpi-mini-l">Vol share</span></div></div>' +
        '<table class="pfo-deep-rank"><tbody>' + rankBody + '</tbody></table></div>';
    }).join('');

    return '<h3 class="pfo-section-title">Deep-dive competitive context</h3>' +
      '<div class="pfo-deep-grid">' + cards + '</div>';
  }

  // ---- Picker binding + orchestration ----
  function swap(focalCode) {
    var payload = parseData();
    if (!payload) return;
    var colour = payload.focal_colour || '#1A5276';

    var h = document.getElementById('pfo-hero');
    var c = document.getElementById('pfo-chart');
    var t = document.getElementById('pfo-table');
    var d = document.getElementById('pfo-deep');
    if (h) h.innerHTML = renderHero(payload, focalCode, colour);
    if (c) c.innerHTML = renderChart(payload, focalCode, colour);
    if (t) t.innerHTML = renderTable(payload, focalCode);
    if (d) d.innerHTML = renderDeepStrip(payload, focalCode);

    var sel = document.getElementById('pfo-focal-select');
    if (sel && sel.value !== focalCode) sel.value = focalCode;

    if (typeof brSetPinState === 'function') {
      brSetPinState('pf_overview_focal', focalCode);
    }
  }

  ready(function () {
    var sel = document.getElementById('pfo-focal-select');
    if (!sel) return;
    sel.addEventListener('change', function (e) {
      var code = e.target.value;
      if (code) swap(code);
    });
  });

  // Expose for pin-state restore hooks
  window.pfoSwitchFocal = swap;
})();
