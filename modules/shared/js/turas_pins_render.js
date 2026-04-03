/**
 * TurasPins Shared Library — Card Rendering
 *
 * Renders pinned view cards, section dividers, and insight editing UI.
 * Cards feature an overflow menu (⋮) with export, clipboard, and move actions.
 *
 * Depends on: turas_pins_utils.js, turas_pins.js (must be loaded first)
 * @namespace TurasPins
 */

/* global TurasPins */

(function() {
  "use strict";

  // ── Overflow menu styles (inline, injected once) ───────────────────────────
  var MENU_CSS = "display:none;position:absolute;right:0;top:100%;background:#fff;" +
    "border:1px solid #e2e8f0;border-radius:6px;box-shadow:0 4px 12px rgba(0,0,0,0.1);" +
    "z-index:100;min-width:180px;padding:4px 0;margin-top:4px;";
  var ITEM_CSS = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;" +
    "background:none;cursor:pointer;font-size:12px;font-family:inherit;color:#374151;";
  var ITEM_HOVER = "onmouseover=\"this.style.background='#f1f5f9'\" " +
    "onmouseout=\"this.style.background='none'\"";

  /** Render all pinned cards and section dividers into the container. */
  TurasPins.renderCards = function() {
    var config = TurasPins.getConfig();
    if (!config) return;
    var container = document.getElementById(config.containerId);
    if (!container) return;
    var emptyState = document.getElementById(config.emptyStateId);
    var toolbar = config.toolbarId ? document.getElementById(config.toolbarId) : _findToolbar();
    var pins = TurasPins.getAll();
    var pinCount = TurasPins.getPinCount();

    if (pinCount === 0) {
      container.innerHTML = "";
      if (emptyState) emptyState.style.display = "";
      if (toolbar) toolbar.style.display = "none";
      return;
    }
    if (emptyState) emptyState.style.display = "none";
    if (toolbar) {
      toolbar.style.display = "";
      _injectPptxToolbar(toolbar);
    }

    var html = "";
    var total = pins.length;
    for (var i = 0; i < total; i++) {
      if (pins[i].type === "section") html += _buildSectionHTML(pins[i], i, total, config);
      else if (pins[i].type === "pin") html += _buildPinCardHTML(pins[i], i, total, config);
    }
    container.innerHTML = html;
    container.querySelectorAll("svg").forEach(function(s) {
      s.style.width = "100%"; s.style.height = "auto";
    });
  };

  // ── Pin Card ───────────────────────────────────────────────────────────────

  function _buildPinCardHTML(pin, idx, total, config) {
    var pfx = config.cssPrefix;
    var pid = TurasPins._escapeHtml(pin.id);
    var title = pin.title || pin.metricLabel || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || "";
    var dragAttr = config.features.dragDrop ?
      ' draggable="true" data-pin-drag-idx="' + idx + '"' : "";

    var html = '<div class="' + pfx + '-card" data-pin-id="' + pid + '"' +
      ' data-idx="' + idx + '"' + dragAttr + '>';
    html += _cardHeader(pid, title, idx, total, pfx);
    if (subtitle) html += '<div class="' + pfx + '-card-subtitle">' +
      TurasPins._escapeHtml(subtitle) + '</div>';
    html += _buildInsightArea(pin, pid, pfx, config);
    html += _buildAiInsightArea(pin, pfx);
    html += _cardContent(pin, pfx);
    html += '</div>';
    return html;
  }

  /** Card header: title + move arrows + remove button + overflow menu (⋮) */
  function _cardHeader(pid, title, idx, total, pfx) {
    var moveHtml = "";
    if (idx > 0) moveHtml += '<button class="' + pfx + '-action-btn" ' +
      'onclick="TurasPins.move(\'' + pid + '\',-1)" title="Move up">\u25B2</button>';
    if (idx < total - 1) moveHtml += '<button class="' + pfx + '-action-btn" ' +
      'onclick="TurasPins.move(\'' + pid + '\',1)" title="Move down">\u25BC</button>';
    return '<div class="' + pfx + '-card-header">' +
      '<span class="' + pfx + '-card-title">' + TurasPins._escapeHtml(title) + '</span>' +
      '<div class="' + pfx + '-card-actions">' +
        moveHtml +
        '<button class="' + pfx + '-remove-btn" onclick="TurasPins.remove(\'' +
          pid + '\')" title="Remove">&times;</button>' +
        _overflowMenu(pid, idx, total) +
      '</div></div>';
  }

  /** Build the ⋮ overflow menu with all actions */
  function _overflowMenu(pid, idx, total) {
    var html = '<div style="position:relative;display:inline-block;">';
    html += '<button style="padding:3px 8px;font-size:14px;line-height:1;background:none;' +
      'border:1px solid #e2e8f0;border-radius:4px;cursor:pointer;color:#64748b;" ' +
      'onclick="TurasPins._toggleOverflow(this)" title="More actions">\u22EE</button>';
    html += '<div class="turas-pin-overflow" style="' + MENU_CSS + '">';
    // Clipboard copy
    html += '<button style="' + ITEM_CSS + '" ' + ITEM_HOVER +
      ' onclick="TurasPins.copyToClipboard(\'' + pid + '\')">&#x1F4CB; Copy to clipboard</button>';
    // Export PNG
    html += '<button style="' + ITEM_CSS + '" ' + ITEM_HOVER +
      ' onclick="TurasPins.exportCard(\'' + pid + '\')">&#128247; Export as PNG</button>';
    // Export single PPTX
    html += '<button style="' + ITEM_CSS + '" ' + ITEM_HOVER +
      ' onclick="TurasPins.exportSinglePptx(\'' + pid + '\')">&#128202; Export as PowerPoint</button>';
    // Move up
    if (idx > 0) {
      html += '<button style="' + ITEM_CSS + '" ' + ITEM_HOVER +
        ' onclick="TurasPins.move(\'' + pid + '\',-1)">\u25B2 Move up</button>';
    }
    // Move down
    if (idx < total - 1) {
      html += '<button style="' + ITEM_CSS + '" ' + ITEM_HOVER +
        ' onclick="TurasPins.move(\'' + pid + '\',1)">\u25BC Move down</button>';
    }
    html += '</div></div>';
    return html;
  }

  /** Build card content: image, chart, table respecting pinMode/pinFlags */
  function _cardContent(pin, pfx) {
    var html = "";
    if (pin.imageData) {
      html += '<div style="margin-bottom:4px;text-align:center;">' +
        '<img src="' + pin.imageData + '" style="max-width:100%;' +
        'max-height:500px;border-radius:6px;border:1px solid #e2e8f0;" /></div>';
    }
    if (pin.chartSvg && pin.chartVisible !== false &&
        TurasPins.shouldShow(pin, "chart")) {
      html += '<div class="' + pfx + '-card-chart">' +
        TurasPins._sanitizeHtml(pin.chartSvg) + '</div>';
    }
    if (pin.tableHtml && TurasPins.shouldShow(pin, "table")) {
      html += '<div class="' + pfx + '-card-table">' +
        TurasPins._sanitizeHtml(pin.tableHtml) + '</div>';
    }
    return html;
  }

  // ── Section Divider ────────────────────────────────────────────────────────

  function _buildSectionHTML(section, idx, total, config) {
    var pfx = config.cssPrefix;
    var sid = TurasPins._escapeHtml(section.id);
    var dragAttr = config.features.dragDrop ?
      ' draggable="true" data-pin-drag-idx="' + idx + '"' : "";
    var moveHtml = "";
    if (idx > 0) moveHtml += '<button class="' + pfx + '-action-btn" ' +
      'onclick="TurasPins.move(\'' + sid + '\',-1)" title="Move up">\u25B2</button>';
    if (idx < total - 1) moveHtml += '<button class="' + pfx + '-action-btn" ' +
      'onclick="TurasPins.move(\'' + sid + '\',1)" title="Move down">\u25BC</button>';
    return '<div class="' + pfx + '-section-divider"' +
      ' data-idx="' + idx + '" data-item-id="' + sid + '"' + dragAttr + '>' +
      '<div class="' + pfx + '-section-title" contenteditable="true" ' +
        'onpaste="event.preventDefault();document.execCommand(\'insertText\',false,' +
        'event.clipboardData.getData(\'text/plain\'))" ' +
        'onblur="TurasPins.updateSectionTitle(\'' + sid + '\',this.textContent)">' +
        TurasPins._escapeHtml(section.title) + '</div>' +
      '<div class="' + pfx + '-section-actions">' + moveHtml +
        '<button class="' + pfx + '-remove-btn" onclick="TurasPins.remove(\'' +
        sid + '\')" title="Remove">&times;</button></div></div>';
  }

  // ── Toolbar Discovery ──────────────────────────────────────────────────────

  /** Find the export toolbar when no toolbarId is configured.
   *  Looks for the parent container of "Export All" or "Add Section" buttons. */
  function _findToolbar() {
    var btns = document.querySelectorAll("button");
    for (var i = 0; i < btns.length; i++) {
      var txt = btns[i].textContent;
      if (txt.indexOf("Export All") > -1 || txt.indexOf("Add Section") > -1) {
        return btns[i].parentElement;
      }
    }
    return null;
  }

  // ── PPTX Toolbar Injection ─────────────────────────────────────────────────

  /** Inject PPTX export button and quality toggle into the toolbar (once per toolbar) */
  function _injectPptxToolbar(toolbar) {
    if (toolbar.getAttribute("data-pptx-injected")) return;
    if (typeof PptxGenJS === "undefined") return;
    toolbar.setAttribute("data-pptx-injected", "true");

    // Quality toggle
    var toggle = document.createElement("select");
    toggle.id = "turas-pptx-quality";
    toggle.title = "Export quality for PNG and PowerPoint";
    toggle.style.cssText =
      "padding:4px 8px;font-size:11px;border:1px solid #e2e8f0;border-radius:6px;" +
      "background:#fff;color:#374151;cursor:pointer;font-family:inherit;";
    var optStd = document.createElement("option");
    optStd.value = "standard"; optStd.textContent = "Standard quality";
    var optHigh = document.createElement("option");
    optHigh.value = "high"; optHigh.textContent = "High quality";
    toggle.appendChild(optStd);
    toggle.appendChild(optHigh);
    toggle.value = TurasPins.EXPORT_QUALITY;
    toggle.addEventListener("change", function() {
      TurasPins.EXPORT_QUALITY = toggle.value;
    });

    // PPTX export button — match existing button style
    var btn = document.createElement("button");
    btn.textContent = "\uD83D\uDCCA Export as PowerPoint";
    btn.title = "Export all pins as a PowerPoint presentation";
    btn.addEventListener("click", function() { TurasPins.exportPptx(); });

    // Copy style from first existing button in toolbar
    var existingBtn = toolbar.querySelector("button");
    if (existingBtn) {
      var cs = window.getComputedStyle(existingBtn);
      btn.style.cssText =
        "padding:" + cs.padding + ";font-size:" + cs.fontSize + ";" +
        "border:" + cs.border + ";border-radius:" + cs.borderRadius + ";" +
        "background:" + cs.background + ";color:" + cs.color + ";" +
        "cursor:pointer;font-family:" + cs.fontFamily + ";";
    } else {
      btn.style.cssText =
        "padding:6px 14px;font-size:12px;border:1px solid #e2e8f0;border-radius:6px;" +
        "background:#fff;color:#374151;cursor:pointer;font-family:inherit;";
    }

    toolbar.appendChild(toggle);
    toolbar.appendChild(btn);
  }

  // ── Overflow Menu Toggle ───────────────────────────────────────────────────

  /** Toggle overflow menu visibility; close others first */
  TurasPins._toggleOverflow = function(btn) {
    var menu = btn.nextElementSibling;
    if (!menu) return;
    var isOpen = menu.style.display !== "none";
    _closeAllOverflows();
    if (!isOpen) menu.style.display = "block";
  };

  /** Close all open overflow menus */
  function _closeAllOverflows() {
    document.querySelectorAll(".turas-pin-overflow").forEach(function(m) {
      m.style.display = "none";
    });
  }

  // Close overflow on click outside
  document.addEventListener("click", function(e) {
    if (!e.target.closest("[onclick*='_toggleOverflow']") &&
        !e.target.closest(".turas-pin-overflow")) {
      _closeAllOverflows();
    }
  });

  // ── Clipboard Copy ─────────────────────────────────────────────────────────

  /**
   * Copy a pin card to clipboard as PNG (for pasting into PowerPoint).
   * Falls back to PNG download if clipboard API unavailable.
   */
  TurasPins.copyToClipboard = function(pinId) {
    _closeAllOverflows();
    TurasPins.exportCard(pinId, function(blob) {
      // exportCard triggers download — for clipboard we need the blob
    });
    // Use the export pipeline but intercept the blob for clipboard
    _exportToClipboard(pinId);
  };

  // ── Insight Area ───────────────────────────────────────────────────────────

  function _buildInsightArea(pin, pid, pfx, config) {
    // Skip if pinFlags says insight is off, or no insight text and no edit mode
    if (pin.pinFlags && !pin.pinFlags.insight) return "";
    if (!config.features.insightEdit) {
      if (pin.insightText) {
        var r = TurasPins._containsHtml(pin.insightText) ?
          TurasPins._sanitizeHtml(pin.insightText) :
          TurasPins._renderMarkdown(pin.insightText);
        return '<div class="' + pfx + '-card-insight">' + r + '</div>';
      }
      return "";
    }
    var raw = pin.insightText || "", rHtml = "", eTxt = "";
    if (raw) {
      if (TurasPins._containsHtml(raw)) {
        rHtml = TurasPins._sanitizeHtml(raw);
        var tmp = document.createElement("div"); tmp.innerHTML = rHtml;
        eTxt = tmp.textContent.trim();
      } else { eTxt = raw; rHtml = TurasPins._renderMarkdown(raw); }
    }
    return '<div class="' + pfx + '-card-insight" data-pin-id="' + pid + '">' +
      '<div class="' + pfx + '-insight-rendered" ' +
        'ondblclick="TurasPins.toggleInsightEdit(\'' + pid + '\')" ' +
        'data-placeholder="Double-click to add insight...">' + (rHtml || "") + '</div>' +
      '<textarea class="' + pfx + '-insight-editor" style="display:none" ' +
        'onblur="TurasPins.finishInsightEdit(\'' + pid + '\')">' +
        TurasPins._escapeHtml(eTxt) + '</textarea></div>';
  }

  TurasPins.toggleInsightEdit = function(pinId) {
    var c = TurasPins.getConfig(); if (!c) return;
    var el = document.querySelector('.' + c.cssPrefix + '-card-insight[data-pin-id="' + pinId + '"]');
    if (!el) return;
    var r = el.querySelector("." + c.cssPrefix + "-insight-rendered");
    var e = el.querySelector("." + c.cssPrefix + "-insight-editor");
    if (r && e) { r.style.display = "none"; e.style.display = ""; e.focus(); }
  };

  TurasPins.finishInsightEdit = function(pinId) {
    var c = TurasPins.getConfig(); if (!c) return;
    var el = document.querySelector('.' + c.cssPrefix + '-card-insight[data-pin-id="' + pinId + '"]');
    if (!el) return;
    var r = el.querySelector("." + c.cssPrefix + "-insight-rendered");
    var e = el.querySelector("." + c.cssPrefix + "-insight-editor");
    if (!r || !e) return;
    var md = e.value.trim();
    r.innerHTML = md ? TurasPins._renderMarkdown(md) : "";
    r.style.display = ""; e.style.display = "none";
    TurasPins.updateInsight(pinId, md);
  };

  // ── AI Insight Area (read-only, styled HTML) ─────────────────────────────

  /** Build AI insight callout panel in pinned card (read-only, preserves styling) */
  function _buildAiInsightArea(pin, pfx) {
    if (!pin.aiInsightHtml) return "";
    // Respect pinFlags if present
    if (pin.pinFlags && !pin.pinFlags.aiInsight) return "";
    return '<div class="' + pfx + '-card-ai-insight">' +
      TurasPins._sanitizeHtml(pin.aiInsightHtml) + '</div>';
  }

  // ── Clipboard Export (internal) ────────────────────────────────────────────

  /** Export pin as PNG blob and copy to clipboard */
  function _exportToClipboard(pinId) {
    var pins = TurasPins.getAll();
    var pin = null;
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].id === pinId) { pin = pins[i]; break; }
    }
    if (!pin) return;
    // Build the export SVG and render to canvas, then copy blob
    TurasPins._exportToBlob(pin, function(blob) {
      if (!blob) return;
      if (navigator.clipboard && navigator.clipboard.write) {
        navigator.clipboard.write([
          new ClipboardItem({ "image/png": blob })
        ]).then(function() {
          TurasPins._showToast("Copied to clipboard");
        }).catch(function() {
          _downloadBlob(blob, pin);
          TurasPins._showToast("Downloaded (clipboard unavailable)");
        });
      } else {
        _downloadBlob(blob, pin);
        TurasPins._showToast("Downloaded (clipboard unavailable)");
      }
    });
  }

  /** Download a blob as PNG file (clipboard fallback) */
  function _downloadBlob(blob, pin) {
    var title = pin.title || "pinned";
    var slug = title.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "pinned_" + slug + ".png";
    document.body.appendChild(a); a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
  }

})();
