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

    // Show all / Hide all toggle
    panel.querySelectorAll('[data-wom-action="toggleall"]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var focalRow = table.querySelector('tr.wom-row-focal');
        var focalCode = focalRow ? focalRow.getAttribute('data-wom-brand') : null;
        var chips = panel.querySelectorAll('[data-wom-action="toggle-row"]');
        var nonFocal = [];
        chips.forEach(function (c) {
          if (c.getAttribute('data-wom-brand') !== focalCode) nonFocal.push(c);
        });
        var allOn = nonFocal.every(function (c) { return c.classList.contains('active'); });
        var nextState = !allOn;
        nonFocal.forEach(function (c) {
          var bc = c.getAttribute('data-wom-brand');
          c.classList.toggle('active', nextState);
          var row = table.querySelector('tr[data-wom-brand="' + cssEscape(bc) + '"]');
          if (row) row.classList.toggle('wom-row-hidden', !nextState);
        });
        reflowChart(panel);
        btn.textContent = nextState ? 'Hide all' : 'Show all';
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

    // --- Show count toggle (Base column visibility)
    panel.querySelectorAll('[data-wom-action="showcounts"]').forEach(function (cb) {
      cb.addEventListener("change", function () {
        panel.querySelectorAll(".wom-col-base").forEach(function (el) {
          if (cb.checked) el.removeAttribute("hidden");
          else            el.setAttribute("hidden", "");
        });
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

    // Move the section toolbar (pin/png/excel) into the meta-row;
    // hide the insight toggle since WOM has its own inline insight box.
    relocateWomToolbar(panel);

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
    panel.querySelectorAll(".wom-variant-seg").forEach(function (seg) {
      if (enabled) seg.removeAttribute("aria-disabled");
      else         seg.setAttribute("aria-disabled", "true");
    });
  }

  function pinWomView(panel) {
    if (typeof TurasPins === "undefined") return;
    var table = panel.querySelector(".wom-table");
    var chartSection = panel.querySelector(".wom-chart-section:not([hidden])");
    var insightEl = panel.querySelector(".ma-insight-box-text");

    var tableHtml = table ? table.outerHTML : "";
    var chartSvg  = chartSection ? (chartSection.querySelector("svg") || {}).outerHTML || "" : "";
    var insight   = insightEl ? insightEl.value.trim() : "";

    var catCode = panel.getAttribute("data-cat-code") || "";
    TurasPins.add({
      title:   "Word of Mouth" + (catCode ? " — " + catCode : ""),
      html:    chartSvg + tableHtml,
      insight: insight
    });
  }

  function exportWomExcel(panel) {
    if (typeof brExportTableToExcel !== "function") return;
    var table = panel.querySelector(".wom-table");
    if (!table) return;
    var catCode = panel.getAttribute("data-cat-code") || "wom";
    brExportTableToExcel(table, "WOM_" + catCode);
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

    updateChartFocalBrand(panel, focalCode, accent);
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
      var step  = parseFloat(svg.getAttribute("data-wom-step")) || 30;
      var mt    = parseFloat(svg.getAttribute("data-wom-mt"))   || 58;
      var mb    = parseFloat(svg.getAttribute("data-wom-mb"))   || 26;
      var origN = parseInt(svg.getAttribute("data-wom-n"), 10)  || 0;
      var W     = parseFloat(svg.getAttribute("data-wom-w"))    || 760;

      // Reposition / hide bar groups
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

      // Shrink grid + axis to match visible row count, then resize viewBox.
      var nVis     = visibleOrdered.length || 1;
      var gridBot  = mt + nVis * step;
      var totalH   = gridBot + mb;

      svg.querySelectorAll("line.wom-grid-line, line.wom-center-line").forEach(function (ln) {
        ln.setAttribute("y2", String(gridBot));
      });
      svg.querySelectorAll("line.wom-avg-line").forEach(function (ln) {
        ln.setAttribute("y2", String(gridBot - 2));
      });
      svg.querySelectorAll("text.wom-axis-tick-label").forEach(function (t) {
        t.setAttribute("y", String(gridBot + 12));
      });
      svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
    });
  }

  // Update SVG chart focal visual state when the focal brand changes.
  // Toggles the background band, label weight/colour/diamond.
  function updateChartFocalBrand(panel, focalCode, accent) {
    panel.querySelectorAll(".wom-chart-svg g.wom-bar-row").forEach(function (g) {
      var bc = g.getAttribute("data-wom-brand");
      var isFocal = (bc === focalCode);
      g.setAttribute("data-wom-focal", isFocal ? "1" : "0");

      var band = g.querySelector(".wom-bar-focal-band");
      if (band) band.style.display = isFocal ? "" : "none";

      var lbl = g.querySelector(".wom-bar-label");
      if (lbl) {
        lbl.setAttribute("font-weight", isFocal ? "700" : "500");
        lbl.setAttribute("fill", isFocal ? accent : "#1e293b");
        var txt = (lbl.textContent || "").replace(/\s*\u25C6\s*$/, "").trim();
        lbl.textContent = isFocal ? txt + " \u25C6" : txt;
      }
    });
  }

  // Move the section toolbar (pin/png/excel) into the WOM meta-row so it
  // sits alongside the Show chart controls. Hides the +Add Insight toggle
  // since the WOM panel has its own inline insight box below the table.
  function relocateWomToolbar(panel) {
    var section = panel.closest(".br-element-section") || panel.parentNode;
    if (!section) return;
    var toolbar = section.querySelector(".br-section-toolbar");
    if (!toolbar) return;

    var insightToggle = toolbar.querySelector(".br-insight-toggle");
    if (insightToggle) insightToggle.style.display = "none";
    var insightContainer = section.querySelector(".br-insight-container");
    if (insightContainer) insightContainer.style.display = "none";

    var metaRow = panel.querySelector(".wom-meta-row");
    if (metaRow) {
      toolbar.style.margin = "";
      toolbar.style.marginBottom = "";
      toolbar.classList.add("wom-toolbar-relocated");
      metaRow.appendChild(toolbar);
    }
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
