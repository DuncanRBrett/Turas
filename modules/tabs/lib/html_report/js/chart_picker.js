// ---- Chart Column Picker ----
var chartColumnState = {}; // qCode -> { colKey: true/false }

// Get column keys that belong to the active banner group (+ Total)
function getChartKeysForGroup(chartData, groupCode) {
  var allKeys = Object.keys(chartData.columns);
  var totalKey = allKeys[0]; // First key is always Total

  // Find keys belonging to this banner group by checking table column classes
  var groupKeys = [totalKey];
  var seen = {};
  seen[totalKey] = true;
  document.querySelectorAll("th.ct-data-col.bg-" + groupCode + "[data-col-key]").forEach(function(th) {
    var key = th.getAttribute("data-col-key");
    if (!seen[key] && chartData.columns[key]) {
      seen[key] = true;
      groupKeys.push(key);
    }
  });
  return groupKeys;
}

function initChartColumnPickers() {
  buildChartPickersForGroup(currentGroup);
}

function buildChartPickersForGroup(groupCode) {
  // Remove existing pickers
  document.querySelectorAll(".chart-col-picker").forEach(function(el) { el.remove(); });

  document.querySelectorAll(".chart-wrapper[data-chart-data]").forEach(function(wrapper) {
    var qCode = wrapper.getAttribute("data-q-code");
    var data = JSON.parse(wrapper.getAttribute("data-chart-data"));
    if (!data || !data.columns) return;

    var keys = getChartKeysForGroup(data, groupCode);
    if (keys.length === 0) return;

    // Always init state so JS rebuild renders priority metrics
    chartColumnState[qCode] = {};
    chartColumnState[qCode][keys[0]] = true;

    // Only show column picker when multiple columns available
    if (keys.length > 1) {
      var bar = document.createElement("div");
      bar.className = "chart-col-picker";
      bar.setAttribute("data-q-code", qCode);

      var lbl = document.createElement("span");
      lbl.className = "col-chip-label";
      lbl.textContent = "Chart:";
      bar.appendChild(lbl);

      keys.forEach(function(key, idx) {
        var chip = document.createElement("button");
        chip.className = "col-chip" + (idx === 0 ? "" : " col-chip-off");
        chip.setAttribute("data-col-key", key);
        chip.textContent = data.columns[key].display;
        chip.onclick = function() {
          toggleChartColumn(qCode, key, chip);
        };
        bar.appendChild(chip);
      });

      var svg = wrapper.querySelector("svg");
      if (svg) wrapper.insertBefore(bar, svg);
    }

    // Always rebuild chart via JS (renders priority metrics etc.)
    rebuildChartSVG(qCode);
  });
}

function toggleChartColumn(qCode, colKey, chipEl) {
  if (!chartColumnState[qCode]) chartColumnState[qCode] = {};
  var isOn = !!chartColumnState[qCode][colKey];
  if (isOn) {
    // Prevent deselecting the last column
    var activeCount = Object.keys(chartColumnState[qCode]).filter(function(k) {
      return chartColumnState[qCode][k];
    }).length;
    if (activeCount <= 1) return;
    delete chartColumnState[qCode][colKey];
    chipEl.classList.add("col-chip-off");
  } else {
    chartColumnState[qCode][colKey] = true;
    chipEl.classList.remove("col-chip-off");
  }
  rebuildChartSVG(qCode);
}

