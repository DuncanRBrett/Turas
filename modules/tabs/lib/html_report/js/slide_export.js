// ---- Slide PNG Export (Enhanced) ----
// Modes: "chart" (chart only), "table" (table only), "chart_table" (both side by side)
// PowerPoint landscape: 1280x720 base, rendered at 3x for high-res output.

function wrapTextLines(text, maxWidth, charWidth) {
  if (!text) return [];
  var maxChars = Math.floor(maxWidth / charWidth);
  if (text.length <= maxChars) return [text];
  var words = text.split(" ");
  var lines = [], current = "";
  for (var i = 0; i < words.length; i++) {
    var test = current ? current + " " + words[i] : words[i];
    if (test.length > maxChars && current) {
      lines.push(current);
      current = words[i];
    } else {
      current = test;
    }
  }
  if (current) lines.push(current);
  return lines;
}

function createWrappedText(ns, lines, x, startY, lineHeight, attrs) {
  var el = document.createElementNS(ns, "text");
  el.setAttribute("x", x);
  for (var key in attrs) { el.setAttribute(key, attrs[key]); }
  for (var i = 0; i < lines.length; i++) {
    var tspan = document.createElementNS(ns, "tspan");
    tspan.setAttribute("x", x);
    tspan.setAttribute("y", startY + i * lineHeight);
    tspan.textContent = lines[i];
    el.appendChild(tspan);
  }
  return { element: el, height: lines.length * lineHeight };
}

// Toggle slide export dropdown menu
function toggleSlideMenu(qCode) {
  var menuId = "slide-menu-" + qCode.replace(/[^a-zA-Z0-9]/g, "-");
  var menu = document.getElementById(menuId);
  if (!menu) return;
  var isOpen = menu.style.display !== "none";
  // Close all slide menus first
  document.querySelectorAll(".slide-menu").forEach(function(m) { m.style.display = "none"; });
  if (!isOpen) {
    menu.style.display = "block";
    // Close on outside click
    setTimeout(function() {
      document.addEventListener("click", function closeMenu(e) {
        if (!menu.contains(e.target)) {
          menu.style.display = "none";
          document.removeEventListener("click", closeMenu);
        }
      });
    }, 10);
  }
}

// Extract visible table data as array of rows for SVG rendering
function extractSlideTableData(container) {
  var table = container.querySelector("table.ct-table");
  if (!table) return null;
  var rows = [];
  var headerRow = [];
  // Header: get visible columns
  table.querySelectorAll("thead th").forEach(function(th) {
    if (th.style.display === "none" || th.offsetParent === null) return;
    var text = th.querySelector(".ct-header-text");
    headerRow.push(text ? text.textContent.trim() : th.textContent.trim().split("\n")[0].trim());
  });
  rows.push({ cells: headerRow, type: "header" });

  // Body rows: skip excluded rows, get visible columns
  table.querySelectorAll("tbody tr").forEach(function(tr) {
    if (tr.classList.contains("ct-row-excluded")) return;
    var cells = [];
    var isBase = tr.classList.contains("ct-row-base");
    var isMean = tr.classList.contains("ct-row-mean");
    var isNet = tr.classList.contains("ct-row-net");
    tr.querySelectorAll("td").forEach(function(td) {
      if (td.style.display === "none" || td.offsetParent === null) return;
      var text = td.textContent.trim().split("\n")[0].trim();
      // Clean up exclusion button text
      text = text.replace(/[\u2715\u25CB]/g, "").trim();
      cells.push(text);
    });
    if (cells.length > 0) {
      rows.push({ cells: cells, type: isBase ? "base" : (isMean ? "mean" : (isNet ? "net" : "data")) });
    }
  });
  return rows;
}

