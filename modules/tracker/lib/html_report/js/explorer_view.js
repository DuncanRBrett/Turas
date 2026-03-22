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
    vbase: false,
    showCI: false,
    showValues: "last",   // "all", "last2", "last", "none"
    labelMode: "last",    // synced with showValues
    yAxisMin: null,        // null = auto (0 for pct/mean, extends negative for NPS)
    yAxisMax: null         // null = auto (above highest data point)
  };

  window.explorerVisualise = function() {
    var ids = Object.keys(explorerSelection);
    if (ids.length === 0) return;

    var data = loadExplorerData();
    if (!data) return;

    // Enable the Visualise tab button (remove greyed-out state)
    var tabBtn = document.getElementById("tab-btn-visualise");
    if (tabBtn) tabBtn.classList.remove("tab-disabled");

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
    visState.yAxisMin = null;
    visState.yAxisMax = null;

    // Annotations persist across navigation — they are keyed to metric+wave
    // and will only render if the matching series is visible

    renderVisualiseView(data);
    if (typeof switchReportTab === "function") switchReportTab("visualise");
  };

  /**
   * Programmatic entry point: visualise specific metric IDs from heatmap drill-down
   * @param {string[]} metricIds - Array of metric IDs to visualise
   */
  window.explorerVisualiseMetrics = function(metricIds) {
    if (!metricIds || metricIds.length === 0) return;
    var data = loadExplorerData();
    if (!data) return;

    // Enable the Visualise tab button (remove greyed-out state)
    var tabBtn = document.getElementById("tab-btn-visualise");
    if (tabBtn) tabBtn.classList.remove("tab-disabled");
    var placeholder = document.getElementById("visualise-placeholder");
    var content = document.getElementById("visualise-content");
    if (placeholder) placeholder.style.display = "none";
    if (content) content.style.display = "";

    visState.mode = "metrics";
    visState.metricIds = metricIds;
    var segSel = document.getElementById("hm-banner-select");
    visState.contextSegment = segSel ? segSel.value : data.segments[0];
    visState.allSegments = data.segments;
    visState.visible = {};
    for (var i = 0; i < metricIds.length; i++) visState.visible[metricIds[i]] = true;

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
    // Significance legend
    h.push('<div class="vis-sidebar-section">');
    h.push('<div class="vis-sidebar-section-title">Significance</div>');
    h.push('<div class="vis-sidebar-legend">');
    h.push('<div class="vis-legend-row"><span class="tk-sig-badge tk-sig-badge-up">&#x25B2; sig</span> Significant increase</div>');
    h.push('<div class="vis-legend-row"><span class="tk-sig-badge tk-sig-badge-down">&#x25BC; sig</span> Significant decrease</div>');
    h.push('<div class="vis-legend-row"><span class="tk-low-base-icon">&#x26A0;</span> Low base (n &lt; 30)</div>');
    h.push('</div></div>');

    // CI bands explanation (shown when CI is toggled on)
    h.push('<div class="vis-sidebar-section vis-ci-legend" id="vis-ci-sidebar" style="display:none">');
    h.push('<div class="vis-sidebar-section-title">Confidence Bands</div>');
    h.push('<div class="vis-sidebar-legend" style="font-size:11px;color:#64748b;line-height:1.5">');
    h.push('Shaded bands show estimated 95% confidence intervals based on sample size (n).');
    h.push(' Wider bands indicate less certainty.');
    h.push(' Non-overlapping bands suggest a meaningful difference.');
    h.push('</div></div>');

    // Low base warnings placeholder (filled after table build)
    h.push('<div class="vis-sidebar-section" id="vis-low-base-section" style="display:none">');
    h.push('<div class="vis-sidebar-section-title vis-warning-title">&#x26A0; Low Base Warnings</div>');
    h.push('<div class="vis-low-base-list" id="vis-low-base-list"></div>');
    h.push('</div>');

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
    h.push('<label class="tk-toggle"><input type="checkbox" onchange="visToggleCI(this.checked)"><span class="tk-toggle-label">Show CI bands</span></label>');
    h.push('<label class="tk-toggle"><input type="checkbox" onchange="visToggleBase(this.checked)"><span class="tk-toggle-label">Show base (n)</span></label>');
    h.push('</div>');
    h.push('<div class="mv-control-group">');
    h.push('<span class="tk-toggle-label" style="font-weight:600;margin-right:4px">Values:</span>');
    h.push('<select class="hm-select" style="font-size:12px;padding:2px 6px" onchange="visSetLabelMode(this.value)">');
    h.push('<option value="last"' + (visState.labelMode === "last" ? ' selected' : '') + '>Last only</option>');
    h.push('<option value="last2"' + (visState.labelMode === "last2" ? ' selected' : '') + '>Last 2</option>');
    h.push('<option value="all"' + (visState.labelMode === "all" ? ' selected' : '') + '>All points</option>');
    h.push('<option value="none"' + (visState.labelMode === "none" ? ' selected' : '') + '>None</option>');
    h.push('</select>');
    h.push('</div>');
    h.push('<div class="mv-control-group">');
    h.push('<span class="tk-toggle-label" style="font-weight:600;margin-right:4px">Y-axis:</span>');
    h.push('<input type="number" class="vis-axis-input" id="vis-ymin" placeholder="Min" step="any"' +
      (visState.yAxisMin != null ? ' value="' + visState.yAxisMin + '"' : '') +
      ' onchange="visSetYAxis()" title="Y-axis minimum (leave blank for auto: starts at 0)">');
    h.push('<span style="color:#94a3b8;margin:0 2px">&ndash;</span>');
    h.push('<input type="number" class="vis-axis-input" id="vis-ymax" placeholder="Max" step="any"' +
      (visState.yAxisMax != null ? ' value="' + visState.yAxisMax + '"' : '') +
      ' onchange="visSetYAxis()" title="Y-axis maximum (leave blank for auto)">');
    h.push('<button class="vis-axis-reset" onclick="visResetYAxis()" title="Reset to auto">&#x21BA;</button>');
    h.push('</div>');
    h.push('<div class="mv-control-group mv-action-buttons" style="border-right:none;margin-left:auto">');
    h.push('<div class="tk-pin-dropdown" style="display:inline-block;position:relative">');
    h.push('<button class="export-btn" onclick="visTogglePinMenu()">&#x1F4CC; Pin &#x25BE;</button>');
    h.push('<div class="tk-pin-menu" id="vis-pin-menu" style="display:none">');
    h.push('<button class="tk-pin-option" onclick="visPinView(\'all\')">Insight + Chart + Table</button>');
    h.push('<button class="tk-pin-option" onclick="visPinView(\'chart\')">Insight + Chart</button>');
    h.push('<button class="tk-pin-option" onclick="visPinView(\'table\')">Insight + Table</button>');
    h.push('</div></div>');
    h.push('<div style="display:inline-block;position:relative">');
    h.push('<button class="export-btn" onclick="visToggleExportMenu()">&#x2B73; Export &#x25BE;</button>');
    h.push('<div class="vis-export-menu" id="vis-export-menu" style="display:none;position:absolute;bottom:100%;right:0;background:#fff;border:1px solid #e2e8f0;border-radius:6px;box-shadow:0 4px 12px rgba(0,0,0,0.1);z-index:100;min-width:160px;padding:4px 0;margin-bottom:4px;">');
    h.push('<button class="export-menu-item" onclick="visExportExcel();visToggleExportMenu()">&#x2B73; Export Excel</button>');
    h.push('<button class="export-menu-item" onclick="visExportSlide();visToggleExportMenu()">&#x1F4F8; Export Slide</button>');
    h.push('</div></div>');
    h.push('</div></div>');

    // Wave chip bar (toggle individual waves)
    h.push('<div class="hm-wave-chips vis-wave-chips" id="vis-wave-chips">');
    h.push('<label class="hm-control-label" style="margin-right:6px;">Waves:</label>');
    for (var wi = 0; wi < data.waves.length; wi++) {
      h.push('<button class="hm-wave-chip active" data-wave="' + escapeHtml(data.waves[wi]) +
        '" onclick="visToggleWaveChip(\'' + escapeHtml(data.waves[wi]) + '\',this)">' +
        escapeHtml(data.waveLabels[wi]) + '</button>');
    }
    h.push('<span class="hm-wave-actions">');
    h.push('<button class="hm-wave-action" onclick="visWaveShowAll()">All</button>');
    h.push('<button class="hm-wave-action" onclick="visWaveShowLast(3)">Last 3</button>');
    h.push('</span>');
    h.push('</div>');

    // Chart area
    h.push('<div class="vis-chart-area" id="vis-chart"></div>');

    // Table area
    h.push('<div class="vis-table-area" id="vis-table">');
    h.push(buildVisTable(data));
    h.push('</div>');

    // Insight area with markdown editor
    h.push('<div class="insight-area">');
    h.push('<button class="insight-toggle" onclick="visToggleInsight()">+ Add Insight</button>');
    h.push('<div class="insight-container" id="vis-insight" style="display:none">');
    h.push('<div class="insight-md-toolbar">');
    h.push('<button class="insight-md-btn" title="Bold" onclick="visInsertMd(\'**\',\'**\')"><strong>B</strong></button>');
    h.push('<button class="insight-md-btn" title="Italic" onclick="visInsertMd(\'*\',\'*\')"><em>I</em></button>');
    h.push('<button class="insight-md-btn" title="Heading" onclick="visInsertMd(\'## \',\'\')">H2</button>');
    h.push('<button class="insight-md-btn" title="Bullet" onclick="visInsertMd(\'- \',\'\')">&#x2022;</button>');
    h.push('<button class="insight-md-btn" title="Quote" onclick="visInsertMd(\'> \',\'\')">"</button>');
    h.push('<span class="insight-md-hint">Supports **bold**, *italic*, ## heading, - bullets, > quotes</span>');
    h.push('</div>');
    h.push('<textarea class="insight-md-editor" id="vis-insight-editor" rows="4" placeholder="Type key insight here... (**bold**, *italic*, ## heading, - bullet, > quote)" oninput="visRenderInsight()"></textarea>');
    h.push('<div class="insight-md-rendered" id="vis-insight-rendered"></div>');
    h.push('<button class="insight-dismiss" title="Delete insight" onclick="visDismissInsight()">&times;</button>');
    h.push('</div></div>');

    h.push('</div>'); // vis-main
    h.push('</div>'); // vis-layout

    content.innerHTML = h.join("\n");

    // Init wave chip state (all waves visible by default in Visualise)
    visWaveState = {};
    for (var wi2 = 0; wi2 < data.waves.length; wi2++) {
      visWaveState[data.waves[wi2]] = true;
    }

    // Render chart after DOM insertion
    if (visState.chartVisible) renderVisCombinedChart(data);

    // Populate low base warnings
    if (visState.lowBaseWarnings && visState.lowBaseWarnings.length > 0) {
      var lbSection = document.getElementById("vis-low-base-section");
      var lbList = document.getElementById("vis-low-base-list");
      if (lbSection && lbList) {
        lbSection.style.display = "";
        var lbHtml = "";
        for (var lb = 0; lb < visState.lowBaseWarnings.length; lb++) {
          lbHtml += '<div class="vis-low-base-item">&#x26A0; ' + escapeHtml(visState.lowBaseWarnings[lb]) + '</div>';
        }
        lbList.innerHTML = lbHtml;
      }
    }
  }

  // ---- Unified detail table ----
  function buildVisTable(data) {
    var waves = data.waves;
    var waveLabels = data.waveLabels;
    var LOW_BASE_THRESHOLD = 30;
    var t = [];

    t.push('<table class="tk-table vis-detail-table" id="vis-tbl">');
    t.push('<thead><tr class="tk-wave-header-row">');
    t.push('<th class="tk-th tk-label-col">' + (visState.mode === "metrics" ? "Metric" : "Segment") + '</th>');
    for (var wi = 0; wi < waves.length; wi++) {
      t.push('<th class="tk-th tk-wave-header" data-wave="' + waves[wi] + '">' + escapeHtml(waveLabels[wi]) + '</th>');
    }
    t.push('</tr></thead><tbody>');

    // Helper: build a change cell with significance badge
    function changeCell(cellData, changeKey, sigKey, metricName, waveId) {
      var cv = cellData ? cellData[changeKey] : null;
      if (cv == null) return '<td class="tk-td tk-change-cell" data-wave="' + waveId + '">&mdash;</td>';
      var formatted = HmUtils.formatChange(cv, metricName);
      var isSig = cellData && cellData[sigKey] === true;
      var sigHtml = "";
      if (isSig) {
        var cls = cv > 0 ? "tk-sig-badge tk-sig-badge-up" : "tk-sig-badge tk-sig-badge-down";
        var arrow = cv > 0 ? "&#x25B2;" : "&#x25BC;";
        sigHtml = ' <span class="' + cls + '">' + arrow + ' sig</span>';
      }
      var bgStyle = HmUtils.changeCellStyle(cv, isSig);
      return '<td class="tk-td tk-change-cell" data-wave="' + waveId + '" style="' + bgStyle + '">' +
        '<span class="tk-change-val">' + formatted + '</span>' + sigHtml + '</td>';
    }

    // Helper: build base (n) row
    function baseRow(segData, visId, hidCls) {
      var r = '<tr class="tk-base-row' + hidCls + '" data-vis-id="' + escapeHtml(visId) + '">';
      r += '<td class="tk-td tk-label-col tk-base-label">Base (n)</td>';
      var hasLowBase = false;
      for (var bw = 0; bw < waves.length; bw++) {
        var bc = segData[waves[bw]];
        var n = bc ? bc.n : null;
        var lowBase = (n != null && n < LOW_BASE_THRESHOLD);
        if (lowBase) hasLowBase = true;
        var cls = lowBase ? ' class="tk-td tk-base-cell tk-low-base"' : ' class="tk-td tk-base-cell"';
        r += '<td' + cls + ' data-wave="' + waves[bw] + '">' + (n != null ? n : "&mdash;") +
          (lowBase ? ' <span class="tk-low-base-icon" title="Low base: n=' + n + '">&#x26A0;</span>' : '') + '</td>';
      }
      r += '</tr>';
      return { html: r, hasLowBase: hasLowBase };
    }

    var lowBaseWarnings = [];

    if (visState.mode === "metrics") {
      var seg = visState.contextSegment;
      for (var mi = 0; mi < visState.metricIds.length; mi++) {
        var met = findMetric(data, visState.metricIds[mi]);
        if (!met || !met.data[seg]) continue;
        var sd = met.data[seg];
        var vis = visState.visible[met.id] !== false;
        var hidCls = vis ? "" : " vis-item-hidden";
        var col = VIS_COLOURS[mi % VIS_COLOURS.length];

        // Value row with sig indicators
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

        // Base (n) row
        var br = baseRow(sd, met.id, hidCls);
        t.push(br.html);
        if (br.hasLowBase) lowBaseWarnings.push(met.label);

        // vs Previous (with significance badges and background)
        t.push('<tr class="tk-change-row tk-vs-prev' + hidCls + '" data-vis-id="' + escapeHtml(met.id) + '">');
        t.push('<td class="tk-td tk-label-col tk-change-label">vs Prev</td>');
        for (var pw = 0; pw < waves.length; pw++) {
          t.push(changeCell(sd[waves[pw]], "change_prev", "sig_prev", met.label, waves[pw]));
        }
        t.push('</tr>');

        // vs Baseline
        t.push('<tr class="tk-change-row tk-vs-base' + hidCls + '" data-vis-id="' + escapeHtml(met.id) + '">');
        t.push('<td class="tk-td tk-label-col tk-change-label">vs Base</td>');
        for (var bw = 0; bw < waves.length; bw++) {
          t.push(changeCell(sd[waves[bw]], "change_base", "sig_base", met.label, waves[bw]));
        }
        t.push('</tr>');
      }
    } else {
      // Rows = segments, for the context metric
      var metric = findMetric(data, visState.contextMetric);
      if (metric) {
        for (var si2 = 0; si2 < visState.allSegments.length; si2++) {
          var seg2 = visState.allSegments[si2];
          var sd2 = metric.data[seg2];
          if (!sd2) continue;
          var segIdx2 = data.segments.indexOf(seg2);
          var vis2 = visState.visible[seg2] !== false;
          var hidCls2 = vis2 ? "" : " vis-item-hidden";
          var col2 = VIS_COLOURS[segIdx2 % VIS_COLOURS.length];

          // Value row
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

          // Base (n) row
          var br2 = baseRow(sd2, seg2, hidCls2);
          t.push(br2.html);
          if (br2.hasLowBase) lowBaseWarnings.push(seg2);

          // vs Previous
          t.push('<tr class="tk-change-row tk-vs-prev' + hidCls2 + '" data-vis-id="' + escapeHtml(seg2) + '">');
          t.push('<td class="tk-td tk-label-col tk-change-label">vs Prev</td>');
          for (var pw2 = 0; pw2 < waves.length; pw2++) {
            t.push(changeCell(sd2[waves[pw2]], "change_prev", "sig_prev", metric.label, waves[pw2]));
          }
          t.push('</tr>');

          // vs Baseline
          t.push('<tr class="tk-change-row tk-vs-base' + hidCls2 + '" data-vis-id="' + escapeHtml(seg2) + '">');
          t.push('<td class="tk-td tk-label-col tk-change-label">vs Base</td>');
          for (var bw2 = 0; bw2 < waves.length; bw2++) {
            t.push(changeCell(sd2[waves[bw2]], "change_base", "sig_base", metric.label, waves[bw2]));
          }
          t.push('</tr>');
        }
      }
    }

    t.push('</tbody></table>');

    // Store low base warnings for sidebar
    visState.lowBaseWarnings = lowBaseWarnings;

    return t.join("\n");
  }

  // ---- Catmull-Rom spline helper (cardinal spline, tension 0) ----
  function catmullRomPath(points) {
    if (points.length < 2) return "";
    if (points.length === 2) return "M" + points[0].x + "," + points[0].y + "L" + points[1].x + "," + points[1].y;

    var d = "M" + points[0].x + "," + points[0].y;
    for (var i = 0; i < points.length - 1; i++) {
      var p0 = points[Math.max(0, i - 1)];
      var p1 = points[i];
      var p2 = points[i + 1];
      var p3 = points[Math.min(points.length - 1, i + 2)];

      // Control points (tension = 0 for smooth Catmull-Rom)
      var cp1x = p1.x + (p2.x - p0.x) / 6;
      var cp1y = p1.y + (p2.y - p0.y) / 6;
      var cp2x = p2.x - (p3.x - p1.x) / 6;
      var cp2y = p2.y - (p3.y - p1.y) / 6;

      d += "C" + cp1x.toFixed(1) + "," + cp1y.toFixed(1) + "," +
           cp2x.toFixed(1) + "," + cp2y.toFixed(1) + "," +
           p2.x.toFixed(1) + "," + p2.y.toFixed(1);
    }
    return d;
  }

  // ---- Combined SVG Line Chart with Annotations ----
  function renderVisCombinedChart(data) {
    var container = document.getElementById("vis-chart");
    if (!container) return;

    // Filter waves by chip state (if chips exist)
    var waves = data.waves;
    var waveLabels = data.waveLabels;
    var ws = (typeof getVisWaveState === "function") ? getVisWaveState() : {};
    var hasWaveFilter = Object.keys(ws).length > 0;
    if (hasWaveFilter) {
      var filteredWaves = [], filteredLabels = [];
      for (var fi = 0; fi < data.waves.length; fi++) {
        if (ws[data.waves[fi]] !== false) {
          filteredWaves.push(data.waves[fi]);
          filteredLabels.push(data.waveLabels[fi]);
        }
      }
      if (filteredWaves.length > 0) {
        waves = filteredWaves;
        waveLabels = filteredLabels;
      }
    }

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
          rawData: met.data[seg],
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
            rawData: metric.data[segName],
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
    var typeLabel = (series[0].type === "pct" || series[0].type === "pct_response") ? "%" : series[0].type === "nps" ? "NPS" : "";

    // Premium chart dimensions
    var W = 960, H = 380;
    var pad = { top: 40, right: 80, bottom: 55, left: 60 };
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
    var dataMin = Math.min.apply(null, allVals), dataMax = Math.max.apply(null, allVals);

    // Default: start from 0 (or below most negative), extend above max
    // User can override with visState.yAxisMin / yAxisMax
    var yMin, yMax;
    if (typeLabel === "%") {
      // Percentage: 0 to above max (capped at 100)
      yMin = 0;
      yMax = Math.min(100, dataMax + Math.max(5, (dataMax - dataMin) * 0.15));
      if (dataMax > 95) yMax = 100;
    } else if (series[0].type === "nps") {
      // NPS can be negative (-100 to +100)
      // Start below most negative, end above most positive
      yMin = Math.min(0, dataMin);
      yMax = Math.max(0, dataMax);
      var npsRange = yMax - yMin || 20;
      yMin = Math.floor((yMin - npsRange * 0.1) / 5) * 5;
      yMax = Math.ceil((yMax + npsRange * 0.1) / 5) * 5;
      yMin = Math.max(-100, yMin);
      yMax = Math.min(100, yMax);
    } else {
      // Means: start from 0 (or below lowest if scale allows), extend above max
      yMin = 0;
      // If data starts well above 0 (e.g., 3.5 on 5-pt scale), still show from 0
      yMax = dataMax + Math.max(0.2, (dataMax - dataMin) * 0.15);
      // If values are negative, extend below
      if (dataMin < 0) {
        yMin = dataMin - Math.abs(dataMin) * 0.15;
      }
    }

    // Apply user overrides if set
    if (visState.yAxisMin != null) yMin = visState.yAxisMin;
    if (visState.yAxisMax != null) yMax = visState.yAxisMax;

    function xP(i) { return pad.left + (i / Math.max(waves.length - 1, 1)) * plotW; }
    function yP(val) { return pad.top + plotH - ((val - yMin) / (yMax - yMin)) * plotH; }

    var svg = [];
    svg.push('<svg class="vis-line-chart" viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg">');

    // Definitions
    svg.push('<defs>');
    svg.push('<filter id="callout-shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity="0.12"/></filter>');
    svg.push('</defs>');

    // Horizontal grid lines (faint, decluttered)
    var nTicks = 5;
    for (var gt = 0; gt <= nTicks; gt++) {
      var yv = yMin + (gt / nTicks) * (yMax - yMin);
      var yy = yP(yv);
      svg.push('<line x1="' + pad.left + '" y1="' + yy + '" x2="' + (W - pad.right) + '" y2="' + yy + '" stroke="#e2e8f0" stroke-width="0.75"/>');
      var tl = typeLabel === "%" ? Math.round(yv) + "%" : yv.toFixed(1);
      svg.push('<text x="' + (pad.left - 12) + '" y="' + (yy + 4) + '" text-anchor="end" fill="#94a3b8" font-size="11" font-weight="400" font-family="-apple-system,BlinkMacSystemFont,\'Segoe UI\',sans-serif">' + tl + '</text>');
    }

    // X axis labels (premium typography)
    for (var xi = 0; xi < waves.length; xi++) {
      svg.push('<text x="' + xP(xi) + '" y="' + (H - pad.bottom + 22) + '" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500" font-family="-apple-system,BlinkMacSystemFont,\'Segoe UI\',sans-serif">' + escapeHtml(waveLabels[xi]) + '</text>');
      // Subtle vertical gridline
      svg.push('<line x1="' + xP(xi) + '" y1="' + pad.top + '" x2="' + xP(xi) + '" y2="' + (H - pad.bottom) + '" stroke="#f1f5f9" stroke-width="0.5"/>');
    }

    // Confidence bands (shaded area ± estimated CI based on n)
    // Hidden by default; toggled with CI checkbox. Uses smooth Catmull-Rom edges.
    var showCI = visState.showCI === true;
    for (var sb = 0; sb < series.length; sb++) {
      var serBand = series[sb];
      var bandUpper = [], bandLower = [];
      for (var bw = 0; bw < waves.length; bw++) {
        if (serBand.values[bw] == null) continue;
        var val = serBand.values[bw];
        var ciWidth;
        var nEst = 300; // default assumed n
        // Try to get actual n from rawData
        if (serBand.rawData) {
          var bCell = serBand.rawData[waves[bw]];
          if (bCell && bCell.n) nEst = bCell.n;
        }
        if (serBand.type === "pct" || serBand.type === "pct_response") {
          var p = val / 100;
          ciWidth = Math.max(0.5, 1.96 * Math.sqrt(Math.max(0, p * (1 - p)) / nEst) * 100);
        } else if (serBand.type === "nps") {
          ciWidth = Math.max(1, 1.96 * Math.sqrt(2500 / nEst)); // NPS has std~50
        } else {
          // Mean: assume std ~0.8 for 5-pt scale
          ciWidth = Math.max(0.03, 1.96 * 0.8 / Math.sqrt(nEst));
        }
        bandUpper.push({ x: xP(bw), y: yP(val + ciWidth) });
        bandLower.push({ x: xP(bw), y: yP(val - ciWidth) });
      }
      if (bandUpper.length >= 2) {
        // Smooth upper and lower edges using Catmull-Rom
        var upperPath = catmullRomPath(bandUpper);
        var lowerRev = bandLower.slice().reverse();
        var lowerPath = catmullRomPath(lowerRev);
        // Combine: upper path forward, line to lower start, lower path, close
        var bandD = upperPath + "L" + lowerRev[0].x.toFixed(1) + "," + lowerRev[0].y.toFixed(1) +
          lowerPath.substring(lowerPath.indexOf("C")) + "Z";
        svg.push('<path class="vis-ci-band" d="' + bandD + '" fill="' + serBand.colour + '" opacity="0.10"' +
          (showCI ? '' : ' style="display:none"') + '/>');
      }
    }

    // Build series-colour lookup for annotations
    var seriesColourMap = {};
    for (var scm = 0; scm < series.length; scm++) {
      seriesColourMap[series[scm].id] = series[scm].colour;
    }

    // Lines + dots + data point labels
    var labelMode = visState.labelMode || "last";
    var allPointLabels = []; // collected for collision avoidance

    for (var s2 = 0; s2 < series.length; s2++) {
      var ser = series[s2];
      var pts = [];
      for (var w = 0; w < waves.length; w++) {
        if (ser.values[w] != null) pts.push({ x: xP(w), y: yP(ser.values[w]), v: ser.values[w], wi: w });
      }

      // Draw smooth curve
      if (pts.length > 1) {
        var smoothPath = catmullRomPath(pts);
        svg.push('<path d="' + smoothPath + '" fill="none" stroke="' + ser.colour + '" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>');
      }

      // Draw dots — each is a tk-chart-point for annotation support + hover callout
      for (var pi = 0; pi < pts.length; pi++) {
        var waveId = waves[pts[pi].wi];
        var ptVal = pts[pi].v;
        // Compute changes from previous and baseline
        // Use series-specific type for formatting (not global typeLabel which is based on first series)
        var serIsPct = (ser.type === "pct" || ser.type === "pct_response" || ser.type === "nps");
        var changePrev = "", changeBase = "";
        if (ser.rawData) {
          // Previous wave change
          if (pts[pi].wi > 0) {
            for (var pw = pts[pi].wi - 1; pw >= 0; pw--) {
              var prevCell = ser.rawData[waves[pw]];
              if (prevCell && prevCell.value != null) {
                var cp = ptVal - prevCell.value;
                changePrev = (cp >= 0 ? "+" : "") + (serIsPct ? Math.round(cp) : cp.toFixed(2));
                break;
              }
            }
          }
          // Baseline change (wave 0)
          var baseCell = ser.rawData[waves[0]];
          if (baseCell && baseCell.value != null && pts[pi].wi > 0) {
            var cb = ptVal - baseCell.value;
            changeBase = (cb >= 0 ? "+" : "") + (serIsPct ? Math.round(cb) : cb.toFixed(2));
          }
        }
        var formattedVal = serIsPct ? Math.round(ptVal) + "%" : ptVal.toFixed(2);
        svg.push('<circle class="tk-chart-point" cx="' + pts[pi].x + '" cy="' + pts[pi].y +
          '" r="5" fill="#fff" stroke="' + ser.colour + '" stroke-width="2.5"' +
          ' data-wave="' + waveId + '" data-segment="' + escapeHtml(ser.id) +
          '" data-wave-label="' + escapeHtml(waveLabels[pts[pi].wi]) + '"' +
          ' data-metric-id="' + escapeHtml(visState.mode === "metrics" ? ser.id : visState.contextMetric) + '"' +
          ' data-label="' + escapeHtml(ser.label) + '"' +
          ' data-value="' + escapeHtml(formattedVal) + '"' +
          ' data-change-prev="' + escapeHtml(changePrev) + '"' +
          ' data-change-base="' + escapeHtml(changeBase) + '"' +
          ' data-colour="' + ser.colour + '"' +
          ' style="cursor:pointer"/>');
        svg.push('<circle cx="' + pts[pi].x + '" cy="' + pts[pi].y + '" r="2.5" fill="' + ser.colour + '" pointer-events="none"/>');
      }

      // Determine which points get value labels based on labelMode
      if (labelMode !== "none" && pts.length > 0) {
        var labelPts = [];
        if (labelMode === "all") {
          labelPts = pts;
        } else if (labelMode === "last2") {
          labelPts = pts.slice(-2);
        } else { // "last"
          labelPts = pts.slice(-1);
        }
        for (var lpi = 0; lpi < labelPts.length; lpi++) {
          var lp = labelPts[lpi];
          var lpText = serIsPct ? Math.round(lp.v) + "%" : lp.v.toFixed(1);
          var isLast = (lp === pts[pts.length - 1]);
          allPointLabels.push({
            x: isLast ? lp.x + 14 : lp.x,
            y: isLast ? lp.y : lp.y - 14,
            rawY: lp.y,
            text: lpText,
            colour: ser.colour,
            anchor: isLast ? "start" : "middle",
            isEnd: isLast
          });
        }
      }
    }

    // Point labels — collision avoidance
    allPointLabels.sort(function(a, b) { return a.rawY - b.rawY; });
    for (var ei = 1; ei < allPointLabels.length; ei++) {
      if (Math.abs(allPointLabels[ei].x - allPointLabels[ei - 1].x) < 40 &&
          Math.abs(allPointLabels[ei].y - allPointLabels[ei - 1].y) < 16) {
        allPointLabels[ei].y = allPointLabels[ei - 1].y + 16;
      }
    }
    for (var ej = 0; ej < allPointLabels.length; ej++) {
      var el = allPointLabels[ej];
      var fontSize = el.isEnd ? "12" : "10";
      var fontWeight = el.isEnd ? "700" : "600";
      svg.push('<text x="' + el.x + '" y="' + (el.y + 4) + '" text-anchor="' + el.anchor + '" fill="' + el.colour +
        '" font-size="' + fontSize + '" font-weight="' + fontWeight + '" font-family="-apple-system,sans-serif">' + el.text + '</text>');
    }

    // Load and render annotations (prominent style with arrows)
    var annots = [];
    if (typeof tkAnnotations !== "undefined") {
      if (visState.mode === "metrics") {
        for (var ai = 0; ai < visState.metricIds.length; ai++) {
          var mAnns = tkAnnotations.getForMetric(visState.metricIds[ai]);
          for (var aj = 0; aj < mAnns.length; aj++) annots.push(mAnns[aj]);
        }
      } else {
        annots = tkAnnotations.getForMetric(visState.contextMetric) || [];
      }
    }

    // Render annotation markers — prominent style: solid colour pill with arrow to data point
    for (var an = 0; an < annots.length; an++) {
      var ann = annots[an];
      var waveIdx = waves.indexOf(ann.waveId);
      if (waveIdx < 0) continue;
      var axPos = xP(waveIdx);

      // Find the data point Y for this annotation's metric/segment
      var targetY = null;
      var annSeriesCol = ann.colour || "#64748b";
      // Match to a visible series to get colour and y position
      for (var as2 = 0; as2 < series.length; as2++) {
        var aSer = series[as2];
        if (aSer.id === ann.metricId || aSer.id === ann.segment) {
          annSeriesCol = aSer.colour;
          if (aSer.values[waveIdx] != null) targetY = yP(aSer.values[waveIdx]);
          break;
        }
      }
      // If no matching visible series found, skip this annotation entirely
      // (the series is hidden — don't fall back to another series)
      if (targetY === null) continue;

      // Callout card position — above the data point
      var calloutY = Math.max(pad.top + 8, targetY - 38 - (an % 2) * 26);
      var annText = ann.text.length > 24 ? ann.text.substring(0, 24) + "\u2026" : ann.text;
      var textW = annText.length * 6 + 16;
      var cardX = axPos - textW / 2;
      // Clamp to chart bounds
      if (cardX < pad.left) cardX = pad.left;
      if (cardX + textW > W - pad.right) cardX = W - pad.right - textW;

      // Arrow line from callout to data point
      var arrowStartY = calloutY + 10;
      svg.push('<line x1="' + axPos + '" y1="' + arrowStartY + '" x2="' + axPos + '" y2="' + (targetY - 7) +
        '" stroke="' + annSeriesCol + '" stroke-width="1.5" stroke-dasharray="3,2" opacity="0.7"/>');
      // Arrowhead
      svg.push('<polygon points="' + (axPos - 3) + ',' + (targetY - 10) + ' ' + axPos + ',' + (targetY - 5) + ' ' + (axPos + 3) + ',' + (targetY - 10) +
        '" fill="' + annSeriesCol + '" opacity="0.7"/>');

      // Solid colour pill (prominent — series colour background, white text)
      svg.push('<rect x="' + cardX + '" y="' + (calloutY - 10) + '" width="' + textW + '" height="20" rx="10" fill="' + annSeriesCol + '" opacity="0.9"/>');
      svg.push('<text x="' + (cardX + textW / 2) + '" y="' + (calloutY + 4) + '" text-anchor="middle" fill="#fff" font-size="10" font-weight="700" font-family="-apple-system,sans-serif">' + escapeHtml(annText) + '</text>');
    }

    svg.push('</svg>');

    // Legend below chart (compact, premium)
    var legendParts = [];
    legendParts.push('<div class="vis-legend">');
    for (var li = 0; li < series.length; li++) {
      legendParts.push('<span class="vis-legend-item"><span class="vis-legend-swatch" style="background:' + series[li].colour + '"></span>' + escapeHtml(series[li].label) + '</span>');
    }
    legendParts.push('</div>');

    svg.push(legendParts.join(""));

    container.innerHTML = svg.join("\n");

    // Bind hover callout on data points
    bindHoverCallouts(container);
  }

  // ---- Hover callout for data points ----
  function bindHoverCallouts(container) {
    // Create or reuse callout element
    var callout = document.getElementById("vis-hover-callout");
    if (!callout) {
      callout = document.createElement("div");
      callout.id = "vis-hover-callout";
      callout.className = "vis-hover-callout";
      var panel = (typeof _tkPanel === "function") ? _tkPanel() : document.body;
      panel.appendChild(callout);
    }

    var points = container.querySelectorAll(".tk-chart-point");
    points.forEach(function(pt) {
      pt.addEventListener("mouseenter", function(e) {
        var label = pt.getAttribute("data-label") || "";
        var waveLbl = pt.getAttribute("data-wave-label") || "";
        var value = pt.getAttribute("data-value") || "";
        var chgPrev = pt.getAttribute("data-change-prev") || "";
        var chgBase = pt.getAttribute("data-change-base") || "";
        var colour = pt.getAttribute("data-colour") || "#333";

        var html = '<div class="vis-callout-header" style="border-left:4px solid ' + colour + '">';
        html += '<span class="vis-callout-label">' + escapeHtml(label) + '</span>';
        html += '<span class="vis-callout-wave">' + escapeHtml(waveLbl) + '</span>';
        html += '</div>';
        html += '<div class="vis-callout-value">' + escapeHtml(value) + '</div>';
        if (chgPrev || chgBase) {
          html += '<div class="vis-callout-changes">';
          if (chgPrev) {
            var prevCls = chgPrev.charAt(0) === "+" ? "pos" : (chgPrev.charAt(0) === "-" ? "neg" : "");
            html += '<div class="vis-callout-change"><span class="vis-callout-change-label">vs Previous</span><span class="vis-callout-change-val ' + prevCls + '">' + escapeHtml(chgPrev) + '</span></div>';
          }
          if (chgBase) {
            var baseCls = chgBase.charAt(0) === "+" ? "pos" : (chgBase.charAt(0) === "-" ? "neg" : "");
            html += '<div class="vis-callout-change"><span class="vis-callout-change-label">vs Baseline</span><span class="vis-callout-change-val ' + baseCls + '">' + escapeHtml(chgBase) + '</span></div>';
          }
          html += '</div>';
        }

        callout.innerHTML = html;
        callout.style.display = "block";

        // Position near the point
        var rect = pt.getBoundingClientRect();
        var cw = callout.offsetWidth || 180;
        var ch = callout.offsetHeight || 80;
        var left = rect.left + window.scrollX + 16;
        var top = rect.top + window.scrollY - ch - 8;
        // If too high, show below
        if (top < window.scrollY + 8) top = rect.bottom + window.scrollY + 8;
        // If too far right, shift left
        if (left + cw > window.innerWidth + window.scrollX - 16) left = rect.left + window.scrollX - cw - 8;
        callout.style.left = left + "px";
        callout.style.top = top + "px";
      });

      pt.addEventListener("mouseleave", function() {
        callout.style.display = "none";
      });
    });
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
    // Annotations persist — they are keyed to metric+wave, not segment
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

  // ---- Toggle base (n) rows ----
  window.visToggleBase = function(show) {
    document.querySelectorAll("#vis-tbl .tk-base-row").forEach(function(row) {
      row.classList.toggle("visible", show);
    });
  };

  // ---- Set label mode (all / last2 / last / none) ----
  window.visSetLabelMode = function(mode) {
    visState.labelMode = mode;
    var data = loadExplorerData();
    if (data && visState.chartVisible) renderVisCombinedChart(data);
  };

  // ---- Clear annotations when data context changes ----
  function visClearAnnotations() {
    if (typeof tkAnnotations === "undefined") return;
    // Remove annotations for all currently visualised metrics/segments
    if (visState.mode === "metrics") {
      for (var i = 0; i < visState.metricIds.length; i++) {
        var anns = tkAnnotations.getForMetric(visState.metricIds[i]);
        for (var j = anns.length - 1; j >= 0; j--) {
          tkAnnotations.remove(anns[j].metricId, anns[j].waveId, anns[j].segment);
        }
      }
    } else if (visState.contextMetric) {
      var anns2 = tkAnnotations.getForMetric(visState.contextMetric);
      for (var k = anns2.length - 1; k >= 0; k--) {
        tkAnnotations.remove(anns2[k].metricId, anns2[k].waveId, anns2[k].segment);
      }
    }
  }

  // ---- Y-axis controls ----
  window.visSetYAxis = function() {
    var minEl = document.getElementById("vis-ymin");
    var maxEl = document.getElementById("vis-ymax");
    visState.yAxisMin = (minEl && minEl.value !== "") ? parseFloat(minEl.value) : null;
    visState.yAxisMax = (maxEl && maxEl.value !== "") ? parseFloat(maxEl.value) : null;
    var data = loadExplorerData();
    if (data && visState.chartVisible) renderVisCombinedChart(data);
  };

  window.visResetYAxis = function() {
    visState.yAxisMin = null;
    visState.yAxisMax = null;
    var minEl = document.getElementById("vis-ymin");
    var maxEl = document.getElementById("vis-ymax");
    if (minEl) minEl.value = "";
    if (maxEl) maxEl.value = "";
    var data = loadExplorerData();
    if (data && visState.chartVisible) renderVisCombinedChart(data);
  };

  // ---- Toggle CI bands ----
  window.visToggleCI = function(show) {
    visState.showCI = show;
    document.querySelectorAll(".vis-ci-band").forEach(function(el) {
      el.style.display = show ? "" : "none";
    });
    // Toggle CI sidebar legend
    var ciSidebar = document.getElementById("vis-ci-sidebar");
    if (ciSidebar) ciSidebar.style.display = show ? "" : "none";
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

  // ---- Insight (markdown editor) ----
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
    var rendered = document.getElementById("vis-insight-rendered");
    if (editor) editor.value = "";
    if (rendered) rendered.innerHTML = "";
    if (c) { c.style.display = "none"; if (btn) btn.style.display = ""; }
  };

  window.visRenderInsight = function() {
    var editor = document.getElementById("vis-insight-editor");
    var rendered = document.getElementById("vis-insight-rendered");
    if (editor && rendered && typeof renderMarkdown === "function") {
      rendered.innerHTML = renderMarkdown(editor.value);
    }
  };

  window.visInsertMd = function(before, after) {
    var editor = document.getElementById("vis-insight-editor");
    if (!editor) return;
    var start = editor.selectionStart;
    var end = editor.selectionEnd;
    var text = editor.value;
    var selected = text.substring(start, end);
    var replacement = before + (selected || "text") + after;
    editor.value = text.substring(0, start) + replacement + text.substring(end);
    editor.focus();
    var newPos = start + before.length + (selected || "text").length;
    editor.setSelectionRange(newPos, newPos);
    visRenderInsight();
  };

  // ---- Pin ----
  window.visTogglePinMenu = function() {
    var menu = document.getElementById("vis-pin-menu");
    if (menu) menu.style.display = menu.style.display === "none" ? "" : "none";
    // Close export menu if open
    var expMenu = document.getElementById("vis-export-menu");
    if (expMenu) expMenu.style.display = "none";
  };

  // ---- Unified Export dropdown ----
  window.visToggleExportMenu = function() {
    var menu = document.getElementById("vis-export-menu");
    if (menu) menu.style.display = menu.style.display === "none" ? "" : "none";
    // Close pin menu if open
    var pinMenu = document.getElementById("vis-pin-menu");
    if (pinMenu) pinMenu.style.display = "none";
  };

  window.visPinView = function(mode) {
    var menu = document.getElementById("vis-pin-menu");
    if (menu) menu.style.display = "none";

    var main = document.getElementById("vis-main-panel");
    if (!main) return;

    // Determine title
    var titleEl = main.querySelector(".vis-context-title, .vis-context-select");
    var titleText = titleEl ? (titleEl.tagName === "SELECT" ? titleEl.options[titleEl.selectedIndex].text : titleEl.textContent) : "Visualise";

    // Capture insight (rendered markdown HTML)
    var insightEditor = document.getElementById("vis-insight-editor");
    var insightRendered = document.getElementById("vis-insight-rendered");
    var insightText = insightRendered ? insightRendered.innerHTML.trim() : (insightEditor ? insightEditor.value.trim() : "");

    // Capture chart SVG
    var chartSvg = "";
    if (mode === "all" || mode === "chart") {
      var chartEl = document.getElementById("vis-chart");
      if (chartEl) chartSvg = chartEl.innerHTML;
    }

    // Capture table HTML (clean: remove hidden rows)
    var tableHtml = "";
    if (mode === "all" || mode === "table") {
      var tableEl = document.getElementById("vis-table");
      if (tableEl) {
        var clone = tableEl.cloneNode(true);
        clone.querySelectorAll(".vis-item-hidden").forEach(function(r) { r.remove(); });
        clone.querySelectorAll(".tk-change-row:not(.visible)").forEach(function(r) { r.remove(); });
        tableHtml = clone.innerHTML;
      }
    }

    // Build pin object matching pinnedViews structure
    if (typeof pinnedViews === "undefined") { console.warn("Pinned views not available"); return; }

    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
      metricId: "visualise-" + (visState.mode === "metrics" ? visState.contextSegment : visState.contextMetric),
      metricTitle: titleText,
      visibleSegments: [],
      tableHtml: tableHtml,
      chartSvg: chartSvg,
      chartVisible: mode === "all" || mode === "chart",
      pinMode: mode,
      insightText: insightText,
      timestamp: Date.now(),
      order: pinnedViews.length
    };

    pinnedViews.push(pinObj);
    if (typeof renderPinnedCards === "function") renderPinnedCards();
    if (typeof updatePinBadge === "function") updatePinBadge();
    if (typeof savePinnedData === "function") savePinnedData();
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

  // ---- Visualise wave chip toggle ----
  var visWaveState = {};  // { waveId: true/false } for Visualise tab

  function applyVisWaveVisibility() {
    var data = loadExplorerData();
    if (!data) return;
    // Table columns
    var tbl = document.getElementById("vis-tbl");
    if (tbl) {
      for (var wid in visWaveState) {
        tbl.querySelectorAll('th[data-wave="' + wid + '"], td[data-wave="' + wid + '"]').forEach(function(el) {
          el.classList.toggle("hm-wave-hidden", !visWaveState[wid]);
        });
      }
    }
    // Rebuild chart with only visible waves
    if (visState.chartVisible && data) renderVisCombinedChart(data);
  }

  window.visToggleWaveChip = function(waveId, chipEl) {
    // Prevent deselecting all
    var activeCount = 0;
    for (var k in visWaveState) { if (visWaveState[k]) activeCount++; }
    if (activeCount <= 1 && visWaveState[waveId]) return;
    chipEl.classList.toggle("active");
    visWaveState[waveId] = chipEl.classList.contains("active");
    applyVisWaveVisibility();
  };

  window.visWaveShowAll = function() {
    document.querySelectorAll("#vis-wave-chips .hm-wave-chip").forEach(function(chip) {
      chip.classList.add("active");
      var wid = chip.getAttribute("data-wave");
      if (wid) visWaveState[wid] = true;
    });
    applyVisWaveVisibility();
  };

  window.visWaveShowLast = function(n) {
    var chips = document.querySelectorAll("#vis-wave-chips .hm-wave-chip");
    var total = chips.length;
    chips.forEach(function(chip, idx) {
      var isActive = idx >= total - n;
      chip.classList.toggle("active", isActive);
      var wid = chip.getAttribute("data-wave");
      if (wid) visWaveState[wid] = isActive;
    });
    applyVisWaveVisibility();
  };

  // Expose wave state for chart rendering
  window.getVisWaveState = function() { return visWaveState; };

  // ---- Listen for annotation changes to refresh Visualise chart ----
  document.addEventListener("tk-annotation-changed", function() {
    var data = loadExplorerData();
    if (data && visState.chartVisible && visState.mode) {
      renderVisCombinedChart(data);
    }
  });

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
