// ==============================================================================
// BRAND MODULE - PORTFOLIO PANEL INTERACTIVITY
// ==============================================================================
// Phase 2: subtab switching.
// Phase 3 additions: brand chip picker (strength map).
// Phase 4 additions: constellation node-click re-centre + pin, timeframe toggle.
// ==============================================================================

/**
 * Switch the active portfolio subtab.
 * @param {string} subtab - One of "footprint", "constellation", "clutter", "extension".
 */
function pfSwitchSubtab(subtab) {
  const panel = document.getElementById('panel-portfolio');
  if (!panel) return;

  // Update tab buttons
  panel.querySelectorAll('.pf-sub-btn').forEach(function(btn) {
    const isActive = btn.dataset.pfSubtab === subtab;
    btn.classList.toggle('active', isActive);
    btn.setAttribute('aria-selected', String(isActive));
  });

  // Update subtab visibility
  panel.querySelectorAll('.pf-subtab').forEach(function(div) {
    div.classList.toggle('active', div.id === 'pf-subtab-' + subtab);
  });

  // Persist subtab in pin state (used by TurasPin round-trip)
  if (typeof brSetPinState === 'function') {
    brSetPinState('pf_active_subtab', subtab);
  }
}

/**
 * Switch the active brand chip in the strength map picker.
 * Pre-renders all brand charts; this function simply shows the selected one.
 * @param {string} brandCode - Brand code to activate.
 */
function pfSwitchStrengthBrand(brandCode) {
  const panel = document.getElementById('panel-portfolio');
  if (!panel) return;

  // Update chip buttons
  panel.querySelectorAll('.pf-brand-chip').forEach(function(btn) {
    const isActive = btn.dataset.pfBrand === brandCode;
    btn.classList.toggle('active', isActive);
    btn.setAttribute('aria-pressed', String(isActive));
  });

  // Show matching chart, hide others
  panel.querySelectorAll('.pf-strength-chart').forEach(function(div) {
    div.style.display = div.dataset.pfBrand === brandCode ? 'block' : 'none';
  });

  if (typeof brSetPinState === 'function') {
    brSetPinState('pf_strength_brand', brandCode);
  }
}

/**
 * Handle constellation node click — highlight selected node and pin centred_brand.
 * Re-centres the view by visually emphasising the clicked node.
 * Pin payload: { subtab: 'constellation', centred_brand: brandCode }.
 * @param {Event|null} event - Click event (may be null when called from restore).
 * @param {string} brandCode - Brand code of the activated node.
 */
function pfConstellationNodeClick(event, brandCode) {
  var chart = document.getElementById('pf-constellation-chart');
  if (chart) {
    chart.querySelectorAll('circle[data-brand]').forEach(function(c) {
      var selected = c.getAttribute('data-brand') === brandCode;
      c.setAttribute('stroke', selected ? '#f59e0b' : '#fff');
      c.setAttribute('stroke-width', selected ? '3.5' : '2');
      c.setAttribute('opacity', selected ? '1' : '0.7');
    });
  }

  if (typeof brSetPinState === 'function') {
    brSetPinState('subtab', 'constellation');
    brSetPinState('centred_brand', brandCode);
  }
}

/**
 * Restore portfolio panel state from a pin payload.
 * Called by brand_pins.js when a portfolio pin is activated.
 * @param {Object} state - Pin state object.
 */
function pfRestorePinState(state) {
  if (!state) return;
  if (state.subtab) pfSwitchSubtab(state.subtab);
  if (state.pf_strength_brand) pfSwitchStrengthBrand(state.pf_strength_brand);
  if (state.centred_brand) pfConstellationNodeClick(null, state.centred_brand);
}

// ---------------------------------------------------------------------------
// FOOTPRINT TABLE — focal switch, chip show/hide, column sorting
// ---------------------------------------------------------------------------

/**
 * Wire up the footprint table interactions:
 *   - Focal-brand <select> moves the focal row to row 1 + recolours its label.
 *   - Brand chips toggle row visibility (and stay highlighted).
 *   - Column-header clicks sort rows by that column (focal pinned to row 1).
 * Idempotent — safe to call after re-renders.
 */