function rebuildChartSVG(qCode) {
  var wrapper = document.querySelector(".chart-wrapper[data-q-code=\"" + qCode + "\"]");
  if (!wrapper) return;
  var data = JSON.parse(wrapper.getAttribute("data-chart-data"));
  if (!data) return;

  var selectedKeys = Object.keys(chartColumnState[qCode] || {}).filter(function(k) {
    return chartColumnState[qCode][k];
  });
  if (selectedKeys.length === 0) return;

  // Apply row exclusions: filter out excluded labels from chart data
  var excluded = (window._chartExclusions && window._chartExclusions[qCode]) || {};
  var filteredData = data;
  if (Object.keys(excluded).length > 0) {
    // Deep-copy data to avoid mutating the original
    filteredData = JSON.parse(JSON.stringify(data));
    var keepIdx = [];
    for (var i = 0; i < filteredData.labels.length; i++) {
      if (!excluded[filteredData.labels[i]]) keepIdx.push(i);
    }
    filteredData.labels = keepIdx.map(function(i) { return data.labels[i]; });
    // Filter colours array too (used by stacked charts)
    if (filteredData.colours) {
      filteredData.colours = keepIdx.map(function(i) { return data.colours[i]; });
    }
    Object.keys(filteredData.columns).forEach(function(key) {
      filteredData.columns[key].values = keepIdx.map(function(i) {
        return data.columns[key].values[i];
      });
    });
    if (filteredData.priority_metric && filteredData.priority_metric.values) {
      var pmv = {};
      Object.keys(filteredData.priority_metric.values).forEach(function(key) {
        // Priority metric values are per-column, not per-row, so keep as-is
        pmv[key] = filteredData.priority_metric.values[key];
      });
      filteredData.priority_metric.values = pmv;
    }
  }

  var oldSvg = wrapper.querySelector("svg");
  if (!oldSvg) return;

  var svgMarkup = "";
  if (filteredData.chart_type === "stacked") {
    svgMarkup = buildMultiStackedSVG(filteredData, selectedKeys, qCode);
  } else {
    svgMarkup = buildMultiHorizontalSVG(filteredData, selectedKeys);
  }

  if (!svgMarkup) return;
  var temp = document.createElement("div");
  temp.innerHTML = svgMarkup;
  var newSvg = temp.querySelector("svg");
  if (newSvg) oldSvg.replaceWith(newSvg);

  // Re-apply table sort order to the newly built chart
  var container = wrapper.closest(".question-container");
  if (container) {
    var table = container.querySelector("table.ct-table");
    if (table && sortState[table.id] && sortState[table.id].direction !== "none") {
      var tbody = table.querySelector("tbody");
      if (tbody) {
        var sortedLabels = [];
        tbody.querySelectorAll("tr.ct-row-category:not(.ct-row-net)").forEach(function(row) {
          var labelCell = row.querySelector("td.ct-label-col");
          if (labelCell) sortedLabels.push(getLabelText(labelCell));
        });
        sortChartBars(table, sortedLabels);
      }
    }
  }
}

