/**
 * Pure formatting helpers — escaping, number formats, significance markup.
 * No DOM access; fully unit-tested in tests/run_tests.mjs.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var fmt = TR.fmt = {};

  /** Escape a string for safe insertion into HTML text or attributes. */
  fmt.escapeHtml = function (value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  };

  /** Escape a string for OOXML text nodes and attributes. */
  fmt.escapeXml = function (value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&apos;");
  };

  /** Percent decimal places for a payload (project override or default). */
  fmt.pctDecimals = function (payload) {
    var f = payload && payload.project && payload.project.format;
    return f && f.percent_decimals != null
      ? f.percent_decimals
      : TR.CONST.PCT_DECIMALS_DEFAULT;
  };

  /**
   * Format a numeric cell.
   * @param {number|null} value - raw value; null/NaN renders as an en dash.
   * @param {string} format - "pct" (default) | "dec1" | "int" | "nps".
   * @param {number} [pctDecimals] - decimals for "pct" (default from CONST).
   * @returns {string}
   */
  fmt.num = function (value, format, pctDecimals) {
    if (value == null || (typeof value === "number" && isNaN(value))) return "–";
    var f = format || "pct";
    if (f === "pct") {
      var d = pctDecimals == null ? TR.CONST.PCT_DECIMALS_DEFAULT : pctDecimals;
      return Number(value).toFixed(d) + "%";
    }
    if (f === "dec1") return Number(value).toFixed(1);
    if (f === "int" || f === "nps") {
      var rounded = Math.round(Number(value));
      return f === "nps" && rounded > 0 ? "+" + rounded : String(rounded);
    }
    return String(value);
  };

  /** Render significance letters as superscript HTML ("" stays ""). */
  fmt.sigSup = function (letters) {
    if (!letters) return "";
    var safe = fmt.escapeHtml(letters);
    return '<sup class="sig" title="Significantly higher than column(s) ' +
      safe + ' at 95% confidence">' + safe + "</sup>";
  };

  /** Index/mean score display — ONE rule everywhere a score card shows a
   *  mean (dashboard gauges, heatmap, tracking): 1 decimal, en dash for null. */
  fmt.score = function (value) {
    if (value == null || (typeof value === "number" && isNaN(value))) return "–";
    return Number(value).toFixed(1);
  };

  /** Base sizes with thin-space thousands separator: 12345 -> "12 345". */
  fmt.base = function (n) {
    if (n == null || (typeof n === "number" && isNaN(n))) return "–";
    return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, "\u202F");
  };

  /** Filename-safe slug, capped at 48 characters. */
  fmt.slug = function (text) {
    return String(text || "export").replace(/[^a-zA-Z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "").substring(0, 48) || "export";
  };

})(typeof window !== "undefined" ? window : globalThis);
