/**
 * seg_utils.js - Utility functions for Turas Segment HTML reports
 * Provides common helpers used across other segment JS modules.
 * All functions exposed on window with 'seg' prefix.
 */
(function() {
  'use strict';

  /**
   * Download a Blob as a file.
   * Creates a temporary anchor element, triggers the download, then cleans up.
   * @param {Blob} blob - The blob to download
   * @param {string} filename - The suggested filename
   */
  window.segDownloadBlob = function(blob, filename) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    setTimeout(function() {
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }, 100);
  };

  /**
   * Escape HTML special characters to prevent XSS in dynamic content.
   * @param {string} text - Raw text to escape
   * @returns {string} HTML-safe string
   */
  window.segEscapeHtml = function(text) {
    if (typeof text !== 'string') return '';
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  };

  /**
   * Word-wrap text into lines that fit a given pixel width.
   * @param {string} text - Input text
   * @param {number} maxWidth - Maximum width in pixels
   * @param {number} charWidth - Approximate character width in pixels (default 7)
   * @returns {string[]} Array of lines
   */
  window.segWrapTextLines = function(text, maxWidth, charWidth) {
    if (!text) return [];
    charWidth = charWidth || 7;
    var maxChars = Math.floor(maxWidth / charWidth);
    if (maxChars < 10) maxChars = 10;

    var words = String(text).split(/\s+/);
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
  window.segCreateWrappedText = function(ns, lines, x, startY, lineHeight, attrs) {
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

  // ==========================================================================
  // Insight editor functions
  // ==========================================================================

  /**
   * Toggle the insight editor for a section.
   * @param {string} sectionKey - Section key (e.g., 'importance')
   * @param {string} prefix - ID prefix (optional)
   */
  window.segToggleInsight = function(sectionKey, prefix) {
    prefix = prefix || '';
    var container = document.getElementById(prefix + 'seg-insight-container-' + sectionKey);
    var toggle = document.getElementById(prefix + 'seg-insight-toggle-' + sectionKey);
    if (!container) return;

    var isHidden = container.style.display === 'none' || container.style.display === '';
    container.style.display = isHidden ? 'block' : 'none';
    if (toggle) toggle.style.display = isHidden ? 'none' : '';

    // Focus the editor when opening
    if (isHidden) {
      var editor = container.querySelector('.seg-insight-editor');
      if (editor) editor.focus();
    }
  };

  /**
   * Sync insight text (called on editor input).
   * No-op during editing — text lives in the contentEditable div.
   * Actual persistence happens when the page is saved.
   * @param {string} sectionKey
   * @param {string} prefix
   */
  window.segSyncInsight = function(sectionKey, prefix) {
    // No-op — text is already in the contentEditable div.
  };

  /**
   * Dismiss (hide and clear) the insight editor for a section.
   * @param {string} sectionKey
   * @param {string} prefix
   */
  window.segDismissInsight = function(sectionKey, prefix) {
    prefix = prefix || '';
    var container = document.getElementById(prefix + 'seg-insight-container-' + sectionKey);
    var toggle = document.getElementById(prefix + 'seg-insight-toggle-' + sectionKey);
    if (container) {
      var editor = container.querySelector('.seg-insight-editor');
      if (editor) editor.textContent = '';
      container.style.display = 'none';
    }
    if (toggle) toggle.style.display = '';
  };

  /**
   * Sync all insight editors before save.
   * Insights live in contentEditable divs — they're serialized with the page.
   */
  window.segSyncAllInsights = function() {
    // Insights live in contentEditable divs — serialized with the page.
  };

  /**
   * Hydrate insight editors from saved state on page load.
   * If an editor already has text (from a saved HTML file), show its container.
   */
  window.segHydrateInsights = function() {
    var containers = document.querySelectorAll('.seg-insight-container');
    for (var i = 0; i < containers.length; i++) {
      var container = containers[i];
      var editor = container.querySelector('.seg-insight-editor');
      if (editor && editor.textContent.trim()) {
        container.style.display = 'block';
        // Hide the toggle button since the editor is visible
        var area = container.closest('.seg-insight-area');
        if (area) {
          var toggle = area.querySelector('.seg-insight-toggle');
          if (toggle) toggle.style.display = 'none';
        }
      }
    }
  };
})();
