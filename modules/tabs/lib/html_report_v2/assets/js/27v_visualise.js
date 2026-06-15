/**
 * Tracking Explorer + Visualise — the tracker module's explorer UX on the
 * published wave history.
 *
 * Explorer = the overview heatmap with two modes:
 *   Questions for segment — every key (or all) tracked metric for one
 *     segment, value-in-cell with green/amber/red threshold colouring;
 *     tick several metrics -> Visualise overlays them for that segment.
 *   Segments for question — one metric across Total + every tracked
 *     segment; tick segments -> Visualise overlays them for that metric.
 * Both share display modes (Absolute / vs Previous / vs Baseline — change
 * cells colour only when significant), sort, wave chips, a legend and
 * Excel export.
 *
 * Visualise = the ticked selection as a multi-series wave chart with CI
 * bands, data-point ANNOTATIONS (click a point to tag it — "Campaign
 * launched"), value-label modes, wave chips, y-axis override, low-base
 * warnings, a colour-keyed series table with optional change rows, an
 * insight note, Excel, and a pin popover that chooses WHICH elements to
 * pin (this-wave chart / trend / table / insight) before pinning.
 *
 * SIZE-EXCEPTION: one explorer workflow (heatmap -> selection ->
 * visualise -> pin); the selection model is shared throughout.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var vis = TR.trkVis = {};
  var MAX_ROWS = 250;
  var MAX_SERIES = 6;

  function trk() { return TR.trk; }

  function lastOf(cells) {
    return cells.length && cells[cells.length - 1].current
      ? cells[cells.length - 1] : null;
  }

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

  /* ---------------- the Visualise selection model ---------------- */

  /** {metrics: [metricKey], segs: [segId]} — one side is usually 1. */
  function selection() {
    var s = trk().state;
    if (!s.visSel || !s.visSel.metrics || !s.visSel.metrics.length) {
      var m = contextMetric();
      s.visSel = { metrics: m ? [m.key] : [], segs: ["total"] };
    }
    return s.visSel;
  }

  /** Cross product of the selection, capped: [{metric, segId, segLabel}]. */
  function seriesSpecs(sel) {
    var specs = [];
    sel.metrics.forEach(function (mk) {
      var m = trk().metricByKey(mk);
      if (!m) return;
      sel.segs.forEach(function (segId) {
        var seg = segId === "total" ? null : trk().segmentByNorm(segId);
        if (segId !== "total" && !seg) return;
        specs.push({ metric: m, segId: segId,
          segLabel: seg ? seg.label : "Total" });
      });
    });
    return specs.slice(0, MAX_SERIES);
  }

  function specLabel(spec, sel) {
    if (sel.metrics.length > 1) {
      // question TEXT, not the code — codes are meaningless on a chart.
      // No display clipping: the chart legend wraps and the table cells
      // wrap; the bound below only guards against degenerate data.
      return TR.charts.clip(spec.metric.title, 300) + " · " +
        TR.charts.clip(spec.metric.label, 120) +
        (sel.segs.length > 1 ? " · " + spec.segLabel : "");
    }
    return spec.segLabel;
  }

  function visTitle(sel, specs) {
    if (sel.metrics.length === 1 && specs.length) {
      var m = specs[0].metric;
      return m.code + " · " + TR.charts.clip(m.title, 60) + " — " +
        TR.charts.clip(m.label, 28) +
        (sel.segs.length > 1 ? " · " + sel.segs.length + " segments"
          : " · " + specs[0].segLabel);
    }
    return sel.metrics.length + " metrics · " +
      (specs.length ? specs[0].segLabel : "");
  }

  /* ---------------- shared explorer pieces ---------------- */

  function activeYears() {
    var all = trk().years().concat([TR.render.currentYear()]);
    var set = trk().state.expWaves;
    return all.filter(function (y) { return !set || set[y]; });
  }

  function waveChipsHtml() {
    var all = trk().years().concat([TR.render.currentYear()]);
    var set = trk().state.expWaves;
    return '<div class="scopebar wavechips"><span class="trknote">Waves:</span>' +
      all.map(function (y) {
        var on = !set || set[y];
        return '<button class="btab' + (on ? " on" : "") + '" data-wavechip="' +
          y + '">' + trk().yLabel(y) + "</button>";
      }).join("") +
      '<button class="linklike" data-waveall>all</button>' +
      '<button class="linklike" data-wavelast>last 3</button></div>';
  }

  function legendHtml() {
    return '<div class="trklegend"><span class="lg cb-g">strong · ≥70% / 7+ ' +
      "mean / 30+ NPS</span><span class='lg cb-a'>moderate</span>" +
      "<span class='lg cb-r'>weak</span>" +
      "<span class='lg'>▲▼ coloured = significant at 95% vs the comparison " +
      "wave — pooled z for %, Welch on published-distribution SDs for " +
      "means/indexes/NPS</span><span class='lg'>⚠ base under " +
      (TR.AGG.project.low_base_threshold || 30) + "</span></div>";
  }

  function displayChips(display) {
    return [["abs", "Absolute"], ["prev", "vs Previous"], ["base", "vs Baseline"]]
      .map(function (d) {
        return '<button class="btab' + (display === d[0] ? " on" : "") +
          '" data-display="' + d[0] + '">' + d[1] + "</button>";
      }).join("");
  }

  /** One wave cell: value + threshold colour, or change + sig colour. */
  function waveCell(metric, c, display, threshold) {
    if (!c) return '<td class="wv none">–</td>';
    var low = c.base !== null && c.base < threshold;
    if (display === "abs") {
      var band = trk().band(trk().kpiType(metric), c.value);
      return '<td class="wv cb-' + band + (c.current ? " curw" : "") +
        '" title="base n=' + fmt.base(c.base) +
        (low ? " — below threshold, excluded from significance" : "") + '">' +
        trk().fmtVal(c.value, metric.isMean) + (low ? " ⚠" : "") + "</td>";
    }
    var change = display === "prev" ? c.change_prev : c.change_base;
    var sig = display === "prev" ? c.sig_prev : c.sig_base;
    var soft = display === "prev" ? c.soft_prev : c.soft_base;
    if (change === null || change === undefined) {
      return '<td class="wv none">·</td>';
    }
    var dir = change >= 0;
    var cls = sig ? (dir ? "hm-up" : "hm-down")
      : soft ? (dir ? "hm-up soft" : "hm-down soft") : "chg";
    var mark = sig ? (dir ? "▲" : "▼") : soft ? (dir ? "△" : "▽") : "";
    return '<td class="wv ' + cls +
      '" title="' + trk().fmtVal(c.value, metric.isMean) + " in " + c.year +
      (sig ? " · significant at 95%"
        : soft ? " · significant at 80% (not 95%)" : "") + '">' +
      mark + trk().changeText(change, metric.isMean).replace("pp", "") + "</td>";
  }

  function changeChip(last, isMean) {
    if (!last || last.change_prev === null) return '<td class="wv dnone">–</td>';
    return '<td class="wv ' + (last.change_prev >= 0 ? "up" : "down") +
      (last.sig_prev ? " dsig" : last.soft_prev ? " dsig soft" : "") +
      '" title="latest vs previous wave' +
      (last.sig_prev ? " · significant at 95%"
        : last.soft_prev ? " · significant at 80% (not 95%)" : "") + '">' +
      (last.change_prev >= 0 ? "▲ +" : "▼ −") +
      Math.abs(last.change_prev).toFixed(isMean ? 1 : 0) +
      (isMean ? "" : "pp") + "</td>";
  }

  function sparkCell(cells, isMean) {
    return '<td class="sparkcell">' + TR.render.sparkline(
      cells.map(function (c) {
        return { year: c.year, value: c.value, current: c.current };
      }), isMean) + "</td>";
  }

  function applySort(entries) {
    var mode = trk().state.expSort;
    if (mode === "value") {
      entries.sort(function (a, b) {
        return ((b.last && b.last.value) || -1e9) - ((a.last && a.last.value) || -1e9);
      });
    } else if (mode === "change") {
      // rank strong (95%) above soft (80%) above direction-only; soft_prev is
      // always false outside dual mode, so this is unchanged there.
      var rank = function (x) {
        return x && x.last ? (x.last.sig_prev ? 2 : x.last.soft_prev ? 1 : 0) : 0;
      };
      entries.sort(function (a, b) {
        if (rank(a) !== rank(b)) return rank(b) - rank(a);
        return Math.abs((b.last && b.last.change_prev) || 0) -
          Math.abs((a.last && a.last.change_prev) || 0);
      });
    }
    return entries;
  }

  function exportExplorer(rows, years, name) {
    var head = ["Metric"].concat(years.map(String)).concat(["Δ prev"]);
    var body = rows.map(function (e) {
      var byYear = {};
      e.cells.forEach(function (c) { byYear[c.year] = c; });
      return [e.exportLabel].concat(years.map(function (y) {
        return byYear[y] ? byYear[y].value : "";
      })).concat([e.last && e.last.change_prev !== null
        ? e.last.change_prev : ""]);
    });
    TR.xlsx.download(name, "Tracking", [head].concat(body));
  }

  /* ---------------- Explorer ---------------- */

  vis.renderExplorer = function (host) {
    var s = trk().state;
    var mode = s.explorerMode || "qfs";
    var display = s.display || "abs";
    var years = activeYears();
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var html = ['<div class="card trkcard">'];

    html.push('<div class="scopebar">' +
      '<button class="btab' + (mode === "qfs" ? " on" : "") +
      '" data-expmode="qfs">Questions for segment</button>' +
      '<button class="btab' + (mode === "sfq" ? " on" : "") +
      '" data-expmode="sfq">Segments for question</button>' +
      '<span class="ctl-spacer"></span>' + displayChips(display) +
      '<select data-expsort>' +
      [["original", "Original order"], ["value", "Current value"],
        ["change", "Largest change"]].map(function (o) {
          return '<option value="' + o[0] + '"' +
            (s.expSort === o[0] ? " selected" : "") + ">" + o[1] + "</option>";
        }).join("") + "</select>" +
      '<button class="t-btn" data-expexcel>Excel</button></div>');

    var entries, exportName, pickAttr;
    if (mode === "qfs") {
      var scope = s.scope || "key";
      var segments = TR.waves.segments();
      html.push('<div class="scopebar">' +
        '<label class="tg">Segment <select data-trkseg>' +
        '<option value="">Total</option>' + segments.map(function (seg) {
          return '<option value="' + seg.norm + '"' +
            (s.segment === seg.norm ? " selected" : "") + ">" +
            fmt.escapeHtml(seg.label) + " (" + seg.years[0] + "–" +
            seg.years[seg.years.length - 1] + ")</option>";
        }).join("") + "</select></label>" +
        '<button class="btab' + (scope === "key" ? " on" : "") +
        '" data-scope="key">Key metrics</button>' +
        '<button class="btab' + (scope === "all" ? " on" : "") +
        '" data-scope="all">All tracked rows</button>' +
        '<input id="trk-search" type="search" placeholder="Search metrics…">' +
        '<button class="primary" data-tovis>Visualise ticked (or click a ' +
        "metric) →</button></div>");
      entries = trk().metricList(scope).map(function (m) {
        var cells = trk().points(m, s.segment);
        return { metric: m, cells: cells, last: lastOf(cells),
          exportLabel: m.code + " " + m.title + " — " + m.label };
      }).filter(function (e) { return e.cells.length; });
      exportName = "tracking_" + (s.segment || "total");
      pickAttr = function (e) { return e.metric.key; };
    } else {
      var metric = contextMetric();
      if (!metric) { host.innerHTML = ""; return; }
      trk().state.metricKey = metric.key;
      html.push('<div class="scopebar"><label class="tg">Metric ' +
        '<select data-trkmetric>' + metricOptions(metric.key) +
        "</select></label>" +
        '<button class="primary" data-tovis>Visualise ticked →</button></div>');
      var segRows = [{ norm: "", label: "Total" }].concat(
        TR.waves.segments().map(function (x) {
          return { norm: x.norm, label: x.label };
        }));
      entries = segRows.map(function (seg) {
        var cells = trk().points(metric, seg.norm || null);
        return { metric: metric, seg: seg, cells: cells, last: lastOf(cells),
          exportLabel: seg.label };
      }).filter(function (e) { return e.cells.length > 1; });
      exportName = metric.code + "_segments";
      pickAttr = function (e) { return e.seg.norm || "total"; };
    }
    applySort(entries);

    html.push(waveChipsHtml());
    html.push('<div class="trkwrap"><table class="moved trk haspick"><thead><tr>' +
      "<th></th>" + (mode === "sfq" ? "<th>Segment</th>" : "<th>Metric</th>") +
      years.map(function (y) {
        return "<th class='wv'>" + trk().yLabel(y) + "</th>";
      }).join("") + "<th>Trend</th><th>Δ prev</th></tr></thead><tbody>");

    var rowHtml = function (e, labelCell) {
      var byYear = {};
      e.cells.forEach(function (c) { byYear[c.year] = c; });
      return "<tr" + (mode === "qfs" ? ' data-cat="' +
        fmt.escapeHtml(e.metric.category) + '" data-search="' +
        fmt.escapeHtml((e.metric.code + " " + e.metric.title + " " +
          e.metric.label).toLowerCase()) + '"' : "") + ">" +
        '<td><input type="checkbox" data-pick="' + fmt.escapeHtml(pickAttr(e)) +
        '"></td>' + labelCell +
        years.map(function (y) {
          return waveCell(e.metric, byYear[y], display, threshold);
        }).join("") + sparkCell(e.cells, e.metric.isMean) +
        changeChip(e.last, e.metric.isMean) + "</tr>";
    };

    if (mode === "qfs") {
      var groups = [
        { title: "Means, indexes & NPS", match: function (m) { return m.isMean; } },
        { title: "Top-box NETs (% — significance-tested)",
          match: function (m) { return !m.isMean; } }];
      var emitted = 0;
      groups.forEach(function (g) {
        var inGroup = entries.filter(function (e) { return g.match(e.metric); });
        if (!inGroup.length) return;
        html.push('<tr class="grp"><td colspan="' + (years.length + 4) +
          '"><span class="stickyhdr">' + g.title + "</span></td></tr>");
        var lastCat = null;
        inGroup.forEach(function (e) {
          if (emitted >= MAX_ROWS) return;
          if ((s.expSort || "original") === "original" &&
              e.metric.category !== lastCat && (s.scope || "key") === "key") {
            lastCat = e.metric.category;
            html.push('<tr class="cat"><td colspan="' + (years.length + 4) +
              '"><span class="stickyhdr">' + fmt.escapeHtml(lastCat) +
              "</span></td></tr>");
          }
          emitted++;
          html.push(rowHtml(e,
            '<td class="lab"><button class="linklike" data-vis="' + e.metric.key +
            '" title="' + fmt.escapeHtml(e.metric.title + " — " + e.metric.label) +
            '">' + e.metric.code + " · " +
            fmt.escapeHtml(TR.charts.clip(e.metric.title, 42)) + "</button>" +
            '<div class="idxd">' + fmt.escapeHtml(TR.charts.clip(e.metric.label, 36)) +
            "</div></td>"));
        });
      });
      if (entries.length > MAX_ROWS) {
        html.push('<tr><td colspan="' + (years.length + 4) +
          '" class="trknote">Showing ' + MAX_ROWS + " of " + entries.length +
          " rows — search to narrow.</td></tr>");
      }
    } else {
      entries.forEach(function (e) {
        html.push(rowHtml(e,
          '<td class="lab"><button class="linklike" data-vis="' + e.metric.key +
          '" data-visseg="' + (e.seg.norm || "total") + '">' +
          fmt.escapeHtml(e.seg.label) + "</button></td>"));
      });
    }
    html.push("</tbody></table></div>");
    html.push(legendHtml());
    html.push("</div>");
    host.innerHTML = html.join("");

    /* ---- wiring ---- */
    host.querySelectorAll("[data-expmode]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk().state.explorerMode = btn.getAttribute("data-expmode");
        trk().rerender();
      });
    });
    host.querySelectorAll("[data-display]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk().state.display = btn.getAttribute("data-display");
        trk().rerender();
      });
    });
    host.querySelector("[data-expsort]").addEventListener("change", function (e) {
      trk().state.expSort = e.target.value;
      trk().rerender();
    });
    host.querySelector("[data-expexcel]").addEventListener("click", function () {
      exportExplorer(entries, years, exportName);
    });
    host.querySelectorAll("[data-wavechip]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var year = parseInt(btn.getAttribute("data-wavechip"), 10);
        var all = trk().years().concat([TR.render.currentYear()]);
        var set = trk().state.expWaves;
        if (!set) {
          set = {};
          all.forEach(function (y) { set[y] = true; });
        }
        set[year] = !set[year];
        trk().state.expWaves = set;
        trk().rerender();
      });
    });
    host.querySelector("[data-waveall]").addEventListener("click", function () {
      trk().state.expWaves = null;
      trk().rerender();
    });
    host.querySelector("[data-wavelast]").addEventListener("click", function () {
      var all = trk().years().concat([TR.render.currentYear()]);
      var set = {};
      all.forEach(function (y, i) { set[y] = i >= all.length - 3; });
      trk().state.expWaves = set;
      trk().rerender();
    });
    host.querySelectorAll("[data-vis]").forEach(function (el) {
      el.addEventListener("click", function () {
        trk().state.metricKey = el.getAttribute("data-vis");
        var seg = el.getAttribute("data-visseg") ||
          (trk().state.segment || "total");
        trk().state.visSel = { metrics: [el.getAttribute("data-vis")],
          segs: [seg] };
        trk().state.sub = "visualise";
        trk().rerender();
      });
    });
    var toVis = host.querySelector("[data-tovis]");
    if (toVis) {
      toVis.addEventListener("click", function () {
        var picked = Array.prototype.slice.call(
          host.querySelectorAll("[data-pick]:checked")).map(function (el) {
            return el.getAttribute("data-pick");
          });
        if (mode === "qfs") {
          if (!picked.length) { TR.shell.toast("Tick at least one metric"); return; }
          trk().state.metricKey = picked[0];
          trk().state.visSel = { metrics: picked.slice(0, MAX_SERIES),
            segs: [trk().state.segment || "total"] };
        } else {
          trk().state.visSel = { metrics: [contextMetric().key],
            segs: (picked.length ? picked : ["total"]).slice(0, MAX_SERIES) };
        }
        trk().state.sub = "visualise";
        trk().rerender();
      });
    }
    var segSel = host.querySelector("[data-trkseg]");
    if (segSel) {
      segSel.addEventListener("change", function () {
        trk().state.segment = segSel.value || null;
        trk().rerender();
      });
    }
    host.querySelectorAll("[data-scope]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk().state.scope = btn.getAttribute("data-scope");
        trk().rerender();
      });
    });
    var metricSel = host.querySelector("[data-trkmetric]");
    if (metricSel) {
      metricSel.addEventListener("change", function () {
        trk().state.metricKey = metricSel.value;
        trk().state.visSel = null;
        trk().rerender();
      });
    }
    if (document.getElementById("trk-search")) {
      TR.views._wireRowFilter(host, "trk-search", "none");
    }
  };

  /* ---------------- Visualise view ---------------- */

  /** 95% interval bounds {lo, hi} at a point: Wilson score on the
   *  published base for proportions (asymmetric — never a plain ±);
   *  for means, indexes and NPS z·SD/√n with the SD derived from the
   *  published distribution (TR.trk.sdAt — the same spread that powers
   *  their sig testing; the single SD source). */
  function ciBounds(metric, segId, point) {
    if (metric.diff) return null;     // score differences: no single base
    if (!point.base || point.value === null) return null;
    if (!metric.isMean) return TR.conf.wilsonPct(point.value, point.base);
    var sd = trk().sdAt(metric, segId === "total" ? null : segId, point.year);
    return sd === null ? null
      : TR.conf.meanCI(point.value, sd, point.base);
  }
  vis._ciBounds = ciBounds;   // exposed for pinned exhibits + tests

  /** Series for the chart/table: spec points transformed for the mode. */
  function buildSeries(specs, sel, mode, yearSet) {
    return specs.map(function (spec) {
      var cells = trk().points(spec.metric,
        spec.segId === "total" ? null : spec.segId);
      if (!cells.length) return null;
      var points = cells.map(function (c, i) {
        var value = c.value;
        if (mode === "prev") value = c.change_prev;
        if (mode === "base") value = i === 0 ? null : c.change_base;
        if (value === null || value === undefined) return null;
        return { wave: c.wave, year: c.year, value: value, base: c.base,
          current: c.current };
      }).filter(Boolean).filter(function (p) {
        return !yearSet || yearSet[p.year];
      });
      return { spec: spec, label: specLabel(spec, sel), points: points,
        cells: cells };
    }).filter(Boolean).filter(function (s) { return s.points.length; });
  }

  vis.renderVisualise = function (host) {
    var s = trk().state;
    var sel = selection();
    var specs = seriesSpecs(sel);
    if (!specs.length) { host.innerHTML = ""; return; }
    var singleMetric = sel.metrics.length === 1 ? specs[0].metric : null;
    if (singleMetric) trk().state.metricKey = singleMetric.key;
    var mode = s.visMode || "absolute";
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var allYears = trk().years().concat([TR.render.currentYear()]);
    var yearSet = s.visWaves;
    var series = buildSeries(specs, sel,
      mode === "absolute" ? "absolute" : mode, yearSet);
    var palette = TR.render.palette();
    // annotations work across every plotted line: gather notes from all the
    // displayed metrics (deduped), each tagged with its metric so a click on
    // any line's point tags the right series.
    var noteMetrics = specs.map(function (sp) { return sp.metric; })
      .filter(function (m, i, a) {
        return a.map(function (x) { return x.key; }).indexOf(m.key) === i;
      });
    var notes = [];
    noteMetrics.forEach(function (m) {
      TR.notes.forMetric(m.key).forEach(function (n) {
        notes.push({ year: n.year, text: n.text, metricKey: m.key });
      });
    });

    var pseudo = { code: singleMetric ? singleMetric.code : "VIS",
      title: visTitle(sel, specs), source: "published",
      chartKind: "summary", lowBaseThreshold: threshold,
      columns: [{ label: "Total", letter: "", base: null, low: false }],
      rows: series.map(function (sr) {
        return { kind: mode === "absolute" ? sr.spec.metric.kind : "net",
          diff: sr.spec.metric.diff, label: sr.label, waves: sr.points,
          metricKey: sr.spec.metric.key,
          cells: [{ pct: null, mean: null, n: null, sig: "" }] };
      }) };
    var chart = TR.render.trendChart(pseudo, {
      yMin: s.yMin, yMax: s.yMax, labels: s.visLabels || "last",
      ci: (mode === "absolute" && s.visCI) ? function (row, point) {
        var sr = series.filter(function (x) { return x.label === row.label; })[0];
        return sr ? ciBounds(sr.spec.metric, sr.spec.segId, point) : null;
      } : null,
      annotations: notes.map(function (n) {
        return { year: n.year, label: n.text };
      }),
      clickable: true,   // tag a point on any line (single or multi-series)
      note: (mode === "absolute" ? "Published values" :
        mode === "prev" ? "Change vs previous wave (pp)" :
        "Change vs baseline wave (pp)") +
        (singleMetric ? " · " + fmt.escapeHtml(singleMetric.label) : "")
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
      "<h3>Visualise · " + fmt.escapeHtml(visTitle(sel, specs)) + "</h3>" +
      (singleMetric
        ? '<select data-trkmetric>' + metricOptions(singleMetric.key) + "</select>"
        : '<button class="linklike" data-backexp>← change selection in ' +
          "Explorer</button>") + "</div>" +
      '<div class="scopebar">' + modeBtn("absolute", "Absolute") +
      modeBtn("prev", "vs Previous") + modeBtn("base", "vs Baseline") +
      '<label class="tg" title="Proportions: Wilson score interval on the ' +
      "published base. Means, indexes and NPS: SD derived from the " +
      'published category distribution of each wave."><input type="checkbox" data-visci' +
      (s.visCI ? " checked" : "") + (mode !== "absolute" ? " disabled" : "") +
      "> 95% " + TR.conf.labels().interval_abbrev + " bands</label>" +
      '<label class="tg">Labels <select data-vislabels>' +
      ["last", "all", "none"].map(function (l) {
        return '<option value="' + l + '"' +
          ((s.visLabels || "last") === l ? " selected" : "") + ">" + l + "</option>";
      }).join("") + "</select></label>" +
      '<label class="tg">Y <input type="number" data-ymin placeholder="min" value="' +
      (s.yMin === null || s.yMin === undefined ? "" : s.yMin) + '">–' +
      '<input type="number" data-ymax placeholder="max" value="' +
      (s.yMax === null || s.yMax === undefined ? "" : s.yMax) + '">' +
      '<button class="t-btn" data-yreset title="Auto scale">↺</button></label>' +
      '<span class="ctl-spacer"></span>' +
      '<button class="t-btn" data-visexcel>Excel</button>' +
      '<span class="pinwrap"><button class="primary" data-vispinbtn>📌 Pin…</button>' +
      '<span class="pinmenu" data-vispinmenu hidden></span></span></div>' +
      '<div class="scopebar wavechips">' + allYears.map(function (y) {
        var on = !yearSet || yearSet[y];
        return '<button class="btab' + (on ? " on" : "") + '" data-wavechip="' +
          y + '">' + trk().yLabel(y) + "</button>";
      }).join("") + '<button class="linklike" data-waveall>all</button></div>' +
      '<div class="chart" data-vischart>' + (chart ||
        '<div class="chart-error">No data for this selection.</div>') + "</div>" +
      (s.visCI && mode === "absolute"
        ? '<p class="trknote">95% ' + TR.conf.labels().interval_term +
          " bands — proportions: Wilson score interval on the published " +
          "base; means, indexes and NPS: SD derived from the published " +
          "category distribution of each wave." +
          (TR.conf.labels().is_probability ? "" :
            " Quoted as stability intervals: this survey did not use " +
            "formal random sampling.") + "</p>"
        : "") +
      '<p class="trknote">💬 Click any data point to tag it with a note ' +
      "(e.g. “Campaign launched”) — tags travel with pins and saved copies.</p>"];

    if (notes.length) {
      html.push('<div class="notechips">' + notes.map(function (n) {
        var m = trk().metricByKey(n.metricKey);
        var pre = (noteMetrics.length > 1 && m) ? fmt.escapeHtml(m.code) + " · " : "";
        return '<span class="notechip">' + pre + trk().yLabel(n.year) + " · " +
          fmt.escapeHtml(TR.charts.clip(n.text, 44)) +
          '<button data-delnote="' + n.year + '" data-delmetric="' +
          fmt.escapeHtml(n.metricKey) + '" title="Remove note">✕</button></span>';
      }).join("") + "</div>");
    }

    // series table: colour key dot, values, optional change rows
    var shownYears = allYears.filter(function (y) {
      return !yearSet || yearSet[y];
    });
    html.push('<div class="scopebar"><span class="trknote">Table rows:</span>' +
      '<label class="tg"><input type="checkbox" data-rowprev' +
      (s.visRowPrev !== false ? " checked" : "") + "> vs previous</label>" +
      '<label class="tg"><input type="checkbox" data-rowbase' +
      (s.visRowBase ? " checked" : "") + "> vs baseline</label></div>");
    html.push('<div class="trkwrap"><table class="moved trk"><thead><tr>' +
      "<th>Series</th>" + shownYears.map(function (y) {
        return "<th class='wv'>" + trk().yLabel(y) + "</th>";
      }).join("") + "</tr></thead><tbody>");
    series.forEach(function (sr, k) {
      var isMean = sr.spec.metric.isMean;
      var byYear = {};
      sr.cells.forEach(function (c) { byYear[c.year] = c; });
      var dot = '<span class="dot" style="background:' +
        palette[k % palette.length] + '"></span>';
      var row = ["<td class='lab'>" + dot + fmt.escapeHtml(sr.label) + "</td>"];
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
          trk().fmtVal(c.value, isMean) + (low ? " ⚠" : "") + "</td>");
        var chg = function (change, sig) {
          if (change === null || change === undefined) return '<td class="wv"></td>';
          return '<td class="wv sub ' + (change >= 0 ? "up" : "down") +
            (sig ? " dsig" : "") + '">' + (change >= 0 ? "+" : "−") +
            Math.abs(change).toFixed(isMean ? 1 : 0) + "</td>";
        };
        prevRow.push(chg(c.change_prev, c.sig_prev));
        baseRow.push(chg(c.change_base, c.sig_base));
      });
      html.push("<tr>" + row.join("") + "</tr>");
      if (s.visRowPrev !== false) {
        html.push('<tr class="subrow">' + prevRow.join("") + "</tr>");
      }
      if (s.visRowBase) {
        html.push('<tr class="subrow">' + baseRow.join("") + "</tr>");
      }
    });
    html.push("</tbody></table></div>");
    if (lowPoints.length) {
      html.push('<p class="trknote">⚠ Low bases (&lt;' + threshold +
        ", excluded from significance): " +
        fmt.escapeHtml(lowPoints.slice(0, 8).join("; ")) +
        (lowPoints.length > 8 ? " +" + (lowPoints.length - 8) + " more" : "") +
        "</p>");
    }
    if (singleMetric) {
      html.push('<div class="insight"><div class="insight-head">Analyst insight · ' +
        "tracking</div><textarea data-visnote placeholder=\"Insight for this trend " +
        'view… (saved locally, pinned with the exhibit)">' +
        fmt.escapeHtml(TR.insights.get(singleMetric.code, "tracking") || "") +
        "</textarea></div>");
    }
    html.push("</div>");
    host.innerHTML = html.join("");

    /* ---- wiring ---- */
    var rerender = function () { trk().rerender(); };
    var msel = host.querySelector("[data-trkmetric]");
    if (msel) msel.addEventListener("change", function (e) {
      trk().state.metricKey = e.target.value;
      trk().state.visSel = { metrics: [e.target.value], segs: sel.segs };
      rerender();
    });
    var back = host.querySelector("[data-backexp]");
    if (back) back.addEventListener("click", function () {
      trk().state.sub = "explorer";
      rerender();
    });
    host.querySelectorAll("[data-vismode]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk().state.visMode = btn.getAttribute("data-vismode") === "abs"
          ? "absolute" : btn.getAttribute("data-vismode");
        rerender();
      });
    });
    var ci = host.querySelector("[data-visci]");
    if (ci) ci.addEventListener("change", function () {
      trk().state.visCI = ci.checked;
      rerender();
    });
    host.querySelector("[data-vislabels]").addEventListener("change", function (e) {
      trk().state.visLabels = e.target.value;
      rerender();
    });
    var applyY = function () {
      var lo = parseFloat(host.querySelector("[data-ymin]").value);
      var hi = parseFloat(host.querySelector("[data-ymax]").value);
      trk().state.yMin = isNaN(lo) ? null : lo;
      trk().state.yMax = isNaN(hi) ? null : hi;
      rerender();
    };
    host.querySelector("[data-ymin]").addEventListener("change", applyY);
    host.querySelector("[data-ymax]").addEventListener("change", applyY);
    host.querySelector("[data-yreset]").addEventListener("click", function () {
      trk().state.yMin = trk().state.yMax = null;
      rerender();
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
        rerender();
      });
    });
    host.querySelector("[data-waveall]").addEventListener("click", function () {
      trk().state.visWaves = null;
      rerender();
    });
    host.querySelectorAll("[data-rowprev], [data-rowbase]").forEach(function (el) {
      el.addEventListener("change", function () {
        trk().state.visRowPrev =
          host.querySelector("[data-rowprev]").checked;
        trk().state.visRowBase =
          host.querySelector("[data-rowbase]").checked;
        rerender();
      });
    });
    // annotation tagging: click ANY line's point -> inline editor (no prompt).
    // The clicked point carries data-metric, so tagging works for single or
    // multi-series charts (each tag belongs to the line it was placed on).
    var chartHost = host.querySelector("[data-vischart]");
    if (chartHost) {
      chartHost.addEventListener("click", function (e) {
        var pt = e.target.closest("circle.trendpt");
        if (!pt) return;
        var year = parseFloat(pt.getAttribute("data-year"));  // float: twice-yearly keys (2025.5)
        var mKey = pt.getAttribute("data-metric") || (singleMetric && singleMetric.key);
        if (!mKey || isNaN(year)) return;
        var mObj = trk().metricByKey(mKey) || singleMetric;
        var old = chartHost.querySelector(".notepop");
        if (old) old.remove();
        var existing = TR.notes.get(mKey, year);
        var pop = document.createElement("div");
        pop.className = "notepop";
        var rect = chartHost.getBoundingClientRect();
        pop.style.left = Math.max(8, Math.min(e.clientX - rect.left - 20,
          rect.width - 260)) + "px";
        pop.style.top = Math.max(8, e.clientY - rect.top + 10) + "px";
        pop.innerHTML = '<div class="np-title">Tag ' + trk().yLabel(year) + " · " +
          fmt.escapeHtml(TR.charts.clip(mObj ? mObj.label : "", 24)) + "</div>" +
          '<input type="text" maxlength="60" placeholder="e.g. Campaign ' +
          'launched" value="' + fmt.escapeHtml(existing) + '">' +
          '<div class="np-btns"><button class="primary" data-npsave>Save</button>' +
          (existing ? "<button data-npremove>Remove</button>" : "") +
          "<button data-npcancel>Cancel</button></div>";
        chartHost.appendChild(pop);
        var input = pop.querySelector("input");
        input.focus();
        input.select();
        var save = function () {
          TR.notes.set(mKey, year, input.value);
          rerender();
        };
        pop.querySelector("[data-npsave]").addEventListener("click", save);
        input.addEventListener("keydown", function (ev) {
          if (ev.key === "Enter") save();
          if (ev.key === "Escape") pop.remove();
        });
        var remove = pop.querySelector("[data-npremove]");
        if (remove) {
          remove.addEventListener("click", function () {
            TR.notes.set(mKey, year, "");
            rerender();
          });
        }
        pop.querySelector("[data-npcancel]").addEventListener("click", function () {
          pop.remove();
        });
      });
    }
    host.querySelectorAll("[data-delnote]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        TR.notes.set(btn.getAttribute("data-delmetric") || (singleMetric && singleMetric.key),
          parseFloat(btn.getAttribute("data-delnote")), "");
        rerender();
      });
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
        if (s.visCI && mode === "absolute") {
          // interval views export their bounds explicitly (lo/hi rows)
          var abbrev = TR.conf.labels().interval_abbrev;
          var boundRow = function (which) {
            return shownYears.map(function (y) {
              var c = byYear[y];
              var bounds = c ? ciBounds(sr.spec.metric, sr.spec.segId, c) : null;
              return bounds ? Math.round(bounds[which] * 10) / 10 : "";
            });
          };
          rows.push([sr.label + " · 95% " + abbrev + " lo"].concat(boundRow("lo")));
          rows.push([sr.label + " · 95% " + abbrev + " hi"].concat(boundRow("hi")));
        }
      });
      TR.xlsx.download((singleMetric ? singleMetric.code : "metrics") + "_trend",
        "Trend", [head].concat(rows));
    });
    // pin popover: choose WHICH elements to pin before pinning
    var pinBtn = host.querySelector("[data-vispinbtn]");
    var pinMenu = host.querySelector("[data-vispinmenu]");
    pinBtn.addEventListener("click", function () {
      if (!pinMenu.hidden) { pinMenu.hidden = true; return; }
      pinMenu.hidden = false;
      TR.shell.pinMenu(pinMenu, [
        { key: "dist", label: "This-wave chart", checked: false },
        { key: "trend", label: "Trend chart", checked: true },
        { key: "table", label: "Data table", checked: false },
        { key: "insight", label: "Insight", checked: true }
      ], function (flags) {
        pinMenu.hidden = true;
        if (!flags.dist && !flags.trend && !flags.table) {
          TR.shell.toast("Pick at least one chart or the table");
          return;
        }
        TR.story2.pinTrackingView({
          title: visTitle(sel, specs),
          ci: !!(s.visCI && mode === "absolute"),
          qs: specs.map(function (sp) { return sp.metric.code; })
            .filter(function (c, i, a) { return a.indexOf(c) === i; }),
          series: specs.map(function (sp) {
            return { code: sp.metric.code, ri: sp.metric.ri,
              label: specLabel(sp, sel), seg: sp.segId };
          }),
          annotations: notes.map(function (n) {
            return { year: n.year, label: n.text };
          }),
          note: singleMetric
            ? (TR.insights.get(singleMetric.code, "tracking") || "") : ""
        }, flags);
      });
    });
    var noteBox = host.querySelector("[data-visnote]");
    if (noteBox) noteBox.addEventListener("input", function (e) {
      TR.insights.set(singleMetric.code, e.target.value, "tracking");
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
