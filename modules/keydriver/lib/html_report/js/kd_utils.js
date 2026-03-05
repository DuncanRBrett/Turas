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

})();
