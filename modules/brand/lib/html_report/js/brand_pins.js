// ==============================================================================
// BRAND REPORT - TURAS PINS WRAPPER
// ==============================================================================
// Thin wrapper around the shared TurasPins library.
// Handles content capture for brand-specific sections and delegates
// to TurasPins.add() for pinning.
// ==============================================================================

(function() {
  "use strict";

  // --- Is element currently visible? ---
  function isVisible(el) {
    return !!el && el.offsetParent !== null;
  }

  // --- Strip interactive controls from a captured HTML fragment ---
  // Pinned cards must read like a snapshot, not a live UI: sort buttons,
  // toolbars, info-callouts, hidden inputs, and stray onclick handlers
  // all get removed. Class list is intentionally brand-specific so the
  // generic shared TurasPins library stays unaware of brand DOM details.
  var INTERACTIVE_SELECTORS = [
    'button', 'input', 'select',
    '.ct-sort-indicator', '.row-exclude-btn',
    '.cb-info-callout', '.cb-controls-bar',
    '.fn-controls', '.ma-controls', '.controls-bar',
    '.fn-pin-dropdown-btn', '.fn-pin-dropdown',
    '.fn-rel-chart-controls',
    // The Chart brands control. Its NOTE (.br-cf-note) is deliberately not
    // stripped: it is the only thing that tells a reader why a captured
    // chart shows fewer brands than the table beside it.
    '.br-cf',
    '.br-pin-btn', '.br-png-btn', '.br-export-btn', '.br-insight-toggle',
    '.fn-png-btn', '.ma-png-btn', '.fn-export-btn', '.ma-export-btn',
    '.toggle-label', '.sig-level-switcher',
    '[onclick]', '[ondblclick]'
  ].join(',');

  // --- Significance markers, and why they are stripped rather than hidden ---
  // The toggle in each destination toolbar hides these with CSS, which is the
  // only thing that survives the MA and funnel panels re-rendering themselves
  // on every focal switch and base toggle. CSS is not enough for a capture:
  // TurasPins' inliner skips values it reads as defaults, and display:none is
  // one of them, so a marker hidden on screen would come back on a pinned
  // card or a PNG. That is the failure mode the project CLAUDE.md warns about
  // and Stage 4 avoided by leaving the funnel's triangle out of the markup.
  //
  // So every capture taken from a destination whose toggle is off has the
  // markers taken out of the captured HTML. One wrapper around
  // TurasPins.capturePortableHtml covers all of it, rather than an edit at
  // each of the fourteen capture sites across five panel files: the funnel,
  // MA, Mental Advantage, Category Buying and portfolio pin paths all go
  // through that one function.
  var SIG_MARKER_SELECTORS = [
    ".ma-sig",        // MA table z-test arrows
    ".ma-fv-sig",     // Mental Advantage focal view stars
    ".ma-adv-sig",    // the significance clause on a Mental Advantage tooltip
    ".ct-sig",        // funnel triangle, the engine's test on its own base
    ".fn-sig-avg",    // funnel arrows against the spread of brands
    ".fn-sig"         // funnel card arrows
  ].join(",");

  window.brStripSigMarkers = function(html) {
    if (!html) return html;
    var d = document.createElement("div");
    d.innerHTML = html;
    d.querySelectorAll(SIG_MARKER_SELECTORS).forEach(function(el) { el.remove(); });
    return d.innerHTML;
  };

  window.brStripInteractive = function(html) {
    if (!html) return html;
    var d = document.createElement('div');
    d.innerHTML = html;
    d.querySelectorAll(INTERACTIVE_SELECTORS).forEach(function(el) { el.remove(); });
    return d.innerHTML;
  };

  // --- Chart brands: the clause a captured chart carries ---
  // Returns "" unless a chart inside this root is showing fewer brands than
  // its table. The words come from the note element BrandChartFocus paints,
  // so the pin, the PNG and the page all say the same thing.
  window.brChartDeviationClause = function(root) {
    if (!root) return "";
    if (window.BrandChartFocus &&
        typeof window.BrandChartFocus.clauseFor === "function") {
      return window.BrandChartFocus.clauseFor(root);
    }
    return "";
  };

  // Append the clause to a pin or PNG title, but only when the capture
  // actually carries the chart. A table pinned on its own is not deviating
  // from anything and must not be labelled as though it were.
  window.brTitleWithChartDeviation = function(title, clause, includeChart) {
    if (!includeChart || !clause) return title;
    return title + " (" + clause + ")";
  };

  // --- Read the active "Base:" toggle label inside a captured root ---
  // Funnel, Brand Attitude, Brand Attributes and CEPs all expose a
  // `.sig-level-switcher` with a "Base:" prefix label and one
  // `.sig-btn-active` button. Returns the active button's text trimmed,
  // or "" if no Base toggle is present in this root.
  // Only considers VISIBLE switchers (offsetParent !== null) so hidden
  // sub-tabs (e.g. funnel's relationship sub-tab when the user is on
  // the main funnel sub-tab) don't leak the wrong base label.
  window.brReadBaseLabel = function(root) {
    if (!root) return "";
    var switchers = root.querySelectorAll(".sig-level-switcher");
    for (var i = 0; i < switchers.length; i++) {
      if (!isVisible(switchers[i])) continue;
      var lbl = switchers[i].querySelector(".sig-level-label");
      if (!lbl || !/Base\s*:/i.test(lbl.textContent || "")) continue;
      var active = switchers[i].querySelector(".sig-btn-active");
      if (active) return (active.textContent || "").trim();
    }
    return "";
  };

  // --- Extract capture payload from a given root element ---
  function captureFromRoot(root, sectionKey) {
    if (!root) return null;

    // The first heading in the root names the card, unless a pane inside the
    // root is hiding it. Stage 5 moved the funnel, MA and Category Buying
    // anchors onto a wrapper around the whole leaf, so the capture root now
    // contains the panel's own sub-tabs and their headings. On the IPK
    // fixture the first heading inside [data-section="funnel-dss"] is
    // "Summary", from the funnel panel's Summary sub-tab, which no nav routes
    // to and which carries the hidden attribute (impact map section 4).
    // Pinning the Brand Funnel therefore produced a card named after a tab
    // the reader cannot open.
    //
    // Skipping every heading a reader cannot see at that instant is too
    // strong: a reader opens the pin picker with the Advanced drawer shut,
    // and then the drawer hides the root and its own heading together.
    // brHeadingHiddenWithin() draws the line at the root, and sectionsIn()
    // in brand_report.js calls the same function so the picker's label and
    // the card's title cannot drift apart.
    var hiddenWithin = window.brHeadingHiddenWithin ||
      function (el) { return !el || el.offsetParent === null; };
    var title = null;
    var heads = root.querySelectorAll(
      ".br-element-title, h2, h3, .pfo-section-title");
    for (var hi = 0; hi < heads.length; hi++) {
      if (!hiddenWithin(heads[hi], root)) { title = heads[hi]; break; }
    }
    // With no visible heading, name the card after the analysis rather than
    // after its anchor id. data-leaf-label is the reader-facing name the
    // Advanced accordion and the pin picker already show, and it sits on the
    // .br-subpanel that holds the anchor. Falling through to sectionKey
    // produced cards called "funnel-dss".
    var titleText = "";
    if (title) {
      titleText = title.textContent.trim();
    } else {
      var leaf = root.closest ? root.closest("[data-leaf-label]") : null;
      titleText = (leaf && leaf.getAttribute("data-leaf-label")) ||
                  (sectionKey || "");
    }

    // Pick the first *visible* SVG in the subtree, skip SVGs inside <button>
    // elements (toolbar download icons) AND SVGs inside [data-pin-as-table]
    // (decorative card icons in the summary panel; the body is the content).
    // Fallback: any non-button, non-decorative SVG even if not visible.
    function skipSvg(s) {
      return s.closest("button") || s.closest("[data-pin-as-table]");
    }
    var svg = null;
    var svgs = root.querySelectorAll("svg");
    for (var si = 0; si < svgs.length; si++) {
      if (isVisible(svgs[si]) && !skipSvg(svgs[si])) { svg = svgs[si]; break; }
    }
    if (!svg) {
      for (var si2 = 0; si2 < svgs.length; si2++) {
        if (!skipSvg(svgs[si2])) { svg = svgs[si2]; break; }
      }
    }

    var chartSvg = "";
    if (svg) {
      var clone = svg.cloneNode(true);
      var vb = svg.getAttribute("viewBox");
      if (vb) {
        var parts = vb.split(/\s+/);
        clone.setAttribute("width", parts[2]);
        clone.setAttribute("height", parts[3]);
      }
      chartSvg = clone.outerHTML;
    }

    // Pick first *visible* table matching known classes, then any visible table.
    var tableSelectors = [
      "table.br-table", "table.pfo-table", "table.fn-table",
      "table.ma-table", "table.ma-matrix", "table"
    ];
    var table = null;
    for (var ts = 0; ts < tableSelectors.length && !table; ts++) {
      var candidates = root.querySelectorAll(tableSelectors[ts]);
      for (var ti = 0; ti < candidates.length; ti++) {
        if (isVisible(candidates[ti])) { table = candidates[ti]; break; }
      }
    }
    if (!table) {
      var fallback = root.querySelector("table");
      if (fallback) table = fallback;
    }

    var tableHtml = "";
    if (table && typeof TurasPins !== "undefined" && TurasPins.capturePortableHtml) {
      tableHtml = TurasPins.capturePortableHtml(table);
    } else if (table) {
      tableHtml = table.outerHTML;
    }

    // Card-grid escape hatch: sections with no <table> can opt into pin
    // capture by marking their card container with data-pin-as-table.
    // Used by the Summary panel (KPI cards) and any future card-only views.
    if (!tableHtml) {
      var cardsEl = root.querySelector("[data-pin-as-table]");
      if (cardsEl && typeof TurasPins !== "undefined" && TurasPins.capturePortableHtml) {
        tableHtml = TurasPins.capturePortableHtml(cardsEl);
      } else if (cardsEl) {
        tableHtml = cardsEl.outerHTML;
      }
    }

    // Insight textarea selectors:
    // - .br-insight-editor      generic section toolbar (page_builder)
    // - .fn-insight-textarea    funnel + cat-buying panels
    // - .ma-insight-box-text    MA + WoM panels
    // - .brsum-insight-editor   summary panel analyst commentary
    var editor = root.querySelector(".br-insight-editor")
             || root.querySelector(".fn-insight-textarea")
             || root.querySelector(".ma-insight-box-text")
             || root.querySelector(".brsum-insight-editor");
    var insightText = editor ? editor.value.trim() : "";

    // For sections whose chart is HTML (not SVG), capture the chart area HTML
    // so it can be rendered alongside the table in PNG export.
    // Look first for the funnel's chart marker, then for the generic
    // [data-pin-as-chart] hook used by Demographics et al. for HTML/CSS bar
    // charts.
    var chartHtml = "";
    if (!chartSvg) {
      var htmlChartEl = root.querySelector("[data-fn-rel-chart-area]")
                     || root.querySelector("[data-pin-as-chart]");
      if (htmlChartEl && typeof TurasPins !== "undefined" && TurasPins.capturePortableHtml) {
        chartHtml = TurasPins.capturePortableHtml(htmlChartEl);
      } else if (htmlChartEl) {
        chartHtml = htmlChartEl.outerHTML;
      }
    }

    // Final pass: strip interactive controls from the captured fragments
    // so pinned cards never carry sort buttons, toolbars, or live toggles.
    tableHtml = window.brStripInteractive(tableHtml);
    chartHtml = window.brStripInteractive(chartHtml);

    // Active "Base:" toggle label, read from the LIVE root before
    // controls are stripped from the captured HTML. Stored both as
    // `subtitle` (rendered in the pin card) and `baseText` (rendered
    // by the PNG/PPT exporter as the meta line under the title).
    var baseLabel = window.brReadBaseLabel(root);
    var subtitle  = baseLabel ? "Base: " + baseLabel : "";

    // Chart brands: if a chart in this root is showing fewer brands than its
    // table, the clause travels with the capture. It is kept as its own
    // field rather than folded into the title here, because whether it
    // belongs on the card depends on whether the caller pins the chart.
    var chartDeviation = window.brChartDeviationClause(root);

    return {
      sectionKey: sectionKey || (root.id || ""),
      title: titleText,
      subtitle: subtitle,
      baseText: baseLabel,
      chartSvg: chartSvg,
      chartHtml: chartHtml,
      tableHtml: tableHtml,
      insightText: insightText,
      chartDeviation: chartDeviation
    };
  }

  // --- Content capture (by section_id string) ---
  function brCaptureContent(sectionId) {
    var section = document.getElementById("section-" + sectionId);
    // Portfolio subtabs use pf-subtab-<id> wrappers (e.g. pf-subtab-overview).
    // Check this BEFORE the generic [data-section] query, because pin buttons
    // also carry data-section and would otherwise match first.
    if (!section && /^pf-/.test(sectionId)) {
      var subId = sectionId.replace(/^pf-/, "pf-subtab-");
      section = document.getElementById(subId);
    }
    if (!section) {
      // Find a container (not a button) that declares data-section
      var candidates = document.querySelectorAll('[data-section="' + sectionId + '"]');
      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].tagName !== "BUTTON") { section = candidates[i]; break; }
      }
    }
    if (!section) return null;
    return captureFromRoot(section, sectionId);
  }

  // --- Toggle pin (show checkbox popover) ---
  window.brTogglePin = function(sectionId) {
    if (typeof TurasPins === "undefined") return;

    var btn = document.querySelector('.br-pin-btn[data-section="' + sectionId + '"]');
    if (!btn) return;

    var section = document.getElementById("section-" + sectionId);
    if (!section && /^pf-/.test(sectionId)) {
      section = document.getElementById(sectionId.replace(/^pf-/, "pf-subtab-"));
    }
    if (!section) {
      var pgCandidates = document.querySelectorAll('[data-section="' + sectionId + '"]');
      for (var pgi = 0; pgi < pgCandidates.length; pgi++) {
        if (pgCandidates[pgi].tagName !== "BUTTON") { section = pgCandidates[pgi]; break; }
      }
    }
    if (!section) return;

    // hasChart: either (a) any SVG that ISN'T a toolbar icon (inside <button>)
    // or a decorative card icon (inside [data-pin-as-table]), or (b) an
    // [data-pin-as-chart] hook for HTML/CSS bar charts (Demographics, etc.).
    // Matches the captureFromRoot skip-list so the popover offers the same
    // options the actual pin will materialise.
    var allSvgs = section.querySelectorAll("svg");
    var hasChart = false;
    for (var ci = 0; ci < allSvgs.length; ci++) {
      var s = allSvgs[ci];
      if (!s.closest("button") && !s.closest("[data-pin-as-table]")) {
        hasChart = true; break;
      }
    }
    if (!hasChart && section.querySelector("[data-pin-as-chart]")) {
      hasChart = true;
    }
    // Match captureFromRoot's selector list so smart-skip sees the same tables
    // the actual capture will find (pfo-table, fn-table, ma-table, plain table,
    // and any [data-pin-as-table] card-grid escape hatch used by Summary).
    var hasTable = !!(
      section.querySelector("table.br-table")  ||
      section.querySelector("table.pfo-table") ||
      section.querySelector("table.fn-table")  ||
      section.querySelector("table.ma-table")  ||
      section.querySelector("table.ma-matrix") ||
      section.querySelector("table") ||
      section.querySelector("[data-pin-as-table]")
    );
    var hasInsight = false;
    var editor = section.querySelector(".br-insight-editor");
    if (editor && editor.value.trim()) hasInsight = true;

    // Smart skip: if only one content type available, pin directly (no dialog)
    if (hasChart && !hasTable)  { brExecutePin(sectionId, { chart: true,  table: false, insight: hasInsight }); return; }
    if (!hasChart && hasTable)  { brExecutePin(sectionId, { chart: false, table: true,  insight: hasInsight }); return; }
    if (!hasChart && !hasTable) { brExecutePin(sectionId, { chart: false, table: false, insight: hasInsight }); return; }

    var checkboxes = [
      { key: "chart",   label: "Chart",   available: true, checked: true },
      { key: "table",   label: "Table",   available: true, checked: true },
      { key: "insight", label: "Insight", available: true, checked: hasInsight }
    ];

    var anchor = btn.closest(".br-section-toolbar") || btn.parentElement;
    TurasPins.showCheckboxPopover(btn, checkboxes, function(flags) {
      brExecutePin(sectionId, flags);
    }, anchor);
  };

  // Portfolio subtabs (footprint/constellation/clutter) lack an H3; map the
  // section id to the user-facing subtab label so pins and PNG exports show a
  // meaningful header instead of "pf-footprint".
  function applyPortfolioTitleFallback(content, sectionId) {
    if (!/^pf-/.test(sectionId)) return;
    if (content.title && content.title !== sectionId) return;
    var pfLabels = {
      "pf-overview":      "Portfolio Overview",
      "pf-footprint":     "Portfolio Footprint",
      "pf-constellation": "Competitive Set",
      "pf-clutter":       "Category Context",
      "pf-extension":     "Portfolio Extension"
    };
    if (pfLabels[sectionId]) content.title = pfLabels[sectionId];
  }

  function brExecutePin(sectionId, flags) {
    var content = brCaptureContent(sectionId);
    if (!content) return;
    applyPortfolioTitleFallback(content, sectionId);

    content.pinFlags = {
      chart:   !!flags.chart,
      table:   !!flags.table,
      insight: !!flags.insight
    };
    content.pinMode = "custom";

    content.title = window.brTitleWithChartDeviation(
      content.title, content.chartDeviation, !!flags.chart);

    if (!flags.chart)   content.chartSvg = "";
    if (!flags.table)   content.tableHtml = "";
    if (!flags.insight) content.insightText = "";

    TurasPins.add(content);

    // Flash pin button
    var btn = document.querySelector('.br-pin-btn[data-section="' + sectionId + '"]');
    if (btn) {
      btn.classList.add("pin-flash");
      setTimeout(function() { btn.classList.remove("pin-flash"); }, 600);
    }
  }

  // --- Pin and PNG with no button of their own ---
  // brTogglePin() needs a .br-pin-btn on the page to hang its popover from,
  // and Stage 5 removed most of those when the export controls moved to one
  // toolbar per destination. These are the button-free entry points: the
  // destination toolbar has already asked the reader what to capture, so
  // there is no second question to ask and everything in the chosen root is
  // captured.
  //
  // They take a root element rather than an anchor because five of the
  // Category Buying analyses have no anchor at all: the anchored ones pass
  // the element their anchor resolves to, so a pin taken through here is the
  // same capture the anchor has always produced.
  // The picker passes the name it showed the reader, and that name wins.
  // It was previously applied only when captureFromRoot() had found nothing,
  // which held while the leaf-label fallback did not exist. Once that
  // fallback landed, content.title was always filled, so the category suffix
  // the picker had put on a Category Buying entry ("Dirichlet Norms: Dry
  // Seasonings and Spices") was dropped and four categories produced four
  // cards all called "Dirichlet Norms". A reader who chose a name should get
  // that name on the card.
  function pinnableContent(root, key, title) {
    var content = captureFromRoot(root, key);
    if (!content) return null;
    if (title) content.title = title;
    return content;
  }

  window.brPinFrom = function(root, key, title) {
    if (typeof TurasPins === "undefined" || !root) return false;
    var content = pinnableContent(root, key, title);
    if (!content) return false;
    var hasChart = !!(content.chartSvg || content.chartHtml);
    var hasTable = !!content.tableHtml;
    if (!hasChart && !hasTable && !content.insightText) return false;
    content.pinFlags = { chart: hasChart, table: hasTable,
                         insight: !!content.insightText };
    content.pinMode = "custom";
    content.title = window.brTitleWithChartDeviation(
      content.title, content.chartDeviation, hasChart);
    TurasPins.add(content);
    return true;
  };

  window.brExportPngFrom = function(root, key, title) {
    if (typeof TurasPins === "undefined" || !root) return false;
    var content = pinnableContent(root, key, title);
    if (!content) return false;
    var hasChart = !!content.chartSvg;
    // An HTML chart is rendered by prepending it to the table fragment, the
    // same way brExportPngFromEl does it.
    var tableHtml = content.tableHtml || "";
    if (!hasChart && content.chartHtml) tableHtml = content.chartHtml + tableHtml;
    if (!hasChart && !tableHtml && !content.insightText) return false;
    TurasPins.exportContentAsPNG({
      title:       window.brTitleWithChartDeviation(
                     content.title, content.chartDeviation,
                     hasChart || !!content.chartHtml),
      subtitle:    content.subtitle || "",
      baseText:    content.baseText || "",
      chartSvg:    content.chartSvg || "",
      tableHtml:   tableHtml,
      insightText: content.insightText || "",
      pinFlags:    { chart: hasChart || !!content.chartHtml,
                     table: !!content.tableHtml,
                     insight: !!content.insightText },
      pinMode:     "custom"
    });
    return true;
  };

  // Kept as the anchor-shaped entry point, for a caller that has a name
  // rather than an element.
  window.brPinSection = function(sectionId) {
    var section = document.getElementById("section-" + sectionId);
    if (!section) {
      var c = document.querySelectorAll('[data-section="' + sectionId + '"]');
      for (var i = 0; i < c.length; i++) {
        if (c[i].tagName !== "BUTTON") { section = c[i]; break; }
      }
    }
    return window.brPinFrom(section, sectionId, null);
  };

  // --- Pin individual chart ---
  window.brPinChart = function(btnEl, chartTitle) {
    if (typeof TurasPins === "undefined") return;
    var wrapper = btnEl.closest(".br-chart-wrapper");
    if (!wrapper) return;
    var svg = wrapper.querySelector("svg");
    if (!svg) return;

    var clone = svg.cloneNode(true);
    var vb = svg.getAttribute("viewBox");
    if (vb) {
      var parts = vb.split(/\s+/);
      clone.setAttribute("width", parts[2]);
      clone.setAttribute("height", parts[3]);
    }

    TurasPins.add({
      sectionKey: "chart-" + Date.now(),
      title: chartTitle || "Chart",
      chartSvg: clone.outerHTML,
      tableHtml: "",
      insightText: "",
      pinMode: "chart_insight"
    });
  };

  // --- Export section content as PNG (no pin save) ---
  window.brExportPng = function(sectionId, btnEl) {
    if (typeof TurasPins === "undefined") return;
    var content = brCaptureContent(sectionId);
    if (!content) return;
    applyPortfolioTitleFallback(content, sectionId);

    var hasChart   = !!content.chartSvg;
    var hasTable   = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    function doExport(flags) {
      TurasPins.exportContentAsPNG({
        title:       window.brTitleWithChartDeviation(
                       content.title, content.chartDeviation, !!flags.chart),
        subtitle:    content.subtitle || "",
        baseText:    content.baseText || "",
        chartSvg:    flags.chart   ? content.chartSvg   : "",
        tableHtml:   flags.table   ? content.tableHtml  : "",
        insightText: flags.insight ? content.insightText : "",
        pinFlags:    { chart: !!flags.chart, table: !!flags.table, insight: !!flags.insight },
        pinMode:     "custom"
      });
    }

    // No button element or nothing to choose between → export directly
    if (!btnEl || (!hasChart && !hasTable)) {
      doExport({ chart: hasChart, table: hasTable, insight: hasInsight });
      return;
    }

    var checkboxes = [];
    if (hasChart) checkboxes.push({ key: "chart",   label: "Chart",   available: true, checked: true });
    if (hasTable) checkboxes.push({ key: "table",   label: "Table",   available: true, checked: true });
    checkboxes.push(              { key: "insight", label: "Insight", available: true, checked: hasInsight });

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      doExport(flags);
    }, null, { title: "EXPORT AS PNG", actionLabel: "Export" });
  };

  // --- Export the enclosing sub-view (or element-section) as PNG ---
  // Used by panels (funnel/MA) whose buttons sit inside controls bars. The
  // nearest MA subtab or funnel subtab is preferred over the outer element
  // section, so switching sub-tabs pins only what's currently visible.
  window.brExportPngFromEl = function(btnEl) {
    if (typeof TurasPins === "undefined" || !btnEl) return;
    var scope = btnEl.closest(".ma-section[data-ma-stim]")
             || btnEl.closest(".ma-subtab[data-ma-subtab]")
             || btnEl.closest(".ma-subtab")
             || btnEl.closest(".fn-subtab")
             || btnEl.closest(".br-element-section");
    if (!scope) return;
    var stim = scope.getAttribute("data-ma-stim")
            || scope.getAttribute("data-ma-subtab");
    var sid = scope.getAttribute("data-section")
           || stim
           || (scope.id || "").replace(/^section-/, "")
           || "export-" + Date.now();
    var content = captureFromRoot(scope, sid);
    if (!content) return;

    // Resolve category label from the enclosing category panel.
    var catPanel = btnEl.closest(".br-panel");
    var catLabel = "";
    if (catPanel) {
      var catBtn = document.querySelector('.br-tab-btn[onclick*="' + (catPanel.id || "").replace(/^panel-/, "") + '"]');
      if (catBtn) catLabel = (catBtn.textContent || "").trim();
    }

    // Friendlier titles for MA/funnel scopes that lack a heading element.
    if (stim) {
      var maTitle = (stim === "attributes")       ? "Brand Attributes"
                  : (stim === "ceps")             ? "Category Entry Points"
                  : (stim === "metrics")          ? "Headline Metrics"
                  : (stim === "advantage_focal")  ? "Mental Advantage, Focal Brand View"
                  : (stim === "advantage")        ? "Mental Advantage"
                  : stim;
      if (!content.title || content.title === sid) {
        content.title = maTitle + (catLabel ? ": " + catLabel : "");
      }
    } else if (scope.classList && scope.classList.contains("fn-subtab")) {
      if (!content.title || content.title === sid) {
        content.title = "Funnel" + (catLabel ? ": " + catLabel : "");
      }
    }

    var hasChart   = !!content.chartSvg || !!content.chartHtml;
    var hasTable   = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    function doExportFromEl(flags) {
      // When chart is HTML (not SVG), prepend it to tableHtml for html2canvas rendering
      var exportTableHtml = flags.table ? content.tableHtml : "";
      if (flags.chart && content.chartHtml && !content.chartSvg) {
        exportTableHtml = content.chartHtml + (exportTableHtml ? exportTableHtml : "");
      }
      TurasPins.exportContentAsPNG({
        title:       window.brTitleWithChartDeviation(
                       content.title, content.chartDeviation, !!flags.chart),
        subtitle:    content.subtitle || "",
        baseText:    content.baseText || "",
        chartSvg:    (flags.chart && content.chartSvg) ? content.chartSvg : "",
        tableHtml:   exportTableHtml,
        insightText: flags.insight ? content.insightText : "",
        pinFlags:    { chart: !!flags.chart, table: !!flags.table, insight: !!flags.insight },
        pinMode:     "custom"
      });
    }

    if (!hasChart && !hasTable) {
      doExportFromEl({ chart: false, table: false, insight: hasInsight });
      return;
    }

    var checkboxes = [];
    if (hasChart) checkboxes.push({ key: "chart",   label: "Chart",   available: true, checked: true });
    if (hasTable) checkboxes.push({ key: "table",   label: "Table",   available: true, checked: true });
    checkboxes.push(              { key: "insight", label: "Insight", available: true, checked: hasInsight });

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      doExportFromEl(flags);
    }, null, { title: "EXPORT AS PNG", actionLabel: "Export" });
  };

  // --- Export all pinned as PNG ---
  window.brExportAllPinned = function() {
    if (typeof TurasPins === "undefined") return;
    if (typeof TurasPins.exportAll === "function") {
      TurasPins.exportAll();
    } else if (typeof TurasPins.exportAllPng === "function") {
      TurasPins.exportAllPng();
    }
  };

  // --- Add section divider ---
  window.brAddSection = function(title) {
    if (typeof TurasPins !== "undefined" && TurasPins.addSection) {
      TurasPins.addSection(title);
    }
  };

  // --- Pin state store ---
  // Lightweight key-value store so portfolio/overview JS can record UI state
  // (active subtab, focal brand, centred brand) that future pin-restore hooks
  // can read via brGetPinState().
  var _brPinState = {};

  window.brSetPinState = function(key, value) {
    _brPinState[key] = value;
  };

  window.brGetPinState = function(key) {
    return _brPinState[key];
  };

  // --- Init TurasPins ---
  // Wrap the shared capture helper once, so no capture site has to know
  // about the significance toggle. The wrapper is idempotent: a second call
  // finds the flag and leaves the chain alone.
  function wrapCaptureForSigMode() {
    if (typeof TurasPins === "undefined") return;
    if (typeof TurasPins.capturePortableHtml !== "function") return;
    if (TurasPins.capturePortableHtml.__brSigWrapped) return;
    var inner = TurasPins.capturePortableHtml;
    var wrapped = function(el) {
      var html = inner.apply(this, arguments);
      var sigOn = (typeof window.brSigOnFor === "function")
        ? window.brSigOnFor(el) : true;
      return sigOn ? html : window.brStripSigMarkers(html);
    };
    wrapped.__brSigWrapped = true;
    TurasPins.capturePortableHtml = wrapped;
  }

  function initPins() {
    if (typeof TurasPins === "undefined") return;
    wrapCaptureForSigMode();

    TurasPins.init({
      storeId: "br-pinned-views-data",
      cssPrefix: "br-pinned",
      moduleLabel: "Brand",
      containerId: "br-pinned-cards-container",
      emptyStateId: "br-pinned-empty",
      badgeId: "br-pin-count-badge",
      features: { sections: true, dragDrop: true }
    });

    if (TurasPins._initDragDrop) TurasPins._initDragDrop();

    // Close any open popover when clicking outside, but not when clicking a
    // button that opens one. Those buttons run their inline onclick first and
    // the SAME click then bubbles to here, so closing on it would shut the
    // popover the click had just opened.
    //
    // Stage 5's destination controls were missing from this list, so a reader
    // clicking Pin or PNG on a destination toolbar got nothing at all: the
    // picker opened and was removed before it could paint. Found in Stage 6
    // by clicking the controls in a browser instead of calling their
    // handlers. drive_chrome.py had passed 115 of 115 because it called
    // brPinFrom and brExportPngFrom directly and only ever clicked Excel,
    // which has no popover. It now clicks all three.
    //
    // One list, so the next control to open a popover is added in one place.
    var POPOVER_OPENERS = ".br-pin-btn, .br-png-btn, .ma-png-btn, " +
                          ".fn-png-btn, .br-dest-pin, .br-dest-png";
    document.addEventListener("click", function(e) {
      if (!e.target.closest(POPOVER_OPENERS)) {
        TurasPins.closePopover();
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPins);
  } else {
    initPins();
  }
})();
