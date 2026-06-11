/**
 * v2 renderers — crosstab table HTML (heatmap, counts, low-base, deltas),
 * export matrix/TSV/clipboard flavours, and the per-question bar chart.
 * All pure string builders over the view model from 22_model.js.
 *
 * SIZE-EXCEPTION: one cohesive rendering surface over the model contract;
 * the table builder dominates and decomposing it would obscure the layout.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt, S = TR.svg;

  var render = TR.render = {};

  /* brand helpers shared with the v1 pptx packager */
  TR.charts = TR.charts || {};
  TR.charts.brandOf = function () {
    return (TR.AGG && TR.AGG.project.brand_colour) || TR.DEFAULT_BRAND;
  };
  TR.charts.accentOf = function () {
    return (TR.AGG && TR.AGG.project.accent_colour) || TR.DEFAULT_ACCENT;
  };
  TR.charts.clip = function (label, max) {
    var s = String(label == null ? "" : label);
    return s.length > max ? s.slice(0, max - 1) + "…" : s;
  };

  function fmtPct(v) {
    return v === null || v === undefined ? "–" : Math.round(v) + "%";
  }
  function fmtMean(v) {
    return v === null || v === undefined ? "–" : Number(v).toFixed(1);
  }

  /** Heatmap tint: brand colour with alpha scaled by value. */
  function heat(value, max) {
    if (value === null || value === undefined || !(max > 0)) return "";
    var alpha = Math.max(0, Math.min(value / max, 1)) * 0.42;
    var brand = TR.charts.brandOf().replace("#", "");
    var r = parseInt(brand.substr(0, 2), 16), g = parseInt(brand.substr(2, 2), 16),
        b = parseInt(brand.substr(4, 2), 16);
    return "background:rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(3) + ");";
  }

  function deltaChip(delta) {
    if (!delta || delta.diff === null) return "";
    var up = delta.diff >= 0;
    var size = delta.isMean ? Math.abs(delta.diff).toFixed(1)
      : Math.abs(delta.diff).toFixed(0);
    if (!delta.isMean && Math.abs(delta.diff) < 1) return "";
    return '<span class="delta ' + (up ? "up" : "down") +
      (delta.sig ? " sig" : "") + '" title="' +
      (delta.year || "prior wave") + ": " +
      (delta.isMean ? delta.prev.toFixed(1) : Math.round(delta.prev) + "%") +
      (delta.sig ? " · significant change" : "") + '">' +
      (up ? "▲" : "▼") + size + "</span>";
  }
  render.deltaChip = deltaChip;

  /** Crosstab table from a view model. */
  render.tableHtml = function (model, opts) {
    opts = opts || {};
    var maxByRow = model.rows.map(function (r) {
      if (r.kind === "mean") return 100;
      var max = 0;
      r.cells.forEach(function (c) {
        if (c.pct !== null && c.pct > max) max = c.pct;
      });
      return max;
    });
    var sort = model.sorted || null;
    var out = ['<table class="ct"><thead><tr><th class="lab">Response</th>'];
    model.columns.forEach(function (col, i) {
      var arrow = sort && sort.col === i
        ? (sort.dir === "desc" ? " ↓" : " ↑") : "";
      out.push('<th class="' + (i === 0 ? "total" : "") +
        (opts.sortable ? " sortable" : "") + '"' +
        (opts.sortable ? ' data-sortcol="' + i + '" title="Click to sort rows by ' +
          fmt.escapeHtml(col.label) + ' (descending / ascending / original)"' : "") + ">" +
        (i > 0 && opts.hideable
          ? '<button class="colx" data-hidecol="' + fmt.escapeHtml(col.label) +
            '" title="Hide this column (table, chart and exports)" ' +
            'aria-label="Hide column ' + fmt.escapeHtml(col.label) + '">✕</button>'
          : "") +
        '<div class="cth">' + fmt.escapeHtml(col.label) + arrow + "</div>" +
        (col.letter ? '<div class="clt">(' + col.letter + ")</div>" : "") +
        "</th>");
    });
    out.push("</tr></thead><tbody>");
    out.push('<tr class="rb"><td class="lab">Base (n=)</td>');
    model.columns.forEach(function (col) {
      out.push("<td>" + (col.low
        ? '<span class="lowb" title="Base below ' + model.lowBaseThreshold +
          ' — interpret with caution">' + fmt.base(col.base) + " ⚠</span>"
        : fmt.base(col.base)) + "</td>");
    });
    out.push("</tr>");

    model.rows.forEach(function (row, ri) {
      var cls = row.kind === "net" ? "rn" : row.kind === "mean" ? "rm" : "rc";
      out.push('<tr class="' + cls + '"><td class="lab">' +
        (opts.rowHideable
          ? '<button class="rowx" data-hiderow="' + fmt.escapeHtml(row.label) +
            '" title="Hide this row (table, chart and exports)" ' +
            'aria-label="Hide row ' + fmt.escapeHtml(row.label) + '">✕</button>'
          : "") +
        fmt.escapeHtml(row.label) +
        (row.indexDesc ? '<div class="idxd">' + fmt.escapeHtml(row.indexDesc) + "</div>" : "") +
        "</td>");
      row.cells.forEach(function (cell, i) {
        var style = opts.heatmap
          ? heat(row.kind === "mean" ? cell.mean : cell.pct,
              row.kind === "mean" ? 100 : Math.max(maxByRow[ri], 1)) : "";
        var body;
        if (row.kind === "mean") {
          body = '<span class="mv">' + fmtMean(cell.mean) + "</span>";
        } else {
          body = '<span class="v">' + fmtPct(cell.pct) + "</span>";
        }
        if (cell.sig) {
          body += '<span class="sg" title="Significantly higher than column(s) ' +
            fmt.escapeHtml(cell.sig) + '">▲' + fmt.escapeHtml(cell.sig) + "</span>";
        }
        if (i === 0 && opts.showDeltas && row.delta) body += deltaChip(row.delta);
        if (opts.showCounts && row.kind !== "mean") {
          body += '<div class="fq">' + (cell.n === null || cell.n === undefined
            ? "" : "n=" + fmt.base(cell.n)) + "</div>";
        }
        out.push('<td style="' + style + '">' + body + "</td>");
      });
      out.push("</tr>");
    });
    out.push("</tbody></table>");
    return out.join("");
  };

  /** Plain matrix for exports (clipboard / PPTX / PNG-table). */
  render.matrix = function (model, opts) {
    opts = opts || {};
    var head = ["Response"].concat(model.columns.map(function (col) {
      return col.label + (col.letter ? " (" + col.letter + ")" : "");
    }));
    var body = [{ kind: "base", cells: ["Base (n=)"].concat(
      model.columns.map(function (col) {
        return fmt.base(col.base) + (col.low ? " ⚠" : "");
      })) }];
    model.rows.forEach(function (row) {
      if (opts.categoriesOnly && row.kind !== "category") return;
      body.push({
        kind: row.kind === "mean" ? "stat" : row.kind === "net" ? "stat" : "row",
        cells: [row.label].concat(row.cells.map(function (cell) {
          var value = row.kind === "mean" ? fmtMean(cell.mean) : fmtPct(cell.pct);
          return value + (cell.sig ? " " + cell.sig : "");
        }))
      });
    });
    return { head: head, body: body };
  };

  render.tsv = function (model) {
    var m = render.matrix(model);
    return [m.head.join("\t")].concat(m.body.map(function (row) {
      return row.cells.join("\t");
    })).join("\n");
  };

  render.clipboardHtml = function (model) {
    var m = render.matrix(model);
    var brand = TR.charts.brandOf();
    var cellCss = "padding:4px 9px;font-size:10pt;border:1px solid #d8dcea;";
    var out = ['<table style="border-collapse:collapse;font-family:Calibri,Arial,sans-serif;">', "<tr>"];
    m.head.forEach(function (h, i) {
      out.push('<th style="' + cellCss + "background:" + brand +
        ";color:#fff;font-weight:bold;text-align:" + (i === 0 ? "left" : "center") +
        ';">' + fmt.escapeHtml(h) + "</th>");
    });
    out.push("</tr>");
    m.body.forEach(function (row) {
      var extra = row.kind === "base" ? "color:#6b7280;font-style:italic;"
        : row.kind === "stat" ? "font-weight:bold;background:#f3f4f8;" : "";
      out.push("<tr>" + row.cells.map(function (cell, i) {
        return '<td style="' + cellCss + extra + "text-align:" +
          (i === 0 ? "left" : "center") + ';">' + fmt.escapeHtml(cell) + "</td>";
      }).join("") + "</tr>");
    });
    out.push("</table>");
    return out.join("");
  };

  /** Series palette: brand first, then accent + distinguishable colours. */
  render.palette = function () {
    var brand = TR.charts.brandOf();
    return [brand, TR.charts.accentOf(), S.shade(brand, 0.55), "#5B8FA8",
      "#C0655B", S.shade(brand, 0.32), "#7A7FB6", "#6B7280"];
  };

  /**
   * Chart source rows + shared axis max. model.chartKind picks the source:
   * "summary" = NET rows (Detractor/Passive/Promoter instead of 0–10),
   * "both" = detail categories AND nets, anything else = detail only.
   * Difference rows (NET POSITIVE) never chart. Falls back to whatever
   * exists so the chart is never silently empty.
   */
  render.chartRows = function (model) {
    var pick = function (kinds) {
      return model.rows.filter(function (r) {
        return kinds.indexOf(r.kind) !== -1 && !r.diff &&
          r.cells.some(function (c) {
            return c.pct !== null && c.pct !== undefined;
          });
      });
    };
    var kinds = model.chartKind === "summary" ? ["net"]
      : model.chartKind === "both" ? ["category", "net"]
      : ["category"];
    var rows = pick(kinds);
    if (!rows.length) rows = pick(["category", "net"]);
    var max = 0;
    rows.forEach(function (r) {
      r.cells.forEach(function (c) { if (c.pct > max) max = c.pct; });
    });
    return { rows: rows, axisMax: S.niceMax(max) };
  };

  /** True when a model actually has chartable NET rows. */
  render.hasNetRows = function (model) {
    return model.rows.some(function (r) {
      return r.kind === "net" && !r.diff && r.cells.some(function (c) {
        return c.pct !== null && c.pct !== undefined;
      });
    });
  };

  function colLegend(model, cols, y, x0, maxW) {
    var palette = render.palette();
    return S.legend(cols.map(function (ci, k) {
      return { label: model.columns[ci] ? model.columns[ci].label : "?",
        colour: palette[k % palette.length] };
    }), x0, y, maxW);
  }

  /**
   * Horizontal bars, grouped when multiple columns are selected
   * (e.g. Total + each campus side by side).
   * @param {number[]|number} cols - selected column indexes.
   */
  render.barChart = function (model, cols) {
    if (!Array.isArray(cols)) cols = [cols || 0];
    var data = render.chartRows(model);
    if (!data.rows.length) return "";
    var W = 660, LABEL = 210, VAL = 64;
    var barH = cols.length > 1 ? 13 : 20;
    var groupGap = 9;
    var plotW = W - LABEL - VAL;
    var x = S.linear(data.axisMax, plotW);
    var palette = render.palette();
    var body = [], y = 8;
    data.rows.forEach(function (r) {
      body.push(S.text(LABEL - 8, y + (barH * cols.length) / 2 + 4,
        TR.charts.clip(r.label, 34),
        { "text-anchor": "end", "font-size": 11.5, fill: "#3b4252" }));
      cols.forEach(function (ci, k) {
        var cell = r.cells[ci];
        var v = cell ? cell.pct : null;
        var w = v === null ? 0 : Math.max(x(v), 0);
        body.push(S.el("rect", { x: LABEL, y: y, width: plotW, height: barH,
          fill: "#eef0f7", rx: 3 }));
        body.push(S.el("rect", { x: LABEL, y: y, width: w, height: barH,
          fill: palette[k % palette.length], rx: 3 }));
        body.push(S.text(LABEL + w + 6, y + barH * 0.78,
          fmtPct(v) + (cols.length === 1 && cell && cell.sig ? " ▲" + cell.sig : ""),
          { "font-size": cols.length > 1 ? 10 : 11.5, "font-weight": 600,
            fill: "#1c2333" }));
        y += barH + 2;
      });
      y += groupGap;
    });
    var note = "0–" + data.axisMax + "% scale";
    if (cols.length === 1 && model.columns[cols[0]]) {
      note += " · " + model.columns[cols[0]].label;
    }
    body.push(S.text(LABEL, y + 8, note, { "font-size": 10, fill: "#9aa1b1" }));
    y += 18;
    if (cols.length > 1) {
      var legend = colLegend(model, cols, y + 6, LABEL, W - LABEL - 10);
      body.push(legend.body);
      y += legend.height + 6;
    }
    return S.root(W, y + 4, model.code + " — chart", body.join(""));
  };

})(typeof window !== "undefined" ? window : globalThis);
