/* ============================================================================
 * TurasTracker - Overview Heatmap Interactivity
 * ============================================================================
 * Handles banner switching, value display mode toggle (absolute/change),
 * sort controls, and click-to-drill navigation for the overview heatmap.
 * VERSION: 1.1.0
 * ============================================================================ */

(function() {
  "use strict";

  var currentBanner = "Total";
  var currentMode = "absolute";  // "absolute", "vs-prev", "vs-base"
  var brandColour = (typeof BRAND_COLOUR_HEX !== "undefined") ? BRAND_COLOUR_HEX : "#323367";

  // ---- Read thresholds from data attribute ----
  var hmThresholds = { pct: {green:70,amber:50}, mean5: {green:4,amber:3}, mean10: {green:7,amber:5}, nps: {green:30,amber:0} };
  (function loadThresholds() {
    var section = document.querySelector(".hm-overview-section[data-thresholds]");
    if (section) {
      try { hmThresholds = JSON.parse(section.getAttribute("data-thresholds")); } catch(e) {}
    }
  })();

  // ---- Colour utilities ----
  function hexToRgb(hex) {
    var r = parseInt(hex.substring(1, 3), 16);
    var g = parseInt(hex.substring(3, 5), 16);
    var b = parseInt(hex.substring(5, 7), 16);
    return { r: r, g: g, b: b };
  }

  function absoluteCellStyle(val, metricType) {
    // Green/amber/red threshold-based colouring
    var thr;
    if (metricType === "pct") {
      thr = hmThresholds.pct;
    } else if (metricType === "nps") {
      thr = hmThresholds.nps;
    } else if (metricType === "mean") {
      thr = (val <= 5.5) ? hmThresholds.mean5 : hmThresholds.mean10;
    } else {
      var rgb = hexToRgb(brandColour);
      return "background:rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + ",0.12)";
    }

    var greenThr = thr.green;
    var amberThr = thr.amber;
    var opacity, frac;

    if (val >= greenThr) {
      // Green zone
      var scaleMax = (metricType === "pct" || metricType === "nps") ? 100 : (val <= 5.5 ? 5 : 10);
      frac = Math.min(1, (val - greenThr) / (scaleMax - greenThr + 0.01));
      opacity = (0.12 + frac * 0.20).toFixed(2);
      return "background:rgba(5,150,105," + opacity + ")";
    } else if (val >= amberThr) {
      // Amber zone
      frac = Math.min(1, (val - amberThr) / (greenThr - amberThr + 0.01));
      opacity = (0.12 + (1 - frac) * 0.15).toFixed(2);
      return "background:rgba(217,159,42," + opacity + ")";
    } else {
      // Red zone
      if (metricType === "pct") {
        frac = Math.min(1, (amberThr - val) / (amberThr + 0.01));
      } else if (metricType === "nps") {
        frac = Math.min(1, (amberThr - val) / (amberThr + 100 + 0.01));
      } else {
        frac = Math.min(1, (amberThr - val) / (amberThr - 1 + 0.01));
      }
      opacity = (0.12 + frac * 0.20).toFixed(2);
      return "background:rgba(192,57,43," + opacity + ")";
    }
  }

  function changeCellStyle(changeVal, isSig) {
    if (changeVal === null || isNaN(changeVal)) return "";
    var r, g, b;
    if (changeVal > 0) { r = 5; g = 150; b = 105; }      // green
    else if (changeVal < 0) { r = 192; g = 57; b = 43; }  // red
    else return "";
    var magnitude = Math.abs(changeVal);
    // Match R-side: more striking range
    var intensity = Math.min(1, magnitude / 10);
    var opacity = 0.10 + intensity * 0.30;
    if (isSig) opacity += 0.10;
    return "background:rgba(" + r + "," + g + "," + b + "," + opacity.toFixed(2) + ")";
  }

  function formatChange(val, metricName) {
    if (val === null || isNaN(val)) return "\u2014";
    var prefix = val > 0 ? "+" : "";
    if (/pct|box|range|proportion|category|any/.test(metricName)) {
      return prefix + Math.round(val) + "pp";
    } else if (metricName === "nps_score" || metricName === "nps") {
      return prefix + Math.round(val);
    } else {
      return prefix + val.toFixed(2);
    }
  }

  // ---- Sparkline builder (JS equivalent of R build_sparkline_svg) ----
  function buildSparklineSvg(values, width, height, colour) {
    width = width || 80;
    height = height || 24;
    colour = colour || brandColour;
    var valid = [], validIdx = [];
    for (var i = 0; i < values.length; i++) {
      if (values[i] !== null && !isNaN(values[i])) {
        valid.push(values[i]);
        validIdx.push(i);
      }
    }
    if (valid.length < 2) return "";
    var yMin = valid[0], yMax = valid[0];
    for (var i = 1; i < valid.length; i++) {
      if (valid[i] < yMin) yMin = valid[i];
      if (valid[i] > yMax) yMax = valid[i];
    }
    var yRange = yMax - yMin;
    if (yRange === 0) yRange = 1;
    var pad = 2, plotW = width - 2 * pad, plotH = height - 2 * pad;
    var totalPoints = values.length;
    var pts = [];
    for (var i = 0; i < valid.length; i++) {
      var x = pad + validIdx[i] / Math.max(1, totalPoints - 1) * plotW;
      var y = pad + plotH - (valid[i] - yMin) / yRange * plotH;
      pts.push(x.toFixed(1) + "," + y.toFixed(1));
    }
    var lastX = pad + validIdx[valid.length - 1] / Math.max(1, totalPoints - 1) * plotW;
    var lastY = pad + plotH - (valid[valid.length - 1] - yMin) / yRange * plotH;
    return '<svg class="tk-sparkline" width="' + width + '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '">' +
      '<polyline points="' + pts.join(" ") + '" fill="none" stroke="' + colour + '" stroke-width="1.5" stroke-linejoin="round"/>' +
      '<circle cx="' + lastX.toFixed(1) + '" cy="' + lastY.toFixed(1) + '" r="2" fill="' + colour + '"/></svg>';
  }

  // ---- Banner switching ----
  window.hmSwitchBanner = function(segmentName) {
    currentBanner = segmentName;
    refreshHeatmap();
  };

  // ---- Mode switching ----
  window.hmSwitchMode = function(mode) {
    currentMode = mode;
    // Update chip active states
    var chips = document.querySelectorAll(".hm-mode-chip");
    for (var i = 0; i < chips.length; i++) {
      var chip = chips[i];
      if (chip.getAttribute("data-mode") === mode) {
        chip.classList.add("active");
      } else {
        chip.classList.remove("active");
      }
    }
    // Show/hide mode note
    var modeNote = document.getElementById("hm-mode-note");
    if (modeNote) {
      modeNote.style.display = (mode === "vs-prev" || mode === "vs-base") ? "" : "none";
    }
    refreshHeatmap();
  };

  // ---- Refresh heatmap cells ----
  function refreshHeatmap() {
    var rows = document.querySelectorAll(".hm-metric-row");
    for (var ri = 0; ri < rows.length; ri++) {
      var row = rows[ri];
      var segDataAttr = row.getAttribute("data-seg-data");
      if (!segDataAttr) continue;

      var segData;
      try { segData = JSON.parse(segDataAttr); } catch (e) { continue; }

      var bannerData = segData[currentBanner];
      if (!bannerData) continue;

      var metricType = row.getAttribute("data-metric-type") || "other";
      var metricName = row.getAttribute("data-metric-name") || "";

      var cells = row.querySelectorAll(".hm-value-cell");
      for (var ci = 0; ci < cells.length; ci++) {
        var cell = cells[ci];
        var waveId = cell.getAttribute("data-wave");
        var waveData = bannerData[waveId];
        if (!waveData) {
          cell.textContent = "\u2014";
          cell.style.cssText = "";
          continue;
        }

        if (currentMode === "absolute") {
          cell.innerHTML = waveData.display || "\u2014";
          if (waveData.value !== null && !isNaN(waveData.value)) {
            cell.style.cssText = absoluteCellStyle(waveData.value, metricType);
          } else {
            cell.style.cssText = "";
          }
        } else if (currentMode === "vs-prev") {
          var change = waveData.change_prev;
          if (change !== null && !isNaN(change)) {
            cell.innerHTML = formatChange(change, metricName);
            cell.style.cssText = changeCellStyle(change, waveData.sig_prev === true);
          } else {
            cell.innerHTML = "\u2014";
            cell.style.cssText = "";
          }
        } else if (currentMode === "vs-base") {
          var changeBase = waveData.change_base;
          if (changeBase !== null && !isNaN(changeBase)) {
            cell.innerHTML = formatChange(changeBase, metricName);
            cell.style.cssText = changeCellStyle(changeBase, waveData.sig_base === true);
          } else {
            cell.innerHTML = "\u2014";
            cell.style.cssText = "";
          }
        }
      }

      // Update sparkline from current segment data
      var sparkCell = row.querySelector(".hm-spark-cell");
      if (sparkCell) {
        var waveKeys = Object.keys(bannerData);
        var sparkVals = [];
        for (var wi = 0; wi < waveKeys.length; wi++) {
          var wd = bannerData[waveKeys[wi]];
          sparkVals.push(wd && wd.value !== null && !isNaN(wd.value) ? wd.value : null);
        }
        sparkCell.innerHTML = buildSparklineSvg(sparkVals);
      }

      // Update delta chip
      var deltaCell = row.querySelector(".hm-delta-cell");
      if (deltaCell) {
        var waves = Object.keys(bannerData);
        var lastWave = waves[waves.length - 1];
        var lastData = bannerData[lastWave];
        if (lastData) {
          var changeKey = currentMode === "vs-base" ? "change_base" : "change_prev";
          var sigKey = currentMode === "vs-base" ? "sig_base" : "sig_prev";
          var deltaChange = lastData[changeKey];
          if (deltaChange !== null && !isNaN(deltaChange)) {
            var cls = deltaChange > 0 ? "hm-delta-up" : (deltaChange < 0 ? "hm-delta-down" : "hm-delta-flat");
            var sigMark = lastData[sigKey] === true ? " *" : "";
            deltaCell.innerHTML = '<span class="hm-delta ' + cls + '">' +
              formatChange(deltaChange, metricName) + sigMark + '</span>';
          } else {
            deltaCell.innerHTML = "";
          }
        }
      }
    }
  }

  // ---- Sort (preserves type/section headers, sorts only within each type group) ----
  window.hmSort = function(mode) {
    var table = document.getElementById("hm-overview-table");
    if (!table) return;
    var tbody = table.querySelector("tbody");
    if (!tbody) return;

    // Collect all rows categorised
    var allRows = Array.prototype.slice.call(tbody.children);
    var typeGroups = [];  // array of { header: node|null, sections: [{header, rows}] }
    var currentGroup = null;
    var currentSection = null;

    for (var i = 0; i < allRows.length; i++) {
      var row = allRows[i];
      if (row.classList.contains("hm-type-header")) {
        currentGroup = { header: row, sections: [{ header: null, rows: [] }] };
        currentSection = currentGroup.sections[0];
        typeGroups.push(currentGroup);
      } else if (row.classList.contains("hm-section-header")) {
        if (!currentGroup) {
          currentGroup = { header: null, sections: [] };
          typeGroups.push(currentGroup);
        }
        currentSection = { header: row, rows: [] };
        currentGroup.sections.push(currentSection);
      } else if (row.classList.contains("hm-metric-row")) {
        if (!currentGroup) {
          currentGroup = { header: null, sections: [{ header: null, rows: [] }] };
          currentSection = currentGroup.sections[0];
          typeGroups.push(currentGroup);
        }
        if (!currentSection) {
          currentSection = { header: null, rows: [] };
          currentGroup.sections.push(currentSection);
        }
        currentSection.rows.push(row);
      }
    }

    // Sort rows within each section
    if (mode !== "original") {
      var sortFn;
      if (mode === "value-desc") {
        sortFn = function(a, b) { return getLatestValue(b) - getLatestValue(a); };
      } else if (mode === "change-desc") {
        sortFn = function(a, b) { return Math.abs(getLatestChange(b)) - Math.abs(getLatestChange(a)); };
      }
      for (var g = 0; g < typeGroups.length; g++) {
        for (var s = 0; s < typeGroups[g].sections.length; s++) {
          typeGroups[g].sections[s].rows.sort(sortFn);
        }
      }
    } else {
      // Original order: sort by data-sort-order within each section
      for (var g = 0; g < typeGroups.length; g++) {
        for (var s = 0; s < typeGroups[g].sections.length; s++) {
          typeGroups[g].sections[s].rows.sort(function(a, b) {
            return parseFloat(a.getAttribute("data-sort-order") || "0") -
                   parseFloat(b.getAttribute("data-sort-order") || "0");
          });
        }
      }
    }

    // Rebuild tbody preserving structure
    while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
    for (var g = 0; g < typeGroups.length; g++) {
      var group = typeGroups[g];
      if (group.header) tbody.appendChild(group.header);
      for (var s = 0; s < group.sections.length; s++) {
        var section = group.sections[s];
        if (section.header) tbody.appendChild(section.header);
        for (var r = 0; r < section.rows.length; r++) {
          tbody.appendChild(section.rows[r]);
        }
      }
    }
  };

  function getLatestValue(row) {
    var cells = row.querySelectorAll(".hm-value-cell");
    if (cells.length === 0) return 0;
    var last = cells[cells.length - 1];
    var val = parseFloat(last.getAttribute("data-value"));
    return isNaN(val) ? 0 : val;
  }

  function getLatestChange(row) {
    var segData;
    try { segData = JSON.parse(row.getAttribute("data-seg-data")); } catch (e) { return 0; }
    var bannerData = segData[currentBanner];
    if (!bannerData) return 0;
    var waves = Object.keys(bannerData);
    var lastWave = waves[waves.length - 1];
    var lastData = bannerData[lastWave];
    if (!lastData) return 0;
    var change = lastData.change_prev;
    return (change !== null && !isNaN(change)) ? change : 0;
  }

  // ---- Drill-down navigation ----
  window.hmDrillDown = function(metricId) {
    if (typeof switchReportTab === "function") {
      switchReportTab("metrics");
    }
    if (typeof selectTrackerMetric === "function") {
      setTimeout(function() {
        selectTrackerMetric(metricId);
      }, 100);
    }
  };

  // ---- KPI Card show/hide/pin ----
  window.hideKpiCard = function(metricId) {
    var card = document.querySelector('.kpi-card-item[data-metric-id="' + metricId + '"]');
    if (card) {
      card.classList.toggle("kpi-card-hidden");
    }
  };

  window.toggleAllKpiCards = function() {
    var cards = document.querySelectorAll('.kpi-card-item');
    var anyHidden = false;
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].classList.contains("kpi-card-hidden")) { anyHidden = true; break; }
    }
    for (var i = 0; i < cards.length; i++) {
      if (anyHidden) {
        cards[i].classList.remove("kpi-card-hidden");
      } else {
        cards[i].classList.add("kpi-card-hidden");
      }
    }
  };

  window.pinVisibleKpiCards = function() {
    if (typeof pinSummarySection === "function") {
      pinSummarySection("kpi-cards");
    }
  };

  // ---- Significant changes segment filter ----
  window.filterSigBySegment = function(segment) {
    var cards = document.querySelectorAll(".dash-sig-card");
    var visibleCount = 0;
    for (var i = 0; i < cards.length; i++) {
      var card = cards[i];
      var cardSeg = card.getAttribute("data-segment");
      if (segment === "all" || cardSeg === segment) {
        card.style.display = "";
        visibleCount++;
      } else {
        card.style.display = "none";
      }
    }
    // Show/hide empty message
    var emptyMsg = document.getElementById("sig-filter-empty");
    if (emptyMsg) {
      emptyMsg.style.display = visibleCount === 0 ? "" : "none";
    }
    // Show/hide the "show more" button
    var showMoreBtn = document.getElementById("sig-show-more-btn");
    if (showMoreBtn) {
      showMoreBtn.style.display = visibleCount > 6 ? "" : "none";
    }
  };

  // ---- Summary Export (main implementation in pinned_views.js) ----

  window.pinSummaryTable = window.pinSummaryTable || function() {
    if (typeof pinSummarySection === "function") {
      pinSummarySection("overview-heatmap");
    }
  };

  window.exportSummaryTableSlide = window.exportSummaryTableSlide || function() {
    if (typeof exportSummarySlide === "function") {
      exportSummarySlide("overview-heatmap");
    }
  };

  // ---- Expose shared utilities for Explorer module ----
  window.HmUtils = {
    absoluteCellStyle: absoluteCellStyle,
    changeCellStyle: changeCellStyle,
    formatChange: formatChange,
    buildSparklineSvg: buildSparklineSvg
  };

})();
