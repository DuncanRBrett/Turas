/* brand_selector_dropdown.js
 *
 * Shared dropdown-style brand selector for the brand HTML report.
 * Replaces the per-panel chip-strip pattern with a compact "Filter brands ▾"
 * trigger that opens a checkbox popover. Live updates on each toggle —
 * no Apply / Cancel button.
 *
 * Public API
 * ----------
 *   const handle = BrandSelector.create({
 *     panelId,        // unique id (e.g. "demographics", "funnel-awareness")
 *     triggerEl,      // <button> element built by R
 *     anchorEl,       // optional: container the popover is positioned within
 *     brands,         // [{code, label, color, isFocal}]
 *     mode,           // "unified" | "split"
 *     initialHidden,  // string[] — brand codes hidden at start (default [])
 *     syncDefault,    // boolean — for split mode; default true
 *     onChange,       // (hiddenSet, scope) => void
 *                     //   scope === "all" | "table" | "chart"
 *     labels: {       // optional overrides
 *       title, allBtn, noneBtn, syncToggle,
 *       columnTable, columnChart
 *     }
 *   });
 *
 *   handle.getHidden()       // -> Set<string>      (table when split)
 *   handle.getHiddenChart()  // -> Set<string>      (split mode only)
 *   handle.setHidden(set)    // -> void
 *   handle.refreshCount()    // -> void
 *   handle.destroy()         // -> void
 *
 *   BrandSelector.closeAll() // -> void
 */
