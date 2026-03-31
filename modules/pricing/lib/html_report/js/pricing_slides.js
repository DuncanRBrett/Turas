// ==============================================================================
// TURAS PRICING MODULE - ADDED SLIDES JAVASCRIPT
// ==============================================================================
// Provides interactive slide creation, markdown editing, image upload,
// reordering, and pinning for the Added Slides tab.
// Version: 12.0
// ==============================================================================

// ── Markdown Renderer (lightweight) ──────────────────────────────────────────

function renderPrSlideMarkdown(md) {
  if (!md) return "";
  var html = md
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/^## (.+)$/gm, "<h2>$1</h2>")
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.+?)\*/g, "<em>$1</em>")
    .replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>")
    .replace(/^- (.+)$/gm, "<li>$1</li>");
  // Wrap consecutive <li> in <ul>
  html = html.replace(/((?:<li>.*<\/li>\s*)+)/g, function(match) {
    return "<ul>" + match + "</ul>";
  });
  // Merge consecutive blockquotes
  html = html.replace(/<\/blockquote>\s*<blockquote>/g, "<br>");
  // Paragraphs: lines not already wrapped in block elements
  html = html.split("\n").map(function(line) {
    var trimmed = line.trim();
    if (!trimmed) return "";
    if (/^<(h2|ul|li|blockquote)/.test(trimmed)) return trimmed;
    return "<p>" + trimmed + "</p>";
  }).join("");
  return html;
}

// ── Render All Slides on Load ────────────────────────────────────────────────

function renderAllPrSlides() {
  document.querySelectorAll(".pr-slide-card").forEach(function(card) {
    var store = card.querySelector(".pr-slide-md-store");
    var editor = card.querySelector(".pr-slide-md-editor");
    var rendered = card.querySelector(".pr-slide-md-rendered");
    if (store && store.value && editor) {
      editor.value = store.value;
    }
    if (rendered && editor) {
      rendered.innerHTML = renderPrSlideMarkdown(editor.value);
    }
    // Hydrate image from stored base64
    var imgStore = card.querySelector(".pr-slide-img-store");
    if (imgStore && imgStore.value) {
      var preview = card.querySelector(".pr-slide-img-preview");
      var thumb = card.querySelector(".pr-slide-img-thumb");
      if (thumb) thumb.src = imgStore.value;
      if (preview) preview.style.display = "";
    }
  });
  updatePrSlidesEmptyState();
}

// ── Toggle Edit Mode (double-click) ─────────────────────────────────────────

function togglePrSlideEdit(card) {
  card.classList.toggle("editing");
  if (!card.classList.contains("editing")) {
    var editor = card.querySelector(".pr-slide-md-editor");
    var rendered = card.querySelector(".pr-slide-md-rendered");
    var store = card.querySelector(".pr-slide-md-store");
    if (rendered && editor) rendered.innerHTML = renderPrSlideMarkdown(editor.value);
    if (store && editor) store.value = editor.value;
  } else {
    var ed = card.querySelector(".pr-slide-md-editor");
    if (ed) ed.focus();
  }
}

// ── Add New Slide ────────────────────────────────────────────────────────────

function addPrSlide() {
  var container = document.getElementById("pr-slides-container");
  if (!container) return;
  var id = "added-slide-" + Date.now();
  var card = document.createElement("div");
  card.className = "pr-slide-card editing";
  card.setAttribute("data-slide-id", id);
  card.innerHTML =
    '<div class="pr-slide-header">' +
      '<div class="pr-slide-title" contenteditable="true">New Slide</div>' +
      '<div class="pr-slide-actions">' +
        '<button class="pr-export-btn" title="Add image" onclick="triggerPrSlideImage(\'' + id + '\')">&#x1F5BC;</button>' +
        '<button class="pr-export-btn" title="Pin this slide" onclick="pinPrSlide(\'' + id + '\')">&#x1F4CC;</button>' +
        '<button class="pr-export-btn" title="Move up" onclick="movePrSlide(\'' + id + '\',\'up\')">&#x25B2;</button>' +
        '<button class="pr-export-btn" title="Move down" onclick="movePrSlide(\'' + id + '\',\'down\')">&#x25BC;</button>' +
        '<button class="pr-export-btn" title="Remove slide" style="color:#e8614d;" onclick="removePrSlide(\'' + id + '\')">&#x2715;</button>' +
      '</div>' +
    '</div>' +
    '<div class="pr-slide-img-preview" style="display:none;">' +
      '<img class="pr-slide-img-thumb"/>' +
      '<button class="pr-slide-img-remove" onclick="removePrSlideImage(\'' + id + '\')" title="Remove image">&times;</button>' +
    '</div>' +
    '<input type="file" class="pr-slide-img-input" accept="image/*" style="display:none;" onchange="handlePrSlideImage(\'' + id + '\', this)">' +
    '<textarea class="pr-slide-md-editor" rows="6" placeholder="Enter markdown content... (**bold**, *italic*, > quote, - bullet, ## heading)"></textarea>' +
    '<div class="pr-slide-md-rendered"></div>' +
    '<textarea class="pr-slide-md-store" style="display:none;"></textarea>' +
    '<textarea class="pr-slide-img-store" style="display:none;"></textarea>';
  container.appendChild(card);
  card.querySelector(".pr-slide-md-editor").focus();
  updatePrSlidesEmptyState();
}

// ── Image Upload ─────────────────────────────────────────────────────────────

