/**
 * Pattern recognition — controller / tab. Orchestrates the deterministic engine
 * and the single Read layout, and owns all interaction wiring (inline editing,
 * deep-links, the "how sure" explainer, and reset-to-engine). Thin by design:
 * gather -> build -> render -> wire. Registered as a top-level tab in 24_shell.js
 * (id stays "takeout"; the visible label is "Patterns").
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};

  var APEX_ID = "__apex__";

  /** Gather the report's findings/levels/headlines and build the patterns. */
  takeout.compute = function () {
    return takeout.buildPatterns(takeout.gather());
  };

  /** The reset control + edit hint (no view toggle — Read is the only view). */
  function headHtml() {
    var reset = takeout.state.hasCuration()
      ? '<button class="tko-reset" data-tko-reset title="Throw away your edits, ' +
        'vetoes and apex answer — restore exactly what the engine produced">' +
        "Discard my edits</button>" : "";
    return '<div class="tko-head"><div class="tko-head-actions">' + reset +
      '<span class="tko-edithint"><svg class="tko-glyph" viewBox="0 0 24 24" aria-hidden="true">' +
      '<path d="M4 20h4L18 10l-4-4L4 16z" fill="none" stroke="currentColor" stroke-width="1.6" ' +
      'stroke-linejoin="round"></path></svg> Click any line to edit</span></div></div>';
  }

  /** Render the takeout tab into the host element. */
  takeout.render = function (host) {
    var t = takeout.compute();
    host.innerHTML = '<div class="page tko-page">' + headHtml() +
      '<div class="tko-body tko-view-read">' + takeout.readView.html(t) + "</div>" +
      '<div class="tko-howsure-panel" hidden></div>' +
      '<div class="tko-live" aria-live="polite"></div></div>';
    wire(host);
  };

  /** Announce a transient message to assistive tech (and nothing visual). */
  function announce(host, message) {
    var live = host.querySelector(".tko-live");
    if (live) { live.textContent = ""; live.textContent = message; }
  }

  /** Persist one edited field; "__apex__" is the answer, everything else is a
   *  pattern's takeaway keyed by id::field. An edit equal to the engine's seed
   *  (or empty) is NOT stored — that keeps an unedited seed from going stale when
   *  the engine's wording changes on a re-run. Stored as plain text. */
  function saveEdit(el, host) {
    var key = el.getAttribute("data-edit");
    var sep = key.indexOf("::");
    var id = key.slice(0, sep), field = key.slice(sep + 2);
    var text = (el.textContent || "").trim();
    var seed = (el.getAttribute("data-seed") || "").trim();
    var value = (text === seed) ? "" : text;   // unchanged from seed -> drop, never persist
    if (id === APEX_ID) takeout.state.setApex(value);
    else takeout.state.setText(id, field, value);
    announce(host, value ? "Saved" : "Reset to the engine's wording");
  }

  /** Attach all interaction handlers (idempotent per render). */
  function wire(host) {
    // inline editing — save on blur so we never lose the caret mid-edit
    host.addEventListener("focusout", function (e) {
      if (e.target && e.target.getAttribute && e.target.getAttribute("data-edit")) {
        saveEdit(e.target, host);
      }
    });
    host.addEventListener("click", function (e) {
      // deep-link a pattern to the tab that shows its detail
      var go = e.target.closest("[data-goto]");
      if (go && TR.shell && TR.shell.goTab) { TR.shell.goTab(go.getAttribute("data-goto")); return; }
      // toggle the "how sure are these numbers?" explainer panel
      if (e.target.closest("[data-howsure]")) { toggleHowSure(host); return; }
      if (e.target.closest("[data-tko-reset]")) {
        takeout.state.reset();
        announce(host, "Edits discarded — back to the engine's selection");
        takeout.render(host);
      }
    });
  }

  /** Show/hide the shared confidence explainer (reused from TR.conf) inline. */
  function toggleHowSure(host) {
    var panel = host.querySelector(".tko-howsure-panel");
    if (!panel) return;
    if (panel.hidden) {
      panel.innerHTML = (TR.conf && TR.conf.calloutHtml) ? TR.conf.calloutHtml() : "";
      panel.hidden = false;
      var cl = panel.querySelector(".callout");
      if (cl) cl.classList.remove("collapsed");   // open it straight away
      var head = panel.querySelector("[data-callout]");
      if (head) head.addEventListener("click", function () {
        head.closest(".callout").classList.toggle("collapsed");
      });
      panel.scrollIntoView({ block: "nearest" });
    } else {
      panel.hidden = true;
      panel.innerHTML = "";
    }
  }

})(typeof window !== "undefined" ? window : globalThis);
