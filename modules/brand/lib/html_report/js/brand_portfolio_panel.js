// ==============================================================================
// BRAND MODULE - PORTFOLIO PANEL INTERACTIVITY
// ==============================================================================
// Phase 2: subtab switching.
// Phase 3 additions: brand chip picker (strength map).
// Phase 4 additions: constellation node-click re-centre + pin, timeframe toggle.
// ==============================================================================


// ------------------------------------------------------------------------------
// CROSS-SUBTAB FOCAL SYNC
// ------------------------------------------------------------------------------
// Each portfolio sub-tab (Overview / Footprint / Constellation / Clutter /
// Extension) renders its own focal-brand <select>. Without sync the user
// has to re-pick the focal on every tab. pfBroadcastFocal() updates every
// select's .value (without firing change), then calls each sub-tab's
// setter so the sub-tab views re-render with the new focal.
//
// Re-entry guard prevents the case where a setter eventually calls
// pfBroadcastFocal again — only the outermost call propagates.

// ------------------------------------------------------------------------------
// AXIS RANGE INPUT HELPER
// ------------------------------------------------------------------------------
// Reads the {min, max} pair off the rangebar inputs scoped by data-attr
// (e.g. data-pf-cl-xrange="min" / "max"). Blank input -> null (auto).
function pfReadRange(attrPrefix) {
  function read(which) {
    var el = document.querySelector(
      'input[data-' + attrPrefix + '="' + which + '"]');
    if (!el || el.value === '') return null;
    var v = parseFloat(el.value);
    return isNaN(v) ? null : v;
  }
  return { min: read('min'), max: read('max') };
}

// Bind input/change/reset listeners on a rangebar pair scoped to a section.
// onChange runs after every input event so the chart redraws live.
function pfBindRangeInputs(section, attrPrefix, onChange) {
  if (!section) return;
  ['input', 'change'].forEach(function (evName) {
    section.addEventListener(evName, function (ev) {
      var t = ev.target;
      if (!t || !t.matches) return;
      if (t.matches('input[data-' + attrPrefix + '="min"], input[data-' +
                     attrPrefix + '="max"]')) onChange();
    });
  });
  section.addEventListener('click', function (ev) {
    var btn = ev.target.closest('button[data-' + attrPrefix + '="reset"]');
    if (!btn) return;
    var minEl = section.querySelector('input[data-' + attrPrefix + '="min"]');
    var maxEl = section.querySelector('input[data-' + attrPrefix + '="max"]');
    if (minEl) minEl.value = '';
    if (maxEl) maxEl.value = '';
    onChange();
  });
}

// Re-render the Clutter scatter with the currently-active focal. Used by
// the axis-range inputs (no focal change, just a redraw).
function pfClRerenderCurrentFocal() {
  var chart = document.getElementById('pf-clutter-chart');
  if (!chart) return;
  var focal = chart.getAttribute('data-pf-cl-focal') || '';
  if (focal && typeof pfClSetFocal === 'function') pfClSetFocal(focal);
}

function pfExRerenderCurrentFocal() {
  var section = document.getElementById('pf-subtab-extension');
  if (!section) return;
  var layout = section.querySelector('.pf-ex-layout');
  var focal = layout ? layout.getAttribute('data-pf-ex-focal') : '';
  if (focal && typeof pfExSetFocal === 'function') pfExSetFocal(focal);
}


