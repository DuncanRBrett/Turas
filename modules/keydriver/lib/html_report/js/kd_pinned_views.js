/* ==============================================================================
 * KEYDRIVER HTML REPORT - PINNED VIEWS
 * ==============================================================================
 * Pin sections to a dedicated Pinned Views panel. Each pin captures:
 * section title, analysis label, insight text, chart SVG, table HTML.
 * Supports section headers/dividers between pins (like tabs/tracker).
 * Pins can be exported as PNG slides or printed to PDF.
 * All functions prefixed kd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // In-memory array of pinned views (pins and section dividers)
  var kdPinnedViews = [];

  /**
   * Get the current pinned views array.
   * @returns {Array}
   */
  window.kdGetPinnedViews = function() {
    return kdPinnedViews;
  };

  /**
   * Count only actual pins (not section dividers).
   * @returns {number}
   */
  function countPins() {
    var count = 0;
    for (var i = 0; i < kdPinnedViews.length; i++) {
      if (kdPinnedViews[i].type !== 'section') count++;
    }
    return count;
  }

  /**
   * Pin a section from an analysis panel.
   * @param {string} sectionKey - Section key (e.g., 'importance')
   * @param {string} prefix - ID prefix (e.g., 'nps-')
   */
  window.kdPinSection = function(sectionKey, prefix) {
    prefix = prefix || '';
    var content = kdCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    // Check for duplicate (toggle behaviour)
    for (var i = 0; i < kdPinnedViews.length; i++) {
      if (kdPinnedViews[i].type !== 'section' &&
          kdPinnedViews[i].sectionKey === sectionKey &&
          kdPinnedViews[i].prefix === prefix) {
        kdPinnedViews.splice(i, 1);
        kdRenderPinnedCards();
        kdUpdatePinBadge();
        kdUpdatePinButtons();
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

    kdPinnedViews.push(pin);
    kdRenderPinnedCards();
    kdUpdatePinBadge();
    kdUpdatePinButtons();
  };

  /**
   * Pin a specific component (chart or table) from a section.
   * @param {string} sectionKey - Section key (e.g., 'importance')
   * @param {string} component - 'chart' or 'table'
   * @param {string} prefix - ID prefix (e.g., 'nps-')
   */
  window.kdPinComponent = function(sectionKey, component, prefix) {
    prefix = prefix || '';

    // Check for duplicate (toggle behaviour) — match by sectionKey + prefix + component
    for (var i = 0; i < kdPinnedViews.length; i++) {
      if (kdPinnedViews[i].type !== 'section' &&
          kdPinnedViews[i].sectionKey === sectionKey &&
          kdPinnedViews[i].prefix === prefix &&
          kdPinnedViews[i].component === component) {
        kdPinnedViews.splice(i, 1);
        kdRenderPinnedCards();
        kdUpdatePinBadge();
        kdUpdatePinButtons();
        return;
      }
    }

    // Build partial capture
    var content = kdCaptureSectionContent(sectionKey, prefix);
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

    kdPinnedViews.push(pin);
    kdRenderPinnedCards();
    kdUpdatePinBadge();
    kdUpdatePinButtons();
  };

  /**
   * Add a section header/divider.
   * @param {string} title - Optional title (default "New Section")
   */
  window.kdAddSection = function(title) {
    title = title || 'New Section';
    kdPinnedViews.push({
      type: 'section',
      title: title,
      id: 'sec-' + Date.now() + '-' + Math.random().toString(36).substr(2, 5)
    });
    kdSavePinnedData();
    kdRenderPinnedCards();
    kdUpdatePinBadge();
  };

  /**
   * Update a section header title.
   * @param {number} idx - Index in kdPinnedViews
   * @param {string} newTitle
   */
  window.kdUpdateSectionTitle = function(idx, newTitle) {
    if (idx >= 0 && idx < kdPinnedViews.length && kdPinnedViews[idx].type === 'section') {
      kdPinnedViews[idx].title = (newTitle || '').trim() || 'Untitled Section';
      kdSavePinnedData();
    }
  };

  // ============================================================================
  // QUALITATIVE SLIDE SUPPORT
  // ============================================================================

  /**
   * Add a qualitative slide to the pinned views panel.
   * Creates a card with markdown editor, image upload, and pin functionality.
   */
  window.kdAddQualSlide = function() {
    var container = document.getElementById('kd-qual-slides-container');
    if (!container) return;
    var id = 'kd-qual-' + Date.now();
    var card = document.createElement('div');
    card.className = 'kd-qual-slide-card editing';
    card.setAttribute('data-slide-id', id);
    card.innerHTML =
      '<div class="kd-qual-header">' +
        '<div class="kd-qual-title" contenteditable="true">New Slide</div>' +
        '<div class="kd-qual-actions">' +
          '<button class="kd-qual-btn" title="Add image" onclick="kdTriggerQualImage(\'' + id + '\')">&#x1F4F7;</button>' +
          '<button class="kd-qual-btn" title="Pin to presentation" onclick="kdPinQualSlide(\'' + id + '\')">&#x1F4CC;</button>' +
          '<button class="kd-qual-btn" title="Move up" onclick="kdMoveQualSlide(\'' + id + '\',-1)">&uarr;</button>' +
          '<button class="kd-qual-btn" title="Move down" onclick="kdMoveQualSlide(\'' + id + '\',1)">&darr;</button>' +
          '<button class="kd-qual-btn kd-qual-delete" title="Delete slide" onclick="kdRemoveQualSlide(\'' + id + '\')">&times;</button>' +
        '</div>' +
      '</div>' +
      '<div class="kd-qual-img-preview" style="display:none;">' +
        '<img class="kd-qual-img-thumb" src="" alt="Slide image"/>' +
        '<button class="kd-qual-img-remove" onclick="kdRemoveQualImage(\'' + id + '\')">&times;</button>' +
      '</div>' +
      '<input type="file" class="kd-qual-img-input" accept="image/*" style="display:none" ' +
        'onchange="kdHandleQualImage(\'' + id + '\',this)"/>' +
      '<textarea class="kd-qual-md-editor" rows="4" placeholder="Enter commentary here (plain text or markdown)..."></textarea>' +
      '<textarea class="kd-qual-img-store" style="display:none"></textarea>';
    container.appendChild(card);
    var editor = card.querySelector('.kd-qual-md-editor');
    if (editor) editor.focus();
  };

  /**
   * Trigger file picker for qualitative slide image.
   */
  window.kdTriggerQualImage = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var input = card.querySelector('.kd-qual-img-input');
    if (input) input.click();
  };

  /**
   * Handle image file selection — resize and store as base64.
   */
  window.kdHandleQualImage = function(slideId, input) {
    if (!input.files || !input.files[0]) return;
    var file = input.files[0];
    if (file.size > 5 * 1024 * 1024) {
      alert('Image too large (max 5 MB). Please use a smaller image or reduce its resolution.');
      input.value = '';
      return;
    }
    var reader = new FileReader();
    reader.onload = function(e) {
      var img = new Image();
      img.onerror = function() { input.value = ''; };
      img.onload = function() {
        var maxDim = 800;
        var w = img.width, h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) { h = Math.round(h * maxDim / w); w = maxDim; }
          else { w = Math.round(w * maxDim / h); h = maxDim; }
        }
        var canvas = document.createElement('canvas');
        canvas.width = w; canvas.height = h;
        canvas.getContext('2d').drawImage(img, 0, 0, w, h);
        var dataUrl = canvas.toDataURL('image/jpeg', 0.7);
        var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
        if (!card) return;
        var store = card.querySelector('.kd-qual-img-store');
        if (store) {
          store.value = dataUrl;
          store.setAttribute('data-img-w', w);
          store.setAttribute('data-img-h', h);
        }
        var preview = card.querySelector('.kd-qual-img-preview');
        var thumb = card.querySelector('.kd-qual-img-thumb');
        if (preview && thumb) {
          thumb.src = dataUrl;
          preview.style.display = 'block';
        }
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
    input.value = '';
  };

  /**
   * Remove image from qualitative slide.
   */
  window.kdRemoveQualImage = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var store = card.querySelector('.kd-qual-img-store');
    if (store) { store.value = ''; store.removeAttribute('data-img-w'); store.removeAttribute('data-img-h'); }
    var preview = card.querySelector('.kd-qual-img-preview');
    if (preview) preview.style.display = 'none';
  };

  /**
   * Pin a qualitative slide to the pinned views panel.
   */
  window.kdPinQualSlide = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var titleEl = card.querySelector('.kd-qual-title');
    var editorEl = card.querySelector('.kd-qual-md-editor');
    var storeEl = card.querySelector('.kd-qual-img-store');
    var title = titleEl ? titleEl.textContent.trim() : 'Untitled';
    var text = editorEl ? editorEl.value.trim() : '';
    var imageData = storeEl ? storeEl.value : '';
    var imgW = storeEl ? storeEl.getAttribute('data-img-w') : '';
    var imgH = storeEl ? storeEl.getAttribute('data-img-h') : '';

    kdPinnedViews.push({
      type: 'text_box',
      id: 'pin-' + Date.now() + '-' + Math.random().toString(36).substr(2, 5),
      pinType: 'text_box',
      qTitle: title,
      insightText: '<p>' + text.replace(/\n/g, '</p><p>') + '</p>',
      imageData: imageData,
      imageWidth: imgW,
      imageHeight: imgH,
      sectionKey: 'qualitative',
      label: title
    });
    kdSavePinnedData();
    kdRenderPinnedCards();
    kdUpdatePinBadge();
  };

  /**
   * Move a qualitative slide up or down.
   */
  window.kdMoveQualSlide = function(slideId, direction) {
    var container = document.getElementById('kd-qual-slides-container');
    if (!container) return;
    var cards = container.querySelectorAll('.kd-qual-slide-card');
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].getAttribute('data-slide-id') === slideId) {
        var target = i + direction;
        if (target >= 0 && target < cards.length) {
          if (direction < 0) container.insertBefore(cards[i], cards[target]);
          else container.insertBefore(cards[target], cards[i]);
        }
        return;
      }
    }
  };

  /**
   * Remove a qualitative slide.
   */
  window.kdRemoveQualSlide = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (card) card.remove();
  };

  /**
   * Capture content from a section for pinning.
   * @param {string} sectionKey
   * @param {string} prefix
   * @returns {Object|null}
   */
  function kdCaptureSectionContent(sectionKey, prefix) {
    var sectionId = prefix + 'kd-' + sectionKey;
    var section = document.getElementById(sectionId);
    if (!section) return null;

    // Panel label (analysis name) — check analysis panel first, fall back to overview
    var panelLabel = '';
    var panel = section.closest('.kd-analysis-panel');
    if (panel) {
      var heading = panel.querySelector('.kd-panel-heading-title');
      panelLabel = heading ? heading.textContent.trim() : '';
      // For overview panel, use "Overview" as label
      if (!panelLabel && panel.id === 'kd-tab-overview') {
        panelLabel = 'Overview';
      }
    }

    // Section title
    var titleEl = section.querySelector('.kd-section-title');
    var sectionTitle = titleEl ? titleEl.textContent.trim() : sectionKey;

    // Insight text (if editor has content)
    var insightText = '';
    var insightContainer = document.getElementById(prefix + 'kd-insight-container-' + sectionKey);
    if (insightContainer) {
      var editor = insightContainer.querySelector('.kd-insight-editor');
      if (editor && editor.textContent.trim()) {
        insightText = editor.textContent.trim();
      }
    }

    // Chart SVG — look inside chart wrapper/container, fall back to any SVG
    var chartSvg = '';
    var svgEl = section.querySelector('.kd-chart-wrapper svg, .kd-chart-container svg, svg.kd-importance-chart, svg.kd-chart');
    if (svgEl) {
      // Clone to avoid modifying the original
      var svgClone = svgEl.cloneNode(true);
      chartSvg = svgClone.outerHTML;
    }

    // Table HTML — capture first visible table
    var tableHtml = '';
    var tableEl = section.querySelector('table.kd-table, table.kd-comp-table, table.kd-quadrant-action-table');
    if (tableEl) {
      // Clone visible rows only (respect chip filtering)
      var tableClone = tableEl.cloneNode(true);
      var hiddenRows = tableClone.querySelectorAll('tr[style*="display: none"], tr[style*="display:none"]');
      hiddenRows.forEach(function(row) { row.remove(); });
      tableHtml = tableClone.outerHTML;
    }

    // For overview sections, also capture card grid or insight elements as content
    if (sectionKey === 'summary-cards' && !tableHtml && !chartSvg) {
      var cardGrid = section.querySelector('.kd-comp-cards');
      if (cardGrid) tableHtml = '<div class="kd-pinned-exec-content">' + cardGrid.outerHTML + '</div>';
    }
    if (sectionKey === 'key-insights' && !tableHtml && !chartSvg) {
      var insightEls = section.querySelectorAll('.kd-comp-insight');
      if (insightEls.length > 0) {
        var insHtml = '';
        insightEls.forEach(function(el) { insHtml += el.outerHTML; });
        tableHtml = '<div class="kd-pinned-exec-content">' + insHtml + '</div>';
      }
    }

    // For exec-summary, capture key insights + findings
    if (sectionKey === 'exec-summary') {
      var execContent = '';
      // Key insights list
      var insightsList = section.querySelector('.kd-key-insights-heading');
      if (insightsList) {
        var insightsContainer = insightsList.parentElement;
        if (insightsContainer) execContent += insightsContainer.outerHTML;
      }
      // Standout findings box
      var findingBox = section.querySelector('.kd-finding-box');
      if (findingBox) execContent += findingBox.outerHTML;

      if (execContent) {
        tableHtml = '<div class="kd-pinned-exec-content">' + execContent + '</div>';
      }
    }

    // For diagnostics, capture the checks table
    if (sectionKey === 'diagnostics' && !chartSvg) {
      var diagTable = section.querySelector('table.kd-diagnostics-table');
      if (diagTable) tableHtml = diagTable.outerHTML;
    }

    // Metadata from panel heading
    var methodText = '';
    var sampleN = '';
    if (panel) {
      var stats = panel.querySelectorAll('.kd-panel-stat');
      stats.forEach(function(stat) {
        var t = stat.textContent.trim();
        if (t.match(/correlation/i) || t.match(/regression/i)) methodText = t;
        else if (t.match(/^n\s*=/i)) sampleN = t;
      });
    }
    // Single report mode — try header badges
    if (!methodText) {
      var badges = document.querySelectorAll('.kd-header-badge');
      badges.forEach(function(b) {
        var t = b.textContent.trim();
        if (t.match(/correlation/i) || t.match(/regression/i)) methodText = t;
        else if (t.match(/^n\s*=/i)) sampleN = t;
      });
    }

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
  window.kdRenderPinnedCards = function() {
    var container = document.getElementById('kd-pinned-cards-container');
    if (!container) return;

    var emptyState = document.getElementById('kd-pinned-empty');
    var pinCount = countPins();

    if (kdPinnedViews.length === 0) {
      container.innerHTML = '';
      if (emptyState) emptyState.style.display = 'block';
      return;
    }

    if (emptyState) emptyState.style.display = 'none';
    var total = kdPinnedViews.length;

    // Build DOM directly for section headers (contentEditable)
    container.innerHTML = '';

    kdPinnedViews.forEach(function(item, idx) {
      // --- Section divider ---
      if (item.type === 'section') {
        var divider = document.createElement('div');
        divider.className = 'kd-section-divider';
        divider.setAttribute('data-idx', idx);

        var titleEl = document.createElement('div');
        titleEl.className = 'kd-section-divider-title';
        titleEl.contentEditable = 'true';
        titleEl.textContent = item.title;
        titleEl.onblur = function() { kdUpdateSectionTitle(idx, this.textContent); };
        divider.appendChild(titleEl);

        var sActions = document.createElement('div');
        sActions.className = 'kd-section-divider-actions';
        if (idx > 0) {
          var sUp = document.createElement('button');
          sUp.className = 'kd-pinned-action-btn';
          sUp.textContent = '\u25B2'; sUp.title = 'Move up';
          sUp.onclick = function() { kdMovePinned(item.id, -1); };
          sActions.appendChild(sUp);
        }
        if (idx < total - 1) {
          var sDown = document.createElement('button');
          sDown.className = 'kd-pinned-action-btn';
          sDown.textContent = '\u25BC'; sDown.title = 'Move down';
          sDown.onclick = function() { kdMovePinned(item.id, 1); };
          sActions.appendChild(sDown);
        }
        var sDel = document.createElement('button');
        sDel.className = 'kd-pinned-action-btn kd-pinned-remove-btn';
        sDel.textContent = '\u2715'; sDel.title = 'Remove section';
        sDel.onclick = function() { kdRemovePinned(item.id); };
        sActions.appendChild(sDel);
        divider.appendChild(sActions);
        container.appendChild(divider);
        return;
      }

      // --- Pin card ---
      var pin = item;
      var card = document.createElement('div');
      card.className = 'kd-pinned-card';
      card.setAttribute('data-pin-id', pin.id);

      var labelTag = pin.panelLabel
        ? '<span class="kd-pinned-card-label">' + kdEscapeHtml(pin.panelLabel) + '</span>'
        : '';

      var insightBlock = pin.insightText
        ? '<div class="kd-pinned-card-insight">' + kdEscapeHtml(pin.insightText) + '</div>'
        : '';

      var chartBlock = pin.chartSvg
        ? '<div class="kd-pinned-card-chart">' + pin.chartSvg + '</div>'
        : '';

      var tableBlock = pin.tableHtml
        ? '<div class="kd-pinned-card-table">' + pin.tableHtml + '</div>'
        : '';

      var actionsHtml = '';
      if (idx > 0) {
        actionsHtml += '<button class="kd-pinned-action-btn" onclick="kdMovePinned(\'' + pin.id + '\', -1)" title="Move up">\u25B2</button>';
      }
      if (idx < total - 1) {
        actionsHtml += '<button class="kd-pinned-action-btn" onclick="kdMovePinned(\'' + pin.id + '\', 1)" title="Move down">\u25BC</button>';
      }
      actionsHtml += '<button class="kd-pinned-action-btn kd-pinned-export-btn" onclick="kdExportPinnedCardPNG(\'' + pin.id + '\')" title="Export as PNG">\uD83D\uDCE5</button>';
      actionsHtml += '<button class="kd-pinned-action-btn kd-pinned-remove-btn" onclick="kdRemovePinned(\'' + pin.id + '\')" title="Remove pin">\u2715</button>';

      card.innerHTML = '<div class="kd-pinned-card-header">'
        + '<div class="kd-pinned-card-title">'
        + labelTag
        + '<span class="kd-pinned-card-section">' + kdEscapeHtml(pin.sectionTitle) + '</span>'
        + '</div>'
        + '<div class="kd-pinned-card-actions">' + actionsHtml + '</div>'
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
  window.kdRemovePinned = function(pinId) {
    kdPinnedViews = kdPinnedViews.filter(function(p) { return p.id !== pinId; });
    kdRenderPinnedCards();
    kdUpdatePinBadge();
    kdUpdatePinButtons();
  };

  /**
   * Move a pinned view up or down.
   * @param {string} pinId
   * @param {number} direction - -1 for up, +1 for down
   */
  window.kdMovePinned = function(pinId, direction) {
    var idx = -1;
    for (var i = 0; i < kdPinnedViews.length; i++) {
      if (kdPinnedViews[i].id === pinId) { idx = i; break; }
    }
    if (idx < 0) return;

    var newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= kdPinnedViews.length) return;

    var temp = kdPinnedViews[idx];
    kdPinnedViews[idx] = kdPinnedViews[newIdx];
    kdPinnedViews[newIdx] = temp;

    kdRenderPinnedCards();
  };

  /**
   * Clear all pinned views.
   */
  window.kdClearAllPinned = function() {
    kdPinnedViews = [];
    kdRenderPinnedCards();
    kdUpdatePinBadge();
    kdUpdatePinButtons();
  };

  /**
   * Update the pin count badge in the tab bar.
   * Only counts actual pins, not section dividers.
   */
  window.kdUpdatePinBadge = function() {
    var badge = document.getElementById('kd-pin-count-badge');
    var n = countPins();
    if (badge) {
      badge.textContent = n;
      badge.style.display = n > 0 ? 'inline-flex' : 'none';
    }
  };

  /**
   * Update pin button states (active/inactive) based on pinned views.
   */
  function kdUpdatePinButtons() {
    // Section-level pin buttons
    document.querySelectorAll('.kd-pin-btn').forEach(function(btn) {
      var sectionKey = btn.getAttribute('data-kd-pin-section');
      var prefix = btn.getAttribute('data-kd-pin-prefix') || '';
      var isPinned = false;
      for (var i = 0; i < kdPinnedViews.length; i++) {
        if (kdPinnedViews[i].type !== 'section' &&
            kdPinnedViews[i].sectionKey === sectionKey &&
            kdPinnedViews[i].prefix === prefix &&
            !kdPinnedViews[i].component) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle('kd-pin-btn-active', isPinned);
      btn.title = isPinned ? 'Unpin this section' : 'Pin this section';
    });

    // Component-level pin buttons (chart/table)
    document.querySelectorAll('.kd-component-pin').forEach(function(btn) {
      var sectionKey = btn.getAttribute('data-kd-pin-section');
      var prefix = btn.getAttribute('data-kd-pin-prefix') || '';
      var component = btn.getAttribute('data-kd-pin-component') || '';
      var isPinned = false;
      for (var i = 0; i < kdPinnedViews.length; i++) {
        if (kdPinnedViews[i].type !== 'section' &&
            kdPinnedViews[i].sectionKey === sectionKey &&
            kdPinnedViews[i].prefix === prefix &&
            kdPinnedViews[i].component === component) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle('kd-pin-btn-active', isPinned);
    });
  }

  /**
   * Export all pinned views as PNG slides.
   */
  window.kdExportAllPinnedPNG = function() {
    var pins = kdPinnedViews.filter(function(p) { return p.type !== 'section'; });
    if (pins.length === 0) return;
    pins.forEach(function(pin, idx) {
      setTimeout(function() {
        kdExportPinnedCardPNG(pin.id);
      }, idx * 500);
    });
  };

  /**
   * Print pinned views to PDF via window.print() overlay.
   * Builds a temporary print layout: one pin per page, section dividers as
   * heading strips. User saves to PDF from the print dialog.
   */
  window.kdPrintPinnedViews = function() {
    var pinCount = countPins();
    if (pinCount === 0) return;

    // Create print overlay
    var overlay = document.createElement('div');
    overlay.id = 'kd-pinned-print-overlay';
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:white;overflow:auto;';

    // Print styles
    var printStyle = document.createElement('style');
    printStyle.id = 'kd-pinned-print-style';
    printStyle.textContent =
      '@page { size: A4 landscape; margin: 10mm 12mm; } ' +
      '@media print { ' +
      'body > *:not(#kd-pinned-print-overlay) { display: none !important; } ' +
      '#kd-pinned-print-overlay { position: static !important; overflow: visible !important; } ' +
      '.kd-print-page { page-break-after: always; padding: 12px 0; box-sizing: border-box; } ' +
      '.kd-print-page:last-child { page-break-after: auto; } ' +
      '.kd-print-header { margin-bottom: 10px; } ' +
      '.kd-print-panel-label { font-size: 13px; font-weight: 700; color: #323367; text-transform: uppercase; letter-spacing: 0.3px; } ' +
      '.kd-print-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 2px 0; } ' +
      '.kd-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid #323367; ' +
      '  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; ' +
      '  color: #1a2744; line-height: 1.5; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.kd-print-chart { margin-bottom: 12px; } ' +
      '.kd-print-chart svg { width: 100%; height: auto; } ' +
      '.kd-print-table { overflow: visible; } ' +
      '.kd-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } ' +
      '.kd-print-table th, .kd-print-table td { padding: 4px 8px; border: 1px solid #ddd; text-align: left; word-wrap: break-word; } ' +
      '.kd-print-table th { background: #f1f5f9; font-weight: 600; font-size: 12px; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.kd-print-page-num { text-align: right; font-size: 9px; color: #94a3b8; margin-top: 4px; } ' +
      '.kd-print-project-strip { padding: 0 0 8px 0; margin-bottom: 12px; border-bottom: 2px solid #323367; -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.kd-print-section-strip { padding: 16px 0 8px; margin: 8px 0; border-bottom: 2px solid #323367; font-size: 16px; font-weight: 600; color: #323367; } ' +
      '} ' +
      // Screen preview
      '#kd-pinned-print-overlay { padding: 32px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; } ' +
      '.kd-print-page { border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; margin-bottom: 16px; background: white; } ' +
      '.kd-print-close-btn { position: fixed; top: 16px; right: 16px; z-index: 100000; padding: 8px 20px; background: #323367; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }';
    document.head.appendChild(printStyle);

    // Close button (visible on screen, hidden in print)
    var closeBtn = document.createElement('button');
    closeBtn.className = 'kd-print-close-btn';
    closeBtn.textContent = 'Close Preview';
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    // Project header strip
    var projTitle = document.querySelector('.kd-header-title, .kd-comp-title');
    var pTitle = projTitle ? projTitle.textContent.trim() : 'Key Driver Report';
    var projStrip = document.createElement('div');
    projStrip.className = 'kd-print-project-strip';
    projStrip.innerHTML = '<div style="font-size:14px;font-weight:700;color:#323367;">' + kdEscapeHtml(pTitle) + '</div>' +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Key Driver &bull; ' + new Date().toLocaleDateString() + '</div>';
    overlay.appendChild(projStrip);

    // Build pages
    var printPinIdx = 0;
    kdPinnedViews.forEach(function(item) {
      if (item.type === 'section') {
        var sectionEl = document.createElement('div');
        sectionEl.className = 'kd-print-section-strip';
        sectionEl.textContent = item.title || 'Untitled Section';
        overlay.appendChild(sectionEl);
        return;
      }

      printPinIdx++;
      var page = document.createElement('div');
      page.className = 'kd-print-page';

      // Header
      var hdr = document.createElement('div');
      hdr.className = 'kd-print-header';
      hdr.innerHTML = (item.panelLabel ? '<div class="kd-print-panel-label">' + kdEscapeHtml(item.panelLabel) + '</div>' : '') +
        '<div class="kd-print-title">' + kdEscapeHtml(item.sectionTitle) + '</div>';
      page.appendChild(hdr);

      // Insight
      if (item.insightText) {
        var insDiv = document.createElement('div');
        insDiv.className = 'kd-print-insight';
        insDiv.textContent = item.insightText;
        page.appendChild(insDiv);
      }

      // Chart
      if (item.chartSvg) {
        var chartDiv = document.createElement('div');
        chartDiv.className = 'kd-print-chart';
        chartDiv.innerHTML = item.chartSvg;
        page.appendChild(chartDiv);
      }

      // Table
      if (item.tableHtml) {
        var tableDiv = document.createElement('div');
        tableDiv.className = 'kd-print-table';
        tableDiv.innerHTML = item.tableHtml;
        page.appendChild(tableDiv);
      }

      // Page number
      var pgNum = document.createElement('div');
      pgNum.className = 'kd-print-page-num';
      pgNum.textContent = printPinIdx + ' of ' + pinCount;
      page.appendChild(pgNum);

      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    function cleanupPrintOverlay() {
      var ov = document.getElementById('kd-pinned-print-overlay');
      if (ov) ov.remove();
      var ps = document.getElementById('kd-pinned-print-style');
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
  window.kdSavePinnedData = function() {
    var store = document.getElementById('kd-pinned-views-data');
    if (store) {
      store.textContent = JSON.stringify(kdPinnedViews);
    }
  };

  /**
   * Hydrate pinned views from hidden data store (call on page load).
   */
  window.kdHydratePinnedViews = function() {
    var store = document.getElementById('kd-pinned-views-data');
    if (!store || !store.textContent.trim()) return;
    try {
      var data = JSON.parse(store.textContent);
      if (Array.isArray(data) && data.length > 0) {
        kdPinnedViews = data;
        kdRenderPinnedCards();
        kdUpdatePinBadge();
        kdUpdatePinButtons();
      }
    } catch (e) {
      // Ignore parse errors
    }
  };

})();
