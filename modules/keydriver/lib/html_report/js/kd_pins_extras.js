/**
 * TURAS Keydriver Report — Pin Extras (Qual Slides + Print)
 *
 * Qualitative slide management (image upload, markdown editing,
 * pin-to-views) and print/PDF overlay. Split from kd_pins.js
 * to keep each file under the 300 active line limit.
 *
 * Depends on: TurasPins shared library, kd_pins.js, kdEscapeHtml
 */

/* global TurasPins, kdEscapeHtml */

(function() {
  "use strict";

  // ── Qualitative Slides ─────────────────────────────────────────────────────

  /** Add a new qualitative slide editing card. */
  window.kdAddQualSlide = function() {
    var container = document.getElementById("kd-qual-slides-container");
    if (!container) return;
    var id = "kd-qual-" + Date.now();
    var card = document.createElement("div");
    card.className = "kd-qual-slide-card editing";
    card.setAttribute("data-slide-id", id);
    card.innerHTML =
      '<div class="kd-qual-header">' +
        '<div class="kd-qual-title" contenteditable="true">New Slide</div>' +
        '<div class="kd-qual-actions">' +
          '<button class="kd-qual-btn" title="Add image" onclick="kdTriggerQualImage(\'' + id + '\')">&#x1F4F7;</button>' +
          '<button class="kd-qual-btn" title="Pin to Views" onclick="kdPinQualSlide(\'' + id + '\')">&#x1F4CC;</button>' +
          '<button class="kd-qual-btn" title="Move up" onclick="kdMoveQualSlide(\'' + id + "\',-1)\">&uarr;</button>" +
          '<button class="kd-qual-btn" title="Move down" onclick="kdMoveQualSlide(\'' + id + "\',1)\">&darr;</button>" +
          '<button class="kd-qual-btn kd-qual-delete" title="Delete slide" onclick="kdRemoveQualSlide(\'' + id + '\')">&times;</button>' +
        "</div>" +
      "</div>" +
      '<div class="kd-qual-img-preview" style="display:none;">' +
        '<img class="kd-qual-img-thumb" src="" alt="Slide image"/>' +
        '<button class="kd-qual-img-remove" onclick="kdRemoveQualImage(\'' + id + '\')">&times;</button>' +
      "</div>" +
      '<input type="file" class="kd-qual-img-input" accept="image/*" style="display:none" ' +
        'onchange="kdHandleQualImage(\'' + id + "',this)\"/>" +
      '<textarea class="kd-qual-md-editor" rows="4" placeholder="Enter commentary here (plain text or markdown)..."></textarea>' +
      '<textarea class="kd-qual-img-store" style="display:none"></textarea>';
    container.appendChild(card);
    var editorEl = card.querySelector(".kd-qual-md-editor");
    if (editorEl) editorEl.focus();
    kdUpdateSlidesEmptyState();
  };

  /** Trigger file picker for qualitative slide image. */
  window.kdTriggerQualImage = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var input = card.querySelector(".kd-qual-img-input");
    if (input) input.click();
  };

  /** Handle image file selection — resize and store as base64. */
  window.kdHandleQualImage = function(slideId, input) {
    if (!input.files || !input.files[0]) return;
    var file = input.files[0];
    if (file.size > 5 * 1024 * 1024) {
      alert("Image too large (max 5 MB). Please use a smaller image or reduce its resolution.");
      input.value = "";
      return;
    }
    var reader = new FileReader();
    reader.onload = function(e) {
      var img = new Image();
      img.onerror = function() { input.value = ""; };
      img.onload = function() {
        var maxDim = 800;
        var w = img.width, h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) { h = Math.round(h * maxDim / w); w = maxDim; }
          else { w = Math.round(w * maxDim / h); h = maxDim; }
        }
        var canvas = document.createElement("canvas");
        canvas.width = w; canvas.height = h;
        canvas.getContext("2d").drawImage(img, 0, 0, w, h);
        var dataUrl = canvas.toDataURL("image/jpeg", 0.7);
        var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
        if (!card) return;
        var store = card.querySelector(".kd-qual-img-store");
        if (store) {
          store.value = dataUrl;
          store.setAttribute("data-img-w", w);
          store.setAttribute("data-img-h", h);
        }
        var preview = card.querySelector(".kd-qual-img-preview");
        var thumb = card.querySelector(".kd-qual-img-thumb");
        if (preview && thumb) {
          thumb.src = dataUrl;
          preview.style.display = "block";
        }
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
    input.value = "";
  };

  /** Remove image from qualitative slide. */
  window.kdRemoveQualImage = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var store = card.querySelector(".kd-qual-img-store");
    if (store) { store.value = ""; store.removeAttribute("data-img-w"); store.removeAttribute("data-img-h"); }
    var preview = card.querySelector(".kd-qual-img-preview");
    if (preview) preview.style.display = "none";
  };

  /** Pin a qualitative slide to pinned views. */
  window.kdPinQualSlide = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var titleEl = card.querySelector(".kd-qual-title");
    var editorEl = card.querySelector(".kd-qual-md-editor");
    var storeEl = card.querySelector(".kd-qual-img-store");
    var title = titleEl ? titleEl.textContent.trim() : "Untitled";
    var text = editorEl ? editorEl.value.trim() : "";
    var imageData = storeEl ? storeEl.value : "";
    var imgW = storeEl ? storeEl.getAttribute("data-img-w") : "";
    var imgH = storeEl ? storeEl.getAttribute("data-img-h") : "";

    TurasPins.add({
      title: title,
      insightText: "<p>" + text.replace(/\n/g, "</p><p>") + "</p>",
      imageData: imageData,
      imageWidth: imgW,
      imageHeight: imgH,
      sectionKey: "qualitative",
      panelLabel: "",
      sectionTitle: title,
      chartSvg: "",
      tableHtml: "",
      pinMode: "all"
    });
  };

  /** Move a qualitative slide up or down in the editing container. */
  window.kdMoveQualSlide = function(slideId, direction) {
    var container = document.getElementById("kd-qual-slides-container");
    if (!container) return;
    var cards = container.querySelectorAll(".kd-qual-slide-card");
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].getAttribute("data-slide-id") === slideId) {
        var target = i + direction;
        if (target >= 0 && target < cards.length) {
          if (direction < 0) container.insertBefore(cards[i], cards[target]);
          else container.insertBefore(cards[target], cards[i]);
        }
        return;
      }
    }
  };

  /** Remove a qualitative slide from the editing container. */
  window.kdRemoveQualSlide = function(slideId) {
    var card = document.querySelector('.kd-qual-slide-card[data-slide-id="' + slideId + '"]');
    if (card) card.remove();
    kdUpdateSlidesEmptyState();
  };

  /** Pin all qualitative slides to pinned views. */
  window.kdPinAllQualSlides = function() {
    var container = document.getElementById("kd-qual-slides-container");
    if (!container) return;
    var cards = container.querySelectorAll(".kd-qual-slide-card");
    if (cards.length === 0) return;
    cards.forEach(function(card) {
      var id = card.getAttribute("data-slide-id");
      if (id) window.kdPinQualSlide(id);
    });
  };

  /** Update empty state for slides tab. */
  function kdUpdateSlidesEmptyState() {
    var container = document.getElementById("kd-qual-slides-container");
    var empty = document.getElementById("kd-qual-slides-empty");
    if (!container || !empty) return;
    var hasCards = container.querySelectorAll(".kd-qual-slide-card").length > 0;
    empty.style.display = hasCards ? "none" : "";
  }

  // ── Print / PDF ────────────────────────────────────────────────────────────

  /**
   * Print pinned views via window.print() overlay.
   * One pin per page, section dividers as heading strips.
   */
  window.kdPrintPinnedViews = function() {
    var allItems = TurasPins.getAll();
    var pinCount = 0;
    for (var i = 0; i < allItems.length; i++) {
      if (allItems[i].type !== "section") pinCount++;
    }
    if (pinCount === 0) return;

    var overlay = document.createElement("div");
    overlay.id = "kd-pinned-print-overlay";
    overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;" +
      "z-index:99999;background:white;overflow:auto;";

    var printStyle = document.createElement("style");
    printStyle.id = "kd-pinned-print-style";
    printStyle.textContent =
      "@page { size: A4 landscape; margin: 10mm 12mm; } " +
      "@media print { " +
      "body > *:not(#kd-pinned-print-overlay) { display: none !important; } " +
      "#kd-pinned-print-overlay { position: static !important; overflow: visible !important; } " +
      ".kd-print-page { page-break-after: always; padding: 12px 0; } " +
      ".kd-print-page:last-child { page-break-after: auto; } " +
      ".kd-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid #323367; " +
      "  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; " +
      "  color: #1a2744; line-height: 1.5; -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".kd-print-chart svg { width: 100%; height: auto; } " +
      ".kd-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } " +
      ".kd-print-table th, .kd-print-table td { padding: 4px 8px; border: 1px solid #ddd; } " +
      ".kd-print-table th { background: #f1f5f9; font-weight: 600; -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".kd-print-section-strip { padding: 16px 0 8px; border-bottom: 2px solid #323367; font-size: 16px; font-weight: 600; color: #323367; } " +
      "} " +
      "#kd-pinned-print-overlay { padding: 32px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; } " +
      ".kd-print-page { border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; margin-bottom: 16px; } " +
      ".kd-print-close-btn { position: fixed; top: 16px; right: 16px; z-index: 100000; padding: 8px 20px; " +
      "  background: #323367; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }";
    document.head.appendChild(printStyle);

    var closeBtn = document.createElement("button");
    closeBtn.className = "kd-print-close-btn";
    closeBtn.textContent = "Close Preview";
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    var projTitle = document.querySelector(".kd-header-title, .kd-comp-title");
    var pTitle = projTitle ? projTitle.textContent.trim() : "Key Driver Report";
    var projStrip = document.createElement("div");
    projStrip.style.cssText = "padding:0 0 8px;margin-bottom:12px;border-bottom:2px solid #323367;";
    projStrip.innerHTML =
      '<div style="font-size:14px;font-weight:700;color:#323367;">' + kdEscapeHtml(pTitle) + "</div>" +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Key Driver &bull; ' +
      new Date().toLocaleDateString() + "</div>";
    overlay.appendChild(projStrip);

    var printPinIdx = 0;
    allItems.forEach(function(item) {
      if (item.type === "section") {
        var sEl = document.createElement("div");
        sEl.className = "kd-print-section-strip";
        sEl.textContent = item.title || "Untitled Section";
        overlay.appendChild(sEl);
        return;
      }
      printPinIdx++;
      var page = document.createElement("div");
      page.className = "kd-print-page";
      page.innerHTML =
        (item.panelLabel ? '<div style="font-size:13px;font-weight:700;color:#323367;text-transform:uppercase;">' + kdEscapeHtml(item.panelLabel) + "</div>" : "") +
        '<div style="font-size:16px;font-weight:600;color:#1e293b;margin:2px 0 10px;">' + kdEscapeHtml(item.sectionTitle || item.title || "") + "</div>" +
        (item.insightText ? '<div class="kd-print-insight">' + kdEscapeHtml(item.insightText) + "</div>" : "") +
        (item.imageData ? '<div style="margin-bottom:12px;text-align:center;"><img src="' + item.imageData + '" style="max-width:100%;max-height:400px;border-radius:6px;" /></div>' : "") +
        (item.chartSvg ? '<div class="kd-print-chart">' + item.chartSvg + "</div>" : "") +
        (item.tableHtml ? '<div class="kd-print-table">' + item.tableHtml + "</div>" : "") +
        '<div style="text-align:right;font-size:9px;color:#94a3b8;margin-top:4px;">' + printPinIdx + " of " + pinCount + "</div>";
      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    function cleanupPrintOverlay() {
      var ov = document.getElementById("kd-pinned-print-overlay");
      if (ov) ov.remove();
      var ps = document.getElementById("kd-pinned-print-style");
      if (ps) ps.remove();
    }

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

})();
