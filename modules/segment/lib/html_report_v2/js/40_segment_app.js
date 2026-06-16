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
  // Register the host-app tab set. "report" has no route here, so it falls
  // through to the engine's generic Report (metadata) tab.
  // -------------------------------------------------------------------------
  TR.app = {
    tabs: [["seg_overview", "Overview"], ["seg_profiles", "Profiles"],
           ["seg_importance", "Importance"], ["report", "Report"]],
    routes: { seg_overview: seg.overview, seg_profiles: seg.profiles,
              seg_importance: seg.importance },
    defaultTab: "seg_overview"
  };

})(typeof window !== "undefined" ? window : globalThis);
