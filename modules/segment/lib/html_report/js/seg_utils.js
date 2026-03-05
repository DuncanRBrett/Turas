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
})();
