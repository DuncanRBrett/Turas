/**
 * Key drivers view. Importance per driver with a method picker and the
 * bootstrap interval that brackets each estimate, the importance-performance
 * quadrant, the driver-by-segment matrix with its bases, and a diagnostics
 * drawer carrying model fit, multicollinearity and the base the whole thing
 * rests on.
 *
 * FROZEN, NOT LIVE. Every other analysis tab recomputes from microdata when
 * the audience filter changes. Key drivers cannot: importance is a model
 * estimate made once, on the whole sample, and a regression cannot be re-fitted
 * in the browser. So this tab shows what was estimated, the filter bar is
 * hidden while it is open, and the note at the top says so. Same contract as
 * Conjoint, MaxDiff, Pricing and Tracking.
 *
 * The data comes from TR.KD, the keydriver module's contribution island
 * (modules/keydriver/R/13_v2_island.R). There are no new row kinds: a driver
 * has no banner and no base of its own, and importance runs along a driver
 * axis, not a banner axis, so none of this belongs in the crosstab data layer.
 *
 * NO INTERVAL IS NOT A ZERO INTERVAL. The bootstrap covers correlation, beta
 * and relative weights. It does not cover Shapley. The island says which
 * methods it reached, and this view stamps the ones it did not rather than
 * drawing a whisker that would mean nothing.
 *
 * SIGNIFICANCE IS NOT BORROWED. Importance is a model estimate, so nothing
 * here routes through the crosstab significance engine, whose letters come
 * from proportion and Welch tests on counts. The interval is the uncertainty
 * statement, and there is no significance letter anywhere on this tab. The
 * gate asserts that by name.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var kd = TR.keydriver = {};

  var SEP = "|:|";

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // A missing value shows as an en dash, never as "NaN" or an empty cell.
  function num(v, dp) {
    if (v === null || v === undefined || v === "" || isNaN(v)) return "–";
    return Number(v).toFixed(dp === undefined ? 1 : dp);
  }

  function arr(v) { return Array.isArray(v) ? v : null; }
  function meta() { return (TR.KD && TR.KD.meta) || {}; }

  /**
   * The interval's confidence level, in the island's own words.
   *
   * Never typed into this file. The level is a property of the bootstrap that
   * ran, so a study configured at 90% must not be labelled 95% by a renderer
   * that assumed one.
   * @returns {string} e.g. "95% interval", or "Interval" when none is carried
   */
  function ciLabel() {
    var c = TR.KD && TR.KD.ci;
    if (!c || c.level === undefined || c.level === null) return "Interval";
    return num(Number(c.level) * 100, 0) + "% interval";
  }

  /** The island's methods, or an empty list when there is no importance block. */
  function methods() {
    var imp = TR.KD && TR.KD.importance;
    return (imp && arr(imp.methods)) || [];
  }

  function methodByKey(key) {
    var ms = methods();
    for (var i = 0; i < ms.length; i++) if (ms[i].key === key) return ms[i];
    return null;
  }

  /** The method on screen. Defaults to the first the island carries. */
  kd.state = { method: null, segmentVar: null };

  function activeMethod() {
    var ms = methods();
    if (!ms.length) return null;
    if (kd.state.method) {
      var hit = methodByKey(kd.state.method);
      if (hit) return hit;
    }
    return ms[0];
  }

  /**
   * Is there a key driver study in this report?
   * @returns {boolean}
   */
  kd.available = function () {
    var d = TR.KD;
    return !!(d && d.importance && arr(d.importance.drivers) &&
              d.importance.drivers.length > 0);
  };

  /** Every interval the island carries, keyed driver + method. */
  function ciIndex() {
    var out = {};
    var rows = (TR.KD && TR.KD.ci && arr(TR.KD.ci.rows)) || [];
    for (var i = 0; i < rows.length; i++) {
      out[rows[i].driver + SEP + rows[i].method] = rows[i];
    }
    return out;
  }

  // ---------------------------------------------------------------- panels

  /** What ran, on what base. The first thing on the tab, deliberately. */
  function provenanceHtml(m) {
    var b = m.base || {};
    var bits = [];
    if (m.outcome && (m.outcome.label || m.outcome.var)) {
      bits.push("Outcome: <strong>" + esc(m.outcome.label || m.outcome.var) + "</strong>");
    }
    if (m.n_drivers) bits.push(m.n_drivers + " drivers");
    if (b.n !== undefined) bits.push("n = " + num(b.n, 0));
    if (b.n_excluded) bits.push(num(b.n_excluded, 0) + " excluded");
    if (b.weighted) {
      var w = "weighted";
      if (b.n_eff !== undefined) w += " (effective n = " + num(b.n_eff, 0) + ")";
      bits.push(w);
    } else {
      bits.push("unweighted");
    }
    if (m.primary_method) bits.push("ranked by " + esc(m.primary_method));

    return '<div class="kd-panel kd-provenance">' +
      "<h3>" + esc(m.analysis_name || "Key drivers") + "</h3>" +
      "<p>" + bits.join(" &middot; ") + "</p>" +
      '<p class="kd-frozen">' + esc(m.filter_note ||
        "Report filters do not apply here.") +
      " The crosstab export is the filterable cut.</p>" +
      "</div>";
  }

  /** The method picker. Absent when the island carries only one method. */
  function pickerHtml() {
    var ms = methods();
    if (ms.length < 2) return "";
    var act = activeMethod();
    var btns = ms.map(function (m) {
      return '<button class="kd-chip' + (m.key === act.key ? " active" : "") +
        '" data-kd-method="' + esc(m.key) + '">' + esc(m.label) + "</button>";
    }).join("");
    return '<div class="kd-chips" role="group" aria-label="Importance method">' +
      btns + "</div>";
  }

  /**
   * Importance bars for the active method, with the interval drawn as a
   * whisker where the bootstrap reached it.
   */
  function importanceHtml() {
    var d = TR.KD;
    var m = activeMethod();
    if (!m) return "";
    var drivers = arr(d.importance.drivers) || [];
    var ci = ciIndex();

    var vals = drivers.map(function (r) {
      return (r.values && r.values[m.key] !== undefined) ? Number(r.values[m.key]) : NaN;
    }).filter(function (v) { return !isNaN(v); });
    if (!vals.length) {
      return '<div class="kd-panel"><p>This method carries no values.</p></div>';
    }
    // Correlations can be negative; a share cannot. The axis covers both.
    var lo = Math.min(0, Math.min.apply(null, vals));
    var hi = Math.max.apply(null, vals);
    // The whiskers can run past the bars.
    drivers.forEach(function (r) {
      var c = ci[r.driver + SEP + m.key];
      if (c) { if (c.lo < lo) lo = c.lo; if (c.hi > hi) hi = c.hi; }
    });
    var span = (hi - lo) || 1;
    var pos = function (v) { return ((v - lo) / span) * 100; };

    var sorted = drivers.slice().sort(function (a, b) {
      var av = (a.values && a.values[m.key]), bv = (b.values && b.values[m.key]);
      if (av === undefined) return 1;
      if (bv === undefined) return -1;
      return Math.abs(bv) - Math.abs(av);
    });

    var rows = sorted.map(function (r) {
      var v = (r.values && r.values[m.key] !== undefined) ? Number(r.values[m.key]) : null;
      var c = ci[r.driver + SEP + m.key];
      var rank = (r.ranks && r.ranks[m.key] !== undefined) ? r.ranks[m.key] : null;
      var dp = m.unit === "r" ? 2 : 1;
      var unit = m.unit === "pct" ? "%" : "";

      var bar = "";
      if (v !== null) {
        var left = pos(Math.min(0, v)), right = pos(Math.max(0, v));
        bar = '<span class="kd-bar" style="left:' + left.toFixed(2) + "%;width:" +
          Math.max(0.4, right - left).toFixed(2) + '%"></span>';
      }
      var whisk = "";
      if (c) {
        whisk = '<span class="kd-whisker" style="left:' + pos(c.lo).toFixed(2) +
          "%;width:" + Math.max(0.4, pos(c.hi) - pos(c.lo)).toFixed(2) + '%"></span>';
      }
      var dir = "";
      if (r.direction === -1) {
        dir = ' <span class="kd-dir" title="This driver moves the outcome down">' +
          "↓</span>";
      }
      var ciText = c
        ? num(c.lo, dp) + unit + " to " + num(c.hi, dp) + unit
        : (m.interval ? "–" : "no interval available");

      return '<tr><th scope="row">' + esc(r.label || r.driver) + dir + "</th>" +
        '<td class="kd-num">' + (rank === null ? "–" : num(rank, 0)) + "</td>" +
        '<td class="kd-track">' + bar + whisk + "</td>" +
        '<td class="kd-num">' + num(v, dp) + unit + "</td>" +
        '<td class="kd-ci">' + esc(ciText) + "</td></tr>";
    }).join("");

    var stamp = m.interval ? "" :
      '<p class="kd-stamp">' + esc(m.label) +
      " carries no interval. The bootstrap does not extend to it, so none is drawn." +
      "</p>";

    return '<div class="kd-panel">' +
      "<h3>Importance</h3>" + pickerHtml() + stamp +
      '<table class="kd-table"><thead><tr>' +
      "<th>Driver</th><th>Rank</th><th>&nbsp;</th><th>" + esc(m.label) +
      "</th><th>" + esc(ciLabel()) + "</th></tr></thead><tbody>" + rows +
      "</tbody></table></div>";
  }

  /** The importance-performance quadrant. */
  function quadrantHtml() {
    var q = TR.KD && TR.KD.quadrant;
    if (!q || !arr(q.points) || !q.points.length) return "";
    var W = 460, H = 360, PAD = 44;
    var t = q.thresholds || {};
    var sx = function (v) { return PAD + (Number(v) / 100) * (W - PAD - 16); };
    var sy = function (v) { return H - PAD - (Number(v) / 100) * (H - PAD - 16); };

    var tx = (t.x === undefined) ? null : sx(t.x);
    var ty = (t.y === undefined) ? null : sy(t.y);

    var guides = "";
    if (tx !== null) {
      guides += '<line class="kd-guide" x1="' + tx.toFixed(1) + '" y1="16" x2="' +
        tx.toFixed(1) + '" y2="' + (H - PAD) + '"></line>';
    }
    if (ty !== null) {
      guides += '<line class="kd-guide" x1="' + PAD + '" y1="' + ty.toFixed(1) +
        '" x2="' + (W - 16) + '" y2="' + ty.toFixed(1) + '"></line>';
    }

    // Labels sit to the right of their point by default and flip left when the
    // point is near the right edge, so a label can never run off the plot. A
    // point near the LEFT edge always takes a right-hand label, which is what
    // the first draft got wrong: alternating purely by index clipped the
    // lowest-performing driver against the axis.
    var pts = q.points.map(function (p) {
      if (p.x === undefined || p.y === undefined) return "";
      var x = sx(p.x), y = sy(p.y);
      var right = x < (W * 0.62);
      return '<g class="kd-qpt"><circle cx="' + x.toFixed(1) + '" cy="' + y.toFixed(1) +
        '" r="5"></circle><text x="' + (right ? x + 8 : x - 8).toFixed(1) + '" y="' +
        (y - 7).toFixed(1) + '" text-anchor="' + (right ? "start" : "end") + '">' +
        esc(p.label || p.driver) + "</text></g>";
    }).join("");

    var src = q.importance_source || {};
    var srcNote = "";
    if (src.used) {
      srcNote = '<p class="kd-note">Importance axis: ' + esc(src.used);
      if (src.requested && src.requested !== src.used) {
        srcNote += " (" + esc(src.requested) + " was requested)";
      }
      srcNote += ".</p>";
    }

    return '<div class="kd-panel"><h3>Importance and performance</h3>' + srcNote +
      '<svg class="kd-quadrant" viewBox="0 0 ' + W + " " + H +
      '" role="img" aria-label="Importance against performance by driver">' +
      '<line class="kd-axis" x1="' + PAD + '" y1="' + (H - PAD) + '" x2="' + (W - 16) +
      '" y2="' + (H - PAD) + '"></line>' +
      '<line class="kd-axis" x1="' + PAD + '" y1="16" x2="' + PAD + '" y2="' +
      (H - PAD) + '"></line>' + guides + pts +
      '<text class="kd-axis-label" x="' + (W / 2) + '" y="' + (H - 10) +
      '" text-anchor="middle">' + esc((q.axes && q.axes.x) || "Performance") + "</text>" +
      '<text class="kd-axis-label" transform="rotate(-90 14 ' + (H / 2) + ')" x="14" y="' +
      (H / 2) + '" text-anchor="middle">' +
      esc((q.axes && q.axes.y) || "Importance") + "</text>" +
      "</svg></div>";
  }

  /** The driver-by-segment matrix, with every segment's base beside its name. */
  function segmentsHtml() {
    var blocks = arr(TR.KD && TR.KD.segments);
    if (!blocks || !blocks.length) return "";

    var idx = 0;
    if (kd.state.segmentVar) {
      blocks.forEach(function (b, i) { if (b.variable === kd.state.segmentVar) idx = i; });
    }
    var blk = blocks[idx];
    var segs = arr(blk.segments) || [];

    var picker = "";
    if (blocks.length > 1) {
      picker = '<div class="kd-chips" role="group" aria-label="Segment variable">' +
        blocks.map(function (b, i) {
          return '<button class="kd-chip' + (i === idx ? " active" : "") +
            '" data-kd-segvar="' + esc(b.variable) + '">' + esc(b.variable) + "</button>";
        }).join("") + "</div>";
    }

    var head = segs.map(function (s) {
      return "<th>" + esc(s.name) +
        (s.n === undefined ? "" : '<span class="kd-base">n = ' + num(s.n, 0) + "</span>") +
        "</th>";
    }).join("");

    var rows = (arr(blk.rows) || []).map(function (r) {
      var cells = segs.map(function (s) {
        var v = r.values && r.values[s.name];
        var rk = r.ranks && r.ranks[s.name];
        return '<td class="kd-num">' + num(v, 1) + "%" +
          (rk === undefined ? "" : '<span class="kd-rank">#' + num(rk, 0) + "</span>") +
          "</td>";
      }).join("");
      return '<tr><th scope="row">' + esc(r.label || r.driver) + "</th>" + cells +
        '<td class="kd-class">' + esc(r.classification || "–") + "</td></tr>";
    }).join("");

    var base = "";
    if (blk.min_base !== undefined) {
      base = '<p class="kd-note">A segment had to reach n = ' + num(blk.min_base, 0) +
        " to be analysed. Smaller segments are not shown.</p>";
    }
    var insights = arr(blk.insights);
    var ins = (insights && insights.length)
      ? '<ul class="kd-insights">' + insights.map(function (t) {
          return "<li>" + esc(t) + "</li>";
        }).join("") + "</ul>"
      : "";

    return '<div class="kd-panel"><h3>By segment</h3>' + picker + base +
      '<table class="kd-table"><thead><tr><th>Driver</th>' + head +
      "<th>Pattern</th></tr></thead><tbody>" + rows + "</tbody></table>" +
      ins + "</div>";
  }

  /** Model fit, multicollinearity, and the base. The honesty drawer. */
  function diagnosticsHtml() {
    var f = TR.KD && TR.KD.fit;
    var m = meta();
    if (!f && !m.base) return "";

    var fitBits = [];
    if (f) {
      if (f.r2 !== undefined) fitBits.push("R&sup2; = " + num(f.r2, 3));
      if (f.adj_r2 !== undefined) fitBits.push("adjusted R&sup2; = " + num(f.adj_r2, 3));
      if (f.f !== undefined) {
        fitBits.push("F(" + num(f.df1, 0) + ", " + num(f.df2, 0) + ") = " + num(f.f, 1));
      }
      if (f.p !== undefined) {
        fitBits.push("p " + (f.p < 0.001 ? "&lt; 0.001" : "= " + num(f.p, 3)));
      }
    }

    var vif = f && arr(f.vif);
    var vifHtml = "";
    if (vif && vif.length) {
      var th = (f.vif_thresholds) || { moderate: 5, high: 10 };
      var worst = 0;
      var vrows = vif.map(function (v) {
        var val = Number(v.vif);
        if (val > worst) worst = val;
        var flag = val >= th.high ? "severe" : (val >= th.moderate ? "moderate" : "");
        return '<tr><th scope="row">' + esc(v.term) + "</th>" +
          '<td class="kd-num' + (flag ? " kd-flag-" + flag : "") + '">' + num(val, 2) +
          "</td><td>" + (flag ? esc(flag) : "–") + "</td></tr>";
      }).join("");
      var caveat = worst >= th.high
        ? '<p class="kd-warn">Severe multicollinearity. Individual driver estimates ' +
          "may be unreliable; read the drivers as a set.</p>"
        : "";
      vifHtml = "<h4>Multicollinearity</h4>" + caveat +
        '<table class="kd-table"><thead><tr><th>Term</th><th>VIF</th>' +
        "<th>Concern</th></tr></thead><tbody>" + vrows + "</tbody></table>";
    }

    var b = m.base || {};
    var baseBits = [];
    if (b.n !== undefined) baseBits.push("n = " + num(b.n, 0));
    if (b.n_excluded !== undefined) baseBits.push(num(b.n_excluded, 0) + " excluded");
    if (b.weighted) {
      baseBits.push("weighted on " + esc(b.weight_var || "a weight"));
      if (b.n_eff !== undefined) baseBits.push("effective n = " + num(b.n_eff, 1));
      if (b.design_effect !== undefined) {
        baseBits.push("design effect = " + num(b.design_effect, 2));
      }
    }
    if (m.random_seed !== undefined) baseBits.push("seed " + num(m.random_seed, 0));

    var ciNote = "";
    var ciBlk = TR.KD && TR.KD.ci;
    if (ciBlk) {
      ciNote = "<h4>Intervals</h4><p>" +
        (ciBlk.iterations ? num(ciBlk.iterations, 0) + " bootstrap resamples, " : "") +
        esc(ciLabel()) + "s. " +
        esc(ciBlk.note || "") + "</p>";
    }

    return '<details class="kd-panel kd-diag"><summary>Diagnostics</summary>' +
      (fitBits.length ? "<h4>Model fit</h4><p>" + fitBits.join(" &middot; ") + "</p>" : "") +
      vifHtml + ciNote +
      (baseBits.length ? "<h4>Base</h4><p>" + baseBits.join(" &middot; ") + "</p>" : "") +
      "</details>";
  }

  // ---------------------------------------------------------------- render

  function bind(host) {
    host.querySelectorAll("[data-kd-method]").forEach(function (b) {
      b.addEventListener("click", function () {
        kd.state.method = b.getAttribute("data-kd-method");
        kd.render(host);
      });
    });
    host.querySelectorAll("[data-kd-segvar]").forEach(function (b) {
      b.addEventListener("click", function () {
        kd.state.segmentVar = b.getAttribute("data-kd-segvar");
        kd.render(host);
      });
    });
  }

  /**
   * Draw the tab.
   * @param {HTMLElement} host
   */
  kd.render = function (host) {
    if (!kd.available()) {
      host.innerHTML = '<div class="kd-panel"><p>This report carries no key driver ' +
        "results.</p></div>";
      return;
    }
    host.innerHTML =
      '<div class="kd-view">' +
      "<h2>Key drivers</h2>" +
      provenanceHtml(meta()) +
      importanceHtml() +
      quadrantHtml() +
      segmentsHtml() +
      diagnosticsHtml() +
      "</div>";
    bind(host);
  };

}(typeof window !== "undefined" ? window : this));
