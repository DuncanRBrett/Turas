/**
 * TurasPins — PowerPoint Export
 *
 * Generates a .pptx file with one pin per slide using PptxGenJS.
 * Section dividers become section header slides. Uses the existing
 * _exportToBlob() pipeline for PNG/JPEG rendering at the chosen quality.
 *
 * Depends on: pptxgen.bundle.js (vendor), turas_pins_utils, turas_pins,
 *             turas_pins_export
 * @namespace TurasPins
 */
/* global TurasPins, PptxGenJS */

(function() {
  "use strict";

  // ── Slide Dimensions (inches, 16:9 widescreen) ───────────────────────────
  var SLIDE_W = 13.33;
  var SLIDE_H = 7.5;
  var MARGIN  = 0.5;
  var IMG_MAX_W = SLIDE_W - MARGIN * 2;  // 12.33"
  var IMG_MAX_H = 5.5;                    // Leave room for title + margin

  // ── Helpers ───────────────────────────────────────────────────────────────

  /** Convert blob to base64 data URL string and read image dimensions */
  function _blobToDataUrl(blob, callback) {
    var reader = new FileReader();
    reader.onloadend = function() {
      var dataUrl = reader.result;
      if (!dataUrl) { callback(null, 0, 0); return; }
      // Load as image to get natural dimensions (5s timeout guards against hang)
      var img = new Image();
      var timeout = setTimeout(function() { callback(dataUrl, 0, 0); }, 5000);
      img.onload = function() { clearTimeout(timeout); callback(dataUrl, img.naturalWidth, img.naturalHeight); };
      img.onerror = function() { clearTimeout(timeout); callback(dataUrl, 0, 0); };
      img.src = dataUrl;
    };
    reader.onerror = function() { callback(null, 0, 0); };
    reader.readAsDataURL(blob);
  }

  /** Scale image dimensions to fit within maxW x maxH while preserving aspect ratio */
  function _fitImage(imgW, imgH, maxW, maxH) {
    if (!imgW || !imgH || imgW <= 0 || imgH <= 0) {
      return { w: maxW, h: maxH };
    }
    var aspect = imgW / imgH;
    var w = maxW;
    var h = w / aspect;
    if (h > maxH) {
      h = maxH;
      w = h * aspect;
    }
    return { w: w, h: h };
  }

  /** Build a safe filename from a title string */
  function _safeFilename(title) {
    return title.replace(/[^a-zA-Z0-9 _-]/g, "").replace(/\s+/g, "_").substring(0, 60);
  }

  /** Get the date stamp for filenames */
  function _datestamp() {
    var d = new Date();
    return d.getFullYear() +
      String(d.getMonth() + 1).padStart(2, "0") +
      String(d.getDate()).padStart(2, "0");
  }

  /** Strip markdown formatting for plain text slide content */
  function _stripMarkdown(md) {
    if (!md) return "";
    return md
      .replace(/^## /gm, "")
      .replace(/\*\*(.+?)\*\*/g, "$1")
      .replace(/\*(.+?)\*/g, "$1")
      .replace(/^> /gm, "")
      .replace(/^- /gm, "\u2022 ");
  }

  // ── Progress Overlay ──────────────────────────────────────────────────────

  function _showProgress(message) {
    var el = document.getElementById("turas-pptx-progress");
    if (!el) {
      el = document.createElement("div");
      el.id = "turas-pptx-progress";
      el.style.cssText =
        "position:fixed;top:0;left:0;right:0;bottom:0;z-index:99999;" +
        "background:rgba(0,0,0,0.5);display:flex;align-items:center;" +
        "justify-content:center;";
      var box = document.createElement("div");
      box.id = "turas-pptx-progress-box";
      box.style.cssText =
        "background:#fff;border-radius:12px;padding:32px 48px;" +
        "box-shadow:0 8px 32px rgba(0,0,0,0.2);text-align:center;" +
        "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;" +
        "min-width:320px;";
      var title = document.createElement("div");
      title.style.cssText = "font-size:16px;font-weight:600;color:#1a2744;margin-bottom:12px;";
      title.textContent = "Exporting to PowerPoint";
      var text = document.createElement("div");
      text.id = "turas-pptx-progress-text";
      text.style.cssText = "font-size:13px;color:#64748b;";
      text.textContent = message;
      var bar = document.createElement("div");
      bar.style.cssText =
        "margin-top:16px;height:4px;background:#e2e8f0;border-radius:2px;overflow:hidden;";
      var fill = document.createElement("div");
      fill.id = "turas-pptx-progress-bar";
      fill.style.cssText =
        "height:100%;background:#323367;border-radius:2px;transition:width 0.3s ease;width:0%;";
      bar.appendChild(fill);
      box.appendChild(title);
      box.appendChild(text);
      box.appendChild(bar);
      el.appendChild(box);
      document.body.appendChild(el);
    } else {
      el.style.display = "flex";
      var t = document.getElementById("turas-pptx-progress-text");
      if (t) t.textContent = message;
    }
  }

  function _updateProgress(message, pct) {
    var t = document.getElementById("turas-pptx-progress-text");
    var b = document.getElementById("turas-pptx-progress-bar");
    if (t) t.textContent = message;
    if (b) b.style.width = Math.round(pct) + "%";
  }

  function _hideProgress() {
    var el = document.getElementById("turas-pptx-progress");
    if (el) el.style.display = "none";
  }

  // ── Export All Pins to PPTX ───────────────────────────────────────────────

  /**
   * Export all pins as a PowerPoint presentation.
   * Each pin becomes one slide; section dividers become section header slides.
   *
   * @param {Object} [options] - Export options
   * @param {string} [options.filename] - Override output filename
   * @param {Function} [options.onComplete] - Called when export finishes
   */
  TurasPins.exportPptx = function(options) {
    options = options || {};
    var pins = TurasPins.getAll();
    if (!pins || pins.length === 0) {
      TurasPins._showToast("No pins to export");
      return;
    }

    if (typeof PptxGenJS === "undefined") {
      TurasPins._showToast("PowerPoint export not available");
      console.error("[TurasPins] PptxGenJS not loaded");
      return;
    }

    var pinCount = 0;
    for (var c = 0; c < pins.length; c++) {
      if (pins[c].type === "pin") pinCount++;
    }
    if (pinCount === 0) {
      TurasPins._showToast("No pin cards to export (only section dividers found)");
      return;
    }

    _showProgress("Preparing slides...");

    var pres = new PptxGenJS();
    pres.layout = "LAYOUT_WIDE";

    // Build report title from page or config
    var reportTitle = document.title || "Turas Report";
    var config = TurasPins.getConfig();
    if (config && config.moduleLabel) reportTitle = config.moduleLabel;

    // Process pins sequentially to avoid memory spikes
    var idx = 0;
    var total = pins.length;

    (function processNext() {
      if (idx >= total) {
        // All slides built — generate and download
        _updateProgress("Building PowerPoint file...", 95);
        var safeName = options.filename ||
          (_safeFilename(reportTitle) + "_pins_" + _datestamp());
        pres.writeFile({ fileName: safeName + ".pptx" })
          .then(function() {
            _hideProgress();
            TurasPins._showToast("PowerPoint exported (" + pinCount + " slides)");
            if (options.onComplete) options.onComplete(true);
          })
          .catch(function(err) {
            _hideProgress();
            console.error("[TurasPins] PPTX write failed:", err && err.message ? err.message : err);
            TurasPins._showToast("PowerPoint export failed \u2014 try fewer slides or lower quality");
            if (options.onComplete) options.onComplete(false);
          });
        return;
      }

      var item = pins[idx];
      var slideNum = idx + 1;

      if (item.type === "section") {
        // Section divider → section header slide
        var secSlide = pres.addSlide();
        secSlide.addText(item.title || "Section", {
          x: MARGIN, y: "40%", w: IMG_MAX_W, h: 1,
          fontSize: 28, fontFace: "Segoe UI",
          color: "1a2744", bold: true, align: "center"
        });
        idx++;
        _updateProgress("Slide " + slideNum + " of " + total + " (section)", (slideNum / total) * 90);
        setTimeout(processNext, 50);
        return;
      }

      if (item.type !== "pin") {
        idx++;
        setTimeout(processNext, 50);
        return;
      }

      // Pin card → content slide with image
      _updateProgress("Rendering slide " + slideNum + " of " + total + "...", (slideNum / total) * 90);

      // 10s per-pin timeout prevents the chain from stalling on a hung export
      var pinDone = false;
      var pinTimer = setTimeout(function() {
        if (pinDone) return; pinDone = true;
        console.warn("[TurasPins] Pin export timed out: " + (item.title || item.id));
        var toSlide = pres.addSlide();
        toSlide.addText(item.title || "Pinned View", {
          x: MARGIN, y: MARGIN, w: IMG_MAX_W, h: 0.6,
          fontSize: 18, fontFace: "Segoe UI", color: "1a2744", bold: true
        });
        toSlide.addText("(Slide rendering timed out)", {
          x: MARGIN, y: 2, w: IMG_MAX_W, h: 0.4,
          fontSize: 12, color: "94a3b8", align: "center"
        });
        idx++;
        setTimeout(processNext, TurasPins.EXPORT_ALL_DELAY_MS);
      }, 10000);

      TurasPins._exportToBlob(item, function(blob) {
        if (pinDone) return; pinDone = true; clearTimeout(pinTimer);
        if (!blob) {
          // Still add slide with title even if image fails
          var errSlide = pres.addSlide();
          errSlide.addText(item.title || "Pinned View", {
            x: MARGIN, y: MARGIN, w: IMG_MAX_W, h: 0.6,
            fontSize: 18, fontFace: "Segoe UI",
            color: "1a2744", bold: true
          });
          errSlide.addText("(Image rendering failed)", {
            x: MARGIN, y: 2, w: IMG_MAX_W, h: 0.4,
            fontSize: 12, color: "94a3b8", align: "center"
          });
          idx++;
          setTimeout(processNext, TurasPins.EXPORT_ALL_DELAY_MS);
          return;
        }

        _blobToDataUrl(blob, function(dataUrl, imgW, imgH) {
          if (!dataUrl) {
            idx++;
            setTimeout(processNext, TurasPins.EXPORT_ALL_DELAY_MS);
            return;
          }

          var slide = pres.addSlide();

          // Pin image already contains title and metadata from the SVG
          // render, so we place it near the top without duplicating text.
          var imgTop = MARGIN;
          var availH = SLIDE_H - imgTop - MARGIN;
          var dims = _fitImage(imgW, imgH, IMG_MAX_W, Math.min(availH, IMG_MAX_H));
          var imgX = MARGIN + (IMG_MAX_W - dims.w) / 2; // centre horizontally
          slide.addImage({
            data: dataUrl,
            x: imgX, y: imgTop,
            w: dims.w, h: dims.h
          });

          idx++;
          setTimeout(processNext, TurasPins.EXPORT_ALL_DELAY_MS);
        });
      });
    })();
  };

  // ── Export Single Pin to PPTX ─────────────────────────────────────────────

  /**
   * Export a single pin as a one-slide PowerPoint presentation.
   * @param {string} pinId - The pin ID to export
   */
  TurasPins.exportSinglePptx = function(pinId) {
    var pins = TurasPins.getAll();
    var pin = null;
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].id === pinId) { pin = pins[i]; break; }
    }
    if (!pin) {
      TurasPins._showToast("Pin not found");
      return;
    }

    if (typeof PptxGenJS === "undefined") {
      TurasPins._showToast("PowerPoint export not available");
      return;
    }

    TurasPins._showToast("Exporting to PowerPoint...");

    TurasPins._exportToBlob(pin, function(blob) {
      if (!blob) {
        TurasPins._showToast("Export failed — could not render pin");
        return;
      }
      _blobToDataUrl(blob, function(dataUrl, imgW, imgH) {
        if (!dataUrl) {
          TurasPins._showToast("Export failed — could not encode image");
          return;
        }

        var pres = new PptxGenJS();
        pres.layout = "LAYOUT_WIDE";

        var slide = pres.addSlide();
        var title = pin.title || pin.metricTitle || pin.qTitle || pin.qCode || "Pinned View";

        // Pin image already contains title and metadata from the SVG render
        var imgTop = MARGIN;
        var availH = SLIDE_H - imgTop - MARGIN;
        var dims = _fitImage(imgW, imgH, IMG_MAX_W, Math.min(availH, IMG_MAX_H));
        var imgX = MARGIN + (IMG_MAX_W - dims.w) / 2;
        slide.addImage({
          data: dataUrl,
          x: imgX, y: imgTop,
          w: dims.w, h: dims.h
        });

        var safeName = _safeFilename(title) + "_" + _datestamp();
        pres.writeFile({ fileName: safeName + ".pptx" })
          .then(function() {
            TurasPins._showToast("PowerPoint exported");
          })
          .catch(function(err) {
            console.error("[TurasPins] PPTX write failed:", err && err.message ? err.message : err);
            TurasPins._showToast("PowerPoint export failed \u2014 try lower quality setting");
          });
      });
    });
  };

})();
