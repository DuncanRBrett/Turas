/**
 * v2 shell — boot, header, report tabs, routing, and the About tab.
 * Tab content renderers live in their own modules (cards/views/story);
 * the shell owns the frame and the state→DOM routing.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var shell = TR.shell = {};

  /** Tab list; Tracking only appears when a prior wave is configured. */
  function tabList() {
    var tabs = [
      ["dashboard", "Dashboard"],
      ["crosstabs", "Crosstabs"],
      ["findings", "Differences"]
    ];
    if (TR.d2.tracking().enabled) tabs.push(["moved", "Tracking"]);
    tabs.push(["story", "Story"], ["report", "Report"]);
    return tabs;
  }

  shell.boot = function () {
    var agg = parseIsland("data-agg"), micro = parseIsland("data-micro"),
        prev = parseIsland("data-prev"), verify = parseIsland("data-verify");
    if (!agg) { fatal([{ code: "IO_DATA_PARSE", message: "aggregate data island failed to parse" }]); return; }
    TR.AGG = agg; TR.MICRO = micro; TR.PREV = prev; TR.VERIFY = verify;
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
    document.title = agg.project.name + " — Turas Report v2";
    applyTheme();
    document.getElementById("app").innerHTML = frameHtml();
    TR.filterBar.render();
    shell.route();
    wireTopLevel();
    if (wantSelftest && TR.selftest2) TR.selftest2.run();
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
    subBits.push("single file &middot; works offline");
    return '<header class="hdr"><div class="hdr-in">' +
      '<div class="hdr-brand">' + brandmark +
      "<div><h1>" + fmt.escapeHtml(p.name) + "</h1>" +
      '<div class="hdr-sub">' + subBits.join(" &middot; ") + "</div></div></div>" +
      '<div class="hdr-meta">' + clientLogo +
      '<span class="wavechip">' + fmt.escapeHtml(p.wave || "") + "</span>" +
      waveHistoryChip() +
      '<button class="savecopy" data-savecopy title="Save a single .html copy with your ' +
      'insights, story and report sections embedded — ready to send">💾 Save copy</button>' +
      "</div></div>" +
      '<nav class="tabs" role="tablist">' + tabList().map(function (t) {
        return '<button role="tab" class="tabbtn" data-tab="' + t[0] +
          '" aria-selected="false">' + t[1] +
          (t[0] === "story" ? ' <span class="count" id="story-count">0</span>' : "") +
          "</button>";
      }).join("") + "</nav></header>" +
      '<div id="filterbar" class="filterbar"></div>' +
      '<div id="tabhost" class="tabhost"></div>' +
      '<div id="toast" role="status" aria-live="polite"></div>' +
      '<div id="present-overlay" hidden></div>';
  }

  /** Header chip summarising the tracked wave history ("" when none). */
  function waveHistoryChip() {
    var waves = TR.d2.tracking().waves;
    if (!waves.length) return "";
    var span = waves.length === 1 ? String(waves[0].year)
      : waves[0].year + "–" + waves[waves.length - 1].year;
    return '<span class="wavechip prev">history ' + fmt.escapeHtml(span) + "</span>";
  }

  /** Route current state.tab into the tab host. */
  shell.route = function () {
    var d2 = TR.d2, host = document.getElementById("tabhost");
    document.querySelectorAll(".tabbtn").forEach(function (btn) {
      btn.setAttribute("aria-selected",
        String(btn.getAttribute("data-tab") === d2.state.tab));
    });
    if (d2.state.tab === "crosstabs") TR.cards2.renderTab(host);
    else if (d2.state.tab === "dashboard") TR.views.dashboard(host);
    else if (d2.state.tab === "moved") TR.views.whatMoved(host);
    else if (d2.state.tab === "findings") TR.views.findings(host);
    else if (d2.state.tab === "story") TR.story2.renderTab(host);
    else TR.report.renderTab(host);
    // The audience filter recomputes from this wave's microdata; prior waves
    // are pre-aggregated, so a filter can't apply on Tracking. Hide the bar
    // there rather than offer a control that does nothing.
    var fb = document.getElementById("filterbar");
    if (fb) fb.hidden = d2.state.tab === "moved";
    d2.pushHash();
  };

  shell.goTab = function (tab) {
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
    document.addEventListener("click", function (e) {
      if (e.target.closest("[data-savecopy]")) TR.report.saveCopy();
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
