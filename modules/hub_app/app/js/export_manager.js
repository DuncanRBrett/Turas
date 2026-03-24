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
  // PDF Export — Browser Print with @media print styles
  // ===========================================================================

  /**
   * Export the pin board as a PDF via the browser's print dialog.
   * Opens a new window with a print-optimised layout of all pins,
   * then triggers window.print().
   */
  function exportPdf() {
    var items = PinBoard.getItems();
    var pinCount = PinBoard.getPinCount();

    if (pinCount === 0) {
      HubApp.showToast("No pins to export", 3000);
      return;
    }

    var projectName = HubApp.state.activeProject
      ? HubApp.state.activeProject.name
      : "Turas Export";

    // Build a self-contained print document
    var html = buildPrintDocument(projectName, items);

    // Open in new window and trigger print
    var printWin = window.open("", "_blank", "width=900,height=700");
    if (!printWin) {
      HubApp.showToast("Pop-up blocked — please allow pop-ups for this page", 5000);
      return;
    }

    printWin.document.open();
    printWin.document.write(html);
    printWin.document.close();

    // Wait for images/SVG to render, then print
    printWin.onload = function() {
      setTimeout(function() {
        printWin.print();
      }, 500);
    };
  }

  /**
   * Build a self-contained HTML document optimised for printing.
   * @param {string} projectName
   * @param {Array} items - Pin and section items
   * @returns {string} Full HTML document string
   */
  function buildPrintDocument(projectName, items) {
    var date = new Date().toLocaleDateString("en-GB", {
      day: "numeric", month: "long", year: "numeric"
    });

    var body = "";
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      if (item.type === "section") {
        body += '<div class="print-section"><h2>' +
          esc(item.title || "Section") + '</h2></div>';
      } else if (item.type === "pin") {
        body += buildPrintPin(item);
      }
    }

    return '<!DOCTYPE html><html><head><meta charset="UTF-8">' +
      '<title>' + esc(projectName) + ' — Pin Board Export</title>' +
      '<style>' + getPrintStyles() + '</style></head>' +
      '<body>' +
      '<div class="print-header">' +
        '<h1>' + esc(projectName) + '</h1>' +
        '<p class="print-date">Generated ' + esc(date) + '</p>' +
      '</div>' +
      body +
      '<div class="print-footer">Generated by Turas Hub App</div>' +
      '</body></html>';
  }

  /**
   * Build HTML for a single pin in the print layout.
   */
  function buildPrintPin(pin) {
    var source = pin.sourceLabel || pin.source || "";
    var title = pin.title || "Pinned View";
    var subtitle = pin.subtitle || "";
    var insight = pin.insight || pin.insightText || "";

    var html = '<div class="print-pin">';
    html += '<div class="print-pin-header">';
    if (source) html += '<span class="print-badge">' + esc(source) + '</span>';
    html += '<span class="print-title">' + esc(title) + '</span>';
    html += '</div>';

    if (subtitle) {
      html += '<div class="print-subtitle">' + esc(subtitle) + '</div>';
    }

    if (insight) {
      // Render markdown to HTML
      var insightHtml = insight
        .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/^## (.+)$/gm, "<strong>$1</strong>")
        .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
        .replace(/\*(.+?)\*/g, "<em>$1</em>")
        .replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>")
        .replace(/^- (.+)$/gm, "<li>$1</li>");
      insightHtml = insightHtml.replace(/((?:<li>.*<\/li>\s*)+)/g, "<ul>$1</ul>");
      insightHtml = insightHtml.replace(/\n/g, "<br>");
      html += '<div class="print-insight">' + insightHtml + '</div>';
    }

    if (pin.chartSvg) {
      html += '<div class="print-chart">' + pin.chartSvg + '</div>';
    }

    if (pin.tableHtml) {
      html += '<div class="print-table">' + pin.tableHtml + '</div>';
    }

    html += '</div>';
    return html;
  }

  /**
   * Helper: escape HTML entities.
   */
  function esc(s) {
    if (!s) return "";
    return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;")
      .replace(/>/g,"&gt;").replace(/"/g,"&quot;");
  }

  /**
   * Return comprehensive print-optimised CSS.
   */
  function getPrintStyles() {
    return [
      "* { box-sizing: border-box; margin: 0; padding: 0; }",
      "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; font-size: 11pt; color: #1e293b; line-height: 1.5; padding: 0; }",
      ".print-header { text-align: center; padding: 24pt 0 16pt; border-bottom: 2px solid #2563eb; margin-bottom: 16pt; }",
      ".print-header h1 { font-size: 18pt; font-weight: 700; color: #1e293b; margin-bottom: 4pt; }",
      ".print-date { font-size: 10pt; color: #64748b; }",
      ".print-section { page-break-before: auto; padding: 12pt 0 6pt; margin-top: 12pt; border-bottom: 1px solid #e2e8f0; }",
      ".print-section h2 { font-size: 14pt; font-weight: 600; color: #1e293b; }",
      ".print-pin { page-break-inside: avoid; border: 1px solid #e2e8f0; border-radius: 4pt; padding: 12pt; margin: 10pt 0; background: #fff; }",
      ".print-pin-header { display: flex; align-items: center; gap: 8pt; margin-bottom: 6pt; }",
      ".print-badge { font-size: 8pt; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5pt; color: #2563eb; background: #eff6ff; padding: 2pt 6pt; border-radius: 3pt; }",
      ".print-title { font-size: 12pt; font-weight: 600; color: #1e293b; }",
      ".print-subtitle { font-size: 10pt; color: #64748b; margin-bottom: 6pt; }",
      ".print-insight { font-size: 10pt; color: #334155; margin: 8pt 0; padding: 8pt; background: #f8fafc; border-left: 3pt solid #2563eb; border-radius: 2pt; }",
      ".print-insight strong { font-weight: 600; }",
      ".print-insight ul { padding-left: 16pt; margin: 4pt 0; }",
      ".print-insight blockquote { padding-left: 8pt; border-left: 2pt solid #94a3b8; color: #64748b; margin: 4pt 0; }",
      ".print-chart { margin: 8pt 0; text-align: center; }",
      ".print-chart svg { max-width: 100%; height: auto; }",
      ".print-table { margin: 8pt 0; overflow-x: auto; }",
      ".print-table table { width: 100%; border-collapse: collapse; font-size: 9pt; }",
      ".print-table th, .print-table td { border: 1px solid #e2e8f0; padding: 4pt 6pt; text-align: left; }",
      ".print-table th { background: #f1f5f9; font-weight: 600; }",
      ".print-footer { text-align: center; font-size: 8pt; color: #94a3b8; margin-top: 20pt; padding-top: 8pt; border-top: 1px solid #e2e8f0; }",
      "@media print {",
      "  body { padding: 0; }",
      "  .print-pin { break-inside: avoid; }",
      "  .print-section { break-before: auto; }",
      "  .print-chart svg { max-height: 350pt; }",
      "}"
    ].join("\n");
  }

  // ===========================================================================
  // Single-File Hub Generation — via Shiny/R
  // ===========================================================================

  /**
   * Request single-file hub generation from R.
   * Uses the current project's reports to auto-generate a combined hub file.
   */
  function generateHub() {
    if (!HubApp.state.activeProject) {
      HubApp.showToast("No project selected", 3000);
      return;
    }

    showProgress("Generating combined hub file...");

    var payload = JSON.stringify({
      project_path: HubApp.state.activeProject.path,
      project_name: HubApp.state.activeProject.name
    });

    if (!HubApp.sendToShiny("hub_generate_hub", payload)) {
      hideProgress();
      HubApp.showToast("Generation failed: Shiny not connected", 5000);
    }
  }

  /**
   * Handle hub generation completion from R.
   * @param {object} data - { success, path, filename, n_reports, error }
   */
  function handleHubGenerateComplete(data) {
    hideProgress();
    if (data && data.success) {
      HubApp.showToast("Hub saved: " + (data.filename || "combined.html"), 5000);
    } else {
      HubApp.showToast("Generation failed: " + (data ? data.error : "Unknown error"), 5000);
    }
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
    exportPdf: exportPdf,
    exportAllPngs: exportAllPngs,
    generateHub: generateHub,
    handlePptxComplete: handlePptxComplete,
    handlePngZipComplete: handlePngZipComplete,
    handleHubGenerateComplete: handleHubGenerateComplete,
    hideProgress: hideProgress
  };
})();
