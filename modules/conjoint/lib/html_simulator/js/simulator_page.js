/**
 * Standalone simulator — page-level glue.
 *
 * The panel markup (01_simulator_parts.R) wires its mode buttons and export
 * buttons to three window-level functions. In the retired combined report
 * those lived in conjoint_navigation.js / conjoint_export.js / cj_pins.js,
 * none of which came across in the extraction — so every button except the
 * default Market Shares mode threw a ReferenceError (C-delta review,
 * finding 1). This file is those entry points, standalone:
 *
 *   switchSimMode()        — carried over from conjoint_navigation.js
 *   exportSimulatorExcel() — carried over from conjoint_export.js
 *   cjExportPNG()          — reimplemented without TurasPins (the pins
 *                            infrastructure is report furniture and stays
 *                            out of the standalone tool by design): it
 *                            renders the active mode's chart SVG to a PNG
 *                            and downloads it.
 */
(function() {

  // === SIMULATOR MODE SWITCH (with callout toggle) ===

  window.switchSimMode = function(mode) {
    document.querySelectorAll(".cj-sim-mode-btn").forEach(function(btn) {
      btn.classList.remove("active");
    });
    var clicked = document.querySelector('.cj-sim-mode-btn[onclick*="' + mode + '"]');
    if (clicked) clicked.classList.add("active");

    document.querySelectorAll(".cj-sim-callout").forEach(function(c) {
      c.classList.remove("active");
    });
    var callout = document.getElementById("cj-sim-callout-" + mode);
    if (callout) callout.classList.add("active");

    if (typeof SimUI !== "undefined") {
      SimUI.switchMode(mode);
    }
  };


  // === DOWNLOAD BLOB UTILITY ===

  window.downloadBlob = function(content, filename, mimeType) {
    var blob = new Blob([content], { type: mimeType || "application/octet-stream" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };


  // === EXCEL EXPORT ===

  function htmlEscape(val) {
    return String(val).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function buildSimulatorExportData() {
    if (typeof SimEngine === "undefined" || typeof SimUI === "undefined") return null;
    var simData = SimEngine.getData();
    if (!simData || !simData.attributes) return null;

    var products = SimUI.getProducts();
    if (!products || products.length === 0) return null;

    var headers = ["Product"];
    simData.attributes.forEach(function(a) { headers.push(a.name); });
    headers.push("Predicted Share (%)");

    // Shares from SimUI state (not the DOM), same as the report's export did.
    var configs = products.map(function(p) { return p.config; });
    var shares = [];
    try {
      shares = SimEngine.predictShares(configs, "logit");
    } catch (e) {
      shares = configs.map(function() { return 0; });
    }

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

  function exportExcelFromData(data, filenameBase) {
    var html = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">';
    html += '<head><meta charset="UTF-8">';
    html += '<!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>';
    html += '<x:Name>Data</x:Name><x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>';
    html += '</x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->';
    html += '<style>td,th{mso-number-format:"\\@";font-family:Calibri,sans-serif;font-size:11pt;}';
    html += 'th{background:#f1f5f9;font-weight:bold;border-bottom:2px solid #ccc;}</style>';
    html += '</head><body>';
    html += '<table border="1" cellspacing="0" cellpadding="4">';

    html += '<tr>';
    data.headers.forEach(function(h) {
      html += '<th>' + htmlEscape(h) + '</th>';
    });
    html += '</tr>';

    data.rows.forEach(function(row) {
      html += '<tr>';
      row.forEach(function(cell) {
        html += '<td>' + htmlEscape(cell) + '</td>';
      });
      html += '</tr>';
    });

    html += '</table></body></html>';

    downloadBlob(html, filenameBase + ".xls", "application/vnd.ms-excel");
  }

  window.exportSimulatorExcel = function() {
    var data = buildSimulatorExportData();
    if (!data) return;
    exportExcelFromData(data, "conjoint_simulator");
  };


  // === PNG EXPORT ===

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

  window.cjExportPNG = function(viewId, btnEl) {
    var host = document.getElementById("cj-sim-results") ||
      document.querySelector(".cj-panel") || document.body;
    var svg = host.querySelector("svg");
    if (!svg) return;

    svgToPNG(svg, 3, function(dataUrl) {
      var a = document.createElement("a");
      a.href = dataUrl;
      a.download = "conjoint_simulator.png";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    });
  };

})();
