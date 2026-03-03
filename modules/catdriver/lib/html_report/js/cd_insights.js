/* ==============================================================================
 * CATDRIVER HTML REPORT - INSIGHT EDITORS
 * ==============================================================================
 * Per-section editable text areas for analyst comments/insights.
 * One insight per section per analysis panel.
 * Stores as JSON in hidden <textarea> per panel.
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  /**
   * Get the insight JSON store for a given prefix.
   * @param {string} prefix - ID prefix (e.g., 'nps-')
   * @returns {Object} Parsed JSON object
   */
  window.cdGetInsightStore = function(prefix) {
    prefix = prefix || '';
    var store = document.getElementById(prefix + 'cd-insight-store');
    if (!store || !store.value) return {};
    try { return JSON.parse(store.value); } catch (e) { return {}; }
  };

  /**
   * Set the insight JSON store for a given prefix.
   * @param {string} prefix - ID prefix
   * @param {Object} obj - JSON-serializable object
   */
  window.cdSetInsightStore = function(prefix, obj) {
    prefix = prefix || '';
    var store = document.getElementById(prefix + 'cd-insight-store');
    if (store) store.value = JSON.stringify(obj);
  };

  /**
   * Toggle insight editor visibility.
   * @param {string} sectionKey - Section key (e.g., 'exec-summary')
   * @param {string} prefix - ID prefix
   */
  window.cdToggleInsight = function(sectionKey, prefix) {
    prefix = prefix || '';
    var container = document.getElementById(prefix + 'cd-insight-container-' + sectionKey);
    var toggle = document.getElementById(prefix + 'cd-insight-toggle-' + sectionKey);
    if (!container) return;

    var isHidden = container.style.display === 'none' || !container.style.display;
    container.style.display = isHidden ? 'block' : 'none';
    if (toggle) {
      toggle.textContent = isHidden ? '− Hide Insight' : '+ Add Insight';
    }

    // Focus editor when opening
    if (isHidden) {
      var editor = container.querySelector('.cd-insight-editor');
      if (editor) editor.focus();
    }
  };

  /**
   * Dismiss (clear + hide) an insight editor.
   * @param {string} sectionKey - Section key
   * @param {string} prefix - ID prefix
   */
  window.cdDismissInsight = function(sectionKey, prefix) {
    prefix = prefix || '';
    var container = document.getElementById(prefix + 'cd-insight-container-' + sectionKey);
    var toggle = document.getElementById(prefix + 'cd-insight-toggle-' + sectionKey);
    if (container) {
      var editor = container.querySelector('.cd-insight-editor');
      if (editor) editor.textContent = '';
      container.style.display = 'none';
    }
    if (toggle) toggle.textContent = '+ Add Insight';

    // Clear from store
    var data = cdGetInsightStore(prefix);
    delete data[sectionKey];
    cdSetInsightStore(prefix, data);
  };

  /**
   * Sync insight editor text to hidden store.
   * @param {string} sectionKey - Section key
   * @param {string} prefix - ID prefix
   */
  window.cdSyncInsight = function(sectionKey, prefix) {
    prefix = prefix || '';
    var container = document.getElementById(prefix + 'cd-insight-container-' + sectionKey);
    if (!container) return;

    var editor = container.querySelector('.cd-insight-editor');
    if (!editor) return;

    var text = editor.textContent.trim();
    var data = cdGetInsightStore(prefix);
    if (text) {
      data[sectionKey] = text;
    } else {
      delete data[sectionKey];
    }
    cdSetInsightStore(prefix, data);
  };

  /**
   * Sync all insight editors to their stores (call before save).
   */
  window.cdSyncAllInsights = function() {
    document.querySelectorAll('.cd-insight-editor').forEach(function(editor) {
      var area = editor.closest('.cd-insight-area');
      if (!area) return;
      var sectionKey = area.getAttribute('data-cd-insight-section');
      var prefix = area.getAttribute('data-cd-insight-prefix') || '';
      if (sectionKey) cdSyncInsight(sectionKey, prefix);
    });
  };

  /**
   * Hydrate insight editors from their stores (call on page load).
   */
  window.cdHydrateInsights = function() {
    // Find all insight stores
    document.querySelectorAll('textarea.cd-insight-store').forEach(function(store) {
      var prefix = store.getAttribute('data-cd-prefix') || '';
      var data;
      try { data = JSON.parse(store.value || '{}'); } catch (e) { data = {}; }

      Object.keys(data).forEach(function(sectionKey) {
        var text = data[sectionKey];
        if (!text) return;

        var container = document.getElementById(prefix + 'cd-insight-container-' + sectionKey);
        var toggle = document.getElementById(prefix + 'cd-insight-toggle-' + sectionKey);
        if (!container) return;

        var editor = container.querySelector('.cd-insight-editor');
        if (editor) editor.textContent = text;
        container.style.display = 'block';
        if (toggle) toggle.textContent = '− Hide Insight';
      });
    });
  };

})();
