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

  // --- Brand popover (searchable multi-select) ------------------------------
  pfFpInitBrandPopover(section, table);

  // --- Category chip toggles ------------------------------------------------
  pfFpInitCategoryChips(section, table);

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

// ---------------------------------------------------------------------------
// FOOTPRINT — brand popover + category chips
// ---------------------------------------------------------------------------

/**
 * Wire the searchable brand popover. Exposes:
 *   - "Manage brands" toggle button (open/close)
 *   - Search input (case-insensitive substring on data-pf-fp-search)
 *   - All / None / Focal-only quick actions
 *   - Per-brand checkboxes that show/hide the matching <tr> in the table
 *   - Outside-click + Escape to dismiss
 */
function pfFpInitBrandPopover(section, table) {
  var btn = section.querySelector('.pf-fp-pop-btn[data-pf-fp-action="brandpop"]');
  var pop = section.querySelector('.pf-fp-pop[data-pf-fp-pop="brand"]');
  if (!btn || !pop) return;

  function open() {
    pop.hidden = false;
    btn.setAttribute('aria-expanded', 'true');
    var input = pop.querySelector('.pf-fp-pop-input');
    if (input) setTimeout(function () { input.focus(); }, 0);
  }
  function close() {
    pop.hidden = true;
    btn.setAttribute('aria-expanded', 'false');
  }
  function toggle() { (pop.hidden) ? open() : close(); }

  btn.addEventListener('click', function (ev) { ev.preventDefault(); toggle(); });
  // Outside-click close — uses closest() so clicks on nested spans inside
  // the trigger button or the popover are correctly attributed. The
  // mousedown phase fires before click, so the popover closes cleanly
  // when the user clicks a category chip or anywhere else.
  document.addEventListener('mousedown', function (ev) {
    if (pop.hidden) return;
    var t = ev.target;
    if (t.closest('.pf-fp-pop[data-pf-fp-pop="brand"]')) return;
    if (t.closest('.pf-fp-pop-btn[data-pf-fp-action="brandpop"]')) return;
    close();
  });
  document.addEventListener('keydown', function (ev) {
    if (ev.key === 'Escape' && !pop.hidden) close();
  });

  // --- Search filter ---
  var input = pop.querySelector('.pf-fp-pop-input');
  if (input) {
    input.addEventListener('input', function () {
      var q = (input.value || '').trim().toLowerCase();
      pop.querySelectorAll('.pf-fp-pop-item').forEach(function (item) {
        var hay = item.getAttribute('data-pf-fp-search') || '';
        item.style.display = (q === '' || hay.indexOf(q) !== -1) ? '' : 'none';
      });
    });
  }

  // --- Per-brand checkbox → row visibility ---
  function applyBrand(bc, on) {
    var row = table.querySelector('tr[data-pf-fp-brand="' + cssEscape(bc) + '"]');
    if (row) row.style.display = on ? '' : 'none';
  }
  function refreshCount() {
    var total   = pop.querySelectorAll('.pf-fp-pop-cb').length;
    var visible = pop.querySelectorAll('.pf-fp-pop-cb:checked').length;
    var label   = btn.querySelector('[data-pf-fp-brand-count]');
    if (label) label.textContent = visible + ' / ' + total + ' visible';
    if (typeof brSetPinState === 'function') {
      var hidden = [];
      pop.querySelectorAll('.pf-fp-pop-cb').forEach(function (cb) {
        if (!cb.checked) hidden.push(cb.getAttribute('data-pf-fp-brand-cb'));
      });
      brSetPinState('pf_fp_hidden_brands', hidden);
    }
  }

  pop.querySelectorAll('.pf-fp-pop-cb').forEach(function (cb) {
    cb.addEventListener('change', function () {
      applyBrand(cb.getAttribute('data-pf-fp-brand-cb'), cb.checked);
      refreshCount();
    });
  });

  // --- Bulk actions ---
  function setAll(state) {
    pop.querySelectorAll('.pf-fp-pop-cb').forEach(function (cb) {
      cb.checked = state;
      applyBrand(cb.getAttribute('data-pf-fp-brand-cb'), state);
    });
    refreshCount();
  }
  var btnAll   = pop.querySelector('[data-pf-fp-action="brand-all"]');
  var btnNone  = pop.querySelector('[data-pf-fp-action="brand-none"]');
  var btnFocal = pop.querySelector('[data-pf-fp-action="brand-focal"]');
  if (btnAll)  btnAll.addEventListener('click',  function () { setAll(true); });
  if (btnNone) btnNone.addEventListener('click', function () { setAll(false); });
  if (btnFocal) btnFocal.addEventListener('click', function () {
    var focal = table.getAttribute('data-pf-focal') || '';
    pop.querySelectorAll('.pf-fp-pop-cb').forEach(function (cb) {
      var bc = cb.getAttribute('data-pf-fp-brand-cb');
      var on = (bc === focal);
      cb.checked = on;
      applyBrand(bc, on);
    });
    refreshCount();
  });
}

