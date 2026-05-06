/**
 * Branded Reach panel controller (Phase 1)
 *
 * Sub-tab switching only — clicking [data-br-reach-tab] in the .br-reach-subnav
 * hides every .br-reach-subtab and unhides the matching one. The clicked
 * button is marked .active.
 *
 * The panel root is captured wholesale by brand_pins.js for pinning + PNG
 * export, so all three sub-tabs are pinned together as a single view.
 */
(function () {
  "use strict";

  function initBrReachPanel(panel) {
    if (!panel || panel.dataset.brReachInit === "1") return;
    panel.dataset.brReachInit = "1";

    var nav = panel.querySelector(".br-reach-subnav");
    if (!nav) return;

    nav.addEventListener("click", function (ev) {
      var btn = ev.target.closest("[data-br-reach-tab]");
      if (!btn) return;
      var key = btn.getAttribute("data-br-reach-tab");
      if (!key) return;

      nav.querySelectorAll(".br-reach-subtab-btn").forEach(function (b) {
        b.classList.toggle("active", b === btn);
      });
      panel.querySelectorAll(".br-reach-subtab").forEach(function (sec) {
        var match = sec.getAttribute("data-br-reach-tab") === key;
        if (match) sec.removeAttribute("hidden");
        else sec.setAttribute("hidden", "");
      });
    });

    // Insight clear button — empties the textarea in this panel only
    var clearBtn = panel.querySelector('[data-br-reach-action="clear-insight"]');
    if (clearBtn) {
      clearBtn.addEventListener("click", function () {
        var ta = panel.querySelector(".br-reach-insight-box .ma-insight-box-text");
        if (ta) { ta.value = ""; ta.focus(); }
      });
    }
  }

  function bootAll(root) {
    (root || document)
      .querySelectorAll(".br-reach-panel")
      .forEach(initBrReachPanel);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () { bootAll(); });
  } else {
    bootAll();
  }

  // Expose for late-mounted panels (matches WOM/MA pattern)
  window.initBrReachPanels = bootAll;

  /**
   * brReachImageMissing(assetCode)
   * --------------------------------------------------------------------------
   * Returns the HTML used to replace a broken <img> when the image at the
   * configured ImagePath cannot be loaded. Mirrors the no-path placeholder
   * built by .br_reach_image_placeholder() in 10_branded_reach_panel.R, so
   * the visual treatment is identical whether the path is absent or
   * present-but-broken.
   */
  window.brReachImageMissing = function (assetCode) {
    var safe = String(assetCode || "")
      .replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    return (
      '<div class="br-reach-img-wrap br-reach-img-placeholder" ' +
      'aria-label="Image could not be loaded">' +
      '<svg viewBox="0 0 80 60" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
        '<rect x="2" y="2" width="76" height="56" rx="4" fill="none" ' +
          'stroke="#c8c1b1" stroke-width="1.5" stroke-dasharray="4 3"/>' +
        '<circle cx="28" cy="26" r="6" fill="none" ' +
          'stroke="#c8c1b1" stroke-width="1.5"/>' +
        '<path d="M2 50 L28 30 L50 44 L78 22" fill="none" ' +
          'stroke="#c8c1b1" stroke-width="1.5"/>' +
      '</svg>' +
      '<span class="br-reach-img-placeholder-label">' + safe + '</span>' +
      '</div>'
    );
  };
})();
