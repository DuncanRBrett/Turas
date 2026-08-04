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

  /** Display precision from the config's DECIMAL PLACES block. The crosstab
   *  rounds to these and tests on the underlying counts; every tab must use the
   *  SAME places or it can show a figure the published table cannot reproduce.
   *  Falls back to the config template's defaults when a report predates the
   *  project.format block. */
  fmt.decimalsFor = function (isMean) {
    var f = TR.AGG && TR.AGG.project && TR.AGG.project.format;
    if (isMean) return (f && f.rating_decimals != null) ? f.rating_decimals : 1;
    return (f && f.percent_decimals != null) ? f.percent_decimals : 0;
  };

  /** Display precision for a specific metric.
   *
   *  An NPS is a mean-KIND row but a percentage-SCALED metric (type "nps",
   *  scale_max 100), and the crosstab rounds it with decimal_places_percent —
   *  CCPB publishes 79, not 79.4. Keying purely off "is it a mean row" gives an
   *  NPS the ratings precision and reintroduces a digit the table never had. */
  fmt.decimalsForQ = function (q, isMean) {
    if (!isMean) return fmt.decimalsFor(false);
    if (q && (q.type === "nps" || q.scale_max === 100)) return fmt.decimalsFor(false);
    return fmt.decimalsFor(true);
  };

  /** Round a value to the display precision — what the reader can actually see.
   *  Wave-on-wave CHANGE is the difference of two of these, never of the raw
   *  values, so the change reconciles with the two figures on screen. */
  fmt.toDisplay = function (value, isMean) {
    if (value == null || (typeof value === "number" && isNaN(value))) return null;
    return Number(Number(value).toFixed(fmt.decimalsFor(isMean)));
  };

  /** Index/mean score display — ONE rule everywhere a score card shows a
   *  mean (dashboard gauges, heatmap, tracking); en dash for null. */
  fmt.score = function (value, decimals) {
    if (value == null || (typeof value === "number" && isNaN(value))) return "–";
    var dp = decimals == null ? fmt.decimalsFor(true) : decimals;
    return Number(value).toFixed(dp);
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
