/**
 * v2 crosstabs tab — sidebar (collapsible categories, search, hideable),
 * one active question with banner tabs (incl. NET-grouping custom banners),
 * controls (heatmap/chart/counts/deltas/detail/summary/dual-sig), sortable
 * columns, hideable rows+columns, multi-column typed charts, banner-aware
 * insights and flag-based pinning. Explainers render as a footer.
 *
 * SIZE-EXCEPTION: the crosstabs workspace is one interaction surface.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var cards2 = TR.cards2 = {};

  function navOrder() {
    var order = [];
    TR.d2.categories().forEach(function (cat) {
      order = order.concat(cat.codes);
    });
    return order;
  }

  /** Model options derived from the current state for the active question. */
  function modelOpts() {
    var s = TR.d2.state;
    return {
      hiddenRows: s.hiddenRows[s.activeQ] || [],
      rowScope: TR.d2.rowScope(),
      sort: s.sorts[s.activeQ] || null,
      dual: s.sigMode === "dual"
    };
  }

  /** sigMode "off" hides every significance letter (screen AND exports). */
  function applySigMode(model) {
    if (model && TR.d2.state.sigMode === "off") {
      model.rows.forEach(function (row) {
        row.cells.forEach(function (cell) { cell.sig = ""; });
      });
    }
    return model;
  }

  cards2.activeModel = function () {
    var s = TR.d2.state;
    return applySigMode(
      TR.model.forQuestion(s.activeQ, s.banner, s.filters, modelOpts()));
  };

  /** Chart model: full rows and ALL columns (the chart picks its own
   *  columns by label, independent of table hiding), with the chart-row
   *  kind resolved ("auto" prefers NET groupings on scale/NPS — Promoter,
   *  not 0–10). */
  cards2.chartModel = function () {
    var s = TR.d2.state;
    var opts = modelOpts();
    opts.rowScope = "all";
    opts.hiddenCols = [];
    var model = TR.model.forQuestion(s.activeQ, s.banner, s.filters, opts);
    if (model) model.chartKind = cards2.resolveChartKind(model);
    return applySigMode(model);
  };

  /** Chart column indexes resolved from the selected labels. */
  cards2.chartCols = function (chartModel) {
    var labels = TR.d2.state.chartColLabels;
    var cols = [];
    chartModel.columns.forEach(function (col, i) {
      if (labels.indexOf(col.label) !== -1) cols.push(i);
    });
    return cols.length ? cols : [0];
  };

  /** Everything the chart is currently showing (for pins/exports). */
  cards2.chartState = function () {
    var chartModel = cards2.chartModel();
    return {
      type: TR.d2.state.chartType,
      kind: chartModel ? chartModel.chartKind : "detail",
      cols: chartModel ? cards2.chartCols(chartModel) : [0]
    };
  };

  /**
   * Resolve the chart-row kind for THIS question. "auto" (the initial
   * state) prefers NET groupings on scale/NPS questions; an explicit
   * choice is honoured, except that NET-based choices degrade to detail
   * when the question simply has no NET rows.
   */
  cards2.resolveChartKind = function (model) {
    var kind = TR.d2.state.chartKind;
    var hasNets = TR.render.hasNetRows(model);
    if (kind === "auto") {
      return hasNets && (model.type === "scale" || model.type === "nps")
        ? "summary" : "detail";
    }
    if (!hasNets && (kind === "summary" || kind === "both")) return "detail";
    return kind;
  };

  cards2.renderTab = function (host) {
    // fresh wrapper per render: listeners die with the old wrapper, so
    // re-entering the tab can never stack duplicate handlers
    var wrap = document.createElement("div");
    wrap.innerHTML = '<div class="xtab-layout" id="xtab">' +
      '<nav class="side" aria-label="Questions">' +
      '<input id="qsearch" type="search" placeholder="Search ' +
      TR.AGG.questions.length + ' questions…" aria-label="Search questions">' +
      '<div class="qlist">' + sidebarHtml() + "</div></nav>" +
      '<div class="content">' +
      '<div id="controls" class="controls"></div>' +
      '<div id="qcard"></div>' +
      explainersHtml() + "</div></div>";
    host.replaceChildren(wrap);
    renderControls();
    cards2.renderActive();
    wire(wrap);
  };

  function sidebarHtml() {
    var d2 = TR.d2;
    return d2.categories().map(function (cat) {
      return '<div class="catgrp"><button class="cathdr" data-cattoggle>' +
        '<span class="catchev">▼</span>' + fmt.escapeHtml(cat.title) +
        ' <span class="catn">(' + cat.codes.length + ")</span></button>" +
        '<div class="catitems">' +
        cat.codes.map(function (code) {
          var q = d2.questionByCode(code);
          return '<a class="qlink" href="#" data-code="' + code + '" title="' +
            fmt.escapeHtml(code + " — " + q.title) + '" data-search="' +
            fmt.escapeHtml((code + " " + q.title).toLowerCase()) + '">' +
            '<span class="qc">' + code + "</span><span class='qt'>" +
            fmt.escapeHtml(q.title) + "</span></a>";
        }).join("") + "</div></div>";
    }).join("");
  }

  function renderControls() {
    var s = TR.d2.state;
    var toggle = function (key, label, title) {
      return '<label class="tg" title="' + (title || "") +
        '"><input type="checkbox" data-ctl="' + key + '"' +
        (s[key] ? " checked" : "") + "> " + label + "</label>";
    };
    document.getElementById("controls").innerHTML =
      '<button data-act="toggleside" title="Show/hide the question list">⟨⟩ Question list</button>' +
      toggle("heatmap", "Heatmap") +
      toggle("showChart", "Chart") +
      toggle("showCounts", "Counts") +
      toggle("showDetail", "Detail rows", "Show the detailed category rows") +
      toggle("showSummary", "Summary rows", "Show NET and Index rows") +
      '<label class="tg" title="Show/hide significance letters and choose the confidence level(s)">Sig ' +
      '<select data-sigmode>' +
      '<option value="off"' + (s.sigMode === "off" ? " selected" : "") + ">Off</option>" +
      '<option value="95"' + (s.sigMode === "95" ? " selected" : "") + ">95%</option>" +
      '<option value="dual"' + (s.sigMode === "dual" ? " selected" : "") + ">95% + 80%</option>" +
      "</select></label>" +
      (TR.d2.tracking().enabled
        ? toggle("showDeltas", "Δ + trend",
            "Change vs the most recent prior wave with this question, " +
            "plus the wave strip")
        : "") +
      '<span class="pinwrap"><button data-act="columns" aria-haspopup="true" ' +
      'title="One place to choose which rows and banner columns show on the ' +
      'table and the chart">' +
      "Rows &amp; columns…</button>" +
      '<span id="colmenu" class="pinmenu colmenu" hidden></span></span>' +
      '<span class="ctl-spacer"></span>' +
      '<button data-act="copy">Copy table</button>' +
      '<button data-act="excel" title="Download this table as an Excel workbook">Excel</button>' +
      '<button data-act="png" title="Hi-res PNG of the current view">PNG</button>' +
      '<span class="pinwrap"><button data-act="pin" class="primary">📌 Pin…</button>' +
      '<span id="pinmenu" class="pinmenu" hidden></span></span>';
  }

  /** (Re)build the rows & columns panel for the active question. One
   *  panel configures the table AND the chart — columns (table/chart
   *  checks), row visibility, and which row kind the chart plots. */
  function buildColumnsPanel() {
    var menu = document.getElementById("colmenu");
    if (!menu) return;
    var chartModel = cards2.chartModel();
    if (!chartModel) { menu.innerHTML = ""; return; }
    var s = TR.d2.state;
    var hidden = TR.d2.hiddenFor(s.banner);
    var hiddenRows = s.hiddenRows[s.activeQ] || [];
    var cols = chartModel.columns.map(function (col, i) {
      var inTable = hidden.indexOf(col.label) === -1;
      var inChart = s.chartColLabels.indexOf(i === 0 ? "Total" : col.label) !== -1;
      return '<div class="cm-row"><span class="cm-label" title="' +
        fmt.escapeHtml(col.label) + '">' +
        fmt.escapeHtml(TR.charts.clip(col.label, 30)) + "</span>" +
        '<label><input type="checkbox" data-cmtable="' + fmt.escapeHtml(col.label) +
        '"' + (inTable ? " checked" : "") + (i === 0 ? " disabled" : "") + "></label>" +
        '<label><input type="checkbox" data-cmchart="' + fmt.escapeHtml(col.label) +
        '"' + (inChart ? " checked" : "") + "></label></div>";
    }).join("");
    var rows = chartModel.rows.map(function (row) {
      return '<div class="cm-row"><span class="cm-label" title="' +
        fmt.escapeHtml(row.label) + '">' +
        fmt.escapeHtml(TR.charts.clip(row.label, 26)) +
        (row.kind !== "category" ? ' <span class="kindtag">' +
          (row.diff ? "diff" : row.kind) + "</span>" : "") + "</span>" +
        '<label><input type="checkbox" data-cmrow="' + fmt.escapeHtml(row.label) +
        '"' + (hiddenRows.indexOf(row.label) === -1 ? " checked" : "") +
        "></label><span></span></div>";
    }).join("");
    var kind = cards2.resolveChartKind(chartModel);
    var hasNets = TR.render.hasNetRows(chartModel);
    menu.innerHTML =
      '<div class="cm-sect">Columns</div>' +
      '<div class="cm-head"><span>Column</span><span>Table</span>' +
      "<span>Chart</span></div><div class='cm-body'>" + cols + "</div>" +
      '<div class="cm-sect">Rows</div>' +
      '<div class="cm-head"><span>Row</span><span>Show</span><span></span></div>' +
      "<div class='cm-body'>" + rows + "</div>" +
      '<div class="cm-sect">Chart plots</div>' +
      '<select data-chartkindsel class="wide"' +
      (hasNets ? "" : ' disabled title="This question has no NET rows — detail only"') +
      '><option value="detail"' + (kind === "detail" ? " selected" : "") +
      ">Detail categories</option>" +
      '<option value="summary"' + (kind === "summary" ? " selected" : "") +
      ">Groupings (NETs)</option>" +
      '<option value="both"' + (kind === "both" ? " selected" : "") +
      ">Both</option></select>" +
      '<button class="primary wide" data-act="columns-done">Done</button>';
  }

  function bannerTabsHtml() {
    var s = TR.d2.state;
    var out = TR.AGG.banner_groups.map(function (g) {
      return '<button class="btab' + (s.banner === g.id ? " on" : "") +
        '" data-banner="' + g.id + '">' + fmt.escapeHtml(g.name) + "</button>";
    });
    if (s.banner && s.banner.indexOf("custom:") === 0) {
      var q = TR.d2.questionByCode(s.banner.split(":")[1]);
      out.push('<button class="btab on custom" data-banner="' + s.banner + '">⚒ ' +
        fmt.escapeHtml(TR.charts.clip(q ? q.title : s.banner, 28)) + "</button>");
    }
    if (TR.d2.hasMicrodata()) {
      out.push('<button class="btab add" data-act="custom-banner" ' +
        'title="Cross this question by any other question">+ Custom…</button>');
    }
    return '<div class="btabs" role="group" aria-label="Banner">' + out.join("") + "</div>";
  }

  cards2.renderActive = function () {
    var s = TR.d2.state;
    var holder = document.getElementById("qcard");
    if (!holder) return;
    var model = cards2.activeModel();
    if (!model) { holder.innerHTML = ""; return; }

    var sourceBadge = model.source === "computed"
      ? '<span class="badge-computed" title="' +
        fmt.escapeHtml("Recomputed live from microdata. " +
          (TR.d2.filterDescription() || "")) + '">COMPUTED · n=' +
        fmt.base(model.columns[0].base) + "</span>"
      : '<span class="badge-published" title="Published 2025 value, verbatim">PUBLISHED</span>';
    var prevBadge = model.prevWave
      ? '<span class="badge-prev" title="' + model.history.length +
        " prior wave" + (model.history.length > 1 ? "s" : "") + " · latest " +
        fmt.escapeHtml(model.prevWave.wave) + " (n=" +
        fmt.base(model.prevWave.base) + ')">tracked since ' +
        model.history[0].year + "</span>"
      : '<span class="badge-prev off">new in 2025</span>';

    // context strip: filters + custom banner can never get lost (item 14/15)
    var contextBits = [];
    if (s.filters.length) contextBits.push("Filtered: " + TR.d2.filterDescription());
    if (s.banner.indexOf("custom:") === 0) contextBits.push(TR.d2.bannerDescription());
    var contextStrip = contextBits.length
      ? '<div class="ctxstrip">⚠ ' + fmt.escapeHtml(contextBits.join("  ·  ")) +
        " — shown on every pin and export</div>"
      : "";

    var html = '<article class="card qc-card">' +
      '<div class="qhead"><div class="qmeta"><span class="qcode">' + model.code +
      "</span>" + sourceBadge + prevBadge +
      '<span class="qnav"><button data-act="prevq" aria-label="Previous question">‹</button>' +
      '<button data-act="nextq" aria-label="Next question">›</button></span></div>' +
      "<h2>" + fmt.escapeHtml(model.title) + "</h2>" + contextStrip + bannerTabsHtml() + "</div>";

    var chartModel = null;
    if (s.showChart) {
      chartModel = cards2.chartModel();
      var kind = chartModel ? chartModel.chartKind : "detail";
      // row kind + chart columns are configured in the single
      // "Rows & columns…" panel on the controls bar — no duplicate
      // triggers here (the toolbar keeps only the chart type)
      html += '<div class="charttools"><label class="ctlab" for="charttype-sel">Type</label>' +
        '<select id="charttype-sel" data-charttypesel>' +
        TR.render.CHART_TYPES.map(function (t) {
          return '<option value="' + t[0] + '"' +
            (s.chartType === t[0] ? " selected" : "") + ">" + t[1] + "</option>";
        }).join("") + "</select>" +
        '<span class="ctlab chartmeta">' +
        cards2.chartCols(chartModel).length + " column" +
        (cards2.chartCols(chartModel).length === 1 ? "" : "s") + " · " +
        (kind === "summary" ? "groupings" : kind === "both" ? "detail + groupings"
          : "detail rows") + " — change under Rows &amp; columns…</span></div>" +
        '<div class="chart">' + safeChart(chartModel) + "</div>";
    }
    if (model.hiddenCount || model.hiddenRowCount) {
      var bits = [];
      if (model.hiddenCount) bits.push(model.hiddenCount + " column" + (model.hiddenCount > 1 ? "s" : ""));
      if (model.hiddenRowCount) bits.push(model.hiddenRowCount + " row" + (model.hiddenRowCount > 1 ? "s" : ""));
      html += '<div class="hiddenbar">' + bits.join(" + ") + " hidden " +
        '<button data-act="showall" class="linklike">show all</button></div>';
    }
    html += '<div class="twrap">' + TR.render.tableHtml(model, {
      heatmap: s.heatmap, showCounts: s.showCounts,
      showDeltas: s.showDeltas && TR.d2.tracking().enabled,
      hideable: true, rowHideable: true, sortable: true }) + "</div>";
    if (s.showDeltas && TR.d2.tracking().enabled) {
      html += TR.render.waveStripHtml(model);
    }

    var bannerName = TR.d2.bannerDescription().replace("Banner: ", "");
    html += '<div class="insight"><div class="insight-head">Analyst insight · ' +
      fmt.escapeHtml(TR.charts.clip(bannerName, 30)) +
      ' <span class="hint">banner-specific, falls back to the general note · saved locally · in saved copies</span></div>' +
      '<textarea id="insight-box" placeholder="Insight for ' + model.code +
      " (" + fmt.escapeHtml(TR.charts.clip(bannerName, 24)) + ")…\">" +
      fmt.escapeHtml(TR.insights.get(model.code, s.banner)) + "</textarea></div></article>";
    holder.innerHTML = html;
    document.querySelectorAll(".qlink").forEach(function (a) {
      var active = a.getAttribute("data-code") === s.activeQ;
      a.classList.toggle("on", active);
      if (active && a.scrollIntoView) a.scrollIntoView({ block: "nearest" });
    });
    TR.d2.pushHash();
  };

  function safeChart(model) {
    try {
      return TR.render.chartBy(TR.d2.state.chartType, model,
        cards2.chartCols(model)) ||
        '<div class="chart-error">Nothing to chart for this row scope.</div>';
    } catch (e) {
      if (global.console) console.error("[TurasV2] chart failed:", e);
      return '<div class="chart-error">Chart unavailable — the table is unaffected.</div>';
    }
  }

  /** Export-grade chart string respecting type, columns and row kind. */
  cards2.chartString = function () {
    try {
      var chartModel = cards2.chartModel();
      return chartModel ? TR.render.chartBy(TR.d2.state.chartType, chartModel,
        cards2.chartCols(chartModel)) : null;
    } catch (e) { return null; }
  };

  function explainersHtml() {
    var p = TR.AGG.project;
    return '<div class="callout collapsed footer-callout"><button class="callout-head" data-callout>' +
      '<span class="callout-ico">i</span> Reading this table — legend' +
      '<span class="callout-chev">▼</span></button><div class="callout-body"><ul>' +
      "<li><strong>Heatmap</strong> — cell shading scales with the value within each row.</li>" +
      "<li><strong>▲ letters</strong> — significantly higher than that lettered column. With the 80% option on: UPPERCASE = 95% confidence, lowercase = 80%.</li>" +
      "<li><strong>⚠ low base</strong> — fewer than " + p.low_base_threshold +
      " respondents; excluded from significance testing.</li>" +
      "<li><strong>▲/▼ chips on Total</strong> — change vs the most recent " +
      "prior wave carrying this question; outlined chips are significant " +
      "changes. The wave strip under tracked questions plots the full " +
      "published history.</li>" +
      "<li><strong>PUBLISHED / COMPUTED</strong> — published figures are the report of record; filtered or custom-banner figures recompute live and are badged.</li>" +
      "<li><strong>NET rows</strong> (navy edge) combine categories; <strong>Index rows</strong> (gold edge) are score-weighted means. Sort by clicking a column header; hide rows/columns with ✕.</li>" +
      "</ul></div></div>" +
      '<div class="callout collapsed footer-callout"><button class="callout-head" data-callout>' +
      '<span class="callout-ico">σ</span> Understanding the significance testing' +
      '<span class="callout-chev">▼</span></button><div class="callout-body">' +
      "<p>Column percentages are compared pairwise within the banner using a " +
      "<strong>two-proportion pooled z-test</strong> — at 95% confidence, plus an " +
      "optional 80% level shown as lowercase letters (the tabs dual-significance " +
      "convention). Letters are only awarded when expected counts are ≥ 5 in both " +
      "columns and both bases are at least " + p.low_base_threshold + ". Index " +
      "means use <strong>Welch's t-test</strong> on banded scores. Year-on-year " +
      "chips test this wave's Total against the prior wave's Total.</p></div></div>";
  }

  function openPinMenu() {
    var menu = document.getElementById("pinmenu");
    var s = TR.d2.state;
    closeColMenu();   // never two panels at once
    if (!menu.hidden) { menu.hidden = true; return; }   // toggle on re-click
    menu.hidden = false;
    setTimeout(function () {
      document.addEventListener("click", function closer(e) {
        if (!e.target.closest(".pinwrap")) {
          menu.hidden = true;
          document.removeEventListener("click", closer);
        }
      });
    }, 0);
    var tracked = !!cards2.activeModel().prevWave;
    menu.innerHTML = '<div class="pm-title">Pin to story</div>' +
      '<label><input type="checkbox" id="pm-chart"' +
      (s.showChart ? " checked" : "") + "> Chart (" +
      fmt.escapeHtml(s.chartType) + ")</label>" +
      '<label><input type="checkbox" id="pm-table" checked> Table</label>' +
      '<label><input type="checkbox" id="pm-insight" checked> Insight</label>' +
      '<button class="primary wide" id="pm-go">Pin</button>' +
      (tracked
        ? '<div class="pm-title pm-sep">Trend exhibit</div>' +
          '<button class="wide" id="pm-exhibit" title="Two-panel exhibit: this ' +
          "wave's distribution chart with the trend over waves below — exports " +
          'to PowerPoint as two editable chart objects on one slide">' +
          "📈 Pin distribution + trend</button>"
        : "");
    document.getElementById("pm-go").addEventListener("click", function () {
      var flags = {
        chart: document.getElementById("pm-chart").checked,
        table: document.getElementById("pm-table").checked,
        insight: document.getElementById("pm-insight").checked
      };
      menu.hidden = true;
      if (!flags.chart && !flags.table && !flags.insight) {
        TR.shell.toast("Pick at least one element to pin");
        return;
      }
      TR.story2.pinCurrent(flags);
    });
    var exhibitBtn = document.getElementById("pm-exhibit");
    if (exhibitBtn) {
      exhibitBtn.addEventListener("click", function () {
        menu.hidden = true;
        TR.story2.pinExhibit();
      });
    }
  }

  function step(delta) {
    var codes = navOrder();
    var at = codes.indexOf(TR.d2.state.activeQ);
    var next = Math.min(Math.max(at + delta, 0), codes.length - 1);
    TR.d2.state.activeQ = codes[next];
    closeColMenu();
    cards2.renderActive();
  }

  /** Close the columns panel from anywhere (outside click, Esc, nav). */
  function closeColMenu() {
    if (!TR.d2.state.colMenuOpen) return;
    TR.d2.state.colMenuOpen = false;
    var menu = document.querySelector(".colmenu");
    if (menu) menu.hidden = true;
    var btn = document.querySelector('[data-act="columns"]');
    if (btn) btn.setAttribute("aria-expanded", "false");
  }

  /* one document-level closer for the columns panel — registered once,
     so tab re-renders can never stack duplicates */
  if (typeof document !== "undefined" && !cards2._colMenuCloser) {
    cards2._colMenuCloser = true;
    document.addEventListener("click", function (e) {
      // a target detached mid-click was re-rendered by an in-panel action
      // (e.g. a checkbox tick) — never treat that as an outside click
      if (e.target && e.target.isConnected === false) return;
      if (!e.target.closest('.pinwrap, [data-act="columns"]')) closeColMenu();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") closeColMenu();
    });
  }

  function cycleSort(colIndex) {
    var s = TR.d2.state;
    var cur = s.sorts[s.activeQ];
    if (!cur || cur.col !== colIndex) {
      s.sorts[s.activeQ] = { col: colIndex, dir: "desc" };
    } else if (cur.dir === "desc") {
      s.sorts[s.activeQ] = { col: colIndex, dir: "asc" };
    } else {
      delete s.sorts[s.activeQ];   // back to original order
    }
    cards2.renderActive();
  }

  function wire(host) {
    host.addEventListener("click", function (e) {
      var link = e.target.closest(".qlink");
      if (link) {
        e.preventDefault();
        TR.d2.state.activeQ = link.getAttribute("data-code");
        closeColMenu();
        cards2.renderActive();
        return;
      }
      var btab = e.target.closest(".btab[data-banner]");
      if (btab) {
        TR.d2.state.banner = btab.getAttribute("data-banner");
        TR.d2.state.chartColLabels = ["Total"];  // selection is per banner
        closeColMenu();
        cards2.renderActive();
        return;
      }
      var cmTable = e.target.closest("[data-cmtable]");
      if (cmTable) {
        var banner = TR.d2.state.banner;
        var list = TR.d2.state.hiddenCols[banner] =
          TR.d2.state.hiddenCols[banner] || [];
        var label = cmTable.getAttribute("data-cmtable");
        var at = list.indexOf(label);
        if (at === -1) list.push(label);
        else list.splice(at, 1);
        cards2.renderActive();
        buildColumnsPanel();   // panel lives in the controls bar — refresh it
        return;
      }
      var cmChart = e.target.closest("[data-cmchart]");
      if (cmChart) {
        var labels = TR.d2.state.chartColLabels;
        var chartLabel = cmChart.getAttribute("data-cmchart");
        var pos = labels.indexOf(chartLabel);
        if (pos === -1) labels.push(chartLabel);
        else if (labels.length > 1) labels.splice(pos, 1);
        cards2.renderActive();
        buildColumnsPanel();
        return;
      }
      var cmRow = e.target.closest("[data-cmrow]");
      if (cmRow) {
        var rowQ = TR.d2.state.activeQ;
        var rowList = TR.d2.state.hiddenRows[rowQ] =
          TR.d2.state.hiddenRows[rowQ] || [];
        var rowLabel = cmRow.getAttribute("data-cmrow");
        var rowAt = rowList.indexOf(rowLabel);
        if (rowAt === -1) rowList.push(rowLabel);
        else rowList.splice(rowAt, 1);
        cards2.renderActive();
        buildColumnsPanel();
        return;
      }
      if (e.target.closest('[data-act="columns-done"]')) {
        closeColMenu();
        return;
      }
      if (e.target.closest(".colmenu")) return;   // clicks inside the panel
      if (e.target.closest("[data-cattoggle]")) {
        e.target.closest(".catgrp").classList.toggle("collapsed");
        return;
      }
      if (e.target.closest("[data-callout]")) {
        e.target.closest(".callout").classList.toggle("collapsed");
        return;
      }
      var hideBtn = e.target.closest("[data-hidecol]");
      if (hideBtn) {
        var banner = TR.d2.state.banner;
        (TR.d2.state.hiddenCols[banner] = TR.d2.state.hiddenCols[banner] || [])
          .push(hideBtn.getAttribute("data-hidecol"));
        cards2.renderActive();
        return;
      }
      var hideRow = e.target.closest("[data-hiderow]");
      if (hideRow) {
        var qid = TR.d2.state.activeQ;
        (TR.d2.state.hiddenRows[qid] = TR.d2.state.hiddenRows[qid] || [])
          .push(hideRow.getAttribute("data-hiderow"));
        cards2.renderActive();
        return;
      }
      var sortTh = e.target.closest("th[data-sortcol]");
      if (sortTh && !e.target.closest(".colx")) {
        cycleSort(parseInt(sortTh.getAttribute("data-sortcol"), 10));
        return;
      }
      var act = e.target.closest("[data-act]");
      if (!act) return;
      var action = act.getAttribute("data-act");
      var model = cards2.activeModel();
      if (action === "toggleside") {
        document.getElementById("xtab").classList.toggle("noside");
      }
      if (action === "columns") {
        var menu = document.getElementById("colmenu");
        if (TR.d2.state.colMenuOpen) {
          closeColMenu();
        } else {
          buildColumnsPanel();
          TR.d2.state.colMenuOpen = true;
          menu.hidden = false;
          act.setAttribute("aria-expanded", "true");
        }
      }
      if (action === "columns-done") closeColMenu();
      if (action === "prevq") step(-1);
      if (action === "nextq") step(1);
      if (action === "copy") TR.exporter.copyTable(model);
      if (action === "excel") {
        TR.xlsx.download(model.code + "_" + model.title, model.code,
          TR.xlsx.rowsFromMatrix(TR.render.matrix(model)));
      }
      if (action === "png") {
        TR.exporter.downloadPng(model, TR.d2.filterDescription(), {
          chartSvg: TR.d2.state.showChart ? cards2.chartString() : null });
      }
      if (action === "pin") openPinMenu();
      if (action === "fulltrend") {
        TR.d2.state.showChart = true;
        TR.d2.state.chartType = "line";
        cards2.renderActive();
      }
      if (action === "showall") {
        delete TR.d2.state.hiddenCols[TR.d2.state.banner];
        delete TR.d2.state.hiddenRows[TR.d2.state.activeQ];
        cards2.renderActive();
      }
      if (action === "custom-banner") TR.filterBar.openCustomBanner();
    });
    host.addEventListener("input", function (e) {
      if (e.target.id === "qsearch") {
        var term = e.target.value.trim().toLowerCase();
        document.querySelectorAll(".qlink").forEach(function (a) {
          a.classList.toggle("hidden",
            !!term && a.getAttribute("data-search").indexOf(term) === -1);
        });
        document.querySelectorAll(".catgrp").forEach(function (grp) {
          grp.classList.toggle("hidden", !grp.querySelector(".qlink:not(.hidden)"));
        });
      }
      if (e.target.id === "insight-box") {
        TR.insights.set(TR.d2.state.activeQ, e.target.value, TR.d2.state.banner);
      }
    });
    host.addEventListener("change", function (e) {
      var ctl = e.target.getAttribute && e.target.getAttribute("data-ctl");
      if (ctl) {
        TR.d2.state[ctl] = e.target.checked;
        cards2.renderActive();
        return;
      }
      if (e.target.hasAttribute && e.target.hasAttribute("data-charttypesel")) {
        TR.d2.state.chartType = e.target.value;
        cards2.renderActive();
        return;
      }
      if (e.target.hasAttribute && e.target.hasAttribute("data-chartkindsel")) {
        TR.d2.state.chartKind = e.target.value;
        cards2.renderActive();
        return;
      }
      if (e.target.hasAttribute && e.target.hasAttribute("data-sigmode")) {
        TR.d2.state.sigMode = e.target.value;
        cards2.renderActive();
      }
    });
  }

})(typeof window !== "undefined" ? window : globalThis);
