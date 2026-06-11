/**
 * Deck builder (Tier B) — collect questions and composite views, then
 * download a native, editable .pptx built entirely in-file (13_zip +
 * 14_pptx_parts + 15_pptx_slides). Shipped only when project.export.pptx
 * is enabled; the whole tier costs ~20 KB of source, not 0.94 MB.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var deck = TR.deck = {};
  deck.items = [];

  function refreshCount() {
    var badge = document.getElementById("deck-count");
    if (badge) badge.textContent = String(deck.items.length);
  }

  /** Add a question card (with its selected chart column) to the deck. */
  deck.addQuestion = function (card, payload) {
    var q = TR.data.questionById(payload, card.getAttribute("data-q"));
    if (!q) return;
    deck.items.push({ kind: "question", qid: q.id,
      colIndex: parseInt(card.getAttribute("data-col") || "0", 10) || 0,
      label: (q.code || q.id) + " — " + TR.charts.clip(q.title, 48) });
    refreshCount();
    TR.wire.toast("Added to deck (" + deck.items.length + ")");
  };

  /** Add a composite model snapshot to the deck. */
  deck.addComposite = function (model, payload) {
    deck.items.push({ kind: "composite", model: model,
      label: "Composite — " + model.items.map(function (i) {
        return i.code; }).join(" + ") });
    refreshCount();
    TR.wire.toast("Composite added to deck (" + deck.items.length + ")");
  };

  deck.removeAt = function (index, payload) {
    deck.items.splice(index, 1);
    refreshCount();
    deck.openDrawer(payload);
  };

  deck.clear = function (payload) {
    deck.items = [];
    refreshCount();
    deck.openDrawer(payload);
  };

  deck.openDrawer = function (payload) {
    var drawer = document.getElementById("deck-drawer");
    var list = deck.items.length
      ? deck.items.map(function (item, i) {
          return '<div class="deckitem"><span>' + (i + 1) + ". " +
            fmt.escapeHtml(item.label) + "</span>" +
            '<button type="button" data-action="deck-remove" data-index="' + i +
            '" aria-label="Remove from deck">✕</button></div>';
        }).join("")
      : '<p class="drawerhint">The deck is empty. Use <strong>+ Deck</strong> on any ' +
        "question or composite view, then download a native PowerPoint file — " +
        "real text and tables, every bar an editable shape. No screenshots.</p>";
    drawer.innerHTML = '<div class="drawerhead"><h2>Export deck</h2>' +
      '<button type="button" data-action="drawer-close" aria-label="Close">✕</button></div>' +
      list +
      (deck.items.length
        ? '<button type="button" class="primary wide" data-action="deck-download">' +
          "Download .pptx (" + deck.items.length + " exhibits)</button>" +
          '<button type="button" class="wide" data-action="deck-clear">Clear deck</button>'
        : "");
    TR.wire.openDrawer("deck-drawer");
  };

  /** Build the slide XML list for the current deck (pure given payload). */
  deck.buildSlides = function (payload) {
    var slideXmls = [TR.pptxSlides.titleSlide(payload, deck.items.length)];
    deck.items.forEach(function (item) {
      if (item.kind === "question") {
        var q = TR.data.questionById(payload, item.qid);
        if (q) {
          slideXmls.push.apply(slideXmls,
            TR.pptxSlides.questionSlides(q, payload, item.colIndex));
        }
      } else {
        slideXmls.push(TR.pptxSlides.compositeSlide(item.model, payload));
      }
    });
    return slideXmls;
  };

  /** Package and download the deck as a .pptx. */
  deck.download = function (payload) {
    var bytes;
    try {
      bytes = TR.pptx.package(deck.buildSlides(payload), payload);
    } catch (e) {
      if (global.console) console.error("[TurasReport] pptx build failed:", e);
      TR.wire.toast("PPTX build failed — see console");
      return;
    }
    var blob = new Blob([bytes], {
      type: "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    });
    var link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = fmt.slug(payload.project.name) + "_deck.pptx";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
    TR.wire.closeDrawers();
    TR.wire.toast("Native PowerPoint downloaded — fully editable");
  };

})(typeof window !== "undefined" ? window : globalThis);
