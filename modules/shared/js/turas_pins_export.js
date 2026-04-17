/**
 * TurasPins — PNG Export. Builds SVG slides and renders to canvas at 3x.
 * Depends on: turas_pins_utils, turas_pins, turas_pins_insight_svg, turas_pins_table
 */
/* global TurasPins */

(function() {
  "use strict";

  var NS = "http://www.w3.org/2000/svg";

  /** Export a single pin card as PNG. */
  TurasPins.exportCard = function(pinId, onComplete) {
    var pins = TurasPins.getAll();
    var pin = null;
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].id === pinId) { pin = pins[i]; break; }
    }
    if (!pin) { if (onComplete) onComplete(); return; }

    if (pin.imageData) {
      var pre = new Image();
      pre.onload = function() { _build(pin, pre.naturalWidth, pre.naturalHeight, onComplete); };
      pre.onerror = function() { _build(pin, 0, 0, onComplete); };
      pre.src = pin.imageData;
    } else {
      _build(pin, 0, 0, onComplete);
    }
  };

  /** Export all pins as PNGs (sequential). */
  TurasPins.exportAll = function() {
    var pins = TurasPins.getAll();
    var ids = [];
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].type === "pin") ids.push(pins[i].id);
    }
    if (ids.length === 0) return;
    var idx = 0;
    (function next() {
      if (idx >= ids.length) return;
      TurasPins.exportCard(ids[idx++], function() { setTimeout(next, TurasPins.EXPORT_ALL_DELAY_MS); });
    })();
  };
  /** Calculate layout dimensions */
  function _layout(pin, imgW, imgH) {
    var pad = 14, usableW = TurasPins.EXPORT_WIDTH - pad * 2;
    var titleText = pin.title || pin.metricTitle || pin.qTitle || pin.qCode || "Pinned View";
    var insightRaw = pin.insightText || "";
    var insightHtml = insightRaw && !TurasPins._containsHtml(insightRaw) ?
      TurasPins._renderMarkdown(insightRaw) : insightRaw;
    var insightBlocks = TurasPins._parseInsightHTML(insightHtml);

    var titleLines = _wrapLines(titleText, usableW, 9.5);
    var titleY = pad + 8;
    var metaY = titleY + titleLines.length * 20 + 2;
    var contentTop = metaY + 10;

    // Researcher insight (rendered as SVG text)
    var insightEl = null, insightH = 0;
    if (insightBlocks.length > 0) {
      insightEl = TurasPins._renderInsightSVG(insightBlocks, pad + 14, contentTop + 14, usableW - 16, 7.5);
      insightH = insightEl.height + 18;
    }

    // AI callout (rendered as SVG text with gold accent — reliable across all exports)
    var aiInsightEl = null, aiInsightH = 0;
    var showAi = pin.aiInsightHtml && (
      (pin.pinFlags && pin.pinFlags.aiInsight) ||
      (!pin.pinFlags && pin.aiInsightHtml)
    );
    if (showAi) {
      var aiText = _extractTextFromHtml(pin.aiInsightHtml);
      if (aiText) {
        var aiY = contentTop + insightH + (insightH > 0 ? 4 : 0);
        var aiBlocks = [{ type: "para", runs: [{ text: aiText, bold: false, italic: false }] }];
        aiInsightEl = TurasPins._renderInsightSVG(aiBlocks, pad + 18, aiY + 34, usableW - 24, 7.5);
        aiInsightH = aiInsightEl.height + 48;
      }
    }

    var imgTopY = contentTop + insightH + aiInsightH +
      (insightH > 0 || aiInsightH > 0 ? 4 : 0);
    var imgDispW = 0, imgDispH = 0;
    if (pin.imageData && imgW > 0 && imgH > 0) {
      imgDispW = Math.min(usableW, imgW);
      imgDispH = Math.round(imgH * (imgDispW / imgW));
    }

    var chartTopY = imgTopY + imgDispH + (imgDispH > 0 ? 4 : 0);
    var chartInfo = _chart(pin, usableW, chartTopY);
    var tableTopY = chartInfo.bottomY + (chartInfo.h > 0 ? 4 : 0);
    var tData = null, estTH = 0;
    var hasHtmlContent = false;
    var combinedHtml = "";
    // Table HTML only (AI callout rendered as SVG above)
    var showTable = pin.tableHtml && TurasPins.shouldShow(pin, "table");
    if (showTable && pin.tableHtml.trim().length > 0) {
      combinedHtml = pin.tableHtml;
      hasHtmlContent = true;
    }

    return {
      pad: pad, usableW: usableW, titleText: titleText,
      titleLines: titleLines, titleY: titleY, metaY: metaY,
      insightY: contentTop, insightH: insightH, insightEl: insightEl,
      aiInsightY: contentTop + insightH + (insightH > 0 ? 4 : 0),
      aiInsightH: aiInsightH, aiInsightEl: aiInsightEl,
      imgTopY: imgTopY, imgDispW: imgDispW, imgDispH: imgDispH,
      chartTopY: chartTopY, chart: chartInfo,
      tableTopY: tableTopY, tData: tData, hasHtmlContent: hasHtmlContent,
      combinedHtml: combinedHtml,
      totalH: Math.max(tableTopY + estTH + pad, 160)
    };
  }
  function _build(pin, imgW, imgH, onComplete) {
    var L = _layout(pin, imgW, imgH);
    var W = TurasPins.EXPORT_WIDTH;

    // If pin has HTML content (AI callout + table), render via html2canvas
    // then composite into the export
    if (L.hasHtmlContent) {
      _renderHtmlToImage(L.combinedHtml, L.usableW, function(result) {
        if (result) {
          var htmlImgW = Math.min(result.width, L.usableW);
          var htmlImgH = Math.round(result.height * (htmlImgW / result.width));
          L.totalH = L.tableTopY + htmlImgH + L.pad;
          var svg = _assembleSVG(pin, L, W);
          _toPNG(svg, pin, L.totalH, W,
            { data: result.dataUrl, x: L.pad, y: L.tableTopY,
              w: htmlImgW, h: htmlImgH },
            L.titleText, onComplete);
        } else {
          var svg = _assembleSVG(pin, L, W);
          _toPNG(svg, pin, L.totalH, W,
            L.imgDispW > 0 ? { data: pin.imageData, x: L.pad, y: L.imgTopY,
              w: L.imgDispW, h: L.imgDispH } : null,
            L.titleText, onComplete);
        }
      });
      return;
    }

    var svg = _assembleSVG(pin, L, W);
    _toPNG(svg, pin, L.totalH, W,
      L.imgDispW > 0 ? { data: pin.imageData, x: L.pad, y: L.imgTopY,
        w: L.imgDispW, h: L.imgDispH } : null,
      L.titleText, onComplete);
  }
  function _addTitle(svg, lines, pad, titleY) {
    var el = document.createElementNS(NS, "text");
    el.setAttribute("x", pad); el.setAttribute("fill", "#1a2744");
    el.setAttribute("font-size", "18"); el.setAttribute("font-weight", "700");
    for (var i = 0; i < lines.length; i++) {
      var ts = document.createElementNS(NS, "tspan");
      ts.setAttribute("x", pad); ts.setAttribute("y", titleY + i * 20);
      ts.textContent = lines[i]; el.appendChild(ts);
    }
    svg.appendChild(el);
  }

  // Badge colors matching hub_styles.css
  var BADGE_COLORS = {
    Tracker:        { bg: "#dbeafe", fg: "#1e40af" },
    Crosstabs:      { bg: "#fef3c7", fg: "#92400e" },
    Confidence:     { bg: "#ede9fe", fg: "#5b21b6" },
    Conjoint:       { bg: "#fce7f3", fg: "#9d174d" },
    MaxDiff:        { bg: "#ccfbf1", fg: "#065f46" },
    Pricing:        { bg: "#fef9c3", fg: "#854d0e" },
    Segmentation:   { bg: "#f0fdf4", fg: "#166534" },
    "Cat Driver":   { bg: "#fff7ed", fg: "#9a3412" },
    "Key Driver":   { bg: "#f0f9ff", fg: "#075985" },
    Weighting:      { bg: "#f5f3ff", fg: "#6d28d9" },
    Overview:       { bg: "#e0e7ff", fg: "#3730a3" }
  };

  function _addMeta(svg, text, pad, metaY, sourceLabel) {
    // Render source badge as a colored tag if sourceLabel is present
    var metaX = pad;
    if (sourceLabel) {
      var colors = BADGE_COLORS[sourceLabel] || { bg: "#f1f5f9", fg: "#475569" };
      var badgeText = sourceLabel.toUpperCase();
      var badgeW = badgeText.length * 6.5 + 16;
      var badgeH = 18;
      var badgeY = metaY - 13;
      _rect(svg, pad, badgeY, badgeW, badgeH, colors.bg, "3");
      var bt = document.createElementNS(NS, "text");
      bt.setAttribute("x", pad + 8); bt.setAttribute("y", metaY - 1);
      bt.setAttribute("fill", colors.fg); bt.setAttribute("font-size", "10");
      bt.setAttribute("font-weight", "600"); bt.setAttribute("letter-spacing", "0.5");
      bt.textContent = badgeText;
      svg.appendChild(bt);
      metaX = pad + badgeW + 8;
    }
    if (text) {
      var el = document.createElementNS(NS, "text");
      el.setAttribute("x", metaX); el.setAttribute("y", metaY);
      el.setAttribute("fill", "#94a3b8"); el.setAttribute("font-size", "12");
      el.textContent = text; svg.appendChild(el);
    }
  }

  function _addInsight(svg, insightEl, y, pad, usableW, brand) {
    var aH = Math.max(32, insightEl.height + 16);
    _rect(svg, pad, y + 2, usableW, aH, "#f0f4ff", "4");
    var bar = document.createElementNS(NS, "rect");
    bar.setAttribute("x", pad); bar.setAttribute("y", y + 2);
    bar.setAttribute("width", "4"); bar.setAttribute("height", aH);
    bar.setAttribute("fill", brand); bar.setAttribute("rx", "2");
    svg.appendChild(bar); svg.appendChild(insightEl.element);
  }

  /** Render AI callout block with gold accent in SVG export */
  function _addAiInsight(svg, aiInsightEl, y, pad, usableW) {
    var aH = Math.max(52, aiInsightEl.height + 42);
    // Gold background with generous padding
    _rect(svg, pad, y + 2, usableW, aH, "#fdf8ed", "6");
    // Gold left accent bar
    var bar = document.createElementNS(NS, "rect");
    bar.setAttribute("x", pad); bar.setAttribute("y", y + 2);
    bar.setAttribute("width", "4"); bar.setAttribute("height", aH);
    bar.setAttribute("fill", "#c9a84c"); bar.setAttribute("rx", "2");
    svg.appendChild(bar);
    // "AI-ASSISTED INSIGHT" label
    var label = document.createElementNS(NS, "text");
    label.setAttribute("x", pad + 18); label.setAttribute("y", y + 20);
    label.setAttribute("fill", "#c9a84c"); label.setAttribute("font-size", "9");
    label.setAttribute("font-weight", "700"); label.setAttribute("letter-spacing", "1.2");
    label.textContent = "\u2726 AI-ASSISTED INSIGHT";
    svg.appendChild(label);
    // Narrative text (positioned below label with breathing room)
    svg.appendChild(aiInsightEl.element);
  }

  /** Extract plain text from AI callout HTML */
  function _extractTextFromHtml(html) {
    if (!html) return "";
    var tmp = document.createElement("div");
    tmp.innerHTML = html;
    // Get the callout body text (skip header/label)
    var body = tmp.querySelector(".ai-callout-body");
    if (body) return body.textContent.trim();
    // Fallback: strip all tags
    return tmp.textContent.trim();
  }

  function _wrapLines(text, maxW, cw) {
    if (!text) return [];
    var mc = Math.floor(maxW / cw);
    if (text.length <= mc) return [text];
    var words = text.split(" "), lines = [], cur = "";
    for (var i = 0; i < words.length; i++) {
      var t = cur ? cur + " " + words[i] : words[i];
      if (t.length > mc && cur) { lines.push(cur); cur = words[i]; } else { cur = t; }
    }
    if (cur) lines.push(cur);
    return lines;
  }

  function _meta(pin) {
    var p = [];
    // sourceLabel now rendered as a colored badge — don't duplicate in meta text
    if (pin.visibleSegments && pin.visibleSegments.length > 0)
      p.push("Segments: " + pin.visibleSegments.join(", "));
    if (pin.bannerLabel) p.push("Banner: " + pin.bannerLabel);
    if (pin.baseText) p.push("Base: " + pin.baseText);
    return p.join("  \u00B7  ");
  }

  function _brandColour() {
    try { return getComputedStyle(document.documentElement).getPropertyValue("--hub-brand").trim() || "#323367"; }
    catch (e) { return "#323367"; }
  }

  function _rect(parent, x, y, w, h, fill, rx) {
    var r = document.createElementNS(NS, "rect");
    r.setAttribute("x", x); r.setAttribute("y", y);
    r.setAttribute("width", w); r.setAttribute("height", h);
    r.setAttribute("fill", fill);
    if (rx) { r.setAttribute("rx", rx); r.setAttribute("ry", rx); }
    parent.appendChild(r);
    return r;
  }

  function _chart(pin, usableW, topY) {
    var res = { clone: null, h: 0, scale: 1, bottomY: topY };
    var mode = pin.pinMode || "all";
    if (!pin.chartSvg || pin.chartVisible === false || !TurasPins.shouldShow(pin, "chart")) return res;
    var tmp = document.createElement("div"); tmp.innerHTML = pin.chartSvg;
    var el = tmp.querySelector("svg");
    if (!el) return res;
    var clone = el.cloneNode(true);
    _resolveCssVars(clone);
    var vb = clone.getAttribute("viewBox");
    if (!vb) return res;
    var parts = vb.split(/[\s,]+/).map(Number);
    if (parts.length < 4 || parts[2] <= 0 || parts[3] <= 0 || isNaN(parts[2]) || isNaN(parts[3])) return res;

    // Append HTML legend items (vis-legend) as SVG elements so they survive export
    var legendItems = tmp.querySelectorAll(".vis-legend-item");
    if (legendItems.length > 0) {
      var svgW = parts[2];
      var legendRowH = 28;
      var newH = parts[3] + legendRowH;
      clone.setAttribute("viewBox", "0 0 " + svgW + " " + newH);
      clone.setAttribute("height", newH);
      var lx = 0;
      var ly = parts[3] + 8;
      legendItems.forEach(function(item) {
        var swatch = item.querySelector(".vis-legend-swatch");
        var colour = "#94a3b8";
        if (swatch) {
          var bg = swatch.style.background || swatch.style.backgroundColor || "";
          if (bg) colour = bg;
        }
        var label = item.textContent.trim();
        var circle = document.createElementNS(NS, "circle");
        circle.setAttribute("cx", lx + 6); circle.setAttribute("cy", ly + 8);
        circle.setAttribute("r", "5"); circle.setAttribute("fill", colour);
        clone.appendChild(circle);
        var text = document.createElementNS(NS, "text");
        text.setAttribute("x", lx + 16); text.setAttribute("y", ly + 12);
        text.setAttribute("font-size", "11"); text.setAttribute("fill", "#334155");
        text.textContent = label;
        clone.appendChild(text);
        lx += label.length * 6.5 + 30;
      });
      parts[3] = newH;
    }

    res.clone = clone; res.scale = usableW / parts[2]; res.h = parts[3] * res.scale;
    res.bottomY = topY + res.h;
    return res;
  }

  function _resolveCssVars(clone) {
    var rs = getComputedStyle(document.documentElement);
    clone.querySelectorAll("*").forEach(function(el) {
      ["fill", "stroke", "stop-color", "color"].forEach(function(attr) {
        var v = el.getAttribute(attr);
        if (!v || v.indexOf("var(") === -1) return;
        var m = v.match(/var\(--([^,)]+),\s*([^)]+)\)/);
        if (m) { el.setAttribute(attr, rs.getPropertyValue("--" + m[1].trim()).trim() || m[2].trim()); return; }
        var m2 = v.match(/var\(--([^)]+)\)/);
        if (m2) { var r2 = rs.getPropertyValue("--" + m2[1].trim()).trim(); if (r2) el.setAttribute(attr, r2); }
      });
    });
  }

  /** Render SVG to canvas then download */
  function _toPNG(svg, pin, totalH, W, imgOvl, titleText, onComplete) {
    _toCanvas(svg, totalH, W, imgOvl, pin.id, function(canvas) {
      if (!canvas) { if (onComplete) onComplete(); return; }
      var preset = TurasPins.QUALITY_PRESETS[TurasPins.EXPORT_QUALITY] ||
                   TurasPins.QUALITY_PRESETS.standard;
      var ext = preset.format === "image/jpeg" ? ".jpg" : ".png";
      var args = preset.quality !== null ? [preset.format, preset.quality] : [preset.format];
      canvas.toBlob(function(blob) {
        if (!blob) { if (onComplete) onComplete(); return; }
        var slug = titleText.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "pinned_" + slug + ext;
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
        URL.revokeObjectURL(a.href);
        if (onComplete) onComplete();
      }, args[0], args[1]);
    });
  }

  /** Export pin to image blob (for clipboard or PPTX).
   *  Respects TurasPins.EXPORT_QUALITY preset for format and resolution.
   *  Delegates to _build for the rendering pipeline (including html2canvas
   *  for HTML-only pins), then captures the result as a blob.
   */
  TurasPins._exportToBlob = function(pin, callback) {
    if (!pin) { callback(null); return; }
    var doExport = function(iw, ih) {
      var L = _layout(pin, iw, ih);
      if (!L) { callback(null); return; }

      // Pins with HTML content: render via html2canvas for pixel-perfect output
      if (L.hasHtmlContent) {
        _renderHtmlToImage(pin.tableHtml, L.usableW, function(result) {
          if (result) {
            var htmlImgW = Math.min(result.width, L.usableW);
            var htmlImgH = Math.round(result.height * (htmlImgW / result.width));
            L.totalH = L.tableTopY + htmlImgH + L.pad;
            var W = TurasPins.EXPORT_WIDTH;
            var svg = _assembleSVG(pin, L, W);
            _toCanvas(svg, L.totalH, W,
              { data: result.dataUrl, x: L.pad, y: L.tableTopY,
                w: htmlImgW, h: htmlImgH },
              pin.id, function(canvas) {
                if (!canvas) { callback(null); return; }
                var preset = TurasPins.QUALITY_PRESETS[TurasPins.EXPORT_QUALITY] ||
                             TurasPins.QUALITY_PRESETS.standard;
                var args = preset.quality !== null ? [preset.format, preset.quality] : [preset.format];
                canvas.toBlob(function(blob) { callback(blob); }, args[0], args[1]);
              });
          } else {
            callback(null);
          }
        });
        return;
      }

      var W = TurasPins.EXPORT_WIDTH;
      var svg = _assembleSVG(pin, L, W);
      _toCanvas(svg, L.totalH, W,
        L.imgDispW > 0 ? { data: pin.imageData, x: L.pad, y: L.imgTopY,
          w: L.imgDispW, h: L.imgDispH } : null,
        pin.id, function(canvas) {
          if (!canvas) { callback(null); return; }
          var preset = TurasPins.QUALITY_PRESETS[TurasPins.EXPORT_QUALITY] ||
                       TurasPins.QUALITY_PRESETS.standard;
          var args = preset.quality !== null ? [preset.format, preset.quality] : [preset.format];
          canvas.toBlob(function(blob) { callback(blob); }, args[0], args[1]);
        });
    };
    if (pin.imageData) {
      var pre = new Image();
      pre.onload = function() { doExport(pre.naturalWidth, pre.naturalHeight); };
      pre.onerror = function() { doExport(0, 0); };
      pre.src = pin.imageData;
    } else { doExport(0, 0); }
  };

  /**
   * Render HTML content to a canvas image using html2canvas.
   *
   * foreignObject SVG approaches fail because the canvas gets tainted
   * by cross-origin security restrictions (SecurityError on toDataURL).
   * html2canvas avoids this entirely — it walks the DOM and draws to
   * canvas using native 2D context commands (fillRect, fillText, etc.).
   * No SVG, no Image loading, no cross-origin taint.
   *
   * @param {string} html - Raw HTML content
   * @param {number} maxWidth - Container width in pixels
   * @param {function} callback - Called with {dataUrl, width, height} or null
   */
  function _renderHtmlToImage(html, maxWidth, callback) {
    if (typeof html2canvas === "undefined") {
      console.warn("[TurasPins] html2canvas not available — HTML content cannot be exported");
      callback(null);
      return;
    }

    // Render off-screen but fully visible — html2canvas needs opacity:1 to
    // capture content correctly (it faithfully renders opacity, so 0.001
    // produces a near-transparent image). Position below the viewport fold
    // so the user doesn't see the temporary element.
    var container = document.createElement("div");
    container.style.cssText =
      "position:fixed;left:0;top:100vh;width:" + maxWidth + "px;" +
      "z-index:-1;pointer-events:none;" +
      "background:#fff;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;" +
      "font-size:13px;color:#1e293b;line-height:1.5;";
    container.innerHTML = TurasPins._sanitizeHtml(html);
    document.body.appendChild(container);

    var width = container.offsetWidth;
    var height = container.offsetHeight;
    if (height <= 0) {
      document.body.removeChild(container);
      callback(null);
      return;
    }
    var preset = TurasPins.QUALITY_PRESETS[TurasPins.EXPORT_QUALITY] ||
                 TurasPins.QUALITY_PRESETS.standard;

    // Canvas pixel budget: cap at ~8 megapixels to prevent browser memory
    // crashes on tall tables. Instead of truncating content, reduce the
    // html2canvas scale so the full table renders at lower resolution.
    var MAX_CANVAS_PIXELS = 8000000;
    var renderScale = preset.scale;
    var canvasPixels = (width * renderScale) * (height * renderScale);
    if (canvasPixels > MAX_CANVAS_PIXELS) {
      renderScale = Math.sqrt(MAX_CANVAS_PIXELS / (width * height));
      renderScale = Math.max(renderScale, 1); // never below 1x
    }

    // 10s timeout guards against html2canvas hanging; done flag prevents double-callback
    var done = false;
    var timer = setTimeout(function() {
      if (done) return; done = true;
      console.warn("[TurasPins] html2canvas timed out after 10s");
      if (container.parentNode) document.body.removeChild(container);
      callback(null);
    }, 10000);

    html2canvas(container, {
      scale: renderScale,
      backgroundColor: "#ffffff",
      width: width,
      height: height,
      logging: false,
      useCORS: true
    }).then(function(canvas) {
      if (done) return; done = true; clearTimeout(timer);
      if (container.parentNode) document.body.removeChild(container);
      callback({ dataUrl: canvas.toDataURL("image/png"), width: width, height: height });
    }).catch(function(err) {
      if (done) return; done = true; clearTimeout(timer);
      console.error("[TurasPins] html2canvas render failed:", err);
      if (container.parentNode) document.body.removeChild(container);
      callback(null);
    });
  }

  /** Assemble export SVG from layout */
  function _assembleSVG(pin, L, W) {
    var font = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
    var svg = document.createElementNS(NS, "svg");
    svg.setAttribute("xmlns", NS);
    svg.setAttribute("viewBox", "0 0 " + W + " " + L.totalH);
    svg.setAttribute("style", "font-family:" + font + ";");
    var bg = _rect(svg, 0, 0, W, L.totalH, "#ffffff");
    var brand = _brandColour();
    _rect(svg, 0, 0, W, 4, brand);
    _addTitle(svg, L.titleLines, L.pad, L.titleY);
    _addMeta(svg, _meta(pin), L.pad, L.metaY, pin.sourceLabel);
    if (L.insightEl && L.insightH > 0) _addInsight(svg, L.insightEl, L.insightY, L.pad, L.usableW, brand);
    if (L.aiInsightEl && L.aiInsightH > 0) _addAiInsight(svg, L.aiInsightEl, L.aiInsightY, L.pad, L.usableW);
    if (L.chart.clone && L.chart.h > 0) {
      var cg = document.createElementNS(NS, "g");
      cg.setAttribute("transform", "translate(" + L.pad + "," + L.chartTopY + ") scale(" + L.chart.scale + ")");
      while (L.chart.clone.firstChild) cg.appendChild(L.chart.clone.firstChild);
      svg.appendChild(cg);
    }
    if (L.tData && L.tData.length > 0) {
      var actH = TurasPins._renderTableSVG(svg, L.tData, L.pad, L.tableTopY, L.usableW);
      if (L.tableTopY + actH + L.pad > L.totalH) {
        L.totalH = L.tableTopY + actH + L.pad;
        bg.setAttribute("height", L.totalH);
        svg.setAttribute("viewBox", "0 0 " + W + " " + L.totalH);
      }
    }
    return svg;
  }

  /** SVG to canvas with optional image overlay */
  function _toCanvas(svg, totalH, W, imgOvl, pinId, callback) {
    var preset = TurasPins.QUALITY_PRESETS[TurasPins.EXPORT_QUALITY] ||
                 TurasPins.QUALITY_PRESETS.standard;
    var scale = preset.scale;
    var url = TurasPins._svgToImageUrl(new XMLSerializer().serializeToString(svg));
    var img = new Image();
    img.onerror = function() {
      console.error("[TurasPins] SVG render failed: " + pinId);
      callback(null);
    };
    img.onload = function() {
      var c = document.createElement("canvas");
      c.width = W * scale; c.height = totalH * scale;
      var ctx = c.getContext("2d");
      if (!ctx) { callback(null); return; }
      ctx.fillStyle = "#fff"; ctx.fillRect(0, 0, c.width, c.height);
      ctx.drawImage(img, 0, 0, c.width, c.height);
      if (imgOvl) {
        var pi = new Image();
        var ovlTimer = setTimeout(function() { callback(c); }, 5000);
        pi.onload = function() {
          clearTimeout(ovlTimer);
          ctx.drawImage(pi, imgOvl.x * scale, imgOvl.y * scale, imgOvl.w * scale, imgOvl.h * scale);
          callback(c);
        };
        pi.onerror = function() { clearTimeout(ovlTimer); callback(c); };
        pi.src = imgOvl.data;
      } else { callback(c); }
    };
    img.src = url;
  }

})();
