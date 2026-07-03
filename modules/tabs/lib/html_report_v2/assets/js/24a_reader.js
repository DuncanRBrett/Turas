/**
 * v2 reader layer — the persistent audience strip (who the numbers describe,
 * on EVERY tab) and the single "How to read this" legend panel that
 * consolidates the scattered per-tab legends (sig letters, ▲▵ arrows, bands,
 * precision, weighted bases). The shell renders both; this module owns the
 * content, the dialog behaviour and the PE-box first-view persistence.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var reader = TR.reader = {};

  /* ---------------- audience strip (A3) ---------------- */

  /** Largest published Total base across questions — the "full sample" figure
   *  when there is no microdata to count (published-only reports, Patterns). */
  function publishedTotalBase() {
    var best = null;
    ((TR.AGG && TR.AGG.questions) || []).forEach(function (q) {
      var b = q.bases && q.bases[0] ? q.bases[0].n : null;
      if (b != null && (best === null || b > best)) best = b;
    });
    return best;
  }
  reader._publishedTotalBase = publishedTotalBase;

  /** Weighted (Σw) + Kish effective base of the live audience — null when the
   *  report is unweighted or carries no per-respondent weights. Mirrors the
   *  accumulation in 21_stats.js (weightAt/effectiveBase are module-private). */
  function weightedAudience(fullSample) {
    var p = (TR.AGG && TR.AGG.project) || {};
    var w = TR.MICRO && TR.MICRO.weights;
    if (!p.weighted || !w) return null;
    var f = fullSample ? null : TR.d2.state.filters;
    var mask = (f && f.length && TR.stats) ? TR.stats.mask(f) : null;
    var sw = 0, sw2 = 0;
    for (var r = 0; r < TR.MICRO.n; r++) {
      if (mask && !mask[r]) continue;
      sw += w[r]; sw2 += w[r] * w[r];
    }
    return { w: sw, eff: sw2 > 0 ? (sw * sw) / sw2 : 0 };
  }
  reader._weightedAudience = weightedAudience;

  /**
   * The strip's HTML for a tab. Reuses the existing state APIs (d2.state,
   * stats.mask/maskCount via disclosure.audienceBase, d2.filterDescription)
   * — never a forked recompute.
   */
  reader.audienceStripHtml = function (tab) {
    var p = (TR.AGG && TR.AGG.project) || {};
    var bits = [];
    var basePart = function (n, fullSample) {
      if (n == null) return "";
      var out = "n=" + fmt.base(n);
      var wa = weightedAudience(fullSample);
      if (wa) {
        out += " · weighted " + fmt.base(wa.w) + " · effective " + fmt.base(wa.eff);
      }
      return out;
    };
    if (tab === "takeout" || tab === "moved") {
      // Patterns + Tracking deliberately ignore the live filter — they read the
      // full published sample (prior waves have no microdata to filter).
      bits.push('<span class="aud-cut">' +
        (tab === "takeout" ? "Patterns reads" : "Tracking shows") +
        ' the <strong>full published sample</strong> — the audience filter does ' +
        "not apply on this tab</span>");
      var pub = TR.d2.hasMicrodata() ? TR.MICRO.n : publishedTotalBase();
      var pubPart = basePart(pub, true);
      if (pubPart) bits.push('<span class="aud-n">' + pubPart + "</span>");
    } else {
      var s = TR.d2.state;
      var cut = s.filters.length ? TR.d2.filterDescription() : "Everyone";
      bits.push('<span class="aud-cut"><strong>' +
        fmt.escapeHtml(TR.charts.clip(cut, 90)) + "</strong></span>");
      if (s.banner && s.banner.indexOf("composite:") === 0) {
        bits.push('<span class="aud-banner">' +
          fmt.escapeHtml(TR.charts.clip(TR.d2.bannerDescription(), 70)) + "</span>");
      }
      var n = (TR.disclosure && TR.disclosure.audienceBase)
        ? TR.disclosure.audienceBase() : null;
      if (n === null) n = publishedTotalBase();
      var nPart = basePart(n);
      if (nPart) bits.push('<span class="aud-n">' + nPart + "</span>");
    }
    if (p.wave) bits.push('<span class="aud-wave">' + fmt.escapeHtml(String(p.wave)) + "</span>");
    return '<span class="aud-label">Audience</span>' + bits.join('<span class="aud-sep">·</span>');
  };

  /** Render the strip into its shell slot (aria-live sits on the container).
   *  The cover is a landing page, not an analysis surface — no strip there
   *  (:empty hides the container). */
  reader.renderStrip = function () {
    if (typeof document === "undefined") return;
    var holder = document.getElementById("audstrip");
    if (!holder) return;
    holder.innerHTML = TR.d2.state.tab === "cover"
      ? "" : reader.audienceStripHtml(TR.d2.state.tab);
  };

  /* ------------- plain-language significance (B2) ------------- */

  var EXPLAIN_KEY = "v2explain_sig";
  var explainCached = null;

  /**
   * Whether plain-language significance is on. The reader's own persisted
   * choice is authoritative once set (ownership: read the existing store
   * first); otherwise saved copies (TR.userState island present) default ON —
   * they go to client readers — and analyst-fresh reports default OFF.
   */
  reader.explainOn = function () {
    if (explainCached !== null) return explainCached;
    var stored = null;
    try {
      if (typeof localStorage !== "undefined") {
        stored = localStorage.getItem(TR.d2.storeKey(EXPLAIN_KEY));
      }
    } catch (e) { /* storage unavailable — fall to the default */ }
    explainCached = stored === null ? !!TR.userState : stored === "1";
    return explainCached;
  };

  reader.setExplain = function (on) {
    explainCached = !!on;
    try {
      if (typeof localStorage !== "undefined") {
        localStorage.setItem(TR.d2.storeKey(EXPLAIN_KEY), on ? "1" : "0");
      }
    } catch (e) { /* storage unavailable — in-memory only */ }
  };

  // Level wording derives from the project's configured alphas (21_stats.js —
  // the one source the tests use), NEVER a hard-coded "95%"/"80%" string.
  function levelText(alpha) { return Math.round((1 - alpha) * 100) + "%"; }
  function primaryLevel() {
    return levelText(TR.stats && TR.stats.alphaPrimary ? TR.stats.alphaPrimary() : 0.05);
  }
  function secondaryLevel() {
    return levelText(TR.stats && TR.stats.alphaSecondary ? TR.stats.alphaSecondary() : 0.20);
  }
  reader._levels = function () {
    return { primary: primaryLevel(), secondary: secondaryLevel() };
  };

  /** The cell's displayed value as text (mean 1dp, % rounded) — null when absent. */
  function valText(kind, cell) {
    if (!cell) return null;
    var v = kind === "mean" ? cell.mean : cell.pct;
    if (v === null || v === undefined) return null;
    return kind === "mean" ? Number(v).toFixed(1) : Math.round(v) + "%";
  }

  function joinList(items) {
    if (items.length <= 1) return items.join("");
    return items.slice(0, -1).join(", ") + " and " + items[items.length - 1];
  }

  /**
   * Plain sentence for a sig-lettered crosstab cell: letters resolve to column
   * labels (and that column's value in the same row) via the model's letter
   * map. Uppercase letters speak at the report's primary level, lowercase at
   * the weaker secondary level. "" when nothing resolvable.
   */
  reader.letterSentence = function (model, row, ci) {
    var cell = row.cells[ci], col = model.columns[ci];
    if (!cell || !cell.sig || !col) return "";
    var own = valText(row.kind, cell);
    if (own === null) return "";
    var byLetter = {};
    model.columns.forEach(function (c, i) {
      if (c.letter) byLetter[String(c.letter).toUpperCase()] = i;
    });
    var refs = function (chars) {
      var out = [];
      chars.forEach(function (ch) {
        var ti = byLetter[ch.toUpperCase()];
        if (ti === undefined) return;
        var tv = valText(row.kind, row.cells[ti]);
        out.push(model.columns[ti].label + (tv === null ? "" : " (" + tv + ")"));
      });
      return out;
    };
    var hi = [], lo = [];
    String(cell.sig).split("").forEach(function (ch) {
      if (!/[a-z]/i.test(ch)) return;
      (ch === ch.toUpperCase() ? hi : lo).push(ch);
    });
    var hiRefs = refs(hi), loRefs = refs(lo);
    var head = col.label + " (" + own + ")";
    if (hiRefs.length && loRefs.length) {
      return head + " is meaningfully higher than " + joinList(hiRefs) +
        " at the report's " + primaryLevel() + " level. It is also higher than " +
        joinList(loRefs) + " at the weaker " + secondaryLevel() + " level (directional).";
    }
    if (hiRefs.length) {
      return head + " is meaningfully higher than " + joinList(hiRefs) +
        " at the report's " + primaryLevel() + " level.";
    }
    if (loRefs.length) {
      return head + " is higher than " + joinList(loRefs) + " at the weaker " +
        secondaryLevel() + " level (directional) — not at the report's " +
        primaryLevel() + " level.";
    }
    return "";
  };

  /** Plain sentence for a composite (vs-the-rest) arrow cell: ▲▼ at the
   *  primary level, hollow ▵▿ at the weaker secondary level. */
  reader.arrowSentence = function (model, row, ci) {
    var cell = row.cells[ci], col = model.columns[ci];
    if (!cell || !cell.sig || !col) return "";
    var sig = String(cell.sig);
    if (!/[▲▼▵▿]/.test(sig)) return "";
    var own = valText(row.kind, cell);
    if (own === null) return "";
    var dir = /[▼▿]/.test(sig) ? "lower" : "higher";
    var head = col.label + " (" + own + ")";
    return /[▲▼]/.test(sig)
      ? head + " is meaningfully " + dir + " than the rest of the sample at the report's " +
        primaryLevel() + " level."
      : head + " is " + dir + " than the rest of the sample at the weaker " +
        secondaryLevel() + " level (directional).";
  };

  /** Plain sentence for a Δ (wave-change) chip, from the delta the model
   *  already carries (current value = prev + diff, wave named from the data). */
  reader.deltaSentence = function (delta) {
    if (!delta || delta.diff === null || delta.diff === undefined) return "";
    var f = function (v) {
      return delta.isMean ? Number(v).toFixed(1) : Math.round(v) + "%";
    };
    var cur = f(delta.prev + delta.diff), prev = f(delta.prev);
    var wave = String(delta.wave || delta.year || "the prior wave");
    var dir = delta.diff >= 0 ? "higher" : "lower";
    return delta.sig
      ? "This wave (" + cur + ") is meaningfully " + dir + " than " + wave +
        " (" + prev + ") at the report's " + primaryLevel() + " level."
      : "This wave (" + cur + ") is " + dir + " than " + wave + " (" + prev +
        "), but the change is within the survey's noise — not significant at the report's " +
        primaryLevel() + " level.";
  };

  /* ------------- insight titles on cards (B3) ------------- */

  /** First sentence of an analyst note (first line, cut at .!? + space/end). */
  function firstSentence(text) {
    var t = String(text || "").trim().split(/\n/)[0].trim();
    var m = t.match(/^.*?[.!?](?=\s|$)/);
    return (m ? m[0] : t).trim();
  }

  /**
   * The one-line insight title for a question's card / header. The analyst
   * headline (Comments-sheet Headline column, q.headline) always wins; absent
   * that, the first sentence of a stored analyst insight (28_insights.js —
   * clearly marked by the caller via source:"insight"); otherwise null — this
   * bundle never auto-generates a sentence.
   */
  reader.insightTitle = function (q, banner) {
    if (!q) return null;
    if (typeof q.headline === "string" && q.headline.trim()) {
      return { text: q.headline.trim(), source: "headline" };
    }
    var note = (TR.insights && TR.insights.get) ? TR.insights.get(q.code, banner || null) : "";
    if (note) {
      var first = firstSentence(note);
      if (first) return { text: first, source: "insight" };
    }
    return null;
  };

  /* ---------------- exec-summary cover (D1) ---------------- */

  /** The cover's leading findings: the first 3–5 story items carrying
   *  evidence (dividers are structure, not findings). */
  reader.coverFindings = function () {
    var items = (TR.story2 && TR.story2.items) ? TR.story2.items() : [];
    return items.filter(function (it) { return it.kind !== "divider"; }).slice(0, 5);
  };

  /**
   * The cover opens only on a saved/shared copy (user-state island present)
   * that carries story content: story pins (incl. promoted hub insights)
   * and/or an authored Report-tab executive summary / background section.
   * Analyst-fresh reports keep today's landing exactly.
   */
  reader.coverAvailable = function () {
    if (!TR.userState) return false;
    if (reader.coverFindings().length) return true;
    var rpt = TR.report;
    if (!rpt || !rpt.sectionText) return false;
    return !!(String(rpt.sectionText("exec") || "").trim() ||
      String(rpt.sectionText("background") || "").trim());
  };

  /** Where "Explore the dashboard →" lands: the first READ tab (dashboard
   *  unless flag-gated off) — never a hard-coded id. */
  reader.exploreTarget = function () {
    return TR.shell.tabGroups()[0].tabs[0][0];
  };

  function coverParas(text) {
    return String(text).trim().split(/\n+/).map(function (p) {
      return "<p>" + fmt.escapeHtml(p) + "</p>";
    }).join("");
  }

  /**
   * The cover page: report title/client/wave, the analyst headline sections
   * (Report-tab executive summary / background when authored), then the
   * leading findings — each story pin as its insight sentence (pin title)
   * over a compact evidence thumbnail. Thumbnails re-use each pin's own
   * renderer (story2.itemBodyHtml), so disclosure gates travel with the pin
   * — never re-derived here.
   */
  reader.coverHtml = function () {
    var p = (TR.AGG && TR.AGG.project) || {};
    var sub = [p.client, p.wave].filter(Boolean).map(function (x) {
      return fmt.escapeHtml(String(x));
    }).join(" · ");
    var explore = '<button class="primary cover-explore" data-cover-explore>' +
      "Explore the dashboard →</button>";
    var html = ['<div class="page cover">'];
    html.push('<div class="card cover-head">' +
      '<div class="cover-kicker">Report cover</div>' +
      "<h1>" + fmt.escapeHtml(p.name || "") + "</h1>" +
      (sub ? '<div class="cover-sub">' + sub + "</div>" : "") + explore + "</div>");
    var rpt = TR.report;
    [["exec", "Executive summary"], ["background", "Background & method"]]
      .forEach(function (sec) {
        var text = (rpt && rpt.sectionText)
          ? String(rpt.sectionText(sec[0]) || "").trim() : "";
        if (!text) return;
        html.push('<div class="card cover-sec"><h3>' + sec[1] + "</h3>" +
          coverParas(text) + "</div>");
      });
    var findings = reader.coverFindings();
    if (findings.length) {
      html.push('<h2 class="cover-h2">Leading findings</h2>');
      findings.forEach(function (item, i) {
        html.push('<div class="card cover-finding">' +
          '<h3 class="cf-title"><span class="cf-n">' + (i + 1) + "</span> " +
          fmt.escapeHtml(TR.story2.pinTitle(item)) + "</h3>" +
          '<div class="cover-thumb">' + TR.story2.itemBodyHtml(item) +
          "</div></div>");
      });
      html.push('<div class="card cover-foot">' + explore + "</div>");
    }
    html.push("</div>");
    return html.join("");
  };

  /** Render the cover route into the tab host. */
  reader.renderCover = function (host) {
    var wrap = document.createElement("div");
    wrap.innerHTML = reader.coverHtml();
    host.replaceChildren(wrap);
    // fresh wrapper per render — the listener dies with the node
    wrap.addEventListener("click", function (e) {
      if (e.target.closest("[data-cover-explore]")) {
        TR.shell.goTab(reader.exploreTarget());
      }
    });
  };

  /* ---------------- "How to read this" panel (A4) ---------------- */

  /** The consolidated legend: sig letters (incl. lowercase 80%), ▲▵ arrows,
   *  strong/moderate/weak bands, the precision estimate, weighted bases. */
  reader.legendHtml = function () {
    var p = (TR.AGG && TR.AGG.project) || {};
    var labels = TR.conf.labels();
    var lowBase = p.low_base_threshold;
    var sections = [];
    sections.push("<h3>Significance letters</h3><ul>" +
      "<li><strong>▲ letters</strong> (e.g. <sup>B</sup>) — this value is significantly " +
      "higher than that lettered column. UPPERCASE letters = 95% confidence; with the " +
      "80% option on, <strong>lowercase letters = 80%</strong> (directional, weaker evidence).</li>" +
      (lowBase ? "<li><strong>⚠ low base</strong> — fewer than " + lowBase +
        " respondents; excluded from significance testing.</li>" : "") + "</ul>");
    sections.push("<h3>Arrows &amp; change chips</h3><ul>" +
      "<li><strong>▲ / ▼</strong> on a composite (profile) column — significantly above / " +
      "below <em>the rest of the sample</em> at 95%; hollow <strong>▵ / ▿</strong> mark the " +
      "80% level. Composite columns may overlap, so they are never compared with one another.</li>" +
      "<li><strong>▲ / ▼ chips</strong> on a Total column or card — change vs the most recent " +
      "prior wave carrying that question; an outlined chip is a significant change.</li></ul>");
    sections.push("<h3>Score bands</h3><ul>" +
      "<li>Index cards and heatmap cells band by % of each scale's maximum: " +
      "<strong>strong ≥75%</strong> · <strong>moderate 50–74%</strong> · " +
      "<strong>weak &lt;50%</strong> — the band is always written or bordered, " +
      "never colour alone.</li>" +
      "<li><strong>NET rows</strong> (navy edge) combine categories; <strong>Index rows</strong> " +
      "(gold edge) are score-weighted means.</li></ul>");
    var pub = publishedTotalBase() || (TR.MICRO && TR.MICRO.n);
    sections.push("<h3>" + fmt.escapeHtml(labels.moe_name) + " (" +
      fmt.escapeHtml(labels.moe_abbrev) + ")</h3><ul>" +
      "<li>Every number is an estimate, not an exact count" +
      (pub ? ": at n=" + fmt.base(pub) + ", overall percentages are stable to about ±" +
        TR.conf.maxMoePct(pub).toFixed(1) + "pp; smaller cuts swing more" : "") +
      ". The full working sits under “How sure can I be of these numbers?” on the " +
      "Crosstabs tab.</li></ul>");
    if (p.weighted) {
      // single source of truth for the weighted-bases explainer
      var wnote = (TR.filterBar && TR.filterBar.weightingNote)
        ? TR.filterBar.weightingNote() : "";
      sections.push("<h3>Weighted data</h3>" +
        (wnote || "<ul><li>Figures are weighted; significance uses the effective base.</li></ul>"));
    }
    // B2 toggle: the same preference as the compact "Explain" control on the
    // crosstabs sig-mode bar (one persisted store behind both).
    sections.push("<h3>Explain significance</h3>" +
      '<label class="xpl-toggle"><input type="checkbox" data-explain-toggle' +
      (reader.explainOn() ? " checked" : "") + "> Explain significance in plain " +
      "language — hover or focus any significance letter, arrow or Δ chip for a " +
      "sentence saying what it means.</label>");
    return sections.join("");
  };

  reader.openLegend = function () {
    if (typeof document === "undefined") return;
    reader.closeLegend();
    var overlay = document.createElement("div");
    overlay.id = "legend-overlay";
    overlay.className = "legend-overlay";
    // lives INSIDE #app so saveCopy (which empties #app in its clone) can
    // never bake an open dialog into a saved copy
    var host = document.getElementById("app") || document.body;
    overlay.innerHTML = '<div class="legend-panel" role="dialog" aria-modal="true" ' +
      'aria-label="How to read this report">' +
      '<div class="legend-head"><h2>ⓘ How to read this report</h2>' +
      '<button class="legend-close" data-legend-close aria-label="Close">✕</button></div>' +
      '<div class="legend-body">' + reader.legendHtml() + "</div></div>";
    host.appendChild(overlay);
    var panel = overlay.firstChild;
    var restoreFocus = document.activeElement;
    // B2 toggle lives in the dialog; flipping it re-renders the live tab so
    // every sig marker gains/drops its plain-language tooltip immediately.
    overlay.addEventListener("change", function (e) {
      if (e.target && e.target.hasAttribute && e.target.hasAttribute("data-explain-toggle")) {
        reader.setExplain(e.target.checked);
        if (TR.shell && TR.shell.route) TR.shell.route();
      }
    });
    overlay.addEventListener("click", function (e) {
      if (e.target === overlay || e.target.closest("[data-legend-close]")) {
        reader.closeLegend();
        if (restoreFocus && restoreFocus.focus) restoreFocus.focus();
      }
    });
    // focus trap + Esc — listeners die with the overlay node
    overlay.addEventListener("keydown", function (e) {
      if (e.key === "Escape") {
        reader.closeLegend();
        if (restoreFocus && restoreFocus.focus) restoreFocus.focus();
        return;
      }
      if (e.key !== "Tab") return;
      var focusables = panel.querySelectorAll(
        "button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])");
      if (!focusables.length) return;
      var first = focusables[0], last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault(); last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault(); first.focus();
      }
    });
    overlay.querySelector("[data-legend-close]").focus();
  };

  reader.closeLegend = function () {
    if (typeof document === "undefined") return;
    var open = document.getElementById("legend-overlay");
    if (open) open.remove();
  };

  /* ------------- PE-box first-view persistence (A4) ------------- */

  var PE_KEY = "v2pe_seen";
  var peSeenAtBoot = null;   // session-stable: collapse only from the NEXT session

  /**
   * Whether the dashboard's precision box should render collapsed (to the ⓘ).
   * First call reads the persisted flag, then marks it seen — so the box stays
   * expanded for the WHOLE first session and collapses on later ones. Local
   * per-report UI state only (d2.storeKey namespace): deliberately NOT baked
   * into saved copies, so every recipient gets one full first view too.
   */
  reader.peCollapsed = function () {
    if (peSeenAtBoot === null) {
      var seen = false;
      try {
        seen = typeof localStorage !== "undefined" &&
          localStorage.getItem(TR.d2.storeKey(PE_KEY)) === "1";
        if (!seen && typeof localStorage !== "undefined") {
          localStorage.setItem(TR.d2.storeKey(PE_KEY), "1");
        }
      } catch (e) { /* storage unavailable (file:// privacy modes) — stay expanded */ }
      peSeenAtBoot = seen;
    }
    return peSeenAtBoot;
  };

})(typeof window !== "undefined" ? window : globalThis);
