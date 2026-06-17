/**
 * v2 AI insights (read-only) — per-question AI callouts, the AI executive
 * summary, and the model attribution line. Data comes from TR.AGG.ai, emitted
 * by the R data layer from the AI sidecar the classic report generates. These
 * are always labelled as AI and are visually distinct from the editable analyst
 * insight box (28_insights). Every accessor returns "" when its data is absent,
 * so AI-free reports render exactly as before.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var fmt = TR.fmt;

  var ai = TR.ai = {};

  function data() { return (TR.AGG && TR.AGG.ai) || null; }

  /** True when the report carries any AI content. */
  ai.has = function () {
    var d = data();
    return !!(d && (d.callouts || d.execSummary));
  };

  /** Read-only AI callout for one question. "" when none for this code. */
  ai.calloutHtml = function (code) {
    var d = data();
    var c = d && d.callouts && d.callouts[code];
    if (!c || !c.text) return "";
    var caveat = c.caveat
      ? '<div class="ai-callout-caveat">' + fmt.escapeHtml(c.caveat) + "</div>"
      : "";
    return '<div class="ai-callout" data-confidence="' +
      fmt.escapeHtml(c.confidence || "high") + '">' +
      '<div class="ai-callout-head"><span class="ai-spark">✦</span>' +
      "AI-assisted insight</div>" +
      '<div class="ai-callout-body">' + fmt.escapeHtml(c.text) + "</div>" +
      caveat + "</div>";
  };

  /** AI executive-summary card for the Report tab. "" when absent. */
  ai.execSummaryHtml = function () {
    var d = data();
    var e = d && d.execSummary;
    if (!e || !e.text) return "";
    var paras = String(e.text).split(/\n\n+/).map(function (p) {
      return "<p>" + fmt.escapeHtml(p.trim()) + "</p>";
    }).join("");
    var flag = e.verified ? "" :
      '<div class="ai-callout-caveat">Unverified draft &mdash; review before use.</div>';
    return '<div class="card ai-exec">' +
      '<div class="ai-callout-head"><span class="ai-spark">✦</span>' +
      "AI-assisted key findings</div>" +
      '<div class="ai-exec-body">' + paras + "</div>" + flag + "</div>";
  };

  /** Methodology attribution paragraph for the About card. "" when no AI. */
  ai.methodologyHtml = function () {
    var d = data();
    if (!d || !d.model) return "";
    return "<p><strong>AI insights:</strong> AI-assisted callouts" +
      (d.execSummary ? " and the key-findings summary" : "") +
      " in this report are generated using " + fmt.escapeHtml(d.model) +
      ". They are always labelled. AI callouts consider all banner groups at " +
      "once and may reference subgroups not shown in the current view.</p>";
  };
})(typeof window !== "undefined" ? window : globalThis);
