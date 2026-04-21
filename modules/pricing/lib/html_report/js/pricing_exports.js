/* ===========================================================================
   TURAS PRICING REPORT - Export System
   PNG charts, Excel/CSV tables, slide export, save report
   =========================================================================== */

(function() {
  "use strict";

  // ── Helper: download a blob ──
  function downloadBlob(blob, filename) {
    var url = URL.createObjectURL(blob);
    var link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    setTimeout(function() { URL.revokeObjectURL(url); }, 100);
  }

  // ── Export chart as PNG ──
  window.exportChartPNG = function(sectionId) {
    var panel = document.getElementById("panel-" + sectionId);
    if (!panel) return;

    var svgEl = panel.querySelector("svg");
    if (!svgEl) { alert("No chart found in this section."); return; }

    var svgData = new XMLSerializer().serializeToString(svgEl);
    var canvas = document.createElement("canvas");
    var ctx = canvas.getContext("2d");
    var img = new Image();

    img.onload = function() {
      canvas.width = img.width * 3;
      canvas.height = img.height * 3;
      ctx.scale(3, 3);
      ctx.fillStyle = "white";
      ctx.fillRect(0, 0, img.width, img.height);
      ctx.drawImage(img, 0, 0);
      ctx.font = "9px sans-serif";
      ctx.fillStyle = "#94a3b8";
      ctx.fillText("TURAS Pricing Report", 10, img.height - 6);

      canvas.toBlob(function(blob) {
        downloadBlob(blob, "pricing_" + sectionId + "_chart.png");
      }, "image/png");
    };
    img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
  };

  // ── Extract table data from a section ──
  function extractTableData(sectionId) {
    var panel = document.getElementById("panel-" + sectionId);
    if (!panel) return null;

    var table = panel.querySelector(".pr-table");
    if (!table) return null;

    var rows = table.querySelectorAll("tr");
    var data = [];
    for (var i = 0; i < rows.length; i++) {
      var cells = rows[i].querySelectorAll("th, td");
      var row = [];
      for (var j = 0; j < cells.length; j++) {
        row.push(cells[j].textContent.trim());
      }
      data.push(row);
    }
    return data;
  }

  // ── Export table as CSV ──
  window.exportTableCSV = function(sectionId) {
    var data = extractTableData(sectionId);
    if (!data || data.length === 0) { alert("No table found in this section."); return; }

    var csv = data.map(function(row) {
      return row.map(function(cell) {
        if (cell.indexOf(",") >= 0 || cell.indexOf('"') >= 0 || cell.indexOf("\n") >= 0) {
          return '"' + cell.replace(/"/g, '""') + '"';
        }
        return cell;
      }).join(",");
    }).join("\n");

    var blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" });
    downloadBlob(blob, "pricing_" + sectionId + "_table.csv");
  };

  // ── Export table as Excel XML ──
  window.exportTableExcel = function(sectionId) {
    var data = extractTableData(sectionId);
    if (!data || data.length === 0) { alert("No table found in this section."); return; }

    var xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
    xml += '<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
    xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';
    xml += '<Styles><Style ss:ID="header"><Font ss:Bold="1"/></Style></Styles>\n';
    xml += '<Worksheet ss:Name="Data"><Table>\n';

    for (var i = 0; i < data.length; i++) {
      xml += "<Row>";
      for (var j = 0; j < data[i].length; j++) {
        var val = data[i][j].replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        var style = i === 0 ? ' ss:StyleID="header"' : "";

        // Try numeric detection
        var num = parseFloat(val.replace(/[,$%]/g, ""));
        if (!isNaN(num) && i > 0 && val.match(/^[\d$,.\-%]+$/)) {
          xml += "<Cell" + style + "><Data ss:Type=\"Number\">" + num + "</Data></Cell>";
        } else {
          xml += "<Cell" + style + "><Data ss:Type=\"String\">" + val + "</Data></Cell>";
        }
      }
      xml += "</Row>\n";
    }

    xml += "</Table></Worksheet></Workbook>";
    var blob = new Blob([xml], { type: "application/vnd.ms-excel" });
    downloadBlob(blob, "pricing_" + sectionId + "_table.xls");
  };

  // ── Export section as slide PNG (title + chart + table + insight) ──
  window.exportSlidePNG = function(sectionId) {
    var panel = document.getElementById("panel-" + sectionId);
    if (!panel) return;

    var svgEl = panel.querySelector("svg");
    if (!svgEl) {
      // Fall back to chart PNG export
      exportChartPNG(sectionId);
      return;
    }

    var title = "";
    var h2 = panel.querySelector("h2");
    if (h2) title = h2.textContent.trim();

    var insightText = "";
    var editor = panel.querySelector(".pr-insight-editor");
    if (editor && editor.textContent.trim()) {
      insightText = editor.textContent.trim();
    }

    var svgData = new XMLSerializer().serializeToString(svgEl);
    var canvas = document.createElement("canvas");
    var W = 1200, H = 675; // 16:9 slide
    canvas.width = W;
    canvas.height = H;
    var ctx = canvas.getContext("2d");

    // Background
    ctx.fillStyle = "white";
    ctx.fillRect(0, 0, W, H);

    // Title bar
    var brandColor = getComputedStyle(document.documentElement).getPropertyValue("--pr-brand").trim() || "#323367";
    ctx.fillStyle = brandColor;
    ctx.fillRect(0, 0, W, 56);
    ctx.fillStyle = "white";
    ctx.font = "bold 22px system-ui, sans-serif";
    ctx.fillText(title, 30, 37);

    // Chart
    var chartImg = new Image();
    chartImg.onload = function() {
      var chartW = W - 60;
      var chartH = insightText ? H - 170 : H - 100;
      var scale = Math.min(chartW / chartImg.width, chartH / chartImg.height);
      var cw = chartImg.width * scale;
      var ch = chartImg.height * scale;
      ctx.drawImage(chartImg, (W - cw) / 2, 70, cw, ch);

      // Insight text at bottom
      if (insightText) {
        ctx.fillStyle = "#f8fafc";
        ctx.fillRect(0, H - 80, W, 80);
        ctx.fillStyle = "#475569";
        ctx.font = "13px system-ui, sans-serif";
        // Truncate long text
        var maxLen = 160;
        var displayText = insightText.length > maxLen ? insightText.substring(0, maxLen) + "..." : insightText;
        ctx.fillText(displayText, 30, H - 45);
      }

      // Watermark
      ctx.fillStyle = "#cbd5e1";
      ctx.font = "10px system-ui, sans-serif";
      ctx.fillText("TURAS Pricing Report", W - 150, H - 10);

      canvas.toBlob(function(blob) {
        downloadBlob(blob, "pricing_" + sectionId + "_slide.png");
      }, "image/png");
    };
    chartImg.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
  };

  // ── Combined Export PNG (Chart + Slide chooser) ──

  /**
   * Show checkbox popover so the user can choose Chart PNG, Slide PNG, or both.
   * @param {string} sectionId - Section identifier
   * @param {HTMLElement} btnEl - The button that was clicked (anchors the popover)
   */
  window.exportPNG = function(sectionId, btnEl) {
    var checkboxes = [
      { key: "chart", label: "Chart PNG", available: true, checked: true },
      { key: "slide", label: "Slide PNG", available: true, checked: true }
    ];
    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      if (flags.chart) exportChartPNG(sectionId);
      if (flags.slide) exportSlidePNG(sectionId);
    }, null, { title: "EXPORT AS PNG", actionLabel: "Export" });
  };

  // ── Save Report (serialize current state to downloadable HTML) ──
  window.saveReportHTML = function() {
    // Sync all insights before saving
    if (typeof syncAllInsights === "function") syncAllInsights();

    // Store simulator state if active
    if (typeof TurasSimulator !== "undefined") {
      var simState = TurasSimulator.getState();
      if (simState) {
        var simPanel = document.getElementById("panel-simulator");
        if (simPanel) {
          simPanel.setAttribute("data-sim-price", simState.currentPrice || "");
        }
      }
    }

    // Serialize full HTML
    var html = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;
    var blob = new Blob([html], { type: "text/html;charset=utf-8" });
    var projectName = document.title.replace(/ - Pricing Report$/, "").replace(/\s+/g, "_") || "Pricing_Report";
    downloadBlob(blob, projectName + "_Saved.html");

    // Update save badge
    var badge = document.getElementById("save-badge");
    if (badge) {
      badge.textContent = "Saved " + new Date().toLocaleTimeString();
      badge.style.display = "inline";
    }
  };

})();
