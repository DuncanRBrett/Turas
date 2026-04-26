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

  /* Segment colours per scope.
     Loyalty: dark-green (sole) → light-green (primary) → amber (secondary) → dark-grey (not bought).
     Dist:    light-blue → dark-blue gradient. */
  var SEG_COLORS = {
    loyalty: ['#166534', '#4ade80', '#fbbf24', '#64748b'],
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
    var h = 5381;
    for (var i = 0; i < code.length; i++) h = ((h << 5) + h + code.charCodeAt(i)) & 0x7fffffff;
    return PALETTE[h % PALETTE.length];
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
      showchart:  { loyalty: true, dist: true, brands: false },
      heatmap:    { brands: false, loyalty: false, dist: false, dop: true },
      showcounts: { loyalty: false, dist: false, dop: false },
      brandsChartCol: 'pen',
      visible: {
        loyalty: makeVisMap(pd.brandCodes),
        dist:    makeVisMap(pd.brandCodes),
        brands:  makeVisMap(pd.brandCodes)
      },
      /* Emphasis is multi-select: an object with a {all: true} default,
         or {seg1: true, seg2: true, ...} when user picks specific segs.
         When 'all' is true, every segment renders in its colour. */
      emphasis: { loyalty: { all: true }, dist: { all: true } }
    };

    colourCbChips(panel);
    bindCbSubTabs(panel);
    bindCbChips(panel);
    bindCbPanelChips(panel);
    bindCbShowChart(panel);
    bindCbHeatmapToggle(panel);
    bindCbShowCounts(panel);
    bindCbSort(panel);
    bindCbRelSort(panel);
    bindCbDopSort(panel);
    bindCbEmphasisChips(panel);
    colourCbEmphasisChips(panel);
    bindCbBrandsFocusSelect(panel);
    bindCbBrandsChartCol(panel);
    relocateCbToolbarIntoControls(panel);
    bindCbPinBtn(panel);
    bindCbPngBtn(panel);

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
    // Move the pin/PNG/Excel buttons into the currently-active subtab's
    // .cb-controls-bar (right-aligned via .cb-toolbar-relocated). On subtabs
    // without a controls bar (Category Context), restore the toolbar to its
    // original top-of-section position so the buttons remain reachable.
    // NOTE: the toolbar is emitted as a SIBLING of .cb-panel inside
    // .br-element-section, so look up via the section, not the panel.
    var section = panel.closest('.br-element-section') || panel.parentNode;
    // Use plain querySelector (no `:scope >`) because once relocated the
    // toolbar is no longer a direct child of the section.
    var toolbar = section ? section.querySelector('.cb-toolbar-top') : null;
    if (!toolbar) return;

    if (!panel.__cbToolbarHome) {
      panel.__cbToolbarHome = {
        parent:  toolbar.parentNode,
        next:    toolbar.nextSibling,
        display: toolbar.style.display
      };
    }

    var activeTab = panel.querySelector('.cb-subtab:not([hidden])');
    var controls  = activeTab ? activeTab.querySelector('.cb-controls-bar') : null;

    if (controls) {
      toolbar.classList.add('cb-toolbar-relocated');
      toolbar.style.margin = '';
      toolbar.style.display = '';
      controls.appendChild(toolbar);
    } else {
      toolbar.classList.remove('cb-toolbar-relocated');
      var home = panel.__cbToolbarHome;
      if (home && home.parent && toolbar.parentNode !== home.parent) {
        home.parent.insertBefore(toolbar, home.next || null);
      }
    }
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

        /* Re-apply brand visibility from panel-level state to the newly-shown tab */
        if (target === 'brands') {
          applyBrandsRowVisibility(panel);
          /* Sync per-tab chip off-states to match panel-level visible map */
          syncSubTabChipStates(panel, 'brands');
        } else if (target === 'loyalty' || target === 'dist') {
          applyRowVisibility(panel, target);
          syncSubTabChipStates(panel, target);
          renderCbStackedBars(panel, target);
        }

        relocateCbToolbarIntoControls(panel);
      });
    });
  }

  /* Mirror panel-level __cbState.visible into chip off-state CSS for a scope */
  function syncSubTabChipStates(panel, scope) {
    var vis = panel.__cbState.visible[scope] || {};
    panel.querySelectorAll('.fn-rel-brand-chip[data-cb-scope="' + scope + '"]')
      .forEach(function (chip) {
        var code = chip.getAttribute('data-cb-brand');
        chip.classList.toggle('col-chip-off', vis[code] === false);
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
        /* Sync visibility across ALL scopes (brands, loyalty, dist) so the
           panel-level chip hides the brand everywhere. */
        var newState = !panel.__cbState.visible.brands[code];
        ['brands', 'loyalty', 'dist'].forEach(function (scope) {
          panel.__cbState.visible[scope][code] = newState;
        });
        chip.classList.toggle('col-chip-off', !newState);
        /* Mirror state on per-tab brand chips (if any still exist) */
        panel.querySelectorAll(
          '.fn-rel-brand-chip[data-cb-brand="' + code + '"]'
        ).forEach(function (c) {
          c.classList.toggle('col-chip-off', !newState);
        });
        applyBrandsRowVisibility(panel);
        applyRowVisibility(panel, 'loyalty');
        applyRowVisibility(panel, 'dist');
        if (panel.__cbState.showchart.brands) renderCbBrandsChart(panel);
        renderCbStackedBars(panel, 'loyalty');
        renderCbStackedBars(panel, 'dist');
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
        var flag = cb.checked ? 'on' : 'off';
        if (scope === 'brands') {
          panel.querySelectorAll('.cb-brand-freq-table').forEach(function (t) {
            t.setAttribute('data-cb-heatmap', flag);
          });
        } else if (scope === 'dop') {
          /* DoP: mark the .cb-dop-section scope table */
          var dopSec = panel.querySelector('.cb-dop-section[data-cb-scope="dop"]');
          if (dopSec) {
            dopSec.querySelectorAll('.cb-dop-table').forEach(function (t) {
              t.setAttribute('data-cb-heatmap', flag);
            });
          }
        } else {
          /* loyalty/dist: mark the .cb-rel-section scope table */
          var sec = panel.querySelector('.cb-rel-section[data-cb-scope="' + scope + '"]');
          if (sec) {
            sec.querySelectorAll('.ct-table').forEach(function (t) {
              t.setAttribute('data-cb-heatmap', flag);
            });
          }
        }
      });
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Show counts toggle (% ↔ N per seg cell on loyalty/dist tables)         */
  /* ---------------------------------------------------------------------- */

  function bindCbShowCounts(panel) {
    panel.querySelectorAll('input[data-cb-action="showcounts"]').forEach(function (cb) {
      cb.addEventListener('change', function () {
        var scope = cb.getAttribute('data-cb-scope');
        if (!scope) return;
        panel.__cbState.showcounts[scope] = cb.checked;
        /* Section lookup: DoP lives in .cb-dop-section, loyalty/dist in .cb-rel-section */
        var sec = scope === 'dop'
          ? panel.querySelector('.cb-dop-section[data-cb-scope="dop"]')
          : panel.querySelector('.cb-rel-section[data-cb-scope="' + scope + '"]');
        if (!sec) return;
        /* % stays visible always; only toggle the n=X secondary label */
        var sel = scope === 'dop' ? '.cb-dop-cell .cb-val-n' : '.cb-seg-cell .cb-val-n';
        sec.querySelectorAll(sel).forEach(function (n) {
          if (cb.checked) n.removeAttribute('hidden');
          else            n.setAttribute('hidden', '');
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

        /* Chart follows sort: re-render so bar order matches the table. */
        if (panel.__cbState && panel.__cbState.showchart
            && panel.__cbState.showchart.brands) {
          renderCbBrandsChart(panel);
        }
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
  /* Loyalty / Dist column sorting — click header to sort rows by data-v     */
  /* ---------------------------------------------------------------------- */

  function bindCbRelSort(panel) {
    panel.querySelectorAll('.cb-rel-table thead th.cb-sortable').forEach(function (th) {
      th.addEventListener('click', function () {
        var table  = th.closest('.cb-rel-table');
        if (!table) return;
        var scope  = table.closest('.cb-rel-section').getAttribute('data-cb-scope');
        var colIdx = parseInt(th.getAttribute('data-cb-sort-col'), 10);
        if (isNaN(colIdx)) return;
        var tbody  = table.querySelector('tbody');
        if (!tbody) return;

        var curDir  = th.getAttribute('data-cb-sort-dir') || 'none';
        var nextDir = curDir === 'none' ? 'desc'
                   : curDir === 'desc' ? 'asc' : 'none';

        /* Reset indicators on sibling headers in this table */
        table.querySelectorAll('thead th.cb-sortable').forEach(function (h) {
          h.setAttribute('data-cb-sort-dir', 'none');
        });
        th.setAttribute('data-cb-sort-dir', nextDir);

        /* Stamp default-order once so 'none' restores original sequence */
        if (!tbody.__cbDefaultStamped) {
          var i = 0;
          tbody.querySelectorAll('tr[data-cb-brand]').forEach(function (tr) {
            tr.setAttribute('data-default-order', String(i++));
          });
          tbody.__cbDefaultStamped = true;
        }

        var avgRow = tbody.querySelector('.cb-avg-row');
        var rows = Array.prototype.slice.call(
          tbody.querySelectorAll('tr[data-cb-brand]'));

        var readVal = function (tr) {
          var cells = tr.children;
          if (colIdx >= cells.length) return -Infinity;
          var v = cells[colIdx].getAttribute('data-v');
          var n = parseFloat(v);
          return isNaN(n) ? -Infinity : n;
        };

        if (nextDir === 'none') {
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

        rows.forEach(function (r) { tbody.appendChild(r); });
        /* Keep Category avg always first */
        if (avgRow) tbody.insertBefore(avgRow, tbody.firstChild);

        /* Chart follows sort */
        renderCbStackedBars(panel, scope);
      });
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Duplication of Purchase column sorting — click header to sort rows by   */
  /* column value. Focal row stays pinned row 1; Cat avg row stays row 2.    */
  /* ---------------------------------------------------------------------- */

  function bindCbDopSort(panel) {
    panel.querySelectorAll('.cb-dop-table thead th.cb-sortable').forEach(function (th) {
      th.addEventListener('click', function () {
        var table = th.closest('.cb-dop-table');
        if (!table) return;
        var tbody = table.querySelector('tbody');
        if (!tbody) return;
        var colIdx = parseInt(th.getAttribute('data-cb-sort-col'), 10);
        if (isNaN(colIdx)) return;

        var curDir  = th.getAttribute('data-cb-sort-dir') || 'none';
        var nextDir = curDir === 'none' ? 'desc'
                   : curDir === 'desc' ? 'asc' : 'none';

        table.querySelectorAll('thead th.cb-sortable').forEach(function (h) {
          h.setAttribute('data-cb-sort-dir', 'none');
        });
        th.setAttribute('data-cb-sort-dir', nextDir);

        /* Stamp default order once (original HTML sequence) */
        if (!tbody.__cbDopDefaultStamped) {
          var i = 0;
          tbody.querySelectorAll('tr[data-brand]').forEach(function (tr) {
            tr.setAttribute('data-default-order', String(i++));
          });
          tbody.__cbDopDefaultStamped = true;
        }

        var focal = (panel.__cbData && panel.__cbData.focalBrand) || null;
        var avgRow   = tbody.querySelector('.cb-dop-avg-row');
        var focalRow = focal ? tbody.querySelector('tr[data-brand="' + focal + '"]') : null;

        /* Sortable rows = all [data-brand] rows except the focal (pinned) */
        var allRows = Array.prototype.slice.call(tbody.querySelectorAll('tr[data-brand]'));
        var rows = allRows.filter(function (r) { return r !== focalRow; });

        var isText = colIdx === 0;
        var readText = function (tr) {
          /* Prefer row-level data-name (set in R for safe lowercase compare);
             fall back to the first cell's text. */
          var n = tr.getAttribute('data-name');
          if (n != null && n.length) return n;
          var cell = tr.children && tr.children[0];
          return cell ? (cell.textContent || '').trim().toLowerCase() : '';
        };
        var readVal = function (tr) {
          var cells = tr.children;
          if (colIdx >= cells.length) return -Infinity;
          var v = cells[colIdx].getAttribute('data-v');
          var n = parseFloat(v);
          return isNaN(n) ? -Infinity : n;
        };

        if (nextDir === 'none') {
          rows.sort(function (a, b) {
            return (parseInt(a.getAttribute('data-default-order') || '0', 10)
                  - parseInt(b.getAttribute('data-default-order') || '0', 10));
          });
        } else {
          var dir = nextDir === 'asc' ? 1 : -1;
          if (isText) {
            rows.sort(function (a, b) {
              return readText(a).localeCompare(readText(b)) * dir;
            });
          } else {
            rows.sort(function (a, b) {
              var av = readVal(a), bv = readVal(b);
              if (av === bv) return 0;
              return av > bv ? dir : -dir;
            });
          }
        }

        /* Re-attach in order: focal, avg, then sorted rows */
        if (focalRow) tbody.appendChild(focalRow);
        if (avgRow)   tbody.appendChild(avgRow);
        rows.forEach(function (r) { tbody.appendChild(r); });
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

    /* Order follows the table: entries are collected in DOM order, so whatever
       sort the user applied to the Brand Summary table is reflected here. */

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
        var key   = chip.getAttribute('data-cb-emphasis');
        if (!scope || !key) return;
        var state = panel.__cbState.emphasis[scope] || { all: true };

        if (key === 'all') {
          /* Clicking "All" always sets emphasis back to all-on */
          state = { all: true };
        } else {
          /* Clicking a seg: leave 'all' mode, toggle that seg. If nothing
             is selected, fall back to all-on so the chart never goes blank. */
          var next = {};
          Object.keys(state).forEach(function (k) {
            if (k !== 'all' && state[k]) next[k] = true;
          });
          next[key] = !next[key];
          if (!next[key]) delete next[key];
          if (Object.keys(next).length === 0) next = { all: true };
          state = next;
        }
        panel.__cbState.emphasis[scope] = state;

        /* Sync .active classes on chips for this scope */
        panel.querySelectorAll('.cb-rel-seg-chip[data-cb-scope="' + scope + '"]')
          .forEach(function (c) {
            var k = c.getAttribute('data-cb-emphasis');
            var on = (k === 'all') ? state.all === true
                                   : (state.all !== true && state[k] === true);
            c.classList.toggle('active', on);
          });
        renderCbStackedBars(panel, scope);
      });
    });
  }

  /* Apply segment colours to the emphasis chips so users see the mapping */
  function colourCbEmphasisChips(panel) {
    ['loyalty', 'dist'].forEach(function (scope) {
      var colors  = SEG_COLORS[scope] || [];
      var chips   = panel.querySelectorAll(
        '.cb-rel-seg-chip[data-cb-scope="' + scope + '"]');
      var segIdx  = 0;
      chips.forEach(function (chip) {
        var emph = chip.getAttribute('data-cb-emphasis');
        if (emph === 'all') return;
        var col = colors[segIdx] || '#94a3b8';
        chip.style.setProperty('--brand-chip-color', col);
        chip.style.borderColor = col;
        chip.style.color       = col;
        /* Active state flip handled by CSS: .active uses bg=colour, fg=#fff */
        chip.setAttribute('data-cb-seg-color', col);
        segIdx++;
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
    var emph   = (panel.__cbState.emphasis || {})[scope] || { all: true };
    var focal  = pd.focalBrand;
    var colors = SEG_COLORS[scope] || SEG_COLORS.loyalty;

    /* Brand order: follow the current DOM order of the scope's table if
       present (so sort clicks reorder the chart too); fall back to focal-first
       order from pd.brandCodes. */
    var ordered = [];
    var sec = panel.querySelector('.cb-rel-section[data-cb-scope="' + scope + '"] .cb-rel-table tbody');
    if (sec) {
      sec.querySelectorAll('tr[data-cb-brand]').forEach(function (tr) {
        var c = tr.getAttribute('data-cb-brand');
        if (c) ordered.push(c);
      });
    }
    if (ordered.length === 0) {
      if (focal && (pd.brandCodes || []).indexOf(focal) >= 0) ordered.push(focal);
      (pd.brandCodes || []).forEach(function (c) { if (c !== focal) ordered.push(c); });
    }
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
    /* Multi-select emphasis: emph.all → all segments coloured; else only
       segments in emph[segCode] render coloured. Non-emphasised go muted. */
    var emphAll = emph && emph.all === true;
    vals.forEach(function (v, i) {
      if (v == null || isNaN(v) || v <= 0) return;
      var pct    = (v / total) * 100;
      var isEmph = emphAll || (emph && emph[segCodes[i]] === true);
      var col    = isEmph ? colors[i] : 'rgba(148,163,184,0.18)';
      var txt    = v.toFixed(0) + '%';
      /* Always show % inside the segment. Small (<8%) segments get a tighter
         font & allow tiny overflow so e.g. "4%" remains readable. */
      var tiny   = pct < 8;
      var lblCls = 'fn-rel-seg-lbl' + (tiny ? ' fn-rel-seg-lbl-tiny' : '');
      var inside = '<span class="' + lblCls + '" title="' + txt + '">' + txt + '</span>';
      segHtml += '<div class="fn-rel-seg' + (tiny ? ' fn-rel-seg-tiny' : '') +
                 '" style="width:' + pct.toFixed(1) + '%;background:' + col + ';">' +
                 inside + '</div>';
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

    /* 3. Focal-row class in tables (both data-brand [brand summary] and
          data-cb-brand [loyalty/dist]) */
    panel.querySelectorAll('tr[data-brand]').forEach(function (tr) {
      tr.classList.toggle('focal-row', tr.getAttribute('data-brand') === brandCode);
    });
    panel.querySelectorAll('tr[data-cb-brand]').forEach(function (tr) {
      var isFocal = tr.getAttribute('data-cb-brand') === brandCode;
      tr.classList.toggle('fn-row-focal', isFocal);
      var lbl = tr.querySelector('.ct-label-col');
      if (!lbl) return;
      var existing = lbl.querySelector('.fn-focal-badge');
      if (isFocal && !existing) {
        var badge = document.createElement('span');
        badge.className = 'fn-focal-badge';
        badge.textContent = 'FOCAL';
        lbl.appendChild(document.createTextNode(' '));
        lbl.appendChild(badge);
      } else if (!isFocal && existing) {
        existing.parentNode.removeChild(existing);
      }
    });

    /* 3c. Loyalty / Dist tables — move new focal row to top (after cat avg),
           demoted focal returns to its natural index among non-focal rows.
           We use the original `data-default-order` stamp if present, else
           sort stays as-is. */
    panel.querySelectorAll('.cb-rel-section .cb-rel-table').forEach(function (table) {
      var tbody = table.querySelector('tbody');
      if (!tbody) return;
      var avgRow = tbody.querySelector('.cb-avg-row');
      var newFocal = tbody.querySelector('tr[data-cb-brand="' + brandCode + '"]');
      if (newFocal) {
        if (avgRow && avgRow.nextSibling) tbody.insertBefore(newFocal, avgRow.nextSibling);
        else if (avgRow)                  tbody.appendChild(newFocal);
        else                              tbody.insertBefore(newFocal, tbody.firstChild);
      }
    });

    /* 3d. Duplication of Purchase table: new focal above the Cat avg row,
           demoted focal drops below it. */
    panel.querySelectorAll('.cb-dop-table').forEach(function (table) {
      var tbody = table.querySelector('tbody');
      if (!tbody) return;
      var avgRow   = tbody.querySelector('.cb-dop-avg-row');
      var newFocal = tbody.querySelector('tr[data-brand="' + brandCode + '"]');
      var demoted  = (prevFocal && prevFocal !== brandCode)
        ? tbody.querySelector('tr[data-brand="' + prevFocal + '"]')
        : null;
      if (newFocal && avgRow) {
        tbody.insertBefore(newFocal, avgRow);
      }
      if (demoted && avgRow) {
        if (avgRow.nextSibling) tbody.insertBefore(demoted, avgRow.nextSibling);
        else                    tbody.appendChild(demoted);
      }
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

    /* 6. Panel-level brand chips: strip stale FOCAL badge from every chip,
          add it to the newly selected focal chip. (The picker chips are
          rendered server-side with the badge baked into the original focal;
          without this pass the badge stays on the wrong brand.) */
    panel.querySelectorAll(
      '.fn-rel-brand-chip[data-brand], .fn-rel-brand-chip[data-cb-brand]'
    ).forEach(function (chip) {
      var code = chip.getAttribute('data-brand') ||
                 chip.getAttribute('data-cb-brand');
      var existing = chip.querySelector('.fn-focal-badge');
      if (code === brandCode) {
        if (!existing) {
          var badge = document.createElement('span');
          badge.className = 'fn-focal-badge';
          badge.textContent = 'FOCAL';
          chip.appendChild(document.createTextNode(' '));
          chip.appendChild(badge);
        }
      } else if (existing) {
        existing.parentNode.removeChild(existing);
      }
    });
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

  /* ---------------------------------------------------------------------- */
  /* CB-aware pin: shows choose-dialog scoped to the ACTIVE sub-tab          */
  /* ---------------------------------------------------------------------- */

  function bindCbPinBtn(panel) {
    /* The toolbar is a SIBLING of .cb-panel inside .br-element-section,
       not a descendant — panel.querySelector() will never find it.
       Walk up to the section and search from there. */
    var section = panel.closest('.br-element-section') || panel.parentNode;
    var pinBtn  = section ? section.querySelector('.cb-toolbar-top .br-pin-btn') : null;
    if (!pinBtn) return;

    /* Remove the generic brTogglePin inline handler, replace with CB-aware one.
       Do NOT guard on TurasPins here — it may not be loaded yet at init time.
       Check inside the click handler instead (fires after all JS is parsed). */
    pinBtn.removeAttribute('onclick');
    pinBtn.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      cbPinDialog(panel, pinBtn);
    });
  }

  /* Context tab is structurally different from the other CB sub-tabs:
     it shows KPI cards plus two small reference tables (frequency +
     repertoire), and no chart. Each visible element gets its own
     checkbox so users can pin exactly what they see. */
  function cbDetectContextCheckboxes(activeTab, hasInsight) {
    var hasCards = !!activeTab.querySelector('.cb-kpi-strip');
    var ctxTables = activeTab.querySelectorAll('.cb-context-tables .cb-ctx-table');
    var checkboxes = [];
    if (hasCards)         checkboxes.push({ key: 'cards',    label: 'KPI cards',         available: true, checked: true });
    if (ctxTables.length > 0) checkboxes.push({ key: 'freq', label: 'Frequency table',   available: true, checked: true });
    if (ctxTables.length > 1) checkboxes.push({ key: 'rep',  label: 'Repertoire table',  available: true, checked: true });
    checkboxes.push(                            { key: 'insight', label: 'Insight',      available: true, checked: hasInsight });
    return checkboxes;
  }

  function cbCaptureContextHtml(activeTab, flags) {
    var portable = (typeof TurasPins !== 'undefined' && TurasPins.capturePortableHtml)
      ? TurasPins.capturePortableHtml
      : function (el) { return el.outerHTML; };
    var strip = (typeof window.brStripInteractive === 'function')
      ? window.brStripInteractive
      : function (s) { return s; };
    var pieces = [];
    if (flags.cards) {
      var kpi = activeTab.querySelector('.cb-kpi-strip');
      if (kpi) pieces.push(strip(portable(kpi)));
    }
    var ctxTables = activeTab.querySelectorAll('.cb-context-tables .cb-ctx-table');
    if (flags.freq && ctxTables[0]) pieces.push(strip(portable(ctxTables[0])));
    if (flags.rep  && ctxTables[1]) pieces.push(strip(portable(ctxTables[1])));
    return pieces.join('');
  }

  function cbPinDialog(panel, pinBtn) {
    if (typeof TurasPins === 'undefined') return;

    var activeTab = panel.querySelector('.cb-subtab:not([hidden])');
    if (!activeTab) return;
    var tabKey = activeTab.getAttribute('data-cb-tab') || '';

    /* Insight lives at section level */
    var section = panel.closest('.br-element-section') || panel.parentNode;
    var editor = section ? section.querySelector('.br-insight-editor') : null;
    var hasInsight = !!(editor && editor.value.trim());

    /* Context tab branch — different element set (cards + 2 tables) */
    if (tabKey === 'context') {
      var ctxBoxes = cbDetectContextCheckboxes(activeTab, hasInsight);
      var anchorCtx = pinBtn.closest('.br-section-toolbar') || pinBtn.parentElement;
      TurasPins.showCheckboxPopover(pinBtn, ctxBoxes, function (flags) {
        cbExecuteContextPin(panel, activeTab, flags, editor);
      }, anchorCtx);
      return;
    }

    /* Detect available content in the active sub-tab only */
    var hasChart = false;
    var hasTable = false;

    if (tabKey === 'brands') {
      var chartArea = activeTab.querySelector('.cb-brands-chart-area');
      hasChart = !!(chartArea && !chartArea.hasAttribute('hidden'));
      hasTable = !!(activeTab.querySelector('.cb-brand-freq-table'));
    } else if (tabKey === 'loyalty' || tabKey === 'dist') {
      var chartArea2 = activeTab.querySelector('.fn-rel-chart-area');
      hasChart = !!(chartArea2 && !chartArea2.hasAttribute('hidden'));
      hasTable = !!(activeTab.querySelector('.cb-rel-table'));
    } else if (tabKey === 'dop') {
      hasChart = false;
      hasTable = !!(activeTab.querySelector('.cb-dop-table'));
    }

    /* Build checkbox list. available:true required by showCheckboxPopover to
       enable the checkbox; without it all items render as disabled. */
    var checkboxes = [];
    if (hasChart) checkboxes.push({ key: 'chart',   label: 'Chart',   available: true, checked: true });
    if (hasTable) checkboxes.push({ key: 'table',   label: 'Table',   available: true, checked: true });
    checkboxes.push(          { key: 'insight', label: 'Insight', available: true, checked: hasInsight });

    /* No real content — pin insight directly with no dialog */
    if (!hasChart && !hasTable) {
      cbExecutePin(panel, activeTab, tabKey, { chart: false, table: false, insight: hasInsight }, editor);
      return;
    }

    var anchor = pinBtn.closest('.br-section-toolbar') || pinBtn.parentElement;
    TurasPins.showCheckboxPopover(pinBtn, checkboxes, function (flags) {
      cbExecutePin(panel, activeTab, tabKey, flags, editor);
    }, anchor);
  }

  function cbExecuteContextPin(panel, activeTab, flags, editor) {
    if (typeof TurasPins === 'undefined') return;

    var section = panel.closest('.br-element-section') || panel.parentNode;
    var titleEl = section ? section.querySelector('.br-element-title') : null;
    var baseTitle = titleEl ? titleEl.textContent.trim() : '';
    var title = baseTitle ? baseTitle + ' — Category Context' : 'Category Context';

    var html = cbCaptureContextHtml(activeTab, flags);
    var insightText = (flags.insight && editor) ? editor.value.trim() : '';

    if (!html && !insightText) return;

    TurasPins.add({
      sectionKey:  'cb-context-' + Date.now(),
      title:       title,
      chartSvg:    '',
      tableHtml:   html,
      insightText: insightText,
      pinFlags:    { chart: false, table: !!html, insight: !!insightText },
      pinMode:     'custom'
    });

    var pinBtn = section ? section.querySelector('.cb-toolbar-top .br-pin-btn') : null;
    if (pinBtn) {
      pinBtn.classList.add('pin-flash');
      setTimeout(function () { pinBtn.classList.remove('pin-flash'); }, 600);
    }
  }

  function cbExecutePin(panel, activeTab, tabKey, flags, editor) {
    if (typeof TurasPins === 'undefined') return;

    /* Build title from section heading + tab label */
    var section = panel.closest('.br-element-section') || panel.parentNode;
    var titleEl = section ? section.querySelector('.br-element-title') : null;
    var baseTitle = titleEl ? titleEl.textContent.trim() : '';
    var tabLabels = { brands: 'Brand Summary', loyalty: 'Loyalty Segmentation',
                     dist: 'Purchase Distribution', dop: 'Duplication of Purchase',
                     context: 'Category Context' };
    var tabLabel = tabLabels[tabKey] || tabKey;
    var title = baseTitle ? baseTitle + ' — ' + tabLabel : tabLabel;

    var content = { sectionKey: panel.id || tabKey, title: title,
                    chartSvg: '', tableHtml: '', insightText: '' };

    /* All CB charts are HTML div-based (not SVG) — capture the chart
       container element and merge it before the table HTML in tableHtml. */
    var capturedChartHtml = '';
    if (flags.chart) {
      var chartEl = null;
      if (tabKey === 'brands') {
        var ca = activeTab.querySelector('.cb-brands-chart-area');
        chartEl = ca ? ca.querySelector('.cb-brands-chart') : null;
      } else if (tabKey === 'loyalty' || tabKey === 'dist') {
        var ca2 = activeTab.querySelector('.fn-rel-chart-area');
        chartEl = ca2 ? ca2.querySelector('.fn-rel-chart') : null;
      }
      if (chartEl) {
        capturedChartHtml = TurasPins.capturePortableHtml
          ? TurasPins.capturePortableHtml(chartEl)
          : chartEl.outerHTML;
      }
    }

    /* Capture table HTML */
    var capturedTableHtml = '';
    if (flags.table) {
      var tbl = activeTab.querySelector('table');
      if (tbl) {
        capturedTableHtml = TurasPins.capturePortableHtml
          ? TurasPins.capturePortableHtml(tbl)
          : tbl.outerHTML;
      }
    }

    /* Strip interactive controls (sort buttons, info-callouts, toolbars)
       so the pinned card is a static snapshot, not a live UI clone. */
    var stripCb = (typeof window.brStripInteractive === 'function')
      ? window.brStripInteractive
      : function (s) { return s; };
    capturedChartHtml = stripCb(capturedChartHtml);
    capturedTableHtml = stripCb(capturedTableHtml);

    /* Chart HTML precedes table HTML so the pin card reads top-to-bottom */
    content.tableHtml = capturedChartHtml + capturedTableHtml;

    if (flags.insight && editor) content.insightText = editor.value.trim();

    /* CB charts are HTML-based and stored in tableHtml (not chartSvg).
       pinFlags.table must be true whenever tableHtml has any content —
       regardless of whether the user's "Table" checkbox was checked —
       otherwise the chart HTML is captured but never rendered in the pin card. */
    content.pinFlags = {
      chart:   !!flags.chart,
      table:   !!(capturedChartHtml || capturedTableHtml),
      insight: !!flags.insight
    };
    content.pinMode  = 'custom';
    TurasPins.add(content);

    /* Flash pin button (button lives in sibling toolbar, not inside .cb-panel) */
    var pinBtn = section ? section.querySelector('.cb-toolbar-top .br-pin-btn') : null;
    if (pinBtn) {
      pinBtn.classList.add('pin-flash');
      setTimeout(function () { pinBtn.classList.remove('pin-flash'); }, 600);
    }
  }

  /* ---------------------------------------------------------------------- */
  /* CB-aware PNG export: intercepts .br-png-btn in sibling toolbar         */
  /* ---------------------------------------------------------------------- */

  function bindCbPngBtn(panel) {
    /* PNG button is a sibling of .cb-panel inside .br-element-section —
       same topology as the pin button; must search from the section root. */
    var section = panel.closest('.br-element-section') || panel.parentNode;
    var pngBtn  = section ? section.querySelector('.cb-toolbar-top .br-png-btn') : null;
    if (!pngBtn) return;

    /* Remove generic brExportPng inline handler, replace with CB-aware one.
       Guard on TurasPins inside the click handler, not here — it may not be
       loaded yet when initCbPanel fires. */
    pngBtn.removeAttribute('onclick');
    pngBtn.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      cbPngDialog(panel, pngBtn);
    });
  }

  function cbPngDialog(panel, pngBtn) {
    if (typeof TurasPins === 'undefined') return;

    var activeTab = panel.querySelector('.cb-subtab:not([hidden])');
    if (!activeTab) return;
    var tabKey = activeTab.getAttribute('data-cb-tab') || '';

    var section = panel.closest('.br-element-section') || panel.parentNode;
    var editor  = section ? section.querySelector('.br-insight-editor') : null;
    var hasInsight = !!(editor && editor.value.trim());

    /* Context tab branch — element set differs (cards + 2 tables) */
    if (tabKey === 'context') {
      var ctxBoxes = cbDetectContextCheckboxes(activeTab, hasInsight);
      TurasPins.showCheckboxPopover(pngBtn, ctxBoxes, function (flags) {
        cbExecuteContextPng(panel, activeTab, flags, editor);
      }, null, { title: 'EXPORT AS PNG', actionLabel: 'Export' });
      return;
    }

    /* Detect available content — mirrors cbPinDialog detection */
    var hasChart = false;
    var hasTable = false;

    if (tabKey === 'brands') {
      var chartArea = activeTab.querySelector('.cb-brands-chart-area');
      hasChart = !!(chartArea && !chartArea.hasAttribute('hidden'));
      hasTable = !!(activeTab.querySelector('.cb-brand-freq-table'));
    } else if (tabKey === 'loyalty' || tabKey === 'dist') {
      var chartArea2 = activeTab.querySelector('.fn-rel-chart-area');
      hasChart = !!(chartArea2 && !chartArea2.hasAttribute('hidden'));
      hasTable = !!(activeTab.querySelector('.cb-rel-table'));
    } else if (tabKey === 'dop') {
      hasChart = false;
      hasTable = !!(activeTab.querySelector('.cb-dop-table'));
    }

    function doExport(flags) {
      cbExecutePng(panel, activeTab, tabKey, flags, editor);
    }

    if (!hasChart && !hasTable) {
      doExport({ chart: false, table: false, insight: hasInsight });
      return;
    }

    var checkboxes = [];
    if (hasChart) checkboxes.push({ key: 'chart',   label: 'Chart',   available: true, checked: true });
    if (hasTable) checkboxes.push({ key: 'table',   label: 'Table',   available: true, checked: true });
    checkboxes.push(              { key: 'insight', label: 'Insight', available: true, checked: hasInsight });

    TurasPins.showCheckboxPopover(pngBtn, checkboxes, function (flags) {
      doExport(flags);
    }, null, { title: 'EXPORT AS PNG', actionLabel: 'Export' });
  }

  function cbExecuteContextPng(panel, activeTab, flags, editor) {
    if (typeof TurasPins === 'undefined') return;

    var section = panel.closest('.br-element-section') || panel.parentNode;
    var titleEl = section ? section.querySelector('.br-element-title') : null;
    var baseTitle = titleEl ? titleEl.textContent.trim() : '';
    var title = baseTitle ? baseTitle + ' — Category Context' : 'Category Context';

    var html = cbCaptureContextHtml(activeTab, flags);
    var insightText = (flags.insight && editor) ? editor.value.trim() : '';

    TurasPins.exportContentAsPNG({
      title:       title,
      chartSvg:    '',
      tableHtml:   html,
      insightText: insightText,
      pinFlags:    { chart: false, table: !!html, insight: !!insightText },
      pinMode:     'custom'
    });
  }

  function cbExecutePng(panel, activeTab, tabKey, flags, editor) {
    if (typeof TurasPins === 'undefined') return;

    var section = panel.closest('.br-element-section') || panel.parentNode;
    var titleEl = section ? section.querySelector('.br-element-title') : null;
    var baseTitle = titleEl ? titleEl.textContent.trim() : '';
    var tabLabels = { brands: 'Brand Summary', loyalty: 'Loyalty Segmentation',
                     dist: 'Purchase Distribution', dop: 'Duplication of Purchase',
                     context: 'Category Context' };
    var tabLabel = tabLabels[tabKey] || tabKey;
    var title = baseTitle ? baseTitle + ' — ' + tabLabel : tabLabel;

    /* Capture chart HTML (all CB charts are HTML div-based) */
    var capturedChartHtml = '';
    if (flags.chart) {
      var chartEl = null;
      if (tabKey === 'brands') {
        var ca = activeTab.querySelector('.cb-brands-chart-area');
        chartEl = ca ? ca.querySelector('.cb-brands-chart') : null;
      } else if (tabKey === 'loyalty' || tabKey === 'dist') {
        var ca2 = activeTab.querySelector('.fn-rel-chart-area');
        chartEl = ca2 ? ca2.querySelector('.fn-rel-chart') : null;
      }
      if (chartEl) {
        capturedChartHtml = TurasPins.capturePortableHtml
          ? TurasPins.capturePortableHtml(chartEl)
          : chartEl.outerHTML;
      }
    }

    /* Capture table HTML */
    var capturedTableHtml = '';
    if (flags.table) {
      var tbl = activeTab.querySelector('table');
      if (tbl) {
        capturedTableHtml = TurasPins.capturePortableHtml
          ? TurasPins.capturePortableHtml(tbl)
          : tbl.outerHTML;
      }
    }

    /* Strip interactive controls so the PNG matches a static snapshot. */
    var stripPng = (typeof window.brStripInteractive === 'function')
      ? window.brStripInteractive
      : function (s) { return s; };
    capturedChartHtml = stripPng(capturedChartHtml);
    capturedTableHtml = stripPng(capturedTableHtml);

    /* Chart HTML prepended to table HTML — both rendered by html2canvas in export.
       Same pinFlags.table fix as cbExecutePin: must be true whenever there is any
       HTML content, not just when the user's "Table" checkbox was ticked. */
    TurasPins.exportContentAsPNG({
      title:       title,
      chartSvg:    '',
      tableHtml:   capturedChartHtml + capturedTableHtml,
      insightText: flags.insight && editor ? editor.value.trim() : '',
      pinFlags:    {
        chart:   !!flags.chart,
        table:   !!(capturedChartHtml || capturedTableHtml),
        insight: !!(flags.insight && editor && editor.value.trim())
      },
      pinMode:     'custom'
    });
  }

}());
