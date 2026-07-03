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
  // esc strips XML-1.0-illegal characters as well as escaping entities (see
  // TR.xlsx.escape) — a stray control char in a verbatim otherwise corrupts
  // the slide part.
  var TR = global.TR, fmt = TR.fmt, S = TR.svg, esc = TR.xlsx.escape;

  var exporter = TR.exporter = {};
  var EMU = 914400, SLIDE_W = 13.333, SLIDE_H = 7.5;
  // WP0: all slide styling flows from TR.pptx.STYLE (14_pptx_parts.js) — the
  // aliases below are the ONLY colour/size sources the slide builders use.
  var STYLE = TR.pptx.STYLE, SIZE = STYLE.SIZE, MARGIN = STYLE.MARGIN;
  var INK = STYLE.INK, GREY = STYLE.GREY, WHITE = STYLE.PAPER, ZEBRA = STYLE.ZEBRA;

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

  /** Generic card SVG: title, meta line, optional chart SVG, optional SVG table
   *  matrix. Backs cardSvg (questions) and the image-deck cards for every other
   *  item kind (exhibit / heatmap / composite / divider). */
  exporter.cardSvgRaw = function (title, metaText, chartSvg, matrix) {
    var W = 1100, PAD = 24, innerW = W - PAD * 2;
    var brand = TR.charts.brandOf();
    var parts = [], y = PAD + 14;
    wrapText(title, 80).forEach(function (line) {
      parts.push(S.text(PAD, y, line, { "font-size": 17, "font-weight": 700, fill: "#1c2333" }));
      y += 22;
    });
    parts.push(S.text(PAD, y, TR.charts.clip(metaText || "", 130),
      { "font-size": 11, fill: "#6b7280" }));
    y += 16;
    if (chartSvg) {
      var vb = chartSvg.match(/viewBox="0 0 ([0-9.]+) ([0-9.]+)"/);
      if (vb) {
        var chartH = parseFloat(vb[2]) / parseFloat(vb[1]) * innerW;
        parts.push(chartSvg.replace('width="100%"',
          'x="' + PAD + '" y="' + y + '" width="' + innerW + '" height="' + chartH + '"'));
        y += chartH + 12;
      }
    }
    if (matrix) {
      var table = svgTable(matrix, PAD, y, innerW, brand);
      parts.push(table.body);
      y += table.height;
    }
    y += PAD;
    var frame = S.el("rect", { x: 0, y: 0, width: W, height: y, fill: "#ffffff" }) +
      S.el("rect", { x: 0, y: 0, width: W, height: 5, fill: brand });
    return S.root(W, y, "card", frame + parts.join(""));
  };

  /** Question card SVG (title, meta, optional chart, optional table). */
  exporter.cardSvg = function (model, note, opts) {
    opts = opts || {};
    var meta = [TR.AGG.project.name, TR.AGG.project.wave,
      model.notRecomputable ? "n/a under filter — not recomputable"
        : model.source === "computed" ? "COMPUTED · filtered audience" : "published values",
      note || ""].filter(Boolean).join(" · ");
    var matrix = opts.includeTable !== false ? TR.render.matrix(model) : null;
    // D2: a pin's stored insight title leads the card when the caller has one
    return exporter.cardSvgRaw(model.code + " — " +
      (opts.title || model.short_label || model.title), meta, opts.chartSvg, matrix);
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
    var labelW = Math.round(width * 0.30);
    var colW = (width - labelW) / Math.max(nCols - 1, 1);
    var rowH = 27, headH = 32;
    var accent = TR.charts.accentOf();
    var parts = [], rowY = y;
    var cellX = function (i) {
      return i === 0 ? x + 12 : x + labelW + (i - 1) * colW + colW / 2;
    };
    parts.push(S.el("rect", { x: x, y: rowY, width: width, height: headH, fill: brand, rx: 4 }));
    matrix.head.forEach(function (h, i) {
      parts.push(S.text(cellX(i), rowY + 21, TR.charts.clip(h, i === 0 ? 42 : 16),
        { "text-anchor": i === 0 ? "start" : "middle", "font-size": 13,
          "font-weight": 700, fill: "#ffffff" }));
    });
    rowY += headH;
    matrix.body.forEach(function (row, r) {
      var stat = row.kind === "stat";
      var fill = stat ? "#f3f4f8" : (r % 2 ? "#fafbfe" : "#ffffff");
      parts.push(S.el("rect", { x: x, y: rowY, width: width, height: rowH, fill: fill }));
      // gold accent edge on stat rows (Index / NPS / NET), mirroring the report
      if (stat) parts.push(S.el("rect", { x: x, y: rowY, width: 4, height: rowH, fill: accent }));
      row.cells.forEach(function (cell, i) {
        parts.push(S.text(cellX(i), rowY + 18, TR.charts.clip(cell, i === 0 ? 46 : 16),
          { "text-anchor": i === 0 ? "start" : "middle", "font-size": 12,
            "font-weight": stat ? 700 : 400,
            "font-style": row.kind === "base" ? "italic" : null,
            fill: row.kind === "base" ? "#6b7280" : "#1c2333" }));
      });
      // wave-change chip (▼0.1) on the Total column, coloured by direction
      if (row.delta && nCols >= 2) {
        parts.push(S.text(cellX(1) + Math.min(colW * 0.30, 30), rowY + 18, row.delta.text,
          { "text-anchor": "start", "font-size": 9.5, "font-weight": 700,
            fill: row.delta.up ? "#1b6e53" : "#b3372f" }));
      }
      rowY += rowH;
    });
    parts.push(S.el("rect", { x: x, y: y, width: width, height: rowY - y,
      fill: "none", stroke: "#d8dcea" }));
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
    if (!text && !o.delta) return "<a:p/>";
    var run = function (t, colour, bold) {
      // optional alpha (percent) — the divider ordinal is 20%-alpha white
      var fill = o.alpha
        ? '<a:srgbClr val="' + colour + '"><a:alpha val="' +
          Math.round(o.alpha * 1000) + '"/></a:srgbClr>'
        : '<a:srgbClr val="' + colour + '"/>';
      return '<a:r><a:rPr lang="en-US" dirty="0" sz="' + Math.round(o.size * 100) + '"' +
        (bold ? ' b="1"' : "") + (o.italic ? ' i="1"' : "") + ">" +
        '<a:solidFill>' + fill + '</a:solidFill>' +
        // explicit latin face: text boxes match the charts (and the theme)
        '<a:latin typeface="' + STYLE.FONT + '"/>' +
        "</a:rPr><a:t>" + esc(t) + "</a:t></a:r>";
    };
    var runs = text ? run(text, o.colour || INK, o.bold) : "";
    // optional wave-change chip as a second coloured run (▼0.1)
    if (o.delta) runs += run("  " + o.delta.text, o.delta.up ? STYLE.GOOD : STYLE.BAD, true);
    return "<a:p><a:pPr" + (o.align ? ' algn="' + o.align + '"' : "") + "/>" + runs + "</a:p>";
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
    // WP2 emphasis model: first charted column in brand, the rest in the
    // muted context greys; value labels only on the emphasis column.
    var seriesHex = function (k) {
      return k === 0 ? TR.charts.brandOf().replace("#", "").toUpperCase()
        : STYLE.CONTEXT[(k - 1) % STYLE.CONTEXT.length];
    };
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
      xml += fillRect(next(), { x: gx, y: box.y, w: 0.008, h: usableH }, STYLE.FAINT);
      xml += textBox(next(), { x: gx - 0.3, y: box.y + usableH + 0.02, w: 0.6, h: 0.2 },
        [para(Math.round(axisMax * f) + "%", { size: SIZE.footer, colour: GREY, align: "ctr" })]);
    });
    rows.forEach(function (r, i) {
      var cy = box.y + i * rowH + rowH / 2;
      var labH = Math.min(rowH - 0.04, 0.5);
      xml += textBox(next(), { x: box.x, y: cy - labH / 2, w: labelW - 0.12, h: labH },
        [para(r.label, { size: SIZE.tableTiny, colour: INK, align: "l" })]);
      xml += fillRect(next(), { x: plotX, y: cy - 0.006, w: plotW, h: 0.012 }, STYLE.FAINT);
      cols.forEach(function (ci, k) {
        var v = r.cells[ci] ? r.cells[ci].pct : null;
        if (v === null || v === undefined) return;
        var frac = Math.max(Math.min(v / axisMax, 1), 0);
        var cx = plotX + frac * plotW;
        var colour = seriesHex(k);
        xml += ellipseShape(next(), { x: cx - dotD / 2, y: cy - dotD / 2, w: dotD, h: dotD }, colour);
        // value label beside the EMPHASIS dot only (bold, brand), like the IPK
        // deck; flips left of the dot near the right edge so it never clips
        if (k !== 0) return;
        var labelLeft = frac > 0.82;
        xml += textBox(next(),
          labelLeft ? { x: cx - dotD / 2 - 0.55, y: cy - 0.11, w: 0.5, h: 0.22 }
                    : { x: cx + dotD / 2 + 0.03, y: cy - 0.11, w: 0.5, h: 0.22 },
          [para(String(Math.round(v)), { size: SIZE.tableTiny, bold: true, colour: colour,
            align: labelLeft ? "r" : "l" })]);
      });
    });
    if (multi) {
      var lx = plotX, ly = box.y + usableH + axisH;
      cols.forEach(function (ci, k) {
        var lbl = model.columns[ci] ? model.columns[ci].label : "?";
        xml += ellipseShape(next(), { x: lx, y: ly + 0.02, w: 0.14, h: 0.14 },
          seriesHex(k));
        var lw = Math.min(2.2, 0.3 + lbl.length * 0.075);
        xml += textBox(next(), { x: lx + 0.2, y: ly - 0.04, w: lw, h: 0.24 },
          [para(lbl, { size: SIZE.tableTiny, colour: INK })]);
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
    // Explicit borders + fills so the formatting survives in PowerPoint, which
    // (unlike LibreOffice) drops cell fills when the table carries no style id —
    // see the "No Style, No Grid" tableStyleId below. Stat rows (Index / NPS /
    // NET) get a gold left edge, mirroring the report's accent rule.
    var BORDER = STYLE.BORDER, line = function (side, w, clr) {
      return '<a:ln' + side + ' w="' + w + '"><a:solidFill><a:srgbClr val="' +
        clr + '"/></a:solidFill></a:ln' + side + ">";
    };
    var cell = function (text, o) {
      return "<a:tc><a:txBody><a:bodyPr/><a:lstStyle/>" + para(text, o) +
        '</a:txBody><a:tcPr marL="27432" marR="27432" marT="9144" marB="9144" anchor="ctr">' +
        (o.accentLeft ? line("L", 28575, STYLE.GOLD) : line("L", 6350, BORDER)) +
        line("R", 6350, BORDER) + line("T", 6350, BORDER) + line("B", 6350, BORDER) +
        '<a:solidFill><a:srgbClr val="' + o.fill + '"/></a:solidFill></a:tcPr></a:tc>';
    };
    var rows = ['<a:tr h="' + rowH + '">' + matrix.head.map(function (h, i) {
      return cell(h, { size: fontSize, bold: true, colour: WHITE, fill: brand,
        align: i === 0 ? "l" : "ctr" });
    }).join("") + "</a:tr>"];
    matrix.body.forEach(function (row, r) {
      var fill = row.kind === "stat" ? ZEBRA : (r % 2 ? STYLE.ROW_ALT : WHITE);
      rows.push('<a:tr h="' + rowH + '">' + row.cells.map(function (text, i) {
        return cell(text, { size: fontSize, bold: row.kind === "stat",
          italic: row.kind === "base", colour: row.kind === "base" ? GREY : INK,
          fill: fill, align: i === 0 ? "l" : "ctr",
          accentLeft: row.kind === "stat" && i === 0,
          delta: (i === 1 && row.delta) ? row.delta : null });
      }).join("") + "</a:tr>");
    });
    return '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="' + id +
      '" name="Table"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>' +
      '<p:xfrm><a:off x="' + inch(box.x) + '" y="' + inch(box.y) + '"/>' +
      '<a:ext cx="' + inch(box.w) + '" cy="' + inch(box.h) + '"/></p:xfrm>' +
      '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">' +
      // "No Style, No Grid" — PowerPoint then applies no theme table style and
      // renders exactly the cell fills/borders above (without a style id it
      // drops them and shows a blank default).
      '<a:tbl><a:tblPr firstRow="1">' +
      '<a:tableStyleId>{2D5ABB26-0587-4C30-8999-92F81FD0307C}</a:tableStyleId>' +
      '</a:tblPr><a:tblGrid>' + grid + "</a:tblGrid>" +
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

  /* ---------------- WP0/WP1 shared slide chrome ---------------- */

  /** Header chrome on every content slide: brand top rule, grey caps kicker,
   *  insight title in ink (brand is emphasis-only), grey subtitle carrying
   *  the question code + full text. spec = {kicker, title, subtitle}. */
  function header(next, spec) {
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var xml = fillRect(next(), STYLE.HEADER.rule, brand);
    if (spec.kicker) {
      xml += textBox(next(), STYLE.HEADER.kicker,
        [para(TR.charts.clip(String(spec.kicker).toUpperCase(), 120),
          { size: SIZE.kicker, bold: true, colour: GREY })]);
    }
    xml += textBox(next(), STYLE.HEADER.title,
      [para(spec.title || "", { size: SIZE.title, bold: true, colour: INK })]);
    if (spec.subtitle) {
      xml += textBox(next(), STYLE.HEADER.subtitle,
        [para(TR.charts.clip(spec.subtitle, 160), { size: SIZE.subtitle, colour: GREY })]);
    }
    return xml;
  }

  /** Base segment of the footer: n= plus weighted Σw / Kish effective n when
   *  the charted column carries them (weighted reports), honouring the same
   *  project display flags as the on-screen base block. "" when no base. */
  function footerBaseText(meta) {
    if (meta.base === null || meta.base === undefined) return "";
    var proj = (TR.AGG && TR.AGG.project) || {};
    var text = "n=" + Math.round(meta.base);
    var extra = [];
    if (meta.baseW !== null && meta.baseW !== undefined &&
        proj.show_weighted_base !== false) {
      extra.push("weighted " + Math.round(meta.baseW));
    }
    if (meta.baseEff !== null && meta.baseEff !== undefined &&
        proj.show_effective_n !== false) {
      extra.push("effective " + Math.round(meta.baseEff));
    }
    return extra.length ? text + " (" + extra.join(" · ") + ")" : text;
  }

  // Plain-language sig-marker note (B2 wording): level derives from the
  // project's configured alpha, never a hard-coded "95%".
  function sigFooterNote() {
    var alpha = (TR.stats && TR.stats.alphaPrimary) ? TR.stats.alphaPrimary() : 0.05;
    return "▲▼ = " + Math.round((1 - alpha) * 100) + "% significance vs prior wave";
  }

  /** Metadata footer on every content slide (B1 contract): left = question
   *  code + full text; mid = base (+ weighted/effective) and the sig note when
   *  the slide carries markers; right = Turas wordmark · wave · page. A pin
   *  that genuinely lacks a field drops that segment, never renders "n=". */
  function footer(next, meta) {
    meta = meta || {};
    var xml = fillRect(next(), STYLE.FOOTER.rule, STYLE.FAINT);
    var left = [meta.qcode, meta.qtext].filter(Boolean).join(" · ");
    if (left) {
      xml += textBox(next(), STYLE.FOOTER.left,
        [para(TR.charts.clip(left, 110), { size: SIZE.footer, colour: GREY })]);
    }
    var mid = [footerBaseText(meta)].concat(meta.notes || []);
    if (meta.sig) mid.push(sigFooterNote());
    mid = mid.filter(Boolean).join(" · ");
    if (mid) {
      xml += textBox(next(), STYLE.FOOTER.mid,
        [para(TR.charts.clip(mid, 95), { size: SIZE.footer, colour: GREY })]);
    }
    xml += textBox(next(), STYLE.FOOTER.right,
      [para(["Turas", TR.AGG.project.wave].filter(Boolean).join(" · ") +
        " · " + TR.pptx.PAGE_TOKEN + "/" + TR.pptx.PAGE_TOTAL_TOKEN,
        { size: SIZE.footer, colour: GREY, align: "r" })]);
    return xml;
  }

  /** Gold analyst-insight callout band pinned to the body's bottom. */
  function callout(next, noteLines, noteH) {
    var noteY = STYLE.BODY.y + STYLE.BODY.h - noteH;
    return rectShape(next(), { x: MARGIN, y: noteY, w: STYLE.BODY.w, h: noteH },
        STYLE.CALLOUT_BG) +
      rectShape(next(), { x: MARGIN, y: noteY, w: 0.05, h: noteH }, STYLE.GOLD) +
      textBox(next(), { x: MARGIN + 0.2, y: noteY + 0.08, w: STYLE.BODY.w - 0.4,
        h: noteH - 0.12 },
        [para("ANALYST INSIGHT", { size: SIZE.footer, bold: true, colour: STYLE.GOLD })]
          .concat(noteLines.map(function (line) {
            return para(line, { size: SIZE.body, colour: INK });
          })));
  }

  /** Resolve the footer page tokens once the deck length is known.
   *  Mutates + returns `slides`; safe on plain-XML and rich slides. */
  exporter.paginate = function (slides) {
    var total = String(slides.length);
    var fix = function (xml, i) {
      return xml.split(TR.pptx.PAGE_TOKEN).join(String(i + 1))
        .split(TR.pptx.PAGE_TOTAL_TOKEN).join(total);
    };
    slides.forEach(function (s, i) {
      if (typeof s === "string") slides[i] = fix(s, i);
      else if (s && typeof s.xml === "string") s.xml = fix(s.xml, i);
    });
    return slides;
  };

  function wrapSlide(content) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
      '<p:sld xmlns:a="' + TR.pptx.NS.a + '" xmlns:r="' + TR.pptx.NS.r +
      '" xmlns:p="' + TR.pptx.NS.p + '"><p:cSld><p:spTree>' +
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>' +
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>' +
      '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>' +
      content + "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>";
  }

  /**
   * Slide that is a single full-bleed PNG image (the pixel-perfect card render),
   * fitted to the slide preserving aspect ratio. png = {bytes, w, h} (raster
   * pixels). Pairs with TR.pptx.package's image-media support.
   */
  exporter.imageSlide = function (png) {
    var availW = SLIDE_W - MARGIN * 2, availH = SLIDE_H - MARGIN * 2;
    var ar = (png.w && png.h) ? png.w / png.h : availW / availH;
    var w = availW, h = availW / ar;
    if (h > availH) { h = availH; w = availH * ar; }
    var x = (SLIDE_W - w) / 2, y = (SLIDE_H - h) / 2;
    var pic = '<p:pic><p:nvPicPr><p:cNvPr id="2" name="Card"/>' +
      '<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>' +
      '<p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>' +
      '<p:spPr><a:xfrm><a:off x="' + inch(x) + '" y="' + inch(y) + '"/>' +
      '<a:ext cx="' + inch(w) + '" cy="' + inch(h) + '"/></a:xfrm>' +
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>';
    return { xml: wrapSlide(pic), charts: [], images: [{ bytes: png.bytes }] };
  };

  /* ---------- NATIVE PowerPoint chart objects ----------
     A real c:chartSpace part + an embedded Excel workbook, so the chart is
     a genuine chart object: change its type in PowerPoint, restyle it, and
     "Edit Data" opens the data in Excel. Honours the report's selected
     chart type, row kind and columns. */

  var C_NS = 'xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" ' +
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" ' +
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

  function chartAxes(catPos, valPos, fmtCode, hideVal, valMin, valMax) {
    return '<c:catAx><c:axId val="111111111"/><c:scaling>' +
      '<c:orientation val="minMax"/></c:scaling><c:delete val="0"/>' +
      '<c:axPos val="' + catPos + '"/>' +
      // 0.75pt FAINT category axis line — the only chart rule (no gridlines)
      '<c:spPr><a:ln w="9525"><a:solidFill><a:srgbClr val="' + STYLE.FAINT +
      '"/></a:solidFill></a:ln></c:spPr>' +
      '<c:crossAx val="222222222"/></c:catAx>' +
      '<c:valAx><c:axId val="222222222"/><c:scaling>' +
      '<c:orientation val="minMax"/>' +
      // Fixed scale (e.g. 0-10 for means) so the PPTX matches the pin and small
      // movements aren't exaggerated by auto-scaling.
      (valMax != null ? '<c:max val="' + valMax + '"/>' : "") +
      (valMin != null ? '<c:min val="' + valMin + '"/>' : "") +
      '</c:scaling><c:delete val="' +
      (hideVal ? "1" : "0") + '"/>' +
      '<c:axPos val="' + valPos + '"/>' +
      '<c:numFmt formatCode="' + (fmtCode || "0&quot;%&quot;") +
      '" sourceLinked="0"/>' +
      '<c:crossAx val="111111111"/></c:valAx>';
  }

  /** Value data labels (the "48%" on each bar/segment). pos = "outEnd" for
   *  clustered bar/column, "ctr" for percent-stacked. colour is the label ink
   *  (dark outside a bar, white centred on a coloured segment). */
  function dataLabels(pos, colour, fmtCode) {
    return '<c:dLbls><c:numFmt formatCode="' + (fmtCode || "0&quot;%&quot;") +
      '" sourceLinked="0"/>' +
      '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>' +
      '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1000" b="1">' +
      '<a:solidFill><a:srgbClr val="' + (colour || STYLE.INK) + '"/></a:solidFill>' +
      '<a:latin typeface="' + STYLE.FONT + '"/></a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>' +
      '<c:dLblPos val="' + pos + '"/>' +
      '<c:showLegendKey val="0"/><c:showVal val="1"/><c:showCatName val="0"/>' +
      '<c:showSerName val="0"/><c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>';
  }

  /** Embedded-workbook column letter for 0-based series index k: series 0
   *  lives in column B (A holds the category labels). Base-26 A..Z,AA..
   *  (mirrors banner.R's generate_excel_letters) so a 26th series makes a
   *  valid Sheet1!$AA$… reference, not Sheet1!$[$…. */
  function seriesLetter(k) {
    var n = k + 2, s = "";
    while (n > 0) {
      s = String.fromCharCode(65 + (n - 1) % 26) + s;
      n = Math.floor((n - 1) / 26);
    }
    return s;
  }
  exporter._seriesLetter = seriesLetter;   // exposed for the export tests

  /** WP2 emphasis colour for series k: the first charted column carries the
   *  project brand colour; every other series is a muted context grey. */
  function emphasisHex(k) {
    return k === 0 ? TR.charts.brandOf().replace("#", "").toUpperCase()
      : STYLE.CONTEXT[(k - 1) % STYLE.CONTEXT.length];
  }

  /** True when every charted row label is an exact sentiment term — the only
   *  case a single-series bar keeps the semantic red/green palette (colour IS
   *  the meaning, e.g. Detractor/Passive/Promoter). semanticColour() answers
   *  index-independently ONLY on an exact map hit; the ordinal gradient for
   *  unmapped labels shifts with position, so this needs no map duplicate. */
  function sentimentRows(rows) {
    return rows.length > 0 && rows.every(function (r) {
      var a = TR.charts.semanticColour(r.label, 0, 3);
      return !!a && a === TR.charts.semanticColour(r.label, 2, 3);
    });
  }

  /** The headline row of a single-series chart — the top NET when NETs are
   *  charted, else the max value: the one bar rendered in brand. */
  function headlineIndex(rows, ci) {
    var pool = rows.some(function (r) { return r.kind === "net"; })
      ? rows.filter(function (r) { return r.kind === "net"; }) : rows;
    var best = null, bestV = -Infinity;
    pool.forEach(function (r) {
      var v = r.cells[ci] ? r.cells[ci].pct : null;
      if (v !== null && v !== undefined && v > bestV) { bestV = v; best = r; }
    });
    return best ? rows.indexOf(best) : 0;
  }

  function chartSeries(model, rows, cols, type, lbl) {
    // Pie keeps the semantic category palette (slices are categories). A
    // single-series bar/column keeps it ONLY when the categories are sentiment
    // terms (colour is meaning, flagged in the slide footer); otherwise all
    // bars go context grey with the headline row in brand. Multi-series charts
    // use the emphasis model: series 0 brand, the rest muted greys.
    var catCol = null;
    var single = cols.length === 1 && type !== "dot";
    var sentiment = false;
    if (type === "pie") {
      catCol = TR.render.categoryColours(rows);
    } else if (single) {
      sentiment = sentimentRows(rows);
      if (sentiment) {
        catCol = TR.render.categoryColours(rows);
      } else {
        var hIdx = headlineIndex(rows, cols[0]);
        catCol = rows.map(function (_, i) {
          return i === hIdx ? emphasisHex(0) : STYLE.CONTEXT[0];
        });
      }
    }
    chartSeries._sentiment = sentiment;   // read by buildChart for the footer flag
    var catPts = rows.map(function (r, i) {
      return '<c:pt idx="' + i + '"><c:v>' + esc(r.label) + "</c:v></c:pt>";
    }).join("");
    var catRef = '<c:cat><c:strRef><c:f>Sheet1!$A$2:$A$' + (rows.length + 1) +
      '</c:f><c:strCache><c:ptCount val="' + rows.length + '"/>' + catPts +
      "</c:strCache></c:strRef></c:cat>";
    return cols.map(function (ci, k) {
      var col = model.columns[ci];
      var colour = emphasisHex(k);
      var letter = seriesLetter(k);
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
      // WP2: data labels are per-series and only the emphasis series gets them
      var serLbls = (lbl && k === 0) ? dataLabels(lbl.pos, lbl.colour, lbl.fmt) : "";
      return '<c:ser><c:idx val="' + k + '"/><c:order val="' + k + '"/>' +
        '<c:tx><c:strRef><c:f>Sheet1!$' + letter + '$1</c:f><c:strCache>' +
        '<c:ptCount val="1"/><c:pt idx="0"><c:v>' + esc(col ? col.label : "Series") +
        "</c:v></c:pt></c:strCache></c:strRef></c:tx>" +
        lineStyle + dPts + serLbls + catRef +
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
      var letter = seriesLetter(k);
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

  /** Declared scale bounds for honest mean axes: the model's own fields when
   *  the pin carried them, else the source question's Scale_Min/Scale_Max
   *  (guarded — export sandboxes and stale pins have no TR.d2 / question).
   *  null when nothing is declared (data-driven fixed max stands). */
  function scaleOf(model) {
    var min = model.scale_min, max = model.scale_max;
    if (max === null || max === undefined) {
      var q = (TR.d2 && TR.d2.questionByCode) ? TR.d2.questionByCode(model.code) : null;
      if (q && q.scale_max !== null && q.scale_max !== undefined) {
        min = q.scale_min; max = q.scale_max;
      }
    }
    if (max === null || max === undefined) return null;
    return { min: (min === null || min === undefined) ? 0 : min, max: max };
  }

  /**
   * Build a native chart for a model: {xml, workbook, sentiment} ready for
   * the packager, honouring chart type, row kind (detail/NETs) and columns.
   * `sentiment` flags semantic red/green category colouring (single-series
   * sentiment scales only) so the slide footer can name it.
   */
  exporter.buildChart = function (model, type, cols) {
    // A question pinned on the trend-over-waves chart ("line") exports the
    // wave-history line chart, matching the screen — a bar of current-wave
    // values would silently drop the tracking story. Only a model with no
    // wave history at all falls through to the bar chart.
    if (type === "line") {
      var trend = exporter.buildTrendChart(model);
      if (trend) return trend;
      type = "bar";
    }
    // A mean ("Index") plot renders as a clustered bar/column with each charted
    // column as its own labelled bar — mirrors the on-screen chart (coerce a
    // percentage type to bar, then transpose columns -> labelled bars).
    if (model.valueKind === "mean" && type !== "column" && type !== "bar") type = "bar";
    // capture the declared scale BEFORE the mean transpose rebuilds the model
    // (asMeanByColumn's synthetic model carries no scale_min/scale_max)
    var declaredScale = scaleOf(model);
    var mb = TR.render.asMeanByColumn(model, cols); model = mb.model; cols = mb.cols;
    var cr = TR.render.chartRows(model);
    var rows = cr.rows;
    if (!rows.length || !cols.length) return null;
    if (type === "pie") cols = [cols[0]];
    // A composite of 0–10 means charts RATINGS: one-decimal labels on a fixed
    // 0–max axis, not the default "0%" percentage format.
    var meanScale = model.valueKind === "mean";
    var lblFmt = meanScale ? "0.0" : null;
    // Honest axes (WP2): means run over the question's declared scale when the
    // source carries Scale_Min/Scale_Max, else the data-driven fixed max as
    // before; percent axes anchor at 0 with niceMax capped at 100 and floored
    // at 25, so auto-scaling can never inflate a small difference.
    var sc = meanScale ? declaredScale : null;
    var meanMin = sc ? sc.min : 0;
    var meanMax = sc ? sc.max : cr.axisMax;
    var pctMax = Math.max(25, Math.min(100, cr.axisMax || 100));
    var series = (type === "stacked" || type === "stackedcol")
      ? chartSeriesStacked(model, rows, cols)
      : chartSeries(model, rows, cols, type,
          type === "pie" ? null
            : { pos: type === "dot" ? "t" : "outEnd", colour: null, fmt: lblFmt });
    var sentiment = type !== "pie" && !!chartSeries._sentiment;
    var plot, axesXml = "";
    if (type === "column") {
      plot = '<c:barChart><c:barDir val="col"/><c:grouping val="clustered"/>' +
        '<c:varyColors val="0"/>' + series +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>';
      axesXml = chartAxes("b", "l", meanScale ? "General" : null, false,
        meanScale ? meanMin : 0, meanScale ? meanMax : pctMax);
    } else if (type === "stacked") {
      plot = '<c:barChart><c:barDir val="bar"/><c:grouping val="percentStacked"/>' +
        '<c:varyColors val="0"/>' + series + dataLabels("ctr", "FFFFFF") +
        '<c:overlap val="100"/>' +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>';
      // Percent-stacked normalises to fractions, so the literal-% value axis is
      // meaningless (and the pin shows none) — hide it; the segment labels carry
      // the %s.
      axesXml = chartAxes("l", "b", null, true);
    } else if (type === "stackedcol") {
      // Vertical twin of stacked: percent-stacked COLUMNS (barDir col), category
      // axis on the bottom and the normalised value axis on the left, hidden.
      plot = '<c:barChart><c:barDir val="col"/><c:grouping val="percentStacked"/>' +
        '<c:varyColors val="0"/>' + series + dataLabels("ctr", "FFFFFF") +
        '<c:overlap val="100"/>' +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>';
      axesXml = chartAxes("b", "l", null, true);
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
      axesXml = chartAxes("b", "l", null, false, 0, pctMax);
    } else {
      // horizontal bar: a mean plot labels one-decimal ratings on a fixed
      // scale-min–max value axis (mirrors the column branch), not "0%".
      plot = '<c:barChart><c:barDir val="bar"/><c:grouping val="clustered"/>' +
        '<c:varyColors val="0"/>' + series +
        '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>';
      axesXml = chartAxes("l", "b", meanScale ? "General" : null, false,
        meanScale ? meanMin : 0, meanScale ? meanMax : pctMax);
    }
    var xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
      "<c:chartSpace " + C_NS + "><c:chart><c:plotArea><c:layout/>" +
      plot + axesXml + "</c:plotArea>" +
      ((cols.length > 1 || type === "pie" || type === "stacked" || type === "stackedcol")
        ? '<c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend>' : "") +
      '<c:plotVisOnly val="1"/></c:chart>' +
      // Default chart font — clean Arial in the report ink so axis/legend text
      // matches the on-screen look.
      '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1000">' +
      '<a:solidFill><a:srgbClr val="' + STYLE.CHART_INK + '"/></a:solidFill>' +
      '<a:latin typeface="' + STYLE.FONT + '"/></a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>' +
      '<c:externalData r:id="rId1"><c:autoUpdate val="0"/></c:externalData></c:chartSpace>';
    // Embedded workbook must mirror the series layout so "Edit Data" resolves:
    // stacked is transposed (columns down col A, one segment-series per column).
    var num = function (v) {
      return v === null || v === undefined ? "" : Math.round(v * 10) / 10;
    };
    var workbookRows = (type === "stacked" || type === "stackedcol")
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
    return { xml: xml, workbook: TR.xlsx.bytes("Sheet1", workbookRows),
      sentiment: sentiment };
  };

  /**
   * Native line chart over wave years for the trended rows of a model
   * (real or pseudo): one series per row with history, categories = the
   * union of years incl. the current wave. {xml, workbook} or null.
   */
  exporter.buildTrendChart = function (model) {
    var all = TR.render.trendRows(model);
    if (!all.length) return null;
    // Mean-scale (0-10) rows and percentage/index rows never share an axis —
    // the dominant group wins, the rest are dropped with a note. Mirrors
    // render.trendChart exactly so the export matches the pinned view.
    var small = all.filter(function (r) {
      return r.kind === "mean" && Math.max.apply(null, r.waves.map(function (w) {
        return w.value;
      })) <= 10;
    });
    var pct = all.filter(function (r) { return small.indexOf(r) === -1; });
    var meanScale = small.length > pct.length;
    var rows = (meanScale ? small : pct).slice(0, 6);
    if (!rows.length) return null;
    var dropped = all.length - rows.length;
    var years = [];
    rows.forEach(function (r) {
      TR.render.wavePoints(r).forEach(function (p) {
        if (p.year !== null && years.indexOf(p.year) === -1) years.push(p.year);
      });
    });
    TR.render.waveKeySort(years);
    var pointsOf = function (r) {
      var byYear = {};
      TR.render.wavePoints(r).forEach(function (p) { byYear[p.year] = p.value; });
      return years.map(function (y) {
        return byYear[y] === undefined ? null : Math.round(byYear[y] * 10) / 10;
      });
    };
    // Wave label ("Wave 22 - Oct 2024"), not the raw year key, to match the pin.
    var wl = function (y) {
      return (TR.trk && TR.trk.yLabel) ? TR.trk.yLabel(y) : String(y);
    };
    var catPts = years.map(function (y, i) {
      return '<c:pt idx="' + i + '"><c:v>' + esc(wl(y)) + "</c:v></c:pt>";
    }).join("");
    var catRef = '<c:cat><c:strRef><c:f>Sheet1!$A$2:$A$' + (years.length + 1) +
      '</c:f><c:strCache><c:ptCount val="' + years.length + '"/>' + catPts +
      "</c:strCache></c:strRef></c:cat>";
    var series = rows.map(function (r, k) {
      // WP2 emphasis model: the first (headline) series in brand, context
      // series in muted greys; value labels on the emphasis series only.
      var colour = emphasisHex(k);
      var letter = seriesLetter(k);
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
        (k === 0 ? dataLabels("t", colour, meanScale ? "0.0" : null) : "") +
        catRef +
        '<c:val><c:numRef><c:f>Sheet1!$' + letter + "$2:$" + letter + "$" +
        (years.length + 1) + '</c:f><c:numCache><c:formatCode>General</c:formatCode>' +
        '<c:ptCount val="' + years.length + '"/>' + valPts +
        "</c:numCache></c:numRef></c:val></c:ser>";
    }).join("");
    var pctOnly = rows.every(function (r) { return r.kind !== "mean"; });
    // Fixed value axis matching the pin: 0 (or the negative floor for NPS) to a
    // nice max, with means anchored to at least 10 — so auto-scaling never
    // exaggerates a small wave-on-wave move. meanScale comes from the scale
    // split above, exactly as on screen.
    var lo = 0, hi = 0;
    rows.forEach(function (r) {
      TR.render.wavePoints(r).forEach(function (p) {
        if (p.value === null || p.value === undefined) return;
        if (p.value < lo) lo = p.value;
        if (p.value > hi) hi = p.value;
      });
    });
    var axisMax = meanScale ? Math.max(S.niceMax(hi), 10) : S.niceMax(hi);
    var axisMin = lo < 0 ? -S.niceMax(-lo) : 0;
    if (axisMax <= axisMin) axisMax = axisMin + 1;
    var xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
      "<c:chartSpace " + C_NS + "><c:chart><c:plotArea><c:layout/>" +
      '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>' +
      series + '<c:marker val="1"/>' +
      '<c:axId val="111111111"/><c:axId val="222222222"/></c:lineChart>' +
      chartAxes("b", "l", pctOnly ? null : "General", false, axisMin, axisMax) +
      "</c:plotArea>" +
      (rows.length > 1
        ? '<c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend>' : "") +
      '<c:plotVisOnly val="1"/></c:chart>' +
      // Default chart font — clean Arial in the report ink so axis/legend text
      // matches the on-screen look.
      '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1000">' +
      '<a:solidFill><a:srgbClr val="' + STYLE.CHART_INK + '"/></a:solidFill>' +
      '<a:latin typeface="' + STYLE.FONT + '"/></a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>' +
      '<c:externalData r:id="rId1"><c:autoUpdate val="0"/></c:externalData></c:chartSpace>';
    var workbookRows = [[""].concat(rows.map(function (r) { return r.label; }))]
      .concat(years.map(function (y, i) {
        return [wl(y)].concat(rows.map(function (r) {
          var v = pointsOf(r)[i];
          return v === null ? "" : v;
        }));
      }));
    // sheet name must match the Sheet1!… formula refs (see buildChart)
    return { xml: xml, workbook: TR.xlsx.bytes("Sheet1", workbookRows),
      note: dropped > 0
        ? dropped + " series hidden (mixed scales or >6)" : "" };
  };

  /**
   * Exhibit slide: stacked native chart objects (each its own editable
   * chart, rels rId2..rId(1+n)) + optional table + insight band, on the
   * shared header/body/footer grid.
   * @param {object} spec - {title, meta, charts, matrix, note, kicker,
   *   footer, chip} — kicker defaults to TRACKING; footer fields (qcode,
   *   qtext, base…) are optional and omitted segments drop gracefully;
   *   chip = {text, up} draws the wave-delta chip (WP5) top-right of BODY
   *   on the callout chrome (CALLOUT_BG + GOOD/BAD edge).
   */
  exporter.exhibitSlide = function (spec) {
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    var hasNote = !!(spec.note && spec.note.trim());
    var noteLines = hasNote ? wrapText(spec.note, 150).slice(0, 3) : [];
    var noteH = hasNote ? 0.45 + noteLines.length * 0.24 : 0;
    var content = header(next, { kicker: spec.kicker || "Tracking",
      title: spec.title, subtitle: spec.meta || "" });
    var top = STYLE.BODY.y;
    var bottom = STYLE.BODY.y + STYLE.BODY.h - (hasNote ? noteH + 0.12 : 0);
    var charts = spec.charts || [];
    var blocks = charts.length + (spec.matrix ? 1 : 0);
    var blockH = blocks ? (bottom - top - (blocks - 1) * 0.2) / blocks : 0;
    charts.forEach(function (_, k) {
      content += chartFrame(next(),
        { x: MARGIN, y: top, w: STYLE.BODY.w, h: blockH }, "rId" + (2 + k));
      top += blockH + 0.2;
    });
    if (spec.matrix) {
      var matrix = fitMatrix(spec.matrix,
        Math.max(3, Math.floor(blockH / 0.28) - 1));
      content += tableFrame(next(), { x: MARGIN, y: top, w: STYLE.BODY.w,
        h: Math.min(blockH, (matrix.body.length + 1) * 0.28) }, matrix, brand,
        matrix.head.length > 8 ? SIZE.tableSmall : SIZE.table);
    }
    // WP5 wave-delta chip: ▲ +4pp • top-right of BODY, on the callout chrome
    // (drawn after the charts so it sits above the chart frame)
    if (spec.chip && spec.chip.text) {
      var chipC = spec.chip.up === false ? STYLE.BAD : STYLE.GOOD;
      var chipBox = { x: MARGIN + STYLE.BODY.w - 1.9, y: STYLE.BODY.y + 0.06,
        w: 1.9, h: 0.36 };
      content += rectShape(next(), chipBox, STYLE.CALLOUT_BG) +
        fillRect(next(), { x: chipBox.x, y: chipBox.y, w: 0.05, h: chipBox.h }, chipC) +
        textBox(next(), { x: chipBox.x + 0.12, y: chipBox.y + 0.04,
          w: chipBox.w - 0.2, h: 0.28 },
          [para(spec.chip.text, { size: SIZE.kicker, bold: true, colour: chipC,
            align: "ctr" })]);
    }
    if (hasNote) content += callout(next, noteLines, noteH);
    content += footer(next, spec.footer || {});
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
   * WP2 sig markers: ▲/▼ beside the emphasis values whose wave delta the
   * model marks significant. A native chart's internals aren't addressable
   * from the slide, so the markers are positioned text boxes on the chart
   * frame's category slots (same technique as dotPlotShapes value labels) —
   * approximate but honest. Wave deltas exist on the Total column only, so a
   * non-Total emphasis, a transposed mean plot or a non-bar/column type gets
   * no markers (the tables keep the letters).
   */
  function sigMarkerShapes(next, box, model, type, cols) {
    var out = { xml: "", any: false };
    if ((cols[0] || 0) !== 0) return out;
    if (type !== "bar" && type !== "column") return out;
    if (model.valueKind === "mean") return out;   // asMeanByColumn transposes rows
    var rows = TR.render.chartRows(model).rows;
    var n = rows.length;
    if (!n) return out;
    // approximate the plot area inside the chart frame: the value-axis label
    // strip (~0.3") and, with a legend (multi-series), the legend strip
    // (~0.35") sit at the frame's bottom
    var inset = 0.30 + (cols.length > 1 ? 0.35 : 0);
    var plotH = Math.max(box.h - inset, 0.5);
    var xml = "";
    rows.forEach(function (r, i) {
      if (!r.delta || !r.delta.sig || !r.delta.diff) return;
      var up = r.delta.diff > 0;
      var at = type === "bar"
        // minMax bar categories plot bottom-up: row i sits n-1-i slots from the top
        ? { x: box.x + box.w - 0.32, y: box.y + plotH - (i + 0.5) * (plotH / n) - 0.1,
            w: 0.28, h: 0.2 }
        : { x: box.x + (i + 0.5) * (box.w / n) - 0.14, y: box.y + 0.02,
            w: 0.28, h: 0.2 };
      xml += textBox(next(), at,
        [para(up ? "▲" : "▼", { size: SIZE.footer, bold: true,
          colour: up ? STYLE.GOOD : STYLE.BAD, align: "ctr" })]);
      out.any = true;
    });
    out.xml = xml;
    return out;
  }

  /**
   * Slide for one story item: chart = a NATIVE chart object honouring the
   * pinned type/rows/columns (editable in PowerPoint, data in Excel);
   * table = native a:tbl; insight = the gold callout band at the body's
   * bottom; metadata footer on the shared grid.
   * @returns {{xml: string, charts: Array}} rich slide for the packager.
   */
  exporter.slideForModel = function (model, commentary, flags) {
    flags = flags || { chart: false, table: true, insight: true };
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    var hasNote = !!(flags.insight && commentary && commentary.trim());
    var noteLines = hasNote ? wrapText(commentary, 150).slice(0, 3) : [];
    var noteH = hasNote ? 0.45 + noteLines.length * 0.24 : 0;
    var charts = [];
    // D2: a pin's stored insight title leads the slide when the caller has
    // one; the question code moves to the subtitle + footer (B1)
    var content = header(next, {
      kicker: [model.category,
        model.source === "computed" ? "filtered audience (live recompute)" : "published values",
        model.filterNote || ""].filter(Boolean).join(" · "),
      title: flags.title || model.short_label || model.title,
      subtitle: model.code + " · " + model.title });
    var top = STYLE.BODY.y;
    var bottom = STYLE.BODY.y + STYLE.BODY.h - (hasNote ? noteH + 0.12 : 0);
    var sigMarks = false, footNotes = [];
    if (flags.chart) {
      var dcols = (flags.chartCols && flags.chartCols.length) ? flags.chartCols : [0];
      var chartH = flags.table ? Math.min(2.9, bottom - top - 1.4) : bottom - top;
      if ((flags.chartType || "bar") === "dot") {
        // A horizontal dot plot has no native PowerPoint chart type — draw it
        // as shapes (matches the on-screen pin; no chart part for this slide).
        content += dotPlotShapes(next, { x: MARGIN, y: top, w: STYLE.BODY.w, h: chartH },
          model, dcols);
        top += chartH + 0.2;
      } else {
        var chart = exporter.buildChart(model, flags.chartType || "bar", dcols);
        if (chart) {
          charts.push(chart);
          // the trend chart's mixed-scale note ("N series hidden …") renders
          // as a strip under the chart, mirroring the on-screen footnote
          var chartNoteH = chart.note ? 0.22 : 0;
          var chartBox = { x: MARGIN, y: top, w: STYLE.BODY.w, h: chartH - chartNoteH };
          content += chartFrame(next(), chartBox, "rId2");
          var marks = sigMarkerShapes(next, chartBox, model,
            flags.chartType || "bar", dcols);
          content += marks.xml;
          sigMarks = marks.any;
          if (chart.sentiment) footNotes.push("bar colours mark sentiment");
          if (chart.note) {
            content += textBox(next(),
              { x: MARGIN, y: top + chartH - chartNoteH, w: STYLE.BODY.w, h: chartNoteH },
              [para(chart.note, { size: SIZE.footer, colour: GREY })]);
          }
          top += chartH + 0.2;
        }
      }
    }
    if (flags.table) {
      var matrix = fitMatrix(TR.render.matrix(model),
        Math.max(4, Math.floor((bottom - top) / 0.3) - 1));
      content += tableFrame(next(), { x: MARGIN, y: top, w: STYLE.BODY.w,
        h: Math.min(bottom - top, (matrix.body.length + 1) * 0.3) }, matrix, brand,
        matrix.head.length > 7 ? SIZE.tableTiny : SIZE.tableSmall);
    }
    if (hasNote) content += callout(next, noteLines, noteH);
    // B1 metadata footer: bases come from the charted (emphasis) column
    if (flags.intervals && TR.conf) {
      footNotes.push(TR.conf.methodNote(TR.conf.modelIntervalKind(model)));
    }
    var fcol = model.columns[(flags.chartCols && flags.chartCols.length)
      ? flags.chartCols[0] : 0] || model.columns[0];
    content += footer(next, { qcode: model.code, qtext: model.title,
      base: fcol ? fcol.base : null,
      baseW: fcol ? fcol.baseW : null,
      baseEff: fcol ? fcol.baseEff : null,
      sig: sigMarks, notes: footNotes });
    return { xml: wrapSlide(content), charts: charts };
  };

  /** Section divider slide (story dividers). opts.num draws the big section
   *  ordinal ("02") at 20%-alpha white top-right (WP3); omitted = unnumbered
   *  (back-compat + placeholder slides). */
  exporter.dividerSlide = function (title, subtitle, opts) {
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    var ordinal = (opts && opts.num)
      ? textBox(next(), { x: SLIDE_W - 3.3, y: 0.3, w: 2.7, h: 1.15 },
          [para((opts.num < 10 ? "0" : "") + opts.num,
            { size: SIZE.ordinal, bold: true, colour: WHITE, alpha: 20, align: "r" })])
      : "";
    return wrapSlide(
      // full-bleed background is a SHARP rect: roundRect here leaves white
      // notched corners on the rendered slide (WP6 visual QA finding)
      fillRect(next(), { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H }, brand) +
      ordinal +
      rectShape(next(), { x: MARGIN, y: 3.55, w: 1.4, h: 0.05 }, STYLE.GOLD) +
      textBox(next(), { x: MARGIN, y: 2.7, w: SLIDE_W - MARGIN * 2, h: 0.9 },
        [para(title, { size: SIZE.divider, bold: true, colour: WHITE })]) +
      textBox(next(), { x: MARGIN, y: 3.75, w: SLIDE_W - MARGIN * 2, h: 0.5 },
        [para(subtitle || "", { size: SIZE.lead, colour: STYLE.ON_BRAND_MUTED })]));
  };

  /** Sentiment names for the quote-slide chip line — the marker colour is
   *  never colour-only (spec archetype 5): the chip says the word. */
  var SENT_WORD = { pos: "Positive", neg: "Negative", neu: "Mixed" };

  /**
   * Verbatim/quote slide (WP4): up to 4 quotes in quote typography — gold
   * opening-quote glyph, italic ink quote on a 9.5" measure, grey attribution
   * chip line (question · demo tags · sentiment word) and a sentiment edge
   * rect — never a one-column table. spec = {title, meta, kicker, quotes:
   * [{text, q, tags, sentiment}], moreN, note}. Quotes arrive ALREADY
   * disclosure-gated (hidden text was never put in the payload; below-k tags
   * were dropped at pin time) — this renders, it never re-derives.
   */
  exporter.quoteSlide = function (spec) {
    var id = 1;
    var next = function () { return ++id; };
    var hasNote = !!(spec.note && spec.note.trim());
    var noteLines = hasNote ? wrapText(spec.note, 150).slice(0, 3) : [];
    var noteH = hasNote ? 0.45 + noteLines.length * 0.24 : 0;
    var content = header(next, { kicker: spec.kicker || "Verbatims",
      title: spec.title, subtitle: spec.meta || "" });
    var all = spec.quotes || [];
    var quotes = all.slice(0, 4);
    var moreN = (spec.moreN || 0) + (all.length - quotes.length);
    var top = STYLE.BODY.y;
    var bottom = STYLE.BODY.y + STYLE.BODY.h - (hasNote ? noteH + 0.12 : 0);
    var blockH = quotes.length ? (bottom - top) / quotes.length : 0;
    quotes.forEach(function (qt, i) {
      var y = top + i * blockH;
      var sentC = qt.sentiment === "pos" ? STYLE.GOOD
        : qt.sentiment === "neg" ? STYLE.BAD : GREY;
      // sentiment edge — colour is reinforced by the chip's sentiment word
      content += fillRect(next(), { x: MARGIN, y: y + 0.06, w: 0.05,
        h: Math.max(blockH - 0.18, 0.2) }, sentC);
      content += textBox(next(), { x: MARGIN + 0.18, y: y - 0.04, w: 0.75, h: 0.7 },
        [para("“", { size: SIZE.quoteGlyph, bold: true, colour: STYLE.GOLD })]);
      content += textBox(next(), { x: MARGIN + 1.0, y: y + 0.06, w: 9.5,
        h: Math.max(blockH - 0.42, 0.3) },
        [para(TR.charts.clip(String(qt.text || ""), 300),
          { size: SIZE.quote, italic: true, colour: INK })]);
      var chip = [qt.q].concat(qt.tags || [])
        .concat([SENT_WORD[qt.sentiment] || null]).filter(Boolean).join(" · ");
      content += textBox(next(), { x: MARGIN + 1.0, y: y + blockH - 0.34,
        w: 9.5, h: 0.26 },
        [para(TR.charts.clip(chip, 120), { size: SIZE.chip, colour: GREY })]);
    });
    if (hasNote) content += callout(next, noteLines, noteH);
    content += footer(next,
      { qtext: moreN > 0 ? "+" + moreN + " more in the report" : null });
    return { xml: wrapSlide(content), charts: [] };
  };

  /** Generic title + native table slide (heatmaps, composites, snapshots) on
   *  the shared grid. opts = {kicker, footer} — both optional. */
  exporter.matrixSlide = function (title, metaLine, matrix, opts) {
    opts = opts || {};
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    matrix = fitMatrix(matrix, 15);
    return wrapSlide(
      header(next, { kicker: opts.kicker || "", title: title,
        subtitle: metaLine || "" }) +
      tableFrame(next(), { x: MARGIN, y: STYLE.BODY.y, w: STYLE.BODY.w,
        h: Math.min(STYLE.BODY.h, (matrix.body.length + 1) * 0.32) }, matrix, brand,
        matrix.head.length > 8 ? SIZE.tableSmall : SIZE.table) +
      footer(next, opts.footer || {}));
  };

  var MONTHS = ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December"];

  /**
   * Exec-summary cover (WP3): white page, brand rule down the left edge,
   * REPORT kicker, project name, client · wave · date, the authored exec
   * summary (first two paragraphs) and the leading findings as numbered
   * insight lines with gold chips — the same content as the HTML cover
   * (reader.coverFindings / report.sectionText), passed in by the deck
   * assembler so this stays data-source-agnostic. Degrades to a clean title
   * cover when spec carries no exec text / findings.
   * spec = {exec, findings: [title, …]}. Replaces titleSlide in the editable
   * deck; the image deck keeps titleSlide untouched.
   */
  exporter.coverSlide = function (spec) {
    spec = spec || {};
    var p = TR.AGG.project;
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    var content = fillRect(next(), { x: 0, y: 0, w: 0.18, h: SLIDE_H }, brand);
    content += textBox(next(), { x: MARGIN + 0.15, y: 0.62, w: 11.9, h: 0.3 },
      [para("REPORT", { size: SIZE.kicker, bold: true, colour: GREY })]);
    content += textBox(next(), { x: MARGIN + 0.15, y: 0.95, w: 11.9, h: 1.15 },
      [para(p.name || "", { size: SIZE.cover, bold: true, colour: INK })]);
    var d = new Date();
    var sub = [p.client, p.wave,
      d.getDate() + " " + MONTHS[d.getMonth()] + " " + d.getFullYear()]
      .filter(Boolean).join(" · ");
    content += textBox(next(), { x: MARGIN + 0.15, y: 2.12, w: 11.9, h: 0.34 },
      [para(sub, { size: SIZE.lead, colour: GREY })]);
    var y = 2.75;
    var exec = String(spec.exec || "").trim();
    if (exec) {
      var execParas = exec.split(/\n+/).slice(0, 2).map(function (t) {
        return para(TR.charts.clip(t, 320), { size: SIZE.body, colour: INK });
      });
      content += textBox(next(), { x: MARGIN + 0.15, y: y, w: 11.9, h: 1.5 },
        execParas);
      y += 1.62;
    }
    // leading findings only when story pins exist — same rule as the HTML
    // cover (coverAvailable); a pin-less deck keeps a clean title cover
    var findings = (spec.findings || []).filter(Boolean).slice(0, 5);
    findings.forEach(function (text, i) {
      var rowH = Math.min(0.52, (SLIDE_H - 0.55 - y) / (findings.length - i));
      content += rectShape(next(), { x: MARGIN + 0.15, y: y + 0.03, w: 0.3, h: 0.3 },
        STYLE.GOLD);
      content += textBox(next(), { x: MARGIN + 0.15, y: y + 0.045, w: 0.3, h: 0.26 },
        [para(String(i + 1), { size: SIZE.kicker, bold: true, colour: WHITE,
          align: "ctr" })]);
      content += textBox(next(), { x: MARGIN + 0.6, y: y, w: 11.2, h: rowH },
        [para(TR.charts.clip(text, 130), { size: SIZE.lead, bold: true, colour: INK })]);
      y += rowH;
    });
    // text wordmark, cover only (Duncan's locked decision — no logo asset)
    content += textBox(next(), { x: SLIDE_W - MARGIN - 4.2, y: 7.02, w: 4.2, h: 0.32 },
      [para("Turas · The Research LampPost",
        { size: SIZE.footer, colour: GREY, align: "r" })]);
    return wrapSlide(content);
  };

  exporter.titleSlide = function (itemCount) {
    var p = TR.AGG.project;
    var brand = TR.charts.brandOf().replace("#", "").toUpperCase();
    var id = 1;
    var next = function () { return ++id; };
    return wrapSlide(
      // sharp full-bleed background (see dividerSlide)
      fillRect(next(), { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H }, brand) +
      textBox(next(), { x: 1, y: 2.5, w: SLIDE_W - 2, h: 1.1 },
        [para(p.name, { size: SIZE.cover, bold: true, colour: WHITE })]) +
      textBox(next(), { x: 1, y: 3.7, w: SLIDE_W - 2, h: 0.9 },
        [para([p.client, p.wave].filter(Boolean).join(" · "),
          { size: SIZE.lead, colour: STYLE.ON_BRAND_MUTED }),
         para(itemCount + " exhibits · built natively inside the Turas report — every table and bar is editable",
          { size: SIZE.body, colour: STYLE.ON_BRAND_MUTED })]));
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

  /** SVG string -> {bytes, w, h} PNG at `scale`. Browser only (canvas). */
  exporter.svgToPng = function (svgString, scale) {
    return new Promise(function (resolve, reject) {
      var vb = svgString.match(/viewBox="0 0 ([0-9.]+) ([0-9.]+)"/);
      var w = vb ? parseFloat(vb[1]) : 1100, h = vb ? parseFloat(vb[2]) : 700;
      var img = new Image();
      img.onload = function () {
        var canvas = document.createElement("canvas");
        canvas.width = Math.round(w * scale);
        canvas.height = Math.round(h * scale);
        var ctx = canvas.getContext("2d");
        ctx.fillStyle = "#fff";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        canvas.toBlob(function (blob) {
          if (!blob) { reject(new Error("rasterise failed")); return; }
          blob.arrayBuffer().then(function (buf) {
            resolve({ bytes: new Uint8Array(buf), w: canvas.width, h: canvas.height });
          });
        }, "image/png");
      };
      img.onerror = function () { reject(new Error("SVG load failed")); };
      img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svgString);
    });
  };

  /**
   * Image deck: each card SVG becomes a pixel-perfect full-slide PNG (the
   * exact on-screen render), not editable. Browser only (canvas). cards = SVG
   * strings, one per slide.
   */
  exporter.downloadImageDeck = function (cards, filename) {
    cards = (cards || []).filter(Boolean);
    if (!cards.length) { TR.shell.toast("Nothing to export"); return; }
    TR.shell.toast("Rendering " + cards.length + " image slide(s)…");
    Promise.all(cards.map(function (svg) { return exporter.svgToPng(svg, 2); }))
      .then(function (pngs) {
        var slides = [exporter.titleSlide(cards.length)].concat(
          pngs.map(function (png) { return exporter.imageSlide(png); }));
        var bytes = TR.pptx.package(slides, { project: TR.AGG.project });
        var blob = new Blob([bytes], { type:
          "application/vnd.openxmlformats-officedocument.presentationml.presentation" });
        var link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(link.href);
        TR.shell.toast("Image PowerPoint downloaded — pixel-perfect");
      })
      .catch(function (e) {
        if (global.console) console.error("[TurasV2] image deck failed:", e);
        TR.shell.toast("Image export failed — see console");
      });
  };

})(typeof window !== "undefined" ? window : globalThis);
