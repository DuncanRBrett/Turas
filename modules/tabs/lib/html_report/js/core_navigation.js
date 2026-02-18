// Banner group codes
var bannerGroups = BANNER_GROUPS_JSON;
var currentGroup = bannerGroups[0] || "";
var heatmapEnabled = true;
var hiddenColumns = {};
var sortState = {};
var originalRowOrder = {};

// Question navigation
function selectQuestion(index) {
  document.querySelectorAll(".question-container").forEach(function(el) {
    el.classList.remove("active");
  });
  var container = document.getElementById("q-container-" + index);
  if (container) container.classList.add("active");

  document.querySelectorAll(".question-item").forEach(function(el) {
    el.classList.toggle("active", parseInt(el.getAttribute("data-index")) === index);
  });
}

// Search filter
function filterQuestions(term) {
  var lower = term.toLowerCase();
  document.querySelectorAll(".question-item").forEach(function(el) {
    var searchText = el.getAttribute("data-search") || "";
    el.style.display = searchText.indexOf(lower) >= 0 ? "" : "none";
  });
}

// Banner group switching
function switchBannerGroup(groupCode, btn) {
  // Save all current insight editor text under the OLD banner before switching
  var oldBannerName = getActiveBannerName();
  document.querySelectorAll(".insight-area").forEach(function(area) {
    var editor = area.querySelector(".insight-editor");
    if (!editor) return;
    var text = editor.textContent.trim();
    var storeObj = getInsightStore(area);
    if (text) {
      storeObj[oldBannerName] = text;
    } else {
      delete storeObj[oldBannerName];
    }
    setInsightStore(area, storeObj);
  });

  currentGroup = groupCode;

  // Update tab buttons
  var activeName = "";
  document.querySelectorAll(".banner-tab").forEach(function(el) {
    var isActive = el.getAttribute("data-group") === groupCode;
    el.classList.toggle("active", isActive);
    if (isActive) activeName = el.getAttribute("data-banner-name") || el.textContent;
  });

  // Update banner name labels under each question title
  if (activeName) {
    document.querySelectorAll(".banner-name-label").forEach(function(el) {
      el.textContent = activeName;
    });
  }

  // Show/hide columns by banner group CSS class
  // Total columns (bg-total) are always visible
  bannerGroups.forEach(function(code) {
    var cols = document.querySelectorAll(".bg-" + code);
    cols.forEach(function(col) {
      col.style.display = (code === groupCode) ? "" : "none";
    });
  });

  // Reset sort and row exclusions when switching banner groups
  sortState = {};
  excludedRows = {};
  if (window._chartExclusions) window._chartExclusions = {};
  document.querySelectorAll(".ct-row-excluded").forEach(function(row) {
    row.classList.remove("ct-row-excluded");
    var btn = row.querySelector(".row-exclude-btn");
    if (btn) btn.textContent = "\u2715";
  });
  document.querySelectorAll(".ct-sort-indicator").forEach(function(ind) {
    ind.textContent = " \u21C5";
    ind.classList.remove("ct-sort-active");
  });
  Object.keys(originalRowOrder).forEach(function(tableId) {
    var table = document.getElementById(tableId);
    if (!table) return;
    var tbody = table.querySelector("tbody");
    if (!tbody) return;
    originalRowOrder[tableId].forEach(function(row) {
      tbody.appendChild(row);
    });
    sortChartBars(table, null);
  });

  // Build column toggle chips for this group
  buildColumnChips(groupCode);

  // Rebuild chart column pickers for new banner group
  buildChartPickersForGroup(groupCode);

  // Update insight text for new banner group
  updateInsightsForBanner(activeName);

  // Re-apply hidden columns for this group
  if (hiddenColumns[groupCode]) {
    Object.keys(hiddenColumns[groupCode]).forEach(function(colKey) {
      document.querySelectorAll("th[data-col-key=\"" + colKey + "\"], td[data-col-key=\"" + colKey + "\"]").forEach(function(el) {
        el.style.display = "none";
      });
    });
  }
}

// Heatmap toggle - reads data-heatmap attribute from cells
function toggleHeatmap(enabled) {
  heatmapEnabled = enabled;
  document.querySelectorAll(".ct-heatmap-cell").forEach(function(td) {
    if (enabled) {
      var colour = td.getAttribute("data-heatmap");
      if (colour) td.style.backgroundColor = colour;
    } else {
      td.style.backgroundColor = "";
    }
  });
}

