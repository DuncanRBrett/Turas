/* ==============================================================================
 * BRAND MODULE - DEMOGRAPHICS PANEL JS (matrix layout v2)
 * ==============================================================================
 * Wires the Demographics matrix panel:
 *   - Global controls: n counts / heatmap checkboxes (re-paint cells)
 *   - Focal-brand picker: chips re-issue a re-render of column 2 across cards
 *   - Brand-visibility chips: hide/show specific per-brand columns
 *   - Question chips: hide/show whole question cards
 *   - Per-card view toggle: table ↔ chart
 *
 * State lives on the panel root element (panel.__state). Mutating any input
 * re-applies the relevant DOM attributes — we do not re-render full HTML
 * because the matrix is already laid out by the R renderer; we just toggle
 * visibility and inline-style cells.
 *
 * Pin / PNG / Excel buttons reuse the global brTogglePin / brExportPng /
 * _brExportPanel functions wired by brand_pins.js / brand_report.js.
 * ==============================================================================*/

(function () {
  "use strict";

  function init(panel) {
    if (!panel || panel.__demoMatrixInit) return;
    panel.__demoMatrixInit = true;

    const data = readPanelData(panel);
    if (!data || !data.questions || !data.questions.length) return;
    panel.__data = data;
    panel.__state = {
      focal:        (data.meta && data.meta.focal_brand) || null,
      hiddenBrands: new Set(),
      hiddenQs:     new Set(),
      showCounts:   false,
      showHeatmap:  true,
      viewByCard:   {} // sectionId -> "table" | "chart"
    };

    bindGlobalToggles(panel);
    bindFocalPicker(panel);
    bindBrandChips(panel);
    bindQuestionChips(panel);
    bindCardViewToggles(panel);

    // Initial paint reflects default state (heatmap on, counts/CI off).
    applyHeatmap(panel);
    applyCellExtras(panel);
  }

  // ---- panel data ----
  function readPanelData(panel) {
    const node = panel.querySelector(".demo-panel-data");
    if (!node) return null;
    try { return JSON.parse(node.textContent || "{}"); }
    catch (e) { console.warn("[demographics] bad JSON payload", e); return null; }
  }

  // ---- global toggles (n counts / heatmap) ----
  function bindGlobalToggles(panel) {
    panel.querySelectorAll('input[data-demo-toggle]').forEach(input => {
      input.addEventListener("change", () => {
        const k = input.getAttribute("data-demo-toggle");
        if      (k === "counts")  { panel.__state.showCounts  = input.checked; applyCellExtras(panel); }
        else if (k === "heatmap") { panel.__state.showHeatmap = input.checked; applyHeatmap(panel); }
      });
    });
  }

  // Show / hide the .demo-cell-n spans across the panel. R renderer
  // emits them with hidden — JS just toggles the attribute.
  function applyCellExtras(panel) {
    const showN = panel.__state.showCounts;
    panel.querySelectorAll(".demo-cell-n").forEach(el => {
      el.toggleAttribute("hidden", !showN);
    });
  }

  // Apply the per-cell heat colour stashed on data-demo-heat. When heatmap
  // is off we clear background-color so the white cell shows through.
  function applyHeatmap(panel) {
    const on = panel.__state.showHeatmap;
    panel.querySelectorAll('td[data-demo-col="brand"], td[data-demo-col="focal"]').forEach(td => {
      const heat = td.getAttribute("data-demo-heat") || "";
      td.style.backgroundColor = (on && heat) ? heat : "";
    });
  }

  // ---- focal-brand picker ----
  // <select> dropdown — picks which brand sits in column 2 ("Focal").
  // Replaces the earlier chip strip; full per-cohort exploration is the
  // tabs module's job, this stays a quick comparison.
  function bindFocalPicker(panel) {
    const sel = panel.querySelector("[data-demo-focal-select]");
    if (!sel) return;
    sel.addEventListener("change", () => {
      panel.__state.focal = sel.value || panel.__state.focal;
      rerenderAllTables(panel);
    });
  }

  // Re-render every visible card's matrix table AND chart by rebuilding
  // both in JS. (Matches the R rendering shape exactly — same data
  // attributes so brand-visibility / heatmap / counts toggles continue
  // to work.) Called whenever the focal-brand dropdown changes.
  function rerenderAllTables(panel) {
    const data = panel.__data;
    const dp   = (data.config && data.config.decimal_places) || 0;
    const focal = panel.__state.focal;
    const brands = (data.brands && data.brands.codes)  || [];
    const labels = (data.brands && data.brands.labels) || brands;
    const palette = brandPalette(data, brands);
    const fi = brands.indexOf(focal);
    const focalLabel = fi >= 0 ? (labels[fi] || focal) : (focal || "");

    panel.querySelectorAll(".demo-card").forEach(card => {
      const idx = parseInt(card.getAttribute("data-demo-q-idx"), 10);
      const q   = data.questions[idx];
      if (!q) return;
      const tableHost = card.querySelector(".demo-card-view-table");
      if (tableHost) tableHost.innerHTML = renderMatrix(q, focal, data, dp);
      const chartHost = card.querySelector(".demo-card-view-chart");
      if (chartHost) chartHost.innerHTML = renderChart(q, focal, focalLabel,
                                                       palette, dp);
    });
    applyHeatmap(panel);
    applyCellExtras(panel);
    applyBrandVisibility(panel);
  }

  // ---- brand-visibility chips ----
  function bindBrandChips(panel) {
    panel.querySelectorAll(".demo-brand-chip").forEach(chip => {
      chip.addEventListener("click", () => {
        const bc = chip.getAttribute("data-demo-brand");
        const off = chip.classList.toggle("active") === false;
        if (off) panel.__state.hiddenBrands.add(bc);
        else     panel.__state.hiddenBrands.delete(bc);
        applyBrandVisibility(panel);
        refreshAllToggleLabel(panel);
      });
    });

    // Show all / Hide all toggle — flips every brand chip in lock-step.
    panel.querySelectorAll('button[data-demo-action="toggleall"]').forEach(btn => {
      btn.addEventListener("click", () => {
        const chips = Array.from(panel.querySelectorAll(".demo-brand-chip"));
        const allOn = chips.every(c => c.classList.contains("active"));
        const nextState = !allOn;          // if every chip is on, hide all; else show all
        chips.forEach(c => {
          const bc = c.getAttribute("data-demo-brand");
          c.classList.toggle("active", nextState);
          if (nextState) panel.__state.hiddenBrands.delete(bc);
          else           panel.__state.hiddenBrands.add(bc);
        });
        applyBrandVisibility(panel);
        btn.textContent = nextState ? "Hide all" : "Show all";
      });
    });
    refreshAllToggleLabel(panel);
  }

  // Keep the toggle-all button label in sync with current chip state.
  function refreshAllToggleLabel(panel) {
    const btn = panel.querySelector('button[data-demo-action="toggleall"]');
    if (!btn) return;
    const chips = panel.querySelectorAll(".demo-brand-chip");
    const allOn = Array.from(chips).every(c => c.classList.contains("active"));
    btn.textContent = allOn ? "Hide all" : "Show all";
  }

  function applyBrandVisibility(panel) {
    const hidden = panel.__state.hiddenBrands;
    panel.querySelectorAll('[data-demo-col="brand"][data-demo-brand]').forEach(el => {
      el.style.display = hidden.has(el.getAttribute("data-demo-brand")) ? "none" : "";
    });
  }

  // ---- question chips ----
  function bindQuestionChips(panel) {
    panel.querySelectorAll(".demo-q-chip").forEach(chip => {
      chip.addEventListener("click", () => {
        const idx = chip.getAttribute("data-demo-q-idx");
        const off = chip.classList.toggle("active") === false;
        if (off) panel.__state.hiddenQs.add(idx);
        else     panel.__state.hiddenQs.delete(idx);
        const card = panel.querySelector(`.demo-card[data-demo-q-idx="${idx}"]`);
        if (card) card.classList.toggle("hidden", off);
      });
    });
  }

  // ---- per-card table ↔ chart toggle ----
  function bindCardViewToggles(panel) {
    panel.querySelectorAll(".demo-card-toolbar").forEach(toolbar => {
      const card = toolbar.closest(".demo-card");
      if (!card) return;
      toolbar.querySelectorAll('[data-demo-view]').forEach(btn => {
        btn.addEventListener("click", () => {
          const view = btn.getAttribute("data-demo-view");
          toolbar.querySelectorAll('[data-demo-view]').forEach(b => b.classList.remove("active"));
          btn.classList.add("active");
          card.querySelectorAll(".demo-card-view").forEach(v => v.toggleAttribute("hidden", true));
          const target = card.querySelector(".demo-card-view-" + view);
          if (target) target.toggleAttribute("hidden", false);
          panel.__state.viewByCard[card.id] = view;
        });
      });
    });
  }

  // ============================================================================
  // RENDERER (mirrors the R matrix-table builder so focal swaps don't need a
  // round-trip to the engine). Kept short by sharing helpers.
  // ============================================================================

  function renderMatrix(q, focalBrand, data, dp) {
    const rows = (q.total && q.total.rows) || [];
    if (!rows.length) return '<div class="demo-empty">No responses for this question.</div>';

    const brands = (data.brands && data.brands.codes)  || [];
    const labels = (data.brands && data.brands.labels) || brands;
    const order  = brandOrder(brands, focalBrand);
    const palette = brandPalette(data, brands);

    return `<div class="demo-matrix-wrap"><table class="demo-matrix">
      ${tableHeader(brands, labels, order, focalBrand, palette)}
      ${tableBody(rows, q, brands, order, focalBrand, dp)}
    </table></div>`;
  }

  function brandOrder(brands, focal) {
    const out = [];
    const fi = brands.indexOf(focal);
    if (fi >= 0) out.push(fi);
    brands.forEach((b, i) => { if (i !== fi) out.push(i); });
    return out;
  }

  function brandPalette(data, brands) {
    const fromR = (data.brands && data.brands.colours) || {};
    const fallback = ["#1A5276","#B7950B","#196F3D","#7E5109","#6C3483","#1E8449",
                      "#A04000","#5D6D7E","#922B21","#4A235A"];
    const out = {};
    let fb = 0;
    brands.forEach(bc => {
      out[bc] = fromR[bc] || fallback[fb++ % fallback.length];
    });
    return out;
  }

  function tableHeader(brands, labels, order, focal, palette) {
    const brandTh = order.map(i => {
      const bc = brands[i], bl = labels[i] || bc;
      const cls = (bc === focal) ? "demo-col-focal" : "";
      return `<th class="${cls}" data-demo-col="brand" data-demo-brand="${esc(bc)}">
        <span class="demo-brand-chip-swatch" style="background:${esc(palette[bc] || "#94a3b8")}"></span> ${esc(bl)}
      </th>`;
    }).join("");
    const fi = brands.indexOf(focal);
    const focalLabel = (fi >= 0 ? (labels[fi] || focal) : focal) || "Focal";
    return `<thead><tr>
      <th>Option</th>
      <th class="demo-col-focal" data-demo-col="focal">${esc(focalLabel)}<span class="demo-th-sub">focal</span></th>
      <th class="demo-col-catavg" data-demo-col="catavg">Cat avg</th>
      ${brandTh}
    </tr></thead>`;
  }

  function tableBody(rows, q, brands, order, focal, dp) {
    const byBrand = {};
    (q.brand_cut || []).forEach(b => { byBrand[b.brand_code] = b; });
    const trs = rows.map(r => {
      const cat = r.pct;
      const focalCell = brandCell(byBrand[focal], r.code, cat, dp,
                                    "demo-col-focal", "focal", focal);
      const avgCell = catAvgCell(r, dp);
      const perBrandCells = order
        .map(i => brands[i])
        .map(bc => brandCell(byBrand[bc], r.code, cat, dp,
                              (bc === focal ? "demo-col-focal" : ""), "brand", bc))
        .join("");
      return `<tr>
        <td>${esc(r.label || r.code)}</td>
        ${focalCell}${avgCell}${perBrandCells}
      </tr>`;
    }).join("");
    return `<tbody>${trs}</tbody>`;
  }

  function brandCell(brandEntry, code, catPct, dp, extraClass, colcode, brandCode) {
    if (!brandEntry) return naCell(extraClass, colcode, brandCode);
    const cell = (brandEntry.cells || []).find(c => c.code === code);
    if (!cell) return naCell(extraClass, colcode, brandCode);
    const pct = cell.pct;
    const diff = (catPct != null && isFinite(catPct) && pct != null && isFinite(pct))
                 ? (pct - catPct) : null;
    const heat = heatColour(diff);
    const baseN = brandEntry.base_n;
    const cellN = (isFinite(baseN) && isFinite(pct))
                   ? Math.round(baseN * pct / 100) : null;
    return `<td class="${extraClass}" data-demo-col="${colcode}" data-demo-brand="${esc(brandCode || "")}" data-demo-heat="${esc(heat)}">
      ${pctStr(pct, dp)}${countSpan(cellN)}
    </td>`;
  }

  function catAvgCell(r, dp) {
    return `<td class="demo-col-catavg" data-demo-col="catavg">
      ${pctStr(r.pct, dp)}${countSpan(r.n)}
    </td>`;
  }

  function naCell(extraClass, colcode, brandCode) {
    return `<td class="${extraClass}" data-demo-col="${colcode}" data-demo-brand="${esc(brandCode || "")}">
      <span class="demo-na">&mdash;</span>
    </td>`;
  }

  function heatColour(diff) {
    if (diff == null || !isFinite(diff)) return "";
    const max = 30;
    const frac = Math.min(1, Math.abs(diff) / max);
    const alpha = (0.06 + frac * 0.50).toFixed(3);
    return diff >= 0 ? `rgba(37,99,171,${alpha})` : `rgba(192,57,43,${alpha})`;
  }

  function pctStr(v, dp) {
    if (v == null || !isFinite(v)) return '<span class="demo-na">&mdash;</span>';
    return v.toFixed(dp) + "%";
  }
  function countSpan(n) {
    if (n == null || !isFinite(n)) return "";
    return `<span class="demo-cell-n" hidden>n=${Math.round(n)}</span>`;
  }
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // ============================================================================
  // CHART RENDERER (mirrors build_demographics_matrix_chart in R, so the
  // chart re-renders client-side when focal changes — same colour, same
  // bar width math). The R-side renderer still produces the initial HTML
  // that ships in the report.
  // ============================================================================
  const CHART_MIN_BAR_WIDTH_PCT = 2;

  function renderChart(q, focalBrand, focalLabel, palette, dp) {
    const rows = (q.total && q.total.rows) || [];
    if (!rows.length) return '<div class="demo-empty">No responses for this question.</div>';

    const focalColour = palette[focalBrand] || "#1A5276";
    const focalEntry  = (q.brand_cut || []).find(b => b.brand_code === focalBrand) || null;
    const scaleMax    = chartScaleMax(rows, focalEntry);

    const bars = rows.map(r => chartRow(r, focalEntry, scaleMax, focalColour, dp)).join("");
    const legend = `<div class="demo-chart-legend">
      <span><span class="demo-chart-legend-swatch" style="background:${esc(focalColour)}"></span>${esc(focalLabel || focalBrand || "focal")}</span>
      <span>Marker: cat avg</span>
    </div>`;
    return `<div class="demo-chart-wrap">${bars}${legend}</div>`;
  }

  function chartScaleMax(rows, focalEntry) {
    let m = 0;
    rows.forEach(r => { if (isFinite(r.pct)) m = Math.max(m, r.pct); });
    if (focalEntry && Array.isArray(focalEntry.cells)) {
      focalEntry.cells.forEach(c => { if (isFinite(c.pct)) m = Math.max(m, c.pct); });
    }
    return (m > 0 && isFinite(m)) ? m : 100;
  }

  function chartRow(r, focalEntry, scaleMax, focalColour, dp) {
    const catPct = isFinite(r.pct) ? r.pct : NaN;
    const focalCell = focalEntry
      ? (focalEntry.cells || []).find(c => c.code === r.code)
      : null;
    const focalPct = (focalCell && isFinite(focalCell.pct)) ? focalCell.pct : NaN;

    const barW = isFinite(focalPct)
      ? Math.max(CHART_MIN_BAR_WIDTH_PCT, 100 * focalPct / scaleMax)
      : 0;
    const markerL = isFinite(catPct) ? (100 * catPct / scaleMax) : NaN;
    const marker = isFinite(markerL)
      ? `<div class="demo-chart-bar-marker" style="left:${markerL.toFixed(1)}%;" title="Cat avg ${pctStr(catPct, dp)}"></div>`
      : "";
    return `<div class="demo-chart-row">
      <div class="demo-chart-row-label">${esc(r.label || r.code)}</div>
      <div class="demo-chart-bar">
        <div class="demo-chart-bar-fill" style="width:${barW.toFixed(1)}%;background:${esc(focalColour)}"></div>
        ${marker}
      </div>
      <div class="demo-chart-row-value">${pctStr(focalPct, dp)}</div>
    </div>`;
  }

  // ---- bootstrap ----
  function bootAll() {
    document.querySelectorAll(".demo-panel").forEach(init);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bootAll);
  } else {
    bootAll();
  }
  // Re-init when category sub-tabs activate (panel may not exist at first paint)
  document.addEventListener("click", function (e) {
    if (e.target && e.target.closest && e.target.closest(".br-tab-btn, .br-subtab-btn")) {
      setTimeout(bootAll, 0);
    }
  });
})();
