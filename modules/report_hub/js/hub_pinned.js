/**
 * Unified Pinned Views Manager
 *
 * Collects pins from all embedded reports into a single curated view.
 * Supports section dividers for narrative structure.
 */

(function() {
  "use strict";

  // Unified pin store: array of {type, source, id, ...data}
  ReportHub.pinnedItems = [];

  /**
   * Add a pin from a source report
   * @param {string} source - Report key (e.g., "tracker", "tabs")
   * @param {object} pinObj - Pin data from the source report
   */
  ReportHub.addPin = function(source, pinObj) {
    pinObj.source = source;
    pinObj.type = "pin";
    if (!pinObj.id) {
      pinObj.id = "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5);
    }
    pinObj.timestamp = pinObj.timestamp || Date.now();
    ReportHub.pinnedItems.push(pinObj);
    ReportHub.renderPinnedCards();
    ReportHub.updatePinBadge();
    ReportHub.savePinnedData();
  };

  /**
   * Remove a pin by ID
   * @param {string} pinId
   */
  ReportHub.removePin = function(pinId) {
    var idx = -1;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) {
        idx = i;
        break;
      }
    }
    if (idx === -1) return;

    var item = ReportHub.pinnedItems[idx];
    ReportHub.pinnedItems.splice(idx, 1);

    ReportHub.renderPinnedCards();
    ReportHub.updatePinBadge();
    ReportHub.savePinnedData();
  };

  /**
   * Add a section divider
   * @param {string} title - Section title (editable)
   */
  ReportHub.addSection = function(title) {
    title = title || "New Section";
    var section = {
      type: "section",
      title: title,
      id: "sec-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5)
    };
    ReportHub.pinnedItems.push(section);
    ReportHub.renderPinnedCards();
    ReportHub.savePinnedData();
  };

  /**
   * Move an item (pin or section) up or down
   * @param {number} fromIdx
   * @param {number} toIdx
   */
  ReportHub.moveItem = function(fromIdx, toIdx) {
    if (toIdx < 0 || toIdx >= ReportHub.pinnedItems.length) return;
    var item = ReportHub.pinnedItems.splice(fromIdx, 1)[0];
    ReportHub.pinnedItems.splice(toIdx, 0, item);
    ReportHub.renderPinnedCards();
    ReportHub.savePinnedData();
  };

  /**
   * Update the pin count badge
   */
  ReportHub.updatePinBadge = function() {
    var count = 0;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].type === "pin") count++;
    }
    var badge = document.getElementById("hub-pin-count");
    if (badge) {
      badge.textContent = count;
      badge.style.display = count > 0 ? "" : "none";
    }
  };

  /**
   * Save pinned data to the hidden JSON store
   */
  ReportHub.savePinnedData = function() {
    var store = document.getElementById("hub-pinned-data");
    if (store) {
      store.textContent = JSON.stringify(ReportHub.pinnedItems);
    }
  };

  /**
   * Hydrate pinned views from the JSON store on page load
   */
  ReportHub.hydratePinnedViews = function() {
    var store = document.getElementById("hub-pinned-data");
    if (!store) return;
    try {
      var data = JSON.parse(store.textContent);
      if (Array.isArray(data) && data.length > 0) {
        ReportHub.pinnedItems = data;
        ReportHub.renderPinnedCards();
        ReportHub.updatePinBadge();

        // Multi-pin: no need to restore per-report pin button states
      }
    } catch (e) {
      console.warn("[Turas Report Hub] Failed to parse pinned data:", e.message);
    }
  };

  /**
   * Render all pinned cards and section dividers
   */
  ReportHub.renderPinnedCards = function() {
    var container = document.getElementById("hub-pinned-cards");
    var emptyState = document.getElementById("hub-pinned-empty");
    var toolbar = document.getElementById("hub-pinned-toolbar");

    if (!container) return;

    var pinCount = 0;
    for (var c = 0; c < ReportHub.pinnedItems.length; c++) {
      if (ReportHub.pinnedItems[c].type === "pin") pinCount++;
    }

    if (pinCount === 0) {
      container.innerHTML = "";
      if (emptyState) emptyState.style.display = "";
      if (toolbar) toolbar.style.display = "none";
      return;
    }

    if (emptyState) emptyState.style.display = "none";
    if (toolbar) toolbar.style.display = "";

    var html = "";
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      var item = ReportHub.pinnedItems[i];

      if (item.type === "section") {
        html += buildSectionDividerHTML(item, i);
      } else if (item.type === "pin") {
        html += buildPinCardHTML(item, i);
      }
    }

    container.innerHTML = html;
  };

  /**
   * Build HTML for a section divider
   */
  function buildSectionDividerHTML(section, idx) {
    var total = ReportHub.pinnedItems.length;
    return '<div class="hub-section-divider" data-idx="' + idx + '">' +
      '<div class="hub-section-title" contenteditable="true" ' +
        'onblur="ReportHub.updateSectionTitle(' + idx + ', this.textContent)">' +
        escapeHtml(section.title) + '</div>' +
      '<div class="hub-section-actions">' +
        (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx - 1) + ')" title="Move up">\u25B2</button>' : '') +
        (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx + 1) + ')" title="Move down">\u25BC</button>' : '') +
        '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + section.id + '\')" title="Remove section">\u00D7</button>' +
      '</div>' +
    '</div>';
  }

  /**
   * Lightweight markdown renderer (matches tabs module renderMarkdown).
   * Handles: **bold**, *italic*, ## headings, > blockquotes, - bullets, paragraphs.
   */
  function hubRenderMarkdown(md) {
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

  /** Detect whether a string contains HTML tags */
  function containsHtml(str) {
    return /<[a-z][\s\S]*>/i.test(str);
  }

  /** Expose markdown renderer for hub slides */
  ReportHub.renderMarkdown = hubRenderMarkdown;

  /**
   * Build HTML for a pin card
   */
  function buildPinCardHTML(pin, idx) {
    var total = ReportHub.pinnedItems.length;

    // Source badge: use sourceLabel if available, fall back to generic type label
    var badgeLabel = pin.sourceLabel || "";
    var badgeClass = "hub-badge-tabs";
    var sourceType = pin.sourceType || pin.source;
    if (sourceType === "tracker") {
      badgeClass = "hub-badge-tracker";
      if (!badgeLabel) badgeLabel = "Tracker";
    } else if (sourceType === "confidence") {
      badgeClass = "hub-badge-confidence";
      if (!badgeLabel) badgeLabel = "Confidence";
    } else if (pin.source === "overview") {
      badgeClass = "hub-badge-overview";
      if (!badgeLabel) badgeLabel = "Overview";
    } else {
      if (!badgeLabel) badgeLabel = "Crosstabs";
    }
    var sourceBadge = '<span class="hub-source-badge ' + badgeClass + '">' + escapeHtml(badgeLabel) + '</span>';

    var title = pin.title || pin.metricLabel || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || "";

    var html = '<div class="hub-pin-card" data-pin-id="' + pin.id + '" data-idx="' + idx + '">' +
      '<div class="hub-pin-header">' +
        sourceBadge +
        '<span class="hub-pin-title">' + escapeHtml(title) + '</span>' +
        '<div class="hub-pin-actions">' +
          '<button class="hub-action-btn" onclick="ReportHub.exportPinCard(\'' + pin.id + '\')" title="Export as PNG">\uD83D\uDCF8</button>' +
          (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx - 1) + ')" title="Move up">\u25B2</button>' : '') +
          (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx + 1) + ')" title="Move down">\u25BC</button>' : '') +
          '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + pin.id + '\')" title="Remove">\u00D7</button>' +
        '</div>' +
      '</div>';

    if (subtitle) {
      html += '<div class="hub-pin-subtitle">' + escapeHtml(subtitle) + '</div>';
    }

    // Insight area with markdown support (dual-mode: rendered view + editor)
    var insightRaw = pin.insight || "";
    // Determine rendered HTML: if insight already contains HTML (from qual slides), use directly;
    // otherwise treat as markdown and render it
    var renderedHtml = "";
    var editorText = "";
    if (insightRaw) {
      if (containsHtml(insightRaw)) {
        renderedHtml = insightRaw;
        // Extract plain text for the editor (reverse: HTML -> text for re-editing)
        var tmp = document.createElement("div");
        tmp.innerHTML = insightRaw;
        editorText = tmp.textContent.trim();
      } else {
        editorText = insightRaw;
        renderedHtml = hubRenderMarkdown(insightRaw);
      }
    }
    html += '<div class="hub-pin-insight" data-pin-id="' + pin.id + '">' +
      '<div class="hub-insight-rendered hub-md-content" ' +
        'ondblclick="ReportHub.toggleInsightEdit(\'' + pin.id + '\')" ' +
        'data-placeholder="Double-click to add insight...">' +
        (renderedHtml || '') +
      '</div>' +
      '<textarea class="hub-insight-editor" style="display:none" ' +
        'onblur="ReportHub.finishInsightEdit(\'' + pin.id + '\')">' +
        escapeHtml(editorText) +
      '</textarea>' +
    '</div>';

    // Image (custom slide image — always shown)
    if (pin.imageData) {
      html += '<div style="margin-bottom:12px;text-align:center;">' +
        '<img src="' + pin.imageData + '" style="max-width:100%;max-height:500px;border-radius:6px;border:1px solid #e2e8f0;" />' +
      '</div>';
    }

    // Respect pinMode: "all" (default), "chart_insight", "table_insight"
    var mode = pin.pinMode || "all";
    var showChart = (mode === "all" || mode === "chart_insight");
    var showTable = (mode === "all" || mode === "table_insight");

    // Chart (if captured and mode allows)
    if (pin.chartSvg && pin.chartVisible !== false && showChart) {
      html += '<div class="hub-pin-chart">' + pin.chartSvg + '</div>';
    }

    // PNG snapshot (hidden – used only for export, not displayed on screen)
    if (pin.pngDataUrl) {
      html += '<div class="hub-pin-snapshot" style="display:none"><img src="' + pin.pngDataUrl + '" alt="Pinned view"></div>';
    }

    // Table (if captured and mode allows)
    if (pin.tableHtml && showTable) {
      html += '<div class="hub-pin-table">' + pin.tableHtml + '</div>';
    }

    html += '</div>';
    return html;
  }

  /**
   * Update a section's title after editing
   */
  ReportHub.updateSectionTitle = function(idx, newTitle) {
    if (idx >= 0 && idx < ReportHub.pinnedItems.length &&
        ReportHub.pinnedItems[idx].type === "section") {
      ReportHub.pinnedItems[idx].title = newTitle.trim() || "Untitled Section";
      ReportHub.savePinnedData();
    }
  };

  /**
   * Toggle insight into edit mode (double-click on rendered view)
   */
  ReportHub.toggleInsightEdit = function(pinId) {
    var container = document.querySelector('.hub-pin-insight[data-pin-id="' + pinId + '"]');
    if (!container) return;
    var rendered = container.querySelector(".hub-insight-rendered");
    var editor = container.querySelector(".hub-insight-editor");
    if (!rendered || !editor) return;
    rendered.style.display = "none";
    editor.style.display = "";
    editor.focus();
  };

  /**
   * Finish insight editing: re-render markdown and save
   */
  ReportHub.finishInsightEdit = function(pinId) {
    var container = document.querySelector('.hub-pin-insight[data-pin-id="' + pinId + '"]');
    if (!container) return;
    var rendered = container.querySelector(".hub-insight-rendered");
    var editor = container.querySelector(".hub-insight-editor");
    if (!rendered || !editor) return;
    var md = editor.value.trim();
    rendered.innerHTML = md ? hubRenderMarkdown(md) : "";
    rendered.style.display = "";
    editor.style.display = "none";
    // Save the markdown source (not HTML) so it round-trips correctly
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) {
        ReportHub.pinnedItems[i].insight = md;
        break;
      }
    }
    ReportHub.savePinnedData();
  };

  /**
   * Sync a pin's insight text after editing (legacy compat)
   */
  ReportHub.syncPinInsight = function(pinId, text) {
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) {
        ReportHub.pinnedItems[i].insight = text.trim();
        ReportHub.savePinnedData();
        break;
      }
    }
  };

  /**
   * Pin an overview summary editor's content
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
    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
      title: title,
      sourceLabel: "Overview",
      insight: text,
      timestamp: Date.now()
    };
    ReportHub.addPin("overview", pinObj);
  };

  /**
   * Pin a hub-level executive summary or background text
   * @param {string} boxId - "executive-summary" or "background"
   */
  ReportHub.pinHubText = function(boxId) {
    var rendered = document.getElementById("hub-text-rendered-" + boxId);
    var editor = document.getElementById("hub-text-editor-" + boxId);
    if (!rendered || !editor) return;
    // Re-render before pinning to capture latest edits
    rendered.innerHTML = hubRenderMarkdown(editor.value);
    var text = rendered.innerHTML.trim();
    if (!text) { alert("Add text before pinning."); return; }
    // Derive title from the section header label (works for both hub-level and per-report sections)
    var section = document.getElementById("hub-text-" + boxId);
    var labelEl = section ? section.querySelector(".hub-summary-label") : null;
    var title = labelEl ? labelEl.textContent.trim() : boxId;
    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
      title: title,
      sourceLabel: "Overview",
      insight: text,
      timestamp: Date.now()
    };
    ReportHub.addPin("overview", pinObj);
  };

  /**
   * Toggle hub text section into edit mode
   * @param {string} boxId - Text section ID
   */
  ReportHub.toggleHubTextEdit = function(boxId) {
    var rendered = document.getElementById("hub-text-rendered-" + boxId);
    var editor = document.getElementById("hub-text-editor-" + boxId);
    if (!rendered || !editor) return;
    rendered.style.display = "none";
    editor.style.display = "";
    editor.focus();
  };

  /**
   * Finish hub text section editing: re-render markdown and persist
   * @param {string} boxId - Text section ID
   */
  ReportHub.finishHubTextEdit = function(boxId) {
    var rendered = document.getElementById("hub-text-rendered-" + boxId);
    var editor = document.getElementById("hub-text-editor-" + boxId);
    if (!rendered || !editor) return;
    rendered.innerHTML = hubRenderMarkdown(editor.value);
    rendered.style.display = "";
    editor.style.display = "none";
  };

  /**
   * Render all hub text sections on page load (executive summary, background)
   */
  ReportHub.renderHubTextSections = function() {
    document.querySelectorAll(".hub-text-section").forEach(function(section) {
      var editor = section.querySelector(".hub-text-editor");
      var rendered = section.querySelector(".hub-text-rendered");
      if (rendered && editor) {
        rendered.innerHTML = hubRenderMarkdown(editor.value);
      }
    });
    // Also render About notes section if present
    var aboutEditor = document.getElementById("hub-about-notes-editor");
    var aboutRendered = document.getElementById("hub-about-notes-rendered");
    if (aboutRendered && aboutEditor) {
      aboutRendered.innerHTML = hubRenderMarkdown(aboutEditor.value);
    }
  };

  /**
   * Toggle About notes into edit mode (double-click to edit)
   */
  ReportHub.toggleHubAboutNotesEdit = function() {
    var rendered = document.getElementById("hub-about-notes-rendered");
    var editor = document.getElementById("hub-about-notes-editor");
    if (!rendered || !editor) return;
    rendered.style.display = "none";
    editor.style.display = "";
    editor.focus();
  };

  /**
   * Finish About notes editing: re-render markdown
   */
  ReportHub.finishHubAboutNotesEdit = function() {
    var rendered = document.getElementById("hub-about-notes-rendered");
    var editor = document.getElementById("hub-about-notes-editor");
    if (!rendered || !editor) return;
    rendered.innerHTML = hubRenderMarkdown(editor.value);
    rendered.style.display = "";
    editor.style.display = "none";
  };

  /**
   * Pin a hub-level qualitative slide
   * @param {string} slideId - Slide element ID
   */
  ReportHub.pinHubSlide = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var titleEl = card.querySelector(".hub-slide-title");
    var editor = card.querySelector(".hub-slide-editor");
    var rendered = card.querySelector(".hub-slide-rendered");
    // Re-render before pinning
    if (rendered && editor) rendered.innerHTML = hubRenderMarkdown(editor.value);
    // Capture slide image if present
    // .value captures manual uploads; .textContent captures config-embedded images
    var imgStore = card.querySelector(".hub-slide-img-store");
    var imageData = null;
    if (imgStore) {
      var val = imgStore.value || imgStore.textContent || "";
      if (val.length > 0) imageData = val;
    }
    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
      title: titleEl ? (titleEl.value || titleEl.textContent || "").trim() || "Slide" : "Slide",
      sourceLabel: "Overview",
      insight: rendered ? rendered.innerHTML : "",
      imageData: imageData,
      tableHtml: null,
      chartSvg: null,
      timestamp: Date.now()
    };
    ReportHub.addPin("overview", pinObj);
  };

  /**
   * Toggle hub slide edit mode
   * @param {string} slideId - Slide element ID
   */
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

  /**
   * Finish hub slide editing: re-render markdown
   * @param {string} slideId - Slide element ID
   */
  ReportHub.finishHubSlideEdit = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var editor = card.querySelector(".hub-slide-editor");
    var rendered = card.querySelector(".hub-slide-rendered");
    if (!editor || !rendered) return;
    rendered.innerHTML = hubRenderMarkdown(editor.value);
    rendered.style.display = "";
    editor.style.display = "none";
  };

  /**
   * Update a hub slide's title
   * @param {string} slideId - Slide element ID
   * @param {string} newTitle - New title text
   */
  ReportHub.updateHubSlideTitle = function(slideId, newTitle) {
    // Title is stored in the input itself, no separate data store needed
    // This handler is available for future persistence if needed
  };

  /**
   * Render all hub slides on page load
   */
  ReportHub.renderHubSlides = function() {
    document.querySelectorAll(".hub-slide-card").forEach(function(card) {
      var editor = card.querySelector(".hub-slide-editor");
      var rendered = card.querySelector(".hub-slide-rendered");
      if (rendered && editor) {
        rendered.innerHTML = hubRenderMarkdown(editor.value);
      }
    });
  };

  /**
   * Add a new insight slide to the Insights & Analysis grid
   */
  ReportHub.addHubSlide = function() {
    var grid = document.getElementById("hub-slides-grid");
    if (!grid) return;
    var slideId = "hub-slide-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5);
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
    // Focus the editor immediately so the user can start typing
    var editor = card.querySelector(".hub-slide-editor");
    if (editor) editor.focus();
  };

  /**
   * Remove a hub slide card from the DOM
   * @param {string} slideId - Slide element ID
   */
  ReportHub.removeHubSlide = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    if (!confirm("Remove this insight slide?")) return;
    card.parentNode.removeChild(card);
  };

  /**
   * Trigger file input for adding an image to a hub slide
   * @param {string} slideId - Slide element ID
   */
  ReportHub.triggerHubSlideImage = function(slideId) {
    var card = document.querySelector('.hub-slide-card[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var input = card.querySelector(".hub-slide-img-input");
    if (input) input.click();
  };

  /**
   * Handle image file selection for a hub slide
   * Reads the file as base64 data URL, stores it, and shows preview.
   * @param {string} slideId - Slide element ID
   * @param {HTMLInputElement} inputEl - The file input element
   */
  ReportHub.handleHubSlideImage = function(slideId, inputEl) {
    var file = inputEl.files && inputEl.files[0];
    if (!file) return;

    // File size guard (5MB raw)
    if (file.size > 5 * 1024 * 1024) {
      alert("Image too large (" + (file.size / 1024 / 1024).toFixed(1) + "MB). Maximum is 5MB.");
      inputEl.value = "";
      return;
    }

    var reader = new FileReader();
    reader.onload = function(e) {
      var img = new Image();
      img.onerror = function() { /* invalid image data — silently skip */ };
      img.onload = function() {
        // Resize to max 800px on longest side + recompress as JPEG 0.7
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
    // Reset file input so the same file can be re-selected
    inputEl.value = "";
  };

  /**
   * Remove the image from a hub slide
   * @param {string} slideId - Slide element ID
   */
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

  // ==========================================================================
  // SVG-Native PNG Export Helpers
  // ==========================================================================
  // Builds pure SVG (no foreignObject), clones chart SVG into <g>, renders
  // tables as SVG rect+text elements. Single reliable code path.
  // ==========================================================================

  /** Wrap text into lines that fit within maxWidth (character-based estimate) */
  function hubWrapTextLines(text, maxWidth, charWidth) {
    if (!text) return [];
    var maxChars = Math.floor(maxWidth / charWidth);
    if (text.length <= maxChars) return [text];
    var words = text.split(" ");
    var lines = [], current = "";
    for (var i = 0; i < words.length; i++) {
      var test = current ? current + " " + words[i] : words[i];
      if (test.length > maxChars && current) {
        lines.push(current);
        current = words[i];
      } else {
        current = test;
      }
    }
    if (current) lines.push(current);
    return lines;
  }

  /** Create SVG <text> with <tspan> lines */
  function hubCreateWrappedText(ns, lines, x, startY, lineHeight, attrs) {
    var el = document.createElementNS(ns, "text");
    el.setAttribute("x", x);
    for (var key in attrs) { el.setAttribute(key, attrs[key]); }
    for (var i = 0; i < lines.length; i++) {
      var tspan = document.createElementNS(ns, "tspan");
      tspan.setAttribute("x", x);
      tspan.setAttribute("y", startY + i * lineHeight);
      tspan.textContent = lines[i];
      el.appendChild(tspan);
    }
    return { element: el, height: lines.length * lineHeight };
  }

  /**
   * Parse insight HTML into structured blocks for formatted SVG rendering.
   * Each block has a type ("heading", "bullet", "quote", "para") and an
   * array of text runs with inline formatting ({text, bold, italic}).
   */
  function hubParseInsightHTML(html) {
    if (!html || !html.trim()) return [];
    var div = document.createElement("div");
    div.innerHTML = html;
    var blocks = [];

    function extractRuns(node, baseCtx) {
      var runs = [];
      (function walk(n, ctx) {
        if (n.nodeType === 3) {
          var t = n.textContent;
          if (t) runs.push({ text: t, bold: ctx.bold, italic: ctx.italic });
          return;
        }
        if (n.nodeType !== 1) return;
        var tag = n.tagName.toLowerCase();
        var nc = { bold: ctx.bold, italic: ctx.italic };
        if (tag === "strong" || tag === "b") nc.bold = true;
        if (tag === "em" || tag === "i") nc.italic = true;
        if (tag === "br") { runs.push({ text: "\n", bold: false, italic: false }); return; }
        for (var i = 0; i < n.childNodes.length; i++) walk(n.childNodes[i], nc);
      })(node, baseCtx || { bold: false, italic: false });
      return runs;
    }

    for (var i = 0; i < div.childNodes.length; i++) {
      var el = div.childNodes[i];
      if (el.nodeType === 3) {
        var t = el.textContent.trim();
        if (t) blocks.push({ type: "para", runs: [{ text: t, bold: false, italic: false }] });
        continue;
      }
      if (el.nodeType !== 1) continue;
      var tag = el.tagName.toLowerCase();

      if (/^h[1-6]$/.test(tag)) {
        blocks.push({ type: "heading", level: parseInt(tag[1]), runs: extractRuns(el, { bold: true, italic: false }) });
      } else if (tag === "ul" || tag === "ol") {
        var items = [];
        for (var j = 0; j < el.children.length; j++) {
          if (el.children[j].tagName.toLowerCase() === "li") items.push(el.children[j]);
        }
        for (var j = 0; j < items.length; j++) {
          var prefix = tag === "ol" ? (j + 1) + ". " : "\u2022 ";
          blocks.push({ type: "bullet", prefix: prefix, runs: extractRuns(items[j], { bold: false, italic: false }) });
        }
      } else if (tag === "blockquote") {
        blocks.push({ type: "quote", runs: extractRuns(el, { bold: false, italic: false }) });
      } else if (tag === "p") {
        var runs = extractRuns(el, { bold: false, italic: false });
        if (runs.length > 0) blocks.push({ type: "para", runs: runs });
      } else {
        var runs = extractRuns(el, { bold: false, italic: false });
        if (runs.length > 0) blocks.push({ type: "para", runs: runs });
      }
    }
    return blocks;
  }

  /**
   * Render parsed insight blocks as SVG elements with formatting preserved.
   * Returns { element: SVG <g>, height: total pixel height }
   */
  function hubRenderInsightSVG(ns, blocks, x, startY, maxWidth, charWidth) {
    var g = document.createElementNS(ns, "g");
    var y = startY;
    var lineH = 17;

    for (var b = 0; b < blocks.length; b++) {
      var block = blocks[b];
      var indent = 0;
      var fontSize = 13;
      var isHeading = block.type === "heading";
      var isQuote = block.type === "quote";

      if (isHeading) {
        fontSize = block.level <= 2 ? 15 : 14;
        if (b > 0) y += 6;
      }
      if (block.type === "bullet") indent = 16;
      if (isQuote) indent = 16;

      // Build annotated character array: each char knows its formatting
      var annot = [];
      if (block.prefix) {
        for (var c = 0; c < block.prefix.length; c++) {
          annot.push({ ch: block.prefix[c], bold: isHeading, italic: false });
        }
      }
      for (var r = 0; r < block.runs.length; r++) {
        var run = block.runs[r];
        for (var c = 0; c < run.text.length; c++) {
          annot.push({ ch: run.text[c], bold: run.bold || isHeading, italic: run.italic || isQuote });
        }
      }

      // Collapse whitespace
      var collapsed = [];
      var lastSpace = true;
      for (var ci = 0; ci < annot.length; ci++) {
        if (/\s/.test(annot[ci].ch)) {
          if (!lastSpace) { collapsed.push({ ch: " ", bold: annot[ci].bold, italic: annot[ci].italic }); lastSpace = true; }
        } else {
          collapsed.push(annot[ci]); lastSpace = false;
        }
      }
      while (collapsed.length > 0 && collapsed[collapsed.length - 1].ch === " ") collapsed.pop();
      if (collapsed.length === 0) continue;

      var fullText = "";
      for (var ci = 0; ci < collapsed.length; ci++) fullText += collapsed[ci].ch;

      // Word wrap
      var effectiveW = maxWidth - indent;
      var maxChars = Math.floor(effectiveW / charWidth);
      var wordBounds = [];
      var ws = -1;
      for (var ci = 0; ci <= fullText.length; ci++) {
        if (ci === fullText.length || fullText[ci] === " ") {
          if (ws >= 0) wordBounds.push({ s: ws, e: ci });
          ws = -1;
        } else { if (ws < 0) ws = ci; }
      }

      var lineRanges = [];
      var lStart = 0, lLen = 0;
      for (var w = 0; w < wordBounds.length; w++) {
        var wb = wordBounds[w];
        var wLen = wb.e - wb.s;
        var needed = lLen === 0 ? wLen : lLen + 1 + wLen;
        if (needed > maxChars && lLen > 0) {
          lineRanges.push({ s: lStart, e: wb.s > 0 ? wb.s : wb.s });
          lStart = wb.s; lLen = wLen;
        } else { lLen = needed; }
      }
      if (lStart < fullText.length) lineRanges.push({ s: lStart, e: fullText.length });

      // Render each line with tspan segments for formatting changes
      for (var li = 0; li < lineRanges.length; li++) {
        var lr = lineRanges[li];
        // Trim leading/trailing spaces from line range
        var ls = lr.s, le = lr.e;
        while (ls < le && fullText[ls] === " ") ls++;
        while (le > ls && fullText[le - 1] === " ") le--;
        if (ls >= le) continue;

        var textEl = document.createElementNS(ns, "text");
        textEl.setAttribute("x", x + indent);
        textEl.setAttribute("y", y);
        textEl.setAttribute("fill", isQuote ? "#64748b" : "#1a2744");
        textEl.setAttribute("font-size", fontSize);

        // Split line into tspan segments at formatting boundaries
        var segStart = ls;
        for (var ci = ls; ci <= le; ci++) {
          var atEnd = (ci === le);
          var fmtChange = !atEnd && ci > ls &&
            (collapsed[ci].bold !== collapsed[ci - 1].bold ||
             collapsed[ci].italic !== collapsed[ci - 1].italic);

          if (fmtChange || atEnd) {
            var segText = fullText.substring(segStart, atEnd ? ci : ci);
            if (segText) {
              var tspan = document.createElementNS(ns, "tspan");
              var fmt = collapsed[segStart];
              if (fmt.bold) tspan.setAttribute("font-weight", "700");
              if (fmt.italic) tspan.setAttribute("font-style", "italic");
              tspan.textContent = segText;
              textEl.appendChild(tspan);
            }
            segStart = ci;
          }
        }

        g.appendChild(textEl);
        y += lineH;
      }

      // Block spacing
      if (block.type === "bullet" && b < blocks.length - 1 && blocks[b + 1].type !== "bullet") y += 4;
      else if (block.type !== "bullet") y += 4;
    }

    return { element: g, height: y - startY };
  }

  /**
   * Extract table data from stored pin HTML.
   * Handles both tracker-style (tk-*) and tabs-style (ct-table) classes.
   */
  function hubExtractPinTableData(tableHtml) {
    if (!tableHtml) return null;
    var tempDiv = document.createElement("div");
    tempDiv.innerHTML = tableHtml;
    var table = tempDiv.querySelector("table");
    if (!table) return null;

    var rows = [];

    // Header row
    var headerCells = [];
    var headerRow = table.querySelector("thead tr");
    if (headerRow) {
      headerRow.querySelectorAll("th").forEach(function(th) {
        if (th.style.display === "none") return;
        // Tabs uses .ct-header-text; tracker uses plain text
        var text = th.querySelector(".ct-header-text");
        headerCells.push(text ? text.textContent.trim() : th.textContent.trim().split("\n")[0].trim());
      });
      if (headerCells.length > 0) {
        rows.push({ cells: headerCells, type: "header" });
      }
    }

    // Body rows
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      if (tr.style.display === "none") return;
      if (tr.classList.contains("ct-row-excluded")) return;

      var rowInfo = { cells: [], type: "data" };

      // Tracker-style rows
      if (tr.classList.contains("tk-base-row")) {
        rowInfo.type = "base";
        var baseLabel = tr.querySelector(".tk-base-label");
        rowInfo.cells.push(baseLabel ? baseLabel.textContent.trim() : "Base");
        tr.querySelectorAll("td.tk-base-cell").forEach(function(td) {
          if (td.style.display === "none") return;
          rowInfo.cells.push(td.textContent.trim());
        });
      } else if (tr.classList.contains("tk-change-row")) {
        rowInfo.type = "change";
        var changeLabel = tr.querySelector(".tk-change-label");
        rowInfo.cells.push(changeLabel ? changeLabel.textContent.trim() : "Change");
        tr.querySelectorAll("td.tk-change-cell").forEach(function(td) {
          if (td.style.display === "none") return;
          rowInfo.cells.push(td.textContent.trim());
        });
      } else if (tr.classList.contains("tk-metric-row")) {
        var segName = tr.getAttribute("data-segment") || "";
        rowInfo.type = segName === "Total" ? "total" : "data";
        var labelEl = tr.querySelector(".tk-metric-label");
        rowInfo.cells.push(labelEl ? labelEl.textContent.trim() : segName);
        tr.querySelectorAll("td.tk-value-cell").forEach(function(td) {
          if (td.style.display === "none") return;
          var valSpan = td.querySelector(".tk-val");
          rowInfo.cells.push(valSpan ? valSpan.textContent.trim() : td.textContent.trim());
        });
        var dot = tr.querySelector(".tk-seg-dot");
        if (dot) rowInfo.colour = dot.style.background || dot.style.backgroundColor || null;

      // Tabs-style rows
      } else if (tr.classList.contains("ct-row-base")) {
        rowInfo.type = "base";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else if (tr.classList.contains("ct-row-mean")) {
        rowInfo.type = "mean";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else if (tr.classList.contains("ct-row-net")) {
        rowInfo.type = "net";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else {
        // Generic row (works for both tracker and tabs)
        tr.querySelectorAll("th, td").forEach(function(cell) {
          if (cell.style.display === "none") return;
          var clone = cell.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn, .ct-sort-indicator").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      }

      if (rowInfo.cells.length > 0) {
        rows.push(rowInfo);
      }
    });

    return rows.length > 0 ? rows : null;
  }

  /** Render table as SVG rect+text elements */
  function hubRenderPinTableSVG(ns, svgParent, tableData, x, y, maxWidth) {
    if (!tableData || tableData.length === 0) return 0;
    var nCols = tableData[0].cells.length;
    if (nCols === 0) return 0;

    var COLOURS = [
      "#323367", "#CC9900", "#2E8B57", "#CD5C5C", "#4682B4",
      "#9370DB", "#D2691E", "#20B2AA", "#8B4513", "#6A5ACD"
    ];

    var baseRowH = 22, headerH = 26, fontSize = 10, padX = 6;
    var firstColW = Math.min(Math.max(maxWidth * 0.25, 140), 260);
    var dataColW = nCols > 1 ? (maxWidth - firstColW) / (nCols - 1) : maxWidth;

    var curY = y;
    var colourIdx = 0;

    tableData.forEach(function(row, ri) {
      var isHeader = row.type === "header";
      var rH = isHeader ? headerH : baseRowH;

      var bgRect = document.createElementNS(ns, "rect");
      bgRect.setAttribute("x", x); bgRect.setAttribute("y", curY);
      bgRect.setAttribute("width", maxWidth); bgRect.setAttribute("height", rH);

      if (isHeader) {
        bgRect.setAttribute("fill", "#1a2744");
      } else if (row.type === "base") {
        bgRect.setAttribute("fill", "#f8f9fa");
      } else if (row.type === "change") {
        bgRect.setAttribute("fill", "#fafbfc");
      } else if (row.type === "total") {
        bgRect.setAttribute("fill", "#f0f0f5");
      } else if (row.type === "mean") {
        bgRect.setAttribute("fill", "#fef9e7");
      } else if (row.type === "net") {
        bgRect.setAttribute("fill", "#f5f0e8");
      } else if (ri % 2 === 0) {
        bgRect.setAttribute("fill", "#ffffff");
      } else {
        bgRect.setAttribute("fill", "#f9fafb");
      }
      svgParent.appendChild(bgRect);

      // Segment colour dot for tracker data/total rows
      if (row.type === "data" || row.type === "total") {
        if (row.colour || tableData.some(function(r) { return r.colour; })) {
          var dotColour = row.colour || COLOURS[colourIdx % COLOURS.length];
          var dot = document.createElementNS(ns, "circle");
          dot.setAttribute("cx", x + 12);
          dot.setAttribute("cy", curY + rH / 2);
          dot.setAttribute("r", "3.5");
          dot.setAttribute("fill", dotColour);
          svgParent.appendChild(dot);
          colourIdx++;
        }
      }

      // Cell text
      row.cells.forEach(function(cellText, ci) {
        var cellW = ci === 0 ? firstColW : dataColW;
        var cellX;
        if (ci === 0) {
          var hasColourDots = tableData.some(function(r) { return r.colour; });
          cellX = (hasColourDots && (row.type === "data" || row.type === "total")) ? x + 22 : x + padX;
        } else {
          cellX = x + firstColW + (ci - 1) * dataColW;
        }

        var textEl = document.createElementNS(ns, "text");
        textEl.setAttribute("y", curY + rH / 2 + 1);
        textEl.setAttribute("dominant-baseline", "central");
        textEl.setAttribute("font-size", fontSize);

        if (ci === 0) {
          textEl.setAttribute("x", cellX);
          textEl.setAttribute("text-anchor", "start");
        } else {
          textEl.setAttribute("x", cellX + cellW / 2);
          textEl.setAttribute("text-anchor", "middle");
        }

        if (isHeader) {
          textEl.setAttribute("fill", "#ffffff");
          textEl.setAttribute("font-weight", "600");
        } else if (row.type === "total" || row.type === "net") {
          textEl.setAttribute("fill", ci === 0 ? "#1a2744" : "#1e293b");
          textEl.setAttribute("font-weight", "600");
        } else if (row.type === "base") {
          textEl.setAttribute("fill", "#666666");
          textEl.setAttribute("font-weight", "600");
          textEl.setAttribute("font-size", fontSize - 1);
        } else if (row.type === "change") {
          textEl.setAttribute("fill", "#888888");
          textEl.setAttribute("font-size", fontSize - 1);
        } else if (row.type === "mean") {
          textEl.setAttribute("fill", "#5c4a2a");
          textEl.setAttribute("font-style", "italic");
        } else {
          textEl.setAttribute("fill", ci === 0 ? "#374151" : "#1e293b");
        }

        var maxChars = Math.floor((cellW - padX * 2) / (fontSize * 0.55));
        if (maxChars > 0 && cellText.length > maxChars) {
          cellText = cellText.substring(0, Math.max(maxChars - 1, 5)) + "\u2026";
        }

        textEl.textContent = cellText;
        svgParent.appendChild(textEl);
      });

      var borderLine = document.createElementNS(ns, "line");
      borderLine.setAttribute("x1", x); borderLine.setAttribute("x2", x + maxWidth);
      borderLine.setAttribute("y1", curY + rH); borderLine.setAttribute("y2", curY + rH);
      borderLine.setAttribute("stroke", "#e2e8f0"); borderLine.setAttribute("stroke-width", "0.5");
      svgParent.appendChild(borderLine);

      curY += rH;
    });

    return curY - y;
  }

  // ==========================================================================
  // Export Functions
  // ==========================================================================

  /**
   * Export a single pin card as a PowerPoint-quality PNG using SVG-native approach.
   * Builds pure SVG: brand bar → title → meta → insight → chart → table → footer.
   * No foreignObject — single reliable code path.
   * @param {string} pinId - Pin ID
   */
  ReportHub.exportPinCard = function(pinId) {
    // Find pin data in the store
    var pin = null;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) { pin = ReportHub.pinnedItems[i]; break; }
    }
    if (!pin) return;

    // If pin has an image, pre-load it to get natural dimensions before building SVG
    if (pin.imageData) {
      var preImg = new Image();
      preImg.onload = function() {
        ReportHub._buildPinExportSVG(pin, preImg.naturalWidth, preImg.naturalHeight);
      };
      preImg.onerror = function() {
        // Image failed to load — export without it
        ReportHub._buildPinExportSVG(pin, 0, 0);
      };
      preImg.src = pin.imageData;
    } else {
      ReportHub._buildPinExportSVG(pin, 0, 0);
    }
  };

  ReportHub._buildPinExportSVG = function(pin, pinImageW, pinImageH) {
    var ns = "http://www.w3.org/2000/svg";
    var W = 1280;
    var fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
    var pad = 20;
    var usableW = W - pad * 2;
    var brandColour = "#323367";

    // ---- Resolve fields (handle both tracker and tabs field names) ----
    var titleText = pin.title || pin.metricTitle || pin.qTitle || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || pin.qTitle || "";
    // For tabs: title is qCode, subtitle is qTitle. Combine for the slide.
    if (pin.source === "tabs" && pin.qCode && pin.qTitle) {
      titleText = pin.qCode + " - " + pin.qTitle;
      subtitle = "";
    }
    var insightRaw = pin.insight || pin.insightText || "";
    // Parse insight HTML into structured blocks for formatted SVG rendering
    var insightHtml = insightRaw;
    if (insightRaw && !containsHtml(insightRaw)) {
      // Plain text — render through markdown first
      insightHtml = hubRenderMarkdown(insightRaw);
    }
    var insightBlocks = hubParseInsightHTML(insightHtml);

    // ---- 1. Title ----
    var titleLines = hubWrapTextLines(titleText, usableW, 9.5);
    var titleLineH = 20;
    var titleStartY = pad + 12;
    var titleBlockH = titleLines.length * titleLineH;

    // ---- 2. Meta line ----
    var metaParts = [];
    // Source badge — use specific label when available
    if (pin.sourceLabel) metaParts.push(pin.sourceLabel);
    else if (pin.source === "tracker") metaParts.push("Tracker");
    else if (pin.source === "tabs") metaParts.push("Crosstabs");
    else if (pin.source === "confidence") metaParts.push("Confidence");
    else if (pin.source === "overview") metaParts.push("Overview");
    // Date
    if (pin.timestamp) metaParts.push(new Date(pin.timestamp).toLocaleDateString());
    // Segments (tracker)
    if (pin.visibleSegments && pin.visibleSegments.length > 0) {
      metaParts.push("Segments: " + pin.visibleSegments.join(", "));
    }
    // Banner (tabs)
    if (pin.bannerLabel) metaParts.push("Banner: " + pin.bannerLabel);
    // Base (tabs)
    if (pin.baseText) metaParts.push("Base: " + pin.baseText);

    var metaText = metaParts.join("  \u00B7  ");
    var metaY = titleStartY + titleBlockH + 4;
    var contentTop = metaY + 12;

    // ---- 3. Insight (pre-render to measure height) ----
    var insightY = contentTop;
    var insightBlockH = 0;
    var insightRendered = null;
    if (insightBlocks.length > 0) {
      insightRendered = hubRenderInsightSVG(ns, insightBlocks, pad + 14, insightY + 18, usableW - 16, 7.5);
      insightBlockH = insightRendered.height + 24;
    }

    // ---- 3b. Image dimensions (config-driven or manually uploaded slide image) ----
    var imageTopY = contentTop + insightBlockH + (insightBlockH > 0 ? 8 : 0);
    var imageDisplayH = 0;
    var imageDisplayW = 0;
    if (pin.imageData && pinImageW > 0 && pinImageH > 0) {
      // Scale image to fit within usable width, preserving aspect ratio
      imageDisplayW = Math.min(usableW, pinImageW);
      var imgScale = imageDisplayW / pinImageW;
      imageDisplayH = Math.round(pinImageH * imgScale);
    }

    // ---- 4. Chart dimensions ----
    // Respect pinMode: "all" (default), "chart_insight", "table_insight"
    var exportMode = pin.pinMode || "all";
    var exportShowChart = (exportMode === "all" || exportMode === "chart_insight");
    var exportShowTable = (exportMode === "all" || exportMode === "table_insight");

    var chartTopY = imageTopY + imageDisplayH + (imageDisplayH > 0 ? 8 : 0);
    var chartDisplayH = 0;
    var chartClone = null;
    var chartScale = 1;

    if (pin.chartSvg && pin.chartVisible !== false && exportShowChart) {
      var chartTempDiv = document.createElement("div");
      chartTempDiv.innerHTML = pin.chartSvg;
      var svgEl = chartTempDiv.querySelector("svg");
      if (svgEl) {
        chartClone = svgEl.cloneNode(true);
        // Resolve CSS variable references in chart SVG
        chartClone.querySelectorAll("*").forEach(function(el) {
          ["fill", "stroke"].forEach(function(attr) {
            var val = el.getAttribute(attr);
            if (val && val.indexOf("var(") !== -1) {
              var match = val.match(/var\(--[^,)]+,\s*([^)]+)\)/);
              if (match) el.setAttribute(attr, match[1].trim());
            }
          });
        });
        var vb = chartClone.getAttribute("viewBox");
        if (vb) {
          var chartVB = vb.split(" ").map(Number);
          chartScale = usableW / chartVB[2];
          chartDisplayH = chartVB[3] * chartScale;
        }
      }
    }

    // ---- 5. Table dimensions ----
    var tableTopY = chartTopY + chartDisplayH + (chartDisplayH > 0 ? 8 : 0);
    var tableData = null;
    var estimatedTableH = 0;

    if (pin.tableHtml && exportShowTable) {
      tableData = hubExtractPinTableData(pin.tableHtml);
      if (tableData && tableData.length > 0) {
        estimatedTableH = 26 + (tableData.length - 1) * 22 + 8;
      }
    }

    // ---- 6. Total height ----
    var totalH = tableTopY + estimatedTableH + pad + 8;
    if (totalH < 200) totalH = 200;

    // ---- Build slide SVG ----
    var svg = document.createElementNS(ns, "svg");
    svg.setAttribute("xmlns", ns);
    svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
    svg.setAttribute("style", "font-family:" + fontFamily + ";");

    // White background
    var bg = document.createElementNS(ns, "rect");
    bg.setAttribute("width", W); bg.setAttribute("height", totalH);
    bg.setAttribute("fill", "#ffffff");
    svg.appendChild(bg);

    // Brand accent bar at top
    var accentBar = document.createElementNS(ns, "rect");
    accentBar.setAttribute("x", "0"); accentBar.setAttribute("y", "0");
    accentBar.setAttribute("width", W); accentBar.setAttribute("height", "4");
    accentBar.setAttribute("fill", brandColour);
    svg.appendChild(accentBar);

    // Title
    var titleResult = hubCreateWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
      { fill: "#1a2744", "font-size": "18", "font-weight": "700" });
    svg.appendChild(titleResult.element);

    // Meta line
    var metaEl = document.createElementNS(ns, "text");
    metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
    metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "12");
    metaEl.textContent = metaText;
    svg.appendChild(metaEl);

    // Insight block (with formatting preserved: headings, bullets, bold, italic)
    if (insightRendered && insightBlockH > 0) {
      var accentH = Math.max(28, insightRendered.height + 12);
      var insBg = document.createElementNS(ns, "rect");
      insBg.setAttribute("x", pad); insBg.setAttribute("y", insightY + 2);
      insBg.setAttribute("width", usableW); insBg.setAttribute("height", accentH);
      insBg.setAttribute("rx", "4"); insBg.setAttribute("fill", "#f0f4ff");
      svg.appendChild(insBg);
      var iBar = document.createElementNS(ns, "rect");
      iBar.setAttribute("x", pad); iBar.setAttribute("y", insightY + 2);
      iBar.setAttribute("width", "4"); iBar.setAttribute("height", accentH);
      iBar.setAttribute("fill", brandColour); iBar.setAttribute("rx", "2");
      svg.appendChild(iBar);
      svg.appendChild(insightRendered.element);
    }

    // Slide image — stored for canvas compositing (not in SVG, which taints canvas)
    var _pinImageData = (pin.imageData && imageDisplayW > 0 && imageDisplayH > 0) ? pin.imageData : null;
    var _pinImageX = pad, _pinImageY = imageTopY;
    var _pinImageW = imageDisplayW, _pinImageH = imageDisplayH;

    // Chart — clone SVG content into <g> element
    if (chartClone && chartDisplayH > 0) {
      var chartG = document.createElementNS(ns, "g");
      chartG.setAttribute("transform", "translate(" + pad + "," + chartTopY + ") scale(" + chartScale + ")");
      while (chartClone.firstChild) chartG.appendChild(chartClone.firstChild);
      svg.appendChild(chartG);
    }

    // Table — rendered as SVG rect+text elements
    if (tableData && tableData.length > 0) {
      var actualTableH = hubRenderPinTableSVG(ns, svg, tableData, pad, tableTopY, usableW);
      var newTotalH = tableTopY + actualTableH + pad + 20;
      if (newTotalH > totalH) {
        totalH = newTotalH;
        bg.setAttribute("height", totalH);
        svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
      }
    }

    // ---- Render SVG to PNG at 3x resolution ----
    var renderScale = 3;
    var svgData = new XMLSerializer().serializeToString(svg);
    var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    var url = URL.createObjectURL(svgBlob);

    var img = new Image();
    img.onerror = function() {
      URL.revokeObjectURL(url);
      console.error("[Hub Pin PNG] SVG render failed for pin: " + pin.id);
      alert("PNG export failed. Please try using Chrome or Edge browser.");
    };
    img.onload = function() {
      var canvas = document.createElement("canvas");
      canvas.width = W * renderScale;
      canvas.height = totalH * renderScale;
      var ctx = canvas.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(url);

      // Composite pin image directly on canvas (avoids SVG <image> taint)
      var _finishExport = function() {
        canvas.toBlob(function(blob) {
          if (!blob) return;
          var slug = titleText.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
          var filename = "pinned_" + slug + ".png";
          var a = document.createElement("a");
          a.href = URL.createObjectURL(blob);
          a.download = filename;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(a.href);
        }, "image/png");
      };

      if (_pinImageData) {
        var pinImg = new Image();
        pinImg.onload = function() {
          ctx.drawImage(pinImg,
            _pinImageX * renderScale, _pinImageY * renderScale,
            _pinImageW * renderScale, _pinImageH * renderScale);
          _finishExport();
        };
        pinImg.onerror = function() {
          _finishExport();
        };
        pinImg.src = _pinImageData;
      } else {
        _finishExport();
      }
    };
    img.src = url;
  };

  /**
   * Export all pinned cards as individual PNGs (sequential download)
   */
  ReportHub.exportAllPins = function() {
    var pins = [];
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].type === "pin") {
        pins.push(ReportHub.pinnedItems[i].id);
      }
    }
    if (pins.length === 0) return;

    var idx = 0;
    function exportNext() {
      if (idx >= pins.length) return;
      ReportHub.exportPinCard(pins[idx]);
      idx++;
      setTimeout(exportNext, 600);
    }
    exportNext();
  };

  /**
   * Download a data URL as a PNG file via Blob (reliable for large images).
   */
  function downloadDataUrlAsPng(dataUrl, filename) {
    try {
      var parts = dataUrl.split(",");
      var mime = parts[0].match(/:(.*?);/)[1];
      var bstr = atob(parts[1]);
      var n = bstr.length;
      var u8 = new Uint8Array(n);
      for (var i = 0; i < n; i++) u8[i] = bstr.charCodeAt(i);
      var blob = new Blob([u8], { type: mime });
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (e) {
      var a2 = document.createElement("a");
      a2.href = dataUrl;
      a2.download = filename;
      document.body.appendChild(a2);
      a2.click();
      document.body.removeChild(a2);
    }
  }

  /**
   * Escape HTML entities
   */
  function escapeHtml(str) {
    if (!str) return "";
    return str.replace(/&/g, "&amp;")
              .replace(/</g, "&lt;")
              .replace(/>/g, "&gt;")
              .replace(/"/g, "&quot;");
  }

})();
