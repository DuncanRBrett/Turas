/**
 * Tier A export — clipboard. Tables copy as rich HTML + TSV so PowerPoint,
 * Word and Excel paste a real editable table; charts copy as hi-res PNG.
 * Falls back to execCommand (rich) or download (image) on older engines.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var copy = TR.exportCopy = {};

  /** Write {html, text} to the clipboard; resolves true on success. */
  function writeRich(html, text) {
    if (navigator.clipboard && global.ClipboardItem) {
      var item = new ClipboardItem({
        "text/html": new Blob([html], { type: "text/html" }),
        "text/plain": new Blob([text], { type: "text/plain" })
      });
      return navigator.clipboard.write([item]).then(function () { return true; },
        function () { return writeFallback(html); });
    }
    return Promise.resolve(writeFallback(html));
  }

  /** Legacy rich-text fallback: select an off-screen node and copy it. */
  function writeFallback(html) {
    var holder = document.createElement("div");
    holder.style.cssText = "position:fixed;left:-9999px;top:0;";
    holder.innerHTML = html;
    document.body.appendChild(holder);
    var range = document.createRange();
    range.selectNodeContents(holder);
    var selection = getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    selection.removeAllRanges();
    document.body.removeChild(holder);
    return ok;
  }

  /** Copy a question's table as an editable rich table. */
  copy.copyTable = function (card, payload) {
    var q = TR.data.questionById(payload, card.getAttribute("data-q"));
    if (!q) return;
    writeRich(TR.tables.clipboardHtml(q, payload), TR.tables.tsv(q, payload))
      .then(function (ok) {
        TR.wire.toast(ok
          ? "Table copied — paste into PowerPoint, Word or Excel"
          : "Copy failed — your browser blocked clipboard access");
      });
  };

  /** Copy a PNG blob; Safari needs the promise-flavoured ClipboardItem. */
  function writeImage(svgString, filenameHint) {
    if (navigator.clipboard && global.ClipboardItem) {
      var blobPromise = new Promise(function (resolve, reject) {
        TR.exportPng.toBlob(svgString, function (blob) {
          if (blob) resolve(blob); else reject(new Error("rasterise failed"));
        });
      });
      return navigator.clipboard
        .write([new ClipboardItem({ "image/png": blobPromise })])
        .then(function () { return "copied"; }, function () {
          return downloadInstead(svgString, filenameHint);
        });
    }
    return downloadInstead(svgString, filenameHint);
  }

  function downloadInstead(svgString, filenameHint) {
    return new Promise(function (resolve) {
      TR.exportPng.toBlob(svgString, function (blob) {
        if (!blob) { resolve("failed"); return; }
        var link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = filenameHint + ".png";
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(link.href);
        resolve("downloaded");
      });
    });
  }

  var COPY_TOASTS = {
    copied: "Chart copied as image",
    downloaded: "Clipboard images not supported here — PNG downloaded instead",
    failed: "Image export failed — see console"
  };

  /** Copy a question's chart (+trend) as a hi-res PNG. */
  copy.copyChart = function (card, payload) {
    var q = TR.data.questionById(payload, card.getAttribute("data-q"));
    if (!q) return;
    var colIndex = parseInt(card.getAttribute("data-col") || "0", 10) || 0;
    var chartSvgs = [TR.charts.forQuestion(q, payload, colIndex),
      TR.charts.trend(q, payload, colIndex)];
    var cols = TR.data.bannerColumns(payload, q);
    var svgString = TR.exportPng.cardSvg((q.code || q.id) + " — " + q.title,
      payload.project.name + " · column: " + (cols[colIndex] || "Total"),
      chartSvgs, null, payload);
    writeImage(svgString, fmt.slug((q.code || q.id) + "_chart"))
      .then(function (outcome) { TR.wire.toast(COPY_TOASTS[outcome]); });
  };

  /** Copy a composite view as a hi-res PNG. */
  copy.copyCompositePng = function (model, payload) {
    var svgString = TR.exportPng.cardSvg("Composite view — " +
      model.items.map(function (i) { return i.code; }).join(" + "),
      payload.project.name + " · column: " + model.column,
      [TR.composer.renderSvg(model, payload)], null, payload);
    writeImage(svgString, "composite")
      .then(function (outcome) { TR.wire.toast(COPY_TOASTS[outcome]); });
  };

})(typeof window !== "undefined" ? window : globalThis);