/**
 * Wire the per-category chip row. Clicking a chip hides/shows that
 * category's column (header + every <td data-pf-fp-col=cc>) in the
 * table. Default state: all on.
 */
function pfFpInitCategoryChips(section, table) {
  section.querySelectorAll('.pf-fp-cat-chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      var cc = chip.getAttribute('data-pf-fp-cat');
      var on = chip.classList.toggle('pf-fp-cat-chip-on');
      chip.classList.toggle('pf-fp-cat-chip-off', !on);
      pfFpSetColVisible(table, cc, on);
      if (typeof brSetPinState === 'function') {
        var hidden = [];
        section.querySelectorAll('.pf-fp-cat-chip-off').forEach(function (c) {
          hidden.push(c.getAttribute('data-pf-fp-cat'));
        });
        brSetPinState('pf_fp_hidden_cats', hidden);
      }
    });
  });
}

function pfFpSetColVisible(table, cc, visible) {
  var disp = visible ? '' : 'none';
  // Header cell
  var th = table.querySelector('th.pf-fp-th-sort[data-pf-fp-sort="' + cssEscape(cc) + '"]');
  if (th) th.style.display = disp;
  // All matching body cells
  table.querySelectorAll('td[data-pf-fp-col="' + cssEscape(cc) + '"]').forEach(function (td) {
    td.style.display = disp;
  });
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

  // Force the new focal brand's row visible (in case it had been hidden
  // from the popover) and re-check its checkbox + popover row.
  if (focalRow) focalRow.style.display = '';
  var pop = section ? section.querySelector('.pf-fp-pop[data-pf-fp-pop="brand"]') : null;
  if (pop) {
    var cb = pop.querySelector('.pf-fp-pop-cb[data-pf-fp-brand-cb="' + cssEscape(brand) + '"]');
    if (cb && !cb.checked) cb.checked = true;
    // Move the focal row's <label> in the popover to the top so it's prominent.
    var item = pop.querySelector('.pf-fp-pop-item[data-pf-fp-brand="' + cssEscape(brand) + '"]');
    if (item) {
      pop.querySelectorAll('.pf-fp-pop-item').forEach(function (el) {
        el.classList.remove('pf-fp-pop-item-focal');
      });
      item.classList.add('pf-fp-pop-item-focal');
      var list = pop.querySelector('.pf-fp-pop-list');
      if (list && list.firstChild !== item) list.insertBefore(item, list.firstChild);
    }
    // Update the visible/total badge on the popover button.
    var btn = section.querySelector('.pf-fp-pop-btn[data-pf-fp-action="brandpop"]');
    if (btn) {
      var total   = pop.querySelectorAll('.pf-fp-pop-cb').length;
      var visible = pop.querySelectorAll('.pf-fp-pop-cb:checked').length;
      var lbl = btn.querySelector('[data-pf-fp-brand-count]');
      if (lbl) lbl.textContent = visible + ' / ' + total + ' visible';
    }
  }

  // Update the focal pill next to the popover (dot colour + name).
  pfFpUpdateFocalPill(section, brand);

  if (typeof brSetPinState === 'function') brSetPinState('pf_fp_focal', brand);
}

function pfFpUpdateFocalPill(section, brand) {
  if (!section) return;
  var pill = section.querySelector('.pf-fp-focal-chip');
  if (!pill) return;
  // Take the brand label + colour from the matching popover item, which
  // already has the right dot colour and display name baked in.
  var src = section.querySelector('.pf-fp-pop-item[data-pf-fp-brand="' + cssEscape(brand) + '"]');
  if (!src) return;
  pill.setAttribute('data-pf-fp-brand', brand);
  var srcName = src.querySelector('.pf-fp-pop-name');
  var nameEl  = pill.querySelector('.pf-fp-focal-chip-name');
  if (srcName && nameEl) nameEl.textContent = srcName.textContent;
  var srcDot = src.querySelector('.pf-fp-pop-dot');
  var dotEl  = pill.querySelector('.pf-fp-focal-chip-dot');
  if (srcDot && dotEl) {
    var col = srcDot.style.background || srcDot.style.backgroundColor || '';
    if (col) dotEl.style.background = col;
  }
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
