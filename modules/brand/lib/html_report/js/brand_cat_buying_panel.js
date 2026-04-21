/* ==========================================================================
   Brand Category Buying Panel — interactivity
   ==========================================================================
   Two modes of interactivity:

   Legacy globals (inline onclick):
     _cbToggleDetails(catCode)   Expand/collapse descriptive detail.
     _cbSetFocal(btn, catCode)   Change focal brand (KPI chips + table).

   Panel init (DOMContentLoaded):
     initCbPanel(panel)          Initialise sub-tabs, brand chips, row
                                 visibility, emphasis chips, show-chart
                                 toggle, and stacked bar charts for loyalty
                                 and dist sub-tabs.

   SIZE-EXCEPTION: rendering pipeline (sub-tab nav, stacked bar builder,
   chip colouring, row visibility). Decomposing would fragment a sequential flow.
   ========================================================================== */

(function () {
  if (window.__BRAND_CB_PANEL_INIT__) return;
  window.__BRAND_CB_PANEL_INIT__ = true;

  /* ---------------------------------------------------------------------- */
  /* Constants                                                                */
  /* ---------------------------------------------------------------------- */

  var PALETTE = ['#4e79a7', '#f28e2b', '#e15759', '#76b7b2', '#59a14f',
                 '#edc948', '#b07aa1', '#ff9da7', '#9c755f', '#bab0ac'];

  /* Segment colours per scope */
  var SEG_COLORS = {
    loyalty: ['#166534', '#4ade80', '#fbbf24', '#e2e8f0'],
    dist:    ['#bfdbfe', '#60a5fa', '#2563eb', '#1e3a8a']
  };

  /* ---------------------------------------------------------------------- */
  /* Helpers                                                                  */
  /* ---------------------------------------------------------------------- */

  function onReady(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  function escHtml(s) {
    if (s == null) return '';
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;')
      .replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function getBrandColour(pd, code) {
    if (!pd || !code) return '#94a3b8';
    if (pd.brandColours && pd.brandColours[code]) return pd.brandColours[code];
    if (pd.focalBrand === code) return pd.focalColour || '#1A5276';
    var idx = (pd.brandCodes || []).indexOf(code);
    if (idx < 0) idx = 0;
    return PALETTE[idx % PALETTE.length];
  }

  function getBrandName(pd, code) {
    var codes = (pd && pd.brandCodes) || [];
    var names = (pd && pd.brandNames) || [];
    var idx   = codes.indexOf(code);
    return idx < 0 ? code : (names[idx] || code);
  }

  /* ---------------------------------------------------------------------- */
  /* Panel init (runs once per .cb-panel on DOMContentLoaded)                */
  /* ---------------------------------------------------------------------- */

  onReady(function () {
    document.querySelectorAll('.cb-panel').forEach(initCbPanel);
  });

  function initCbPanel(panel) {
    var scriptEl = panel.querySelector('script.cb-panel-chart-data');
    if (!scriptEl) return;
    var pd;
    try { pd = JSON.parse(scriptEl.textContent || '{}'); }
    catch (e) { return; }
    panel.__cbData = pd;

    var makeVisMap = function (codes) {
      var m = {};
      (codes || []).forEach(function (c) { m[c] = true; });
      return m;
    };

    panel.__cbState = {
      showchart: { loyalty: true, dist: true, brands: false },
      heatmap:   { brands: false },
      brandsChartCol: 'pen',
      visible: {
        loyalty: makeVisMap(pd.brandCodes),
        dist:    makeVisMap(pd.brandCodes),
        brands:  makeVisMap(pd.brandCodes)
      },
      emphasis: { loyalty: 'all', dist: 'all' }
    };

    colourCbChips(panel);
    bindCbSubTabs(panel);
    bindCbChips(panel);
    bindCbPanelChips(panel);
    bindCbShowChart(panel);
    bindCbHeatmapToggle(panel);
    bindCbSort(panel);
    bindCbEmphasisChips(panel);
    bindCbBrandsFocusSelect(panel);
    bindCbBrandsChartCol(panel);
    relocateCbToolbarIntoControls(panel);

    renderCbStackedBars(panel, 'loyalty');
    renderCbStackedBars(panel, 'dist');

    /* Re-render when chart areas come into view (hidden tabs) */
    if (typeof IntersectionObserver !== 'undefined') {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (!e.isIntersecting || e.target.clientWidth <= 0) return;
          var scope = e.target.getAttribute('data-cb-scope');
          if (scope) renderCbStackedBars(panel, scope);
        });
      }, { root: null, threshold: 0.01 });
      panel.querySelectorAll('.fn-rel-chart-area').forEach(function (s) { io.observe(s); });
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Relocate section toolbar pin+export into the Brand Summary controls bar */
  /* ---------------------------------------------------------------------- */

  function relocateCbToolbarIntoControls(panel) {
    var section = panel.closest('.br-element-section');
    if (!section) return;
    var toolbar = section.querySelector(':scope > .cb-toolbar-top');
    if (!toolbar || toolbar.__cbRelocated) return;
    var controls = panel.querySelector(
      '.cb-controls-bar[data-cb-scope="brands"]');
    if (!controls) return;
    var pinBtn    = toolbar.querySelector('.br-pin-btn');
    var exportBtn = toolbar.querySelector('.br-export-btn');
    if (!pinBtn && !exportBtn) return;
    var wrap = document.createElement('span');
    wrap.className = 'cb-toolbar-relocated';
    if (pinBtn)    wrap.appendChild(pinBtn);
    if (exportBtn) wrap.appendChild(exportBtn);
    controls.appendChild(wrap);
    toolbar.style.display = 'none';
    toolbar.__cbRelocated = true;
  }

  /* ---------------------------------------------------------------------- */
  /* Chip colouring (brand chips — both panel-level and per-tab)             */
  /* ---------------------------------------------------------------------- */

  function colourCbChips(panel) {
    var pd    = panel.__cbData;
    var focal = pd && pd.focalBrand;
    /* Panel-level chips use data-brand; per-tab chips use data-cb-brand */
    panel.querySelectorAll(
      '.fn-rel-brand-chip[data-cb-brand], .fn-rel-brand-chip[data-brand]'
    ).forEach(function (chip) {
      var code = chip.getAttribute('data-cb-brand') ||
                 chip.getAttribute('data-brand');
      if (!code) return;
      var col  = getBrandColour(pd, code);
      chip.style.setProperty('--brand-chip-color', col);
      chip.style.backgroundColor = col;
      chip.style.borderColor     = col;
      chip.style.color           = '#fff';
      chip.style.fontWeight      = code === focal ? '700' : '500';
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Sub-tab switching                                                        */
  /* ---------------------------------------------------------------------- */

  function bindCbSubTabs(panel) {
    panel.querySelectorAll('.cb-subtab-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var target = btn.getAttribute('data-cb-tab');
        panel.querySelectorAll('.cb-subtab-btn').forEach(function (b) {
          b.classList.toggle('active', b === btn);
        });
        panel.querySelectorAll('.cb-subtab').forEach(function (sp) {
          var show = sp.getAttribute('data-cb-tab') === target;
          if (show) sp.removeAttribute('hidden');
          else      sp.setAttribute('hidden', '');
        });
        panel.classList.toggle('cb-on-context', target === 'context');
        if (target === 'loyalty' || target === 'dist') {
          renderCbStackedBars(panel, target);
        }
      });
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Brand visibility chips (per-tab: fn-rel-brand-chip with data-cb-scope)  */
  /* ---------------------------------------------------------------------- */

  function bindCbChips(panel) {
    panel.querySelectorAll('.fn-rel-brand-chip[data-cb-scope]').forEach(function (chip) {
      chip.addEventListener('click', function () {
        var scope = chip.getAttribute('data-cb-scope');
        var code  = chip.getAttribute('data-cb-brand');
        var vis   = panel.__cbState.visible[scope];
        if (!vis) return;
        vis[code] = !vis[code];
        chip.classList.toggle('col-chip-off', !vis[code]);
        applyRowVisibility(panel, scope);
        renderCbStackedBars(panel, scope);
      });
    });
  }

  function applyRowVisibility(panel, scope) {
    var vis = panel.__cbState.visible[scope];
    var sec = panel.querySelector('.cb-rel-section[data-cb-scope="' + scope + '"]');
    if (!sec) return;
    sec.querySelectorAll('tr[data-cb-brand]').forEach(function (row) {
      var code = row.getAttribute('data-cb-brand');
      row.style.display = vis[code] === false ? 'none' : '';
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Show chart toggle                                                        */
  /* ---------------------------------------------------------------------- */

  function bindCbShowChart(panel) {
    panel.querySelectorAll('input[data-cb-action="showchart"]').forEach(function (cb) {
      cb.addEventListener('change', function () {
        var scope = cb.getAttribute('data-cb-scope');
        panel.__cbState.showchart[scope] = cb.checked;
        if (scope === 'brands') {
          var brandsArea = panel.querySelector('.cb-brands-chart-area[data-cb-scope="brands"]');
          if (brandsArea) {
            if (cb.checked) { brandsArea.removeAttribute('hidden'); renderCbBrandsChart(panel); }
            else              brandsArea.setAttribute('hidden', '');
          }
          return;
        }
        var chartArea = panel.querySelector('.fn-rel-chart-area[data-cb-scope="' + scope + '"]');
        if (chartArea) {
          if (cb.checked) { chartArea.removeAttribute('hidden'); renderCbStackedBars(panel, scope); }
          else              chartArea.setAttribute('hidden', '');
        }
      });
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Panel-level brand chips: show/hide rows in the Brand Summary table      */
  /* (chips DO NOT change the focal brand; focal changes via <select>)       */
  /* ---------------------------------------------------------------------- */

  function bindCbPanelChips(panel) {
    panel.querySelectorAll(
      '.fn-rel-brand-chip[data-cb-action="toggle-row"]'
    ).forEach(function (chip) {
      chip.addEventListener('click', function () {
        var code = chip.getAttribute('data-brand');
        if (!code) return;
        var vis = panel.__cbState.visible.brands;
        vis[code] = !vis[code];
        chip.classList.toggle('col-chip-off', !vis[code]);
        applyBrandsRowVisibility(panel);
        if (panel.__cbState.showchart.brands) renderCbBrandsChart(panel);
      });
    });
  }

  function applyBrandsRowVisibility(panel) {
    var vis = panel.__cbState.visible.brands || {};
    panel.querySelectorAll('.cb-brand-freq-table tbody tr[data-brand]').forEach(function (tr) {
      var code = tr.getAttribute('data-brand');
      tr.style.display = vis[code] === false ? 'none' : '';
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Heatmap mode toggle (flips data-cb-heatmap attr on the table)          */
  /* ---------------------------------------------------------------------- */

  function bindCbHeatmapToggle(panel) {
    panel.querySelectorAll('input[data-cb-action="heatmapmode"]').forEach(function (cb) {
      cb.addEventListener('change', function () {
        var scope = cb.getAttribute('data-cb-scope') || 'brands';
        panel.__cbState.heatmap[scope] = cb.checked;
        panel.querySelectorAll('.cb-brand-freq-table').forEach(function (table) {
          table.setAttribute('data-cb-heatmap', cb.checked ? 'on' : 'off');
        });
      });
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Sort handler for Brand Summary table (MA-style header buttons)          */
  /* ---------------------------------------------------------------------- */

  function bindCbSort(panel) {
    panel.querySelectorAll('[data-cb-action="sort"]').forEach(function (btn) {
      btn.addEventListener('click', function (ev) {
        ev.stopPropagation();
        var tableId = btn.getAttribute('data-cb-sort-table');
        var col     = parseInt(btn.getAttribute('data-cb-sort-col'), 10);
        var table   = document.getElementById(tableId);
        if (!table || isNaN(col)) return;
        var tbody = table.querySelector('tbody');
        if (!tbody) return;

        /* Cycle this button: none -> desc -> asc -> none */
        var curDir = btn.getAttribute('data-cb-sort-dir') || 'none';
        var nextDir = curDir === 'none' ? 'desc'
                   : curDir === 'desc' ? 'asc' : 'none';

        /* Reset all sort indicators on this table */
        table.querySelectorAll('[data-cb-action="sort"][data-cb-sort-table="' + tableId + '"]')
          .forEach(function (b) { b.setAttribute('data-cb-sort-dir', 'none'); });
        btn.setAttribute('data-cb-sort-dir', nextDir);

        /* Only sortable rows (exclude focal row + cat avg row) */
        var rows = Array.prototype.slice.call(
          tbody.querySelectorAll('tr.cbp-brand-row'));
        if (rows.length === 0) return;

        var readVal = function (tr) {
          var cells = tr.children;
          if (col >= cells.length) return NaN;
          var v = cells[col].getAttribute('data-v');
          var n = parseFloat(v);
          return isNaN(n) ? -Infinity : n;
        };

        if (nextDir === 'none') {
          /* Restore default order: data-default-order attr, or leave alone */
          rows.sort(function (a, b) {
            return (parseInt(a.getAttribute('data-default-order') || '0', 10)
                  - parseInt(b.getAttribute('data-default-order') || '0', 10));
          });
        } else {
          var dir = nextDir === 'asc' ? 1 : -1;
          rows.sort(function (a, b) {
            var av = readVal(a), bv = readVal(b);
            if (av === bv) return 0;
            return av > bv ? dir : -dir;
          });
        }

        /* Re-append sortable rows after the cat-avg row */
        rows.forEach(function (r) { tbody.appendChild(r); });
      });
    });

    /* Stamp default-order so the "none" state can restore the starting sequence */
    panel.querySelectorAll('.cb-brand-freq-table').forEach(function (table) {
      var tbody = table.querySelector('tbody');
      if (!tbody) return;
      var i = 0;
      tbody.querySelectorAll('tr.cbp-brand-row').forEach(function (tr) {
        tr.setAttribute('data-default-order', String(i++));
      });
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Focal <select> dropdown (delegates to _cbSetFocal for table+KPI update) */
  /* ---------------------------------------------------------------------- */

  function bindCbBrandsFocusSelect(panel) {
    /* Re-render the Brand Summary chart (if visible) after focal changes */
    var sel = panel.querySelector('select.cb-focus-select[data-cb-action="focus"]');
    if (!sel) return;
    sel.addEventListener('change', function () {
      if (panel.__cbState.showchart.brands) renderCbBrandsChart(panel);
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Brand Summary chart renderer — single column selected via dropdown       */
  /* ---------------------------------------------------------------------- */

  /* Column key -> { col index in table row, label, suffix } */
  var BRANDS_CHART_COLS = {
    pen: { col: 2, label: 'Penetration',   suffix: '%' },
    avg: { col: 3, label: 'Avg purchases', suffix: ''  },
    vol: { col: 4, label: 'Vol share',     suffix: '%' },
    scr: { col: 5, label: 'SCR obs',       suffix: '%' }
  };

  function bindCbBrandsChartCol(panel) {
    var sel = panel.querySelector('select[data-cb-action="brandschart-col"]');
    if (!sel) return;
    sel.addEventListener('change', function () {
      var key = sel.value;
      if (!BRANDS_CHART_COLS[key]) return;
      panel.__cbState.brandsChartCol = key;
      if (panel.__cbState.showchart.brands) renderCbBrandsChart(panel);
    });
  }

  function renderCbBrandsChart(panel) {
    var host = panel.querySelector('.cb-brands-chart[data-cb-brands-chart="brands"]');
    if (!host) return;
    var table = panel.querySelector('.cb-brand-freq-table');
    if (!table) { host.innerHTML = ''; return; }

    var key = (panel.__cbState && panel.__cbState.brandsChartCol) || 'pen';
    var m   = BRANDS_CHART_COLS[key] || BRANDS_CHART_COLS.pen;

    var pd    = panel.__cbData || {};
    var focal = pd.focalBrand;
    var vis   = (panel.__cbState.visible && panel.__cbState.visible.brands) || {};

    var rows = Array.prototype.slice.call(
      table.querySelectorAll('tbody tr[data-brand]'));
    var avgRow = table.querySelector('tbody tr.cbp-avg-row');

    /* Collect (brand, value) pairs across all visible brands */
    var entries = [];
    var vals    = [];
    rows.forEach(function (tr) {
      var code = tr.getAttribute('data-brand');
      if (vis[code] === false) return;
      var cell = tr.children[m.col];
      if (!cell) return;
      var v = parseFloat(cell.getAttribute('data-v'));
      if (isNaN(v)) return;
      entries.push({ code: code, v: v, isFocal: code === focal });
      vals.push(v);
    });

    if (entries.length === 0) {
      host.innerHTML = '<div style="font-size:11px;color:#94a3b8;">No visible brands.</div>';
      return;
    }

    /* Sort descending by value (focal stays wherever — value-sorted chart) */
    entries.sort(function (a, b) { return b.v - a.v; });

    var max = Math.max.apply(null, vals);
    if (!isFinite(max) || max <= 0) max = 1;

    /* Category average marker */
    var avgV = NaN;
    if (avgRow && avgRow.children[m.col]) {
      avgV = parseFloat(avgRow.children[m.col].getAttribute('data-v'));
    }
    var avgPct = (!isNaN(avgV) && max > 0) ? Math.min(100, (avgV / max) * 100) : null;
    var avgTxt = !isNaN(avgV)
      ? (m.suffix === '%' ? avgV.toFixed(0) + '%' : avgV.toFixed(1))
      : null;

    var html = '';
    html += '<div class="cb-brands-chart-title">' + escHtml(m.label)
         +  (avgTxt ? ' <span style="font-weight:400;color:#64748b;">(cat avg ' + escHtml(avgTxt) + ')</span>' : '')
         +  '</div>';

    entries.forEach(function (e) {
      var pct  = Math.max(0, (e.v / max) * 100);
      var col  = getBrandColour(pd, e.code);
      var name = getBrandName(pd, e.code);
      var txt  = (m.suffix === '%'
        ? e.v.toFixed(0) + '%'
        : e.v.toFixed(e.v < 10 ? 2 : 1));
      html += '<div class="cb-brands-chart-row">'
           +   '<div class="cb-brands-chart-label' + (e.isFocal ? ' focal' : '') + '">'
           +     escHtml(name) + (e.isFocal ? ' \u2605' : '')
           +   '</div>'
           +   '<div class="cb-brands-chart-bar-track">'
           +     '<div class="cb-brands-chart-bar" style="width:' + pct.toFixed(1)
           +       '%;background:' + col + ';">' + txt + '</div>'
           +     (avgPct !== null
             ? '<div class="cb-brands-chart-avg-line" title="Category avg" '
               + 'style="left:' + avgPct.toFixed(1) + '%;"></div>'
             : '')
           +   '</div>'
           + '</div>';
    });

    host.innerHTML = html;
  }

  /* ---------------------------------------------------------------------- */
  /* Emphasis chips (Emphasise: All | Seg1 | Seg2 …)                        */
  /* ---------------------------------------------------------------------- */

  function bindCbEmphasisChips(panel) {
    panel.querySelectorAll('.cb-rel-seg-chip').forEach(function (chip) {
      chip.addEventListener('click', function () {
        var scope = chip.getAttribute('data-cb-scope');
        var emph  = chip.getAttribute('data-cb-emphasis');
        if (!scope) return;
        panel.__cbState.emphasis[scope] = emph;
        panel.querySelectorAll('.cb-rel-seg-chip[data-cb-scope="' + scope + '"]')
          .forEach(function (c) { c.classList.toggle('active', c === chip); });
        renderCbStackedBars(panel, scope);
      });
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Stacked bar chart renderer (Brand Attitude style)                       */
  /* ---------------------------------------------------------------------- */

  function renderCbStackedBars(panel, scope) {
    if (panel.__cbState && panel.__cbState.showchart[scope] === false) return;

    var pd       = panel.__cbData;
    var block    = pd && (scope === 'loyalty' ? pd.loyalty : pd.dist);
    if (!pd || !block) return;

    var chartDiv = panel.querySelector('.fn-rel-chart[data-cb-stacked-chart="' + scope + '"]');
    if (!chartDiv) return;

    var vis    = (panel.__cbState.visible  || {})[scope] || {};
    var emph   = (panel.__cbState.emphasis || {})[scope] || 'all';
    var focal  = pd.focalBrand;
    var colors = SEG_COLORS[scope] || SEG_COLORS.loyalty;

    /* Brand order: focal first */
    var ordered = [];
    if (focal && (pd.brandCodes || []).indexOf(focal) >= 0) ordered.push(focal);
    (pd.brandCodes || []).forEach(function (c) { if (c !== focal) ordered.push(c); });
    var visibleBrands = ordered.filter(function (c) { return vis[c] !== false; });

    var segCodes  = block.codes  || [];
    var segLabels = block.labels || [];
    var catAvg    = block.catAvg || [];

    var rows = [];

    /* Category average row (top) */
    rows.push(renderStackedRow(
      'Category avg', catAvg, segCodes, colors, emph, false, true));

    /* Per-brand rows */
    visibleBrands.forEach(function (bc) {
      var vals    = (block.values || {})[bc] || [];
      var isFocal = bc === focal;
      var name    = getBrandName(pd, bc);
      rows.push(renderStackedRow(name, vals, segCodes, colors, emph, isFocal, false, bc));
    });

    chartDiv.innerHTML = rows.join('');
  }

  function renderStackedRow(label, vals, segCodes, colors, emph, isFocal, isAvg, brandCode) {
    var total = 0;
    vals.forEach(function (v) { if (v != null && !isNaN(v)) total += v; });
    if (total <= 0) total = 100;

    var segHtml = '';
    vals.forEach(function (v, i) {
      if (v == null || isNaN(v) || v <= 0) return;
      var pct    = (v / total) * 100;
      var isEmph = emph === 'all' || emph === segCodes[i];
      var col    = isEmph ? colors[i] : 'rgba(148,163,184,0.18)';
      var inside = pct >= 10
        ? '<span style="font-size:11px;font-weight:700;color:#fff;padding:0 4px;">' + v.toFixed(0) + '%</span>'
        : '';
      segHtml += '<div class="fn-rel-seg" style="width:' + pct.toFixed(1) + '%;background:' + col + ';">' + inside + '</div>';
    });

    var rowCls = 'fn-rel-bar-row';
    if (isFocal) rowCls += ' fn-rel-bar-row-focal';
    if (isAvg)   rowCls += ' fn-rel-bar-row-avg';

    var labelHtml = escHtml(label);
    if (isFocal) {
      labelHtml += ' <span style="display:inline-block;font-size:9px;font-weight:700;background:var(--cb-focal-colour,#1A5276);color:#fff;border-radius:3px;padding:1px 4px;margin-left:4px;">FOCAL</span>';
    }

    var dbAttr = brandCode ? ' data-cb-brand="' + escHtml(brandCode) + '"' : '';

    return '<div class="' + rowCls + '"' + dbAttr + '>'
      + '<div class="fn-rel-bar-label">' + labelHtml + '</div>'
      + '<div class="fn-rel-bar-area"><div class="fn-rel-bar-track">'
      + segHtml
      + '</div></div>'
      + '</div>';
  }

  /* ---------------------------------------------------------------------- */
  /* Collapsible descriptive detail                                          */
  /* ---------------------------------------------------------------------- */

  window._cbToggleDetails = function (catCode) {
    var el = document.getElementById('cb-details-' + catCode);
    if (!el) return;
    var isOpen = el.classList.contains('open');
    el.classList.toggle('open', !isOpen);
    var btn = el.previousElementSibling;
    if (btn) {
      btn.textContent = isOpen
        ? '+ Descriptive detail (frequency, repertoire)'
        : '\u2212 Descriptive detail (frequency, repertoire)';
    }
  };

  /* ---------------------------------------------------------------------- */
  /* Focal brand picker (panel-level: updates tables + re-renders charts)    */
  /* ---------------------------------------------------------------------- */

  window._cbSetFocal = function (btn, catCode) {
    var panel = btn.closest('.cb-panel');
    if (!panel) return;

    /* Handle both <select> (focal dropdown) and <button> (legacy chips) */
    var brandCode = btn.tagName === 'SELECT'
      ? btn.value
      : btn.getAttribute('data-brand');
    var focalColour = panel.dataset.focalColour || '#1A5276';

    /* Capture the previous focal BEFORE any class mutations below
       (section 3 strips focal-row from non-new-focal rows, which would
        otherwise hide which row was the outgoing focal). */
    var prevFocal = (panel.__cbData && panel.__cbData.focalBrand) || null;
    if (!prevFocal) {
      var prevFocalRow = panel.querySelector(
        '.cb-brand-freq-table tbody tr.focal-row[data-brand]');
      if (prevFocalRow) prevFocal = prevFocalRow.getAttribute('data-brand');
    }

    /* 2. Re-colour SVG elements (legacy server-side charts) */
    var MUTED = '#94a3b8';
    panel.querySelectorAll('g[data-brand]').forEach(function (g) {
      var isFocal = g.getAttribute('data-brand') === brandCode;
      var col = isFocal ? focalColour : MUTED;
      var fw  = isFocal ? '700' : '400';
      g.querySelectorAll('.cb-brand-dot').forEach(function (dot) {
        dot.setAttribute('fill', col);
        dot.setAttribute('r', isFocal ? '6' : '4');
      });
      g.querySelectorAll('.cb-brand-label').forEach(function (lbl) {
        lbl.setAttribute('fill', col);
        lbl.setAttribute('font-weight', fw);
      });
    });

    /* 3. Focal-row class in tables */
    panel.querySelectorAll('tr[data-brand]').forEach(function (tr) {
      tr.classList.toggle('focal-row', tr.getAttribute('data-brand') === brandCode);
    });

    /* 3b. Brand Performance Summary: new focal to row 1, demoted focal to
          sortable section (below cat-avg row), FOCAL badge swapped.
          Uses prevFocal (captured above) — do NOT rely on the focal-row
          class here because section 3 already stripped it. */
    panel.querySelectorAll('.cb-brand-freq-table').forEach(function (table) {
      var tbody  = table.querySelector('tbody');
      if (!tbody) return;
      var avgRow = tbody.querySelector('.cbp-avg-row');

      /* First pass: update classes + badges */
      tbody.querySelectorAll('tr[data-brand]').forEach(function (tr) {
        var bc      = tr.getAttribute('data-brand');
        var isFocal = bc === brandCode;
        tr.classList.toggle('focal-row',     isFocal);
        tr.classList.toggle('cbp-brand-row', !isFocal);

        var badge = tr.querySelector('.cb-focal-badge');
        if (isFocal && !badge) {
          var nameCell = tr.querySelector('.ct-label-col, .brand-col');
          if (nameCell) {
            badge = document.createElement('span');
            badge.className = 'cb-focal-badge';
            badge.textContent = 'FOCAL';
            nameCell.appendChild(badge);
          }
        } else if (!isFocal && badge) {
          badge.parentNode.removeChild(badge);
        }
      });

      /* Second pass: position rows.
         Demoted-focal identity comes from prevFocal, not from a class. */
      var newFocalRow = tbody.querySelector('tr[data-brand="' + brandCode + '"]');
      var demotedRow  = (prevFocal && prevFocal !== brandCode)
        ? tbody.querySelector('tr[data-brand="' + prevFocal + '"]')
        : null;

      if (newFocalRow) {
        if (avgRow) tbody.insertBefore(newFocalRow, avgRow);
        else        tbody.insertBefore(newFocalRow, tbody.firstChild);
      }
      if (demotedRow) {
        if (avgRow && avgRow.nextSibling) {
          tbody.insertBefore(demotedRow, avgRow.nextSibling);
        } else {
          tbody.appendChild(demotedRow);
        }
      }
    });

    /* 4. Update KPI chips from embedded JSON */
    var scriptEl = document.getElementById('cb-data-' + catCode);
    if (scriptEl) {
      var kpiMap;
      try { kpiMap = JSON.parse(scriptEl.textContent); } catch (e) { kpiMap = null; }
      if (kpiMap) {
        var kd = kpiMap[brandCode];
        if (kd) {
          panel.querySelectorAll('[data-kpi]').forEach(function (chip) {
            var kpiKey = chip.getAttribute('data-kpi');
            var valEl  = chip.querySelector('[data-kpi-val]');
            var subEl  = chip.querySelector('[data-kpi-sub]');
            if (kpiKey === 'scr') {
              if (valEl) valEl.textContent = kd.scr_obs || '\u2014';
              if (subEl) subEl.textContent = kd.scr_exp || '';
            } else if (kpiKey === 'loyal') {
              if (valEl) valEl.textContent = kd.loyal_obs || '\u2014';
              if (subEl) subEl.textContent = kd.loyal_exp || '';
            } else if (kpiKey === 'nmi') {
              if (valEl) valEl.textContent = (kd.nmi || '\u2014') + (kd.nmi_arrow || '');
            }
          });
        }
      }
    }

    /* 5. Update chart data focal + re-render stacked bars */
    if (panel.__cbData) {
      panel.__cbData.focalBrand  = brandCode;
      panel.__cbData.focalColour = focalColour;
      colourCbChips(panel);
      renderCbStackedBars(panel, 'loyalty');
      renderCbStackedBars(panel, 'dist');
    }
  };

  /* ---------------------------------------------------------------------- */
  /* Helper: update active state on toggle button siblings                  */
  /* ---------------------------------------------------------------------- */

  function _cbSetActiveBtn(activeBtn) {
    if (!activeBtn) return;
    var bar = activeBtn.parentElement;
    if (!bar) return;
    bar.querySelectorAll('.cb-toggle-btn').forEach(function (b) {
      b.classList.toggle('active', b === activeBtn);
    });
  }

  /* Legacy toggle functions kept for backwards compatibility */
  window._cbDJToggle = function (containerId, yaxis, btn) {
    var c = document.getElementById(containerId);
    if (!c) return;
    c.querySelectorAll('[data-dj-yaxis]').forEach(function (el) {
      el.style.display = el.getAttribute('data-dj-yaxis') === yaxis ? '' : 'none';
    });
    _cbSetActiveBtn(btn);
  };

  window._cbDoPToggle = function (containerId, view, btn) {
    var c = document.getElementById(containerId);
    if (!c) return;
    c.querySelectorAll('[data-dop-view]').forEach(function (el) {
      el.style.display = el.getAttribute('data-dop-view') === view ? '' : 'none';
    });
    _cbSetActiveBtn(btn);
  };

}());
