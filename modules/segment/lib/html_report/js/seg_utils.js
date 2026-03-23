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
  // ==========================================================================
  // BAR CHART SHOW/HIDE TOGGLE
  // ==========================================================================

  /**
   * Toggle visibility of a bar group in an SVG chart.
   * Used for presentation mode — click a segment label to hide/show its bars.
   * Bars are identified by data-seg-bar-group attribute on the SVG rects.
   *
   * @param {HTMLElement} btn - The toggle button that was clicked
   * @param {string} groupId - The bar group identifier (e.g., "seg-1")
   */
  window.segToggleBarGroup = function(btn, groupId) {
    var chartWrapper = btn.closest('.seg-chart-wrapper') || btn.closest('.seg-section');
    if (!chartWrapper) return;

    var svg = chartWrapper.querySelector('svg');
    if (!svg) return;

    var bars = svg.querySelectorAll('[data-seg-bar-group="' + groupId + '"]');
    var labels = svg.querySelectorAll('[data-seg-label-group="' + groupId + '"]');

    var isHidden = btn.classList.contains('seg-bar-hidden');

    for (var i = 0; i < bars.length; i++) {
      bars[i].style.opacity = isHidden ? '' : '0.08';
      bars[i].style.transition = 'opacity 0.2s';
    }
    for (var j = 0; j < labels.length; j++) {
      labels[j].style.opacity = isHidden ? '' : '0.2';
      labels[j].style.transition = 'opacity 0.2s';
    }

    if (isHidden) {
      btn.classList.remove('seg-bar-hidden');
      btn.style.opacity = '';
      btn.style.textDecoration = '';
    } else {
      btn.classList.add('seg-bar-hidden');
      btn.style.opacity = '0.4';
      btn.style.textDecoration = 'line-through';
    }
  };

  // ==========================================================================
  // BAR X-BUTTON TOGGLE (inline on bars)
  // ==========================================================================

  /**
   * Toggle a bar's visibility via the inline X button on the SVG bar.
   * The X circle changes to a + to indicate it can be restored.
   * @param {SVGGElement} xBtn - The <g> element containing the X button
   * @param {string} groupId - The bar group identifier
   */
  window.segToggleBarByX = function(xBtn, groupId) {
    var svg = xBtn.closest('svg');
    if (!svg) return;

    var bars = svg.querySelectorAll('[data-seg-bar-group="' + groupId + '"]');
    var labels = svg.querySelectorAll('[data-seg-label-group="' + groupId + '"]');
    var isHidden = xBtn.classList.contains('seg-bar-x-hidden');

    for (var i = 0; i < bars.length; i++) {
      bars[i].style.opacity = isHidden ? '' : '0.06';
      bars[i].style.transition = 'opacity 0.2s';
    }
    for (var j = 0; j < labels.length; j++) {
      labels[j].style.opacity = isHidden ? '' : '0.15';
      labels[j].style.transition = 'opacity 0.2s';
    }

    // Toggle the X button appearance
    var circle = xBtn.querySelector('circle');
    var text = xBtn.querySelector('text');
    if (isHidden) {
      xBtn.classList.remove('seg-bar-x-hidden');
      if (circle) { circle.setAttribute('fill', '#f1f5f9'); circle.setAttribute('stroke', '#cbd5e1'); }
      if (text) { text.textContent = '\u00D7'; text.setAttribute('fill', '#94a3b8'); }
    } else {
      xBtn.classList.add('seg-bar-x-hidden');
      if (circle) { var b = getComputedStyle(document.documentElement).getPropertyValue('--seg-brand').trim() || '#323367'; circle.setAttribute('fill', b); circle.setAttribute('stroke', b); }
      if (text) { text.textContent = '+'; text.setAttribute('fill', '#ffffff'); }
    }
  };

  /**
   * Show all bars in the nearest importance chart.
   * @param {HTMLElement} btn - The "Show all" button
   */
  window.segShowAllBars = function(btn) {
    var wrapper = btn.closest('.seg-chart-wrapper') || btn.closest('.seg-section');
    if (!wrapper) return;
    var svg = wrapper.querySelector('svg');
    if (!svg) return;

    var xBtns = svg.querySelectorAll('.seg-bar-x-btn.seg-bar-x-hidden');
    for (var i = 0; i < xBtns.length; i++) {
      var gid = xBtns[i].getAttribute('data-seg-target-group');
      if (gid) segToggleBarByX(xBtns[i], gid);
    }
  };

  // ==========================================================================
  // GOLDEN QUESTIONS TOGGLE
  // ==========================================================================

  /**
   * Handle golden question checkbox toggle.
   * Recalculates accuracy based on which questions are checked,
   * using the incremental accuracy data embedded in the page.
   * @param {HTMLInputElement} checkbox - The checkbox that changed
   */
  window.segToggleGoldenQuestion = function(checkbox) {
    var row = checkbox.closest('.seg-gq-row');
    if (!row) return;

    // Dim the row when unchecked
    if (checkbox.checked) {
      row.style.opacity = '1';
      row.style.textDecoration = '';
    } else {
      row.style.opacity = '0.35';
      row.style.textDecoration = 'line-through';
    }
    row.style.transition = 'opacity 0.2s';

    // Count checked questions
    var table = document.getElementById('seg-gq-table');
    if (!table) return;

    var checkboxes = table.querySelectorAll('.seg-gq-checkbox');
    var checkedCount = 0;
    var highestCheckedRank = 0;
    for (var i = 0; i < checkboxes.length; i++) {
      if (checkboxes[i].checked) {
        checkedCount++;
        var r = checkboxes[i].closest('.seg-gq-row');
        var rank = parseInt(r.getAttribute('data-gq-rank'), 10);
        if (rank > highestCheckedRank) highestCheckedRank = rank;
      }
    }

    // Update count display
    var countEl = document.getElementById('seg-gq-count');
    if (countEl) countEl.textContent = checkedCount;

    // Estimate accuracy from incremental data
    var dataEl = document.getElementById('seg-gq-incremental-data');
    var accEl = document.getElementById('seg-gq-accuracy-val');
    if (dataEl && accEl) {
      try {
        var incData = JSON.parse(dataEl.textContent);
        var estAccuracy;
        if (checkedCount === 0) {
          estAccuracy = 0;
        } else if (highestCheckedRank <= incData.length) {
          // Use highest checked rank as proxy — accuracy with top-N where N = highest checked
          // Then subtract approximate contribution of unchecked questions below it
          estAccuracy = incData[highestCheckedRank - 1] * 100;
          var uncheckedBelow = highestCheckedRank - checkedCount;
          // Each unchecked question below reduces accuracy by its marginal contribution
          if (uncheckedBelow > 0 && highestCheckedRank > 1) {
            var avgMarginal = (incData[highestCheckedRank - 1] - incData[0]) / (highestCheckedRank - 1);
            estAccuracy -= uncheckedBelow * avgMarginal * 100;
          }
        } else {
          estAccuracy = incData[incData.length - 1] * 100;
        }
        estAccuracy = Math.max(0, Math.min(100, estAccuracy));
        accEl.textContent = estAccuracy.toFixed(1) + '%';
        // Update colour
        if (estAccuracy >= 80) accEl.style.color = '#22c55e';
        else if (estAccuracy >= 60) accEl.style.color = '#f59e0b';
        else accEl.style.color = '#ef4444';
      } catch(e) { /* silent */ }
    }
  };

  // ==========================================================================
  // SLIDES FUNCTIONS
  // ==========================================================================

  /**
   * Add a new empty slide to the slides container.
   */
  window.segAddSlide = function() {
    var container = document.getElementById('seg-slides-container');
    if (!container) return;

    // Remove empty state
    var empty = document.getElementById('seg-slides-empty');
    if (empty) empty.remove();

    var card = document.createElement('div');
    card.className = 'seg-slide-card';
    card.style.cssText = 'background:#fff; border:1px solid #e2e8f0; border-radius:8px; padding:20px; margin-bottom:16px; position:relative;';
    card.innerHTML = '<div style="position:absolute;top:8px;right:12px;display:flex;gap:6px;">' +
      '<button style="background:none;border:1px solid #d1d5db;border-radius:4px;color:#64748b;font-size:12px;cursor:pointer;padding:2px 8px;" onclick="segPinSlide(this)" title="Pin to Views">\uD83D\uDCCC</button>' +
      '<button style="background:none;border:none;color:#94a3b8;font-size:18px;cursor:pointer;padding:4px;" onclick="this.closest(\'.seg-slide-card\').remove();segUpdateSlideCount();">\u00D7</button></div>' +
      '<div class="seg-slide-title" contenteditable="true" style="font-size:16px;font-weight:600;color:var(--seg-brand);margin-bottom:8px;border-bottom:2px solid var(--seg-brand);padding-bottom:6px;outline:none;" data-placeholder="Slide title..."></div>' +
      '<div class="seg-slide-content" contenteditable="true" style="font-size:13px;color:#334155;line-height:1.6;min-height:60px;outline:none;border:1px dashed transparent;padding:8px;border-radius:4px;" data-placeholder="Add slide content..."></div>' +
      '<div style="margin-top:8px;text-align:right;"><label style="font-size:11px;color:#64748b;cursor:pointer;padding:4px 10px;border:1px solid #d1d5db;border-radius:4px;display:inline-block;">\uD83D\uDCF7 Add Image<input type="file" accept="image/*" style="display:none;" onchange="segSlideImageUpload(this)"></label></div>';

    container.appendChild(card);
    segUpdateSlideCount();
    card.querySelector('.seg-slide-title').focus();
  };

  /**
   * Pin a slide to Pinned Views.
   * Captures title, content, and image as an HTML snapshot.
   * @param {HTMLElement} btn - The pin button inside a slide card
   */
  window.segPinSlide = function(btn) {
    var card = btn.closest('.seg-slide-card');
    if (!card) return;

    var titleEl = card.querySelector('.seg-slide-title');
    var contentEl = card.querySelector('.seg-slide-content');
    var imgEl = card.querySelector('.seg-slide-image img');

    var title = titleEl ? titleEl.textContent.trim() : 'Slide';
    var content = contentEl ? contentEl.innerHTML : '';
    var imgHtml = imgEl ? '<div style="margin:8px 0;">' + imgEl.outerHTML + '</div>' : '';

    // Build composite HTML for the pin
    var slideHtml = '<div style="padding:12px;">' +
      '<div style="font-size:15px;font-weight:600;color:var(--seg-brand);border-bottom:2px solid var(--seg-brand);padding-bottom:6px;margin-bottom:8px;">' + segEscapeHtml(title) + '</div>' +
      '<div style="font-size:13px;color:#334155;line-height:1.6;">' + content + '</div>' +
      imgHtml +
      '</div>';

    // Use the public pinned views API
    if (typeof window.segPinCustomContent === 'function') {
      window.segPinCustomContent('Slide: ' + title, slideHtml);

      // Brief feedback
      btn.textContent = '\u2713';
      btn.style.color = '#22c55e';
      setTimeout(function() { btn.textContent = '\uD83D\uDCCC'; btn.style.color = '#64748b'; }, 1500);
    }
  };

  /**
   * Handle image upload for a slide.
   * Reads the file as base64 and inserts an <img> into the slide card.
   * @param {HTMLInputElement} input - The file input element
   */
  window.segSlideImageUpload = function(input) {
    if (!input.files || !input.files[0]) return;
    var file = input.files[0];
    if (!file.type.startsWith('image/')) return;

    var reader = new FileReader();
    reader.onload = function(e) {
      var card = input.closest('.seg-slide-card');
      if (!card) return;

      // Remove existing image if any
      var existing = card.querySelector('.seg-slide-image');
      if (existing) existing.remove();

      var imgDiv = document.createElement('div');
      imgDiv.className = 'seg-slide-image';
      imgDiv.style.cssText = 'margin:12px 0; position:relative;';
      imgDiv.innerHTML = '<img src="' + e.target.result + '" style="max-width:100%;border-radius:6px;border:1px solid #e2e8f0;">' +
        '<button style="position:absolute;top:4px;right:4px;background:rgba(0,0,0,0.5);color:#fff;border:none;border-radius:50%;width:24px;height:24px;cursor:pointer;font-size:14px;line-height:1;" onclick="this.parentElement.remove();">\u00D7</button>';

      var content = card.querySelector('.seg-slide-content');
      if (content) {
        content.parentNode.insertBefore(imgDiv, content.nextSibling);
      } else {
        card.appendChild(imgDiv);
      }
    };
    reader.readAsDataURL(file);
    input.value = '';
  };

  /**
   * Update slide count badge.
   */
  window.segUpdateSlideCount = function() {
    var container = document.getElementById('seg-slides-container');
    var badge = document.getElementById('seg-slide-count-badge');
    if (container && badge) {
      var count = container.querySelectorAll('.seg-slide-card').length;
      badge.textContent = count;
      badge.style.display = count > 0 ? 'inline' : 'none';
    }
  };

  /**
   * Export all slides as individual PNGs.
   * Uses the slide export infrastructure.
   */
  window.segExportAllSlidesPNG = function() {
    var cards = document.querySelectorAll('#seg-slides-container .seg-slide-card');
    if (cards.length === 0) {
      alert('No slides to export. Add at least one slide first.');
      return;
    }
    // Use html2canvas approach or simple DOM serialisation
    cards.forEach(function(card, i) {
      if (typeof window.segExportElementAsPNG === 'function') {
        window.segExportElementAsPNG(card, 'slide_' + (i + 1) + '.png');
      }
    });
  };

  // ==========================================================================
  // HELP OVERLAY
  // ==========================================================================

  /**
   * Show/hide help overlay with navigation guide.
   */
  window.segToggleHelp = function() {
    var overlay = document.getElementById('seg-help-overlay');
    if (!overlay) return;
    var isVisible = overlay.style.display !== 'none';
    overlay.style.display = isVisible ? 'none' : 'flex';
  };

  // ==========================================================================
  // Table CSV/Excel export
  // ==========================================================================

  /**
   * Export the nearest <table> in the same wrapper as the clicked button to CSV.
   * CSV is wrapped in a UTF-8 BOM Blob so Excel opens it correctly.
   * @param {HTMLElement} btn - The button that was clicked
   * @param {string} sectionKey - Used to build the filename
   */
  window.segExportTableCSV = function(btn, sectionKey) {
    var wrapper = btn.closest('.seg-table-wrapper');
    if (!wrapper) return;
    var table = wrapper.querySelector('table');
    if (!table) return;

    var rows = table.querySelectorAll('tr');
    var csvRows = [];

    for (var i = 0; i < rows.length; i++) {
      var cells = rows[i].querySelectorAll('th, td');
      var csvCells = [];
      for (var j = 0; j < cells.length; j++) {
        var text = (cells[j].textContent || '').trim();
        // Escape quotes and wrap in quotes if contains comma/quote/newline
        if (text.indexOf('"') !== -1 || text.indexOf(',') !== -1 || text.indexOf('\n') !== -1) {
          text = '"' + text.replace(/"/g, '""') + '"';
        }
        csvCells.push(text);
      }
      csvRows.push(csvCells.join(','));
    }

    var csv = csvRows.join('\n');
    // UTF-8 BOM so Excel opens with correct encoding
    var bom = '\uFEFF';
    var blob = new Blob([bom + csv], { type: 'text/csv;charset=utf-8;' });

    var meta = document.querySelector('meta[name="turas-source-filename"]');
    var prefix = meta ? meta.getAttribute('content').replace(/\.[^.]+$/, '') : 'Segment';
    var filename = prefix + '_' + sectionKey + '.csv';

    window.segDownloadBlob(blob, filename);

    // Brief visual feedback
    var orig = btn.innerHTML;
    btn.innerHTML = '&#x2705; Saved';
    setTimeout(function() { btn.innerHTML = orig; }, 1500);
  };

  /**
   * Alias for toggleHelpOverlay used by the tab bar ? button.
   */
  window.toggleHelpOverlay = window.toggleHelpOverlay || window.segToggleHelp;

})();
