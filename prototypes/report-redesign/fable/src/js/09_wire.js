/**
 * Event wiring — lazy rendering, search, delegated actions, drawers with
 * focus management, and toast feedback. Separated from the shell so the
 * shell stays declarative.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var wire = TR.wire = {};
  var lastFocus = null;

  wire.init = function (payload) {
    observeCards(payload);
    wireSearch();
    wireActions(payload);
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") wire.closeDrawers();
    });
  };

  /**
   * Render card bodies as they approach the viewport, with a progressive
   * background backstop: a timer fills remaining cards a few at a time, so
   * every card renders even if IntersectionObserver never fires (printing,
   * zero-height embeds) — scroll just jumps the queue.
   */
  var FILL_BATCH = 2, FILL_INTERVAL_MS = 80;

  function observeCards(payload) {
    var cardsEls = Array.prototype.slice.call(
      document.querySelectorAll("#cards .card"));
    var fill = function (el) {
      var body = el.querySelector(".cardbody");
      if (body && body.classList.contains("pending")) TR.cards.fill(el, payload);
    };
    if ("IntersectionObserver" in global) {
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          observer.unobserve(entry.target);
          fill(entry.target);
        });
      }, { rootMargin: "900px 0px" });
      cardsEls.forEach(function (el) { observer.observe(el); });
    }
    var queue = cardsEls.slice();
    var timer = setInterval(function () {
      var done = 0;
      while (queue.length && done < FILL_BATCH) {
        fill(queue.shift());
        done++;
      }
      if (!queue.length) clearInterval(timer);
    }, FILL_INTERVAL_MS);
  }

  /** Ensure a card body exists right now (export paths need filled DOM). */
  wire.ensureFilled = function (article, payload) {
    var body = article.querySelector(".cardbody");
    if (body && body.classList.contains("pending")) TR.cards.fill(article, payload);
  };

  function wireSearch() {
    var input = document.getElementById("search");
    if (!input) return;
    input.addEventListener("input", function () {
      var term = input.value.trim().toLowerCase();
      document.querySelectorAll("#cards .card").forEach(function (card) {
        card.classList.toggle("hidden",
          !!term && card.getAttribute("data-search").indexOf(term) === -1);
      });
      document.querySelectorAll("#nav .navlink").forEach(function (link) {
        var card = document.getElementById("card-" + link.getAttribute("data-q"));
        link.classList.toggle("hidden", !!card && card.classList.contains("hidden"));
      });
    });
  }

  /** One delegated click handler for every [data-action] button. */
  function wireActions(payload) {
    document.addEventListener("click", function (e) {
      var btn = e.target.closest("[data-action]");
      if (!btn) return;
      var action = btn.getAttribute("data-action");
      var card = btn.closest(".card");
      var handlers = {
        "col": function () { selectColumn(btn, card, payload); },
        "copy-table": function () { TR.exportCopy.copyTable(card, payload); },
        "copy-chart": function () { TR.exportCopy.copyChart(card, payload); },
        "download-png": function () { TR.exportPng.downloadCard(card, payload); },
        "deck-add": function () { TR.deck.addQuestion(card, payload); },
        "deck-open": function () { TR.deck.openDrawer(payload); },
        "deck-download": function () { TR.deck.download(payload); },
        "deck-clear": function () { TR.deck.clear(payload); },
        "deck-remove": function () {
          TR.deck.removeAt(parseInt(btn.getAttribute("data-index"), 10), payload);
        },
        "compose-open": function () { TR.composer.openDrawer(payload); },
        "compose-submit": function () { TR.composer.submit(payload); },
        "composite-remove": function () { TR.composer.removeCard(card); },
        "composite-deck": function () { TR.composer.addToDeck(card, payload); },
        "composite-png": function () { TR.composer.downloadPng(card, payload); },
        "composite-copy": function () { TR.composer.copyPng(card, payload); },
        "drawer-close": function () { wire.closeDrawers(); }
      };
      if (handlers[action]) handlers[action]();
    });
  }

  function selectColumn(btn, card, payload) {
    card.setAttribute("data-col", btn.getAttribute("data-col"));
    TR.cards.refreshCharts(card, payload);
  }

  /** Open a drawer with backdrop + focus capture. */
  wire.openDrawer = function (id) {
    wire.closeDrawers();
    lastFocus = document.activeElement;
    document.getElementById("drawer-backdrop").hidden = false;
    var drawer = document.getElementById(id);
    drawer.hidden = false;
    var focusable = drawer.querySelector("input, select, button");
    if (focusable) focusable.focus();
  };

  /** Close any open drawer and restore focus to the opener. */
  wire.closeDrawers = function () {
    var backdrop = document.getElementById("drawer-backdrop");
    if (backdrop) backdrop.hidden = true;
    ["composer-drawer", "deck-drawer"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.hidden = true;
    });
    if (lastFocus && lastFocus.focus) { lastFocus.focus(); lastFocus = null; }
  };

  /** Toast feedback (aria-live region announced by screen readers). */
  wire.toast = function (message) {
    var holder = document.getElementById("toast");
    if (!holder) return;
    var note = document.createElement("div");
    note.className = "toastmsg";
    note.textContent = message;
    holder.appendChild(note);
    requestAnimationFrame(function () { note.classList.add("show"); });
    setTimeout(function () {
      note.classList.remove("show");
      setTimeout(function () { note.remove(); }, 400);
    }, 2600);
  };

  if (typeof document !== "undefined") {
    document.addEventListener("click", function (e) {
      if (e.target && e.target.id === "drawer-backdrop") wire.closeDrawers();
    });
  }

})(typeof window !== "undefined" ? window : globalThis);
