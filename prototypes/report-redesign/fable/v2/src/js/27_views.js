/**
 * v2 analytical views — Dashboard (gauges + heatmap with its own banner
 * picker, Excel export and pin-to-story) and Differences (banner-
 * filterable, sortable, names what each cell beats). The Tracking view
 * lives in 27t_tracking.js and shares this module's helpers.
 *
 * SIZE-EXCEPTION: sibling read-only views sharing ranking helpers.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var views = TR.views = {};
  var heatBanner = null;        // dashboard heatmap banner override
  var diffSort = null;
  var diffBanner = null;

  function scoreMax(q) {
    var max = 0;
    if (q.index_scores) {
      Object.keys(q.index_scores).forEach(function (k) {
        if (q.index_scores[k] > max) max = q.index_scores[k];
      });
    }
    return max > 0 ? max : 100;
  }

  function gaugeColour(value, max) {
    if (value === null || value === undefined) return "#94a3b8";
    var pct = value / (max || 100) * 100;
    if (pct >= 75) return "#1b6e53";
    if (pct >= 50) return "#a8842c";
    return "#b3372f";
  }

  function indexQuestions() {
    return TR.AGG.questions.filter(function (q) {
      return q.rows.some(function (r) { return r.kind === "mean"; });
    });
  }

  function modelFor(code, banner) {
    // intervals ride along for the gauge + heatmap tooltips (additive)
    return TR.model.forQuestion(code, banner || TR.d2.state.banner,
      TR.d2.state.filters, { hiddenCols: [], intervals: true });
  }

  /** "95% SI 82.6–85.6 · n=519" tooltip fragment for a mean cell. */
  function intervalTip(cell, base) {
    if (!cell || !cell.ci) return "";
    return " · 95% " + TR.conf.labels().interval_abbrev + " " +
      TR.conf.fmtRange(cell.ci.lo, cell.ci.hi, true) +
      (base ? " · n=" + fmt.base(base) : "");
  }

  /**
   * The dashboard's plain-language precision chip: worst-case ±pp at the
   * overall base vs the smallest column of the heatmap banner — all
   * computed live from the report's own bases.
   */
  function moeChipHtml(qs, heatModels) {
    var labels = TR.conf.labels();
    var overall = 0;
    var smallest = null;
    qs.forEach(function (q) {
      var m = heatModels[q.code];
      if (!m || !m.columns[0] || !m.columns[0].base) return;
      if (m.columns[0].base > overall) {
        overall = m.columns[0].base;
        smallest = null;
        m.columns.forEach(function (col, i) {
          if (i === 0 || !col.base) return;
          if (!smallest || col.base < smallest.n) {
            smallest = { label: col.label, n: col.base };
          }
        });
      }
    });
    if (!overall) return "";
    var bits = "At n=" + fmt.base(overall) +
      ", overall percentages are stable to about ±" +
      TR.conf.maxMoePct(overall).toFixed(1) + "pp";
    if (smallest) {
      bits += "; smaller cuts swing more — " + fmt.escapeHtml(smallest.label) +
        " (n=" + fmt.base(smallest.n) + ") about ±" +
        TR.conf.maxMoePct(smallest.n).toFixed(1) + "pp";
    }
    return '<p class="moechip" title="Worst-case 95% ' +
      labels.precision_term + " at each base — see “How sure can I be of " +
      'these numbers?” on the Crosstabs tab">' +
      labels.moe_name + " (" + labels.moe_abbrev + "): " + bits + ".</p>";
  }

  function meanRow(model) {
    for (var i = 0; i < model.rows.length; i++) {
      if (model.rows[i].kind === "mean") return model.rows[i];
    }
    return null;
  }

  function bannerPickerHtml(current, action) {
    var options = TR.AGG.banner_groups.map(function (g) {
      return '<option value="' + g.id + '"' +
        (current === g.id ? " selected" : "") + ">" + fmt.escapeHtml(g.name) + "</option>";
    }).join("");
    return '<select data-act="' + action + '" aria-label="Banner">' + options + "</select>";
  }

  /* ---------------- Dashboard ---------------- */

  views.dashboard = function (host) {
    var qs = indexQuestions();
    var hb = heatBanner || TR.d2.state.banner;
    if (hb.indexOf("custom:") === 0) hb = TR.AGG.banner_groups[0].id;
    var byCat = {}, models = {}, heatModels = {};
    qs.forEach(function (q) {
      models[q.code] = modelFor(q.code);
      heatModels[q.code] = hb === TR.d2.state.banner
        ? models[q.code] : modelFor(q.code, hb);
      (byCat[q.category] = byCat[q.category] || []).push(q);
    });
    var html = ['<div class="page"><div class="dash-intro card">' +
      "<h2>Experience dashboard</h2><p>Index scores for every rated touchpoint " +
      "— <span class='gl g'>strong ≥75%</span> <span class='gl a'>moderate 50–74%</span> " +
      "<span class='gl r'>weak &lt;50%</span> of each scale's maximum. " +
      (TR.d2.filtersActive() ? "<strong>Filtered audience — recomputed live.</strong> " : "") +
      "▲▼ chips show change vs 2024. Click any card or cell to open the full table.</p>" +
      moeChipHtml(qs, heatModels) + "</div>"];

    Object.keys(byCat).forEach(function (cat) {
      html.push('<div class="dash-cat"><h3>' + fmt.escapeHtml(cat) + "</h3><div class='gauges'>");
      byCat[cat].forEach(function (q) {
        var row = meanRow(models[q.code]);
        var value = row ? row.cells[0].mean : null;
        var delta = row && row.delta ? row.delta : null;
        html.push('<button class="gauge" data-goq="' + q.code + '" title="' +
          fmt.escapeHtml(q.title) +
          (row ? intervalTip(row.cells[0], models[q.code].columns[0].base) : "") +
          '" style="--gc:' +
          gaugeColour(value, scoreMax(q)) + '">' +
          '<span class="gv">' + (value === null ? "–" : value.toFixed(1)) + "</span>" +
          (delta ? '<span class="gd ' + (delta.diff >= 0 ? "up" : "down") + '">' +
            (delta.diff >= 0 ? "▲" : "▼") + Math.abs(delta.diff).toFixed(1) + "</span>" : "") +
          '<span class="gt">' + fmt.escapeHtml(TR.charts.clip(q.title, 64)) + "</span>" +
          '<span class="gq">' + q.code + "</span></button>");
      });
      html.push("</div></div>");
    });

    html.push(heatGridHtml(qs, heatModels, hb));
    html.push("</div>");
    host.innerHTML = html.join("");
    host.querySelectorAll("[data-goq]").forEach(function (el) {
      el.addEventListener("click", function () {
        TR.shell.goQuestion(el.getAttribute("data-goq"));
      });
    });
    var picker = host.querySelector('[data-act="heatbanner"]');
    if (picker) {
      picker.addEventListener("change", function () {
        heatBanner = picker.value;
        views.dashboard(host);
      });
    }
    var excel = host.querySelector('[data-act="heat-excel"]');
    if (excel) {
      excel.addEventListener("click", function () {
        var grid = heatMatrix(qs, heatModels);
        TR.xlsx.download("index_heatmap", "Heatmap",
          [grid.head].concat(grid.rows));
      });
    }
    var pin = host.querySelector('[data-act="heat-pin"]');
    if (pin) {
      pin.addEventListener("click", function () {
        TR.story2.pinHeatmap(hb);
      });
    }
  };

  /** Matrix of the heatmap (question x banner columns of index means). */
  function heatMatrix(qs, models) {
    var first = models[qs[0] && qs[0].code];
    var head = ["Question"].concat(first.columns.map(function (c) { return c.label; }));
    var rows = [];
    qs.forEach(function (q) {
      var row = meanRow(models[q.code]);
      if (!row) return;
      rows.push([q.code + " — " + q.title].concat(row.cells.map(function (c) {
        return c.mean === null ? "" : Math.round(c.mean * 10) / 10;
      })));
    });
    return { head: head, rows: rows };
  }
  views._heatMatrix = heatMatrix;
  views._indexQuestions = indexQuestions;
  views._modelFor = modelFor;
  views._meanRow = meanRow;

  function heatGridHtml(qs, models, hb) {
    var first = models[qs[0] && qs[0].code];
    if (!first) return "";
    var groupName = TR.AGG.banner_groups.filter(function (g) { return g.id === hb; })[0];
    var html = ['<div class="card heatgrid-card"><div class="heathead"><h3>Index heatmap · by ' +
      fmt.escapeHtml(groupName ? groupName.name : hb) + "</h3>" +
      '<span class="heat-actions">' + bannerPickerHtml(hb, "heatbanner") +
      '<button data-act="heat-excel" title="Download as an Excel workbook">Excel</button>' +
      '<button data-act="heat-pin" class="primary">📌 Pin to story</button></span></div>' +
      "<div class='heatwrap'><table class='heatgrid'><thead><tr><th></th>"];
    first.columns.forEach(function (col) {
      html.push("<th>" + fmt.escapeHtml(TR.charts.clip(col.label, 16)) + "</th>");
    });
    html.push("</tr></thead><tbody>");
    qs.forEach(function (q) {
      var model = models[q.code];
      var row = meanRow(model);
      if (!row) return;
      html.push('<tr><td class="lab"><button class="linklike" data-goq="' + q.code +
        '">' + fmt.escapeHtml(TR.charts.clip(q.title, 52)) + "</button></td>");
      var max = scoreMax(q);
      row.cells.forEach(function (cell, i) {
        var v = cell.mean;
        var norm = v === null ? 0 : Math.min(Math.max(v / max * 100, 0), 100);
        var low = model.columns[i].low;
        html.push('<td style="background:' +
          (v === null ? "#f3f4f8" : gaugeColour(v, max) +
            Math.round(40 + norm / 100 * 50).toString(16)) +
          '" title="' + fmt.escapeHtml(model.columns[i].label) +
          intervalTip(cell, model.columns[i].base) + '">' +
          (v === null ? "–" : (max <= 10 ? v.toFixed(1) : Math.round(v))) +
          (low ? " ⚠" : "") + "</td>");
      });
      html.push("</tr>");
    });
    html.push("</tbody></table></div></div>");
    return html.join("");
  }

  function th(key, label, sort) {
    var arrow = sort && sort.col === key ? (sort.dir === "desc" ? " ↓" : " ↑") : "";
    return '<th data-sort="' + key + '" class="sortable">' + label + arrow + "</th>";
  }

  function wireRowFilter(host, searchId, catId) {
    var apply = function () {
      var term = (document.getElementById(searchId).value || "").toLowerCase();
      var cat = document.getElementById(catId) ? document.getElementById(catId).value : "";
      host.querySelectorAll("tbody tr").forEach(function (tr) {
        var okTerm = !term || (tr.getAttribute("data-search") || "").indexOf(term) !== -1;
        var okCat = !cat || tr.getAttribute("data-cat") === cat;
        tr.classList.toggle("hidden", !(okTerm && okCat));
      });
    };
    var search = document.getElementById(searchId);
    var cat = document.getElementById(catId);
    if (search) search.addEventListener("input", apply);
    if (cat) cat.addEventListener("change", apply);
  }

  /* ---------------- Differences ---------------- */

  views.findings = function (host) {
    var banner = diffBanner || TR.d2.state.banner;
    if (banner.indexOf("custom:") === 0) banner = TR.AGG.banner_groups[0].id;
    var bannerSource = banner.replace("custom:", "").split(":")[0];
    var findings = [];
    TR.AGG.questions.forEach(function (q) {
      if (q.code === bannerSource) return;
      var model = modelFor(q.code, banner);
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
            pct: cell.pct, total: total,
            beaten: sig95.split("").map(function (letter) {
              return labelByLetter[letter] || letter;
            }),
            gap: cell.pct - total,
            score: sig95.length * Math.abs(cell.pct - total) });
        });
      });
    });
    var sort = diffSort || { col: "score", dir: "desc" };
    findings.sort(function (a, b) {
      var v;
      if (sort.col === "value") v = a.pct - b.pct;
      else if (sort.col === "total") v = a.total - b.total;
      else if (sort.col === "question") v = a.code < b.code ? -1 : 1;
      else v = a.score - b.score;
      return sort.dir === "asc" ? v : -v;
    });
    var groupName = TR.AGG.banner_groups.filter(function (g) { return g.id === banner; })[0];
    var html = ['<div class="page"><div class="card"><h2>Significant differences · ' +
      fmt.escapeHtml(groupName ? groupName.name : banner) + " banner</h2>" +
      "<p>Every within-survey significant difference in one place (this wave; " +
      "year-on-year lives in Tracking). A row appears when a column is " +
      "significantly higher than two or more sibling columns at 95%; " +
      "<strong>higher than</strong> names exactly what it beats. Click headers to sort.</p>" +
      '<div class="scopebar">' + bannerPickerHtml(banner, "diffbanner") +
      '<input id="diff-search" type="search" placeholder="Search…"></div>' +
      '<table class="moved"><thead><tr>' +
      th("question", "Question", sort) + "<th>Row</th><th>Column</th>" +
      th("value", "Value", sort) + th("total", "Total", sort) +
      th("score", "Higher than", sort) + "</tr></thead><tbody>"];
    findings.slice(0, 80).forEach(function (f) {
      html.push('<tr data-search="' +
        fmt.escapeHtml((f.code + " " + f.title + " " + f.label + " " + f.column).toLowerCase()) +
        '" data-cat="' + fmt.escapeHtml(f.category) + '">' +
        '<td><button class="linklike" data-goq="' + f.code + '">' +
        f.code + " · " + fmt.escapeHtml(TR.charts.clip(f.title, 40)) + "</button></td>" +
        "<td>" + fmt.escapeHtml(TR.charts.clip(f.label, 30)) + "</td>" +
        "<td><strong>" + fmt.escapeHtml(TR.charts.clip(f.column, 24)) + "</strong></td>" +
        "<td><strong>" + Math.round(f.pct) + "%</strong></td>" +
        "<td>" + Math.round(f.total) + "%</td>" +
        '<td class="beatenlist">' + fmt.escapeHtml(
          f.beaten.map(function (b) { return TR.charts.clip(b, 22); }).join(" · ")) +
        "</td></tr>");
    });
    html.push("</tbody></table></div></div>");
    host.innerHTML = html.join("");
    wireLinks(host);
    var picker = host.querySelector('[data-act="diffbanner"]');
    if (picker) {
      picker.addEventListener("change", function () {
        diffBanner = picker.value;
        views.findings(host);
      });
    }
    host.querySelectorAll("th[data-sort]").forEach(function (el) {
      el.addEventListener("click", function () {
        var col = el.getAttribute("data-sort");
        diffSort = (diffSort && diffSort.col === col && diffSort.dir === "desc")
          ? { col: col, dir: "asc" } : { col: col, dir: "desc" };
        views.findings(host);
      });
    });
    wireRowFilter(host, "diff-search", "none");
  };

  function wireLinks(host) {
    host.querySelectorAll("[data-goq]").forEach(function (el) {
      el.addEventListener("click", function () {
        TR.shell.goQuestion(el.getAttribute("data-goq"));
      });
    });
  }

  /* shared with the Tracking view (27t_tracking.js) */
  views._th = th;
  views._wireRowFilter = wireRowFilter;
  views._wireLinks = wireLinks;

})(typeof window !== "undefined" ? window : globalThis);
