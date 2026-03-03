/* ==============================================================================
 * CATDRIVER HTML REPORT - UNIFIED TAB SWITCHING
 * ==============================================================================
 * Switches between analysis tabs in unified multi-outcome reports.
 * Follows the tabs/tracker .report-tab pattern: toggle .active class
 * on buttons (.cd-analysis-tab) and panels (.cd-analysis-panel).
 * ============================================================================== */

(function() {
  'use strict';

  window.cdSwitchAnalysisTab = function(tabId) {
    // Update tab buttons
    document.querySelectorAll('.cd-analysis-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.getAttribute('data-tab') === tabId);
    });

    // Hide all panels, show target
    document.querySelectorAll('.cd-analysis-panel').forEach(function(panel) {
      panel.classList.remove('active');
    });

    var target = document.getElementById('cd-tab-' + tabId);
    if (target) {
      target.classList.add('active');
      // Scroll to top of content when switching tabs
      window.scrollTo({ top: 0, behavior: 'instant' });
    }
  };

  // Initialise: activate the first tab on load
  document.addEventListener('DOMContentLoaded', function() {
    var firstTab = document.querySelector('.cd-analysis-tab');
    if (firstTab) {
      cdSwitchAnalysisTab(firstTab.getAttribute('data-tab'));
    }
  });

})();
