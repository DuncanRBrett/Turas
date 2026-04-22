/**
 * WOM Panel controller
 *
 * Live controls:
 *   - Focal-brand dropdown    (.wom-focus-select)             → repins focal row
 *   - Coloured brand chips    ([data-wom-action="toggle-row"])→ show/hide row + chart bar
 *   - Any column header       ([data-wom-action="sort"])      → asc/desc sort
 *   - Show chart checkbox     ([data-wom-action="showchart"]) → toggles chart
 *   - Heard/Said variant seg  ([data-wom-action="variant"])   → swaps SVG variant
 *
 * Chart ↔ table coupling: any reorder or chip toggle calls reflowChart(),
 * which hides/shows and repositions <g class="wom-bar-row"> groups so the
 * chart mirrors the visible row order of the table.
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
        reflowChart(panel);
      });
    });

    // --- Column sort (Brand = alpha, data cols = numeric on data-wom-val)
    panel.querySelectorAll('[data-wom-action="sort"]').forEach(function (th) {
      th.addEventListener("click", function () {
        var col = th.getAttribute("data-wom-sort-col") || "brand";
        var dir = th.getAttribute("data-wom-sort-dir") || "none";
        // Data-column default is DESC (most interesting first); Brand default is ASC.
        var next;
        if (dir === "none") next = (col === "brand") ? "asc" : "desc";
        else                next = (dir === "asc") ? "desc" : "asc";
        panel.querySelectorAll('[data-wom-action="sort"]').forEach(function (other) {
          if (other !== th) other.setAttribute("data-wom-sort-dir", "none");
        });
        th.setAttribute("data-wom-sort-dir", next);
        sortTable(panel, table, col, next);
        reflowChart(panel);
      });
    });

    // --- Show chart toggle
    panel.querySelectorAll('[data-wom-action="showchart"]').forEach(function (cb) {
      cb.addEventListener("change", function () {
        var scope = cb.getAttribute("data-wom-scope");
        var sel   = '.wom-chart-section[data-wom-scope="' + cssEscape(scope) + '"]';
        var sec   = panel.querySelector(sel);
        if (!sec) return;
        if (cb.checked) sec.removeAttribute("hidden");
        else             sec.setAttribute("hidden", "");
        syncVariantControlDisabled(panel, cb.checked);
      });
    });

    // --- Heard / Said variant selector
    panel.querySelectorAll('[data-wom-action="variant"]').forEach(function (btn) {
      btn.addEventListener("click", function () {
        var variant = btn.getAttribute("data-wom-variant");
        if (!variant) return;
        switchChartVariant(panel, variant);
      });
    });

    // Ensure variant control reflects initial Show chart state
    var cb0 = panel.querySelector('[data-wom-action="showchart"]');
    syncVariantControlDisabled(panel, cb0 ? cb0.checked : false);

    // Initial chart reflow so bar order matches the table's initial
    // (alphabetical) competitor order — chart is built focal-first then
    // net DESC, but the table ships alphabetical.
    reflowChart(panel);
  }

  function switchChartVariant(panel, variant) {
    panel.querySelectorAll('[data-wom-action="variant"]').forEach(function (btn) {
      var active = btn.getAttribute("data-wom-variant") === variant;
      btn.classList.toggle("active", active);
      btn.setAttribute("aria-selected", active ? "true" : "false");
    });
    var sec = panel.querySelector(".wom-chart-section");
    if (sec) sec.setAttribute("data-wom-variant", variant);
    panel.querySelectorAll(".wom-chart-variant").forEach(function (wrap) {
      var match = wrap.getAttribute("data-wom-variant") === variant;
      if (match) wrap.removeAttribute("hidden");
      else       wrap.setAttribute("hidden", "");
    });
  }

  function syncVariantControlDisabled(panel, enabled) {
    var host = panel.querySelector(".wom-chart-controls");
    if (!host) return;
    if (enabled) host.removeAttribute("aria-disabled");
    else         host.setAttribute("aria-disabled", "true");
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

    // Reset all sort indicators — repin implies alpha order
    panel.querySelectorAll('[data-wom-action="sort"]').forEach(function (th) {
      th.setAttribute("data-wom-sort-dir", "none");
    });

    reflowChart(panel);
  }

  // Sort competitor rows by `col` in `dir`. Focal + cat-avg stay pinned.
  //   col === "brand": alphabetical on data-wom-sort-key
  //   else:            numeric on td[data-wom-col=col]'s data-wom-val
  function sortTable(panel, table, col, dir) {
    var tbody = table.querySelector("tbody");
    if (!tbody) return;
    var rows = Array.prototype.slice.call(tbody.querySelectorAll("tr"));
    var focalRow = null, avgRow = null, compRows = [];
    rows.forEach(function (tr) {
      if (tr.classList.contains("wom-row-avg"))        avgRow = tr;
      else if (tr.classList.contains("wom-row-focal")) focalRow = tr;
      else if (tr.classList.contains("wom-row"))       compRows.push(tr);
    });

    if (col === "brand") {
      compRows.sort(function (a, b) {
        var la = a.dataset.womSortKey || "";
        var lb = b.dataset.womSortKey || "";
        return dir === "desc" ? lb.localeCompare(la) : la.localeCompare(lb);
      });
    } else {
      compRows.sort(function (a, b) {
        var va = rowValueForCol(a, col);
        var vb = rowValueForCol(b, col);
        var aBad = !isFinite(va), bBad = !isFinite(vb);
        if (aBad && bBad) return 0;
        if (aBad) return 1;   // NaNs last regardless of dir
        if (bBad) return -1;
        return dir === "desc" ? vb - va : va - vb;
      });
    }

    if (focalRow) tbody.appendChild(focalRow);
    if (avgRow)   tbody.appendChild(avgRow);
    compRows.forEach(function (tr) { tbody.appendChild(tr); });
  }

  function rowValueForCol(tr, col) {
    var td = tr.querySelector('td[data-wom-col="' + cssEscape(col) + '"]');
    if (!td) return NaN;
    var raw = td.getAttribute("data-wom-val");
    if (raw === null || raw === "") return NaN;
    var v = parseFloat(raw);
    return isFinite(v) ? v : NaN;
  }

  // Reflow SVG bar groups so the chart mirrors the table's current visible
  // row order. Hidden brands -> display:none; visible brands get a
  // translate(0, dy) transform where dy = (newIdx - originalIdx) * step.
  function reflowChart(panel) {
    var table = panel.querySelector(".wom-table");
    if (!table) return;

    var focalCode = null;
    var focalRow = table.querySelector("tr.wom-row-focal");
    if (focalRow) focalCode = focalRow.getAttribute("data-wom-brand");

    // Visible competitor order (table row order)
    var visibleOrdered = [];
    if (focalCode) visibleOrdered.push(focalCode);
    table.querySelectorAll("tbody tr.wom-row").forEach(function (tr) {
      if (tr.classList.contains("wom-row-focal")) return;
      if (tr.classList.contains("wom-row-hidden")) return;
      var bc = tr.getAttribute("data-wom-brand");
      if (bc) visibleOrdered.push(bc);
    });

    panel.querySelectorAll(".wom-chart-svg").forEach(function (svg) {
      var step = parseFloat(svg.getAttribute("data-wom-step")) || 30;
      svg.querySelectorAll("g.wom-bar-row").forEach(function (g) {
        var bc = g.getAttribute("data-wom-brand");
        var origIdx = parseInt(g.getAttribute("data-wom-original-idx"), 10);
        if (!isFinite(origIdx)) origIdx = 0;
        var newIdx = visibleOrdered.indexOf(bc);
        if (newIdx < 0) {
          g.style.display = "none";
          g.removeAttribute("transform");
        } else {
          g.style.display = "";
          var deltaY = (newIdx - origIdx) * step;
          if (Math.abs(deltaY) < 0.01) g.removeAttribute("transform");
          else g.setAttribute("transform", "translate(0," + deltaY + ")");
        }
      });
    });
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