// Frequency toggle
function toggleFrequency(enabled) {
  var main = document.getElementById("main-content");
  if (enabled) {
    main.classList.add("show-freq");
  } else {
    main.classList.remove("show-freq");
  }
}

// ---- HELP OVERLAY ----
function toggleHelpOverlay() {
  var overlay = document.getElementById("help-overlay");
  if (!overlay) return;
  overlay.classList.toggle("active");
  if (!overlay.classList.contains("active")) {
    try { localStorage.setItem("turas-help-seen", "1"); } catch(e) {}
  }
}

// ---- PRINT REPORT ----
// Shows all questions for the active banner and triggers browser print
function printReport() {
  // Remember which question was active
  var activeContainer = document.querySelector(".question-container.active");
  var activeIndex = activeContainer ? activeContainer.id.replace("q-container-", "") : "0";

  // Show all question containers for print
  var allContainers = document.querySelectorAll(".question-container");
  allContainers.forEach(function(el) {
    el.classList.add("active");
    el.style.display = "block";
  });

  // Show charts if they have content — capture current state first for restore
  var chartStates = [];
  document.querySelectorAll(".chart-wrapper").forEach(function(div) {
    chartStates.push({ el: div, was: div.style.display });
    if (div.querySelector("svg")) {
      div.style.display = "block";
    }
  });

  // Show insights that have content
  var insightStates = [];
  document.querySelectorAll(".insight-container").forEach(function(container) {
    var editor = container.querySelector(".insight-editor");
    var hadContent = editor && editor.textContent.trim() !== "";
    insightStates.push({ el: container, was: container.style.display });
    if (hadContent) container.style.display = "block";
  });

  // Trigger print
  window.print();

  // Restore original state after print dialog closes
  allContainers.forEach(function(el) {
    el.classList.remove("active");
    el.style.display = "";
  });
  var restoreEl = document.getElementById("q-container-" + activeIndex);
  if (restoreEl) restoreEl.classList.add("active");

  // Restore chart visibility to pre-print state
  chartStates.forEach(function(state) {
    state.el.style.display = state.was;
  });

  // Restore insight visibility
  insightStates.forEach(function(state) {
    state.el.style.display = state.was;
  });
}

// Chart toggle
function toggleChart(enabled) {
  document.querySelectorAll(".chart-wrapper").forEach(function(div) {
    div.style.display = enabled ? "block" : "none";
  });
  document.querySelectorAll(".export-chart-btn").forEach(function(btn) {
    btn.style.display = enabled ? "inline-block" : "none";
  });
  document.querySelectorAll(".slide-export-group").forEach(function(grp) {
    grp.style.display = enabled ? "inline-block" : "none";
  });
}

// ---- Utility: extract label text from a td, ignoring button elements ----
function getLabelText(cell) {
  var clone = cell.cloneNode(true);
  var btns = clone.querySelectorAll(".row-exclude-btn");
  btns.forEach(function(b) { b.remove(); });
  return clone.textContent.trim();
}

// ---- Row Exclusion from Chart ----
var excludedRows = {};  // keyed by tableId -> Set of labels

function toggleRowExclusion(row) {
  var table = row.closest("table.ct-table");
  if (!table) return;
  var tableId = table.id;
  if (!excludedRows[tableId]) excludedRows[tableId] = {};
  var labelCell = row.querySelector("td.ct-label-col");
  if (!labelCell) return;
  var label = getLabelText(labelCell);
  var isExcluded = row.classList.toggle("ct-row-excluded");
  if (isExcluded) {
    excludedRows[tableId][label] = true;
  } else {
    delete excludedRows[tableId][label];
  }
  // Update button icon
  var btn = row.querySelector(".row-exclude-btn");
  if (btn) btn.textContent = isExcluded ? "\u25CB" : "\u2715";
  // Rebuild chart with exclusions applied
  var container = table.closest(".question-container");
  if (container) {
    var wrapper = container.querySelector(".chart-wrapper[data-q-code]");
    if (wrapper) {
      var qCode = wrapper.getAttribute("data-q-code");
      rebuildChartWithExclusions(qCode, excludedRows[tableId]);
    }
  }
}

