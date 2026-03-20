// ==============================================================================
// MAXDIFF HTML REPORT — INTERACTIVE JS MODULE
// ==============================================================================
// Handles: tab navigation, save report, pins, insights, table sorting,
//          show/hide utilities toggle, help overlay
// Self-contained — no external dependencies.
// ==============================================================================

(function() {
  "use strict";

  // --------------------------------------------------------------------------
  // GLOBALS
  // --------------------------------------------------------------------------
  var pinnedViews = [];
  var currentTab = "overview";

  // --------------------------------------------------------------------------
  // HELPERS
  // --------------------------------------------------------------------------
  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function escapeHtml(str) {
    if (!str) return "";
    return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function renderMarkdown(md) {
    if (!md) return "";
    var html = escapeHtml(md);
    html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    html = html.replace(/\*(.+?)\*/g, "<em>$1</em>");
    html = html.replace(/^## (.+)$/gm, "<h4>$1</h4>");
    html = html.replace(/^> (.+)$/gm, "<blockquote>$1</blockquote>");
    // Bullet lists
    var lines = html.split("\n");
    var out = [], inList = false;
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (/^- (.+)/.test(line)) {
        if (!inList) { out.push("<ul>"); inList = true; }
        out.push("<li>" + line.replace(/^- /, "") + "</li>");
      } else {
        if (inList) { out.push("</ul>"); inList = false; }
        if (line.trim()) out.push("<p>" + line + "</p>");
      }
    }
    if (inList) out.push("</ul>");
    return out.join("\n");
  }

  function stripMarkdown(md) {
    if (!md) return "";
    return md.replace(/\*\*(.+?)\*\*/g, "$1").replace(/\*(.+?)\*/g, "$1")
      .replace(/^## /gm, "").replace(/^> /gm, "").replace(/^- /gm, "\u2022 ");
  }

  function generateId() {
    return "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5);
  }

  // --------------------------------------------------------------------------
  // TAB NAVIGATION
  // --------------------------------------------------------------------------
  function switchTab(tabId) {
    currentTab = tabId;
    $$(".md-tab-btn").forEach(function(btn) {
      btn.classList.toggle("active", btn.getAttribute("data-tab") === tabId);
    });
    $$(".md-panel").forEach(function(panel) {
      panel.classList.toggle("active", panel.id === "panel-" + tabId);
    });
    // Resize simulator iframe if switching to it
    if (tabId === "simulator") {
      var iframe = $("#panel-simulator iframe");
      if (iframe && iframe.contentWindow) {
        try {
          iframe.style.height = (iframe.contentWindow.document.body.scrollHeight + 40) + "px";
        } catch(e) {}
      }
    }
  }

  function initTabs() {
    $$(".md-tab-btn").forEach(function(btn) {
      btn.addEventListener("click", function() {
        switchTab(this.getAttribute("data-tab"));
      });
    });
  }

  // --------------------------------------------------------------------------
  // TABLE SORTING
  // --------------------------------------------------------------------------
  function initTableSort() {
    $$(".md-th").forEach(function(th) {
      th.addEventListener("click", function() {
        var table = this.closest(".md-table");
        if (!table) return;
        var headerRow = this.parentElement;
        var headers = Array.prototype.slice.call(headerRow.children);
        var colIdx = headers.indexOf(this);
        if (colIdx < 0) return;

        var tbody = table.querySelector("tbody") || table;
        var rows = Array.prototype.slice.call(tbody.querySelectorAll("tr")).filter(function(r) {
          return r.querySelector("td") && !r.classList.contains("md-tr-section");
        });
        if (rows.length === 0) return;

        var currentDir = this.getAttribute("data-sort-dir");
        var newDir = (currentDir === "asc") ? "desc" : "asc";

        headers.forEach(function(h) {
          h.setAttribute("data-sort-dir", "");
          var arrow = h.querySelector(".sort-arrow");
          if (arrow) arrow.remove();
        });

        this.setAttribute("data-sort-dir", newDir);
        var arrowSpan = document.createElement("span");
        arrowSpan.className = "sort-arrow";
        arrowSpan.textContent = (newDir === "asc") ? " \u25B2" : " \u25BC";
        this.appendChild(arrowSpan);

        var isNumeric = rows.every(function(row) {
          var cell = row.children[colIdx];
          if (!cell) return false;
          var txt = cell.textContent.replace(/[,%$\s]/g, "").trim();
          return txt === "" || txt === "\u2014" || !isNaN(parseFloat(txt));
        });

        rows.sort(function(a, b) {
          var aVal = a.children[colIdx] ? a.children[colIdx].textContent.trim() : "";
          var bVal = b.children[colIdx] ? b.children[colIdx].textContent.trim() : "";
          if (isNumeric) {
            var aNum = parseFloat(aVal.replace(/[,%$\s]/g, "")) || 0;
            var bNum = parseFloat(bVal.replace(/[,%$\s]/g, "")) || 0;
            return (newDir === "asc") ? aNum - bNum : bNum - aNum;
          }
          var cmp = aVal.localeCompare(bVal);
          return (newDir === "asc") ? cmp : -cmp;
        });

        rows.forEach(function(row) { tbody.appendChild(row); });
      });
    });
  }

  // --------------------------------------------------------------------------
  // SHOW/HIDE UTILITY TOGGLE
  // --------------------------------------------------------------------------
  function initUtilityToggle() {
    var toggle = $("#md-utility-toggle");
    if (!toggle) return;
    toggle.addEventListener("click", function() {
      var showing = this.getAttribute("data-showing") === "shares";
      var newMode = showing ? "utilities" : "shares";
      this.setAttribute("data-showing", newMode);
      this.textContent = newMode === "shares" ? "Show Raw Utilities" : "Show Preference Shares";

      var sharesEl = $("#md-pref-shares-view");
      var utilsEl = $("#md-pref-utils-view");
      if (sharesEl) sharesEl.style.display = newMode === "shares" ? "block" : "none";
      if (utilsEl) utilsEl.style.display = newMode === "utilities" ? "block" : "none";
    });
  }

  // --------------------------------------------------------------------------
  // INSIGHTS
  // --------------------------------------------------------------------------
  function getInsightStore(area) {
    var store = area.querySelector(".insight-store");
    if (!store || !store.value || !store.value.trim()) return {};
    try { return JSON.parse(store.value); } catch(e) { return { "_default": store.value }; }
  }

  function setInsightStore(area, obj) {
    var store = area.querySelector(".insight-store");
    if (store) store.value = JSON.stringify(obj);
  }

  function toggleInsight(panelId) {
    var area = $(".insight-area[data-panel='" + panelId + "']");
    if (!area) return;
    var container = area.querySelector(".insight-container");
    var toggle = area.querySelector(".insight-toggle");
    if (!container) return;

    var isOpen = container.style.display !== "none";
    container.style.display = isOpen ? "none" : "block";
    if (toggle) toggle.textContent = isOpen ? "+ Add Insight" : "- Hide Insight";

    if (!isOpen) {
      var editor = area.querySelector(".insight-md-editor");
      if (editor) editor.focus();
    }
  }

  function toggleInsightEdit(panelId) {
    var area = $(".insight-area[data-panel='" + panelId + "']");
    if (!area) return;
    var editor = area.querySelector(".insight-md-editor");
    var rendered = area.querySelector(".insight-md-rendered");
    if (!editor || !rendered) return;

    var isEditing = editor.style.display !== "none";
    if (isEditing) {
      // Save and render
      rendered.innerHTML = renderMarkdown(editor.value);
      editor.style.display = "none";
      rendered.style.display = "block";
      syncInsight(panelId);
    } else {
      editor.style.display = "block";
      rendered.style.display = "none";
      editor.focus();
    }
  }

  function syncInsight(panelId) {
    var area = $(".insight-area[data-panel='" + panelId + "']");
    if (!area) return;
    var editor = area.querySelector(".insight-md-editor");
    if (!editor) return;
    var store = getInsightStore(area);
    store["_default"] = editor.value;
    setInsightStore(area, store);
  }

  function syncAllInsights() {
    $$(".insight-area").forEach(function(area) {
      var panelId = area.getAttribute("data-panel");
      var editor = area.querySelector(".insight-md-editor");
      if (editor && panelId) syncInsight(panelId);
    });
  }

  function dismissInsight(panelId) {
    var area = $(".insight-area[data-panel='" + panelId + "']");
    if (!area) return;
    var container = area.querySelector(".insight-container");
    var toggle = area.querySelector(".insight-toggle");
    if (container) container.style.display = "none";
    if (toggle) toggle.textContent = "+ Add Insight";
  }

  function hydrateInsights() {
    $$(".insight-area").forEach(function(area) {
      var panelId = area.getAttribute("data-panel");
      var store = getInsightStore(area);
      var text = store["_default"] || "";

      // Check config-provided insights
      if (!text) {
        var configData = area.querySelector(".insight-comments-data");
        if (configData) {
          try {
            var entries = JSON.parse(configData.textContent);
            if (entries && entries.length > 0) {
              text = entries[0].text || "";
            }
          } catch(e) {}
        }
      }

      if (text) {
        var editor = area.querySelector(".insight-md-editor");
        var rendered = area.querySelector(".insight-md-rendered");
        var container = area.querySelector(".insight-container");
        var toggle = area.querySelector(".insight-toggle");
        if (editor) editor.value = text;
        if (rendered) {
          rendered.innerHTML = renderMarkdown(text);
          rendered.style.display = "block";
          if (editor) editor.style.display = "none";
        }
        if (container) container.style.display = "block";
        if (toggle) toggle.textContent = "- Hide Insight";
      }
    });
  }

  // --------------------------------------------------------------------------
  // PINNED VIEWS
  // --------------------------------------------------------------------------
  function loadPinnedData() {
    var store = $("#pinned-views-data");
    if (!store) return;
    try { pinnedViews = JSON.parse(store.textContent) || []; } catch(e) { pinnedViews = []; }
  }

  function savePinnedData() {
    var store = $("#pinned-views-data");
    if (store) store.textContent = JSON.stringify(pinnedViews);
  }

  function updatePinBadge() {
    var badge = $("#pin-count-badge");
    if (!badge) return;
    var count = pinnedViews.length;
    badge.textContent = count;
    badge.style.display = count > 0 ? "inline-block" : "none";
  }

  function captureCurrentView(panelId) {
    var panel = $("#panel-" + panelId);
    if (!panel) return null;

    var title = "";
    var h2 = panel.querySelector("h2");
    if (h2) title = h2.textContent;

    // Capture chart SVG
    var chartSvg = "";
    var svgEl = panel.querySelector(".md-chart-container svg");
    if (svgEl) chartSvg = svgEl.outerHTML;

    // Capture table HTML
    var tableHtml = "";
    var tableEl = panel.querySelector(".md-table");
    if (tableEl) {
      var clone = tableEl.cloneNode(true);
      // Remove sort arrows from clone
      clone.querySelectorAll(".sort-arrow").forEach(function(a) { a.remove(); });
      tableHtml = clone.outerHTML;
    }

    // Capture insight text
    var insightText = "";
    var area = panel.querySelector(".insight-area");
    if (area) {
      var editor = area.querySelector(".insight-md-editor");
      if (editor) insightText = editor.value;
    }

    return {
      id: generateId(),
      panelId: panelId,
      title: title,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      insightText: insightText,
      timestamp: Date.now(),
      order: pinnedViews.length,
      pinMode: "all"
    };
  }

  function executePinWithMode(panelId, mode) {
    // Close popover
    $$(".pin-mode-popover").forEach(function(p) { p.style.display = "none"; });

    var view = captureCurrentView(panelId);
    if (!view) return;
    view.pinMode = mode;
    pinnedViews.push(view);
    savePinnedData();
    updatePinBadge();
    renderPinnedCards();

    // Flash pin button to confirm
    var btn = $(".pin-btn[data-panel='" + panelId + "']");
    if (btn) {
      btn.classList.add("pin-flash");
      setTimeout(function() { btn.classList.remove("pin-flash"); }, 600);
    }
  }

  function togglePin(panelId) {
    var btn = $(".pin-btn[data-panel='" + panelId + "']");
    if (!btn) return;
    var popover = btn.parentElement.querySelector(".pin-mode-popover");
    if (!popover) return;
    var isOpen = popover.style.display === "block";
    $$(".pin-mode-popover").forEach(function(p) { p.style.display = "none"; });
    popover.style.display = isOpen ? "none" : "block";
  }

  function removePinned(pinId) {
    pinnedViews = pinnedViews.filter(function(p) { return p.id !== pinId; });
    savePinnedData();
    updatePinBadge();
    renderPinnedCards();
  }

  function movePinned(fromIdx, toIdx) {
    if (toIdx < 0 || toIdx >= pinnedViews.length) return;
    var item = pinnedViews.splice(fromIdx, 1)[0];
    pinnedViews.splice(toIdx, 0, item);
    savePinnedData();
    renderPinnedCards();
  }

  function renderPinnedCards() {
    var container = $("#pinned-cards-container");
    var empty = $("#pinned-empty-state");
    if (!container) return;

    if (pinnedViews.length === 0) {
      container.innerHTML = "";
      if (empty) empty.style.display = "block";
      return;
    }
    if (empty) empty.style.display = "none";

    var html = "";
    for (var i = 0; i < pinnedViews.length; i++) {
      var pin = pinnedViews[i];
      var showChart = pin.pinMode === "all" || pin.pinMode === "chart_insight";
      var showTable = pin.pinMode === "all" || pin.pinMode === "table_insight";

      var chartBlock = "";
      if (showChart && pin.chartSvg) {
        chartBlock = '<div class="pinned-chart">' + pin.chartSvg + '</div>';
      }

      var tableBlock = "";
      if (showTable && pin.tableHtml) {
        tableBlock = '<div class="pinned-table">' + pin.tableHtml + '</div>';
      }

      var insightBlock = "";
      if (pin.insightText) {
        insightBlock = '<div class="pinned-insight">' + renderMarkdown(pin.insightText) + '</div>';
      }

      html += '<div class="pinned-card" data-pin-id="' + escapeHtml(pin.id) + '">' +
        '<div class="pinned-card-header">' +
          '<div class="pinned-card-title">' + escapeHtml(pin.title) + '</div>' +
          '<div class="pinned-card-actions">' +
            (i > 0 ? '<button class="pinned-action" onclick="window._mdMovePinned(' + i + ',' + (i-1) + ')" title="Move up">\u25B2</button>' : '') +
            (i < pinnedViews.length - 1 ? '<button class="pinned-action" onclick="window._mdMovePinned(' + i + ',' + (i+1) + ')" title="Move down">\u25BC</button>' : '') +
            '<button class="pinned-action pinned-remove" onclick="window._mdRemovePinned(\'' + pin.id + '\')" title="Remove">\u00D7</button>' +
          '</div>' +
        '</div>' +
        insightBlock + chartBlock + tableBlock +
      '</div>';
    }
    container.innerHTML = html;
  }

  // --------------------------------------------------------------------------
  // SAVE REPORT
  // --------------------------------------------------------------------------
  function saveReportHTML() {
    syncAllInsights();
    savePinnedData();

    // Update header date badge
    var dateBadge = $("#md-header-date");
    if (dateBadge) {
      var now = new Date();
      var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      dateBadge.textContent = "Saved " + now.getDate() + " " + months[now.getMonth()] + " " +
        now.getFullYear() + " " + String(now.getHours()).padStart(2,"0") + ":" +
        String(now.getMinutes()).padStart(2,"0");
    }

    // Serialize
    var html = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;
    var blob = new Blob([html], { type: "text/html;charset=utf-8" });

    // Filename from meta tag
    var meta = $('meta[name="turas-source-filename"]');
    var filename = meta ? meta.getAttribute("content") : "MaxDiff_Report";
    filename = filename.replace(/\.[^.]+$/, "") + "_report.html";

    // File System Access API (Chrome/Edge)
    if (window.showSaveFilePicker) {
      window.showSaveFilePicker({
        suggestedName: filename,
        types: [{ description: "HTML Report", accept: { "text/html": [".html"] } }]
      }).then(function(handle) {
        return handle.createWritable().then(function(writable) {
          return writable.write(blob).then(function() { return writable.close(); });
        });
      }).then(function() {
        showToast("Report saved successfully");
      }).catch(function(err) {
        if (err.name !== "AbortError") downloadBlob(blob, filename);
      });
    } else {
      downloadBlob(blob, filename);
    }
  }

  function downloadBlob(blob, filename) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast("Report downloaded");
  }

  function showToast(msg) {
    var toast = document.createElement("div");
    toast.className = "md-toast";
    toast.textContent = msg;
    document.body.appendChild(toast);
    setTimeout(function() { toast.classList.add("md-toast-show"); }, 10);
    setTimeout(function() {
      toast.classList.remove("md-toast-show");
      setTimeout(function() { toast.remove(); }, 300);
    }, 2500);
  }

  // --------------------------------------------------------------------------
  // HELP OVERLAY
  // --------------------------------------------------------------------------
  function toggleHelpOverlay() {
    var overlay = $("#md-help-overlay");
    if (overlay) overlay.classList.toggle("open");
  }

  // --------------------------------------------------------------------------
  // COLLAPSIBLE SECTIONS
  // --------------------------------------------------------------------------
  function initCollapsibles() {
    $$(".md-collapsible-header").forEach(function(header) {
      header.addEventListener("click", function() {
        var content = this.nextElementSibling;
        var arrow = this.querySelector(".md-collapse-arrow");
        if (!content) return;
        var isOpen = content.style.display !== "none";
        content.style.display = isOpen ? "none" : "block";
        if (arrow) arrow.textContent = isOpen ? "\u25B6" : "\u25BC";
        this.classList.toggle("md-collapsed", isOpen);
      });
    });
  }

  // --------------------------------------------------------------------------
  // INIT
  // --------------------------------------------------------------------------
  function init() {
    initTabs();
    initTableSort();
    initUtilityToggle();
    initCollapsibles();
    loadPinnedData();
    updatePinBadge();
    renderPinnedCards();
    hydrateInsights();

    // Close popovers on outside click
    document.addEventListener("click", function(e) {
      if (!e.target.closest(".pin-btn-wrapper")) {
        $$(".pin-mode-popover").forEach(function(p) { p.style.display = "none"; });
      }
    });
  }

  // Expose to global scope for onclick handlers
  window._mdSwitchTab = switchTab;
  window._mdToggleInsight = toggleInsight;
  window._mdToggleInsightEdit = toggleInsightEdit;
  window._mdDismissInsight = dismissInsight;
  window._mdTogglePin = togglePin;
  window._mdExecutePin = executePinWithMode;
  window._mdRemovePinned = removePinned;
  window._mdMovePinned = movePinned;
  window._mdSaveReport = saveReportHTML;
  window._mdToggleHelp = toggleHelpOverlay;

  // Run on DOMContentLoaded or immediately if already loaded
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
