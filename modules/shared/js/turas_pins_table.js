/**
 * TurasPins Shared Library — Table Extraction & SVG Rendering
 *
 * Extracts table data from pin HTML (supports tracker-style and tabs-style)
 * and renders tables as SVG rect+text elements for PNG export.
 *
 * Depends on: turas_pins_utils.js (loaded first)
 * @namespace TurasPins
 */

/* global TurasPins */

(function() {
  "use strict";

  var NS = "http://www.w3.org/2000/svg";
  var SEGMENT_COLOURS = [
    "#323367", "#CC9900", "#2E8B57", "#CD5C5C", "#4682B4",
    "#9370DB", "#D2691E", "#20B2AA", "#8B4513", "#6A5ACD"
  ];

  /** Extract table data from stored pin HTML */
  TurasPins._extractTableData = function(tableHtml) {
    if (!tableHtml) return null;
    var temp = document.createElement("div");
    temp.innerHTML = tableHtml;
    var table = temp.querySelector("table");
    if (!table) return null;
    var rows = [];

    // Header row
    var headerRow = table.querySelector("thead tr");
    if (headerRow) {
      var cells = [], styles = [];
      headerRow.querySelectorAll("th").forEach(function(th) {
        if (th.style.display === "none") return;
        var text = th.querySelector(".ct-header-text");
        var label = text ? text.textContent.trim() : th.textContent.trim().split("\n")[0].trim();
        var letterEl = th.querySelector(".ct-letter");
        if (letterEl) label += " " + letterEl.textContent.trim();
        cells.push(label);
        styles.push(_getCellStyle(th, table));
      });
      if (cells.length > 0) rows.push({ cells: cells, type: "header", cellStyles: styles });
    }

    // Body rows
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      if (tr.style.display === "none" || tr.classList.contains("ct-row-excluded")) return;
      var row = _extractBodyRow(tr, table);
      if (row && row.cells.length > 0) rows.push(row);
    });
    return rows.length > 0 ? rows : null;
  };

  /** Extract a single body row (tracker and tabs styles) */
  function _extractBodyRow(tr, table) {
    var row = { cells: [], cellStyles: [], type: "data" };

    if (tr.classList.contains("tk-base-row")) {
      row.type = "base";
      _extractTrackerLabelledRow(tr, row, table, ".tk-base-label", "Base", "td.tk-base-cell");
    } else if (tr.classList.contains("tk-change-row")) {
      row.type = "change";
      _extractTrackerLabelledRow(tr, row, table, ".tk-change-label", "Change", "td.tk-change-cell");
    } else if (tr.classList.contains("tk-metric-row")) {
      var segName = tr.getAttribute("data-segment") || "";
      row.type = segName === "Total" ? "total" : "data";
      var ml = tr.querySelector(".tk-metric-label");
      row.cells.push(ml ? ml.textContent.trim() : segName);
      row.cellStyles.push(_getCellStyle(tr.querySelector("td") || tr, table));
      tr.querySelectorAll("td.tk-value-cell").forEach(function(td) {
        if (td.style.display === "none") return;
        var vs = td.querySelector(".tk-val");
        row.cells.push(vs ? vs.textContent.trim() : td.textContent.trim());
        row.cellStyles.push(_getCellStyle(td, table));
      });
      var dot = tr.querySelector(".tk-seg-dot");
      if (dot) row.colour = dot.style.background || dot.style.backgroundColor || null;
    } else if (tr.classList.contains("ct-row-base")) {
      row.type = "base"; _extractTabsCells(tr, row);
    } else if (tr.classList.contains("ct-row-mean")) {
      row.type = "mean"; _extractTabsCells(tr, row);
    } else if (tr.classList.contains("ct-row-net")) {
      row.type = "net"; _extractTabsCells(tr, row);
    } else {
      tr.querySelectorAll("th, td").forEach(function(cell) {
        if (cell.style.display === "none") return;
        row.cellStyles.push(_getCellStyle(cell, table));
        var clone = cell.cloneNode(true);
        clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn, .ct-sort-indicator")
          .forEach(function(el) { el.remove(); });
        row.cells.push(clone.textContent.trim());
      });
    }
    return row;
  }

  /** Extract tracker-style labelled row (base/change) */
  function _extractTrackerLabelledRow(tr, row, table, labelSel, fallback, cellSel) {
    var lbl = tr.querySelector(labelSel);
    row.cells.push(lbl ? lbl.textContent.trim() : fallback);
    row.cellStyles.push(_getCellStyle(tr.querySelector("td") || tr, table));
    tr.querySelectorAll(cellSel).forEach(function(td) {
      if (td.style.display === "none") return;
      row.cells.push(td.textContent.trim());
      row.cellStyles.push(_getCellStyle(td, table));
    });
  }

  /** Extract cells from tabs-style row */
  function _extractTabsCells(tr, row) {
    tr.querySelectorAll("td").forEach(function(td) {
      if (td.style.display === "none") return;
      row.cellStyles.push(_getCellStyle(td, null));
      var clone = td.cloneNode(true);
      clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
      row.cells.push(clone.textContent.trim());
    });
  }

  /** Get inline style properties from a cell */
  function _getCellStyle(el, table) {
    if (!el) return { bg: "", color: "", fontWeight: "", align: "" };
    var target = el;
    while (target && target.tagName !== "TD" && target.tagName !== "TH" && target !== table) {
      target = target.parentElement;
    }
    if (!target || target === table) target = el;
    return {
      bg: target.style.backgroundColor || "",
      color: el.style.color || target.style.color || "",
      fontWeight: el.style.fontWeight || target.style.fontWeight || "",
      align: target.style.textAlign || ""
    };
  }

  /** Render table as SVG elements */
  /** Render table as SVG rect+text elements */
  TurasPins._renderTableSVG = function(svgParent, tableData, x, y, maxW) {
    if (!tableData || tableData.length === 0) return 0;
    var nCols = tableData[0].cells.length;
    if (nCols === 0) return 0;
    var dims = _tableDims(tableData, nCols, maxW);
    var tg = _tableFrame(svgParent, x, y, maxW, dims.totalH);
    var curY = y, colourIdx = 0;

    tableData.forEach(function(row, ri) {
      var rH = row.type === "header" ? dims.headerH : dims.baseRowH;
      var res = _renderTableRow(tg, row, ri, curY, rH, x, maxW, dims, tableData);
      curY += rH;
      colourIdx = res.colourIdx !== undefined ? res.colourIdx : colourIdx;
    });
    return curY - y;
  };

  /** Calculate table column dimensions */
  function _tableDims(tableData, nCols, maxW) {
    var fontSize = 11, padX = 10, baseRowH = 28, headerH = 34;
    var maxLabelLen = 0;
    for (var i = 0; i < tableData.length; i++) {
      if (tableData[i].cells.length > 0 && tableData[i].cells[0].length > maxLabelLen)
        maxLabelLen = tableData[i].cells[0].length;
    }
    var firstColW = Math.min(Math.max(maxLabelLen * (fontSize * 0.6) + padX * 2 + 20, 140), maxW * 0.4);
    var dataColW = nCols > 1 ? (maxW - firstColW) / (nCols - 1) : maxW;
    var totalH = 0;
    for (var h = 0; h < tableData.length; h++) totalH += tableData[h].type === "header" ? headerH : baseRowH;
    return { firstColW: firstColW, dataColW: dataColW, totalH: totalH,
      fontSize: fontSize, padX: padX, baseRowH: baseRowH, headerH: headerH };
  }

  /** Create clip path, group, and border for table */
  function _tableFrame(svgParent, x, y, maxW, totalH) {
    var clipId = "tc-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5);
    var defs = svgParent.querySelector("defs") || document.createElementNS(NS, "defs");
    if (!defs.parentNode) svgParent.insertBefore(defs, svgParent.firstChild);
    var cp = document.createElementNS(NS, "clipPath"); cp.setAttribute("id", clipId);
    var cr = document.createElementNS(NS, "rect");
    cr.setAttribute("x", x); cr.setAttribute("y", y);
    cr.setAttribute("width", maxW); cr.setAttribute("height", totalH);
    cr.setAttribute("rx", "6"); cr.setAttribute("ry", "6");
    cp.appendChild(cr); defs.appendChild(cp);
    var tg = document.createElementNS(NS, "g");
    tg.setAttribute("clip-path", "url(#" + clipId + ")");
    svgParent.appendChild(tg);
    var br = document.createElementNS(NS, "rect");
    br.setAttribute("x", x); br.setAttribute("y", y);
    br.setAttribute("width", maxW); br.setAttribute("height", totalH);
    br.setAttribute("rx", "6"); br.setAttribute("ry", "6");
    br.setAttribute("fill", "none"); br.setAttribute("stroke", "#e5e7eb");
    br.setAttribute("stroke-width", "1");
    svgParent.appendChild(br);
    return tg;
  }

  /** Render a single table row (background, cells, dots, border) */
  function _renderTableRow(tg, row, ri, curY, rH, x, maxW, dims, allData) {
    var isHdr = row.type === "header";
    var bg = document.createElementNS(NS, "rect");
    bg.setAttribute("x", x); bg.setAttribute("y", curY);
    bg.setAttribute("width", maxW); bg.setAttribute("height", rH);
    bg.setAttribute("fill", _rowBg(row.type, isHdr, ri));
    tg.appendChild(bg);
    if (row.cellStyles && !isHdr) _cellBgs(tg, row, curY, rH, x, dims.firstColW, dims.dataColW);
    if ((row.type === "data" || row.type === "total") &&
        (row.colour || allData.some(function(r) { return r.colour; }))) {
      var d = document.createElementNS(NS, "circle");
      d.setAttribute("cx", x + 12); d.setAttribute("cy", curY + rH / 2); d.setAttribute("r", "3.5");
      d.setAttribute("fill", row.colour || SEGMENT_COLOURS[0]);
      tg.appendChild(d);
    }
    _rowText(tg, row, curY, rH, x, dims.firstColW, dims.dataColW, dims.fontSize, dims.padX, isHdr, allData);
    var ln = document.createElementNS(NS, "line");
    ln.setAttribute("x1", x); ln.setAttribute("x2", x + maxW);
    ln.setAttribute("y1", curY + rH); ln.setAttribute("y2", curY + rH);
    ln.setAttribute("stroke", "#e2e8f0"); ln.setAttribute("stroke-width", "0.5");
    tg.appendChild(ln);
    return {};
  };

  function _rowBg(type, isHdr, ri) {
    if (isHdr) return "#1a2744";
    var map = { base: "#f8f9fa", change: "#fafbfc", total: "#f0f0f5", mean: "#fef9e7", net: "#f5f0e8" };
    return map[type] || (ri % 2 === 0 ? "#ffffff" : "#f9fafb");
  }

  function _isSignificantBg(bg) {
    if (!bg) return false;
    bg = bg.trim().toLowerCase();
    return bg !== "" && bg !== "transparent" && bg !== "rgba(0, 0, 0, 0)" &&
      bg !== "rgb(255, 255, 255)" && bg !== "#ffffff" && bg !== "#fff" && bg !== "white";
  }

  function _cellBgs(group, row, curY, rH, x, firstColW, dataColW) {
    row.cells.forEach(function(_, ci) {
      var cs = row.cellStyles[ci];
      if (!cs || !_isSignificantBg(cs.bg)) return;
      var cw = ci === 0 ? firstColW : dataColW;
      var cx = ci === 0 ? x : x + firstColW + (ci - 1) * dataColW;
      var r = document.createElementNS(NS, "rect");
      r.setAttribute("x", cx); r.setAttribute("y", curY);
      r.setAttribute("width", cw); r.setAttribute("height", rH);
      r.setAttribute("fill", cs.bg); group.appendChild(r);
    });
  }

  function _rowText(group, row, curY, rH, x, firstColW, dataColW, fs, padX, isHdr, allData) {
    var hasStyles = row.cellStyles && row.cellStyles.length > 0;
    row.cells.forEach(function(text, ci) {
      var cs = hasStyles ? row.cellStyles[ci] : null;
      var cw = ci === 0 ? firstColW : dataColW;
      var cx;
      if (ci === 0) {
        var hasDots = allData.some(function(r) { return r.colour; });
        cx = (hasDots && (row.type === "data" || row.type === "total")) ? x + 22 : x + padX;
      } else { cx = x + firstColW + (ci - 1) * dataColW; }

      var el = document.createElementNS(NS, "text");
      el.setAttribute("y", curY + rH / 2 + 1);
      el.setAttribute("dominant-baseline", "central");
      el.setAttribute("font-size", fs);

      if (ci === 0) { el.setAttribute("x", cx); el.setAttribute("text-anchor", "start"); }
      else {
        var anc = "middle";
        if (cs && cs.align === "left") anc = "start";
        else if (cs && cs.align === "right") anc = "end";
        el.setAttribute("x", anc === "middle" ? cx + cw / 2 : anc === "end" ? cx + cw - padX : cx + padX);
        el.setAttribute("text-anchor", anc);
      }

      _cellStyle(el, cs, row.type, ci, isHdr, fs);
      var max = Math.floor((cw - padX * 2) / (fs * 0.55));
      if (max > 0 && text.length > max) text = text.substring(0, Math.max(max - 1, 5)) + "\u2026";
      el.textContent = text;
      group.appendChild(el);
    });
  }

  function _cellStyle(el, cs, type, ci, isHdr, fs) {
    if (cs && cs.color) {
      el.setAttribute("fill", cs.color);
      if (cs.fontWeight && (cs.fontWeight === "bold" || parseInt(cs.fontWeight) >= 600)) el.setAttribute("font-weight", "600");
      return;
    }
    if (isHdr) { el.setAttribute("fill", "#ffffff"); el.setAttribute("font-weight", "600"); }
    else if (type === "total" || type === "net") { el.setAttribute("fill", ci === 0 ? "#1a2744" : "#1e293b"); el.setAttribute("font-weight", "600"); }
    else if (type === "base") { el.setAttribute("fill", "#666666"); el.setAttribute("font-weight", "600"); el.setAttribute("font-size", fs - 1); }
    else if (type === "change") { el.setAttribute("fill", "#888888"); el.setAttribute("font-size", fs - 1); }
    else if (type === "mean") { el.setAttribute("fill", "#5c4a2a"); el.setAttribute("font-style", "italic"); }
    else { el.setAttribute("fill", ci === 0 ? "#374151" : "#1e293b"); }
  }

})();