function rebuildChartWithExclusions(qCode, excluded) {
  if (typeof rebuildChartSVG === "function") {
    // Store exclusions so rebuildChartSVG can read them
    if (!window._chartExclusions) window._chartExclusions = {};
    window._chartExclusions[qCode] = excluded || {};
    rebuildChartSVG(qCode);
  }
}

// ---- Key Insight (per-banner) ----
// Each question stores insights as JSON: { "bannerName": "text", ... }
// in the hidden textarea.insight-store. This allows separate insights
// per banner group on the same question.

// Get the display name of the currently active banner group
function getActiveBannerName() {
  var activeTab = document.querySelector(".banner-tab.active");
  if (activeTab) return activeTab.getAttribute("data-banner-name") || activeTab.textContent.trim();
  return "_default";
}

// Read the per-banner JSON store for a question
function getInsightStore(area) {
  var store = area.querySelector("textarea.insight-store");
  if (!store || !store.value || !store.value.trim()) return {};
  try {
    var parsed = JSON.parse(store.value);
    // Handle legacy plain-text stores (upgrade to per-banner format)
    if (typeof parsed === "string") {
      var legacy = {};
      legacy[getActiveBannerName()] = parsed;
      return legacy;
    }
    return parsed;
  } catch(e) {
    // Legacy plain text — wrap under current banner
    if (store.value.trim()) {
      var legacy = {};
      legacy[getActiveBannerName()] = store.value.trim();
      return legacy;
    }
    return {};
  }
}

// Write the per-banner JSON store for a question
function setInsightStore(area, obj) {
  var store = area.querySelector("textarea.insight-store");
  if (!store) return;
  // Remove empty entries
  var clean = {};
  for (var k in obj) {
    if (obj.hasOwnProperty(k) && obj[k] && obj[k].trim()) {
      clean[k] = obj[k].trim();
    }
  }
  store.value = Object.keys(clean).length > 0 ? JSON.stringify(clean) : "";
}

function toggleInsight(qCode) {
  var area = document.querySelector(".insight-area[data-q-code=\"" + qCode + "\"]");
  if (!area) return;
  var container = area.querySelector(".insight-container");
  var btn = area.querySelector(".insight-toggle");
  if (!container) return;
  var isHidden = container.style.display === "none";
  container.style.display = isHidden ? "block" : "none";
  if (btn) {
    btn.style.display = isHidden ? "none" : "block";
  }
  if (isHidden) {
    var editor = container.querySelector(".insight-editor");
    if (editor) editor.focus();
  }
}

function dismissInsight(qCode) {
  var area = document.querySelector(".insight-area[data-q-code=\"" + qCode + "\"]");
  if (!area) return;
  var container = area.querySelector(".insight-container");
  var btn = area.querySelector(".insight-toggle");
  var editor = area.querySelector(".insight-editor");
  // Clear content for current banner and hide
  if (editor) editor.innerHTML = "";
  if (container) container.style.display = "none";
  if (btn) {
    btn.style.display = "block";
    btn.textContent = "+ Add Insight";
  }
  // Remove this banner entry from the store
  syncInsight(qCode);
}

// Sync insight editor text into hidden store under the current banner key
function syncInsight(qCode) {
  var area = document.querySelector(".insight-area[data-q-code=\"" + qCode + "\"]");
  if (!area) return;
  var editor = area.querySelector(".insight-editor");
  if (!editor) return;
  var bannerName = getActiveBannerName();
  var storeObj = getInsightStore(area);
  var text = editor.textContent.trim();
  if (text) {
    storeObj[bannerName] = text;
  } else {
    delete storeObj[bannerName];
  }
  setInsightStore(area, storeObj);
}

// Sync ALL insights into their hidden stores (called before save)
function syncAllInsights() {
  document.querySelectorAll(".insight-area").forEach(function(area) {
    var editor = area.querySelector(".insight-editor");
    if (!editor) return;
    var qCode = area.getAttribute("data-q-code");
    if (qCode) syncInsight(qCode);
  });
}

