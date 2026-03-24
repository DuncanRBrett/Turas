/**
 * Unified Pinned Views Manager
 *
 * Collects pins from all embedded reports into a single curated view.
 * Supports section dividers for narrative structure.
 */

(function() {
  "use strict";

  /** Strip control characters that are invalid in XML 1.0. */
  function stripInvalidXmlChars(str) {
    return str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "");
  }

  /** Convert SVG string to an Image-loadable URL.
   *  Uses a data URI instead of URL.createObjectURL so that SVG-to-canvas
   *  rendering works reliably on file:// protocol.
   *  Strips invalid XML control characters as a safety net. */
  function svgToImageUrl(svgString) {
    return "data:image/svg+xml;charset=utf-8," + encodeURIComponent(stripInvalidXmlChars(svgString));
  }

  // ---- Configuration constants ----
  var EXPORT_WIDTH         = 1280;   // Export SVG canvas width (px)
  var EXPORT_RENDER_SCALE  = 3;      // Canvas resolution multiplier for crisp PNGs
  var SVG_COMPRESS_DIGITS  = 3;      // Decimal places kept in SVG coordinate compression
  var EXPORT_ALL_DELAY_MS  = 200;    // Delay between sequential multi-pin exports (ms)

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
      pinObj.id = "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7);
    }
    pinObj.timestamp = pinObj.timestamp || Date.now();

    // Compress SVG to reduce storage size (strip excess whitespace/precision)
    if (pinObj.chartSvg) {
      pinObj.chartSvg = compressSvg(pinObj.chartSvg);
    }

    // Strip pngDataUrl — some source reports (e.g. tracker) include a full PNG
    // snapshot alongside the SVG. The hub never displays it and regenerates PNGs
    // from SVG at export time, so storing it is pure waste (~200-500KB per pin).
    delete pinObj.pngDataUrl;

    ReportHub.pinnedItems.push(pinObj);
    ReportHub.renderPinnedCards();
    ReportHub.updatePinBadge();
    ReportHub.savePinnedData();

    // Visual feedback: brief toast confirming pin was added
    var toastLabel = pinObj.sourceLabel || source || "Report";
    var toastTitle = pinObj.title || "View";
    showPinToast("Pinned: " + toastTitle + " (" + toastLabel + ")");
  };

  /** Show a brief confirmation toast for pin actions */
  function showPinToast(message) {
    var existing = document.getElementById("hub-pin-toast");
    if (existing) existing.parentNode.removeChild(existing);
    var toast = document.createElement("div");
    toast.id = "hub-pin-toast";
    toast.textContent = message;
    toast.style.cssText = "position:fixed;bottom:24px;left:50%;transform:translateX(-50%);" +
      "z-index:99999;background:#323367;color:#fff;padding:10px 24px;border-radius:8px;" +
      "font-size:13px;font-weight:500;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;" +
      "box-shadow:0 4px 16px rgba(0,0,0,0.2);opacity:0;transition:opacity 0.3s ease;" +
      "white-space:nowrap;max-width:90vw;overflow:hidden;text-overflow:ellipsis;";
    document.body.appendChild(toast);
    toast.offsetHeight;
    toast.style.opacity = "1";
    setTimeout(function() {
      toast.style.opacity = "0";
      setTimeout(function() { if (toast.parentNode) toast.parentNode.removeChild(toast); }, 300);
    }, 2500);
  }

  /** Compress SVG string by removing unnecessary whitespace and reducing coordinate precision.
   *  Preserves 3 decimal places to maintain sub-pixel text alignment quality.
   *  Excludes whitespace between text/tspan elements to preserve label spacing. */
  function compressSvg(svg) {
    // Collapse whitespace between tags — but NOT between </tspan> and <tspan>,
    // or between </text> and <text>, where whitespace is semantically meaningful.
    svg = svg.replace(/>([\s]+)</g, function(match, ws, offset) {
      // Look at what comes before > and after <
      var before = svg.substring(Math.max(0, offset - 7), offset + 1);
      var after = svg.substring(offset + match.length - 1, offset + match.length + 7);
      if (/tspan>$/.test(before) || /^<tspan/.test(after) ||
          /text>$/.test(before) || /^<text/.test(after)) {
        return ">" + (ws.indexOf("\n") !== -1 ? " " : ws.substring(0, 1)) + "<";
      }
      return "><";
    });
    // Reduce decimal precision to 3 places in coordinate/path attributes only.
    // Global replacement would corrupt data labels like "123.4567%" inside <text>.
    var coordAttrs = /\b(d|x|y|x1|y1|x2|y2|cx|cy|r|rx|ry|width|height|viewBox|transform|points|offset|dx|dy|style)="([^"]*)"/g;
    svg = svg.replace(coordAttrs, function(full, attr, val) {
      return attr + '="' + val.replace(/(\d+\.\d{3})\d+/g, "$1") + '"';
    });
    // Remove empty style/class attributes
    svg = svg.replace(/\s+(style|class)=""/g, "");
    return svg;
  }

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
      id: "sec-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7)
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
   * Move an item by ID in a given direction.
   * Safer than index-based moveItem because the ID is stable across re-renders.
   * @param {string} itemId - Pin or section ID
   * @param {number} direction - -1 for up, +1 for down
   */
  ReportHub.moveItemById = function(itemId, direction) {
    var fromIdx = -1;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === itemId) { fromIdx = i; break; }
    }
    if (fromIdx === -1) return;
    var toIdx = fromIdx + direction;
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
      if (!Array.isArray(data)) {
        console.warn("[Turas Report Hub] Pinned data is not an array, ignoring.");
        return;
      }
      // Validate each item — filter out corrupted entries
      var valid = [];
      for (var i = 0; i < data.length; i++) {
        var item = data[i];
        if (!item || typeof item !== "object") continue;
        if (!item.type || !item.id) continue;
        if (item.type !== "pin" && item.type !== "section") continue;
        // Strip legacy pngDataUrl to save space on re-save
        if (item.pngDataUrl) delete item.pngDataUrl;
        valid.push(item);
      }
      if (valid.length > 0) {
        ReportHub.pinnedItems = valid;
        ReportHub.renderPinnedCards();
        ReportHub.updatePinBadge();
      }
      if (valid.length < data.length) {
        console.warn("[Turas Report Hub] Filtered " + (data.length - valid.length) +
          " corrupted pin entries on load.");
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
    var sid = escapeHtml(section.id);
    return '<div class="hub-section-divider" data-idx="' + idx + '" data-item-id="' + sid + '" draggable="true" data-pin-drag-idx="' + idx + '">' +
      '<div class="hub-section-title" contenteditable="true" ' +
        'onpaste="event.preventDefault();document.execCommand(\'insertText\',false,event.clipboardData.getData(\'text/plain\'))" ' +
        'onblur="ReportHub.updateSectionTitleById(\'' + sid + '\', this.textContent)">' +
        escapeHtml(section.title) + '</div>' +
      '<div class="hub-section-actions">' +
        (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + sid + '\',-1)" title="Move up">\u25B2</button>' : '') +
        (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + sid + '\',1)" title="Move down">\u25BC</button>' : '') +
        '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + sid + '\')" title="Remove section">\u00D7</button>' +
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
    var badgeClass = "hub-badge-default";
    var sourceType = pin.sourceType || pin.source || "";
    var badgeMap = {
      tracker:    { cls: "hub-badge-tracker",    label: "Tracker" },
      tabs:       { cls: "hub-badge-tabs",       label: "Crosstabs" },
      confidence: { cls: "hub-badge-confidence", label: "Confidence" },
      conjoint:   { cls: "hub-badge-conjoint",   label: "Conjoint" },
      maxdiff:    { cls: "hub-badge-maxdiff",    label: "MaxDiff" },
      pricing:    { cls: "hub-badge-pricing",    label: "Pricing" },
      segment:    { cls: "hub-badge-segment",    label: "Segmentation" },
      catdriver:  { cls: "hub-badge-catdriver",  label: "Cat Driver" },
      keydriver:  { cls: "hub-badge-keydriver",  label: "Key Driver" },
      weighting:  { cls: "hub-badge-weighting",  label: "Weighting" },
      overview:   { cls: "hub-badge-overview",   label: "Overview" }
    };
    if (badgeMap[sourceType]) {
      badgeClass = badgeMap[sourceType].cls;
      if (!badgeLabel) badgeLabel = badgeMap[sourceType].label;
    } else {
      if (!badgeLabel) badgeLabel = sourceType || "Report";
    }
    var sourceBadge = '<span class="hub-source-badge ' + badgeClass + '">' + escapeHtml(badgeLabel) + '</span>';

    var title = pin.title || pin.metricLabel || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || "";

    var pid = escapeHtml(pin.id);
    var html = '<div class="hub-pin-card" data-pin-id="' + pid + '" data-idx="' + idx + '" draggable="true" data-pin-drag-idx="' + idx + '">' +
      '<div class="hub-pin-header">' +
        sourceBadge +
        '<span class="hub-pin-title">' + escapeHtml(title) + '</span>' +
        '<div class="hub-pin-actions">' +
          '<button class="hub-action-btn" onclick="ReportHub.exportPinCard(\'' + pid + '\')" title="Export as PNG">\uD83D\uDCF8</button>' +
          (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + pid + '\',-1)" title="Move up">\u25B2</button>' : '') +
          (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + pid + '\',1)" title="Move down">\u25BC</button>' : '') +
          '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + pid + '\')" title="Remove">\u00D7</button>' +
        '</div>' +
      '</div>';

    if (subtitle) {
      html += '<div class="hub-pin-subtitle">' + escapeHtml(subtitle) + '</div>';
    }

    // Insight area with markdown support (dual-mode: rendered view + editor)
    // Some modules use 'insightText', others use 'insight'
    var insightRaw = pin.insight || pin.insightText || "";
    // Determine rendered HTML: if insight already contains HTML (from qual slides), use directly;
    // otherwise treat as markdown and render it
    var renderedHtml = "";
    var editorText = "";
    if (insightRaw) {
      if (containsHtml(insightRaw)) {
        renderedHtml = sanitizeHtml(insightRaw);
        // Extract plain text for the editor (reverse: HTML -> text for re-editing)
        var tmp = document.createElement("div");
        tmp.innerHTML = renderedHtml;
        editorText = tmp.textContent.trim();
      } else {
        editorText = insightRaw;
        renderedHtml = hubRenderMarkdown(insightRaw);
      }
    }
    html += '<div class="hub-pin-insight" data-pin-id="' + pid + '">' +
      '<div class="hub-insight-rendered hub-md-content" ' +
        'ondblclick="ReportHub.toggleInsightEdit(\'' + pid + '\')" ' +
        'data-placeholder="Double-click to add insight...">' +
        (renderedHtml || '') +
      '</div>' +
      '<textarea class="hub-insight-editor" style="display:none" ' +
        'onblur="ReportHub.finishInsightEdit(\'' + pid + '\')">' +
        escapeHtml(editorText) +
      '</textarea>' +
    '</div>';

    // Image (custom slide image — always shown)
    if (pin.imageData) {
      html += '<div style="margin-bottom:4px;text-align:center;">' +
        '<img src="' + pin.imageData + '" style="max-width:100%;max-height:500px;border-radius:6px;border:1px solid #e2e8f0;" />' +
      '</div>';
    }

    // Respect pinMode: "all" (default), "chart_insight", "table_insight"
    var mode = pin.pinMode || "all";
    var showChart = (mode === "all" || mode === "chart_insight");
    var showTable = (mode === "all" || mode === "table_insight");

    // Chart (if captured and mode allows)
    if (pin.chartSvg && pin.chartVisible !== false && showChart) {
      html += '<div class="hub-pin-chart">' + sanitizeHtml(pin.chartSvg) + '</div>';
    }

    // Table (if captured and mode allows)
    if (pin.tableHtml && showTable) {
      html += '<div class="hub-pin-table">' + sanitizeHtml(pin.tableHtml) + '</div>';
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
   * Update a section's title by ID (safer than index-based)
   */
  ReportHub.updateSectionTitleById = function(sectionId, newTitle) {
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === sectionId &&
          ReportHub.pinnedItems[i].type === "section") {
        ReportHub.pinnedItems[i].title = newTitle.trim() || "Untitled Section";
        ReportHub.savePinnedData();
        break;
      }
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
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7),
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
    // Store the markdown source (not rendered HTML) so it round-trips correctly
    // on subsequent edits — consistent with finishInsightEdit behaviour.
    var mdSource = editor.value.trim();
    if (!mdSource) { alert("Add text before pinning."); return; }
    // Derive title from the section header label (works for both hub-level and per-report sections)
    var section = document.getElementById("hub-text-" + boxId);
    var labelEl = section ? section.querySelector(".hub-summary-label") : null;
    var title = labelEl ? labelEl.textContent.trim() : boxId;
    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7),
      title: title,
      sourceLabel: "Overview",
      insight: mdSource,
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
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7),
      title: titleEl ? (titleEl.value || titleEl.textContent || "").trim() || "Slide" : "Slide",
      sourceLabel: "Overview",
      insight: editor ? editor.value.trim() : "",
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

    // File size guard (10MB raw)
    if (file.size > 10 * 1024 * 1024) {
      alert("Image too large (" + (file.size / 1024 / 1024).toFixed(1) + "MB). Maximum is 10MB.");
      inputEl.value = "";
      return;
    }

    var reader = new FileReader();
    reader.onload = function(e) {
      var img = new Image();
      img.onerror = function() { /* invalid image data — silently skip */ };
      img.onload = function() {
        // Resize to max 1200px on longest side — matches config-driven images.
        // Keeps file size manageable while staying sharp at 3× export (1280px canvas).
        var maxDim = 1200;
        var w = img.width, h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) { h = Math.round(h * maxDim / w); w = maxDim; }
          else { w = Math.round(w * maxDim / h); h = maxDim; }
        }
        var canvas = document.createElement("canvas");
        canvas.width = w; canvas.height = h;
        var ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, w, h);
        // Preserve format: PNG for PNGs (keeps transparency), JPEG for photos
        var isPNG = file.type === "image/png" || file.name.toLowerCase().endsWith(".png");
        var dataUrl = isPNG
          ? canvas.toDataURL("image/png")
          : canvas.toDataURL("image/jpeg", 0.92);

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
   * Now also extracts per-cell inline styles (background, color, font-weight)
   * so the SVG export can render cell-level formatting (significance colours, etc.).
   */
  function hubExtractPinTableData(tableHtml) {
    if (!tableHtml) return null;
    var tempDiv = document.createElement("div");
    tempDiv.innerHTML = tableHtml;
    var table = tempDiv.querySelector("table");
    if (!table) return null;

    // Helper: extract inline style properties from a cell element.
    // inlineTableStyles() has already baked computed styles onto elements,
    // so element.style.* reads from the style attribute (works in detached DOM).
    function getCellStyle(el) {
      if (!el) return { bg: "", color: "", fontWeight: "", align: "" };
      // Walk up to nearest td/th to get background (spans inherit from parent cell)
      var target = el;
      while (target && target.tagName !== "TD" && target.tagName !== "TH" && target !== table) {
        target = target.parentElement;
      }
      if (!target || target === table) target = el;
      return {
        bg: target.style.backgroundColor || "",
        color: el.style.color || target.style.color || "",
        fontWeight: el.style.fontWeight || target.style.fontWeight || "",
        align: target.style.textAlign || ""
      };
    }

    var rows = [];

    // Header row
    var headerCells = [];
    var headerStyles = [];
    var headerRow = table.querySelector("thead tr");
    if (headerRow) {
      headerRow.querySelectorAll("th").forEach(function(th) {
        if (th.style.display === "none") return;
        // Tabs uses .ct-header-text; tracker uses plain text
        // Include column letter (A, B, C...) when present so significance markers are interpretable
        var text = th.querySelector(".ct-header-text");
        var label = text ? text.textContent.trim() : th.textContent.trim().split("\n")[0].trim();
        var letterEl = th.querySelector(".ct-letter");
        if (letterEl) label += " " + letterEl.textContent.trim();
        headerCells.push(label);
        headerStyles.push(getCellStyle(th));
      });
      if (headerCells.length > 0) {
        rows.push({ cells: headerCells, type: "header", cellStyles: headerStyles });
      }
    }

    // Body rows
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      if (tr.style.display === "none") return;
      if (tr.classList.contains("ct-row-excluded")) return;

      var rowInfo = { cells: [], cellStyles: [], type: "data" };

      // Tracker-style rows
      if (tr.classList.contains("tk-base-row")) {
        rowInfo.type = "base";
        var baseLabel = tr.querySelector(".tk-base-label");
        rowInfo.cells.push(baseLabel ? baseLabel.textContent.trim() : "Base");
        rowInfo.cellStyles.push(getCellStyle(tr.querySelector("td") || tr));
        tr.querySelectorAll("td.tk-base-cell").forEach(function(td) {
          if (td.style.display === "none") return;
          rowInfo.cells.push(td.textContent.trim());
          rowInfo.cellStyles.push(getCellStyle(td));
        });
      } else if (tr.classList.contains("tk-change-row")) {
        rowInfo.type = "change";
        var changeLabel = tr.querySelector(".tk-change-label");
        rowInfo.cells.push(changeLabel ? changeLabel.textContent.trim() : "Change");
        rowInfo.cellStyles.push(getCellStyle(tr.querySelector("td") || tr));
        tr.querySelectorAll("td.tk-change-cell").forEach(function(td) {
          if (td.style.display === "none") return;
          rowInfo.cells.push(td.textContent.trim());
          rowInfo.cellStyles.push(getCellStyle(td));
        });
      } else if (tr.classList.contains("tk-metric-row")) {
        var segName = tr.getAttribute("data-segment") || "";
        rowInfo.type = segName === "Total" ? "total" : "data";
        var labelEl = tr.querySelector(".tk-metric-label");
        rowInfo.cells.push(labelEl ? labelEl.textContent.trim() : segName);
        rowInfo.cellStyles.push(getCellStyle(tr.querySelector("td") || tr));
        tr.querySelectorAll("td.tk-value-cell").forEach(function(td) {
          if (td.style.display === "none") return;
          var valSpan = td.querySelector(".tk-val");
          rowInfo.cells.push(valSpan ? valSpan.textContent.trim() : td.textContent.trim());
          rowInfo.cellStyles.push(getCellStyle(td));
        });
        var dot = tr.querySelector(".tk-seg-dot");
        if (dot) rowInfo.colour = dot.style.background || dot.style.backgroundColor || null;

      // Tabs-style rows
      } else if (tr.classList.contains("ct-row-base")) {
        rowInfo.type = "base";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          rowInfo.cellStyles.push(getCellStyle(td));
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else if (tr.classList.contains("ct-row-mean")) {
        rowInfo.type = "mean";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          rowInfo.cellStyles.push(getCellStyle(td));
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else if (tr.classList.contains("ct-row-net")) {
        rowInfo.type = "net";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          rowInfo.cellStyles.push(getCellStyle(td));
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else {
        // Generic row (works for both tracker and tabs)
        tr.querySelectorAll("th, td").forEach(function(cell) {
          if (cell.style.display === "none") return;
          rowInfo.cellStyles.push(getCellStyle(cell));
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

  /** Render table as SVG rect+text elements.
   *  Now uses per-cell inline styles (from inlineTableStyles) to preserve
   *  significance highlighting, header colours, and cell-level formatting
   *  in the exported PNG. */
  function hubRenderPinTableSVG(ns, svgParent, tableData, x, y, maxWidth) {
    if (!tableData || tableData.length === 0) return 0;
    var nCols = tableData[0].cells.length;
    if (nCols === 0) return 0;

    var COLOURS = [
      "#323367", "#CC9900", "#2E8B57", "#CD5C5C", "#4682B4",
      "#9370DB", "#D2691E", "#20B2AA", "#8B4513", "#6A5ACD"
    ];

    var baseRowH = 22, headerH = 26, fontSize = 10, padX = 6;
    // Adaptive first column width: measure longest label across all rows
    var maxLabelLen = 0;
    for (var mi = 0; mi < tableData.length; mi++) {
      if (tableData[mi].cells.length > 0) {
        var len = tableData[mi].cells[0].length;
        if (len > maxLabelLen) maxLabelLen = len;
      }
    }
    var estimatedLabelW = maxLabelLen * (fontSize * 0.6) + padX * 2 + 20;
    var firstColW = Math.min(Math.max(estimatedLabelW, 140), maxWidth * 0.4);
    var dataColW = nCols > 1 ? (maxWidth - firstColW) / (nCols - 1) : maxWidth;

    var curY = y;
    var colourIdx = 0;

    // Helper: check if a background colour is visually significant
    // (not empty, transparent, or plain white)
    function isSignificantBg(bg) {
      if (!bg) return false;
      bg = bg.trim().toLowerCase();
      if (bg === "" || bg === "transparent" || bg === "rgba(0, 0, 0, 0)") return false;
      if (bg === "rgb(255, 255, 255)" || bg === "#ffffff" || bg === "#fff" || bg === "white") return false;
      return true;
    }

    tableData.forEach(function(row, ri) {
      var isHeader = row.type === "header";
      var rH = isHeader ? headerH : baseRowH;
      var hasCellStyles = row.cellStyles && row.cellStyles.length > 0;

      // Row-level background rect (default styling based on row type)
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

      // Per-cell background overlays: preserves significance highlighting,
      // conditional formatting, and other cell-level background colours
      if (hasCellStyles) {
        row.cells.forEach(function(cellText, ci) {
          var cs = row.cellStyles[ci];
          if (cs && isSignificantBg(cs.bg)) {
            var cellW = ci === 0 ? firstColW : dataColW;
            var cellX = ci === 0 ? x : x + firstColW + (ci - 1) * dataColW;
            var cellBg = document.createElementNS(ns, "rect");
            cellBg.setAttribute("x", cellX);
            cellBg.setAttribute("y", curY);
            cellBg.setAttribute("width", cellW);
            cellBg.setAttribute("height", rH);
            cellBg.setAttribute("fill", cs.bg);
            svgParent.appendChild(cellBg);
          }
        });
      }

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

      // Cell text — uses per-cell inline styles when available,
      // falls back to row-type-based defaults
      row.cells.forEach(function(cellText, ci) {
        var cs = hasCellStyles ? row.cellStyles[ci] : null;
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
          // Respect inline text-align when available
          var anchor = "middle";
          if (cs && cs.align === "left") anchor = "start";
          else if (cs && cs.align === "right") anchor = "end";
          textEl.setAttribute("x", anchor === "middle" ? cellX + cellW / 2 :
                                   anchor === "end"    ? cellX + cellW - padX :
                                                         cellX + padX);
          textEl.setAttribute("text-anchor", anchor);
        }

        // Apply cell-level colour and weight from inline styles first;
        // fall back to the existing row-type defaults for unstyled cells
        var appliedInline = false;
        if (cs && cs.color) {
          textEl.setAttribute("fill", cs.color);
          if (cs.fontWeight && (cs.fontWeight === "bold" || parseInt(cs.fontWeight) >= 600)) {
            textEl.setAttribute("font-weight", "600");
          }
          appliedInline = true;
        }

        if (!appliedInline) {
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
  /**
   * Export a single pin card as a PowerPoint-quality PNG using SVG-native approach.
   * @param {string} pinId - Pin ID
   * @param {function} [onComplete] - Optional callback invoked after export finishes
   */
  ReportHub.exportPinCard = function(pinId, onComplete) {
    // Find pin data in the store
    var pin = null;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) { pin = ReportHub.pinnedItems[i]; break; }
    }
    if (!pin) { if (onComplete) onComplete(); return; }

    // If pin has an image, pre-load it to get natural dimensions before building SVG
    if (pin.imageData) {
      var preImg = new Image();
      preImg.onload = function() {
        ReportHub._buildPinExportSVG(pin, preImg.naturalWidth, preImg.naturalHeight, onComplete);
      };
      preImg.onerror = function() {
        // Image failed to load — export without it
        ReportHub._buildPinExportSVG(pin, 0, 0, onComplete);
      };
      preImg.src = pin.imageData;
    } else {
      ReportHub._buildPinExportSVG(pin, 0, 0, onComplete);
    }
  };

  ReportHub._buildPinExportSVG = function(pin, pinImageW, pinImageH, onComplete) {
    var ns = "http://www.w3.org/2000/svg";
    var W = EXPORT_WIDTH;
    var fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
    var pad = 14;
    var usableW = W - pad * 2;
    var brandColour = getComputedStyle(document.documentElement).getPropertyValue("--hub-brand").trim() || "#323367";

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
    var titleStartY = pad + 8;
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
    var metaY = titleStartY + titleBlockH + 2;
    var contentTop = metaY + 10;

    // ---- 3. Insight (pre-render to measure height) ----
    var insightY = contentTop;
    var insightBlockH = 0;
    var insightRendered = null;
    if (insightBlocks.length > 0) {
      insightRendered = hubRenderInsightSVG(ns, insightBlocks, pad + 14, insightY + 14, usableW - 16, 7.5);
      insightBlockH = insightRendered.height + 18;
    }

    // ---- 3b. Image dimensions (config-driven or manually uploaded slide image) ----
    var imageTopY = contentTop + insightBlockH + (insightBlockH > 0 ? 4 : 0);
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

    var chartTopY = imageTopY + imageDisplayH + (imageDisplayH > 0 ? 4 : 0);
    var chartDisplayH = 0;
    var chartClone = null;
    var chartScale = 1;

    if (pin.chartSvg && pin.chartVisible !== false && exportShowChart) {
      var chartTempDiv = document.createElement("div");
      chartTempDiv.innerHTML = pin.chartSvg;
      var svgEl = chartTempDiv.querySelector("svg");
      if (svgEl) {
        chartClone = svgEl.cloneNode(true);
        // Resolve CSS variable references in chart SVG.
        // Handles both var(--name, fallback) and var(--name) without fallback.
        var rootStyles = getComputedStyle(document.documentElement);
        chartClone.querySelectorAll("*").forEach(function(el) {
          ["fill", "stroke", "stop-color", "color"].forEach(function(attr) {
            var val = el.getAttribute(attr);
            if (val && val.indexOf("var(") !== -1) {
              // Try var(--name, fallback) first
              var matchFb = val.match(/var\(--([^,)]+),\s*([^)]+)\)/);
              if (matchFb) {
                var resolved = rootStyles.getPropertyValue("--" + matchFb[1].trim()).trim();
                el.setAttribute(attr, resolved || matchFb[2].trim());
              } else {
                // var(--name) without fallback
                var matchNoFb = val.match(/var\(--([^)]+)\)/);
                if (matchNoFb) {
                  var resolved2 = rootStyles.getPropertyValue("--" + matchNoFb[1].trim()).trim();
                  if (resolved2) el.setAttribute(attr, resolved2);
                }
              }
            }
          });
        });
        var vb = chartClone.getAttribute("viewBox");
        if (vb) {
          // Handle both space-separated and comma-separated viewBox values
          var chartVB = vb.split(/[\s,]+/).map(Number);
          // Guard against degenerate viewBox (0 width/height, NaN)
          if (chartVB.length >= 4 && chartVB[2] > 0 && chartVB[3] > 0 &&
              !isNaN(chartVB[2]) && !isNaN(chartVB[3])) {
            chartScale = usableW / chartVB[2];
            chartDisplayH = chartVB[3] * chartScale;
          } else {
            chartClone = null; // Skip broken chart
          }
        }
      }
    }

    // ---- 5. Table dimensions ----
    var tableTopY = chartTopY + chartDisplayH + (chartDisplayH > 0 ? 4 : 0);
    var tableData = null;
    var estimatedTableH = 0;

    if (pin.tableHtml && exportShowTable) {
      tableData = hubExtractPinTableData(pin.tableHtml);
      if (tableData && tableData.length > 0) {
        estimatedTableH = 26 + (tableData.length - 1) * 22 + 4;
      }
    }

    // ---- 6. Total height ----
    var totalH = tableTopY + estimatedTableH + pad;
    if (totalH < 160) totalH = 160;

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
      var accentH = Math.max(24, insightRendered.height + 8);
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
      var newTotalH = tableTopY + actualTableH + pad;
      if (newTotalH > totalH) {
        totalH = newTotalH;
        bg.setAttribute("height", totalH);
        svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
      }
    }

    // ---- Render SVG to PNG at 3x resolution ----
    var renderScale = EXPORT_RENDER_SCALE;
    var svgData = new XMLSerializer().serializeToString(svg);
    var url = svgToImageUrl(svgData);

    var img = new Image();
    img.onerror = function() {
      console.error("[Hub Pin PNG] SVG render failed for pin: " + pin.id);
      alert("PNG export failed. Please try using Chrome or Edge browser.");
      if (onComplete) onComplete();
    };
    img.onload = function() {
      var canvas = document.createElement("canvas");
      canvas.width = W * renderScale;
      canvas.height = totalH * renderScale;
      var ctx = canvas.getContext("2d");
      if (!ctx) {
        console.error("[Hub Pin PNG] Canvas 2D context unavailable for pin: " + pin.id);
        if (onComplete) onComplete();
        return;
      }
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

      // Composite pin image directly on canvas (avoids SVG <image> taint)
      var _finishExport = function() {
        canvas.toBlob(function(blob) {
          if (!blob) { if (onComplete) onComplete(); return; }
          var slug = titleText.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
          var filename = "pinned_" + slug + ".png";
          var a = document.createElement("a");
          a.href = URL.createObjectURL(blob);
          a.download = filename;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(a.href);
          if (onComplete) onComplete();
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
   * Export all pinned cards as individual PNGs (sequential callback chain).
   * Each export waits for the previous one to complete before starting the next,
   * ensuring downloads don't overlap and browser download limits aren't hit.
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
      var currentId = pins[idx];
      idx++;
      // Small delay between downloads for browser download queue stability
      ReportHub.exportPinCard(currentId, function() {
        setTimeout(exportNext, EXPORT_ALL_DELAY_MS);
      });
    }
    exportNext();
  };

  /**
   * Sanitize HTML by removing script tags and event handler attributes.
   * Used for content that will be injected via innerHTML from report pins.
   * Since pins come from the user's own reports (same-origin), this is
   * defence-in-depth rather than a trust boundary, but prevents accidental
   * script execution when content is moved between contexts.
   */
  function sanitizeHtml(html) {
    if (!html) return "";
    // Remove dangerous elements and their content.
    // IMPORTANT: Regex patterns are built with new RegExp() to avoid literal
    // closing tags (e.g. script end tags) in source, which would break the HTML
    // parser when this JS is inlined inside a <script> block.
    var scriptRe = new RegExp("<script\\b[^<]*(?:(?!<\\/script>)<[^<]*)*<\\/script>", "gi");
    var iframeRe = new RegExp("<iframe\\b[^<]*(?:(?!<\\/iframe>)<[^<]*)*<\\/iframe>", "gi");
    var objectRe = new RegExp("<object\\b[^<]*(?:(?!<\\/object>)<[^<]*)*<\\/object>", "gi");
    html = html.replace(scriptRe, "");
    html = html.replace(iframeRe, "");
    html = html.replace(objectRe, "");
    html = html.replace(/<embed\b[^>]*\/?>/gi, "");
    html = html.replace(/<link\b[^>]*\/?>/gi, "");
    // Remove event handler attributes (on*)
    html = html.replace(/\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, "");
    // Remove javascript: and data: URI schemes from href/src/action attributes
    html = html.replace(/(href|src|action)\s*=\s*["']?\s*javascript:/gi, "$1=\"");
    html = html.replace(/(href|src|action)\s*=\s*["']?\s*data:text\/html/gi, "$1=\"");
    return html;
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

  // ============================================================================
  // DRAG AND DROP REORDERING
  // Allows pin cards and section dividers to be reordered by dragging.
  // Uses the same HTML5 Drag and Drop pattern as the tabs module.
  // ============================================================================
  (function() {
    var dragFromIdx = null;

    document.addEventListener("dragstart", function(e) {
      var draggable = e.target.closest("[data-pin-drag-idx]");
      if (!draggable) return;
      // Don't start drag when editing text inputs
      if (e.target.isContentEditable || e.target.tagName === "TEXTAREA" || e.target.tagName === "INPUT") {
        e.preventDefault();
        return;
      }
      dragFromIdx = parseInt(draggable.getAttribute("data-pin-drag-idx"), 10);
      draggable.classList.add("hub-pin-dragging");
      e.dataTransfer.effectAllowed = "move";
      // Custom drag ghost with pin/section title
      try {
        var title = draggable.querySelector(".hub-pin-title, .hub-section-title");
        var label = title ? title.textContent.substring(0, 30) : "Moving...";
        var ghost = document.createElement("div");
        ghost.style.cssText = "position:absolute;top:-999px;left:-999px;padding:8px 16px;background:#e2e8f0;border-radius:6px;font-size:13px;font-weight:500;color:#374151;white-space:nowrap;";
        ghost.textContent = label;
        document.body.appendChild(ghost);
        e.dataTransfer.setDragImage(ghost, 0, 0);
        setTimeout(function() { document.body.removeChild(ghost); }, 0);
      } catch (err) {}
    });

    document.addEventListener("dragover", function(e) {
      var target = e.target.closest("[data-pin-drag-idx]");
      if (!target || dragFromIdx === null) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
      document.querySelectorAll(".hub-pin-drop-target").forEach(function(el) {
        el.classList.remove("hub-pin-drop-target");
      });
      target.classList.add("hub-pin-drop-target");
    });

    document.addEventListener("dragleave", function(e) {
      var target = e.target.closest("[data-pin-drag-idx]");
      if (target) target.classList.remove("hub-pin-drop-target");
    });

    document.addEventListener("drop", function(e) {
      e.preventDefault();
      document.querySelectorAll(".hub-pin-drop-target, .hub-pin-dragging").forEach(function(el) {
        el.classList.remove("hub-pin-drop-target", "hub-pin-dragging");
      });
      var target = e.target.closest("[data-pin-drag-idx]");
      if (!target || dragFromIdx === null) return;
      var toIdx = parseInt(target.getAttribute("data-pin-drag-idx"), 10);
      if (dragFromIdx !== toIdx) {
        ReportHub.moveItem(dragFromIdx, toIdx);
      }
      dragFromIdx = null;
    });

    document.addEventListener("dragend", function() {
      dragFromIdx = null;
      document.querySelectorAll(".hub-pin-drop-target, .hub-pin-dragging").forEach(function(el) {
        el.classList.remove("hub-pin-drop-target", "hub-pin-dragging");
      });
    });
  })();

})();
