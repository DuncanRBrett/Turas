/* brand_chart_focus.js
 *
 * "Chart brands": a per-chart deviation from the category header's
 * comparison set.
 *
 * Stage 2 put one brand control in the category header and hid every
 * per-panel focal select and brand filter. That was right: the two sets
 * duplicated each other and their counts disagreed. But the per-panel filter
 * carried a "Sync table and chart" toggle, and with it off an analyst could
 * hide a brand from the chart while keeping it in the table. This file gives
 * that back as a control of its own.
 *
 * Two rules keep it a deviation rather than a competing selection.
 *
 *   1. It can only narrow. The popover lists the brands the header shows
 *      right now, so a brand the header excluded can never come back into a
 *      chart through here.
 *   2. Any header change resets it. BrandSelector.applyRemoteHiddenSet
 *      already writes hiddenChart from hiddenTable on every published set,
 *      so the reset is the substrate's own behaviour. Nothing here has to
 *      remember to undo anything.
 *
 * A deviating chart says so in three places: the trigger reads "3 of 6"
 * rather than "same as table", a note sits above the chart naming what is
 * missing, and brand_pins.js reads that note so a pin or a PNG of the chart
 * carries the same words.
 *
 * The mount (.br-cf) and the note (.br-cf-note) are emitted by R, in
 * panels/00_chart_focus_widget.R, next to the charts that have both a table
 * beside them and a chart-only visibility map behind them. This file finds
 * the mount, walks up to the panel that owns it, and drives that panel's own
 * BrandSelector handle through setHiddenChart(). No filtering is
 * reimplemented and no number is recomputed.
 */
