/**
 * Hub Pinned Views — Overview & Qualitative Slides
 *
 * Hub-specific features: overview summary pinning, executive summary /
 * background text sections, About notes, and qualitative insight slides.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 *             hub_pins.js (ReportHub.addPin, ReportHub.renderMarkdown)
 */

/* global ReportHub, TurasPins */

(function() {
  "use strict";

  // ── Configuration Constants ────────────────────────────────────────────────

  var MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024;
  var MAX_IMAGE_DIM = 1200;
  var JPEG_QUALITY = 0.92;

  // ── Overview Summary Pinning ───────────────────────────────────────────────

  /**
   * Pin an overview summary editor's content.
   * @param {string} source - Data source key (e.g., "tracker", "tabs")
   */
  ReportHub.pinOverviewSummary = function(source) {
    var editors = document.querySelectorAll('.hub-summary-editor[data-source="' + source + '"]');
    if (!editors.length) return;
    var editor = editors[0];
    var text = editor.innerText.trim();
    if (!text) { alert("Add summary text before pinning."); return; }
    var section = editor.closest(".hub-summary-section");
    var title = section ? section.querySelector(".hub-summary-label").textContent : "Overview Summary";
    ReportHub.addPin("overview", {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7),
      title: title,
      sourceLabel: "Overview",
      insight: text,
      timestamp: Date.now()
    });
  };

  /**
   * Pin a hub-level executive summary or background text.
   * @param {string} boxId - "executive-summary" or "background"
   */
  ReportHub.pinHubText = function(boxId) {
    var rendered = document.getElementById("hub-text-rendered-" + boxId);
    var editor = document.getElementById("hub-text-editor-" + boxId);
    if (!rendered || !editor) return;
    rendered.innerHTML = TurasPins._renderMarkdown(editor.value);
    var mdSource = editor.value.trim();
    if (!mdSource) { alert("Add text before pinning."); return; }
    var section = document.getElementById("hub-text-" + boxId);
    var labelEl = section ? section.querySelector(".hub-summary-label") : null;
    var title = labelEl ? labelEl.textContent.trim() : boxId;
    ReportHub.addPin("overview", {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7),
      title: title,
      sourceLabel: "Overview",
      insight: mdSource,
      timestamp: Date.now()
    });
  };

  // ── Hub Text Sections (Executive Summary, Background) ──────────────────────

  /** Toggle hub text section into edit mode. */
  ReportHub.toggleHubTextEdit = function(boxId) {
    var rendered = document.getElementById("hub-text-rendered-" + boxId);
    var editor = document.getElementById("hub-text-editor-" + boxId);
    if (!rendered || !editor) return;
    rendered.style.display = "none";
    editor.style.display = "";
    editor.focus();
  };

  /** Finish hub text section editing: re-render markdown and persist. */
  ReportHub.finishHubTextEdit = function(boxId) {
    var rendered = document.getElementById("hub-text-rendered-" + boxId);
    var editor = document.getElementById("hub-text-editor-" + boxId);
    if (!rendered || !editor) return;
    rendered.innerHTML = TurasPins._renderMarkdown(editor.value);
    rendered.style.display = "";
    editor.style.display = "none";
  };

  /** Render all hub text sections on page load. */
  ReportHub.renderHubTextSections = function() {
    document.querySelectorAll(".hub-text-section").forEach(function(section) {
      var editor = section.querySelector(".hub-text-editor");
      var rendered = section.querySelector(".hub-text-rendered");
      if (rendered && editor) {
        rendered.innerHTML = TurasPins._renderMarkdown(editor.value);
      }
    });
    var aboutEditor = document.getElementById("hub-about-notes-editor");
    var aboutRendered = document.getElementById("hub-about-notes-rendered");
    if (aboutRendered && aboutEditor) {
      aboutRendered.innerHTML = TurasPins._renderMarkdown(aboutEditor.value);
    }
  };

  // ── About Notes ────────────────────────────────────────────────────────────

  /** Toggle About notes into edit mode. */
  ReportHub.toggleHubAboutNotesEdit = function() {
    var rendered = document.getElementById("hub-about-notes-rendered");
    var editor = document.getElementById("hub-about-notes-editor");
    if (!rendered || !editor) return;
    rendered.style.display = "none";
    editor.style.display = "";
    editor.focus();
  };

  /** Finish About notes editing: re-render markdown. */
  ReportHub.finishHubAboutNotesEdit = function() {
    var rendered = document.getElementById("hub-about-notes-rendered");
    var editor = document.getElementById("hub-about-notes-editor");
    if (!rendered || !editor) return;
    rendered.innerHTML = TurasPins._renderMarkdown(editor.value);
    rendered.style.display = "";
    editor.style.display = "none";
  };

  // ── Qualitative Slides ─────────────────────────────────────────────────────

  /**
   * Pin a hub-level qualitative slide.
   * @param {string} slideId - Slide element ID
   */
  ReportHub.pinHubSlide = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var titleEl = card.querySelector(".hub-slide-title");
    var editor = card.querySelector(".hub-slide-editor");
    var rendered = card.querySelector(".hub-slide-rendered");
    if (rendered && editor) rendered.innerHTML = TurasPins._renderMarkdown(editor.value);
    var imgStore = card.querySelector(".hub-slide-img-store");
    var imageData = null;
    if (imgStore) {
      var val = imgStore.value || imgStore.textContent || "";
      if (val.length > 0) imageData = val;
    }
    ReportHub.addPin("overview", {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7),
      title: titleEl ? (titleEl.value || titleEl.textContent || "").trim() || "Slide" : "Slide",
      sourceLabel: "Overview",
      insight: editor ? editor.value.trim() : "",
      imageData: imageData,
      tableHtml: null,
      chartSvg: null,
      timestamp: Date.now()
    });
  };

  /** Toggle hub slide edit mode. */
  ReportHub.toggleHubSlideEdit = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var editor = card.querySelector(".hub-slide-editor");
    var rendered = card.querySelector(".hub-slide-rendered");
    if (!editor || !rendered) return;
    rendered.style.display = "none";
    editor.style.display = "";
    editor.focus();
  };

  /** Finish hub slide editing: re-render markdown. */
  ReportHub.finishHubSlideEdit = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var editor = card.querySelector(".hub-slide-editor");
    var rendered = card.querySelector(".hub-slide-rendered");
    if (!editor || !rendered) return;
    rendered.innerHTML = TurasPins._renderMarkdown(editor.value);
    rendered.style.display = "";
    editor.style.display = "none";
  };

  /** Update a hub slide's title (placeholder for future persistence). */
  ReportHub.updateHubSlideTitle = function(slideId, newTitle) {
    // Title is stored in the input itself, no separate data store needed
  };

  /** Render all hub slides on page load. */
  ReportHub.renderHubSlides = function() {
    document.querySelectorAll(".hub-slide-card").forEach(function(card) {
      var editor = card.querySelector(".hub-slide-editor");
      var rendered = card.querySelector(".hub-slide-rendered");
      if (rendered && editor) {
        rendered.innerHTML = TurasPins._renderMarkdown(editor.value);
      }
    });
  };

  /** Add a new insight slide to the Insights & Analysis grid. */
  ReportHub.addHubSlide = function() {
    var grid = document.getElementById("hub-slides-grid");
    if (!grid) return;
    var slideId = "hub-slide-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7);
    var card = document.createElement("div");
    card.className = "hub-slide-card";
    card.setAttribute("data-slide-id", slideId);
    card.innerHTML =
      '<div class="hub-slide-title-row">' +
        '<input class="hub-slide-title" value="New Insight" ' +
          'onchange="ReportHub.updateHubSlideTitle(\'' + slideId + '\', this.value)">' +
        '<button class="hub-slide-img-btn" onclick="ReportHub.triggerHubSlideImage(\'' + slideId + '\')" title="Add image">&#x1F5BC;</button>' +
        '<button class="hub-pin-summary-btn" onclick="ReportHub.pinHubSlide(\'' + slideId + '\')" title="Pin this slide">\uD83D\uDCCC Pin</button>' +
        '<button class="hub-slide-remove-btn" onclick="ReportHub.removeHubSlide(\'' + slideId + '\')" title="Remove this slide">\u00D7</button>' +
      '</div>' +
      '<div class="hub-slide-img-preview" style="display:none;">' +
        '<img class="hub-slide-img-thumb" src="">' +
        '<button class="hub-slide-img-remove" onclick="ReportHub.removeHubSlideImage(\'' + slideId + '\')" title="Remove image">&times;</button>' +
      '</div>' +
      '<input type="file" class="hub-slide-img-input" accept="image/*" style="display:none;" ' +
        'onchange="ReportHub.handleHubSlideImage(\'' + slideId + '\', this)">' +
      '<div class="hub-slide-rendered hub-md-content" data-slide-id="' + slideId + '" ' +
        'ondblclick="ReportHub.toggleHubSlideEdit(\'' + slideId + '\')"></div>' +
      '<textarea class="hub-slide-editor" data-slide-id="' + slideId + '" ' +
        'style="display:block" ' +
        'onblur="ReportHub.finishHubSlideEdit(\'' + slideId + '\')"></textarea>' +
      '<textarea class="hub-slide-img-store" style="display:none;"></textarea>';
    grid.appendChild(card);
    var editorEl = card.querySelector(".hub-slide-editor");
    if (editorEl) editorEl.focus();
  };

  /** Remove a hub slide card from the DOM. */
  ReportHub.removeHubSlide = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    if (!confirm("Remove this insight slide?")) return;
    card.parentNode.removeChild(card);
  };

  /** Trigger file input for adding an image to a hub slide. */
  ReportHub.triggerHubSlideImage = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var input = card.querySelector(".hub-slide-img-input");
    if (input) input.click();
  };

  /**
   * Handle image file selection for a hub slide.
   * Resizes to max dimension, encodes as base64, shows preview.
   * @param {string} slideId - Slide element ID
   * @param {HTMLInputElement} inputEl - The file input element
   */
  ReportHub.handleHubSlideImage = function(slideId, inputEl) {
    var file = inputEl.files && inputEl.files[0];
    if (!file) return;

    if (file.size > MAX_IMAGE_SIZE_BYTES) {
      alert("Image too large (" + (file.size / 1024 / 1024).toFixed(1) + "MB). Maximum is 10MB.");
      inputEl.value = "";
      return;
    }

    var reader = new FileReader();
    reader.onload = function(e) {
      var img = new Image();
      img.onerror = function() { /* invalid image data */ };
      img.onload = function() {
        var w = img.width, h = img.height;
        if (w > MAX_IMAGE_DIM || h > MAX_IMAGE_DIM) {
          if (w > h) { h = Math.round(h * MAX_IMAGE_DIM / w); w = MAX_IMAGE_DIM; }
          else { w = Math.round(w * MAX_IMAGE_DIM / h); h = MAX_IMAGE_DIM; }
        }
        var canvas = document.createElement("canvas");
        canvas.width = w; canvas.height = h;
        var ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, w, h);
        var isPNG = file.type === "image/png" || file.name.toLowerCase().endsWith(".png");
        var dataUrl = isPNG
          ? canvas.toDataURL("image/png")
          : canvas.toDataURL("image/jpeg", JPEG_QUALITY);
        var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
        if (!card) return;
        var preview = card.querySelector(".hub-slide-img-preview");
        var thumb = card.querySelector(".hub-slide-img-thumb");
        var store = card.querySelector(".hub-slide-img-store");
        if (thumb) thumb.src = dataUrl;
        if (preview) preview.style.display = "";
        if (store) store.value = dataUrl;
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
    inputEl.value = "";
  };

  /** Remove the image from a hub slide. */
  ReportHub.removeHubSlideImage = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var preview = card.querySelector(".hub-slide-img-preview");
    var thumb = card.querySelector(".hub-slide-img-thumb");
    var store = card.querySelector(".hub-slide-img-store");
    if (thumb) thumb.src = "";
    if (preview) preview.style.display = "none";
    if (store) store.value = "";
  };

})();
