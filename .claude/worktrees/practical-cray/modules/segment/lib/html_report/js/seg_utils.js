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
   * Wrap text into lines at word boundaries.
   * @param {string} text - Text to wrap
   * @param {number} maxChars - Maximum characters per line
   * @returns {string[]} Array of line strings
   */
  window.segWrapTextLines = function(text, maxChars) {
    if (!text) return [''];
    maxChars = maxChars || 40;
    var words = String(text).split(/\s+/);
    var lines = [];
    var current = '';
    for (var i = 0; i < words.length; i++) {
      var test = current ? current + ' ' + words[i] : words[i];
      if (test.length > maxChars && current) {
        lines.push(current);
        current = words[i];
      } else {
        current = test;
      }
    }
    if (current) lines.push(current);
    return lines.length ? lines : [''];
  };

  /**
   * Create wrapped SVG text with tspan elements.
   * @param {SVGElement} parent - SVG parent to append to
   * @param {string} text - Text content
   * @param {number} x - X position
   * @param {number} y - Starting Y position
   * @param {number} maxChars - Max chars per line
   * @param {Object} attrs - SVG attributes for each tspan
   * @returns {number} Total height used
   */
  window.segCreateWrappedText = function(parent, text, x, y, maxChars, attrs) {
    var NS = 'http://www.w3.org/2000/svg';
    var lines = window.segWrapTextLines(text, maxChars);
    var lineHeight = parseInt((attrs && attrs['font-size']) || '14', 10) * 1.3;
    var textEl = document.createElementNS(NS, 'text');
    if (attrs) {
      for (var key in attrs) {
        if (attrs.hasOwnProperty(key)) {
          textEl.setAttribute(key, attrs[key]);
        }
      }
    }
    for (var i = 0; i < lines.length; i++) {
      var tspan = document.createElementNS(NS, 'tspan');
      tspan.setAttribute('x', x);
      tspan.setAttribute('y', y + i * lineHeight);
      tspan.textContent = lines[i];
      textEl.appendChild(tspan);
    }
    parent.appendChild(textEl);
    return lines.length * lineHeight;
  };
})();
