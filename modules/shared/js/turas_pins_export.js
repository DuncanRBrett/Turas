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
    if (pin.tableHtml && (mode === "all" || mode === "table_insight")) {
      tData = TurasPins._extractTableData(pin.tableHtml);
      if (tData && tData.length > 0) estTH = 34 + (tData.length - 1) * 28 + 4;
    }

    return {
      pad: pad, usableW: usableW, titleText: titleText,
      titleLines: titleLines, titleY: titleY, metaY: metaY,
      insightY: contentTop, insightH: insightH, insightEl: insightEl,
      imgTopY: imgTopY, imgDispW: imgDispW, imgDispH: imgDispH,
      chartTopY: chartTopY, chart: chartInfo,
      tableTopY: tableTopY, tData: tData,
      totalH: Math.max(tableTopY + estTH + pad, 160)
    };
  }
  function _build(pin, imgW, imgH, onComplete) {
    var L = _layout(pin, imgW, imgH);
    var W = TurasPins.EXPORT_WIDTH;
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
