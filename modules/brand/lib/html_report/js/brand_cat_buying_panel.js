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
      showchart: { loyalty: true, dist: true },
      visible: {
        loyalty: makeVisMap(pd.brandCodes),
        dist:    makeVisMap(pd.brandCodes)
      },
      emphasis: { loyalty: 'all', dist: 'all' }
    };

    colourCbChips(panel);
    bindCbSubTabs(panel);
    bindCbChips(panel);
    bindCbShowChart(panel);
    bindCbEmphasisChips(panel);

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
  /* Chip colouring (brand chips — both panel-level and per-tab)             */
  /* ---------------------------------------------------------------------- */

  function colourCbChips(panel) {
    var pd    = panel.__cbData;
    var focal = pd && pd.focalBrand;
    panel.querySelectorAll('.fn-rel-brand-chip[data-cb-brand]').forEach(function (chip) {
      var code = chip.getAttribute('data-cb-brand');
      var col  = getBrandColour(pd, code);
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
        var chartArea = panel.querySelector('.fn-rel-chart-area[data-cb-scope="' + scope + '"]');
        if (chartArea) {
          if (cb.checked) { chartArea.removeAttribute('hidden'); renderCbStackedBars(panel, scope); }
          else              chartArea.setAttribute('hidden', '');
        }
      });
    });
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

    /* 3b. Brand Performance Summary: focal row to top + FOCAL badge */
    panel.querySelectorAll('.cb-brand-freq-table').forEach(function (table) {
      var tbody  = table.querySelector('tbody');
      if (!tbody) return;
      var avgRow = tbody.querySelector('.cbp-avg-row');
      tbody.querySelectorAll('tr[data-brand]').forEach(function (tr) {
        var bc      = tr.getAttribute('data-brand');
        var isFocal = bc === brandCode;
        if (isFocal) { tr.classList.remove('cbp-brand-row'); tr.classList.add('focal-row'); }
        else          { tr.classList.remove('focal-row');    tr.classList.add('cbp-brand-row'); }
        var badge = tr.querySelector('.cb-focal-badge');
        if (isFocal && !badge) {
          var nameCell = tr.querySelector('.brand-col');
          if (nameCell) {
            badge = document.createElement('span');
            badge.className = 'cb-focal-badge';
            badge.textContent = 'FOCAL';
            nameCell.appendChild(badge);
          }
        } else if (!isFocal && badge) {
          badge.parentNode.removeChild(badge);
        }
        if (isFocal) {
          if (avgRow) tbody.insertBefore(tr, avgRow);
          else        tbody.insertBefore(tr, tbody.firstChild);
        }
      });
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
