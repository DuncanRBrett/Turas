/**
 * Executive Takeout — controller / tab. Orchestrates the deterministic engine
 * and the two views, and owns all interaction wiring (the Read/Present toggle,
 * inline editing, deep-links, vetoes, reset). Thin by design: gather -> build
 * -> render -> wire. Registered as a top-level tab in 24_shell.js.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var fmt = TR.fmt;

  var APEX_ID = "__apex__";

  /** Gather candidates, apply the researcher's vetoes, build the takeout. */
  takeout.compute = function (banner) {
    var inputs = takeout.gather(banner);
    inputs.vetoes = takeout.state.vetoes();
    return takeout.buildTakeout(inputs);
  };

  function currentView() {
    return (TR.d2 && TR.d2.state.takeoutView === "present") ? "present" : "read";
  }

  /** The view toggle + reset controls. */
  function headHtml(view) {
    var btn = function (id, label) {
      return '<button role="radio" class="tko-vbtn" data-view="' + id + '" aria-checked="' +
        (view === id ? "true" : "false") + '" tabindex="' + (view === id ? "0" : "-1") +
        '">' + label + "</button>";
    };
    var reset = takeout.state.hasCuration()
      ? '<button class="tko-reset" data-tko-reset>Reset to engine</button>' : "";
    return '<div class="tko-head"><div class="tko-viewtoggle" role="radiogroup" ' +
      'aria-label="Takeout view">' + btn("read", "Read") + btn("present", "Present") +
      '</div><div class="tko-head-actions">' + reset +
      '<span class="tko-edithint"><svg class="tko-glyph" viewBox="0 0 24 24" aria-hidden="true">' +
      '<path d="M4 20h4L18 10l-4-4L4 16z" fill="none" stroke="currentColor" stroke-width="1.6" ' +
      'stroke-linejoin="round"></path></svg> Click any line to edit</span></div></div>';
  }

  /** Render the takeout tab into the host element. */
  takeout.render = function (host) {
    var view = currentView();
    var t = takeout.compute();
    var lowThreshold = (TR.AGG && TR.AGG.project && TR.AGG.project.low_base_threshold) || 30;
    var body = view === "present"
      ? takeout.presentView.html(t, { lowThreshold: lowThreshold })
      : takeout.readView.html(t, { lowThreshold: lowThreshold });
    host.innerHTML = '<div class="page tko-page">' + headHtml(view) +
      '<div class="tko-body tko-view-' + view + '">' + body + "</div>" +
      '<div class="tko-live" aria-live="polite"></div></div>';
    wire(host);
  };

  /** Announce a transient message to assistive tech (and nothing visual). */
  function announce(host, message) {
    var live = host.querySelector(".tko-live");
    if (live) { live.textContent = ""; live.textContent = message; }
  }

  /** Persist one edited field; "__apex__" is the answer, everything else is a
   *  finding's claim / so-what keyed by id::field. Stored as plain text. */
  function saveEdit(el, host) {
    var key = el.getAttribute("data-edit");
    var sep = key.indexOf("::");
    var id = key.slice(0, sep), field = key.slice(sep + 2);
    var text = (el.textContent || "").trim();
    if (id === APEX_ID) takeout.state.setApex(text);
    else takeout.state.setText(id, field, text);
    announce(host, "Saved");
  }

  /** Move focus between the two view radios with the arrow keys. */
  function wireToggleKeys(host) {
    var radios = [].slice.call(host.querySelectorAll(".tko-vbtn"));
    radios.forEach(function (btn, i) {
      btn.addEventListener("keydown", function (e) {
        if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
        e.preventDefault();
        var next = radios[(i + (e.key === "ArrowRight" ? 1 : radios.length - 1)) % radios.length];
        setView(host, next.getAttribute("data-view"));
      });
    });
  }

  function setView(host, view) {
    TR.d2.state.takeoutView = view;
    if (TR.d2.pushHash) TR.d2.pushHash();
    takeout.render(host);
  }

  /** Attach all interaction handlers (idempotent per render). */
  function wire(host) {
    host.querySelectorAll(".tko-vbtn").forEach(function (btn) {
      btn.addEventListener("click", function () { setView(host, btn.getAttribute("data-view")); });
    });
    wireToggleKeys(host);
    // inline editing — save on blur so we never lose the caret mid-edit
    host.addEventListener("focusout", function (e) {
      if (e.target && e.target.getAttribute && e.target.getAttribute("data-edit")) {
        saveEdit(e.target, host);
      }
    });
    // deep-link a card to its full crosstab; veto promotes the next candidate
    host.addEventListener("click", function (e) {
      var goq = e.target.closest("[data-goq]");
      if (goq) { TR.shell.goQuestion(goq.getAttribute("data-goq")); return; }
      var veto = e.target.closest("[data-veto]");
      if (veto) {
        takeout.state.setVeto(veto.getAttribute("data-veto"), true);
        announce(host, "Finding hidden — next candidate promoted");
        takeout.render(host);
        return;
      }
      if (e.target.closest("[data-tko-reset]")) {
        takeout.state.reset();
        announce(host, "Reset to the engine's selection");
        takeout.render(host);
      }
    });
  }

})(typeof window !== "undefined" ? window : globalThis);
