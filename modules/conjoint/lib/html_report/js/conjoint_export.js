/**
 * Conjoint Report Export Functions
 * CSV, Excel (XML Spreadsheet), Chart PNG (SVG -> Canvas), Slide PNG.
 * Includes simulator-specific export functions.
 */

(function() {
  "use strict";

  // === TABLE DATA EXTRACTION ===

  function extractTableData(panelId) {
    var panel = document.getElementById("panel-" + panelId);
    if (!panel) {
      // Try active attribute detail
      panel = document.querySelector('.cj-attr-detail.active');
    }
    if (!panel) return null;

    var table = panel.querySelector(".cj-table");
    if (!table) return null;

    var headers = [];
    table.querySelectorAll("thead th").forEach(function(th) {
      headers.push(th.textContent.trim());
    });

    var rows = [];
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      var row = [];
      tr.querySelectorAll("td").forEach(function(td) {
        var exportVal = td.getAttribute("data-export-value");
        row.push(exportVal !== null ? exportVal : td.textContent.trim());
      });
      rows.push(row);
    });

    return { headers: headers, rows: rows };
  }


  // === CSV EXPORT ===

  window.exportCSV = function(panelId) {
    var data = extractTableData(panelId);
    if (!data) return;
    exportCSVFromData(data, "conjoint_" + panelId);
  };

  function exportCSVFromData(data, filenameBase) {
    var csvRows = [];
    csvRows.push(data.headers.map(csvEscape).join(","));
    data.rows.forEach(function(row) {
      csvRows.push(row.map(csvEscape).join(","));
    });

    var csv = csvRows.join("\n");
    var filename = filenameBase + ".csv";
    downloadBlob(csv, filename, "text/csv;charset=utf-8");
  }

  function csvEscape(val) {
    val = String(val);
    if (val.indexOf(",") >= 0 || val.indexOf('"') >= 0 || val.indexOf("\n") >= 0) {
      return '"' + val.replace(/"/g, '""') + '"';
    }
    return val;
  }


  // === EXCEL EXPORT (HTML Table format — compatible with Excel, LibreOffice, Numbers) ===

  window.exportExcel = function(panelId) {
    var data = extractTableData(panelId);
    if (!data) return;

    var title = "";
    var filenameBase = "conjoint_" + panelId;

    // For utility panels: read the attribute name from the active detail element
    // so the file is named "conjoint_utility_Brand.xls" and includes a title row
    if (panelId.indexOf("util-") === 0) {
      var detailEl = document.querySelector(".cj-attr-detail.active");
      if (detailEl) {
        var attrName = detailEl.getAttribute("data-attr") ||
          (detailEl.querySelector("h2") ? detailEl.querySelector("h2").textContent.trim() : "");
        if (attrName) {
          title = attrName;
          filenameBase = "conjoint_utility_" + attrName.replace(/[^a-zA-Z0-9]+/g, "_").replace(/^_|_$/g, "");
        }
      }
    }

    exportExcelFromData(data, filenameBase, title);
  };

  function exportExcelFromData(data, filenameBase, title) {
    var html = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">';
    html += '<head><meta charset="UTF-8">';
    html += '<!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>';
    html += '<x:Name>Data</x:Name><x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>';
    html += '</x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->';
    html += '<style>td,th{mso-number-format:"\\@";font-family:Calibri,sans-serif;font-size:11pt;}';
    html += 'th{background:#f1f5f9;font-weight:bold;border-bottom:2px solid #ccc;}</style>';
    html += '</head><body>';
    html += '<table border="1" cellspacing="0" cellpadding="4">';

    // Optional title row spanning all columns
    if (title) {
      var colspan = data.headers.length || 1;
      html += '<tr><th colspan="' + colspan + '" style="background:#323367;color:#ffffff;' +
        'font-size:12pt;text-align:left;border-bottom:2px solid #1e1e5c;">' +
        htmlEscape(title) + '</th></tr>';
    }

    // Headers
    html += '<tr>';
    data.headers.forEach(function(h) {
      html += '<th>' + htmlEscape(h) + '</th>';
    });
    html += '</tr>';

    // Data rows
    data.rows.forEach(function(row) {
      html += '<tr>';
      row.forEach(function(cell) {
        html += '<td>' + htmlEscape(cell) + '</td>';
      });
      html += '</tr>';
    });

    html += '</table></body></html>';

    var filename = filenameBase + ".xls";
    downloadBlob(html, filename, "application/vnd.ms-excel");
  }

  function htmlEscape(val) {
    return String(val).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }


  // === SIMULATOR CSV EXPORT ===

  window.exportSimulatorCSV = function() {
    var data = buildSimulatorExportData();
    if (!data) return;
    exportCSVFromData(data, "conjoint_simulator");
  };


  // === SIMULATOR EXCEL EXPORT ===

  window.exportSimulatorExcel = function() {
    var data = buildSimulatorExportData();
    if (!data) return;
    exportExcelFromData(data, "conjoint_simulator");
  };


  // === BUILD SIMULATOR EXPORT DATA ===

  function buildSimulatorExportData() {
    if (typeof SimEngine === "undefined" || typeof SimUI === "undefined") return null;
    var simData = SimEngine.getData();
    if (!simData || !simData.attributes) return null;

    var products = SimUI.getProducts();
    if (!products || products.length === 0) return null;

    // Build headers: Product Name, Attribute1, Attribute2, ..., Predicted Share (%)
    var headers = ["Product"];
    simData.attributes.forEach(function(a) { headers.push(a.name); });
    headers.push("Predicted Share (%)");

    // Calculate shares using product configs from SimUI state (not DOM)
    var configs = products.map(function(p) { return p.config; });
    var shares = [];
    try {
      shares = SimEngine.predictShares(configs, "logit");
    } catch (e) {
      shares = configs.map(function() { return 0; });
    }

    // Build rows
    var rows = [];
    products.forEach(function(prod, i) {
      var row = [prod.name || ("Product " + (i + 1))];
      simData.attributes.forEach(function(a) {
        row.push(prod.config[a.name] || "");
      });
      row.push(shares[i] !== undefined ? shares[i].toFixed(1) : "");
      rows.push(row);
    });

    return { headers: headers, rows: rows };
  }


  // === CHART PNG EXPORT ===

  window.exportChartPNG = function(panelId) {
    var panel = document.getElementById("panel-" + panelId);
    if (!panel) panel = document.querySelector('.cj-attr-detail.active');
    if (!panel) return;

    // For simulator, look in results div
    if (panelId === "simulator") {
      panel = document.getElementById("cj-sim-results") || panel;
    }

    var chartWrap = panel.querySelector(".cj-chart-wrap");
    if (!chartWrap) chartWrap = panel.querySelector(".cj-chart-container");
    if (!chartWrap) chartWrap = panel; // fallback to panel itself for inline SVGs
    if (!chartWrap) return;

    var svg = chartWrap.querySelector("svg");
    if (!svg) return;

    svgToPNG(svg, 3, function(dataUrl) {
      var a = document.createElement("a");
      a.href = dataUrl;
      a.download = "conjoint_chart_" + panelId + ".png";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    });
  };


  // === SLIDE PNG EXPORT ===

  window.exportSlidePNG = function(panelId) {
    var panel = document.getElementById("panel-" + panelId);
    if (!panel) panel = document.querySelector('.cj-attr-detail.active');
    if (!panel) return;

    // For simulator, look in results div
    var svgSource = panel;
    if (panelId === "simulator") {
      svgSource = document.getElementById("cj-sim-results") || panel;
    }

    // Build a slide-sized SVG (1280x720)
    var slideW = 1280, slideH = 720, scale = 3;
    var canvas = document.createElement("canvas");
    canvas.width = slideW * scale;
    canvas.height = slideH * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);

    // White background
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, slideW, slideH);

    // Header bar
    var brand = getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim() || "#323367";
    ctx.fillStyle = brand;
    ctx.fillRect(0, 0, slideW, 60);
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 20px system-ui, sans-serif";
    ctx.fillText("Turas Conjoint", 24, 38);

    // Title
    var title = panel.querySelector("h2");
    if (title) {
      ctx.fillStyle = "#1e293b";
      ctx.font = "bold 18px system-ui, sans-serif";
      ctx.fillText(title.textContent, 24, 90);
    }

    // Embed chart as image
    var svg = svgSource.querySelector("svg");
    if (svg) {
      var svgData = new XMLSerializer().serializeToString(svg);
      var img = new Image();
      var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
      var url = URL.createObjectURL(blob);

      img.onload = function() {
        var maxW = slideW - 48, maxH = slideH - 140;
        var ratio = Math.min(maxW / img.width, maxH / img.height, 1);
        var drawW = img.width * ratio;
        var drawH = img.height * ratio;
        ctx.drawImage(img, 24, 110, drawW, drawH);
        URL.revokeObjectURL(url);

        // Footer
        ctx.fillStyle = "#94a3b8";
        ctx.font = "10px system-ui, sans-serif";
        ctx.fillText("Generated by TURAS Analytics Platform", 24, slideH - 12);

        canvas.toBlob(function(blob) {
          var a = document.createElement("a");
          a.href = URL.createObjectURL(blob);
          a.download = "conjoint_slide_" + panelId + ".png";
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
        }, "image/png");
      };
      img.src = url;
    } else {
      // No chart - just export header + text
      ctx.fillStyle = "#94a3b8";
      ctx.font = "10px system-ui, sans-serif";
      ctx.fillText("Generated by TURAS Analytics Platform", 24, slideH - 12);
      canvas.toBlob(function(blob) {
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "conjoint_slide_" + panelId + ".png";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      }, "image/png");
    }
  };


  // === SVG TO PNG UTILITY ===

  function svgToPNG(svgElement, scale, callback) {
    scale = scale || 3;
    var svgData = new XMLSerializer().serializeToString(svgElement);
    var canvas = document.createElement("canvas");
    var bbox = svgElement.getBoundingClientRect();
    canvas.width = bbox.width * scale;
    canvas.height = bbox.height * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, bbox.width, bbox.height);

    var img = new Image();
    var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    var url = URL.createObjectURL(blob);

    img.onload = function() {
      ctx.drawImage(img, 0, 0, bbox.width, bbox.height);
      URL.revokeObjectURL(url);
      callback(canvas.toDataURL("image/png"));
    };
    img.onerror = function() {
      URL.revokeObjectURL(url);
      console.warn("Failed to render SVG to PNG");
    };
    img.src = url;
  }

})();