// Build multi-column stacked bar SVG (one bar per selected column)
function buildMultiStackedSVG(data, selectedKeys, qCode) {
  var barH = 36, barGap = 8, labelMargin = 10;
  var hasPM = data.priority_metric && data.priority_metric.label;
  var pmDecimals = (hasPM && data.priority_metric.decimals != null) ? data.priority_metric.decimals : 1;
  var metricW = hasPM ? 90 : 0;
  var barW = 680;
  var headerH = hasPM ? 20 : 4;
  // Calculate label column width for column names
  var maxLabelLen = 0;
  selectedKeys.forEach(function(k) {
    var len = (data.columns[k].display || "").length;
    if (len > maxLabelLen) maxLabelLen = len;
  });
  var colLabelW = Math.max(60, maxLabelLen * 7 + 16);
  var barStartX = colLabelW;
  var barUsable = barW - colLabelW - labelMargin - metricW;

  var barCount = selectedKeys.length;
  var legendY = headerH + barCount * (barH + barGap) + 16;
  var labels = data.labels || [];
  var colours = data.colours || [];

  // Pre-calculate legend layout (show category names only — per-column % is on the bars)
  var legPositions = [], legX = labelMargin, legRow = 0;
  for (var li = 0; li < labels.length; li++) {
    var legText = labels[li];
    var itemW = legText.length * 6 + 30;
    if (legX + itemW > barW - labelMargin && li > 0) { legRow++; legX = labelMargin; }
    legPositions.push({ x: legX, row: legRow, text: legText });
    legX += itemW;
  }
  var legendRows = legRow + 1;
  var totalH = legendY + legendRows * 18 + 8;

  var clipId = "mc-clip-" + qCode.replace(/[^a-zA-Z0-9]/g, "-");
  var p = [];
  p.push("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 " + barW + " " + totalH + "\" role=\"img\" aria-label=\"Distribution chart\" style=\"font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;\">");

  // Priority metric header (centred above metric pill box)
  if (hasPM) {
    var pmHeaderX = (barW - metricW + 4) + (metricW - 14) / 2;
    p.push("<text x=\"" + pmHeaderX + "\" y=\"" + 14 + "\" text-anchor=\"middle\" fill=\"#94a3b8\" font-size=\"9\" font-weight=\"600\">" + escapeHtml(data.priority_metric.label) + "</text>");
  }

  selectedKeys.forEach(function(key, ki) {
    var y = headerH + ki * (barH + barGap);
    var vals = data.columns[key].values;
    var total = 0;
    vals.forEach(function(v) { total += v; });
    if (total <= 0) return;

    var cid = clipId + "-" + ki;
    p.push("<defs><clipPath id=\"" + cid + "\"><rect x=\"" + barStartX + "\" y=\"" + y + "\" width=\"" + barUsable + "\" height=\"" + barH + "\" rx=\"5\" ry=\"5\"/></clipPath></defs>");

    // Column label
    p.push("<text x=\"" + (colLabelW - 8) + "\" y=\"" + (y + barH / 2) + "\" text-anchor=\"end\" dominant-baseline=\"central\" fill=\"#374151\" font-size=\"11\" font-weight=\"600\">" + escapeHtml(data.columns[key].display) + "</text>");

    // Segments
    var xOff = barStartX;
    for (var si = 0; si < vals.length; si++) {
      var segW = (vals[si] / total) * barUsable;
      if (segW < 1) continue;
      p.push("<rect x=\"" + xOff + "\" y=\"" + y + "\" width=\"" + segW + "\" height=\"" + barH + "\" fill=\"" + (colours[si] || "#999") + "\" clip-path=\"url(#" + cid + ")\"/>");

      // Label inside if fits
      var pctText = Math.round(vals[si]) + "%";
      if (segW > 35) {
        var tFill = getLuminance(colours[si] || "#999") > 0.65 ? "#5c4a3a" : "#ffffff";
        p.push("<text x=\"" + (xOff + segW / 2) + "\" y=\"" + (y + barH / 2) + "\" text-anchor=\"middle\" dominant-baseline=\"central\" fill=\"" + tFill + "\" font-size=\"11\" font-weight=\"600\">" + pctText + "</text>");
      }
      xOff += segW;
    }

    // Priority metric value -- styled pill to the right of bar
    if (hasPM) {
      var pmVals = data.priority_metric.values || {};
      var pmVal = pmVals[key];
      if (pmVal != null) {
        var pmText = pmVal.toFixed(pmDecimals);
        var pmBoxX = barW - metricW + 4;
        var pmBoxW = metricW - 14;
        var pmBoxY = y + 4;
        var pmBoxH = barH - 8;
        p.push("<rect x=\"" + pmBoxX + "\" y=\"" + pmBoxY + "\" width=\"" + pmBoxW + "\" height=\"" + pmBoxH + "\" rx=\"4\" fill=\"#f0fafa\" stroke=\"#d0e8e8\" stroke-width=\"1\"/>");
        p.push("<text x=\"" + (pmBoxX + pmBoxW / 2) + "\" y=\"" + (y + barH / 2) + "\" text-anchor=\"middle\" dominant-baseline=\"central\" fill=\"#1a2744\" font-size=\"13\" font-weight=\"700\">" + pmText + "</text>");
      }
    }
  });

  // Legend (category names only — percentages are shown on the bars themselves)
  for (var li = 0; li < labels.length; li++) {
    var pos = legPositions[li];
    var legY = legendY + pos.row * 18;
    p.push("<circle cx=\"" + (pos.x + 4.5) + "\" cy=\"" + (legY + 5) + "\" r=\"4.5\" fill=\"" + (colours[li] || "#999") + "\"/>");
    p.push("<text x=\"" + (pos.x + 13) + "\" y=\"" + (legY + 9) + "\" fill=\"#64748b\" font-size=\"10.5\">" + escapeHtml(pos.text) + "</text>");
  }

  p.push("</svg>");
  return p.join("\n");
}

// Wrap long label into 2 lines at nearest space to midpoint
function wrapLabel(label, maxChars) {
  if (label.length <= maxChars) return [label];
  var mid = Math.floor(label.length / 2);
  var bestSplit = -1, bestDist = label.length;
  for (var i = 0; i < label.length; i++) {
    if (label[i] === " " && Math.abs(i - mid) < bestDist) {
      bestDist = Math.abs(i - mid);
      bestSplit = i;
    }
  }
  if (bestSplit === -1) return [label];
  return [label.substring(0, bestSplit), label.substring(bestSplit + 1)];
}

