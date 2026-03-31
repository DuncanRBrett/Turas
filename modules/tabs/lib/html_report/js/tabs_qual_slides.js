/**
 * TURAS Tabs Report — Qualitative Slides
 *
 * Add, edit, reorder, and pin qualitative slides with markdown content
 * and optional image uploads. Pinning delegates to TurasPins.add().
 *
 * Depends on: TurasPins shared library, renderMarkdown from tabs_pins_dashboard.js
 */

/* global TurasPins */

(function() {
  "use strict";

  /** Render markdown for all qualitative slide cards. */
  window.renderAllQualSlides = function() {
    document.querySelectorAll(".qual-slide-card").forEach(function(card) {
      var store = card.querySelector(".qual-md-store");
      var editor = card.querySelector(".qual-md-editor");
      var rendered = card.querySelector(".qual-md-rendered");
      if (store && store.value && editor) editor.value = store.value;
      if (rendered && editor) rendered.innerHTML = window.renderMarkdown(editor.value);
      var imgStore = card.querySelector(".qual-img-store");
      if (imgStore && imgStore.value) {
        var preview = card.querySelector(".qual-img-preview");
        var thumb = card.querySelector(".qual-img-thumb");
        if (thumb) thumb.src = imgStore.value;
        if (preview) preview.style.display = "";
      }
    });
    window.updateQualEmptyState();
  };

  /** Toggle edit mode on a qualitative slide card. */
  window.toggleQualEdit = function(card) {
    card.classList.toggle("editing");
    if (!card.classList.contains("editing")) {
      var editor = card.querySelector(".qual-md-editor");
      var rendered = card.querySelector(".qual-md-rendered");
      var store = card.querySelector(".qual-md-store");
      if (rendered && editor) rendered.innerHTML = window.renderMarkdown(editor.value);
      if (store && editor) store.value = editor.value;
    } else {
      var ed = card.querySelector(".qual-md-editor");
      if (ed) ed.focus();
    }
  };

  /** Add a new empty qualitative slide. */
  window.addQualSlide = function() {
    var container = document.getElementById("qual-slides-container");
    if (!container) return;
    var id = "qual-slide-" + Date.now();
    var card = document.createElement("div");
    card.className = "qual-slide-card editing";
    card.setAttribute("data-slide-id", id);
    card.innerHTML =
      '<div class="qual-slide-header">' +
        '<div class="qual-slide-title" contenteditable="true">New Slide</div>' +
        '<div class="qual-slide-actions">' +
          '<button class="export-btn" title="Add image" onclick="triggerQualImage(\'' + id + '\')">\u{1F5BC}</button>' +
          '<button class="export-btn" title="Pin this slide" onclick="pinQualSlide(\'' + id + '\')">\u{1F4CC}</button>' +
          '<button class="export-btn" title="Move up" onclick="moveQualSlide(\'' + id + '\',\'up\')">\u25B2</button>' +
          '<button class="export-btn" title="Move down" onclick="moveQualSlide(\'' + id + '\',\'down\')">\u25BC</button>' +
          '<button class="export-btn" title="Remove slide" style="color:#e8614d;" onclick="removeQualSlide(\'' + id + '\')">\u2715</button>' +
        '</div>' +
      '</div>' +
      '<div class="qual-img-preview" style="display:none;">' +
        '<img class="qual-img-thumb"/>' +
        '<button class="qual-img-remove" onclick="removeQualImage(\'' + id + '\')" title="Remove image">&times;</button>' +
      '</div>' +
      '<input type="file" class="qual-img-input" accept="image/*" style="display:none;" ' +
        'onchange="handleQualImage(\'' + id + '\', this)">' +
      '<textarea class="qual-md-editor" rows="6" placeholder="Enter markdown content... ' +
        '(**bold**, *italic*, > quote, - bullet, ## heading)"></textarea>' +
      '<div class="qual-md-rendered"></div>' +
      '<textarea class="qual-md-store" style="display:none;"></textarea>' +
      '<textarea class="qual-img-store" style="display:none;"></textarea>';
    container.appendChild(card);
    card.querySelector(".qual-md-editor").focus();
    window.updateQualEmptyState();
  };

  /** Trigger the hidden file input for image upload. */
  window.triggerQualImage = function(slideId) {
    var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var input = card.querySelector(".qual-img-input");
    if (input) input.click();
  };

  /** Handle image file selection — resize and store as base64. */
  window.handleQualImage = function(slideId, input) {
    if (!input.files || !input.files[0]) return;
    var file = input.files[0];
    var MAX_FILE_SIZE = 5 * 1024 * 1024;
    var MAX_DIMENSION = 1920;

    if (file.size > MAX_FILE_SIZE) {
      alert("Image too large (" + (file.size / 1024 / 1024).toFixed(1) + "MB). Maximum is 5MB.");
      input.value = "";
      return;
    }

    var reader = new FileReader();
    reader.onload = function(e) {
      var img = new Image();
      img.onerror = function() { /* invalid image data */ };
      img.onload = function() {
        var w = img.width, h = img.height;
        if (w > MAX_DIMENSION || h > MAX_DIMENSION) {
          if (w > h) { h = Math.round(h * MAX_DIMENSION / w); w = MAX_DIMENSION; }
          else { w = Math.round(w * MAX_DIMENSION / h); h = MAX_DIMENSION; }
        }
        var canvas = document.createElement("canvas");
        canvas.width = w; canvas.height = h;
        canvas.getContext("2d").drawImage(img, 0, 0, w, h);
        var dataUrl = canvas.toDataURL("image/jpeg", 0.92);

        var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
        if (!card) return;
        var store = card.querySelector(".qual-img-store");
        if (store) {
          store.value = dataUrl;
          store.setAttribute("data-img-w", w);
          store.setAttribute("data-img-h", h);
        }
        var preview = card.querySelector(".qual-img-preview");
        var thumb = card.querySelector(".qual-img-thumb");
        if (thumb) thumb.src = dataUrl;
        if (preview) preview.style.display = "";
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
    input.value = "";
  };

  /** Remove image from a qualitative slide. */
  window.removeQualImage = function(slideId) {
    var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var store = card.querySelector(".qual-img-store");
    if (store) store.value = "";
    var preview = card.querySelector(".qual-img-preview");
    if (preview) preview.style.display = "none";
    var thumb = card.querySelector(".qual-img-thumb");
    if (thumb) thumb.src = "";
  };

  /** Remove a qualitative slide. */
  window.removeQualSlide = function(slideId) {
    var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
    if (card && confirm("Remove this slide?")) {
      card.remove();
      window.updateQualEmptyState();
    }
  };

  /** Move a qualitative slide up or down. */
  window.moveQualSlide = function(slideId, direction) {
    var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    if (direction === "up" && card.previousElementSibling) {
      card.parentNode.insertBefore(card, card.previousElementSibling);
    } else if (direction === "down" && card.nextElementSibling) {
      card.parentNode.insertBefore(card.nextElementSibling, card);
    }
  };

  /** Pin a qualitative slide to Pinned Views. */
  window.pinQualSlide = function(slideId) {
    var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var titleEl = card.querySelector(".qual-slide-title");
    var rendered = card.querySelector(".qual-md-rendered");
    var editor = card.querySelector(".qual-md-editor");
    if (rendered && editor) rendered.innerHTML = window.renderMarkdown(editor.value);

    var imgStore = card.querySelector(".qual-img-store");
    var imageData = (imgStore && imgStore.value) ? imgStore.value : null;
    var imageWidth = imgStore ? parseInt(imgStore.getAttribute("data-img-w")) || 0 : 0;
    var imageHeight = imgStore ? parseInt(imgStore.getAttribute("data-img-h")) || 0 : 0;
    if (!imageData) {
      var thumb = card.querySelector(".qual-img-thumb");
      if (thumb && thumb.src && thumb.src.indexOf("data:") === 0) {
        imageData = thumb.src;
        imageWidth = thumb.naturalWidth || 0;
        imageHeight = thumb.naturalHeight || 0;
      }
    }

    TurasPins.add({
      pinType: "text_box",
      qCode: null, qTitle: titleEl ? titleEl.textContent.trim() : "Qualitative Slide",
      title: titleEl ? titleEl.textContent.trim() : "Qualitative Slide",
      insightText: rendered ? rendered.innerHTML : "",
      imageData: imageData, imageWidth: imageWidth, imageHeight: imageHeight,
      tableHtml: null, chartSvg: null, baseText: null
    });
  };

  /** Show/hide qualitative empty state and update move button visibility. */
  window.updateQualEmptyState = function() {
    var container = document.getElementById("qual-slides-container");
    var emptyState = document.getElementById("qual-empty-state");
    if (!container || !emptyState) return;
    var cards = container.querySelectorAll(".qual-slide-card");
    var hasCards = cards.length > 0;
    emptyState.style.display = hasCards ? "none" : "";
    var showMove = cards.length > 1;
    cards.forEach(function(card) {
      card.querySelectorAll('.export-btn[title="Move up"], .export-btn[title="Move down"]')
        .forEach(function(btn) { btn.style.display = showMove ? "" : "none"; });
    });
  };

})();
