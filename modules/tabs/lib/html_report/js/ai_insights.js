// =============================================================================
// AI INSIGHTS — Client-Side JavaScript
// =============================================================================
//
// Toggle and pin functionality for AI insight callout panels.
// Loaded into HTML reports when AI insights are enabled.
//
// Functions:
//   toggleAllCallouts(show)  — Show/hide all AI callout panels
//   toggleCalloutPin(btn)    — Pin/unpin an individual AI callout
//
// =============================================================================

/**
 * Toggle visibility of all AI callout panels.
 * Does not affect the executive summary or researcher commentary.
 *
 * @param {boolean} show - Whether to show (true) or hide (false) callouts.
 */
function toggleAllCallouts(show) {
  var callouts = document.querySelectorAll('.turas-ai-callout:not(.turas-ai-exec)');
  callouts.forEach(function(el) {
    el.style.display = show ? '' : 'none';
  });
}

/**
 * Toggle the pinned state of an individual AI callout.
 * Pinned callouts are included in print/PDF output and slide export.
 *
 * @param {HTMLElement} btn - The pin button element that was clicked.
 */
function toggleCalloutPin(btn) {
  var callout = btn.closest('.turas-ai-callout');
  if (!callout) return;

  var isPinned = callout.getAttribute('data-pinned') === 'true';
  callout.setAttribute('data-pinned', isPinned ? 'false' : 'true');
}
