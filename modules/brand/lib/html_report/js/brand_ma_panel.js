/* ==========================================================================
   Brand Mental Availability Panel — interactivity
   ==========================================================================
   Features:
   - Sub-tab switch (Attributes / CEPs / Metrics)
   - Focal brand change, persisted across panels via a CustomEvent on window
   - Brand chips (toggle visibility), chip colouring from brand palette
   - Heatmap modes: CI bands (default) / diverging vs cat avg / off
   - Base mode: % total / % aware (both stim tabs)
   - Row grey-out toggle (checkbox on row label) — greyed rows dim in table
     and drop out of the bar chart
   - Show chart toggle + inline SVG bar chart (one bar per visible brand,
     grouped per active attribute/CEP, bars coloured to match chips)
   - Column sort
   - Client-side .xls export
   - Pin dropdown → window.TurasPin.pin()
   - Full-width editable insight box (persists in sessionStorage)
   ========================================================================== */

(function () {
  if (window.__BRAND_MA_PANEL_INIT__) return;
  window.__BRAND_MA_PANEL_INIT__ = true;

  var FOCAL_EVENT = 'turas:brand-focal-change';
  var FOCAL_STORAGE_KEY = 'turas.brand.focal';

  function onReady(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  // -------------------------------------------------------------- helpers
  function escAttr(s) {
    if (s == null) return '';
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;')
      .replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function escHtml(s) { return escAttr(s); }

  function readPayload(panel) {
    var el = panel.querySelector('script.ma-panel-data');
    if (!el) return null;
    try { return JSON.parse(el.textContent || '{}'); }
    catch (e) { return null; }
  }

  function hexToRgba(hex, alpha) {
    if (!hex) return 'rgba(100,116,139,' + alpha + ')';
    if (hex[0] === '#') hex = hex.slice(1);
    if (hex.length === 3) hex = hex.split('').map(function (c) { return c + c; }).join('');
    if (hex.length < 6) return 'rgba(100,116,139,' + alpha + ')';
    var r = parseInt(hex.slice(0, 2), 16);
    var g = parseInt(hex.slice(2, 4), 16);
    var b = parseInt(hex.slice(4, 6), 16);
    return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
  }

  var BRAND_PALETTE = ['#4e79a7','#f28e2b','#e15759','#76b7b2','#59a14f',
                       '#edc948','#b07aa1','#ff9da7','#9c755f','#bab0ac'];

  function stableBrandIdx(code) {
    var h = 5381;
    for (var i = 0; i < code.length; i++) h = ((h << 5) + h + code.charCodeAt(i)) & 0x7fffffff;
    return h % BRAND_PALETTE.length;
  }

  function getBrandColour(pd, code) {
    if (!code) return '#94a3b8';
    if (pd.config && pd.config.brand_colours && pd.config.brand_colours[code])
      return pd.config.brand_colours[code];
    if (code === (pd.meta && pd.meta.focal_brand_code))
      return pd.config.focal_colour || pd.focal_colour || '#1A5276';
    return BRAND_PALETTE[stableBrandIdx(code)];
  }

  function getBrandName(pd, code) {
    var codes = (pd.config && pd.config.brand_codes) || [];
    var names = (pd.config && pd.config.brand_names) || [];
    var idx = codes.indexOf(code);
    return idx < 0 ? code : (names[idx] || code);
  }

  // -------------------------------------------------------------- init
  onReady(function () {
    document.querySelectorAll('.ma-panel').forEach(function (panel) {
      initPanel(panel);
    });

    // Cross-panel focal sync: listen for the custom event, update this
    // panel's focal when a sibling (funnel/other MA) changes. Also
    // updates any funnel panel in the same category.
    window.addEventListener(FOCAL_EVENT, function (ev) {
      var d = ev.detail || {};
      if (!d.code) return;

      // Update MA panels
      document.querySelectorAll('.ma-panel').forEach(function (panel) {
        var pd = panel.__maData;
        if (!pd) return;
        if (d.category != null && pd.meta && pd.meta.category_label &&
            String(d.category) !== String(pd.meta.category_label)) return;
        if (d.source === panel) return;
        var sel = panel.querySelector('.ma-focus-select');
        if (sel && sel.value !== d.code) sel.value = d.code;
        setFocal(panel, d.code, { silent: true });
      });

      // Update funnel panels (dispatch a change on their select)
      document.querySelectorAll('.fn-panel').forEach(function (fnPanel) {
        if (d.source === fnPanel) return;
        var fnPd = fnPanel.__fnData;
        if (fnPd && fnPd.meta && fnPd.meta.category_label &&
            d.category != null &&
            String(d.category) !== String(fnPd.meta.category_label)) return;
        var fnSel = fnPanel.querySelector('.fn-focus-select');
        if (!fnSel) return;
        // Only trigger if a matching option exists
        var hasOpt = Array.from(fnSel.options || []).some(function (o) { return o.value === d.code; });
        if (!hasOpt) return;
        if (fnSel.value !== d.code) {
          fnSel.value = d.code;
          // Suppress re-emit by marking this change as coming from cross-panel
          fnSel.__maSuppress = true;
          fnSel.dispatchEvent(new Event('change'));
          fnSel.__maSuppress = false;
        }
      });
    });

    // Also patch the funnel panel's focal selector (if present) to emit
    // the same event, so MA picks it up when the user changes focal on
    // the funnel side.
    document.querySelectorAll('.fn-panel .fn-focus-select').forEach(function (sel) {
      var fnPanel = sel.closest('.fn-panel');
      sel.addEventListener('change', function () {
        if (sel.__maSuppress) return;  // change came from MA, don't re-emit
        var pd = fnPanel && fnPanel.__fnData;
        var cat = pd && pd.meta && pd.meta.category_label;
        window.dispatchEvent(new CustomEvent(FOCAL_EVENT, {
          detail: { category: cat || null, code: sel.value, source: fnPanel }
        }));
      });
    });

    // Restore last focal from sessionStorage if any
    try {
      var stored = JSON.parse(sessionStorage.getItem(FOCAL_STORAGE_KEY) || '{}');
      Object.keys(stored).forEach(function (cat) {
        window.dispatchEvent(new CustomEvent(FOCAL_EVENT, {
          detail: { category: cat, code: stored[cat], source: null }
        }));
      });
    } catch (e) { /* ignore */ }
  });

  function initPanel(panel) {
    var pd = readPayload(panel);
    if (!pd) return;
    panel.__maData = pd;

    var brandCodes = (pd.config && pd.config.brand_codes) || [];

    var makeVisMap = function () {
      var m = {};
      brandCodes.forEach(function (c) { m[c] = true; });
      m.__avg__ = true;
      return m;
    };
    var makeRowMap = function (codes) {
      var m = {};
      (codes || []).forEach(function (c) { m[c] = true; });
      return m;
    };
    var attrCodes = (pd.attributes && pd.attributes.codes) || [];
    var cepCodes  = (pd.ceps       && pd.ceps.codes)       || [];

    panel.__maState = {
      focal: (pd.meta && pd.meta.focal_brand_code) || brandCodes[0] || null,
      basemode:     { attributes: 'total', ceps: 'total' },
      heatmap:      { attributes: 'ci',    ceps: 'ci' },
      counts:       { attributes: false,   ceps: false },
      showchart:    { attributes: true,    ceps: true },
      visible:      { attributes: makeVisMap(), ceps: makeVisMap() },
      chartVisible: { attributes: makeVisMap(), ceps: makeVisMap() },
      rowActive:    { attributes: makeRowMap(attrCodes), ceps: makeRowMap(cepCodes) },
      sort:         { attributes: { col: null, dir: 'none' },
                      ceps:       { col: null, dir: 'none' } }
    };

    colourChips(panel);

    bindSubTabs(panel);
    bindFocusSelect(panel);
    bindChipPicker(panel);
    bindChartChips(panel);
    bindToggles(panel);
    bindBaseMode(panel);
    bindHeatmapMode(panel);
    bindSortButtons(panel);
    bindMetricsSortButtons(panel);
    bindMetricsChips(panel);
    bindMetricsShowCounts(panel);
    bindChartSelectMenu(panel);
    bindExport(panel);
    bindPinDropdown(panel);
    bindAddInsight(panel);
    bindRowActiveCheckboxes(panel);
    bindInsightBoxPersistence(panel);

    // Stamp rows with their original index for stable "reset" sort
    panel.querySelectorAll('.ma-matrix-section tbody tr.ma-row').forEach(function (r, i) {
      r.setAttribute('data-ma-orig-idx', i);
    });

    // Initial render
    applyHeatmapMode(panel, 'attributes');
    applyHeatmapMode(panel, 'ceps');
    applyBaseMode(panel, 'attributes');
    applyBaseMode(panel, 'ceps');
    applyShowCounts(panel, 'attributes');
    applyShowCounts(panel, 'ceps');
    renderChart(panel, 'attributes');
    renderChart(panel, 'ceps');
    repositionMetricsPinnedRows(panel);
    renderMAScatter(panel);
    renderMABarChart(panel);
    if (window.MAAdvantage && typeof window.MAAdvantage.init === 'function') {
      try { window.MAAdvantage.init(panel); } catch (e) { /* non-fatal */ }
    }

    // Re-render when the MA panel (or its chart sections) become visible
    // after starting in display:none (e.g. the parent tab wasn't active
    // at init-time). Uses an IntersectionObserver for efficiency; falls
    // back to a one-shot MutationObserver on the br-tab state.
    if (typeof IntersectionObserver !== 'undefined') {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (!e.isIntersecting || e.target.clientWidth <= 0) return;
          if (e.target.classList.contains('ma-scatter-wrap')) {
            renderMAScatter(panel); return;
          }
          if (e.target.classList.contains('ma-bars-wrap')) {
            renderMABarChart(panel); return;
          }
          var stim = e.target.getAttribute('data-ma-stim');
          if (stim) renderChart(panel, stim);
        });
      }, { root: null, threshold: 0.01 });
      panel.querySelectorAll('.ma-chart-section').forEach(function (s) {
        io.observe(s);
      });
      var scatterWrap = panel.querySelector('.ma-scatter-wrap');
      var barsWrap    = panel.querySelector('.ma-bars-wrap');
      if (scatterWrap) io.observe(scatterWrap);
      if (barsWrap)    io.observe(barsWrap);
    }

    // Restore focal from sessionStorage if present for this category
    try {
      var stored = JSON.parse(sessionStorage.getItem(FOCAL_STORAGE_KEY) || '{}');
      var cat = pd.meta && pd.meta.category_label;
      if (cat && stored[cat] && stored[cat] !== panel.__maState.focal) {
        var sel = panel.querySelector('.ma-focus-select');
        if (sel) sel.value = stored[cat];
        setFocal(panel, stored[cat], { silent: true });
      }
    } catch (e) { /* ignore */ }
  }

  function colourChips(panel) {
    var pd = panel.__maData;
    var focal = panel.__maState.focal;
    panel.querySelectorAll('.col-chip[data-ma-brand]').forEach(function (chip) {
      var code = chip.getAttribute('data-ma-brand');
      var col  = code === '__avg__' ? '#64748b' : getBrandColour(pd, code);
      chip.style.setProperty('--brand-chip-color', col);
      chip.style.backgroundColor = col;
      chip.style.borderColor = col;
      chip.style.color = '#fff';
      chip.style.fontWeight = code === focal ? '700' : '500';
    });
  }

  // -------------------------------------------------------------- sub-tabs
  function bindSubTabs(panel) {
    panel.querySelectorAll('.ma-subtab-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var target = btn.getAttribute('data-ma-subtab-target');
        panel.querySelectorAll('.ma-subtab-btn').forEach(function (b) {
          var active = b === btn;
          b.classList.toggle('active', active);
          b.setAttribute('aria-selected', active ? 'true' : 'false');
        });
        panel.querySelectorAll('.ma-subtab').forEach(function (sp) {
          var show = sp.getAttribute('data-ma-subtab') === target;
          if (show) sp.removeAttribute('hidden');
          else      sp.setAttribute('hidden', '');
        });
        // Re-render chart when tab becomes visible (in case it was
        // built while hidden and has wrong dimensions)
        // Toggle a panel class so CSS can hide the panel-wide
        // Mental Availability drawer when on the advantage tab
        // (Duncan: "remove the mental availability call out" on advantage).
        panel.classList.toggle('ma-active-advantage', target === 'advantage');
        if (target === 'attributes' || target === 'ceps') {
          renderChart(panel, target);
        } else if (target === 'metrics') {
          renderMAScatter(panel);
          renderMABarChart(panel);
        } else if (target === 'advantage' && window.MAAdvantage) {
          try { window.MAAdvantage.render(panel); } catch (e) { /* non-fatal */ }
        }
      });
    });
  }

  // -------------------------------------------------------------- focal
  function bindFocusSelect(panel) {
    var sel = panel.querySelector('.ma-focus-select');
    if (!sel) return;
    sel.addEventListener('change', function () {
      setFocal(panel, sel.value, { silent: false });
    });
  }

  function reorderFocalColumn(panel, focal) {
    panel.querySelectorAll('.ma-matrix-section').forEach(function (sec) {
      sec.querySelectorAll('table').forEach(function (table) {
        table.querySelectorAll('tr').forEach(function (row) {
          var labelCell = row.children[0];
          if (!labelCell) return;
          var focalCell = row.querySelector('[data-ma-brand="' + focal + '"]');
          var avgCell   = row.querySelector('[data-ma-brand="__avg__"]');
          if (!focalCell) return;
          row.insertBefore(focalCell, labelCell.nextSibling);
          if (avgCell) row.insertBefore(avgCell, focalCell.nextSibling);
        });
      });
    });
  }

  function setFocal(panel, code, opts) {
    opts = opts || {};
    if (!code) return;
    panel.__maState.focal = code;
    refreshFocalAccents(panel);
    reorderFocalColumn(panel, code);
    refreshMetricsFocal(panel);
    refreshMetricsHero(panel);
    colourChips(panel);
    renderChart(panel, 'attributes');
    renderChart(panel, 'ceps');
    renderMAScatter(panel);
    renderMABarChart(panel);
    if (window.MAAdvantage && typeof window.MAAdvantage.render === 'function') {
      try { window.MAAdvantage.render(panel); } catch (e) { /* non-fatal */ }
    }
    // Persist + broadcast
    try {
      var stored = JSON.parse(sessionStorage.getItem(FOCAL_STORAGE_KEY) || '{}');
      var cat = panel.__maData && panel.__maData.meta && panel.__maData.meta.category_label;
      if (cat) {
        stored[cat] = code;
        sessionStorage.setItem(FOCAL_STORAGE_KEY, JSON.stringify(stored));
      }
    } catch (e) { /* ignore */ }
    if (!opts.silent) {
      var cat = panel.__maData && panel.__maData.meta && panel.__maData.meta.category_label;
      window.dispatchEvent(new CustomEvent(FOCAL_EVENT, {
        detail: { category: cat || null, code: code, source: panel }
      }));
    }
  }

  function refreshFocalAccents(panel) {
    var focal = panel.__maState.focal;
    panel.querySelectorAll('.ma-ct-th-brand').forEach(function (th) {
      th.classList.toggle('ma-ct-th-focal',
        th.getAttribute('data-ma-brand') === focal);
      var existing = th.querySelector('.ma-focal-badge');
      if (existing) existing.remove();
      if (th.getAttribute('data-ma-brand') === focal) {
        var hdr = th.querySelector('.ct-header-text');
        if (hdr) {
          var b = document.createElement('span');
          b.className = 'ma-focal-badge';
          b.textContent = 'FOCAL';
          hdr.insertBefore(b, hdr.firstChild);
        }
      }
    });
    panel.querySelectorAll('.ma-ct-table td[data-ma-brand]').forEach(function (td) {
      td.classList.toggle('ma-td-focal',
        td.getAttribute('data-ma-brand') === focal);
    });
    panel.querySelectorAll('.ma-metrics-table tr').forEach(function (tr) {
      var code = tr.getAttribute('data-ma-brand');
      tr.classList.toggle('ma-row-focal', code && code === focal);
    });
  }

  // -------------------------------------------------------------- chips
  function bindChartChips(panel) {
    panel.querySelectorAll('.chart-chip[data-ma-chart-scope]').forEach(function (chip) {
      chip.addEventListener('click', function () {
        var scope = chip.getAttribute('data-ma-chart-scope');
        var code  = chip.getAttribute('data-ma-brand');
        var vis = panel.__maState.chartVisible[scope];
        if (!vis) return;
        vis[code] = !vis[code];
        chip.classList.toggle('col-chip-off', !vis[code]);
        renderChart(panel, scope);
      });
    });
  }

  function bindChipPicker(panel) {
    panel.querySelectorAll('.col-chip[data-ma-scope]').forEach(function (chip) {
      chip.addEventListener('click', function () {
        var scope = chip.getAttribute('data-ma-scope');
        var code  = chip.getAttribute('data-ma-brand');
        var vis = panel.__maState.visible[scope];
        if (!vis) return;
        vis[code] = !vis[code];
        chip.classList.toggle('col-chip-off', !vis[code]);
        applyColumnVisibility(panel, scope);
        renderChart(panel, scope);
      });
    });
  }

  function applyColumnVisibility(panel, scope) {
    var vis = panel.__maState.visible[scope];
    var sec = panel.querySelector('.ma-matrix-section[data-ma-stim="' + scope + '"]');
    if (!sec) return;
    sec.querySelectorAll('th[data-ma-brand], td[data-ma-brand]').forEach(function (cell) {
      var code = cell.getAttribute('data-ma-brand');
      cell.style.display = vis[code] === false ? 'none' : '';
    });
  }

  // -------------------------------------------------------------- toggles
  function bindToggles(panel) {
    panel.querySelectorAll('input[data-ma-action="showcounts"]').forEach(function (cb) {
      cb.addEventListener('change', function () {
        var stim = cb.getAttribute('data-ma-stim');
        panel.__maState.counts[stim] = cb.checked;
        applyShowCounts(panel, stim);
      });
    });
    panel.querySelectorAll('input[data-ma-action="showchart"]').forEach(function (cb) {
      cb.addEventListener('change', function () {
        var stim = cb.getAttribute('data-ma-stim');
        panel.__maState.showchart[stim] = cb.checked;
        var sec = panel.querySelector('.ma-chart-section[data-ma-stim="' + stim + '"]');
        if (sec) {
          if (cb.checked) { sec.removeAttribute('hidden'); renderChart(panel, stim); }
          else sec.setAttribute('hidden', '');
        }
      });
    });
  }

  function applyShowCounts(panel, stim) {
    var sec = panel.querySelector('.ma-matrix-section[data-ma-stim="' + stim + '"]');
    if (!sec) return;
    sec.classList.toggle('ma-show-counts', !!panel.__maState.counts[stim]);
  }

  // -------------------------------------------------------------- heatmap mode
  function bindHeatmapMode(panel) {
    panel.querySelectorAll('input[type="checkbox"][data-ma-action="heatmapmode"]').forEach(function (cb) {
      cb.addEventListener('change', function () {
        var stim = cb.getAttribute('data-ma-stim');
        panel.__maState.heatmap[stim] = cb.checked ? 'ci' : 'off';
        applyHeatmapMode(panel, stim);
      });
    });
  }

  function applyHeatmapMode(panel, stim) {
    var sec = panel.querySelector('.ma-matrix-section[data-ma-stim="' + stim + '"]');
    if (!sec) return;
    var mode = panel.__maState.heatmap[stim] || 'ci';
    sec.setAttribute('data-ma-heatmap-mode', mode);
    sec.classList.toggle('ma-heatmap-off', mode === 'off');
    sec.querySelectorAll('.ma-heatmap-cell').forEach(function (td) {
      if (mode === 'diff') {
        var col = td.getAttribute('data-ma-heatmap') || '';
        td.style.backgroundColor = col;
      } else {
        td.style.backgroundColor = '';
      }
    });
  }

  // -------------------------------------------------------------- base mode
  function bindBaseMode(panel) {
    panel.querySelectorAll('.sig-btn[data-ma-action="basemode"]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var stim = btn.getAttribute('data-ma-stim');
        var mode = btn.getAttribute('data-ma-basemode');
        panel.__maState.basemode[stim] = mode;
        var parent = btn.closest('.sig-level-switcher');
        if (parent) {
          parent.querySelectorAll('.sig-btn').forEach(function (b) {
            var active = b === btn;
            b.classList.toggle('sig-btn-active', active);
            b.setAttribute('aria-pressed', active ? 'true' : 'false');
          });
        }
        applyBaseMode(panel, stim);
        renderChart(panel, stim);
      });
    });
  }

  function applyBaseMode(panel, stim) {
    var mode = panel.__maState.basemode[stim] || 'total';
    var sec = panel.querySelector('.ma-matrix-section[data-ma-stim="' + stim + '"]');
    if (!sec) return;
    // Update base row cells — always show n=aware (total)
    sec.querySelectorAll('tr.ma-row-base td.ma-base-n[data-ma-brand]').forEach(function (td) {
      var span = td.querySelector('.ma-base-val');
      if (!span) return;
      var nTotal = td.getAttribute('data-ma-n-total');
      var nAware = td.getAttribute('data-ma-n-aware');
      if (nAware && nTotal) {
        span.textContent = 'n=' + nAware + ' (' + nTotal + ')';
      } else if (nTotal) {
        span.textContent = 'n=' + nTotal;
      } else {
        span.textContent = '\u2014';
      }
    });
    sec.querySelectorAll('.ma-heatmap-cell').forEach(function (td) {
      var pctTotal = parseFloat(td.getAttribute('data-ma-pct'));
      var pctAware = parseFloat(td.getAttribute('data-ma-pct-aware'));
      var nTotal   = td.getAttribute('data-ma-n-total');
      var nAware   = td.getAttribute('data-ma-n-aware');
      var span = td.querySelector('.ma-pct-primary');
      var nSpan = td.querySelector('.ma-n-primary');
      if (!span) return;
      var val = pctTotal;
      if (mode === 'aware' && !isNaN(pctAware)) { val = pctAware; }
      if (isNaN(val)) { span.textContent = '—'; return; }
      span.textContent = Math.round(val) + '%';
      if (nSpan) {
        if (nAware && nTotal) {
          nSpan.textContent = 'n=' + nAware + ' (' + nTotal + ')';
        } else if (nTotal) {
          nSpan.textContent = 'n=' + nTotal;
        } else {
          nSpan.textContent = '';
        }
      }
      td.setAttribute('data-sort-val', val.toFixed(6));
    });
  }

  // -------------------------------------------------------------- row active (grey-out)
  function bindRowActiveCheckboxes(panel) {
    panel.querySelectorAll('.ma-row-active-cb').forEach(function (cb) {
      cb.addEventListener('change', function (ev) {
        ev.stopPropagation();
        var stim = cb.getAttribute('data-ma-stim');
        var code = cb.getAttribute('data-ma-stim-code');
        if (!stim || !code) return;
        panel.__maState.rowActive[stim][code] = cb.checked;
        var tr = cb.closest('tr');
        if (tr) tr.classList.toggle('ma-row-inactive', !cb.checked);
        renderChart(panel, stim);
      });
    });
    // Also allow click on the label text to toggle
    panel.querySelectorAll('.ma-row-label-text').forEach(function (t) {
      t.addEventListener('click', function (ev) {
        var cb = t.closest('.ma-row-toggle').querySelector('.ma-row-active-cb');
        if (cb) { cb.checked = !cb.checked; cb.dispatchEvent(new Event('change')); }
        ev.preventDefault();
      });
    });
  }

  // -------------------------------------------------------------- sort
  function bindSortButtons(panel) {
    panel.querySelectorAll('.ma-sort-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var stim = btn.getAttribute('data-ma-stim');
        var action = btn.getAttribute('data-ma-action');
        var brand  = btn.getAttribute('data-ma-brand') || null;
        var state = panel.__maState.sort[stim];
        if (!state) return;

        var key = action === 'sort-brand' ? brand
                : action === 'sort-avg'   ? 'avg'
                : '__stim__';
        var next;
        if (state.col !== key) next = 'desc';
        else if (state.dir === 'desc') next = 'asc';
        else if (state.dir === 'asc')  next = 'none';
        else next = 'desc';

        state.col = next === 'none' ? null : key;
        state.dir = next;

        panel.querySelectorAll('.ma-sort-btn[data-ma-stim="' + stim + '"]').forEach(function (b) {
          b.setAttribute('data-ma-sort-dir', 'none');
          b.textContent = '\u21C5';
        });
        btn.setAttribute('data-ma-sort-dir', next);
        btn.textContent = next === 'desc' ? '\u2193'
                        : next === 'asc'  ? '\u2191' : '\u21C5';

        applySort(panel, stim);
      });
    });
  }

  function applySort(panel, stim) {
    var state = panel.__maState.sort[stim];
    var sec = panel.querySelector('.ma-matrix-section[data-ma-stim="' + stim + '"]');
    if (!sec) return;
    var tbody = sec.querySelector('tbody');
    if (!tbody) return;
    var rows = Array.from(tbody.querySelectorAll('tr.ma-row'));
    if (state.dir === 'none' || !state.col) {
      rows.sort(function (a, b) {
        return parseInt(a.getAttribute('data-ma-orig-idx') || '0', 10) -
               parseInt(b.getAttribute('data-ma-orig-idx') || '0', 10);
      });
    } else if (state.col === '__stim__') {
      rows.sort(function (a, b) {
        var av = a.getAttribute('data-ma-sort-stim') || '';
        var bv = b.getAttribute('data-ma-sort-stim') || '';
        return av.localeCompare(bv);
      });
      if (state.dir === 'desc') rows.reverse();
    } else {
      rows.sort(function (a, b) {
        var av = parseFloat(a.getAttribute('data-ma-sort-' + state.col) || 'NaN');
        var bv = parseFloat(b.getAttribute('data-ma-sort-' + state.col) || 'NaN');
        if (isNaN(av)) return 1; if (isNaN(bv)) return -1;
        return av - bv;
      });
      if (state.dir === 'desc') rows.reverse();
    }
    rows.forEach(function (r) { tbody.appendChild(r); });
    var summary = tbody.querySelector('tr.ma-row-summary');
    if (summary) tbody.appendChild(summary);
  }

  // -------------------------------------------------------------- metrics table sort
  function bindMetricsSortButtons(panel) {
    panel.__maState.metricsSort = { col: null, dir: 'none' };

    panel.querySelectorAll('.ma-metrics-table .ma-metric-sort-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var col   = btn.getAttribute('data-sort-col');
        var state = panel.__maState.metricsSort;
        var next;
        if (state.col !== col) {
          // Brand col: first click = A→Z; metric cols: first click = highest first
          next = { col: col, dir: col === 'brand' ? 'asc' : 'desc' };
        } else {
          next = { col: col, dir: state.dir === 'desc' ? 'asc' : 'desc' };
        }
        state.col = next.col;
        state.dir = next.dir;

        panel.querySelectorAll('.ma-metrics-table .ma-metric-sort-btn').forEach(function (b) {
          b.setAttribute('data-sort-dir', 'none');
          b.textContent = '\u21C5';
        });
        btn.setAttribute('data-sort-dir', next.dir);
        // For brand: asc=A→Z (↑), desc=Z→A (↓); for metrics: desc=highest (↓)
        btn.textContent = next.dir === 'desc' ? '\u2193' : '\u2191';

        applyMetricsSort(panel);
      });
    });
  }

  function applyMetricsSort(panel) {
    var state = panel.__maState && panel.__maState.metricsSort;
    if (!state) return;
    var table = panel.querySelector('.ma-metrics-table');
    if (!table) return;
    var tbody = table.querySelector('tbody');
    if (!tbody) return;

    // Only sort non-focal brand rows; focal row stays pinned above cat avg
    var focalCode = panel.__maState.focal;
    var sortableRows = Array.from(tbody.querySelectorAll('tr.ma-row')).filter(function (r) {
      return r.getAttribute('data-ma-brand') !== focalCode;
    });

    if (state.col === 'brand') {
      sortableRows.sort(function (a, b) {
        var av = (a.getAttribute('data-sort-brand') || '').trim();
        var bv = (b.getAttribute('data-sort-brand') || '').trim();
        return av.localeCompare(bv);
      });
      if (state.dir === 'desc') sortableRows.reverse();
    } else {
      sortableRows.sort(function (a, b) {
        var av = parseFloat(a.getAttribute('data-sort-' + state.col) || 'NaN');
        var bv = parseFloat(b.getAttribute('data-sort-' + state.col) || 'NaN');
        if (isNaN(av)) return 1;
        if (isNaN(bv)) return -1;
        return state.dir === 'desc' ? bv - av : av - bv;
      });
    }

    sortableRows.forEach(function (r) { tbody.appendChild(r); });
    // Re-pin fixed rows: base > focal > cat-avg > (other brand rows already at bottom)
    repositionMetricsPinnedRows(panel);
  }

  function repositionMetricsPinnedRows(panel) {
    var table = panel.querySelector('.ma-metrics-table');
    if (!table) return;
    var tbody = table.querySelector('tbody');
    if (!tbody) return;
    var focal    = panel.__maState.focal;
    var avgRow   = tbody.querySelector('tr.ma-metrics-cat-avg');
    var baseRow  = tbody.querySelector('tr.ma-metrics-base');
    var focalRow = focal ? tbody.querySelector('tr.ma-row[data-ma-brand="' + focal + '"]') : null;
    // Order from bottom to top (each insertBefore pushes to front)
    if (avgRow)   tbody.insertBefore(avgRow,   tbody.firstChild);
    if (focalRow) tbody.insertBefore(focalRow, tbody.firstChild);
    if (baseRow)  tbody.insertBefore(baseRow,  tbody.firstChild);
  }

  // -------------------------------------------------------------- metrics chips
  function bindMetricsChips(panel) {
    panel.querySelectorAll('.col-chip[data-ma-scope="metrics"]').forEach(function (chip) {
      chip.addEventListener('click', function () {
        var code  = chip.getAttribute('data-ma-brand');
        var focal = panel.__maState.focal;
        if (code === focal) return; // focal brand cannot be hidden
        var isOff = chip.classList.toggle('col-chip-off');
        var table = panel.querySelector('.ma-metrics-table');
        if (!table) return;
        table.querySelectorAll('tbody tr.ma-row[data-ma-brand="' + code + '"]').forEach(function (r) {
          r.style.display = isOff ? 'none' : '';
        });
        renderMAScatter(panel);
        renderMABarChart(panel);
      });
    });
  }

  // -------------------------------------------------------------- metrics hero refresh
  function refreshMetricsHero(panel) {
    var pd = panel.__maData;
    if (!pd || !pd.metrics) return;
    var focal = panel.__maState && panel.__maState.focal;
    if (!focal) return;

    var rows = pd.metrics.table || [];
    var focalRow = null;
    rows.forEach(function (r) { if (r.brand_code === focal) focalRow = r; });
    if (!focalRow) return;

    var focalName   = focalRow.brand_name || getBrandName(pd, focal);
    var focalColour = getBrandColour(pd, focal);
    var catAvg      = pd.metrics.cat_avg || {};

    // Update section heading
    var titleEl = panel.querySelector('.ma-metrics-hero-title');
    if (titleEl) titleEl.textContent = focalName + ' \u2014 Headline Metrics';

    // Find overall leader for a metric key
    function findLeader(key) {
      var best = null, bestVal = -Infinity;
      rows.forEach(function (r) {
        var v = r[key];
        if (v != null && !isNaN(v) && v > bestVal) { bestVal = v; best = r; }
      });
      return best;
    }

    var dp = (pd.config && pd.config.decimal_places != null) ? pd.config.decimal_places : 0;
    function fmtVal(val, unit) {
      if (val == null || isNaN(Number(val))) return '\u2014';
      return unit === 'pct' ? Number(val).toFixed(dp) + '%' : Number(val).toFixed(2);
    }

    var metricDefs = [
      { key: 'mpen', unit: 'pct' },
      { key: 'ns',   unit: 'num' },
      { key: 'mms',  unit: 'pct' },
      { key: 'som',  unit: 'pct' }
    ];

    metricDefs.forEach(function (def) {
      var card = panel.querySelector('.ma-hero-card[data-ma-metric="' + def.key + '"]');
      if (!card) return;

      // Focal value
      var valEl = card.querySelector('.tk-hero-value');
      if (valEl) {
        valEl.textContent = fmtVal(focalRow[def.key], def.unit);
        valEl.style.color = focalColour;
      }
      card.style.borderLeftColor = focalColour;

      // Category avg (static — doesn't change with focal)
      var avgEl = card.querySelector('.ma-hero-compare strong');
      if (avgEl) avgEl.textContent = fmtVal(catAvg[def.key], def.unit);

      // Leader line
      var leaderEl = card.querySelector('.ma-hero-leader');
      if (leaderEl) {
        var leader = findLeader(def.key);
        if (!leader) {
          leaderEl.innerHTML = '';
        } else if (leader.brand_code === focal) {
          leaderEl.className = 'ma-hero-leader ma-hero-leader-focal';
          leaderEl.textContent = 'Category leader';
        } else {
          leaderEl.className = 'ma-hero-leader';
          var lname = leader.brand_name || getBrandName(pd, leader.brand_code);
          leaderEl.innerHTML = 'Leader: <strong>' + escHtml(lname) + '</strong> (' + fmtVal(leader[def.key], def.unit) + ')';
        }
      }
    });
  }

  // -------------------------------------------------------------- metrics focal refresh
  function refreshMetricsFocal(panel) {
    var focal = panel.__maState.focal;
    var table = panel.querySelector('.ma-metrics-table');
    if (!table) return;
    var tbody = table.querySelector('tbody');
    if (!tbody) return;

    // Update focal-row class and badge on all brand rows
    tbody.querySelectorAll('tr.ma-row').forEach(function (r) {
      var code     = r.getAttribute('data-ma-brand');
      var isFocal  = code === focal;
      r.classList.toggle('ma-metrics-focal-row', isFocal);
      var lbl = r.querySelector('td.ct-label-col');
      if (!lbl) return;
      var existing = lbl.querySelector('.ma-focal-badge');
      if (existing) existing.remove();
      if (isFocal) {
        var b = document.createElement('span');
        b.className = 'ma-focal-badge';
        b.textContent = 'FOCAL';
        lbl.appendChild(b);
      }
    });

    // Ensure focal chip is always on and row visible
    panel.querySelectorAll('.col-chip[data-ma-scope="metrics"]').forEach(function (chip) {
      if (chip.getAttribute('data-ma-brand') === focal) {
        chip.classList.remove('col-chip-off');
        var focalRow = tbody.querySelector('tr.ma-row[data-ma-brand="' + focal + '"]');
        if (focalRow) focalRow.style.display = '';
      }
    });

    repositionMetricsPinnedRows(panel);
  }

  // -------------------------------------------------------------- chart section toggles
  var CHART_OPTS = [
    { key: 'scatter', label: 'Mental Space' },
    { key: 'bars',    label: 'MMS vs SOM' },
    { key: 'ranking', label: 'CEP Ranking' }
  ];

  function bindChartSelectMenu(panel) {
    panel.querySelectorAll('[data-ma-action="chartselectmenu"]').forEach(function (btn) {
      btn.addEventListener('click', function (ev) {
        ev.stopPropagation();
        openChartSelectMenu(panel, btn);
      });
    });
  }

  function openChartSelectMenu(panel, btn) {
    panel.querySelectorAll('.ma-chart-select-menu').forEach(function (el) { el.remove(); });

    var dd = document.createElement('div');
    dd.className = 'ma-chart-select-menu';
    dd.style.cssText = 'position:absolute;z-index:400;background:#fff;border:1px solid #cbd5e1;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,0.08);padding:8px;min-width:180px;font-size:12px;';
    dd.innerHTML = '<div style="font-weight:600;margin-bottom:6px;color:#334155;">Show charts</div>'
      + CHART_OPTS.map(function (c) {
        var sec = panel.querySelector('[data-ma-chart-id="' + c.key + '"]');
        var checked = (!sec || !sec.hasAttribute('hidden')) ? ' checked' : '';
        return '<label style="display:block;padding:3px 0;cursor:pointer;"><input type="checkbox"' + checked + ' data-ma-chart-key="' + c.key + '" style="margin-right:6px;">' + c.label + '</label>';
      }).join('');

    var rect = btn.getBoundingClientRect();
    var panelRect = panel.getBoundingClientRect();
    dd.style.left = (rect.left - panelRect.left) + 'px';
    dd.style.top  = (rect.bottom - panelRect.top + 4) + 'px';
    panel.appendChild(dd);

    dd.querySelectorAll('input[data-ma-chart-key]').forEach(function (cb) {
      cb.addEventListener('change', function () {
        var target = cb.getAttribute('data-ma-chart-key');
        var sec = panel.querySelector('[data-ma-chart-id="' + target + '"]');
        if (!sec) return;
        if (cb.checked) {
          sec.removeAttribute('hidden');
          if (target === 'scatter') renderMAScatter(panel);
          else if (target === 'bars') renderMABarChart(panel);
        } else {
          sec.setAttribute('hidden', '');
        }
        updateChartSelectBtn(panel, btn);
      });
    });

    function closeOnce() {
      dd.remove();
      document.removeEventListener('click', closeOnce);
    }
    setTimeout(function () { document.addEventListener('click', closeOnce); }, 0);
    dd.addEventListener('click', function (e) { e.stopPropagation(); });
  }

  function updateChartSelectBtn(panel, btn) {
    var anyVisible = CHART_OPTS.some(function (c) {
      var s = panel.querySelector('[data-ma-chart-id="' + c.key + '"]');
      return s && !s.hasAttribute('hidden');
    });
    btn.setAttribute('aria-pressed', anyVisible ? 'true' : 'false');
    btn.innerHTML = (anyVisible ? '&#10003; ' : '') + 'Show chart &#9662;';
  }

  // -------------------------------------------------------------- metrics show counts
  function bindMetricsShowCounts(panel) {
    var cb = panel.querySelector('input[data-ma-action="showcounts-metrics"]');
    if (!cb) return;
    cb.addEventListener('change', function () {
      var sec = panel.querySelector('.ma-metrics-section');
      if (sec) sec.classList.toggle('ma-show-counts-metrics', cb.checked);
    });
  }

  // -------------------------------------------------------------- metrics scatter (MPen × NS)
  function renderMAScatter(panel) {
    var wrap = panel.querySelector('.ma-scatter-wrap');
    if (!wrap) return;
    var svg = wrap.querySelector('.ma-scatter-svg');
    if (!svg) return;

    var pd = panel.__maData;
    if (!pd || !pd.metrics) { svg.innerHTML = ''; return; }

    var focal = panel.__maState && panel.__maState.focal;

    // Build vis map from metrics chips
    var visMap = {};
    panel.querySelectorAll('.col-chip[data-ma-scope="metrics"]').forEach(function (chip) {
      visMap[chip.getAttribute('data-ma-brand')] = !chip.classList.contains('col-chip-off');
    });

    var points = (pd.metrics.table || []).filter(function (r) {
      return visMap[r.brand_code] !== false && r.mpen != null && r.ns != null;
    }).map(function (r) {
      return { code: r.brand_code, name: r.brand_name,
               mpen: r.mpen, ns: r.ns, mms: r.mms || 0, som: r.som || 0,
               isFocal: r.brand_code === focal };
    });

    if (points.length === 0) { svg.innerHTML = ''; return; }

    var dp = (pd.config && pd.config.decimal_places != null) ? pd.config.decimal_places : 0;
    var catAvg = pd.metrics.cat_avg || {};
    var mL = 56, mR = 24, mT = 28, mB = 48;
    var width  = svg.clientWidth || 600;
    var height = Math.max(300, Math.round(width * 0.5));

    svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
    svg.setAttribute('height', height);
    svg.style.height = height + 'px';

    var xMax = 100; // always 0-100 for MPen
    var yMax = Math.max(1, (Math.ceil(Math.max.apply(null, points.map(function (p) { return p.ns; })) * 4) / 4) + 0.5);
    var mmsMax = Math.max(1, Math.max.apply(null, points.map(function (p) { return p.mms; })));

    var pW = width - mL - mR;
    var pH = height - mT - mB;

    function toX(v) { return mL + pW * v / xMax; }
    function toY(v) { return mT + pH * (1 - v / yMax); }
    function bR(mms) { return Math.max(7, Math.min(24, 7 + 17 * mms / mmsMax)); }

    var parts = [];

    // Subtle quadrant tint (based on cat avg)
    var qMidX = catAvg.mpen != null ? toX(catAvg.mpen) : mL + pW / 2;
    var qMidY = catAvg.ns   != null ? toY(catAvg.ns)   : mT + pH / 2;
    parts.push('<rect x="' + qMidX + '" y="' + mT + '" width="' + (mL + pW - qMidX) + '" height="' + (qMidY - mT) + '" fill="rgba(5,150,105,0.04)"/>');
    parts.push('<rect x="' + mL + '" y="' + qMidY + '" width="' + (qMidX - mL) + '" height="' + (mT + pH - qMidY) + '" fill="rgba(220,38,38,0.04)"/>');

    // Grid lines
    for (var xi = 0; xi <= 5; xi++) {
      var xv = xMax * xi / 5;
      var gx = toX(xv);
      parts.push('<line x1="' + gx + '" y1="' + mT + '" x2="' + gx + '" y2="' + (mT + pH) +
                 '" stroke="#eef2f7" stroke-width="1"/>');
      parts.push('<text x="' + gx + '" y="' + (mT + pH + 14) +
                 '" text-anchor="middle" font-size="9" fill="#94a3b8">' + Math.round(xv) + '%</text>');
    }
    for (var yi = 0; yi <= 4; yi++) {
      var yv = yMax * yi / 4;
      var gy = toY(yv);
      parts.push('<line x1="' + mL + '" y1="' + gy + '" x2="' + (width - mR) + '" y2="' + gy +
                 '" stroke="#eef2f7" stroke-width="1"/>');
      parts.push('<text x="' + (mL - 6) + '" y="' + gy +
                 '" text-anchor="end" dominant-baseline="middle" font-size="9" fill="#94a3b8">' + yv.toFixed(1) + '</text>');
    }

    // Cat avg reference lines
    if (catAvg.mpen != null) {
      var ax = toX(catAvg.mpen);
      parts.push('<line x1="' + ax + '" y1="' + mT + '" x2="' + ax + '" y2="' + (mT + pH) +
                 '" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 3"/>');
      parts.push('<text x="' + (ax + 4) + '" y="' + (mT + 11) +
                 '" font-size="9" fill="#94a3b8" font-weight="600">avg MPen</text>');
    }
    if (catAvg.ns != null) {
      var ay = toY(catAvg.ns);
      parts.push('<line x1="' + mL + '" y1="' + ay + '" x2="' + (width - mR) + '" y2="' + ay +
                 '" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 3"/>');
      parts.push('<text x="' + (mL + 4) + '" y="' + (ay - 5) +
                 '" font-size="9" fill="#94a3b8" font-weight="600">avg NS</text>');
    }

    // OLS double-jeopardy trend line
    if (points.length >= 3) {
      var n = points.length;
      var sx = 0, sy = 0, sxy = 0, sx2 = 0;
      points.forEach(function (p) { sx += p.mpen; sy += p.ns; sxy += p.mpen * p.ns; sx2 += p.mpen * p.mpen; });
      var den = sx2 - sx * sx / n;
      if (Math.abs(den) > 1e-8) {
        var b = (sxy - sx * sy / n) / den;
        var a = sy / n - b * sx / n;
        var lx1 = 0, ly1 = a, lx2 = xMax, ly2 = a + b * xMax;
        if (ly1 < 0) { lx1 = -a / b; ly1 = 0; }
        if (ly2 > yMax) { lx2 = (yMax - a) / b; ly2 = yMax; }
        if (ly1 > yMax) { lx1 = (yMax - a) / b; ly1 = yMax; }
        if (ly2 < 0) { lx2 = -a / b; ly2 = 0; }
        parts.push('<line x1="' + toX(lx1) + '" y1="' + toY(ly1) + '" x2="' + toX(lx2) + '" y2="' + toY(ly2) +
                   '" stroke="#64748b" stroke-width="1.5" stroke-dasharray="8 5" opacity="0.35">' +
                   '<title>Double jeopardy trend</title></line>');
      }
    }

    // Quadrant labels
    var qs = 'font-size:9;fill:#cbd5e1;font-weight:700;letter-spacing:0.5px;';
    parts.push('<text style="' + qs + '" x="' + (width - mR - 6) + '" y="' + (mT + 14) + '" text-anchor="end">STRONG</text>');
    parts.push('<text style="' + qs + '" x="' + (mL + 6) + '" y="' + (mT + 14) + '">NICHE</text>');
    parts.push('<text style="' + qs + '" x="' + (width - mR - 6) + '" y="' + (mT + pH - 6) + '" text-anchor="end">BROAD REACH</text>');
    parts.push('<text style="' + qs + '" x="' + (mL + 6) + '" y="' + (mT + pH - 6) + '">WEAK</text>');

    // Axes
    parts.push('<line x1="' + mL + '" y1="' + mT + '" x2="' + mL + '" y2="' + (mT + pH) + '" stroke="#94a3b8" stroke-width="1.5"/>');
    parts.push('<line x1="' + mL + '" y1="' + (mT + pH) + '" x2="' + (width - mR) + '" y2="' + (mT + pH) + '" stroke="#94a3b8" stroke-width="1.5"/>');
    parts.push('<text x="' + (mL + pW / 2) + '" y="' + (height - 4) + '" text-anchor="middle" font-size="11" fill="#475569" font-weight="600">Mental Penetration (%)</text>');
    parts.push('<text transform="rotate(-90 ' + (mL - 40) + ' ' + (mT + pH / 2) + ')" x="' + (mL - 40) + '" y="' + (mT + pH / 2) + '" text-anchor="middle" font-size="11" fill="#475569" font-weight="600">Network Size</text>');

    // Bubbles — focal on top
    var nonFocal = points.filter(function (p) { return !p.isFocal; });
    var focal2   = points.filter(function (p) { return p.isFocal; });
    nonFocal.concat(focal2).forEach(function (p) {
      var cx  = toX(p.mpen), cy = toY(p.ns), r2 = bR(p.mms);
      var col = getBrandColour(pd, p.code);
      // Drop shadow filter id per bubble
      var filterId = 'f-' + p.code.replace(/[^a-z0-9]/gi, '');
      parts.push('<defs><filter id="' + filterId + '" x="-30%" y="-30%" width="160%" height="160%">' +
                 '<feDropShadow dx="1" dy="1" stdDeviation="2" flood-color="' + col + '" flood-opacity="0.25"/>' +
                 '</filter></defs>');
      parts.push('<circle cx="' + cx + '" cy="' + cy + '" r="' + r2 + '"' +
                 ' fill="' + col + '" fill-opacity="' + (p.isFocal ? 0.88 : 0.70) + '"' +
                 ' stroke="' + col + '" stroke-width="' + (p.isFocal ? 2.5 : 1.5) + '"' +
                 ' filter="url(#' + filterId + ')">' +
                 '<title>' + escHtml(p.name) + '\nMPen: ' + p.mpen.toFixed(dp) + '%' +
                 '\nNS: ' + p.ns.toFixed(2) + '\nMMS: ' + p.mms.toFixed(dp) + '%</title></circle>');
      var lblLines2 = wrapSvgLabel(p.name, 14);
      var lblFontSize = p.isFocal ? 10 : 9;
      var lblLineH = lblFontSize + 2;
      var lblStartY = cy - ((lblLines2.length - 1) * lblLineH) / 2 + 3;
      // Try to offset label to avoid overlap at right edge
      var lblX = cx + r2 + 4;
      var anchorDir = 'start';
      if (lblX + 60 > width - mR) { lblX = cx - r2 - 4; anchorDir = 'end'; }
      var tspans2 = lblLines2.map(function (line, li) {
        return '<tspan x="' + lblX + '" dy="' + (li === 0 ? 0 : lblLineH) + '">' + escHtml(line) + '</tspan>';
      });
      parts.push('<text x="' + lblX + '" y="' + lblStartY + '"' +
                 ' text-anchor="' + anchorDir + '"' +
                 ' font-size="' + lblFontSize + '" font-weight="' + (p.isFocal ? 700 : 400) + '"' +
                 ' fill="' + col + '">' + tspans2.join('') + '</text>');
    });

    svg.innerHTML = parts.join('');
  }

  // -------------------------------------------------------------- metrics bar chart (MMS vs SOM)
  function renderMABarChart(panel) {
    var wrap = panel.querySelector('.ma-bars-wrap');
    if (!wrap) return;
    var svg = wrap.querySelector('.ma-bars-svg');
    if (!svg) return;

    var pd = panel.__maData;
    if (!pd || !pd.metrics) { svg.innerHTML = ''; return; }

    var focal = panel.__maState && panel.__maState.focal;

    var visMap = {};
    panel.querySelectorAll('.col-chip[data-ma-scope="metrics"]').forEach(function (chip) {
      visMap[chip.getAttribute('data-ma-brand')] = !chip.classList.contains('col-chip-off');
    });

    // Focal first, then others by MMS desc
    var all = (pd.metrics.table || []).filter(function (r) {
      return visMap[r.brand_code] !== false;
    });
    var focalRows = all.filter(function (r) { return r.brand_code === focal; });
    var others    = all.filter(function (r) { return r.brand_code !== focal; })
                       .sort(function (a, b) { return (b.mms || 0) - (a.mms || 0); });
    var rows = focalRows.concat(others);
    if (rows.length === 0) { svg.innerHTML = ''; return; }

    var dp = (pd.config && pd.config.decimal_places != null) ? pd.config.decimal_places : 0;
    var catAvg = pd.metrics.cat_avg || {};
    var lblW = 130, mR = 8, mT = 28, mB = 22;
    var barH = 12, barGap = 3, rowH = barH * 2 + barGap + 14;

    var width  = svg.clientWidth || 500;
    var height = mT + mB + rows.length * rowH + 20;

    svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
    svg.setAttribute('height', height);
    svg.style.height = height + 'px';

    var pW = width - lblW - mR;

    var maxVal = Math.max(
      Math.max.apply(null, rows.map(function (r) { return r.mms || 0; }).concat(catAvg.mms || 0)),
      Math.max.apply(null, rows.map(function (r) { return r.som || 0; }).concat(catAvg.som || 0))
    );
    maxVal = Math.max(5, Math.ceil(maxVal / 5) * 5 + 5);

    function toX(v) { return lblW + pW * v / maxVal; }

    var parts = [];

    // Legend
    parts.push('<rect x="' + lblW + '" y="7" width="14" height="9" fill="#475569" fill-opacity="0.8" rx="2"/>');
    parts.push('<text x="' + (lblW + 18) + '" y="15.5" font-size="10" fill="#334155" font-weight="500">MMS</text>');
    parts.push('<rect x="' + (lblW + 54) + '" y="7" width="14" height="9" fill="#94a3b8" fill-opacity="0.6" rx="2"/>');
    parts.push('<text x="' + (lblW + 72) + '" y="15.5" font-size="10" fill="#334155" font-weight="500">Share of Mind</text>');

    // X grid + ticks
    for (var ti = 0; ti <= 4; ti++) {
      var tv = maxVal * ti / 4;
      var tx = toX(tv);
      parts.push('<line x1="' + tx + '" y1="' + mT + '" x2="' + tx + '" y2="' + (height - mB) +
                 '" stroke="#f1f5f9" stroke-width="1"/>');
      parts.push('<text x="' + tx + '" y="' + (height - mB + 12) +
                 '" text-anchor="middle" font-size="9" fill="#94a3b8">' + tv.toFixed(dp) + '%</text>');
    }

    // Cat avg reference lines
    if (catAvg.mms != null) {
      var cx = toX(catAvg.mms);
      parts.push('<line x1="' + cx + '" y1="' + mT + '" x2="' + cx + '" y2="' + (height - mB) +
                 '" stroke="#475569" stroke-width="1" stroke-dasharray="4 3" opacity="0.6">' +
                 '<title>Cat avg MMS: ' + catAvg.mms.toFixed(dp) + '%</title></line>');
    }
    if (catAvg.som != null) {
      var sx = toX(catAvg.som);
      parts.push('<line x1="' + sx + '" y1="' + mT + '" x2="' + sx + '" y2="' + (height - mB) +
                 '" stroke="#94a3b8" stroke-width="1" stroke-dasharray="4 3" opacity="0.6">' +
                 '<title>Cat avg SOM: ' + catAvg.som.toFixed(dp) + '%</title></line>');
    }

    // Bars per brand
    rows.forEach(function (r, i) {
      var y0     = mT + i * rowH;
      var col    = getBrandColour(pd, r.brand_code);
      var isFocal = r.brand_code === focal;
      var lblLines = wrapSvgLabel(r.brand_name || r.brand_code, 16);
      var lineH    = 12;
      var lblMidY  = y0 + rowH / 2;
      var lblStartY = lblMidY - ((lblLines.length - 1) * lineH) / 2;
      var tspans = lblLines.map(function (line, li) {
        return '<tspan x="' + (lblW - 6) + '" dy="' + (li === 0 ? 0 : lineH) + '">' + escHtml(line) + '</tspan>';
      });
      parts.push('<text x="' + (lblW - 6) + '" y="' + lblStartY +
                 '" text-anchor="end" dominant-baseline="middle" font-size="11"' +
                 ' fill="' + (isFocal ? col : '#334155') + '"' +
                 ' font-weight="' + (isFocal ? 700 : 400) + '">' + tspans.join('') + '</text>');

      // MMS bar
      var mmsW = Math.max(0, pW * (r.mms || 0) / maxVal);
      parts.push('<rect x="' + lblW + '" y="' + y0 + '" width="' + mmsW + '" height="' + barH +
                 '" fill="' + col + '" fill-opacity="' + (isFocal ? 0.9 : 0.7) + '" rx="2">' +
                 '<title>' + escHtml(r.brand_name) + ' MMS: ' + (r.mms || 0).toFixed(dp) + '%</title></rect>');
      if (mmsW > 28)
        parts.push('<text x="' + (lblW + mmsW - 4) + '" y="' + (y0 + barH - 3) +
                   '" text-anchor="end" font-size="9" fill="#fff" font-weight="600">' + (r.mms || 0).toFixed(dp) + '%</text>');

      // SOM bar
      var somY = y0 + barH + barGap;
      var somW = Math.max(0, pW * (r.som || 0) / maxVal);
      parts.push('<rect x="' + lblW + '" y="' + somY + '" width="' + somW + '" height="' + barH +
                 '" fill="' + col + '" fill-opacity="' + (isFocal ? 0.38 : 0.25) + '" rx="2">' +
                 '<title>' + escHtml(r.brand_name) + ' SOM: ' + (r.som || 0).toFixed(dp) + '%</title></rect>');
      if (somW > 28)
        parts.push('<text x="' + (lblW + somW - 4) + '" y="' + (somY + barH - 3) +
                   '" text-anchor="end" font-size="9" fill="' + col + '" font-weight="600">' + (r.som || 0).toFixed(dp) + '%</text>');

      if (i < rows.length - 1)
        parts.push('<line x1="' + lblW + '" y1="' + (y0 + rowH - 2) + '" x2="' + (width - mR) + '" y2="' + (y0 + rowH - 2) +
                   '" stroke="#f1f5f9" stroke-width="1"/>');
    });

    // Y axis
    parts.push('<line x1="' + lblW + '" y1="' + mT + '" x2="' + lblW + '" y2="' + (height - mB) + '" stroke="#cbd5e1" stroke-width="1"/>');

    svg.innerHTML = parts.join('');
  }

  // -------------------------------------------------------------- label wrap helper
  function wrapSvgLabel(text, maxChars) {
    var words = text.split(' ');
    var line1 = '', line2 = '';
    var onLine2 = false;
    for (var i = 0; i < words.length; i++) {
      var w = words[i];
      if (!onLine2) {
        var t1 = line1 ? line1 + ' ' + w : w;
        if (t1.length <= maxChars) { line1 = t1; } else { onLine2 = true; line2 = w; }
      } else {
        var t2 = line2 ? line2 + ' ' + w : w;
        if (t2.length <= maxChars) { line2 = t2; }
        else { line2 = line2.slice(0, maxChars - 1) + '\u2026'; break; }
      }
    }
    var lines = [];
    if (line1) lines.push(line1);
    if (line2) lines.push(line2);
    if (!lines.length) lines.push(text.slice(0, maxChars));
    return lines;
  }

  // -------------------------------------------------------------- dot plot chart
  function renderChart(panel, stim) {
    var sec = panel.querySelector('.ma-chart-section[data-ma-stim="' + stim + '"]');
    if (!sec) return;
    if (panel.__maState.showchart[stim] === false) { sec.setAttribute('hidden', ''); return; }
    sec.removeAttribute('hidden');

    var svg = sec.querySelector('.ma-bar-chart');
    if (!svg) return;

    var pd = panel.__maData;
    var block = pd[stim];
    if (!block) { svg.innerHTML = ''; return; }

    var focal    = panel.__maState.focal;
    var baseMode = panel.__maState.basemode[stim] || 'total';
    var visMap   = panel.__maState.chartVisible[stim] || {};
    var rowActive = panel.__maState.rowActive[stim] || {};

    var brandCodes = (pd.config && pd.config.brand_codes) || [];
    var orderedBrands = [];
    if (focal && brandCodes.indexOf(focal) >= 0) orderedBrands.push(focal);
    brandCodes.forEach(function (c) { if (c !== focal) orderedBrands.push(c); });
    var visibleBrands = orderedBrands.filter(function (c) { return visMap[c] !== false; });

    var activeRows = (block.codes || []).map(function (code, i) {
      return { code: code, label: block.labels[i], idx: i };
    }).filter(function (r) { return rowActive[r.code] !== false; });

    // Render legend
    var legendEl = sec.querySelector('.ma-chart-legend');
    if (legendEl) {
      legendEl.innerHTML = visibleBrands.map(function (b) {
        var col = getBrandColour(pd, b);
        var isFocal = b === focal;
        return '<span class="ma-legend-item">' +
               '<span class="ma-legend-dot" style="background:' + col + ';opacity:' + (isFocal ? '1' : '0.8') + '"></span>' +
               '<span class="ma-legend-name">' + escHtml(getBrandName(pd, b)) + '</span>' +
               '</span>';
      }).join('');
    }

    if (activeRows.length === 0 || visibleBrands.length === 0) {
      svg.innerHTML = '';
      return;
    }

    var cellMap = {};
    (block.cells || []).forEach(function (c) {
      cellMap[c.stim_code + '|' + c.brand_code] = c;
    });

    var pctField = baseMode === 'aware' ? 'pct_aware' : 'pct_total';

    // Layout constants
    var marginLeft   = 200;
    var marginRight  = 30;
    var marginTop    = 14;
    var marginBottom = 28;
    var rowH         = 44;
    var dotCYOffset  = 28;
    var dotR         = 5;

    var width = svg.clientWidth || 800;

    // Pre-calculate legend layout so we can include it in chartHeight
    var legendItems = visibleBrands.map(function (b) {
      var name  = getBrandName(pd, b);
      var label = name.length > 18 ? name.slice(0, 17) + '\u2026' : name;
      return { code: b, label: label, col: getBrandColour(pd, b),
               isFocal: b === focal, w: 14 + label.length * 5.8 + 12 };
    });
    var legendRows = [], legendCurRow = [], legendX = 0;
    for (var li = 0; li < legendItems.length; li++) {
      var litem = legendItems[li];
      if (legendX + litem.w > width - 8 && legendCurRow.length > 0) {
        legendRows.push(legendCurRow); legendCurRow = []; legendX = 0;
      }
      legendCurRow.push({ item: litem, x: legendX });
      legendX += litem.w;
    }
    if (legendCurRow.length > 0) legendRows.push(legendCurRow);
    var legendRowH  = 18;
    var legendPadT  = 10;
    var showCatAvgNote = baseMode === 'total' && block.stim_avg &&
      block.stim_avg.some(function (v) { return v != null && !isNaN(v); });
    var legendH     = (legendRows.length > 0 || showCatAvgNote)
      ? legendPadT + legendRows.length * legendRowH + (showCatAvgNote ? legendRowH : 0)
      : 0;

    var dataAreaH   = marginTop + marginBottom + activeRows.length * rowH;
    var chartHeight = dataAreaH + legendH;
    svg.setAttribute('viewBox', '0 0 ' + width + ' ' + chartHeight);
    svg.setAttribute('height', chartHeight);
    svg.setAttribute('preserveAspectRatio', 'xMinYMin meet');
    svg.style.height = chartHeight + 'px';

    var xZero  = marginLeft;
    var xEnd   = width - marginRight;
    var xScale = xEnd - xZero;

    var maxVal = 0;
    activeRows.forEach(function (r) {
      visibleBrands.forEach(function (b) {
        var c = cellMap[r.code + '|' + b];
        if (!c) return;
        var v = c[pctField];
        if (v != null && !isNaN(v) && v > maxVal) maxVal = v;
      });
    });
    maxVal = Math.max(10, Math.ceil(maxVal / 10) * 10);

    var parts = [];

    var gridSteps = 4;
    for (var g = 0; g <= gridSteps; g++) {
      var gv = maxVal * g / gridSteps;
      var gx = xZero + xScale * g / gridSteps;
      parts.push('<line class="ma-bar-gridline" x1="' + gx + '" y1="' + marginTop +
                 '" x2="' + gx + '" y2="' + (dataAreaH - marginBottom) + '"/>');
      parts.push('<text class="ma-bar-label" x="' + gx + '" y="' + (dataAreaH - marginBottom + 14) +
                 '" text-anchor="middle">' + Math.round(gv) + '%</text>');
    }

    activeRows.forEach(function (r, ri) {
      var rowTop = marginTop + ri * rowH;
      var dotCY  = rowTop + dotCYOffset;

      if (ri % 2 === 0) {
        parts.push('<rect x="' + xZero + '" y="' + rowTop + '" width="' + xScale +
                   '" height="' + rowH + '" fill="#fafbfc" fill-opacity="0.55"/>');
      }

      var lblLines = wrapSvgLabel(r.label, 26);
      var lineH = 14;
      var startY = dotCY - Math.floor(lblLines.length * lineH / 2) + Math.floor(lineH / 2);
      var tspans = lblLines.map(function(line, li) {
        return '<tspan x="' + (xZero - 10) + '" y="' + (startY + li * lineH) + '">' + escHtml(line) + '</tspan>';
      });
      parts.push('<text class="ma-bar-group-label" text-anchor="end">' + tspans.join('') + '</text>');

      parts.push('<line x1="' + xZero + '" y1="' + dotCY + '" x2="' + xEnd + '" y2="' + dotCY +
                 '" stroke="#eef2f7" stroke-width="1"/>');

      var avg = block.stim_avg ? block.stim_avg[r.idx] : null;
      if (avg != null && !isNaN(avg) && baseMode === 'total') {
        var ax = xZero + xScale * avg / maxVal;
        parts.push('<line class="ma-bar-cat-avg" x1="' + ax + '" y1="' + (rowTop + 4) +
                   '" x2="' + ax + '" y2="' + (rowTop + rowH - 4) + '">' +
                   '<title>Cat avg: ' + avg.toFixed(0) + '%</title></line>');
      }

      visibleBrands.forEach(function (b) {
        var cell = cellMap[r.code + '|' + b];
        if (!cell) return;
        var v = cell[pctField];
        if (v == null || isNaN(v)) return;

        var cx      = xZero + Math.max(dotR, Math.min(xScale, xScale * v / maxVal));
        var col     = getBrandColour(pd, b);
        var isFocal = b === focal;
        var r2      = isFocal ? dotR + 1 : dotR;
        var opacity = isFocal ? 1 : 0.80;

        parts.push(
          '<text x="' + cx + '" y="' + (dotCY - r2 - 3) + '"' +
          ' text-anchor="middle" dominant-baseline="text-after-edge"' +
          ' font-size="9" fill="' + col + '"' +
          ' font-weight="' + (isFocal ? '700' : '500') + '">' +
          v.toFixed(0) + '%</text>'
        );

        parts.push(
          '<circle class="ma-bar" cx="' + cx + '" cy="' + dotCY + '"' +
          ' r="' + r2 + '" fill="' + col + '" fill-opacity="' + opacity + '"' +
          ' stroke="' + col + '" stroke-width="' + (isFocal ? 1.5 : 0.5) + '">' +
          '<title>' + escHtml(getBrandName(pd, b)) + ': ' + v.toFixed(0) + '%</title>' +
          '</circle>'
        );
      });

      if (ri < activeRows.length - 1) {
        parts.push('<line x1="' + xZero + '" y1="' + (rowTop + rowH) +
                   '" x2="' + xEnd + '" y2="' + (rowTop + rowH) +
                   '" stroke="#e8ecf0" stroke-width="1"/>');
      }
    });

    parts.push('<line class="ma-bar-axis" x1="' + xZero + '" y1="' + marginTop +
               '" x2="' + xZero + '" y2="' + (dataAreaH - marginBottom) + '"/>');

    // SVG legend
    if (legendRows.length > 0 || showCatAvgNote) {
      var legendStartY = chartHeight - legendH + legendPadT;
      var legendParts = ['<g class="ma-bar-legend" font-size="10" fill="#334155">'];
      for (var lri = 0; lri < legendRows.length; lri++) {
        var lrow = legendRows[lri];
        for (var lci = 0; lci < lrow.length; lci++) {
          var le = lrow[lci];
          var lcx = le.x + 5;
          var lcy = legendStartY + lri * legendRowH;
          var lr  = le.item.isFocal ? 5.5 : 4.5;
          var lop = le.item.isFocal ? '1' : '0.75';
          legendParts.push(
            '<circle cx="' + lcx + '" cy="' + lcy + '" r="' + lr + '"' +
            ' fill="' + le.item.col + '" fill-opacity="' + lop + '"/>',
            '<text x="' + (lcx + 9) + '" y="' + lcy + '"' +
            ' dominant-baseline="middle"' +
            ' font-weight="' + (le.item.isFocal ? '700' : '400') + '">' +
            escHtml(le.item.label) + '</text>'
          );
        }
      }
      if (showCatAvgNote) {
        var catAvgNoteY = legendStartY + legendRows.length * legendRowH + Math.round(legendRowH / 2);
        legendParts.push(
          '<line x1="8" y1="' + catAvgNoteY + '" x2="28" y2="' + catAvgNoteY + '"' +
          ' stroke="#64748b" stroke-width="1.5" stroke-dasharray="3 3"/>',
          '<text x="32" y="' + catAvgNoteY + '" dominant-baseline="middle"' +
          ' fill="#64748b">Category average</text>'
        );
      }
      legendParts.push('</g>');
      parts.push(legendParts.join(''));
    }

    svg.innerHTML = parts.join('');
  }

  // -------------------------------------------------------------- insight box
  function insightKey(panel, stim) {
    var pd = panel.__maData;
    var cat = pd && pd.meta && pd.meta.category_label;
    return 'turas.ma.insight:' + (cat || '') + ':' + stim;
  }

  function bindInsightBoxPersistence(panel) {
    panel.querySelectorAll('.ma-insight-box-text').forEach(function (ta) {
      var stim = ta.getAttribute('data-ma-stim');
      var key = insightKey(panel, stim);
      try {
        var saved = sessionStorage.getItem(key);
        if (saved) ta.value = saved;
      } catch (e) { /* ignore */ }
      ta.addEventListener('input', function () {
        try { sessionStorage.setItem(key, ta.value); } catch (e) {}
      });
    });
    panel.querySelectorAll('.ma-insight-box-clear').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var stim = btn.getAttribute('data-ma-stim');
        var ta = panel.querySelector('.ma-insight-box-text[data-ma-stim="' + stim + '"]');
        if (ta) {
          ta.value = '';
          try { sessionStorage.removeItem(insightKey(panel, stim)); } catch (e) {}
        }
      });
    });
  }

  // -------------------------------------------------------------- export
  function bindExport(panel) {
    panel.querySelectorAll('.ma-export-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var stim = btn.getAttribute('data-ma-stim');
        exportTable(panel, stim);
      });
    });
  }

  function exportTable(panel, stim) {
    var sec = panel.querySelector('.ma-matrix-section[data-ma-stim="' + stim + '"]')
           || panel.querySelector('.ma-metrics-section[data-ma-stim="' + stim + '"]')
           || panel.querySelector('[data-ma-stim="' + stim + '"]');
    if (!sec) return;
    var tbl = sec.querySelector('table');
    if (!tbl) return;

    var pd      = panel.__maData || {};
    var cat     = (pd.meta && pd.meta.category_label) || 'category';
    var focal   = (pd.meta && pd.meta.focal_brand_code) || '';
    var maState = panel.__maState || {};
    var mode    = ((maState.basemode && maState.basemode[stim]) || 'total');
    var vis     = (maState.visible && maState.visible[stim]) || {};
    var pctAttr = (mode === 'aware') ? 'data-ma-pct-aware' : 'data-ma-pct';
    var nAttr   = (mode === 'aware') ? 'data-ma-n-aware'   : 'data-ma-n-total';
    var baseLabel = (mode === 'aware') ? '% of those aware of brand' : '% of total sample';

    var title = (stim === 'attributes') ? 'Brand Attributes'
              : (stim === 'ceps')       ? 'Category Entry Points'
              : 'Headline Metrics';

    var tdStyle = 'border:1px solid #ccc;padding:4px 8px;font-family:Calibri,sans-serif;font-size:12px;';
    var html = '<html xmlns:o="urn:schemas-microsoft-com:office:office"'
      + ' xmlns:x="urn:schemas-microsoft-com:office:excel"'
      + ' xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="UTF-8">'
      + '<style>td,th{' + tdStyle + '}'
      + 'th{background:#1a2744;color:#fff;font-weight:700;}'
      + '.mode{background:#e8edf5;color:#1a2744;font-style:italic;font-size:11px;}'
      + '.focal{font-weight:700;background:#eef4fb;}'
      + '.count{color:#888;font-size:11px;}'
      + '.base-row{background:#f0f4f8;font-style:italic;}'
      + '</style></head><body><table>';

    // Header row — strip sort buttons
    var ths = Array.from(tbl.querySelectorAll('thead th'));
    var colCount = ths.length;
    var headers = ths.map(function (th) {
      var clone = th.cloneNode(true);
      clone.querySelectorAll('button, input').forEach(function (el) { el.remove(); });
      return clone.textContent.trim();
    });
    html += '<tr><td class="mode" colspan="' + colCount + '">Base: ' + baseLabel + ' \u2014 ' + escHtml(cat) + '</td></tr>';
    html += '<tr>' + headers.map(function (h) { return '<th>' + escHtml(h) + '</th>'; }).join('') + '</tr>';

    // Body rows
    tbl.querySelectorAll('tbody tr').forEach(function (tr) {
      if (tr.style.display === 'none') return;
      var tds = Array.from(tr.querySelectorAll('td'));

      // Base row — show n= per brand
      if (tr.classList.contains('ma-row-base')) {
        html += '<tr>';
        tds.forEach(function (td) {
          var brand = td.getAttribute('data-ma-brand');
          if (brand && brand !== '__avg__') {
            var n = td.getAttribute(nAttr);
            html += '<td class="base-row">' + (n ? 'n=' + n : '\u2014') + '</td>';
          } else {
            html += '<td class="base-row">' + td.textContent.trim() + '</td>';
          }
        });
        html += '</tr>';
        return;
      }

      // % row
      html += '<tr>';
      tds.forEach(function (td) {
        var brand = td.getAttribute('data-ma-brand');
        if (!brand) {
          // label column
          var clone = td.cloneNode(true);
          clone.querySelectorAll('button, input, .ct-sort-indicator, .ma-ci-bar-wrap, .ma-ci-limits').forEach(function (el) { el.remove(); });
          html += '<td>' + escHtml(clone.textContent.trim()) + '</td>';
        } else if (brand === '__avg__') {
          var pct = parseFloat(td.getAttribute('data-ma-pct'));
          var ciLo = td.getAttribute('data-ma-ci-lower');
          var ciHi = td.getAttribute('data-ma-ci-upper');
          var ciStr = (ciLo && ciHi) ? ' (' + Math.round(parseFloat(ciLo)) + '\u2013' + Math.round(parseFloat(ciHi)) + '%)' : '';
          html += '<td>' + (isNaN(pct) ? '\u2014' : Math.round(pct) + '%' + ciStr) + '</td>';
        } else {
          if (vis[brand] === false) { html += '<td>\u2014</td>'; return; }
          var isFocal = (brand === focal);
          var cls = isFocal ? ' class="focal"' : '';
          var pct = parseFloat(td.getAttribute(pctAttr));
          html += '<td' + cls + '>' + (isNaN(pct) ? '\u2014' : Math.round(pct) + '%') + '</td>';
        }
      });
      html += '</tr>';

      // n= row — skip for avg column
      html += '<tr>';
      tds.forEach(function (td) {
        var brand = td.getAttribute('data-ma-brand');
        if (!brand) {
          var clone = td.cloneNode(true);
          clone.querySelectorAll('button, input').forEach(function (el) { el.remove(); });
          html += '<td class="count">' + escHtml(clone.textContent.trim()) + ' (n=)</td>';
        } else if (brand === '__avg__') {
          html += '<td class="count">\u2014</td>';
        } else {
          if (vis[brand] === false) { html += '<td class="count">\u2014</td>'; return; }
          var n = td.getAttribute(nAttr);
          html += '<td class="count">' + (n ? 'n=' + n : '\u2014') + '</td>';
        }
      });
      html += '</tr>';
    });

    html += '</table></body></html>';

    var blob = new Blob([html], { type: 'application/vnd.ms-excel;charset=utf-8' });
    var url  = URL.createObjectURL(blob);
    var a    = document.createElement('a');
    a.href = url;
    a.download = 'ma_' + stim + '_' + (cat || 'category').toLowerCase().replace(/[^a-z0-9]+/g, '_') + '.xls';
    document.body.appendChild(a); a.click();
    setTimeout(function () { URL.revokeObjectURL(url); a.remove(); }, 0);
  }

  // -------------------------------------------------------------- pin dropdown
  function bindPinDropdown(panel) {
    panel.querySelectorAll('.ma-pin-dropdown-btn').forEach(function (btn) {
      btn.addEventListener('click', function (ev) {
        ev.stopPropagation();
        openPinDropdown(panel, btn);
      });
    });
  }

  function openPinDropdown(panel, btn) {
    panel.querySelectorAll('.ma-pin-dropdown').forEach(function (el) { el.remove(); });

    var activeTab = panel.querySelector('.ma-subtab-btn.active');
    var activeKey = activeTab ? activeTab.getAttribute('data-ma-subtab-target') : 'attributes';
    var opts = [];
    if (activeKey === 'attributes' || activeKey === 'ceps') {
      opts.push({ key: 'matrix', label: 'Matrix table' });
      opts.push({ key: 'chart',  label: 'Bar chart' });
      opts.push({ key: 'insight',label: 'Insight note' });
    } else if (activeKey === 'metrics') {
      opts.push({ key: 'hero',    label: 'Headline metric cards' });
      opts.push({ key: 'brandtbl',label: 'Brand metric table' });
      opts.push({ key: 'scatter', label: 'Mental Space scatter' });
      opts.push({ key: 'bars',    label: 'MMS vs SOM chart' });
      opts.push({ key: 'ranking', label: 'CEP penetration ranking' });
      opts.push({ key: 'insight', label: 'Insight note' });
    } else if (activeKey === 'advantage') {
      opts.push({ key: 'matrix',   label: 'Mental Advantage matrix' });
      opts.push({ key: 'quadrant', label: 'Strategic quadrant chart' });
      opts.push({ key: 'actions',  label: 'Action list (Defend / Build / Maintain)' });
      opts.push({ key: 'insight',  label: 'Insight note' });
    }

    var dd = document.createElement('div');
    dd.className = 'ma-pin-dropdown';
    dd.style.cssText = 'position:absolute;z-index:400;background:#fff;border:1px solid #cbd5e1;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,0.08);padding:8px;min-width:220px;font-size:12px;';
    dd.innerHTML = '<div style="font-weight:600;margin-bottom:6px;color:#334155;">Pin sections</div>'
      + opts.map(function (o) {
        return '<label style="display:block;padding:3px 0;"><input type="checkbox" data-ma-pin-opt="' + o.key + '" style="margin-right:6px;">' + escHtml(o.label) + '</label>';
      }).join('')
      + '<div style="text-align:right;margin-top:8px;"><button type="button" class="ma-pin-confirm" style="background:var(--ma-brand,#1A5276);color:#fff;border:none;border-radius:4px;padding:4px 10px;cursor:pointer;">Pin selected</button></div>';

    var rect = btn.getBoundingClientRect();
    var panelRect = panel.getBoundingClientRect();
    dd.style.right = Math.max(0, panelRect.right - rect.right) + 'px';
    dd.style.top = (rect.bottom - panelRect.top + 4) + 'px';
    panel.appendChild(dd);

    function closeOnce() {
      dd.remove();
      document.removeEventListener('click', closeOnce);
    }
    setTimeout(function () { document.addEventListener('click', closeOnce); }, 0);
    dd.addEventListener('click', function (e) { e.stopPropagation(); });

    dd.querySelector('.ma-pin-confirm').addEventListener('click', function () {
      var selected = Array.from(dd.querySelectorAll('input:checked')).map(function (inp) {
        return inp.getAttribute('data-ma-pin-opt');
      });
      if (!selected.length) { closeOnce(); return; }
      pinSections(panel, activeKey, selected);
      closeOnce();
    });
  }

  function captureSvg(el) {
    if (!el) return '';
    var svg = el.querySelector('svg:not(button svg)');
    if (!svg) return '';
    var clone = svg.cloneNode(true);
    var vb = svg.getAttribute('viewBox');
    if (vb) { var p = vb.split(/\s+/); clone.setAttribute('width', p[2]); clone.setAttribute('height', p[3]); }
    return clone.outerHTML;
  }

  function _maStrip(html) {
    return (typeof window.brStripInteractive === 'function')
      ? window.brStripInteractive(html)
      : html;
  }

  function captureTable(el) {
    if (!el) return '';
    var tbl = el.querySelector('table');
    if (!tbl) return '';
    var html = (typeof TurasPins !== 'undefined' && TurasPins.capturePortableHtml)
      ? TurasPins.capturePortableHtml(tbl) : tbl.outerHTML;
    return _maStrip(html);
  }

  // Capture arbitrary HTML for div-based sections (no SVG/table).
  function captureHtml(el) {
    if (!el) return '';
    var html = (typeof TurasPins !== 'undefined' && TurasPins.capturePortableHtml)
      ? TurasPins.capturePortableHtml(el) : el.outerHTML;
    return _maStrip(html);
  }

  function pinSections(panel, activeKey, optKeys) {
    if (typeof TurasPins === 'undefined') return;
    var pd = panel.__maData || {};
    var cat = (pd.meta && pd.meta.category_label) || 'Category';
    var focal = (pd.meta && pd.meta.focal_brand_name) || '';
    var baseTitle = 'Mental Availability \u2014 ' + cat;

    if (activeKey === 'attributes' || activeKey === 'ceps') {
      // Combine all selected sections into ONE pin card
      var subLabel = activeKey === 'attributes' ? 'Brand Attributes' : 'Category Entry Points';
      var chartSvg = '', tableHtml = '', insightText = '';
      if (optKeys.indexOf('matrix') >= 0) {
        var matSec = panel.querySelector('.ma-matrix-section[data-ma-stim="' + activeKey + '"]');
        tableHtml = captureTable(matSec);
      }
      if (optKeys.indexOf('chart') >= 0) {
        var chartSec = panel.querySelector('.ma-chart-section[data-ma-stim="' + activeKey + '"]');
        chartSvg = captureSvg(chartSec);
      }
      if (optKeys.indexOf('insight') >= 0) {
        var ta = panel.querySelector('.ma-insight-box-text[data-ma-stim="' + activeKey + '"]');
        if (ta) insightText = ta.value.trim();
      }
      // Active "Base:" toggle for the current MA sub-tab. Scope to the
      // sub-tab wrapper so we don't accidentally read another sub-tab's
      // toggle (attributes vs ceps share the same panel).
      var maSubtab = panel.querySelector('.ma-subtab[data-ma-subtab="' + activeKey + '"]') || panel;
      var maBaseLabel = (typeof window.brReadBaseLabel === 'function')
        ? window.brReadBaseLabel(maSubtab) : '';
      TurasPins.add({
        sectionKey: 'ma-' + activeKey + '-' + Date.now(),
        title: baseTitle + ' \u2014 ' + subLabel,
        subtitle: maBaseLabel ? 'Base: ' + maBaseLabel : '',
        baseText: maBaseLabel,
        chartSvg: chartSvg, chartHtml: '',
        tableHtml: tableHtml, insightText: insightText,
        pinMode: 'custom',
        pinFlags: { chart: !!chartSvg, table: !!tableHtml, insight: !!insightText }
      });

    } else if (activeKey === 'metrics') {
      // Metrics: each section is a distinct content type — pin separately
      // Insight is captured only when its checkbox is ticked, so unticked
      // metrics never get the insight surreptitiously attached to ranking.
      var metricsInsight = '';
      if (optKeys.indexOf('insight') >= 0) {
        var taM = panel.querySelector('.ma-insight-box-text[data-ma-stim="metrics"]');
        if (taM) metricsInsight = taM.value.trim();
      }
      var metricDefs = {
        hero:     { sel: '.ma-hero-strip',    label: 'Headline metrics' },
        brandtbl: { sel: '.ma-table-wrap',    label: 'Brand metrics table' },
        scatter:  { sel: '.ma-scatter-wrap',  label: 'Mental Space' },
        bars:     { sel: '.ma-bars-wrap',     label: 'MMS vs SOM' },
        ranking:  { sel: '.ma-rank-section',  label: 'CEP Ranking' }
      };
      // Iterate in canonical screen order so insight (if ticked) attaches
      // to the first pinned card rather than to whichever metric the user
      // happened to tick first in the dropdown.
      var orderedKeys = ['hero', 'brandtbl', 'scatter', 'bars', 'ranking'];
      var pinIndex = 0;
      orderedKeys.forEach(function (key) {
        if (optKeys.indexOf(key) < 0) return;
        var def = metricDefs[key];
        var el = panel.querySelector(def.sel); if (!el) return;
        var svg = captureSvg(el);
        var tbl = captureTable(el);
        // hero and ranking are div-based \u2014 no SVG, no table. Fall back to full HTML.
        var htm = (!svg && !tbl) ? captureHtml(el) : '';
        TurasPins.add({
          sectionKey: 'ma-metrics-' + key + '-' + Date.now(),
          title: baseTitle + ' \u2014 ' + def.label,
          chartSvg: svg, chartHtml: '',
          tableHtml: tbl || htm,
          insightText: (pinIndex === 0) ? metricsInsight : '',
          pinMode: 'custom',
          pinFlags: { chart: !!svg, table: !!(tbl || htm),
                      insight: (pinIndex === 0 && !!metricsInsight) }
        });
        pinIndex++;
      });
      // Insight ticked alone (no other element) — emit a standalone insight pin
      if (pinIndex === 0 && metricsInsight) {
        TurasPins.add({
          sectionKey: 'ma-metrics-insight-' + Date.now(),
          title: baseTitle + ' — Insight',
          chartSvg: '', chartHtml: '',
          tableHtml: '',
          insightText: metricsInsight,
          pinMode: 'custom',
          pinFlags: { chart: false, table: false, insight: true }
        });
      }

    } else if (activeKey === 'advantage') {
      // Capture each Mental Advantage view as a faithful snapshot of the
      // current state. Romaniuk-faithful: the base is always total
      // respondents, so the pin title hard-codes that.
      var advSubtab = panel.querySelector('.ma-subtab[data-ma-subtab="advantage"]') || panel;
      var advFocalName = (pd.meta && pd.meta.focal_brand_name) || focal || 'Focal';
      var advBaseLabel = 'total respondents (Romaniuk)';
      var advTitleSuffix = ' — Mental Advantage — ' + advFocalName + ' — Base: ' + advBaseLabel;
      var advInsight = '';
      if (optKeys.indexOf('insight') >= 0) {
        var taA = panel.querySelector('.ma-insight-box-text[data-ma-stim="advantage"]');
        if (taA) advInsight = taA.value.trim();
      }
      var advDefs = {
        matrix:   { sel: '.ma-adv-matrix-wrap',  label: 'Matrix' },
        quadrant: { sel: '.ma-adv-quadrant-view', label: 'Strategic quadrant' },
        actions:  { sel: '.ma-adv-action-list-view', label: 'Action list' }
      };
      var advOrder = ['matrix', 'quadrant', 'actions'];
      var advPinIndex = 0;
      advOrder.forEach(function (key) {
        if (optKeys.indexOf(key) < 0) return;
        var def = advDefs[key];
        var el = advSubtab.querySelector(def.sel); if (!el) return;
        var svg = captureSvg(el);
        var tbl = captureTable(el);
        var htm = (!svg && !tbl) ? captureHtml(el) : '';
        TurasPins.add({
          sectionKey: 'ma-advantage-' + key + '-' + Date.now(),
          title: cat + advTitleSuffix + ' — ' + def.label,
          subtitle: 'Focal: ' + advFocalName + ' · Base: ' + advBaseLabel,
          baseText: advBaseLabel,
          chartSvg: svg, chartHtml: '',
          tableHtml: tbl || htm,
          insightText: (advPinIndex === 0) ? advInsight : '',
          pinMode: 'custom',
          pinFlags: { chart: !!svg, table: !!(tbl || htm),
                      insight: (advPinIndex === 0 && !!advInsight) }
        });
        advPinIndex++;
      });
      if (advPinIndex === 0 && advInsight) {
        TurasPins.add({
          sectionKey: 'ma-advantage-insight-' + Date.now(),
          title: cat + advTitleSuffix + ' — Insight',
          subtitle: 'Focal: ' + advFocalName + ' · Base: ' + advBaseLabel,
          chartSvg: '', chartHtml: '', tableHtml: '',
          insightText: advInsight,
          pinMode: 'custom',
          pinFlags: { chart: false, table: false, insight: true }
        });
      }
    }
  }

  // -------------------------------------------------------------- legacy add-insight (kept for pin compat)
  function bindAddInsight(panel) { /* no-op now; full insight box covers the use case */ }

  // Re-render charts on viewport resize (debounced)
  var resizeTimer = null;
  window.addEventListener('resize', function () {
    if (resizeTimer) clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      document.querySelectorAll('.ma-panel').forEach(function (p) {
        if (!p.__maData) return;
        renderChart(p, 'attributes');
        renderChart(p, 'ceps');
        renderMAScatter(p);
        renderMABarChart(p);
        if (window.MAAdvantage) {
          try { window.MAAdvantage.render(p); } catch (e) { /* non-fatal */ }
        }
      });
    }, 120);
  });

  // Re-render charts when the containing br-tab becomes active.
  document.addEventListener('click', function (ev) {
    var tabBtn = ev.target && ev.target.closest && ev.target.closest('.br-tab-btn');
    if (!tabBtn) return;
    setTimeout(function () {
      document.querySelectorAll('.ma-panel').forEach(function (p) {
        if (!p.__maData) return;
        // Only render the sections whose own clientWidth is now > 0
        p.querySelectorAll('.ma-chart-section').forEach(function (s) {
          if (s.clientWidth > 0) {
            renderChart(p, s.getAttribute('data-ma-stim'));
          }
        });
      });
    }, 20);
  });
})();