// Render table data into SVG elements at (x, y) with maxWidth
function renderTableSVG(ns, svgParent, tableData, x, y, maxWidth) {
  if (!tableData || tableData.length === 0) return 0;
  var nCols = tableData[0].cells.length;
  if (nCols === 0) return 0;

  var rowH = 18, headerH = 22, fontSize = 9, padX = 6;
  // Calculate column widths: first col gets more space
  var firstColW = Math.min(Math.max(maxWidth * 0.3, 120), 200);
  var dataColW = nCols > 1 ? (maxWidth - firstColW) / (nCols - 1) : maxWidth;

  var curY = y;
  tableData.forEach(function(row, ri) {
    var isHeader = row.type === "header";
    var rH = isHeader ? headerH : rowH;

    // Row background
    var bgRect = document.createElementNS(ns, "rect");
    bgRect.setAttribute("x", x); bgRect.setAttribute("y", curY);
    bgRect.setAttribute("width", maxWidth); bgRect.setAttribute("height", rH);
    if (isHeader) {
      bgRect.setAttribute("fill", "#1a2744");
    } else if (row.type === "base") {
      bgRect.setAttribute("fill", "#fafbfc");
    } else if (row.type === "mean") {
      bgRect.setAttribute("fill", "#fef9e7");
    } else if (row.type === "net") {
      bgRect.setAttribute("fill", "#f5f0e8");
    } else if (ri % 2 === 0) {
      bgRect.setAttribute("fill", "#ffffff");
    } else {
      bgRect.setAttribute("fill", "#f9fafb");
    }
    svgParent.appendChild(bgRect);

    // Cell text
    row.cells.forEach(function(cellText, ci) {
      var cellX = ci === 0 ? x + padX : x + firstColW + (ci - 1) * dataColW + padX;
      var textEl = document.createElementNS(ns, "text");
      textEl.setAttribute("x", cellX);
      textEl.setAttribute("y", curY + rH / 2 + 1);
      textEl.setAttribute("dominant-baseline", "central");
      textEl.setAttribute("font-size", fontSize);
      textEl.setAttribute("fill", isHeader ? "#ffffff" : (ci === 0 ? "#374151" : "#1e293b"));
      if (isHeader || row.type === "net" || ci === 0) textEl.setAttribute("font-weight", "600");
      if (row.type === "mean") textEl.setAttribute("font-style", "italic");
      // Truncate long text to fit column
      var maxChars = Math.floor((ci === 0 ? firstColW : dataColW) / (fontSize * 0.55));
      textEl.textContent = cellText.length > maxChars ? cellText.substring(0, maxChars - 1) + "\u2026" : cellText;
      svgParent.appendChild(textEl);
    });

    // Row border
    var borderLine = document.createElementNS(ns, "line");
    borderLine.setAttribute("x1", x); borderLine.setAttribute("x2", x + maxWidth);
    borderLine.setAttribute("y1", curY + rH); borderLine.setAttribute("y2", curY + rH);
    borderLine.setAttribute("stroke", "#e2e8f0"); borderLine.setAttribute("stroke-width", "0.5");
    svgParent.appendChild(borderLine);

    curY += rH;
  });

  return curY - y;
}