// Distinct colour palette from brand colour using HSL rotation
function getDistinctPalette(brandHex, count) {
  var r = parseInt(brandHex.substr(1, 2), 16) / 255;
  var g = parseInt(brandHex.substr(3, 2), 16) / 255;
  var b = parseInt(brandHex.substr(5, 2), 16) / 255;
  var mx = Math.max(r, g, b), mn = Math.min(r, g, b);
  var h = 0, s = 0, l = (mx + mn) / 2;
  if (mx !== mn) {
    var d = mx - mn;
    s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    if (mx === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    else if (mx === g) h = ((b - r) / d + 2) / 6;
    else h = ((r - g) / d + 4) / 6;
  }
  var palette = [];
  var offsets = [0, 35, 190, 60, 150];
  for (var i = 0; i < count; i++) {
    var oh = ((h * 360 + (offsets[i] || i * 72)) % 360) / 360;
    var os = i === 0 ? s : Math.max(0.35, s * 0.8);
    var ol = i === 0 ? l : Math.min(0.55, l + 0.05);
    palette.push(hslToHex(oh, os, ol));
  }
  return palette;
}

function hslToHex(h, s, l) {
  var r2, g2, b2;
  if (s === 0) { r2 = g2 = b2 = l; }
  else {
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    var pp = 2 * l - q;
    r2 = hue2rgb(pp, q, h + 1/3);
    g2 = hue2rgb(pp, q, h);
    b2 = hue2rgb(pp, q, h - 1/3);
  }
  return "#" + ((1 << 24) + (Math.round(r2 * 255) << 16) + (Math.round(g2 * 255) << 8) + Math.round(b2 * 255)).toString(16).slice(1);
}

function hue2rgb(p, q, t) {
  if (t < 0) t += 1; if (t > 1) t -= 1;
  if (t < 1/6) return p + (q - p) * 6 * t;
  if (t < 1/2) return q;
  if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
  return p;
}

// Build multi-column horizontal bar SVG (grouped bars per category)
function buildMultiHorizontalSVG(data, selectedKeys) {
  var labels = data.labels || [];
  var nCols = selectedKeys.length;
  var hasPM = data.priority_metric && data.priority_metric.label;
  var pmDecimals = (hasPM && data.priority_metric.decimals != null) ? data.priority_metric.decimals : 1;
  var barH = 22, subGap = 3, groupGap = 12;
  var wrapThreshold = 30;

  // Wrap labels and calculate widths
  var wrappedLabels = labels.map(function(l) { return wrapLabel(l, wrapThreshold); });
  var maxLine1 = 0, hasWrapped = false;
  wrappedLabels.forEach(function(lines) {
    if (lines[0].length > maxLine1) maxLine1 = lines[0].length;
    if (lines.length > 1) hasWrapped = true;
  });
  var labelW = Math.max(160, maxLine1 * 6.2 + 16);
  var valueW = 45;
  // Right padding: percentage text (~35px) + column name (~80px for multi-col) + gap
  var rightPad = nCols > 1 ? 130 : 50;
  var chartW = 680;
  var barAreaW = chartW - labelW - valueW - rightPad;
  if (barAreaW < 200) { chartW = labelW + valueW + rightPad + 300; barAreaW = 300; }

  // Find max value across selected columns
  var maxVal = 0;
  selectedKeys.forEach(function(key) {
    data.columns[key].values.forEach(function(v) {
      if (v > maxVal) maxVal = v;
    });
  });
  if (maxVal <= 0) maxVal = 1;

  var groupH = nCols * (barH + subGap) - subGap;
  var wrapExtra = hasWrapped ? 10 : 0;
  var topMargin = 4;
  var barsH = topMargin;

  // Pre-calculate group positions accounting for wrapped labels
  var groupPositions = [];
  wrappedLabels.forEach(function(lines) {
    groupPositions.push(barsH);
    var extra = lines.length > 1 ? 10 : 0;
    barsH += groupH + groupGap + extra;
  });

  // Add space for priority metric pill strip below bars
  var metricStripH = (hasPM && nCols > 0) ? 36 : 0;
  var totalH = barsH + metricStripH;

  // Distinct colour palette for columns — use chart_bar_colour for horizontal bars
  var bc = data.chart_bar_colour || data.brand_colour || "#323367";
  var colColours = nCols > 1 ? getDistinctPalette(bc, nCols) : [bc];

  var p = [];
  p.push("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 " + chartW + " " + totalH + "\" role=\"img\" aria-label=\"Bar chart\" style=\"font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;\">");

  labels.forEach(function(label, li) {
    var groupY = groupPositions[li];
    var lines = wrappedLabels[li];

    // Wrap each category group in <g> with data attributes for sort sync
    p.push("<g class=\"chart-bar-group\" data-bar-label=\"" + escapeHtml(label) + "\" data-bar-index=\"" + li + "\" transform=\"translate(0," + groupY + ")\">");

    selectedKeys.forEach(function(key, ki) {
      var y = ki * (barH + subGap);
      var val = data.columns[key].values[li] || 0;
      var barW = Math.max((val / maxVal) * barAreaW, 2);
      var pctText = Math.round(val) + "%";
      var colour = colColours[ki];

      // Category label only on first bar of group -- with wrapping
      if (ki === 0) {
        if (lines.length === 1) {
          p.push("<text x=\"" + (labelW - 8) + "\" y=\"" + (y + barH / 2) + "\" text-anchor=\"end\" dominant-baseline=\"central\" fill=\"#374151\" font-size=\"11\" font-weight=\"500\">" + escapeHtml(lines[0]) + "</text>");
        } else {
          p.push("<text x=\"" + (labelW - 8) + "\" text-anchor=\"end\" fill=\"#374151\" font-size=\"11\" font-weight=\"500\">");
          p.push("<tspan x=\"" + (labelW - 8) + "\" y=\"" + (y + barH / 2 - 6) + "\">" + escapeHtml(lines[0]) + "</tspan>");
          p.push("<tspan x=\"" + (labelW - 8) + "\" dy=\"13\">" + escapeHtml(lines[1]) + "</tspan>");
          p.push("</text>");
        }
      }

      p.push("<rect x=\"" + labelW + "\" y=\"" + y + "\" width=\"" + barW + "\" height=\"" + barH + "\" rx=\"3\" fill=\"" + colour + "\" opacity=\"0.85\"/>");
      p.push("<text x=\"" + (labelW + barW + 8) + "\" y=\"" + (y + barH / 2) + "\" dominant-baseline=\"central\" fill=\"#64748b\" font-size=\"11\" font-weight=\"600\">" + pctText + "</text>");

      // Column name label (small, after percentage, only if multiple columns)
      if (nCols > 1) {
        var afterPct = labelW + barW + 8 + pctText.length * 7 + 6;
        p.push("<text x=\"" + afterPct + "\" y=\"" + (y + barH / 2) + "\" dominant-baseline=\"central\" fill=\"#94a3b8\" font-size=\"9\">" + escapeHtml(data.columns[key].display) + "</text>");
      }
    });

    p.push("</g>");
  });

  // Priority metric pill strip below chart
  if (hasPM) {
    var pmY = barsH + 4;
    p.push("<line x1=\"" + labelW + "\" x2=\"" + (chartW - 10) + "\" y1=\"" + (pmY - 2) + "\" y2=\"" + (pmY - 2) + "\" stroke=\"#e2e8f0\" stroke-width=\"1\"/>");
    // Metric label
    p.push("<text x=\"" + (labelW - 8) + "\" y=\"" + (pmY + 16) + "\" text-anchor=\"end\" fill=\"#94a3b8\" font-size=\"9\" font-weight=\"600\">" + escapeHtml(data.priority_metric.label) + "</text>");
    // Pill badges for each column
    var pillX = labelW;
    selectedKeys.forEach(function(key, ki) {
      var pmVals = data.priority_metric.values || {};
      var pmVal = pmVals[key];
      if (pmVal != null) {
        var pmText = escapeHtml(data.columns[key].display) + " " + pmVal.toFixed(pmDecimals);
        var pillW = pmText.length * 6.5 + 16;
        p.push("<rect x=\"" + pillX + "\" y=\"" + (pmY + 2) + "\" width=\"" + pillW + "\" height=\"" + 22 + "\" rx=\"11\" fill=\"#f0fafa\" stroke=\"#d0e8e8\" stroke-width=\"1\"/>");
        p.push("<text x=\"" + (pillX + pillW / 2) + "\" y=\"" + (pmY + 16) + "\" text-anchor=\"middle\" fill=\"#1a2744\" font-size=\"10\" font-weight=\"600\">" + pmText + "</text>");
        pillX += pillW + 8;
      }
    });
  }

  p.push("</svg>");
  return p.join("\n");
}

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function getLuminance(hex) {
  var r = parseInt(hex.substr(1, 2), 16);
  var g = parseInt(hex.substr(3, 2), 16);
  var b = parseInt(hex.substr(5, 2), 16);
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

function blendColour(hex, mix) {
  var r = parseInt(hex.substr(1, 2), 16);
  var g = parseInt(hex.substr(3, 2), 16);
  var b = parseInt(hex.substr(5, 2), 16);
  var fr = Math.round(255 - (255 - r) * mix);
  var fg = Math.round(255 - (255 - g) * mix);
  var fb = Math.round(255 - (255 - b) * mix);
  return "#" + ((1 << 24) + (fr << 16) + (fg << 8) + fb).toString(16).slice(1);
}

// Chart PNG export - injects question title, renders via canvas, downloads PNG
function exportChartPNG(qCode) {
  var container = document.querySelector(".question-container.active");
  if (!container) return;
  var wrapper = container.querySelector(".chart-wrapper");
  if (!wrapper) return;
  var origSvg = wrapper.querySelector("svg");
  if (!origSvg) return;

  var qTitle = wrapper.getAttribute("data-q-title") || "";
  var qCodeLabel = wrapper.getAttribute("data-q-code") || qCode;

  // Clone SVG so we can modify without affecting the page
  var svgClone = origSvg.cloneNode(true);

  // Parse original viewBox
  var vb = svgClone.getAttribute("viewBox").split(" ").map(Number);
  var origW = vb[2], origH = vb[3];

  // Title dimensions
  var titleFontSize = 14;
  var titlePadding = 12;
  var titleLineHeight = titleFontSize * 1.3;
  // Title block: qCode + question text
  var titleText = qCodeLabel + " - " + qTitle;
  var titleBlockH = titlePadding + titleLineHeight + titlePadding;

  // Expand viewBox to accommodate title at top
  var newH = origH + titleBlockH;
  svgClone.setAttribute("viewBox", "0 0 " + origW + " " + newH);

  // Shift all existing content down by titleBlockH
  var gWrap = document.createElementNS("http://www.w3.org/2000/svg", "g");
  gWrap.setAttribute("transform", "translate(0," + titleBlockH + ")");
  while (svgClone.firstChild) {
    gWrap.appendChild(svgClone.firstChild);
  }
  svgClone.appendChild(gWrap);

  // Add white background
  var bgRect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
  bgRect.setAttribute("x", "0");
  bgRect.setAttribute("y", "0");
  bgRect.setAttribute("width", origW);
  bgRect.setAttribute("height", newH);
  bgRect.setAttribute("fill", "#ffffff");
  svgClone.insertBefore(bgRect, svgClone.firstChild);

  // Add title text
  var titleEl = document.createElementNS("http://www.w3.org/2000/svg", "text");
  titleEl.setAttribute("x", "10");
  titleEl.setAttribute("y", String(titlePadding + titleFontSize));
  titleEl.setAttribute("fill", "#1e293b");
  titleEl.setAttribute("font-size", String(titleFontSize));
  titleEl.setAttribute("font-weight", "600");
  titleEl.setAttribute("font-family", "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif");
  titleEl.textContent = titleText;
  // Insert after background, before content group
  svgClone.insertBefore(titleEl, gWrap);

  // Render to canvas at 3x for crisp PNG (presentation quality)
  var scale = 3;
  var canvasW = origW * scale;
  var canvasH = newH * scale;

  var svgData = new XMLSerializer().serializeToString(svgClone);
  var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
  var url = URL.createObjectURL(svgBlob);

  var img = new Image();
  img.onload = function() {
    var canvas = document.createElement("canvas");
    canvas.width = canvasW;
    canvas.height = canvasH;
    var ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvasW, canvasH);
    ctx.drawImage(img, 0, 0, canvasW, canvasH);
    URL.revokeObjectURL(url);

    canvas.toBlob(function(blob) {
      downloadBlob(blob, qCode + "_chart.png");
    }, "image/png");
  };
  img.src = url;
}

