/* ==============================================================================
 * BRAND MODULE - DEMOGRAPHICS PANEL JS
 * ==============================================================================
 * Wires the Demographics tab interactivity:
 *   - Question chip toggle (show/hide individual question cards)
 *   - Sub-tab switch (Total | Buyer | Tier | By brand) re-renders each card
 *   - Per-card brand picker (visible only on the "By brand" sub-tab)
 *   - Per-card CI overlay toggle
 *   - Heatmap cell colouring on the by-brand and tier sub-tabs
 *
 * Panel data lives in <script class="demo-panel-data"> as JSON; we hydrate
 * once on first interaction and cache on the panel root element.
 *
 * Pin / PNG buttons reuse the existing brTogglePin / brExportPng handlers
 * from brand_pins.js — nothing custom required here.
 * ==============================================================================*/

(function () {
  "use strict";

  function init(panel) {
    if (!panel || panel.__demoInit) return;
    panel.__demoInit = true;

    const data = readPanelData(panel);
    if (!data || !data.questions || !data.questions.length) return;
    panel.__demoData = data;
    panel.__demoState = {
      tab: "total",
      brandByCard: {}, // section_id -> brand_code
      visibleQs: new Set(data.questions.map((_, i) => i)),
      ciOn: new Set()
    };

    bindChipRow(panel);
    bindSubnav(panel);
    bindCardToolbars(panel);
    bindBrandPickers(panel);
  }

  function readPanelData(panel) {
    const node = panel.querySelector(".demo-panel-data");
    if (!node) return null;
    try { return JSON.parse(node.textContent || "{}"); }
    catch (e) { console.warn("[demographics] bad JSON payload", e); return null; }
  }

  // ----- chip row (show/hide questions) -----
  function bindChipRow(panel) {
    panel.querySelectorAll(".demo-q-chip").forEach(chip => {
      chip.addEventListener("click", () => {
        const idx = parseInt(chip.getAttribute("data-demo-q-idx"), 10);
        const visible = panel.__demoState.visibleQs;
        if (visible.has(idx)) { visible.delete(idx); chip.classList.remove("active"); }
        else                  { visible.add(idx);    chip.classList.add("active"); }
        panel.querySelectorAll(`.demo-card[data-demo-q-idx="${idx}"]`).forEach(card => {
          card.classList.toggle("hidden", !visible.has(idx));
        });
      });
    });
  }

  // ----- sub-tab nav -----
  function bindSubnav(panel) {
    panel.querySelectorAll(".demo-subtab-btn").forEach(btn => {
      if (btn.classList.contains("disabled")) return;
      btn.addEventListener("click", () => {
        panel.querySelectorAll(".demo-subtab-btn.active").forEach(a => a.classList.remove("active"));
        btn.classList.add("active");
        const tab = btn.getAttribute("data-demo-tab");
        panel.__demoState.tab = tab;
        rerenderAllCards(panel);
      });
    });
  }

  // ----- per-card pin (handled by brand_pins.js) + CI toggle -----
  function bindCardToolbars(panel) {
    panel.querySelectorAll(".demo-ci-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        const sec = btn.getAttribute("data-section");
        const card = panel.querySelector(`.demo-card[id="${sec}"]`);
        if (!card) return;
        const ci = panel.__demoState.ciOn;
        if (ci.has(sec)) { ci.delete(sec); card.classList.remove("show-ci"); btn.classList.remove("active"); }
        else             { ci.add(sec);    card.classList.add("show-ci");    btn.classList.add("active"); }
      });
    });
  }

  // ----- brand pickers (per card; only meaningful on "by brand" sub-tab) -----
  function bindBrandPickers(panel) {
    panel.querySelectorAll(".demo-brand-picker").forEach(picker => {
      const idx = parseInt(picker.getAttribute("data-demo-q-idx"), 10);
      picker.querySelectorAll(".demo-brand-chip").forEach(chip => {
        chip.addEventListener("click", () => {
          picker.querySelectorAll(".demo-brand-chip.active").forEach(a => a.classList.remove("active"));
          chip.classList.add("active");
          const brand = chip.getAttribute("data-demo-brand");
          const card = panel.querySelector(`.demo-card[data-demo-q-idx="${idx}"]`);
          if (!card) return;
          panel.__demoState.brandByCard[card.id] = brand;
          rerenderCard(panel, card, idx);
        });
      });
    });
  }

  // ----- rendering -----
  function rerenderAllCards(panel) {
    panel.querySelectorAll(".demo-card").forEach(card => {
      const idx = parseInt(card.getAttribute("data-demo-q-idx"), 10);
      rerenderCard(panel, card, idx);
    });
  }

  function rerenderCard(panel, card, idx) {
    const data = panel.__demoData;
    const state = panel.__demoState;
    const q = data.questions[idx];
    const body = card.querySelector(".demo-card-body");
    const picker = card.querySelector(".demo-brand-picker");
    if (!q || !body) return;

    const dp = (data.config && data.config.decimal_places) || 0;
    const focal = (data.meta && data.meta.focal_colour) || "#1A5276";

    // Picker visibility
    if (picker) picker.toggleAttribute("hidden", state.tab !== "brand");

    let html;
    switch (state.tab) {
      case "buyer": html = renderBuyerCut(q, focal, dp); break;
      case "tier":  html = renderTierCut(q, focal, dp);  break;
      case "brand": {
        const brand = state.brandByCard[card.id] ||
                       (data.brands.codes && data.brands.codes[0]);
        html = renderBrandCut(q, brand, focal, dp, data.brands);
        break;
      }
      default: html = renderTotal(q, focal, dp); break;
    }
    body.innerHTML = html;
  }

  // ----- renderers -----
  function pctStr(v, dp) {
    if (v == null || !isFinite(v)) return '<span class="demo-na">&mdash;</span>';
    return v.toFixed(dp) + "%";
  }
  function intStr(v) {
    if (v == null || !isFinite(v)) return "&mdash;";
    return Math.round(v).toLocaleString();
  }
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function distRowsHtml(rows, focal, dp) {
    if (!rows || !rows.length) return '<div class="demo-empty">No data for this cut.</div>';
    const maxPct = Math.max(...rows.map(r => r.pct || 0));
    const denom = maxPct > 0 ? maxPct : 1;
    const trs = rows.map(r => {
      const w = isFinite(r.pct) ? Math.max(2, 100 * r.pct / denom) : 0;
      return `<tr>
        <td class="demo-row-label">${esc(r.label || r.code)}</td>
        <td class="demo-row-bar"><div class="demo-row-bar-fill" style="width:${w.toFixed(1)}%;background-color:${focal}"></div></td>
        <td class="demo-row-pct">${pctStr(r.pct, dp)}</td>
        <td class="demo-row-ci">[${pctStr(r.ci_lower, dp)} &ndash; ${pctStr(r.ci_upper, dp)}]</td>
        <td class="demo-row-n">${intStr(r.n)}</td>
      </tr>`;
    }).join("");
    return `<table class="demo-table">
      <thead><tr><th>Option</th><th></th><th>%</th><th class="demo-ci-col">95% CI</th><th>n</th></tr></thead>
      <tbody>${trs}</tbody>
    </table>`;
  }

  function renderTotal(q, focal, dp) {
    return distRowsHtml((q.total && q.total.rows) || [], focal, dp);
  }

  function renderBuyerCut(q, focal, dp) {
    if (!q.buyer_cut) return '<div class="demo-empty">No focal-brand pen data — buyer cut hidden.</div>';
    const buyerRows = (q.buyer_cut.buyer && q.buyer_cut.buyer.rows) || [];
    const nonRows   = (q.buyer_cut.non_buyer && q.buyer_cut.non_buyer.rows) || [];
    return twoColTable("Buyer", "Non-buyer", buyerRows, nonRows, focal, dp);
  }

  function renderTierCut(q, focal, dp) {
    if (!q.tier_cut) return '<div class="demo-empty">No buyer-heaviness tertiles — tier cut hidden.</div>';
    const cols = [
      { hdr: "Light",  rows: (q.tier_cut.light  && q.tier_cut.light.rows)  || [] },
      { hdr: "Medium", rows: (q.tier_cut.medium && q.tier_cut.medium.rows) || [] },
      { hdr: "Heavy",  rows: (q.tier_cut.heavy  && q.tier_cut.heavy.rows)  || [] }
    ];
    return manyColTable(cols, q.codes, q.labels, focal, dp);
  }

  function renderBrandCut(q, brand, focal, dp, brands) {
    if (!q.brand_cut || !q.brand_cut.length) {
      return '<div class="demo-empty">No brand pen data — brand cut hidden.</div>';
    }
    // For the active brand, render its distribution like a Total card.
    const rec = q.brand_cut.find(b => b.brand_code === brand) || q.brand_cut[0];
    const cells = (rec.cells || []).map(c => {
      const i = q.codes.indexOf(c.code);
      const lbl = (i >= 0 && q.labels[i]) || c.code;
      return { label: lbl, code: c.code, pct: c.pct,
               ci_lower: c.ci_lower, ci_upper: c.ci_upper, n: rec.base_n };
    });
    const heading = `<div class="demo-brand-heading">${esc(rec.brand_label || rec.brand_code)} buyers (n = ${intStr(rec.base_n)})</div>`;
    const heat = brandHeatmap(q, brand, focal, dp);
    return heading + distRowsHtml(cells, focal, dp) + heat;
  }

  function brandHeatmap(q, focalBrand, focalCol, dp) {
    if (!q.brand_cut || !q.brand_cut.length) return "";
    const totalRows = (q.total && q.total.rows) || [];
    const codes = q.codes;
    const labels = q.labels;
    const totalByCode = new Map(totalRows.map(r => [r.code, r.pct]));
    const headerCells = codes.map((c, i) =>
      `<th class="demo-heat-hdr">${esc(labels[i] || c)}</th>`).join("");
    const rowsHtml = q.brand_cut.map(b => {
      const tds = b.cells.map(cell => {
        const tot = totalByCode.get(cell.code);
        const diff = (cell.pct != null && tot != null) ? cell.pct - tot : null;
        const bg = heatColour(diff);
        const cls = "demo-heat-cell" + (b.brand_code === focalBrand ? " focal-col" : "");
        return `<td class="${cls}" style="background-color:${bg}" title="vs total: ${diff == null ? "—" : (diff>=0?"+":"") + diff.toFixed(dp)}pp">${pctStr(cell.pct, dp)}</td>`;
      }).join("");
      return `<tr><td class="demo-row-label">${esc(b.brand_label || b.brand_code)}</td>${tds}<td class="demo-row-n">${intStr(b.base_n)}</td></tr>`;
    }).join("");
    return `<div class="demo-heatmap-wrap" style="margin-top:14px;">
      <div class="demo-heatmap-title" style="font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px;">Heatmap &mdash; brand &times; option (% of brand buyers)</div>
      <div style="overflow-x:auto;"><table class="demo-table demo-heatmap-table">
        <thead><tr><th>Brand</th>${headerCells}<th>n</th></tr></thead>
        <tbody>${rowsHtml}</tbody>
      </table></div>
    </div>`;
  }

  // Diverging colour: blue when above category average, red when below.
  // Magnitude clipped to 30pp (the largest diff likely to occur for an
  // option-share at a single demographic cut).
  function heatColour(diff) {
    if (diff == null || !isFinite(diff)) return "transparent";
    const max = 30;
    const frac = Math.min(1, Math.abs(diff) / max);
    const alpha = (0.06 + frac * 0.50).toFixed(3);
    return diff >= 0
      ? `rgba(37,99,171,${alpha})`
      : `rgba(192,57,43,${alpha})`;
  }

  function twoColTable(hdrA, hdrB, rowsA, rowsB, focal, dp) {
    const codes = unionCodes(rowsA, rowsB);
    const mapA = new Map(rowsA.map(r => [r.code, r]));
    const mapB = new Map(rowsB.map(r => [r.code, r]));
    const baseA = rowsA.length ? rowsA[0].n : null;
    const baseB = rowsB.length ? rowsB[0].n : null;
    const trs = codes.map(c => {
      const ra = mapA.get(c.code) || {};
      const rb = mapB.get(c.code) || {};
      return `<tr>
        <td class="demo-row-label">${esc(c.label)}</td>
        <td class="demo-heat-cell" style="background-color:${heatColour((ra.pct||0)-(rb.pct||0))}">${pctStr(ra.pct, dp)}</td>
        <td class="demo-heat-cell" style="background-color:${heatColour((rb.pct||0)-(ra.pct||0))}">${pctStr(rb.pct, dp)}</td>
        <td class="demo-row-n">${intStr(ra.n)}</td>
        <td class="demo-row-n">${intStr(rb.n)}</td>
      </tr>`;
    }).join("");
    return `<table class="demo-table">
      <thead><tr><th>Option</th><th>${esc(hdrA)} %</th><th>${esc(hdrB)} %</th><th>${esc(hdrA)} n</th><th>${esc(hdrB)} n</th></tr></thead>
      <tbody>${trs}</tbody>
    </table>`;
  }

  function manyColTable(cols, codes, labels, focal, dp) {
    const headerCells = cols.map(c => `<th>${esc(c.hdr)} %</th>`).join("");
    const trs = codes.map((cd, i) => {
      const cells = cols.map(col => {
        const r = (col.rows.find(x => x.code === cd)) || {};
        return `<td class="demo-heat-cell">${pctStr(r.pct, dp)}</td>`;
      }).join("");
      return `<tr><td class="demo-row-label">${esc(labels[i] || cd)}</td>${cells}</tr>`;
    }).join("");
    return `<table class="demo-table">
      <thead><tr><th>Option</th>${headerCells}</tr></thead>
      <tbody>${trs}</tbody>
    </table>`;
  }

  function unionCodes(rowsA, rowsB) {
    const seen = new Set();
    const out = [];
    [...rowsA, ...rowsB].forEach(r => {
      if (!seen.has(r.code)) { seen.add(r.code); out.push({ code: r.code, label: r.label || r.code }); }
    });
    return out;
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
  // Re-init when a tab containing the panel becomes active
  document.addEventListener("click", function (e) {
    if (e.target && e.target.closest && e.target.closest(".br-tab-btn")) {
      setTimeout(bootAll, 0);
    }
  });
})();