function exportSlidePNG(qCode, mode) {
  mode = mode || "chart";
  var container = document.querySelector(".question-container.active");
  if (!container) return;
  var wrapper = container.querySelector(".chart-wrapper");
  // Close the menu
  document.querySelectorAll(".slide-menu").forEach(function(m) { m.style.display = "none"; });

  var ns = "http://www.w3.org/2000/svg";
  var W = 1280, fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
  var pad = 28;
  var usableW = W - pad * 2;

  var qTitle = wrapper ? wrapper.getAttribute("data-q-title") || "" : "";
  var qCodeLabel = wrapper ? wrapper.getAttribute("data-q-code") || qCode : qCode;

  // Gather base, banner, metrics, insight
  var baseText = "";
  var baseRow = container.querySelector("tr.ct-row-base");
  if (baseRow) {
    var baseCells = baseRow.querySelectorAll("td:not([style*=none])");
    if (baseCells.length > 1) baseText = "Base: n=" + baseCells[1].textContent.trim();
  }

  // Banner name
  var bannerLabel = "";
  var activeBannerTab = document.querySelector(".banner-tab.active");
  if (activeBannerTab) bannerLabel = activeBannerTab.textContent.trim();

  var metrics = [];
  container.querySelectorAll("tr.ct-row-mean").forEach(function(row) {
    var labelCell = row.querySelector("td.ct-label-col");
    var dataCells = row.querySelectorAll("td:not(.ct-label-col):not([style*=none])");
    if (labelCell && dataCells.length > 0) {
      var label = labelCell.textContent.trim();
      var val = dataCells[0].textContent.trim().split("\n")[0].trim();
      if (val && val !== "-") metrics.push(label + ": " + val);
    }
  });
  try {
    if (wrapper) {
      var chartDataStr = wrapper.getAttribute("data-chart-data");
      if (chartDataStr) {
        var cd = JSON.parse(chartDataStr);
        if (cd.priority_metric && cd.priority_metric.label) {
          var pmL = cd.priority_metric.label.toLowerCase();
          metrics = metrics.filter(function(m) { return m.toLowerCase().indexOf(pmL) !== 0; });
        }
      }
    }
  } catch(e) {}

  var insightText = "";
  var insightEditor = container.querySelector(".insight-editor");
  if (insightEditor) insightText = insightEditor.textContent.trim();

  // ---- Layout calculations ----
  var titleFullText = qCodeLabel + " - " + qTitle;
  var titleLines = wrapTextLines(titleFullText, usableW, 9.5);
  var titleLineH = 20;
  var titleStartY = pad + 16;
  var titleBlockH = titleLines.length * titleLineH;

  var metaText = [baseText, bannerLabel ? "Banner: " + bannerLabel : ""].filter(function(s) { return s; }).join(" \u00B7 ");
  var metaY = titleStartY + titleBlockH + 4;
  var contentTop = metaY + 18;

  // Determine content area dimensions based on mode
  var showChart = mode === "chart" || mode === "chart_table";
  var showTable = mode === "table" || mode === "chart_table";

  var chartSvg = wrapper ? wrapper.querySelector("svg") : null;
  var tableData = showTable ? extractSlideTableData(container) : null;

  // Content layout
  var contentH = 0;
  var chartClone, chartVB, chartOrigW, chartOrigH, chartScale, chartDisplayH;
  var chartAreaW, tableAreaW, chartX, tableX;

  if (mode === "chart_table" && chartSvg && tableData) {
    // Side by side: table left, chart right
    tableAreaW = Math.floor(usableW * 0.48);
    chartAreaW = usableW - tableAreaW - 16;
    tableX = pad;
    chartX = pad + tableAreaW + 16;

    chartClone = chartSvg.cloneNode(true);
    chartVB = chartClone.getAttribute("viewBox").split(" ").map(Number);
    chartOrigW = chartVB[2]; chartOrigH = chartVB[3];
    chartScale = chartAreaW / chartOrigW;
    chartDisplayH = chartOrigH * chartScale;

    var tableH = tableData.length * 18 + 4;
    contentH = Math.max(chartDisplayH, tableH);
  } else if (showChart && chartSvg) {
    chartClone = chartSvg.cloneNode(true);
    chartVB = chartClone.getAttribute("viewBox").split(" ").map(Number);
    chartOrigW = chartVB[2]; chartOrigH = chartVB[3];
    chartScale = usableW / chartOrigW;
    chartDisplayH = chartOrigH * chartScale;
    chartX = pad;
    chartAreaW = usableW;
    contentH = chartDisplayH;
  } else if (showTable && tableData) {
    tableX = pad;
    tableAreaW = usableW;
    contentH = tableData.length * 18 + 4;
  } else {
    return;
  }

  var metricsY = contentTop + contentH + 12;
  var metricsH = metrics.length > 0 ? 28 : 0;

  var insightLines = wrapTextLines(insightText, usableW - 16, 7);
  var insightLineH = 17;
  var insightY = metricsY + metricsH + (metricsH > 0 ? 8 : 0);
  var insightBlockH = insightLines.length > 0 ? insightLines.length * insightLineH + 10 : 0;

  var totalH = insightY + insightBlockH + pad;

  // ---- Build slide SVG ----
  var svg = document.createElementNS(ns, "svg");
  svg.setAttribute("xmlns", ns);
  svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
  svg.setAttribute("style", "font-family:" + fontFamily + ";");

  var bg = document.createElementNS(ns, "rect");
  bg.setAttribute("width", W); bg.setAttribute("height", totalH);
  bg.setAttribute("fill", "#ffffff");
  svg.appendChild(bg);

  // Title
  var titleResult = createWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
    { fill: "#1a2744", "font-size": "16", "font-weight": "700" });
  svg.appendChild(titleResult.element);

  // Meta (base + banner)
  var metaEl = document.createElementNS(ns, "text");
  metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
  metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "11");
  metaEl.textContent = metaText;
  svg.appendChild(metaEl);

  // Table
  if (showTable && tableData) {
    renderTableSVG(ns, svg, tableData, tableX, contentTop, tableAreaW);
  }

  // Chart
  if (showChart && chartClone) {
    var chartG = document.createElementNS(ns, "g");
    chartG.setAttribute("transform", "translate(" + chartX + "," + contentTop + ") scale(" + chartScale + ")");
    while (chartClone.firstChild) chartG.appendChild(chartClone.firstChild);
    svg.appendChild(chartG);
  }

  // Metrics strip
  if (metrics.length > 0) {
    var mLine = document.createElementNS(ns, "line");
    mLine.setAttribute("x1", pad); mLine.setAttribute("x2", W - pad);
    mLine.setAttribute("y1", metricsY); mLine.setAttribute("y2", metricsY);
    mLine.setAttribute("stroke", "#e2e8f0"); mLine.setAttribute("stroke-width", "1");
    svg.appendChild(mLine);
    var mText = document.createElementNS(ns, "text");
    mText.setAttribute("x", pad); mText.setAttribute("y", metricsY + 16);
    mText.setAttribute("fill", "#5c4a2a"); mText.setAttribute("font-size", "11");
    mText.setAttribute("font-weight", "600");
    mText.textContent = metrics.join("  |  ");
    svg.appendChild(mText);
  }

  // Insight
  if (insightLines.length > 0) {
    var iLine = document.createElementNS(ns, "line");
    iLine.setAttribute("x1", pad); iLine.setAttribute("x2", W - pad);
    iLine.setAttribute("y1", insightY); iLine.setAttribute("y2", insightY);
    iLine.setAttribute("stroke", "#e2e8f0"); iLine.setAttribute("stroke-width", "1");
    svg.appendChild(iLine);
    var accentH = Math.max(24, insightLines.length * insightLineH);
    var iBar = document.createElementNS(ns, "rect");
    iBar.setAttribute("x", pad); iBar.setAttribute("y", insightY + 4);
    iBar.setAttribute("width", "3"); iBar.setAttribute("height", accentH);
    iBar.setAttribute("fill", "#323367"); iBar.setAttribute("rx", "1.5");
    svg.appendChild(iBar);
    var insResult = createWrappedText(ns, insightLines, pad + 12, insightY + 18, insightLineH,
      { fill: "#374151", "font-size": "12", "font-style": "italic" });
    svg.appendChild(insResult.element);
  }

  // ---- Render SVG to PNG at 3x ----
  var scale = 3;
  var svgData = new XMLSerializer().serializeToString(svg);
  var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
  var url = URL.createObjectURL(svgBlob);

  var img = new Image();
  img.onload = function() {
    var canvas = document.createElement("canvas");
    canvas.width = W * scale;
    canvas.height = totalH * scale;
    var ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    URL.revokeObjectURL(url);
    canvas.toBlob(function(blob) {
      var suffix = mode === "chart" ? "_chart" : (mode === "table" ? "_table" : "");
      downloadBlob(blob, qCode + "_slide" + suffix + ".png");
    }, "image/png");
  };
  img.src = url;
}

