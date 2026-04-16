// ==============================================================================
// BRAND REPORT - TURAS PINS WRAPPER
// ==============================================================================
// Thin wrapper around the shared TurasPins library.
// Handles content capture for brand-specific sections and delegates
// to TurasPins.add() for pinning.
// ==============================================================================

(function() {
  "use strict";

  // --- Content capture ---
  function brCaptureContent(sectionId) {
    var section = document.getElementById("section-" + sectionId);
    if (!section) section = document.querySelector('[data-section="' + sectionId + '"]');
    if (!section) return null;

    var title = section.querySelector(".br-element-title, h2, h3");
    var titleText = title ? title.textContent.trim() : sectionId;

    // Capture SVG (clone with explicit dimensions for portability)
    var svg = section.querySelector("svg");
    var chartSvg = "";
    if (svg) {
      var clone = svg.cloneNode(true);
      var vb = svg.getAttribute("viewBox");
      if (vb) {
        var parts = vb.split(/\s+/);
        clone.setAttribute("width", parts[2]);
        clone.setAttribute("height", parts[3]);
      }
      chartSvg = clone.outerHTML;
    }

    // Capture table with portable inline styles
    var table = section.querySelector("table.br-table");
    var tableHtml = "";
    if (table && typeof TurasPins !== "undefined" && TurasPins.capturePortableHtml) {
      tableHtml = TurasPins.capturePortableHtml(table);
    } else if (table) {
      tableHtml = table.outerHTML;
    }

    // Capture insight text
    var editor = section.querySelector(".br-insight-editor");
    var insightText = editor ? editor.value.trim() : "";

    return {
      sectionKey: sectionId,
      title: titleText,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      insightText: insightText
    };
  }

  // --- Toggle pin (show checkbox popover) ---
  window.brTogglePin = function(sectionId) {
    if (typeof TurasPins === "undefined") return;

    var btn = document.querySelector('.br-pin-btn[data-section="' + sectionId + '"]');
    if (!btn) return;

    var section = document.getElementById("section-" + sectionId) ||
                  document.querySelector('[data-section="' + sectionId + '"]');
    if (!section) return;

    var hasChart = !!section.querySelector("svg");
    var hasTable = !!section.querySelector("table.br-table");
    var hasInsight = false;
    var editor = section.querySelector(".br-insight-editor");
    if (editor && editor.value.trim()) hasInsight = true;

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable, checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart, checked: hasChart },
      { key: "insight", label: "Insight", available: true,     checked: hasInsight }
    ];

    var anchor = btn.closest(".br-section-toolbar") || btn.parentElement;
    TurasPins.showCheckboxPopover(btn, checkboxes, function(flags) {
      brExecutePin(sectionId, flags);
    }, anchor);
  };

  function brExecutePin(sectionId, flags) {
    var content = brCaptureContent(sectionId);
    if (!content) return;

    content.pinFlags = {
      chart:   !!flags.chart,
      table:   !!flags.table,
      insight: !!flags.insight
    };
    content.pinMode = "custom";

    if (!flags.chart)   content.chartSvg = "";
    if (!flags.table)   content.tableHtml = "";
    if (!flags.insight) content.insightText = "";

    TurasPins.add(content);

    // Flash pin button
    var btn = document.querySelector('.br-pin-btn[data-section="' + sectionId + '"]');
    if (btn) {
      btn.classList.add("pin-flash");
      setTimeout(function() { btn.classList.remove("pin-flash"); }, 600);
    }
  }

  // --- Pin individual chart ---
  window.brPinChart = function(btnEl, chartTitle) {
    if (typeof TurasPins === "undefined") return;
    var wrapper = btnEl.closest(".br-chart-wrapper");
    if (!wrapper) return;
    var svg = wrapper.querySelector("svg");
    if (!svg) return;

    var clone = svg.cloneNode(true);
    var vb = svg.getAttribute("viewBox");
    if (vb) {
      var parts = vb.split(/\s+/);
      clone.setAttribute("width", parts[2]);
      clone.setAttribute("height", parts[3]);
    }

    TurasPins.add({
      sectionKey: "chart-" + Date.now(),
      title: chartTitle || "Chart",
      chartSvg: clone.outerHTML,
      tableHtml: "",
      insightText: "",
      pinMode: "chart_insight"
    });
  };

  // --- Export all pinned as PNG ---
  window.brExportAllPinned = function() {
    if (typeof TurasPins !== "undefined" && TurasPins.exportAllPng) {
      TurasPins.exportAllPng();
    }
  };

  // --- Add section divider ---
  window.brAddSection = function(title) {
    if (typeof TurasPins !== "undefined" && TurasPins.addSection) {
      TurasPins.addSection(title);
    }
  };

  // --- Init TurasPins ---
  function initPins() {
    if (typeof TurasPins === "undefined") return;

    TurasPins.init({
      storeId: "br-pinned-views-data",
      cssPrefix: "br-pinned",
      moduleLabel: "Brand",
      containerId: "br-pinned-cards-container",
      emptyStateId: "br-pinned-empty",
      badgeId: "br-pin-count-badge",
      features: { sections: true, dragDrop: true }
    });

    if (TurasPins._initDragDrop) TurasPins._initDragDrop();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPins);
  } else {
    initPins();
  }
})();
