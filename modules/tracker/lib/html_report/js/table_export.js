// ==============================================================================
// TurasTracker HTML Report - Table Export
// ==============================================================================
// CSV and Excel export, column sorting for the tracking crosstab table.
// ==============================================================================

(function() {
  "use strict";

  // ---- CSV Export ----
  window.exportCSV = function() {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    var rows = [];

    // Headers
    var headerRows = table.querySelectorAll("thead tr");
    headerRows.forEach(function(tr) {
      var cells = [];
      tr.querySelectorAll("th").forEach(function(th) {
        if (th.classList.contains("segment-hidden")) return;
        var colspan = parseInt(th.getAttribute("colspan") || "1", 10);
        var text = th.textContent.trim();
        cells.push(csvEscape(text));
        for (var c = 1; c < colspan; c++) {
          cells.push("");
        }
      });
      rows.push(cells.join(","));
    });

    // Data rows (only visible ones)
    var bodyRows = table.querySelectorAll("tbody tr");
    bodyRows.forEach(function(tr) {
      // Skip hidden change rows
      if (tr.classList.contains("tk-change-row") && !tr.classList.contains("visible")) return;
      // Skip section rows
      if (tr.classList.contains("tk-section-row")) {
        var secText = tr.querySelector("td").textContent.trim();
        rows.push(csvEscape(secText));
        return;
      }

      var cells = [];
      tr.querySelectorAll("td").forEach(function(td) {
        if (td.classList.contains("segment-hidden")) return;
        // Get text content, strip sparkline SVG
        var text = "";
        var label = td.querySelector(".tk-metric-label");
        if (label) {
          text = label.textContent.trim();
        } else {
          text = td.textContent.trim();
        }
        cells.push(csvEscape(text));
      });
      rows.push(cells.join(","));
    });

    var csv = rows.join("\n");
    downloadBlob(csv, "tracking_crosstab.csv", "text/csv;charset=utf-8");
  };

  // ---- Excel Export (XML Spreadsheet) ----
  window.exportExcel = function() {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    var xml = '<?xml version="1.0"?>\n';
    xml += '<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
    xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';

    // Styles
    xml += '<Styles>\n';
    xml += '<Style ss:ID="Default"><Font ss:FontName="Calibri" ss:Size="11"/></Style>\n';
    xml += '<Style ss:ID="Header"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/><Interior ss:Color="#D9E2F3" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Section"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/><Interior ss:Color="#E2EFDA" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Change"><Font ss:FontName="Calibri" ss:Size="10" ss:Color="#666666"/><Interior ss:Color="#F5F5F5" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="SigUp"><Font ss:FontName="Calibri" ss:Size="10" ss:Color="#008000" ss:Bold="1"/><Interior ss:Color="#F5F5F5" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="SigDown"><Font ss:FontName="Calibri" ss:Size="10" ss:Color="#C00000" ss:Bold="1"/><Interior ss:Color="#F5F5F5" ss:Pattern="Solid"/></Style>\n';
    xml += '</Styles>\n';

    xml += '<Worksheet ss:Name="Tracking Crosstab">\n<Table>\n';

    // Headers
    var headerRows = table.querySelectorAll("thead tr");
    headerRows.forEach(function(tr) {
      xml += '<Row>\n';
      tr.querySelectorAll("th").forEach(function(th) {
        if (th.classList.contains("segment-hidden")) return;
        var colspan = th.getAttribute("colspan");
        var text = th.textContent.trim();
        var mergeAttr = colspan && parseInt(colspan) > 1 ? ' ss:MergeAcross="' + (parseInt(colspan) - 1) + '"' : '';
        xml += '<Cell ss:StyleID="Header"' + mergeAttr + '><Data ss:Type="String">' + xmlEscape(text) + '</Data></Cell>\n';
      });
      xml += '</Row>\n';
    });

    // Body
    var bodyRows = table.querySelectorAll("tbody tr");
    bodyRows.forEach(function(tr) {
      if (tr.classList.contains("tk-change-row") && !tr.classList.contains("visible")) return;

      xml += '<Row>\n';

      if (tr.classList.contains("tk-section-row")) {
        var secText = tr.querySelector("td").textContent.trim();
        var totalCols = tr.querySelector("td").getAttribute("colspan") || "1";
        xml += '<Cell ss:StyleID="Section" ss:MergeAcross="' + (parseInt(totalCols) - 1) + '"><Data ss:Type="String">' + xmlEscape(secText) + '</Data></Cell>\n';
      } else {
        var isChange = tr.classList.contains("tk-change-row");
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.classList.contains("segment-hidden")) return;
          var text = "";
          var label = td.querySelector(".tk-metric-label");
          if (label) {
            text = label.textContent.trim();
          } else {
            text = td.textContent.trim();
          }

          var style = "Default";
          if (isChange) {
            var sigUp = td.querySelector(".sig-up");
            var sigDown = td.querySelector(".sig-down");
            if (sigUp) style = "SigUp";
            else if (sigDown) style = "SigDown";
            else style = "Change";
          }

          // Try to detect numeric values
          var numVal = parseFloat(text.replace(/[+%pp↑↓→]/g, "").trim());
          if (!isNaN(numVal) && text.match(/^[+\-]?\d/)) {
            xml += '<Cell ss:StyleID="' + style + '"><Data ss:Type="String">' + xmlEscape(text) + '</Data></Cell>\n';
          } else {
            xml += '<Cell ss:StyleID="' + style + '"><Data ss:Type="String">' + xmlEscape(text) + '</Data></Cell>\n';
          }
        });
      }

      xml += '</Row>\n';
    });

    xml += '</Table>\n</Worksheet>\n</Workbook>';

    downloadBlob(xml, "tracking_crosstab.xls", "application/vnd.ms-excel");
  };

  // ---- Helpers (exposed globally for reuse by metrics_view.js) ----
  function csvEscape(text) {
    if (!text) return "";
    text = text.replace(/"/g, '""');
    if (text.indexOf(",") !== -1 || text.indexOf('"') !== -1 || text.indexOf("\n") !== -1) {
      text = '"' + text + '"';
    }
    return text;
  }

  function xmlEscape(text) {
    if (!text) return "";
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function downloadBlob(content, filename, mimeType) {
    var blob = new Blob([content], { type: mimeType });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // Expose helpers globally
  window.csvEscape = csvEscape;
  window.xmlEscape = xmlEscape;
  window.downloadBlob = downloadBlob;

})();
