/**
 * Tracking Segments + Visualise views — the tracker explorer rebuilt on
 * published wave history. Segments: one metric across Total + every
 * tracked banner segment (column-per-wave, sparkline, Δs, checkboxes).
 * Visualise: the selected metric × segments as a multi-series wave chart
 * with display modes (absolute / vs previous / vs baseline), optional 95%
 * CI bands (proportions, from published bases), value-label modes, wave
 * chips, y-axis override, low-base warnings, a per-view insight note,
 * Excel export and pin-to-story (native two-chart exhibit).
 *
 * SIZE-EXCEPTION: one explorer workflow (pick segments -> visualise);
 * the selection, transform and rendering share the metric context.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var vis = TR.trkVis = {};

  function trk() { return TR.trk; }

  function metricOptions(selected) {
    return trk().metricList("key").map(function (m) {
      return '<option value="' + m.key + '"' +
        (selected === m.key ? " selected" : "") + ">" + m.code + " · " +
        fmt.escapeHtml(TR.charts.clip(m.title, 40)) + " — " +
        fmt.escapeHtml(TR.charts.clip(m.label, 24)) + "</option>";
    }).join("");
  }

  function contextMetric() {
    var m = trk().metricByKey(trk().state.metricKey);
    return m || trk().metricList("key")[0] || null;
  }

  /** Rows of the segment table: Total first, then every tracked segment. */
  function segEntries(metric) {
    var rows = [{ norm: "", label: "Total" }].concat(
      TR.waves.segments().map(function (s) {
        return { norm: s.norm, label: s.label };
      }));
    return rows.map(function (seg) {
      var cells = trk().points(metric, seg.norm || null);
      return { seg: seg, cells: cells,
        last: cells.length && cells[cells.length - 1].current
          ? cells[cells.length - 1] : null };
    }).filter(function (e) { return e.cells.length > 1; });
  }

  /* ---------------- Segments view (one metric across segments) ---------- */

  vis.renderSegments = function (host) {
    var metric = contextMetric();
    if (!metric) { host.innerHTML = ""; return; }
    trk().state.metricKey = metric.key;
    var years = trk().years();
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var entries = segEntries(metric);
    var selected = trk().state.visSegs || ["total"];

    var html = ['<div class="card trkcard"><div class="heathead">' +
      "<h3>Segments · one metric across every tracked segment</h3>" +
      '<select data-trkmetric>' + metricOptions(metric.key) + "</select></div>" +
      "<p class='trknote'>Published values per wave. Tick segments and open " +
      "Visualise to chart them together; segment coverage varies by wave " +
      "(– = the wave was published without that segment).</p>" +
      '<div class="trkwrap"><table class="moved trk"><thead><tr><th></th>' +
      "<th>Segment</th>" + years.map(function (y) {
        return "<th class='wv'>" + y + "</th>";
      }).join("") + "<th class='wv'>" + TR.render.currentYear() +
      "</th><th>Trend</th><th>Δ prev</th><th>Δ first</th></tr></thead><tbody>"];
    entries.forEach(function (e) {
      var byYear = {};
      e.cells.forEach(function (c) { if (!c.current) byYear[c.year] = c; });
      var id = e.seg.norm || "total";
      var cells = ['<td><input type="checkbox" data-segpick="' + id + '"' +
        (selected.indexOf(id) !== -1 ? " checked" : "") + "></td>",
        "<td>" + fmt.escapeHtml(e.seg.label) + "</td>"];
      years.forEach(function (y) {
        var c = byYear[y];
        var low = c && c.base !== null && c.base < threshold;
        cells.push(c
          ? '<td class="wv' + (low ? " lowb" : "") + '" title="' + y +
            " base n=" + fmt.base(c.base) + '">' +
            trk().fmtVal(c.value, metric.isMean) + (low ? " ⚠" : "") + "</td>"
          : '<td class="wv none">–</td>');
      });
      cells.push('<td class="wv cur">' +
        (e.last ? trk().fmtVal(e.last.value, metric.isMean) : "–") + "</td>");
      cells.push('<td class="sparkcell">' + TR.render.sparkline(
        e.cells.map(function (c) {
          return { year: c.year, value: c.value, current: c.current };
        }), metric.isMean) + "</td>");
      ["change_prev", "change_base"].forEach(function (key) {
        var change = e.last ? e.last[key] : null;
        var sig = e.last ? e.last[key === "change_prev" ? "sig_prev" : "sig_base"] : false;
        cells.push(change === null || change === undefined
          ? '<td class="wv dnone">–</td>'
          : '<td class="wv ' + (change >= 0 ? "up" : "down") + (sig ? " dsig" : "") +
            '">' + (change >= 0 ? "▲ +" : "▼ −") +
            Math.abs(change).toFixed(metric.isMean ? 1 : 0) +
            (metric.isMean ? "" : "pp") + "</td>");
      });
      html.push("<tr>" + cells.join("") + "</tr>");
    });
    html.push("</tbody></table></div>" +
      '<div class="scopebar"><button class="primary" data-tovis>Visualise ' +
      "selection →</button></div></div>");
    host.innerHTML = html.join("");

    host.querySelector("[data-trkmetric]").addEventListener("change", function (e) {
      trk().state.metricKey = e.target.value;
      trk().state.visSegs = null;
      trk().rerender();
    });
    host.querySelector("[data-tovis]").addEventListener("click", function () {
      var picked = Array.prototype.slice.call(
        host.querySelectorAll("[data-segpick]:checked")).map(function (el) {
          return el.getAttribute("data-segpick");
        });
      trk().state.visSegs = picked.length ? picked : ["total"];
      trk().state.sub = "visualise";
      trk().rerender();
    });
  };

  /* ---------------- Visualise view ---------------- */

  function ciHalfWidth(metric, point) {
    if (metric.isMean || metric.diff) return null;       // no published spread
    if (!point.base || point.value === null) return null;
    var p = Math.min(Math.max(point.value / 100, 0.001), 0.999);
    return 1.96 * Math.sqrt(p * (1 - p) / point.base) * 100;
  }

  /** Selected segment series transformed for the active display mode. */
  function visSeries(metric, mode, yearSet) {
    var ids = trk().state.visSegs || ["total"];
    return ids.map(function (id) {
      var seg = id === "total" ? null : trk().segmentByNorm(id);
      if (id !== "total" && !seg) return null;
      var cells = trk().points(metric, id === "total" ? null : id);
      if (!cells.length) return null;
      var points = cells.map(function (c, i) {
        var value = c.value;
        if (mode === "prev") value = c.change_prev;
        if (mode === "base") value = i === 0 ? null : c.change_base;
        if (value === null || value === undefined) return null;
        return { wave: c.wave, year: c.year, value: value, base: c.base,
          current: c.current, cell: c };
      }).filter(Boolean).filter(function (p) {
        return !yearSet || yearSet[p.year];
      });
      return { id: id, label: seg ? seg.label : "Total", points: points,
        cells: cells };
    }).filter(Boolean).filter(function (s) { return s.points.length; });
  }

  vis.renderVisualise = function (host) {
    var s = trk().state;
    var metric = contextMetric();
    if (!metric) { host.innerHTML = ""; return; }
    trk().state.metricKey = metric.key;
    var mode = s.visMode || "absolute";
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var allYears = trk().years().concat([TR.render.currentYear()]);
    var yearSet = s.visWaves;
    var series = visSeries(metric, mode === "absolute" ? "absolute" : mode, yearSet);

    // pseudo-model rows: one per segment, current point embedded in waves
    var pseudo = { code: metric.code, title: metric.title, source: "published",
      chartKind: "summary", lowBaseThreshold: threshold,
      columns: [{ label: "Total", letter: "", base: null, low: false }],
      rows: series.map(function (sr) {
        return { kind: mode === "absolute" ? metric.kind : "net",
          diff: metric.diff, label: sr.label, waves: sr.points,
          cells: [{ pct: null, mean: null, n: null, sig: "" }] };
      }) };
    var chart = TR.render.trendChart(pseudo, {
      yMin: s.yMin, yMax: s.yMax, labels: s.visLabels || "last",
      ci: (mode === "absolute" && s.visCI) ? function (row, point) {
        return ciHalfWidth(metric, point);
      } : null,
      note: (mode === "absolute" ? "Published values" :
        mode === "prev" ? "Change vs previous wave (pp)" :
        "Change vs baseline wave (pp)") + " · " + fmt.escapeHtml(metric.label)
    });

    var lowPoints = [];
    series.forEach(function (sr) {
      sr.cells.forEach(function (c) {
        if (c.base !== null && c.base < threshold) {
          lowPoints.push(sr.label + " " + c.year + " (n=" + c.base + ")");
        }
      });
    });

    var modeBtn = function (id, label) {
      return '<button class="btab' + (mode === id ? " on" : "") +
        '" data-vismode="' + id + '">' + label + "</button>";
    };
    var html = ['<div class="card trkcard"><div class="heathead">' +
      "<h3>Visualise · " + metric.code + " · " +
      fmt.escapeHtml(TR.charts.clip(metric.label, 40)) + "</h3>" +
      '<select data-trkmetric>' + metricOptions(metric.key) + "</select></div>" +
      '<div class="scopebar">' + modeBtn("absolute", "Absolute") +
      modeBtn("prev", "vs Previous") + modeBtn("base", "vs Baseline") +
      '<label class="tg"><input type="checkbox" data-visci' +
      (s.visCI ? " checked" : "") + (mode !== "absolute" || metric.isMean
        ? " disabled" : "") + "> 95% CI bands</label>" +
      '<label class="tg">Labels <select data-vislabels>' +
      ["last", "all", "none"].map(function (l) {
        return '<option value="' + l + '"' +
          ((s.visLabels || "last") === l ? " selected" : "") + ">" + l + "</option>";
      }).join("") + "</select></label>" +
      '<label class="tg">Y <input type="number" data-ymin placeholder="min" value="' +
      (s.yMin === null || s.yMin === undefined ? "" : s.yMin) + '">–' +
      '<input type="number" data-ymax placeholder="max" value="' +
      (s.yMax === null || s.yMax === undefined ? "" : s.yMax) + '">' +
      '<button data-yreset title="Auto scale">↺</button></label>' +
      '<span class="ctl-spacer"></span>' +
      '<button data-visexcel>Excel</button>' +
      '<button class="primary" data-vispin>📌 Pin to story</button></div>' +
      '<div class="scopebar wavechips">' + allYears.map(function (y) {
        var on = !yearSet || yearSet[y];
        return '<button class="btab' + (on ? " on" : "") + '" data-wavechip="' +
          y + '">' + y + "</button>";
      }).join("") + '<button class="linklike" data-waveall>all</button></div>' +
      '<div class="chart">' + (chart ||
        '<div class="chart-error">No data for this selection.</div>') + "</div>"];

    // table: per segment, value per wave (+ change sub-rows in absolute mode)
    var shownYears = allYears.filter(function (y) {
      return !yearSet || yearSet[y];
    });
    html.push('<div class="trkwrap"><table class="moved trk"><thead><tr>' +
      "<th>Series</th>" + shownYears.map(function (y) {
        return "<th class='wv'>" + y + "</th>";
      }).join("") + "</tr></thead><tbody>");
    series.forEach(function (sr) {
      var byYear = {};
      sr.cells.forEach(function (c) { byYear[c.year] = c; });
      var row = ["<td class='lab'>" + fmt.escapeHtml(sr.label) + "</td>"];
      var prevRow = ["<td class='lab sub'>vs previous</td>"];
      var baseRow = ["<td class='lab sub'>vs baseline</td>"];
      shownYears.forEach(function (y) {
        var c = byYear[y];
        if (!c) {
          row.push('<td class="wv none">–</td>');
          prevRow.push('<td class="wv none"></td>');
          baseRow.push('<td class="wv none"></td>');
          return;
        }
        var low = c.base !== null && c.base < threshold;
        row.push('<td class="wv' + (c.current ? " cur" : "") +
          (low ? " lowb" : "") + '" title="base n=' + fmt.base(c.base) + '">' +
          trk().fmtVal(c.value, metric.isMean) + (low ? " ⚠" : "") + "</td>");
        var chg = function (change, sig) {
          if (change === null || change === undefined) return '<td class="wv"></td>';
          return '<td class="wv sub ' + (change >= 0 ? "up" : "down") +
            (sig ? " dsig" : "") + '">' + (change >= 0 ? "+" : "−") +
            Math.abs(change).toFixed(metric.isMean ? 1 : 0) + "</td>";
        };
        prevRow.push(chg(c.change_prev, c.sig_prev));
        baseRow.push(chg(c.change_base, c.sig_base));
      });
      html.push("<tr>" + row.join("") + "</tr>");
      html.push('<tr class="subrow">' + prevRow.join("") + "</tr>");
      html.push('<tr class="subrow">' + baseRow.join("") + "</tr>");
    });
    html.push("</tbody></table></div>");
    if (lowPoints.length) {
      html.push('<p class="trknote">⚠ Low bases (&lt;' + threshold +
        ", excluded from significance): " +
        fmt.escapeHtml(lowPoints.slice(0, 8).join("; ")) +
        (lowPoints.length > 8 ? " +" + (lowPoints.length - 8) + " more" : "") +
        "</p>");
    }
    html.push('<div class="insight"><div class="insight-head">Analyst insight · ' +
      "tracking</div><textarea data-visnote placeholder=\"Insight for this trend " +
      'view… (saved locally, exported with insights JSON)">' +
      fmt.escapeHtml(TR.insights.get(metric.code, "tracking") || "") +
      "</textarea></div></div>");
    host.innerHTML = html.join("");

    /* ---- wiring ---- */
    host.querySelector("[data-trkmetric]").addEventListener("change", function (e) {
      trk().state.metricKey = e.target.value;
      trk().state.visSegs = null;
      trk().rerender();
    });
    host.querySelectorAll("[data-vismode]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk().state.visMode = btn.getAttribute("data-vismode");
        trk().rerender();
      });
    });
    var ci = host.querySelector("[data-visci]");
    if (ci) ci.addEventListener("change", function () {
      trk().state.visCI = ci.checked;
      trk().rerender();
    });
    host.querySelector("[data-vislabels]").addEventListener("change", function (e) {
      trk().state.visLabels = e.target.value;
      trk().rerender();
    });
    var applyY = function () {
      var lo = parseFloat(host.querySelector("[data-ymin]").value);
      var hi = parseFloat(host.querySelector("[data-ymax]").value);
      trk().state.yMin = isNaN(lo) ? null : lo;
      trk().state.yMax = isNaN(hi) ? null : hi;
      trk().rerender();
    };
    host.querySelector("[data-ymin]").addEventListener("change", applyY);
    host.querySelector("[data-ymax]").addEventListener("change", applyY);
    host.querySelector("[data-yreset]").addEventListener("click", function () {
      trk().state.yMin = trk().state.yMax = null;
      trk().rerender();
    });
    host.querySelectorAll("[data-wavechip]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var year = parseInt(btn.getAttribute("data-wavechip"), 10);
        var set = trk().state.visWaves;
        if (!set) {
          set = {};
          allYears.forEach(function (y) { set[y] = true; });
        }
        set[year] = !set[year];
        trk().state.visWaves = set;
        trk().rerender();
      });
    });
    host.querySelector("[data-waveall]").addEventListener("click", function () {
      trk().state.visWaves = null;
      trk().rerender();
    });
    host.querySelector("[data-visexcel]").addEventListener("click", function () {
      var head = ["Series"].concat(shownYears.map(String));
      var rows = [];
      series.forEach(function (sr) {
        var byYear = {};
        sr.cells.forEach(function (c) { byYear[c.year] = c; });
        rows.push([sr.label].concat(shownYears.map(function (y) {
          return byYear[y] ? byYear[y].value : "";
        })));
        rows.push([sr.label + " · base"].concat(shownYears.map(function (y) {
          return byYear[y] ? byYear[y].base : "";
        })));
      });
      TR.xlsx.download(metric.code + "_trend", "Trend", [head].concat(rows));
    });
    host.querySelector("[data-vispin]").addEventListener("click", function () {
      TR.story2.pinTrackingView(metric, trk().state.visSegs || ["total"]);
    });
    host.querySelector("[data-visnote]").addEventListener("input", function (e) {
      TR.insights.set(metric.code, e.target.value, "tracking");
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
