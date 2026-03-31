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

    var insightEl = null, insightH = 0;
    if (insightBlocks.length > 0) {
      insightEl = TurasPins._renderInsightSVG(insightBlocks, pad + 14, contentTop + 14, usableW - 16, 7.5);
      insightH = insightEl.height + 18;
    }

    var imgTopY = contentTop + insightH + (insightH > 0 ? 4 : 0);
    var imgDispW = 0, imgDispH = 0;
    if (pin.imageData && imgW > 0 && imgH > 0) {
      imgDispW = Math.min(usableW, imgW);
      imgDispH = Math.round(imgH * (imgDispW / imgW));
    }

    var chartTopY = imgTopY + imgDispH + (imgDispH > 0 ? 4 : 0);
    var chartInfo = _chart(pin, usableW, chartTopY);
    var tableTopY = chartInfo.bottomY + (chartInfo.h > 0 ? 4 : 0);
    var mode = pin.pinMode || "all";
    var tData = null, estTH = 0;
    var hasHtmlContent = false;
    if (pin.tableHtml && (mode === "all" || mode === "table_insight")) {
      tData = TurasPins._extractTableData(pin.tableHtml);
      if (tData && tData.length > 0) {
        estTH = 34 + (tData.length - 1) * 28 + 4;
      } else if (pin.tableHtml.trim().length > 0) {
        // HTML content (gauges, sig cards, simulators) — needs image capture
        hasHtmlContent = true;
      }
    }

    return {
      pad: pad, usableW: usableW, titleText: titleText,
      titleLines: titleLines, titleY: titleY, metaY: metaY,
      insightY: contentTop, insightH: insightH, insightEl: insightEl,
      imgTopY: imgTopY, imgDispW: imgDispW, imgDispH: imgDispH,
      chartTopY: chartTopY, chart: chartInfo,
      tableTopY: tableTopY, tData: tData, hasHtmlContent: hasHtmlContent,
      totalH: Math.max(tableTopY + estTH + pad, 160)
    };
  }
  function _build(pin, imgW, imgH, onComplete) {
    var L = _layout(pin, imgW, imgH);
    var W = TurasPins.EXPORT_WIDTH;

    // If pin has HTML-only content (no SVG chart, no table), render it
    // to an image first, then composite into the export
    console.log("[TurasPins _build] Pin:", pin.title,
      "| hasHtmlContent:", L.hasHtmlContent,
      "| chartClone:", !!L.chart.clone,
      "| tData:", !!L.tData,
      "| tableHtml length:", (pin.tableHtml || "").length,
      "| chartSvg length:", (pin.chartSvg || "").length);
    if (L.hasHtmlContent && !L.chart.clone && !L.tData) {
      console.log("[TurasPins _build] Taking HTML content path for:", pin.title);
      _renderHtmlToImage(pin.tableHtml, L.usableW, function(result) {
        console.log("[TurasPins _build] HTML render result:", result ? "got image " + result.width + "x" + result.height : "NULL");
        if (result) {
          // Recalculate layout with the rendered image dimensions
          var htmlImgH = Math.round(result.height * (L.usableW / result.width));
          L.totalH = L.tableTopY + htmlImgH + L.pad;
          var svg = _assembleSVG(pin, L, W);
          // Composite HTML image onto canvas after SVG render
          _toPNG(svg, pin, L.totalH, W,
            { data: result.dataUrl, x: L.pad, y: L.tableTopY,
              w: L.usableW, h: htmlImgH },
            L.titleText, onComplete);
        } else {
          // Fallback: render without HTML content
          var svg = _assembleSVG(pin, L, W);
          _toPNG(svg, pin, L.totalH, W, null, L.titleText, onComplete);
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

  function _addMeta(svg, text, pad, metaY) {
    var el = document.createElementNS(NS, "text");
    el.setAttribute("x", pad); el.setAttribute("y", metaY);
    el.setAttribute("fill", "#94a3b8"); el.setAttribute("font-size", "12");
    el.textContent = text; svg.appendChild(el);
  }

  function _addInsight(svg, insightEl, y, pad, usableW, brand) {
    var aH = Math.max(24, insightEl.height + 8);
    _rect(svg, pad, y + 2, usableW, aH, "#f0f4ff", "4");
    var bar = document.createElementNS(NS, "rect");
    bar.setAttribute("x", pad); bar.setAttribute("y", y + 2);
    bar.setAttribute("width", "4"); bar.setAttribute("height", aH);
    bar.setAttribute("fill", brand); bar.setAttribute("rx", "2");
    svg.appendChild(bar); svg.appendChild(insightEl.element);
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
    if (pin.sourceLabel) p.push(pin.sourceLabel);
    if (pin.timestamp) p.push(new Date(pin.timestamp).toLocaleDateString());
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
    if (!pin.chartSvg || pin.chartVisible === false || (mode !== "all" && mode !== "chart_insight")) return res;
    var tmp = document.createElement("div"); tmp.innerHTML = pin.chartSvg;
    var el = tmp.querySelector("svg");
    if (!el) return res;
    var clone = el.cloneNode(true);
    _resolveCssVars(clone);
    var vb = clone.getAttribute("viewBox");
    if (!vb) return res;
    var parts = vb.split(/[\s,]+/).map(Number);
    if (parts.length < 4 || parts[2] <= 0 || parts[3] <= 0 || isNaN(parts[2]) || isNaN(parts[3])) return res;
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
   */
  TurasPins._exportToBlob = function(pin, callback) {
    if (!pin) { callback(null); return; }
    var doExport = function(iw, ih) {
      var L = _layout(pin, iw, ih);
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
   * Render HTML content to a canvas image for pixel-perfect export.
   *
   * Two-phase approach:
   * Phase 1: Render HTML off-screen with page's stylesheets applied,
   *          then deep-clone with ALL computed styles inlined on every
   *          element (since the SVG Blob has no stylesheet access).
   * Phase 2: Serialize the styled clone via XMLSerializer (produces
   *          well-formed XHTML), embed in SVG foreignObject, load via
   *          Blob URL (not data URI — avoids encoding issues), render
   *          to canvas.
   *
   * @param {string} html - Raw HTML content
   * @param {number} maxWidth - Container width in pixels
   * @param {function} callback - Called with {dataUrl, width, height} or null
   */
  function _renderHtmlToImage(html, maxWidth, callback) {
    // Phase 1: Render off-screen to capture computed styles
    var container = document.createElement("div");
    container.style.cssText =
      "position:absolute;left:-9999px;top:-9999px;width:" + maxWidth + "px;" +
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
    height = Math.min(height, 1200);

    // Deep-clone with ALL computed styles inlined on every element.
    // The SVG Blob is an independent document with no stylesheet access,
    // so every style must be inline for the render to match.
    var styledClone = _deepCloneWithStyles(container);

    document.body.removeChild(container);

    // Phase 2: Serialize to XHTML and render via Blob URL
    // XMLSerializer produces well-formed XML (self-closing tags)
    // that foreignObject requires. innerHTML would produce HTML5
    // with void elements that break SVG parsing.
    styledClone.setAttribute("xmlns", "http://www.w3.org/1999/xhtml");
    var xhtml = new XMLSerializer().serializeToString(styledClone);

    var svgStr = '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '">' +
      '<foreignObject width="100%" height="100%">' +
      xhtml +
      '</foreignObject></svg>';

    // 3. Use Blob URL — critically different from data URI.
    //    Blob URLs handle encoding transparently, avoiding the malformed
    //    XHTML issues that break data:image/svg+xml foreignObject rendering.
    var svgBlob = new Blob([svgStr], { type: "image/svg+xml;charset=utf-8" });
    var url = URL.createObjectURL(svgBlob);

    // Diagnostic: log SVG size and first/last chars to console
    console.log("[TurasPins HTML export] SVG size:", svgStr.length,
      "| width:", width, "| height:", height,
      "| xhtml length:", xhtml.length,
      "| starts with:", svgStr.substring(0, 80));

    var img = new Image();
    img.onload = function() {
      URL.revokeObjectURL(url);
      console.log("[TurasPins HTML export] Image loaded OK:", img.naturalWidth, "x", img.naturalHeight);
      var preset = TurasPins.QUALITY_PRESETS[TurasPins.EXPORT_QUALITY] ||
                   TurasPins.QUALITY_PRESETS.standard;
      var scale = preset.scale;
      var c = document.createElement("canvas");
      c.width = width * scale;
      c.height = height * scale;
      var ctx = c.getContext("2d");
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, c.width, c.height);
      ctx.drawImage(img, 0, 0, c.width, c.height);
      // Diagnostic: check if canvas has any non-white pixels
      var sample = ctx.getImageData(Math.floor(c.width/2), Math.floor(c.height/2), 1, 1).data;
      console.log("[TurasPins HTML export] Canvas centre pixel RGBA:", sample[0], sample[1], sample[2], sample[3]);
      callback({ dataUrl: c.toDataURL("image/png"), width: width, height: height });
    };
    img.onerror = function(e) {
      URL.revokeObjectURL(url);
      console.error("[TurasPins HTML export] Image FAILED to load. Error:", e);
      console.error("[TurasPins HTML export] SVG first 500 chars:", svgStr.substring(0, 500));
      callback(null);
    };
    img.src = url;
  }

  /**
   * Deep-clone a DOM tree with ALL computed styles inlined on every element.
   * Required because the SVG Blob is loaded as an independent document
   * with no access to the page's stylesheets.
   */
  function _deepCloneWithStyles(original) {
    var clone = original.cloneNode(true);
    var origEls = original.querySelectorAll("*");
    var cloneEls = clone.querySelectorAll("*");
    _inlineAllStyles(original, clone);
    for (var i = 0; i < origEls.length; i++) {
      _inlineAllStyles(origEls[i], cloneEls[i]);
    }
    return clone;
  }

  /**
   * Copy ALL computed styles from source to target as inline styles.
   */
  function _inlineAllStyles(source, target) {
    if (source.nodeType !== 1) return;
    var cs;
    try { cs = window.getComputedStyle(source); } catch (e) { return; }
    var cssText = "";
    for (var i = 0; i < cs.length; i++) {
      var prop = cs[i];
      var val = cs.getPropertyValue(prop);
      if (!val) continue;
      cssText += prop + ":" + val + ";";
    }
    target.setAttribute("style", cssText);
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
    _addMeta(svg, _meta(pin), L.pad, L.metaY);
    if (L.insightEl && L.insightH > 0) _addInsight(svg, L.insightEl, L.insightY, L.pad, L.usableW, brand);
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
        pi.onload = function() {
          ctx.drawImage(pi, imgOvl.x * scale, imgOvl.y * scale, imgOvl.w * scale, imgOvl.h * scale);
          callback(c);
        };
        pi.onerror = function() { callback(c); };
        pi.src = imgOvl.data;
      } else { callback(c); }
    };
    img.src = url;
  }

})();
