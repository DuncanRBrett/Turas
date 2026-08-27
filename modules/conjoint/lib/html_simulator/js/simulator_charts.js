/**
 * Conjoint Simulator SVG Charts
 * Market share bars, sensitivity, source of volume, demand curve.
 * Follows Turas visual standards: rx=4, muted palette, #64748b labels.
 */

var SimCharts = (function() {
  "use strict";

  var brandColour = "#323367";
  var palette = ["#323367", "#2d8a6e", "#c46a3a", "#8b5e9b", "#3a7bc8", "#c45d5d", "#5ea37a", "#b07d4f"];

  function setBrand(colour) { brandColour = colour || "#323367"; palette[0] = brandColour; }

  function getColour(i) { return palette[i % palette.length]; }


  // === MARKET SHARE BARS ===

  // Inject CSS for animated bar transitions (once)
  var _barStyleInjected = false;
  function _injectBarAnimStyle() {
    if (_barStyleInjected) return;
    _barStyleInjected = true;
    var style = document.createElement("style");
    style.textContent = ".cj-bar-anim { transition: width 300ms ease-in-out; }";
    document.head.appendChild(style);
  }

  function renderShareBars(containerId, products, shares) {
    var container = document.getElementById(containerId);
    if (!container) return;
    _injectBarAnimStyle();

    var n = shares.length;
    var w = 960, barH = 38, gap = 14, ml = 200, mr = 80;
    var h = n * (barH + gap) + 20;
    var pw = w - ml - mr;
    var maxShare = Math.max.apply(null, shares.concat([50]));

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';

    // Vertical gridlines every 10%
    for (var g = 10; g <= maxShare; g += 10) {
      var gx = ml + (g / maxShare) * pw;
      svg += '<line x1="' + gx.toFixed(1) + '" y1="0" x2="' + gx.toFixed(1) + '" y2="' + h + '" stroke="#e2e8f0" stroke-width="0.5"/>';
      svg += '<text x="' + gx.toFixed(1) + '" y="' + (h - 2) + '" text-anchor="middle" fill="#cbd5e1" font-size="9">' + g + '%</text>';
    }

    for (var i = 0; i < n; i++) {
      var y = i * (barH + gap) + 10;
      var bw = Math.max((shares[i] / maxShare) * pw, 2);
      var label = products[i].name || ("Product " + (i + 1));
      if (label.length > 20) label = label.substring(0, 19) + "\u2026";

      // Product name
      svg += '<text x="' + (ml - 8) + '" y="' + (y + barH / 2 - 6) + '" text-anchor="end" fill="#334155" font-size="12" font-weight="500" dominant-baseline="central">' + escSvg(label) + '</text>';

      // Descriptor subtitle (first 3 attribute values)
      var desc = getProductDescriptor(products[i].config, 3);
      if (desc) {
        svg += '<text x="' + (ml - 8) + '" y="' + (y + barH / 2 + 8) + '" text-anchor="end" fill="#94a3b8" font-size="9" dominant-baseline="central">' + escSvg(desc) + '</text>';
      }

      svg += '<rect class="cj-bar-anim" x="' + ml + '" y="' + y + '" width="' + bw.toFixed(1) + '" height="' + barH + '" rx="4" fill="' + getColour(i) + '" opacity="0.8"/>';

      // Share percentage label: white on bar if wide enough, else to the right
      var shareLabel = shares[i].toFixed(1) + '%';
      if (bw > 50) {
        svg += '<text x="' + (ml + bw - 8).toFixed(1) + '" y="' + (y + barH / 2) + '" text-anchor="end" fill="#ffffff" font-size="12" font-weight="600" dominant-baseline="central">' + shareLabel + '</text>';
      } else {
        svg += '<text x="' + (ml + bw + 6).toFixed(1) + '" y="' + (y + barH / 2) + '" fill="#334155" font-size="12" font-weight="600" dominant-baseline="central">' + shareLabel + '</text>';
      }
    }

    svg += '</svg>';

    // Product configuration grid below the chart
    var gridHtml = buildProductGrid(products, shares);
    container.innerHTML = svg + gridHtml;

    // Add sticky annotations showing share percentage on each bar
    _injectAnnotationStyle();
    var svgEl = container.querySelector("svg");
    // Enable click-to-annotate on bars (user can add custom notes)
    _enableClickAnnotations(container);
  }

  function getProductDescriptor(config, maxAttrs) {
    if (!config) return "";
    var keys = Object.keys(config);
    var vals = keys.slice(0, maxAttrs).map(function(k) { return config[k]; });
    var desc = vals.join(", ");
    if (desc.length > 40) desc = desc.substring(0, 39) + "\u2026";
    return desc;
  }

  function buildProductGrid(products, shares) {
    if (!products || products.length === 0) return "";
    var data = (typeof SimEngine !== "undefined") ? SimEngine.getData() : null;
    if (!data || !data.attributes) return "";

    // Detect price attribute for revenue column
    var priceAttr = null;
    for (var ai = 0; ai < data.attributes.length; ai++) {
      var aName = data.attributes[ai].name.toLowerCase();
      if (aName.indexOf("price") >= 0 || aName.indexOf("cost") >= 0 || aName.indexOf("fee") >= 0) {
        priceAttr = data.attributes[ai].name;
        break;
      }
    }

    var html = '<div style="overflow-x:auto;">';
    html += '<table class="cj-table" style="margin-top:16px;font-size:12px;width:100%;min-width:500px;">';
    html += '<thead><tr>';
    html += '<th>Product</th>';
    data.attributes.forEach(function(a) {
      html += '<th>' + escSvg(a.name) + '</th>';
    });
    html += '<th style="text-align:right;">Share (%)</th>';
    if (priceAttr) html += '<th style="text-align:right;">Revenue Index</th>';
    html += '</tr></thead><tbody>';

    products.forEach(function(prod, i) {
      html += '<tr>';
      html += '<td style="font-weight:500;"><span style="display:inline-block;width:10px;height:10px;border-radius:3px;background:' + getColour(i) + ';margin-right:6px;vertical-align:middle;"></span>' + escSvg(prod.name) + '</td>';
      data.attributes.forEach(function(a) {
        html += '<td>' + escSvg(prod.config[a.name] || "") + '</td>';
      });
      var sh = shares && shares[i] !== undefined ? shares[i].toFixed(1) : "";
      html += '<td style="text-align:right;font-weight:600;">' + sh + '</td>';
      if (priceAttr) {
        var priceVal = prod.config ? prod.config[priceAttr] : "";
        var priceNum = parseFloat(String(priceVal || "0").replace(/[^0-9.\-]/g, ""));
        var rev = (!isNaN(priceNum) && shares && shares[i] !== undefined) ? ((shares[i] / 100) * priceNum).toFixed(2) : "";
        html += '<td style="text-align:right;font-weight:600;">' + rev + '</td>';
      }
      html += '</tr>';
    });

    html += '</tbody></table></div>';
    return html;
  }


  // === SENSITIVITY LINE CHART ===

  function renderSensitivity(containerId, sweepResults, attrName, productName) {
    var container = document.getElementById(containerId);
    if (!container || !sweepResults || sweepResults.length === 0) return;

    var n = sweepResults.length;
    var w = 960, h = 540, ml = 70, mr = 40, mt = 36, mb = 80;
    var pw = w - ml - mr, ph = h - mt - mb;
    var maxS = Math.max.apply(null, sweepResults.map(function(r) { return r.share; }).concat([50]));
    var minS = Math.min.apply(null, sweepResults.map(function(r) { return r.share; }).concat([0]));
    if (maxS - minS < 1) maxS = minS + 10;

    var titleLabel = productName || "Product 1";
    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';
    svg += '<text x="' + (w / 2) + '" y="16" text-anchor="middle" fill="#334155" font-size="13" font-weight="500">' + escSvg(attrName) + ' Sensitivity (' + escSvg(titleLabel) + ')</text>';

    // Gridlines
    var yStep = niceStep(maxS - minS, 4);
    for (var gy = Math.ceil(minS / yStep) * yStep; gy <= maxS; gy += yStep) {
      var yy = mt + (1 - (gy - minS) / (maxS - minS)) * ph;
      svg += '<line x1="' + ml + '" y1="' + yy.toFixed(1) + '" x2="' + (w - mr) + '" y2="' + yy.toFixed(1) + '" stroke="#e2e8f0" stroke-width="1"/>';
      svg += '<text x="' + (ml - 6) + '" y="' + yy.toFixed(1) + '" text-anchor="end" fill="#64748b" font-size="10" dominant-baseline="central">' + gy.toFixed(0) + '%</text>';
    }

    // Line + points
    var points = [];
    for (var i = 0; i < n; i++) {
      var x = ml + (i / Math.max(n - 1, 1)) * pw;
      var y = mt + (1 - (sweepResults[i].share - minS) / (maxS - minS)) * ph;
      points.push(x.toFixed(1) + "," + y.toFixed(1));

      svg += '<circle cx="' + x.toFixed(1) + '" cy="' + y.toFixed(1) + '" r="5" fill="' + brandColour + '"/>';
      svg += '<text x="' + x.toFixed(1) + '" y="' + (y - 10).toFixed(1) + '" text-anchor="middle" fill="#334155" font-size="10" font-weight="500">' + sweepResults[i].share.toFixed(1) + '%</text>';

      var lbl = sweepResults[i].level;
      if (lbl.length > 12) lbl = lbl.substring(0, 11) + "\u2026";
      svg += '<text x="' + x.toFixed(1) + '" y="' + (h - mb + 16) + '" text-anchor="end" fill="#64748b" font-size="10" transform="rotate(-35,' + x.toFixed(1) + ',' + (h - mb + 16) + ')">' + lbl + '</text>';
    }

    if (points.length > 1) {
      svg += '<polyline points="' + points.join(" ") + '" fill="none" stroke="' + brandColour + '" stroke-width="2.5"/>';
    }

    svg += '</svg>';
    container.innerHTML = svg;

    // Enable click-to-annotate on the sensitivity chart
    _enableClickAnnotations(container);
  }


  // === SOURCE OF VOLUME ===

  function renderSourceOfVolume(containerId, sovResults, allProducts) {
    var container = document.getElementById(containerId);
    if (!container || !sovResults || sovResults.length === 0) return;

    var n = sovResults.length;
    var w = 960, barH = 28, gap = 10, ml = 200, mr = 120;
    var h = n * (barH + gap) * 2 + 60;
    var pw = w - ml - mr;

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';

    var yPos = 20;
    sovResults.forEach(function(item, i) {
      var label = escSvg(item.product);
      if (label.length > 20) label = label.substring(0, 19) + "\u2026";
      svg += '<text x="' + (ml - 8) + '" y="' + (yPos + barH / 2) + '" text-anchor="end" fill="#334155" font-size="11" font-weight="500" dominant-baseline="central">' + label + '</text>';

      var bw1 = Math.max((item.baseline / 100) * pw, 0);
      svg += '<rect x="' + ml + '" y="' + yPos + '" width="' + bw1.toFixed(1) + '" height="' + barH + '" rx="4" fill="#94a3b8" opacity="0.5"/>';
      svg += '<text x="' + (ml + bw1 + 4).toFixed(1) + '" y="' + (yPos + barH / 2) + '" fill="#94a3b8" font-size="10" dominant-baseline="central">' + item.baseline.toFixed(1) + '%</text>';
      yPos += barH + 2;

      var bw2 = Math.max((item.test / 100) * pw, 0);
      svg += '<rect x="' + ml + '" y="' + yPos + '" width="' + bw2.toFixed(1) + '" height="' + barH + '" rx="4" fill="' + getColour(i) + '" opacity="0.8"/>';

      var changeStr = (item.change >= 0 ? "+" : "") + item.change.toFixed(1) + "pp";
      var changeColour = item.change >= 0 ? "#16a34a" : "#dc2626";
      svg += '<text x="' + (ml + bw2 + 4).toFixed(1) + '" y="' + (yPos + barH / 2) + '" fill="' + changeColour + '" font-size="10" font-weight="500" dominant-baseline="central">' + item.test.toFixed(1) + '% (' + changeStr + ')</text>';
      yPos += barH + gap + 6;
    });

    // Legend
    svg += '<text x="' + ml + '" y="' + (yPos + 5) + '" fill="#94a3b8" font-size="10">Grey = Baseline | Colour = With new product</text>';

    svg += '</svg>';

    // SOV comparison grid
    var gridHtml = buildSovGrid(sovResults);
    container.innerHTML = svg + gridHtml;
  }

  function buildSovGrid(sovResults) {
    if (!sovResults || sovResults.length === 0) return "";
    var html = '<table class="cj-table" style="margin-top:16px;font-size:12px;">';
    html += '<thead><tr>';
    html += '<th>Product</th><th style="text-align:right;">Baseline %</th><th style="text-align:right;">With Entrant %</th><th style="text-align:right;">Change (pp)</th>';
    html += '</tr></thead><tbody>';

    sovResults.forEach(function(item, i) {
      var changeStr = (item.change >= 0 ? "+" : "") + item.change.toFixed(1);
      var changeClass = item.change >= 0 ? "cj-positive" : "cj-negative";
      html += '<tr>';
      html += '<td style="font-weight:500;"><span style="display:inline-block;width:10px;height:10px;border-radius:3px;background:' + getColour(i) + ';margin-right:6px;vertical-align:middle;"></span>' + escSvg(item.product) + '</td>';
      html += '<td style="text-align:right;">' + item.baseline.toFixed(1) + '</td>';
      html += '<td style="text-align:right;">' + item.test.toFixed(1) + '</td>';
      html += '<td style="text-align:right;" class="' + changeClass + '">' + changeStr + '</td>';
      html += '</tr>';
    });

    html += '</tbody></table>';
    return html;
  }


  // === DEMAND CURVE ===

  function renderDemandCurve(containerId, curveData, options) {
    var container = document.getElementById(containerId);
    if (!container || !curveData || curveData.length === 0) return;

    options = options || {};
    var title = options.title || "Demand Curve";
    var xLabel = options.xLabel || "Price Level";
    var yLabel = options.yLabel || "Predicted Share (%)";
    var optimalPrice = options.optimalPrice || null;

    var n = curveData.length;
    var w = 960, h = 540, ml = 75, mr = 40, mt = 40, mb = 70;
    var pw = w - ml - mr, ph = h - mt - mb;
    var maxS = Math.max.apply(null, curveData.map(function(d) { return d.share; })) * 1.15;
    var minS = 0;
    if (maxS < 10) maxS = 10;

    var uid = "dc-" + Math.random().toString(36).substring(2, 8);

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';

    // Title
    svg += '<text x="' + (w / 2) + '" y="18" text-anchor="middle" fill="#334155" font-size="13" font-weight="500">' + escSvg(title) + '</text>';

    // Y-axis label
    svg += '<text x="14" y="' + (mt + ph / 2) + '" text-anchor="middle" fill="#64748b" font-size="10" font-weight="400" transform="rotate(-90,14,' + (mt + ph / 2) + ')">' + escSvg(yLabel) + '</text>';

    // X-axis label
    svg += '<text x="' + (ml + pw / 2) + '" y="' + (h - 6) + '" text-anchor="middle" fill="#64748b" font-size="10" font-weight="400">' + escSvg(xLabel) + '</text>';

    // Horizontal gridlines
    var yStep = niceStep(maxS - minS, 5);
    for (var gy = yStep; gy <= maxS; gy += yStep) {
      var yy = mt + (1 - (gy - minS) / (maxS - minS)) * ph;
      svg += '<line x1="' + ml + '" y1="' + yy.toFixed(1) + '" x2="' + (w - mr) + '" y2="' + yy.toFixed(1) + '" stroke="#e2e8f0" stroke-width="0.5"/>';
      svg += '<text x="' + (ml - 6) + '" y="' + yy.toFixed(1) + '" text-anchor="end" fill="#64748b" font-size="9" dominant-baseline="central">' + gy.toFixed(0) + '%</text>';
    }

    // Area fill under the curve
    var points = [];
    var areaPoints = [];
    for (var i = 0; i < n; i++) {
      var x = ml + (i / Math.max(n - 1, 1)) * pw;
      var y = mt + (1 - curveData[i].share / maxS) * ph;
      points.push({ x: x, y: y });
      areaPoints.push(x.toFixed(1) + "," + y.toFixed(1));
    }

    // Area fill polygon
    if (areaPoints.length > 1) {
      var areaPath = areaPoints.join(" ") + " " + points[n - 1].x.toFixed(1) + "," + (mt + ph) + " " + points[0].x.toFixed(1) + "," + (mt + ph);
      svg += '<polygon points="' + areaPath + '" fill="' + brandColour + '" opacity="0.07"/>';
    }

    // Line
    if (areaPoints.length > 1) {
      svg += '<polyline points="' + areaPoints.join(" ") + '" fill="none" stroke="' + brandColour + '" stroke-width="2.5" stroke-linejoin="round"/>';
    }

    // Optimal price marker
    if (optimalPrice) {
      for (var oi = 0; oi < n; oi++) {
        if (curveData[oi].level === optimalPrice.level) {
          var ox = points[oi].x;
          var oy = points[oi].y;
          svg += '<line x1="' + ox.toFixed(1) + '" y1="' + oy.toFixed(1) + '" x2="' + ox.toFixed(1) + '" y2="' + (mt + ph) + '" stroke="#16a34a" stroke-width="1" stroke-dasharray="4,3"/>';
          svg += '<text x="' + ox.toFixed(1) + '" y="' + (mt + ph + 12) + '" text-anchor="middle" fill="#16a34a" font-size="9" font-weight="500">Optimal</text>';
          break;
        }
      }
    }

    // Data points with hover targets
    for (var i = 0; i < n; i++) {
      var px = points[i].x;
      var py = points[i].y;

      // Invisible larger hit area for hover
      svg += '<circle cx="' + px.toFixed(1) + '" cy="' + py.toFixed(1) + '" r="14" fill="transparent" class="' + uid + '-hover-target" data-idx="' + i + '" style="cursor:pointer;"/>';

      // Visible dot
      svg += '<circle cx="' + px.toFixed(1) + '" cy="' + py.toFixed(1) + '" r="5" fill="' + brandColour + '" stroke="#fff" stroke-width="1.5" style="pointer-events:none;"/>';

      // Data label
      svg += '<text x="' + px.toFixed(1) + '" y="' + (py - 10).toFixed(1) + '" text-anchor="middle" fill="#334155" font-size="9" font-weight="500" style="pointer-events:none;">' + curveData[i].share.toFixed(1) + '%</text>';

      // X-axis tick label
      var tickLabel = curveData[i].level;
      if (String(tickLabel).length > 10) tickLabel = String(tickLabel).substring(0, 9) + "\u2026";
      if (n <= 8) {
        svg += '<text x="' + px.toFixed(1) + '" y="' + (mt + ph + 16) + '" text-anchor="middle" fill="#64748b" font-size="10">' + escSvg(tickLabel) + '</text>';
      } else {
        svg += '<text x="' + px.toFixed(1) + '" y="' + (mt + ph + 16) + '" text-anchor="end" fill="#64748b" font-size="9" transform="rotate(-35,' + px.toFixed(1) + ',' + (mt + ph + 16) + ')">' + escSvg(tickLabel) + '</text>';
      }
    }

    // Tooltip container (rendered as foreignObject for HTML tooltip)
    svg += '<foreignObject x="0" y="0" width="' + w + '" height="' + h + '" style="pointer-events:none;">';
    svg += '<div xmlns="http://www.w3.org/1999/xhtml" id="' + uid + '-tip" style="display:none;position:absolute;background:#1e293b;color:#f8fafc;padding:6px 10px;border-radius:4px;font-size:11px;line-height:1.5;pointer-events:none;white-space:nowrap;"></div>';
    svg += '</foreignObject>';

    svg += '</svg>';
    container.innerHTML = svg;

    // Attach hover listeners for tooltips
    var tipEl = document.getElementById(uid + "-tip");
    var targets = container.querySelectorAll("." + uid + "-hover-target");
    targets.forEach(function(el) {
      el.addEventListener("mouseenter", function(e) {
        var idx = parseInt(el.getAttribute("data-idx"), 10);
        if (isNaN(idx) || !curveData[idx]) return;
        var d = curveData[idx];
        var tipText = d.level + ": " + d.share.toFixed(1) + "%";
        if (d.elasticity !== undefined) tipText += " | Elasticity: " + d.elasticity.toFixed(2);
        if (tipEl) {
          tipEl.textContent = tipText;
          tipEl.style.display = "block";
          tipEl.style.left = (points[idx].x - 40) + "px";
          tipEl.style.top = (points[idx].y - 34) + "px";
        }
      });
      el.addEventListener("mouseleave", function() {
        if (tipEl) tipEl.style.display = "none";
      });
    });
  }


  // === UTILITY ===

  function niceStep(range, targetTicks) {
    var rough = range / (targetTicks || 4);
    var mag = Math.pow(10, Math.floor(Math.log10(rough)));
    var candidates = [1, 2, 5, 10];
    var best = mag;
    candidates.forEach(function(c) {
      if (Math.abs(c * mag - rough) < Math.abs(best - rough)) best = c * mag;
    });
    return best || 1;
  }


  // === STICKY ANNOTATIONS ===

  /**
   * Create a sticky annotation label at a given position within a chart container.
   * The annotation is a small tooltip-like div with a triangle pointer underneath.
   * @param {HTMLElement} chartContainer - The container element (must have position:relative)
   * @param {number} x - Left position in pixels
   * @param {number} y - Top position in pixels (annotation appears above this point)
   * @param {string} text - Label text
   * @returns {HTMLElement} The annotation element
   */
  // ========================================================
  // CLICK-TO-ANNOTATE: User can click any chart area to add a custom note
  // Annotations persist in the DOM and are included in Save Report
  // ========================================================

  var _annStyleInjected = false;
  function _injectAnnotationStyle() {
    if (_annStyleInjected) return;
    _annStyleInjected = true;
    var style = document.createElement("style");
    style.textContent = [
      ".cj-chart-annotation { position:absolute; background:#fff; border:1px solid #e2e8f0; border-radius:6px; padding:6px 10px; font-size:11px; font-weight:500; color:#1e293b; white-space:nowrap; z-index:5; box-shadow:0 1px 4px rgba(0,0,0,0.10); cursor:move; transform:translate(-50%,-100%); margin-top:-10px; }",
      ".cj-chart-annotation::after { content:''; position:absolute; left:50%; bottom:-5px; transform:translateX(-50%); width:0; height:0; border-left:5px solid transparent; border-right:5px solid transparent; border-top:5px solid #e2e8f0; }",
      ".cj-chart-annotation .cj-ann-text { outline:none; min-width:30px; display:inline-block; }",
      ".cj-chart-annotation .cj-ann-text:empty::before { content:'Type note...'; color:#94a3b8; font-style:italic; }",
      ".cj-chart-annotation .cj-ann-remove { display:inline-block; margin-left:6px; color:#94a3b8; cursor:pointer; font-size:13px; font-weight:700; line-height:1; }",
      ".cj-chart-annotation .cj-ann-remove:hover { color:#dc2626; }",
      ".cj-chart-annotation-prompt { position:absolute; background:rgba(30,41,59,0.8); color:#fff; padding:4px 10px; border-radius:4px; font-size:10px; pointer-events:none; transform:translate(-50%,-100%); margin-top:-4px; z-index:4; white-space:nowrap; }"
    ].join("\n");
    document.head.appendChild(style);
  }

  function _enableClickAnnotations(chartContainer) {
    if (!chartContainer || chartContainer._annEnabled) return;
    chartContainer._annEnabled = true;
    _injectAnnotationStyle();

    var pos = window.getComputedStyle(chartContainer).position;
    if (pos === "static" || pos === "") {
      chartContainer.style.position = "relative";
    }

    chartContainer.addEventListener("dblclick", function(e) {
      // Don't add annotation if clicking on an existing annotation
      if (e.target.closest && e.target.closest(".cj-chart-annotation")) return;

      var rect = chartContainer.getBoundingClientRect();
      var x = e.clientX - rect.left;
      var y = e.clientY - rect.top;

      _createAnnotation(chartContainer, x, y, "");
    });

    // Show hint on first hover
    var _hintShown = false;
    chartContainer.addEventListener("mouseenter", function() {
      if (_hintShown) return;
      _hintShown = true;
      var hint = document.createElement("div");
      hint.className = "cj-chart-annotation-prompt";
      hint.textContent = "Double-click to add a note";
      hint.style.left = "50%";
      hint.style.top = "8px";
      hint.style.transform = "translateX(-50%)";
      hint.style.marginTop = "0";
      chartContainer.appendChild(hint);
      setTimeout(function() { if (hint.parentNode) hint.parentNode.removeChild(hint); }, 3000);
    });
  }

  function _createAnnotation(container, x, y, text) {
    var ann = document.createElement("div");
    ann.className = "cj-chart-annotation";
    ann.style.left = x + "px";
    ann.style.top = y + "px";

    var textEl = document.createElement("span");
    textEl.className = "cj-ann-text";
    textEl.contentEditable = "true";
    textEl.textContent = text;
    ann.appendChild(textEl);

    var removeBtn = document.createElement("span");
    removeBtn.className = "cj-ann-remove";
    removeBtn.innerHTML = "&times;";
    removeBtn.title = "Remove annotation";
    removeBtn.onclick = function(e) {
      e.stopPropagation();
      ann.parentNode.removeChild(ann);
    };
    ann.appendChild(removeBtn);

    // Focus the text field immediately
    container.appendChild(ann);
    textEl.focus();

    // Prevent double-click on annotation from creating another
    ann.addEventListener("dblclick", function(e) { e.stopPropagation(); });

    return ann;
  }


  function escSvg(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  return {
    setBrand: setBrand,
    renderShareBars: renderShareBars,
    renderSensitivity: renderSensitivity,
    renderSourceOfVolume: renderSourceOfVolume,
    renderDemandCurve: renderDemandCurve,
    enableClickAnnotations: _enableClickAnnotations
  };
})();
