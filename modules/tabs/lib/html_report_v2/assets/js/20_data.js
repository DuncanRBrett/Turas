/**
 * v2 data layer — access to the extracted aggregates (TR.AGG), synthetic
 * microdata (TR.MICRO) and prior wave (TR.PREV), plus report state and
 * URL-hash (de)serialisation. Pure except for the state singleton.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var d2 = TR.d2 = {};

  /** Report state (single source of truth; UI re-renders from this). */
  d2.state = {
    tab: "takeout",         // Pattern recognition is the landing tab (id stays "takeout")
    banner: null,           // banner group id ("Q002") or "custom:<qcode>"
    filters: [],            // [{q: "Q006", rows: [9, 10]}]
    showCounts: false,
    showIntervals: false,   // 95% interval ranges under every value
    heatmap: "bars",        // cell magnitude: "bars" | "heat" | "off"
    showChart: false,
    showDeltas: true,
    showWaveStrip: true,    // per-question wave history strip
    showDetail: true,       // category rows visible
    showSummary: true,      // NET + index rows visible
    sigMode: "95",          // significance display: off | 95 | dual (95+80)
    chartType: "bar",
    chartKind: "auto",      // chart rows: auto | detail | summary (NETs) | mean (Index)
    chartColLabels: ["Total"],  // chart columns by label (multi-select)
    colMenuOpen: false,     // columns panel visibility survives re-renders
    movedScope: null,       // "key" | "all" (null = use project config)
    hiddenCols: {},         // {bannerSelection: [column labels]}
    hiddenRows: {},         // {qcode: [row labels]} — hidden from the table
    hiddenChartRows: {},    // {qcode: [row labels]} — excluded from the chart
    sorts: {},              // {qcode: {col, dir}}
    activeQ: null
  };

  /** Row scope derived from the two visibility toggles. */
  d2.rowScope = function () {
    var s = d2.state;
    if (s.showDetail && !s.showSummary) return "detail";
    if (!s.showDetail && s.showSummary) return "summary";
    return "all";
  };

  /** Human-readable description of the active filters ("" when none). */
  d2.filterDescription = function () {
    return d2.state.filters.map(function (f) {
      var q = d2.questionByCode(f.q);
      var labels = f.rows.map(function (ri) {
        return q && q.rows[ri] ? q.rows[ri].label : "?";
      });
      // collapse member lists back to a NET label when they match one
      if (q && q.net_members) {
        var keys = Object.keys(q.net_members);
        for (var i = 0; i < keys.length; i++) {
          var members = q.net_members[keys[i]];
          if (members.length === f.rows.length &&
              members.every(function (m) { return f.rows.indexOf(m) !== -1; })) {
            labels = [q.rows[parseInt(keys[i], 10)].label];
            break;
          }
        }
      }
      return (q ? q.code : f.q) + ": " + labels.join(" / ");
    }).join(" · ");
  };

  /** Human-readable description of the current banner selection. */
  d2.bannerDescription = function (banner) {
    banner = banner || d2.state.banner;
    if (banner && banner.indexOf("custom:") === 0) {
      var bits = banner.split(":");
      var q = d2.questionByCode(bits[1]);
      return "Custom banner — " + (q ? q.code + " " + q.title : bits[1]) +
        (bits[2] === "net" ? " (summary groupings)" : " (detail categories)");
    }
    var group = (TR.AGG.banner_groups || []).filter(function (g) {
      return g.id === banner;
    })[0];
    return "Banner: " + (group ? group.name : banner);
  };

  /** Tracking config: project.tracking with safe defaults. */
  d2.tracking = function () {
    var cfg = (TR.AGG.project && TR.AGG.project.tracking) || {};
    var available = !!(TR.PREV && TR.PREV.waves && TR.PREV.waves.length);
    return {
      enabled: cfg.enabled !== false && available,
      defaultScope: cfg.default_scope === "all" ? "all" : "key",
      waves: available ? TR.PREV.waves.filter(function (w) {
        return !w.current;   // the current wave is the live AGG, not history
      }).map(function (w) {
        return { wave: w.wave, year: w.year, label: w.label };
      }) : []
    };
  };

  /** Hidden column labels for the current banner selection. */
  d2.hiddenFor = function (banner) {
    return d2.state.hiddenCols[banner] || [];
  };

  /** Validate the three payloads enough to boot safely. */
  d2.validate = function (agg, micro, prev) {
    var errors = [];
    if (!agg || !Array.isArray(agg.questions) || !agg.questions.length) {
      errors.push({ code: "DATA_NO_QUESTIONS", message: "aggregates payload empty" });
    }
    if (!agg || !Array.isArray(agg.columns) || !agg.columns.length) {
      errors.push({ code: "DATA_NO_COLUMNS", message: "banner columns missing" });
    }
    if (prev && !Array.isArray(prev.waves)) {
      errors.push({ code: "DATA_WAVES_SHAPE",
        message: "prior-wave island is not a waves payload (schema_version 2)" });
    }
    if (micro && agg) {
      var n = micro.n;
      Object.keys(micro.banner_vars || {}).forEach(function (g) {
        if (micro.banner_vars[g].length !== n) {
          errors.push({ code: "DATA_MICRO_LEN", message: "banner var " + g + " length mismatch" });
        }
      });
      (agg.questions || []).forEach(function (q) {
        var a = micro.answers && micro.answers[q.code];
        if (!a || a.length !== n) {
          errors.push({ code: "DATA_MICRO_Q", message: "microdata missing/short for " + q.code });
        }
      });
    }
    return { ok: errors.length === 0, errors: errors };
  };

  d2.questionByCode = function (code) {
    if (!d2._qIndex) {
      d2._qIndex = {};
      TR.AGG.questions.forEach(function (q) { d2._qIndex[q.code] = q; });
    }
    return d2._qIndex[code] || null;
  };

  /** Column indexes belonging to a banner group id. */
  d2.groupCols = function (groupId) {
    var out = [];
    TR.AGG.columns.forEach(function (c, i) {
      if (c.group === groupId) out.push(i);
    });
    return out;
  };

  /** First built-in banner id, or "" for a Total-only report (no banner
   *  groups). Used wherever a custom / heat banner falls back to a real one so
   *  Total-only studies never dereference an empty banner_groups list. */
  d2.firstBanner = function () {
    return (TR.AGG.banner_groups && TR.AGG.banner_groups.length)
      ? TR.AGG.banner_groups[0].id : "";
  };

  /** Ordered categories with their question codes. */
  d2.categories = function () {
    var seen = {}, order = [];
    TR.AGG.questions.forEach(function (q) {
      if (!seen[q.category]) {
        seen[q.category] = { title: q.category, codes: [] };
        order.push(seen[q.category]);
      }
      seen[q.category].codes.push(q.code);
    });
    return order;
  };

  /** Category rows of a question (the filterable/answerable values). */
  d2.catRows = function (q) {
    var out = [];
    q.rows.forEach(function (r, i) {
      if (r.kind === "category") out.push({ index: i, label: r.label });
    });
    return out;
  };

  /** Box-category NET rows of a hidden-scale question — groupings that exist
   *  only as per-respondent box membership (TR.MICRO.boxes), with no shown
   *  category rows to decompose into. These back box filters and the box
   *  custom-banner. The box index equals the row index (mirrors the box
   *  recompute in netRow / stats.boxCounts). Empty when the question has no box
   *  membership, or its NETs decompose into shown categories (net_members). */
  d2.boxRows = function (q) {
    if (!TR.MICRO || !TR.MICRO.boxes || !TR.MICRO.boxes[q.code]) return [];
    var out = [];
    q.rows.forEach(function (r, ri) {
      var isDiff = !!(q.net_diffs && q.net_diffs[String(ri)]);
      var hasMembers = !!(q.net_members && q.net_members[String(ri)]);
      if (r.kind === "net" && !isDiff && !hasMembers) {
        out.push({ index: ri, label: r.label });
      }
    });
    return out;
  };

  d2.hasMicrodata = function () {
    return !!(TR.MICRO && TR.MICRO.answers);
  };

  d2.filtersActive = function () {
    return d2.state.filters.length > 0;
  };

  /* ---------- hash state ---------- */

  d2.encodeHash = function () {
    var s = d2.state, parts = ["tab=" + s.tab];
    if (s.activeQ) parts.push("q=" + s.activeQ);
    if (s.banner) parts.push("banner=" + s.banner);
    if (s.showCounts) parts.push("count=1");
    if (s.showIntervals) parts.push("iv=1");
    if (s.showChart) parts.push("chart=1");
    if (s.heatmap !== "bars") parts.push("heat=" + s.heatmap);
    if (s.filters.length) {
      parts.push("filter=" + s.filters.map(function (f) {
        return f.q + ":" + (f.box ? "b" : "") + f.rows.join(",");
      }).join("|"));
    }
    return "#" + parts.join("&");
  };

  d2.decodeHash = function (hash) {
    var s = d2.state;
    String(hash || "").replace(/^#/, "").split("&").forEach(function (kv) {
      var eq = kv.indexOf("=");
      if (eq < 0) return;
      var k = kv.slice(0, eq), v = decodeURIComponent(kv.slice(eq + 1));
      if (k === "tab") s.tab = v;
      if (k === "q") s.activeQ = v;
      if (k === "banner") s.banner = v;
      if (k === "count") s.showCounts = v === "1";
      if (k === "iv") s.showIntervals = v === "1";
      if (k === "chart") s.showChart = v === "1";
      if (k === "heat") s.heatmap = v === "0" ? "off" : v;
      if (k === "filter") {
        s.filters = v.split("|").map(function (part) {
          var bits = part.split(":");
          var spec = bits[1] || "", box = spec.charAt(0) === "b";
          return { q: bits[0], box: box,
            rows: (box ? spec.slice(1) : spec).split(",")
              .map(Number).filter(function (x) { return !isNaN(x); }) };
        }).filter(function (f) {
          if (!f.q || !f.rows.length) return false;
          // a typo'd or crafted hash must not silently zero every base: the
          // question must exist and every row index must be a real filterable
          // value — a category row, or a box NET row for box filters (boot
          // decodes after the islands parse).
          if (!TR.AGG) return true;
          var q = d2.questionByCode(f.q);
          if (!q) return false;
          if (f.box) {
            return !!(TR.MICRO && TR.MICRO.boxes && TR.MICRO.boxes[f.q]) &&
              f.rows.every(function (ri) {
                return q.rows[ri] && q.rows[ri].kind === "net";
              });
          }
          return f.rows.every(function (ri) {
            return q.rows[ri] && q.rows[ri].kind === "category";
          });
        });
      }
    });
  };

  d2.pushHash = function () {
    if (typeof history !== "undefined" && history.replaceState) {
      history.replaceState(null, "", d2.encodeHash());
    }
  };

})(typeof window !== "undefined" ? window : globalThis);
