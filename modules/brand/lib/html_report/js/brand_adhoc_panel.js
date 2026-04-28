/* ==============================================================================
 * BRAND MODULE - AD HOC PANEL JS
 * ==============================================================================
 * Wires the Ad Hoc tab interactivity:
 *   - Scope sub-tab switch (ALL + each category)
 *   - Question chip toggle (show/hide individual question cards in scope)
 *   - Per-card brand picker (visible only when "By brand" toggle is on)
 *   - Per-card CI overlay toggle
 *   - Per-card brand heatmap toggle
 *
 * Pin / PNG buttons reuse brTogglePin / brExportPng from brand_pins.js.
 * ==============================================================================*/

(function () {
  "use strict";

  function init(panel) {
    if (!panel || panel.__adhocInit) return;
    panel.__adhocInit = true;

    const data = readPanelData(panel);
    if (!data || !data.scopes || !data.scopes.length) return;
    panel.__adhocData = data;
    panel.__adhocState = {
      scope: data.scopes[0].scope_code,
      ciOn: new Set(),
      brandOn: new Set(),
      brandByCard: {}
    };

    bindScopeNav(panel);
    bindChipRows(panel);
    bindCardToolbars(panel);
    bindBrandPickers(panel);
  }

  function readPanelData(panel) {
    const node = panel.querySelector(".adhoc-panel-data");
    if (!node) return null;
    try { return JSON.parse(node.textContent || "{}"); }
    catch (e) { console.warn("[adhoc] bad JSON payload", e); return null; }
  }

  function bindScopeNav(panel) {
    panel.querySelectorAll(".adhoc-scope-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        panel.querySelectorAll(".adhoc-scope-btn.active").forEach(a => a.classList.remove("active"));
        btn.classList.add("active");
        const sc = btn.getAttribute("data-adhoc-scope");
        panel.__adhocState.scope = sc;
        panel.querySelectorAll(".adhoc-scope-section").forEach(sec => {
          sec.toggleAttribute("hidden", sec.getAttribute("data-adhoc-scope") !== sc);
        });
      });
    });
  }

  function bindChipRows(panel) {
    panel.querySelectorAll(".demo-q-chip[data-adhoc-q-idx]").forEach(chip => {
      chip.addEventListener("click", () => {
        const idx = parseInt(chip.getAttribute("data-adhoc-q-idx"), 10);
        const sc  = chip.getAttribute("data-adhoc-scope");
        const card = panel.querySelector(
          `.adhoc-scope-section[data-adhoc-scope="${sc}"] .adhoc-card[data-adhoc-q-idx="${idx}"]`);
        if (!card) return;
        const isOn = chip.classList.toggle("active");
        card.classList.toggle("hidden", !isOn);
      });
    });
  }

  function bindCardToolbars(panel) {
    // CI overlay toggle (mirrors demographics behaviour)
    panel.querySelectorAll(".adhoc-card .demo-ci-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        const sec = btn.getAttribute("data-section");
        const card = document.getElementById(sec);
        if (!card) return;
        const ci = panel.__adhocState.ciOn;
        if (ci.has(sec)) { ci.delete(sec); card.classList.remove("show-ci"); btn.classList.remove("active"); }
        else             { ci.add(sec);    card.classList.add("show-ci");    btn.classList.add("active"); }
      });
    });

    // "By brand" toggle: shows the brand picker + appends the brand heatmap
    panel.querySelectorAll(".adhoc-brand-toggle").forEach(btn => {
      btn.addEventListener("click", () => {
        const sec = btn.getAttribute("data-section");
        const card = document.getElementById(sec);
        if (!card) return;
        const on = panel.__adhocState.brandOn;
        if (on.has(sec)) {
          on.delete(sec);
          btn.classList.remove("active");
          card.classList.remove("show-brand");
          const picker = card.querySelector(".demo-brand-picker");
          if (picker) picker.toggleAttribute("hidden", true);
          const heat = card.querySelector(".adhoc-brand-heatmap");
          if (heat) heat.remove();
        } else {
          on.add(sec);
          btn.classList.add("active");
          card.classList.add("show-brand");
          const picker = card.querySelector(".demo-brand-picker");
          if (picker) picker.toggleAttribute("hidden", false);
          renderBrandHeatmap(panel, card);
        }
      });
    });
  }

  function bindBrandPickers(panel) {
    panel.querySelectorAll(".adhoc-card .demo-brand-picker").forEach(picker => {
      picker.querySelectorAll(".demo-brand-chip").forEach(chip => {
        chip.addEventListener("click", () => {
          picker.querySelectorAll(".demo-brand-chip.active").forEach(a => a.classList.remove("active"));
          chip.classList.add("active");
          const card = picker.closest(".adhoc-card");
          if (!card) return;
          panel.__adhocState.brandByCard[card.id] = chip.getAttribute("data-demo-brand");
          renderBrandHeatmap(panel, card);
        });
      });
    });
  }

  function renderBrandHeatmap(panel, card) {
    const idx = parseInt(card.getAttribute("data-adhoc-q-idx"), 10);
    const sc  = card.closest(".adhoc-scope-section").getAttribute("data-adhoc-scope");
    const data = panel.__adhocData;
    const scope = data.scopes.find(s => s.scope_code === sc);
    if (!scope) return;
    const q = scope.questions[idx];
    if (!q || !q.brand_cut || !q.brand_cut.length) return;

    const focalBrand = panel.__adhocState.brandByCard[card.id] ||
                       (q.brand_cut[0] && q.brand_cut[0].brand_code);
    const dp = (data.config && data.config.decimal_places) || 0;

    const totalRows = (q.total && q.total.rows) || [];
    const totalByCode = new Map(totalRows.map(r => [r.code, r.pct]));

    const codes = q.codes || (totalRows.map(r => r.code));
    const labels = q.labels || codes;
    const headerCells = codes.map((c, i) =>
      `<th>${esc(labels[i] || c)}</th>`).join("");
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
    const html = `<div class="adhoc-brand-heatmap" style="margin-top:14px;">
      <div class="demo-heatmap-title" style="font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px;">By brand &mdash; % among each brand's buyers</div>
      <div style="overflow-x:auto;"><table class="demo-table">
        <thead><tr><th>Brand</th>${headerCells}<th>n</th></tr></thead>
        <tbody>${rowsHtml}</tbody>
      </table></div>
    </div>`;

    const existing = card.querySelector(".adhoc-brand-heatmap");
    if (existing) existing.remove();
    const body = card.querySelector(".demo-card-body");
    if (body) body.insertAdjacentHTML("beforeend", html);
  }

  // ---- formatters / helpers ----
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
  function heatColour(diff) {
    if (diff == null || !isFinite(diff)) return "transparent";
    const max = 30;
    const frac = Math.min(1, Math.abs(diff) / max);
    const alpha = (0.06 + frac * 0.50).toFixed(3);
    return diff >= 0 ? `rgba(37,99,171,${alpha})` : `rgba(192,57,43,${alpha})`;
  }

  // ---- bootstrap ----
  function bootAll() {
    document.querySelectorAll(".adhoc-panel").forEach(init);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bootAll);
  } else {
    bootAll();
  }
  document.addEventListener("click", function (e) {
    if (e.target && e.target.closest && e.target.closest(".br-tab-btn")) {
      setTimeout(bootAll, 0);
    }
  });
})();
