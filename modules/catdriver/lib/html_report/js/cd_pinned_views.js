/* ==============================================================================
 * CATDRIVER HTML REPORT - PINNED VIEWS
 * ==============================================================================
 * Pin sections to a dedicated Pinned Views panel. Each pin captures:
 * section title, analysis label, insight text, chart SVG, table HTML.
 * Supports section headers/dividers between pins (like tabs/tracker).
 * Pins can be exported as PNG slides or printed to PDF.
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // In-memory array of pinned views (pins and section dividers)
  var cdPinnedViews = [];

  /**
   * Get the current pinned views array.
   * @returns {Array}
   */
  window.cdGetPinnedViews = function() {
    return cdPinnedViews;
  };

  /**
   * Count only actual pins (not section dividers).
   * @returns {number}
   */
  function countPins() {
    var count = 0;
    for (var i = 0; i < cdPinnedViews.length; i++) {
      if (cdPinnedViews[i].type !== 'section') count++;
    }
    return count;
  }

  /**
   * Pin a section — show mode popover (table/chart/both).
   * If already pinned, unpin instead.
   * @param {string} sectionKey - Section key (e.g., 'importance')
   * @param {string} prefix - ID prefix (e.g., 'nps-')
   */
  window.cdPinSection = function(sectionKey, prefix) {
    prefix = prefix || '';

    // Check for duplicate (toggle behaviour — unpin)
    for (var i = 0; i < cdPinnedViews.length; i++) {
      if (cdPinnedViews[i].type !== 'section' &&
          cdPinnedViews[i].sectionKey === sectionKey &&
          cdPinnedViews[i].prefix === prefix) {
        cdPinnedViews.splice(i, 1);
        cdSavePinnedData();
        cdRenderPinnedCards();
        cdUpdatePinBadge();
        cdUpdatePinButtons();
        cdClosePopover();
        return;
      }
    }

    // Show mode popover
    var btn = document.querySelector('.cd-pin-btn[data-cd-pin-section="' + sectionKey + '"]');
    if (!btn) { cdExecutePin(sectionKey, prefix, 'all'); return; }

    cdClosePopover();

    var content = cdCaptureSectionContent(sectionKey, prefix);
    var hasChart = content && content.chartSvg;
    var hasTable = content && content.tableHtml;

    var popover = document.createElement('div');
    popover.className = 'cd-pin-popover';
    popover.id = 'cd-pin-popover';

    var options = [
      { label: 'Table + Chart', mode: 'all', enabled: hasChart && hasTable },
      { label: 'Chart only', mode: 'chart_insight', enabled: !!hasChart },
      { label: 'Table only', mode: 'table_insight', enabled: !!hasTable }
    ];

    options.forEach(function(opt) {
      var item = document.createElement('button');
      item.className = 'cd-pin-popover-item';
      item.textContent = opt.label;
      if (!opt.enabled) {
        item.disabled = true;
        item.style.opacity = '0.4';
        item.style.cursor = 'default';
      } else {
        item.onclick = function(e) {
          e.stopPropagation();
          cdExecutePin(sectionKey, prefix, opt.mode);
          cdClosePopover();
        };
      }
      popover.appendChild(item);
    });

    btn.parentElement.style.position = 'relative';
    btn.parentElement.appendChild(popover);

    setTimeout(function() {
      document.addEventListener('click', cdClosePopoverOnOutside);
    }, 10);
  };

  function cdClosePopover() {
    var p = document.getElementById('cd-pin-popover');
    if (p) p.remove();
    document.removeEventListener('click', cdClosePopoverOnOutside);
  }

  function cdClosePopoverOnOutside(e) {
    var p = document.getElementById('cd-pin-popover');
    if (p && !p.contains(e.target)) cdClosePopover();
  }

  /**
   * Execute pin with selected mode.
   */
  function cdExecutePin(sectionKey, prefix, mode) {
    var content = cdCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    var pin = {
      type: 'pin',
      id: 'pin-' + Date.now() + '-' + Math.random().toString(36).substr(2, 6),
      sectionKey: sectionKey,
      prefix: prefix,
      pinMode: mode,
      panelLabel: content.panelLabel,
      sectionTitle: content.sectionTitle,
      insightText: content.insightText,
      chartSvg: (mode === 'all' || mode === 'chart_insight') ? content.chartSvg : '',
      tableHtml: (mode === 'all' || mode === 'table_insight') ? content.tableHtml : '',
      timestamp: new Date().toISOString(),
      modelType: content.modelType,
      sampleN: content.sampleN,
      r2Text: content.r2Text
    };

    cdPinnedViews.push(pin);
    cdSavePinnedData();
    cdRenderPinnedCards();
    cdUpdatePinBadge();
    cdUpdatePinButtons();
  }

  /**
   * Add a section header/divider.
   * @param {string} title - Optional title (default "New Section")
   */
  window.cdAddSection = function(title) {
    title = title || 'New Section';
    cdPinnedViews.push({
      type: 'section',
      title: title,
      id: 'sec-' + Date.now() + '-' + Math.random().toString(36).substr(2, 5)
    });
    cdSavePinnedData();
    cdRenderPinnedCards();
    cdUpdatePinBadge();
  };

  /**
   * Update a section header title.
   * @param {number} idx - Index in cdPinnedViews
   * @param {string} newTitle
   */
  window.cdUpdateSectionTitle = function(idx, newTitle) {
    if (idx >= 0 && idx < cdPinnedViews.length && cdPinnedViews[idx].type === 'section') {
      cdPinnedViews[idx].title = (newTitle || '').trim() || 'Untitled Section';
      cdSavePinnedData();
    }
  };

  /**
   * Capture content from a section for pinning.
   * @param {string} sectionKey
   * @param {string} prefix
   * @returns {Object|null}
   */
  function cdCaptureSectionContent(sectionKey, prefix) {
    var sectionId = prefix + 'cd-' + sectionKey;
    var section = document.getElementById(sectionId);
    if (!section) return null;

    // Panel label (analysis name) — check analysis panel first, fall back to overview
    var panelLabel = '';
    var panel = section.closest('.cd-analysis-panel');
    if (panel) {
      var heading = panel.querySelector('.cd-panel-heading-title');
      panelLabel = heading ? heading.textContent.trim() : '';
      // For overview panel, use "Overview" as label
      if (!panelLabel && panel.id === 'cd-tab-overview') {
        panelLabel = 'Overview';
      }
    }

    // Section title
    var titleEl = section.querySelector('.cd-section-title');
    var sectionTitle = titleEl ? titleEl.textContent.trim() : sectionKey;

    // Insight text (if editor has content)
    var insightText = '';
    var insightContainer = document.getElementById(prefix + 'cd-insight-container-' + sectionKey);
    if (insightContainer) {
      var editor = insightContainer.querySelector('.cd-insight-editor');
      if (editor && editor.textContent.trim()) {
        insightText = editor.textContent.trim();
      }
    }

    // Chart SVG — look for any SVG with cd-chart or cd-forest-plot class
    var chartSvg = '';
    var svgEl = section.querySelector('svg.cd-chart, svg.cd-forest-plot');
    if (svgEl) {
      // Clone to avoid modifying the original
      var svgClone = svgEl.cloneNode(true);
      chartSvg = svgClone.outerHTML;
    }

    // Table HTML — capture first visible table, skip patterns (too many)
    var tableHtml = '';
    if (sectionKey !== 'patterns') {
      var tableEl = section.querySelector('table.cd-table, table.cd-comp-table');
      if (tableEl) {
        // Clone visible rows only (respect chip filtering)
        var tableClone = tableEl.cloneNode(true);
        var hiddenRows = tableClone.querySelectorAll('tr[style*="display: none"], tr[style*="display:none"]');
        hiddenRows.forEach(function(row) { row.remove(); });
        tableHtml = tableClone.outerHTML;
      }
    }

    // For overview sections, also capture card grid or insight elements as content
    if (sectionKey === 'summary-cards' && !tableHtml && !chartSvg) {
      var cardGrid = section.querySelector('.cd-comp-cards');
      if (cardGrid) tableHtml = '<div class="cd-pinned-exec-content">' + cardGrid.outerHTML + '</div>';
    }
    if (sectionKey === 'key-insights' && !tableHtml && !chartSvg) {
      var insightEls = section.querySelectorAll('.cd-comp-insight');
      if (insightEls.length > 0) {
        var insHtml = '';
        insightEls.forEach(function(el) { insHtml += el.outerHTML; });
        tableHtml = '<div class="cd-pinned-exec-content">' + insHtml + '</div>';
      }
    }

    // For exec-summary, capture callout cards + key insights + findings
    if (sectionKey === 'exec-summary') {
      var execContent = '';
      // Model confidence callout
      var confidence = section.querySelector('.cd-model-confidence');
      if (confidence) execContent += confidence.outerHTML;
      // Top driver callout cards
      var callouts = section.querySelectorAll('.cd-callout');
      if (callouts.length > 0) {
        callouts.forEach(function(c) { execContent += c.outerHTML; });
      }
      // Key insights list
      var insightsList = section.querySelector('.cd-key-insights-heading');
      if (insightsList) {
        var insightsContainer = insightsList.parentElement;
        if (insightsContainer) execContent += insightsContainer.outerHTML;
      }
      // Standout findings box
      var findingBox = section.querySelector('.cd-finding-box');
      if (findingBox) execContent += findingBox.outerHTML;

      if (execContent) {
        tableHtml = '<div class="cd-pinned-exec-content">' + execContent + '</div>';
      }
    }

    // For diagnostics, capture the checks table + fit stats
    if (sectionKey === 'diagnostics' && !chartSvg) {
      var diagTable = section.querySelector('table.cd-diagnostics-table');
      if (diagTable) tableHtml = diagTable.outerHTML;
    }

    // Model metadata from panel heading
    var modelType = '';
    var sampleN = '';
    var r2Text = '';
    if (panel) {
      var stats = panel.querySelectorAll('.cd-panel-stat');
      stats.forEach(function(stat) {
        var t = stat.textContent.trim();
        if (t.match(/logistic/i)) modelType = t;
        else if (t.match(/^n\s*=/i)) sampleN = t;
        else if (t.match(/^R/)) r2Text = t;
      });
    }
    // Single report mode — try header badges
    if (!modelType) {
      var badges = document.querySelectorAll('.cd-header-badge');
      badges.forEach(function(b) {
        var t = b.textContent.trim();
        if (t.match(/logistic/i)) modelType = t;
        else if (t.match(/^n\s*=/i)) sampleN = t;
        else if (t.match(/^R/)) r2Text = t;
      });
    }

    return {
      panelLabel: panelLabel,
      sectionTitle: sectionTitle,
      insightText: insightText,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      modelType: modelType,
      sampleN: sampleN,
      r2Text: r2Text
    };
  }

  /**
   * Render pinned cards into the pinned views container.
   */
  // --------------------------------------------------------------------------
  // Drag-and-drop state
  // --------------------------------------------------------------------------
  var cdDragFromIdx = null;

  /**
   * Render pinned cards into the pinned views container.
   * Cards are draggable for reordering.
   */
  window.cdRenderPinnedCards = function() {
    var container = document.getElementById('cd-pinned-cards-container');
    if (!container) return;

    var emptyState = document.getElementById('cd-pinned-empty');

    if (cdPinnedViews.length === 0) {
      container.innerHTML = '';
      if (emptyState) emptyState.style.display = 'block';
      return;
    }

    if (emptyState) emptyState.style.display = 'none';

    container.innerHTML = '';

    cdPinnedViews.forEach(function(item, idx) {
      // --- Section divider ---
      if (item.type === 'section') {
        var divider = document.createElement('div');
        divider.className = 'cd-section-divider';
        divider.setAttribute('draggable', 'true');
        divider.setAttribute('data-cd-drag-idx', idx);

        var titleEl = document.createElement('div');
        titleEl.className = 'cd-section-divider-title';
        titleEl.contentEditable = 'true';
        titleEl.textContent = item.title;
        titleEl.onblur = function() { cdUpdateSectionTitle(idx, this.textContent); };
        divider.appendChild(titleEl);

        var sActions = document.createElement('div');
        sActions.className = 'cd-section-divider-actions';
        var sDel = document.createElement('button');
        sDel.className = 'cd-pinned-action-btn cd-pinned-remove-btn';
        sDel.textContent = '\u2715'; sDel.title = 'Remove section';
        sDel.onclick = function() { cdRemovePinned(item.id); };
        sActions.appendChild(sDel);
        divider.appendChild(sActions);

        cdAttachDragHandlers(divider, idx);
        container.appendChild(divider);
        return;
      }

      // --- Pin card ---
      var pin = item;
      var mode = pin.pinMode || 'all';
      var card = document.createElement('div');
      card.className = 'cd-pinned-card';
      card.setAttribute('data-pin-id', pin.id);
      card.setAttribute('draggable', 'true');
      card.setAttribute('data-cd-drag-idx', idx);

      var labelTag = pin.panelLabel
        ? '<span class="cd-pinned-card-label">' + cdEscapeHtml(pin.panelLabel) + '</span>'
        : '';

      var insightBlock = pin.insightText
        ? '<div class="cd-pinned-card-insight">' + cdEscapeHtml(pin.insightText) + '</div>'
        : '';

      var showChart = (mode === 'all' || mode === 'chart_insight');
      var showTable = (mode === 'all' || mode === 'table_insight');

      var chartBlock = (showChart && pin.chartSvg)
        ? '<div class="cd-pinned-card-chart">' + pin.chartSvg + '</div>'
        : '';

      var tableBlock = (showTable && pin.tableHtml)
        ? '<div class="cd-pinned-card-table">' + pin.tableHtml + '</div>'
        : '';

      var actionsHtml = '';
      actionsHtml += '<button class="cd-pinned-action-btn cd-pinned-export-btn" onclick="cdExportPinnedCardPNG(\'' + pin.id + '\')" title="Export as PNG">\uD83D\uDCE5</button>';
      actionsHtml += '<button class="cd-pinned-action-btn cd-pinned-remove-btn" onclick="cdRemovePinned(\'' + pin.id + '\')" title="Remove pin">\u2715</button>';

      card.innerHTML = '<div class="cd-pinned-card-header">'
        + '<div class="cd-pinned-card-title">'
        + labelTag
        + '<span class="cd-pinned-card-section">' + cdEscapeHtml(pin.sectionTitle) + '</span>'
        + '</div>'
        + '<div class="cd-pinned-card-actions">' + actionsHtml + '</div>'
        + '</div>'
        + insightBlock
        + chartBlock
        + tableBlock;

      cdAttachDragHandlers(card, idx);
      container.appendChild(card);
    });
  };

  /**
   * Attach drag-and-drop handlers to a card/divider element.
   */
  function cdAttachDragHandlers(el, idx) {
    el.addEventListener('dragstart', function(e) {
      cdDragFromIdx = idx;
      el.classList.add('cd-pin-dragging');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', String(idx));
    });
    el.addEventListener('dragover', function(e) {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      el.classList.add('cd-pin-drop-target');
    });
    el.addEventListener('dragleave', function() {
      el.classList.remove('cd-pin-drop-target');
    });
    el.addEventListener('drop', function(e) {
      e.preventDefault();
      el.classList.remove('cd-pin-drop-target');
      var toIdx = parseInt(el.getAttribute('data-cd-drag-idx'), 10);
      if (cdDragFromIdx !== null && cdDragFromIdx !== toIdx) {
        var item = cdPinnedViews.splice(cdDragFromIdx, 1)[0];
        cdPinnedViews.splice(toIdx, 0, item);
        cdSavePinnedData();
        cdRenderPinnedCards();
      }
      cdDragFromIdx = null;
    });
    el.addEventListener('dragend', function() {
      el.classList.remove('cd-pin-dragging');
      cdDragFromIdx = null;
      document.querySelectorAll('.cd-pin-drop-target').forEach(function(t) {
        t.classList.remove('cd-pin-drop-target');
      });
    });
  }

  /**
   * Remove a pinned view or section by ID.
   * @param {string} pinId
   */
  window.cdRemovePinned = function(pinId) {
    cdPinnedViews = cdPinnedViews.filter(function(p) { return p.id !== pinId; });
    cdRenderPinnedCards();
    cdUpdatePinBadge();
    cdUpdatePinButtons();
  };

  /**
   * Move a pinned view up or down.
   * @param {string} pinId
   * @param {number} direction - -1 for up, +1 for down
   */
  window.cdMovePinned = function(pinId, direction) {
    var idx = -1;
    for (var i = 0; i < cdPinnedViews.length; i++) {
      if (cdPinnedViews[i].id === pinId) { idx = i; break; }
    }
    if (idx < 0) return;

    var newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= cdPinnedViews.length) return;

    var temp = cdPinnedViews[idx];
    cdPinnedViews[idx] = cdPinnedViews[newIdx];
    cdPinnedViews[newIdx] = temp;

    cdRenderPinnedCards();
  };

  /**
   * Clear all pinned views.
   */
  window.cdClearAllPinned = function() {
    cdPinnedViews = [];
    cdRenderPinnedCards();
    cdUpdatePinBadge();
    cdUpdatePinButtons();
  };

  /**
   * Update the pin count badge in the tab bar.
   * Only counts actual pins, not section dividers.
   */
  window.cdUpdatePinBadge = function() {
    var badge = document.getElementById('cd-pin-count-badge');
    var n = countPins();
    if (badge) {
      badge.textContent = n;
      badge.style.display = n > 0 ? 'inline-flex' : 'none';
    }
  };

  /**
   * Update pin button states (active/inactive) based on pinned views.
   */
  function cdUpdatePinButtons() {
    document.querySelectorAll('.cd-pin-btn').forEach(function(btn) {
      var sectionKey = btn.getAttribute('data-cd-pin-section');
      var prefix = btn.getAttribute('data-cd-pin-prefix') || '';
      var isPinned = false;
      for (var i = 0; i < cdPinnedViews.length; i++) {
        if (cdPinnedViews[i].type !== 'section' &&
            cdPinnedViews[i].sectionKey === sectionKey &&
            cdPinnedViews[i].prefix === prefix) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle('cd-pin-btn-active', isPinned);
      btn.title = isPinned ? 'Unpin this section' : 'Pin to Views';
    });
  }

  /**
   * Export all pinned views as PNG slides.
   */
  window.cdExportAllPinnedPNG = function() {
    var pins = cdPinnedViews.filter(function(p) { return p.type !== 'section'; });
    if (pins.length === 0) return;
    pins.forEach(function(pin, idx) {
      setTimeout(function() {
        cdExportPinnedCardPNG(pin.id);
      }, idx * 500);
    });
  };

  /**
   * Print pinned views to PDF via window.print() overlay.
   * Builds a temporary print layout: one pin per page, section dividers as
   * heading strips. User saves to PDF from the print dialog.
   */
  window.cdPrintPinnedViews = function() {
    var pinCount = countPins();
    if (pinCount === 0) return;

    // Create print overlay
    var overlay = document.createElement('div');
    overlay.id = 'cd-pinned-print-overlay';
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:white;overflow:auto;';

    // Print styles
    var printStyle = document.createElement('style');
    printStyle.id = 'cd-pinned-print-style';
    printStyle.textContent =
      '@page { size: A4 landscape; margin: 10mm 12mm; } ' +
      '@media print { ' +
      'body > *:not(#cd-pinned-print-overlay) { display: none !important; } ' +
      '#cd-pinned-print-overlay { position: static !important; overflow: visible !important; } ' +
      '.cd-print-page { page-break-after: always; padding: 12px 0; box-sizing: border-box; } ' +
      '.cd-print-page:last-child { page-break-after: auto; } ' +
      '.cd-print-header { margin-bottom: 10px; } ' +
      '.cd-print-panel-label { font-size: 13px; font-weight: 700; color: #323367; text-transform: uppercase; letter-spacing: 0.3px; } ' +
      '.cd-print-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 2px 0; } ' +
      '.cd-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid #323367; ' +
      '  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; ' +
      '  color: #1a2744; line-height: 1.5; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.cd-print-chart { margin-bottom: 12px; } ' +
      '.cd-print-chart svg { width: 100%; height: auto; } ' +
      '.cd-print-table { overflow: visible; } ' +
      '.cd-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } ' +
      '.cd-print-table th, .cd-print-table td { padding: 4px 8px; border: 1px solid #ddd; text-align: left; word-wrap: break-word; } ' +
      '.cd-print-table th { background: #f1f5f9; font-weight: 600; font-size: 12px; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.cd-print-page-num { text-align: right; font-size: 9px; color: #94a3b8; margin-top: 4px; } ' +
      '.cd-print-project-strip { padding: 0 0 8px 0; margin-bottom: 12px; border-bottom: 2px solid #323367; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.cd-print-section-strip { padding: 16px 0 8px; margin: 8px 0; border-bottom: 2px solid #323367; font-size: 16px; font-weight: 600; color: #323367; } ' +
      '} ' +
      // Screen preview
      '#cd-pinned-print-overlay { padding: 32px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; } ' +
      '.cd-print-page { border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; margin-bottom: 16px; background: white; } ' +
      '.cd-print-close-btn { position: fixed; top: 16px; right: 16px; z-index: 100000; padding: 8px 20px; background: #323367; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }';
    document.head.appendChild(printStyle);

    // Close button (visible on screen, hidden in print)
    var closeBtn = document.createElement('button');
    closeBtn.className = 'cd-print-close-btn';
    closeBtn.textContent = 'Close Preview';
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    // Project header strip
    var projTitle = document.querySelector('.cd-header-title, .cd-comp-title');
    var pTitle = projTitle ? projTitle.textContent.trim() : 'Catdriver Report';
    var projStrip = document.createElement('div');
    projStrip.className = 'cd-print-project-strip';
    projStrip.innerHTML = '<div style="font-size:14px;font-weight:700;color:#323367;">' + cdEscapeHtml(pTitle) + '</div>' +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Catdriver &bull; ' + new Date().toLocaleDateString() + '</div>';
    overlay.appendChild(projStrip);

    // Build pages
    var printPinIdx = 0;
    cdPinnedViews.forEach(function(item) {
      if (item.type === 'section') {
        var sectionEl = document.createElement('div');
        sectionEl.className = 'cd-print-section-strip';
        sectionEl.textContent = item.title || 'Untitled Section';
        overlay.appendChild(sectionEl);
        return;
      }

      printPinIdx++;
      var page = document.createElement('div');
      page.className = 'cd-print-page';

      // Header
      var hdr = document.createElement('div');
      hdr.className = 'cd-print-header';
      hdr.innerHTML = (item.panelLabel ? '<div class="cd-print-panel-label">' + cdEscapeHtml(item.panelLabel) + '</div>' : '') +
        '<div class="cd-print-title">' + cdEscapeHtml(item.sectionTitle) + '</div>';
      page.appendChild(hdr);

      // Insight
      if (item.insightText) {
        var insDiv = document.createElement('div');
        insDiv.className = 'cd-print-insight';
        insDiv.textContent = item.insightText;
        page.appendChild(insDiv);
      }

      // Chart
      if (item.chartSvg) {
        var chartDiv = document.createElement('div');
        chartDiv.className = 'cd-print-chart';
        chartDiv.innerHTML = item.chartSvg;
        page.appendChild(chartDiv);
      }

      // Table
      if (item.tableHtml) {
        var tableDiv = document.createElement('div');
        tableDiv.className = 'cd-print-table';
        tableDiv.innerHTML = item.tableHtml;
        page.appendChild(tableDiv);
      }

      // Page number
      var pgNum = document.createElement('div');
      pgNum.className = 'cd-print-page-num';
      pgNum.textContent = printPinIdx + ' of ' + pinCount;
      page.appendChild(pgNum);

      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    function cleanupPrintOverlay() {
      var ov = document.getElementById('cd-pinned-print-overlay');
      if (ov) ov.remove();
      var ps = document.getElementById('cd-pinned-print-style');
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
  window.cdSavePinnedData = function() {
    var store = document.getElementById('cd-pinned-views-data');
    if (store) {
      store.textContent = JSON.stringify(cdPinnedViews);
    }
  };

  /**
   * Hydrate pinned views from hidden data store (call on page load).
   */
  window.cdHydratePinnedViews = function() {
    var store = document.getElementById('cd-pinned-views-data');
    if (!store || !store.textContent.trim()) return;
    try {
      var data = JSON.parse(store.textContent);
      if (Array.isArray(data) && data.length > 0) {
        cdPinnedViews = data;
        cdRenderPinnedCards();
        cdUpdatePinBadge();
        cdUpdatePinButtons();
      }
    } catch (e) {
      // Ignore parse errors
    }
  };

})();