function pfInitFootprintTable() {
  var table = document.querySelector('.pf-fp-table');
  if (!table || table.dataset.pfFpBound === '1') return;
  table.dataset.pfFpBound = '1';

  var section = document.getElementById('pf-subtab-footprint');
  if (!section) return;

  // --- Focal-brand <select> -------------------------------------------------
  var focalSelect = section.querySelector('.pf-fp-focal-select');
  if (focalSelect) {
    focalSelect.addEventListener('change', function () {
      pfFpSetFocal(focalSelect.value);
    });
  }

  // --- Chip clicks (toggle row visibility) ----------------------------------
  section.querySelectorAll('.pf-fp-chip').forEach(function (chip) {
    chip.classList.add('pf-fp-chip-on');  // start visible
    chip.addEventListener('click', function () {
      var brand = chip.getAttribute('data-pf-fp-brand');
      var on = chip.classList.toggle('pf-fp-chip-on');
      chip.classList.toggle('pf-fp-chip-off', !on);
      var row = table.querySelector('tr[data-pf-fp-brand="' + cssEscape(brand) + '"]');
      if (row) row.style.display = on ? '' : 'none';
    });
  });

  // --- Column-header sort ---------------------------------------------------
  // Click target is the <th> itself (no inner <button>) — keeps the
  // thead rendering as one solid navy bar without native-button gaps.
  table.querySelectorAll('th.pf-fp-th-sort').forEach(function (th) {
    th.addEventListener('click', function () {
      var key = th.getAttribute('data-pf-fp-sort');
      pfFpSortBy(table, key);
    });
    // Keyboard activation (role="button" is set in the markup).
    th.addEventListener('keydown', function (ev) {
      if (ev.key === 'Enter' || ev.key === ' ') {
        ev.preventDefault();
        var key = th.getAttribute('data-pf-fp-sort');
        pfFpSortBy(table, key);
      }
    });
  });

  // --- Display toggles (heatmap + show counts) ------------------------------
  var wrap = table.closest('.pf-fp-table-wrap');
  var hmCb = section.querySelector('input[data-pf-fp-action="heatmap"]');
  var scCb = section.querySelector('input[data-pf-fp-action="showcounts"]');
  if (hmCb && wrap) {
    hmCb.addEventListener('change', function () {
      wrap.classList.toggle('pf-fp-heatmap-on',  hmCb.checked);
      wrap.classList.toggle('pf-fp-heatmap-off', !hmCb.checked);
      if (typeof brSetPinState === 'function') {
        brSetPinState('pf_fp_heatmap', hmCb.checked);
      }
    });
  }
  if (scCb && wrap) {
    scCb.addEventListener('change', function () {
      wrap.classList.toggle('pf-fp-show-counts', scCb.checked);
      if (typeof brSetPinState === 'function') {
        brSetPinState('pf_fp_show_counts', scCb.checked);
      }
    });
  }
}

function pfFpSetFocal(brand) {
  var table = document.querySelector('.pf-fp-table');
  if (!table) return;
  var section = document.getElementById('pf-subtab-footprint');

  table.setAttribute('data-pf-focal', brand);

  // Update <select> if changed externally
  var sel = section ? section.querySelector('.pf-fp-focal-select') : null;
  if (sel && sel.value !== brand) sel.value = brand;

  // Update row classes + move the focal row to top of <tbody>.
  var tbody = table.querySelector('tbody');
  if (!tbody) return;
  var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr[data-pf-fp-brand]'));
  var focalRow = null;
  rows.forEach(function (tr) {
    var isFocal = tr.getAttribute('data-pf-fp-brand') === brand;
    tr.classList.toggle('pf-fp-row-focal', isFocal);
    tr.classList.toggle('pf-fp-row-other', !isFocal);
    tr.setAttribute('data-pf-fp-focal', isFocal ? '1' : '0');
    // Strip any existing FOCAL badge then re-add to the new focal row.
    var lbl = tr.querySelector('.pf-fp-row-label');
    if (lbl) {
      lbl.querySelectorAll('.fn-focal-badge').forEach(function (b) { b.remove(); });
      if (isFocal) {
        var span = document.createElement('span');
        span.className = 'fn-focal-badge';
        span.textContent = 'FOCAL';
        span.style.marginLeft = '6px';
        lbl.appendChild(span);
      }
    }
    if (isFocal) focalRow = tr;
  });
  if (focalRow && tbody.firstChild !== focalRow) tbody.insertBefore(focalRow, tbody.firstChild);

  if (typeof brSetPinState === 'function') brSetPinState('pf_fp_focal', brand);
}

