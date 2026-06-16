/**
 * v2 exports — Tier A (clipboard editable table, hi-res PNG assembled as
 * pure SVG) and Tier B (native PPTX slides: real text, real tables, bars
 * as editable shapes) built from view-model matrices. Uses the v1 zip +
 * package plumbing (TR.zip / TR.pptx.package).
 *
 * SIZE-EXCEPTION: sequential OOXML slide assembly + raster pipeline;
 * splitting would fragment the geometry story.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt, S = TR.svg, esc = TR.fmt.escapeXml;

  var exporter = TR.exporter = {};
  var EMU = 914400, SLIDE_W = 13.333, SLIDE_H = 7.5, MARGIN = 0.55;
  var INK = "1C2333", GREY = "6B7280", WHITE = "FFFFFF", ZEBRA = "F3F4F8";

  /* ---------------- Tier A: clipboard ---------------- */

  exporter.copyTable = function (model) {
    var html = TR.render.clipboardHtml(model);
    var text = TR.render.tsv(model);
    var done = function (ok) {
      TR.shell.toast(ok ? "Table copied — paste into PowerPoint, Word or Excel"
        : "Copy blocked by the browser");
    };
    if (navigator.clipboard && global.ClipboardItem) {
      navigator.clipboard.write([new ClipboardItem({
        "text/html": new Blob([html], { type: "text/html" }),
        "text/plain": new Blob([text], { type: "text/plain" })
      })]).then(function () { done(true); }, function () { done(fallbackCopy(html)); });
    } else {
      done(fallbackCopy(html));
    }
  };

  function fallbackCopy(html) {
    var holder = document.createElement("div");
    holder.style.cssText = "position:fixed;left:-9999px;top:0;";
    holder.innerHTML = html;
    document.body.appendChild(holder);
    var range = document.createRange();
    range.selectNodeContents(holder);
    var sel = getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    sel.removeAllRanges();
    document.body.removeChild(holder);
    return ok;
  }

  /* ---------------- Tier A: PNG ---------------- */

  /** Assemble a card SVG: title, meta, optional chart, optional SVG table. */
  exporter.cardSvg = function (model, note, opts) {
    opts = opts || {};
    var W = 1100, PAD = 24, innerW = W - PAD * 2;
    var brand = TR.charts.brandOf();
    var parts = [], y = PAD + 14;
    wrapText(model.code + " — " + model.title, 80).forEach(function (line) {
      parts.push(S.text(PAD, y, line, { "font-size": 17, "font-weight": 700, fill: "#1c2333" }));
      y += 22;
    });
    var meta = [TR.AGG.project.name, TR.AGG.project.wave,
      model.source === "computed" ? "COMPUTED · filtered audience" : "published values",
      note || ""].filter(Boolean).join(" · ");
    parts.push(S.text(PAD, y, TR.charts.clip(meta, 130),
      { "font-size": 11, fill: "#6b7280" }));
    y += 16;
    if (opts.chartSvg) {
      var vb = opts.chartSvg.match(/viewBox="0 0 ([0-9.]+) ([0-9.]+)"/);
      if (vb) {
        var chartH = parseFloat(vb[2]) / parseFloat(vb[1]) * innerW;
        parts.push(opts.chartSvg.replace('width="100%"',
          'x="' + PAD + '" y="' + y + '" width="' + innerW +
          '" height="' + chartH + '"'));
        y += chartH + 12;
      }
    }
    if (opts.includeTable !== false) {
      var table = svgTable(TR.render.matrix(model), PAD, y, innerW, brand);
      parts.push(table.body);
      y += table.height;
    }
    y += PAD;
    var frame = S.el("rect", { x: 0, y: 0, width: W, height: y, fill: "#ffffff" }) +
      S.el("rect", { x: 0, y: 0, width: W, height: 5, fill: brand });
    return S.root(W, y, model.code, frame + parts.join(""));
  };

  function wrapText(text, maxChars) {
    var words = String(text).split(" "), lines = [], cur = "";
    words.forEach(function (w) {
      var cand = cur ? cur + " " + w : w;
      if (cand.length > maxChars && cur) { lines.push(cur); cur = w; }
      else cur = cand;
    });
    if (cur) lines.push(cur);
    return lines;
  }

  function svgTable(matrix, x, y, width, brand) {
    var nCols = matrix.head.length;
    var labelW = Math.round(width * 0.26);
    var colW = (width - labelW) / Math.max(nCols - 1, 1);
    var rowH = 19, headH = 24;
    var parts = [], rowY = y;
    var cellX = function (i) {
      return i === 0 ? x + 6 : x + labelW + (i - 1) * colW + colW / 2;
    };
    parts.push(S.el("rect", { x: x, y: rowY, width: width, height: headH, fill: brand, rx: 3 }));
    matrix.head.forEach(function (h, i) {
      parts.push(S.text(cellX(i), rowY + 16, TR.charts.clip(h, i === 0 ? 34 : 13),
        { "text-anchor": i === 0 ? "start" : "middle", "font-size": 10,
          "font-weight": 700, fill: "#ffffff" }));
    });
    rowY += headH;
    matrix.body.forEach(function (row, r) {
      var fill = row.kind === "stat" ? "#f3f4f8" : (r % 2 ? "#fafbfe" : "#ffffff");
      parts.push(S.el("rect", { x: x, y: rowY, width: width, height: rowH, fill: fill }));
      row.cells.forEach(function (cell, i) {
        parts.push(S.text(cellX(i), rowY + 13.5, TR.charts.clip(cell, i === 0 ? 38 : 12),
          { "text-anchor": i === 0 ? "start" : "middle", "font-size": 10,
            "font-weight": row.kind === "stat" ? 700 : 400,
            "font-style": row.kind === "base" ? "italic" : null,
            fill: row.kind === "base" ? "#6b7280" : "#1c2333" }));
      });
      rowY += rowH;
    });
    parts.push(S.el("rect", { x: x, y: y, width: width, height: rowY - y,
      fill: "none", stroke: "#e5e7ef" }));
    return { body: parts.join(""), height: rowY - y };
  }

  exporter.downloadPng = function (model, note, opts) {
    var svgString = exporter.cardSvg(model, note, opts);
    var vb = svgString.match(/viewBox="0 0 ([0-9.]+) ([0-9.]+)"/);
    var img = new Image();
    img.onload = function () {
      var scale = 3;
      var canvas = document.createElement("canvas");
      canvas.width = Math.round(parseFloat(vb[1]) * scale);
      canvas.height = Math.round(parseFloat(vb[2]) * scale);
      var ctx = canvas.getContext("2d");
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      canvas.toBlob(function (blob) {
        if (!blob) { TR.shell.toast("PNG export failed"); return; }
        var link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = fmt.slug(model.code + "_" + model.title) + ".png";
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(link.href);
        TR.shell.toast("PNG downloaded (3×)");
      }, "image/png");
    };
    img.onerror = function () { TR.shell.toast("PNG export failed"); };
    img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svgString);
  };

  /* ---------------- Tier B: native PPTX ---------------- */

  function inch(v) { return Math.round(v * EMU); }

  function para(text, o) {
    if (!text) return "<a:p/>";
    return "<a:p><a:pPr" + (o.align ? ' algn="' + o.align + '"' : "") + "/>" +
      '<a:r><a:rPr lang="en-US" dirty="0" sz="' + Math.round(o.size * 100) + '"' +
      (o.bold ? ' b="1"' : "") + (o.italic ? ' i="1"' : "") + ">" +
      '<a:solidFill><a:srgbClr val="' + (o.colour || INK) + '"/></a:solidFill>' +
      "</a:rPr><a:t>" + esc(text) + "</a:t></a:r></a:p>";
  }

  function textBox(id, box, paras) {
    return '<p:sp><p:nvSpPr><p:cNvPr id="' + id + '" name="Text"/>' +
      '<p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr>' +
      '<a:xfrm><a:off x="' + inch(box.x) + '" y="' + inch(box.y) + '"/>' +
      '<a:ext cx="' + inch(box.w) + '" cy="' + inch(box.h) + '"/></a:xfrm>' +
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>' +
      '<p:txBody><a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr><a:lstStyle/>' +
      paras.join("") + "</p:txBody></p:sp>";
  }

  function rectShape(id, box, colour) {
    return '<p:sp><p:nvSpPr><p:cNvPr id="' + id + '" name="Bar"/><p:cNvSpPr/>' +
      "<p:nvPr/></p:nvSpPr><p:spPr>" +
      '<a:xfrm><a:off x="' + inch(box.x) + '" y="' + inch(box.y) + '"/>' +
      '<a:ext cx="' + inch(box.w) + '" cy="' + inch(box.h) + '"/></a:xfrm>' +
      '<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 18000"/></a:avLst></a:prstGeom>' +
      '<a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill>' +
      "<a:ln><a:noFill/></a:ln></p:spPr>" +
      "<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>";
  }

  // Sharp-cornered filled rectangle (axis baselines, gridlines).
  function fillRect(id, box, colour) {
    return '<p:sp><p:nvSpPr><p:cNvPr id="' + id + '" name="Rule"/><p:cNvSpPr/>' +
      "<p:nvPr/></p:nvSpPr><p:spPr>" +
      '<a:xfrm><a:off x="' + inch(box.x) + '" y="' + inch(box.y) + '"/>' +
      '<a:ext cx="' + inch(box.w) + '" cy="' + inch(box.h) + '"/></a:xfrm>' +
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>' +
      '<a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill>' +
      "<a:ln><a:noFill/></a:ln></p:spPr>" +
      "<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>";
  }

  // Filled ellipse with a thin white halo — a dot-plot marker.
  function ellipseShape(id, box, colour) {
    return '<p:sp><p:nvSpPr><p:cNvPr id="' + id + '" name="Dot"/><p:cNvSpPr/>' +
      "<p:nvPr/></p:nvSpPr><p:spPr>" +
      '<a:xfrm><a:off x="' + inch(box.x) + '" y="' + inch(box.y) + '"/>' +
      '<a:ext cx="' + inch(box.w) + '" cy="' + inch(box.h) + '"/></a:xfrm>' +
      '<a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>' +
      '<a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill>' +
      '<a:ln w="12700"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:ln>' +
      "</p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>";
  }

  /**
   * Horizontal dot plot as native shapes (PowerPoint has no dot-plot chart
   * type). Mirrors render.dotChart — category labels left, a faint baseline
   * per row, vertical gridlines + % ticks, one positioned dot per column,
   * coloured from the report palette. Editable shapes (no "Edit Data", which
   * a dot plot does not need). Returns the shape XML for the slide tree.
   */
  function dotPlotShapes(next, box, model, cols) {
    var data = TR.render.chartRows(model);
    var rows = data.rows || [];
    if (!rows.length) return "";
    var axisMax = data.axisMax || 100;
    var palette = TR.render.palette();
    var multi = cols.length > 1;
    var labelW = Math.min(box.w * 0.34, 3.2);
    var plotX = box.x + labelW;
    var plotW = box.w - labelW - 0.35;
    var axisH = 0.3, legendH = multi ? 0.35 : 0;
    var usableH = Math.max(box.h - axisH - legendH, 0.5);
    var rowH = usableH / rows.length;
    var dotD = Math.min(0.16, rowH * 0.5);
    var xml = "";
    [0, 0.25, 0.5, 0.75, 1].forEach(function (f) {
      var gx = plotX + plotW * f;
      xml += fillRect(next(), { x: gx, y: box.y, w: 0.008, h: usableH }, "EEF0F7");
      xml += textBox(next(), { x: gx - 0.3, y: box.y + usableH + 0.02, w: 0.6, h: 0.2 },
        [para(Math.round(axisMax * f) + "%", { size: 8, colour: GREY, align: "ctr" })]);
    });
    rows.forEach(function (r, i) {
      var cy = box.y + i * rowH + rowH / 2;
      var labH = Math.min(rowH - 0.04, 0.5);
      xml += textBox(next(), { x: box.x, y: cy - labH / 2, w: labelW - 0.12, h: labH },
        [para(r.label, { size: 9, colour: INK, align: "l" })]);
      xml += fillRect(next(), { x: plotX, y: cy - 0.006, w: plotW, h: 0.012 }, "E7E9F2");
      cols.forEach(function (ci, k) {
        var v = r.cells[ci] ? r.cells[ci].pct : null;
        if (v === null || v === undefined) return;
        var frac = Math.max(Math.min(v / axisMax, 1), 0);
        var cx = plotX + frac * plotW;
        var colour = palette[k % palette.length].replace("#", "").toUpperCase();
        xml += ellipseShape(next(), { x: cx - dotD / 2, y: cy - dotD / 2, w: dotD, h: dotD }, colour);
        // value label beside the dot (bold, dot-coloured), like the IPK deck;
        // flips to the left of the dot near the right edge so it never clips
        var labelLeft = frac > 0.82;
        xml += textBox(next(),
          labelLeft ? { x: cx - dotD / 2 - 0.55, y: cy - 0.11, w: 0.5, h: 0.22 }
                    : { x: cx + dotD / 2 + 0.03, y: cy - 0.11, w: 0.5, h: 0.22 },
          [para(String(Math.round(v)), { size: 9, bold: true, colour: colour,
            align: labelLeft ? "r" : "l" })]);
      });
    });
    if (multi) {
      var lx = plotX, ly = box.y + usableH + axisH;
      cols.forEach(function (ci, k) {
        var lbl = model.columns[ci] ? model.columns[ci].label : "?";
        xml += ellipseShape(next(), { x: lx, y: ly + 0.02, w: 0.14, h: 0.14 },
          palette[k % palette.length].replace("#", "").toUpperCase());
        var lw = Math.min(2.2, 0.3 + lbl.length * 0.075);
        xml += textBox(next(), { x: lx + 0.2, y: ly - 0.04, w: lw, h: 0.24 },
          [para(lbl, { size: 9, colour: INK })]);
        lx += 0.2 + lw + 0.25;
      });
    }
    return xml;
  }

  function tableFrame(id, box, matrix, brand, fontSize) {
    var nCols = matrix.head.length;
    var labelW = Math.min(box.w * 0.28, 3.4);
    var colW = (box.w - labelW) / Math.max(nCols - 1, 1);
    var rowH = Math.round(inch(Math.min(0.3, box.h / (matrix.body.length + 1))));
    var grid = '<a:gridCol w="' + inch(labelW) + '"/>';
    for (var i = 1; i < nCols; i++) grid += '<a:gridCol w="' + inch(colW) + '"/>';
    var cell = function (text, o) {
      return "<a:tc><a:txBody><a:bodyPr/><a:lstStyle/>" + para(text, o) +
        '</a:txBody><a:tcPr marL="27432" marR="27432" marT="9144" marB="9144" anchor="ctr">' +
        '<a:solidFill><a:srgbClr val="' + o.fill + '"/></a:solidFill></a:tcPr></a:tc>';
    };
    var rows = ['<a:tr h="' + rowH + '">' + matrix.head.map(function (h, i) {
      return cell(h, { size: fontSize, bold: true, colour: WHITE, fill: brand,
        align: i === 0 ? "l" : "ctr" });
    }).join("") + "</a:tr>"];
    matrix.body.forEach(function (row, r) {
      var fill = row.kind === "stat" ? ZEBRA : (r % 2 ? "FAFBFE" : WHITE);
      rows.push('<a:tr h="' + rowH + '">' + row.cells.map(function (text, i) {
        return cell(text, { size: fontSize, bold: row.kind === "stat",
          italic: row.kind === "base", colour: row.kind === "base" ? GREY : INK,
          fill: fill, align: i === 0 ? "l" : "ctr" });
      }).join("") + "</a:tr>");
    });
    return '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="' + id +
      '" name="Table"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>' +
      '<p:xfrm><a:off x="' + inch(box.x) + '" y="' + inch(box.y) + '"/>' +
      '<a:ext cx="' + inch(box.w) + '" cy="' + inch(box.h) + '"/></p:xfrm>' +
      '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">' +
      '<a:tbl><a:tblPr firstRow="1"/><a:tblGrid>' + grid + "</a:tblGrid>" +
      rows.join("") + "</a:tbl></a:graphicData></a:graphic></p:graphicFrame>";
  }

  /** Fit a matrix to a slide's row budget. When rows must be dropped the
   *  last visible row says how many — a silently truncated table reads
   *  as complete, which misstates the data. */
  function fitMatrix(matrix, maxRows) {
    if (matrix.body.length <= maxRows) return matrix;
    var kept = matrix.body.slice(0, Math.max(maxRows - 1, 1));
    var note = ["… +" + (matrix.body.length - kept.length) +
      " more rows — see the full report"];
    while (note.length < matrix.head.length) note.push("");
    return { head: matrix.head,
      body: kept.concat([{ kind: "base", cells: note }]) };
  }

  function wrapSlide(content) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
      '<p:sld xmlns:a="' + TR.pptx.NS.a + '" xmlns:r="' + TR.pptx.NS.r +
      '" xmlns:p="' + TR.pptx.NS.p + '"><p:cSld><p:spTree>' +
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>' +
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>' +
      '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>' +
      content + "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>";
  }

  /* ---------- NATIVE PowerPoint chart objects ----------
     A real c:chartSpace part + an embedded Excel workbook, so the chart is
     a genuine chart object: change its type in PowerPoint, restyle it, and
     "Edit Data" opens the data in Excel. Honours the report's selected
     chart type, row kind and columns. */

  var C_NS = 'xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" ' +
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" ' +
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

  function chartAxes(catPos, valPos, fmtCode, hideVal) {
    return '<c:catAx><c:axId val="111111111"/><c:scaling>' +
      '<c:orientation val="minMax"/></c:scaling><c:delete val="0"/>' +
      '<c:axPos val="' + catPos + '"/><c:crossAx val="222222222"/></c:catAx>' +
      '<c:valAx><c:axId val="222222222"/><c:scaling>' +
      '<c:orientation val="minMax"/></c:scaling><c:delete val="' +
      (hideVal ? "1" : "0") + '"/>' +
      '<c:axPos val="' + valPos + '"/>' +
      '<c:numFmt formatCode="' + (fmtCode || "0&quot;%&quot;") +
      '" sourceLinked="0"/>' +
      '<c:crossAx val="111111111"/></c:valAx>';
  }

  /** Value data labels (the "48%" on each bar/segment). pos = "outEnd" for
   *  clustered bar/column, "ctr" for percent-stacked. colour is the label ink
   *  (dark outside a bar, white centred on a coloured segment). */
  function dataLabels(pos, colour) {
    return '<c:dLbls><c:numFmt formatCode="0&quot;%&quot;" sourceLinked="0"/>' +
      '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>' +
      '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1000" b="1">' +
      '<a:solidFill><a:srgbClr val="' + (colour || "1C2333") + '"/></a:solidFill>' +
      '<a:latin typeface="Arial"/></a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>' +
      '<c:dLblPos val="' + pos + '"/>' +
      '<c:showLegendKey val="0"/><c:showVal val="1"/><c:showCatName val="0"/>' +
      '<c:showSerName val="0"/><c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>';
  }

  function chartSeries(model, rows, cols, type) {
    var palette = TR.render.palette();
    // Single-series bar/column and pie colour by CATEGORY (the semantic palette
    // — negative = red, positive = green), matching the on-screen pins. Multiple
    // cuts keep one colour per series so the columns stay comparable.
    var catCol = (type === "pie" || (cols.length === 1 && type !== "dot"))
      ? TR.render.categoryColours(rows) : null;
    var catPts = rows.map(function (r, i) {
      return '<c:pt idx="' + i + '"><c:v>' + esc(r.label) + "</c:v></c:pt>";
    }).join("");
    var catRef = '<c:cat><c:strRef><c:f>Sheet1!$A$2:$A$' + (rows.length + 1) +
      '</c:f><c:strCache><c:ptCount val="' + rows.length + '"/>' + catPts +
      "</c:strCache></c:strRef></c:cat>";
    return cols.map(function (ci, k) {
      var col = model.columns[ci];
      var colour = palette[k % palette.length].replace("#", "").toUpperCase();
      var letter = String.fromCharCode(66 + k);
      var valPts = rows.map(function (r, i) {
        var v = r.cells[ci] ? r.cells[ci].pct : null;
        return '<c:pt idx="' + i + '"><c:v>' +
          (v === null || v === undefined ? "" : Math.round(v * 10) / 10) +
          "</c:v></c:pt>";
      }).join("");
      var dPts = catCol ? rows.map(function (_, i) {
        var pc = catCol[i].replace("#", "").toUpperCase();
        return '<c:dPt><c:idx val="' + i + '"/><c:bubble3D val="0"/>' +
          '<c:spPr><a:solidFill><a:srgbClr val="' + pc + '"/></a:solidFill></c:spPr></c:dPt>';
      }).join("") : "";
      var lineStyle = type === "dot"
        ? '<c:spPr><a:ln><a:noFill/></a:ln></c:spPr>' +
          '<c:marker><c:symbol val="circle"/><c:size val="7"/>' +
          '<c:spPr><a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill></c:spPr></c:marker>'
        : '<c:spPr><a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill></c:spPr>';
      return '<c:ser><c:idx val="' + k + '"/><c:order val="' + k + '"/>' +
        '<c:tx><c:strRef><c:f>Sheet1!$' + letter + '$1</c:f><c:strCache>' +
        '<c:ptCount val="1"/><c:pt idx="0"><c:v>' + esc(col ? col.label : "Series") +
        "</c:v></c:pt></c:strCache></c:strRef></c:tx>" +
        lineStyle + dPts + catRef +
        '<c:val><c:numRef><c:f>Sheet1!$' + letter + "$2:$" + letter + "$" +
        (rows.length + 1) + '</c:f><c:numCache><c:formatCode>General</c:formatCode>' +
        '<c:ptCount val="' + rows.length + '"/>' + valPts +
        "</c:numCache></c:numRef></c:val></c:ser>";
    }).join("");
  }

  /**
   * Series for a 100%-stacked bar: TRANSPOSED relative to chartSeries —
   * categories are the selected columns (one bar each) and there is one
   * series per row (the segments that stack), coloured by segment. Mirrors
   * the on-screen render.stackedChart so the PPTX matches the report/PNG.
   */
  function chartSeriesStacked(model, rows, cols) {
    // Colour the stacked segments with the SAME semantic palette the on-screen
    // render.stackedChart uses (negative = red, positive = green), so the PPTX
    // matches the pins.
    var catCol = TR.render.categoryColours(rows);
    var rampColour = function (i) {
      return catCol[i].replace("#", "").toUpperCase();
    };
    var catPts = cols.map(function (ci, i) {
      var c = model.columns[ci];
      return '<c:pt idx="' + i + '"><c:v>' + esc(c ? c.label : "Series") + "</c:v></c:pt>";
    }).join("");
    var catRef = '<c:cat><c:strRef><c:f>Sheet1!$A$2:$A$' + (cols.length + 1) +
      '</c:f><c:strCache><c:ptCount val="' + cols.length + '"/>' + catPts +
      "</c:strCache></c:strRef></c:cat>";
    return rows.map(function (r, k) {
      var colour = rampColour(k);
      var letter = String.fromCharCode(66 + k);
      var valPts = cols.map(function (ci, i) {
        var v = r.cells[ci] ? r.cells[ci].pct : null;
        return '<c:pt idx="' + i + '"><c:v>' +
          (v === null || v === undefined ? "" : Math.round(v * 10) / 10) +
          "</c:v></c:pt>";
      }).join("");
      return '<c:ser><c:idx val="' + k + '"/><c:order val="' + k + '"/>' +
        '<c:tx><c:strRef><c:f>Sheet1!$' + letter + '$1</c:f><c:strCache>' +
        '<c:ptCount val="1"/><c:pt idx="0"><c:v>' + esc(r.label) +
        "</c:v></c:pt></c:strCache></c:strRef></c:tx>" +
        '<c:spPr><a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill></c:spPr>' +
        catRef +
        '<c:val><c:numRef><c:f>Sheet1!$' + letter + "$2:$" + letter + "$" +
        (cols.length + 1) + '</c:f><c:numCache><c:formatCode>General</c:formatCode>' +
        '<c:ptCount val="' + cols.length + '"/>' + valPts +
        "</c:numCache></c:numRef></c:val></c:ser>";
    }).join("");
  }

  /**
   * Build a native chart for a model: {xml, workbook} ready for the
   * packager, honouring chart type, row kind (detail/NETs) and columns.
   */
  exporter.buildChart = function (model, type, cols) {
    var rows = TR.render.chartRows(model).rows;
    if (!rows.length || !cols.length) return null;
    if (type === "pie") cols = [cols[0]];
    var series = type === "stacked"
      ? chartSeriesStacked(model, rows, cols)
      : chartSeries(model, rows, cols, type);
    var plot, axesXml = "";
    if (type === "column") {
      plot = '<c:barChart><c:barDir val="col"/><c:grouping val="clustered"/>' +
        '<c:varyColors val="0"/>' + series + dataLabels("outEnd") +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>';
      axesXml = chartAxes("b", "l");
    } else if (type === "stacked") {
      plot = '<c:barChart><c:barDir val="bar"/><c:grouping val="percentStacked"/>' +
        '<c:varyColors val="0"/>' + series + dataLabels("ctr", "FFFFFF") +
        '<c:overlap val="100"/>' +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>';
      // Percent-stacked normalises to fractions, so the literal-% value axis is
      // meaningless (and the pin shows none) — hide it; the segment labels carry
      // the %s.
      axesXml = chartAxes("l", "b", null, true);
    } else if (type === "pie") {
      // Labels OUTSIDE the pie with leader lines so they read on any slice
      // colour, formatted as %.
      plot = '<c:pieChart><c:varyColors val="1"/>' + series +
        '<c:dLbls><c:numFmt formatCode="0&quot;%&quot;" sourceLinked="0"/>' +
        '<c:dLblPos val="outEnd"/>' +
        '<c:showLegendKey val="0"/><c:showVal val="1"/>' +
        '<c:showCatName val="0"/><c:showSerName val="0"/><c:showPercent val="0"/>' +
        '<c:showBubbleSize val="0"/><c:showLeaderLines val="1"/></c:dLbls></c:pieChart>';
    } else if (type === "dot") {
      plot = '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>' +
        series + '<c:marker val="1"/>' +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:lineChart>';
      axesXml = chartAxes("b", "l");
    } else {
      plot = '<c:barChart><c:barDir val="bar"/><c:grouping val="clustered"/>' +
        '<c:varyColors val="0"/>' + series + dataLabels("outEnd") +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>';
      axesXml = chartAxes("l", "b");
    }
    var xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
      "<c:chartSpace " + C_NS + "><c:chart><c:plotArea><c:layout/>" +
      plot + axesXml + "</c:plotArea>" +
      ((cols.length > 1 || type === "pie" || type === "stacked")
        ? '<c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend>' : "") +
      '<c:plotVisOnly val="1"/></c:chart>' +
      // Default chart font — clean Arial in the report ink so axis/legend text
      // matches the on-screen look.
      '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1000">' +
      '<a:solidFill><a:srgbClr val="3B4252"/></a:solidFill>' +
      '<a:latin typeface="Arial"/></a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>' +
      '<c:externalData r:id="rId1"><c:autoUpdate val="0"/></c:externalData></c:chartSpace>';
    // Embedded workbook must mirror the series layout so "Edit Data" resolves:
    // stacked is transposed (columns down col A, one segment-series per column).
    var num = function (v) {
      return v === null || v === undefined ? "" : Math.round(v * 10) / 10;
    };
    var workbookRows = type === "stacked"
      ? [[""].concat(rows.map(function (r) { return r.label; }))].concat(
          cols.map(function (ci) {
            return [model.columns[ci] ? model.columns[ci].label : "Series"]
              .concat(rows.map(function (r) {
                return num(r.cells[ci] ? r.cells[ci].pct : null);
              }));
          }))
      : [[""].concat(cols.map(function (ci) {
          return model.columns[ci] ? model.columns[ci].label : "Series";
        }))].concat(rows.map(function (r) {
          return [r.label].concat(cols.map(function (ci) {
            return num(r.cells[ci] ? r.cells[ci].pct : null);
          }));
        }));
    // the sheet MUST be named Sheet1: the c:f formula refs above say
    // Sheet1!… — on "Edit Data" Excel resolves them against the embedded
    // workbook, and any other sheet name turns every series into #REF!
    return { xml: xml, workbook: TR.xlsx.bytes("Sheet1", workbookRows) };
  };

  /**
   * Native line chart over wave years for the trended rows of a model
   * (real or pseudo): one series per row with history, categories = the
   * union of years incl. the current wave. {xml, workbook} or null.
   */
  exporter.buildTrendChart = function (model) {
    var rows = TR.render.trendRows(model).slice(0, 6);
    if (!rows.length) return null;
    var palette = TR.render.palette();
    var years = [];
    rows.forEach(function (r) {
      TR.render.wavePoints(r).forEach(function (p) {
        if (p.year !== null && years.indexOf(p.year) === -1) years.push(p.year);
      });
    });
    years.sort();
    var pointsOf = function (r) {
      var byYear = {};
      TR.render.wavePoints(r).forEach(function (p) { byYear[p.year] = p.value; });
      return years.map(function (y) {
        return byYear[y] === undefined ? null : Math.round(byYear[y] * 10) / 10;
      });
    };
    var catPts = years.map(function (y, i) {
      return '<c:pt idx="' + i + '"><c:v>' + y + "</c:v></c:pt>";
    }).join("");
    var catRef = '<c:cat><c:strRef><c:f>Sheet1!$A$2:$A$' + (years.length + 1) +
      '</c:f><c:strCache><c:ptCount val="' + years.length + '"/>' + catPts +
      "</c:strCache></c:strRef></c:cat>";
    var series = rows.map(function (r, k) {
      var colour = palette[k % palette.length].replace("#", "").toUpperCase();
      var letter = String.fromCharCode(66 + k);
      var valPts = pointsOf(r).map(function (v, i) {
        return '<c:pt idx="' + i + '"><c:v>' + (v === null ? "" : v) + "</c:v></c:pt>";
      }).join("");
      return '<c:ser><c:idx val="' + k + '"/><c:order val="' + k + '"/>' +
        '<c:tx><c:strRef><c:f>Sheet1!$' + letter + '$1</c:f><c:strCache>' +
        '<c:ptCount val="1"/><c:pt idx="0"><c:v>' + esc(r.label) +
        "</c:v></c:pt></c:strCache></c:strRef></c:tx>" +
        '<c:spPr><a:ln w="28575"><a:solidFill><a:srgbClr val="' + colour +
        '"/></a:solidFill></a:ln></c:spPr>' +
        '<c:marker><c:symbol val="circle"/><c:size val="6"/>' +
        '<c:spPr><a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill></c:spPr></c:marker>' +
        catRef +
        '<c:val><c:numRef><c:f>Sheet1!$' + letter + "$2:$" + letter + "$" +
        (years.length + 1) + '</c:f><c:numCache><c:formatCode>General</c:formatCode>' +
        '<c:ptCount val="' + years.length + '"/>' + valPts +
        "</c:numCache></c:numRef></c:val></c:ser>";
    }).join("");
    var pctOnly = rows.every(function (r) { return r.kind !== "mean"; });
    var xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
      "<c:chartSpace " + C_NS + "><c:chart><c:plotArea><c:layout/>" +
      '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>' +
      series + '<c:marker val="1"/>' +
      '<c:axId val="111111111"/><c:axId val="222222222"/></c:lineChart>' +
      chartAxes("b", "l", pctOnly ? null : "General") + "</c:plotArea>" +
      (rows.length > 1
        ? '<c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend>' : "") +
      '<c:plotVisOnly val="1"/></c:chart>' +
      // Default chart font — clean Arial in the report ink so axis/legend text
      // matches the on-screen look.
      '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1000">' +
      '<a:solidFill><a:srgbClr val="3B4252"/></a:solidFill>' +
      '<a:latin typeface="Arial"/></a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>' +
      '<c:externalData r:id="rId1"><c:autoUpdate val="0"/></c:externalData></c:chartSpace>';
    var workbookRows = [[""].concat(rows.map(function (r) { return r.label; }))]
      .concat(years.map(function (y, i) {
        return [y].concat(rows.map(function (r) {
          var v = pointsOf(r)[i];
          return v === null ? "" : v;
        }));
      }));
    // sheet name must match the Sheet1!… formula refs (see buildChart)
    return { xml: xml, workbook: TR.xlsx.bytes("Sheet1", workbookRows) };
  };

  /**
   * Exhibit slide: stacked native chart objects (each its own editable
   * chart, rels rId2..rId(1+n)) + optional table + insight band.
   * @param {object} spec - {title, meta, charts, matrix, note}.
   */
  exporter.exhibitSlide = function (spec) {
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    var contentW = SLIDE_W - MARGIN * 2;
    var hasNote = !!(spec.note && spec.note.trim());
    var noteLines = hasNote ? wrapText(spec.note, 150).slice(0, 3) : [];
    var noteH = hasNote ? 0.45 + noteLines.length * 0.24 : 0;
    var content =
      rectShape(next(), { x: 0, y: 0, w: SLIDE_W, h: 0.07 }, brand) +
      textBox(next(), { x: MARGIN, y: 0.3, w: contentW, h: 0.65 },
        [para(spec.title, { size: 19, bold: true, colour: brand })]) +
      textBox(next(), { x: MARGIN, y: 0.95, w: contentW, h: 0.3 },
        [para(spec.meta || "", { size: 10.5, colour: GREY })]);
    var top = 1.45, bottom = SLIDE_H - 0.35 - noteH;
    var charts = spec.charts || [];
    var blocks = charts.length + (spec.matrix ? 1 : 0);
    var blockH = blocks ? (bottom - top - (blocks - 1) * 0.2) / blocks : 0;
    charts.forEach(function (_, k) {
      content += chartFrame(next(),
        { x: MARGIN, y: top, w: contentW, h: blockH }, "rId" + (2 + k));
      top += blockH + 0.2;
    });
    if (spec.matrix) {
      var matrix = fitMatrix(spec.matrix,
        Math.max(3, Math.floor(blockH / 0.28) - 1));
      content += tableFrame(next(), { x: MARGIN, y: top, w: contentW,
        h: Math.min(blockH, (matrix.body.length + 1) * 0.28) }, matrix, brand,
        matrix.head.length > 8 ? 8.5 : 10);
    }
    if (hasNote) {
      var noteY = SLIDE_H - 0.25 - noteH;
      content += rectShape(next(), { x: MARGIN, y: noteY, w: contentW, h: noteH }, "FBF6E8") +
        rectShape(next(), { x: MARGIN, y: noteY, w: 0.05, h: noteH }, "CC9900") +
        textBox(next(), { x: MARGIN + 0.2, y: noteY + 0.08, w: contentW - 0.4, h: noteH - 0.12 },
          [para("ANALYST INSIGHT", { size: 8.5, bold: true, colour: "CC9900" })]
            .concat(noteLines.map(function (line) {
              return para(line, { size: 11.5, colour: INK });
            })));
    }
    return { xml: wrapSlide(content), charts: charts };
  };

  function chartFrame(id, box, relId) {
    return '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="' + id +
      '" name="Chart"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>' +
      '<p:xfrm><a:off x="' + inch(box.x) + '" y="' + inch(box.y) + '"/>' +
      '<a:ext cx="' + inch(box.w) + '" cy="' + inch(box.h) + '"/></p:xfrm>' +
      '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">' +
      '<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" ' +
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="' +
      relId + '"/></a:graphicData></a:graphic></p:graphicFrame>';
  }

  /**
   * Slide for one story item: chart = a NATIVE chart object honouring the
   * pinned type/rows/columns (editable in PowerPoint, data in Excel);
   * table = native a:tbl; insight = full-width callout band at the bottom.
   * @returns {{xml: string, charts: Array}} rich slide for the packager.
   */
  exporter.slideForModel = function (model, commentary, flags) {
    flags = flags || { chart: false, table: true, insight: true };
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    var hasNote = !!(flags.insight && commentary && commentary.trim());
    var contentW = SLIDE_W - MARGIN * 2;
    var noteLines = hasNote ? wrapText(commentary, 150).slice(0, 3) : [];
    var noteH = hasNote ? 0.45 + noteLines.length * 0.24 : 0;
    var charts = [];
    var content =
      rectShape(next(), { x: 0, y: 0, w: SLIDE_W, h: 0.07 }, brand) +
      textBox(next(), { x: MARGIN, y: 0.3, w: contentW, h: 0.65 },
        [para(model.code + " — " + model.title, { size: 19, bold: true, colour: brand })]) +
      textBox(next(), { x: MARGIN, y: 0.95, w: contentW, h: 0.3 },
        [para([TR.AGG.project.name, TR.AGG.project.wave,
          model.source === "computed" ? "filtered audience (live recompute)" : "published values",
          flags.intervals
            ? TR.conf.methodNote(TR.conf.modelIntervalKind(model)) : "",
          model.filterNote || ""].filter(Boolean).join(" · "),
          { size: 10.5, colour: GREY })]);
    var top = 1.45, bottom = SLIDE_H - 0.35 - noteH;
    if (flags.chart) {
      var dcols = (flags.chartCols && flags.chartCols.length) ? flags.chartCols : [0];
      var chartH = flags.table ? Math.min(2.9, bottom - top - 1.4) : bottom - top;
      if ((flags.chartType || "bar") === "dot") {
        // A horizontal dot plot has no native PowerPoint chart type — draw it
        // as shapes (matches the on-screen pin; no chart part for this slide).
        content += dotPlotShapes(next, { x: MARGIN, y: top, w: contentW, h: chartH },
          model, dcols);
        top += chartH + 0.2;
      } else {
        var chart = exporter.buildChart(model, flags.chartType || "bar", dcols);
        if (chart) {
          charts.push(chart);
          content += chartFrame(next(),
            { x: MARGIN, y: top, w: contentW, h: chartH }, "rId2");
          top += chartH + 0.2;
        }
      }
    }
    if (flags.table) {
      var matrix = fitMatrix(TR.render.matrix(model),
        Math.max(4, Math.floor((bottom - top) / 0.3) - 1));
      content += tableFrame(next(), { x: MARGIN, y: top, w: contentW,
        h: Math.min(bottom - top, (matrix.body.length + 1) * 0.3) }, matrix, brand,
        matrix.head.length > 7 ? 9 : 10);
    }
    if (hasNote) {
      var noteY = SLIDE_H - 0.25 - noteH;
      content += rectShape(next(), { x: MARGIN, y: noteY, w: contentW, h: noteH }, "FBF6E8") +
        rectShape(next(), { x: MARGIN, y: noteY, w: 0.05, h: noteH }, "CC9900") +
        textBox(next(), { x: MARGIN + 0.2, y: noteY + 0.08, w: contentW - 0.4, h: noteH - 0.12 },
          [para("ANALYST INSIGHT", { size: 8.5, bold: true, colour: "CC9900" })]
            .concat(noteLines.map(function (line) {
              return para(line, { size: 11.5, colour: INK });
            })));
    }
    return { xml: wrapSlide(content), charts: charts };
  };

  /** Section divider slide (story dividers). */
  exporter.dividerSlide = function (title, subtitle) {
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    return wrapSlide(
      rectShape(next(), { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H }, brand) +
      rectShape(next(), { x: MARGIN, y: 3.55, w: 1.4, h: 0.05 }, "CC9900") +
      textBox(next(), { x: MARGIN, y: 2.7, w: SLIDE_W - MARGIN * 2, h: 0.9 },
        [para(title, { size: 30, bold: true, colour: WHITE })]) +
      textBox(next(), { x: MARGIN, y: 3.75, w: SLIDE_W - MARGIN * 2, h: 0.5 },
        [para(subtitle || "", { size: 13, colour: "D9DCEC" })]));
  };

  /** Generic title + native table slide (heatmaps, composites). */
  exporter.matrixSlide = function (title, metaLine, matrix) {
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    matrix = fitMatrix(matrix, 15);
    return wrapSlide(
      rectShape(next(), { x: 0, y: 0, w: SLIDE_W, h: 0.07 }, brand) +
      textBox(next(), { x: MARGIN, y: 0.3, w: SLIDE_W - MARGIN * 2, h: 0.6 },
        [para(title, { size: 19, bold: true, colour: brand })]) +
      textBox(next(), { x: MARGIN, y: 0.92, w: SLIDE_W - MARGIN * 2, h: 0.3 },
        [para(metaLine || "", { size: 10.5, colour: GREY })]) +
      tableFrame(next(), { x: MARGIN, y: 1.35, w: SLIDE_W - MARGIN * 2,
        h: Math.min(5.7, (matrix.body.length + 1) * 0.32) }, matrix, brand,
        matrix.head.length > 8 ? 8.5 : 10));
  };

  exporter.titleSlide = function (itemCount) {
    var p = TR.AGG.project;
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    return wrapSlide(
      rectShape(next(), { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H }, brand) +
      textBox(next(), { x: 1, y: 2.5, w: SLIDE_W - 2, h: 1.1 },
        [para(p.name, { size: 34, bold: true, colour: WHITE })]) +
      textBox(next(), { x: 1, y: 3.7, w: SLIDE_W - 2, h: 0.9 },
        [para([p.client, p.wave].filter(Boolean).join(" · "),
          { size: 15, colour: "D9DCEC" }),
         para(itemCount + " exhibits · built natively inside the Turas report — every table and bar is editable",
          { size: 11.5, colour: "B9BEDC" })]));
  };

  /** Build + download a deck for the story items. */
  exporter.downloadDeck = function (slideXmls, filename) {
    var bytes;
    try {
      bytes = TR.pptx.package(slideXmls, { project: TR.AGG.project });
    } catch (e) {
      if (global.console) console.error("[TurasV2] pptx failed:", e);
      TR.shell.toast("PPTX build failed — see console");
      return;
    }
    var blob = new Blob([bytes], {
      type: "application/vnd.openxmlformats-officedocument.presentationml.presentation" });
    var link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
    TR.shell.toast("Native PowerPoint downloaded — fully editable");
  };

})(typeof window !== "undefined" ? window : globalThis);
