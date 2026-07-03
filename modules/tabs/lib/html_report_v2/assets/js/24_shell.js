/**
 * v2 shell — boot, header, report tabs, routing, and the About tab.
 * Tab content renderers live in their own modules (cards/views/story);
 * the shell owns the frame and the state→DOM routing.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var shell = TR.shell = {};

  /**
   * B1 Read vs Analyse navigation: the tab bar renders two visual groups —
   * reading surfaces first, the analyst workbenches after a divider. Story/
   * Crosstabs/Report are always present; the rest are gated by the per-report
   * visibility flags in project.tabs (default-on, so existing reports are
   * unchanged). Tracking also needs prior-wave data; Qualitative also needs a
   * non-null DATA_QUAL island. Tab ids are unchanged, so saved-copy deep links
   * (#tab=…) keep resolving.
   */
  function tabGroups() {
    var flags = (TR.AGG.project && TR.AGG.project.tabs) || {};
    var on = function (flag) { return flags[flag] !== false; };
    var read = [];
    if (on("dashboard")) read.push(["dashboard", "Dashboard"]);
    if (on("patterns")) read.push(["takeout", "Patterns"]);
    if (TR.d2.tracking().enabled && on("tracking")) read.push(["moved", "Tracking"]);
    if (TR.d2.qualitative && TR.d2.qualitative().enabled) read.push(["qualitative", "Qualitative"]);
    read.push(["story", "Story"]);
    var analyse = [["crosstabs", "Crosstabs"]];
    if (on("differences")) analyse.push(["findings", "Differences"]);
    analyse.push(["report", "Report"]);
    return [{ label: "Read", tabs: read }, { label: "Analyse", tabs: analyse }];
  }
  shell.tabGroups = tabGroups;   // exposed for the node gate

  /** The grouped tab bar. Group labels and the divider are aria-hidden so the
   *  tablist exposes only tabs to assistive tech; visual grouping is CSS. */
  function tabsNavHtml() {
    return '<nav class="tabs" role="tablist">' + tabGroups().map(function (g, gi) {
      return (gi ? '<span class="tabsep" aria-hidden="true"></span>' : "") +
        '<span class="tabgrp-label" aria-hidden="true">' + g.label + "</span>" +
        g.tabs.map(function (t) {
          return '<button role="tab" class="tabbtn" data-tab="' + t[0] +
            '" aria-selected="false">' + t[1] +
            (t[0] === "story" ? ' <span class="count" id="story-count">0</span>' : "") +
            "</button>";
        }).join("");
    }).join("") + "</nav>";
  }
  shell._tabsNavHtml = tabsNavHtml;   // exposed for the node gate

  shell.boot = function () {
    var agg = parseIsland("data-agg"), micro = parseIsland("data-micro"),
        prev = parseIsland("data-prev"), verify = parseIsland("data-verify");
    if (!agg) { fatal([{ code: "IO_DATA_PARSE", message: "aggregate data island failed to parse" }]); return; }
    TR.AGG = agg; TR.MICRO = micro; TR.PREV = prev; TR.VERIFY = verify;
    TR.QUAL = parseIsland("data-qual");          // qualitative verbatims (null when absent)
    TR.userState = parseIsland("user-state");   // saved-copy annotations
    var check = TR.d2.validate(agg, micro, prev);
    if (!check.ok) { fatal(check.errors); return; }

    var d2 = TR.d2;
    var wantSelftest = location.hash.indexOf("selftest") >= 0;
    // A report with no banner groups (Total-only survey) has no default
    // banner; "" matches no column group, so views show the Total column.
    d2.state.banner = (agg.banner_groups && agg.banner_groups.length)
      ? agg.banner_groups[0].id : "";
    d2.decodeHash(location.hash);
    if (!d2.questionByCode(d2.state.activeQ)) {
      d2.state.activeQ = agg.questions[0].code;
    }
    d2.state.tab = shell.landingTab(location.hash, d2.state.tab);
    document.title = agg.project.name + " — Turas Report v2";
    applyTheme();
    document.getElementById("app").innerHTML = frameHtml();
    TR.filterBar.render();
    shell.route();
    wireTopLevel();
    if (wantSelftest && TR.selftest2) TR.selftest2.run();
  };

  /**
   * D1 landing: a deep link naming a tab (#tab=…) ALWAYS wins; otherwise a
   * saved/shared copy with cover content opens on the exec-summary cover;
   * otherwise today's default landing stands (analyst-fresh unchanged).
   */
  shell.landingTab = function (hash, current) {
    if (/(^#|[&#])tab=/.test(hash || "")) return current;
    return (TR.reader && TR.reader.coverAvailable && TR.reader.coverAvailable())
      ? "cover" : current;
  };

  function parseIsland(id) {
    var el = document.getElementById(id);
    if (!el) return null;
    try { return JSON.parse(el.textContent); } catch (e) { return null; }
  }

  function fatal(errors) {
    var list = errors.map(function (e) {
      return "<li><code>" + fmt.escapeHtml(e.code) + "</code> " +
        fmt.escapeHtml(e.message) + "</li>";
    }).join("");
    if (global.console) console.error("[TurasV2] boot refused:", errors);
    document.getElementById("app").innerHTML =
      '<div class="fatal" role="alert"><h1>This report cannot be displayed</h1><ul>' +
      list + "</ul></div>";
  }

  function applyTheme() {
    var style = document.documentElement.style;
    style.setProperty("--brand", TR.charts.brandOf());
    style.setProperty("--accent", TR.charts.accentOf());
  }

  function frameHtml() {
    var p = TR.AGG.project;
    // researcher logo (embedded data URI) when supplied, else the brand dot
    var brandmark = p.researcher_logo
      ? '<img class="hdr-logo" src="' + p.researcher_logo + '" alt="">'
      : '<span class="dot" aria-hidden="true"></span>';
    // optional client logo, shown on the right of the header
    var clientLogo = p.client_logo
      ? '<img class="hdr-clientlogo" src="' + p.client_logo + '" alt="">' : "";
    // subtitle: client · interactive report · single file · works offline
    // (client omitted cleanly when blank, so there is never a leading " · ")
    var subBits = [];
    if (p.client) subBits.push(fmt.escapeHtml(p.client));
    subBits.push("<strong>interactive report</strong>");
    // At-a-glance weighting indicator (weighted reports only), so the reader is
    // never left guessing whether the figures are weighted. Names the weight
    // variable in a tooltip when known.
    if (p.weighted) {
      subBits.push('<strong class="hdr-wt"' +
        (p.weight_variable
          ? ' title="Figures weighted by ‘' + fmt.escapeHtml(p.weight_variable) + '’"'
          : ' title="Figures are weighted"') +
        ">weighted data</strong>");
    }
    subBits.push("single file &middot; works offline");
    return '<header class="hdr"><div class="hdr-in">' +
      '<div class="hdr-brand">' + brandmark +
      "<div><h1>" + fmt.escapeHtml(p.name) + "</h1>" +
      '<div class="hdr-sub">' + subBits.join(" &middot; ") + "</div></div></div>" +
      '<div class="hdr-meta">' + clientLogo +
      // D1: the cover is the saved-copy landing page, not a READ tab — this
      // small header link is the only way back to it, and only exists when a
      // cover exists (saved copy + story content)
      (TR.reader && TR.reader.coverAvailable && TR.reader.coverAvailable()
        ? '<button class="hdr-legend hdr-cover" data-cover-open ' +
          'title="Back to the report cover — executive summary and leading findings">' +
          "Cover</button>" : "") +
      '<button class="hdr-legend" data-legend-open aria-haspopup="dialog" ' +
      'title="How to read this report — significance letters, arrows, bands, precision">' +
      "ⓘ How to read</button>" +
      '<button class="savecopy" data-savecopy title="Save a single .html copy with your ' +
      'insights, story and report sections embedded — ready to send">💾 Save copy</button>' +
      "</div></div>" +
      tabsNavHtml() + "</header>" +
      '<div id="filterbar" class="filterbar"></div>' +
      // A3: who the numbers describe — persistent on EVERY tab; polite so a
      // cut change is announced without stealing focus
      '<div id="audstrip" class="audstrip" aria-live="polite"></div>' +
      '<div id="tabhost" class="tabhost"></div>' +
      '<div id="toast" role="status" aria-live="polite"></div>' +
      '<div id="present-overlay" hidden></div>';
  }

  /** Route current state.tab into the tab host. */
  shell.route = function () {
    var d2 = TR.d2, host = document.getElementById("tabhost");
    // a cover deep link on a report without cover content (analyst-fresh, or
    // the story was cleared) lands on the dashboard, never a blank page
    if (d2.state.tab === "cover" &&
        !(TR.reader && TR.reader.coverAvailable && TR.reader.coverAvailable())) {
      d2.state.tab = "dashboard";
    }
    document.querySelectorAll(".tabbtn").forEach(function (btn) {
      btn.setAttribute("aria-selected",
        String(btn.getAttribute("data-tab") === d2.state.tab));
    });
    if (d2.state.tab === "cover") TR.reader.renderCover(host);
    else if (d2.state.tab === "takeout") TR.takeout.render(host);
    else if (d2.state.tab === "crosstabs") TR.cards2.renderTab(host);
    else if (d2.state.tab === "dashboard") TR.views.dashboard(host);
    else if (d2.state.tab === "moved") TR.views.whatMoved(host);
    else if (d2.state.tab === "findings") TR.views.findings(host);
    else if (d2.state.tab === "qualitative") TR.qual.render(host);
    else if (d2.state.tab === "story") TR.story2.renderTab(host);
    else TR.report.renderTab(host);
    // The audience filter recomputes from this wave's microdata; prior waves
    // are pre-aggregated, so a filter can't apply on Tracking. The Executive
    // Takeout summarises the published view, so it hides the bar too. The
    // cover is a landing page, not an analysis surface — no filter bar.
    var fb = document.getElementById("filterbar");
    if (fb) fb.hidden = d2.state.tab === "moved" || d2.state.tab === "takeout" ||
      d2.state.tab === "cover";
    if (TR.reader) TR.reader.renderStrip();
    d2.pushHash();
  };

  shell.goTab = function (tab) {
    // A tab-bar click is plain navigation, never a jump — drop any stale qual
    // breadcrumb so opening Qualitative directly is a clean browse.
    if (TR.qual && TR.qual.clearJump) TR.qual.clearJump();
    TR.d2.state.tab = tab;
    shell.route();
  };

  /** Jump to a question in the crosstabs tab (deep links). */
  shell.goQuestion = function (code, bannerId) {
    var d2 = TR.d2;
    d2.state.activeQ = code;
    if (bannerId) d2.state.banner = bannerId;
    d2.state.tab = "crosstabs";
    shell.route();
  };

  function wireTopLevel() {
    // singleton guard: document/window listeners must never stack, even
    // if boot were ever re-entered (hard-won guardrail)
    if (shell._wiredTopLevel) return;
    shell._wiredTopLevel = true;
    document.querySelector(".tabs").addEventListener("click", function (e) {
      var btn = e.target.closest(".tabbtn");
      if (btn) shell.goTab(btn.getAttribute("data-tab"));
    });
    // tablist arrow-key navigation (Left/Right move focus across BOTH groups)
    document.querySelector(".tabs").addEventListener("keydown", function (e) {
      if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
      var btns = Array.prototype.slice.call(document.querySelectorAll(".tabbtn"));
      var at = btns.indexOf(document.activeElement);
      if (at === -1) return;
      e.preventDefault();
      var next = (at + (e.key === "ArrowRight" ? 1 : -1) + btns.length) % btns.length;
      btns[next].focus();
    });
    document.addEventListener("click", function (e) {
      if (e.target.closest("[data-savecopy]")) TR.report.saveCopy();
    });
    document.addEventListener("click", function (e) {
      if (e.target.closest("[data-cover-open]")) shell.goTab("cover");
    });
    // One "How to read this" panel for the whole report — every ⓘ trigger
    // (header, collapsed PE box, crosstabs footer) opens the same dialog.
    document.addEventListener("click", function (e) {
      if (e.target.closest("[data-legend-open]") && TR.reader) TR.reader.openLegend();
    });
    // Closed<->open jump: a "💬 comments" affordance on a linked closed/composite
    // card opens its open-end comments in the Qualitative tab, filtered to the cut.
    document.addEventListener("click", function (e) {
      var jb = e.target.closest("[data-qual-jump]");
      if (jb && TR.qual && TR.qual.jumpTo) {
        e.preventDefault();
        TR.qual.jumpTo(jb.getAttribute("data-qual-jump"));
      }
    });
    // Pin any on-screen card to the story "as it looks on the page". One
    // delegated listener serves every surface (patterns / dashboard /
    // differences) — each card carries data-snap-card and a data-snap-pin
    // control with the title / source / context to record.
    document.addEventListener("click", function (e) {
      var pin = e.target.closest("[data-snap-pin]");
      if (!pin) return;
      var card = pin.closest("[data-snap-card]");
      if (!card) return;
      e.preventDefault();
      TR.story2.pinSnapshot({
        source: pin.getAttribute("data-snap-source") || "card",
        title: pin.getAttribute("data-snap-title") || "Pinned card",
        context: pin.getAttribute("data-snap-context") || "",
        html: shell.snapshotCard(card),
        lines: shell.snapshotLines(card)
      });
    });
    global.addEventListener("hashchange", function () {
      TR.d2.decodeHash(location.hash);
      TR.filterBar.render();
      shell.route();
    });
  }

  /**
   * Shared pin popover: one look everywhere something pins to the story.
   * @param {Element} menu - the .pinmenu element to fill.
   * @param {Array} items - [{key, label, checked}] element checkboxes.
   * @param {Function} onPin - receives {key: bool} flags.
   * @param {string} [extraHtml] - appended below the Pin button.
   */
  shell.pinMenu = function (menu, items, onPin, extraHtml) {
    menu.innerHTML = '<div class="pm-title">Pin to story</div>' +
      items.map(function (it) {
        return '<label><input type="checkbox" data-pf="' + it.key + '"' +
          (it.checked ? " checked" : "") + "> " + it.label + "</label>";
      }).join("") +
      '<button class="primary wide" data-pingo>Pin</button>' +
      (extraHtml || "");
    menu.querySelector("[data-pingo]").addEventListener("click", function () {
      var flags = {};
      menu.querySelectorAll("[data-pf]").forEach(function (cb) {
        flags[cb.getAttribute("data-pf")] = cb.checked;
      });
      onPin(flags);
    });
  };

  /**
   * Capture a card "as it looks on the page" for a story snapshot: clone it,
   * drop the pin control itself, and freeze any editable field to static text so
   * the pinned copy renders identically but inert. Returns an HTML string.
   */
  shell.snapshotCard = function (cardEl) {
    var clone = cardEl.cloneNode(true);
    clone.querySelectorAll(".snap-pin").forEach(function (el) { el.remove(); });
    clone.querySelectorAll("textarea").forEach(function (ta) {
      var d = document.createElement("div");
      d.className = "snap-frozen-note";
      d.textContent = ta.value || ta.textContent || "";
      ta.replaceWith(d);
    });
    clone.querySelectorAll("[contenteditable]").forEach(function (el) {
      el.removeAttribute("contenteditable");
    });
    clone.removeAttribute("data-snap-card");
    return clone.outerHTML;
  };

  /** Plain-text lines from a card — used only for the deck export of a snapshot
   *  pin (the on-screen story keeps the exact HTML; the SVG/PPTX path has no way
   *  to rasterise arbitrary HTML, so it renders the same content as a card). */
  shell.snapshotLines = function (cardEl) {
    var out = [];
    function add(t) {
      t = (t || "").replace(/\s+/g, " ").trim();
      if (t && out.indexOf(t) === -1) out.push(t);
    }
    // headings / captions / prose — skip anything inside a table, whose cells are
    // harvested row-by-row below so the tabular layout survives.
    cardEl.querySelectorAll(
      "h1,h2,h3,h4,strong,p,li,.tko-take,.tko-note,.tko-cap,.df-sentence,.df-beats,.gv,.gt"
    ).forEach(function (el) {
      if (el.closest(".snap-pin") || el.closest("table")) return;
      add(el.textContent);
    });
    // Table rows: join each row's cells so a pinned crosstab carries its NUMBERS,
    // not just its title (I1 — the deck/PNG export had the caption but no figures).
    cardEl.querySelectorAll("table tr").forEach(function (tr) {
      if (tr.closest(".snap-pin")) return;
      var cells = [];
      tr.querySelectorAll("th,td").forEach(function (c) {
        cells.push((c.textContent || "").replace(/\s+/g, " ").trim());
      });
      add(cells.filter(function (x) { return x !== ""; }).join(" · "));
    });
    return out.slice(0, 20);
  };

  shell.toast = function (message) {
    if (typeof document === "undefined") return;   // headless (node gate)
    var holder = document.getElementById("toast");
    if (!holder) return;
    var note = document.createElement("div");
    note.className = "toastmsg";
    note.textContent = message;
    holder.appendChild(note);
    requestAnimationFrame(function () { note.classList.add("show"); });
    setTimeout(function () {
      note.classList.remove("show");
      setTimeout(function () { note.remove(); }, 400);
    }, 2600);
  };


  if (typeof document !== "undefined") {
    document.addEventListener("DOMContentLoaded", shell.boot);
  }

})(typeof window !== "undefined" ? window : globalThis);
