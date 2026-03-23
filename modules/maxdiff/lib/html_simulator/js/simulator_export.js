/**
 * TURAS MaxDiff Simulator Export v2.1
 * PNG export (SVG -> 3x canvas), Excel XML, CSV, copy-to-clipboard
 */

var SimExport = (function() {

  var SCALE = 3;
  var WIDTH = 1280;
  var FONT = "Inter,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";

  // --- Gather tab data (shared by PNG, clipboard, etc.) ---

  function gatherTabData(tabId) {
    var data = SimEngine.getData();
    if (!data) return null;

    var result = { data: data, title: data.project_name || "MaxDiff" };

    if (tabId === "shares") {
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-shares") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-shares") : null;
      var shares = SimEngine.computeShares(segFilter);
      var hiddenItems = window.SimUI ? window.SimUI.getHiddenItems() : {};

      if (Object.keys(hiddenItems).length > 0) {
        var visible = shares.filter(function(s) { return !hiddenItems[s.itemId]; });
        var total = visible.reduce(function(sum, s) { return sum + s.share; }, 0);
        if (total > 0) visible.forEach(function(s) { s.share = (s.share / total) * 100; });
        shares = visible;
      }
      shares.sort(function(a, b) { return b.share - a.share; });

      result.type = "shares";
      result.shares = shares;
      result.subtitle = "Preference Shares" + (segLabel ? " \u2014 " + segLabel : "");
      result.segLabel = segLabel;

    } else if (tabId === "h2h") {
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-h2h") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-h2h") : null;
      var slots = window.SimUI ? window.SimUI.getH2HSlots() : [];
      var results = [];
      for (var i = 0; i < slots.length; i++) {
        if (slots[i].idA && slots[i].idB && slots[i].idA !== slots[i].idB) {
          results.push(SimEngine.headToHead(slots[i].idA, slots[i].idB, segFilter));
        }
      }

      result.type = "h2h";
      result.comparisons = results;
      result.subtitle = "Head-to-Head" + (segLabel ? " \u2014 " + segLabel : "");
      result.segLabel = segLabel;

    } else if (tabId === "portfolio") {
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-turf") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-turf") : null;
      var checks = document.querySelectorAll(".sim-portfolio-check");
      var selected = [];
      checks.forEach(function(cb) { if (cb.checked) selected.push(cb.value); });
      var topK = window.SimUI ? window.SimUI.getTopK() : 3;
      var reach = SimEngine.turfReach(selected, topK, segFilter);

      var itemLabels = {};
      data.items.forEach(function(it) { itemLabels[it.id] = it.label; });
      var labels = selected.map(function(id) { return itemLabels[id] || id; });

      // Get per-item reach from optimization results if available
      var optEl = document.getElementById("turf-opt-result");
      var optItems = [];
      if (optEl) {
        var lis = optEl.querySelectorAll("li");
        lis.forEach(function(li) { optItems.push(li.textContent); });
      }

      result.type = "portfolio";
      result.reach = reach;
      result.labels = labels;
      result.selectedIds = selected;
      result.topK = topK;
      result.segLabel = segLabel;
      result.subtitle = "Portfolio (TURF)" + (segLabel ? " \u2014 " + segLabel : "");
      result.optItems = optItems;
    }

    return result;
  }

  /**
   * Export current tab as PNG
   * @param {string} tabId - "shares", "h2h", "portfolio"
   */
  function exportPNG(tabId) {
    var td = gatherTabData(tabId);
    if (!td) return;

    var svgContent = "";
    var height = 400;

    if (td.type === "shares") {
      svgContent = buildSharesSVG(td.shares, td.title, td.subtitle, td.data.brand_colour);
      height = 100 + td.shares.length * 36 + 60;

    } else if (td.type === "h2h") {
      svgContent = buildH2HSVG(td.comparisons, td.title, td.subtitle, td.data.brand_colour);
      height = 100 + td.comparisons.length * 90 + 60;

    } else if (td.type === "portfolio") {
      svgContent = buildTurfSVG(td.reach, td.labels, td.title, td.subtitle, td.data.brand_colour, td.segLabel, td.topK);
      height = 380 + td.labels.length * 28 + 60;
    }

    renderSVGToPNG(svgContent, WIDTH, Math.max(height, 300), tabId);
  }

  /**
   * Export a pinned card as PNG
   */
  function exportPinPNG(pinId) {
    var cardEl = document.querySelector('.sim-pin-card[data-pin-id="' + pinId + '"]');
    if (!cardEl) return;

    var data = SimEngine.getData();
    var brand = (data && data.brand_colour) || "#1e3a5f";
    var titleEl = cardEl.querySelector(".sim-pin-card-title");
    var title = titleEl ? titleEl.textContent : "Pinned View";

    var bodyEl = cardEl.querySelector(".sim-pin-card-body");
    var bodyHtml = bodyEl ? bodyEl.innerHTML : "";

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + WIDTH + '" height="600">' +
      '<rect width="100%" height="100%" fill="white"/>' +
      '<rect x="0" y="0" width="100%" height="56" fill="' + brand + '"/>' +
      '<text x="32" y="36" font-family="' + FONT + '" font-size="20" font-weight="600" fill="white">' + escSvg(title) + '</text>' +
      '<text x="' + (WIDTH - 32) + '" y="36" font-family="' + FONT + '" font-size="12" fill="rgba(255,255,255,0.7)" text-anchor="end">TURAS MaxDiff Simulator</text>' +
      '<foreignObject x="24" y="72" width="' + (WIDTH - 48) + '" height="500">' +
        '<div xmlns="http://www.w3.org/1999/xhtml" style="font-family:' + FONT + ';font-size:14px;color:#1e293b;line-height:1.5">' +
          bodyHtml +
        '</div>' +
      '</foreignObject>' +
    '</svg>';

    renderSVGToPNG(svg, WIDTH, 600, "pin-" + pinId);
  }

  /**
   * Copy tab data to clipboard as formatted text
   * @param {string} tabId
   */
  function copyToClipboard(tabId) {
    var td = gatherTabData(tabId);
    if (!td) return;

    var text = "";

    if (td.type === "shares") {
      text = td.title + " \u2014 " + td.subtitle + "\n\n";
      td.shares.forEach(function(s, i) {
        text += (i + 1) + ". " + s.label + ": " + s.share.toFixed(1) + "%\n";
      });

    } else if (td.type === "h2h") {
      text = td.title + " \u2014 " + td.subtitle + "\n\n";
      td.comparisons.forEach(function(r) {
        text += r.itemA + " (" + r.probA + "%) vs " + r.itemB + " (" + r.probB + "%)\n";
      });

    } else if (td.type === "portfolio") {
      text = td.title + " \u2014 " + td.subtitle + "\n\n";
      text += "Reach: " + td.reach.reach + "%\n";
      text += "Respondents reached: " + td.reach.nReached + " / " + td.reach.nTotal + "\n";
      text += "Avg frequency: " + td.reach.frequency + " items\n";
      if (td.segLabel) text += "Segment: " + td.segLabel + "\n";
      text += "Top-K threshold: " + td.topK + "\n\n";
      text += "Optimal portfolio (" + td.labels.length + " items):\n";
      td.labels.forEach(function(l, i) {
        text += "  " + (i + 1) + ". " + l + "\n";
      });
    }

    // Try modern clipboard API first, fall back to textarea hack
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).catch(function() {
        fallbackCopy(text);
      });
    } else {
      fallbackCopy(text);
    }
  }

  function fallbackCopy(text) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); } catch(e) {}
    document.body.removeChild(ta);
  }

  /**
   * Export shares data as Excel XML
   */
  function exportExcel(tabId) {
    var data = SimEngine.getData();
    if (!data) return;

    if (tabId === "shares") {
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-shares") : null;
      var shares = SimEngine.computeShares(segFilter);
      shares.sort(function(a, b) { return b.share - a.share; });

      var matrix = SimEngine.segmentComparisonMatrix();
      if (matrix) {
        exportExcelXML(buildSegmentExcelData(matrix), "MaxDiff_Shares");
      } else {
        var rows = [["Item", "Share (%)"]];
        shares.forEach(function(s) { rows.push([s.label, Math.round(s.share * 10) / 10]); });
        exportExcelXML(rows, "MaxDiff_Shares");
      }
    } else if (tabId === "h2h") {
      var slots = window.SimUI ? window.SimUI.getH2HSlots() : [];
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-h2h") : null;
      var rows = [["Item A", "Item B", "Prob A (%)", "Prob B (%)"]];
      slots.forEach(function(slot) {
        if (slot.idA && slot.idB && slot.idA !== slot.idB) {
          var r = SimEngine.headToHead(slot.idA, slot.idB, segFilter);
          rows.push([r.itemA, r.itemB, r.probA, r.probB]);
        }
      });
      exportExcelXML(rows, "MaxDiff_HeadToHead");
    } else if (tabId === "portfolio") {
      var checks = document.querySelectorAll(".sim-portfolio-check");
      var selected = [];
      checks.forEach(function(cb) { if (cb.checked) selected.push(cb.value); });
      var topK = window.SimUI ? window.SimUI.getTopK() : 3;
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-turf") : null;
      var reach = SimEngine.turfReach(selected, topK, segFilter);

      var itemLabels = {};
      data.items.forEach(function(it) { itemLabels[it.id] = it.label; });

      var rows = [["Metric", "Value"]];
      rows.push(["Reach (%)", reach.reach]);
      rows.push(["Respondents Reached", reach.nReached + " / " + reach.nTotal]);
      rows.push(["Avg Frequency", reach.frequency]);
      rows.push(["Top-K", topK]);
      rows.push(["", ""]);
      rows.push(["Selected Items", ""]);
      selected.forEach(function(id) { rows.push([itemLabels[id] || id, ""]); });
      exportExcelXML(rows, "MaxDiff_TURF");
    }
  }

  // --- SVG Builders ---

  function buildSharesSVG(shares, title, subtitle, brand) {
    brand = brand || "#1e3a5f";
    var barHeight = 28;
    var gap = 8;
    var labelWidth = 200;
    var barStart = labelWidth + 10;
    var barMaxWidth = WIDTH - barStart - 120;
    var maxVal = shares.length > 0 ? shares[0].share : 1;
    if (maxVal <= 0) maxVal = 1;

    var y = 0;
    var svg = headerSVG(title, subtitle, brand);
    y = 80;

    for (var i = 0; i < shares.length; i++) {
      var s = shares[i];
      var w = Math.max(4, (s.share / maxVal) * barMaxWidth);

      svg += '<text x="' + (labelWidth) + '" y="' + (y + barHeight / 2 + 4) + '" font-family="' + FONT + '" font-size="12" font-weight="500" fill="#334155" text-anchor="end">' + escSvg(s.label) + '</text>';
      svg += '<rect x="' + barStart + '" y="' + y + '" width="' + w + '" height="' + barHeight + '" rx="4" fill="' + brand + '"/>';
      svg += '<text x="' + (barStart + w + 8) + '" y="' + (y + barHeight / 2 + 4) + '" font-family="' + FONT + '" font-size="12" font-weight="600" fill="#334155">' + s.share.toFixed(1) + '%</text>';

      y += barHeight + gap;
    }

    y += 20;
    svg += footerSVG(y);
    var totalHeight = y + 30;

    return wrapSVG(svg, totalHeight);
  }

  function buildH2HSVG(results, title, subtitle, brand) {
    brand = brand || "#1e3a5f";
    var y = 80;
    var svg = headerSVG(title, subtitle, brand);
    var barWidth = WIDTH - 120;

    for (var i = 0; i < results.length; i++) {
      var r = results[i];
      var wA = (r.probA / 100) * barWidth;

      svg += '<text x="60" y="' + y + '" font-family="' + FONT + '" font-size="12" font-weight="500" fill="#475569">' + escSvg(r.itemA) + ' vs ' + escSvg(r.itemB) + '</text>';
      y += 8;

      svg += '<rect x="60" y="' + y + '" width="' + wA + '" height="36" rx="4" fill="' + brand + '"/>';
      svg += '<rect x="' + (60 + wA) + '" y="' + y + '" width="' + (barWidth - wA) + '" height="36" rx="4" fill="#e74c3c"/>';
      svg += '<text x="' + (60 + wA / 2) + '" y="' + (y + 22) + '" font-family="' + FONT + '" font-size="14" font-weight="700" fill="white" text-anchor="middle">' + r.probA + '%</text>';
      svg += '<text x="' + (60 + wA + (barWidth - wA) / 2) + '" y="' + (y + 22) + '" font-family="' + FONT + '" font-size="14" font-weight="700" fill="white" text-anchor="middle">' + r.probB + '%</text>';

      y += 36;
      svg += '<text x="60" y="' + (y + 14) + '" font-family="' + FONT + '" font-size="11" fill="#64748b">' + escSvg(r.itemA) + '</text>';
      svg += '<text x="' + (60 + barWidth) + '" y="' + (y + 14) + '" font-family="' + FONT + '" font-size="11" fill="#64748b" text-anchor="end">' + escSvg(r.itemB) + '</text>';
      y += 30;
    }

    y += 20;
    svg += footerSVG(y);
    return wrapSVG(svg, y + 30);
  }

  /**
   * Build visual TURF export SVG — donut ring chart with reach %,
   * respondent counts, avg frequency, segment label, and numbered portfolio list.
   */
  function buildTurfSVG(reach, labels, title, subtitle, brand, segLabel, topK) {
    brand = brand || "#1e3a5f";
    var svg = headerSVG(title, subtitle, brand);

    // --- Layout constants ---
    var donutCx = 200;       // Centre of donut
    var donutCy = 230;       // Centre of donut
    var donutR = 90;         // Outer radius
    var donutStroke = 20;    // Ring thickness
    var trackR = donutR;     // Track radius
    var infoX = 380;         // Left edge of info panel
    var listX = 380;         // Left edge of portfolio list

    // --- Donut ring ---
    // Background track
    svg += '<circle cx="' + donutCx + '" cy="' + donutCy + '" r="' + trackR + '" fill="none" stroke="#e2e8f0" stroke-width="' + donutStroke + '"/>';

    // Fill arc
    var pct = Math.min(reach.reach, 100);
    var angle = (pct / 100) * 360;

    if (pct >= 99.9) {
      // Full circle
      svg += '<circle cx="' + donutCx + '" cy="' + donutCy + '" r="' + trackR + '" fill="none" stroke="' + brand + '" stroke-width="' + donutStroke + '"/>';
    } else if (pct > 0) {
      var rad = ((angle - 90) * Math.PI) / 180;
      var large = angle > 180 ? 1 : 0;
      var ex = donutCx + trackR * Math.cos(rad);
      var ey = donutCy + trackR * Math.sin(rad);
      var startX = donutCx;
      var startY = donutCy - trackR;
      svg += '<path d="M ' + startX + ' ' + startY + ' A ' + trackR + ' ' + trackR + ' 0 ' + large + ' 1 ' + ex.toFixed(1) + ' ' + ey.toFixed(1) + '" fill="none" stroke="' + brand + '" stroke-width="' + donutStroke + '" stroke-linecap="round"/>';
    }

    // Centre text — big reach %
    svg += '<text x="' + donutCx + '" y="' + (donutCy - 8) + '" font-family="' + FONT + '" font-size="42" font-weight="700" fill="' + brand + '" text-anchor="middle" dominant-baseline="middle">' + reach.reach + '%</text>';
    svg += '<text x="' + donutCx + '" y="' + (donutCy + 22) + '" font-family="' + FONT + '" font-size="14" font-weight="500" fill="#64748b" text-anchor="middle">reach</text>';

    // --- Info panel (right of donut) ---
    var infoY = donutCy - 50;

    // Respondents reached
    svg += '<text x="' + infoX + '" y="' + infoY + '" font-family="' + FONT + '" font-size="24" font-weight="700" fill="' + brand + '">' + reach.nReached + '/' + reach.nTotal + '</text>';
    infoY += 22;
    svg += '<text x="' + infoX + '" y="' + infoY + '" font-family="' + FONT + '" font-size="13" fill="#64748b">respondents reached</text>';
    infoY += 36;

    // Avg frequency
    svg += '<text x="' + infoX + '" y="' + infoY + '" font-family="' + FONT + '" font-size="24" font-weight="700" fill="' + brand + '">' + reach.frequency + '</text>';
    infoY += 22;
    svg += '<text x="' + infoX + '" y="' + infoY + '" font-family="' + FONT + '" font-size="13" fill="#64748b">avg items per respondent</text>';
    infoY += 36;

    // Segment label
    if (segLabel) {
      svg += '<rect x="' + infoX + '" y="' + (infoY - 14) + '" width="' + (segLabel.length * 8 + 24) + '" height="26" rx="13" fill="' + brand + '" opacity="0.1"/>';
      svg += '<text x="' + (infoX + 12) + '" y="' + (infoY + 2) + '" font-family="' + FONT + '" font-size="12" font-weight="600" fill="' + brand + '">Segment: ' + escSvg(segLabel) + '</text>';
      infoY += 32;
    }

    // Top-K info
    if (topK) {
      svg += '<text x="' + infoX + '" y="' + infoY + '" font-family="' + FONT + '" font-size="12" fill="#94a3b8">Top-K threshold: ' + topK + '</text>';
    }

    // --- Divider line ---
    var divY = donutCy + donutR + 40;
    svg += '<line x1="60" y1="' + divY + '" x2="' + (WIDTH - 60) + '" y2="' + divY + '" stroke="#e2e8f0" stroke-width="1"/>';

    // --- Portfolio list ---
    var listY = divY + 32;
    svg += '<text x="' + 60 + '" y="' + listY + '" font-family="' + FONT + '" font-size="15" font-weight="600" fill="#1e293b">Optimal portfolio (' + labels.length + ' items)</text>';
    listY += 12;

    // Two-column layout for the portfolio items
    var colWidth = (WIDTH - 120) / 2;
    var itemHeight = 28;
    var col1X = 80;
    var col2X = 80 + colWidth;
    var halfCount = Math.ceil(labels.length / 2);

    for (var i = 0; i < labels.length; i++) {
      var col = i < halfCount ? 0 : 1;
      var row = col === 0 ? i : i - halfCount;
      var ix = col === 0 ? col1X : col2X;
      var iy = listY + row * itemHeight + 20;

      // Number badge
      var badgeX = ix;
      var badgeY = iy - 4;
      svg += '<rect x="' + badgeX + '" y="' + (badgeY - 12) + '" width="22" height="22" rx="11" fill="' + brand + '"/>';
      svg += '<text x="' + (badgeX + 11) + '" y="' + (badgeY + 1) + '" font-family="' + FONT + '" font-size="11" font-weight="600" fill="white" text-anchor="middle">' + (i + 1) + '</text>';

      // Item label
      svg += '<text x="' + (ix + 32) + '" y="' + iy + '" font-family="' + FONT + '" font-size="13" fill="#334155">' + escSvg(labels[i]) + '</text>';
    }

    var listEndY = listY + halfCount * itemHeight + 30;

    listEndY += 10;
    svg += footerSVG(listEndY);
    return wrapSVG(svg, listEndY + 30);
  }

  function headerSVG(title, subtitle, brand) {
    return '<rect x="0" y="0" width="' + WIDTH + '" height="56" rx="0" fill="' + brand + '"/>' +
      '<text x="32" y="28" font-family="' + FONT + '" font-size="18" font-weight="600" fill="white" dominant-baseline="middle">' + escSvg(title) + '</text>' +
      '<text x="32" y="48" font-family="' + FONT + '" font-size="12" fill="rgba(255,255,255,0.8)">' + escSvg(subtitle) + '</text>' +
      '<text x="' + (WIDTH - 32) + '" y="28" font-family="' + FONT + '" font-size="11" fill="rgba(255,255,255,0.6)" text-anchor="end" dominant-baseline="middle">TURAS MaxDiff Simulator</text>';
  }

  function footerSVG(y) {
    return '<line x1="32" y1="' + y + '" x2="' + (WIDTH - 32) + '" y2="' + y + '" stroke="#e2e8f0" stroke-width="1"/>' +
      '<text x="' + (WIDTH / 2) + '" y="' + (y + 18) + '" font-family="' + FONT + '" font-size="10" fill="#94a3b8" text-anchor="middle">Generated by TURAS MaxDiff Simulator v2.0</text>';
  }

  function wrapSVG(content, height) {
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + WIDTH + '" height="' + height + '" viewBox="0 0 ' + WIDTH + ' ' + height + '">' +
      '<rect width="100%" height="100%" fill="white"/>' +
      content +
    '</svg>';
  }

  // --- Render SVG to PNG ---

  function renderSVGToPNG(svgString, width, height, filename) {
    var canvas = document.createElement("canvas");
    canvas.width = width * SCALE;
    canvas.height = height * SCALE;
    var ctx = canvas.getContext("2d");
    ctx.scale(SCALE, SCALE);

    var img = new Image();
    var blob = new Blob([svgString], {type: "image/svg+xml;charset=utf-8"});
    var url = URL.createObjectURL(blob);

    img.onload = function() {
      ctx.drawImage(img, 0, 0, width, height);
      URL.revokeObjectURL(url);

      canvas.toBlob(function(pngBlob) {
        var a = document.createElement("a");
        a.href = URL.createObjectURL(pngBlob);
        a.download = (filename || "export") + ".png";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(a.href);
      }, "image/png");
    };

    img.onerror = function() {
      URL.revokeObjectURL(url);
      console.error("Failed to render SVG to PNG");
    };

    img.src = url;
  }

  // --- Excel XML ---

  function exportExcelXML(rows, filename) {
    var xml = '<?xml version="1.0"?>\n' +
      '<?mso-application progid="Excel.Sheet"?>\n' +
      '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n' +
      ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n' +
      '<Styles>\n' +
      '  <Style ss:ID="header"><Font ss:Bold="1" ss:Size="11"/><Interior ss:Color="#1e3a5f" ss:Pattern="Solid"/><Font ss:Color="#FFFFFF" ss:Bold="1"/></Style>\n' +
      '  <Style ss:ID="data"><Font ss:Size="11"/></Style>\n' +
      '</Styles>\n' +
      '<Worksheet ss:Name="Data">\n' +
      '<Table>\n';

    for (var r = 0; r < rows.length; r++) {
      var style = r === 0 ? ' ss:StyleID="header"' : ' ss:StyleID="data"';
      xml += '<Row' + style + '>\n';
      for (var c = 0; c < rows[r].length; c++) {
        var val = rows[r][c];
        var type = (typeof val === "number") ? "Number" : "String";
        xml += '  <Cell><Data ss:Type="' + type + '">' + escXml(String(val)) + '</Data></Cell>\n';
      }
      xml += '</Row>\n';
    }

    xml += '</Table>\n</Worksheet>\n</Workbook>';

    downloadFile(xml, (filename || "export") + ".xls", "application/vnd.ms-excel");
  }

  function buildSegmentExcelData(matrix) {
    var header = ["Item"];
    matrix.segments.forEach(function(s) { header.push(s.label); });
    var rows = [header];

    matrix.items.forEach(function(item) {
      var row = [item.label];
      matrix.segments.forEach(function(s) {
        var key = s.key || "all";
        row.push(item.shares[key] || 0);
      });
      rows.push(row);
    });

    return rows;
  }

  function downloadFile(content, filename, mimeType) {
    var blob = new Blob([content], {type: mimeType});
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
  }

  // --- Helpers ---

  function escSvg(str) {
    return (str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function escXml(str) {
    return (str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
  }

  return {
    exportPNG: exportPNG,
    exportPinPNG: exportPinPNG,
    exportExcel: exportExcel,
    copyToClipboard: copyToClipboard
  };
})();
