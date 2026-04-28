// ==========================================================================
// BRAND AUDIENCE LENS PANEL — sub-tab switcher + insight box wiring
// ==========================================================================
// Drives the in-panel sub-tabs (Banner table / Per-audience cards / Pair
// scorecards). Pin + PNG buttons go through brand_pins.js.
//
// Insight box: persists per-panel free text via localStorage, keyed on the
// panel's data-cat-code attribute, so analysts can write a one-line headline
// per category and have it survive a refresh.
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
            persistInsight(panel, "");
          }
        }
      }
    });

    var ta = panel.querySelector(".al-insight-box .ma-insight-box-text");
    if (ta) {
      var saved = readInsight(panel);
      if (saved) ta.value = saved;
      ta.addEventListener("input", function () {
        persistInsight(panel, ta.value);
      });
    }

    // Default: ensure first subtab is the visible one (R sets [hidden] on
    // the others, but defensive in case a later panel intervenes)
    var firstBtn = panel.querySelector(".al-subtab-btn.active");
    if (firstBtn) {
      activateSubtab(panel, firstBtn.getAttribute("data-al-tab"));
    }
  }

  function insightKey(panel) {
    var cat = panel.getAttribute("data-cat-code") || "";
    return "turas_al_insight_" + cat;
  }

  function readInsight(panel) {
    try {
      return localStorage.getItem(insightKey(panel)) || "";
    } catch (e) { return ""; }
  }

  function persistInsight(panel, val) {
    try {
      if (val) localStorage.setItem(insightKey(panel), val);
      else     localStorage.removeItem(insightKey(panel));
    } catch (e) { /* swallow quota errors */ }
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
