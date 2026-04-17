// =============================================================================
// BRAND FUNNEL PANEL — INTERACTIVE BEHAVIOUR (FUNNEL_SPEC_v2 §6)
// =============================================================================
// Each .fn-panel carries a <script type="application/json" class="fn-panel-data">
// with the full panel payload. Controls operate on the panel in-place:
//
//   • Focus dropdown: reassigns focal brand across cards/table/chart.
//   • Table chips: show/hide brand columns (independent of chart chips).
//   • Chart chips: show/hide brand lines on slope chart.
//   • % mode: nested (default) ⇄ absolute.
//   • Show counts: appends n=X under every percentage cell.
//   • Chart view: slope ⇄ small-multiples.
//   • Segment emphasis: highlights one attitude position + auto-sorts
//     brand rows by that segment.
//   • Export: downloads the pre-written funnel_<cat>.xlsx file
//     (filename discovered via data-fn-excel-filename on panel root).
// =============================================================================

(function(){
  if (window.__BRAND_FUNNEL_PANEL_INIT__) return;
  window.__BRAND_FUNNEL_PANEL_INIT__ = true;

  document.addEventListener("DOMContentLoaded", function(){
    var panels = document.querySelectorAll(".fn-panel");
    for (var i = 0; i < panels.length; i++) initPanel(panels[i]);
  });

  // ---------------------------------------------------------------------------
  // Panel init
  // ---------------------------------------------------------------------------
  function initPanel(panel) {
    var payload = readPayload(panel);
    if (!payload) return;
    panel.__fnData = payload;
    panel.__fnState = {
      focal: (payload.meta && payload.meta.focal_brand_code) || null,
      pctMode: "total",      // "total" (% of sample) | "previous" (% of prev stage)
      showCounts: false,
      showChart: true,
      chartView: "slope",
      emphasis: "all",
      tableBrands: {},
      chartBrands: {},
      sort: { col: "brand", dir: "asc" }
    };
    // Default chip state: table all on, chart only focal on
    var allBrands = (payload.table && payload.table.brand_codes) || [];
    for (var i = 0; i < allBrands.length; i++) {
      panel.__fnState.tableBrands[allBrands[i]] = true;
      panel.__fnState.chartBrands[allBrands[i]] =
        (allBrands[i] === panel.__fnState.focal);
    }
    bindControls(panel);
    applyTableVisibility(panel);
    applyChartVisibility(panel);
    applyPctMode(panel);
    applyHeatmap(panel, true);  // On by default
    bindSubTabs(panel);
  }

  // ---------------------------------------------------------------------------
  // Sub-tab nav (Summary | Funnel | Relationship)
  // ---------------------------------------------------------------------------
  function bindSubTabs(panel) {
    panel.querySelectorAll('.fn-subtab-btn[data-fn-subtab-target]').forEach(function(btn){
      btn.addEventListener("click", function(){
        var target = btn.getAttribute("data-fn-subtab-target");
        panel.querySelectorAll('.fn-subtab-btn').forEach(function(b){
          var active = b === btn;
          b.classList.toggle("active", active);
          b.setAttribute("aria-selected", active ? "true" : "false");
        });
        panel.querySelectorAll('.fn-subtab[data-fn-subtab]').forEach(function(s){
          s.hidden = (s.getAttribute("data-fn-subtab") !== target);
        });
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Heatmap ON/OFF — reads data-heatmap on every .ct-heatmap-cell and writes
  // it as inline background-color. When OFF, a .fn-heatmap-off class on the
  // panel root blanks the background via CSS.
  // ---------------------------------------------------------------------------
  function applyHeatmap(panel, on) {
    panel.classList.toggle("fn-heatmap-off", !on);
    if (!on) return;
    panel.querySelectorAll(".ct-heatmap-cell").forEach(function(td){
      var colour = td.getAttribute("data-heatmap");
      if (colour) td.style.backgroundColor = colour;
    });
  }

  function readPayload(panel) {
    var el = panel.querySelector("script.fn-panel-data");
    if (!el) return null;
    try { return JSON.parse(el.textContent || "{}"); }
    catch(e) { console.warn("Funnel panel JSON parse failed", e); return null; }
  }

  // ---------------------------------------------------------------------------
  // Bind every control inside the panel
  // ---------------------------------------------------------------------------
  function bindControls(panel) {
    var focusSel = panel.querySelector('[data-fn-action="focus"]');
    if (focusSel) focusSel.addEventListener("change", function(){
      setFocal(panel, this.value);
    });

    panel.querySelectorAll('button[data-fn-scope][data-fn-brand]').forEach(function(btn){
      btn.addEventListener("click", function(){
        toggleBrandChip(panel, btn.getAttribute("data-fn-scope"),
                        btn.getAttribute("data-fn-brand"), btn);
      });
    });

    // Base (% of total / previous) — tabs segmented-button style
    panel.querySelectorAll('button[data-fn-action="pctmode"]').forEach(function(btn){
      btn.addEventListener("click", function(){
        var mode = btn.getAttribute("data-fn-pctmode");
        panel.__fnState.pctMode = mode;
        panel.querySelectorAll('button[data-fn-action="pctmode"]').forEach(function(b){
          var active = b === btn;
          b.classList.toggle("sig-btn-active", active);
          b.setAttribute("aria-pressed", active ? "true" : "false");
        });
        applyPctMode(panel);
      });
    });

    // Heatmap toggle (checked by default)
    var heat = panel.querySelector('[data-fn-action="heatmap"]');
    if (heat) heat.addEventListener("change", function(){
      applyHeatmap(panel, heat.checked);
    });

    // Show count — tabs uses .show-freq parent class to reveal .ct-freq
    var counts = panel.querySelector('[data-fn-action="showcounts"]');
    if (counts) counts.addEventListener("change", function(){
      panel.__fnState.showCounts = counts.checked;
      panel.classList.toggle("show-freq", counts.checked);
      panel.classList.toggle("fn-show-counts", counts.checked);
    });

    var showChart = panel.querySelector('[data-fn-action="showchart"]');
    if (showChart) showChart.addEventListener("change", function(){
      panel.__fnState.showChart = showChart.checked;
      panel.classList.toggle("fn-hide-chart", !showChart.checked);
    });

    panel.querySelectorAll('[data-fn-action="chartview"]').forEach(function(r){
      r.addEventListener("change", function(){
        panel.__fnState.chartView = r.value;
        applyChartView(panel);
      });
    });

    panel.querySelectorAll('[data-fn-action="sort-brand"]').forEach(function(b){
      b.addEventListener("click", function(){ toggleBrandSort(panel, b); });
    });
    panel.querySelectorAll('[data-fn-action="sort-stage"]').forEach(function(b){
      b.addEventListener("click", function(){
        toggleStageSort(panel, b, b.getAttribute("data-fn-stage"));
      });
    });

    panel.querySelectorAll('[data-fn-action="help"]').forEach(function(b){
      b.addEventListener("click", function(e){
        e.stopPropagation();
        toggleHelpPopover(panel, b, b.getAttribute("data-fn-stage"));
      });
    });
    document.addEventListener("click", function(){ closeAllHelpPopovers(panel); });

    panel.querySelectorAll('.fn-seg-chip[data-fn-emphasis]').forEach(function(c){
      c.addEventListener("click", function(){
        setEmphasis(panel, c.getAttribute("data-fn-emphasis"));
      });
    });

    var exp = panel.querySelector('[data-fn-action="export"]');
    if (exp) exp.addEventListener("click", function(){ exportToExcel(panel); });
  }

  // ---------------------------------------------------------------------------
  // Focus dropdown
  // ---------------------------------------------------------------------------
  function setFocal(panel, code) {
    if (!code) return;
    panel.__fnState.focal = code;
    panel.setAttribute("data-fn-focal", code);
    // Move the FOCAL row class + badge
    panel.querySelectorAll("tr[data-fn-brand]").forEach(function(row){
      var isFocal = row.getAttribute("data-fn-brand") === code;
      row.classList.toggle("fn-row-focal", isFocal);
      row.classList.toggle("fn-row-competitor", !isFocal);
    });
    panel.querySelectorAll(".fn-focal-badge").forEach(function(b){ b.remove(); });
    var focalRow = panel.querySelector("tr.fn-row-focal");
    if (focalRow) {
      var label = focalRow.querySelector(".ct-label-col");
      if (label && !label.querySelector(".fn-focal-badge")) {
        label.insertAdjacentHTML("beforeend",
          ' <span class="fn-focal-badge">FOCAL</span>');
      }
    }
    // Rebuild cards against the new focal, update the title sub-line, repaint chart
    rebuildFunnelCards(panel, code);
    rebuildRelationshipCards(panel, code);
    updateTitleSub(panel, code);
    rebuildChart(panel);
  }

  function rebuildFunnelCards(panel, focal) {
    var pd = panel.__fnData;
    if (!pd || !pd.table) return;
    var cells = pd.table.cells || [];
    panel.querySelectorAll(".fn-card-funnel").forEach(function(card){
      var stageKey = card.getAttribute("data-fn-stage");
      var focalPct = null, otherPcts = [];
      var focalBaseU = null;
      for (var i = 0; i < cells.length; i++) {
        var c = cells[i];
        if (c.stage_key !== stageKey) continue;
        if (c.brand_code === focal) {
          focalPct = c.pct_absolute;
          focalBaseU = c.base_unweighted;
        } else if (c.pct_absolute != null) {
          otherPcts.push(c.pct_absolute);
        }
      }
      var cavg = otherPcts.length
        ? otherPcts.reduce(function(a,b){return a+b;}, 0) / otherPcts.length
        : null;
      var pctEl = card.querySelector(".tk-hero-value");
      if (pctEl) pctEl.textContent = focalPct == null ? "—"
                   : Math.round(focalPct * 100) + "%";
      var cmpEl = card.querySelector(".fn-card-compare strong");
      if (cmpEl) cmpEl.textContent = cavg == null ? "—"
                   : Math.round(cavg * 100) + "%";
      var baseEl = card.querySelector(".fn-card-base");
      if (baseEl) baseEl.textContent = focalBaseU == null ? ""
                    : "Focal n = " + Math.round(focalBaseU);
    });
  }

  function rebuildRelationshipCards(panel, focal) {
    var pd = panel.__fnData;
    if (!pd || !pd.consideration_detail) return;
    var brands = pd.consideration_detail.brands || [];
    var focalEntry = null, others = [];
    for (var i = 0; i < brands.length; i++) {
      if (brands[i].brand_code === focal) focalEntry = brands[i];
      else others.push(brands[i]);
    }
    if (!focalEntry) return;
    var roleMap = {
      "LOVE": "attitude.love",
      "PREFER": "attitude.prefer",
      "AMBIVALENT": "attitude.ambivalent",
      "REJECT": "attitude.reject",
      "NO OPINION": "attitude.no_opinion"
    };
    panel.querySelectorAll(".fn-card-relationship").forEach(function(card){
      var labelEl = card.querySelector(".tk-hero-label");
      var name = labelEl ? labelEl.textContent.trim().toUpperCase() : "";
      var role = roleMap[name];
      if (!role) return;
      var focalPct = (focalEntry.segments || {})[role];
      var otherPcts = [];
      for (var j = 0; j < others.length; j++) {
        var seg = (others[j].segments || {})[role];
        if (seg != null) otherPcts.push(seg);
      }
      var cavg = otherPcts.length
        ? otherPcts.reduce(function(a,b){return a+b;}, 0) / otherPcts.length
        : null;
      var pctEl = card.querySelector(".tk-hero-value");
      if (pctEl) pctEl.textContent = focalPct == null ? "—"
                   : Math.round(focalPct * 100) + "%";
      var cmpEl = card.querySelector(".fn-card-compare strong");
      if (cmpEl) cmpEl.textContent = cavg == null ? "—"
                   : Math.round(cavg * 100) + "%";
    });
  }

  function updateTitleSub(panel, focal) {
    var pd = panel.__fnData;
    if (!pd || !pd.table) return;
    var codes = pd.table.brand_codes || [];
    var names = pd.table.brand_names || [];
    var idx = codes.indexOf(focal);
    var name = idx >= 0 ? names[idx] : focal;
    var strong = panel.querySelector(".fn-title-sub strong");
    if (strong) strong.textContent = name;
  }

  // ---------------------------------------------------------------------------
  // Chip toggles — scope = "table" or "chart"
  // ---------------------------------------------------------------------------
  function toggleBrandChip(panel, scope, code, btn) {
    var bucket = scope === "table" ? "tableBrands" : "chartBrands";
    panel.__fnState[bucket][code] = !panel.__fnState[bucket][code];
    btn.classList.toggle("col-chip-off", !panel.__fnState[bucket][code]);
    if (scope === "table") applyTableVisibility(panel);
    else applyChartVisibility(panel);
  }

  function applyTableVisibility(panel) {
    var state = panel.__fnState.tableBrands || {};
    var codes = Object.keys(state);
    // Hide/show brand rows; header stays put
    panel.querySelectorAll("tr[data-fn-brand]").forEach(function(row){
      var c = row.getAttribute("data-fn-brand");
      row.style.display = state[c] === false ? "none" : "";
    });
  }

  // ---------------------------------------------------------------------------
  // % mode — rewrite visible cell text via data-fn-pct-abs / data-fn-pct-nes
  // ---------------------------------------------------------------------------
  function applyPctMode(panel) {
    // "total" -> % of total sample (pct_absolute)
    // "previous" -> % of previous stage (pct_nested)
    // Legacy "absolute"/"nested" accepted for back-compat.
    var mode = panel.__fnState.pctMode;
    var useAbs = (mode === "total" || mode === "absolute");
    var attr = useAbs ? "data-fn-pct-abs" : "data-fn-pct-nes";
    // New table uses ct-td (tabs parity); older .fn-td selector kept for safety.
    panel.querySelectorAll(".ct-td[data-fn-pct-abs], .fn-td[data-fn-pct-abs]")
      .forEach(function(td){
        var v = parseFloat(td.getAttribute(attr));
        var primary = td.querySelector(".fn-pct-primary");
        if (primary && !isNaN(v)) primary.textContent = Math.round(v * 100) + "%";
      });
    // Cards always show absolute — don't rewrite; they read direct from payload
  }

  // ---------------------------------------------------------------------------
  // Chart visibility — JS redraws competitor lines when chips toggle
  // ---------------------------------------------------------------------------
  function applyChartVisibility(panel) {
    rebuildChart(panel);
  }

  function applyChartView(panel) {
    var wrap = panel.querySelector(".fn-chart-wrap");
    if (!wrap) return;
    wrap.setAttribute("data-fn-chart", panel.__fnState.chartView);
    rebuildChart(panel);
  }

  function rebuildChart(panel) {
    var svg = panel.querySelector(".fn-slope-svg");
    if (!svg) return;
    var pd = panel.__fnData;
    if (!pd || !pd.shape_chart) return;
    // Remove previously injected competitor series
    svg.querySelectorAll('[data-fn-series-comp="1"]').forEach(function(n){ n.remove(); });

    var comp = pd.shape_chart.competitor_series || [];
    var enabled = panel.__fnState.chartBrands || {};
    var focal = panel.__fnState.focal;
    for (var i = 0; i < comp.length; i++) {
      var series = comp[i];
      if (!enabled[series.brand_code]) continue;
      if (series.brand_code === focal) continue;
      var line = buildCompLine(series, pd.shape_chart.stage_positions || series.stage_keys);
      if (line) svg.insertAdjacentHTML("beforeend", line);
    }
  }

  function buildCompLine(series, stage_positions) {
    var pcts = series.pct_values || [];
    var n = pcts.length;
    if (n < 2) return "";
    // Re-derive the same x/y mapping as the R-side SVG builder
    var w = 760, h = 360, ml = 60, mr = 30, mt = 40, mb = 60;
    var pw = w - ml - mr, ph = h - mt - mb;
    var pts = [];
    for (var i = 0; i < n; i++) {
      var v = pcts[i];
      if (v == null || isNaN(v)) continue;
      var x = ml + pw * (i / (n - 1));
      var y = mt + ph * (1 - Math.max(0, Math.min(1, v)));
      pts.push(x.toFixed(2) + "," + y.toFixed(2));
    }
    if (pts.length < 2) return "";
    return '<polyline points="' + pts.join(" ") + '" ' +
           'fill="none" stroke="#94a3b8" stroke-width="1.5" ' +
           'opacity="0.8" data-fn-series-comp="1" ' +
           'data-fn-brand="' + escapeAttr(series.brand_code) + '"/>';
  }

  // ---------------------------------------------------------------------------
  // Segment emphasis + auto-sort
  // ---------------------------------------------------------------------------
  function setEmphasis(panel, role) {
    panel.__fnState.emphasis = role;
    panel.querySelectorAll(".fn-seg-chip").forEach(function(c){
      c.classList.toggle("active", c.getAttribute("data-fn-emphasis") === role);
    });
    var container = panel.querySelector(".fn-relationship-bars");
    if (!container) return;
    container.setAttribute("data-fn-emphasis", role);
    if (role === "all") {
      panel.removeAttribute("data-fn-emphasis-active");
    } else {
      panel.setAttribute("data-fn-emphasis-active", "1");
      container.querySelectorAll(".fn-seg").forEach(function(s){
        s.classList.toggle("fn-seg-active",
          s.getAttribute("data-fn-role") === role);
      });
      sortBarsByEmphasis(container, role);
    }
  }

  function sortBarsByEmphasis(container, role) {
    var rows = Array.prototype.slice.call(
      container.querySelectorAll(".fn-bar-row"));
    rows.sort(function(a, b){
      var av = segPctOf(a, role);
      var bv = segPctOf(b, role);
      return bv - av;
    });
    rows.forEach(function(r){ container.appendChild(r); });
  }

  function segPctOf(row, role) {
    var seg = row.querySelector('.fn-seg[data-fn-role="' + role + '"]');
    if (!seg) return 0;
    var v = parseFloat(seg.getAttribute("data-fn-pct"));
    return isNaN(v) ? 0 : v;
  }

  // ---------------------------------------------------------------------------
  // Export to Excel — the file is already written alongside the HTML by
  // write_funnel_excel(). The panel carries the filename via data-attribute;
  // we just trigger a download link. If the filename isn't set we alert.
  // ---------------------------------------------------------------------------
  function exportToExcel(panel) {
    var fn = panel.getAttribute("data-fn-excel-filename");
    if (!fn) {
      alert("Excel file not available. Run the report with output_excel = Y.");
      return;
    }
    var a = document.createElement("a");
    a.href = fn;
    a.download = fn;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }

  // ---------------------------------------------------------------------------
  // Sort — Focal + Category Average rows are LOCKED to positions 2+3 (Base
  // row stays at 1). Only competitor rows reorder. Sort state is tracked
  // on panel.__fnState.sort = { col: "brand"|<stage_key>, dir: "asc"|"desc" }.
  // ---------------------------------------------------------------------------
  function toggleBrandSort(panel, btn) {
    var s = panel.__fnState.sort;
    var nextDir = (s.col === "brand" && s.dir === "asc") ? "desc" : "asc";
    setSort(panel, "brand", nextDir);
  }

  function toggleStageSort(panel, btn, stageKey) {
    var s = panel.__fnState.sort;
    var nextDir = (s.col === stageKey && s.dir === "desc") ? "asc" : "desc";
    setSort(panel, stageKey, nextDir);
  }

  function setSort(panel, col, dir) {
    panel.__fnState.sort = { col: col, dir: dir };
    // Mark header state so CSS/aria can render the indicator
    panel.querySelectorAll("[data-fn-action^='sort-']").forEach(function(b){
      b.setAttribute("data-fn-sort-dir", "none");
    });
    var activeSel = (col === "brand")
      ? '[data-fn-action="sort-brand"]'
      : '[data-fn-action="sort-stage"][data-fn-stage="' + col + '"]';
    var active = panel.querySelector(activeSel);
    if (active) active.setAttribute("data-fn-sort-dir", dir);

    var tbody = panel.querySelector(".fn-table tbody");
    if (!tbody) return;
    var competitors = Array.prototype.slice.call(
      tbody.querySelectorAll('tr.fn-row-competitor'));
    competitors.sort(function(a, b){
      var av, bv;
      if (col === "brand") {
        av = a.getAttribute("data-fn-sort-brand") || "";
        bv = b.getAttribute("data-fn-sort-brand") || "";
        return dir === "asc" ? av.localeCompare(bv) : bv.localeCompare(av);
      }
      av = parseFloat(a.getAttribute("data-fn-sort-" + col));
      bv = parseFloat(b.getAttribute("data-fn-sort-" + col));
      if (isNaN(av)) av = -Infinity;
      if (isNaN(bv)) bv = -Infinity;
      return dir === "asc" ? av - bv : bv - av;
    });
    competitors.forEach(function(r){ tbody.appendChild(r); });
  }

  // ---------------------------------------------------------------------------
  // Help popovers — floated next to the header ? trigger; click outside or
  // on another ? dismisses. Content comes from the hidden <template> blocks
  // emitted by the renderer (one per stage).
  // ---------------------------------------------------------------------------
  function toggleHelpPopover(panel, btn, stageKey) {
    var existing = panel.querySelector('.fn-help-popover');
    if (existing && existing.getAttribute("data-fn-stage") === stageKey) {
      existing.remove();
      return;
    }
    closeAllHelpPopovers(panel);
    var tpl = panel.querySelector('template.fn-help-template[data-fn-stage="' + stageKey + '"]');
    if (!tpl) return;
    var label = tpl.getAttribute("data-fn-stage-label") || stageKey;
    var body = tpl.content.cloneNode(true);
    var pop = document.createElement("div");
    pop.className = "fn-help-popover";
    pop.setAttribute("data-fn-stage", stageKey);
    pop.setAttribute("role", "dialog");
    pop.innerHTML = '<div class="fn-help-popover-title">' +
      escapeAttr(label) + '</div>';
    pop.appendChild(body);
    // Position it — place relative to the panel using the button rect
    var bRect = btn.getBoundingClientRect();
    var pRect = panel.getBoundingClientRect();
    pop.style.left = (bRect.left - pRect.left) + "px";
    pop.style.top = (bRect.bottom - pRect.top + 6) + "px";
    panel.appendChild(pop);
    // Stop clicks inside the popover from bubbling to the document listener
    pop.addEventListener("click", function(e){ e.stopPropagation(); });
  }

  function closeAllHelpPopovers(panel) {
    panel.querySelectorAll('.fn-help-popover').forEach(function(p){ p.remove(); });
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------
  function escapeAttr(s) {
    return String(s).replace(/&/g,"&amp;").replace(/"/g,"&quot;").replace(/</g,"&lt;");
  }
})();
