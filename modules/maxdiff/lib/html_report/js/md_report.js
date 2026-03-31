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
  // SUB-TAB NAVIGATION
  // --------------------------------------------------------------------------
  function switchSubtab(btn) {
    var nav = btn.closest(".md-subtab-nav");
    if (!nav) return;
    var group = btn.getAttribute("data-group");
    var target = btn.getAttribute("data-subtab");
    var panel = nav.closest(".md-panel") || nav.parentElement;
    // Deactivate all sub-tab buttons in this group
    nav.querySelectorAll(".md-subtab-btn").forEach(function(b) {
      b.classList.remove("active");
    });
    btn.classList.add("active");
    // Show/hide sub-panels
    panel.querySelectorAll('.md-subpanel[data-group="' + group + '"]').forEach(function(p) {
      p.classList.toggle("active", p.getAttribute("data-subpanel") === target);
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
  // PINNED VIEWS — Delegated to TurasPins shared library via md_pins.js
  // --------------------------------------------------------------------------

  // --------------------------------------------------------------------------
  // SAVE REPORT
  // --------------------------------------------------------------------------
  function saveReportHTML() {
    syncAllInsights();
    if (typeof TurasPins !== "undefined") TurasPins.save();

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
  // SEGMENT FILTER
  // --------------------------------------------------------------------------
  function filterSegment(selectEl) {
    var panel = selectEl.closest(".md-panel");
    if (!panel) return;
    var val = selectEl.value;  // e.g. "Age_Group:young" or "all"
    var isAll = !val || val === "all";

    // Apply to ALL segment table containers in this panel (across sub-panels)
    var containers = panel.querySelectorAll(".md-segment-tables");
    containers.forEach(function(container) {
      var divs = container.querySelectorAll("div[data-segment]");
      var mainDiv = container.querySelector('div[data-segment="all"]');

      if (isAll) {
        if (mainDiv) mainDiv.style.display = "block";
        divs.forEach(function(d) { if (d.getAttribute("data-segment") !== "all") d.style.display = "none"; });
      } else {
        if (mainDiv) mainDiv.style.display = "none";
        divs.forEach(function(d) {
          var seg = d.getAttribute("data-segment");
          if (seg === "all") { d.style.display = "none"; return; }
          d.style.display = (seg === val) ? "block" : "none";
        });
      }
    });

    // n= labels are inside segment divs and automatically show/hide with their parent
  }

  // --------------------------------------------------------------------------
  // ADDED SLIDES (Markdown editor + image insert)
  // --------------------------------------------------------------------------
  function addSlide() {
    var container = $("#md-slides-container");
    if (!container) return;
    var id = "slide-" + Date.now();
    var card = document.createElement("div");
    card.className = "md-slide-card editing";
    card.setAttribute("data-slide-id", id);
    card.innerHTML =
      '<div class="md-slide-header">' +
        '<div class="md-slide-title" contenteditable="true">New Slide</div>' +
        '<div class="md-slide-actions">' +
          '<button class="md-slide-btn" title="Add image" onclick="window._mdTriggerSlideImage(\'' + id + '\')">\u{1F5BC}</button>' +
          '<button class="md-slide-btn" title="Pin this slide" onclick="window._mdPinSlide(\'' + id + '\')">\u{1F4CC}</button>' +
          '<button class="md-slide-btn" title="Move up" onclick="window._mdMoveSlide(\'' + id + '\',\'up\')">\u25B2</button>' +
          '<button class="md-slide-btn" title="Move down" onclick="window._mdMoveSlide(\'' + id + '\',\'down\')">\u25BC</button>' +
          '<button class="md-slide-btn" title="Remove" style="color:#e74c3c;" onclick="window._mdRemoveSlide(\'' + id + '\')">\u2715</button>' +
        '</div>' +
      '</div>' +
      '<div class="md-slide-img-preview" style="display:none;">' +
        '<img class="md-slide-img-thumb"/>' +
        '<button class="md-slide-img-remove" onclick="window._mdRemoveSlideImage(\'' + id + '\')">&times;</button>' +
      '</div>' +
      '<input type="file" class="md-slide-img-input" accept="image/*" style="display:none;" onchange="window._mdHandleSlideImage(\'' + id + '\', this)">' +
      '<textarea class="md-slide-md-editor" rows="6" placeholder="Enter markdown... (**bold**, *italic*, > quote, - bullet, ## heading)"></textarea>' +
      '<div class="md-slide-md-rendered" style="display:none;"></div>' +
      '<textarea class="md-slide-md-store" style="display:none;"></textarea>' +
      '<textarea class="md-slide-img-store" style="display:none;"></textarea>';
    container.appendChild(card);
    card.querySelector(".md-slide-md-editor").focus();
    updateSlideEmptyState();
  }

  function triggerSlideImage(slideId) {
    var card = $('[data-slide-id="' + slideId + '"]');
    if (card) { var inp = card.querySelector(".md-slide-img-input"); if (inp) inp.click(); }
  }

  function handleSlideImage(slideId, input) {
    if (!input.files || !input.files[0]) return;
    var file = input.files[0];
    if (file.size > 5 * 1024 * 1024) { alert("Image too large. Max 5MB."); input.value = ""; return; }
    var reader = new FileReader();
    reader.onload = function(e) {
      var card = $('[data-slide-id="' + slideId + '"]');
      if (!card) return;
      var preview = card.querySelector(".md-slide-img-preview");
      var thumb = card.querySelector(".md-slide-img-thumb");
      var store = card.querySelector(".md-slide-img-store");
      if (thumb) { thumb.src = e.target.result; }
      if (preview) { preview.style.display = "block"; }
      if (store) { store.value = e.target.result; }
    };
    reader.readAsDataURL(file);
  }

  function removeSlideImage(slideId) {
    var card = $('[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var preview = card.querySelector(".md-slide-img-preview");
    var store = card.querySelector(".md-slide-img-store");
    if (preview) preview.style.display = "none";
    if (store) store.value = "";
  }

  function removeSlide(slideId) {
    var card = $('[data-slide-id="' + slideId + '"]');
    if (card) card.remove();
    updateSlideEmptyState();
  }

  function moveSlide(slideId, direction) {
    var card = $('[data-slide-id="' + slideId + '"]');
    if (!card) return;
    if (direction === "up" && card.previousElementSibling) {
      card.parentNode.insertBefore(card, card.previousElementSibling);
    } else if (direction === "down" && card.nextElementSibling) {
      card.parentNode.insertBefore(card.nextElementSibling, card);
    }
  }

  // pinSlide — delegated to md_pins.js

  function updateSlideEmptyState() {
    var container = $("#md-slides-container");
    var empty = $("#md-slides-empty");
    if (!container || !empty) return;
    empty.style.display = container.children.length === 0 ? "block" : "none";
  }

  // pinChart — delegated to md_pins.js

  // --------------------------------------------------------------------------
  // PANEL EXCEL EXPORT
  // --------------------------------------------------------------------------
  function escapeXml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  /**
   * Export tables from a panel to Excel XML.
   * For panels with segment variants, exports each segment as a labelled
   * section within the worksheet. Only exports visible tables unless
   * segment containers are present (in which case all segments are exported).
   * @param {string} panelId - Panel identifier (e.g., "h2h", "preferences")
   */
  function exportPanelToExcel(panelId) {
    var panel = $("#panel-" + panelId);
    if (!panel) return;

    var meta = $('meta[name="turas-source-filename"]');
    var base = meta ? meta.getAttribute("content").replace(/\.[^.]+$/, "") : "MaxDiff";
    var sheetName = panelId.replace(/[^a-zA-Z0-9_]/g, "_").substring(0, 31);

    var xml = [];
    xml.push('<?xml version="1.0" encoding="UTF-8"?>');
    xml.push('<?mso-application progid="Excel.Sheet"?>');
    xml.push('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"');
    xml.push(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
    xml.push('<Styles>');
    xml.push('<Style ss:ID="header"><Font ss:Bold="1" ss:Size="11"/>');
    xml.push('<Interior ss:Color="#F8F9FA" ss:Pattern="Solid"/></Style>');
    xml.push('<Style ss:ID="title"><Font ss:Bold="1" ss:Size="12"/></Style>');
    xml.push('<Style ss:ID="segment"><Font ss:Bold="1" ss:Size="11" ss:Color="#1e3a5f"/></Style>');
    xml.push('<Style ss:ID="normal"><Font ss:Size="11"/></Style>');
    xml.push('</Styles>');
    xml.push('<Worksheet ss:Name="' + escapeXml(sheetName) + '">');
    xml.push('<Table>');

    // Title row
    var h2 = panel.querySelector("h2");
    if (h2) {
      xml.push('<Row><Cell ss:StyleID="title"><Data ss:Type="String">' +
                escapeXml(base + " - " + h2.textContent.trim()) + '</Data></Cell></Row>');
      xml.push('<Row></Row>');
    }

    // Helper: export a single table's rows to XML
    function exportTableRows(table) {
      var rows = table.querySelectorAll("tr");
      rows.forEach(function(row, rowIdx) {
        xml.push('<Row>');
        var cells = row.querySelectorAll("th, td");
        cells.forEach(function(c) {
          var txt = c.textContent.trim();
          var styleId = (row.querySelector("th") || rowIdx === 0) ? "header" : "normal";
          var num = parseFloat(txt.replace(/[,%]/g, ""));
          var isNum = !isNaN(num) && /^[\d,\.%\s\-]+$/.test(txt) && txt.trim() !== "";
          if (isNum) {
            xml.push('<Cell ss:StyleID="' + styleId + '"><Data ss:Type="Number">' + num + '</Data></Cell>');
          } else {
            xml.push('<Cell ss:StyleID="' + styleId + '"><Data ss:Type="String">' + escapeXml(txt) + '</Data></Cell>');
          }
        });
        xml.push('</Row>');
      });
    }

    // Check for segment-variant containers (data-segment divs)
    var segContainer = panel.querySelector(".md-segment-tables");
    if (segContainer) {
      // Export each segment separately with a label header
      var segDivs = segContainer.querySelectorAll("[data-segment]");
      segDivs.forEach(function(segDiv, sIdx) {
        var segKey = segDiv.getAttribute("data-segment");
        // Resolve segment label from the dropdown if available
        var segLabel = segKey === "all" ? "All Respondents" : segKey;
        var dropdown = panel.querySelector("select");
        if (dropdown && segKey !== "all") {
          for (var oi = 0; oi < dropdown.options.length; oi++) {
            if (dropdown.options[oi].value === segKey) {
              segLabel = dropdown.options[oi].text;
              break;
            }
          }
        }
        // n= label
        var nLabel = segDiv.querySelector(".md-segment-n-label");
        var nText = nLabel ? " " + nLabel.textContent.trim() : "";

        if (sIdx > 0) xml.push('<Row></Row>');
        xml.push('<Row><Cell ss:StyleID="segment"><Data ss:Type="String">' +
                  escapeXml(segLabel + nText) + '</Data></Cell></Row>');

        var tables = segDiv.querySelectorAll(".md-table, .md-h2h-table, table");
        tables.forEach(function(table) { exportTableRows(table); });
      });
    } else {
      // No segment variants — export visible tables only
      var tables = panel.querySelectorAll(".md-table, .md-h2h-table");
      if (tables.length === 0) { showToast("No table data to export"); return; }
      tables.forEach(function(table, tIdx) {
        // Skip hidden tables
        if (table.closest("[style*='display:none']") || table.closest("[style*='display: none']")) return;
        if (tIdx > 0) xml.push('<Row></Row>');
        exportTableRows(table);
      });
    }

    xml.push('</Table></Worksheet></Workbook>');

    var blob = new Blob([xml.join("\n")], { type: "application/vnd.ms-excel;charset=utf-8" });
    downloadBlob(blob, base + "_" + panelId + ".xls");
    showToast("Exported to Excel");
  }

  // PIN EXPORT — delegated to md_pins.js via TurasPins

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
    hydrateInsights();
    // Pin init handled by md_pins.js via TurasPins
  }

  // Expose to global scope for onclick handlers
  window._mdSwitchTab = switchTab;
  window._mdToggleInsight = toggleInsight;
  window._mdToggleInsightEdit = toggleInsightEdit;
  window._mdDismissInsight = dismissInsight;
  // _mdTogglePin, _mdExecutePin, _mdRemovePinned, _mdMovePinned — set by md_pins.js
  window._mdSaveReport = saveReportHTML;
  window._mdToggleHelp = toggleHelpOverlay;
  window._mdFilterSegment = filterSegment;
  window._mdSwitchSubtab = switchSubtab;
  window._mdAddSlide = addSlide;
  window._mdTriggerSlideImage = triggerSlideImage;
  window._mdHandleSlideImage = handleSlideImage;
  window._mdRemoveSlideImage = removeSlideImage;
  window._mdRemoveSlide = removeSlide;
  window._mdMoveSlide = moveSlide;
  // _mdPinSlide, _mdPinChart, _mdExportPinnedSvg, _mdExportAllPinned — set by md_pins.js
  window._mdExportPanel = exportPanelToExcel;

  // Run on DOMContentLoaded or immediately if already loaded
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
