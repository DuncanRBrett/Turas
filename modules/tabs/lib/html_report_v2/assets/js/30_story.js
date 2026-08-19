/**
 * v2 story builder — an ordered, annotated narrative of four item kinds:
 * pinned questions (with chart/table/insight flags), section dividers,
 * pinned dashboard heatmaps, and composites (all index metrics of a
 * section in one exhibit). Present full-screen or export a native,
 * editable PowerPoint. Persists locally and inside saved report copies.
 *
 * SIZE-EXCEPTION: one narrative workspace; splitting item kinds across
 * files would obscure the story contract.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var story2 = TR.story2 = {};
  var KEY = "turas_v2_story";
  var items = null;
  var owned = false;   // the reader has changed the story in this browser
  var presentAt = 0;

  function load() {
    if (items) return items;
    items = [];
    var own = null;
    try {
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(KEY));
      if (raw) own = JSON.parse(raw) || null;
    } catch (e) { /* island-only */ }
    // Ownership marker: once the reader changes anything here, the persisted
    // localStorage state carries _owns:true and is authoritative — the island
    // seed is ignored on load, so deletions stay deleted. State without the
    // marker (legacy / first visit) seeds from the island and merges without
    // claiming ownership; only a reader change through the persist path does.
    if (own && !Array.isArray(own) && own._owns) {
      owned = true;
      items = Array.isArray(own.items) ? own.items : [];
      return items;
    }
    if (TR.userState && Array.isArray(TR.userState.story)) {
      items = JSON.parse(JSON.stringify(TR.userState.story));
    }
    if (Array.isArray(own) && own.length) items = own;   // legacy un-owning state
    return items;
  }

  function persist() {
    try {
      if (global.localStorage) {
        localStorage.setItem(TR.d2.storeKey(KEY),
          JSON.stringify(owned ? { _owns: true, items: load() } : load()));
      }
    } catch (e) { /* in-memory only */ }
    if (typeof document === "undefined") return;   // headless (node gate)
    var badge = document.getElementById("story-count");
    if (badge) badge.textContent = String(load().length);
  }

  // A reader change (add/edit/delete/clear) takes ownership, then persists;
  // renderTab's passive persist stays un-owning (it never changes the story).
  function touch() { owned = true; persist(); }

  story2.items = function () { return load(); };

  story2.merge = function (incoming) {
    var have = {};
    load().forEach(function (item) { have[JSON.stringify(item)] = true; });
    (incoming || []).forEach(function (item) {
      if (!have[JSON.stringify(item)]) load().push(item);
    });
    touch();
  };

  /* ---------------- pin creators ---------------- */

  // The first banner group's id, or "" (the Total column) on a Total-only
  // report. banner_groups[0].id thrown unguarded — pinning a tracking view or a
  // composite exhibit on a no-banner survey (e.g. CCS) crashed and nothing
  // pinned.
  function firstBanner() {
    return TR.AGG.banner_groups.length ? TR.AGG.banner_groups[0].id : "";
  }

  // The banner to record on a pinned story item. A custom or composite banner is
  // a live spec that a pinned exhibit can't recompute, so it resolves to the
  // first banner — or "" (Total) on a Total-only survey. (addExhibit read
  // banner_groups[0].id unguarded here and crashed on CCS.)
  function pinBanner() {
    var b = TR.d2.state.banner;
    return (b.indexOf("custom:") === 0 || b.indexOf("composite:") === 0)
      ? firstBanner() : b;
  }
  story2._pinBanner = pinBanner;   // exposed for the node gate

  story2.pinCurrent = function (flags) {
    var s = TR.d2.state;
    var chartState = TR.cards2.chartState();
    // D2: the default pin title is the analyst headline (reader.headlineTitle).
    // NOT the insight's first sentence — the pin body prints the insight in
    // full below the table, so titling the pin with it said it twice. "" keeps
    // each surface's existing default (story head = title, PPTX =
    // short_label/title); older pins carry no title field and render unchanged.
    var ins = (TR.reader && TR.reader.headlineTitle)
      ? TR.reader.headlineTitle(TR.d2.questionByCode(s.activeQ)) : null;
    load().push({
      kind: "question",
      title: ins ? ins.text : "",
      q: s.activeQ,
      banner: s.banner,
      filters: JSON.parse(JSON.stringify(s.filters)),
      flags: flags || { chart: false, table: true, insight: true },
      chartType: chartState.type,
      chartKind: chartState.kind,
      chartCols: chartState.cols,
      hiddenChartRows: (s.hiddenChartRows[s.activeQ] || []).slice(),
      // the pinned TABLE reproduces the screen too: scope, sort, hidden
      // rows/columns and the dual-sig setting travel with the pin
      // (older pins lack these fields and render the full default table)
      rowScope: TR.d2.rowScope(),
      sort: s.sorts[s.activeQ]
        ? JSON.parse(JSON.stringify(s.sorts[s.activeQ])) : null,
      hiddenRows: (s.hiddenRows[s.activeQ] || []).slice(),
      hiddenCols: TR.d2.hiddenFor(s.banner).slice(),
      dual: s.sigMode === "dual",
      intervals: !!s.showIntervals,   // pin shows exactly what was on screen
      counts: !!s.showCounts,         // the "Counts" toggle travels with the pin
      note: ""
    });
    touch();
    TR.shell.toast("Pinned to story (" + load().length + ") — see the Story tab");
  };

  /** The flagship two-panel pin: this-wave distribution + trend-over-waves.
   *  `withComments` comes from the pin menu's own priority-comments tickbox —
   *  the exhibit-then-evidence pair a findings deck is usually built as. */
  story2.pinExhibit = function (withComments) {
    var s = TR.d2.state;
    var chartState = TR.cards2.chartState();
    load().push({ kind: "exhibit", qs: [s.activeQ], banner: s.banner,
      filters: JSON.parse(JSON.stringify(s.filters)),
      flags: { dist: true, trend: true, table: false, insight: true,
        comments: !!withComments },
      distType: chartState.type === "line" ? "column" : chartState.type,
      chartKind: chartState.kind, chartCols: chartState.cols,
      hiddenChartRows: (s.hiddenChartRows[s.activeQ] || []).slice(),
      note: "" });
    touch();
    TR.shell.toast("Trend exhibit pinned (" + load().length + ") — see the Story tab");
  };

  /** Pin a tracking Visualise view exactly as selected: explicit series
   *  (metric × segment each), the elements chosen in the pin popover,
   *  the analyst insight and any data-point annotations. */
  story2.pinTrackingView = function (spec, flags) {
    load().push({ kind: "exhibit", title: spec.title, qs: spec.qs.slice(),
      series: JSON.parse(JSON.stringify(spec.series)),
      annotations: JSON.parse(JSON.stringify(spec.annotations || [])),
      ci: !!spec.ci,
      trendline: !!spec.trendline,   // dashed least-squares fit, as on screen
      banner: firstBanner(), filters: [],
      flags: { dist: !!flags.dist, trend: !!flags.trend,
        table: !!flags.table, insight: flags.insight !== false },
      distType: "column", note: spec.note || "" });
    touch();
    TR.shell.toast("Pinned exactly as selected (" + load().length +
      ") — see the Story tab");
  };

  /** Composite exhibit: any tracked questions, each via its headline metric. */
  story2.addExhibit = function () {
    var tracked = TR.AGG.questions.filter(function (q) {
      var m = TR.model.forQuestion(q.code, firstBanner(), []);
      return m && m.prevWave && TR.exhibit.headlineRow(m);
    });
    var holder = document.getElementById("story-picker");
    holder.hidden = false;
    holder.innerHTML = '<div class="fpick"><div class="fpick-head">Composite ' +
      "exhibit — pick any tracked questions (any sections); each contributes " +
      'its headline metric<button data-close aria-label="Close">✕</button></div>' +
      '<div class="fpick-list">' + tracked.map(function (q) {
        return '<label class="fpick-q"><input type="checkbox" value="' + q.code +
          '"> ' + q.code + " · " + fmt.escapeHtml(TR.charts.clip(q.title, 64)) +
          ' <span class="kindtag">' + fmt.escapeHtml(q.category) + "</span></label>";
      }).join("") + "</div>" +
      '<div class="fpick-foot"><span>Panels:</span>' +
      '<label><input type="checkbox" id="ex-dist" checked> this wave</label>' +
      '<label><input type="checkbox" id="ex-trend" checked> trend</label>' +
      '<label><input type="checkbox" id="ex-table" checked> table</label>' +
      '<button class="primary" id="ex-add">Add exhibit</button></div></div>';
    holder.querySelector("[data-close]").addEventListener("click", function () {
      holder.hidden = true;
    });
    holder.querySelector("#ex-add").addEventListener("click", function () {
      var qs = Array.prototype.slice.call(
        holder.querySelectorAll(".fpick-list input:checked")).map(function (el) {
          return el.value;
        });
      if (!qs.length) { TR.shell.toast("Pick at least one question"); return; }
      load().push({ kind: "exhibit", qs: qs,
        banner: pinBanner(),
        filters: JSON.parse(JSON.stringify(TR.d2.state.filters)),
        flags: { dist: holder.querySelector("#ex-dist").checked,
          trend: holder.querySelector("#ex-trend").checked,
          table: holder.querySelector("#ex-table").checked, insight: true },
        distType: "column", note: "" });
      touch();
      holder.hidden = true;
      story2.renderTab(document.getElementById("tabhost"));
    });
  };

  story2.pinHeatmap = function (banner) {
    load().push({ kind: "heatmap", banner: banner,
      filters: JSON.parse(JSON.stringify(TR.d2.state.filters)), note: "" });
    touch();
    TR.shell.toast("Heatmap pinned to story (" + load().length + ")");
  };

  /** Pin any on-screen card (patterns / dashboard / differences) exactly as it
   *  looks: its own HTML is stored and re-shown in the story and present mode.
   *  `lines` is the card's plain text, used only for the deck export (an HTML
   *  card has no chart/table to rasterise, so the slide shows the same content
   *  rendered as a card). */
  story2.pinSnapshot = function (snap) {
    var item = { kind: "snapshot", source: snap.source || "card",
      title: snap.title || "Pinned card", context: snap.context || "",
      html: snap.html || "", lines: (snap.lines || []).slice(), note: "" };
    // WP4: a structured quotes payload (qual hub exhibits) exports as a
    // quote-typography slide. Additive — the payload arrives ALREADY
    // disclosure-gated (hidden text absent, below-k tags dropped); old pins
    // without it keep the table fallback unchanged.
    if (snap.quotes && snap.quotes.length) {
      item.quotes = JSON.parse(JSON.stringify(snap.quotes));
      item.moreN = snap.moreN || 0;
    }
    load().push(item);
    touch();
    TR.shell.toast("Pinned to story (" + load().length + ") — see the Story tab");
  };

  /** A config-authored study slide, pinned by INDEX into project.slides rather
   *  than by copying it. The picture stays embedded exactly once no matter how
   *  often it is pinned, and a rebuilt report's story keeps pointing at the
   *  current slide. A pin whose slide no longer exists renders as a plain
   *  missing-slide note rather than an empty card. */
  story2.pinSlide = function (idx, title) {
    if (!(idx >= 0)) return;
    load().push({ kind: "slide", slide: idx, title: title || "", note: "" });
    touch();
    TR.shell.toast("Slide pinned to story (" + load().length + ") — see the Story tab");
  };

  /** The authored slide a "slide" item points at, or null when the config no
   *  longer carries it (sheet row deleted, or an older report opened). */
  function slideOf(item) {
    if (!item || item.kind !== "slide") return null;
    var list = (TR.report && TR.report.slides) ? TR.report.slides() : [];
    return list[item.slide] || null;
  }
  story2._slideOf = slideOf;   // exposed for the node gate

  var SLIDE_GONE_NOTE = "This slide is no longer in the project configuration.";

  story2.addDivider = function () {
    var title = prompt("Section title for the divider:");
    if (!title) return;
    load().push({ kind: "divider", title: title, note: "" });
    touch();
    story2.renderTab(document.getElementById("tabhost"));
  };

  story2.addComposite = function () {
    var cats = TR.d2.categories().filter(function (cat) {
      return cat.codes.some(function (code) {
        var q = TR.d2.questionByCode(code);
        return q.rows.some(function (r) { return r.kind === "mean"; });
      });
    });
    var holder = document.getElementById("story-picker");
    holder.hidden = false;
    holder.innerHTML = '<div class="fpick"><div class="fpick-head">Composite — all index ' +
      'metrics of a section in one exhibit<button data-close aria-label="Close">✕</button></div>' +
      cats.map(function (cat) {
        return '<button class="fpick-q" data-cat="' + fmt.escapeHtml(cat.title) + '">' +
          fmt.escapeHtml(cat.title) + "</button>";
      }).join("") + "</div>";
    holder.querySelector("[data-close]").addEventListener("click", function () {
      holder.hidden = true;
    });
    holder.querySelectorAll("[data-cat]").forEach(function (b) {
      b.addEventListener("click", function () {
        load().push({ kind: "composite", category: b.getAttribute("data-cat"),
          banner: pinBanner(),
          filters: JSON.parse(JSON.stringify(TR.d2.state.filters)), note: "" });
        touch();
        holder.hidden = true;
        story2.renderTab(document.getElementById("tabhost"));
      });
    });
  };

  /* ---------------- item models ---------------- */

  function modelFor(item) {
    var model = TR.model.forQuestion(item.q, item.banner, item.filters || [],
      { hiddenCols: item.hiddenCols || [],
        hiddenRows: item.hiddenRows || [],
        rowScope: item.rowScope || "all",
        sort: item.sort || null,
        dual: !!item.dual,
        intervals: !!item.intervals });
    if (model) {
      model.filterNote = filterNote(item);
      model.chartKind = item.chartKind || "detail";
      model.hiddenChartRows = item.hiddenChartRows || [];
    }
    return model;
  }
  story2._modelFor = modelFor;   // exposed for the node gate

  function filterNote(item) {
    if (!item.filters || !item.filters.length) return "";
    return "Filtered: " + item.filters.map(function (f) {
      var q = TR.d2.questionByCode(f.q);
      var labels = f.rows.map(function (ri) {
        return q && q.rows[ri] ? q.rows[ri].label : "?";
      });
      return (q ? q.code : f.q) + " = " + labels.join("/");
    }).join("; ");
  }

  /** Composite model: one row per index question of the category. */
  function compositeMatrix(item) {
    var qs = TR.AGG.questions.filter(function (q) {
      return q.category === item.category &&
        q.rows.some(function (r) { return r.kind === "mean"; });
    });
    var models = qs.map(function (q) {
      return TR.model.forQuestion(q.code, item.banner, item.filters || [],
        { hiddenCols: [] });
    });
    if (!models.length) return null;
    var head = ["Metric"].concat(models[0].columns.map(function (c) {
      return c.label + (c.letter ? " (" + c.letter + ")" : "");
    }));
    var body = models.map(function (m) {
      var row = m.rows.filter(function (r) { return r.kind === "mean"; })[0];
      return { kind: "row", cells: [m.code + " — " + TR.charts.clip(m.title, 60)]
        .concat(row.cells.map(function (c) {
          return c.mean === null ? "–" : c.mean.toFixed(1);
        })) };
    });
    return { head: head, body: body, models: models };
  }

  /** A snapshot's plain text as a one-column matrix for the deck export. */
  function snapshotMatrix(item) {
    var lines = (item.lines && item.lines.length) ? item.lines : [item.title || ""];
    return { head: [item.context ? TR.charts.clip(item.context, 60)
        : (item.source || "Pinned card")],
      body: lines.map(function (l) { return { kind: "row", cells: [l] }; }) };
  }

  function heatmapMatrix(item) {
    var qs = TR.views._indexQuestions();
    var models = {};
    qs.forEach(function (q) {
      models[q.code] = TR.model.forQuestion(q.code, item.banner,
        item.filters || [], { hiddenCols: [] });
    });
    var grid = TR.views._heatMatrix(qs, models);
    return { head: grid.head, body: grid.rows.map(function (r) {
      return { kind: "row", cells: r };
    }) };
  }

  /**
   * Display title for any pin — the stored title first (D2 question pins,
   * snapshots, titled tracking exhibits), else the analyst headline, else the
   * item kind's existing default. The insight is never borrowed as a title
   * here: the pin already shows it in full. Read-only: old pins are never
   * migrated, so a saved copy keeps whatever title it was pinned with.
   */
  story2.pinTitle = function (item) {
    if (item.title) return item.title;
    if (item.kind === "question") {
      var q = TR.d2.questionByCode(item.q);
      var ins = (TR.reader && TR.reader.headlineTitle)
        ? TR.reader.headlineTitle(q) : null;
      if (ins) return ins.text;
      return q ? (TR.d2.shortLabel ? TR.d2.shortLabel(q) : q.title) : item.q;
    }
    if (item.kind === "exhibit") {
      return TR.exhibit.titleFor(item, TR.exhibit.models(item));
    }
    if (item.kind === "slide") {
      var sl = slideOf(item);
      return (sl && sl.title) || "Study slide";
    }
    if (item.kind === "heatmap") return "Index heatmap";
    if (item.kind === "composite") return "Composite — " + item.category;
    return item.kind === "divider" ? (item.title || "Section") : "Pinned card";
  };

  /** Evidence-only body of an item (no head/controls/commentary) — the cover
   *  (24a) renders findings through the SAME renderers as the story tab, so
   *  each pin's disclosure gates travel with it. "" when nothing resolves. */
  /** A frozen qualitative pin is STALE once any quote it froze is no longer
   *  published by the current island (hide-marked since, scope tightened,
   *  confidentiality mode changed, island absent from this copy). The whole
   *  frozen payload — html included — must not render: priority pins
   *  re-resolve on every render for exactly this reason (review 2026-08, I20). */
  function qualPinStale(item) {
    if (!item || item.source !== "qualitative") return false;
    if (!item.quotes || !item.quotes.length) return false;
    if (!TR.qual || !TR.qual.textPublished) return true;
    for (var i = 0; i < item.quotes.length; i++) {
      if (!TR.qual.textPublished(item.quotes[i].text)) return true;
    }
    return false;
  }
  story2._qualPinStale = qualPinStale;   // exposed for the node gate

  var QUAL_STALE_NOTE = "This pinned collection references comments this copy " +
    "no longer publishes — re-pin it from the Qualitative tab.";

  /** The picture (and/or words) of an authored slide, resolved from the island
   *  at render time. Shared by the story card, the cover thumbnail and present
   *  mode, so all three show the current slide rather than a frozen copy. */
  function slideBodyHtml(item) {
    var sl = slideOf(item);
    if (!sl) {
      return '<div class="snap-body"><p class="si-ctx">' +
        fmt.escapeHtml(SLIDE_GONE_NOTE) + "</p></div>";
    }
    return '<div class="snap-body">' +
      (sl.image ? '<img class="si-slide-img" src="' + fmt.escapeHtml(sl.image) +
        '" alt="' + fmt.escapeHtml(sl.title || "Study slide") + '">' : "") +
      (sl.text ? '<div class="as-text">' + fmt.escapeHtml(sl.text) + "</div>" : "") +
      "</div>";
  }

  story2.itemBodyHtml = function (item) {
    if (item.kind === "divider") return "";
    if (item.kind === "slide") return slideBodyHtml(item);
    if (item.kind === "exhibit") return TR.exhibit.panelsHtml(item);
    if (item.kind === "snapshot") {
      if (qualPinStale(item)) {
        return '<div class="snap-body"><p class="si-ctx">' +
          fmt.escapeHtml(QUAL_STALE_NOTE) + "</p></div>";
      }
      return '<div class="snap-body">' + (item.html || "") + "</div>";
    }
    if (item.kind === "heatmap" || item.kind === "composite") {
      var matrix = item.kind === "heatmap" ? heatmapMatrix(item) : compositeMatrix(item);
      return matrix ? '<div class="si-table">' + matrixTable(matrix) + "</div>" : "";
    }
    var model = modelFor(item);
    if (!model) return "";
    var flags = item.flags || { chart: false, table: true };
    if (flags.chart) {
      return '<div class="chart si-chart">' +
        TR.render.chartBy(item.chartType || "bar", model, item.chartCols || [0]) +
        "</div>";
    }
    return '<div class="si-table">' + TR.render.tableHtml(model,
      { heatmap: true, showDeltas: TR.d2.tracking().enabled,
        intervals: !!item.intervals, showCounts: !!item.counts }) + "</div>";
  };

  /** The priority comments a question pin carries, or [] — recomputed from the
   *  island on every render rather than frozen into the pin, because tier 3 is
   *  authored in the coding workbook and is the same for every reader. Guarded:
   *  a report without a qual island has no TR.qual at all. */
  function quotesFor(item) {
    if (!item) return [];
    var flags = item.flags || {};
    if (!flags.comments) return [];
    // A trend exhibit is pinned on one question (qs[0]); a composite exhibit
    // spans several, and there is no one open-end behind it, so it carries none.
    var code = item.kind === "question" ? item.q
      : (item.kind === "exhibit" && item.qs && item.qs.length === 1) ? item.qs[0] : null;
    if (!code) return [];
    return (TR.qual && TR.qual.priorityQuotes) ? TR.qual.priorityQuotes(code) : [];
  }
  story2._quotesFor = quotesFor;   // exposed for the node gate

  /** The quote block for the on-screen surfaces ("" when the pin carries none). */
  function quoteBlockHtml(item) {
    var quotes = quotesFor(item);
    return (quotes.length && TR.qual && TR.qual.priorityBlockHtml)
      ? TR.qual.priorityBlockHtml(quotes) : "";
  }

  function contextLine(item, model) {
    var bits = [];
    if (item.kind === "question") {
      bits.push(TR.d2.bannerDescription(item.banner));
      if (model) bits.push(model.source === "computed" ? "computed live" : "published");
      if (item.intervals) {
        bits.push(TR.conf.methodNote(TR.conf.modelIntervalKind(model)));
      }
    }
    if (item.kind === "heatmap") bits.push(TR.d2.bannerDescription(item.banner));
    if (item.kind === "composite") {
      bits.push(item.category + " · " + TR.d2.bannerDescription(item.banner));
    }
    var filters = filterNote(item);
    if (filters) bits.push(filters);
    return bits.join(" · ");
  }

  /* ---------------- story tab ---------------- */

  story2.renderTab = function (host) {
    var list = load();
    var html = ['<div class="page"><div class="card story-actions">' +
      "<h2>Story · " + list.length + " items</h2><div class='sa-btns'>" +
      '<button data-sact="present" class="primary"' + (list.length ? "" : " disabled") +
      ">▶ Present</button>" +
      '<button data-sact="pptx" class="primary"' + (list.length ? "" : " disabled") +
      ' title="Editable native PowerPoint charts (Edit Data)">Download .pptx (editable)</button>' +
      '<button data-sact="pptx-img" class="primary"' + (list.length ? "" : " disabled") +
      ' title="Pixel-perfect image slides — exactly what is on screen (not editable)">' +
      "Download .pptx (images)</button>" +
      '<button data-sact="divider">+ Section divider</button>' +
      /* the exhibit builder replaces the parked per-section composite;
         story2.addComposite and the old "composite" item kind stay for
         back-compat with previously saved pins */
      '<button data-sact="exhibit">+ Composite exhibit…</button>' +
      '<button data-sact="export" title="Save your insights + pinned story to a small ' +
      'file. Re-import it into a future wave report to carry your commentary forward — ' +
      'Save copy is a frozen snapshot and cannot do that.">Export insights JSON</button>' +
      '<label class="t-btnish" title="Merge insights + story from a previous Export back ' +
      'into this report (e.g. carry last wave commentary forward).">Import JSON' +
      '<input id="story-import" type="file" accept=".json" hidden></label>' +
      '<button data-sact="clear">Clear</button></div>' +
      '<div id="story-picker" hidden></div>' +
      (list.length ? "" : "<p>Pin questions from Crosstabs (📌), the dashboard heatmap, " +
        "or add composites and dividers. You can then present full-screen or export " +
        "a native editable PowerPoint. The JSON downloads a small file containing " +
        "insight notes and pins and you can export it and import it back in if " +
        "needed.</p>") + "</div>"];

    list.forEach(function (item, i) {
      html.push(itemHtml(item, i));
    });
    html.push("</div>");
    // fresh wrapper per render: story re-renders constantly (reorder, notes)
    // and must never stack duplicate listeners on the tab host
    var wrap = document.createElement("div");
    wrap.innerHTML = html.join("");
    host.replaceChildren(wrap);
    wire(wrap);
    if (TR.shell && TR.shell.autoGrowNotes) TR.shell.autoGrowNotes(wrap);   // pin commentary opens at its full height
    persist();
  };

  function itemHtml(item, i) {
    var buttons = '<span class="si-btns"><button data-move="-1" title="Move up">↑</button>' +
      '<button data-move="1" title="Move down">↓</button>' +
      (item.kind === "question" ? '<button data-png title="Download as PNG">PNG</button>' +
        '<button data-open title="Open in Crosstabs">⧉</button>' : "") +
      '<button data-remove title="Remove">✕</button></span>';
    if (item.kind === "divider") {
      return '<div class="card story-item story-divider" data-i="' + i + '">' +
        '<div class="si-head"><span class="qcode">' + (i + 1) + "</span>" +
        '<strong class="divider-title">— ' + fmt.escapeHtml(item.title) + " —</strong>" +
        buttons + "</div></div>";
    }
    if (item.kind === "exhibit") {
      // elements were chosen at pin time — story shows exactly the pin
      var exModels = TR.exhibit.models(item);
      var exFlags = item.flags || {};
      return '<div class="card story-item" data-i="' + i + '">' +
        '<div class="si-head"><span class="qcode">' + (i + 1) + ". TREND</span>" +
        "<strong>" + fmt.escapeHtml(TR.charts.clip(
          TR.exhibit.titleFor(item, exModels), 90)) + "</strong>" +
        '<span class="si-ctx">' +
        fmt.escapeHtml(TR.exhibit.contextLine(item, exModels)) + "</span>" +
        buttons + "</div>" +
        TR.exhibit.panelsHtml(item) +
        quoteBlockHtml(item) +
        (exFlags.insight !== false
          ? '<textarea class="si-note" placeholder="Commentary for this slide…">' +
            fmt.escapeHtml(item.note || "") + "</textarea>" : "") + "</div>";
    }
    if (item.kind === "slide") {
      return '<div class="card story-item story-snapshot" data-i="' + i + '">' +
        '<div class="si-head"><span class="qcode">' + (i + 1) + ". SLIDE</span>" +
        "<strong>" + fmt.escapeHtml(TR.charts.clip(story2.pinTitle(item), 90)) +
        "</strong>" + buttons + "</div>" +
        slideBodyHtml(item) +
        '<textarea class="si-note" placeholder="Commentary for this slide…">' +
        fmt.escapeHtml(item.note || "") + "</textarea></div>";
    }
    if (item.kind === "snapshot") {
      // pinned "as it looks" — the card's own HTML, re-shown verbatim (unless a
      // rebuild withheld any of its quotes, in which case the frozen payload
      // must not render — I20)
      var snapBody = qualPinStale(item)
        ? '<p class="si-ctx">' + fmt.escapeHtml(QUAL_STALE_NOTE) + "</p>"
        : (item.html || "");
      return '<div class="card story-item story-snapshot" data-i="' + i + '">' +
        '<div class="si-head"><span class="qcode">' + (i + 1) + ". " +
        fmt.escapeHtml((item.source || "PIN").toUpperCase()) + "</span><strong>" +
        fmt.escapeHtml(TR.charts.clip(item.title || "Pinned card", 90)) + "</strong>" +
        (item.context ? '<span class="si-ctx">' + fmt.escapeHtml(item.context) + "</span>" : "") +
        buttons + "</div>" +
        '<div class="snap-body">' + snapBody + "</div>" +
        '<textarea class="si-note" placeholder="Commentary for this slide…">' +
        fmt.escapeHtml(item.note || "") + "</textarea></div>";
    }
    if (item.kind === "heatmap" || item.kind === "composite") {
      var matrix = item.kind === "heatmap" ? heatmapMatrix(item) : compositeMatrix(item);
      var title = item.kind === "heatmap" ? "Index heatmap"
        : "Composite — " + item.category;
      return '<div class="card story-item" data-i="' + i + '">' +
        '<div class="si-head"><span class="qcode">' + (i + 1) + ". " +
        (item.kind === "heatmap" ? "HEAT" : "COMP") + "</span><strong>" +
        fmt.escapeHtml(title) + "</strong>" +
        '<span class="si-ctx">' + fmt.escapeHtml(contextLine(item)) + "</span>" +
        buttons + "</div>" +
        (matrix ? '<div class="si-table">' + matrixTable(matrix) + "</div>" : "") +
        '<textarea class="si-note" placeholder="Commentary for this slide…">' +
        fmt.escapeHtml(item.note || "") + "</textarea></div>";
    }
    var model = modelFor(item);
    if (!model) return "";
    var flags = item.flags || { chart: false, table: true, insight: true };
    // D2: a stored insight title leads; a title-less (older) pin is unchanged
    return '<div class="card story-item" data-i="' + i + '">' +
      '<div class="si-head"><span class="qcode">' + (i + 1) + ". " + model.code +
      "</span> <strong>" + fmt.escapeHtml(TR.charts.clip(item.title || model.title, 90)) + "</strong>" +
      '<span class="si-ctx">' + fmt.escapeHtml(contextLine(item, model)) + "</span>" +
      buttons + "</div>" +
      (flags.chart ? '<div class="chart si-chart">' +
        TR.render.chartBy(item.chartType || "bar", model, item.chartCols || [0]) +
        "</div>" : "") +
      (flags.table ? '<div class="si-table">' + TR.render.tableHtml(model,
        { heatmap: true, showDeltas: TR.d2.tracking().enabled,
          intervals: !!item.intervals, showCounts: !!item.counts }) + "</div>" : "") +
      quoteBlockHtml(item) +
      (flags.insight ? '<textarea class="si-note" placeholder="Commentary for this slide…">' +
        fmt.escapeHtml(item.note || TR.insights.get(item.q, item.banner) || "") +
        "</textarea>" : "") + "</div>";
  }

  story2._itemHtml = itemHtml;   // exposed for the node gate

  function matrixTable(matrix) {
    return '<table class="ct"><thead><tr>' + matrix.head.map(function (h, i) {
      return '<th class="' + (i === 0 ? "lab" : "") + '">' + fmt.escapeHtml(h) + "</th>";
    }).join("") + "</tr></thead><tbody>" + matrix.body.map(function (row) {
      return "<tr>" + row.cells.map(function (cell, i) {
        return "<td" + (i === 0 ? ' class="lab"' : "") + ">" +
          fmt.escapeHtml(String(cell)) + "</td>";
      }).join("") + "</tr>";
    }).join("") + "</tbody></table>";
  }

  /* ---------------- actions ---------------- */

  function wire(host) {
    host.addEventListener("click", function (e) {
      var sact = e.target.closest("[data-sact]");
      if (sact) { topAction(sact.getAttribute("data-sact")); return; }
      var card = e.target.closest(".story-item");
      if (!card) return;
      var i = parseInt(card.getAttribute("data-i"), 10);
      if (e.target.closest("[data-move]")) {
        var dir = parseInt(e.target.closest("[data-move]").getAttribute("data-move"), 10);
        var list = load(), j = i + dir;
        if (j >= 0 && j < list.length) {
          var tmp = list[i]; list[i] = list[j]; list[j] = tmp;
          touch();
          story2.renderTab(document.getElementById("tabhost"));
        }
      } else if (e.target.closest("[data-remove]")) {
        load().splice(i, 1);
        touch();
        story2.renderTab(document.getElementById("tabhost"));
      } else if (e.target.closest("[data-png]")) {
        var item = load()[i];
        var model = modelFor(item);
        var flags = item.flags || { chart: false, table: true };
        TR.exporter.downloadPng(model, contextLine(item, model), {
          chartSvg: flags.chart
            ? TR.render.chartBy(item.chartType || "bar", model, item.chartCols || [0])
            : null,
          includeTable: flags.table !== false,
          title: item.title || null   // D2: PNG title = pin title
        });
      } else if (e.target.closest("[data-open]")) {
        var openItem = load()[i];
        TR.d2.state.filters = JSON.parse(JSON.stringify(openItem.filters || []));
        TR.filterBar.render();
        TR.shell.goQuestion(openItem.q, openItem.banner);
      }
    });
    host.addEventListener("input", function (e) {
      if (e.target.classList.contains("si-note")) {
        var card = e.target.closest(".story-item");
        load()[parseInt(card.getAttribute("data-i"), 10)].note = e.target.value;
        touch();
      }
    });
    var importer = host.querySelector("#story-import");
    if (importer) {
      importer.addEventListener("change", function () {
        if (!importer.files[0]) return;
        TR.insights.importJson(importer.files[0], function (ok) {
          TR.shell.toast(ok ? "Insights + story imported" : "Import failed");
          story2.renderTab(document.getElementById("tabhost"));
        });
      });
    }
  }

  /** WP3 cover: the same content as the HTML cover — project head, the
   *  authored exec summary (report.sectionText) and the leading findings as
   *  pin-title insight lines (story2.pinTitle, the reader chain). Falls back
   *  to the plain title slide when the exporter has no cover (node stubs). */
  function coverSlideFor(list) {
    if (!TR.exporter.coverSlide) return TR.exporter.titleSlide(list.length);
    // Deliberately 5, and NOT html_report_v2_cover_findings: the HTML cover
    // scrolls, this is one fixed slide whose rows already shrink to fit, so a
    // long list would compress into something unreadable. The config setting
    // governs the HTML cover only, and says so in the template and the docs.
    var findings = list.filter(function (it) { return it.kind !== "divider"; })
      .slice(0, 5).map(function (it) { return story2.pinTitle(it); });
    var exec = (TR.report && TR.report.sectionText)
      ? String(TR.report.sectionText("exec") || "").trim() : "";
    return TR.exporter.coverSlide({ exec: exec, findings: findings });
  }

  // Data-table pin kinds — the deck's "Detail" tail when no appendix flags
  // are in play (WP5).
  function isDetailItem(item) {
    return item.kind === "heatmap" || item.kind === "composite";
  }

  function slidesFor(list) {
    // WP5 deck tail: pins flagged appendix:true go behind an "Appendix"
    // divider. When the analyst marked nothing, matrix/table pins (heatmap /
    // composite) group behind a "Detail" divider — but only on a MIXED deck;
    // an all-tables deck has nothing to separate and keeps its order.
    var main = list, tail = [], tailTitle = "";
    if (list.some(function (it) { return !!it.appendix; })) {
      tailTitle = "Appendix";
      main = list.filter(function (it) { return !it.appendix; });
      tail = list.filter(function (it) { return !!it.appendix; });
    } else if (list.some(isDetailItem) && list.some(function (it) {
      return it.kind !== "divider" && !isDetailItem(it);
    })) {
      tailTitle = "Detail";
      main = list.filter(function (it) { return !isDetailItem(it); });
      tail = list.filter(isDetailItem);
    }
    var slides = [coverSlideFor(list)];
    var divN = 0;   // WP3: dividers numbered in deck order
    // The evidence gets its own slide rather than a strip under the exhibit:
    // three verbatims squeezed below a crosstab are unreadable, and the deck
    // already has quote typography for exactly this (exporter.quoteSlide).
    // A band-split open-end (NPS Detractor/Passive/Promoter) gets ONE SLIDE PER
    // BAND: that is how the story is told, and it keeps each band clear of the
    // slide's 4-quote cap, which two priority marks per band sheet would breach.
    var pushQuoteSlide = function (item, apx, title, meta) {
      var quotes = quotesFor(item);
      if (!quotes.length || !TR.exporter.quoteSlide) return;
      var groups = (TR.qual && TR.qual.groupQuotesByBand)
        ? TR.qual.groupQuotesByBand(quotes) : [{ band: "", quotes: quotes }];
      groups.forEach(function (g) {
        slides.push(TR.exporter.quoteSlide({
          title: g.band ? title + " — " + g.band : title,
          kicker: apx ? "Appendix" : "In their words",
          meta: meta || "", quotes: g.quotes, moreN: 0, note: "" }));
      });
    };
    var emit = function (item, apx) {
      if (item.kind === "divider") {
        slides.push(TR.exporter.dividerSlide(item.title, item.note || "",
          { num: ++divN }));
        return;
      }
      if (item.kind === "exhibit") {
        var exSlide = TR.exhibit.slide(item);
        if (exSlide) slides.push(exSlide);
        if (quotesFor(item).length) {
          var exModels = TR.exhibit.models(item);
          pushQuoteSlide(item, apx, TR.exhibit.titleFor(item, exModels),
            TR.exhibit.contextLine(item, exModels));
        }
        return;
      }
      if (item.kind === "slide") {
        // The authored picture goes in as a real picture. A slide whose image
        // cannot be decoded (or a text-only slide) still gets a slide, carrying
        // its words — the deck never silently loses a pinned exhibit.
        var sl = slideOf(item);
        var pic = sl && TR.exporter.slidePicture ? TR.exporter.slidePicture(sl) : null;
        if (pic) {
          slides.push(TR.exporter.imageSlide(pic));
        } else {
          slides.push(TR.exporter.dividerSlide(story2.pinTitle(item),
            (sl ? (sl.text || "") : SLIDE_GONE_NOTE) || item.note || ""));
        }
        return;
      }
      if (item.kind === "heatmap") {
        slides.push(TR.exporter.matrixSlide("Index heatmap",
          contextLine(item) + (item.note ? " · " + item.note : ""),
          heatmapMatrix(item), { kicker: apx ? "Appendix" : "Dashboard" }));
        return;
      }
      if (item.kind === "composite") {
        // a stale pin (category no longer resolves -> null matrix) must not
        // crash the whole deck — a visible placeholder slide, like the
        // stale-question-pin guard in present mode
        var cm = compositeMatrix(item);
        slides.push(cm
          ? TR.exporter.matrixSlide("Composite — " + item.category,
              contextLine(item) + (item.note ? " · " + item.note : ""), cm,
              { kicker: apx ? "Appendix" : "Composite" })
          : TR.exporter.dividerSlide("Composite — " + item.category,
              "This pin no longer resolves in this report."));
        return;
      }
      if (item.kind === "snapshot") {
        // A stale qualitative pin exports a placeholder, never its frozen
        // (since-withheld) quotes — mirror of the stale-composite rule (I20).
        if (qualPinStale(item)) {
          slides.push(TR.exporter.dividerSlide(item.title || "Pinned card",
            QUAL_STALE_NOTE));
          return;
        }
        // WP4: a structured quotes payload renders in quote typography; old
        // pins (no payload) keep the one-column table fallback unchanged
        if (item.quotes && item.quotes.length && TR.exporter.quoteSlide) {
          slides.push(TR.exporter.quoteSlide({
            title: item.title || "Pinned card",
            kicker: apx ? "Appendix" : (item.source || "Verbatims"),
            meta: item.context || "",
            quotes: item.quotes, moreN: item.moreN || 0,
            note: item.note || "" }));
          return;
        }
        slides.push(TR.exporter.matrixSlide(item.title || "Pinned card",
          (item.context || "") + (item.note ? " · " + item.note : ""),
          snapshotMatrix(item),
          { kicker: apx ? "Appendix" : (item.source || "Pinned card") }));
        return;
      }
      var model = modelFor(item);
      if (model) {
        var flags = item.flags || { chart: false, table: true, insight: true };
        slides.push(TR.exporter.slideForModel(model,
          item.note || TR.insights.get(item.q, item.banner) || "",
          { chart: flags.chart, table: flags.table, insight: flags.insight,
            chartType: item.chartType || "bar",
            chartCols: item.chartCols || [0],
            intervals: !!item.intervals,
            title: item.title || null }));   // D2: slide title = pin title
        pushQuoteSlide(item, apx, item.title || model.title,
          contextLine(item, model));
      }
    };
    main.forEach(function (item) { emit(item, false); });
    if (tail.length) {
      slides.push(TR.exporter.dividerSlide(tailTitle,
        "Supporting data tables", { num: ++divN }));
      tail.forEach(function (item) { emit(item, tailTitle === "Appendix"); });
    }
    // WP1: resolve footer page-number tokens now the deck length is known
    // (the node gates stub TR.exporter without paginate — tokens never appear
    // there because the stubs emit no chrome)
    return TR.exporter.paginate ? TR.exporter.paginate(slides) : slides;
  }
  story2._slidesFor = slidesFor;   // exposed for the node gate

  /** One story item -> a card SVG for the pixel-perfect image deck. Mirrors the
   *  on-screen render of each item kind; null when the item has nothing to show
   *  (e.g. an exhibit with no resolvable questions). */
  function itemCardSvg(item) {
    if (item.kind === "slide") {
      // Not an SVG at all: the image deck takes this one through untouched, so
      // the authored picture is never rasterised twice. imageCards labels it.
      var sl = slideOf(item);
      var pic = sl && TR.exporter.slidePicture ? TR.exporter.slidePicture(sl) : null;
      if (pic) return { png: pic };
      return TR.exporter.cardSvgRaw(story2.pinTitle(item),
        (sl ? (sl.text || "") : SLIDE_GONE_NOTE) || "", null, null);
    }
    if (item.kind === "divider") {
      return TR.exporter.cardSvgRaw(item.title || "Section", item.note || "", null, null);
    }
    if (item.kind === "heatmap") {
      return TR.exporter.cardSvgRaw("Index heatmap",
        contextLine(item) + (item.note ? " · " + item.note : ""), null, heatmapMatrix(item));
    }
    if (item.kind === "composite") {
      return TR.exporter.cardSvgRaw("Composite — " + item.category,
        contextLine(item) + (item.note ? " · " + item.note : ""), null, compositeMatrix(item));
    }
    if (item.kind === "snapshot") {
      if (qualPinStale(item)) {
        return TR.exporter.cardSvgRaw(item.title || "Pinned card",
          QUAL_STALE_NOTE, null, null);
      }
      return TR.exporter.cardSvgRaw(item.title || "Pinned card",
        (item.context || "") + (item.note ? " · " + item.note : ""), null, snapshotMatrix(item));
    }
    if (item.kind === "exhibit") {
      var models = TR.exhibit.models(item);
      if (!models.length) return null;
      var ef = item.flags || {};
      var chartSvg = null;
      if (TR.exhibit.isComposite(item, models)) {
        // composite -> one scorecard (replaces both dist and trend)
        if (ef.dist || ef.trend) chartSvg = TR.exhibit.scorecardSvg(item, models, 660);
      } else if (ef.trend !== false) {
        chartSvg = TR.render.trendChart(TR.exhibit.trendModel(item, models));
      } else if (ef.dist) chartSvg = TR.render.chartBy(item.distType === "line"
        ? "column" : (item.distType || "column"),
        TR.exhibit.distModel(item, models), item.chartCols || [0]);
      return TR.exporter.cardSvgRaw(TR.exhibit.titleFor(item, models),
        TR.exhibit.contextLine(item, models), chartSvg,
        ef.table ? TR.exhibit.matrix(item, models) : null);
    }
    var model = modelFor(item);
    if (!model) return null;
    var flags = item.flags || { chart: false, table: true, insight: true };
    var chart = flags.chart
      ? TR.render.chartBy(item.chartType || "bar", model, item.chartCols || [0]) : null;
    return TR.exporter.cardSvg(model,
      item.note || TR.insights.get(item.q, item.banner) || "",
      { chartSvg: chart, includeTable: flags.table !== false,
        title: item.title || null });   // D2: card title = pin title
  }

  /** The image deck's card list: one card per item, plus a companion quote card
   *  wherever a pin carries priority comments — so the image deck shows the same
   *  evidence as the editable deck rather than silently dropping it. */
  function imageCards(list) {
    var cards = [];
    list.forEach(function (item) {
      cards.push(itemCardSvg(item));
      var quotes = quotesFor(item);
      if (quotes.length && TR.exporter.quoteCardSvg) {
        // an exhibit has no single question model — its own title chain answers
        var model = item.kind === "question" ? modelFor(item) : null;
        var head = item.title || (model ? model.title : story2.pinTitle(item));
        var meta = model ? contextLine(item, model) : (filterNote(item) || "");
        // one card per band, mirroring the editable deck's one slide per band
        var groups = (TR.qual && TR.qual.groupQuotesByBand)
          ? TR.qual.groupQuotesByBand(quotes) : [{ band: "", quotes: quotes }];
        groups.forEach(function (g) {
          cards.push(TR.exporter.quoteCardSvg("In their words — " + head +
            (g.band ? " · " + g.band : ""), meta, g.quotes));
        });
      }
    });
    return cards;
  }
  story2._imageCards = imageCards;   // exposed for the node gate
  story2._topAction = function (a) { return topAction(a); };  // node gate: Clear guard

  function topAction(action) {
    if (action === "clear") {
      // Clear wipes an afternoon's pinning in one click, writes the empty state
      // straight to storage, and sets the ownership marker — so a reload will
      // NOT bring the pins back from the island seed. The only recovery is an
      // earlier Export insights JSON or a saved copy. Ask first, and say what
      // survives (the insight notes live in their own store and are untouched).
      // Same guarded-confirm shape the qual hub delete uses.
      var n = load().length;
      if (n && typeof confirm !== "undefined" &&
          !confirm("Clear the whole story? " + n + " pinned item" +
                   (n === 1 ? "" : "s") + " will be removed and this cannot be " +
                   "undone. Your Insight notes are not affected.")) return;
      items = [];
      touch();
      story2.renderTab(document.getElementById("tabhost"));
    }
    if (action === "divider") story2.addDivider();
    if (action === "exhibit") story2.addExhibit();
    if (action === "composite") story2.addComposite();
    if (action === "export") TR.insights.exportJson();
    if (action === "pptx") {
      TR.exporter.downloadDeck(slidesFor(load()),
        fmt.slug(TR.AGG.project.name) + "_story.pptx");
    }
    if (action === "pptx-img") {
      TR.exporter.downloadImageDeck(imageCards(load()),
        fmt.slug(TR.AGG.project.name) + "_story_images.pptx");
    }
    if (action === "present") startPresent();
  }

  /* ---------------- present mode ---------------- */

  function startPresent() {
    if (!load().length) return;
    presentAt = 0;
    renderPresent();
    document.addEventListener("keydown", presentKeys);
  }

  function presentKeys(e) {
    if (e.key === "Escape") { closePresent(); return; }
    if (e.key === "ArrowRight" || e.key === " ") {
      presentAt = Math.min(presentAt + 1, load().length - 1);
      renderPresent();
    }
    if (e.key === "ArrowLeft") {
      presentAt = Math.max(presentAt - 1, 0);
      renderPresent();
    }
  }

  function closePresent() {
    document.removeEventListener("keydown", presentKeys);
    var overlay = document.getElementById("present-overlay");
    overlay.hidden = true;
    overlay.innerHTML = "";
  }

  function renderPresent() {
    var overlay = document.getElementById("present-overlay");
    var item = load()[presentAt];
    if (!item) { closePresent(); return; }
    var head = '<div class="pr-head"><span>' + (presentAt + 1) + " / " + load().length +
      " · " + fmt.escapeHtml(TR.AGG.project.name) + "</span>" +
      '<button id="pr-close" aria-label="Exit presentation">✕ esc</button></div>';
    var body;
    if (item.kind === "divider") {
      body = '<div class="pr-divider"><h1>' + fmt.escapeHtml(item.title) + "</h1>" +
        (item.note ? '<p class="pr-ctx">' + fmt.escapeHtml(item.note) + "</p>" : "") + "</div>";
    } else if (item.kind === "exhibit") {
      var exModels = TR.exhibit.models(item);
      body = "<h1>" + fmt.escapeHtml(TR.exhibit.titleFor(item, exModels)) + "</h1>" +
        '<p class="pr-ctx">' +
        fmt.escapeHtml(TR.exhibit.contextLine(item, exModels)) + "</p>" +
        (item.note ? '<div class="pr-note">' + fmt.escapeHtml(item.note) + "</div>" : "") +
        '<div class="pr-table pr-chart">' + TR.exhibit.panelsHtml(item) + "</div>" +
        quoteBlockHtml(item);
    } else if (item.kind === "slide") {
      body = "<h1>" + fmt.escapeHtml(story2.pinTitle(item)) + "</h1>" +
        (item.note ? '<div class="pr-note">' + fmt.escapeHtml(item.note) + "</div>" : "") +
        '<div class="pr-table">' + slideBodyHtml(item) + "</div>";
    } else if (item.kind === "snapshot") {
      var presentBody = qualPinStale(item)
        ? '<p class="pr-ctx">' + fmt.escapeHtml(QUAL_STALE_NOTE) + "</p>"
        : (item.html || "");
      body = "<h1>" + fmt.escapeHtml(item.title || "Pinned card") + "</h1>" +
        (item.context ? '<p class="pr-ctx">' + fmt.escapeHtml(item.context) + "</p>" : "") +
        (item.note ? '<div class="pr-note">' + fmt.escapeHtml(item.note) + "</div>" : "") +
        '<div class="pr-table snap-body">' + presentBody + "</div>";
    } else if (item.kind === "heatmap" || item.kind === "composite") {
      var matrix = item.kind === "heatmap" ? heatmapMatrix(item) : compositeMatrix(item);
      // a stale composite pin (null matrix) must not crash present mode —
      // same guard as the stale question pin below
      body = matrix
        ? "<h1>" + (item.kind === "heatmap" ? "Index heatmap"
            : "Composite — " + fmt.escapeHtml(item.category)) + "</h1>" +
          '<p class="pr-ctx">' + fmt.escapeHtml(contextLine(item)) + "</p>" +
          (item.note ? '<div class="pr-note">' + fmt.escapeHtml(item.note) + "</div>" : "") +
          '<div class="pr-table">' + matrixTable(matrix) + "</div>"
        : '<div class="pr-divider"><h1>Unavailable exhibit</h1>' +
          '<p class="pr-ctx">This pin no longer resolves in this report.</p></div>';
    } else if (!modelFor(item)) {
      // a stale pin (question no longer in this report) must not crash
      // present mode — itemHtml and the PPTX path already skip it
      body = '<div class="pr-divider"><h1>Unavailable exhibit</h1>' +
        '<p class="pr-ctx">This pin references a question that is not in ' +
        "this report.</p></div>";
    } else {
      var model = modelFor(item);
      var flags = item.flags || { table: true, insight: true };
      body = "<h1>" + fmt.escapeHtml(model.code + " — " + (item.title || model.title)) + "</h1>" +
        '<p class="pr-ctx">' + fmt.escapeHtml(contextLine(item, model)) + "</p>" +
        ((flags.insight !== false && (item.note || TR.insights.get(item.q, item.banner))) ?
          '<div class="pr-note">' +
          fmt.escapeHtml(item.note || TR.insights.get(item.q, item.banner)) + "</div>" : "") +
        (flags.chart ? '<div class="pr-table pr-chart">' +
          TR.render.chartBy(item.chartType || "bar", model, item.chartCols || [0]) +
          "</div>" : "") +
        (flags.table !== false ? '<div class="pr-table">' + TR.render.tableHtml(model,
          { heatmap: true, showDeltas: TR.d2.tracking().enabled,
            intervals: !!item.intervals, showCounts: !!item.counts }) + "</div>" : "") +
        quoteBlockHtml(item);
    }
    overlay.hidden = false;
    overlay.innerHTML = '<div class="present">' + head + body +
      '<div class="pr-foot">← → to navigate · Esc to exit</div></div>';
    overlay.querySelector("#pr-close").addEventListener("click", closePresent);
  }

})(typeof window !== "undefined" ? window : globalThis);
