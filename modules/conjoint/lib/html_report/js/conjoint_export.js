/**
 * Conjoint Report Export Functions
 * CSV, Excel (XML Spreadsheet), Chart PNG (SVG -> Canvas), Slide PNG.
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

    var csvRows = [];
    csvRows.push(data.headers.map(csvEscape).join(","));
    data.rows.forEach(function(row) {
      csvRows.push(row.map(csvEscape).join(","));
    });

    var csv = csvRows.join("\n");
    var filename = "conjoint_" + panelId + ".csv";
    downloadBlob(csv, filename, "text/csv;charset=utf-8");
  };

  function csvEscape(val) {
    val = String(val);
    if (val.indexOf(",") >= 0 || val.indexOf('"') >= 0 || val.indexOf("\n") >= 0) {
      return '"' + val.replace(/"/g, '""') + '"';
    }
    return val;
  }


  // === EXCEL EXPORT (XML Spreadsheet 2003) ===

  window.exportExcel = function(panelId) {
    var data = extractTableData(panelId);
    if (!data) return;

    var xml = '<?xml version="1.0"?>\n';
    xml += '<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
    xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';
    xml += '<Styles><Style ss:ID="header"><Font ss:Bold="1"/><Interior ss:Color="#f1f5f9" ss:Pattern="Solid"/></Style></Styles>\n';
    xml += '<Worksheet ss:Name="Data"><Table>\n';

    // Headers
    xml += '<Row>';
    data.headers.forEach(function(h) {
      xml += '<Cell ss:StyleID="header"><Data ss:Type="String">' + xmlEscape(h) + '</Data></Cell>';
    });
    xml += '</Row>\n';

    // Data rows
    data.rows.forEach(function(row) {
      xml += '<Row>';
      row.forEach(function(cell) {
        var type = isNaN(parseFloat(cell)) ? "String" : "Number";
        xml += '<Cell><Data ss:Type="' + type + '">' + xmlEscape(cell) + '</Data></Cell>';
      });
      xml += '</Row>\n';
    });

    xml += '</Table></Worksheet></Workbook>';

    var filename = "conjoint_" + panelId + ".xls";
    downloadBlob(xml, filename, "application/vnd.ms-excel");
  };

  function xmlEscape(val) {
    return String(val).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }


  // === CHART PNG EXPORT ===

  window.exportChartPNG = function(panelId) {
    var panel = document.getElementById("panel-" + panelId);
    if (!panel) panel = document.querySelector('.cj-attr-detail.active');
    if (!panel) return;

    var chartWrap = panel.querySelector(".cj-chart-wrap");
    if (!chartWrap) chartWrap = panel.querySelector(".cj-chart-container");
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
    var svg = panel.querySelector("svg");
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
