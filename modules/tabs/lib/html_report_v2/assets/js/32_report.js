/**
 * v2 Report tab — the narrative wrapper around the numbers: background &
 * method, executive summary, added slides (text blocks or imported images,
 * e.g. from a qual phase), and About (analyst, contact, disclaimers) plus
 * the auto-generated methodology notes. All sections are editable, persist
 * locally, and travel inside saved report copies.
 *
 * Also owns "Save copy": clones this document with the user's insights,
 * story and report sections embedded, so the saved .html opens for anyone
 * with all annotations intact — still a single self-contained file.
 *
 * SIZE-EXCEPTION: one narrative workspace + the save-copy serialiser.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var report = TR.report = {};
  var KEY = "turas_v2_report";
  var cache = null;

  var SECTIONS = [
    ["background", "Background & method",
      "Why the study was run, who was interviewed, fieldwork dates, method notes…"],
    ["exec", "Executive summary",
      "The findings that matter, in the analyst's words…"]
  ];
  var ABOUT_FIELDS = [
    ["analyst", "Analyst / author"],
    ["contact", "Contact details"],
    ["disclaimer", "Disclaimers / confidentiality"]
  ];

  function store() {
    if (cache) return cache;
    cache = { sections: {}, about: {}, slides: [] };
    if (TR.userState && TR.userState.report) {
      cache = JSON.parse(JSON.stringify(TR.userState.report));
    }
    try {
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(KEY));
      if (raw) {
        var own = JSON.parse(raw);
        if (own && (Object.keys(own.sections || {}).length ||
            Object.keys(own.about || {}).length || (own.slides || []).length)) {
          cache = own;
        }
      }
    } catch (e) { /* island-only */ }
    cache.sections = cache.sections || {};
    cache.about = cache.about || {};
    cache.slides = cache.slides || [];
    return cache;
  }

  function persist() {
    try {
      if (global.localStorage) localStorage.setItem(TR.d2.storeKey(KEY), JSON.stringify(store()));
    } catch (e) {
      TR.shell.toast("Browser storage is full — use Save copy to keep your work");
    }
  }

  report.data = function () { return store(); };

  /* Defaults imported from the config (project.report_meta) — shown until the
   * analyst types their own. A field set in localStorage (even to "") wins, so
   * the analyst can always override; an untouched field falls back here. */
  function metaOf() { return (TR.AGG.project && TR.AGG.project.report_meta) || {}; }
  function aboutDefault(field) {
    var m = metaOf();
    if (field === "analyst") return m.analyst || "";
    if (field === "contact") {
      return [m.company, m.email, m.phone].filter(function (x) { return x; }).join(" · ");
    }
    if (field === "disclaimer") return m.closing || "";
    return "";
  }
  function sectionDefault(sec) {
    var m = metaOf();
    if (sec === "background") {
      if (m.background) return m.background;            // config Comments _BACKGROUND
      if (m.fieldwork) return "Fieldwork: " + m.fieldwork + ".";
    }
    if (sec === "exec" && m.exec_summary) return m.exec_summary;  // _EXECUTIVE_SUMMARY
    return "";
  }

  report.renderTab = function (host) {
    var s = store();
    var html = ['<div class="page">'];
    html.push('<div class="card"><h2>Report</h2><p>The narrative around the numbers. ' +
      "Background &amp; method and the Executive summary are editable, saved in " +
      "this browser, and embedded in <strong>saved copies</strong> of the report " +
      "— use <em>Save copy</em> (top right) to produce a single .html with your " +
      "insights, story and these sections baked in, ready to send.</p></div>");
    SECTIONS.forEach(function (sec) {
      var secVal = sec[0] in s.sections ? s.sections[sec[0]] : sectionDefault(sec[0]);
      html.push('<div class="card"><h3>' + sec[1] + "</h3>" +
        '<textarea class="rpt-section" data-section="' + sec[0] +
        '" placeholder="' + fmt.escapeHtml(sec[2]) + '">' +
        fmt.escapeHtml(secVal) + "</textarea></div>");
    });

    // AI-assisted key findings (read-only, labelled) — shown only when present.
    html.push(TR.ai.execSummaryHtml());

    html.push('<div class="card"><h3>Added slides</h3><p>Import exhibits from outside ' +
      "this study — e.g. qual-phase slides exported as images (in PowerPoint: " +
      "right-click a slide → Save as Picture), or plain text blocks.</p>" +
      '<div class="sa-btns"><label class="t-btnish">+ Import image' +
      '<input id="slide-image" type="file" accept="image/png,image/jpeg" hidden></label>' +
      '<button data-act="add-text">+ Text block</button></div>' +
      '<div class="added-slides">' + s.slides.map(function (slide, i) {
        return '<div class="added-slide" data-i="' + i + '">' +
          (slide.image
            // FileReader data URLs only today, but stored state outlives
            // the writer — escape the attribute like every other value
            ? '<img src="' + fmt.escapeHtml(slide.image) + '" alt="' +
              fmt.escapeHtml(slide.title || "Added slide") + '">'
            : '<div class="as-text">' + fmt.escapeHtml(slide.text || "") + "</div>") +
          '<div class="as-foot"><input type="text" class="as-title" value="' +
          fmt.escapeHtml(slide.title || "") + '" placeholder="Caption…">' +
          '<button data-removeslide="' + i + '" aria-label="Remove">✕</button></div></div>';
      }).join("") + "</div></div>");

    // About is read-only: it is set from the project configuration (analyst,
    // contact, disclaimers) and is not an editable workspace. Only populated
    // fields are shown.
    html.push('<div class="card"><h3>About this report</h3>' +
      '<p class="hint">Set from the project configuration.</p>' +
      ABOUT_FIELDS.map(function (f) {
        var aboutVal = aboutDefault(f[0]);
        if (!aboutVal) return "";
        return '<div class="rpt-field"><label>' + f[1] + "</label>" +
          '<div class="rpt-about-static">' + fmt.escapeHtml(aboutVal) + "</div></div>";
      }).join("") + autoAboutHtml() + "</div>");
    html.push("</div>");
    // fresh wrapper per render — never stack duplicate listeners
    var wrap = document.createElement("div");
    wrap.innerHTML = html.join("");
    host.replaceChildren(wrap);
    wire(wrap);
  };

  function autoAboutHtml() {
    var p = TR.AGG.project;
    var verify = TR.VERIFY || {};
    var ok = verify.other_banners_base_ge_threshold || {};
    return "<h3>Methodology (auto-generated)</h3>" +
      "<p>" + fmt.escapeHtml(p.name) + " · " + fmt.escapeHtml(p.wave || "") +
      ". Published figures are the report of record; filtered and custom-banner " +
      "views recompute live from embedded respondent-level data and are badged " +
      "COMPUTED. Significance: two-proportion pooled z-test at 95% (optional 80% " +
      "lowercase letters), expected counts ≥ 5, bases under " + p.low_base_threshold +
      " excluded and flagged ⚠. " +
      (TR.MICRO && TR.MICRO.synthetic
        ? "This prototype's respondent data is SYNTHETIC, fitted to the published " +
          "tables (Campus crosses exact; other banners mean |error| " +
          (ok.mean_abs_err_pp !== undefined ? ok.mean_abs_err_pp.toFixed(1) : "≈2") +
          "pp on healthy bases). A production build embeds real anonymised data."
        : "") + "</p>" + TR.ai.methodologyHtml();
  }

  function wire(host) {
    host.addEventListener("input", function (e) {
      if (e.target.classList.contains("rpt-section")) {
        store().sections[e.target.getAttribute("data-section")] = e.target.value;
        persist();
      }
      if (e.target.classList.contains("as-title")) {
        var slide = e.target.closest(".added-slide");
        store().slides[parseInt(slide.getAttribute("data-i"), 10)].title = e.target.value;
        persist();
      }
    });
    host.addEventListener("click", function (e) {
      var remove = e.target.closest("[data-removeslide]");
      if (remove) {
        store().slides.splice(parseInt(remove.getAttribute("data-removeslide"), 10), 1);
        persist();
        report.renderTab(document.getElementById("tabhost"));
        return;
      }
      var act = e.target.closest("[data-act]");
      if (act && act.getAttribute("data-act") === "add-text") {
        var text = prompt("Text for the added slide:");
        if (text) {
          store().slides.push({ text: text, title: "" });
          persist();
          report.renderTab(document.getElementById("tabhost"));
        }
      }
    });
    var imageInput = host.querySelector("#slide-image");
    if (imageInput) {
      imageInput.addEventListener("change", function () {
        var file = imageInput.files[0];
        if (!file) return;
        if (file.size > 1.5 * 1024 * 1024) {
          TR.shell.toast("Image too large — keep imported slides under 1.5 MB each");
          return;
        }
        var reader = new FileReader();
        reader.onload = function () {
          store().slides.push({ image: reader.result, title: file.name });
          persist();
          report.renderTab(document.getElementById("tabhost"));
        };
        reader.readAsDataURL(file);
      });
    }
  }

  /* ---------------- save a portable annotated copy ---------------- */

  report.saveCopy = function () {
    var state = {
      saved: true,
      insights: TR.insights.all(),
      annotations: TR.notes.all(),
      story: TR.story2.items(),
      banners: TR.savedBanners.all(),
      composites: TR.compositeBanners.all(),
      report: store()
    };
    var json = JSON.stringify(state).replace(/<\//g, "<\\/");
    var clone = document.documentElement.cloneNode(true);
    var app = clone.querySelector("#app");
    if (app) app.innerHTML = "";
    var island = clone.querySelector("#user-state");
    if (!island) {
      TR.shell.toast("Save failed — user-state island missing");
      return;
    }
    island.textContent = json;
    var blob = new Blob(["<!DOCTYPE html>\n" + clone.outerHTML],
      { type: "text/html" });
    var link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = fmt.slug(TR.AGG.project.name) + "_annotated.html";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
    TR.shell.toast("Annotated copy saved — single file, send it to anyone");
  };

})(typeof window !== "undefined" ? window : globalThis);
