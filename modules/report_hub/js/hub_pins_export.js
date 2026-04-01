/**
 * Hub Pinned Views — PNG Export
 *
 * Builds pure SVG export slides: brand bar, title, meta, insight,
 * image, chart, table, footer. Renders to canvas at 3x resolution.
 *
 * Delegates to TurasPins shared library for:
 * - SVG utilities (compress, strip XML chars, data URI)
 * - Insight parsing & SVG rendering
 * - Table extraction & SVG rendering
 *
 * Depends on: TurasPins shared library (loaded before this file)
 *             hub_pins.js (ReportHub.pinnedItems)
 */

/* global ReportHub, TurasPins */

(function() {
  "use strict";

  // ── Configuration Constants ────────────────────────────────────────────────

  var EXPORT_WIDTH = 1280;
  var EXPORT_RENDER_SCALE = 3;
  var EXPORT_ALL_DELAY_MS = 200;
  var NS = "http://www.w3.org/2000/svg";
  var FONT_FAMILY = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";

  // ── Text Wrapping Helpers ──────────────────────────────────────────────────

  /** Wrap text into lines that fit within maxWidth (character-based estimate). */
  function wrapTextLines(text, maxWidth, charWidth) {
    if (!text) return [];
    var maxChars = Math.floor(maxWidth / charWidth);
    if (text.length <= maxChars) return [text];
    var words = text.split(" ");
    var lines = [], current = "";
    for (var i = 0; i < words.length; i++) {
      var test = current ? current + " " + words[i] : words[i];
      if (test.length > maxChars && current) {
        lines.push(current);
        current = words[i];
      } else {
        current = test;
      }
    }
    if (current) lines.push(current);
    return lines;
  }

  /** Create SVG text element with tspan lines. */
  function createWrappedText(lines, x, startY, lineHeight, attrs) {
    var el = document.createElementNS(NS, "text");
    el.setAttribute("x", x);
    for (var key in attrs) { el.setAttribute(key, attrs[key]); }
    for (var i = 0; i < lines.length; i++) {
      var tspan = document.createElementNS(NS, "tspan");
      tspan.setAttribute("x", x);
      tspan.setAttribute("y", startY + i * lineHeight);
      tspan.textContent = lines[i];
      el.appendChild(tspan);
    }
    return { element: el, height: lines.length * lineHeight };
  }

  // ── Export Entry Points ────────────────────────────────────────────────────

  /**
   * Export a single pin card as a PowerPoint-quality PNG.
   * @param {string} pinId - Pin ID
   * @param {function} [onComplete] - Optional callback after export
   */
  ReportHub.exportPinCard = function(pinId, onComplete) {
    var pin = null;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) { pin = ReportHub.pinnedItems[i]; break; }
    }
    if (!pin) { if (onComplete) onComplete(); return; }

    // Use shared _exportToBlob (html2canvas) for all pins.
    // inlineTableStyles (run at pin-forwarding time inside the iframe)
    // has already inlined all computed styles including significance
    // markers, heatmap colours, and all CSS formatting. This makes
    // the HTML self-contained and renderable at the hub level.
    if (typeof TurasPins._exportToBlob === "function") {
      TurasPins._exportToBlob(pin, function(blob) {
        if (blob) {
          var title = pin.title || pin.qTitle || "pinned";
          var slug = title.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
          var a = document.createElement("a");
          a.href = URL.createObjectURL(blob);
          a.download = "pinned_" + slug + ".png";
          document.body.appendChild(a); a.click(); document.body.removeChild(a);
          URL.revokeObjectURL(a.href);
        }
        if (onComplete) onComplete();
      });
      return;
    }

    // Fallback: hub's own SVG renderer (no html2canvas available)
    if (pin.imageData) {
      var preImg = new Image();
      preImg.onload = function() {
        buildExportSVG(pin, preImg.naturalWidth, preImg.naturalHeight, onComplete);
      };
      preImg.onerror = function() {
        buildExportSVG(pin, 0, 0, onComplete);
      };
      preImg.src = pin.imageData;
    } else {
      buildExportSVG(pin, 0, 0, onComplete);
    }
  };

  /**
   * Export all pinned cards as individual PNGs (sequential callback chain).
   */
  ReportHub.exportAllPins = function() {
    var pins = [];
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].type === "pin") {
        pins.push(ReportHub.pinnedItems[i].id);
      }
    }
    if (pins.length === 0) return;

    var idx = 0;
    function exportNext() {
      if (idx >= pins.length) return;
      var currentId = pins[idx];
      idx++;
      ReportHub.exportPinCard(currentId, function() {
        setTimeout(exportNext, EXPORT_ALL_DELAY_MS);
      });
    }
    exportNext();
  };

  // ── SVG Export Builder ─────────────────────────────────────────────────────

  /**
   * Build SVG export slide and render to PNG.
   * Layout: brand bar -> title -> meta -> insight -> image -> chart -> table
   */
  function buildExportSVG(pin, pinImageW, pinImageH, onComplete) {
    var W = EXPORT_WIDTH;
    var pad = 14;
    var usableW = W - pad * 2;
    var brandColour = getComputedStyle(document.documentElement)
      .getPropertyValue("--hub-brand").trim() || "#323367";

    // ---- Resolve fields ----
    var titleText = pin.title || pin.metricTitle || pin.qTitle || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || pin.qTitle || "";
    if (pin.source === "tabs" && pin.qCode && pin.qTitle) {
      titleText = pin.qCode + " - " + pin.qTitle;
      subtitle = "";
    }

    // ---- Insight parsing (via shared library) ----
    var insightRaw = pin.insight || pin.insightText || "";
    var insightHtml = insightRaw;
    if (insightRaw && !TurasPins._containsHtml(insightRaw)) {
      insightHtml = TurasPins._renderMarkdown(insightRaw);
    }
    var insightBlocks = TurasPins._parseInsightHTML(insightHtml);

    // ---- 1. Title layout ----
    var titleLines = wrapTextLines(titleText, usableW, 9.5);
    var titleLineH = 20;
    var titleStartY = pad + 8;
    var titleBlockH = titleLines.length * titleLineH;

    // ---- 2. Meta line ----
    var metaParts = buildMetaParts(pin);
    var metaText = metaParts.join("  \u00B7  ");
    var metaY = titleStartY + titleBlockH + 2;
    var contentTop = metaY + 10;

    // ---- 3. Insight dimensions ----
    var insightY = contentTop;
    var insightBlockH = 0;
    var insightRendered = null;
    if (insightBlocks.length > 0) {
      insightRendered = TurasPins._renderInsightSVG(insightBlocks, pad + 14, insightY + 14, usableW - 16, 7.5);
      insightBlockH = insightRendered.height + 18;
    }

    // ---- 3b. Image dimensions ----
    var imageTopY = contentTop + insightBlockH + (insightBlockH > 0 ? 4 : 0);
    var imageDisplayH = 0, imageDisplayW = 0;
    if (pin.imageData && pinImageW > 0 && pinImageH > 0) {
      imageDisplayW = Math.min(usableW, pinImageW);
      var imgScale = imageDisplayW / pinImageW;
      imageDisplayH = Math.round(pinImageH * imgScale);
    }

    // ---- 4. Chart dimensions ----
    var exportMode = pin.pinMode || "all";
    var showChart = (exportMode === "all" || exportMode === "chart_insight");
    var showTable = (exportMode === "all" || exportMode === "table_insight");

    var chartTopY = imageTopY + imageDisplayH + (imageDisplayH > 0 ? 4 : 0);
    var chartDisplayH = 0, chartClone = null, chartScale = 1;

    if (pin.chartSvg && pin.chartVisible !== false && showChart) {
      var result = prepareChartClone(pin.chartSvg, usableW);
      if (result) {
        chartClone = result.clone;
        chartScale = result.scale;
        chartDisplayH = result.height;
      }
    }

    // ---- 5. Table dimensions (via shared library) ----
    var tableTopY = chartTopY + chartDisplayH + (chartDisplayH > 0 ? 4 : 0);
    var tableData = null, estimatedTableH = 0;
    if (pin.tableHtml && showTable) {
      tableData = TurasPins._extractTableData(pin.tableHtml);
      if (tableData && tableData.length > 0) {
        estimatedTableH = 34 + (tableData.length - 1) * 28 + 4;
      }
    }

    // ---- 6. Total height ----
    var totalH = Math.max(tableTopY + estimatedTableH + pad, 160);

    // ---- Build SVG ----
    var svg = document.createElementNS(NS, "svg");
    svg.setAttribute("xmlns", NS);
    svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
    svg.setAttribute("style", "font-family:" + FONT_FAMILY + ";");

    // White background
    var bg = document.createElementNS(NS, "rect");
    bg.setAttribute("width", W); bg.setAttribute("height", totalH);
    bg.setAttribute("fill", "#ffffff");
    svg.appendChild(bg);

    // Brand accent bar
    var accentBar = document.createElementNS(NS, "rect");
    accentBar.setAttribute("x", "0"); accentBar.setAttribute("y", "0");
    accentBar.setAttribute("width", W); accentBar.setAttribute("height", "4");
    accentBar.setAttribute("fill", brandColour);
    svg.appendChild(accentBar);

    // Title
    var titleResult = createWrappedText(titleLines, pad, titleStartY, titleLineH,
      { fill: "#1a2744", "font-size": "18", "font-weight": "700" });
    svg.appendChild(titleResult.element);

    // Meta line
    var metaEl = document.createElementNS(NS, "text");
    metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
    metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "12");
    metaEl.textContent = metaText;
    svg.appendChild(metaEl);

    // Insight block
    if (insightRendered && insightBlockH > 0) {
      var accentH = Math.max(24, insightRendered.height + 8);
      var insBg = document.createElementNS(NS, "rect");
      insBg.setAttribute("x", pad); insBg.setAttribute("y", insightY + 2);
      insBg.setAttribute("width", usableW); insBg.setAttribute("height", accentH);
      insBg.setAttribute("rx", "4"); insBg.setAttribute("fill", "#f0f4ff");
      svg.appendChild(insBg);
      var iBar = document.createElementNS(NS, "rect");
      iBar.setAttribute("x", pad); iBar.setAttribute("y", insightY + 2);
      iBar.setAttribute("width", "4"); iBar.setAttribute("height", accentH);
      iBar.setAttribute("fill", brandColour); iBar.setAttribute("rx", "2");
      svg.appendChild(iBar);
      svg.appendChild(insightRendered.element);
    }

    // Slide image data — stored for canvas compositing
    var imgData = (pin.imageData && imageDisplayW > 0 && imageDisplayH > 0) ? pin.imageData : null;
    var imgX = pad, imgY = imageTopY;

    // Chart — clone SVG content into <g>
    if (chartClone && chartDisplayH > 0) {
      var chartG = document.createElementNS(NS, "g");
      chartG.setAttribute("transform", "translate(" + pad + "," + chartTopY + ") scale(" + chartScale + ")");
      while (chartClone.firstChild) chartG.appendChild(chartClone.firstChild);
      svg.appendChild(chartG);
    }

    // Table — rendered as SVG rect+text (via shared library)
    if (tableData && tableData.length > 0) {
      var actualTableH = TurasPins._renderTableSVG(svg, tableData, pad, tableTopY, usableW);
      var newTotalH = tableTopY + actualTableH + pad;
      if (newTotalH > totalH) {
        totalH = newTotalH;
        bg.setAttribute("height", totalH);
        svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
      }
    }

    // ---- Render to PNG ----
    renderToPNG(svg, totalH, titleText, imgData, imgX, imgY, imageDisplayW, imageDisplayH, onComplete);
  }

  // ── Internal Helpers ───────────────────────────────────────────────────────

  /** Build meta line parts from pin data. */
  function buildMetaParts(pin) {
    var parts = [];
    if (pin.sourceLabel) parts.push(pin.sourceLabel);
    else if (pin.source === "tracker") parts.push("Tracker");
    else if (pin.source === "tabs") parts.push("Crosstabs");
    else if (pin.source === "confidence") parts.push("Confidence");
    else if (pin.source === "overview") parts.push("Overview");
    if (pin.timestamp) parts.push(new Date(pin.timestamp).toLocaleDateString());
    if (pin.visibleSegments && pin.visibleSegments.length > 0) {
      parts.push("Segments: " + pin.visibleSegments.join(", "));
    }
    if (pin.bannerLabel) parts.push("Banner: " + pin.bannerLabel);
    if (pin.baseText) parts.push("Base: " + pin.baseText);
    return parts;
  }

  /** Prepare a chart SVG clone with resolved CSS variables. */
  function prepareChartClone(chartSvg, usableW) {
    var tempDiv = document.createElement("div");
    tempDiv.innerHTML = chartSvg;
    var svgEl = tempDiv.querySelector("svg");
    if (!svgEl) return null;

    var clone = svgEl.cloneNode(true);
    var rootStyles = getComputedStyle(document.documentElement);

    // Resolve CSS variable references in chart SVG
    clone.querySelectorAll("*").forEach(function(el) {
      ["fill", "stroke", "stop-color", "color"].forEach(function(attr) {
        var val = el.getAttribute(attr);
        if (!val || val.indexOf("var(") === -1) return;
        var matchFb = val.match(/var\(--([^,)]+),\s*([^)]+)\)/);
        if (matchFb) {
          var resolved = rootStyles.getPropertyValue("--" + matchFb[1].trim()).trim();
          el.setAttribute(attr, resolved || matchFb[2].trim());
        } else {
          var matchNoFb = val.match(/var\(--([^)]+)\)/);
          if (matchNoFb) {
            var resolved2 = rootStyles.getPropertyValue("--" + matchNoFb[1].trim()).trim();
            if (resolved2) el.setAttribute(attr, resolved2);
          }
        }
      });
    });

    var vb = clone.getAttribute("viewBox");
    if (!vb) return null;
    var chartVB = vb.split(/[\s,]+/).map(Number);
    if (chartVB.length < 4 || chartVB[2] <= 0 || chartVB[3] <= 0 ||
        isNaN(chartVB[2]) || isNaN(chartVB[3])) return null;

    var scale = usableW / chartVB[2];
    return { clone: clone, scale: scale, height: chartVB[3] * scale };
  }

  /** Render SVG to PNG at high resolution, compositing pin image on canvas. */
  function renderToPNG(svg, totalH, titleText, imgData, imgX, imgY, imgW, imgH, onComplete) {
    var W = EXPORT_WIDTH;
    var scale = EXPORT_RENDER_SCALE;
    var svgData = new XMLSerializer().serializeToString(svg);
    var url = TurasPins._svgToImageUrl(svgData);

    var img = new Image();
    img.onerror = function() {
      console.error("[Hub Pin PNG] SVG render failed");
      TurasPins._showToast("PNG export failed \u2014 try Chrome or Edge");
      if (onComplete) onComplete();
    };
    img.onload = function() {
      var canvas = document.createElement("canvas");
      canvas.width = W * scale;
      canvas.height = totalH * scale;
      var ctx = canvas.getContext("2d");
      if (!ctx) { if (onComplete) onComplete(); return; }
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

      var finishExport = function() {
        canvas.toBlob(function(blob) {
          if (!blob) { if (onComplete) onComplete(); return; }
          var slug = titleText.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
          var a = document.createElement("a");
          a.href = URL.createObjectURL(blob);
          a.download = "pinned_" + slug + ".png";
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(a.href);
          if (onComplete) onComplete();
        }, "image/png");
      };

      // Composite pin image directly on canvas (avoids SVG <image> taint)
      if (imgData) {
        var pinImg = new Image();
        pinImg.onload = function() {
          ctx.drawImage(pinImg,
            imgX * scale, imgY * scale,
            imgW * scale, imgH * scale);
          finishExport();
        };
        pinImg.onerror = finishExport;
        pinImg.src = imgData;
      } else {
        finishExport();
      }
    };
    img.src = url;
  }

  // ── Hub Blob Export (for PPTX and clipboard) ───────────────────────────────

  /**
   * Export a hub pin to a PNG blob using the hub's own rendering pipeline.
   * This uses buildExportSVG (same as PNG download) which has the table
   * styles inlined at pin-forwarding time. The shared _exportToBlob would
   * render at the hub level where module CSS classes don't exist.
   *
   * @param {string} pinId - Pin ID
   * @param {function} callback - Called with Blob or null
   */
  function hubExportToBlob(pinId, callback) {
    var pin = null;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) { pin = ReportHub.pinnedItems[i]; break; }
    }
    if (!pin) {
      console.warn("[Hub Export] Pin not found:", pinId);
      callback(null);
      return;
    }

    // Use the shared _exportToBlob which routes tableHtml through
    // html2canvas. This preserves significance markers, heatmap colours,
    // and all table formatting. The hub's inlineTableStyles (run at
    // pin-forwarding time inside the iframe) has already inlined all
    // computed styles, making the HTML self-contained and renderable
    // at the hub level without module CSS classes.
    if (typeof TurasPins._exportToBlob === "function") {
      TurasPins._exportToBlob(pin, callback);
      return;
    }
    console.warn("[Hub Export] TurasPins._exportToBlob not available");
    callback(null);
  }

  // ── Clipboard Copy ────────────────────────────────────────────────────────

  /**
   * Copy a hub pin card to clipboard as PNG (for pasting into PowerPoint).
   * Falls back to PNG download if clipboard API unavailable.
   * @param {string} pinId - Pin ID
   */
  ReportHub.copyPinToClipboard = function(pinId) {
    var pin = null;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) { pin = ReportHub.pinnedItems[i]; break; }
    }
    if (!pin) return;

    hubExportToBlob(pinId, function(blob) {
      if (!blob) {
        TurasPins._showToast("Could not render pin");
        return;
      }
      if (navigator.clipboard && navigator.clipboard.write) {
        try {
          navigator.clipboard.write([
            new ClipboardItem({ "image/png": blob })
          ]).then(function() {
            TurasPins._showToast("Copied to clipboard");
          }).catch(function() {
            _downloadFallback(blob, pin);
          });
        } catch (e) {
          // ClipboardItem constructor can throw in some browsers
          _downloadFallback(blob, pin);
        }
      } else {
        _downloadFallback(blob, pin);
      }
    });
  };

  function _downloadFallback(blob, pin) {
    var title = pin.title || pin.qTitle || "pinned";
    var slug = title.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "pinned_" + slug + ".png";
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
    TurasPins._showToast("Downloaded (clipboard unavailable)");
  }

  // ── PowerPoint Export (delegates to shared TurasPins PPTX engine) ──────────

  /**
   * Export all hub pinned items as a PowerPoint presentation.
   * Temporarily proxies ReportHub.pinnedItems through TurasPins so the
   * shared PPTX engine can access them via TurasPins.getAll().
   */
  ReportHub.exportPptx = function() {
    if (typeof PptxGenJS === "undefined") {
      TurasPins._showToast("PowerPoint export not available");
      return;
    }

    var items = ReportHub.pinnedItems;
    if (!items || items.length === 0) {
      TurasPins._showToast("No pins to export");
      return;
    }

    // Proxy TurasPins.getAll to return hub pins. The shared _exportToBlob
    // (html2canvas) works correctly because inlineTableStyles has already
    // inlined all CSS at pin-forwarding time inside the iframe.
    var originalGetAll = TurasPins.getAll;
    TurasPins.getAll = function() { return items; };

    var reportTitle = document.title || "Combined Report";
    TurasPins.exportPptx({
      filename: reportTitle.replace(/[^a-zA-Z0-9 _-]/g, "").replace(/\s+/g, "_").substring(0, 60) + "_pins",
      onComplete: function() {
        TurasPins.getAll = originalGetAll;
      }
    });
  };

})();
