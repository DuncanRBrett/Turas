/**
 * Differences view — significant banner gaps for LAY readers.
 *
 * The old flat table (Question | Row | Column | Value | Total | Higher
 * than) read like database output. This view groups findings by QUESTION
 * into ranked cards; each line inside a card is one group that stands
 * out, told as a sentence with a two-bar comparison (group vs overall)
 * and the groups it is statistically ahead of. Same deterministic
 * engine underneath: a finding appears when a column is significantly
 * higher than two or more sibling columns at 95% (pooled z), ranked by
 * sig-count × gap. The shared confidence explainer renders at the foot.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var views = TR.views;
  var MAX_FINDINGS = 80;        // ranked cut-off, surfaced in the UI note
  var diffBanner = null;        // banner override (default: report banner)
  var diffSort = "standout";    // "standout" (top score) | "question"

  /**
   * "The rest" — everyone EXCEPT this group — for one question row, as a
   * percentage on the table's own base logic. Recomputed from microdata so it
   * is weighted-safe and reconciles exactly with the published group / overall
   * figures (group hits + rest hits = overall hits, over the matching bases).
   * Falls back to the exact unweighted count identity when a report carries no
   * microdata. Returns null when the row has no single base (score-difference
   * NETs) or the rest is empty.
   */
  function restPct(q, ri, groupMember, mask, groupCell, totalCell, groupBase, totalBase) {
    if (q.net_diffs && q.net_diffs[String(ri)] !== undefined) return null;
    if (groupMember && mask) {
      var n = TR.MICRO.n, rest = new Uint8Array(n);
      for (var r = 0; r < n; r++) rest[r] = groupMember[r] ? 0 : 1;
      var col = [{ member: rest }];
      if (q.rows[ri].kind === "net") {
        var boxes = TR.MICRO.boxes && TR.MICRO.boxes[q.code];
        var c = boxes
          ? TR.stats.boxCounts(q.code, ri, col, mask)[0]
          : TR.stats.netCounts(q,
              (q.net_members && q.net_members[String(ri)]) || [], col, mask)[0];
        return c.wbase ? c.n / c.wbase * 100 : null;
      }
      var tab = TR.stats.tabulate(q, col, mask)[0];
      return tab.wbase ? (tab.counts[ri] || 0) / tab.wbase * 100 : null;
    }
    // No microdata: exact when unweighted (weighted count == unweighted base).
    var rb = totalBase - groupBase;
    if (!rb || groupCell.n == null || totalCell.n == null) return null;
    return (totalCell.n - groupCell.n) / rb * 100;
  }

  /** A mean-kind row that reports spread (Std Dev), not a centre — never a
   *  "difference" finding (mirrors the model's isStdDevRow). */
  function isSpreadRow(label) {
    return /^(std\.?\s*dev|standard deviation)/i.test(String(label || ""));
  }

  /**
   * Mean / Index / NPS findings for one question. The published tables carry NO
   * significance for these rows, so recompute the per-column weighted means from
   * microdata (the engine a filtered table uses) and test each group against THE
   * REST with a weighted Welch t-test — the natural test for a single-value
   * metric. It is bidirectional: a group significantly ABOVE or BELOW the rest
   * is a finding (a low-NPS segment is often the headline). The gap is in the
   * metric's own units (points, not pp); the score scales it by significance
   * strength and the response-scale range so these rank comparably with the
   * percentage findings. Returns [] for derived / ranking questions with no
   * recomputable score.
   */
  function meanFindings(q, spec, mask, threshold) {
    var out = [], row = null;
    q.rows.forEach(function (r) {
      if (!row && r.kind === "mean" && !isSpreadRow(r.label)) row = r;
    });
    if (!row) return out;
    var means = TR.stats.indexMeans(q, spec.columns, mask);
    if (!means) return out;                       // ranking / no-score question
    var scores = TR.MICRO.scores && TR.MICRO.scores[q.code];
    var lo = 0, hi = 0, any = false;              // response-scale range
    if (scores) {
      scores.forEach(function (v) {
        if (v === null || v === undefined) return;
        if (!any) { lo = hi = v; any = true; } else { lo = Math.min(lo, v); hi = Math.max(hi, v); }
      });
    }
    var scaleMin = Math.min(0, lo), scaleMax = Math.max(0, hi);
    var range = (scaleMax - scaleMin) || 1;
    var decimals = /nps/i.test(row.label) ? 0 : 1;
    var n = TR.MICRO.n;
    spec.columns.forEach(function (col, i) {
      if (i === 0 || means[i].mean === null || !means[i].k || means[i].k < threshold) return;
      var rest = new Uint8Array(n);
      for (var r = 0; r < n; r++) rest[r] = col.member[r] ? 0 : 1;
      var rm = TR.stats.indexMeans(q, [{ member: rest }], mask)[0];
      if (!rm || rm.mean === null || !rm.k || rm.k < threshold) return;
      var z = TR.stats.meanZ(means[i].mean, means[i].sd, means[i].k, rm.mean, rm.sd, rm.k);
      if (z === null || Math.abs(z) <= TR.stats.Z95) return;   // not different from the rest
      var gap = means[i].mean - rm.mean;
      out.push({ code: q.code, title: q.title, category: q.category,
        label: row.label, column: col.label, isMean: true,
        direction: gap >= 0 ? "ahead" : "behind",
        value: means[i].mean, rest: rm.mean, overall: means[0].mean,
        gap: gap, decimals: decimals, scaleMin: scaleMin, scaleMax: scaleMax,
        beaten: [],
        score: (Math.abs(z) / TR.stats.Z95) * Math.abs(gap) / range * 100 });
    });
    return out;
  }

  /** All findings for a banner: {code,title,category,label,column,value,isMean,
   *  rest,overall,gap,beaten[],score}. Pure given the models + microdata. */
  function collectFindings(banner) {
    var bannerSource = banner.replace("custom:", "").split(":")[0];
    var micro = TR.d2.hasMicrodata();
    // Banner-column memberships (respondent -> column) are question-independent;
    // build them once and reuse to recompute "the rest" for every finding.
    var spec = micro ? TR.stats.columnsFor(banner) : null;
    var mask = micro ? TR.stats.mask(TR.d2.state.filters) : null;
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var findings = [];
    TR.AGG.questions.forEach(function (q) {
      if (q.code === bannerSource) return;   // a banner never "beats" itself
      var model = views._modelFor(q.code, banner);
      var labelByLetter = {};
      model.columns.forEach(function (col) {
        if (col.letter) labelByLetter[col.letter] = col.label;
      });
      // model.rows is 1:1 with q.rows in this view (no row scope / hide / sort),
      // so the loop index is the question row index used to recompute the rest.
      model.rows.forEach(function (row, ri) {
        if (row.kind === "mean") return;       // means handled below (recomputed)
        row.cells.forEach(function (cell, i) {
          var sig95 = (cell.sig || "").replace(/[a-z]/g, "");
          if (i === 0 || sig95.length < 2) return;
          var overall = row.cells[0].pct;
          if (cell.pct === null || overall === null) return;
          var rest = restPct(q, ri, spec ? spec.columns[i].member : null, mask,
            cell, row.cells[0], model.columns[i].base, model.columns[0].base);
          var baseline = rest === null ? overall : rest;
          findings.push({ code: q.code, title: q.title, category: q.category,
            label: row.label, column: model.columns[i].label, isMean: false,
            value: cell.pct, rest: rest, overall: overall,
            gap: cell.pct - baseline,
            beaten: sig95.split("").map(function (letter) {
              return labelByLetter[letter] || letter;
            }),
            score: sig95.length * Math.abs(cell.pct - baseline) });
        });
      });
      // Mean / index / NPS standouts — recomputed from microdata (the published
      // data has no significance for them), arguably the headline differences.
      if (spec) meanFindings(q, spec, mask, threshold)
        .forEach(function (f) { findings.push(f); });
    });
    findings.sort(function (a, b) { return b.score - a.score; });
    return findings;
  }

  /** Group the ranked findings by question, preserving rank order. */
  function groupByQuestion(findings) {
    var byCode = {}, groups = [];
    findings.forEach(function (f) {
      if (!byCode[f.code]) {
        byCode[f.code] = { code: f.code, title: f.title,
          category: f.category, top: f.score, items: [] };
        groups.push(byCode[f.code]);
      }
      byCode[f.code].items.push(f);
    });
    return groups;
  }

  /** Value in its own units: "83%" for proportions, "9.3" / "78" for a
   *  mean / index / NPS (the metric is named in the sentence lead). */
  function fmtMetric(f, v) {
    return f.isMean ? v.toFixed(f.decimals) : Math.round(v) + "%";
  }

  /** Two-bar comparison: the group vs the rest (everyone except the group);
   *  falls back to "Everyone" when the rest is unavailable. Proportions fill a
   *  0–100 track; means/index/NPS scale to the metric's own range so a 9.3 mean
   *  is a near-full bar, not a 9% sliver. */
  function barsHtml(f) {
    var hasRest = f.rest !== null && f.rest !== undefined;
    var bar = function (value, cls, name) {
      var w = f.isMean
        ? (value - f.scaleMin) / (f.scaleMax - f.scaleMin) * 100
        : value;
      return '<div class="dfb-row"><span class="dfb-name">' + name + "</span>" +
        '<div class="dfb-track"><div class="dfb-bar ' + cls + '" style="width:' +
        Math.min(Math.max(w, 0), 100).toFixed(1) + '%"></div></div>' +
        '<span class="dfb-val">' + fmtMetric(f, value) + "</span></div>";
    };
    return '<div class="dfb">' +
      bar(f.value, "dfb-group", fmt.escapeHtml(TR.charts.clip(f.column, 24))) +
      bar(hasRest ? f.rest : f.overall, "dfb-total",
        hasRest ? "The rest" : "Everyone") + "</div>";
  }

  /** One finding as a plain-English line inside its question card. The headline
   *  compares the group with the REST (everyone except it) and carries the
   *  whole-sample figure in brackets. Proportions read "X% say "label""; a
   *  mean / index / NPS reads "<metric> <value>" with the gap in its own units. */
  function lineHtml(f) {
    var direction = f.gap >= 0 ? "+" : "−";
    var hasRest = f.rest !== null && f.rest !== undefined;
    var gapTxt = f.isMean
      ? Math.abs(f.gap).toFixed(f.decimals)
      : Math.abs(Math.round(f.gap)) + "pp";
    var lead = f.isMean
      ? fmt.escapeHtml(f.label) + " " + fmtMetric(f, f.value)
      : Math.round(f.value) + "% say “" + fmt.escapeHtml(f.label) + "”";
    var baseline = hasRest
      ? fmtMetric(f, f.rest) + " of the rest (" + fmtMetric(f, f.overall) +
        " overall)"
      : fmtMetric(f, f.overall) + (f.isMean ? " overall" : " of everyone");
    return '<div class="df-line">' +
      '<div class="df-sentence"><strong>' + fmt.escapeHtml(f.column) +
      "</strong> — " + lead + " vs " + baseline + " · " + direction + gapTxt +
      "</div>" + barsHtml(f) +
      '<div class="df-beats">' + (f.isMean
        ? "statistically " + (f.direction === "ahead" ? "ahead of" : "behind") +
          " the rest"
        : "statistically ahead of " + fmt.escapeHtml(f.beaten.join(" · "))) +
      "</div></div>";
  }

  /* exposed for the differences gate test */
  views._collectFindings = collectFindings;
  views._diffLineHtml = lineHtml;

  function cardHtml(group) {
    var search = (group.code + " " + group.title + " " +
      group.items.map(function (f) { return f.label + " " + f.column; })
        .join(" ")).toLowerCase();
    return '<div class="card df-card" data-search="' +
      fmt.escapeHtml(search) + '">' +
      '<div class="df-qhead"><button class="linklike" data-goq="' +
      group.code + '">' + group.code + " · " +
      fmt.escapeHtml(group.title) + "</button>" +
      '<span class="kindtag">' + fmt.escapeHtml(group.category) +
      "</span></div>" +
      group.items.map(lineHtml).join("") + "</div>";
  }

  views.findings = function (host) {
    var banner = diffBanner || TR.d2.state.banner;
    if (banner.indexOf("custom:") === 0) banner = TR.AGG.banner_groups[0].id;
    var all = collectFindings(banner);
    var shown = all.slice(0, MAX_FINDINGS);
    var groups = groupByQuestion(shown);
    if (diffSort === "question") {
      groups.sort(function (a, b) { return a.code < b.code ? -1 : 1; });
    }
    var groupName = TR.AGG.banner_groups.filter(function (g) {
      return g.id === banner;
    })[0];
    var html = ['<div class="page"><div class="card"><h2>Where groups differ · ' +
      fmt.escapeHtml(groupName ? groupName.name : banner) + "</h2>" +
      "<p>Each card is one question; each line is one group that genuinely " +
      "stands out — on a percentage, average, index or NPS — measured against " +
      "the rest (the whole-sample figure is in brackets). Percentages name the " +
      "groups they beat; averages show whether they sit above or below the rest " +
      "(95% level, this wave; year-on-year changes live in Tracking).</p>" +
      '<div class="scopebar">' + views._bannerPickerHtml(banner, "diffbanner") +
      '<select data-diffsort>' +
      '<option value="standout"' + (diffSort === "standout" ? " selected" : "") +
      ">Biggest standouts first</option>" +
      '<option value="question"' + (diffSort === "question" ? " selected" : "") +
      ">Question order</option></select>" +
      '<input id="diff-search" type="search" placeholder="Search questions, ' +
      'answers or groups…">' +
      (all.length > MAX_FINDINGS
        ? '<span class="trknote">top ' + MAX_FINDINGS + " of " + all.length +
          " differences shown</span>" : "") + "</div></div>"];
    if (!groups.length) {
      html.push('<div class="card"><p>No group is significantly ahead of two ' +
        "or more others on this banner.</p></div>");
    }
    groups.forEach(function (group) { html.push(cardHtml(group)); });
    html.push(TR.conf.calloutHtml());
    html.push("</div>");
    host.innerHTML = html.join("");

    views._wireLinks(host);
    var picker = host.querySelector('[data-act="diffbanner"]');
    if (picker) {
      picker.addEventListener("change", function () {
        diffBanner = picker.value;
        views.findings(host);
      });
    }
    host.querySelector("[data-diffsort]").addEventListener("change", function (e) {
      diffSort = e.target.value;
      views.findings(host);
    });
    var search = host.querySelector("#diff-search");
    search.addEventListener("input", function () {
      var term = search.value.trim().toLowerCase();
      host.querySelectorAll(".df-card").forEach(function (card) {
        card.classList.toggle("hidden",
          !!term && card.getAttribute("data-search").indexOf(term) === -1);
      });
    });
    var callout = host.querySelector("[data-callout]");
    if (callout) {
      callout.addEventListener("click", function () {
        callout.closest(".callout").classList.toggle("collapsed");
      });
    }
  };

})(typeof window !== "undefined" ? window : globalThis);
