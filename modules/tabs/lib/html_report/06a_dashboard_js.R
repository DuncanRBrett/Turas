# ==============================================================================
# HTML REPORT - DASHBOARD JAVASCRIPT (V10.8)
# ==============================================================================
# JavaScript builders for dashboard interactivity.
# Extracted from 06_dashboard_builder.R for modularity.
#
# FUNCTIONS:
# - build_heatmap_export_js() - Client-side Excel export via XML Spreadsheet
# - build_dashboard_interaction_js() - Gauge toggle, sort, SVG slide export
#
# DEPENDENCIES: None (pure JS generation)
# ==============================================================================

#' Build Heatmap Excel Export JavaScript
#'
#' Client-side Excel export using XML Spreadsheet format, same approach
#' as the crosstab export in 03_page_builder.R.
#'
#' @return htmltools::tags$script
#' @keywords internal
build_heatmap_export_js <- function() {

  js <- '
    function exportHeatmapExcel(tableId, sheetName) {
      var table = document.getElementById(tableId);
      if (!table) return;

      var rows = table.querySelectorAll("tr");
      if (rows.length === 0) return;

      var xml = [];
      xml.push("<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>");
      xml.push("<?mso-application progid=\\"Excel.Sheet\\"?>");
      xml.push("<Workbook xmlns=\\"urn:schemas-microsoft-com:office:spreadsheet\\"");
      xml.push(" xmlns:ss=\\"urn:schemas-microsoft-com:office:spreadsheet\\">");
      xml.push("<Styles>");
      xml.push("<Style ss:ID=\\"header\\"><Font ss:Bold=\\"1\\" ss:Size=\\"11\\"/>");
      xml.push("<Interior ss:Color=\\"#F8F9FA\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("<Style ss:ID=\\"title\\"><Font ss:Bold=\\"1\\" ss:Size=\\"12\\"/></Style>");
      xml.push("<Style ss:ID=\\"normal\\"><Font ss:Size=\\"11\\"/></Style>");
      xml.push("<Style ss:ID=\\"green\\"><Font ss:Size=\\"11\\" ss:Color=\\"#4a7c6f\\"/>");
      xml.push("<Interior ss:Color=\\"#e0ede8\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("<Style ss:ID=\\"amber\\"><Font ss:Size=\\"11\\" ss:Color=\\"#96783a\\"/>");
      xml.push("<Interior ss:Color=\\"#f5efe0\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("<Style ss:ID=\\"red\\"><Font ss:Size=\\"11\\" ss:Color=\\"#b85450\\"/>");
      xml.push("<Interior ss:Color=\\"#f5e3e2\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("</Styles>");

      var safeName = sheetName.replace(/[\\[\\]\\\\\\/?*]/g, "").substring(0, 31);
      xml.push("<Worksheet ss:Name=\\"" + escapeHeatmapXml(safeName) + "\\">");
      xml.push("<Table>");

      rows.forEach(function(row, rowIdx) {
        xml.push("<Row>");
        var cells = row.querySelectorAll("th, td");
        cells.forEach(function(cell) {
          var colspan = cell.getAttribute("colspan");
          var text = cell.textContent.trim();
          var isHeader = cell.tagName === "TH" || rowIdx < 2;
          var styleId = isHeader ? "header" : "normal";

          // Read colour tier from data attribute (inline style colours are
          // normalised to rgb(r, g, b) by browsers, making string matching unreliable)
          if (!isHeader) {
            var tier = cell.getAttribute("data-tier");
            if (tier === "green" || tier === "amber" || tier === "red") {
              styleId = tier;
            }
          }

          // Handle colspan by merging
          var mergeAttr = "";
          if (colspan && parseInt(colspan) > 1) {
            mergeAttr = " ss:MergeAcross=\\"" + (parseInt(colspan) - 1) + "\\"";
          }

          // Try numeric detection
          var cleaned = text.replace(/[+%,]/g, "").trim();
          var num = parseFloat(cleaned);
          var isNum = !isNaN(num) && cleaned.match(/^[\\-]?[\\d\\.]+$/);

          if (isNum && text.trim() !== "" && text.trim() !== "\\u2014") {
            xml.push("<Cell ss:StyleID=\\"" + styleId + "\\"" + mergeAttr +
                      "><Data ss:Type=\\"Number\\">" + num + "</Data></Cell>");
          } else {
            xml.push("<Cell ss:StyleID=\\"" + styleId + "\\"" + mergeAttr +
                      "><Data ss:Type=\\"String\\">" + escapeHeatmapXml(text) + "</Data></Cell>");
          }
        });
        xml.push("</Row>");
      });

      xml.push("</Table></Worksheet></Workbook>");

      var blob = new Blob([xml.join("\\n")], {
        type: "application/vnd.ms-excel;charset=utf-8"
      });
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = safeName.replace(/\\s+/g, "_") + "_heatmap.xls";
      document.body.appendChild(a);
      a.click();
      setTimeout(function() { document.body.removeChild(a); URL.revokeObjectURL(url); }, 100);
    }

    function escapeHeatmapXml(s) {
      return s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }
  '

  htmltools::tags$script(htmltools::HTML(js))
}


#' Build Dashboard Slide Export & Gauge Toggle JavaScript
#'
#' @return htmltools::tags$script
#' @keywords internal
build_dashboard_interaction_js <- function() {
  js <- '
    function toggleGaugeExclude(card) {
      card.classList.toggle("dash-gauge-excluded");
    }

    function cycleSortGauges(sectionId) {
      var section = document.getElementById("dash-sec-" + sectionId);
      if (!section) return;
      var container = section.querySelector(".dash-gauges");
      if (!container) return;
      var current = container.getAttribute("data-sort-mode") || "desc";

      // Cycle: desc -> asc -> original -> desc
      var nextMode = current === "desc" ? "asc" : current === "asc" ? "original" : "desc";
      container.setAttribute("data-sort-mode", nextMode);

      var cards = Array.from(container.querySelectorAll(".dash-gauge-card"));
      if (cards.length < 2) return;

      if (nextMode === "original") {
        cards.sort(function(a, b) {
          return parseInt(a.getAttribute("data-original-idx") || "0") -
                 parseInt(b.getAttribute("data-original-idx") || "0");
        });
      } else {
        cards.sort(function(a, b) {
          var va = parseFloat(a.getAttribute("data-value-num")) || -Infinity;
          var vb = parseFloat(b.getAttribute("data-value-num")) || -Infinity;
          return nextMode === "desc" ? vb - va : va - vb;
        });
      }

      // Re-insert in new order and update rank labels
      cards.forEach(function(card, i) {
        container.appendChild(card);
        var rank = card.querySelector(".dash-gauge-rank");
        if (rank) rank.textContent = "#" + (i + 1);
      });

      // Update button label
      var btn = section.querySelector(".dash-sort-btn");
      if (btn) {
        btn.innerHTML = nextMode === "desc" ? "\\u25BC High\\u2192Low"
                      : nextMode === "asc" ? "\\u25B2 Low\\u2192High"
                      : "\\u25CF Original";
      }
    }

    function exportDashboardSlide(sectionId) {
      var section = document.getElementById("dash-sec-" + sectionId);
      if (!section) return;
      var cards = section.querySelectorAll(".dash-gauge-card:not(.dash-gauge-excluded)");
      if (cards.length === 0) { alert("No gauges to export (all excluded)"); return; }

      // 2A: Read embedded metadata
      var summaryPanel = document.getElementById("tab-summary");
      var projectTitle = summaryPanel ? (summaryPanel.getAttribute("data-project-title") || "") : "";
      var fieldwork = summaryPanel ? (summaryPanel.getAttribute("data-fieldwork") || "") : "";
      var companyName = summaryPanel ? (summaryPanel.getAttribute("data-company") || "") : "";
      var brandColour = summaryPanel ? (summaryPanel.getAttribute("data-brand-colour") || BRAND_COLOUR) : BRAND_COLOUR;

      var ns = "http://www.w3.org/2000/svg";
      var font = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
      var W = 1000, pad = 30;
      var perRow = 5, cardW = 170, cardH = 150, gapX = 14, gapY = 18;
      var maxPerSlide = 20;
      var totalCards = cards.length;
      var slideCount = Math.ceil(totalCards / maxPerSlide);

      // 2C: Count tier colours from all cards in this section
      var nGreen = 0, nAmber = 0, nRed = 0;
      cards.forEach(function(c) {
        var g = c.querySelector("svg");
        if (g) {
          var ps = g.querySelectorAll("path");
          if (ps.length >= 2) {
            var sc = ps[1].getAttribute("stroke") || "";
            if (sc === "#4a7c6f") nGreen++;
            else if (sc === "#c9a96e") nAmber++;
            else if (sc === "#b85450") nRed++;
          }
        }
      });

      for (var si = 0; si < slideCount; si++) {
        var startIdx = si * maxPerSlide;
        var endIdx = Math.min(startIdx + maxPerSlide, totalCards);
        var slideCards = Array.from(cards).slice(startIdx, endIdx);
        var nRows = Math.ceil(slideCards.length / perRow);

        // 2B: Brand header bar (48px)
        var headerH = 48;
        // 2C: Summary callout line (24px)
        var calloutH = 24;
        var sectionTitleH = 30;
        var gridH = nRows * (cardH + gapY);
        // 2E: Footer (30px)
        var footerH = 30;
        var totalH = headerH + pad + calloutH + sectionTitleH + gridH + pad + footerH;

        var svg = document.createElementNS(ns, "svg");
        svg.setAttribute("xmlns", ns);
        svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
        svg.setAttribute("style", "font-family:" + font + ";");

        // White bg
        var bg = document.createElementNS(ns, "rect");
        bg.setAttribute("width", W); bg.setAttribute("height", totalH);
        bg.setAttribute("fill", "#ffffff");
        svg.appendChild(bg);

        // 2B: Brand header bar — full width rect in brand colour
        var headerBar = document.createElementNS(ns, "rect");
        headerBar.setAttribute("x", "0"); headerBar.setAttribute("y", "0");
        headerBar.setAttribute("width", W); headerBar.setAttribute("height", headerH);
        headerBar.setAttribute("fill", brandColour);
        svg.appendChild(headerBar);

        // Project name (white, left)
        if (projectTitle) {
          var ptEl = document.createElementNS(ns, "text");
          ptEl.setAttribute("x", pad); ptEl.setAttribute("y", headerH / 2 + 6);
          ptEl.setAttribute("fill", "#ffffff"); ptEl.setAttribute("font-size", "16");
          ptEl.setAttribute("font-weight", "700");
          ptEl.textContent = projectTitle;
          svg.appendChild(ptEl);
        }

        // Fieldwork + company (white, right)
        var rightText = [fieldwork, companyName].filter(function(s) { return s; }).join("  \\u00B7  ");
        if (rightText) {
          var rtEl = document.createElementNS(ns, "text");
          rtEl.setAttribute("x", W - pad); rtEl.setAttribute("y", headerH / 2 + 5);
          rtEl.setAttribute("text-anchor", "end"); rtEl.setAttribute("fill", "rgba(255,255,255,0.85)");
          rtEl.setAttribute("font-size", "11"); rtEl.setAttribute("font-weight", "500");
          rtEl.textContent = rightText;
          svg.appendChild(rtEl);
        }

        // 2C: Summary callout line below header
        var calloutY = headerH + 16;
        var calloutParts = [];
        if (nGreen > 0) calloutParts.push(nGreen + " Strong");
        if (nAmber > 0) calloutParts.push(nAmber + " Moderate");
        if (nRed > 0) calloutParts.push(nRed + " Concern");
        if (calloutParts.length > 0) {
          var calloutText = totalCards + " of " + totalCards + " metrics: " + calloutParts.join(", ");
          var coEl = document.createElementNS(ns, "text");
          coEl.setAttribute("x", pad); coEl.setAttribute("y", calloutY + 12);
          coEl.setAttribute("fill", "#64748b"); coEl.setAttribute("font-size", "11");
          coEl.setAttribute("font-weight", "500");
          coEl.textContent = calloutText;
          svg.appendChild(coEl);
        }

        // Section title with accent line
        var secTitleY = calloutY + calloutH + 4;
        var accent = document.createElementNS(ns, "rect");
        accent.setAttribute("x", pad); accent.setAttribute("y", secTitleY);
        accent.setAttribute("width", "4"); accent.setAttribute("height", "20");
        accent.setAttribute("rx", "2"); accent.setAttribute("fill", brandColour);
        svg.appendChild(accent);

        var title = document.createElementNS(ns, "text");
        var sectionTitle = section.querySelector(".dash-section-title");
        var titleText = sectionTitle ? sectionTitle.textContent.replace("Export Slide", "").trim() : sectionId;
        // Remove tier pill text that gets concatenated
        titleText = titleText.replace(/\\d+\\s*(Strong|Moderate|Concern)/g, "").trim();
        if (slideCount > 1) titleText += " (" + (si + 1) + " of " + slideCount + ")";
        title.setAttribute("x", pad + 12); title.setAttribute("y", secTitleY + 15);
        title.setAttribute("fill", "#1a2744"); title.setAttribute("font-size", "15");
        title.setAttribute("font-weight", "700");
        title.textContent = titleText;
        svg.appendChild(title);

        // 2D: Gauge cards — with coloured top border, larger value, subtle shadow
        var gridTopY = secTitleY + sectionTitleH;
        var gridStartX = (W - (perRow * cardW + (perRow - 1) * gapX)) / 2;

        // SVG drop shadow filter
        var defs = document.createElementNS(ns, "defs");
        var filter = document.createElementNS(ns, "filter");
        filter.setAttribute("id", "cardShadow");
        filter.setAttribute("x", "-5%"); filter.setAttribute("y", "-5%");
        filter.setAttribute("width", "110%"); filter.setAttribute("height", "120%");
        var feFlood = document.createElementNS(ns, "feDropShadow");
        feFlood.setAttribute("dx", "0"); feFlood.setAttribute("dy", "1");
        feFlood.setAttribute("stdDeviation", "2");
        feFlood.setAttribute("flood-color", "rgba(0,0,0,0.06)");
        filter.appendChild(feFlood);
        defs.appendChild(filter);
        svg.appendChild(defs);

        slideCards.forEach(function(card, ci) {
          var col = ci % perRow;
          var row = Math.floor(ci / perRow);
          var cx = gridStartX + col * (cardW + gapX);
          var cy = gridTopY + row * (cardH + gapY);
          var midX = cx + cardW / 2;

          // Extract gauge colour and fill from the existing card SVG
          var gaugeColour = "#4a7c6f";
          var fillFrac = 0.5;
          var gaugeEl = card.querySelector("svg");
          if (gaugeEl) {
            var paths = gaugeEl.querySelectorAll("path");
            if (paths.length >= 2) {
              gaugeColour = paths[1].getAttribute("stroke") || gaugeColour;
              var da = paths[1].getAttribute("stroke-dasharray") || "";
              var daParts = da.split(/[\\s,]+/);
              if (daParts.length >= 1) {
                var fillLen = parseFloat(daParts[0]) || 0;
                fillFrac = Math.min(fillLen / 251.33, 1);
              }
            }
          }

          // Card background with subtle shadow
          var cardBg = document.createElementNS(ns, "rect");
          cardBg.setAttribute("x", cx); cardBg.setAttribute("y", cy);
          cardBg.setAttribute("width", cardW); cardBg.setAttribute("height", cardH);
          cardBg.setAttribute("rx", "8"); cardBg.setAttribute("fill", "#f8fafc");
          cardBg.setAttribute("stroke", "#e2e8f0"); cardBg.setAttribute("stroke-width", "1");
          cardBg.setAttribute("filter", "url(#cardShadow)");
          svg.appendChild(cardBg);

          // 2D: 3px coloured top border
          var topBorder = document.createElementNS(ns, "rect");
          topBorder.setAttribute("x", cx + 4); topBorder.setAttribute("y", cy);
          topBorder.setAttribute("width", cardW - 8); topBorder.setAttribute("height", "3");
          topBorder.setAttribute("rx", "1.5"); topBorder.setAttribute("fill", gaugeColour);
          svg.appendChild(topBorder);

          // Draw mini gauge arc (radius 40, centered in upper card area)
          var gr = 40, gStroke = 8;
          var gCx = midX, gCy = cy + 58;
          var arcLen = Math.PI * gr;
          var fillDash = (fillFrac * arcLen).toFixed(1);
          var gapDash = (arcLen - fillFrac * arcLen + 1).toFixed(1);

          // Background arc (grey)
          var bgArc = document.createElementNS(ns, "path");
          var arcD = "M " + (gCx - gr) + " " + gCy + " A " + gr + " " + gr + " 0 0 1 " + (gCx + gr) + " " + gCy;
          bgArc.setAttribute("d", arcD); bgArc.setAttribute("fill", "none");
          bgArc.setAttribute("stroke", "#e2e8f0"); bgArc.setAttribute("stroke-width", gStroke);
          bgArc.setAttribute("stroke-linecap", "round");
          svg.appendChild(bgArc);

          // Coloured arc
          var fgArc = document.createElementNS(ns, "path");
          fgArc.setAttribute("d", arcD); fgArc.setAttribute("fill", "none");
          fgArc.setAttribute("stroke", gaugeColour); fgArc.setAttribute("stroke-width", gStroke);
          fgArc.setAttribute("stroke-linecap", "round");
          fgArc.setAttribute("stroke-dasharray", fillDash + " " + gapDash);
          svg.appendChild(fgArc);

          // 2D: Value text — larger font (20px instead of 16px)
          var val = card.getAttribute("data-value") || "";
          var valEl = document.createElementNS(ns, "text");
          valEl.setAttribute("x", midX); valEl.setAttribute("y", gCy - 4);
          valEl.setAttribute("text-anchor", "middle"); valEl.setAttribute("fill", gaugeColour);
          valEl.setAttribute("font-size", "20"); valEl.setAttribute("font-weight", "700");
          valEl.textContent = val;
          svg.appendChild(valEl);

          // Q code (small, brand colour)
          var qCode = card.getAttribute("data-q-code") || "";
          var qcEl = document.createElementNS(ns, "text");
          qcEl.setAttribute("x", midX); qcEl.setAttribute("y", gCy + 16);
          qcEl.setAttribute("text-anchor", "middle"); qcEl.setAttribute("fill", brandColour);
          qcEl.setAttribute("font-size", "10"); qcEl.setAttribute("font-weight", "700");
          qcEl.textContent = qCode;
          svg.appendChild(qcEl);

          // Question text (multi-line wrapping)
          var qText = card.getAttribute("data-q-text") || "";
          var maxCharsPerLine = Math.floor((cardW - 12) / 5);
          var tLines = [];
          if (qText.length <= maxCharsPerLine) {
            tLines = [qText];
          } else {
            var words = qText.split(" ");
            var current = "";
            for (var wi = 0; wi < words.length; wi++) {
              var test = current ? current + " " + words[wi] : words[wi];
              if (test.length > maxCharsPerLine && current) {
                tLines.push(current);
                current = words[wi];
              } else {
                current = test;
              }
            }
            if (current) tLines.push(current);
            if (tLines.length > 4) tLines = tLines.slice(0, 4);
          }
          tLines.forEach(function(tLine, tli) {
            var tEl = document.createElementNS(ns, "text");
            tEl.setAttribute("x", midX);
            tEl.setAttribute("y", gCy + 30 + tli * 11);
            tEl.setAttribute("text-anchor", "middle");
            tEl.setAttribute("fill", "#64748b");
            tEl.setAttribute("font-size", "8.5");
            tEl.textContent = tLine;
            svg.appendChild(tEl);
          });
        });

        // 2E: Footer — hairline + company (left) + page number (right)
        var footerY = totalH - footerH;
        var hairline = document.createElementNS(ns, "line");
        hairline.setAttribute("x1", pad); hairline.setAttribute("y1", footerY);
        hairline.setAttribute("x2", W - pad); hairline.setAttribute("y2", footerY);
        hairline.setAttribute("stroke", "#e2e8f0"); hairline.setAttribute("stroke-width", "1");
        svg.appendChild(hairline);

        if (companyName) {
          var ftCompany = document.createElementNS(ns, "text");
          ftCompany.setAttribute("x", pad); ftCompany.setAttribute("y", footerY + 18);
          ftCompany.setAttribute("fill", "#94a3b8"); ftCompany.setAttribute("font-size", "9");
          ftCompany.setAttribute("font-weight", "500");
          ftCompany.textContent = companyName;
          svg.appendChild(ftCompany);
        }

        if (slideCount > 1) {
          var ftPage = document.createElementNS(ns, "text");
          ftPage.setAttribute("x", W - pad); ftPage.setAttribute("y", footerY + 18);
          ftPage.setAttribute("text-anchor", "end");
          ftPage.setAttribute("fill", "#94a3b8"); ftPage.setAttribute("font-size", "9");
          ftPage.textContent = (si + 1) + " of " + slideCount;
          svg.appendChild(ftPage);
        }

        // Render to PNG at 3x
        var scale = 3;
        var svgData = new XMLSerializer().serializeToString(svg);
        var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
        var url = URL.createObjectURL(svgBlob);
        var img = new Image();
        img.onerror = (function(blobUrl) {
          return function() {
            URL.revokeObjectURL(blobUrl);
            alert("Dashboard export failed. Your browser may not support this operation. Try Chrome or Edge.");
          };
        })(url);
        img.onload = (function(slideIdx, svgW, svgH, blobUrl) {
          return function() {
            var canvas = document.createElement("canvas");
            canvas.width = svgW * scale; canvas.height = svgH * scale;
            var ctx = canvas.getContext("2d");
            ctx.fillStyle = "#ffffff";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            URL.revokeObjectURL(blobUrl);
            canvas.toBlob(function(blob) {
              var suffix = slideCount > 1 ? "_" + (slideIdx + 1) : "";
              var a = document.createElement("a");
              a.href = URL.createObjectURL(blob);
              a.download = sectionId + "_dashboard" + suffix + ".png";
              document.body.appendChild(a); a.click();
              document.body.removeChild(a);
              URL.revokeObjectURL(a.href);
            }, "image/png");
          };
        })(si, W, totalH, url);
        img.src = url;
      }
    }
  '
  htmltools::tags$script(htmltools::HTML(js))
}
