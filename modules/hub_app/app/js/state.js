/**
 * Turas Hub App — State Manager
 *
 * Persistence layer for pins and annotations.
 * - IndexedDB is the fast browser-side cache
 * - JSON sidecar files ({project}/.turas_pins.json) are the source of truth
 * - Shiny custom messages bridge browser ↔ filesystem
 *
 * Flow:
 *   1. On project open: R reads sidecar → sends to browser → browser hydrates IndexedDB + UI
 *   2. On pin change: browser updates IndexedDB → debounced save → sends JSON to R → R writes sidecar
 *   3. On next open: R reads sidecar (source of truth), browser compares timestamps
 */

var HubState = (function() {
  "use strict";

  // ---- Configuration ----
  var DB_NAME       = "TurasHubApp";
  var DB_VERSION    = 1;
  var STORE_NAME    = "pins";
  var SAVE_DEBOUNCE = 500;   // ms before writing to sidecar

  // ---- State ----
  var db            = null;   // IDBDatabase instance
  var saveTimer     = null;   // Debounce timer
  var projectKey    = null;   // Current project identifier (path-based)
  var listeners     = [];     // onChange callbacks

  // ---- Sidecar schema version ----
  var SIDECAR_VERSION = 1;

  // ===========================================================================
  // IndexedDB Setup
  // ===========================================================================

  /**
   * Open the IndexedDB database. Creates object stores on first run.
   * @param {function} [callback] - Called with (error) when ready
   */
  function openDB(callback) {
    if (db) {
      if (callback) callback(null);
      return;
    }

    if (!window.indexedDB) {
      console.warn("[Hub State] IndexedDB not available, using memory-only mode");
      if (callback) callback(null);
      return;
    }

    var request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = function(event) {
      var database = event.target.result;
      if (!database.objectStoreNames.contains(STORE_NAME)) {
        database.createObjectStore(STORE_NAME, { keyPath: "projectKey" });
      }
    };

    request.onsuccess = function(event) {
      db = event.target.result;
      if (callback) callback(null);
    };

    request.onerror = function(event) {
      console.error("[Hub State] IndexedDB open error:", event.target.error);
      if (callback) callback(event.target.error);
    };
  }

  // ===========================================================================
  // IndexedDB Read/Write
  // ===========================================================================

  /**
   * Read pin data from IndexedDB for the current project.
   * @param {function} callback - Called with (error, data)
   */
  function readFromIDB(callback) {
    if (!db || !projectKey) {
      callback(null, null);
      return;
    }

    try {
      var tx = db.transaction(STORE_NAME, "readonly");
      var store = tx.objectStore(STORE_NAME);
      var request = store.get(projectKey);

      request.onsuccess = function() {
        callback(null, request.result || null);
      };

      request.onerror = function() {
        callback(request.error, null);
      };
    } catch (e) {
      callback(e, null);
    }
  }

  /**
   * Write pin data to IndexedDB for the current project.
   * @param {object} data - The sidecar-format data to store
   * @param {function} [callback] - Called with (error)
   */
  function writeToIDB(data, callback) {
    if (!db || !projectKey) {
      if (callback) callback(null);
      return;
    }

    try {
      var record = {
        projectKey: projectKey,
        data: data,
        savedAt: Date.now()
      };

      var tx = db.transaction(STORE_NAME, "readwrite");
      var store = tx.objectStore(STORE_NAME);
      store.put(record);

      tx.oncomplete = function() {
        if (callback) callback(null);
      };

      tx.onerror = function() {
        if (callback) callback(tx.error);
      };
    } catch (e) {
      if (callback) callback(e);
    }
  }

  // ===========================================================================
  // Sidecar Sync (via Shiny)
  // ===========================================================================

  /**
   * Build a sidecar-format object from current pin/section arrays.
   * @param {Array} items - Array of pin and section objects
   * @returns {object} Sidecar-format JSON
   */
  function buildSidecarData(items) {
    var pins = [];
    var sections = [];

    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      if (item.type === "section") {
        sections.push({
          id: item.id,
          type: "section",
          title: item.title,
          position: i
        });
      } else if (item.type === "pin") {
        var pinCopy = {};
        for (var k in item) {
          if (item.hasOwnProperty(k)) {
            pinCopy[k] = item[k];
          }
        }
        pinCopy.position = i;
        pins.push(pinCopy);
      }
    }

    return {
      version: SIDECAR_VERSION,
      last_modified: new Date().toISOString(),
      turas_version: "1.0",
      pins: pins,
      sections: sections
    };
  }

  /**
   * Reconstruct the ordered items array from sidecar data.
   * Interleaves pins and sections by their stored position.
   * @param {object} sidecarData - Parsed sidecar JSON
   * @returns {Array} Ordered array of pin/section objects
   */
  function parseSidecarData(sidecarData) {
    if (!sidecarData) return [];

    var items = [];

    // Collect pins
    var pins = sidecarData.pins || [];
    for (var p = 0; p < pins.length; p++) {
      var pin = pins[p];
      pin.type = "pin";
      items.push(pin);
    }

    // Collect sections
    var sections = sidecarData.sections || [];
    for (var s = 0; s < sections.length; s++) {
      var sec = sections[s];
      sec.type = "section";
      items.push(sec);
    }

    // Sort by position if available, otherwise maintain array order
    items.sort(function(a, b) {
      var posA = (typeof a.position === "number") ? a.position : 9999;
      var posB = (typeof b.position === "number") ? b.position : 9999;
      return posA - posB;
    });

    // Clean up position field (UI doesn't need it)
    for (var i = 0; i < items.length; i++) {
      delete items[i].position;
    }

    return items;
  }

  /**
   * Save current items to both IndexedDB and sidecar (via Shiny).
   * Debounced — call freely on every change.
   * @param {Array} items - Current ordered items array
   */
  function save(items) {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(function() {
      var sidecarData = buildSidecarData(items);

      // 1. Write to IndexedDB (fast, local)
      writeToIDB(sidecarData);

      // 2. Send to R for sidecar file write
      var json = JSON.stringify(sidecarData);
      HubApp.sendToShiny("hub_save_pins", json);

      // Notify listeners
      for (var i = 0; i < listeners.length; i++) {
        listeners[i]("save", items);
      }
    }, SAVE_DEBOUNCE);
  }

  /**
   * Load pins for a project. Tries sidecar first (via Shiny message),
   * falls back to IndexedDB cache.
   * @param {string} key - Project key (typically the normalized path)
   */
  function loadForProject(key) {
    projectKey = key;

    // Request sidecar data from R
    HubApp.sendToShiny("hub_load_pins", key);

    // Also try IndexedDB as immediate cache
    readFromIDB(function(err, record) {
      if (err || !record || !record.data) return;

      // Use IDB data as initial hydration (sidecar will override if available)
      var items = parseSidecarData(record.data);
      if (items.length > 0) {
        for (var i = 0; i < listeners.length; i++) {
          listeners[i]("hydrate-cache", items);
        }
      }
    });
  }

  /**
   * Handle sidecar data received from R (source of truth).
   * @param {object} sidecarData - Parsed sidecar JSON from R
   */
  function handleSidecarLoaded(sidecarData) {
    if (!sidecarData) return;

    var items = parseSidecarData(sidecarData);

    // Update IndexedDB cache
    writeToIDB(sidecarData);

    // Notify listeners (PinBoard will hydrate from this)
    for (var i = 0; i < listeners.length; i++) {
      listeners[i]("hydrate-sidecar", items);
    }
  }

  /**
   * Register a change listener.
   * @param {function} fn - Called with (eventType, items)
   */
  function onChange(fn) {
    listeners.push(fn);
  }

  /**
   * Clear state for current project (e.g., on back navigation).
   */
  function clearProject() {
    clearTimeout(saveTimer);
    projectKey = null;
  }

  /**
   * Initialise the state manager. Opens IndexedDB.
   * @param {function} [callback] - Called when ready
   */
  function init(callback) {
    openDB(callback || function() {});
  }

  // ===========================================================================
  // Last-Opened Project Memory
  // ===========================================================================

  var LAST_PROJECT_KEY = "__hub_last_project__";

  /**
   * Save the last-opened project path to IndexedDB.
   * @param {string} projectPath - Project directory path
   * @param {string} projectName - Project display name
   */
  function saveLastProject(projectPath, projectName) {
    if (!db) return;

    try {
      var tx = db.transaction(STORE_NAME, "readwrite");
      var store = tx.objectStore(STORE_NAME);
      store.put({
        projectKey: LAST_PROJECT_KEY,
        data: { path: projectPath, name: projectName },
        savedAt: Date.now()
      });
    } catch (e) {
      console.warn("[Hub State] Failed to save last project:", e.message);
    }
  }

  /**
   * Get the last-opened project from IndexedDB.
   * @param {function} callback - Called with ({ path, name }) or null
   */
  function getLastProject(callback) {
    if (!db) {
      callback(null);
      return;
    }

    try {
      var tx = db.transaction(STORE_NAME, "readonly");
      var store = tx.objectStore(STORE_NAME);
      var request = store.get(LAST_PROJECT_KEY);

      request.onsuccess = function() {
        if (request.result && request.result.data) {
          callback(request.result.data);
        } else {
          callback(null);
        }
      };

      request.onerror = function() {
        callback(null);
      };
    } catch (e) {
      callback(null);
    }
  }

  // --- Public API ---
  return {
    init: init,
    save: save,
    loadForProject: loadForProject,
    handleSidecarLoaded: handleSidecarLoaded,
    onChange: onChange,
    clearProject: clearProject,
    buildSidecarData: buildSidecarData,
    parseSidecarData: parseSidecarData,
    saveLastProject: saveLastProject,
    getLastProject: getLastProject
  };
})();
