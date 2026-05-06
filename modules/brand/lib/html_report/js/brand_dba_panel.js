/* ==========================================================================
 * brand_dba_panel.js
 * --------------------------------------------------------------------------
 * Sub-tab switching for the project-level DBA panel. Mirrors the contract
 * used by brand_branded_reach_panel.js: clicking [data-dba-tab] in the
 * .dba-subnav hides every .dba-subtab and unhides the matching one.
 *
 * The panel root carries a JSON payload at script.dba-panel-data; future
 * features (asset-level filters, threshold sliders) can read from there.
 * Currently we only need the tab switch.
 *
 * No-ops cleanly when the page has no .dba-panel (e.g. placeholder mode).
 * ==========================================================================
 */
(function () {
  "use strict";

  function initDbaPanel(panel) {
    var nav = panel.querySelector(".dba-subnav");
    if (!nav) return;

    nav.addEventListener("click", function (ev) {
      var btn = ev.target.closest("[data-dba-tab]");
      if (!btn || !nav.contains(btn)) return;
      var key = btn.getAttribute("data-dba-tab");
      if (!key) return;

      nav.querySelectorAll(".dba-subtab-btn").forEach(function (b) {
        b.classList.toggle("active", b === btn);
      });
      panel.querySelectorAll(".dba-subtab").forEach(function (sec) {
        var match = sec.getAttribute("data-dba-tab") === key;
        if (match) {
          sec.removeAttribute("hidden");
        } else {
          sec.setAttribute("hidden", "");
        }
      });
    });
  }

  function initAll() {
    var panels = document.querySelectorAll(".dba-panel");
    panels.forEach(initDbaPanel);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
