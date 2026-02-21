// ==============================================================================
// TurasTracker HTML Report - Pinned Views
// ==============================================================================
// Pin/unpin metric views, render pinned cards, persist JSON.
// Captures current view state: visible segments, chart, counts, change rows.
// ==============================================================================

var pinnedViews = [];

/**
 * Toggle pin on a metric (add or remove)
 * @param {string} metricId - The metric ID
 */
function togglePin(metricId) {
  var existingIdx = -1;
  for (var i = 0; i < pinnedViews.length; i++) {
    if (pinnedViews[i].metricId === metricId) {
      existingIdx = i;
      break;
    }
  }

  if (existingIdx >= 0) {
    // Unpin
    pinnedViews.splice(existingIdx, 1);
    updatePinButton(metricId, false);
  } else {
    // Pin — capture current view
    var pinObj = captureMetricView(metricId);
    if (pinObj) {
      pinnedViews.push(pinObj);
      updatePinButton(metricId, true);
    }
  }

  renderPinnedCards();
  updatePinBadge();
  savePinnedData();
}

/**
 * Capture current view state for a metric.
 * Filters out hidden segments from the table HTML.
 * Captures chart SVG only if chart is currently visible.
 * Records display state: show-freq (counts), vs-prev/vs-base row visibility.
 * @param {string} metricId - The metric ID
 * @returns {Object|null} Pin object
 */
function captureMetricView(metricId) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return null;

  var titleEl = panel.querySelector(".mv-metric-title");
  var tableArea = panel.querySelector(".mv-table-area");
  var chartArea = panel.querySelector(".mv-chart-area");
  var insightEditor = panel.querySelector(".insight-editor");

  // Get visible segments
  var visibleSegments = [];
  panel.querySelectorAll(".tk-segment-chip.active").forEach(function(chip) {
    visibleSegments.push(chip.getAttribute("data-segment"));
  });

  // ---- Build clean table HTML (only visible segments) ----
  var cleanTableHtml = "";
  if (tableArea) {
    var tableClone = tableArea.cloneNode(true);

    // Remove hidden segment rows
    tableClone.querySelectorAll("tr.segment-hidden").forEach(function(row) {
      row.parentNode.removeChild(row);
    });

    // Remove hidden wave columns
    tableClone.querySelectorAll(".wave-hidden").forEach(function(el) {
      el.parentNode.removeChild(el);
    });

    // Determine display state from panel
    var showFreq = panel.classList.contains("show-freq");
    var vsPrevVisible = false;
    var vsBaseVisible = false;

    // Check if vs-prev / vs-base rows are toggled visible
    var prevRows = panel.querySelectorAll(".tk-change-row.tk-vs-prev.visible");
    var baseRows = panel.querySelectorAll(".tk-change-row.tk-vs-base.visible");
    vsPrevVisible = prevRows.length > 0;
    vsBaseVisible = baseRows.length > 0;

    // In the clone: make freq visible if show-freq is on
    if (showFreq) {
      tableClone.querySelectorAll(".tk-freq").forEach(function(el) {
        el.style.display = "block";
      });
    }

    // In the clone: make vs-prev rows visible if toggled on
    if (vsPrevVisible) {
      tableClone.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) {
        row.style.display = "table-row";
      });
    } else {
      // Remove vs-prev rows from clone if not visible
      tableClone.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) {
        row.parentNode.removeChild(row);
      });
    }

    // In the clone: make vs-base rows visible if toggled on
    if (vsBaseVisible) {
      tableClone.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) {
        row.style.display = "table-row";
      });
    } else {
      // Remove vs-base rows from clone if not visible
      tableClone.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) {
        row.parentNode.removeChild(row);
      });
    }

    cleanTableHtml = tableClone.innerHTML;
  }

  // ---- Chart SVG: only capture if chart is currently displayed ----
  var chartSvg = "";
  var chartVisible = false;
  if (chartArea && chartArea.style.display !== "none") {
    chartVisible = true;
    // Clone chart and remove hidden elements
    var chartClone = chartArea.cloneNode(true);
    chartClone.querySelectorAll("[data-segment]").forEach(function(el) {
      if (el.style.display === "none") {
        el.parentNode.removeChild(el);
      }
    });
    chartClone.querySelectorAll("[data-wave]").forEach(function(el) {
      if (el.style.display === "none") {
        el.parentNode.removeChild(el);
      }
    });
    chartSvg = chartClone.innerHTML;
  }

  return {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    metricId: metricId,
    metricTitle: titleEl ? titleEl.textContent : metricId,
    visibleSegments: visibleSegments,
    tableHtml: cleanTableHtml,
    chartSvg: chartSvg,
    chartVisible: chartVisible,
    insightText: insightEditor ? insightEditor.innerHTML : "",
    timestamp: Date.now(),
    order: pinnedViews.length
  };
}

