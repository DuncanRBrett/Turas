/**
 * TURAS Tabs Report — Print Overlay & Sig Findings Export
 *
 * Print overlay builds a temporary A4 landscape layout with one pin per page,
 * triggers window.print(), then cleans up. Sig findings export renders
 * finding cards as paginated SVG→PNG slides.
 *
 * Depends on: TurasPins shared library, tabs_pins.js, tabs_pins_dashboard.js
 */

/* global TurasPins, BRAND_COLOUR, escapeHtml, renderMarkdown, stripMarkdown */

(function() {
  "use strict";

  // ── Print Pinned Views to PDF ─────────────────────────────────────────────

  /**
   * Build a temporary print overlay with one pinned view per page.
   * Triggers window.print() then restores DOM.
   */
  window.printPinnedViews = function() {
    var pins = TurasPins.getAll();
    var pinCount = TurasPins.getPinCount();
    if (pinCount === 0) {
      alert("No pinned views to print. Pin questions from the Crosstabs tab first.");
      return;
    }

    var overlay = document.createElement("div");
    overlay.id = "pinned-print-overlay";
    overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:white;overflow:auto;";

    var printStyle = document.createElement("style");
    printStyle.id = "pinned-print-style";
    printStyle.textContent = buildPrintCSS();
    document.head.appendChild(printStyle);

    // Project info strip
    var projectTitle = document.querySelector(".header-title");
    var pTitle = projectTitle ? projectTitle.textContent : "Report";
    var headerBadges = extractHeaderBadges();
    var statsLine = headerBadges.join("  \u00B7  ");

    var projStrip = document.createElement("div");
    projStrip.className = "pinned-print-project-strip";
    projStrip.innerHTML = '<div style="font-size:14px;font-weight:700;color:' + BRAND_COLOUR + ';">' +
      escapeHtml(pTitle) + '</div>' +
      (statsLine ? '<div style="font-size:10px;color:#64748b;margin-top:2px;">' + escapeHtml(statsLine) + '</div>' : '');
    overlay.appendChild(projStrip);

    // Build one page per pin
    var printIdx = 0;
    for (var i = 0; i < pins.length; i++) {
      var pin = pins[i];
      if (pin.type === "section") {
        overlay.appendChild(buildSectionStrip(pin));
        continue;
      }
      printIdx++;
      overlay.appendChild(buildPrintPage(pin, printIdx, pinCount));
    }

    document.body.appendChild(overlay);
    triggerPrint();
  };

  /** Extract header badge texts from the report banner. */
  function extractHeaderBadges() {
    var badges = [];
    var dateBadge = document.getElementById("header-date-badge");
    if (dateBadge && dateBadge.parentNode) {
      var children = dateBadge.parentNode.children;
      for (var i = 0; i < children.length; i++) {
        if (children[i].style.height) continue;
        var txt = children[i].textContent.trim();
        if (txt) badges.push(txt);
      }
    }
    return badges;
  }

  /** Build a section heading strip for print. */
  function buildSectionStrip(pin) {
    var el = document.createElement("div");
    el.style.cssText = "padding:16px 0 8px;margin:8px 0;border-bottom:2px solid " +
      BRAND_COLOUR + ";font-size:16px;font-weight:600;color:" + BRAND_COLOUR + ";";
    el.textContent = pin.title || "Untitled Section";
    return el;
  }

  /** Build a single print page for a pin. */
  function buildPrintPage(pin, pageNum, totalPages) {
    var page = document.createElement("div");
    page.className = "pinned-print-page";

    // Header
    var hdr = document.createElement("div");
    hdr.className = "pinned-print-header";
    if (pin.pinType === "text_box" || pin.pinType === "heatmap") {
      hdr.innerHTML = '<div class="pinned-print-title">' + escapeHtml(pin.qTitle || pin.title || "") + '</div>';
    } else {
      hdr.innerHTML =
        '<div class="pinned-print-qcode">' + escapeHtml(pin.qCode || "") + '</div>' +
        '<div class="pinned-print-title">' + escapeHtml(pin.qTitle || pin.title || "") + '</div>' +
        '<div class="pinned-print-meta">Banner: ' + escapeHtml(pin.bannerLabel || "") +
        (pin.baseText ? " \u00B7 Base: " + escapeHtml(pin.baseText) : "") + '</div>';
    }
    page.appendChild(hdr);

    var mode = pin.pinMode || "all";
    var showTable = (mode === "all" || mode === "table_insight");
    var showChart = (mode === "all" || mode === "chart_insight");

    // Insight
    if (pin.insightText) {
      var insDiv = document.createElement("div");
      insDiv.className = "pinned-print-insight";
      if (pin.pinType === "text_box") {
        insDiv.style.cssText = "font-size:13px;line-height:1.7;font-weight:400;border-left:none;" +
          "background:#f8fafc;padding:12px 16px;border-radius:6px;white-space:pre-wrap;";
      }
      insDiv.innerHTML = pin.pinType === "text_box" ? pin.insightText : renderMarkdown(pin.insightText);
      page.appendChild(insDiv);
    }

    // Image
    if (pin.imageData) {
      var imgDiv = document.createElement("div");
      imgDiv.style.cssText = "margin-bottom:12px;text-align:center;";
      var imgEl = document.createElement("img");
      imgEl.src = pin.imageData;
      imgEl.style.cssText = "max-width:100%;max-height:400px;border-radius:6px;";
      imgDiv.appendChild(imgEl);
      page.appendChild(imgDiv);
    }

    // Chart
    if (showChart && pin.chartSvg) {
      var chartDiv = document.createElement("div");
      chartDiv.className = "pinned-print-chart";
      chartDiv.innerHTML = pin.chartSvg;
      page.appendChild(chartDiv);
    }

    // Table
    if (showTable && pin.tableHtml) {
      var tableDiv = document.createElement("div");
      tableDiv.className = "pinned-print-table";
      tableDiv.innerHTML = pin.tableHtml;
      page.appendChild(tableDiv);
    }

    // Page number
    var pgNum = document.createElement("div");
    pgNum.className = "pinned-print-page-num";
    pgNum.textContent = pageNum + " of " + totalPages;
    page.appendChild(pgNum);

    return page;
  }

  /** Build print CSS rules. */
  function buildPrintCSS() {
    return '@page { size: A4 landscape; margin: 10mm 12mm; } ' +
      '@media print { ' +
      'body > *:not(#pinned-print-overlay) { display: none !important; } ' +
      '#pinned-print-overlay { position: static !important; overflow: visible !important; } ' +
      '.pinned-print-page { page-break-after: always; padding: 12px 0; } ' +
      '.pinned-print-page:last-child { page-break-after: auto; } ' +
      '.pinned-print-qcode { font-size: 13px; font-weight: 700; color: ' + BRAND_COLOUR + '; } ' +
      '.pinned-print-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 2px 0; } ' +
      '.pinned-print-meta { font-size: 11px; color: #64748b; } ' +
      '.pinned-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid ' + BRAND_COLOUR + '; ' +
      '  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; color: #1a2744; line-height: 1.5; ' +
      '  -webkit-print-color-adjust: exact; print-color-adjust: exact; } ' +
      '.pinned-print-chart svg { width: 100%; height: auto; max-height: 300px; } ' +
      '.pinned-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } ' +
      '.pinned-print-table th, .pinned-print-table td { padding: 4px 8px; border: 1px solid #ddd; } ' +
      '.pinned-print-table th { background: #f1f5f9; font-weight: 600; font-size: 12px; -webkit-print-color-adjust: exact; } ' +
      '.pinned-print-page-num { text-align: right; font-size: 9px; color: #94a3b8; margin-top: 4px; } ' +
      '.pinned-print-project-strip { padding: 0 0 8px 0; margin-bottom: 12px; border-bottom: 2px solid ' + BRAND_COLOUR + '; ' +
      '  page-break-after: avoid; -webkit-print-color-adjust: exact; } ' +
      '} ' +
      '@media screen { ' +
      '#pinned-print-overlay .pinned-print-page { max-width: 900px; margin: 20px auto; padding: 32px; ' +
      '  border: 1px solid #e2e8f0; border-radius: 8px; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); } ' +
      '.pinned-print-project-strip { padding: 12px 32px 8px 32px; margin-bottom: 12px; border-bottom: 2px solid ' + BRAND_COLOUR + '; } ' +
      '}';
  }

  /** Trigger print with cleanup handlers. */
  function triggerPrint() {
    var cleaned = false;
    function cleanup() {
      if (cleaned) return;
      cleaned = true;
      window.removeEventListener("afterprint", cleanup);
      var ov = document.getElementById("pinned-print-overlay");
      if (ov) ov.remove();
      var ps = document.getElementById("pinned-print-style");
      if (ps) ps.remove();
    }
    window.addEventListener("afterprint", cleanup);
    setTimeout(function() {
      window.print();
      setTimeout(function() { if (!cleaned) cleanup(); }, 2000);
    }, 300);
  }

  // ── Sig Findings Slide Export ──────────────────────────────────────────────

  /**
   * Export significant findings section as paginated SVG→PNG slides.
   * 12 cards per slide, brand header, finding text + badges.
   */
  window.exportSigFindingsSlide = function() {
    var section = document.getElementById("dash-sec-sig-findings");
    if (!section) return;
    var allCards = section.querySelectorAll(".dash-sig-card");
    var cards = Array.from(allCards).filter(function(card) {
      return card.style.display !== "none" && !card.classList.contains("sig-hidden");
    });
    if (cards.length === 0) { alert("No significant findings to export."); return; }

    var summaryPanel = document.getElementById("tab-summary");
    var projectTitle = summaryPanel ? (summaryPanel.getAttribute("data-project-title") || "") : "";
    var fieldwork = summaryPanel ? (summaryPanel.getAttribute("data-fieldwork") || "") : "";
    var companyName = summaryPanel ? (summaryPanel.getAttribute("data-company") || "") : "";
    var brandColour = summaryPanel ? (summaryPanel.getAttribute("data-brand-colour") || BRAND_COLOUR) : BRAND_COLOUR;

    var ns = "http://www.w3.org/2000/svg";
    var font = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
    var W = 1000, pad = 30;
    var HEADER_H = 48, TITLE_H = 30, FOOTER_H = 30;
    var CARD_H = 64, CARD_GAP = 6;
    var MAX_PER_SLIDE = 12;
    var slideCount = Math.ceil(cards.length / MAX_PER_SLIDE);

    for (var si = 0; si < slideCount; si++) {
      var slideCards = Array.from(cards).slice(si * MAX_PER_SLIDE, (si + 1) * MAX_PER_SLIDE);
      var gridH = slideCards.length * (CARD_H + CARD_GAP);
      var totalH = HEADER_H + pad + TITLE_H + gridH + pad + FOOTER_H;

      var svg = document.createElementNS(ns, "svg");
      svg.setAttribute("xmlns", ns);
      svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
      svg.setAttribute("style", "font-family:" + font + ";");

      appendRect(svg, ns, 0, 0, W, totalH, "#ffffff");
      appendRect(svg, ns, 0, 0, W, HEADER_H, brandColour);

      if (projectTitle) appendText(svg, ns, pad, HEADER_H / 2 + 6, projectTitle, "#ffffff", "16", "700");
      var rightText = [fieldwork, companyName].filter(Boolean).join("  \u00B7  ");
      if (rightText) {
        var rt = appendText(svg, ns, W - pad, HEADER_H / 2 + 5, rightText, "rgba(255,255,255,0.85)", "11", "500");
        rt.setAttribute("text-anchor", "end");
      }

      var secY = HEADER_H + pad;
      appendText(svg, ns, pad, secY + 16, "Significant Findings" +
        (slideCount > 1 ? " (" + (si + 1) + "/" + slideCount + ")" : ""), "#1a2744", "15", "700");

      var cardY = secY + TITLE_H;
      slideCards.forEach(function(card) {
        var sigText = card.querySelector(".dash-sig-text");
        var badges = card.querySelectorAll(".dash-sig-metric-badge, .dash-sig-group-badge, .dash-sig-type-badge");
        var text = sigText ? sigText.textContent.trim() : "";

        appendRect(svg, ns, pad, cardY, W - 2 * pad, CARD_H, "#f0fdf4", "6", "#bbf7d0");

        var bx = pad + 10;
        badges.forEach(function(badge) {
          var bText = badge.textContent.trim();
          appendText(svg, ns, bx, cardY + 18, bText, "#059669", "9", "700");
          bx += bText.length * 6 + 14;
        });

        var dispText = text.length > 130 ? text.substring(0, 127) + "..." : text;
        appendText(svg, ns, pad + 10, cardY + 42, dispText, "#1e293b", "11");
        cardY += CARD_H + CARD_GAP;
      });

      var footerText = "Generated by Turas \u00B7 " + new Date().toLocaleDateString();
      var ft = appendText(svg, ns, W / 2, totalH - FOOTER_H + 18, footerText, "#94a3b8", "9");
      ft.setAttribute("text-anchor", "middle");

      renderSlidePNG(svg, W, totalH, "sig_findings" + (slideCount > 1 ? "_" + (si + 1) : "") + ".png");
    }
  };

  // ── SVG Helpers ───────────────────────────────────────────────────────────

  function appendRect(parent, ns, x, y, w, h, fill, rx, stroke) {
    var r = document.createElementNS(ns, "rect");
    r.setAttribute("x", x); r.setAttribute("y", y);
    r.setAttribute("width", w); r.setAttribute("height", h);
    r.setAttribute("fill", fill);
    if (rx) r.setAttribute("rx", rx);
    if (stroke) { r.setAttribute("stroke", stroke); r.setAttribute("stroke-width", "1"); }
    parent.appendChild(r);
    return r;
  }

  function appendText(parent, ns, x, y, text, fill, size, weight) {
    var t = document.createElementNS(ns, "text");
    t.setAttribute("x", x); t.setAttribute("y", y);
    t.setAttribute("fill", fill); t.setAttribute("font-size", size);
    if (weight) t.setAttribute("font-weight", weight);
    t.textContent = text;
    parent.appendChild(t);
    return t;
  }

  /** Render SVG to PNG via canvas and trigger download. */
  function renderSlidePNG(svg, w, h, filename) {
    var svgData = new XMLSerializer().serializeToString(svg);
    var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    var url = URL.createObjectURL(blob);
    var canvas = document.createElement("canvas");
    var SCALE = 2;
    canvas.width = w * SCALE; canvas.height = h * SCALE;
    var ctx = canvas.getContext("2d");
    var img = new Image();
    img.onload = function() {
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      var a = document.createElement("a");
      a.download = filename;
      a.href = canvas.toDataURL("image/png");
      a.click();
      URL.revokeObjectURL(url);
    };
    img.onerror = function() { URL.revokeObjectURL(url); };
    img.src = url;
  }

})();