function triggerPrSlideImage(slideId) {
  var card = document.querySelector('.pr-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  var input = card.querySelector(".pr-slide-img-input");
  if (input) input.click();
}

function handlePrSlideImage(slideId, input) {
  if (!input.files || !input.files[0]) return;
  var file = input.files[0];

  // File size guard (5MB raw)
  if (file.size > 5 * 1024 * 1024) {
    alert("Image too large (" + (file.size / 1024 / 1024).toFixed(1) + "MB). Maximum is 5MB.");
    input.value = "";
    return;
  }

  var reader = new FileReader();
  reader.onload = function(e) {
    var img = new Image();
    img.onerror = function() { /* invalid image — skip */ };
    img.onload = function() {
      // Resize to max 800px on longest side
      var maxDim = 800;
      var w = img.width, h = img.height;
      if (w > maxDim || h > maxDim) {
        if (w > h) { h = Math.round(h * maxDim / w); w = maxDim; }
        else { w = Math.round(w * maxDim / h); h = maxDim; }
      }
      var canvas = document.createElement("canvas");
      canvas.width = w; canvas.height = h;
      var ctx = canvas.getContext("2d");
      ctx.drawImage(img, 0, 0, w, h);
      var dataUrl = canvas.toDataURL("image/jpeg", 0.7);

      var card = document.querySelector('.pr-slide-card[data-slide-id="' + slideId + '"]');
      if (!card) return;
      var store = card.querySelector(".pr-slide-img-store");
      if (store) {
        store.value = dataUrl;
        store.setAttribute("data-img-w", w);
        store.setAttribute("data-img-h", h);
      }
      var preview = card.querySelector(".pr-slide-img-preview");
      var thumb = card.querySelector(".pr-slide-img-thumb");
      if (thumb) thumb.src = dataUrl;
      if (preview) preview.style.display = "";
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
  input.value = "";
}

function removePrSlideImage(slideId) {
  var card = document.querySelector('.pr-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  var store = card.querySelector(".pr-slide-img-store");
  if (store) store.value = "";
  var preview = card.querySelector(".pr-slide-img-preview");
  if (preview) preview.style.display = "none";
  var thumb = card.querySelector(".pr-slide-img-thumb");
  if (thumb) thumb.src = "";
}

// ── Remove Slide ─────────────────────────────────────────────────────────────

function removePrSlide(slideId) {
  var card = document.querySelector('.pr-slide-card[data-slide-id="' + slideId + '"]');
  if (card && confirm("Remove this slide?")) {
    card.remove();
    updatePrSlidesEmptyState();
  }
}

// ── Reorder Slides ───────────────────────────────────────────────────────────

function movePrSlide(slideId, direction) {
  var card = document.querySelector('.pr-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  if (direction === "up" && card.previousElementSibling) {
    card.parentNode.insertBefore(card, card.previousElementSibling);
  } else if (direction === "down" && card.nextElementSibling) {
    card.parentNode.insertBefore(card.nextElementSibling, card);
  }
}

// ── Pin Slide ────────────────────────────────────────────────────────────────

function pinPrSlide(slideId) {
  var card = document.querySelector('.pr-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  var titleEl = card.querySelector(".pr-slide-title");
  var rendered = card.querySelector(".pr-slide-md-rendered");
  var editor = card.querySelector(".pr-slide-md-editor");
  if (rendered && editor) rendered.innerHTML = renderPrSlideMarkdown(editor.value);

  // Get image data if present
  var imgStore = card.querySelector(".pr-slide-img-store");
  var imageData = (imgStore && imgStore.value) ? imgStore.value : null;
  var imageWidth = imgStore ? parseInt(imgStore.getAttribute("data-img-w")) || 0 : 0;
  var imageHeight = imgStore ? parseInt(imgStore.getAttribute("data-img-h")) || 0 : 0;
  if (!imageData) {
    var thumb = card.querySelector(".pr-slide-img-thumb");
    if (thumb && thumb.src && thumb.src.indexOf("data:") === 0) {
      imageData = thumb.src;
      imageWidth = thumb.naturalWidth || 0;
      imageHeight = thumb.naturalHeight || 0;
    }
  }

  // Delegate to TurasPins shared library
  if (typeof TurasPins !== "undefined") {
    TurasPins.add({
      sectionId: "slides",
      title: titleEl ? titleEl.textContent.trim() : "Added Slide",
      insightText: rendered ? rendered.innerHTML : "",
      imageData: imageData,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      tableHtml: "",
      chartSvg: "",
      pinMode: "all"
    });
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

function updatePrSlidesEmptyState() {
  var container = document.getElementById("pr-slides-container");
  var emptyState = document.getElementById("pr-slides-empty");
  if (!container || !emptyState) return;
  var hasCards = container.querySelectorAll(".pr-slide-card").length > 0;
  emptyState.style.display = hasCards ? "none" : "";
}

// ── Init: Double-click to edit, render on load ───────────────────────────────

document.addEventListener("DOMContentLoaded", function() {
  // Render all config-loaded slides
  renderAllPrSlides();

  // Double-click on rendered content toggles edit mode
  document.addEventListener("dblclick", function(e) {
    var rendered = e.target.closest(".pr-slide-md-rendered");
    if (rendered) {
      var card = rendered.closest(".pr-slide-card");
      if (card) togglePrSlideEdit(card);
    }
  });

  // Blur on editor saves and renders
  document.addEventListener("focusout", function(e) {
    if (e.target.classList && e.target.classList.contains("pr-slide-md-editor")) {
      var card = e.target.closest(".pr-slide-card");
      if (card && card.classList.contains("editing")) {
        togglePrSlideEdit(card);
      }
    }
  });
});
