/**
 * TurasPins Shared Library — Core API
 *
 * Centralised pin management: init, add, remove, move, save, load.
 * Schema normalisation maps module-specific field names to canonical
 * names (chartSvg, tableHtml, insightText, pinMode).
 *
 * Depends on: turas_pins_utils.js (loaded first)
 * @namespace TurasPins
 */

/* global TurasPins */

(function() {
  "use strict";

  var _pins = [];
  var _config = null;
  var _hubMode = false;

  /**
   * Initialise TurasPins for a specific module.
   * @param {object} config - See plan for full config shape
   */
  TurasPins.init = function(config) {
    var f = config.features || {};
    _config = {
      storeId: config.storeId || "pinned-views-data",
      cssPrefix: config.cssPrefix || "pinned",
      moduleLabel: config.moduleLabel || "Report",
      containerId: config.containerId || "pinned-cards-container",
      emptyStateId: config.emptyStateId || "pinned-empty-state",
      badgeId: config.badgeId || null,
      toolbarId: config.toolbarId || null,
      features: {
        sections: !!f.sections, dragDrop: !!f.dragDrop,
        modePopover: !!f.modePopover, imageUpload: !!f.imageUpload,
        insightEdit: f.insightEdit !== false, qualSlides: !!f.qualSlides
      }
    };
    _hubMode = !!(window.pinToHub);
    if (!_hubMode) _load();
    TurasPins.updateBadge();
    TurasPins.updateButtons();
    if (_hubMode) {
      TurasPins._renderHubDelegation();
    } else {
      TurasPins.renderCards();
    }
  };

  /** @returns {object|null} Current config */
  TurasPins.getConfig = function() { return _config; };

  /** @returns {boolean} True if hub-embedded */
  TurasPins.isHubMode = function() { return _hubMode; };

  /**
   * Normalise pin to canonical field names and set defaults.
   * @param {object} pin - Raw pin data
   * @returns {object} Normalised pin
   */
  TurasPins.normalise = function(pin) {
    if (!pin || typeof pin !== "object") return pin;
    // Aliases → canonical
    if (pin.chart !== undefined && pin.chartSvg === undefined) pin.chartSvg = pin.chart;
    if (pin.table !== undefined && pin.tableHtml === undefined) pin.tableHtml = pin.table;
    if (pin.note !== undefined && pin.insightText === undefined) pin.insightText = pin.note;
    if (pin.insight !== undefined && pin.insightText === undefined) pin.insightText = pin.insight;
    if (pin.chartHtml !== undefined && pin.tableHtml === undefined) pin.tableHtml = pin.chartHtml;
    // Mode normalisation (conjoint: "both"/"chart"/"table")
    if (pin.mode && !pin.pinMode) {
      var modeMap = { both: "all", chart: "chart_insight", table: "table_insight" };
      pin.pinMode = modeMap[pin.mode] || pin.mode;
    }
    // Defaults
    pin.chartSvg = pin.chartSvg || "";
    pin.tableHtml = pin.tableHtml || "";
    pin.insightText = pin.insightText || "";
    pin.pinMode = pin.pinMode || "all";
    pin.timestamp = pin.timestamp || new Date().toISOString();
    pin.type = pin.type || "pin";
    if (!pin.id) {
      pin.id = "pin-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7);
    }
    // Clean up aliases
    delete pin.chart; delete pin.table; delete pin.note;
    delete pin.insight; delete pin.chartHtml; delete pin.mode;
    return pin;
  };

  /**
   * Add a pin. Hub mode forwards to pinToHub; standalone stores locally.
   * @param {object} pin - Pin data (will be normalised)
   */
  TurasPins.add = function(pin) {
    pin = TurasPins.normalise(pin);
    if (pin.chartSvg) pin.chartSvg = TurasPins._compressSvg(pin.chartSvg);
    delete pin.pngDataUrl;
    if (_hubMode) {
      window.pinToHub(pin);
      TurasPins._showToast("Pinned to combined report");
      return;
    }
    _pins.push(pin);
    _save();
    TurasPins.updateBadge();
    TurasPins.updateButtons();
    TurasPins.renderCards();
    TurasPins._showToast("Pinned: " + (pin.title || "View"));
  };

  /** Remove a pin or section by ID. */
  TurasPins.remove = function(id) {
    var idx = _findIndex(id);
    if (idx === -1) return;
    _pins.splice(idx, 1);
    _save();
    TurasPins.updateBadge();
    TurasPins.updateButtons();
    TurasPins.renderCards();
  };

  /** Move item by ID. direction: -1 up, +1 down. */
  TurasPins.move = function(id, direction) {
    var fromIdx = _findIndex(id);
    if (fromIdx === -1) return;
    var toIdx = fromIdx + direction;
    if (toIdx < 0 || toIdx >= _pins.length) return;
    var item = _pins.splice(fromIdx, 1)[0];
    _pins.splice(toIdx, 0, item);
    _save();
    TurasPins.renderCards();
  };

  /** Move item by index (used by drag/drop). */
  TurasPins.moveByIndex = function(fromIdx, toIdx) {
    if (fromIdx < 0 || fromIdx >= _pins.length) return;
    if (toIdx < 0 || toIdx >= _pins.length) return;
    var item = _pins.splice(fromIdx, 1)[0];
    _pins.splice(toIdx, 0, item);
    _save();
    TurasPins.renderCards();
  };

  /** Add a section divider. */
  TurasPins.addSection = function(title) {
    _pins.push({
      type: "section", title: title || "New Section",
      id: "sec-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7)
    });
    _save();
    TurasPins.renderCards();
  };

  /** @returns {Array} Copy of pins array */
  TurasPins.getAll = function() { return _pins.slice(); };

  /** @returns {number} Pin count (excludes sections) */
  TurasPins.getPinCount = function() {
    var c = 0;
    for (var i = 0; i < _pins.length; i++) { if (_pins[i].type === "pin") c++; }
    return c;
  };

  /** Update a pin's insight text. */
  TurasPins.updateInsight = function(pinId, text) {
    for (var i = 0; i < _pins.length; i++) {
      if (_pins[i].id === pinId) { _pins[i].insightText = text.trim(); _save(); return; }
    }
  };

  /** Update a section's title. */
  TurasPins.updateSectionTitle = function(sectionId, newTitle) {
    for (var i = 0; i < _pins.length; i++) {
      if (_pins[i].id === sectionId && _pins[i].type === "section") {
        _pins[i].title = newTitle.trim() || "Untitled Section";
        _save(); return;
      }
    }
  };

  /** Update pin count badge. */
  TurasPins.updateBadge = function() {
    if (!_config || !_config.badgeId) return;
    var badge = document.getElementById(_config.badgeId);
    if (!badge) return;
    var count = TurasPins.getPinCount();
    badge.textContent = count;
    badge.style.display = count > 0 ? "inline-flex" : "none";
  };

  /** Update pin button active states (pinned/unpinned toggle). */
  TurasPins.updateButtons = function() {
    if (!_config) return;
    var btns = document.querySelectorAll(
      "." + _config.cssPrefix + "-pin-btn, .pr-pin-btn, [data-pin-section]"
    );
    for (var i = 0; i < btns.length; i++) {
      var sid = btns[i].getAttribute("data-section") || btns[i].getAttribute("data-pin-section");
      if (!sid) continue;
      var isPinned = _pins.some(function(p) { return p.sectionId === sid; });
      btns[i].classList.toggle("pinned", isPinned);
      var txt = btns[i].textContent;
      if (txt.indexOf("Pin") !== -1 || txt.indexOf("Unpin") !== -1) {
        btns[i].textContent = isPinned ? "Unpin" : "Pin";
      }
    }
  };

  /** Save to DOM store. */
  TurasPins.save = function() { _save(); };

  /** Load from DOM store. */
  TurasPins.load = function() { _load(); };

  // ── Internal ───────────────────────────────────────────────────────────────

  function _findIndex(id) {
    for (var i = 0; i < _pins.length; i++) { if (_pins[i].id === id) return i; }
    return -1;
  }

  function _save() {
    if (!_config) return;
    var store = document.getElementById(_config.storeId);
    if (store) store.textContent = JSON.stringify(_pins);
  }

  function _load() {
    if (!_config) return;
    var store = document.getElementById(_config.storeId);
    if (!store) return;
    try {
      var data = JSON.parse(store.textContent);
      if (!Array.isArray(data)) return;
      var valid = [];
      for (var i = 0; i < data.length; i++) {
        var item = data[i];
        if (!item || typeof item !== "object") continue;
        if (!item.type || !item.id) continue;
        if (item.type !== "pin" && item.type !== "section") continue;
        if (item.pngDataUrl) delete item.pngDataUrl;
        valid.push(item);
      }
      _pins = valid;
    } catch (e) { _pins = []; }
  }

  /** Hub delegation message for embedded reports */
  TurasPins._renderHubDelegation = function() {
    var container = document.getElementById(_config.containerId);
    if (!container) return;
    var empty = document.getElementById(_config.emptyStateId);
    if (empty) empty.style.display = "none";
    container.innerHTML =
      '<div style="text-align:center;padding:48px 24px;color:#64748b;">' +
      '<div style="font-size:32px;margin-bottom:12px;">\uD83D\uDCCC</div>' +
      '<div style="font-size:15px;font-weight:600;color:#334155;margin-bottom:8px;">' +
      'Pinned views are in the combined report</div>' +
      '<div style="font-size:13px;">In combined reports, pins can be found in ' +
      'the combined report pin reel.</div></div>';
  };

  /**
   * Switch to hub mode after bridge injection.
   * Called by hub_navigation.js injectBridge() — handles the timing issue where
   * TurasPins.init() runs before window.pinToHub is set on the iframe.
   */
  TurasPins._setHubMode = function() {
    if (_hubMode) return;
    _hubMode = true;
    _pins = [];
    TurasPins._renderHubDelegation();
  };

  /** Direct access to internal pins array (for hub backward compat). */
  TurasPins._getPinsRef = function(newPins) {
    if (newPins !== undefined) _pins = newPins;
    return _pins;
  };

})();
