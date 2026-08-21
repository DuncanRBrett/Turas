/**
 * v2 Report tab — the narrative wrapper around the numbers: background &
 * method and executive summary (authored in the config, read-only here,
 * pinnable to the story), added slides (text blocks or imported images,
 * e.g. from a qual phase), and About (analyst + contact from the config, the
 * standard report-construction note) plus the auto-generated methodology
 * notes. Added slides persist locally and travel inside saved report copies.
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

  // [key, card title, the config Comments-sheet row that authors it]
  var SECTIONS = [
    ["background", "Background & method", "_BACKGROUND"],
    ["exec", "Executive summary", "_EXECUTIVE_SUMMARY"]
  ];
  var ABOUT_FIELDS = [
    ["analyst", "Analyst / author"],
    ["contact", "Contact details"]
  ];
  // Fallback producer name for the report-construction note when the config
  // carries no company_name (report_meta absent).
  var DEFAULT_COMPANY = "The Research LampPost";

  function store() {
    if (cache) return cache;
    cache = { sections: {}, about: {}, slides: [] };
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
    if (own && own._owns) {
      cache = { sections: own.sections || {}, about: own.about || {},
        slides: own.slides || [] };
      return cache;
    }
    if (TR.userState && TR.userState.report) {
      cache = JSON.parse(JSON.stringify(TR.userState.report));
      delete cache._owns;
    }
    cache.sections = cache.sections || {};
    cache.about = cache.about || {};
    cache.slides = cache.slides || [];
    if (own && typeof own === "object") {
      // un-owning local state fills gaps ADDITIVELY — a stale pre-existing store
      // for this project key must not hide the island's authored sections/slides
      Object.keys(own.sections || {}).forEach(function (k) {
        if (!(k in cache.sections)) cache.sections[k] = own.sections[k];
      });
      Object.keys(own.about || {}).forEach(function (k) {
        if (!(k in cache.about)) cache.about[k] = own.about[k];
      });
      var have = {};
      cache.slides.forEach(function (s) { have[JSON.stringify(s)] = true; });
      (own.slides || []).forEach(function (s) {
        if (!have[JSON.stringify(s)]) cache.slides.push(s);
      });
    }
    return cache;
  }

  function persist() {
    try {
      if (global.localStorage) {
        var s = store();   // every persist here is a reader change
        localStorage.setItem(TR.d2.storeKey(KEY), JSON.stringify(
          { _owns: true, sections: s.sections, about: s.about, slides: s.slides }));
      }
    } catch (e) {
      TR.shell.toast("Browser storage is full — use Save copy to keep your work");
    }
  }

  report.data = function () { return store(); };

  /** Effective text of a narrative section — authored by the report author in
   *  the config (project.report_meta via the Comments sheet) and read-only in
   *  the app, so this is always the config value. Legacy section edits in
   *  stored state are deliberately ignored. The cover (24a) reads the same
   *  value the Report tab shows. */
  report.sectionText = function (sec) { return sectionDefault(sec); };

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
    html.push('<div class="card"><h2>Report</h2>' +
      TR.txt.block("report.intro") + "</div>");
    html.push(report.sectionsHtml());

    // AI-assisted key findings (read-only, labelled) — shown only when present.
    html.push(TR.ai.execSummaryHtml());

    // Authored exhibits from the config, above the reader's own scratch ones.
    html.push(report.studySlidesHtml());

    html.push('<div class="card"><h3>Added slides</h3>' +
      TR.txt.block("report.added_slides.intro") +
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

    // About is read-only: analyst + contact come from the project
    // configuration; the report-construction note and methodology are
    // standard text, not an editable workspace.
    html.push(report.aboutHtml());
    // Statistical diagnostics — the interactive twin of the Excel stats pack
    // (empty string when the island carries none, e.g. an older report).
    html.push(report.diagnosticsHtml());
    html.push("</div>");
    // fresh wrapper per render — never stack duplicate listeners
    var wrap = document.createElement("div");
    wrap.innerHTML = html.join("");
    host.replaceChildren(wrap);
    wire(wrap);
  };

  /** Background & method + Executive summary — authored by the report author
   * in the config (Comments sheet _BACKGROUND / _EXECUTIVE_SUMMARY rows, with
   * the fieldwork-dates fallback) and rendered read-only, one paragraph per
   * line. A populated card is a data-snap-card with the standard snap-pin, so
   * the section can be pinned to the story — the shell's document-level
   * handler (24_shell) does the capture; no wiring here. A pure function of
   * the data island so it is unit-testable. */
  report.sectionsHtml = function () {
    return SECTIONS.map(function (sec) {
      var text = String(sectionDefault(sec[0]) || "").trim();
      var body = text
        ? text.split(/\n+/).map(function (p) {
            return "<p>" + fmt.escapeHtml(p) + "</p>";
          }).join("")
        : TR.txt.block("report.section_unset", { row: sec[2] }, { cls: "hint" });
      return '<div class="card rpt-sec-card"' + (text ? " data-snap-card" : "") +
        "><h3>" + sec[1] + "</h3>" +
        (text
          ? '<button class="snap-pin" data-snap-pin data-snap-source="report" ' +
            'data-snap-title="' + fmt.escapeHtml(sec[1]) + '" data-snap-context="" ' +
            'title="Pin this section to the story" ' +
            'aria-label="Pin section to story">📌</button>'
          : "") + body + "</div>";
    }).join("");
  };

  /** Study slides — exhibits the REPORT AUTHOR put in the config's AddedSlides
   *  sheet, carried on the data island as project.slides. Distinct from the
   *  reader's own Added slides above: these are authored, so they are read-only
   *  here, exactly like the narrative sections. They are deliberately NOT merged
   *  into the reader's slide store — that store takes ownership on first edit
   *  and would then ignore anything a later run authored. */
  report.slides = function () {
    var s = (TR.AGG && TR.AGG.project && TR.AGG.project.slides) || [];
    return Array.isArray(s) ? s : [];
  };

  /** One card per authored slide, each individually pinnable. A pure function of
   *  the data island ("" when the config authored none) so it is unit-testable. */
  report.studySlidesHtml = function () {
    var list = report.slides();
    if (!list.length) return "";
    return '<div class="card"><h3>Study slides</h3>' +
      '<p class="hint">Additional slides from outside Turas generation added ' +
      "to this report can be found here.</p>" +
      '<div class="added-slides">' + list.map(function (sl, i) {
        var title = String(sl.title || "");
        return '<div class="added-slide" data-snap-card>' +
          (sl.image
            ? '<img src="' + fmt.escapeHtml(sl.image) + '" alt="' +
              fmt.escapeHtml(title || "Study slide") + '">' : "") +
          (sl.text ? '<div class="as-text">' + fmt.escapeHtml(sl.text) + "</div>" : "") +
          '<div class="as-foot"><span class="as-cap">' + fmt.escapeHtml(title) +
          '</span><button class="snap-pin" data-snap-pin data-snap-source="slide" ' +
          'data-snap-slide="' + i + '" data-snap-title="' + fmt.escapeHtml(title) +
          '" title="Pin this slide to the story" ' +
          'aria-label="Pin slide to story">📌</button></div></div>';
      }).join("") + "</div></div>";
  };

  /** The About card: analyst + contact (config-fed, shown when set), then the
   * standard report-construction note — how the report is produced and where
   * AI does and does not act. The note's "names the model" promise is kept by
   * the auto-methodology block below (TR.ai.methodologyHtml names the model
   * whenever AI content is present). A pure function of the data island so it
   * is unit-testable. */
  /**
   * How this report was built.
   *
   * The wording lives in the callout registry under report.construction.* and
   * is edited in the Callout Editor; only the rules below are code. The stock
   * text describes a stock Turas report: R computes the PUBLISHED figures, and every
   * COMPUTED view is recalculated in the reader's browser by Turas's own
   * engine. The one sentence that is not always true — earlier waves shown as
   * previously published rather than recalculated — renders only when the
   * report carries earlier waves and none of them holds respondent-level
   * scores (a wave with scores IS recalculated, by 22w_waves.js).
   *
   * That default stops being true the moment a study puts other stages around
   * Turas — a derived-variable engine ahead of it, a preparation layer that
   * builds composite columns, pages that compute in the browser from their own
   * embedded data. The engine cannot know about those, so the STUDY declares
   * them, in the config's Comments sheet under _REPORT_CONSTRUCTION.
   *
   * A declaration replaces the WHOLE stock block — the default sentence and the
   * reproducibility, AI and author-validation paragraphs with it. It used to
   * replace only the first sentence, which meant a config that restated any of
   * those paragraphs printed them twice, and a config that deliberately left one
   * out had it silently reinstated underneath. Neither is a study saying how its
   * own numbers were built. The study is the authority on that; the trade is
   * that a study which declares a note owns every assurance in this section,
   * including whether it says anything about AI.
   *
   * The producer line is kept either way, so a declaration cannot accidentally
   * drop the attribution — the declared text is written to FOLLOW it. Unless the
   * study wrote its own: an author drafting this row naturally opens "This report
   * was produced by …", and prepending a second copy printed the sentence twice
   * on the client's page. So when the declaration already names the producer, it
   * is left to say it in its own words. Attribution is still guaranteed — one of
   * the two always renders.
   */
  /** Earlier waves this report can compare against. TR.PREV always carries the
   *  current wave, so one entry is not a tracker. */
  function priorWaves() {
    var w = (TR.PREV && TR.PREV.waves) || [];
    return w.filter(function (x) { return !x.current; });
  }
  function hasPriorWaves() { return priorWaves().length > 0; }

  /** True when every earlier wave is published figures only. A wave MAY carry
   *  per-respondent scores (22w_waves.js recomputes its mean and SD from them
   *  when it does), so "shown as published rather than recalculated" is a claim
   *  the note is only entitled to make when no earlier wave carries any. */
  function priorWavesArePublished() {
    var prior = priorWaves();
    if (!prior.length) return false;
    return prior.every(function (x) {
      var qs = x.questions || {};
      return Object.keys(qs).every(function (c) { return !(qs[c] || {}).scores; });
    });
  }

  /**
   * The words here are authored in the Callout Editor, not written in this
   * file — see 02_text.js. What stays in code is the logic: who owns the
   * attribution sentence, and which paragraphs a given report is entitled to
   * show. Blank any of these keys in the editor and that paragraph simply does
   * not render.
   */
  function constructionHtml() {
    var produced = TR.txt("report.construction.produced",
                          { company: metaOf().company || DEFAULT_COMPANY });
    var declared = String(metaOf().construction || "").trim();

    if (declared) {
      // Matched on the producer phrasing rather than the company name alone: a
      // note may mention the company for other reasons ("… reviewed by The
      // Research LampPost") without that being the attribution line.
      var ownsAttribution = /produced by\s+\S/i.test(declared.slice(0, 400));
      // Tagged data-txt-config, not data-txt-key: this study wrote these words
      // in its own config, so the Callout Editor is the wrong place to look for
      // them. The author-only badges colour the two sources differently.
      return declared.split(/\n+/).map(function (p, i) {
        return '<p data-txt-config="_REPORT_CONSTRUCTION">' +
          (i || ownsAttribution || !produced ? "" : produced + " ") +
          fmt.escapeHtml(p) + "</p>";
      }).join("");
    }

    // The stock note is ONE authored entry, written as it reads — blank lines
    // between paragraphs, exactly like the config row a study would write. Two
    // things inside it cannot be plain text and so arrive as placeholders:
    //   {producer}   the attribution sentence, because the declared-note path
    //                above uses the same sentence on its own;
    //   {waves_note} the earlier-waves sentence, because only the code knows
    //                when the report is entitled to make that claim — it needs
    //                earlier waves, none of them carrying respondent-level
    //                scores (a wave with scores IS recalculated, 22w_waves.js).
    // An author moves {waves_note} to say it somewhere else, or deletes it to
    // never say it at all.
    var stock = TR.txt("report.construction.stock", {
      producer: { html: produced },
      waves_note: { html: priorWavesArePublished()
        ? TR.txt("report.construction.prior_waves_published") : "" }
    });

    return stock.split(/\n\s*\n+/)
      .map(function (para) { return para.trim(); })
      .filter(Boolean)          // a dropped {waves_note} leaves no empty <p>
      .map(function (para) {
        return '<p data-txt-key="report.construction.stock">' + para + "</p>";
      }).join("");
  }

  report.aboutHtml = function () {
    return '<div class="card"><h3>About this report</h3>' +
      '<p class="hint">Analyst and contact are set from the project configuration.</p>' +
      ABOUT_FIELDS.map(function (f) {
        var aboutVal = aboutDefault(f[0]);
        if (!aboutVal) return "";
        return '<div class="rpt-field"><label>' + f[1] + "</label>" +
          '<div class="rpt-about-static">' + fmt.escapeHtml(aboutVal) + "</div></div>";
      }).join("") +
      "<h3>Report construction</h3>" +
      constructionHtml() +
      autoAboutHtml() + "</div>";
  };

  /**
   * What the About card still says for itself.
   *
   * The auto-generated methodology paragraph that used to open this block —
   * project name, significance level, Bonferroni, which test each metric uses,
   * the low-base cut-off, the wave-test exception — was removed on 2026-08-11.
   * It restated in prose what the Statistical diagnostics panel and the
   * How-to-read guide both carry, on a page whose job is the narrative.
   *
   * What survives are the three disclosures that appear ONLY here and only when
   * they apply, none of which is boilerplate:
   *   - synthetic respondent data (prototype builds), which a reader must not
   *     mistake for real fieldwork;
   *   - weighting, which changes how every base on every table should be read;
   *   - the AI attribution, which is what keeps the construction note's promise
   *     that AI-generated report text is labelled and its model named.
   * A stock, unweighted, AI-free report renders nothing at all here.
   */
  function autoAboutHtml() {
    var p = TR.AGG.project;
    var verify = TR.VERIFY || {};
    var ok = verify.other_banners_base_ge_threshold || {};
    var notes = "";
    if (TR.MICRO && TR.MICRO.synthetic) {
      notes += "<p><strong>Synthetic data.</strong> This prototype's respondent " +
        "data is SYNTHETIC, fitted to the published tables (Campus crosses exact; " +
        "other banners mean |error| " +
        (ok.mean_abs_err_pp !== undefined ? ok.mean_abs_err_pp.toFixed(1) : "≈2") +
        "pp on healthy bases). A production build embeds real anonymised data.</p>";
    }
    if (p.weighted) {
      notes += "<p><strong>Weighting.</strong> Figures are weighted" +
        (p.weight_variable ? " using ‘" + fmt.escapeHtml(p.weight_variable) + "’" : "") +
        " so the sample matches the known profile of the population; percentages, means and " +
        "significance are all calculated on the weights. Each table shows the <em>unweighted " +
        "base</em> (the number of people who answered — judge robustness on this), the " +
        "<em>weighted base</em> (the denominator the percentages use) and the <em>effective " +
        "base</em> (the sample's effective size after weighting, on which significance tests " +
        "and confidence intervals are sized, since weighting reduces precision).</p>";
    }
    return (notes ? "<h3>Notes on this report</h3>" + notes : "") +
      TR.ai.methodologyHtml();
  }

  // The statistical diagnostics panel — the interactive twin of the Excel stats
  // pack (project.diagnostics, attached by the R build; a curated subset). A pure
  // function of the island object so it is unit-testable; "" when absent, so old
  // reports (and any build that couldn't attach it) simply omit the panel.
  report.diagnosticsHtml = function () {
    var d = TR.AGG && TR.AGG.project && TR.AGG.project.diagnostics;
    if (!d || typeof d !== "object") return "";
    var esc = fmt.escapeHtml;
    var secs = (d.sections || []).map(function (s) {
      var rows = ((s && s.rows) || []).map(function (r) {
        return "<tr><th>" + esc(r && r[0]) + "</th><td>" + esc(r && r[1]) + "</td></tr>";
      }).join("");
      if (!rows) return "";
      return '<div class="rpt-diag-sec"><h4>' + esc(s.title) + "</h4>" +
        '<table class="rpt-diag-tbl"><tbody>' + rows + "</tbody></table></div>";
    }).join("");
    var w = d.warnings || {};
    var evs = (w.events && typeof w.events.map === "function") ? w.events : [];
    var warn;
    if (!evs.length) {
      warn = '<div class="rpt-diag-sec rpt-diag-warn"><h4>Warnings &amp; events</h4>' +
        '<p class="rpt-diag-clean">✓ ' + esc(w.summary || "No events — ran cleanly") + "</p></div>";
    } else {
      warn = '<div class="rpt-diag-sec rpt-diag-warn"><h4>Warnings &amp; events</h4>' +
        '<table class="rpt-diag-tbl rpt-diag-events"><thead><tr><th>Level</th><th>Code</th>' +
        "<th>Detail</th></tr></thead><tbody>" +
        evs.map(function (e) {
          e = e || {};
          var lvl = String(e.level || "INFO").toUpperCase();
          var cls = lvl === "REFUSE" ? "refuse" : lvl === "PARTIAL" ? "partial" : "info";
          var detail = [e.title, e.message].filter(function (x) { return x && x !== "—"; }).join(" — ");
          return '<tr><td><span class="rpt-diag-lvl ' + cls + '">' + esc(lvl) + "</span></td>" +
            "<td>" + esc(e.code) + "</td><td>" + esc(detail) + "</td></tr>";
        }).join("") + "</tbody></table></div>";
    }
    var st = String(d.status || "PASS").toUpperCase();
    var stCls = st === "PASS" ? "pass" : st === "PARTIAL" ? "partial" : "refuse";
    return '<details class="card rpt-diag"><summary class="rpt-diag-sum">Statistical diagnostics' +
      '<span class="rpt-diag-status ' + stCls + '">' + esc(d.status || "PASS") + "</span></summary>" +
      '<p class="hint">This is the reports diagnostics record.</p>' +
      '<div class="rpt-diag-grid">' + secs + warn + "</div></details>";
  };

  function wire(host) {
    host.addEventListener("input", function (e) {
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
      qualSaved: (TR.qual && TR.qual.savedAll) ? TR.qual.savedAll() : {},
      qualHighlights: (TR.qual && TR.qual.highlightsAll) ? TR.qual.highlightsAll() : {},
      takeout: (TR.takeout && TR.takeout.state && TR.takeout.state.snapshot) ? TR.takeout.state.snapshot() : null,
      report: store()
    };
    // Escape EVERY "<" as the JSON unicode escape, not just the closing-tag
    // form. An HTML comment opener followed by a script opener inside a script
    // island puts the HTML parser into its double-escaped state, after which
    // this island's own closing tag no longer closes it and the following
    // islands plus the JS bundle are swallowed — a blank report. The build side
    // has escaped this way since review 2026-08 (I14, triggered by a respondent
    // pasting an HTML email into an open-end); saveCopy still had the weaker
    // closing-tag-only guard, so an analyst pasting the same markup into an
    // Insight box or an added slide could ship a blank saved copy (review
    // 2026-08-21, I-4). The escape parses back to "<" through JSON.parse.
    //
    // NB: this comment deliberately spells those sequences out in words. The
    // bundler refuses to inline any renderer JS that CONTAINS them literally
    // (CFG_REPORT_V2_JS_EMBED), so writing them here would break every build.
    var json = JSON.stringify(state).replace(/</g, "\\u003c");
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
