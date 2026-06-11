/**
 * Question cards — DOM rendering of one question from the data layer.
 * Chart failures are contained per-slot: a broken chart shows an inline
 * notice while the table still renders (robustness criterion).
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var cards = TR.cards = {};

  var TYPE_LABELS = { single: "Single", multi: "Multi", scale: "Scale",
    nps: "NPS", numeric: "Numeric" };

  /** Card header HTML (rendered eagerly so search/nav work pre-fill). */
  cards.headHtml = function (q, payload) {
    var base = q.bases && q.bases.length ? q.bases[0] : null;
    var baseline = "Base: " + (q.base_label || "All respondents") +
      (base != null ? " · n=" + fmt.base(base) : "");
    return '<header class="cardhead">' +
      '<div class="cardmeta">' +
      '<span class="qcode">' + fmt.escapeHtml(q.code || q.id) + "</span>" +
      '<span class="qtype qtype-' + fmt.escapeHtml(q.type) + '">' +
      (TYPE_LABELS[q.type] || fmt.escapeHtml(q.type)) + "</span>" +
      (q.meta && q.meta.waves ? '<span class="qtype qtype-trend">Trended</span>' : "") +
      '<div class="cardactions">' +
      '<button type="button" data-action="copy-table" title="Copy as an editable table — paste into PowerPoint, Word or Excel">Copy table</button>' +
      '<button type="button" data-action="copy-chart" title="Copy the chart as a high-resolution image">Copy chart</button>' +
      '<button type="button" data-action="download-png" title="Download this card as a high-resolution PNG">PNG</button>' +
      '<button type="button" class="primary" data-action="deck-add" title="Add to the PowerPoint deck">+ Deck</button>' +
      "</div></div>" +
      "<h2>" + fmt.escapeHtml(q.title) + "</h2>" +
      '<p class="baseline">' + fmt.escapeHtml(baseline) + "</p>" +
      "</header>";
  };

  /** Banner-column chips (chart column selector). */
  function chipsHtml(q, payload, colIndex) {
    var cols = TR.data.bannerColumns(payload, q);
    if (q.type === "scale" || q.type === "nps" || cols.length < 2) return "";
    var out = ['<div class="chips" role="group" aria-label="Chart banner column">'];
    cols.forEach(function (col, i) {
      out.push('<button type="button" class="chip" data-action="col" data-col="' +
        i + '" aria-pressed="' + (i === colIndex) + '">' +
        fmt.escapeHtml(col) + "</button>");
    });
    out.push("</div>");
    return out.join("");
  }

  /** Render a chart builder safely into a slot element. */
  cards.renderSlot = function (slot, builder, emptyOk) {
    try {
      var svgString = builder();
      if (!svgString) {
        slot.hidden = true;
        return emptyOk ? true : false;
      }
      slot.hidden = false;
      slot.innerHTML = svgString;
      return true;
    } catch (e) {
      slot.hidden = false;
      slot.innerHTML = '<div class="chart-error" role="note">Chart unavailable (' +
        fmt.escapeHtml(e.message) + "). The data table below is unaffected.</div>";
      if (global.console) console.error("[TurasReport] chart render failed:", e);
      return false;
    }
  };

  /**
   * Fill a lazily-rendered card body. The shell article carries
   * data-q (question id) and data-col (selected banner column).
   */
  cards.fill = function (article, payload) {
    var q = TR.data.questionById(payload, article.getAttribute("data-q"));
    if (!q) return;
    var colIndex = parseInt(article.getAttribute("data-col") || "0", 10) || 0;
    var body = article.querySelector(".cardbody");
    body.classList.remove("pending");
    body.innerHTML = chipsHtml(q, payload, colIndex) +
      '<div class="chart" data-slot="chart"></div>' +
      '<div class="chart" data-slot="trend"></div>' +
      '<div class="tablewrap" data-slot="table"></div>';
    cards.refreshCharts(article, payload);
    try {
      body.querySelector('[data-slot="table"]').innerHTML = TR.tables.html(q, payload);
    } catch (e) {
      body.querySelector('[data-slot="table"]').innerHTML =
        '<div class="chart-error">Table unavailable (' +
        fmt.escapeHtml(e.message) + ").</div>";
      if (global.console) console.error("[TurasReport] table render failed:", e);
    }
  };

  /** Re-render the chart + trend slots (after a column chip click). */
  cards.refreshCharts = function (article, payload) {
    var q = TR.data.questionById(payload, article.getAttribute("data-q"));
    if (!q) return;
    var colIndex = parseInt(article.getAttribute("data-col") || "0", 10) || 0;
    var chartSlot = article.querySelector('[data-slot="chart"]');
    var trendSlot = article.querySelector('[data-slot="trend"]');
    if (chartSlot) {
      cards.renderSlot(chartSlot, function () {
        return TR.charts.forQuestion(q, payload, colIndex);
      }, true);
    }
    if (trendSlot) {
      cards.renderSlot(trendSlot, function () {
        return TR.charts.trend(q, payload, colIndex);
      }, true);
    }
    article.querySelectorAll('.chip[data-action="col"]').forEach(function (chip) {
      chip.setAttribute("aria-pressed",
        String(parseInt(chip.getAttribute("data-col"), 10) === colIndex));
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
