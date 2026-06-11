/**
 * Cross-question composer — pick >=2 questions and render one combined
 * view from the data layer: aligned bars on a SHARED percentage axis,
 * plus aligned wave-trend strips for trended questions. compose() and
 * renderSvg() are pure so they unit-test in node and feed PNG/PPTX export.
 */
(function (global) {
  "use strict";
  var TR = global.TR, C = TR.CONST, S = TR.svg, fmt = TR.fmt;

  var composer = TR.composer = {};
  composer._models = {};
  var nextId = 1;

  /**
   * Build a composite model (pure, error-accumulating).
   * Only %-formatted rows join the shared bar axis; means/NPS trends render
   * as per-question strips because they do not share a unit.
   */
  composer.compose = function (payload, ids, colIndex) {
    var errors = [];
    if (!Array.isArray(ids) || ids.length < C.COMPOSE_MIN) {
      errors.push({ code: "CFG_COMPOSE_MIN",
        message: "Pick at least " + C.COMPOSE_MIN + " questions to compose." });
    }
    if (Array.isArray(ids) && ids.length > C.COMPOSE_MAX) {
      errors.push({ code: "CFG_COMPOSE_MAX",
        message: "Pick at most " + C.COMPOSE_MAX + " questions." });
    }
    var cols = (payload.banner && payload.banner.columns) || [];
    if (colIndex < 0 || colIndex >= cols.length) {
      errors.push({ code: "CFG_COMPOSE_COL",
        message: "Banner column index " + colIndex + " is out of range." });
    }
    if (errors.length) return { ok: false, errors: errors, model: null };

    var columnName = cols[colIndex];
    var items = [], trends = [], maxValue = 0, waveLabels = null, mixedWaves = false;
    ids.forEach(function (id) {
      var q = TR.data.questionById(payload, id);
      if (!q) {
        errors.push({ code: "CFG_COMPOSE_UNKNOWN", message: "Unknown question id '" + id + "'." });
        return;
      }
      var rows = (q.rows || [])
        .filter(function (r) { return (r.format || "pct") === "pct"; })
        .map(function (r) {
          var v = r.values[colIndex];
          if (typeof v === "number" && v > maxValue) maxValue = v;
          return { label: r.label, value: v,
            sig: r.sig ? r.sig[colIndex] || "" : "" };
        });
      items.push({ id: q.id, code: q.code || q.id, title: q.title, type: q.type,
        base: q.bases ? q.bases[colIndex] : null, rows: rows });
      var waves = q.meta && q.meta.waves;
      if (waves) {
        var series = TR.data.waveSeriesFor(q, columnName);
        if (series) {
          if (!waveLabels) waveLabels = waves.labels;
          else if (waveLabels.join("|") !== waves.labels.join("|")) mixedWaves = true;
          trends.push({ code: q.code || q.id, title: q.title,
            stat: waves.stat || "value", format: waves.format || "dec1",
            labels: waves.labels, values: series.values });
        }
      }
    });
    if (errors.length) return { ok: false, errors: errors, model: null };

    return { ok: true, errors: [], model: {
      column: columnName, colIndex: colIndex, items: items,
      sharedMax: S.niceMax(maxValue),
      trends: trends, waveLabels: waveLabels, mixedWaves: mixedWaves
    } };
  };

  /** Composite SVG: aligned bar panels + aligned trend strips (pure). */
  composer.renderSvg = function (model, payload) {
    var brand = TR.charts.brandOf(payload);
    var accent = TR.charts.accentOf(payload);
    var width = C.CHART_WIDTH;
    var plotW = width - C.CHART_LABEL_WIDTH - C.CHART_VALUE_WIDTH;
    var x = S.linear(model.sharedMax, plotW);
    var body = [], y = 6;

    model.items.forEach(function (item, idx) {
      var colour = idx % 2 === 0 ? brand : S.shade(brand, 0.55);
      body.push(S.text(10, y + 12, item.code + " · " + TR.charts.clip(item.title, 64),
        { "font-size": 12.5, "font-weight": 700, fill: "#1c2333" }));
      body.push(S.text(width - 10, y + 12,
        "n=" + (item.base != null ? fmt.base(item.base) : "–"),
        { "text-anchor": "end", "font-size": 10.5, fill: "#9aa1b1" }));
      y += 22;
      item.rows.forEach(function (row) {
        var w = typeof row.value === "number" ? Math.max(x(row.value), 0) : 0;
        body.push(S.text(C.CHART_LABEL_WIDTH - 8, y + 13, TR.charts.clip(row.label, 26),
          { "text-anchor": "end", "font-size": 11.5, fill: "#3b4252" }));
        body.push(S.el("rect", { x: C.CHART_LABEL_WIDTH, y: y, width: plotW,
          height: 18, fill: "#eef0f7", rx: 3 }));
        body.push(S.el("rect", { x: C.CHART_LABEL_WIDTH, y: y, width: w,
          height: 18, fill: colour, rx: 3 }));
        body.push(S.text(C.CHART_LABEL_WIDTH + w + 6, y + 13,
          fmt.num(row.value, "pct", fmt.pctDecimals(payload)) +
          (row.sig ? " " + row.sig : ""),
          { "font-size": 11.5, "font-weight": 600, fill: "#1c2333" }));
        y += 24;
      });
      y += 10;
      if (idx < model.items.length - 1) {
        body.push(S.el("line", { x1: 10, y1: y, x2: width - 10, y2: y, stroke: "#e5e7ef" }));
        y += 12;
      }
    });
    body.push(S.text(C.CHART_LABEL_WIDTH, y + 4,
      "Shared axis 0–" + model.sharedMax + "% · column: " + model.column,
      { "font-size": 10, fill: "#9aa1b1" }));
    y += 18;
    y = renderTrendStrips(model, body, y, width, brand, accent);
    return S.root(width, y, "Composite view — " + model.items.length +
      " questions · " + model.column, body.join(""));
  };

  /** Aligned per-question trend strips (each strip keeps its own unit). */
  function renderTrendStrips(model, body, y, width, brand, accent) {
    if (!model.trends.length || !model.waveLabels) return y;
    y += 10;
    body.push(S.el("line", { x1: 10, y1: y, x2: width - 10, y2: y, stroke: "#e5e7ef" }));
    y += 18;
    body.push(S.text(10, y, "Trend by wave · " + model.column +
      (model.mixedWaves ? " · note: wave labels differ, aligned by position" : ""),
      { "font-size": 11, "font-weight": 700, fill: "#1c2333" }));
    y += 10;
    var padL = 190, padR = 110, stripH = 44;
    var nWaves = model.waveLabels.length;
    var xAt = function (i) { return padL + (i / (nWaves - 1)) * (width - padL - padR); };

    model.trends.forEach(function (trend, ti) {
      var numbers = trend.values.filter(function (v) { return typeof v === "number"; });
      if (!numbers.length) return;
      var lo = Math.min.apply(null, numbers), hi = Math.max.apply(null, numbers);
      var pad = Math.max((hi - lo) * 0.3, 0.1);
      var yAt = function (v) {
        return y + 12 + (1 - (v - (lo - pad)) / ((hi + pad) - (lo - pad))) * (stripH - 16);
      };
      var colour = ti % 2 === 0 ? brand : accent;
      body.push(S.text(padL - 10, y + stripH / 2 + 4,
        TR.charts.clip(trend.code + " " + trend.stat, 24),
        { "text-anchor": "end", "font-size": 11, fill: "#3b4252" }));
      var pts = trend.values.map(function (v, i) { return xAt(i) + "," + yAt(v); }).join(" ");
      body.push(S.el("polyline", { points: pts, fill: "none", stroke: colour,
        "stroke-width": 2.5, "stroke-linecap": "round" }));
      trend.values.forEach(function (v, i) {
        body.push(S.el("circle", { cx: xAt(i), cy: yAt(v), r: 3, fill: colour }));
      });
      body.push(S.text(xAt(nWaves - 1) + 8, yAt(trend.values[nWaves - 1]) + 4,
        fmt.num(trend.values[nWaves - 1], trend.format),
        { "font-size": 11, "font-weight": 700, fill: "#1c2333" }));
      y += stripH;
    });
    y += 6;
    model.waveLabels.forEach(function (label, i) {
      body.push(S.text(xAt(i), y + 6, TR.charts.clip(label, 14),
        { "text-anchor": "middle", "font-size": 10.5, fill: "#6b7280" }));
    });
    return y + 22;
  }

  /* ----- drawer UI + mounted composite cards (DOM from here down) ----- */

  composer.openDrawer = function (payload) {
    var drawer = document.getElementById("composer-drawer");
    var cols = payload.banner.columns;
    var picks = payload.questions.map(function (q) {
      return '<label class="qpick"><input type="checkbox" value="' +
        fmt.escapeHtml(q.id) + '"><span class="code">' +
        fmt.escapeHtml(q.code || q.id) + "</span><span>" +
        fmt.escapeHtml(TR.charts.clip(q.title, 60)) +
        (q.meta && q.meta.waves ? " ↗" : "") + "</span></label>";
    }).join("");
    drawer.innerHTML = '<div class="drawerhead"><h2>Compose a cross-question view</h2>' +
      '<button type="button" data-action="drawer-close" aria-label="Close">✕</button></div>' +
      "<p class='drawerhint'>Pick " + C.COMPOSE_MIN + "–" + C.COMPOSE_MAX +
      " questions. Percentages share one axis; trended questions (↗) also get " +
      "aligned wave strips.</p>" +
      '<div class="field"><label for="compose-col">Banner column</label>' +
      '<select id="compose-col">' + cols.map(function (c, i) {
        return '<option value="' + i + '">' + fmt.escapeHtml(c) + "</option>";
      }).join("") + "</select></div>" +
      '<div id="compose-list">' + picks + "</div>" +
      '<div id="compose-errors" role="alert"></div>' +
      '<button type="button" class="primary wide" data-action="compose-submit">Compose view</button>';
    TR.wire.openDrawer("composer-drawer");
  };

  composer.submit = function (payload) {
    var ids = Array.prototype.map.call(
      document.querySelectorAll("#compose-list input:checked"),
      function (el) { return el.value; });
    var colIndex = parseInt(document.getElementById("compose-col").value, 10) || 0;
    var result = composer.compose(payload, ids, colIndex);
    if (!result.ok) {
      document.getElementById("compose-errors").innerHTML =
        '<ul class="drawer-errors">' + result.errors.map(function (e) {
          return "<li>" + fmt.escapeHtml(e.message) + "</li>";
        }).join("") + "</ul>";
      return;
    }
    mountCard(result.model, payload);
    TR.wire.closeDrawers();
    TR.wire.toast("Composite view created");
  };

  function mountCard(model, payload) {
    var id = "comp-" + nextId++;
    composer._models[id] = model;
    var holder = document.getElementById("composites");
    var article = document.createElement("article");
    article.className = "card composite";
    article.id = id;
    article.setAttribute("data-comp", id);
    article.innerHTML = '<header class="cardhead"><div class="cardmeta">' +
      '<span class="qcode">Composite</span>' +
      '<span class="qtype qtype-trend">' + model.items.length + " questions</span>" +
      '<div class="cardactions">' +
      '<button type="button" data-action="composite-copy">Copy PNG</button>' +
      '<button type="button" data-action="composite-png">PNG</button>' +
      '<button type="button" class="primary" data-action="composite-deck">+ Deck</button>' +
      '<button type="button" data-action="composite-remove" aria-label="Remove composite">✕</button>' +
      "</div></div><h2>" + fmt.escapeHtml(model.items.map(function (i) {
        return i.code; }).join(" + ")) + " — combined view</h2>" +
      '<p class="baseline">Column: ' + fmt.escapeHtml(model.column) +
      " · composed from the embedded data layer</p></header>" +
      '<div class="chart" data-slot="composite"></div>';
    holder.prepend(article);
    TR.cards.renderSlot(article.querySelector('[data-slot="composite"]'),
      function () { return composer.renderSvg(model, payload); }, false);
    article.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  composer.modelFor = function (card) {
    return composer._models[card.getAttribute("data-comp")] || null;
  };

  composer.removeCard = function (card) { card.remove(); };

  composer.addToDeck = function (card, payload) {
    var model = composer.modelFor(card);
    if (model) TR.deck.addComposite(model, payload);
  };

  composer.downloadPng = function (card, payload) {
    var model = composer.modelFor(card);
    if (model) TR.exportPng.downloadComposite(model, payload);
  };

  composer.copyPng = function (card, payload) {
    var model = composer.modelFor(card);
    if (model) TR.exportCopy.copyCompositePng(model, payload);
  };

})(typeof window !== "undefined" ? window : globalThis);
