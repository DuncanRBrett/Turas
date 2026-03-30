/**
 * TURAS Segment Report — Pin Extras (Image Upload, Custom Content, Print)
 *
 * Split from seg_pins.js to stay within 300 active line limit.
 * Handles segment-unique features that delegate to TurasPins:
 *   - Image upload for pinned cards (PNG/JPEG/GIF/WebP, 2 MB limit)
 *   - Custom content pinning (from slides tab)
 *   - Print / PDF overlay with A4 landscape layout
 *
 * Depends on: TurasPins shared library, seg_pins.js, segEscapeHtml
 */

/* global TurasPins, segEscapeHtml */

(function() {
  "use strict";

  // ── Custom Content Pin (for slides tab) ────────────────────────────────────

  /**
   * Pin arbitrary custom content (used by slides, custom sections).
   * @param {string} title - Display title for the pinned card
   * @param {string} htmlContent - HTML string to display
   */
  window.segPinCustomContent = function(title, htmlContent) {
    TurasPins.add({
      sectionKey: "custom", prefix: "",
      panelLabel: "", sectionTitle: title,
      insightText: "", chartSvg: "",
      tableHtml: htmlContent, pinMode: "all"
    });
  };

  // ── Image Upload (segment-unique) ──────────────────────────────────────────

  var MAX_IMAGE_SIZE = 2 * 1024 * 1024; // 2 MB
  var ACCEPTED_TYPES = /^image\/(png|jpeg|gif|webp)$/;

  /**
   * Trigger file input to upload an image for a pinned card.
   * @param {string} pinId - ID of the pin to attach the image to
   */
  window.segTriggerImageUpload = function(pinId) {
    var input = document.createElement("input");
    input.type = "file";
    input.accept = "image/png,image/jpeg,image/gif,image/webp";
    input.style.display = "none";

    input.onchange = function(e) {
      var file = e.target.files[0];
      if (!file) return;

      if (file.size > MAX_IMAGE_SIZE) {
        TurasPins._showToast("Image must be under 2 MB.");
        return;
      }
      if (!ACCEPTED_TYPES.test(file.type)) {
        TurasPins._showToast("Please select a PNG, JPEG, GIF, or WebP image.");
        return;
      }

      var reader = new FileReader();
      reader.onload = function(ev) {
        var allPins = TurasPins._getPinsRef();
        for (var i = 0; i < allPins.length; i++) {
          if (allPins[i].id === pinId) {
            allPins[i].imageData = ev.target.result;
            break;
          }
        }
        TurasPins.renderCards();
        TurasPins.save();
      };
      reader.readAsDataURL(file);
    };

    document.body.appendChild(input);
    input.click();
    document.body.removeChild(input);
  };

  /**
   * Remove an uploaded image from a pinned card.
   * @param {string} pinId - ID of the pin
   */
  window.segRemoveImage = function(pinId) {
    var allPins = TurasPins._getPinsRef();
    for (var i = 0; i < allPins.length; i++) {
      if (allPins[i].id === pinId) {
        delete allPins[i].imageData;
        break;
      }
    }
    TurasPins.renderCards();
    TurasPins.save();
  };

  // ── Print / PDF ────────────────────────────────────────────────────────────

  /**
   * Print pinned views via window.print() overlay.
   * One pin per page, section dividers as heading strips.
   */
  window.segPrintPinnedViews = function() {
    var allItems = TurasPins.getAll();
    var pinCount = 0;
    for (var i = 0; i < allItems.length; i++) {
      if (allItems[i].type !== "section") pinCount++;
    }
    if (pinCount === 0) return;

    var segBrand = getComputedStyle(document.documentElement)
      .getPropertyValue("--seg-brand").trim() || "#323367";

    var overlay = document.createElement("div");
    overlay.id = "seg-pinned-print-overlay";
    overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;" +
      "z-index:99999;background:white;overflow:auto;";

    var printStyle = document.createElement("style");
    printStyle.id = "seg-pinned-print-style";
    printStyle.textContent = buildPrintCSS(segBrand);
    document.head.appendChild(printStyle);

    // Close button
    var closeBtn = document.createElement("button");
    closeBtn.className = "seg-print-close-btn";
    closeBtn.textContent = "Close Preview";
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    // Project header strip
    var projTitle = document.querySelector(".seg-header-title");
    var pTitle = projTitle ? projTitle.textContent.trim() : "Segment Report";
    var projStrip = document.createElement("div");
    projStrip.className = "seg-print-project-strip";
    projStrip.innerHTML =
      '<div style="font-size:14px;font-weight:700;color:' + segBrand + ';">' +
      segEscapeHtml(pTitle) + "</div>" +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Segment &bull; ' +
      new Date().toLocaleDateString() + "</div>";
    overlay.appendChild(projStrip);

    // Build pages
    var printPinIdx = 0;
    allItems.forEach(function(item) {
      if (item.type === "section") {
        var sEl = document.createElement("div");
        sEl.className = "seg-print-section-strip";
        sEl.textContent = item.title || "Untitled Section";
        overlay.appendChild(sEl);
        return;
      }
      printPinIdx++;
      overlay.appendChild(buildPrintPage(item, printPinIdx, pinCount, segBrand));
    });

    document.body.appendChild(overlay);

    // Print + cleanup
    var cleaned = false;
    window.addEventListener("afterprint", function onAP() {
      if (cleaned) return;
      cleaned = true;
      window.removeEventListener("afterprint", onAP);
      cleanupPrintOverlay();
    });
    setTimeout(function() {
      window.print();
      setTimeout(function() {
        if (!cleaned) { cleaned = true; cleanupPrintOverlay(); }
      }, 3000);
    }, 300);
  };

  /** Build print CSS string. */
  function buildPrintCSS(brand) {
    return "@page { size: A4 landscape; margin: 10mm 12mm; } " +
      "@media print { " +
      "body > *:not(#seg-pinned-print-overlay) { display: none !important; } " +
      "#seg-pinned-print-overlay { position: static !important; overflow: visible !important; } " +
      ".seg-print-page { page-break-after: always; padding: 12px 0; } " +
      ".seg-print-page:last-child { page-break-after: auto; } " +
      ".seg-print-insight { margin-bottom: 12px; padding: 16px 24px; " +
      "border-left: 4px solid " + brand + "; background: #f0f5f5; " +
      "border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; " +
      "color: #1a2744; line-height: 1.5; " +
      "-webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".seg-print-chart svg { width: 100%; height: auto; } " +
      ".seg-print-table table { width: 100%; border-collapse: collapse; " +
      "font-size: 13px; table-layout: fixed; } " +
      ".seg-print-table th, .seg-print-table td { padding: 4px 8px; border: 1px solid #ddd; } " +
      ".seg-print-table th { background: #f1f5f9; font-weight: 600; " +
      "-webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".seg-print-section-strip { padding: 16px 0 8px; border-bottom: 2px solid " + brand + "; " +
      "font-size: 16px; font-weight: 600; color: " + brand + "; } " +
      "} " +
      "#seg-pinned-print-overlay { padding: 32px; " +
      "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; } " +
      ".seg-print-page { border: 1px solid #e2e8f0; border-radius: 8px; " +
      "padding: 24px; margin-bottom: 16px; } " +
      ".seg-print-project-strip { padding: 0 0 8px; margin-bottom: 12px; " +
      "border-bottom: 2px solid " + brand + "; } " +
      ".seg-print-close-btn { position: fixed; top: 16px; right: 16px; " +
      "z-index: 100000; padding: 8px 20px; background: " + brand + "; " +
      "color: white; border: none; border-radius: 6px; cursor: pointer; " +
      "font-size: 13px; font-weight: 600; }";
  }

  /** Build a single print page for a pin. */
  function buildPrintPage(item, idx, total, brand) {
    var page = document.createElement("div");
    page.className = "seg-print-page";

    var hdr = "";
    if (item.panelLabel) {
      hdr += '<div style="font-size:13px;font-weight:700;color:' + brand +
        ';text-transform:uppercase;">' + segEscapeHtml(item.panelLabel) + "</div>";
    }
    hdr += '<div style="font-size:16px;font-weight:600;color:#1e293b;margin:2px 0 10px;">' +
      segEscapeHtml(item.sectionTitle || item.title || "") + "</div>";

    var insight = item.insightText
      ? '<div class="seg-print-insight">' + segEscapeHtml(item.insightText) + "</div>" : "";
    var image = item.imageData
      ? '<div style="margin-bottom:12px;"><img src="' + item.imageData +
        '" style="max-width:100%;max-height:300px;border-radius:4px;" /></div>' : "";
    var chart = item.chartSvg
      ? '<div class="seg-print-chart">' + item.chartSvg + "</div>" : "";
    var table = item.tableHtml
      ? '<div class="seg-print-table">' + item.tableHtml + "</div>" : "";
    var pgNum = '<div style="text-align:right;font-size:9px;color:#94a3b8;margin-top:4px;">' +
      idx + " of " + total + "</div>";

    page.innerHTML = hdr + insight + image + chart + table + pgNum;
    return page;
  }

  /** Remove print overlay and styles. */
  function cleanupPrintOverlay() {
    var ov = document.getElementById("seg-pinned-print-overlay");
    if (ov) ov.remove();
    var ps = document.getElementById("seg-pinned-print-style");
    if (ps) ps.remove();
  }

})();
