/**
 * PPTX slide builders — native, editable slide content from the data layer:
 * real text boxes, real tables, bar charts drawn as PowerPoint SHAPES (each
 * bar a rectangle you can recolour/move). No screenshots anywhere. Pure.
 *
 * SIZE-EXCEPTION: sequential slide-assembly flow over OOXML strings;
 * fragmenting it would obscure the slide geometry story.
 */
(function (global) {
  "use strict";
  var TR = global.TR, C = TR.CONST, esc = TR.fmt.escapeXml, fmt = TR.fmt;

  var slides = TR.pptxSlides = {};

  var INK = "1C2333", GREY = "6B7280", WHITE = "FFFFFF", ZEBRA = "F3F4F8";
  var MARGIN_IN = 0.55, TITLE_H_IN = 0.62, META_H_IN = 0.3, CONTENT_TOP_IN = 1.55;

  function emu(inches) { return Math.round(inches * C.EMU_PER_INCH); }
  function hex(colour) { return String(colour).replace("#", "").toUpperCase(); }

  /** One paragraph with one run. Empty text -> empty paragraph. */
  function para(text, opts) {
    if (!text) return "<a:p/>";
    return "<a:p><a:pPr" + (opts.align ? ' algn="' + opts.align + '"' : "") + "/>" +
      '<a:r><a:rPr lang="en-US" dirty="0" sz="' + Math.round(opts.size * 100) + '"' +
      (opts.bold ? ' b="1"' : "") + (opts.italic ? ' i="1"' : "") + ">" +
      '<a:solidFill><a:srgbClr val="' + (opts.colour || INK) + '"/></a:solidFill>' +
      "</a:rPr><a:t>" + esc(text) + "</a:t></a:r></a:p>";
  }

  /** A plain text box shape. box in inches {x,y,w,h}. */
  function textBox(id, name, box, paras) {
    return '<p:sp><p:nvSpPr><p:cNvPr id="' + id + '" name="' + esc(name) + '"/>' +
      '<p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>' +
      '<p:spPr><a:xfrm><a:off x="' + emu(box.x) + '" y="' + emu(box.y) + '"/>' +
      '<a:ext cx="' + emu(box.w) + '" cy="' + emu(box.h) + '"/></a:xfrm>' +
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>' +
      '<p:txBody><a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr><a:lstStyle/>' +
      paras.join("") + "</p:txBody></p:sp>";
  }

  /** A filled rectangle shape (a chart bar). */
  function barShape(id, box, colour) {
    return '<p:sp><p:nvSpPr><p:cNvPr id="' + id + '" name="Bar"/>' +
      "<p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
      '<p:spPr><a:xfrm><a:off x="' + emu(box.x) + '" y="' + emu(box.y) + '"/>' +
      '<a:ext cx="' + emu(box.w) + '" cy="' + emu(box.h) + '"/></a:xfrm>' +
      '<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 18000"/></a:avLst></a:prstGeom>' +
      '<a:solidFill><a:srgbClr val="' + colour + '"/></a:solidFill>' +
      "<a:ln><a:noFill/></a:ln></p:spPr>" +
      "<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>";
  }

  /** Native a:tbl from a tables.matrix model. box in inches. */
  function tableFrame(id, box, matrix, brand, fontSize) {
    var nCols = matrix.head.length;
    var labelW = Math.min(box.w * 0.3, 3.2);
    var colW = (box.w - labelW) / Math.max(nCols - 1, 1);
    var rowH = Math.round(emu(Math.min(0.32, box.h / (matrix.body.length + 1))));
    var grid = '<a:gridCol w="' + emu(labelW) + '"/>';
    for (var i = 1; i < nCols; i++) grid += '<a:gridCol w="' + emu(colW) + '"/>';

    var cell = function (text, opts) {
      return "<a:tc><a:txBody><a:bodyPr/><a:lstStyle/>" +
        para(text, opts) + "</a:txBody>" +
        '<a:tcPr marL="27432" marR="27432" marT="13716" marB="13716" anchor="ctr">' +
        '<a:solidFill><a:srgbClr val="' + opts.fill + '"/></a:solidFill></a:tcPr></a:tc>';
    };
    var rows = ['<a:tr h="' + rowH + '">' + matrix.head.map(function (h, i) {
      return cell(h, { size: fontSize, bold: true, colour: WHITE, fill: brand,
        align: i === 0 ? "l" : "ctr" });
    }).join("") + "</a:tr>"];

    matrix.body.forEach(function (row, r) {
      var fill = row.kind === "stat" ? ZEBRA : (r % 2 === 1 ? "FAFBFE" : WHITE);
      var colour = row.kind === "base" ? GREY : INK;
      rows.push('<a:tr h="' + rowH + '">' + row.cells.map(function (text, i) {
        return cell(text, { size: fontSize, bold: row.kind === "stat",
          italic: row.kind === "base", colour: colour, fill: fill,
          align: i === 0 ? "l" : "ctr" });
      }).join("") + "</a:tr>");
    });

    return '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="' + id +
      '" name="Table"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>' +
      '<p:xfrm><a:off x="' + emu(box.x) + '" y="' + emu(box.y) + '"/>' +
      '<a:ext cx="' + emu(box.w) + '" cy="' + emu(box.h) + '"/></p:xfrm>' +
      '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">' +
      '<a:tbl><a:tblPr firstRow="1"/><a:tblGrid>' + grid + "</a:tblGrid>" +
      rows.join("") + "</a:tbl></a:graphicData></a:graphic></p:graphicFrame>";
  }

  /** Editable bar chart: label + bar + value, one trio of shapes per row. */
  function barGroup(idRef, box, rows, axisMax, brand, payload) {
    var parts = [];
    var labelW = Math.min(1.7, box.w * 0.4), valueW = Math.min(0.85, box.w * 0.2);
    var plotW = Math.max(box.w - labelW - valueW, 0.4);
    var step = Math.min(0.46, box.h / Math.max(rows.length, 1));
    var barH = step * 0.62;
    var pd = fmt.pctDecimals(payload);
    rows.forEach(function (row, i) {
      var y = box.y + i * step;
      var v = typeof row.value === "number" ? row.value : 0;
      var w = axisMax > 0 ? (v / axisMax) * plotW : 0;
      parts.push(textBox(idRef.next(), "Label", { x: box.x, y: y, w: labelW, h: step },
        [para(TR.charts.clip(row.label, 24), { size: 10, colour: INK, align: "r" })]));
      parts.push(barShape(idRef.next(),
        { x: box.x + labelW + 0.05, y: y + (step - barH) / 2, w: Math.max(w, 0.02), h: barH },
        brand));
      parts.push(textBox(idRef.next(), "Value",
        { x: box.x + labelW + 0.1 + w, y: y, w: valueW, h: step },
        [para(fmt.num(v, "pct", pd) + (row.sig ? " " + row.sig : ""),
          { size: 10, bold: true, colour: INK })]));
    });
    return parts.join("");
  }

  function wrap(contentXml) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
      '<p:sld xmlns:a="' + TR.pptx.NS.a + '" xmlns:r="' + TR.pptx.NS.r +
      '" xmlns:p="' + TR.pptx.NS.p + '"><p:cSld><p:spTree>' +
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>' +
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>' +
      '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>' +
      contentXml + "</p:spTree></p:cSld>" +
      "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>";
  }

  function idCounter() {
    var n = 1;
    return { next: function () { return ++n; } };
  }

  function header(idRef, title, metaLine, brand) {
    return barShape(idRef.next(), { x: 0, y: 0, w: C.SLIDE_W_IN, h: 0.07 }, brand) +
      textBox(idRef.next(), "Title",
        { x: MARGIN_IN, y: 0.32, w: C.SLIDE_W_IN - MARGIN_IN * 2, h: TITLE_H_IN },
        [para(title, { size: 21, bold: true, colour: brand })]) +
      textBox(idRef.next(), "Meta",
        { x: MARGIN_IN, y: 1.0, w: C.SLIDE_W_IN - MARGIN_IN * 2, h: META_H_IN },
        [para(metaLine, { size: 11, colour: GREY })]);
  }

  /** Title slide for the deck. */
  slides.titleSlide = function (payload, slideCount) {
    var p = payload.project;
    var brand = hex(TR.charts.brandOf(payload));
    var ids = idCounter();
    var content = barShape(ids.next(), { x: 0, y: 0, w: C.SLIDE_W_IN, h: C.SLIDE_H_IN }, brand) +
      textBox(ids.next(), "Title",
        { x: 1.0, y: 2.4, w: C.SLIDE_W_IN - 2, h: 1.2 },
        [para(p.name, { size: 36, bold: true, colour: WHITE })]) +
      textBox(ids.next(), "Sub", { x: 1.0, y: 3.6, w: C.SLIDE_W_IN - 2, h: 0.9 },
        [para([p.client, p.wave].filter(Boolean).join(" · "),
          { size: 16, colour: "D9DCEC" }),
         para(slideCount + " exhibits · native editable slides built in-report by Turas",
          { size: 12, colour: "B9BEDC" })]);
    return wrap(content);
  };

  /** Chunk matrix body rows for table pagination. */
  function chunkMatrix(matrix) {
    var per = C.PPTX_TABLE_ROWS_PER_SLIDE;
    if (matrix.body.length <= per) return [matrix];
    var chunks = [];
    for (var i = 0; i < matrix.body.length; i += per) {
      chunks.push({ head: matrix.head, body: matrix.body.slice(i, i + per) });
    }
    return chunks;
  }

  /**
   * Slides for one question: bars (as shapes) + native table when compact,
   * otherwise full-width table paginated across continuation slides.
   * @returns {string[]} one or more slide XML strings.
   */
  slides.questionSlides = function (q, payload, colIndex) {
    var brand = hex(TR.charts.brandOf(payload));
    var cols = TR.data.bannerColumns(payload, q);
    var matrix = TR.tables.matrix(q, payload);
    var metaLine = [payload.project.name, payload.project.wave,
      "Base: " + (q.base_label || "All respondents") +
      (q.bases ? " · n=" + fmt.base(q.bases[0]) : "")].filter(Boolean).join(" · ");
    var title = (q.code || q.id) + " — " + q.title;
    var contentH = C.SLIDE_H_IN - CONTENT_TOP_IN - 0.45;
    var compact = (q.rows || []).length > 0 && (q.rows || []).length <= 9 &&
      cols.length <= 6 && matrix.body.length <= C.PPTX_TABLE_ROWS_PER_SLIDE;

    if (compact) {
      var ids = idCounter();
      var barRows = q.rows.map(function (row) {
        return { label: row.label, value: row.values[colIndex],
          sig: row.sig ? row.sig[colIndex] : "" };
      });
      var axisMax = TR.svg.niceMax(TR.data.maxRowValue(q));
      var content = header(ids, title, metaLine +
          " · bars: " + (cols[colIndex] || "Total"), brand) +
        barGroup(ids, { x: MARGIN_IN, y: CONTENT_TOP_IN, w: 5.4, h: contentH },
          barRows, axisMax, brand, payload) +
        tableFrame(ids.next(), { x: 6.3, y: CONTENT_TOP_IN,
          w: C.SLIDE_W_IN - 6.3 - MARGIN_IN,
          h: Math.min(contentH, (matrix.body.length + 1) * 0.32) },
          matrix, brand, 10);
      return [wrap(content)];
    }

    return chunkMatrix(matrix).map(function (chunk, i, all) {
      var ids = idCounter();
      var suffix = all.length > 1 ? " (" + (i + 1) + "/" + all.length + ")" : "";
      return wrap(header(ids, title + suffix, metaLine, brand) +
        tableFrame(ids.next(), { x: MARGIN_IN, y: CONTENT_TOP_IN,
          w: C.SLIDE_W_IN - MARGIN_IN * 2,
          h: Math.min(contentH, (chunk.body.length + 1) * 0.3) },
          chunk, brand, matrix.head.length > 7 ? 9 : 10));
    });
  };

  /** One slide for a composite view: grouped editable bars per question. */
  slides.compositeSlide = function (model, payload) {
    var brand = hex(TR.charts.brandOf(payload));
    var light = hex(TR.svg.shade(TR.charts.brandOf(payload), 0.55));
    var ids = idCounter();
    var title = "Composite — " + model.items.map(function (i) { return i.code; }).join(" + ");
    var metaLine = payload.project.name + " · column: " + model.column +
      " · shared axis 0–" + model.sharedMax + "%";
    var content = header(ids, title, metaLine, brand);
    var contentH = C.SLIDE_H_IN - CONTENT_TOP_IN - 0.4;
    var slotW = (C.SLIDE_W_IN - MARGIN_IN * 2) / model.items.length;
    model.items.forEach(function (item, i) {
      var x = MARGIN_IN + i * slotW;
      content += textBox(ids.next(), "QTitle",
        { x: x, y: CONTENT_TOP_IN, w: slotW - 0.2, h: 0.5 },
        [para(item.code + " · " + TR.charts.clip(item.title, 38),
          { size: 11, bold: true, colour: INK }),
         para("n=" + (item.base != null ? fmt.base(item.base) : "–"),
          { size: 9, colour: GREY })]);
      content += barGroup(ids, { x: x, y: CONTENT_TOP_IN + 0.6,
        w: slotW - 0.3, h: contentH - 0.6 },
        item.rows.slice(0, 8).map(function (r) { return r; }),
        model.sharedMax, i % 2 === 0 ? brand : light, payload);
    });
    return wrap(content);
  };

})(typeof window !== "undefined" ? window : globalThis);
