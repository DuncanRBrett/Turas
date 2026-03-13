/* ===========================================================================
   TURAS PRICING REPORT - Insights System
   Per-section editable insights with config defaults and persistence
   =========================================================================== */

(function() {
  "use strict";

  // ── Toggle insight editor visibility ──
  window.toggleInsight = function(sectionId) {
    var area = document.querySelector('.pr-insight-area[data-section="' + sectionId + '"]');
    if (!area) return;

    var container = area.querySelector(".pr-insight-container");
    var toggle = area.querySelector(".pr-insight-toggle");

    if (container.classList.contains("visible")) {
      // Hide
      syncInsight(sectionId);
      container.classList.remove("visible");
      toggle.textContent = area.querySelector(".pr-insight-editor").textContent.trim()
        ? "Edit Insight" : "+ Add Insight";
    } else {
      // Show
      container.classList.add("visible");
      toggle.textContent = "Hide Insight";
      var editor = area.querySelector(".pr-insight-editor");
      editor.focus();
    }
  };

  // ── Dismiss (clear) insight ──
  window.dismissInsight = function(sectionId) {
    var area = document.querySelector('.pr-insight-area[data-section="' + sectionId + '"]');
    if (!area) return;

    var editor = area.querySelector(".pr-insight-editor");
    editor.textContent = "";
    syncInsight(sectionId);

    var container = area.querySelector(".pr-insight-container");
    container.classList.remove("visible");
    area.querySelector(".pr-insight-toggle").textContent = "+ Add Insight";
  };

  // ── Sync editor text to hidden store ──
  window.syncInsight = function(sectionId) {
    var area = document.querySelector('.pr-insight-area[data-section="' + sectionId + '"]');
    if (!area) return;

    var editor = area.querySelector(".pr-insight-editor");
    var store = area.querySelector(".pr-insight-store");
    if (editor && store) {
      store.value = editor.textContent.trim();
    }
  };

  // ── Sync all insights (called before save) ──
  window.syncAllInsights = function() {
    var areas = document.querySelectorAll(".pr-insight-area");
    for (var i = 0; i < areas.length; i++) {
      var sectionId = areas[i].getAttribute("data-section");
      syncInsight(sectionId);
    }
  };

  // ── Hydrate insights from stores on page load ──
  function hydrateInsights() {
    var areas = document.querySelectorAll(".pr-insight-area");
    for (var i = 0; i < areas.length; i++) {
      var area = areas[i];
      var editor = area.querySelector(".pr-insight-editor");
      var store = area.querySelector(".pr-insight-store");
      var toggle = area.querySelector(".pr-insight-toggle");
      var container = area.querySelector(".pr-insight-container");

      if (!editor || !store) continue;

      // Priority: stored value > config default
      var text = store.value.trim();
      if (!text) {
        var configEl = area.querySelector(".pr-insight-config-data");
        if (configEl) {
          try { text = JSON.parse(configEl.textContent).text || ""; }
          catch(e) { text = ""; }
        }
      }

      if (text) {
        editor.textContent = text;
        store.value = text;
        container.classList.add("visible");
        toggle.textContent = "Edit Insight";
      } else {
        toggle.textContent = "+ Add Insight";
      }
    }
  }

  // ── Input handler for live sync ──
  document.addEventListener("input", function(e) {
    if (e.target.classList && e.target.classList.contains("pr-insight-editor")) {
      var area = e.target.closest(".pr-insight-area");
      if (area) {
        var sectionId = area.getAttribute("data-section");
        syncInsight(sectionId);
      }
    }
  });

  // Hydrate on load
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", hydrateInsights);
  } else {
    hydrateInsights();
  }

})();
