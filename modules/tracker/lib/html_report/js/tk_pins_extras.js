/**
 * TURAS Tracker Report — Summary Pins, Sig Changes, Print & Export
 *
 * Handles summary section pinning (background, findings, KPI cards),
 * significant change cards, print overlay, save/export functions.
 * All pin creation delegates to TurasPins.add().
 *
 * Depends on: TurasPins shared library, tk_pins.js (loaded before this)
 *             escapeHtml, svgToImageUrl, stripInvalidXmlChars from earlier in bundle
 */

/* global TurasPins, escapeHtml, svgToImageUrl, stripInvalidXmlChars */

(function() {
  "use strict";

  // ── Summary Section Pins ──────────────────────────────────────────────────

  /**
   * Pin a summary section (background, findings, or KPI cards).
   * @param {string} sectionType - "background", "findings", or "kpi-cards"
   */
  window.pinSummarySection = function(sectionType) {
    if (sectionType === "kpi-cards") {
      pinKpiCards();
      return;
    }

    var editorId = sectionType === "background"
      ? "summary-background-editor"
      : "summary-findings-editor";
    var editor = document.getElementById(editorId);
    if (!editor || !editor.innerHTML.trim()) {
      alert("Add content before pinning.");
      return;
    }

    var title = sectionType === "background" ? "Background & Method" : "Summary";
    TurasPins.add({
      metricId: "summary-" + sectionType,
      title: title, metricTitle: title,
      insightText: editor.innerHTML,
      tableHtml: "", chartSvg: "", chartVisible: false
    });
  };

  /** Pin visible KPI cards. */
  function pinKpiCards() {
    var visibleCards = document.querySelectorAll(".kpi-card-item:not(.kpi-card-hidden)");
    if (visibleCards.length === 0) {
      alert("No visible KPI cards to pin. Show some cards first.");
      return;
    }
    var container = document.createElement("div");
    container.className = "tk-hero-strip";
    container.style.cssText = "display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px;";
    for (var i = 0; i < visibleCards.length; i++) {
      var clone = visibleCards[i].cloneNode(true);
      var hideBtn = clone.querySelector(".kpi-card-hide-btn");
      if (hideBtn) hideBtn.remove();
      container.appendChild(clone);
    }
    TurasPins.add({
      metricId: "summary-kpi-cards",
      title: "Key Metrics at a Glance", metricTitle: "Key Metrics at a Glance",
      tableHtml: _wrapKpiStyles(container.outerHTML),
      chartSvg: "", chartVisible: false, insightText: ""
    });
  }

  /** Wrap KPI card HTML with embedded CSS for rendering outside tracker context. */
  function _wrapKpiStyles(html) {
    var brand = getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367";
    var css = ".tk-hero-strip{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px}" +
      ".tk-hero-card{background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:16px 20px;border-left:4px solid #94a3b8}" +
      ".tk-hero-label{font-size:12px;font-weight:600;color:#64748b;margin-bottom:6px;line-height:1.3}" +
      ".tk-hero-value-row{display:flex;align-items:baseline;gap:12px}" +
      ".tk-hero-value{font-size:28px;font-weight:700;font-variant-numeric:tabular-nums;line-height:1.1}" +
      ".tk-hero-delta{font-size:13px;font-weight:600}" +
      ".tk-hero-sparkline{margin-top:8px}" +
      ".tk-hero-sparkline svg{display:block;width:100%;height:auto}" +
      ".tk-hero-primary .tk-hero-value{font-size:32px}" +
      ".tk-hero-primary .tk-hero-card{padding:20px 24px}" +
      ".tk-hero-secondary .tk-hero-card{padding:12px 16px}" +
      ".tk-hero-secondary .tk-hero-value{font-size:22px}" +
      ".tk-hero-secondary .tk-hero-label{font-size:11px}";
    return '<div style="font-family:Inter,system-ui,-apple-system,sans-serif;"><style>' + css + '</style>' + html + '</div>';
  }

  /** Wrap sig change card HTML with embedded CSS for rendering outside tracker context. */
  function _wrapSigStyles(html) {
    var css = ".dash-sig-card{background:#fff;border-radius:8px;border:1px solid #e2e8f0;padding:12px 16px;border-left:3px solid #059669;margin-bottom:8px}" +
      ".dash-sig-metric-badge{font-size:9px;font-weight:700;padding:2px 6px;border-radius:3px;background:rgba(26,39,68,0.06);color:#1a2744;letter-spacing:0.5px}" +
      ".dash-sig-text{font-size:12px;color:#1e293b;line-height:1.4}" +
      ".dash-sig-grid{display:grid;gap:8px}";
    return '<div style="font-family:Inter,system-ui,-apple-system,sans-serif;"><style>' + css + '</style>' + html + '</div>';
  }

  // ── Significant Changes ───────────────────────────────────────────────────

  /** Alias for pinVisibleSigFindings. */
  window.pinSigChanges = function() { window.pinVisibleSigFindings(); };

  /** Toggle sig card visibility. */
  window.toggleSigCard = function(sigId) {
    var card = document.querySelector('.dash-sig-card[data-sig-id="' + sigId + '"]');
    if (!card) return;
    card.classList.toggle("sig-hidden");
    window.saveSigCardStates();
  };

  /** Pin an individual sig change card. */
  window.pinSigCard = function(sigId) {
    var card = document.querySelector('.dash-sig-card[data-sig-id="' + sigId + '"]');
    if (!card || card.classList.contains("sig-hidden")) return;
    var clone = card.cloneNode(true);
    var actions = clone.querySelector(".sig-card-actions");
    if (actions) actions.remove();
    clone.classList.remove("sig-hidden");

    var textEl = clone.querySelector(".dash-sig-text");
    var title = textEl ? textEl.textContent.substring(0, 80) : "Sig Change";

    TurasPins.add({
      metricId: "summary-sig-change-" + sigId,
      title: "Sig Change: " + title, metricTitle: "Sig Change: " + title,
      tableHtml: _wrapSigStyles(clone.outerHTML),
      chartSvg: "", chartVisible: false, insightText: ""
    });
  };

  /** Pin all visible sig change cards as one block. */
  window.pinVisibleSigFindings = function() {
    var section = document.getElementById("summary-section-sig-changes");
    if (!section) return;
    var visible = section.querySelectorAll(".dash-sig-card:not(.sig-hidden)");
    if (visible.length === 0) return;

    var wrapper = document.createElement("div");
    wrapper.className = "dash-sig-grid";
    visible.forEach(function(card) {
      var clone = card.cloneNode(true);
      var actions = clone.querySelector(".sig-card-actions");
      if (actions) actions.remove();
      wrapper.appendChild(clone);
    });

    TurasPins.add({
      metricId: "summary-sig-changes",
      title: "Significant Changes", metricTitle: "Significant Changes",
      tableHtml: _wrapSigStyles(wrapper.outerHTML),
      chartSvg: "", chartVisible: false, insightText: ""
    });
  };

  /** Persist sig card toggle states to hidden JSON store. */
  window.saveSigCardStates = function() {
    var store = document.getElementById("sig-card-states");
    if (!store) return;
    var states = {};
    document.querySelectorAll(".dash-sig-card[data-sig-id]").forEach(function(card) {
      if (card.classList.contains("sig-hidden")) {
        states[card.getAttribute("data-sig-id")] = true;
      }
    });
    store.textContent = JSON.stringify(states);
  };

  /** Restore sig card toggle states from hidden JSON store. */
  window.hydrateSigCardStates = function() {
    var store = document.getElementById("sig-card-states");
    if (!store || !store.textContent || store.textContent === "{}") return;
    try {
      var states = JSON.parse(store.textContent);
      for (var sigId in states) {
        if (states[sigId]) {
          var card = document.querySelector('.dash-sig-card[data-sig-id="' + sigId + '"]');
          if (card) card.classList.add("sig-hidden");
        }
      }
    } catch(e) { /* corrupt data — skip silently */ }
  };

  // ── Summary Table Pin ─────────────────────────────────────────────────────

  /** Pin the summary metrics table. */
  window.pinSummaryTable = function() {
    var table = document.getElementById("summary-metrics-table");
    if (!table) return;
    var clone = table.cloneNode(true);
    clone.querySelectorAll("tr").forEach(function(tr) {
      if (tr.style.display === "none") tr.remove();
    });
    TurasPins.add({
      metricId: "summary-metrics-table",
      title: "Summary Metrics Overview", metricTitle: "Summary Metrics Overview",
      tableHtml: '<div class="tk-table-wrapper">' + clone.outerHTML + '</div>',
      chartSvg: "", chartVisible: false, insightText: ""
    });
  };

  // ── Print All Pins ────────────────────────────────────────────────────────

  /** Print all pinned views using body class to hide other content. */
  window.printAllPins = function() {
    if (typeof switchReportTab === "function") switchReportTab("pinned");
    var printPanel = (typeof _tkPanel === "function") ? _tkPanel() : document.body;
    printPanel.classList.add("print-pinned-only");
    setTimeout(function() {
      window.print();
      setTimeout(function() { printPanel.classList.remove("print-pinned-only"); }, 500);
    }, 200);
  };

  // ── Save Report HTML ──────────────────────────────────────────────────────

  /** Save the entire HTML report with all pins and insights. */
  window.saveReportHTML = function() {
    TurasPins.save();

    // Update "Last saved" timestamp
    var dateBadge = document.getElementById("header-date-badge");
    if (dateBadge) {
      var now = new Date();
      var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      dateBadge.textContent = "Last saved " + now.getDate() + " " +
        months[now.getMonth()] + " " + now.getFullYear() + " " +
        String(now.getHours()).padStart(2, "0") + ":" +
        String(now.getMinutes()).padStart(2, "0");
    }

    // Save insight editors to hidden stores
    document.querySelectorAll(".insight-editor").forEach(function(editor) {
      var area = editor.closest(".insight-area");
      if (area) {
        var textarea = area.querySelector(".insight-store");
        if (textarea) textarea.value = editor.innerHTML;
      }
    });

    // Sync closing notes
    var closingEditor = document.querySelector(".closing-notes-editor");
    var closingStore = document.querySelector(".closing-notes-store");
    if (closingEditor && closingStore) closingStore.textContent = closingEditor.innerHTML;

    // Save summary editors
    document.querySelectorAll(".summary-editor").forEach(function(editor) {
      editor.setAttribute("data-saved-content", editor.innerHTML);
    });

    // Download
    var htmlContent = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;
    var blob = new Blob([htmlContent], { type: "text/html;charset=utf-8" });
    var projectTitle = document.querySelector(".tk-header-project");
    var filename = projectTitle
      ? projectTitle.textContent.trim().replace(/[^a-zA-Z0-9_-]/g, "_")
      : "tracking_report";
    var suggestedName = filename + "_updated.html";

    if (window.showSaveFilePicker) {
      window.showSaveFilePicker({
        suggestedName: suggestedName,
        types: [{ description: "HTML Document", accept: { "text/html": [".html"] } }]
      }).then(function(handle) {
        return handle.createWritable().then(function(writable) {
          return writable.write(blob).then(function() { return writable.close(); });
        });
      }).catch(function(err) {
        if (err.name !== "AbortError") { /* save cancelled */ }
      });
    } else {
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = suggestedName;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }
  };

  // ── DOMContentLoaded Hydration ────────────────────────────────────────────

  function initExtras() {
    window.hydratePinnedViews();
    window.hydrateSigCardStates();
    // Hydrate closing notes
    var closingStore = document.querySelector(".closing-notes-store");
    var closingEditor = document.querySelector(".closing-notes-editor");
    if (closingStore && closingStore.value && closingEditor) {
      closingEditor.innerHTML = closingStore.value;
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initExtras);
  } else {
    initExtras();
  }

})();
