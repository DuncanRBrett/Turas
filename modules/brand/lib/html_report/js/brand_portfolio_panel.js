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
 * Restore portfolio panel state from a pin payload.
 * Called by brand_pins.js when a portfolio pin is activated.
 * @param {Object} state - Pin state object.
 */
function pfRestorePinState(state) {
  if (!state) return;
  if (state.subtab) pfSwitchSubtab(state.subtab);
  // Phase 3: restore brand chip selection
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
