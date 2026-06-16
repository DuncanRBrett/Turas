/**
 * Segment-native views for the data-centric report v2.
 *
 * This module is segment-SPECIFIC and layered ON TOP of the vendored engine
 * (it is bundled after assets/js/*). It registers a host-app tab set + routes
 * via TR.app (the backward-compatible seam in 24_shell.js), so the segment
 * report opens reader-in (Overview → Profiles) instead of the engine's
 * crosstab tabs. It reads the v2 data layer (TR.AGG): segments are the banner
 * columns, each question is a profile variable carrying a single mean row.
 *
 * Presentation only — no statistics here. Charts/heatmap use plain HTML + the
 * engine's CSS variables (var(--brand/--ink/--line/--green/--red/...)).
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;
  var seg = TR.segViews = {};

  function project()  { return (TR.AGG && TR.AGG.project) || {}; }
  function columns()  { return (TR.AGG && TR.AGG.columns) || []; }
  function questions(){ return (TR.AGG && TR.AGG.questions) || []; }
  function dec1(v)    { return fmt.num(v, "dec1"); }

  function totalIndex() {
    var c = columns();
    for (var i = 0; i < c.length; i++) if (c[i].group === "total") return i;
    return 0;
  }
  function segIndexes() {
    var out = [], c = columns();
    for (var i = 0; i < c.length; i++) if (c[i].group === "segment") out.push(i);
    return out;
  }
  // The single mean row each profile-variable question carries.
  function meanRow(q) {
    var rows = q.rows || [];
    for (var i = 0; i < rows.length; i++) if (rows[i].kind === "mean") return rows[i];
    return rows[0] || { pct: [] };
  }
  function baseN(colIdx) {
    var q = questions()[0];
    return (q && q.bases && q.bases[colIdx]) ? q.bases[colIdx].n : null;
  }

  // -------------------------------------------------------------------------
  // Overview — reader-in segment scorecards
  // -------------------------------------------------------------------------
  seg.overview = function (host) {
    var ti = totalIndex(), segs = segIndexes(), qs = questions();
    var totalN = baseN(ti);

    function gapLine(d, positive) {
      var arrow = positive ? "▲" : "▼";
      var colour = positive ? "var(--green)" : "var(--red)";
      return '<li style="margin:2px 0">' +
        '<span style="color:' + colour + ';font-weight:500">' + arrow + " " + dec1(d.sv) +
        '</span> <span style="color:var(--muted)">vs ' + dec1(d.ov) + " overall</span> &mdash; " +
        fmt.escapeHtml(d.title) + "</li>";
    }

    var cards = segs.map(function (si) {
      var col = columns()[si], n = baseN(si);
      var pct = (totalN && n != null) ? Math.round(n / totalN * 100) : null;
      var diffs = qs.map(function (q) {
        var r = meanRow(q), ov = r.pct[ti], sv = r.pct[si];
        return { title: q.title || q.code, ov: ov, sv: sv,
                 diff: (ov != null && sv != null) ? sv - ov : null };
      }).filter(function (d) { return d.diff != null; })
        .sort(function (a, b) { return b.diff - a.diff; });
      var highs = diffs.slice(0, 2);
      var lows  = diffs.slice(-2).reverse();

      return '<div style="background:var(--card);border:1px solid var(--line);' +
        'border-radius:var(--radius);padding:16px 18px;box-shadow:var(--shadow)">' +
        '<div style="display:flex;align-items:center;gap:8px;margin-bottom:2px">' +
        '<span style="display:inline-flex;width:24px;height:24px;border-radius:6px;' +
        'background:var(--brand);color:#fff;align-items:center;justify-content:center;' +
        'font-weight:500;font-size:13px">' + fmt.escapeHtml(col.letter || "") + "</span>" +
        '<h3 style="margin:0;font-size:16px;font-weight:500">' + fmt.escapeHtml(col.label) + "</h3></div>" +
        '<div style="color:var(--muted);font-size:13px;margin:0 0 12px">' +
        (n != null ? "n = " + fmt.num(n, "int") : "") +
        (pct != null ? " &middot; " + pct + "% of sample" : "") + "</div>" +
        '<div style="font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:var(--faint);margin-bottom:2px">Stands out for</div>' +
        '<ul style="margin:0 0 10px;padding-left:0;list-style:none;font-size:13px;line-height:1.45">' +
        (highs.length ? highs.map(function (d) { return gapLine(d, true); }).join("") : "<li style=\"color:var(--muted)\">–</li>") + "</ul>" +
        '<div style="font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:var(--faint);margin-bottom:2px">Lags on</div>' +
        '<ul style="margin:0;padding-left:0;list-style:none;font-size:13px;line-height:1.45">' +
        (lows.length ? lows.map(function (d) { return gapLine(d, false); }).join("") : "<li style=\"color:var(--muted)\">–</li>") + "</ul>" +
        "</div>";
    }).join("");

    host.innerHTML =
      '<section style="padding:8px 0 24px">' +
      '<h2 style="font-size:20px;font-weight:500;margin:8px 0 4px">' +
        fmt.escapeHtml(project().name || "Segmentation") + "</h2>" +
      '<p style="color:var(--muted);margin:0 0 18px;max-width:62ch;line-height:1.6">' +
        segs.length + " segments" +
        (totalN != null ? " from " + fmt.num(totalN, "int") + " respondents" : "") +
        ". Each card shows the segment’s size and the variables where it most over- and " +
        "under-indexes against the overall average. See the Profiles tab for the full matrix.</p>" +
      '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px">' +
        cards + "</div></section>";
  };

  // -------------------------------------------------------------------------
  // Profiles — variables × segments heatmap (shaded vs the overall mean)
  // -------------------------------------------------------------------------
  function tint(diff, scaleMax) {
    if (diff == null) return "";
    var span = (scaleMax || 10) * 0.25;                 // ±25% of scale = full intensity
    var a = Math.max(0, Math.min(1, Math.abs(diff) / span)) * 0.55;
    var rgb = diff >= 0 ? "27,110,83" : "179,55,47";    // --green / --red
    return "background:rgba(" + rgb + "," + a.toFixed(2) + ")";
  }

  // Variables in display order: sorted by a segment's gap vs overall when a
  // sort column is set (segment comparison — decision A, no microdata), else
  // the natural order.
  function rowsForState(state) {
    var ti = totalIndex(), qs = questions().slice();
    if (state.sortCol != null) {
      qs.sort(function (a, b) {
        function gap(q) {
          var r = meanRow(q), ov = r.pct[ti], v = r.pct[state.sortCol];
          return (ov != null && v != null) ? (v - ov) : -Infinity;
        }
        return gap(b) - gap(a);
      });
    }
    return qs;
  }

  // Pure render of the profiles table for a {sortCol, mode} state — exposed so
  // the sort/compare logic is testable without a DOM; seg.profiles wires it.
  seg.profilesHtml = function (state) {
    state = state || { sortCol: null, mode: "mean" };
    var ti = totalIndex(), segs = segIndexes(), cols = columns();
    var order = [ti].concat(segs);
    var qs = rowsForState(state);

    function chip(attr, val, label, on) {
      return '<button ' + attr + '="' + val + '" style="font:inherit;font-size:12px;cursor:pointer;' +
        'border:1px solid ' + (on ? "var(--brand)" : "var(--line)") + ';border-radius:6px;padding:3px 9px;' +
        'background:' + (on ? "var(--brand)" : "var(--card)") + ';color:' + (on ? "#fff" : "var(--ink)") +
        '">' + label + "</button>";
    }
    var controls =
      '<div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:0 0 12px">' +
      '<span style="font-size:12px;color:var(--faint)">Rank by</span>' +
      segs.map(function (ci) {
        return chip("data-sortcol", ci, fmt.escapeHtml(cols[ci].label) +
          (cols[ci].letter ? " " + cols[ci].letter : ""), state.sortCol === ci);
      }).join("") +
      (state.sortCol != null ? chip("data-sortcol", -1, "Clear", false) : "") +
      '<span style="width:12px"></span><span style="font-size:12px;color:var(--faint)">Show</span>' +
      chip("data-mode", "mean", "Means", state.mode !== "delta") +
      chip("data-mode", "delta", "vs overall", state.mode === "delta") + "</div>";

    var head = '<th style="text-align:left;position:sticky;left:0;background:var(--card);' +
      'padding:8px 10px;border-bottom:2px solid var(--line)">Variable</th>' +
      order.map(function (ci) {
        var c = cols[ci], hl = state.sortCol === ci;
        return '<th style="padding:8px 10px;border-bottom:2px solid var(--line);font-weight:500;' +
          'min-width:78px' + (hl ? ";background:rgba(50,51,103,.10)" : "") + '">' + fmt.escapeHtml(c.label) +
          (c.letter ? ' <span style="color:var(--faint)">' + c.letter + "</span>" : "") + "</th>";
      }).join("");

    var body = qs.map(function (q) {
      var r = meanRow(q), ov = r.pct[ti], sm = q.scale_max || 10;
      var cells = order.map(function (ci) {
        var v = r.pct[ci], isTotal = ci === ti, hl = state.sortCol === ci;
        var diff = (v != null && ov != null) ? v - ov : null;
        var show = (state.mode === "delta" && !isTotal)
          ? (diff == null ? "–" : (diff >= 0 ? "+" : "") + fmt.num(diff, "dec1"))
          : fmt.num(v, "dec1");
        var style = "padding:7px 10px;text-align:center;border-bottom:1px solid var(--line);" +
          (isTotal ? "color:var(--muted);font-weight:500" : tint(diff, sm)) +
          (hl ? ";outline:2px solid rgba(50,51,103,.18);outline-offset:-2px" : "");
        return '<td style="' + style + '">' + show + "</td>";
      }).join("");
      return '<tr><td style="text-align:left;position:sticky;left:0;background:var(--card);' +
        'padding:7px 10px;border-bottom:1px solid var(--line)">' +
        fmt.escapeHtml(q.title || q.code) + "</td>" + cells + "</tr>";
    }).join("");

    return '<section style="padding:8px 0 24px">' +
      '<h2 style="font-size:20px;font-weight:500;margin:8px 0 4px">Segment profiles</h2>' +
      '<p style="color:var(--muted);margin:0 0 12px;max-width:62ch;line-height:1.6">Mean score per ' +
      'variable by segment, shaded vs the overall average. Click a segment to rank the variables it ' +
      'most over- and under-indexes on; switch to “vs overall” to read the gaps directly.</p>' + controls +
      '<div style="overflow:auto"><table style="border-collapse:collapse;font-size:13px;width:100%">' +
      "<thead><tr>" + head + "</tr></thead><tbody>" + body + "</tbody></table></div></section>";
  };

  seg.profiles = function (host) {
    var state = { sortCol: null, mode: "mean" };
    function draw() {
      host.innerHTML = seg.profilesHtml(state);
      // Fresh listeners each render (innerHTML replaced the old nodes — no stacking).
      host.querySelectorAll("[data-sortcol]").forEach(function (b) {
        b.addEventListener("click", function () {
          var ci = parseInt(b.getAttribute("data-sortcol"), 10);
          state.sortCol = (ci < 0 || state.sortCol === ci) ? null : ci;
          draw();
        });
      });
      host.querySelectorAll("[data-mode]").forEach(function (b) {
        b.addEventListener("click", function () { state.mode = b.getAttribute("data-mode"); draw(); });
      });
    }
    draw();
  };

  // -------------------------------------------------------------------------
  // Variable importance — how strongly each variable separates the segments
  // (ANOVA F carried on the question by the data-layer writer)
  // -------------------------------------------------------------------------
  seg.importance = function (host) {
    var rows = questions().map(function (q) {
      return { title: q.title || q.code,
               f: (typeof q.f_stat === "number" && !isNaN(q.f_stat)) ? q.f_stat : null,
               p: (typeof q.p_value === "number" && !isNaN(q.p_value)) ? q.p_value : null };
    }).filter(function (d) { return d.f != null; })
      .sort(function (a, b) { return b.f - a.f; });

    var intro = '<h2 style="font-size:20px;font-weight:500;margin:8px 0 4px">Variable importance</h2>';
    if (!rows.length) {
      host.innerHTML = '<section style="padding:8px 0 24px">' + intro +
        '<p style="color:var(--muted)">No differentiation statistics are available for this solution.</p></section>';
      return;
    }
    var maxF = rows[0].f || 1;
    var bars = rows.map(function (d) {
      var w = Math.max(2, Math.round(d.f / maxF * 100));
      var sig = (d.p != null && d.p < 0.05)
        ? '<span style="color:var(--green)">sig.</span>'
        : (d.p != null ? '<span style="color:var(--faint)">ns</span>' : "");
      return '<div style="display:grid;grid-template-columns:minmax(140px,220px) 1fr 96px;' +
        'align-items:center;gap:10px;margin:5px 0">' +
        '<div style="font-size:13px">' + fmt.escapeHtml(d.title) + "</div>" +
        '<div style="background:var(--soft);border-radius:5px;overflow:hidden">' +
        '<div style="background:var(--brand);height:16px;width:' + w + '%"></div></div>' +
        '<div style="font-size:12px;color:var(--muted);text-align:right">F=' +
        fmt.num(d.f, "dec1") + " " + sig + "</div></div>";
    }).join("");
    host.innerHTML =
      '<section style="padding:8px 0 24px">' + intro +
      '<p style="color:var(--muted);margin:0 0 14px;max-width:62ch;line-height:1.6">How strongly each ' +
      'variable distinguishes the segments (one-way ANOVA F across segments — longer bars separate the ' +
      'segments more). “sig.” marks variables that differ significantly at p &lt; 0.05.</p>' +
      bars + "</section>";
  };

  // -------------------------------------------------------------------------
  // Golden questions — the smallest set of questions that types a respondent
  // into a segment (RF predictive model + cumulative-accuracy curve). A key
  // operational output: which questions to ask to allocate someone in future.
  // -------------------------------------------------------------------------
  seg.golden = function (host) {
    var g = TR.AGG && TR.AGG.golden;
    if (!g || !g.questions || !g.questions.length) {
      host.innerHTML = '<section style="padding:8px 0 24px">' +
        '<h2 style="font-size:20px;font-weight:500;margin:8px 0 4px">Golden questions</h2>' +
        '<p style="color:var(--muted)">Golden questions were not computed for this solution.</p></section>';
      return;
    }
    var qs = g.questions.slice().sort(function (a, b) { return (a.rank || 0) - (b.rank || 0); });
    var incr = seg.goldenIncrements(qs);
    var sel = qs.map(function () { return true; });

    function refreshStat() {
      var el = host.querySelector("[data-estimate]");
      if (!el) return;
      var nSel = sel.filter(Boolean).length;
      var est = seg.goldenEstimate(incr, sel, g.overall_accuracy);
      el.innerHTML = 'Using <strong>' + nSel + ' of ' + qs.length + '</strong> questions &middot; ' +
        'estimated accuracy <strong>' + Math.round(est * 100) + '%</strong>';
    }
    host.innerHTML = seg.goldenHtml(g, qs, incr, sel);
    host.querySelectorAll("[data-gq]").forEach(function (cb) {
      cb.addEventListener("change", function () {
        sel[parseInt(cb.getAttribute("data-gq"), 10)] = cb.checked;
        refreshStat();   // update the live stat only; checkbox state persists in `sel`
      });
    });
  };

  // Per-question accuracy increment (cumulative[i] − cumulative[i−1]); the first
  // is the single-question accuracy. Pure + exposed for the node gate.
  seg.goldenIncrements = function (qs) {
    return qs.map(function (q, i) {
      var c = q.cumulative_accuracy, p = i > 0 ? qs[i - 1].cumulative_accuracy : 0;
      return (c != null && p != null) ? (c - p) : null;
    });
  };
  // Estimated accuracy for a selected subset = sum of its increments (exact for
  // a top-N prefix; an approximation otherwise), capped at the full-model OOB.
  seg.goldenEstimate = function (incr, sel, overall) {
    var s = 0;
    for (var i = 0; i < incr.length; i++) if (sel[i] && incr[i] != null) s += incr[i];
    return (overall != null) ? Math.min(s, overall) : s;
  };
  seg.goldenHtml = function (g, qs, incr, sel) {
    var P = function (x) { return (x == null || isNaN(x)) ? "–" : Math.round(x * 100) + "%"; };
    var overall = g.overall_accuracy, oob = (overall != null) ? Math.round((1 - overall) * 100) : null;
    var est = seg.goldenEstimate(incr, sel, overall), nSel = sel.filter(Boolean).length;

    var trs = qs.map(function (q, i) {
      var gain = (i > 0 && incr[i] != null)
        ? ' <span style="color:' + (incr[i] >= 0 ? "var(--green)" : "var(--red)") + '">(' +
          (incr[i] >= 0 ? "+" : "−") + Math.abs(incr[i] * 100).toFixed(1) + " pp)</span>" : "";
      return '<tr><td style="padding:6px 8px;border-bottom:1px solid var(--line)">' +
        '<input type="checkbox" data-gq="' + i + '"' + (sel[i] ? " checked" : "") + "></td>" +
        '<td style="padding:6px 8px;border-bottom:1px solid var(--line);color:var(--muted)">' + q.rank + "</td>" +
        '<td style="padding:6px 10px;border-bottom:1px solid var(--line)">' + fmt.escapeHtml(q.title || q.code) + "</td>" +
        '<td style="padding:6px 10px;border-bottom:1px solid var(--line);text-align:right;color:var(--muted)">' +
        (q.importance_pct != null ? Math.round(q.importance_pct) + "%" : "–") + "</td>" +
        '<td style="padding:6px 10px;border-bottom:1px solid var(--line);text-align:right">' +
        P(q.cumulative_accuracy) + gain + "</td></tr>";
    }).join("");

    var perSeg = (g.per_segment && g.per_segment.length)
      ? '<div style="margin-top:12px;font-size:12.5px;color:var(--muted)">Per-segment hit rate: ' +
        g.per_segment.map(function (s) { return fmt.escapeHtml(s.label) + " " + P(s.accuracy); }).join(" · ") + "</div>"
      : "";

    return '<section style="padding:8px 0 24px">' +
      '<h2 style="font-size:20px;font-weight:500;margin:8px 0 4px">Golden questions</h2>' +
      '<p style="color:var(--muted);margin:0 0 12px;max-width:64ch;line-height:1.6">The survey items that best ' +
      'predict which segment a respondent belongs to (random-forest typing model). Tick questions off to find the ' +
      'smallest short-form screener that still types people accurately. These differ from the Importance tab: ' +
      'importance (ANOVA) tells you what <em>defines</em> the segments; golden questions tell you what ' +
      '<em>identifies</em> them — a strong differentiator can be a weaker standalone predictor when its signal ' +
      'overlaps with correlated questions.</p>' +
      '<div style="background:var(--soft);border-radius:8px;padding:12px 14px;margin:0 0 14px">' +
      (overall != null ? '<div style="font-size:13px"><strong style="color:var(--ink)">Random-forest accuracy: ' +
        Math.round(overall * 100) + "%</strong> using all " + qs.length + " questions" +
        (oob != null ? " (OOB error " + oob + "%)" : "") + ".</div>" : "") +
      '<div data-estimate style="font-size:13px;margin-top:4px">Using <strong>' + nSel + " of " + qs.length +
      "</strong> questions &middot; estimated accuracy <strong>" + Math.round(est * 100) + "%</strong></div></div>" +
      '<div style="overflow:auto"><table style="border-collapse:collapse;font-size:13px;width:100%"><thead><tr>' +
      '<th style="padding:7px 8px;border-bottom:2px solid var(--line)"></th>' +
      '<th style="padding:7px 8px;border-bottom:2px solid var(--line);text-align:left;color:var(--faint);font-weight:500">#</th>' +
      '<th style="padding:7px 10px;border-bottom:2px solid var(--line);text-align:left;font-weight:500">Question</th>' +
      '<th style="padding:7px 10px;border-bottom:2px solid var(--line);text-align:right;font-weight:500">Importance</th>' +
      '<th style="padding:7px 10px;border-bottom:2px solid var(--line);text-align:right;font-weight:500">Accuracy added</th>' +
      "</tr></thead><tbody>" + trs + "</tbody></table></div>" + perSeg +
      '<p style="font-size:11.5px;color:var(--faint);margin-top:10px;max-width:64ch">Estimated accuracy assumes ' +
      "questions are added in rank order; a custom subset is an approximation — confirm a final screener on fresh data.</p></section>";
  };

  // ===========================================================================
  // Chart toolkit — polished, on-brand SVG via the engine's TR.svg primitives.
  // ===========================================================================
  var S = TR.svg;
  function brandHex()  { return (TR.charts && TR.charts.brandOf) ? TR.charts.brandOf() : "#323367"; }
  function accentHex() { return (TR.charts && TR.charts.accentOf) ? TR.charts.accentOf() : "#CC9900"; }
  function letterOf(i) { return i < 26 ? String.fromCharCode(65 + i) : String(i + 1); }

  // Horizontal bar chart. items = [{label, value, valueLabel}].
  function segHBarsSvg(items, opts) {
    opts = opts || {};
    var n = items.length, rowH = 32, top = 6, gut = opts.gutter || 150,
        barW = opts.barW || 300, pad = 10;
    var w = gut + barW + 110, h = top + n * rowH + pad, colour = opts.colour || brandHex();
    var max = opts.max || Math.max.apply(null, items.map(function (d) { return d.value || 0; })) || 1;
    var scale = S.linear(max, barW), els = [];
    items.forEach(function (d, i) {
      var y = top + i * rowH;
      els.push(S.text(gut - 8, y + rowH / 2 + 4, d.label, { "text-anchor": "end", "font-size": 13, fill: "#1e293b" }));
      els.push(S.el("rect", { x: gut, y: y + 6, width: barW, height: 16, rx: 5, fill: "#f3f4f8" }));
      els.push(S.el("rect", { x: gut, y: y + 6, width: Math.max(2, scale(d.value || 0)), height: 16, rx: 5, fill: colour }));
      els.push(S.text(gut + barW + 8, y + rowH / 2 + 4, d.valueLabel != null ? d.valueLabel : String(d.value),
        { "font-size": 12, fill: "#64748b" }));
    });
    return S.root(w, h, opts.title || "bar chart", S.el("g", {}, els.join("")));
  }

  // Square matrix heatmap (letters on the axes). matrix[i][j] numeric.
  function segMatrixSvg(matrix, opts) {
    opts = opts || {};
    var k = matrix.length, cell = opts.cell || 52, gut = 30, top = 24, pad = 10;
    var w = gut + k * cell + pad, h = top + k * cell + pad, colour = opts.colour || brandHex();
    var max = opts.max || 1, els = [], j, i, jj;
    for (j = 0; j < k; j++) {
      els.push(S.text(gut + j * cell + cell / 2, top - 8, letterOf(j),
        { "text-anchor": "middle", "font-size": 12, "font-weight": 500, fill: "#5f5e5a" }));
    }
    for (i = 0; i < k; i++) {
      els.push(S.text(gut - 8, top + i * cell + cell / 2 + 4, letterOf(i),
        { "text-anchor": "end", "font-size": 12, "font-weight": 500, fill: "#5f5e5a" }));
      for (jj = 0; jj < k; jj++) {
        var v = matrix[i][jj], blank = opts.diagBlank && i === jj;
        var strength = (max > 0) ? Math.max(0.06, Math.min(1, v / max)) : 0.06;
        els.push(S.el("rect", { x: gut + jj * cell + 2, y: top + i * cell + 2, width: cell - 4,
          height: cell - 4, rx: 5, fill: blank ? "#f3f4f8" : S.shade(colour, strength) }));
        if (!blank) {
          var label = opts.fmt ? opts.fmt(v) : String(v);
          if (label !== "") {
            els.push(S.text(gut + jj * cell + cell / 2, top + i * cell + cell / 2 + 4, label,
              { "text-anchor": "middle", "font-size": 12, fill: (max > 0 && v / max > 0.55) ? "#fff" : "#2c2c2a" }));
          }
        }
      }
    }
    return S.root(w, h, opts.title || "matrix", S.el("g", {}, els.join("")));
  }

  // Legend mapping the axis letters back to segment labels.
  function letterLegend(labels) {
    return '<div style="font-size:12.5px;color:var(--muted);margin-top:8px">' +
      labels.map(function (l, i) {
        return '<span style="margin-right:14px"><strong style="color:var(--ink)">' + letterOf(i) +
          "</strong> " + fmt.escapeHtml(l) + "</span>";
      }).join("") + "</div>";
  }

  // -------------------------------------------------------------------------
  // Segment distinctiveness (overlap) — pairwise distance between centroids
  // -------------------------------------------------------------------------
  seg.overlap = function (host) {
    var o = TR.AGG && TR.AGG.overlap;
    var head = '<h2 style="font-size:20px;font-weight:500;margin:8px 0 4px">Segment distinctiveness</h2>';
    if (!o || !o.distance || !o.labels || o.labels.length < 2) {
      host.innerHTML = '<section style="padding:8px 0 24px">' + head +
        '<p style="color:var(--muted)">Distinctiveness needs at least two segments.</p></section>';
      return;
    }
    var labels = o.labels, M = o.distance, k = labels.length;
    var max = 0, minV = Infinity, maxV = -Infinity, minPair = null, maxPair = null, i, j;
    for (i = 0; i < k; i++) for (j = 0; j < k; j++) if (i !== j) {
      var v = M[i][j];
      if (v > max) max = v;
      if (v > maxV) { maxV = v; maxPair = [i, j]; }
      if (v < minV) { minV = v; minPair = [i, j]; }
    }
    var heat = segMatrixSvg(M, { max: max, colour: accentHex(), diagBlank: true,
      fmt: function (x) { return x.toFixed(1); }, title: "Segment distance matrix" });
    var callout = (maxPair && minPair)
      ? '<p style="font-size:13px;color:var(--muted);margin-top:6px;max-width:62ch">Most distinct: ' +
        '<strong style="color:var(--ink)">' + letterOf(maxPair[0]) + " &harr; " + letterOf(maxPair[1]) +
        "</strong> (" + maxV.toFixed(1) + '). Closest / most overlap: <strong style="color:var(--ink)">' +
        letterOf(minPair[0]) + " &harr; " + letterOf(minPair[1]) + "</strong> (" + minV.toFixed(1) + ").</p>"
      : "";
    host.innerHTML = '<section style="padding:8px 0 24px">' + head +
      '<p style="color:var(--muted);margin:0 0 14px;max-width:64ch;line-height:1.6">How far apart the segments ' +
      'sit in the clustering space (distance between their centres). Larger numbers = more distinct, ' +
      'well-separated segments; small numbers = segments that overlap and can be harder to tell apart.</p>' +
      '<div style="overflow:auto">' + heat + "</div>" + letterLegend(labels) + callout + "</section>";
  };

  // -------------------------------------------------------------------------
  // Segment vulnerability — boundary respondents who could switch segment
  // -------------------------------------------------------------------------
  seg.vulnerability = function (host) {
    var v = TR.AGG && TR.AGG.vulnerability;
    var head = '<h2 style="font-size:20px;font-weight:500;margin:8px 0 4px">Segment vulnerability</h2>';
    if (!v || !v.segments || !v.segments.length) {
      host.innerHTML = '<section style="padding:8px 0 24px">' + head +
        '<p style="color:var(--muted)">Vulnerability analysis was not computed for this solution.</p></section>';
      return;
    }
    var overall = v.overall_pct_vulnerable;
    var bars = segHBarsSvg(v.segments.map(function (s) {
      return { label: s.label, value: s.pct_vulnerable,
        valueLabel: (s.pct_vulnerable != null ? Math.round(s.pct_vulnerable) + "%" : "–") +
          (s.avg_confidence != null ? "  ·  conf " + s.avg_confidence.toFixed(2) : "") };
    }), { max: Math.max(5, Math.max.apply(null, v.segments.map(function (s) { return s.pct_vulnerable || 0; }))),
      colour: brandHex(), gutter: 150, barW: 280, title: "Percent vulnerable by segment" });

    var switchBlock = "";
    var sw = v.switching;
    if (sw && sw.matrix && sw.labels && sw.labels.length) {
      var smax = 0;
      sw.matrix.forEach(function (r, ri) { r.forEach(function (x, ci) { if (ri !== ci && x > smax) smax = x; }); });
      var smat = segMatrixSvg(sw.matrix, { max: smax || 1, colour: brandHex(), diagBlank: true,
        fmt: function (x) { return x ? String(x) : ""; }, title: "Switching matrix" });
      switchBlock = '<h3 style="font-size:15px;font-weight:500;margin:20px 0 4px">Where at-risk members would move</h3>' +
        '<p style="color:var(--muted);margin:0 0 10px;max-width:62ch;font-size:13px">Row = current segment; ' +
        'column = the segment its boundary members sit closest to.</p>' +
        '<div style="overflow:auto">' + smat + "</div>" + letterLegend(sw.labels);
    }
    host.innerHTML = '<section style="padding:8px 0 24px">' + head +
      '<p style="color:var(--muted);margin:0 0 12px;max-width:64ch;line-height:1.6">Respondents who sit close to ' +
      'the boundary with another segment — their assignment is less certain, so they could plausibly belong ' +
      'elsewhere. A segment with many such members is less stable.</p>' +
      (overall != null ? '<div style="background:var(--soft);border-radius:8px;padding:12px 14px;margin:0 0 14px;font-size:13px">' +
        '<strong style="color:var(--ink)">' + Math.round(overall) + '% of respondents sit near a boundary</strong>' +
        (v.threshold != null ? " (assignment confidence below " + v.threshold + ")." : ".") + "</div>" : "") +
      '<div style="overflow:auto">' + bars + "</div>" + switchBlock + "</section>";
  };

  // -------------------------------------------------------------------------
  // Register the host-app tab set. "report" has no route here, so it falls
  // through to the engine's generic Report (metadata) tab.
  // -------------------------------------------------------------------------
  TR.app = {
    tabs: [["seg_overview", "Overview"], ["seg_profiles", "Profiles"],
           ["seg_golden", "Golden questions"], ["seg_importance", "Importance"],
           ["seg_overlap", "Distinctiveness"], ["seg_vulnerability", "Vulnerability"],
           ["report", "Report"]],
    routes: { seg_overview: seg.overview, seg_profiles: seg.profiles,
              seg_golden: seg.golden, seg_importance: seg.importance,
              seg_overlap: seg.overlap, seg_vulnerability: seg.vulnerability },
    defaultTab: "seg_overview"
  };

})(typeof window !== "undefined" ? window : globalThis);
