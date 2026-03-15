/* ============================================================================
 * TurasTracker - Qualitative Slides (Added Slides Tab)
 * ============================================================================
 * Create, edit, reorder, and pin commentary slides with images and markdown.
 * Ported from Turas Tabs for visual consistency.
 * VERSION: 1.0.0
 * ============================================================================ */

/** Simple markdown-to-HTML renderer. */
function renderMarkdown(md) {
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
}

/** Add a new qualitative slide. */
function addQualSlide() {
  var container = document.getElementById("qual-slides-container");
  if (!container) return;
  var id = "qual-slide-" + Date.now();
  var card = document.createElement("div");
  card.className = "qual-slide-card editing";
  card.setAttribute("data-slide-id", id);
  card.innerHTML =
    '<div class="qual-slide-header">' +
      '<div class="qual-slide-number">Slide ' + (container.children.length + 1) + '</div>' +
      '<div class="qual-slide-actions">' +
        '<button title="Add image" onclick="triggerQualImage(\'' + id + '\')">&#x1F5BC; Image</button>' +
        '<button title="Pin to Views" onclick="pinQualSlide(\'' + id + '\')">&#x1F4CC; Pin</button>' +
        '<button title="Move up" onclick="moveQualSlide(\'' + id + '\',\'up\')">&#x25B2;</button>' +
        '<button title="Move down" onclick="moveQualSlide(\'' + id + '\',\'down\')">&#x25BC;</button>' +
        '<button title="Remove slide" style="color:#e8614d;" onclick="removeQualSlide(\'' + id + '\')">&#x2715;</button>' +
      '</div>' +
    '</div>' +
    '<div class="qual-slide-body">' +
      '<div class="qual-slide-image-area" style="display:none;">' +
        '<img class="qual-slide-image"/>' +
        '<div class="qual-slide-image-actions">' +
          '<button class="qual-upload-btn" onclick="removeQualImage(\'' + id + '\')">&times; Remove</button>' +
        '</div>' +
      '</div>' +
      '<input type="file" class="qual-img-input" accept="image/png,image/jpeg,image/gif,image/webp" style="display:none;" onchange="handleQualImage(\'' + id + '\', this)">' +
      '<div class="qual-slide-editor" contenteditable="true" data-placeholder="Enter slide content... (**bold**, *italic*, - bullets, ## headings)" oninput="syncQualStore(\'' + id + '\')"></div>' +
      '<textarea class="qual-md-store" style="display:none;"></textarea>' +
      '<textarea class="qual-img-store" style="display:none;"></textarea>' +
    '</div>';
  container.appendChild(card);
  card.querySelector(".qual-slide-editor").focus();
  updateQualEmptyState();
  saveQualSlidesData();
}

/** Trigger image file input for a slide. */
function triggerQualImage(slideId) {
  var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  var input = card.querySelector(".qual-img-input");
  if (input) input.click();
}

