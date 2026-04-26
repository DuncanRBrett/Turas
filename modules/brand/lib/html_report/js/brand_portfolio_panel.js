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

  // Focal-brand picker.
  var sel = document.getElementById('pf-cn-focal-select');
  if (sel) {
    sel.addEventListener('change', function () {
      pfCnSetFocal(sel.value);
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

  // Reset every node + label to comparator styling.
  svg.querySelectorAll('.pf-cn-node').forEach(function (n) {
    var baseR = parseFloat(n.getAttribute('data-pf-cn-base-r')) || 8;
    n.classList.remove('pf-cn-node-focal');
    n.setAttribute('r', baseR);
    n.setAttribute('fill', '#94a3b8');
  });
  svg.querySelectorAll('.pf-cn-label').forEach(function (t) {
    t.classList.remove('pf-cn-label-focal');
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
  // Layout (Fruchterman-Reingold) places nodes by GLOBAL stress so visual
  // distance is not a faithful read of pairwise Jaccard with the focal —
  // the highlighted edges show the true focal-relative ranking on top.
  var focalEdges = svg.querySelectorAll(
    '.pf-cn-edge[data-pf-cn-b1="' + fcss + '"], ' +
    '.pf-cn-edge[data-pf-cn-b2="' + fcss + '"]');
  var maxJac = 0;
  focalEdges.forEach(function (e) {
    var j = parseFloat(e.getAttribute('data-pf-cn-jac')) || 0;
    if (j > maxJac) maxJac = j;
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

  // Hover tooltip text is built on demand by pfCnFormatTooltip from
  // the live edge data, so no pre-population is needed when focal changes.
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
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', pfInit);
  } else {
    pfInit();
  }
})();
