/**
 * Turas Hub App — Export Manager
 *
 * Handles all export operations:
 *   - Individual pin as PNG (SVG → Canvas → PNG, 3x resolution)
 *   - All pins as PNGs (triggers R-side ZIP generation)
 *   - PowerPoint (.pptx) via officer R package
 *   - Progress indicator during exports
 *
 * PNG export runs entirely in the browser (no R round-trip).
 * PPTX export sends pin data to R, which builds the deck with officer.
 */

var ExportManager = (function() {
  "use strict";

  // ---- Configuration ----
  var EXPORT_RENDER_SCALE = 3;    // Canvas resolution multiplier for crisp PNGs
  var EXPORT_WIDTH        = 1280; // SVG canvas width (px)
  var SEQUENTIAL_DELAY_MS = 150;  // Delay between sequential PNG exports

  // ===========================================================================
  // PNG Export — Single Pin
  // ===========================================================================

  /**
   * Export a single pin as a PNG download.
   * Renders the SVG chart at high resolution via canvas.
   * @param {string} pinId - Pin ID to export
   */
  function exportPinAsPng(pinId) {
    var items = PinBoard.getItems();
    var pin = null;
    for (var i = 0; i < items.length; i++) {
      if (items[i].id === pinId) { pin = items[i]; break; }
    }
    if (!pin) {
      HubApp.showToast("Pin not found", 3000);
      return;
    }

    if (!pin.chartSvg) {
      HubApp.showToast("No chart to export", 3000);
      return;
    }

    svgToPng(pin.chartSvg, function(dataUrl) {
      if (!dataUrl) {
        HubApp.showToast("Export failed", 3000);
        return;
      }
      var filename = sanitizeFilename(pin.title || pin.id) + ".png";
      downloadDataUrl(dataUrl, filename);
      HubApp.showToast("Exported: " + filename);
    });
  }

  /**
   * Convert an SVG string to a PNG data URL via canvas.
   * @param {string} svgStr - SVG markup
   * @param {function} callback - Called with (dataUrl) or (null) on error
   */
  function svgToPng(svgStr, callback) {
    try {
      // Parse SVG to extract dimensions
      var parser = new DOMParser();
      var svgDoc = parser.parseFromString(svgStr, "image/svg+xml");
      var svgEl = svgDoc.documentElement;

      // Get dimensions from viewBox or width/height attributes
      var viewBox = svgEl.getAttribute("viewBox");
      var svgWidth = parseFloat(svgEl.getAttribute("width")) || EXPORT_WIDTH;
      var svgHeight = parseFloat(svgEl.getAttribute("height")) || 600;

      if (viewBox) {
        var parts = viewBox.split(/[\s,]+/);
        if (parts.length === 4) {
          svgWidth = parseFloat(parts[2]) || svgWidth;
          svgHeight = parseFloat(parts[3]) || svgHeight;
        }
      }

      // Ensure SVG has explicit dimensions for canvas rendering
      svgEl.setAttribute("width", svgWidth);
      svgEl.setAttribute("height", svgHeight);

      var serializer = new XMLSerializer();
      var svgData = serializer.serializeToString(svgEl);
      var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
      var url = URL.createObjectURL(blob);

      var img = new Image();
      img.onload = function() {
        var canvas = document.createElement("canvas");
        canvas.width = svgWidth * EXPORT_RENDER_SCALE;
        canvas.height = svgHeight * EXPORT_RENDER_SCALE;

        var ctx = canvas.getContext("2d");
        ctx.scale(EXPORT_RENDER_SCALE, EXPORT_RENDER_SCALE);
        ctx.fillStyle = "#ffffff";
        ctx.fillRect(0, 0, svgWidth, svgHeight);
        ctx.drawImage(img, 0, 0, svgWidth, svgHeight);

        URL.revokeObjectURL(url);
        callback(canvas.toDataURL("image/png"));
      };

      img.onerror = function() {
        URL.revokeObjectURL(url);
        console.error("[Export] Failed to render SVG to canvas");
        callback(null);
      };

      img.src = url;
    } catch (e) {
      console.error("[Export] svgToPng error:", e.message);
      callback(null);
    }
  }

  // ===========================================================================
  // PPTX Export — via Shiny/officer
  // ===========================================================================

  /**
   * Request PPTX export from R.
   * Sends the current pin data to R, which builds the deck with officer.
   */
  function exportPptx() {
    var items = PinBoard.getItems();
    var pinCount = PinBoard.getPinCount();

    if (pinCount === 0) {
      HubApp.showToast("No pins to export", 3000);
      return;
    }

    showProgress("Generating PowerPoint...");

    // Convert SVGs to PNG data URLs for R-side embedding
    var pinsWithImages = [];
    var pending = 0;
    var completed = 0;

    for (var i = 0; i < items.length; i++) {
      var item = items[i];

      if (item.type === "section") {
        pinsWithImages.push({
          type: "section",
          title: item.title,
          position: i
        });
        continue;
      }

      if (item.type === "pin") {
        // Create a copy for export
        var exportPin = {
          type: "pin",
          id: item.id,
          title: item.title || "Untitled",
          subtitle: item.subtitle || "",
          insight: item.insight || item.insightText || "",
          source: item.source || "",
          sourceLabel: item.sourceLabel || "",
          tableHtml: item.tableHtml || "",
          position: i,
          chartPng: null  // Will be filled by svgToPng
        };

        if (item.chartSvg) {
          pending++;
          (function(ep, svg) {
            svgToPng(svg, function(dataUrl) {
              ep.chartPng = dataUrl;
              completed++;
              updateProgress("Rendering charts... " + completed + "/" + pending);
              checkAllDone();
            });
          })(exportPin, item.chartSvg);
        }

        pinsWithImages.push(exportPin);
      }
    }

    function checkAllDone() {
      if (completed < pending) return;

      updateProgress("Sending to R for PPTX generation...");

      // Send to R
      var projectName = HubApp.state.activeProject
        ? HubApp.state.activeProject.name
        : "Turas Export";

      var payload = JSON.stringify({
        project_name: projectName,
        items: pinsWithImages
      });

      if (!HubApp.sendToShiny("hub_export_pptx", payload)) {
        hideProgress();
        HubApp.showToast("Export failed: Shiny not connected", 5000);
      }
    }

    // If no SVGs to render, send immediately
    if (pending === 0) {
      checkAllDone();
    }
  }

  // ===========================================================================
  // All Pins as PNG ZIP — via Shiny
  // ===========================================================================

  /**
   * Export all pins as PNGs, packaged in a ZIP by R.
   */
  function exportAllPngs() {
    var items = PinBoard.getItems();
    var pins = [];

    for (var i = 0; i < items.length; i++) {
      if (items[i].type === "pin" && items[i].chartSvg) {
        pins.push(items[i]);
      }
    }

    if (pins.length === 0) {
      HubApp.showToast("No charts to export", 3000);
      return;
    }

    showProgress("Rendering PNGs...");

    var pngData = [];
    var idx = 0;

    function renderNext() {
      if (idx >= pins.length) {
        // All done — send to R for ZIP
        updateProgress("Packaging ZIP...");
        var payload = JSON.stringify({
          project_name: HubApp.state.activeProject
            ? HubApp.state.activeProject.name
            : "Turas Export",
          images: pngData
        });
        if (!HubApp.sendToShiny("hub_export_pngs_zip", payload)) {
          hideProgress();
          HubApp.showToast("Export failed: Shiny not connected", 5000);
        }
        return;
      }

      var pin = pins[idx];
      updateProgress("Rendering " + (idx + 1) + " of " + pins.length + "...");

      svgToPng(pin.chartSvg, function(dataUrl) {
        pngData.push({
          filename: sanitizeFilename(pin.title || pin.id) + ".png",
          dataUrl: dataUrl
        });
        idx++;
        setTimeout(renderNext, SEQUENTIAL_DELAY_MS);
      });
    }

    renderNext();
  }

  // ===========================================================================
  // Progress Indicator
  // ===========================================================================

  var progressTimeout = null;

  function showProgress(message) {
    var overlay = document.getElementById("export-progress");
    var text = document.getElementById("export-progress-text");
    if (overlay) overlay.style.display = "flex";
    if (text) text.textContent = message || "Exporting...";

    // Safety: auto-hide after 30 seconds to prevent stuck overlay
    if (progressTimeout) clearTimeout(progressTimeout);
    progressTimeout = setTimeout(function() {
      hideProgress();
      HubApp.showToast("Export timed out — check the R console for errors", 5000);
    }, 30000);
  }

  function updateProgress(message) {
    var text = document.getElementById("export-progress-text");
    if (text) text.textContent = message;
  }

  function hideProgress() {
    if (progressTimeout) { clearTimeout(progressTimeout); progressTimeout = null; }
    var overlay = document.getElementById("export-progress");
    if (overlay) overlay.style.display = "none";
  }

  // ===========================================================================
  // Shiny Response Handlers
  // ===========================================================================

  /**
   * Handle PPTX export completion from R.
   * @param {object} data - { success, path, filename, error }
   */
  function handlePptxComplete(data) {
    hideProgress();
    if (data && data.success) {
      HubApp.showToast("PowerPoint saved: " + (data.filename || "export.pptx"));
    } else {
      HubApp.showToast("Export failed: " + (data ? data.error : "Unknown error"), 5000);
    }
  }

  /**
   * Handle PNG ZIP export completion from R.
   * @param {object} data - { success, path, filename, error }
   */
  function handlePngZipComplete(data) {
    hideProgress();
    if (data && data.success) {
      HubApp.showToast("PNGs saved: " + (data.filename || "pins.zip"));
    } else {
      HubApp.showToast("Export failed: " + (data ? data.error : "Unknown error"), 5000);
    }
  }

  // ===========================================================================
  // Utilities
  // ===========================================================================

  /**
   * Trigger a browser download from a data URL.
   * @param {string} dataUrl
   * @param {string} filename
   */
  function downloadDataUrl(dataUrl, filename) {
    var link = document.createElement("a");
    link.href = dataUrl;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  /**
   * Sanitize a string for use as a filename.
   * @param {string} str
   * @returns {string}
   */
  function sanitizeFilename(str) {
    return String(str || "export")
      .replace(/[^a-zA-Z0-9_\- ]/g, "")
      .replace(/\s+/g, "_")
      .substring(0, 80) || "export";
  }

  // --- Public API ---
  return {
    exportPinAsPng: exportPinAsPng,
    exportPptx: exportPptx,
    exportAllPngs: exportAllPngs,
    handlePptxComplete: handlePptxComplete,
    handlePngZipComplete: handlePngZipComplete,
    hideProgress: hideProgress
  };
})();