function pfFpSortBy(table, key) {
  var tbody = table.querySelector('tbody');
  if (!tbody) return;

  // Cycle direction: none -> desc -> asc -> none.
  var current = table.getAttribute('data-pf-fp-sort-key') === key
    ? (table.getAttribute('data-pf-fp-sort-dir') || 'none') : 'none';
  var next = (current === 'none') ? 'desc' : (current === 'desc' ? 'asc' : 'none');

  table.setAttribute('data-pf-fp-sort-key', next === 'none' ? '' : key);
  table.setAttribute('data-pf-fp-sort-dir', next);

  // Update sort indicators + active marker (CSS lights up the chevron).
  table.querySelectorAll('th.pf-fp-th-sort').forEach(function (th) {
    th.removeAttribute('data-pf-fp-active');
    var ind = th.querySelector('.pf-fp-sort-ind');
    if (ind) ind.textContent = '↕';
  });
  if (next !== 'none') {
    var activeTh = table.querySelector('th.pf-fp-th-sort[data-pf-fp-sort="' + cssEscape(key) + '"]');
    if (activeTh) {
      activeTh.setAttribute('data-pf-fp-active', '1');
      var ind = activeTh.querySelector('.pf-fp-sort-ind');
      if (ind) ind.textContent = (next === 'desc') ? '↓' : '↑';
    }
  }

  var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr[data-pf-fp-brand]'));

  if (next === 'none') {
    // Restore data-attribute insertion order — rebuild from server-issued
    // order stored in data-pf-fp-orig-idx (set on first sort below).
    if (!table.dataset.pfFpOrigIndexed) {
      rows.forEach(function (tr, i) { tr.dataset.pfFpOrigIdx = String(i); });
      table.dataset.pfFpOrigIndexed = '1';
    }
    rows.sort(function (a, b) {
      return (parseInt(a.dataset.pfFpOrigIdx, 10) || 0) -
             (parseInt(b.dataset.pfFpOrigIdx, 10) || 0);
    });
  } else {
    if (!table.dataset.pfFpOrigIndexed) {
      rows.forEach(function (tr, i) { tr.dataset.pfFpOrigIdx = String(i); });
      table.dataset.pfFpOrigIndexed = '1';
    }
    var dirSign = (next === 'desc') ? -1 : 1;
    rows.sort(function (a, b) {
      // Focal pinned to top regardless of sort direction
      var fa = a.getAttribute('data-pf-fp-focal') === '1';
      var fb = b.getAttribute('data-pf-fp-focal') === '1';
      if (fa && !fb) return -1;
      if (!fa && fb) return 1;

      var va, vb;
      if (key === '__brand__') {
        va = (a.querySelector('.pf-fp-row-label-text') || {}).textContent || '';
        vb = (b.querySelector('.pf-fp-row-label-text') || {}).textContent || '';
        return dirSign * va.localeCompare(vb);
      }
      var ca = a.querySelector('td[data-pf-fp-col="' + cssEscape(key) + '"]');
      var cb = b.querySelector('td[data-pf-fp-col="' + cssEscape(key) + '"]');
      var na = ca ? parseFloat(ca.getAttribute('data-pf-fp-val')) : NaN;
      var nb = cb ? parseFloat(cb.getAttribute('data-pf-fp-val')) : NaN;
      // NA values always sort to the bottom regardless of direction.
      var aNa = !isFinite(na), bNa = !isFinite(nb);
      if (aNa && !bNa) return 1;
      if (!aNa && bNa) return -1;
      if (aNa && bNa)  return 0;
      return dirSign * (na - nb);
    });
  }

  rows.forEach(function (tr) { tbody.appendChild(tr); });

  if (typeof brSetPinState === 'function') {
    brSetPinState('pf_fp_sort', { key: key, dir: next });
  }
}

function cssEscape(s) {
  if (window.CSS && CSS.escape) return CSS.escape(s);
  return String(s).replace(/([^a-zA-Z0-9_\-])/g, '\\$1');
}

// ---------------------------------------------------------------------------
// Initialise on DOMContentLoaded
// ---------------------------------------------------------------------------
(function() {
  function pfInit() {
    // Ensure the first subtab is active if none is
    const panel = document.getElementById('panel-portfolio');
    if (!panel) return;
    const activeBtn = panel.querySelector('.pf-sub-btn.active');
    if (!activeBtn) pfSwitchSubtab('footprint');

    pfInitFootprintTable();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', pfInit);
  } else {
    pfInit();
  }
})();
