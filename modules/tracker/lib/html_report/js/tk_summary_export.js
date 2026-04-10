/**
 * TURAS Tracker Report — Summary Section Export
 *
 * Export functions for summary sections: slide PNG, Excel XML, table slide.
 * These were previously in pinned_views.js but are not pin-related.
 *
 * Depends on: xmlEscape, downloadBlob from table_export.js
 *             svgToImageUrl, stripInvalidXmlChars from earlier in bundle
 */

/* global xmlEscape, downloadBlob, svgToImageUrl, stripInvalidXmlChars */

(function() {
  "use strict";

  // ── DOM Helpers for Export ─────────────────────────────────────────────────

  /** Clean cloned DOM for SVG foreignObject export. */
  function cleanCloneForExport(clone) {
    clone.querySelectorAll("[contenteditable]").forEach(function(el) {
      el.removeAttribute("contenteditable");
    });
    clone.querySelectorAll("[oninput],[onblur],[onclick]").forEach(function(el) {
      el.removeAttribute("oninput");
      el.removeAttribute("onblur");
      el.removeAttribute("onclick");
    });
  }

  /** Sanitize HTML string for SVG foreignObject (XHTML compliance). */
  function sanitizeForSvg(html) {
    html = html.replace(/&(?![a-zA-Z]+;|#\d+;|#x[0-9a-fA-F]+;)/g, "&amp;");
    html = html.replace(/<br\s*>/gi, "<br/>");
    html = html.replace(/<hr\s*>/gi, "<hr/>");
    html = html.replace(/<img([^>]*?)(?<!\/)>/gi, "<img$1/>");
    html = html.replace(/<input([^>]*?)(?<!\/)>/gi, "<input$1/>");
    html = html.replace(/<col([^>]*?)(?<!\/)>/gi, "<col$1/>");
    html = html.replace(/<wbr\s*>/gi, "<wbr/>");
    html = html.replace(/<source([^>]*?)(?<!\/)>/gi, "<source$1/>");
    html = html.replace(/<meta([^>]*?)(?<!\/)>/gi, "<meta$1/>");
    html = html.replace(/<link([^>]*?)(?<!\/)>/gi, "<link$1/>");
    return html;
  }

  /** Inline computed styles on an element tree for foreignObject rendering. */
  function inlineStyles(el) {
    if (el.nodeType !== 1) return;
    var computed = window.getComputedStyle(el);
    var props = [
      "font-family", "font-size", "font-weight", "color", "background-color",
      "background", "border", "border-radius", "padding", "margin",
      "display", "text-align", "line-height", "white-space",
      "border-bottom", "border-top", "overflow"
    ];
    for (var i = 0; i < props.length; i++) {
      el.style[props[i]] = computed.getPropertyValue(props[i]);
    }
    for (var c = 0; c < el.children.length; c++) {
      inlineStyles(el.children[c]);
    }
  }

  // ── Summary Slide Export ──────────────────────────────────────────────────

  /**
   * Export a summary section as a slide PNG.
   * @param {string} sectionType - "background", "findings", or "sig-changes"
   */
  window.exportSummarySlide = function(sectionType) {
    var sectionId;
    if (sectionType === "background") sectionId = "summary-section-background";
    else if (sectionType === "sig-changes") sectionId = "summary-section-sig-changes";
    else sectionId = "summary-section-findings";

    var section = document.getElementById(sectionId);
    if (!section) return;

    var clone = section.cloneNode(true);
    var controls = clone.querySelector(".summary-section-controls");
    if (controls) controls.remove();
    cleanCloneForExport(clone);
    inlineStyles(clone);

    var w = section.offsetWidth || 800;
    var h = Math.max(section.offsetHeight || 300, 200);
    var SCALE = 3;
    var svgNS = "http://www.w3.org/2000/svg";
    var htmlContent = sanitizeForSvg(clone.outerHTML);
    var svgStr = '<svg xmlns="' + svgNS + '" width="' + (w * SCALE) + '" height="' + (h * SCALE) + '">';
    svgStr += '<foreignObject width="' + w + '" height="' + h + '" transform="scale(' + SCALE + ')">';
    svgStr += '<div xmlns="http://www.w3.org/1999/xhtml" style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;font-size:14px;color:#2c2c2c;background:#fff;">';
    svgStr += htmlContent;
    svgStr += '</div></foreignObject></svg>';

    var svgUrl = svgToImageUrl(svgStr);
    var canvas = document.createElement("canvas");
    canvas.width = w * SCALE; canvas.height = h * SCALE;
    var ctx = canvas.getContext("2d");
    var img = new Image();
    img.onload = function() {
      ctx.drawImage(img, 0, 0);
      canvas.toBlob(function(blob) {
        if (!blob) return;
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "summary_" + sectionType + ".png";
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
        URL.revokeObjectURL(a.href);
      }, "image/png");
    };
    img.onerror = function() { /* render failed */ };
    img.src = svgUrl;
  };

  // ── Summary Excel Export ──────────────────────────────────────────────────

  /** Export the summary/heatmap table as Excel XML. */
  window.exportSummaryExcel = function() {
    var table = document.getElementById("hm-overview-table") || document.getElementById("summary-metrics-table");
    if (!table) return;
    var isHeatmap = table.id === "hm-overview-table";

    var segLabel = "Total", modeLabel = "Absolute";
    if (isHeatmap) {
      var segSel = document.getElementById("hm-segment-select");
      if (segSel) segLabel = segSel.options[segSel.selectedIndex].text;
      var activeMode = document.querySelector(".hm-mode-btn.active");
      if (activeMode) modeLabel = activeMode.textContent.trim();
    }

    var xml = '<?xml version="1.0"?>\n<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
    xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';
    xml += '<Styles>\n';
    xml += '<Style ss:ID="Default"><Font ss:FontName="Calibri" ss:Size="11"/></Style>\n';
    xml += '<Style ss:ID="Title"><Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/></Style>\n';
    xml += '<Style ss:ID="Header"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/><Interior ss:Color="#D9E2F3" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Section"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1" ss:Color="#333333"/><Interior ss:Color="#F0F0F0" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Green"><Font ss:FontName="Calibri" ss:Size="11"/><Interior ss:Color="#D4EDDA" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Amber"><Font ss:FontName="Calibri" ss:Size="11"/><Interior ss:Color="#FFF3CD" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Red"><Font ss:FontName="Calibri" ss:Size="11"/><Interior ss:Color="#F8D7DA" ss:Pattern="Solid"/></Style>\n';
    xml += '</Styles>\n';

    var sheetTitle = isHeatmap ? "Overview Heatmap" : "Summary Metrics Overview";
    var sheetName = xmlEscape((isHeatmap ? segLabel + " - " + modeLabel : "Summary").substring(0, 31));
    xml += '<Worksheet ss:Name="' + sheetName + '">\n<Table>\n';
    xml += '<Row><Cell ss:StyleID="Title"><Data ss:Type="String">' + xmlEscape(sheetTitle) + '</Data></Cell></Row>\n';
    if (isHeatmap) {
      xml += '<Row><Cell><Data ss:Type="String">Segment: ' + xmlEscape(segLabel) + '  |  Mode: ' + xmlEscape(modeLabel) + '</Data></Cell></Row>\n';
    }
    xml += '<Row></Row>\n';

    var headerRow = table.querySelector("thead tr");
    if (headerRow) {
      xml += '<Row>\n';
      headerRow.querySelectorAll("th").forEach(function(th) {
        if (th.classList.contains("hm-spark-col") || th.classList.contains("hm-delta-col")) return;
        xml += '<Cell ss:StyleID="Header"><Data ss:Type="String">' + xmlEscape(th.textContent.trim()) + '</Data></Cell>\n';
      });
      if (isHeatmap) xml += '<Cell ss:StyleID="Header"><Data ss:Type="String">Change</Data></Cell>\n';
      xml += '</Row>\n';
    }

    table.querySelectorAll("tbody tr").forEach(function(tr) {
      if (tr.style.display === "none") return;
      if (tr.classList.contains("hm-type-header") || tr.classList.contains("hm-section-header") || tr.classList.contains("tk-section-row")) {
        var label = tr.textContent.trim();
        var nCols = headerRow ? headerRow.querySelectorAll("th").length : 5;
        if (isHeatmap) nCols = nCols - 1;
        xml += '<Row><Cell ss:StyleID="Section" ss:MergeAcross="' + (nCols - 1) + '"><Data ss:Type="String">' + xmlEscape(label) + '</Data></Cell></Row>\n';
        return;
      }
      if (isHeatmap && !tr.classList.contains("hm-metric-row")) return;

      xml += '<Row>\n';
      tr.querySelectorAll("td").forEach(function(td) {
        if (td.classList.contains("hm-spark-cell") || td.classList.contains("hm-delta-cell")) return;
        var text = "", dataType = "String", style = "Default";
        var labelEl = td.querySelector(".tk-metric-label") || td.querySelector(".hm-metric-label");
        if (labelEl) {
          text = labelEl.textContent.trim();
        } else if (td.classList.contains("hm-value-cell")) {
          var numVal = parseFloat(td.getAttribute("data-value"));
          if (!isNaN(numVal)) { text = String(numVal); dataType = "Number"; }
          else text = td.textContent.trim();
          var bg = td.style.backgroundColor || "";
          if (bg.indexOf("39, 174, 96") >= 0 || bg.indexOf("46, 204, 113") >= 0) style = "Green";
          else if (bg.indexOf("243, 156, 18") >= 0 || bg.indexOf("241, 196, 15") >= 0) style = "Amber";
          else if (bg.indexOf("231, 76, 60") >= 0 || bg.indexOf("192, 57, 43") >= 0) style = "Red";
        } else {
          text = td.textContent.trim();
        }
        xml += '<Cell ss:StyleID="' + style + '"><Data ss:Type="' + dataType + '">' + xmlEscape(text) + '</Data></Cell>\n';
      });
      if (isHeatmap) {
        var deltaCell = tr.querySelector(".hm-delta-cell");
        xml += '<Cell><Data ss:Type="String">' + xmlEscape(deltaCell ? deltaCell.textContent.trim() : "") + '</Data></Cell>\n';
      }
      xml += '</Row>\n';
    });

    xml += '</Table>\n</Worksheet>\n</Workbook>';
    var filename = isHeatmap ? "heatmap_" + segLabel.replace(/[^a-zA-Z0-9_-]/g, "_") + ".xls" : "summary_metrics.xls";
    downloadBlob(xml, filename, "application/vnd.ms-excel");
  };

  // ── Significance Matrix Excel Export ─────────────────────────────────────

  /**
   * Export the Significance Matrix heatmap table as Excel XML.
   * Reads tk-heatmap-table inside summary-section-heatmap.
   * Colour-codes cells: green (up), red (down), grey (stable), blank (n/a).
   */
  window.exportSigMatrixExcel = function() {
    var container = document.getElementById("summary-section-heatmap");
    if (!container) return;
    var table = container.querySelector(".tk-heatmap-table");
    if (!table) return;

    var xml = '<?xml version="1.0"?>\n<?mso-application progid="Excel.Sheet"?>\n';
    xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
    xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';
    xml += '<Styles>\n';
    xml += '<Style ss:ID="Default"><Font ss:FontName="Calibri" ss:Size="11"/></Style>\n';
    xml += '<Style ss:ID="Title"><Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/></Style>\n';
    xml += '<Style ss:ID="Header"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/>' +
      '<Interior ss:Color="#D9E2F3" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="TypeHdr"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"' +
      ' ss:Color="#475569"/><Interior ss:Color="#F8FAFC" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Up"><Font ss:FontName="Calibri" ss:Size="11"/>' +
      '<Interior ss:Color="#D4EDDA" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Down"><Font ss:FontName="Calibri" ss:Size="11"/>' +
      '<Interior ss:Color="#F8D7DA" ss:Pattern="Solid"/></Style>\n';
    xml += '<Style ss:ID="Stable"><Font ss:FontName="Calibri" ss:Size="11" ss:Color="#888888"/>' +
      '<Interior ss:Color="#F1F5F9" ss:Pattern="Solid"/></Style>\n';
    xml += '</Styles>\n';

    xml += '<Worksheet ss:Name="Significance Matrix">\n<Table>\n';
    xml += '<Row><Cell ss:StyleID="Title"><Data ss:Type="String">' +
      'Significance Matrix</Data></Cell></Row>\n';
    xml += '<Row><Cell><Data ss:Type="String">Change direction vs previous wave. ' +
      'Green = significant increase, Red = significant decrease, ' +
      'Grey = no significant change.</Data></Cell></Row>\n';
    xml += '<Row></Row>\n';

    // Header row
    var headerRow = table.querySelector("thead tr");
    if (headerRow) {
      xml += '<Row>\n';
      headerRow.querySelectorAll("th").forEach(function(th) {
        xml += '<Cell ss:StyleID="Header"><Data ss:Type="String">' +
          xmlEscape(th.textContent.trim()) + '</Data></Cell>\n';
      });
      xml += '</Row>\n';
    }

    // Body rows
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      // Type group header row
      if (tr.classList.contains("tk-heatmap-type-header")) {
        var label = tr.querySelector("td") ? tr.querySelector("td").textContent.trim() : "";
        var nCols = headerRow ? headerRow.querySelectorAll("th").length : 2;
        xml += '<Row><Cell ss:StyleID="TypeHdr" ss:MergeAcross="' + (nCols - 1) + '">' +
          '<Data ss:Type="String">' + xmlEscape(label) + '</Data></Cell></Row>\n';
        return;
      }
      // Metric data row
      if (!tr.classList.contains("tk-heatmap-row")) return;
      xml += '<Row>\n';
      tr.querySelectorAll("td").forEach(function(td) {
        var text = td.textContent.trim();
        var style = "Default";
        if (td.classList.contains("tk-heatmap-up"))     { style = "Up"; }
        else if (td.classList.contains("tk-heatmap-down"))   { style = "Down"; }
        else if (td.classList.contains("tk-heatmap-stable")) { style = "Stable"; }
        else if (td.classList.contains("tk-heatmap-na"))     { text = ""; }
        xml += '<Cell ss:StyleID="' + style + '"><Data ss:Type="String">' +
          xmlEscape(text) + '</Data></Cell>\n';
      });
      xml += '</Row>\n';
    });

    xml += '</Table>\n</Worksheet>\n</Workbook>';
    downloadBlob(xml, "significance_matrix.xls", "application/vnd.ms-excel");
  };

  // ── Summary Table Slide Export ────────────────────────────────────────────

  /** Export summary metrics table as a slide PNG. */
  window.exportSummaryTableSlide = function() {
    var table = document.getElementById("summary-metrics-table");
    if (!table) return;
    var brandColour = (typeof _tkBrand === "function") ? _tkBrand() :
      (getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367");
    var SLIDE_W = 1280, SLIDE_H = 720, SCALE = 3;
    var canvas = document.createElement("canvas");
    canvas.width = SLIDE_W * SCALE; canvas.height = SLIDE_H * SCALE;
    var ctx = canvas.getContext("2d");
    ctx.scale(SCALE, SCALE);

    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, SLIDE_W, SLIDE_H);
    ctx.fillStyle = brandColour;
    ctx.fillRect(0, 0, SLIDE_W, 60);
    ctx.fillStyle = "#fff";
    ctx.font = "bold 22px -apple-system, sans-serif";
    ctx.fillText("Summary Metrics Overview", 30, 40);
    ctx.fillStyle = "#666";
    ctx.font = "13px -apple-system, sans-serif";
    ctx.fillText("See HTML report for full interactive table", 30, 90);

    canvas.toBlob(function(blob) {
      if (!blob) return;
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "summary_metrics_slide.png";
      document.body.appendChild(a); a.click(); document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }, "image/png");
  };

})();
