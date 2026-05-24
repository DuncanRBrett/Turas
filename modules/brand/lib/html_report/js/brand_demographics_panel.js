/* ==============================================================================
 * BRAND MODULE - DEMOGRAPHICS PANEL JS (matrix layout v2)
 * ==============================================================================
 * SIZE-EXCEPTION: single panel controller — table + chart + focal picker +
 * three toggle behaviours share state on a single panel root element. Splitting
 * across files would force a JS module loader and scoped imports the rest of
 * the brand-module client code intentionally avoids. ~325 active lines.
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
      focal:         (data.meta && data.meta.focal_brand) || null,
      hiddenBrands:  new Set(),
      hiddenQs:      new Set(),
      showCounts:    false,
      showHeatmap:   true,
      showBuyer:     true,
      showNonbuyer:  true,
      cellMetric:    "penetration", // "penetration" | "share"
      baseline:      "cat",         // "cat" | "study" — affects Share mode only
      viewByCard:    {} // sectionId -> "table" | "chart"
    };

    bindGlobalToggles(panel);
    bindMetricRadios(panel);
    bindBaselineRadios(panel);
    bindFocalPicker(panel);
    bindBrandSelector(panel);
    bindQuestionChips(panel);
    bindCardViewToggles(panel);
    bindViewAllButtons(panel);

    // Initial paint reflects default state (heatmap on, counts off, both rows visible).
    applyHeatmap(panel);
    applyCellExtras(panel);
    applyRowToggles(panel);
    // Default metric = penetration, so the baseline group starts disabled.
    applyBaselineEnabledState(panel);
  }

  // ---- cell-metric radio (Penetration vs Share of buyers) ----
  function bindMetricRadios(panel) {
    panel.querySelectorAll('input[data-demo-metric]').forEach(input => {
      input.addEventListener("change", () => {
        if (!input.checked) return;
        panel.__state.cellMetric = input.getAttribute("data-demo-metric");
        applyBaselineEnabledState(panel);
        rerenderAllTables(panel);
      });
    });
  }

  // ---- baseline radio (Cat avg vs Total sample) ----
  // Affects Share-of-buyers mode: swaps the Cat-avg column + heatmap
  // shading + chart marker between the cat-buyer distribution (r.pct)
  // and the total-study-sample distribution (q.total_study_sample.rows[i].pct).
  // Penetration mode is unaffected because its baseline is per-option
  // mean brand pen (option_avg_penetration), not a sample distribution —
  // the baseline radios are visually disabled in Pen mode (see
  // applyBaselineEnabledState below) so the reader doesn't perceive a
  // broken control.
  function bindBaselineRadios(panel) {
    panel.querySelectorAll('input[data-demo-baseline]').forEach(input => {
      input.addEventListener("change", () => {
        if (!input.checked) return;
        panel.__state.baseline = input.getAttribute("data-demo-baseline");
        rerenderAllTables(panel);
      });
    });
  }

  // Toggle the baseline-radio group's disabled look + native input
  // disabled attribute based on the current cell-metric. The 'Baseline'
  // wrapper carries a data-demo-baseline-group marker rendered by the R
  // panel builder; we add .demo-disabled (CSS opacity / cursor) when in
  // Pen mode and a hover tooltip explaining why.
  function applyBaselineEnabledState(panel) {
    const wrap = panel.querySelector('[data-demo-baseline-group]');
    if (!wrap) return;
    const isPen = (panel.__state.cellMetric || "penetration") === "penetration";
    wrap.classList.toggle("demo-disabled", isPen);
    wrap.setAttribute(
      "title",
      isPen
        ? "Baseline only applies when Cells = '% of buyers'. In '% who buy' mode the cat-avg column reads from the per-option mean brand penetration regardless of which baseline is selected."
        : ""
    );
    wrap.querySelectorAll('input[data-demo-baseline]').forEach(input => {
      input.disabled = isPen;
    });
  }

  // ---- panel data ----
  function readPanelData(panel) {
    const node = panel.querySelector(".demo-panel-data");
    if (!node) return null;
    try { return JSON.parse(node.textContent || "{}"); }
    catch (e) { console.warn("[demographics] bad JSON payload", e); return null; }
  }

  // ---- global toggles (n counts / heatmap / buyer row / non-buyer row) ----
  function bindGlobalToggles(panel) {
    panel.querySelectorAll('input[data-demo-toggle]').forEach(input => {
      input.addEventListener("change", () => {
        const k = input.getAttribute("data-demo-toggle");
        if      (k === "counts")   { panel.__state.showCounts   = input.checked; applyCellExtras(panel); }
        else if (k === "heatmap")  { panel.__state.showHeatmap  = input.checked; applyHeatmap(panel); }
        else if (k === "buyer")    { panel.__state.showBuyer    = input.checked; applyRowToggles(panel); }
        else if (k === "nonbuyer") { panel.__state.showNonbuyer = input.checked; applyRowToggles(panel); }
      });
    });
  }

  // Toggle .demo-row-buyer / .demo-row-nonbuyer across all matrix tables via
  // panel root classes; CSS does the actual hide/show.
  function applyRowToggles(panel) {
    panel.classList.toggle("demo-hide-buyer",    !panel.__state.showBuyer);
    panel.classList.toggle("demo-hide-nonbuyer", !panel.__state.showNonbuyer);
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

    const metric   = panel.__state.cellMetric || "penetration";
    const baseline = panel.__state.baseline   || "cat";
    panel.querySelectorAll(".demo-card").forEach(card => {
      const idx = parseInt(card.getAttribute("data-demo-q-idx"), 10);
      const q   = data.questions[idx];
      if (!q) return;
      const tableHost = card.querySelector(".demo-card-view-table");
      if (tableHost) tableHost.innerHTML = renderMatrix(q, focal, data, dp, metric, baseline);
      const chartHost = card.querySelector(".demo-card-view-chart");
      if (chartHost) chartHost.innerHTML = renderChart(q, focal, focalLabel,
                                                       palette, dp, metric, baseline);
    });
    applyHeatmap(panel);
    applyCellExtras(panel);
    applyBrandVisibility(panel);
  }

  // ---- brand-visibility selector (dropdown) ----
  // Replaces the legacy chip strip. State (hiddenBrands Set) and the visibility
  // application (applyBrandVisibility) are unchanged — only the UI changed.
  function bindBrandSelector(panel) {
    const trigger = panel.querySelector('.bs-trigger[data-bs-panel="demographics"]');
    if (!trigger || typeof window.BrandSelector === "undefined") return;
    const data = panel.__data;
    const codes  = (data.brands && data.brands.codes)  || [];
    const labels = (data.brands && data.brands.labels) || codes;
    const focal  = panel.__state.focal;
    const palette = brandPalette(data, codes);
    const brandList = codes.map((c, i) => ({
      code:    c,
      label:   labels[i] || c,
      color:   palette[c] || "#94a3b8",
      isFocal: c === focal
    }));

    // panelId MUST be unique per panel instance. BrandSelector's REGISTRY is
    // keyed by panelId, so a hardcoded "demographics" string makes every
    // category panel overwrite the previous one's state — closeAll() then
    // can't find the actually-open popover and clicking outside doesn't
    // close it. Use the panel's DOM id as the natural anchor.
    window.BrandSelector.create({
      panelId:     panel.id || "demographics",
      categoryKey: (panel.id || "").replace(/^demo-panel-/, ""),
      triggerEl:   trigger,
      anchorEl:    trigger.parentElement,
      brands:      brandList,
      mode:        "unified",
      onChange:    function (hiddenSet) {
        panel.__state.hiddenBrands = new Set(hiddenSet);
        applyBrandVisibility(panel);
      }
    });
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
  function switchCardView(card, view) {
    const toolbar = card.querySelector(".demo-card-toolbar");
    if (toolbar) {
      toolbar.querySelectorAll('[data-demo-view]').forEach(b => b.classList.remove("active"));
      const active = toolbar.querySelector(`[data-demo-view="${view}"]`);
      if (active) active.classList.add("active");
    }
    card.querySelectorAll(".demo-card-view").forEach(v => v.toggleAttribute("hidden", true));
    const target = card.querySelector(".demo-card-view-" + view);
    if (target) target.toggleAttribute("hidden", false);
  }

  function bindCardViewToggles(panel) {
    panel.querySelectorAll(".demo-card-toolbar").forEach(toolbar => {
      const card = toolbar.closest(".demo-card");
      if (!card) return;
      toolbar.querySelectorAll('[data-demo-view]').forEach(btn => {
        btn.addEventListener("click", () => {
          const view = btn.getAttribute("data-demo-view");
          switchCardView(card, view);
          panel.__state.viewByCard[card.id] = view;
          refreshViewAllButtons(panel);
        });
      });
    });
  }

  // ---- global view-all buttons (All tables / All charts) ----
  function switchAllCards(panel, view) {
    panel.querySelectorAll(".demo-card").forEach(card => {
      if (card.classList.contains("hidden")) return;
      switchCardView(card, view);
      panel.__state.viewByCard[card.id] = view;
    });
    refreshViewAllButtons(panel);
  }

  function refreshViewAllButtons(panel) {
    const btns = panel.querySelectorAll(".demo-view-all-btn");
    if (!btns.length) return;
    const cards = Array.from(panel.querySelectorAll(".demo-card:not(.hidden)"));
    if (!cards.length) return;
    const views = cards.map(c => panel.__state.viewByCard[c.id] || "table");
    const allTable = views.every(v => v === "table");
    const allChart = views.every(v => v === "chart");
    btns.forEach(btn => {
      const action = btn.getAttribute("data-demo-action");
      btn.classList.toggle("active", action === "allTables" ? allTable : allChart);
    });
  }

  function bindViewAllButtons(panel) {
    panel.querySelectorAll(".demo-view-all-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        const action = btn.getAttribute("data-demo-action");
        if (action === "allTables") switchAllCards(panel, "table");
        else if (action === "allCharts") switchAllCards(panel, "chart");
      });
    });
  }

  // ============================================================================
  // RENDERER (mirrors the R matrix-table builder so focal swaps don't need a
  // round-trip to the engine). Kept short by sharing helpers.
  // ============================================================================

  function renderMatrix(q, focalBrand, data, dp, metric, baseline) {
    const rows = (q.total && q.total.rows) || [];
    if (!rows.length) return '<div class="demo-empty">No responses for this question.</div>';

    const brands = (data.brands && data.brands.codes)  || [];
    const labels = (data.brands && data.brands.labels) || brands;
    const order  = brandOrder(brands, focalBrand);
    const palette = brandPalette(data, brands);

    return `<div class="demo-matrix-wrap"><table class="demo-matrix">
      ${tableHeader(brands, labels, order, focalBrand, palette, baseline)}
      ${tableBody(rows, q, brands, order, focalBrand, dp, metric, baseline)}
    </table></div>`;
  }

  function brandOrder(brands, focal) {
    // Focal lives in its own pinned column 2; exclude it from the per-brand
    // block to avoid rendering the same brand twice.
    const out = [];
    const fi = brands.indexOf(focal);
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

  function tableHeader(brands, labels, order, focal, palette, baseline) {
    // Look up focal label from the ORIGINAL brand list (order excludes focal).
    const fi = brands.indexOf(focal);
    const focalLabel = (fi >= 0 ? (labels[fi] || focal) : focal) || "Focal";
    const brandTh = order.map(i => {
      const bc = brands[i], bl = labels[i] || bc;
      // order excludes focal — every entry here is a non-focal brand.
      return `<th class="" data-demo-col="brand" data-demo-brand="${esc(bc)}">
        <span class="demo-brand-chip-swatch" style="background:${esc(palette[bc] || "#94a3b8")}"></span> ${esc(bl)}
      </th>`;
    }).join("");
    const baselineLabel = baseline === "study" ? "Total sample" : "Cat avg";
    return `<thead><tr>
      <th>Option</th>
      <th class="demo-col-focal" data-demo-col="focal">${esc(focalLabel)}<span class="demo-th-sub">focal</span></th>
      <th class="demo-col-catavg" data-demo-col="catavg">${esc(baselineLabel)}</th>
      ${brandTh}
    </tr></thead>`;
  }

  // Dispatch on the current cell-metric mode. Same row structure (two rows
  // per option, focal pinned in column 2, per-brand block to the right) but
  // different cell semantics and shading baseline per mode — see penTableBody
  // and shareTableBody for the details.
  function tableBody(rows, q, brands, order, focal, dp, metric, baseline) {
    if (metric === "share") {
      return shareTableBody(rows, q, brands, order, focal, dp, baseline);
    }
    return penTableBody(rows, q, brands, order, focal, dp);
  }

  // Look up the baseline pct for a row in Share mode.
  //   baseline = "cat"   -> r.pct (% of CAT BUYERS in this option)
  //   baseline = "study" -> q.total_study_sample.rows[i].pct (% of ALL
  //                         screened study sample in this option)
  // The total_study_sample distribution is computed by the engine when
  // study_values is supplied; for backwards compatibility, if it's missing
  // the lookup falls back to r.pct (no toggle effect).
  function shareBaselinePct(q, r, baseline) {
    if (baseline !== "study") return r.pct;
    const ss = q.total_study_sample;
    if (!ss || !Array.isArray(ss.rows)) return r.pct;
    const hit = ss.rows.find(x => x.code === r.code);
    return (hit && isFinite(hit.pct)) ? hit.pct : r.pct;
  }

  // PENETRATION mode (default). Cell = "% of respondents in this option who
  // buy this brand". Non-buyer row = complement (100 − buyer). Heat colour
  // is driven by (buyer pct − per-option avg brand pen), so blue = brand
  // over-performs vs the typical brand in this demographic; red = under-
  // performs. Buyer + non-buyer rows share the same colour and direction.
  function penTableBody(rows, q, brands, order, focal, dp) {
    const penBy     = indexByBrand(q.brand_penetration_long);
    const optionAvg = q.option_avg_penetration || {};
    const trs = rows.map(r => {
      const catPct = optionAvgPct(optionAvg, r.code);
      const optLabel = esc(r.label || r.code);
      const buyerRow = penRow({
        role: "buyer",
        labelCell: optLabelCell(optLabel, "buyer"),
        brandIndex: penBy, catPct,
        code: r.code, catAvgCell: catAvgPenCell(catPct, dp),
        brands, order, focal, complement: false, dp
      });
      const nonbuyerRow = penRow({
        role: "nonbuyer",
        labelCell: optLabelCell(optLabel, "non-buyer"),
        brandIndex: penBy, catPct,
        code: r.code,
        catAvgCell: '<td class="demo-col-catavg demo-cell-blank" data-demo-col="catavg"></td>',
        brands, order, focal, complement: true, dp
      });
      return buyerRow + nonbuyerRow;
    }).join("");
    return `<tbody>${trs}</tbody>`;
  }

  // Build the option label cell for either row type. Both pieces (option
  // name + role chip) always rendered so the row is self-identifying when
  // the sibling row is toggled off.
  function optLabelCell(optLabel, role) {
    const roleCls = role === "non-buyer"
      ? "demo-opt-role demo-opt-role-nonbuyer"
      : "demo-opt-role";
    return `<td class="demo-opt-label">
      <span class="demo-opt-name">${optLabel}</span><span class="${roleCls}">${role}</span>
    </td>`;
  }

  function penRow(p) {
    const focalCell = penCell(p.brandIndex[p.focal], p.catPct,
                                p.code, p.dp, p.complement,
                                "demo-col-focal", "focal", p.focal);
    const perBrand = p.order
      .map(i => p.brands[i])
      .map(bc => penCell(p.brandIndex[bc], p.catPct,
                          p.code, p.dp, p.complement,
                          "", "brand", bc))
      .join("");
    return `<tr class="demo-row-${p.role}">${p.labelCell}${focalCell}${p.catAvgCell}${perBrand}</tr>`;
  }

  // Per-option avg brand pen lookup (mirrors R's option_avg_penetration map).
  function optionAvgPct(optionAvg, code) {
    const entry = (optionAvg || {})[String(code)];
    if (!entry || entry.pct == null || !isFinite(entry.pct)) return NaN;
    return entry.pct;
  }

  // Cat-avg cell for penetration mode — shows the per-option mean brand pen
  // (the typical brand's pen rate in this demographic).
  function catAvgPenCell(catPct, dp) {
    return `<td class="demo-col-catavg" data-demo-col="catavg">${pctStr(catPct, dp)}</td>`;
  }

  function indexByBrand(brandLong) {
    const out = {};
    (brandLong || []).forEach(b => { out[b.brand_code] = b; });
    return out;
  }

  // Penetration cell. complement=true flips the displayed value to 100-buyer
  // (the non-buyer share within the option). Heat colour driven by the buyer
  // gap vs the per-option avg brand pen (catPct) so buyer + non-buyer rows
  // carry the same competitive direction.
  function penCell(entry, catPct, code, dp, complement, extraClass, colcode, brandCode) {
    if (!entry) return naCell(extraClass, colcode, brandCode);
    const cell = (entry.cells || []).find(c => c.code === code);
    if (!cell) return naCell(extraClass, colcode, brandCode);
    const buyerPct = cell.pct;
    const shown = (complement && buyerPct != null && isFinite(buyerPct))
                    ? (100 - buyerPct) : buyerPct;
    const buyerDiff = (buyerPct != null && isFinite(buyerPct)
                       && catPct != null && isFinite(catPct))
                      ? (buyerPct - catPct) : null;
    const heat = heatColour(buyerDiff);
    const cellN = penCellN(cell, buyerPct, complement);
    return `<td class="${extraClass}" data-demo-col="${colcode}" data-demo-brand="${esc(brandCode || "")}" data-demo-heat="${esc(heat)}">${pctStr(shown, dp)}${countSpan(cellN)}</td>`;
  }

  function penCellN(cell, buyerPct, complement) {
    const baseInOpt = cell.base_n_in_option;
    if (baseInOpt == null || !isFinite(baseInOpt)
        || buyerPct == null || !isFinite(buyerPct)) return null;
    const buyerN = Math.round(baseInOpt * buyerPct / 100);
    return complement ? (baseInOpt - buyerN) : buyerN;
  }

  // SHARE OF BUYERS mode. Cell = "% of this brand's buyers who fall in this
  // option" (audience-share). The buyer row sums to 100% down a brand column;
  // the non-buyer row is a SEPARATE distribution (% of brand's non-buyers in
  // this option) and also sums to 100% down its column. Heat colour is the
  // gap vs Cat avg (% of cat respondents in this option) — the audience-share
  // baseline, restored from v1.
  function shareTableBody(rows, q, brands, order, focal, dp, baseline) {
    const buyerBy    = indexByBrand(q.brand_cut);
    const nonbuyerBy = indexByBrand(q.brand_nonbuyer_cut);
    const trs = rows.map(r => {
      const catPct = shareBaselinePct(q, r, baseline);
      const optLabel = esc(r.label || r.code);
      const buyerRow = shareRow({
        role: "buyer",
        labelCell: optLabelCell(optLabel, "buyer"),
        brandIndex: buyerBy,
        code: r.code, catPct,
        catAvgCell: catAvgCellBaseline(catPct, r, dp, baseline),
        brands, order, focal, dp
      });
      const nonbuyerRow = shareRow({
        role: "nonbuyer",
        labelCell: optLabelCell(optLabel, "non-buyer"),
        brandIndex: nonbuyerBy,
        code: r.code, catPct,
        catAvgCell: '<td class="demo-col-catavg demo-cell-blank" data-demo-col="catavg"></td>',
        brands, order, focal, dp
      });
      return buyerRow + nonbuyerRow;
    }).join("");
    return `<tbody>${trs}</tbody>`;
  }

  // Cat-avg cell for Share mode — displays the baseline pct chosen by the
  // user (cat-buyer distribution OR total-study-sample distribution).
  function catAvgCellBaseline(catPct, r, dp, baseline) {
    return `<td class="demo-col-catavg" data-demo-col="catavg">${pctStr(catPct, dp)}</td>`;
  }

  function shareRow(p) {
    const focalCell = shareCell(p.brandIndex[p.focal], p.code, p.catPct, p.dp,
                                  "demo-col-focal", "focal", p.focal);
    const perBrand = p.order
      .map(i => p.brands[i])
      .map(bc => shareCell(p.brandIndex[bc], p.code, p.catPct, p.dp,
                            "", "brand", bc))
      .join("");
    return `<tr class="demo-row-${p.role}">${p.labelCell}${focalCell}${p.catAvgCell}${perBrand}</tr>`;
  }

  // Share-of-audience cell. Pct = % of brand's buyers (or non-buyers) in
  // this option. Heat colour reflects (pct − cat avg in this option), i.e.
  // is this audience over- or under-represented in this option vs the
  // overall sample?
  function shareCell(entry, code, catPct, dp, extraClass, colcode, brandCode) {
    if (!entry) return naCell(extraClass, colcode, brandCode);
    const cell = (entry.cells || []).find(c => c.code === code);
    if (!cell) return naCell(extraClass, colcode, brandCode);
    const pct = cell.pct;
    const diff = (catPct != null && isFinite(catPct) && pct != null && isFinite(pct))
                  ? (pct - catPct) : null;
    const heat = heatColour(diff);
    const baseN = entry.base_n;
    const cellN = (baseN != null && isFinite(baseN) && pct != null && isFinite(pct))
                   ? Math.round(baseN * pct / 100) : null;
    return `<td class="${extraClass}" data-demo-col="${colcode}" data-demo-brand="${esc(brandCode || "")}" data-demo-heat="${esc(heat)}">${pctStr(pct, dp)}${countSpan(cellN)}</td>`;
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

  function renderChart(q, focalBrand, focalLabel, palette, dp, metric, baseline) {
    const rows = (q.total && q.total.rows) || [];
    if (!rows.length) return '<div class="demo-empty">No responses for this question.</div>';

    const focalColour = palette[focalBrand] || "#1A5276";
    const ctx = chartModeCtx(q, focalBrand, metric, baseline);
    const scaleMax = chartScaleMax(rows, ctx);

    // One row per option — buyer view only. Detail buyer-vs-non-buyer is
    // in the table; the chart's job is the at-a-glance bar comparison
    // which is purely a buyer-row read.
    const bars = rows.map(r => chartRow(r, ctx, scaleMax, focalColour, dp)).join("");
    const legend = chartLegend(ctx, focalBrand, focalLabel, focalColour);
    return `<div class="demo-chart-wrap">${bars}${legend}</div>`;
  }

  // Legend: focal swatch + primary-marker label + optional secondary-marker
  // label (penetration mode only).
  function chartLegend(ctx, focalBrand, focalLabel, focalColour) {
    const primary = `<span><span class="demo-chart-legend-swatch-line"></span>${esc(ctx.markerLabel)}</span>`;
    const secondary = (ctx.mode === "penetration" && isFinite(ctx.overallPen))
      ? `<span><span class="demo-chart-legend-swatch-line-dashed"></span>${esc(ctx.overallMarkerLabel)}</span>`
      : "";
    return `<div class="demo-chart-legend">
      <span><span class="demo-chart-legend-swatch" style="background:${esc(focalColour)}"></span>${esc(focalLabel || focalBrand || "focal")}</span>
      ${primary}
      ${secondary}
    </div>`;
  }

  // Resolve which long-list drives the bars and what each marker means for
  // the requested metric mode. Mirrors .demo_chart_mode_ctx in R.
  function chartModeCtx(q, focalBrand, metric, baseline) {
    if (metric === "share") {
      const focalEntry    = (q.brand_cut || []).find(b => b.brand_code === focalBrand) || null;
      const nonbuyerEntry = (q.brand_nonbuyer_cut || []).find(b => b.brand_code === focalBrand) || null;
      const useStudy = baseline === "study";
      return {
        mode: "share",
        focalEntry: focalEntry,
        nonbuyerEntry: nonbuyerEntry,
        // share mode marker reads r.pct (cat) or total_study_sample (study)
        optionAvg: null,
        baseline: useStudy ? "study" : "cat",
        studyTotal: useStudy ? (q.total_study_sample || null) : null,
        markerLabel: useStudy ? "total sample" : "cat avg",
        overallPen: NaN,
        overallMarkerLabel: ""
      };
    }
    // default: penetration. Two markers per row:
    //   primary  = mean brand pen in that option (per-row)
    //   secondary = focal's cat-wide overall pen (constant; dashed line)
    const focalEntry = (q.brand_penetration_long || []).find(b => b.brand_code === focalBrand) || null;
    const totalPenMap = q.brand_total_penetration || {};
    const totalPenFocal = totalPenMap[focalBrand];
    const overallPen = (totalPenFocal && isFinite(totalPenFocal.pct)) ? totalPenFocal.pct : NaN;
    return {
      mode: "penetration",
      focalEntry: focalEntry,
      nonbuyerEntry: null,   // pen mode derives non-buyer as 100 - buyer
      optionAvg: q.option_avg_penetration || {},
      markerLabel: "avg brand pen in option",
      overallPen: overallPen,
      overallMarkerLabel: isFinite(overallPen)
        ? `${focalBrand || "focal"} overall pen (${overallPen.toFixed(1)}%)`
        : ""
    };
  }

  // Per-row marker value lookup. Pen mode reads from ctx.optionAvg[code];
  // share mode reads r.pct (cat baseline) or the total-study-sample row pct
  // (study baseline). Falls back to r.pct if study data is missing.
  function chartMarkerPct(ctx, r) {
    if (ctx.mode === "share") {
      if (ctx.baseline === "study" && ctx.studyTotal &&
          Array.isArray(ctx.studyTotal.rows)) {
        const hit = ctx.studyTotal.rows.find(x => x.code === r.code);
        if (hit && isFinite(hit.pct)) return hit.pct;
      }
      return isFinite(r.pct) ? r.pct : NaN;
    }
    const entry = (ctx.optionAvg || {})[String(r.code)];
    if (!entry || entry.pct == null || !isFinite(entry.pct)) return NaN;
    return entry.pct;
  }

  // Scale-max considers ONLY values drawn on the chart (buyer focal bars,
  // per-row primary marker, optional global secondary marker).
  function chartScaleMax(rows, ctx) {
    let m = 0;
    if (ctx.focalEntry && Array.isArray(ctx.focalEntry.cells)) {
      ctx.focalEntry.cells.forEach(c => { if (isFinite(c.pct)) m = Math.max(m, c.pct); });
    }
    rows.forEach(r => {
      const mp = chartMarkerPct(ctx, r);
      if (isFinite(mp)) m = Math.max(m, mp);
    });
    if (ctx.mode === "penetration" && isFinite(ctx.overallPen)) {
      m = Math.max(m, ctx.overallPen);
    }
    return (m > 0 && isFinite(m)) ? m : 100;
  }

  function chartRow(r, ctx, scaleMax, focalColour, dp) {
    const focalCell = ctx.focalEntry
      ? (ctx.focalEntry.cells || []).find(c => c.code === r.code)
      : null;
    const focalPct = (focalCell && isFinite(focalCell.pct)) ? focalCell.pct : NaN;
    const markerPct = chartMarkerPct(ctx, r);

    const barW = isFinite(focalPct)
      ? Math.max(CHART_MIN_BAR_WIDTH_PCT, 100 * focalPct / scaleMax)
      : 0;

    let marker = "";
    let markerValue = "";
    if (isFinite(markerPct)) {
      const markerL = 100 * markerPct / scaleMax;
      marker = `<div class="demo-chart-bar-marker" style="left:${markerL.toFixed(1)}%;" title="${esc(ctx.markerLabel)} ${pctStr(markerPct, dp)}"></div>`;
      markerValue = `<div class="demo-chart-bar-marker-value" style="left:${markerL.toFixed(1)}%;">${pctStr(markerPct, dp)}</div>`;
    }

    let overallMarker = "";
    if (ctx.mode === "penetration" && isFinite(ctx.overallPen)) {
      const overallL = 100 * ctx.overallPen / scaleMax;
      overallMarker = `<div class="demo-chart-bar-marker-overall" style="left:${overallL.toFixed(1)}%;" title="${esc(ctx.overallMarkerLabel)}"></div>`;
    }

    return `<div class="demo-chart-row">
      <div class="demo-chart-row-label">
        <span class="demo-chart-opt-name">${esc(r.label || r.code)}</span><span class="demo-chart-role">buyer</span>
      </div>
      <div class="demo-chart-bar">
        ${markerValue}
        <div class="demo-chart-bar-fill" style="width:${barW.toFixed(1)}%;background:${esc(focalColour)}"></div>
        ${marker}${overallMarker}
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