/**
 * Update pin button visual state
 * @param {string} metricId - The metric ID
 * @param {boolean} isPinned - Whether it's pinned
 */
function updatePinButton(metricId, isPinned) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var btn = panel.querySelector(".mv-pin-btn");
  if (btn) {
    btn.classList.toggle("pinned", isPinned);
    btn.title = isPinned ? "Unpin this view" : "Pin this view";
  }
}

/**
 * Render all pinned cards in the pinned tab.
 * Each card shows: header, chart (if captured), table, insight, meta.
 */
function renderPinnedCards() {
  var container = document.getElementById("pinned-cards-container");
  var emptyState = document.getElementById("pinned-empty-state");
  if (!container) return;

  if (pinnedViews.length === 0) {
    container.innerHTML = "";
    if (emptyState) emptyState.style.display = "block";
    return;
  }

  if (emptyState) emptyState.style.display = "none";

  var html = "";
  for (var i = 0; i < pinnedViews.length; i++) {
    var pin = pinnedViews[i];
    html += "<div class=\"pinned-card\" data-pin-id=\"" + pin.id + "\">";

    // Header
    html += "<div class=\"pinned-card-header\">";
    html += "<h3 class=\"pinned-card-title\">" + escapeHtml(pin.metricTitle) + "</h3>";
    html += "<div class=\"pinned-card-actions\">";
    if (i > 0) {
      html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"movePinned(" + i + "," + (i - 1) + ")\" title=\"Move up\">\u2191</button>";
    }
    if (i < pinnedViews.length - 1) {
      html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"movePinned(" + i + "," + (i + 1) + ")\" title=\"Move down\">\u2193</button>";
    }
    html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"removePinned('" + pin.id + "','" + pin.metricId + "')\" title=\"Remove pin\">\u00d7</button>";
    html += "</div></div>";

    // Chart (if captured and was visible)
    if (pin.chartSvg && pin.chartVisible !== false) {
      html += "<div class=\"pinned-card-chart\">" + pin.chartSvg + "</div>";
    }

    // Table
    html += "<div class=\"pinned-card-body\">" + pin.tableHtml + "</div>";

    // Insight
    if (pin.insightText) {
      html += "<div class=\"pinned-card-insight\">" + pin.insightText + "</div>";
    }

    // Meta
    html += "<div class=\"pinned-card-meta\">" + new Date(pin.timestamp).toLocaleString() + "</div>";
    html += "</div>";
  }

  container.innerHTML = html;
}

/**
 * Move a pinned view from one position to another
 * @param {number} fromIdx - Source index
 * @param {number} toIdx - Destination index
 */
function movePinned(fromIdx, toIdx) {
  if (fromIdx < 0 || toIdx < 0 || fromIdx >= pinnedViews.length || toIdx >= pinnedViews.length) return;
  var item = pinnedViews.splice(fromIdx, 1)[0];
  pinnedViews.splice(toIdx, 0, item);
  renderPinnedCards();
  savePinnedData();
}

/**
 * Remove a pinned view
 * @param {string} pinId - The pin ID
 * @param {string} metricId - The metric ID
 */
function removePinned(pinId, metricId) {
  pinnedViews = pinnedViews.filter(function(p) { return p.id !== pinId; });
  updatePinButton(metricId, false);
  renderPinnedCards();
  updatePinBadge();
  savePinnedData();
}

/**
 * Update the pin count badge on the Pinned Views tab
 */
function updatePinBadge() {
  var badge = document.getElementById("pin-count-badge");
  if (badge) {
    badge.textContent = pinnedViews.length;
    badge.style.display = pinnedViews.length > 0 ? "inline-block" : "none";
  }
}

/**
 * Save pinned data to JSON script tag
 */
function savePinnedData() {
  var store = document.getElementById("pinned-views-data");
  if (store) {
    store.textContent = JSON.stringify(pinnedViews);
  }
}

/**
 * Hydrate pinned views from JSON on page load
 */
function hydratePinnedViews() {
  var store = document.getElementById("pinned-views-data");
  if (store) {
    try {
      pinnedViews = JSON.parse(store.textContent || "[]");
      renderPinnedCards();
      updatePinBadge();
      // Update pin buttons
      for (var i = 0; i < pinnedViews.length; i++) {
        updatePinButton(pinnedViews[i].metricId, true);
      }
    } catch (e) {
      pinnedViews = [];
    }
  }
}

/**
 * Escape HTML entities
 * @param {string} str
 * @returns {string}
 */
function escapeHtml(str) {
  var div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

document.addEventListener("DOMContentLoaded", function() {
  hydratePinnedViews();
});
