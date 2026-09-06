// ==========================================================================
// BRAND AUDIENCE LENS PANEL — sub-tab switcher + insight box wiring
// ==========================================================================
// Drives the in-panel sub-tabs (Banner table / Per-audience cards / Pair
// scorecards). Pin + PNG buttons go through brand_pins.js.
//
// Insight box: free text persists in the saved HTML itself through the
// report-wide textarea mirror in brand_report.js, so a one-line headline per
// category survives Save and reopen.
// ==========================================================================

(function () {
  "use strict";

  function ready(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  function activateSubtab(panel, key) {
    if (!panel) return;
    panel.querySelectorAll(".al-subtab-btn").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-al-tab") === key);
    });
    panel.querySelectorAll(".al-subtab").forEach(function (sec) {
      var match = sec.getAttribute("data-al-tab") === key;
      if (match) {
        sec.removeAttribute("hidden");
        sec.classList.add("al-subtab-active");
      } else {
        sec.setAttribute("hidden", "");
        sec.classList.remove("al-subtab-active");
      }
    });
  }

  function bindPanel(panel) {
    if (!panel || panel.dataset.alBound === "1") return;
    panel.dataset.alBound = "1";

    panel.addEventListener("click", function (ev) {
      var btn = ev.target.closest(".al-subtab-btn");
      if (btn && panel.contains(btn)) {
        activateSubtab(panel, btn.getAttribute("data-al-tab"));
        return;
      }
      var clear = ev.target.closest("[data-al-action='clear-insight']");
      if (clear) {
        var box = clear.closest(".al-insight-box");
        if (box) {
          var ta = box.querySelector(".ma-insight-box-text");
          if (ta) {
            ta.value = "";
            if (window._brSyncCommentary) window._brSyncCommentary(ta);
          }
        }
      }
    });

    // Insight text persists through the report-wide textarea mirror in
    // brand_report.js (window._brSyncCommentary), so it travels with the
    // saved file. The localStorage copy that lived here never did, and its
    // key (a fixed prefix plus the category code) was shared by every
    // report in the browser, so two clients' commentary overwrote each
    // other (review 2026-07-12, H3).

    // Default: ensure first subtab is the visible one (R sets [hidden] on
    // the others, but defensive in case a later panel intervenes)
    var firstBtn = panel.querySelector(".al-subtab-btn.active");
    if (firstBtn) {
      activateSubtab(panel, firstBtn.getAttribute("data-al-tab"));
    }
  }

  ready(function () {
    document.querySelectorAll(".al-panel").forEach(bindPanel);
  });

  // Re-bind when other tabs (e.g. category nav) lazy-render new content
  if (typeof window !== "undefined") {
    window.brAudienceLensRebind = function () {
      document.querySelectorAll(".al-panel").forEach(bindPanel);
    };
  }
})();
