/**
 * Conjoint Report Navigation & Core Interactions
 * Tab switching, attribute sidebar, insight system, save/print, help overlay.
 */

(function() {
  "use strict";

  // === TAB NAVIGATION ===

  window.switchReportTab = function(tabName) {
    document.querySelectorAll(".cj-report-tab").forEach(function(t) {
      t.classList.remove("active");
    });
    document.querySelectorAll(".cj-panel").forEach(function(p) {
      p.classList.remove("active");
    });
    var btn = document.querySelector('.cj-report-tab[data-tab="' + tabName + '"]');
    if (btn) btn.classList.add("active");
    var panel = document.getElementById("panel-" + tabName);
    if (panel) panel.classList.add("active");

    // Initialize simulator on first visit
    if (tabName === "simulator" && typeof SimUI !== "undefined" && !SimUI._initialized) {
      SimUI.init();
    }
  };


  // === ATTRIBUTE SIDEBAR ===

  window.selectAttribute = function(attrName) {
    document.querySelectorAll(".cj-util-item").forEach(function(item) {
      item.classList.toggle("active", item.getAttribute("data-attr") === attrName);
    });
    document.querySelectorAll(".cj-attr-detail").forEach(function(d) {
      d.classList.toggle("active", d.getAttribute("data-attr") === attrName);
    });
  };

  window.filterAttributes = function(term) {
    var lower = (term || "").toLowerCase();
    document.querySelectorAll(".cj-util-item").forEach(function(item) {
      var name = (item.getAttribute("data-attr") || "").toLowerCase();
      item.style.display = name.indexOf(lower) >= 0 ? "" : "none";
    });
  };


  // === INSIGHT SYSTEM ===

  window.toggleInsight = function(id) {
    var body = document.getElementById("insight-body-" + id);
    if (body) {
      body.classList.toggle("open");
      var btn = body.previousElementSibling;
      if (btn && btn.classList.contains("cj-insight-toggle")) {
        btn.textContent = body.classList.contains("open") ? "- Hide Insight" : "+ Add Insight";
      }
    }
  };

  window.syncInsight = function(id) {
    var editor = document.getElementById("insight-editor-" + id);
    var store = document.getElementById("insight-store-" + id);
    if (editor && store) {
      store.value = editor.innerHTML;
    }
  };

  window.syncAllInsights = function() {
    document.querySelectorAll(".cj-insight-editor").forEach(function(editor) {
      var id = editor.id.replace("insight-editor-", "");
      syncInsight(id);
    });
  };

  window.syncAboutNotes = function() {
    var editor = document.getElementById("cj-about-notes");
    var store = document.getElementById("cj-about-notes-store");
    if (editor && store) {
      store.value = editor.innerHTML;
    }
  };

  function hydrateInsights() {
    document.querySelectorAll(".cj-insight-store").forEach(function(store) {
      var id = store.id.replace("insight-store-", "");
      var editor = document.getElementById("insight-editor-" + id);
      if (editor && store.value && store.value.trim()) {
        editor.innerHTML = store.value;
        var body = document.getElementById("insight-body-" + id);
        if (body) body.classList.add("open");
      }
    });
  }


  // === SAVE REPORT ===

  window.saveReportHTML = function() {
    syncAllInsights();

    // Update date badge
    var badge = document.getElementById("cj-header-date");
    if (badge) {
      var now = new Date();
      badge.textContent = "Last saved " + now.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
    }

    // Serialize HTML
    var clone = document.documentElement.cloneNode(true);

    // Remove help overlay open state
    var helpEl = clone.querySelector("#cj-help-overlay");
    if (helpEl) helpEl.classList.remove("open");

    var html = "<!DOCTYPE html>\n" + clone.outerHTML;

    // Determine filename
    var meta = document.querySelector('meta[name="turas-source-filename"]');
    var baseName = meta ? meta.getAttribute("content") : "Conjoint_Report";
    baseName = baseName.replace(/\.[^/.]+$/, "");
    var filename = baseName + "_Updated.html";

    downloadBlob(html, filename, "text/html");
  };


  // === PRINT ===

  window.printReport = function() {
    syncAllInsights();
    // Show all panels for printing
    document.querySelectorAll(".cj-panel").forEach(function(p) {
      p.classList.add("active");
    });
    window.print();
    // Restore active tab
    var activeBtn = document.querySelector(".cj-report-tab.active");
    if (activeBtn) {
      var tab = activeBtn.getAttribute("data-tab");
      switchReportTab(tab);
    }
  };


  // === HELP OVERLAY ===

  window.toggleHelpOverlay = function() {
    var overlay = document.getElementById("cj-help-overlay");
    if (overlay) overlay.classList.toggle("open");
  };


  // === SIMULATOR MODE SWITCH ===

  window.switchSimMode = function(mode) {
    document.querySelectorAll(".cj-sim-mode-btn").forEach(function(btn) {
      btn.classList.remove("active");
    });
    var clicked = document.querySelector('.cj-sim-mode-btn[onclick*="' + mode + '"]');
    if (clicked) clicked.classList.add("active");

    if (typeof SimUI !== "undefined") {
      SimUI.switchMode(mode);
    }
  };


  // === DOWNLOAD BLOB UTILITY ===

  window.downloadBlob = function(content, filename, mimeType) {
    var blob = new Blob([content], { type: mimeType || "application/octet-stream" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };


  // === INIT ===

  document.addEventListener("DOMContentLoaded", function() {
    // Initialize simulator engine with embedded data
    var dataEl = document.getElementById("cj-simulator-data");
    if (dataEl) {
      try {
        var simData = JSON.parse(dataEl.textContent);
        if (simData && simData.attributes) {
          SimEngine.init(simData);
        }
      } catch (e) {
        console.warn("Failed to parse simulator data:", e);
      }
    }

    // Set brand colour for charts
    var brand = getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim();
    if (brand && typeof SimCharts !== "undefined") {
      SimCharts.setBrand(brand);
    }

    // Hydrate saved insights
    hydrateInsights();

    // Hydrate pinned views
    if (typeof hydratePinnedViews === "function") {
      hydratePinnedViews();
    }

    // Show help on first visit
    try {
      if (!localStorage.getItem("cj-help-seen")) {
        var overlay = document.getElementById("cj-help-overlay");
        if (overlay) overlay.classList.add("open");
        localStorage.setItem("cj-help-seen", "1");
      }
    } catch (e) { /* localStorage unavailable */ }

    // Start on overview tab
    switchReportTab("overview");
  });

})();
