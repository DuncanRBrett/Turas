/**
 * Minimal XLSX writer — a real Excel workbook (zip of OOXML parts via
 * TR.zip), one sheet, inline strings + native numbers. Enough for
 * exporting any matrix/heatmap; no dependencies, ~1 KB of parts.
 */
(function (global) {
  "use strict";
  var TR = global.TR, esc = TR.fmt.escapeXml;

  var xlsx = TR.xlsx = {};

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

  /** Cell XML: numbers stay numeric, everything else is an inline string. */
  function cell(value) {
    if (typeof value === "number" && isFinite(value)) {
      return "<c><v>" + value + "</v></c>";
    }
    var text = String(value == null ? "" : value);
    var numeric = text.replace(/[%\s ,]/g, "");
    if (numeric !== "" && !isNaN(Number(numeric)) && /^[\d.\-+]+$/.test(numeric)) {
      return "<c><v>" + Number(numeric) + "</v></c>";
    }
    return '<c t="inlineStr"><is><t xml:space="preserve">' + esc(text) + "</t></is></c>";
  }

  function sheet(rows) {
    return XML + '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      "<sheetData>" + rows.map(function (row) {
        return "<row>" + row.map(cell).join("") + "</row>";
      }).join("") + "</sheetData></worksheet>";
  }

  /** Workbook bytes for a single sheet (also embedded in native charts). */
  xlsx.bytes = function (sheetName, rows) {
    return TR.zip.build([
      { name: "[Content_Types].xml", data: CT },
      { name: "_rels/.rels", data: ROOT_RELS },
      { name: "xl/workbook.xml", data: workbook(sheetName) },
      { name: "xl/_rels/workbook.xml.rels", data: WB_RELS },
      { name: "xl/worksheets/sheet1.xml", data: sheet(rows) }
    ]);
  };

  /**
   * Build and download an .xlsx.
   * @param {string} filename - without extension.
   * @param {string} sheetName - tab name.
   * @param {Array<Array>} rows - first row is typically the header.
   */
  xlsx.download = function (filename, sheetName, rows) {
    var bytes = xlsx.bytes(sheetName, rows);
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