/** Handle image selection — resize and store as base64. */
function handleQualImage(slideId, input) {
  if (!input.files || !input.files[0]) return;
  var file = input.files[0];

  if (file.size > 5 * 1024 * 1024) {
    alert("Image too large (" + (file.size / 1024 / 1024).toFixed(1) + "MB). Maximum is 5MB.");
    input.value = "";
    return;
  }

  var reader = new FileReader();
  reader.onload = function(e) {
    var img = new Image();
    img.onerror = function() {};
    img.onload = function() {
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

      var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
      if (!card) return;
      var store = card.querySelector(".qual-img-store");
      if (store) {
        store.value = dataUrl;
        store.setAttribute("data-img-w", w);
        store.setAttribute("data-img-h", h);
      }
      var imgArea = card.querySelector(".qual-slide-image-area");
      var thumb = card.querySelector(".qual-slide-image");
      if (thumb) thumb.src = dataUrl;
      if (imgArea) imgArea.style.display = "";
      saveQualSlidesData();
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
  input.value = "";
}

/** Remove image from a slide. */
function removeQualImage(slideId) {
  var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  var store = card.querySelector(".qual-img-store");
  if (store) store.value = "";
  var imgArea = card.querySelector(".qual-slide-image-area");
  if (imgArea) imgArea.style.display = "none";
  var thumb = card.querySelector(".qual-slide-image");
  if (thumb) thumb.src = "";
  saveQualSlidesData();
}

/** Remove a slide. */
function removeQualSlide(slideId) {
  var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
  if (card && confirm("Remove this slide?")) {
    card.remove();
    updateQualEmptyState();
    renumberQualSlides();
    saveQualSlidesData();
  }
}

/** Move a slide up or down. */
function moveQualSlide(slideId, direction) {
  var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  if (direction === "up" && card.previousElementSibling) {
    card.parentNode.insertBefore(card, card.previousElementSibling);
  } else if (direction === "down" && card.nextElementSibling) {
    card.parentNode.insertBefore(card.nextElementSibling, card);
  }
  renumberQualSlides();
  saveQualSlidesData();
}

/** Pin a slide to Pinned Views. */
function pinQualSlide(slideId) {
  var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  var numberEl = card.querySelector(".qual-slide-number");
  var editor = card.querySelector(".qual-slide-editor");
  var content = editor ? editor.innerHTML : "";

  var imgStore = card.querySelector(".qual-img-store");
  var imageData = (imgStore && imgStore.value) ? imgStore.value : null;
  var imageWidth = imgStore ? parseInt(imgStore.getAttribute("data-img-w")) || 0 : 0;
  var imageHeight = imgStore ? parseInt(imgStore.getAttribute("data-img-h")) || 0 : 0;

  if (typeof pinnedViews === "undefined") return;

  var pin = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    pinType: "text_box",
    qCode: null,
    qTitle: numberEl ? numberEl.textContent.trim() : "Added Slide",
    bannerGroup: null, bannerLabel: null,
    selectedColumns: null, excludedRows: null,
    insightText: content,
    imageData: imageData,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    sortState: null,
    tableHtml: null, chartSvg: null, baseText: null,
    timestamp: Date.now(),
    order: pinnedViews.length
  };
  pinnedViews.push(pin);
  if (typeof savePinnedData === "function") savePinnedData();
  if (typeof renderPinnedCards === "function") renderPinnedCards();
  if (typeof updatePinBadge === "function") updatePinBadge();
}

/** Pin all slides to Views. */
function pinAllQualSlides() {
  var cards = document.querySelectorAll(".qual-slide-card");
  if (cards.length === 0) return;
  cards.forEach(function(card) {
    var slideId = card.getAttribute("data-slide-id");
    if (slideId) pinQualSlide(slideId);
  });
}

/** Sync editor content to hidden store. */
function syncQualStore(slideId) {
  var card = document.querySelector('.qual-slide-card[data-slide-id="' + slideId + '"]');
  if (!card) return;
  var editor = card.querySelector(".qual-slide-editor");
  var store = card.querySelector(".qual-md-store");
  if (editor && store) store.value = editor.innerHTML;
}

/** Renumber slide headers. */
function renumberQualSlides() {
  var cards = document.querySelectorAll("#qual-slides-container .qual-slide-card");
  cards.forEach(function(card, i) {
    var numEl = card.querySelector(".qual-slide-number");
    if (numEl) numEl.textContent = "Slide " + (i + 1);
  });
}

/** Show/hide empty state. */
function updateQualEmptyState() {
  var container = document.getElementById("qual-slides-container");
  var emptyState = document.getElementById("qual-empty-state");
  if (!container || !emptyState) return;
  var hasCards = container.querySelectorAll(".qual-slide-card").length > 0;
  emptyState.style.display = hasCards ? "none" : "";
}

/** Save all slides data to hidden JSON store for persistence. */
function saveQualSlidesData() {
  var store = document.getElementById("qual-slides-data");
  if (!store) return;
  var data = [];
  document.querySelectorAll("#qual-slides-container .qual-slide-card").forEach(function(card) {
    var editor = card.querySelector(".qual-slide-editor");
    var imgStore = card.querySelector(".qual-img-store");
    var numEl = card.querySelector(".qual-slide-number");
    data.push({
      id: card.getAttribute("data-slide-id"),
      title: numEl ? numEl.textContent.trim() : "",
      content: editor ? editor.innerHTML : "",
      image: (imgStore && imgStore.value) ? imgStore.value : null,
      imageWidth: imgStore ? parseInt(imgStore.getAttribute("data-img-w")) || 0 : 0,
      imageHeight: imgStore ? parseInt(imgStore.getAttribute("data-img-h")) || 0 : 0
    });
  });
  store.textContent = JSON.stringify(data);
}

/** Restore slides from JSON store (called on page load). */
function restoreQualSlides() {
  var store = document.getElementById("qual-slides-data");
  if (!store) return;
  try {
    var data = JSON.parse(store.textContent);
    if (!Array.isArray(data) || data.length === 0) return;
    data.forEach(function(slide) {
      addQualSlide();
      var container = document.getElementById("qual-slides-container");
      var card = container.lastElementChild;
      if (!card) return;
      card.setAttribute("data-slide-id", slide.id);
      var editor = card.querySelector(".qual-slide-editor");
      if (editor) editor.innerHTML = slide.content || "";
      var numEl = card.querySelector(".qual-slide-number");
      if (numEl && slide.title) numEl.textContent = slide.title;
      if (slide.image) {
        var imgStore = card.querySelector(".qual-img-store");
        if (imgStore) {
          imgStore.value = slide.image;
          imgStore.setAttribute("data-img-w", slide.imageWidth || 0);
          imgStore.setAttribute("data-img-h", slide.imageHeight || 0);
        }
        var imgArea = card.querySelector(".qual-slide-image-area");
        var thumb = card.querySelector(".qual-slide-image");
        if (thumb) thumb.src = slide.image;
        if (imgArea) imgArea.style.display = "";
      }
    });
  } catch(e) {}
}

// Auto-restore on DOMContentLoaded
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", restoreQualSlides);
} else {
  restoreQualSlides();
}
