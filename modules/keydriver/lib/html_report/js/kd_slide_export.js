/* ==============================================================================
 * KEYDRIVER HTML REPORT - SLIDE EXPORT (PNG)
 * ==============================================================================
 * Exports pinned views as presentation-quality PNG slides.
 * Layout: PowerPoint landscape 1280x720 at 3x scale -> 3840x2160 PNG.
 * Uses native Canvas API -- no external libraries.
 * All functions prefixed kd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  var SLIDE_W = 1280;
  var SLIDE_H = 720;
  var SCALE = 3;
  var NS = 'http://www.w3.org/2000/svg';

  /**
   * Export a pinned card as a PNG slide.
   * @param {string} pinId - The pin ID to export
   */
  window.kdExportPinnedCardPNG = function(pinId) {
    var pins = (typeof kdGetPinnedViews === 'function') ? kdGetPinnedViews() : [];
    if (!pins || !pins.length) return;
    var pin = null;
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].id === pinId) { pin = pins[i]; break; }
    }
    if (!pin) return;

    var svg = buildSlideSVG(pin);
    renderSVGtoPNG(svg, pin);
  };

  /**
   * Build the SVG slide layout for a pin.
   * @param {Object} pin - Pinned view data
   * @returns {string} SVG markup
   */
  function buildSlideSVG(pin) {
    var brandColour = getComputedStyle(document.documentElement)
      .getPropertyValue('--kd-brand').trim() || '#323367';
    var accentColour = getComputedStyle(document.documentElement)
      .getPropertyValue('--kd-accent').trim() || '#CC9900';

    // Create SVG document
    var svgEl = document.createElementNS(NS, 'svg');
    svgEl.setAttribute('xmlns', NS);
    svgEl.setAttribute('width', SLIDE_W);
    svgEl.setAttribute('height', SLIDE_H);
    svgEl.setAttribute('viewBox', '0 0 ' + SLIDE_W + ' ' + SLIDE_H);

    // Background
    var bg = document.createElementNS(NS, 'rect');
    bg.setAttribute('width', SLIDE_W);
    bg.setAttribute('height', SLIDE_H);
    bg.setAttribute('fill', '#ffffff');
    svgEl.appendChild(bg);

    // Top brand bar
    var topBar = document.createElementNS(NS, 'rect');
    topBar.setAttribute('x', 0);
    topBar.setAttribute('y', 0);
    topBar.setAttribute('width', SLIDE_W);
    topBar.setAttribute('height', 6);
    topBar.setAttribute('fill', brandColour);
    svgEl.appendChild(topBar);

    var yPos = 40;

    // Panel label (analysis name)
    if (pin.panelLabel) {
      var labelText = document.createElementNS(NS, 'text');
      labelText.setAttribute('x', 48);
      labelText.setAttribute('y', yPos);
      labelText.setAttribute('fill', brandColour);
      labelText.setAttribute('font-size', '14');
      labelText.setAttribute('font-weight', '600');
      labelText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
      labelText.setAttribute('text-transform', 'uppercase');
      labelText.setAttribute('letter-spacing', '0.5');
      labelText.textContent = pin.panelLabel.toUpperCase();
      svgEl.appendChild(labelText);
      yPos += 12;
    }

    // Section title
    var titleLines = kdWrapTextLines(pin.sectionTitle, SLIDE_W - 96, 14);
    var titleText = kdCreateWrappedText(NS, titleLines, 48, yPos + 20, 28, {
      fill: '#1e293b',
      fontSize: '24',
      fontWeight: '700'
    });
    svgEl.appendChild(titleText);
    yPos += 20 + titleLines.length * 28 + 12;

    // Separator line
    var sep = document.createElementNS(NS, 'line');
    sep.setAttribute('x1', 48);
    sep.setAttribute('y1', yPos);
    sep.setAttribute('x2', SLIDE_W - 48);
    sep.setAttribute('y2', yPos);
    sep.setAttribute('stroke', '#e2e8f0');
    sep.setAttribute('stroke-width', '1');
    svgEl.appendChild(sep);
    yPos += 16;

    // Insight callout (if present)
    if (pin.insightText) {
      // Accent left border
      var insightBorder = document.createElementNS(NS, 'rect');
      insightBorder.setAttribute('x', 48);
      insightBorder.setAttribute('y', yPos);
      insightBorder.setAttribute('width', 3);

      var insightLines = kdWrapTextLines(pin.insightText, SLIDE_W - 140, 9);
      var insightHeight = Math.max(48, insightLines.length * 20 + 24);

      insightBorder.setAttribute('height', insightHeight);
      insightBorder.setAttribute('fill', brandColour);
      svgEl.appendChild(insightBorder);

      // Insight background — light blue matching tabs export
      var insightBg = document.createElementNS(NS, 'rect');
      insightBg.setAttribute('x', 51);
      insightBg.setAttribute('y', yPos);
      insightBg.setAttribute('width', SLIDE_W - 99);
      insightBg.setAttribute('height', insightHeight);
      insightBg.setAttribute('fill', '#f0f4ff');
      insightBg.setAttribute('rx', '4');
      svgEl.appendChild(insightBg);

      // Insight label
      var insightLabel = document.createElementNS(NS, 'text');
      insightLabel.setAttribute('x', 64);
      insightLabel.setAttribute('y', yPos + 16);
      insightLabel.setAttribute('fill', accentColour);
      insightLabel.setAttribute('font-size', '12');
      insightLabel.setAttribute('font-weight', '700');
      insightLabel.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
      insightLabel.textContent = 'ANALYST INSIGHT';
      svgEl.appendChild(insightLabel);

      // Insight text (16px = readable in PowerPoint landscape at 3x scale)
      var insightTextEl = kdCreateWrappedText(NS, insightLines, 64, yPos + 34, 20, {
        fill: '#475569',
        fontSize: '16',
        fontWeight: '400'
      });
      svgEl.appendChild(insightTextEl);

      yPos += insightHeight + 16;
    }

    // Determine layout: side-by-side for quadrant (chart + table), stacked for others
    var isSideBySide = (pin.sectionKey === 'quadrant') && pin.chartSvg && pin.tableHtml;

    if (isSideBySide) {
      // Side-by-side layout: chart on left, table on right
      var contentArea = SLIDE_H - yPos - 60;
      var leftW = Math.floor((SLIDE_W - 96) * 0.55);  // 55% for chart
      var rightW = (SLIDE_W - 96) - leftW - 16;        // 45% for table minus gap
      var rightX = 48 + leftW + 16;

      // Left: Chart
      var tempDiv = document.createElement('div');
      tempDiv.innerHTML = pin.chartSvg;
      var sourceSvg = tempDiv.querySelector('svg');
      var chartEndY = yPos;

      if (sourceSvg) {
        var svgW = 700;
        var svgH = 350;
        var vb = sourceSvg.getAttribute('viewBox');
        if (vb) {
          var parts = vb.split(/[\s,]+/);
          if (parts.length >= 4) {
            svgW = parseFloat(parts[2]);
            svgH = parseFloat(parts[3]);
          }
        }

        var maxChartH = Math.min(contentArea - 8, 440);
        var scaleX = leftW / svgW;
        var scaleY = maxChartH / svgH;
        var chartScale = Math.min(scaleX, scaleY, 1.0);
        var scaledW = svgW * chartScale;
        var scaledH = svgH * chartScale;

        var nestedSvg = document.createElementNS(NS, 'svg');
        nestedSvg.setAttribute('x', 48);
        nestedSvg.setAttribute('y', yPos);
        nestedSvg.setAttribute('width', scaledW);
        nestedSvg.setAttribute('height', scaledH);
        nestedSvg.setAttribute('viewBox', '0 0 ' + svgW + ' ' + svgH);
        nestedSvg.setAttribute('preserveAspectRatio', 'xMidYMid meet');

        while (sourceSvg.firstChild) {
          nestedSvg.appendChild(sourceSvg.firstChild);
        }
        svgEl.appendChild(nestedSvg);
        chartEndY = yPos + scaledH;
      }

      // Right: Table
      var tableData = kdExtractSlideTableData(pin.tableHtml);
      var tableEndY = yPos;
      if (tableData && tableData.headers.length > 0) {
        var tableUsed = kdRenderTableSVG(svgEl, tableData, rightX, yPos, rightW, contentArea);
        tableEndY = yPos + tableUsed;
      }

      yPos = Math.max(chartEndY, tableEndY) + 12;

      // Action guide legend strip (below chart+table, fits in remaining space)
      var legendSpace = SLIDE_H - yPos - 60;
      if (legendSpace >= 36) {
        var actionItems = [
          { label: 'IMPROVE',  bg: '#fee2e2', color: '#991b1b', desc: 'High importance, low performance' },
          { label: 'MAINTAIN', bg: '#dcfce7', color: '#166534', desc: 'High importance, high performance' },
          { label: 'MONITOR',  bg: '#f1f5f9', color: '#64748b', desc: 'Low importance, low performance' },
          { label: 'ASSESS',   bg: '#dbeafe', color: '#1e40af', desc: 'Low importance, high performance' }
        ];
        var legendW = SLIDE_W - 96;
        var boxW = Math.floor(legendW / 4) - 6;
        var boxH = Math.min(36, legendSpace - 4);

        for (var li = 0; li < actionItems.length; li++) {
          var ax = 48 + li * (boxW + 8);
          var item = actionItems[li];

          // Background box
          var boxRect = document.createElementNS(NS, 'rect');
          boxRect.setAttribute('x', ax);
          boxRect.setAttribute('y', yPos);
          boxRect.setAttribute('width', boxW);
          boxRect.setAttribute('height', boxH);
          boxRect.setAttribute('fill', item.bg);
          boxRect.setAttribute('rx', '4');
          svgEl.appendChild(boxRect);

          // Action label (bold)
          var labelText = document.createElementNS(NS, 'text');
          labelText.setAttribute('x', ax + boxW / 2);
          labelText.setAttribute('y', yPos + 13);
          labelText.setAttribute('text-anchor', 'middle');
          labelText.setAttribute('fill', item.color);
          labelText.setAttribute('font-size', '9');
          labelText.setAttribute('font-weight', '700');
          labelText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
          labelText.textContent = item.label;
          svgEl.appendChild(labelText);

          // Description text
          if (boxH >= 30) {
            var descText = document.createElementNS(NS, 'text');
            descText.setAttribute('x', ax + boxW / 2);
            descText.setAttribute('y', yPos + 26);
            descText.setAttribute('text-anchor', 'middle');
            descText.setAttribute('fill', item.color);
            descText.setAttribute('font-size', '7');
            descText.setAttribute('font-weight', '400');
            descText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
            descText.textContent = item.desc;
            svgEl.appendChild(descText);
          }
        }
        yPos += boxH + 8;
      }

    } else {
      // Standard stacked layout: chart above table
      var chartArea = SLIDE_H - yPos - 60; // Reserve 60px for footer
      if (pin.chartSvg && chartArea > 80) {
        var tempDiv = document.createElement('div');
        tempDiv.innerHTML = pin.chartSvg;
        var sourceSvg = tempDiv.querySelector('svg');

        if (sourceSvg) {
          var svgW = 700;
          var svgH = 350;

          var vb = sourceSvg.getAttribute('viewBox');
          if (vb) {
            var parts = vb.split(/[\s,]+/);
            if (parts.length >= 4) {
              svgW = parseFloat(parts[2]);
              svgH = parseFloat(parts[3]);
            }
          }

          var maxChartW = SLIDE_W - 96;
          var maxChartH = Math.min(chartArea - 8, 400);
          var scaleX = maxChartW / svgW;
          var scaleY = maxChartH / svgH;
          var chartScale = Math.min(scaleX, scaleY, 1.0);
          var scaledW = svgW * chartScale;
          var scaledH = svgH * chartScale;
          var chartX = 48 + (maxChartW - scaledW) / 2;

          var nestedSvg = document.createElementNS(NS, 'svg');
          nestedSvg.setAttribute('x', chartX);
          nestedSvg.setAttribute('y', yPos);
          nestedSvg.setAttribute('width', scaledW);
          nestedSvg.setAttribute('height', scaledH);
          nestedSvg.setAttribute('viewBox', '0 0 ' + svgW + ' ' + svgH);
          nestedSvg.setAttribute('preserveAspectRatio', 'xMidYMid meet');

          while (sourceSvg.firstChild) {
            nestedSvg.appendChild(sourceSvg.firstChild);
          }
          svgEl.appendChild(nestedSvg);

          yPos += scaledH + 12;
        }
      }

      // Table content (if present and enough space remaining)
      if (pin.tableHtml) {
        var remainingSpace = SLIDE_H - yPos - 60;

        if (remainingSpace > 60) {
          var tableData = kdExtractSlideTableData(pin.tableHtml);
          if (tableData && tableData.headers.length > 0) {
            var tableUsed = kdRenderTableSVG(svgEl, tableData, 48, yPos, SLIDE_W - 96, remainingSpace);
            yPos += tableUsed + 8;
          } else {
            var textData = kdExtractContentText(pin.tableHtml);
            if (textData && textData.length > 0) {
              yPos = kdRenderContentTextSVG(svgEl, textData, 48, yPos, SLIDE_W - 96, remainingSpace, brandColour);
            }
          }
        }
      }
    }

    // Footer strip
    var footerY = SLIDE_H - 36;
    var footerBg = document.createElementNS(NS, 'rect');
    footerBg.setAttribute('x', 0);
    footerBg.setAttribute('y', footerY);
    footerBg.setAttribute('width', SLIDE_W);
    footerBg.setAttribute('height', 36);
    footerBg.setAttribute('fill', '#f8f9fa');
    svgEl.appendChild(footerBg);

    var footerLine = document.createElementNS(NS, 'line');
    footerLine.setAttribute('x1', 0);
    footerLine.setAttribute('y1', footerY);
    footerLine.setAttribute('x2', SLIDE_W);
    footerLine.setAttribute('y2', footerY);
    footerLine.setAttribute('stroke', '#e2e8f0');
    footerLine.setAttribute('stroke-width', '1');
    svgEl.appendChild(footerLine);

    // Footer text items
    var footerParts = [];
    if (pin.methodText) footerParts.push(pin.methodText);
    if (pin.sampleN) footerParts.push(pin.sampleN);
    footerParts.push(new Date().toLocaleDateString());
    footerParts.push('Turas Key Driver');

    var footerText = document.createElementNS(NS, 'text');
    footerText.setAttribute('x', 48);
    footerText.setAttribute('y', footerY + 23);
    footerText.setAttribute('fill', '#5c4a2a');
    footerText.setAttribute('font-size', '11');
    footerText.setAttribute('font-weight', '600');
    footerText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
    footerText.textContent = footerParts.join('  \u2022  ');
    svgEl.appendChild(footerText);

    return new XMLSerializer().serializeToString(svgEl);
  }

  /**
   * Render SVG string to PNG via Canvas at 3x scale.
   * @param {string} svgString - SVG markup
   * @param {Object} pin - Pin data (for filename)
   */
  function renderSVGtoPNG(svgString, pin) {
    var blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var img = new Image();

    img.onload = function() {
      var canvas = document.createElement('canvas');
      canvas.width = SLIDE_W * SCALE;
      canvas.height = SLIDE_H * SCALE;
      var ctx = canvas.getContext('2d');

      // White background
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Scale and draw
      ctx.scale(SCALE, SCALE);
      ctx.drawImage(img, 0, 0, SLIDE_W, SLIDE_H);

      URL.revokeObjectURL(url);

      canvas.toBlob(function(pngBlob) {
        if (pngBlob) {
          var filename = (pin.panelLabel || 'keydriver') + '_' +
            (pin.sectionTitle || 'slide').replace(/\s+/g, '_') + '.png';
          kdDownloadBlob(pngBlob, filename);
        }
      }, 'image/png');
    };

    img.onerror = function() {
      URL.revokeObjectURL(url);
      console.error('Failed to render slide SVG to image');
    };

    img.src = url;
  }

  /**
   * Extract table data from HTML table string for SVG rendering.
   * @param {string} tableHtml
   * @returns {Object|null} { headers: string[], rows: string[][] }
   */
  window.kdExtractSlideTableData = function(tableHtml) {
    if (!tableHtml) return null;
    var tempDiv = document.createElement('div');
    tempDiv.innerHTML = tableHtml;
    var table = tempDiv.querySelector('table');
    if (!table) return null;

    var headers = [];
    var rows = [];

    // Headers
    var ths = table.querySelectorAll('thead th');
    ths.forEach(function(th) { headers.push(th.textContent.trim()); });

    // Limit columns for readability on slide
    var maxCols = Math.min(headers.length, 8);
    headers = headers.slice(0, maxCols);

    // Rows (limit to first 12 for slide)
    var trs = table.querySelectorAll('tbody tr');
    var maxRows = Math.min(trs.length, 12);
    for (var i = 0; i < maxRows; i++) {
      var tds = trs[i].querySelectorAll('td');
      var row = [];
      for (var j = 0; j < maxCols && j < tds.length; j++) {
        row.push(tds[j].textContent.trim());
      }
      rows.push(row);
    }

    return { headers: headers, rows: rows };
  };

  /**
   * Render a table as SVG elements.
   * @param {SVGElement} parent - Parent SVG element
   * @param {Object} tableData - { headers, rows }
   * @param {number} x - X position
   * @param {number} y - Y position
   * @param {number} maxW - Maximum width
   * @param {number} maxH - Maximum height
   * @returns {number} Total height used
   */
  function kdRenderTableSVG(parent, tableData, x, y, maxW, maxH) {
    var nCols = tableData.headers.length;
    if (nCols === 0) return 0;

    var colW = Math.floor(maxW / nCols);
    var rowH = 22;
    var headerH = 26;
    var fontSize = 10;

    // Header background — dark, matching tabs export style
    var headerBg = document.createElementNS(NS, 'rect');
    headerBg.setAttribute('x', x);
    headerBg.setAttribute('y', y);
    headerBg.setAttribute('width', maxW);
    headerBg.setAttribute('height', headerH);
    headerBg.setAttribute('fill', '#1a2744');
    headerBg.setAttribute('rx', '3');
    parent.appendChild(headerBg);

    // Header text — white on dark
    for (var h = 0; h < nCols; h++) {
      var hText = document.createElementNS(NS, 'text');
      hText.setAttribute('x', x + h * colW + 6);
      hText.setAttribute('y', y + 17);
      hText.setAttribute('fill', '#ffffff');
      hText.setAttribute('font-size', String(fontSize - 1));
      hText.setAttribute('font-weight', '600');
      hText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
      hText.textContent = truncateText(tableData.headers[h], colW - 8, fontSize - 1);
      parent.appendChild(hText);
    }

    // Row data
    var rowY = y + headerH;
    var maxRows = Math.min(tableData.rows.length, Math.floor((maxH - headerH) / rowH));

    for (var r = 0; r < maxRows; r++) {
      // Alternate row background
      if (r % 2 === 1) {
        var rowBg = document.createElementNS(NS, 'rect');
        rowBg.setAttribute('x', x);
        rowBg.setAttribute('y', rowY);
        rowBg.setAttribute('width', maxW);
        rowBg.setAttribute('height', rowH);
        rowBg.setAttribute('fill', '#fafafa');
        parent.appendChild(rowBg);
      }

      for (var c = 0; c < nCols && c < tableData.rows[r].length; c++) {
        var cellText = document.createElementNS(NS, 'text');
        cellText.setAttribute('x', x + c * colW + 6);
        cellText.setAttribute('y', rowY + 15);
        cellText.setAttribute('fill', '#1e293b');
        cellText.setAttribute('font-size', String(fontSize));
        cellText.setAttribute('font-weight', '400');
        cellText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
        cellText.textContent = truncateText(tableData.rows[r][c], colW - 8, fontSize);
        parent.appendChild(cellText);
      }
      rowY += rowH;
    }

    // Bottom border
    var bottomLine = document.createElementNS(NS, 'line');
    bottomLine.setAttribute('x1', x);
    bottomLine.setAttribute('y1', rowY);
    bottomLine.setAttribute('x2', x + maxW);
    bottomLine.setAttribute('y2', rowY);
    bottomLine.setAttribute('stroke', '#e2e8f0');
    bottomLine.setAttribute('stroke-width', '1');
    parent.appendChild(bottomLine);

    return rowY - y;
  }

  /**
   * Extract text content from non-table HTML (exec summary, key insights, findings).
   * Simpler replacement for catdriver's callout extraction — keydriver doesn't have
   * model confidence cards or top driver callouts.
   * @param {string} html
   * @returns {Array|null} Array of { title, items[] }
   */
  function kdExtractContentText(html) {
    if (!html) return null;
    var tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;

    var data = [];

    // Key insights list
    var insightItems = tempDiv.querySelectorAll('.kd-key-insight-item');
    if (insightItems.length > 0) {
      var items = [];
      insightItems.forEach(function(li) { items.push(li.textContent.trim()); });
      data.push({ title: 'Key Insights', items: items });
    }

    // Standout findings
    var findingItems = tempDiv.querySelectorAll('.kd-finding-item');
    if (findingItems.length > 0) {
      var items = [];
      findingItems.forEach(function(f) { items.push(f.textContent.trim()); });
      data.push({ title: 'Standout Findings', items: items });
    }

    // Overview comparison insights
    var compInsights = tempDiv.querySelectorAll('.kd-comp-insight');
    if (compInsights.length > 0) {
      var items = [];
      compInsights.forEach(function(ci) { items.push(ci.textContent.trim()); });
      data.push({ title: 'Cross-Outcome Insights', items: items });
    }

    // Overview card grid — extract summary info
    var compCards = tempDiv.querySelectorAll('.kd-comp-card');
    if (compCards.length > 0) {
      compCards.forEach(function(card) {
        var cardTitle = card.querySelector('.kd-comp-card-title');
        var title = cardTitle ? cardTitle.textContent.trim() : 'Outcome';
        var statEls = card.querySelectorAll('.kd-comp-card-stat');
        var items = [];
        statEls.forEach(function(s) { items.push(s.textContent.trim()); });
        data.push({ title: title, items: items });
      });
    }

    return data.length > 0 ? data : null;
  }

  /**
   * Render extracted content text as SVG elements (bullet list with section titles).
   * @param {SVGElement} parent
   * @param {Array} contentData - Array of { title, items[] }
   * @param {number} x
   * @param {number} y
   * @param {number} maxW
   * @param {number} maxH
   * @param {string} brandColour
   * @returns {number} Y position after rendering
   */
  function kdRenderContentTextSVG(parent, contentData, x, y, maxW, maxH, brandColour) {
    var currentY = y;
    var cardGap = 12;
    var lineHeight = 16;
    var maxY = y + maxH;

    contentData.forEach(function(card) {
      if (currentY >= maxY - 30) return;

      // Card title
      if (card.title) {
        var titleText = document.createElementNS(NS, 'text');
        titleText.setAttribute('x', x + 8);
        titleText.setAttribute('y', currentY + 16);
        titleText.setAttribute('fill', brandColour);
        titleText.setAttribute('font-size', '13');
        titleText.setAttribute('font-weight', '700');
        titleText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
        titleText.textContent = card.title;
        parent.appendChild(titleText);
        currentY += 24;
      }

      // Card items
      card.items.forEach(function(item) {
        if (currentY >= maxY - 16) return;
        var wrapped = kdWrapTextLines(item, maxW - 24, 7);
        wrapped.forEach(function(line, li) {
          if (currentY >= maxY - 16) return;
          var lineText = document.createElementNS(NS, 'text');
          lineText.setAttribute('x', x + 16);
          lineText.setAttribute('y', currentY + 12);
          lineText.setAttribute('fill', '#334155');
          lineText.setAttribute('font-size', '11');
          lineText.setAttribute('font-weight', '400');
          lineText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
          lineText.textContent = (li === 0 ? '\u2022 ' : '  ') + line;
          parent.appendChild(lineText);
          currentY += lineHeight;
        });
        currentY += 4;
      });
      currentY += cardGap;
    });

    return currentY;
  }

  /**
   * Truncate text to fit within a pixel width.
   * @param {string} text
   * @param {number} maxPixels
   * @param {number} fontSize
   * @returns {string}
   */
  function truncateText(text, maxPixels, fontSize) {
    if (!text) return '';
    var charW = fontSize * 0.6;
    var maxChars = Math.floor(maxPixels / charW);
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars - 1) + '\u2026';
  }

})();
