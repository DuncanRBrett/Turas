/**
 * Tier A export — hi-res PNG. The whole card (title, meta, chart, table)
 * is assembled as ONE pure SVG string from the data layer, then rasterised
 * at 3x. No DOM screenshots, no html2canvas, no CSS-variable resolution.
 */
(function (global) {
  "use strict";
  var TR = global.TR, C = TR.CONST, S = TR.svg, fmt = TR.fmt;

  var png = TR.exportPng = {};
  var PAD = 24;

  /** Word-wrap text to lines of roughly maxChars. */
  png.wrap = function (text, maxChars) {
    var words = String(text || "").split(" "), lines = [], current = "";
    words.forEach(function (word) {
      var candidate = current ? current + " " + word : word;
      if (candidate.length > maxChars && current) {
        lines.push(current);
        current = word;
      } else {
        current = candidate;
      }
    });
    if (current) lines.push(current);
    return lines;
  };

  /** Draw a table matrix as SVG rows. Returns {body, height}. */
  png.svgTable = function (matrix, x, y, width, brand) {
    var nCols = matrix.head.length;
    var labelW = Math.round(width * 0.3);
    var colW = (width - labelW) / Math.max(nCols - 1, 1);
    var headH = 26, rowH = 20;
    var parts = [], rowY = y;
    var cellX = function (i) {
      return i === 0 ? x + 8 : x + labelW + (i - 1) * colW + colW / 2;
    };
    parts.push(S.el("rect", { x: x, y: rowY, width: width, height: headH,
      fill: brand, rx: 4 }));
    matrix.head.forEach(function (h, i) {
      parts.push(S.text(cellX(i), rowY + 17, TR.charts.clip(h, i === 0 ? 40 : 14),
        { "text-anchor": i === 0 ? "start" : "middle", "font-size": 10.5,
          "font-weight": 700, fill: "#ffffff" }));
    });
    rowY += headH;
    matrix.body.forEach(function (row, r) {
      var fill = row.kind === "stat" ? "#f3f4f8"
        : (r % 2 === 1 ? "#fafbfe" : "#ffffff");
      parts.push(S.el("rect", { x: x, y: rowY, width: width, height: rowH, fill: fill }));
      var colour = row.kind === "base" ? "#6b7280" : "#1c2333";
      row.cells.forEach(function (cell, i) {
        parts.push(S.text(cellX(i), rowY + 14, TR.charts.clip(cell, i === 0 ? 42 : 12),
          { "text-anchor": i === 0 ? "start" : "middle", "font-size": 10.5,
            "font-weight": row.kind === "stat" ? 700 : 400,
            "font-style": row.kind === "base" ? "italic" : null, fill: colour }));
      });
      rowY += rowH;
    });
    parts.push(S.el("rect", { x: x, y: y, width: width, height: rowY - y,
      fill: "none", stroke: "#e5e7ef" }));
    return { body: parts.join(""), height: rowY - y };
  };

  /** Re-anchor a chart SVG string inside a parent SVG. {svg, height}. */
  png.nest = function (chartSvg, x, y, targetW) {
    var vb = chartSvg.match(/viewBox="0 0 ([0-9.]+) ([0-9.]+)"/);
    if (!vb) return { svg: "", height: 0 };
    var h = (parseFloat(vb[2]) / parseFloat(vb[1])) * targetW;
    return {
      svg: chartSvg.replace('width="100%"',
        'x="' + x + '" y="' + y + '" width="' + targetW + '" height="' + h + '"'),
      height: h
    };
  };

  /** Assemble a full export card SVG (pure). */
  png.cardSvg = function (title, metaLine, chartSvgs, matrix, payload) {
    var width = C.EXPORT_WIDTH, innerW = width - PAD * 2;
    var brand = TR.charts.brandOf(payload);
    var parts = [], y = PAD + 14;
    var titleLines = png.wrap(title, 70);
    titleLines.forEach(function (line) {
      parts.push(S.text(PAD, y, line,
        { "font-size": 18, "font-weight": 700, fill: "#1c2333" }));
      y += 24;
    });
    parts.push(S.text(PAD, y, metaLine, { "font-size": 11.5, fill: "#6b7280" }));
    y += 18;
    (chartSvgs || []).forEach(function (chartSvg) {
      if (!chartSvg) return;
      var nested = png.nest(chartSvg, PAD, y, innerW);
      parts.push(nested.svg);
      y += nested.height + 10;
    });
    if (matrix) {
      var table = png.svgTable(matrix, PAD, y, innerW, brand);
      parts.push(table.body);
      y += table.height;
    }
    var height = y + PAD;
    var frame = S.el("rect", { x: 0, y: 0, width: width, height: height,
      fill: "#ffffff" }) +
      S.el("rect", { x: 0, y: 0, width: width, height: 5, fill: brand });
    return S.root(width, height, title, frame + parts.join(""));
  };

  /** Rasterise an SVG string to a canvas at EXPORT_SCALE. */
  png.toCanvas = function (svgString, callback) {
    var vb = svgString.match(/viewBox="0 0 ([0-9.]+) ([0-9.]+)"/);
    if (!vb) { callback(null); return; }
    var w = parseFloat(vb[1]), h = parseFloat(vb[2]), scale = C.EXPORT_SCALE;
    var img = new Image();
    img.onload = function () {
      var canvas = document.createElement("canvas");
      canvas.width = Math.round(w * scale);
      canvas.height = Math.round(h * scale);
      var ctx = canvas.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      callback(canvas);
    };
    img.onerror = function () { callback(null); };
    img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svgString);
  };

  /** SVG string -> PNG blob (or null on failure). */
  png.toBlob = function (svgString, callback) {
    png.toCanvas(svgString, function (canvas) {
      if (!canvas) { callback(null); return; }
      canvas.toBlob(function (blob) { callback(blob); }, "image/png");
    });
  };

  function triggerDownload(blob, filename) {
    var link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
  }

  /** Build the export SVG for a question card. */
  png.questionSvg = function (q, payload, colIndex) {
    var cols = TR.data.bannerColumns(payload, q);
    var meta = [payload.project.name, payload.project.wave,
      "Chart column: " + (cols[colIndex] || "Total"),
      "Base: n=" + (q.bases ? fmt.base(q.bases[0]) : "–")]
      .filter(Boolean).join(" · ");
    var chartSvgs = [];
    try { chartSvgs.push(TR.charts.forQuestion(q, payload, colIndex)); } catch (e) { /* chart skipped, table still exports */ }
    try { chartSvgs.push(TR.charts.trend(q, payload, colIndex)); } catch (e) { /* trend skipped */ }
    return png.cardSvg((q.code || q.id) + " — " + q.title, meta, chartSvgs,
      TR.tables.matrix(q, payload), payload);
  };

  /** Download a question card as PNG. */
  png.downloadCard = function (card, payload) {
    var q = TR.data.questionById(payload, card.getAttribute("data-q"));
    if (!q) return;
    var colIndex = parseInt(card.getAttribute("data-col") || "0", 10) || 0;
    png.toBlob(png.questionSvg(q, payload, colIndex), function (blob) {
      if (!blob) { TR.wire.toast("PNG export failed — see console"); return; }
      triggerDownload(blob, fmt.slug((q.code || q.id) + "_" + q.title) + ".png");
      TR.wire.toast("PNG downloaded");
    });
  };

  /** Download a composite view as PNG. */
  png.downloadComposite = function (model, payload) {
    var svgString = png.cardSvg("Composite view — " + model.items.map(function (i) {
      return i.code; }).join(" + "),
      payload.project.name + " · " + (payload.project.wave || "") +
      " · column: " + model.column,
      [TR.composer.renderSvg(model, payload)], null, payload);
    png.toBlob(svgString, function (blob) {
      if (!blob) { TR.wire.toast("PNG export failed — see console"); return; }
      triggerDownload(blob, fmt.slug("composite_" + model.items.map(function (i) {
        return i.code; }).join("_")) + ".png");
      TR.wire.toast("PNG downloaded");
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
