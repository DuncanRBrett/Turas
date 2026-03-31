/**
 * Conjoint Pins — Print Overlay
 *
 * Generates a full-page print overlay from pinned views for PDF/print export.
 * Extracted from cj_pins.js to keep files under 300 active lines.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 */

/* global TurasPins */

(function() {
  "use strict";

  /** Generate and display print overlay for all pinned views. */
  window.cjPrintPinnedViews = function() {
    var allItems = TurasPins.getAll();
    var pinCount = 0;
    for (var i = 0; i < allItems.length; i++) {
      if (allItems[i].type !== "section") pinCount++;
    }
    if (pinCount === 0) return;

    var overlay = document.createElement("div");
    overlay.id = "cj-pinned-print-overlay";
    overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;" +
      "z-index:99999;background:white;overflow:auto;";

    var printStyle = document.createElement("style");
    printStyle.id = "cj-pinned-print-style";
    printStyle.textContent = [
      "@page{size:A4 landscape;margin:10mm 12mm}",
      "@media print{body>*:not(#cj-pinned-print-overlay){display:none!important}",
      "#cj-pinned-print-overlay{position:static!important;overflow:visible!important}",
      ".cj-print-page{page-break-after:always;padding:12px 0}.cj-print-page:last-child{page-break-after:auto}",
      ".cj-print-insight{margin-bottom:12px;padding:16px 24px;border-left:4px solid #323367;background:#f0f5f5;border-radius:0 6px 6px 0;font-size:15px;font-weight:600;color:#1a2744;line-height:1.5;-webkit-print-color-adjust:exact;print-color-adjust:exact}",
      ".cj-print-chart svg{width:100%;height:auto}.cj-print-table table{width:100%;border-collapse:collapse;font-size:13px}",
      ".cj-print-table th,.cj-print-table td{padding:4px 8px;border:1px solid #ddd}.cj-print-table th{background:#f1f5f9;font-weight:600;-webkit-print-color-adjust:exact;print-color-adjust:exact}",
      ".cj-print-section-strip{padding:16px 0 8px;border-bottom:2px solid #323367;font-size:16px;font-weight:600;color:#323367}}",
      "#cj-pinned-print-overlay{padding:32px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}",
      ".cj-print-page{border:1px solid #e2e8f0;border-radius:8px;padding:24px;margin-bottom:16px}",
      ".cj-print-close-btn{position:fixed;top:16px;right:16px;z-index:100000;padding:8px 20px;background:#323367;color:white;border:none;border-radius:6px;cursor:pointer;font-size:13px;font-weight:600}"
    ].join(" ");
    document.head.appendChild(printStyle);

    function cleanupPrintOverlay() {
      var ov = document.getElementById("cj-pinned-print-overlay");
      if (ov) ov.remove();
      var ps = document.getElementById("cj-pinned-print-style");
      if (ps) ps.remove();
    }

    var closeBtn = document.createElement("button");
    closeBtn.className = "cj-print-close-btn";
    closeBtn.textContent = "Close Preview";
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    var projTitle = document.querySelector(".cj-header-title");
    var pTitle = projTitle ? projTitle.textContent.trim() : "Conjoint Report";
    var projStrip = document.createElement("div");
    projStrip.style.cssText = "padding:0 0 8px;margin-bottom:12px;border-bottom:2px solid #323367;";
    projStrip.innerHTML =
      '<div style="font-size:14px;font-weight:700;color:#323367;">' + TurasPins._escapeHtml(pTitle) + "</div>" +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Conjoint &bull; ' +
      new Date().toLocaleDateString() + "</div>";
    overlay.appendChild(projStrip);

    var printPinIdx = 0;
    allItems.forEach(function(item) {
      if (item.type === "section") {
        var sEl = document.createElement("div");
        sEl.className = "cj-print-section-strip";
        sEl.textContent = item.title || "Untitled Section";
        overlay.appendChild(sEl);
        return;
      }
      printPinIdx++;
      var page = document.createElement("div");
      page.className = "cj-print-page";
      page.innerHTML =
        '<div style="font-size:16px;font-weight:600;color:#1e293b;margin:2px 0 10px;">' + TurasPins._escapeHtml(item.title || "") + "</div>" +
        (item.insightText ? '<div class="cj-print-insight">' + TurasPins._escapeHtml(item.insightText) + "</div>" : "") +
        (item.chartSvg ? '<div class="cj-print-chart">' + item.chartSvg + "</div>" : "") +
        (item.tableHtml ? '<div class="cj-print-table">' + item.tableHtml + "</div>" : "") +
        '<div style="text-align:right;font-size:9px;color:#94a3b8;margin-top:4px;">' + printPinIdx + " of " + pinCount + "</div>";
      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    var cleaned = false;
    window.addEventListener("afterprint", function onAP() {
      if (cleaned) return;
      cleaned = true;
      window.removeEventListener("afterprint", onAP);
      cleanupPrintOverlay();
    });

    setTimeout(function() {
      window.print();
      setTimeout(function() { if (!cleaned) { cleaned = true; cleanupPrintOverlay(); } }, 3000);
    }, 300);
  };

  window.printPinnedViews = function() { window.cjPrintPinnedViews(); };

})();
