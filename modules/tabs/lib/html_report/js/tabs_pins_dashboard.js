/**
 * TURAS Tabs Report — Dashboard Pin Types & Qualitative Slides
 *
 * Handles dashboard-specific pin types (text boxes, gauge sections,
 * significant findings) and qualitative slide management.
 * All pin creation delegates to TurasPins.add().
 *
 * Depends on: TurasPins shared library, tabs_pins.js (loaded before this)
 */

/* global TurasPins, BRAND_COLOUR, escapeHtml */

(function() {
  "use strict";

  // ── Embedded CSS for portable pin rendering ───────────────────────────────

  /**
   * Wrap dashboard HTML with embedded CSS so it renders correctly outside
   * the tabs report's stylesheet context (e.g., in the hub combined report).
   * Same pattern as conjoint's _wrapSimulatorStyles().
   * @param {string} html - Raw dashboard section innerHTML
   * @returns {string} HTML with embedded <style> block
   */
  function _wrapDashboardStyles(html) {
    var brand = "var(--brand-colour, #323367)";
    try { brand = getComputedStyle(document.documentElement).getPropertyValue("--brand-colour").trim() || "#323367"; } catch (e) {}
    var css =
      ".dash-gauges{display:flex;flex-wrap:wrap;gap:16px;margin-bottom:16px}" +
      ".dash-gauge-card{background:#fff;border-radius:8px;border:1px solid #e2e8f0;" +
        "padding:14px 16px;min-width:170px;flex:1;max-width:240px;text-align:center;position:relative}" +
      ".dash-gauge-hero{max-width:480px;min-width:300px;display:flex;flex-direction:row;" +
        "align-items:center;gap:20px;padding:16px 24px;text-align:left}" +
      ".dash-gauge-hero svg{flex-shrink:0}" +
      ".dash-gauge-hero .dash-gauge-label{font-size:13px;margin-top:0}" +
      ".dash-gauge-label{font-size:11px;color:#1e293b;margin-top:6px;line-height:1.4;" +
        "white-space:normal;word-wrap:break-word}" +
      ".dash-gauge-qcode{font-size:10px;font-weight:700;color:" + brand + ";margin-right:4px}" +
      ".dash-gauge-value{font-size:24px;font-weight:700;color:#1e293b}" +
      ".dash-type-badge{display:inline-block;font-size:9px;font-weight:700;" +
        "padding:2px 8px;border-radius:3px;letter-spacing:0.5px;margin-bottom:6px}" +
      ".dash-type-net_positive{background:rgba(74,124,111,0.1);color:#4a7c6f}" +
      ".dash-type-nps_score{background:rgba(50,51,103,0.1);color:" + brand + "}" +
      ".dash-type-average{background:rgba(201,169,110,0.1);color:#96783a}" +
      ".dash-type-index{background:rgba(99,102,241,0.1);color:#4f46e5}" +
      ".dash-type-custom{background:rgba(100,116,139,0.1);color:#475569}" +
      ".dash-callout-badge{position:absolute;top:6px;right:6px;font-size:9px;font-weight:700;" +
        "padding:2px 8px;border-radius:10px;letter-spacing:0.3px}" +
      ".dash-callout-best{background:rgba(74,124,111,0.12);color:#4a7c6f;border:1px solid rgba(74,124,111,0.25)}" +
      ".dash-callout-worst{background:rgba(184,84,80,0.10);color:#b85450;border:1px solid rgba(184,84,80,0.25)}" +
      ".dash-section-title{font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px}" +
      ".dash-sig-card{background:#fff;border-radius:8px;border:1px solid #e2e8f0;padding:12px 16px;margin-bottom:8px}" +
      ".dash-sig-text{font-size:13px;color:#334155;line-height:1.5}" +
      ".dash-sig-grid{display:flex;flex-wrap:wrap;gap:8px}";
    return '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;"><style>' + css + '</style>' + html + '</div>';
  }

  // ── Dashboard Text Pin ────────────────────────────────────────────────────

  /**
   * Pin executive summary or background text box.
   * @param {string} boxId - "background" or "exec-summary"
   */
  window.pinDashboardText = function(boxId) {
    var content = document.getElementById("dash-text-" + boxId);
    var mdEditor = content ? content.querySelector(".dash-md-editor") : null;
    var text = mdEditor ? mdEditor.value.trim() : "";
    if (!text) { alert("Please enter text before pinning."); return; }

    var title = boxId === "background" ? "Background & Method" : "Executive Summary";
    TurasPins.add({
      pinType: "text_box",
      qCode: null, qTitle: title, title: title,
      insightText: text,
      tableHtml: null, chartSvg: null, baseText: null
    });
  };

  // ── Gauge Section Pin ─────────────────────────────────────────────────────

  /**
   * Pin a gauge section (Index, NPS Score, etc.).
   * @param {string} sectionId - Section ID suffix (e.g. "index", "nps-score")
   */
  window.pinGaugeSection = function(sectionId) {
    var section = document.getElementById("dash-sec-" + sectionId);
    if (!section) return;

    var gauges = section.querySelectorAll(".dash-gauge-card:not(.dash-gauge-excluded)");
    if (gauges.length === 0) return;

    var titleEl = section.querySelector(".dash-section-title");
    var sectionTitle = titleEl ? titleEl.childNodes[0].textContent.trim() : sectionId;

    var clone = section.cloneNode(true);
    clone.querySelectorAll(".dash-export-btn, .dash-sort-btn, .dash-slide-export-btn")
      .forEach(function(btn) { btn.remove(); });
    clone.querySelectorAll(".dash-tier-pill").forEach(function(pill) { pill.remove(); });
    clone.querySelectorAll(".dash-gauge-excluded").forEach(function(g) { g.remove(); });

    TurasPins.add({
      pinType: "dashboard_section",
      qCode: null, qTitle: sectionTitle, title: sectionTitle,
      tableHtml: _wrapDashboardStyles(clone.innerHTML),
      insightText: null, chartSvg: null, baseText: null
    });
  };

  // ── Significant Findings ──────────────────────────────────────────────────

  /** Alias for pinVisibleSigFindings. */
  window.pinSigFindings = function() { window.pinVisibleSigFindings(); };

  /** Toggle visibility of a sig finding card. */
  window.toggleSigCard = function(sigId) {
    var card = document.querySelector('.dash-sig-card[data-sig-id="' + sigId + '"]');
    if (!card) return;
    card.classList.toggle("sig-hidden");
    window.saveSigCardStates();
  };

  /** Pin a single sig finding card. */
  window.pinSigCard = function(sigId) {
    var card = document.querySelector('.dash-sig-card[data-sig-id="' + sigId + '"]');
    if (!card || card.classList.contains("sig-hidden")) return;
    var clone = card.cloneNode(true);
    var actions = clone.querySelector(".sig-card-actions");
    if (actions) actions.remove();
    clone.classList.remove("sig-hidden");

    var textEl = clone.querySelector(".dash-sig-text");
    var title = textEl ? textEl.textContent.substring(0, 80) : "Sig Finding";

    TurasPins.add({
      pinType: "dashboard_section",
      qCode: null, qTitle: "Sig Finding: " + title, title: "Sig Finding: " + title,
      tableHtml: _wrapDashboardStyles(clone.outerHTML),
      insightText: null, chartSvg: null, baseText: null
    });
  };

  /** Pin all visible (non-hidden) sig finding cards. */
  window.pinVisibleSigFindings = function() {
    var section = document.getElementById("dash-sec-sig-findings");
    if (!section) return;
    var allVisible = section.querySelectorAll(".dash-sig-card:not(.sig-hidden)");
    if (allVisible.length === 0) return;

    var visible = Array.from(allVisible).filter(function(card) {
      return card.style.display !== "none";
    });
    if (visible.length === 0) return;

    var wrapper = document.createElement("div");
    wrapper.className = "dash-sig-grid";
    visible.forEach(function(card) {
      var clone = card.cloneNode(true);
      var actions = clone.querySelector(".sig-card-actions");
      if (actions) actions.remove();
      wrapper.appendChild(clone);
    });

    TurasPins.add({
      pinType: "dashboard_section",
      qCode: null, qTitle: "Significant Findings", title: "Significant Findings",
      tableHtml: _wrapDashboardStyles(wrapper.outerHTML),
      insightText: null, chartSvg: null, baseText: null
    });
  };

  /** Persist sig card toggle states to hidden JSON store. */
  window.saveSigCardStates = function() {
    var store = document.getElementById("sig-card-states");
    if (!store) return;
    var states = {};
    document.querySelectorAll(".dash-sig-card[data-sig-id]").forEach(function(card) {
      if (card.classList.contains("sig-hidden")) {
        states[card.getAttribute("data-sig-id")] = true;
      }
    });
    store.textContent = JSON.stringify(states);
  };

  /** Restore sig card toggle states from hidden JSON store. */
  window.hydrateSigCardStates = function() {
    var store = document.getElementById("sig-card-states");
    if (!store || !store.textContent || store.textContent === "{}") return;
    try {
      var states = JSON.parse(store.textContent);
      for (var sigId in states) {
        if (states[sigId]) {
          var card = document.querySelector('.dash-sig-card[data-sig-id="' + sigId + '"]');
          if (card) card.classList.add("sig-hidden");
        }
      }
    } catch(e) { /* corrupt data — skip silently */ }
  };

  /** Filter sig finding cards by banner group (segment). */
  window.filterSigBySegment = function(segment) {
    var cards = document.querySelectorAll(".dash-sig-card");
    var visibleCount = 0;
    for (var i = 0; i < cards.length; i++) {
      var cardSeg = cards[i].getAttribute("data-segment");
      if (segment === "all" || cardSeg === segment) {
        cards[i].style.display = "";
        visibleCount++;
      } else {
        cards[i].style.display = "none";
      }
    }
    var emptyMsg = document.getElementById("sig-filter-empty");
    if (emptyMsg) emptyMsg.style.display = visibleCount === 0 ? "" : "none";
  };

  // ── Markdown Renderer ─────────────────────────────────────────────────────

  /**
   * Lightweight markdown renderer.
   * Handles: **bold**, *italic*, ## headings, > blockquotes, - bullets, paragraphs.
   */
  window.renderMarkdown = function(md) {
    if (!md) return "";
    var html = md
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/^## (.+)$/gm, "<h2>$1</h2>")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>")
      .replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>")
      .replace(/^- (.+)$/gm, "<li>$1</li>");
    html = html.replace(/((?:<li>.*<\/li>\s*)+)/g, function(match) {
      return "<ul>" + match + "</ul>";
    });
    html = html.replace(/<\/blockquote>\s*<blockquote>/g, "<br>");
    html = html.split("\n").map(function(line) {
      var trimmed = line.trim();
      if (!trimmed) return "";
      if (/^<(h2|ul|li|blockquote)/.test(trimmed)) return trimmed;
      return "<p>" + trimmed + "</p>";
    }).join("\n");
    return html;
  };

  /** Strip markdown syntax for plain-text contexts (SVG export). */
  window.stripMarkdown = function(md) {
    if (!md) return "";
    return md
      .replace(/\*\*(.+?)\*\*/g, "$1")
      .replace(/\*(.+?)\*/g, "$1")
      .replace(/^## /gm, "")
      .replace(/^> /gm, "")
      .replace(/^- /gm, "\u2022 ");
  };

})();
