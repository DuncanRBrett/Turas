/**
 * Turas Hub App — Annotations Manager
 *
 * Manages project-level text fields: executive summary, background/methodology,
 * and project notes. These persist in a .turas_annotations.json sidecar file
 * alongside the project's reports.
 *
 * Public API:
 *   Annotations.init()           — Bind events
 *   Annotations.load(data)       — Hydrate from sidecar data
 *   Annotations.clear()          — Reset when leaving a project
 *   Annotations.show()           — Show annotations panel
 *   Annotations.hide()           — Hide annotations panel
 *   Annotations.toggle()         — Toggle visibility
 */

var Annotations = (function() {
  "use strict";

  var SAVE_DEBOUNCE = 800;  // ms
  var saveTimer = null;
  var isVisible = false;

  // Current annotation data
  var data = {
    executive_summary: "",
    background: "",
    notes: ""
  };

  /**
   * Initialise — bind event listeners on text areas.
   */
  function init() {
    var fields = ["ann-executive-summary", "ann-background", "ann-notes"];
    for (var i = 0; i < fields.length; i++) {
      var el = document.getElementById(fields[i]);
      if (el) {
        el.addEventListener("input", onFieldChange);
        el.addEventListener("blur", onFieldChange);
      }
    }
  }

  /**
   * Handle field change — debounced save.
   */
  function onFieldChange() {
    var summaryEl = document.getElementById("ann-executive-summary");
    var bgEl = document.getElementById("ann-background");
    var notesEl = document.getElementById("ann-notes");

    data.executive_summary = summaryEl ? summaryEl.value : "";
    data.background = bgEl ? bgEl.value : "";
    data.notes = notesEl ? notesEl.value : "";

    clearTimeout(saveTimer);
    saveTimer = setTimeout(function() {
      persist();
    }, SAVE_DEBOUNCE);
  }

  /**
   * Persist annotations to R (which writes the sidecar file).
   */
  function persist() {
    var payload = JSON.stringify({
      version: 1,
      last_modified: new Date().toISOString(),
      executive_summary: data.executive_summary,
      background: data.background,
      notes: data.notes
    });
    HubApp.sendToShiny("hub_save_annotations", payload);
  }

  /**
   * Load annotations from sidecar data (received from R).
   * @param {object} sidecarData - Parsed JSON from .turas_annotations.json
   */
  function load(sidecarData) {
    if (!sidecarData) {
      data = { executive_summary: "", background: "", notes: "" };
    } else {
      data.executive_summary = sidecarData.executive_summary || "";
      data.background = sidecarData.background || "";
      data.notes = sidecarData.notes || "";
    }

    // Update UI fields
    var summaryEl = document.getElementById("ann-executive-summary");
    var bgEl = document.getElementById("ann-background");
    var notesEl = document.getElementById("ann-notes");

    if (summaryEl) summaryEl.value = data.executive_summary;
    if (bgEl) bgEl.value = data.background;
    if (notesEl) notesEl.value = data.notes;

    // Update preview
    updatePreview();
  }

  /**
   * Update the rendered preview of the executive summary.
   */
  function updatePreview() {
    var preview = document.getElementById("ann-summary-preview");
    if (preview) {
      if (data.executive_summary) {
        preview.innerHTML = renderMarkdown(data.executive_summary);
        preview.style.display = "";
      } else {
        preview.innerHTML = "";
        preview.style.display = "none";
      }
    }
  }

  /**
   * Simple markdown renderer (matches PinBoard's renderMarkdown).
   */
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
    html = html.split("\n").map(function(line) {
      var trimmed = line.trim();
      if (!trimmed) return "";
      if (/^<(h2|ul|li|blockquote)/.test(trimmed)) return trimmed;
      return "<p>" + trimmed + "</p>";
    }).join("\n");

    return html;
  }

  /**
   * Show the annotations panel.
   */
  function show() {
    var panel = document.getElementById("annotations-panel");
    if (panel) panel.style.display = "";
    isVisible = true;
  }

  /**
   * Hide the annotations panel.
   */
  function hide() {
    var panel = document.getElementById("annotations-panel");
    if (panel) panel.style.display = "none";
    isVisible = false;
  }

  /**
   * Toggle annotations panel visibility.
   */
  function toggle() {
    if (isVisible) hide();
    else show();
  }

  /**
   * Clear all annotation data (on project close).
   */
  function clear() {
    clearTimeout(saveTimer);
    data = { executive_summary: "", background: "", notes: "" };

    var summaryEl = document.getElementById("ann-executive-summary");
    var bgEl = document.getElementById("ann-background");
    var notesEl = document.getElementById("ann-notes");

    if (summaryEl) summaryEl.value = "";
    if (bgEl) bgEl.value = "";
    if (notesEl) notesEl.value = "";

    hide();
  }

  /**
   * Get current data for export.
   */
  function getData() {
    return data;
  }

  return {
    init: init,
    load: load,
    clear: clear,
    show: show,
    hide: hide,
    toggle: toggle,
    getData: getData
  };
})();