(function () {
  "use strict";

  var REGISTRY = (window._brandSelectorRegistry = window._brandSelectorRegistry || {});
  var OUTSIDE_HANDLER = null;

  function escAttr(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/"/g, "&quot;")
      .replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function makeEl(tag, className, attrs) {
    var el = document.createElement(tag);
    if (className) el.className = className;
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === "text") el.textContent = attrs[k];
      else el.setAttribute(k, attrs[k]);
    });
    return el;
  }

  function arrToSet(arr) { return new Set(arr || []); }

  // --- popover construction --------------------------------------------------

  function buildHeader(state) {
    var header = makeEl("div", "bs-popover-header");
    var title = makeEl("span", "bs-popover-title", { text: state.labels.title });
    var btnGroup = makeEl("div", "bs-popover-header-actions");
    var allBtn = makeEl("button", "bs-popover-action",
      { type: "button", text: state.labels.allBtn, "data-bs-action": "all" });
    var noneBtn = makeEl("button", "bs-popover-action",
      { type: "button", text: state.labels.noneBtn, "data-bs-action": "none" });
    btnGroup.appendChild(allBtn);
    btnGroup.appendChild(noneBtn);
    header.appendChild(title);
    header.appendChild(btnGroup);
    return header;
  }

  function buildRow(brand, state, splitMode) {
    var row = makeEl("label", "bs-popover-row" + (brand.isFocal ? " bs-popover-row-focal" : ""));
    row.setAttribute("data-bs-brand", brand.code);

    var tableCb = makeEl("input", "bs-popover-checkbox bs-popover-checkbox-table",
      { type: "checkbox", "data-bs-scope": "table" });
    tableCb.checked = !state.hiddenTable.has(brand.code);
    row.appendChild(tableCb);

    if (splitMode) {
      var chartCb = makeEl("input", "bs-popover-checkbox bs-popover-checkbox-chart",
        { type: "checkbox", "data-bs-scope": "chart" });
      chartCb.checked = !state.hiddenChart.has(brand.code);
      row.appendChild(chartCb);
    }

    var swatch = makeEl("span", "bs-popover-swatch");
    swatch.style.backgroundColor = brand.color || "#94a3b8";
    row.appendChild(swatch);

    var labelSpan = makeEl("span", "bs-popover-label", { text: brand.label });
    labelSpan.title = brand.label;
    row.appendChild(labelSpan);

    if (brand.isFocal) {
      var focal = makeEl("span", "bs-popover-focal-pill", { text: "FOCAL" });
      row.appendChild(focal);
    }

    return row;
  }

  function buildSyncFooter(state) {
    var wrap = makeEl("label", "bs-popover-sync");
    var cb = makeEl("input", "bs-popover-sync-cb",
      { type: "checkbox", "data-bs-action": "sync" });
    cb.checked = state.syncMode;
    var span = makeEl("span", null, { text: state.labels.syncToggle });
    wrap.appendChild(cb);
    wrap.appendChild(span);
    return wrap;
  }

  function buildPopover(state) {
    var pop = makeEl("div", "bs-popover");
    pop.setAttribute("role", "dialog");
    pop.setAttribute("data-bs-panel", state.panelId);
    pop.onclick = function (e) { e.stopPropagation(); };

    pop.appendChild(buildHeader(state));

    var body = makeEl("div", "bs-popover-body" + (state.mode === "split" ? " bs-popover-body-split" : ""));
    if (state.mode === "split") {
      var colHeader = makeEl("div", "bs-popover-col-header");
      colHeader.appendChild(makeEl("span", "bs-popover-col-table",
        { text: state.labels.columnTable }));
      colHeader.appendChild(makeEl("span", "bs-popover-col-chart",
        { text: state.labels.columnChart }));
      body.appendChild(colHeader);
    }
    state.brands.forEach(function (b) {
      body.appendChild(buildRow(b, state, state.mode === "split" && !state.syncMode));
    });
    pop.appendChild(body);

    if (state.mode === "split") pop.appendChild(buildSyncFooter(state));

    return pop;
  }

  // --- popover behaviour -----------------------------------------------------

  function emit(state, scope) {
    state.opts.onChange(state.hiddenTable, scope);
    if (state.mode === "split" && scope !== "table") {
      state.opts.onChange(state.hiddenChart, "chart");
    }
    refreshTriggerCount(state);
  }

  function bindRowToggle(state, row) {
    var brand = row.getAttribute("data-bs-brand");
    row.querySelectorAll(".bs-popover-checkbox").forEach(function (cb) {
      cb.addEventListener("change", function () {
        var scope = cb.getAttribute("data-bs-scope");
        var shouldShow = cb.checked;
        if (state.mode === "split" && state.syncMode) {
          state.hiddenTable[shouldShow ? "delete" : "add"](brand);
          state.hiddenChart[shouldShow ? "delete" : "add"](brand);
          emit(state, "all");
        } else if (scope === "chart") {
          state.hiddenChart[shouldShow ? "delete" : "add"](brand);
          emit(state, "chart");
        } else {
          state.hiddenTable[shouldShow ? "delete" : "add"](brand);
          emit(state, state.mode === "split" ? "table" : "all");
        }
      });
    });
  }

  function bindHeaderActions(state) {
    state.popoverEl.querySelectorAll('[data-bs-action="all"], [data-bs-action="none"]')
      .forEach(function (btn) {
        btn.addEventListener("click", function () {
          var hideAll = btn.getAttribute("data-bs-action") === "none";
          state.brands.forEach(function (b) {
            if (hideAll) { state.hiddenTable.add(b.code); state.hiddenChart.add(b.code); }
            else        { state.hiddenTable.delete(b.code); state.hiddenChart.delete(b.code); }
          });
          state.popoverEl.querySelectorAll(".bs-popover-checkbox").forEach(function (cb) {
            cb.checked = !hideAll;
          });
          emit(state, "all");
        });
      });
  }

  function bindSyncToggle(state) {
    var cb = state.popoverEl.querySelector('[data-bs-action="sync"]');
    if (!cb) return;
    cb.addEventListener("change", function () {
      state.syncMode = cb.checked;
      if (state.syncMode) {
        // Snap chart selection to table on sync-on
        state.hiddenChart = new Set(state.hiddenTable);
        emit(state, "all");
      }
      rebuildBody(state);
    });
  }

  function rebuildBody(state) {
    var oldBody = state.popoverEl.querySelector(".bs-popover-body");
    var newBody = makeEl("div", "bs-popover-body" + (state.mode === "split" ? " bs-popover-body-split" : ""));
    if (state.mode === "split") {
      var colHeader = makeEl("div", "bs-popover-col-header");
      colHeader.appendChild(makeEl("span", "bs-popover-col-table",
        { text: state.labels.columnTable }));
      colHeader.appendChild(makeEl("span", "bs-popover-col-chart",
        { text: state.labels.columnChart }));
      newBody.appendChild(colHeader);
    }
    state.brands.forEach(function (b) {
      var row = buildRow(b, state, state.mode === "split" && !state.syncMode);
      newBody.appendChild(row);
      bindRowToggle(state, row);
    });
    oldBody.replaceWith(newBody);
  }

  function refreshTriggerCount(state) {
    var visible = state.brands.length - state.hiddenTable.size;
    var badge = state.triggerEl.querySelector(".bs-trigger-count");
    if (badge) badge.textContent = "(" + visible + "/" + state.brands.length + ")";
  }

  function openPopover(state) {
    closeAll();
    var anchor = state.opts.anchorEl || state.triggerEl.parentElement;
    if (!anchor) return;
    if (getComputedStyle(anchor).position === "static") anchor.style.position = "relative";
    var pop = buildPopover(state);
    state.popoverEl = pop;
    pop.style.cssText = "position:absolute;top:" +
      (state.triggerEl.offsetTop + state.triggerEl.offsetHeight + 4) +
      "px;left:" + state.triggerEl.offsetLeft + "px;z-index:900;";
    anchor.appendChild(pop);

    pop.querySelectorAll(".bs-popover-row").forEach(function (row) { bindRowToggle(state, row); });
    bindHeaderActions(state);
    bindSyncToggle(state);

    OUTSIDE_HANDLER = function (e) {
      if (!pop.contains(e.target) && e.target !== state.triggerEl) closeAll();
    };
    setTimeout(function () {
      document.addEventListener("click", OUTSIDE_HANDLER, true);
      document.addEventListener("keydown", onEsc, true);
    }, 0);
    state.triggerEl.setAttribute("aria-expanded", "true");
  }

  function onEsc(e) { if (e.key === "Escape") closeAll(); }

  function closeAll() {
    Object.keys(REGISTRY).forEach(function (id) {
      var s = REGISTRY[id];
      if (s.popoverEl && s.popoverEl.parentNode) s.popoverEl.parentNode.removeChild(s.popoverEl);
      s.popoverEl = null;
      if (s.triggerEl) s.triggerEl.setAttribute("aria-expanded", "false");
    });
    if (OUTSIDE_HANDLER) document.removeEventListener("click", OUTSIDE_HANDLER, true);
    document.removeEventListener("keydown", onEsc, true);
    OUTSIDE_HANDLER = null;
  }

  // --- public API ------------------------------------------------------------

  function create(opts) {
    if (!opts || !opts.panelId) throw new Error("BrandSelector.create: panelId required");
    if (!opts.triggerEl) throw new Error("BrandSelector.create: triggerEl required");
    if (!Array.isArray(opts.brands)) throw new Error("BrandSelector.create: brands array required");

    var state = {
      panelId: opts.panelId,
      triggerEl: opts.triggerEl,
      brands: opts.brands.slice(),
      mode: opts.mode === "split" ? "split" : "unified",
      syncMode: opts.syncDefault !== false,
      hiddenTable: arrToSet(opts.initialHidden),
      hiddenChart: arrToSet(opts.initialHiddenChart || opts.initialHidden),
      popoverEl: null,
      labels: Object.assign({
        title: "Filter brands",
        allBtn: "All",
        noneBtn: "None",
        syncToggle: "Sync table + chart",
        columnTable: "Table",
        columnChart: "Chart"
      }, opts.labels || {}),
      opts: opts
    };
    REGISTRY[opts.panelId] = state;

    state.triggerEl.setAttribute("aria-haspopup", "true");
    state.triggerEl.setAttribute("aria-expanded", "false");
    state.triggerEl.addEventListener("click", function (e) {
      e.stopPropagation();
      var open = !!state.popoverEl;
      if (open) closeAll(); else openPopover(state);
    });

    refreshTriggerCount(state);

    return {
      getHidden: function () { return new Set(state.hiddenTable); },
      getHiddenChart: function () { return new Set(state.hiddenChart); },
      setHidden: function (codes) {
        state.hiddenTable = arrToSet(codes);
        if (state.syncMode) state.hiddenChart = arrToSet(codes);
        refreshTriggerCount(state);
      },
      // Update which brand carries the FOCAL pill. Re-renders open popover.
      setFocal: function (focalCode) {
        state.brands.forEach(function (b) { b.isFocal = (b.code === focalCode); });
        if (state.popoverEl) rebuildBody(state);
      },
      // Force a brand visible — removes from BOTH hidden sets (split mode safe)
      // and refreshes the trigger count + open popover. Used by panels that
      // need to guarantee the focal brand is always shown after a focal-change.
      showBrand: function (code) {
        state.hiddenTable.delete(code);
        state.hiddenChart.delete(code);
        refreshTriggerCount(state);
        if (state.popoverEl) rebuildBody(state);
      },
      refreshCount: function () { refreshTriggerCount(state); },
      destroy: function () { delete REGISTRY[state.panelId]; }
    };
  }

  window.BrandSelector = {
    create: create,
    closeAll: closeAll
  };
})();
