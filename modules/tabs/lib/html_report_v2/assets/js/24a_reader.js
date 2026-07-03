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

  /** Render the strip into its shell slot (aria-live sits on the container). */
  reader.renderStrip = function () {
    if (typeof document === "undefined") return;
    var holder = document.getElementById("audstrip");
    if (!holder) return;
    holder.innerHTML = reader.audienceStripHtml(TR.d2.state.tab);
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