function pfBroadcastFocal(brand) {
  if (!brand) return;
  if (window.__pfFocalSyncing) return;
  window.__pfFocalSyncing = true;
  try {
    // 1. Sync every focal-select widget. Setting .value programmatically
    //    does not fire 'change', so we don't recurse through the
    //    addEventListener('change', ...) bindings.
    var selectors = [
      '#pfo-focal-select',
      '.pf-fp-focal-select',
      '#pf-cn-focal-select',
      '#pf-cl-focal-select',
      '#pf-ex-focal-select'
    ];
    selectors.forEach(function (sel) {
      document.querySelectorAll(sel).forEach(function (el) {
        if (!el || el.value === brand) return;
        var hasOption = Array.prototype.some.call(el.options || [], function (o) {
          return o.value === brand;
        });
        if (hasOption) el.value = brand;
      });
    });

    // 2. Re-render each sub-tab. Each setter is a no-op if its DOM is not
    //    present (e.g. early in load), so we can safely call them all.
    if (typeof window.pfoSwitchFocal === 'function') window.pfoSwitchFocal(brand);
    if (typeof pfFpSetFocal === 'function')          pfFpSetFocal(brand);
    if (typeof pfCnSetFocal === 'function')          pfCnSetFocal(brand);
    if (typeof pfClSetFocal === 'function')          pfClSetFocal(brand);
    if (typeof pfExSetFocal === 'function')          pfExSetFocal(brand);
  } finally {
    window.__pfFocalSyncing = false;
  }
}

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
  // Broadcast to every portfolio sub-tab so the picked focal flows
  // across Overview / Footprint / Constellation / Clutter / Extension.
  var focalSelect = section.querySelector('.pf-fp-focal-select');
  if (focalSelect) {
    focalSelect.addEventListener('change', function () {
      pfBroadcastFocal(focalSelect.value);
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
 * table, AND refreshes the brand popover so brands that only have
 * data in hidden categories disappear from the brand list. Default
 * state: all on.
 */
function pfFpInitCategoryChips(section, table) {
  section.querySelectorAll('.pf-fp-cat-chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      var cc = chip.getAttribute('data-pf-fp-cat');
      var on = chip.classList.toggle('pf-fp-cat-chip-on');
      chip.classList.toggle('pf-fp-cat-chip-off', !on);
      pfFpSetColVisible(table, cc, on);
      pfFpRefreshBrandPopoverByCats(section);
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

/**
 * Hide popover rows for brands that have no presence in any currently
 * active category. The focal brand is always kept visible so the user
 * can never accidentally lose access to it.
 */
function pfFpRefreshBrandPopoverByCats(section) {
  var pop = section.querySelector('.pf-fp-pop[data-pf-fp-pop="brand"]');
  if (!pop) return;
  var activeCats = {};
  section.querySelectorAll('.pf-fp-cat-chip-on').forEach(function (c) {
    activeCats[c.getAttribute('data-pf-fp-cat')] = true;
  });
  pop.querySelectorAll('.pf-fp-pop-item').forEach(function (item) {
    if (item.classList.contains('pf-fp-pop-item-focal')) {
      item.style.display = '';
      return;
    }
    var cats = (item.getAttribute('data-pf-fp-cats') || '')
      .split(',').filter(Boolean);
    var anyActive = cats.some(function (c) { return !!activeCats[c]; });
    item.style.display = anyActive ? '' : 'none';
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
// COMPETITIVE SET — per-category chart + focal picker + closest-competitors
// ---------------------------------------------------------------------------

// Lazy-build a single floating tooltip element. One per document is
// enough — we move and rewrite it as the cursor moves between nodes.
function pfCnGetTooltip() {
  var t = document.getElementById('pf-cn-tooltip');
  if (t) return t;
  t = document.createElement('div');
  t.id = 'pf-cn-tooltip';
  t.className = 'pf-cn-tooltip';
  t.setAttribute('role', 'tooltip');
  t.setAttribute('aria-hidden', 'true');
  document.body.appendChild(t);
  return t;
}

function pfCnFormatTooltip(node, focalCode) {
  var brandLabel = node.getAttribute('data-pf-cn-name') ||
                   pfCnReadNodeLabel(node);
  var code = node.getAttribute('data-pf-cn-node');
  if (!focalCode || code === focalCode) return brandLabel + ' — focal';

  // Compute Jaccard with focal + rank from the SVG's edges.
  var svg = node.ownerSVGElement;
  var jacByCode = {};
  if (svg) {
    svg.querySelectorAll('.pf-cn-edge').forEach(function (e) {
      var b1 = e.getAttribute('data-pf-cn-b1');
      var b2 = e.getAttribute('data-pf-cn-b2');
      var j  = parseFloat(e.getAttribute('data-pf-cn-jac')) || 0;
      if (b1 === focalCode) jacByCode[b2] = j;
      else if (b2 === focalCode) jacByCode[b1] = j;
    });
  }
  var ranked = Object.keys(jacByCode)
    .sort(function (a, b) { return jacByCode[b] - jacByCode[a]; });
  var rank = ranked.indexOf(code) + 1;
  var jac  = jacByCode[code];

  // Look up the focal's brand label too so the tooltip reads naturally.
  var focalLabel = focalCode;
  if (svg) {
    var fcss = (window.CSS && CSS.escape) ? CSS.escape(focalCode)
      : focalCode.replace(/([^a-zA-Z0-9_\-])/g, '\\$1');
    var fNode = svg.querySelector('.pf-cn-node[data-pf-cn-node="' + fcss + '"]');
    if (fNode) {
      focalLabel = fNode.getAttribute('data-pf-cn-name') ||
                   pfCnReadNodeLabel(fNode);
    }
  }

  if (jac == null) {
    return brandLabel + ' — no co-awareness link with ' + focalLabel;
  }
  var pct = Math.round(jac * 100);
  return brandLabel + ' — ' + pct + '% Jaccard with ' + focalLabel +
         ' · #' + rank + ' closest';
}

function pfCnPositionTooltip(tip, ev) {
  // Place tooltip just below+right of cursor; flip to left/up if it
  // would overflow the viewport.
  var pad = 12;
  var x = ev.clientX + pad;
  var y = ev.clientY + pad;
  // Show first to measure
  tip.style.visibility = 'hidden';
  tip.style.opacity = '1';
  tip.style.left = '0px';
  tip.style.top  = '0px';
  var r = tip.getBoundingClientRect();
  if (x + r.width  > window.innerWidth)  x = ev.clientX - pad - r.width;
  if (y + r.height > window.innerHeight) y = ev.clientY - pad - r.height;
  tip.style.left = x + 'px';
  tip.style.top  = y + 'px';
  tip.style.visibility = 'visible';
}

function pfCnBindHoverTooltips(panel) {
  // Delegate hover events on the constellation panel — works for any
  // re-rendered SVG too (e.g. if we later swap in a new chart).
  panel.addEventListener('mouseover', function (ev) {
    var node = ev.target.closest && ev.target.closest('.pf-cn-node');
    if (!node) return;
    var tip = pfCnGetTooltip();
    var container = document.getElementById('pf-constellation-chart');
    var focal = container ? container.getAttribute('data-pf-cn-focal') : '';
    tip.textContent = pfCnFormatTooltip(node, focal);
    tip.setAttribute('aria-hidden', 'false');
    pfCnPositionTooltip(tip, ev);
  });
  panel.addEventListener('mousemove', function (ev) {
    var node = ev.target.closest && ev.target.closest('.pf-cn-node');
    if (!node) return;
    var tip = pfCnGetTooltip();
    if (tip.getAttribute('aria-hidden') === 'true') return;
    pfCnPositionTooltip(tip, ev);
  });
  panel.addEventListener('mouseout', function (ev) {
    var node = ev.target.closest && ev.target.closest('.pf-cn-node');
    if (!node) return;
    // Only hide when leaving the node entirely (not when moving to a
    // sibling element inside the same node).
    var to = ev.relatedTarget;
    if (to && node.contains(to)) return;
    var tip = pfCnGetTooltip();
    tip.style.opacity = '0';
    tip.style.visibility = 'hidden';
    tip.setAttribute('aria-hidden', 'true');
  });
}

function pfInitConstellationChips() {
  var panel = document.getElementById('pf-subtab-constellation');
  if (!panel) return;
  pfCnBindHoverTooltips(panel);

  panel.querySelectorAll('.pf-cn-cat-chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      var cc = chip.getAttribute('data-pf-cn-cat');
      panel.querySelectorAll('.pf-cn-cat-chip').forEach(function (c) {
        c.classList.toggle('pf-cn-cat-chip-on', c === chip);
      });
      panel.querySelectorAll('.pf-cn-cat-panel').forEach(function (p) {
        var match = p.getAttribute('data-pf-cn-cat-panel') === cc;
        p.classList.toggle('hidden', !match);
      });
      // Repopulate the focal dropdown with just THIS cat's brands.
      pfCnRebuildFocalSelectForCat(cc);
      if (typeof brSetPinState === 'function') {
        brSetPinState('pf_cn_active_cat', cc);
      }
    });
  });

  // Focal-brand picker. Broadcasts to every portfolio sub-tab.
  var sel = document.getElementById('pf-cn-focal-select');
  if (sel) {
    sel.addEventListener('change', function () {
      pfBroadcastFocal(sel.value);
    });
  }

  // Initial: filter dropdown to the active cat's brands, then paint
  // closest-competitors list across every cat panel.
  var container = document.getElementById('pf-constellation-chart');
  if (container) {
    var initialFocal = (sel && sel.value) ||
      container.getAttribute('data-pf-cn-focal') || '';
    var activeChip = panel.querySelector('.pf-cn-cat-chip-on');
    var initialCat = activeChip ? activeChip.getAttribute('data-pf-cn-cat') : '';
    if (initialCat) pfCnRebuildFocalSelectForCat(initialCat, initialFocal);
    if (initialFocal) pfCnSetFocal(initialFocal);
  }
}

/**
 * Rebuild the focal-brand <select> so it lists only brands present in
 * the active category. If the previously-selected focal is still in
 * the cat, keep it selected; otherwise select the first brand and fire
 * pfCnSetFocal so the chart + rivals list update.
 *
 * @param {string} catCode  Active category code.
 * @param {string} [preferredFocal]  Optional preferred selection (e.g. on
 *   first init, the value the server rendered with).
 */
function pfCnRebuildFocalSelectForCat(catCode, preferredFocal) {
  var sel = document.getElementById('pf-cn-focal-select');
  if (!sel) return;
  var data = pfCnLoadData();
  if (!data || !data[catCode]) return;
  var nodes = (data[catCode].nodes || []).slice();
  if (nodes.length === 0) return;

  var current = preferredFocal || sel.value || '';
  // Sort: preferred focal first (if present), then alphabetical by label.
  nodes.sort(function (a, b) {
    var ap = (a.code === current) ? 0 : 1;
    var bp = (b.code === current) ? 0 : 1;
    if (ap !== bp) return ap - bp;
    return (a.label || a.code).toLowerCase()
      .localeCompare((b.label || b.code).toLowerCase());
  });

  // Build options + figure out which to pick.
  var hasCurrent = nodes.some(function (n) { return n.code === current; });
  var pick = hasCurrent ? current : nodes[0].code;

  sel.innerHTML = nodes.map(function (n) {
    var s = (n.code === pick) ? ' selected' : '';
    return '<option value="' + escapeHtmlMaybe(n.code) + '"' + s + '>' +
           escapeHtmlMaybe(n.label || n.code) + '</option>';
  }).join('');

  // If the focal had to change because the previous focal isn't in this
  // category, propagate the new focal so chart + rivals list update.
  if (pick !== current) {
    pfCnSetFocal(pick);
  }
}

function pfCnLoadData() {
  var node = document.getElementById('pf-cn-data');
  if (!node) return null;
  try { return JSON.parse(node.textContent || '{}'); }
  catch (e) { console.warn('[pf-cn] Failed to parse JSON:', e); return null; }
}

function pfCnSetFocal(focalCode) {
  var container = document.getElementById('pf-constellation-chart');
  if (!container) return;
  container.setAttribute('data-pf-cn-focal', focalCode);

  var brandColour = pfCnReadFocalColour();

  // For every cat panel, re-style the SVG so the new focal gets the halo
  // + brand-coloured fill + bold label, and the previous focal reverts.
  container.querySelectorAll('.pf-cn-cat-panel').forEach(function (panel) {
    var svg = panel.querySelector('svg');
    if (svg) pfCnRestyleSvgForFocal(svg, focalCode, brandColour);
    var cat = panel.getAttribute('data-pf-cn-cat-panel');
    pfCnRenderRivals(panel, cat, focalCode);
  });

  if (typeof brSetPinState === 'function') {
    brSetPinState('pf_cn_focal', focalCode);
  }
}

function pfCnReadFocalColour() {
  // The focal colour is baked onto the focal-coloured chip elsewhere; we
  // pull it from --br-brand on :root so all tabs share one source of truth.
  try {
    var c = getComputedStyle(document.documentElement)
      .getPropertyValue('--br-brand').trim();
    if (c) return c;
  } catch (e) {}
  return '#1A5276';
}

function pfCnRestyleSvgForFocal(svg, focalCode, focalColour) {
  // Clear any existing halo (server may have rendered one for the
  // initial focal); we draw a fresh one for the new focal below.
  svg.querySelectorAll('.pf-cn-halo').forEach(function (h) { h.remove(); });

  // Reset every node + label to comparator styling. The rival tier
  // (top-N closest competitors) is re-applied below from the live edge
  // ranking once the new focal is set.
  svg.querySelectorAll('.pf-cn-node').forEach(function (n) {
    var baseR = parseFloat(n.getAttribute('data-pf-cn-base-r')) || 8;
    n.classList.remove('pf-cn-node-focal');
    n.classList.remove('pf-cn-node-rival');
    n.setAttribute('r', baseR);
    n.setAttribute('fill', '#94a3b8');
  });
  svg.querySelectorAll('.pf-cn-label').forEach(function (t) {
    t.classList.remove('pf-cn-label-focal');
    t.classList.remove('pf-cn-label-rival');
    t.setAttribute('fill', '#64748b');
    t.setAttribute('font-size', '10');
    t.setAttribute('font-weight', '400');
  });
  // Reset every edge to default (grey) styling.
  svg.querySelectorAll('.pf-cn-edge').forEach(function (e) {
    var baseW = parseFloat(e.getAttribute('data-pf-cn-base-w')) || 1;
    e.setAttribute('stroke', '#94a3b8');
    e.setAttribute('stroke-width', baseW);
    e.classList.remove('pf-cn-edge-focal');
  });

  // (Tooltip text is now built on hover by pfCnFormatTooltip — no
  // per-node text to reset on focal change.)

  if (!focalCode) return;

  // Apply focal styling to the new focal node + label, and inject a halo.
  var fcss = (window.CSS && CSS.escape) ? CSS.escape(focalCode)
    : focalCode.replace(/([^a-zA-Z0-9_\-])/g, '\\$1');
  var node  = svg.querySelector('.pf-cn-node[data-pf-cn-node="' + fcss + '"]');
  var label = svg.querySelector('.pf-cn-label[data-pf-cn-label="' + fcss + '"]');
  if (!node) return;
  var baseR = parseFloat(node.getAttribute('data-pf-cn-base-r')) || 8;
  var focalR = baseR * 1.25;

  node.classList.add('pf-cn-node-focal');
  node.setAttribute('r', focalR);
  node.setAttribute('fill', focalColour);
  if (label) {
    label.classList.add('pf-cn-label-focal');
    label.setAttribute('fill', '#1e293b');
    label.setAttribute('font-size', '12');
    label.setAttribute('font-weight', '700');
  }

  // Halo — dashed ring around the focal node. Insert at the END of the
  // parent <g> (= the node-group wrapping the focal circle) so it draws
  // beneath the circle without disturbing the <title> sibling.
  var ns = 'http://www.w3.org/2000/svg';
  var halo = document.createElementNS(ns, 'circle');
  halo.setAttribute('class', 'pf-cn-halo');
  halo.setAttribute('data-pf-cn-halo', focalCode);
  halo.setAttribute('cx', node.getAttribute('cx'));
  halo.setAttribute('cy', node.getAttribute('cy'));
  halo.setAttribute('r', focalR + 6);
  halo.setAttribute('fill', 'none');
  halo.setAttribute('stroke', focalColour);
  halo.setAttribute('stroke-width', '2');
  halo.setAttribute('stroke-dasharray', '3 3');
  halo.setAttribute('opacity', '0.55');
  // Insert halo BEFORE the node so the dashed ring sits underneath.
  node.parentNode.insertBefore(halo, node);

  // Highlight focal-incident edges so the chart matches the rivals list.
  // Each focal-incident edge carries a Jaccard score on data-pf-cn-jac,
  // which we'll also use below to identify the top-N rival tier.
  var focalEdges = svg.querySelectorAll(
    '.pf-cn-edge[data-pf-cn-b1="' + fcss + '"], ' +
    '.pf-cn-edge[data-pf-cn-b2="' + fcss + '"]');
  var maxJac = 0;
  var rivalJacs = [];  // {code, jac} per focal-incident edge
  focalEdges.forEach(function (e) {
    var j = parseFloat(e.getAttribute('data-pf-cn-jac')) || 0;
    if (j > maxJac) maxJac = j;
    var b1 = e.getAttribute('data-pf-cn-b1');
    var b2 = e.getAttribute('data-pf-cn-b2');
    var rival = (b1 === focalCode) ? b2 : b1;
    if (rival) rivalJacs.push({ code: rival, jac: j });
  });
  if (maxJac < 1e-6) maxJac = 1;
  focalEdges.forEach(function (e) {
    var j = parseFloat(e.getAttribute('data-pf-cn-jac')) || 0;
    var w = 1 + (j / maxJac) * 4;            // 1px..5px
    e.setAttribute('stroke', focalColour);
    e.setAttribute('stroke-width', w.toFixed(2));
    e.setAttribute('opacity', '0.85');
    e.classList.add('pf-cn-edge-focal');
  });

  // Rival tier — top-N closest competitors by Jaccard. The SVG carries
  // data-pf-cn-rival-colour (lightened focal hex computed by the server)
  // and data-pf-cn-top-n (count, default 5). When the user changes
  // focal we recompute the top-N here from the live edges so the
  // colour follows the picker.
  var topN = parseInt(svg.getAttribute('data-pf-cn-top-n'), 10);
  if (!isFinite(topN) || topN < 0) topN = 5;
  var rivalColour = svg.getAttribute('data-pf-cn-rival-colour') ||
                    pfCnDeriveRivalColour(focalColour);
  rivalJacs.sort(function (a, b) { return b.jac - a.jac; });
  var seen = {};
  var topRivals = [];
  for (var ri = 0; ri < rivalJacs.length && topRivals.length < topN; ri++) {
    var rcode = rivalJacs[ri].code;
    if (seen[rcode]) continue;
    seen[rcode] = true;
    topRivals.push(rcode);
  }
  topRivals.forEach(function (rcode) {
    var rcss = (window.CSS && CSS.escape) ? CSS.escape(rcode)
      : rcode.replace(/([^a-zA-Z0-9_\-])/g, '\\$1');
    var rNode  = svg.querySelector('.pf-cn-node[data-pf-cn-node="' + rcss + '"]');
    var rLabel = svg.querySelector('.pf-cn-label[data-pf-cn-label="' + rcss + '"]');
    if (rNode) {
      rNode.classList.add('pf-cn-node-rival');
      rNode.setAttribute('fill', rivalColour);
    }
    if (rLabel) {
      rLabel.classList.add('pf-cn-label-rival');
      rLabel.setAttribute('fill', '#334155');
      rLabel.setAttribute('font-size', '11');
      rLabel.setAttribute('font-weight', '600');
    }
  });

  // Hover tooltip text is built on demand by pfCnFormatTooltip from
  // the live edge data, so no pre-population is needed when focal changes.
}

// Lighten a focal hex toward white by 45% — matches the server-side
// .lighten_hex() helper so the rival colour stays consistent across
// the initial render and JS-driven focal switches.
function pfCnDeriveRivalColour(hex) {
  if (!hex) return '#7DA8C4';
  var clean = hex.replace(/^#/, '');
  if (clean.length === 3) {
    clean = clean.split('').map(function (c) { return c + c; }).join('');
  }
  if (clean.length !== 6) return '#7DA8C4';
  var r = parseInt(clean.substr(0, 2), 16);
  var g = parseInt(clean.substr(2, 2), 16);
  var b = parseInt(clean.substr(4, 2), 16);
  if (isNaN(r) || isNaN(g) || isNaN(b)) return '#7DA8C4';
  var amt = 0.45;
  r = Math.round(r + (255 - r) * amt);
  g = Math.round(g + (255 - g) * amt);
  b = Math.round(b + (255 - b) * amt);
  var hh = function (n) { return ('0' + n.toString(16)).slice(-2); };
  return ('#' + hh(r) + hh(g) + hh(b)).toUpperCase();
}

// Brand display label for a node — read the matching <text> in the
// same SVG so the tooltip uses the human-readable name rather than the
// brand code (which was the <title>'s initial text content).
function pfCnReadNodeLabel(node) {
  var code = node.getAttribute('data-pf-cn-node') || '';
  if (!code) return '';
  var fcss = (window.CSS && CSS.escape) ? CSS.escape(code)
    : code.replace(/([^a-zA-Z0-9_\-])/g, '\\$1');
  var svg = node.ownerSVGElement;
  if (!svg) return code;
  var lbl = svg.querySelector('.pf-cn-label[data-pf-cn-label="' + fcss + '"]');
  return lbl ? (lbl.textContent || code) : code;
}

function pfCnRenderRivals(panel, catCode, focalCode) {
  var ol = panel.querySelector('.pf-cn-rivals');
  if (!ol) return;
  var data = pfCnLoadData();
  if (!data || !data[catCode]) {
    ol.innerHTML = '<li class="pf-cn-rivals-empty">No co-awareness data for this category.</li>';
    return;
  }
  var nodes = data[catCode].nodes || [];
  var edges = data[catCode].edges || [];

  // Build code → label lookup.
  var labelOf = {};
  nodes.forEach(function (n) { labelOf[n.code] = n.label || n.code; });

  // Find edges that touch the focal, ranked by Jaccard desc.
  var rivals = edges
    .filter(function (e) { return e.b1 === focalCode || e.b2 === focalCode; })
    .map(function (e) {
      var other = (e.b1 === focalCode) ? e.b2 : e.b1;
      return { code: other, label: labelOf[other] || other, jac: e.jac };
    })
    .sort(function (a, b) { return b.jac - a.jac; })
    .slice(0, 5);

  if (rivals.length === 0) {
    var focalLabel = labelOf[focalCode] || focalCode;
    var inCat = nodes.some(function (n) { return n.code === focalCode; });
    var msg = inCat
      ? 'No competitors share enough co-awareness with ' + escapeHtmlMaybe(focalLabel) +
        ' to register in this category. ' +
        'It either dominates mental space here or has too few aware buyers for stable comparisons.'
      : escapeHtmlMaybe(focalLabel) + ' is not present in this category — pick another focal or a different category.';
    ol.innerHTML = '<li class="pf-cn-rivals-empty">' + msg + '</li>';
    return;
  }

  var maxJac = rivals[0].jac || 1;
  ol.innerHTML = rivals.map(function (r, i) {
    var pct = Math.round(r.jac * 100);
    var bar = Math.max(4, Math.round((r.jac / maxJac) * 100));
    return '<li>' +
      '<span class="pf-cn-rival-rank">#' + (i + 1) + '</span>' +
      '<span class="pf-cn-rival-name">' + escapeHtmlMaybe(r.label) + '</span>' +
      '<span class="pf-cn-rival-bar"><span class="pf-cn-rival-bar-fill" style="width:' + bar + '%"></span></span>' +
      '<span class="pf-cn-rival-jac">' + pct + '</span>' +
      '</li>';
  }).join('');
}

function escapeHtmlMaybe(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ---------------------------------------------------------------------------
// CATEGORY CONTEXT — focal picker, client-side scatter render, hover tooltip
// ---------------------------------------------------------------------------

function pfClLoadData() {
  var node = document.getElementById('pf-cl-data');
  if (!node) return null;
  try { return JSON.parse(node.textContent || '{}'); }
  catch (e) { console.warn('[pf-cl] Failed to parse JSON:', e); return null; }
}

function pfClInit() {
  var section = document.getElementById('pf-subtab-clutter');
  if (!section) return;

  // If the JSON payload didn't render (e.g. older R session, no per-cat
  // data), bail BEFORE doing anything that would replace the chart's
  // server-rendered SVG. The page still works — just without the
  // dynamic focal switching + tooltips.
  var data = pfClLoadData();
  if (!data || !data.cats || Object.keys(data.cats).length === 0) {
    return;
  }

  pfClBindHoverTooltips(section);

  var sel = document.getElementById('pf-cl-focal-select');
  if (sel) {
    sel.addEventListener('change', function () { pfBroadcastFocal(sel.value); });
  }

  // Axis range inputs — re-render the scatter on input/change. Reset
  // buttons clear the inputs (auto values). Mirrors the MA Advantage /
  // Metrics pattern.
  pfBindRangeInputs(section, 'pf-cl-xrange',
    function () { pfClRerenderCurrentFocal(); });
  pfBindRangeInputs(section, 'pf-cl-yrange',
    function () { pfClRerenderCurrentFocal(); });

  // Category chips — toggle which dots appear on the chart. State is
  // read by pfClSetFocal so it survives focal switches.
  section.querySelectorAll('.pf-cl-cat-chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      var on = chip.classList.toggle('pf-cl-cat-chip-on');
      chip.classList.toggle('pf-cl-cat-chip-off', !on);
      var focal = (sel && sel.value) ||
        (document.getElementById('pf-clutter-chart') &&
         document.getElementById('pf-clutter-chart').getAttribute('data-pf-cl-focal')) || '';
      pfClSetFocal(focal);
      if (typeof brSetPinState === 'function') {
        var hidden = [];
        section.querySelectorAll('.pf-cl-cat-chip-off').forEach(function (c) {
          hidden.push(c.getAttribute('data-pf-cl-cat'));
        });
        brSetPinState('pf_cl_hidden_cats', hidden);
      }
    });
  });

  // Repaint with the current focal so the SVG carries the new
  // tooltip-friendly data attributes that the server-side
  // build_scatter doesn't emit.
  var chart = document.getElementById('pf-clutter-chart');
  var initial = chart ? chart.getAttribute('data-pf-cl-focal') : '';
  if (initial) pfClSetFocal(initial);
}

// Read the active set of category codes from the chip row — used to
// filter which dots get drawn. When no chips are off, returns null
// (meaning "show all"); otherwise returns a Set of active codes.
function pfClActiveCats() {
  var section = document.getElementById('pf-subtab-clutter');
  if (!section) return null;
  var chips = section.querySelectorAll('.pf-cl-cat-chip');
  if (chips.length === 0) return null;
  var anyOff = false;
  var on = {};
  chips.forEach(function (c) {
    var cc = c.getAttribute('data-pf-cl-cat');
    if (c.classList.contains('pf-cl-cat-chip-off')) anyOff = true;
    else on[cc] = true;
  });
  return anyOff ? on : null;
}

function pfClSetFocal(focalCode) {
  var chart = document.getElementById('pf-clutter-chart');
  if (!chart) return;
  chart.setAttribute('data-pf-cl-focal', focalCode);

  var sel = document.getElementById('pf-cl-focal-select');
  if (sel && sel.value !== focalCode) sel.value = focalCode;

  var data = pfClLoadData();
  if (!data) return;

  var rows = pfClBuildRows(data, focalCode);
  // Filter rows by active category chips (if any chip is off).
  var active = pfClActiveCats();
  if (active) {
    rows = rows.filter(function (r) { return !!active[r.cat_code]; });
  }
  var brandColour = chart.getAttribute('data-pf-cl-focal-colour') || '#1A5276';
  var svg = pfClRenderScatter(rows, data.ref_x, brandColour);
  chart.innerHTML = svg;

  // Refresh the supporting table + coverage note for the new focal.
  pfClRenderTable(rows, focalCode, data);
  pfClRenderCoverageNote(data, focalCode);

  if (typeof brSetPinState === 'function') {
    brSetPinState('pf_cl_focal', focalCode);
  }
}

// Look up the focal brand's display label across the per-cat payload —
// first cat with a label for this code wins.
function pfClFocalLabel(data, focalCode) {
  if (!data || !data.cats || !focalCode) return focalCode;
  var keys = Object.keys(data.cats);
  for (var i = 0; i < keys.length; i++) {
    var lbls = (data.cats[keys[i]] || {}).brand_lbls || {};
    if (lbls[focalCode]) return lbls[focalCode];
  }
  return focalCode;
}

// Number of categories the focal brand is measured in vs total
// categories in the data — drives the "N of M" coverage note.
function pfClRenderCoverageNote(data, focalCode) {
  var note = document.getElementById('pf-cl-coverage');
  if (!note) return;
  var cats = (data && data.cats) || {};
  var keys = Object.keys(cats);
  var total = keys.length;
  if (total === 0) { note.textContent = ''; return; }
  var present = 0;
  keys.forEach(function (cc) {
    var pcts = (cats[cc] || {}).brand_pcts || {};
    if (Object.prototype.hasOwnProperty.call(pcts, focalCode)) present++;
  });
  var lbl = pfClFocalLabel(data, focalCode);
  note.textContent = lbl + ' is measured in ' + present +
    ' of ' + total + ' categories. Categories without ' + lbl +
    ' in the brand list are excluded from the chart and table.';
}

// Client-side context table — rebuilt on every focal change so the
// numbers always match the chart. Style mirrors the Overview Category
// detail table (dark navy header, lowercase, sortable affordance).
function pfClRenderTable(rows, focalCode, data) {
  var host = document.getElementById('pf-cl-table-host');
  if (!host) return;
  if (!rows || rows.length === 0) {
    var lbl = pfClFocalLabel(data, focalCode);
    host.innerHTML = '<p class="pf-cl-table-empty">' +
      pfClEsc(lbl) + ' is not measured in any of the listed categories.</p>';
    return;
  }

  // Sort by focal share descending so the dominant cats lead.
  var sorted = rows.slice().sort(function (a, b) {
    return (b.focal_share || 0) - (a.focal_share || 0);
  });

  // "Focal awareness" (% of cat buyers aware of focal) is shown next
  // to "Focal share" (focal's slice of the total awareness pie) so the
  // user sees both metrics side by side — the two numbers can look very
  // different, which is the source of the confusion vs the Overview tab.
  var head = '<thead><tr>' +
    '<th class="pf-cl-th-cat">Category</th>' +
    '<th class="pf-cl-th-num" title="Mean number of brands a category buyer is aware of (clutter measure)">Avg brands known</th>' +
    '<th class="pf-cl-th-num" title="% of category buyers aware of the focal brand — same metric the Overview tab uses">Focal awareness</th>' +
    '<th class="pf-cl-th-num" title="Focal’s slice of total brand-awareness mentions in the category (= focal awareness ÷ sum of every brand’s awareness)">Focal share of awareness</th>' +
    '<th class="pf-cl-th-num">Cat. penetration</th>' +
    '<th class="pf-cl-th-cat">Quadrant</th>' +
    '</tr></thead>';

  var body = sorted.map(function (r) {
    return '<tr>' +
      '<td class="pf-cl-td-cat">' + pfClEsc(r.cat_label) + '</td>' +
      '<td class="pf-cl-td-num">' +
        (r.set_size_mean == null ? '—' : Number(r.set_size_mean).toFixed(1)) +
        '</td>' +
      '<td class="pf-cl-td-num">' +
        (r.focal_pct == null ? '—' : Math.round(r.focal_pct) + '%') + '</td>' +
      '<td class="pf-cl-td-num">' +
        (r.focal_share == null ? '—' :
          Math.round(r.focal_share * 100) + '%') + '</td>' +
      '<td class="pf-cl-td-num">' +
        (r.cat_penetration == null ? '—' :
          Math.round(r.cat_penetration * 100) + '%') + '</td>' +
      '<td class="pf-cl-td-cat">' + pfClEsc(r.quadrant || '—') + '</td>' +
      '</tr>';
  }).join('');

  host.innerHTML =
    '<div class="pf-cl-table-scroll"><table class="pf-cl-table">' +
    head + '<tbody>' + body + '</tbody></table></div>';
}

function pfClBuildRows(data, focalCode) {
  var refX = data.ref_x;
  var cats = data.cats || {};
  var rows = [];
  Object.keys(cats).forEach(function (cc) {
    var c = cats[cc] || {};
    var pcts = c.brand_pcts || {};
    // Skip categories where the focal brand isn't even measured (no
    // entry in this cat's brand list). Otherwise we'd plot a 0% dot
    // that floods the bottom row of the chart and distorts the read.
    if (!Object.prototype.hasOwnProperty.call(pcts, focalCode)) return;

    var sum = 0;
    Object.keys(pcts).forEach(function (k) { sum += (pcts[k] || 0); });
    var focalPct = pcts[focalCode] || 0;
    var focalShare = sum > 0 ? focalPct / sum : 0;
    var fairShare  = (c.n_brands && c.n_brands > 0) ? 1 / c.n_brands : null;
    var quadrant;
    var isStrong = fairShare != null && focalShare > fairShare;
    var isHighClutter = (refX != null && c.set_size_mean != null &&
                          c.set_size_mean > refX);
    if (isStrong && !isHighClutter) quadrant = 'Dominant';
    else if (isStrong && isHighClutter) quadrant = 'Contested';
    else if (!isStrong && !isHighClutter) quadrant = 'Niche opportunity';
    else quadrant = 'Forgotten / wrong battle';

    rows.push({
      cat_code:        cc,
      cat_label:       c.cat_label || cc,
      set_size_mean:   c.set_size_mean,
      cat_penetration: c.cat_penetration,
      n_brands:        c.n_brands,
      focal_pct:       focalPct,
      sum_pcts:        sum,
      focal_share:     focalShare,
      fair_share:      fairShare,
      quadrant:        quadrant
    });
  });
  return rows;
}

// Pure-JS port of build_scatter (R) — generates the same visual
// contract: title, quadrant backings, ref lines, axes + ticks, dots
// sized by category penetration. Each <circle> carries data-pf-cl-cat
// so the hover handler can look up the row's full metrics.
// Collision-aware scatter label placement.
//
// Mirrors the server-side .place_scatter_labels() in 04_chart_builder.R so
// the JS-driven re-renders (focal change on Category Context / Extension)
// produce the same anti-overlap layout as the initial render. Tries 8
// candidate positions per point (E / NE / SE / W / NW / SW / N / S) at
// progressively wider offsets, scoring each by overlap with other bubbles
// and already-placed labels. Bubble positions are never moved — only labels.
//
// points: [{ svgx, svgy, r, label, isFocal }]
// returns: [{ cx, cy, anchor, leader }] same length, same order
function pfPlaceScatterLabels(points, plotLeft, plotRight, plotTop, plotBot,
                               fontSize, pad) {
  fontSize = fontSize || 10;
  pad = (pad == null) ? 4 : pad;
  var n = points.length;
  if (n === 0) return [];

  var charW = fontSize * 0.55;
  var textH = fontSize * 1.15;

  var candidates = [
    { dx:  1.0, dy:  0.0, anchor: 'start'  },
    { dx:  0.7, dy: -0.7, anchor: 'start'  },
    { dx:  0.7, dy:  0.7, anchor: 'start'  },
    { dx: -1.0, dy:  0.0, anchor: 'end'    },
    { dx: -0.7, dy: -0.7, anchor: 'end'    },
    { dx: -0.7, dy:  0.7, anchor: 'end'    },
    { dx:  0.0, dy: -1.0, anchor: 'middle' },
    { dx:  0.0, dy:  1.0, anchor: 'middle' }
  ];

  function bboxFor(pt, cand, mult) {
    var labelW = charW * (pt.label ? pt.label.length : 0);
    var cx = pt.svgx + cand.dx * (pt.r + pad) * mult;
    var cy = pt.svgy + cand.dy * (pt.r + pad) * mult;
    var x0 = cand.anchor === 'start' ? cx
           : cand.anchor === 'end'   ? cx - labelW
           :                            cx - labelW / 2;
    var y0 = cy - textH * 0.7;
    return {
      x0: x0, y0: y0, x1: x0 + labelW, y1: y0 + textH,
      cx: cx, cy: cy, anchor: cand.anchor, mult: mult
    };
  }

  function scoreBox(bb, selfIdx, placed) {
    var s = 0;
    if (bb.x0 < plotLeft)  s += (plotLeft - bb.x0) * 3;
    if (bb.x1 > plotRight) s += (bb.x1 - plotRight) * 3;
    if (bb.y0 < plotTop)   s += (plotTop - bb.y0) * 3;
    if (bb.y1 > plotBot)   s += (bb.y1 - plotBot) * 3;
    for (var i = 0; i < n; i++) {
      if (i === selfIdx) continue;
      var p = points[i];
      var cxC = Math.max(bb.x0, Math.min(p.svgx, bb.x1));
      var cyC = Math.max(bb.y0, Math.min(p.svgy, bb.y1));
      var d = Math.sqrt((cxC - p.svgx) * (cxC - p.svgx) +
                        (cyC - p.svgy) * (cyC - p.svgy));
      if (d < p.r + pad) s += (p.r + pad - d) * 8;
    }
    for (var k = 0; k < placed.length; k++) {
      var lb = placed[k];
      if (!lb) continue;
      var ow = Math.max(0, Math.min(bb.x1, lb.x1) - Math.max(bb.x0, lb.x0));
      var oh = Math.max(0, Math.min(bb.y1, lb.y1) - Math.max(bb.y0, lb.y0));
      s += ow * oh * 0.15;
    }
    return s;
  }

  // Process focal first, then longest labels first.
  var order = [];
  for (var i = 0; i < n; i++) if (points[i].isFocal) order.push(i);
  var rest = [];
  for (var j = 0; j < n; j++) if (!points[j].isFocal) rest.push(j);
  rest.sort(function (a, b) {
    return (points[b].label || '').length - (points[a].label || '').length;
  });
  order = order.concat(rest);

  var placed = new Array(n);
  var mults = [1.0, 1.5, 2.0];

  for (var oi = 0; oi < order.length; oi++) {
    var idx = order[oi];
    var pt  = points[idx];
    var best = null, bestScore = Infinity;
    for (var mi = 0; mi < mults.length; mi++) {
      for (var ci = 0; ci < candidates.length; ci++) {
        var bb = bboxFor(pt, candidates[ci], mults[mi]);
        var sc = scoreBox(bb, idx, placed);
        if (sc < bestScore) { bestScore = sc; best = bb; }
      }
      if (bestScore < 1) break;
    }
    placed[idx] = best;
  }

  return placed.map(function (bb, i) {
    var pt = points[i];
    var natural = bb.mult <= 1.0 &&
                  Math.abs(bb.cx - pt.svgx) <= pt.r * 1.6 &&
                  Math.abs(bb.cy - pt.svgy) <= pt.r * 1.6;
    return { cx: bb.cx, cy: bb.cy, anchor: bb.anchor, leader: !natural };
  });
}


function pfClRenderScatter(rows, refX, focalColour) {
  if (!rows || rows.length === 0) {
    return '<p style="color:#94a3b8;padding:24px 0;">No category data available.</p>';
  }

  var w = 820, h = 580;
  var ml = 70, mr = 30, mt = 50, mb = 60;
  var pw = w - ml - mr, ph = h - mt - mb;

  // X = set size; Y = focal share %, fixed to 0..max+pad. Y range
  // intentionally extends a touch above the data so labels don't clip.
  var xs = rows.map(function (r) { return r.set_size_mean; })
    .filter(function (v) { return v != null && isFinite(v); });
  var xMin = Math.min.apply(null, xs);
  var xMax = Math.max.apply(null, xs);
  var xPad = Math.max(0.5, (xMax - xMin) * 0.12);
  xMin -= xPad; xMax += xPad;

  var yMaxData = Math.max.apply(null, rows.map(function (r) {
    return (r.focal_share || 0) * 100;
  }).filter(function (v) { return isFinite(v); }));
  var yMax = Math.max(20, Math.min(100, Math.ceil(yMaxData / 10) * 10 + 10));
  var yMin = 0;

  // User-set axis range overrides (read from the rangebar inputs above
  // the chart). Blank input = use auto. Mirrors MA Advantage / Metrics.
  var xrUser = pfReadRange('pf-cl-xrange');
  var yrUser = pfReadRange('pf-cl-yrange');
  if (xrUser.min != null) xMin = xrUser.min;
  if (xrUser.max != null) xMax = xrUser.max;
  if (yrUser.min != null) yMin = yrUser.min;
  if (yrUser.max != null) yMax = yrUser.max;
  if (xMax <= xMin) { xMin = Math.min.apply(null, xs) - xPad;
                       xMax = Math.max.apply(null, xs) + xPad; }
  if (yMax <= yMin) { yMin = 0;
                       yMax = Math.max(20, Math.min(100, Math.ceil(yMaxData / 10) * 10 + 10)); }

  function sx(v) { return ml + ((v - xMin) / (xMax - xMin)) * pw; }
  function sy(v) { return mt + ph - ((v - yMin) / (yMax - yMin)) * ph; }

  var parts = [];

  // Title
  parts.push('<text x="' + ml + '" y="28" fill="#1e293b" font-size="14" ' +
    'font-weight="700">Category context — clutter vs focal brand position</text>');

  // Reference lines: vertical at ref_x (median set size), horizontal at
  // median fair share — same convention as the R version.
  var refY;
  var fairs = rows.map(function (r) { return r.fair_share; })
    .filter(function (v) { return v != null && isFinite(v); }).sort(function (a, b) { return a - b; });
  if (fairs.length > 0) {
    var mid = Math.floor(fairs.length / 2);
    refY = (fairs.length % 2 ? fairs[mid] : (fairs[mid - 1] + fairs[mid]) / 2) * 100;
  }

  // Quadrant backgrounds
  if (refX != null && refY != null) {
    var rx = sx(refX), ry = sy(refY);
    var fills = ['#f0fdf4', '#eff6ff', '#fefce8', '#fdf2f8'];
    parts.push(
      '<rect x="' + ml + '" y="' + mt + '" width="' + (rx - ml) + '" height="' + (ry - mt) + '" fill="' + fills[0] + '" opacity="0.5"/>',
      '<rect x="' + rx + '" y="' + mt + '" width="' + (ml + pw - rx) + '" height="' + (ry - mt) + '" fill="' + fills[1] + '" opacity="0.5"/>',
      '<rect x="' + ml + '" y="' + ry + '" width="' + (rx - ml) + '" height="' + (mt + ph - ry) + '" fill="' + fills[2] + '" opacity="0.5"/>',
      '<rect x="' + rx + '" y="' + ry + '" width="' + (ml + pw - rx) + '" height="' + (mt + ph - ry) + '" fill="' + fills[3] + '" opacity="0.5"/>'
    );
    parts.push(
      '<text x="' + (ml + 8)      + '" y="' + (mt + 16)      + '" fill="#64748b" font-size="10" font-weight="600">Dominant</text>',
      '<text x="' + (ml + pw - 8) + '" y="' + (mt + 16)      + '" fill="#64748b" font-size="10" font-weight="600" text-anchor="end">Contested</text>',
      '<text x="' + (ml + 8)      + '" y="' + (mt + ph - 8) + '" fill="#64748b" font-size="10" font-weight="600">Niche opportunity</text>',
      '<text x="' + (ml + pw - 8) + '" y="' + (mt + ph - 8) + '" fill="#64748b" font-size="10" font-weight="600" text-anchor="end">Forgotten / wrong battle</text>'
    );
    parts.push(
      '<line x1="' + rx + '" y1="' + mt + '" x2="' + rx + '" y2="' + (mt + ph) + '" stroke="#94a3b8" stroke-width="1" stroke-dasharray="5,3"/>',
      '<line x1="' + ml + '" y1="' + ry + '" x2="' + (ml + pw) + '" y2="' + ry + '" stroke="#94a3b8" stroke-width="1" stroke-dasharray="5,3"/>'
    );
  }

  // Axes (ticks + labels)
  var xTicks = pfClPretty(xMin, xMax, 5);
  var yTicks = pfClPretty(yMin, yMax, 5);
  xTicks.forEach(function (t) {
    parts.push('<text x="' + sx(t) + '" y="' + (mt + ph + 16) +
      '" text-anchor="middle" fill="#94a3b8" font-size="10">' +
      pfClFormatNum(t, 1) + '</text>');
  });
  yTicks.forEach(function (t) {
    parts.push('<text x="' + (ml - 8) + '" y="' + sy(t) +
      '" text-anchor="end" dominant-baseline="middle" fill="#94a3b8" font-size="10">' +
      pfClFormatNum(t, 0) + '%</text>');
  });
  parts.push('<text x="' + (ml + pw / 2) + '" y="' + (h - 8) +
    '" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500">' +
    'Awareness set size (brands known per buyer)</text>');
  parts.push('<text x="14" y="' + (mt + ph / 2) +
    '" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500" ' +
    'transform="rotate(-90,14,' + (mt + ph / 2) + ')">' +
    'Focal share of awareness (%)</text>');

  parts.push('<rect x="' + ml + '" y="' + mt + '" width="' + pw + '" height="' + ph +
    '" fill="none" stroke="#e2e8f0"/>');

  // Dots — radius scaled by category penetration. Two-pass placement:
  // build bubble specs first, then run collision-aware label placement
  // so categories sharing coordinates don't end up with stacked labels.
  var maxPen = Math.max.apply(null, rows.map(function (r) {
    return r.cat_penetration || 0;
  }));
  if (!(maxPen > 0)) maxPen = 1;

  var dots = [];
  rows.forEach(function (r) {
    if (r.set_size_mean == null || r.focal_share == null) return;
    var fy = r.focal_share * 100;
    // Skip out-of-range categories so a custom zoom doesn't paint
    // half-bubbles on the plot edge.
    if (r.set_size_mean < xMin || r.set_size_mean > xMax) return;
    if (fy < yMin || fy > yMax) return;
    var cx = sx(r.set_size_mean);
    var cy = sy(fy);
    var radius = Math.max(5, Math.min(20, 5 + (r.cat_penetration / maxPen) * 15));
    dots.push({
      svgx: cx, svgy: cy, r: radius,
      label: pfClTrunc(r.cat_label, 22),
      isFocal: false,
      cat_code: r.cat_code
    });
  });

  var dotPlacements = pfPlaceScatterLabels(
    dots, ml, ml + pw, mt, mt + ph, 10, 4
  );

  dots.forEach(function (d, i) {
    var pl = dotPlacements[i];
    if (pl.leader) {
      parts.push(
        '<line x1="' + d.svgx + '" y1="' + d.svgy +
        '" x2="' + pl.cx + '" y2="' + pl.cy +
        '" stroke="#cbd5e1" stroke-width="0.8" opacity="0.7"/>'
      );
    }
    parts.push(
      '<circle class="pf-cl-dot" data-pf-cl-cat="' + pfClEsc(d.cat_code) +
      '" cx="' + d.svgx + '" cy="' + d.svgy + '" r="' + d.r + '" ' +
      'fill="' + focalColour + '" opacity="0.85" stroke="#fff" stroke-width="2" ' +
      'style="cursor:pointer;"></circle>',
      '<text class="pf-cl-dot-label" data-pf-cl-cat="' + pfClEsc(d.cat_code) +
      '" x="' + pl.cx + '" y="' + pl.cy +
      '" text-anchor="' + pl.anchor + '" fill="#1e293b" font-size="10" font-weight="500">' +
      pfClEsc(d.label) + '</text>'
    );
  });

  return '<svg viewBox="0 0 ' + w + ' ' + h +
    '" style="font-family:inherit;width:100%;max-width:' + w +
    'px;height:auto;display:block;margin:0 auto;" role="img" ' +
    'aria-label="Category context scatter">' + parts.join('') + '</svg>';
}

// Round-friendly tick generation — emulates pretty() coarsely.
function pfClPretty(lo, hi, n) {
  var range = hi - lo;
  if (!(range > 0)) return [lo];
  var step = Math.pow(10, Math.floor(Math.log10(range / n)));
  var err  = (range / n) / step;
  if (err >= 7.5) step *= 10;
  else if (err >= 3.5) step *= 5;
  else if (err >= 1.5) step *= 2;
  var ticks = [];
  var first = Math.ceil(lo / step) * step;
  for (var v = first; v <= hi + 1e-9; v += step) ticks.push(v);
  return ticks;
}

function pfClFormatNum(v, d) {
  if (v == null || !isFinite(v)) return '—';
  return Number(v).toFixed(d);
}
function pfClTrunc(s, n) {
  if (s == null) return '';
  s = String(s);
  return s.length > n ? s.substring(0, n - 1) + '…' : s;
}
function pfClEsc(s) {
  if (s == null) return '';
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// Hover tooltip — reuses the same floating <div> pattern as the
// constellation tab, but builds a multi-line message about the cat.
function pfClBindHoverTooltips(section) {
  section.addEventListener('mouseover', function (ev) {
    var dot = ev.target.closest && ev.target.closest('.pf-cl-dot');
    if (!dot) return;
    var tip = pfCnGetTooltip();
    var cat = dot.getAttribute('data-pf-cl-cat');
    var focal = section.querySelector('.pf-cl-chart')
      ? section.querySelector('.pf-cl-chart').getAttribute('data-pf-cl-focal')
      : '';
    tip.textContent = pfClFormatTooltip(cat, focal);
    tip.setAttribute('aria-hidden', 'false');
    pfCnPositionTooltip(tip, ev);
  });
  section.addEventListener('mousemove', function (ev) {
    var dot = ev.target.closest && ev.target.closest('.pf-cl-dot');
    if (!dot) return;
    var tip = pfCnGetTooltip();
    if (tip.getAttribute('aria-hidden') === 'true') return;
    pfCnPositionTooltip(tip, ev);
  });
  section.addEventListener('mouseout', function (ev) {
    var dot = ev.target.closest && ev.target.closest('.pf-cl-dot');
    if (!dot) return;
    var to = ev.relatedTarget;
    if (to && dot.contains(to)) return;
    var tip = pfCnGetTooltip();
    tip.style.opacity = '0';
    tip.style.visibility = 'hidden';
    tip.setAttribute('aria-hidden', 'true');
  });
}

function pfClFormatTooltip(catCode, focalCode) {
  var data = pfClLoadData();
  if (!data || !data.cats || !data.cats[catCode]) return catCode;
  var rows = pfClBuildRows(data, focalCode);
  var r = rows.find(function (x) { return x.cat_code === catCode; });
  if (!r) return catCode;
  var brandLbls = (data.cats[catCode] || {}).brand_lbls || {};
  var focalLabel = brandLbls[focalCode] || focalCode;
  // Show BOTH the awareness rate and the share-of-awareness so the
  // distinction (and the difference vs the Overview tab) is explicit.
  return r.cat_label +
    '\nQuadrant: ' + r.quadrant +
    '\n' + focalLabel + ' awareness: ' +
      Math.round(r.focal_pct || 0) + '% of category buyers' +
    '\n' + focalLabel + ' share of awareness: ' +
      Math.round(r.focal_share * 100) +
      '% (= focal awareness ÷ sum of every brand’s awareness)' +
    '\nSet size: ' + Number(r.set_size_mean).toFixed(1) + ' brands known per buyer' +
    '\nCategory penetration: ' +
      Math.round((r.cat_penetration || 0) * 100) + '% of all respondents';
}

// ---------------------------------------------------------------------------
// EXTENSION — focal picker, client-side strength bubble + extension table
// ---------------------------------------------------------------------------

function pfExLoadData() {
  var node = document.getElementById('pf-ex-data');
  if (!node) return null;
  try { return JSON.parse(node.textContent || '{}'); }
  catch (e) { console.warn('[pf-ex] Failed to parse JSON:', e); return null; }
}

function pfExInit() {
  var section = document.getElementById('pf-subtab-extension');
  if (!section) return;
  var data = pfExLoadData();
  if (!data) return;

  pfExBindHoverTooltips(section);

  var sel = document.getElementById('pf-ex-focal-select');
  if (sel) {
    sel.addEventListener('change', function () { pfBroadcastFocal(sel.value); });
  }

  // Axis range inputs — re-render the strength scatter on edit / reset.
  pfBindRangeInputs(section, 'pf-ex-xrange',
    function () { pfExRerenderCurrentFocal(); });
  pfBindRangeInputs(section, 'pf-ex-yrange',
    function () { pfExRerenderCurrentFocal(); });

  var layout = section.querySelector('.pf-ex-layout');
  var initial = layout ? layout.getAttribute('data-pf-ex-focal') : '';
  if (initial) pfExSetFocal(initial);
}

function pfExSetFocal(focalCode) {
  var section = document.getElementById('pf-subtab-extension');
  if (!section) return;
  var layout = section.querySelector('.pf-ex-layout');
  if (!layout) return;
  layout.setAttribute('data-pf-ex-focal', focalCode);

  var sel = document.getElementById('pf-ex-focal-select');
  if (sel && sel.value !== focalCode) sel.value = focalCode;

  var data = pfExLoadData() || {};
  var brandColour = layout.getAttribute('data-pf-ex-focal-colour') || '#1A5276';
  var brandLabel  = pfExBrandLabel(data, focalCode);

  // Strength bubble chart (left half).
  var strengthHost = document.getElementById('pf-extension-strength');
  if (strengthHost) {
    var bubbles = (data.strength || {})[focalCode] || [];
    strengthHost.innerHTML = pfExRenderStrength(bubbles, brandColour, brandLabel);
  }

  // Extension table (right half).
  var tableHost = document.getElementById('pf-extension-table');
  if (tableHost) {
    var ext = (data.extension || {})[focalCode] || { rows: [] };
    tableHost.innerHTML = pfExRenderTable(ext, brandLabel);
  }

  if (typeof brSetPinState === 'function') {
    brSetPinState('pf_ex_focal', focalCode);
  }
}

function pfExBrandLabel(data, code) {
  if (!data || !code) return code;
  var lbls = data.brand_names || {};
  return lbls[code] || code;
}

// ---- Strength bubble renderer -----------------------------------------------

function pfExRenderStrength(bubbles, focalColour, brandLabel) {
  if (!bubbles || bubbles.length === 0) {
    return '<p class="pf-ex-empty">No strength-map data for ' +
      pfClEsc(brandLabel) + ' — the brand is not measured in any qualifying category.</p>';
  }

  var w = 560, h = 460;
  var ml = 60, mr = 30, mt = 50, mb = 60;
  var pw = w - ml - mr, ph = h - mt - mb;

  // X = cat penetration % (0..max), Y = focal awareness % (0..100).
  var xMaxAuto = Math.max.apply(null, bubbles.map(function (b) { return b.x; }));
  xMaxAuto = Math.max(20, Math.ceil((xMaxAuto + 5) / 10) * 10);
  var xMin = 0, xMax = xMaxAuto;
  var yMin = 0, yMax = 100;

  // User-set axis-range overrides from the rangebar inputs.
  var xrUser = pfReadRange('pf-ex-xrange');
  var yrUser = pfReadRange('pf-ex-yrange');
  if (xrUser.min != null) xMin = xrUser.min;
  if (xrUser.max != null) xMax = xrUser.max;
  if (yrUser.min != null) yMin = yrUser.min;
  if (yrUser.max != null) yMax = yrUser.max;
  if (xMax <= xMin) { xMin = 0; xMax = xMaxAuto; }
  if (yMax <= yMin) { yMin = 0; yMax = 100; }

  function sx(v) { return ml + ((v - xMin) / (xMax - xMin)) * pw; }
  function sy(v) { return mt + ph - ((v - yMin) / (yMax - yMin)) * ph; }

  var maxSize = Math.max.apply(null, bubbles.map(function (b) { return b.size || 0; }));
  if (!(maxSize > 0)) maxSize = 1;

  var parts = [];
  parts.push('<text x="' + ml + '" y="28" fill="#1e293b" font-size="14" font-weight="700">' +
    'Portfolio strength — ' + pfClEsc(brandLabel) + '</text>');

  // Diagonal "y = x" reference (where awareness == cat penetration).
  parts.push('<line x1="' + sx(0) + '" y1="' + sy(0) + '" x2="' + sx(Math.min(xMax, yMax)) +
    '" y2="' + sy(Math.min(xMax, yMax)) +
    '" stroke="#cbd5e1" stroke-width="1.5" stroke-dasharray="6 4"/>');

  // Axes (ticks + labels)
  pfClPretty(xMin, xMax, 5).forEach(function (t) {
    parts.push('<text x="' + sx(t) + '" y="' + (mt + ph + 16) +
      '" text-anchor="middle" fill="#94a3b8" font-size="10">' +
      pfClFormatNum(t, 0) + '%</text>');
  });
  pfClPretty(yMin, yMax, 5).forEach(function (t) {
    parts.push('<text x="' + (ml - 8) + '" y="' + sy(t) +
      '" text-anchor="end" dominant-baseline="middle" fill="#94a3b8" font-size="10">' +
      pfClFormatNum(t, 0) + '%</text>');
  });
  parts.push('<text x="' + (ml + pw / 2) + '" y="' + (h - 8) +
    '" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500">' +
    'Category penetration (% of all respondents)</text>');
  parts.push('<text x="14" y="' + (mt + ph / 2) +
    '" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500" ' +
    'transform="rotate(-90,14,' + (mt + ph / 2) + ')">' +
    pfClEsc(brandLabel) + ' awareness among buyers (%)</text>');
  parts.push('<rect x="' + ml + '" y="' + mt + '" width="' + pw + '" height="' + ph +
    '" fill="none" stroke="#e2e8f0"/>');

  // Bubbles — collision-aware label placement (same algorithm as the
  // clutter scatter). Build bubble specs first, then place labels.
  // Out-of-range bubbles are dropped so custom axis zooms render cleanly.
  var exDots = [];
  bubbles.forEach(function (b) {
    if (b.x < xMin || b.x > xMax) return;
    if (b.y < yMin || b.y > yMax) return;
    exDots.push({
      svgx: sx(b.x), svgy: sy(b.y),
      r: Math.max(6, Math.min(28, 6 + (b.size / maxSize) * 22)),
      label: pfClTrunc(b.cat_label, 22),
      isFocal: false,
      cat: b.cat
    });
  });

  var exPlacements = pfPlaceScatterLabels(
    exDots, ml, ml + pw, mt, mt + ph, 10, 4
  );

  exDots.forEach(function (d, i) {
    var pl = exPlacements[i];
    if (pl.leader) {
      parts.push(
        '<line x1="' + d.svgx + '" y1="' + d.svgy +
        '" x2="' + pl.cx + '" y2="' + pl.cy +
        '" stroke="#cbd5e1" stroke-width="0.8" opacity="0.7"/>'
      );
    }
    parts.push(
      '<circle class="pf-ex-bubble" data-pf-ex-cat="' + pfClEsc(d.cat) +
      '" cx="' + d.svgx + '" cy="' + d.svgy + '" r="' + d.r + '" ' +
      'fill="' + focalColour + '" opacity="0.7" stroke="#fff" stroke-width="2" ' +
      'style="cursor:pointer;"></circle>',
      '<text class="pf-ex-bubble-label" x="' + pl.cx + '" y="' + pl.cy +
      '" text-anchor="' + pl.anchor + '" fill="#1e293b" font-size="10" font-weight="500">' +
      pfClEsc(d.label) + '</text>'
    );
  });

  return '<svg viewBox="0 0 ' + w + ' ' + h +
    '" style="font-family:inherit;width:100%;max-width:' + w +
    'px;height:auto;display:block;margin:0 auto;" role="img" ' +
    'aria-label="Portfolio strength scatter">' + parts.join('') + '</svg>';
}

// ---- Extension table --------------------------------------------------------

function pfExRenderTable(ext, brandLabel) {
  var rows = (ext && ext.rows) || [];
  if (rows.length === 0) {
    return '<div class="pf-ex-empty">' +
      '<p><strong>No extension lift data for ' + pfClEsc(brandLabel) + '.</strong></p>' +
      '<p>Permission-to-extend analysis needs cross-category awareness data — ' +
      'the questionnaire has to ask whether buyers in <em>other</em> categories are aware of ' +
      pfClEsc(brandLabel) + '. ' +
      'For this brand the questionnaire didn’t collect that data, so there are no extension ' +
      'targets to score.</p>' +
      '</div>';
  }

  var homeCat = ext.home_cat || '';
  var homeRow = rows.find(function (r) { return r.is_home; });
  var nonHome = rows.filter(function (r) { return !r.is_home; });
  // Already sorted by lift desc on the server; defensive re-sort here too.
  nonHome.sort(function (a, b) { return (b.lift || 0) - (a.lift || 0); });

  // Sparse-coverage state: if there are no non-home cats, the brand's
  // cross-cat awareness is limited to its home category. Show the home
  // row plus an explanation of why there's nothing to extend INTO.
  if (nonHome.length === 0) {
    var homeLabel = homeRow ? (homeRow.cat_label || homeRow.cat) : (homeCat || '—');
    return '<div class="pf-ex-empty">' +
      '<p><strong>' + pfClEsc(brandLabel) + ' is only measured in 1 category (' +
      pfClEsc(homeLabel) + ').</strong></p>' +
      '<p>Permission-to-extend ranks <em>other</em> categories by their awareness lift for the focal brand — ' +
      'so it needs at least one non-home category with cross-category awareness data. ' +
      'For ' + pfClEsc(brandLabel) + ', the questionnaire didn’t ask buyers of other categories whether they’re aware of this brand, ' +
      'so there are no extension targets to score.</p>' +
      '<p>To enable extension analysis for this brand, the next wave would need to add ' + pfClEsc(brandLabel) +
      ' to the awareness battery in additional categories.</p>' +
      '</div>';
  }

  var rendered = [];
  if (homeRow) rendered.push(homeRow);
  rendered = rendered.concat(nonHome);

  var head = '<thead><tr>' +
    '<th class="pf-ex-th-cat">Category</th>' +
    '<th class="pf-ex-th-num" title="Number of category buyers in the unweighted base">Buyers (n)</th>' +
    '<th class="pf-ex-th-num" title="% of category buyers aware of the focal">Aware of focal</th>' +
    '<th class="pf-ex-th-num" title="P(aware focal | bought cat) ÷ P(aware focal | baseline)">Lift</th>' +
    '<th class="pf-ex-th-num" title="★ = significant after BH correction; † = low base">Sig.</th>' +
    '</tr></thead>';

  var body = rendered.map(function (r) {
    var rowCls = r.is_home ? ' class="pf-ex-row-home"' : '';
    var lbl = pfClEsc(r.cat_label || r.cat);
    var n   = r.n_buyers_uw == null ? '—' :
                Number(r.n_buyers_uw).toLocaleString('en-US');
    var aw  = (r.focal_aware_pct == null || isNaN(r.focal_aware_pct)) ? '—' :
                (Math.round(r.focal_aware_pct) + '%');
    var lift = r.is_home ? '<span class="pf-ex-home-tag">home</span>' :
                ((r.lift == null || isNaN(r.lift)) ? '—' :
                  (r.low_base_flag ? Number(r.lift).toFixed(2) + ' †' :
                                      Number(r.lift).toFixed(2)));
    var sig = '';
    if (!r.is_home && r.p_adj != null && !isNaN(r.p_adj) && r.p_adj < 0.05) {
      sig = '★';
    }
    return '<tr' + rowCls + ' data-pf-ex-cat="' + pfClEsc(r.cat) + '">' +
      '<td class="pf-ex-td-cat">' + lbl + '</td>' +
      '<td class="pf-ex-td-num">' + n + '</td>' +
      '<td class="pf-ex-td-num">' + aw + '</td>' +
      '<td class="pf-ex-td-num pf-ex-td-lift">' + lift + '</td>' +
      '<td class="pf-ex-td-num pf-ex-td-sig">' + sig + '</td></tr>';
  }).join('');

  // Baseline + formula caption — repeated above the table so a reader
  // who jumps straight to the numbers sees how lift was computed
  // without scrolling to the reading guide.
  var formulaNote = '<p class="pf-ex-table-note">' +
    '<strong>Lift</strong> = ' +
    'P(aware of focal | bought category) ÷ P(aware of focal | all respondents). ' +
    'Numerator is shown in the "aware of focal" column; baseline is the focal’s ' +
    'awareness rate across the full sample for the same awareness column. ' +
    '★ = significant after BH correction. † = low category base, interpret cautiously.</p>';

  var homeNote = homeCat ? ('<p class="pf-ex-table-note">' +
    'Home category: <strong>' + pfClEsc(homeCat) + '</strong>. ' +
    'Other categories ranked by lift. The home row is greyed out as a reference, ' +
    'not an extension target.</p>') : '';

  return '<h3 class="pf-ex-section-title">Permission to extend</h3>' +
    formulaNote + homeNote +
    '<div class="pf-ex-table-scroll"><table class="pf-ex-table">' +
    head + '<tbody>' + body + '</tbody></table></div>';
}

// ---- Hover tooltip ----------------------------------------------------------

function pfExBindHoverTooltips(section) {
  section.addEventListener('mouseover', function (ev) {
    var target = ev.target;
    var bubble = target.closest && target.closest('.pf-ex-bubble');
    var row    = target.closest && target.closest('tr[data-pf-ex-cat]');
    var node   = bubble || row;
    if (!node) return;
    var tip = pfCnGetTooltip();
    var layout = section.querySelector('.pf-ex-layout');
    var focal = layout ? layout.getAttribute('data-pf-ex-focal') : '';
    var cat = node.getAttribute('data-pf-ex-cat') ||
              node.getAttribute('data-pf-ex-cat');
    tip.textContent = pfExFormatTooltip(cat, focal);
    tip.setAttribute('aria-hidden', 'false');
    pfCnPositionTooltip(tip, ev);
  });
  section.addEventListener('mousemove', function (ev) {
    var target = ev.target;
    var bubble = target.closest && target.closest('.pf-ex-bubble');
    var row    = target.closest && target.closest('tr[data-pf-ex-cat]');
    if (!(bubble || row)) return;
    var tip = pfCnGetTooltip();
    if (tip.getAttribute('aria-hidden') === 'true') return;
    pfCnPositionTooltip(tip, ev);
  });
  section.addEventListener('mouseout', function (ev) {
    var target = ev.target;
    var bubble = target.closest && target.closest('.pf-ex-bubble');
    var row    = target.closest && target.closest('tr[data-pf-ex-cat]');
    var node   = bubble || row;
    if (!node) return;
    var to = ev.relatedTarget;
    if (to && node.contains(to)) return;
    var tip = pfCnGetTooltip();
    tip.style.opacity = '0';
    tip.style.visibility = 'hidden';
    tip.setAttribute('aria-hidden', 'true');
  });
}

function pfExFormatTooltip(catCode, focalCode) {
  var data = pfExLoadData() || {};
  var bubbles = (data.strength || {})[focalCode] || [];
  var ext     = (data.extension || {})[focalCode] || { rows: [] };
  var b = bubbles.find(function (x) { return x.cat === catCode; });
  var r = (ext.rows || []).find(function (x) { return x.cat === catCode; });
  var brandLabel = pfExBrandLabel(data, focalCode);
  var lbl = (b && b.cat_label) || (r && r.cat_label) || catCode;

  var lines = [lbl];
  if (b) {
    lines.push('Category penetration: ' + Math.round(b.x) + '% of all respondents');
    lines.push(brandLabel + ' awareness: ' + Math.round(b.y) + '% of category buyers');
  }
  if (r && !r.is_home) {
    if (r.lift != null && !isNaN(r.lift) &&
        r.focal_aware_pct != null && !isNaN(r.focal_aware_pct) &&
        r.lift > 0) {
      // Derive the baseline awareness rate from numerator and lift so
      // users can see both halves of the ratio without us re-computing
      // it server-side.
      var baselinePct = r.focal_aware_pct / r.lift;
      lines.push('Lift = ' + Math.round(r.focal_aware_pct) +
        '% ÷ ' + baselinePct.toFixed(0) + '% = ' +
        Number(r.lift).toFixed(2) + '×' +
        (r.p_adj != null && r.p_adj < 0.05 ? ' (significant)' :
          (r.p_adj != null ? ' (not significant)' : '')));
      lines.push('  · Numerator: ' + Math.round(r.focal_aware_pct) +
        '% of category buyers aware of focal');
      lines.push('  · Baseline: ' + baselinePct.toFixed(0) +
        '% of all respondents aware of focal');
    } else if (r.lift != null && !isNaN(r.lift)) {
      lines.push('Lift vs baseline: ' + Number(r.lift).toFixed(2) + '×');
    }
    if (r.low_base_flag) lines.push('Low category base — interpret cautiously');
  } else if (r && r.is_home) {
    lines.push('Home category — reference point, not an extension target');
  }
  return lines.join('\n');
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
    pfInitConstellationChips();
    pfClInit();
    pfExInit();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', pfInit);
  } else {
    pfInit();
  }
})();
