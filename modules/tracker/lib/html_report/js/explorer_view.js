/* ============================================================================
 * TurasTracker - Heatmap Explorer
 * ============================================================================
 * Mode toggle (Questions for Segment / Segments for Question),
 * Mode B table rendering, row selection, and Visualise action.
 * VERSION: 1.0.0
 * ============================================================================ */

(function() {
  "use strict";

  // ---- State ----
  var currentExplorerMode = "mode-a";  // "mode-a" or "mode-b"
  var currentModeBMode = "absolute";   // "absolute", "vs-prev", "vs-base"
  var currentModeBMetric = null;
  var explorerData = null;             // parsed master JSON blob
  var explorerSelection = {};          // { id: true } for selected rows

  // ---- Load master data blob ----
  function loadExplorerData() {
    if (explorerData) return explorerData;
    var el = document.getElementById("hm-explorer-data");
    if (!el) return null;
    try {
      explorerData = JSON.parse(el.textContent);
    } catch (e) {
      console.error("Explorer: Failed to parse data blob", e);
    }
    return explorerData;
  }

  // ---- Mode Toggle ----
  window.explorerSwitchMode = function(mode) {
    currentExplorerMode = mode;
    var modeA = document.getElementById("explorer-mode-a");
    var modeB = document.getElementById("explorer-mode-b");
    if (modeA) modeA.style.display = mode === "mode-a" ? "" : "none";
    if (modeB) modeB.style.display = mode === "mode-b" ? "" : "none";

    // Update toggle buttons
    document.querySelectorAll(".explorer-mode-btn").forEach(function(btn) {
      btn.classList.toggle("active", btn.getAttribute("data-mode") === mode);
    });

    // Clear selection on mode switch
    explorerClearSelection();

    // Render Mode B if switching to it for the first time
    if (mode === "mode-b" && !currentModeBMetric) {
      var sel = document.getElementById("hm-b-metric-select");
      if (sel && sel.value) {
        currentModeBMetric = sel.value;
        renderModeBTable(sel.value);
      }
    }
  };

  // ---- Mode B: Metric Selection ----
  window.explorerSelectMetric = function(metricId) {
    currentModeBMetric = metricId;
    renderModeBTable(metricId);
    explorerClearSelection();
  };

  // ---- Mode B: Display Mode Switch ----
  window.explorerBSwitchMode = function(mode) {
    currentModeBMode = mode;
    // Update active chip
    var container = document.getElementById("explorer-mode-b");
    if (container) {
      container.querySelectorAll(".hm-mode-chip").forEach(function(chip) {
        chip.classList.toggle("active", chip.getAttribute("data-mode") === mode);
      });
    }
    // Re-render
    if (currentModeBMetric) renderModeBTable(currentModeBMetric);
  };

  // ---- Mode B: Sort ----
  window.explorerBSort = function(sortMode) {
    if (currentModeBMetric) renderModeBTable(currentModeBMetric, sortMode);
  };

  // ---- Mode B: Render Table ----
  function renderModeBTable(metricId, sortMode) {
    var data = loadExplorerData();
    if (!data) return;

    // Find metric
    var metric = null;
    for (var i = 0; i < data.metrics.length; i++) {
      if (data.metrics[i].id === metricId) { metric = data.metrics[i]; break; }
    }
    if (!metric) return;

    var waves = data.waves;
    var waveLabels = data.waveLabels;
    var segments = data.segments;
    var metricType = metric.type;
    var latestWave = waves[waves.length - 1];
    var prevWave = waves.length > 1 ? waves[waves.length - 2] : null;

    // Build segment row data
    var rows = [];
    for (var si = 0; si < segments.length; si++) {
      var seg = segments[si];
      var segData = metric.data[seg];
      if (!segData) continue;

      var latestVal = segData[latestWave] ? segData[latestWave].value : null;
      var latestChange = segData[latestWave] ? segData[latestWave].change_prev : null;

      rows.push({
        segment: seg,
        data: segData,
        latestVal: latestVal,
        latestChange: latestChange,
        originalOrder: si
      });
    }

    // Sort
    if (!sortMode) sortMode = document.getElementById("hm-b-sort-select") ? document.getElementById("hm-b-sort-select").value : "original";

    if (sortMode === "alpha") {
      rows.sort(function(a, b) { return a.segment.localeCompare(b.segment); });
    } else if (sortMode === "value-desc") {
      rows.sort(function(a, b) {
        var va = a.latestVal != null ? a.latestVal : -Infinity;
        var vb = b.latestVal != null ? b.latestVal : -Infinity;
        return vb - va;
      });
    } else if (sortMode === "change-desc") {
      rows.sort(function(a, b) {
        var ca = a.latestChange != null ? Math.abs(a.latestChange) : -1;
        var cb = b.latestChange != null ? Math.abs(b.latestChange) : -1;
        return cb - ca;
      });
    }
    // "original" — no sort needed

    // Build HTML
    var html = [];
    html.push('<div class="hm-grid-wrap">');
    html.push('<table class="hm-table" id="hm-b-table">');

    // Header
    html.push('<thead><tr>');
    html.push('<th class="hm-th hm-checkbox-col"></th>');
    html.push('<th class="hm-th hm-label-col">Segment</th>');
    for (var wi = 0; wi < waves.length; wi++) {
      html.push('<th class="hm-th hm-wave-col">' + escapeHtml(waveLabels[wi]) + '</th>');
    }
    html.push('<th class="hm-th hm-spark-col">Trend</th>');
    html.push('<th class="hm-th hm-delta-col">Change</th>');
    html.push('</tr></thead>');

    html.push('<tbody>');

    for (var ri = 0; ri < rows.length; ri++) {
      var row = rows[ri];
      var segId = row.segment;
      var isSelected = explorerSelection[segId] ? ' hm-row-selected' : '';

      html.push('<tr class="hm-metric-row hm-b-seg-row' + isSelected + '" data-seg-id="' + escapeHtml(segId) + '">');

      // Checkbox
      html.push('<td class="hm-td hm-checkbox-col"><input type="checkbox" class="hm-row-cb" ' +
        (explorerSelection[segId] ? 'checked ' : '') +
        'onchange="toggleExplorerRow(\'' + escapeHtml(segId) + '\', this)" ' +
        'onclick="event.stopPropagation()"></td>');

      // Label
      html.push('<td class="hm-td hm-label-col"><span class="hm-metric-label">' + escapeHtml(segId) + '</span></td>');

      // Value cells
      var sparkVals = [];
      for (var wi2 = 0; wi2 < waves.length; wi2++) {
        var wid = waves[wi2];
        var cell = row.data[wid];
        var val = cell ? cell.value : null;
        var display = "";
        var bgStyle = "";

        if (currentModeBMode === "absolute") {
          display = cell ? cell.display : "&mdash;";
          if (val != null) bgStyle = HmUtils.absoluteCellStyle(val, metricType);
        } else if (currentModeBMode === "vs-prev") {
          var cv = cell ? cell.change_prev : null;
          if (cv != null) {
            display = HmUtils.formatChange(cv, metric.name);
            bgStyle = HmUtils.changeCellStyle(cv, cell.sig_prev);
          } else {
            display = "&mdash;";
          }
        } else if (currentModeBMode === "vs-base") {
          var cb = cell ? cell.change_base : null;
          if (cb != null) {
            display = HmUtils.formatChange(cb, metric.name);
            bgStyle = HmUtils.changeCellStyle(cb, cell.sig_base);
          } else {
            display = "&mdash;";
          }
        }

        sparkVals.push(val);
        html.push('<td class="hm-td hm-value-cell" data-wave="' + wid + '" data-value="' +
          (val != null ? val : '') + '" style="' + bgStyle + '">' + display + '</td>');
      }

      // Sparkline
      var brandColour = (typeof BRAND_COLOUR_HEX !== "undefined") ? BRAND_COLOUR_HEX : "#323367";
      var sparkSvg = HmUtils.buildSparklineSvg(sparkVals, 80, 24, brandColour);
      html.push('<td class="hm-td hm-spark-cell">' + sparkSvg + '</td>');

      // Delta chip
      var deltaHtml = "";
      if (row.latestChange != null) {
        var deltaClass = row.latestChange > 0 ? "hm-delta-up" : (row.latestChange < 0 ? "hm-delta-down" : "hm-delta-flat");
        var deltaDisplay = HmUtils.formatChange(row.latestChange, metric.name);
        var latestCell = row.data[latestWave];
        var sigMarker = (latestCell && latestCell.sig_prev) ? " *" : "";
        deltaHtml = '<span class="hm-delta ' + deltaClass + '">' + deltaDisplay + sigMarker + '</span>';
      }
      html.push('<td class="hm-td hm-delta-cell">' + deltaHtml + '</td>');

      html.push('</tr>');
    }

    html.push('</tbody></table></div>');

    var container = document.getElementById("hm-b-table-container");
    if (container) container.innerHTML = html.join("\n");
  }

  // ---- Row Selection ----
  window.toggleExplorerRow = function(id, checkbox) {
    if (explorerSelection[id]) {
      delete explorerSelection[id];
    } else {
      explorerSelection[id] = true;
    }

    // Update row highlight
    var selector = currentExplorerMode === "mode-a"
      ? '.hm-metric-row[data-metric-id="' + id + '"]'
      : '.hm-b-seg-row[data-seg-id="' + id + '"]';
    var row = document.querySelector(selector);
    if (row) row.classList.toggle("hm-row-selected", !!explorerSelection[id]);
    if (checkbox) checkbox.checked = !!explorerSelection[id];

    updateSelectionBar();
  };

  window.explorerClearSelection = function() {
    explorerSelection = {};
    // Remove all highlights
    document.querySelectorAll(".hm-row-selected").forEach(function(r) {
      r.classList.remove("hm-row-selected");
    });
    document.querySelectorAll(".hm-row-cb").forEach(function(cb) {
      cb.checked = false;
    });
    updateSelectionBar();
  };

  function updateSelectionBar() {
    var count = Object.keys(explorerSelection).length;
    var bar = document.getElementById("explorer-selection-bar");
    var countEl = document.getElementById("explorer-selection-count");
    if (bar) bar.style.display = count > 0 ? "" : "none";
    if (countEl) countEl.textContent = count + " selected";
  }

  // ---- Visualise Action ----
  var VIS_COLOURS = [
    "#323367", "#CC9900", "#4a7c6f", "#b85450", "#6b7fb5",
    "#8e6c88", "#d4915e", "#5b9e8f", "#c47a9b", "#7a8b6e"
  ];

  // Unified state — single view, not per-panel
  var visState = {
    mode: null,            // "metrics" (Mode A) or "segments" (Mode B)
    metricIds: [],         // selected metric IDs
    allSegments: [],       // all available segment names
    contextSegment: null,  // Mode A: which segment to show
    contextMetric: null,   // Mode B: which metric
    visible: {},           // sidebar item visibility {id: true}
    chartVisible: true,
    vprev: false,
    vbase: false
  };

  window.explorerVisualise = function() {
    var ids = Object.keys(explorerSelection);
    if (ids.length === 0) return;

    var data = loadExplorerData();
    if (!data) return;

    // Show the Visualise tab button
    var tabBtn = document.getElementById("tab-btn-visualise");
    if (tabBtn) tabBtn.style.display = "";

    var placeholder = document.getElementById("visualise-placeholder");
    var content = document.getElementById("visualise-content");
    if (placeholder) placeholder.style.display = "none";
    if (content) content.style.display = "";

    // Determine context
    if (currentExplorerMode === "mode-a") {
      visState.mode = "metrics";
      visState.metricIds = ids;
      var segSel = document.getElementById("hm-banner-select");
      visState.contextSegment = segSel ? segSel.value : data.segments[0];
      visState.allSegments = data.segments;
      visState.visible = {};
      for (var i = 0; i < ids.length; i++) visState.visible[ids[i]] = true;
    } else {
      visState.mode = "segments";
      visState.metricIds = [currentModeBMetric];
      visState.contextMetric = currentModeBMetric;
      visState.allSegments = ids;
      visState.visible = {};
      for (var j = 0; j < ids.length; j++) visState.visible[ids[j]] = true;
    }
    visState.chartVisible = true;
    visState.vprev = false;
    visState.vbase = false;

    renderVisualiseView(data);
    if (typeof switchReportTab === "function") switchReportTab("visualise");
  };

  function findMetric(data, metricId) {
    for (var i = 0; i < data.metrics.length; i++) {
      if (data.metrics[i].id === metricId) return data.metrics[i];
    }
    return null;
  }

  // ---- Render the entire Visualise tab ----
  function renderVisualiseView(data) {
    var content = document.getElementById("visualise-content");
    if (!content) return;

    var h = [];
    h.push('<div class="vis-layout">');

    // ---- Left sidebar ----
    h.push('<div class="vis-sidebar">');
    if (visState.mode === "metrics") {
      h.push('<div class="vis-sidebar-header">');
      h.push('<span class="vis-sidebar-title">Selected Metrics</span>');
      h.push('</div>');
      h.push('<div class="vis-sidebar-items">');
      for (var mi = 0; mi < visState.metricIds.length; mi++) {
        var met = findMetric(data, visState.metricIds[mi]);
        if (!met) continue;
        var col = VIS_COLOURS[mi % VIS_COLOURS.length];
        var active = visState.visible[met.id] !== false;
        h.push('<button class="vis-sidebar-item' + (active ? ' active' : '') + '" data-id="' +
          escapeHtml(met.id) + '" onclick="visToggleSidebarItem(\'' + escapeHtml(met.id) + '\',this)">');
        h.push('<span class="vis-sidebar-dot" style="background:' + col + '"></span>');
        h.push('<span class="vis-sidebar-label">' + escapeHtml(met.label) + '</span>');
        h.push('</button>');
      }
      h.push('</div>');
    } else {
      h.push('<div class="vis-sidebar-header">');
      var ctxMet = findMetric(data, visState.contextMetric);
      h.push('<span class="vis-sidebar-title">Selected Segments</span>');
      h.push('</div>');
      h.push('<div class="vis-sidebar-items">');
      for (var si = 0; si < visState.allSegments.length; si++) {
        var seg = visState.allSegments[si];
        var segIdx = data.segments.indexOf(seg);
        var col2 = VIS_COLOURS[segIdx % VIS_COLOURS.length];
        var active2 = visState.visible[seg] !== false;
        h.push('<button class="vis-sidebar-item' + (active2 ? ' active' : '') + '" data-id="' +
          escapeHtml(seg) + '" onclick="visToggleSidebarItem(\'' + escapeHtml(seg) + '\',this)">');
        h.push('<span class="vis-sidebar-dot" style="background:' + col2 + '"></span>');
        h.push('<span class="vis-sidebar-label">' + escapeHtml(seg) + '</span>');
        h.push('</button>');
      }
      h.push('</div>');
    }
    h.push('</div>'); // vis-sidebar

    // ---- Main content ----
    h.push('<div class="vis-main" id="vis-main-panel">');

    // Context bar
    h.push('<div class="vis-context-bar">');
    if (visState.mode === "metrics") {
      h.push('<span class="vis-context-label">Segment:</span>');
      h.push('<select class="vis-context-select" id="vis-seg-select" onchange="visChangeContext(this.value)">');
      for (var cs = 0; cs < data.segments.length; cs++) {
        var selAttr = data.segments[cs] === visState.contextSegment ? ' selected' : '';
        h.push('<option value="' + escapeHtml(data.segments[cs]) + '"' + selAttr + '>' + escapeHtml(data.segments[cs]) + '</option>');
      }
      h.push('</select>');
    } else {
      var mObj = findMetric(data, visState.contextMetric);
      if (mObj) {
        h.push('<h2 class="vis-context-title">' + escapeHtml(mObj.label) + '</h2>');
        h.push('<span class="vis-context-subtitle">' + escapeHtml(mObj.section) + ' &middot; ' +
          escapeHtml(mObj.type === "mean" ? "Mean Score" : mObj.type === "pct" ? "Top 2 Box (%)" : mObj.type === "nps" ? "NPS" : mObj.type) + '</span>');
      }
    }
    h.push('</div>');

    // Controls bar
    h.push('<div class="mv-controls">');
    h.push('<div class="mv-control-group">');
    h.push('<label class="tk-toggle"><input type="checkbox" onchange="visToggleChange(\'vs-prev\',this.checked)"><span class="tk-toggle-label">vs Previous</span></label>');
    h.push('<label class="tk-toggle"><input type="checkbox" onchange="visToggleChange(\'vs-base\',this.checked)"><span class="tk-toggle-label">vs Baseline</span></label>');
    h.push('</div>');
    h.push('<div class="mv-control-group">');
    h.push('<label class="tk-toggle"><input type="checkbox" checked onchange="visToggleChart(this.checked)"><span class="tk-toggle-label">Show chart</span></label>');
    h.push('</div>');
    h.push('<div class="mv-control-group mv-action-buttons" style="border-right:none;margin-left:auto">');
    h.push('<button class="export-btn" onclick="visExportExcel()">&#x2B73; Export Excel</button>');
    h.push('<div class="tk-pin-dropdown" style="display:inline-block;position:relative">');
    h.push('<button class="export-btn" onclick="visTogglePinMenu()">&#x1F4CC; Pin &#x25BE;</button>');
    h.push('<div class="tk-pin-menu" id="vis-pin-menu" style="display:none">');
    h.push('<button class="tk-pin-option" onclick="visPinView(\'all\')">Insight + Chart + Table</button>');
    h.push('<button class="tk-pin-option" onclick="visPinView(\'chart\')">Insight + Chart</button>');
    h.push('<button class="tk-pin-option" onclick="visPinView(\'table\')">Insight + Table</button>');
    h.push('</div></div>');
    h.push('<button class="export-btn" onclick="visExportSlide()">&#x1F4F8; Export Slide</button>');
    h.push('</div></div>');

    // Chart area
    h.push('<div class="vis-chart-area" id="vis-chart"></div>');

    // Table area
    h.push('<div class="vis-table-area" id="vis-table">');
    h.push(buildVisTable(data));
    h.push('</div>');

    // Insight area
    h.push('<div class="insight-area">');
    h.push('<button class="insight-toggle" onclick="visToggleInsight()">+ Add Insight</button>');
    h.push('<div class="insight-container" id="vis-insight" style="display:none">');
    h.push('<div class="insight-editor" contenteditable="true" data-placeholder="Type key insight here..." id="vis-insight-editor"></div>');
    h.push('<button class="insight-dismiss" title="Delete insight" onclick="visDismissInsight()">×</button>');
    h.push('</div></div>');

    h.push('</div>'); // vis-main
    h.push('</div>'); // vis-layout

    content.innerHTML = h.join("\n");

    // Render chart after DOM insertion
    if (visState.chartVisible) renderVisCombinedChart(data);
  }

  // ---- Unified detail table ----
  function buildVisTable(data) {
    var waves = data.waves;
    var waveLabels = data.waveLabels;
    var t = [];

    t.push('<table class="tk-table vis-detail-table" id="vis-tbl">');
    t.push('<thead><tr class="tk-wave-header-row">');
    t.push('<th class="tk-th tk-label-col">' + (visState.mode === "metrics" ? "Metric" : "Segment") + '</th>');
    for (var wi = 0; wi < waves.length; wi++) {
      t.push('<th class="tk-th tk-wave-header" data-wave="' + waves[wi] + '">' + escapeHtml(waveLabels[wi]) + '</th>');
    }
    t.push('</tr></thead><tbody>');

    if (visState.mode === "metrics") {
      // Rows = metrics, for the context segment
      var seg = visState.contextSegment;
      for (var mi = 0; mi < visState.metricIds.length; mi++) {
        var met = findMetric(data, visState.metricIds[mi]);
        if (!met || !met.data[seg]) continue;
        var sd = met.data[seg];
        var vis = visState.visible[met.id] !== false;
        var hidCls = vis ? "" : " vis-item-hidden";
        var col = VIS_COLOURS[mi % VIS_COLOURS.length];

        // Value row
        t.push('<tr class="tk-metric-row' + hidCls + '" data-vis-id="' + escapeHtml(met.id) + '">');
        t.push('<td class="tk-td tk-label-col"><span class="tk-seg-dot" style="background:' + col + '"></span><span class="tk-metric-label">' + escapeHtml(met.label) + '</span></td>');
        for (var vw = 0; vw < waves.length; vw++) {
          var vc = sd[waves[vw]];
          var val = vc ? vc.display : "&mdash;";
          var sigBadge = "";
          if (vc && vc.sig_prev) sigBadge = vc.change_prev > 0 ? ' <span class="tk-sig tk-sig-up">&#x25B2;</span>' : ' <span class="tk-sig tk-sig-down">&#x25BC;</span>';
          t.push('<td class="tk-td tk-value-cell" data-wave="' + waves[vw] + '">' + '<span class="tk-val">' + val + '</span>' + sigBadge + '</td>');
        }
        t.push('</tr>');

        // vs Previous
        t.push('<tr class="tk-change-row tk-vs-prev' + hidCls + '" data-vis-id="' + escapeHtml(met.id) + '">');
        t.push('<td class="tk-td tk-label-col tk-change-label">vs Prev</td>');
        for (var pw = 0; pw < waves.length; pw++) {
          var pc = sd[waves[pw]];
          var pv = (pc && pc.change_prev != null) ? HmUtils.formatChange(pc.change_prev, met.label) : "";
          var ps = (pc && pc.sig_prev) ? " *" : "";
          t.push('<td class="tk-td tk-change-cell" data-wave="' + waves[pw] + '">' + pv + ps + '</td>');
        }
        t.push('</tr>');

        // vs Baseline
        t.push('<tr class="tk-change-row tk-vs-base' + hidCls + '" data-vis-id="' + escapeHtml(met.id) + '">');
        t.push('<td class="tk-td tk-label-col tk-change-label">vs Base</td>');
        for (var bw = 0; bw < waves.length; bw++) {
          var bc = sd[waves[bw]];
          var bv = (bc && bc.change_base != null) ? HmUtils.formatChange(bc.change_base, met.label) : "";
          var bs = (bc && bc.sig_base) ? " *" : "";
          t.push('<td class="tk-td tk-change-cell" data-wave="' + waves[bw] + '">' + bv + bs + '</td>');
        }
        t.push('</tr>');
      }
    } else {
      // Rows = segments, for the context metric
      var metric = findMetric(data, visState.contextMetric);
      if (metric) {
        // Base row
        var totalData = metric.data[data.segments[0]];
        if (totalData) {
          t.push('<tr class="tk-base-row"><td class="tk-td tk-label-col tk-base-label">Base (n=)</td>');
          for (var bwi = 0; bwi < waves.length; bwi++) {
            var bci = totalData[waves[bwi]];
            t.push('<td class="tk-td tk-base-cell" data-wave="' + waves[bwi] + '">' + (bci ? bci.n : "") + '</td>');
          }
          t.push('</tr>');
        }

        for (var si2 = 0; si2 < visState.allSegments.length; si2++) {
          var seg2 = visState.allSegments[si2];
          var sd2 = metric.data[seg2];
          if (!sd2) continue;
          var segIdx2 = data.segments.indexOf(seg2);
          var vis2 = visState.visible[seg2] !== false;
          var hidCls2 = vis2 ? "" : " vis-item-hidden";
          var col2 = VIS_COLOURS[segIdx2 % VIS_COLOURS.length];

          t.push('<tr class="tk-metric-row' + hidCls2 + '" data-vis-id="' + escapeHtml(seg2) + '">');
          t.push('<td class="tk-td tk-label-col"><span class="tk-seg-dot" style="background:' + col2 + '"></span><span class="tk-metric-label">' + escapeHtml(seg2) + '</span></td>');
          for (var vw2 = 0; vw2 < waves.length; vw2++) {
            var vc2 = sd2[waves[vw2]];
            var val2 = vc2 ? vc2.display : "&mdash;";
            var sig2 = "";
            if (vc2 && vc2.sig_prev) sig2 = vc2.change_prev > 0 ? ' <span class="tk-sig tk-sig-up">&#x25B2;</span>' : ' <span class="tk-sig tk-sig-down">&#x25BC;</span>';
            t.push('<td class="tk-td tk-value-cell" data-wave="' + waves[vw2] + '">' + '<span class="tk-val">' + val2 + '</span>' + sig2 + '</td>');
          }
          t.push('</tr>');

          t.push('<tr class="tk-change-row tk-vs-prev' + hidCls2 + '" data-vis-id="' + escapeHtml(seg2) + '">');
          t.push('<td class="tk-td tk-label-col tk-change-label">vs Prev</td>');
          for (var pw2 = 0; pw2 < waves.length; pw2++) {
            var pc2 = sd2[waves[pw2]];
            var pv2 = (pc2 && pc2.change_prev != null) ? HmUtils.formatChange(pc2.change_prev, metric.label) : "";
            var ps2 = (pc2 && pc2.sig_prev) ? " *" : "";
            t.push('<td class="tk-td tk-change-cell" data-wave="' + waves[pw2] + '">' + pv2 + ps2 + '</td>');
          }
          t.push('</tr>');

          t.push('<tr class="tk-change-row tk-vs-base' + hidCls2 + '" data-vis-id="' + escapeHtml(seg2) + '">');
          t.push('<td class="tk-td tk-label-col tk-change-label">vs Base</td>');
          for (var bw2 = 0; bw2 < waves.length; bw2++) {
            var bc2 = sd2[waves[bw2]];
            var bv2 = (bc2 && bc2.change_base != null) ? HmUtils.formatChange(bc2.change_base, metric.label) : "";
            var bs2 = (bc2 && bc2.sig_base) ? " *" : "";
            t.push('<td class="tk-td tk-change-cell" data-wave="' + waves[bw2] + '">' + bv2 + bs2 + '</td>');
          }
          t.push('</tr>');
        }
      }
    }

    t.push('</tbody></table>');
    return t.join("\n");
  }

  // ---- Combined SVG Line Chart with Annotations ----
  function renderVisCombinedChart(data) {
    var container = document.getElementById("vis-chart");
    if (!container) return;

    var waves = data.waves;
    var waveLabels = data.waveLabels;

    // Build series: each visible item becomes a line
    var series = [];
    if (visState.mode === "metrics") {
      var seg = visState.contextSegment;
      for (var mi = 0; mi < visState.metricIds.length; mi++) {
        var met = findMetric(data, visState.metricIds[mi]);
        if (!met || !met.data[seg] || visState.visible[met.id] === false) continue;
        series.push({
          id: met.id,
          label: met.label,
          colour: VIS_COLOURS[mi % VIS_COLOURS.length],
          values: waves.map(function(w) { var c = met.data[seg][w]; return c ? c.value : null; }),
          type: met.type
        });
      }
    } else {
      var metric = findMetric(data, visState.contextMetric);
      if (metric) {
        for (var si = 0; si < visState.allSegments.length; si++) {
          var segName = visState.allSegments[si];
          if (visState.visible[segName] === false || !metric.data[segName]) continue;
          var segIdx = data.segments.indexOf(segName);
          series.push({
            id: segName,
            label: segName,
            colour: VIS_COLOURS[segIdx % VIS_COLOURS.length],
            values: waves.map(function(w) { var c = metric.data[segName][w]; return c ? c.value : null; }),
            type: metric.type
          });
        }
      }
    }

    if (series.length === 0) {
      container.innerHTML = '<p class="dash-section-sub" style="padding:24px;text-align:center;">Toggle items in the sidebar to see chart.</p>';
      return;
    }

    // Determine chart type label
    var typeLabel = series[0].type === "pct" ? "%" : series[0].type === "nps" ? "NPS" : "";

    // Responsive: use wide viewBox, CSS will scale
    var W = 960, H = 340;
    var pad = { top: 30, right: 90, bottom: 50, left: 55 };
    var plotW = W - pad.left - pad.right;
    var plotH = H - pad.top - pad.bottom;

    // Y range across all visible series
    var allVals = [];
    for (var s = 0; s < series.length; s++) {
      for (var v = 0; v < series[s].values.length; v++) {
        if (series[s].values[v] != null) allVals.push(series[s].values[v]);
      }
    }
    if (allVals.length === 0) { container.innerHTML = ''; return; }
    var yMin = Math.min.apply(null, allVals), yMax = Math.max.apply(null, allVals);
    var yR = yMax - yMin || 1;
    yMin -= yR * 0.12; yMax += yR * 0.12;

    function xP(i) { return pad.left + (i / Math.max(waves.length - 1, 1)) * plotW; }
    function yP(val) { return pad.top + plotH - ((val - yMin) / (yMax - yMin)) * plotH; }

    var svg = [];
    svg.push('<svg class="vis-line-chart" viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg" style="font-family:Arial,sans-serif">');

    // Horizontal grid lines
    var nTicks = 5;
    for (var t = 0; t <= nTicks; t++) {
      var yv = yMin + (t / nTicks) * (yMax - yMin);
      var yy = yP(yv);
      svg.push('<line x1="' + pad.left + '" y1="' + yy + '" x2="' + (W - pad.right) + '" y2="' + yy + '" stroke="#e2e8f0" stroke-width="1"/>');
      var tl = typeLabel === "%" ? Math.round(yv) + "%" : yv.toFixed(1);
      svg.push('<text x="' + (pad.left - 10) + '" y="' + (yy + 4) + '" text-anchor="end" fill="#94a3b8" font-size="11" font-weight="400">' + tl + '</text>');
    }

    // X axis labels
    for (var xi = 0; xi < waves.length; xi++) {
      svg.push('<text x="' + xP(xi) + '" y="' + (H - pad.bottom + 20) + '" text-anchor="middle" fill="#94a3b8" font-size="11" font-weight="400">' + escapeHtml(waveLabels[xi]) + '</text>');
    }

    // Load annotations
    var annots = [];
    if (typeof tkAnnotations !== "undefined") {
      if (visState.mode === "metrics") {
        for (var ai = 0; ai < visState.metricIds.length; ai++) {
          var mAnns = tkAnnotations.getForMetric(visState.metricIds[ai]);
          for (var aj = 0; aj < mAnns.length; aj++) annots.push(mAnns[aj]);
        }
      } else {
        annots = tkAnnotations.getForMetric(visState.contextMetric);
      }
    }

    // Render annotation markers (vertical dashed lines + callout labels)
    for (var an = 0; an < annots.length; an++) {
      var ann = annots[an];
      var waveIdx = waves.indexOf(ann.waveId);
      if (waveIdx < 0) continue;
      var axPos = xP(waveIdx);
      var annCol = ann.colour || "#94a3b8";

      // Dashed vertical line
      svg.push('<line x1="' + axPos + '" y1="' + pad.top + '" x2="' + axPos + '" y2="' + (H - pad.bottom) +
        '" stroke="' + annCol + '" stroke-width="1" stroke-dasharray="4,3" opacity="0.6"/>');

      // Callout: small circle + connecting line + text
      var calloutY = pad.top + 14 + (an % 3) * 16; // stagger to avoid overlap
      var textX = axPos + 8;
      var annText = ann.text.length > 30 ? ann.text.substring(0, 30) + "\u2026" : ann.text;

      // Small marker dot on the axis line
      svg.push('<circle cx="' + axPos + '" cy="' + calloutY + '" r="3" fill="' + annCol + '" opacity="0.7"/>');

      // Callout connector + text
      svg.push('<line x1="' + axPos + '" y1="' + calloutY + '" x2="' + (textX + 2) + '" y2="' + calloutY + '" stroke="' + annCol + '" stroke-width="1" opacity="0.5"/>');
      svg.push('<text x="' + (textX + 4) + '" y="' + (calloutY + 4) + '" fill="' + annCol + '" font-size="10" font-weight="500" font-style="italic">' + escapeHtml(annText) + '</text>');
    }

    // Lines + dots + end labels
    // Collect end-label positions for collision avoidance
    var endLabels = [];
    for (var s2 = 0; s2 < series.length; s2++) {
      var ser = series[s2];
      var pts = [];
      for (var w = 0; w < waves.length; w++) {
        if (ser.values[w] != null) pts.push({ x: xP(w), y: yP(ser.values[w]), v: ser.values[w], wi: w });
      }

      // Draw line
      if (pts.length > 1) {
        svg.push('<path d="M' + pts.map(function(p) { return p.x + ',' + p.y; }).join('L') +
          '" fill="none" stroke="' + ser.colour + '" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>');
      }

      // Draw dots — each is a tk-chart-point for annotation support
      for (var pi = 0; pi < pts.length; pi++) {
        var waveId = waves[pts[pi].wi];
        svg.push('<circle class="tk-chart-point" cx="' + pts[pi].x + '" cy="' + pts[pi].y + '" r="4.5" fill="' + ser.colour +
          '" stroke="#fff" stroke-width="2" data-wave="' + waveId + '" data-segment="' + escapeHtml(ser.id) +
          '" data-wave-label="' + escapeHtml(waveLabels[pts[pi].wi]) + '" style="cursor:pointer"/>');
      }

      // End label (last data point)
      if (pts.length > 0) {
        var last = pts[pts.length - 1];
        var lbl = typeLabel === "%" ? Math.round(last.v) + "%" : last.v.toFixed(2);
        endLabels.push({ x: last.x + 10, y: last.y + 4, text: lbl, colour: ser.colour, rawY: last.y });
      }
    }

    // Simple collision avoidance for end labels
    endLabels.sort(function(a, b) { return a.rawY - b.rawY; });
    for (var ei = 1; ei < endLabels.length; ei++) {
      if (endLabels[ei].y - endLabels[ei - 1].y < 14) {
        endLabels[ei].y = endLabels[ei - 1].y + 14;
      }
    }
    for (var ej = 0; ej < endLabels.length; ej++) {
      var el = endLabels[ej];
      svg.push('<text x="' + el.x + '" y="' + el.y + '" fill="' + el.colour + '" font-size="12" font-weight="600">' + el.text + '</text>');
    }

    svg.push('</svg>');

    // Legend below chart
    svg.push('<div class="vis-legend">');
    for (var li = 0; li < series.length; li++) {
      svg.push('<span class="vis-legend-item"><span class="vis-legend-swatch" style="background:' + series[li].colour + '"></span>' + escapeHtml(series[li].label) + '</span>');
    }
    svg.push('</div>');

    container.innerHTML = svg.join("\n");
  }

  // ---- Sidebar toggle ----
  window.visToggleSidebarItem = function(id, btn) {
    visState.visible[id] = !visState.visible[id];
    btn.classList.toggle("active", visState.visible[id]);

    // Toggle table rows
    var rows = document.querySelectorAll('tr[data-vis-id="' + id + '"]');
    rows.forEach(function(row) { row.classList.toggle("vis-item-hidden", !visState.visible[id]); });

    // Re-render chart
    var data = loadExplorerData();
    if (data && visState.chartVisible) renderVisCombinedChart(data);
  };

  // ---- Context change (Mode A segment selector) ----
  window.visChangeContext = function(value) {
    visState.contextSegment = value;
    var data = loadExplorerData();
    if (!data) return;
    // Rebuild table and chart
    var tableEl = document.getElementById("vis-table");
    if (tableEl) tableEl.innerHTML = buildVisTable(data);
    if (visState.chartVisible) renderVisCombinedChart(data);
  };

  // ---- Toggle change rows ----
  window.visToggleChange = function(type, show) {
    if (type === "vs-prev") visState.vprev = show;
    if (type === "vs-base") visState.vbase = show;
    var cls = type === "vs-prev" ? "tk-vs-prev" : "tk-vs-base";
    document.querySelectorAll("#vis-tbl .tk-change-row." + cls).forEach(function(row) {
      row.classList.toggle("visible", show);
    });
  };

  // ---- Toggle chart ----
  window.visToggleChart = function(show) {
    visState.chartVisible = show;
    var el = document.getElementById("vis-chart");
    if (el) el.style.display = show ? "" : "none";
    if (show) {
      var data = loadExplorerData();
      if (data) renderVisCombinedChart(data);
    }
  };

  // ---- Insight ----
  window.visToggleInsight = function() {
    var c = document.getElementById("vis-insight");
    var btn = c ? c.previousElementSibling : null;
    if (c) { c.style.display = ""; if (btn) btn.style.display = "none"; }
    var editor = document.getElementById("vis-insight-editor");
    if (editor) editor.focus();
  };

  window.visDismissInsight = function() {
    var c = document.getElementById("vis-insight");
    var btn = c ? c.previousElementSibling : null;
    var editor = document.getElementById("vis-insight-editor");
    if (editor) editor.innerHTML = "";
    if (c) { c.style.display = "none"; if (btn) btn.style.display = ""; }
  };

  // ---- Pin ----
  window.visTogglePinMenu = function() {
    var menu = document.getElementById("vis-pin-menu");
    if (menu) menu.style.display = menu.style.display === "none" ? "" : "none";
  };

  window.visPinView = function(mode) {
    var menu = document.getElementById("vis-pin-menu");
    if (menu) menu.style.display = "none";

    var main = document.getElementById("vis-main-panel");
    if (!main) return;

    var titleEl = main.querySelector(".vis-context-title, .vis-context-select");
    var titleText = titleEl ? (titleEl.tagName === "SELECT" ? titleEl.options[titleEl.selectedIndex].text : titleEl.textContent) : "Visualise";
    var insight = document.getElementById("vis-insight-editor");
    var insightText = insight ? insight.innerHTML.trim() : "";

    var pinHtml = '<div class="pinned-view-content">';
    pinHtml += '<h3>' + escapeHtml(titleText) + '</h3>';
    if (insightText) pinHtml += '<div class="pinned-insight">' + insightText + '</div>';
    if (mode === "all" || mode === "chart") {
      var chartEl = document.getElementById("vis-chart");
      if (chartEl) pinHtml += '<div class="pinned-chart">' + chartEl.innerHTML + '</div>';
    }
    if (mode === "all" || mode === "table") {
      var tableEl = document.getElementById("vis-table");
      if (tableEl) pinHtml += '<div class="pinned-table">' + tableEl.innerHTML + '</div>';
    }
    pinHtml += '</div>';

    if (typeof addPinnedView === "function") addPinnedView(pinHtml, titleText);
  };

  // ---- Export ----
  window.visExportExcel = function() {
    var table = document.getElementById("vis-tbl");
    if (!table) return;
    var titleText = visState.mode === "metrics" ? ("Metrics - " + visState.contextSegment) :
      (findMetric(loadExplorerData(), visState.contextMetric) || {}).label || "Export";

    var xml = '<?xml version="1.0"?>\n<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';
    xml += '<Styles><Style ss:ID="Default"><Font ss:FontName="Calibri" ss:Size="11"/></Style>';
    xml += '<Style ss:ID="H"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/><Interior ss:Color="#D9E2F3" ss:Pattern="Solid"/></Style></Styles>\n';
    xml += '<Worksheet ss:Name="Data"><Table>\n';
    xml += '<Row><Cell><Data ss:Type="String">' + xmlEscape(titleText) + '</Data></Cell></Row><Row></Row>\n';

    table.querySelectorAll("tr").forEach(function(tr) {
      if (tr.classList.contains("vis-item-hidden")) return;
      if (tr.classList.contains("tk-change-row") && !tr.classList.contains("visible")) return;
      xml += '<Row>';
      tr.querySelectorAll("th, td").forEach(function(cell) {
        var sid = cell.tagName === "TH" ? "H" : "Default";
        var txt = cell.textContent.trim();
        var num = parseFloat(txt);
        var type = (!isNaN(num) && txt.match(/^[\d.\-+]+%?$/)) ? "Number" : "String";
        if (type === "Number") txt = String(num);
        xml += '<Cell ss:StyleID="' + sid + '"><Data ss:Type="' + type + '">' + xmlEscape(txt) + '</Data></Cell>';
      });
      xml += '</Row>\n';
    });

    xml += '</Table></Worksheet></Workbook>';
    var fn = titleText.replace(/[^a-zA-Z0-9_-]/g, "_") + ".xls";
    downloadBlob(xml, fn, "application/vnd.ms-excel");
  };

  window.visExportSlide = function() {
    var main = document.getElementById("vis-main-panel");
    if (main && typeof exportSectionAsSlide === "function") {
      exportSectionAsSlide(main, "Visualise");
    }
  };

  // ---- Mode A: Inject checkboxes into existing heatmap rows ----
  function injectModeACheckboxes() {
    var table = document.getElementById("hm-overview-table");
    if (!table) return;

    // Add checkbox header
    var headerRow = table.querySelector("thead tr");
    if (headerRow && !headerRow.querySelector(".hm-checkbox-col")) {
      var th = document.createElement("th");
      th.className = "hm-th hm-checkbox-col";
      headerRow.insertBefore(th, headerRow.firstChild);
    }

    // Add checkbox cells to each metric row and replace drill-down with selection
    table.querySelectorAll(".hm-metric-row").forEach(function(row) {
      if (row.querySelector(".hm-checkbox-col")) return;
      var metricId = row.getAttribute("data-metric-id");
      var td = document.createElement("td");
      td.className = "hm-td hm-checkbox-col";
      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.className = "hm-row-cb";
      cb.addEventListener("click", function(e) {
        e.stopPropagation();
        toggleExplorerRow(metricId, cb);
      });
      td.appendChild(cb);
      row.insertBefore(td, row.firstChild);

      // Replace drill-down onclick with checkbox toggle
      row.onclick = function() {
        cb.checked = !cb.checked;
        toggleExplorerRow(metricId, cb);
      };
    });

    // Also add empty cells for type/section header rows to maintain colspan
    table.querySelectorAll(".hm-type-header td, .hm-section-header td").forEach(function(td) {
      var currentColspan = parseInt(td.getAttribute("colspan") || "1");
      td.setAttribute("colspan", currentColspan + 1);
    });
  }

  // ---- Export Mode B to Excel ----
  window.explorerExportExcel = function() {
    var table = document.getElementById("hm-b-table");
    if (!table) { alert("No data to export. Select a metric first."); return; }

    var sel = document.getElementById("hm-b-metric-select");
    var metricLabel = sel ? sel.options[sel.selectedIndex].text : "Metric";
    var modeLabel = currentModeBMode === "absolute" ? "Absolute" :
                    currentModeBMode === "vs-prev" ? "vs Previous" : "vs Baseline";

    if (typeof exportSummaryExcel === "function") {
      // Reuse the existing export logic by temporarily swapping table IDs
      // Actually, let's build a simple export directly
    }

    var xml = '<?xml version="1.0"?>\n';
    xml += '<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
    xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';
    xml += '<Styles>\n';
    xml += '<Style ss:ID="Default"><Font ss:FontName="Calibri" ss:Size="11"/></Style>\n';
    xml += '<Style ss:ID="Title"><Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/></Style>\n';
    xml += '<Style ss:ID="Header"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/><Interior ss:Color="#D9E2F3" ss:Pattern="Solid"/></Style>\n';
    xml += '</Styles>\n';

    var sheetName = xmlEscape(metricLabel.substring(0, 31));
    xml += '<Worksheet ss:Name="' + sheetName + '">\n<Table>\n';
    xml += '<Row><Cell ss:StyleID="Title"><Data ss:Type="String">' + xmlEscape(metricLabel) + '</Data></Cell></Row>\n';
    xml += '<Row><Cell><Data ss:Type="String">Mode: ' + xmlEscape(modeLabel) + '</Data></Cell></Row>\n';
    xml += '<Row></Row>\n';

    // Headers
    var headerRow = table.querySelector("thead tr");
    if (headerRow) {
      xml += '<Row>\n';
      headerRow.querySelectorAll("th").forEach(function(th) {
        if (th.classList.contains("hm-checkbox-col") || th.classList.contains("hm-spark-col") || th.classList.contains("hm-delta-col")) return;
        xml += '<Cell ss:StyleID="Header"><Data ss:Type="String">' + xmlEscape(th.textContent.trim()) + '</Data></Cell>\n';
      });
      xml += '<Cell ss:StyleID="Header"><Data ss:Type="String">Change</Data></Cell>\n';
      xml += '</Row>\n';
    }

    // Body rows
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      xml += '<Row>\n';
      tr.querySelectorAll("td").forEach(function(td) {
        if (td.classList.contains("hm-checkbox-col") || td.classList.contains("hm-spark-cell") || td.classList.contains("hm-delta-cell")) return;
        var text = td.textContent.trim();
        var type = "String";
        if (td.classList.contains("hm-value-cell")) {
          var num = parseFloat(td.getAttribute("data-value"));
          if (!isNaN(num)) { text = String(num); type = "Number"; }
        }
        xml += '<Cell><Data ss:Type="' + type + '">' + xmlEscape(text) + '</Data></Cell>\n';
      });
      var delta = tr.querySelector(".hm-delta-cell");
      xml += '<Cell><Data ss:Type="String">' + xmlEscape(delta ? delta.textContent.trim() : "") + '</Data></Cell>\n';
      xml += '</Row>\n';
    });

    xml += '</Table>\n</Worksheet>\n</Workbook>';
    var filename = "segments_" + metricLabel.replace(/[^a-zA-Z0-9_-]/g, "_") + ".xls";
    downloadBlob(xml, filename, "application/vnd.ms-excel");
  };

  // ---- Utilities ----
  function escapeHtml(text) {
    if (!text) return "";
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }

  // ---- Init ----
  function initExplorer() {
    injectModeACheckboxes();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initExplorer);
  } else {
    initExplorer();
  }

})();