// ---- Export All Insights as Standalone HTML ----
// Exports ALL insights across ALL banners, grouped by question
function exportInsightsHTML() {
  // First sync current editor text into stores
  syncAllInsights();

  var insights = [];
  document.querySelectorAll(".insight-area").forEach(function(area) {
    var storeObj = getInsightStore(area);
    var bannerKeys = Object.keys(storeObj);
    if (bannerKeys.length === 0) return;
    var qCode = area.getAttribute("data-q-code") || "";
    var container = area.closest(".question-container");
    var wrapper = container ? container.querySelector(".chart-wrapper") : null;
    var qTitle = wrapper ? wrapper.getAttribute("data-q-title") : "";
    bannerKeys.forEach(function(banner) {
      if (storeObj[banner] && storeObj[banner].trim()) {
        insights.push({ code: qCode, title: qTitle, banner: banner, text: storeObj[banner].trim() });
      }
    });
  });

  if (insights.length === 0) {
    alert("No insights to export. Add insights to questions first.");
    return;
  }

  var projectTitle = document.querySelector(".header-title");
  var pTitle = projectTitle ? projectTitle.textContent : "Report";
  var now = new Date().toLocaleDateString();

  var html = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\">";
  html += "<title>Insights - " + pTitle + "</title>";
  html += "<style>";
  html += "body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;max-width:800px;margin:40px auto;padding:0 20px;color:#1e293b;line-height:1.6;}";
  html += "h1{font-size:20px;margin-bottom:4px;}";
  html += ".meta{color:#64748b;font-size:12px;margin-bottom:32px;}";
  html += ".insight{margin-bottom:24px;padding:16px;border-left:3px solid #323367;background:#f8f9fb;border-radius:0 6px 6px 0;}";
  html += ".q-code{font-weight:700;color:#323367;font-size:13px;}";
  html += ".q-title{font-size:13px;color:#64748b;margin-bottom:8px;}";
  html += ".banner-label{font-size:11px;color:#94a3b8;font-style:italic;margin-bottom:6px;}";
  html += ".q-text{font-size:14px;}";
  html += "@media print{body{margin:20px;}.insight{break-inside:avoid;}}";
  html += "</style></head><body>";
  html += "<h1>Key Insights</h1>";
  html += "<div class=\"meta\">" + pTitle + " &middot; " + now + " &middot; " + insights.length + " insight" + (insights.length > 1 ? "s" : "") + "</div>";

  insights.forEach(function(item) {
    html += "<div class=\"insight\">";
    html += "<div class=\"q-code\">" + escapeHtml(item.code) + "</div>";
    html += "<div class=\"q-title\">" + escapeHtml(item.title) + "</div>";
    html += "<div class=\"banner-label\">Banner: " + escapeHtml(item.banner) + "</div>";
    html += "<div class=\"q-text\">" + escapeHtml(item.text) + "</div>";
    html += "</div>";
  });

  html += "</body></html>";

  var blob = new Blob([html], { type: "text/html;charset=utf-8" });
  downloadBlob(blob, "Insights_" + pTitle.replace(/[^a-zA-Z0-9]/g, "_") + ".html");
}

