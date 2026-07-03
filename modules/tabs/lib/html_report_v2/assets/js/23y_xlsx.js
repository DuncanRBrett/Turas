/**
 * Minimal XLSX writer — a real Excel workbook (zip of OOXML parts via
 * TR.zip), one sheet, inline strings + native numbers. Enough for
 * exporting any matrix/heatmap; no dependencies, ~1 KB of parts.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var xlsx = TR.xlsx = {};

  /** escapeXml + strip characters XML 1.0 forbids even when entity-escaped:
   *  C0 controls other than \t \n \r, U+FFFE/U+FFFF and unpaired surrogates
   *  (valid pairs — emoji — survive). A stray \x0B in a verbatim otherwise
   *  yields an invalid worksheet/slide part that Excel and PowerPoint refuse.
   *  Shared with the PPTX text runs in 29_export.js. */
  xlsx.escape = function (value) {
    return TR.fmt.escapeXml(value).replace(
      /[\uD800-\uDBFF][\uDC00-\uDFFF]|[\u0000-\u0008\u000B\u000C\u000E-\u001F\uD800-\uDFFF\uFFFE\uFFFF]/g,
      function (m) { return m.length === 2 ? m : ""; });
  };
  var esc = xlsx.escape;

  var XML = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  var CT = XML +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
    "</Types>";
  var ROOT_RELS = XML +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
    "</Relationships>";
  var WB_RELS = XML +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
    "</Relationships>";

  function workbook(sheetName) {
    return XML + '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
      '<sheets><sheet name="' + esc(sheetName).slice(0, 31) +
      '" sheetId="1" r:id="rId1"/></sheets></workbook>';
  }

  /** Cell XML: numbers stay numeric, everything else is an inline string.
   *  keepText forces a string cell even for numeric-looking text — for columns
   *  that are prose / identifiers (verbatims, IDs, phone or account numbers)
   *  where coercion would mangle the value. A numeric-matrix export leaves it
   *  off, so a display "45%" still lands as the number 45. */
  function cell(value, keepText) {
    if (typeof value === "number" && isFinite(value)) {
      return "<c><v>" + value + "</v></c>";
    }
    var text = String(value == null ? "" : value);
    var numeric = text.replace(/[%\s ,]/g, "");
    // Coerce only a clean number, and only when the caller allows it. Never a
    // leading-zero identifier (007, phone / account / postal codes): that is not
    // a number, and storing it as one drops the zero (007 -> 7).
    if (!keepText && numeric !== "" && !isNaN(Number(numeric)) &&
        /^[\d.\-+]+$/.test(numeric) && !/^[+-]?0\d/.test(numeric)) {
      return "<c><v>" + Number(numeric) + "</v></c>";
    }
    return '<c t="inlineStr"><is><t xml:space="preserve">' + esc(text) + "</t></is></c>";
  }
  xlsx._cell = cell;   // exposed for the export coercion tests

  function sheet(rows, keepText) {
    return XML + '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      "<sheetData>" + rows.map(function (row) {
        return "<row>" + row.map(function (v) { return cell(v, keepText); }).join("") + "</row>";
      }).join("") + "</sheetData></worksheet>";
  }

  /** Workbook bytes for a single sheet (also embedded in native charts).
   *  opts.keepText -> string cells are never coerced to numbers (text exports). */
  xlsx.bytes = function (sheetName, rows, opts) {
    return TR.zip.build([
      { name: "[Content_Types].xml", data: CT },
      { name: "_rels/.rels", data: ROOT_RELS },
      { name: "xl/workbook.xml", data: workbook(sheetName) },
      { name: "xl/_rels/workbook.xml.rels", data: WB_RELS },
      { name: "xl/worksheets/sheet1.xml", data: sheet(rows, opts && opts.keepText) }
    ]);
  };

  /**
   * Build and download an .xlsx.
   * @param {string} filename - without extension.
   * @param {string} sheetName - tab name.
   * @param {Array<Array>} rows - first row is typically the header.
   * @param {object} [opts] - {keepText} to suppress numeric coercion (text exports).
   */
  xlsx.download = function (filename, sheetName, rows, opts) {
    var bytes = xlsx.bytes(sheetName, rows, opts);
    var blob = new Blob([bytes], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
    var link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = TR.fmt.slug(filename) + ".xlsx";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
    TR.shell.toast("Excel workbook downloaded");
  };

  /** Rows for a model matrix (shared by table + heatmap exports). */
  xlsx.rowsFromMatrix = function (matrix) {
    return [matrix.head].concat(matrix.body.map(function (row) {
      return row.cells;
    }));
  };

})(typeof window !== "undefined" ? window : globalThis);
