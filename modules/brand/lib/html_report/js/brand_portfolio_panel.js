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
 * Restore portfolio panel state from a pin payload.
 * Called by brand_pins.js when a portfolio pin is activated.
 * @param {Object} state - Pin state object.
 */
function pfRestorePinState(state) {
  if (!state) return;
  if (state.subtab) pfSwitchSubtab(state.subtab);
  if (state.pf_strength_brand) pfSwitchStrengthBrand(state.pf_strength_brand);
  // Phase 4: restore constellation centred_brand
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
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', pfInit);
  } else {
    pfInit();
  }
})();
