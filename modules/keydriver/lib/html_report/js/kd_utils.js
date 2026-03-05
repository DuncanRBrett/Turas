/* ==============================================================================
 * KEYDRIVER HTML REPORT - UTILITY FUNCTIONS
 * ==============================================================================
 * Shared helpers: Blob download, HTML escape, SVG text wrapping.
 * All functions prefixed kd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  /**
   * Download a Blob as a file.
   * @param {Blob} blob - The file blob
   * @param {string} filename - Suggested filename
   */
  window.kdDownloadBlob = function(blob, filename) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
  };

  /**
   * Escape HTML entities in a string.
   * @param {string} text
   * @returns {string}
   */
  window.kdEscapeHtml = function(text) {
    if (!text) return '';
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  };

  /**
   * Word-wrap text into lines that fit a given pixel width.
   * @param {string} text - Input text
   * @param {number} maxWidth - Maximum width in pixels
   * @param {number} charWidth - Approximate character width in pixels
   * @returns {string[]} Array of lines
   */
  window.kdWrapTextLines = function(text, maxWidth, charWidth) {
    if (!text) return [];
    charWidth = charWidth || 7;
    var maxChars = Math.floor(maxWidth / charWidth);
    if (maxChars < 10) maxChars = 10;

    var words = text.split(/\s+/);
    var lines = [];
    var currentLine = '';

    for (var i = 0; i < words.length; i++) {
      var word = words[i];
      if (currentLine.length === 0) {
        currentLine = word;
      } else if ((currentLine + ' ' + word).length <= maxChars) {
        currentLine += ' ' + word;
      } else {
        lines.push(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.length > 0) lines.push(currentLine);
    return lines;
  };

  /**
   * Create SVG <text> element with multiple <tspan> lines.
   * @param {string} ns - SVG namespace URI
   * @param {string[]} lines - Array of text lines
   * @param {number} x - X coordinate
   * @param {number} startY - Starting Y coordinate
   * @param {number} lineHeight - Line height in pixels
   * @param {Object} attrs - Additional attributes { fill, fontSize, fontWeight, fontFamily }
   * @returns {SVGTextElement}
   */
  window.kdCreateWrappedText = function(ns, lines, x, startY, lineHeight, attrs) {
    attrs = attrs || {};
    var textEl = document.createElementNS(ns, 'text');
    textEl.setAttribute('x', x);
    textEl.setAttribute('y', startY);
    textEl.setAttribute('fill', attrs.fill || '#1e293b');
    textEl.setAttribute('font-size', attrs.fontSize || '14');
    textEl.setAttribute('font-weight', attrs.fontWeight || '400');
    textEl.setAttribute('font-family', attrs.fontFamily || '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');

    for (var i = 0; i < lines.length; i++) {
      var tspan = document.createElementNS(ns, 'tspan');
      tspan.setAttribute('x', x);
      if (i > 0) tspan.setAttribute('dy', lineHeight);
      tspan.textContent = lines[i];
      textEl.appendChild(tspan);
    }
    return textEl;
  };

  // --------------------------------------------------------------------------
  // Insight editor functions
  // --------------------------------------------------------------------------

  /**
   * Toggle the insight editor for a section.
   * @param {string} sectionKey - Section key (e.g., 'importance')
   * @param {string} prefix - ID prefix (e.g., 'nps-')
   */
  window.kdToggleInsight = function(sectionKey, prefix) {
    prefix = prefix || '';
    var container = document.getElementById(prefix + 'kd-insight-container-' + sectionKey);
    var toggle = document.getElementById(prefix + 'kd-insight-toggle-' + sectionKey);
    if (!container) return;

    var isHidden = container.style.display === 'none' || container.style.display === '';
    container.style.display = isHidden ? 'block' : 'none';
    if (toggle) toggle.style.display = isHidden ? 'none' : '';

    // Focus the editor when opening
    if (isHidden) {
      var editor = container.querySelector('.kd-insight-editor');
      if (editor) editor.focus();
    }
  };

  /**
   * Sync insight text to a hidden data store (called on editor input).
   * @param {string} sectionKey
   * @param {string} prefix
   */
  window.kdSyncInsight = function(sectionKey, prefix) {
    // No-op during editing — text is already in the contentEditable div.
    // Actual persistence happens via kdSyncAllInsights() before save.
  };

  /**
   * Dismiss (hide and clear) the insight editor for a section.
   * @param {string} sectionKey
   * @param {string} prefix
   */
  window.kdDismissInsight = function(sectionKey, prefix) {
    prefix = prefix || '';
    var container = document.getElementById(prefix + 'kd-insight-container-' + sectionKey);
    var toggle = document.getElementById(prefix + 'kd-insight-toggle-' + sectionKey);
    if (container) {
      var editor = container.querySelector('.kd-insight-editor');
      if (editor) editor.textContent = '';
      container.style.display = 'none';
    }
    if (toggle) toggle.style.display = '';
  };

  /**
   * Sync all insight editors to hidden data stores (called before save).
   * Since insights are stored directly in contentEditable divs, the DOM
   * already holds the text. This function is a hook for any pre-save work.
   */
  window.kdSyncAllInsights = function() {
    // Insights live in contentEditable divs — they're serialized with the page.
    // Nothing extra needed.
  };

  /**
   * Hydrate insight editors from saved state on page load.
   * If an editor already has text (from a saved HTML file), show its container.
   */
  window.kdHydrateInsights = function() {
    document.querySelectorAll('.kd-insight-container').forEach(function(container) {
      var editor = container.querySelector('.kd-insight-editor');
      if (editor && editor.textContent.trim()) {
        container.style.display = 'block';
        // Hide the toggle button since the editor is visible
        var area = container.closest('.kd-insight-area');
        if (area) {
          var toggle = area.querySelector('.kd-insight-toggle');
          if (toggle) toggle.style.display = 'none';
        }
      }
    });
  };

})();
