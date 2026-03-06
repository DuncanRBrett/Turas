/* ==============================================================================
 * SEGMENT HTML REPORT - PINNED VIEWS
 * ==============================================================================
 * Pin sections to a dedicated Pinned Views panel. Each pin captures:
 * section title, panel label, insight text, chart SVG, table HTML.
 * Supports section headers/dividers between pins.
 * Pins can be exported as PNG slides or printed to PDF.
 * All functions prefixed seg to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // In-memory array of pinned views (pins and section dividers)
  var segPinnedViews = [];

  /**
   * Get the current pinned views array.
   * @returns {Array}
   */
  window.segGetPinnedViews = function() {
    return segPinnedViews;
  };

  /**
   * Count only actual pins (not section dividers).
   * @returns {number}
   */
  function countPins() {
    var count = 0;
    for (var i = 0; i < segPinnedViews.length; i++) {
      if (segPinnedViews[i].type !== 'section') count++;
    }
    return count;
  }

  /**
   * Pin a section from the report.
   * @param {string} sectionKey - Section key (e.g., 'overview', 'validation')
   * @param {string} prefix - ID prefix (optional, default '')
   */
  window.segPinSection = function(sectionKey, prefix) {
    prefix = prefix || '';
    var content = segCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    // Check for duplicate (toggle behaviour)
    for (var i = 0; i < segPinnedViews.length; i++) {
      if (segPinnedViews[i].type !== 'section' &&
          segPinnedViews[i].sectionKey === sectionKey &&
          segPinnedViews[i].prefix === prefix) {
        segPinnedViews.splice(i, 1);
        segRenderPinnedCards();
        segUpdatePinBadge();
        segUpdatePinButtons();
        return;
      }
    }

    var pin = {
      type: 'pin',
      id: 'pin-' + Date.now() + '-' + Math.random().toString(36).substr(2, 6),
      sectionKey: sectionKey,
      prefix: prefix,
      panelLabel: content.panelLabel,
      sectionTitle: content.sectionTitle,
      insightText: content.insightText,
      chartSvg: content.chartSvg,
      tableHtml: content.tableHtml,
      timestamp: new Date().toISOString(),
      methodText: content.methodText,
      sampleN: content.sampleN
    };

    segPinnedViews.push(pin);
    segRenderPinnedCards();
    segUpdatePinBadge();
    segUpdatePinButtons();
  };

  /**
   * Pin a specific component (chart or table) from a section.
   * @param {string} sectionKey - Section key (e.g., 'overview')
   * @param {string} component - 'chart' or 'table'
   * @param {string} prefix - ID prefix (optional, default '')
   */
  window.segPinComponent = function(sectionKey, component, prefix) {
    prefix = prefix || '';

    // Check for duplicate (toggle behaviour) — match by sectionKey + prefix + component
    for (var i = 0; i < segPinnedViews.length; i++) {
      if (segPinnedViews[i].type !== 'section' &&
          segPinnedViews[i].sectionKey === sectionKey &&
          segPinnedViews[i].prefix === prefix &&
          segPinnedViews[i].component === component) {
        segPinnedViews.splice(i, 1);
        segRenderPinnedCards();
        segUpdatePinBadge();
        segUpdatePinButtons();
        return;
      }
    }

    // Build partial capture
    var content = segCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    var pin = {
      type: 'pin',
      id: 'pin-' + Date.now() + '-' + Math.random().toString(36).substr(2, 6),
      sectionKey: sectionKey,
      prefix: prefix,
      component: component,
      panelLabel: content.panelLabel,
      sectionTitle: content.sectionTitle + ' \u2014 ' + (component === 'chart' ? 'Chart' : 'Table'),
      insightText: content.insightText,
      chartSvg: component === 'chart' ? content.chartSvg : '',
      tableHtml: component === 'table' ? content.tableHtml : '',
      timestamp: new Date().toISOString(),
      methodText: content.methodText,
      sampleN: content.sampleN
    };

    segPinnedViews.push(pin);
    segRenderPinnedCards();
    segUpdatePinBadge();
    segUpdatePinButtons();
  };

  /**
   * Add a section header/divider.
   * @param {string} title - Optional title (default "New Section")
   */
  window.segAddSection = function(title) {
    title = title || 'New Section';
    segPinnedViews.push({
      type: 'section',
      title: title,
      id: 'sec-' + Date.now() + '-' + Math.random().toString(36).substr(2, 5)
    });
    segSavePinnedData();
    segRenderPinnedCards();
    segUpdatePinBadge();
  };

  /**
   * Update a section header title.
   * @param {number} idx - Index in segPinnedViews
   * @param {string} newTitle
   */
  window.segUpdateSectionTitle = function(idx, newTitle) {
    if (idx >= 0 && idx < segPinnedViews.length && segPinnedViews[idx].type === 'section') {
      segPinnedViews[idx].title = (newTitle || '').trim() || 'Untitled Section';
      segSavePinnedData();
    }
  };

  /**
   * Capture content from a section for pinning.
   * Segment sections are identified by data-seg-section attribute.
   * @param {string} sectionKey
   * @param {string} prefix
   * @returns {Object|null}
   */
  function segCaptureSectionContent(sectionKey, prefix) {
    // Segment uses data-seg-section attribute for section identification
    var section = document.querySelector('[data-seg-section="' + sectionKey + '"]');
    if (!section) return null;

    // Panel label — get from the report header title
    var panelLabel = '';
    var headerTitle = document.querySelector('.seg-header-title');
    if (headerTitle) {
      panelLabel = headerTitle.textContent.trim();
    }

    // Section title
    var titleEl = section.querySelector('.seg-section-title');
    var sectionTitle = titleEl ? titleEl.textContent.trim() : sectionKey;

    // Insight text — segment uses seg-insight-container-{sectionKey} pattern
    var insightText = '';
    var insightContainer = document.getElementById('seg-insight-container-' + sectionKey);
    if (insightContainer) {
      var editor = insightContainer.querySelector('.seg-insight-editor');
      if (editor && editor.textContent.trim()) {
        insightText = editor.textContent.trim();
      }
    }

    // Chart SVG — look inside chart wrapper, fall back to any SVG in the section
    var chartSvg = '';
    var svgEl = section.querySelector('.seg-chart-wrapper svg, svg');
    if (svgEl) {
      // Clone to avoid modifying the original
      var svgClone = svgEl.cloneNode(true);
      chartSvg = svgClone.outerHTML;
    }

    // Table HTML — capture first visible table
    var tableHtml = '';
    var tableEl = section.querySelector('table.seg-table, table');
    if (tableEl) {
      // Clone visible rows only (respect any filtering)
      var tableClone = tableEl.cloneNode(true);
      var hiddenRows = tableClone.querySelectorAll('tr[style*="display: none"], tr[style*="display:none"]');
      hiddenRows.forEach(function(row) { row.remove(); });
      tableHtml = tableClone.outerHTML;
    }

    // For exec-summary, capture key content blocks
    if (sectionKey === 'exec-summary' && !tableHtml && !chartSvg) {
      var execContent = '';
      var summaryBlocks = section.querySelectorAll('.seg-exec-block, .seg-finding-box, .seg-key-insights-heading');
      summaryBlocks.forEach(function(el) {
        execContent += el.outerHTML;
      });
      if (execContent) {
        tableHtml = '<div class="seg-pinned-exec-content">' + execContent + '</div>';
      }
    }

    // For cards section, capture segment profile cards
    if (sectionKey === 'cards' && !tableHtml && !chartSvg) {
      var cardGrid = section.querySelector('.seg-cards-grid, .seg-profile-cards');
      if (cardGrid) {
        tableHtml = '<div class="seg-pinned-exec-content">' + cardGrid.outerHTML + '</div>';
      }
    }

    // Metadata from header badges
    var methodText = '';
    var sampleN = '';
    var badges = document.querySelectorAll('.seg-header-badge');
    badges.forEach(function(b) {
      var t = b.textContent.trim();
      if (t.match(/k-means|hierarchical|pam|cluster/i)) methodText = t;
      else if (t.match(/^n\s*=/i) || t.match(/n\s*&nbsp;\s*=\s*/i)) sampleN = t;
    });

    return {
      panelLabel: panelLabel,
      sectionTitle: sectionTitle,
      insightText: insightText,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      methodText: methodText,
      sampleN: sampleN
    };
  }

  /**
   * Render pinned cards into the pinned views container.
   */
  window.segRenderPinnedCards = function() {
    var container = document.getElementById('seg-pinned-cards-container');
    if (!container) return;

    var emptyState = document.getElementById('seg-pinned-empty');
    var pinCount = countPins();

    if (segPinnedViews.length === 0) {
      container.innerHTML = '';
      if (emptyState) emptyState.style.display = 'block';
      return;
    }

    if (emptyState) emptyState.style.display = 'none';
    var total = segPinnedViews.length;

    // Build DOM directly for section headers (contentEditable)
    container.innerHTML = '';

    segPinnedViews.forEach(function(item, idx) {
      // --- Section divider ---
      if (item.type === 'section') {
        var divider = document.createElement('div');
        divider.className = 'seg-section-divider';
        divider.setAttribute('data-idx', idx);

        var titleEl = document.createElement('div');
        titleEl.className = 'seg-section-divider-title';
        titleEl.contentEditable = 'true';
        titleEl.textContent = item.title;
        titleEl.onblur = function() { segUpdateSectionTitle(idx, this.textContent); };
        divider.appendChild(titleEl);

        var sActions = document.createElement('div');
        sActions.className = 'seg-section-divider-actions';
        if (idx > 0) {
          var sUp = document.createElement('button');
          sUp.className = 'seg-pinned-action-btn';
          sUp.textContent = '\u25B2'; sUp.title = 'Move up';
          sUp.onclick = function() { segMovePinned(item.id, -1); };
          sActions.appendChild(sUp);
        }
        if (idx < total - 1) {
          var sDown = document.createElement('button');
          sDown.className = 'seg-pinned-action-btn';
          sDown.textContent = '\u25BC'; sDown.title = 'Move down';
          sDown.onclick = function() { segMovePinned(item.id, 1); };
          sActions.appendChild(sDown);
        }
        var sDel = document.createElement('button');
        sDel.className = 'seg-pinned-action-btn seg-pinned-remove-btn';
        sDel.textContent = '\u2715'; sDel.title = 'Remove section';
        sDel.onclick = function() { segRemovePinned(item.id); };
        sActions.appendChild(sDel);
        divider.appendChild(sActions);
        container.appendChild(divider);
        return;
      }

      // --- Pin card ---
      var pin = item;
      var card = document.createElement('div');
      card.className = 'seg-pinned-card';
      card.setAttribute('data-pin-id', pin.id);

      var labelTag = pin.panelLabel
        ? '<span class="seg-pinned-card-label">' + segEscapeHtml(pin.panelLabel) + '</span>'
        : '';

      var insightBlock = pin.insightText
        ? '<div class="seg-pinned-card-insight">' + segEscapeHtml(pin.insightText) + '</div>'
        : '';

      var chartBlock = pin.chartSvg
        ? '<div class="seg-pinned-card-chart">' + pin.chartSvg + '</div>'
        : '';

      var tableBlock = pin.tableHtml
        ? '<div class="seg-pinned-card-table">' + pin.tableHtml + '</div>'
        : '';

      var actionsHtml = '';
      if (idx > 0) {
        actionsHtml += '<button class="seg-pinned-action-btn" onclick="segMovePinned(\'' + pin.id + '\', -1)" title="Move up">\u25B2</button>';
      }
      if (idx < total - 1) {
        actionsHtml += '<button class="seg-pinned-action-btn" onclick="segMovePinned(\'' + pin.id + '\', 1)" title="Move down">\u25BC</button>';
      }
      actionsHtml += '<button class="seg-pinned-action-btn seg-pinned-export-btn" onclick="segExportPinnedCardPNG(\'' + pin.id + '\')" title="Export as PNG">\uD83D\uDCE5</button>';
      actionsHtml += '<button class="seg-pinned-action-btn seg-pinned-remove-btn" onclick="segRemovePinned(\'' + pin.id + '\')" title="Remove pin">\u2715</button>';

      card.innerHTML = '<div class="seg-pinned-card-header">'
        + '<div class="seg-pinned-card-title">'
        + labelTag
        + '<span class="seg-pinned-card-section">' + segEscapeHtml(pin.sectionTitle) + '</span>'
        + '</div>'
        + '<div class="seg-pinned-card-actions">' + actionsHtml + '</div>'
        + '</div>'
        + insightBlock
        + chartBlock
        + tableBlock;

      container.appendChild(card);
    });
  };

  /**
   * Remove a pinned view or section by ID.
   * @param {string} pinId
   */
  window.segRemovePinned = function(pinId) {
    segPinnedViews = segPinnedViews.filter(function(p) { return p.id !== pinId; });
    segRenderPinnedCards();
    segUpdatePinBadge();
    segUpdatePinButtons();
  };

  /**
   * Move a pinned view up or down.
   * @param {string} pinId
   * @param {number} direction - -1 for up, +1 for down
   */
  window.segMovePinned = function(pinId, direction) {
    var idx = -1;
    for (var i = 0; i < segPinnedViews.length; i++) {
      if (segPinnedViews[i].id === pinId) { idx = i; break; }
    }
    if (idx < 0) return;

    var newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= segPinnedViews.length) return;

    var temp = segPinnedViews[idx];
    segPinnedViews[idx] = segPinnedViews[newIdx];
    segPinnedViews[newIdx] = temp;

    segRenderPinnedCards();
  };

  /**
   * Clear all pinned views.
   */
  window.segClearAllPinned = function() {
    segPinnedViews = [];
    segRenderPinnedCards();
    segUpdatePinBadge();
    segUpdatePinButtons();
  };

  /**
   * Update the pin count badge in the tab bar.
   * Only counts actual pins, not section dividers.
   */
  window.segUpdatePinBadge = function() {
    var badge = document.getElementById('seg-pin-count-badge');
    var n = countPins();
    if (badge) {
      badge.textContent = n;
      badge.style.display = n > 0 ? 'inline-flex' : 'none';
    }
  };

  /**
   * Update pin button states (active/inactive) based on pinned views.
   */
  function segUpdatePinButtons() {
    // Section-level pin buttons
    document.querySelectorAll('.seg-pin-btn').forEach(function(btn) {
      var sectionKey = btn.getAttribute('data-seg-pin-section');
      var prefix = btn.getAttribute('data-seg-pin-prefix') || '';
      var isPinned = false;
      for (var i = 0; i < segPinnedViews.length; i++) {
        if (segPinnedViews[i].type !== 'section' &&
            segPinnedViews[i].sectionKey === sectionKey &&
            segPinnedViews[i].prefix === prefix &&
            !segPinnedViews[i].component) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle('seg-pin-btn-active', isPinned);
      btn.title = isPinned ? 'Unpin this section' : 'Pin this section';
    });

    // Component-level pin buttons (chart/table)
    document.querySelectorAll('.seg-component-pin').forEach(function(btn) {
      var sectionKey = btn.getAttribute('data-seg-pin-section');
      var prefix = btn.getAttribute('data-seg-pin-prefix') || '';
      var component = btn.getAttribute('data-seg-pin-component') || '';
      var isPinned = false;
      for (var i = 0; i < segPinnedViews.length; i++) {
        if (segPinnedViews[i].type !== 'section' &&
            segPinnedViews[i].sectionKey === sectionKey &&
            segPinnedViews[i].prefix === prefix &&
            segPinnedViews[i].component === component) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle('seg-pin-btn-active', isPinned);
    });
  }

  /**
   * Export all pinned views as PNG slides.
   */
  window.segExportAllPinnedPNG = function() {
    var pins = segPinnedViews.filter(function(p) { return p.type !== 'section'; });
    if (pins.length === 0) return;
    pins.forEach(function(pin, idx) {
      setTimeout(function() {
        segExportPinnedCardPNG(pin.id);
      }, idx * 500);
    });
  };

  /**
   * Print pinned views to PDF via window.print() overlay.
   * Builds a temporary print layout: one pin per page, section dividers as
   * heading strips. User saves to PDF from the print dialog.
   */
  window.segPrintPinnedViews = function() {
    var pinCount = countPins();
    if (pinCount === 0) return;

    // Create print overlay
    var overlay = document.createElement('div');
    overlay.id = 'seg-pinned-print-overlay';
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:white;overflow:auto;';

    // Print styles
    var printStyle = document.createElement('style');
    printStyle.id = 'seg-pinned-print-style';
    printStyle.textContent =
      '@page { size: A4 landscape; margin: 10mm 12mm; } ' +
      '@media print { ' +
      'body > *:not(#seg-pinned-print-overlay) { display: none !important; } ' +
      '#seg-pinned-print-overlay { position: static !important; overflow: visible !important; } ' +
      '.seg-print-page { page-break-after: always; padding: 12px 0; box-sizing: border-box; } ' +
      '.seg-print-page:last-child { page-break-after: auto; } ' +
      '.seg-print-header { margin-bottom: 10px; } ' +
      '.seg-print-panel-label { font-size: 13px; font-weight: 700; color: #323367; text-transform: uppercase; letter-spacing: 0.3px; } ' +
      '.seg-print-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 2px 0; } ' +
      '.seg-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid #323367; ' +
      '  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; ' +
      '  color: #1a2744; line-height: 1.5; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.seg-print-chart { margin-bottom: 12px; } ' +
      '.seg-print-chart svg { width: 100%; height: auto; } ' +
      '.seg-print-table { overflow: visible; } ' +
      '.seg-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } ' +
      '.seg-print-table th, .seg-print-table td { padding: 4px 8px; border: 1px solid #ddd; text-align: left; word-wrap: break-word; } ' +
      '.seg-print-table th { background: #f1f5f9; font-weight: 600; font-size: 12px; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.seg-print-page-num { text-align: right; font-size: 9px; color: #94a3b8; margin-top: 4px; } ' +
      '.seg-print-project-strip { padding: 0 0 8px 0; margin-bottom: 12px; border-bottom: 2px solid #323367; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.seg-print-section-strip { padding: 16px 0 8px; margin: 8px 0; border-bottom: 2px solid #323367; font-size: 16px; font-weight: 600; color: #323367; } ' +
      '} ' +
      // Screen preview
      '#seg-pinned-print-overlay { padding: 32px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; } ' +
      '.seg-print-page { border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; margin-bottom: 16px; background: white; } ' +
      '.seg-print-close-btn { position: fixed; top: 16px; right: 16px; z-index: 100000; padding: 8px 20px; background: #323367; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }';
    document.head.appendChild(printStyle);

    // Close button (visible on screen, hidden in print)
    var closeBtn = document.createElement('button');
    closeBtn.className = 'seg-print-close-btn';
    closeBtn.textContent = 'Close Preview';
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    // Project header strip
    var projTitle = document.querySelector('.seg-header-title');
    var pTitle = projTitle ? projTitle.textContent.trim() : 'Segment Report';
    var projStrip = document.createElement('div');
    projStrip.className = 'seg-print-project-strip';
    projStrip.innerHTML = '<div style="font-size:14px;font-weight:700;color:#323367;">' + segEscapeHtml(pTitle) + '</div>' +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Segment &bull; ' + new Date().toLocaleDateString() + '</div>';
    overlay.appendChild(projStrip);

    // Build pages
    var printPinIdx = 0;
    segPinnedViews.forEach(function(item) {
      if (item.type === 'section') {
        var sectionEl = document.createElement('div');
        sectionEl.className = 'seg-print-section-strip';
        sectionEl.textContent = item.title || 'Untitled Section';
        overlay.appendChild(sectionEl);
        return;
      }

      printPinIdx++;
      var page = document.createElement('div');
      page.className = 'seg-print-page';

      // Header
      var hdr = document.createElement('div');
      hdr.className = 'seg-print-header';
      hdr.innerHTML = (item.panelLabel ? '<div class="seg-print-panel-label">' + segEscapeHtml(item.panelLabel) + '</div>' : '') +
        '<div class="seg-print-title">' + segEscapeHtml(item.sectionTitle) + '</div>';
      page.appendChild(hdr);

      // Insight
      if (item.insightText) {
        var insDiv = document.createElement('div');
        insDiv.className = 'seg-print-insight';
        insDiv.textContent = item.insightText;
        page.appendChild(insDiv);
      }

      // Chart
      if (item.chartSvg) {
        var chartDiv = document.createElement('div');
        chartDiv.className = 'seg-print-chart';
        chartDiv.innerHTML = item.chartSvg;
        page.appendChild(chartDiv);
      }

      // Table
      if (item.tableHtml) {
        var tableDiv = document.createElement('div');
        tableDiv.className = 'seg-print-table';
        tableDiv.innerHTML = item.tableHtml;
        page.appendChild(tableDiv);
      }

      // Page number
      var pgNum = document.createElement('div');
      pgNum.className = 'seg-print-page-num';
      pgNum.textContent = printPinIdx + ' of ' + pinCount;
      page.appendChild(pgNum);

      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    function cleanupPrintOverlay() {
      var ov = document.getElementById('seg-pinned-print-overlay');
      if (ov) ov.remove();
      var ps = document.getElementById('seg-pinned-print-style');
      if (ps) ps.remove();
    }

    var cleaned = false;
    function onAfterPrint() {
      if (cleaned) return;
      cleaned = true;
      window.removeEventListener('afterprint', onAfterPrint);
      cleanupPrintOverlay();
    }
    window.addEventListener('afterprint', onAfterPrint);

    setTimeout(function() {
      window.print();
      setTimeout(function() {
        if (!cleaned) { cleaned = true; cleanupPrintOverlay(); }
      }, 3000);
    }, 300);
  };

  /**
   * Serialize pinned views to hidden data store (call before save).
   */
  window.segSavePinnedData = function() {
    var store = document.getElementById('seg-pinned-views-data');
    if (store) {
      store.textContent = JSON.stringify(segPinnedViews);
    }
  };

  /**
   * Hydrate pinned views from hidden data store (call on page load).
   */
  window.segHydratePinnedViews = function() {
    var store = document.getElementById('seg-pinned-views-data');
    if (!store || !store.textContent.trim()) return;
    try {
      var data = JSON.parse(store.textContent);
      if (Array.isArray(data) && data.length > 0) {
        segPinnedViews = data;
        segRenderPinnedCards();
        segUpdatePinBadge();
        segUpdatePinButtons();
      }
    } catch (e) {
      // Ignore parse errors
    }
  };

})();
