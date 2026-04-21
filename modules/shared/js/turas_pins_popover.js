/**
 * TurasPins — Shared Checkbox Popover
 *
 * Provides a consistent, checkbox-based "PIN TO VIEWS" popover for all modules.
 * Users independently toggle content types (Table, Chart, Insight, AI Insight)
 * before confirming with a "Pin" button.
 *
 * Usage:
 *   TurasPins.showCheckboxPopover(btnEl, checkboxes, onPin);
 *   TurasPins.closePopover();
 *
 * Depends on: TurasPins core (turas_pins.js) — loaded before this file.
 */

/* global TurasPins */

(function() {
  "use strict";

  var _outsideHandler = null;

  // ── CSS Injection ──────────────────────────────────────────────────────────

  /**
   * Inject popover CSS once on first use. Uses CSS variable for brand colour
   * so it adapts to whatever module theme is active.
   */
  function _ensureCSS() {
    if (document.getElementById("turas-pin-popover-css")) return;

    // Detect brand colour from module-specific CSS variables
    var root = getComputedStyle(document.documentElement);
    var brand =
      root.getPropertyValue("--cj-brand").trim() ||
      root.getPropertyValue("--md-brand").trim() ||
      root.getPropertyValue("--kd-brand").trim() ||
      root.getPropertyValue("--cd-brand").trim() ||
      root.getPropertyValue("--ci-brand").trim() ||
      root.getPropertyValue("--seg-brand").trim() ||
      root.getPropertyValue("--tk-brand").trim() ||
      root.getPropertyValue("--wt-brand").trim() ||
      root.getPropertyValue("--pr-brand").trim() ||
      root.getPropertyValue("--turas-brand").trim() ||
      "#323367";

    var css =
      ".pin-mode-popover {" +
        "background:#fff;" +
        "border:1px solid #e2e8f0;" +
        "border-radius:8px;" +
        "box-shadow:0 4px 12px rgba(0,0,0,0.12);" +
        "padding:4px 0;" +
        "min-width:190px;" +
        "display:flex;" +
        "flex-direction:column;" +
        "animation:fadeInPopover 0.15s ease;" +
      "}" +
      "@keyframes fadeInPopover {" +
        "from{opacity:0;transform:translateY(-4px)}" +
        "to{opacity:1;transform:translateY(0)}" +
      "}" +
      ".pin-mode-title {" +
        "padding:6px 14px 4px;" +
        "font-size:10px;" +
        "font-weight:700;" +
        "color:#94a3b8;" +
        "text-transform:uppercase;" +
        "letter-spacing:0.5px;" +
        "border-bottom:1px solid #f1f5f9;" +
        "margin-bottom:2px;" +
      "}" +
      ".pin-mode-checkbox {" +
        "display:flex;" +
        "align-items:center;" +
        "gap:8px;" +
        "padding:7px 14px;" +
        "font-size:12px;" +
        "font-weight:500;" +
        "color:#1e293b;" +
        "cursor:pointer;" +
        "transition:background 0.1s;" +
      "}" +
      ".pin-mode-checkbox:hover{background:#f0f4f8}" +
      ".pin-mode-checkbox.pin-mode-disabled{color:#cbd5e1;cursor:default}" +
      ".pin-mode-checkbox.pin-mode-disabled:hover{background:none}" +
      ".pin-mode-checkbox input[type=\"checkbox\"] {" +
        "accent-color:" + brand + ";" +
        "width:14px;" +
        "height:14px;" +
        "margin:0;" +
        "cursor:pointer;" +
      "}" +
      ".pin-mode-checkbox.pin-mode-disabled input[type=\"checkbox\"]{cursor:default}" +
      ".pin-mode-action {" +
        "display:block;" +
        "width:calc(100% - 20px);" +
        "margin:6px 10px 8px;" +
        "padding:7px 0;" +
        "border:none;" +
        "border-radius:5px;" +
        "background:" + brand + ";" +
        "color:#fff;" +
        "font-size:12px;" +
        "font-weight:600;" +
        "cursor:pointer;" +
        "font-family:inherit;" +
        "transition:opacity 0.15s;" +
      "}" +
      ".pin-mode-action:hover{opacity:0.85}";

    var style = document.createElement("style");
    style.id = "turas-pin-popover-css";
    style.textContent = css;
    document.head.appendChild(style);
  }

  // ── Close ──────────────────────────────────────────────────────────────────

  function _closePopoverOnOutside(e) {
    var p = document.querySelector(".pin-mode-popover");
    if (p && !p.contains(e.target) && !e.target.closest("[data-pin-btn]")) {
      TurasPins.closePopover();
    }
  }

  /**
   * Close any open pin popover.
   */
  TurasPins.closePopover = function() {
    var existing = document.querySelector(".pin-mode-popover");
    if (existing) existing.remove();
    if (_outsideHandler) {
      document.removeEventListener("click", _outsideHandler, true);
      _outsideHandler = null;
    }
  };

  // ── Show ───────────────────────────────────────────────────────────────────

  /**
   * Show a checkbox-based popover (pin or export).
   *
   * @param {HTMLElement} btnEl - The button that was clicked
   * @param {Array<{key:string, label:string, available:boolean, checked:boolean}>} checkboxes
   *   Content type options to show. Each has:
   *   - key: string identifier
   *   - label: Display text
   *   - available: Whether content exists (disabled if false)
   *   - checked: Default checked state
   * @param {function(Object)} onConfirm - Callback with flags object keyed by checkbox key
   * @param {HTMLElement} [anchorEl] - Optional parent for positioning (defaults to btn parent)
   * @param {object} [opts] - Optional overrides: { title, actionLabel }
   *   - title: Popover heading text (default "PIN TO VIEWS")
   *   - actionLabel: Action button text (default "Pin")
   */
  TurasPins.showCheckboxPopover = function(btnEl, checkboxes, onConfirm, anchorEl, opts) {
    // Toggle: if popover already open, close it
    var existing = document.querySelector(".pin-mode-popover");
    if (existing) {
      TurasPins.closePopover();
      return;
    }

    opts = opts || {};
    var popoverTitle  = opts.title       || "PIN TO VIEWS";
    var actionLabel   = opts.actionLabel || "Pin";

    _ensureCSS();

    var popover = document.createElement("div");
    popover.className = "pin-mode-popover";
    popover.onclick = function(e) { e.stopPropagation(); };

    // Title
    var title = document.createElement("div");
    title.className = "pin-mode-title";
    title.textContent = popoverTitle;
    popover.appendChild(title);

    // Optional header element (e.g. sub-tab radio group) inserted before checkboxes
    if (opts.headerEl) {
      popover.appendChild(opts.headerEl);
    }

    // Checkboxes
    var state = {};
    checkboxes.forEach(function(opt) {
      state[opt.key] = opt.available && opt.checked;

      var row = document.createElement("label");
      row.className = "pin-mode-checkbox" + (opt.available ? "" : " pin-mode-disabled");

      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = opt.available && opt.checked;
      cb.disabled = !opt.available;
      cb.onchange = function() { state[opt.key] = this.checked; };

      var span = document.createElement("span");
      span.textContent = opt.label;
      if (!opt.available) span.title = "Not available for this view";

      row.appendChild(cb);
      row.appendChild(span);
      popover.appendChild(row);
    });

    // Action button
    var pinBtn = document.createElement("button");
    pinBtn.className = "pin-mode-action";
    pinBtn.textContent = actionLabel;
    pinBtn.onclick = function(e) {
      e.stopPropagation();
      var anyChecked = Object.keys(state).some(function(k) { return state[k]; });
      if (!anyChecked) return;
      TurasPins.closePopover();
      onConfirm(state);
    };
    popover.appendChild(pinBtn);

    // Position under the button
    var anchor = anchorEl || btnEl.parentElement;
    anchor.style.position = "relative";
    popover.style.cssText = "position:absolute;top:" +
      (btnEl.offsetTop + btnEl.offsetHeight + 4) + "px;right:16px;z-index:1000;";
    anchor.appendChild(popover);

    // Deferred outside-click listener
    _outsideHandler = _closePopoverOnOutside;
    setTimeout(function() {
      document.addEventListener("click", _outsideHandler, true);
    }, 0);
  };

})();
