/**
 * v2 Tracking workspace — tracker-module parity over the wave history.
 * This file: the sub-tab shell (Summary | Explorer | Visualise) and the
 * shared tracking helpers (TR.trk). The Summary lives in 27u_summary.js;
 * the Explorer heatmap + Visualise live in 27v_visualise.js.
 *
 * KEY METRICS are evaluative only — questions carrying an Index / NPS /
 * Mean row contribute exactly that mean row plus their top-box NET (the
 * NET whose members sit highest on the scale), one heatmap row per
 * question, mirroring the tracker module's configured tracking specs.
 * Profile questions (campus, age, intake…) appear under "all tracked
 * rows" only.
 *
 * Tracking views always show PUBLISHED figures — current wave included —
 * so segment columns and history stay comparable; report-level filters
 * deliberately do not apply here (noted in the UI when active).
 *
 * SIZE-EXCEPTION: the workspace shell + shared data helpers used by all
 * tracking views; splitting them would scatter the metric contract.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var views = TR.views;
  var trk = TR.trk = {};

  /** Workspace state — survives tab switches (module scope, not DOM). */
  trk.state = {
    sub: "summary",
    explorerMode: "qfs",    // qfs = questions for segment, sfq = segments for question
    scope: null,            // "key" | "all" (Explorer mode A)
    segment: null,          // segment norm, null = Total (Explorer mode A)
    display: "abs",         // abs | prev | base (Explorer cell mode)
    expSort: "original",    // original | value | change
    expWaves: null,         // {year: bool} or null = all
    metricKey: null,        // Explorer mode B / Visualise context metric
    visSel: null,           // {metrics:[key], segs:[segNorm|"total"]} for Visualise
    visMode: "absolute", visCI: false, visLabels: "last", visWaves: null,
    yMin: null, yMax: null
  };

  /* ---------------- shared helpers (used by 27u/27v) ---------------- */

  trk.fmtVal = function (v, isMean) {
    if (v === null || v === undefined) return "–";
    return isMean ? (Math.round(v * 10) / 10).toString() : Math.round(v) + "%";
  };

  trk.years = function () {
    return TR.d2.tracking().waves.map(function (w) { return w.year; });
  };

  /* Wave-axis display. The year value is only a unique, ordered x-KEY (so
   * twice-yearly waves never collide); the label shown to users comes from the
   * wave's own name. Built once from the history waves + the current wave. */
  var yLabelMap = null;
  trk.currentWaveLabel = function () {
    // Use the full configured wave name (e.g. "Wave 25 - May 2026") so the
    // current wave matches the history labels ("Wave 22 - Oct 2024"). Previously
    // a /wave \d+/ extract dropped the date, truncating only the current wave.
    var w = ((TR.AGG.project && TR.AGG.project.wave) || "").trim();
    if (w) return w;
    var cy = TR.render.currentYear();
    return cy != null ? String(cy) : "Current";
  };
  trk.yLabel = function (y) {
    if (!yLabelMap) {
      yLabelMap = {};
      TR.d2.tracking().waves.forEach(function (w) {
        yLabelMap[w.year] = w.label || w.wave || String(w.year);
      });
      var cy = TR.render.currentYear();
      if (cy != null && yLabelMap[cy] === undefined) yLabelMap[cy] = trk.currentWaveLabel();
    }
    return yLabelMap[y] != null ? yLabelMap[y] : String(y);
  };

  var pubCache = {};
  /** Published, unfiltered model for a question under a banner group. */
  trk.publishedModel = function (code, group) {
    // Total-only reports have no banner groups — fall back to the Total column
    // ("") rather than assuming a first group exists.
    var grp = group ||
      (TR.AGG.banner_groups.length ? TR.AGG.banner_groups[0].id : "");
    var key = code + "::" + (grp || "default");
    if (!pubCache[key]) {
      pubCache[key] = TR.model.forQuestion(code, grp, [], { hiddenCols: [] });
    }
    return pubCache[key];
  };

  function metricEntry(q, model, row, ri) {
    return { key: q.code + "::" + ri, code: q.code, title: q.title,
      category: q.category, label: row.label, kind: row.kind,
      isMean: row.kind === "mean", diff: !!row.diff, ri: ri,
      q: TR.d2.questionByCode(q.code), row: row };
  }

  /** Top-box NET row index: the non-diff NET whose members sit highest. */
  function topNetIndex(q, model) {
    var best = -1, bestRank = -1;
    model.rows.forEach(function (row, ri) {
      if (row.kind !== "net" || row.diff) return;
      if (!row.waves || !row.waves.length) return;
      var members = q.net_members && q.net_members[String(ri)];
      if (!members || !members.length) return;
      var rank = Math.max.apply(null, members);
      if (rank > bestRank) { bestRank = rank; best = ri; }
    });
    return best;
  }

  var metricCache = {};
  /**
   * Tracked metrics. scope "key": evaluative questions only — the mean
   * row (Index/NPS/Mean) plus the top-box NET, in question order.
   * scope "all": every row with history on every tracked question.
   */
  trk.metricList = function (scope) {
    if (metricCache[scope]) return metricCache[scope];
    var out = [];
    TR.AGG.questions.forEach(function (q) {
      var model = trk.publishedModel(q.code, null);
      if (!model || !model.prevWave) return;
      if (scope === "key") {
        var hasMean = model.rows.some(function (r) { return r.kind === "mean"; });
        if (!hasMean) return;   // profile question — not a key metric
        model.rows.forEach(function (row, ri) {
          if (row.kind === "mean" && row.waves && row.waves.length) {
            out.push(metricEntry(q, model, row, ri));
          }
        });
        var top = topNetIndex(TR.d2.questionByCode(q.code), model);
        if (top >= 0) out.push(metricEntry(q, model, model.rows[top], top));
        return;
      }
      model.rows.forEach(function (row, ri) {
        if (!row.waves || !row.waves.length) return;
        out.push(metricEntry(q, model, row, ri));
      });
    });
    metricCache[scope] = out;
    return out;
  };

  /** Key proportion metrics: the top-box NET per evaluative question. */
  trk.keyNets = function () {
    return trk.metricList("key").filter(function (m) {
      return !m.isMean && !m.diff;
    });
  };

  trk.metricByKey = function (key) {
    return trk.metricList("all").filter(function (m) {
      return m.key === key;
    })[0] || null;
  };

  trk.newQuestions = function () {
    return TR.AGG.questions.filter(function (q) {
      var m = trk.publishedModel(q.code, null);
      return !m || !m.prevWave;
    });
  };

  trk.segmentByNorm = function (norm) {
    return TR.waves.segments().filter(function (s) {
      return s.norm === norm;
    })[0] || null;
  };

  /** Published CURRENT value of a metric for Total or a segment. */
  trk.currentFor = function (metric, segNorm) {
    if (!segNorm) {
      // Microdata waves: recompute the current point too, so the whole series
      // is one consistent model (full precision; sig holds without a published
      // distribution). The 1-dp display is unchanged.
      if (metric.isMean && !metric.diff) {
        var cp = TR.waves.currentPoint(metric.q);
        if (cp) return { value: cp.value, base: cp.base, x: null, effBase: cp.effBase };
      }
      var cell = metric.row.cells[0];
      var v = metric.isMean ? cell.mean : cell.pct;
      if (v === null || v === undefined) return null;
      var m0 = trk.publishedModel(metric.code, null).columns[0];
      return { value: v, base: m0.base,
        effBase: (m0.baseEff != null && m0.baseEff > 0) ? m0.baseEff : m0.base,
        x: cell.n !== null && cell.n !== undefined ? cell.n : null };
    }
    var seg = trk.segmentByNorm(segNorm);
    if (!seg) return null;
    var model = trk.publishedModel(metric.code, seg.group);
    if (!model) return null;
    var ci = -1;
    model.columns.forEach(function (col, i) {
      if (col.label === seg.label) ci = i;
    });
    if (ci < 0) return null;
    var segCell = model.rows[metric.ri] && model.rows[metric.ri].cells[ci];
    if (!segCell) return null;
    var value = metric.isMean ? segCell.mean : segCell.pct;
    if (value === null || value === undefined) return null;
    return { value: value, base: model.columns[ci].base,
      x: segCell.n !== null && segCell.n !== undefined ? segCell.n : null };
  };

  /**
   * SD of a mean-kind metric at one point (Total or a segment), derived
   * exactly from the published category distribution of that wave.
   * History waves read the wave payload; the current wave reads the
   * published model cells. null when not a mean or no distribution.
   */
  trk.sdAt = function (metric, segNorm, year) {
    if (!metric.isMean || metric.diff) return null;
    if (year !== TR.render.currentYear()) {
      var hit = TR.waves.history(metric.q).filter(function (h) {
        return h.year === year;
      })[0];
      return hit
        ? TR.waves.sdAtWave(metric.q, metric.row, hit.q, segNorm || null) : null;
    }
    // Current wave: prefer microdata (Total) — its SD powers the latest-wave
    // significance even when the published distribution is absent.
    if (!segNorm) {
      var curScores = TR.waves.currentScores(metric.q);
      if (curScores) return TR.waves.sdFromScores(curScores, TR.waves.currentWeights(metric.q));
    }
    var scores = TR.waves.scoreMap(metric.q, metric.row);
    if (!scores) return null;
    var ci = 0, model;
    if (segNorm) {
      var seg = trk.segmentByNorm(segNorm);
      if (!seg) return null;
      model = trk.publishedModel(metric.code, seg.group);
      ci = -1;
      model.columns.forEach(function (col, i) {
        if (col.label === seg.label) ci = i;
      });
      if (ci < 0) return null;
    } else {
      model = trk.publishedModel(metric.code, null);
    }
    var pairs = [];
    Object.keys(scores).forEach(function (ri) {
      var cell = model.rows[ri] && model.rows[ri].cells[ci];
      if (cell && cell.pct !== null && cell.pct !== undefined) {
        pairs.push({ p: cell.pct, s: scores[ri] });
      }
    });
    return TR.waves.sdFromPairs(pairs);
  };

  /**
   * Full tracker-shaped point list for a metric in a segment (or Total):
   * history series + the current wave, each with change/sig vs previous
   * point and vs the first point — pooled z for proportions, Welch on
   * distribution-derived SDs for means/indexes/NPS. [] when no history.
   */
  trk.points = function (metric, segNorm) {
    var series = TR.waves.series(metric.q, metric.row, metric.ri, segNorm || null);
    if (!series.length) return [];
    var canSig = !metric.isMean && !metric.diff;
    var cur = trk.currentFor(metric, segNorm);
    var points = series.slice();
    if (cur) {
      points.push({ wave: TR.AGG.project.wave, year: TR.render.currentYear(),
        value: cur.value, base: cur.base, effBase: cur.effBase,
        x: canSig ? (cur.x !== null ? cur.x
          : Math.round(cur.value / 100 * (cur.base || 0))) : null,
        sd: metric.isMean && !metric.diff
          ? trk.sdAt(metric, segNorm, TR.render.currentYear()) : undefined,
        current: true });
    }
    // honour the report's significance setting (off / 95% / 95%+80%): "dual"
    // adds soft_prev/soft_base, "off" suppresses all sig flags.
    return TR.waves.cellsFor(points, canSig, TR.d2.state.sigMode);
  };

  /* ---- thresholds + cell colouring (tracker defaults, overridable) ---- */

  var THRESHOLDS = { pct: { green: 70, amber: 50 },
    index: { green: 70, amber: 50 }, mean: { green: 7, amber: 5 },
    nps: { green: 30, amber: 0 } };

  trk.kpiType = function (metric) {
    if (!metric.isMean) return "pct";
    var label = TR.model.norm(metric.label);
    if (label.indexOf("nps") !== -1) return "nps";
    if (label === "mean") return "mean";
    return "index";
  };

  trk.thresholds = function (type) {
    var cfg = (TR.AGG.project.tracking || {}).thresholds || {};
    return cfg[type] || THRESHOLDS[type] || THRESHOLDS.pct;
  };

  trk.band = function (type, value) {
    if (value === null || value === undefined) return "";
    var t = trk.thresholds(type);
    return value >= t.green ? "g" : value >= t.amber ? "a" : "r";
  };

  /** Signed change text: "+20pp" / "−1.3" ("" when not computable). */
  trk.changeText = function (change, isMean) {
    if (change === null || change === undefined) return "";
    return (change >= 0 ? "+" : "−") +
      Math.abs(change).toFixed(isMean ? 1 : 0) + (isMean ? "" : "pp");
  };

  /* ---------------- shell ---------------- */

  var SUBS = [["summary", "Summary"], ["explorer", "Explorer"],
    ["visualise", "Visualise"]];

  views.whatMoved = function (host) {
    if (!TR.d2.tracking().enabled) {
      host.innerHTML = '<div class="page"><div class="card"><h2>Tracking</h2>' +
        "<p>No wave history is configured, so there is nothing to track. With " +
        "history supplied (one wave or many), this workspace provides the " +
        "summary, explorer and visualise tracking views.</p></div></div>";
      return;
    }
    // migrate pre-round-6 state
    if (trk.state.sub === "metrics" || trk.state.sub === "segments") {
      trk.state.explorerMode = trk.state.sub === "segments" ? "sfq" : "qfs";
      trk.state.sub = "explorer";
    }
    var wrap = document.createElement("div");
    var years = trk.years();
    wrap.innerHTML = '<div class="page"><div class="trkbar">' +
      "<h2>Tracking · " + years[0] + "–" + TR.render.currentYear() + "</h2>" +
      '<nav class="trksubs">' + SUBS.map(function (s) {
        return '<button class="btab' + (trk.state.sub === s[0] ? " on" : "") +
          '" data-sub="' + s[0] + '">' + s[1] + "</button>";
      }).join("") + "</nav>" +
      (TR.d2.filtersActive()
        ? '<span class="trkfilternote">⚠ report filters do not apply here — ' +
          "tracking always compares published figures</span>" : "") +
      "</div><div id='trkhost'></div>" +
      TR.conf.calloutHtml() + "</div>";
    host.replaceChildren(wrap);
    wrap.querySelectorAll("[data-sub]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk.state.sub = btn.getAttribute("data-sub");
        views.whatMoved(host);
      });
    });
    // the shared confidence explainer (fresh wrapper -> no stacked handlers)
    var callout = wrap.querySelector("[data-callout]");
    if (callout) {
      callout.addEventListener("click", function () {
        callout.closest(".callout").classList.toggle("collapsed");
      });
    }
    var sub = document.getElementById("trkhost");
    if (trk.state.sub === "explorer") TR.trkVis.renderExplorer(sub);
    else if (trk.state.sub === "visualise") TR.trkVis.renderVisualise(sub);
    else TR.trkSummary.render(sub);
  };

  /** Re-render the active sub-view in place (state already updated). */
  trk.rerender = function () {
    views.whatMoved(document.getElementById("tabhost"));
  };

})(typeof window !== "undefined" ? window : globalThis);