(function () {
  "use strict";

  var PANEL_SEL = ".fn-panel, .ma-panel, .cb-panel, .wom-panel";

  function ownerPanel(mount) {
    var el = mount.parentElement;
    while (el) {
      if (el.__brChartSelector) return el;
      el = el.parentElement;
    }
    // Fall back to the nearest known panel root, so a mount that renders
    // before its panel has registered still resolves on the next refresh.
    return mount.closest ? mount.closest(PANEL_SEL) : null;
  }

  function handleFor(mount) {
    var panel = ownerPanel(mount);
    if (!panel || !panel.__brChartSelector) return null;
    var h = panel.__brChartSelector;
    if (typeof h.setHiddenChart !== "function") return null;
    if (typeof h.isSplit === "function" && !h.isSplit()) return null;
    return h;
  }

  // What the header shows for this panel, what the chart shows, and the
  // difference between them. Everything the control renders comes from here,
  // read live, so the control cannot drift from the panel it governs.
  function readState(handle) {
    var brands = handle.getBrands();
    var hiddenTable = handle.getHidden();
    var hiddenChart = handle.getHiddenChart();
    var shown = [], deviating = [], focal = null;
    brands.forEach(function (b) {
      if (b.isFocal) focal = b.code;
      if (hiddenTable.has(b.code)) return;
      shown.push(b);
      if (hiddenChart.has(b.code)) deviating.push(b);
    });
    return {
      brands: brands, focal: focal, shown: shown, deviating: deviating,
      hiddenTable: hiddenTable
    };
  }

  function labelsOf(list) {
    return list.map(function (b) { return b.label || b.code; });
  }

  // --- the note, which is the half that survives a capture -----------------

  function noteFor(mount) {
    var scope = mount.getAttribute("data-chartfocus");
    var parent = mount.parentElement;
    if (!parent) return null;
    return parent.querySelector(
      '.br-cf-note[data-chartfocus-note="' + scope + '"]');
  }

  function paintNote(mount, st) {
    var note = noteFor(mount);
    if (!note) return;
    if (st.deviating.length === 0) {
      note.hidden = true;
      note.textContent = "";
      note.removeAttribute("data-chartfocus-clause");
      return;
    }
    var nChart = st.shown.length - st.deviating.length;
    var nTable = st.shown.length;
    note.textContent =
      "Chart shows " + nChart + " of the " + nTable +
      " brands in the table. Hidden from the chart: " +
      labelsOf(st.deviating).join(", ") + ".";
    // The short form a pin or a PNG title carries. Kept as an attribute so
    // brand_pins.js reads one value rather than parsing the sentence.
    note.setAttribute("data-chartfocus-clause",
      "chart shows " + nChart + " of " + nTable + " brands");
    note.hidden = false;
  }

  // --- the control ---------------------------------------------------------

  function closeAllPopovers(except) {
    document.querySelectorAll(".br-cf-pop").forEach(function (p) {
      if (p === except) return;
      p.hidden = true;
      var t = p.parentElement
        ? p.parentElement.querySelector(".br-cf-trigger") : null;
      if (t) t.setAttribute("aria-expanded", "false");
    });
  }

  function buildPopover(mount, handle) {
    var st = readState(handle);
    var pop = document.createElement("div");
    pop.className = "br-cf-pop";
    pop.hidden = true;

    var head = document.createElement("div");
    head.className = "br-cf-head";
    head.textContent = "Untick a brand to drop it from this chart. " +
                       "The table keeps every brand the header shows.";
    pop.appendChild(head);

    var list = document.createElement("div");
    list.className = "br-cf-list";
    st.shown.forEach(function (b) {
      var row = document.createElement("label");
      row.className = "br-cf-item";
      row.setAttribute("data-cf-brand", b.code);
      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.className = "br-cf-check";
      cb.value = b.code;
      cb.checked = !handle.getHiddenChart().has(b.code);
      // The focal brand stays in its own chart. A chart without it is a
      // category chart, and the header's premise is focal first.
      if (b.isFocal) { cb.checked = true; cb.disabled = true; }
      cb.addEventListener("change", function () { applyFromPopover(mount); });
      var span = document.createElement("span");
      span.textContent = b.label || b.code;
      row.appendChild(cb);
      row.appendChild(span);
      list.appendChild(row);
    });
    pop.appendChild(list);

    var reset = document.createElement("button");
    reset.type = "button";
    reset.className = "br-cf-reset";
    reset.textContent = "Match the table";
    reset.addEventListener("click", function () {
      pop.querySelectorAll(".br-cf-check").forEach(function (cb) {
        cb.checked = true;
      });
      applyFromPopover(mount);
    });
    pop.appendChild(reset);

    return pop;
  }

  // Publish the chart-only hidden set: everything the header already hides,
  // plus the brands unticked here. Union, never difference, so the control
  // cannot widen what the header chose.
  function applyFromPopover(mount) {
    var handle = handleFor(mount);
    if (!handle) return;
    var hidden = [];
    handle.getHidden().forEach(function (c) { hidden.push(c); });
    mount.querySelectorAll(".br-cf-check").forEach(function (cb) {
      if (!cb.checked && hidden.indexOf(cb.value) < 0) hidden.push(cb.value);
    });
    handle.setHiddenChart(hidden);
    refreshMount(mount);
  }

  function refreshMount(mount) {
    var handle = handleFor(mount);
    var trigger = mount.querySelector(".br-cf-trigger");
    if (!handle) {
      // No split-mode handle on this panel: the chart has no set of its own
      // to deviate with, so no control is offered.
      if (trigger) trigger.hidden = true;
      var n = noteFor(mount);
      if (n) { n.hidden = true; n.textContent = ""; }
      return;
    }
    var st = readState(handle);
    if (trigger) {
      trigger.hidden = false;
      var lbl = trigger.querySelector(".br-cf-label");
      var dev = st.deviating.length > 0;
      var nChart = st.shown.length - st.deviating.length;
      if (lbl) {
        lbl.textContent = dev
          ? "Chart brands: " + nChart + " of " + st.shown.length
          : "Chart brands: same as table";
      }
      trigger.classList.toggle("br-cf-on", dev);
      trigger.setAttribute("title", dev
        ? "This chart shows fewer brands than its table. Click to change."
        : "Drop a brand from this chart without dropping it from the table.");
    }
    paintNote(mount, st);
  }

  // The mount is empty in a freshly generated report, so this builds the
  // trigger. It is NOT empty in a saved copy: outerHTML serialises the
  // trigger this function built, while __cfBuilt is a plain property that
  // serialisation drops. Appending unconditionally would give every chart in
  // a reopened copy two triggers, and the single-control census would only
  // catch it on a report nobody runs the census against. So an existing
  // trigger is adopted and rewired, and a stale popover, whose checkboxes
  // are dead state, is dropped and rebuilt on the next open as always.
  function buildMount(mount) {
    if (mount.__cfBuilt) return;
    mount.__cfBuilt = true;

    mount.querySelectorAll(".br-cf-pop").forEach(function (p) { p.remove(); });

    var trigger = mount.querySelector(".br-cf-trigger");
    if (!trigger) {
      trigger = document.createElement("button");
      trigger.type = "button";
      trigger.className = "br-cf-trigger";
      mount.appendChild(trigger);
    }
    trigger.setAttribute("aria-haspopup", "true");
    trigger.setAttribute("aria-expanded", "false");
    var lbl = trigger.querySelector(".br-cf-label");
    if (!lbl) {
      lbl = document.createElement("span");
      lbl.className = "br-cf-label";
      lbl.textContent = "Chart brands: same as table";
      trigger.appendChild(lbl);
    }

    trigger.addEventListener("click", function (ev) {
      ev.stopPropagation();
      var handle = handleFor(mount);
      if (!handle) return;
      var open = mount.querySelector(".br-cf-pop");
      if (open && !open.hidden) {
        open.hidden = true;
        trigger.setAttribute("aria-expanded", "false");
        return;
      }
      if (open) open.remove();
      // Rebuilt on every open, because the brands it may offer are whatever
      // the header shows at this moment.
      var pop = buildPopover(mount, handle);
      mount.appendChild(pop);
      closeAllPopovers(pop);
      pop.hidden = false;
      trigger.setAttribute("aria-expanded", "true");
    });
  }

  function init() {
    document.querySelectorAll(".br-cf[data-chartfocus]").forEach(function (m) {
      buildMount(m);
      refreshMount(m);
    });
  }

  function refreshAll() {
    document.querySelectorAll(".br-cf[data-chartfocus]").forEach(refreshMount);
  }

  // --- surviving Save ------------------------------------------------------
  // A chart's deviation lives on its panel's BrandSelector handle, which is
  // JavaScript state that outerHTML cannot see. The note above the chart is
  // a plain text node, so before this it was the half that DID survive: a
  // reopened copy could carry a note saying the chart omits three brands
  // above a chart showing all of them. Writing the set into the DOM at save
  // time and reading it back at load closes that.
  //
  // The attribute is written only here, never by refreshMount, so a restore
  // cannot race a repaint that would clear the value it is about to read.
  var SAVE_ATTR = "data-cf-saved";

  function prepareForSave() {
    document.querySelectorAll(".br-cf[data-chartfocus]").forEach(function (m) {
      // An open popover is dead state once serialised: its checkboxes carry
      // .checked, which outerHTML never sees, and it is rebuilt on the next
      // open anyway.
      m.querySelectorAll(".br-cf-pop").forEach(function (p) { p.remove(); });
      var t = m.querySelector(".br-cf-trigger");
      if (t) t.setAttribute("aria-expanded", "false");

      var handle = handleFor(m);
      if (!handle) { m.removeAttribute(SAVE_ATTR); return; }
      var st = readState(handle);
      if (st.deviating.length === 0) { m.removeAttribute(SAVE_ATTR); return; }
      m.setAttribute(SAVE_ATTR, st.deviating.map(function (b) {
        return b.code;
      }).join(","));
    });
  }

  // Read every saved deviation first, then apply, because building a mount
  // repaints it and a one-pass loop would read a value it had just changed.
  // Union with the header's own hidden set, never a difference, so a restore
  // obeys the same only-narrows rule the control does.
  function restoreAll() {
    var wanted = [];
    document.querySelectorAll(".br-cf[data-chartfocus]").forEach(function (m) {
      var raw = m.getAttribute(SAVE_ATTR) || "";
      wanted.push({
        mount: m,
        codes: raw ? raw.split(",").filter(function (c) { return !!c; }) : []
      });
    });
    wanted.forEach(function (w) {
      buildMount(w.mount);
      var handle = w.codes.length ? handleFor(w.mount) : null;
      if (handle) {
        var hidden = [];
        handle.getHidden().forEach(function (c) { hidden.push(c); });
        w.codes.forEach(function (c) {
          if (hidden.indexOf(c) < 0) hidden.push(c);
        });
        handle.setHiddenChart(hidden);
      }
      refreshMount(w.mount);
    });
  }

  document.addEventListener("click", function (ev) {
    if (ev.target && ev.target.closest && !ev.target.closest(".br-cf")) {
      closeAllPopovers(null);
    }
  }, true);

  window.BrandChartFocus = {
    init: init,
    refreshAll: refreshAll,
    // Called by _brSyncSelectionState() just before the page is serialised,
    // and by brApplyAllComparisonSets() at the end of the load-time publish.
    prepareForSave: prepareForSave,
    restoreAll: restoreAll,
    // Read the pin and PNG clause for a captured root, or "" when nothing in
    // it deviates. brand_pins.js and the panel-local capture paths call this.
    clauseFor: function (root) {
      if (!root || !root.querySelectorAll) return "";
      var notes = root.querySelectorAll(".br-cf-note[data-chartfocus-clause]");
      for (var i = 0; i < notes.length; i++) {
        if (notes[i].hidden) continue;
        return notes[i].getAttribute("data-chartfocus-clause") || "";
      }
      return "";
    }
  };

  if (document.readyState === "complete") setTimeout(init, 0);
  else window.addEventListener("load", function () { setTimeout(init, 0); });
})();
