/* ==============================================================================
 * CATDRIVER HTML REPORT - SLIDE EXPORT (PNG)
 * ==============================================================================
 * Exports pinned views as presentation-quality PNG slides.
 * Layout: PowerPoint landscape 1280×720 at 3× scale → 3840×2160 PNG.
 * Uses native Canvas API — no external libraries.
 * All functions prefixed cd to avoid global namespace conflicts.
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
  window.cdExportPinnedCardPNG = function(pinId) {
    var pins = cdGetPinnedViews();
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
      .getPropertyValue('--cd-brand').trim() || '#323367';
    var accentColour = getComputedStyle(document.documentElement)
      .getPropertyValue('--cd-accent').trim() || '#CC9900';

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
    var titleLines = cdWrapTextLines(pin.sectionTitle, SLIDE_W - 96, 14);
    var titleText = cdCreateWrappedText(NS, titleLines, 48, yPos + 20, 28, {
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

      var insightLines = cdWrapTextLines(pin.insightText, SLIDE_W - 140, 7.5);
      var insightHeight = Math.max(40, insightLines.length * 18 + 16);

      insightBorder.setAttribute('height', insightHeight);
      insightBorder.setAttribute('fill', accentColour);
      svgEl.appendChild(insightBorder);

      // Insight background
      var insightBg = document.createElementNS(NS, 'rect');
      insightBg.setAttribute('x', 51);
      insightBg.setAttribute('y', yPos);
      insightBg.setAttribute('width', SLIDE_W - 99);
      insightBg.setAttribute('height', insightHeight);
      insightBg.setAttribute('fill', '#faf9f7');
      insightBg.setAttribute('rx', '4');
      svgEl.appendChild(insightBg);

      // Insight label
      var insightLabel = document.createElementNS(NS, 'text');
      insightLabel.setAttribute('x', 64);
      insightLabel.setAttribute('y', yPos + 16);
      insightLabel.setAttribute('fill', accentColour);
      insightLabel.setAttribute('font-size', '10');
      insightLabel.setAttribute('font-weight', '700');
      insightLabel.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
      insightLabel.textContent = 'ANALYST INSIGHT';
      svgEl.appendChild(insightLabel);

      // Insight text
      var insightTextEl = cdCreateWrappedText(NS, insightLines, 64, yPos + 32, 18, {
        fill: '#475569',
        fontSize: '13',
        fontWeight: '400'
      });
      svgEl.appendChild(insightTextEl);

      yPos += insightHeight + 16;
    }

    // Chart (if present)
    var chartArea = SLIDE_H - yPos - 60; // Reserve 60px for footer
    if (pin.chartSvg && chartArea > 80) {
      var chartGroup = document.createElementNS(NS, 'g');

      // Parse the captured SVG to extract its content
      var tempDiv = document.createElement('div');
      tempDiv.innerHTML = pin.chartSvg;
      var sourceSvg = tempDiv.querySelector('svg');

      if (sourceSvg) {
        var svgW = parseFloat(sourceSvg.getAttribute('width')) || 700;
        var svgH = parseFloat(sourceSvg.getAttribute('height')) || 350;

        // If viewBox exists, use those dimensions
        var vb = sourceSvg.getAttribute('viewBox');
        if (vb) {
          var parts = vb.split(/[\s,]+/);
          if (parts.length >= 4) {
            svgW = parseFloat(parts[2]);
            svgH = parseFloat(parts[3]);
          }
        }

        var maxChartW = SLIDE_W - 96;
        var maxChartH = Math.min(chartArea - 8, 360);
        var scaleX = maxChartW / svgW;
        var scaleY = maxChartH / svgH;
        var chartScale = Math.min(scaleX, scaleY, 1.0);
        var scaledW = svgW * chartScale;
        var scaledH = svgH * chartScale;
        var chartX = 48 + (maxChartW - scaledW) / 2;

        // Use foreignObject to embed the chart SVG
        var fo = document.createElementNS(NS, 'foreignObject');
        fo.setAttribute('x', chartX);
        fo.setAttribute('y', yPos);
        fo.setAttribute('width', scaledW);
        fo.setAttribute('height', scaledH);

        var innerDiv = document.createElement('div');
        innerDiv.setAttribute('xmlns', 'http://www.w3.org/1999/xhtml');
        innerDiv.style.cssText = 'width:100%;height:100%;overflow:hidden;';
        innerDiv.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="' + scaledW +
          '" height="' + scaledH + '" viewBox="0 0 ' + svgW + ' ' + svgH + '">' +
          sourceSvg.innerHTML + '</svg>';

        fo.appendChild(innerDiv);
        chartGroup.appendChild(fo);
        svgEl.appendChild(chartGroup);

        yPos += scaledH + 12;
      }
    }

    // Table (if present and enough space)
    if (pin.tableHtml && !pin.chartSvg && (SLIDE_H - yPos - 60) > 80) {
      var tableData = cdExtractSlideTableData(pin.tableHtml);
      if (tableData && tableData.headers.length > 0) {
        cdRenderTableSVG(svgEl, tableData, 48, yPos, SLIDE_W - 96, SLIDE_H - yPos - 60);
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
    if (pin.modelType) footerParts.push(pin.modelType);
    if (pin.sampleN) footerParts.push(pin.sampleN);
    if (pin.r2Text) footerParts.push(pin.r2Text);
    footerParts.push(new Date().toLocaleDateString());
    footerParts.push('Turas Catdriver');

    var footerText = document.createElementNS(NS, 'text');
    footerText.setAttribute('x', 48);
    footerText.setAttribute('y', footerY + 23);
    footerText.setAttribute('fill', '#94a3b8');
    footerText.setAttribute('font-size', '11');
    footerText.setAttribute('font-weight', '400');
    footerText.setAttribute('font-family', '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif');
    footerText.textContent = footerParts.join('  \u2022  ');
    svgEl.appendChild(footerText);

    return new XMLSerializer().serializeToString(svgEl);
  }

  /**
   * Render SVG string to PNG via Canvas at 3× scale.
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
          var filename = (pin.panelLabel || 'catdriver') + '_' +
            (pin.sectionTitle || 'slide').replace(/\s+/g, '_') + '.png';
          cdDownloadBlob(pngBlob, filename);
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
  window.cdExtractSlideTableData = function(tableHtml) {
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
   */
  function cdRenderTableSVG(parent, tableData, x, y, maxW, maxH) {
    var nCols = tableData.headers.length;
    if (nCols === 0) return;

    var colW = Math.floor(maxW / nCols);
    var rowH = 22;
    var headerH = 26;
    var fontSize = 10;

    var brandColour = getComputedStyle(document.documentElement)
      .getPropertyValue('--cd-brand').trim() || '#323367';

    // Header background
    var headerBg = document.createElementNS(NS, 'rect');
    headerBg.setAttribute('x', x);
    headerBg.setAttribute('y', y);
    headerBg.setAttribute('width', maxW);
    headerBg.setAttribute('height', headerH);
    headerBg.setAttribute('fill', '#f8f9fa');
    headerBg.setAttribute('rx', '3');
    parent.appendChild(headerBg);

    // Header text
    for (var h = 0; h < nCols; h++) {
      var hText = document.createElementNS(NS, 'text');
      hText.setAttribute('x', x + h * colW + 6);
      hText.setAttribute('y', y + 17);
      hText.setAttribute('fill', '#64748b');
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
