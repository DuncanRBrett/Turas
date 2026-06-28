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

  function scoreMax(q) {
    // Tabs supplies the configured scale max (e.g. 10 for a 0-10 rating);
    // the prototype's SACAP data instead carries index_scores. Either gives
    // the denominator for the "% of each scale's maximum" gauge colouring.
    if (q.scale_max) return q.scale_max;
    var max = 0;
    if (q.index_scores) {
      Object.keys(q.index_scores).forEach(function (k) {
        if (q.index_scores[k] > max) max = q.index_scores[k];
      });
    }
    return max > 0 ? max : 100;
  }

  function gaugeColour(value, max, q) {
    if (value === null || value === undefined) return "#94a3b8";
    // Classic-report parity: when tabs supplies the configured raw thresholds
    // (e.g. >=7 green / >=5 amber on a 0-10 scale) colour against them; else
    // fall back to % of the scale max (75/50), as the SACAP prototype does.
    if (q && q.gauge_green != null && q.gauge_amber != null) {
      if (value >= q.gauge_green) return "#1b6e53";
      if (value >= q.gauge_amber) return "#a8842c";
      return "#b3372f";
    }
    var pct = value / (max || 100) * 100;
    if (pct >= 75) return "#1b6e53";
    if (pct >= 50) return "#a8842c";
    return "#b3372f";
  }

  function indexQuestions() {
    // A rated touchpoint carries a summary mean and sits on a known scale:
    // scale / nps questions, PLUS composite indices (e.g. Q_Engage / Q_Value)
    // which map to type "single" but carry a scale_max. Numeric open-counts
    // (type "numeric", e.g. "hours lost") also have a mean but no scale maximum,
    // so colour-banding them as "% of scale" is meaningless — excluded.
    return TR.AGG.questions.filter(function (q) {
      if (!q.rows.some(function (r) { return r.kind === "mean"; })) return false;
      if (q.type === "scale" || q.type === "nps") return true;
      return q.type !== "numeric" &&
        typeof q.scale_max === "number" && isFinite(q.scale_max) && q.scale_max > 0;
    });
  }
  views.indexQuestions = indexQuestions;   // exposed for the gate test

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
    if (hb.indexOf("custom:") === 0) hb = TR.d2.firstBanner();
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
        var max = scoreMax(q), gc = gaugeColour(value, max, q);
        // gauge bar = value vs scale max; sparkline = the wave trajectory (only
        // when wave history is attached — non-tracking reports just show the bar)
        var hasVal = value !== null && value !== undefined && max > 0;
        var barPct = hasVal ? Math.max(0, Math.min(value / max, 1)) * 100 : 0;
        var pts = row ? TR.render.wavePoints(row) : null;
        var spark = (pts && pts.length > 1) ? TR.render.sparkline(pts, true, { w: 212, h: 28 }) : "";
        html.push('<div class="gauge-wrap" data-snap-card>' +
          '<button class="gauge" data-goq="' + q.code + '" title="' +
          fmt.escapeHtml(q.title) +
          (row ? intervalTip(row.cells[0], models[q.code].columns[0].base) : "") +
          '" style="--gc:' + gc + '">' +
          '<span class="gq">' + q.code + "</span>" +
          '<span class="gv">' + (value === null ? "–" : value.toFixed(1)) +
          (hasVal ? '<span class="gsc">/' + max + "</span>" : "") +
          (delta ? '<span class="gd ' + (delta.diff >= 0 ? "up" : "down") + '">' +
            (delta.diff >= 0 ? "▲" : "▼") + Math.abs(delta.diff).toFixed(1) + "</span>" : "") +
          "</span>" +
          (hasVal ? '<span class="gbar"><span class="gbf" style="width:' +
            barPct.toFixed(0) + '%"></span></span>' : "") +
          (spark ? '<span class="gspark">' + spark + "</span>" : "") +
          '<span class="gt">' + fmt.escapeHtml(TR.charts.clip(q.title, 64)) + "</span></button>" +
          '<button class="snap-pin" data-snap-pin data-snap-source="dashboard" data-snap-title="' +
          fmt.escapeHtml(q.code + " — " + q.title) + '" data-snap-context="' +
          fmt.escapeHtml((q.category || "") + " · index") +
          '" title="Pin this card to the story" aria-label="Pin card to story">📌</button></div>');
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
          (v === null ? "#f3f4f8" : gaugeColour(v, max, q) +
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

  /* The Differences view lives in 27d_diffs.js (question-grouped cards). */

  function wireLinks(host) {
    host.querySelectorAll("[data-goq]").forEach(function (el) {
      el.addEventListener("click", function () {
        TR.shell.goQuestion(el.getAttribute("data-goq"));
      });
    });
  }

  /* shared with the Tracking + Differences views (27t / 27d) */
  views._wireRowFilter = wireRowFilter;
  views._wireLinks = wireLinks;
  views._bannerPickerHtml = bannerPickerHtml;

})(typeof window !== "undefined" ? window : globalThis);
