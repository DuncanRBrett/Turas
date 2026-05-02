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

  // Colour resolution delegated to the shared TurasColours module (brand_colours.js).

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
      pctMode: "total",
      showCounts: false,
      showChart: true,
      showValues: "focal",  // "focal" | "all" | "none"
      yMinInput: null,
      yMaxInput: null,
      shading: "range",        // slope chart band: "range" | "ci" | "none"
      tableShading: "heatmap", // table cells: "off" | "heatmap" | "ci"
      callouts: {},
      emphasis: "all",
      tableBrands: {},
      chartBrands: {},
      sort: { col: "brand", dir: "asc" },
      chartView: "slope",  // "slope" | "bar"
      barStage: null       // active stage key in bar view (set in initPanel)
    };
    // Default bar stage = first stage key
    var stageKeys = (payload.table && payload.table.stage_keys) || [];
    panel.__fnState.barStage = stageKeys[0] || null;

    // Default chip state respects the chip_default config:
    //   focal_only: only focal + cat-avg active; other brand chips greyed off.
    //   all       : all brand chips active and cat-avg active.
    // Read DOM (col-chip-off / .active) — R has rendered the right initial state.
    var chipDefault = panel.getAttribute('data-chip-default') || 'focal_only';
    var focalCode = (payload.meta && payload.meta.focal_brand_code) || null;
    var allBrands = (payload.table && payload.table.brand_codes) || [];
    for (var i = 0; i < allBrands.length; i++) {
      var bcode = allBrands[i];
      var visible = (chipDefault !== 'focal_only') || (bcode === focalCode);
      panel.__fnState.tableBrands[bcode] = visible;
      panel.__fnState.chartBrands[bcode] = visible;
    }
    // Cat-avg always on under both modes.
    panel.__fnState.chartBrands["__avg__"] = true;
    bindControls(panel);
    // Enforce initial control row visibility (chartView starts as "slope")
    panel.querySelectorAll(".fn-stk-ctl").forEach(function(el) { el.hidden = true; });
    var initBarWrap = panel.querySelector(".fn-bar-wrap");
    if (initBarWrap) initBarWrap.hidden = true;
    // Apply brand colours to funnel table/chart chip buttons
    panel.querySelectorAll('button[data-fn-scope][data-fn-brand]').forEach(function(btn) {
      var code = btn.getAttribute('data-fn-brand');
      if (code === '__avg__') return;
      var color = resolveBrandColor(payload, panel.__fnState, code);
      if (color) btn.style.setProperty('--brand-chip-color', color);
    });
    applySortIndicators(panel);
    applyTableVisibility(panel);
    applyChartVisibility(panel);
    applyPctMode(panel);
    applyTableShading(panel, "off");
    applyTableSigMarkers(panel);
    bindSubTabs(panel);
    bindPinDropdown(panel);
    initRelChart(panel);
    if (panel.style.position !== "relative") panel.style.position = "relative";
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
        // Rebuild the relationship chart when its tab becomes visible so flex
        // layout can compute widths (bars were zero-width while tab was hidden).
        if (target === "relationship") buildRelChart(panel);
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Table shading — three modes:
  //   "heatmap" — per-column blue intensity (original behaviour)
  //   "ci"      — amber/green/red vs category average 95% CI
  //   "off"     — no cell shading
  // ---------------------------------------------------------------------------
  function applyTableShading(panel, mode) {
    panel.__fnState.tableShading = mode;

    // Clear all inline bg on heatmap cells first
    panel.querySelectorAll(".ct-heatmap-cell").forEach(function(td){
      td.style.removeProperty("background-color");
      td.classList.remove("fn-ci-above", "fn-ci-within", "fn-ci-below");
    });
    // Remove heatmap-off class used by old toggle approach
    panel.classList.remove("fn-heatmap-off");

    if (mode === "off") {
      // Restore focal/avg persistent tints that CSS rules handle via !important
      return;
    }

    if (mode === "heatmap") {
      panel.querySelectorAll(".ct-heatmap-cell").forEach(function(td){
        var row = td.closest("tr");
        if (row && row.classList.contains("fn-row-avg-all")) return;
        if (td.classList.contains("fn-rel-td-focal") ||
            td.classList.contains("fn-rel-td-avg")) return;
        var colour = td.getAttribute("data-heatmap");
        if (colour) td.style.backgroundColor = colour;
      });
      return;
    }

    if (mode === "ci") {
      // Compute 95% CI bounds per stage from all visible brand cells
      var pd = panel.__fnData;
      if (!pd || !pd.table) return;
      var cells = pd.table.cells || [];
      var stageKeys = pd.table.stage_keys || [];
      var ciBounds = {};
      stageKeys.forEach(function(sk){
        var vals = [];
        cells.forEach(function(c){
          if (c.stage_key === sk && c.pct_absolute != null) vals.push(c.pct_absolute);
        });
        if (vals.length < 2) return;
        var mean = vals.reduce(function(a, b){ return a + b; }, 0) / vals.length;
        var sd = Math.sqrt(vals.reduce(function(a, v){ return a + (v - mean) * (v - mean); }, 0) / (vals.length - 1));
        var se = sd / Math.sqrt(vals.length);
        ciBounds[sk] = { lower: mean - 1.96 * se, upper: mean + 1.96 * se };
      });

      panel.querySelectorAll(".ct-heatmap-cell").forEach(function(td){
        var row = td.closest("tr");
        if (!row || row.classList.contains("fn-row-base") ||
            row.classList.contains("fn-row-avg-all")) return;
        if (td.classList.contains("fn-rel-td-avg")) return;
        var sk  = td.getAttribute("data-fn-stage");
        var bnds = sk && ciBounds[sk];
        if (!bnds) return;
        var pct = parseFloat(td.getAttribute("data-fn-pct-abs"));
        if (isNaN(pct)) return;
        var cls = pct > bnds.upper ? "fn-ci-above"
                : pct < bnds.lower ? "fn-ci-below"
                : "fn-ci-within";
        td.classList.add(cls);
      });
    }
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

    // Show all / Hide all toggle for table and chart chip bars
    panel.querySelectorAll('button[data-fn-action="toggleall"]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var scope = btn.getAttribute('data-fn-scope');
        var focal = panel.__fnState.focal;
        var bucket = scope === 'table' ? 'tableBrands' : 'chartBrands';
        var chips = panel.querySelectorAll('button[data-fn-scope="' + scope + '"][data-fn-brand]');
        var nonFocal = [];
        chips.forEach(function(c) {
          if (c.getAttribute('data-fn-brand') !== focal) nonFocal.push(c);
        });
        var allOn = nonFocal.every(function(c) { return !c.classList.contains('col-chip-off'); });
        var nextState = !allOn;
        nonFocal.forEach(function(c) {
          var code = c.getAttribute('data-fn-brand');
          panel.__fnState[bucket][code] = nextState;
          c.classList.toggle('col-chip-off', !nextState);
        });
        if (scope === 'table') applyTableVisibility(panel);
        else applyChartVisibility(panel);
        btn.textContent = nextState ? 'Hide all' : 'Show all';
      });
    });

    // Add Insight toggle — shows/hides inline textarea in the insight strip
    panel.querySelectorAll('button[data-fn-action="add-insight"]').forEach(function(btn) {
      btn.addEventListener("click", function() {
        var strip = btn.closest(".fn-insight-strip");
        if (!strip) return;
        var box = strip.querySelector(".fn-insight-box");
        if (!box) return;
        var open = box.style.display !== "none";
        box.style.display = open ? "none" : "block";
        btn.textContent = open ? "+ Add Insight" : "\u2212 Hide Insight";
        if (!open) {
          var ta = box.querySelector(".fn-insight-textarea");
          if (ta) ta.focus();
        }
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
        buildMiniFunnels(panel);  // mini funnels must reflect the new % base
        drawSlopeSvg(panel);      // slope chart re-renders with new base
      });
    });

    // CI bands checkbox (single toggle; off by default)
    var showCI = panel.querySelector('[data-fn-action="showci"]');
    if (showCI) showCI.addEventListener("change", function(){
      applyTableShading(panel, showCI.checked ? "ci" : "off");
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

    panel.querySelectorAll('[data-fn-action="showvalues"]').forEach(function(btn){
      btn.addEventListener("click", function(){
        var mode = btn.getAttribute("data-fn-showvalues");
        panel.__fnState.showValues = mode;
        panel.querySelectorAll('[data-fn-action="showvalues"]').forEach(function(b){
          var active = b === btn;
          b.classList.toggle("sig-btn-active", active);
          b.setAttribute("aria-pressed", active ? "true" : "false");
        });
        drawSlopeSvg(panel);
      });
    });

    panel.querySelectorAll('[data-fn-yaxis]').forEach(function(inp){
      ["change","input"].forEach(function(evt){
        inp.addEventListener(evt, function(){
          var which = inp.getAttribute("data-fn-yaxis");
          var raw = inp.value.trim();
          var val = raw === "" ? null : parseFloat(raw);
          if (which === "min") panel.__fnState.yMinInput = val;
          else                 panel.__fnState.yMaxInput = val;
          drawSlopeSvg(panel);
        });
      });
    });

    var yReset = panel.querySelector('[data-fn-action="yaxisreset"]');
    if (yReset) yReset.addEventListener("click", function(){
      panel.__fnState.yMinInput = null;
      panel.__fnState.yMaxInput = null;
      var minInp = panel.querySelector('[data-fn-yaxis="min"]');
      var maxInp = panel.querySelector('[data-fn-yaxis="max"]');
      if (minInp) minInp.value = "";
      if (maxInp) maxInp.value = "";
      drawSlopeSvg(panel);
    });

    panel.querySelectorAll('[data-fn-action="shading"]').forEach(function(btn){
      btn.addEventListener("click", function(){
        panel.__fnState.shading = btn.getAttribute("data-fn-shading");
        panel.querySelectorAll('[data-fn-action="shading"]').forEach(function(b){
          var active = b === btn;
          b.classList.toggle("sig-btn-active", active);
          b.setAttribute("aria-pressed", active ? "true" : "false");
        });
        drawSlopeSvg(panel);
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

    // Chart view toggle (Slope | Bar)
    panel.querySelectorAll('[data-fn-action="chartview"]').forEach(function(btn) {
      btn.addEventListener("click", function() {
        var view = btn.getAttribute("data-fn-view");
        panel.__fnState.chartView = view;
        panel.querySelectorAll('[data-fn-action="chartview"]').forEach(function(b) {
          var active = b === btn;
          b.classList.toggle("sig-btn-active", active);
          b.setAttribute("aria-pressed", active ? "true" : "false");
        });
        var isBar = view === "bar";
        panel.querySelectorAll(".fn-slope-ctl").forEach(function(el) { el.hidden = isBar; });
        panel.querySelectorAll(".fn-stk-ctl").forEach(function(el) { el.hidden = !isBar; });
        var slopeWrap = panel.querySelector('[data-fn-chart="slope"]');
        var barWrap   = panel.querySelector(".fn-bar-wrap");
        if (slopeWrap) slopeWrap.hidden = isBar;
        if (barWrap)   barWrap.hidden   = !isBar;
        if (isBar) buildBarChart(panel);
        else { drawSlopeSvg(panel); buildMiniFunnels(panel); }
      });
    });

    // Bar stage selector chips
    panel.querySelectorAll(".fn-stk-emph-chip").forEach(function(chip) {
      chip.addEventListener("click", function() {
        var stage = chip.getAttribute("data-fn-stk-emphasis");
        panel.__fnState.barStage = stage;
        panel.querySelectorAll(".fn-stk-emph-chip").forEach(function(c) {
          c.classList.toggle("fn-stk-emph-active", c === chip);
        });
        buildBarChart(panel);
      });
    });

    var exp = panel.querySelector('[data-fn-action="exporttable"]');
    if (exp) exp.addEventListener("click", function(){ exportTable(panel); });
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
    // Move new focal row to top of tbody (just after Base row),
    // then re-anchor Category average immediately after focal.
    var tbody = panel.querySelector("table.fn-table tbody");
    if (tbody) {
      var baseRow  = tbody.querySelector(".fn-row-base");
      var focalRow = tbody.querySelector("tr.fn-row-focal");
      var avgRow   = tbody.querySelector("tr.fn-row-avg-all");
      if (baseRow && focalRow && baseRow.nextSibling !== focalRow) {
        tbody.insertBefore(focalRow, baseRow.nextSibling);
      }
      if (focalRow && avgRow && focalRow.nextSibling !== avgRow) {
        tbody.insertBefore(avgRow, focalRow.nextSibling);
      }
    }

    // Update relationship table: swap focal/competitor classes, badge, cell highlight, row order
    var relTable = panel.querySelector("[data-fn-rel-table]");
    if (relTable) {
      var relTbody = relTable.querySelector("tbody") || relTable;
      // Swap row classes and clear old FOCAL badges from rel table rows only
      relTable.querySelectorAll("tr[data-fn-brand]").forEach(function(row) {
        var isFocal = row.getAttribute("data-fn-brand") === code;
        row.classList.toggle("fn-row-focal", isFocal);
        row.classList.toggle("fn-row-competitor", !isFocal);
        var lbl = row.querySelector(".ct-label-col");
        if (lbl) {
          lbl.querySelectorAll(".fn-focal-badge").forEach(function(b) { b.remove(); });
          if (isFocal) lbl.insertAdjacentHTML("beforeend", ' <span class="fn-focal-badge">FOCAL</span>');
        }
        // Swap fn-rel-td-focal on data cells
        row.querySelectorAll("td[data-fn-att]").forEach(function(td) {
          td.classList.toggle("fn-rel-td-focal", isFocal);
        });
      });
      // Move focal row to top (above avg row)
      var relFocal = relTbody.querySelector("tr.fn-row-focal");
      var relAvg   = relTbody.querySelector("tr.fn-row-avg-all");
      if (relFocal && relTbody.firstChild !== relFocal) {
        relTbody.insertBefore(relFocal, relTbody.firstChild);
      }
      if (relFocal && relAvg && relFocal.nextSibling !== relAvg) {
        relTbody.insertBefore(relAvg, relFocal.nextSibling);
      }
    }
    // Ensure new focal is always on in chart/mini-funnels; update its chip UI
    panel.__fnState.chartBrands[code] = true;
    var newFocalChip = panel.querySelector(
      '.fn-chart-brand-chips [data-fn-scope="chart"][data-fn-brand="' + code + '"]');
    if (newFocalChip) newFocalChip.classList.remove("col-chip-off");

    // Rebuild cards against the new focal, update title, repaint chart + mini funnels
    rebuildFunnelCards(panel, code);
    rebuildRelationshipCards(panel, code);
    updateTitleSub(panel, code);
    drawSlopeSvg(panel);
    buildMiniFunnels(panel);
    buildRelChart(panel);
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
  // % mode — rewrite cell text, base row n=, and cell count spans.
  //
  // "total"    → pct_absolute from data-fn-pct-abs attribute
  // "previous" → pct_nested from data-fn-pct-nes attribute
  // "aware"    → computed on the fly from pct_absolute / brand_aware_pct using
  //              the JSON payload (pd.table.cells), so it works without
  //              regenerating the HTML. Stage 1 (aware) pinned to 100%.
  //
  // Cell count format (Show count on): n=<stage_count> (<mode_denom>)
  // Base row format: n=300 (varies by brand) for non-total modes ≥ stage 2.
  // ---------------------------------------------------------------------------
  function applyPctMode(panel) {
    var mode = panel.__fnState.pctMode;
    var pd   = panel.__fnData;

    // --- 1. Build aware-pct lookup (brand → pct_absolute at stage 1) -----------
    var brandAwarePct = {}; // used for "aware" mode computations
    if (pd && pd.table) {
      var awareStageKey = (pd.table.stage_keys || [])[0];
      (pd.table.cells || []).forEach(function(c) {
        if (c.stage_key === awareStageKey) brandAwarePct[c.brand_code] = c.pct_absolute;
      });
    }

    // --- 2. Rewrite primary pct text in every data cell ----------------------
    if (mode === "aware") {
      // Compute aware-indexed values on the fly — works regardless of whether
      // data-fn-pct-aw is present in the HTML (backward-compatible).
      panel.querySelectorAll(".ct-td[data-fn-brand][data-fn-stage], .fn-td[data-fn-brand][data-fn-stage]")
        .forEach(function(td) {
          var brand   = td.getAttribute("data-fn-brand");
          var stage   = td.getAttribute("data-fn-stage");
          var primary = td.querySelector(".fn-pct-primary");
          if (!primary) return;
          var ap    = brandAwarePct[brand];
          var absV  = parseFloat(td.getAttribute("data-fn-pct-abs"));
          var v;
          if (stage === awareStageKey) {
            v = 1.0; // Aware stage = 100% of itself by definition
          } else if (ap && ap > 0 && !isNaN(absV)) {
            v = absV / ap;
          } else {
            return;
          }
          primary.textContent = Math.round(v * 100) + "%";
        });
    } else {
      var attr = mode === "previous" ? "data-fn-pct-nes" : "data-fn-pct-abs";
      panel.querySelectorAll(".ct-td[data-fn-pct-abs], .fn-td[data-fn-pct-abs]")
        .forEach(function(td) {
          var v = parseFloat(td.getAttribute(attr));
          var primary = td.querySelector(".fn-pct-primary");
          if (primary && !isNaN(v)) primary.textContent = Math.round(v * 100) + "%";
        });
    }

    // --- 3. Funnel-inversion warnings (% previous mode only) -----------------
    panel.querySelectorAll(".ct-td[data-fn-pct-nes]").forEach(function(td) {
      td.classList.remove("fn-inversion-warning");
      td.removeAttribute("title");
    });
    if (mode === "previous") {
      panel.querySelectorAll(".ct-td[data-fn-pct-nes]").forEach(function(td) {
        var nes = parseFloat(td.getAttribute("data-fn-pct-nes"));
        if (!isNaN(nes) && nes > 1.001) {
          td.classList.add("fn-inversion-warning");
          td.setAttribute("title", "Funnel inversion: this stage exceeds the previous stage (" +
            Math.round(nes * 100) + "%). Check data quality.");
        }
      });
    }

    if (!pd || !pd.table || !pd.meta) return;
    var nTotal    = Math.round(pd.meta.n_weighted || 0);
    var stageKeys = pd.table.stage_keys || [];

    // Build per-brand base_unweighted lookup (count at each stage per brand).
    var brandCountByStage = {};
    (pd.table.cells || []).forEach(function(c) {
      if (!brandCountByStage[c.brand_code]) brandCountByStage[c.brand_code] = {};
      brandCountByStage[c.brand_code][c.stage_key] = c.base_unweighted;
    });

    // --- 4. Update base row --------------------------------------------------
    // "total":    n=300  (all stages)
    // "previous": n=300  (stage 1),  n=300 (varies by brand)  (subsequent)
    // "aware":    n=300  (aware),    n=300 (varies by brand)  (subsequent)
    var baseRow = panel.querySelector("tr.fn-row-base");
    if (baseRow && nTotal) {
      var dataCells = baseRow.querySelectorAll("td.ct-td.ct-data-col");
      dataCells.forEach(function(td, i) {
        var span = td.querySelector(".ct-base-n, .ct-low-base");
        if (!span) return;
        if (mode === "total" || mode === "absolute" || i === 0) {
          span.textContent = "n=" + nTotal;
        } else {
          span.textContent = "n=" + nTotal + " (varies by brand)";
        }
      });
    }

    // --- 5. Update cell count spans: n=<stage_count> (<mode_denom>) ----------
    panel.querySelectorAll(".ct-td[data-fn-brand][data-fn-stage]").forEach(function(td) {
      var brand = td.getAttribute("data-fn-brand");
      var stage = td.getAttribute("data-fn-stage");
      var countSpan = td.querySelector(".fn-pct-count");
      if (!countSpan) return;
      var rawBase   = td.getAttribute("data-fn-base");
      var stageCount = (rawBase !== "" && rawBase != null) ? parseInt(rawBase, 10) : null;
      if (stageCount == null || isNaN(stageCount)) { countSpan.textContent = ""; return; }

      var denom = null;
      if (mode === "aware") {
        var awareKey = stageKeys[0];
        denom = (stage !== awareKey)
          ? ((brandCountByStage[brand] || {})[awareKey] || null)
          : nTotal;
      } else if (mode === "previous") {
        var stageIdx = stageKeys.indexOf(stage);
        if (stageIdx > 0) {
          denom = (brandCountByStage[brand] || {})[stageKeys[stageIdx - 1]] || null;
        } else {
          denom = nTotal;
        }
      }

      countSpan.textContent = (denom != null)
        ? "n=" + stageCount + " (" + denom + ")"
        : "n=" + stageCount;
    });
  }

  // ---------------------------------------------------------------------------
  // Chart visibility — routes to slope or stacked depending on state
  // ---------------------------------------------------------------------------
  function applyChartVisibility(panel) {
    if (panel.__fnState.chartView === "bar") {
      buildBarChart(panel);
    } else {
      drawSlopeSvg(panel);
      buildMiniFunnels(panel);
    }
  }

  function buildMiniFunnels(panel) {
    var view = panel.querySelector(".fn-mini-funnels-view");
    if (!view) return;
    var pd = panel.__fnData;
    if (!pd || !pd.table) { view.innerHTML = ""; return; }

    var stageKeys   = pd.table.stage_keys   || [];
    var stageLabels = pd.table.stage_labels || stageKeys;
    var brandCodes  = pd.table.brand_codes  || [];
    var brandNames  = pd.table.brand_names  || brandCodes;
    var cells       = pd.table.cells        || [];
    var focal       = panel.__fnState.focal;
    var chartBrands = panel.__fnState.chartBrands || {};
    var state       = panel.__fnState;
    var pctMode     = state.pctMode;

    var cellMap = {};
    for (var ci = 0; ci < cells.length; ci++) {
      var c = cells[ci];
      if (!cellMap[c.brand_code]) cellMap[c.brand_code] = {};
      cellMap[c.brand_code][c.stage_key] = c;
    }

    // Build avg value map for cat avg card
    var avgMap = {};
    if (pd.table && pd.table.avg_all_brands) {
      pd.table.avg_all_brands.forEach(function(r) { avgMap[r.stage_key] = r; });
    }

    var html = "";

    // Category average card (shown when __avg__ chip is on)
    if (chartBrands["__avg__"] !== false) {
      var avgColor = "#64748b";
      html += '<div class="fn-mini-funnel fn-mf-avg" style="border-left-color:' + avgColor + '">';
      html += '<div class="fn-mf-title"><em>Category average</em></div>';
      html += '<div class="fn-mf-stages">';
      for (var si = 0; si < stageKeys.length; si++) {
        var k = stageKeys[si];
        var r = avgMap[k];
        var pct = r ? (pctMode === "previous" && r.pct_nested != null ? r.pct_nested : r.pct_absolute) : null;
        var barW = pct != null ? Math.max(6, Math.round(pct * 100)) : 0;
        var pctStr = pct != null ? Math.round(pct * 100) + "%" : "\u2014";
        html += '<div class="fn-mf-stage">';
        html += '<div class="fn-mf-bar-bg"><div class="fn-mf-bar" style="width:' + barW + '%;background:' + avgColor + ';">';
        if (barW > 22) html += pctStr;
        html += '</div></div>';
        html += '<div class="fn-mf-label">' + escapeAttr(stageLabels[si] || k) + ' <span class="fn-mf-pct">' + pctStr + '</span></div>';
        html += '</div>';
      }
      html += '</div></div>';
    }

    for (var bi = 0; bi < brandCodes.length; bi++) {
      var code = brandCodes[bi];
      if (chartBrands[code] === false) continue;
      var name    = brandNames[bi] || code;
      var isFocal = code === focal;
      var color   = resolveBrandColor(pd, state, code);

      html += '<div class="fn-mini-funnel' + (isFocal ? " fn-mf-focal" : "") + '" style="border-left-color:' + color + '">';
      html += '<div class="fn-mf-title">' + escapeAttr(name);
      if (isFocal) html += ' <span class="fn-focal-badge">FOCAL</span>';
      html += "</div>";
      html += '<div class="fn-mf-stages">';

      for (var si = 0; si < stageKeys.length; si++) {
        var k     = stageKeys[si];
        var lbl   = stageLabels[si] || k;
        var cell  = cellMap[code] && cellMap[code][k];
        var pct   = cell ? (pctMode === "previous" && cell.pct_nested != null
                            ? cell.pct_nested : cell.pct_absolute) : null;
        var barW  = pct != null ? Math.max(6, Math.round(pct * 100)) : 0;
        var pctStr = pct != null ? Math.round(pct * 100) + "%" : "\u2014";

        html += '<div class="fn-mf-stage">';
        html += '<div class="fn-mf-bar-bg">';
        html += '<div class="fn-mf-bar" style="width:' + barW + '%;background:' + color + ';">';
        if (barW > 22) html += pctStr;
        html += "</div></div>";
        html += '<div class="fn-mf-label">' + escapeAttr(lbl);
        html += ' <span class="fn-mf-pct">' + pctStr + "</span></div>";
        html += "</div>";
      }
      html += "</div></div>";
    }
    view.innerHTML = html;
  }

  // ---------------------------------------------------------------------------
  // Slope chart — full JS redraw (colors, legend, data points, y-axis scale)
  // ---------------------------------------------------------------------------

  // Intentionally uses the ORIGINAL focal (from pd.meta.focal_brand_code), not
  // state.focal (current UI selection), so colours stay fixed when the user
  // switches the focal brand. The state parameter is retained in the signature
  // for callsite compatibility but is not used inside this wrapper.
  function resolveBrandColor(pd, state, brandCode) {
    return TurasColours.getBrandColour(pd, brandCode);
  }

  function getBrandName(pd, brandCode) {
    var codes = (pd.table && pd.table.brand_codes) || [];
    var names = (pd.table && pd.table.brand_names) || codes;
    var idx = codes.indexOf(brandCode);
    return idx >= 0 ? names[idx] : brandCode;
  }

  function autoYTicks(yMin, yMax) {
    var range = (yMax - yMin) || 1;
    // Nice step size for ~4 ticks
    var rawStep = range / 4;
    var mag = Math.pow(10, Math.floor(Math.log10(rawStep)));
    var step = mag;
    if (rawStep / mag >= 5)      step = mag * 5;
    else if (rawStep / mag >= 2) step = mag * 2.5;
    else if (rawStep / mag >= 1) step = mag;
    var start = Math.ceil((yMin + 1e-9) / step) * step;
    var ticks = [];
    for (var t = start; t <= yMax + 1e-9; t = parseFloat((t + step).toFixed(10))) {
      ticks.push(parseFloat(t.toFixed(6)));
      if (ticks.length > 10) break;
    }
    return ticks;
  }

  function catmullRomPath(pts, tension) {
    if (!pts || pts.length < 2) return "";
    tension = tension !== undefined ? tension : 0.3;
    var d = "M" + pts[0].x.toFixed(2) + "," + pts[0].y.toFixed(2);
    for (var i = 0; i < pts.length - 1; i++) {
      var p0 = pts[Math.max(0, i - 1)];
      var p1 = pts[i];
      var p2 = pts[i + 1];
      var p3 = pts[Math.min(pts.length - 1, i + 2)];
      var cp1x = p1.x + (p2.x - p0.x) * tension;
      var cp1y = p1.y + (p2.y - p0.y) * tension;
      var cp2x = p2.x - (p3.x - p1.x) * tension;
      var cp2y = p2.y - (p3.y - p1.y) * tension;
      d += " C" + cp1x.toFixed(2) + "," + cp1y.toFixed(2) +
           " " + cp2x.toFixed(2) + "," + cp2y.toFixed(2) +
           " " + p2.x.toFixed(2) + "," + p2.y.toFixed(2);
    }
    return d;
  }

  function filterCallouts(callouts, brandCode) {
    var result = {};
    if (!callouts) return result;
    Object.keys(callouts).forEach(function(k) {
      var parts = k.split("::");
      if (parts[0] === brandCode) result[parseInt(parts[1])] = callouts[k];
    });
    return result;
  }

  function hexToRgba(hex, alpha) {
    var r = parseInt(hex.slice(1, 3), 16);
    var g = parseInt(hex.slice(3, 5), 16);
    var b = parseInt(hex.slice(5, 7), 16);
    return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
  }

  function updateChipColors(panel) {
    var pd = panel.__fnData;
    var state = panel.__fnState;
    panel.querySelectorAll(".fn-chart-brand-chips button").forEach(function(btn) {
      var code  = btn.getAttribute("data-fn-brand");
      var isOn  = state.chartBrands[code] !== false;
      btn.classList.toggle("col-chip-off", !isOn);
      btn.style.setProperty('--brand-chip-color', '');
      btn.style.backgroundColor = '';
      btn.style.borderColor = '';
      btn.style.color = '';
      if (isOn) {
        var color = (code === "__avg__") ? "#64748b"
                  : resolveBrandColor(pd, state, code);
        btn.style.setProperty('--brand-chip-color', color);
        btn.style.backgroundColor = color;
        btn.style.borderColor = color;
        btn.style.color = '#fff';
      }
    });
  }

  // brandCode, callouts, brandName, stageLabels used for callout/tooltip rendering
  // showVals: "focal" | "all" | "none" (old boolean true = "focal")
  function svgSeries(pcts, n, xFor, yFor, color, dashed, isFocal, showVals, brandCode, callouts, brandName, stageLabels) {
    var curvePts = [], circles = [], labels = [], calloutSvg = [];
    // Normalise legacy boolean
    if (showVals === true)  showVals = "focal";
    if (showVals === false) showVals = "none";
    for (var i = 0; i < n; i++) {
      var v = pcts && pcts[i];
      if (v == null || isNaN(v)) continue;
      var x = xFor(i), y = yFor(v);
      if (y == null) continue;
      curvePts.push({ x: x, y: y });
      var hasCallout = callouts && callouts[i] != null;
      // Data points always shown for all visible brands
      var r  = isFocal ? 6 : 3.5;
      var ck = brandCode + "::" + i;
      var tipStage = stageLabels ? escapeAttr(stageLabels[i] || "") : "";
      var tipBrand = escapeAttr(brandName || brandCode);
      circles.push(
        '<circle cx="' + x.toFixed(2) + '" cy="' + y.toFixed(2) +
        '" r="' + r + '" fill="' + color + '" stroke="#fff" stroke-width="' + (isFocal ? "2" : "1.5") +
        '" data-fn-callout-key="' + escapeAttr(ck) + '"' +
        ' data-fn-tip-brand="' + tipBrand + '"' +
        ' data-fn-tip-stage="' + tipStage + '"' +
        ' data-fn-tip-pct="' + Math.round(v * 100) + '"' +
        ' data-fn-tip-color="' + escapeAttr(color) + '"' +
        ' style="cursor:pointer"/>');
      // Value labels
      var showThisLabel = showVals === "all" || (showVals === "focal" && isFocal);
      if (showThisLabel) {
        var fs = isFocal ? "11" : "9";
        var fw = isFocal ? "700" : "500";
        var yOffset = isFocal ? 12 : 9;
        labels.push(
          '<text x="' + x.toFixed(2) + '" y="' + (y - yOffset).toFixed(2) +
          '" text-anchor="middle" font-size="' + fs + '" font-weight="' + fw + '" fill="' + color + '">' +
          Math.round(v * 100) + '%</text>');
      }
      if (callouts && callouts[i] != null) {
        var ct   = String(callouts[i]);
        var ck2  = brandCode + "::" + i;
        var tw   = Math.max(50, ct.length * 6.5 + 14);
        var bx   = x - tw / 2;
        var by   = Math.max(4, y - 44);
        calloutSvg.push(
          '<line x1="' + x.toFixed(2) + '" y1="' + (y - (isFocal ? 8 : 5)).toFixed(2) +
          '" x2="' + x.toFixed(2) + '" y2="' + (by + 18).toFixed(2) +
          '" stroke="' + color + '" stroke-width="1" stroke-dasharray="3,2"/>' +
          '<rect x="' + bx.toFixed(2) + '" y="' + by.toFixed(2) +
          '" width="' + tw.toFixed(0) + '" height="18" rx="4" fill="#1e293b"' +
          ' data-fn-callout-key="' + escapeAttr(ck2) + '" style="cursor:pointer"/>' +
          '<text x="' + x.toFixed(2) + '" y="' + (by + 12).toFixed(2) +
          '" text-anchor="middle" font-size="10" font-weight="600" fill="#fff"' +
          ' data-fn-callout-key="' + escapeAttr(ck2) + '" style="cursor:pointer">' +
          escapeAttr(ct) + "</text>");
      }
    }
    if (curvePts.length < 2) return "";
    var pathD = catmullRomPath(curvePts, 0.3);
    var dash  = dashed ? ' stroke-dasharray="5,4"' : "";
    var sw    = isFocal ? "3.5" : "1.8";
    var opaq  = isFocal ? "" : ' opacity="0.85"';
    return '<path d="' + pathD + '" fill="none" stroke="' + color +
      '" stroke-width="' + sw + '"' + dash + opaq + ' stroke-linecap="round" stroke-linejoin="round"/>' +
      circles.join("") + labels.join("") + calloutSvg.join("");
  }

  function buildSvgLegend(focalColour, ml, h, visibleComps, pd, shading, showAvg) {
    var y1 = h - 36;
    var y2 = h - 18;
    var items = [], x;

    x = ml;
    items.push('<line x1="' + x + '" y1="' + y1 + '" x2="' + (x + 18) + '" y2="' + y1 +
      '" stroke="' + focalColour + '" stroke-width="2.5"/>' +
      '<text x="' + (x + 24) + '" y="' + (y1 + 3) + '">Focal</text>');
    x += 70;
    if (showAvg) {
      items.push('<line x1="' + x + '" y1="' + y1 + '" x2="' + (x + 18) + '" y2="' + y1 +
        '" stroke="#64748b" stroke-width="2" stroke-dasharray="5,4"/>' +
        '<text x="' + (x + 24) + '" y="' + (y1 + 3) + '">Category avg</text>');
      x += 115;
    }
    if (shading === "range") {
      items.push('<rect x="' + x + '" y="' + (y1 - 6) + '" width="18" height="8" fill="rgba(148,163,184,0.18)"/>' +
        '<text x="' + (x + 24) + '" y="' + (y1 + 3) + '">Min\u2013max range</text>');
    } else if (shading === "ci") {
      items.push('<rect x="' + x + '" y="' + (y1 - 6) + '" width="18" height="8" fill="rgba(100,116,139,0.10)" stroke="rgba(100,116,139,0.35)" stroke-width="1"/>' +
        '<text x="' + (x + 24) + '" y="' + (y1 + 3) + '">\u00B195% CI (avg)</text>');
    }

    if (visibleComps.length > 0) {
      x = ml;
      for (var ci = 0; ci < visibleComps.length; ci++) {
        var vc = visibleComps[ci];
        var nm = getBrandName(pd, vc.brand_code);
        var label = nm.length > 13 ? nm.substring(0, 12) + "\u2026" : nm;
        var itemW = 30 + label.length * 6.2;
        if (x + itemW > 740) break;
        items.push('<line x1="' + x + '" y1="' + y2 + '" x2="' + (x + 18) + '" y2="' + y2 +
          '" stroke="' + vc.color + '" stroke-width="2"/>' +
          '<text x="' + (x + 24) + '" y="' + (y2 + 3) + '">' + escapeAttr(label) + '</text>');
        x += itemW;
      }
    }
    return '<g class="fn-slope-legend" font-size="10" fill="#64748b">' + items.join("") + '</g>';
  }

  function drawSlopeSvg(panel) {
    var svg = panel.querySelector(".fn-slope-svg");
    if (!svg) return;
    var pd = panel.__fnData;
    if (!pd || !pd.shape_chart) return;
    var sc = pd.shape_chart;

    var stageKeys = (sc.focal_series && sc.focal_series.stage_keys) ||
                    (sc.category_avg_series && sc.category_avg_series.stage_keys) || [];
    var n = stageKeys.length;
    if (n < 2) return;

    var tableStageKeys   = (pd.table && pd.table.stage_keys)   || [];
    var tableStageLabels = (pd.table && pd.table.stage_labels) || tableStageKeys;
    var stageLabels = stageKeys.map(function(k) {
      var idx = tableStageKeys.indexOf(k);
      return idx >= 0 ? tableStageLabels[idx] : k;
    });

    var state        = panel.__fnState;
    var currentFocal = state.focal;
    var origFocal    = pd.meta && pd.meta.focal_brand_code;
    var focalColour  = resolveBrandColor(pd, state, currentFocal || origFocal || "focal");
    var showValues   = state.showValues || "focal";  // "focal" | "all" | "none"
    var chartBrands  = state.chartBrands || {};
    var callouts     = state.callouts || {};
    var allComp      = sc.competitor_series || [];

    // Pick the right values array based on current base mode:
    //   "total"    — absolute % of all respondents
    //   "previous" — each stage as % of the previous stage
    //   "aware"    — each stage as % of awareness (awareness pinned to 100%)
    var pctMode = state.pctMode || "total";
    function pickPcts(series) {
      if (!series) return null;
      if (pctMode === "previous") return series.pct_values_nes || series.pct_values;
      if (pctMode === "aware")    return series.pct_values_aw  || series.pct_values;
      return series.pct_values;
    }

    // Determine focal pct_values and competitor list for current focal selection
    var focalPcts, compSeries = [];
    if (!currentFocal || currentFocal === origFocal) {
      focalPcts  = pickPcts(sc.focal_series);
      compSeries = allComp.slice();
    } else {
      var newEntry = null;
      for (var i = 0; i < allComp.length; i++) {
        if (allComp[i].brand_code === currentFocal) { newEntry = allComp[i]; break; }
      }
      focalPcts = pickPcts(newEntry || sc.focal_series);
      if (sc.focal_series) {
        compSeries.push({ brand_code: origFocal,
                          pct_values: pickPcts(sc.focal_series),
                          stage_keys: sc.focal_series.stage_keys });
      }
      for (var i = 0; i < allComp.length; i++) {
        if (allComp[i].brand_code !== currentFocal) compSeries.push(allComp[i]);
      }
    }

    // SVG layout — mr=60 ensures rightmost stage label never clips the viewBox
    var w = 760, h = 380, ml = 60, mr = 60, mt = 40, mb = 80;
    var pw = w - ml - mr, ph = h - mt - mb;

    // Y scale — driven by Min/Max inputs (% values, null = use full 0–100%)
    var yMin = (state.yMinInput != null) ? Math.max(0,   state.yMinInput / 100) : 0;
    var yMax = (state.yMaxInput != null) ? Math.min(1,   state.yMaxInput / 100) : 1;
    if (yMax <= yMin) { yMin = 0; yMax = 1; }

    var yRange = yMax - yMin || 1;
    function xFor(i) { return ml + pw * (i / Math.max(1, n - 1)); }
    function yFor(v) {
      if (v == null || isNaN(v)) return null;
      return mt + ph * (1 - (Math.max(yMin, Math.min(yMax, v)) - yMin) / yRange);
    }

    var shading = state.shading || "range";
    var parts = [];

    // Register callout click handler once (persists through innerHTML rebuilds)
    if (!svg.hasAttribute("data-fn-callout-init")) {
      svg.setAttribute("data-fn-callout-init", "1");
      svg.addEventListener("click", function(e) {
        var key = e.target.getAttribute("data-fn-callout-key");
        if (!key) return;
        var existing = (panel.__fnState.callouts || {})[key] || "";
        var text = window.prompt("Callout text (clear to remove):", existing);
        if (text === null) return;
        if (!panel.__fnState.callouts) panel.__fnState.callouts = {};
        if (text.trim() === "") delete panel.__fnState.callouts[key];
        else panel.__fnState.callouts[key] = text.trim();
        drawSlopeSvg(panel);
      });
    }

    // Register tooltip hover handler once
    if (!svg.hasAttribute("data-fn-tip-init")) {
      svg.setAttribute("data-fn-tip-init", "1");
      var tipEl = document.createElement("div");
      tipEl.className = "fn-slope-tooltip";
      panel.style.position = "relative";
      panel.appendChild(tipEl);
      svg.addEventListener("mousemove", function(e) {
        var circ = e.target;
        if (!circ.getAttribute || !circ.getAttribute("data-fn-tip-brand")) {
          tipEl.style.display = "none"; return;
        }
        var brand = circ.getAttribute("data-fn-tip-brand");
        var stage = circ.getAttribute("data-fn-tip-stage");
        var pct   = circ.getAttribute("data-fn-tip-pct");
        var color = circ.getAttribute("data-fn-tip-color") || "#1A5276";
        tipEl.innerHTML =
          '<div class="fn-st-color-bar" style="background:' + color + '"></div>' +
          '<div class="fn-st-body">' +
          '<div class="fn-st-brand">' + brand + '</div>' +
          '<div class="fn-st-stage">' + stage + '</div>' +
          '<div class="fn-st-pct" style="color:' + color + '">' + pct + '%</div>' +
          '</div>';
        tipEl.style.display = "block";
        var pRect = panel.getBoundingClientRect();
        var tipW = tipEl.offsetWidth || 130;
        var tipH = tipEl.offsetHeight || 70;
        var left = e.clientX - pRect.left - tipW / 2;
        var top  = e.clientY - pRect.top  - tipH - 14;
        if (left < 4) left = 4;
        if (left + tipW > pRect.width - 4) left = pRect.width - tipW - 4;
        if (top  < 4) top  = e.clientY - pRect.top + 14;
        tipEl.style.left = left + "px";
        tipEl.style.top  = top  + "px";
      });
      svg.addEventListener("mouseout", function(e) {
        if (e.target.getAttribute && e.target.getAttribute("data-fn-tip-brand")) {
          tipEl.style.display = "none";
        }
      });
    }

    // Shading band — range (min-max envelope), ci (±1.96 SE around avg), or none
    if (shading === "range") {
      var env = sc.envelope;
      if (env && env.min_values && env.max_values && env.min_values.length === n) {
        var topPts = [], botPts = [];
        for (var i = 0; i < n; i++) {
          var yt = yFor(env.max_values[i]), yb = yFor(env.min_values[i]);
          if (yt != null) topPts.push(xFor(i).toFixed(2) + "," + yt.toFixed(2));
          if (yb != null) botPts.unshift(xFor(i).toFixed(2) + "," + yb.toFixed(2));
        }
        if (topPts.length >= 2 && botPts.length >= 2) {
          parts.push('<polygon points="' + topPts.concat(botPts).join(" ") +
            '" fill="rgba(148,163,184,0.18)" stroke="none"/>');
        }
      }
    } else if (shading === "ci") {
      // Collect all brand pct values to compute ±1.96 SE band around category avg
      var allPctsCI = [];
      if (sc.focal_series) allPctsCI.push(pickPcts(sc.focal_series));
      allComp.forEach(function(cs) { var p = pickPcts(cs); if (p) allPctsCI.push(p); });
      if (allPctsCI.length >= 2) {
        var ciTopPts = [], ciBotPts = [];
        for (var i = 0; i < n; i++) {
          var vals = [];
          allPctsCI.forEach(function(p) { if (p && p[i] != null && !isNaN(p[i])) vals.push(p[i]); });
          if (vals.length < 2) continue;
          var mean = vals.reduce(function(a, b) { return a + b; }, 0) / vals.length;
          var sd = Math.sqrt(vals.reduce(function(a, v) { return a + (v - mean) * (v - mean); }, 0) / (vals.length - 1));
          var se = sd / Math.sqrt(vals.length);
          var yt = yFor(mean + 1.96 * se), yb = yFor(mean - 1.96 * se);
          if (yt != null) ciTopPts.push(xFor(i).toFixed(2) + "," + yt.toFixed(2));
          if (yb != null) ciBotPts.unshift(xFor(i).toFixed(2) + "," + yb.toFixed(2));
        }
        if (ciTopPts.length >= 2) {
          parts.push('<polygon points="' + ciTopPts.concat(ciBotPts).join(" ") +
            '" fill="rgba(100,116,139,0.10)" stroke="rgba(100,116,139,0.35)" stroke-width="1" stroke-dasharray="4,3"/>');
        }
      }
    }

    // Category avg dashed line (respects chip state)
    var avgPcts = pickPcts(sc.category_avg_series);
    var showAvg = chartBrands["__avg__"] !== false;
    if (avgPcts && showAvg) {
      var avgCallouts = filterCallouts(callouts, "__avg__");
      parts.push(svgSeries(avgPcts, n, xFor, yFor, "#64748b", true, false, showValues,
                           "__avg__", avgCallouts, "Category avg", stageLabels));
    }

    // Y gridlines + tick labels
    var yTicks = autoYTicks(yMin, yMax);
    yTicks.forEach(function(tv) {
      var ty = yFor(tv);
      if (ty == null) return;
      parts.push(
        '<line x1="' + ml + '" y1="' + ty.toFixed(2) + '" x2="' + (ml + pw) + '" y2="' + ty.toFixed(2) +
          '" stroke="#e2e8f0" stroke-width="1"/>' +
        '<text x="' + (ml - 6) + '" y="' + (ty + 3).toFixed(2) +
          '" font-size="10" fill="#94a3b8" text-anchor="end">' + Math.round(tv * 100) + '%</text>');
    });

    // X-axis baseline at bottom of plot area (visual minimum boundary)
    var xAxisY = mt + ph;
    parts.push(
      '<line x1="' + ml + '" y1="' + xAxisY + '" x2="' + (ml + pw) + '" y2="' + xAxisY +
        '" stroke="#94a3b8" stroke-width="1.5"/>' +
      '<text x="' + (ml - 6) + '" y="' + (xAxisY + 3) +
        '" font-size="10" fill="#94a3b8" text-anchor="end">' + Math.round(yMin * 100) + '%</text>');

    // Stage labels
    for (var i = 0; i < n; i++) {
      parts.push('<text x="' + xFor(i).toFixed(2) + '" y="' + (mt + ph + 22) +
        '" font-size="11" font-weight="500" fill="#1e293b" text-anchor="middle">' +
        escapeAttr(stageLabels[i] || stageKeys[i]) + '</text>');
    }

    // Competitor lines (differentiated colours, data points / values if showPts)
    var visibleComps = [];
    compSeries.forEach(function(cs) {
      if (!chartBrands[cs.brand_code]) return;
      var color = resolveBrandColor(pd, state, cs.brand_code);
      var cco = filterCallouts(callouts, cs.brand_code);
      var cName = getBrandName(pd, cs.brand_code);
      parts.push(svgSeries(pickPcts(cs) || [], n, xFor, yFor, color, false, false,
                           showValues, cs.brand_code, cco, cName, stageLabels));
      visibleComps.push({ brand_code: cs.brand_code, color: color });
    });

    // Focal line (always on top)
    if (focalPcts) {
      var fco = filterCallouts(callouts, currentFocal || origFocal || "focal");
      var fName = getBrandName(pd, currentFocal || origFocal || "focal");
      parts.push(svgSeries(focalPcts, n, xFor, yFor, focalColour, false, true, showValues,
                           currentFocal || origFocal || "focal", fco, fName, stageLabels));
    }

    // Legend (two rows: static + visible competitors)
    parts.push(buildSvgLegend(focalColour, ml, h, visibleComps, pd, shading, showAvg));

    // Show/hide "% of aware" annotation note
    var awareNote = panel.querySelector(".fn-aware-note");
    if (awareNote) awareNote.style.display = (pctMode === "aware") ? "" : "none";

    // Update viewBox to match new height and rebuild SVG content
    svg.setAttribute("viewBox", "0 0 " + w + " " + h);
    svg.innerHTML = parts.join("");

    // Colour chips to match their lines
    updateChipColors(panel);
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
  // Export table — builds an Excel-compatible HTML table and triggers download.
  // Respects current pct mode (% of total / % of previous / % of aware) and
  // includes a Base (n=) row and optional count rows when Show count is on.
  // ---------------------------------------------------------------------------
  function exportTable(panel) {
    var pd = panel.__fnData;
    if (!pd || !pd.table) { alert("No table data available."); return; }

    var brandCodes  = pd.table.brand_codes  || [];
    var brandNames  = pd.table.brand_names  || brandCodes;
    var stageKeys   = pd.table.stage_keys   || [];
    var stageLabels = pd.table.stage_labels || stageKeys;
    var cells       = pd.table.cells        || [];
    var pctMode     = panel.__fnState.pctMode;
    var showCounts  = panel.__fnState.showCounts;

    var cellMap = {};
    cells.forEach(function(c) {
      if (!cellMap[c.brand_code]) cellMap[c.brand_code] = {};
      cellMap[c.brand_code][c.stage_key] = c;
    });

    var avgMap = {};
    var avgRows = (pd.table && pd.table.avg_all_brands) || [];
    avgRows.forEach(function(r) { avgMap[r.stage_key] = r; });

    var nTotal = pd.meta ? Math.round(pd.meta.n_weighted || 0) : 0;
    var awareStageKey = stageKeys[0];

    // Brand aware pct lookup — mirrors applyPctMode logic for on-the-fly computation.
    var brandAwarePct = {};
    cells.forEach(function(c) {
      if (c.stage_key === awareStageKey) brandAwarePct[c.brand_code] = c.pct_absolute;
    });
    var avgAwarePct = (avgMap[awareStageKey] && avgMap[awareStageKey].pct_absolute) || null;

    // Pick the correct pct value for the current mode.
    // "aware" computed on the fly (pct_absolute / brand_aware_pct) — no dependency
    // on pct_aware being present in the JSON payload.
    function pickPct(obj, brandCode, stageIdx) {
      if (!obj) return null;
      if (pctMode === "previous") return obj.pct_nested != null ? obj.pct_nested : obj.pct_absolute;
      if (pctMode === "aware") {
        if (stageIdx === 0) return 1.0;
        var ap = brandCode ? brandAwarePct[brandCode] : avgAwarePct;
        if (ap && ap > 0 && obj.pct_absolute != null) return obj.pct_absolute / ap;
        return obj.pct_absolute;
      }
      return obj.pct_absolute;
    }

    // Helper: base row n= — n=300 (varies by brand) for non-total modes ≥ stage 2.
    function baseRowN(stageIdx) {
      if (pctMode === "total" || pctMode === "absolute" || stageIdx === 0) {
        return nTotal ? "n=" + nTotal : "";
      }
      return nTotal ? "n=" + nTotal + " (varies by brand)" : "";
    }

    // Helper: cell count — n=<stage_count> (<mode_denom>) per brand.
    function cellCountStr(code, sk, stageIdx) {
      var c = cellMap[code] && cellMap[code][sk];
      if (!c || c.base_unweighted == null) return "";
      var count = Math.round(c.base_unweighted);
      var denom = null;
      if (pctMode === "aware" && stageIdx > 0) {
        var awareCell = cellMap[code] && cellMap[code][awareStageKey];
        denom = awareCell && awareCell.base_unweighted != null
          ? Math.round(awareCell.base_unweighted) : null;
      } else if (pctMode === "previous" && stageIdx > 0) {
        var prevCell = cellMap[code] && cellMap[code][stageKeys[stageIdx - 1]];
        denom = prevCell && prevCell.base_unweighted != null
          ? Math.round(prevCell.base_unweighted) : null;
      }
      return denom != null ? "n=" + count + " (" + denom + ")" : "n=" + count;
    }

    var focal = panel.__fnState.focal;
    var tdStyle = 'border:1px solid #ccc;padding:4px 8px;font-family:Calibri,sans-serif;font-size:12px;';
    var baseModeLabel = pctMode === "previous" ? "% of previous stage"
                      : pctMode === "aware"    ? "% of aware respondents"
                      : "% of total sample";

    var html = '<html xmlns:o="urn:schemas-microsoft-com:office:office"' +
      ' xmlns:x="urn:schemas-microsoft-com:office:excel"' +
      ' xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="UTF-8">' +
      '<style>td,th{' + tdStyle + '}' +
      'th{background:#1a2744;color:#fff;font-weight:700;}' +
      '.focal{font-weight:700;background:#eef4fb;}' +
      '.avg{font-style:italic;background:#f5f6f8;}' +
      '.base{background:#f0f0f0;color:#555;}' +
      '.mode{background:#e8edf5;color:#1a2744;font-style:italic;font-size:11px;}' +
      '.count{color:#888;font-size:11px;}' +
      '</style></head><body><table>';

    // Base mode label row
    html += '<tr><td class="mode" colspan="' + (stageKeys.length + 1) + '">Base: ' + baseModeLabel + '</td></tr>';

    // Header row
    html += '<tr><th>Brand</th>';
    stageLabels.forEach(function(lbl) { html += '<th>' + lbl + '</th>'; });
    html += '</tr>';

    // Base (n=) row — category-average denominator, total in brackets for non-total modes
    html += '<tr><td class="base">Base (n=)</td>';
    stageKeys.forEach(function(sk, i) {
      html += '<td class="base">' + baseRowN(i) + '</td>';
    });
    html += '</tr>';

    brandCodes.forEach(function(code, i) {
      var name    = brandNames[i] || code;
      var isFocal = code === focal;
      var cls     = isFocal ? ' class="focal"' : '';
      var label   = isFocal ? name + ' (Focal)' : name;
      html += '<tr><td' + cls + '>' + label + '</td>';
      stageKeys.forEach(function(sk, si) {
        var c = cellMap[code] && cellMap[code][sk];
        var pct = pickPct(c, code, si);
        html += '<td' + cls + '>' + (pct != null ? Math.round(pct * 100) + '%' : '') + '</td>';
      });
      html += '</tr>';
      // Count row: n=<stage_count> (<mode_denom>) — only when Show count is on
      if (showCounts) {
        html += '<tr><td class="count">' + name + ' (n=)</td>';
        stageKeys.forEach(function(sk, si) {
          html += '<td class="count">' + cellCountStr(code, sk, si) + '</td>';
        });
        html += '</tr>';
      }
    });

    // Category Average row — pass null brandCode so pickPct uses avgAwarePct
    html += '<tr><td class="avg">Category average</td>';
    stageKeys.forEach(function(sk, si) {
      var r = avgMap[sk];
      var pct = pickPct(r, null, si);
      html += '<td class="avg">' + (pct != null ? Math.round(pct * 100) + '%' : '') + '</td>';
    });
    html += '</tr>';

    html += '</table></body></html>';

    var blob = new Blob([html], { type: 'application/vnd.ms-excel;charset=utf-8' });
    var url  = URL.createObjectURL(blob);
    var a    = document.createElement('a');
    a.href   = url;
    var cat  = (pd.meta && pd.meta.category_code) || 'funnel';
    a.download = 'funnel_table_' + cat + '.xls';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
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

  function applySortIndicators(panel) {
    var s = panel.__fnState.sort;
    panel.querySelectorAll('[data-fn-action="sort-brand"], [data-fn-action="sort-stage"]')
      .forEach(function(b) {
        var col = b.getAttribute("data-fn-action") === "sort-brand"
          ? "brand" : b.getAttribute("data-fn-stage");
        var dir = (s.col === col) ? s.dir : "none";
        b.setAttribute("data-fn-sort-dir", dir);
        b.textContent = dir === "asc" ? "\u2191" : dir === "desc" ? "\u2193" : "\u21C5";
      });
  }

  function setSort(panel, col, dir) {
    panel.__fnState.sort = { col: col, dir: dir };
    applySortIndicators(panel);

    var tbody = panel.querySelector("table.fn-table tbody");
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
  // Table significance markers — permanent ↑↓ arrows on cells that fall
  // outside the 95% CI of the category average (computed across all brands).
  // Applied once on init; independent of the shading mode.
  // ---------------------------------------------------------------------------
  function applyTableSigMarkers(panel) {
    var pd = panel.__fnData;
    if (!pd || !pd.table) return;
    var cells     = pd.table.cells     || [];
    var stageKeys = pd.table.stage_keys || [];

    // Compute 95% CI bounds per stage from all brand values
    var ciBounds = {};
    stageKeys.forEach(function(sk) {
      var vals = [];
      cells.forEach(function(c) {
        if (c.stage_key === sk && c.pct_absolute != null) vals.push(c.pct_absolute);
      });
      if (vals.length < 2) return;
      var mean = vals.reduce(function(a, b) { return a + b; }, 0) / vals.length;
      var sd   = Math.sqrt(vals.reduce(function(a, v) { return a + (v - mean) * (v - mean); }, 0) / (vals.length - 1));
      var se   = sd / Math.sqrt(vals.length);
      ciBounds[sk] = { lower: mean - 1.96 * se, upper: mean + 1.96 * se };
    });

    panel.querySelectorAll(".ct-heatmap-cell").forEach(function(td) {
      var row = td.closest("tr");
      if (!row || row.classList.contains("fn-row-base") || row.classList.contains("fn-row-avg-all")) return;
      if (td.classList.contains("fn-rel-td-avg")) return;
      var sk   = td.getAttribute("data-fn-stage");
      var bnds = sk && ciBounds[sk];
      if (!bnds) return;
      var pct = parseFloat(td.getAttribute("data-fn-pct-abs"));
      if (isNaN(pct)) return;
      var valEl = td.querySelector(".fn-pct-primary");
      if (!valEl) return;
      if (pct > bnds.upper) {
        valEl.insertAdjacentHTML("afterend", '<span class="fn-sig-avg fn-sig-avg-up">\u2191</span>');
      } else if (pct < bnds.lower) {
        valEl.insertAdjacentHTML("afterend", '<span class="fn-sig-avg fn-sig-avg-dn">\u2193</span>');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Export relationship table to Excel (.xls HTML format).
  // Writes a % row + n= row per brand, respecting the active base toggle.
  // ---------------------------------------------------------------------------
  function exportRelTableExcel(panel) {
    var table = panel.querySelector("[data-fn-rel-table]");
    if (!table) return;
    var hidden    = panel.__fnState.relHiddenBrands || new Set();
    var base      = (panel.__fnState && panel.__fnState.relBase) || "aware";
    var pctAttr   = base === "total" ? "data-fn-rel-pct-total"  : "data-fn-rel-pct-aware";
    var cntAttr   = base === "total" ? "data-fn-rel-count-total" : "data-fn-rel-count-aware";
    var denomAttr = base === "total" ? "data-fn-rel-denom-total" : "data-fn-rel-denom-aware";
    var baseLabel = base === "total" ? "% of total respondents"  : "% of aware respondents";

    var tdStyle = "border:1px solid #ccc;padding:4px 8px;font-family:Calibri,sans-serif;font-size:12px;";
    var html = '<html xmlns:o="urn:schemas-microsoft-com:office:office"' +
      ' xmlns:x="urn:schemas-microsoft-com:office:excel"' +
      ' xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="UTF-8">' +
      "<style>td,th{" + tdStyle + "}" +
      "th{background:#1a2744;color:#fff;font-weight:700;}" +
      ".mode{background:#e8edf5;color:#1a2744;font-style:italic;font-size:11px;}" +
      ".focal{font-weight:700;background:#eef4fb;}" +
      ".count{color:#888;font-size:11px;}" +
      ".avg{font-style:italic;background:#f5f6f8;}" +
      "</style></head><body><table>";

    // Column headers — strip sort-indicator button text
    var ths = Array.from(table.querySelectorAll("thead th"));
    var colCount = ths.length;
    var headers = ths.map(function(th) {
      var clone = th.cloneNode(true);
      var ind = clone.querySelector(".ct-sort-indicator");
      if (ind) clone.removeChild(ind);
      return clone.textContent.trim();
    });

    html += '<tr><td class="mode" colspan="' + colCount + '">Base: ' + baseLabel + '</td></tr>';
    html += "<tr>" + headers.map(function(h) { return "<th>" + h + "</th>"; }).join("") + "</tr>";

    table.querySelectorAll("tbody tr").forEach(function(tr) {
      if (tr.style.display === "none") return;
      var brand = tr.getAttribute("data-fn-brand");
      if (brand && hidden.has(brand)) return;

      var isAvg   = tr.classList.contains("fn-row-avg-all");
      var isFocal = tr.classList.contains("fn-row-focal");
      var cls     = isFocal ? ' class="focal"' : (isAvg ? ' class="avg"' : "");

      var tds = Array.from(tr.querySelectorAll("td"));

      // % row
      html += "<tr>";
      tds.forEach(function(td) {
        var role = td.getAttribute("data-fn-att");
        if (role) {
          var pct = parseFloat(td.getAttribute(pctAttr));
          html += "<td" + cls + ">" + (isNaN(pct) ? "" : Math.round(pct * 100) + "%") + "</td>";
        } else {
          // Label or Base column — strip FOCAL badge / CI bar markup
          var clone = td.cloneNode(true);
          var badge = clone.querySelector(".fn-focal-badge");
          if (badge) clone.removeChild(badge);
          var ciBar = clone.querySelector(".ma-ci-bar-wrap, .ma-ci-limits");
          if (ciBar) clone.removeChild(ciBar);
          html += "<td" + cls + ">" + clone.textContent.trim() + "</td>";
        }
      });
      html += "</tr>";

      // n= row — skip for avg row (no per-brand counts there)
      if (!isAvg) {
        var labelTd = tds[0];
        var labelClone = labelTd ? labelTd.cloneNode(true) : null;
        if (labelClone) {
          var badge2 = labelClone.querySelector(".fn-focal-badge");
          if (badge2) labelClone.removeChild(badge2);
        }
        var brandLabel = labelClone ? labelClone.textContent.trim() : "";
        html += "<tr>";
        tds.forEach(function(td, i) {
          var role = td.getAttribute("data-fn-att");
          if (role) {
            var cnt   = parseInt(td.getAttribute(cntAttr),   10);
            var denom = parseInt(td.getAttribute(denomAttr), 10);
            var str   = isNaN(cnt) ? "" : ("n=" + cnt + (!isNaN(denom) ? " (" + denom + ")" : ""));
            html += '<td class="count">' + str + "</td>";
          } else if (i === 0) {
            html += '<td class="count">' + brandLabel + " (n=)</td>";
          } else {
            html += '<td class="count"></td>';
          }
        });
        html += "</tr>";
      }
    });

    html += "</table></body></html>";

    var blob = new Blob([html], { type: "application/vnd.ms-excel;charset=utf-8" });
    var url  = URL.createObjectURL(blob);
    var a    = document.createElement("a");
    a.href = url;
    a.download = "brand_relationship.xls";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // ---------------------------------------------------------------------------
  // Pin dropdown — lists individually pinnable sections; calls TurasPin if
  // available, otherwise toggles a .fn-pinned outline as visual feedback.
  // ---------------------------------------------------------------------------
  function bindPinDropdown(panel) {
    var pinBtns = panel.querySelectorAll('[data-fn-action="pindropdown"]');
    if (!pinBtns.length) return;
    pinBtns.forEach(function(btn) { btn.addEventListener("click", function(e) {
      e.stopPropagation();
      var existing = panel.querySelector(".fn-pin-dropdown");
      if (existing) { existing.remove(); return; }

      var pd = panel.__fnData;
      var hasAI = pd && pd.meta && pd.meta.has_ai_insights;

      // Detect active subtab
      var activeSubtab = "funnel";
      var activeBtn = panel.querySelector(".fn-subtab-btn.active");
      if (activeBtn) activeSubtab = activeBtn.getAttribute("data-fn-subtab-target") || "funnel";

      var items;
      if (activeSubtab === "relationship") {
        items = [
          { label: "Relationship table", sel: ".fn-rel-table-wrap" },
          { label: "Relationship chart", sel: "[data-fn-rel-chart-area]" },
          { label: "Insights",           sel: ".fn-rel-chart-section .fn-insight-strip" }
        ];
      } else {
        // ".fn-chart-view[data-fn-view='slope']" is the outer chart wrapper div.
        // It avoids matching the Slope/Bar toggle BUTTON (which also carries
        // data-fn-view='slope'). The save handler resolves bar vs slope at
        // capture time so the active view is always pinned.
        items = [
          { label: "Table",        sel: ".fn-table-wrap" },
          { label: "Chart",        sel: ".fn-chart-view[data-fn-view='slope']" },
          { label: "Mini funnels", sel: ".fn-mini-funnels-view[data-fn-view='minifunnels']" },
          { label: "Insights",     sel: ".fn-insight-strip" }
        ];
      }
      if (hasAI) items.push({ label: "AI insights", sel: ".fn-ai-insights" });

      var html = '<div class="fn-pin-dropdown" role="dialog" aria-label="Pin sections">' +
        '<div class="fn-pin-header">Pin sections</div>';
      items.forEach(function(item) {
        html += '<label class="fn-pin-item">' +
          '<input type="checkbox" class="fn-pin-chk" data-fn-pin-sel="' +
          item.sel.replace(/"/g, "&quot;") + '"> ' + item.label + '</label>';
      });
      html += '<div class="fn-pin-footer"><button class="fn-pin-save-btn" type="button">Pin selected</button></div></div>';

      btn.insertAdjacentHTML("afterend", html);
      var drop = panel.querySelector(".fn-pin-dropdown");
      var btnRect = btn.getBoundingClientRect();
      var pRect   = panel.getBoundingClientRect();
      drop.style.top  = (btnRect.bottom - pRect.top + 4) + "px";
      drop.style.left = (btnRect.left   - pRect.left)    + "px";

      drop.addEventListener("click", function(e) { e.stopPropagation(); });
      setTimeout(function() {
        document.addEventListener("click", function closeDrop() {
          if (drop.parentNode) drop.remove();
          document.removeEventListener("click", closeDrop);
        });
      }, 0);

      drop.querySelector(".fn-pin-save-btn").addEventListener("click", function() {
        if (typeof TurasPins === "undefined") { drop.remove(); return; }

        var pd       = panel.__fnData;
        var catLabel = (pd && pd.meta && pd.meta.category_label) ||
                       (pd && pd.meta && pd.meta.category_code) || "Brand";
        var isRel    = (activeSubtab === "relationship");
        var focalName = "";
        if (pd && pd.table) {
          var codes = pd.table.brand_codes || [];
          var names = pd.table.brand_names || codes;
          var fi = codes.indexOf(panel.__fnState.focal);
          if (fi >= 0) focalName = names[fi];
        }

        var title = "Brand " + (isRel ? "Relationship" : "Funnel") + " \u2013 " + catLabel;
        if (focalName) title += " \u2013 " + focalName;

        var chartSvg    = "";
        var tableHtml   = "";
        var insightText = "";
        var hasChart    = false;
        var hasTable    = false;
        var hasInsight  = false;

        drop.querySelectorAll(".fn-pin-chk:checked").forEach(function(chk) {
          var label = chk.parentNode.textContent.trim();
          var sel   = chk.getAttribute("data-fn-pin-sel");
          var el    = panel.querySelector(sel);
          if (!el) return;

          if (/insight/i.test(label)) {
            // Read textarea value — do NOT capture the DOM element itself
            var ta  = el.querySelector(".fn-insight-textarea");
            var txt = ta ? ta.value.trim() : "";
            if (txt) { insightText = txt; hasInsight = true; }
          } else if (label === "Chart" && !chartSvg) {
            // Use bar wrap when bar view is active; slope container otherwise.
            var barWrap = panel.querySelector(".fn-bar-wrap");
            var chartEl = (barWrap && !barWrap.hidden) ? barWrap : el;
            var svgEl = chartEl.querySelector("svg");
            if (svgEl) {
              var svgClone = svgEl.cloneNode(true);
              if (!svgClone.getAttribute("viewBox")) {
                var rect = svgEl.getBoundingClientRect();
                if (rect.width > 0) {
                  svgClone.setAttribute("viewBox", "0 0 " + rect.width + " " + rect.height);
                }
              }
              if (!svgClone.getAttribute("width"))  svgClone.setAttribute("width",  svgEl.getBoundingClientRect().width  || "");
              if (!svgClone.getAttribute("height")) svgClone.setAttribute("height", svgEl.getBoundingClientRect().height || "");
              chartSvg = svgClone.outerHTML;
              hasChart = true;
            }
          } else {
            // Table, Mini funnels, Relationship table/chart, AI insights
            var tbl = el.querySelector("table");
            if (tbl) {
              tableHtml += TurasPins.capturePortableHtml
                ? TurasPins.capturePortableHtml(tbl)
                : tbl.outerHTML;
            } else {
              tableHtml += el.outerHTML;
            }
            hasTable = true;
          }
        });

        if (!hasChart && !hasTable && !hasInsight) { drop.remove(); return; }

        // Strip interactive controls so the pinned card is a static snapshot.
        if (typeof window.brStripInteractive === "function") {
          tableHtml = window.brStripInteractive(tableHtml);
        }

        // Active "Base:" toggle — captured from the panel so the pin/PNG
        // records which percentage base the user was looking at.
        var baseLabel = (typeof window.brReadBaseLabel === "function")
          ? window.brReadBaseLabel(panel) : "";

        TurasPins.add({
          sectionKey:  "fn-" + Date.now(),
          title:       title,
          subtitle:    baseLabel ? "Base: " + baseLabel : "",
          baseText:    baseLabel,
          chartSvg:    chartSvg,
          tableHtml:   tableHtml,
          insightText: insightText,
          pinFlags:    { chart: hasChart, table: hasTable, insight: hasInsight },
          pinMode:     "custom"
        });
        drop.remove();
      });
    }); });
  }

  // ---------------------------------------------------------------------------
  // Relationship chart — horizontal stacked bars (brands = rows)
  // ---------------------------------------------------------------------------
  var REL_SEG_ROLES = [
    "attitude.love","attitude.prefer","attitude.ambivalent",
    "attitude.reject","attitude.no_opinion"
  ];
  var REL_SEG_COLORS = {
    "attitude.love":       "#2E7D32",
    "attitude.prefer":     "#81C784",
    "attitude.ambivalent": "#F9A825",
    "attitude.reject":     "#C62828",
    "attitude.no_opinion": "#90A4AE"
  };
  var REL_SEG_LABELS = {
    "attitude.love":       "Love",
    "attitude.prefer":     "Prefer",
    "attitude.ambivalent": "Ambivalent",
    "attitude.reject":     "Reject",
    "attitude.no_opinion": "No opinion"
  };

  function initRelChart(panel) {
    if (!panel.querySelector("[data-fn-rel-chart]")) return;
    panel.__fnState.relEmphasisSet  = new Set();
    panel.__fnState.relBase         = "aware";
    panel.__fnState.relSortCol      = "brand";
    panel.__fnState.relSortDir      = "asc";
    panel.__fnState.relHiddenBrands = new Set();
    panel.__fnState.relShowChart    = true;
    panel.__fnState.relShowCount    = false;
    panel.__fnState.tableShading    = "off";

    var pd = panel.__fnData;

    // Seed relHiddenBrands from DOM under chip_default = focal_only — chips
    // rendered without .active count as hidden. Also add col-chip-off so the
    // toggleall handler (which reads col-chip-off) sees the same state.
    panel.querySelectorAll("[data-fn-rel-brand]").forEach(function(chip) {
      var code = chip.getAttribute("data-fn-rel-brand");
      if (!code || code === "__avg__") return;
      if (!chip.classList.contains("active")) {
        panel.__fnState.relHiddenBrands.add(code);
        chip.classList.add("col-chip-off");
      }
    });

    // Apply brand colours to brand chips from pd.config.brand_colours
    panel.querySelectorAll("[data-fn-rel-brand]").forEach(function(chip) {
      var code = chip.getAttribute("data-fn-rel-brand");
      if (code === "__avg__") return;
      var color = (pd && pd.config && pd.config.brand_colours && pd.config.brand_colours[code])
                  || resolveBrandColor(pd, panel.__fnState, code);
      if (color) chip.style.setProperty("--brand-chip-color", color);
    });

    // Apply sentiment colours to emphasis chips
    panel.querySelectorAll("[data-fn-rel-emphasis]").forEach(function(btn) {
      var role = btn.getAttribute("data-fn-rel-emphasis");
      var col  = REL_SEG_COLORS[role];
      if (col) btn.style.setProperty("--seg-chip-color", col);
    });

    // Emphasis chips — multi-select; "All" chip clears set
    panel.querySelectorAll("[data-fn-rel-emphasis]").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var role = btn.getAttribute("data-fn-rel-emphasis");
        var eset = panel.__fnState.relEmphasisSet;
        if (role === "all") {
          eset.clear();
        } else {
          if (eset.has(role)) { eset.delete(role); } else { eset.add(role); }
        }
        panel.querySelectorAll("[data-fn-rel-emphasis]").forEach(function(b) {
          var bRole = b.getAttribute("data-fn-rel-emphasis");
          b.classList.toggle("active", bRole === "all" ? eset.size === 0 : eset.has(bRole));
        });
        buildRelChart(panel);
        updateRelHeadline(panel);
      });
    });

    // Show all / Hide all toggle for relationship chip bar
    panel.querySelectorAll('button[data-fn-rel-action="toggleall"]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var focal  = panel.__fnState.focal;
        var hidden = panel.__fnState.relHiddenBrands;
        var chips  = panel.querySelectorAll('[data-fn-rel-brand]');
        var nonFocal = [];
        chips.forEach(function(c) {
          if (c.getAttribute('data-fn-rel-brand') !== focal) nonFocal.push(c);
        });
        var allOn = nonFocal.every(function(c) { return !c.classList.contains('col-chip-off'); });
        var nextState = !allOn;
        nonFocal.forEach(function(c) {
          var code = c.getAttribute('data-fn-rel-brand');
          if (nextState) {
            hidden.delete(code);
            c.classList.add('active');
            c.classList.remove('col-chip-off');
          } else {
            hidden.add(code);
            c.classList.remove('active');
            c.classList.add('col-chip-off');
          }
        });
        applyRelBrandVis(panel);
        buildRelChart(panel);
        updateRelHeadline(panel);
        btn.textContent = nextState ? 'Hide all' : 'Show all';
      });
    });

    // Brand chips — toggle visibility in chart and table
    panel.querySelectorAll("[data-fn-rel-brand]").forEach(function(chip) {
      chip.addEventListener("click", function() {
        var code   = chip.getAttribute("data-fn-rel-brand");
        var hidden = panel.__fnState.relHiddenBrands;
        if (hidden.has(code)) {
          hidden.delete(code);
          chip.classList.add("active");
          chip.classList.remove("col-chip-off");
        } else {
          hidden.add(code);
          chip.classList.remove("active");
          chip.classList.add("col-chip-off");
        }
        applyRelBrandVis(panel);
        buildRelChart(panel);
        updateRelHeadline(panel);
      });
    });

    // Column header sort
    panel.querySelectorAll("[data-fn-rel-sortable]").forEach(function(th) {
      th.addEventListener("click", function() {
        var col    = th.getAttribute("data-fn-rel-sortable");
        var curCol = panel.__fnState.relSortCol;
        var curDir = panel.__fnState.relSortDir;
        panel.__fnState.relSortCol = col;
        panel.__fnState.relSortDir = (col === curCol)
          ? (curDir === "desc" ? "asc" : "desc")
          : (col === "brand" ? "asc" : "desc");
        sortRelTable(panel);
        buildRelChart(panel);
      });
    });

    // Base toggle
    panel.querySelectorAll("[data-fn-rel-base]").forEach(function(btn) {
      btn.addEventListener("click", function() {
        panel.__fnState.relBase = btn.getAttribute("data-fn-rel-base");
        panel.querySelectorAll("[data-fn-rel-base]").forEach(function(b) {
          var on = b === btn;
          b.classList.toggle("sig-btn-active", on);
          b.setAttribute("aria-pressed", on ? "true" : "false");
        });
        buildRelChart(panel);
        applyRelTableBase(panel);
        var pctAttr2 = panel.__fnState.relBase === "total" ? "data-fn-rel-pct-total" : "data-fn-rel-pct-aware";
        var relShowCI2 = panel.querySelector('[data-fn-rel-showci]');
        if (relShowCI2 && relShowCI2.checked) applyRelTableHeatmap(panel, pctAttr2);
        applyRelTableSigMarkers(panel);
        sortRelTable(panel);
      });
    });

    // CI bands checkbox (relationship table)
    var relShowCI = panel.querySelector('[data-fn-rel-showci]');
    if (relShowCI) relShowCI.addEventListener("change", function() {
      var pctAttr = (panel.__fnState.relBase === "total")
        ? "data-fn-rel-pct-total" : "data-fn-rel-pct-aware";
      panel.querySelectorAll("[data-fn-rel-table] td.ct-heatmap-cell").forEach(function(td) {
        td.classList.remove("fn-ci-above", "fn-ci-within", "fn-ci-below");
        td.style.removeProperty("background-color");
      });
      if (relShowCI.checked) {
        panel.classList.remove("fn-heatmap-off");
        applyRelTableCI(panel, pctAttr);
      }
    });

    // Show count checkbox — show-freq class reveals .ct-freq spans
    var relShowCounts = panel.querySelector('[data-fn-rel-showcounts]');
    if (relShowCounts) relShowCounts.addEventListener("change", function() {
      panel.__fnState.relShowCount = relShowCounts.checked;
      panel.classList.toggle("show-freq", relShowCounts.checked);
    });

    // Show/hide chart checkbox
    var relShowChart = panel.querySelector('[data-fn-rel-showchart]');
    if (relShowChart) relShowChart.addEventListener("change", function() {
      panel.__fnState.relShowChart = relShowChart.checked;
      var area = panel.querySelector("[data-fn-rel-chart-area]");
      if (area) area.style.display = relShowChart.checked ? "" : "none";
    });

    // Export button
    var exportBtn = panel.querySelector("[data-fn-rel-action='export']");
    if (exportBtn) {
      exportBtn.addEventListener("click", function() { exportRelTableExcel(panel); });
    }

    buildRelChart(panel);
    applyRelTableBase(panel);
    applyRelTableSigMarkers(panel);
    sortRelTable(panel);
    applyRelBrandVis(panel);
  }

  function relPct(brand, role, base, nTotal) {
    // segments[role] = count/n_total (% of total respondents, session-3 fix)
    var segVal = brand.segments && brand.segments[role] != null
      ? brand.segments[role] : 0;
    // "% aware" = scale up to aware denominator; "% total" = use as-is
    if (base === "aware" && nTotal && brand.aware_base && brand.aware_base > 0) {
      return segVal * (nTotal / brand.aware_base);
    }
    return segVal;
  }

  function buildRelChart(panel) {
    var container = panel.querySelector("[data-fn-rel-chart]");
    if (!container) return;
    var pd = panel.__fnData;
    if (!pd || !pd.consideration_detail) { container.innerHTML = ""; return; }

    var allBrands = pd.consideration_detail.brands || [];
    var hidden    = panel.__fnState.relHiddenBrands || new Set();
    var brands    = allBrands.filter(function(b) { return !hidden.has(b.brand_code); });
    var focal     = panel.__fnState.focal;
    var emphSet   = panel.__fnState.relEmphasisSet || new Set();
    var isAll     = emphSet.size === 0;
    var sortCol   = panel.__fnState.relSortCol  || "brand";
    var sortDir   = panel.__fnState.relSortDir  || "asc";
    var base      = panel.__fnState.relBase     || "aware";
    var nTotalEl  = container.closest("[data-fn-rel-ntotal]");
    var nTotal    = (pd.meta && (pd.meta.n_weighted || pd.meta.n_unweighted)) ||
                    (nTotalEl ? parseFloat(nTotalEl.getAttribute("data-fn-rel-ntotal")) : 0);
    var useTotal  = (base === "total");
    var showAvg   = !hidden.has("__avg__");

    var focalBrand = null, compBrands = [];
    brands.forEach(function(b) {
      if (b.brand_code === focal) focalBrand = b; else compBrands.push(b);
    });

    var sortedComps = compBrands.slice();
    if (sortCol === "brand") {
      sortedComps.sort(function(a, b) {
        var an = (a.brand_name || a.brand_code).toLowerCase();
        var bn = (b.brand_name || b.brand_code).toLowerCase();
        return sortDir === "asc" ? an.localeCompare(bn) : bn.localeCompare(an);
      });
    } else {
      sortedComps.sort(function(a, b) {
        var av = relPct(a, sortCol, base, nTotal);
        var bv = relPct(b, sortCol, base, nTotal);
        return sortDir === "desc" ? bv - av : av - bv;
      });
    }

    // Cat avg segments (computed across ALL brands for consistency).
    //
    // For "% aware" base, we POOL across brands instead of taking an
    // unweighted mean of per-brand rescaled fractions. The unweighted mean
    // is fragile: any brand with a very low aware_base gets a huge rescale
    // factor (nTotal/aware_base), inflating its contribution and pushing
    // the cross-brand mean far beyond 100% (the bug seen on the exported
    // Brand Relationship slide where Cat avg row summed to 185%).
    //
    // Pooled formula:
    //   cat_avg_aware[role] = sum_b(segments[b][role] * nTotal) / sum_b(aware_base[b])
    // Conceptually: treat all (brand × respondent) cells as one bag and
    // compute the fraction of that bag falling into each segment among
    // aware respondents.
    var avgSegments = null;
    if (showAvg && allBrands.length > 0) {
      avgSegments = {};
      var totalAware = 0;
      allBrands.forEach(function(b) { totalAware += (b.aware_base || 0); });
      if (base === "aware" && nTotal && totalAware > 0) {
        REL_SEG_ROLES.forEach(function(role) {
          var sumCount = 0;
          allBrands.forEach(function(b) {
            var seg = (b.segments && b.segments[role]) || 0;
            sumCount += seg * nTotal;
          });
          avgSegments[role] = sumCount / totalAware;
        });
      } else {
        // % total or no aware data — unweighted mean is fine here.
        REL_SEG_ROLES.forEach(function(role) {
          var vals = allBrands.map(function(b) { return relPct(b, role, base, nTotal); });
          avgSegments[role] = vals.reduce(function(s, v) { return s + v; }, 0) / vals.length;
        });
      }
      // Safety clamp: if the pooled values still exceed 100% in total
      // (data anomaly — e.g. segment definitions overlap), normalise so
      // the bar stays sensible. Keeps the relative shape, prevents the
      // 185% nonsense from reaching the user.
      var avgTotal = 0;
      REL_SEG_ROLES.forEach(function(r) { avgTotal += (avgSegments[r] || 0); });
      if (avgTotal > 1.05) {
        REL_SEG_ROLES.forEach(function(r) {
          avgSegments[r] = (avgSegments[r] || 0) / avgTotal;
        });
      }
    }

    // Max bar total for proportional track widths (total-base mode only)
    var maxBarTotal = 0;
    if (useTotal) {
      var checkRows = (focalBrand ? [focalBrand] : []).concat(sortedComps);
      checkRows.forEach(function(b) {
        var t = REL_SEG_ROLES.reduce(function(s, r) { return s + relPct(b, r, base, nTotal); }, 0);
        if (t > maxBarTotal) maxBarTotal = t;
      });
      if (avgSegments) {
        var at = REL_SEG_ROLES.reduce(function(s, r) { return s + (avgSegments[r] || 0); }, 0);
        if (at > maxBarTotal) maxBarTotal = at;
      }
    }

    // Render one horizontal bar row
    function renderRow(brandCode, segs, rowCls, labelHtml) {
      var totalPct = REL_SEG_ROLES.reduce(function(s, r) { return s + (segs[r] || 0); }, 0);
      var trackFlex = useTotal
        ? (maxBarTotal > 0 ? (totalPct / maxBarTotal).toFixed(4) : "0")
        : "1";

      var segHtml  = "";

      REL_SEG_ROLES.forEach(function(role) {
        var pct      = segs[role] || 0;
        var widthPct = totalPct > 0 ? (pct / totalPct) * 100 : 0;
        var isEmph   = isAll || emphSet.has(role);
        var color    = isEmph ? REL_SEG_COLORS[role] : "rgba(148,163,184,0.18)";
        var insideLbl = "";

        if (isEmph && pct > 0 && widthPct >= 2) {
          insideLbl = '<span class="fn-rel-seg-label-inside">' + Math.round(pct * 100) + '%</span>';
        }

        segHtml += '<div class="fn-rel-seg" data-fn-role="' + escapeAttr(role) +
          '" style="width:' + widthPct.toFixed(2) + '%;background:' + color + ';">' +
          insideLbl + '</div>';
      });

      return '<div class="' + rowCls + '" data-fn-brand="' + escapeAttr(brandCode) + '">' +
        '<div class="fn-rel-bar-label">' + labelHtml + '</div>' +
        '<div class="fn-rel-bar-area">' +
        '<div class="fn-rel-bar-track" style="flex:' + trackFlex + ' ' + trackFlex + ' 0%;">' +
        segHtml + '</div>' +
        '</div></div>';
    }

    var html = '<div class="fn-rel-chart-inner">';

    // Focal brand first
    if (focalBrand) {
      var fSegs = {};
      REL_SEG_ROLES.forEach(function(r) { fSegs[r] = relPct(focalBrand, r, base, nTotal); });
      var fLbl = escapeAttr(focalBrand.brand_name || focalBrand.brand_code) + ' <span class="fn-focal-badge">FOCAL</span>';
      html += renderRow(focalBrand.brand_code, fSegs, "fn-rel-bar-row fn-rel-bar-row-focal", fLbl);
    }

    // Cat avg (if visible)
    if (avgSegments) {
      html += renderRow("__avg__", avgSegments, "fn-rel-bar-row fn-rel-bar-row-avg", "<em>Cat avg</em>");
    }

    // Competitors
    sortedComps.forEach(function(brand) {
      var bSegs = {};
      REL_SEG_ROLES.forEach(function(r) { bSegs[r] = relPct(brand, r, base, nTotal); });
      html += renderRow(brand.brand_code, bSegs, "fn-rel-bar-row", escapeAttr(brand.brand_name || brand.brand_code));
    });

    // Legend
    html += '<div class="fn-rel-legend">';
    REL_SEG_ROLES.forEach(function(role) {
      var isEmph = isAll || emphSet.has(role);
      var color  = isEmph ? REL_SEG_COLORS[role] : "rgba(148,163,184,0.30)";
      html += '<div class="fn-rel-legend-item">' +
        '<div class="fn-rel-legend-swatch" style="background:' + color + '"></div>' +
        '<span>' + escapeAttr(REL_SEG_LABELS[role]) + '</span></div>';
    });
    html += '</div></div>';

    container.innerHTML = html;
    updateRelHeadline(panel);
  }

  function updateRelHeadline(panel) {
    var hdEl = panel.querySelector("[data-fn-rel-headline]");
    if (!hdEl) return;
    var emphSet = panel.__fnState.relEmphasisSet || new Set();
    // Only show headline when exactly one segment is emphasised
    if (emphSet.size !== 1) { hdEl.style.display = "none"; return; }
    var emphasis = emphSet.values().next().value;

    var pd = panel.__fnData;
    if (!pd || !pd.consideration_detail) return;
    var allBrands = pd.consideration_detail.brands || [];
    var hidden    = panel.__fnState.relHiddenBrands || new Set();
    var brands    = allBrands.filter(function(b) { return !hidden.has(b.brand_code); });
    var focal     = panel.__fnState.focal;
    var base      = panel.__fnState.relBase || "aware";
    var nTotal    = pd.meta && (pd.meta.n_weighted || pd.meta.n_unweighted);

    var brandPcts = brands
      .map(function(b) { return { brand: b, pct: relPct(b, emphasis, base, nTotal) }; })
      .filter(function(x) { return x.pct > 0; });
    if (!brandPcts.length) { hdEl.style.display = "none"; return; }

    var sum    = brandPcts.reduce(function(s, x) { return s + x.pct; }, 0);
    var catAvg = sum / brandPcts.length;
    var sorted = brandPcts.slice().sort(function(a, b) { return b.pct - a.pct; });
    var top    = sorted[0];

    var topStr    = Math.round(top.pct * 100) + "%";
    var avgStr    = Math.round(catAvg * 100) + "%";
    var ratio     = catAvg > 0 ? top.pct / catAvg : null;
    var roleName  = REL_SEG_LABELS[emphasis] || emphasis;
    var brandName = escapeAttr(top.brand.brand_name || top.brand.brand_code);

    var prefix;
    if (emphasis === "attitude.reject") {
      prefix = "<strong>" + brandName + "</strong> has the highest active rejection";
    } else if (top.brand.brand_code === focal) {
      prefix = "<strong>" + brandName + "</strong> leads on <em>" + roleName + "</em>";
    } else {
      prefix = "<strong>" + brandName + "</strong> has the highest <em>" + roleName + "</em>";
    }

    var suffix = " at <strong>" + topStr + "</strong>";
    suffix += (ratio != null && ratio >= 1.5)
      ? " \u2014 " + ratio.toFixed(1) + "\u00D7 the category average (" + avgStr + ")"
      : " (category avg: " + avgStr + ")";

    hdEl.innerHTML = '<div class="fn-rel-headline-text">' + prefix + suffix + '</div>';
    hdEl.style.display = "";
  }

  function sortRelTable(panel) {
    var table = panel.querySelector("[data-fn-rel-table]");
    if (!table) return;
    var tbody = table.querySelector("tbody");
    if (!tbody) return;

    var col  = panel.__fnState.relSortCol || "brand";
    var dir  = panel.__fnState.relSortDir || "asc";
    var base = panel.__fnState.relBase    || "aware";
    var attr = base === "total" ? "data-fn-rel-pct-total" : "data-fn-rel-pct-aware";

    var focalRow = tbody.querySelector("tr.fn-row-focal");
    var avgRow   = tbody.querySelector("tr.fn-row-avg-all");
    var compRows = Array.from(tbody.querySelectorAll("tr.fn-row-competitor"));

    compRows.sort(function(a, b) {
      if (col === "brand") {
        var aLbl = a.querySelector(".ct-label-col");
        var bLbl = b.querySelector(".ct-label-col");
        var an   = (aLbl ? aLbl.textContent.trim() : a.getAttribute("data-fn-brand") || "").toLowerCase();
        var bn   = (bLbl ? bLbl.textContent.trim() : b.getAttribute("data-fn-brand") || "").toLowerCase();
        return dir === "asc" ? an.localeCompare(bn) : bn.localeCompare(an);
      } else {
        var aCell = a.querySelector('td[data-fn-att="' + col + '"]');
        var bCell = b.querySelector('td[data-fn-att="' + col + '"]');
        var av    = aCell ? parseFloat(aCell.getAttribute(attr)) : -1;
        var bv    = bCell ? parseFloat(bCell.getAttribute(attr)) : -1;
        if (isNaN(av)) av = -1; if (isNaN(bv)) bv = -1;
        return dir === "desc" ? bv - av : av - bv;
      }
    });

    // Rebuild tbody: focal → avg → sorted competitors
    var frag = document.createDocumentFragment();
    if (focalRow) frag.appendChild(focalRow);
    if (avgRow)   frag.appendChild(avgRow);
    compRows.forEach(function(r) { frag.appendChild(r); });
    tbody.appendChild(frag);

    // Update sort indicator icons
    panel.querySelectorAll("[data-fn-rel-sort-ind]").forEach(function(el) {
      var c = el.getAttribute("data-fn-rel-sort-ind");
      if (c === col) {
        el.textContent = dir === "desc" ? "\u2193" : "\u2191";
        el.setAttribute("data-fn-sort-dir", dir);
      } else {
        el.textContent = "\u2195";
        el.setAttribute("data-fn-sort-dir", "");
      }
    });
  }

  function applyRelBrandVis(panel) {
    var table = panel.querySelector("[data-fn-rel-table]");
    if (!table) return;
    var hidden = panel.__fnState.relHiddenBrands || new Set();
    table.querySelectorAll("tr[data-fn-brand]").forEach(function(row) {
      row.style.display = hidden.has(row.getAttribute("data-fn-brand")) ? "none" : "";
    });
    // Category avg row controlled by __avg__ chip
    var avgRow = table.querySelector("tr.fn-row-avg-all");
    if (avgRow) avgRow.style.display = hidden.has("__avg__") ? "none" : "";
  }

  function applyRelTableBase(panel) {
    var table = panel.querySelector("[data-fn-rel-table]");
    if (!table) return;
    var base    = (panel.__fnState && panel.__fnState.relBase) || "aware";
    var pctAttr = base === "total" ? "data-fn-rel-pct-total"  : "data-fn-rel-pct-aware";
    var cntAttr = base === "total" ? "data-fn-rel-count-total" : "data-fn-rel-count-aware";
    var denomAttr = base === "total" ? "data-fn-rel-denom-total" : "data-fn-rel-denom-aware";
    table.querySelectorAll("td.ct-heatmap-cell[data-fn-att]").forEach(function(td) {
      var pct   = parseFloat(td.getAttribute(pctAttr));
      var cnt   = parseInt(td.getAttribute(cntAttr), 10);
      var denom = parseInt(td.getAttribute(denomAttr), 10);
      var valEl  = td.querySelector(".ct-val");
      var freqEl = td.querySelector(".ct-freq");
      if (valEl && !isNaN(pct)) valEl.textContent = Math.round(pct * 100) + "%";
      if (freqEl && !isNaN(cnt)) {
        freqEl.textContent = "n=" + cnt + (!isNaN(denom) ? " (" + denom + ")" : "");
      }
    });
    // Update avg row cells (fn-rel-td-avg, not ct-heatmap-cell)
    table.querySelectorAll("td.fn-rel-td-avg[data-fn-att]").forEach(function(td) {
      var pct = parseFloat(td.getAttribute(pctAttr));
      var valEl = td.querySelector(".ct-val");
      if (valEl && !isNaN(pct)) valEl.textContent = Math.round(pct * 100) + "%";
      // Re-render CI bar with mode-specific bounds
      var ciLo = parseFloat(td.getAttribute("data-fn-rel-ci-lo-" + base));
      var ciHi = parseFloat(td.getAttribute("data-fn-rel-ci-hi-" + base));
      var barWrap   = td.querySelector(".ma-ci-bar-wrap");
      var barLimits = td.querySelector(".ma-ci-limits");
      var barTick   = td.querySelector(".ma-ci-bar-tick");
      var barRange  = td.querySelector(".ma-ci-bar-range");
      if (barWrap && !isNaN(pct) && !isNaN(ciLo) && !isNaN(ciHi)) {
        var loDisp   = Math.round(ciLo * 100) + "%";
        var hiDisp   = Math.round(ciHi * 100) + "%";
        var fillLeft = Math.max(0, Math.min(94, ciLo * 100));
        var fillW    = Math.max(4, Math.min(100 - fillLeft, (ciHi - ciLo) * 100));
        var meanPct  = Math.max(1, Math.min(99, pct * 100));
        barWrap.title = "95% CI: " + loDisp + " \u2013 " + hiDisp;
        if (barRange) { barRange.style.left = fillLeft.toFixed(1) + "%"; barRange.style.width = fillW.toFixed(1) + "%"; }
        if (barTick)  barTick.style.left = meanPct.toFixed(1) + "%";
        if (barLimits) {
          var spans = barLimits.querySelectorAll("span");
          if (spans[0]) spans[0].textContent = loDisp;
          if (spans[1]) spans[1].textContent = hiDisp;
        }
      }
    });
    // Re-apply CI bands if currently active
    var relShowCI = panel.querySelector('[data-fn-rel-showci]');
    if (relShowCI && relShowCI.checked) {
      table.querySelectorAll("td.ct-heatmap-cell[data-fn-att]").forEach(function(td) {
        td.classList.remove("fn-ci-above", "fn-ci-within", "fn-ci-below");
      });
      applyRelTableCI(panel, pctAttr);
    }
  }

  function applyRelTableCI(panel, pctAttr) {
    var table = panel.querySelector("[data-fn-rel-table]");
    if (!table) return;
    pctAttr = pctAttr || "data-fn-rel-pct-aware";

    // Get category average pct per column from the avg row
    var avgPcts = {};
    var avgRow = table.querySelector("tr.fn-row-avg-all");
    if (avgRow) {
      avgRow.querySelectorAll("td[data-fn-att]").forEach(function(td) {
        var att = td.getAttribute("data-fn-att");
        var v   = parseFloat(td.getAttribute(pctAttr));
        if (att && !isNaN(v)) avgPcts[att] = v;
      });
    }
    if (Object.keys(avgPcts).length === 0) return;

    // Use average aware_base across brands as n for binomial CI
    var brands = panel.__fnData && panel.__fnData.consideration_detail &&
                 panel.__fnData.consideration_detail.brands || [];
    var n = brands.length
      ? brands.reduce(function(s, b) { return s + (b.aware_base || 0); }, 0) / brands.length
      : 100;

    // Compute 95% CI bounds per column: avg_p ± 1.96 * sqrt(p*(1-p)/n)
    var ciBounds = {};
    Object.keys(avgPcts).forEach(function(att) {
      var p  = avgPcts[att];
      var se = Math.sqrt(p * (1 - p) / Math.max(n, 1));
      ciBounds[att] = { lower: p - 1.96 * se, upper: p + 1.96 * se };
    });

    // Apply colour classes to brand cells (not avg row)
    table.querySelectorAll("td.ct-heatmap-cell[data-fn-att]").forEach(function(td) {
      if (td.classList.contains("fn-rel-td-avg")) return;
      var att  = td.getAttribute("data-fn-att");
      var bnds = att && ciBounds[att];
      if (!bnds) return;
      var v = parseFloat(td.getAttribute(pctAttr));
      if (isNaN(v)) return;
      var cls = v > bnds.upper ? "fn-ci-above" : v < bnds.lower ? "fn-ci-below" : "fn-ci-within";
      td.classList.add(cls);
    });
  }

  function applyRelTableSigMarkers(panel) {
    var table = panel.querySelector("[data-fn-rel-table]");
    if (!table) return;
    var pctAttr = "data-fn-rel-pct-aware";
    var cntAttr = "data-fn-rel-count-aware";
    // Get cat avg pct per att from the avg row (uses fn-rel-td-avg, not ct-heatmap-cell)
    var avgPcts = {};
    var avgRow = table.querySelector("tr.fn-row-avg-all");
    if (avgRow) {
      avgRow.querySelectorAll("td[data-fn-att]").forEach(function(td) {
        var att = td.getAttribute("data-fn-att");
        var v   = parseFloat(td.getAttribute(pctAttr));
        if (att && !isNaN(v)) avgPcts[att] = v;
      });
    }
    if (Object.keys(avgPcts).length === 0) return;
    table.querySelectorAll("tr:not(.fn-row-avg-all):not(.fn-row-base)").forEach(function(row) {
      row.querySelectorAll("td.ct-heatmap-cell[data-fn-att]").forEach(function(td) {
        var valEl = td.querySelector(".ct-val");
        if (!valEl) return;
        // Remove old arrows
        valEl.querySelectorAll(".fn-sig-avg").forEach(function(a) { a.remove(); });
        var att   = td.getAttribute("data-fn-att");
        var v     = parseFloat(td.getAttribute(pctAttr));
        var cnt   = parseInt(td.getAttribute(cntAttr), 10);
        var avg   = avgPcts[att];
        if (isNaN(v) || isNaN(cnt) || avg == null || cnt <= 0) return;
        var n   = cnt / v;  // reverse-compute aware_n from count = pct * n
        if (n <= 0 || !isFinite(n)) return;
        var se  = Math.sqrt(avg * (1 - avg) / n);
        var sig = se > 0 && Math.abs(v - avg) > 1.96 * se;
        if (!sig) return;
        var dir  = v > avg ? "fn-sig-avg-up" : "fn-sig-avg-dn";
        var arrow = v > avg ? "\u2191" : "\u2193";
        var span = document.createElement("span");
        span.className = "fn-sig-avg " + dir;
        span.textContent = arrow;
        valEl.appendChild(span);
      });
    });
  }

  function applyRelTableHeatmap(panel, pctAttr) {
    var table = panel.querySelector("[data-fn-rel-table]");
    if (!table) return;
    pctAttr = pctAttr || "data-fn-rel-pct-aware";
    var colMax = {};
    table.querySelectorAll("td.ct-heatmap-cell[data-fn-att]").forEach(function(td) {
      var att = td.getAttribute("data-fn-att");
      var v   = parseFloat(td.getAttribute(pctAttr));
      if (att && !isNaN(v) && (colMax[att] == null || v > colMax[att])) colMax[att] = v;
    });
    table.querySelectorAll("td.ct-heatmap-cell[data-fn-att]").forEach(function(td) {
      if (td.classList.contains("fn-rel-td-focal")) return;
      var att  = td.getAttribute("data-fn-att");
      var v    = parseFloat(td.getAttribute(pctAttr));
      var maxV = colMax[att] || 1;
      if (isNaN(v)) return;
      var frac = Math.min(1, Math.max(0, v / maxV));
      td.style.backgroundColor = "rgba(37,99,171," + (0.08 + frac * 0.57).toFixed(3) + ")";
    });
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------
  function escapeAttr(s) {
    return String(s).replace(/&/g,"&amp;").replace(/"/g,"&quot;").replace(/</g,"&lt;");
  }

  function escSvg(s) {
    return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  }

  // ---------------------------------------------------------------------------
  // Bar chart — one horizontal bar per brand for the selected funnel stage.
  // Bars use brand colours; focal brand is thicker. Category avg shown as a
  // dashed reference line. Brands sorted focal-first then descending by value.
  // ---------------------------------------------------------------------------
  function buildBarChart(panel) {
    var wrap  = panel.querySelector(".fn-bar-wrap");
    if (!wrap) return;
    var svgEl = wrap.querySelector(".fn-bar-svg");
    if (!svgEl) return;

    var pd    = panel.__fnData;
    var state = panel.__fnState;
    if (!pd || !pd.table) { svgEl.innerHTML = ""; return; }

    var stageKeys   = pd.table.stage_keys   || [];
    var stageLabels = pd.table.stage_labels || {};
    var brandCodes  = pd.table.brand_codes  || [];
    var brandNames  = pd.table.brand_names  || brandCodes;
    var cells       = pd.table.cells        || [];
    var focal       = state.focal;
    var barStage    = state.barStage || stageKeys[0];

    if (!barStage) {
      svgEl.innerHTML = '<text x="20" y="30" font-size="12" fill="#94a3b8">No stage data</text>';
      return;
    }

    var stageLabel = stageLabels[barStage] || barStage;

    // Value map: brandCode -> pct_absolute for selected stage
    var valMap = {};
    for (var ci = 0; ci < cells.length; ci++) {
      var c = cells[ci];
      if (c.stage_key === barStage && c.pct_absolute != null) {
        valMap[c.brand_code] = c.pct_absolute;
      }
    }

    // Visible brands (cat avg chip excluded)
    var visBrands = brandCodes.filter(function(b) {
      return b !== "__avg__" && state.chartBrands[b] !== false;
    });

    var brandData = visBrands.map(function(b) {
      var bIdx = brandCodes.indexOf(b);
      return {
        code: b,
        name: bIdx >= 0 ? brandNames[bIdx] : b,
        val:  valMap[b] != null ? valMap[b] : null
      };
    });

    // Sort: focal first, then descending by value
    brandData.sort(function(a, b) {
      if (a.code === focal) return -1;
      if (b.code === focal) return 1;
      return (b.val != null ? b.val : -1) - (a.val != null ? a.val : -1);
    });

    // Category average reference value
    var catAvgVal = null;
    if (pd.table.avg_all_brands) {
      for (var ai = 0; ai < pd.table.avg_all_brands.length; ai++) {
        if (pd.table.avg_all_brands[ai].stage_key === barStage) {
          catAvgVal = pd.table.avg_all_brands[ai].pct_absolute; break;
        }
      }
    }
    if (catAvgVal == null) {
      var vals = brandCodes.map(function(b) { return valMap[b]; }).filter(function(v) { return v != null; });
      if (vals.length) catAvgVal = vals.reduce(function(a, b) { return a + b; }, 0) / vals.length;
    }

    // Layout
    var W = 700, labelW = 160, rPad = 56, barAreaW = W - labelW - rPad;
    var rowH = 32, focalBarH = 24, stdBarH = 18, mt = 28, mb = 16;
    var H = mt + brandData.length * rowH + mb;

    var parts = [];

    // Stage title
    parts.push('<text x="' + (labelW + barAreaW / 2) + '" y="16" text-anchor="middle" font-size="11" font-weight="600" fill="#64748b">' + escSvg(stageLabel) + ' \u2014 % of total respondents</text>');

    // Category average dashed reference line
    if (catAvgVal != null) {
      var avgX = (labelW + catAvgVal * barAreaW).toFixed(1);
      parts.push('<line x1="' + avgX + '" y1="' + mt + '" x2="' + avgX + '" y2="' + (H - mb) + '" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="4,3"/>');
      parts.push('<text x="' + avgX + '" y="' + (mt - 4) + '" text-anchor="middle" font-size="9" fill="#94a3b8">cat avg ' + Math.round(catAvgVal * 100) + '%</text>');
    }

    // Bars
    for (var ri = 0; ri < brandData.length; ri++) {
      var bd      = brandData[ri];
      var y       = mt + ri * rowH;
      var isFocal = bd.code === focal;
      var bh      = isFocal ? focalBarH : stdBarH;
      var barY    = y + (rowH - bh) / 2;
      var color   = resolveBrandColor(pd, state, bd.code);

      // Row separator
      if (ri > 0) {
        parts.push('<line x1="' + (labelW - 2) + '" y1="' + y + '" x2="' + (labelW + barAreaW + 4) + '" y2="' + y + '" stroke="#f1f5f9" stroke-width="1"/>');
      }

      // Brand name label
      var dispName = bd.name.length > 22 ? bd.name.slice(0, 21) + "\u2026" : bd.name;
      var fontW    = isFocal ? "700" : "400";
      parts.push('<text x="' + (labelW - 6) + '" y="' + (y + rowH / 2 + 4).toFixed(1) + '" text-anchor="end" font-size="12" font-weight="' + fontW + '" fill="' + color + '">' + escSvg(dispName) + '</text>');

      if (bd.val == null) {
        parts.push('<rect x="' + labelW + '" y="' + barY.toFixed(1) + '" width="' + barAreaW + '" height="' + bh + '" fill="#f8fafc" rx="2"/>');
        continue;
      }

      var barW = Math.max(2, bd.val * barAreaW);
      // Track
      parts.push('<rect x="' + labelW + '" y="' + barY.toFixed(1) + '" width="' + barAreaW + '" height="' + bh + '" fill="#f1f5f9" rx="2"/>');
      // Bar
      parts.push('<rect x="' + labelW + '" y="' + barY.toFixed(1) + '" width="' + barW.toFixed(1) + '" height="' + bh + '" fill="' + color + '" rx="2"/>');
      // Value label to the right
      var pctStr = Math.round(bd.val * 100) + "%";
      parts.push('<text x="' + (labelW + barW + 5).toFixed(1) + '" y="' + (barY + bh / 2 + 4).toFixed(1) + '" font-size="11" font-weight="' + fontW + '" fill="' + color + '">' + pctStr + '</text>');
    }

    svgEl.setAttribute("viewBox", "0 0 " + W + " " + H);
    svgEl.setAttribute("height", H);
    svgEl.innerHTML = parts.join("");
  }

})();
