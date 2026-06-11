/**
 * Table builders. One matrix model feeds four renderers: report HTML,
 * clipboard HTML (inline styles, pastes as an editable PowerPoint/Excel
 * table), TSV plain text, and (in later modules) SVG + native PPTX tables.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var tables = TR.tables = {};

  /**
   * Plain matrix model of a question table.
   * @returns {{head: string[], body: Array<{kind: string, cells: string[]}>}}
   *   kind is "base" | "row" | "stat". Sig letters are appended " A".
   */
  tables.matrix = function (q, payload) {
    var cols = TR.data.bannerColumns(payload, q);
    var letters = TR.data.bannerLetters(payload, q);
    var pd = fmt.pctDecimals(payload);
    var head = [""].concat(cols.map(function (c, i) {
      return c + " (" + letters[i] + ")";
    }));
    var body = [];
    if (q.bases) {
      body.push({ kind: "base", cells: ["Base (n)"].concat(
        q.bases.map(function (b) { return fmt.base(b); })) });
    }
    (q.rows || []).forEach(function (row) {
      body.push({ kind: "row", cells: [String(row.label)].concat(
        (row.values || []).map(function (v, i) {
          var sig = row.sig && row.sig[i] ? " " + row.sig[i] : "";
          return fmt.num(v, row.format || "pct", pd) + sig;
        })) });
    });
    (q.stats || []).forEach(function (stat) {
      body.push({ kind: "stat", cells: [String(stat.label)].concat(
        (stat.values || []).map(function (v, i) {
          var sig = stat.sig && stat.sig[i] ? " " + stat.sig[i] : "";
          return fmt.num(v, stat.format || "dec1", pd) + sig;
        })) });
    });
    return { head: head, body: body };
  };

  /** Report table HTML (rich: sig as <sup>, styled by the report CSS). */
  tables.html = function (q, payload) {
    var cols = TR.data.bannerColumns(payload, q);
    var letters = TR.data.bannerLetters(payload, q);
    var pd = fmt.pctDecimals(payload);
    var out = ['<table class="qtable"><thead><tr><th class="lab" scope="col">' +
      '<span class="visually-hidden">Row</span></th>'];
    cols.forEach(function (c, i) {
      out.push('<th scope="col">' + fmt.escapeHtml(c) +
        '<span class="letter">' + fmt.escapeHtml(letters[i]) + "</span></th>");
    });
    out.push("</tr></thead><tbody>");
    if (q.bases) {
      out.push('<tr class="baserow"><td class="lab">Base (n)' +
        (q.base_label ? ' <span class="baselab">— ' +
          fmt.escapeHtml(q.base_label) + "</span>" : "") + "</td>");
      q.bases.forEach(function (b) { out.push("<td>" + fmt.base(b) + "</td>"); });
      out.push("</tr>");
    }
    (q.rows || []).forEach(function (row) {
      out.push('<tr><td class="lab">' + fmt.escapeHtml(row.label) + "</td>");
      (row.values || []).forEach(function (v, i) {
        out.push("<td>" + fmt.num(v, row.format || "pct", pd) +
          (row.sig ? fmt.sigSup(row.sig[i]) : "") + "</td>");
      });
      out.push("</tr>");
    });
    (q.stats || []).forEach(function (stat) {
      out.push('<tr class="statrow"><td class="lab">' +
        fmt.escapeHtml(stat.label) + "</td>");
      (stat.values || []).forEach(function (v, i) {
        out.push("<td>" + fmt.num(v, stat.format || "dec1", pd) +
          (stat.sig ? fmt.sigSup(stat.sig[i]) : "") + "</td>");
      });
      out.push("</tr>");
    });
    out.push("</tbody></table>");
    return out.join("");
  };

  /** Tab-separated plain text (clipboard text/plain flavour). */
  tables.tsv = function (q, payload) {
    var m = tables.matrix(q, payload);
    var lines = [m.head.join("\t")];
    m.body.forEach(function (row) { lines.push(row.cells.join("\t")); });
    return lines.join("\n");
  };

  /**
   * Inline-styled HTML table for the clipboard. PowerPoint, Word and Excel
   * all paste this as a real, editable table — no screenshots involved.
   */
  tables.clipboardHtml = function (q, payload) {
    var m = tables.matrix(q, payload);
    var brand = TR.charts.brandOf(payload);
    var cellBase = 'padding:4px 9px;font-size:11pt;border:1px solid #d8dcea;';
    var out = ['<table style="border-collapse:collapse;font-family:Calibri,Arial,sans-serif;">'];
    out.push("<tr>");
    m.head.forEach(function (h, i) {
      out.push('<th style="' + cellBase + "background:" + brand +
        ";color:#ffffff;font-weight:bold;text-align:" +
        (i === 0 ? "left" : "center") + ';">' + fmt.escapeHtml(h) + "</th>");
    });
    out.push("</tr>");
    m.body.forEach(function (row) {
      var style = cellBase + (row.kind === "base"
        ? "color:#6b7280;font-style:italic;"
        : row.kind === "stat" ? "font-weight:bold;background:#f3f4f8;" : "");
      out.push("<tr>");
      row.cells.forEach(function (cell, i) {
        out.push('<td style="' + style + "text-align:" +
          (i === 0 ? "left" : "center") + ';">' + fmt.escapeHtml(cell) + "</td>");
      });
      out.push("</tr>");
    });
    out.push("</table>");
    return out.join("");
  };

})(typeof window !== "undefined" ? window : globalThis);
