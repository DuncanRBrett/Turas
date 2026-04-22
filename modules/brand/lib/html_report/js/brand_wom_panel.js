/**
 * WOM Panel controller
 *
 * Live controls:
 *   - Focal-brand dropdown    (.wom-focus-select)           → repins focal row
 *   - Coloured brand chips    ([data-wom-action="toggle-row"]) → show/hide rows
 *   - Brand column header     ([data-wom-action="sort"])    → A-Z / Z-A sort
 *   - Show chart checkbox     ([data-wom-action="showchart"]) → toggles chart
 */
(function () {
  "use strict";

  function initWomPanel(panel) {
    if (!panel || panel.dataset.womInit === "1") return;
    panel.dataset.womInit = "1";

    var table = panel.querySelector(".wom-table");
    if (!table) return;

    var accent = panel.getAttribute("data-focal-colour") || "#1A5276";

    // --- Focal brand dropdown
    var select = panel.querySelector(".wom-focus-select");
    if (select) {
      select.addEventListener("change", function () {
        var brand = select.value;
        if (!brand) return;
        repinFocal(panel, table, brand, accent);
        syncChipActivity(panel);
      });
    }

    // --- Brand show/hide chips
    panel.querySelectorAll('[data-wom-action="toggle-row"]').forEach(function (chip) {
      chip.addEventListener("click", function (ev) {
        ev.preventDefault();
        var bc = chip.getAttribute("data-wom-brand");
        if (!bc) return;
        var row = table.querySelector('tr[data-wom-brand="' + cssEscape(bc) + '"]');
        if (!row) return;
        var active = chip.classList.toggle("active");
        row.classList.toggle("wom-row-hidden", !active);
      });
    });

    // --- Brand column sort
    panel.querySelectorAll('[data-wom-action="sort"]').forEach(function (th) {
      th.addEventListener("click", function () {
        var dir = th.getAttribute("data-wom-sort-dir") || "none";
        var next = dir === "asc" ? "desc" : "asc";
        th.setAttribute("data-wom-sort-dir", next);
        sortByBrand(table, next);
      });
    });

    // --- Show chart toggle (placeholder section)
    panel.querySelectorAll('[data-wom-action="showchart"]').forEach(function (cb) {
      cb.addEventListener("change", function () {
        var scope = cb.getAttribute("data-wom-scope");
        var sel   = '.wom-chart-section[data-wom-scope="' + cssEscape(scope) + '"]';
        var sec   = panel.querySelector(sel);
        if (!sec) return;
        if (cb.checked) sec.removeAttribute("hidden");
        else             sec.setAttribute("hidden", "");
      });
    });
  }

  function repinFocal(panel, table, focalCode, accent) {
    var tbody = table.querySelector("tbody");
    if (!tbody) return;

    var allRows = Array.prototype.slice.call(
      tbody.querySelectorAll("tr.wom-row, tr.wom-row-avg"));
    if (allRows.length === 0) return;

    var focalRow = null, avgRow = null, compRows = [];
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
      tr.querySelectorAll(".fn-rel-td-focal").forEach(function (td) {
        td.classList.remove("fn-rel-td-focal");
      });
      var lbl = tr.querySelector("td.ct-label-col");
      if (lbl) {
        var badge = lbl.querySelector(".fn-focal-badge");
        if (badge) badge.remove();
      }
    });

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

    // Move focal to FOCAL chip, strip badge from the old chip
    panel.querySelectorAll(".wom-brand-chip").forEach(function (chip) {
      var b = chip.querySelector(".fn-focal-badge");
      if (b) b.remove();
      if (chip.getAttribute("data-wom-brand") === focalCode) {
        chip.appendChild(document.createTextNode(" "));
        var nb = document.createElement("span");
        nb.className = "fn-focal-badge";
        nb.textContent = "FOCAL";
        chip.appendChild(nb);
      }
    });

    compRows.sort(function (a, b) {
      return (a.dataset.womSortKey || "").localeCompare(b.dataset.womSortKey || "");
    });

    tbody.appendChild(focalRow);
    if (avgRow) tbody.appendChild(avgRow);
    compRows.forEach(function (tr) { tbody.appendChild(tr); });

    // Reset any active sort indicator — repin implies alpha order
    var sortTh = panel.querySelector('[data-wom-action="sort"]');
    if (sortTh) sortTh.setAttribute("data-wom-sort-dir", "none");
  }

  function sortByBrand(table, dir) {
    var tbody = table.querySelector("tbody");
    if (!tbody) return;
    var rows = Array.prototype.slice.call(tbody.querySelectorAll("tr"));
    var focalRow = null, avgRow = null, compRows = [];
    rows.forEach(function (tr) {
      if (tr.classList.contains("wom-row-avg"))   avgRow   = tr;
      else if (tr.classList.contains("wom-row-focal")) focalRow = tr;
      else if (tr.classList.contains("wom-row"))  compRows.push(tr);
    });
    compRows.sort(function (a, b) {
      var la = a.dataset.womSortKey || "";
      var lb = b.dataset.womSortKey || "";
      return dir === "desc" ? lb.localeCompare(la) : la.localeCompare(lb);
    });
    if (focalRow) tbody.appendChild(focalRow);
    if (avgRow)   tbody.appendChild(avgRow);
    compRows.forEach(function (tr) { tbody.appendChild(tr); });
  }

  function syncChipActivity(panel) {
    // No-op: chip "active" state is independent of focal selection.
  }

  function cssEscape(s) {
    if (window.CSS && CSS.escape) return CSS.escape(s);
    return String(s).replace(/([^a-zA-Z0-9_\-])/g, "\\$1");
  }

  function initAll() {
    document.querySelectorAll(".wom-panel").forEach(initWomPanel);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }

  window.__initWomPanels = initAll;
})();
