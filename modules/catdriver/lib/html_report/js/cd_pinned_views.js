/* ==============================================================================
 * CATDRIVER HTML REPORT - PINNED VIEWS
 * ==============================================================================
 * Pin sections to a dedicated Pinned Views panel. Each pin captures:
 * section title, analysis label, insight text, chart SVG, table HTML.
 * Pins can be exported as PNG slides or collected for presentation.
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // In-memory array of pinned views
  var cdPinnedViews = [];

  /**
   * Get the current pinned views array.
   * @returns {Array}
   */
  window.cdGetPinnedViews = function() {
    return cdPinnedViews;
  };

  /**
   * Pin a section from an analysis panel.
   * @param {string} sectionKey - Section key (e.g., 'importance')
   * @param {string} prefix - ID prefix (e.g., 'nps-')
   */
  window.cdPinSection = function(sectionKey, prefix) {
    prefix = prefix || '';
    var content = cdCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    // Check for duplicate
    for (var i = 0; i < cdPinnedViews.length; i++) {
      if (cdPinnedViews[i].sectionKey === sectionKey &&
          cdPinnedViews[i].prefix === prefix) {
        // Already pinned — remove it (toggle behaviour)
        cdPinnedViews.splice(i, 1);
        cdRenderPinnedCards();
        cdUpdatePinBadge();
        cdUpdatePinButtons();
        return;
      }
    }

    var pin = {
      id: 'pin-' + Date.now() + '-' + Math.random().toString(36).substr(2, 6),
      sectionKey: sectionKey,
      prefix: prefix,
      panelLabel: content.panelLabel,
      sectionTitle: content.sectionTitle,
      insightText: content.insightText,
      chartSvg: content.chartSvg,
      tableHtml: content.tableHtml,
      timestamp: new Date().toISOString(),
      // Metadata for export
      modelType: content.modelType,
      sampleN: content.sampleN,
      r2Text: content.r2Text
    };

    cdPinnedViews.push(pin);
    cdRenderPinnedCards();
    cdUpdatePinBadge();
    cdUpdatePinButtons();
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

    // Panel label (analysis name)
    var panelLabel = '';
    var panel = section.closest('.cd-analysis-panel');
    if (panel) {
      var heading = panel.querySelector('.cd-panel-heading-title');
      panelLabel = heading ? heading.textContent.trim() : '';
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

    // Chart SVG (first SVG in section)
    var chartSvg = '';
    var svgEl = section.querySelector('svg.cd-chart');
    if (svgEl) {
      chartSvg = svgEl.outerHTML;
    }

    // Table HTML (first cd-table in section, skip if patterns section — too many tables)
    var tableHtml = '';
    if (sectionKey !== 'patterns') {
      var tableEl = section.querySelector('table.cd-table');
      if (tableEl) {
        tableHtml = tableEl.outerHTML;
      }
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

    var html = '';
    cdPinnedViews.forEach(function(pin, idx) {
      var labelTag = pin.panelLabel
        ? '<span class="cd-pinned-card-label">' + cdEscapeHtml(pin.panelLabel) + '</span>'
        : '';

      var insightBlock = pin.insightText
        ? '<div class="cd-pinned-card-insight">' + cdEscapeHtml(pin.insightText) + '</div>'
        : '';

      var chartBlock = pin.chartSvg
        ? '<div class="cd-pinned-card-chart">' + pin.chartSvg + '</div>'
        : '';

      html += '<div class="cd-pinned-card" data-pin-id="' + pin.id + '">'
        + '<div class="cd-pinned-card-header">'
        + '<div class="cd-pinned-card-title">'
        + labelTag
        + '<span class="cd-pinned-card-section">' + cdEscapeHtml(pin.sectionTitle) + '</span>'
        + '</div>'
        + '<div class="cd-pinned-card-actions">';

      // Move buttons
      if (idx > 0) {
        html += '<button class="cd-pinned-action-btn" onclick="cdMovePinned(\'' + pin.id + '\', -1)" title="Move up">\u25B2</button>';
      }
      if (idx < cdPinnedViews.length - 1) {
        html += '<button class="cd-pinned-action-btn" onclick="cdMovePinned(\'' + pin.id + '\', 1)" title="Move down">\u25BC</button>';
      }

      html += '<button class="cd-pinned-action-btn cd-pinned-export-btn" onclick="cdExportPinnedCardPNG(\'' + pin.id + '\')" title="Export as PNG">\uD83D\uDCE5</button>'
        + '<button class="cd-pinned-action-btn cd-pinned-remove-btn" onclick="cdRemovePinned(\'' + pin.id + '\')" title="Remove pin">\u2715</button>'
        + '</div></div>'
        + insightBlock
        + chartBlock
        + '</div>';
    });

    container.innerHTML = html;
  };

  /**
   * Remove a pinned view by ID.
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
   */
  window.cdUpdatePinBadge = function() {
    var badge = document.getElementById('cd-pin-count-badge');
    if (badge) {
      badge.textContent = cdPinnedViews.length;
      badge.style.display = cdPinnedViews.length > 0 ? 'inline-flex' : 'none';
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
        if (cdPinnedViews[i].sectionKey === sectionKey &&
            cdPinnedViews[i].prefix === prefix) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle('cd-pin-btn-active', isPinned);
      btn.title = isPinned ? 'Unpin this section' : 'Pin this section';
    });
  }

  /**
   * Export all pinned views as PNG slides.
   */
  window.cdExportAllPinnedPNG = function() {
    if (cdPinnedViews.length === 0) return;
    cdPinnedViews.forEach(function(pin, idx) {
      setTimeout(function() {
        cdExportPinnedCardPNG(pin.id);
      }, idx * 500); // Stagger exports to avoid overwhelming browser
    });
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
