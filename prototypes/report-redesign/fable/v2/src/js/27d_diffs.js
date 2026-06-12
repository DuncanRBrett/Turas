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

  /** All findings for a banner: {code,title,category,label,column,pct,
   *  total,gap,beaten[],score}. Pure given the models. */
  function collectFindings(banner) {
    var bannerSource = banner.replace("custom:", "").split(":")[0];
    var findings = [];
    TR.AGG.questions.forEach(function (q) {
      if (q.code === bannerSource) return;   // a banner never "beats" itself
      var model = views._modelFor(q.code, banner);
      var labelByLetter = {};
      model.columns.forEach(function (col) {
        if (col.letter) labelByLetter[col.letter] = col.label;
      });
      model.rows.forEach(function (row) {
        if (row.kind === "mean") return;
        row.cells.forEach(function (cell, i) {
          var sig95 = (cell.sig || "").replace(/[a-z]/g, "");
          if (i === 0 || sig95.length < 2) return;
          var total = row.cells[0].pct;
          if (cell.pct === null || total === null) return;
          findings.push({ code: q.code, title: q.title, category: q.category,
            label: row.label, column: model.columns[i].label,
            pct: cell.pct, total: total, gap: cell.pct - total,
            beaten: sig95.split("").map(function (letter) {
              return labelByLetter[letter] || letter;
            }),
            score: sig95.length * Math.abs(cell.pct - total) });
        });
      });
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

  /** Two-bar comparison: the group's value vs everyone, same scale. */
  function barsHtml(f) {
    var bar = function (value, cls, name) {
      return '<div class="dfb-row"><span class="dfb-name">' + name + "</span>" +
        '<div class="dfb-track"><div class="dfb-bar ' + cls + '" style="width:' +
        Math.min(Math.max(value, 0), 100).toFixed(1) + '%"></div></div>' +
        '<span class="dfb-val">' + Math.round(value) + "%</span></div>";
    };
    return '<div class="dfb">' +
      bar(f.pct, "dfb-group", fmt.escapeHtml(TR.charts.clip(f.column, 24))) +
      bar(f.total, "dfb-total", "Everyone") + "</div>";
  }

  /** One finding as a plain-English line inside its question card. */
  function lineHtml(f) {
    var direction = f.gap >= 0 ? "+" : "−";
    return '<div class="df-line">' +
      '<div class="df-sentence"><strong>' + fmt.escapeHtml(f.column) +
      "</strong> — " + Math.round(f.pct) + "% say “" +
      fmt.escapeHtml(f.label) + "” vs " + Math.round(f.total) +
      "% of everyone (" + direction + Math.abs(Math.round(f.gap)) + "pp)" +
      "</div>" + barsHtml(f) +
      '<div class="df-beats">statistically ahead of ' +
      fmt.escapeHtml(f.beaten.join(" · ")) + "</div></div>";
  }

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
      "stands out — what it says, how far it sits from everyone, and which " +
      "groups it is statistically ahead of (95% level, this wave; " +
      "year-on-year changes live in Tracking).</p>" +
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
