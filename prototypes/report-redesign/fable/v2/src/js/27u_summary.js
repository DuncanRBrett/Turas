/**
 * Tracking Summary view — the tracker module's summary surface rebuilt on
 * the published wave history: KPI hero cards (threshold-banded, sparkline,
 * change vs previous wave), the wave pulse bar (significant ups / downs /
 * stable), significant-changes cards across Total AND banner segments with
 * a segment filter, and the metric × segment significance heatmap.
 *
 * Sig conventions: proportions (NET %s) are pooled-z tested at 95% with
 * the low-base exclusion; means/indexes/NPS scores carry no significance
 * in published-totals mode (no per-wave SDs) and show direction only.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var summary = TR.trkSummary = {};
  var segFilter = "";        // significant-changes segment filter
  var hmGroup = null;        // heatmap banner group id
  var showAllSig = false;

  function lastCell(cells) {
    return cells.length && cells[cells.length - 1].current
      ? cells[cells.length - 1] : null;
  }

  /* ---------------- KPI cards ---------------- */

  function kpiCards() {
    var trk = TR.trk;
    return trk.metricList("key").filter(function (m) { return m.isMean; })
      .map(function (m) {
        var cells = trk.points(m, null);
        var last = lastCell(cells);
        if (!last) return null;
        var type = trk.kpiType(m);
        return { metric: m, cells: cells, last: last, type: type,
          band: trk.band(type, last.value) };
      }).filter(Boolean);
  }

  function kpiCardHtml(card) {
    var trk = TR.trk;
    var m = card.metric, last = card.last;
    var change = last.change_prev;
    var chip = change === null ? "" :
      '<span class="kpi-chg ' + (change >= 0 ? "up" : "down") + '">' +
      (change >= 0 ? "▲ +" : "▼ −") + Math.abs(change).toFixed(1) + " vs " +
      (card.cells.length > 1 ? card.cells[card.cells.length - 2].year : "") +
      "</span>";
    return '<button class="kpi band-' + card.band + '" data-vis="' + m.key +
      '" title="' + fmt.escapeHtml(m.title) + ' — click to visualise">' +
      '<span class="kpi-label">' + m.code + " · " +
      fmt.escapeHtml(TR.charts.clip(m.title, 44)) + "</span>" +
      '<span class="kpi-value">' + trk.fmtVal(last.value, true) +
      '<span class="kpi-type">' + card.type + "</span></span>" +
      chip + '<span class="kpi-spark">' + TR.render.sparkline(
        card.cells.map(function (c) {
          return { year: c.year, value: c.value, current: c.current };
        }), true, { w: 120, h: 26 }) + "</span></button>";
  }

  /* ---------------- pulse + significant changes ---------------- */

  function sigChanges() {
    var trk = TR.trk;
    var segs = [{ norm: "", label: "Total" }].concat(
      TR.waves.segments().map(function (s) {
        return { norm: s.norm, label: s.label };
      }));
    var out = [];
    trk.metricList("key").forEach(function (m) {
      if (m.isMean || m.diff) return;       // proportions only
      segs.forEach(function (seg) {
        var cells = trk.points(m, seg.norm || null);
        var last = lastCell(cells);
        if (!last || !last.sig_prev) return;
        out.push({ metric: m, segment: seg.label,
          change: last.change_prev, prev: cells[cells.length - 2],
          cur: last });
      });
    });
    out.sort(function (a, b) {
      if ((a.change >= 0) !== (b.change >= 0)) return a.change >= 0 ? -1 : 1;
      return Math.abs(b.change) - Math.abs(a.change);
    });
    return out;
  }

  function pulse(changes, nTested) {
    var up = changes.filter(function (c) {
      return c.segment === "Total" && c.change >= 0;
    }).length;
    var down = changes.filter(function (c) {
      return c.segment === "Total" && c.change < 0;
    }).length;
    return { up: up, down: down, stable: Math.max(nTested - up - down, 0) };
  }

  /* ---------------- significance heatmap ---------------- */

  function heatmapHtml() {
    var trk = TR.trk;
    var groups = TR.AGG.banner_groups.filter(function (g) {
      return TR.waves.segments().some(function (s) { return s.group === g.id; });
    });
    if (!groups.length) return "";
    var group = hmGroup || groups[0].id;
    var segs = TR.waves.segments().filter(function (s) { return s.group === group; });
    var metrics = trk.metricList("key").filter(function (m) {
      return !m.isMean && !m.diff;
    });
    var html = ['<div class="card"><div class="heathead"><h3>Latest wave change ' +
      "direction · metric × segment</h3>" +
      '<select data-hmgroup>' + groups.map(function (g) {
        return '<option value="' + g.id + '"' + (group === g.id ? " selected" : "") +
          ">" + fmt.escapeHtml(g.name) + "</option>";
      }).join("") + "</select></div>" +
      "<p class='trknote'>↑ / ↓ outlined = significant at 95% vs the previous " +
      "wave for that segment; → = no significant change; – = no history. " +
      "Click a metric to open it in the Segments view.</p>" +
      '<div class="trkwrap"><table class="moved trk hm"><thead><tr><th>Metric</th>' +
      "<th class='wv'>Total</th>" + segs.map(function (s) {
        return "<th class='wv'>" + fmt.escapeHtml(TR.charts.clip(s.label, 16)) + "</th>";
      }).join("") + "</tr></thead><tbody>"];
    metrics.slice(0, 60).forEach(function (m) {
      var cellsHtml = [null].concat(segs).map(function (seg) {
        var cells = trk.points(m, seg ? seg.norm : null);
        var last = lastCell(cells);
        if (!last || last.change_prev === null) return '<td class="wv none">–</td>';
        var cls = last.sig_prev ? (last.change_prev >= 0 ? "hm-up" : "hm-down") : "hm-flat";
        return '<td class="wv ' + cls + '" title="' +
          trk.fmtVal(last.value, false) + " (" +
          (last.change_prev >= 0 ? "+" : "−") + Math.abs(last.change_prev).toFixed(0) +
          "pp vs prev" + (last.sig_prev ? ", significant" : "") + ')">' +
          (last.sig_prev ? (last.change_prev >= 0 ? "↑" : "↓") : "→") + "</td>";
      }).join("");
      html.push('<tr><td class="lab"><button class="linklike" data-seg-metric="' +
        m.key + '">' + m.code + " · " +
        fmt.escapeHtml(TR.charts.clip(m.label, 34)) + "</button></td>" +
        cellsHtml + "</tr>");
    });
    html.push("</tbody></table></div></div>");
    return html.join("");
  }

  /* ---------------- render ---------------- */

  summary.render = function (host) {
    var trk = TR.trk;
    var cards = kpiCards();
    var changes = sigChanges();
    var tested = trk.metricList("key").filter(function (m) {
      return !m.isMean && !m.diff;
    }).length;
    var p = pulse(changes, tested);
    var shown = showAllSig ? changes : changes.slice(0, 24);
    var segOptions = {};
    changes.forEach(function (c) { segOptions[c.segment] = true; });

    var html = ['<div class="card"><h3>Key metric scorecard · ' +
      fmt.escapeHtml(TR.AGG.project.wave) + "</h3>" +
      "<p class='trknote'>Card colour bands the latest value against the " +
      "tracker thresholds (green strong / amber moderate / red weak per metric " +
      "type). Means, indexes and NPS scores show direction only — published " +
      "wave totals carry no spread, so only proportion metrics are " +
      "significance-tested.</p>" +
      '<div class="kpis">' + cards.map(kpiCardHtml).join("") + "</div></div>"];

    html.push('<div class="card"><div class="pulse">' +
      '<span class="pulse-chip up">▲ ' + p.up + " significant increases</span>" +
      '<span class="pulse-chip down">▼ ' + p.down + " significant decreases</span>" +
      '<span class="pulse-chip">→ ' + p.stable + " stable</span>" +
      '<span class="trknote">Total only · key proportion metrics · latest wave ' +
      "vs previous</span></div></div>");

    html.push('<div class="card"><div class="heathead"><h3>Significant changes · ' +
      "latest wave</h3><select data-sigseg><option value=''>All segments</option>" +
      Object.keys(segOptions).map(function (label) {
        return '<option value="' + fmt.escapeHtml(label) + '"' +
          (segFilter === label ? " selected" : "") + ">" +
          fmt.escapeHtml(label) + "</option>";
      }).join("") + "</select></div>" +
      (changes.length ? "" :
        "<p class='trknote'>No significant wave-on-wave changes.</p>") +
      '<div class="sigcards">' + shown.map(function (c) {
        return '<button class="sigcard ' + (c.change >= 0 ? "up" : "down") +
          '" data-vis="' + c.metric.key + '" data-seglabel="' +
          fmt.escapeHtml(c.segment) + '">' +
          '<span class="sig-dir">' + (c.change >= 0 ? "▲" : "▼") + " " +
          (c.change >= 0 ? "+" : "−") + Math.abs(c.change).toFixed(0) + "pp</span>" +
          '<span class="sig-metric">' + c.metric.code + " · " +
          fmt.escapeHtml(TR.charts.clip(c.metric.label, 30)) + "</span>" +
          '<span class="sig-detail">' + fmt.escapeHtml(c.segment) + " · " +
          trk.fmtVal(c.prev.value, false) + " (" + c.prev.year + ") → " +
          trk.fmtVal(c.cur.value, false) + "</span></button>";
      }).join("") + "</div>" +
      (changes.length > 24 && !showAllSig
        ? '<button class="linklike" data-sigmore>Show all ' + changes.length +
          " significant changes</button>" : "") + "</div>");

    html.push(heatmapHtml());
    host.innerHTML = html.join("");

    var applySegFilter = function () {
      host.querySelectorAll(".sigcard").forEach(function (el) {
        el.classList.toggle("hidden",
          !!segFilter && el.getAttribute("data-seglabel") !== segFilter);
      });
    };
    applySegFilter();
    host.querySelectorAll("[data-vis]").forEach(function (el) {
      el.addEventListener("click", function () {
        trk.state.metricKey = el.getAttribute("data-vis");
        trk.state.visSegs = null;
        trk.state.sub = "visualise";
        trk.rerender();
      });
    });
    host.querySelectorAll("[data-seg-metric]").forEach(function (el) {
      el.addEventListener("click", function () {
        trk.state.metricKey = el.getAttribute("data-seg-metric");
        trk.state.sub = "segments";
        trk.rerender();
      });
    });
    var sigSeg = host.querySelector("[data-sigseg]");
    if (sigSeg) {
      sigSeg.addEventListener("change", function () {
        segFilter = sigSeg.value;
        applySegFilter();
      });
    }
    var more = host.querySelector("[data-sigmore]");
    if (more) {
      more.addEventListener("click", function () {
        showAllSig = true;
        trk.rerender();
      });
    }
    var hmSel = host.querySelector("[data-hmgroup]");
    if (hmSel) {
      hmSel.addEventListener("change", function () {
        hmGroup = hmSel.value;
        trk.rerender();
      });
    }
  };

})(typeof window !== "undefined" ? window : globalThis);
