/**
 * Application shell — boot, theming, fatal-error panel, sidebar navigation
 * and the lazily-rendered card list. Event wiring lives in 09_wire.js.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var app = TR.app = {};

  /** Parse + validate the embedded payload, then render the shell. */
  app.boot = function () {
    var holder = document.getElementById("turas-data");
    var payload;
    try {
      payload = JSON.parse(holder.textContent);
    } catch (e) {
      app.fatal([{ code: "IO_DATA_PARSE",
        message: "Embedded JSON failed to parse: " + e.message }]);
      return;
    }
    var check = TR.data.validate(payload);
    if (!check.ok) { app.fatal(check.errors); return; }

    TR.state = { payload: payload };
    app.applyTheme(payload);
    document.title = payload.project.name + " — Turas Report";
    document.getElementById("app").innerHTML = shellHtml(payload);
    buildNav(payload);
    buildCards(payload);
    TR.wire.init(payload);
    if (location.hash === "#selftest" && TR.selftest) TR.selftest.run();
  };

  /** Console + on-page refusal panel listing every accumulated error. */
  app.fatal = function (errors) {
    var lines = ["", "=== TURAS REPORT ERROR ==="];
    errors.forEach(function (e) { lines.push(e.code + ": " + e.message); });
    lines.push("==========================", "");
    if (global.console) console.error(lines.join("\n"));
    var items = errors.map(function (e) {
      return "<li><code>" + fmt.escapeHtml(e.code) + "</code> " +
        fmt.escapeHtml(e.message) + "</li>";
    }).join("");
    document.getElementById("app").innerHTML =
      '<div class="fatal" role="alert"><h1>This report cannot be displayed</h1>' +
      "<p>The embedded data failed validation. Fix the data layer and rebuild — " +
      "every problem found is listed below.</p><ul>" + items + "</ul></div>";
  };

  /** Apply brand colours from the payload; keep sidebar text readable. */
  app.applyTheme = function (payload) {
    var brand = TR.charts.brandOf(payload);
    var accent = TR.charts.accentOf(payload);
    var rootStyle = document.documentElement.style;
    rootStyle.setProperty("--brand", brand);
    rootStyle.setProperty("--accent", accent);
    rootStyle.setProperty("--sidebar-fg", luminance(brand) > 0.55 ? "#1c2333" : "#ffffff");
  };

  /** WCAG-ish relative luminance of a hex colour (0 dark – 1 light). */
  function luminance(hex) {
    var c = String(hex).replace("#", "");
    if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
    var lin = function (pos) {
      var v = parseInt(c.substr(pos, 2), 16) / 255;
      return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * lin(0) + 0.7152 * lin(2) + 0.0722 * lin(4);
  }

  function shellHtml(payload) {
    var p = payload.project;
    var nQ = payload.questions.length;
    var nCols = (payload.banner.columns || []).length;
    var pptxOn = !p.export || p.export.pptx !== false;
    return '<header class="topbar">' +
      '<div class="brandmark"><span class="dot" aria-hidden="true"></span>Turas' +
      '<span class="proto">report</span></div>' +
      '<div class="projmeta"><strong>' + fmt.escapeHtml(p.name) + "</strong>" +
      "<span>" + fmt.escapeHtml(p.wave || "") + "</span></div>" +
      '<div class="topactions">' +
      '<button type="button" data-action="compose-open">⧉ Compose</button>' +
      (pptxOn ? '<button type="button" class="primary" data-action="deck-open">' +
        'Deck <span class="count" id="deck-count">0</span></button>' : "") +
      "</div></header>" +
      '<div class="layout">' +
      '<nav class="sidebar" aria-label="Questions">' +
      '<input id="search" type="search" placeholder="Search questions…" ' +
      'aria-label="Search questions" autocomplete="off">' +
      '<div id="nav"></div>' +
      '<div class="sidefoot">Single self-contained file · renders from embedded ' +
      "data · no network, no installs</div></nav>" +
      '<main id="main">' + heroHtml(p, nQ, nCols) +
      '<div id="composites"></div><div id="cards"></div></main></div>' +
      '<div id="drawer-backdrop" hidden></div>' +
      '<aside id="composer-drawer" class="drawer" role="dialog" aria-modal="true" ' +
      'aria-label="Cross-question composer" hidden></aside>' +
      '<aside id="deck-drawer" class="drawer" role="dialog" aria-modal="true" ' +
      'aria-label="Export deck" hidden></aside>' +
      '<div id="toast" role="status" aria-live="polite"></div>';
  }

  function heroHtml(p, nQ, nCols) {
    return '<section class="hero"><h1>' + fmt.escapeHtml(p.name) + "</h1>" +
      '<p class="sub">' + fmt.escapeHtml([p.client, p.wave, p.fieldwork]
        .filter(Boolean).join(" · ")) + "</p>" +
      '<div class="herostats">' +
      '<div class="stat"><b>' + nQ + "</b>questions</div>" +
      '<div class="stat"><b>' + nCols + "</b>banner columns</div>" +
      '<div class="stat"><b>0</b>external requests</div></div>' +
      (p.sig_note ? '<p class="signote">' + fmt.escapeHtml(p.sig_note) + "</p>" : "") +
      "</section>";
  }

  function buildNav(payload) {
    var nav = document.getElementById("nav");
    var out = [];
    var sections = Array.isArray(payload.sections) && payload.sections.length
      ? payload.sections
      : [{ id: "all", title: "Questions",
          questions: payload.questions.map(function (q) { return q.id; }) }];
    sections.forEach(function (section) {
      out.push('<div class="navsec">' + fmt.escapeHtml(section.title) + "</div>");
      (section.questions || []).forEach(function (qid) {
        var q = TR.data.questionById(payload, qid);
        if (!q) return;
        out.push('<a class="navlink" href="#card-' + fmt.escapeHtml(q.id) +
          '" data-q="' + fmt.escapeHtml(q.id) + '"><span class="code">' +
          fmt.escapeHtml(q.code || q.id) + '</span><span class="t">' +
          fmt.escapeHtml(q.title) + "</span></a>");
      });
    });
    nav.innerHTML = out.join("");
  }

  /** Card shells only — bodies render lazily as they scroll into view. */
  function buildCards(payload) {
    var holder = document.getElementById("cards");
    var out = [];
    payload.questions.forEach(function (q) {
      out.push('<article class="card" id="card-' + fmt.escapeHtml(q.id) +
        '" data-q="' + fmt.escapeHtml(q.id) + '" data-col="0" data-search="' +
        fmt.escapeHtml(((q.code || "") + " " + q.title).toLowerCase()) + '">' +
        TR.cards.headHtml(q, payload) +
        '<div class="cardbody pending">Rendering…</div></article>');
    });
    holder.innerHTML = out.join("");
  }

  if (typeof document !== "undefined") {
    document.addEventListener("DOMContentLoaded", app.boot);
  }

})(typeof window !== "undefined" ? window : globalThis);
