/* ==========================================================================
   Brand Category Buying Panel — interactivity
   ==========================================================================
   Provides toggle handlers called from inline onclick attributes:

     _cbDJToggle(containerId, yaxis, btn)
       Switch the Double Jeopardy scatter between SCR and Buy-rate y-axis.

     _cbDoPToggle(containerId, view, btn)
       Switch the DoP heatmap between "Deviation from law" and "Observed".

     _cbToggleDetails(catCode)
       Expand / collapse the legacy descriptive detail section.

     _cbSetFocal(btn, catCode)
       Change the focal brand across all charts, the norms table, the
       heatmap, and the three focal KPI chips within a panel.
   ========================================================================== */

(function () {
  if (window.__BRAND_CB_PANEL_INIT__) return;
  window.__BRAND_CB_PANEL_INIT__ = true;

  /* ---------------------------------------------------------------------- */
  /* Double Jeopardy y-axis toggle                                           */
  /* ---------------------------------------------------------------------- */

  window._cbDJToggle = function (containerId, yaxis, btn) {
    var container = document.getElementById(containerId);
    if (!container) return;

    container.querySelectorAll('[data-dj-yaxis]').forEach(function (el) {
      el.style.display = el.getAttribute('data-dj-yaxis') === yaxis ? '' : 'none';
    });

    _cbSetActiveBtn(btn);
  };

  /* ---------------------------------------------------------------------- */
  /* DoP heatmap view toggle                                                 */
  /* ---------------------------------------------------------------------- */

  window._cbDoPToggle = function (containerId, view, btn) {
    var container = document.getElementById(containerId);
    if (!container) return;

    container.querySelectorAll('[data-dop-view]').forEach(function (el) {
      el.style.display = el.getAttribute('data-dop-view') === view ? '' : 'none';
    });

    _cbSetActiveBtn(btn);
  };

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
  /* Focal brand picker                                                      */
  /* ---------------------------------------------------------------------- */

  window._cbSetFocal = function (btn, catCode) {
    var panel = btn.closest('.cb-panel');
    if (!panel) return;

    var brandCode   = btn.getAttribute('data-brand');
    var focalColour = panel.dataset.focalColour || '#1A5276';

    /* 1. Update picker chip active states */
    panel.querySelectorAll('.cb-focal-chip').forEach(function (chip) {
      chip.classList.toggle('active', chip.getAttribute('data-brand') === brandCode);
    });

    /* 2. Re-colour SVG elements in all charts
          For the focal brand:  apply focal colour + larger radius (dots)
          For others:           apply muted colour */
    var MUTED_COL = '#94a3b8';
    panel.querySelectorAll('g[data-brand]').forEach(function (g) {
      var isFocal = g.getAttribute('data-brand') === brandCode;
      var col     = isFocal ? focalColour : MUTED_COL;
      var fw      = isFocal ? '700' : '400';

      g.querySelectorAll('.cb-brand-dot').forEach(function (dot) {
        dot.setAttribute('fill', col);
        dot.setAttribute('r', isFocal ? '6' : '4');
      });
      g.querySelectorAll('.cb-brand-bar').forEach(function (bar) {
        /* Only re-colour the buy-rate bars (heaviness bars use tier colours) */
        if (bar.parentElement && bar.parentElement.closest('.cb-buyrate-svg')) {
          bar.setAttribute('fill', col);
        }
      });
      g.querySelectorAll('.cb-brand-label').forEach(function (lbl) {
        lbl.setAttribute('fill', col);
        lbl.setAttribute('font-weight', fw);
      });
    });

    /* 3. Update focal-row class in norms table */
    panel.querySelectorAll('tr[data-brand]').forEach(function (tr) {
      tr.classList.toggle('focal-row', tr.getAttribute('data-brand') === brandCode);
    });

    /* 4. Update KPI chips from embedded JSON */
    var scriptEl = document.getElementById('cb-data-' + catCode);
    if (!scriptEl) return;
    var kpiMap;
    try { kpiMap = JSON.parse(scriptEl.textContent); } catch (e) { return; }
    var kd = kpiMap[brandCode];
    if (!kd) return;

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

}());
