/**
 * WOM Panel controller
 *
 * v1.0 scope: static WOM table with a live focal-brand dropdown that
 * reorders rows and toggles focal styling client-side. Chart layer will
 * be added in a follow-up commit.
 */
(function () {
  "use strict";

  function initWomPanel(panel) {
    if (!panel || panel.dataset.womInit === "1") return;
    panel.dataset.womInit = "1";

    var select = panel.querySelector(".wom-focus-select");
    var table  = panel.querySelector(".wom-table");
    if (!select || !table) return;

    var accent = panel.getAttribute("data-focal-colour") || "#1A5276";

    select.addEventListener("change", function () {
      var brand = select.value;
      if (!brand) return;
      repinFocal(table, brand, accent);
    });
  }

  function repinFocal(table, focalCode, accent) {
    var tbody = table.querySelector("tbody");
    if (!tbody) return;

    var allRows = Array.prototype.slice.call(
      tbody.querySelectorAll("tr.wom-row, tr.wom-row-avg"));
    if (allRows.length === 0) return;

    // Partition
    var focalRow = null;
    var avgRow   = null;
    var compRows = [];
    allRows.forEach(function (tr) {
      if (tr.classList.contains("wom-row-avg")) {
        avgRow = tr;
      } else if (tr.dataset.womBrand === focalCode) {
        focalRow = tr;
      } else {
        compRows.push(tr);
      }
    });
    if (!focalRow) return;

    // Reset all brand rows to competitor styling
    allRows.forEach(function (tr) {
      if (tr.classList.contains("wom-row-avg")) return;
      tr.classList.remove("fn-row-focal", "wom-row-focal");
      tr.classList.add("fn-row-competitor", "wom-row-competitor");
      tr.removeAttribute("style");
      tr.removeAttribute("data-locked");

      // Remove focal cell highlight
      tr.querySelectorAll(".fn-rel-td-focal").forEach(function (td) {
        td.classList.remove("fn-rel-td-focal");
      });

      // Strip any FOCAL badge from the label cell
      var lbl = tr.querySelector("td.ct-label-col");
      if (lbl) {
        var badge = lbl.querySelector(".fn-focal-badge");
        if (badge) badge.remove();
      }
    });

    // Apply focal styling to the newly-focal row
    focalRow.classList.remove("fn-row-competitor", "wom-row-competitor");
    focalRow.classList.add("fn-row-focal", "wom-row-focal");
    focalRow.setAttribute("style", "--fn-row-accent:" + accent + ";");
    focalRow.setAttribute("data-locked", "1");
    focalRow.querySelectorAll("td").forEach(function (td) {
      td.classList.add("fn-rel-td-focal");
    });
    var focalLbl = focalRow.querySelector("td.ct-label-col");
    if (focalLbl && !focalLbl.querySelector(".fn-focal-badge")) {
      var badge = document.createElement("span");
      badge.className = "fn-focal-badge";
      badge.textContent = "FOCAL";
      focalLbl.appendChild(document.createTextNode(" "));
      focalLbl.appendChild(badge);
    }

    // Sort competitors alphabetically by label text
    compRows.sort(function (a, b) {
      var la = (a.querySelector("td.ct-label-col") || {}).textContent || "";
      var lb = (b.querySelector("td.ct-label-col") || {}).textContent || "";
      return la.trim().toLowerCase().localeCompare(lb.trim().toLowerCase());
    });

    // Re-insert: focal, avg, then competitors
    tbody.appendChild(focalRow);
    if (avgRow) tbody.appendChild(avgRow);
    compRows.forEach(function (tr) { tbody.appendChild(tr); });
  }

  function initAll() {
    document.querySelectorAll(".wom-panel").forEach(initWomPanel);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }

  // Expose for late-rendered panels (e.g. tab lazy-mount).
  window.__initWomPanels = initAll;
})();