// Save the entire HTML report (with insights embedded) as a standalone file
function saveReportHTML() {
  syncAllInsights();

  // Before serializing, clear editor contenteditable (data lives in textarea store)
  // The hydrate function will restore editors from stores on re-open
  document.querySelectorAll(".insight-area").forEach(function(area) {
    var store = area.querySelector("textarea.insight-store");
    var editor = area.querySelector(".insight-editor");
    var container = area.querySelector(".insight-container");
    var btn = area.querySelector(".insight-toggle");
    var storeObj = getInsightStore(area);
    var hasAny = Object.keys(storeObj).length > 0;
    // Show the insight container if any banner has content
    if (hasAny) {
      var bannerName = getActiveBannerName();
      var currentText = storeObj[bannerName] || "";
      if (editor) editor.textContent = currentText;
      if (container) container.style.display = currentText ? "block" : "none";
      if (btn) btn.style.display = currentText ? "none" : "block";
    } else {
      if (editor) editor.innerHTML = "";
      if (container) container.style.display = "none";
      if (btn) { btn.style.display = "block"; btn.textContent = "+ Add Insight"; }
    }
  });

  // Clean DOM to prevent bloat on repeated save-open-save cycles
  // Remove elements that get rebuilt on DOMContentLoaded
  var removedPickers = [];
  document.querySelectorAll(".chart-col-picker").forEach(function(el) {
    removedPickers.push({ parent: el.parentNode, next: el.nextSibling, el: el });
    el.remove();
  });
  var removedIndicators = [];
  document.querySelectorAll(".ct-sort-indicator").forEach(function(el) {
    removedIndicators.push({ parent: el.parentNode, el: el });
    el.remove();
  });

  // Serialize the full page
  var html = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;
  var blob = new Blob([html], { type: "text/html;charset=utf-8" });
  var title = document.querySelector(".header-title");
  var fname = title ? title.textContent.replace(/[^a-zA-Z0-9 ]/g, "").replace(/\s+/g, "_") : "";
  if (!fname) fname = "Report";
  downloadBlob(blob, fname + "_with_insights.html");

  // Restore DOM elements for continued use
  removedPickers.forEach(function(item) {
    if (item.next) {
      item.parent.insertBefore(item.el, item.next);
    } else {
      item.parent.appendChild(item.el);
    }
  });
  removedIndicators.forEach(function(item) {
    item.parent.appendChild(item.el);
  });
}

// Hydrate insight editors from hidden textareas (when opening a saved HTML)
function hydrateInsights() {
  var bannerName = getActiveBannerName();
  document.querySelectorAll(".insight-area").forEach(function(area) {
    var storeObj = getInsightStore(area);
    if (Object.keys(storeObj).length === 0) return;
    var text = storeObj[bannerName] || "";
    var editor = area.querySelector(".insight-editor");
    var container = area.querySelector(".insight-container");
    var btn = area.querySelector(".insight-toggle");
    if (text && editor) {
      editor.textContent = text;
      if (container) container.style.display = "block";
      if (btn) btn.style.display = "none";
    }
  });
}

// Update insight editors when banner group changes
// Note: saving under the old banner is done in switchBannerGroup BEFORE
// the active tab changes, so here we only need to load the new banner text.
function updateInsightsForBanner(bannerName) {
  document.querySelectorAll(".insight-area").forEach(function(area) {
    var storeObj = getInsightStore(area);
    // Also merge in config-provided comments if store has no entry for this banner
    var scriptEl = area.querySelector("script.insight-comments-data");
    if (scriptEl && !storeObj[bannerName]) {
      try {
        var comments = JSON.parse(scriptEl.textContent);
        if (comments && comments.length) {
          for (var i = 0; i < comments.length; i++) {
            if (comments[i].banner && comments[i].banner === bannerName) {
              storeObj[bannerName] = comments[i].text;
              break;
            }
          }
          if (!storeObj[bannerName]) {
            for (var i = 0; i < comments.length; i++) {
              if (!comments[i].banner) {
                storeObj[bannerName] = comments[i].text;
                break;
              }
            }
          }
        }
      } catch(e) { /* ignore parse errors */ }
    }

    var text = storeObj[bannerName] || "";
    var editor = area.querySelector(".insight-editor");
    var container = area.querySelector(".insight-container");
    var btn = area.querySelector(".insight-toggle");
    if (text) {
      if (editor) editor.textContent = text;
      if (container) container.style.display = "block";
      if (btn) btn.style.display = "none";
    } else {
      if (editor) editor.innerHTML = "";
      if (container) container.style.display = "none";
      if (btn) { btn.style.display = "block"; btn.textContent = "+ Add Insight"; }
    }
  });
}

