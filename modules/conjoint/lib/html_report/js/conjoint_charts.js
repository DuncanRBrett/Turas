/**
 * Conjoint Report Chart Utilities
 * HSL colour generation, chart rebuild helpers for LC comparison.
 */

(function() {
  "use strict";

  // === HSL COLOUR UTILITIES ===

  /**
   * Generate N distinct HSL colours
   * @param {number} n Number of colours needed
   * @param {number} saturation 0-100
   * @param {number} lightness 0-100
   * @returns {string[]} Array of HSL colour strings
   */
  window.generateHSLPalette = function(n, saturation, lightness) {
    saturation = saturation || 55;
    lightness = lightness || 45;
    var colours = [];
    for (var i = 0; i < n; i++) {
      var hue = (i * 360 / n + 220) % 360;
      colours.push("hsl(" + Math.round(hue) + "," + saturation + "%," + lightness + "%)");
    }
    return colours;
  };


  // === REBUILD CHART SVG ===

  /**
   * Rebuild an SVG chart from data attributes (for dynamic updates).
   * Used by LC class comparison column picker.
   */
  window.rebuildChartSVG = function(chartId) {
    var wrap = document.querySelector('[data-chart-id="' + chartId + '"]');
    if (!wrap) return;

    // Get data from the corresponding table
    var panel = wrap.closest(".cj-panel") || wrap.closest(".cj-card");
    if (!panel) return;

    var table = panel.querySelector('.cj-table[data-table-id="class-importance"]');
    if (!table) return;

    // Extract data from table
    var headers = [];
    var classCols = [];
    table.querySelectorAll("thead th").forEach(function(th) {
      var key = th.getAttribute("data-col-key");
      if (key && key !== "attribute") {
        classCols.push({ key: key, label: th.textContent.trim() });
      }
    });

    if (classCols.length === 0) return;

    var attributes = [];
    var classData = {};
    classCols.forEach(function(c) { classData[c.key] = []; });

    table.querySelectorAll("tbody tr").forEach(function(tr) {
      var attrCell = tr.querySelector('td[data-col-key="attribute"]');
      if (attrCell) {
        attributes.push(attrCell.getAttribute("data-export-value") || attrCell.textContent.trim());
      }
      classCols.forEach(function(c) {
        var cell = tr.querySelector('td[data-col-key="' + c.key + '"]');
        var val = cell ? parseFloat(cell.getAttribute("data-export-value") || cell.textContent) : 0;
        classData[c.key].push(isNaN(val) ? 0 : val);
      });
    });

    if (attributes.length === 0) return;

    // Build grouped bar chart
    var nAttrs = attributes.length;
    var nClasses = classCols.length;
    var palette = ["#323367", "#2d8a6e", "#c46a3a", "#8b5e9b", "#3a7bc8", "#c45d5d"];
    var brand = getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim();
    if (brand) palette[0] = brand;

    var chartW = Math.max(400, nAttrs * (nClasses * 30 + 40) + 200);
    var chartH = 280;
    var ml = 50, mr = 100, mt = 20, mb = 70;
    var pw = chartW - ml - mr, ph = chartH - mt - mb;
    var groupW = pw / nAttrs;
    var barW = Math.min(26, (groupW * 0.7) / nClasses);

    var allVals = [];
    classCols.forEach(function(c) { allVals = allVals.concat(classData[c.key]); });
    var maxVal = Math.max.apply(null, allVals.concat([50])) * 1.1;

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + chartW + ' ' + chartH + '" width="100%" style="max-width:' + chartW + 'px;font-family:system-ui,sans-serif;">';

    // Y gridlines
    for (var g = 0; g <= maxVal; g += 10) {
      var gy = mt + (1 - g / maxVal) * ph;
      svg += '<line x1="' + ml + '" y1="' + gy.toFixed(1) + '" x2="' + (chartW - mr) + '" y2="' + gy.toFixed(1) + '" stroke="#e2e8f0" stroke-width="1"/>';
      svg += '<text x="' + (ml - 6) + '" y="' + gy.toFixed(1) + '" text-anchor="end" fill="#64748b" font-size="10" dominant-baseline="central">' + g + '%</text>';
    }

    // Bars
    for (var i = 0; i < nAttrs; i++) {
      var gx = ml + i * groupW;
      var gc = gx + groupW / 2;

      for (var j = 0; j < nClasses; j++) {
        var val = classData[classCols[j].key][i];
        var bx = gc - (nClasses * barW) / 2 + j * barW;
        var by = mt + (1 - val / maxVal) * ph;
        var bh = mt + ph - by;

        svg += '<rect x="' + bx.toFixed(1) + '" y="' + by.toFixed(1) + '" width="' + (barW - 2).toFixed(1) + '" height="' + Math.max(bh, 1).toFixed(1) + '" rx="4" fill="' + (palette[j] || palette[0]) + '" opacity="0.8"/>';
        svg += '<text x="' + (bx + (barW - 2) / 2).toFixed(1) + '" y="' + (by - 4).toFixed(1) + '" text-anchor="middle" fill="#334155" font-size="9" font-weight="500">' + Math.round(val) + '</text>';
      }

      // Attribute label
      var lbl = attributes[i];
      if (lbl.length > 12) lbl = lbl.substring(0, 11) + "\u2026";
      svg += '<text x="' + gc.toFixed(1) + '" y="' + (chartH - mb + 12) + '" text-anchor="end" fill="#64748b" font-size="10" transform="rotate(-45,' + gc.toFixed(1) + ',' + (chartH - mb + 12) + ')">' + lbl + '</text>';
    }

    // Legend
    var lx = chartW - mr + 10;
    for (var k = 0; k < nClasses; k++) {
      var ly = mt + k * 22;
      svg += '<rect x="' + lx + '" y="' + ly + '" width="14" height="14" rx="3" fill="' + (palette[k] || palette[0]) + '"/>';
      svg += '<text x="' + (lx + 20) + '" y="' + (ly + 10) + '" fill="#64748b" font-size="10" dominant-baseline="central">' + classCols[k].label + '</text>';
    }

    svg += '</svg>';
    wrap.innerHTML = svg;
  };

})();
